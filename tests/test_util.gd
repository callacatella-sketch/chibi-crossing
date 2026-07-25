extends RefCounted
## Mini-framework di test dependency-free (nessun addon, nessuna rete).
## I casi di test stanno in tests/cases/test_*.gd ed espongono `func run(t)`.
## Si esegue con:
##   Godot --headless --path . --script res://tests/test_runner.gd

var passes := 0
var failures := 0
var current_file := ""
var _fails: Array[String] = []


func ok(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
	else:
		failures += 1
		_fails.append("[%s] %s" % [current_file, msg])


func eq(a, b, msg: String) -> void:
	ok(a == b, "%s (atteso %s, ottenuto %s)" % [msg, str(b), str(a)])


func almost(a: float, b: float, msg: String, eps := 0.0001) -> void:
	ok(absf(a - b) <= eps, "%s (atteso ~%s, ottenuto %s)" % [msg, str(b), str(a)])


func report() -> void:
	print("")
	print("==== TEST: %d passati, %d falliti ====" % [passes, failures])
	for f in _fails:
		print("  FAIL: ", f)
