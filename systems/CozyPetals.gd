class_name CozyPetals
extends GPUParticles2D

## Petali che scendono piano: la coccola visiva dei menu e del titolo. Si
## configurano da soli sulla larghezza del viewport e continuano a fluttuare
## anche a gioco in pausa (process_mode ALWAYS). Nessuna texture esterna: il
## petalo è un pallino morbido dipinto in codice, tinto di rosa/crema/pesca.

@export var petal_amount := 26
@export var soft := true   # se false, colori più vivaci (titolo)


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	amount = maxi(1, petal_amount)
	lifetime = 11.0
	preprocess = 8.0
	randomness = 1.0
	local_coords = false
	texture = _petal_texture()
	process_material = _make_material()
	_fit()
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:
	var vp := get_viewport_rect().size
	position = Vector2(vp.x * 0.5, -20.0)
	var pm := process_material as ParticleProcessMaterial
	if pm:
		pm.emission_box_extents = Vector3(vp.x * 0.55, 6.0, 1.0)
	# tempo di vita ~ quanto serve per attraversare lo schermo, con margine
	lifetime = clampf(vp.y / 40.0, 8.0, 20.0)
	visibility_rect = Rect2(-vp.x, -60, vp.x * 3.0, vp.y + 200.0)


func _make_material() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(600, 6, 1)
	pm.direction = Vector3(0.15, 1, 0)
	pm.spread = 22.0
	pm.gravity = Vector3(0, 26, 0)
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 26.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -70.0
	pm.angular_velocity_max = 70.0
	pm.scale_min = 0.35
	pm.scale_max = 1.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 4.0
	pm.turbulence_noise_scale = 1.2
	pm.turbulence_influence_min = 0.1
	pm.turbulence_influence_max = 0.35

	# colore per-petalo: rosa, crema, pesca, un tocco di menta
	var init := Gradient.new()
	if soft:
		init.colors = PackedColorArray([
			Color("f6c2d2"), Color("fff1de"), Color("f7d0b8"), Color("d7ecd0")])
	else:
		init.colors = PackedColorArray([
			Color("ff9ec0"), Color("ffe6a8"), Color("ffc59a"), Color("bfe6c8")])
	init.offsets = PackedFloat32Array([0.0, 0.4, 0.7, 1.0])
	var init_tex := GradientTexture1D.new()
	init_tex.gradient = init
	pm.color_initial_ramp = init_tex

	# alpha nel tempo: entra ed esce in dissolvenza
	var life := Gradient.new()
	life.offsets = PackedFloat32Array([0.0, 0.12, 0.85, 1.0])
	life.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	var life_tex := GradientTexture1D.new()
	life_tex.gradient = life
	pm.color_ramp = life_tex
	return pm


# petalo morbido: un pallino con bordo sfumato (radiale)
func _petal_texture() -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.width = 48
	tex.height = 48
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([
		Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.0)])
	tex.gradient = g
	return tex
