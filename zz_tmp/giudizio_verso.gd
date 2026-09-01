extends SceneTree
## IL VERSO — «si vede che si e' mosso» non e' «si vede DOVE guarda».
##
##   CHIBI_VER=/dove Godot --path . --script res://zz_tmp/giudizio_verso.gd
##
## Il conteggio XOR contro la lastra di fondo misura la RILEVABILITA'. La
## LEGGIBILITA' e' un'altra domanda, ed e' quella che decide se un gesto
## dice qualcosa: le DUE versioni opposte dello stesso gesto si distinguono
## fra loro?
##
##   rilevabilita' = |maschera(+A) XOR maschera(base)|
##   leggibilita'  = |maschera(+A) XOR maschera(-A)|
##
## Un gesto con tanta rilevabilita' e poca leggibilita' e' un gesto che si
## nota e non si legge: da dietro, la testa che gira di 44 gradi muove le
## orecchie tanto a destra quanto a sinistra.

const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")

const DISTANZE := [6.0]
const VISTE := [["fronte", 180.0], ["trequarti", 135.0], ["profilo", 90.0], ["spalle", 0.0]]
const SEME := 7331
const SOGLIA := 24

var _player: Node3D = null
var _v: Node3D = null
var _righe := {}
var _ordine := []


func _init() -> void:
	_go()


func _cam() -> Camera3D:
	return get_root().get_camera_3d()


func _mesh(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_mesh(c))
	return out


func _bbox_tutto() -> Rect2:
	var radice := _v.get("_corpo") as Node3D
	var r := Rect2()
	var primo := true
	for m in _mesh(radice):
		var mi: MeshInstance3D = m
		var ab := mi.get_aabb()
		var xf := mi.global_transform
		for i in 8:
			var q: Vector3 = xf * (ab.position + Vector3(
					ab.size.x * float(i & 1), ab.size.y * float((i >> 1) & 1),
					ab.size.z * float((i >> 2) & 1)))
			if _cam().is_position_behind(q):
				continue
			var s := _cam().unproject_position(q)
			if primo:
				r = Rect2(s, Vector2.ZERO); primo = false
			else:
				r = r.expand(s)
	return r


func _leggi(rr: Rect2i) -> PackedByteArray:
	for _i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img.get_region(rr.intersection(Rect2i(Vector2i.ZERO, img.get_size()))).get_data()


func _maschera(cur: PackedByteArray, bg: PackedByteArray) -> PackedByteArray:
	var n := cur.size() / 3
	var m := PackedByteArray()
	m.resize(n)
	for i in n:
		var j := i * 3
		var d := absi(int(cur[j]) - int(bg[j])) \
				+ absi(int(cur[j + 1]) - int(bg[j + 1])) \
				+ absi(int(cur[j + 2]) - int(bg[j + 2]))
		m[i] = 1 if d > SOGLIA else 0
	return m


func _xor(a: PackedByteArray, b: PackedByteArray) -> int:
	var n := mini(a.size(), b.size())
	var c := 0
	for i in n:
		if a[i] != b[i]:
			c += 1
	return c


var _snap := {}

func _congela() -> void:
	_snap.clear()
	var nodi := [_v, _v.get("_vis"), _v.get("_corpo"), _v.get("_head"),
			_v.get("_tail_p"), _v.get("_tail_tip")]
	for a in (_v.get("_c_ears") as Array):
		nodi.append(a)
	for a in (_v.get("_c_arms") as Array):
		nodi.append(a)
	for a in (_v.get("_c_legs") as Array):
		nodi.append(a)
	for n in nodi:
		if n != null and is_instance_valid(n):
			_snap[n] = (n as Node3D).transform


func _rimetti() -> void:
	for n in _snap:
		if is_instance_valid(n):
			(n as Node3D).transform = _snap[n]


## Ogni voce: [nome, verso positivo, verso negativo].
func _coppie() -> Array:
	var testa := _v.get("_head") as Node3D
	var vis := _v.get("_vis") as Node3D
	var avanti := -_v.global_transform.basis.z
	return [
	["OGGI testa44 dx/sx",
		func(): testa.rotation.y += 0.775,
		func(): testa.rotation.y -= 0.775],
	["PSI mezzogiro24 dx/sx",
		func():
			vis.rotation.y += 0.419
			testa.rotation.y += 0.356,
		func():
			vis.rotation.y -= 0.419
			testa.rotation.y -= 0.356],
	["PSI capo roll10 dx/sx",
		func(): testa.rotation.z += 0.10,
		func(): testa.rotation.z -= 0.10],
	["SIL peso px7.5 dx/sx",
		func():
			vis.position.x += 0.075
			vis.rotation.z -= 0.075,
		func():
			vis.position.x -= 0.075
			vis.rotation.z += 0.075],
	["SIL alto/basso 5.5cm",
		func(): vis.position.y += 0.055,
		func(): vis.position.y -= 0.055],
	["SIL piccolo/grande 10%",
		func(): vis.scale = Vector3(1.054, 0.90, 1.054),
		func(): vis.scale = Vector3(0.951, 1.10, 0.951)],
	["TEMPO avanti/indietro 22cm",
		func(): _v.global_position += avanti * 0.22,
		func(): _v.global_position -= avanti * 0.22],
	]


func _go() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 10:
		await process_frame
	var liv := current_scene
	_player = liv.get_node_or_null("Player") as Node3D
	var visitors := liv.get_node_or_null("Visitors")
	var build := liv.get_node_or_null("BuildSystem")
	var dn := liv.get_node_or_null("DayNight")
	if build != null:
		build.call("set_persist_for_debug", false)
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	await create_timer(1.5).timeout
	_v = VS.new()
	_v.species = "chibi"
	_v.dna = DNAG.generate(SEME)
	visitors.add_child(_v)
	_v.set("greet_enabled", false)
	await create_timer(1.2).timeout
	_v.call("_enter_state", "r_idle")
	_v.set("_timer", 99999.0)
	_v.global_position = Vector3.ZERO
	await create_timer(0.8).timeout
	_v.set_process(false)
	Engine.time_scale = 0.0
	for _i in 4:
		await process_frame

	var radice := _v.get("_corpo") as Node3D
	var colonne := []
	for vista in VISTE:
		for dv in DISTANZE:
			var col := "%s@%dm" % [str(vista[0]), int(dv)]
			colonne.append(col)
			_v.global_position = Vector3.ZERO
			_player.global_position = Vector3(0.0, _player.global_position.y, float(dv))
			_v.set("_yaw", deg_to_rad(float(vista[1])))
			_v.rotation.y = deg_to_rad(float(vista[1]))
			for _i in 3:
				await process_frame
			_congela()
			var r := _bbox_tutto().grow(140.0)
			var rr := Rect2i(Vector2i(floori(r.position.x), floori(r.position.y)),
					Vector2i(ceili(r.size.x), ceili(r.size.y)))
			radice.visible = false
			var bg := await _leggi(rr)
			radice.visible = true
			var m_base := _maschera(await _leggi(rr), bg)
			for p in _coppie():
				var nome: String = p[0]
				(p[1] as Callable).call()
				_v.force_update_transform()
				var m_piu := _maschera(await _leggi(rr), bg)
				_rimetti(); _v.force_update_transform()
				(p[2] as Callable).call()
				_v.force_update_transform()
				var m_meno := _maschera(await _leggi(rr), bg)
				_rimetti(); _v.force_update_transform()
				var rilev := (_xor(m_base, m_piu) + _xor(m_base, m_meno)) / 2
				var legg := _xor(m_piu, m_meno)
				if not _righe.has(nome):
					_righe[nome] = {}
					_ordine.append(nome)
				_righe[nome][col] = [rilev, legg]
			print("  fatto %s" % col)

	Engine.time_scale = 1.0
	print("")
	print("RILEVABILITA' (px contro il riposo)  /  LEGGIBILITA' (px fra i due versi)")
	print("piu' la seconda e' bassa, piu' il gesto si NOTA senza dire in che verso")
	print("")
	var intest := "coppia".rpad(28)
	for c in colonne:
		intest += str(c).lpad(18)
	print(intest)
	print("-".repeat(intest.length()))
	for nome in _ordine:
		var riga := str(nome).rpad(28)
		for c in colonne:
			var v: Array = _righe[nome][c]
			riga += ("%d / %d" % [int(v[0]), int(v[1])]).lpad(18)
		print(riga)
	print("")
	var r2 := "rapporto legg/rilev".rpad(28)
	print(r2)
	for nome in _ordine:
		var riga := str(nome).rpad(28)
		for c in colonne:
			var v: Array = _righe[nome][c]
			riga += ("%.2f" % (float(v[1]) / maxf(1.0, float(v[0])))).lpad(18)
		print(riga)
	quit(0)
