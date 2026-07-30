extends SceneTree
## Fotogrammi del prologo, ai momenti che contano: sotto la pioggia, il lampo,
## il giro verso il giocatore, l'ultima battuta col cielo che si apre.
const PROLOGO = preload("res://scenes/levels/Prologo.gd")
static func _dir() -> String:
	var d := OS.get_environment("CHIBI_SCATTI")
	return (d.rstrip("/") + "/") if d != "" else OS.get_user_data_dir() + "/"
func _init() -> void: _go()
func _go() -> void:
	await process_frame
	var p = PROLOGO.new()
	root.add_child(p)
	var tappe := [[2.0, "prologo_1_pioggia.png"], [4.6, "prologo_2_giro.png"],
			[8.5, "prologo_3_prima.png"], [15.0, "prologo_4_aiuto.png"],
			[23.0, "prologo_5_sereno.png"], [28.0, "prologo_6_fine.png"]]
	var passato := 0.0
	for t in tappe:
		var quanto: float = float(t[0]) - passato
		if quanto > 0.0:
			await create_timer(quanto).timeout
		passato = float(t[0])
		for _i in 2: await process_frame
		root.get_texture().get_image().save_png(_dir() + str(t[1]))
		print("SHOT ", t[1])
	quit(0)
