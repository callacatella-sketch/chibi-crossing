extends SceneTree
func _init() -> void: _go()
func _go() -> void:
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for i in 8: await process_frame
	await create_timer(2.0).timeout
	var bs: Node = current_scene.get_node_or_null("BuildSystem")
	bs.call("set_persist_for_debug", false)
	bs.set("_locks_active", false)
	bs.call("set_active_for_debug", true, Vector3(2, 0, 4), "Tavolino")
	await create_timer(1.0).timeout
	var p: Control = bs.get("_panel")
	var d: Control = bs.get("_dock")
	print("APERTO   min.y=", p.get_combined_minimum_size().y,
			"  dock=", d.get_global_rect(), "  panel=", p.get_global_rect())
	bs.call("_piega", false)
	await create_timer(1.2).timeout
	print("PIEGATO  min.y=", p.get_combined_minimum_size().y,
			"  dock=", d.get_global_rect(), "  panel=", p.get_global_rect())
	print("schermo alto: ", get_root().size.y)
	print("ATE_BASSA attuale: ", bs.get("ATE_BASSA"))
	# e la barra dei colori: dov'è rispetto al pannello, nei due stati?
	bs.call("_piega", true)
	await create_timer(1.0).timeout
	var eco: Node = bs.call("_economy")
	if eco: eco.call("unlock_variant", "menta")
	bs.call("_update_variant_bar")
	await create_timer(0.4).timeout
	var vb: Control = bs.get("_variant_bar")
	print("APERTO   barra=", vb.get_global_rect(), " visibile=", vb.visible,
			"  dentro il pannello? ", p.get_global_rect().intersects(vb.get_global_rect()))
	bs.call("_piega", false)
	await create_timer(1.0).timeout
	print("PIEGATO  barra=", vb.get_global_rect(),
			"  dentro il pannello? ", p.get_global_rect().intersects(vb.get_global_rect()))
	print("PIEGATO  panel bottom=", p.get_global_rect().end.y, " (schermo 1080)")
	quit()
