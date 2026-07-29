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
## Quanto resta aperta la finestra dell'incontro, dopo che il vicino è
## andato: molto più larga della fascia (che dura ~30 s reali), o bastava
## arrivare tardi di un attimo perché il momento non si annodasse mai.
const FINESTRA_INCONTRO := 120.0
## Quanto si deve stare lì insieme, in silenzio, perché diventi un momento.
const INSIEME_MINIMO := 6.0


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
var _fetta_prima := -1


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
	# L'APPUNTAMENTO VIVE FUORI DALL'OSSERVAZIONE. Prima stava in fondo al
	# campionamento, cioè dentro il ramo «Mochi è ferma all'aperto»: il
	# vicino veniva mandato al posto solo se in quel momento tu stavi
	# fermo — e il giorno si "bruciava" anche stando fermi dall'altra
	# parte del villaggio. Adesso l'appuntamento si decide da sé, e
	# l'incontro si può vivere camminandoci dentro.
	_appuntamento(delta, float(_daynight.get("time")))
	_campione_cd -= delta
	if _campione_cd > 0.0:
		return
	_campione_cd = CAMPIONE

	# si guarda solo chi STA: passare non è fermarsi
	var v: Variant = _player.get("velocity")
	var ferma: bool = (v is Vector3) and (v as Vector3).length() < FERMA
	if not ferma:
		_scordati_la_sosta()   # ci si è alzati: la sosta ricomincia da capo
		return
	# e solo all'aperto: dentro casa non è "il posto", è casa
	var pos: Vector3 = _player.global_position
	if _build and bool(_build.call("has_cover", Vector2i(roundi(pos.x), roundi(pos.z)))):
		_scordati_la_sosta()   # dentro casa non è «il posto», è casa
		return

	var k := chiave(pos, float(_daynight.get("time")))
	var oggi := int(_daynight.get("day"))
	if not _soste.has(k):
		_soste[k] = {"giorni": [], "secondi": 0.0, "g": -1, "oggi": 0.0}
	var voce: Dictionary = _soste[k]
	# LA SOSTA È DI OGGI. Il totale storico (`secondi`) serve solo allo
	# spareggio fra due abitudini pari; a decidere se OGGI ci si è fermati
	# davvero è un contatore che riparte a ogni giornata e a ogni volta che
	# ci si alza. Senza questa distinzione `SOSTA_MINIMA` diventava un
	# budget UNA TANTUM: superati i nove secondi in tutta la vita, da lì in
	# poi bastava passare un istante per timbrare la giornata — cioè
	# esattamente il «passare non è fermarsi» che questo file promette.
	if int(voce.get("g", -1)) != oggi or k != _ultima_chiave:
		voce["g"] = oggi
		voce["oggi"] = 0.0
	_ultima_chiave = k
	voce["oggi"] = float(voce.get("oggi", 0.0)) + CAMPIONE
	voce["secondi"] = float(voce.get("secondi", 0.0)) + CAMPIONE
	# la sosta si "timbra" una volta sola al giorno, e solo quando è vera
	if float(voce["oggi"]) >= SOSTA_MINIMA:
		var giorni: Array = voce.get("giorni", [])
		if not (oggi in giorni):
			giorni.append(oggi)
			voce["giorni"] = giorni
			_forse_trovato(k)


## Ci si è alzati (o si è entrati in casa): la sosta in corso non conta
## più, e il prossimo fermarsi ricomincia da zero.
func _scordati_la_sosta() -> void:
	if _ultima_chiave != "" and _soste.has(_ultima_chiave):
		(_soste[_ultima_chiave] as Dictionary)["oggi"] = 0.0
	_ultima_chiave = ""


# l'abitudine si è formata: da domani, qualcuno potrebbe esserci già
func _forse_trovato(_k: String) -> void:
	var forte := abitudine_piu_forte(_soste)
	if forte == "":
		return
	# LA PRIMA ELEZIONE NON È DEFINITIVA. Prima bastava un `if not
	# _posto.is_empty(): return` e il primo posto trovato restava per
	# sempre — anche quando, venti giorni dopo, l'abitudine vera era
	# un'altra e più forte. Un'abitudine si sposta: il posto la segue.
	var prima := str(_posto.get("chiave", ""))
	if prima == forte:
		return
	if prima != "" and not _piu_forte_di(forte, prima):
		return
	_posto = {"chiave": forte, "dal": int(_daynight.get("day"))}
	# NESSUN TOAST. Il gioco si è accorto di una cosa tua: dirtelo la
	# rovinerebbe. Lo saprai la prima volta che arrivi e trovi qualcuno.
	_salva()


## `a` batte `b`? Serve STRETTAMENTE più giornate: un pareggio non
## sposta il posto (o due celle vicine se lo ruberebbero a turno).
func _piu_forte_di(a: String, b: String) -> bool:
	return _giornate(a) > _giornate(b)


func _giornate(k: String) -> int:
	var visti := {}
	for g in ((_soste.get(k, {}) as Dictionary).get("giorni", []) as Array):
		visti[int(g)] = true
	return visti.size()


# ============================================================ l'appuntamento

func _nuovo_giorno(_giorno: int) -> void:
	_oggi = {}


## Se oggi è il giorno, e siamo appena entrati nella sua fascia, qualcuno
## ci va PRIMA di te. Se poi ci arrivi, ci trovi lui.
func _appuntamento(delta: float, ora: float) -> void:
	if _posto.is_empty() or _visitors == null:
		return
	var k := str(_posto.get("chiave", ""))
	var fetta := fetta_di(ora)
	var dentro := fetta == fetta_di_chiave(k)
	# si decide UNA volta, quando si ENTRA nella fascia: un rilevatore di
	# ingresso, non un "sono dentro" che rifarebbe il conto a ogni frame
	if dentro and _fetta_prima != fetta:
		_manda_al_posto(k)
	_fetta_prima = fetta
	# L'INCONTRO HA UNA FINESTRA SUA, più larga della fascia. La fascia dura
	# una trentina di secondi reali: pretendere che l'incontro cominci e
	# finisca lì dentro voleva dire che bastava arrivare tardi di un attimo
	# perché il momento non si annodasse mai.
	if float(_oggi.get("finestra", 0.0)) > 0.0:
		_oggi["finestra"] = float(_oggi["finestra"]) - delta
		_forse_momento(k, delta)


## Manda al posto chi ti conosce meglio — e apre la finestra dell'incontro.
func _manda_al_posto(k: String) -> void:
	if _oggi.has("chi"):
		return                      # già deciso per oggi, comunque sia andata
	_oggi["chi"] = ""
	if randf() > PROB_APPUNTAMENTO:
		return
	var chi := _chi_ti_conosce_meglio()
	if chi == "":
		return
	_oggi["chi"] = chi
	_oggi["finestra"] = FINESTRA_INCONTRO
	# ci va e basta: nessun annuncio, nessuna freccia sulla mappa
	_visitors.call("manda", chi, centro_di(k))


## Chi ti conosce meglio: il vicino con più momenti sul Filo Rosso. È il
## solo criterio che ha senso — al posto di sempre non ci va uno a caso.
## Il Filo Rosso si cerca OGNI VOLTA, non una volta sola all'avvio:
## Legami nasce differito dentro CozyWorld, qualche frame DOPO di noi, e
## la cattura una-tantum di `_ready` lo trovava sempre null — il momento
## del posto non si sarebbe annodato mai (e nessun test se ne accorgeva,
## perché la funzione veniva chiamata solo in partita).
func _filo_rosso() -> Node:
	if _legami == null or not is_instance_valid(_legami):
		_legami = get_tree().get_first_node_in_group("legami")
	return _legami


func _chi_ti_conosce_meglio() -> String:
	var meglio := ""
	var quanti := -1
	for r in (_visitors.get("_residents") as Array):
		var label := str(r.get("label", ""))
		var nome := str((r.get("dna", {}) as Dictionary).get("name", ""))
		if label == "" or nome == "":
			continue
		var n := 0
		var filo := _filo_rosso()
		if filo:
			n = int(filo.call("momenti_vissuti", nome))
		if n > quanti:
			quanti = n
			meglio = label
	return meglio


## Se sei arrivato e lui è lì, dopo un po' il momento si annoda al Filo.
## Una volta sola per giornata, e in silenzio: nessuno dice niente.
func _forse_momento(k: String, delta: float) -> void:
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
	_oggi["insieme"] = float(_oggi.get("insieme", 0.0)) + delta
	if float(_oggi["insieme"]) < INSIEME_MINIMO:
		return
	_oggi["fatto"] = true
	var nome := _nome_di(chi)
	var filo := _filo_rosso()
	if nome != "" and filo:
		filo.call("momento", nome, "posto", "")
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
		# il salvataggio passa da JSON e gli interi tornano FLOAT: senza
		# questa normalizzazione `oggi in giorni` non trova mai 7 dentro
		# [7.0], la giornata si timbra due volte e l'abitudine matura al
		# doppio della velocità
		_soste = {}
		for k in (s as Dictionary):
			var voce: Dictionary = (s as Dictionary)[k]
			var giorni: Array = []
			for g in (voce.get("giorni", []) as Array):
				giorni.append(int(g))
			_soste[str(k)] = {"giorni": giorni,
					"secondi": float(voce.get("secondi", 0.0)),
					"g": int(voce.get("g", -1)),
					"oggi": float(voce.get("oggi", 0.0))}
	var p: Variant = dd.get("posto")
	if p is Dictionary and not (p as Dictionary).is_empty():
		_posto = {"chiave": str((p as Dictionary).get("chiave", "")),
				"dal": int((p as Dictionary).get("dal", 0))}


# ---------------------------------------------------------------- debug CLI

func debug_stato() -> Dictionary:
	return {"soste": _soste.size(), "posto": _posto, "oggi": _oggi}


func debug_forza_posto(pos: Vector3, ora: float) -> void:
	var k := chiave(pos, ora)
	_soste[k] = {"giorni": [1, 2, 3], "secondi": 60.0}
	_posto = {"chiave": k, "dal": 1}
