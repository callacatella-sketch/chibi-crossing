extends SceneTree
const VISITOR := preload("res://scenes/npc/Visitor.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")
func _process(_d: float) -> bool:
	var v = VISITOR.new()
	v.species = "chibi"
	v.mode = "resident"
	v.dna = DNA.generate(4242)
	root.add_child(v)
	v.set_process(false)
	var vis: Node3D = v.get("_vis")
	var corpo: Node3D = v.get("_corpo")
	var testa: Node3D = v.get("_head")
	print("v.scale=%s  _vis.scale=%s  _corpo.scale=%s" % [str(v.scale), str(vis.scale), str(corpo.scale)])
	print("testa locale y=%.3f  globale y=%.3f" % [testa.position.y, testa.global_position.y])
	v._process(1.0/60.0)
	print("dopo un frame: _vis.scale=%s testa globale y=%.3f" % [str(vis.scale), testa.global_position.y])
	quit(0)
	return true
