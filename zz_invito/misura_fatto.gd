extends SceneTree
## BANCO TEMPORANEO — il FATTO «posto accanto» non trema, e a chi ARRIVA.
##
## Due domande che la corsa lunga non risponde:
##  1. quante volte al minuto cambierebbe il bit, per residente, contro
##     quante volte al minuto quel residente cambia azione? (il tremolio)
##  2. nel villaggio VERO, quanti residenti hanno anche solo la POSSIBILITA'
##     di ricevere un invito — cioe' hanno una coppia di sedute entro la
##     portata di casa loro? (l'esclusione, in cifre)
##
##   CHIBI_SEC=240   quanto misurare
##   CHIBI_GAZEBO=0  senza il gazebo posato dal banco

const ACCANTO := 2.5
const SPOSTA_MAX := 6.0
const RAGGIO_POSTI := 16.0

var _vis: Node
var _dn: Node3D
var _build: Node
var _posti: Array = []


func _init() -> void:
	_go()


func _trova(g: String) -> Node:
	for n in get_nodes_in_group(g):
		return n
	return null


func _go() -> void:
	var sec := 240.0
	if OS.get_environment("CHIBI_SEC") != "":
		sec = float(OS.get_environment("CHIBI_SEC"))
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 50:
		await process_frame
	_vis = _trova("visitors"); _dn = _trova("daynight") as Node3D
	_build = _trova("build_system")
	_build.call("set_persist_for_debug", false)
	if OS.get_environment("CHIBI_GAZEBO") != "0":
		_build.call("place_cell", Vector2i(0, 13), "Gazebo", 0, false)
		_build.call("aggiorna_varchi_ora")
		await process_frame
	for p in (_build.call("get_placed_by_name", "Panchina") as Array):
		_posti.append(p as Node3D)
	for g in (_build.call("get_placed_by_name", "Gazebo") as Array):
		for p2 in (g as Node3D).find_children("Posto*", "Node3D", true, false):
			_posti.append(p2 as Node3D)
	for s in (_build.call("get_placed_by_name", "Serra") as Array):
		for p3 in (s as Node3D).find_children("Posto*", "Node3D", true, false):
			_posti.append(p3 as Node3D)
	var res: Array = _vis.get("_residents")
	print("residenti %d · posti %d" % [res.size(), _posti.size()])

	# ---- 1) LA GEOGRAFIA DELL'INVITO, che non dipende dal tempo ----
	# quante COPPIE di sedute stanno entro ACCANTO l'una dall'altra
	var coppie := 0
	var in_coppia := {}
	for x in _posti.size():
		for y in range(x + 1, _posti.size()):
			if (_posti[x] as Node3D).global_position.distance_to(
					(_posti[y] as Node3D).global_position) <= ACCANTO:
				coppie += 1
				in_coppia[x] = true; in_coppia[y] = true
	# e i GRAPPOLI da tre: un posto con almeno due altri entro ACCANTO
	var terne := 0
	for x2 in _posti.size():
		var q := 0
		for y2 in _posti.size():
			if x2 != y2 and (_posti[x2] as Node3D).global_position.distance_to(
					(_posti[y2] as Node3D).global_position) <= ACCANTO:
				q += 1
		if q >= 2:
			terne += 1
	print("  coppie di sedute entro %.1f m: %d   ·  sedute che ne hanno >=2 accanto: %d"
			% [ACCANTO, coppie, terne])
	# CHI PUO' ESSERE INVITATO: quanti residenti hanno una coppia di sedute
	# dentro la portata di casa loro
	var raggiunti := 0
	var elenco: Array = []
	for r in res:
		var c: Vector2i = (r as Dictionary).get("cell", Vector2i(999, 999))
		if c.x == 999:
			continue
		var home := Vector3(float(c.x), 0.0, float(c.y))
		var ok := false
		for x3 in in_coppia:
			if home.distance_to((_posti[int(x3)] as Node3D).global_position) <= SPOSTA_MAX + RAGGIO_POSTI:
				ok = true; break
		if ok:
			raggiunti += 1
		else:
			elenco.append(str((r as Dictionary).get("label", "?")))
	print("  residenti che hanno una coppia di sedute a portata: %d su %d" % [raggiunti, res.size()])
	if not elenco.is_empty():
		print("  fuori portata: " + ", ".join(elenco))

	# ---- 2) IL TREMOLIO ----
	var bit_prec: Array = []
	var flip: Array = []
	var az_prec: Array = []
	var az_flip: Array = []
	# e il confronto: il booleano NUDO «un vicino entro 2,5 m»
	var nudo_prec: Array = []
	var nudo_flip: Array = []
	for _k in res.size():
		bit_prec.append(false); flip.append(0); az_prec.append(-99)
		az_flip.append(0); nudo_prec.append(false); nudo_flip.append(0)
	var t0 := Time.get_ticks_msec()
	var acceso := 0
	var campioni := 0
	var ecs = _vis.get("_ecs")
	var sosta := OS.get_environment("CHIBI_SOSTA") == "1"
	var lease_dato: Array = []
	var q_prec: Array = []
	var q_flip: Array = []
	var q_acceso := 0
	var q_camp := 0
	for _k2 in res.size():
		lease_dato.append(false); q_prec.append(false); q_flip.append(0)
	var frame := 0
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame
		frame += 1
		# LA SOSTA: la stessa sonda esterna della corsa A/B/C
		if sosta:
			for i9 in res.size():
				var r9 := res[i9] as Dictionary
				var n9 := r9.get("node") as Node3D
				if n9 == null or not is_instance_valid(n9):
					continue
				if str(n9.get("_state")) == "r_bench":
					if not bool(lease_dato[i9]):
						lease_dato[i9] = true
						r9["next_act"] = maxf(float(r9.get("next_act", 0.0)),
								float(n9.get("_timer")))
				else:
					lease_dato[i9] = false
		# occupazione dei posti, una volta per tutti
		var occ: Array = []
		occ.resize(_posti.size())
		for x4 in _posti.size():
			occ[x4] = false
		for r2 in res:
			var n2 := (r2 as Dictionary).get("node") as Node3D
			if n2 == null or not is_instance_valid(n2) or str(n2.get("_state")) != "r_bench":
				continue
			for x5 in _posti.size():
				if _posti[x5] == n2.get("_routine_aux"):
					occ[x5] = true
		for i in res.size():
			var r3 := res[i] as Dictionary
			var n3 := r3.get("node") as Node3D
			if n3 == null or not is_instance_valid(n3):
				continue
			var c2: Vector2i = r3.get("cell", Vector2i(999, 999))
			var home2 := Vector3(float(c2.x), 0.0, float(c2.y))
			var bit := false
			for x6 in _posti.size():
				if bool(occ[x6]):
					continue
				if home2.distance_to((_posti[x6] as Node3D).global_position) > SPOSTA_MAX + RAGGIO_POSTI:
					continue
				for y6 in _posti.size():
					if x6 != y6 and bool(occ[y6]) \
							and (_posti[x6] as Node3D).global_position.distance_to(
								(_posti[y6] as Node3D).global_position) <= ACCANTO:
						bit = true; break
				if bit:
					break
			if bit != bool(bit_prec[i]):
				flip[i] = int(flip[i]) + 1
				bit_prec[i] = bit
			if bit:
				acceso += 1
			campioni += 1
			# …e COME LO VEDE LA DECISIONE: i fatti si rinfrescano ogni
			# FATTI_OGNI = 30 frame, sfalsati per residente. Un tremolio
			# sotto il mezzo secondo la decisione non lo vede MAI.
			if (frame + i) % 30 == 0:
				if bit != bool(q_prec[i]):
					q_flip[i] = int(q_flip[i]) + 1
					q_prec[i] = bit
				if bit:
					q_acceso += 1
				q_camp += 1
			# il booleano NUDO, per confronto
			var nud := false
			for j in res.size():
				if j == i:
					continue
				var n4 := (res[j] as Dictionary).get("node") as Node3D
				if n4 and is_instance_valid(n4) \
						and n4.global_position.distance_to(n3.global_position) <= ACCANTO:
					nud = true; break
			if nud != bool(nudo_prec[i]):
				nudo_flip[i] = int(nudo_flip[i]) + 1
				nudo_prec[i] = nud
			# i cambi d'AZIONE, il metro di confronto
			if ecs != null and r3.has("ecs"):
				var az: int = ecs.azione(int(r3["ecs"]))
				if az != int(az_prec[i]):
					az_flip[i] = int(az_flip[i]) + 1
					az_prec[i] = az
	var minuti := sec / 60.0
	var sf := 0; var sn := 0; var sa := 0
	for i2 in res.size():
		sf += int(flip[i2]); sn += int(nudo_flip[i2]); sa += int(az_flip[i2])
	print("\n  in %.0f s:" % sec)
	print("  il FATTO «posto accanto» — flip/min per residente: %.2f   (acceso il %.1f%% dei campioni)"
			% [float(sf) / float(res.size()) / minuti, 100.0 * float(acceso) / maxf(1.0, float(campioni))])
	print("  il booleano NUDO «un vicino entro 2,5 m» — flip/min per residente: %.2f"
			% [float(sn) / float(res.size()) / minuti])
	var sq := 0
	for i3 in res.size():
		sq += int(q_flip[i3])
	print("  …lo stesso fatto LETTO COME LO LEGGE LA DECISIONE (ogni 30 frame,"
			+ " sfalsato) — flip/min: %.2f  (acceso il %.1f%%)"
			% [float(sq) / float(res.size()) / minuti,
			100.0 * float(q_acceso) / maxf(1.0, float(q_camp))])
	print("  cambi d'AZIONE per residente — al minuto: %.2f"
			% [float(sa) / float(res.size()) / minuti])
	quit()
