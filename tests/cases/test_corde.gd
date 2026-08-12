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


## UN CIELO FINTO, con la sola porta che il villaggio usa per chiedergli
## il vento: il gruppo «weather» e il metodo `forza_del_vento` (e' il
## contratto di `Rimbalzello._vento()`, e adesso anche delle corde).
class FintoCielo extends Node3D:
	var _vento := 1.0

	func forza_del_vento(_stato: String, _nevica: bool, _nebbia: bool) -> float:
		return _vento


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
	_test_vento_dal_cielo(t)
	_test_nessuna_porta_murata(t)


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
	# le Lucine rifatte appendono UN nodo per lampadina (portalampada,
	# vetro e filamento stanno dentro lo stesso contenitore): prima erano
	# due nodi per lampadina — l'attacco e il bulbo — e per questo la
	# soglia era dieci. Il numero segue la LUNGHEZZA del filo, che è la
	# promessa del sistema (vedi test_festoni).
	t.ok(appesi.size() >= 5, "le lucine dichiarano le loro lampadine appese")
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


## IL VENTO DEVE ARRIVARE DAL CIELO — e questo test esiste perche' per
## due anni non ci e' arrivato, con la suite verde.
##
## `_forza_vento()` chiedeva il vento a
## `RenderingServer.global_shader_parameter_get("vento_forza")`. Fuori
## dall'editor Godot fa fallire quella funzione apposta: tornava `null`,
## e le corde ricevevano SEMPRE 1.0 — il vento del sereno — anche col
## temporale, che il cielo tira a 1.8. E il guasto era MUTO headless per
## due ragioni indipendenti, che e' il motivo per cui va provato COSI':
## il renderer fittizio non ha quel guardrail (nessun errore da vedere),
## e 1.0 e' proprio il valore giusto del sereno (nessun numero sbagliato
## da vedere). Serve un cielo che dica un numero DIVERSO da 1.0, e poi
## guardare se le corde lo sentono addosso.
##
## Si misura il COMPORTAMENTO — quanto si scosta la pancia della corda —
## non la risposta della funzione: una `_forza_vento` giusta collegata a
## un `passo` che la butta via passerebbe un test di lettura.
func _test_vento_dal_cielo(t) -> void:
	var cielo := FintoCielo.new()
	t.stage(cielo)
	cielo.add_to_group("weather")

	var sereno: Array = _agita(t, 1.0)
	var tempesta: Array = _agita(t, 1.8)
	t.almost(float(sereno[1]), 1.0, "col sereno le corde sentono il vento del sereno", 0.001)
	t.almost(float(tempesta[1]), 1.8, "col temporale sentono il vento del temporale", 0.001)
	# La spinta va col QUADRATO della forza (`1.1 * forza * forza` in
	# `passo`): fra 1.0 e 1.8 ci sono 3.24 volte. La soglia sta a 2.0,
	# cioe' sotto il misurato ma abbondantemente sopra l'1.0 che darebbe
	# una corda sorda: e' la fascia in cui il test dice qualcosa senza
	# ridiventare rosso se un giorno si ritocca la curva del vento.
	var quanto := float(tempesta[0]) / maxf(float(sereno[0]), 1e-9)
	t.ok(quanto > 2.5,
			"col temporale la corda si scosta molto di piu' (x%.2f)" % quanto)

	# E SENZA CIELO le corde respirano lo stesso, con la brezza del
	# sereno: il diorama del titolo, il bosco e i banchi non hanno un
	# Weather, e una corda che si pianta li' e' un guasto peggiore di
	# quello che questo test sorveglia.
	cielo.remove_from_group("weather")
	var orfano: Array = _agita(t, -1.0)
	t.almost(float(orfano[1]), 1.0, "senza cielo si risponde la brezza del sereno", 0.001)
	t.almost(float(orfano[0]), float(sereno[0]),
			"e la corda si scosta esattamente come col sereno", 0.0001)


## Un gestore nuovo, una corda vera nuova, e novanta passi di vento: si
## torna quanto la pancia si e' scostata NELLA DIREZIONE DEL VENTO, e che
## vento ha visto il gestore. Corda e gestore sono NUOVI a ogni chiamata:
## due misure che partono da stati diversi non sono confrontabili.
func _agita(t, vento_del_cielo: float) -> Array:
	for n in (t.tree() as SceneTree).get_nodes_in_group("weather"):
		if n is FintoCielo:
			(n as FintoCielo)._vento = maxf(vento_del_cielo, 0.0)
	# IL SOGGETTO E' UN FESTONE, e la scelta e' misurata. Le «Lucine» del
	# catalogo hanno una cordicella corta e tesa che sente il vento al
	# 50%: fra sereno e temporale si scostava di 1.88 volte invece delle
	# 3.24 della fisica, perche' una corda tesa e corta satura — e con
	# quel soggetto la soglia del test avrebbe dovuto scendere sotto il
	# doppio, cioe' diventare quasi indistinguibile da «zero vento». La
	# campata da tre metri e' invece la corda che il vento ha il permesso
	# di muovere davvero (`vento` = 1.0), ed e' anche quella che si vede
	# ondeggiare nel provino.
	var pezzo = t.stage(CAT.festone(Vector3(-1.5, 2.4, 0.0), Vector3(1.5, 2.4, 0.0),
			CAT.FESTONE_BULBI, 20260812))
	var corda: MeshInstance3D = _corde_di(pezzo)[0]
	var gestore = t.stage(VIVE.new())
	gestore.registra(corda)
	var stato: Dictionary = gestore._stato_di(corda)
	if stato.is_empty():
		t.ok(false, "il gestore non ha registrato la campata")
		return [0.0, 1.0]
	# LA FASE SI FISSA. `registra` la ricava dall'instance_id del nodo
	# («orologi incommensurabili»: due corde vicine non ondeggiano in
	# sincrono), quindi cambia a ogni corda costruita — e due misure con
	# turbolenze sfasate non sono confrontabili al millimetro. Qui la si
	# azzera, cosi' le tre corse differiscono per UNA cosa sola: il vento.
	stato["fase"] = 0.0

	# SI MISURA LUNGO L'ASSE DEL VENTO, e dopo che la corda si e'
	# assestata. Il primo mezzo secondo la pancia SCENDE (la posa di
	# riposo nasce con dieci giri di vincoli, il gestore ne fa sei: la
	# corda cede ancora un poco sotto il proprio peso), e quello
	# spostamento — cinque centimetri, tutto in Y — e' identico col
	# sereno e col temporale: misurando la distanza in linea d'aria dalla
	# posa seppelliva il vento dentro la gravita' e i due venti
	# risultavano uguali all'1% (misurato: x1.03). Il vento parte lungo
	# +X (`_dir_vento` nasce a zero), la gravita' non ha X: proiettare
	# sulla X separa le due cose senza doverle sottrarre.
	var riposo: Vector3 = FISICA.campiona(corda.get_meta("posa"), 0.5)
	for _k in 90:
		gestore.passo(1.0 / 60.0)
	var spinta := 0.0
	for _k in 60:
		gestore.passo(1.0 / 60.0)
		spinta += (FISICA.campiona(stato["punti"], 0.5) as Vector3).x - riposo.x
	return [spinta / 60.0, float(gestore._forza_vento())]


## LA PORTA MURATA NON SI RIAPRE. Questo e' un controllo sul SORGENTE, ed
## e' l'eccezione che il progetto si concede quando il guasto non ha
## nessuna traccia headless: `global_shader_parameter_get` fuori
## dall'editor non stampa niente in `--headless` (renderer fittizio) e
## torna proprio il valore del sereno, quindi in un banco a occhi chiusi
## e' indistinguibile dal codice giusto. Con la finestra aperta invece
## costa un ERROR per frame — 3600 al minuto, 55 µs l'uno, sei righe di
## log a testa.
##
## I COMMENTI SI TOLGONO PRIMA DI CERCARE: la nota che spiega il guasto
## nomina la funzione, e un controllo ingenuo resterebbe rosso per colpa
## della sua stessa spiegazione (o, peggio, verrebbe scritto in modo da
## non nominarla mai — cioe' cancellando la memoria del difetto).
func _test_nessuna_porta_murata(t) -> void:
	var f := FileAccess.open("res://scenes/world/CordeVive.gd", FileAccess.READ)
	t.ok(f != null, "CordeVive.gd si legge")
	if f == null:
		return
	var vive := 0
	for riga in f.get_as_text().split("\n"):
		var nuda := (riga as String).strip_edges()
		if nuda.begins_with("#"):
			continue
		if nuda.contains("global_shader_parameter_get"):
			vive += 1
	f.close()
	t.eq(vive, 0,
			"CordeVive non chiede piu' il vento al RenderingServer (righe vive: %d)" % vive)


func _corde_di(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and n.has_meta("corda"):
		out.append(n)
	for f in n.get_children():
		out.append_array(_corde_di(f))
	return out
