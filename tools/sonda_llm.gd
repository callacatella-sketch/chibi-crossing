extends SceneTree
## LA SONDA — quanto pesa, quanto ci mette, quanto scrive, e con chi parla.
##
##   CHIBI_MODELLI=/dove/stanno/i/gguf CHIBI_MODELLO=/quello/da/aprire.gguf \
##   ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . \
##       --script res://tools/sonda_llm.gd
##
##   CHIBI_GIOCO=1   apre PRIMA il MainLevel vero: la stessa misura col gioco
##                   acceso. Si lancia due volte e si confrontano le colonne —
##                   la CPU in partita è contesa, e un token/s misurato a
##                   gioco spento è un numero che nessun giocatore vedrà mai.
##   CHIBI_IMPRONTA=1  calcola anche lo SHA-256 di ogni modello (secondi).
##   CHIBI_COPIE=5     quante bozze in una volta.
##   CHIBI_CTX=2048    la finestra.
##   CHIBI_PROMPT=/dir prende sistema/utente/grammatica dai file veri scritti
##                   da `tools/prova_prompt.gd`; senza, usa un foglio minimo.
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ ESISTE, VISTO CHE C'È GIÀ `misura_pensieri.gd`
## ────────────────────────────────────────────────────────────────────────
##
## Quello misura il FRAME: se il gioco singhiozza mentre un vicino pensa.
## Questo misura il PREZZO, che è l'altra metà e ha un tetto scritto
## dall'autore: **al massimo 2 GB di RAM sul PC del giocatore**. Un tetto
## senza un metro è un desiderio.
##
## Quattro sezioni:
##   A. IL PORTIERE — cosa dice di ogni .gguf, quanto costa dirlo, e quanta
##      memoria chiederebbe quel modello PRIMA di aprirlo (stima), con il
##      verdetto sul tetto.
##   B. IL CARICO — quanto ci mette davvero, e quanto pesa il processo prima
##      e dopo. Due numeri: l'impronta fisica (quella con cui il sistema
##      decide chi mandare in swap) e il vecchio RSS, che su macOS mente.
##   C. LA SCRITTURA — gettoni al secondo, in lettura e in uscita, e la
##      memoria alla fine (la cache di attenzione si riempie generando).
##   D. LA RETE — chi ha aperto una connessione. Deve essere: nessuno.
##
## ⚠️ La memoria si misura DA DENTRO il processo (il `memoria()` del ponte nativo),
## non con `ps`: i pesi sono mappati da file, e `ps rss` li conta a modo suo.

const LLM := preload("res://systems/Llm.gd")

const TETTO := 2 * 1024 * 1024 * 1024 # il tetto dell'autore, in byte

var _llm: Object = null


func _init() -> void:
	_go()


func _mb(b) -> String:
	return "%.0f MB" % (float(b) / 1048576.0)


func _aspetta(secondi: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(secondi * 1000.0):
		await process_frame


func _go() -> void:
	print("")
	print("════ LA SONDA DEL CUORE CHE SCRIVE ════")
	if not LLM.disponibile():
		print("llm: assente. Questo binario è compilato senza llama.cpp (llm=no),")
		print("e va benissimo: è la configurazione normale. Per misurare, ricompila")
		print("con `scons llm=yes` — la sonda non ha niente da dire senza.")
		quit(0)
		return
	_llm = LLM.apri()
	print("llama.cpp %s · backend: %s" % [str(_llm.versione()), ", ".join(_llm.backend())])
	print("istruzioni: %s" % str(_llm.info_sistema()).strip_edges())
	var m0 = _llm.memoria()
	print("il processo, adesso: impronta %s · residente %s"
			% [_mb(m0["impronta"]), _mb(m0["residente"])])

	var col_gioco := OS.get_environment("CHIBI_GIOCO") != ""
	if col_gioco:
		print("")
		print("— apro il MainLevel vero (il gioco resta acceso per tutta la misura) —")
		var ok := change_scene_to_file("res://scenes/levels/MainLevel.tscn")
		if ok != OK:
			print("  non si è aperto (%d): misuro a gioco spento" % ok)
			col_gioco = false
		else:
			await _aspetta(6.0)
			var mg = _llm.memoria()
			print("  il gioco acceso pesa: impronta %s · residente %s"
					% [_mb(mg["impronta"]), _mb(mg["residente"])])

	await _sezione_portiere()
	await _sezione_carico(col_gioco)
	quit(0)


# ───────────────────────────────────────────── A. IL PORTIERE
func _sezione_portiere() -> void:
	var dove := OS.get_environment("CHIBI_MODELLI")
	if dove == "":
		var uno := OS.get_environment("CHIBI_MODELLO")
		if uno == "":
			print("\n(nessun CHIBI_MODELLI / CHIBI_MODELLO: salto il portiere)")
			return
		dove = uno.get_base_dir()
	var con_impronta := OS.get_environment("CHIBI_IMPRONTA") != ""
	var d := DirAccess.open(dove)
	if d == null:
		print("\nnon riesco ad aprire %s" % dove)
		return
	var files: Array[String] = []
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if f.ends_with(".gguf"):
			files.append(dove.path_join(f))
		f = d.get_next()
	d.list_dir_end()
	files.sort()

	print("")
	print("════ A. IL PORTIERE ════ (tetto dell'autore: %s)" % _mb(TETTO))
	print("%-24s %-9s %-16s %8s %9s %10s %10s  %s"
			% ["file", "esito", "arch/quant", "sul disco", "ms esame", "stima 2k", "stima 4k", "ci sta?"])
	for p in files:
		var e = _llm.esamina(p, con_impronta)
		var nome := p.get_file()
		if not e["ok"]:
			print("%-24s %-9s %s" % [nome.substr(0, 24), "RIFIUTA", str(e["motivo"])])
			continue
		var s2 = int(e["byte_stimati_2k"])
		var s4 = int(e["byte_stimati_4k"])
		print("%-24s %-9s %-16s %9s %8.0f %10s %10s  %s"
				% [nome.substr(0, 24), "sano",
					("%s %s" % [e["architettura"], e["quantizzazione"]]).substr(0, 16),
					_mb(e["byte_file"]), float(e["ms_esame"]),
					_mb(s2), _mb(s4),
					("sì" if s2 <= TETTO else "NO — sfonda di %s" % _mb(s2 - TETTO))])
		if con_impronta:
			print("%-24s   sha256 %s (%.0f ms)" % ["", str(e["impronta"]).substr(0, 24), float(e["ms_impronta"])])


# ───────────────────────────────────── B+C. IL CARICO E LA SCRITTURA
func _sezione_carico(col_gioco: bool) -> void:
	var modello := OS.get_environment("CHIBI_MODELLO")
	if modello == "":
		print("\n(nessun CHIBI_MODELLO: non carico niente)")
		return

	var ctx := int(OS.get_environment("CHIBI_CTX")) if OS.get_environment("CHIBI_CTX") != "" else 2048
	var copie := int(OS.get_environment("CHIBI_COPIE")) if OS.get_environment("CHIBI_COPIE") != "" else 5

	print("")
	print("════ B. IL CARICO ════ (%s, finestra %d, gioco %s)"
			% [modello.get_file(), ctx, "ACCESO" if col_gioco else "spento"])
	var prima = _llm.memoria()
	var t0 := Time.get_ticks_usec()
	# Il tetto si spegne QUI perché la sonda deve poter misurare anche un
	# modello che il gioco rifiuterebbe: è così che si scopre di quanto
	# sfonda, invece di scoprire solo che sfonda.
	# Di serie il tetto è SPENTO qui, e non è una svista: la sonda deve poter
	# misurare anche un modello che il gioco rifiuterebbe — è così che si
	# scopre di QUANTO sfonda, invece di scoprire solo che sfonda.
	# `CHIBI_TETTO=<byte>` lo riaccende, ed è il modo di provare dal vivo che
	# il cancello del gioco funziona davvero (CHIBI_TETTO=2147483648).
	var opz := {"n_ctx": ctx, "tetto_byte": int(OS.get_environment("CHIBI_TETTO"))}
	# Le due manopole che cambiano il numero di gettoni al secondo più di
	# tutto il resto messo insieme, e vanno misurate, non credute:
	#   priorità 2 = QOS_CLASS_BACKGROUND, cioè i core di efficienza;
	#   thread = quanti core ci lavorano.
	if OS.get_environment("CHIBI_PRIORITA") != "":
		opz["priorita"] = int(OS.get_environment("CHIBI_PRIORITA"))
	if OS.get_environment("CHIBI_THREAD") != "":
		opz["n_thread"] = int(OS.get_environment("CHIBI_THREAD"))
	var partito: bool = _llm.apri_modello(modello, opz)
	if not partito:
		print("  non è nemmeno partito (percorso? c'è già un modello aperto?)")
		return
	# Il caricamento è sul thread: il frame gira mentre il modello si apre, ed
	# è tutto il punto. Qui si aspetta guardando l'avanzamento.
	var frame_durante := 0
	while true:
		await process_frame
		frame_durante += 1
		var st := int(_llm.stato())
		if st == 2 or st == 4: # PRONTO o GUASTO
			break
		if Time.get_ticks_usec() - t0 > 300 * 1000 * 1000:
			print("  ci mette più di cinque minuti: mi fermo")
			return
	var ms_carico := float(Time.get_ticks_usec() - t0) / 1000.0
	var mis = _llm.misure()
	if int(_llm.stato()) == 4:
		print("  RIFIUTATO: %s" % str(mis["diagnosi"]))
		return
	var dopo = _llm.memoria()
	print("  %.0f ms (di cui %.0f dentro llama) · il gioco ha disegnato %d frame nel frattempo"
			% [ms_carico, float(mis["secondi_caricamento"]) * 1000.0, frame_durante])
	print("  impronta  %s → %s   (+%s)"
			% [_mb(prima["impronta"]), _mb(dopo["impronta"]),
				_mb(int(dopo["impronta"]) - int(prima["impronta"]))])
	print("  residente %s → %s   (+%s)"
			% [_mb(prima["residente"]), _mb(dopo["residente"]),
				_mb(int(dopo["residente"]) - int(prima["residente"]))])
	print("  thread consigliati: %d" % int(mis["n_thread_consigliati"]))

	await _sezione_scrittura(copie, dopo)
	_sezione_rete()


func _foglio() -> Dictionary:
	var dir := OS.get_environment("CHIBI_PROMPT")
	if dir != "":
		var s := FileAccess.get_file_as_string(dir.path_join("prompt_sistema.txt"))
		var u := FileAccess.get_file_as_string(dir.path_join("prompt_utente.txt"))
		var g := FileAccess.get_file_as_string(dir.path_join("grammatica_esempio.gbnf"))
		if s != "" and u != "" and g != "":
			return {"sistema": s, "utente": u, "grammatica": g}
	# Il ripiego: un foglio minimo, ma con una grammatica VERA — generare
	# senza è il guasto che la Fase 5 esiste per impedire, e una sonda che
	# misura una configurazione impossibile misura il nulla.
	return {
		"sistema": "Sei un gufo anziano che scrive lettere brevi a una gattina.",
		"utente": "Scrivi tre righe.",
		"grammatica": "root ::= riga riga riga\nriga ::= [a-z ,]+ \"\\n\"\n",
	}


func _sezione_scrittura(copie: int, prima) -> void:
	print("")
	print("════ C. LA SCRITTURA ════ (%d copie in una volta)" % copie)
	var f := _foglio()
	# ⚠️ SOLO PER MISURARE il prezzo della grammatica. In partita la
	# grammatica NON è facoltativa: senza, il modello inventa citazioni nel
	# 27% dei casi (misurato nel provino), ed è il guasto che INVERTE
	# l'effetto invece di attenuarlo.
	var senza := OS.get_environment("CHIBI_SENZA_GRAMMATICA") != ""
	if senza:
		print("  ⚠️ grammatica SPENTA: è una misura, non una configurazione")
	var t0 := Time.get_ticks_usec()
	var biglietto: int = _llm.accoda(0, f["sistema"], f["utente"],
			("" if senza else f["grammatica"]), {"copie": copie, "seme": 1234})
	if biglietto == 0:
		print("  rifiutato in coda (il motore non è libero?)")
		return
	var esito := {}
	var frame := 0
	while true:
		await process_frame
		frame += 1
		var r = _llm.raccogli()
		if not r.is_empty():
			esito = r
			break
		if Time.get_ticks_usec() - t0 > 600 * 1000 * 1000:
			print("  dieci minuti: mi fermo")
			return
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	if str(esito.get("errore", "")) != "":
		print("  errore: %s" % str(esito["errore"]))
		return
	var sp := float(esito["secondi_prompt"])
	var sg := float(esito["secondi_generazione"])
	var tp := int(esito["token_prompt"])
	var tg := int(esito["token_generati"])
	print("  prompt      %d gettoni in %.2f s = %.1f gettoni/s" % [tp, sp, (float(tp) / sp) if sp > 0.0 else 0.0])
	print("  uscita      %d gettoni in %.2f s = %.1f gettoni/s" % [tg, sg, (float(tg) / sg) if sg > 0.0 else 0.0])
	print("  in tutto    %.2f s per %d bozze (%d frame disegnati nel frattempo)"
			% [ms / 1000.0, esito["bozze"].size(), frame])
	var dopo = _llm.memoria()
	print("  impronta    %s → %s dopo aver scritto (+%s)"
			% [_mb(prima["impronta"]), _mb(dopo["impronta"]),
				_mb(int(dopo["impronta"]) - int(prima["impronta"]))])
	print("  TETTO       %s su %s → %s"
			% [_mb(dopo["impronta"]), _mb(TETTO),
				("ci sta" if int(dopo["impronta"]) <= TETTO else "SFONDA di %s" % _mb(int(dopo["impronta"]) - TETTO))])
	print("")
	var bozze: PackedStringArray = esito["bozze"]
	for i in bozze.size():
		print("  ── bozza %d ─────────────────────────" % (i + 1))
		for riga in str(bozze[i]).split("\n"):
			if riga.strip_edges() != "":
				print("     %s" % riga)


# ───────────────────────────────────────────── D. LA RETE
func _sezione_rete() -> void:
	print("")
	print("════ D. LA RETE ════")
	print("  (deve essere vuota: il modello gira in locale, nessuna chiamata a nessuno)")
	var fuori: Array = []
	var codice := OS.execute("/usr/sbin/lsof", ["-nP", "-i", "-a", "-p", str(OS.get_process_id())], fuori, true)
	if codice != 0 and fuori.is_empty():
		print("  lsof non ha risposto (%d): la verifica si fa da fuori" % codice)
		return
	var righe := str("\n".join(fuori)).strip_edges()
	if righe == "":
		print("  nessuna connessione aperta. ✓")
	else:
		print(righe)
