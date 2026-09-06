extends SceneTree
## Runner FILTRATO — identico a tests/test_runner.gd ma esegue solo i casi
## nominati in CHIBI_CASI (separati da virgola). Serve al banco delle
## mutazioni: la suite intera costa 2'22", e una mutazione va provata decine
## di volte. Le affermazioni «resta VERDE» si rifanno comunque sulla suite
## INTERA, perché un altro file potrebbe essere l'unico a vederla.

var _t
var _cases: Array = []
var _i := 0


func _initialize() -> void:
	var util_script := load("res://tests/test_util.gd")
	_t = util_script.new()
	var filtro := OS.get_environment("CHIBI_CASI")
	for f in filtro.split(",", false):
		_cases.append(f.strip_edges())


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
