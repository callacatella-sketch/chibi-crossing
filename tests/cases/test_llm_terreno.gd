extends RefCounted
## IL TERRENO DEL CUORE CHE SCRIVE — e la promessa che ci sta sotto.
##
## Il gioco può avere dentro un modello linguistico locale (llama.cpp,
## `scons llm=yes`). **Deve funzionare identico senza.** Questo caso tiene
## chiusa quella promessa da tutte e due le parti, e gira in tutte e due le
## configurazioni:
##
##   - nel binario SENZA (quello normale, quello che gira qui e in
##     `tests.yml`) la classe nativa `LlmLocale` non esiste, `Llm.apri()`
##     torna `null`, e nessuna di queste chiamate deve stampare un errore o
##     interrompere niente;
##   - nel binario CON (il job `test-llm` di `tests.yml`) la classe esiste, e
##     allora le si chiede di dimostrare che il link statico non è solo
##     riuscito ma VIVO: un archivio si può linkare benissimo e lasciare il
##     registro dei backend di ggml vuoto, e da fuori sembrerebbe tutto a
##     posto finché non serve.
##
## Il difetto peggiore che questo file esiste per impedire non è un crash: è
## un ramo di gioco scritto per il caso «c'è il modello» e provato solo lì.
## Verrebbe consegnato a chi non ce l'ha e lo lascerebbe senza lettere, senza
## un errore, senza che nessun test diventi rosso.

const LLM := preload("res://systems/Llm.gd")


func run(t) -> void:
	_test_la_domanda_ha_una_casa_sola(t)
	_test_senza_e_la_normalita(t)
	_test_il_confine_in_cpp(t)
	_test_se_c_e_e_vivo(t)


## La domanda «c'è un cuore che scrive?» si fa in UN posto. È la regola delle
## fonti uniche applicata prima che ci sia qualcosa da duplicare: il giorno in
## cui la risposta dipenderà anche da altro (un modello scaricato, la memoria
## libera, una preferenza), deve cambiare un file solo.
func _test_la_domanda_ha_una_casa_sola(t) -> void:
	var colpevoli: Array[String] = []
	for cartella in ["res://systems", "res://scenes", "res://tools", "res://audio"]:
		_cerca(cartella, "LlmLocale", colpevoli)
	# Llm.gd è l'unico che ha diritto di nominarla; questo test la nomina nei
	# commenti e sta in tests/, che non viene scandagliato.
	colpevoli.erase("res://systems/Llm.gd")
	t.eq(colpevoli.size(), 0,
			"solo systems/Llm.gd può nominare la classe nativa (invece: %s)" % str(colpevoli))


## Il ramo SENZA è quello normale, e deve essere silenzioso. Niente `null` che
## esplode alla prima chiamata, niente avviso a ogni giro: un gioco che si
## lamenta di non avere una cosa opzionale insegna a chi ci gioca che gli
## manca qualcosa, e non gli manca niente.
func _test_senza_e_la_normalita(t) -> void:
	var c_e := LLM.disponibile()
	var cuore := LLM.apri()
	if c_e:
		t.ok(cuore != null, "se la classe c'è, apri() deve restituirla")
	else:
		t.ok(cuore == null, "senza il modulo, apri() restituisce null (e non è un guasto)")

	# `riga_di_stato()` attraversa il ramo nullo per intero. Se qualcuno le
	# togliesse la guardia, qui non arriverebbe una stringa vuota: arriverebbe
	# un errore a runtime — che NON fa fallire il test da solo (il runner non
	# se ne accorge), ma fa salire il conteggio degli `SCRIPT ERROR`, che in
	# questo progetto deve dare zero.
	var riga := LLM.riga_di_stato()
	t.ok(riga.length() > 0, "riga_di_stato() dice sempre qualcosa")
	t.eq(riga.contains("assente"), not c_e,
			"la riga di stato racconta la configurazione vera")


## Il CONFINE, dal lato C++. `src/llm_llama.h` è l'unico file autorizzato a
## includere llama.cpp: chi lo scavalcasse riaprirebbe le asimmetrie fra i
## rami del SConstruct (eccezioni, NDEBUG, flag di architettura) e il difetto
## uscirebbe come un comportamento DIVERSO fra Windows e macOS — cioè nel
## posto in cui questo progetto non può guardare da un Mac.
func _test_il_confine_in_cpp(t) -> void:
	var dir := DirAccess.open("res://src")
	t.ok(dir != null, "la cartella dei sorgenti C++ si legge")
	if dir == null:
		return
	var fuorilegge: Array[String] = []
	var confine_sbagliato: Array[String] = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and (f.ends_with(".cpp") or f.ends_with(".h")):
			var testo := FileAccess.get_file_as_string("res://src/" + f)
			if f != "llm_llama.h" and (testo.contains("#include \"llama.h\"") or testo.contains("<llama.h>")):
				fuorilegge.append(f)
			if testo.contains("llm_llama.h") and not f.begins_with("llm_"):
				confine_sbagliato.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	t.eq(fuorilegge.size(), 0,
			"solo llm_llama.h include llama.h (invece: %s)" % str(fuorilegge))
	t.eq(confine_sbagliato.size(), 0,
			"il confine lo aprono solo i file llm_* (invece: %s)" % str(confine_sbagliato))

	# E la guardia che rende il confine non aggirabile: se il SConstruct
	# smettesse di compilare il ponte con le eccezioni accese, la build
	# fallisce. Senza questa riga, un throw di llama_decode su macOS non
	# sarebbe un errore da gestire ma un `std::terminate` — il gioco che
	# sparisce mentre il Gufo scrive.
	var confine := FileAccess.get_file_as_string("res://src/llm_llama.h")
	t.ok(confine.contains("#error") and confine.contains("__EXCEPTIONS"),
			"llm_llama.h fa fallire la build se perde -fexceptions")
	t.ok(confine.contains("CHIBI_LLM"),
			"llm_llama.h non si lascia includere in una build senza llm=yes")

	# Il ponte non contagia: register_types.cpp lo include sotto condizione, e
	# `llm_ponte.h` non porta con sé niente di llama.
	var ponte_h := FileAccess.get_file_as_string("res://src/llm_ponte.h")
	t.ok(not ponte_h.contains("llama.h") or ponte_h.contains("NON include"),
			"llm_ponte.h non tira dentro llama.h")


## Se il cuore c'è, deve essere VIVO. Gira solo nel binario compilato con
## llm=yes (il job `test-llm`): lì queste righe sono l'unica prova che gli
## archivi statici di ggml non si sono limitati a linkare.
func _test_se_c_e_e_vivo(t) -> void:
	if not LLM.disponibile():
		return
	var cuore := LLM.apri()
	t.ok(str(cuore.versione()).length() > 0, "il ponte sa dire che llama.cpp ha dentro")

	# Il registro dei backend è la parte che si perde in silenzio: i backend si
	# registrano da costruttori dentro l'archivio statico, e un linker che
	# scarta l'oggetto sbagliato lascia zero backend e nessun errore.
	var quanti := int(cuore.quanti_backend())
	t.ok(quanti >= 1, "almeno un backend di calcolo registrato (invece: %d)" % quanti)
	var nomi: PackedStringArray = cuore.backend()
	t.eq(nomi.size(), quanti, "i nomi dei backend sono tanti quanti i backend")
	var ha_cpu := false
	for n in nomi:
		if str(n).to_lower().contains("cpu"):
			ha_cpu = true
	t.ok(ha_cpu, "c'è il backend CPU (invece: %s)" % str(nomi))

	# La riga con cui llama.cpp dichiara le istruzioni compilate. Non si
	# asserisce QUALI (cambiano fra ARM e x86, ed è giusto così): si pretende
	# che ci sia, perché è l'unico posto da cui si può leggere, nei log della
	# CI, se la baseline è quella che il SConstruct ha chiesto.
	t.ok(str(cuore.info_sistema()).length() > 0, "il ponte sa dire con che istruzioni è compilato")


func _cerca(cartella: String, ago: String, dentro: Array[String]) -> void:
	var dir := DirAccess.open(cartella)
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		var p := cartella + "/" + f
		if dir.current_is_dir():
			_cerca(p, ago, dentro)
		elif f.ends_with(".gd"):
			if FileAccess.get_file_as_string(p).contains(ago):
				dentro.append(p)
		f = dir.get_next()
	dir.list_dir_end()
