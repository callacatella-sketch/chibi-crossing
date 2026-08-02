extends RefCounted
## LA BOUTIQUE — i quindici pezzi del negozio di vestiti.
##
## Le tre guardie di sempre (il pezzo esiste, si costruisce, è
## RAGGIUNGIBILE) più quattro che sono di questo set e di nessun altro,
## perché qui il modo di rompere tutto in silenzio è diverso:
##
##  · IL VETRO. `_mat(..., trans)` NON è trasparenza — la translucency
##    dell'handpaint è retro-illuminazione — e una vetrina fatta così
##    esce OPACA, col manichino dentro che non si vede: cioè senza il
##    motivo per cui esiste una vetrina. Il test guarda il materiale.
##  · IL CAPPOTTO DEL MANICHINO. Un capo indossato deve stare FUORI dal
##    corpo. Sbagliare di due centimetri non dà nessun errore: il petto
##    del manichino spunta attraverso il bavero, e di profilo la figura
##    sembra tagliata a metà. Il test confronta le due sagome.
##  · I CAPI CHE PENDONO. Un capo appeso più in alto dell'asta o che
##    tocca terra non è un capo appeso. È il tipo di errore che si vede
##    subito guardando, e mai leggendo.
##  · LA CRENATURA DELL'INSEGNA. Le lettere staccate SONO il marchio: se
##    un domani qualcuno le stringe, l'insegna smette di dire «negozio di
##    moda» e comincia a dire «ferramenta» — e la suite resterebbe verde.

const CAT := preload("res://scenes/build/BuildCatalog.gd")
const BOU := preload("res://scenes/build/BuildBoutique.gd")
const ECONOMY := preload("res://scenes/ui/Economy.gd")
const SYS := preload("res://scenes/build/BuildSystem.gd")
const L := preload("res://systems/L10n.gd")

const CAT_BOUTIQUE := 5
const ANCORA := "Vetrina moda"
const PEZZI := ["Vetrina moda", "Insegna boutique", "Manichino",
		"Busto sartoriale", "Stender", "Tavolo piegati", "Scaffale a giorno",
		"Camerino", "Specchiera", "Cassa boutique", "Poltroncina",
		"Cesto saldi", "Faretti", "Passatoia", "Sacchetti"]
## Chi ha un posto d'uso: dove ci si mette e da che parte si guarda. Va
## messo ADESSO — ricavarlo dopo, a occhio, dai numeri del builder è il
## modo sicuro di far provare una giacca a qualcuno dentro un muro.
const CON_POSTO := ["Manichino", "Stender", "Tavolo piegati", "Camerino",
		"Specchiera", "Cassa boutique", "Poltroncina"]


func run(t) -> void:
	_test_i_pezzi_esistono(t)
	_test_si_costruiscono_davvero(t)
	_test_il_corredo(t)
	_test_il_posto_duso(t)
	_test_il_vetro_e_vetro(t)
	_test_il_manichino_e_vestito(t)
	_test_i_capi_pendono(t)
	_test_linsegna_si_legge(t)
	_test_la_luce_ce(t)
	_test_i_nomi_sono_tradotti(t)
	_test_il_negozio_ha_le_sue_cose(t)


func _test_i_pezzi_esistono(t) -> void:
	var per_nome := _catalogo()
	for n in PEZZI:
		t.ok(per_nome.has(n), "«%s» è nel catalogo" % n)
	t.eq(PEZZI.size(), 15, "quindici pezzi: un negozio che si può davvero allestire")
	var quanti := 0
	for v in CAT.items():
		if int((v as Dictionary).get("cat", 0)) == CAT_BOUTIQUE:
			quanti += 1
	t.eq(quanti, PEZZI.size(),
			"stanno tutti nella categoria Boutique, e nessun altro ci è finito")
	t.ok(SYS.CAT_NAMES.size() > CAT_BOUTIQUE
			and str(SYS.CAT_NAMES[CAT_BOUTIQUE]) == "Boutique",
			"la scheda «Boutique» esiste nel menu di costruzione")


## Ogni pezzo si costruisce, ha geometria vera, poggia a terra e sta
## dentro la sua cella.
func _test_si_costruiscono_davvero(t) -> void:
	var per_nome := _catalogo()
	for n in PEZZI:
		var voce: Dictionary = per_nome.get(n, {})
		if voce.is_empty():
			continue
		var nodo = (voce["builder"] as Callable).call()
		t.ok(nodo != null, "«%s» costruisce un nodo" % n)
		if nodo == null:
			continue
		t.ok(_conta_mesh(nodo) >= 3,
				"«%s» ha geometria vera (%d mesh)" % [n, _conta_mesh(nodo)])
		var aabb := _ingombro(nodo)
		t.ok(aabb.position.y > -0.35,
				"«%s» non sprofonda sottoterra (y=%.2f)" % [n, aabb.position.y])
		t.ok(aabb.size.x < 2.2 and aabb.size.z < 2.2,
				"«%s» sta nella sua cella (%.1f x %.1f)" % [n, aabb.size.x, aabb.size.z])
		t.ok(aabb.size.y < 2.6,
				"«%s» non buca il tetto (alto %.2f)" % [n, aabb.size.y])
		nodo.free()


## Un pezzo che non sta né in negozio né in un corredo resta un «?» grigio
## per tutta la partita, con la didascalia che promette un Ordine che non
## arriverà mai.
func _test_il_corredo(t) -> void:
	var per_nome := _catalogo()
	t.ok(ECONOMY.CORREDO.has(ANCORA),
			"la vetrina ha un corredo: un negozio o c'è intero, o è un magazzino")
	var corredo: Array = ECONOMY.CORREDO.get(ANCORA, [])
	for n in corredo:
		t.ok(per_nome.has(str(n)),
				"il corredo promette «%s», e il catalogo ce l'ha" % n)
	t.eq(corredo.size(), PEZZI.size() - 1,
			"tutta la boutique tranne la vetrina stessa (%d pezzi)" % corredo.size())
	t.ok(not ANCORA in corredo, "la vetrina non è nel proprio corredo")
	# e ogni pezzo dev'essere davvero raggiungibile
	for n in PEZZI:
		var ok: bool = (n == ANCORA) or (n in corredo)
		t.ok(ok, "«%s» si può ottenere davvero" % n)
	var in_negozio := false
	for p in ECONOMY.SHOP_PIECES:
		if str(p["name"]) == ANCORA:
			in_negozio = true
			t.ok(int(p["cost"]) > 0, "la vetrina ha un prezzo")
			t.eq(int(p["cat"]), CAT_BOUTIQUE, "ed è offerta nella sua categoria")
	t.ok(in_negozio, "la vetrina sta sul banco del mercante")


func _test_il_posto_duso(t) -> void:
	var per_nome := _catalogo()
	for n in CON_POSTO:
		var voce: Dictionary = per_nome.get(n, {})
		if voce.is_empty():
			continue
		var nodo = (voce["builder"] as Callable).call()
		t.ok(_trova(nodo, "posto") != null,
				"«%s» dice dove ci si mette e da che parte si guarda" % n)
		nodo.free()


## IL VETRO DEVE ESSERE VETRO. Il modo di sbagliare è documentato e ha già
## colpito: `_mat(..., trans)` non è trasparenza. Qui si pretende una
## lastra GRANDE, con alpha vera e sotto la metà: da una vetrina si deve
## vedere dentro.
func _test_il_vetro_e_vetro(t) -> void:
	var v = BOU.vetrina()
	var area_max := 0.0
	for mi in _tutte_le_mesh(v):
		var mat := (mi as MeshInstance3D).material_override
		if not (mat is StandardMaterial3D):
			continue
		var sm := mat as StandardMaterial3D
		if sm.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
			continue
		if sm.albedo_color.a >= 0.5:
			continue
		var a: AABB = (mi as MeshInstance3D).mesh.get_aabb()
		var s: Vector3 = a.size * (mi as MeshInstance3D).scale
		area_max = maxf(area_max, s.x * s.y)
	t.ok(area_max > 1.0,
			"la vetrina ha una lastra vera e trasparente (%.2f m²): ci si vede dentro"
			% area_max)
	v.free()


## IL CAPPOTTO STA FUORI DAL MANICHINO. Si confrontano le due sagome sui
## due assi: la stoffa deve essere più larga E più spessa del busto, o il
## corpo spunta attraverso il capo — e di profilo la figura si spezza.
func _test_il_manichino_e_vestito(t) -> void:
	var m = BOU.manichino()
	var busto := _trova(m, "busto")
	var stoffa := _trova(m, "stoffa")
	t.ok(busto != null, "il manichino ha un busto")
	t.ok(stoffa != null, "e ha addosso un capo")
	if busto == null or stoffa == null:
		m.free()
		return
	# LE DUE SAGOME VANNO MISURATE NELLO STESSO SPAZIO. Il busto è figlio
	# del corpo, il capo è appeso DENTRO un nodo suo mezzo metro più su:
	# confrontarli ognuno nel proprio locale dice che il cappotto sta
	# sottoterra. Si risale entrambi fino al corpo, che è il padre comune.
	var radice := busto.get_parent() as Node3D
	var ab := _ingombro_in(busto, radice)
	var ac := _ingombro_in(stoffa, radice)
	t.ok(ac.size.x > ab.size.x,
			"il capo è più largo del busto (%.3f > %.3f)" % [ac.size.x, ab.size.x])
	t.ok(ac.size.z > ab.size.z,
			"e più profondo (%.3f > %.3f): niente petto attraverso il bavero"
			% [ac.size.z, ab.size.z])
	# e copre la spalla: un cappotto che comincia alla pancia è una gonna
	var scarto := (ab.position.y + ab.size.y) - (ac.position.y + ac.size.y)
	t.ok(scarto < 0.15,
			"e arriva alla spalla, non alla pancia (%.3f m sotto la spalla)" % scarto)
	m.free()


## I CAPI PENDONO SOTTO L'ASTA e non toccano terra. La quota dell'asta si
## legge dalla geometria, non si riscrive qui: se un domani lo stender
## cambia altezza, il test si adegua da solo invece di mentire.
func _test_i_capi_pendono(t) -> void:
	var s = BOU.stender()
	var capi := _tutti(s, "capo")
	t.ok(capi.size() >= 8, "lo stender è pieno (%d capi)" % capi.size())
	var asta := _trova(s, "asta") as Node3D
	t.ok(asta != null, "lo stender ha un'asta")
	if asta == null:
		s.free()
		return
	# la quota si LEGGE dall'asta, non si riscrive qui: così alzando
	# l'asta il test si adegua invece di restare verde per inerzia
	var q := _ingombro_di(asta).position.y + _ingombro_di(asta).size.y * 0.5
	var alto := -1e9
	var basso := 1e9
	for c in capi:
		var a := _ingombro_di(c)
		alto = maxf(alto, a.position.y + a.size.y)
		basso = minf(basso, a.position.y)
	t.ok(alto < q + 0.08,
			"nessun capo scavalca l'asta (asta %.2f, il più alto a %.2f)" % [q, alto])
	t.ok(basso > 0.15, "e nessuno striscia per terra (il più basso a %.2f m)" % basso)
	t.ok(q - basso > 0.35,
			"e i capi PENDONO davvero (%.2f m di stoffa sotto l'asta)" % (q - basso))
	t.ok(_trova(s, "posto") != null, "lo stender ha il suo posto")
	# e i capi non sono tutti uguali: due lunghezze identiche in fila sono
	# un negozio stampato
	var lunghezze := {}
	for c in capi:
		lunghezze[snappedf(_ingombro_di(c).size.y, 0.01)] = true
	t.ok(lunghezze.size() >= 4,
			"i capi hanno lunghezze diverse (%d misure)" % lunghezze.size())
	s.free()


## LE LETTERE STACCATE SONO IL MARCHIO. Quattro lettere, in ordine, con il
## passo COSTANTE e più largo della lettera stessa: è la crenatura a dire
## «moda». Stringerle non romperebbe niente — cambierebbe solo il negozio
## in una ferramenta, in silenzio.
func _test_linsegna_si_legge(t) -> void:
	var i = BOU.insegna()
	var lettere := _tutti(i, "lettera_")
	t.eq(lettere.size(), 4, "l'insegna ha le sue quattro lettere")
	if lettere.size() < 4:
		i.free()
		return
	var xs := []
	for l in lettere:
		xs.append((l as Node3D).position.x)
	xs.sort()
	var passi := []
	for k in range(1, xs.size()):
		passi.append(float(xs[k]) - float(xs[k - 1]))
	var minimo: float = passi.min()
	var massimo: float = passi.max()
	t.ok(massimo - minimo < 0.005,
			"le lettere sono equidistanti (passo %.3f–%.3f)" % [minimo, massimo])
	# la lettera è alta 0.17 e larga 0.62 di quello: il passo deve stare
	# oltre, o le lettere si toccano
	t.ok(minimo > 0.17 * 0.62,
			"e staccate: passo %.3f > larghezza %.3f" % [minimo, 0.17 * 0.62])
	i.free()


## LA BOUTIQUE PROMETTE LUCE. È l'unico posto del villaggio che di sera
## illumina la strada invece di sé stesso: senza una luce vera resta una
## scatola scura, e la promessa era tutta lì.
func _test_la_luce_ce(t) -> void:
	for nome in ["Vetrina moda", "Faretti"]:
		var voce: Dictionary = _catalogo().get(nome, {})
		if voce.is_empty():
			continue
		var nodo = (voce["builder"] as Callable).call()
		t.ok(_conta_luci(nodo) >= 1, "«%s» accende una luce vera" % nome)
		nodo.free()


func _test_i_nomi_sono_tradotti(t) -> void:
	var tabella := {}
	for parte in L.TABELLE.get("en", []):
		for chiave in parte.tabella():
			tabella[chiave] = true
	for n in PEZZI:
		t.ok(tabella.has(n), "«%s» ha la sua voce inglese" % n)
	t.ok(tabella.has("Boutique"), "e la scheda della categoria è tradotta")
	for p in ECONOMY.SHOP_PIECES:
		if str(p["name"]) == ANCORA:
			t.ok(tabella.has(str(p["desc"])),
					"la didascalia del banco è tradotta")


## Un negozio di vestiti ha bisogno di quattro cose, e se un domani
## qualcuno ne togliesse una smetterebbe di essere un negozio senza che
## nessun test se ne accorga: qualcosa da guardare da fuori, la merce
## esposta in due modi (appesa e piegata), un posto dove provare, e uno
## dove pagare.
func _test_il_negozio_ha_le_sue_cose(t) -> void:
	var per_nome := _catalogo()
	t.ok(per_nome.has("Vetrina moda") and per_nome.has("Insegna boutique"),
			"da fuori si capisce che è un negozio: la vetrina e l'insegna")
	t.ok(per_nome.has("Stender") and per_nome.has("Tavolo piegati"),
			"la merce è esposta nei due modi: appesa e piegata")
	t.ok(per_nome.has("Camerino") and per_nome.has("Specchiera"),
			"e ci si può provare la roba, e guardarsi")
	t.ok(per_nome.has("Cassa boutique"), "e c'è dove pagare")
	t.ok(per_nome.has("Cesto saldi"),
			"e c'è il cesto dei saldi: senza disordine è uno showroom, e in "
			+ "uno showroom non si entra")


# ------------------------------------------------------------------ helper

func _catalogo() -> Dictionary:
	var out := {}
	for v in CAT.items():
		out[str(v["name"])] = v
	return out


func _conta_mesh(n: Node) -> int:
	var c := 0
	if n is MeshInstance3D:
		c += 1
	for f in n.get_children():
		c += _conta_mesh(f)
	return c


func _conta_luci(n: Node) -> int:
	var c := 0
	if n is Light3D:
		c += 1
	for f in n.get_children():
		c += _conta_luci(f)
	return c


## SI CHIAMA COSÌ? Non basta `begins_with`. `add_child(x)` senza
## `force_readable_name` rinomina i doppioni in «@capo@2», «@capo@3» — e
## un test che cerca il prefisso nudo ne trova UNO SOLO su dieci, poi
## dichiara verde uno stender vuoto. La chiocciola va tolta prima.
func _si_chiama(n: Node, prefisso: String) -> bool:
	var s := str(n.name)
	if s.begins_with("@"):
		s = s.substr(1)
	return s.begins_with(prefisso)


func _trova(n: Node, prefisso: String) -> Node:
	if _si_chiama(n, prefisso):
		return n
	for f in n.get_children():
		var r := _trova(f, prefisso)
		if r != null:
			return r
	return null


func _tutti(n: Node, prefisso: String) -> Array:
	var out := []
	if _si_chiama(n, prefisso):
		out.append(n)
	for f in n.get_children():
		out.append_array(_tutti(f, prefisso))
	return out


func _tutte_le_mesh(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for f in n.get_children():
		out.append_array(_tutte_le_mesh(f))
	return out


## L'ingombro di un nodo NELLO SPAZIO DEL SUO GENITORE — la sua stessa
## trasformata compresa. Fermandosi allo spazio locale, un capo appeso
## mezzo metro più in su sembrerebbe sempre al posto giusto.
func _ingombro_di(n: Node) -> AABB:
	return _ingombro_in(n, (n as Node3D).get_parent() as Node3D)


## L'ingombro di un nodo nello spazio di un ANTENATO qualunque: l'unico
## modo onesto di confrontare due sagome che stanno a profondità diverse.
func _ingombro_in(n: Node, radice: Node3D) -> AABB:
	var tr := _trasformata_relativa(n as Node3D, radice)
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return tr * (n as MeshInstance3D).mesh.get_aabb()
	return tr * _ingombro(n as Node3D)


func _ingombro(n: Node3D) -> AABB:
	var out := AABB()
	var primo := true
	for mi in _tutte_le_mesh(n):
		var a: AABB = (mi as MeshInstance3D).mesh.get_aabb()
		var mondo := _trasformata_relativa(mi, n) * a
		if primo:
			out = mondo
			primo = false
		else:
			out = out.merge(mondo)
	return out


func _trasformata_relativa(nodo: Node3D, radice: Node3D) -> Transform3D:
	var tr := Transform3D.IDENTITY
	var cur := nodo
	while cur != null and cur != radice:
		tr = cur.transform * tr
		cur = cur.get_parent() as Node3D
	return tr
