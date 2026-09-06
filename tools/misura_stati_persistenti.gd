extends SceneTree
## IL METRO DEGLI STATI PERSISTENTI — quanto torna tutto al suo posto, e
## quanto succede da se'.
##
##   Godot --path . --resolution 1280x720 \
##       --script res://tools/misura_stati_persistenti.gd
##   CHIBI_GIORNI=3 CHIBI_RIPOSO=3 CHIBI_ANNI=4 CHIBI_QUANTI=13 …
##
## ⚠️ **LO STRUMENTO VIENE PRIMA DELLA COSA DA MISURARE**, ed e' la lezione
## piu' cara di questo progetto: il termine dell'insieme che non cambiava
## nessuna decisione, la neurochimica che non arrivava a nessun corpo, le
## coppie che non potevano formarsi. Tutti e tre erano sistemi completi,
## provati e VERDI, e spenti in partita. Questo banco esiste per dare i
## numeri CONTRO cui si giudichera' un substrato che non c'e' ancora.
##
## ════════════════════════════════════════════════════════════════════════
## LE CINQUE DOMANDE
## ════════════════════════════════════════════════════════════════════════
##
## **D1 · QUANTO TORNA TUTTO AL SUO POSTO.** Per i marchi, `regolazione`,
##      `umore`, il cortisolo e il peso di un ricordo: dopo un colpo, quanto
##      tempo di gioco ci mette a tornare a riposo. E' il numero contro cui
##      si misurera' l'idea intera.
## **D2 · QUANTE COSE TRISTI** fa succedere il gioco da se' in una stagione:
##      una partenza, un lutto, un cucciolo che cresce. Zero vuol dire che
##      l'origine non esiste e il progetto va rifatto.
## **D3 · QUANTO SPESSO LE VIE D'USCITA CAPITANO DA SOLE** — il posto
##      accanto, la Veglia, il piatto caldo, l'accompagnamento — con e senza
##      il giocatore.
## **D4 · IL TETTO**: quanti vicini potrebbero essere deviati INSIEME, con
##      la geografia e il ritmo di oggi.
## **D5 · IN UN'ORA DI GIOCO, QUANTE COSE IL GIOCATORE VEDE SUCCEDERE CHE
##      NESSUNO HA SCRITTO.** La definizione e' dichiarata sotto, e conta
##      quanto il numero.
##
## ────────────────────────────────────────────────────────────────────────
## LA DEFINIZIONE DI D5, e si dichiara perche' senza il numero non vuol dire
## ────────────────────────────────────────────────────────────────────────
##
## Un **EVENTO EMERGENTE** e' un fatto che soddisfa tutte e tre:
##
##  (a) **nasce dallo STATO INTERNO di un vicino** — bisogni, chimica,
##      marchi, memoria, affinita' — e non da un orologio del mondo ne' da
##      una scena scritta;
##  (b) ha una manifestazione **SUL CORPO**, leggibile senza una parola;
##  (c) **non e' riproducibile**: due partite non lo mettono negli stessi
##      istanti.
##
## Sono ESCLUSI per definizione, e ognuno per la sua ragione:
##  · il **falo'** (orologio del mondo, posti ASSEGNATI da `_posto_al_falo`,
##    cioe' dall'ordine in cui la gente ha traslocato — la stessa ragione
##    per cui `_segna_incontro` non registra li');
##  · **Concerto · Salone · Nascondino · Concertino · Bancarella ·
##    RichiesteFoto · Onsen** (scene scritte, e chi le riceve e' un
##    sorteggio uniforme: `candidati[randi() % size]`);
##  · i **toast**, le **lettere**, le **nuvolette rivolte al giocatore** —
##    quelli sono testo, e il metro qui e' il corpo;
##  · il **ciclo sonno/veglia** (e' il mondo che gira).
##
## Si contano SETTE famiglie, ognuna col suo oracolo INDIPENDENTE (letto dal
## CORPO o dalle POSIZIONI, mai chiedendo al sistema se e' d'accordo con
## se' stesso):
##
##  1. un **gesto del vocabolario** concesso  → `Visitor.gesto_in_corso()`
##  2. una **chiacchierata** fra due vicini   → i due corpi girati e vicini
##  3. una **co-seduta** che comincia         → posizioni + `_state`
##  4. un **sussulto** o un **riconoscimento** → `_gs_soma`/`_gs_soma_t`
##  5. una **rinuncia a un luogo** (`_filtra_luogo`) → l'azione dell'agenda
##     contro quella recitata
##  6. una **cricca** che si chiude           → `Cricche.debug_stato`, con
##     la controprova sulle posizioni
##  7. un **mestiere dirottato da una deduzione** → `debug_deduzioni_*`
##
## E per ognuna: **quante dentro l'inquadratura della camera VERA**, che e'
## l'unica definizione difendibile di «il giocatore lo vede».
##
## ────────────────────────────────────────────────────────────────────────
## LE REGOLE DEL BANCO, tutte gia' pagate in questo progetto
## ────────────────────────────────────────────────────────────────────────
##
## ⚠️ **L'OROLOGIO NON SI ACCELERA.** Una giornata dura `cycle_seconds`
## (quattro minuti reali) e resta cosi': `_chats` guarda ogni 3,5 s, i corpi
## camminano a metri al secondo, il sussulto ha 9 s di raffreddamento e il
## morso 12. Accelerare vorrebbe dire misurare un villaggio che non esiste.
## L'UNICA parte che salta i giorni e' il CALENDARIO (D2), e li' non si
## misura niente che dipenda dai fotogrammi: le partenze e le nascite si
## decidono **solo** su `day_changed`, quindi guidare quel segnale e' la
## domanda giusta e non una scorciatoia. Gira per ultima, apposta: muove
## il mondo di anni e da li' in poi non si misura piu' niente.
##
## ⚠️ **NON SI TOCCA IL `village.json` DELL'AUTORE**:
## `set_persist_for_debug(false)` PRIMA di qualunque cosa, e l'impronta del
## file confrontata prima e dopo. Un banco altrui si e' gia' portato via due
## gigabyte.
##
## ⚠️ **SE UN NUMERO E' ZERO, SI DICE PERCHE'.** Il silenzio ha molti nomi, e
## un referto che stampa uno zero senza la sua ragione fa accusare il
## cablaggio quando era il calendario.
##
## ⚠️ **SI MISURA IL VILLAGGIO CHE C'E'.** Il MainLevel carica il
## salvataggio: se ci sono gia' dei residenti, si misurano quelli, con le
## loro case dove il giocatore le ha messe. Dei corpi propri su una griglia
## a quattro metri sarebbero co-presenza FABBRICATA dal banco.
##
## ⚠️ **SENZA FINESTRA, DUE CANCELLI DEGRADANO A «SI'».** `_nell_inquadratura`
## e `_gesto_coperto` tornano `true` quando non c'e' camera o non c'e'
## mondo fisico: in `--headless` il conto dei gesti e' quindi un TETTO, non
## una misura. Il banco lo verifica e lo dichiara in cima al referto.

const VISITORS := preload("res://scenes/npc/Visitors.gd")
const LIMBICO := preload("res://scenes/npc/Limbico.gd")
const CONGEDO := preload("res://scenes/world/Congedo.gd")
const NASCITE := preload("res://scenes/world/Nascite.gd")
const LEGAMI := preload("res://scenes/world/Legami.gd")
const CRICCHE := preload("res://scenes/npc/Cricche.gd")
const ACCOMP := preload("res://scenes/npc/Accompagna.gd")
const VEGLIA := preload("res://scenes/npc/Veglia.gd")
const REGIA := preload("res://scenes/npc/Regia.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")
const AFFETTI := preload("res://scenes/npc/Affetti.gd")

## Quanto lontano si porta Mochi nei blocchi «senza il giocatore». Oltre il
## raggio di TUTTO: `GESTO_RAGGIO` 9 m, `Percezione.RAGGIO` 9 m, il sussulto
## 3,2, il morso 2,6, `Deduzioni.RAGGIO` 4,5.
const LONTANO := Vector3(70.0, 0.0, -70.0)

## Quanto dura un blocco «con»/«senza» il giocatore, in secondi reali. Sotto
## il minuto i raffreddamenti del villaggio (35 s la coppia, 12 s il morso)
## non ci starebbero dentro nemmeno una volta.
const BLOCCO := 75.0

var _vis: Node
var _dn: Node3D
var _build: Node
var _cric: Node
var _leg: Node
var _cong: Node
var _nasc: Node
var _perc: Node
var _player: Node3D
var _ecs: Object

var _giorni := 3.0        # giornate della PARTITA (D3, D5)
var _riposo_gg := 3.0     # giornate del RITORNO A RIPOSO (D1)
var _anni := 4            # anni di calendario (D2)
var _quanti := 13

var _camera_viva := false
var _fisica_viva := false

# ---- D1 : le tracce dei canali -----------------------------------------
var _tracce := {}         # canale -> [[t_gioco, valore], …]
var _cavie := []          # label delle cavie
var _t0_riposo := 0.0
var _giorno_riposo0 := 0

# ---- D3/D5 : i conti della partita --------------------------------------
var _fase := "con"        # con | senza
var _sec := {"con": 0.0, "senza": 0.0}
var _ev := {}             # "famiglia|fase" -> quanti
var _ev_visti := {}       # idem, ma dentro l'inquadratura
var _gesto_prec := {}     # label -> gesto in corso
var _soma_prec := {}      # label -> raffreddamento del sussulto
var _sus_cd := {}
var _animi_ref := {}
var _bench_prec := {}     # label -> era seduto
var _coppia_sed := {}     # "a|b" -> era una co-seduta
var _chat_prec := {}      # chiave coppia -> timestamp
var _cric_prec := 0
var _ded_prec := {}
var _az_prec := {}
var _rinunce := 0
var _luoghi_evit_prec := {}
var _corpi_in_quadro := {}   # quanti corpi insieme nel frustum -> campioni
var _corpi_tot := 0
var _campioni := 0
var _frustum_no := 0
var _frustum_si := 0
var _fps_n := 0
var _fps_acc := 0.0

# ---- D3 : le vie d'uscita ----------------------------------------------
var _uscite := {}         # "via|fase" -> quanti / secondi
var _seduti_accanto_sec := {"con": 0.0, "senza": 0.0}
var _accomp_candidati := {"con": 0, "senza": 0}
var _accomp_camp := {"con": 0, "senza": 0}

# ---- D4 : il tetto ------------------------------------------------------
var _quadro_max := 0

# ---- D2 : il calendario -------------------------------------------------
var _cal := {}


func _init() -> void:
	_go()


# =========================================================================
#  la preparazione
# =========================================================================

func _trova(g: String) -> Node:
	for n in get_nodes_in_group(g):
		return n
	return null


func _impronta(p: String) -> String:
	if not FileAccess.file_exists(p):
		return "(assente)"
	var f := FileAccess.open(p, FileAccess.READ)
	var c := HashingContext.new()
	c.start(HashingContext.HASH_SHA256)
	c.update(f.get_buffer(f.get_length()))
	return c.finish().hex_encode()


func _cella(k: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(-8 + (k % 5) * 4, 2 + (k / 5) * 4)


func _env(n: String, d: float) -> float:
	return float(OS.get_environment(n)) if OS.get_environment(n) != "" else d


func _go() -> void:
	_giorni = _env("CHIBI_GIORNI", 3.0)
	_riposo_gg = _env("CHIBI_RIPOSO", 3.0)
	_anni = int(_env("CHIBI_ANNI", 4.0))
	_quanti = int(_env("CHIBI_QUANTI", 13.0))

	var salvataggio := "user://village.json"
	var prima_sha := _impronta(salvataggio)

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	if change_scene_to_file("res://scenes/levels/MainLevel.tscn") != OK:
		push_error("MainLevel non si apre")
		quit(1)
		return
	for _i in 40:
		await process_frame

	_vis = _trova("visitors")
	_dn = _trova("daynight") as Node3D
	_build = _trova("build_system")
	_cric = _trova("cricche")
	_leg = _trova("legami")
	_cong = _trova("congedo")
	_nasc = _trova("nascite")
	var liv := current_scene
	_player = liv.get_node_or_null("Player") as Node3D
	_perc = liv.get_node_or_null("Percezione")
	if _vis == null or _dn == null or _build == null or _player == null:
		push_error("manca Visitors, DayNight, BuildSystem o Player")
		quit(1)
		return
	# PRIMA DI TOCCARE QUALUNQUE COSA
	_build.call("set_persist_for_debug", false)
	await process_frame

	var residenti: Array = _vis.get("_residents")
	var gia := residenti.size()
	if gia < 6:
		# prato vuoto: se ne mettono di propri, e SULLA PROPRIA CELLA
		var VS := load("res://scenes/npc/Visitor.gd")
		var DNAG := load("res://scenes/npc/ChibiDNA.gd")
		for k in _quanti:
			var c := _cella(k)
			_build.call("place_cell", c, "Letto", 0, false)
			_build.call("place_cell", c, "Tetto", 0, false)
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
		_build.call("aggiorna_varchi_ora")
		for _i2 in 20:
			await process_frame
	_ecs = _vis.get("_ecs")
	residenti = _vis.get("_residents")

	# I DUE CANCELLI DELLA VISIBILITA' — vivi o degradati?
	# ⚠️ **NON BASTA CHE LA CAMERA CI SIA.** In `--headless` il viewport non
	# ha dimensioni e `is_position_in_frustum` risponde **false a tutto**:
	# il cancello `_nell_inquadratura` blocca allora OGNI gesto, e il banco
	# misurerebbe zero credendo di misurare il villaggio. Si prova con un
	# punto che deve stare in quadro per costruzione — cinque metri davanti
	# alla camera stessa.
	# Il punto di prova sta cinque metri davanti E un metro e mezzo di lato:
	# con un fov di 50° la mezza larghezza a cinque metri e' 2,3 m, quindi
	# in un frustum sano ci sta. In `--headless` il viewport e' largo zero e
	# il tronco si riduce a una scheggia sull'asse: il punto centrale ci
	# starebbe lo stesso, quello di lato no — ed e' per questo che il
	# collaudo e' FUORI ASSE. (Misurato: con la finestra il 66% dei corpi
	# risulta fuori quadro; headless, il 100%.)
	var cam := get_root().get_camera_3d()
	_camera_viva = false
	if cam != null:
		var avanti := cam.global_position - cam.global_transform.basis.z * 5.0
		var lato := avanti + cam.global_transform.basis.x * 1.5
		_camera_viva = cam.is_position_in_frustum(avanti) \
				and cam.is_position_in_frustum(lato)
		print("  [collaudo del frustum] viewport %s · avanti %s · di lato %s"
				% [str(get_root().size), cam.is_position_in_frustum(avanti),
				cam.is_position_in_frustum(lato)])
	_fisica_viva = liv.get_world_3d() != null \
			and liv.get_world_3d().direct_space_state != null

	_intestazione(residenti, prima_sha)

	# ---- LA PARTITA (D3, D5) ------------------------------------------
	await _partita(residenti)

	# ---- IL RITORNO A RIPOSO (D1) --------------------------------------
	await _ritorno_a_riposo(residenti)

	# ---- IL TETTO (D4) --------------------------------------------------
	_tetto(residenti)

	# ---- IL CALENDARIO (D2) — per ULTIMO: muove il mondo di anni --------
	await _calendario(residenti)

	print("")
	var dopo_sha := _impronta(salvataggio)
	print("il salvataggio dell'autore: %s"
			% ["INTATTO" if prima_sha == dopo_sha else "⚠️ TOCCATO ⚠️"])
	quit(0)


func _intestazione(res: Array, sha: String) -> void:
	print("")
	print("█".repeat(74))
	print("IL METRO DEGLI STATI PERSISTENTI")
	print("█".repeat(74))
	var pezzi := {}
	for nome in ["Panchina", "Cespuglio", "Letto", "Gazebo", "Aiuola",
			"Guardiola", "Cucina", "Serra", "Lavagna"]:
		var q: int = (_build.call("get_placed_by_name", nome) as Array).size()
		if q > 0:
			pezzi[nome] = q
	print("  villaggio: giorno %d (%s, %d° dei 7 giorni della stagione)"
			% [int(_dn.get("day")), _dn.call("season_name"),
			1 + (int(_dn.get("day")) - 1) % 7])
	print("  residenti: %d · pezzi costruiti: %s" % [res.size(), str(pezzi)])
	print("  una giornata dura %.0f s reali · l'orologio NON e' accelerato"
			% float(_dn.get("cycle_seconds")))
	print("  salvataggio: %s…" % sha.substr(0, 12))
	var vp := get_root().size
	var asp := float(vp.x) / maxf(1.0, float(vp.y))
	print("  camera viva: %s · mondo fisico vivo: %s · viewport %dx%d (%.2f:1)"
			% [_camera_viva, _fisica_viva, vp.x, vp.y, asp])
	if absf(asp - 16.0 / 9.0) > 0.15:
		print("  ⚠️ IL QUADRO NON HA LE PROPORZIONI DI UNO SCHERMO (%.2f:1 invece" % asp)
		print("     di 1.78:1). `--headless` da' un viewport 64x64, cioe' un")
		print("     campo orizzontale molto piu' STRETTO: «quanti il giocatore")
		print("     ne vede» esce SOTTOSTIMATO. Per quel numero serve")
		print("     --resolution 1280x720 SENZA --headless.")
	# `Llm` e' una `class_name` con funzioni statiche, non un autoload
	print("  il villaggio pensa (Fase 5): acceso %s · binario capace %s · modello «%s»"
			% [Llm.acceso(), Llm.disponibile(), Llm.percorso_modello()])
	# quanti marchi ha addosso il villaggio ADESSO — e la sorgente e' una
	var animi0: Dictionary = _vis.get("_animi")
	var m0 := _conta_marchi(animi0)
	print("  marchi nel villaggio: %d su LUOGHI · %d su PERSONE"
			% [int(m0["luogo"]), int(m0["chi"])])
	print("     (solo quelli su LUOGO producono l'evitamento, e l'unica")
	print("      sorgente in partita e' `Visitors.assegna_compito`)")
	# ⚠️ LA SCALA DELLA RIBELLIONE spiega da sola tre zeri: `_tick_confronti`
	# (e quindi «si e' trattenuto») esiste solo da `confronto` in su, e la
	# partenza per rancore solo da `diserzione`.
	var grad := {}
	for l1 in animi0:
		var g := int((animi0[l1] as RefCounted).gradino)
		grad[ANIMO.SCALA[clampi(g, 0, ANIMO.SCALA.size() - 1)]] = \
				int(grad.get(ANIMO.SCALA[clampi(g, 0, ANIMO.SCALA.size() - 1)], 0)) + 1
	print("  la scala della ribellione, oggi: %s" % str(grad))
	print("     («si_e_trattenuto» vuole almeno «confronto»: %s)"
			% ("possibile" if ANIMO.almeno(_gradino_max(animi0), "confronto")
			else "IMPOSSIBILE in questo villaggio"))
	if not _camera_viva:
		print("  ⚠️⚠️ IL FRUSTUM NON RISPONDE (tipico di `--headless`): il")
		print("     cancello `_nell_inquadratura` bocchera' OGNI gesto, e D5")
		print("     conterebbe ZERO per colpa del banco. RIFAI LA CORSA CON LA")
		print("     FINESTRA:  Godot --path . --resolution 1280x720 --script …")
	print("")


# =========================================================================
#  D3 + D5 — LA PARTITA
# =========================================================================

func _conta(fam: String, visto: bool) -> void:
	var k := fam + "|" + _fase
	_ev[k] = int(_ev.get(k, 0)) + 1
	if visto:
		_ev_visti[k] = int(_ev_visti.get(k, 0)) + 1


func _in_quadro(p: Vector3) -> bool:
	if not _camera_viva:
		return true
	var cam := get_root().get_camera_3d()
	if cam == null:
		return true
	return cam.is_position_in_frustum(p + Vector3(0, 0.6, 0))


func _partita(res: Array) -> void:
	print("─".repeat(74))
	print("D3 + D5 — LA PARTITA: %.1f giornate (%.0f s reali), a blocchi"
			% [_giorni, _giorni * float(_dn.get("cycle_seconds"))])
	print("   alternati «con il giocatore» / «senza», %.0f s l'uno" % BLOCCO)
	print("─".repeat(74))
	var animi: Dictionary = _vis.get("_animi")
	for r in res:
		var l := str((r as Dictionary).get("label", ""))
		if animi.has(l):
			_animi_ref[l] = (animi[l] as RefCounted).limbico
		_gesto_prec[l] = ""
		_soma_prec[l] = 0.0
		_bench_prec[l] = false
		_az_prec[l] = -99
		_luoghi_evit_prec[l] = 0
	_cric_prec = ((_cric.call("debug_stato") as Dictionary).get("cricche", []) as Array).size() \
			if _cric != null else 0

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260817
	var meta := Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10))
	var sosta := 0.0
	var lavoro := 3.0
	var verbo := 0
	const VERBI := ["annaffia", "semina", "raccoglie", "costruisce", "pesca"]

	var ciclo := float(_dn.get("cycle_seconds"))
	var totale := _giorni * ciclo
	var t := 0.0
	var t_blocco := 0.0
	var ms := Time.get_ticks_msec()
	var avviso := 0.0
	while t < totale:
		await process_frame
		var ora := Time.get_ticks_msec()
		var dt := float(ora - ms) / 1000.0
		ms = ora
		if dt <= 0.0 or dt > 0.5:
			continue
		t += dt
		t_blocco += dt
		_sec[_fase] += dt
		_fps_acc += 1.0 / dt
		_fps_n += 1
		if t_blocco >= BLOCCO:
			t_blocco = 0.0
			_fase = "senza" if _fase == "con" else "con"
			if _fase == "senza":
				_player.global_position = LONTANO
			else:
				_player.global_position = Vector3(rng.randf_range(-6, 6), 0,
						rng.randf_range(-6, 6))
				meta = _player.global_position
		if t - avviso > 60.0:
			avviso = t
			print("   … %.0f s (%.2f giornate) · fase «%s» · eventi %d"
					% [t, t / ciclo, _fase, _quanti_eventi()])

		# --- Mochi cammina come cammina un giocatore ---------------------
		# …e nel blocco «senza» sta LONTANA da tutto, inchiodata ogni
		# fotogramma (la gravita' del PlayerController la farebbe cadere,
		# e un giocatore che precipita non e' un giocatore assente).
		if _fase == "senza":
			_player.global_position = LONTANO
		if _fase == "con":
			var p := _player.global_position
			if sosta > 0.0:
				sosta -= dt
			elif Vector2(p.x - meta.x, p.z - meta.z).length() < 1.0:
				sosta = 2.5
				if rng.randf() < 0.34 and not res.is_empty():
					var q := (res[rng.randi() % res.size()] as Dictionary).get("node") as Node3D
					meta = q.global_position if (q != null and is_instance_valid(q)) \
							else Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
				else:
					meta = Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
			var verso := meta - p
			verso.y = 0.0
			if sosta <= 0.0 and verso.length() > 0.01:
				# ⚠️ ALLA VELOCITA' VERA, letta dal giocatore vero: sotto
				# 1,6 m/s `indizio_grezzo` non vede niente di brusco e
				# **nessuno sussulta mai**.
				var lontano: bool = verso.length() > 8.0
				var vel: float = float(_player.get("run_speed") if lontano
						else _player.get("walk_speed"))
				if vel <= 0.0:
					vel = 6.0 if lontano else 3.0
				_player.global_position = p + verso.normalized() * vel * dt
			# …e LAVORA, in raffica come lavora un giocatore vero
			lavoro -= dt
			if lavoro <= 0.0:
				lavoro = 5.5
				if _perc != null:
					for _k in (2 + verbo % 3):
						_perc.call("accaduto", VERBI[verbo % VERBI.size()],
								_player.global_position)
					verbo += 1
		_censimento(res, dt)
	print("")


func _quanti_eventi() -> int:
	var n := 0
	for k in _ev:
		n += int(_ev[k])
	return n


## L'ORACOLO INDIPENDENTE, e gira OGNI fotogramma: un fronte che comincia e
## finisce fra due campioni radi e' un fronte che non esiste.
func _censimento(res: Array, dt: float) -> void:
	_campioni += 1
	_sus_cd = _vis.get("_sussulto_cd")
	var in_quadro := 0
	var seduti: Array = []
	for r in res:
		var d := r as Dictionary
		var n := d.get("node") as Node3D
		if n == null or not is_instance_valid(n):
			continue
		var lab := str(d.get("label", ""))
		var pos := n.global_position
		var visto := _in_quadro(pos)
		if visto:
			in_quadro += 1
		if _camera_viva:
			if visto:
				_frustum_si += 1
			else:
				_frustum_no += 1

		# 1 · IL GESTO — letto dal CORPO, non dal contatore di Visitors
		if n.has_method("gesto_in_corso"):
			var g := str(n.call("gesto_in_corso"))
			if g != "" and str(_gesto_prec.get(lab, "")) == "":
				_conta("gesto", visto)
				_conta("gesto:" + g, visto)
			_gesto_prec[lab] = g

		# 4 · IL PERCETTO — l'oracolo e' il RAFFREDDAMENTO che salta
		#     all'insu' (`_sussulto_cd`), lo stesso di `misura_sussulti`:
		#     `_tick_sussulti` lo rimette a 9,0 nell'istante in cui chiama
		#     `percepisci`. La reazione la dice il Limbico.
		var ora_cd := float(_sus_cd.get(lab, 0.0))
		if ora_cd > float(_soma_prec.get(lab, 0.0)) + 0.0001:
			var lim: RefCounted = _animi_ref.get(lab)
			var rea := "nulla"
			if lim != null:
				rea = str((lim.ultimo_sussulto as Dictionary).get("reazione", "nulla"))
			if rea != "nulla":
				_conta("sussulto", visto)
				_conta("sussulto:" + rea, visto)
		_soma_prec[lab] = ora_cd

		# 3 · LA SEDUTA — il fronte, dallo stato del corpo
		var seduto := str(n.get("_state")) == "r_bench"
		if seduto:
			seduti.append([lab, pos, visto])
		_bench_prec[lab] = seduto

		# 5 · LA RINUNCIA A UN LUOGO — quanti posti quel vicino evita
		var ev: int = (_vis.call("luoghi_evitati", lab) as Array).size()
		if ev > int(_luoghi_evit_prec.get(lab, 0)):
			_conta("evitamento", visto)
		_luoghi_evit_prec[lab] = ev

	_corpi_tot += in_quadro
	_quadro_max = maxi(_quadro_max, in_quadro)
	_corpi_in_quadro[in_quadro] = int(_corpi_in_quadro.get(in_quadro, 0)) + 1

	# 3bis · LA CO-SEDUTA: due corpi seduti entro VICINI. Contata dalle
	# POSIZIONI, mai chiedendo a `_seduto_accanto`.
	var viste: Dictionary = {}
	for i in seduti.size():
		for j in range(i + 1, seduti.size()):
			var pa: Vector3 = seduti[i][1]
			var pb: Vector3 = seduti[j][1]
			if pa.distance_to(pb) > VISITORS.VICINI:
				continue
			var k: String = "%s|%s" % [seduti[i][0], seduti[j][0]]
			viste[k] = true
			_seduti_accanto_sec[_fase] += dt
			if not bool(_coppia_sed.get(k, false)):
				_conta("coseduta", bool(seduti[i][2]) or bool(seduti[j][2]))
				var kk := "posto accanto|" + _fase
				_uscite[kk] = int(_uscite.get(kk, 0)) + 1
	for k2 in _coppia_sed.keys():
		if not viste.has(k2):
			_coppia_sed.erase(k2)
	for k3 in viste:
		_coppia_sed[k3] = true

	# 2 · LA CHIACCHIERATA — il log dei raffreddamenti di `_chats`. E' un
	# REGISTRO di cio' che e' successo, non un giudizio: la controprova e'
	# che i due corpi sono entro `VICINI` nell'istante in cui compare.
	var cd: Dictionary = _vis.get("_pair_cd")
	for k4 in cd:
		if int(cd[k4]) != int(_chat_prec.get(k4, -1)):
			_chat_prec[k4] = int(cd[k4])
			var pezzi := str(k4).split("_")
			var visto2 := false
			if pezzi.size() == 2:
				var ra: Dictionary = res[int(pezzi[0])] if int(pezzi[0]) < res.size() else {}
				var na := ra.get("node") as Node3D
				if na != null and is_instance_valid(na):
					visto2 = _in_quadro(na.global_position)
			_conta("chiacchierata", visto2)

	# 6 · LE CRICCHE (campione rado: `debug_stato` duplica i dizionari)
	if _cric != null and _campioni % 15 == 0:
		var st: Dictionary = _cric.call("debug_stato")
		var q := ((st.get("cricche", []) as Array)).size()
		if q > _cric_prec:
			_conta("cricca", true)
		_cric_prec = q

	# 7 · IL MESTIERE DIROTTATO DA UNA DEDUZIONE (rado)
	var dd: Dictionary = _vis.call("debug_deduzioni_contatori") \
			if _campioni % 15 == 0 else {}
	for k5 in dd:
		if int(dd[k5]) > int(_ded_prec.get(k5, 0)):
			if str(k5).find("mestier") >= 0 or str(k5).find("dirott") >= 0:
				_conta("deduzione", true)
		_ded_prec[k5] = int(dd[k5])

	# --- D3 : le vie d'uscita che capitano da sole ----------------------
	# l'ACCOMPAGNAMENTO: quante volte, campionando, esiste un candidato
	var acc := _trova("accompagna")
	if acc != null and acc.has_method("_candidato") and _campioni % 15 == 0:
		_accomp_camp[_fase] += 1
		if not (acc.call("_candidato") as Array).is_empty():
			_accomp_candidati[_fase] += 1


# =========================================================================
#  D1 — IL RITORNO A RIPOSO
# =========================================================================

## Il colpo si da' dalle PORTE VERE — `rivaluta`, `trattieni`,
## `Percezione.accaduto` — mai scrivendo il campo a mano: scrivere il
## marchio a mano vorrebbe dire provare un villaggio che non esiste.
func _ritorno_a_riposo(res: Array) -> void:
	print("─".repeat(74))
	print("D1 — IL RITORNO A RIPOSO: %.1f giornate, coi passi VERI"
			% _riposo_gg)
	print("   (`passo_neuro` 60 volte al secondo da `Visitors`,")
	print("    `passa_giorno` una volta per giornata dal calendario vero)")
	print("─".repeat(74))
	var animi: Dictionary = _vis.get("_animi")
	_cavie.clear()
	for r in res:
		var l := str((r as Dictionary).get("label", ""))
		if animi.has(l):
			_cavie.append(l)
		if _cavie.size() >= 3:
			break
	if _cavie.is_empty():
		print("   ZERO cavie: nessun residente ha un Animo. Non e' un guasto")
		print("   del substrato, e' un villaggio senza abitanti.")
		return
	print("   cavie: %s" % str(_cavie))

	# --- il PESO DI UN RICORDO, dal grafo vero --------------------------
	# Si mette un ricordo VERO nel grafo (`Percezione.accaduto` addosso a una
	# cavia) e si guarda il suo peso decadere. La mezza vita la dice il
	# BINARIO, non una costante ricopiata.
	var cost: Dictionary = _ecs.debug_grafo_costanti() if _ecs != null else {}
	var mv := float(cost.get("mezza_vita", 120.0))
	var nodo0 := _vis.call("node_di", _cavie[0]) as Node3D
	if nodo0 != null and _perc != null:
		_player.global_position = nodo0.global_position + Vector3(1.2, 0, 0)
		await process_frame
		_perc.call("accaduto", "dona", _player.global_position, _cavie[0])
		await process_frame

	# --- I COLPI, dalle porte vere, e UNA CAVIA PER CANALE ---------------
	# ⚠️ Tre colpi sullo stesso corpo non sono tre misure: il lutto alza il
	# cortisolo, lo spavento alza l'arousal, e a quel punto ogni canale
	# sta rispondendo anche agli altri due. Ognuna prende il SUO colpo, e
	# ognuno passa dalla porta che il gioco usa davvero.
	var A: RefCounted = animi[_cavie[0]]
	var B: RefCounted = animi[_cavie[1]] if _cavie.size() > 1 else A
	var C: RefCounted = animi[_cavie[2]] if _cavie.size() > 2 else A
	var p0 := {"cort": float(A.limbico.neuro.get("cortisolo", 0.0)),
			"umore": float(A.limbico.umore)}
	var p1 := float(B.limbico.carica_di("cucina"))
	var p2 := {"reg": float(C.limbico.regolazione), "att": _attesa_max(C.limbico)}
	# A) il LUTTO — la porta vera di `Congedo._giorno_di_lutto` → `lutto_di`
	A.lutto("un amico")
	# B) lo SPAVENTO ripetuto in un luogo — la porta vera del marchio
	#    (`_tick_sussulti` + `rivaluta`, la doppia strada)
	for _i in 3:
		B.limbico.rivaluta("spavento", "", -0.9, "cucina", true)
	# C) i MORSI TRATTENUTI (`_tick_confronti`) e il LAVORO CHE TRADISCE IL
	#    SOGNO (`Lavori` → `Animo.esegue`): regolazione e attese
	for _i2 in 3:
		C.limbico.trattieni()
	# ⚠️ IL COMPITO SI SCEGLIE SUL SOGNO DI QUELLA PERSONA. `taglia_legna`
	# tradisce solo chi sogna di fare il guerriero o l'artista: dato a un
	# boscaiolo e' un regalo, e l'attesa non si muove di un bit — cioe' il
	# banco misurerebbe il proprio sorteggio invece del canale.
	var sogno := str(C.get("sogno"))
	var compito := "taglia_legna"
	for k in ANIMO.COMPITI:
		if sogno in ((ANIMO.COMPITI[k] as Dictionary).get("tradisce", []) as Array):
			compito = str(k)
			break
	for _i3 in 3:
		C.esegue(compito)

	var li0: RefCounted = A.limbico
	var li1: RefCounted = B.limbico
	var li2: RefCounted = C.limbico
	print("   i colpi, misurati subito dopo:")
	print("     A «%s» — un LUTTO" % _cavie[0])
	print("        cortisolo %.4f → %.4f (riposo %.4f) · umore %.4f → %.4f"
			% [p0["cort"], float(li0.neuro.get("cortisolo", 0.0)),
			float(li0.neuro_base.get("cortisolo", 0.10)),
			p0["umore"], li0.umore])
	print("        arousal %.4f · stato del corpo: «%s»"
			% [li0.arousal, li0.stato_corpo()])
	print("     B «%s» — tre SPAVENTI in cucina" % _cavie[1 if _cavie.size() > 1 else 0])
	print("        marchio «cucina» %.4f → %.4f · gira al largo? %s"
			% [p1, li1.carica_di("cucina"), li1.evita("cucina")])
	print("     C «%s» — tre MORSI trattenuti + tre «%s» (sogna «%s»)"
			% [_cavie[2 if _cavie.size() > 2 else 0], compito, sogno])
	print("        regolazione %.4f → %.4f · attesa max %.4f → %.4f"
			% [p2["reg"], li2.regolazione, p2["att"], _attesa_max(li2)])

	var ciclo := float(_dn.get("cycle_seconds"))
	_giorno_riposo0 = int(_dn.get("day"))
	var t := 0.0
	var ms := Time.get_ticks_msec()
	var prossimo := 0.0
	var giorno_prec := _giorno_riposo0
	var per_giorno := []
	while t < _riposo_gg * ciclo:
		await process_frame
		var ora := Time.get_ticks_msec()
		var dt := float(ora - ms) / 1000.0
		ms = ora
		if dt <= 0.0 or dt > 0.5:
			continue
		t += dt
		# Mochi resta lontana: il ritorno a riposo si misura senza che il
		# giocatore rimetta mano ai canali che sta guardando.
		_player.global_position = LONTANO
		if t >= prossimo:
			prossimo += 1.0
			_campiona_canali(li0, li1, li2, t / ciclo)
		var g := int(_dn.get("day"))
		if g != giorno_prec:
			giorno_prec = g
			per_giorno.append({"g": g - _giorno_riposo0,
					"marchio": li1.carica_di("cucina"),
					"attesa_max": _attesa_max(li2),
					"reg": li2.regolazione,
					"umore": li0.umore,
					"cort": float(li0.neuro.get("cortisolo", 0.0))})
	_referto_riposo(li0, per_giorno, mv)


func _attesa_max(li: RefCounted) -> float:
	var m := 0.0
	for k in li.attese:
		m = maxf(m, absf(float(li.attese[k])))
	return m


func _campiona_canali(a: RefCounted, b: RefCounted, c: RefCounted,
		tg: float) -> void:
	for nome in ["cortisolo", "serotonina", "adenosina"]:
		if not _tracce.has(nome):
			_tracce[nome] = []
		(_tracce[nome] as Array).append([tg, float(a.neuro.get(nome, 0.0))])
	for coppia in [["umore", a.umore], ["arousal", a.arousal],
			["regolazione", c.regolazione], ["marchio", b.carica_di("cucina")],
			["attesa", _attesa_max(c)]]:
		var n2 := str(coppia[0])
		if not _tracce.has(n2):
			_tracce[n2] = []
		(_tracce[n2] as Array).append([tg, float(coppia[1])])


## Quante GIORNATE per tornare entro `eps` dal riposo. -1 = non ci arriva
## dentro la finestra misurata (e allora si estrapola, e si dice che e'
## un'estrapolazione).
func _quando_torna(nome: String, riposo: float, eps: float) -> float:
	var tr: Array = _tracce.get(nome, [])
	if tr.is_empty():
		return -1.0
	for c in tr:
		if absf(float(c[1]) - riposo) <= eps:
			return float(c[0])
	return -1.0


func _referto_riposo(li: RefCounted, per_giorno: Array, mv: float) -> void:
	print("")
	print("   ► I CANALI CONTINUI (li muove `passo_neuro`, 60 volte al secondo)")
	var basi := {"cortisolo": float(li.neuro_base.get("cortisolo", 0.10)),
			"serotonina": float(li.neuro_base.get("serotonina", 0.50)),
			"adenosina": 0.0, "umore": 0.0, "arousal": 0.0,
			"regolazione": 1.0, "marchio": 0.0, "attesa": 0.0}
	for nome in ["cortisolo", "serotonina", "adenosina", "umore", "arousal",
			"regolazione", "marchio", "attesa"]:
		var riposo := float(basi.get(nome, 0.0))
		var tr: Array = _tracce.get(nome, [])
		if tr.is_empty():
			continue
		var v0 := float((tr[0] as Array)[1])
		var q := _quando_torna(nome, riposo, 0.02)
		print("     %-11s da %+.4f · riposo %+.4f · dentro 0.02 dopo %s"
				% [nome, v0, riposo,
				("%.3f giornate (%.0f s reali)" % [q, q * float(_dn.get("cycle_seconds"))])
				if q >= 0.0 else "NON ci arriva in %.1f giornate" % _riposo_gg])
	print("")
	print("   ► I CANALI GIORNALIERI (li muove SOLO `passa_giorno`, una volta")
	print("     per giornata: qui si vede se il calendario vero li chiama)")
	print("     gg | marchio | attesa | regolaz | umore  | cortisolo")
	for r in per_giorno:
		var d := r as Dictionary
		print("     %2d | %+7.4f | %6.4f | %7.4f | %+6.4f | %.4f"
				% [int(d["g"]), float(d["marchio"]), float(d["attesa_max"]),
				float(d["reg"]), float(d["umore"]), float(d["cort"])])
	if per_giorno.size() >= 2:
		var a := per_giorno[0] as Dictionary
		var b := per_giorno[per_giorno.size() - 1] as Dictionary
		var passi := int(b["g"]) - int(a["g"])
		var passo := (absf(float(a["marchio"])) - absf(float(b["marchio"]))) / maxf(1.0, float(passi))
		print("")
		print("     il marchio scende di %.4f per giornata (la costante e'"
				% passo)
		print("     `Limbico.ESTINZIONE` = %.2f, e il passo e' LINEARE:"
				% LIMBICO.ESTINZIONE)
		if passo > 0.0001:
			var gg := absf(float(b["marchio"])) / passo
			print("     da qui a zero mancano %.1f giornate = %.0f minuti reali"
					% [gg, gg * float(_dn.get("cycle_seconds")) / 60.0])
			var soglia := LIMBICO.SOGLIA_EVITAMENTO
			var gg2 := maxf(0.0, (absf(float(b["marchio"])) - soglia) / passo)
			print("     …e smette di girare al largo (|carica| < %.2f) fra %.1f giornate"
					% [soglia, gg2])
		else:
			print("     ⚠️ IL MARCHIO NON SI E' MOSSO: `passa_giorno` non e' stato")
			print("        chiamato, oppure lo chiama qualcuno con sbiadisci=false")
	print("")
	print("   ► IL PESO DI UN RICORDO nel grafo (mezza vita dal BINARIO: %.0f s)" % mv)
	if _ecs != null:
		# R_SU_DI_ME = 1u << 1 (l'unica asimmetria del grafo), e la
		# soglia sotto cui un ricordo smette di contare la dice il codice
		var r0 := {"quante": 1, "quando": 0.0, "bandiere": 0}
		var r1 := {"quante": 6, "quando": 0.0, "bandiere": 0}
		var r2 := {"quante": 1, "quando": 0.0, "bandiere": 2}
		print("     giornate | visto una volta | visto sei volte | fatto A ME")
		for gg2 in [0.0, 0.25, 0.5, 1.0, 2.0, 4.0]:
			var t: float = gg2 * float(_dn.get("cycle_seconds"))
			print("        %5.2f | %15.4f | %15.4f | %10.4f"
					% [gg2, _ecs.debug_grafo_peso(r0, t, mv),
					_ecs.debug_grafo_peso(r1, t, mv),
					_ecs.debug_grafo_peso(r2, t, mv)])
		print("     ⚠️ e questo grafo NON E' PERSISTITO: muore col processo.")
		print("        «Torna a riposo» qui vuol dire anche «riaprendo il")
		print("        gioco e' gia' a zero», per progetto.")
	print("")


# =========================================================================
#  D4 — IL TETTO
# =========================================================================

func _tetto(res: Array) -> void:
	print("─".repeat(74))
	print("D4 — IL TETTO: quanti vicini potrebbero essere deviati INSIEME")
	print("─".repeat(74))
	var oggi := int(_dn.get("day"))
	# chi e' il prossimo a partire, e quanti hanno un filo con lui
	var anziano := ""
	var anziano_gg := -1
	for r in res:
		var nome := str(((r as Dictionary).get("dna", {}) as Dictionary).get("name", ""))
		if nome == "":
			continue
		var g := int(_leg.call("giorni_di_amicizia", nome))
		if g > anziano_gg:
			anziano_gg = g
			anziano = nome
	print("   il prossimo a partire: %s, %d giorni d'amicizia"
			% [anziano, anziano_gg])
	print("     (serve %d: mancano %d giornate = %.0f minuti reali)"
			% [CONGEDO.ETA_PARTENZA, maxi(0, CONGEDO.ETA_PARTENZA - anziano_gg),
			maxi(0, CONGEDO.ETA_PARTENZA - anziano_gg)
					* float(_dn.get("cycle_seconds")) / 60.0])
	# QUANTI hanno un filo, e di che spessore
	var fili := {}
	for r in res:
		var nome := str(((r as Dictionary).get("dna", {}) as Dictionary).get("name", ""))
		if nome == "":
			continue
		fili[nome] = int(_leg.call("momenti_vissuti", nome))
	var sopra1 := 0
	var sopra3 := 0
	var sopra6 := 0
	for n in fili:
		if int(fili[n]) >= 1:
			sopra1 += 1
		if int(fili[n]) >= 3:
			sopra3 += 1
		if int(fili[n]) >= 6:
			sopra6 += 1
	print("   fili del giocatore col villaggio: %d residenti, di cui" % res.size())
	print("     %d con ≥1 momento · %d con ≥3 · %d con ≥6" % [sopra1, sopra3, sopra6])
	print("   ⚠️ MA IL FILO DEL GIOCATORE NON E' IL LEGAME FRA DUE VICINI:")
	print("      `Legami` tiene solo i fili verso MOCHI. Chi abbia un legame")
	print("      con chi PARTE si legge da `Affetti` e da `Cricche`.")
	# le coppie e le cricche vive
	var aff := _trova("affetti")
	# ⚠️ **CHI SAREBBE TOCCATO da una partenza?** Non «tutti i residenti»
	# (quella e' `da_consolare`, ed e' l'aggancio che romperebbe la regola
	# 7): chi aveva un legame VERO con chi parte. Il libro mastro degli
	# Affetti e' l'unico posto del gioco che tiene un legame fra due VICINI,
	# e la sua scala e' `SOGLIA_COPPIA`. Si stampa la distribuzione, non un
	# numero: e' la forma che decide se il tetto serve scriverlo o se il
	# mondo lo ha gia' scritto.
	if aff != null and anziano != "":
		# ⚠️ **LA CHIAVE DEGLI AFFETTI E' IL NOME, NON LA LABEL.**
		# `Affetti._tutti()` cicla i residenti e prende `dna.name`: passando
		# la label si ottengono dodici zeri, che si leggono come «nessuno gli
		# voleva bene» invece che come «hai chiesto in un'altra lingua».
		# (E' la trappola delle DUE ANAGRAFI, gia' pagata dal Filo Rosso.)
		var conti: Array = []
		for r in res:
			var nome2 := str(((r as Dictionary).get("dna", {}) as Dictionary).get("name", ""))
			if nome2 == anziano or nome2 == "":
				continue
			conti.append([nome2, float(aff.call("quanto", anziano, nome2)),
					float(aff.call("quanto", nome2, anziano))])
		conti.sort_custom(func(x, y): return minf(float(x[1]), float(x[2])) > minf(float(y[1]), float(y[2])))
		print("")
		print("   ► CHI AVEVA UN LEGAME CON CHI PARTE (Affetti.quanto,")
		print("     soglia della coppia %.1f — il minimo RECIPROCO)"
				% AFFETTI.SOGLIA_COPPIA)
		var sopra := 0
		for i in conti.size():
			var c: Array = conti[i]
			var minimo: float = minf(float(c[1]), float(c[2]))
			if minimo >= AFFETTI.SOGLIA_COPPIA:
				sopra += 1
			if i < 6:
				print("       %-14s verso lui %.3f · da lui %.3f · min %.3f"
						% [str(c[0]).substr(0, 14), float(c[1]), float(c[2]), minimo])
		print("     residenti col minimo reciproco sopra soglia: %d su %d"
				% [sopra, conti.size()])
		if _cric != null:
			print("     compagni di cricca di chi parte: %s"
					% str(_cric.call("compagni", anziano)))
		# …e il LEGAME PIU' FORTE DEL VILLAGGIO, chiunque sia: e' il tetto
		# vero. Se nemmeno il primo della classifica arriva alla soglia, il
		# tetto non serve scriverlo — il mondo lo ha gia' scritto.
		var nomi: Array = []
		for r2 in res:
			var n3 := str(((r2 as Dictionary).get("dna", {}) as Dictionary).get("name", ""))
			if n3 != "":
				nomi.append(n3)
		var tutti_conti: Array = []
		for i2 in nomi.size():
			for j2 in range(i2 + 1, nomi.size()):
				var m2: float = minf(float(aff.call("quanto", nomi[i2], nomi[j2])),
						float(aff.call("quanto", nomi[j2], nomi[i2])))
				tutti_conti.append([m2, nomi[i2], nomi[j2]])
		tutti_conti.sort_custom(func(x, y): return float(x[0]) > float(y[0]))
		print("     i tre legami piu' forti del villaggio (su %d coppie):"
				% tutti_conti.size())
		for i3 in mini(3, tutti_conti.size()):
			var c3: Array = tutti_conti[i3]
			print("       %.3f  %s — %s%s" % [float(c3[0]), str(c3[1]), str(c3[2]),
					"  ← SOPRA SOGLIA" if float(c3[0]) >= AFFETTI.SOGLIA_COPPIA else ""])
		var q_sopra := 0
		for c4 in tutti_conti:
			if float((c4 as Array)[0]) >= AFFETTI.SOGLIA_COPPIA:
				q_sopra += 1
		print("     coppie sopra %.1f: %d su %d"
				% [AFFETTI.SOGLIA_COPPIA, q_sopra, tutti_conti.size()])
	var coppie: Array = (aff.call("le_coppie") as Array) if aff != null else []
	print("   coppie vive (Affetti.le_coppie): %d %s"
			% [coppie.size(), str(coppie) if coppie.size() <= 6 else ""])
	if aff != null:
		var sa: Dictionary = aff.call("debug_stato")
		print("   …righe del libro mastro: %s" % str(sa))
	if _cric != null:
		var st: Dictionary = _cric.call("debug_stato")
		print("   cricche di oggi: %d · coppie che si ritrovano: %d · righe: %d"
				% [(st.get("cricche", []) as Array).size(),
				int(st.get("coppie", 0)), int(st.get("incontri", 0))])
	# il tetto OTTICO: quanti corpi stanno insieme nell'inquadratura
	print("")
	print("   ► IL TETTO OTTICO — quanti corpi il giocatore ha in quadro")
	print("     massimo visto: %d corpi insieme" % _quadro_max)
	if _campioni > 0:
		print("     media: %.2f corpi in quadro" % (float(_corpi_tot) / float(_campioni)))
		var chiavi: Array = _corpi_in_quadro.keys()
		chiavi.sort()
		var righe := []
		for k in chiavi:
			righe.append("%d:%.1f%%" % [int(k),
					100.0 * float(_corpi_in_quadro[k]) / float(_campioni)])
		print("     distribuzione: %s" % ", ".join(PackedStringArray(righe)))
	print("")


# =========================================================================
#  D2 — IL CALENDARIO (per ULTIMO: muove il mondo di anni)
# =========================================================================

func _calendario(res: Array) -> void:
	print("─".repeat(74))
	print("D2 — LE ORIGINI: %d anni di calendario (%d giornate)"
			% [_anni, _anni * 28])
	print("   Le partenze, i lutti e le nascite si decidono SOLO su")
	print("   `day_changed`: guidare quel segnale e' la domanda giusta.")
	print("   Da qui in poi il mondo e' avanti di anni: non si misura")
	print("   piu' niente che dipenda dai fotogrammi.")
	print("─".repeat(74))
	# i cancelli, letti dal codice invece che ricopiati
	print("   i cancelli, letti dalle costanti vere:")
	print("     una stagione dura %d giornate (%.0f minuti reali)"
			% [7, 7 * float(_dn.get("cycle_seconds")) / 60.0])
	print("     partenza: %d giorni d'amicizia, e mai due a meno di %d giorni"
			% [CONGEDO.ETA_PARTENZA, CONGEDO.DISTANZA_PARTENZE])
	print("     il congedo dura %d giornate, poi il lutto ne dura 3..8"
			% CONGEDO.GIORNI_CONGEDO)
	print("     nascita: solo in primavera, e mai piu' di una ogni %d giornate"
			% NASCITE.GIORNI_ANNO)
	print("     un cucciolo diventa adulto in %d giornate" % LEGAMI.GIORNI_ADULTO)
	print("")
	var giorno0 := int(_dn.get("day"))
	var partiti0 := (_leg.call("partiti") as Array).size()
	var res0 := (_vis.get("_residents") as Array).size()
	var lutti := 0
	var lutto_prec := false
	var congedi := 0
	var cong_prec := false
	var nascite := 0
	var nasc_prec := false
	# traccia stagionale
	var per_stagione := {}
	var giorni := _anni * 28
	for k in giorni:
		var g := giorno0 + k + 1
		_dn.call("debug_set_day", g)
		await process_frame
		var st := int(_dn.call("get_season"))
		var chiave := "%d" % st
		if not per_stagione.has(chiave):
			per_stagione[chiave] = {"partenze": 0, "lutti": 0, "nascite": 0}
		var in_lutto: bool = bool(_leg.call("lutto_attivo"))
		if in_lutto and not lutto_prec:
			lutti += 1
			(per_stagione[chiave] as Dictionary)["lutti"] += 1
		lutto_prec = in_lutto
		var in_cong: bool = _cong != null and not (_cong.get("_congedo") as Dictionary).is_empty()
		if in_cong and not cong_prec:
			congedi += 1
			(per_stagione[chiave] as Dictionary)["partenze"] += 1
		cong_prec = in_cong
		var in_nasc: bool = _nasc != null and not (_nasc.get("_in_arrivo") as Dictionary).is_empty()
		if in_nasc and not nasc_prec:
			nascite += 1
			(per_stagione[chiave] as Dictionary)["nascite"] += 1
		nasc_prec = in_nasc
	var partiti1 := (_leg.call("partiti") as Array).size()
	print("   in %d giornate (%d anni · %d stagioni · %.0f ore reali):"
			% [giorni, _anni, _anni * 4, giorni * float(_dn.get("cycle_seconds")) / 3600.0])
	print("     congedi cominciati ......... %d" % congedi)
	print("     partenze compiute .......... %d" % (partiti1 - partiti0))
	print("     lutti aperti ............... %d" % lutti)
	print("     annunci di nascita ......... %d" % nascite)
	print("     residenti: %d → %d" % [res0, (_vis.get("_residents") as Array).size()])
	print("")
	var stagioni := float(_anni * 4)
	print("   ► PER STAGIONE (7 giornate = %.0f minuti reali):"
			% (7.0 * float(_dn.get("cycle_seconds")) / 60.0))
	print("     partenze %.2f · lutti %.2f · nascite %.2f"
			% [float(congedi) / stagioni, float(lutti) / stagioni,
			float(nascite) / stagioni])
	print("   ► PER ORA REALE DI GIOCO (15 giornate):")
	var ore := giorni * float(_dn.get("cycle_seconds")) / 3600.0
	print("     partenze %.2f · lutti %.2f · nascite %.2f"
			% [float(congedi) / ore, float(lutti) / ore, float(nascite) / ore])
	if congedi == 0:
		print("   ⚠️ ZERO CONGEDI, e il perche' conta piu' del numero: guarda")
		print("      i giorni d'amicizia in D4. Se il piu' anziano e' sotto")
		print("      %d, il cancello non e' mai stato aperto." % CONGEDO.ETA_PARTENZA)
	if nascite == 0:
		print("   ⚠️ ZERO NASCITE: servono una coppia di sesso diverso con")
		print("      affinita' ≥ %d, una casa libera, e la primavera."
				% NASCITE.AFFINITA_MINIMA)
		# …e quell'«affinita'» e' `Visitors.affetto_fra`, cioe' il LIBRO
		# MASTRO degli Affetti — la stessa scala di `coppia()`, che ha
		# soglia 2.4. Otto e' PIU' DEL TRIPLO: si misura, non si suppone.
		var res2: Array = _vis.get("_residents")
		var top := 0.0
		var chi := ""
		for i2 in res2.size():
			for j2 in range(i2 + 1, res2.size()):
				var la := str((res2[i2] as Dictionary).get("label", ""))
				var lb := str((res2[j2] as Dictionary).get("label", ""))
				var v: float = minf(float(_vis.call("affetto_fra", la, lb)), float(_vis.call("affetto_fra", lb, la)))
				if v > top:
					top = v
					chi = "%s — %s" % [la, lb]
		print("      MISURATO: l'affetto reciproco piu' alto del villaggio e'")
		print("      %.3f (%s), contro una soglia di %d: %.0f volte tanto."
				% [top, chi, NASCITE.AFFINITA_MINIMA, float(NASCITE.AFFINITA_MINIMA) / maxf(0.001, top)])
		print("      E la soglia della COPPIA (`Affetti.SOGLIA_COPPIA`) e'")
		print("      %.1f: la nascita ne chiede piu' del triplo." % AFFETTI.SOGLIA_COPPIA)
	_referto_partita()


# =========================================================================
#  il referto della partita (stampato in coda, con tutti i numeri in mano)
# =========================================================================

func _referto_partita() -> void:
	var ciclo := float(_dn.get("cycle_seconds"))
	print("")
	print("═".repeat(74))
	print("D5 — GLI EVENTI EMERGENTI (la definizione e' in cima al file)")
	print("═".repeat(74))
	var fam := ["gesto", "chiacchierata", "coseduta", "sussulto",
			"evitamento", "cricca", "deduzione"]
	print("   %-16s %8s %8s | %8s %8s | %s"
			% ["famiglia", "CON", "SENZA", "visti", "vis/h", "all'ora"])
	var tot_con := 0
	var tot_senza := 0
	var tot_visti := 0
	for f in fam:
		var c := int(_ev.get(f + "|con", 0))
		var s := int(_ev.get(f + "|senza", 0))
		var vc := int(_ev_visti.get(f + "|con", 0))
		tot_con += c
		tot_senza += s
		tot_visti += vc
		var ore_con: float = float(_sec["con"]) / 3600.0
		var ore_tot: float = (float(_sec["con"]) + float(_sec["senza"])) / 3600.0
		print("   %-16s %8d %8d | %8d %8.1f | %.1f"
				% [f, c, s, vc, (float(vc) / ore_con) if ore_con > 0 else 0.0,
				(float(c + s) / ore_tot) if ore_tot > 0 else 0.0])
	var ore_con2: float = float(_sec["con"]) / 3600.0
	var ore_sen2: float = float(_sec["senza"]) / 3600.0
	print("   %-16s %8d %8d | %8d" % ["TOTALE", tot_con, tot_senza, tot_visti])
	print("")
	print("   ⇒ IN UN'ORA DI GIOCO (= %d giornate del villaggio)" % int(3600.0 / ciclo))
	print("     ⚠️ i due tassi si tengono SEPARATI: mescolarli darebbe un")
	print("        numero che non descrive nessuna delle due situazioni.")
	if ore_con2 > 0:
		print("     col giocatore in mezzo al villaggio ......... %.0f eventi/h"
				% (float(tot_con) / ore_con2))
		print("     …DI CUI DENTRO L'INQUADRATURA .............. %.0f eventi/h"
				% (float(tot_visti) / ore_con2))
		print("        cioe' uno ogni %.0f secondi di gioco"
				% (3600.0 / maxf(1.0, float(tot_visti) / ore_con2)))
	if ore_sen2 > 0:
		print("     col giocatore a %.0f m da tutto ............. %.0f eventi/h"
				% [LONTANO.length(), float(tot_senza) / ore_sen2])
	print("")
	print("   misurato su %.0f s «con» e %.0f s «senza» (%.2f + %.2f giornate)"
			% [_sec["con"], _sec["senza"], _sec["con"] / ciclo, _sec["senza"] / ciclo])
	print("   fotogrammi medi durante la misura: %.1f/s (una misura fatta a"
			% (_fps_acc / maxf(1.0, float(_fps_n))))
	print("      dieci fotogrammi al secondo non e' la partita di nessuno)")
	print("   ⚠️ i due blocchi NON sono appaiati: appena il comportamento")
	print("      cambia i due villaggi divergono. Si confrontano i TASSI")
	print("      dentro la stessa corsa, mai i totali.")
	if _camera_viva:
		var tot_f := _frustum_si + _frustum_no
		if tot_f > 0:
			print("   il frustum MORDE: %.1f%% dei corpi-campione era fuori quadro"
					% (100.0 * float(_frustum_no) / float(tot_f)))
	else:
		print("   ⚠️ senza camera «visti» = «successi»: e' un TETTO.")
	print("")
	print("   ► PERCHE' UNO ZERO E' ZERO (il silenzio ha molti nomi)")
	var animi: Dictionary = _vis.get("_animi")
	var mm := _conta_marchi(animi)
	if int(_ev.get("evitamento|con", 0)) + int(_ev.get("evitamento|senza", 0)) == 0:
		print("     evitamento: %d marchi su LUOGHI (%d su persone, che NON"
				% [int(mm["luogo"]), int(mm["chi"])])
		print("       producono evitamento). L'UNICA")
		print("       sorgente in partita e' `Visitors.assegna_compito` —")
		print("       cioe' IL GIOCATORE che assegna un lavoro. Nessun evento")
		print("       del mondo marchia un luogo da se'.")
	if int(_ev.get("cricca|con", 0)) + int(_ev.get("cricca|senza", 0)) == 0:
		print("     cricca: ne servono %d GIORNATE DISTINTE alla stessa ora"
				% CRICCHE.GIORNATE_RITROVO)
		print("       nello stesso posto — piu' di quanto duri questa corsa.")
	if int(_ev.get("deduzione|con", 0)) + int(_ev.get("deduzione|senza", 0)) == 0:
		print("     deduzione: `Llm.acceso()` = %s. Senza modello linguistico"
				% Llm.acceso())
		print("       `Deduzioni.incassa()` non ha chiamanti: zero PER")
		print("       COSTRUZIONE, e per la maggioranza di chi gioca.")
	if int(_ev.get("sussulto|con", 0)) == 0:
		print("     sussulto: vuole Mochi entro 3,2 m E il raffreddamento di")
		print("       9 s scaduto E `indizio_grezzo` sopra 0,22 (cioe' un")
		print("       arrivo brusco: sotto 1,6 m/s non si vede niente).")
	print("")
	print("   dettaglio dei gesti per frase:")
	var visto_qualcosa := false
	for k in _ev:
		if str(k).begins_with("gesto:"):
			visto_qualcosa = true
			print("     %s = %d" % [str(k), int(_ev[k])])
	if not visto_qualcosa:
		print("     (nessuno)")
	print("   i NO della regia, per nome (dal contatore di Visitors):")
	var no: Dictionary = _vis.call("debug_gesti_contatori")
	var kk: Array = no.keys()
	kk.sort()
	for k2 in kk:
		print("     %-34s %d" % [str(k2), int(no[k2])])

	print("")
	print("═".repeat(74))
	print("D3 — LE VIE D'USCITA CHE CAPITANO DA SOLE")
	print("═".repeat(74))
	print("   %-24s %8s %8s" % ["via", "CON", "SENZA"])
	print("   %-24s %8d %8d" % ["posto accanto (fronti)",
			int(_uscite.get("posto accanto|con", 0)),
			int(_uscite.get("posto accanto|senza", 0))])
	print("   %-24s %8.1f %8.1f" % ["…secondi-coppia seduti",
			_seduti_accanto_sec["con"], _seduti_accanto_sec["senza"]])
	var pc := 100.0 * float(_accomp_candidati["con"]) / maxf(1.0, float(_accomp_camp["con"]))
	var ps := 100.0 * float(_accomp_candidati["senza"]) / maxf(1.0, float(_accomp_camp["senza"]))
	print("   %-24s %7.1f%% %7.1f%%" % ["accompagnamento (offerto)", pc, ps])
	# la VEGLIA e il PIATTO CALDO: si guarda se ESISTONO le condizioni
	var lav := _trova("lavori")
	var guardia := ""
	if lav != null and lav.has_method("chi_fa"):
		guardia = str(lav.call("chi_fa", "guardia"))
	var guardiole: int = (_build.call("get_placed_by_name", "Guardiola") as Array).size()
	print("   %-24s %s" % ["Veglia: chi fa la guardia",
			guardia if guardia != "" else "NESSUNO"])
	print("   %-24s %d" % ["…Guardiole costruite", guardiole])
	var cucine: int = (_build.call("get_placed_by_name", "Cucina") as Array).size()
	print("   %-24s %d (e i piatti li da' il GIOCATORE: `offer_item`)"
			% ["…Cucine costruite", cucine])
	var animi3: Dictionary = _vis.get("_animi")
	var m3d := _conta_marchi(animi3)
	var m3 := int(m3d["luogo"])
	print("   %-24s %d su luoghi, %d su persone"
			% ["marchi nel villaggio", m3, int(m3d["chi"])])
	_collo_di_bottiglia()
	_geografia_delle_sedute()
	print("   %-24s %s" % ["…e la visita serena",
			"IMPOSSIBILE (nessun marchio)" if m3 == 0
			else "possibile su %d marchi" % m3])
	print("")
	print("   ⚠️ Se una riga e' zero, la ragione sta nella geografia: la")
	print("      Veglia vuole una Guardiola E l'incarico assegnato,")
	print("      l'accompagnamento vuole un marchio su uno dei quattro")
	print("      luoghi localizzabili (catasta · orto · cucina · bosco).")
	print("")


## ⚠️ **IL COLLO DI BOTTIGLIA DEI LUOGHI**, e non e' un'opinione: sono tre
## tabelle del gioco intersecate, lette da dove vivono.
##
## Perche' una paura appresa produca una via d'uscita servono TRE cose sullo
## stesso posto: che qualcosa possa marchiarlo, che l'evitamento cambi un
## comportamento, e che l'accompagnamento sappia dov'e'. Se l'intersezione e'
## vuota, tutta la catena «paura → largo → accompagnamento → estinzione» e'
## codice morto in partita **con la suite verde** — che e' il guasto che
## questo progetto ha gia' pagato tre volte.
func _collo_di_bottiglia() -> void:
	var acc := _trova("accompagna")
	var loc: Array = (acc.call("_localizzabili") as Array) if acc != null else []
	var marcabili: Array = VISITORS.LUOGO_DEL_LAVORO.values()
	var consumati: Array = VISITORS.LUOGO_ATTIVITA.values()
	var tutti: Array = ["catasta", "orto", "cucina", "confine", "bosco"]
	print("")
	print("   ► IL COLLO DI BOTTIGLIA DEI LUOGHI (tre tabelle intersecate)")
	print("     %-9s | marchiabile | l'evitamento | accompagnabile | LA CATENA"
			% "luogo")
	print("     %-9s | (dal lavoro)|  cambia qcs  |  qui e ora     | INTERA"
			% "")
	var interi := 0
	for l in tutti:
		var a: bool = l in marcabili
		var b: bool = l in consumati
		var c: bool = l in loc
		if a and b and c:
			interi += 1
		print("     %-9s |     %-7s |    %-9s |   %-12s | %s"
				% [l, "si" if a else "NO", "si" if b else "NO",
				"si" if c else "NO", "SI'" if (a and b and c) else "—"])
	print("     ⇒ luoghi su cui la catena intera si chiude, in QUESTO")
	print("       villaggio: %d su %d" % [interi, tutti.size()])
	if interi == 0:
		print("     ⚠️ ZERO: la paura appresa non ha NESSUNA strada completa.")
	print("     (`LUOGO_DEL_LAVORO` e `LUOGO_ATTIVITA` sono di `Visitors`;")
	print("      i localizzabili li dice `Accompagna._localizzabili()`, che")
	print("      guarda i PEZZI COSTRUITI: Orto/Aiuola, Camino, gli alberi.)")


## LA GEOGRAFIA DELL'INVITO, che non dipende dal tempo. Se nessuna seduta ha
## una sorella entro `VICINI`, «il posto accanto» non e' una via d'uscita
## rara: e' una via d'uscita IMPOSSIBILE, e il numero che la misura non
## direbbe niente sul meccanismo — direbbe che il villaggio non ha il mobile.
func _geografia_delle_sedute() -> void:
	var posti: Array = []
	for nome in ["Panchina", "Gazebo", "Serra", "Gradinata"]:
		for pn in (_build.call("get_placed_by_name", nome) as Array):
			var n3 := pn as Node3D
			if n3 == null:
				continue
			var anc := n3.find_children("Posto*", "Node3D", true, false)
			if anc.is_empty():
				posti.append(n3)
			else:
				for a in anc:
					posti.append(a as Node3D)
	var coppie := 0
	var con_due := 0
	var accoppiate := 0
	for x in posti.size():
		var q := 0
		for y in posti.size():
			if x == y:
				continue
			if (posti[x] as Node3D).global_position.distance_to(
					(posti[y] as Node3D).global_position) <= VISITORS.VICINI:
				q += 1
				if y > x:
					coppie += 1
		if q >= 1:
			accoppiate += 1
		if q >= 2:
			con_due += 1
	print("   %-24s %d" % ["sedute nel villaggio", posti.size()])
	print("   %-24s %d (%d hanno una sorella, %d ne hanno due)"
			% ["…coppie entro %.1f m" % VISITORS.VICINI, coppie, accoppiate, con_due])
	if coppie == 0:
		print("   ⚠️ NESSUNA SEDUTA HA UNA SORELLA ACCANTO: «il posto accanto»")
		print("      non e' raro, e' IMPOSSIBILE. Serve un mobile a piu'")
		print("      sedute (Gazebo, Gradinata) o due panchine vicine.")


func _gradino_max(animi: Dictionary) -> int:
	var m := 0
	for l in animi:
		m = maxi(m, int((animi[l] as RefCounted).gradino))
	return m


## I marchi si contano SEPARATI, e non e' pignoleria: `_marchia` scrive due
## famiglie di chiavi — `luogo|X` e `chi|X` — e SOLO la prima produce
## l'evitamento (`_filtra_luogo` chiede `evita(luogo)`). Contati insieme
## fanno sembrare che il villaggio abbia quaranta paure apprese quando ne ha
## ZERO sui posti: e' la differenza fra «il canale e' vivo» e «e' morto».
func _conta_marchi(animi: Dictionary) -> Dictionary:
	var l := 0
	var c := 0
	for k in animi:
		for chiave in ((animi[k] as RefCounted).limbico.marchi as Dictionary):
			if str(chiave).begins_with("luogo|"):
				l += 1
			else:
				c += 1
	return {"luogo": l, "chi": c}
