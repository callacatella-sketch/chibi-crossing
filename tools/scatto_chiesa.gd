extends SceneTree
## USA E GETTA: la vetrina dei pezzi della chiesa, piu la chiesa montata —
## che e la domanda vera: messi insieme, si legge una chiesa o un capannone?
##
##   CHIBI_SCATTI=/tmp Godot --path . --resolution 1600x900 \
##       --script res://tools/scatto_chiesa.gd

const CAT = preload("res://scenes/build/BuildCatalog.gd")

const FILA_A := ["Campanile", "Frontone", "Portale", "Abside"]
const FILA_B := ["Muro di pietra", "Vetrata", "Arcata", "Volta", "Sagrato"]
const FILA_C := ["Altare", "Banco", "Candeliere", "Fonte dei nomi", "Armonium", "Lastricato"]

var _per_nome := {}


static func _dir() -> String:
	var d := OS.get_environment("CHIBI_SCATTI")
	return (d.rstrip("/") + "/") if d != "" else OS.get_user_data_dir() + "/"


func _init() -> void:
	_go()


func _pezzo(nome: String) -> Node3D:
	return (_per_nome[nome]["builder"] as Callable).call()


func _metti(dove: Node3D, nome: String, pos: Vector3, giro := 0.0) -> Node3D:
	var p := _pezzo(nome)
	p.position = pos
	p.rotation.y = giro
	dove.add_child(p)
	return p


func _go() -> void:
	await process_frame
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.93, 0.95, 0.97)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.84, 0.87, 0.93)
	e.ambient_light_energy = 0.85
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -34, 0)
	sun.light_energy = 1.1
	root.add_child(sun)
	var suolo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	suolo.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.82, 0.85, 0.73)
	suolo.material_override = sm
	root.add_child(suolo)

	for v in CAT.items():
		_per_nome[str(v["name"])] = v

	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true

	# --- le tre file dei pezzi, uno accanto all'altro ---
	for coppia in [[FILA_A, 2.4, 1.9, "chiesa_a.png"], [FILA_B, 1.8, 1.5, "chiesa_b.png"],
			[FILA_C, 1.4, 1.1, "chiesa_c.png"]]:
		var fila := Node3D.new()
		root.add_child(fila)
		var lista: Array = coppia[0]
		var passo: float = coppia[1]
		var x := 0.0
		for nome in lista:
			var p := _metti(fila, str(nome), Vector3(x, 0, 0), PI + 0.3)
			x += passo
		await create_timer(0.8).timeout
		var cx := (x - passo) * 0.5
		cam.global_position = Vector3(cx, float(coppia[2]), 5.6)
		cam.look_at(Vector3(cx, float(coppia[2]) * 0.55, 0), Vector3.UP)
		for _i in 4:
			await process_frame
		await create_timer(0.3).timeout
		root.get_texture().get_image().save_png(_dir() + str(coppia[3]))
		print("SHOT ", coppia[3])
		fila.queue_free()
		await process_frame

	# --- la chiesa montata: navata 3x4, abside a nord, sagrato a sud ---
	var ch := Node3D.new()
	root.add_child(ch)
	for x in [-1, 0, 1]:
		for z in [-1, 0, 1, 2]:
			_metti(ch, "Lastricato", Vector3(x, 0, z))
	# i fianchi: vetrata e muro a giorni alterni
	for z in [-1, 0, 1, 2]:
		for lato: float in [-1.5, 1.5]:
			var nome := "Vetrata" if (z % 2 == 0) else "Muro di pietra"
			_metti(ch, nome, Vector3(lato, 0, float(z)), PI * 0.5)
	# il fondo a nord: il frontone col rosone, e l'abside che sporge
	_metti(ch, "Frontone", Vector3(0, 0, -1.5))
	for x: float in [-1.0, 1.0]:
		_metti(ch, "Muro di pietra", Vector3(x, 0, -1.5))
	_metti(ch, "Abside", Vector3(0, 0, -2.0))
	# la facciata a sud: il portale in mezzo, due vetrate ai lati
	_metti(ch, "Portale", Vector3(0, 0, 2.5), PI)
	for x: float in [-1.0, 1.0]:
		_metti(ch, "Vetrata", Vector3(x, 0, 2.5), PI)
	# la volta sopra la navata
	for x in [-1, 0, 1]:
		for z in [-1, 0, 1, 2]:
			_metti(ch, "Volta", Vector3(x, 0, z))
	# dentro: l'altare, i banchi, il resto
	_metti(ch, "Altare", Vector3(0, 0, -1), PI)
	_metti(ch, "Candeliere", Vector3(-1, 0, -1), PI)
	_metti(ch, "Armonium", Vector3(1, 0, -1), PI)
	for z in [0, 1, 2]:
		for x: float in [-1.0, 1.0]:
			_metti(ch, "Banco", Vector3(x, 0, float(z)))
	_metti(ch, "Fonte dei nomi", Vector3(1, 0, 2), PI * 0.5)
	_metti(ch, "Arcata", Vector3(0, 0, 0))
	# fuori: il sagrato e il campanile
	for x in [-1, 0, 1]:
		_metti(ch, "Sagrato", Vector3(x, 0, 3), PI)
	_metti(ch, "Campanile", Vector3(3, 0, 1), PI)
	await create_timer(1.2).timeout

	var viste := [
		[Vector3(6.4, 4.2, 9.6), Vector3(0.4, 1.4, 0.2), "chiesa_montata.png"],
		[Vector3(0.0, 1.35, 6.6), Vector3(0.0, 1.35, 0.0), "chiesa_facciata.png"],
		[Vector3(-5.6, 3.0, -5.4), Vector3(0.0, 1.3, -0.6), "chiesa_abside.png"],
	]
	for v in viste:
		cam.global_position = v[0]
		cam.look_at(v[1], Vector3.UP)
		for _i in 4:
			await process_frame
		await create_timer(0.35).timeout
		root.get_texture().get_image().save_png(_dir() + str(v[2]))
		print("SHOT ", v[2])
	quit(0)
