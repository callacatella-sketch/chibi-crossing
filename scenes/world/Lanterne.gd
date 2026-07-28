extends RefCounted

## LA LANTERNA DI CARTA — una sola, per tutto il villaggio.
##
## È nata per il congedo (le lucine che accompagnano chi parte, l'ultima
## sera) ed è troppo bella per restare di un sistema solo: adesso la
## accende anche la RONDA della guardia, ogni sera, davanti alle case di
## chi dorme. Una fabbrica sola, come per le mesh del mondo (WorldGeo) e
## per il bestiario: due lanterne diverse in due posti diversi sarebbero
## due lanterne che col tempo divergono.
##
## È un chōchin: carta traslucida (il controluce ATTRAVERSA la materia,
## `translucency` del handpaint), tre costine di bambù che ne danno il
## ritmo, cappellino di legno e una fiammella che respira — mai due
## uguali, perché la taglia e la fase nascono a caso a ogni lanterna.
##
## `accendi()` restituisce la scheda che serve per animarla:
##   {node, luce, core, fase, nascita, taglia}
## Il respiro lo fa chi la possiede (`respira()`), così una lanterna in
## una scena in pausa non consuma niente.

const HANDPAINT := preload("res://shaders/handpaint.gdshader")

## Quanto lontano arriva il conforto di una lanterna accesa. È lo stesso
## numero che la Veglia usa per decidere chi ha dormito al buio: la luce
## che si vede e la luce che conta sono la stessa cosa.
const RAGGIO := 2.8


static func _pm(a: Color, b: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = HANDPAINT
	mat.set_shader_parameter("color_a", a)
	mat.set_shader_parameter("color_b", b)
	mat.set_shader_parameter("noise_scale", 5.0)
	mat.set_shader_parameter("noise_amount", 0.5)
	return mat


static func _cilindro(parent: Node3D, r: float, h: float, mat: Material,
		pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


## Costruisce una lanterna spenta (energia 0: la si accende animandola).
## Il nodo NON viene messo in scena: lo aggiunge chi la chiede, dove vuole.
static func accendi(pos: Vector3) -> Dictionary:
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = randf() * TAU
	var taglia := randf_range(0.92, 1.08)   # fatte a mano: mai due uguali
	# il gruppo che il volto vivo scandaglia per mettere il riflesso caldo
	# negli occhi di chi ci passa accanto
	node.add_to_group("luce_calda")

	var legno := _pm(Color("6e5138"), Color("55402c"))
	var carta := _pm(Color("fff2da"), Color("f4deb4"))
	carta.set_shader_parameter("translucency", 0.65)

	# piedino e stelo
	_cilindro(node, 0.055, 0.05, legno, Vector3(0, 0.025, 0))
	_cilindro(node, 0.014, 0.36, legno, Vector3(0, 0.23, 0))
	# il corpo di carta, appena schiacciato come i chōchin veri
	var corpo := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.115
	sm.height = 0.23
	sm.radial_segments = 20
	corpo.mesh = sm
	corpo.material_override = carta
	corpo.position = Vector3(0, 0.62, 0)
	corpo.scale = Vector3(1.0, 1.12, 1.0)
	node.add_child(corpo)
	# le costine di carta: tre anelli sottili che danno il ritmo del bambù
	for h in [-0.055, 0.0, 0.055]:
		var costina := MeshInstance3D.new()
		var tm := TorusMesh.new()
		var r_h := sqrt(maxf(0.0001, 0.115 * 0.115 - float(h) * float(h) * 0.8))
		tm.inner_radius = r_h - 0.004
		tm.outer_radius = r_h + 0.004
		costina.mesh = tm
		costina.material_override = _pm(Color("e8cf9e"), Color("d6ba84"))
		costina.position = Vector3(0, 0.62 + float(h) * 1.12, 0)
		costina.scale = Vector3(1, 0.5, 1)
		node.add_child(costina)
	# cappellino
	_cilindro(node, 0.055, 0.035, legno, Vector3(0, 0.765, 0))

	# la fiammella: il cuore emissivo che respira
	var core := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.05
	cm.height = 0.1
	core.mesh = cm
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color("ffdf9a")
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.76, 0.4)
	core_mat.emission_energy_multiplier = 0.0
	core.material_override = core_mat
	core.position = Vector3(0, 0.62, 0)
	node.add_child(core)
	var luce := OmniLight3D.new()
	luce.light_color = Color(1.0, 0.78, 0.45)
	luce.omni_range = RAGGIO
	luce.light_energy = 0.0
	luce.shadow_enabled = false
	luce.position = Vector3(0, 0.62, 0)
	node.add_child(luce)
	return {"node": node, "luce": luce, "core": core_mat,
			"fase": randf() * TAU, "nascita": 0.0, "taglia": taglia}


## Il respiro di una fiammella: due seni sfasati e incommensurabili, così
## non si richiudono mai su uno schema. `viva` va da 0 (spenta) a 1.
## Chiamare a ogni frame, per ogni lanterna che si possiede.
static func respira(scheda: Dictionary, t: float, viva := 1.0) -> void:
	var fase := float(scheda.get("fase", 0.0))
	var battito := 1.0 + sin(t * 2.3 + fase) * 0.12 + sin(t * 3.7 + fase * 1.7) * 0.06
	var forza := clampf(viva, 0.0, 1.0) * battito
	var luce := scheda.get("luce") as OmniLight3D
	if luce != null and is_instance_valid(luce):
		luce.light_energy = 0.9 * forza
	var core := scheda.get("core") as StandardMaterial3D
	if core != null:
		core.emission_energy_multiplier = 1.6 * forza
