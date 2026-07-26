extends SceneTree
## Runner dei test: carica ed esegue tutti i tests/cases/test_*.gd, poi esce con
## codice 0 (tutti passati) o 1 (almeno un fallimento) — adatto anche alla CI.
##   Godot --headless --path . --script res://tests/test_runner.gd
##
## I casi girano al PRIMO FRAME, non in _initialize(): lì l'albero non è ancora
## vivo e un nodo messo in scena non riceverebbe il suo _ready (Mochi, il volto
## e l'economia lo pretendono, e chiamerebbero get_tree() su un albero nullo).

var _t
var _cases: Array = []
var _i := 0


func _initialize() -> void:
	var util_script := load("res://tests/test_util.gd")
	_t = util_script.new()
	_cases = _list_cases()


## UN CASO PER FRAME. I nodi messi in scena con t.stage() restano vivi fino
## alla fine del frame: così le chiamate differite che il gioco accoda nel
## proprio _ready (call_deferred) trovano ancora il loro nodo nell'albero, e
## solo al frame successivo si libera tutto. Liberarli subito lascerebbe quelle
## chiamate a puntare nel vuoto.
func _process(_delta: float) -> bool:
	# prima cosa: via i nodi del caso precedente (le differite sono già passate)
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
	# Uno script con errori di parse non deve far cadere l'intero runner
	# (altrimenti quit() non viene chiamato e il processo resta appeso).
	if script == null or not (script is GDScript) or not script.can_instantiate():
		_t.ok(false, "%s: non compilabile (errore di parse)" % fname)
		print("SKIP ", fname)
		return false
	var case = script.new()
	if case.has_method("run"):
		case.run(_t)
	print("DONE ", fname)
	return false


func _list_cases() -> Array:
	var out := []
	var dir := DirAccess.open("res://tests/cases")
	if dir == null:
		push_error("Cartella res://tests/cases assente")
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.begins_with("test_") and f.ends_with(".gd"):
			out.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out
