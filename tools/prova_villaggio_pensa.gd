extends SceneTree
## IL VILLAGGIO CHE PENSA DA SOLO — la Fase 5 cablata, in una partita vera.
##
##   CHIBI_MODELLO=/percorso/al.gguf \
##     ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --resolution 1280x720 --script res://tools/prova_villaggio_pensa.gd
##
##   CHIBI_MINUTI=12   quanto dura la vita (di serie 12)
##   CHIBI_QUANTI=28   quanti residenti (di serie 28: il tetto vero)
##   CHIBI_BLOCCHI=4   quante coppie di blocchi per il metro del fotogramma
##   CHIBI_RISERVA=0   spegne il cancello della RAM (un banco deve poter
##                     misurare anche il modello che il gioco rifiuterebbe)
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ ESISTE, E COSA NESSUN ALTRO BANCO PUÒ DIRE
## ────────────────────────────────────────────────────────────────────────
##
## Gli altri banchi della Fase 5 accendono il ritmo **a mano**: si costruiscono
## il loro Pensatoio, la loro fonte, il loro foglio, la loro consegna. Provano
## i pezzi, e li provano bene — ma non provano il gioco: se il nodo che li
## mette insieme non esistesse (ed è stato così fino a oggi), sarebbero tutti
## verdi lo stesso.
##
## Qui non si collega NIENTE. Si apre il MainLevel vero — dove il nodo
## `Pensieri` sta in scena accanto a `Percezione` — ci si mettono i residenti
## veri, si fa camminare Mochi come cammina un giocatore, e si guarda.
## Le quattro domande, e sono quelle dell'autore:
##
##  A. **il fotogramma se ne accorge?** Misura APPAIATA, blocchi alternati
##     nella stessa corsa: due processi diversi non sono confrontabili
##     (compilazione degli shader, cache, e soprattutto le altre sessioni di
##     agente che girano su questa macchina).
##  B. **quante deduzioni entrano, quante ricevute si pagano, quanti vicini
##     cambiano mestiere** in N minuti di partita.
##  C. **con che ritmo**: ogni quanto, in pratica, un vicino riceve un
##     pensiero con ventotto residenti.
##  D. **e quando il gioco se ne va**: cambio di scena con una generazione in
##     volo, e quanti millisecondi passano prima che il motore torni libero.
##
## ⚠️ LE TRAPPOLE DI MISURA, tutte già pagate in questo progetto:
##
##  · **ci si aggancia a `process_frame`, non a `_process`**: l'ordine del
##    frame è `process_frame` → `_process` dei nodi → tween → disegno, e una
##    sonda in mezzo somma due spostamenti che il giocatore non ha mai visto
##    insieme (è la lezione del tween della seduta);
##  · **il vsync si spegne**: acceso, ogni frame dura 16.6 ms per definizione
##    e le due colonne uscirebbero identiche anche se il motore si mangiasse
##    metà macchina;
##  · **i blocchi A e B durano UGUALE**: il massimo di un campione cresce col
##    numero di campioni, e confrontare venti secondi con novanta è
##    confrontare venti tiri di dado con novanta;
##  · **il carico della macchina si stampa accanto a ogni numero**: senza, fra
##    un mese nessuno saprà se quei 32 ms erano il gioco o il vicino di banco.
##    Su questa macchina girano altre sessioni di agente, e lo si vede;
##  · **l'orologio del giorno si ferma**: un giorno dura quattro minuti e
##    questo banco parecchi. Senza, a metà prova i vicini rientrano in casa
##    (`is_hidden`), smettono di essere candidati e il banco misura il buio.

const LLM := preload("res://systems/Llm.gd")
const PENSATOIO := preload("res://scenes/npc/Pensatoio.gd")
const PERCEZIONE := preload("res://scenes/npc/Percezione.gd")
const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")

## Il tetto vero del villaggio (`Visitors.MAX_RESIDENTS`): misurare con tre
## sarebbe misurare un gioco che non esiste.
const QUANTI_DEF := 28
const BLOCCHI_DEF := 4
const DURATA_BLOCCO := 12.0
const MINUTI_DEF := 12.0

## Il giro di Mochi: un giocatore che cammina, non che corre.
const MOCHI_PASSO := 3.0
const VITA_PASSO := 0.25

var _vis: Node = null
var _dn: Node = null
var _build: Node = null
var _player: Node3D = null
var _cuore: Object = null
var _pensieri: Node = null
var _residenti: Array = []
var _osservatore: Object = null      # un maniglione in più, solo per guardare

var _misura := false
var _campioni := PackedFloat64Array()
var _t_ultimo := 0

## L'ORACOLO INDIPENDENTE DELLE RICEVUTE. I due contatori di `Visitors` sono
## strumentazione dentro il codice di produzione, e la suite headless non li
## può provare (`Visitors` non si istanzia senza villaggio): chiedere a loro
## se hanno ragione sarebbe chiedere al giudice se è d'accordo con sé stesso —
## lo stesso errore che `tools/misura_cammino.gd` esiste per non commettere.
## Perciò qui si conta la STESSA cosa da un'altra parte: le bandiere sul
## grafo, lette dal ponte. La chiave è `id:indice:quando` e non `id:indice`,
## perché gli slot delle deduzioni si riciclano — due deduzioni diverse dello
## stesso vicino possono stare nello stesso posto.
var _ricevute_viste := {}
var _spese_viste := {}

var _minuti := MINUTI_DEF
var _quanti := QUANTI_DEF
var _blocchi := BLOCCHI_DEF


func _init() -> void:
	_go()


# =========================================================================
# LE MISURE DEL FOTOGRAMMA
# =========================================================================

func _process(_d: float) -> bool:
	return false


## Si AGGANCIA al segnale, non si mette in un ciclo con `await`: un ciclo che
## aspetta `process_frame` dentro una coroutine si rimette in coda dopo tutti
## gli altri risvegli, e finirebbe per campionare un frame sì e uno no.
func _sonda() -> void:
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
	var doppi := 0
	for x in v:
		if float(x) > p50 * 2.0:
			doppi += 1
	return {"n": v.size(), "medio": somma / float(v.size()), "p50": p50,
			"p99": float(v[mini(int(v.size() * 0.99), v.size() - 1)]),
			"max": float(v[v.size() - 1]), "doppi": doppi}


func _fondi(a: Dictionary, b: Dictionary) -> Dictionary:
	if int(a.get("n", 0)) == 0:
		return b
	if int(b.get("n", 0)) == 0:
		return a
	var na := float(a["n"])
	var nb := float(b["n"])
	return {"n": int(na + nb),
			"medio": (float(a["medio"]) * na + float(b["medio"]) * nb) / (na + nb),
			"p50": (float(a["p50"]) * na + float(b["p50"]) * nb) / (na + nb),
			"p99": maxf(float(a["p99"]), float(b["p99"])),
			"max": maxf(float(a["max"]), float(b["max"])),
			"doppi": int(a["doppi"]) + int(b["doppi"])}


func _riga(nome: String, d: Dictionary) -> String:
	if int(d.get("n", 0)) == 0:
		return "  %-22s (nessun campione)" % nome
	return "  %-22s n=%5d  medio %6.2f  p50 %6.2f  p99 %6.2f  MAX %7.2f  >2×p50: %d" \
			% [nome, int(d["n"]), float(d["medio"]), float(d["p50"]),
			float(d["p99"]), float(d["max"]), int(d["doppi"])]


func _carico() -> String:
	var out := []
	OS.execute("/usr/sbin/sysctl", ["-n", "vm.loadavg"], out)
	var riga := str(out[0]).strip_edges() if not out.is_empty() else "?"
	var out2 := []
	OS.execute("/usr/sbin/sysctl", ["-n", "vm.swapusage"], out2)
	return "loadavg %s · swap %s" % [riga,
			str(out2[0]).strip_edges() if not out2.is_empty() else "?"]


# =========================================================================
# IL MONDO
# =========================================================================

func _go() -> void:
	_minuti = float(OS.get_environment("CHIBI_MINUTI")) \
			if OS.get_environment("CHIBI_MINUTI") != "" else MINUTI_DEF
	_quanti = int(OS.get_environment("CHIBI_QUANTI")) \
			if OS.get_environment("CHIBI_QUANTI") != "" else QUANTI_DEF
	_blocchi = int(OS.get_environment("CHIBI_BLOCCHI")) \
			if OS.get_environment("CHIBI_BLOCCHI") != "" else BLOCCHI_DEF

	print("")
	print("════════ IL VILLAGGIO CHE PENSA DA SOLO ════════")
	print("  %s" % LLM.riga_di_stato())
	print("  modello: %s" % (LLM.percorso_modello() if LLM.percorso_modello() != "" else "(nessuno)"))
	print("  porta:   Llm.acceso() = %s" % str(LLM.acceso()))
	print("  macchina: %s" % _carico())
	if not LLM.acceso():
		print("")
		print("  La porta è chiusa: il gioco gira coi testi scritti a mano.")
		print("  Per questo banco serve CHIBI_MODELLO=/percorso/al.gguf su un")
		print("  binario compilato con `scons llm=yes`.")
		quit(1)
		return

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_sonda()

	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 8:
		await process_frame
	var livello := current_scene
	if livello == null:
		print("GUASTO: il MainLevel non si è caricato")
		quit(1)
		return
	_vis = livello.get_node_or_null("Visitors")
	_dn = livello.get_node_or_null("DayNight")
	_build = livello.get_node_or_null("BuildSystem")
	_player = livello.get_node_or_null("Player") as Node3D
	# IL GRUPPO È L'API — come per `Percezione`: chi userà il ritmo (le lettere
	# del Gufo, un domani) non deve conoscere il percorso del nodo. Qui si
	# guardano tutte e due le cose, perché sono due domande diverse: che il
	# nodo sia NELLA SCENA (il nome) e che si sia ACCESO (il gruppo, in cui
	# entra solo se la porta è aperta).
	_pensieri = livello.get_node_or_null("Pensieri")
	var dal_gruppo := get_first_node_in_group("pensieri")
	if _vis == null or _player == null:
		print("GUASTO: Visitors=%s Player=%s" % [_vis, _player])
		quit(1)
		return
	# ⚠️ LA PRIMA COSA CHE QUESTO BANCO PROVA, ed è la ragione per cui esiste:
	# il nodo dev'essere NELLA SCENA, non costruito qui.
	if _pensieri == null:
		print("GUASTO: il MainLevel non ha il nodo «Pensieri» — la Fase 5 non è cablata")
		quit(1)
		return
	if dal_gruppo != _pensieri:
		print("GUASTO: il nodo c'è ma non è nel gruppo «pensieri» — non si è acceso")
		quit(1)
		return
	if _build != null:
		_build.call("set_persist_for_debug", false)
	if _dn != null:
		_dn.set("cycle_seconds", 1000000.0)
		_dn.set("time", 0.42)
	await create_timer(1.0).timeout

	_costruisci()
	if not await _insedia():
		print("GUASTO: nessun cuore ECS")
		quit(1)
		return
	print("  residenti: %d · cuore ECS: sì" % _residenti.size())
	await create_timer(2.0).timeout
	var con_luoghi := 0
	var con_meta := 0
	for r in _residenti:
		var rr: Dictionary = r
		var l: Array = rr.get("luoghi", [])
		if l.is_empty():
			continue
		con_luoghi += 1
		for voce in l:
			if bool((voce as Dictionary).get("ok", false)):
				con_meta += 1
				break
	# ⚠️ SE QUESTO NUMERO È ZERO, il banco misurerà zero ricevute e non sarà
	# colpa del cablaggio: è il mondo che non ha posti dove andare.
	print("  residenti con i luoghi calcolati: %d · con almeno un posto raggiungibile: %d"
			% [con_luoghi, con_meta])

	# UN MANIGLIONE IN PIÙ, solo per guardare. Il motore è UNO per processo
	# (`traduttore()` è uno static), quindi da qui si può chiedere `libero()`
	# anche dopo che il livello — e con lui il nodo — se ne sono andati.
	_osservatore = LLM.apri()

	await _aspetta_il_carico()
	await _dai_da_pensare()
	await _il_metro_del_fotogramma()
	await _la_vita()
	await _lo_spegnimento()
	quit(0)


## LA CELLA DI CHI ABITA QUI: griglia larga, lontano dal letto del fiume.
func _cella(k: int) -> Vector2i:
	return Vector2i(-6 + (k % 7) * 2, 3 + (k / 7) * 2)


## ⚠️ **IL VILLAGGIO DEVE AVERE DEI POSTI, O LE RICEVUTE NON SI PAGANO MAI.**
## Questa funzione è nata da una misura: alla prima corsa il banco insediava
## ventotto residenti in un prato NUDO — nessun cespuglio, nessuna panchina —
## e il risultato era **cinque deduzioni entrate nel grafo e ZERO ricevute**.
## Non era un guasto del cablaggio: era il mondo. La ricevuta chiede
## `Deduzioni.meta_del_gesto`, che chiede al risolutore dove andrà il corpo, e
## in un prato vuoto nessuno dei cinque luoghi è `ok` — quindi nessun piano,
## quindi nessuna direzione a cui legare lo sguardo, quindi silenzio.
##
## È anche la ragione per cui `_insedia` mette i corpi **sulla propria cella**
## invece che in una griglia comoda: `Visitors` calcola i luoghi a partire da
## `home = cell`, e un corpo che sta trenta metri dalla sua cella pianifica
## per un posto e cammina in un altro.
func _costruisci() -> void:
	if _build == null:
		return
	var messi := 0
	for k in 4:
		var z := 3 + k * 2
		for x in [-9, 9]:
			_build.call("place_cell", Vector2i(x, z), "Cespuglio", 0, false)
			messi += 1
		for x in [-3, 3]:
			_build.call("place_cell", Vector2i(x, z), "Panchina", 0, false)
			messi += 1
	_build.call("aggiorna_varchi_ora")
	print("  posti nel mondo: %d cespugli, %d panchine (chiesti %d)"
			% [(_build.call("get_placed_by_name", "Cespuglio") as Array).size(),
			(_build.call("get_placed_by_name", "Panchina") as Array).size(), messi])


## I residenti veri, ognuno sulla sua cella (vedi `_costruisci`).
func _insedia() -> bool:
	var residenti: Array = _vis.get("_residents")
	for k in _quanti:
		var c := _cella(k)
		var v = VS.new()
		v.dna = DNAG.generate(9000 + k * 37)
		_vis.add_child(v)
		v.mode = "resident"
		v.position = Vector3(float(c.x), 0.0, float(c.y))
		v._enter_state("r_idle")
		var r := {"node": v, "label": "Prova%02d" % k, "dna": v.dna,
				"cell": c, "species": "chibi"}
		residenti.append(r)
		_vis.call("_ensure_brain", r)
	for _i in 8:
		await process_frame
	_residenti = residenti
	_cuore = _vis.call("cuore")
	return _cuore != null


## SI ASPETTA CHE IL MODELLO SIA APERTO — dal nodo, non da qui: il banco
## guarda `misure()["stato"]` e basta. È la differenza fra provare il gioco e
## provare il banco.
func _aspetta_il_carico() -> void:
	var t0 := Time.get_ticks_msec()
	print("")
	print("  ── il nodo apre il modello da solo (sul thread, mentre il gioco disegna) ──")
	_via()
	while float(Time.get_ticks_msec() - t0) < 240000.0:
		var m: Dictionary = _pensieri.call("misure")
		if str(m["stato"]) == "pensa" or str(m["stato"]) == "guasto":
			break
		await create_timer(0.25).timeout
	var d := _stop()
	var m: Dictionary = _pensieri.call("misure")
	print("  stato: %s%s  (in %.1f s)" % [str(m["stato"]),
			("" if str(m.get("diagnosi", "")) == "" else " — " + str(m["diagnosi"])),
			float(Time.get_ticks_msec() - t0) / 1000.0])
	print(_riga("durante il carico", d))
	print("  %s" % _carico())
	if str(m["stato"]) != "pensa":
		print("GUASTO: il modello non si è aperto")
		quit(1)


## SI DÀ LORO QUALCOSA DA RACCONTARE, e con la stessa chiamata del gioco: il
## bus della percezione, dai posti veri, con Mochi che ci sta davanti. Un
## banco che scrivesse nel grafo da fuori proverebbe il banco.
##
## Non a tutti e non lo stesso numero: un villaggio in cui tutti hanno visto
## tutto è il caso più FACILE per il ritmo (nessun tentativo a vuoto), e
## misurare il caso facile è il modo di non accorgersi del costo dei muti.
func _dai_da_pensare() -> void:
	var verbi := ["annaffia", "semina", "raccoglie", "costruisce", "taglia", "pesca", "cucina"]
	var quanti := 0
	for k in _residenti.size():
		if k % 3 == 2:
			continue     # un terzo del villaggio non ha visto niente: tacerà
		var node := (_residenti[k] as Dictionary).get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		for j in (1 + k % 3):
			var dove: Vector3 = node.global_position + Vector3(
					cos(float(j) * 2.1) * 3.0, 0.0, sin(float(j) * 2.1) * 3.0)
			_player.global_position = Vector3(dove.x, _player.global_position.y, dove.z)
			await process_frame
			call_group("percezione", "accaduto", str(verbi[(k + j) % verbi.size()]), dove, "")
			quanti += 1
			# i ricordi devono avere ETÀ diverse, o il «più pesante» sarebbe
			# sempre l'ultimo per costruzione
			await create_timer(0.12).timeout
	print("  gesti di Mochi visti dal villaggio: %d" % quanti)
	await create_timer(2.0).timeout


# =========================================================================
# A. IL METRO DEL FOTOGRAMMA — blocchi alternati, stessa corsa
# =========================================================================

func _il_metro_del_fotogramma() -> void:
	print("")
	print("  ── A. IL FOTOGRAMMA: %d coppie di blocchi da %.0f s, alternati ──"
			% [_blocchi, DURATA_BLOCCO])
	var spento := {}
	var acceso := {}
	for i in _blocchi:
		# SPENTO: il nodo non gira. Il modello resta APERTO (la RAM è quella
		# di prima): quello che si toglie è il ritmo, la costruzione dei fogli
		# e il thread che scrive — cioè esattamente quello che il cablaggio
		# aggiunge al gioco.
		_pensieri.call("debug_pausa", true)
		await create_timer(0.5).timeout
		_via()
		await create_timer(DURATA_BLOCCO).timeout
		spento = _fondi(spento, _stop())

		_pensieri.call("debug_pausa", false)
		await create_timer(0.5).timeout
		_via()
		await create_timer(DURATA_BLOCCO).timeout
		acceso = _fondi(acceso, _stop())
	print(_riga("nodo spento", spento))
	print(_riga("il villaggio pensa", acceso))
	if int(spento.get("n", 0)) > 0 and int(acceso.get("n", 0)) > 0:
		var da := float(spento["medio"])
		var a := float(acceso["medio"])
		print("  scarto sul fotogramma medio: %+.2f ms (%+.1f%%)"
				% [a - da, 100.0 * (a - da) / maxf(da, 0.001)])
	var m: Dictionary = _pensieri.call("misure")
	print("  il costo del nodo, cronometrato sulla riga: passo medio %.1f µs, peggiore %.1f µs"
			% [float(m["passo_us_medio"]), float(m["passo_us_peggio"])])
	print("  %s" % _carico())


# =========================================================================
# B/C. LA VITA — Mochi cammina, il villaggio pensa, e si conta
# =========================================================================

func _la_vita() -> void:
	print("")
	print("  ── B. LA VITA: %.0f minuti, %d residenti, Mochi che cammina ──"
			% [_minuti, _residenti.size()])
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260812
	var mete := []
	for r in _residenti:
		var n := (r as Dictionary).get("node") as Node3D
		if n != null and is_instance_valid(n):
			mete.append(n.global_position)
	var meta: Vector3 = mete[rng.randi() % mete.size()]
	var sosta := 0.0
	var verbi := ["annaffia", "costruisce", "raccoglie", "semina"]

	var t := 0.0
	var prossimo_gesto := 8.0
	var prossimo_rapporto := 60.0
	var prossimo_oracolo := 2.0
	var fine := _minuti * 60.0
	_via()
	while t < fine:
		# MOCHI CAMMINA come cammina un giocatore: da un posto all'altro, con
		# qualche secondo di sosta. Senza di lei nessuna ricevuta si paga —
		# ed è il guasto che tutta questa fase esiste per rendere impossibile.
		var p := _player.global_position
		if sosta > 0.0:
			sosta -= VITA_PASSO
		elif p.distance_to(Vector3(meta.x, p.y, meta.z)) < 0.6:
			sosta = rng.randf_range(2.0, 6.0)
			meta = mete[rng.randi() % mete.size()]
		else:
			var d := (Vector3(meta.x, p.y, meta.z) - p).normalized()
			_player.global_position = p + d * MOCHI_PASSO * VITA_PASSO
		# ...e ogni tanto FA qualcosa, o dopo qualche minuto i ricordi si
		# raffreddano sotto soglia e non c'è più niente da dedurre
		prossimo_gesto -= VITA_PASSO
		if prossimo_gesto <= 0.0:
			prossimo_gesto = rng.randf_range(6.0, 14.0)
			call_group("percezione", "accaduto",
					str(verbi[rng.randi() % verbi.size()]),
					_player.global_position, "")
		prossimo_oracolo -= VITA_PASSO
		if prossimo_oracolo <= 0.0:
			prossimo_oracolo = 2.0
			_conta_dal_grafo()
		prossimo_rapporto -= VITA_PASSO
		if prossimo_rapporto <= 0.0:
			prossimo_rapporto = 60.0
			print("    t=%5.0f s  %s" % [t, _riassunto()])
		await create_timer(VITA_PASSO).timeout
		t += VITA_PASSO
	var d := _stop()
	print("")
	print(_riga("la vita intera", d))
	print("  %s" % _carico())
	_rapporto_finale(fine)


## LE BANDIERE, lette dal grafo. Due secondi di passo: una ricevuta pagata
## resta scritta sulla deduzione finché quella vive (decine di secondi), e la
## deduzione vive molto più a lungo del campionamento.
func _conta_dal_grafo() -> void:
	var k: Dictionary = _cuore.call("debug_deduzioni_costanti")
	var b_ric := int(k.get("d_ricevuta", 0))
	var b_spe := int(k.get("d_spesa", 0))
	for riga in _residenti:
		var rr: Dictionary = riga
		if not rr.has("ecs"):
			continue
		var id := int(rr["ecs"])
		for d in ((_cuore.call("debug_deduzioni", id) as Dictionary)
				.get("deduzioni", []) as Array):
			var dd: Dictionary = d
			var chiave := "%d:%.3f:%d" % [id, float(dd.get("quando", 0.0)),
					int(dd.get("obiettivo", 0))]
			if int(dd.get("bandiere", 0)) & b_ric != 0:
				_ricevute_viste[chiave] = true
			if int(dd.get("bandiere", 0)) & b_spe != 0:
				_spese_viste[chiave] = true


func _riassunto() -> String:
	var m: Dictionary = _pensieri.call("misure")
	var c: Dictionary = _vis.call("debug_deduzioni_contatori")
	var r: Dictionary = m.get("ritmo", {})
	return "pensieri %d · dedotte %d · ricevute %d · dirotti %d · muti %d · in volo %s" \
			% [int(m["pensieri"]), int(m["dedotte"]), int(c["ricevute"]), int(c["dirotti"]),
			int(r.get("muti", 0)), str(r.get("in_volo", false))]


func _rapporto_finale(secondi: float) -> void:
	var m: Dictionary = _pensieri.call("misure")
	var c: Dictionary = _vis.call("debug_deduzioni_contatori")
	var r: Dictionary = m.get("ritmo", {})
	var vive := 0
	for riga in _residenti:
		var rr: Dictionary = riga
		if not rr.has("ecs"):
			continue
		vive += ((_cuore.call("debug_deduzioni", int(rr["ecs"])) as Dictionary)
				.get("deduzioni", []) as Array).size()
	print("")
	print("  ── C. IL RITMO, in %.0f minuti di partita con %d residenti ──"
			% [secondi / 60.0, _residenti.size()])
	print("     pensieri consegnati dal motore ....... %d" % int(m["pensieri"]))
	print("     deduzioni ENTRATE nel grafo .......... %d" % int(m["dedotte"]))
	print("     bocciate (Giudice o ponte) ........... %d" % int(m["bocciate"]))
	print("     deduzioni ancora vive adesso ......... %d" % vive)
	print("     RICEVUTE PAGATE (teste girate) ....... %d" % int(c["ricevute"]))
	print("     MESTIERI cambiati per una deduzione .. %d" % int(c["dirotti"]))
	# L'ORACOLO INDIPENDENTE: le stesse due cose contate dalle bandiere sul
	# grafo invece che dai contatori del registro. Non devono combaciare al
	# numero — una deduzione può scadere fra due campionamenti, e il
	# campionamento è ogni due secondi — ma se il contatore dicesse zero
	# mentre il grafo è pieno di bandiere (o viceversa), il contatore mente.
	print("     ...e contate dalle BANDIERE del grafo:  ricevute %d · spese %d"
			% [_ricevute_viste.size(), _spese_viste.size()])
	print("     tentativi muti (niente da dire) ...... %d" % int(r.get("muti", 0)))
	print("     bozze buttate dal ritmo .............. %d" % int(r.get("buttati", 0)))
	print("     pensieri persi dal motore ............ %d" % int(r.get("persi", 0)))
	if str(r.get("errore", "")) != "":
		print("     ultimo errore del motore ............. %s" % str(r["errore"]))
	var porte: Dictionary = m.get("porte", {})
	if not porte.is_empty():
		print("     perché le consegne non hanno prodotto niente:")
		for k in porte:
			print("        %3d × %s" % [int(porte[k]), str(k)])
	var per_pensiero := secondi / maxf(float(int(m["pensieri"])), 1.0)
	print("")
	print("     un pensiero ogni ................ %.1f s (misurato)" % per_pensiero)
	print("     un vicino ne riceve uno ogni .... %.1f s = %.1f min (Pensatoio.attesa_stimata)"
			% [PENSATOIO.attesa_stimata(_residenti.size(), per_pensiero),
			PENSATOIO.attesa_stimata(_residenti.size(), per_pensiero) / 60.0])
	print("     il foglio costa ................. %.2f ms (peggiore %.2f ms)"
			% [float(r.get("foglio_ms", 0.0)), float(r.get("foglio_ms_peggio", 0.0))])
	print("     la consegna costa ............... %.2f ms (peggiore %.2f ms)"
			% [float(m["consegna_ms"]), float(m["consegna_ms_peggio"])])


# =========================================================================
# D. LO SPEGNIMENTO — il gioco se ne va con una generazione in volo
# =========================================================================

## ⚠️ QUI L'OSSERVATORE NON È INNOCENTE, e va dichiarato: questo banco tiene
## un maniglione in più, quindi quando il livello se ne va **non è l'ultimo a
## morire** e il distruttore del ponte non parte. È voluto: così quello che si
## misura è l'uscita VERA del nodo (`_exit_tree` → `svuota()` → `annulla()`),
## non la rete che sta sotto. Il distruttore ha già il suo banco
## (`tools/prova_uscita.gd`, scene 1 e 2) e la chiusura del processo il suo
## (lo scaricamento della GDExtension).
func _lo_spegnimento() -> void:
	print("")
	print("  ── D. LO SPEGNIMENTO: si torna al titolo con un pensiero in volo ──")
	if _osservatore == null:
		print("     (nessun osservatore: non si può misurare)")
		return
	# si aspetta che ce ne sia davvero uno in volo, o «zero millisecondi»
	# sarebbe vero comunque
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) < 300000.0:
		var r: Dictionary = (_pensieri.call("misure") as Dictionary).get("ritmo", {})
		if bool(r.get("in_volo", false)) and not bool(_osservatore.call("libero")):
			break
		await create_timer(0.2).timeout
	if bool(_osservatore.call("libero")):
		print("     (non sono riuscito a cogliere un pensiero in volo: niente da misurare)")
		return
	print("     c'è un pensiero in volo e il motore è occupato. Si cambia scena.")
	var t := Time.get_ticks_msec()
	change_scene_to_file("res://scenes/ui/TitleScreen.tscn")
	var liberato := -1
	while float(Time.get_ticks_msec() - t) < 60000.0:
		await process_frame
		if bool(_osservatore.call("libero")):
			liberato = Time.get_ticks_msec() - t
			break
	if liberato < 0:
		print("     ⚠️ GUASTO: dopo 60 s il motore è ANCORA occupato — nessuno ha fermato niente")
	else:
		print("     il motore è tornato libero in %d ms" % liberato)
	# e la controprova che conta davvero: il motore non resta incastrato.
	# (È il difetto che c'era: `annulla()` dentro la finestra buttava la coda
	# e lasciava `_in_volo` acceso PER SEMPRE, cioè il villaggio muto.)
	var ok := bool(_osservatore.call("libero"))
	print("     e ACCETTA ANCORA lavoro: libero()=%s · stato=%s"
			% [str(ok), ["SPENTO", "CARICA", "PRONTO", "PENSA", "GUASTO"][int(_osservatore.call("stato"))]])
	print("  %s" % _carico())
