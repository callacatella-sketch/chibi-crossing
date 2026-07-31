extends SceneTree

const VIS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")


func _mk() -> Node3D:
	var v: Node3D = VIS.new()
	v.set("species", "chibi")
	v.set("dna", DNAG.generate(4242))
	root.add_child(v)
	v.set("mode", "resident")
	v.position = Vector3(3, 0, -2)
	return v


func _init() -> void:
	await process_frame
	await process_frame

	# 1) r_wander senza casa
	var v := _mk()
	v.call("_enter_state", "r_wander")
	print("A) _house vuoto -> _state=", v.get("_state"), " target=", v.get("_target"),
			" next=", v.get("_next_state"))

	# 2) fa qualche frame: si muove davvero?
	var p0: Vector3 = v.position
	for i in 120:
		await process_frame
	print("B) dopo 120 frame: pos spostata di %.3f m, _state=%s"
			% [p0.distance_to(v.position), str(v.get("_state"))])

	# 3) r_wander CON casa (non regredito)
	var w := _mk()
	w.call("setup_resident", {"bed": null, "cell": Vector2i(9, 9), "front": Vector3(10, 0, 10)})
	w.call("_enter_state", "r_wander")
	var t: Vector3 = w.get("_target")
	print("C) con casa -> _state=%s target=%s dist da front=%.2f"
			% [str(w.get("_state")), str(t), t.distance_to(Vector3(10, 0, 10))])

	# 4) resident_wake senza casa
	var z := _mk()
	z.position = Vector3(-5, 0, 7)
	z.call("resident_sleep")
	z.call("resident_wake")
	print("D) wake senza casa -> pos=", z.position, " _state=", z.get("_state"))

	# 5) resident_wake CON casa
	var k := _mk()
	k.call("setup_resident", {"bed": null, "cell": Vector2i(1, 1), "front": Vector3(2, 0, 3)})
	k.position = Vector3(-9, 0, -9)
	k.call("resident_sleep")
	k.call("resident_wake")
	print("E) wake con casa -> pos=", k.position, " (atteso 2,0,3)")

	# 6) il ciclo lungo: parte da r_idle e non si pianta
	var q := _mk()
	q.call("_enter_state", "r_idle")
	var visti := {}
	for i in 1400:
		await process_frame
		visti[str(q.get("_state"))] = true
	print("F) 1400 frame da r_idle senza casa -> stati visti: ", visti.keys())

	quit()
