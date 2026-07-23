extends Node3D

## L'onsen del bosco ♨️ — oltre la radura del falò, una pozza termale
## tra le rocce: acqua lattiginosa, vapore che sale, sassi caldi, la
## lanterna di pietra e le lucciole che ci ballano sopra di notte.
## Con E sul bordo, Mochi si immerge fino al musetto (occhi socchiusi,
## guanciotte al massimo): la stamina risale veloce, i cuoricini
## salgono col vapore. E ogni tanto un residente arriva in accappatoio
## con l'asciugamanino piegato in testa, scivola in acqua accanto a te
## e sospira in Chibiese. Amicizia da bagno condiviso: +1.

const HANDPAINT := preload("res://shaders/handpaint.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")
const UI_BROWN := Color("6a4a3a")
const CENTER := Vector3(6.0, 0.0, -53.0)
const POOL_R := 1.55

var _player: Node3D
var _mochi: Node3D
var _survival: Node
var _daynight: Node3D
var _visitors: Node
var _sfx

var _soaking := false
var _guest_cd := 12.0
var _guest: Node3D
var _heart_cd := 3.0
var _bubble_cd := 4.0
var _fireflies: GPUParticles3D

var _prompt: PanelContainer
var _prompt_label: Label


func _ready() -> void:
	add_to_group("onsen")
	position = CENTER
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_pool()
	_build_ui()
	(func():
		_player = get_node_or_null("../../Player")
		_mochi = _player.get_node_or_null("Mochi") if _player else null
		_survival = _player.get_node_or_null("SurvivalComponent") if _player else null
		_daynight = get_node_or_null("../../DayNight")
		_visitors = get_node_or_null("../../Visitors")).call_deferred()


# ---------------------------------------------------------------- il luogo

func _pm(a: Color, b: Color, grain := 3.0, amount := 0.5) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = HANDPAINT
	mat.set_shader_parameter("color_a", a)
	mat.set_shader_parameter("color_b", b)
	mat.set_shader_parameter("noise_scale", grain)
	mat.set_shader_parameter("noise_amount", amount)
	return mat


func _build_pool() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 53

	# la conca: ghiaia scura incassata nel prato e fondo di pietra
	var rim := CylinderMesh.new()
	rim.top_radius = POOL_R + 0.75
	rim.bottom_radius = POOL_R + 0.85
	rim.height = 0.05
	rim.radial_segments = 32
	var rim_mi := MeshInstance3D.new()
	rim_mi.mesh = rim
	rim_mi.material_override = _pm(Color("7a7268"), Color("635c52"), 2.0, 0.55)
	rim_mi.position = Vector3(0, 0.025, 0)
	add_child(rim_mi)
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = POOL_R + 0.2
	floor_mesh.bottom_radius = POOL_R + 0.3
	floor_mesh.height = 0.05
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	floor_mi.material_override = _pm(Color("4c463e"), Color("3c3630"), 3.0, 0.5)
	floor_mi.position = Vector3(0, 0.055, 0)
	add_child(floor_mi)

	# lo SPECCHIO D'ACQUA: lo shader dello stagno (il cielo si riflette
	# davvero) in palette termale, latte caldo sulla riva
	var water := CylinderMesh.new()
	water.top_radius = POOL_R + 0.12
	water.bottom_radius = POOL_R + 0.12
	water.height = 0.02
	water.radial_segments = 48
	var wmat := ShaderMaterial.new()
	wmat.shader = WATER_SHADER
	wmat.set_shader_parameter("shallow_col", Color(0.74, 0.87, 0.82))
	wmat.set_shader_parameter("deep_col", Color(0.3, 0.56, 0.58))
	wmat.set_shader_parameter("radius", POOL_R + 0.1)
	var wmi := MeshInstance3D.new()
	wmi.mesh = water
	wmi.material_override = wmat
	wmi.position = Vector3(0, 0.36, 0)
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wmi)

	# la corona di massi veri: sfaccettati, semi-affondati, ognuno suo
	var rock_dry := _pm(Color("a49a8c"), Color("847a6e"), 2.0, 0.5)
	var rock_dry2 := _pm(Color("b8afa0"), Color("948a7c"), 2.0, 0.5)
	var rock_wet := _pm(Color("5e564c"), Color("4a443c"), 2.5, 0.45)
	var body := StaticBody3D.new()
	add_child(body)
	for i in 12:
		var a := float(i) / 12.0 * TAU + rng.randf_range(-0.12, 0.12)
		var r := POOL_R + rng.randf_range(0.35, 0.58)
		var s := rng.randf_range(0.3, 0.55)
		var mi := MeshInstance3D.new()
		mi.mesh = _rock_mesh(s, rng.randi())
		mi.material_override = rock_dry if i % 2 == 0 else rock_dry2
		mi.position = Vector3(cos(a) * r, rng.randf_range(-0.08, 0.06), sin(a) * r)
		mi.scale = Vector3(rng.randf_range(1.0, 1.5), rng.randf_range(0.6, 0.85), rng.randf_range(0.9, 1.25))
		mi.rotation.y = rng.randf() * TAU
		add_child(mi)
		# il bordo tiene fuori chi cammina: dentro si entra solo con la E
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.95, 0.8, 0.55)
		shape.shape = box
		shape.position = Vector3(cos(a) * (POOL_R + 0.4), 0.4, sin(a) * (POOL_R + 0.4))
		shape.rotation.y = -a + PI * 0.5
		body.add_child(shape)
	# sassi bagnati, scuri, semi-sommersi lungo la linea d'acqua
	for i in 8:
		var a := float(i) / 8.0 * TAU + 0.35 + rng.randf_range(-0.15, 0.15)
		var mi := MeshInstance3D.new()
		mi.mesh = _rock_mesh(rng.randf_range(0.14, 0.24), rng.randi())
		mi.material_override = rock_wet
		mi.position = Vector3(cos(a) * (POOL_R - 0.05), rng.randf_range(0.2, 0.28), sin(a) * (POOL_R - 0.05))
		mi.scale = Vector3(1.2, 0.7, 1.0)
		mi.rotation.y = rng.randf() * TAU
		add_child(mi)
	# l'omino di pietre in equilibrio (il cairn del bagnante zen)
	var cairn_x := Vector3(1.7, 0, 1.55)
	for i in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = _rock_mesh(0.2 - i * 0.05, 400 + i)
		mi.material_override = rock_dry2
		mi.position = cairn_x + Vector3(rng.randf_range(-0.02, 0.02), 0.3 + i * 0.17, 0)
		mi.scale = Vector3(1.2, 0.6, 1.1)
		mi.rotation.y = rng.randf() * TAU
		add_child(mi)
	# un filo di schiuma dove l'acqua tocca la pietra, appena percettibile
	var foam := TorusMesh.new()
	foam.inner_radius = POOL_R + 0.05
	foam.outer_radius = POOL_R + 0.1
	foam.rings = 48
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.albedo_color = Color(1, 1, 1, 0.09)
	var foam_mi := MeshInstance3D.new()
	foam_mi.mesh = foam
	foam_mi.material_override = fmat
	foam_mi.position = Vector3(0, 0.368, 0)
	foam_mi.scale = Vector3(1, 0.05, 1)
	foam_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(foam_mi)

	# il deck d'ingresso: assi di legno vissuto su due travetti
	var wood := _pm(Color("b08a5e"), Color("8f6f4a"), 4.0, 0.55)
	var wood_dark := _pm(Color("8f6f4a"), Color("735838"), 4.0, 0.5)
	var deck := Node3D.new()
	deck.position = Vector3(-1.95, 0, -0.9)
	deck.rotation.y = 0.42
	add_child(deck)
	for i in 4:
		var plank := MeshInstance3D.new()
		var pmesh := BoxMesh.new()
		pmesh.size = Vector3(0.3, 0.05, 1.15)
		plank.mesh = pmesh
		plank.material_override = wood if i % 2 == 0 else wood_dark
		plank.position = Vector3(-0.48 + i * 0.32, 0.12, 0)
		plank.rotation.y = rng.randf_range(-0.02, 0.02)
		deck.add_child(plank)
	for sz: float in [-0.45, 0.45]:
		var beam := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size = Vector3(1.35, 0.09, 0.12)
		beam.mesh = bmesh
		beam.material_override = wood_dark
		beam.position = Vector3(0, 0.05, sz)
		deck.add_child(beam)

	# il secchiello di legno e gli asciugamanini piegati, sul deck
	var bucket := MeshInstance3D.new()
	var bk := CylinderMesh.new()
	bk.top_radius = 0.14
	bk.bottom_radius = 0.11
	bk.height = 0.16
	bucket.mesh = bk
	bucket.material_override = wood_dark
	bucket.position = Vector3(-0.35, 0.23, -0.3)
	deck.add_child(bucket)
	var terry := _pm(Color("fdf3e6"), Color("efe2d0"), 5.0, 0.35)
	for i in 2:
		var towel := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.3, 0.06, 0.22)
		towel.mesh = tm
		towel.material_override = terry
		towel.position = Vector3(0.3, 0.18 + i * 0.065, 0.28)
		towel.rotation.y = 0.3 + i * 0.2
		deck.add_child(towel)

	# felci, muschio e cespugli: il bosco abbraccia la pozza
	var moss := _pm(Color("6a8a4e"), Color("55703e"), 3.0, 0.6)
	for i in 5:
		var a := rng.randf() * TAU
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(0.16, 0.3)
		sm.height = sm.radius * 2.0
		mi.mesh = sm
		mi.material_override = moss
		mi.position = Vector3(cos(a) * (POOL_R + 0.75), 0.0, sin(a) * (POOL_R + 0.75))
		mi.scale = Vector3(1.3, 0.25, 1.1)
		add_child(mi)
	for i in 4:
		var a := 0.9 + float(i) * 1.5
		_fern(Vector3(cos(a) * (POOL_R + 1.15), 0, sin(a) * (POOL_R + 1.15)), rng)

	# la lanterna di pietra (tōrō) con la sua luce calda
	var toro := Node3D.new()
	toro.position = Vector3(2.35, 0, -1.5)
	add_child(toro)
	var stone := _pm(Color("a89e90"), Color("8a8072"), 3.0, 0.5)
	_box(toro, Vector3(0.42, 0.12, 0.42), stone, Vector3(0, 0.06, 0))
	_box(toro, Vector3(0.16, 0.5, 0.16), stone, Vector3(0, 0.42, 0))
	_box(toro, Vector3(0.36, 0.08, 0.36), stone, Vector3(0, 0.7, 0))
	var lamp_glow := StandardMaterial3D.new()
	lamp_glow.albedo_color = Color("ffd9a0")
	lamp_glow.emission_enabled = true
	lamp_glow.emission = Color("ffc978")
	lamp_glow.emission_energy_multiplier = 1.2
	var cell := MeshInstance3D.new()
	var cbox := BoxMesh.new()
	cbox.size = Vector3(0.24, 0.22, 0.24)
	cell.mesh = cbox
	cell.material_override = lamp_glow
	cell.position = Vector3(0, 0.85, 0)
	toro.add_child(cell)
	_box(toro, Vector3(0.4, 0.09, 0.4), stone, Vector3(0, 1.0, 0))
	var light := OmniLight3D.new()
	light.light_color = Color("ffc98a")
	light.light_energy = 1.1
	light.omni_range = 4.0
	light.shadow_enabled = false
	light.position = Vector3(0, 0.85, 0)
	toro.add_child(light)

	# i sassi-guado dalla radura del falò
	for i in 4:
		var step := MeshInstance3D.new()
		var sm2 := CylinderMesh.new()
		sm2.top_radius = 0.3
		sm2.bottom_radius = 0.36
		sm2.height = 0.07
		step.mesh = sm2
		step.material_override = rock_dry2
		step.position = Vector3(-2.9 - float(i) * 0.95, 0.035, -0.4 + float(i) * 0.85) \
				+ Vector3(0, 0, 2.2)
		step.rotation.y = float(i) * 0.8
		add_child(step)

	# il vapore: due colonne morbide ai lati, e la nebbiolina bassa che
	# scivola sul pelo dell'acqua
	for off in [Vector3(-1.05, 0.4, -0.75), Vector3(0.95, 0.4, -0.6)]:
		var steam := _make_steam()
		steam.position = off
		add_child(steam)
	var mist := _make_mist()
	mist.position = Vector3(0, 0.42, 0)
	add_child(mist)

	# le lucciole che ballano sull'acqua, solo di notte
	_fireflies = _make_fireflies()
	_fireflies.position = Vector3(0, 0.9, 0)
	add_child(_fireflies)


func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


# un masso vero: sfera low-poly coi vertici perturbati (deterministico
# per seed) e normali di faccia -> pietra sfaccettata, mai marshmallow
func _rock_mesh(size: float, seed_v: int) -> ArrayMesh:
	var base := SphereMesh.new()
	base.radius = size
	base.height = size * 2.0
	base.radial_segments = 8
	base.rings = 5
	var arrays := base.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var jittered := PackedVector3Array()
	jittered.resize(verts.size())
	for i in verts.size():
		var v := verts[i]
		# stesso jitter per vertici coincidenti: niente crepe
		var h := hash(Vector3i((v * 97.0).round()) + Vector3i(seed_v, 0, 0))
		var k := 1.0 + (float(h % 1000) / 1000.0 - 0.5) * 0.42
		jittered[i] = v * k
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := 0
	while tri + 2 < indices.size():
		var a := jittered[indices[tri]]
		var b := jittered[indices[tri + 1]]
		var c := jittered[indices[tri + 2]]
		var n := (b - a).cross(c - a)
		if n.length() > 0.000001:
			n = n.normalized()
			for v in [a, b, c]:
				st.set_normal(n)
				st.add_vertex(v)
		tri += 3
	return st.commit()


# una felce: ventaglio di lame verdi scure ricurve
func _fern(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var fern := Node3D.new()
	fern.position = pos
	fern.rotation.y = rng.randf() * TAU
	add_child(fern)
	var leaf := _pm(Color("4e7a42"), Color("3d6234"), 3.0, 0.55)
	for i in 6:
		var a := float(i) / 6.0 * TAU + rng.randf_range(-0.2, 0.2)
		var blade := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.0
		bm.bottom_radius = 0.05
		bm.height = rng.randf_range(0.4, 0.6)
		bm.radial_segments = 5
		blade.mesh = bm
		blade.material_override = leaf
		blade.position = Vector3(cos(a) * 0.1, 0.16, sin(a) * 0.1)
		blade.rotation.x = cos(a) * 0.75
		blade.rotation.z = -sin(a) * 0.75
		blade.scale = Vector3(1, 1, 0.35)
		fern.add_child(blade)


func _make_steam() -> GPUParticles3D:
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0.4), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.35
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 8.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, 0.15, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_speed = Vector3(0.3, 0.15, 0.3)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.8, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var steam := GPUParticles3D.new()
	steam.amount = 16
	steam.lifetime = 3.2
	steam.preprocess = 3.0
	steam.process_material = pm
	steam.draw_pass_1 = quad
	steam.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 5, 4))
	return steam


# la nebbiolina termale: veli larghi e lentissimi rasenti l'acqua
func _make_mist() -> GPUParticles3D:
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(1.4, 1.4)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.3, 0.05, 1.3)
	pm.direction = Vector3(1, 0.05, 0.3)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.06
	pm.initial_velocity_max = 0.14
	pm.gravity = Vector3(0, 0.03, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.5
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.75, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var mist := GPUParticles3D.new()
	mist.amount = 10
	mist.lifetime = 6.0
	mist.preprocess = 6.0
	mist.process_material = pm
	mist.draw_pass_1 = quad
	mist.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 3, 6))
	return mist


func _make_fireflies() -> GPUParticles3D:
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([
		Color(0.85, 1.0, 0.55, 0.9), Color(0.85, 1.0, 0.55, 0.4), Color(0.85, 1.0, 0.55, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
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
	pm.emission_box_extents = Vector3(1.2, 0.35, 1.2)
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.08
	pm.initial_velocity_max = 0.2
	pm.spread = 180.0
	pm.direction = Vector3(0, 1, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 0.8, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.15),
		Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var flies := GPUParticles3D.new()
	flies.amount = 12
	flies.lifetime = 4.0
	flies.preprocess = 4.0
	flies.process_material = pm
	flies.draw_pass_1 = quad
	flies.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 3, 4))
	return flies


# ---------------------------------------------------------------- il bagno

func _process(delta: float) -> void:
	if _fireflies and _daynight:
		_fireflies.emitting = _daynight.is_night()
	_update_prompt()
	if not _soaking:
		return

	# l'acqua calda scioglie la stanchezza (e disseta pure)
	if _survival:
		_survival.set_stamina(minf(_survival.get_max_stamina(),
				_survival.get_stamina() + 22.0 * delta))
		_survival.set_water(minf(_survival.get_max_water(),
				_survival.get_water() + 8.0 * delta))

	# cuoricini che salgono col vapore
	_heart_cd -= delta
	if _heart_cd <= 0.0:
		_heart_cd = randf_range(3.0, 5.0)
		var gtree := get_tree().get_first_node_in_group("grande_albero")
		if gtree:
			gtree.call("_sparkle", _player.global_position + Vector3(0, 0.9, 0), 6)
	_bubble_cd -= delta
	if _bubble_cd <= 0.0:
		_bubble_cd = randf_range(4.0, 7.0)
		if _sfx:
			_sfx.play("water", -22.0, 0.7)

	# e ogni tanto un residente arriva in accappatoio
	_guest_cd -= delta
	if _guest_cd <= 0.0:
		_guest_cd = randf_range(40.0, 70.0)
		_invite_guest()


func _invite_guest() -> void:
	if _visitors == null:
		return
	# l'ospite di prima ha finito il bagno (o non c'è più): posto libero
	if _guest and (not is_instance_valid(_guest)
			or not str(_guest.get("_state")).begins_with("on_")):
		_guest = null
	if _guest:
		return
	var pool: Array[Node3D] = []
	for r in _visitors.get("_residents"):
		var node := r.get("node") as Node3D
		if node and is_instance_valid(node) and not node.call("is_hidden"):
			pool.append(node)
	if pool.is_empty():
		return
	var pick: Node3D = pool[randi() % pool.size()]
	var edge := global_position + Vector3(-1.95, 0, -0.9)
	var soak := global_position + Vector3(-0.6, 0, 0.7)
	# l'invito può essere rifiutato (già in gita, sulla casa sull'albero…):
	# amicizia e posto solo se accetta davvero
	if not bool(pick.call("onsen_visit", edge, soak)):
		return
	_guest = pick
	# il bagno condiviso scalda l'amicizia — e si annoda al Filo Rosso
	for r in _visitors.get("_residents"):
		if r.get("node") == _guest:
			_visitors.call("_bump_friend", r, 1)
			get_tree().call_group("legami", "momento",
					str(r.get("dna", {}).get("name", "")), "onsen", "")
			break


func _can_enter() -> bool:
	if _player == null or _soaking:
		return false
	return _player.global_position.distance_to(global_position) < 2.6


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if _soaking:
		_exit_bath()
		get_viewport().set_input_as_handled()
	elif _can_enter():
		_enter_bath()
		get_viewport().set_input_as_handled()


func _enter_bath() -> void:
	_soaking = true
	get_tree().call_group("regista", "note", "onsen")
	_player.set_physics_process(false)
	_player.velocity = Vector3.ZERO
	_player.global_position = global_position + Vector3(0.35, 0, 0.15)
	if _mochi:
		_mochi.call("set_pose", "soak")
		_mochi.call("set_blush_max", true)
	_guest_cd = randf_range(6.0, 12.0)
	if _sfx:
		_sfx.plop()
		get_tree().create_timer(0.3).timeout.connect(func():
			if _sfx: _sfx.water())


func _exit_bath() -> void:
	_soaking = false
	if _mochi:
		_mochi.call("set_pose", "stand")
		_mochi.call("set_blush_max", false)
	_player.global_position = global_position + Vector3(-1.95, 0, -0.9)
	_player.set_physics_process(true)
	if _sfx:
		_sfx.play("water", -16.0, 1.1)


func _update_prompt() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_prompt.visible = false
		return
	var text := ""
	var wp := global_position + Vector3(0, 1.3, 0)
	if _soaking:
		text = "E — esci dall'acqua (che pace…)"
		wp = global_position + Vector3(0.35, 1.5, 0.15)
	elif _can_enter():
		text = "E — immergiti nell'onsen ♨"
	else:
		_prompt.visible = false
		return
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = text
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


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
	_prompt_label.add_theme_color_override("font_color", UI_BROWN)
	_prompt.add_child(_prompt_label)


# ---------------------------------------------------------------- debug CLI

func debug_soak() -> void:
	_enter_bath()


func debug_exit() -> void:
	_exit_bath()


func debug_guest(node: Node3D) -> void:
	var edge := global_position + Vector3(-1.95, 0, -0.9)
	var soak := global_position + Vector3(-0.6, 0, 0.7)
	node.call("onsen_visit", edge, soak)
