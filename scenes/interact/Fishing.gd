extends Node

## La pesca allo stagno, alla Animal Crossing ma senza fallimenti: sulla
## sponda "E — pesca" fa apparire la canna, il galleggiante vola in un
## arco e ammara col bloop e l'anello nell'acqua; dopo un po' i cerchi
## si stringono, il galleggiante affonda — "E — tira!" — e il pesciolino
## salta fuori tra gli spruzzi, dritto nella collezione. Se non tiri in
## tempo, il pesce ribussa: qui nessuno scappa mai. Allontanarsi riavvolge.

const CRIT := preload("res://scenes/world/Critters.gd")
const UI_BROWN := Color("6a4a3a")

var _player: Node3D
var _mochi: Node3D
var _cozy: Node3D
var _collection: Node
var _sfx

var _state := "off"      # off | wait | bite
var _rod: Node3D
var _line: MeshInstance3D
var _bobber: Node3D
var _bob_home := Vector3.ZERO
var _cast_from := Vector3.ZERO
var _timer := 0.0
var _t := 0.0

# la preda di QUESTO lancio: decisa all'ammaraggio (non allo strattone),
# così sotto l'acqua può nuotare la sua ombra — grande se la specie è rara
var _kind := ""
var _shadow: Node3D
var _bussate := 0        # il raro bussa due volte prima di abboccare davvero

# DA CHE ACQUA si pesca: lo stagno (dalla sponda) o il FIUME (dalla
# barchetta). _wl è la quota della superficie: tutto il rito — galleggiante,
# tuffi, bussate, ombra — è espresso come scarto da _wl, così lo stesso
# rituale vale per le due acque (lo stagno a 0.06, il fiume a -0.45).
var _fiume := false
var _wl := 0.06

var _prompt: PanelContainer
var _prompt_label: Label


func _ready() -> void:
	_player = get_node("%Player")
	_mochi = _player.get_node("Mochi")
	_cozy = get_node_or_null("../CozyWorld")
	_collection = get_node_or_null("../Collection")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_ui()


func _pond_center() -> Vector3:
	return _cozy.POND_CENTER if _cozy else Vector3.ZERO


func _near_shore() -> bool:
	if _cozy == null:
		return false
	var d: float = _player.global_position.distance_to(_pond_center())
	return d > _cozy.POND_R - 0.4 and d < _cozy.POND_R + 2.2


# la barchetta sul fiume: se Mochi è a bordo, la canna pesca dal FIUME
func _barchetta() -> Node:
	return get_tree().get_first_node_in_group("barchetta")


func _in_barca() -> bool:
	var b := _barchetta()
	return b != null and bool(b.call("naviga_attiva"))


# ---------------------------------------------------------------- ciclo

func _process(delta: float) -> void:
	_t += delta
	match _state:
		"wait":
			_timer -= delta
			if _bobber:
				_bobber.position.y = _wl + 0.03 + sin(_t * 2.4) * 0.015
			_drift_shadow(delta)
			if _timer <= 0.0:
				_start_bite()
			_check_walked_away()
		"bite":
			_timer -= delta
			if _timer <= 0.0:
				# il pesce non scappa: riprende a bussare tra poco
				_state = "wait"
				_timer = randf_range(2.0, 3.5)
			_check_walked_away()
	_update_line()
	_update_prompt()


func _check_walked_away() -> void:
	# dalla barca si pesca anche ALLA DERIVA: la corrente porta Mochi e la
	# lenza si distende — il punto di lancio la segue, mai un riavvolgimento
	if _in_barca():
		_cast_from = _player.global_position
		return
	if _player.global_position.distance_to(_cast_from) > 1.2:
		_cleanup()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	# player congelato da un pannello (tasche, negozio, lavagna…): la E è del
	# pannello — niente lanci di canna col menu aperto
	if _player == null or not _player.is_physics_processing():
		return
	match _state:
		"off":
			# una farfalla o lucciola a portata di retino ha la precedenza
			# sulla canna: niente prompt in conflitto sulla sponda
			if _collection and not (_collection.call("_nearest_catch") as Dictionary).is_empty():
				return
			if _near_shore():
				_cast(false)
				get_viewport().set_input_as_handled()
			elif _in_barca():
				_cast(true)
				get_viewport().set_input_as_handled()
		"bite":
			_catch()
			get_viewport().set_input_as_handled()
		"wait":
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- lancio

func _cast(fiume := false) -> void:
	_state = "cast"
	_cast_from = _player.global_position
	_fiume = fiume
	_wl = -0.45 if fiume else 0.06   # la superficie: fiume o stagno

	# Mochi guarda l'acqua: lo stagno dalla sponda, il corso dalla barca
	var bersaglio := _pond_center()
	if fiume:
		var barca := _barchetta()
		if barca:
			bersaglio = barca.call("punto_di_pesca", _player.global_position)
	var dir := ((bersaglio - _player.global_position) * Vector3(1, 0, 1)).normalized()
	_mochi.set("_yaw", atan2(-dir.x, -dir.z))

	# la canna NELLA zampa: eredita ogni movimento del braccio
	_rod = Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("a8794f")
	var stick := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.008
	sm.bottom_radius = 0.014
	sm.height = 0.72
	stick.mesh = sm
	stick.material_override = wood
	stick.position = Vector3(0, 0.36, 0)
	_rod.add_child(stick)
	_mochi.call("attach_to_paw", _rod)
	_rod.rotation.z = PI      # il manico prosegue oltre la zampa
	_rod.rotation.x = -0.5    # punta in avanti-alto rispetto al braccio
	_rod.scale = Vector3.ONE * 0.05
	_mochi.call("hold_rod", true)   # pour 0: caricata dietro la spalla

	# il filo
	var lm := CylinderMesh.new()
	lm.top_radius = 0.0035
	lm.bottom_radius = 0.0035
	lm.height = 1.0
	lm.radial_segments = 5
	_line = MeshInstance3D.new()
	_line.mesh = lm
	var lmat := StandardMaterial3D.new()
	lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lmat.albedo_color = Color(1, 1, 1, 0.7)
	lmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line.material_override = lmat
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)

	# il galleggiante vola in un arco e ammara
	_bobber = Node3D.new()
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("d9534f")
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("fff3e0")
	var bot := MeshInstance3D.new()
	var bmesh := SphereMesh.new()
	bmesh.radius = 0.038
	bmesh.height = 0.076
	bot.mesh = bmesh
	bot.material_override = red
	_bobber.add_child(bot)
	var top := MeshInstance3D.new()
	var tmesh := SphereMesh.new()
	tmesh.radius = 0.03
	tmesh.height = 0.06
	top.mesh = tmesh
	top.material_override = white
	top.position = Vector3(0, 0.032, 0)
	_bobber.add_child(top)
	add_child(_bobber)

	_bobber.visible = false

	# il LANCIO: la canna sboccia mentre il braccio carica dietro la
	# spalla (anticipazione), un respiro, e il COLPETTO in avanti —
	# solo allora il galleggiante vola via dalla punta
	var tw := create_tween()
	tw.tween_property(_rod, "scale", Vector3.ONE, 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.1)
	tw.tween_callback(func():
		if _sfx:
			_sfx.net_swish())
	tw.tween_property(_mochi, "pour", 1.0, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _launch_bobber(dir))


# il galleggiante parte dalla punta VIVA della canna e ammara col plop
func _launch_bobber(dir: Vector3) -> void:
	if _state != "cast" or _bobber == null:
		return
	_state = "wait"
	_timer = randf_range(2.5, 5.0)
	_bobber.visible = true
	var start: Vector3 = _rod.to_global(Vector3(0, 0.72, 0))
	# dal fiume il lancio è più corto: l'alveo è stretto, la lenza si
	# distende con la corrente
	var gittata := randf_range(1.3, 1.9) if _fiume else randf_range(2.2, 3.2)
	var target: Vector3 = _player.global_position + dir * gittata
	target.y = _wl + 0.03
	_bob_home = target
	_bobber.global_position = start
	_bob_tw = create_tween().set_parallel(true)
	var tw := _bob_tw
	tw.tween_property(_bobber, "global_position:x", target.x, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_bobber, "global_position:z", target.z, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_bobber, "global_position:y", start.y + 0.7, 0.26) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_bobber, "global_position:y", _wl + 0.03, 0.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		if _cozy and not _fiume:
			_cozy.water_ripple(_bob_home, 0.8)
		if _sfx:
			_sfx.plop()
		_spawn_preda())


func _update_line() -> void:
	if _line == null or _rod == null or _bobber == null:
		return
	if not _bobber.visible:
		_line.visible = false   # galleggiante ancora in canna: niente filo
		return
	var tip: Vector3 = _rod.to_global(Vector3(0, 0.72, 0))
	var bob: Vector3 = _bobber.global_position + Vector3(0, 0.04, 0)
	var mid := (tip + bob) * 0.5
	var dist := tip.distance_to(bob)
	if dist < 0.02:
		_line.visible = false  # look_at degenere al frame del lancio
		return
	_line.visible = true
	_line.global_position = mid
	_line.look_at(bob, Vector3.UP)
	_line.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	_line.scale = Vector3(1, maxf(dist, 0.01), 1)


# ---------------------------------------------------------------- la preda

## Quanto è larga l'ombra sotto l'acqua: la taglia È l'informazione. Il
## giocatore impara a leggerla — grande = specie rara — prima ancora che
## il galleggiante si muova. Pura: la verifica il test.
static func taglia_ombra(rara: bool) -> float:
	return 1.6 if rara else 0.9


## Il pesce si decide all'ammaraggio: da qui in poi l'acqua RACCONTA.
## L'ombra della preda scivola verso il galleggiante, e se la specie è
## rara busserà due volte prima di abboccare. Nessun fallimento, come
## sempre: solo lettura e attesa.
func _spawn_preda() -> void:
	_kind = _weighted_fish()
	_bussate = 2 if CRIT.rara(_kind) else 0
	_shadow = Node3D.new()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 20
	sm.rings = 8
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.12, 0.18, 0.22, 0.34)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(0.36, 0.045, 0.22)
	_shadow.add_child(mi)
	add_child(_shadow)
	var lato := randf_range(0.0, TAU)
	_shadow.scale = Vector3.ONE * taglia_ombra(CRIT.rara(_kind))
	_shadow.global_position = _bob_home \
			+ Vector3(cos(lato), 0, sin(lato)) * randf_range(1.2, 1.7)
	_shadow.global_position.y = _wl - 0.03
	_shadow.rotation.y = lato


# l'ombra ondeggia e si avvicina piano al galleggiante durante l'attesa
func _drift_shadow(delta: float) -> void:
	if _shadow == null:
		return
	var target := _bob_home + Vector3(sin(_t * 0.7) * 0.35, 0, cos(_t * 0.9) * 0.3)
	target.y = _wl - 0.03
	var prima := _shadow.global_position
	_shadow.global_position = prima.lerp(target, 1.0 - exp(-0.55 * delta))
	var passo := _shadow.global_position - prima
	if passo.length() > 0.0005:
		_shadow.rotation.y = atan2(-passo.z, passo.x)


func _free_shadow() -> void:
	if _shadow and is_instance_valid(_shadow):
		_shadow.queue_free()
	_shadow = null


# ---------------------------------------------------------------- abbocco

## La bussata del raro: il galleggiante trema appena, l'ombra guizza sotto
## e si ritrae. NON è l'abbocco — il prompt non appare: chi conosce lo
## stagno riconosce il saluto del pesce grosso e aspetta.
func _bussa() -> void:
	_timer = randf_range(1.4, 2.4)
	if _cozy and not _fiume:
		_cozy.water_ripple(_bob_home, 0.35)
	if _sfx:
		_sfx.play("plop", -17.0, 1.35)   # un tocco, non l'abbocco
	if _bobber:
		if _bob_tw and _bob_tw.is_valid():
			_bob_tw.kill()
		_bob_tw = create_tween()
		_bob_tw.tween_property(_bobber, "position:y", _wl - 0.015, 0.1) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_bob_tw.tween_property(_bobber, "position:y", _wl + 0.03, 0.25) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _shadow:
		var qui := _shadow.global_position
		var sotto := Vector3(_bob_home.x, _wl - 0.03, _bob_home.z)
		var tw := create_tween()
		tw.tween_property(_shadow, "global_position", sotto, 0.22) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(_shadow, "global_position", qui, 0.5) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_bite() -> void:
	# il pesce raro prima BUSSA (due volte): lo stato resta "wait" e il
	# prompt non compare — è il momento della lettura, non dello strattone
	if _bussate > 0:
		_bussate -= 1
		_bussa()
		return
	_state = "bite"
	_timer = 2.0
	if _shadow:
		var tw := create_tween()
		tw.tween_property(_shadow, "global_position",
				Vector3(_bob_home.x, _wl - 0.03, _bob_home.z), 0.15) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _cozy and not _fiume:
		_cozy.water_ripple(_bob_home, 0.55)
		get_tree().create_timer(0.35).timeout.connect(func():
			if _cozy and _state == "bite":
				_cozy.water_ripple(_bob_home, 0.4))
	if _sfx:
		_sfx.plop()
	if _bobber:
		if _bob_tw and _bob_tw.is_valid():
			_bob_tw.kill()
		_bob_tw = create_tween()
		var tw := _bob_tw
		tw.tween_property(_bobber, "position:y", _wl - 0.08, 0.12) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(_bobber, "position:y", _wl + 0.03, 0.3) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _weighted_fish() -> String:
	# chi abbocca lo decide il bestiario: le tre carpe di sempre più le specie
	# di stagione (il girino in primavera, il pesce ghiaccio d'inverno, la
	# carpa foglia d'oro d'autunno, il pesce dell'alba al crepuscolo). I pesi
	# stanno in Critters, accanto al prezzo: carpetta comune, rare preziose.
	# Le due ACQUE non si mescolano: dalla barchetta abboccano solo le specie
	# del fiume (la trota del salto, l'anguilla della notte), dallo stagno
	# solo le sue — disponibili_in fa la dogana.
	if _cozy and _cozy.has_method("contesto_critter"):
		var pool: Array = CRIT.disponibili_in("pesce",
				_cozy.call("contesto_critter"), _fiume)
		var kind := CRIT.estrai(pool, randf())
		if kind != "":
			return kind
	return "trota" if _fiume else "carpetta"


func _catch() -> void:
	# la preda è quella annunciata dall'ombra (il ripiego serve solo ai
	# vecchi salvataggi di debug in cui l'ombra non è mai nata)
	var kind := _kind if _kind != "" else _weighted_fish()
	_kind = ""
	_free_shadow()
	var col := CRIT.colore(kind)

	# lo STRATTONE: la canna scatta all'indietro col braccio, poi si
	# assesta con un molleggio — è il colpo che strappa il pesce all'acqua
	_state = "reel"
	var yank := create_tween()
	yank.tween_property(_mochi, "pour", 0.12, 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	yank.tween_property(_mochi, "pour", 0.8, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# il pesciolino salta fuori in un arco scintillante
	var fish := _make_fish(col)
	add_child(fish)
	fish.global_position = _bob_home
	if _cozy:
		_cozy.water_ripple(_bob_home, 1.3)
	if _sfx:
		_sfx.play("step_wet1", -12.0, 1.1)
	var dest: Vector3 = _player.global_position + Vector3(0, 1.0, 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(fish, "global_position:x", dest.x, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(fish, "global_position:z", dest.z, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(fish, "global_position:y", 1.6, 0.28) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(fish, "rotation:z", TAU, 0.5)
	tw.chain().tween_property(fish, "global_position:y", dest.y, 0.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		if _sfx:
			_sfx.place_ok()
		if _collection:
			_collection.add_catch(kind)
			_collection.call("_sparkle", dest, col)
		fish.queue_free())
	# la canna resta in zampa per tutto lo strattone, poi si ripone
	get_tree().create_timer(0.75).timeout.connect(_cleanup)


func _make_fish(col: Color) -> Node3D:
	var fish := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.07
	bm.height = 0.14
	body.mesh = bm
	body.material_override = mat
	body.scale = Vector3(1.5, 0.9, 0.7)
	fish.add_child(body)
	var tail := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.0
	tm.bottom_radius = 0.05
	tm.height = 0.08
	tail.mesh = tm
	tail.material_override = mat
	tail.position = Vector3(-0.12, 0, 0)
	tail.rotation.z = -PI * 0.5
	fish.add_child(tail)
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color("2a1d1d")
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.012
		em.height = 0.024
		eye.mesh = em
		eye.material_override = dark
		eye.position = Vector3(0.06, 0.02, side * 0.045)
		fish.add_child(eye)
	return fish


# il tween attivo sul galleggiante: da uccidere prima del queue_free,
# o continuerebbe a scrivere su un nodo morto
var _bob_tw: Tween


func _cleanup() -> void:
	_state = "off"
	if _bob_tw and _bob_tw.is_valid():
		_bob_tw.kill()
	_bob_tw = null
	if _mochi:
		_mochi.call("hold_rod", false)   # la presa si scioglie con calma
	for node in [_rod, _line, _bobber]:
		if node and is_instance_valid(node):
			node.queue_free()
	_rod = null
	_line = null
	_bobber = null
	_free_shadow()
	_kind = ""
	_bussate = 0
	_fiume = false
	_wl = 0.06


# ---------------------------------------------------------------- UI

func _update_prompt() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_prompt.visible = false
		return
	var text := ""
	var wp := Vector3.ZERO
	match _state:
		"off":
			if _near_shore():
				text = L10n.t("E — pesca")
				wp = _player.global_position + Vector3(0, 1.3, 0)
			elif _in_barca():
				text = L10n.t("E — pesca dal fiume")
				wp = _player.global_position + Vector3(0, 1.35, 0)
		"bite":
			text = L10n.t("E — tira!")
			wp = _bob_home + Vector3(0, 0.5, 0)
	if text == "" or cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = text
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
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
	_prompt_label.add_theme_color_override("font_color", UI_BROWN)
	_prompt.add_child(_prompt_label)


# ---------------------------------------------------------------- debug CLI

func debug_start() -> void:
	_cast()


func debug_force_bite() -> void:
	_timer = 0.0
	if _state == "wait":
		_bussate = 0   # la CLI vuole l'abbocco vero, senza il rito delle bussate
		_start_bite()
		_timer = 30.0
