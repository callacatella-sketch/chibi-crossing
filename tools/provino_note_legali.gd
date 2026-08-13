extends SceneTree

## IL PROVINO DELLE NOTE LEGALI — perché una suite verde non dice niente su
## come si legge una pagina.
##
## `test_licenze.gd` prova che i file ci siano e dicano la cosa giusta. Non
## può dire se la pagina è LEGGIBILE: se il testo di una licenza esce dal
## pannello, se i bottoni si accavallano, se il lettore mostra una parete di
## caratteri da 12 punti in cui non si trova niente. Questa roba si guarda.
##
##     CHIBI_NOTE=/tmp/note ~/Downloads/Godot.app/Contents/MacOS/Godot \
##         --path . --resolution 1280x720 --script res://tools/provino_note_legali.gd
##
## Fotografa quattro momenti: l'indice senza il modello (quello che vede la
## maggioranza dei giocatori), l'indice CON il modello, il lettore aperto sui
## Gemma Terms of Use, e la pagina in inglese. L'ultima non è un vezzo: le
## righe inglesi sono più lunghe delle italiane, ed è lì che un pannello a
## larghezza fissa si rompe.
##
## ⚠️ **NIENTE `--headless`**: senza rendering non c'è niente da guardare, ed
## è esattamente il modo in cui un guasto di impaginazione resta invisibile.

const NOTE := preload("res://scenes/ui/NoteLegali.gd")

var _dove := ""
var _passo := 0
var _atteso := 0
var _radice: Control
var _pagina


func _init() -> void:
	_dove = OS.get_environment("CHIBI_NOTE")
	if _dove == "":
		_dove = "/tmp/note_legali"
	DirAccess.make_dir_recursive_absolute(_dove)
	print("[provino] le foto vanno in ", _dove)

	var sfondo := ColorRect.new()
	sfondo.color = Color("cfe4d0")          # il verde del prato, per contrasto
	sfondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(sfondo)

	_radice = CenterContainer.new()
	_radice.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_radice)


func _process(_d: float) -> bool:
	_passo += 1
	# si aspettano due fotogrammi per scena: il primo costruisce, il secondo
	# ha i Container già disposti. Fotografare al primo dà pannelli a
	# dimensione zero — il classico «la schermata è vuota» che non lo è.
	if _passo < _atteso:
		return false
	match _passo:
		1:
			_scena("1-indice-senza-modello", false, "it")
			_atteso = 4
		4:
			_scatta("1-indice-senza-modello")
			_scena("2-indice-col-modello", true, "it")
			_atteso = 8
		8:
			_scatta("2-indice-col-modello")
			_apri_documento("Gemma-Terms-of-Use.txt")
			_atteso = 12
		12:
			_scatta("3-lettore-terms")
			_scena("4-indice-inglese", true, "en")
			_atteso = 16
		16:
			_scatta("4-indice-inglese")
			print("[provino] fatto.")
			return true
	return false


func _scena(_nome: String, col_modello: bool, lingua: String) -> void:
	L10n.imposta(lingua)
	for c in _radice.get_children():
		_radice.remove_child(c)
		c.queue_free()
	_pagina = NOTE.new()
	# LA LEVA si tira PRIMA di entrare nell'albero: l'indice si costruisce in
	# `_ready`, e una leva tirata dopo non cambierebbe niente — la pagina
	# sarebbe già quella sbagliata, e il provino fotograferebbe due volte la
	# stessa cosa credendo di averne fotografate due diverse.
	_pagina.forza_modello = 1 if col_modello else 0
	var cornice := PanelContainer.new()
	cornice.add_theme_stylebox_override("panel", CozyUI.paper_panel(28))
	cornice.custom_minimum_size = Vector2(560, 520)
	cornice.add_child(_pagina)
	_pagina.incorpora()
	_radice.add_child(cornice)


func _apri_documento(file: String) -> void:
	_pagina.call("_apri", file)


func _scatta(nome: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var p := "%s/%s.png" % [_dove, nome]
	img.save_png(p)
	print("[provino] ", p)
