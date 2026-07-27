extends RefCounted
## IL LESSICO CHIBIESE: combinazioni di suoni che vogliono dire parole
## semplici — SEMPRE le stesse. La promessa della lingua è la coerenza:
## se "grazie" non fosse sempre «ta-ki», il giocatore non potrebbe mai
## impararla. Guardie:
##  1. ogni sillaba del vocabolario è consonante+vocale dell'inventario
##     (la lingua ha una fonetica, non suoni a caso);
##  2. OGNI SEQUENZA È UNICA: mai due parole omofone;
##  3. i contorni d'intonazione appartengono a parole vere e hanno una
##     nota per sillaba;
##  4. COPERTURA: ogni concetto pronunciato nel codice (speak/say e le
##     parole dei ricordi in Legami.TIPI) esiste nel vocabolario — era
##     il buco di "addio" e "triste": i ricordi del congedo cadevano
##     nel balbettio casuale, proprio nei momenti più cari;
##  5. il suono è DETERMINISTICO (stessa voce + stessa parola = stessa
##     onda) e DISTINGUIBILE (parole diverse = onde diverse).

const CHB := preload("res://audio/Chibiese.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")


func run(t) -> void:
	_test_fonetica(t)
	_test_niente_omofoni(t)
	_test_contorni(t)
	_test_copertura(t)
	_test_suono(t)


func _test_fonetica(t) -> void:
	t.ok(CHB.VOCAB.size() >= 35, "il lessico è cresciuto (%d parole)" % CHB.VOCAB.size())
	for parola in CHB.VOCAB:
		var sillabe: Array = CHB.VOCAB[parola]
		t.ok(sillabe.size() >= 1 and sillabe.size() <= 3,
				"'%s': da una a tre sillabe (parole semplici)" % parola)
		for s in sillabe:
			var syl := str(s)
			var vocale := syl[syl.length() - 1]
			var cons := syl.substr(0, syl.length() - 1)
			t.ok(vocale in "aeiou", "'%s': '%s' finisce in vocale" % [parola, syl])
			t.ok(cons == "" or cons in CHB.CONS,
					"'%s': consonante '%s' dell'inventario" % [parola, cons])


func _test_niente_omofoni(t) -> void:
	var viste := {}
	for parola in CHB.VOCAB:
		var chiave := "-".join(PackedStringArray(CHB.VOCAB[parola]))
		t.ok(not viste.has(chiave),
				"'%s' non è omofona di '%s' («%s»)" % [parola, viste.get(chiave, ""), chiave])
		viste[chiave] = parola


func _test_contorni(t) -> void:
	for parola in CHB.CONTORNO:
		t.ok(CHB.VOCAB.has(parola),
				"il contorno di '%s' appartiene a una parola vera" % parola)
		t.eq((CHB.CONTORNO[parola] as Array).size(), (CHB.VOCAB[parola] as Array).size(),
				"'%s': una nota di contorno per sillaba" % parola)
		for m in CHB.CONTORNO[parola]:
			t.ok(float(m) > 0.5 and float(m) < 1.6,
					"'%s': contorno cantabile, mai un salto d'ottava" % parola)


## La guardia della copertura: si scandagliano i sorgenti per ogni
## speak([...]) e say(..., [...]), più le parole dei ricordi in
## Legami.TIPI — tutto ciò che si pronuncia deve stare nel vocabolario.
func _test_copertura(t) -> void:
	var re := RegEx.new()
	re.compile("(?:speak|say)\\([^\\)]*?\\[([^\\]]*)\\]")
	var re_lit := RegEx.new()
	re_lit.compile("\"([a-z~]+)\"")
	var parlati := {}
	for path in _tutti_gli_script("res://scenes"):
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var src := f.get_as_text()
		for m in re.search_all(src):
			for lit in re_lit.search_all(m.get_string(1)):
				parlati[lit.get_string(1)] = path.get_file()
	# e le parole dei ricordi del filo (Legami.TIPI, colonna Chibiese)
	var legami = load("res://scenes/world/Legami.gd")
	for tipo in legami.TIPI:
		for parola in (legami.TIPI[tipo] as Array)[1]:
			parlati[str(parola)] = "Legami.TIPI"
	t.ok(parlati.has("addio") and parlati.has("triste"),
			"la scansione vede le parole del congedo (il buco storico)")
	for parola in parlati:
		if str(parola) == "~":
			continue   # il chiacchiericcio libero è voluto
		t.ok(CHB.VOCAB.has(parola),
				"'%s' (da %s) è nel vocabolario: mai balbettio al suo posto"
				% [parola, parlati[parola]])


func _test_suono(t) -> void:
	var voce: Dictionary = CHB.voice(DNA.generate(7))
	# determinismo: la stessa parola, dalla stessa voce, è la STESSA onda
	CHB._cache.clear()
	var a: AudioStreamWAV = CHB.say(voce, ["grazie"], "neutro")
	CHB._cache.clear()
	var b: AudioStreamWAV = CHB.say(voce, ["grazie"], "neutro")
	t.eq(a.data, b.data, "«ta-ki» è sempre la stessa onda: si può imparare")
	# distinguibilità: parole diverse suonano diverse
	CHB._cache.clear()
	var c: AudioStreamWAV = CHB.say(voce, ["addio"], "neutro")
	t.ok(a.data != c.data, "«ba-yo» non è «ta-ki»: le parole si distinguono")
	# il contorno lavora: la stessa parola con e senza melodia differisce
	# (confronto indiretto: 'addio' ha contorno, la sua onda esiste e non
	# è vuota — la discesa la sente l'orecchio, il test ne garantisce i dati)
	t.ok(c.data.size() > 1000, "l'addio ha una voce, non un silenzio")


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
