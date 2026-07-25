extends Node

## Il menu di pausa (Esc). Mette in pausa TUTTO il mondo (get_tree().paused):
## Mochi, il ciclo giorno/notte, i bisogni, l'ecosistema — tutto si ferma con
## grazia. Solo la musica continua (Sfx è PROCESS_MODE_ALWAYS). Da qui:
## riprendi, impostazioni, torna al titolo (salvando), o esci dal gioco.
##
## Si apre solo quando ha senso: non durante la costruzione, il negozio, o
## mentre Mochi è seduta / in un altro pannello (player congelato).

const TITLE_SCENE := "res://scenes/ui/TitleScreen.tscn"

var _ui: CanvasLayer
var _backdrop: ColorRect
var _menu: PanelContainer
var _settings: CozySettingsPanel
var _player: Node
var _sfx
var _shown := false
var _in_settings := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_ui()
	# %Player non si risolve dai nodi creati a runtime (owner null): uso il gruppo
	(func(): _player = get_tree().get_first_node_in_group("player_controller")).call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _shown:
		if _in_settings:
			_show_settings(false)
		else:
			_resume()
		get_viewport().set_input_as_handled()
	elif _can_open():
		_open()
		get_viewport().set_input_as_handled()


func _can_open() -> bool:
	var bs := get_tree().get_first_node_in_group("build_system")
	if bs and bs.has_method("is_active") and bs.is_active():
		return false
	var shop := get_tree().get_first_node_in_group("shop")
	if shop and shop.has_method("is_open") and shop.is_open():
		return false
	# un altro pannello (calendario, cucina, stelle…) ha già congelato Mochi
	if _player and _player.has_method("is_physics_processing") and not _player.is_physics_processing():
		return false
	return true


func _open() -> void:
	_shown = true
	_in_settings = false
	get_tree().paused = true
	_ui.visible = true
	_menu.visible = true
	_settings.visible = false
	CozyUI.fade_to(_backdrop, 0.5, 0.3)
	CozyUI.appear(_menu, 0.34)
	if _sfx: _sfx.build_open()


func _resume() -> void:
	_shown = false
	CozyUI.fade_to(_backdrop, 0.0, 0.22)
	CozyUI.dismiss(_menu, _finish_resume, 0.2)
	if _sfx: _sfx.build_close()


func _finish_resume() -> void:
	if _shown:
		return   # riaperto durante la dissolvenza: lascialo aperto e in pausa
	_ui.visible = false
	get_tree().paused = false


func _show_settings(on: bool) -> void:
	_in_settings = on
	if on:
		_menu.visible = false
		_settings.visible = true
		CozyUI.appear(_settings, 0.3)
	else:
		_settings.visible = false
		_menu.visible = true
		CozyUI.appear(_menu, 0.3)
	if _sfx: _sfx.ui_select()


func _to_title() -> void:
	# salva il villaggio prima di uscire (rete di sicurezza in più al backup)
	var bs := get_tree().get_first_node_in_group("build_system")
	if bs and bs.has_method("_save_village"):
		bs._save_village()
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


func _quit() -> void:
	var bs := get_tree().get_first_node_in_group("build_system")
	if bs and bs.has_method("_save_village"):
		bs._save_village()
	get_tree().quit()


# ================================================================ UI
func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui.visible = false
	add_child(_ui)

	_backdrop = CozyUI.backdrop()
	_ui.add_child(_backdrop)
	_ui.add_child(CozyUI.petals(16))

	var center := CozyUI.center_root()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(center)

	# --- il pannello del menu ---
	_menu = PanelContainer.new()
	_menu.add_theme_stylebox_override("panel", CozyUI.paper_panel(30))
	_menu.custom_minimum_size = Vector2(420, 0)
	center.add_child(_menu)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_menu.add_child(col)

	col.add_child(CozyUI.title_label("In pausa", 34))
	var sub := CozyUI.hint_label("Il villaggio ti aspetta.", 15)
	col.add_child(sub)
	col.add_child(_gap(6))

	_menu_button(col, "Riprendi", CozyUI.MINT, _resume)
	_menu_button(col, "Impostazioni", CozyUI.SKY, func(): _show_settings(true))
	_menu_button(col, "Torna al titolo", CozyUI.HONEY, _to_title)
	_menu_button(col, "Esci dal gioco", CozyUI.DANGER, _quit)

	# --- il pannello impostazioni (nascosto finché non serve) ---
	_settings = CozySettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(func(): _show_settings(false))
	center.add_child(_settings)


func _menu_button(col: VBoxContainer, text: String, accent: Color, cb: Callable) -> void:
	var b := CozyUI.cozy_button(text, accent, 19)
	b.custom_minimum_size = Vector2(320, 54)
	b.pressed.connect(cb)
	col.add_child(b)


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
