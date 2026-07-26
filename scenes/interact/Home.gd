extends Node

## "Casa" del giocatore: vicino a un letto premi H e quel letto diventa
## casa tua — un cuoricino ci fluttua sopra, e al prossimo avvio ti
## sveglierai lì. Una casa sola per volta: impostarne un'altra sposta il
## cuore. I letti reclamati dai villager non si possono rubare.

const UI_BROWN := Color("6a4a3a")

var home_cell := Vector2i(9999, 9999)

var _player: Node3D
var _build: Node3D
var _sfx
var _marker: Node3D
var _toast: PanelContainer
var _toast_label: Label
var _spawn_applied := false


func _ready() -> void:
	add_to_group("home_system")
	add_to_group("persistable")
	_player = get_node("%Player")
	_build = get_node("../BuildSystem")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_ui()


func has_home() -> bool:
	return home_cell != Vector2i(9999, 9999)


func is_home(cell: Vector2i) -> bool:
	return has_home() and cell == home_cell


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("set_home"):
		return
	# il letto più vicino, a portata di zampa
	var best: Node3D = null
	var best_d := 1.6
	for bed in _build.get_placed_by_name("Letto"):
		var d: float = _player.global_position.distance_to((bed as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = bed
	if best == null:
		return
	var cell := Vector2i(roundi(best.position.x), roundi(best.position.z))
	# i letti dei villager sono loro
	var visitors := get_node_or_null("../Visitors")
	if visitors and visitors.call("is_bed_claimed", cell):
		_show_toast("Questo lettino è di qualcun altro!")
		return
	if is_home(cell):
		_show_toast("È già casa tua!")
		return
	home_cell = cell
	_place_marker(best)
	_show_toast("Casa impostata: è qui che ti sveglierai!")
	if _sfx:
		_sfx.place_ok()
	_build.request_save()
	get_viewport().set_input_as_handled()


# cuoricino che fluttua sopra il letto di casa
func _place_marker(bed: Node3D) -> void:
	if _marker and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = Node3D.new()
	var pink := StandardMaterial3D.new()
	pink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pink.albedo_color = Color(1.0, 0.55, 0.68, 0.95)
	pink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for side: float in [-1.0, 1.0]:
		var b := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.1
		b.mesh = sm
		b.material_override = pink
		b.position = Vector3(side * 0.037, 0.03, 0)
		_marker.add_child(b)
	var tip := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.075
	cm.height = 0.1
	tip.mesh = cm
	tip.material_override = pink
	tip.position = Vector3(0, -0.035, 0)
	tip.rotation.x = PI
	_marker.add_child(tip)
	_marker.position = Vector3(0, 1.1, 0)
	bed.add_child(_marker)
	var bob := create_tween().set_loops()
	bob.tween_property(_marker, "position:y", 1.22, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_marker, "position:y", 1.1, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	if not has_home():
		return {}
	return {"home": [home_cell.x, home_cell.y]}


func load_extra(data: Dictionary) -> void:
	var h: Variant = data.get("home")
	if h is not Array or (h as Array).size() != 2:
		return
	home_cell = Vector2i(int(h[0]), int(h[1]))
	for bed in _build.get_placed_by_name("Letto"):
		var cell := Vector2i(roundi(bed.position.x), roundi(bed.position.z))
		if cell == home_cell:
			_place_marker(bed)
			# il risveglio: si riparte da casa propria
			if not _spawn_applied:
				_spawn_applied = true
				_player.global_position = (bed as Node3D).global_position + Vector3(0, 0, 1.0)
			return
	# il letto non esiste più: la casa decade con lui
	home_cell = Vector2i(9999, 9999)


# ---------------------------------------------------------------- UI

func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.reset_size()
	_toast.modulate.a = 0.0
	_toast.visible = true
	var vp_w := get_viewport().get_visible_rect().size.x
	_toast.position = Vector2(vp_w * 0.5 - _toast.size.x * 0.5, 64)
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): _toast.visible = false)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_toast = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.99, 0.96, 0.9, 0.96)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(0.62, 0.46, 0.34, 0.5)
	sb.set_border_width_all(2)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	_toast.add_theme_stylebox_override("panel", sb)
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_toast)
	_toast_label = Label.new()
	_toast_label.add_theme_font_size_override("font_size", 15)
	_toast_label.add_theme_color_override("font_color", Color("8a5a3a"))
	_toast.add_child(_toast_label)
