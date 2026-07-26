extends RefCounted
## IL REGISTA: il taccuino segreto deve pesare davvero sul profilo.
##
## Il bug trovato il 2026-07-26: Cooking e Woodcutting segnalavano "cucina" e
## "legna" con note(), ma nessun asse di Director.ASSI li conteneva — i
## contatori arrivavano e non pesavano MAI sul profilo del giocatore. Questi
## test tengono chiuso il buco:
##  1. ogni evento emesso nei sorgenti (call_group "regista"/"note" e le
##     note() interne del Regista) appartiene a un asse di ASSI;
##  2. assi e lettere del Gufo sono allineati (e ogni contatore ha UNA casa);
##  3. prova comportamentale: note("cucina") e note("legna") muovono profilo().

const DIRECTOR = preload("res://scenes/npc/Director.gd")


func run(t) -> void:
	_test_ogni_evento_ha_un_asse(t)
	_test_assi_e_lettere_allineati(t)
	_test_il_profilo_pesa_gli_eventi(t)


## Scova nei sorgenti tutti gli eventi segnalati al Regista e pretende che
## ciascuno stia in un asse: un evento orfano è un contatore che non peserà
## mai sul profilo (il bug esatto di "cucina" e "legna").
func _test_ogni_evento_ha_un_asse(t) -> void:
	var noti := {}
	for asse in DIRECTOR.ASSI:
		for c in DIRECTOR.ASSI[asse]:
			noti[c] = true

	var emessi := _eventi_emessi()
	t.ok(emessi.has("cucina") and emessi.has("legna"),
			"la scansione vede gli eventi di Cooking e Woodcutting")
	t.ok(emessi.has("bosco"), "la scansione vede le note() interne del Regista")
	for ev in emessi:
		t.ok(noti.has(ev),
				"l'evento '%s' appartiene a un asse di ASSI (da %s)"
				% [ev, emessi[ev]])


## Ogni asse ha la sua lettera del Gufo (più il fallback "curioso"), le
## lettere col contatore si formattano davvero, e ogni contatore vive in UN
## solo asse: contato due volte, gonfierebbe due profili insieme.
func _test_assi_e_lettere_allineati(t) -> void:
	for asse in DIRECTOR.ASSI:
		t.ok(DIRECTOR.LETTERE_GUFO.has(asse),
				"l'asse '%s' ha la sua lettera del Gufo" % asse)
	t.ok(DIRECTOR.LETTERE_GUFO.has("curioso"),
			"il fallback 'curioso' ha la sua lettera")
	for asse in DIRECTOR.LETTERE_GUFO:
		var testo = str(DIRECTOR.LETTERE_GUFO[asse])
		if testo.contains("%d"):
			t.ok((testo % 7).contains("7"),
					"la lettera di '%s' si formatta col contatore" % asse)
	var case := {}
	for asse in DIRECTOR.ASSI:
		for c in DIRECTOR.ASSI[asse]:
			t.ok(not case.has(c),
					"il contatore '%s' vive in un solo asse ('%s', non anche '%s')"
					% [c, case.get(c, ""), asse])
			case[c] = asse


## La prova comportamentale del bug: cucinare e far legna devono muovere il
## profilo. Regista fuori dall'albero (_ready non parte, niente Lua): note()
## e profilo() sono logica pura.
func _test_il_profilo_pesa_gli_eventi(t) -> void:
	var d = DIRECTOR.new()
	t.eq(d.profilo(), "curioso", "sotto tre gesti non si giudica nessuno")
	for i in 3:
		d.note("cucina")
	t.eq(d.profilo(), "socievole",
			"tre zuppette fanno un profilo socievole (il bug: prima non pesavano)")
	for i in 4:
		d.note("legna")
	t.eq(d.profilo(), "costruttore",
			"quattro alberi fanno un profilo costruttore")
	d.note("costruzione")
	t.eq(int(d._asse_val("costruttore")), 5,
			"l'asse somma i suoi contatori (legna + costruzione)")
	d.free()


## Tutti gli eventi segnalati al Regista nei sorgenti: le chiamate
## call_group("regista", "note", ...) in scenes/ (letterali della riga,
## ternari compresi) più le note("...") dirette dentro Director.gd.
## Ritorna { evento: file_di_provenienza }.
func _eventi_emessi() -> Dictionary:
	var out := {}
	var re_lit := RegEx.new()
	re_lit.compile("\"(\\w+)\"")
	for path in _tutti_gli_script("res://scenes"):
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		for riga in f.get_as_text().split("\n"):
			if not (riga.contains("\"regista\"") and riga.contains("\"note\"")):
				continue
			for m in re_lit.search_all(riga):
				var lit := m.get_string(1)
				if lit != "regista" and lit != "note":
					out[lit] = path.get_file()
	var fd := FileAccess.open("res://scenes/npc/Director.gd", FileAccess.READ)
	if fd != null:
		var re_note := RegEx.new()
		re_note.compile("\\bnote\\(\"(\\w+)\"\\)")
		for m in re_note.search_all(fd.get_as_text()):
			out[m.get_string(1)] = "Director.gd"
	return out


func _tutti_gli_script(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var p := dir_path.path_join(n)
		if d.current_is_dir():
			out.append_array(_tutti_gli_script(p))
		elif n.ends_with(".gd"):
			out.append(p)
		n = d.get_next()
	d.list_dir_end()
	return out
