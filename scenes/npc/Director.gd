extends Node

## Il Regista. Osserva come giochi (senza mai dirtelo) e ogni mattina
## COMPONE in Lua le routine dei residenti, assemblando i mattoncini del
## recinto (vai_a, annusa, parla_di…) coi parametri del tuo profilo: al
## giocatore botanico i vicini fioriscono intorno, al collezionista
## parlano di pesci sullo stagno, al solitario si avvicinano piano.
## È il gioco che riscrive il comportamento degli NPC in tempo reale —
## dentro il recinto di LuaRoutines: una routine rotta = piano vuoto =
## si torna alla routine di default, e nessun salvataggio si rompe.
##
## La regola d'oro: una sola sorpresa di regia al giorno, sempre vestita
## di finzione — è il Gufo che ti scrive, mai una meccanica nuda.

const LUA := preload("res://scenes/npc/LuaRoutines.gd")

# contatori del modello del giocatore -> assi del profilo
# Ogni evento emesso con note() DEVE stare in un asse, o non pesa mai sul
# profilo (test_regista fa la guardia). "legna" sta col costruttore (è il
# legname dei cantieri), "cucina" col socievole (le zuppette si offrono),
# "concertino" pure (si radunano i vicini a cantare attorno al carillon).
const ASSI := {
	"costruttore": ["costruzione", "legna"],
	"botanico": ["giardino"],
	"collezionista": ["retino", "pesca"],
	"socievole": ["socievole", "onsen", "cucina", "concertino", "nascondino"],
	"contemplativo": ["foto", "stelle", "dormita", "bosco"],
}

# le lettere del Gufo: la voce in-fiction del Regista (%d = il contatore)
const LETTERE_GUFO := {
	"costruttore": "Dal ramo alto conto colpi d'ascia e tetti nuovi:\n%d opere! Il villaggio cresce sotto le tue zampe.",
	"botanico": "Ti guardo annaffiare ogni mattina: %d gesti\ngentili. Anche le farfalle se ne sono accorte.",
	"collezionista": "Ho contato %d creaturine nei tuoi barattoli.\nLo stagno sussurra che gli piaci.",
	"socievole": "Che via vai di benvenuti e zuppette: %d gentilezze!\nNel bosco non si parla d'altro.",
	"contemplativo": "Ti ho vista guardare le stelle e camminare piano.\n%d momenti di quiete: sei dei nostri, ormai.",
	"curioso": "Ti osservo da un po': annusi il mondo come un\nriccio al primo giorno. Mi piace chi curiosa.",
}

var _lua: RefCounted
var _daynight: Node3D
var _visitors: Node
var _weather: Node3D
var _build: Node3D
var _mail: Node
var _cozy: Node3D
var _player: Node3D

var _contatori := {}
var _ieri := {}                 # snapshot per capire se il giorno è stato vissuto
var _sources := {}              # chiave residente -> sorgente Lua corrente
var _ultima_sorpresa := -1
var _sorprese := 0
var _bosco_acc := 0.0


func _ready() -> void:
	add_to_group("regista")
	add_to_group("persistable")
	_lua = LUA.new()
	_cozy = get_parent()
	(func():
		# figlio runtime di CozyWorld: %Player non risolve, path relativo
		_player = get_node_or_null("../../Player")
		_daynight = get_node_or_null("../../DayNight")
		_visitors = get_node_or_null("../../Visitors")
		_weather = get_node_or_null("../../Weather")
		_mail = get_node_or_null("../../Mail")
		_build = get_tree().get_first_node_in_group("build_system")
		if _daynight:
			_daynight.day_changed.connect(_on_new_day)).call_deferred()


## Il taccuino segreto del Regista: i sistemi segnalano qui cosa fai.
## Chiamata via call_group("regista", "note", evento): zero accoppiamento.
func note(evento: String) -> void:
	_contatori[evento] = int(_contatori.get(evento, 0)) + 1


func _process(delta: float) -> void:
	# l'unica osservazione attiva: il tempo passato nel bosco
	if _player and _player.global_position.z < -8.0:
		_bosco_acc += delta
		if _bosco_acc >= 6.0:
			_bosco_acc = 0.0
			note("bosco")


# ---------------------------------------------------------------- profilo

func _asse_val(asse: String) -> int:
	var v := 0
	for c in ASSI[asse]:
		v += int(_contatori.get(c, 0))
	return v


## L'asse dominante del giocatore ("curioso" finché non c'è storia).
func profilo() -> String:
	var best := "curioso"
	var best_v := 2   # sotto tre gesti non si giudica nessuno
	for asse in ASSI:
		var v := _asse_val(asse)
		if v > best_v:
			best_v = v
			best = asse
	return best


# ---------------------------------------------------------------- il mattino

func _on_new_day(_day: int) -> void:
	_compose_all()
	_sorpresa_del_giorno()
	_ieri = _contatori.duplicate()


# ------------------------------------------------------- composizione Lua

func _key_for(r: Dictionary) -> String:
	return "%s_%d_%d" % [str(r.get("label", "?")), r["cell"].x, r["cell"].y]


## Ricompone la routine Lua di ogni residente sul profilo di oggi.
func _compose_all() -> void:
	if _visitors == null or not (_lua as Object).call("attivo"):
		return
	var asse := profilo()
	for r in (_visitors.get("_residents") as Array):
		var key := _key_for(r)
		var sorgente := _componi_sorgente(r, asse)
		var err: String = _lua.compile_routine(key, sorgente)
		if err == "":
			_sources[key] = sorgente
		else:
			# routine rotta: non entra in servizio, resta la default
			_sources.erase(key)
			printerr("Regista: routine di %s respinta (%s)" % [key, err])


# un mattoncino: raggiungi un luogo del contesto, annusalo, commenta
func _blocco(target: String, concetto: String, umore: String, cuore: bool) -> String:
	var s := "\t\tvai_a(leggi(\"%s_x\"), leggi(\"%s_z\"))\n" % [target, target]
	s += "\t\tannusa(tra(2.5, 4.5))\n"
	s += "\t\tparla_di(\"%s\", \"%s\")\n" % [concetto, umore]
	if cuore:
		s += "\t\tcuoricino()\n"
	return s


# la personalità della giornata: [mattina, giorno A, giorno B]
# scelta dall'asse del giocatore, poi piegata dall'indole del residente
func _blocchi_per(asse: String, dna: Dictionary) -> Array:
	var scelte: Array
	match asse:
		"botanico":
			scelte = [["aiuola", "fiore", "felice", true],
					["fungo", "cibo", "domanda", false],
					["giocatore", "amico", "felice", false]]
		"collezionista":
			scelte = [["stagno", "pesce", "domanda", false],
					["aiuola", "fiore", "neutro", false],
					["giocatore", "amico", "felice", true]]
		"costruttore":
			scelte = [["casa", "casa", "felice", true],
					["panchina", "felice", "neutro", false],
					["giocatore", "amico", "felice", false]]
		"socievole":
			scelte = [["giocatore", "ciao", "felice", true],
					["panchina", "amico", "neutro", false],
					["aiuola", "fiore", "felice", false]]
		"contemplativo":
			scelte = [["panchina", "sole", "neutro", false],
					["stagno", "pesce", "domanda", false],
					["fungo", "cibo", "neutro", true]]
		_:
			scelte = [["fungo", "cibo", "domanda", false],
					["aiuola", "fiore", "felice", false],
					["stagno", "pesce", "domanda", false]]
	# l'indole del residente piega la regia: chi ama il giardino ci torna
	var w: Dictionary = dna.get("weights", {})
	if float(w.get("garden", 0.0)) >= 0.6:
		scelte[2] = ["aiuola", "fiore", "felice", true]
	elif float(w.get("warmth", 0.0)) >= 0.6:
		scelte[2] = ["casa", "fuoco", "felice", false]
	return scelte


func _componi_sorgente(r: Dictionary, asse: String) -> String:
	var b := _blocchi_per(asse, r.get("dna", {}))
	var giorno := int(_daynight.get("day")) if _daynight else 1
	var s := "-- Routine di %s, composta dal Regista (giorno %d)\n" % [str(r.get("label", "?")), giorno]
	s += "-- Profilo del giocatore: %s\n" % asse
	s += "return function()\n"
	s += "\tif leggi(\"pioggia\") then\n"
	s += "\t\tparla_di(\"pioggia\", \"domanda\")\n"
	s += "\t\tverso_casa()\n"
	s += "\t\taspetta(tra(4, 7))\n"
	s += "\t\treturn\n"
	s += "\tend\n"
	s += "\tif leggi(\"mattina\") then\n"
	s += _blocco(b[0][0], b[0][1], b[0][2], b[0][3])
	s += "\telse\n"
	s += "\t\tif caso() < 0.5 then\n"
	s += _blocco(b[1][0], b[1][1], b[1][2], b[1][3]).indent("\t")
	s += "\t\telse\n"
	s += _blocco(b[2][0], b[2][1], b[2][2], b[2][3]).indent("\t")
	s += "\t\tend\n"
	s += "\tend\n"
	s += "\taspetta(tra(2, 4))\n"
	s += "end\n"
	return s


# ------------------------------------------------------------ esecuzione

## Il piano Lua per un residente, o [] se tocca alla routine di default.
func plan_for(r: Dictionary, fase: String) -> Array:
	if not (_lua as Object).call("attivo"):
		return []
	var key := _key_for(r)
	if not _sources.has(key):
		return []
	return _lua.plan(key, _ctx_for(r, fase))


# il contesto: tutto ciò che una routine può "leggere" del mondo
func _ctx_for(r: Dictionary, fase: String) -> Dictionary:
	var casa := Vector3(r["cell"].x, 0, r["cell"].y)
	# solo bool e numeri: attraversano il confine Lua senza ambiguità
	var ctx := {
		"pioggia": _weather != null and _weather.is_raining(),
		"mattina": fase == "morning",
		"casa_x": casa.x, "casa_z": casa.z,
		"giocatore_x": casa.x, "giocatore_z": casa.z,
		"stagno_x": casa.x, "stagno_z": casa.z,
	}
	if _player:
		var vicino: Vector3 = _player.global_position + \
				Vector3(randf_range(-1.0, 1.0), 0, randf_range(0.8, 1.4))
		ctx["giocatore_x"] = vicino.x
		ctx["giocatore_z"] = vicino.z
	if _cozy:
		var bordo: Vector3 = _cozy.POND_CENTER + Vector3(0, 0, _cozy.POND_R + 0.8)
		ctx["stagno_x"] = bordo.x
		ctx["stagno_z"] = bordo.z
	for nome in [["aiuola", "Aiuola"], ["fungo", "Fungo"], ["panchina", "Panchina"]]:
		var pos := _posto_vicino(str(nome[1]), casa)
		ctx[str(nome[0]) + "_x"] = pos.x
		ctx[str(nome[0]) + "_z"] = pos.z
	return ctx


# il pezzo piazzato più vicino a casa (con un passetto di rispetto),
# o casa stessa se non ce n'è: vai_a resta sempre sensato
func _posto_vicino(item_name: String, casa: Vector3) -> Vector3:
	if _build == null:
		return casa
	var best := casa
	var best_d := 18.0
	for node in _build.get_placed_by_name(item_name):
		var d: float = (node as Node3D).global_position.distance_to(casa)
		if d < best_d:
			best_d = d
			best = (node as Node3D).global_position
	if best != casa:
		best += (casa - best).normalized() * 0.65
	return best


# ------------------------------------------------------------ la sorpresa

# una sola al giorno, e solo se ieri è successo qualcosa: il Gufo scrive
func _sorpresa_del_giorno() -> void:
	if _mail == null or _daynight == null:
		return
	var giorno := int(_daynight.get("day"))
	if giorno <= 1 or giorno == _ultima_sorpresa:
		return
	var mossi := false
	for k in _contatori:
		if int(_contatori[k]) > int(_ieri.get(k, 0)):
			mossi = true
			break
	if not mossi:
		return
	_ultima_sorpresa = giorno
	_sorprese += 1
	var asse := profilo()
	# la chiave italiana, non la frase tradotta: il conto si mette dentro
	# quando la busta si apre (e il ritratto del curioso è l'unico senza
	# numero da mettere — il segnaposto lo si cerca nella CHIAVE)
	var chiave := str(LETTERE_GUFO[asse])
	_mail.call("queue_letter", {
		"from_key": "Il Gufo",
		"text_key": chiave,
		"args": [_asse_val(asse)] if chiave.contains("%d") else [],
		"gift": _sorprese % 3 == 0,
	})


# ------------------------------------------------------------ persistenza

func save_extra() -> Dictionary:
	return {"regista": {
		"contatori": _contatori,
		"ieri": _ieri,
		"routine": _sources,
		"ultima_sorpresa": _ultima_sorpresa,
		"sorprese": _sorprese,
	}}


func load_extra(data: Dictionary) -> void:
	var d: Variant = data.get("regista")
	if d is not Dictionary:
		return
	_contatori = d.get("contatori", {})
	# lo snapshot di ieri torna dal salvataggio: senza, la sorpresa del
	# Gufo del mattino dopo un reload verrebbe quasi sempre saltata
	_ieri = d.get("ieri", _contatori.duplicate())
	_ultima_sorpresa = int(d.get("ultima_sorpresa", -1))
	_sorprese = int(d.get("sorprese", 0))
	# le routine di oggi tornano in servizio così com'erano
	var routine: Dictionary = d.get("routine", {})
	for key in routine:
		if _lua.compile_routine(str(key), str(routine[key])) == "":
			_sources[str(key)] = str(routine[key])


# ------------------------------------------------------------ debug CLI

func debug_note_many(evento: String, n: int) -> void:
	for i in n:
		note(evento)


func debug_compose() -> void:
	_compose_all()


func debug_stats() -> Dictionary:
	return {
		"compilate": _lua.get("compilate"),
		"respinte": _lua.get("respinte"),
		"attivo": (_lua as Object).call("attivo"),
		"profilo": profilo(),
	}


func debug_first_plan() -> Array:
	if _visitors == null:
		return []
	var residents: Array = _visitors.get("_residents")
	if residents.is_empty():
		return []
	return plan_for(residents[0], "morning")


func debug_first_source() -> String:
	if _sources.is_empty():
		return ""
	return str(_sources[_sources.keys()[0]])


## La prova del recinto: la sintassi rotta va respinta alla porta, e la
## routine "cattiva" (che tenta di usare io, fuori dal recinto) compila
## ma muore nel pcall — piano vuoto, si torna alla routine di default.
func debug_recinto() -> bool:
	var e1: String = _lua.compile_routine("__rotta", "questo non e' lua ((")
	var e2: String = _lua.compile_routine("__cattiva", "return function()\n\tio.write(\"fuga\")\nend")
	var piano: Array = _lua.plan("__cattiva", {})
	return e1 != "" and e2 == "" and piano.is_empty()
