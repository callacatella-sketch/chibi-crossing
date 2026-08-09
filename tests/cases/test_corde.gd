extends RefCounted
## LE CORDE VIVE — la fisica, e le corde che i pezzi dichiarano.
##
## Si prova il COMPORTAMENTO, a occhi chiusi: la corda si assesta e i
## tratti restano lunghi uguali (è l'unica legge che ha); il vento la
## sposta e, cessato il vento, torna; la mano la scosta; il sedile
## dell'altalena resta appeso alle sue due corde. E si prova il
## CABLAGGIO: i pezzi col filo (lucine, altalena, stendino, ponticello,
## campanile) dichiarano corde vere, con gli appesi che stanno SULLA
## corda — non su una formula parallela.

const FISICA := preload("res://scenes/world/CordaFisica.gd")
const VIVE := preload("res://scenes/world/CordeVive.gd")
const CAT := preload("res://scenes/build/BuildCatalog.gd")
const CHIESA := preload("res://scenes/build/BuildChiesa.gd")


func run(t) -> void:
	_test_si_assesta(t)
	_test_tratti_uguali(t)
	_test_vento_e_ritorno(t)
	_test_la_mano(t)
	_test_corda_libera(t)
	_test_altalena(t)
	_test_i_pezzi_dichiarano(t)
	_test_appesi_sulla_corda(t)
	_test_gestore_headless(t)


## La corda ferma: pancia sotto i capi, simmetrica, coi capi al loro posto.
func _test_si_assesta(t) -> void:
	var a := Vector3(-0.5, 1.0, 0)
	var b := Vector3(0.5, 1.0, 0)
	var punti: Array = FISICA.riposo(a, b, 0.2, 11)
	t.eq(punti.size(), 11, "la corda ha i suoi punti")
	t.ok((punti[0] as Vector3).distance_to(a) < 0.001, "il capo A è ancorato")
	t.ok((punti[10] as Vector3).distance_to(b) < 0.001, "il capo B è ancorato")
	var centro: Vector3 = punti[5]
	t.ok(centro.y < 0.95, "la pancia scende sotto i capi (y=%.3f)" % centro.y)
	var sinistra: Vector3 = punti[2]
	var destra: Vector3 = punti[8]
	t.almost(sinistra.y, destra.y, "e pende simmetrica", 0.02)


## L'unica legge della corda: ogni tratto resta lungo uguale.
func _test_tratti_uguali(t) -> void:
	var a := Vector3(0, 1.5, 0)
	var b := Vector3(0.8, 1.4, 0.2)
	var punti: Array = FISICA.riposo(a, b, 0.15, 10)
	var seg: float = FISICA.lunghezza(a, b, 0.15) / 9.0
	var peggio := 0.0
	for i in 9:
		var d: float = (punti[i] as Vector3).distance_to(punti[i + 1])
		peggio = maxf(peggio, absf(d - seg) / seg)
	t.ok(peggio < 0.02,
			"dopo l'assestamento i tratti sono uguali (errore max %.1f%%)" % (peggio * 100.0))


## Il vento la sposta di lato; senza vento, torna dov'era.
func _test_vento_e_ritorno(t) -> void:
	var a := Vector3(-0.5, 1.5, 0)
	var b := Vector3(0.5, 1.5, 0)
	var punti: Array = FISICA.riposo(a, b, 0.2, 11)
	var quiete_z: float = (punti[5] as Vector3).z
	var prev: Array = punti.duplicate()
	var ancore := {0: a, 10: b}
	var seg: float = FISICA.lunghezza(a, b, 0.2) / 10.0
	for k in 120:
		FISICA.soffia(punti, prev, 1.0 / 60.0, Vector3(0, 0, 6.0),
				float(k) / 60.0, 0.0)
		FISICA.passo(punti, prev, 1.0 / 60.0, Vector3(0, -9.8, 0))
		FISICA.vincola(punti, seg, ancore)
	var spinta: float = (punti[5] as Vector3).z - quiete_z
	t.ok(spinta > 0.03, "il vento ha spostato la pancia (%.3f m)" % spinta)
	for _k in 240:
		FISICA.passo(punti, prev, 1.0 / 60.0, Vector3(0, -9.8, 0))
		FISICA.vincola(punti, seg, ancore)
	var residuo: float = absf((punti[5] as Vector3).z - quiete_z)
	t.ok(residuo < 0.01,
			"cessato il vento la corda torna (residuo %.4f m)" % residuo)


## La mano: i punti dentro la sfera vengono spinti fuori.
func _test_la_mano(t) -> void:
	var a := Vector3(-0.5, 1.0, 0)
	var b := Vector3(0.5, 1.0, 0)
	var punti: Array = FISICA.riposo(a, b, 0.2, 11)
	var pancia: Vector3 = punti[5]
	FISICA.spingi(punti, pancia + Vector3(0, 0, -0.1), 0.3)
	t.ok((punti[5] as Vector3).z > pancia.z + 0.02,
			"la corda si scosta dalla mano")


## La corda che pende da un capo solo (la campana): il fondo sta sotto
## l'ancora, e la lunghezza si conserva.
func _test_corda_libera(t) -> void:
	var a := Vector3(0, 2.4, 0)
	var punti: Array = FISICA.riposo_libera(a, 1.9, 12)
	var prev: Array = punti.duplicate()
	var seg := 1.9 / 11.0
	for _k in 120:
		FISICA.passo(punti, prev, 1.0 / 60.0, Vector3(0, -9.8, 0))
		FISICA.vincola(punti, seg, {0: a})
	var fondo: Vector3 = punti[11]
	t.almost(fondo.y, a.y - 1.9, "pende per tutta la sua lunghezza", 0.03)
	var lung := 0.0
	for i in 11:
		lung += (punti[i] as Vector3).distance_to(punti[i + 1])
	t.almost(lung, 1.9, "e la lunghezza si conserva", 0.02)


## L'altalena: il vincolo del sedile tiene i due fondi alla loro distanza.
func _test_altalena(t) -> void:
	var pa := Vector3(-0.16, 0.6, 0.0)
	var pb := Vector3(0.20, 0.63, 0.05)
	var stretta: Array = FISICA.lega(pa, pb, 0.32)
	t.almost((stretta[0] as Vector3).distance_to(stretta[1]), 0.32,
			"il sedile tiene le corde alla sua larghezza", 0.001)
	var mezzo_prima := (pa + pb) * 0.5
	var mezzo_dopo: Vector3 = ((stretta[0] as Vector3) + (stretta[1] as Vector3)) * 0.5
	t.ok(mezzo_prima.distance_to(mezzo_dopo) < 0.001,
			"e la correzione è equa: il centro non si sposta")


## I pezzi col filo dichiarano corde vive, con meta completo.
func _test_i_pezzi_dichiarano(t) -> void:
	var attese := {"Lucine": 1, "Altalena": 2, "Stendino": 1, "Ponticello": 3}
	var per_nome := {}
	for v in CAT.items():
		per_nome[str(v["name"])] = v
	for nome in attese:
		var nodo = (per_nome[nome]["builder"] as Callable).call()
		var corde := _corde_di(nodo)
		t.eq(corde.size(), int(attese[nome]),
				"«%s» dichiara le sue corde vive (%d)" % [nome, corde.size()])
		for c in corde:
			var m: Dictionary = c.get_meta("corda", {})
			t.ok(not m.is_empty(), "«%s»: la corda ha il suo meta" % nome)
			t.ok(c.is_in_group("corda_viva"), "«%s»: ed è nel gruppo" % nome)
			t.ok(c.mesh is ImmediateMesh and c.mesh.get_surface_count() > 0,
					"«%s»: la posa di riposo è già scolpita" % nome)
		nodo.free()
	# e la campana della chiesa
	var campanile = null
	for v2 in CAT.items():
		if str(v2["name"]) == "Campanile":
			campanile = (v2["builder"] as Callable).call()
	if campanile != null:
		var corde2 := _corde_di(campanile)
		t.ok(corde2.size() >= 1, "il campanile ha la corda della campana viva")
		if corde2.size() >= 1:
			t.ok(bool((corde2[0].get_meta("corda") as Dictionary).get("libera", false)),
					"e pende da un capo solo")
		campanile.free()


## Gli appesi stanno SULLA posa vera della corda, non su una formula.
func _test_appesi_sulla_corda(t) -> void:
	var per_nome := {}
	for v in CAT.items():
		per_nome[str(v["name"])] = v
	var lucine = (per_nome["Lucine"]["builder"] as Callable).call()
	var corda: MeshInstance3D = _corde_di(lucine)[0]
	var posa: Array = corda.get_meta("posa")
	var m: Dictionary = corda.get_meta("corda")
	var appesi: Array = m.get("appesi", [])
	t.ok(appesi.size() >= 10, "le lucine dichiarano lampadine e attacchi appesi")
	var peggio := 0.0
	for ap in appesi:
		var seguace: Node3D = corda.get_node_or_null(str(ap["path"]))
		t.ok(seguace != null, "l'appeso «%s» esiste" % ap["path"])
		if seguace == null:
			continue
		var atteso: Vector3 = FISICA.campiona(posa, float(ap["t"])) \
				+ Vector3(0, -float(ap["giu"]), 0)
		peggio = maxf(peggio, seguace.position.distance_to(atteso))
	t.ok(peggio < 0.005,
			"e ogni appeso sta sulla corda (scarto max %.4f m)" % peggio)
	lucine.free()


## Il gestore, a occhi chiusi: registra una corda vera, fa passi
## espliciti col vento forzato, e la corda si muove e resta ancorata.
func _test_gestore_headless(t) -> void:
	var gestore = VIVE.new()
	gestore.vento_forzato = 2.2
	var per_nome := {}
	for v in CAT.items():
		per_nome[str(v["name"])] = v
	# IN ALBERO, non solo costruite. Il gestore chiede la trasformata
	# GLOBALE della corda a ogni passo, e un Node3D fuori dall'albero non
	# ce l'ha: uscivano novanta «Condition "!is_inside_tree()" is true»
	# (uno per passo) che non facevano fallire niente ma sporcavano il log
	# della suite — e in un log sporco gli errori VERI non si vedono, che
	# e' il modo in cui questo progetto ha gia' perso dei difetti.
	# `t.stage` li libera da solo a fine caso.
	var lucine = t.stage((per_nome["Lucine"]["builder"] as Callable).call())
	var corda: MeshInstance3D = _corde_di(lucine)[0]
	gestore.registra(corda)
	var prima: Vector3 = FISICA.campiona(corda.get_meta("posa"), 0.5)
	for _k in 90:
		gestore.passo(1.0 / 60.0)
	# lo stato vivo del gestore: la pancia si è mossa, i capi no
	var stato: Dictionary = gestore._stato_di(corda)
	t.ok(not stato.is_empty(), "il gestore ha registrato la corda")
	if not stato.is_empty():
		var punti: Array = stato["punti"]
		var mossa: float = (FISICA.campiona(punti, 0.5) as Vector3).distance_to(prima)
		t.ok(mossa > 0.005, "col vento la corda si muove (%.3f m)" % mossa)
		var m: Dictionary = corda.get_meta("corda")
		t.ok((punti[0] as Vector3).distance_to(m["a"]) < 0.001,
				"e i capi restano ancorati")
		# e le lampadine hanno seguito il filo
		var ap: Dictionary = m["appesi"][3]
		var seguace: Node3D = corda.get_node_or_null(str(ap["path"]))
		var atteso: Vector3 = FISICA.campiona(punti, float(ap["t"])) \
				+ Vector3(0, -float(ap["giu"]), 0)
		t.ok(seguace.position.distance_to(atteso) < 0.005,
				"le lampadine seguono il filo che si muove")
	gestore.free()


func _corde_di(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and n.has_meta("corda"):
		out.append(n)
	for f in n.get_children():
		out.append_array(_corde_di(f))
	return out
