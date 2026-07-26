extends SceneTree
## Fotografia STRUTTURALE del mondo generato da CozyWorld.
##
## Serve come rete di sicurezza per i refactor: si cattura un "prima", si
## rifattorizza, si cattura un "dopo" e si confrontano. Se il censimento è
## identico, la scomposizione non ha cambiato ciò che viene costruito.
##
## Censisce STRUTTURA (quanti nodi, di che tipo, con quante superfici/istanze),
## non le posizioni: la generazione usa rumore/random, quindi le coordinate
## possono variare mentre la struttura resta la stessa.
##
##   Godot --headless --path . --script res://tests/world_snapshot.gd > snap.txt

const TIMEOUT_FRAMES := 600


func _initialize() -> void:
	var level: Node = load("res://scenes/levels/MainLevel.tscn").instantiate()
	root.add_child(level)

	var cozy: Node = level.get_node_or_null("CozyWorld")
	if cozy == null:
		print("ERRORE: CozyWorld non trovato")
		quit(1)
		return

	# aspetta la fine della generazione differita (segnale world_built)
	var built := [false]
	if cozy.has_signal("world_built"):
		cozy.world_built.connect(func(): built[0] = true)
	var frames := 0
	while not built[0] and frames < TIMEOUT_FRAMES:
		await process_frame
		frames += 1
	# qualche frame di assestamento (nodi aggiunti in deferred)
	for i in 5:
		await process_frame

	var lines: Array[String] = []
	_census(cozy, "CozyWorld", lines)
	lines.sort()
	print("# world_snapshot | costruito=%s | frames=%d | voci=%d" % [built[0], frames, lines.size()])
	for l in lines:
		print(l)
	quit(0)


## Riga di censimento per ogni nodo: percorso relativo, classe e dati strutturali.
## I nomi auto-generati da Godot (@Node3D@707) contengono un contatore globale che
## cambia tra un'esecuzione e l'altra: si normalizza a @Node3D@N, altrimenti due
## run identici risulterebbero diversi.
func _census(node: Node, path: String, out: Array[String]) -> void:
	out.append("%s | %s%s" % [path, node.get_class(), _detail(node)])
	for c in node.get_children():
		_census(c, path + "/" + _norm(str(c.name)), out)


func _norm(n: String) -> String:
	var re := RegEx.new()
	re.compile("@([A-Za-z0-9_]+)@[0-9]+")
	return re.sub(n, "@$1@N", true)


func _detail(node: Node) -> String:
	if node is MultiMeshInstance3D:
		var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
		if mm == null:
			return " | multimesh=null"
		return " | instances=%d visible=%d mesh=%s" % [
			mm.instance_count, mm.visible_instance_count,
			("null" if mm.mesh == null else mm.mesh.get_class())]
	if node is MeshInstance3D:
		var m: Mesh = (node as MeshInstance3D).mesh
		if m == null:
			return " | mesh=null"
		var verts := 0
		for s in m.get_surface_count():
			var arr: Array = m.surface_get_arrays(s)
			if arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
				verts += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		return " | mesh=%s surfaces=%d verts=%d" % [m.get_class(), m.get_surface_count(), verts]
	if node is GPUParticles3D:
		return " | amount=%d" % (node as GPUParticles3D).amount
	if node is Light3D:
		return " | light"
	if node is CollisionShape3D:
		var sh: Shape3D = (node as CollisionShape3D).shape
		return " | shape=%s" % ("null" if sh == null else sh.get_class())
	return ""
