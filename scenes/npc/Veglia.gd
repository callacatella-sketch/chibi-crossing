extends Node3D

## LA VEGLIA — quello che produce «fare la guardia».
##
## IL DIFETTO CHE CHIUDE: nel registro dei lavori, «Fare la guardia»
## costava rancore come gli altri (fatica +0.16, noia +0.20, e tradisce i
## sogni di artisti e giardinieri) ma non produceva NIENTE: nel match di
## `Lavori._produzione_del_giorno()` il suo ramo non c'era. Era l'unico
## lavoro che si poteva solo perderci.
##
## COSA PRODUCE, E PERCHÉ ERA GIÀ SCRITTO NEL CODICE.
## In `Animo.gd` ci sono sei drive. Cinque hanno padroni ovunque nel
## gioco. `sicurezza` no: in tutto il repository l'unica riga che la
## toccava era
##     "guardia": { … "sicurezza": -0.05},
## cioè la guardia SPENDEVA una risorsa che nessun altro sapeva né
## spendere né rimettere in circolo — e che quindi restava inchiodata a 1
## per tutti, rendendo quel -0.05 invisibile. Il prodotto era già lì:
## mancava il destinatario. **Chi veglia paga la propria quiete per
## comprare quella di tutti gli altri.**
##
## COME SI VEDE (perché un guadagno invisibile non è un guadagno).
## Al calare della sera, prima che gli altri vadano a letto, chi ha
## l'incarico esce a fare la RONDA: passa davanti alle case e accende una
## lanterna di carta a ogni tappa. Quante ne accende lo decide la stessa
## `Lavori.resa()` che regola legna e piatti — resa piena: villaggio tutto
## illuminato; svogliato: metà villaggio al buio; dal rifiuto in poi: buio
## pesto. **La scala della ribellione diventa leggibile a colpo d'occhio,
## di notte, senza aprire un pannello.** All'alba le lanterne si spengono.
##
## IL BUIO NON È MAI UNA PUNIZIONE. Chi dorme senza una luce vicina perde
## un pizzico di sicurezza, ma con un pavimento (`SICUREZZA_MINIMA`) che
## da solo non basta MAI a far salire la scala della ribellione: al
## massimo qualcuno sbadiglia e dice che è stata una notte buia. E la
## strada che non costa rancore a nessuno esiste già ed è in vendita: un
## Lampione conta esattamente come una lanterna della ronda.
##
## Le decisioni sono funzioni PURE (chi è al buio, dove passa la ronda):
## si provano headless in tests/cases/test_veglia.gd.

const LANTERNE := preload("res://scenes/world/Lanterne.gd")

# --- i numeri, tutti qui: il rubinetto e il dono si tarano INSIEME ---
## Quanto lontano arriva il conforto di una luce accesa.
const RAGGIO_LUCE := 6.0
## Quanto pesa dormire al buio (contro un rientro passivo di +0.09/giorno).
const BUIO_SICUREZZA := 0.10
## …ma mai sotto questo pavimento: il buio non deve MAI, da solo, portare
## qualcuno alla ribellione. Al massimo lo rende un po' più stanco.
const SICUREZZA_MINIMA := 0.45
## Quanto dona a ciascun altro residente una notte vegliata, a resa piena.
const VEGLIA_SICUREZZA := 0.14
## Quanto cresce il legame verso chi ha vegliato (Villaggio.lega).
const VEGLIA_CREDITO := 0.05
## Il grazie del mattino, addosso a chi ha fatto il turno.
const VEGLIA_STIMA := 0.06
## L'ora della ronda: prima che gli altri vadano a dormire (0.80).
const ORA_RONDA := 0.76
## E l'ora in cui le lanterne si spengono.
const ORA_ALBA := 0.29
## Quanto passa fra una tappa e l'altra del giro.
const PASSO_RONDA := 9.0

# --- il TURNO DI GIORNO: la garitta -----------------------------------
## Se il villaggio ha una Guardiola, chi è di guardia non aspetta la sera
## girando a vuoto: passa la giornata al suo posto, DENTRO la garitta
## (il nodo "PostoGuardia" che la guardiola porta con sé). La finestra
## dell'orario lascia fuori il risveglio e la sera del falò; il passo è
## più lungo della presa di `manda` (45 s), così fra un richiamo e
## l'altro la guardia ha qualche boccata d'aria — sta di posto, non in
## castigo.
const ORA_TURNO_DA := 0.34
const ORA_TURNO_A := 0.72
const PASSO_TURNO := 75.0

# le lanterne accese stanotte: EFFIMERE — mai salvate, mai in
# un gruppo persistable, liberate all'alba (il volto vivo scandaglia il
# gruppo "luce_calda" a ogni frame: una lanterna che sopravvive alla notte
# è una perdita di memoria e un costo che cresce ogni sera)
var _lanterne: Array = []
var _t := 0.0
var _ronda_fatta_oggi := false
var _lanterne_accese := 0
var _guardia := ""          # la LABEL di chi ha vegliato stanotte
var _resa := 0.0
var _tappe: Array = []
# le PORTE della ronda, nello stesso ordine delle prime tappe: l'indice di
# tappa `i < _porte.size()` mappa esattamente su `_porte[i]`. Serve al
# mattino per sapere DI CHI era l'ultima porta illuminata — un dato che
# `_tappe` (sole posizioni) non porta con sé.
var _porte: Array = []
var _tappa_i := 0
var _passo_cd := 0.0
var _turno_cd := 0.0        # il prossimo richiamo alla garitta

var _daynight: Node3D
var _visitors: Node
var _build: Node3D
var _lavori: Node


func _ready() -> void:
	add_to_group("veglia")
	(func() -> void:
		_daynight = get_node_or_null("../DayNight")
		_visitors = get_node_or_null("../Visitors")
		_build = get_tree().get_first_node_in_group("build_system")
		_lavori = get_tree().get_first_node_in_group("lavori")
	).call_deferred()


# ============================================================ le decisioni (pure)

## Questo posto è al buio? `luci` sono le posizioni delle luci accese.
## PURA: entra una posizione, esce un sì o un no.
static func al_buio(pos: Vector3, luci: Array, raggio := RAGGIO_LUCE) -> bool:
	for l in luci:
		var p: Vector3 = l
		if Vector2(p.x - pos.x, p.z - pos.z).length() <= raggio:
			return false
	return true


## Le tappe della ronda, nell'ordine in cui la guardia le accende: prima
## le case di chi dorme (è per loro che si veglia), poi i luoghi che il
## villaggio vive di sera. `quante` viene dalla resa: chi è svogliato si
## ferma a metà giro, e il villaggio resta mezzo al buio.
static func tappe_della_ronda(case: Array, ritrovi: Array, quante: int) -> Array:
	var out: Array = []
	for p in case:
		if out.size() >= quante:
			return out
		out.append(p)
	for p in ritrovi:
		if out.size() >= quante:
			return out
		out.append(p)
	return out


## SU CHI HA VEGLIATO, stanotte. Cammina ALL'INDIETRO sulle porte
## effettivamente raggiunte e ritorna il NOME della prima che risulta al
## buio senza la ronda: l'ultima lanterna della notte, quella per cui la
## guardia è rimasta alzata — quella che poteva saltare e non ha saltato.
##
## PERCHÉ UNA SOLA, E PERCHÉ L'ULTIMA. Il libro mastro degli affetti
## riceveva una riga identica da chi era di guardia verso OGNI residente:
## misurato su 240 giorni, il conto verso il cuoco cresceva 2.6 volte più
## che verso chiunque altro, la prima coppia nasceva al giorno 3 ed era
## sempre quella, e nessun'altra poteva più formarsi — un solo incarico
## assegnato sterilizzava gli affetti dell'intero villaggio. Anche
## scriverla a TUTTI i «salvati» rifà lo stesso pareggio un piano sotto.
## Una riga sola, e a scegliere il destinatario è dove il giocatore ha
## (non) messo le luci: chi illumina una casa toglie quella porta dal giro.
##
## `luci_costruite` sono SOLO le luci del villaggio costruito: le lanterne
## della ronda renderebbero ogni porta illuminata e la risposta sarebbe
## sempre "". Ritorna "" anche quando il villaggio è già tutto illuminato
## dal giocatore, ed è giusto: non ha vegliato su nessuno che ne avesse
## bisogno, quindi silenzio.
## PURA: entrano porte e luci, esce un nome.
static func chi_ha_vegliato(porte: Array, quante_fatte: int,
		luci_costruite: Array) -> String:
	for i in range(mini(quante_fatte, porte.size()) - 1, -1, -1):
		var p: Dictionary = porte[i]
		var pos: Vector3 = p.get("pos", Vector3.ZERO)
		if al_buio(pos, luci_costruite):
			return str(p.get("nome", ""))
	return ""


## Quanta sicurezza dona una notte vegliata, a una data resa.
static func dono_di_sicurezza(resa: float) -> float:
	return VEGLIA_SICUREZZA * clampf(resa, 0.0, 1.5)


## È l'ora di stare in garitta? PURA: entra l'ora del giorno, esce un
## sì o un no — la finestra evita il risveglio e la sera del falò.
static func in_orario_di_turno(ora: float) -> bool:
	return ora >= ORA_TURNO_DA and ora < ORA_TURNO_A


# ============================================================ la sera

func _process(delta: float) -> void:
	_t += delta
	if _daynight == null:
		return
	var ora := float(_daynight.get("time"))

	# l'alba: le lucine della notte si congedano
	if _ronda_fatta_oggi and ora > ORA_ALBA and ora < ORA_RONDA - 0.1:
		_spegni()

	# la sera: la ronda parte una volta sola
	if not _ronda_fatta_oggi and ora >= ORA_RONDA and ora < 0.95:
		_ronda_fatta_oggi = true
		_comincia_ronda()

	# il giorno: il turno in garitta, un richiamo ogni tanto
	if in_orario_di_turno(ora):
		_turno_cd -= delta
		if _turno_cd <= 0.0:
			_turno_cd = PASSO_TURNO
			_manda_in_garitta()

	# il giro, una tappa alla volta
	if _tappa_i < _tappe.size():
		_passo_cd -= delta
		if _passo_cd <= 0.0:
			_passo_cd = PASSO_RONDA
			_accendi_tappa(_tappe[_tappa_i])
			_tappa_i += 1

	_respira(delta)


# ============================================================ il giorno

## Il turno in garitta: chi è di guardia viene mandato al suo posto,
## DENTRO la guardiola. Vale solo se una Guardiola esiste (senza, il
## lavoro resta com'era: la sola ronda della sera) e se la resa non è
## a zero — chi ha smesso di obbedire non ci va, e la garitta vuota di
## giorno racconta la ribellione come il buio la racconta di notte.
func _manda_in_garitta() -> void:
	if _visitors == null or _lavori == null or _build == null:
		return
	var chi := str(_lavori.call("chi_fa", "guardia"))
	if chi == "":
		return
	var gradino := str(_visitors.call("animo_di", chi))
	if gradino == "":
		return
	var r := float(_lavori.call("resa", gradino, str(_visitors.call("sogno_di", chi)),
			"guardia"))
	if r <= 0.0:
		return
	var posto = _posto_di_guardia()
	if posto == null:
		return
	if _visitors.has_method("manda"):
		_visitors.call("manda", chi, posto)


## Dov'è il posto della guardia, se una Guardiola c'è: `null` altrimenti.
## Lo usano DUE cose (il turno di giorno e il punto da cui parte il giro
## della sera): una funzione sola, o le due si scollano in silenzio.
func _posto_di_guardia():
	if _build == null or not _build.has_method("get_placed_by_name"):
		return null
	var garitte: Array = _build.call("get_placed_by_name", "Guardiola")
	if garitte.is_empty():
		return null
	var garitta := garitte[0] as Node3D
	if garitta == null or not is_instance_valid(garitta):
		return null
	var posto := garitta.find_child("PostoGuardia", true, false) as Node3D
	if posto == null:
		return null
	return posto.global_position


func _comincia_ronda() -> void:
	_lanterne_accese = 0
	_guardia = ""
	_resa = 0.0
	_tappe = []
	_porte = []
	_tappa_i = 0
	if _visitors == null or _lavori == null:
		return
	# chi ha l'incarico, e con che resa
	var chi := str(_lavori.call("chi_fa", "guardia"))
	if chi == "":
		return
	var gradino := str(_visitors.call("animo_di", chi))
	if gradino == "":
		return
	var r := float(_lavori.call("resa", gradino, str(_visitors.call("sogno_di", chi)),
			"guardia"))
	if r <= 0.0:
		# dal rifiuto in poi non esce proprio: la notte è quella di sempre,
		# buia — ed è quel buio a raccontare, senza una riga di testo
		return
	_guardia = chi
	_resa = r
	# le porte tengono NOME e cella; alle tappe vanno solo le posizioni, così
	# `tappe_della_ronda` resta la stessa funzione pura di prima e l'indice di
	# tappa continua a mappare 1:1 sulle porte finché `i < _porte.size()`
	_porte = _ordina_porte(_porte_dei_vicini())
	var case: Array = _porte.map(func(p: Dictionary) -> Vector3: return p["pos"])
	var ritrovi := _ritrovi()
	var quante: int = int(_lavori.call("quanti", case.size() + ritrovi.size(), r))
	_tappe = tappe_della_ronda(case, ritrovi, maxi(quante, 1))
	_passo_cd = 0.6


# una tappa: la guardia ci va, e lì sboccia una lanterna
func _accendi_tappa(pos: Vector3) -> void:
	if _visitors and _guardia != "" and _visitors.has_method("manda"):
		_visitors.call("manda", _guardia, pos + Vector3(0.5, 0, 0.5))
	var scheda := LANTERNE.accendi(pos)
	var node := scheda["node"] as Node3D
	add_child(node)
	scheda["nascita"] = _t
	_lanterne.append(scheda)
	_lanterne_accese += 1
	# sboccia con lo scatto elastico, come ogni cosa che si posa nel villaggio
	node.scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3.ONE * float(scheda["taglia"]), 0.42) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _respira(delta: float) -> void:
	if _lanterne.is_empty():
		return
	for l in _lanterne:
		var node := l.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		# l'accensione è lenta: la fiammella prende piede in un secondo e mezzo
		var vita: float = _t - float(l.get("nascita", 0.0))
		LANTERNE.respira(l, _t, clampf(vita / 1.5, 0.0, 1.0))
	# delta non serve al respiro (usa _t), ma tenerlo in firma dice a chi
	# legge che questa è animazione, non logica
	if delta < 0.0:
		return


func _spegni() -> void:
	for l in _lanterne:
		var node := l.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void:
			if is_instance_valid(node):
				LANTERNE.respira(l, _t, v), 1.0, 0.0, 1.2)
		tw.tween_property(node, "scale", Vector3.ONE * 0.02, 0.4) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(node.queue_free)
	_lanterne.clear()
	_ronda_fatta_oggi = false


# ============================================================ i luoghi

## Le PORTE dei vicini: è per chi ci dorme che si veglia, quindi vengono
## prima. Ogni voce è {"nome", "label", "pos", "cell"}; `pos` è l'uscio
## (`_house.front`), non il corpo.
##
## TRAPPOLA MISURATA: `ORA_RONDA = 0.76` cade dentro la fase "fire" di
## `Visitors._phase()` (0.66-0.82), cioè l'ora in cui i corpi sono TUTTI
## attorno al falò. Leggendo `node.global_position` la ronda illuminava la
## radura N volte e le case mai — e il mattino dopo non c'era modo di dire
## su chi si fosse vegliato. La casa la si chiede a `_house` (le chiavi
## vere sono `bed`/`cell`/`front`, vedi `Visitors._make_house`), e si
## ripiega sul corpo solo se il letto è stato demolito.
func _porte_dei_vicini() -> Array:
	var out: Array = []
	if _visitors == null:
		return out
	for r in (_visitors.get("_residents") as Array):
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var label := str(r.get("label", ""))
		# i cuccioli non hanno una casa loro e non si vegliano da adulti:
		# la stessa esclusione del registro dei lavori e del congedo
		if label != "" and _visitors.has_method("e_cucciolo") \
				and bool(_visitors.call("e_cucciolo", label)):
			continue
		var pos := Vector3(node.global_position.x, 0.0, node.global_position.z)
		var cell := Vector2i(int(roundf(pos.x)), int(roundf(pos.z)))
		var casa = node.get("_house")
		if casa is Dictionary:
			var front = (casa as Dictionary).get("front", null)
			if front is Vector3:
				pos = Vector3(front.x, 0.0, front.z)
			var c = (casa as Dictionary).get("cell", null)
			if c is Vector2i:
				cell = c
		out.append({
			"nome": str((r.get("dna", {}) as Dictionary).get("name", "")),
			"label": label, "pos": pos, "cell": cell,
		})
	return out


## L'ordine del giro: si parte dal posto di guardia (o, senza Guardiola,
## dalla porta di chi veglia) e si va per vicinanza.
##
## IL PAREGGIO VA ROTTO A MANO. Le case stanno su una griglia a interi: due
## porte alla stessa distanza dal posto sono la norma, non l'eccezione, e
## senza un secondo criterio a decidere torna l'ordine di `_residents` —
## cioè un ordine che dipende da chi è arrivato prima. Qui non è un
## dettaglio contabile: è il giro che il giocatore VEDE, e il mattino dopo
## è il nome che finisce nel libro mastro.
func _ordina_porte(porte: Array) -> Array:
	var da: Vector3 = Vector3.ZERO
	var posto = _posto_di_guardia()
	if posto != null:
		da = posto
	else:
		for p in porte:
			if str((p as Dictionary).get("label", "")) == _guardia:
				da = (p as Dictionary)["pos"]
				break
	var out: Array = porte.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: Vector3 = a["pos"]
		var pb: Vector3 = b["pos"]
		var da2 := Vector2(pa.x - da.x, pa.z - da.z).length_squared()
		var db2 := Vector2(pb.x - da.x, pb.z - da.z).length_squared()
		if absf(da2 - db2) > 0.0001:
			return da2 < db2
		var ca: Vector2i = a["cell"]
		var cb: Vector2i = b["cell"]
		if ca.x != cb.x:
			return ca.x < cb.x
		return ca.y < cb.y)
	return out


## I luoghi che il villaggio vive di sera: la piazza e il falò della radura.
func _ritrovi() -> Array:
	var out: Array = [Vector3(2.5, 0, 5.5)]
	var cozy := get_node_or_null("../CozyWorld")
	if cozy:
		out.append(cozy.CLEARING_CENTER)
	return out


## I pezzi che il giocatore può posare e che fanno luce: la strada che non
## costa rancore a nessuno.
const PEZZI_CHE_ILLUMINANO := ["Lampione", "Camino", "Lampada",
		"Lampada semplice", "Braciere stellato", "Fontana"]


## Solo le luci COSTRUITE: quelle che ci sarebbero anche senza la ronda.
## Sono queste, e non le lanterne, a dire quali porte sarebbero rimaste al
## buio stanotte.
func luci_costruite() -> Array:
	var out: Array = []
	if _build == null:
		return out
	for nome in PEZZI_CHE_ILLUMINANO:
		for n in (_build.call("get_placed_by_name", nome) as Array):
			if n != null and is_instance_valid(n):
				out.append((n as Node3D).global_position)
	return out


## Le lanterne accese stanotte, come posizioni.
##
## SI LEGGE DA `_tappe`, NON DA `_lanterne`. `MORNING = 0.29` (DayNight) e
## `ORA_ALBA = 0.29` sono lo stesso numero: le lanterne sopravvivono al
## rendiconto del mattino solo perché DayNight sta PRIMA di Veglia
## nell'albero e `_spegni()` chiede `ora > ORA_ALBA` stretto. Far dipendere
## dall'ordine dei nodi un dato che finisce nei drive (e quindi nel
## salvataggio) è un guasto che aspetta solo di essere spostato di un
## fratello. `_tappe`/`_tappa_i` sono dati puri e restano fino alla ronda
## successiva.
func luci_della_ronda() -> Array:
	return _tappe.slice(0, _tappa_i)


## Tutte le luci del villaggio: quelle costruite più le lanterne di
## stanotte. Serve per sapere chi dorme al buio.
func luci_del_villaggio() -> Array:
	var out := luci_costruite()
	out.append_array(luci_della_ronda())
	return out


# ============================================================ il mattino
# Chiamato da Lavori._produzione_del_giorno (un padrone solo per il cambio
# giorno: così non c'è una gara fra chi produce e chi fa rientrare i drive).

## Applica quello che la notte ha lasciato e racconta com'è andata.
## Ritorna {"lanterne": int, "guardia": label, "al_buio": int}.
func rendiconto_del_mattino() -> Dictionary:
	var esito := {"lanterne": _lanterne_accese, "guardia": _guardia, "al_buio": 0}
	if _visitors == null:
		return esito
	var luci := luci_del_villaggio()
	var dono := dono_di_sicurezza(_resa) if _guardia != "" else 0.0
	for r in (_visitors.get("_residents") as Array):
		var label := str(r.get("label", ""))
		if label == "":
			continue
		var node := r.get("node") as Node3D
		var dove: Vector3 = node.global_position if node and is_instance_valid(node) \
				else Vector3.ZERO
		if label == _guardia:
			# chi ha vegliato non riceve il proprio dono: ha pagato lui.
			# Gli resta la stima di aver fatto una cosa che serviva.
			_visitors.call("dona_drive", label, "stima", VEGLIA_STIMA)
			continue
		# ⚠️ **LA DOMANDA SI FA SEMPRE, e prima si faceva solo se NON c'era
		# una guardia.** Con la guardia, ogni residente riceveva la stessa
		# identica riga `vegliato` — misurato: **1,000 per residente per
		# giornata, uguale per tutti e quattordici**. Cioe' «protetto» non era
		# un fatto di quella persona: era il meteo del villaggio.
		#
		# E' la ragione per cui l'esempio «chi e' stato protetto per venti
		# notti diventa un filo meno pauroso» non poteva entrare fra le
		# spinte della deriva: una prova che tocca tutti allo stesso modo non
		# distingue nessuno, ed e' una marea che solleva tutte le barche.
		var buio := al_buio(dove, luci)
		if dono > 0.0:
			_visitors.call("dona_drive", label, "sicurezza", dono)
			# ⚠️ **LA RIGA VA A CHI LA RONDA HA DAVVERO PROTETTO**, cioe' a chi
			# era al buio e ha avuto qualcuno che passava. Chi ha una luce
			# davanti a casa era gia' al sicuro — per un gesto che il
			# giocatore ha fatto mesi prima, e che si vede nel fatto che NON
			# perde sicurezza. Cosi' «protetto» diventa un fatto per persona,
			# e le chiavi in mano al giocatore restano due: assegnare la
			# guardia, e piantare i lampioni.
			#
			# Il ricordo resta intestato ALLA GUARDIA, mai al giocatore: in
			# Animo i ricordi buoni scontano i cattivi, e col nome sbagliato
			# una notte di veglia comprerebbe il perdono di tutto il villaggio.
			if buio:
				_visitors.call("ricorda_per", label, "vegliato", _guardia,
						0.30 * _resa)
				_visitors.call("lega_vicini", label, _guardia, VEGLIA_CREDITO)
		elif buio:
			_visitors.call("dona_drive", label, "sicurezza", -BUIO_SICUREZZA,
					SICUREZZA_MINIMA)
			esito["al_buio"] = int(esito["al_buio"]) + 1
	_annota_la_veglia()
	return esito


## La riga del libro mastro degli affetti: UNA per notte, e nasce QUI
## perché qui vive l'informazione — questo è l'unico posto che sa dov'è
## andata la luce.
##
## Prima la scriveva un giro in `Lavori`, identica da chi vegliava verso
## OGNI residente: misurato su 240 giorni, il conto fra guardia e cuoco
## cresceva 2.6 volte più che verso chiunque altro, la prima coppia nasceva
## al giorno 3 ed era sempre la stessa, e in tutta la partita non se ne
## formava nessun'altra. Il libro mastro non aveva più nessuna forma se non
## quella dell'incarico assegnato.
##
## IL LIBRO MASTRO È INDICIZZATO PER NOME (`dna.name`), non per label:
## `_guardia` è una label e va convertita, o la riga resta intestata a
## qualcuno che nel libro non esiste — e non se ne accorge nessuno.
func _annota_la_veglia() -> void:
	if _visitors == null or _guardia == "":
		return
	var chi := str(_visitors.call("_nome_da_label", _guardia))
	var vegliato := chi_ha_vegliato(_porte, _tappa_i, luci_costruite())
	if chi == "" or vegliato == "" or chi == vegliato:
		return
	get_tree().call_group("affetti", "gesto", chi, vegliato, "veglia")


# ---------------------------------------------------------------- debug CLI

func debug_ronda() -> void:
	_ronda_fatta_oggi = false
	_comincia_ronda()


func debug_stato() -> Dictionary:
	return {"guardia": _guardia, "resa": _resa, "lanterne": _lanterne.size(),
			"tappe": _tappe.size(), "porte": _porte.size(),
			"vegliato": chi_ha_vegliato(_porte, _tappa_i, luci_costruite())}
