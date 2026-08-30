extends SceneTree
## runner usa-e-getta: UN caso solo. CHIBI_CASO=test_gioia.gd
var _t
var _fatto := false
func _initialize() -> void:
	_t = load("res://tests/test_util.gd").new()
func _process(_d: float) -> bool:
	if _fatto:
		_t.report()
		quit(1 if _t.failures > 0 else 0)
		return true
	_fatto = true
	if L10n.lingua_corrente() != L10n.SORGENTE:
		L10n.imposta(L10n.SORGENTE)
	var f := OS.get_environment("CHIBI_CASO")
	_t.current_file = f
	var s := load("res://tests/cases/" + f)
	if s == null or not (s is GDScript) or not s.can_instantiate():
		print("NON COMPILA")
		quit(1)
		return true
	var c = s.new()
	c.run(_t)
	return false
