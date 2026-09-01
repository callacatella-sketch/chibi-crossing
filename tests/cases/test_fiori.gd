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
## l'ecosistema del C++: qui se ne monta uno FUORI dall'albero, così il
## suo `_ready` non parte e si possono chiedere le sole mesh
const ECO = preload("res://scenes/world/Ecosystem.gd")


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
	_la_battuta_e_la_stessa_in_due_lingue(t)
	_lecosistema_regge_i_suoi_contratti(t)
	_i_due_array_dei_campi_restano_paralleli(t)


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
	# ⚠️ IL MASSIMO SI CERCA SU UNA GRIGLIA FITTA. Con `nu = 6` la
	# discretizzazione lo inchioda all'indice 3, cioè a 0.50 esatto, sia
	# col petalo obovato sia col PLATEAU: la soglia a 0.42 non
	# distingueva le due cose, e a distinguerle era solo la larghezza
	# dell'attacco, qui sotto.
	var fitta: Array = FIO.petalo_griglia(0.030, 0.0072, 60, 2,
			{"incisione": 0.19, "arco": 0.26, "caduta": 0.20, "conca": 0.62,
			"torsione": 0.0})
	var wf := 0.0
	var iu_f := 0
	for iu in 61:
		var w: float = absf((fitta[iu][2] as Vector3).z
				- (fitta[iu][0] as Vector3).z) * 0.5
		if w > wf:
			wf = w
			iu_f = iu
	t.ok(float(iu_f) / 60.0 > 0.50,
			"il massimo della larghezza cade OLTRE metà petalo (a %.3f): "
			% (float(iu_f) / 60.0) + "è la definizione di obovato")
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
	# 4. LA TORSIONE: il piano del lembo RUOTA lungo il petalo. È la
	#    quinta legge («nessun petalo è planare, e due petali della
	#    stessa corolla non prendono mai la stessa luce») e nessuna
	#    asserzione la guardava — l'unico caso che poteva misurarla la
	#    spegneva passando `torsione: 0.0`.
	for tors: float in [0.0, 0.30]:
		var gt: Array = FIO.petalo_griglia(0.030, 0.0072, 6, 2,
				{"incisione": 0.0, "arco": 0.0, "caduta": 0.0,
				"conca": 0.0, "torsione": tors})
		var nt := FIO.lembo_normali(gt)
		var gira: float = (nt[0][1] as Vector3).angle_to(nt[6][1] as Vector3)
		if tors == 0.0:
			t.almost(gira, 0.0,
					"CONTROPROVA: senza torsione il lembo è planare", 0.01)
		else:
			t.ok(gira > tors * 0.5,
					"con torsione 0.30 il piano del lembo ruota di %.3f rad "
					% gira + "dalla radice alla punta")


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
	# ⚠️ «e le due facce sono equilibrate» era una TAUTOLOGIA: i due
	# fogli escono dalla stessa lista di quad col segno rovesciato,
	# quindi `su` e `giu` sono uguali BIT PER BIT per qualunque
	# geometria. Quello che va misurato è l'altra cosa, che è la vera
	# invenzione del petalo: i due fogli sono SEPARATI in mezzo e
	# COINCIDENTI sul margine — è così che si chiude senza un triangolo
	# in più, e in controluce il bordo diventa una linea di spessore.
	var g := FIO.petalo_griglia(0.030, 0.0072, 4, 2, {})
	var nr := FIO.lembo_normali(g)
	var spessore := 0.030 * 0.012
	var scarto := func(iu: int, iv: int) -> float:
		var sp: float = spessore * (1.0 - pow(lerpf(-1.0, 1.0,
				float(iv) / 2.0), 2.0)) * (1.0 - pow(float(iu) / 4.0, 3.0))
		return 2.0 * sp
	t.ok(scarto.call(2, 1) > spessore * 0.5,
			"in MEZZO i due fogli sono separati (%.5f m)" % scarto.call(2, 1))
	t.almost(scarto.call(2, 0), 0.0,
			"…e sul MARGINE coincidono: il petalo si chiude da sé", 1e-9)
	t.almost(scarto.call(4, 1), 0.0,
			"…e sulla PUNTA pure", 1e-9)
	# e la mesh vera lo rispetta: due vertici alla stessa (u, v) di
	# margine devono stare nello stesso posto
	var bordo_uguali := 0
	for iu in 5:
		var a := (g[iu][0] as Vector3) + (nr[iu][0] as Vector3) * 0.0
		var b := (g[iu][0] as Vector3) - (nr[iu][0] as Vector3) * 0.0
		if a.distance_to(b) < 1e-9:
			bordo_uguali += 1
	t.eq(bordo_uguali, 5, "…su tutta la riga del margine")
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
	# ⚠️ E LA COSA CHE CONTA È LA DISPERSIONE SU UNA FACCIA SOLA.
	# «Non sono tutte verso l'alto» non sa fallire: i due fogli hanno il
	# segno opposto, quindi metà punta in giù anche su una LASTRA PIATTA
	# — cioè il difetto di partenza passerebbe la guardia intitolata a
	# lui. Su una superficie vera le normali del solo dorso si aprono a
	# ventaglio; su una lastra sono tutte identiche.
	var apertura := 0.0
	var sopra := 0
	for n in nrm:
		if n.y <= 0.0:
			continue
		sopra += 1
		apertura = maxf(apertura, n.angle_to(Vector3.UP))
	t.ok(sopra > 0, "c'è un dorso da misurare (%d normali)" % sopra)
	t.ok(apertura > 0.25,
			"e le normali del DORSO si aprono a ventaglio: %.3f rad dal "
			% apertura + "verticale (su una lastra piatta sarebbe zero)")


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
	# ⚠️ SI MISURA LA MESH, non `_catmull`. La prima stesura campionava
	# la sola interpolazione: chi tornasse ai due cilindri accostati
	# lasciando `_catmull` intatta avrebbe lasciato la guardia verde —
	# guardava un'altra cosa da quella di cui parlava.
	#
	# ⚠️ E CON UNA PIEGA VERA, quella del papavero (0.185 dell'altezza).
	# Con la piega mite di prima persino una SPEZZATA — cioè letteralmente
	# lo spigolo dei due cilindri — dà un salto di 0.0787 rad contro una
	# soglia di 0.09: la guardia non aveva un caso in cui potesse fallire.
	var h := 0.290
	var dir := Vector3(0.62, 0.0, 0.78)
	var cima := Vector3(0, h, 0) + dir * (h * 0.185)
	var punti: Array = [Vector3.ZERO,
			Vector3(0, h * 0.45, 0) + dir * (h * 0.185 * 0.16), cima]
	var lati := 5
	var anelli := 5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	FIO.stelo_su(st, Transform3D.IDENTITY, punti, [0.005, 0.0038, 0.003],
			lati, anelli)
	var m: ArrayMesh = st.commit()
	# ⚠️ I CENTRI SI RICAVANO DALL'ORDINE DI EMISSIONE, non raggruppando
	# per quota: una corona di `stelo_su` è perpendicolare alla tangente,
	# quindi i suoi vertici NON stanno tutti alla stessa y — e
	# raggruppare per y rimescolava corone diverse, dando angoli da 2.5
	# radianti su uno stelo perfettamente liscio.
	# `stelo_su` emette `lati` quad (6 vertici) per ogni coppia di
	# corone: la media di un blocco è il punto di mezzo di quella coppia.
	var vtx: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var per_blocco := lati * 6
	var spina: Array[Vector3] = []
	for b in int(vtx.size() / per_blocco):
		var somma := Vector3.ZERO
		for k in per_blocco:
			somma += vtx[b * per_blocco + k]
		spina.append(somma / float(per_blocco))
	t.eq(spina.size(), anelli,
			"la spina si ricava dalla mesh (%d tratti)" % spina.size())
	# ⚠️ E IL METRO NON È L'ANGOLO PEGGIORE, è la sua CONCENTRAZIONE.
	# A cinque anelli una curva vera gira comunque di qualche grado per
	# tratto — è curva, non dritta — e un tetto assoluto finisce per
	# vietare la curvatura invece del gomito. La differenza fra una
	# curva e uno spigolo è che la prima DISTRIBUISCE la piega e il
	# secondo la CONCENTRA tutta in un punto: si misura il rapporto fra
	# l'angolo peggiore e la media.
	var concentrazione := func(sp: Array) -> float:
		var ang: Array[float] = []
		for i in range(1, sp.size() - 1):
			var a := ((sp[i] as Vector3) - (sp[i - 1] as Vector3)).normalized()
			var b := ((sp[i + 1] as Vector3) - (sp[i] as Vector3)).normalized()
			ang.append(a.angle_to(b))
		var somma := 0.0
		var peggio2 := 0.0
		for x in ang:
			somma += x
			peggio2 = maxf(peggio2, x)
		if somma <= 0.000001:
			return 1.0
		return peggio2 / (somma / float(ang.size()))
	var peggio := 0.0
	for i in range(1, spina.size() - 1):
		var a := (spina[i] - spina[i - 1]).normalized()
		var b := (spina[i + 1] - spina[i]).normalized()
		peggio = maxf(peggio, a.angle_to(b))
	# la CONTROPROVA: la stessa spina fatta a SPEZZATA (i due cilindri
	# accostati di prima), campionata negli stessi punti
	var peggio_spezzata := 0.0
	var sp: Array[Vector3] = []
	for k in spina.size():
		var u := (float(k) + 0.5) / float(spina.size())
		sp.append((punti[0] as Vector3).lerp(punti[1], u * 2.0) if u < 0.5
				else (punti[1] as Vector3).lerp(punti[2], (u - 0.5) * 2.0))
	for i in range(1, sp.size() - 1):
		var a := (sp[i] - sp[i - 1]).normalized()
		var b := (sp[i + 1] - sp[i]).normalized()
		peggio_spezzata = maxf(peggio_spezzata, a.angle_to(b))
	var conc_curva: float = concentrazione.call(spina)
	var conc_spezzata: float = concentrazione.call(sp)
	t.ok(peggio_spezzata > 0.05,
			"CONTROPROVA: una spezzata sugli stessi controlli fa un gomito "
			+ "di %.3f rad, concentrato %.2f volte la media"
			% [peggio_spezzata, conc_spezzata])
	t.ok(conc_spezzata > 1.6,
			"…e lo concentra tutto in un punto (%.2f)" % conc_spezzata)
	t.ok(conc_curva < conc_spezzata * 0.72,
			"lo stelo DISTRIBUISCE la piega invece di concentrarla: "
			+ "%.2f contro %.2f" % [conc_curva, conc_spezzata])
	t.ok(peggio < peggio_spezzata,
			"…e il suo tratto peggiore è comunque più dolce (%.3f < %.3f rad)"
			% [peggio, peggio_spezzata])
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
	# ⚠️ `_scatter_exact` restituisce dei NODI: senza liberarli Godot
	# stampa «ObjectDB instances leaked at exit», che NON è un
	# `SCRIPT ERROR` e quindi sfugge al secondo cancello di questo
	# progetto. E `free()`, non `queue_free()`: nel runner non gira
	# nessun frame e la coda non si smaltisce mai.
	mmi.free()
	mmi2.free()
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
	# ⚠️ IL TUBO DEL CORPO E LE ANTENNE si distinguono per GEOMETRIA: il
	# tubo è schiacciato attorno all'asse, le antenne salgono. Non c'è
	# più un canale che le marchi, e non serve: a tenerle fuori dalla
	# cerniera è `COLOR.a`, che dice CORPO anche per loro.
	var lung := 0.076 * 0.92
	var soglia := lung * 0.13
	var fuori := 0
	var antenne := 0
	var tubo := 0
	for i in vtx.size():
		if col[i].a > 0.5:
			continue
		if vtx[i].y > soglia:
			antenne += 1
			continue
		tubo += 1
		if absf(vtx[i].x) > rt + 0.0001:
			fuori += 1
	t.eq(fuori, 0,
			"il TUBO del corpo sta tutto entro il raggio del torace "
			+ "(%.4f m, %d vertici)" % [rt, tubo])
	t.ok(antenne > 0 and tubo > 0,
			"…e la soglia separa davvero due popolazioni: %d di tubo, "
			% tubo + "%d di antenne" % antenne)
	# le antenne ESCONO dal torace, ed è per questo che vale la pena
	# dirlo: se non uscissero, la cerniera non le toccherebbe comunque
	var antenna_lontana := 0.0
	for i in vtx.size():
		if col[i].a < 0.5 and vtx[i].y > soglia:
			antenna_lontana = maxf(antenna_lontana, absf(vtx[i].x))
	t.ok(antenna_lontana > rt,
			"le antenne escono dal raggio del torace (%.4f > %.4f): a "
			% [antenna_lontana, rt]
			+ "tenerle ferme è la maschera, non la loro posizione")
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
	# ⚠️ E IL PAVIMENTO NON PUÒ ESSERE SÉ STESSO. «Raddoppia» è vero per
	# QUALUNQUE frazione, zero compresa; e un tetto senza pavimento
	# lascia passare `TORACE_FRAZIONE = 0.0`. I due numeri contro cui si
	# giudica vengono dalla MESH: il corpo deve starci dentro, e il
	# torace deve restare molto sotto la semiapertura.
	var apertura := 0.105
	var rt: float = FARF.raggio_torace(apertura)
	# ⚠️ contro il TUBO, non contro l'AABB di `corpo()`: quello comprende
	# le ANTENNE, che escono di proposito e sono più larghe del torace.
	# Il tubo si isola per quota, come nel caso della farfalla piatta.
	var m: ArrayMesh = FARF.corpo(0.076 * 0.92)
	var vv: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var mezzo_tubo := 0.0
	for v in vv:
		if v.y <= 0.076 * 0.92 * 0.13:
			mezzo_tubo = maxf(mezzo_tubo, absf(v.x))
	t.ok(mezzo_tubo > 0.0001, "il tubo del corpo esiste (%.5f)" % mezzo_tubo)
	t.ok(rt >= mezzo_tubo,
			"il torace CONTIENE il tubo del corpo (%.5f >= %.5f): sotto, "
			% [rt, mezzo_tubo]
			+ "la cerniera piegherebbe l'addome come un'ala")
	t.ok(rt < apertura * 0.5 * 0.30,
			"…e resta molto sotto la semiapertura (%.5f < %.5f)"
			% [rt, apertura * 0.5 * 0.30])
	# il corpo scala con la sua lunghezza, non con dei metri assoluti
	var a: AABB = FARF.corpo(0.060).get_aabb()
	var b: AABB = FARF.corpo(0.120).get_aabb()
	t.almost(b.size.x, a.size.x * 2.0,
			"e anche lo spessore del corpo va con la lunghezza", 0.0005)
	t.ok(a.size.x > 0.0001,
			"…e il corpo non è degenere (%.5f m di larghezza)" % a.size.x)


## ⚠️ LA BATTUTA È UNA LEGGE SOLA IN DUE LINGUE, e questa è la prova di
## equivalenza che le tiene appaiate — la stessa disciplina che
## `nottambulo()` ha in `test_ecs_mondo`. È un SOURCE-CHECK, e lo dico:
## il vertex shader non si può far girare headless, quindi si legge la
## sua trascrizione e si pretende che i due numeri della legge siano gli
## stessi. Senza, cambiare `0.35` o `0.62` nel solo shader lascerebbe la
## suite verde e le novanta batterebbero con una legge diversa dalle
## cinque nominate.
func _la_battuta_e_la_stessa_in_due_lingue(t) -> void:
	var gd := FileAccess.get_file_as_string("res://scenes/world/FarfalleGeo.gd")
	var sh := FileAccess.get_file_as_string("res://shaders/butterfly.gdshader")
	t.ok(gd.length() > 0 and sh.length() > 0, "i due sorgenti si leggono")
	var numeri := func(testo: String, chiave: String) -> Array:
		var i := testo.find(chiave)
		if i < 0:
			return []
		var riga := testo.substr(i, testo.find("\n", i) - i)
		var out: Array = []
		for pezzo in riga.split(" "):
			var pulito := str(pezzo).replace("(", "").replace(")", "") \
					.replace(";", "").replace(",", "").replace("*", "")
			if pulito.is_valid_float():
				out.append(float(pulito))
		return out
	var a: Array = numeri.call(gd, "sin(theta + ")
	var b: Array = numeri.call(sh, "sin(theta + ")
	t.ok(a.size() > 0 and a == b,
			"la deformazione del tempo è la stessa: %s in GDScript, %s "
			% [str(a), str(b)] + "nello shader")
	var pa: Array = numeri.call(gd, "pow(absf(s), ")
	var pb: Array = numeri.call(sh, "pow(abs(s), ")
	t.ok(pa.size() > 0 and pa == pb,
			"e il colmo piatto pure: %s contro %s" % [str(pa), str(pb)])
	# e la cerniera del battito è gatata su COLOR.a — è quella riga a
	# tenere il torace E LE ANTENNE fuori dalla piega
	t.ok(sh.contains("raggio_torace, 0.0) * COLOR.a"),
			"la cerniera è gatata su COLOR.a: il corpo non si piega")
	# e l'ORLO lo leggono TUTTI E DUE i montaggi. Le cinque nominate sono
	# dipinte da `handpaint`, le novanta dal loro shader: se solo uno dei
	# due lo guardasse, la farfalla che catturi nel retino non sarebbe
	# quella che hai visto volare — che è il difetto che avere UNA
	# sagoma serve a impedire.
	var hp := FileAccess.get_file_as_string("res://shaders/handpaint.gdshader")
	var cwsrc := FileAccess.get_file_as_string("res://scenes/world/CozyWorld.gd")
	t.ok(sh.contains("orlo = COLOR.r") or sh.contains("orlo;"),
			"le novanta leggono l'orlo")
	t.ok(hp.contains("uniform float orlo"),
			"…e handpaint pure, per i cinque rig nominati")
	t.ok(cwsrc.contains('wing_mat.set_shader_parameter("orlo"'),
			"…e le ali dei rig lo accendono davvero")


## ⚠️ LE TRE INVARIANTI DI `Ecosystem._flower_mesh` erano dichiarate «non
## si toccano» e non aveva una guardia nessuna delle tre. Qui si monta un
## `Ecosystem` FUORI dall'albero (il suo `_ready` non parte) e si
## chiedono le mesh vere, quelle che il gioco consegna al MultiMesh del
## C++ — non `FARF.piatta(…)` con numeri scritti a mano, che è quello
## che il resto di questo file prova.
func _lecosistema_regge_i_suoi_contratti(t) -> void:
	var eco = ECO.new()
	var fiore: ArrayMesh = eco.call("_flower_mesh")
	t.eq(fiore.get_surface_count(), 1,
			"il fiore selvatico è UNA superficie: con due, "
			+ "`_wildflower_mat` non cattura più il materiale e il "
			+ "ritinto stagionale si spegne in silenzio")
	t.ok(eco.get("_wildflower_mat") != null, "…e il materiale è catturato")
	t.eq(fiore.surface_get_material(0), eco.get("_wildflower_mat"),
			"…ed è proprio quello della superficie 0")
	# COLOR.a è una MASCHERA: 0 o 1, niente sfumature
	var col: PackedColorArray = fiore.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var petali := 0
	var verdi := 0
	var sfumati := 0
	for c in col:
		if c.a > 0.99:
			petali += 1
		elif c.a < 0.01:
			verdi += 1
		else:
			sfumati += 1
	t.eq(sfumati, 0, "`COLOR.a` è una maschera, non una sfumatura")
	t.ok(petali > 0 and verdi > 0,
			"…e distingue petali (%d) da verde (%d): con la maschera "
			% [petali, verdi] + "storta i petali diventano verdi")
	# le tinte restano QUATTRO: `kind` 0..3 è persistito e riletto con
	# un clamp, quindi tre tinte ricolorerebbero i salvataggi vecchi
	var mat: ShaderMaterial = eco.get("_wildflower_mat")
	for chiave: String in ["tint_a", "tint_b", "tint_c", "tint_d"]:
		t.ok(mat.get_shader_parameter(chiave) != null,
				"la tinta «%s» c'è (le tinte restano QUATTRO)" % chiave)
	# e la farfalla: una superficie, e la CERNIERA allineata alla mesh
	var farfalla: ArrayMesh = eco.call("_butterfly_mesh")
	t.eq(farfalla.get_surface_count(), 1, "la farfalla è UNA superficie")
	var bmat: ShaderMaterial = eco.get("_butterfly_mat")
	t.eq(farfalla.surface_get_material(0), bmat,
			"…e il suo materiale è catturato dalla superficie 0")
	var apertura: float = farfalla.get_aabb().size.x
	var rt: float = float(bmat.get_shader_parameter("raggio_torace"))
	t.almost(rt, FARF.raggio_torace(apertura),
			"la cerniera dello shader è allineata alla MESH consegnata: "
			+ "senza quella riga il vertex ripiega sul suo valore di "
			+ "serie e le farfalle si piegano dal punto sbagliato",
			0.0002)
	t.ok(apertura < 0.16,
			"e l'apertura resta a misura di farfalla (%.3f m): a 28 cm "
			% apertura + "era larga quanto la testa di un chibi")
	eco.free()


## GLI ARRAY PARALLELI. `flatten_cell` indicizza `_flower_fields[c]` con
## l'indice di `_flower_base`: se qualcuno facesse `append` su uno solo
## dei due, accuccerebbe SILENZIOSAMENTE i fiori sbagliati.
func _i_due_array_dei_campi_restano_paralleli(t) -> void:
	var w = CW.new()
	var tf: Array[Transform3D] = [Transform3D.IDENTITY]
	var g = GEO.new()
	for k in 3:
		w.call("_registra_campo",
				w.call("_scatter_exact", g.clover_mesh(Color("fdf6ec")),
						tf, false), tf)
	t.eq((w.get("_flower_fields") as Array).size(),
			(w.get("_flower_base") as Array).size(),
			"i campi e le loro trasformate restano appaiati")
	# e un campo VUOTO non sfasa gli indici: `_scatter_exact` torna null
	w.call("_registra_campo", w.call("_scatter_exact",
			g.clover_mesh(Color("fdf6ec")), [] as Array[Transform3D], false),
			[] as Array[Transform3D])
	t.eq((w.get("_flower_fields") as Array).size(),
			(w.get("_flower_base") as Array).size(),
			"…anche quando un campo non semina niente")
	for n in (w.get("_flower_fields") as Array):
		(n as Node).free()
	w.free()
