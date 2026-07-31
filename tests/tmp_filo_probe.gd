extends SceneTree
## Sonda: cosa succede se la guardia DENTRO il differito scatta davvero?

const FILO := preload("res://scenes/world/FiloRosso.gd")

var _filo
var _b
var _c
var _step := 0


func _process(_d: float) -> bool:
	_step += 1
	if _step == 1:
		_filo = FILO.new()
		root.add_child(_filo)
		var a := Node3D.new()
		_b = Node3D.new()
		_c = Node3D.new()
		var d := Node3D.new()
		for n in [a, _b, _c, d]:
			_filo.add_child(n)
		_filo.annoda(a, d, 1)             # filo attivo
		_filo.annoda(a, _b, 2)            # coda[0] — viva ORA
		_filo.annoda(a, _c, 3)            # coda[1] — viva
		print("coda prima  = ", (_filo.get("_coda") as Array).size())
		_filo.call("_spegni")             # pesca coda[0], differisce
		print("coda dopo   = ", (_filo.get("_coda") as Array).size())
		_b.free()                         # muore PRIMA che il differito giri
		return false
	if _step == 2:
		print("attivo      = ", _filo.get("_attivo"))
		print("coda residua= ", (_filo.get("_coda") as Array).size())
		print("c ancora vivo=", is_instance_valid(_c))
		return false
	if _step == 6:
		print("--- dopo qualche frame ---")
		print("attivo      = ", _filo.get("_attivo"))
		print("coda residua= ", (_filo.get("_coda") as Array).size())
		quit(0)
	return false
