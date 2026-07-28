extends RefCounted

## L'ANIMO di un chibi: la vita interiore che lo fa sembrare una persona.
##
## Non è un albero di comportamenti né una macchina a stati: è un piccolo
## apparato di pressioni, ricordi e carattere che produce decisioni — e che
## sa SPIEGARE ogni decisione all'indietro.
##
## LA REGOLA D'ORO DI QUESTO FILE: la percezione d'intelligenza non nasce
## dalla complessità, nasce dalla LEGGIBILITÀ. Un NPC che si ribella senza
## che il giocatore possa ricostruire il perché non sembra intelligente:
## sembra un bug. Perciò ogni pressione, ogni ricordo e ogni scatto di
## ribellione si porta dietro la sua causa, e `racconta()` la restituisce in
## italiano, in ordine di importanza. Se un domani cambierai i numeri, cambia
## anche ciò che il chibi dice: un sistema che mente al giocatore è peggio
## di un sistema stupido.
##
## Tutto qui dentro è PURO: nessun nodo, nessun SceneTree, nessun tempo di
## gioco. Entra il DNA e una cronaca di eventi, esce una decisione e il suo
## perché. Così la parte più delicata del gioco si verifica headless
## (tests/cases/test_animo.gd) invece che a occhio, sperando che si veda.
##
## L'IBRIDO CON I MODELLI LINGUISTICI: questo apparato decide COSA fa il
## chibi — deterministico, ispezionabile, gratis. Un eventuale LLM può
## riscrivere COME lo dice, partendo da `racconta()`. Mai il contrario: se il
## modello decidesse lo stato di gioco, addio coerenza e addio debug.

# ============================================================ i drive
# Sei pressioni interne, 0..1. Attenzione alla POLARITÀ, che è mista apposta
# per restare leggibile a chi legge i numeri nel debugger:
#   fatica e noia      -> 1 = malissimo (sono malesseri che salgono)
#   gli altri quattro  -> 1 = benissimo (sono beni che si consumano)
# Il resto del file non ragiona mai sui valori grezzi ma su `malessere()`,
# che li riporta tutti sulla stessa scala: 0 = sto bene, 1 = non ce la faccio.
const DRIVES := ["fatica", "noia", "sicurezza", "autonomia", "appartenenza", "stima"]
const MALESSERI := ["fatica", "noia"]     # questi salgono; gli altri calano

## Quanto ogni drive torna da solo verso il riposo, al giorno.
const RIENTRO := {
	"fatica": 0.55, "noia": 0.22, "sicurezza": 0.18,
	"autonomia": 0.15, "appartenenza": 0.12, "stima": 0.10,
}

# ============================================================ i tratti
# I tratti NON sono comportamenti: sono PESI. Due chibi nella stessa
# identica situazione reagiscono diversamente ma coerentemente con chi sono.
# È questa la fonte dell'imprevedibilità: il caso puro fa sembrare gli NPC
# scemi, la varianza di carattere li fa sembrare persone.
const TRATTI := ["orgoglio", "lealta", "grinta", "codardia", "ambizione"]

# ============================================================ la ribellione
## La ribellione è una SCALA, non un interruttore. Ogni gradino telegrafa il
## successivo: il giocatore deve poter vedere che sta perdendo qualcuno, e
## avere il tempo di rimediare.
const SCALA := [
	"lavoro", "svogliato", "attrezzi", "rifiuto",
	"sabotaggio", "confronto", "diserzione", "ammutinamento",
]

## Quanto rancore serve per salire ogni gradino (prima dei tratti).
const SOGLIA := {
	"lavoro": 0.0, "svogliato": 0.18, "attrezzi": 0.32, "rifiuto": 0.46,
	"sabotaggio": 0.60, "confronto": 0.70, "diserzione": 0.82,
	"ammutinamento": 0.93,
}

# ------------------------------------------------ leggere la scala da fuori
# SCALA qui sopra è l'UNICA definizione dei gradini in tutto il gioco: nessun
# altro file deve riscriverne la lista né gli indici a mano (prima Lavori
# teneva una copia dell'elenco e Visitors due indici magici, 5 e 6: aggiungere
# un gradino in mezzo li faceva puntare al gradino sbagliato, in silenzio).
# Si interroga SEMPRE per nome, con questi tre metodi.

## L'indice di un gradino ("diserzione" -> 6), o -1 se il nome non esiste.
static func indice(gradino: String) -> int:
	return SCALA.find(gradino)


## Il chibi è a questo gradino o oltre? (`gradino_idx` è `Animo.gradino`.)
static func almeno(gradino_idx: int, gradino: String) -> bool:
	var i := indice(gradino)
	return i >= 0 and gradino_idx >= i


## Quanto è avanti sulla scala, da 0 (sereno) a 1 (ammutinamento).
static func frazione(gradino_idx: int) -> float:
	if SCALA.size() <= 1:
		return 0.0
	return clampf(float(gradino_idx) / float(SCALA.size() - 1), 0.0, 1.0)


## Cosa si vede addosso a un chibi a ogni gradino: il gioco lo mostra con
## postura, sguardi e una battuta. Senza questo, la scala è invisibile e
## tanto varrebbe avere l'interruttore.
const TELEGRAFO := {
	"lavoro": ["sereno", "Buongiorno!"],
	"svogliato": ["spalle_basse", "…arrivo, sì, arrivo."],
	"attrezzi": ["distratto", "Oh. Ho scordato l'ascia. Di nuovo."],
	"rifiuto": ["braccia_conserte", "Oggi no. Chiedilo a qualcun altro."],
	"sabotaggio": ["sguardo_sfuggente", "Strano, era a posto ieri sera…"],
	"confronto": ["petto_in_fuori", "Possiamo parlare? Adesso."],
	"diserzione": ["fagotto_in_spalla", "Ho lasciato le mie cose in ordine. Addio."],
	"ammutinamento": ["testa_alta", "Non sei più tu a decidere per noi."],
}

# ============================================================ la memoria
## Dopo quanti giorni un ricordo pesa la metà. Il rancore non è eterno: si
## può rimediare, ed è ciò che rende il sistema un dialogo e non una condanna.
const MEZZA_VITA := 18.0
## Oltre questo numero i ricordi non spariscono: si FONDONO in un sommario
## (tipo+attore -> quante volte, quanto pesavano). È l'aggregazione a creare
## la frase «mi hai mandato a spaccare legna quarantasette volte»: senza,
## quarantasette episodi diventerebbero sei e il senso andrebbe perso.
const RICORDI_VIVI := 40
## Quanto in fretta il rancore ripetuto satura. TARATO SUL BRIEF: quaranta
## giorni di lavoro che tradisce un sogno devono portare alla ribellione, non
## due. Con 9.0 un solo giorno valeva già mezzo rancore e la scala scattava il
## primo giorno: sembrava un capriccio, non una memoria. Con 55 il primo
## giorno vale il 5%, dieci giorni un terzo, quaranta giorni quasi tutto —
## e nel mezzo c'è il tempo di accorgersene e rimediare.
const SATURAZIONE := 55.0

## Quanto conta, per un chibi, che il compito tradisca il suo sogno.
## Mandare a spaccare legna chi voleva diventare guerriero brucia molto più
## in fretta che mandarci chi voleva fare il boscaiolo.
const CONTRO_SOGNO := 3.0
const VERSO_SOGNO := 0.35

## Che sogno serve un compito. Chi ha quel sogno lo vive come un passo avanti,
## chi ha un sogno che il compito tradisce lo vive come tempo rubato.
const COMPITI := {
	"taglia_legna": {"serve": "boscaiolo", "tradisce": ["guerriero", "artista"],
			"fatica": 0.22, "noia": 0.16, "autonomia": -0.06},
	"coltiva": {"serve": "giardiniere", "tradisce": ["guerriero"],
			"fatica": 0.14, "noia": 0.10, "autonomia": -0.04},
	"cucina": {"serve": "cuoco", "tradisce": ["guerriero"],
			"fatica": 0.10, "noia": 0.08, "autonomia": -0.03},
	"guardia": {"serve": "guerriero", "tradisce": ["artista", "giardiniere"],
			"fatica": 0.16, "noia": 0.20, "sicurezza": -0.05},
	"esplora": {"serve": "esploratore", "tradisce": [],
			"fatica": 0.18, "noia": -0.25, "autonomia": 0.08},
	"riposa": {"serve": "", "tradisce": [],
			"fatica": -0.45, "noia": 0.06},
	"festa": {"serve": "", "tradisce": [],
			"noia": -0.30, "appartenenza": 0.18, "fatica": 0.05},
}

const SOGNI := ["boscaiolo", "giardiniere", "cuoco", "guerriero", "artista", "esploratore"]

# ============================================================ stato

var nome := "chibi"
var sogno := "boscaiolo"
var tratti := {}          # nome tratto -> 0..1
var drive := {}           # nome drive -> 0..1
var ricordi: Array = []   # {tipo, attore, quando, valenza, intensita}
var sommario := {}        # "tipo|attore" -> {"n": int, "peso": float, "ultimo": int}
var opinione := {}        # attore -> -1..1 (il giocatore è "giocatore")
var legami := {}          # nome di un altro chibi -> -1..1 (quanto gli si crede)
var gradino := 0          # dove sta sulla SCALA
var scatti: Array = []    # la cronaca degli scatti: {giorno, da, a, cause}
var oggi := 0
var _voce_del_giorno := {}   # chi mi ha già parlato oggi
var _ultimo_scatto := -99   # il giorno dell'ultimo scatto: uno al giorno, non di più

## L'APPARATO LIMBICO (scenes/npc/Limbico.gd): sta SOTTO tutto questo.
## L'animo ragiona sui ricordi; il limbico decide come quei ricordi vengono
## SENTITI mentre si formano — con la sorpresa, l'umore e il corpo di mezzo.
var limbico = preload("res://scenes/npc/Limbico.gd").new()

var _rng := RandomNumberGenerator.new()


# ---------------------------------------------------------------- nascita

## Costruisce l'animo dal genoma. I tratti e il sogno si DERIVANO dal seme
## quando il DNA non li porta ancora: i residenti salvati prima di questo
## sistema ricevono così un carattere stabile, sempre lo stesso, invece di
## cambiare personalità a ogni avvio.
func setup(dna: Dictionary, seed_v := -1) -> void:
	nome = str(dna.get("name", dna.get("nome", "chibi")))
	var s: int = int(dna.get("seed", seed_v))
	if s < 0:
		s = abs(hash(nome))
	_rng.seed = s

	var dnat: Dictionary = dna.get("tratti", {})
	for t in TRATTI:
		if dnat.has(t):
			tratti[t] = clampf(float(dnat[t]), 0.0, 1.0)
		else:
			# non uniforme: i caratteri estremi devono essere RARI, o il
			# villaggio diventa un carnevale di orgogliosi e codardi
			tratti[t] = clampf((_rng.randf() + _rng.randf()) * 0.5, 0.0, 1.0)
	sogno = str(dna.get("sogno", SOGNI[_rng.randi() % SOGNI.size()]))
	limbico.setup(tratti)

	for d in DRIVES:
		drive[d] = 0.12 if d in MALESSERI else 0.85


## Il carattere in una riga, per il diario e per il debug.
func descrizione() -> String:
	var forti := []
	for t in TRATTI:
		if float(tratti.get(t, 0.0)) > 0.66:
			forti.append(t)
	if forti.is_empty():
		forti.append("equilibrat" + ("o" if _rng.randf() < 0.5 else "a"))
	return "%s, sogna di fare %s (%s)" % [nome, sogno, ", ".join(forti)]


# ---------------------------------------------------------------- i drive

## Quanto un drive sta male, 0..1, su scala unica (vedi la nota in testa).
func malessere(d: String) -> float:
	var v: float = float(drive.get(d, 0.0))
	return clampf(v if d in MALESSERI else 1.0 - v, 0.0, 1.0)


## Il malessere complessivo: la media pesata dai tratti. Un ambizioso soffre
## la noia molto più di un altro; un orgoglioso, la stima calpestata.
func disagio() -> float:
	var pesi := {
		"fatica": 1.0,
		"noia": 0.6 + 0.9 * float(tratti.get("ambizione", 0.5)),
		"sicurezza": 0.7 + 1.0 * float(tratti.get("codardia", 0.5)),
		"autonomia": 0.7 + 0.9 * float(tratti.get("orgoglio", 0.5)),
		"appartenenza": 0.7 + 0.7 * float(tratti.get("lealta", 0.5)),
		"stima": 0.6 + 1.1 * float(tratti.get("orgoglio", 0.5)),
	}
	var somma := 0.0
	var tot := 0.0
	for d in DRIVES:
		var p: float = pesi[d]
		somma += malessere(d) * p
		tot += p
	return somma / maxf(0.001, tot)


## Un giorno passa: i drive rientrano piano verso il riposo. La grinta aiuta
## a scrollarsi di dosso la fatica; la lealtà tiene caldo il senso di
## appartenenza anche quando non succede nulla.
func passa_giorno() -> void:
	oggi += 1
	limbico.passa_giorno()
	var recupero := 0.7 + 0.6 * float(tratti.get("grinta", 0.5))
	for d in DRIVES:
		var r: float = float(RIENTRO[d]) * (recupero if d == "fatica" else 1.0)
		if d in MALESSERI:
			drive[d] = clampf(float(drive[d]) - r, 0.0, 1.0)
		else:
			drive[d] = clampf(float(drive[d]) + r * 0.5, 0.0, 1.0)
	_potatura()


# ---------------------------------------------------------------- gli eventi

## Il chibi ha fatto un compito perché gliel'hai chiesto tu.
## È il canale principale del risentimento: qui l'evento viene VALUTATO
## contro il sogno di chi lo esegue, ed è quella valutazione — non il compito
## in sé — a decidere quanto brucia.
func esegue(compito: String, ordinante := "giocatore") -> void:
	var c: Dictionary = COMPITI.get(compito, {"fatica": 0.12, "noia": 0.10})
	for d in DRIVES:
		if not c.has(d):
			continue
		var delta: float = float(c[d])
		if d in MALESSERI:
			drive[d] = clampf(float(drive[d]) + delta, 0.0, 1.0)
		else:
			drive[d] = clampf(float(drive[d]) + delta, 0.0, 1.0)

	# la classificazione va fatta PRIMA dello scaling dell'ambizione: dopo,
	# mult non è più confrontabile (il ramo `mult == VERSO_SOGNO` diventava
	# irraggiungibile e il lavoro-del-sogno maturava un ricordo NEGATIVO;
	# e `mult > 1.0` scattava anche sui compiti neutri degli ambiziosi,
	# marchiandoli come tradimenti d'identità)
	var e_sogno := str(c.get("serve", "")) == sogno
	var e_tradito := sogno in (c.get("tradisce", []) as Array)
	var mult := 1.0
	if e_sogno:
		mult = VERSO_SOGNO                 # è un passo verso il suo sogno
		drive["stima"] = clampf(float(drive["stima"]) + 0.05, 0.0, 1.0)
	elif e_tradito:
		mult = CONTRO_SOGNO                # gli stai rubando la vita
	# l'ambizione rende ogni compito umile più amaro
	mult *= 0.75 + 0.5 * float(tratti.get("ambizione", 0.5))
	var valenza := 0.12 if e_sogno else (-0.28 * mult if e_tradito else -0.08 * mult)
	# se il compito tradisce il sogno, l'evento tocca l'IDENTITÀ: non ci si
	# abitua, ci si sensibilizza (vedi Limbico.rivaluta)
	ricorda(compito, ordinante, valenza, 0.5 + 0.5 * minf(1.0, mult / CONTRO_SOGNO),
			"", e_tradito)


## Un fatto qualunque della vita del villaggio.
## [param valenza] -1 (terribile) .. +1 (bellissimo); [param intensita] 0..1.
func ricorda(tipo: String, attore: String, valenza: float, intensita := 0.5,
		luogo := "", identita := false) -> void:
	# IL FATTO PASSA DAL CORPO PRIMA DI DIVENTARE RICORDO. Quello che resta
	# non è ciò che è successo, ma quanto ha sorpreso: il decimo regalo si
	# incide poco, una gentilezza dopo il gelo si incide profondissima.
	var letto: Dictionary = limbico.rivaluta(tipo, attore, valenza, luogo, identita)
	var sentito: float = float(letto["sentito"])
	ricordi.append({
		"tipo": tipo, "attore": attore, "quando": oggi,
		"valenza": clampf(sentito, -1.0, 1.0), "intensita": clampf(intensita, 0.0, 1.0),
		"come": str(letto["perche"]),
	})
	if sentito < 0.0:
		drive["stima"] = clampf(float(drive["stima"]) + sentito * 0.12 * intensita, 0.0, 1.0)
	# si pota SUBITO, non solo al cambio di giorno: in una giornata sola
	# possono succedere cento cose, e i ricordi vivi devono restare pochi
	# perché il sommario (quello che sa dire «quarantasette volte») si riempia
	_potatura()


## Un lutto ignorato: il caso che il brief cita, e che deve pesare tanto.
## Non è il lutto a fare rancore verso di te — è l'INDIFFERENZA.
func lutto(amico: String, consolato_da := "") -> void:
	drive["appartenenza"] = clampf(float(drive["appartenenza"]) - 0.35, 0.0, 1.0)
	ricorda("lutto", amico, -0.8, 1.0)
	if consolato_da == "":
		# nessuno si è fatto vivo: il rancore va a chi comanda il villaggio
		ricorda("lutto_ignorato", "giocatore", -0.7,
				0.7 + 0.3 * float(tratti.get("lealta", 0.5)))
	else:
		ricorda("consolato", consolato_da, 0.6, 0.8)
		drive["appartenenza"] = clampf(float(drive["appartenenza"]) + 0.22, 0.0, 1.0)


# i ricordi vecchi non svaniscono: si fondono nel sommario, che è ciò che
# permette di dire «quarantasette volte» invece di «qualche volta»
func _potatura() -> void:
	while ricordi.size() > RICORDI_VIVI:
		var r: Dictionary = ricordi.pop_front()
		var k := "%s|%s" % [r["tipo"], r["attore"]]
		var voce: Dictionary = sommario.get(k, {"n": 0, "peso": 0.0, "ultimo": 0})
		voce["n"] = int(voce["n"]) + 1
		voce["peso"] = float(voce["peso"]) + float(r["valenza"]) * float(r["intensita"])
		voce["ultimo"] = maxi(int(voce["ultimo"]), int(r["quando"]))
		sommario[k] = voce


func _recenza(quando: int) -> float:
	return pow(0.5, float(oggi - quando) / MEZZA_VITA)


## Quante volte è successo (ricordi vivi + sommario): il numero che il chibi
## userà per rinfacciartelo.
func quante_volte(tipo: String, attore := "") -> int:
	var n := 0
	for r in ricordi:
		if r["tipo"] == tipo and (attore == "" or r["attore"] == attore):
			n += 1
	for k in sommario:
		var parti: PackedStringArray = k.split("|")
		if parti[0] == tipo and (attore == "" or parti[1] == attore):
			n += int(sommario[k]["n"])
	return n


## Il rancore verso qualcuno: 0 (nessuno) .. 1 (insopportabile).
## È una saturazione, non una somma: cento torti non fanno un rancore cento
## volte più grande, ma quarantasette pesano molto più di cinque.
func rancore(attore := "giocatore") -> float:
	var somma := 0.0
	for r in ricordi:
		if r["attore"] != attore or float(r["valenza"]) >= 0.0:
			continue
		somma += -float(r["valenza"]) * float(r["intensita"]) * _recenza(int(r["quando"]))
	for k in sommario:
		var parti: PackedStringArray = k.split("|")
		if parti.size() < 2 or parti[1] != attore:
			continue
		var v: Dictionary = sommario[k]
		if float(v["peso"]) >= 0.0:
			continue
		somma += -float(v["peso"]) * _recenza(int(v["ultimo"]))
	# il perdono: i ricordi belli scontano il rancore
	var buoni := 0.0
	for r in ricordi:
		if r["attore"] == attore and float(r["valenza"]) > 0.0:
			buoni += float(r["valenza"]) * float(r["intensita"]) * _recenza(int(r["quando"]))
	somma = maxf(0.0, somma - buoni * 1.4)
	return 1.0 - exp(-somma / SATURAZIONE * 3.0)


# ---------------------------------------------------------------- la scala

## Le soglie di QUESTO chibi: i tratti le spostano, ed è qui che due
## caratteri diversi prendono strade diverse davanti allo stesso torto.
## Un codardo non ti verrà mai a cercare: sparisce. Un orgoglioso non
## sabota alle spalle: ti affronta in faccia.
func soglie() -> Dictionary:
	var org: float = float(tratti.get("orgoglio", 0.5))
	var lea: float = float(tratti.get("lealta", 0.5))
	var cod: float = float(tratti.get("codardia", 0.5))
	var gri: float = float(tratti.get("grinta", 0.5))
	var out := {}
	for g in SCALA:
		out[g] = float(SOGLIA[g])
	# la lealtà alza TUTTE le soglie: un leale sopporta molto più a lungo
	for g in SCALA:
		out[g] = float(out[g]) + lea * 0.22
	# l'orgoglioso arriva prima al confronto, ma disdegna il sabotaggio
	out["confronto"] = float(out["confronto"]) - org * 0.26
	out["sabotaggio"] = float(out["sabotaggio"]) + org * 0.30
	# il codardo non affronta mai nessuno: salta il confronto e scappa prima
	out["confronto"] = float(out["confronto"]) + cod * 0.60
	out["ammutinamento"] = float(out["ammutinamento"]) + cod * 0.40
	out["diserzione"] = float(out["diserzione"]) - cod * 0.28
	# chi ha grinta non fa la vittima: salta il lavoro sciatto
	out["svogliato"] = float(out["svogliato"]) + gri * 0.18
	out["rifiuto"] = float(out["rifiuto"]) - gri * 0.10
	return out


## Ricalcola il gradino. Sale di UNO alla volta — mai due — perché ogni
## gradino deve poter essere visto e corretto: è la promessa che facciamo al
## giocatore. Scendere invece è libero: rimediare deve dare sollievo subito.
func aggiorna_scala(verso := "giocatore") -> bool:
	var r := rancore(verso)
	# LA SCALA LA GUIDA IL RANCORE ACCUMULATO, non il malumore di giornata.
	# Prima il disagio pesava quanto il rancore e bastavano quattro giorni di
	# lavoro pesante per arrivare al confronto: sembrava isteria, non memoria.
	# Ora la stanchezza può al massimo ANTICIPARE di poco uno scatto che il
	# rancore stava già preparando — e non può da sola portare oltre il
	# rifiuto, perché essere stanchi non è avere qualcosa contro qualcuno.
	var spinta: float = r + minf(disagio() * 0.18, 0.14)
	if r < 0.30:
		spinta = minf(spinta, float(SOGLIA["rifiuto"]) - 0.01)
	var s := soglie()
	var target := 0
	for i in SCALA.size():
		if spinta >= float(s[SCALA[i]]):
			target = i
	var prima := gradino
	if target > gradino:
		# UNO SCATTO AL GIORNO, mai due. È la promessa che facciamo al
		# giocatore: ogni gradino dev'essere visto prima che arrivi il
		# successivo. Senza questo freno, un giro di pettegolezzi poteva
		# far salire due gradini nella stessa giornata e il telegrafo
		# diventava illeggibile.
		if oggi - _ultimo_scatto < 1:
			return false
		gradino += 1
		_ultimo_scatto = oggi
	elif target < gradino:
		# scendere richiede di essere andati BEN sotto la soglia del gradino
		# attuale: senza isteresi un chibi al confine oscillava avanti e
		# indietro ogni giorno, e sembrava indeciso invece che ferito
		var s_giu: float = float(s[SCALA[gradino]]) - 0.06
		if spinta > s_giu:
			return false
		gradino = target
		_ultimo_scatto = oggi
	if gradino != prima:
		scatti.append({"giorno": oggi, "da": SCALA[prima], "a": SCALA[gradino],
				"cause": cause(verso)})
		return true
	return false


## Cosa si vede addosso adesso: [postura, battuta]. Il telegrafo del gradino.
func telegrafo() -> Array:
	return TELEGRAFO.get(SCALA[gradino], ["sereno", "…"])


func stato() -> String:
	return SCALA[gradino]


# ---------------------------------------------------------------- decidere

## Il punteggio di un'azione: pressioni interne pesate dal carattere, più il
## peso dei ricordi e l'opinione sociale su chi la chiede.
func punteggio(azione: String, chiede := "giocatore") -> float:
	var c: Dictionary = COMPITI.get(azione, {})
	var s := 0.0
	# quanto quell'azione allevia ciò che sta pesando ORA
	for d in DRIVES:
		if not c.has(d):
			continue
		var delta: float = float(c[d])
		var sollievo: float = (-delta if d in MALESSERI else delta)
		s += sollievo * malessere(d) * 2.2
	# il sogno tira: si fa volentieri ciò che ci avvicina a chi vogliamo essere
	if str(c.get("serve", "")) == sogno:
		s += 0.45 * (0.5 + float(tratti.get("ambizione", 0.5)))
	elif sogno in (c.get("tradisce", []) as Array):
		s -= 0.5 * (0.5 + float(tratti.get("orgoglio", 0.5)))
	# i ricordi: se questo compito ti ha già bruciato, pesa
	s -= 0.5 * minf(1.0, float(quante_volte(azione, chiede)) / 25.0)
	# l'opinione su chi chiede, e il gradino della scala
	s += float(opinione.get(chiede, 0.0)) * 0.6
	s -= float(gradino) / float(SCALA.size()) * 1.2
	return s


## Sceglie fra le azioni possibili. NON prende il massimo: campiona pesato
## fra le prime tre. Prendere sempre il massimo rende gli NPC prevedibili e
## meccanici; campiare fra le migliori li rende vivi restando sensati — non
## faranno mai la cosa assurda, ma nemmeno sempre la stessa.
func decide(azioni: Array, chiede := "giocatore") -> String:
	if azioni.is_empty():
		return ""
	var voti := []
	for a in azioni:
		voti.append({"a": a, "s": punteggio(a, chiede)})
	voti.sort_custom(func(x, y): return float(x["s"]) > float(y["s"]))
	var top: Array = voti.slice(0, mini(3, voti.size()))
	# softmax povero: si sposta tutto sopra lo zero e si pesa
	var base: float = float(top[top.size() - 1]["s"])
	var tot := 0.0
	for v in top:
		tot += exp((float(v["s"]) - base) * 1.6)
	var tiro := _rng.randf() * tot
	for v in top:
		tiro -= exp((float(v["s"]) - base) * 1.6)
		if tiro <= 0.0:
			return str(v["a"])
	return str(top[0]["a"])


# ---------------------------------------------------------------- il contagio

## Il pettegolezzo: quello che è successo a un altro chibi arriva qui.
## Quanto attecchisce dipende da quanto gli si crede (legame) e da quanto
## questo chibi è leale a chi comanda. È da qui che nascono le cascate:
## nessuno le scrive, si formano da sole quando le soglie sono giuste.
func senti_dire(da: String, su: String, valenza: float, forza := 1.0) -> float:
	var credito: float = clampf(float(legami.get(da, 0.25)), -1.0, 1.0)
	if credito <= 0.0:
		return 0.0          # da chi non stimi, le voci non attecchiscono
	var resistenza: float = float(tratti.get("lealta", 0.5)) if su == "giocatore" else 0.0
	var peso: float = credito * forza * (1.0 - resistenza * 0.75)
	if peso <= 0.001:
		return 0.0
	opinione[su] = clampf(float(opinione.get(su, 0.0)) + valenza * peso * 0.35, -1.0, 1.0)
	# IL PETTEGOLEZZO SPOSTA L'OPINIONE, NON RIEMPIE LA MEMORIA. Prima ogni
	# voce diventava un ricordo: in cinquanta giorni ne restavano centinaia,
	# e «sentito_dire × 161» finiva in cima alla spiegazione, scavalcando il
	# motivo vero. Una frase così non dice niente a chi gioca. Ora si segna
	# solo la voce del giorno, e solo se ha spostato qualcosa davvero.
	if peso >= 0.18 and int(_voce_del_giorno.get(da, -1)) != oggi:
		_voce_del_giorno[da] = oggi
		ricorda("sentito_dire", su, valenza * peso, minf(1.0, absf(peso)))
	return peso


## Quanto questo chibi "irradia" quando si ribella: un ammutinato pesa molto
## più di uno svogliato, e uno che tutti stimano più di un solitario.
func eco() -> float:
	return frazione(gradino) \
			* (0.5 + 0.5 * float(tratti.get("orgoglio", 0.5)))


# ---------------------------------------------------------------- IL PERCHÉ
# La parte che rende il sistema un sistema e non un generatore di rumore.

## Le cause del suo stato d'animo, dalla più pesante alla più lieve.
## Ogni voce: {"peso": 0..1, "testo": "…"}. È la materia prima della
## ricostruzione a posteriori — e ciò che un LLM dovrebbe riscrivere, senza
## MAI inventarsi cause che qui non ci sono.
func cause(verso := "giocatore") -> Array:
	var out := []
	# 1) i compiti ripetuti, con il numero in chiaro
	var conteggi := {}
	for r in ricordi:
		if r["attore"] == verso and float(r["valenza"]) < 0.0:
			conteggi[r["tipo"]] = int(conteggi.get(r["tipo"], 0)) + 1
	for k in sommario:
		var parti: PackedStringArray = k.split("|")
		if parti.size() > 1 and parti[1] == verso and float(sommario[k]["peso"]) < 0.0:
			conteggi[parti[0]] = int(conteggi.get(parti[0], 0)) + int(sommario[k]["n"])
	for tipo in conteggi:
		var n: int = conteggi[tipo]
		if n < 2:
			continue
		if tipo == "sentito_dire":
			# il numero di voci non significa nulla per chi gioca: conta che
			# il villaggio mormori, non quante volte l'abbia sentito dire
			out.append({"peso": minf(0.45, 0.12 + float(n) / 60.0),
					"testo": L10n.t("nel villaggio se ne parla male")})
			continue
		var c: Dictionary = COMPITI.get(tipo, {})
		var extra := ""
		if sogno in (c.get("tradisce", []) as Array):
			extra = " " + L10n.tf("(e lui sognava di fare %s)", [L10n.t(sogno)])
		# I TORTI CONCRETI VENGONO SEMPRE PRIMA DEI SINTOMI. Un giocatore può
		# agire su «ti ho mandato a spaccare legna sei volte»; su «stima al
		# limite» no — quello è l'effetto, non la causa. Perciò anche un
		# conteggio piccolo parte da 0.35 e scavalca ogni pressione interna.
		out.append({"peso": minf(1.0, 0.35 + float(n) / 30.0),
				"testo": "%s × %d%s" % [L10n.t(str(tipo)), n, extra]})
	# 2) i colpi singoli che hanno lasciato il segno.
	#    Solo quelli NON già raccontati dal conteggio qui sopra: elencare
	#    quaranta volte «taglia_legna» dopo aver detto «taglia_legna × 40» è
	#    il modo più sicuro di rendere illeggibile una spiegazione giusta.
	for r in ricordi:
		if int(conteggi.get(str(r["tipo"]), 0)) >= 2:
			continue
		if float(r["valenza"]) > -0.45:
			continue
		var p: float = -float(r["valenza"]) * float(r["intensita"]) * _recenza(int(r["quando"]))
		if p < 0.12:
			continue
		var testo := ""
		match str(r["tipo"]):
			"lutto":
				testo = L10n.tf("ha perso %s", [r["attore"]])
			"lutto_ignorato":
				testo = L10n.t("e nessuno gli è stato vicino")
			"sentito_dire":
				testo = L10n.tf("gira voce su %s", [r["attore"]])
			_:
				testo = "%s (%s)" % [L10n.t(str(r["tipo"])), r["attore"]]
		out.append({"peso": clampf(p, 0.0, 1.0), "testo": testo})
	# 3) le pressioni interne che stanno sopra la soglia del sopportabile
	for d in DRIVES:
		var m := malessere(d)
		if m > 0.55:
			# tetto a 0.33: le pressioni interne raccontano COME sta, non
			# PERCHÉ — e non devono mai finire in cima alla spiegazione
			out.append({"peso": m * 0.33, "testo": L10n.tf("%s al limite", [L10n.t(str(d))])})
	out.sort_custom(func(a, b): return float(a["peso"]) > float(b["peso"]))
	return out


## La catena causale in italiano, pronta da mostrare. È LA funzione del file:
## se il giocatore legge questa riga e dice «ah, ecco perché», il sistema ha
## funzionato; se dice «e questo da dove esce?», abbiamo sbagliato noi.
func racconta(verso := "giocatore", quante := 3) -> String:
	var c := cause(verso)
	if c.is_empty():
		return L10n.tf("%s non ha nulla da rimproverarti.", [nome])
	var pezzi := []
	for i in mini(quante, c.size()):
		pezzi.append(str(c[i]["testo"]))
	var corpo: String = limbico.stato_corpo()
	var coda := "" if corpo == "tranquillo" else " (%s)" % L10n.t(corpo)
	return L10n.tf("%s è a «%s»%s: %s.",
			[nome, L10n.t(str(SCALA[gradino])), coda, " · ".join(pezzi)])


## LO SFOGO: cosa ti dice in faccia, con i fatti in mano.
##
## Non una frase generica di rabbia: i FATTI, quelli che il sistema ha
## davvero contato. È la differenza fra un NPC che urla e uno che ti fa
## sentire in colpa — e fra i due, solo il secondo si racconta agli amici.
## Se un domani ci metti un modello linguistico sopra, dagli QUESTA roba da
## riscrivere: mai lasciargli inventare i fatti.
func sfogo() -> String:
	var c := cause()
	if c.is_empty():
		return L10n.t("Non è niente. Lascia stare.")
	var primo := str(c[0]["testo"])
	# il torto principale, detto come lo direbbe lui
	var apertura := L10n.t("Ti rendi conto?")
	if float(tratti.get("orgoglio", 0.5)) > 0.65:
		apertura = L10n.t("Guardami quando ti parlo.")
	elif float(tratti.get("codardia", 0.5)) > 0.65:
		apertura = L10n.t("Scusa… posso dirti una cosa?")
	var corpo_frase := primo
	# se c'è un secondo motivo, si aggiunge: sono le catene a fare male
	if c.size() > 1:
		corpo_frase = L10n.tf("%s, e %s", [corpo_frase, str(c[1]["testo"])])
	var chiusa := L10n.t("Non lo faccio più.")
	if almeno(gradino, "diserzione"):
		chiusa = L10n.t("Me ne vado.")
	elif float(tratti.get("lealta", 0.5)) > 0.6:
		chiusa = L10n.t("Io ti sono stato accanto. Tu no.")
	var trattenuto: String = limbico.perche_scoppio()
	if trattenuto != "":
		chiusa += " (%s)" % trattenuto
	return "%s %s. %s" % [apertura, corpo_frase, chiusa]


## La cronaca degli scatti: quando è salito di gradino e perché, allora.
## Serve al giocatore per ricostruire la storia dopo, non solo adesso.
func diario() -> Array:
	var out := []
	for s in scatti:
		var c: Array = s["cause"]
		var motivo := str(c[0]["testo"]) if not c.is_empty() else L10n.t("malessere")
		out.append(L10n.tf("giorno %d: %s → %s (%s)",
				[s["giorno"], L10n.t(str(s["da"])), L10n.t(str(s["a"])), motivo]))
	return out


# ---------------------------------------------------------------- salvataggio

func save() -> Dictionary:
	return {
		"nome": nome, "sogno": sogno, "tratti": tratti.duplicate(),
		"drive": drive.duplicate(), "ricordi": ricordi.duplicate(true),
		"sommario": sommario.duplicate(true), "opinione": opinione.duplicate(),
		"legami": legami.duplicate(), "gradino": gradino,
		"scatti": scatti.duplicate(true), "oggi": oggi, "ultimo_scatto": _ultimo_scatto,
		"limbico": limbico.save(),
	}


func load(d: Dictionary) -> void:
	nome = str(d.get("nome", nome))
	sogno = str(d.get("sogno", sogno))
	tratti = (d.get("tratti", tratti) as Dictionary).duplicate()
	drive = (d.get("drive", drive) as Dictionary).duplicate()
	ricordi = (d.get("ricordi", []) as Array).duplicate(true)
	sommario = (d.get("sommario", {}) as Dictionary).duplicate(true)
	opinione = (d.get("opinione", {}) as Dictionary).duplicate()
	legami = (d.get("legami", {}) as Dictionary).duplicate()
	gradino = int(d.get("gradino", 0))
	scatti = (d.get("scatti", []) as Array).duplicate(true)
	oggi = int(d.get("oggi", 0))
	_ultimo_scatto = int(d.get("ultimo_scatto", -99))
	if d.has("limbico"):
		limbico.load(d["limbico"])
