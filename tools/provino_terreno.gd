extends SceneTree
## IL PROVINO DEL TERRENO. Mancava — ci sono provini per ogni pezzo, per le
## serre, per le rastrelliere, per le luci notturne e per il catalogo
## intero, e NESSUNO per il suolo: e' la ragione per cui il terreno non era
## verificabile, e per cui una tela dei sentieri satura ha reso il villaggio
## un piazzale senza che nessun test se ne accorgesse.
##
##   CHIBI_TERRENO=/dove/salvare Godot --path . \
##       --script res://tools/provino_terreno.gd
##
## DUE TRAPPOLE, tutte e due gia' pagate:
##  · IL BANCO EREDITA IL SALVATAGGIO. Senza fissare giorno e ora si
##    fotografa un mondo in inverno, di sera, e si giudica la neve
##    credendola il prato (successo: tre rese lette come un difetto di
##    illuminazione).
##  · LA TAVOLOZZA NON SEGUE IL GIORNO DA SOLA: la scrive
##    CozyWorld.set_season. Senza quella riga il prato resta color sabbia
##    (autunno) e si accusa lo shader di un difetto che non ha.
const VISTE := [
	{"n": "1-prato.jpg", "p": Vector3(2.0, 2.7, 5.7), "l": Vector3(2.0, 0.4, 2.0)},
	{"n": "2-bosco.jpg", "p": Vector3(1.5, 2.4, -8.0), "l": Vector3(0.0, 0.5, -18.0)},
	{"n": "3-sentiero.jpg", "p": Vector3(4.0, 1.4, -20.0), "l": Vector3(-1.0, 0.3, -30.0)},
	{"n": "4-alberi.jpg", "p": Vector3(-3.0, 1.5, -1.0), "l": Vector3(-6.0, 0.3, -5.0)},
]
func _init() -> void:
	_go()
func _go() -> void:
	if change_scene_to_file("res://scenes/levels/MainLevel.tscn") != OK:
		quit(1); return
	for _i in 20:
		await process_frame
	var dn := root.find_child("DayNight", true, false)
	if dn:
		dn.set("day", 12)
		dn.set("time", 0.42)
	var cw := root.find_child("CozyWorld", true, false)
	# la STAGIONE si sceglie: 0 primavera · 1 estate · 2 autunno · 3 inverno
	# (CHIBI_STAG=2 per guardare la lettiera, =3 per la neve)
	var stag := int(OS.get_environment("CHIBI_STAG"))
	var neve := 0.85 if stag == 3 else 0.0
	if cw and cw.has_method("set_season"):
		cw.call("set_season", stag, neve, false)
	for _i in 45:
		await process_frame
	var dove := OS.get_environment("CHIBI_TERRENO")
	if dove == "": dove = "/tmp/t2"
	DirAccess.make_dir_recursive_absolute(dove)
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.current = true
	root.add_child(cam)
	for v in VISTE:
		cam.position = v["p"]
		cam.look_at(v["l"], Vector3.UP)
		for _k in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_jpg(dove + "/" + str(v["n"]), 0.92)
	print("T2 -> ", dove)
	quit()
