extends SceneTree
## RUNNER TEMPORANEO DELLA LENTE (da cancellare a fine sessione).
## Esegue SOLO i casi elencati in CHIBI_CASI (separati da virgola).
##   CHIBI_CASI=test_giudice.gd Godot --headless --path . --script res://tests/zz_lente_runner.gd

var _t
var _cases: Array = []
var _i := 0


func _initialize() -> void:
	var util_script := load("res://tests/test_util.gd")
	_t = util_script.new()
	var elenco := OS.get_environment("CHIBI_CASI")
	for c in elenco.split(",", false):
		_cases.append(str(c).strip_edges())


func _process(_delta: float) -> bool:
	if L10n.lingua_corrente() != L10n.SORGENTE:
		L10n.imposta(L10n.SORGENTE)
	_t.cleanup_staged()
	if _i >= _cases.size():
		_t.report()
		quit(1 if _t.failures > 0 else 0)
		return true
	var fname: String = _cases[_i]
	_i += 1
	print("RUN  ", fname)
	_t.current_file = fname
	var script := load("res://tests/cases/" + fname)
	if script == null or not (script is GDScript) or not script.can_instantiate():
		_t.ok(false, "%s: non compilabile (errore di parse)" % fname)
		print("SKIP ", fname)
		return false
	var case = script.new()
	if case.has_method("run"):
		case.run(_t)
	print("DONE ", fname)
	return false
