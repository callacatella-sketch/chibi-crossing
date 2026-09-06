extends SceneTree
const VISITOR := preload("res://scenes/npc/Visitor.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")

func _process(_d: float) -> bool:
	var lo := 1e9
	var hi := -1e9
	for s in [4242, 7717, 3311, 8101, 5150]:
		var v = VISITOR.new()
		v.species = "chibi"
		v.mode = "resident"
		v.dna = DNA.generate(s)
		root.add_child(v)
		v.set_process(false)
		var testa: Node3D = v.get("_head")
		var aabb := AABB()
		var primo := true
		for m in v.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null:
				continue
			var a := mi.global_transform * mi.mesh.get_aabb()
			if primo:
				aabb = a
				primo = false
			else:
				aabb = aabb.merge(a)
		print("seme %d: testa.y=%.3f  aabb.y=[%.3f, %.3f]  altezza=%.3f"
				% [s, testa.global_position.y if testa else -1.0,
				aabb.position.y, aabb.position.y + aabb.size.y, aabb.size.y])
		lo = minf(lo, aabb.position.y)
		hi = maxf(hi, aabb.position.y + aabb.size.y)
		v.free()
	print("--- il corpo di un chibi sta fra %.3f e %.3f m" % [lo, hi])
	quit(0)
	return true
