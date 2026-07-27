class_name PozzeDiLuce
extends Node
## LE POZZE DI LUCE DALLE FINESTRE — la sera, le finestre accese versano
## rettangoli caldi sull'erba.
##
## Tre voci, una regia:
##   • ogni "Finestra" piazzata dal giocatore, al calare della notte,
##     scalda il vetro (da azzurrino diurno ad ambra) e versa la sua
##     pozza su ENTRAMBI i lati del muro (la luce non sceglie un lato);
##   • attorno al vetro acceso ballano due falene (particelle);
##   • la FINESTRA DEL LUTTO (l'OmniLight che Congedo accende per una
##     settimana alla casa di chi è partito) ha la pozza più eloquente:
##     una candela ambrata che respira piano, il pulviscolo che le fluttua
##     dentro, una falena sola — e la pozza si allunga VERSO IL SENTIERO
##     che i passi del partito avevano consumato (letto dalla tela dei
##     Sentieri): la luce cade proprio sulla via vuota.
##
## Niente OmniLight per le finestre normali (le pozze SONO la luce, a
## costo quasi zero); il lutto tiene la sua, accesa da Congedo.
## Shader: pozza_finestra.gdshader. Un test fa la guardia al contratto.

const SHADER := preload("res://shaders/pozza_finestra.gdshader")
const GEO := preload("res://scenes/world/WorldGeo.gd")

const LUNGA := 2.3            # quanto si allunga la pozza sul prato
const LARGA := 1.35           # larghezza del quad (il trapezio vive nella UV)
const ALZO := 0.03            # appena sopra il manto: niente z-fight
const VELOCITA_CREPUSCOLO := 0.14   # 1/s: la sera scende in ~7 secondi
const INTERVALLO_CENSIMENTO := 5.0

# il vetro delle finestre: freddo di giorno, ambra la sera
const VETRO_GIORNO := Color("bfe0f2")
const VETRO_SERA := Color("ffc978")
const VETRO_ENERGIA_GIORNO := 0.35
const VETRO_ENERGIA_SERA := 1.5

var _notte := false           # lo stato voluto (da DayNight)
var _crepuscolo := 0.0        # 0 giorno → 1 notte, scivola piano
var _t_censimento := 0.0
var _t_notte := 0.0
# instance_id della finestra -> {"root": Node3D, "mats": [ShaderMaterial],
#   "vetro": StandardMaterial3D|null, "falene": GPUParticles3D}
var _pozze := {}
# la pozza del lutto: {"root", "mats", "luce_id"} o vuoto
var _lutto := {}


func _ready() -> void:
	add_to_group("pozze_di_luce")
	_censimento()


func _process(delta: float) -> void:
	_t_censimento -= delta
	if _t_censimento <= 0.0:
		_t_censimento = INTERVALLO_CENSIMENTO
		_censimento()

	_t_notte -= delta
	if _t_notte <= 0.0:
		_t_notte = 0.6
		var dn := get_node_or_null("../../DayNight")
		if dn and dn.has_method("is_night"):
			imposta_notte(dn.is_night())

	# il crepuscolo scivola: le pozze sbocciano e svaniscono in ~7 s
	var meta := 1.0 if _notte else 0.0
	if absf(_crepuscolo - meta) > 0.0005:
		_crepuscolo = move_toward(_crepuscolo, meta, VELOCITA_CREPUSCOLO * delta)
		_applica_crepuscolo()


## Lo stato notte lo detta DayNight (o un test): da qui in poi fa tutto
## lo scivolo del crepuscolo in _process.
func imposta_notte(notte: bool) -> void:
	_notte = notte


func _applica_crepuscolo() -> void:
	var k := _crepuscolo
	for id in _pozze:
		var voce: Dictionary = _pozze[id]
		for m in voce["mats"]:
			(m as ShaderMaterial).set_shader_parameter("intensita", k)
		var vetro: StandardMaterial3D = voce["vetro"]
		if vetro:
			vetro.emission = VETRO_GIORNO.lerp(VETRO_SERA, k)
			vetro.emission_energy_multiplier = lerpf(
					VETRO_ENERGIA_GIORNO, VETRO_ENERGIA_SERA, k)
		var falene: GPUParticles3D = voce["falene"]
		if falene:
			falene.emitting = k > 0.4
	if not _lutto.is_empty():
		for m in _lutto["mats"]:
			# la candela del lutto non si spegne mai del tutto: anche di
			# giorno un filo di presenza (chi passa la vede appena)
			(m as ShaderMaterial).set_shader_parameter("intensita",
					maxf(k, 0.12))


# ------------------------------------------------------------ censimento

## Le finestre vive adesso: quelle piazzate dal giocatore (BuildSystem)
## e la luce del lutto di Congedo. Chiamabile dai test con liste finte.
func _censimento() -> void:
	var bs := get_node_or_null("../../BuildSystem")
	if bs and bs.has_method("get_placed_by_name"):
		censisci_finestre(bs.call("get_placed_by_name", "Finestra"))
	_censisci_lutto()


## Crea/rimuove le pozze per l'elenco corrente dei nodi-finestra.
func censisci_finestre(finestre: Array) -> void:
	var vive := {}
	for f in finestre:
		var w := f as Node3D
		if w == null or not w.is_inside_tree():
			continue
		var id := w.get_instance_id()
		vive[id] = true
		if not _pozze.has(id):
			_pozze[id] = _fai_pozza_finestra(w)
	# le finestre rimosse dal giocatore si portano via le loro pozze
	for id in _pozze.keys():
		if not vive.has(id):
			var voce: Dictionary = _pozze[id]
			if is_instance_valid(voce["root"]):
				(voce["root"] as Node).queue_free()
			_pozze.erase(id)
	_applica_crepuscolo()


## Il corredo di una finestra: due quad-pozza (uno per lato del muro),
## il vetro da scaldare la sera, due falene che ballano vicino al vetro.
func _fai_pozza_finestra(w: Node3D) -> Dictionary:
	var root := Node3D.new()
	w.add_child(root)
	var mats: Array = []
	for lato: float in [-1.0, 1.0]:
		var m := _quad_pozza(root, 0.0)
		var mi: MeshInstance3D = m[0]
		# il quad parte dal muro e corre via sul prato, su entrambi i lati
		mi.position = Vector3(0, ALZO, lato * (LUNGA * 0.5 + 0.08))
		if lato < 0.0:
			mi.rotation.y = PI
		mats.append(m[1])
	return {"root": root, "mats": mats,
			"vetro": _trova_vetro(w), "falene": _fai_falene(root, 2)}


## Il quad della pozza: PlaneMesh con la UV.y lungo la corsa della luce.
## Ritorna [MeshInstance3D, ShaderMaterial].
func _quad_pozza(parent: Node3D, lutto_v: float) -> Array:
	var pm := PlaneMesh.new()
	pm.size = Vector2(LARGA, LUNGA)
	pm.orientation = PlaneMesh.FACE_Y
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("lutto", lutto_v)
	mat.set_shader_parameter("fase", randf() * 37.0)
	mat.set_shader_parameter("intensita", 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# la UV.y del PlaneMesh corre lungo -Z→+Z: y=0 (parete) al bordo -Z
	parent.add_child(mi)
	return [mi, mat]


## Il vetro emissivo dentro il nodo-finestra (il box col material
## StandardMaterial3D a emissione): è lui che si scalda la sera.
func _trova_vetro(w: Node3D) -> StandardMaterial3D:
	for c in w.get_children():
		var mi := c as MeshInstance3D
		if mi == null:
			continue
		var sm := mi.material_override as StandardMaterial3D
		if sm and sm.emission_enabled:
			return sm
	return null


## Le falene che ballano attorno al vetro acceso (spente di giorno).
func _fai_falene(parent: Node3D, quante: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = quante
	p.lifetime = 3.2
	p.emitting = false
	p.local_coords = true
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.28, 0.22, 0.16)
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.12
	pm.initial_velocity_max = 0.3
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.9
	pm.turbulence_noise_scale = 3.2
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.045)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = GEO.soft_circle(Color(1.0, 0.9, 0.72, 0.85), 0.45)
	quad.material = mat
	p.draw_pass_1 = quad
	p.position = Vector3(0, 1.25, 0)   # all'altezza del vetro
	parent.add_child(p)
	return p


# ------------------------------------------------------------ il lutto

## La finestra accesa del lutto: l'OmniLight che Congedo tiene accesa per
## la settimana. La si scopre da fuori (Congedo è dell'altra metà del
## gioco): un OmniLight3D figlio del nodo con lo script Congedo.gd.
func _censisci_lutto() -> void:
	var luce := _trova_luce_lutto()
	var luce_id := luce.get_instance_id() if luce else 0
	if not _lutto.is_empty():
		if luce_id == _lutto["luce_id"] and is_instance_valid(_lutto["root"]):
			return                      # la stessa candela di prima
		if is_instance_valid(_lutto["root"]):
			(_lutto["root"] as Node).queue_free()
		_lutto = {}
	if luce == null:
		return
	_lutto = _fai_pozza_lutto(luce)


func _trova_luce_lutto() -> OmniLight3D:
	var cozy := get_parent()
	if cozy == null:
		return null
	for fratello in cozy.get_children():
		var s := fratello.get_script() as Script
		if s == null or not str(s.resource_path).ends_with("Congedo.gd"):
			continue
		for c in fratello.get_children():
			if c is OmniLight3D:
				return c
	return null


## La pozza del lutto: una candela che respira, orientata VERSO IL
## SENTIERO che i passi di chi è partito avevano consumato — la luce
## cade sulla via vuota. Pulviscolo dentro il fascio, una falena sola.
func _fai_pozza_lutto(luce: OmniLight3D) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	root.global_position = Vector3(luce.global_position.x, 0.0,
			luce.global_position.z)
	# verso dove? Il sentiero più consumato attorno alla casa. Se la tela
	# dei Sentieri non c'è (o è vergine), verso sud: la porta è a sud.
	var dir := _verso_il_sentiero(root.global_position)
	# il +Z locale (dove il quad si allunga) deve puntare lungo il sentiero
	root.rotation.y = atan2(dir.x, dir.y)

	var m := _quad_pozza(root, 1.0)
	var mi: MeshInstance3D = m[0]
	# la candela del lutto si allunga di più: LUNGA*1.25, stretta
	mi.scale = Vector3(0.8, 1.0, 1.25)
	mi.position = Vector3(0, ALZO, LUNGA * 1.25 * 0.5 + 0.05)
	var mats: Array = [m[1]]

	# il pulviscolo che fluttua nel fascio: lento, caldo, rado
	var p := GPUParticles3D.new()
	p.amount = 9
	p.lifetime = 6.0
	p.emitting = true
	p.local_coords = true
	var ppm := ParticleProcessMaterial.new()
	ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ppm.emission_box_extents = Vector3(0.4, 0.02, LUNGA * 0.55)
	ppm.gravity = Vector3(0, 0.045, 0)      # il pulviscolo SALE, piano
	ppm.initial_velocity_min = 0.0
	ppm.initial_velocity_max = 0.03
	ppm.turbulence_enabled = true
	ppm.turbulence_noise_strength = 0.25
	ppm.turbulence_noise_scale = 1.6
	ppm.scale_min = 0.30
	ppm.scale_max = 0.6
	p.process_material = ppm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.03, 0.03)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pmat.albedo_texture = GEO.soft_circle(Color(1.0, 0.78, 0.5, 0.5), 0.4)
	quad.material = pmat
	p.draw_pass_1 = quad
	p.position = Vector3(0, 0.35, LUNGA * 0.6)
	root.add_child(p)

	# una falena sola: la solitudine si conta
	var falena := _fai_falene(root, 1)
	falena.emitting = true

	return {"root": root, "mats": mats, "luce_id": luce.get_instance_id()}


## Da dove i passi hanno consumato di più: legge la tela dei Sentieri
## attorno alla casa e torna la direzione (XZ) del sentiero. Zero → sud.
func _verso_il_sentiero(centro: Vector3) -> Vector2:
	var sent := get_tree().get_first_node_in_group("sentieri")
	if sent and sent.get("_vp") != null:
		var img: Image = (sent.get("_vp") as SubViewport).get_texture().get_image()
		if img != null and not img.is_empty():
			var px: Vector2 = sent.px_di(centro)
			if px.x >= 0.0:
				var raggio: float = 2.0 / (sent.AREA as Rect2).size.x \
						* float(sent.RISOLUZIONE)
				var dir := direzione_piu_consumata(img, px, raggio)
				if dir != Vector2.ZERO:
					return dir
	return Vector2(0, 1)   # sud: le porte guardano a sud


## Pura e statica (testabile headless): fra 16 direzioni attorno a
## [param px], quella con più usura media lungo il raggio. ZERO se la
## tela lì attorno è vergine (nessun sentiero da illuminare).
static func direzione_piu_consumata(img: Image, px: Vector2,
		raggio_px: float) -> Vector2:
	var migliore := Vector2.ZERO
	var massimo := 0.0
	for i in 16:
		var a := float(i) / 16.0 * TAU
		var dir := Vector2(cos(a), sin(a))
		var somma := 0.0
		for passo in 3:
			var campione := px + dir * raggio_px * (float(passo + 1) / 3.0)
			var cx := clampi(int(campione.x), 0, img.get_width() - 1)
			var cy := clampi(int(campione.y), 0, img.get_height() - 1)
			somma += img.get_pixel(cx, cy).r
		if somma > massimo:
			massimo = somma
			migliore = dir
	if massimo < 0.15:      # tela vergine: nessun sentiero, meglio il sud
		return Vector2.ZERO
	return migliore
