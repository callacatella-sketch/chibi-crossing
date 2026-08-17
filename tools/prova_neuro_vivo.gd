extends SceneTree
## LA PROVA VIVA della neurochimica: nel MainLevel VERO, con residenti veri,
## si guarda se il modello ARRIVA AL CORPO — e se l'umore resta una cosa che
## si muove invece di una costante.
##
##   CHIBI_MINUTI=2 Godot --headless --path . --script res://tools/prova_neuro_vivo.gd
##
## ⚠️ Serve perche' la suite non lo dice: il difetto che questo banco esiste
## per sorvegliare (247 righe di somatizzazione senza nessun chiamante, e un
## umore saturo a +1.0000 per tutti) conviveva con 68157 asserzioni verdi.

var _guasti := 0

func _init() -> void:
	_go()

func _dico(ok: bool, testo: String) -> void:
	if not ok:
		_guasti += 1
	print(("  ok      " if ok else "  GUASTO  ") + testo)

func _go() -> void:
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 8:
		await process_frame
	var liv := current_scene
	var vis := liv.get_node_or_null("Visitors")
	var build := liv.get_node_or_null("BuildSystem")
	if vis == null or build == null:
		print("GUASTO: livello incompleto"); quit(1); return
	build.call("set_persist_for_debug", false)
	await create_timer(1.2).timeout

	var res: Array = vis.get("_residents")
	print("\n=== residenti: %d ===" % res.size())
	if res.is_empty():
		print("GUASTO: nessun residente"); quit(1); return

	# --- 1) IL MODELLO ARRIVA AL CORPO?
	var lab := str(res[0].get("label", ""))
	var animi: Dictionary = vis.get("_animi")
	var an = animi.get(lab)
	if an == null or an.limbico == null:
		print("GUASTO: nessun animo per %s" % lab); quit(1); return
	var corpo: Node3D = res[0]["node"]
	# si guasta apposta la chimica e si guarda se il RIG cambia
	an.limbico.neuro["cortisolo"] = 0.05
	an.limbico.neuro["serotonina"] = 0.90
	for _f in 20:
		await process_frame
	var and_prima = corpo.get("_andatura")
	var cort_rig_a := float(and_prima.get("cortisolo")) if and_prima else -1.0
	an.limbico.neuro["cortisolo"] = 0.95
	an.limbico.neuro["serotonina"] = 0.10
	for _f2 in 20:
		await process_frame
	var cort_rig_b := float(and_prima.get("cortisolo")) if and_prima else -1.0
	print("\n--- 1) la chimica arriva al corpo ---")
	print("       Andatura.cortisolo: %.3f -> %.3f" % [cort_rig_a, cort_rig_b])
	_dico(cort_rig_b > cort_rig_a + 0.5,
			"il rig dell'andatura segue il cortisolo (se resta uguale, la "
			+ "somatizzazione e' di nuovo codice morto)")
	var faccia = corpo.get("_face")
	if faccia != null:
		print("       FaceController.cortisolo: %.3f" % float(faccia.get("cortisolo")))
		_dico(float(faccia.get("cortisolo")) > 0.5, "e anche la faccia")
	else:
		print("       (questo corpo non ha volto vivo: salto)")

	# --- 2) L'UMORE E' ANCORA UNA COSA CHE SI MUOVE?
	print("\n--- 2) l'umore, dopo due minuti di villaggio ---")
	var minuti := float(OS.get_environment("CHIBI_MINUTI")) if OS.get_environment("CHIBI_MINUTI") != "" else 2.0
	await create_timer(minuti * 60.0).timeout
	var saturi := 0
	var estremi := 0
	var somma := 0.0
	var quanti := 0
	for r in res:
		var a2 = animi.get(str(r.get("label", "")))
		if a2 == null or a2.limbico == null:
			continue
		var u := float(a2.limbico.umore)
		quanti += 1
		somma += u
		if absf(u) >= 0.999:
			saturi += 1
		if absf(u) >= 0.90:
			estremi += 1
	print("       %d residenti · umore medio %.4f · saturi (|u|>=0.999): %d · estremi (>=0.90): %d"
			% [quanti, somma / maxf(1.0, float(quanti)), saturi, estremi])
	_dico(saturi == 0, "nessun umore e' saturo: l'umore non e' una rampa "
			+ "alla frequenza del fotogramma")
	_dico(estremi <= quanti / 3, "e la maggioranza non e' nemmeno agli estremi")

	# --- 3) UN LUTTO NON SI CANCELLA IN TRE SECONDI
	print("\n--- 3) un colpo resta addosso ---")
	an.limbico.umore = -0.9
	await create_timer(3.0).timeout
	print("       tre secondi dopo: %.4f" % float(an.limbico.umore))
	_dico(float(an.limbico.umore) < -0.5, "tre secondi dopo un lutto l'umore e' ancora sotto")

	print("\n==== NEURO VIVO: %s ====" % ("TUTTO A POSTO" if _guasti == 0
			else "%d GUASTI" % _guasti))
	quit(1 if _guasti > 0 else 0)
