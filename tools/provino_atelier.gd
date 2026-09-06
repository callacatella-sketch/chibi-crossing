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
	# ⚠️ I LUCCHETTI SI APRONO SOLO PER LA SCENA «aperto». Le altre scene
	# esistono APPOSTA per guardare il pannello di chi non ha ancora tutto:
	# le carte col «?», i cartellini del prezzo, i conti dei corredi. Era
	# il residuo dichiarato di questo lavoro — l'Atelier era stato guardato
	# in UNA configurazione sola, e tre difetti su sette vivevano nelle altre.
	var scena := OS.get_environment("CHIBI_SCENA")
	if scena == "":
		scena = "aperto"
	# ⚠️ anche «colori» apre i lucchetti: la barra delle varianti compare
	# solo con in mano un pezzo VERNICIABILE, e col catalogo chiuso il
	# builder ripiega sul Pavimento — che non lo è. Il provino mostrava una
	# scena senza il soggetto che doveva giudicare.
	if scena == "aperto" or scena == "colori":
		bs.set("_locks_active", false)
	bs.call("set_active_for_debug", true, Vector3(2, 0, 4), "Tavolino")
	await create_timer(0.5).timeout
	match scena:
		"piegato":
			# la striscia: i bolli si vestono, e ci sta dentro l'altezza?
			await _scatta("p0-aperto")
			bs.call("_piega", false)
			await create_timer(0.6).timeout
			await _scatta("p1-piegato-subito")
			await create_timer(4.0).timeout
			await _scatta("p2-piegato-dopo4s")
			bs.call("_piega", true)
			await create_timer(0.6).timeout
			await _scatta("p3-riaperto")
		"colori":
			# la barra delle varianti: sta SOPRA il pannello, o dentro la
			# griglia? È il difetto che nessun provino aveva mai guardato,
			# perché nessuna scena sbloccava una tinta.
			var eco: Node = bs.call("_economy")
			if eco != null and eco.has_method("unlock_variant"):
				for tinta in ["menta", "lavanda", "miele"]:
					eco.call("unlock_variant", tinta)
			bs.call("_update_variant_bar")
			await create_timer(2.5).timeout
			await _scatta("v0-aperto")
			bs.call("_piega", false)
			await create_timer(1.0).timeout
			await _scatta("v1-piegato")
		"chiuso":
			# il pannello di chi comincia: i «?», i prezzi, i corredi
			await _scatta("q0-partenza")
			await create_timer(3.0).timeout
			await _scatta("q1-dopo3s")
			bs.call("_on_cat_pressed", bs.get("CAT_TUTTO"))
			await create_timer(3.5).timeout
			await _scatta("q2-tutto-il-catalogo")
		_:
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
