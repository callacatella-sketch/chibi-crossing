extends Node

## La premura dei vicini. Fame e sete ora hanno una conseguenza MORBIDA:
## a pancia vuota (o gola secca) Mochi cammina un filo più lenta — nessuna
## punizione, solo il corpo che si fa sentire. E dopo un po' i residenti
## SE NE ACCORGONO: il più vicino le trotterella incontro e le porta un
## boccone del suo pranzo. Finora l'empatia scorreva solo da Mochi verso
## il villaggio (regali, zuppette, consolazioni): da qui il villaggio
## ricambia — è la premura a rendere vere le barre, non la penalità.

const LENTA := 0.82           # il passo languido: -18%, si sente ma non punisce
const ATTESA_PREMURA := 12.0  # secondi di languore prima che qualcuno accorra
const RAGGIO_PREMURA := 12.0  # da quanto lontano un vicino può accorgersene
const RIFOCILLO := 0.65       # quanto riempie il boccone (frazione del massimo)

var _player: Node3D
var _survival: Node
var _visitors: Node
var _daynight: Node3D
var _sfx

var _walk_base := -1.0
var _run_base := -1.0
var _languida := false
var _attesa := 0.0
var _premura_giorno := -1     # il giorno dell'ultimo soccorso: uno al giorno
var _in_arrivo := false


func _ready() -> void:
	(func() -> void:
		_player = get_node_or_null("../Player")
		_visitors = get_node_or_null("../Visitors")
		_daynight = get_node_or_null("../DayNight")
		_sfx = get_node_or_null(^"/root/Sfx")
		if _player:
			_survival = _player.get_node_or_null("SurvivalComponent")
			# il passo "di fabbrica" si legge UNA volta: da qui in poi la
			# velocità vera è sempre base * (1 o LENTA), mai un accumulo
			if _player.has_method("get_walk_speed"):
				_walk_base = float(_player.get_walk_speed())
				_run_base = float(_player.get_run_speed())
	).call_deferred()


## Il languore, come lo decide il corpo: pancia vuota O gola secca.
## PURA: la verifica il test senza istanziare nulla.
static func languida(fame: float, sete: float) -> bool:
	return fame <= 0.01 or sete <= 0.01


func _process(delta: float) -> void:
	if _survival == null or _player == null:
		return
	var adesso := languida(float(_survival.get_hunger()), float(_survival.get_water()))
	if adesso != _languida:
		_languida = adesso
		_applica_passo()
		if adesso and _visitors:
			_visitors.call("_show_toast",
					"Che languorino… il passo di Mochi si fa piccolo piccolo.")
	if not _languida or _in_arrivo:
		_attesa = 0.0
		return
	_attesa += delta
	if _attesa >= ATTESA_PREMURA:
		_attesa = 0.0
		_porta_un_boccone()


# il passo si accorcia (o torna suo) — mai sommando: sempre dalla base
func _applica_passo() -> void:
	if _walk_base < 0.0 or not _player.has_method("set_walk_speed"):
		return
	var k := LENTA if _languida else 1.0
	_player.set_walk_speed(_walk_base * k)
	_player.set_run_speed(_run_base * k)


## Il soccorso: il vicino più vicino accorre e divide il suo pranzo.
## Uno al giorno: la premura è un dono, non un distributore.
func _porta_un_boccone() -> void:
	if _visitors == null:
		return
	var oggi := int(_daynight.get("day")) if _daynight else 0
	if oggi == _premura_giorno:
		return
	var vicino: Dictionary = {}
	var meglio := RAGGIO_PREMURA
	for r in (_visitors.get("_residents") as Array):
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node) or bool(node.call("is_hidden")):
			continue
		var d: float = node.global_position.distance_to(_player.global_position)
		if d < meglio:
			meglio = d
			vicino = r
	if vicino.is_empty():
		return
	_premura_giorno = oggi
	_in_arrivo = true
	var node := vicino.get("node") as Node3D
	var label := str(vicino.get("label", "un vicino"))
	# trotterella fin quasi addosso a Mochi, annusa, e offre
	var accanto: Vector3 = _player.global_position \
			+ Vector3(randf_range(-0.6, 0.6), 0, randf_range(0.7, 1.1))
	node.call("do_routine", "sniff", accanto, _player.global_position)
	get_tree().create_timer(3.2).timeout.connect(func() -> void:
		_in_arrivo = false
		if _survival == null or not is_instance_valid(node):
			return
		if not _languida:
			return   # nel frattempo ha mangiato da sola: il vicino saluta e basta
		if float(_survival.get_hunger()) <= 0.01:
			_survival.set_hunger(float(_survival.get_max_hunger()) * RIFOCILLO)
		if float(_survival.get_water()) <= 0.01:
			_survival.set_water(float(_survival.get_max_water()) * RIFOCILLO)
		node.call("speak", ["cibo", "amico", "felice"], "felice")
		node.call("_spawn_heart")
		if _visitors:
			_visitors.call("_show_toast",
					"%s si è accort%s del languorino: un boccone del suo pranzo per te!"
					% [label, "a" if label.begins_with("la ") else "o"])
		if _sfx:
			_sfx.munch())
