extends RefCounted
## IL TETTO SI AFFIANCA, E NON SI MANGIA LA CORONA DEL MURO.
##
## Il Tetto è il pezzo più visto del gioco — sta sopra ogni casa — ed è
## anche l'unico il cui mestiere è essere AFFIANCATO. Due difetti veri, e
## nessuno dei due si vede fotografando il pezzo da solo:
##
##  · IL RITMO. I listelli stavano a z = -0.3 / 0.0 / +0.3 su un passo di
##    cella di 1.0. Attraversando il confine la sequenza diventava
##    0.3, 0.3, **0.4**, 0.3, 0.3, **0.4**: su un tetto di due celle si
##    vedeva la cucitura. Perché un ornamento si affianchi, il suo passo
##    deve DIVIDERE la cella.
##  · LA CORONA. La lastra occupava y 2.01-2.11 e la trave di colmo del
##    Muro (2.00-2.08) col suo coprigiunto (2.08-2.11) ci finivano dentro:
##    posavi un tetto e la casa perdeva la sua cornice.
##
## Le due misure si prendono dai pezzi VERI del catalogo, mai da numeri
## ricopiati: se un domani il Muro alza la sua trave, qui si accende una
## luce.

const CATALOGO := "res://scenes/build/BuildCatalog.gd"


func run(t) -> void:
	var cat: GDScript = load(CATALOGO)
	t.ok(cat != null, "BuildCatalog si carica")
	if cat == null:
		return
	_test_ritmo_si_affianca(t, cat)
	_test_non_mangia_la_corona(t, cat)


func _costruisci(cat: GDScript, nome: String) -> Node3D:
	for it in cat.items():
		if str((it as Dictionary).get("name", "")) == nome:
			return ((it as Dictionary)["builder"] as Callable).call()
	return null


func _relativa(root: Node, n: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c := n
	while c != null and c != root:
		t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


## L'ingombro di ogni mesh del pezzo, in coordinate del pezzo.
func _scatole(root: Node3D) -> Array:
	var out: Array = []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		out.append(_relativa(root, mi) * (mi as MeshInstance3D).mesh.get_aabb())
	return out


## IL RITMO. Si raccolgono le x dei nervi del tetto (i coppi e i canali:
## sono lunghi lungo Z e stretti lungo X) e si pretende che il loro passo
## divida ESATTAMENTE la cella. È l'unica condizione che rende invisibile
## il confine fra due tetti vicini, e vale per qualunque numero di nervi.
func _test_ritmo_si_affianca(t, cat: GDScript) -> void:
	var tetto := _costruisci(cat, "Tetto")
	t.ok(tetto != null, "il Tetto si costruisce")
	if tetto == null:
		return
	var xs: Array[float] = []
	for ab: AABB in _scatole(tetto):
		# un nervo: lungo quasi quanto la cella in Z, stretto in X
		if ab.size.z > 0.8 and ab.size.x < 0.35:
			xs.append(ab.position.x + ab.size.x * 0.5)
	tetto.free()
	t.ok(xs.size() >= 4, "il tetto ha dei nervi da misurare (%d)" % xs.size())
	if xs.size() < 4:
		return
	xs.sort()
	var passo := xs[1] - xs[0]
	t.ok(passo > 0.001, "il passo dei nervi è positivo (%.4f)" % passo)
	if passo <= 0.001:
		return
	var regolare := true
	for i in range(1, xs.size()):
		if absf((xs[i] - xs[i - 1]) - passo) > 0.002:
			regolare = false
	t.ok(regolare, "i nervi sono a passo costante (%.3f)" % passo)
	# LA CONDIZIONE VERA: il passo deve dividere la cella, o attraversando
	# il confine si apre una fuga più larga delle altre
	var quanti := 1.0 / passo
	t.almost(quanti, roundf(quanti),
			"il passo dei nervi DIVIDE la cella (1.0 / %.3f = %.4f): due tetti affiancati fanno un tetto solo"
			% [passo, quanti], 0.01)
	# e il pezzo copre tutta la cella: se i nervi si fermassero prima del
	# bordo resterebbe una striscia liscia in mezzo al tetto
	t.ok(xs[0] <= -0.5 + passo * 0.51 and xs[xs.size() - 1] >= 0.5 - passo * 0.51,
			"i nervi arrivano fino ai bordi della cella (%.3f … %.3f)"
			% [xs[0], xs[xs.size() - 1]])


## LA CORONA. Il punto più basso del Tetto non deve scendere sotto il
## punto più alto del Muro: il tetto POGGIA sulla trave di colmo, non ci
## affonda dentro.
func _test_non_mangia_la_corona(t, cat: GDScript) -> void:
	var muro := _costruisci(cat, "Muro")
	var tetto := _costruisci(cat, "Tetto")
	t.ok(muro != null and tetto != null, "Muro e Tetto si costruiscono insieme")
	if muro == null or tetto == null:
		if muro: muro.free()
		if tetto: tetto.free()
		return
	var cima_muro := -99.0
	for ab: AABB in _scatole(muro):
		cima_muro = maxf(cima_muro, ab.position.y + ab.size.y)
	var base_tetto := 99.0
	for ab2: AABB in _scatole(tetto):
		base_tetto = minf(base_tetto, ab2.position.y)
	muro.free()
	tetto.free()
	t.ok(cima_muro > 1.5, "il Muro ha una corona da misurare (%.3f)" % cima_muro)
	t.ok(base_tetto >= cima_muro - 0.002,
			"il Tetto POGGIA sulla corona del Muro (%.3f ≥ %.3f): non se la mangia"
			% [base_tetto, cima_muro])
