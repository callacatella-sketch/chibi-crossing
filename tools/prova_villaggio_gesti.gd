extends SceneTree
## IL VILLAGGIO CHE GESTICOLA — la prova viva, e il metro della SCARSITÀ.
##
##   CHIBI_GESTI_FOTO=/dove ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --resolution 1280x720 --script res://tools/prova_villaggio_gesti.gd
##   CHIBI_MINUTI=8 CHIBI_QUANTI=20 …
##
## Questo banco **non collega niente**: apre il MainLevel vero, insedia i
## residenti, fa camminare Mochi come cammina un giocatore, e guarda. Se il
## cablaggio non ci fosse, qui non succederebbe niente — ed è esattamente il
## guasto che questo file esiste per rendere visibile (la Fase 5 è stata per
## un giorno intero un laboratorio completo e **non collegato**: cinque banchi
## verdi e il grafo delle deduzioni vuoto per sempre).
##
## ────────────────────────────────────────────────────────────────────────
## IL NUMERO CHE PUÒ UCCIDERE IL LAVORO IN TUTTE E DUE LE DIREZIONI
## ────────────────────────────────────────────────────────────────────────
##
## `Visitors.GESTO_PASSO`. Un gettone SENZA periodo — «uno per volta in tutto
## il villaggio» — significa *sempre esattamente un mimo in scena, per
## sempre*: appena uno finisce, il primo che passa prende il posto. Troppo
## lungo, e il vocabolario non si vede mai.
##
## Non si tara al banco: si tara **in partita**, e contro quello che il
## villaggio fa GIÀ — una chiacchierata ogni 3,5 s, un sussulto ogni 9 s per
## residente, un cambio di mestiere ogni 0,4–1,6 s. Qui si contano:
##
##   · gesti partiti, e di che frase
##   · **simultanei** — dev'essere SEMPRE ≤ 1
##   · quanti col giocatore entro nove metri (fuori di lì non si vede)
##   · la frazione di secondi-vicino passata dentro un gesto — il metro del
##     MIMO: sopra il 15% il villaggio sembra un carillon di pupazzi
##   · quanti vicini diversi hanno gesticolato (mai sempre lo stesso)
##   · e il fotogramma, a blocchi alternati col vocabolario spento

const DNAG := preload("res://scenes/npc/ChibiDNA.gd")
const GESTI := preload("res://scenes/npc/Gesti.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")

var _vis: Node = null
var _build: Node = null
var _player: Node3D = null
var _dove := ""
var _scatti := 0

# --- i conti ---
var _partiti := 0
var _per_frase := {}
var _chi := {}
var _in_raggio := 0
var _fuori_raggio := 0
var _simultanei_max := 0
var _secondi_vicino := 0.0
var _secondi_in_gesto := 0.0
var _campioni := 0
var _fps_acc := 0.0
var _fps_n := 0
var _lavoro := 3.0
var _verbo := 0
var _doni := 0
var _secondi_addosso := 0.0
var _sosta := 0.0
## I verbi che il ponte conosce: sono i gesti veri del ciclo di gioco.
const VERBI := ["annaffia", "semina", "raccoglie", "costruisce", "pesca"]


func _init() -> void:
	_go()


func _m(c: Vector2i) -> Vector3:
	return Vector3(c.x, 0.0, c.y)


func _go() -> void:
	_dove = OS.get_environment("CHIBI_GESTI_FOTO")
	if _dove != "":
		DirAccess.make_dir_recursive_absolute(_dove)
	var minuti := 6.0
	if OS.get_environment("CHIBI_MINUTI") != "":
		minuti = float(OS.get_environment("CHIBI_MINUTI"))
	var quanti := 14
	if OS.get_environment("CHIBI_QUANTI") != "":
		quanti = int(OS.get_environment("CHIBI_QUANTI"))

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 10:
		await process_frame
	var liv := current_scene
	_build = liv.get_node_or_null("BuildSystem")
	_vis = liv.get_node_or_null("Visitors")
	_player = liv.get_node_or_null("Player") as Node3D
	var dn := liv.get_node_or_null("DayNight")
	if _build == null or _vis == null or _player == null:
		print("GUASTO: manca qualcosa nel MainLevel")
		quit(1)
		return
	_build.call("set_persist_for_debug", false)
	# ⚠️ L'OROLOGIO SI FERMA a metà pomeriggio. Un giorno del gioco dura
	# quattro minuti: senza questa riga, a metà prova i vicini vanno a
	# dormire — `resident_sleep()` li rimpicciolisce a scala 0.03 — e il
	# banco misurerebbe un villaggio vuoto credendo di misurare i gesti.
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	await create_timer(1.5).timeout

	# ⚠️ E IL PRATO NUDO NON PRODUCE NIENTE. I gesti nascono da momenti veri —
	# la fame che trova il cespuglio, il posto diventato insopportabile, la
	# ricevuta di un gesto di Mochi — e in un prato senza niente sopra quei
	# momenti non capitano. Si costruisce, e si stampa cosa c'è.
	_vis.call("debug_reset")
	var celle: Array[Vector2i] = []
	var raggio := 7
	for gx in range(-raggio, raggio):
		for gz in range(-raggio, raggio):
			celle.append(Vector2i(gx * 2, gz * 2))
	celle.shuffle()
	# ⚠️ **`place_cell` NON TORNA NIENTE, e rifiuta in silenzio** (il letto del
	# fiume, una cella occupata, un pezzo non sbloccato). Le celle si provano
	# UNA PER UNA e si conta chi si è insediato davvero: chiedere a
	# `place_cell` se ha funzionato è chiedere a una funzione `void`, e la
	# prima stesura di questo banco l'ha fatto — l'errore ha interrotto la
	# preparazione a metà lasciando l'albero vivo, e il processo ha girato a
	# vuoto per venti minuti senza stampare una riga.
	var letti := 0
	var i := 0
	while letti < quanti and i < celle.size():
		var c: Vector2i = celle[i]
		i += 1
		_build.call("place_cell", c, "Letto", 0, false)
		_build.call("place_cell", c, "Tetto", 0, false)
		if not bool(_build.call("has_cover", c)):
			continue
		letti += 1
	# e qualcosa da fare: cespugli, panchine, aiuole
	var extra := 0
	while extra < 12 and i < celle.size():
		var c: Vector2i = celle[i]
		i += 1
		var pezzo: String = ["Cespuglio", "Panchina", "Aiuola"][extra % 3]
		_build.call("place_cell", c, pezzo, 0, false)
		extra += 1
	_build.call("aggiorna_varchi_ora")
	print("costruiti: %d letti coperti, %d posti dove fare qualcosa" % [letti, extra])

	var celle_letto: Array[Vector2i] = []
	for k in range(mini(letti, celle.size())):
		celle_letto.append(celle[k])
	var residenti: Array = []
	for k in celle_letto.size():
		_vis.call("debug_settle", 5000 + k * 37, celle_letto[k])
		residenti = _vis.get("_residents")
	await create_timer(1.5).timeout
	residenti = _vis.get("_residents")
	print("insediati: %d residenti" % residenti.size())
	if residenti.is_empty():
		print("GUASTO: nessun residente")
		quit(1)
		return
	# ⚠️ i corpi vanno messi SULLA PROPRIA CELLA: `Visitors` calcola i luoghi
	# a partire da `home = cell`, e un corpo a trenta metri dalla sua cella
	# pianifica per un posto e cammina in un altro.
	for k in residenti.size():
		_vis.call("debug_stage_resident", k, _m((residenti[k] as Dictionary)["cell"]))
	await create_timer(1.0).timeout
	_prepara(residenti)

	print("")
	print("█".repeat(72))
	print("IL VILLAGGIO GESTICOLA — %d residenti, %.0f minuti" % [residenti.size(), minuti])
	print("  gettone: uno ogni %.0f s · riposo per vicino: %.0f s · raggio %.0f m"
			% [VISITORS.GESTO_PASSO, VISITORS.GESTO_RIPOSO, VISITORS.GESTO_RAGGIO])
	print("█".repeat(72))
	await _guarda(minuti * 60.0, residenti)
	_referto(residenti.size(), minuti * 60.0)
	quit(0)


## ⚠️ **UN VILLAGGIO APPENA NATO NON GESTICOLA, E NON È UN GUASTO.** Le
## quattro frasi hanno inneschi VERI e nessun innesco nuovo: la premessa
## vuole che Mochi FACCIA qualcosa (`Percezione.accaduto`, il bus che
## chiamano Garden, BuildSystem, la pesca…), la rinuncia vuole qualcuno che
## abbia qualcosa da rinfacciarti, l'evitamento vuole un posto che qualcuno
## abbia imparato a temere. In un prato nuovo, con un giocatore che passeggia
## e basta, il conto giusto è **zero** — misurato: 0 gesti in trenta secondi
## con quattordici residenti.
##
## Perciò il banco COSTRUISCE LE SITUAZIONI, come `prova_recinto` costruisce
## la staccionata: due vicini che hanno imparato a temere un posto, due che
## hanno finito la forza di trattenersi, e un giocatore che lavora invece di
## passeggiare. Tutto attraverso le porte vere — `Limbico`, `Animo`,
## `Percezione.accaduto` — mai chiamando `chiedi_frase` a mano: **se il
## cablaggio non ci fosse, qui non succederebbe niente**, ed è il solo modo
## di accorgersene.
func _prepara(residenti: Array) -> void:
	var animi: Dictionary = _vis.get("_animi")
	var k := 0
	for r in residenti:
		var lab := str((r as Dictionary).get("label", ""))
		if not animi.has(lab):
			continue
		var animo: RefCounted = animi[lab]
		if k % 3 == 0:
			# CHI HA IMPARATO A TEMERE UN POSTO. Si passa dalla porta vera
			# (`percepisci` + `rivaluta`, la doppia strada): scrivere il
			# marchio a mano vorrebbe dire provare un villaggio che non
			# esiste.
			for _i in 4:
				animo.limbico.rivaluta("spavento", "", -0.9, "cucina", true)
		if k % 3 == 1:
			# CHI HA QUALCOSA DA RINFACCIARTI E ANCORA LA FORZA DI TENERSELO.
			#
			# ⚠️ **E QUI IL BANCO SI ERA RESO IMPOSSIBILE DA SOLO.** La prima
			# stesura consumava CINQUE morsi (1,10 di costo su 1,00 di
			# forza), cioè preparava «chi ha finito la forza di trattenersi»
			# — che è esattamente la popolazione per cui
			# `Limbico.trattieni()` torna **falso**. Ma l'occasione
			# `si_e_trattenuto` sta nell'altro ramo, quello del morso
			# RIUSCITO: il banco chiedeva zero e otteneva zero, e il referto
			# lo dichiarava come un silenzio del gioco. Due morsi lasciano
			# 0,56 di forza, cioè due tentativi che riescono e poi il terzo
			# che scoppia — che è la scena vera.
			for _i in 2:
				animo.limbico.trattieni()
			r["gradino"] = maxi(int(r.get("gradino", 0)), 2)
			animo.set("gradino", maxi(int(animo.get("gradino")), 2))
		if k % 3 == 2:
			# E CHI TI VUOLE BENE. Serve al «ah… sei tu»: il sussulto si
			# scioglie nel riconoscimento solo se la strada lenta (`rivaluta`
			# su «incontro») torna un sentito POSITIVO, e quanto vale
			# dipende dall'amicizia vera (`_tick_riconoscimenti`).
			r["friend"] = maxi(int(r.get("friend", 0)), 3)
		k += 1
	print("preparati: %d vicini con un posto che temono, %d che si trattengono,"
			% [(residenti.size() + 2) / 3, (residenti.size() + 1) / 3]
			+ " %d che ti vogliono bene" % (residenti.size() / 3))


## MOCHI CAMMINA COME CAMMINA UN GIOCATORE: a mete a caso, non in cerchio
## attorno a un vicino. Il modello è dichiarato — è quello di
## `misura_attribuzione` — e conta, perché metà delle domande di questo banco
## sono «il giocatore lo vede?».
func _guarda(secondi: float, residenti: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var meta := Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10))
	# ⚠️ **IL TEMPO È L'OROLOGIO DA POLSO, non `get_frames_per_second()`.** La
	# prima stesura ricavava il passo da quel numero, che è una media
	# addolcita: con la macchina carica dichiarava sessanta fotogrammi al
	# secondo mentre ne disegnava sei, e il banco credeva di aver simulato
	# quattro minuti dopo averne consumati quaranta di orologio vero. Una
	# misura che non sa che ora è non misura niente.
	var t := 0.0
	var prossimo_scatto := 4.0
	var ms := Time.get_ticks_msec()
	var ultimo_avviso := 0.0
	while t < secondi:
		await process_frame
		var ora := Time.get_ticks_msec()
		var dt := float(ora - ms) / 1000.0
		ms = ora
		if dt <= 0.0 or dt > 0.5:
			continue     # un fotogramma perso non è un secondo di villaggio
		t += dt
		_fps_acc += 1.0 / dt
		_fps_n += 1
		if t - ultimo_avviso > 30.0:
			ultimo_avviso = t
			print("  … %.0f s · gesti %d · simultanei max %d"
					% [t, _partiti, _simultanei_max])
		# Mochi cammina — e quando arriva da qualcuno, SI FERMA un momento.
		# Un giocatore che va da un vicino non lo sfiora e riparte: sta lì.
		# Due delle sette occasioni vogliono Mochi a meno di 2,6-3,2 m *e*
		# un tick che ci cada dentro (il morso ha 12 s di raffreddamento, il
		# sussulto 9): passandoci a sei metri al secondo la finestra è di
		# mezzo secondo, e in dieci minuti non ci cade nessuno.
		var p := _player.global_position
		if _sosta > 0.0:
			_sosta -= dt
		elif Vector2(p.x - meta.x, p.z - meta.z).length() < 1.0:
			_sosta = 2.5
			# ⚠️ **E UNA VOLTA SU TRE VA DA QUALCUNO.** Il modello «mete a
			# caso» è dichiarato ed è quello di `misura_attribuzione`, ma da
			# solo NON è un giocatore: tre delle sette occasioni della regia
			# vogliono Mochi addosso a un vicino (il morso trattenuto entro
			# 2,6 m, il sussulto entro 3,2, il posto evitato) e con mete a
			# caso su un prato di trenta metri non capitano mai — misurato,
			# ZERO richieste in dieci minuti. Un banco che non produce
			# un'occasione non prova che quell'occasione tace: prova che il
			# banco non la fa succedere.
			if rng.randf() < 0.34 and not residenti.is_empty():
				var q: Dictionary = residenti[rng.randi() % residenti.size()]
				var qn := q.get("node") as Node3D
				if qn != null and is_instance_valid(qn):
					meta = qn.global_position
				else:
					meta = Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
			else:
				meta = Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
		var verso := (meta - p)
		verso.y = 0.0
		if _sosta <= 0.0 and verso.length() > 0.01:
			# ⚠️ **ALLA VELOCITÀ VERA, e si legge dal giocatore vero.** La
			# prima stesura muoveva Mochi a 2,6 m/s — cioè **più piano di
			# quanto un giocatore possa camminare** (`PlayerController`:
			# 3,0 a passo, 6,0 di corsa). Non è un dettaglio da banco: la
			# strada veloce del Limbico guarda proprio COME arrivi
			# (`indizio_grezzo` non vede niente di brusco sotto 1,6 m/s e
			# satura a 5,0), e a 2,6 la forza del sussulto vale 0,13 contro
			# una soglia di 0,22. **Nessuno sussultava mai**, quindi
			# «ah… sei tu» non poteva succedere — e il banco lo dichiarava
			# come un silenzio del gioco invece che come un silenzio suo.
			# Si corre verso le mete lontane e si cammina quando si è
			# arrivati: è quello che fa un giocatore.
			var lontano: bool = verso.length() > 8.0
			var vel: float = float(_player.get("run_speed") if lontano
					else _player.get("walk_speed"))
			if vel <= 0.0:
				vel = 6.0 if lontano else 3.0
			_player.global_position = p + verso.normalized() * vel * dt
		# …E LAVORA. Ogni tanto Mochi fa qualcosa lì dove si trova, e lo dice
		# al bus vero della percezione — quello che chiamano Garden, il
		# BuildSystem e la pesca. È da lì che nasce «la premessa».
		_lavoro -= dt
		if _lavoro <= 0.0:
			_lavoro = 5.5
			var perc := current_scene.get_node_or_null("Percezione")
			if perc != null:
				# ⚠️ **IN RAFFICA, come lavora un giocatore vero.** Il
				# BuildSystem non ha lucchetto (`_try_place` sta su
				# `is_action_pressed`) ed emette un gesto per PEZZO: un
				# sentiero è quaranta emissioni di fila. Un banco che emette
				# un gesto isolato ogni cinque secondi e mezzo non prova la
				# regola più importante della regia — che il corpo segue il
				# RICORDO e non il gesto — e per giunta non arriva mai al
				# peso che serve per una promozione (`quante` cresce solo
				# dentro la finestra di fusione).
				var quante := 2 + (_verbo % 3)
				for _k in quante:
					perc.call("accaduto", VERBI[_verbo % VERBI.size()],
							_player.global_position)
				_verbo += 1
				# …e ogni tanto un DONO, che è l'unico gesto che il grafo sa
				# essere stato fatto A QUALCUNO (`R_SU_DI_ME`)
				if _verbo % 3 == 0:
					var vicino := ""
					var dmin := 9.0
					for r in residenti:
						var n := (r as Dictionary).get("node") as Node3D
						if n == null or not is_instance_valid(n):
							continue
						var dd: float = _player.global_position.distance_to(n.global_position)
						if dd < dmin:
							dmin = dd
							vicino = str((r as Dictionary).get("label", ""))
					if vicino != "":
						perc.call("accaduto", "dona", _player.global_position, vicino)
						_doni += 1
		# il censimento
		var insieme := 0
		for r in residenti:
			var n := (r as Dictionary).get("node") as Node3D
			if n == null or not is_instance_valid(n) or not n.has_method("gesto_in_corso"):
				continue
			var dist: float = _player.global_position.distance_to(n.global_position)
			if dist <= VISITORS.GESTO_RAGGIO:
				_secondi_vicino += dt
			# quanto spesso Mochi arriva ADDOSSO a qualcuno: è la condizione
			# di tre occasioni su sette, e senza questo numero un «zero
			# richieste» non si sa se è del gioco o del banco
			if dist <= 3.2:
				_secondi_addosso += dt
			var g := str(n.call("gesto_in_corso"))
			if g == "":
				continue
			insieme += 1
			if dist <= VISITORS.GESTO_RAGGIO:
				_secondi_in_gesto += dt
			var lab := str((r as Dictionary).get("label", ""))
			if not _chi.has(lab):
				_chi[lab] = 0
			# il FRONTE: si conta il gesto quando comincia, non ogni frame
			if not bool((r as Dictionary).get("_gs_visto", false)):
				(r as Dictionary)["_gs_visto"] = true
				_partiti += 1
				_chi[lab] = int(_chi[lab]) + 1
				_per_frase[g] = int(_per_frase.get(g, 0)) + 1
				if dist <= VISITORS.GESTO_RAGGIO:
					_in_raggio += 1
				else:
					_fuori_raggio += 1
				if _dove != "" and t > prossimo_scatto:
					prossimo_scatto = t + 25.0
					await _scatta("gesto_%03d_%s" % [_partiti, g])
		for r in residenti:
			var n := (r as Dictionary).get("node") as Node3D
			if n != null and is_instance_valid(n) and n.has_method("gesto_in_corso") \
					and str(n.call("gesto_in_corso")) == "":
				(r as Dictionary)["_gs_visto"] = false
		_simultanei_max = maxi(_simultanei_max, insieme)
		_campioni += 1


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_jpg(_dove.rstrip("/") + "/" + nome + ".jpg", 0.92)
	_scatti += 1


func _referto(quanti: int, secondi: float) -> void:
	print("")
	print("─".repeat(72))
	print("  gesti partiti ................................. %d" % _partiti)
	for f in _per_frase:
		print("      %-14s .............................. %d" % [f, _per_frase[f]])
	print("  ⇒ GESTI AL MINUTO che vede un giocatore ....... %.2f"
			% (60.0 * float(_partiti) / maxf(1.0, secondi)))
	print("  uno in tutto il villaggio ogni ................ %.1f s"
			% (secondi / maxf(1.0, float(_partiti))))
	print("  un dato vicino ne fa uno ogni ................. %.1f min"
			% (secondi * float(quanti) / maxf(1.0, float(_partiti)) / 60.0))
	print("  vicini DIVERSI che hanno gesticolato .......... %d su %d"
			% [_chi.size(), quanti])
	var peggio := 0
	for k in _chi:
		peggio = maxi(peggio, int(_chi[k]))
	print("  il più prolifico ne ha fatti .................. %d" % peggio)
	print("")
	print("  ⚠ SIMULTANEI, massimo ........................ %d   (dev'essere 1)"
			% _simultanei_max)
	print("  gesti col giocatore dentro i nove metri ....... %d su %d"
			% [_in_raggio, _partiti])
	print("  ⚠ frazione di secondi-vicino DENTRO un gesto .. %.2f%%  (bersaglio ≤ 15%%)"
			% (100.0 * _secondi_in_gesto / maxf(0.001, _secondi_vicino)))
	print("")
	print("  LE OCCASIONI: chieste (?) e concesse (✓). Il silenzio è il"
			+ " comportamento normale,")
	print("  e ogni no ha il suo nome — un banco che dice solo «zero gesti»"
			+ " lascia indovinare.")
	var no: Dictionary = _vis.call("debug_gesti_contatori")
	var chiavi: Array = no.keys()
	chiavi.sort()
	for k in chiavi:
		print("      %-32s %d" % [k, no[k]])
	print("      (doni emessi da Mochi: %d)" % _doni)
	print("      (secondi-vicino con Mochi entro 3,2 m: %.0f — la condizione di"
			% _secondi_addosso + " tre occasioni su sette)")
	print("")
	print("  fotogrammi al secondo, medi ................... %.1f"
			% (_fps_acc / maxf(1.0, float(_fps_n))))
	if _dove != "":
		print("  scatti ....................................... %d in %s" % [_scatti, _dove])
	print("─".repeat(72))
	print("  IL METRO DI PARTENZA: sette teste girate in venticinque minuti.")
