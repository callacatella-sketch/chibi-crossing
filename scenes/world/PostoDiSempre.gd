extends Node

## IL POSTO DI SEMPRE — l'abitudine che nessuno ha deciso.
##
## Non è una meccanica che si sblocca: è una cosa che il gioco NOTA. Ogni
## tanto, giocando, ci si ferma sempre nello stesso punto alla stessa ora
## — l'orlo dello stagno quando cala la luce, il ramo del Grande Albero al
## mattino — senza averlo scelto, senza saperlo. Il villaggio se ne
## accorge prima di te.
##
## E un giorno arrivi, e **qualcuno è già lì**. Non dice niente. Non se ne
## va. Sta, come ci staresti tu.
##
## Perché non c'è nessun testo, nessun prompt, nessun premio: il momento
## vale ESATTAMENTE quanto non viene spiegato. L'unica cosa che il gioco
## si permette è annodare il momento al Filo Rosso — così, cento giorni
## dopo, davanti al fiore, «il posto di sempre» riaffiora insieme al
## resto della vostra storia.
##
## COME SI ACCORGE (tutto puro, testato headless):
##  · mentre Mochi sta FERMA all'aperto, ogni tanto si prende nota di
##    dov'è e a che ora: il mondo è diviso in quadrati di CELLA metri e
##    la giornata in FETTE fasce (non serve la precisione: serve
##    l'abitudine);
##  · una sosta conta come tale solo dopo SOSTA_MINIMA secondi lì dentro
##    — passare non è fermarsi;
##  · quando la stessa cella nella stessa fascia torna in GIORNI_ABITUDINE
##    giornate DIVERSE, quello è il posto di sempre. Uno solo alla volta:
##    quello più frequentato.
##
## CHI ARRIVA PRIMA: il vicino con più momenti sul Filo — chi ti conosce
## meglio. Ci va PRIMA di te (all'inizio della fascia), e resta.

const CELLA := 3.0            # il lato del quadrato che conta come "lo stesso posto"
const FETTE := 8              # le fasce della giornata (una fetta ≈ 30 s di gioco)
const SOSTA_MINIMA := 9.0     # quanti secondi fermi lì perché conti come sosta
const GIORNI_ABITUDINE := 3   # in quante giornate diverse, perché diventi abitudine
const CAMPIONE := 1.0         # ogni quanto si guarda dov'è
const FERMA := 0.35           # sotto questa velocità Mochi è "ferma"
const VICINO := 3.2           # quanto vicino deve essere per essere "lì"
const PROB_APPUNTAMENTO := 0.55   # non tutti i giorni: l'attesa fa parte del dono


var _player: Node3D
var _daynight: Node3D
var _visitors: Node
var _legami: Node
var _build: Node3D

# chiave "cx:cz:fetta" -> {"giorni": [int], "secondi": float}
var _soste := {}
# il posto trovato: {"cx": int, "cz": int, "fetta": int, "dal": int}
var _posto := {}
# l'appuntamento di oggi: chi c'è andato, e se il momento è già stato annodato
var _oggi := {}
var _campione_cd := 0.0
var _ultima_chiave := ""


func _ready() -> void:
	add_to_group("posto_di_sempre")
	add_to_group("persistable")
	(func() -> void:
		_player = get_node_or_null("%Player")
		_daynight = get_node_or_null("../DayNight")
		_visitors = get_node_or_null("../Visitors")
		_legami = get_tree().get_first_node_in_group("legami")
		_build = get_tree().get_first_node_in_group("build_system")
		if _daynight and _daynight.has_signal("day_changed"):
			_daynight.day_changed.connect(_nuovo_giorno)
	).call_deferred()


# ============================================================ le decisioni (pure)

## La chiave di un posto-e-ora: il quadrato di mondo più la fascia oraria.
## PURA: due soste vicine di posto e di ora danno la stessa chiave, ed è
## proprio quello che serve — l'abitudine non è precisa al centimetro.
static func chiave(pos: Vector3, ora: float) -> String:
	var cx := int(floor(pos.x / CELLA))
	var cz := int(floor(pos.z / CELLA))
	return "%d:%d:%d" % [cx, cz, fetta_di(ora)]


## In quale fascia della giornata cade quest'ora (0..FETTE-1).
static func fetta_di(ora: float) -> int:
	return int(floor(clampf(ora, 0.0, 0.9999) * float(FETTE)))


## Il centro del quadrato di una chiave, sul terreno.
static func centro_di(k: String) -> Vector3:
	var parti := k.split(":")
	if parti.size() < 3:
		return Vector3.ZERO
	return Vector3((float(parti[0]) + 0.5) * CELLA, 0.0,
			(float(parti[1]) + 0.5) * CELLA)


static func fetta_di_chiave(k: String) -> int:
	var parti := k.split(":")
	return int(parti[2]) if parti.size() >= 3 else 0


## È diventato un'abitudine? Serve la stessa cella nella stessa fascia in
## GIORNI_ABITUDINE giornate DIVERSE: tre pomeriggi di fila sullo stesso
## sasso sono un'abitudine, tre ore nello stesso pomeriggio no.
static func e_abitudine(giorni: Array) -> bool:
	var visti := {}
	for g in giorni:
		visti[int(g)] = true
	return visti.size() >= GIORNI_ABITUDINE


## Fra tutte le soste, la chiave dell'abitudine più forte (più giornate
## diverse; a parità, più secondi). "" se non ce n'è ancora nessuna.
static func abitudine_piu_forte(soste: Dictionary) -> String:
	var meglio := ""
	var mg := 0
	var ms := 0.0
	for k in soste:
		var voce: Dictionary = soste[k]
		var giorni: Array = voce.get("giorni", [])
		if not e_abitudine(giorni):
			continue
		var visti := {}
		for g in giorni:
			visti[int(g)] = true
		var quanti := visti.size()
		var secondi := float(voce.get("secondi", 0.0))
		if quanti > mg or (quanti == mg and secondi > ms):
			meglio = str(k)
			mg = quanti
			ms = secondi
	return meglio


# ============================================================ l'osservazione

func _process(delta: float) -> void:
	if _player == null or _daynight == null:
		return
	_campione_cd -= delta
	if _campione_cd > 0.0:
		return
	_campione_cd = CAMPIONE

	# si guarda solo chi STA: passare non è fermarsi
	var v: Variant = _player.get("velocity")
	var ferma: bool = (v is Vector3) and (v as Vector3).length() < FERMA
	if not ferma:
		_ultima_chiave = ""
		return
	# e solo all'aperto: dentro casa non è "il posto", è casa
	var pos: Vector3 = _player.global_position
	if _build and bool(_build.call("has_cover", Vector2i(roundi(pos.x), roundi(pos.z)))):
		_ultima_chiave = ""
		return

	var k := chiave(pos, float(_daynight.get("time")))
	if k != _ultima_chiave:
		_ultima_chiave = k
	if not _soste.has(k):
		_soste[k] = {"giorni": [], "secondi": 0.0}
	var voce: Dictionary = _soste[k]
	voce["secondi"] = float(voce.get("secondi", 0.0)) + CAMPIONE
	# la sosta si "timbra" una volta sola al giorno, e solo quando è vera
	if float(voce["secondi"]) >= SOSTA_MINIMA:
		var oggi := int(_daynight.get("day"))
		var giorni: Array = voce.get("giorni", [])
		if not (oggi in giorni):
			giorni.append(oggi)
			voce["giorni"] = giorni
			_forse_trovato(k)

	_forse_appuntamento(float(_daynight.get("time")))


# l'abitudine si è formata: da domani, qualcuno potrebbe esserci già
func _forse_trovato(k: String) -> void:
	if not _posto.is_empty():
		return
	var forte := abitudine_piu_forte(_soste)
	if forte == "":
		return
	_posto = {"chiave": forte, "dal": int(_daynight.get("day"))}
	# NESSUN TOAST. Il gioco si è accorto di una cosa tua: dirtelo la
	# rovinerebbe. Lo saprai la prima volta che arrivi e trovi qualcuno.
	_salva()


# ============================================================ l'appuntamento

func _nuovo_giorno(_giorno: int) -> void:
	_oggi = {}


## Se oggi è il giorno, e siamo appena entrati nella sua fascia, qualcuno
## ci va PRIMA di te. Se poi ci arrivi, ci trovi lui.
func _forse_appuntamento(ora: float) -> void:
	if _posto.is_empty() or _visitors == null:
		return
	var k := str(_posto.get("chiave", ""))
	if fetta_di(ora) != fetta_di_chiave(k):
		return
	if _oggi.has("chi"):
		_forse_momento(k)
		return
	_oggi["chi"] = ""     # deciso per oggi, comunque vada
	if randf() > PROB_APPUNTAMENTO:
		return
	var chi := _chi_ti_conosce_meglio()
	if chi == "":
		return
	_oggi["chi"] = chi
	# ci va e basta: nessun annuncio, nessuna freccia sulla mappa
	_visitors.call("manda", chi, centro_di(k))


## Chi ti conosce meglio: il vicino con più momenti sul Filo Rosso. È il
## solo criterio che ha senso — al posto di sempre non ci va uno a caso.
func _chi_ti_conosce_meglio() -> String:
	var meglio := ""
	var quanti := -1
	for r in (_visitors.get("_residents") as Array):
		var label := str(r.get("label", ""))
		var nome := str((r.get("dna", {}) as Dictionary).get("name", ""))
		if label == "" or nome == "":
			continue
		var n := 0
		if _legami:
			n = int(_legami.call("momenti_vissuti", nome))
		if n > quanti:
			quanti = n
			meglio = label
	return meglio


## Se sei arrivato e lui è lì, dopo un po' il momento si annoda al Filo.
## Una volta sola per giornata, e in silenzio: nessuno dice niente.
func _forse_momento(k: String) -> void:
	var chi := str(_oggi.get("chi", ""))
	if chi == "" or _oggi.get("fatto", false):
		return
	var centro := centro_di(k)
	if _player.global_position.distance_to(centro) > VICINO:
		return
	var nodo := _nodo_di(chi)
	if nodo == null or nodo.global_position.distance_to(centro) > VICINO + 1.5:
		return
	# ci siete tutti e due. Si aspetta un poco: la compagnia silenziosa ha
	# bisogno di durare, o è solo un incrocio
	_oggi["insieme"] = float(_oggi.get("insieme", 0.0)) + CAMPIONE
	if float(_oggi["insieme"]) < 6.0:
		return
	_oggi["fatto"] = true
	var nome := _nome_di(chi)
	if nome != "" and _legami:
		_legami.call("momento", nome, "posto", "")
	# l'unica cosa che si vede: un cuoricino, dal suo lato. Non parla.
	if nodo.has_method("_spawn_heart"):
		nodo.call("_spawn_heart")


func _nodo_di(label: String) -> Node3D:
	for r in (_visitors.get("_residents") as Array):
		if str(r.get("label", "")) == label:
			var n := r.get("node") as Node3D
			return n if n != null and is_instance_valid(n) else null
	return null


func _nome_di(label: String) -> String:
	for r in (_visitors.get("_residents") as Array):
		if str(r.get("label", "")) == label:
			return str((r.get("dna", {}) as Dictionary).get("name", ""))
	return ""


# ---------------------------------------------------------------- persistenza

func _salva() -> void:
	if _build:
		_build.call("request_save")


func save_extra() -> Dictionary:
	# le soste si salvano potate: tenere ogni quadrato in cui ci si è
	# fermati per cento giorni farebbe un salvataggio che cresce e basta.
	# Restano quelle che contano: le abitudini e le quasi-abitudini.
	var vive := {}
	for k in _soste:
		var voce: Dictionary = _soste[k]
		if (voce.get("giorni", []) as Array).size() >= 1:
			vive[k] = voce
	return {"posto_di_sempre": {"soste": vive, "posto": _posto}}


func load_extra(data: Dictionary) -> void:
	var d: Variant = data.get("posto_di_sempre")
	if not (d is Dictionary):
		return
	var dd: Dictionary = d
	var s: Variant = dd.get("soste")
	if s is Dictionary:
		_soste = s
	var p: Variant = dd.get("posto")
	if p is Dictionary:
		_posto = p


# ---------------------------------------------------------------- debug CLI

func debug_stato() -> Dictionary:
	return {"soste": _soste.size(), "posto": _posto, "oggi": _oggi}


func debug_forza_posto(pos: Vector3, ora: float) -> void:
	var k := chiave(pos, ora)
	_soste[k] = {"giorni": [1, 2, 3], "secondi": 60.0}
	_posto = {"chiave": k, "dal": 1}
