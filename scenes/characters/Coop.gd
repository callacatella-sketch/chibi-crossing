extends Node

## Co-op sul divano. F2 e accanto a Mochi sboccia un secondo chibi —
## generato dal DNA la prima volta e POI SEMPRE LUI: l'amico del divano
## ha un'identità stabile, salvata nel villaggio. Si muove con IJKL,
## e con U aiuta davvero nel giardino: pianta, annaffia (gratis: gli
## ospiti non consumano la tua borraccia) e raccoglie nella stessa
## dispensa. Costruire in due lo stesso giardino, appunto.
## Se si perde, torna con uno sbuffo accanto a Mochi.

const DNA_GEN := preload("res://scenes/npc/ChibiDNA.gd")
const BUILDER := preload("res://scenes/npc/ChibiBuilder.gd")
const CHIBIESE := preload("res://audio/Chibiese.gd")
const FACE := preload("res://scenes/characters/FaceController.gd")

var _player: Node3D
var _garden: Node
var _sfx
var _dna := {}
var _voice := {}

var _p2: CharacterBody3D
var _vis: Node3D
var _parts := {}
var _t := 0.0
var _wag_t := 0.0
var _yaw := 0.0
var _babble_cd := 20.0
var _voice_player: AudioStreamPlayer3D
var _prompt: PanelContainer
var _prompt_label: Label
# il volto vivo dell'amico del divano
var _face
var _coop_mood := "neutro"


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("coop")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_ui()
	(func():
		_player = get_node_or_null("../../Player")
		_garden = get_node_or_null("../../Garden")).call_deferred()


func is_active() -> bool:
	return _p2 != null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("coop_toggle"):
		if _p2:
			_leave()
		else:
			_join()
		get_viewport().set_input_as_handled()
	elif _p2 and event.is_action_pressed("p2_action"):
		_help_garden()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- arrivo

func _join() -> void:
	# la prima volta nasce dal DNA; poi è sempre lo stesso amico
	if _dna.is_empty():
		_dna = DNA_GEN.generate()
	_voice = CHIBIESE.voice(_dna)

	_p2 = CharacterBody3D.new()
	_p2.floor_max_angle = deg_to_rad(72.0)
	_p2.floor_snap_length = 0.5
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 0.95
	shape.shape = cap
	shape.position = Vector3(0, 0.5, 0)
	_p2.add_child(shape)

	_vis = Node3D.new()
	_p2.add_child(_vis)
	_parts = BUILDER.build(_dna)
	_vis.add_child(_parts["root"])
	# il volto vivo: espressioni, sguardo, ammicco
	if _parts.has("face"):
		var rig: Dictionary = _parts["face"]
		rig["head"] = _parts["head"]
		_face = FACE.new()
		_face.setup(rig)

	_voice_player = AudioStreamPlayer3D.new()
	_voice_player.position = Vector3(0, 0.8, 0)
	_voice_player.max_distance = 16.0
	_voice_player.volume_db = -7.0
	_p2.add_child(_voice_player)

	get_parent().add_child(_p2)
	var side := Vector3(0.9, 0, 0.3)
	_p2.global_position = (_player.global_position + side) if _player else side
	_yaw = 0.0

	# sboccia con lo sbuffo e saluta: «ya-ho, mi-ka!»
	_vis.scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(_vis, "scale", Vector3.ONE, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_speak(["ciao", "amico"], "felice")
	if _sfx:
		_sfx.place_ok()
	_toast("%s si siede accanto a te! (IJKL muove · U aiuta in giardino · F2 saluta)" % _dna["label"])
	var build := get_tree().get_first_node_in_group("build_system")
	if build:
		build._save_village()


func _leave() -> void:
	_speak(["ciao"], "triste")
	_toast("%s ti saluta con la zampina. A presto!" % _dna["label"])
	var body := _p2
	var visual := _vis
	_p2 = null
	_vis = null
	_prompt.visible = false
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3.ONE * 0.03, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(body.queue_free)
	if _sfx:
		_sfx.build_close()


func _toast(text: String) -> void:
	var visitors := get_node_or_null("../../Visitors")
	if visitors:
		visitors.call("_show_toast", text)


func _speak(concepts: Array, mood := "neutro") -> void:
	_coop_mood = mood
	if _voice.is_empty() or _voice_player == null or _voice_player.playing:
		return
	_voice_player.stream = CHIBIESE.say(_voice, concepts, mood)
	_voice_player.play()


# ---------------------------------------------------------------- movimento

func _physics_process(delta: float) -> void:
	if _p2 == null:
		return
	_t += delta
	var dir := Input.get_vector("p2_left", "p2_right", "p2_up", "p2_down")
	var vel := _p2.velocity
	var speed := 3.0
	if dir.length() > 0.0:
		vel.x = dir.x * speed
		vel.z = dir.y * speed
	else:
		vel.x = move_toward(vel.x, 0.0, speed)
		vel.z = move_toward(vel.z, 0.0, speed)
	if not _p2.is_on_floor():
		vel.y -= 9.8 * delta
	else:
		vel.y = 0.0
	_p2.velocity = vel
	_p2.move_and_slide()

	# se l'amico si perde oltre lo schermo condiviso, torna con uno sbuffo
	if _player and _p2.global_position.distance_to(_player.global_position) > 14.0:
		_p2.global_position = _player.global_position + Vector3(0.9, 0.1, 0.3)
		_poof(_p2.global_position + Vector3(0, 0.4, 0))

	_animate(delta, Vector2(vel.x, vel.z).length())


# la camminata chibi: saltello, dondolio, braccine, orecchie e coda
func _animate(delta: float, speed: float) -> void:
	var moving := speed > 0.2
	if moving:
		var v := _p2.velocity
		_yaw = lerp_angle(_yaw, atan2(-v.x, -v.z), 1.0 - exp(-9.0 * delta))
	_vis.rotation.y = _yaw
	var hop := absf(sin(_t * 8.0)) if moving else 0.0
	_vis.position.y = hop * 0.05
	_vis.rotation.z = sin(_t * 8.0) * 0.05 if moving else sin(_t * 1.1) * 0.015
	var arms: Array = _parts.get("arms", [])
	if arms.size() == 2:
		var swing := sin(_t * 8.0) * 0.45 if moving else sin(_t * 2.0) * 0.06
		(arms[0] as Node3D).rotation.x = swing
		(arms[1] as Node3D).rotation.x = -swing
	# i piedini trottano in controfase; da fermo tornano a posto piano
	var legs: Array = _parts.get("legs", [])
	for li in legs.size():
		var gamba := legs[li] as Node3D
		if moving:
			var pp := _t * 8.0 + (0.0 if li == 0 else PI)
			gamba.rotation.x = -sin(pp) * 0.6
			gamba.position.y = 0.16 + maxf(0.0, cos(pp)) * 0.05
		else:
			gamba.rotation.x = lerpf(gamba.rotation.x, 0.0, 0.18)
			gamba.position.y = lerpf(gamba.position.y, 0.16, 0.18)
	for ear in _parts.get("ears", []):
		(ear as Node3D).rotation.x = -hop * 0.22
	_wag_t += delta * (1.7 + 3.4 * (1.0 if moving else 0.0))
	var tail := _parts.get("tail") as Node3D
	if tail:
		tail.rotation.y = sin(_wag_t) * 0.32
	var tip := _parts.get("tail_tip") as Node3D
	if tip:
		tip.rotation.y = sin(_wag_t - 0.9) * 0.27

	# --- il volto vivo: sorride camminando, recita l'umore mentre parla,
	# tiene d'occhio Mochi quando le è vicino ---
	if _face:
		if _voice_player and _voice_player.playing:
			_face.set_talking(true)
			_face.set_mood(_coop_mood)
		else:
			_face.set_talking(false)
			_face.set_expression("felice" if moving else "neutro", 0.5 if moving else 1.0)
		if _player and is_instance_valid(_player) \
				and _p2.global_position.distance_to(_player.global_position) < 4.0:
			_face.look_at_node(_player)
		else:
			_face.clear_gaze()
		_face.update(delta)

	# chiacchiericcio affettuoso quando i due sono vicini
	_babble_cd -= delta
	if _babble_cd <= 0.0 and _player \
			and _p2.global_position.distance_to(_player.global_position) < 2.0:
		_babble_cd = randf_range(18.0, 30.0)
		_speak(["~", "felice"], "felice")

	_update_prompt()


# ---------------------------------------------------------------- giardino

# U vicino a un'aiuola: l'ospite pianta, annaffia o raccoglie
func _help_garden() -> void:
	if _garden == null or _p2 == null:
		return
	var bed: Node3D = _garden.call("nearest_bed", _p2.global_position, 1.4)
	if bed == null:
		return
	_garden.call("guest_help", bed)
	_speak(["fiore", "felice"], "felice")


func _update_prompt() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _p2 == null or _garden == null:
		_prompt.visible = false
		return
	var bed: Node3D = _garden.call("nearest_bed", _p2.global_position, 1.4)
	if bed == null:
		_prompt.visible = false
		return
	var wp: Vector3 = _p2.global_position + Vector3(0, 1.1, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = "U — %s aiuta in giardino" % _dna.get("name", "l'amico")
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _poof(pos: Vector3) -> void:
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 80.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0, 0.5, 0)
	var burst := GPUParticles3D.new()
	burst.amount = 10
	burst.lifetime = 0.7
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.local_coords = false
	burst.process_material = pm
	burst.draw_pass_1 = quad
	burst.position = pos
	get_parent().add_child(burst)
	burst.emitting = true
	get_tree().create_timer(1.2).timeout.connect(burst.queue_free)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_prompt = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.95, 0.88, 0.92)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(0.62, 0.46, 0.34, 0.5)
	sb.set_border_width_all(2)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	_prompt.add_theme_stylebox_override("panel", sb)
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_prompt)
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 13)
	_prompt_label.add_theme_color_override("font_color", Color("6a4a3a"))
	_prompt.add_child(_prompt_label)


# ---------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	if _dna.is_empty():
		return {}
	return {"coop_dna": _dna}


func load_extra(data: Dictionary) -> void:
	var d: Variant = data.get("coop_dna")
	if d is Dictionary and not (d as Dictionary).is_empty():
		_dna = d


# ---------------------------------------------------------------- debug CLI

func debug_join(seed_v: int, pos: Vector3) -> void:
	if _p2:
		return
	_dna = DNA_GEN.generate(seed_v)
	_join()
	_p2.global_position = pos


func debug_help() -> void:
	_help_garden()
