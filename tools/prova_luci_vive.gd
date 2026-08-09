extends SceneTree
## LE LUCI DEL CATALOGO, NEL VILLAGGIO VERO, DI NOTTE.
##
## Lo studio del provino ha un pavimento blu-grigio: una luce calda ci
## batte sopra e torna GRIGIA, perché l'albedo del suolo è freddo. Va
## benissimo per giudicare la FORMA di una pozza (dove sta il centro,
## dove muore il bordo) e la sua forza; non dice niente sul colore. E il
## colore è metà del mestiere di una luce.
##
## Qui invece le stesse luci si posano col BuildSystem vero dentro
## `MainLevel`, si porta l'orologio a notte fonda, e si fotografa: erba
## vera, sentiero vero, cielo vero, e l'ambiente notturno di DayNight —
## che è il DOPPIO di quello dello studio (0.30 contro 0.16). È l'unico
## posto in cui si può dire «questa luce è tarata».
##
##   CHIBI_LUCI_VIVE=/dove Godot --path . \
##       --script res://tools/prova_luci_vive.gd

## dove si posa cosa: una fila di pezzi accesi, distanziati abbastanza da
## non prestarsi luce a vicenda.
## `CHIBI_GRUPPO=2` posa il secondo gruppo: sono più ingombranti e
## vogliono più spazio fra loro (una casa sull'albero accanto a un gazebo
## si prestano luce e non si giudica più niente).
const POSA := [
	{"nome": "Lampione", "c": Vector2i(8, 8)},
	{"nome": "Lampada", "c": Vector2i(12, 8)},
	{"nome": "Braciere stellato", "c": Vector2i(16, 8)},
	{"nome": "Fontana", "c": Vector2i(8, 12)},
	{"nome": "Candeliere", "c": Vector2i(12, 12)},
	{"nome": "Faretti", "c": Vector2i(16, 12)},
	{"nome": "Lucine", "c": Vector2i(8, 16)},
	{"nome": "Faro caserma", "c": Vector2i(12, 16)},
	{"nome": "Giostrina", "c": Vector2i(16, 16)},
]
const POSA2 := [
	{"nome": "Camino", "c": Vector2i(8, 8)},
	{"nome": "Gazebo", "c": Vector2i(14, 8)},
	{"nome": "Torretta", "c": Vector2i(20, 8)},
	{"nome": "Casa albero", "c": Vector2i(8, 14)},
	{"nome": "Fondale", "c": Vector2i(14, 14)},
	{"nome": "Serra", "c": Vector2i(20, 14)},
	{"nome": "Serra", "c": Vector2i(21, 14)},
]
## l'ora: notte fonda, sole sotto e luna alta (DayNight: 0.0 = mezzanotte)
const NOTTE := 0.97

var _build: Node = null
var _cam: Camera3D = null


func _init() -> void:
	_go()


func _trova(gruppo: String) -> Node:
	for n in get_nodes_in_group(gruppo):
		return n
	return null


func _scatta(centro: Vector3, az: float, ele: float, dist: float, dove: String) -> void:
	_cam.position = centro + Vector3(sin(az), ele, -cos(az)).normalized() * dist
	_cam.look_at(centro, Vector3.UP)
	for _k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_jpg(dove, 0.92)


func _go() -> void:
	var ok: int = change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	if ok != OK:
		push_error("MainLevel non si apre")
		quit(1)
		return
	for _i in 20:
		await process_frame

	_build = _trova("build_system")
	var dn := _trova("daynight")
	if _build == null or dn == null:
		push_error("manca il BuildSystem o il DayNight")
		quit(1)
		return
	# questa è una prova, non una partita: niente scritture su disco
	_build.set("_persist", false)
	dn.call("set_time", NOTTE)

	var posa: Array = POSA2 if OS.get_environment("CHIBI_GRUPPO") == "2" else POSA
	for p in posa:
		_build.call("place_cell", p["c"], p["nome"], 0, false, 0, "")
	# le serre si fondono con un rinfresco DIFFERITO: qui si fotografa
	# subito, quindi si forza (vedi BuildSystem.aggiorna_serre_ora)
	_build.call("aggiorna_serre_ora")
	for _i in 6:
		await process_frame
	# l'orologio del mondo continua a girare durante gli scatti: lo si
	# riporta a notte subito prima di fotografare, o l'ultima foto è
	# all'alba
	dn.call("set_time", NOTTE)

	var dove := OS.get_environment("CHIBI_LUCI_VIVE")
	if dove == "":
		dove = "docs/catalogo/provini-luci-vive"
	DirAccess.make_dir_recursive_absolute(dove)

	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.current = true
	root.add_child(_cam)

	var i := 0
	for p in posa:
		i += 1
		dn.call("set_time", NOTTE)
		var c: Vector2i = p["c"]
		var centro := Vector3(float(c.x), 0.9, float(c.y))
		var slug := str(p["nome"]).to_lower().replace(" ", "-")
		await _scatta(centro, 0.785398, 0.55, 5.4,
				dove.rstrip("/") + "/%02d-%s.jpg" % [i, slug])
		print("  ", p["nome"])

	# e una veduta d'insieme: è così che il giocatore le vede davvero,
	# tutte insieme, dal suo punto di vista
	dn.call("set_time", NOTTE)
	await _scatta(Vector3(14.0, 0.9, 12.0), 0.785398, 0.62, 17.0,
			dove.rstrip("/") + "/00-insieme.jpg")
	print("LUCI VIVE -> ", dove)
	quit()
