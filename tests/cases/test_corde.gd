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
const METEO := preload("res://scenes/world/Weather.gd")
const CAT := preload("res://scenes/build/BuildCatalog.gd")
const CHIESA := preload("res://scenes/build/BuildChiesa.gd")


## Un cielo finto: al gestore delle corde il cielo serve per una cosa
## sola, dire quanto tira il vento. Se il numero arriva alle corde, si sa
## da dove è passato.
class MeteoFinto extends Node3D:
	var forza := 1.0
	func vento() -> float:
		return forza


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
	_test_il_vento_viene_dal_cielo(t)
	_test_il_cielo_arriva_alla_corda(t)
	_test_la_fase_viene_dal_posto(t)


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


## DA DOVE VIENE IL VENTO. Da `Weather.vento()`, che è la sola casa del
## numero — non da `RenderingServer.global_shader_parameter_get()`, che è
## una lettura da editor: a runtime lascia un errore per FOTOGRAMMA e non
## risponde (misurato nel MainLevel vero: torna `<null>` col cielo a
## 1.786). Le corde ci stavano appese, e restavano nella brezza del sereno
## anche sotto l'acquazzone.
func _test_il_vento_viene_dal_cielo(t) -> void:
	var gestore = VIVE.new()
	var cielo := MeteoFinto.new()
	gestore._weather = cielo

	cielo.forza = 1.8                       # l'acquazzone
	t.almost(float(gestore._forza_vento()), 1.8, "il gestore prende il vento dal cielo")
	cielo.forza = 0.45                      # la nebbia: l'aria si ferma
	t.almost(float(gestore._forza_vento()), 0.45,
			"…e lo risente appena il cielo cambia")

	# la leva dei test resta sopra a tutto
	gestore.vento_forzato = 2.2
	t.almost(float(gestore._forza_vento()), 2.2,
			"il vento forzato dei test scavalca il cielo")
	gestore.vento_forzato = -1.0

	# e senza cielo (test, provini, diorama del titolo) resta la brezza del
	# sereno — che a dirla è comunque Weather, non un 1.0 ricopiato qui
	gestore._weather = null
	t.almost(float(gestore._forza_vento()),
			METEO.forza_del_vento("clear", false, false),
			"senza cielo resta la brezza del sereno")

	# (che nessuno riapra la fonte dal server di rendering lo tiene chiuso
	# test_vento.gd, che guarda TUTTI i sorgenti: qui si prova il
	# comportamento, lì si sorveglia la porta)
	cielo.free()
	gestore.free()


## IL NUMERO ARRIVA DAVVERO ALLA CORDA. Non basta che `_forza_vento()`
## torni 1.8: se il valore non entrasse nella fisica, la corda si
## muoverebbe uguale sotto l'acquazzone e nella nebbia — ed è esattamente
## il guasto che un cambio di fonte può introdurre senza far fallire
## niente.
func _test_il_cielo_arriva_alla_corda(t) -> void:
	var per_nome := {}
	for v in CAT.items():
		per_nome[str(v["name"])] = v
	var mosse: Array = []
	for forza: float in [0.45, 1.8]:        # nebbia, acquazzone
		var gestore = VIVE.new()
		var cielo := MeteoFinto.new()
		cielo.forza = forza
		gestore._weather = cielo
		var lucine = t.stage((per_nome["Lucine"]["builder"] as Callable).call())
		var corda: MeshInstance3D = _corde_di(lucine)[0]
		gestore.registra(corda)
		var prima: Vector3 = FISICA.campiona(corda.get_meta("posa"), 0.5)
		for _k in 90:
			gestore.passo(1.0 / 60.0)
		var stato: Dictionary = gestore._stato_di(corda)
		mosse.append((FISICA.campiona(stato["punti"], 0.5) as Vector3).distance_to(prima))
		cielo.free()
		gestore.free()
	# LA SOGLIA È MISURATA, non scelta a occhio. Con la corda sana il
	# rapporto vale 2.063 e non balla di un bit (la fase della corda viene
	# dal POSTO: vedi CordeVive._fase_di — prima veniva dal contatore delle
	# istanze e questa riga era rossa una corsa su quattro, con 0.0063 m
	# contro 0.0042 m, cioè esattamente 1.5). Il residuo vero è la fase:
	# girandola per tutto il cerchio il rapporto scende al minimo a 1.488.
	# Il GUASTO da prendere — il numero del cielo che non arriva alla
	# fisica — dà 1.0000 esatto, perché le due misure diventano la stessa.
	# 1.30 sta in mezzo ai due numeri misurati, con margine da tutte e due
	# le parti.
	t.ok(mosse[1] > mosse[0] * 1.30,
			"la corda sente l'acquazzone più della nebbia (%.4f m contro %.4f m)"
					% [mosse[1], mosse[0]])


## LA FASE DELLA CORDA NON È UN CONTATORE. È ciò che tiene due corde
## vicine fuori sincrono, e per anni è venuta da `get_instance_id()`: un
## contatore di processo, che cambia con la storia delle allocazioni.
## Effetto: la stessa corda, nello stesso villaggio, ondeggiava diversa a
## ogni avvio — niente foto del catalogo rifacibile, niente provino
## ripetibile, e il caso qui sopra rosso una volta su quattro senza che
## niente fosse cambiato.
##
## Qui si prova il COMPORTAMENTO, non la formula: la stessa corda nello
## stesso posto deve dare la stessa fase anche dopo che il processo ha
## allocato altro (è quello che un contatore non sa fare), e due corde in
## posti diversi devono continuare a darne di diverse.
func _test_la_fase_viene_dal_posto(t) -> void:
	var per_nome := {}
	for v in CAT.items():
		per_nome[str(v["name"])] = v
	var b: Callable = per_nome["Lucine"]["builder"] as Callable

	# le QUATTRO CELLE di un quadrato, più la prima rifatta in fondo:
	# vicine come non possono esserlo di più, e la ripetizione dice se la
	# fase sopravvive alle allocazioni che ci sono state in mezzo
	var celle: Array = [Vector3.ZERO, Vector3(2, 0, 0), Vector3(0, 0, 2),
			Vector3(2, 0, 2), Vector3.ZERO]
	var fasi: Array = []
	for dove: Vector3 in celle:
		# fra una corda e l'altra il processo alloca: con la fase presa dal
		# contatore delle istanze, la prima e l'ultima NON coinciderebbero
		var zavorra: Array = []
		for _z in 40:
			zavorra.append(Node3D.new())
		var pezzo := t.stage(b.call()) as Node3D
		pezzo.global_position = dove
		var gestore = VIVE.new()
		gestore.registra(_corde_di(pezzo)[0])
		fasi.append(float(gestore._corde[0]["fase"]))
		gestore.free()
		for z in zavorra:
			z.free()

	t.almost(fasi[0], fasi[4],
			"la stessa corda nello stesso posto ritrova la sua fase")
	# «diverse» non basta: a un grado di scarto due corde ondeggiano
	# insieme a occhio. La soglia è MISURATA: su 36 lucine piantate a due
	# metri di passo, fra le 110 coppie di vicine (entro tre metri) la più
	# somigliante sta a 0.86 rad — e le quattro celle qui sopra sono il
	# caso peggiore di quella misura. 0.5 lascia margine senza scendere
	# dove due corde parrebbero la stessa corda.
	for i1 in 4:
		for i2 in range(i1 + 1, 4):
			var d: float = absf(fasi[i1] - fasi[i2])
			d = minf(d, TAU - d)
			t.ok(d > 0.5, "due lucine in celle vicine restano fuori sincrono (%.3f rad)" % d)

	# e le due sorelle dell'altalena, che il posto ce l'hanno identico: a
	# distinguerle restano i loro attacchi, distanti 32 cm. Questa riga
	# non è una formalità — rimettendo il vecchio contatore per vedere se
	# il caso diventava rosso è venuto fuori che le due corde del
	# seggiolino stavano a 0.063 rad, quattro gradi: ondeggiavano
	# INSIEME, e nessuno se n'era accorto.
	var alt := t.stage((per_nome["Altalena"]["builder"] as Callable).call()) as Node3D
	var g2 = VIVE.new()
	for c in _corde_di(alt):
		g2.registra(c)
	t.eq(g2._corde.size(), 2, "l'altalena dichiara le sue due corde")
	if g2._corde.size() == 2:
		var ds: float = absf(float(g2._corde[0]["fase"]) - float(g2._corde[1]["fase"]))
		ds = minf(ds, TAU - ds)
		t.ok(ds > 0.3,
				"le due corde dell'altalena non dondolano insieme (%.3f rad)" % ds)
	g2.free()


func _corde_di(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and n.has_meta("corda"):
		out.append(n)
	for f in n.get_children():
		out.append_array(_corde_di(f))
	return out
