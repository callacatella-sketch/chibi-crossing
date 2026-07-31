extends SceneTree
## USA E GETTA: una fotografia dall'alto del villaggio di prova, per guardare
## con gli occhi quello che i numeri dicono (dieci case in piedi e vuote).
##
##   CHIBI_SCATTI=/tmp Godot --path . --resolution 1600x900 \
##       --script res://tools/scatto_villaggio_prova.gd
##
## Spegne la persistenza appena il livello e in piedi: fotografare non deve
## riscrivere il salvataggio.

## Dove finiscono gli scatti: CHIBI_SCATTI se c'e, altrimenti la cartella
## user:// del gioco (che esiste sempre e non sporca il repo).
static func _dir() -> String:
	var d := OS.get_environment("CHIBI_SCATTI")
	return (d.rstrip("/") + "/") if d != "" else OS.get_user_data_dir() + "/"


func _init() -> void:
	_go()


func _go() -> void:
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for i in 6:
		await process_frame
	var livello := current_scene
	var build := livello.get_node_or_null("BuildSystem")
	if build:
		build.call("set_persist_for_debug", false)
	# il mondo si costruisce in differita, e il mattino ci mette a schiarire
	await create_timer(3.0).timeout

	var cam := Camera3D.new()
	livello.add_child(cam)
	cam.fov = 55.0
	cam.current = true

	var viste := [
		[Vector3(2, 30, 30), Vector3(-2, 0, 1), "prova_villaggio.png"],
		[Vector3(-6, 6, 20), Vector3(-7, 1, 10), "prova_fila_sud.png"],
	]
	for v in viste:
		cam.global_position = v[0]
		cam.look_at(v[1], Vector3.UP)
		for _i in 4:
			await process_frame
		await create_timer(0.4).timeout
		root.get_texture().get_image().save_png(_dir() + str(v[2]))
		print("SHOT ", v[2])
	quit(0)
