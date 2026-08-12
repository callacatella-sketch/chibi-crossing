extends SceneTree
## LE USCITE — chi ferma una generazione quando il gioco va da un'altra parte.
##
##   CHIBI_MODELLO=/percorso/al.gguf \
##     ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . \
##     --script res://tools/prova_uscita.gd
##
##   CHIBI_SCENA=1|2|3   una sola scena (di serie le fa tutte in fila)
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ ESISTE
## ────────────────────────────────────────────────────────────────────────
##
## Un pensiero dura secondi. Il giocatore, in quei secondi, può tornare al
## titolo, ricaricare la partita, chiudere il gioco. La domanda è una sola e
## non ha una risposta booleana: **quando il gioco va da un'altra parte, chi
## spegne il thread che sta ancora scrivendo?**
##
## Le tre uscite che questo banco guarda, una scena per una:
##
##  1. IL MANIGLIONE MUORE. `Llm.apri()` torna un `RefCounted`: quando l'ultimo
##     riferimento sparisce — ed è quello che succede a un cambio di scena, se
##     a tenerlo era un nodo dell'albero — non c'è più NESSUNO che possa
##     chiamare `raccogli()`. Un pensiero senza destinatario è lavoro che il
##     giocatore paga in core e non riceverà mai.
##  2. IL PENSATOIO MUORE. Stessa storia un piano più in su: chi ospita il
##     ritmo se ne va, e il ritmo deve portarsi dietro il lavoro in volo.
##  3. IL PROCESSO SI CHIUDE. Qui la rete è la GDExtension che si scarica
##     (`register_types.cpp`), e la si guarda con gli occhi: un thread vivo
##     dentro una libreria che si sta scaricando è un crash che nessuno vede,
##     perché la finestra è già sparita.
##
## Il numero che conta, in tutte e tre, è lo stesso: **quanti millisecondi
## passano fra il gesto e il momento in cui il motore torna libero**. Se sono
## quanto una generazione intera, nessuno ha fermato niente.

const LLM := preload("res://systems/Llm.gd")
const PENSATOIO := preload("res://scenes/npc/Pensatoio.gd")
const SUG := preload("res://scenes/npc/Suggeritore.gd")

## Il tetto di attesa: oltre questo la generazione è finita da sola, e
## «finita da sola» vuol dire che nessuno l'ha fermata.
const TETTO_MS := 40000.0

var _sistema := ""
var _utente := ""
var _gram := ""


func _init() -> void:
	_go()


func _aspetta_frame(n: int) -> void:
	for _i in n:
		await process_frame


func _go() -> void:
	print("")
	print("════ LE USCITE DEL CUORE CHE SCRIVE ════")
	if not LLM.disponibile():
		print("llm: assente (binario senza llama.cpp). Non c'è niente da fermare.")
		quit(0)
		return
	var percorso := OS.get_environment("CHIBI_MODELLO")
	if percorso == "" or not FileAccess.file_exists(percorso):
		print("serve CHIBI_MODELLO=/percorso/al.gguf")
		quit(1)
		return

	# Il foglio è quello VERO (`Suggeritore` su un ritratto pieno): la
	# lunghezza del prompt è metà del tempo di una generazione, e un banco che
	# scrive «ciao» misura una macchina che non esiste.
	var rit := _ritratto()
	var parti: Dictionary = SUG.parti(rit)
	_sistema = str(parti.get("sistema", ""))
	_utente = str(parti.get("utente", ""))
	_gram = SUG.grammatica(rit)
	if _utente == "" or _gram == "":
		print("GUASTO: il ritratto non produce un prompt")
		quit(1)
		return

	# ⚠️ IL MODELLO SI APRE UNA VOLTA PER PROCESSO e il maniglione che lo apre
	# NON si tiene: è proprio il gesto della scena 1. Il traduttore, invece,
	# vive nel processo — è la sua ragione d'essere.
	var apri := LLM.apri()
	var t0 := Time.get_ticks_msec()
	if not bool(apri.apri_modello(percorso, {"n_ctx": 1024, "priorita": 0})):
		print("GUASTO: apri_modello ha detto no: %s" % percorso)
		quit(1)
		return
	while int(apri.stato()) == 1:
		await process_frame
	if int(apri.stato()) != 2:
		print("GUASTO: %s" % str((apri.misure() as Dictionary).get("diagnosi", "")))
		quit(1)
		return
	print("modello aperto in %d ms · %s" % [Time.get_ticks_msec() - t0, percorso.get_file()])
	apri = null

	var quale := OS.get_environment("CHIBI_SCENA")
	if quale == "" or quale == "1":
		await _scena_maniglione()
	if quale == "" or quale == "2":
		await _scena_pensatoio()
	if quale == "" or quale == "3":
		await _scena_chiusura()
	quit(0)


## Quanto ci mette il motore a tornare libero, guardando da un maniglione
## NUOVO — cioè da un pezzo di gioco che non è quello che è morto.
func _quanto_ci_mette_a_tornare_libero() -> float:
	var spia := LLM.apri()
	var t := Time.get_ticks_msec()
	while not bool(spia.libero()):
		await process_frame
		if Time.get_ticks_msec() - t > int(TETTO_MS):
			return -1.0
	return float(Time.get_ticks_msec() - t)


func _accoda_lungo(cuore: Object, seme: int) -> int:
	# venti bozze da 128 gettoni: su questa macchina sono decine di secondi,
	# cioè molto più di qualunque uscita. Se il motore torna libero, è perché
	# qualcuno l'ha fermato.
	return int(cuore.accoda(1, _sistema, _utente, _gram,
			{"copie": 20, "max_token": 128, "seme": seme}))


# ─────────────────────────────────────────── 1. il maniglione muore
func _scena_maniglione() -> void:
	print("")
	print("── 1. IL MANIGLIONE MUORE (il cambio di scena) ──")
	var cuore := LLM.apri()
	if _accoda_lungo(cuore, 101) == 0:
		print("  GUASTO: accoda ha rifiutato")
		return
	# si aspetta che il thread sia DAVVERO dentro llama: fermare una cosa che
	# non è ancora partita non dimostra niente
	while int(cuore.stato()) != 3:
		await process_frame
	await _aspetta_frame(30)
	print("  sta generando (stato %d). Lascio cadere ogni riferimento." % int(cuore.stato()))
	cuore = null
	var ms := await _quanto_ci_mette_a_tornare_libero()
	if ms < 0.0:
		print("  ✗ dopo %d s STA ANCORA SCRIVENDO: nessuno l'ha fermata." % int(TETTO_MS / 1000.0))
	else:
		print("  ✓ il motore torna libero dopo %.0f ms" % ms)
	await _svuota()


# ─────────────────────────────────────────── 2. il Pensatoio muore
func _scena_pensatoio() -> void:
	print("")
	print("── 2. IL PENSATOIO MUORE (chi ospita il ritmo se ne va) ──")
	var cuore := LLM.apri()
	var p = PENSATOIO.new()
	var candidati := [{"chi": 1, "id": "prova"}]
	p.collega(cuore, func(): return candidati,
			func(_c): return {"sistema": _sistema, "utente": _utente,
					"grammatica": _gram, "seme": 202},
			func(_c, _b, _f): pass)
	p.passo(10.0)
	while int(cuore.stato()) != 3:
		await process_frame
	await _aspetta_frame(30)
	print("  sta generando (stato %d). Lascio cadere il Pensatoio." % int(cuore.stato()))
	p = null
	var t := Time.get_ticks_msec()
	while not bool(cuore.libero()):
		await process_frame
		if Time.get_ticks_msec() - t > int(TETTO_MS):
			print("  ✗ dopo %d s STA ANCORA SCRIVENDO: il ritmo se n'è andato e il lavoro no."
					% int(TETTO_MS / 1000.0))
			await _svuota()
			return
	print("  ✓ il motore torna libero dopo %d ms" % (Time.get_ticks_msec() - t))
	await _svuota()


# ─────────────────────────────────────────── 3. il processo si chiude
func _scena_chiusura() -> void:
	print("")
	print("── 3. IL PROCESSO SI CHIUDE mentre il Gufo scrive ──")
	var cuore := LLM.apri()
	if _accoda_lungo(cuore, 303) == 0:
		print("  GUASTO: accoda ha rifiutato")
		return
	while int(cuore.stato()) != 3:
		await process_frame
	await _aspetta_frame(30)
	print("  sta generando. Da qui in poi il gioco si chiude: la rete è il")
	print("  terminatore della GDExtension (`register_types.cpp`), e si guarda")
	print("  DA FUORI — quanto ci mette il processo a sparire, e se muore male.")
	print("  (chi lancia questo banco misuri con `time` e guardi il codice d'uscita)")


func _svuota() -> void:
	# fra una scena e l'altra si riparte puliti: chi arriva dopo deve trovare
	# un motore libero, non la coda della scena prima
	var c := LLM.apri()
	c.annulla()
	var t := Time.get_ticks_msec()
	while not bool(c.libero()) and Time.get_ticks_msec() - t < 10000:
		await process_frame


## Un ritratto pieno: sei ricordi, il prompt più lungo che il gioco produca.
func _ritratto() -> Dictionary:
	var righe := []
	var pesi := PackedFloat64Array()
	for k in 6:
		righe.append({"soggetto": -1, "verbo": k % 8, "cosa": 0, "bandiere": 0,
				"quante": 1 + k, "intensita": 255, "px": float(k) * 3.0, "pz": 2.0,
				"quando": 100.0 - float(k) * 60.0})
		pesi.append(2.6 - float(k) * 0.35)
	return {
		"nome": "la volpina Papavero", "eta": "adulta",
		"indole": ["curioso"], "quirk": "", "casa": Vector3(2, 0, 2),
		"azione": "cura_giardino", "obiettivo": "provvedi_cura",
		"protagonista": "Mochi", "nomi": {}, "compito": "lettera",
		"stagione": "autunno", "momento": "pomeriggio", "ciclo": 480.0,
		"ricordi": righe, "pesi": pesi,
		"verbi": ["annaffia", "semina", "raccoglie", "costruisce", "taglia",
				"pesca", "cucina", "dona"],
		"cose": ["fiore", "cibo", "casa", "fuoco", "pesce", "amico"],
		"gusto": PackedFloat64Array([1.4, 1.0, 1.0, 0.0, 1.0, 1.2]),
		"tinte": {"ammirazione": 2.4, "gratitudine": 0.5,
				"interesse": PackedFloat64Array()},
		"ora": 100.0, "mezza_vita": 240.0,
		"bandiere": {"sentito": 1, "su_di_me": 2, "detto": 4, "nessuno": -1},
	}
