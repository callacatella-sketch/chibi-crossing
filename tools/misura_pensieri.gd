extends SceneTree
## IL METRO DEL PENSIERO — quanto costa al gioco avere un cuore che scrive.
##
##   CHIBI_MODELLO=/percorso/al.gguf CHIBI_PRIORITA=2 CHIBI_COPIE=5 \
##     ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://tools/misura_pensieri.gd
##
## ────────────────────────────────────────────────────────────────────────
## COSA MISURA, E PERCHÉ NESSUNA ASSERZIONE PUÒ DARE QUESTI NUMERI
## ────────────────────────────────────────────────────────────────────────
##
## La promessa della Fase 5 è: **il frame non si ferma mai, nemmeno un
## millisecondo**. Un test booleano non sa dirlo — sa solo dire che una
## funzione ha risposto. Qui si apre il MainLevel VERO, ci si mettono
## ventotto residenti veri, e si guarda il frame com'è stato DISEGNATO:
##
##   A. venti secondi a motore SPENTO       → il frame di riferimento
##   B. il caricamento del modello          → 2 GB mappati mentre si gioca
##   C. il villaggio che pensa              → il frame col thread acceso
##   D. lo spegnimento                      → quanto costa `annulla`/`chiudi`
##
## e poi mette le due distribuzioni una accanto all'altra. La differenza fra
## A e C è la risposta alla domanda dell'autore.
##
## ⚠️ LA TRAPPOLA DI MISURA, ed è la stessa già pagata col tween della seduta:
## l'ordine del frame in Godot è `process_frame` → `_process` dei nodi →
## tween → disegno. Una sonda dentro `_process` cade in mezzo e somma due
## spostamenti che il giocatore non ha mai visto insieme. Ci si aggancia a
## `process_frame`, che vede il frame com'è stato disegnato.
##
## ⚠️ E IL VSYNC SI SPEGNE. Con il vsync acceso ogni frame dura 16.6 ms per
## definizione, e le due colonne uscirebbero identiche anche se il motore si
## mangiasse metà macchina: il vsync non toglie il costo, lo NASCONDE dentro
## l'attesa. Spento, il tempo di frame è il lavoro vero.

const FOGLIO := preload("res://scenes/npc/FoglioDelVicino.gd")
const PENSATOIO := preload("res://scenes/npc/Pensatoio.gd")
const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")
const LLM := preload("res://systems/Llm.gd")

## Ventotto: il tetto vero del villaggio (`Visitors.MAX_RESIDENTS`), cioè il
## caso peggiore che un giocatore possa costruirsi. Misurare con tre sarebbe
## misurare un gioco che non esiste.
const QUANTI := 28
## ⚠️ A E C DURANO UGUALE, E NON È UN DETTAGLIO. Il MASSIMO di un campione
## cresce col numero di campioni: confrontare il peggior frame di venti
## secondi con quello di novanta è confrontare venti tiri di dado con
## novanta, e il secondo esce sempre più alto — un divario inventato dalla
## statistica, non dal motore. La prima stesura di questo banco lo faceva, e
## dichiarava +43 ms di peggioramento su un frame che il modello non aveva
## mai toccato.
const SECONDI := 30.0
## I blocchi alternati: sei per parte, dodici secondi l'uno (due minuti e
## mezzo in tutto). Corti abbastanza che la macchina non abbia il tempo di
## cambiare umore fra uno e il suo gemello, lunghi abbastanza da raccogliere
## qualche centinaio di frame per blocco.
const BLOCCHI := 6
const DURATA_BLOCCO := 12.0

var _vis: Node = null
var _dn: Node = null
var _cuore: Object = null
var _llm: Object = null
var _pens: RefCounted = null
var _residenti: Array = []
var _consegne: Array = []
var _gia_dette: Array = []   # la memoria del Giudice: cosa il villaggio ha già detto
var _campioni := PackedFloat64Array()
var _t_ultimo := 0
var _misura := false
var _sistema_finto := ""
var _utente_finto := ""
var _gram_finta := ""


func _init() -> void:
	_go()


func _trova(gruppo: String) -> Node:
	for n in get_nodes_in_group(gruppo):
		return n
	return null


# ---------------------------------------------------------------- il metro

func _apri_sonda() -> void:
	process_frame.connect(_frame)


func _frame() -> void:
	var ora := Time.get_ticks_usec()
	if _misura and _t_ultimo != 0:
		_campioni.append(float(ora - _t_ultimo) / 1000.0)
	_t_ultimo = ora


func _via() -> void:
	_campioni = PackedFloat64Array()
	_t_ultimo = 0
	_misura = true


func _stop() -> Dictionary:
	_misura = false
	var v := Array(_campioni)
	v.sort()
	if v.is_empty():
		return {"n": 0}
	var somma := 0.0
	for x in v:
		somma += float(x)
	var p50 := float(v[int(v.size() * 0.50)])
	# LA SINGHIOZZATA SI CONTA, non si guarda solo il massimo: «quanti frame
	# sono durati più del doppio della mediana» è il numero che descrive quello
	# che si VEDE (uno scatto), mentre il massimo descrive un frame solo — che
	# su una macchina viva può essere il compattatore della memoria di macOS.
	var doppi := 0
	for x in v:
		if float(x) > p50 * 2.0:
			doppi += 1
	return {
		"n": v.size(),
		"medio": somma / float(v.size()),
		"p50": p50,
		"p99": float(v[mini(int(v.size() * 0.99), v.size() - 1)]),
		"p999": float(v[mini(int(v.size() * 0.999), v.size() - 1)]),
		"max": float(v[v.size() - 1]),
		"doppi": doppi,
	}


func _riga(nome: String, d: Dictionary) -> String:
	if int(d.get("n", 0)) == 0:
		return "  %-24s (nessun campione)" % nome
	return "  %-24s n=%5d medio %6.2f p50 %6.2f p99 %6.2f p99.9 %6.2f MAX %7.2f  >2×p50: %d" \
			% [nome, int(d["n"]), float(d["medio"]), float(d["p50"]), float(d["p99"]),
			float(d["p999"]), float(d["max"]), int(d["doppi"])]


## Il carico della macchina, che va STAMPATO ACCANTO A OGNI NUMERO: senza,
## fra un mese nessuno saprà se quei 32 ms erano il gioco o il vicino di
## banco. (Su questa macchina, mentre misuravo, il carico medio è arrivato a
## 47 per via di altri lavori in parallelo.)
func _carico_macchina() -> String:
	var out := []
	OS.execute("/usr/sbin/sysctl", ["-n", "vm.loadavg"], out)
	var riga := str(out[0]).strip_edges() if not out.is_empty() else "?"
	var out2 := []
	OS.execute("/usr/sbin/sysctl", ["-n", "vm.swapusage"], out2)
	return "loadavg %s · swap %s" % [riga,
			str(out2[0]).strip_edges() if not out2.is_empty() else "?"]


func _aspetta(secondi: float) -> void:
	var fine := Time.get_ticks_usec() + int(secondi * 1_000_000.0)
	var prima := Time.get_ticks_usec()
	while Time.get_ticks_usec() < fine:
		await process_frame
		var ora := Time.get_ticks_usec()
		if _pens != null:
			_pens.passo(float(ora - prima) / 1_000_000.0)
		prima = ora


# ------------------------------------------------------------- il villaggio

func _insedia() -> bool:
	var residenti: Array = _vis.get("_residents")
	for k in QUANTI:
		var v = VS.new()
		v.dna = DNAG.generate(9000 + k * 37)
		_vis.add_child(v)
		v.mode = "resident"
		# in griglia larga: non si toccano, così nessuno passa la giornata a
		# scansarsi e la misura non diventa la misura delle collisioni
		v.position = Vector3(float(k % 7) * 3.0 - 9.0, 0, float(k / 7) * 3.0 + 4.0)
		v._enter_state("r_idle")
		var r := {"node": v, "label": "Prova%02d" % k, "dna": v.dna,
				"cell": Vector2i(k % 7, k / 7 + 3), "species": "chibi"}
		residenti.append(r)
		_vis.call("_ensure_brain", r)
	for _i in 6:
		await process_frame
	_residenti = residenti
	_cuore = _vis.call("cuore")
	return _cuore != null


## SI DÀ LORO QUALCOSA DA RACCONTARE, e si fa con la stessa chiamata del
## gioco (`EcsMondo.osserva`), non scrivendo nel grafo da fuori: un banco che
## si costruisce lo stato a mano prova il banco, non il gioco.
##
## Non a tutti, e non lo stesso numero: un villaggio in cui tutti hanno visto
## tutto è il caso più FACILE per il ritmo (nessun tentativo a vuoto), e
## misurare il caso facile è il modo di non accorgersi del costo dei
## tentativi muti.
func _dai_ricordi() -> void:
	var verbi := ["annaffia", "semina", "raccoglie", "costruisce", "taglia", "pesca", "cucina"]
	for k in _residenti.size():
		if k % 3 == 2:
			continue  # un terzo del villaggio non ha visto niente: tacerà
		var r: Dictionary = _residenti[k]
		var id := int(r["ecs"]) if r.has("ecs") else int(_vis.call("_ecs_id", r))
		for j in (1 + k % 4):
			var v := str(verbi[(k + j) % verbi.size()])
			_cuore.call("osserva", id, _cuore.call("indice_verbo", v),
					Vector3(float(k) - 12.0, 0.0, float(j) * 4.0), -1)


# ------------------------------------------------------------------- il giro

func _fonte() -> Array:
	var out := []
	for r in _residenti:
		if (r as Dictionary).has("ecs"):
			out.append({"chi": int(r["ecs"]), "id": str(r.get("label", "")), "r": r})
	return out


func _foglio(c) -> Dictionary:
	return FOGLIO.foglio(_vis, _dn, _cuore, (c as Dictionary)["r"],
			"lettera", "Mochi", hash(str(c.get("id", ""))) & 0x7FFFFFFF)


func _consegna(c, bozze: PackedStringArray, foglio: Dictionary) -> void:
	# ⚠️ QUI SI CHIUDE LA CATENA, e il banco la percorre TUTTA apposta:
	# `Pensatoio` (il ritmo) → il thread (la scrittura) → `Giudice` (la
	# scelta). Se le tre parti fossero provate solo ognuna per conto suo,
	# quello che nessun test vedrebbe è proprio la giuntura — ed è per
	# questo che il foglio viaggia col pensiero: `Giudice.scegli()` vuole
	# lo STESSO ritratto con cui è stata generata la grammatica.
	#
	# Venti bozze entrano, una esce — o nessuna, e nessuna è una risposta
	# giusta: il silenzio è il comportamento normale di tutto ciò che in
	# questo gioco parla.
	var GIU := load("res://scenes/npc/Giudice.gd")
	var rit: Dictionary = foglio.get("ritratto", {})
	var v := {"scelta": -1, "motivo": "senza ritratto", "lettera": ""}
	if not rit.is_empty():
		v = GIU.scegli(Array(bozze), rit, {"sue": _gia_dette})
	if int(v["scelta"]) >= 0:
		_gia_dette.append(str(v["testo"]))
	_consegne.append({
		"chi": str((c as Dictionary).get("id", "")),
		"bozze": Array(bozze),
		"scelta": int(v["scelta"]),
		"motivo": str(v["motivo"]),
		"lettera": str(v.get("lettera", "")),
		"quando": Time.get_ticks_msec(),
	})


# ------------------------------------------------------------------ il ritmo

## QUANTO CI METTE A PENSARE, senza il villaggio intorno. Il prompt e la
## grammatica sono quelli VERI (li scrive `Suggeritore` da un ritratto
## fabbricato qui), perché la lunghezza del prompt è metà del conto: un banco
## con «ciao» al posto del foglio misurerebbe una macchina che non esiste.
func _ritmo(percorso: String, priorita: int, n_thread: int, copie: int) -> void:
	var SUG := load("res://scenes/npc/Suggeritore.gd")
	var rit := _ritratto_finto()
	var parti: Dictionary = SUG.parti(rit)
	var gram: String = SUG.grammatica(rit)
	if parti.is_empty() or gram == "":
		print("GUASTO: il ritratto finto non produce un prompt")
		quit(1)
		return
	# LA DOMANDA SI FA IN UN POSTO SOLO, anche da un banco di prova: `Llm.gd`
	# è la porta, e un test (`test_llm_terreno`) fa la guardia perché resti
	# così.
	_llm = LLM.apri()
	if _llm == null:
		print("GUASTO: binario senza llama.cpp (serve `scons llm=yes`)")
		quit(1)
		return
	var n_ctx := int(OS.get_environment("CHIBI_CTX")) \
			if OS.get_environment("CHIBI_CTX") != "" else 1024
	var opz := {"priorita": priorita, "n_ctx": n_ctx}
	if n_thread > 0:
		opz["n_thread"] = n_thread
	var t0 := Time.get_ticks_msec()
	if not bool(_llm.call("apri_modello", percorso, opz)):
		print("GUASTO: apri_modello ha detto no: %s" % percorso)
		quit(1)
		return
	while int(_llm.call("stato")) == 1:
		await process_frame
	var t_car := Time.get_ticks_msec() - t0
	print("modello: %s" % percorso.get_file())
	print("  finestra %d · priorità %d · thread %s · carico %d ms · %s"
			% [n_ctx, priorita, ("auto" if n_thread <= 0 else str(n_thread)), t_car,
			str((_llm.call("misure") as Dictionary).get("diagnosi", ""))])
	print("  carico della macchina: %s" % _carico_macchina())
	if int(_llm.call("stato")) != 2:
		quit(1)
		return
	if _llm.has_method("memoria"):
		var mm: Dictionary = _llm.call("memoria")
		print("  memoria del processo: impronta %.0f MB" % (float(mm.get("impronta", 0)) / 1048576.0))

	# ⚠️ LA PROVA DELL'ANNULLAMENTO A VUOTO, e sta PRIMA di ogni misura perché
	# è un guasto che rende muto il villaggio senza lasciare una riga di log.
	# `annulla()` mentre non c'è niente in volo è il caso NORMALE (si cambia
	# scena, e in quel momento il villaggio non stava pensando): se la
	# bandiera restasse alzata, il primo pensiero della scena nuova nascerebbe
	# già annullato e sparirebbe in silenzio. Un test headless non può vederlo
	# — senza modello `accoda` rifiuta sempre — e quindi la guardia sta qui.
	_llm.call("annulla")
	var bp := int(_llm.call("accoda", 1, str(parti["sistema"]), str(parti["utente"]), gram,
			{"copie": 1, "max_token": 24, "seme": 4242}))
	var ep := {}
	if bp != 0:
		while ep.is_empty() and int(_llm.call("stato")) != 0:
			await process_frame
			ep = _llm.call("raccogli")
	var vivo := not ep.is_empty() and (ep.get("bozze", PackedStringArray()) as PackedStringArray).size() > 0
	print("  %s dopo un annulla() a vuoto, il pensiero dopo arriva: %s"
			% ["✓" if vivo else "GUASTO —", str(vivo)])

	# ⚠️ LE BOZZE QUI SONO CORTE APPOSTA (24 gettoni invece di 128), e non è
	# per fare prima: è per rendere VISIBILE il conto che interessa. La
	# domanda è «il prompt si paga una volta o N?», e con le bozze lunghe la
	# risposta annega nel tempo di generazione. Corte, il prompt è quasi tutto
	# il tempo — e se `secondi_prompt` di N copie è uguale a quello di UNA, il
	# riavvolgimento della memoria di attenzione sta funzionando.
	for n in [1, copie]:
		var b := int(_llm.call("accoda", 1, str(parti["sistema"]), str(parti["utente"]), gram,
				{"copie": n, "max_token": 24, "seme": 12345}))
		if b == 0:
			print("  GUASTO: accoda ha rifiutato")
			break
		var t1 := Time.get_ticks_msec()
		var e := {}
		while e.is_empty():
			await process_frame
			e = _llm.call("raccogli")
		var dt := float(Time.get_ticks_msec() - t1) / 1000.0
		var sp := float(e.get("secondi_prompt", 0.0))
		var sg := float(e.get("secondi_generazione", 0.0))
		var tp := int(e.get("token_prompt", 0))
		var tg := int(e.get("token_generati", 0))
		print("  %d copi%s: %6.2f s · prompt %d gettoni in %5.2f s (%5.1f g/s) · uscita %d gettoni in %5.2f s (%4.1f g/s) · riletture %d"
				% [n, ("a" if n == 1 else "e"), dt, tp, sp, float(tp) / maxf(sp, 0.001),
				tg, sg, float(tg) / maxf(sg, 0.001), int(e.get("riletture_prompt", -1))])
		if str(e.get("errore", "")) != "":
			print("     errore: %s" % str(e["errore"]))
		var bozze: PackedStringArray = e.get("bozze", PackedStringArray())
		if n == 1 and bozze.size() > 0:
			print("     «%s»" % str(bozze[0]).strip_edges().replace("\n", " / "))

	# la latenza dello spegnimento CON UNA GENERAZIONE IN VOLO: è il numero
	# che dice se chiudere il gioco mentre il Gufo scrive costa un'attesa
	var b2 := int(_llm.call("accoda", 1, str(parti["sistema"]), str(parti["utente"]), gram,
			{"copie": 8, "max_token": 128, "seme": 777}))
	if b2 != 0:
		for _i in 60:
			await process_frame   # un secondo: è già dentro llama
		var t_ann := Time.get_ticks_usec()
		_llm.call("annulla")
		print("  annulla() con una generazione in volo: %.3f ms"
				% (float(Time.get_ticks_usec() - t_ann) / 1000.0))
		var t_chi := Time.get_ticks_usec()
		_llm.call("chiudi")
		print("  chiudi() subito dopo               : %.1f ms"
				% (float(Time.get_ticks_usec() - t_chi) / 1000.0))
	quit(0)


## Un ritratto fabbricato: sei ricordi, cioè il caso PIENO — il prompt più
## lungo che questo gioco possa produrre, che è quello da misurare.
func _ritratto_finto() -> Dictionary:
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


# ---------------------------------------------------------------------- il go

func _go() -> void:
	var percorso := OS.get_environment("CHIBI_MODELLO")
	var priorita := int(OS.get_environment("CHIBI_PRIORITA")) \
			if OS.get_environment("CHIBI_PRIORITA") != "" else 2
	var n_thread := int(OS.get_environment("CHIBI_THREAD"))
	var copie := int(OS.get_environment("CHIBI_COPIE")) \
			if OS.get_environment("CHIBI_COPIE") != "" else 5

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	# IL MODO «RITMO»: nessun villaggio, nessun frame — solo quanto ci mette a
	# pensare, a una data priorità. Sta a parte perché sono due domande
	# diverse, e mescolarle rende tutte e due meno leggibili: qui si misura
	# QUANTO CI METTE, di là se il gioco SE NE ACCORGE.
	if OS.get_environment("CHIBI_MODO") == "ritmo":
		await _ritmo(percorso, priorita, n_thread, copie)
		return

	if change_scene_to_file("res://scenes/levels/MainLevel.tscn") != OK:
		push_error("MainLevel non si apre")
		quit(1)
		return
	for _i in 40:
		await process_frame

	_vis = _trova("visitors")
	_dn = _trova("daynight")
	if _vis == null:
		push_error("manca Visitors")
		quit(1)
		return
	if _dn != null:
		_dn.call("set_time", 0.45)   # primo pomeriggio: nessuno dorme

	if not await _insedia():
		push_error("il cuore ECS non c'è (GDExtension non caricata?)")
		quit(1)
		return
	_dai_ricordi()
	for _i in 20:
		await process_frame
	print("=== villaggio: %d residenti, cuore %s ===" % [_residenti.size(), _cuore != null])

	_apri_sonda()

	# ---------------------------------------------------------- A) il riferimento
	print("\n--- A) %d s a motore SPENTO ---" % int(SECONDI))
	_via()
	await _aspetta(SECONDI)
	var a := _stop()
	print(_riga("A) motore spento", a))
	print("     carico della macchina: %s" % _carico_macchina())

	if percorso == "":
		print("\n(nessun CHIBI_MODELLO: qui finisce — ed è la configurazione")
		print(" normale di chi non ha il modello. Il gioco è quello di sopra.)")
		quit(0)
		return

	# apre il ponte SOLO adesso: prima non deve esistere niente
	_llm = LLM.apri()
	if _llm == null:
		print("\nGUASTO: il binario non ha llama.cpp dentro (serve `scons llm=yes`).")
		quit(1)
		return

	# ------------------------------------------------- B) il caricamento vivo
	print("\n--- B) il modello si apre MENTRE si gioca ---")
	# LA FINESTRA È UNA MANOPOLA, e sotto il tetto dei 2 GB dell'autore è LA
	# manopola: la cache di attenzione cresce dritta con lei (per un 3B
	# quantizzato, ~110 MB ogni mille gettoni), e i pesi da soli sono già
	# 1.9 GB. Il portiere (`llm_gguf.h`) rifiuta PRIMA di aprire, e la
	# diagnosi dice di quanto si sfora.
	var n_ctx := int(OS.get_environment("CHIBI_CTX")) \
			if OS.get_environment("CHIBI_CTX") != "" else 1024
	var opz := {"priorita": priorita, "n_ctx": n_ctx}
	if n_thread > 0:
		opz["n_thread"] = n_thread
	_via()
	var t0 := Time.get_ticks_msec()
	if not bool(_llm.call("apri_modello", percorso, opz)):
		print("GUASTO: apri_modello ha detto no (file assente?): %s" % percorso)
		quit(1)
		return
	while int(_llm.call("stato")) == 1:  # LLM_CARICA
		await process_frame
	var b := _stop()
	var t_car := Time.get_ticks_msec() - t0
	print(_riga("B) durante il carico", b))
	print("     carico: %d ms · stato %d · finestra %d · %s" % [t_car, int(_llm.call("stato")),
			n_ctx, str((_llm.call("misure") as Dictionary).get("diagnosi", ""))])
	if _llm.has_method("memoria"):
		var mm: Dictionary = _llm.call("memoria")
		print("     memoria del processo: impronta %.0f MB · residente %.0f MB"
				% [float(mm.get("impronta", 0)) / 1048576.0,
				float(mm.get("residente", 0)) / 1048576.0])
	if int(_llm.call("stato")) != 2:  # LLM_PRONTO
		print("GUASTO: il modello non è pronto.")
		quit(1)
		return

	# ------------------------------------------------- C) il villaggio pensa
	#
	# ⚠️ A BLOCCHI ALTERNATI, e questa è la correzione più importante di tutto
	# il banco. Questa macchina non è mia sola: mentre misuravo, il carico
	# medio è passato da 13 a 47 (altri agenti che compilano e fanno girare
	# altri Godot), e il frame di riferimento è peggiorato del 5% FRA UNA
	# CORSA E L'ALTRA — cioè più di quanto costi il motore. Un banco che
	# misura A per novanta secondi e poi C per novanta secondi, su una
	# macchina che va e viene, non sta confrontando A con C: sta confrontando
	# le nove del mattino con le nove e un quarto.
	#
	# Alternando blocchi corti — spento, acceso, spento, acceso… — la deriva
	# della macchina cade su TUTTI E DUE i campioni allo stesso modo, e la
	# differenza che resta è il motore. È lo stesso motivo per cui un provino
	# affiancato si guarda affiancato e non in due giornate diverse.
	print("\n--- C) %d blocchi alternati da %d s (priorità %d) ---"
			% [BLOCCHI * 2, int(DURATA_BLOCCO), priorita])
	_pens = PENSATOIO.new()
	_pens.collega(_llm, _fonte, _foglio, _consegna)
	# il foglio di riserva con cui si tiene il motore OCCUPATO: è lo stesso
	# prompt vero (`Suggeritore` su un ritratto pieno), perché la lunghezza
	# del prompt è metà del lavoro che si vuole far pesare sul frame
	var SUGX := load("res://scenes/npc/Suggeritore.gd")
	var ritx := _ritratto_finto()
	var partix: Dictionary = SUGX.parti(ritx)
	_sistema_finto = str(partix.get("sistema", ""))
	_utente_finto = str(partix.get("utente", ""))
	_gram_finta = SUGX.grammatica(ritx)
	var fermo := PackedFloat64Array()
	var pensa := PackedFloat64Array()
	var t_c0 := Time.get_ticks_msec()
	for giro in BLOCCHI:
		# --- blocco SPENTO: si spegne il pensiero e si aspetta che il thread
		#     sia davvero fermo (se no il primo pezzo del blocco è ancora C)
		_llm.call("annulla")
		while int(_llm.call("stato")) == 3:  # LLM_PENSA
			await process_frame
		for _i in 12:
			await process_frame
		_via()
		await _aspetta(DURATA_BLOCCO)
		fermo.append_array(_campioni)
		_misura = false

		# --- blocco ACCESO: si tiene il thread OCCUPATO per tutto il blocco.
		#     Si chiedono molte copie apposta: qui non interessa raccogliere
		#     un pensiero, interessa che il motore stia macinando mentre si
		#     guarda il frame.
		_pens.passo(0.6)
		if int(_llm.call("stato")) != 3:
			_llm.call("accoda", 1, _sistema_finto, _utente_finto, _gram_finta,
					{"copie": 20, "max_token": 128, "seme": 900 + giro})
		var atteso := 0
		while int(_llm.call("stato")) != 3 and atteso < 120:
			await process_frame
			atteso += 1
		_via()
		await _aspetta(DURATA_BLOCCO)
		pensa.append_array(_campioni)
		_misura = false

	_campioni = fermo
	var a2 := _stop()
	_campioni = pensa
	var c := _stop()
	var dt_c := (Time.get_ticks_msec() - t_c0) / 1000.0
	print(_riga("  fermo (interleaved)", a2))
	print(_riga("  pensa (interleaved)", c))
	print("     carico della macchina: %s" % _carico_macchina())
	a = a2  # il riferimento buono è quello appaiato, non quello di dieci minuti fa

	# ------------------------------------------------------ D) lo spegnimento
	print("\n--- D) lo spegnimento ---")
	var t_ann := Time.get_ticks_usec()
	_pens.svuota()
	var ms_ann := float(Time.get_ticks_usec() - t_ann) / 1000.0
	var t_chi := Time.get_ticks_usec()
	_llm.call("chiudi")
	var ms_chi := float(Time.get_ticks_usec() - t_chi) / 1000.0

	# ------------------------------------------------------------ il verdetto
	var m: Dictionary = _llm.call("misure")
	var mp: Dictionary = _pens.misure()
	print("\n════════════════════════ IL VERDETTO ════════════════════════")
	print(_riga("A) motore spento", a))
	print(_riga("B) durante il carico", b))
	print(_riga("C) col cuore acceso", c))
	print("")
	print("  scarto sul frame medio : %+.3f ms (%.1f%%)"
			% [float(c.get("medio", 0)) - float(a.get("medio", 0)),
			100.0 * (float(c.get("medio", 1)) / maxf(float(a.get("medio", 1)), 0.001) - 1.0)])
	print("  scarto sul frame PEGGIO: %+.3f ms"
			% [float(c.get("max", 0)) - float(a.get("max", 0))])
	print("")
	print("  pensieri consegnati    : %d in %.0f s" % [int(mp["consegnati"]), dt_c])
	print("  tentativi muti         : %d (chi non ha visto niente)" % int(mp["muti"]))
	print("  bozze buttate          : %d%s" % [int(mp["buttati"]),
			("" if str(mp.get("errore", "")) == "" else "  (ultimo motivo: %s)" % str(mp["errore"]))])
	print("  foglio (main thread)   : ultimo %.3f ms · peggio %.3f ms"
			% [float(mp["foglio_ms"]), float(mp["foglio_ms_peggio"])])
	var u: Dictionary = mp.get("ultimo", {})
	if not u.is_empty():
		var sp := float(u["secondi_prompt"])
		var sg := float(u["secondi_generazione"])
		print("  l'ultima generazione   : prompt %d gettoni in %.2f s (%.1f g/s) ·"
				% [int(u["token_prompt"]), sp, float(u["token_prompt"]) / maxf(sp, 0.001)])
		print("                           %d bozze, %d gettoni in %.2f s (%.1f g/s) · riletture del prompt: %d"
				% [int(u["bozze"]), int(u["token_generati"]), sg,
				float(u["token_generati"]) / maxf(sg, 0.001), int(u.get("riletture_prompt", 0))])
	var per_pensiero := dt_c / maxf(float(int(mp["consegnati"])), 1.0)
	print("  un pensiero ogni       : %.1f s" % per_pensiero)
	print("  ⇒ UN VICINO OGNI       : %.0f s (%.1f min) con %d abitanti"
			% [PENSATOIO.attesa_stimata(_residenti.size(), per_pensiero),
			PENSATOIO.attesa_stimata(_residenti.size(), per_pensiero) / 60.0,
			_residenti.size()])
	print("")
	print("  annulla()              : %.3f ms (non deve bloccare)" % ms_ann)
	print("  chiudi()               : %.3f ms (si paga una volta sola)" % ms_chi)
	print("  carico modello         : %d ms" % t_car)
	print("  memoria del processo   : %.0f MB" % (float(OS.get_static_memory_usage()) / 1048576.0))
	print("  llm.misure             : %s" % str(m))
	for k in mini(_consegne.size(), 3):
		var cg: Dictionary = _consegne[k]
		print("\n  --- consegna a %s: %d bozze, scelta la %d ---"
				% [str(cg["chi"]), (cg["bozze"] as Array).size(), int(cg["scelta"])])
		print("      giudizio: %s" % str(cg["motivo"]))
		for t in (cg["bozze"] as Array):
			print("      ·  " + str(t).strip_edges().replace("\n", " / "))
		if int(cg["scelta"]) >= 0:
			print("      ⇒ ESCE: %s" % str(cg["lettera"]).replace("\n", " / "))
	print("═════════════════════════════════════════════════════════════")
	quit(0)
