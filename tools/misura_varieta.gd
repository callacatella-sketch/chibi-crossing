extends SceneTree

## IL METRO DELLA VARIETÀ — quante cose DIVERSE il modello propone in una
## volta, e quanto quello che cita spiega quello che chiede.
##
## Fase 5. Il Giudice esiste per «generare molto e tenere poco»: la rarità di
## una bozza si misura contro le sue sorelle, e se le cinque sorelle sono la
## stessa cosa non c'è niente da scegliere. Questo banco misura proprio quel
## numero, e lo fa **senza villaggio**: un registro nudo, N ritratti
## deterministici, il modello vero. Non giudica: registra una riga JSON per
## generazione, e il conto si fa dopo.
##
## ⚠️ **SI CONFRONTANO DUE CORSE, MAI UN NUMERO DA SOLO.** I ritratti e i semi
## sono deterministici apposta: due corse dello stesso banco con lo stesso
## modello differiscono SOLO per quello che è cambiato nel codice. Un numero
## assoluto qui non vuol dire niente — dipende dal modello, dalla taglia,
## dalla quantizzazione — mentre la differenza fra due corse appaiate sì.
##
##   CHIBI_MODELLO=/percorso.gguf CHIBI_OUT=/dir [CHIBI_N=24] [CHIBI_COPIE=5]
##   [CHIBI_CTX=2048] [CHIBI_PRIORITA=1] [CHIBI_TEMP=0.8]
##   Godot --headless --path . --script res://tools/misura_varieta.gd
##
## Le tre misure che escono, e perché sono queste:
##  · **obiettivi diversi fra le bozze di una generazione** — è la varietà che
##    conta per il Giudice: cinque bozze che chiedono la stessa cosa sono una
##    bozza sola, per quanto diverse siano le parole;
##  · **bozze testualmente distinte** — la varietà grezza, che dice se il
##    campionatore sta lavorando affatto;
##  · **il NESSO**: il verbo del ricordo più forte che la bozza cita, contro
##    l'obiettivo che chiede. Non è un voto (nessuno sa dire se «l'ho vista
##    pescare» giustifichi «cerco da mangiare»): è una tabella da guardare in
##    faccia, perché se il nesso è un dado la deduzione è rumore ben formato.
##
## ────────────────────────────────────────────────────────────────────────
## QUELLO CHE QUESTO BANCO HA GIÀ DETTO (2026-08-12, gemma-3-4b Q4_K_M)
## ────────────────────────────────────────────────────────────────────────
##
## Tredici ritratti appaiati, cinque copie ciascuno, quattro corse:
##
##     base (obiettivo prima, temp 0.8, top_p 0.9)   1.31 obiettivi · 1.62 bozze
##     il «perche» prima nella grammatica            1.00 · 1.15   ← PEGGIO
##     temperatura 1.15 (top_p 0.9)                  1.31 · 1.54   ← uguale
##     temperatura 1.15 e top_p 1.00                 1.38 · 1.69   ← nel rumore
##
## **Nessuna delle tre leve sposta il numero**, e la prima lo peggiora: coi
## numeri davanti il modello si impegna sui ricordi e arriva all'obiettivo
## ancora più deciso (tredici generazioni su tredici con un obiettivo solo).
## La temperatura non morde perché nella catena di `llm_pensieri.cpp` il
## `top_p` viene PRIMA: su una distribuzione già tagliata a 0.9, scaldarla
## non riapre i gettoni che sono stati tolti.
##
## Il conto vero è quello: **cinque copie comprano una proposta e mezza.**
## Non è una taratura sfortunata, è la forma del problema — una grammatica da
## poche decine di uscite e un modello sicuro di sé. Chi tara
## `Pensatoio.COPIE` per le DEDUZIONI guardi `Giudice.quante_diverse()`, che
## adesso viaggia dentro il `motivo` della scelta.
##
## E IL NESSO, sullo stesso banco: «Mochi mi ha messo una cosa fra le zampe»
## porta a `provvedi_meraviglia` 31 volte, a `provvedi_pancino` 6, a
## `provvedi_cura` 3 — lo STESSO ricordo verso tutti e tre. Il legame fra
## quello che si cita e quello che si chiede, oggi, lo tira il modello: nel
## gioco non esiste una fonte che dica a quale bisogno parli un ricordo, e
## inventarne una qui sarebbe la tabella scritta a occhio che questo progetto
## vieta. È il residuo dichiarato di questa fase, e si vede da questa tabella.

const SUG := preload("res://scenes/npc/Suggeritore.gd")
const GIU := preload("res://scenes/npc/Giudice.gd")
const LLM := preload("res://systems/Llm.gd")

## Il ciclo del villaggio vero: `imposta_ritmo` ne fa la mezza vita (120 s).
const CICLO := 240.0

## LE OTTO INDOLI E I QUATTRO MESTIERI del banco. Non sono decorazione: il
## foglio cambia con loro (CHI SEI, «adesso …»), e un banco che desse a tutti
## lo stesso carattere misurerebbe la varietà di UNA situazione.
const INDOLI := [["goloso"], ["curioso"], ["timido"], ["chiacchierone"],
	["pigro"], ["goloso", "curioso"], ["timido", "pigro"], ["chiacchierone"]]
const AZIONI := ["gironzola", "riposo", "quattro_chiacchiere", "regia"]

var _llm: Object = null
var _f: FileAccess = null
var _copie := 5


func _init() -> void:
	_go()


func _go() -> void:
	var percorso := OS.get_environment("CHIBI_MODELLO")
	var out := OS.get_environment("CHIBI_OUT")
	var quanti := int(OS.get_environment("CHIBI_N")) if OS.get_environment("CHIBI_N") != "" else 24
	_copie = int(OS.get_environment("CHIBI_COPIE")) if OS.get_environment("CHIBI_COPIE") != "" else 5
	if not LLM.disponibile():
		print("serve un binario compilato con llm=yes")
		quit(1)
		return
	if percorso == "" or out == "" or not ClassDB.class_exists("EcsMondo"):
		print("servono CHIBI_MODELLO, CHIBI_OUT e la GDExtension")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	_f = FileAccess.open(out + "/varieta.jsonl", FileAccess.WRITE)

	_llm = LLM.apri()
	var opz := {}
	if OS.get_environment("CHIBI_CTX") != "":
		opz["n_ctx"] = int(OS.get_environment("CHIBI_CTX"))
	opz["priorita"] = int(OS.get_environment("CHIBI_PRIORITA")) \
			if OS.get_environment("CHIBI_PRIORITA") != "" else 1
	# IL TETTO DI RAM È SPENTO QUI, e solo qui. Quello vero è dell'autore e
	# vive in `chibi::Config`: un banco che rifiutasse il modello che sta
	# misurando non misurerebbe niente. `0` vuol dire «nessun tetto», e
	# `CHIBI_TETTO` serve a chi vuole provare proprio quella valvola.
	opz["tetto_byte"] = int(OS.get_environment("CHIBI_TETTO")) \
			if OS.get_environment("CHIBI_TETTO") != "" else 0
	# E LA RISERVA DELLA MACCHINA, per la stessa ragione. ⚠️ Questo la spegne:
	# su una macchina carica (più agenti, più Godot) il modello che il gioco
	# aprirebbe benissimo da solo qui verrebbe rifiutato, e la corsa B non si
	# potrebbe appaiare alla A. Va bene per un banco, MAI per il gioco.
	opz["riserva_byte"] = int(OS.get_environment("CHIBI_RISERVA")) \
			if OS.get_environment("CHIBI_RISERVA") != "" else 0
	if not bool(_llm.call("apri_modello", percorso, opz)):
		print("GUASTO: apri_modello")
		quit(1)
		return
	while int(_llm.call("stato")) == 1:
		await process_frame
	if int(_llm.call("stato")) != 2:
		# LA DIAGNOSI SI STAMPA. Un banco che dicesse solo «non è pronto»
		# manderebbe chi lo usa a indovinare fra il file, il tetto di RAM e
		# la memoria libera della macchina — tre cause diverse con la stessa
		# faccia.
		print("GUASTO: il modello non è pronto (stato %d) — %s"
				% [int(_llm.call("stato")),
				str((_llm.call("misure") as Dictionary).get("diagnosi", ""))])
		quit(1)
		return
	print("modello aperto: %s" % percorso.get_file())

	var t0 := Time.get_ticks_msec()
	var vuoti := 0
	for i in quanti:
		var b := _ritratto(i)
		var m = b["m"]
		var rit: Dictionary = b["rit"]
		var parti: Dictionary = SUG.parti_deduzione(rit)
		var gram := str(SUG.grammatica_deduzione(rit))
		if parti.is_empty() or gram == "":
			# NIENTE DA DEDURRE: è il caso normale, non un errore. Si registra
			# lo stesso — un banco che nascondesse i muti direbbe che il
			# villaggio pensa più di quanto pensi.
			vuoti += 1
			_riga({"i": i, "muto": true})
			m.free()
			continue
		var bozze := await _genera(parti, gram, hash("varieta") + i * 7919)
		var fatti := []
		for x in SUG.fatti_deducibili(rit):
			var xx: Dictionary = x
			fatti.append({"riga": int(xx["riga"]), "base": str(xx["base"]),
					"peso": SUG.peso_riga(rit, int(xx["riga"]))})
		var d := {
			"i": i,
			"bozze": Array(bozze),
			"offerti": SUG.obiettivi_deducibili(rit),
			"righe": Array(SUG.righe_vive(rit)),
			"fatti": fatti,
			"azione": str(rit.get("azione", "")),
			"obiettivo_corrente": str(rit.get("obiettivo", "")),
		}
		# E COSA NE FA IL GIUDICE. Il numero che conta non è quante bozze
		# arrivano: è quante ne AMMETTE, perché è fra quelle che sceglie.
		var aperte := []
		for testo in bozze:
			var v = JSON.parse_string(str(testo))
			aperte.append(v if v is Dictionary else {})
		var scelta: Dictionary = GIU.scegli_deduzione(aperte, rit,
				{"fattibili": SUG.obiettivi_deducibili(rit)})
		var ammesse := 0
		for s in (scelta["schede"] as Array):
			if bool((s as Dictionary)["ok"]):
				ammesse += 1
		d["ammesse"] = ammesse
		d["scelta"] = int(scelta["scelta"])
		_riga(d)
		if i % 4 == 0:
			print("  %d/%d — %.1f min" % [i, quanti, float(Time.get_ticks_msec() - t0) / 60000.0])
		m.free()

	_llm.call("chiudi")
	if _f != null:
		_f.close()
	print("FINITO: %d generazioni (%d mute) in %.1f min"
			% [quanti, vuoti, float(Time.get_ticks_msec() - t0) / 60000.0])
	quit(0)


func _riga(d: Dictionary) -> void:
	if _f != null:
		_f.store_line(JSON.stringify(d))
		_f.flush()


## UN RITRATTO DETERMINISTICO, e la sua forma imita il villaggio vero: da uno
## a cinque ricordi di verbi diversi, sparsi nel tempo, qualcuno fatto A LUI
## (il dono) e qualcuno solo SENTITO. Le età sono scelte perché una parte dei
## ricordi finisca sotto la soglia — che è quello che succede in partita dopo
## qualche minuto.
func _ritratto(i: int) -> Dictionary:
	var m = ClassDB.instantiate("EcsMondo")
	m.imposta_ritmo(CICLO)
	var id = m.registra(PackedStringArray(INDOLI[i % INDOLI.size()]), "")
	var costanti: Dictionary = m.debug_grafo_costanti()
	var nessuno := int(costanti["sogg_nessuno"])
	var quanti := 1 + (i % 5)
	for k in quanti:
		var v := (i * 3 + k * 5) % int(m.N_VERBI)
		var dove := Vector3(2.0 + float((i + k) % 9), 0.0, 1.0 + float((i * 2 + k) % 11))
		if (i + k) % 7 == 0:
			# UN DONO: il ricordo «su di me», che nel villaggio vero è quello
			# che pesa il doppio ed è anche il più citato dal modello.
			m.osserva(id, m.V_DONA, dove, int(id))
		else:
			m.osserva(id, v, dove, nessuno)
		_passano(m, 12.0 + float((i * 13 + k * 29) % 90))
	var rit: Dictionary = SUG.ritratto(m, id, {
		"nome": "la volpina Papavero", "eta": "giovane",
		"indole": INDOLI[i % INDOLI.size()], "quirk": "",
		"casa": Vector3(4, 0, 6),
		"azione": AZIONI[i % AZIONI.size()],
		"obiettivo": _obiettivo_di(AZIONI[i % AZIONI.size()]),
	}, {"protagonista": "Mochi", "nomi": {int(id): "la volpina Papavero"},
		"compito": "pensiero", "stagione": "primavera",
		"momento": "pomeriggio", "ciclo": CICLO})
	return {"m": m, "rit": rit}


## L'obiettivo dell'azione in corso, con la tabella vera di `Piani`. Solo due
## delle quattro azioni del banco ne hanno uno: le altre non hanno un piano
## APPOSTA, ed è giusto che il banco veda tutti e due i casi.
func _obiettivo_di(azione: String) -> String:
	var piani := load("res://scenes/npc/Piani.gd")
	return str(piani.OBIETTIVO.get(azione, ""))


func _passano(m, sec: float) -> void:
	var fatto := 0.0
	while fatto < sec - 1e-6:
		var dt: float = minf(0.5, sec - fatto)
		m.avanza(dt, 0.5)
		fatto += dt


func _genera(parti: Dictionary, gram: String, seme: int) -> PackedStringArray:
	var opz := {"copie": _copie, "max_token": 48, "seme": seme}
	if OS.get_environment("CHIBI_TEMP") != "":
		opz["temperatura"] = float(OS.get_environment("CHIBI_TEMP"))
	# ⚠️ `top_p` VA GUARDATO INSIEME ALLA TEMPERATURA, non dopo. Nella catena
	# di llama.cpp il taglio della coda viene PRIMA (`llm_pensieri.cpp`
	# aggiunge top_p e poi temp), quindi alzare la temperatura su una
	# distribuzione già tagliata a 0.9 non riapre niente: misurato, non
	# supposto — vedi il commento in cima.
	if OS.get_environment("CHIBI_TOPP") != "":
		opz["top_p"] = float(OS.get_environment("CHIBI_TOPP"))
	var b := int(_llm.call("accoda", 0, str(parti["sistema"]), str(parti["utente"]),
			gram, opz))
	if b == 0:
		return PackedStringArray()
	var t0 := Time.get_ticks_msec()
	var e := {}
	while e.is_empty() and Time.get_ticks_msec() - t0 < 600000:
		await process_frame
		e = _llm.call("raccogli")
	return e.get("bozze", PackedStringArray())
