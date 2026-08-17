extends Node3D

## Meteo gentile. Ogni tanto arriva una pioggerella — mai un temporale:
## il cielo si ammorbidisce in grigio-lavanda, le gocce scendono sottili
## (e si fermano sui tetti: dentro casa non piove, si sente solo il
## tamburellare ovattato), l'erba si scurisce e fa splash sotto i passi,
## e il camino diventa il posto dove stare. Quando smette, se è giorno,
## un arcobaleno si distende sul villaggio e poi svanisce piano.

const RAIN_CLEAR_MIN := 100.0
const RAIN_CLEAR_MAX := 220.0
const RAIN_DUR_MIN := 45.0
const RAIN_DUR_MAX := 75.0
const RAINBOW_DUR := 24.0

var _player: Node3D
var _daynight: Node3D
var _build: Node3D
var _sfx
var _ground_mat: ShaderMaterial

var _state := "clear"          # clear | rain | rainbow
var _timer := 0.0
var _gloom := 0.0              # lerp morbido verso il target
var _gloom_target := 0.0
var _wetness := 0.0
var _muffled := false
var _snowing := false          # d'inverno la precipitazione è una NEVICATA:
                               # fiocchi lenti e silenzio, niente erba zuppa

var _rain: GPUParticles3D
var _rain_pm: ParticleProcessMaterial
var _rain_quad: QuadMesh
var _rain_mat: StandardMaterial3D
var _splash: GPUParticles3D
var _rainbow: MeshInstance3D
var _rainbow_mat: StandardMaterial3D

# la nebbiolina del mattino d'autunno: veli bassi che il sole scioglie
var _mist: GPUParticles3D
var _mist_mat: StandardMaterial3D
var _misty := false
var _vento := 1.0              # la forza del vento di adesso, che insegue il cielo


func _ready() -> void:
	add_to_group("weather")
	_player = get_node_or_null("%Player")
	_daynight = get_node_or_null("../DayNight")
	_build = get_node_or_null("../BuildSystem")
	_sfx = get_node_or_null(^"/root/Sfx")
	var floor_mesh := get_node_or_null("../Floor/MeshInstance3D") as MeshInstance3D
	if floor_mesh:
		_ground_mat = floor_mesh.get_surface_override_material(0) as ShaderMaterial
	_build_rain()
	_build_splash()
	_build_rainbow()
	_build_mist()
	_timer = randf_range(70.0, 130.0)


func is_raining() -> bool:
	return _state == "rain"


## Vero mentre la precipitazione d'inverno scende fitta: è la finestra
## in cui il bestiario fa uscire la farfalla di neve.
func is_snowing() -> bool:
	return _state == "rain" and _snowing


## Vero finché l'erba è zuppa (anche un po' dopo che ha smesso).
func is_wet() -> bool:
	return _wetness > 0.25


## Quanto tira il vento, adesso: 1 = la brezza di un giorno sereno.
## PURA (entra lo stato del cielo, esce un numero): la prova il test.
static func forza_del_vento(stato: String, nevica: bool, nebbia: bool) -> float:
	if nebbia:
		return 0.45      # nella nebbia l'aria si ferma: è metà del suo effetto
	if stato == "rain":
		return 1.15 if nevica else 1.8   # la neve scende piano, la pioggia no
	if stato == "rainbow":
		return 0.8       # dopo l'acquazzone il mondo tira il fiato
	return 1.0


func _vento_target() -> float:
	return forza_del_vento(_state, _snowing, _misty)


## IL VENTO DI ADESSO — e questa è la sua unica casa. Il numero che di qui
## parte verso gli shader (il globale `vento_forza`) è lo stesso che
## leggono le corde vive e il rimbalzello: chi lo vuole lo chiede QUI.
##
## In particolare non lo si riprende dal RenderingServer:
## `global_shader_parameter_get()` è una lettura da EDITOR e a runtime NON
## RISPONDE — misurato nel MainLevel vero col cielo a 1.786, torna `<null>`
## — lasciando un errore per fotogramma nel log (1710 righe in quattro
## minuti) e 283 µs di fotogramma buttati a ogni chiamata. Le corde vive lo
## facevano a ogni `_process`: hanno dondolato nella brezza del sereno
## anche sotto l'acquazzone, per quanto è vecchia quella riga.
func vento() -> float:
	return _vento


## Vero mentre la nebbiolina del mattino d'autunno avvolge il villaggio:
## la finestra per le eventuali specie della nebbia (bestiario).
func is_misty() -> bool:
	return _misty


## Quando la nebbiolina ha diritto di esserci: le mattine d'autunno col
## cielo sereno, dal risveglio finché il sole non si alza a scioglierla.
## PURA: entra l'ora del mondo, esce un sì o no (la verifica il test).
static func nebbia_del_mattino(stagione: int, ora: float, sereno: bool) -> bool:
	return stagione == 2 and sereno and ora >= 0.27 and ora <= 0.40


## Quante pozzanghere lascia un prato bagnato così (0..1). Sotto un
## quarto di zuppo non si raccoglie niente; da lì lo specchio cresce.
## PURA: entra il bagnato, esce l'acqua raccolta (la verifica il test).
static func pozzanghere_da_bagnato(bagnato: float) -> float:
	return smoothstep(0.25, 0.9, bagnato)


# ---------------------------------------------------------------- ciclo

func _process(delta: float) -> void:
	_timer -= delta
	match _state:
		"clear":
			if _timer <= 0.0:
				_start_rain()
		"rain":
			if _timer <= 0.0:
				_stop_rain()
		"rainbow":
			if _timer <= 0.0:
				_end_rainbow()

	# il cielo si copre e si scopre con dolcezza
	_gloom = lerpf(_gloom, _gloom_target, 1.0 - exp(-0.8 * delta))
	if _daynight:
		_daynight.weather_gloom = _gloom

	# la terra si inzuppa piano e asciuga ancora più piano (la neve invece
	# non bagna: si posa)
	var piove := _state == "rain" and not _snowing
	var wet_target := 1.0 if piove else 0.0
	var wet_k := 0.12 if piove else 0.035
	_wetness = lerpf(_wetness, wet_target, 1.0 - exp(-wet_k * delta))
	if _ground_mat:
		_ground_mat.set_shader_parameter("wetness", _wetness)
		# le POZZANGHERE si riempiono col prato zuppo e si ritirano con lui
		# (l'asciugatura lenta di _wetness fa arretrare la soglia: gli
		# specchi si restringono dagli orli, come quelli veri); mentre
		# piove l'acqua si increspa ad anelli, appena smette fa da specchio
		_ground_mat.set_shader_parameter("pozzanghere", pozzanghere_da_bagnato(_wetness))
		_ground_mat.set_shader_parameter("pioggia_cade", 1.0 if piove else 0.0)
	# anche i fili d'erba si inzuppano (rugiada che scintilla)
	RenderingServer.global_shader_parameter_set("erba_bagnata", _wetness)

	# IL VENTO DEL MOMENTO. Un solo numero che l'erba, il bucato e le chiome
	# leggono insieme (shaders/vento.gdshaderinc): quando il cielo si copre
	# il mondo INTERO comincia a muoversi di più, e nella nebbiolina del
	# mattino l'aria si ferma — è quella quiete a far sembrare la nebbia
	# nebbia. Si arriva sempre per gradi: un vento che scatta si vede.
	_vento = lerpf(_vento, _vento_target(), 1.0 - exp(-0.5 * delta))
	RenderingServer.global_shader_parameter_set("vento_forza", _vento)

	# la nebbiolina: mattine d'autunno serene; il sole alto la scioglie
	var ora := float(_daynight.get("time")) if _daynight else 0.5
	var stagione := int(_daynight.get_season()) if _daynight \
			and _daynight.has_method("get_season") else 0
	var vuole_nebbia := nebbia_del_mattino(stagione, ora, _state == "clear")
	if vuole_nebbia != _misty:
		_misty = vuole_nebbia
		_show_mist(_misty)
	# la nebbia vela appena il cielo, ma solo quando il cielo è suo
	if _state == "clear":
		_gloom_target = 0.22 if _misty else 0.0

	if _player == null:
		return

	# la pioggia segue il giocatore (particelle in spazio mondo)
	var pp := _player.global_position
	_rain.position = pp + Vector3(0, 7.5, 0)
	_splash.position = Vector3(pp.x, 0.03, pp.z)
	_mist.position = Vector3(pp.x, 0.55, pp.z)

	# sotto un tetto: niente tonfi vicini e pioggia ovattata (la neve non
	# fa rumore né anellini: non c'è nulla da ovattare)
	if _state == "rain" and not _snowing:
		var covered := _under_roof(pp)
		_splash.emitting = not covered
		if covered != _muffled:
			_muffled = covered
			if _sfx:
				_sfx.set_rain_muffled(covered)


func _under_roof(pos: Vector3) -> bool:
	if _build == null:
		return false
	var cell := Vector2i(roundi(pos.x), roundi(pos.z))
	# la copertura completa la sa il BuildSystem: tetto a terra,
	# solaio o tetto del piano di sopra
	return bool(_build.call("has_cover", cell))


func _start_rain() -> void:
	_state = "rain"
	# d'inverno la stessa perturbazione è una NEVICATA fitta: fiocchi tondi
	# che scendono piano, in silenzio — la finestra della farfalla di neve
	_snowing = _daynight != null and _daynight.has_method("get_season") \
			and int(_daynight.get_season()) == 3
	_apply_precip_look()
	_timer = randf_range(RAIN_DUR_MIN, RAIN_DUR_MAX)
	_gloom_target = 0.7 if _snowing else 1.0
	_rain.emitting = true
	_splash.emitting = not _snowing
	if _sfx and not _snowing:
		_sfx.set_rain(true)
	_set_forest_shafts(false)


# veste le particelle da pioggia (strisce rapide) o da neve (fiocchi lenti)
func _apply_precip_look() -> void:
	if _rain_pm == null:
		return
	if _snowing:
		_rain_pm.initial_velocity_min = 0.9
		_rain_pm.initial_velocity_max = 1.5
		_rain_pm.gravity = Vector3(0.3, -0.5, 0.15)
		_rain_pm.particle_flag_align_y = false
		_rain_quad.size = Vector2(0.055, 0.055)
		_rain_mat.albedo_color = Color(1, 1, 1, 0.9)
		_rain.lifetime = 9.0
	else:
		_rain_pm.initial_velocity_min = 5.2
		_rain_pm.initial_velocity_max = 6.4
		_rain_pm.gravity = Vector3(0.5, -2.2, 0.25)
		_rain_pm.particle_flag_align_y = true
		_rain_quad.size = Vector2(0.02, 0.42)
		_rain_mat.albedo_color = Color(1, 1, 1, 0.55)
		_rain.lifetime = 1.7


func _stop_rain() -> void:
	_rain.emitting = false
	_splash.emitting = false
	_gloom_target = 0.0
	if _muffled:
		_muffled = false
		if _sfx:
			_sfx.set_rain_muffled(false)  # la prossima pioggia parte pulita
	if _sfx:
		_sfx.set_rain(false)
	# l'arcobaleno appare solo con la luce del giorno (e mai dopo la neve)
	var is_day: bool = _daynight == null or not _daynight.is_night()
	if is_day and not _snowing:
		_state = "rainbow"
		_timer = RAINBOW_DUR
		_show_rainbow(true)
		_set_forest_shafts(true)
	else:
		_state = "clear"
		_timer = randf_range(RAIN_CLEAR_MIN, RAIN_CLEAR_MAX)
		if is_day:
			_set_forest_shafts(true)   # dopo la neve i fasci tornano, senza arcobaleno
	_snowing = false


# con il cielo coperto i fasci di luce del bosco non hanno senso
func _set_forest_shafts(on: bool) -> void:
	var cozy := get_node_or_null("../CozyWorld")
	if cozy == null:
		return
	var mat: StandardMaterial3D = cozy.get("_shaft_mat")
	if mat == null:
		return
	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.32 if on else 0.0, 2.5)


func _end_rainbow() -> void:
	_state = "clear"
	_timer = randf_range(RAIN_CLEAR_MIN, RAIN_CLEAR_MAX)
	_show_rainbow(false)


func _show_rainbow(on: bool) -> void:
	if on:
		_rainbow.visible = true
	var tw := create_tween()
	tw.tween_property(_rainbow_mat, "albedo_color:a", 0.30 if on else 0.0, 3.5) \
			.set_trans(Tween.TRANS_SINE)
	if not on:
		tw.tween_callback(func(): _rainbow.visible = false)


# ---------------------------------------------------------------- pioggia

func _build_rain() -> void:
	# goccia: striscia verticale sfumata, allineata alla velocità di caduta
	var tex := GradientTexture2D.new()
	tex.width = 8
	tex.height = 64
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	grad.colors = PackedColorArray([
		Color(0.85, 0.9, 1.0, 0.0), Color(0.85, 0.9, 1.0, 0.55),
		Color(0.85, 0.9, 1.0, 0.55), Color(0.85, 0.9, 1.0, 0.0)])
	tex.gradient = grad

	var quad := QuadMesh.new()
	quad.size = Vector2(0.02, 0.42)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.albedo_color = Color(1, 1, 1, 0.55)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(11.0, 0.4, 11.0)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 3.0
	pm.initial_velocity_min = 5.2
	pm.initial_velocity_max = 6.4
	pm.gravity = Vector3(0.5, -2.2, 0.25)
	pm.scale_min = 0.7
	pm.scale_max = 1.15
	pm.particle_flag_align_y = true
	# le tegole hanno GPUParticlesCollisionBox3D: la goccia sparisce sul tetto
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT

	# le maniglie per rivestire la stessa perturbazione da neve (inverno)
	_rain_pm = pm
	_rain_quad = quad
	_rain_mat = mat

	_rain = GPUParticles3D.new()
	_rain.amount = 520
	_rain.lifetime = 1.7
	_rain.local_coords = false
	_rain.emitting = false
	_rain.process_material = pm
	_rain.draw_pass_1 = quad
	_rain.visibility_aabb = AABB(Vector3(-14, -12, -14), Vector3(28, 16, 28))
	add_child(_rain)


func _build_splash() -> void:
	# il tonfo a terra: un anellino che sboccia e svanisce
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 0.7, 1.0])
	grad.colors = PackedColorArray([
		Color(0.9, 0.95, 1.0, 0.0), Color(0.9, 0.95, 1.0, 0.0),
		Color(0.9, 0.95, 1.0, 0.55), Color(0.9, 0.95, 1.0, 0.0)])
	tex.gradient = grad

	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(8.5, 0.02, 8.5)
	pm.direction = Vector3.ZERO
	pm.spread = 0.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.particle_flag_rotate_y = true
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	# l'anello si allarga mentre svanisce
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.3))
	sc.add_point(Vector2(1.0, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct

	_splash = GPUParticles3D.new()
	_splash.amount = 70
	_splash.lifetime = 0.5
	_splash.local_coords = false
	_splash.emitting = false
	_splash.process_material = pm
	_splash.draw_pass_1 = quad
	_splash.visibility_aabb = AABB(Vector3(-10, -1, -10), Vector3(20, 3, 20))
	add_child(_splash)


# ---------------------------------------------------------------- nebbiolina

func _build_mist() -> void:
	# veli tondi, larghi e quasi trasparenti che scivolano radenti al prato
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(0.94, 0.93, 0.97, 0.5), Color(0.94, 0.93, 0.97, 0.28),
		Color(0.94, 0.93, 0.97, 0.0)])
	tex.gradient = grad

	var quad := QuadMesh.new()
	quad.size = Vector2(3.6, 1.5)
	_mist_mat = StandardMaterial3D.new()
	_mist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mist_mat.albedo_texture = tex
	_mist_mat.albedo_color = Color(1, 1, 1, 0.0)   # si alza con la dissolvenza
	_mist_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mist_mat.no_depth_test = false
	quad.material = _mist_mat

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(10.0, 0.25, 10.0)
	pm.direction = Vector3(1, 0, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.12
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.7
	pm.scale_max = 1.6
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1),
			Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex

	_mist = GPUParticles3D.new()
	_mist.amount = 26
	_mist.lifetime = 11.0
	_mist.preprocess = 6.0        # la nebbia c'è già, non "parte"
	_mist.local_coords = false
	_mist.emitting = false
	_mist.process_material = pm
	_mist.draw_pass_1 = quad
	_mist.position.y = 0.55
	_mist.visibility_aabb = AABB(Vector3(-13, -2, -13), Vector3(26, 5, 26))
	add_child(_mist)


func _show_mist(on: bool) -> void:
	if on:
		_mist.emitting = true
		var visitors := get_node_or_null("../Visitors")
		if visitors:
			visitors.call("_show_toast", L10n.t("La nebbiolina del mattino avvolge il villaggio…"))
	var tw := create_tween()
	tw.tween_property(_mist_mat, "albedo_color:a", 0.55 if on else 0.0, 4.0) \
			.set_trans(Tween.TRANS_SINE)
	if not on:
		tw.tween_callback(func(): _mist.emitting = false)


# ---------------------------------------------------------------- arcobaleno

func _build_rainbow() -> void:
	# arco a 7 bande pastello, costruito a mano con vertex color; le
	# estremità sfumano dolcemente verso il prato
	var bands := [
		Color(1.0, 0.5, 0.5), Color(1.0, 0.72, 0.45), Color(1.0, 0.95, 0.55),
		Color(0.6, 0.9, 0.55), Color(0.5, 0.8, 0.95), Color(0.55, 0.62, 0.95),
		Color(0.75, 0.55, 0.9),
	]
	var radius := 24.0
	var band_w := 0.62
	var segments := 48

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in bands.size():
		var r0 := radius - b * band_w
		var r1 := r0 - band_w
		var col: Color = bands[b]
		for s in segments:
			var a0 := PI * float(s) / float(segments)
			var a1 := PI * float(s + 1) / float(segments)
			var fade0 := clampf(sin(a0) * 2.2, 0.0, 1.0)
			var fade1 := clampf(sin(a1) * 2.2, 0.0, 1.0)
			var v00 := Vector3(cos(a0) * r0, sin(a0) * r0 * 0.82, 0)
			var v01 := Vector3(cos(a0) * r1, sin(a0) * r1 * 0.82, 0)
			var v10 := Vector3(cos(a1) * r0, sin(a1) * r0 * 0.82, 0)
			var v11 := Vector3(cos(a1) * r1, sin(a1) * r1 * 0.82, 0)
			var c0 := Color(col, fade0)
			var c1 := Color(col, fade1)
			st.set_color(c0); st.add_vertex(v00)
			st.set_color(c1); st.add_vertex(v10)
			st.set_color(c0); st.add_vertex(v01)
			st.set_color(c1); st.add_vertex(v10)
			st.set_color(c1); st.add_vertex(v11)
			st.set_color(c0); st.add_vertex(v01)

	_rainbow_mat = StandardMaterial3D.new()
	_rainbow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rainbow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rainbow_mat.vertex_color_use_as_albedo = true
	_rainbow_mat.albedo_color = Color(1, 1, 1, 0.0)
	_rainbow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(_rainbow_mat)

	_rainbow = MeshInstance3D.new()
	_rainbow.mesh = st.commit()
	_rainbow.position = Vector3(2.0, 0.0, -30.0)
	_rainbow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rainbow.visible = false
	add_child(_rainbow)


# ---------------------------------------------------------------- debug CLI

func debug_rain(on: bool) -> void:
	if on:
		_start_rain()
		_gloom = 0.7
		_wetness = 0.6
	else:
		_timer = 0.0
		_stop_rain()


func debug_rainbow() -> void:
	_state = "rainbow"
	_timer = RAINBOW_DUR
	_gloom_target = 0.0
	_show_rainbow(true)


func debug_mist(on: bool) -> void:
	_misty = on
	_show_mist(on)
