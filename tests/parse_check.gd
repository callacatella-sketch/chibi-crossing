extends SceneTree
## Verifica di sola compilazione dei file toccati dal volto vivo.
##   Godot --headless --path . --script res://tests/parse_check.gd


func _initialize() -> void:
	var files := [
		"res://scenes/characters/FaceController.gd",
		"res://scenes/characters/Mochi.gd",
		"res://scenes/npc/ChibiBuilder.gd",
		"res://scenes/npc/Visitor.gd",
		"res://scenes/characters/Coop.gd",
		"res://scenes/world/Calendar.gd",
		"res://scenes/levels/DebugHarness.gd",
	]
	var bad := 0
	for f in files:
		var s = load(f)
		if s == null or not (s is GDScript) or not s.can_instantiate():
			push_error("PARSE FAIL: %s" % f)
			bad += 1
		else:
			print("ok  ", f)
	if bad > 0:
		print("PARSE_CHECK_FAIL ", bad)
		quit(1)
	else:
		print("PARSE_CHECK_OK")
		quit(0)
