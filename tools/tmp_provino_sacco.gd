extends SceneTree
const PAL := preload("res://scenes/build/BuildPalestra.gd")
func _init() -> void: _go()
func _go() -> void:
	await process_frame
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.85, 0.88, 0.92)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.88, 0.9, 0.95); e.ambient_light_energy = 1.0
	env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0); sun.light_energy = 1.1
	root.add_child(sun)
	var pezzo := PAL.sacco()
	root.add_child(pezzo)
	await create_timer(0.3).timeout
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true
	cam.fov = 35.0
	for vista in [
		["fronte", Vector3(0, 1.15, -2.5), Vector3(0, 1.15, -0.1)],
		["trequarti", Vector3(1.6, 1.3, -1.7), Vector3(0, 1.15, -0.1)],
		["profilo", Vector3(2.2, 1.1, 0), Vector3(0, 1.2, 0)],
		["dettaglio", Vector3(0.5, 1.05, -1.15), Vector3(0.08, 0.95, -0.3)],
		["top", Vector3(0.25, 2.5, -0.5), Vector3(0, 2.0, -0.1)],
	]:
		cam.global_position = vista[1]
		cam.look_at(vista[2], Vector3.UP)
		print("VISTA ", vista[0], " pos=", cam.global_position, " basis_z=", cam.global_transform.basis.z)
		for _i in 8: await process_frame
		await create_timer(0.4).timeout
		for _i in 4: await process_frame
		print("  dopo attesa: pos=", cam.global_position, " basis_z=", cam.global_transform.basis.z)
		var img := root.get_texture().get_image()
		print("  img size=", img.get_size())
		img.save_png(
			"/private/tmp/claude-501/-Users-duck-Developer-chibi-crossing/460fb14b-4dac-4a09-afff-91a2f1147283/scratchpad/sacco_%s.png" % vista[0])
	quit(0)
