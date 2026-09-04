extends SceneTree
## Quanto spesso l'allarme SATURA? Se l'allarme grezzo (pre-clamp) supera
## il divisore, il tamponamento non può fare niente — e il tetto morde
## proprio sui più reattivi, cioè inverte la firma del social buffering.
## Questo conta i percetti VERI di un villaggio vero, senza toccare nulla.
var _n := 0
var _oltre1 := 0
var _oltre15 := 0
var _oltre2 := 0
var _somma := 0.0
var _max := 0.0
func _init() -> void: _go()
func _go() -> void:
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for i in 8: await process_frame
	await create_timer(2.0).timeout
	var vis: Node = current_scene.get_node_or_null("Visitors")
	var bs: Node = current_scene.get_node_or_null("BuildSystem")
	if bs: bs.call("set_persist_for_debug", false)
	var quanti := int(OS.get_environment("CHIBI_QUANTI")) if OS.get_environment("CHIBI_QUANTI") != "" else 14
	for i in quanti:
		vis.call("debug_settle", Vector2i(3 + (i % 5) * 2, 3 + (i / 5) * 2))
		await process_frame
	await create_timer(1.0).timeout
	var minuti := float(OS.get_environment("CHIBI_MINUTI")) if OS.get_environment("CHIBI_MINUTI") != "" else 3.0
	var player: Node3D = current_scene.get_node_or_null("Player")
	var t0 := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	# Mochi gira come gira un giocatore, e a ogni percetto POSSIBILE si
	# campiona l'allarme grezzo — senza chiamare percepisci, per non
	# consumare i raffreddamenti veri
	while Time.get_ticks_msec() - t0 < minuti * 60000.0:
		await process_frame
		if player:
			var t := float(Time.get_ticks_msec() - t0) / 1000.0
			player.global_position = Vector3(6.0 + sin(t * 0.31) * 5.0, 0.0,
					6.0 + cos(t * 0.23) * 5.0)
		var pp: Vector3 = player.global_position if player else Vector3.ZERO
		for r in (vis.get("_residents") as Array):
			var label := str(r.get("label", ""))
			var animi: Dictionary = vis.get("_animi")
			if not animi.has(label):
				continue
			var node := r.get("node") as Node3D
			if node == null:
				continue
			var d: float = pp.distance_to(node.global_position)
			if d > 3.2:
				continue
			var lim = (animi[label] as RefCounted).limbico
			var carica := 0.0
			var m: Dictionary = lim.marchi
			if m.has("chi|giocatore"):
				carica = float((m["chi|giocatore"] as Dictionary)["carica"])
			var grezzo: float = vis.call("indizio_grezzo", 3.0, 0.0,
					clampf(1.0 - d / 3.2, 0.0, 1.0))
			var a: float = (maxf(0.0, -carica) + grezzo) * float(lim.reattivita) \
					* (1.0 + float(lim.arousal) * 0.6)
			_n += 1
			_somma += a
			_max = maxf(_max, a)
			if a > 1.0: _oltre1 += 1
			if a > 1.5: _oltre15 += 1
			if a > 2.0: _oltre2 += 1
	print("\n=== L'ALLARME GREZZO (pre-clamp), su ", _n, " campioni ===")
	print("  medio  : ", "%.4f" % (_somma / maxf(1.0, float(_n))))
	print("  massimo: ", "%.4f" % _max)
	print("  oltre 1.0 (già saturo oggi)      : ", _oltre1, "  ",
			"%.1f%%" % (100.0 * float(_oltre1) / maxf(1.0, float(_n))))
	print("  oltre 1.5 (K=0.5 non morde)      : ", _oltre15, "  ",
			"%.1f%%" % (100.0 * float(_oltre15) / maxf(1.0, float(_n))))
	print("  oltre 2.0 (K=1.0 non morde)      : ", _oltre2, "  ",
			"%.1f%%" % (100.0 * float(_oltre2) / maxf(1.0, float(_n))))
	quit()
