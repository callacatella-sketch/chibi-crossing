extends RefCounted
## La caserma dei pompieri: i quindici pezzi del catalogo.
##
## Non prova la bellezza (quella si guarda), prova le cose che si rompono in
## silenzio: un pezzo che affonda nel terreno, una collisione dimenticata, un
## nome nuovo senza la sua traduzione inglese, un pezzo del corredo che finisce
## anche in vendita da solo (e il giocatore lo pagherebbe due volte).
##
## E una guardia di tono: il rosso della caserma deve restare CALDO. Qui non
## brucia niente e non brucerà mai — se un domani qualcuno alzasse la
## saturazione fino al rosso d'allarme, la caserma smetterebbe di essere un
## posto dove si tiene pronto e diventerebbe un posto dove si ha paura.

const CAT := preload("res://scenes/build/BuildCatalog.gd")
const ECO := preload("res://scenes/ui/Economy.gd")
const EN_UI := preload("res://locale/en/ui.gd")

## L'àncora e il suo corredo: comprando l'Autopompa arriva tutta la caserma.
const ANCORA := "Autopompa"
const CORREDO := ["Portone rimessa", "Torretta", "Palo pompieri",
		"Scala a pioli", "Insegna caserma", "Campana caserma", "Casco appeso",
		"Stivali", "Secchi", "Idrante", "Manichetta", "Faro caserma",
		"Cuccia", "Pennone"]


func run(t) -> void:
	var voci := _voci()
	_test_pezzi_nel_catalogo(t, voci)
	_test_geometria(t, voci)
	_test_corredo(t)
	_test_traduzioni(t)
	_test_faro_gira(t)
	_test_rosso_caldo(t)


func _tutti() -> Array:
	return [ANCORA] + CORREDO


## Le voci di catalogo della caserma, per nome.
func _voci() -> Dictionary:
	var per_nome := {}
	for v in CAT.items():
		per_nome[str(v["name"])] = v
	return per_nome


# ------------------------------------------------------------- catalogo

func _test_pezzi_nel_catalogo(t, voci: Dictionary) -> void:
	for nome in _tutti():
		t.ok(voci.has(nome), "la caserma ha il pezzo «%s»" % nome)
		if not voci.has(nome):
			continue
		var v: Dictionary = voci[nome]
		t.ok(v["builder"] is Callable, "%s ha un builder" % nome)
		t.ok(int(v["cat"]) in [0, 1, 2], "%s sta in una categoria valida" % nome)
		t.ok(str(v["type"]) in ["cell", "edge"], "%s ha un tipo valido" % nome)


func _test_geometria(t, voci: Dictionary) -> void:
	for nome in _tutti():
		if not voci.has(nome):
			continue
		var v: Dictionary = voci[nome]
		var node: Node3D = v["builder"].call()
		t.ok(node != null and node.get_child_count() > 0,
				"%s costruisce qualcosa" % nome)
		if node == null:
			continue
		var box := _ingombro(node, Transform3D.IDENTITY)
		# nessun pezzo affonda nel prato
		t.ok(box.position.y > -0.06, "%s non affonda nel terreno" % nome)
		# i pezzi che stanno per terra ci stanno davvero: qualcosa deve
		# toccare il suolo. Quelli da muro (il casco appeso) no: è il loro
		# mestiere stare per aria, e devono restare a portata di parete.
		if str(v["type"]) == "cell":
			t.ok(box.position.y < 0.32, "%s tocca terra" % nome)
		else:
			t.ok(box.position.y + box.size.y < 2.3,
					"%s sta dentro l'altezza di un muro" % nome)
		# in scala col villaggio: una cella è un metro. La TORRETTA è
		# l'eccezione DICHIARATA: da quando è visitabile, la gronda deve
		# lasciare in piedi anche la volpina (1.6 con le orecchie) sopra
		# uno spiazzo a quota due metri — a una torre di vedetta si
		# concedono quattro metri, essere più alta del resto è il suo
		# mestiere. Non allargare l'eccezione ad altri pezzi.
		var tetto_max := 4.0 if nome == "Torretta" else 3.0
		t.ok(box.size.y < tetto_max,
				"%s resta nella sua altezza di scala" % nome)
		t.ok(box.size.x < 2.2 and box.size.z < 2.2,
				"%s sta nel suo ingombro" % nome)
		# le collisioni dichiarate hanno misure sensate
		for c in v.get("cols", []):
			var dim: Vector3 = c[0]
			t.ok(dim.x > 0.0 and dim.y > 0.0 and dim.z > 0.0,
					"%s: collisione con misure positive" % nome)
			t.ok(dim.y <= box.size.y + 0.3,
					"%s: la collisione non è più alta del pezzo" % nome)
		node.free()


## L'ingombro reale di un pezzo: l'unione delle AABB delle sue mesh, nello
## spazio del pezzo (le AABB delle mesh sono in spazio locale, quindi vanno
## portate su con la trasformata accumulata).
func _ingombro(node: Node3D, sopra: Transform3D) -> AABB:
	var mio := sopra * node.transform
	var box := AABB()
	var primo := true
	if node is MeshInstance3D and node.mesh != null:
		box = mio * node.mesh.get_aabb()
		primo = false
	for figlio in node.get_children():
		if figlio is not Node3D:
			continue
		var sotto := _ingombro(figlio, mio)
		if sotto.size == Vector3.ZERO:
			continue
		if primo:
			box = sotto
			primo = false
		else:
			box = box.merge(sotto)
	return box


# --------------------------------------------------------------- corredo

func _test_corredo(t) -> void:
	var corredo: Array = ECO.CORREDO.get(ANCORA, [])
	t.eq(corredo.size(), CORREDO.size(), "il corredo della caserma è completo")
	for pezzo in CORREDO:
		t.ok(pezzo in corredo, "il corredo porta «%s»" % pezzo)
	# l'àncora è in vendita, il corredo NO: altrimenti si paga due volte
	var in_vendita := {}
	for offerta in ECO.SHOP_PIECES:
		in_vendita[str(offerta["name"])] = true
	t.ok(in_vendita.has(ANCORA), "l'autopompa è al banco del mercante")
	for pezzo in CORREDO:
		t.ok(not in_vendita.has(pezzo),
				"«%s» arriva col corredo, non si vende da solo" % pezzo)


# ------------------------------------------------------------ traduzione

func _test_traduzioni(t) -> void:
	var en: Dictionary = EN_UI.tabella()
	for nome in _tutti():
		t.ok(en.has(nome), "«%s» ha il suo nome inglese" % nome)
		if en.has(nome):
			t.ok(str(en[nome]).strip_edges() != "",
					"«%s» non ha una traduzione vuota" % nome)
	# anche la descrizione al banco, con le sue tre righe
	for offerta in ECO.SHOP_PIECES:
		if str(offerta["name"]) != ANCORA:
			continue
		var desc := str(offerta.get("desc", ""))
		t.ok(en.has(desc), "la descrizione dell'autopompa è tradotta")
		if en.has(desc):
			t.eq(str(en[desc]).count("\n"), desc.count("\n"),
					"la descrizione inglese ha le stesse righe")


# ----------------------------------------------------------- il movimento

func _test_faro_gira(t) -> void:
	# i pezzi piazzati sono nodi nudi: il giro lo dà un AnimationPlayer in
	# loop, come la mongolfiera. Se sparisse, il faro resterebbe fermo senza
	# che nessun errore lo dica.
	var voci := _voci()
	var faro: Node3D = voci["Faro caserma"]["builder"].call()
	t.ok(faro.get_node_or_null("Girella") != null, "il faro ha la testa che gira")
	var player: AnimationPlayer = null
	for figlio in faro.get_children():
		if figlio is AnimationPlayer:
			player = figlio
	t.ok(player != null, "il faro ha il suo AnimationPlayer")
	if player != null:
		t.ok(player.autoplay != "", "il giro del faro parte da solo")
		var anim := player.get_animation(player.autoplay)
		t.ok(anim != null and anim.loop_mode == Animation.LOOP_LINEAR,
				"il giro del faro è continuo")
	faro.free()

	var campana: Node3D = voci["Campana caserma"]["builder"].call()
	t.ok(campana.get_node_or_null("Campana") != null,
			"la campana ha il suo giogo che dondola")
	campana.free()


# ------------------------------------------------------------- il tono

func _test_rosso_caldo(t) -> void:
	# rosso da lacca, non da allarme: saturo sì, ma non urlato
	t.ok(CAT.POMPA_ROSSO.s < 0.75, "il rosso della caserma non è un allarme")
	t.ok(CAT.POMPA_ROSSO.v > 0.6, "il rosso della caserma è luminoso")
	t.ok(CAT.POMPA_ROSSO_SCURO.v < CAT.POMPA_ROSSO.v,
			"l'ombra del rosso è più scura della luce")
