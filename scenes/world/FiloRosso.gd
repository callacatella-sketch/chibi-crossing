extends Node3D

## IL FILO ROSSO, LETTERALE — il simbolo del gioco reso visibile.
##
## Nei momenti che si annodano (il primo di ogni tipo sul filo dei
## Legami, ogni consolazione, ogni desiderio d'oro del congedo) appare
## per un paio di secondi un filo rosso sottile e luminoso tra la zampa
## di Mochi e quella del vicino: la leggenda giapponese del filo del
## destino. Non una notifica: un'immagine.
##
## Com'è fatto:
##  · un NASTRO (ImmediateMesh ricostruita ogni frame) teso tra le due
##    zampe VIVE — se i due si muovono, il filo li segue — con la pancia
##    di una catenaria e un filo di vento (punto_filo, pura);
##  · si DISEGNA dalla zampa di Mochi verso l'amico, e quando arriva il
##    nodo SI STRINGE: la pancia si tira su con un piccolo elastico,
##    scintille alle due zampe, due note di carillon;
##  · lungo il filo, le PERLINE: una per ogni tipo di momento già
##    annodato con quel vicino — il filo RICORDA la storia che porta;
##  · il desiderio d'ORO del congedo lo tinge di dorato; il ricordo che
##    riaffiora lo mostra appena accennato (intensità ridotta);
##  · alla fine si DISSOLVE piano, lasciando scintille lungo la corsa.
##
## Un filo alla volta (le richieste si mettono in coda): il momento va
## guardato, non affastellato.

const SHADER := preload("res://shaders/filo_rosso.gdshader")

const SEGMENTI := 26
const LARGHEZZA := 0.013
const DURATA_DISEGNO := 0.45
const DURATA_PIENA := 1.55
const DURATA_DISSOLVENZA := 0.6
const MAX_PERLINE := 7

var _mesh: ImmediateMesh
var _mi: MeshInstance3D
var _mat: ShaderMaterial
var _perline: Array[MeshInstance3D] = []
var _perline_oro: StandardMaterial3D
var _perline_rosso: StandardMaterial3D
var _sfx

var _attivo := false
var _fase := ""          # disegno | piena | dissolvenza
var _t := 0.0
var _da: Node3D
var _a: Node3D
var _nodi := 0
var _oro := false
var _intensita := 1.0
var _pancia_k := 1.0     # 1 = filo molle, ~0.45 = nodo stretto
var _coda: Array = []


func _ready() -> void:
	add_to_group("filo_rosso")
	_sfx = get_node_or_null(^"/root/Sfx")
	_mesh = ImmediateMesh.new()
	_mi = MeshInstance3D.new()
	_mi.mesh = _mesh
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mi.material_override = _mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.visible = false
	add_child(_mi)
	# più CHIARE del nastro: sono i nodi della storia, devono leggersi
	# come perline luminose sul filo, non confondersi con lui
	_perline_rosso = _mat_perlina(Color(1.0, 0.62, 0.58), Color(1.0, 0.32, 0.36))
	_perline_oro = _mat_perlina(Color(1.0, 0.93, 0.72), Color(1.0, 0.82, 0.42))
	for i in MAX_PERLINE:
		var p := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.03
		sm.height = 0.06
		sm.radial_segments = 10
		sm.rings = 6
		p.mesh = sm
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.visible = false
		add_child(p)
		_perline.append(p)


func _mat_perlina(albedo: Color, emissione: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = albedo
	m.emission_enabled = true
	m.emission = emissione
	m.emission_energy_multiplier = 2.2
	return m


# ---------------------------------------------------------------- la curva

## Un punto lungo il filo: la retta tra le zampe, la pancia della
## catenaria (massima al centro: 4t(1-t)) e un filo di vento. PURA.
static func punto_filo(pa: Vector3, pb: Vector3, t: float, pancia: float, fase: float) -> Vector3:
	var p := pa.lerp(pb, t)
	var arco := 4.0 * t * (1.0 - t)
	p.y -= pancia * arco
	p += Vector3(sin(fase + t * 6.3), 0.0, cos(fase * 0.8 + t * 5.1)) * 0.008 * arco
	return p


## Dove stanno le perline dei momenti: n frazioni interne, mai sulle
## zampe (la storia sta LUNGO il filo, i capi sono di oggi). PURA.
static func frazioni_perline(n: int) -> Array:
	var out: Array = []
	var quante := mini(n, MAX_PERLINE)
	for i in quante:
		out.append(float(i + 1) / float(quante + 1))
	return out


# ---------------------------------------------------------------- l'annodo

## Mostra il filo tra due zampe vive. `nodi` = i momenti già annodati con
## questo vicino (le perline), `oro` = il desiderio d'oro del congedo,
## `intensita` < 1 = il filo appena accennato del ricordo che riaffiora.
## Se un filo è già in scena, la richiesta si mette in coda.
func annoda(da: Node3D, a: Node3D, nodi: int, oro := false, intensita := 1.0) -> void:
	if da == null or a == null or not is_instance_valid(da) or not is_instance_valid(a):
		return
	if _attivo:
		if _coda.size() < 3:
			_coda.append([da, a, nodi, oro, intensita])
		return
	_attivo = true
	_fase = "disegno"
	_t = 0.0
	_da = da
	_a = a
	_nodi = nodi
	_oro = oro
	_intensita = intensita
	_pancia_k = 1.0
	_mat.set_shader_parameter("progresso", 0.0)
	_mat.set_shader_parameter("dissolvenza", 0.0)
	_mat.set_shader_parameter("oro", 1.0 if oro else 0.0)
	_mat.set_shader_parameter("intensita", intensita)
	_mi.visible = true
	for p in _perline:
		p.visible = false
		p.material_override = _perline_oro if oro else _perline_rosso


func _zampa(n: Node3D) -> Vector3:
	if n.has_method("paw_world"):
		return n.paw_world()
	return n.global_position + Vector3(0, 0.42, 0)


func _process(delta: float) -> void:
	if not _attivo:
		return
	if _da == null or _a == null or not is_instance_valid(_da) or not is_instance_valid(_a):
		_spegni()
		return
	_t += delta
	match _fase:
		"disegno":
			var k := clampf(_t / DURATA_DISEGNO, 0.0, 1.0)
			_mat.set_shader_parameter("progresso", 1.0 - pow(1.0 - k, 2.5))
			if _t >= DURATA_DISEGNO:
				_fase = "piena"
				_t = 0.0
				_si_stringe()
		"piena":
			# il nodo si stringe: la pancia si tira su con un piccolo elastico
			_pancia_k = lerpf(_pancia_k, 0.45, 1.0 - exp(-6.0 * delta))
			if _t >= DURATA_PIENA:
				_fase = "dissolvenza"
				_t = 0.0
		"dissolvenza":
			var k2 := clampf(_t / DURATA_DISSOLVENZA, 0.0, 1.0)
			_mat.set_shader_parameter("dissolvenza", k2)
			_pancia_k = lerpf(_pancia_k, 1.1, 1.0 - exp(-2.0 * delta))
			if _t >= DURATA_DISSOLVENZA:
				_scintille_lungo_il_filo()
				_spegni()
				return
	_ridisegna()


# il momento in cui il filo È annodato: scintille alle zampe, due note
func _si_stringe() -> void:
	for capo in [_zampa(_da), _zampa(_a)]:
		_scintille(capo, 6)
	if _sfx:
		_sfx.play("select", -14.0, 1.25 if not _oro else 1.0)
		get_tree().create_timer(0.14).timeout.connect(func() -> void:
			if _sfx:
				_sfx.play("select", -15.0, 1.55 if not _oro else 1.25))


# il nastro, ricostruito ogni frame tra le due zampe vive
func _ridisegna() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var pa := _zampa(_da)
	var pb := _zampa(_a)
	var pancia: float = minf(0.2, pa.distance_to(pb) * 0.14) * _pancia_k
	var fase_vento: float = Time.get_ticks_msec() / 1000.0 * 1.7
	var punti: Array[Vector3] = []
	for i in SEGMENTI + 1:
		punti.append(punto_filo(pa, pb, float(i) / float(SEGMENTI), pancia, fase_vento))
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in SEGMENTI + 1:
		var t := float(i) / float(SEGMENTI)
		var prima: Vector3 = punti[maxi(i - 1, 0)]
		var dopo: Vector3 = punti[mini(i + 1, SEGMENTI)]
		var dir := (dopo - prima).normalized()
		var verso_cam := (cam.global_position - punti[i]).normalized()
		var lato := dir.cross(verso_cam).normalized() * LARGHEZZA
		_mesh.surface_set_uv(Vector2(t, 0.0))
		_mesh.surface_add_vertex(punti[i] - lato)
		_mesh.surface_set_uv(Vector2(t, 1.0))
		_mesh.surface_add_vertex(punti[i] + lato)
	_mesh.surface_end()
	# le perline della storia: compaiono col disegno, una dopo l'altra
	var progresso := 1.0 if _fase != "disegno" else clampf(_t / DURATA_DISEGNO, 0.0, 1.0)
	var frazioni := frazioni_perline(_nodi)
	for i in _perline.size():
		var p := _perline[i]
		if i >= frazioni.size() or _fase == "dissolvenza":
			p.visible = false
			continue
		var f: float = frazioni[i]
		if f > progresso:
			p.visible = false
			continue
		p.visible = true
		p.global_position = punto_filo(pa, pb, f, pancia, fase_vento)
		p.scale = Vector3.ONE * (0.7 + 0.3 * sin(fase_vento * 2.6 + f * 9.0))


func _spegni() -> void:
	_attivo = false
	_mi.visible = false
	for p in _perline:
		p.visible = false
	_da = null
	_a = null
	# la prossima richiesta in coda, se c'è
	if not _coda.is_empty():
		var r: Array = _coda.pop_front()
		(func() -> void:
			annoda(r[0], r[1], int(r[2]), bool(r[3]), float(r[4]))).call_deferred()


# --------------------------------------------------------------- scintille

func _scintille(pos: Vector3, n: int) -> void:
	var col := Color(1.0, 0.82, 0.45) if _oro else Color(1.0, 0.4, 0.45)
	for i in n:
		var s := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = randf_range(0.012, 0.026)
		m.height = m.radius * 2.0
		m.radial_segments = 6
		m.rings = 3
		s.mesh = m
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = col
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		s.material_override = mat
		s.position = pos
		add_child(s)
		var a := TAU * float(i) / float(n) + randf_range(-0.3, 0.3)
		var to := pos + Vector3(cos(a) * randf_range(0.1, 0.28),
				randf_range(0.05, 0.3), sin(a) * randf_range(0.1, 0.28))
		var tw := create_tween()
		tw.tween_property(s, "position", to, 0.5) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.5)
		tw.tween_callback(s.queue_free)


func _scintille_lungo_il_filo() -> void:
	if _da == null or _a == null or not is_instance_valid(_da) or not is_instance_valid(_a):
		return
	var pa := _zampa(_da)
	var pb := _zampa(_a)
	for i in 5:
		var t := float(i + 1) / 6.0
		_scintille(punto_filo(pa, pb, t, 0.08, 0.0), 2)
