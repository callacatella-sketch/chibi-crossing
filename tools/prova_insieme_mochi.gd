extends SceneTree
## LA CHIAVE A FORMA DI GIOCATORE — Mochi si siede, e il posto accanto chiama.
##
## Il fatto dell'insieme e' una proprieta' del mondo: «il posto che
## sceglierei ha, entro un braccio, qualcuno che ci E' SEDUTO ADESSO». Fra i
## corpi seduti c'e' anche **Mochi**, e questo banco misura la sola cosa che
## conta saperne: *il giocatore puo' accenderlo?*
##
## E' la prima domanda della regola del cozy — «ogni ferita ha una chiave a
## forma di giocatore» — e senza una misura resta una promessa. Qui si apre il
## MainLevel VERO, si posa un Gazebo (tre sgabelli fratelli a 0,92-1,01 m), si
## fa sedere Mochi su uno sgabello **con l'interazione vera** (`E`, cioe'
## `Interactions.debug_sit`), e si conta quanti residenti si vedono accendere
## il bit — leggendolo dalla maschera che arriva al C++, non da una domanda
## rifatta qui.
##
##   Godot --headless --path . --script res://tools/prova_insieme_mochi.gd
##
## ⚠️ **NON tocca il salvataggio dell'autore**: `set_persist_for_debug(false)`
## prima di posare qualunque cosa, e l'impronta confrontata prima e dopo.

const VISITORS := preload("res://scenes/npc/Visitors.gd")


func _init() -> void:
	_go()


func _trova(g: String) -> Node:
	for n in get_nodes_in_group(g):
		return n
	return null


func _impronta(p: String) -> String:
	if not FileAccess.file_exists(p):
		return "(assente)"
	var f := FileAccess.open(p, FileAccess.READ)
	var c := HashingContext.new()
	c.start(HashingContext.HASH_SHA256)
	c.update(f.get_buffer(f.get_length()))
	return c.finish().hex_encode()


func _quanti_accesi(vis: Node, bit: int) -> Array:
	var elenco: Array = []
	for r in (vis.get("_residents") as Array):
		if (int((r as Dictionary).get("fatti", 0)) & bit) != 0:
			elenco.append(str((r as Dictionary).get("label", "?")))
	return elenco


func _go() -> void:
	var salv := "user://village.json"
	var prima := _impronta(salv)
	if change_scene_to_file("res://scenes/levels/MainLevel.tscn") != OK:
		push_error("MainLevel non si apre")
		quit(1)
		return
	for _i in 40:
		await process_frame
	var vis := _trova("visitors")
	var build := _trova("build_system")
	var inter := _trova("interactions")
	var dn := _trova("daynight") as Node3D
	if vis == null or build == null or dn == null:
		push_error("manca Visitors, BuildSystem o DayNight")
		quit(1)
		return
	print("Interactions si trova per gruppo: %s" % ("si" if inter != null else "NO"))
	if inter == null:
		push_error("Interactions non e' nel gruppo «interactions»: il fatto non vedra' mai Mochi")
		quit(1)
		return
	build.call("set_persist_for_debug", false)
	# l'ora: pieno giorno, o i vicini vanno a dormire in mezzo alla prova
	dn.call("set_time", 0.5)

	# IL MOBILE A TRE SEDUTE FRATELLE. E' quello che rende possibile una
	# terna, ed e' anche il posto in cui la chiave del giocatore ha senso:
	# ci si siede accanto a qualcuno, non in mezzo a un prato.
	# ⚠️ `place_cell` non torna un booleano: torna NIENTE. Assegnarlo a un
	# `bool` tipizzato e' un errore a runtime — che non fa fallire il banco,
	# lo INTERROMPE, e il processo resta a girare a vuoto per sempre (l'ho
	# pagato: dieci minuti di villaggio acceso e zero righe stampate).
	# Si conta il risultato guardando il MONDO, che e' anche l'unica
	# risposta che vale.
	# …e le celle si provano UNA PER UNA: `place_cell` rifiuta in silenzio
	# dove il villaggio ha gia' qualcosa (e nel letto del fiume), quindi una
	# cella scelta a occhio da' un banco che misura un prato.
	var prima_gaz: int = (build.call("get_placed_by_name", "Gazebo") as Array).size()
	var dopo_gaz := prima_gaz
	for cella in [Vector2i(0, 10), Vector2i(0, 6), Vector2i(-6, 10),
			Vector2i(6, 10), Vector2i(0, 14), Vector2i(-10, 6)]:
		build.call("place_cell", cella, "Gazebo", 0, false)
		build.call("aggiorna_varchi_ora")
		await process_frame
		dopo_gaz = (build.call("get_placed_by_name", "Gazebo") as Array).size()
		if dopo_gaz > prima_gaz:
			print("Gazebo posato in %s (ne c'erano %d, adesso %d)"
					% [str(cella), prima_gaz, dopo_gaz])
			break
	var sgabelli: Array = []
	for g in (build.call("get_placed_by_name", "Gazebo") as Array):
		for p in (g as Node3D).find_children("Posto*", "Node3D", true, false):
			sgabelli.append(p as Node3D)
	print("sgabelli in tutto: %d" % sgabelli.size())
	if sgabelli.size() < 2:
		push_error("servono almeno due sgabelli fratelli")
		quit(1)
		return
	var d_min := 999.0
	for i in sgabelli.size():
		for j in range(i + 1, sgabelli.size()):
			d_min = minf(d_min, (sgabelli[i] as Node3D).global_position.distance_to(
					(sgabelli[j] as Node3D).global_position))
	print("due sgabelli fratelli distano %.2f m (la soglia dell'insieme e' %.2f)"
			% [d_min, VISITORS.VICINI])

	var ecs = vis.get("_ecs")
	var bit: int = int(ecs.maschera_fatti(PackedStringArray([VISITORS.FATTO_INSIEME]))) \
			if ecs != null else 0
	print("il bit del fatto: %d\n" % bit)

	# ---- 1) MOCHI IN PIEDI: quanti si accendono? ----
	# ⚠️ Si aspettano DUE giri di rinfresco dei fatti (FATTI_OGNI = 30
	# fotogrammi, sfalsati per residente): chiedere subito misurerebbe la
	# maschera di prima, cioe' il gradino invece del mondo.
	for _f in VISITORS.FATTI_OGNI * 3:
		await process_frame
	var prima_elenco := _quanti_accesi(vis, bit)
	print("1 · Mochi IN PIEDI  → residenti col fatto acceso: %d  %s"
			% [prima_elenco.size(), str(prima_elenco)])

	# ---- 2) MOCHI SI SIEDE, con l'interazione vera ----
	inter.call("debug_sit", "Posto")
	await process_frame
	var sedile = vis.call("sedile_di_mochi")
	print("\n2 · Mochi si siede: `sedile_attuale()` risponde %s"
			% ("«%s»" % str((sedile as Node3D).name) if sedile != null else "NIENTE ⚠️"))
	if sedile == null:
		push_error("Mochi non risulta seduta: il fatto non potra' mai vederla")
	for _f2 in VISITORS.FATTI_OGNI * 3:
		await process_frame
	var dopo_elenco := _quanti_accesi(vis, bit)
	print("   → residenti col fatto acceso: %d  %s" % [dopo_elenco.size(), str(dopo_elenco)])

	# ---- 3) E NESSUNO LE SI SIEDE ADDOSSO ----
	# `_free_bench` cicla solo `_residents`: senza sapere di Mochi, il posto
	# su cui e' seduta risulterebbe libero.
	var addosso := 0
	for r2 in (vis.get("_residents") as Array):
		var scelta = vis.call("_free_bench",
				(sedile as Node3D).global_position if sedile != null else Vector3.ZERO)
		if scelta != null and scelta == sedile:
			addosso += 1
	print("\n3 · vicini a cui `_free_bench` darebbe il posto DI MOCHI: %d (dev'essere 0)"
			% addosso)

	# ---- 4) E QUANDO SI ALZA, si spegne ----
	inter.call("_stand_up")
	for _f3 in VISITORS.FATTI_OGNI * 3:
		await process_frame
	var fine_elenco := _quanti_accesi(vis, bit)
	print("\n4 · Mochi si alza → residenti col fatto acceso: %d  %s"
			% [fine_elenco.size(), str(fine_elenco)])

	print("\n============================================")
	print("LA CHIAVE FUNZIONA: %s" % [
			"SI — sedendosi, il giocatore accende il fatto a %d vicini"
					% (dopo_elenco.size() - prima_elenco.size())
			if dopo_elenco.size() > prima_elenco.size()
			else "NO — nessun vicino ha il Gazebo fra i posti che sceglierebbe"])
	print("il salvataggio dell'autore: %s"
			% ["INTATTO" if prima == _impronta(salv) else "⚠️ TOCCATO ⚠️"])
	quit()
