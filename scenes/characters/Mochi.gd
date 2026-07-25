class_name Mochi
extends Node3D

## Mochi, la gattina chibi. Carinissima.
##
## Costruita interamente in modo procedurale (nessun asset esterno):
## mesh primitive + shader toon pastello. La faccia guarda verso -Z,
## la convenzione "forward" di Godot.
##
## Se il nodo genitore è un CharacterBody3D (il PlayerController C++),
## Mochi legge la sua velocità e anima da sola la camminata: rotazione
## verso la direzione, passo saltellante, braccine, orecchie, coda e
## sbuffi di polvere ai piedi.

signal anomaly_started
signal anomaly_ended

const TOON_SHADER := preload("res://shaders/toon.gdshader")
const BUILDER := preload("res://scenes/npc/ChibiBuilder.gd")
const FACE := preload("res://scenes/characters/FaceController.gd")

const FUR := Color("f7e6d0")
const FUR_DARK := Color("e9cfae")
const INNER_EAR := Color("ffb3c0")
const DRESS := Color("f2a9bc")
const EYE := Color("2a1d1d")
const EYE_VOID := Color("000000")
const MOUTH := Color("5a3434")
const BLUSH := Color("ff9db1")
const PAW := Color("fff3e6")

const ANOMALY_DURATION := 0.22

## Il lato horror, disattivato per ora: niente anomalie finché è false.
@export var anomalies_enabled := false

var _head: Node3D
var _tail: Node3D
var _tail_tip: Node3D
var _wag_t := 0.0
var _shadow_blob: MeshInstance3D
var _dust: GPUParticles3D
var _ears: Array[Node3D] = []
var _eyes: Array[Node3D] = []
var _eyeballs: Array[MeshInstance3D] = []
var _irises: Array[Node3D] = []
var _happy: Array[Node3D] = []
var _brows: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _legs: Array[MeshInstance3D] = []
var _squints: Array[Node3D] = []
var _highlights: Array[MeshInstance3D] = []
var _blushes: Array[MeshInstance3D] = []
var _eye_mat: StandardMaterial3D

# il volto vivo: sopracciglia, sguardo, espressioni fuse (vedi FaceController).
# Volutamente non tipizzato: usiamo il preload FACE, così non dipendiamo dal
# fatto che il class_name sia già nella cache globale (primo avvio pulito).
var _face
var _mouths := {}
var _mouth_open: Node3D

# L'autoload viene registrato a metà della prima scansione del filesystem,
# quindi al primo avvio non è ancora visibile al parser: lo risolviamo a
# runtime (var non tipizzata = chiamate dinamiche, nessun errore di parse).
var _sfx

var _body: CharacterBody3D
var _yaw := 0.0
var _walk := 0.0
var _step := 0.0
var _prev_step_sin := 0.0
var _squinting := false
var _tired := false
var _droop := 0.0
var _sweat: MeshInstance3D
var _blowing := false
var _disc_tex: Texture2D   # texture morbida della bollicina di bisogno (lazy)

# posa corrente: "stand" | "sit" | "sleep"
var _pose := "stand"
var _pose_lean := 0.0
var _pose_tw: Tween
# la presa (tazza o annaffiatoio): 0 = braccia libere, 1 = stretta piena
var _hold := 0.0
var _hold_target := 0.0
var _hold_pose := "cup"
## Inclinazione della versata / fase dell'arco di semina (0..1):
## la tweena chi dirige la scena.
var pour := 0.0
## Accovacciata (0..1): il corpo si abbassa sulla terra, animabile.
var crouch := 0.0
## Saltello di gioia (0..1): un tween 0->1 produce UN salto pulito.
var joy := 0.0
# l'arrampicata mano-sopra-mano: peso, fase e memoria del suono presa
var _climb := 0.0
var _climb_step := 0.0
var _climb_prev := 0.0
var _climb_force := false
# il saluto con la zampina: orologio del gesto (99 = a riposo)
var _wave_t := 99.0
# la coreografia della sedutina: tocco -> posa -> rimbalzino -> idle viva
var _sit_t := 0.0
var _sit_flourish := false
var _sit_bounce := 0.0        # il sobbalzo di orecchie e coda quando si posa
var _rise_t := 99.0           # la spinta delle zampine quando si alza
var _gesto := ""              # gesto cute in corso: squeeze | kick | tilt
var _gesto_t := 0.0
var _gesto_cd := 8.0
var _gesto_tilt := 0.0
var _zzz_t := 0.0
var _build_sys: Node
var _weather: Node

# gambette e inclinazione del corpo per ogni posa: da sedute penzolano in
# avanti oltre l'orlo del vestitino, nel letto Mochi si reclina sul cuscino
const LEG_POSES := {
	"stand": {"rot": 0.0, "pos": Vector3(0.115, 0.11, -0.02), "spread": 0.0},
	"sit": {"rot": -1.5, "pos": Vector3(0.115, 0.2, -0.16), "spread": -0.12},
	"sleep": {"rot": -1.5, "pos": Vector3(0.115, 0.16, -0.1), "spread": -0.08},
	"stargaze": {"rot": -1.35, "pos": Vector3(0.115, 0.18, -0.14), "spread": -0.14},
	"soak": {"rot": -0.9, "pos": Vector3(0.115, 0.14, -0.08), "spread": -0.1},
}
const POSE_LEAN := {"stand": 0.0, "sit": 0.12, "sleep": 0.95, "stargaze": 1.5, "soak": 0.06}

var _t := 0.0
var _next_twitch := randf_range(3.0, 8.0)
var _twitch_t := -1.0
var _twitch_ear: Node3D
var _twitch_value := 0.0
var _next_anomaly := randf_range(16.0, 34.0)
var _anomaly_t := -1.0
var _anomaly_duration_override := -1.0


func _ready() -> void:
	_build_body()
	_build_head()
	_build_tail()
	_build_contact_shadow()
	_build_dust()
	_setup_face()
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_sys = get_tree().get_first_node_in_group("build_system")
	# il Weather entra in scena dopo il Player: lookup rimandato a fine frame
	(func(): _weather = get_tree().get_first_node_in_group("weather")).call_deferred()
	_body = get_parent() as CharacterBody3D
	_yaw = rotation.y


func is_anomalous() -> bool:
	return _anomaly_t >= 0.0


## Forza un'anomalia al prossimo frame (debug / eventi scriptati).
## Con [param duration] > 0 si sovrascrive la durata standard.
func provoke_anomaly(duration := -1.0) -> void:
	_next_anomaly = 0.0
	_anomaly_duration_override = duration


## Le zampine si stringono sulla tazza (rituale del camino): la presa
## SFUMA sopra qualunque altra posa delle braccia, e si scioglie piano.
func hold_cup(on: bool) -> void:
	_hold_pose = "cup"
	_hold_target = 1.0 if on else 0.0


## La presa dell'annaffiatoio: avambracci protesi in avanti, e la
## versata (pour 0..1, animabile con un tween) piega le braccia col getto.
func hold_pour(on: bool) -> void:
	_hold_pose = "pour"
	_hold_target = 1.0 if on else 0.0
	if not on:
		pour = 0.0


## La semina: accovacciata (crouch), sacchettino nella zampa sinistra,
## la destra spazza l'arco di spargitura (pour 0..1 per ogni arco).
func hold_sow(on: bool) -> void:
	_hold_pose = "sow"
	_hold_target = 1.0 if on else 0.0
	if not on:
		pour = 0.0


## La raccolta: entrambe le zampine scendono ad afferrare (pour 0),
## poi si alzano col tesoro fin sopra la testolina (pour 1).
func hold_reach(on: bool) -> void:
	_hold_pose = "reach"
	_hold_target = 1.0 if on else 0.0
	if not on:
		pour = 0.0


## La sventagliata del retino: carica all'indietro (pour 0), frustata
## in avanti (pour 1) — il tween di pour decide quanto è veloce il colpo.
func hold_swing(on: bool) -> void:
	_hold_pose = "swing"
	_hold_target = 1.0 if on else 0.0
	if not on:
		pour = 0.0


## La canna da pesca a due zampine: caricata dietro la spalla (pour 0),
## lancio e lunga attesa in avanti (pour 1); lo strattone è un tween
## rapido di pour verso lo 0 e ritorno.
func hold_rod(on: bool) -> void:
	_hold_pose = "rod"
	_hold_target = 1.0 if on else 0.0
	if not on:
		pour = 0.0


## L'offerta: entrambe le zampine protese in avanti col piatto, e
## l'inchino del capo (pour 0..1) mentre lo porge all'amico.
func hold_offer(on: bool) -> void:
	_hold_pose = "offer"
	_hold_target = 1.0 if on else 0.0
	if not on:
		pour = 0.0


## La letterina: zampine strette sui bordi del foglio davanti al musetto,
## la testolina segue le righe (pour 0..1 = progresso di lettura, riga
## per riga) e alla firma si rialza inclinata in un sorrisino affettuoso.
func hold_letter(on: bool) -> void:
	_hold_pose = "letter"
	_hold_target = 1.0 if on else 0.0
	if not on:
		pour = 0.0


## Mette un oggetto in zampa (annaffiatoio, sacchettino, lanterna…):
## da lì in poi eredita ogni movimento del braccio.
func attach_to_paw(prop: Node3D, destra := true) -> void:
	(_arms[1] if destra else _arms[0]).add_child(prop)
	prop.position = Vector3(0, -0.33, -0.06)


## Il punto nel mondo della zampa destra (semini, scintille, gocce).
func paw_world() -> Vector3:
	return _arms[1].to_global(Vector3(0, -0.33, -0.06))


## Il saluto: zampina destra alzata che ondeggia due volte, poi giù.
## Risponde ai vicini che salutano, o parte col tasto T.
func wave() -> void:
	if _hold_target == 0.0 and _wave_t > 1.5:
		_wave_t = 0.0
		# un guizzo lieto del sopracciglio accompagna il saluto
		if _face:
			_face.brow_flash(1.0)
			_face.blink_now()


## Per la verifica CLI: forza la posa d'arrampicata (con fase animata).
func debug_climb(on: bool) -> void:
	_climb_force = on
	if on:
		_climb_step = 2.2


## Soffia sulla tazza: testa china, bocca a "o", occhi socchiusi dolci.
## La faccia recita l'espressione "soffio" (la sceglie _update_face).
func start_blowing() -> void:
	_blowing = true


func stop_blowing() -> void:
	_blowing = false


## Guanciotte al massimo (per l'onsen): il rossore extra si somma
## all'espressione beata senza esserne sovrascritto.
func set_blush_max(on: bool) -> void:
	if _face:
		_face.set_blush_boost(0.55 if on else 0.0)


## Sfinita: goccia di sudore, orecchie basse, occhi a mezz'asta (il musetto
## assonnato lo mette _update_face leggendo _tired).
func set_tired(on: bool) -> void:
	_tired = on
	_sweat.visible = on


## Una bollicina di bisogno che sboccia sopra il musetto e sale fluttuando,
## tinta come il ciondolo della HUD (acqua azzurra, fame rosa, energia verde):
## così il personaggio e l'interfaccia parlano la stessa lingua di colori.
## Riusa il pattern dei "z" del sonno (Sprite3D billboard che sale e svanisce).
func emote_need(kind: String) -> void:
	if not _head:
		return
	var tint: Color = {
		"water": Color("a2d2ff"),
		"hunger": Color("ffc8dd"),
		"stamina": Color("b9fbc0"),
	}.get(kind, Color("ffd5e0"))
	var bubble := Sprite3D.new()
	bubble.texture = _need_bubble_texture()
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.pixel_size = 0.007
	bubble.scale = Vector3.ONE * 0.6
	bubble.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	bubble.position = _head.position + Vector3(randf_range(-0.12, 0.2), 0.5, -0.05)
	add_child(bubble)
	# entra con un pop, sale fluttuando alla deriva
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(bubble, "modulate:a", 0.95, 0.18)
	tw.tween_property(bubble, "scale", Vector3.ONE * 1.12, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(bubble, "position:y", bubble.position.y + 0.72, 1.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(bubble, "position:x", bubble.position.x + randf_range(-0.1, 0.16), 1.7) \
			.set_trans(Tween.TRANS_SINE)
	# la dissolvenza parte a metà volo, poi si congeda
	var fade := create_tween()
	fade.tween_interval(1.0)
	fade.tween_property(bubble, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	fade.tween_callback(bubble.queue_free)


# disco morbido (radiale) per la bollicina di bisogno, creato una volta sola
func _need_bubble_texture() -> Texture2D:
	if _disc_tex:
		return _disc_tex
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0.95),
		Color(1, 1, 1, 0.5),
		Color(1, 1, 1, 0.0),
	])
	tex.gradient = grad
	_disc_tex = tex
	return _disc_tex


## Il punto di aggancio per i capi del guardaroba: "testa" segue la
## testolina (e i suoi dondolii), "polso" la zampina destra, "corpo"
## il busto. Gli accessori indossati ereditano ogni animazione.
func get_attach_point(slot: String) -> Node3D:
	match slot:
		"testa":
			return _head
		"polso":
			return _arms[1]
		_:
			return self


## Cambia la posa: "stand", "sit" (sedie, sgabelli, panchine) o "sleep" (letto).
func set_pose(pose: String) -> void:
	var prev := _pose
	_pose = pose
	# la coreografia della sedutina riparte da capo a ogni cambio
	_sit_t = 0.0
	_sit_flourish = false
	_gesto = ""
	_gesto_tilt = 0.0
	_gesto_cd = randf_range(6.0, 11.0)
	if pose == "stand" and prev == "sit":
		_rise_t = 0.0   # alzandosi, le zampine danno la spintarella
	var lp: Dictionary = LEG_POSES[pose]
	var tw := create_tween().set_parallel(true)
	_pose_tw = tw   # finché corre, il ciclo di camminata lascia stare le gambe
	for i in _legs.size():
		var leg := _legs[i]
		var side := -1.0 if i == 0 else 1.0
		var pos: Vector3 = lp["pos"]
		tw.tween_property(leg, "rotation:x", lp["rot"], 0.32) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(leg, "rotation:z", side * lp["spread"], 0.32) \
				.set_trans(Tween.TRANS_SINE)
		tw.tween_property(leg, "position", Vector3(side * pos.x, pos.y, pos.z), 0.32) \
				.set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_pose_lean", POSE_LEAN[pose], 0.38) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# l'ombra di contatto ha senso solo in piedi: da seduta è sul mobile
	_shadow_blob.visible = pose == "stand"
	if pose != "sleep":
		_zzz_t = 0.0


# una "z" di carillon che sale fluttuando dalla testa e svanisce
func _spawn_zzz() -> void:
	var z := Label3D.new()
	z.text = "z"
	z.font_size = randi_range(40, 58)
	z.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	z.modulate = Color(0.62, 0.5, 0.78, 0.95)
	z.outline_size = 10
	z.outline_modulate = Color(1, 1, 1, 0.85)
	z.no_depth_test = true
	z.position = _head.position + Vector3(randf_range(0.18, 0.3), 0.42, -0.05)
	add_child(z)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(z, "position:y", 2.1, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(z, "position:x", z.position.x + 0.18, 1.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(z, "modulate:a", 0.0, 1.7).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(z.queue_free)


# ---------------------------------------------------------------- materiali

func _toon_mat(color: Color, fur := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("albedo_color", color)
	if fur > 0.0:
		mat.set_shader_parameter("fur_noise", fur)
	return mat


func _flat_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


# ---------------------------------------------------------------- geometrie

func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl := Vector3.ONE, casts_shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	if not casts_shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _sphere(radius: float, segments := 32) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = int(segments * 0.5)
	return m


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return m


func _cone(radius: float, height: float, segments := 24) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = segments
	return m


# ---------------------------------------------------------------- corpo

func _build_body() -> void:
	var dress_mat := _toon_mat(DRESS)
	var paw_mat := _toon_mat(PAW)

	# il vestitino è un solo pezzo: una pera morbida con l'orlo arrotondato
	BUILDER.lathe(self, BUILDER.DRESS_PROFILE, dress_mat)

	# colletto a petali da grembiulino, appoggiato sulla scollatura
	BUILDER.collar(self, paw_mat, 0.585, 0.17, 9, 0.054)

	# il pelo del petto che sbuffa sopra il colletto
	BUILDER.tuft(self, _toon_mat(FUR, 0.45), Vector3(0, 0.645, -0.165),
			Vector3(-2.55, 0, 0), 0.105, 3, 0.5)

	# gambette coi piedini a fagiolo (si piegano quando Mochi si siede)
	for side: float in [-1.0, 1.0]:
		var leg := _add_mesh(self, _capsule(0.07, 0.2), paw_mat, Vector3(side * 0.115, 0.11, -0.02))
		_add_mesh(leg, _sphere(0.075, 18), paw_mat, Vector3(0, -0.08, -0.05), Vector3(1, 0.6, 1.35))
		_legs.append(leg)

	# braccia VERE, leggibili: manica corta a sbuffo (rosa vestito) col
	# polsino chiaro, poi l'avambraccio in PELO crema — che stacca dal
	# rosa: prima le braccia sparivano perché manica e campana erano lo
	# stesso colore — e in punta la zampa-guanto paffuta col pollicino
	var fur_arm_mat := _toon_mat(FUR, 0.45)
	for side: float in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		# spalla raccolta sul corpo, braccio corto: proporzioni da peluche
		shoulder.position = Vector3(side * 0.215, 0.58, 0)
		shoulder.rotation.z = side * 0.3
		add_child(shoulder)
		_add_mesh(shoulder, _capsule(0.08, 0.19), dress_mat, Vector3(0, -0.05, 0))
		_add_mesh(shoulder, _sphere(0.072, 18), paw_mat, Vector3(0, -0.125, 0), Vector3(1, 0.55, 1))
		# gomito morbido, piega in avanti più accentuata: niente bastoncini
		var elbow := Node3D.new()
		elbow.position = Vector3(0, -0.13, 0)
		elbow.rotation.x = 0.24
		shoulder.add_child(elbow)
		_add_mesh(elbow, _capsule(0.048, 0.21), fur_arm_mat, Vector3(0, -0.09, 0))
		_add_mesh(elbow, _sphere(0.068, 20), paw_mat, Vector3(0, -0.2, 0), Vector3(0.95, 1.1, 0.85))
		_add_mesh(elbow, _sphere(0.026, 12), paw_mat, Vector3(side * -0.042, -0.175, -0.024))
		_arms.append(shoulder)


func _build_head() -> void:
	_head = Node3D.new()
	_head.position = Vector3(0, 0.96, 0)
	add_child(_head)

	# testolina più larga che alta, da pupazzetto, con la grana del pelo
	var fur_mat := _toon_mat(FUR, 0.45)
	_add_mesh(_head, _sphere(0.42, 48), fur_mat, Vector3.ZERO, Vector3(1.04, 0.92, 0.98))

	# il musetto: due cuscinetti in un tono appena più chiaro del pelo
	# (mai bianco: non deve staccare), col nasino rosa nel mezzo
	var muso_mat := _toon_mat(FUR.lightened(0.06), 0.35)
	for side: float in [-1.0, 1.0]:
		_add_mesh(_head, _sphere(0.085, 20), muso_mat,
				Vector3(side * 0.048, -0.115, -0.352), Vector3(1, 0.72, 0.5))
	_add_mesh(_head, _sphere(0.021, 12), _flat_mat(Color("ff8fa3")),
			Vector3(0, -0.052, -0.418), Vector3(1.3, 0.85, 0.7), false)

	# ciuffi di pelo sulle guance e la frangetta sulla fronte
	for side: float in [-1.0, 1.0]:
		BUILDER.tuft(_head, fur_mat, Vector3(side * 0.36, -0.07, -0.10),
				Vector3(0, side * -0.35, side * -2.05), 0.082, 3, 0.6)
	BUILDER.tuft(_head, fur_mat, Vector3(0, 0.275, -0.265),
			Vector3(-2.9, 0, 0), 0.095, 3, 0.62)

	# orecchie da gattina: coni morbidi a punta arrotondata, con pivot
	# alla base per il twitch e l'interno rosa inserito
	for side: float in [-1.0, 1.0]:
		var ear := Node3D.new()
		ear.position = Vector3(side * 0.215, 0.315, -0.01)
		ear.rotation.z = side * -0.32
		ear.rotation.y = side * -0.15
		_head.add_child(ear)
		BUILDER.lathe(ear, [Vector2(0.11, 0.0), Vector2(0.105, 0.09),
				Vector2(0.078, 0.165), Vector2(0.042, 0.22), Vector2(0.0, 0.25)],
				fur_mat, Vector3.ZERO, 18)
		var inr: MeshInstance3D = BUILDER.lathe(ear, [Vector2(0.065, 0.0),
				Vector2(0.058, 0.07), Vector2(0.033, 0.135), Vector2(0.0, 0.165)],
				_toon_mat(INNER_EAR), Vector3(0, 0.04, -0.048), 14)
		inr.scale.z = 0.55
		_ears.append(ear)

	# ciuffetto ribelle: un ricciolo affondato a metà nella testa
	var ahoge := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.042
	torus.outer_radius = 0.078
	ahoge.mesh = torus
	ahoge.material_override = _toon_mat(FUR_DARK)
	ahoge.position = Vector3(0.02, 0.4, -0.04)
	ahoge.rotation_degrees = Vector3(55, 10, -20)
	_head.add_child(ahoge)

	# occhioni lucidi. Struttura pensata per il volto vivo (FaceController):
	# ogni occhio è un pivot con l'ellissoide scuro (apertura via scale.y) e
	# un nodo "iride" che raccoglie le due luci — così lo sguardo le sposta
	# insieme e la tenerezza le dilata.
	_eye_mat = _flat_mat(EYE)
	for side: float in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(side * 0.155, 0.03, -0.355)
		_head.add_child(eye)
		var ball := _add_mesh(eye, _sphere(0.085, 24), _eye_mat, Vector3.ZERO,
				Vector3(1, 1.18, 0.55), false)
		var iris := Node3D.new()
		eye.add_child(iris)
		# le luci sono DISCHI appoggiati sull'occhio, non palline sporgenti
		var shine := _add_mesh(iris, _sphere(0.03, 12), _flat_mat(Color.WHITE),
				Vector3(-0.028 * side, 0.038, -0.043), Vector3(1, 1, 0.35), false)
		var sparkle := _add_mesh(iris, _sphere(0.013, 10), _flat_mat(Color("ffdce4")),
				Vector3(0.03 * side, -0.028, -0.045), Vector3(1, 1, 0.35), false)
		_eyes.append(eye)
		_eyeballs.append(ball)
		_irises.append(iris)
		_highlights.append(shine)
		_highlights.append(sparkle)
		# l'arco "^^" della felicità piena (nascosto a riposo)
		_happy.append(FACE.build_happy_arc(_head, _eye_mat,
				Vector3(side * 0.155, 0.04, -0.362), side, 0.078))
		# il sopracciglio: una barretta morbida sopra l'occhio — dove vive
		# gran parte dell'emozione. Tono caldo del musetto, non nero duro.
		_brows.append(FACE.build_brow(_head, _flat_mat(Color("6b4636")), side,
				Vector3(side * 0.108, 0.185, -0.352), 0.088, 0.017))

	# occhi ">.<" per la corsa: due chevron di capsule, nascosti a riposo
	for side: float in [-1.0, 1.0]:
		var sq := Node3D.new()
		sq.position = Vector3(side * 0.155, 0.03, -0.36)
		sq.scale.x = 1.0 if side < 0.0 else -1.0
		sq.visible = false
		_head.add_child(sq)
		var sq_mat := _flat_mat(EYE)
		var upper := _add_mesh(sq, _capsule(0.014, 0.095), sq_mat,
				Vector3(-0.009, 0.033, 0), Vector3.ONE, false)
		upper.rotation.z = 0.85
		var lower := _add_mesh(sq, _capsule(0.014, 0.095), sq_mat,
				Vector3(-0.009, -0.033, 0), Vector3.ONE, false)
		lower.rotation.z = PI - 0.85
		_squints.append(sq)

	# goccia di sudore per quando è sfinita (nascosta a riposo)
	_sweat = _add_mesh(_head, _sphere(0.042, 14),
			_flat_mat(Color(0.66, 0.86, 0.96, 0.92)),
			Vector3(0.27, 0.12, -0.19), Vector3(0.8, 1.35, 0.8), false)
	_sweat.visible = false

	# il set completo di bocche morbide (neutra "w", sorriso, ghigno, o/O,
	# broncio, triste, seria) più la cavità scura che si apre per parlare/
	# ridere/stupirsi: il FaceController le sfuma e le anima.
	var mouth_mat := _flat_mat(MOUTH)
	_mouths = FACE.build_mouth_set(_head, mouth_mat, Vector3(0, -0.1, -0.408), 1.0)
	_mouth_open = FACE.build_mouth_open(_head, _flat_mat(Color("3a1f1f")),
			Vector3(0, -0.1, -0.404), 1.0)

	# guanciotte
	for side: float in [-1.0, 1.0]:
		var blush := _add_mesh(_head, _sphere(0.055, 16), _flat_mat(Color(BLUSH, 0.6)),
				Vector3(side * 0.265, -0.055, -0.3), Vector3(1, 0.62, 0.3), false)
		blush.rotation.y = side * -0.55
		_blushes.append(blush)


# monta il "volto vivo" sulle parti facciali appena costruite
func _setup_face() -> void:
	_face = FACE.new()
	_face.setup({
		"head": _head,
		"eyes": _eyes, "eyeballs": _eyeballs, "irises": _irises,
		"happy": _happy, "squint": _squints, "brows": _brows,
		"blush": _blushes, "mouths": _mouths, "mouth_open": _mouth_open,
		"eye_base_scale": Vector3(1, 1.18, 0.55), "face_side": 0.28,
	})


## Congela l'ammicco per gli scatti ravvicinati del DebugHarness.
func freeze_face(sec := 10.0) -> void:
	if _face:
		_face.freeze_blink(sec)


func _build_tail() -> void:
	# una coda VERA: tubo rastremato spazzato lungo una S, che spunta dal
	# retro del vestitino e sale dietro la schiena. Due snodi: la base
	# scodinzola, la punta segue in ritardo (colpo di frusta), con una
	# sferetta-nocca a nascondere la giuntura e la puntina chiara.
	var fur_mat := _toon_mat(FUR, 0.45)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.235, 0.28)
	add_child(_tail)
	# il ciuffo alla base, dove la coda esce dal vestitino
	BUILDER.tuft(self, fur_mat, Vector3(0, 0.26, 0.275), Vector3(1.25, 0, 0), 0.095, 3, 0.7)
	BUILDER.tube(_tail, [Vector3(0, -0.02, -0.07), Vector3(0, 0.0, 0.10),
			Vector3(0, 0.045, 0.20), Vector3(0, 0.115, 0.265)],
			[0.06, 0.064, 0.058, 0.05], fur_mat, 18, 12)
	_add_mesh(_tail, _sphere(0.048, 16), fur_mat, Vector3(0, 0.115, 0.265))
	_tail_tip = Node3D.new()
	_tail_tip.position = Vector3(0, 0.115, 0.265)
	_tail.add_child(_tail_tip)
	BUILDER.tube(_tail_tip, [Vector3.ZERO, Vector3(0, 0.075, 0.04), Vector3(0, 0.145, 0.045)],
			[0.049, 0.039, 0.027], fur_mat, 12, 10)
	BUILDER.tube(_tail_tip, [Vector3(0, 0.145, 0.045), Vector3(0, 0.19, 0.028), Vector3(0, 0.222, -0.01)],
			[0.027, 0.018, 0.007], _toon_mat(PAW), 10, 8)


# ombra di contatto morbida, per ancorare Mochi al terreno
func _build_contact_shadow() -> void:
	var tex := GradientTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(0.2, 0.12, 0.24, 0.4),
		Color(0.2, 0.12, 0.24, 0.2),
		Color(0.2, 0.12, 0.24, 0.0),
	])
	tex.gradient = grad

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex

	var plane := PlaneMesh.new()
	plane.size = Vector2(1.05, 1.05)
	_shadow_blob = MeshInstance3D.new()
	_shadow_blob.mesh = plane
	_shadow_blob.material_override = mat
	_shadow_blob.position = Vector3(0, 0.02, 0)
	_shadow_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow_blob)


# sbuffi di polvere ai piedi mentre cammina
func _build_dust() -> void:
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	grad.colors = PackedColorArray([
		Color(0.96, 0.9, 0.78, 0.32),
		Color(0.96, 0.9, 0.78, 0.16),
		Color(0.96, 0.9, 0.78, 0.0),
	])
	tex.gradient = grad

	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.albedo_texture = tex
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_mat.vertex_color_use_as_albedo = true

	var quad := QuadMesh.new()
	quad.size = Vector2(0.13, 0.13)
	quad.material = draw_mat

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.12
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.55
	pm.gravity = Vector3(0, 0.3, 0)
	pm.scale_min = 0.45
	pm.scale_max = 0.85
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0),
		Color(1, 1, 1, 0.8),
		Color(1, 1, 1, 0.0),
	])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex

	_dust = GPUParticles3D.new()
	_dust.amount = 12
	_dust.lifetime = 0.65
	_dust.local_coords = false
	_dust.emitting = false
	_dust.process_material = pm
	_dust.draw_pass_1 = quad
	_dust.position = Vector3(0, 0.05, 0)
	add_child(_dust)


# easing "back-out": arriva, sfora di un pelo, rientra — il rimbalzino
# che rende morbido ogni assestamento
func _back_out(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)


# ---------------------------------------------------------------- animazione

func _process(delta: float) -> void:
	_t += delta

	# --- lettura del movimento dal PlayerController (C++) ---
	var speed := 0.0
	if _body:
		var hv := _body.velocity
		hv.y = 0.0
		speed = hv.length()
		if speed > 0.15:
			var target_yaw := atan2(-hv.x, -hv.z)
			_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-9.0 * delta))
	rotation.y = _yaw

	var moving := speed > 0.15
	_walk = lerpf(_walk, 1.0 if moving else 0.0, 1.0 - exp(-8.0 * delta))
	if moving:
		_step += speed * delta * 3.2
	_dust.emitting = speed > 0.6

	# il suono scatta nell'ISTANTE in cui il piedino si pianta a terra
	# (cos che attraversa lo zero = fine della fase aerea del ciclo),
	# diverso a seconda della superficie (erba, parquet, pietra)
	var step_sin := cos(_step)
	if _walk > 0.4 and step_sin * _prev_step_sin < 0.0 and _sfx:
		var surface := "grass"
		if _build_sys:
			surface = _build_sys.surface_at(global_position)
		# dopo la pioggia l'erba è zuppa: passi che fanno splash
		if surface == "grass" and _weather and _weather.is_wet():
			surface = "wet"
		_sfx.footstep(surface)
	_prev_step_sin = step_sin

	# occhi ">.<" quando corre (con isteresi per non sfarfallare); da
	# sfinita niente squint: arranca, non sfreccia
	# lo stato di "sforzo" della corsa: il FaceController mostra i ">.<"
	var squint_on := (speed > 4.6 or (_squinting and speed > 4.0)) and not _tired
	if not is_anomalous():
		_squinting = squint_on

	var hop := absf(sin(_step)) * _walk

	# respiro (fermo) + saltello del passo (in cammino)
	position.y = sin(_t * 2.1) * 0.018 * (1.0 - _walk) + hop * 0.05 - crouch * 0.1 \
			+ sin(clampf(joy, 0.0, 1.0) * PI) * 0.16
	rotation.z = sin(_t * 1.05) * 0.012 + sin(_step) * 0.055 * _walk
	rotation.x = -0.06 * _walk + _pose_lean + crouch * 0.26
	# l'ombra resta incollata al terreno mentre Mochi dondola e saltella
	_shadow_blob.position.y = 0.02 - position.y

	# scodinzolio: dolce da ferma, vivace in cammino, la punta segue in
	# ritardo di fase — il colpo di frusta che rende viva una coda
	_wag_t += delta * (1.7 + 3.8 * _walk)
	var wag_a := 0.3 + 0.32 * _walk
	_tail.rotation.y = sin(_wag_t) * wag_a
	_tail.rotation.x = sin(_t * 0.9) * 0.06 + hop * 0.2
	_tail_tip.rotation.y = sin(_wag_t - 0.9) * wag_a * 0.85
	_tail_tip.rotation.x = sin(_wag_t * 0.5 - 0.6) * 0.06
	# braccine: oscillazione ampia con un filo di torsione, e in cammino
	# si APRONO oltre la campana del vestitino — mai dentro la stoffa
	var swing := sin(_step) * 0.62 * _walk
	_arms[0].rotation.x = swing
	_arms[1].rotation.x = -swing
	_arms[0].rotation.y = -sin(_step - 0.4) * 0.14 * _walk
	_arms[1].rotation.y = sin(_step - 0.4) * 0.14 * _walk
	# segno VERSO FUORI (sinistra negativa, destra positiva): il respiro
	# da ferma e l'apertura in cammino allargano, mai dentro la stoffa
	_arms[0].rotation.z = -0.3 - sin(_t * 2.1) * 0.05 * (1.0 - _walk) - 0.2 * _walk
	_arms[1].rotation.z = 0.3 + sin(_t * 2.1 + 0.4) * 0.05 * (1.0 - _walk) + 0.2 * _walk

	# --- il ciclo di camminata dei piedini ---
	# Ogni gambetta ha la sua metà del passo: si SOLLEVA mentre avanza
	# (fase aerea), si pianta davanti e SPINGE all'indietro in appoggio.
	# Da ferma il ciclo si spegne da solo (via _walk); le pose sedute
	# hanno la precedenza finché il loro tween è in corsa.
	if _pose == "stand" and (_pose_tw == null or not _pose_tw.is_running()):
		for i in _legs.size():
			var leg := _legs[i]
			var lato := -1.0 if i == 0 else 1.0
			var p := _step + (0.0 if i == 0 else PI)
			leg.rotation.x = -sin(p) * 0.62 * _walk
			leg.rotation.z = 0.0
			leg.position.x = lato * 0.115
			leg.position.y = 0.11 + maxf(0.0, cos(p)) * 0.075 * _walk
			leg.position.z = -0.02

	if not is_anomalous():
		if _blowing:
			# china sulla tazza, con un dondolio appena percettibile
			_head.rotation = Vector3(0.3 + sin(_t * 2.4) * 0.03, 0, 0.02)
		elif _pose == "sleep":
			# testa abbandonata sul cuscino, appena un fremito di sogno
			_head.rotation = Vector3(0.14, sin(_t * 0.3) * 0.05, 0.04)
		else:
			# la testa si guarda intorno da ferma, guarda avanti in cammino
			_head.rotation = Vector3(
				sin(_t * 0.6) * 0.03 * (1.0 - _walk) + hop * 0.06,
				(sin(_t * 0.45) * 0.22 + sin(_t * 1.7) * 0.03) * (1.0 - _walk),
				sin(_t * 0.8) * 0.045
			)

	_update_ear_twitch(delta)
	# orecchie: sobbalzo del passo + eventuale twitch + stanchezza
	_droop = lerpf(_droop, 0.55 if _tired else 0.0, 1.0 - exp(-6.0 * delta))
	for ear in _ears:
		ear.rotation.x = -hop * 0.22 + _droop + (_twitch_value if ear == _twitch_ear else 0.0)
	_update_anomaly(delta)

	# --- pose da seduta / da sonno ---
	# --- l'arrampicata: mano-sopra-mano su scale e pioli ---
	# Rilevata dalla fisica: forte velocità verticale col corpo su una
	# rampa ripida. Tutto il corpo racconta la salita: braccia alternate
	# che cercano il piolo sopra, zampette in controtempo, corpo stretto
	# alla scala che dondola col ritmo, testolina verso la meta.
	var vy := _body.velocity.y if _body else 0.0
	var salita := _climb_force or (_body != null and _pose == "stand" \
			and absf(vy) > 0.75 and _hold_target == 0.0)
	_climb = lerpf(_climb, 1.0 if salita else 0.0, 1.0 - exp(-8.0 * delta))
	if salita:
		_climb_step += (vy * 5.5 if not _climb_force else 4.0) * delta
	if _climb > 0.02:
		var ph := _climb_step
		# braccia alternate: una si allunga al piolo, l'altra tira giù
		_arms[0].rotation.x = lerpf(_arms[0].rotation.x, 1.35 + sin(ph) * 0.55, _climb)
		_arms[1].rotation.x = lerpf(_arms[1].rotation.x, 1.35 + sin(ph + PI) * 0.55, _climb)
		_arms[0].rotation.z = lerpf(_arms[0].rotation.z, -0.12, _climb)
		_arms[1].rotation.z = lerpf(_arms[1].rotation.z, 0.12, _climb)
		# zampette sui pioli, in controtempo con le braccia
		for i in _legs.size():
			var leg := _legs[i]
			var lp := ph + (PI if i == 0 else 0.0)
			leg.rotation.x = lerpf(leg.rotation.x, -0.5 - sin(lp) * 0.45, _climb)
			leg.position.y = lerpf(leg.position.y,
					0.11 + maxf(0.0, cos(lp)) * 0.05, _climb)
		# il corpo si stringe alla scala e ondeggia con la presa
		rotation.x += 0.22 * _climb
		rotation.z += sin(ph) * 0.06 * _climb
		position.y += absf(sin(ph)) * 0.02 * _climb
		_head.rotation.x += (-0.28 if vy >= 0.0 else 0.18) * _climb
		# il tocchetto di legno a ogni presa sul piolo
		var cs := sin(ph)
		if _sfx and cs * _climb_prev < 0.0 and _climb > 0.5:
			_sfx.play("step_wood" + str(1 + randi() % 3), -18.0, 1.25)
		_climb_prev = cs

	# --- il saluto: zampina alzata che ondeggia, testolina inclinata ---
	if _wave_t < 1.5:
		_wave_t += delta
		# entra (0-0.25), sventola (0.25-1.1), rientra (1.1-1.5)
		var su := smoothstep(0.0, 0.25, _wave_t) * (1.0 - smoothstep(1.1, 1.5, _wave_t))
		var wag := sin(_wave_t * 14.0) * 0.45 * smoothstep(0.2, 0.35, _wave_t) \
				* (1.0 - smoothstep(1.0, 1.2, _wave_t))
		# ANATOMIA CHIBI: la testona (0.92 di diametro) inghiotte qualunque
		# saluto sopra la testa, e davanti alla faccia sarebbe bianco su
		# bianco. Quindi: zampina DAVANTI AL PETTO che sventola di lato,
		# crema sul rosa del vestitino — leggibile da ogni inquadratura.
		_arms[1].rotation.x = lerpf(_arms[1].rotation.x, 1.66, su)
		_arms[1].rotation.z = lerpf(_arms[1].rotation.z, 0.1 + wag, su)
		_head.rotation.z += 0.14 * su
		rotation.z += 0.05 * su

	# --- la spintarella dell'alzata: le zampine premono sul sedile ---
	if _rise_t < 0.3:
		_rise_t += delta
		var spinta := sin(clampf(_rise_t / 0.3, 0.0, 1.0) * PI)
		_arms[0].rotation.x = minf(_arms[0].rotation.x, -spinta * 0.38)
		_arms[1].rotation.x = minf(_arms[1].rotation.x, -spinta * 0.38)

	# --- la sedutina cute: tocco, posa, rimbalzino, poi idle viva ---
	if _pose == "sit":
		_sit_t += delta
		# un gesto alla volta, col suo orologio
		if _gesto != "":
			_gesto_t += delta
			var durata: float = {"squeeze": 1.0, "kick": 0.8, "tilt": 1.4}[_gesto]
			if _gesto_t >= durata:
				_gesto = ""
				_gesto_tilt = 0.0

		# fase 1 (0-0.22s): il TOCCO — le zampine cercano il sedile
		var brace := smoothstep(0.0, 0.22, _sit_t)
		# fase 2-3 (0.3-0.62s): la POSA col rimbalzino elastico in grembo
		var settle := clampf((_sit_t - 0.3) / 0.32, 0.0, 1.0)
		var lap := _back_out(settle)

		# il corpo si accuccia di un soffio mentre si posa (squash & recover)
		position.y -= sin(clampf(_sit_t / 0.62, 0.0, 1.0) * PI) * 0.032

		# braccine: avanti ad appoggiarsi, poi in grembo, poi respirano
		var stretta := 0.0
		if _gesto == "squeeze":
			stretta = sin(clampf(_gesto_t / 1.0, 0.0, 1.0) * PI)
		var arm_x := lerpf(0.72 * brace, 0.44, lap) \
				+ sin(_t * 1.7) * 0.035 * settle + stretta * 0.1
		_arms[0].rotation.x = arm_x
		_arms[1].rotation.x = arm_x + 0.03
		_arms[0].rotation.y = 0.0
		_arms[1].rotation.y = 0.0
		var chiusura := lerpf(0.26, 0.12, lap) - stretta * 0.1
		_arms[0].rotation.z = -chiusura
		_arms[1].rotation.z = chiusura

		# quando si è posata: sobbalzo di orecchie e coda, una volta sola
		if settle >= 1.0 and not _sit_flourish:
			_sit_flourish = true
			_sit_bounce = 0.42
		_tail.rotation.y += _sit_bounce * 0.8
		for ear in _ears:
			ear.rotation.x += _sit_bounce

		# idle viva: piedini a penzoloni che dondolano, sfasati e pigri
		if settle >= 1.0 and (_pose_tw == null or not _pose_tw.is_running()):
			for i in _legs.size():
				var leg := _legs[i]
				var ph := _t * 2.1 + (0.0 if i == 0 else 2.4)
				var dondolio := sin(ph) * 0.1
				if _gesto == "kick":
					# due calcetti felici, insieme
					dondolio = sin(_gesto_t * 13.0) * 0.28 * (1.0 - _gesto_t / 0.8)
				leg.rotation.x = -1.5 + dondolio
			# ogni tanto, un piccolo gesto tutto suo
			_gesto_cd -= delta
			if _gesto == "" and _gesto_cd <= 0.0:
				_gesto = ["squeeze", "kick", "tilt"][randi() % 3]
				_gesto_t = 0.0
				_gesto_cd = randf_range(7.0, 13.0)
			if _gesto == "tilt":
				_gesto_tilt = sin(clampf(_gesto_t / 1.4, 0.0, 1.0) * PI) * 0.16
				_head.rotation.z += _gesto_tilt
	elif _pose == "sleep":
		# zampine raccolte sotto il musetto, respiro lento
		var curl := 0.5 + sin(_t * 1.4) * 0.02
		_arms[0].rotation.x = curl
		_arms[1].rotation.x = curl + 0.04
		_arms[0].rotation.z = -0.1
		_arms[1].rotation.z = 0.1
	elif _pose != "stand":
		# le altre pose (stelle, onsen): zampine in grembo, per ora
		_arms[0].rotation.x = 0.45
		_arms[1].rotation.x = 0.45
	_sit_bounce = lerpf(_sit_bounce, 0.0, 1.0 - exp(-9.0 * delta))

	# --- la presa sulla tazza: sfuma SOPRA ogni altra posa ---
	# avambracci sollevati al petto, zampine che si cercano al centro,
	# un filo di respiro; quando soffia, la tazza sale verso il musetto
	_hold = lerpf(_hold, _hold_target, 1.0 - exp(-7.0 * delta))
	if _hold > 0.01:
		# niente torsione y: con la piega del gomito renderebbe le due
		# braccia asimmetriche (l'ordine di rotazione YXZ non perdona)
		_arms[0].rotation.y = lerpf(_arms[0].rotation.y, 0.0, _hold)
		_arms[1].rotation.y = lerpf(_arms[1].rotation.y, 0.0, _hold)
		if _hold_pose == "sow":
			# la semina: sinistra col sacchettino al petto, destra che
			# spazza l'arco (pour 0..1) alzandosi a metà gesto
			_arms[0].rotation.x = lerpf(_arms[0].rotation.x, 0.85, _hold)
			_arms[0].rotation.z = lerpf(_arms[0].rotation.z, 0.18, _hold)
			_arms[1].rotation.x = lerpf(_arms[1].rotation.x,
					0.68 + sin(pour * PI) * 0.12, _hold)
			_arms[1].rotation.z = lerpf(_arms[1].rotation.z,
					lerpf(-0.55, 0.3, pour), _hold)
			# la testolina segue la terra che sta seminando
			_head.rotation.x += crouch * 0.3
		elif _hold_pose == "reach":
			# la raccolta: giù ad afferrare, su a sollevare il tesoro —
			# e la testolina lo segue, dalla terra al cielo
			var rx := lerpf(0.55 + crouch * 0.25, 1.5, pour)
			_arms[0].rotation.x = lerpf(_arms[0].rotation.x, rx, _hold)
			_arms[1].rotation.x = lerpf(_arms[1].rotation.x, rx + 0.05, _hold)
			_arms[0].rotation.z = lerpf(_arms[0].rotation.z, 0.22, _hold)
			_arms[1].rotation.z = lerpf(_arms[1].rotation.z, -0.22, _hold)
			_head.rotation.x += crouch * 0.28 - pour * 0.4
		elif _hold_pose == "swing":
			# la sventagliata: destra che carica dietro-alto e frusta in
			# avanti; la sinistra bilancia in controtempo; la testolina
			# accompagna il colpo — tutto il corpo racconta lo swing
			var sx := lerpf(-0.85, 1.25, pour)
			_arms[1].rotation.x = lerpf(_arms[1].rotation.x, sx, _hold)
			_arms[1].rotation.z = lerpf(_arms[1].rotation.z, -0.15, _hold)
			_arms[0].rotation.x = lerpf(_arms[0].rotation.x,
					lerpf(0.3, -0.35, pour), _hold)
			_arms[0].rotation.z = lerpf(_arms[0].rotation.z, -0.3, _hold)
			_head.rotation.x += lerpf(-0.15, 0.12, pour) * _hold
		elif _hold_pose == "rod":
			# la pesca: entrambe le zampine sul manico, la destra guida;
			# nell'attesa la canna respira piano e la testolina segue
			# il galleggiante laggiù
			var rx := lerpf(-0.7, 0.95, pour) + sin(_t * 1.6) * 0.025 * pour
			_arms[1].rotation.x = lerpf(_arms[1].rotation.x, rx, _hold)
			_arms[0].rotation.x = lerpf(_arms[0].rotation.x, rx * 0.85, _hold)
			_arms[0].rotation.z = lerpf(_arms[0].rotation.z, 0.16, _hold)
			_arms[1].rotation.z = lerpf(_arms[1].rotation.z, -0.12, _hold)
			_head.rotation.x += 0.12 * pour * _hold
		elif _hold_pose == "offer":
			# l'offerta: zampine protese davanti al petto (visibili, mai
			# dietro la testona) e l'inchino gentile del capo (pour)
			var ox := 1.35 + sin(_t * 1.9) * 0.02
			_arms[0].rotation.x = lerpf(_arms[0].rotation.x, ox, _hold)
			_arms[1].rotation.x = lerpf(_arms[1].rotation.x, ox + 0.03, _hold)
			_arms[0].rotation.z = lerpf(_arms[0].rotation.z, 0.16, _hold)
			_arms[1].rotation.z = lerpf(_arms[1].rotation.z, -0.16, _hold)
			_head.rotation.x += 0.24 * pour * _hold
		elif _hold_pose == "letter":
			# la letterina: il foglio tra le zampine all'altezza del
			# musetto, con un respiro appena percettibile
			var fx := 1.5 + sin(_t * 1.7) * 0.02
			_arms[0].rotation.x = lerpf(_arms[0].rotation.x, fx, _hold)
			_arms[1].rotation.x = lerpf(_arms[1].rotation.x, fx + 0.02, _hold)
			_arms[0].rotation.z = lerpf(_arms[0].rotation.z, 0.13, _hold)
			_arms[1].rotation.z = lerpf(_arms[1].rotation.z, -0.13, _hold)
			# pour = il progresso di lettura: la testolina scende riga per
			# riga, e ogni riga è uno sguardo che SCORRE da sinistra a
			# destra (il plateau dello smoothstep dà lo scatto del ritorno
			# a capo). Qui la testa va PILOTATA, non sommata: il vagare
			# dello sguardo da ferma (±0.22 sulla y) coprirebbe tutto il
			# racconto della lettura.
			var righe := clampf(pour, 0.0, 0.999) * 3.0
			var scorri: float = smoothstep(0.12, 0.88, fmod(righe, 1.0))
			var firma: float = smoothstep(0.9, 1.0, pour)
			var giu := 0.24 + floorf(righe) * 0.04
			_head.rotation.x = lerpf(_head.rotation.x,
					lerpf(giu, -0.06, firma), _hold)
			_head.rotation.y = lerpf(_head.rotation.y,
					lerpf(0.16, -0.16, scorri) * (1.0 - firma), _hold)
			# ...e alla firma il sorrisino: la testa si rialza inclinata
			_head.rotation.z = lerpf(_head.rotation.z, 0.22 * firma, _hold)
		else:
			var hx: float
			var hz: float
			var destra_extra := 0.04
			if _hold_pose == "pour":
				# la versata: avambracci avanti, si piegano col getto; la
				# zampa destra (che regge il bricco) guida di un soffio
				hx = 0.6 + pour * 0.24 + sin(_t * 2.0) * 0.02
				hz = 0.1
				destra_extra = 0.08
			else:
				hx = 1.02 + sin(_t * 1.8) * 0.03 + (0.14 if _blowing else 0.0)
				hz = 0.2
			_arms[0].rotation.x = lerpf(_arms[0].rotation.x, hx, _hold)
			_arms[1].rotation.x = lerpf(_arms[1].rotation.x, hx + destra_extra, _hold)
			_arms[0].rotation.z = lerpf(_arms[0].rotation.z, hz, _hold)
			_arms[1].rotation.z = lerpf(_arms[1].rotation.z, -hz, _hold)
	elif _hold_target == 0.0:
		# cintura e bretelle: se una scena dimentica l'accovacciata,
		# il corpo torna su da solo
		crouch = lerpf(crouch, 0.0, 1.0 - exp(-6.0 * delta))
	if _pose == "sleep":
		# respiro lento e profondo, occhi chiusi, sogni che salgono
		position.y = sin(_t * 1.4) * 0.028
		_zzz_t += delta
		if _zzz_t > 1.7:
			_zzz_t = 0.0
			_spawn_zzz()
	elif _pose == "stargaze":
		# sdraiata a pancia in su nell'erba, occhioni pieni di stelle
		position.y = 0.34 + sin(_t * 1.3) * 0.018
		_head.rotation = Vector3(-0.25 + sin(_t * 0.5) * 0.03, sin(_t * 0.3) * 0.08, 0)
	elif _pose == "soak":
		# a mollo fino al musetto: occhi socchiusi beati, dondolio d'acqua
		position.y = -0.4 + sin(_t * 1.1) * 0.022
		_head.rotation = Vector3(-0.08 + sin(_t * 0.7) * 0.03, sin(_t * 0.4) * 0.1, 0)

	# il volto vivo: scelgo l'espressione dallo stato e aggiorno il motore
	# DOPO aver posato testa e corpo (così lo sguardo legge la testa finale)
	_update_face(delta)


# Sceglie l'espressione facciale dallo stato corrente e la passa al motore
# del volto, che la fonde dolcemente e ci mette la vita (ammicco, sguardo,
# micro-movimenti). Un solo punto di verità: niente più pokate sparse.
func _update_face(delta: float) -> void:
	if _face == null:
		return
	if is_anomalous():
		return   # durante l'anomalia il viso lo pilota _update_anomaly

	var expr := "neutro"
	var inten := 1.0
	if _blowing:
		expr = "soffio"
	elif _pose == "sleep":
		expr = "dorme"
	elif _pose == "soak":
		expr = "beato"
	elif _pose == "stargaze":
		expr = "meraviglia"
	elif joy > 0.05:
		expr = "gioia"
		inten = clampf(joy, 0.35, 1.0)
	elif _hold > 0.5 and _hold_pose == "letter":
		# lettura: concentrata riga per riga, poi il sorrisino alla firma
		expr = "felice" if smoothstep(0.9, 1.0, pour) > 0.5 else "concentrato"
	elif _hold > 0.5 and (_hold_pose == "offer" or _hold_pose == "reach"):
		expr = "felice"
	elif _tired:
		expr = "assonnato"
	elif _squinting:
		expr = "sforzo"
	elif _wave_t < 1.5:
		expr = "felice"
	elif _walk > 0.45:
		expr = "felice"
		inten = 0.45
	_face.set_expression(expr, inten)

	# lo sguardo: verso la camera durante il saluto (presenza), altrimenti
	# vaga sognante — mai un laser puntato addosso in continuazione
	if _wave_t < 1.5:
		var vp := get_viewport()
		var cam := vp.get_camera_3d() if vp else null
		if cam:
			_face.look_at_node(cam)
		else:
			_face.clear_gaze()
	else:
		_face.clear_gaze()

	# la testolina si inclina con l'espressione (curiosità, tenerezza): è il
	# suggerimento del volto, che applico alla MIA testa (già posata sopra).
	# Non è cumulativo: _head.rotation viene riscritto ogni frame prima di qui.
	_head.rotation.z += _face.head_tilt()

	_face.update(delta)


func _update_ear_twitch(delta: float) -> void:
	if _twitch_t < 0.0:
		_twitch_value = 0.0
		_next_twitch -= delta
		if _next_twitch <= 0.0:
			_twitch_t = 0.0
			_twitch_ear = _ears[0] if randf() < 0.5 else _ears[1]
			_next_twitch = randf_range(3.0, 9.0)
		return
	_twitch_t += delta
	var p := _twitch_t / 0.35
	if p >= 1.0:
		_twitch_t = -1.0
		_twitch_value = 0.0
		return
	_twitch_value = sin(p * PI * 3.0) * (1.0 - p) * 0.35


# Il lato horror di Mochi. Dormiente finché anomalies_enabled è false.
func _update_anomaly(delta: float) -> void:
	if not anomalies_enabled:
		return
	if _anomaly_t < 0.0:
		_next_anomaly -= delta
		if _next_anomaly <= 0.0:
			_anomaly_t = 0.0
			_next_anomaly = randf_range(20.0, 45.0)
			# il vuoto: occhi neri spalancati, niente luci, niente bocca
			_eye_mat.albedo_color = EYE_VOID
			for h in _highlights:
				h.visible = false
			for m in _mouths.values():
				(m as Node3D).visible = false
			if _mouth_open:
				_mouth_open.visible = false
			for i in _eyes.size():
				_eyes[i].scale = Vector3(1.18, 1.25, 1.0)
				if i < _eyeballs.size():
					_eyeballs[i].visible = true
				if i < _happy.size():
					_happy[i].visible = false
				if i < _squints.size():
					_squints[i].visible = false
			anomaly_started.emit()
		return

	_anomaly_t += delta

	# fissa la camera, immobile
	var cam := get_viewport().get_camera_3d()
	if cam:
		_head.look_at(cam.global_position, Vector3.UP)

	var duration := _anomaly_duration_override if _anomaly_duration_override > 0.0 else ANOMALY_DURATION
	if _anomaly_t >= duration:
		_anomaly_t = -1.0
		_anomaly_duration_override = -1.0
		# torna tutto: bocca e forme degli occhi le ripristina da sé il
		# prossimo _face.update (quando non è più anomala)
		_eye_mat.albedo_color = EYE
		for h in _highlights:
			h.visible = true
		for eye in _eyes:
			eye.scale = Vector3.ONE
		anomaly_ended.emit()
