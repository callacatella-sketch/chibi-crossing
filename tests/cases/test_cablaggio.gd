extends RefCounted
## CABLAGGIO: i fili che legano i sistemi al salvataggio e all'animo.
##
## La classe di bug trovata il 2026-07-26 era sempre la stessa: sistemi
## perfetti in isolamento ma mai collegati al gioco (l'animo non tornava dal
## salvataggio, i regali non lo toccavano, taglialegna e incarichi non
## salvavano). Questi test tengono i fili attaccati:
##  1. prova COMPORTAMENTALE: il rancore sopravvive a save -> _ensure_brain;
##  2. contratto delle chiavi: tutto ciò che save_extra scrive, load_extra
##     lo rilegge (è il bug esatto: "animo" scritto ma mai riletto);
##  3. i punti di salvataggio e il gesto gentile restano cablati nei sorgenti.

const VISITORS = preload("res://scenes/npc/Visitors.gd")
const ANIMO = preload("res://scenes/npc/Animo.gd")


func run(t) -> void:
	_test_animo_sopravvive_al_salvataggio(t)
	_test_contratto_chiavi_save_load(t)
	_test_fili_attaccati(t)
	_test_nessuno_chiama_il_writer_privato(t)


## Il percorso VERO del ripristino: un animo con rancore viene salvato, rimesso
## nella riga del residente con la chiave "animo" (com'è dopo load_extra) e
## ricostruito da _ensure_brain. Lo stato deve sopravvivere al viaggio.
func _test_animo_sopravvive_al_salvataggio(t) -> void:
	var a = ANIMO.new()
	a.setup({"name": "Timo"})
	a.ricorda("ordine_sgradito", "giocatore", -0.9, 1.0)
	var prima = a.rancore()
	t.ok(prima > 0.0, "l'animo di prova porta rancore (%s)" % prima)

	# niente albero: _ready di Visitors non parte, usiamo solo _ensure_brain
	var v = VISITORS.new()
	var r = {"label": "Timo", "dna": {"name": "Timo"}, "brain": {},
			"animo": a.save()}
	v._ensure_brain(r)
	var dopo = v._animi["Timo"]
	t.almost(dopo.rancore(), prima,
			"il rancore sopravvive a save -> riga residente -> _ensure_brain", 0.02)
	t.eq((dopo.ricordi as Array).size(), (a.ricordi as Array).size(),
			"i ricordi sopravvivono al viaggio")
	v.free()


## Ogni chiave che save_extra scrive nelle righe dei residenti deve comparire
## anche in load_extra: se qualcuno aggiunge un campo e dimentica di rileggerlo,
## questo test si accende (senza, il campo sparirebbe in silenzio a ogni avvio).
func _test_contratto_chiavi_save_load(t) -> void:
	var se := _body("res://scenes/npc/Visitors.gd", "save_extra")
	var le := _body("res://scenes/npc/Visitors.gd", "load_extra")
	t.ok(se != "" and le != "", "save_extra e load_extra esistono in Visitors")
	var chiavi := {}
	var re_lit := RegEx.new()
	re_lit.compile("\"(\\w+)\"\\s*:")
	for m in re_lit.search_all(se):
		chiavi[m.get_string(1)] = true
	var re_row := RegEx.new()
	re_row.compile("row\\[\"(\\w+)\"\\]")
	for m in re_row.search_all(se):
		chiavi[m.get_string(1)] = true
	t.ok(chiavi.has("animo"), "save_extra scrive la chiave 'animo'")
	t.ok(chiavi.has("brain"), "save_extra scrive la chiave 'brain'")
	for k in chiavi:
		t.ok(le.contains("\"%s\"" % k),
				"load_extra rilegge '%s' (chiave scritta da save_extra)" % k)


## I punti di salvataggio e il gesto gentile: controlli sul sorgente, mirati
## alla singola funzione (se il filo si stacca, qui si vede subito).
func _test_fili_attaccati(t) -> void:
	# NB: il salvataggio si chiede con l'API pubblica `request_save()` (una
	# scrittura per frame). Prima si chiamava il writer privato del
	# BuildSystem, `_save_village()`, da mezzo progetto: vedi
	# _test_nessuno_chiama_il_writer_privato qui sotto.
	t.ok(_body("res://scenes/interact/Woodcutting.gd", "_give_wood")
			.contains("request_save"),
			"Woodcutting._give_wood mette al sicuro l'abbattimento")
	t.ok(_body("res://scenes/npc/Lavori.gd", "assegna").contains("request_save"),
			"Lavori.assegna salva l'incarico appena dato")
	t.ok(_body("res://scenes/npc/Visitors.gd", "offer_item")
			.contains("gesto_gentile"),
			"offer_item porta il regalo fino all'animo (gesto_gentile)")


## Il writer del villaggio è PRIVATO del BuildSystem: chi ha stato da salvare
## chiede `request_save()` (o `save_now()` se sta uscendo). Questo test tiene
## chiusa la porta: era proprio l'accoppiamento sui membri privati altrui —
## `_save_village()` chiamato da 16 file — a produrre i buchi di persistenza e
## le doppie scritture (ogni nocciolina salvava il villaggio due volte).
func _test_nessuno_chiama_il_writer_privato(t) -> void:
	var colpevoli: Array[String] = []
	for path in _tutti_gli_script("res://scenes"):
		if path.ends_with("/BuildSystem.gd"):
			continue  # è il suo writer: lì dentro può usarlo
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		for riga in f.get_as_text().split("\n"):
			var r := str(riga).strip_edges()
			if r.begins_with("#") or r.begins_with("##"):
				continue  # i commenti possono nominarlo
			if r.contains("_save_village"):
				colpevoli.append(path.get_file())
				break
	t.eq(colpevoli.size(), 0,
			"nessuno fuori dal BuildSystem chiama _save_village (colpevoli: %s)"
			% ", ".join(colpevoli))


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


## Il corpo di una funzione: dal suo `func nome(` alla `func` successiva.
func _body(path: String, fn: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var src := f.get_as_text()
	var start := src.find("func %s(" % fn)
	if start < 0:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end - start) if end > start else -1)
