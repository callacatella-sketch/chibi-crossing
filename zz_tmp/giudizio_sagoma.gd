extends SceneTree
## IL GIUDIZIO IN PIXEL — i tre vocabolari messi sullo STESSO metro.
##
##   CHIBI_GIU=/dove ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --script res://zz_tmp/giudizio_sagoma.gd     # SENZA --headless
##
## Stesso banco della ricognizione (MainLevel vero, camera vera, seme 7331,
## mondo congelato, LASTRA DI FONDO), ma il conteggio si fa DENTRO il motore:
## la maschera del corpo e' l'insieme dei pixel che differiscono dalla
## lastra; la lettura di un gesto e' |maschera_base XOR maschera_posa|.
##
## Non misura le mie idee: misura i canali su cui i tre progetti hanno
## scommesso, uno per uno, ai quattro azimut e alle due distanze che
## contano. L'oracolo e' il fotogramma renderizzato, mai una funzione del
## gesto.

const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")

const DISTANZE := [6.0, 9.0]
const VISTE := [["fronte", 180.0], ["trequarti", 135.0], ["profilo", 90.0], ["spalle", 0.0]]
const SEME := 7331
## Sopra quanto un pixel e' "cambiato" (somma delle tre componenti, 0..765).
const SOGLIA := 24

var _dove := ""
var _player: Node3D = null
var _v: Node3D = null
var _righe := {}          # nome posa -> {vista_dist: px}
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
	var big := Rect2i(Vector2i.ZERO, img.get_size())
	return img.get_region(rr.intersection(big)).get_data()


## La maschera: 1 dove il fotogramma differisce dalla lastra di fondo.
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


func _conta(m: PackedByteArray) -> int:
	var c := 0
	for i in m.size():
		if m[i] != 0:
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


## LE POSE. Ognuna e' il canale su cui un progetto ha scommesso, alla sua
## ampiezza dichiarata. Il nome porta il progetto fra parentesi.
func _pose() -> Array:
	var testa := _v.get("_head") as Node3D
	var vis := _v.get("_vis") as Node3D
	var orecchie: Array = _v.get("_c_ears")
	var gambe: Array = _v.get("_c_legs")
	var coda = _v.get("_tail_p")
	var avanti := -_v.global_transform.basis.z
	return [
	# ── il metro di oggi, e la taratura dello strumento ──────────────────
	["OGGI testa44", func(): testa.rotation.y += 0.775],
	["TARA passoLato10cm", func():
		_v.global_position += _cam().global_transform.basis.x * 0.10],

	# ── TEMPO: il contrasto di moto, un fotogramma alla volta ────────────
	["TEMPO cammina 1frame 2.42cm", func(): _v.global_position += avanti * 0.0242],
	["TEMPO fermo 1frame 0.075mm", func(): vis.position.y += 0.00075],
	["TEMPO indietro 22cm", func(): _v.global_position -= avanti * 0.22],

	# ── PSICOLOGIA: il mezzo giro (busto che segue la testa) ─────────────
	["PSI busto20", func(): vis.rotation.y += 0.349],
	["PSI busto24", func(): vis.rotation.y += 0.419],
	["PSI busto35", func(): vis.rotation.y += 0.611],
	["PSI mezzogiro24 (testa+busto)", func():
		vis.rotation.y += 0.419
		testa.rotation.y += 0.356],
	["PSI capo roll10", func(): testa.rotation.z += 0.10],
	["PSI mezzopasso z10", func(): vis.position.z -= 0.10],

	# ── SILHOUETTE: le tre colonne ───────────────────────────────────────
	["SIL peso px7.5 (+rotz)", func():
		vis.position.x += 0.075
		vis.rotation.z -= 0.075],
	["SIL piccolo sy0.90", func(): vis.scale = Vector3(1.054, 0.90, 1.054)],
	["SIL tornasu vy+5.5", func(): vis.position.y += 0.055],
	["SIL sporge vz-9 vx+.16", func():
		vis.position.z -= 0.09
		vis.rotation.x += 0.16],
	["SIL ferma vz-5.5", func(): vis.position.z -= 0.055],
	["SIL gamba scarica z.13", func():
		if gambe.size() > 0:
			(gambe[0] as Node3D).rotation.z += 0.13],

	# ── i canali di appoggio che tutti e tre citano ──────────────────────
	["APP orecchie -0.42", func():
		for o in orecchie:
			(o as Node3D).rotation.x -= 0.42],
	["APP coda z 0.14", func():
		if coda != null:
			(coda as Node3D).rotation.z += 0.14],
	["APP coda x -0.55", func():
		if coda != null:
			(coda as Node3D).rotation.x -= 0.55],
	]


func _go() -> void:
	_dove = OS.get_environment("CHIBI_GIU")
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
			var base_img := await _leggi(rr)
			var m_base := _maschera(base_img, bg)
			# il rumore di fondo: due scatti identici
			var base2 := await _leggi(rr)
			var rumore := _xor(m_base, _maschera(base2, bg))
			if not _righe.has("~area del corpo"):
				_righe["~area del corpo"] = {}
				_ordine.append("~area del corpo")
			_righe["~area del corpo"][col] = _conta(m_base)
			if not _righe.has("~rumore di fondo"):
				_righe["~rumore di fondo"] = {}
				_ordine.append("~rumore di fondo")
			_righe["~rumore di fondo"][col] = rumore
			for p in _pose():
				var nome: String = p[0]
				(p[1] as Callable).call()
				_v.force_update_transform()
				var img := await _leggi(rr)
				var px := _xor(m_base, _maschera(img, bg))
				if not _righe.has(nome):
					_righe[nome] = {}
					_ordine.append(nome)
				_righe[nome][col] = px
				_rimetti()
				_v.force_update_transform()
			print("  fatto %s" % col)

	Engine.time_scale = 1.0
	print("")
	print("PIXEL DI CONTORNO CAMBIATI (maschera XOR contro la lastra di fondo)")
	print("seme %d, 1920x1080, camera vera del gioco" % SEME)
	print("")
	var intest := "posa".rpad(34)
	for c in colonne:
		intest += str(c).lpad(14)
	intest += "   peggiore  peggio/meglio"
	print(intest)
	print("-".repeat(intest.length()))
	for nome in _ordine:
		var riga := str(nome).rpad(34)
		var vals := []
		for c in colonne:
			var v: int = int(_righe[nome].get(c, 0))
			vals.append(v)
			riga += str(v).lpad(14)
		var mn: int = vals.min()
		var mx: int = vals.max()
		riga += str(mn).lpad(11)
		riga += ("%.2f" % (float(mx) / maxf(1.0, float(mn)))).lpad(15)
		print(riga)
	quit(0)
