class_name SaltoTrota
extends Node3D
## IL SALTO DELLA TROTA — l'indizio del bestiario, mantenuto.
##
## «Risale la corrente e salta dove la cascata spumeggia»: ora lo fa
## davvero. Ogni 20–40 secondi, ai piedi del velo della cascata (z = -4,
## la stessa FALL_Z di WorldMath), un guizzo rosa-argento esce dall'acqua
## ad arco, si torce nell'aria con un colpo di coda, prende il sole al
## colmo e rientra con lo splash — le stesse increspature del fiume
## (water_ripple di CozyWorld) e il plop di Sfx.
##
## La fisica è quella vera delle trote alla risalita: il salto punta
## CONTROCORRENTE, verso il velo — prova a salire, non ce la fa, ricade.
## Ogni tanto riprova subito: il doppio salto delle ostinate.
##
## Tutto in fonte unica: la posa della pozza da WorldMath.river_x(FALL_Z),
## il colore della livrea da Critters.SPECIE["trota"], e il pesce salta
## SOLO quando il bestiario lo dà disponibile (Critters.disponibile col
## contesto di CozyWorld): se un giorno la trota diventasse stagionale,
## anche i salti seguirebbero il calendario. Nessuna parola: chi guarda
## il fiume impara da solo dove (e quando) pescare.

const MATH := preload("res://scenes/world/WorldMath.gd")
const CRITTERS := preload("res://scenes/world/Critters.gd")
const GEO := preload("res://scenes/world/WorldGeo.gd")

const ATTESA_MIN := 20.0
const ATTESA_MAX := 40.0
const GRAVITA := 6.5              # un filo più dolce del vero: mondo-peluche
const ACQUA_Y := -0.45            # CozyWorld.RIVER_WATER_Y (pelo del fiume)
const PROB_DOPPIO := 0.28         # l'ostinata che riprova subito

var _cd := 8.0                    # il primo salto non si fa attendere troppo
var _salto := {}                  # {t, dur, start, vel, doppio}
var _pesce: Node3D
## Quanto si rientra verso monte rispetto al piede della cascata: sul bordo
## esatto il guizzo finirebbe dentro il velo d'acqua e non si vedrebbe.
const RIENTRO_POZZA := 1.1

var _coda: Node3D
var _corpo_mat: StandardMaterial3D


func _ready() -> void:
	# LA POZZA DOVE LA CASCATA SPUMEGGIA — e la cascata la posa `cliff_x`,
	# non `river_x`. Erano due fonti diverse per lo stesso posto, e per
	# definizione `cliff_x(FALL_Z) = river_x(FALL_Z) + 2.9`: il guizzo
	# usciva 2,90 m piu' in la', in acqua liscia, fuori dalla foschia
	# (raggio utile 0,8 m) e lontano dalle rocce, con un secondo grappolo
	# di increspature scollegato dal primo. E l'indizio del bestiario
	# («salta dove la cascata spumeggia») insegnava il posto sbagliato.
	# Il rientro di RIENTRO_POZZA porta il salto DENTRO la pozza invece che
	# sul bordo, dove finirebbe dietro il velo d'acqua.
	position = Vector3(MATH.cliff_x(MATH.FALL_Z) - 0.55 - RIENTRO_POZZA,
			ACQUA_Y, MATH.FALL_Z)
	_pesce = _fai_trota()
	# un guizzo che si VEDE dalla riva: il pesciolino è di taglia onesta
	_pesce.scale = Vector3.ONE * 1.25
	add_child(_pesce)
	_pesce.visible = false


func _process(delta: float) -> void:
	if _salto.is_empty():
		_cd -= delta
		if _cd <= 0.0:
			_cd = randf_range(ATTESA_MIN, ATTESA_MAX)
			if _bestiario_permette():
				_salta(randf() < PROB_DOPPIO)
		return

	_salto["t"] = float(_salto["t"]) + delta
	var t: float = _salto["t"]
	var dur: float = _salto["dur"]
	if t >= dur:
		_ammara()
		return

	# la parabola vera, col muso lungo la velocità: il pesce VOLA, non slitta
	var start: Vector3 = _salto["start"]
	var vel: Vector3 = _salto["vel"]
	_pesce.position = punto_salto(start, vel, GRAVITA, t)
	var v_ora: Vector3 = vel + Vector3(0, -GRAVITA * t, 0)
	if v_ora.length() > 0.01:
		# il muso della trota è il -Z del modello (come tutto nel gioco):
		# look_at punta il -Z lungo la velocità — il pesce VOLA di muso
		_pesce.look_at(_pesce.global_position + v_ora.normalized(), Vector3.UP)
	# il colpo di coda in aria: la torsione del guizzo
	_pesce.rotation.z += sin(t * 26.0) * 0.22
	if _coda:
		_coda.rotation.y = sin(t * 30.0) * 0.7
	# al colmo prende il sole: il lampo argentato del guizzo
	var colmo := 1.0 - absf(t / dur - 0.5) * 2.0
	_corpo_mat.emission_energy_multiplier = smoothstep(0.55, 1.0, colmo) * 0.45


# --------------------------------------------------------------- il salto

func _salta(doppio: bool) -> void:
	# parte poco a valle del velo e salta CONTROCORRENTE, verso la schiuma
	var da := Vector3(randf_range(-0.55, -0.2), 0, randf_range(-0.55, 0.55))
	var apice := randf_range(0.65, 1.05)
	var vy := sqrt(2.0 * GRAVITA * apice)
	var dur := 2.0 * vy / GRAVITA
	var verso_velo := Vector3(randf_range(0.35, 0.6), 0, -da.z * randf_range(0.3, 0.7))
	_salto = {"t": 0.0, "dur": dur, "start": da,
			"vel": verso_velo / dur + Vector3(0, vy, 0), "doppio": doppio}
	_pesce.visible = true
	_pesce.position = da
	_spruzzo(da, 0.7)
	_plop()


func _ammara() -> void:
	var start: Vector3 = _salto["start"]
	var vel: Vector3 = _salto["vel"]
	var fine := punto_salto(start, vel, GRAVITA, float(_salto["dur"]))
	_pesce.visible = false
	_spruzzo(fine, 1.0)
	_plop()
	if bool(_salto["doppio"]):
		# l'ostinata: riprende fiato un attimo e riprova
		_salto = {}
		_cd = randf_range(1.2, 2.2)
	else:
		_salto = {}


## Dove sta il pesce a tempo [param t] della parabola. PURA: il test la
## percorre tutta senza acqua né cascata.
static func punto_salto(start: Vector3, vel: Vector3, g: float, t: float) -> Vector3:
	return start + vel * t + Vector3(0, -0.5 * g * t * t, 0)


## La durata del volo per un salto alto [param apice] (rientro al pelo).
static func durata_salto(apice: float, g: float) -> float:
	return 2.0 * sqrt(2.0 * g * apice) / g


func _bestiario_permette() -> bool:
	var cozy := get_parent()
	if cozy == null or not cozy.has_method("contesto_critter"):
		return true
	return CRITTERS.disponibile("trota", cozy.call("contesto_critter"))


# ------------------------------------------------------------- il pesciolino

## La trota del salto: fuso argenteo con la livrea rosa del bestiario
## (STESSO colore di Critters: la trota che vedi saltare è quella che
## peschi), pinna caudale a due lobi su un pivot (il colpo di coda),
## dorsale, e il ventre metallico che prende la luce.
func _fai_trota() -> Node3D:
	var n := Node3D.new()
	var livrea: Color = (CRITTERS.SPECIE["trota"]["colore"] as Color)
	_corpo_mat = StandardMaterial3D.new()
	_corpo_mat.albedo_color = livrea.lerp(Color("cfd6dc"), 0.45)
	_corpo_mat.metallic = 0.75
	_corpo_mat.roughness = 0.25
	_corpo_mat.emission_enabled = true
	_corpo_mat.emission = Color("eef2f6")
	_corpo_mat.emission_energy_multiplier = 0.0

	# il corpo: fuso affusolato (muso verso -Z)
	var corpo := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	sm.radial_segments = 16
	sm.rings = 10
	corpo.mesh = sm
	corpo.material_override = _corpo_mat
	corpo.scale = Vector3(0.42, 0.55, 1.55)
	n.add_child(corpo)

	# la fascia rosa della livrea, lungo il fianco
	var fascia := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.088
	fm.height = 0.176
	fm.radial_segments = 14
	fm.rings = 8
	var fascia_mat := StandardMaterial3D.new()
	fascia_mat.albedo_color = livrea
	fascia_mat.metallic = 0.4
	fascia_mat.roughness = 0.4
	fascia.mesh = fm
	fascia.material_override = fascia_mat
	fascia.scale = Vector3(0.45, 0.28, 1.35)
	fascia.position = Vector3(0, 0.012, 0.01)
	n.add_child(fascia)

	# la coda su un PIVOT: due lobi che frustano in volo
	_coda = Node3D.new()
	_coda.position = Vector3(0, 0, 0.14)
	n.add_child(_coda)
	for lato: float in [-1.0, 1.0]:
		var lobo := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.05
		lm.height = 0.1
		lm.radial_segments = 10
		lm.rings = 6
		lobo.mesh = lm
		lobo.material_override = _corpo_mat
		lobo.scale = Vector3(0.16, 0.75, 0.95)
		lobo.position = Vector3(0, lato * 0.022, 0.05)
		lobo.rotation.x = lato * 0.5
		_coda.add_child(lobo)

	# la pinna dorsale
	var dorsale := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.045
	dm.height = 0.09
	dm.radial_segments = 8
	dm.rings = 5
	dorsale.mesh = dm
	dorsale.material_override = _corpo_mat
	dorsale.scale = Vector3(0.12, 0.75, 0.8)
	dorsale.position = Vector3(0, 0.055, 0.02)
	n.add_child(dorsale)
	return n


# ------------------------------------------------------------ acqua e suono

## Lo spruzzo: goccioline bianche una-tantum + l'anello d'increspatura
## VERO del fiume (water_ripple di CozyWorld, lo stesso della pioggia).
func _spruzzo(locale: Vector3, forza: float) -> void:
	var cozy := get_parent()
	if cozy and cozy.has_method("water_ripple"):
		cozy.call("water_ripple", global_position + locale, 0.55 * forza, 0.02)

	var p := GPUParticles3D.new()
	p.amount = int(14 * forza)
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.06
	pm.direction = Vector3.UP
	pm.spread = 55.0
	pm.gravity = Vector3(0, -9.0, 0)
	pm.initial_velocity_min = 1.0 * forza
	pm.initial_velocity_max = 2.0 * forza
	pm.scale_min = 0.35
	pm.scale_max = 0.7
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = GEO.soft_circle(Color(0.92, 0.97, 1.0, 0.85), 0.4)
	quad.material = mat
	p.draw_pass_1 = quad
	add_child(p)
	p.position = locale + Vector3(0, 0.03, 0)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())


func _plop() -> void:
	var sfx = get_node_or_null(^"/root/Sfx")
	if sfx and sfx.has_method("plop"):
		sfx.plop()
