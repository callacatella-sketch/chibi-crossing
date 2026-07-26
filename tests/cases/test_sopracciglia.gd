extends RefCounted
## Le sopracciglia: non più file di palline ma una ciglia unica — un fuso
## rastremato spazzato lungo l'arco radice→colmo→coda. Il test verifica:
##  • REGRESSIONE PALLINE: ogni stile produce UNA mesh sola (il vecchio
##    sopracciglio era una catena di 4 SphereMesh);
##  • la coda è davvero più sottile della radice (rastremazione);
##  • gli stili si distinguono: le arcuate s'inarcano più delle dritte,
##    le folte sono più spesse delle sottili;
##  • i due lati sono specchiati;
##  • il fuso è orientato come le mesh di Godot (winding concorde a una
##    SphereMesh: un segno invertito = sopracciglio rovesciato/invisibile);
##  • il DNA pesca sempre stili ESISTENTI in FaceController.BROW_STYLES
##    (i mazzi di ChibiDNA non possono divergere), geni nei range e
##    deterministici a parità di seed;
##  • ChibiBuilder monta il rig con le ciglia nuove per ogni stile.

const FACE := "res://scenes/characters/FaceController.gd"
const DNA := "res://scenes/npc/ChibiDNA.gd"
const BUILDER := "res://scenes/npc/ChibiBuilder.gd"

const LEN := 0.1
const THICK := 0.016


func run(t) -> void:
	var fc: GDScript = load(FACE)
	var dna: GDScript = load(DNA)
	var builder: GDScript = load(BUILDER)
	for pair in [["FaceController", fc], ["ChibiDNA", dna], ["ChibiBuilder", builder]]:
		var s: GDScript = pair[1]
		t.ok(s != null and s.can_instantiate(), "%s compila" % pair[0])
		if s == null or not s.can_instantiate():
			return

	var head := t.stage(Node3D.new()) as Node3D
	var mat := StandardMaterial3D.new()

	_test_forma_stili(t, fc, head, mat)
	_test_specchio(t, fc, head, mat)
	_test_winding(t, fc, head, mat)
	_test_geni(t, fc, dna)
	_test_builder(t, fc, dna, builder)


# la MeshInstance3D unica dentro il pivot di un sopracciglio (null se il
# contratto "una ciglia sola" è rotto)
func _ciglia(t, pivot: Node3D, ctx: String) -> MeshInstance3D:
	t.eq(pivot.get_child_count(), 1, "%s: il pivot ha UNA sola ciglia" % ctx)
	if pivot.get_child_count() != 1:
		return null
	var mi := pivot.get_child(0) as MeshInstance3D
	t.ok(mi != null, "%s: la ciglia è una MeshInstance3D" % ctx)
	if mi == null:
		return null
	t.ok(mi.mesh is ArrayMesh, "%s: fuso unico, non palline (ArrayMesh)" % ctx)
	return mi


func _verts(mi: MeshInstance3D) -> PackedVector3Array:
	if mi == null or not (mi.mesh is ArrayMesh):
		return PackedVector3Array()
	return (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


# l'ingombro dei vertici lungo un asse, nella fascia orizzontale [x0..x1]
func _span(vs: PackedVector3Array, x0: float, x1: float, axis: int) -> float:
	var lo := INF
	var hi := -INF
	for v in vs:
		if v.x >= x0 and v.x <= x1:
			lo = minf(lo, v[axis])
			hi = maxf(hi, v[axis])
	return (hi - lo) if hi > lo else 0.0


func _test_forma_stili(t, fc: GDScript, head: Node3D, mat: Material) -> void:
	var max_y := {}
	var span_z := {}
	for stile in fc.BROW_STYLES:
		var pivot: Node3D = fc.build_brow(head, mat, 1.0,
				Vector3.ZERO, LEN, THICK, stile)
		var mi := _ciglia(t, pivot, str(stile))
		var vs := _verts(mi)
		t.ok(vs.size() > 100, "%s: il fuso ha una vera geometria (%d vertici)"
				% [stile, vs.size()])
		if vs.is_empty():
			continue

		# copre la lunghezza chiesta e cresce verso il lato giusto
		var hi_x := -INF
		var lo_x := INF
		var hi_y := -INF
		var lo_z := INF
		var hi_z := -INF
		for v in vs:
			hi_x = maxf(hi_x, v.x)
			lo_x = minf(lo_x, v.x)
			hi_y = maxf(hi_y, v.y)
			lo_z = minf(lo_z, v.z)
			hi_z = maxf(hi_z, v.z)
		t.ok(hi_x > LEN * 0.95 and hi_x < LEN * 1.1 and lo_x > -THICK * 2.0,
				"%s: lunghezza rispettata verso l'esterno (x %f..%f)"
				% [stile, lo_x, hi_x])

		# rastremazione: la coda è più sottile della radice. Si misura in
		# PROFONDITÀ (z): l'ingombro verticale includerebbe la discesa della
		# curva stessa negli stili con la coda ricadente
		var radice := _span(vs, LEN * 0.05, LEN * 0.3, Vector3.AXIS_Z)
		var coda := _span(vs, LEN * 0.85, LEN * 1.1, Vector3.AXIS_Z)
		t.ok(coda < radice * 0.7,
				"%s: coda affilata (%.4f) più sottile della radice (%.4f)"
				% [stile, coda, radice])

		# GENTILEZZA (regressione "gabbiano"): su musetti teneri il colmo non
		# deve svettare né la coda precipitare — l'aria arrabbiata nasce lì
		t.ok(hi_y < LEN * 0.45,
				"%s: il colmo resta dolce (%.4f)" % [stile, hi_y])
		var coda_min := INF
		for v in vs:
			if v.x >= LEN * 0.85:
				coda_min = minf(coda_min, v.y)
		t.ok(coda_min > -LEN * 0.35,
				"%s: la coda non precipita (%.4f)" % [stile, coda_min])

		max_y[stile] = hi_y
		span_z[stile] = hi_z - lo_z

	# gli stili si distinguono davvero l'uno dall'altro
	if max_y.has("arcuate") and max_y.has("dritte"):
		t.ok(float(max_y["arcuate"]) > float(max_y["dritte"]) + 0.01,
				"le arcuate s'inarcano più delle dritte (%.4f vs %.4f)"
				% [max_y["arcuate"], max_y["dritte"]])
	if span_z.has("folte") and span_z.has("sottili"):
		t.ok(float(span_z["folte"]) > float(span_z["sottili"]) * 1.5,
				"le folte sono ben più spesse delle sottili (%.4f vs %.4f)"
				% [span_z["folte"], span_z["sottili"]])


func _test_specchio(t, fc: GDScript, head: Node3D, mat: Material) -> void:
	var dx: Node3D = fc.build_brow(head, mat, 1.0, Vector3.ZERO, LEN, THICK, "morbide")
	var sx: Node3D = fc.build_brow(head, mat, -1.0, Vector3.ZERO, LEN, THICK, "morbide")
	var mdx := _ciglia(t, dx, "specchio dx")
	var msx := _ciglia(t, sx, "specchio sx")
	if mdx == null or msx == null:
		return
	var adx := mdx.mesh.get_aabb()
	var asx := msx.mesh.get_aabb()
	t.almost(adx.end.x, -asx.position.x, "i due lati sono specchiati in x", 0.0005)
	t.almost(adx.size.y, asx.size.y, "i due lati hanno la stessa altezza", 0.0005)
	# il riposo del pivot pende verso l'esterno, simmetrico
	t.almost(dx.rotation.z, -sx.rotation.z, "l'inclinazione a riposo è speculare", 0.0001)


# il volume col segno dice il verso del winding: se non concorda con quello
# di una SphereMesh di Godot, il fuso è rovesciato (facce dentro, invisibile)
func _signed_volume(mesh: Mesh) -> float:
	var arr := mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx = arr[Mesh.ARRAY_INDEX]
	var vol := 0.0
	if idx == null or (idx as PackedInt32Array).is_empty():
		for i in range(0, vs.size() - 2, 3):
			vol += vs[i].dot(vs[i + 1].cross(vs[i + 2]))
	else:
		var ia := idx as PackedInt32Array
		for i in range(0, ia.size() - 2, 3):
			vol += vs[ia[i]].dot(vs[ia[i + 1]].cross(vs[ia[i + 2]]))
	return vol / 6.0


func _test_winding(t, fc: GDScript, head: Node3D, mat: Material) -> void:
	var sph := SphereMesh.new()
	sph.radius = 0.1
	sph.height = 0.2
	var rif := _signed_volume(sph)
	for side: float in [-1.0, 1.0]:
		var pivot: Node3D = fc.build_brow(head, mat, side,
				Vector3.ZERO, LEN, THICK, "morbide")
		var mi := pivot.get_child(0) as MeshInstance3D
		if mi == null:
			continue
		var vol := _signed_volume(mi.mesh)
		t.ok(absf(vol) > 0.0, "lato %+.0f: il fuso è un solido chiuso" % side)
		t.ok(signf(vol) == signf(rif),
				"lato %+.0f: winding concorde alle mesh di Godot" % side)


func _test_geni(t, fc: GDScript, dna: GDScript) -> void:
	# i mazzi coprono tutti gli archetipi e pescano solo stili esistenti
	for arche in dna.ARCHETYPES:
		t.ok(dna.BROW_DECKS.has(arche), "l'archetipo %s ha il suo mazzo" % arche)
		for stile in dna.BROW_DECKS.get(arche, []):
			t.ok(fc.BROW_STYLES.has(stile),
					"%s: lo stile '%s' esiste in BROW_STYLES" % [arche, stile])

	var validi := 0
	for i in 60:
		var g: Dictionary = dna.generate(i * 977 + 13)
		var buoni: bool = fc.BROW_STYLES.has(g.get("brow", "")) \
				and float(g["brow_folto"]) >= 0.82 and float(g["brow_folto"]) <= 1.22 \
				and float(g["brow_arco"]) >= 0.8 and float(g["brow_arco"]) <= 1.25 \
				and float(g["brow_len"]) >= 0.9 and float(g["brow_len"]) <= 1.15
		if buoni:
			validi += 1
	t.eq(validi, 60, "60 genomi su 60 hanno geni sopracciglia validi e nei range")

	# stesso seed → stesse sopracciglia (il residente salvato rinasce uguale)
	var a: Dictionary = dna.generate(4242)
	var b: Dictionary = dna.generate(4242)
	for k in ["brow", "brow_folto", "brow_arco", "brow_len"]:
		t.eq(a[k], b[k], "gene '%s' deterministico a parità di seed" % k)


func _test_builder(t, fc: GDScript, dna: GDScript, builder: GDScript) -> void:
	# un chibi per ogni stile: il rig arriva con due ciglie-fuso, mai palline
	var stili: Array = fc.BROW_STYLES.keys()
	var montati := 0
	for i in stili.size():
		var g: Dictionary = dna.generate(i * 31 + 5)
		g["brow"] = stili[i]
		var parts: Dictionary = builder.build(g)
		t.stage(parts["root"])
		var brows: Array = parts["face"]["brows"]
		if brows.size() != 2:
			t.ok(false, "stile %s: il rig non ha due sopracciglia" % stili[i])
			continue
		var ok_stile := true
		for pivot in brows:
			var mi := _ciglia(t, pivot, "builder/%s" % stili[i])
			if mi == null or _verts(mi).is_empty():
				ok_stile = false
		if ok_stile:
			montati += 1
	t.eq(montati, stili.size(),
			"tutti i %d stili montano sul chibi con la ciglia nuova" % stili.size())
