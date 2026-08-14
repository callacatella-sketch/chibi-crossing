extends SceneTree
## IL METRO DEL CAPO — quante teste sono inclinate INSIEME, e per quanto.
##
##   CHIBI_MINUTI=5 CHIBI_QUANTI=12 ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --resolution 1280x720 --script res://tools/misura_capi.gd
##
## `Visitors.CAPO_MAX` dice che in tutto il villaggio non si vedono più di
## DUE teste inclinate insieme: tre sono una posa di gruppo, non tre
## pensieri. È una regola sul MONDO, e finora era sorvegliata da un
## contatore — `_gesto_capi`, il registro — che il mondo non era obbligato a
## rispecchiare. Questo banco non chiede al registro: **conta le teste**.
##
## ⚠️ **L'ORACOLO È INDIPENDENTE DAL REGISTRO, e deve restarlo.** Chiedere a
## `_gesto_capi.size()` quante teste pendono è chiedere al giudice se è
## d'accordo con sé stesso — è l'errore che `tools/misura_cammino.gd` esiste
## per non commettere. Qui si scandaglia il gruppo «passanti» (ogni corpo
## che sta nel mondo, residenti e non) e si legge il rig:
##
##   · `_gs_capo`   — il livello è ACCESO su quel corpo
##   · `_gs_capo_x` — di quanto è inclinata la testa ADESSO, in radianti
##
## Sono due domande diverse e servono tutte e due: la prima dice quante ne
## ha accese il gioco, la seconda quante se ne VEDONO (la molla rientra da
## sé, quindi una testa spenta un istante fa è ancora storta).
##
## TRE ATTI, e ognuno risponde a una domanda che nessuna asserzione booleana
## sa dare:
##
##   I   il villaggio    quante teste insieme, in partita, sotto pressione
##   II  l'estetista     una testa storta sopravvive a uno spegnimento secco?
##   III il tetto        con cinque che ci pensano e una frase sopra, quante?
##
## Il banco è GENEROSO apposta: le occasioni si producono più spesso che in
## una partita vera, perché un tetto si prova sotto pressione — a villaggio
## addormentato qualunque tetto tiene.

const DNAG := preload("res://scenes/npc/ChibiDNA.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")

## Sopra questo scarto la testa è inclinata in modo VISIBILE. Il rollio vive
## fra 0,08 e 0,11 rad (4,6°–6,3°): due centesimi di radiante sono 1,1°, cioè
## il primo gradino sopra il quale non è più «dritta».
const VISIBILE := 0.02

var _vis: Node = null
var _build: Node = null
var _player: Node3D = null

# --- i conti dell'atto I ---
var _max_accesi := 0
var _max_visibili := 0
var _isto_accesi := {}
var _isto_visibili := {}
var _sec_oltre := 0.0
var _sec_tot := 0.0
var _campioni := 0
var _max_divergenza := 0
var _max_terzo := 0.0
var _terzo_acc := 0.0
var _terzo_n := 0
var _divergenze := 0
var _frasi_chieste := 0
var _frasi_concesse := 0


func _init() -> void:
	_go()


func _m(c: Vector2i) -> Vector3:
	return Vector3(c.x, 0.0, c.y)


## TUTTI I CORPI DEL MONDO, non i residenti: un vicino che se ne sta andando
## col fagotto è ancora un corpo che il giocatore vede.
func _corpi() -> Array:
	var out: Array = []
	for n in get_nodes_in_group("passanti"):
		if n is Node3D and is_instance_valid(n) and (n as Node).get("_gs_capo") != null:
			out.append(n)
	return out


func _teste() -> Array:
	# [accesi, visibili, il TERZO scarto in ordine di grandezza]
	#
	# ⚠️ Il terzo non è un ornamento: quando una testa in più compare, la
	# domanda che conta è **di quanto** pende. Il rollio pieno vive fra 4,6°
	# e 6,3°; la molla che rientra ci passa in mezzo scendendo. Contare le
	# teste sopra una soglia dice QUANTE, non se si vedono.
	var a := 0
	var v := 0
	var scarti: Array[float] = []
	for n in _corpi():
		if bool(n.get("_gs_capo")):
			a += 1
		var x := absf(float(n.get("_gs_capo_x")))
		if x >= VISIBILE:
			v += 1
		scarti.append(x)
	scarti.sort()
	scarti.reverse()
	var terzo: float = scarti[2] if scarti.size() > 2 else 0.0
	return [a, v, terzo]


func _registro() -> int:
	var d = _vis.get("_gesto_capi")
	if d == null:
		return -1
	return (d as Dictionary).size()


func _go() -> void:
	var minuti := 5.0
	if OS.get_environment("CHIBI_MINUTI") != "":
		minuti = float(OS.get_environment("CHIBI_MINUTI"))
	var quanti := 12
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
	# l'orologio si ferma a metà pomeriggio: un giorno dura quattro minuti, e
	# chi dorme non pende il capo (è una delle tre valvole)
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	await create_timer(1.5).timeout

	_vis.call("debug_reset")
	var celle: Array[Vector2i] = []
	for gx in range(-7, 7):
		for gz in range(-7, 7):
			celle.append(Vector2i(gx * 2, gz * 2))
	celle.shuffle()
	var letti := 0
	var i := 0
	var celle_letto: Array[Vector2i] = []
	while letti < quanti and i < celle.size():
		var c: Vector2i = celle[i]
		i += 1
		_build.call("place_cell", c, "Letto", 0, false)
		_build.call("place_cell", c, "Tetto", 0, false)
		if not bool(_build.call("has_cover", c)):
			continue
		celle_letto.append(c)
		letti += 1
	var extra := 0
	while extra < 10 and i < celle.size():
		var c: Vector2i = celle[i]
		i += 1
		_build.call("place_cell", c, ["Cespuglio", "Panchina", "Aiuola"][extra % 3], 0, false)
		extra += 1
	_build.call("aggiorna_varchi_ora")
	for k in celle_letto.size():
		_vis.call("debug_settle", 5000 + k * 37, celle_letto[k])
	await create_timer(1.5).timeout
	var residenti: Array = _vis.get("_residents")
	print("insediati: %d residenti su %d letti" % [residenti.size(), letti])
	if residenti.size() < 4:
		print("GUASTO: servono almeno quattro residenti")
		quit(1)
		return
	for k in residenti.size():
		_vis.call("debug_stage_resident", k, _m((residenti[k] as Dictionary)["cell"]))
	await create_timer(1.0).timeout

	# CHI CI PENSA. Si passa dalla porta vera — `Limbico.trattieni()`, che è
	# il morso che consuma la forza di trattenersi — e non scrivendo
	# `regolazione` a mano: la causa dev'essere quella del gioco, o il banco
	# misura un villaggio che non esiste.
	var animi: Dictionary = _vis.get("_animi")
	var pensosi := 0
	for k in residenti.size():
		if k % 2 == 1:
			continue
		var lab := str((residenti[k] as Dictionary).get("label", ""))
		if not animi.has(lab):
			continue
		for _j in 6:
			(animi[lab] as RefCounted).limbico.trattieni()
		pensosi += 1
	print("preparati: %d vicini che hanno finito la forza di trattenersi" % pensosi)
	print("  (soglia del capo: regolazione < %.2f)" % 0.45)

	print("")
	print("█".repeat(72))
	print("ATTO I — IL VILLAGGIO: %d residenti, %.0f minuti" % [residenti.size(), minuti])
	print("  il tetto dichiarato è CAPO_MAX = %d" % VISITORS.CAPO_MAX)
	print("█".repeat(72))
	await _atto_uno(minuti * 60.0, residenti)
	_referto_uno(minuti * 60.0)

	print("")
	print("█".repeat(72))
	print("ATTO II — L'ESTETISTA: lo spegnimento SECCO sotto una frase")
	print("█".repeat(72))
	await _atto_due(residenti)

	print("")
	print("█".repeat(72))
	print("ATTO III — IL TETTO sotto pressione")
	print("█".repeat(72))
	await _atto_tre(residenti)
	quit(0)


# =========================================================================
# ATTO I — il villaggio
# =========================================================================

func _atto_uno(secondi: float, residenti: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260814
	var meta := Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8))
	var bersaglio := 0
	var t := 0.0
	var ms := Time.get_ticks_msec()
	var prossima := 2.0
	var avviso := 0.0
	while t < secondi:
		await process_frame
		var ora := Time.get_ticks_msec()
		var dt := float(ora - ms) / 1000.0
		ms = ora
		if dt <= 0.0 or dt > 0.5:
			continue
		t += dt
		_sec_tot += dt
		_campioni += 1
		var q := _teste()
		var a: int = q[0]
		var v: int = q[1]
		_max_accesi = maxi(_max_accesi, a)
		_max_visibili = maxi(_max_visibili, v)
		_isto_accesi[a] = int(_isto_accesi.get(a, 0)) + 1
		_isto_visibili[v] = int(_isto_visibili.get(v, 0)) + 1
		_max_terzo = maxf(_max_terzo, float(q[2]))
		if float(q[2]) >= VISIBILE:
			_terzo_acc += float(q[2])
			_terzo_n += 1
		if v > VISITORS.CAPO_MAX:
			_sec_oltre += dt
		var reg := _registro()
		if reg >= 0 and reg != a:
			_divergenze += 1
			_max_divergenza = maxi(_max_divergenza, absi(reg - a))
		# IL GIOCATORE CAMMINA, e ogni tanto va da qualcuno: due delle
		# valvole dell'usciere (raggio e inquadratura) vogliono Mochi
		# addosso, e con mete a caso su un prato di trenta metri non
		# capitano mai.
		var p := _player.global_position
		if Vector2(p.x - meta.x, p.z - meta.z).length() < 1.2:
			bersaglio = rng.randi() % residenti.size()
			var qn := (residenti[bersaglio] as Dictionary).get("node") as Node3D
			meta = qn.global_position if qn != null and is_instance_valid(qn) \
					else Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
		var verso := meta - p
		verso.y = 0.0
		if verso.length() > 0.05:
			_player.global_position = p + verso.normalized() \
					* minf(3.0 * dt, verso.length())
		# e bussa all'usciere per una frase del pensiero: l'innesco vero è
		# la ricevuta di una deduzione (Fase 5, che vuole il modello), ma la
		# PORTA è questa — la stessa che bussa il gioco.
		prossima -= dt
		if prossima <= 0.0:
			prossima = 2.0
			var lab := str((residenti[bersaglio] as Dictionary).get("label", ""))
			_frasi_chieste += 1
			if bool(_vis.call("chiedi_gesto", lab, "ha_dedotto")):
				_frasi_concesse += 1
		if t - avviso > 60.0:
			avviso = t
			print("  … %.0f s · teste accese max %d · visibili max %d · frasi %d"
					% [t, _max_accesi, _max_visibili, _frasi_concesse])


func _referto_uno(secondi: float) -> void:
	print("")
	print("  frasi del pensiero: %d chieste, %d concesse" % [_frasi_chieste, _frasi_concesse])
	print("  teste ACCESE   — massimo insieme: %d   (tetto %d)"
			% [_max_accesi, VISITORS.CAPO_MAX])
	print("  teste VISIBILI — massimo insieme: %d" % _max_visibili)
	var chiavi := _isto_visibili.keys()
	chiavi.sort()
	for k in chiavi:
		print("      %d teste storte: %5.1f%% del tempo"
				% [k, 100.0 * float(_isto_visibili[k]) / float(maxi(_campioni, 1))])
	print("  la TERZA testa più inclinata: massimo %.4f rad (%.1f°)"
			% [_max_terzo, rad_to_deg(_max_terzo)])
	if _terzo_n > 0:
		print("      …e quando c'è, in media %.1f° (su %d fotogrammi)"
				% [rad_to_deg(_terzo_acc / float(_terzo_n)), _terzo_n])
	print("  tempo con PIÙ di %d teste storte: %.1f s su %.0f (%.1f%%)"
			% [VISITORS.CAPO_MAX, _sec_oltre, _sec_tot,
					100.0 * _sec_oltre / maxf(_sec_tot, 0.001)])
	if _registro() < 0:
		print("  registro `_gesto_capi`: NON ESISTE PIÙ (il conto è derivato dal mondo)")
	else:
		print("  registro contro mondo: %d fotogrammi divergenti (scarto max %d)"
				% [_divergenze, _max_divergenza])
	# e il referto dei NO dell'usciere: senza, «zero frasi» sembra un
	# silenzio del gioco quando è un silenzio del banco
	var no: Dictionary = _vis.call("debug_gesti_contatori")
	var righe := no.keys()
	righe.sort()
	print("  l'usciere:")
	for k in righe:
		print("      %-28s %d" % [str(k), int(no[k])])


# =========================================================================
# ATTO II — l'estetista, cioè lo spegnimento SECCO
# =========================================================================
#
# `rifai_il_look` (il Salone di bellezza) rimonta il corpo, e per farlo
# chiama `gesto_spegni(true)`: il taglio netto, quello che si usa quando il
# rig sta per non esistere più. È una porta VERA del gioco — ci si passa
# ogni volta che un vicino cambia pettinatura — ed è la stessa che usa
# `set_cucciolo` a ogni gradino di crescita di un cucciolo.

## ⚠️ IL LEASE VA ZITTITO, o `Visitors._routine` rimanda il corpo a fare un
## mestiere e il Punto si rifiuta (giustamente: vuole un passo da spezzare).
## È la stessa trappola di banco di `prova_deduzione`.
func _in_cammino(r: Dictionary) -> Node3D:
	var n := r.get("node") as Node3D
	r["next_act"] = 9999.0
	_player.global_position = n.global_position + Vector3(0, 0, 2.2)
	n.call("_enter_state", "r_idle")
	n.call("_walk_to", n.global_position + Vector3(0, 0, -20), "r_idle")
	var t := 0.0
	while t < 1.0:
		await process_frame
		t += 1.0 / 60.0
	return n


func _perche(n: Node3D) -> String:
	var and_ = n.get("_andatura")
	return "stato «%s» · blend %.2f · viaggio %s · gesto «%s»" % [
			str(n.get("_state")),
			(float(and_.blend) if and_ != null else -1.0),
			str(bool(n.get("_gs_viaggio"))),
			str(n.call("gesto_in_corso"))]


func _atto_due(residenti: Array) -> void:
	var r: Dictionary = residenti[0]
	var lab := str(r.get("label", ""))
	# il palco e il riposo si azzerano: qui non si misura la regia, si misura
	# cosa resta addosso al corpo
	_vis.set("_gesto_acc", 0.0)
	_vis.set("_gesto_chi", "")
	_vis.set("_gesto_riposo", {})
	# ⚠️ E SI FA POSTO NEL TETTO, dalla porta vera: a tutti torna la forza di
	# trattenersi, il registro se ne accorge al suo tick e ritira i livelli.
	# Senza, il permesso del villaggio nega — giustamente — il capo alla
	# frase, e questo atto misurerebbe un silenzio che è suo.
	var animi: Dictionary = _vis.get("_animi")
	for rr in residenti:
		var l2 := str((rr as Dictionary).get("label", ""))
		if animi.has(l2):
			(animi[l2] as RefCounted).limbico.regolazione = 1.0
			(animi[l2] as RefCounted).limbico.umore = 0.0
	await create_timer(1.5).timeout
	print("  fatto posto nel tetto: teste accese adesso %d" % _teste()[0])
	var n: Node3D = await _in_cammino(r)
	print("  il corpo: %s" % _perche(n))
	var acceso := bool(_vis.call("chiedi_gesto", lab, "ha_dedotto"))
	if not acceso:
		acceso = bool(n.call("frase", "pensiero"))
		print("  (l'usciere ha detto no: la frase si chiede al corpo)")
	await create_timer(0.2).timeout
	print("  la frase del pensiero è partita: %s" % ("sì" if acceso else "NO"))
	print("  capo acceso: %s · registro: %s"
			% [str(bool(n.get("_gs_capo"))), str(_registro())])
	if not bool(n.get("_gs_capo")):
		print("  GUASTO DI BANCO: il capo non si è acceso, non c'è niente da misurare")
		return
	# IL SALONE. Il corpo si rimonta da capo, e col corpo se ne va il gesto.
	var ok: bool = bool(n.call("rifai_il_look", {"fur": "e8b4a0", "belly": "f6d8cc"}))
	print("  … e passa dall'estetista (rifai_il_look: %s)" % str(ok))
	var t := 0.0
	var spento_a := -1.0
	var dritta_a := -1.0
	while t < 30.0:
		await process_frame
		t += 1.0 / 60.0
		if spento_a < 0.0 and not bool(n.get("_gs_capo")):
			spento_a = t
		if dritta_a < 0.0 and absf(float(n.get("_gs_capo_x"))) < VISIBILE \
				and spento_a >= 0.0:
			dritta_a = t
	print("  DOPO L'ESTETISTA, trenta secondi:")
	print("    il livello si è spento a: %s"
			% ("MAI — resta acceso" if spento_a < 0.0 else "%.2f s" % spento_a))
	print("    la testa è tornata dritta a: %s"
			% ("MAI — resta storta" if dritta_a < 0.0 else "%.2f s" % dritta_a))
	print("    scarto della testa adesso: %.4f rad (%.1f°)"
			% [float(n.get("_gs_capo_x")), rad_to_deg(float(n.get("_gs_capo_x")))])
	print("    e il registro del villaggio dice: %s" % str(_registro()))


# =========================================================================
# ATTO III — il tetto sotto pressione
# =========================================================================

func _atto_tre(residenti: Array) -> void:
	# tutti quanti ci pensano: la domanda è quante teste il villaggio
	# concede, non quante ne vorrebbe
	var animi: Dictionary = _vis.get("_animi")
	for r in residenti:
		var lab := str((r as Dictionary).get("label", ""))
		if animi.has(lab):
			for _j in 8:
				(animi[lab] as RefCounted).limbico.trattieni()
	# il registro distribuisce (tick ogni 0,75 s)
	var t := 0.0
	while t < 4.0:
		await process_frame
		t += 1.0 / 60.0
	var q := _teste()
	print("  con %d vicini che ci pensano tutti:" % residenti.size())
	print("    teste accese: %d · visibili: %d · tetto: %d"
			% [q[0], q[1], VISITORS.CAPO_MAX])
	# …E ORA UNA FRASE SOPRA. È il punto: la frase accende il capo dal corpo,
	# e il tetto è del villaggio.
	_vis.set("_gesto_acc", 0.0)
	_vis.set("_gesto_chi", "")
	_vis.set("_gesto_riposo", {})
	var riga: Dictionary = {}
	for r in residenti:
		var n := (r as Dictionary).get("node") as Node3D
		if n != null and is_instance_valid(n) and not bool(n.get("_gs_capo")):
			riga = r
			break
	if riga.is_empty():
		print("    (nessun corpo senza capo: niente da provare)")
		return
	var terzo: Node3D = await _in_cammino(riga)
	print("  il corpo: %s" % _perche(terzo))
	var ok: bool = bool(terzo.call("frase", "pensiero"))
	await create_timer(0.5).timeout
	var q2 := _teste()
	print("  poi una FRASE del pensiero su chi non ce l'aveva (partita: %s):" % str(ok))
	print("    teste accese: %d · visibili: %d · tetto: %d"
			% [q2[0], q2[1], VISITORS.CAPO_MAX])
	print("    il registro del villaggio dice: %s" % str(_registro()))
	if q2[0] > VISITORS.CAPO_MAX:
		print("    ⚠️  IL TETTO NON TIENE: %d teste insieme" % q2[0])
	else:
		print("    ✓ il tetto tiene")
