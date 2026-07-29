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
var _tappa_i := 0
var _passo_cd := 0.0

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


## Quanta sicurezza dona una notte vegliata, a una data resa.
static func dono_di_sicurezza(resa: float) -> float:
	return VEGLIA_SICUREZZA * clampf(resa, 0.0, 1.5)


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

	# il giro, una tappa alla volta
	if _tappa_i < _tappe.size():
		_passo_cd -= delta
		if _passo_cd <= 0.0:
			_passo_cd = PASSO_RONDA
			_accendi_tappa(_tappe[_tappa_i])
			_tappa_i += 1

	_respira(delta)


func _comincia_ronda() -> void:
	_lanterne_accese = 0
	_guardia = ""
	_resa = 0.0
	_tappe = []
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
	var case := _case_dei_vicini()
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

## Le case dei vicini: è per chi ci dorme che si veglia, quindi vengono prima.
func _case_dei_vicini() -> Array:
	var out: Array = []
	if _visitors == null:
		return out
	for r in (_visitors.get("_residents") as Array):
		var node := r.get("node") as Node3D
		if node != null and is_instance_valid(node):
			out.append(Vector3(node.global_position.x, 0.0, node.global_position.z))
	return out


## I luoghi che il villaggio vive di sera: la piazza e il falò della radura.
func _ritrovi() -> Array:
	var out: Array = [Vector3(2.5, 0, 5.5)]
	var cozy := get_node_or_null("../CozyWorld")
	if cozy:
		out.append(cozy.CLEARING_CENTER)
	return out


## Tutte le luci del villaggio: quelle costruite (Lampione, Camino, Lampada)
## più le lanterne di stanotte. Serve per sapere chi dorme al buio.
func luci_del_villaggio() -> Array:
	var out: Array = []
	if _build:
		for nome in ["Lampione", "Camino", "Lampada", "Braciere stellato", "Fontana"]:
			for n in (_build.call("get_placed_by_name", nome) as Array):
				if n != null and is_instance_valid(n):
					out.append((n as Node3D).global_position)
	for l in _lanterne:
		var node := l.get("node") as Node3D
		if node != null and is_instance_valid(node):
			out.append(node.global_position)
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
		if dono > 0.0:
			_visitors.call("dona_drive", label, "sicurezza", dono)
			# il ricordo va intestato ALLA GUARDIA, mai al giocatore: in
			# Animo i ricordi buoni scontano i cattivi, e col nome sbagliato
			# una notte di veglia comprerebbe il perdono di tutto il villaggio
			_visitors.call("ricorda_per", label, "vegliato", _guardia, 0.30 * _resa)
			_visitors.call("lega_vicini", label, _guardia, VEGLIA_CREDITO)
		elif al_buio(dove, luci):
			_visitors.call("dona_drive", label, "sicurezza", -BUIO_SICUREZZA,
					SICUREZZA_MINIMA)
			esito["al_buio"] = int(esito["al_buio"]) + 1
	return esito


# ---------------------------------------------------------------- debug CLI

func debug_ronda() -> void:
	_ronda_fatta_oggi = false
	_comincia_ronda()


func debug_stato() -> Dictionary:
	return {"guardia": _guardia, "resa": _resa, "lanterne": _lanterne.size(),
			"tappe": _tappe.size()}
