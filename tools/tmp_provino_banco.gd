extends SceneTree
## USA E GETTA — il banco del builder GUARDATO, nel MainLevel vero.
## Apre il gioco, entra in modalità costruzione e fotografa il pannello
## in quattro stati: categoria piccola, categoria grande (Giardino),
## ricerca in corso, recenti.
##
##   CHIBI_BANCO=<dir> Godot --path . --resolution 1280x720 \
##       --script res://tools/tmp_provino_banco.gd

var _dove := ""


func _init() -> void:
	_go()


func _scatta(nome: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_jpg(_dove + "/" + nome + ".jpg", 0.92)
	print("  scatto: ", nome)


func _go() -> void:
	_dove = OS.get_environment("CHIBI_BANCO")
	if _dove == "":
		_dove = "/tmp/banco"
	DirAccess.make_dir_recursive_absolute(_dove)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for i in 8:
		await process_frame
	await create_timer(2.0).timeout
	var liv := current_scene
	var bs := liv.get_node_or_null("BuildSystem")
	if bs == null:
		print("GUASTO: niente BuildSystem")
		quit(1)
		return
	bs.call("set_persist_for_debug", false)
	# tutto sbloccato: si guarda il banco pieno, che è il caso vero di chi
	# ha giocato — e il caso in cui la vecchia riga si spezzava
	bs.set("_locks_active", false)
	bs.call("set_active_for_debug", true, Vector3(2, 0, 4), "Aiuola")
	await create_timer(0.6).timeout
	await _scatta("1-giardino")

	bs.call("_on_cat_pressed", 0)          # Struttura
	await create_timer(0.4).timeout
	await _scatta("2-struttura")

	bs.call("_ricerca_accendi")
	for c in "fior".split(""):
		var ev := InputEventKey.new()
		ev.pressed = true
		ev.unicode = c.unicode_at(0)
		bs.call("_ricerca_tasto", ev)
	await create_timer(0.4).timeout
	await _scatta("3-ricerca")

	bs.call("_ricerca_spegni", true)
	for nome in ["Panchina", "Aiuola", "Lampione", "Cesto fiorito", "Fioriera bistrot"]:
		bs.call("_segna_recente", nome)
	bs.call("_on_cat_pressed", -1)         # la scheda dei recenti
	await create_timer(0.4).timeout
	await _scatta("4-recenti")
	print("BANCO -> ", _dove)
	quit()
