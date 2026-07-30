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

## ============================================================
## IL TACCUINO: le lettere che citano un micro-gesto
## ============================================================
## Le lettere di sopra dicono un TOTALE. Queste dicono un ISTANTE, e non
## si possono liquidare con «era scriptato» perche' quel gesto non era
## richiesto da niente e non dava punti.
##
## Sono scritte con una regola precisa: la prima meta' afferma solo cio'
## che si e' VISTO (ti sei fermata, sei ripartita, tutto e' rimasto dov'era),
## la seconda dice cosa ha pensato IL GUFO — che e' sempre vero, perche' e'
## suo. Cosi' nemmeno nel caso peggiore la lettera mente.
##
## E niente pronomi sulla cosa citata: «l'hai lasciata» va in pezzi se la
## cosa e' un fungo, e in inglese ogni concordanza si perde comunque. Si
## dice «tutto e' rimasto dov'era», che non ha genere.
##
## `cita`: la lettera vuole [quando, cosa] — e sono CHIAVI ANNIDATE, non
## testo, cosi' si traducono all'apertura della busta e non al momento in
## cui finiscono su disco.
##
## E il campo si chiama `text_key` DI PROPOSITO, non "testo": il guardiano
## della localizzazione cerca i letterali `"text_key": "…"` nei sorgenti.
## Con un nome qualunque queste lettere gli sarebbero sfuggite, e sarebbero
## uscite in italiano dentro la versione inglese con la suite verde.
const TACCUINO_LETTERE := {
	"esitazione": {"cita": true, "text_key": "Ti ho vista fermarti, %s,\ndavanti a %s.\nHai allungato la zampina, e poi sei ripartita:\ntutto è rimasto dov'era.\nCi ho pensato tutto il pomeriggio, sul mio ramo."},
	"regola_tua": {"cita": false, "text_key": "È la seconda volta che ti fermi davanti a qualcosa\ne poi tiri indietro la zampina.\nHo smesso di pensare che sia distrazione:\ncredo sia una regola tua. Non te la chiedo. La rispetto."},
	"sentiero_fedele": {"cita": false, "text_key": "Cammini sul sentiero. Sempre, anche quando tagliare\nsarebbe più corto e nessuno ti vedrebbe.\nAnche io faccio così, sui rami. Non so perché."},
	"sentiero_ignorato": {"cita": false, "text_key": "Hai posato un sentiero e cammini accanto.\nNon è un rimprovero: l'ho guardato dall'alto, stamattina,\ne ho pensato che certe cose si fanno perché siano belle da vedere."},
	"sosta": {"cita": true, "text_key": "Sei rimasta ferma tanto, %s.\nA guardare %s.\nNon ho mosso una piuma, per non disturbarti."},
}
## Quante pagine si tengono, e per quanti giorni una pagina resta citabile.
const TACCUINO_MAX := 12
const TACCUINO_GIORNI := 4

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
## LE PAGINE DEL TACCUINO. Le scrive Taccuino.gd, le cita il Gufo. Stanno
## qui e non li' perche' il Gufo deve avere UNA voce: se il taccuino
## spedisse da se', due lettere potrebbero arrivare la stessa mattina.
var _pagine: Array = []


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


## IL SECONDO CANALE: una pagina del taccuino. Non e' un contatore e non
## entra negli ASSI del profilo — un micro-gesto non dice che GIOCATORE
## sei, dice che e' stato visto. Chiamata da Taccuino.gd.
##
## Le pagine sono a scadenza: il Gufo non cita come «ieri» una cosa di sei
## giorni fa, ed e' proprio quel dettaglio che smaschererebbe tutto.
func annota(pagina: Dictionary) -> void:
	if not TACCUINO_LETTERE.has(str(pagina.get("oss", ""))):
		return
	_pagine.append(pagina)
	while _pagine.size() > TACCUINO_MAX:
		_pagine.pop_front()


## La pagina da citare stamattina, o {} se non ce n'e'. PURA: si prova
## headless fabbricando le pagine a mano, che e' l'unico modo di mettere
## alla prova la scadenza.
##
## Si prende la piu' RECENTE, non la piu' vecchia: un gesto di stamattina
## e' piu' vivo di uno di tre giorni fa, e la pila cresce in coda.
static func pagina_da_citare(pagine: Array, oggi: int) -> Dictionary:
	for i in range(pagine.size() - 1, -1, -1):
		var p: Dictionary = pagine[i]
		if bool(p.get("usata", false)):
			continue
		var eta := oggi - int(p.get("giorno", -99))
		if eta < 0 or eta > TACCUINO_GIORNI:
			continue
		return p
	return {}


## Da quanti giorni, detto come lo dice il Gufo. PURA.
static func quando(giorni: int) -> String:
	if giorni <= 0:
		return "stamattina"
	if giorni == 1:
		return "ieri"
	return "l'altro giorno"


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

# una sola al giorno: il Gufo scrive. Se ha una pagina del taccuino la cita,
# altrimenti ripiega sul ritratto del profilo — e solo se ieri e' successo
# qualcosa.
func _sorpresa_del_giorno() -> void:
	if _mail == null or _daynight == null:
		return
	var giorno := int(_daynight.get("day"))
	if giorno <= 1 or giorno == _ultima_sorpresa:
		return
	# ---- IL TACCUINO HA LA PRECEDENZA. Un istante citato batte un totale,
	# sempre: e' l'unica delle due lettere che il giocatore non puo'
	# spiegarsi. La lettera-contatore diventa il ripiego di quando non
	# c'e' stato nessun micro-gesto da guardare.
	var pagina := pagina_da_citare(_pagine, giorno)
	if not pagina.is_empty():
		_ultima_sorpresa = giorno
		_sorprese += 1
		pagina["usata"] = true
		_mail.call("queue_letter", _lettera_dal_taccuino(pagina, giorno))
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


## La busta di una pagina del taccuino. Il «quando» e la cosa citata sono
## CHIAVI ANNIDATE (`{"k": ...}`): la posta finisce su disco in italiano e
## si traduce solo all'apertura, nella lingua di quel momento.
##
## E il taccuino non porta regali: un pacco trasformerebbe l'osservazione
## in una ricompensa, e il momento vale esattamente quanto NON viene pagato.
func _lettera_dal_taccuino(pagina: Dictionary, oggi: int) -> Dictionary:
	var voce: Dictionary = TACCUINO_LETTERE[str(pagina["oss"])]
	var args: Array = []
	if bool(voce["cita"]):
		args = [{"k": quando(oggi - int(pagina.get("giorno", oggi)))},
				{"k": str(pagina.get("cosa", ""))}]
	return {
		"from_key": "Il Gufo",
		"text_key": str(voce["text_key"]),
		"args": args,
		"gift": false,
	}


# ------------------------------------------------------------ persistenza

func save_extra() -> Dictionary:
	return {"regista": {
		"contatori": _contatori,
		"ieri": _ieri,
		"routine": _sources,
		"ultima_sorpresa": _ultima_sorpresa,
		"sorprese": _sorprese,
		"pagine": _pagine,
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
	# le pagine del taccuino tornano com'erano: un salvataggio fatto prima
	# che il taccuino esistesse non ha la chiave, e riparte da vuoto senza
	# rompere niente
	_pagine = d.get("pagine", [])
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
