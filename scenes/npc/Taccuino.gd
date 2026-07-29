extends Node

## IL TACCUINO DEL GUFO — il secondo canale del Regista.
##
## Il Regista conta già i gesti GROSSI (una casa, una retinata, un'aiuola) e
## il Gufo te li rimanda in faccia come un totale: «%d opere!». È freddo,
## ed è il tipo di frase che qualunque cozy game potrebbe scriverti.
##
## Questo è l'altro canale: i MICRO-GESTI. Quelli che nessuno ti ha chiesto
## di fare, che non danno punti, che non compaiono in nessuna lista — e che
## proprio per questo, citati, non si possono liquidare con «era scriptato».
## Un contatore dice «ti ho misurata». Una frase come
##
##   «Ti ho vista fermarti davanti a una farfalla dorata, allungare la
##    zampina, e poi lasciarla dov'era. Ci ho pensato tutto il pomeriggio.»
##
## dice «ti ho GUARDATA», e non c'è modo di spiegarsela: quel gesto non era
## richiesto da niente.
##
## ============================================================
## LA REGOLA CHE TIENE IN PIEDI TUTTO: SI AFFERMA SOLO CIÒ CHE SI È VISTO
## ============================================================
## Un falso positivo qui non attenua l'effetto: LO INVERTE. Se il Gufo
## dice «ti ho vista esitare» a chi stava cercando il menu, il giocatore
## capisce in un istante che è una frase generica, e da quel momento non
## crede più a NESSUNA lettera. Il danno è permanente.
##
## Perciò il Gufo non dice mai cosa hai PENSATO — non è cosa sua e non lo
## può sapere. Dice cosa è ACCADUTO (ti sei fermata, hai proseguito, l'hai
## lasciato lì) e poi dice cosa ha pensato LUI («ci ho pensato tutto il
## pomeriggio», «anche io faccio così»). La prima metà è verificabile, la
## seconda è sempre vera perché è sua. Anche nel caso peggiore la lettera
## non mente: al massimo il Gufo si è commosso per niente, e questo è
## esattamente ciò che fa un gufo.
##
## E poi ci sono le valvole, che sono altrettanto importanti:
##  · LA VALVOLA DEL CONTROLLO. Non si osserva NULLA mentre Mochi non è in
##    mano al giocatore. In questo gioco «pannello aperto», «seduta»,
##    «onsen», «modalità foto», «costellazioni» e «dialogo» si riducono
##    tutti allo stesso fatto: il player ha la fisica spenta. Una riga, e
##    la classe di falsi positivi più grossa sparisce.
##  · LA VALVOLA DEL SALTO. Un balzo di posizione più lungo di SALTO metri
##    fra due campioni non è camminare: è un caricamento, una dormita, una
##    seduta. Qualunque osservazione in corso viene buttata.
##  · LA VALVOLA DELLA TAZZA DI CAFFÈ. Una sosta è contemplazione se dura
##    fra SOSTA_MIN e SOSTA_MAX secondi. Sotto è un rallentamento, sopra è
##    andata a fare altro nella vita vera.
##  · IL SILENZIO È IL COMPORTAMENTO NORMALE. Ogni giudizio ha una fascia
##    grigia in cui NON scatta. Meglio nessuna lettera che una lettera a
##    vuoto.
##
## ============================================================
## COSA GUARDA (quattro cose, non una di più)
## ============================================================
##  1. L'ESITAZIONE — sei andata verso una cosa, ti sei fermata, lo schermo
##     ti stava offrendo il tasto, e sei ripartita senza premerlo.
##     L'oracolo esiste già: `ArbitroE.scegli()` sa in ogni istante cosa
##     faresti se premessi E. Non c'era bisogno di inventarlo.
##  2. IL SENTIERO — il sentiero l'hai posato tu. Ci cammini sopra sempre,
##     anche quando tagliare sarebbe più corto? Oppure l'hai fatto e non ci
##     passi mai? Sono due frasi diversissime e sono entrambe vere.
##  3. LA SOSTA — ferma all'aperto a lungo, e poi ripartita da sola.
##  4. LA REGOLA TUA — la stessa esitazione, sulla stessa specie di cosa,
##     in due giornate diverse. Non è più un momento: è un'abitudine. È
##     l'osservazione più profonda che il taccuino sa fare, e nasce
##     gratis dalla prima.
##
## Il posto in cui torni sempre NON è qui: quello lo nota già
## `PostoDiSempre`, e lo dice senza parole (un vicino è già lì). Metterci
## sopra una lettera rovinerebbe il suo silenzio.

const CRIT := preload("res://scenes/world/Critters.gd")

# ------------------------------------------------------------- le soglie
# Tutte misurate, non indovinate: ognuna esclude un falso positivo preciso.

## Ogni quanto si guarda il mondo. 5 volte al secondo bastano per un gesto
## umano e costano una frazione di quello che costerebbe ogni frame.
const CAMPIONE := 0.2
## Sotto questa velocità Mochi è «ferma» (la stessa soglia di PostoDiSempre
## e del Fiato Sospeso: la calma del giocatore ha un solo metro).
const FERMA := 0.35
## Un balzo più lungo di così fra due campioni non è un passo.
const SALTO := 3.0

## L'ESITAZIONE
## Quanto va stata ferma davanti alla cosa perché sia una sosta e non un
## rallentamento. Due secondi sono un'eternità, con un tasto che lampeggia.
const ESITA_FERMA := 2.0
## Di quanto si deve essere AVVICINATA perché sia «ci è andata» e non «le
## è capitato davanti». Sotto un metro è passare accanto.
const ESITA_AVVICINAMENTO := 0.9
## Oltre questo, non è più esitazione: è una sosta, e la giudica un altro.
const ESITA_MAX := 22.0
## E deve ripartire CAMMINANDO: sparire dal raggio perché ti hanno
## teletrasportata non è un gesto.
const ESITA_RIPARTE := 0.5

## IL SENTIERO
## Quanti campioni di cammino servono per un verdetto. A 0.2 s l'uno e solo
## quando cammina, sono circa venti secondi di passi VERI.
const SENT_CAMPIONI := 100
## Sopra questa frazione di passi sul selciato: ci cammini sempre.
const SENT_FEDELE := 0.82
## Sotto questa: l'hai fatto e non lo usi.
const SENT_IGNORATO := 0.12
## E serve un sentiero VERO, non una piastrella: sotto questo non si giudica.
const SENT_CELLE_MIN := 6

## LA SOSTA
const SOSTA_MIN := 30.0
## Sopra questo è andata a prendere un caffè, e il Gufo non ne sa niente.
const SOSTA_MAX := 95.0
## Se tiene premuta una direzione mentre «sta ferma», è incastrata in un
## muro: non è contemplazione. Si tollera qualche campione (l'inerzia).
const SOSTA_SPINTA_MAX := 0.10

## LA REGOLA TUA: quante esitazioni sulla stessa classe di cosa, in
## giornate diverse, perché diventi un'abitudine.
const REGOLA_VOLTE := 2

## Quante pagine tiene il taccuino, e per quanti giorni una pagina resta
## fresca. Oltre, il Gufo non la cita: un ricordo di sei giorni fa citato
## come «ieri» è la cosa che smaschera tutto.
const PAGINE_MAX := 12
const PAGINE_GIORNI := 4

# ---------------------------------------------------------- i bersagli
# Come si chiama, in italiano, la cosa che stavi per fare. Il nome VERO
# (la specie della farfalla, il frutto dell'albero) lo dà il sistema che
# la possiede, tramite `bersaglio_umano()`: qui c'è solo il ripiego per
# chi non ce l'ha, e la CLASSE che serve alla «regola tua».
const BERSAGLI := {
	"retino": {"cosa": "quella creaturina", "classe": "creatura"},
	"pesca": {"cosa": "quell'ombra nell'acqua", "classe": "pesce"},
	"ascia": {"cosa": "quell'albero", "classe": "albero"},
	"frutteto": {"cosa": "quel ramo carico", "classe": "frutto"},
	"scavo": {"cosa": "quella terra smossa", "classe": "scavo"},
	"rimbalzello": {"cosa": "quel sasso piatto", "classe": "sasso"},
}

# ------------------------------------------------------------- lo stato

var _player: Node3D
var _daynight: Node3D
var _weather: Node3D
var _build: Node3D
var _arbitro: Node
var _regista: Node

var _t := 0.0
var _pos_prec := Vector3.INF

## l'esitazione in corso: {} = nessuna
var _es := {}
## il cammino: campioni e quanti sul selciato
var _sent_tot := 0
var _sent_pietra := 0
## la sosta in corso
var _sosta := 0.0
var _sosta_spinte := 0
var _sosta_campioni := 0
var _sosta_arrivata := false
## quanto è che cammina (per capire se è «ripartita»)
var _in_moto := 0.0
## QUANTE CELLE DI SENTIERO CI SONO, in cache. `get_placed_by_name` scorre
## TUTTI i pezzi piazzati del villaggio su due dizionari e cinque strati:
## chiederglielo a ogni campionamento, in un villaggio cresciuto, sono
## migliaia di confronti cinque volte al secondo. Un sentiero non nasce
## mentre stai camminando: si ricontano ogni CENSIMENTO secondi.
const CENSIMENTO := 6.0
var _celle_sentiero := 0
var _t_censimento := 99.0
## le classi su cui ha già esitato, e in che giornate: "creatura" -> [2, 5]
var _rinunce := {}
## i verdetti già dati una volta, per non ripeterli: "sentiero_fedele" -> giorno
var _detti := {}


func _ready() -> void:
	add_to_group("taccuino")
	add_to_group("persistable")
	_cabla()


## IL CABLAGGIO SI RIPROVA. Un `call_deferred` nel `_ready` non basta, e
## averlo scoperto e' costato una pagina che non arrivava mai: il REGISTA
## non e' nella scena, e' un figlio RUNTIME di CozyWorld, creato durante la
## generazione differita del mondo. Un frame dopo il caricamento non esiste
## ancora, e un riferimento preso allora resta null per sempre — il
## taccuino avrebbe osservato tutto e consegnato niente, senza un errore.
##
## Quindi si riprova, a ogni campionamento, finche' non si e' trovato tutto.
## Costa qualche `get_first_node_in_group` nei primi secondi di partita e
## poi zero, perche' `_cablato` chiude la porta.
var _cablato := false

func _cabla() -> void:
	if _cablato:
		return
	if _player == null:
		_player = get_node_or_null("../Player")
	if _daynight == null:
		_daynight = get_node_or_null("../DayNight")
	if _weather == null:
		_weather = get_node_or_null("../Weather")
	if _build == null:
		_build = get_tree().get_first_node_in_group("build_system")
	if _arbitro == null:
		_arbitro = get_tree().get_first_node_in_group("arbitro_e")
	if _regista == null:
		_regista = get_tree().get_first_node_in_group("regista")
	# il Regista e' l'ultimo ad arrivare: quando c'e' lui, c'e' tutto
	_cablato = _player != null and _daynight != null and _build != null \
			and _arbitro != null and _regista != null


# ============================================================ i giudizi puri
# Separati dall'osservazione per poterli provare headless, uno per uno,
# fabbricando la finestra a mano. Un test che entra dalla porta del
# `_process` non riuscirebbe mai a mettere alla prova i casi limite —
# ed è nei casi limite che vivono i falsi positivi.

## L'ESITAZIONE È VERA? La finestra porta con sé tutto quello che serve.
## Nessuna di queste condizioni è decorativa: togline una e si apre un
## modo preciso di scattare a vuoto.
static func giudica_esitazione(f: Dictionary) -> bool:
	if bool(f.get("guasta", false)):
		return false                          # una valvola l'ha annullata
	if bool(f.get("premuto", false)):
		return false                          # l'ha fatto: non è una rinuncia
	if float(f.get("fermo", 0.0)) < ESITA_FERMA:
		return false                          # ha rallentato, non si è fermata
	if float(f.get("durata", 0.0)) > ESITA_MAX:
		return false                          # è una sosta, non un'esitazione
	if float(f.get("avvicinamento", 0.0)) < ESITA_AVVICINAMENTO:
		return false                          # le è capitato davanti, non ci è andata
	if float(f.get("riparte", 0.0)) < ESITA_RIPARTE:
		return false                          # non se n'è andata camminando
	if not bool(f.get("vivo", true)):
		return false                          # gliel'ha presa qualcun altro
	return true


## IL CAMMINO SUL SENTIERO: "sentiero_fedele", "sentiero_ignorato" o ""
## (la fascia grigia, che è la risposta normale).
static func giudica_sentiero(su_pietra: int, campioni: int, celle: int) -> String:
	if campioni < SENT_CAMPIONI or celle < SENT_CELLE_MIN:
		return ""
	var q := float(su_pietra) / float(campioni)
	if q >= SENT_FEDELE:
		return "sentiero_fedele"
	if q <= SENT_IGNORATO:
		return "sentiero_ignorato"
	return ""


## LA SOSTA È CONTEMPLAZIONE? Notare che questo giudizio è più permissivo
## degli altri, e può esserlo: la sua lettera afferma soltanto che sei
## stata ferma a lungo, che è vero anche se eri in cucina a farti un tè.
static func giudica_sosta(secondi: float, spinte: int, campioni: int,
		arrivata: bool, guasta: bool) -> bool:
	if guasta or not arrivata:
		return false
	if secondi < SOSTA_MIN or secondi > SOSTA_MAX:
		return false
	if campioni > 0 and float(spinte) / float(campioni) > SOSTA_SPINTA_MAX:
		return false                          # incastrata in un muro
	return true


## COSA AVEVI DAVANTI: il contesto che la lettera può citare. Puro.
static func contesto(notte: bool, piove: bool, acqua: bool, ora: float) -> String:
	if piove:
		return "la pioggia"
	if notte:
		return "le stelle"
	if acqua:
		return "l'acqua"
	if ora < 0.34:
		return "la luce che si alzava"
	if ora > 0.66:
		return "le ombre che si allungavano"
	return "il prato"


## Da quanti giorni è la pagina, detto come lo direbbe il Gufo. Puro.
static func quando(giorni: int) -> String:
	if giorni <= 0:
		return "stamattina"
	if giorni == 1:
		return "ieri"
	return "l'altro giorno"


## Una pagina è ancora citabile oggi? Puro.
static func fresca(pagina: Dictionary, oggi: int) -> bool:
	if bool(pagina.get("usata", false)):
		return false
	var eta := oggi - int(pagina.get("giorno", -99))
	return eta >= 0 and eta <= PAGINE_GIORNI


# ============================================================ l'osservazione

func _process(delta: float) -> void:
	_t += delta
	if _t < CAMPIONE:
		return
	var passo := _t
	_t = 0.0
	_cabla()
	if _player == null or not is_instance_valid(_player):
		return

	# ---- LA VALVOLA DEL CONTROLLO. Se Mochi non è in mano al giocatore
	# (pannello, seduta, onsen, foto, costellazioni, dormita) non si
	# osserva niente e si buttano le finestre aperte: quello che succede
	# mentre lei è congelata NON è un gesto del giocatore.
	if not _player.is_physics_processing():
		_annulla_tutto()
		return

	var pos: Vector3 = _player.global_position
	# ---- LA VALVOLA DEL SALTO
	if _pos_prec != Vector3.INF and _pos_prec.distance_to(pos) > SALTO:
		_annulla_tutto()
		_pos_prec = pos
		return
	_pos_prec = pos

	_t_censimento += passo
	var vel := _velocita()
	if vel > FERMA:
		_in_moto += passo
	else:
		_in_moto = 0.0

	_guarda_esitazione(passo, pos, vel)
	_guarda_sentiero(pos, vel)
	_guarda_sosta(passo, pos, vel)


func _velocita() -> float:
	var v: Variant = _player.get("velocity")
	if v is Vector3:
		return Vector2((v as Vector3).x, (v as Vector3).z).length()
	return 0.0


## Tutto ciò che era in corso viene buttato. Non si «mette in pausa»: una
## finestra interrotta a metà non è più una prova di niente.
func _annulla_tutto() -> void:
	if not _es.is_empty():
		_es["guasta"] = true
		_chiudi_esitazione()
	_sosta = 0.0
	_sosta_arrivata = false
	_sosta_spinte = 0
	_sosta_campioni = 0
	_in_moto = 0.0


# ------------------------------------------------------------ 1. l'esitazione

func _guarda_esitazione(passo: float, pos: Vector3, vel: float) -> void:
	if _arbitro == null or not is_instance_valid(_arbitro):
		return
	# `candidato()` e non `scegli()`: chiedere «cosa farebbe se premesse E»
	# non e' una contesa, e non deve finire nel registro delle contese.
	var v: Dictionary = _arbitro.call("candidato")
	var nome := str(v.get("nome", "")) if not v.is_empty() else ""

	# la cosa che avevo davanti non c'è più (o è cambiata): si tira la riga
	if _es.is_empty() or str(_es.get("nome", "")) != nome:
		if not _es.is_empty():
			_es["riparte"] = _in_moto
			_es["vivo"] = is_instance_valid(_es.get("chi"))
			_chiudi_esitazione()
		if nome == "" or not BERSAGLI.has(nome):
			return
		# si apre una finestra nuova: da qui si misura tutto
		_es = {
			"nome": nome,
			"chi": v.get("chi"),
			"cosa": _nome_del_bersaglio(v),
			"classe": str(BERSAGLI[nome]["classe"]),
			"d_iniziale": _distanza_dal_bersaglio(v, pos),
			"d_minima": _distanza_dal_bersaglio(v, pos),
			"fermo": 0.0,
			"durata": 0.0,
			"premuto": false,
			"guasta": false,
			"giorno": _giorno(),
		}
		return

	# la finestra continua: si accumula
	_es["durata"] = float(_es["durata"]) + passo
	if vel <= FERMA:
		_es["fermo"] = float(_es["fermo"]) + passo
	var d := _distanza_dal_bersaglio(v, pos)
	if d >= 0.0:
		_es["d_minima"] = minf(float(_es["d_minima"]), d)


## IL TASTO PREMUTO. Si ascolta l'evento VERO, e non si chiede a nessuno
## se il gesto e' andato a buon fine: se il giocatore ha premuto, non ha
## rinunciato — anche se il gesto e' fallito, anche se l'ha rubato un altro
## sistema, anche se ha premuto un istante troppo tardi. Il dubbio va
## sempre a favore del silenzio.
##
## Non si consuma NULLA qui: il taccuino guarda passare l'input di tutti.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not _es.is_empty():
		_es["premuto"] = true


func _chiudi_esitazione() -> void:
	var f := _es
	_es = {}
	if f.is_empty():
		return
	var d0 := float(f.get("d_iniziale", -1.0))
	var dm := float(f.get("d_minima", -1.0))
	f["avvicinamento"] = (d0 - dm) if (d0 >= 0.0 and dm >= 0.0) else 0.0
	if not giudica_esitazione(f):
		return
	var classe := str(f.get("classe", ""))
	_annota("esitazione", {"cosa": f.get("cosa", ""), "classe": classe})
	# ---- LA REGOLA TUA: la stessa rinuncia, in giornate DIVERSE. Il
	# giorno conta una volta sola: dieci funghi lasciati nello stesso
	# pomeriggio sono un pomeriggio, non un'abitudine.
	var g := _giorno()
	var giorni: Array = _rinunce.get(classe, [])
	if not g in giorni:
		giorni.append(g)
		_rinunce[classe] = giorni
	if giorni.size() >= REGOLA_VOLTE and not _detti.has("regola_" + classe):
		_detti["regola_" + classe] = g
		_annota("regola_tua", {"cosa": f.get("cosa", ""), "classe": classe})


## Come si chiama la cosa che stavi per fare. Il sistema che la possiede lo
## sa meglio di chiunque: se espone `bersaglio_umano()` si usa quello (la
## specie della farfalla viene da Critters, che è la fonte unica dei nomi).
## Altrimenti il ripiego generico, che è comunque una frase vera.
func _nome_del_bersaglio(v: Dictionary) -> String:
	var chi := v.get("chi") as Node
	if chi != null and is_instance_valid(chi) and chi.has_method("bersaglio_umano"):
		var n := str(chi.call("bersaglio_umano"))
		if n != "":
			return n
	return str(BERSAGLI[str(v["nome"])]["cosa"])


func _distanza_dal_bersaglio(v: Dictionary, _pos: Vector3) -> float:
	# l'arbitro parla in distanze: è il suo contratto, ed è già in metri
	var d := float(v.get("distanza", -1.0))
	return d if d >= 0.0 else -1.0


# --------------------------------------------------------------- 2. il sentiero

func _guarda_sentiero(pos: Vector3, vel: float) -> void:
	if _build == null or not is_instance_valid(_build) or vel <= FERMA:
		return
	if _t_censimento >= CENSIMENTO:
		_t_censimento = 0.0
		_celle_sentiero = (_build.call("get_placed_by_name", "Sentiero") as Array).size()
	if _celle_sentiero < SENT_CELLE_MIN:
		return
	# UN CAMPIONE CONTA SOLO SE C'ERA UNA SCELTA: si sta sul selciato, o
	# gli si sta accanto. In mezzo al prato, a venti metri dal sentiero,
	# non stai «evitando» niente — e contare quei passi renderebbe
	# «ignorato» il verdetto di chiunque abbia un villaggio grande.
	var su := str(_build.call("surface_at", pos)) == "stone"
	if not su and not _sentiero_accanto(pos):
		return
	_sent_tot += 1
	if su:
		_sent_pietra += 1
	var verdetto := giudica_sentiero(_sent_pietra, _sent_tot, _celle_sentiero)
	if _sent_tot >= SENT_CAMPIONI:
		_sent_tot = 0
		_sent_pietra = 0
		if verdetto != "" and not _detti.has(verdetto):
			_detti[verdetto] = _giorno()
			_annota(verdetto, {})


## C'è un sentiero a un passo da qui? Le quattro celle ortogonali bastano:
## a un metro dal selciato la scelta di non salirci è una scelta.
func _sentiero_accanto(pos: Vector3) -> bool:
	for d: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0),
			Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		if str(_build.call("surface_at", pos + d)) == "stone":
			return true
	return false


# ----------------------------------------------------------------- 3. la sosta

func _guarda_sosta(passo: float, pos: Vector3, vel: float) -> void:
	if vel > FERMA:
		# ripartita: si tira la riga sulla sosta appena finita
		if _sosta > 0.0:
			var s := _sosta
			var sp := _sosta_spinte
			var camp := _sosta_campioni
			var arr := _sosta_arrivata
			_sosta = 0.0
			_sosta_spinte = 0
			_sosta_campioni = 0
			if giudica_sosta(s, sp, camp, arr, false):
				_annota("sosta", {"cosa": _contesto_di_adesso(pos)})
		# «ci è arrivata camminando»: se la sosta cominciasse da sola
		# (un caricamento, una posa che finisce) non sarebbe una scelta
		_sosta_arrivata = _in_moto >= 0.6
		return
	# ferma sotto un tetto non è contemplare il mondo: è essere in casa
	if _build != null and is_instance_valid(_build) \
			and str(_build.call("surface_at", pos)) == "wood":
		_sosta = 0.0
		return
	_sosta += passo
	_sosta_campioni += 1
	# tiene premuta una direzione e non si muove: è incastrata in un muro
	if Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down").length() > 0.1:
		_sosta_spinte += 1
	# oltre il tetto massimo si butta subito, senza aspettare che riparta:
	# così una notte passata da ferma non lascia una finestra buona in
	# attesa di chiudersi
	if _sosta > SOSTA_MAX:
		_sosta = 0.0
		_sosta_arrivata = false
		_sosta_spinte = 0
		_sosta_campioni = 0


func _contesto_di_adesso(pos: Vector3) -> String:
	var notte := _daynight != null and bool(_daynight.call("is_night"))
	var piove := _weather != null and (bool(_weather.call("is_raining")) \
			or bool(_weather.call("is_snowing")))
	var ora := float(_daynight.get("time")) if _daynight else 0.5
	return contesto(notte, piove, _vicino_all_acqua(pos), ora)


## Il fiume ha una sola fonte di verità: la sua curva. Lo stagno è dove il
## prato si apre. Si chiede a chi lo sa, non si ricopia una coordinata.
func _vicino_all_acqua(pos: Vector3) -> bool:
	var cozy := get_tree().get_first_node_in_group("cozy_world")
	if cozy != null and cozy.has_method("distanza_dall_acqua"):
		return float(cozy.call("distanza_dall_acqua", pos)) < 4.0
	var MATH := load("res://scenes/world/WorldMath.gd")
	if MATH != null:
		return absf(pos.x - float(MATH.river_x(pos.z))) < 4.0
	return false


# ============================================================ le pagine

## Si scrive una pagina. Il taccuino non manda niente da sé: consegna al
## Regista, che è l'unico a decidere quando il Gufo scrive — così non
## esistono due gufi che parlano lo stesso giorno.
func _annota(oss: String, dati: Dictionary) -> void:
	var pagina := {
		"oss": oss,
		"cosa": str(dati.get("cosa", "")),
		"classe": str(dati.get("classe", "")),
		"giorno": _giorno(),
		"usata": false,
	}
	if _regista != null and is_instance_valid(_regista) \
			and _regista.has_method("annota"):
		_regista.call("annota", pagina)


func _giorno() -> int:
	return int(_daynight.get("day")) if _daynight else 1


# ============================================================ persistenza

func save_extra() -> Dictionary:
	return {"taccuino": {"rinunce": _rinunce, "detti": _detti}}


func load_extra(data: Dictionary) -> void:
	var d: Variant = data.get("taccuino")
	if d is not Dictionary:
		return
	_rinunce = (d as Dictionary).get("rinunce", {})
	_detti = (d as Dictionary).get("detti", {})


# ============================================================ debug CLI

func debug_stato() -> Dictionary:
	return {
		"esitazione": _es.duplicate(true) if not _es.is_empty() else {},
		"sent_tot": _sent_tot,
		"sent_pietra": _sent_pietra,
		"sosta": _sosta,
		"rinunce": _rinunce,
		"detti": _detti,
	}


## Fabbrica un'esitazione già cotta: serve all'harness per vedere la
## lettera vera senza dover recitare il gesto davanti alla telecamera.
func debug_forza_esitazione(cosa: String, classe: String) -> void:
	_es = {"nome": "retino", "chi": self, "cosa": cosa, "classe": classe,
			"d_iniziale": 3.0, "d_minima": 1.0, "fermo": ESITA_FERMA + 0.5,
			"durata": ESITA_FERMA + 1.0, "premuto": false, "guasta": false,
			"giorno": _giorno()}
	_es["riparte"] = ESITA_RIPARTE + 0.2
	_es["vivo"] = true
	_chiudi_esitazione()
