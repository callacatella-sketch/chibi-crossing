extends SceneTree
## I 380 FIORI SELVATICI DEL C++ SI ACCUCCIANO, nel MainLevel VERO.
##
##   Godot --headless --audio-driver Dummy --path . \
##       --script res://tools/prova_accuccia_cpp.gd
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ ESISTE, e perché NON basta la guardia headless
## ────────────────────────────────────────────────────────────────────────
##
## `tests/cases/test_fiori_cpp_accuccia.gd` prova la REGOLA: chiama
## `accuccia_cella` a mano e guarda la trasformata. Resta verde anche se in
## partita non la chiama nessuno — che è esattamente il difetto con cui questa
## meccanica è nata, e che la prima stesura del cablaggio ha ripreso in pieno:
## `CozyWorld._eco_manager()` alzava una bandiera «già cercato» alla PRIMA
## chiamata, e l'`Ecosystem` nasce in fondo alla generazione differita, cioè
## DOPO le prime `flatten_cell` del caricamento. Trovava `null` e se lo teneva
## **per sempre**. MISURATO, posando un pavimento su quaranta celle con dentro
## un fiore: *«IL CABLAGGIO NON C'E'»*, zero fiori accucciati.
##
## Qui si apre il mondo vero, si posa un pavimento con il BuildSystem vero, e
## si guarda cosa succede al fiore.
##
## ⚠️ **E GIRA HEADLESS perché NON rilegge il MultiMesh.**
## `MultiMesh.get_instance_transform()` torna l'IDENTITÀ senza schermo: un
## banco che leggesse di lì misurerebbe la propria cecità (è la trappola già
## scritta per `prova_accuccia.gd`, che infatti si rifiuta di girare headless).
## `debug_trasf_fiore` chiama `trasf_fiore`, cioè **la stessa funzione che
## scrive nel MultiMesh** — un secondo chiamante, non una copia.

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
	for _i in 12:
		await process_frame
	var liv := current_scene
	if liv == null:
		print("GUASTO: il MainLevel non si è caricato")
		quit(1)
		return
	var build := liv.get_node_or_null("BuildSystem")
	if build == null:
		print("GUASTO: nessun BuildSystem")
		quit(1)
		return
	# ⚠️ il salvataggio dell'autore non si tocca
	build.call("set_persist_for_debug", false)
	await create_timer(2.0).timeout

	var eco: Node = liv.get_tree().get_first_node_in_group("ecosystem")
	if eco == null:
		print("GUASTO: nessun nodo nel gruppo «ecosystem»")
		quit(1)
		return
	var mgr = eco.get("eco")
	if mgr == null or not (mgr as Object).has_method("debug_trasf_fiore"):
		print("GUASTO: il cuore C++ non espone «debug_trasf_fiore»"
				+ " (GDExtension vecchia?)")
		quit(1)
		return

	var n: int = int(mgr.debug_quanti_fiori())
	print("\n=== %d fiori selvatici nel prato ===" % n)
	_dico(n > 0, "il prato ne ha seminati")
	if n == 0:
		quit(1)
		return

	# si posa un pavimento sulla cella di un fiore, e si guarda il fiore
	var trovato := false
	for i in mini(n, 60):
		var d: Dictionary = mgr.debug_trasf_fiore(i)
		var p: Vector3 = d["pos"]
		var c := Vector2i(roundi(p.x), roundi(p.z))
		var prima := float(d["alto"])
		if prima < 0.2 or bool(d["accucciato"]):
			continue                       # già sotto qualcosa, o appena nato
		build.call("place_cell", c, "Pavimento", 0, false)
		await process_frame
		var d2: Dictionary = mgr.debug_trasf_fiore(i)
		if not bool(d2["accucciato"]):
			continue                       # quella cella il mondo l'ha rifiutata
		trovato = true
		print("       cella %s · fiore %d" % [c, i])
		_dico(float(d2["alto"]) < prima * 0.1,
				"il fiore si è schiacciato sotto il pavimento (%.4f → %.4f)"
						% [prima, float(d2["alto"])])
		# e uno di un'ALTRA cella non si è mosso
		var altro := -1
		for j in mini(n, 60):
			var dj: Dictionary = mgr.debug_trasf_fiore(j)
			var pj: Vector3 = dj["pos"]
			if Vector2i(roundi(pj.x), roundi(pj.z)) != c and float(dj["alto"]) > 0.2:
				altro = j
				break
		_dico(altro >= 0,
				"…e c'è ancora un fiore in piedi da un'altra parte (il %d)" % altro)
		break

	_dico(trovato, "il cablaggio CozyWorld → EcosystemManager esiste in partita")
	print("\n==== FIORI DEL C++: %s ====" % ("TUTTO A POSTO" if _guasti == 0
			else "%d GUASTI" % _guasti))
	quit(1 if _guasti > 0 else 0)
