extends RefCounted
## Le bocche: non più catene di palline ma labbra-fuso continue, piene al
## centro e affilate agli angoli. Il test verifica:
##  • REGRESSIONE PALLINE: nessuna SphereMesh nel set — le forme curve sono
##    UN fuso (la "w" neutra ne ha DUE, uno per archetto), o/O restano tori;
##  • le curvature giuste dai vertici: smile/grin a ∪, frown/sad a ∩,
##    la "w" con gli archetti che affondano nel mezzo;
##  • gli angoli più sottili del centro (labbro vero, non tubo uniforme);
##  • gli stili si distinguono: larga più ampia di minuta, piena più
##    spessa di morbida;
##  • winding concorde alle mesh di Godot (fuso rovesciato = invisibile);
##  • la bocca aperta ha cavità E linguetta, e nasce nascosta;
##  • il DNA pesca stili esistenti in FaceController.MOUTH_STYLES, geni nei
##    range e deterministici; il gene storico "mouth" resta com'era;
##  • ChibiBuilder monta il set nuovo per ogni stile.

const FACE := "res://scenes/characters/FaceController.gd"
const DNA := "res://scenes/npc/ChibiDNA.gd"
const BUILDER := "res://scenes/npc/ChibiBuilder.gd"

# le forme curve costruite come UN labbro-fuso solo
const FUSI_SINGOLI := ["smile", "grin", "frown", "sad", "line"]


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

	_test_niente_palline(t, fc, head, mat)
	_test_curvature(t, fc, head, mat)
	_test_stili(t, fc, head, mat)
	_test_winding(t, fc, head, mat)
	_test_bocca_aperta(t, fc, head, mat)
	_test_geni(t, fc, dna)
	_test_builder(t, fc, dna, builder)
	_test_musetti(t, dna, builder)


func _verts(node: Node3D, child := 0) -> PackedVector3Array:
	if node == null or node.get_child_count() <= child:
		return PackedVector3Array()
	var mi := node.get_child(child) as MeshInstance3D
	if mi == null or not (mi.mesh is ArrayMesh):
		return PackedVector3Array()
	return (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


# tutti i vertici di tutte le mesh figlie, nello spazio del nodo-forma
func _verts_tutti(node: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for c in node.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for v in mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			out.append(mi.position + v)
	return out


func _test_niente_palline(t, fc: GDScript, head: Node3D, mat: Material) -> void:
	var mouths: Dictionary = fc.build_mouth_set(head, mat, Vector3.ZERO)
	t.ok(mouths.size() >= 8, "il set ha almeno 8 forme (%d)" % mouths.size())
	for shape in mouths:
		var node: Node3D = mouths[shape]
		for c in node.get_children():
			var mi := c as MeshInstance3D
			t.ok(mi != null and not (mi.mesh is SphereMesh),
					"%s: niente palline (mesh %s)" % [shape,
					"nulla" if mi == null else mi.mesh.get_class()])
	for shape in FUSI_SINGOLI:
		var node: Node3D = mouths.get(shape)
		t.ok(node != null and node.get_child_count() == 1
				and (node.get_child(0) as MeshInstance3D).mesh is ArrayMesh,
				"%s: UN solo labbro-fuso" % shape)
	var wnode: Node3D = mouths.get("neutral")
	t.ok(wnode != null and wnode.get_child_count() == 2,
			"neutral: la 'w' è fatta di DUE archetti-fuso")
	# solo la neutra è visibile a riposo
	t.ok(wnode.visible, "la bocca neutra parte visibile")
	t.ok(not (mouths["smile"] as Node3D).visible, "le altre partono nascoste")


# la curvatura dai vertici: angoli (|x| alto) meno centro (|x| basso)
func _curvatura(node: Node3D) -> float:
	var vs := _verts_tutti(node)
	var hw := 0.0
	for v in vs:
		hw = maxf(hw, absf(v.x))
	var corner := -INF
	var center := -INF
	for v in vs:
		if absf(v.x) > hw * 0.8:
			corner = maxf(corner, v.y)
		elif absf(v.x) < hw * 0.2:
			center = maxf(center, v.y)
	return corner - center


func _test_curvature(t, fc: GDScript, head: Node3D, mat: Material) -> void:
	var mouths: Dictionary = fc.build_mouth_set(head, mat, Vector3.ZERO)
	t.ok(_curvatura(mouths["smile"]) > 0.0, "smile curva a ∪ (sorriso)")
	t.ok(_curvatura(mouths["grin"]) > 0.0, "grin curva a ∪")
	t.ok(_curvatura(mouths["frown"]) < 0.0, "frown curva a ∩ (broncio)")
	t.ok(_curvatura(mouths["sad"]) < 0.0, "sad curva a ∩")
	# la "w": nel mezzo di ciascun archetto si affonda sotto lo zero
	var wv := _verts_tutti(mouths["neutral"])
	var lo := 0.0
	for v in wv:
		lo = minf(lo, v.y)
	t.ok(lo < -0.012, "la 'w' neutra affonda nel mezzo degli archetti (%.4f)" % lo)

	# labbro vero: agli angoli il fuso è più sottile che al centro
	# (in profondità z, che non deriva con la curva)
	var sv := _verts(mouths["smile"])
	var hw := 0.0
	for v in sv:
		hw = maxf(hw, absf(v.x))
	var span_c := _span_z(sv, -hw * 0.2, hw * 0.2)
	var span_a := _span_z(sv, hw * 0.8, hw * 1.1)
	t.ok(span_a < span_c * 0.75,
			"smile: angoli affilati (%.4f) rispetto al centro (%.4f)" % [span_a, span_c])


func _span_z(vs: PackedVector3Array, x0: float, x1: float) -> float:
	var lo := INF
	var hi := -INF
	for v in vs:
		if v.x >= x0 and v.x <= x1:
			lo = minf(lo, v.z)
			hi = maxf(hi, v.z)
	return (hi - lo) if hi > lo else 0.0


func _larghezza(node: Node3D) -> float:
	var vs := _verts_tutti(node)
	var lo := INF
	var hi := -INF
	for v in vs:
		lo = minf(lo, v.x)
		hi = maxf(hi, v.x)
	return hi - lo


func _test_stili(t, fc: GDScript, head: Node3D, mat: Material) -> void:
	for stile in fc.MOUTH_STYLES:
		var mouths: Dictionary = fc.build_mouth_set(head, mat, Vector3.ZERO, 1.0, stile)
		t.ok(mouths.size() >= 8, "stile %s: set completo" % stile)
	var larga: Dictionary = fc.build_mouth_set(head, mat, Vector3.ZERO, 1.0, "larga")
	var minuta: Dictionary = fc.build_mouth_set(head, mat, Vector3.ZERO, 1.0, "minuta")
	var piena: Dictionary = fc.build_mouth_set(head, mat, Vector3.ZERO, 1.0, "piena")
	var morbida: Dictionary = fc.build_mouth_set(head, mat, Vector3.ZERO, 1.0, "morbida")
	t.ok(_larghezza(larga["smile"]) > _larghezza(minuta["smile"]) * 1.3,
			"lo smile 'larga' è ben più ampio di 'minuta'")
	var sp := _verts(piena["smile"])
	var sm := _verts(morbida["smile"])
	var hw := 0.05
	t.ok(_span_z(sp, -hw * 0.2, hw * 0.2) > _span_z(sm, -hw * 0.2, hw * 0.2) * 1.2,
			"lo smile 'piena' ha il labbro più spesso di 'morbida'")


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
	var mouths: Dictionary = fc.build_mouth_set(head, mat, Vector3.ZERO)
	for shape in FUSI_SINGOLI:
		var mi := (mouths[shape] as Node3D).get_child(0) as MeshInstance3D
		var vol := _signed_volume(mi.mesh)
		t.ok(absf(vol) > 0.0 and signf(vol) == signf(rif),
				"%s: winding concorde alle mesh di Godot" % shape)


func _test_bocca_aperta(t, fc: GDScript, head: Node3D, mat: Material) -> void:
	var node: Node3D = fc.build_mouth_open(head, mat, Vector3.ZERO)
	t.ok(node != null and not node.visible, "la bocca aperta nasce nascosta")
	t.ok(node.get_child_count() >= 2, "la bocca aperta ha cavità E linguetta")
	# la linguetta è rosa e sta sotto il centro della cavità
	var tongue: MeshInstance3D = null
	for c in node.get_children():
		var mi := c as MeshInstance3D
		if mi != null and mi.material_override is StandardMaterial3D \
				and (mi.material_override as StandardMaterial3D).albedo_color.r > 0.6 \
				and mi.position.y < 0.0:
			tongue = mi
	t.ok(tongue != null, "la linguetta rosa è adagiata sul fondo")


func _test_geni(t, fc: GDScript, dna: GDScript) -> void:
	for arche in dna.ARCHETYPES:
		t.ok(dna.MOUTH_DECKS.has(arche), "l'archetipo %s ha il suo mazzo bocche" % arche)
		for stile in dna.MOUTH_DECKS.get(arche, []):
			t.ok(fc.MOUTH_STYLES.has(stile),
					"%s: lo stile bocca '%s' esiste in MOUTH_STYLES" % [arche, stile])

	var validi := 0
	for i in 60:
		var g: Dictionary = dna.generate(i * 977 + 13)
		var buoni: bool = fc.MOUTH_STYLES.has(g.get("bocca", "")) \
				and float(g["bocca_larg"]) >= 0.92 and float(g["bocca_larg"]) <= 1.1 \
				and float(g["bocca_spess"]) >= 0.85 and float(g["bocca_spess"]) <= 1.2 \
				and g.get("mouth", "") in ["w", "smile", "o"]
		if buoni:
			validi += 1
	t.eq(validi, 60, "60 genomi su 60: geni bocca validi e 'mouth' storico intatto")

	var a: Dictionary = dna.generate(4242)
	var b: Dictionary = dna.generate(4242)
	for k in ["bocca", "bocca_larg", "bocca_spess"]:
		t.eq(a[k], b[k], "gene '%s' deterministico a parità di seed" % k)


# dove il naso di ciascun archetipo vive (y in unità di head_scale):
# la bocca deve stargli SOTTO con aria in mezzo, e appoggiata sul musetto
const NASO_Y := {"gatto": -0.052, "coniglio": -0.052, "orsetto": -0.045,
		"topolino": -0.062, "volpina": -0.088}


# REGRESSIONE BOCCA SUL NASO / SEPOLTA: la quota unica -0.105·hs metteva la
# bocca sopra i cuscinetti (gatto/coniglio) o DENTRO il muso sporgente
# (volpina/orsetto/topolino), dove restava invisibile: si leggeva solo il
# punto nero del naso. Ora la quota la decide il musetto, e dove il musetto
# è piatto c'è il filtrino naso→labbro.
func _test_musetti(t, dna: GDScript, builder: GDScript) -> void:
	var visti := {}
	var giro := 0
	while visti.size() < dna.ARCHETYPES.size() and giro < 400:
		var g: Dictionary = dna.generate(giro * 7 + 1)
		giro += 1
		var arche: String = g["archetype"]
		if visti.has(arche):
			continue
		visti[arche] = true
		var hs: float = g["head_scale"]
		var front := -0.34 * hs
		var parts: Dictionary = builder.build(g)
		t.stage(parts["root"])
		var rig: Dictionary = parts["face"]
		var neutro: Node3D = rig["mouths"]["neutral"]
		t.ok(neutro.position.y <= (float(NASO_Y[arche]) - 0.055) * hs,
				"%s: la bocca sta sotto il naso, con aria (y=%.3f)"
				% [arche, neutro.position.y])
		# ADERENZA: la bocca poggia sulla superficie VERA (musetto, valle dei
		# cuscinetti o viso nudo) — prima stava su una quota piana e di
		# profilo restava APPESA a mezz'aria davanti alla testona
		var sup: Array = builder._superficie_bocca(arche, neutro.position.y, hs)
		t.almost(neutro.position.z, float(sup[0]) - 0.006,
				"%s: la bocca è APPOGGIATA sulla superficie vera (z=%.3f, attesa %.3f)"
				% [arche, neutro.position.z, float(sup[0]) - 0.006], 0.012)
		t.ok(neutro.position.z <= front + 0.02,
				"%s: e non è sepolta dentro la testa" % arche)
		if arche == "volpina":
			t.ok(rig.get("philtrum") == null,
					"volpina: niente filtrino (il naso sta in punta al muso)")
		else:
			t.ok(rig.get("philtrum") != null,
					"%s: il filtrino naso→labbro c'è" % arche)

		# REGRESSIONE MACCHIA: niente mesh nel tono "musetto chiaro" (pelo
		# schiarito) sul viso — la macchia attorno alla bocca è stata tolta.
		# Sopravvive solo il muso a goccia della volpina (è struttura).
		var chiaro := Color(str(g["fur"])).lightened(0.07)
		var macchie := 0
		for c in (parts["head"] as Node3D).get_children():
			var mi = c as MeshInstance3D
			if mi == null or not (mi.material_override is ShaderMaterial):
				continue
			var alb = (mi.material_override as ShaderMaterial) \
					.get_shader_parameter("albedo_color")
			if alb is Color and (alb as Color).is_equal_approx(chiaro):
				macchie += 1
		if arche == "volpina":
			t.ok(macchie >= 1, "volpina: il muso a goccia resta")
		else:
			t.eq(macchie, 0,
					"%s: nessuna macchia color pelo vicino alla bocca" % arche)
	t.eq(visti.size(), dna.ARCHETYPES.size(),
			"il musetto di ogni archetipo è stato verificato")


func _test_builder(t, fc: GDScript, dna: GDScript, builder: GDScript) -> void:
	var stili: Array = fc.MOUTH_STYLES.keys()
	var montati := 0
	for i in stili.size():
		var g: Dictionary = dna.generate(i * 53 + 11)
		g["bocca"] = stili[i]
		var parts: Dictionary = builder.build(g)
		t.stage(parts["root"])
		var mouths: Dictionary = parts["face"]["mouths"]
		var ok_stile: bool = mouths.size() >= 8
		for shape in FUSI_SINGOLI:
			var node: Node3D = mouths.get(shape)
			if node == null or node.get_child_count() != 1 \
					or not ((node.get_child(0) as MeshInstance3D).mesh is ArrayMesh):
				ok_stile = false
		if ok_stile:
			montati += 1
		else:
			t.ok(false, "stile bocca %s: il rig non è a labbra-fuso" % stili[i])
	t.eq(montati, stili.size(),
			"tutti i %d stili di bocca montano sul chibi" % stili.size())
