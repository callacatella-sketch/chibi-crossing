extends SceneTree
## LA PROVA CHE CHIUDE LA FASE 5 — due partite appaiate, e nessuno che spinge.
##
##   CHIBI_MODELLO=/percorso/gemma3-4b.gguf CHIBI_FOTO=/dove/le/foto \
##     ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --resolution 1280x720 --script res://tools/prova_fase5_finale.gd
##
##   CHIBI_MINUTI=20   quanto dura la vita (di serie 20)
##   CHIBI_QUANTI=28   quanti residenti (di serie 28: il tetto vero)
##   CHIBI_BLOCCHI=3   coppie di blocchi per il metro del fotogramma
##   CHIBI_SEME=4242   il seme del villaggio: STESSO seme nei due bracci
##   CHIBI_TRACCIA=…   dove scrivere la traccia del comportamento (A/B)
##   CHIBI_FOTO=…      dove scrivere le foto (senza, non ne fa)
##   CHIBI_RISERVA=0   (lo legge `Pensieri`) spegne il cancello della RAM
##
## ────────────────────────────────────────────────────────────────────────
## COSA HA QUESTO BANCO CHE GLI ALTRI CINQUE NON HANNO
## ────────────────────────────────────────────────────────────────────────
##
## `prova_villaggio_pensa` misura il ritmo, ma i gesti di Mochi li **spinge
## lui**, chiamando `call_group("percezione", "accaduto", …)` a mano. È
## legittimo — quella è l'API vera — ma vuol dire che il banco tiene in mano
## un pezzo della catena. Qui no: Mochi si avvicina a un'aiuola VERA e
## **preme E** (`InputEventAction` dato in pasto a `Input.parse_input_event`),
## e da lì in poi è tutto gioco: `Garden._unhandled_input` → `_water` →
## `call_group("percezione", …)` → `Percezione.accaduto` → la testa dei
## testimoni che si gira → il grafo dei ricordi in C++ → il foglio → il
## modello → il Giudice → il ponte → la ricevuta → il mestiere.
##
## **Il banco non tocca nessun anello di quella catena.** Le uniche cose che
## fa sono le tre che un giocatore fa: muove Mochi, preme E, e guarda.
##
## Le sei domande dell'autore, e da dove esce ogni numero:
##
##  1. deduzioni entrate nel grafo / mestieri cambiati → `Pensieri.misure()`
##     e `Visitors.debug_deduzioni_contatori()`, più l'oracolo indipendente
##     delle bandiere lette dal grafo (`debug_deduzioni`);
##  2. ricevute pagate e **a che distanza stava Mochi** → si campiona il
##     grafo a 10 Hz e, nell'istante in cui una bandiera `D_RICEVUTA` compare,
##     si misura la distanza VERA fra il giocatore e quel corpo;
##  3. allucinazioni → per ogni deduzione che entra, ognuno dei suoi «perché»
##     dev'essere una riga VIVA del grafo dei ricordi di quel vicino. La
##     verifica non passa dal Giudice né dal ponte (sarebbe chiedere al
##     giudice se è d'accordo con sé stesso): confronta le copie con
##     `debug_grafo(id)`, che è l'anello vero;
##  4. il fotogramma → misura APPAIATA a blocchi alternati nella stessa corsa;
##  5. la RAM → `memoria()["impronta"]` sul ponte (il nome della classe
##     nativa ha una casa sola, ed è `systems/Llm.gd`), **mai `ps rss`** (che su
##     macOS conta male le pagine mappate da file);
##  6. le foto → tre macchine (tre quarti, profilo, e la camera VERA del
##     gioco) sull'istante in cui una deduzione diventa un gesto.
##
## ⚠️ **E GIRA IDENTICO SENZA MODELLO.** Se `Llm.acceso()` è falso il banco
## NON si ferma: fa lo stesso villaggio, con lo stesso seme, per lo stesso
## tempo, e scrive la stessa traccia. È l'unico modo di rispondere alla
## domanda B — «indistinguibile?» — invece di dichiararlo.
##
## ⚠️ LE TRAPPOLE DI MISURA (tutte già pagate in questo progetto):
##  · ci si aggancia a `process_frame`, non a un `_process` in mezzo al frame;
##  · il vsync si spegne, o ogni fotogramma dura 16.6 ms per definizione;
##  · i blocchi A e B durano UGUALE (un massimo cresce col numero di tiri);
##  · il carico della macchina si stampa accanto a ogni numero;
##  · l'orologio del giorno si ferma: un giorno dura quattro minuti e questo
##    banco venti — senza, a metà prova i vicini vanno a dormire, si
##    rimpiccioliscono a scala 0.03 e le foto inquadrano un granello al buio;
##  · lo scatto arriva DOPO due `frame_post_draw`: il primo salverebbe il
##    fotogramma precedente.

const LLM := preload("res://systems/Llm.gd")
const PENSATOIO := preload("res://scenes/npc/Pensatoio.gd")
const DEDUZIONI := preload("res://scenes/npc/Deduzioni.gd")
const PERCEZIONE := preload("res://scenes/npc/Percezione.gd")

const QUANTI_DEF := 28
const BLOCCHI_DEF := 3
const DURATA_BLOCCO := 45.0
const MINUTI_DEF := 20.0
const SEME_DEF := 4242

## Il giro di Mochi: un giocatore che cammina, non che corre.
const MOCHI_PASSO := 3.0
const PASSO := 0.1                  # il battito del banco, in secondi di gioco

## Il villaggio: dodici case in griglia, e poi i posti che i piani sanno
## nominare. Le celle sono le stesse nei due bracci — la prima regola di un
## confronto appaiato.
const CASE_RIGHE := 4
const CASE_COLONNE := 7

var _dove_foto := ""
var _traccia_fuori := ""
var _minuti := MINUTI_DEF
var _quanti := QUANTI_DEF
var _blocchi := BLOCCHI_DEF
var _seme := SEME_DEF

var _vis: Node = null
var _dn: Node = null
var _build: Node = null
var _garden: Node = null
var _player: Node3D = null
var _cuore: Object = null
var _pensieri: Node = null
var _osservatore: Object = null
var _residenti: Array = []
var _aiuole: Array = []

# --- il fotogramma ---------------------------------------------------------
var _misura := false
var _campioni := PackedFloat64Array()
var _t_ultimo := 0

# --- l'oracolo indipendente ------------------------------------------------
var _viste := {}                    # chiave deduzione → {ricevuta, spesa, …}
var _ricevute := []                 # una riga per ricevuta: distanza di Mochi
var _allucinazioni := []            # i «perché» che non stanno nell'anello
var _dedu_viste := 0
var _perche_tot := 0
var _perche_esatti := 0
var _mute_scadute := 0
var _ram_max := 0
var _ram_ultima := 0
var _ram_prima := 0              # l'impronta del gioco PRIMA che il modello si apra

# --- la traccia del comportamento (il confronto A/B) -----------------------
var _stati := {}
var _azioni := {}
var _transizioni := 0
var _stato_prec := {}
var _passi_camminati := 0.0
var _pos_prec := {}
var _campioni_traccia := 0
var _righe_traccia := PackedStringArray()

# --- i gesti di Mochi ------------------------------------------------------
var _gesti := 0
var _gesti_visti := 0

# --- le foto ---------------------------------------------------------------
var _scatti := 0
var _servizi := 0
const SERVIZI_MAX := 6


func _init() -> void:
	_go()


# =========================================================================
# IL FOTOGRAMMA
# =========================================================================

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
		return "  %-24s (nessun campione)" % nome
	return "  %-24s n=%5d  medio %6.2f  p50 %6.2f  p99 %6.2f  MAX %7.2f  >2×p50: %d" \
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

func _cella(k: int) -> Vector2i:
	return Vector2i(-8 + (k % CASE_COLONNE) * 3, 4 + (k / CASE_COLONNE) * 3)


func _go() -> void:
	_dove_foto = OS.get_environment("CHIBI_FOTO")
	_traccia_fuori = OS.get_environment("CHIBI_TRACCIA")
	if OS.get_environment("CHIBI_MINUTI") != "":
		_minuti = float(OS.get_environment("CHIBI_MINUTI"))
	if OS.get_environment("CHIBI_QUANTI") != "":
		_quanti = int(OS.get_environment("CHIBI_QUANTI"))
	if OS.get_environment("CHIBI_BLOCCHI") != "":
		_blocchi = int(OS.get_environment("CHIBI_BLOCCHI"))
	if OS.get_environment("CHIBI_SEME") != "":
		_seme = int(OS.get_environment("CHIBI_SEME"))
	if _dove_foto != "":
		DirAccess.make_dir_recursive_absolute(_dove_foto)

	print("")
	print("════════ LA PROVA CHE CHIUDE LA FASE 5 ════════")
	print("  %s" % LLM.riga_di_stato())
	print("  modello: %s" % (LLM.percorso_modello() if LLM.percorso_modello() != "" else "(nessuno)"))
	print("  porta:   Llm.disponibile()=%s · Llm.acceso()=%s"
			% [str(LLM.disponibile()), str(LLM.acceso())])
	print("  seme %d · %d residenti · %.0f minuti di vita" % [_seme, _quanti, _minuti])
	print("  macchina: %s" % _carico())

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_sonda()

	# ⚠️ I DADI SI SEMINANO A MANO, tutti e tre (è la lezione di
	# `prova_identico`): il globale prima che il mondo nasca, quello delle
	# chiacchiere dopo che `Visitors._ready` l'ha mescolato, e quello di ogni
	# cervello nello stesso frame in cui il cervello nasce. Senza, i due
	# bracci non sono lo stesso villaggio e il confronto non vuol dire niente.
	seed(_seme)

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
	_garden = livello.get_node_or_null("Garden")
	_player = livello.get_node_or_null("Player") as Node3D
	_pensieri = livello.get_node_or_null("Pensieri")
	if _vis == null or _player == null or _build == null:
		print("GUASTO: Visitors=%s Player=%s BuildSystem=%s" % [_vis, _player, _build])
		quit(1)
		return
	# LA PRIMA COSA CHE SI PROVA: il nodo dev'essere NELLA SCENA. Che si sia
	# ACCESO è un'altra domanda (il gruppo), ed è giusto che sia falsa senza
	# modello.
	if _pensieri == null:
		print("GUASTO: il MainLevel non ha il nodo «Pensieri» — la Fase 5 non è cablata")
		quit(1)
		return
	var dal_gruppo := get_first_node_in_group("pensieri")
	print("  nodo «Pensieri» in scena: sì · acceso (nel gruppo): %s"
			% ("sì" if dal_gruppo == _pensieri else "NO"))
	if LLM.acceso() and dal_gruppo != _pensieri:
		print("GUASTO: la porta è aperta ma il nodo non si è acceso")
		quit(1)
		return
	if not LLM.acceso() and dal_gruppo != null:
		print("GUASTO: la porta è CHIUSA e il nodo si è acceso lo stesso")
		quit(1)
		return

	_build.call("set_persist_for_debug", false)
	if _dn != null:
		_dn.set("cycle_seconds", 1000000.0)
		_dn.set("time", 0.42)
	_vis.set("_chat_rng", _dado(_seme + 1))
	await create_timer(1.0).timeout

	_costruisci()
	await _insedia()
	if _cuore == null:
		print("GUASTO: nessun cuore ECS (GDExtension non caricata?)")
		quit(1)
		return
	_osservatore = LLM.apri()
	# ⚠️ LA RAM SI MISURA A DIFFERENZA, o si attribuisce al modello anche il
	# gioco. `memoria()["impronta"]` è l'impronta fisica dell'INTERO processo
	# — è la misura giusta (`ps rss` su macOS conta male le pagine mappate da
	# file), ma dentro c'è anche il MainLevel con i suoi ventotto residenti.
	# Il tetto di 3 GB dell'autore è del MODELLO: il numero da confrontare col
	# tetto è la differenza fra questa riga e il massimo visto dopo.
	_ram_prima = _impronta()
	await create_timer(2.0).timeout
	_conta_luoghi()

	await _mochi_lavora(14)
	await _aspetta_il_carico()
	await _il_metro_del_fotogramma()
	await _la_vita()
	_rapporto()
	_scrivi_traccia()
	quit(0)


func _dado(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


## IL VILLAGGIO: una casa vera per ognuno (un `Letto` con una copertura sulla
## sua stessa cella — «una casa non è un letto»), e poi i posti che i piani
## sanno nominare: cespugli, panchine, orti, la Lavagna.
##
## ⚠️ **SENZA POSTI NON SI PAGA NESSUNA RICEVUTA**, e non è un guasto del
## cablaggio: `Deduzioni.meta_del_gesto` chiede al risolutore dove andrà il
## corpo, e in un prato nudo nessun luogo è raggiungibile — nessun piano,
## nessuna direzione a cui legare lo sguardo, silenzio.
func _costruisci() -> void:
	_vis.call("debug_reset")
	for k in _quanti:
		var c := _cella(k)
		_build.call("place_cell", c, "Letto", 0, false)
		_build.call("place_cell", c, "Tetto", 0, false)
	var arredo := []
	for k in 5:
		arredo.append([Vector2i(-14, 4 + k * 3), "Cespuglio"])
		arredo.append([Vector2i(14, 4 + k * 3), "Panchina"])
		arredo.append([Vector2i(-11 + k * 6, 1), "Orto"])
	arredo.append([Vector2i(0, 18), "Lavagna"])
	arredo.append([Vector2i(-4, 18), "Panchina"])
	arredo.append([Vector2i(4, 18), "Cespuglio"])
	for a in arredo:
		_build.call("place_cell", a[0], a[1], 0, false)
	_build.call("aggiorna_varchi_ora")
	print("  villaggio: %d letti · %d cespugli · %d panchine · %d orti"
			% [(_build.call("get_placed_by_name", "Letto") as Array).size(),
			(_build.call("get_placed_by_name", "Cespuglio") as Array).size(),
			(_build.call("get_placed_by_name", "Panchina") as Array).size(),
			(_build.call("get_placed_by_name", "Orto") as Array).size()])
	_aiuole = _build.call("get_placed_by_name", "Orto")


func _insedia() -> void:
	for k in _quanti:
		_vis.call("debug_settle", _seme + k * 37, _cella(k))
		# ⚠️ IL DADO DEL CERVELLO SI FISSA NELLO STESSO FRAME IN CUI IL
		# CERVELLO NASCE (`VillagerBrain.setup` lo semina con l'orologio da
		# polso): aspettare anche un frame vuol dire che ha già scelto il
		# primo mestiere della giornata, e i due bracci partono diversi.
		_residenti = _vis.get("_residents")
		_semina_cervelli()
		await process_frame
	_residenti = _vis.get("_residents")
	_cuore = _vis.call("cuore")
	print("  insediati %d/%d · cuore ECS: %s"
			% [_residenti.size(), _quanti, "sì" if _cuore != null else "NO"])


func _semina_cervelli() -> void:
	for i in _residenti.size():
		var r: Dictionary = _residenti[i]
		var b: RefCounted = _vis.call("_ensure_brain", r)
		if b != null and not bool(r.get("dado_fissato", false)):
			r["dado_fissato"] = true
			b.set("_rng", _dado(_seme + 1000 + i * 13))


func _conta_luoghi() -> void:
	var con_meta := 0
	for r in _residenti:
		for voce in ((r as Dictionary).get("luoghi", []) as Array):
			if bool((voce as Dictionary).get("ok", false)):
				con_meta += 1
				break
	print("  residenti con almeno un posto raggiungibile: %d/%d"
			% [con_meta, _residenti.size()])


# =========================================================================
# MOCHI FA I SUOI GESTI — e li fa PREMENDO E, come chi gioca
# =========================================================================

## L'aiuola più vicina a un punto.
func _aiuola_vicina(p: Vector3) -> Node3D:
	var best: Node3D = null
	var bd := 1e9
	for n in _aiuole:
		if not is_instance_valid(n):
			continue
		var d: float = (n as Node3D).global_position.distance_to(p)
		if d < bd:
			bd = d
			best = n
	return best


## UN GESTO VERO: Mochi si mette accanto all'aiuola e **preme E**.
##
## Non si chiama `Garden._water()`: si dà in pasto a `Input` l'azione
## «interact», che è esattamente quello che fa la tastiera. Da lì in poi
## nessuna riga di questo file è nella catena — se domani qualcuno spostasse
## l'emissione della percezione da `Garden` a un altro posto, questo banco
## continuerebbe a provare il gioco e non la propria idea del gioco.
func _premi_e_su(aiuola: Node3D) -> void:
	if aiuola == null or not is_instance_valid(aiuola):
		return
	var p: Vector3 = aiuola.global_position
	_player.global_position = Vector3(p.x + 0.7, _player.global_position.y, p.z + 0.5)
	# due frame: uno perché `Garden._process` ricalcoli `_near`, uno perché
	# l'input arrivi con `_near` già aggiornato
	await process_frame
	await process_frame
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	var giu := InputEventAction.new()
	giu.action = "interact"
	giu.pressed = false
	Input.parse_input_event(giu)
	_gesti += 1
	await create_timer(1.2).timeout


## LA GIORNATA DI LAVORO: Mochi gira per gli orti e preme E. È la sola cosa
## che riempie il grafo dei ricordi dei vicini — e senza quello non c'è niente
## da dedurre.
func _mochi_lavora(quanti: int) -> void:
	print("")
	print("  ── Mochi lavora: %d gesti VERI (E premuto su un'aiuola) ──" % quanti)
	var prima := _quanti_ricordi()
	for k in quanti:
		var a := _aiuole[k % maxi(_aiuole.size(), 1)] as Node3D
		await _premi_e_su(a)
	await create_timer(1.0).timeout
	var dopo := _quanti_ricordi()
	_gesti_visti = dopo
	print("     ricordi nel villaggio: %d → %d (li ha incisi la percezione VERA)"
			% [prima, dopo])
	if dopo == prima:
		print("     ⚠️ NESSUN RICORDO: o l'input non arriva, o nessuno era lì a vedere.")


func _quanti_ricordi() -> int:
	var n := 0
	for r in _residenti:
		var rr: Dictionary = r
		if not rr.has("ecs"):
			continue
		n += ((_cuore.call("debug_grafo", int(rr["ecs"])) as Dictionary)
				.get("ricordi", []) as Array).size()
	return n


# =========================================================================
# IL CARICO DEL MODELLO
# =========================================================================

func _aspetta_il_carico() -> void:
	if not LLM.acceso():
		print("")
		print("  ── nessun modello: si va avanti col gioco di sempre ──")
		return
	print("")
	print("  ── il nodo apre il modello da solo (sul thread, mentre il gioco disegna) ──")
	var t0 := Time.get_ticks_msec()
	_via()
	while float(Time.get_ticks_msec() - t0) < 300000.0:
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
	_leggi_ram()
	print("  %s" % _carico())
	if str(m["stato"]) != "pensa":
		print("GUASTO: il modello non si è aperto — questo braccio non misura niente")
		quit(1)


## LA RAM, LETTA DA DENTRO IL PROCESSO. **Mai `ps rss`**: su macOS conta male
## le pagine mappate da file (su gemma-3-1b dichiara 1947 MB dove l'impronta
## fisica ne dice 1301).
func _impronta() -> int:
	if _osservatore == null:
		return 0
	return int((_osservatore.call("memoria") as Dictionary).get("impronta", 0))


func _leggi_ram() -> void:
	if _osservatore == null:
		return
	_ram_ultima = _impronta()
	_ram_max = maxi(_ram_max, _ram_ultima)


# =========================================================================
# A. IL FOTOGRAMMA — blocchi alternati, stessa corsa
# =========================================================================

func _il_metro_del_fotogramma() -> void:
	print("")
	print("  ── A. IL FOTOGRAMMA: %d coppie di blocchi da %.0f s, alternati ──"
			% [_blocchi, DURATA_BLOCCO])
	var spento := {}
	var acceso := {}
	for i in _blocchi:
		if _pensieri != null and LLM.acceso():
			_pensieri.call("debug_pausa", true)
		await create_timer(0.5).timeout
		_via()
		await create_timer(DURATA_BLOCCO).timeout
		spento = _fondi(spento, _stop())

		if _pensieri != null and LLM.acceso():
			_pensieri.call("debug_pausa", false)
		await create_timer(0.5).timeout
		_via()
		await create_timer(DURATA_BLOCCO).timeout
		acceso = _fondi(acceso, _stop())
	print(_riga("motore spento", spento))
	print(_riga("il villaggio pensa", acceso))
	if int(spento.get("n", 0)) > 0 and int(acceso.get("n", 0)) > 0:
		var da := float(spento["medio"])
		var a := float(acceso["medio"])
		print("  scarto sul fotogramma medio: %+.2f ms (%+.1f%%) · frame PEGGIORE %.2f → %.2f ms"
				% [a - da, 100.0 * (a - da) / maxf(da, 0.001),
				float(spento["max"]), float(acceso["max"])])
	if LLM.acceso():
		var m: Dictionary = _pensieri.call("misure")
		print("  il costo del nodo, cronometrato sulla riga: passo medio %.1f µs, peggiore %.1f µs"
				% [float(m["passo_us_medio"]), float(m["passo_us_peggio"])])
	_leggi_ram()
	print("  %s" % _carico())


# =========================================================================
# B. LA VITA — venti minuti, Mochi che vive, e nessuno che spinge
# =========================================================================

func _la_vita() -> void:
	print("")
	print("  ── B. LA VITA: %.0f minuti, %d residenti, Mochi che cammina e lavora ──"
			% [_minuti, _residenti.size()])
	var rng := _dado(_seme + 77)
	var mete := []
	for n in _aiuole:
		if is_instance_valid(n):
			mete.append((n as Node3D).global_position)
	for r in _residenti:
		var nn := (r as Dictionary).get("node") as Node3D
		if nn != null and is_instance_valid(nn):
			mete.append(nn.global_position)
	var meta: Vector3 = mete[rng.randi() % mete.size()]
	var sosta := 0.0
	var t := 0.0
	var prossimo_gesto := 20.0
	var prossimo_rapporto := 120.0
	var prossimo_oracolo := 0.0
	var prossima_ram := 10.0
	var prossima_traccia := 0.0
	var fine := _minuti * 60.0
	_via()
	while t < fine:
		var p := _player.global_position
		if sosta > 0.0:
			sosta -= PASSO
		elif p.distance_to(Vector3(meta.x, p.y, meta.z)) < 0.6:
			sosta = rng.randf_range(2.0, 6.0)
			meta = mete[rng.randi() % mete.size()]
		else:
			var d := (Vector3(meta.x, p.y, meta.z) - p).normalized()
			_player.global_position = p + d * MOCHI_PASSO * PASSO

		prossimo_gesto -= PASSO
		if prossimo_gesto <= 0.0:
			prossimo_gesto = rng.randf_range(18.0, 34.0)
			# il gesto VERO: si va sull'aiuola più vicina e si preme E. Il
			# tempo speso lì dentro è tempo di gioco come tutto il resto.
			var quando := Time.get_ticks_msec()
			await _premi_e_su(_aiuola_vicina(_player.global_position))
			t += float(Time.get_ticks_msec() - quando) / 1000.0
			meta = mete[rng.randi() % mete.size()]

		prossimo_oracolo -= PASSO
		if prossimo_oracolo <= 0.0:
			prossimo_oracolo = 0.1
			_oracolo()
		prossima_traccia -= PASSO
		if prossima_traccia <= 0.0:
			prossima_traccia = 2.0
			_campiona_traccia(t)
		prossima_ram -= PASSO
		if prossima_ram <= 0.0:
			prossima_ram = 10.0
			_leggi_ram()
		prossimo_rapporto -= PASSO
		if prossimo_rapporto <= 0.0:
			prossimo_rapporto = 120.0
			print("    t=%5.0f s  %s  · %s" % [t, _riassunto(), _carico()])
		await create_timer(PASSO).timeout
		t += PASSO
	var d := _stop()
	print("")
	print(_riga("la vita intera", d))
	print("  %s" % _carico())


func _riassunto() -> String:
	if not LLM.acceso():
		return "(nessun modello) ricordi %d" % _quanti_ricordi()
	var m: Dictionary = _pensieri.call("misure")
	var c: Dictionary = _vis.call("debug_deduzioni_contatori")
	var r: Dictionary = m.get("ritmo", {})
	return "pensieri %d · dedotte %d · ricevute %d · dirotti %d · muti %d · RAM %d MB" \
			% [int(m["pensieri"]), int(m["dedotte"]), int(c["ricevute"]),
			int(c["dirotti"]), int(r.get("muti", 0)), _ram_ultima / 1048576]


# =========================================================================
# L'ORACOLO INDIPENDENTE — le bandiere del grafo, e le allucinazioni
# =========================================================================

## Si campiona a 10 Hz. Una ricevuta si paga sulla cadenza dei fatti (30
## frame, sfalsata per residente) e la deduzione vive decine di secondi:
## nessuna sfugge. La distanza di Mochi è quella dell'istante del campione —
## a 3 m/s si sbaglia di 30 cm nel caso peggiore, ed è dichiarato.
func _oracolo() -> void:
	if _cuore == null or not is_instance_valid(_cuore):
		return
	var k: Dictionary = _cuore.call("debug_deduzioni_costanti")
	var b_ric := int(k.get("d_ricevuta", 0))
	var b_spe := int(k.get("d_spesa", 0))
	var mochi: Vector3 = _player.global_position
	for riga in _residenti:
		var rr: Dictionary = riga
		if not rr.has("ecs"):
			continue
		var id := int(rr["ecs"])
		var node := rr.get("node") as Node3D
		var elenco: Array = (_cuore.call("debug_deduzioni", id) as Dictionary).get("deduzioni", [])
		for d in elenco:
			var dd: Dictionary = d
			var chiave := "%d:%.4f:%d" % [id, float(dd.get("quando", 0.0)),
					int(dd.get("obiettivo", 0))]
			if not _viste.has(chiave):
				_viste[chiave] = {"ric": false, "spe": false, "vista": 0,
						"dmin": 1e9, "collo": 0, "meta": 0, "ancora": 0,
						"chi": str(rr.get("label", "?"))}
				_dedu_viste += 1
				_verifica_perche(id, dd, str(rr.get("label", "?")))
			var v: Dictionary = _viste[chiave]
			var band := int(dd.get("bandiere", 0))
			# ⚠️ PERCHÉ UNA RICEVUTA NON ARRIVA: le TRE porte di
			# `Deduzioni.consegna`, rilette da fuori e senza toccare niente.
			# Senza questa riga «zero ricevute» è un numero e basta, e un
			# numero che non dice la sua ragione fa aggiustare la cosa
			# sbagliata (è la lezione del vento: 283 µs presi per 14.6 ms).
			if not bool(v["ric"]) and node != null and is_instance_valid(node):
				var d0: float = node.global_position.distance_to(mochi)
				v["dmin"] = minf(float(v["dmin"]), d0)
				if PERCEZIONE.puo_vedere(node, mochi, DEDUZIONI.RAGGIO):
					v["vista"] = int(v["vista"]) + 1
					var meta: Dictionary = DEDUZIONI.meta_del_gesto(_cuore, id,
							elenco.find(d), rr.get("luoghi", []), int(rr.get("fatti", 0)))
					if meta.is_empty():
						v["meta"] = int(v["meta"]) + 1
					else:
						var dove: Vector3 = _cuore.call("deduzione_dove", id,
								elenco.find(d), node.global_position, meta["pos"],
								DEDUZIONI.APERTURA)
						# ⚠️ LE DUE RAGIONI SI SEPARANO, o si aggiusta la cosa
						# sbagliata. `deduzione_dove` torna il RIPIEGO — cioè
						# la posizione del corpo — quando nessun perché sta
						# dentro il cono di `APERTURA`: quello non è «il collo
						# è corto», è «non c'è niente da mostrare», e sono due
						# manopole diverse (l'apertura, e il tetto del rig).
						if dove.distance_to(node.global_position) < 0.05:
							v["ancora"] = int(v["ancora"]) + 1
						elif not bool(node.call("collo_ci_arriva", dove)):
							v["collo"] = int(v["collo"]) + 1
			if not bool(v["ric"]) and (band & b_ric) != 0:
				v["ric"] = true
				var dist := 0.0
				if node != null and is_instance_valid(node):
					var a := node.global_position
					dist = Vector2(a.x - mochi.x, a.z - mochi.z).length()
				_ricevute.append(dist)
				if _dove_foto != "" and _servizi < SERVIZI_MAX and node != null:
					_servizi += 1
					_servizio_fotografico(node, id, dd, _servizi)
			if not bool(v["spe"]) and (band & b_spe) != 0:
				v["spe"] = true


## ⚠️ LE ALLUCINAZIONI, e la verifica NON passa dal Giudice né dal ponte.
##
## Una deduzione porta le COPIE dei suoi perché. Ognuna dev'essere una riga
## VIVA dell'anello dei ricordi di quel vicino — se non lo è, il vicino sta
## andando da qualche parte per una cosa che non gli è mai successa, che è
## l'unico modo in cui questa fase può fare danno vero.
##
## Si confronta col grafo (`debug_grafo`), che è l'anello: verbo, cosa, e il
## posto. Il `quando` si guarda a parte e si conta separatamente, perché una
## riga può essersi RINFRESCATA dopo la copia (la fusione delle raffiche
## sposta `quando` in avanti): dichiararla allucinazione sarebbe un falso
## positivo, e un banco che grida al lupo non lo si guarda più.
func _verifica_perche(id: int, dd: Dictionary, chi: String) -> void:
	var anello: Array = (_cuore.call("debug_grafo", id) as Dictionary).get("ricordi", [])
	for p in (dd.get("perche", []) as Array):
		var pp: Dictionary = p
		_perche_tot += 1
		var trovato := false
		var esatto := false
		for r in anello:
			var rr: Dictionary = r
			if int(rr.get("verbo", -1)) != int(pp.get("verbo", -2)):
				continue
			if int(rr.get("cosa", -1)) != int(pp.get("cosa", -2)):
				continue
			if absf(float(rr.get("px", 0.0)) - float(pp.get("px", 0.0))) > 0.01:
				continue
			if absf(float(rr.get("pz", 0.0)) - float(pp.get("pz", 0.0))) > 0.01:
				continue
			trovato = true
			if absf(float(rr.get("quando", 0.0)) - float(pp.get("quando", 0.0))) < 0.01:
				esatto = true
			break
		if esatto:
			_perche_esatti += 1
		if not trovato:
			_allucinazioni.append("%s: verbo=%d cosa=%d in (%.2f, %.2f) — non è nell'anello"
					% [chi, int(pp.get("verbo", -1)), int(pp.get("cosa", -1)),
					float(pp.get("px", 0.0)), float(pp.get("pz", 0.0))])


# =========================================================================
# LA TRACCIA — il confronto A/B
# =========================================================================

func _campiona_traccia(t: float) -> void:
	_campioni_traccia += 1
	for i in _residenti.size():
		var r: Dictionary = _residenti[i]
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var etichetta := str(r.get("label", "?"))
		var st := str(node.get("_state"))
		_stati[st] = int(_stati.get(st, 0)) + 1
		var az := -1
		if _cuore != null and r.has("ecs"):
			az = int(_cuore.call("azione", int(r["ecs"])))
		_azioni[az] = int(_azioni.get(az, 0)) + 1
		if str(_stato_prec.get(etichetta, "")) != st:
			if _stato_prec.has(etichetta):
				_transizioni += 1
			_stato_prec[etichetta] = st
		var p: Vector3 = node.global_position
		if _pos_prec.has(etichetta):
			_passi_camminati += (p - (_pos_prec[etichetta] as Vector3)).length()
		_pos_prec[etichetta] = p
		if _traccia_fuori != "":
			_righe_traccia.append("%7.1f %-10s %-12s az=%2d %8.2f %8.2f"
					% [t, etichetta, st, az, p.x, p.z])


func _scrivi_traccia() -> void:
	if _traccia_fuori == "":
		return
	var f := FileAccess.open(_traccia_fuori, FileAccess.WRITE)
	if f == null:
		return
	for riga in _righe_traccia:
		f.store_line(riga)
	f.close()
	print("  traccia scritta: %s (%d righe)" % [_traccia_fuori, _righe_traccia.size()])


# =========================================================================
# LE FOTO — l'istante in cui una deduzione diventa un gesto
# =========================================================================

## TRE MACCHINE, e sono tre domande diverse:
##  · **tre quarti** e **profilo** — le due che l'autore ha chiesto: è lì che
##    si smascherano i trucchi di una posa (la lezione del muso in volo);
##  · **la camera VERA del gioco** — l'unica che risponde alla domanda che
##    conta: cosa vede chi sta giocando.
##
## Si scatta due volte: quando la testa si gira (la premessa) e qualche
## secondo dopo (la conseguenza, se il corpo parte). Il campionamento del
## fotogramma si mette in pausa: una foto costa, e non deve finire dentro il
## metro del fotogramma.
func _servizio_fotografico(node: Node3D, id: int, dd: Dictionary, n: int) -> void:
	var era := _misura
	_misura = false
	# il PERCHÉ PIÙ FORTE, con il cono spento (`apertura <= 0` = «non
	# filtrare»): serve alla riga di registro, non alla scelta — quella
	# l'ha già fatta `Deduzioni.consegna` con la meta vera.
	var p: Vector3 = node.global_position
	var dove: Vector3 = _cuore.call("deduzione_dove", id, 0, p, p, 0.0)
	print("     📷 servizio %d su %s — guarda (%.1f, %.1f) da (%.1f, %.1f), Mochi a %.1f m"
			% [n, str(node.name), dove.x, dove.z, p.x, p.z,
			p.distance_to(_player.global_position)])
	await _scatta_giro(node, "%02d_a_premessa" % n, dove)
	await create_timer(2.5).timeout
	await _scatta_giro(node, "%02d_b_dopo" % n, dove)
	await create_timer(4.0).timeout
	await _scatta_giro(node, "%02d_c_gesto" % n, dove)
	_misura = era


func _scatta_giro(node: Node3D, nome: String, guarda: Vector3) -> void:
	if not is_instance_valid(node):
		return
	var centro: Vector3 = node.global_position + Vector3(0, 0.40, 0)
	var avanti: Vector3 = -node.global_transform.basis.z
	avanti.y = 0.0
	if avanti.length() < 0.01:
		avanti = Vector3.FORWARD
	avanti = avanti.normalized()
	var lato := Vector3(avanti.z, 0.0, -avanti.x)
	# ⚠️ LE DISTANZE SONO STATE ALZATE DOPO AVER GUARDATO LE PRIME FOTO: a
	# 2,2 m il villaggio è pieno, e in un villaggio pieno un altro chibi
	# passa DAVANTI all'obiettivo — la prima serie ha una testona bianca che
	# occupa mezzo fotogramma. E la macchina si alza: un chibi è alto meno di
	# un metro, e da un metro di altezza si guarda sopra le teste degli altri.
	# TRE QUARTI: davanti e di lato, come guarda una persona in una stanza.
	var tq := centro + (avanti * 0.8 + lato * 0.6).normalized() * 4.2 + Vector3(0, 1.05, 0)
	# PROFILO: perpendicolare, l'unica vista in cui un collo che si gira si
	# legge come un angolo invece che come uno scorcio.
	var pr := centro + lato * 3.8 + Vector3(0, 0.75, 0)
	await _scatta_da(tq, centro, nome + "_treQuarti")
	await _scatta_da(pr, centro, nome + "_profilo")
	# LA LETTURA: la sola inquadratura che contiene la PREMESSA e il suo
	# oggetto insieme — il vicino e il posto che sta guardando. È la domanda
	# dell'autore messa in una foto: un giocatore che non sa niente,
	# guardando lo schermo, capisce che quei due si riferiscono l'uno
	# all'altro? (Se l'ancora è addosso al corpo non c'è niente da leggere e
	# si salta: è il residuo dichiarato di `chibi::Lettura`.)
	var verso: Vector3 = guarda - node.global_position
	verso.y = 0.0
	if verso.length() > 1.0:
		var mezzo: Vector3 = node.global_position + verso * 0.5
		var perp := Vector3(verso.z, 0.0, -verso.x).normalized()
		var quanto: float = maxf(verso.length() * 0.9, 6.0)
		await _scatta_da(mezzo + perp * quanto + Vector3(0, quanto * 0.45, 0),
				mezzo + Vector3(0, 0.3, 0), nome + "_lettura")
	# e la macchina VERA del gioco
	await _scatta(nome + "_camera")


## ⚠️ LA CAMERA VERA SI RIMETTE A MANO. Liberare la macchina di prova non
## rimette al suo posto quella del gioco in modo garantito, e una foto «dalla
## camera vera» scattata da una macchina qualunque risponderebbe a una
## domanda che nessuno si fa.
func _scatta_da(da: Vector3, a: Vector3, nome: String) -> void:
	var prima := get_root().get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = 50.0
	current_scene.add_child(cam)
	cam.global_position = da
	cam.look_at(a, Vector3.UP)
	cam.current = true
	await _scatta(nome)
	cam.queue_free()
	await process_frame
	if prima != null and is_instance_valid(prima):
		prima.current = true
	await process_frame


func _scatta(nome: String) -> void:
	if _dove_foto == "":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_jpg(_dove_foto.rstrip("/") + "/" + nome + ".jpg", 0.94)
	_scatti += 1


# =========================================================================
# IL RAPPORTO
# =========================================================================

func _rapporto() -> void:
	print("")
	print("  ══════════ IL RAPPORTO ══════════")
	print("  gesti VERI di Mochi (E premuto) ....... %d" % _gesti)
	print("  ricordi incisi nel villaggio .......... %d" % _quanti_ricordi())
	var stati := _stati.keys()
	stati.sort()
	var s := []
	for k in stati:
		s.append("%s=%d" % [str(k), int(_stati[k])])
	print("  campioni di traccia ................... %d (× %d residenti)"
			% [_campioni_traccia, _residenti.size()])
	print("  stati del corpo ....................... %s" % " ".join(s))
	var az := _azioni.keys()
	az.sort()
	var a := []
	for k in az:
		a.append("az%d=%d" % [int(k), int(_azioni[k])])
	print("  azioni dell'agenda .................... %s" % " ".join(a))
	print("  transizioni di stato .................. %d" % _transizioni)
	print("  metri camminati dai vicini ............ %.1f" % _passi_camminati)

	if not LLM.acceso():
		print("")
		print("  ── IL BRACCIO SENZA MODELLO ──")
		print("  nodo «Pensieri» acceso ................ %s"
				% str(get_first_node_in_group("pensieri") != null))
		var vive := 0
		for r in _residenti:
			var rr: Dictionary = r
			if rr.has("ecs"):
				vive += ((_cuore.call("debug_deduzioni", int(rr["ecs"])) as Dictionary)
						.get("deduzioni", []) as Array).size()
		print("  deduzioni nel grafo ................... %d (dev'essere 0)" % vive)
		var c: Dictionary = _vis.call("debug_deduzioni_contatori")
		print("  ricevute / dirotti .................... %d / %d (dev'essere 0/0)"
				% [int(c["ricevute"]), int(c["dirotti"])])
		return

	var m: Dictionary = _pensieri.call("misure")
	var c2: Dictionary = _vis.call("debug_deduzioni_contatori")
	var r2: Dictionary = m.get("ritmo", {})
	print("")
	print("  ── LA FASE 5, in %.0f minuti ──" % _minuti)
	print("  pensieri consegnati dal motore ........ %d" % int(m["pensieri"]))
	print("  bozze generate / ammesse .............. %d / %d" % [int(m["bozze"]), int(m["bozze_ok"])])
	print("  DEDUZIONI ENTRATE NEL GRAFO ........... %d" % int(m["dedotte"]))
	print("  bocciate (Giudice o ponte) ............ %d" % int(m["bocciate"]))
	print("  RICEVUTE PAGATE (teste girate) ........ %d" % int(c2["ricevute"]))
	print("  MESTIERI CAMBIATI per una deduzione ... %d" % int(c2["dirotti"]))
	print("  ...contate dalle BANDIERE del grafo:  deduzioni %d · ricevute %d"
			% [_dedu_viste, _ricevute.size()])
	print("  tentativi muti (niente da dire) ....... %d" % int(r2.get("muti", 0)))
	print("  pensieri persi dal motore ............. %d" % int(r2.get("persi", 0)))
	var porte: Dictionary = m.get("porte", {})
	if not porte.is_empty():
		print("  perché le consegne non hanno prodotto niente:")
		for k in porte:
			print("     %3d × %s" % [int(porte[k]), str(k)])

	print("")
	print("  ── LA DISTANZA DI MOCHI QUANDO LA TESTA SI GIRA ──")
	if _ricevute.is_empty():
		print("  (nessuna ricevuta pagata)")
	else:
		var v := _ricevute.duplicate()
		v.sort()
		var somma := 0.0
		for x in v:
			somma += float(x)
		var fuori := 0
		for x in v:
			if float(x) > DEDUZIONI.RAGGIO + 0.5:
				fuori += 1
		print("  n=%d · media %.2f m · mediana %.2f m · MAX %.2f m"
				% [v.size(), somma / float(v.size()), float(v[v.size() / 2]),
				float(v[v.size() - 1])])
		print("  fuori dal raggio (%.1f m + mezzo metro di campionamento): %d — dev'essere 0"
				% [DEDUZIONI.RAGGIO, fuori])

	print("")
	print("  ── LE ALLUCINAZIONI ──")
	print("  «perché» controllati uno per uno ...... %d" % _perche_tot)
	print("  ...che stanno nell'anello VERO ........ %d" % (_perche_tot - _allucinazioni.size()))
	print("  ...col «quando» identico al ricordo ... %d" % _perche_esatti)
	print("  ALLUCINAZIONI ......................... %d (DEVE ESSERE 0)" % _allucinazioni.size())
	for riga in _allucinazioni:
		print("     ⚠️ %s" % str(riga))

	print("")
	print("  ── LA RAM (letta con memoria(), MAI con ps) ──")
	print("  il gioco da solo, prima del modello ... %d MB" % (_ram_prima / 1048576))
	print("  il processo intero, massimo visto ..... %d MB" % (_ram_max / 1048576))
	print("  IL MODELLO, per differenza ............ %d MB" % ((_ram_max - _ram_prima) / 1048576))
	if _osservatore != null:
		var lim: Dictionary = _osservatore.call("limiti")
		print("  il tetto dell'autore .................. %d MB"
				% (int(lim.get("tetto_byte", 0)) / 1048576))
		var mm: Dictionary = _osservatore.call("memoria")
		print("  libera nel sistema, adesso ............ %d MB"
				% (int(mm.get("libera_sistema", 0)) / 1048576))
	print("")
	print("  ── LE DEDUZIONI CHE NON HANNO TROVATO IL LORO MOMENTO ──")
	print("  deduzioni viste dal grafo ............. %d" % _dedu_viste)
	print("  ...che hanno pagato la ricevuta ....... %d" % _ricevute.size())
	print("  ...ancora mute o scadute .............. %d" % (_dedu_viste - _ricevute.size()))
	# LE TRE PORTE, una riga per deduzione muta. `dmin` è la cosa che decide:
	# sotto `Deduzioni.RAGGIO` la premessa si può vedere, sopra no — e sopra,
	# le altre due colonne non hanno nemmeno avuto occasione di parlare.
	var mute := 0
	for k in _viste:
		var v: Dictionary = _viste[k]
		if bool(v["ric"]):
			continue
		mute += 1
		if mute > 14:
			continue
		print("     %-22s Mochi a %6.2f m · in raggio %4d · "
				% [str(v["chi"]), float(v["dmin"]), int(v["vista"])]
				+ "meta vuota %4d · niente da mostrare %4d · collo corto %4d"
				% [int(v["meta"]), int(v["ancora"]), int(v["collo"])])
	print("")
	print("  foto scattate: %d in %s" % [_scatti, _dove_foto if _dove_foto != "" else "(nessuna)"])
