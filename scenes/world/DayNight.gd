class_name DayNight
extends Node3D

## Il ciclo giorno/notte di Chibi Crossing.
##
## time: 0 = mezzanotte · 0.25 = alba · 0.5 = mezzogiorno · 0.75 = tramonto.
## Il sole attraversa il cielo da est a ovest (le ombre girano con lui),
## poi sorge la luna: il cielo scivola tra quattro palette, all'orizzonte
## brilla il bagliore dell'alba/tramonto, si accendono le stelle e le
## lucciole, e il mondo cambia abitanti (pollini e farfalle di giorno).
## I dischi di sole e luna nel cielo sono disegnati dal ProceduralSky.

signal day_changed(day: int)

@export var cycle_seconds := 240.0
@export var time := 0.38

## Il calendario del villaggio: quante mattine sono sorte. Persistito nel
## JSON del villaggio insieme ai pezzi piazzati.
var day := 1

## 0..1, pilotato dal Weather: quanto il cielo è coperto dalla pioggia.
## Ammorbidisce luce e colori verso un grigio-lavanda, mai minaccioso.
var weather_gloom := 0.0

## L'ora a cui ci si sveglia dopo una notte di sonno: poco dopo l'alba,
## col sole basso e dorato.
const MORNING := 0.29

const DAY_TOP := Color(0.4, 0.62, 0.87)
const DAY_HORIZON := Color(0.9, 0.84, 0.72)
const NIGHT_TOP := Color(0.045, 0.065, 0.17)
const NIGHT_HORIZON := Color(0.1, 0.13, 0.27)
const DUSK_GLOW := Color(1.0, 0.55, 0.35)
const DAY_FOG := Color(0.93, 0.89, 0.79)
const NIGHT_FOG := Color(0.07, 0.1, 0.2)
const DAY_GROUND := Color(0.5, 0.58, 0.48)
const NIGHT_GROUND := Color(0.05, 0.06, 0.12)

## La LUCE D'OMBRA. Nei giochi cozy di riferimento l'ombra non è "meno
## verde": è di un altro colore. Qui l'ambiente è una luce dedicata —
## tutto ciò che il sole non tocca viene dipinto da questa: azzurro-
## lavanda di giorno, lilla alla golden hour, indaco profondo la notte.
const AMB_DAY := Color(0.60, 0.66, 0.86)
const AMB_DUSK := Color(0.76, 0.55, 0.72)
const AMB_NIGHT := Color(0.26, 0.32, 0.55)
const AMB_RAIN := Color(0.71, 0.72, 0.78)

var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _env: Environment
var _sky: ShaderMaterial
var _cozy: Node3D
var _stars_mat: StandardMaterial3D
var _fireflies: GPUParticles3D
var _night := false

## Le direzioni delle 260 stelle della cupola (raggio 52): il cielo che
## le costellazioni di Mochi sanno leggere.
var star_dirs: PackedVector3Array = []


func _ready() -> void:
	add_to_group("persistable")
	_sun = get_node("../Sun")
	var we: WorldEnvironment = get_node("../WorldEnvironment")
	_env = we.environment
	_sky = _env.sky.sky_material as ShaderMaterial
	_cozy = get_node_or_null("../CozyWorld")
	_build_moon()
	_build_stars()
	_build_fireflies()
	_apply()


## Salta a un'ora precisa (0..1). Usato anche dalla verifica CLI.
func set_time(t: float) -> void:
	var nt := fposmod(t, 1.0)
	_check_new_day(time, nt)
	time = nt
	_apply()


# un nuovo mattino: attraversamento naturale dell'alba, oppure il salto
# all'indietro del sonno (la sveglia atterra nella finestra del mattino)
func _check_new_day(prev: float, t: float) -> void:
	var crossed := prev < MORNING and t >= MORNING and t - prev < 0.5
	var jumped := t < prev and t >= 0.25 and t <= 0.42
	if crossed or jumped:
		day += 1
		day_changed.emit(day)
		var bs: Node = get_tree().get_first_node_in_group("build_system")
		if bs:
			bs._save_village()


func save_extra() -> Dictionary:
	return {"day": day}


func load_extra(data: Dictionary) -> void:
	day = maxi(1, int(data.get("day", day)))


## Vero quando il mondo è in modalità notte (stelle, lucciole, finestre accese).
func is_night() -> bool:
	return _night


func _process(delta: float) -> void:
	var nt := fposmod(time + delta / cycle_seconds, 1.0)
	_check_new_day(time, nt)
	time = nt
	_apply()


func _build_moon() -> void:
	_moon = DirectionalLight3D.new()
	_moon.light_color = Color(0.66, 0.74, 0.92)
	_moon.light_energy = 0.0
	_moon.shadow_enabled = false
	_moon.shadow_blur = 2.5
	_moon.directional_shadow_max_distance = 40.0
	add_child(_moon)


# cupola di stelle: MultiMesh di sferette emissive, alpha animata di notte
func _build_stars() -> void:
	_stars_mat = StandardMaterial3D.new()
	_stars_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_stars_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_stars_mat.albedo_color = Color(1.0, 0.97, 0.9, 0.0)

	var star := SphereMesh.new()
	star.radius = 0.16
	star.height = 0.32
	star.radial_segments = 8
	star.rings = 4
	star.material = _stars_mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = star
	mm.instance_count = 260
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in mm.instance_count:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.12, 1.0), rng.randf_range(-1, 1)).normalized()
		# le direzioni restano leggibili: le costellazioni si disegnano qui
		star_dirs.append(dir)
		var star_basis := Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.5, 1.7))
		mm.set_instance_transform(i, Transform3D(star_basis, dir * 52.0))

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# lucciole: motes caldi che lampeggiano piano, solo di notte
func _build_fireflies() -> void:
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var cg := Gradient.new()
	cg.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	cg.colors = PackedColorArray([
		Color(0.92, 1.0, 0.66, 0.95), Color(0.92, 1.0, 0.66, 0.4), Color(0.92, 1.0, 0.66, 0.0)])
	tex.gradient = cg

	var quad := QuadMesh.new()
	quad.size = Vector2(0.075, 0.075)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(15.0, 1.0, 15.0)
	pm.direction = Vector3(0, 0, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.8
	pm.turbulence_noise_speed = Vector3(0.3, 0.2, 0.3)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	# lampeggio: l'alpha pulsa più volte nella vita della particella
	var blink := Gradient.new()
	blink.offsets = PackedFloat32Array([0.0, 0.12, 0.24, 0.4, 0.55, 0.7, 0.85, 1.0])
	blink.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.12),
		Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.15), Color(1, 1, 1, 1.0),
		Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.0)])
	var blink_tex := GradientTexture1D.new()
	blink_tex.gradient = blink
	pm.color_ramp = blink_tex

	# coprono prato e foresta: stessa quantità, area più ampia = più rade
	# nel prato, più fitte percepite nel bosco dove la vista è chiusa
	pm.emission_box_extents = Vector3(26.0, 1.2, 26.0)

	_fireflies = GPUParticles3D.new()
	_fireflies.amount = 46
	_fireflies.lifetime = 7.0
	_fireflies.preprocess = 4.0
	_fireflies.local_coords = false
	_fireflies.emitting = false
	_fireflies.process_material = pm
	_fireflies.draw_pass_1 = quad
	_fireflies.position = Vector3(0, 0.9, -14)
	_fireflies.visibility_aabb = AABB(Vector3(-28, -2, -28), Vector3(56, 8, 56))
	add_child(_fireflies)


func _apply() -> void:
	var a := (time - 0.25) * TAU
	var elev := sin(a)
	var day_f := smoothstep(-0.18, 0.22, elev)
	# campana del bagliore: massima quando il sole sfiora l'orizzonte
	var glow_bell := exp(-pow(elev * 3.6, 2.0))

	var g := weather_gloom

	# --- sole: elevazione + azimut che spazza da est a ovest.
	# Più forte e più CALDO di prima: il contrasto col blu dell'ombra
	# è quello che dà volume al giorno ---
	var day_prog := clampf((time - 0.25) / 0.5, 0.0, 1.0)
	_sun.rotation = Vector3(-(0.12 + 0.9 * maxf(elev, 0.0)), 1.5 - day_prog * 2.4, 0.0)
	# (all'orizzonte ARANCIO dorato, mai rosso: i marroni caldi del mondo
	# reggono l'arancio ma virano al rosso acceso con troppa poca G)
	_sun.light_energy = smoothstep(-0.04, 0.18, elev) * 1.55 * (1.0 - 0.55 * g)
	_sun.light_color = Color(1.0, 0.70, 0.46).lerp(Color(1.0, 0.90, 0.72), clampf(elev * 2.2, 0.0, 1.0))
	_sun.shadow_enabled = elev > 0.02

	# --- luna: sorge quando il sole tramonta ---
	var melev := -elev
	_moon.rotation = Vector3(-(0.2 + 0.7 * maxf(melev, 0.0)), -0.8, 0.0)
	_moon.light_energy = smoothstep(0.0, 0.25, melev) * 0.32 * (1.0 - 0.6 * g)
	_moon.shadow_enabled = melev > 0.12

	# --- cielo (con la pioggia scivola verso un grigio-lavanda gentile) ---
	var hor := NIGHT_HORIZON.lerp(DAY_HORIZON, day_f).lerp(DUSK_GLOW, glow_bell * 0.75)
	var top := NIGHT_TOP.lerp(DAY_TOP, day_f)
	top = top.lerp(Color(0.52, 0.56, 0.66) * maxf(day_f, 0.12), g)
	hor = hor.lerp(Color(0.72, 0.73, 0.78) * maxf(day_f, 0.12), g)
	_sky.set_shader_parameter("top_color", top)
	_sky.set_shader_parameter("horizon_color", hor)
	_sky.set_shader_parameter("ground_color", NIGHT_GROUND.lerp(DAY_GROUND, day_f))

	# --- le nuvole: candide a mezzogiorno, rosa-pesca alla golden hour,
	# ardesia appena rischiarata dalla luna la notte; la pioggia le
	# gonfia (copertura su) e le ingrigisce ---
	var c_lit := Color(0.33, 0.36, 0.50).lerp(Color(1.0, 0.99, 0.95), day_f) \
			.lerp(Color(1.0, 0.80, 0.72), glow_bell * 0.85)
	var c_shade := Color(0.16, 0.19, 0.30).lerp(Color(0.74, 0.79, 0.90), day_f) \
			.lerp(Color(0.78, 0.58, 0.66), glow_bell * 0.7)
	c_lit = c_lit.lerp(Color(0.72, 0.73, 0.78), g * 0.75)
	c_shade = c_shade.lerp(Color(0.56, 0.58, 0.64), g * 0.75)
	_sky.set_shader_parameter("cloud_color", c_lit)
	_sky.set_shader_parameter("cloud_shade", c_shade)
	_sky.set_shader_parameter("cloud_cover", 0.48 + g * 0.38)

	# --- la luce d'ombra: è QUI che il giorno prende profondità.
	# Fredda quando il sole è caldo (complementari = volume); la pioggia
	# la ALZA e la ingrigisce: la luce piatta e senza ombre del nuvolo ---
	var amb := AMB_NIGHT.lerp(AMB_DAY, day_f).lerp(AMB_DUSK, glow_bell * 0.55)
	amb = amb.lerp(AMB_RAIN, g * 0.7)
	_env.ambient_light_color = amb
	_env.ambient_light_energy = (0.30 + 0.38 * day_f) * (1.0 + 0.4 * g)

	# --- nebbia e glow: alla golden hour la foschia si scalda davvero,
	# così il tramonto tinge il MONDO e non solo il cielo ---
	_env.fog_light_color = NIGHT_FOG.lerp(DAY_FOG, day_f) \
			.lerp(DUSK_GLOW, glow_bell * 0.38) \
			.lerp(Color(0.68, 0.7, 0.76) * maxf(day_f, 0.15), g * 0.8)
	_env.fog_density = 0.0012 + g * 0.0035
	_env.glow_intensity = 0.22 + (1.0 - day_f) * 0.25

	# --- stelle: si accendono quando il bagliore muore (e le nuvole coprono) ---
	_stars_mat.albedo_color.a = clampf((1.0 - day_f) - glow_bell * 0.5, 0.0, 1.0) * 0.9 * (1.0 - g)

	# --- il mondo cambia abitanti ---
	var night := day_f < 0.35
	if night != _night:
		_night = night
		_fireflies.emitting = night
		if _cozy and _cozy.has_method("set_night"):
			_cozy.set_night(night)
