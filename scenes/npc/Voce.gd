extends Node

## LA VOCE — il giocatore entra nel grafo.
##
## Ogni gesto del giocatore è sempre stato uno-a-uno: regalare, salutare,
## assegnare un lavoro, promettere. Il villaggio intanto ha una vita
## relazionale simulata (Villaggio.gd: il passaparola, le cascate di
## simula_giorno) che il giocatore può solo subire. La Voce è il verbo che
## mancava: PORTARE qualcosa fra due persone. Il nome viene da lì:
## SOGLIA_VOCE, «la voce non vale più la pena di essere riportata» —
## questa è la voce che la pena la vale.
##
## COME SI GIOCA, in sei battute:
##
## 1. NON SI OTTIENE PARLANDO: SI OTTIENE ASPETTANDO. Nessun dialogo a
##    scelte. Ti siedi accanto a chi ha bisogno e tieni premuto C — il
##    Fiato Sospeso. La stessa calma che fa posare le farfalle fa parlare
##    le persone: questo nodo è un ascoltatore in più del gruppo
##    calma_listener. Chi si confida lo decidono i sistemi che già ci
##    sono: umore basso e regolazione a terra (ha bisogno di dirlo),
##    giorni di Filo Rosso (te lo dice A TE), arousal alto (non riesce
##    a stare zitto).
##
## 2. QUELLO CHE TI DICE È VERO — stato di simulazione, non lore. Cinque
##    famiglie, ognuna pescata da un sistema esistente e finora invisibile:
##      paura      → un marchio in Limbico.marchi (luogo| sotto la soglia)
##      torto      → il lavoro assegnato che TRADISCE il sogno (Animo.COMPITI)
##      desiderio  → il drive più a terra fra quelli che un mestiere sa colmare
##      affetto    → un'amicizia NON reciproca nel grafo del Villaggio
##      partenza   → la scala della ribellione a un passo dalla diserzione
##
## 3. LA VOCE TI RESTA ADDOSSO, E SCADE: quattro giorni (GIORNI_VOCE, la
##    stessa vita delle pagine del Taccuino), poi «l'altro giorno» non si
##    può più dire. UNA voce per volta: una confidenza è un peso, non un
##    oggetto da collezionare. Alcune sono MICCE: se non fai niente,
##    simula_giorno fa il suo lavoro — la partenza non ha bisogno di
##    codice nuovo per diventare una partenza.
##
## 4. POI SCEGLI: TACERE, O PORTARLA. Portarla è un gesto fisico (gradino
##    VOLTO dell'arbitro della E), come si consegna un regalo. Ogni voce
##    ha un destinatario giusto DENTRO i sistemi — e molti sbagliati.
##    Nessuna freccia: lo deduci da quello che sai delle persone. È un
##    puzzle sociale.
##
## 5. LE CONSEGUENZE LE CALCOLANO I SISTEMI. Giusto: l'altro agisce con i
##    verbi che il villaggio già conosce (manda, lega, dona, visita_serena,
##    i gesti degli Affetti). Sbagliato: il danno lo fa il Limbico
##    onestamente — rivaluta("confidenza", "giocatore", -0.8, identita)
##    marchia chi|giocatore da solo — e il pettegolezzo porta la voce in
##    giro con lo smorzamento già tarato del Villaggio.
##
## 6. IL SILENZIO LO VEDE IL GUFO. Se la voce scade non detta, il Taccuino
##    del Regista scrive la pagina («hai saputo una cosa e non l'hai detta
##    a nessuno») e la fiducia sale: ti confidano di più. L'arbitro morale
##    esiste già, gratis.
##
## La logica è PURA in testa al file (si prova headless in
## tests/cases/test_voce.gd); il cablaggio vive sotto.

const ANIMO := preload("res://scenes/npc/Animo.gd")
const ARBITRO := preload("res://systems/ArbitroE.gd")

# ------------------------------------------------- i numeri, tutti qui

## Quanto tempo di quiete vera accanto a qualcuno prima che si apra.
const TEMPO_CONFIDENZA := 5.5
## La quiete minima perché ti senta come ti sentono le farfalle: la stessa
## soglia della fiducia del prato (FiatoSospeso.SOGLIA_FIDUCIA).
const QUIETE_MINIMA := 0.70
## Entro questa distanza sei «accanto»: più in là stai solo aspettando.
const RAGGIO_ASCOLTO := 2.4
## Giorni di Filo Rosso perché si confidi proprio A TE.
const FIDUCIA_GIORNI := 3
## Ogni voce taciuta (rispettata) abbassa la porta della prossima.
const SCONTO_RISERBO := 1
## Quanti giorni la voce resta viva addosso — come le pagine del Taccuino.
const GIORNI_VOCE := 4
## Il bisogno di dirlo: umore sotto, regolazione sotto.
const UMORE_BISOGNO := -0.22
const REGOLAZIONE_A_TERRA := 0.40
## Oppure: il corpo che non riesce a stare zitto.
const AROUSAL_TRABOCCA := 0.62
## Sotto questa carica un marchio non è una paura da confidare (la stessa
## soglia oltre cui il Limbico comincia a girare al largo).
const PAURA_SOGLIA := 0.45
## L'asimmetria che fa un affetto non detto: io ci tengo, lui non lo sa.
const AFFETTO_MIO := 0.55
const AFFETTO_SUO := 0.18
## Il drive dev'essere messo male davvero per diventare un desiderio.
const DESIDERIO_SOGLIA := 0.62
## Il gradino della scala da cui la partenza è nell'aria: uno PRIMA della
## diserzione — a diserzione il fagotto è già in spalla, e novanta secondi
## (Visitors.ATTESA_PARTENZA) non bastano a nessuno.
const GRADINO_PARTENZA := "confronto"
## Entro questa distanza si consegna la voce (gradino VOLTO).
const RAGGIO_CONSEGNA := 1.7
## Il danno di una confidenza tradita, e la voce che poi gira.
const TRADIMENTO := -0.8
const PETTEGOLEZZO_VALENZA := -0.4
const PETTEGOLEZZO_FORZA := 0.55

## Chi sa colmare quale mancanza: il MESTIERE è il destinatario giusto del
## desiderio. Solo i drive che un mestiere sa davvero colmare — la stima e
## l'autonomia non si regalano per interposta persona.
const LAVORO_PER_DRIVE := {
	"sicurezza": "guardia",
	"fatica": "cucina",
	"noia": "esplora",
}

## Come si DICE un luogo dentro una frase. Le chiavi sono gli id dei
## marchi (Visitors.LUOGO_DEL_LAVORO); i valori hanno l'articolo perché
## vanno in mezzo a una confidenza, non su un'etichetta.
const LUOGO_DETTO := {
	"catasta": "la catasta",
	"orto": "l'orto",
	"cucina": "la cucina",
	"confine": "il confine",
	"bosco": "il bosco",
}

# ============================================================ la logica pura

## Si apre con te, adesso? Le tre porte della confidenza, tutte già nel
## gioco: il bisogno (umore e regolazione), la fiducia (giorni di Filo),
## il corpo che trabocca (arousal). PURA.
static func si_confida(umore: float, arousal: float, regolazione: float,
		giorni_filo: int, riserbo := 0) -> bool:
	var fiducia := giorni_filo >= maxi(1, FIDUCIA_GIORNI - riserbo * SCONTO_RISERBO)
	if not fiducia:
		return false
	var bisogno := umore <= UMORE_BISOGNO and regolazione <= REGOLAZIONE_A_TERRA
	var trabocca := arousal >= AROUSAL_TRABOCCA
	return bisogno or trabocca


## Pesca la voce dallo stato VERO del residente. `dati` è uno snapshot
## piatto (così la funzione resta pura e provabile headless):
##   marchi        i marchi del limbico {"luogo|catasta": {carica: -0.6}, …}
##   lavoro/sogno  l'incarico attuale (id di Lavori) e il sogno (Animo.SOGNI)
##   amici_miei    {altro: quanto CI TENGO}   (il mio lato del grafo)
##   amici_loro    {altro: quanto LUI tiene a me}
##   drive_male    {drive: malessere 0..1}
##   gradino       l'indice sulla scala della ribellione
## Ritorna {} se non c'è niente da confidare, altrimenti la voce:
##   {famiglia, da, dettaglio, giorno, miccia}
## La priorità è il peso: la partenza sopra tutto, poi la paura, il torto,
## l'affetto, e per ultimo il desiderio.
static func pesca_voce(nome: String, dati: Dictionary, oggi: int) -> Dictionary:
	# la paura di partire: la voce che pesa più di tutte — ed è una miccia
	if ANIMO.almeno(int(dati.get("gradino", 0)), GRADINO_PARTENZA):
		return {"famiglia": "partenza", "da": nome, "dettaglio": "",
				"giorno": oggi, "miccia": true}
	# una paura: il marchio di luogo più carico, se supera la soglia
	var peggio := ""
	var carica_peggio := 0.0
	var marchi: Dictionary = dati.get("marchi", {})
	for k in marchi:
		if not str(k).begins_with("luogo|"):
			continue
		var carica: float = float((marchi[k] as Dictionary).get("carica", 0.0))
		if carica < -PAURA_SOGLIA and carica < carica_peggio:
			carica_peggio = carica
			peggio = str(k).trim_prefix("luogo|")
	if peggio != "":
		return {"famiglia": "paura", "da": nome, "dettaglio": peggio,
				"giorno": oggi, "miccia": false}
	# un torto: il lavoro assegnato che TRADISCE il sogno. Non un semplice
	# «non è quello che sognavo» (quello è la vita): il tradimento vero,
	# quello che in Animo brucia CONTRO_SOGNO e porta alla scala.
	var lavoro := str(dati.get("lavoro", ""))
	var sogno := str(dati.get("sogno", ""))
	if lavoro != "" and ANIMO.COMPITI.has(lavoro) \
			and sogno in (ANIMO.COMPITI[lavoro]["tradisce"] as Array):
		return {"famiglia": "torto", "da": nome, "dettaglio": lavoro,
				"giorno": oggi, "miccia": false}
	# un affetto non detto: io ci tengo, lui non lo sa
	var amici_miei: Dictionary = dati.get("amici_miei", {})
	var amici_loro: Dictionary = dati.get("amici_loro", {})
	var caro := ""
	var quanto := AFFETTO_MIO
	for altro in amici_miei:
		var mio: float = float(amici_miei[altro])
		var suo: float = float(amici_loro.get(altro, 0.0))
		if mio >= quanto and suo <= AFFETTO_SUO:
			quanto = mio
			caro = str(altro)
	if caro != "":
		return {"famiglia": "affetto", "da": nome, "dettaglio": caro,
				"giorno": oggi, "miccia": false}
	# un desiderio: il drive più a terra fra quelli che un mestiere colma
	var drive_male: Dictionary = dati.get("drive_male", {})
	var peggiore := ""
	var male := DESIDERIO_SOGLIA
	for d in LAVORO_PER_DRIVE:
		var v: float = float(drive_male.get(d, 0.0))
		if v >= male:
			male = v
			peggiore = str(d)
	if peggiore != "":
		return {"famiglia": "desiderio", "da": nome, "dettaglio": peggiore,
				"giorno": oggi, "miccia": false}
	return {}


## La voce è ancora viva? Quattro giorni, come le pagine del Taccuino:
## «l'altro giorno» a un certo punto non si può più dire. PURA.
static func scaduta(voce: Dictionary, oggi: int) -> bool:
	return oggi - int(voce.get("giorno", -99)) > GIORNI_VOCE


## Questo destinatario è quello GIUSTO per questa voce? Il giusto sta
## dentro i sistemi, non in una tabella di quest:
##   paura      → un amico vero di chi si è confidato (lo accompagnerà)
##   torto      → chi SOGNA proprio quel lavoro (lo prenderà lui)
##   desiderio  → chi FA il mestiere che colma quel drive
##   affetto    → l'altro in persona
##   partenza   → il più caro fra i suoi (l'unico che pesa abbastanza)
## `ctx`: {amici_di_da: {..}, sogno_dest, incarico_dest, piu_caro}. PURA.
static func destinatario_giusto(voce: Dictionary, dest: String,
		ctx: Dictionary) -> bool:
	match str(voce.get("famiglia", "")):
		"paura":
			return float((ctx.get("amici_di_da", {}) as Dictionary).get(dest, 0.0)) >= 0.5
		"torto":
			var serve := str((ANIMO.COMPITI.get(str(voce.get("dettaglio", "")), {})
					as Dictionary).get("serve", ""))
			return serve != "" and str(ctx.get("sogno_dest", "")) == serve
		"desiderio":
			var mestiere := str(LAVORO_PER_DRIVE.get(str(voce.get("dettaglio", "")), ""))
			return mestiere != "" and str(ctx.get("incarico_dest", "")) == mestiere
		"affetto":
			return dest == str(voce.get("dettaglio", ""))
		"partenza":
			return dest == str(ctx.get("piu_caro", ""))
	return false


## Il più caro di qualcuno: l'arco più pesante del suo lato del grafo. PURA.
static func piu_caro(amici: Dictionary) -> String:
	var caro := ""
	var quanto := 0.0
	for altro in amici:
		if float(amici[altro]) > quanto:
			quanto = float(amici[altro])
			caro = str(altro)
	return caro


# ============================================================ il cablaggio

var _voce := {}              # la voce addosso, o {}
var _riserbo := {}           # label -> quante volte ho taciuto per lui
var _confidato_oggi := {}    # label -> true (si bussa una volta al giorno)
var _quiete := 0.0
var _quiete_pos := Vector3.ZERO
var _quiete_fresca := 9.0    # da quanto non arriva una pubblicazione
var _ascolto := 0.0          # secondi di quiete accanto allo stesso vicino
var _ascolto_chi := ""
var _oggi := 0

var _visitors: Node
var _player: Node3D
var _lavori: Node
var _legami: Node
var _affetti: Node
var _daynight: Node3D
var _arbitro: Node


func _ready() -> void:
	add_to_group("voce_sistema")
	add_to_group("persistable")
	# la stessa calma che fa posare le farfalle: un ascoltatore in più
	add_to_group("calma_listener")
	_cabla()


## IL CABLAGGIO SI RIPROVA (lezione del Taccuino): un call_deferred nel
## _ready non basta, perché il Regista e Accompagna sono figli RUNTIME di
## CozyWorld, che nasce su più frame. Costa qualche get_node nei primi
## secondi e poi zero, perché `_cablato` chiude la porta.
var _cablato := false

func _cabla() -> void:
	if _cablato:
		return
	if _visitors == null:
		_visitors = get_node_or_null("../Visitors")
	if _player == null:
		_player = get_node_or_null("../Player") as Node3D
	if _daynight == null:
		_daynight = get_node_or_null("../DayNight") as Node3D
		if _daynight:
			_daynight.connect("day_changed", _nuovo_giorno)
			_oggi = int(_daynight.get("day"))
	if _lavori == null:
		_lavori = get_tree().get_first_node_in_group("lavori")
	if _legami == null:
		_legami = get_tree().get_first_node_in_group("legami")
	if _affetti == null:
		_affetti = get_tree().get_first_node_in_group("affetti")
	if _arbitro == null:
		_arbitro = get_tree().get_first_node_in_group("arbitro_e")
		if _arbitro and _arbitro.has_method("iscrivi"):
			_arbitro.call("iscrivi", self, "voce", ARBITRO.VOLTO,
					Callable(self, "_in_gioco"), Callable(self, "_agisci"))
	_cablato = _visitors != null and _player != null and _daynight != null \
			and _lavori != null and _legami != null and _affetti != null \
			and _arbitro != null


## Il canale del Fiato Sospeso: la quiete pubblicata ogni frame che il
## fiato è attivo. Quando smette di arrivare, l'ascolto si spegne da solo.
func set_calma(quiete: float, pos: Vector3) -> void:
	_quiete = quiete
	_quiete_pos = pos
	_quiete_fresca = 0.0


func _process(delta: float) -> void:
	_cabla()
	_quiete_fresca += delta
	if _quiete_fresca > 0.4 or _quiete < QUIETE_MINIMA or not _voce.is_empty() \
			or _visitors == null:
		_ascolto = 0.0
		_ascolto_chi = ""
		return
	# chi è il vicino accanto? Se cambia, l'ascolto riparte: la fiducia
	# non si trasferisce da un orecchio all'altro
	var chi := _vicino_a(_quiete_pos, RAGGIO_ASCOLTO)
	if chi == "":
		_ascolto = 0.0
		_ascolto_chi = ""
		return
	if chi != _ascolto_chi:
		_ascolto_chi = chi
		_ascolto = 0.0
	_ascolto += delta
	if _ascolto >= TEMPO_CONFIDENZA:
		_ascolto = 0.0
		_prova_confidenza(chi)


func _vicino_a(pos: Vector3, raggio: float) -> String:
	var vicino := ""
	var d_min := raggio
	for label in _etichette():
		var node := _visitors.call("node_di", str(label)) as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var d: float = node.global_position.distance_to(pos)
		if d < d_min:
			d_min = d
			vicino = str(label)
	return vicino


func _etichette() -> Array:
	if _visitors and _visitors.has_method("etichette"):
		return _visitors.call("etichette")
	return []


## La porta della confidenza: le tre condizioni, tutte dai sistemi veri.
## Si bussa UNA volta al giorno per persona: la porta chiusa oggi non si
## tempesta di colpi.
func _prova_confidenza(label: String) -> void:
	if _confidato_oggi.get(label, false):
		return
	_confidato_oggi[label] = true
	var animo: RefCounted = _visitors.call("animo_oggetto_di", label)
	if animo == null:
		return
	var lim: RefCounted = animo.get("limbico")
	var giorni := 0
	if _legami and _legami.has_method("giorni_di_amicizia"):
		giorni = int(_legami.call("giorni_di_amicizia", label))
	if not si_confida(float(lim.get("umore")), float(lim.get("arousal")),
			float(lim.get("regolazione")), giorni, int(_riserbo.get(label, 0))):
		return
	var voce := pesca_voce(label, _dati_di(label, animo, lim), _oggi)
	if voce.is_empty():
		return
	_voce = voce
	_bolla(label, "…")
	_toast(_frase_confidenza(voce))
	_nota_regista("voce_ricevuta")


## Lo snapshot piatto per la logica pura: tutto stato vero, niente lore.
func _dati_di(label: String, animo: RefCounted, lim: RefCounted) -> Dictionary:
	var drive_male := {}
	for d in LAVORO_PER_DRIVE:
		drive_male[d] = float(animo.call("malessere", d))
	return {
		"marchi": lim.get("marchi"),
		"lavoro": str(_lavori.call("incarico", label)) if _lavori else "",
		"sogno": str(_visitors.call("sogno_di", label)),
		"amici_miei": _amici_di(label),
		"amici_loro": _amici_verso(label),
		"drive_male": drive_male,
		"gradino": int(animo.get("gradino")),
	}


func _amici_di(label: String) -> Dictionary:
	if _visitors and _visitors.has_method("amici_di"):
		return _visitors.call("amici_di", label)
	return {}


## Il lato OPPOSTO del grafo: quanto ciascun altro tiene a `label`.
func _amici_verso(label: String) -> Dictionary:
	var out := {}
	for altro in _etichette():
		if str(altro) == label:
			continue
		var suoi: Dictionary = _amici_di(str(altro))
		if suoi.has(label):
			out[altro] = suoi[label]
	return out


# ------------------------------------------------------------ la consegna

## Per l'arbitro: c'è una voce addosso e un VOLTO davanti — che non sia
## chi si è confidato (a lui non si riporta la sua stessa parola).
func _in_gioco() -> float:
	if _voce.is_empty() or scaduta(_voce, _oggi) or _visitors == null \
			or _player == null:
		return -1.0
	var chi := _vicino_a(_player.global_position, RAGGIO_CONSEGNA)
	if chi == "" or chi == str(_voce.get("da", "")):
		return -1.0
	var node := _visitors.call("node_di", chi) as Node3D
	if node == null:
		return -1.0
	return node.global_position.distance_to(_player.global_position)


func _agisci() -> void:
	if _voce.is_empty() or _player == null:
		return
	var dest := _vicino_a(_player.global_position, RAGGIO_CONSEGNA)
	if dest == "" or dest == str(_voce.get("da", "")):
		return
	consegna(dest)


## La consegna: si porta la parola come si porta un regalo. Il giusto e lo
## sbagliato li decidono i sistemi (destinatario_giusto è pura); in
## entrambi i casi la voce non è più tua — le parole non si riprendono.
func consegna(dest: String) -> void:
	var da := str(_voce.get("da", ""))
	var amici_da := _amici_di(da)
	var ctx := {
		"amici_di_da": amici_da,
		"sogno_dest": str(_visitors.call("sogno_di", dest)),
		"incarico_dest": str(_lavori.call("incarico", dest)) if _lavori else "",
		"piu_caro": piu_caro(amici_da),
	}
	if destinatario_giusto(_voce, dest, ctx):
		_conseguenza_giusta(dest)
		_nota_regista("voce_portata")
	else:
		_conseguenza_sbagliata(dest)
		_nota_regista("voce_sbagliata")
	_voce = {}


## GIUSTO: l'altro agisce, con i verbi che il villaggio già conosce.
## Niente di scritto apposta: manda, lega, dona, visita_serena, i gesti
## degli Affetti — e ogni toast afferma solo ciò che è successo davvero.
func _conseguenza_giusta(dest: String) -> void:
	var da := str(_voce.get("da", ""))
	var dettaglio := str(_voce.get("dettaglio", ""))
	match str(_voce.get("famiglia", "")):
		"paura":
			# l'amico lo accompagna fin là e non succede niente: è la
			# visita serena — l'estinzione dolce del marchio. Il posto
			# vero lo conosce Accompagna (fonte unica dei luoghi).
			var animo: RefCounted = _visitors.call("animo_oggetto_di", da)
			if animo:
				(animo.get("limbico") as RefCounted).call("visita_serena", dettaglio)
			var posto := _posizione_luogo(dettaglio)
			if posto.has("pos"):
				_manda(dest, posto["pos"])
				_manda(da, posto["pos"])
			else:
				_manda_incontro(dest, da)
			_gesto_affetti(dest, da, "coraggio")
			_toast(L10n.tf("%s ha capito. Prende %s per zampa: ci tornano insieme.",
					[dest, da]))
		"torto":
			# il lavoro passa a chi lo sognava: due torti si spengono in uno
			if _lavori and _lavori.has_method("assegna"):
				_lavori.call("assegna", da, "")
				_lavori.call("assegna", dest, dettaglio)
			var animo_da: RefCounted = _visitors.call("animo_oggetto_di", da)
			if animo_da:
				animo_da.call("ricorda", "sollievo", dest, 0.6, 0.7)
			_toast(L10n.tf("Gli occhi di %s si accendono: quel lavoro passa di mano. %s respira.",
					[dest, da]))
		"desiderio":
			# chi fa quel mestiere adesso sa per chi farlo
			if _visitors.has_method("dona_drive"):
				var quanto := -0.35 if dettaglio in ANIMO.MALESSERI else 0.35
				_visitors.call("dona_drive", da, dettaglio, quanto)
			_manda_incontro(dest, da)
			_toast(L10n.tf("%s ascolta, poi si avvia verso %s: certe cose si sistemano di persona.",
					[dest, da]))
		"affetto":
			# nasce un legame che non c'era: l'altro adesso lo sa. Il lato
			# di chi già amava non si tocca (forza_inversa lo conserva)
			var mio: float = float(_amici_di(da).get(dest, AFFETTO_MIO))
			if _visitors.has_method("lega_vicini"):
				_visitors.call("lega_vicini", dest, da, 0.62, mio)
			_gesto_affetti(dest, da, "fianco")
			_manda_incontro(dest, da)
			_toast(L10n.tf("%s adesso lo sa. E va da %s — certe parole vanno restituite di persona.",
					[dest, da]))
		"partenza":
			# il più caro non lo lascia solo: è la consolazione che pesa —
			# il ricordo buono che sconta i rancori e ferma la scala
			var animo_p: RefCounted = _visitors.call("animo_oggetto_di", da)
			if animo_p:
				animo_p.call("ricorda", "consolazione", dest, 0.85, 0.95)
			if _visitors.has_method("lega_vicini"):
				_visitors.call("lega_vicini", dest, da, 0.9)
			_gesto_affetti(dest, da, "consolazione")
			_manda_incontro(dest, da)
			_toast(L10n.tf("%s lascia tutto e corre da %s.", [dest, da]))


## SBAGLIATO: il danno lo fa il Limbico, onestamente. Il tradimento di una
## confidenza è IDENTITARIO (a chi ti tradisce non ci si abitua): rivaluta
## con identita=true marchia chi|giocatore da solo, e per giorni ti gira
## al largo. Poi la voce ormai è fuori: gli amici del destinatario
## sbagliato la sentono, smorzata come ogni voce che passa di bocca.
func _conseguenza_sbagliata(dest: String) -> void:
	var da := str(_voce.get("da", ""))
	var animo: RefCounted = _visitors.call("animo_oggetto_di", da)
	if animo:
		(animo.get("limbico") as RefCounted).call("rivaluta",
				"confidenza", "giocatore", TRADIMENTO, "", true)
	for amico in _amici_di(dest):
		var a: RefCounted = _visitors.call("animo_oggetto_di", str(amico))
		if a:
			a.call("senti_dire", dest, da, PETTEGOLEZZO_VALENZA, PETTEGOLEZZO_FORZA)
	_bolla(da, "…")
	_toast(L10n.tf("%s ammutolisce. Proprio da te non se l'aspettava.", [da]))


# ------------------------------------------------------------ il giorno

func _nuovo_giorno(giorno: int) -> void:
	_oggi = giorno
	_confidato_oggi = {}
	if _voce.is_empty() or not scaduta(_voce, _oggi):
		return
	# IL SILENZIO. La voce è scaduta senza essere portata: il Gufo l'ha
	# visto (il Taccuino ha già la forma esatta), e la fiducia sale —
	# chi custodisce le confidenze se ne merita di più.
	var da := str(_voce.get("da", ""))
	_riserbo[da] = int(_riserbo.get(da, 0)) + 1
	for regista in get_tree().get_nodes_in_group("regista"):
		if regista.has_method("annota"):
			regista.call("annota", {"oss": "voce_taciuta", "giorno": _oggi})
	_voce = {}
	_nota_regista("voce_taciuta")


# ------------------------------------------------------------ gli attrezzi

func _posizione_luogo(luogo: String) -> Dictionary:
	var acc := get_tree().get_first_node_in_group("accompagna")
	if acc and acc.has_method("posizione_del_luogo"):
		return acc.call("posizione_del_luogo", luogo)
	return {}


func _manda(label: String, pos: Vector3) -> void:
	if _visitors.has_method("manda"):
		_visitors.call("manda", label, pos)
	_bolla(label, "!")


func _manda_incontro(chi: String, verso: String) -> void:
	var node := _visitors.call("node_di", verso) as Node3D
	if node and is_instance_valid(node):
		_manda(chi, node.global_position)


func _gesto_affetti(da: String, verso: String, tipo: String) -> void:
	if _affetti and _affetti.has_method("gesto"):
		_affetti.call("gesto", da, verso, tipo)


func _bolla(label: String, simbolo: String) -> void:
	var node := _visitors.call("node_di", label) as Node3D
	if node and is_instance_valid(node) and node.has_method("chat_bubble"):
		node.call("chat_bubble", simbolo)


func _toast(testo: String) -> void:
	if testo != "" and _visitors and _visitors.has_method("_show_toast"):
		_visitors.call("_show_toast", testo)


func _nota_regista(evento: String) -> void:
	for regista in get_tree().get_nodes_in_group("regista"):
		if regista.has_method("note"):
			regista.call("note", evento)


## La frase con cui la confidenza arriva: corta, in prima persona, senza
## nomi di sistema. Il luogo si dice con l'articolo (LUOGO_DETTO) e si
## traduce al momento di mostrare, mai prima.
func _frase_confidenza(voce: Dictionary) -> String:
	var da := str(voce.get("da", ""))
	var dettaglio := str(voce.get("dettaglio", ""))
	match str(voce.get("famiglia", "")):
		"paura":
			var luogo := str(LUOGO_DETTO.get(dettaglio, dettaglio))
			return L10n.tf("%s, piano: «C'è un posto dove non riesco più a passare… %s.»",
					[da, L10n.t(luogo)])
		"torto":
			return L10n.tf("%s, piano: «Questo lavoro non è per me. Ma a chi lo dico?»", [da])
		"desiderio":
			match dettaglio:
				"sicurezza":
					return L10n.tf("%s, piano: «La notte non mi sento al sicuro. Non so a chi dirlo.»", [da])
				"fatica":
					return L10n.tf("%s, piano: «Ho una stanchezza addosso che non passa. Non so a chi dirlo.»", [da])
				_:
					return L10n.tf("%s, piano: «I giorni sono tutti uguali. Non so a chi dirlo.»", [da])
		"affetto":
			return L10n.tf("%s, piano: «%s non sa quanto conta per me. E io non riesco a dirglielo.»",
					[da, dettaglio])
		"partenza":
			return L10n.tf("%s, pianissimo: «Sto pensando di andarmene. Non l'ho detto a nessuno.»", [da])
	return ""


## Per la UI e per le prove dal vivo: la voce addosso adesso, o {}.
func voce_attiva() -> Dictionary:
	return _voce.duplicate(true)


# ------------------------------------------------------------ persistenza

func save_extra() -> Dictionary:
	return {"voce": {"attiva": _voce, "riserbo": _riserbo}}


func load_extra(data: Dictionary) -> void:
	var v: Variant = data.get("voce", {})
	if v is not Dictionary:
		return
	var d: Dictionary = v
	var attiva: Variant = d.get("attiva", {})
	_voce = attiva if attiva is Dictionary else {}
	# il salvataggio è JSON: il giorno torna float, si rimette intero
	if _voce.has("giorno"):
		_voce["giorno"] = int(_voce["giorno"])
	var ris: Variant = d.get("riserbo", {})
	_riserbo = ris if ris is Dictionary else {}
	for k in _riserbo:
		_riserbo[k] = int(_riserbo[k])
