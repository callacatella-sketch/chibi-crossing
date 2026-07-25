extends SceneTree
## Smoke test headless del volto dei villager: genera qualche DNA, costruisce
## il chibi con ChibiBuilder (che ora restituisce anche il rig facciale),
## monta il FaceController e lo esercita. Verifica anche che Visitor.gd
## compili (usa il rig).
##   Godot --headless --path . --script res://tests/npc_face_smoke.gd


func _initialize() -> void:
	var DNA := load("res://scenes/npc/ChibiDNA.gd")
	var B := load("res://scenes/npc/ChibiBuilder.gd")
	var FC := load("res://scenes/characters/FaceController.gd")
	var V := load("res://scenes/npc/Visitor.gd")
	for s in [["ChibiDNA", DNA], ["ChibiBuilder", B], ["FaceController", FC], ["Visitor", V]]:
		if s[1] == null or not (s[1] is GDScript) or not s[1].can_instantiate():
			push_error("%s: errore di parse" % s[0])
			quit(1)
			return

	var archetypes := ["gatto", "coniglio", "orsetto", "volpina", "topolino"]
	var checked := 0
	for seed_v in range(5):
		var dna: Dictionary = DNA.generate(seed_v * 131 + 7)
		var parts: Dictionary = B.build(dna)
		get_root().add_child(parts["root"])
		if not parts.has("face"):
			push_error("build() non restituisce 'face'")
			quit(1)
			return
		var rig: Dictionary = parts["face"]
		rig["head"] = parts["head"]
		# controlli sul rig
		if (rig["eyes"] as Array).size() != 2:
			push_error("occhi: %d" % (rig["eyes"] as Array).size()); quit(1); return
		if (rig["brows"] as Array).size() != 2:
			push_error("sopracciglia mancanti"); quit(1); return
		if (rig["mouths"] as Dictionary).size() < 6:
			push_error("bocche: %d" % (rig["mouths"] as Dictionary).size()); quit(1); return

		var face = FC.new()
		face.setup(rig)
		var target := Node3D.new()
		target.position = Vector3(0.6, 1.0, -1.5)
		get_root().add_child(target)
		face.look_at_node(target)
		# esercita ogni espressione + parlato
		for e in FC.EXPRESSIONS.keys():
			face.set_expression(e)
			face.set_talking(true)
			for f in 8:
				face.update(0.016)
		face.set_mood("felice")
		face.set_talking(false)
		for f in 20:
			face.update(0.016)
		checked += 1
		parts["root"].queue_free()
		target.queue_free()

	print("NPC_FACE_OK chibi=", checked)
	quit(0)
