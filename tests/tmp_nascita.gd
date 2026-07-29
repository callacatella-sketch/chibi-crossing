extends SceneTree
## USA E GETTA: una nascita vera, dall'inizio alla fine, nel gioco vero.
## Costruisce tre lettini, insedia due adulti di sesso diverso, li fa
## affezionare, forza la nascita, va sulla soglia, dà il nome e fotografa
## il cucciolo accanto a un adulto.

const DIR := "/private/tmp/claude-501/-Users-duck-Developer-chibi-crossing/64b02dc3-a849-4f5f-ba05-53ed1dcd7e02/scratchpad/"
const DNA = preload("res://scenes/npc/ChibiDNA.gd")


func _init() -> void:
	var ps: PackedScene = load("res://scenes/levels/MainLevel.tscn")
	root.add_child(ps.instantiate())
	_go()


func _go() -> void:
	await process_frame
	await create_timer(2.6).timeout
	var vis = root.get_tree().get_first_node_in_group("visitors")
	var leg = root.get_tree().get_first_node_in_group("legami")
	var nas = root.get_tree().get_first_node_in_group("nascite")
	var build = root.get_tree().get_first_node_in_group("build_system")
	if build == null:
		build = root.get_tree().get_first_node_in_group("build")
	if vis == null or leg == null or nas == null or build == null:
		print("MANCA: vis=%s leg=%s nas=%s build=%s" % [vis, leg, nas, build])
		quit(1)
		return

	# --- tre lettini col tetto: due per i genitori, uno per chi nasce ---
	var celle := [Vector2i(6, 0), Vector2i(9, 0), Vector2i(12, 0)]
	for c in celle:
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				build.call("place_cell", c + Vector2i(dx, dz), "Pavimento", 0, false, 0, "")
		build.call("place_cell", c, "Letto", 0, false, 0, "")
		build.call("place_cell", c + Vector2i(0, -1), "Tetto", 0, false, 1, "")
		build.call("place_cell", c, "Tetto", 0, false, 1, "")
		build.call("place_cell", c + Vector2i(0, 1), "Tetto", 0, false, 1, "")
	await create_timer(1.0).timeout

	# --- due adulti di sesso diverso ---
	var semi := []
	var vogliamo := ["m", "f"]
	var s := 1
	while vogliamo.size() > 0 and s < 4000:
		var d: Dictionary = DNA.generate(s)
		var sx: String = DNA.sesso(d)
		if sx in vogliamo:
			vogliamo.erase(sx)
			semi.append(s)
		s += 1
	vis.call("debug_settle", semi[0], celle[0])
	vis.call("debug_settle", semi[1], celle[1])
	await create_timer(1.2).timeout
	var adulti: Array = vis.call("adulti_del_villaggio")
	print("ADULTI: ", adulti.size())
	for a in adulti:
		print("  ", a[0], " sesso=", DNA.sesso(a[2]), " label=", a[1])
	if adulti.size() < 2:
		quit(1)
		return

	# --- li facciamo affezionare davvero (l'affinità dei cervelli) ---
	# i cervelli nascono pigri: una lettura li crea
	vis.call("affinita_fra", str(adulti[0][1]), str(adulti[1][1]))
	vis.call("affinita_fra", str(adulti[1][1]), str(adulti[0][1]))
	var brains = vis.get("_brains")
	for i in 2:
		var b = brains.get(str(adulti[i][1]))
		if b != null:
			b.bump_affinita(str(adulti[1 - i][1]), 20)
	print("AFFINITA: ", vis.call("affinita_fra", str(adulti[0][1]), str(adulti[1][1])),
			" / ", vis.call("affinita_fra", str(adulti[1][1]), str(adulti[0][1])))

	# --- la nascita ---
	nas.call("debug_forza_nascita")
	await create_timer(0.6).timeout
	var in_arrivo = nas.get("_in_arrivo")
	print("IN ARRIVO: ", in_arrivo)
	if in_arrivo.is_empty():
		print("NESSUNA NASCITA")
		quit(1)
		return

	# --- Mochi va sulla soglia ---
	var mochi := _find(root, "/Mochi.gd")
	var player := _per_nome(root, "Player")
	var madre_label: String = vis.call("label_di_nome", str(in_arrivo["madre"]))
	var madre: Node3D = vis.call("node_di", madre_label)
	if player and madre:
		player.global_position = madre.global_position + Vector3(1.2, 0, 0.6)
	await create_timer(0.8).timeout
	print("PROMPT VISIBILE: ", nas.get("_prompt").visible)

	# --- il battesimo ---
	nas.call("_apri_pannello")
	await process_frame
	nas.get("_campo").text = "Ribes"
	nas.call("_conferma_nome")
	await create_timer(1.4).timeout

	var dopo: Array = vis.get("_residents")
	print("RESIDENTI ORA: ", dopo.size())
	var cucciolo: Node3D = null
	for r in dopo:
		if str(r.get("dna", {}).get("name", "")) == "Ribes":
			cucciolo = r.get("node") as Node3D
	if cucciolo == null:
		print("IL CUCCIOLO NON C'E'")
		quit(1)
		return
	print("CRESCITA: ", leg.call("crescita", "Ribes"))
	print("E_NATO: ", leg.call("e_nato", "Ribes"))
	print("GENITORI: ", leg.call("genitori_di", "Ribes"))
	print("E_CUCCIOLO: ", vis.call("e_cucciolo", str(cucciolo.get("dna")["label"])))
	print("EREDITA: ", leg.call("eredita_di", "Ribes"))

	# --- la foto: il cucciolo accanto a sua madre, tutti e due di fronte ---
	if player:
		player.global_position = madre.global_position + Vector3(-6, 0, -6)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	for stadio in [[0.0, "nato_appena.png"], [0.5, "nato_meta.png"],
			[1.0, "nato_grande.png"]]:
		cucciolo.call("set_cucciolo", float(stadio[0]))
		for _i in 6:
			cucciolo.global_position = madre.global_position + Vector3(0.62, 0, 0.05)
			cucciolo.rotation.y = 0.0
			madre.rotation.y = 0.0
			var mid: Vector3 = (cucciolo.global_position + madre.global_position) * 0.5
			cam.global_position = mid + Vector3(0.0, 0.52, 1.65)
			cam.look_at(mid + Vector3(0, 0.34, 0), Vector3.UP)
			await process_frame
		await create_timer(0.25).timeout
		cucciolo.global_position = madre.global_position + Vector3(0.62, 0, 0.05)
		cucciolo.rotation.y = 0.0
		madre.rotation.y = 0.0
		await process_frame
		_shot(str(stadio[1]))
	quit(0)


func _shot(nome: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(DIR + nome)
	print("SHOT ", nome)


func _per_nome(n: Node, nome: String) -> Node3D:
	if n.name == nome:
		return n as Node3D
	for c in n.get_children():
		var r := _per_nome(c, nome)
		if r != null:
			return r
	return null


func _find(n: Node, suff: String) -> Node3D:
	var s = n.get_script()
	if s != null and str(s.resource_path).ends_with(suff):
		return n as Node3D
	for c in n.get_children():
		var r := _find(c, suff)
		if r != null:
			return r
	return null
