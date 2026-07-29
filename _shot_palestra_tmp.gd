extends SceneTree
## TEMPORANEO — il provino degli attrezzi: ogni pezzo del catalogo
## "Palestra" fotografato di tre quarti su un fondo neutro, con la sua
## etichetta nel nome del file.
##   SHOT_OUT=<cartella> Godot --path . --script res://_shot_palestra_tmp.gd

const CAT := preload("res://scenes/build/BuildCatalog.gd")

var _frame := 0
var _out := ""
var _cam: Camera3D
var _pezzi: Array = []
var _i := -1
var _t := 0
var _nodo: Node3D


func _initialize() -> void:
	_out = OS.get_environment("SHOT_OUT")
	root.size = Vector2i(900, 900)
	# un fondo neutro e una luce da studio: qui si guarda l'OGGETTO
	var mondo := Node3D.new()
	root.add_child(mondo)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.90, 0.88, 0.83)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.74, 0.78)
	e.ambient_light_energy = 0.85
	env.environment = e
	mondo.add_child(env)
	var sole := DirectionalLight3D.new()
	sole.rotation = Vector3(-0.95, -0.7, 0)
	sole.light_energy = 1.5
	sole.shadow_enabled = true
	mondo.add_child(sole)
	var piano := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	piano.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.84, 0.81, 0.75)
	piano.material_override = pmat
	mondo.add_child(piano)
	_cam = Camera3D.new()
	_cam.fov = 34.0
	mondo.add_child(_cam)
	_cam.current = true
	for v in CAT.items():
		if int(v.get("cat", 0)) == 3:
			_pezzi.append(v)
	print("PEZZI: ", _pezzi.size())


func _process(_d: float) -> bool:
	_frame += 1
	if _frame < 12:
		return false
	if _i < 0:
		_i = 0
		_monta()
		return false
	if _frame == _t + 10:
		var nome := str(_pezzi[_i]["name"]).to_lower().replace(" ", "_")
		root.get_texture().get_image().save_png(
				_out.path_join("attrezzo_%d_%s.png" % [_i, nome]))
		print("SHOT ", nome)
		_i += 1
		if _i >= _pezzi.size():
			quit(0)
			return true
		_monta()
	return false


func _monta() -> void:
	if _nodo and is_instance_valid(_nodo):
		_nodo.queue_free()
	_nodo = (_pezzi[_i]["builder"] as Callable).call()
	root.get_child(0).add_child(_nodo)
	# l'inquadratura si adatta all'ingombro dichiarato dalle collisioni
	var alt := 0.6
	for c in (_pezzi[_i].get("cols", []) as Array):
		alt = maxf(alt, float((c[1] as Vector3).y) + float((c[0] as Vector3).y) * 0.5)
	# l'inquadratura tiene DENTRO tutto il pezzo: si guarda al centro
	# dell'altezza e ci si allontana in proporzione
	var centro := alt * 0.5
	var d: float = 1.5 + alt * 1.15
	# di TRE QUARTI DAVANTI: il fronte dei pezzi del catalogo è -Z, e
	# fin qui li stavo fotografando tutti di spalle
	_cam.global_position = Vector3(d * 0.62, centro + alt * 0.45 + 0.35, -d * 0.78)
	_cam.look_at(Vector3(0, centro, 0))
	_t = _frame
