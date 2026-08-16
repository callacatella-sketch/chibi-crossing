extends SceneTree
## BANCO TEMPORANEO — LA SOSTA E L'INVITO.
##
## A/B ALTERNATO NELLA STESSA CORSA (due processi diversi non sono
## confrontabili: compilazione shader, cache, altre sessioni).
##
##   A = il villaggio di oggi
##   B = + LA SOSTA: quando un corpo entra in `r_bench` si alza il LEASE
##       fino a coprire il timer della seduta. E' quello che fanno gia' il
##       falo' (9999) e le chiacchiere (12 s); alla panchina non lo fa
##       nessuno. La sonda scrive SOLO nel Dictionary del residente —
##       nessun file di produzione e' toccato.
##   C = + L'INVITO: la sonda dirotta chi si sta sedendo verso il posto
##       LIBERO piu' vicino a uno OCCUPATO, se ce n'e' uno a portata
##       (SPOSTA_MAX + 16 m da casa sua). E' l'anello in piu' della cascata
##       di `_panchina_per`, simulato da fuori.
##
##   CHIBI_MODI=ABC   quali modi, in quest'ordine, ciclati
##   CHIBI_BLOCCHI=9  quanti blocchi
##   CHIBI_SEC=120    secondi reali per blocco
##   CHIBI_QUANTI=12  residenti

const CRICCHE := preload("res://scenes/npc/Cricche.gd")
const A_RIPOSO := ["r_idle", "r_wander", "r_fire", "r_bench", "r_sniff"]
const SPOSTA_MAX := 6.0
const RAGGIO_POSTI := 16.0
const ACCANTO := 2.5

var _vis: Node
var _dn: Node3D
var _build: Node
var _cric: Node
var _res: Array = []
var _quanti := 12
var _blocchi := 6
var _sec := 120.0
var _modi := "AB"

var _st_prec: Array = []
var _ep_t0: Array = []
var _lease_dato: Array = []
var _acc := {}
var _invito_chi: Array = []
var _invito_t: Array = []
var _posti: Array = []


func _init() -> void:
	_go()


func _trova(g: String) -> Node:
	for n in get_nodes_in_group(g):
		return n
	return null


func _nuovo() -> Dictionary:
	return {"frames": 0, "dt": 0.0, "sedute": 0, "sec_seduti": 0.0,
		"durate": [], "cop_sec": 0.0, "cop_frames": 0, "sed_cop_sec": 0.0,
		"sed_cop_frames": 0, "terzetti": 0, "max_insieme": 0,
		"vicini_hist": {}, "vicini_somma": 0.0, "vicini_n": 0, "zero_vicini": 0,
		"offerta_si": 0, "offerta_no": 0, "posti_occ_somma": 0.0,
		"posti_occ_max": 0, "posti_n": 0, "stati": {}, "righe0": 0, "righe1": 0,
		"dirotti": 0, "dirotti_no": 0,
		"inviti": 0, "soli": 0, "rifiuti": 0, "ore": {}, "coppie_sedute": {},
		"sec_seduti_con": 0.0}


func _go() -> void:
	for k in [["CHIBI_QUANTI", "q"], ["CHIBI_BLOCCHI", "b"], ["CHIBI_SEC", "s"], ["CHIBI_MODI", "m"]]:
		var v := OS.get_environment(str(k[0]))
		if v == "":
			continue
		match str(k[1]):
			"q": _quanti = int(v)
			"b": _blocchi = int(v)
			"s": _sec = float(v)
			"m": _modi = v
	if change_scene_to_file("res://scenes/levels/MainLevel.tscn") != OK:
		push_error("MainLevel non si apre"); quit(1); return
	for _i in 40:
		await process_frame
	_vis = _trova("visitors"); _dn = _trova("daynight") as Node3D
	_build = _trova("build_system"); _cric = _trova("cricche")
	if _vis == null or _dn == null or _build == null:
		push_error("manca qualcosa"); quit(1); return
	_build.call("set_persist_for_debug", false)

	# IL VILLAGGIO E' QUELLO CARICATO (13 residenti, 28 panchine, 16 cespugli:
	# il salvataggio di prova dell'autore). NON si aggiungono ne' corpi ne'
	# panchine — misurare su una griglia fabbricata vuol dire misurare la
	# griglia. L'unica cosa che si posa e' un GAZEBO: il solo pezzo del gioco
	# con TRE sedute a ~0,9 m, cioe' l'unico posto in cui una triade puo'
	# esistere fisicamente. Il villaggio dell'autore non ne ha.
	if OS.get_environment("CHIBI_GAZEBO") != "0":
		_build.call("place_cell", Vector2i(0, 13), "Gazebo", 0, false)
		_build.call("aggiorna_varchi_ora")
	await process_frame
	_rileva_posti()
	var residenti: Array = _vis.get("_residents")
	_res = residenti
	for _i2 in 8:
		await process_frame
	print("residenti %d · posti a sedere %d" % [_res.size(), _posti.size()])

	_st_prec.resize(_res.size()); _ep_t0.resize(_res.size()); _lease_dato.resize(_res.size())
	for i in _res.size():
		_st_prec[i] = ""; _ep_t0[i] = 0.0; _lease_dato[i] = false
		_invito_chi.append(-1); _invito_t.append(0.0)
	for m in _modi:
		_acc[str(m)] = _nuovo()

	_dn.call("set_time", 0.05)
	var t_gioco := 0.0
	for b in _blocchi:
		var modo := str(_modi[b % _modi.length()])
		var a0: Dictionary = _acc[modo]
		a0["righe0"] = int(a0.get("righe1", 0))
		var righe_pre: int = (_cric.get("_incontri") as Array).size() if _cric else 0
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < int(_sec * 1000.0):
			await process_frame
			var dt: float = get_root().get_process_delta_time()
			t_gioco += dt
			if modo != "A":
				_sonda(modo)
			_campiona(modo, dt, t_gioco)
		var righe_post: int = (_cric.get("_incontri") as Array).size() if _cric else 0
		a0["righe1"] = int(a0.get("righe1", 0)) + (righe_post - righe_pre)
		print("  blocco %d (%s) — ora %.2f (%s) — righe cricche +%d"
				% [b, modo, float(_dn.get("time")), str(_vis.call("_phase")),
				righe_post - righe_pre])
	_referto()
	quit()


func _rileva_posti() -> void:
	_posti.clear()
	for p in (_build.call("get_placed_by_name", "Panchina") as Array):
		_posti.append(p as Node3D)
	for g in (_build.call("get_placed_by_name", "Gazebo") as Array):
		for p2 in (g as Node3D).find_children("Posto*", "Node3D", true, false):
			_posti.append(p2 as Node3D)


## chi occupa cosa, adesso (indice del posto -> true)
func _occupati() -> Array:
	var occ: Array = []
	occ.resize(_posti.size())
	for x in _posti.size():
		occ[x] = false
	for r in _res:
		var n := (r as Dictionary).get("node") as Node3D
		if n == null or not is_instance_valid(n):
			continue
		if str(n.get("_state")) != "r_bench":
			continue
		var aux = n.get("_routine_aux")
		for x2 in _posti.size():
			if _posti[x2] == aux:
				occ[x2] = true
	return occ


func _sonda(modo: String) -> void:
	for i in _res.size():
		var r := _res[i] as Dictionary
		var n := r.get("node") as Node3D
		if n == null or not is_instance_valid(n):
			continue
		var st := str(n.get("_state"))
		# --- L'INVITO: si dirotta chi ha appena scelto la panchina ---
		if modo == "C" and st == "walk" and str(_st_prec[i]) != "walk":
			_forse_dirotta(r, n, modo)
		# --- LA SOSTA: il lease della seduta ---
		if st == "r_bench":
			if not bool(_lease_dato[i]):
				_lease_dato[i] = true
				r["next_act"] = maxf(float(r.get("next_act", 0.0)),
						float(n.get("_timer")))
		else:
			_lease_dato[i] = false


## L'ANELLO IN PIU' DELLA CASCATA, simulato da fuori: se il corpo sta
## andando a sedersi, e c'e' un posto LIBERO accanto a uno OCCUPATO dentro
## la portata di casa sua, ci si va li'.
func _forse_dirotta(r: Dictionary, n: Node3D, modo: String) -> void:
	# ⚠️ `_routine_aux` RESTA APPICCICATO dopo un viaggio in panchina: chi va
	# a un cespuglio con `do_task` non lo azzera. Senza la seconda domanda
	# (dove sta ANDANDO) si dirotta chi stava andando a mangiare.
	if str(n.get("_next_state")) != "r_bench":
		return
	var aux = n.get("_routine_aux")
	if aux == null or not (aux is Node3D):
		return
	var e_posto := false
	for p in _posti:
		if p == aux:
			e_posto = true; break
	if not e_posto:
		return
	var a: Dictionary = _acc[modo]
	var home := Vector3(float((r["cell"] as Vector2i).x), 0.0, float((r["cell"] as Vector2i).y))
	var occ := _occupati()
	var migliore: Node3D = null
	var d_mig := 1.0e30
	for x in _posti.size():
		if bool(occ[x]) or _posti[x] == aux:
			continue
		var accanto := false
		for y in _posti.size():
			if x == y or not bool(occ[y]):
				continue
			if (_posti[x] as Node3D).global_position.distance_to(
					(_posti[y] as Node3D).global_position) <= ACCANTO:
				accanto = true; break
		if not accanto:
			continue
		# nessuno ci sta gia' andando
		var preso := false
		for r2 in _res:
			var n2 := (r2 as Dictionary).get("node") as Node3D
			if n2 and is_instance_valid(n2) and n2.get("_routine_aux") == _posti[x] \
					and str(n2.get("_state")) in ["walk", "r_bench"]:
				preso = true; break
		if preso:
			continue
		# LA PORTATA: dall'ancora spostata al massimo di SPOSTA_MAX da casa,
		# e poi il raggio di sempre
		var d_casa: float = home.distance_to((_posti[x] as Node3D).global_position)
		if d_casa > SPOSTA_MAX + RAGGIO_POSTI:
			continue
		if d_casa < d_mig:
			d_mig = d_casa; migliore = _posti[x] as Node3D
	if migliore == null:
		a["dirotti_no"] = int(a["dirotti_no"]) + 1
		return
	a["dirotti"] = int(a["dirotti"]) + 1
	var arrivo: Vector3 = migliore.global_transform * Vector3(0, 0, 0.8)
	var sguardo := Vector3.ZERO
	if migliore.has_meta("seduta"):
		arrivo = migliore.global_position
	if migliore.has_meta("tavolo"):
		sguardo = (migliore.get_parent() as Node3D).global_transform \
				* (migliore.get_meta("tavolo") as Vector3)
	n.call("do_routine", "bench", Vector3(arrivo.x, 0, arrivo.z), sguardo, migliore)


func _campiona(modo: String, dt: float, t_gioco: float) -> void:
	var a: Dictionary = _acc[modo]
	a["frames"] = int(a["frames"]) + 1
	a["dt"] = float(a["dt"]) + dt
	var pos: Array = []
	var vivi: Array = []
	for i in _res.size():
		var r := _res[i] as Dictionary
		var n := r.get("node") as Node3D
		if n == null or not is_instance_valid(n):
			pos.append(Vector3.ZERO); vivi.append(false); continue
		var st := str(n.get("_state"))
		var stt: Dictionary = a["stati"]
		stt[st] = float(stt.get(st, 0.0)) + dt
		if st == "r_bench" and str(_st_prec[i]) != "r_bench":
			_ep_t0[i] = t_gioco
			a["sedute"] = int(a["sedute"]) + 1
			# a che ora ci si siede
			var ora := int(float(_dn.get("time")) * 12.0)
			var oo: Dictionary = a["ore"]
			oo[ora] = int(oo.get(ora, 0)) + 1
			# L'INVITO CONSEGNATO: c'era gia' qualcuno seduto entro ACCANTO?
			var gia := -1
			for j2 in _res.size():
				if j2 == i:
					continue
				var n3 := (_res[j2] as Dictionary).get("node") as Node3D
				if n3 == null or not is_instance_valid(n3):
					continue
				if str(n3.get("_state")) != "r_bench":
					continue
				if n3.global_position.distance_to(n.global_position) <= ACCANTO:
					gia = j2; break
			if gia >= 0:
				a["inviti"] = int(a["inviti"]) + 1
				_invito_chi[i] = gia
				_invito_t[i] = t_gioco
			else:
				a["soli"] = int(a["soli"]) + 1
				_invito_chi[i] = -1
		elif st != "r_bench" and str(_st_prec[i]) == "r_bench":
			(a["durate"] as Array).append(t_gioco - float(_ep_t0[i]))
			# si e' alzato entro 3 s da quando qualcuno gli si e' seduto accanto?
			for j3 in _res.size():
				if int(_invito_chi[j3]) == i and t_gioco - float(_invito_t[j3]) <= 3.0:
					a["rifiuti"] = int(a["rifiuti"]) + 1
					_invito_chi[j3] = -1
		if st == "r_bench":
			a["sec_seduti"] = float(a["sec_seduti"]) + dt
		_st_prec[i] = st
		pos.append(n.global_position)
		vivi.append(not bool(n.call("is_hidden")))
	var almeno := false
	var almeno_sed := false
	for i2 in _res.size():
		if not bool(vivi[i2]):
			continue
		var vicini := 0
		for j in _res.size():
			if i2 == j or not bool(vivi[j]):
				continue
			var d: float = (pos[i2] as Vector3).distance_to(pos[j] as Vector3)
			if d <= 3.0:
				vicini += 1
			if j > i2 and d <= ACCANTO:
				var na := (_res[i2] as Dictionary).get("node") as Node3D
				var nb := (_res[j] as Dictionary).get("node") as Node3D
				var sa := str(na.get("_state")); var sb := str(nb.get("_state"))
				if sa in A_RIPOSO and sb in A_RIPOSO:
					a["cop_sec"] = float(a["cop_sec"]) + dt
					almeno = true
				if sa == "r_bench" and sb == "r_bench":
					a["sed_cop_sec"] = float(a["sed_cop_sec"]) + dt
					almeno_sed = true
					var cs: Dictionary = a["coppie_sedute"]
					cs["%d_%d" % [i2, j]] = float(cs.get("%d_%d" % [i2, j], 0.0)) + dt
		var h: Dictionary = a["vicini_hist"]
		h[vicini] = int(h.get(vicini, 0)) + 1
		a["vicini_somma"] = float(a["vicini_somma"]) + float(vicini)
		a["vicini_n"] = int(a["vicini_n"]) + 1
		if vicini == 0:
			a["zero_vicini"] = int(a["zero_vicini"]) + 1
	if almeno:
		a["cop_frames"] = int(a["cop_frames"]) + 1
	if almeno_sed:
		a["sed_cop_frames"] = int(a["sed_cop_frames"]) + 1
	# I POSTI: quanti occupati insieme, e il piu' grande grappolo SEDUTO
	if int(a["frames"]) % 15 == 0:
		var occ := _occupati()
		var q := 0
		for o in occ:
			if bool(o):
				q += 1
		a["posti_occ_somma"] = float(a["posti_occ_somma"]) + float(q)
		a["posti_n"] = int(a["posti_n"]) + 1
		if q > int(a["posti_occ_max"]):
			a["posti_occ_max"] = q
		# grappolo: quanti seduti entro ACCANTO l'uno dall'altro
		var grosso := 0
		for x in _posti.size():
			if not bool(occ[x]):
				continue
			var g := 1
			for y in _posti.size():
				if x == y or not bool(occ[y]):
					continue
				if (_posti[x] as Node3D).global_position.distance_to(
						(_posti[y] as Node3D).global_position) <= ACCANTO:
					g += 1
			if g > grosso:
				grosso = g
		if grosso > int(a["max_insieme"]):
			a["max_insieme"] = grosso
		if grosso >= 3:
			a["terzetti"] = int(a["terzetti"]) + 1
		# l'OFFERTA
		var trovato := false
		for x2 in _posti.size():
			if bool(occ[x2]):
				continue
			for y2 in _posti.size():
				if x2 == y2 or not bool(occ[y2]):
					continue
				if (_posti[x2] as Node3D).global_position.distance_to(
						(_posti[y2] as Node3D).global_position) <= ACCANTO:
					trovato = true; break
			if trovato:
				break
		if trovato:
			a["offerta_si"] = int(a["offerta_si"]) + 1
		else:
			a["offerta_no"] = int(a["offerta_no"]) + 1


func _p(v: Array) -> String:
	if v.is_empty():
		return "—"
	var s := v.duplicate(); s.sort()
	var somma := 0.0
	for x in s:
		somma += float(x)
	var sotto := 0
	for x2 in s:
		if float(x2) < 1.0:
			sotto += 1
	return "n=%d  media %.2f s  p50 %.2f  max %.2f  sotto 1 s: %d (%.0f%%)" \
			% [s.size(), somma / float(s.size()), float(s[s.size() / 2]),
			float(s[-1]), sotto, 100.0 * float(sotto) / float(s.size())]


func _referto() -> void:
	for modo in _modi:
		var m := str(modo)
		var a: Dictionary = _acc[m]
		if int(a["frames"]) == 0:
			continue
		var T := float(a["dt"])
		print("\n════════ MODO %s ════════  (%.0f s di gioco, %d frame)" % [m, T, a["frames"]])
		print("  sedute cominciate: %d   ·  secondi-corpo seduti: %.1f (%.1f%% del tempo)"
				% [a["sedute"], a["sec_seduti"], 100.0 * float(a["sec_seduti"]) / (T * float(_res.size()))])
		print("  DURATA DI UNA SEDUTA: %s" % _p(a["durate"] as Array))
		print("  co-presenza entro %.1f m, entrambi a riposo: %.1f s-coppia  (%.2f per 100 s)"
				% [ACCANTO, a["cop_sec"], float(a["cop_sec"]) / T * 100.0])
		print("  …entrambi SEDUTI: %.1f s-coppia   ·  frame con due seduti vicini: %d (%.2f%%)"
				% [a["sed_cop_sec"], a["sed_cop_frames"],
				100.0 * float(a["sed_cop_frames"]) / float(a["frames"])])
		print("  GRAPPOLO PIU' GRANDE di seduti vicini: %d   ·  campioni con >=3: %d"
				% [a["max_insieme"], a["terzetti"]])
		print("  posti occupati insieme: media %.2f  max %d  (su %d)"
				% [float(a["posti_occ_somma"]) / maxf(1.0, float(a["posti_n"])),
				a["posti_occ_max"], _posti.size()])
		print("  «c'e' un posto libero accanto a uno occupato»: %d si' / %d no (%.1f%%)"
				% [a["offerta_si"], a["offerta_no"],
				100.0 * float(a["offerta_si"]) / maxf(1.0, float(int(a["offerta_si"]) + int(a["offerta_no"])))])
		print("  GRUMO — vicini entro 3 m per corpo: media %.3f  ·  a ZERO vicini: %.1f%%"
				% [float(a["vicini_somma"]) / maxf(1.0, float(a["vicini_n"])),
				100.0 * float(a["zero_vicini"]) / maxf(1.0, float(a["vicini_n"]))])
		var h: Dictionary = a["vicini_hist"]
		var ks: Array = h.keys(); ks.sort()
		var righe: Array = []
		for k in ks:
			righe.append("%s:%.1f%%" % [k, 100.0 * float(h[k]) / maxf(1.0, float(a["vicini_n"]))])
		print("     istogramma: " + ", ".join(righe))
		if m == "C":
			print("  dirottamenti: %d riusciti / %d volte non c'era un posto accanto"
					% [a["dirotti"], a["dirotti_no"]])
		var cs2: Dictionary = a["coppie_sedute"]
		var lunghe := 0
		for k9 in cs2:
			if float(cs2[k9]) >= 6.0:
				lunghe += 1
		print("  INVITI: %d arrivi con qualcuno gia' seduto accanto / %d arrivi da solo"
				% [a["inviti"], a["soli"]])
		print("  RIFIUTI (chi c'era si alza entro 3 s): %d" % a["rifiuti"])
		print("  coppie DISTINTE che si sono sedute vicine: %d   ·  di cui sopra i 6 s (INSIEME_MINIMO): %d"
				% [cs2.size(), lunghe])
		var oo2: Dictionary = a["ore"]
		var ok2: Array = oo2.keys(); ok2.sort()
		var oz: Array = []
		for o3 in ok2:
			oz.append("%d/12:%d" % [o3, oo2[o3]])
		print("  ORE in cui ci si siede: " + ", ".join(oz))
		print("  righe di co-presenza registrate dalle Cricche in questo modo: %d" % a["righe1"])
		var st: Dictionary = a["stati"]
		var kk: Array = st.keys()
		kk.sort_custom(func(x, y): return float(st[x]) > float(st[y]))
		var tot := 0.0
		for k2 in kk:
			tot += float(st[k2])
		var out: Array = []
		for k3 in kk.slice(0, 6):
			out.append("%s %.1f%%" % [k3, 100.0 * float(st[k3]) / maxf(1.0, tot)])
		print("     stati: " + " · ".join(out))
