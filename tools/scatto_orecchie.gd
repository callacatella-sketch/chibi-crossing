extends SceneTree
## Le orecchie da tre angoli e in due pose: a riposo e APPIATTITE (la posa
## peggiore, quella della pioggia). Il difetto della base staccata si vedeva
## di tre quarti e di profilo, non solo di fronte.
const MOCHI = preload("res://scenes/characters/Mochi.tscn")
static func _dir() -> String:
	var d := OS.get_environment("CHIBI_SCATTI")
	return (d.rstrip("/") + "/") if d != "" else OS.get_user_data_dir() + "/"
func _init() -> void: _go()
func _go() -> void:
	await process_frame
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.72, 0.80, 0.88)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.86, 0.89, 0.95); e.ambient_light_energy = 1.0
	env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 28, 0); sun.light_energy = 1.05
	root.add_child(sun)
	var m = MOCHI.instantiate()
	root.add_child(m)
	m.call("forza_espressione", "neutro", 1.0)
	await create_timer(0.6).timeout
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true
	cam.fov = 34.0
	var angoli := [[0.0, "fronte"], [0.9, "trequarti"], [1.57, "profilo"]]
	for posa in [["riposo", false], ["appiattite", true]]:
		m.call("set_tired", bool(posa[1]))
		# le orecchie ci arrivano piano (lerp): si aspetta che ci siano
		await create_timer(1.6).timeout
		for a in angoli:
			var ang: float = float(a[0])
			var testa: Node3D = m.call("get_attach_point", "testa")
			var c: Vector3 = testa.global_position
			cam.global_position = c + Vector3(sin(ang) * 2.05, 0.34, -cos(ang) * 2.05)
			cam.look_at(c + Vector3(0, 0.13, 0), Vector3.UP)
			for _i in 3: await process_frame
			await create_timer(0.2).timeout
			var nome := "orecchie_%s_%s.png" % [posa[0], a[1]]
			root.get_texture().get_image().save_png(_dir() + nome)
			print("SHOT ", nome)
	quit(0)
