extends Node3D

## LA VITA SECONDARIA — il villaggio respira anche quando nessuno fa niente.
## È il segreto dei cozy: le cose piccole che succedono da sole.
##
## Tre emettitori e un telo che riusa il vento del handpaint:
##   · il FUMO dei camini: la sera, dal comignolo di ogni Camino acceso sale
##     un filo di fumo con la turbolenza vera (il ricciolo, non la colonna).
##     Se il camino sta sotto un tetto, il fumo esce SOPRA il tetto — dal
##     comignolo della casa, come è giusto;
##   · le FOGLIE d'autunno: non solo chiome dorate — per tutta la stagione
##     qualche foglia si stacca e scende volteggiando intorno a Mochi
##     (e sui tetti si ferma: le collisioni della pioggia valgono anche qui);
##   · il BUCATO dello Stendino: i teli ondeggiano con la STESSA onda di
##     vento che muove l'erba (wind_strength del handpaint — il trucco: la
##     mesh del telo cresce dalla corda in su e il nodo è capovolto, così
##     è l'ORLO a sventolare, non la parte appesa). Mochi stende i colori
##     del suo guardaroba (E sullo stendino), i residenti stendono i LORO
##     panni al mattino accanto a casa e li ritirano prima di sera;
##   · il terzo emettitore è il più piccolo di tutti: le goccioline che
##     cadono dal bucato appena steso.
##
## Il fumo e il bucato si accendono e spengono con l'ora del mondo: le
## finestre orarie sono funzioni PURE (le verifica il test), lo stato del
## bucato di Mochi persiste col villaggio.

const CATALOG := preload("res://scenes/build/BuildCatalog.gd")

## Da quanto vicino a una casa uno stendino appartiene a quel residente.
const RAGGIO_PROPRIETA := 5.0
## I colori del bucato di Mochi: il guardaroba steso ad asciugare.
## id del capo -> colore del telo (i primi 3 sbloccati, nell'ordine).
const COLORE_CAPO := {
	"cappello_petali": Color("f7bcd2"), "lanterna_lucciola": Color("d8ffa0"),
	"sciarpina_lana": Color("d97a6a"), "impermeabilino": Color("ffd35c"),
	"fiocco_ciliegio": Color("f7a8c4"), "occhialini_sole": Color("e8c46a"),
	"mantellina_foglie": Color("e0885a"), "cuffietta_neve": Color("f7f4ee"),
	"cerchietto_stelle": Color("fff2b8"), "cappellino_festa": Color("9fd8cf"),
	"campanellino_gatto": Color("c25a7a"), "portafortuna_carota": Color("f0913c"),
	"vasetto_miele": Color("e8b04a"), "coda_sciarpa": Color("e0885a"),
	"berretto_orecchie": Color("b8b2c0"),
}
## La biancheria di casa, quando il guardaroba è ancora vuoto.
const LINO := [Color("fff3e0"), Color("d9e4f0")]
## Le foglie che cadono d'autunno (la tavolozza del giardino d'autunno).
const FOGLIE_AUTUNNO := [Color("e0705a"), Color("e8a24a"), Color("c9603a"), Color("f0c050")]

var _build: Node3D
var _daynight: Node3D
var _visitors: Node
var _player: Node3D
var _sfx

# il fumo: nodo del camino -> emettitore agganciato al comignolo
var _fumi := {}
var _fumo_acceso := false
# le foglie d'autunno: un solo emettitore che segue Mochi
var _foglie: GPUParticles3D
var _autunno := false
# gli stendini: nodo -> {"di": label del residente ("" = di Mochi),
#                        "teli": Node3D o null}
var _stendini := {}
var _npc_steso := false
var _dirty := true
var _tick := 0.0
# il bucato di Mochi, persistito: "x|z" della cella -> true
var _steso := {}

var _prompt: PanelContainer
var _prompt_label: Label
var _vicino: Node3D


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("season_listener")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_prompt()
	_foglie = _make_foglie()
	add_child(_foglie)
	(func() -> void:
		_player = get_tree().get_first_node_in_group("player_controller")
		_daynight = get_node_or_null("../DayNight")
		_visitors = get_node_or_null("../Visitors")
		_build = get_tree().get_first_node_in_group("build_system")
		if _build and _build.has_signal("placed_changed"):
			_build.connect("placed_changed", func() -> void: _dirty = true)
	).call_deferred()


# ---------------------------------------------------------------- le ore

## L'ora del fumo: dal tramonto in poi, e per tutta la notte. PURA.
static func ora_del_fumo(tempo: float, notte: bool) -> bool:
	return notte or tempo >= 0.66


## L'ora del bucato steso dei residenti: il giorno pieno (si stende poco
## dopo l'alba, si ritira prima di sera — mai panni fuori col buio). PURA.
static func ora_del_bucato(tempo: float, notte: bool) -> bool:
	return not notte and tempo >= 0.31 and tempo <= 0.64


## Di chi è uno stendino: del residente con la casa più vicina (entro
## RAGGIO_PROPRIETA), altrimenti di Mochi. PURA sulla lista delle case
## ({"label": ..., "pos": Vector2}).
static func di_chi(pos: Vector2, case: Array) -> String:
	var best := ""
	var best_d := RAGGIO_PROPRIETA
	for c in case:
		var d: float = pos.distance_to(c["pos"])
		if d < best_d:
			best_d = d
			best = str(c["label"])
	return best


## I colori del bucato di Mochi: i primi tre capi sbloccati del guardaroba
## (nell'ordine del pannello), o la biancheria di lino se il baule è vuoto.
## PURA sulla lista degli id.
static func colori_bucato(sbloccati: Array) -> Array:
	var out: Array = []
	for id in sbloccati:
		if COLORE_CAPO.has(id):
			out.append(COLORE_CAPO[id])
		if out.size() >= 3:
			break
	if out.is_empty():
		return LINO.duplicate()
	return out


# ---------------------------------------------------------------- ciclo

func _process(delta: float) -> void:
	_update_prompt()
	# il resto respira piano: quattro battiti al secondo bastano
	_tick += delta
	if _tick < 0.25:
		return
	_tick = 0.0
	if _build == null or _daynight == null:
		return
	if _dirty:
		_rebuild()
	# il fumo si accende al tramonto e si spegne al mattino
	var tempo := float(_daynight.get("time"))
	var notte: bool = _daynight.is_night()
	var fumo := ora_del_fumo(tempo, notte)
	if fumo != _fumo_acceso:
		_fumo_acceso = fumo
		for camino in _fumi:
			if is_instance_valid(_fumi[camino]):
				(_fumi[camino] as GPUParticles3D).emitting = fumo
	# i residenti stendono al mattino e ritirano prima di sera
	var bucato := ora_del_bucato(tempo, notte)
	if bucato != _npc_steso:
		_npc_steso = bucato
		_refresh_teli_npc()
	# le foglie seguono Mochi (emesse solo d'autunno)
	if _player and _foglie:
		var pp: Vector3 = _player.global_position
		_foglie.position = Vector3(pp.x, 4.6, pp.z)


## Il regista delle stagioni chiama qui: le foglie cadono solo d'autunno.
func set_season(season: int, _snow: float, _transition: bool) -> void:
	_autunno = season == 2
	if _foglie:
		_foglie.emitting = _autunno


# ------------------------------------------------------------- il censimento

# Riprende in carico camini e stendini quando il villaggio cambia.
func _rebuild() -> void:
	_dirty = false
	# --- i camini: un filo di fumo ciascuno, agganciato al comignolo ---
	for camino in _fumi.keys():
		if not is_instance_valid(camino):
			_fumi.erase(camino)
	for camino in _build.get_placed_by_name("Camino"):
		var fumo: GPUParticles3D = _fumi.get(camino)
		if fumo == null or not is_instance_valid(fumo):
			fumo = _make_fumo()
			(camino as Node3D).add_child(fumo)
			_fumi[camino] = fumo
		# sotto un tetto il fumo esce SOPRA la casa (la canna arriva al
		# comignolo del tetto); all'aperto, dalla cima della canna propria
		var cell := Vector2i(roundi((camino as Node3D).position.x),
				roundi((camino as Node3D).position.z))
		var coperto: bool = _build.call("has_cover", cell)
		fumo.position = Vector3(0, 2.85 if coperto else 1.82, 0)
		fumo.emitting = _fumo_acceso
	# --- gli stendini: di chi sono, e con che teli ---
	for nodo in _stendini.keys():
		if not is_instance_valid(nodo):
			_stendini.erase(nodo)
	var case: Array = []
	if _visitors:
		for r in (_visitors.get("_residents") as Array):
			var cell2: Vector2i = r.get("cell", Vector2i.ZERO)
			case.append({"label": str(r.get("label", "")),
					"pos": Vector2(float(cell2.x), float(cell2.y))})
	for nodo in _build.get_placed_by_name("Stendino"):
		var p3: Vector3 = (nodo as Node3D).global_position
		var proprietario := di_chi(Vector2(p3.x, p3.z), case)
		if not _stendini.has(nodo):
			_stendini[nodo] = {"di": proprietario, "teli": null}
		else:
			_stendini[nodo]["di"] = proprietario
	_refresh_teli_npc()
	_refresh_teli_mochi()


# ------------------------------------------------------------- i teli

func _refresh_teli_npc() -> void:
	for nodo in _stendini:
		var s: Dictionary = _stendini[nodo]
		if str(s["di"]) == "":
			continue
		if _npc_steso and s["teli"] == null:
			s["teli"] = _stendi(nodo, _colori_npc(str(s["di"])), false)
		elif not _npc_steso and s["teli"] != null:
			_ritira(s)


func _refresh_teli_mochi() -> void:
	for nodo in _stendini:
		var s: Dictionary = _stendini[nodo]
		if str(s["di"]) != "":
			continue
		var steso: bool = _steso.has(_chiave(nodo))
		if steso and s["teli"] == null:
			# ripristino dal salvataggio: i panni erano già lì, niente gocce
			s["teli"] = _stendi(nodo, _colori_mochi(), true)
		elif not steso and s["teli"] != null:
			_ritira(s)


func _chiave(nodo: Node3D) -> String:
	return "%d|%d" % [roundi(nodo.position.x), roundi(nodo.position.z)]


# i panni di un residente: i colori del SUO vestito, dal DNA
func _colori_npc(label: String) -> Array:
	if _visitors:
		for r in (_visitors.get("_residents") as Array):
			if str(r.get("label", "")) == label:
				var dna: Dictionary = r.get("dna", {})
				return [Color(str(dna.get("dress", "d9e4f0"))),
						Color(str(dna.get("dress2", "fff3e0"))),
						LINO[0]]
	return LINO.duplicate()


func _colori_mochi() -> Array:
	var guardaroba := get_tree().get_first_node_in_group("guardaroba")
	var sbloccati: Array = []
	if guardaroba:
		# nell'ordine del pannello, così il bucato racconta i primi ricordi
		for id in guardaroba.ORDER:
			if (guardaroba.get("_unlocked") as Dictionary).has(id):
				sbloccati.append(id)
	return colori_bucato(sbloccati)


## Appende i teli alla corda dello stendino. Ogni telo è PIEGATO sulla
## corda e ondeggia col vento del handpaint (vedi _telo per il trucco).
func _stendi(stendino: Node3D, colori: Array, silenzioso: bool) -> Node3D:
	var teli := Node3D.new()
	stendino.add_child(teli)
	var n := mini(colori.size(), 3)
	for i in n:
		var x := -0.3 + 0.3 * float(i) + randf_range(-0.03, 0.03)
		var largo := randf_range(0.2, 0.26)
		var telo := _telo(colori[i], largo, randf_range(0.34, 0.44))
		telo.position = Vector3(x, 1.075 - absf(x) * 0.05, 0)
		teli.add_child(telo)
	if not silenzioso:
		_gocce(stendino.global_position + Vector3(0, 0.9, 0))
	return teli


func _ritira(s: Dictionary) -> void:
	var teli: Node3D = s["teli"]
	s["teli"] = null
	if teli == null or not is_instance_valid(teli):
		return
	var tw := create_tween()
	tw.tween_property(teli, "scale", Vector3(1.0, 0.04, 1.0), 0.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(teli.queue_free)


## Un telo steso: piegato sulla corda, con le due mollette. IL TRUCCO DEL
## VENTO: il handpaint fa ondeggiare i vertici in proporzione a y² (è nato
## per l'erba, ferma alla radice e viva in punta) — perciò la mesh del telo
## CRESCE dalla corda (y=0) verso l'alto e il nodo viene CAPOVOLTO: così
## l'orlo, il punto più lontano dalla corda, è quello che sventola, e la
## piega appesa resta ferma. La stessa onda dell'erba: sin(t·v + x·0.9 + z·0.7).
func _telo(col: Color, mezza_larghezza: float, altezza: float) -> Node3D:
	var n := Node3D.new()
	var mat: ShaderMaterial = CATALOG._mat(col, col.darkened(0.14), 6.0, 0.42)
	mat.set_shader_parameter("wind_strength", 0.55)
	mat.set_shader_parameter("wind_speed", 1.7)
	mat.set_shader_parameter("no_snow", true)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 6
	var rows := 4
	# la griglia, due volte: fronte e retro (il telo si vede da tutti i lati)
	for lato: float in [1.0, -1.0]:
		for i in rows:
			for j in cols:
				var x0 := -mezza_larghezza + 2.0 * mezza_larghezza * float(j) / float(cols)
				var x1 := -mezza_larghezza + 2.0 * mezza_larghezza * float(j + 1) / float(cols)
				var y0 := altezza * float(i) / float(rows)
				var y1 := altezza * float(i + 1) / float(rows)
				var quad := [Vector3(x0, y0, 0), Vector3(x1, y0, 0),
						Vector3(x1, y1, 0), Vector3(x0, y1, 0)]
				var ordine := [0, 1, 2, 0, 2, 3] if lato > 0.0 else [0, 2, 1, 0, 3, 2]
				for k in ordine:
					st.set_normal(Vector3(0, 0, lato))
					st.add_vertex(quad[k])
	st.index()
	var mi := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# il capovolgimento: la mesh cresce in +y, il nodo la appende a testa
	# in giù — la corda è a y=0 (ferma), l'orlo in fondo (sventola)
	mi.rotation.z = PI
	mi.position.y = 0.012
	n.add_child(mi)
	# le due mollette di legno sulla corda
	var molla := CATALOG._mat(Color("c89a6b"), Color("a87c50"), 8.0, 0.4)
	for sx: float in [-1.0, 1.0]:
		var pin := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.011
		cm.bottom_radius = 0.011
		cm.height = 0.05
		cm.radial_segments = 6
		pin.mesh = cm
		pin.material_override = molla
		pin.position = Vector3(sx * mezza_larghezza * 0.8, 0.012, 0)
		n.add_child(pin)
	return n


# ------------------------------------------------------------- gli emettitori

# il filo di fumo: sbuffi morbidi che salgono lenti e si ARRICCIANO
# (turbolenza vera, non una colonna dritta), allargandosi e svanendo
func _make_fumo() -> GPUParticles3D:
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	# grigio spento e alpha bassa: il fumo è materia, non vapore luminoso
	# (con l'unshaded, un bianco pieno brillerebbe anche al tramonto)
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([
		Color(0.8, 0.78, 0.77, 0.4), Color(0.8, 0.78, 0.77, 0.18),
		Color(0.8, 0.78, 0.77, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.03
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 5.0
	pm.initial_velocity_min = 0.22
	pm.initial_velocity_max = 0.38
	pm.gravity = Vector3(0.1, 0.16, 0.05)     # sale piano e deriva col vento
	pm.damping_min = 0.05
	pm.damping_max = 0.1
	# IL RICCIOLO: la turbolenza piega il filo, come il fumo vero
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 2.4
	pm.turbulence_influence_min = 0.04
	pm.turbulence_influence_max = 0.1
	pm.scale_min = 0.35
	pm.scale_max = 0.6
	# lo sbuffo si allarga salendo (il fumo si disfa nell'aria)
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.35))
	sc.add_point(Vector2(0.55, 1.0))
	sc.add_point(Vector2(1.0, 1.7))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.85),
			Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex

	var fumo := GPUParticles3D.new()
	fumo.amount = 32     # abbastanza fitti da leggersi come un FILO continuo
	fumo.lifetime = 6.0
	fumo.preprocess = 3.0      # all'ora del tramonto il filo c'è già
	fumo.local_coords = false  # il fumo resta nell'aria, non segue il camino
	fumo.emitting = false
	fumo.process_material = pm
	fumo.draw_pass_1 = quad
	fumo.visibility_aabb = AABB(Vector3(-2.5, -0.5, -2.5), Vector3(5, 7, 5))
	return fumo


# le foglie d'autunno: si staccano alte e scendono volteggiando (la
# turbolenza dà lo svolazzo, la rotazione il dondolio); sui tetti si
# fermano, come le gocce della pioggia
func _make_foglie() -> GPUParticles3D:
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.95),
			Color(1, 1, 1, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.085, 0.058)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(10.0, 0.6, 10.0)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 10.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.55
	pm.gravity = Vector3(0.3, -0.55, 0.12)
	# lo SVOLAZZO: la foglia non cade, plana a zig-zag
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.7
	pm.turbulence_noise_scale = 1.4
	pm.turbulence_influence_min = 0.12
	pm.turbulence_influence_max = 0.25
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -140.0
	pm.angular_velocity_max = 140.0
	pm.scale_min = 0.75
	pm.scale_max = 1.35
	# ogni foglia col SUO rame (la tavolozza dell'autunno del giardino)
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offs := PackedFloat32Array()
	var colori := PackedColorArray()
	for i in FOGLIE_AUTUNNO.size():
		offs.append(float(i) / float(FOGLIE_AUTUNNO.size()))
		colori.append(FOGLIE_AUTUNNO[i])
	ramp.offsets = offs
	ramp.colors = colori
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_initial_ramp = ramp_tex
	# sui tetti la foglia si ferma (le stesse collisioni della pioggia)
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT

	var foglie := GPUParticles3D.new()
	foglie.amount = 30
	foglie.lifetime = 10.0
	foglie.preprocess = 5.0
	foglie.local_coords = false
	foglie.emitting = false
	foglie.process_material = pm
	foglie.draw_pass_1 = quad
	foglie.visibility_aabb = AABB(Vector3(-12, -6, -12), Vector3(24, 8, 24))
	return foglie


# le goccioline del bucato appena steso: uno scroscio piccolo e una volta sola
func _gocce(pos: Vector3) -> void:
	var tex := GradientTexture2D.new()
	tex.width = 16
	tex.height = 16
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	grad.colors = PackedColorArray([Color(0.75, 0.85, 0.95, 0.8),
			Color(0.75, 0.85, 0.95, 0.4), Color(0.75, 0.85, 0.95, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.4, 0.05, 0.06)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 4.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3(0, -3.2, 0)
	var burst := GPUParticles3D.new()
	burst.amount = 14
	burst.lifetime = 0.7
	burst.one_shot = true
	burst.explosiveness = 0.25
	burst.local_coords = false
	burst.process_material = pm
	burst.draw_pass_1 = quad
	burst.position = pos
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(1.6).timeout.connect(burst.queue_free)


# ------------------------------------------------------------- Mochi stende

func _update_prompt() -> void:
	if _prompt == null or _player == null or _build == null:
		return
	var cam := get_viewport().get_camera_3d()
	_vicino = null
	if cam == null:
		_prompt.visible = false
		return
	var best := 1.5
	for nodo in _stendini:
		if not is_instance_valid(nodo):
			continue
		if str((_stendini[nodo] as Dictionary)["di"]) != "":
			continue   # il bucato dei residenti non si tocca: è roba loro
		var d: float = _player.global_position.distance_to((nodo as Node3D).global_position)
		if d < best:
			best = d
			_vicino = nodo
	if _vicino == null:
		_prompt.visible = false
		return
	var steso: bool = _steso.has(_chiave(_vicino))
	_prompt_label.text = L10n.t("E — ritira il bucato") if steso else L10n.t("E — stendi il bucato")
	_prompt.reset_size()
	var wp: Vector3 = _vicino.global_position + Vector3(0, 1.6, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or _vicino == null:
		return
	if _player == null or not _player.is_physics_processing():
		return   # la E è di un altro pannello: idioma di Calendar
	if not is_instance_valid(_vicino):
		return
	var k := _chiave(_vicino)
	var s: Dictionary = _stendini.get(_vicino, {"di": "", "teli": null})
	if _steso.has(k):
		_steso.erase(k)
		_ritira(s)
	else:
		_steso[k] = true
		s["teli"] = _stendi(_vicino, _colori_mochi(), false)
		if _sfx:
			_sfx.play("swish", -16.0, 1.15)
	_stendini[_vicino] = s
	if _sfx:
		_sfx.ui_select()
	var saver := get_tree().get_first_node_in_group("build_system")
	if saver and saver.has_method("request_save"):
		saver.request_save()
	get_viewport().set_input_as_handled()


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


# ------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	return {"bucato_mochi": _steso.keys()}


func load_extra(data: Dictionary) -> void:
	_steso.clear()
	for k in data.get("bucato_mochi", []):
		_steso[str(k)] = true
	_dirty = true
