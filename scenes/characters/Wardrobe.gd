extends Node3D

## Il guardaroba di Mochi. Ogni capo è un RICORDO indossabile: si
## sblocca vivendo, non comprando — il cappello di petali con la prima
## fioritura, la lanterna-lucciola da polso con la prima lucciola in
## collezione, la sciarpina di lana coi regali del passerotto,
## l'impermeabilino giallo con la prima pioggia (e indossarlo sotto la
## pioggia la rende FELICE: scintille dorate ai piedi). G apre il
## guardaroba; i residenti vicini commentano il vestito nuovo in
## Chibiese («wa-wi!»). Tutto persistito nel JSON.

const HANDPAINT := preload("res://shaders/handpaint.gdshader")
const UI_BROWN := Color("6a4a3a")

# id -> {nome, slot, sblocco (racconto), icona}
const CAPI := {
	"cappello_petali": {"nome": "il cappello di petali", "slot": "testa",
		"sblocco": "la prima fioritura del giardino", "icona": "✿"},
	"lanterna_lucciola": {"nome": "la lanterna-lucciola da polso", "slot": "polso",
		"sblocco": "una lucciola in collezione", "icona": "●"},
	"sciarpina_lana": {"nome": "la sciarpina di lana", "slot": "collo",
		"sblocco": "un regalino del passerotto", "icona": "~"},
	"impermeabilino": {"nome": "l'impermeabilino giallo", "slot": "corpo",
		"sblocco": "la prima pioggerella vissuta", "icona": "☂"},
}
const ORDER := ["cappello_petali", "lanterna_lucciola", "sciarpina_lana", "impermeabilino"]

var _player: Node3D
var _mochi: Node3D
var _weather: Node
var _build: Node3D
var _sfx

var _unlocked := {}
var _worn := {}          # id -> nodo indossato
# i RICORDINI di chi è partito per il Grande Prato (Fase 5 del Filo
# Rosso): capi dinamici, uno per partenza, tinti col SUO colore.
# id "ricordo_<nome>" -> {"nome": testo, "colore": html}
var _ricordi := {}
var _was_raining := false
var _rain_joy := 0.0
var _lantern_light: OmniLight3D
var _daynight: Node3D

var _open := false
var _panel: PanelContainer
var _rows: VBoxContainer


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("guardaroba")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_ui()
	(func():
		# i nodi creati a runtime non risolvono %Player: percorso esplicito
		_player = get_node_or_null("../../Player")
		_mochi = _player.get_node_or_null("Mochi") if _player else null
		_weather = get_node_or_null("../../Weather")
		_daynight = get_node_or_null("../../DayNight")
		_build = get_tree().get_first_node_in_group("build_system")).call_deferred()


## La scheda di un capo: dal catalogo fisso o dai ricordini dinamici.
func _capo_info(id: String) -> Dictionary:
	if CAPI.has(id):
		return CAPI[id]
	if _ricordi.has(id):
		var r: Dictionary = _ricordi[id]
		return {"nome": str(r["nome"]), "slot": "collo", "icona": "❀",
				"sblocco": ""}
	return {}


## Tutti i capi nell'ordine del pannello: prima il catalogo, poi i
## ricordini (in ordine stabile).
func _ordine() -> Array:
	var out: Array = ORDER.duplicate()
	var ricordi: Array = _ricordi.keys()
	ricordi.sort()
	out.append_array(ricordi)
	return out


## Il ricordino di chi è partito: entra nel guardaroba già sbloccato,
## col suo colore. Quando Mochi lo indossa, i vicini si fermano: «mi-ka…».
func unlock_ricordo(nome: String, colore: Color) -> void:
	var id := "ricordo_" + nome
	if _unlocked.has(id):
		return
	_ricordi[id] = {"nome": "il ricordino di %s" % nome,
			"colore": colore.to_html(false)}
	_unlocked[id] = true
	_toast("Nel guardaroba c'è il ricordino di %s, piegato con cura. (G)" % nome)
	if _sfx:
		_sfx.build_open()
	if _build:
		_build.request_save()


## Sblocca un capo (se è nuovo): toast, scintille, campanellino.
func unlock(id: String) -> void:
	if _unlocked.has(id) or not CAPI.has(id):
		return
	_unlocked[id] = true
	var capo: Dictionary = CAPI[id]
	_toast("Nuovo capo nel guardaroba: %s! (G per indossarlo)" % capo["nome"])
	if _mochi:
		var gtree := get_tree().get_first_node_in_group("grande_albero")
		if gtree:
			gtree.call("_sparkle", _player.global_position + Vector3(0, 1.2, 0), 14)
	if _sfx:
		_sfx.build_open()
	if _build:
		_build.request_save()


func _toggle_wear(id: String) -> void:
	if not _unlocked.has(id):
		return
	if _worn.has(id):
		_unwear(id)
	else:
		# un capo per slot: il nuovo scalza il vecchio
		for other in _worn.keys():
			if _capo_info(other)["slot"] == _capo_info(id)["slot"]:
				_unwear(other)
		_wear(id)
		if id.begins_with("ricordo_"):
			_compliments_ricordo()
		else:
			_compliments()
	if _sfx:
		_sfx.ui_select()
	if _build:
		_build.request_save()
	_refresh_panel()


func _wear(id: String) -> void:
	if _mochi == null or _worn.has(id) or _capo_info(id).is_empty():
		return
	var node := _build_capo(id)
	var mount: Node3D = _mochi.call("get_attach_point", _capo_info(id)["slot"])
	mount.add_child(node)
	_worn[id] = node
	node.scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _unwear(id: String) -> void:
	var node: Node3D = _worn.get(id)
	if node and is_instance_valid(node):
		node.queue_free()
	_worn.erase(id)
	if id == "lanterna_lucciola":
		_lantern_light = null


# il ricordino addosso: i vicini si fermano, sottovoce — «mi-ka…» (amico)
func _compliments_ricordo() -> void:
	var visitors := get_node_or_null("../../Visitors")
	if visitors == null or _player == null:
		return
	for r in visitors.get("_residents"):
		var node := r.get("node") as Node3D
		if node and is_instance_valid(node) and not node.call("is_hidden") \
				and node.global_position.distance_to(_player.global_position) < 6.0:
			node.call("face_towards", _player.global_position)
			node.call("speak", ["amico"], "triste")
			node.call("chat_bubble", "…")


# i residenti vicini si voltano e commentano: «wa-wi!»
func _compliments() -> void:
	var visitors := get_node_or_null("../../Visitors")
	if visitors == null or _player == null:
		return
	for r in visitors.get("_residents"):
		var node := r.get("node") as Node3D
		if node and is_instance_valid(node) and not node.call("is_hidden") \
				and node.global_position.distance_to(_player.global_position) < 6.0:
			node.call("face_towards", _player.global_position)
			node.call("speak", ["felice", "~"], "felice")
			node.call("_spawn_heart")


# ---------------------------------------------------------------- i capi

func _pm(a: Color, b: Color, grain := 5.0, amount := 0.5) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = HANDPAINT
	mat.set_shader_parameter("color_a", a)
	mat.set_shader_parameter("color_b", b)
	mat.set_shader_parameter("noise_scale", grain)
	mat.set_shader_parameter("noise_amount", amount)
	# gli accessori indossati non si coprono di neve d'inverno (i vestiti
	# di Mochi restano suoi: la neve è del mondo, non dei personaggi)
	mat.set_shader_parameter("no_snow", true)
	return mat


func _ball(parent: Node3D, r: float, mat: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 9
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _build_capo(id: String) -> Node3D:
	var n := Node3D.new()
	match id:
		"cappello_petali":
			# coroncina di petali sulla testolina, col cuoricino giallo
			n.position = Vector3(0, 0.36, 0.0)
			n.rotation.z = -0.08
			var petal := _pm(Color("f7bcd2"), Color("eba4be"), 6.0, 0.45)
			var petal2 := _pm(Color("fff2f7"), Color("f2dce8"), 6.0, 0.45)
			for i in 8:
				var a := float(i) / 8.0 * TAU
				var p := _ball(n, 0.088, petal if i % 2 == 0 else petal2,
						Vector3(cos(a) * 0.27, sin(a * 3.0) * 0.015, sin(a) * 0.27),
						Vector3(1.2, 0.5, 0.85))
				p.rotation.y = -a
				p.rotation.x = 0.2
			_ball(n, 0.055, _pm(Color("ffd76e"), Color("eec254")), Vector3(0, 0.1, -0.24))
		"lanterna_lucciola":
			# il barattolino da polso: dentro, una lucciola vera che pulsa
			# (segue il polso delle braccine accorciate)
			n.position = Vector3(0, -0.32, -0.06)
			var metal := _pm(Color("8a7f72"), Color("6f665b"), 4.0, 0.4)
			var ring := TorusMesh.new()
			ring.inner_radius = 0.075
			ring.outer_radius = 0.095
			var rmi := MeshInstance3D.new()
			rmi.mesh = ring
			rmi.material_override = metal
			rmi.rotation.x = PI * 0.5
			n.add_child(rmi)
			var glass := StandardMaterial3D.new()
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.albedo_color = Color(0.85, 0.95, 0.9, 0.3)
			_ball(n, 0.058, glass, Vector3(0, -0.095, 0), Vector3(1, 1.25, 1))
			var glow := StandardMaterial3D.new()
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.albedo_color = Color("d8ffa0")
			glow.emission_enabled = true
			glow.emission = Color(0.75, 1.0, 0.45)
			glow.emission_energy_multiplier = 1.4
			_ball(n, 0.02, glow, Vector3(0, -0.095, 0))
			_ball(n, 0.028, metal, Vector3(0, -0.02, 0), Vector3(1, 0.5, 1))
			_lantern_light = OmniLight3D.new()
			_lantern_light.light_color = Color(0.8, 1.0, 0.55)
			_lantern_light.omni_range = 3.0
			_lantern_light.light_energy = 0.0
			_lantern_light.shadow_enabled = false
			_lantern_light.position = Vector3(0, -0.095, 0)
			n.add_child(_lantern_light)
		"sciarpina_lana":
			# lana calda a girocollo, coi lembi che ricadono e le frange
			n.position = Vector3(0, 0.6, 0)
			var wool := _pm(Color("d97a6a"), Color("c26454"), 7.0, 0.6)
			var wrap_mesh := TorusMesh.new()
			wrap_mesh.inner_radius = 0.19
			wrap_mesh.outer_radius = 0.31
			var wmi := MeshInstance3D.new()
			wmi.mesh = wrap_mesh
			wmi.material_override = wool
			wmi.scale = Vector3(1, 0.8, 1)
			n.add_child(wmi)
			var tail := _ball(n, 0.08, wool, Vector3(0.12, -0.13, -0.26), Vector3(0.8, 1.7, 0.45))
			tail.rotation.z = 0.15
			var tail2 := _ball(n, 0.065, wool, Vector3(-0.05, -0.07, -0.27), Vector3(0.75, 1.2, 0.42))
			tail2.rotation.z = -0.12
			for i in 3:
				_ball(n, 0.02, wool, Vector3(0.08 + i * 0.032, -0.27, -0.26), Vector3(0.6, 1.6, 0.6))
		"impermeabilino":
			# mantellina gialla col cappuccio ripiegato e i bottoni
			var rain_mat := _pm(Color("ffd35c"), Color("f0bc42"), 4.0, 0.4)
			var cape := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.21
			cm.bottom_radius = 0.43
			cm.height = 0.56
			cape.mesh = cm
			cape.material_override = rain_mat
			cape.position = Vector3(0, 0.42, 0)
			n.add_child(cape)
			# cappuccio ripiegato dietro le spalle
			_ball(n, 0.15, rain_mat, Vector3(0, 0.64, 0.22), Vector3(1.25, 0.7, 0.85))
			var btn := _pm(Color("fff3e0"), Color("efe2cc"), 5.0, 0.3)
			for i in 3:
				_ball(n, 0.024, btn, Vector3(0, 0.58 - i * 0.12, -0.31 + i * 0.05))
		_:
			if id.begins_with("ricordo_") and _ricordi.has(id):
				# il ricordino: un fiocchetto col campanellino, al collo,
				# tinto col colore del vestitino di chi è partito
				n.position = Vector3(0, 0.58, -0.26)
				var c := Color(str((_ricordi[id] as Dictionary)["colore"]))
				var nastro := _pm(c, c.darkened(0.2), 6.0, 0.45)
				for lato: float in [-1.0, 1.0]:
					var ala := _ball(n, 0.055, nastro,
							Vector3(lato * 0.055, 0.01, 0), Vector3(1.5, 0.75, 0.5))
					ala.rotation.z = lato * 0.35
				_ball(n, 0.028, nastro, Vector3.ZERO, Vector3(0.9, 0.9, 0.7))
				var oro := _pm(Color("ffd76e"), Color("eec254"), 4.0, 0.35)
				_ball(n, 0.022, oro, Vector3(0, -0.055, 0))
	return n


# ---------------------------------------------------------------- vita

func _process(delta: float) -> void:
	# la lanterna-lucciola si accende col buio
	if _lantern_light and _daynight:
		var target := 1.1 if _daynight.is_night() else 0.0
		_lantern_light.light_energy = lerpf(_lantern_light.light_energy, target,
				1.0 - exp(-3.0 * delta))

	# la prima pioggia sblocca l'impermeabilino; indossarlo la fa felice
	var raining: bool = _weather != null and _weather.is_raining()
	if raining and not _was_raining:
		unlock("impermeabilino")
	_was_raining = raining
	if raining and _worn.has("impermeabilino") and _player:
		_rain_joy -= delta
		if _rain_joy <= 0.0:
			_rain_joy = randf_range(2.5, 4.5)
			var gtree := get_tree().get_first_node_in_group("grande_albero")
			if gtree:
				gtree.call("_sparkle", _player.global_position + Vector3(0, 0.3, 0), 8)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("guardaroba"):
		_open = not _open
		_panel.visible = _open
		if _player:
			_player.set_physics_process(not _open)
			if _open:
				_player.velocity = Vector3.ZERO
		if _open:
			_refresh_panel()
		if _sfx:
			if _open:
				_sfx.build_open()
			else:
				_sfx.build_close()
		get_viewport().set_input_as_handled()
	elif _open and event is InputEventKey and event.pressed and not event.is_echo():
		var idx: int = (event as InputEventKey).keycode - KEY_1
		var ordine := _ordine()
		if idx >= 0 and idx < ordine.size():
			_toggle_wear(str(ordine[idx]))
			get_viewport().set_input_as_handled()


func _refresh_panel() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var ordine := _ordine()
	for i in ordine.size():
		var id := str(ordine[i])
		var capo := _capo_info(id)
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 13)
		if _unlocked.has(id):
			var stato := "indossato ♥" if _worn.has(id) else "nel baule"
			row.text = "%d.  %s  %s   —   %s" % [i + 1, capo["icona"], capo["nome"], stato]
			row.add_theme_color_override("font_color",
					Color("a83a5c") if _worn.has(id) else UI_BROWN)
		else:
			row.text = "%d.  ?  un ricordo da vivere: %s" % [i + 1, capo["sblocco"]]
			row.add_theme_color_override("font_color", Color(UI_BROWN, 0.4))
		_rows.add_child(row)


func _toast(text: String) -> void:
	var visitors := get_node_or_null("../../Visitors")
	if visitors:
		visitors.call("_show_toast", text)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_panel = PanelContainer.new()
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color("fdf6e3")
	ms.set_corner_radius_all(16)
	ms.border_color = Color(0.62, 0.46, 0.34, 0.55)
	ms.set_border_width_all(2)
	ms.shadow_color = Color(0.25, 0.15, 0.1, 0.3)
	ms.shadow_size = 12
	ms.content_margin_left = 26.0
	ms.content_margin_right = 26.0
	ms.content_margin_top = 16.0
	ms.content_margin_bottom = 16.0
	_panel.add_theme_stylebox_override("panel", ms)
	_panel.custom_minimum_size = Vector2(430, 0)
	_panel.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	center.add_child(_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)
	var title := Label.new()
	title.text = "~ Il guardaroba di Mochi ~"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("8a5a3a"))
	vbox.add_child(title)
	var sub := Label.new()
	sub.text = "ogni capo è un ricordo indossabile"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color("c25a7a"))
	vbox.add_child(sub)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	vbox.add_child(_rows)
	var hint := Label.new()
	hint.text = "1-4 — indossa/togli  ·  G — chiudi"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(UI_BROWN, 0.55))
	vbox.add_child(hint)


# ---------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	return {"wardrobe": {"unlocked": _unlocked.keys(), "worn": _worn.keys(),
			"ricordi": _ricordi}}


func load_extra(data: Dictionary) -> void:
	var w: Dictionary = data.get("wardrobe", {})
	if w.is_empty():
		return
	# i ricordini PRIMA degli sblocchi: gli id "ricordo_*" esistono solo
	# se la loro scheda (nome, colore) è tornata dal salvataggio
	var ric: Variant = w.get("ricordi")
	if ric is Dictionary:
		_ricordi = ric
	# solo id che esistono nel catalogo (o tra i ricordini): un salvataggio
	# di un'altra versione non fa saltare il ripristino
	for id in w.get("unlocked", []):
		if CAPI.has(str(id)) or _ricordi.has(str(id)):
			_unlocked[str(id)] = true
	(func():
		for id in w.get("worn", []):
			if _unlocked.has(str(id)) and not _capo_info(str(id)).is_empty():
				_wear(str(id))).call_deferred()


# ---------------------------------------------------------------- debug CLI

func debug_unlock_all() -> void:
	for id in ORDER:
		_unlocked[id] = true


func debug_wear(id: String) -> void:
	_unlocked[id] = true
	_wear(id)


func debug_strip() -> void:
	for id in _worn.keys():
		_unwear(id)


func debug_open_panel() -> void:
	_open = true
	_refresh_panel()
	_panel.visible = true


func debug_close_panel() -> void:
	_open = false
	_panel.visible = false
	if _player:
		_player.set_physics_process(true)
