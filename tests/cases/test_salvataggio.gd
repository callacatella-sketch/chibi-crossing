extends RefCounted
## Il salvataggio blindato: scrittura atomica (tmp -> rename), copia .bak
## della versione precedente, ripristino automatico se il .json è rotto, e
## "Nuovo villaggio" che ARCHIVIA invece di cancellare. Prima di far
## crescere l'investimento emotivo del Filo Rosso, una copia di sicurezza
## è economica e preziosa — e qui si tiene la porta chiusa.

const BS := preload("res://scenes/build/BuildSystem.gd")


func run(t) -> void:
	_test_lettura_salvataggio(t)
	_test_fili_della_blindatura(t)


## _leggi_salvataggio: la funzione su cui poggia il ripiego sul .bak.
func _test_lettura_salvataggio(t) -> void:
	var b = BS.new()
	var p := "user://test_salvataggio_tmp.json"
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string("{\"cells\": [], \"nuts\": 7}")
	f.close()
	var buono = b._leggi_salvataggio(p)
	t.ok(buono is Dictionary, "un json valido si legge")
	t.eq(int((buono as Dictionary).get("nuts", 0)), 7, "e i dati ci sono")
	# il crash a metà scrittura: mezzo json non deve passare per buono
	f = FileAccess.open(p, FileAccess.WRITE)
	f.store_string("{\"cells\": [ CRASH")
	f.close()
	t.ok(not (b._leggi_salvataggio(p) is Dictionary), "un json rotto -> niente")
	t.ok(b._leggi_salvataggio("user://__non_esiste__.json") == null,
			"un file assente -> null, senza errori")
	DirAccess.remove_absolute(p)
	b.free()


## I fili nel sorgente: atomicità, .bak, ripiego, archivio.
func _test_fili_della_blindatura(t) -> void:
	var salva := _corpo("res://scenes/build/BuildSystem.gd", "_save_village")
	t.ok(salva.contains(".tmp") and salva.contains("rename_absolute"),
			"la scrittura è atomica: prima il .tmp, poi il rename")
	t.ok(salva.contains(".bak"),
			"la versione precedente diventa la copia .bak")
	var carica := _corpo("res://scenes/build/BuildSystem.gd", "_load_village")
	t.ok(carica.contains("_leggi_salvataggio") and carica.contains(".bak"),
			"il caricamento ripiega sul .bak se il .json è rotto")
	var nuovo := _corpo("res://scenes/ui/TitleScreen.gd", "_start_new")
	t.ok(nuovo.contains("rename_absolute"),
			"Nuovo villaggio ARCHIVIA il vecchio (village_<data>.json)")
	t.ok(not nuovo.contains("remove_absolute"),
			"e non cancella più niente: una storia non si butta")


## Il corpo di una funzione: dal suo `func nome(` alla `func` successiva.
func _corpo(path: String, fn: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var src := f.get_as_text()
	var start := src.find("func %s(" % fn)
	if start < 0:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end - start) if end > start else -1)
