extends RefCounted
## I FIORI E LE FARFALLE: le guardie di forma, di costo e di cablaggio.
##
## Non sono source-check. Si costruiscono le mesh VERE, si campionano le
## leggi VERE, e si guarda la geometria — perché il difetto da cui questo
## lavoro nasce (una margherita fatta di tredici sfere scalate, larga
## quanto alta) sarebbe passato indenne da qualunque test che si
## accontenti di contare i triangoli.
##
## ⚠️ E CIÒ CHE QUI NON SI PUÒ PROVARE È SCRITTO IN FONDO: la resa si
## guarda, con `tools/provino_fiori.gd`, `tools/provino_farfalle.gd` e
## `tools/prova_prato_vivo.gd`. Una suite verde non dice niente su un
## petalo.

const CW = preload("res://scenes/world/CozyWorld.gd")
const GEO = preload("res://scenes/world/WorldGeo.gd")
const FIO = preload("res://scenes/world/FioriGeo.gd")
const FARF = preload("res://scenes/world/FarfalleGeo.gd")
## il corso del fiume: si chiede a chi lo definisce, non si ricopia
const MATH = preload("res://scenes/world/WorldMath.gd")


func run(t) -> void:
	_una_superficie_per_fiore(t)
	_il_budget_e_unasserzione(t)
	_la_proporzione_del_capolino(t)
	_le_leggi_del_petalo(t)
	_il_petalo_ha_due_facce(t)
	_le_normali_non_sono_quelle_di_una_sfera(t)
	_la_conca_si_misura_sulla_larghezza(t)
	_lo_stelo_e_una_curva_sola(t)
	_nessun_campo_accende_use_colors(t)
	_la_semina_non_invade(t)
	_lhabitat_sposta_la_densita(t)
	_la_farfalla_ha_quattro_ali_e_un_corpo(t)
	_il_battito_e_asimmetrico(t)
	_il_torace_e_in_frazione_dellapertura(t)


# --------------------------------------------------------- gli attrezzi

func _tris(m: Mesh) -> int:
	var n := 0
	for si in m.get_surface_count():
		var arr := m.surface_get_arrays(si)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] \
				if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var vtx: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		n += (idx.size() / 3) if idx.size() > 0 else (vtx.size() / 3)
	return n


func _fiori() -> Array:
	var g = GEO.new()
	var out := [
		["margherita", g.daisy_mesh(Color("fffaf4"), Color("ffcf5e")), 620],
		["tulipano", g.tulip_mesh(Color("ffb35c")), 420],
		["lavanda", g.lavender_mesh(), 620],
		["trifoglio", g.clover_mesh(Color("fdf6ec")), 140],
		["papavero", g.poppy_mesh(Color("e8574f")), 380],
		["nontiscordar", g.forgetmenot_mesh(), 460],
	]
	return out


# ------------------------------------------------------------ le guardie

## UNA SUPERFICIE PER FIORE. Non è pignoleria di draw call: gli organi si
## distinguono dalla MASCHERA nel COLOR dei vertici, e una mesh spezzata
## in tre superfici vuol dire che qualcuno è tornato a un materiale per
## organo — cioè che la maschera non serve più a niente e il fremito per
## petalo (che legge `COLOR.a`) è morto.
func _una_superficie_per_fiore(t) -> void:
	for f: Array in _fiori():
		t.eq((f[1] as Mesh).get_surface_count(), 1,
				"%s è UNA superficie sola" % f[0])
	t.eq(FARF.piatta(0.105, 0.076).get_surface_count(), 1,
			"la farfalla piatta è una superficie sola (o `_butterfly_mat` "
			+ "non cattura più il materiale e il ritinto stagionale muore)")


## IL BUDGET È UN'ASSERZIONE, non una promessa. E il tetto è generoso di
## poco: se qualcuno raddoppia i passi di una griglia «per sicurezza»,
## qui diventa rosso invece di costare quattrocentomila triangoli in un
## prato che nessuno ha più misurato.
func _il_budget_e_unasserzione(t) -> void:
	for f: Array in _fiori():
		var n := _tris(f[1] as Mesh)
		t.ok(n <= int(f[2]),
				"%s sta nel suo tetto: %d triangoli (max %d)" % [f[0], n, f[2]])
		t.ok(n >= 60, "%s non è vuoto (%d triangoli)" % [f[0], n])
	var b := _tris(FARF.piatta(0.105, 0.076))
	t.ok(b <= 300 and b >= 120,
			"la farfalla piatta sta fra 120 e 300 triangoli (%d)" % b)


## ⚠️ LA PROPORZIONE, che è metà del difetto di partenza. La margherita
## aveva la corolla di ø 0.229 su uno stelo di 0.20: LARGA QUANTO ALTA,
## in un prato dove il filo d'erba fa 0.30. Era quella — prima degli otto
## meridiani della sfera — a farla leggere come una girandola di
## confetti. Il numero contro cui si giudica non è suo: è l'altezza del
## filo d'erba, `blade_mesh`.
func _la_proporzione_del_capolino(t) -> void:
	var g = GEO.new()
	var erba: float = (g.blade_mesh() as Mesh).get_aabb().size.y
	t.almost(erba, 0.30, "il filo d'erba fa trenta centimetri", 0.02)
	var m: Mesh = g.daisy_mesh(Color("fffaf4"), Color("ffcf5e"))
	var a := m.get_aabb()
	t.ok(a.size.y < erba,
			"la margherita sta SOTTO la linea dell'erba (%.3f < %.3f)"
			% [a.size.y, erba])
	t.ok(a.size.y / a.size.x > 2.0,
			"…ed è alta più del doppio di quanto è larga (%.2f)"
			% (a.size.y / a.size.x))
	# il trifoglio è l'altra CLASSE di sagoma: sta sotto tutti
	var tf: Mesh = g.clover_mesh(Color("fdf6ec"))
	t.ok(tf.get_aabb().size.y < a.size.y * 0.55,
			"il trifoglio è il tappeto: meno di metà della margherita (%.3f)"
			% tf.get_aabb().size.y)
	# e il papavero è l'ALTO
	var pa: Mesh = g.poppy_mesh(Color("e8574f"))
	t.ok(pa.get_aabb().size.y > a.size.y * 1.3,
			"il papavero rompe la sagoma verso l'alto (%.3f)"
			% pa.get_aabb().size.y)


## LE TRE LEGGI DEL PETALO, misurate sulla griglia vera. Ognuna è la
## differenza fra un petalo e un nastro, ed è già scritta in casa
## (`_fio_corolla`, `_bis_petalo`): qui si pretende che valgano ancora.
func _le_leggi_del_petalo(t) -> void:
	var nu := 6
	var nv := 4
	var g: Array = FIO.petalo_griglia(0.030, 0.0072, nu, nv,
			{"incisione": 0.19, "arco": 0.26, "caduta": 0.20, "conca": 0.62,
			"torsione": 0.0})
	# 1. LA PUNTA È INCISA: sull'ultima riga la mezzeria rientra rispetto
	#    ai due lobi. Senza, cinque punte a mandorla fanno una stella.
	var punta_mezzo: Vector3 = g[nu][nv / 2]
	var punta_lobo: Vector3 = g[nu][0]
	t.ok(punta_mezzo.x < punta_lobo.x - 0.0008,
			"la punta è INCISA: la mezzeria rientra di %.4f m"
			% (punta_lobo.x - punta_mezzo.x))
	# 2. OBOVATO: la mezza larghezza è massima OLTRE la metà, e più
	#    piccola all'attacco e in punta. Con un plateau esce un nastro.
	var largh := func(iu: int) -> float:
		return absf((g[iu][nv] as Vector3).z - (g[iu][0] as Vector3).z) * 0.5
	var w0: float = largh.call(0)
	var wmax := 0.0
	var iu_max := 0
	for iu in nu + 1:
		var w: float = largh.call(iu)
		if w > wmax:
			wmax = w
			iu_max = iu
	t.ok(float(iu_max) / float(nu) > 0.42,
			"il massimo della larghezza cade oltre il 42%% (a %.2f)"
			% (float(iu_max) / float(nu)))
	t.ok(w0 < wmax * 0.72,
			"…e l'attacco è ben più stretto del massimo (%.4f < %.4f)"
			% [w0, wmax * 0.72])
	t.ok(largh.call(nu) < wmax * 0.80,
			"…e la punta si stringe (%.4f < %.4f)"
			% [largh.call(nu), wmax * 0.80])
	# 3. LA PUNTA CADE: la spina sale e poi ricade sotto l'attacco.
	var y_max := -9.0
	for iu in nu + 1:
		y_max = maxf(y_max, (g[iu][nv / 2] as Vector3).y)
	t.ok(y_max > 0.0005, "il petalo si INARCA (colmo a %.4f m)" % y_max)
	t.ok((g[nu][nv / 2] as Vector3).y < 0.0,
			"…e la punta CADE sotto l'attacco (%.4f m)"
			% (g[nu][nv / 2] as Vector3).y)


## IL PETALO HA DUE FACCE: dorso e ventre, con normali OPPOSTE. È ciò
## che rende visibile il `translucency` che questi materiali hanno da
## sempre e che non si è mai visto — un ellissoide non ha un bordo.
func _il_petalo_ha_due_facce(t) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	FIO.petalo_su(st, Transform3D.IDENTITY, 0.030, 0.0072, 3, 2)
	var m: ArrayMesh = st.commit()
	var arr := m.surface_get_arrays(0)
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var su := 0
	var giu := 0
	for n in nrm:
		if n.y > 0.3:
			su += 1
		elif n.y < -0.3:
			giu += 1
	t.ok(su > 0 and giu > 0,
			"il petalo ha un dorso e un ventre (%d normali su, %d giù)"
			% [su, giu])
	t.ok(absf(float(su - giu)) < float(su + giu) * 0.35,
			"…e le due facce sono equilibrate (%d contro %d)" % [su, giu])
	# e il COLOR porta la MASCHERA: petalo, non cuore né verde
	var col: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	t.ok(col.size() > 0, "il petalo porta la maschera d'organo nel COLOR")
	t.almost(col[0].r, 1.0, "…e la maschera dice PETALO", 0.001)
	t.almost(col[0].b, 0.0, "…e non verde", 0.001)


## LE NORMALI NON SONO QUELLE DI UNA SFERA. È il difetto letterale di
## partenza: tredici `sphere_mesh` scalate 0.62 × 0.22 × 1.75, che
## portano le normali di una BIGLIA. Su un petalo vero le normali dei
## due lembi guardano quasi tutte in su o in giù — è una lamina, non un
## solido.
func _le_normali_non_sono_quelle_di_una_sfera(t) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	FIO.petalo_su(st, Transform3D.IDENTITY, 0.030, 0.0072, 4, 3)
	var arr := (st.commit() as ArrayMesh).surface_get_arrays(0)
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var laterali := 0
	for n in nrm:
		if absf(n.y) < 0.30:
			laterali += 1
	t.ok(float(laterali) / float(nrm.size()) < 0.12,
			"meno del 12%% delle normali guarda di lato: è una lamina, "
			+ "non un ellissoide (%.1f%%)"
			% (100.0 * float(laterali) / float(nrm.size())))


## ⚠️ LA CONCA SI MISURA SULLA MEZZA LARGHEZZA, non sulla lunghezza. È
## una curvatura TRASVERSALE: legata alla lunghezza esplode sui petali
## lunghi e stretti — su un petalo di tulipano lungo 62 mm faceva 16 mm
## di incurvatura per lato, i bordi attraversavano il fiore e uscivano
## dall'altra parte, e in cima usciva una corona sfrangiata.
##
## Il numero contro cui si giudica NON è la conca: è la larghezza.
func _la_conca_si_misura_sulla_larghezza(t) -> void:
	var lung := 0.062
	var largo := 0.0125
	var g: Array = FIO.petalo_griglia(lung, largo, 4, 2,
			{"conca": 0.55, "torsione": 0.0, "arco": 0.0, "caduta": 0.0,
			"incisione": 0.0})
	# lo scostamento del bordo rispetto alla mezzeria, all'estremità
	var mezzo: Vector3 = g[4][1]
	var bordo: Vector3 = g[4][0]
	var alzata := absf(bordo.y - mezzo.y)
	t.ok(alzata < largo * 1.2,
			"la conca sta dentro l'ordine di grandezza della LARGHEZZA "
			+ "(%.4f m su %.4f di mezza larghezza)" % [alzata, largo])
	t.ok(alzata < lung * 0.25,
			"…e non della lunghezza: con la legge sbagliata faceva %.4f m"
			% (0.55 * lung))
	t.ok(alzata > largo * 0.15, "…ma la conca c'è (%.4f m)" % alzata)


## LO STELO È UNA CURVA SOLA. Erano due cilindri accostati con 0.12 rad
## di piega: a ottanta centimetri lo spigolo del gomito si vedeva. Qui si
## chiede che la spina non abbia GOMITI — che l'angolo fra due tratti
## consecutivi resti piccolo.
func _lo_stelo_e_una_curva_sola(t) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var punti: Array = [Vector3.ZERO, Vector3(0.002, 0.09, -0.003),
			Vector3(0.012, 0.20, -0.011)]
	var peggio := 0.0
	var prima := Vector3.ZERO
	var precedente := Vector3.ZERO
	for k in 13:
		var p: Vector3 = FIO._catmull(punti, float(k) / 12.0)
		if k >= 1:
			var d := (p - precedente).normalized()
			if k >= 2:
				peggio = maxf(peggio, prima.angle_to(d))
			prima = d
		precedente = p
	t.ok(peggio < 0.09,
			"lo stelo non ha gomiti: il salto peggiore fra due tratti è "
			+ "%.3f rad (i due cilindri di prima ne facevano 0.12)" % peggio)
	FIO.stelo_su(st, Transform3D.IDENTITY, punti, [0.0034, 0.0026, 0.0021], 5, 5)
	var m: ArrayMesh = st.commit()
	t.ok(_tris(m) > 20 and _tris(m) < 120,
			"…e costa poco (%d triangoli)" % _tris(m))


## ⚠️ NESSUN CAMPO DI FIORI ACCENDE `use_colors`, e non è pignoleria:
## Godot MOLTIPLICA il colore d'istanza dentro il `COLOR` dei vertici, e
## per un fiore quel COLOR è la MASCHERA D'ORGANO. Accenderlo dipinge i
## petali del colore del gambo, senza un errore.
##
## Si interroga la funzione VERA del mondo (`_scatter_exact`), su
## un'istanza di CozyWorld non aggiunta all'albero: `_ready` non parte.
func _nessun_campo_accende_use_colors(t) -> void:
	var w = CW.new()
	var tf: Array[Transform3D] = [Transform3D.IDENTITY,
			Transform3D(Basis.IDENTITY, Vector3(1, 0, 0))]
	var cu: Array[Color] = [Color(0.3, 0.1, 0, 0), Color(0.8, 0.6, 0, 0)]
	var mmi = w.call("_scatter_exact", GEO.new().clover_mesh(Color("fdf6ec")),
			tf, false, cu)
	t.ok(mmi != null, "il campo si semina")
	var mm: MultiMesh = mmi.multimesh
	t.eq(mm.use_colors, false,
			"`use_colors` è SPENTO: accenderlo corromperebbe la maschera "
			+ "d'organo dei vertici")
	t.eq(mm.use_custom_data, true,
			"…e i canali per istanza viaggiano in `custom_data`")
	t.eq(mm.instance_count, 2, "…con tutte le istanze")
	# e senza canali per istanza non si accende niente
	var mmi2 = w.call("_scatter_exact", GEO.new().clover_mesh(Color("fdf6ec")),
			tf, false)
	t.eq((mmi2.multimesh as MultiMesh).use_custom_data, false,
			"chi non passa canali non paga il buffer")
	w.free()


## LA SEMINA NON INVADE: stagno, letto del fiume, sentieri. Con la
## CONTROPROVA nello stesso caso — senza il sentiero, lì i fiori ci
## sono. Un test che non sa fallire non dice niente.
func _la_semina_non_invade(t) -> void:
	var w = CW.new()
	var p := Vector3(8.0, 0.0, 8.0)
	t.ok(w.call("suolo_libero", p, 0.0),
			"CONTROPROVA: senza sentiero, lì si semina")
	w.set("_path_samples", [p])
	t.ok(not w.call("suolo_libero", p, 0.0),
			"col sentiero lì sotto, no")
	t.ok(w.call("suolo_libero", p + Vector3(3, 0, 0), 0.0),
			"…ma tre metri più in là sì")
	w.set("_path_samples", [])
	# lo stagno e il fiume: si chiedono dove sono, non si ricopiano
	var stagno: Vector3 = w.get("POND_CENTER")
	t.ok(not w.call("suolo_libero", stagno, 0.0), "mai dentro lo stagno")
	var fiume := Vector3(0.0, 0.0, 4.0)
	fiume.x = MATH.river_x(fiume.z)
	t.ok(not w.call("suolo_libero", fiume, 0.0), "mai nel letto del fiume")
	w.free()


## L'HABITAT SPOSTA LA DENSITÀ, e in tutte e due le direzioni: una
## specie che cerca l'acqua deve pesare di più vicino, una che la
## scappa di meno. A zero il peso vale UNO ovunque — cioè le specie
## indifferenti non cambiano di un bit.
func _lhabitat_sposta_la_densita(t) -> void:
	var w = CW.new()
	var stagno: Vector3 = w.get("POND_CENTER")
	var vicino: Vector3 = stagno + Vector3(float(w.get("POND_R")) + 1.0, 0, 0)
	var lontano := Vector3(-18.0, 0.0, 14.0)
	t.ok(float(w.call("peso_habitat", vicino, 1.0, 0.0))
			> float(w.call("peso_habitat", lontano, 1.0, 0.0)),
			"chi cerca l'acqua pesa di più vicino all'acqua")
	t.ok(float(w.call("peso_habitat", vicino, -1.0, 0.0))
			< float(w.call("peso_habitat", lontano, -1.0, 0.0)),
			"…e chi la scappa, di meno")
	for p: Vector3 in [vicino, lontano, Vector3(3, 0, -12)]:
		t.almost(float(w.call("peso_habitat", p, 0.0, 0.0)), 1.0,
				"a zero il peso vale uno ovunque", 0.0001)
	t.ok(float(w.call("peso_habitat", Vector3(0, 0, -15), 0.0, 1.0))
			> float(w.call("peso_habitat", Vector3(0, 0, 15), 0.0, 1.0)),
			"e chi va verso il bosco pesa di più verso il bosco")
	w.free()


## LA FARFALLA HA QUATTRO ALI E UN CORPO, e il COLOR è il CONTRATTO col
## vertex shader: `a` dice ala/corpo, `g` dice anteriore/posteriore.
## Prima il corpo era «tutto ciò che sta entro |x| < 0.0714», una banda
## DIPINTA — e un torace modellato verrebbe piegato come un'ala.
func _la_farfalla_ha_quattro_ali_e_un_corpo(t) -> void:
	var m: ArrayMesh = FARF.piatta(0.105, 0.076)
	var arr := m.surface_get_arrays(0)
	var col: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var vtx: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ali := 0
	var corpo := 0
	var post := 0
	for c in col:
		if c.a > 0.5:
			ali += 1
			if c.g > 0.5:
				post += 1
		else:
			corpo += 1
	t.ok(ali > 0 and corpo > 0, "ci sono ali (%d) e corpo (%d)" % [ali, corpo])
	t.ok(post > 0 and post < ali,
			"…e fra le ali ce ne sono di posteriori (%d su %d): sono "
			+ "QUATTRO ali, ed è l'intaglio a far leggere «farfalla»"
			% [post, ali])
	# il corpo sta TUTTO dentro il raggio del torace, o il battito lo
	# piegherebbe come un'ala
	var rt: float = FARF.raggio_torace(0.105)
	# (le ANTENNE hanno `b = 1` e sono l'eccezione: escono dal torace ma
	# non sono ala, e il vertex shader le tiene fuori dalla cerniera)
	var fuori := 0
	var antenne := 0
	for i in vtx.size():
		if col[i].a > 0.5:
			continue
		if col[i].b > 0.5:
			antenne += 1
			continue
		if absf(vtx[i].x) > rt + 0.0001:
			fuori += 1
	t.eq(fuori, 0,
			"il corpo sta tutto entro il raggio del torace (%.4f m)" % rt)
	t.ok(antenne > 0, "…e le antenne hanno un canale loro (%d vertici)" % antenne)
	# e le ali cominciano DENTRO il torace ma arrivano fuori
	var span := 0.0
	for i in vtx.size():
		if col[i].a > 0.5:
			span = maxf(span, absf(vtx[i].x))
	t.almost(span * 2.0, 0.105, "l'apertura è quella chiesta", 0.004)
	# le normali NON sono tutte UP: era il difetto letterale delle 90
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var non_su := 0
	for n in nrm:
		if n.y < 0.98:
			non_su += 1
	t.ok(non_su > nrm.size() / 4,
			"le normali non sono tutte verso l'alto (%d su %d)"
			% [non_su, nrm.size()])


## ⚠️ IL BATTITO È ASIMMETRICO, con la CONTROPROVA nello stesso caso: un
## `sin()` puro dà mezzo ciclo per parte e nessuna pausa in cima — è il
## carillon che «si smaschera in due cicli», ed era quello che c'era in
## tutti e due i posti (GDScript e vertex shader).
func _il_battito_e_asimmetrico(t) -> void:
	var passi := 4000
	# 1. IL TEMPO SI DEFORMA, e si misura DOVE CADE IL COLMO nel mezzo
	#    ciclo. ⚠️ NON in «quanto tempo si sta sopra lo zero»: la legge è
	#    dispari, quindi ci sta esattamente metà del tempo — e la prima
	#    stesura di questa guardia misurava proprio quello, cioè non
	#    misurava niente. MISURATO: il colmo cade al 39.5%% del mezzo
	#    ciclo (la discesa dura una volta e mezzo la salita), contro il
	#    50.0%% esatto del seno puro.
	var colmo := func(f: Callable) -> float:
		var best := -9.0
		var dove := 0.0
		for k in passi:
			var th := PI * float(k) / float(passi)
			var v: float = f.call(th)
			if v > best:
				best = v
				dove = th
		return dove / PI
	var c_vero: float = colmo.call(func(x: float) -> float: return FARF.battito(x))
	var c_seno: float = colmo.call(func(x: float) -> float: return sin(x))
	t.almost(c_seno, 0.50,
			"CONTROPROVA: il colmo del seno puro cade a metà esatta", 0.002)
	t.ok(c_vero < 0.44,
			"la battuta vera NO: il colmo cade al %.1f%% del mezzo ciclo, "
			% (c_vero * 100.0)
			+ "cioè la discesa dura una volta e mezzo la salita")
	# 2. IL COLMO È PIATTO: si sta in cima più a lungo. MISURATO: 47.1%
	#    contro 41.0% del seno, a ogni soglia il rapporto è ~1.15.
	var sopra := func(f: Callable, soglia: float) -> float:
		var n := 0
		for k in passi:
			if absf(f.call(TAU * float(k) / float(passi))) > soglia:
				n += 1
		return float(n) / float(passi)
	for soglia: float in [0.70, 0.80, 0.90]:
		var a: float = sopra.call(func(x: float) -> float: return FARF.battito(x), soglia)
		var b: float = sopra.call(func(x: float) -> float: return sin(x), soglia)
		t.ok(a > b * 1.10,
				"sopra %.2f la battuta ci sta il %.1f%% del tempo contro il "
				% [soglia, a * 100.0] + "%.1f%% del seno" % (b * 100.0))
	# 3. …e schizza via dal fondo: ci si passa MENO tempo che col seno
	var basso_vero: float = sopra.call(
			func(x: float) -> float: return FARF.battito(x), 0.20)
	var basso_seno: float = sopra.call(func(x: float) -> float: return sin(x), 0.20)
	t.ok(basso_vero > basso_seno,
			"e il fondo si attraversa in fretta (fuori dalla fascia bassa "
			+ "il %.1f%% contro il %.1f%%)"
			% [basso_vero * 100.0, basso_seno * 100.0])
	# e resta limitata a ±1 toccandolo, e passa per lo zero
	var picco := 0.0
	for k in passi:
		picco = maxf(picco, absf(FARF.battito(TAU * float(k) / float(passi))))
	t.ok(picco <= 1.0001 and picco > 0.99,
			"la battuta sta dentro ±1 toccandolo (%.4f)" % picco)
	t.almost(FARF.battito(0.0), 0.0, "…e passa per lo zero", 0.0001)


## ⚠️ IL TORACE È UNA FRAZIONE DELL'APERTURA, non un numero in metri.
## Finché tutte le farfalle avevano la stessa taglia non si vedeva; su
## una piccola quel raggio era un quarto della semiapertura — un torace
## largo come mezz'ala.
func _il_torace_e_in_frazione_dellapertura(t) -> void:
	var piccola: float = FARF.raggio_torace(0.105)
	var grande: float = FARF.raggio_torace(0.210)
	t.almost(grande, piccola * 2.0,
			"il torace raddoppia con l'apertura", 0.00001)
	t.ok(piccola < 0.105 * 0.5 * 0.25,
			"…e resta sotto un quarto della semiapertura (%.4f)" % piccola)
	# il corpo scala con la sua lunghezza, non con dei metri assoluti
	var a: AABB = FARF.corpo(0.060).get_aabb()
	var b: AABB = FARF.corpo(0.120).get_aabb()
	t.almost(b.size.x, a.size.x * 2.0,
			"e anche lo spessore del corpo va con la lunghezza", 0.0005)
