extends SceneTree
## IL PROVINO DELL'ATELIER — le carte si vestono davvero?
##
## Il catalogo del builder non ha nessuna immagine su disco: ogni ritratto
## nasce da un builder che gira in `Miniature.gd`. Nessuna asserzione può
## dire se le carte restano BIANCHE, e restare bianche è il modo in cui
## questa UI si rompe: la suite era verde mentre metà griglia era vuota.
##
## Tre istanti dalla stessa vista — subito, dopo due secondi, dopo sei —
## più le misure dello studio. Se la terza tessera ha ancora una carta
## vuota, qualcosa nella catena `_chiedi_visibili` → coda → `_su_miniatura`
## si è interrotto.
##
##     CHIBI_ATELIER=<dir> ~/Downloads/Godot.app/Contents/MacOS/Godot \
##         --path . --resolution 1920x1080 \
##         --script res://tools/provino_atelier.gd
##
## ⚠️ NON in `--headless`: senza schermo lo studio nasce spento e non
## dipinge niente — il provino fotograferebbe la sua stessa assenza.
var _d := ""

func _init() -> void:
	_go()

func _scatta(n: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_jpg(_d + "/" + n + ".jpg", 0.9)
	print("  ", n)

func _go() -> void:
	_d = OS.get_environment("CHIBI_ATELIER")
	if _d == "":
		_d = "user://provino_atelier"
	DirAccess.make_dir_recursive_absolute(_d)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for i in 8:
		await process_frame
	await create_timer(2.0).timeout
	var bs: Node = current_scene.get_node_or_null("BuildSystem")
	if bs == null:
		print("nessun BuildSystem: il livello non è quello vero")
		quit(1)
		return
	# ⚠️ il villaggio dell'autore non si tocca, e i lucchetti si aprono:
	# un catalogo tutto chiuso mostrerebbe una griglia di punti interrogativi
	bs.call("set_persist_for_debug", false)
	bs.set("_locks_active", false)
	bs.call("set_active_for_debug", true, Vector3(2, 0, 4), "Tavolino")
	await create_timer(0.5).timeout
	await _scatta("a-subito")
	await create_timer(2.0).timeout
	await _scatta("b-dopo2s")
	await create_timer(4.0).timeout
	await _scatta("c-dopo6s")
	var mini: Node = bs.get("_mini")
	if mini != null and mini.has_method("misure"):
		print("MISURE: ", mini.call("misure"))
	print("le tessere sono in ", _d)
	quit()
