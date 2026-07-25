extends SceneTree

## Smoke test dell'economia (noccioline/stelline, negozio, varianti).
## Esegui:  godot --headless --path . --script res://tests/eco_smoke.gd

func _initialize() -> void:
	var fails: Array[String] = []
	var check := func(cond: bool, name: String) -> void:
		if not cond:
			fails.append(name)

	var Eco: GDScript = load("res://scenes/ui/Economy.gd")
	var e = Eco.new()
	get_root().add_child(e)

	# valute
	e.add_nuts(50)
	e.add_stars(3)
	check.call(e.nuts == 50 and e.stars == 3, "add_nuts/stars")
	check.call(e.spend(20, "nut") and e.nuts == 30, "spend nut")
	check.call(not e.spend(999, "star"), "spend star insufficiente")

	# catture rare -> stelline
	var s0: int = e.stars
	e.award_catch("rosina")
	check.call(e.stars == s0 + 1, "award rara")
	e.award_catch("rosa")
	check.call(e.stars == s0 + 1, "comune niente stelle")
	check.call(e.sell_value("gialla") == 14, "valore vendita")

	# sblocchi
	e.unlock_piece("Fontana")
	check.call(e.is_piece_unlocked("Fontana"), "unlock pezzo")
	check.call(e.is_shop_piece("Fontana") and not e.is_shop_piece("Sedia"), "is_shop_piece")
	e.unlock_variant("menta")
	check.call(e.is_variant_unlocked("menta"), "unlock variante")
	check.call(e.is_variant_unlocked(""), "originale sempre valido")
	check.call(e.piece_takes_variant("Sedia") and not e.piece_takes_variant("Muro"), "piece_takes_variant")

	# salvataggio/caricamento
	var data: Dictionary = e.save_extra()
	var e2 = Eco.new()
	get_root().add_child(e2)
	e2.load_extra(data)
	check.call(e2.nuts == e.nuts and e2.stars == e.stars, "roundtrip valute")
	check.call(e2.is_piece_unlocked("Fontana") and e2.is_variant_unlocked("menta"), "roundtrip sblocchi")

	# tinta della variante su un materiale handpaint
	var hp: Shader = load("res://shaders/handpaint.gdshader")
	var mi := MeshInstance3D.new()
	var sm := ShaderMaterial.new()
	sm.shader = hp
	sm.set_shader_parameter("color_a", Color("c89a6b"))
	sm.set_shader_parameter("color_b", Color("a87c50"))
	mi.material_override = sm
	var root := Node3D.new()
	root.add_child(mi)
	e.apply_variant(root, "menta")
	var ca = (mi.material_override as ShaderMaterial).get_shader_parameter("color_a")
	check.call(ca is Color and ca != Color("c89a6b"), "apply_variant tinge")

	if fails.is_empty():
		print("ECO_SMOKE: PASS (tutti i controlli ok)")
	else:
		print("ECO_SMOKE: FAIL -> ", fails)
	quit()
