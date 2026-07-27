extends Node3D

## LA BARCHETTA DI MOCHI — il verbo "navigare".
##
## Il fiume aveva corrente, pesci e ponti, ma non si toccava. Dal MOLO
## (assi di legno sull'acqua, a valle del ponte) parte una barchetta a
## remi: si rema CONTROCORRENTE verso monte, si passa sotto il ponte ad
## arco, si pesca dal fiume le specie SUE (la trota del salto presso la
## cascata, l'anguilla della notte col buio) — e appena smetti di remare
## la corrente ti riporta a valle, piano, come è giusto.
##
## La fisica è volutamente da barca a remi (mai da motoscafo): forze e
## attrito con velocità terminali PURE (passo_navigazione, testata) —
## la corrente da sola fa ~0.7 m/s a valle, coi remi si risale a ~1.5.
## Le sponde sono i binari: la barca ci rimbalza gentile, mai incastrata.
## Mentre navighi il PlayerController è in pausa e Mochi siede a bordo
## (la camera, figlia sua, viene in barca da sola); i remi leggono gli
## STESSI input del passo (WASD/frecce): nessun tasto nuovo da imparare.

const MATH := preload("res://scenes/world/WorldMath.gd")
const CATALOG := preload("res://scenes/build/BuildCatalog.gd")

## La quota dell'acqua del fiume (la stessa di CozyWorld.RIVER_WATER_Y).
const ACQUA_Y := -0.45
## Dove sta il molo, lungo il corso (a valle del ponte, che è a z=3.2).
const MOLO_Z := 12.0
## Il tratto navigabile (il fiume esiste da -56 a 56: un margine gentile).
const Z_MIN := -50.0
const Z_MAX := 50.0
## Mezzo alveo navigabile (l'acqua è larga 2.35 per lato).
const SPONDA := 1.5

## Le forze della barca. Con l'attrito esponenziale la velocità terminale
## è forza/ATTRITO: corrente sola ~0.7 a valle, remi ~2.2, e remando
## controcorrente si risale a (REMATA-CORRENTE)/ATTRITO ~ 1.5.
const CORRENTE := 0.6          # la spinta del fiume, sempre verso valle (+z)
const REMATA := 1.9            # i remi, in avanti
const RETRO := 0.9             # la sciabordata all'indietro
const ATTRITO := 0.85
const GIRO := 1.6              # virata, in radianti al secondo

var _cozy: Node3D
var _player: Node3D
var _mochi: Node3D
var _sfx

var _molo: Node3D
var _barca: Node3D
var _remi: Array[Node3D] = []
var _naviga := false
var _vel := Vector3.ZERO
var _yaw := PI                 # in avanti = verso monte (-z), come si salpa
var _rem_t := 0.0
var _t := 0.0
var _primo_imbarco := true
var _costruita := false

var _prompt: PanelContainer
var _prompt_label: Label


func _ready() -> void:
	add_to_group("barchetta")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_prompt()
	(func() -> void:
		_player = get_tree().get_first_node_in_group("player_controller")
		_mochi = _player.get_node_or_null("Mochi") if _player else null
		_cozy = get_tree().get_first_node_in_group("cozy_world")
		# il mondo si costruisce differito: il molo aspetta la geometria
		if _cozy and _cozy.has_signal("world_built"):
			_cozy.world_built.connect(_costruisci)
		_costruisci()
	).call_deferred()


# ------------------------------------------------------------ il cuore puro

## Un passo di navigazione: i remi spingono lungo la prua, la corrente
## spinge SEMPRE verso valle (+z), l'attrito riporta tutto a misura di
## barca a remi. PURA: le velocità terminali le verifica il test.
static func passo_navigazione(vel: Vector3, avanti: Vector3, spinta: float,
		delta: float) -> Vector3:
	var v := vel + avanti * spinta * delta
	v += Vector3(0, 0, CORRENTE) * delta
	return v.lerp(Vector3.ZERO, 1.0 - exp(-ATTRITO * delta))


## Dove la sponda rimanda la barca: la x resta nell'alveo attorno al
## corso vero del fiume. PURA (la usa anche il test coi valori di MATH).
static func dentro_l_alveo(x: float, rx: float) -> float:
	return clampf(x, rx - SPONDA, rx + SPONDA)


## Vero mentre Mochi è a bordo (lo chiede la canna da pesca).
func naviga_attiva() -> bool:
	return _naviga


## Il punto in cui la canna ammara dalla barca: il centro del corso, un
## passo a valle — la lenza si distende con la corrente.
func punto_di_pesca(da: Vector3) -> Vector3:
	var z := da.z + 1.2
	return Vector3(MATH.river_x(z), ACQUA_Y, z)


# ------------------------------------------------------------ gli asset

func _costruisci() -> void:
	if _costruita:
		return
	_costruita = true
	var rx := MATH.river_x(MOLO_Z)
	_molo = _make_molo()
	_molo.position = Vector3(rx - 2.35, 0.0, MOLO_Z)
	add_child(_molo)
	_barca = _make_barca()
	_barca.position = Vector3(rx - 0.85, ACQUA_Y + 0.04, MOLO_Z + 0.9)
	_barca.rotation.y = _yaw
	add_child(_barca)


# il molo: assi di legno su pali piantati nell'acqua, con la bitta per
# la cima della barca e la lanterna che aspetta chi rientra col buio
func _make_molo() -> Node3D:
	var n := Node3D.new()
	var wood := CATALOG._mat(Color("c89a6b"), Color("a87c50"), 4.0, 0.5)
	var dark := CATALOG._mat(Color("a87c50"), Color("8a6440"), 4.0, 0.5)
	# le assi, dalla riva sull'acqua (verso est, dentro il fiume)
	for i in 5:
		var asse := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.44, 0.06, 0.66)
		asse.mesh = bm
		asse.material_override = wood
		asse.position = Vector3(0.28 + float(i) * 0.42, 0.14 - float(i) * 0.012, 0)
		asse.rotation.z = -0.015 * float(i)
		n.add_child(asse)
	# i pali che scendono nell'acqua
	for px: float in [0.5, 1.5, 2.3]:
		for pz: float in [-0.26, 0.26]:
			var palo := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.045
			cm.bottom_radius = 0.05
			cm.height = 0.9
			palo.mesh = cm
			palo.material_override = dark
			palo.position = Vector3(px, -0.3, pz)
			n.add_child(palo)
	# la bitta della cima
	var bitta := MeshInstance3D.new()
	var bm2 := CylinderMesh.new()
	bm2.top_radius = 0.05
	bm2.bottom_radius = 0.04
	bm2.height = 0.16
	bitta.mesh = bm2
	bitta.material_override = dark
	bitta.position = Vector3(2.2, 0.2, 0.24)
	n.add_child(bitta)
	return n


# la barchetta a remi: scafo di assi, prua e poppa rialzate, la panchetta
# di Mochi e i due remi sugli scalmi (animati remando)
func _make_barca() -> Node3D:
	var n := Node3D.new()
	var scafo_mat := CATALOG._mat(Color("b06a4a"), Color("8f5238"), 4.0, 0.5)
	var chiaro := CATALOG._mat(Color("e8cfa8"), Color("cfae82"), 5.0, 0.45)
	# il fondo e le fiancate (leggermente aperte verso l'alto)
	var fondo := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.52, 0.07, 1.2)
	fondo.mesh = fm
	fondo.material_override = scafo_mat
	fondo.position = Vector3(0, 0.03, 0)
	n.add_child(fondo)
	for sx: float in [-1.0, 1.0]:
		var fianco := MeshInstance3D.new()
		var im := BoxMesh.new()
		im.size = Vector3(0.06, 0.24, 1.24)
		fianco.mesh = im
		fianco.material_override = scafo_mat
		fianco.position = Vector3(sx * 0.28, 0.17, 0)
		fianco.rotation.z = -sx * 0.12
		n.add_child(fianco)
	# prua e poppa rialzate (la prua guarda -z locale: si salpa verso monte)
	for dz: float in [-1.0, 1.0]:
		var punta := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.5, 0.2, 0.28)
		punta.mesh = pm
		punta.material_override = scafo_mat
		punta.position = Vector3(0, 0.16, dz * 0.62)
		punta.rotation.x = -dz * 0.35
		n.add_child(punta)
	# la panchetta
	var panca := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.48, 0.05, 0.2)
	panca.mesh = bm
	panca.material_override = chiaro
	panca.position = Vector3(0, 0.2, 0.08)
	n.add_child(panca)
	# i remi sugli scalmi, pala in acqua
	_remi.clear()
	for sx: float in [-1.0, 1.0]:
		var remo := Node3D.new()
		remo.position = Vector3(sx * 0.31, 0.24, 0.0)
		var asta := MeshInstance3D.new()
		var am := CylinderMesh.new()
		am.top_radius = 0.018
		am.bottom_radius = 0.018
		am.height = 0.85
		asta.mesh = am
		asta.material_override = chiaro
		asta.position = Vector3(sx * 0.3, -0.12, 0)
		asta.rotation.z = -sx * 0.9
		remo.add_child(asta)
		var pala := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.05, 0.2, 0.1)
		pala.mesh = lm
		pala.material_override = scafo_mat
		pala.position = Vector3(sx * 0.62, -0.38, 0)
		pala.rotation.z = -sx * 0.9
		remo.add_child(pala)
		n.add_child(remo)
		_remi.append(remo)
	return n


# ------------------------------------------------------------ navigare

func _physics_process(delta: float) -> void:
	if not _naviga or _barca == null or _player == null:
		return
	_t += delta
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# la virata: dolce, un po' più viva quando la barca ha abbrivio
	_yaw -= input.x * GIRO * delta
	var avanti := Vector3(sin(_yaw), 0.0, cos(_yaw))
	var spinta := 0.0
	if input.y < -0.1:
		spinta = REMATA
	elif input.y > 0.1:
		spinta = -RETRO
	_vel = passo_navigazione(_vel, avanti, spinta, delta)

	var pos := _barca.position + _vel * delta
	# le sponde: la barca ci si appoggia e scivola, mai incastrata
	var rx := MATH.river_x(pos.z)
	var dentro := dentro_l_alveo(pos.x, rx)
	if absf(dentro - pos.x) > 0.001:
		pos.x = dentro
		_vel.x *= -0.25
	# i capolinea del corso
	var pz := clampf(pos.z, Z_MIN, Z_MAX)
	if absf(pz - pos.z) > 0.001:
		pos.z = pz
		_vel.z *= -0.25
	pos.y = ACQUA_Y + 0.04 + sin(_t * 2.1) * 0.018
	_barca.position = pos
	# l'assetto: beccheggio con l'abbrivio, rollio con la virata
	_barca.rotation = Vector3(
			clampf(_vel.dot(avanti) * 0.05, -0.08, 0.08),
			_yaw,
			clampf(-input.x * 0.09, -0.09, 0.09) + sin(_t * 1.7) * 0.012)

	# i remi vogano solo quando si rema (e si sente il tuffo della pala)
	if spinta != 0.0:
		var prima := int(_rem_t * 1.4)
		_rem_t += delta
		if int(_rem_t * 1.4) != prima and _sfx:
			_sfx.play("step_wet1", -20.0, 1.3)
	for remo in _remi:
		var fase := sin(_rem_t * TAU * 1.4)
		remo.rotation.x = fase * 0.5 if spinta != 0.0 else 0.0

	# Mochi resta seduta a bordo (e la camera, figlia sua, viene con lei)
	_player.global_position = _barca.position + Vector3(0, 0.34, 0)
	if _mochi:
		_mochi.set("_yaw", atan2(-avanti.x, -avanti.z))


func _imbarca() -> void:
	_naviga = true
	_vel = Vector3.ZERO
	_yaw = _barca.rotation.y
	if _player:
		_player.set_physics_process(false)
		_player.set("velocity", Vector3.ZERO)
	if _mochi:
		_mochi.call("set_pose", "sit")
	if _sfx:
		_sfx.play("step_wet2", -12.0, 0.9)
	if _primo_imbarco:
		_primo_imbarco = false
		_toast("I remi in zampa: su per il fiume! (si rema come si cammina, E per scendere)")


func _sbarca() -> void:
	_naviga = false
	if _mochi:
		_mochi.call("set_pose", "stand")
	if _player:
		# a riva dalla sponda più vicina, coi piedi sull'erba
		var pos: Vector3 = _barca.position
		var rx := MATH.river_x(pos.z)
		var lato: float = signf(pos.x - rx)
		if lato == 0.0:
			lato = -1.0
		_player.global_position = Vector3(rx + lato * (2.35 + 0.8), 0.0, pos.z)
		_player.set_physics_process(true)
	if _sfx:
		_sfx.play("step_wet2", -12.0, 1.1)


# ------------------------------------------------------------ il prompt

func _process(_delta: float) -> void:
	if _prompt == null or _player == null or _barca == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_prompt.visible = false
		return
	var text := ""
	var wp := Vector3.ZERO
	if _naviga:
		text = "E — scendi a riva"
		wp = _barca.global_position + Vector3(0, 1.3, 0)
	elif _player.is_physics_processing() \
			and _player.global_position.distance_to(_barca.global_position) < 2.0:
		text = "E — sali sulla barchetta"
		wp = _barca.global_position + Vector3(0, 1.1, 0)
	if text == "" or cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = text
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or _barca == null or _player == null:
		return
	if _naviga:
		# la canna ha la precedenza: se sta pescando, la E è sua
		var fishing := get_node_or_null("../Fishing")
		if fishing and str(fishing.get("_state")) != "off":
			return
		_sbarca()
		get_viewport().set_input_as_handled()
	elif _player.is_physics_processing() \
			and _player.global_position.distance_to(_barca.global_position) < 2.0:
		_imbarca()
		get_viewport().set_input_as_handled()


func _toast(text: String) -> void:
	var visitors := get_node_or_null("../Visitors")
	if visitors:
		visitors.call("_show_toast", text)


func _build_prompt() -> void:
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
	_prompt_label.add_theme_color_override("font_color", Color("6a4a3a"))
	_prompt.add_child(_prompt_label)
