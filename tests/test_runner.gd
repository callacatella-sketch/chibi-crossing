extends SceneTree
## Runner dei test: carica ed esegue tutti i tests/cases/test_*.gd, poi esce con
## codice 0 (tutti passati) o 1 (almeno un fallimento) — adatto anche alla CI.
##   Godot --headless --path . --script res://tests/test_runner.gd


func _initialize() -> void:
	var util_script := load("res://tests/test_util.gd")
	var t = util_script.new()
	for fname in _list_cases():
		print("RUN  ", fname)
		t.current_file = fname
		var script := load("res://tests/cases/" + fname)
		# Uno script con errori di parse non deve far cadere l'intero runner
		# (altrimenti quit() non viene chiamato e il processo resta appeso).
		if script == null or not (script is GDScript) or not script.can_instantiate():
			t.ok(false, "%s: non compilabile (errore di parse)" % fname)
			print("SKIP ", fname)
			continue
		var case = script.new()
		if case.has_method("run"):
			case.run(t)
		print("DONE ", fname)
	t.report()
	quit(1 if t.failures > 0 else 0)


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
