extends RefCounted
## LA PALESTRA DEL VILLAGGIO — gli attrezzi costruibili.
##
## Il test difende le cose che, sbagliate, non danno nessun errore:
##
##  • gli attrezzi devono essere RAGGIUNGIBILI: un pezzo che non sta né in
##    negozio né in un Ordine resta un «?» grigio per tutta la partita,
##    con la didascalia che promette un Ordine che non arriverà mai;
##  • ogni attrezzo ha il suo POSTO d'uso — il nodo a cui si aggancerà
##    chi viene ad allenarsi. Ricavarlo dopo, a occhio, dai numeri del
##    builder è il modo sicuro di far allenare qualcuno dentro un muro;
##  • le COLLISIONI devono contenere il pezzo davvero: un bilanciere fuori
##    sagoma è un bilanciere che si attraversa camminando;
##  • i pezzi si costruiscono senza rompersi, e il loro nome (che è la
##    chiave del salvataggio) resta italiano e tradotto solo a schermo.

const CAT := "res://scenes/build/BuildCatalog.gd"
const PAL := "res://scenes/build/BuildPalestra.gd"
const ECO := "res://scenes/ui/Economy.gd"
const LEGNA := "res://scenes/interact/Woodcutting.gd"
const CAT_PALESTRA := 3


func run(t) -> void:
	var cs: GDScript = load(CAT)
	var ps: GDScript = load(PAL)
	t.ok(cs != null and ps != null, "il catalogo e la palestra compilano")
	if cs == null or ps == null:
		return
	var attrezzi := []
	for v in cs.items():
		if int((v as Dictionary).get("cat", 0)) == CAT_PALESTRA:
			attrezzi.append(v)
	t.ok(attrezzi.size() >= 8, "la palestra ha i suoi attrezzi (%d)" % attrezzi.size())
	if attrezzi.is_empty():
		return

	_test_si_costruiscono(t, attrezzi)
	_test_hanno_un_posto(t, attrezzi)
	_test_collisioni(t, attrezzi)
	_test_raggiungibili(t, attrezzi)
	_test_lingua(t, attrezzi)


## Ogni builder gira e produce qualcosa di vero (non un nodo vuoto).
func _test_si_costruiscono(t, attrezzi: Array) -> void:
	for v in attrezzi:
		var nome := str(v["name"])
		var n: Node3D = (v["builder"] as Callable).call()
		t.ok(n != null, "«%s» si costruisce" % nome)
		if n == null:
			continue
		var mesh := _conta_mesh(n)
		# la soglia non è a occhio: il pezzo più semplice della palestra è
		# il tappetino, e ne ha già nove
		t.ok(mesh >= 6, "«%s» è un oggetto, non un cubo (%d mesh)" % [nome, mesh])
		n.free()


func _conta_mesh(n: Node) -> int:
	var q := 1 if n is MeshInstance3D else 0
	for f in n.get_children():
		q += _conta_mesh(f)
	return q


## IL POSTO D'USO. È l'aggancio che serve al passo successivo — chi si
## allena deve sapere dove mettersi e da che parte guardare — e va messo
## adesso: un posto ricavato dopo dai numeri del builder è un posto
## sbagliato.
func _test_hanno_un_posto(t, attrezzi: Array) -> void:
	for v in attrezzi:
		var nome := str(v["name"])
		var n: Node3D = (v["builder"] as Callable).call()
		if n == null:
			continue
		var posto := n.find_child("posto", true, false) as Node3D
		t.ok(posto != null, "«%s» dice dove ci si mette" % nome)
		if posto:
			# dentro un raggio umano dal pezzo: un posto a tre metri non è
			# il posto di questo attrezzo
			var d := Vector2(posto.position.x, posto.position.z).length()
			t.ok(d < 1.4, "…e il posto di «%s» è addosso all'attrezzo (%.2f m)"
					% [nome, d])
			t.ok(posto.position.y >= -0.01,
					"…e non sottoterra (%.2f)" % posto.position.y)
	# e i due posatoi che dondolano hanno il pivot in ALTO, o oscillerebbero
	# attorno al proprio ombelico
	for v in attrezzi:
		if str(v["name"]) != "Sacco":
			continue
		var n: Node3D = (v["builder"] as Callable).call()
		var sacco := n.find_child("sacco", true, false) as Node3D
		t.ok(sacco != null, "il sacco è un nodo a sé, che potrà dondolare")
		if sacco:
			t.ok(sacco.position.y > 1.5,
					"…col pivot in alto, dove è appeso (%.2f)" % sacco.position.y)
		n.free()


## Le collisioni devono CONTENERE il pezzo: si misura l'ingombro vero
## delle mesh e si controlla che le scatole dichiarate ci arrivino.
func _test_collisioni(t, attrezzi: Array) -> void:
	for v in attrezzi:
		var nome := str(v["name"])
		var cols: Array = v.get("cols", [])
		if cols.is_empty():
			# legittimo solo per i pezzi che si calpestano
			t.ok(int(v.get("layer", 2)) <= 1,
					"«%s» senza collisioni è un pezzo da calpestare" % nome)
			continue
		var n: Node3D = (v["builder"] as Callable).call()
		if n == null:
			continue
		var alto_vero := _cima(n, Transform3D.IDENTITY)
		var alto_col := 0.0
		for c in cols:
			alto_col = maxf(alto_col,
					float((c[1] as Vector3).y) + float((c[0] as Vector3).y) * 0.5)
		# tolleranza: le parti appese (corde, anelli) possono sporgere un
		# po' sopra la scatola senza che nessuno ci sbatta contro
		t.ok(alto_col >= alto_vero - 0.25,
				"le collisioni di «%s» arrivano fin quasi in cima (%.2f vs %.2f)"
				% [nome, alto_col, alto_vero])
		n.free()


## L'altezza vera dell'ingombro. La trasformata va portata giù per intero:
## un cilindro lungo 0.94 messo di traverso (rotation.z = PI/2) è alto 6 cm,
## non 47 — e misurandolo male si accusano le collisioni di un difetto che
## non hanno.
func _cima(n: Node, tr: Transform3D) -> float:
	var y := -99.0
	for f in n.get_children():
		if not (f is Node3D):
			continue
		var f3 := f as Node3D
		var t2 := tr * f3.transform
		if f3 is MeshInstance3D and (f3 as MeshInstance3D).mesh:
			var box: AABB = t2 * (f3 as MeshInstance3D).mesh.get_aabb()
			y = maxf(y, box.end.y)
		y = maxf(y, _cima(f3, t2))
	return y


## RAGGIUNGIBILI. Con i lucchetti attivi un pezzo che non sta né in
## negozio né in un Ordine del Gufo non arriva MAI: resta un «?» grigio
## con scritto «Un Ordine del Gufo lo porterà» — una promessa falsa.
func _test_raggiungibili(t, attrezzi: Array) -> void:
	var es: GDScript = load(ECO)
	if es == null:
		return
	var in_negozio := {}
	for v in es.SHOP_PIECES:
		in_negozio[str((v as Dictionary)["name"])] = true
	var corredo: Dictionary = es.CORREDO
	var portati := {}
	for capo in corredo:
		for pezzo in (corredo[capo] as Array):
			portati[str(pezzo)] = str(capo)
	for v in attrezzi:
		var nome := str(v["name"])
		var arriva: bool = in_negozio.has(nome) or portati.has(nome)
		t.ok(arriva, "«%s» si può davvero avere" % nome)
		# e chi arriva col corredo deve avere un capo che sta in vetrina,
		# o il corredo non si compra da nessuna parte
		if portati.has(nome):
			t.ok(in_negozio.has(portati[nome]),
					"…e il suo capo «%s» sta in vetrina" % portati[nome])
	# la legna: un attrezzo si costruisce, non si evoca (il tappetino è
	# stoffa, ed è l'unico che può essere gratis)
	var ws := FileAccess.get_file_as_string(LEGNA)
	for v in attrezzi:
		var nome := str(v["name"])
		if nome == "Tappetino":
			continue
		t.ok(ws.contains('"%s":' % nome), "«%s» costa legna" % nome)


## I nomi viaggiano nei SALVATAGGI: restano italiani per sempre, e si
## traducono solo quando si disegnano.
func _test_lingua(t, attrezzi: Array) -> void:
	var ui := FileAccess.get_file_as_string("res://locale/en/ui.gd")
	for v in attrezzi:
		var nome := str(v["name"])
		t.ok(ui.contains('"%s":' % nome), "«%s» ha il suo nome inglese" % nome)
	t.ok(ui.contains('"Palestra":'), "e la categoria pure")
	var bs := FileAccess.get_file_as_string("res://scenes/build/BuildSystem.gd")
	t.ok(bs.contains('"Palestra"]'),
			"la palestra è una categoria sua nel builder")
	# il catalogo non deve avere due pezzi con lo stesso nome: la chiave
	# del salvataggio è quella, e il secondo vincerebbe in silenzio
	var cs: GDScript = load(CAT)
	var visti := {}
	for v in cs.items():
		var nome := str((v as Dictionary)["name"])
		t.ok(not visti.has(nome), "«%s» compare una volta sola in catalogo" % nome)
		visti[nome] = true
