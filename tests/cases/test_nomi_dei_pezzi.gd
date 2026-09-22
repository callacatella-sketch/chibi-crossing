extends RefCounted
## ⚠️ **CHI CERCA UN PEZZO PER NOME DEVE CERCARE UN NOME CHE ESISTE.**
##
## `Visitors._nearest_named(names, …)` scorre `BuildSystem.get_placed_by_name`,
## che confronta il meta `item_name` col catalogo. Un nome che a catalogo non
## c'è non trova MAI niente — e non dà nessun errore, nessun avviso, nessuna
## traccia: la lista resta lì, si legge benissimo, e non cerca nulla.
##
## Era successo, e in due posti insieme. `_fatti_di` gatava «meraviglia» con
## `["Stagno", "Grande Albero", "Panchina"]` e `_luoghi_del_piano` dava al
## PIANIFICATORE il luogo «bello» con la stessa lista — ma dei
## centotrentasette nomi a catalogo **nessuno è «Stagno» né «Grande Albero»**:
## lo stagno e l'albero sono geografia, li costruisce `CozyWorld`. Quella
## lista valeva quindi «c'è una Panchina entro 18 m», mentre `_recita` mandava
## il corpo allo stagno o al Grande Albero. Il cancello misurava una cosa e il
## corpo ne faceva un'altra: chi non aveva una panchina vicina non poteva
## meravigliarsi nemmeno stando davanti allo stagno, e chi ce l'aveva partiva
## per un posto che poteva stare a quaranta metri.
##
## Questa guardia non conosce quel caso: conosce la REGOLA. Qualunque nome
## passato a `_nearest_named` deve stare a catalogo.
const CAT := preload("res://scenes/build/BuildCatalog.gd")

## I file che cercano pezzi per nome. Non è un elenco da tenere allineato a
## mano: si scandagliano tutte le cartelle e si guarda chi chiama.
const CARTELLE := ["res://scenes/npc", "res://scenes/world", "res://scenes/interact",
		"res://scenes/build", "res://scenes/levels", "res://systems"]


func run(t) -> void:
	_i_nomi_cercati_esistono(t)


func _catalogo() -> Dictionary:
	var out := {}
	for v in CAT.items():
		var n := str((v as Dictionary).get("name", ""))
		if n != "":
			out[n] = true
	return out


func _file_gd(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			if not f.begins_with("."):
				_file_gd(dir + "/" + f, out)
		elif f.ends_with(".gd"):
			out.append(dir + "/" + f)
		f = d.get_next()
	d.list_dir_end()


func _i_nomi_cercati_esistono(t) -> void:
	var nomi := _catalogo()
	t.ok(nomi.size() > 100, "il catalogo si legge (%d pezzi)" % nomi.size())

	var files: Array = []
	for c in CARTELLE:
		_file_gd(c, files)
	t.ok(files.size() > 40, "si scandagliano i sorgenti (%d file)" % files.size())

	# ⚠️ i commenti si spogliano: questo progetto NOMINA apposta le cose che
	# ha tolto, e un guardiano ingenuo accuserebbe proprio il file riparato
	var util = load("res://tests/test_util.gd")
	var cercati := 0
	var fantasmi: Array[String] = []
	var re := RegEx.new()
	re.compile('_nearest_named\\(\\s*\\[([^\\]]*)\\]')
	var re_str := RegEx.new()
	re_str.compile('"([^"]+)"')
	for f: String in files:
		var src: String = util.senza_commenti(FileAccess.get_file_as_string(f))
		for m in re.search_all(src):
			for s in re_str.search_all(m.get_string(1)):
				var nome := s.get_string(1)
				cercati += 1
				if not nomi.has(nome):
					fantasmi.append("%s cerca «%s»" % [f.get_file(), nome])

	t.ok(cercati > 0,
			"qualcuno cerca davvero pezzi per nome (%d nomi in tutto)" % cercati)
	t.eq(fantasmi.size(), 0,
			("nessuno cerca un pezzo che a catalogo non esiste — un nome "
			+ "fantasma non trova mai niente e non lo dice: %s")
					% str(fantasmi))
