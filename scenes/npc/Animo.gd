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
const DERIVA := preload("res://scenes/npc/Deriva.gd")
## LO SCHEMA DEL SÉ: chi si sacrifica quando la memoria è piena. Puro e
## statico, e — per costruzione — CIECO all'attore.
const SCHEMA := preload("res://scenes/npc/Schema.gd")
const RILETTURA := preload("res://scenes/npc/Rilettura.gd")
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

## QUANTE PROVE SATURANO LA FIDUCIA.
##
## ⚠️ **NON è `SATURAZIONE`, e non ricopiarla È la decisione — la trappola qui
## SEMBRA la regola delle fonti uniche e la viola.** Quel 55 è tarato su una
## serie che SENSIBILIZZA (`Limbico.rivaluta` spinge verso −0.30 sui torti
## d'identità); i doni invece ABITUANO, e il loro asintoto è molto più basso.
## Rapporto misurato: **4,5 volte**. Con 55 questa funzione non supererebbe
## **0.24 in nessuna partita possibile** — cioè dichiarerebbe 0..1 e non
## arriverebbe a un quarto.
##
## La fonte unica vincola la FORMA (`1 − exp(−x/S·3)`) e la RECENZA
## (`_recenza`, `MEZZA_VITA`), non lo scalare di scala: è esattamente quello
## che ha già fatto `Deriva.SAZIETA := 8.0`.
##
## L'UNITÀ, dichiarata: **venti gesti veri del giocatore, sparsi su una
## settimana, valgono 1 − 1/e** (≈0,63). Chi la muove resti fra 5 e 15 e porti
## la misura.
const SAZIETA_FIDUCIA := 12.0

## QUANTO PUÒ SMORZARE, al massimo, il logorio della richiesta ripetuta.
##
## Non è scelto: è DERIVATO. L'effetto massimo vale `SMORZO_FIDUCIA * 0.5` =
## 0.20, e deve restare sotto il **tiro del sogno più debole** —
## `0.45 * (0.5 + ambizione)` con ambizione a zero, cioè 0.225. La fiducia in
## chi chiede non può MAI pesare quanto la vocazione, né quanto il carattere
## (`AMPIEZZA_TRATTO`). Un test legge le due costanti dal sorgente invece di
## riscriverle.
const SMORZO_FIDUCIA := 0.4

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
	# IL SALONE. Chi ha in mano l'aspetto degli altri fa un mestiere
	# leggero di corpo e pesante di testa: stanca poco, annoia
	# pochissimo (ogni testa e' diversa) e riempie di APPARTENENZA —
	# passi la giornata a parlare con tutti. Ma chiede autonomia: e'
	# l'estetista a decidere il taglio, non chi glielo ordina.
	"abbellisce": {"serve": "estetista", "tradisce": ["guerriero", "boscaiolo"],
			"fatica": 0.09, "noia": -0.06, "appartenenza": 0.14,
			"autonomia": -0.08, "stima": 0.06},
	# SUONARE non stanca quasi e annoia zero: e' la cosa che l'artista
	# farebbe comunque. Ma paga in STIMA piu' di ogni altro mestiere —
	# gli applausi sono l'unica retribuzione del palco — e costa in
	# autonomia, perche' un concerto ha un'ora e un pubblico che aspetta.
	"suona": {"serve": "artista", "tradisce": ["guerriero", "boscaiolo"],
			"fatica": 0.07, "noia": -0.14, "appartenenza": 0.16,
			"autonomia": -0.10, "stima": 0.13},
}

## COSA SI FA QUANDO CI SI RITROVA SOLI. Non e' una tabella di eventi: e'
## una tabella di BISOGNI, letta dallo stesso `punteggio()` che sceglie il
## mestiere del giorno — quindi la risposta esce dal carattere di chi
## risponde, e due persone diverse rispondono in modo diverso senza che
## nessuno scriva «se orgoglioso allora».
##
## Nessuna di queste e' una punizione e nessuna e' un fallimento. Il gioco
## non prende posizione su quale sia quella giusta: le pesa soltanto sui
## bisogni di chi le sceglie.
##
## E OGNUNA HA UNA CHIAVE A FORMA DI GIOCATORE (`Affetti.MOMENTI_CHIAVE`):
## nessuna ferita che questi sistemi creano puo' restare senza una porta —
## e' la stessa regola per cui `_filtra_luogo` esiste.
## Quanto pesa il CARATTERE su una risposta. Deve essere della stessa scala
## del tiro del sogno (±0.45..±1.05), perché è l'unico termine che sopravvive
## quando i bisogni sono tutti a posto — cioè nella vita normale di un
## vicino, che è il caso COMUNE.
##
## Senza, misurato: sette punteggi a 0.000000, il softmax su tre pareggi, e
## un dado uniforme sulle prime tre chiavi nell'ordine in cui la tabella è
## scritta — identico per un orgoglioso e per un codardo. Il commento che
## prometteva «o chi guarda vede un dado» descriveva il comportamento vero.
const AMPIEZZA_TRATTO := 0.9

## `tratto` è chi sceglie quella risposta, e `verso` da che parte: +1 se la
## sceglie chi ha molto di quel tratto, −1 se chi ne ha poco.
const REAZIONI := {
	# la porta che non si apre piu': chi ha molto orgoglio la sente come
	# l'unico modo di riprendersi qualcosa di suo
	"chiudo_la_porta": {"tratto": "orgoglio", "verso": 1, "autonomia": 0.30, "stima": 0.22, "appartenenza": -0.25},
	# ritirarsi: chi ha paura sceglie il posto dove non succede niente
	"mi_ritiro": {"tratto": "codardia", "verso": 1, "sicurezza": 0.35, "appartenenza": -0.30, "noia": 0.10},
	# stare col piccolo — possibile solo se un piccolo c'e'
	"sto_col_piccolo": {"tratto": "lealta", "verso": 1, "appartenenza": 0.26, "sicurezza": 0.12, "autonomia": -0.18},
	# andarsene: serve tanto bisogno di autonomia e poche radici
	"me_ne_vado": {"tratto": "ambizione", "verso": 1, "autonomia": 0.45, "appartenenza": -0.45, "stima": 0.10},
	# dirlo a tutti: il villaggio si schiera, e a qualcuno serve
	"lo_dico_a_tutti": {"tratto": "grinta", "verso": 1, "stima": 0.25, "appartenenza": 0.15, "sicurezza": -0.10},
	# fare finta di niente, che e' una risposta come le altre
	"faccio_finta": {"tratto": "grinta", "verso": -1, "sicurezza": 0.15, "stima": -0.10, "noia": -0.05},
	# restare, e aspettare. La piu' rara, e l'unica che puo' finire bene
	"resto_e_aspetto": {"tratto": "orgoglio", "verso": -1, "appartenenza": 0.12, "autonomia": -0.15, "sicurezza": 0.08},
}

## Quanto e' DECISA una risposta come queste. Alta: una scelta che cambia
## una vita non puo' essere una moneta appena sbilanciata, o chi guarda
## vede un dado invece di una persona.
const NITIDEZZA_VITA := 4.5

## I sogni che un chibi puo' avere. In coda i nuovi, MAI in mezzo: la
## generazione del DNA pesca per indice e infilarne uno a meta' cambierebbe
## il sogno di ogni residente gia' nato (a parita' di seed).
const SOGNI := ["boscaiolo", "giardiniere", "cuoco", "guerriero", "artista",
		"esploratore", "estetista"]

# ============================================================ stato

var nome := "chibi"
var sogno := "boscaiolo"
## ⚠️ SOLO PER IL BANCO: rimette la potatura FIFO di prima (`pop_front`).
## Serve al CONTROLLO di `tools/misura_memoria.gd`, perché le due
## previsioni — convergenza col FIFO, divergenza con lo schema del sé —
## sono opposte e si misurano APPAIATE: il termine di paragone dev'essere
## il vecchio codice VERO, non una sua imitazione riscritta nel banco (un
## doppio che mente è peggio di nessun doppio).
## Nel gioco non la accende nessuno, e un caso di `test_schema` scandaglia
## `scenes/` e `systems/` perché resti così.
var debug_potatura_fifo := false
## ⚠️ SOLO PER IL BANCO: spegne la rilettura e lascia solo il morso della
## lingua, cioè il gioco di prima. Serve al braccio di CONTROLLO di
## `tools/misura_rilettura.gd` — «quanto costa NON rileggere» si misura
## appaiato, e la rilettura cambia la storia di quel vicino, quindi l'A/B
## non può stare dentro una corsa sola (la stessa eccezione, con la stessa
## ragione, delle cricche).
## Nel gioco non la accende nessuno, e un caso di `test_rilettura`
## scandaglia `scenes/` e `systems/` perché resti così.
var debug_niente_rilettura := false
var tratti := {}          # nome tratto -> 0..1
var drive := {}           # nome drive -> 0..1
var ricordi: Array = []   # {tipo, attore, quando, valenza, intensita}
var sommario := {}        # "tipo|attore" -> {"n": int, "peso": float, "ultimo": int}
var opinione := {}        # attore -> -1..1 (il giocatore è "giocatore")
var legami := {}          # nome di un altro chibi -> -1..1 (quanto gli si crede)
var gradino := 0          # dove sta sulla SCALA
## QUANTO SCONTA UN RICORDO BELLO. Era un letterale in mezzo a `rancore()`;
## adesso ha un nome perche' ha un SECONDO lettore: la valenza del sollievo
## in Villaggio si deriva da qui (1/SCONTO_PERDONO), invece di essere un
## secondo numero da tenere allineato a mano.
const SCONTO_PERDONO := 1.4

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
	# alla nascita non c'e' nessuna prova, quindi δ = 0 — ma la chiamata c'e'
	# lo stesso, perche' e' lei a riproiettare il corpo dai tratti.
	_deriva_giorno = -1
	_ricalcola_deriva()

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
	sincronizza_neuro()


## Mappatura dei 6 drive sui corrispondenti canali neurochimici del Limbico:
## - fatica -> adenosina
## - noia -> dopamina
## - sicurezza -> cortisolo / serotonina
## - appartenenza -> ossitocina
## - stima & autonomia -> serotonina / endorfine
func sincronizza_neuro() -> void:
	if limbico == null:
		return
	# ⚠️ **I BISOGNI SPOSTANO IL PUNTO DI RIPOSO, NON IL LIVELLO.** Prima
	# questa funzione ASSEGNAVA cinque canali su sette, e la chiamano sei
	# posti diversi (`setup`, `passa_giorno`, `esegue`, `ricorda`, `lutto`,
	# `load`) piu' `Visitors`: ogni impulso degli eventi veniva cancellato
	# dal primo fatto qualunque del villaggio. MISURATO: la chiacchierata
	# portava l'ossitocina a 1.0000, e un `ricorda()` la riportava a 0.7575.
	# Il piatto caldo, l'onsen e la chiacchierata non contavano niente — in
	# silenzio, con la suite verde.
	#
	# E c'era di peggio sul cortisolo: il ri-aggancio era un `max()`, cioe'
	# **solo verso l'alto**. Misurato nell'ordine vero di `_give_dish`: un
	# vicino con `sicurezza = 0.30` si sveglia guarito dalla notte (0.0800),
	# il giocatore gli porta un piatto caldo, e resta con **0.4400** — cioe'
	# il gesto piu' affettuoso del gioco lo lasciava piu' teso di come si era
	# svegliato. Adesso il piatto sposta il livello (in giu', come deve) e i
	# drive spostano soltanto il posto dove il livello torna.
	var m_fatica: float = malessere("fatica")
	var m_noia: float = malessere("noia")
	var m_sicurezza: float = malessere("sicurezza")
	var aut_val: float = float(drive.get("autonomia", 0.5))
	var app_val: float = float(drive.get("appartenenza", 0.5))
	var stima_val: float = float(drive.get("stima", 0.5))
	var base: Dictionary = limbico.neuro_base
	# 1. Fatica -> Adenosina (pressione omeostatica del sonno)
	base["adenosina"] = clampf(m_fatica, 0.0, 1.0)
	# 2. Noia -> Dopamina (l'assenza di novità la deprime; l'autonomia la sostiene)
	base["dopamina"] = clampf((1.0 - m_noia) * 0.55 + aut_val * 0.35 + 0.05, 0.0, 1.0)
	# 3. Sicurezza -> Cortisolo. Nessun `max()`: chi sta bene torna giu'.
	base["cortisolo"] = clampf(maxf(float(limbico.NEURO_BASELINE["cortisolo"]),
			m_sicurezza * 0.8), 0.0, 1.0)
	# 4. Appartenenza -> Ossitocina (calore sociale, fiducia e legame)
	base["ossitocina"] = clampf(app_val * 0.75 + 0.12, 0.0, 1.0)
	# 5. Stima & Autonomia -> Serotonina ed Endorfine
	base["serotonina"] = clampf(stima_val * 0.55 + aut_val * 0.35 + 0.10, 0.0, 1.0)
	base["endorfine"] = clampf(stima_val * 0.35 + (1.0 - m_fatica) * 0.45 + 0.10, 0.0, 1.0)
	# 6. ⚠️ **E POI IL CARATTERE**, che e' uno scarto e non una scrittura.
	# Le cinque righe qui sopra assegnano; il carattere ci si somma sopra. Se
	# invece riassegnasse, cancellerebbe i bisogni — cioe' il difetto che la
	# testata di questa funzione documenta, rifatto un piano piu' giu'. Un
	# carattere medio somma zero esatto: per lui non e' cambiato niente.
	limbico.applica_tinta(base)


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
## QUANTO PESA UN BISOGNO PER QUESTA PERSONA. È il carattere fatto numero:
## l'ambizioso soffre la noia, il codardo l'insicurezza, l'orgoglioso la
## stima negata, il leale la solitudine.
##
## Viveva dentro `disagio()`, e `punteggio()` NON LO CHIAMAVA: due vicini con
## gli stessi bisogni ricevevano punteggi identici su ogni azione, qualunque
## fosse il loro carattere. Il motore delle scelte era cieco proprio alla
## cosa che doveva renderle diverse — e finché lo era, «libero arbitrio»
## non poteva essere altro che un dado.
func peso_drive(d: String) -> float:
	match d:
		"fatica":
			return 1.0
		"noia":
			return 0.6 + 0.9 * tratto("ambizione")
		"sicurezza":
			return 0.7 + 1.0 * tratto("codardia")
		"autonomia":
			return 0.7 + 0.9 * tratto("orgoglio")
		"appartenenza":
			return 0.7 + 0.7 * tratto("lealta")
		"stima":
			return 0.6 + 1.1 * tratto("orgoglio")
	return 1.0


func disagio() -> float:
	var pesi := {}
	for d in DRIVES:
		pesi[d] = peso_drive(d)
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
	_ricalcola_deriva()
	limbico.passa_giorno()
	var recupero := 0.7 + 0.6 * tratto("grinta")
	for d in DRIVES:
		var r: float = float(RIENTRO[d]) * (recupero if d == "fatica" else 1.0)
		if d in MALESSERI:
			drive[d] = clampf(float(drive[d]) - r, 0.0, 1.0)
		else:
			drive[d] = clampf(float(drive[d]) + r * 0.5, 0.0, 1.0)
	sincronizza_neuro()
	_potatura()


# ---------------------------------------------------------------- gli eventi

## Il chibi ha fatto un compito perché gliel'hai chiesto tu.
## È il canale principale del risentimento: qui l'evento viene VALUTATO
## contro il sogno di chi lo esegue, ed è quella valutazione — non il compito
## in sé — a decidere quanto brucia.
## Torna il `sentito` che il compito ha inciso — vedi `ricorda()`: chi vuole
## sapere com'è andata NON deve dedurlo da `ricordi.back()`.
func esegue(compito: String, ordinante := "giocatore") -> float:
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
	mult *= 0.75 + 0.5 * tratto("ambizione")
	var valenza := 0.12 if e_sogno else (-0.28 * mult if e_tradito else -0.08 * mult)
	# se il compito tradisce il sogno, l'evento tocca l'IDENTITÀ: non ci si
	# abitua, ci si sensibilizza (vedi Limbico.rivaluta)
	var sentito := ricorda(compito, ordinante, valenza,
			0.5 + 0.5 * minf(1.0, mult / CONTRO_SOGNO), "", e_tradito)
	sincronizza_neuro()
	return sentito


## Un fatto qualunque della vita del villaggio.
## [param valenza] -1 (terribile) .. +1 (bellissimo); [param intensita] 0..1.
## ⚠️ **TORNA IL `sentito` CHE HA APPENA INCISO, e non è una comodità.**
## `Visitors.assegna_compito` leggeva `ricordi[size-1]` per sapere com'era
## andata — una deduzione che il FIFO garantiva (`pop_front` non può togliere
## la riga appena appesa) e che la potatura per SCHEMA DEL SÉ **rompe**: fra
## righe dello stesso tipo scritte lo stesso giorno il `recente` è 1.0 per
## tutte e `quanti` è identico, quindi decide `PESO_FORZA * forza` — e
## `Limbico.rivaluta` incide ogni ripetizione MENO della precedente, cioè la
## riga appena scritta ha la forza minima ed è proprio lei la vittima.
##
## Concreto: residente a quaranta ricordi vivi, il giocatore gli riassegna lo
## stesso compito una seconda volta nello stesso giorno; la riga nuova viene
## potata dentro `ricorda()`, e tre righe dopo `ricordi.back()` è un'ALTRA —
## per esempio il lutto di un amico a −0.8. Parte `_marchia("luogo|bosco",
## −0.8)`, e alla seconda volta quel posto supera `SOGLIA_EVITAMENTO`: il
## vicino comincia a evitare il bosco per via di un lutto.
##
## La riga non si deduce dall'array: si fa restituire.
func ricorda(tipo: String, attore: String, valenza: float, intensita := 0.5,
		luogo := "", identita := false) -> float:
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
	sincronizza_neuro()
	# si pota SUBITO, non solo al cambio di giorno: in una giornata sola
	# possono succedere cento cose, e i ricordi vivi devono restare pochi
	# perché il sommario (quello che sa dire «quarantasette volte») si riempia
	_potatura()
	return sentito


## Un lutto ignorato: il caso che il brief cita, e che deve pesare tanto.
## Non è il lutto a fare rancore verso di te — è l'INDIFFERENZA.
## [param quanto] e' QUANTO CONTAVA quella persona, 0..1 — e di serie vale
## 1.0, che e' esattamente il comportamento di prima.
##
## ⚠️ **Prima era scritto a mano, uguale per tutti**, e con `Congedo` che
## mette in lutto ogni residente il risultato era che una partenza toccava
## dodici persone allo stesso identico modo. Il grado deve nascere gia'
## distribuito, e a distribuirlo non e' una curva inventata: e' il libro
## mastro degli Affetti, letto **in assoluto**. Mai normalizzato sul massimo
## del villaggio — normalizzare su un massimo E' una classifica, ed e' il no
## numero due della regola sacra.
func lutto(amico: String, consolato_da := "", quanto := 1.0) -> void:
	var q: float = clampf(quanto, 0.0, 1.0) if is_finite(quanto) else 1.0
	drive["appartenenza"] = clampf(float(drive["appartenenza"]) - 0.35, 0.0, 1.0)
	ricorda("lutto", amico, -0.8, q)
	if consolato_da == "":
		# nessuno si è fatto vivo: il rancore va a chi comanda il villaggio
		ricorda("lutto_ignorato", "giocatore", -0.7,
				0.7 + 0.3 * tratto("lealta"))
	else:
		ricorda("consolato", consolato_da, 0.6, 0.8)
		drive["appartenenza"] = clampf(float(drive["appartenenza"]) + 0.22, 0.0, 1.0)
	sincronizza_neuro()


# i ricordi vecchi non svaniscono: si fondono nel sommario, che è ciò che
# permette di dire «quarantasette volte» invece di «qualche volta»
func _potatura() -> void:
	# ⚠️ NON PIÙ `pop_front()`. Era un FIFO, cioè una memoria ordinata solo
	# dal tempo — e siccome `cause()` cerca i «colpi singoli che hanno
	# lasciato il segno» SOLO fra i ricordi vivi (i compiti ripetuti li
	# conta anche dal sommario), il FIFO cancellava esattamente gli
	# episodi UNICI e teneva quelli frequenti. Col tempo ogni vicino
	# finiva per saper dire soltanto la cosa che il giocatore fa più
	# spesso: convergenza, e non per caso — per aritmetica.
	#
	# Adesso si sceglie chi sacrificare, come fa `Legami.indice_da_potare`
	# col filo dei momenti e come fa già il grafo dei ricordi in C++.
	# ⚠️ E la scelta è CIECA ALL'ATTORE per firma, non per disciplina:
	# `SCHEMA.scheda()` costruisce una vista senza quel campo. Proteggere
	# «chi me l'ha fatto» invece di «cosa mi è successo» trasformerebbe la
	# potatura in un archivio di rancori — e la chiave del sommario è
	# letteralmente `"tipo|attore"`, quindi sarebbe la gogna dalla porta
	# di servizio.
	# ⚠️ **LE SCHEDE SI COSTRUISCONO SOLO SE C'È DA POTARE.** La prima
	# stesura le faceva SEMPRE, prima di guardare la condizione del `while`
	# — cioè anche nel caso comune, in cui l'array è sotto il tetto e non si
	# pota niente. `ricorda()` gira a ogni evento della vita del villaggio, e
	# `scheda()` alloca un Dictionary e chiama `congruenza()` **e** `verso()`
	# per ogni ricordo vivo: quaranta Dictionary e ottanta ricerche in
	# tabella per una chiamata che non fa niente.
	#
	# Dove si vedeva: la partenza di un vicino mette in lutto OGNI residente
	# e `Animo.lutto()` chiama `ricorda()` due volte — con ventotto vicini
	# sono ~56 potature complete nello stesso fotogramma, cioè la scena
	# dell'addio, che è la più coreografata del gioco. E la suite intera è
	# passata da ~90 s a oltre sette minuti di CPU il giorno in cui `verso()`
	# si è aggiunto a `congruenza()` dentro `scheda()`.
	#
	# Col `pop_front()` era O(1) e zero allocazioni; adesso è O(n²), ma
	# **solo quando pota davvero**.
	var schede: Array = []
	while ricordi.size() > RICORDI_VIVI:
		if schede.is_empty() and not debug_potatura_fifo:
			for r0 in ricordi:
				schede.append(SCHEMA.scheda(r0, sogno, COMPITI))
		var vittima := 0
		if not debug_potatura_fifo:
			vittima = SCHEMA.indice_da_sacrificare(schede, oggi, MEZZA_VITA)
			if vittima < 0:
				# tutto intoccabile: meglio sforare di uno che buttare un
				# ricordo insostituibile (la valvola di `Legami`)
				break
		var r: Dictionary = ricordi[vittima]
		ricordi.remove_at(vittima)
		if not debug_potatura_fifo:
			schede.remove_at(vittima)
		# ⚠️ E LA RIGA POTATA FINISCE COMUNQUE NEL SOMMARIO, come sempre:
		# la potatura non cancella un fatto, gli toglie la CITABILITÀ come
		# episodio. `quante_volte()`, `rancore()` e il primo punto di
		# `cause()` continuano a contare tutto — cambia soltanto che cosa
		# un vicino sa ancora dire come episodio singolo, che è
		# esattamente la cosa che dice chi è.
		var k := "%s|%s" % [r["tipo"], r["attore"]]
		var voce: Dictionary = sommario.get(k, {"n": 0, "peso": 0.0, "ultimo": 0})
		voce["n"] = int(voce["n"]) + 1
		voce["peso"] = float(voce["peso"]) + float(r["valenza"]) * float(r["intensita"])
		voce["ultimo"] = maxi(int(voce["ultimo"]), int(r["quando"]))
		sommario[k] = voce


## QUANTO PESA ANCORA, OGGI, CIO' CHE NON C'E' PIU'. 0.0 .. 1.0.
##
## Non e' un campo e non e' un bit: e' una LETTURA di due cose che stavano
## gia' nel salvataggio da sempre — la recenza dell'ultimo ricordo di
## perdita, e quanto e' scavato il senso di appartenenza. Il prodotto di due
## numeri che ci sono gia', come `coppia()` e' il minimo reciproco di due
## conti che ci sono gia'. **Zero chiavi nuove, zero migrazioni**: un
## salvataggio di ieri riaperto oggi risponde 0.0 per tutti, perche' nessuno
## ha una riga «lutto», e il gioco e' quello di prima.
##
## ⚠️ **LEGGE UN TIPO SOLO, ed e' la regola «il giocatore non puo' causarla»
## scritta in una riga.** `RICORDO_PERDITA` e' `"lutto"` e basta: NON
## `"lutto_ignorato"`, che e' la riga che `lutto()` incide contro il
## GIOCATORE quando nessuno si e' fatto vivo. Se questa funzione la
## leggesse, chi non ha fatto in tempo a salutare ventisette persone in tre
## giornate avrebbe causato lui lo stato che dura — per una cosa che non ha
## fatto, a scala di villaggio.
##
## ⚠️ **E il `quando` si cerca anche nel SOMMARIO.** `_potatura()` fa
## `pop_front()` sopra i quaranta ricordi vivi, quindi la riga del lutto
## finisce nel sommario in poche giornate di villaggio vivace — e il
## sommario non si pota mai. Guardare solo `ricordi` darebbe un substrato
## che sparisce **proprio dove il villaggio e' pieno di vita**, cioe' dove
## nessun collaudo arriva.
const RICORDO_PERDITA := "lutto"


func assenza() -> float:
	var quando := -1
	var intensita := 0.0
	for r in ricordi:
		if str(r.get("tipo", "")) != RICORDO_PERDITA:
			continue
		var q := int(r.get("quando", 0))
		if q >= quando:
			quando = q
			intensita = float(r.get("intensita", 1.0))
	for k in sommario:
		if not str(k).begins_with(RICORDO_PERDITA + "|"):
			continue
		var v: Dictionary = sommario[k]
		var q2 := int(v.get("ultimo", 0))
		if q2 >= quando:
			quando = q2
			intensita = maxf(intensita, float(v.get("intensita", 1.0)))
	if quando < 0:
		return 0.0
	return assenza_da(oggi - quando, intensita,
			float(drive.get("appartenenza", 0.5)))


## La forma della cosa, senza lo stato: pura, e provabile senza villaggio.
##
## Il primo fattore e' `_recenza` — la STESSA curva, con la STESSA
## `MEZZA_VITA` — cioe' l'orologio piu' lento che questo gioco possieda:
## diciotto giornate sono settantadue minuti reali. Il secondo e' la
## profondita', ed e' quello che il giocatore e il villaggio possono
## muovere: `passa_giorno` riempie l'appartenenza da sola, e ogni gesto
## gentile la riempie prima.
##
## Il prodotto ha la forma giusta **senza che nessuno la disegni**: una
## settimana acuta, e poi una coda lunga e fioca. Non c'e' nessuna curva da
## tarare — ci sono due orologi che il gioco aveva gia'.
static func assenza_da(giorni: int, intensita: float, appartenenza: float) -> float:
	if giorni < 0 or not is_finite(intensita) or not is_finite(appartenenza):
		return 0.0
	return pow(0.5, float(giorni) / MEZZA_VITA) \
			* clampf(intensita, 0.0, 1.0) \
			* clampf(1.0 - appartenenza, 0.0, 1.0)


# ================= I DUE VOLTI DI UN TRATTO ==========================
#
# ⚠️ **LA REGOLA, e vale per tutti i ventuno lettori dei tratti di questo
# gioco: la deriva entra dove il tratto COLORA, e non entra in nessuna
# funzione la cui uscita e' una PORTA, una SOGLIA o una FRASE.**
#
# Non e' pignoleria, ed e' costata due vie d'uscita dal genere trovate
# leggendo il codice:
#
#  · `soglie()` abbassa il gradino della DISERZIONE di `codardia × 0.28`, e
#    sotto quella soglia c'e' `Visitors._congeda()`. Con la deriva dentro,
#    «protetto e nutrito» diventerebbe **«se ne va prima»**: il giocatore
#    perderebbe i vicini di cui si e' occupato di piu'. Misurato: 0.35 di
#    codardia si mangia il 60% del campo naturale fra quattordici residenti.
#  · `Affetti.conto()` calcola la mezza vita dei ricordi con la lealta' e la
#    applica a **tutte** le righe, comprese quelle di sei mesi fa. Una lealta'
#    che deriva **riscriverebbe il passato**, e potrebbe sciogliere una
#    coppia senza che nessuno abbia fatto niente — perche' `ancora_coppia()`
#    e' un confronto fra conti, e una mezza vita piu' corta schiaccia il
#    passato e lascia in piedi il recente. La mezza vita e' la grammatica con
#    cui si legge la storia, non un colore.
#
# E il TESTO legge la base per una ragione piu' semplice: quello che uno dice
# quando sbotta e' chi e' sempre stato.

## δ per tratto. **NON entra in `save()`**: si ricava dalle prove, che sono
## gia' persistite. E' una cache, non uno stato.
var _deriva := {}
var _deriva_giorno := -1
## Le giornate passate con qualcuno, prestate da `Cricche` una volta al
## giorno. **Non si salva**: sta nel registro delle cricche, che e' gia'
## persistito, e ricopiarla qui sarebbe la seconda casa di un dato solo.
var compagnia: Array = []
## QUANTO GLI MANCA A CRESCERE: 0 appena nato, 1 finito — e **1 per chiunque
## non sia nato qui**, che è il valore di serie e vuol dire «il gioco di
## ieri, bit per bit». Prestata da `Visitors` come si presta la compagnia, e
## per la stessa ragione: `Animo` non ha un orologio e non deve averne uno.
##
## ⚠️ **NON SI SALVA**, e non è una comodità: la sua casa è già nel
## salvataggio (`legami → <nome> → giorno_arrivo`), e una seconda copia qui
## sarebbe la seconda casa di un dato solo. È la decisione fondativa di
## `Deriva`: la deriva è una LETTURA, non uno stato.
##
## ⚠️ E a differenza della compagnia **non vuole nessuna traduzione fra i due
## orologi**: l'età è una DURATA, non una data. Chi un domani la ricalcasse
## sulla compagnia per simmetria applicherebbe una conversione che qui è
## sbagliata.
var crescita := 1.0


## IL TRATTO DI ADESSO — chi vuole il tratto lo chiede QUI, e solo qui.
##
## ⚠️ **LA COMPOSIZIONE NON SI RIFÀ A MANO: la fa `Deriva`.** Qui c'era
## `clampf(base + δ, 0, 1)` ricopiato, cioè esattamente quello che
## `Deriva.derivato()` esiste per centralizzare — e infatti `derivato` non
## aveva **nessun chiamante di produzione**: le undici chiamate che lo
## esercitano stanno tutte nei test (`test_deriva`, `test_finestra`), cioè
## sorvegliavano una funzione che il gioco non chiamava, e chi avesse rotto
## QUESTA riga li avrebbe lasciati tutti verdi.
##
## E la copia era già DIVERGENTE, non solo ridondante: là la BASE si clampa
## **prima** di sommare, qui no. Con un `tratti` sporco a 1.4 (un salvataggio
## vecchio, un banco, un `set()` sbagliato) e δ = −0.1, la riga di qui dava
## `clampf(1.3) = 1.0` e la funzione dava `clampf(1.0 − 0.1) = 0.9` — cioè un
## dato rotto portava il tratto al muro passando dalla porta di servizio. Due
## clamp scritti in due posti divergono al primo che ne ritocca uno.
##
## `componi(base, δ)` e non `derivato(base, pressione, plasticita)` perché il
## δ qui è già calcolato: `_ricalcola_deriva()` lo fa **una volta al giorno**
## (e la spinta costa una scansione di tutti i ricordi). Passare da `derivato`
## vorrebbe dire rifare quella scansione a ogni lettura di un tratto, cioè
## decine di volte per fotogramma per residente — e con una `pressione` che
## qui non abbiamo nemmeno in mano.
## ⚠️⚠️ **E LA COMPOSIZIONE È SCRITTA QUI IN LINEA, NON CHIAMATA — perché
## una chiamata statica costa 23 volte tanto, MISURATO.**
##
## Una revisione avversariale ha chiesto (giustamente) che la composizione
## avesse un posto solo: `Deriva.componi(base, scarto)`. Sostituita qui, la
## suite è passata da ~90 secondi a **oltre sette minuti di CPU**. Il conto,
## cronometrato su due milioni di giri: l'aritmetica in linea **116 ms**, la
## stessa cosa attraverso `DERIVA.componi` **2725 ms** — un fattore
## **23,4×**. In GDScript una statica raggiunta da un `const preload` non è
## una chiamata a buon mercato, e `tratto()` è una delle funzioni più calde
## del gioco: la leggono `peso_drive`, `punteggio` (per ogni azione di ogni
## decisione), `soglie()`, `_tratti_derivati()`, gli Affetti.
##
## Il buco che quella richiesta voleva chiudere era vero — se qualcuno
## rompesse questa riga, gli undici casi che esercitano `Deriva.derivato`
## resterebbero verdi — ma si chiude con una GUARDIA, non con una chiamata:
## `test_finestra._la_composizione_e_la_stessa` pretende che questa riga e
## `Deriva.componi` diano lo stesso identico numero su una griglia. Il posto
## unico è la DEFINIZIONE, non l'istruzione macchina.
##
## ⚠️⚠️ **E PER UN PEZZO LA TRASCRIZIONE È STATA INCOMPLETA, cioè la
## promessa qui sopra era falsa: `componi` fermava il NON FINITO e questa riga
## no.** In Godot `clampf(NAN, 0.0, 1.0)` torna **NAN**, non il pavimento — i
## confronti col NAN sono tutti falsi, quindi il clamp non lo tocca — e la
## somma se lo porta dietro. Con un `_deriva` sporco `componi` rispondeva la
## BASE (chi quella persona è sempre stata: sparisce la deriva, resta il
## genoma — il degrado giusto) e questa riga rispondeva NAN; con un `tratti`
## sporco — un salvataggio vecchio, un banco, un `set()` — `componi`
## rispondeva 0.0 e questa riga NAN.
##
## **Il non finito NON deve arrivare fin qui**, e il controllo si è aggiunto
## di QUA invece di toglierlo di là, per tre ragioni:
##
## 1. **il NAN è ASSORBENTE, e questa è la porta d'ingresso di mezzo
##    villaggio**: da `tratto()` il numero passa in `peso_drive`, in
##    `punteggio` (per ogni azione di ogni decisione) e nel softmax di
##    `decide()`. Un NAN lì non degrada la personalità: la cancella, in
##    silenzio — e non se ne va da solo, perché il dato sporco resta dov'è e
##    `_ricalcola_deriva()` lo rilegge ogni giorno.
## 2. **il degrado va dove va sempre in questo progetto: verso il gioco che
##    continua.** Togliere il controllo da `componi` allineerebbe le due
##    stesure peggiorando quella di RIFERIMENTO, e lascerebbe il dato rotto
##    senza nessun posto in cui fermarsi: lì la definizione è anche l'unica
##    difesa che quel dato incontri.
## 3. **una guardia che pretendesse NAN == NAN non sarebbe una guardia**: i
##    confronti col NAN sono falsi, quindi `t.almost(NAN, NAN, …)` FALLISCE.
##    La griglia che sorveglia le due stesure può estendersi al non finito
##    solo se tutte e due rispondono un NUMERO.
##
## ⚠️ **E il collaudo del finito è scritto come CONFRONTI, non come
## `is_finite()`**: `x > -INF and x < INF` è lo stesso predicato (il NAN
## fallisce tutti e due i confronti, un infinito ne fallisce uno) e non mette
## una CHIAMATA sulla riga che i 23,4× qui sopra hanno insegnato a tenere
## sgombra. Non è un'ottimizzazione dichiarata — il costo di `is_finite` su
## questa riga **non è misurato** — è il rifiuto di pagare, sulla funzione
## più calda del gioco, un prezzo che nessuno ha contato. Sul dato ROTTO
## invece `Deriva.componi` si chiama sul serio: la risposta a un dato rotto la
## dà la DEFINIZIONE, una volta sola e in un posto solo, e la paga chi ha il
## salvataggio sporco.
##
## ⚠️ Chi tocca questo corpo tocca anche `Deriva.componi`: sono la stessa
## legge scritta due volte, e a tenerle insieme c'è solo quella guardia — la
## stessa disciplina di `nottambulo()` e della battuta delle farfalle.
##
## Da dove entra il veleno, per chi si chiede se il controllo serve davvero:
## da `tratti`, che arriva dal salvataggio e che chiunque può scrivere con un
## `set()`. **Non da `_deriva`**, che è nostro e che `_ricalcola_deriva()`
## riempie con `DERIVA.delta`, il quale un ingresso non finito lo ferma già da
## sé (torna 0.0). Il secondo confronto è quindi la rete del banco e del
## chiamante futuro, non di un guasto che si conosca oggi.
##
## Verificato a tavolino su **2601 coppie** (la griglia dei tratti, i bordi
## fuori intervallo, ±INF e NAN) riscrivendo la `CLAMP` di Godot — due
## confronti, e il NAN ci passa in mezzo: zero divergenze da `Deriva.componi`
## su tutto il dominio, zero uscite NAN, e **zero divergenze dal gioco di
## ieri sui valori finiti**. ⚠️ È un conto su carta, non il motore: la prova
## vera è la griglia di `test_finestra`, che oggi è tutta di valori finiti —
## cioè cieca esattamente dove le due stesure divergevano.
func tratto(nome: String) -> float:
	var base := float(tratti.get(nome, 0.5))
	var scarto := float(_deriva.get(nome, 0.0))
	if base > -INF and base < INF and scarto > -INF and scarto < INF:
		return clampf(clampf(base, 0.0, 1.0) + scarto, 0.0, 1.0)
	return DERIVA.componi(base, scarto)


## CHI SEI SEMPRE STATO. Lo leggono le porte, le soglie e le frasi, e nessun
## altro. E' il genoma: **nessuno lo scrive, mai**.
func tratto_base(nome: String) -> float:
	return float(tratti.get(nome, 0.5))


## ⚠️ **UNA VOLTA AL GIORNO, e non di piu'.** Un tratto che cambia a meta'
## giornata non e' una persona che cambia: e' un cruscotto. La chiamano
## `setup()` (dove le prove non ci sono ancora, quindi δ = 0), `load()` in
## coda — cosi' l'ordine `setup → load` di `_ensure_brain`, che oggi
## cancellerebbe tutto, qui lavora per noi — e `passa_giorno()`.
func _ricalcola_deriva() -> void:
	if _deriva_giorno == oggi and not _deriva.is_empty():
		return
	_deriva_giorno = oggi
	var nuovo := {}
	# ⚠️ SPENTA, LA DERIVA È UN DIZIONARIO VUOTO — non uno zero scritto sopra
	# ogni tratto. `_tratti_derivati()` legge la base quando la chiave manca,
	# quindi il vuoto vuol dire ESATTAMENTE «chi sei sempre stato», che è la
	# condizione di controllo che serve. Scrivere degli zeri sarebbe una
	# seconda verità sulla stessa domanda.
	# (Non è hot: `_ricalcola_deriva` la chiamano in tre soli posti — setup,
	# load e passa_giorno — quindi un vuoto che rifà il giro non costa.)
	if not Leve.acceso(Leve.DERIVA):
		_deriva = nuovo
		if limbico != null:
			limbico.riproietta(_tratti_derivati())
		return
	for nome in DERIVA.DERIVANO:
		var t := str(nome)
		var pressione: float = DERIVA.spinta(t, ricordi, sommario,
				limbico.marchi if limbico != null else {}, _recenza, compagnia,
				compiti_del_sogno())
		nuovo[t] = DERIVA.delta(float(tratti.get(t, 0.5)), pressione,
				DERIVA.plasticita_di(crescita))
	_deriva = nuovo
	# e le due grandezze che il Limbico DERIVA dai tratti si rifanno: senza,
	# la deriva si fermerebbe un millimetro prima del corpo.
	if limbico != null:
		limbico.riproietta(_tratti_derivati())


## ⚠️ **QUALI COMPITI SERVONO IL MIO SOGNO** — e sta QUI perché la tabella è
## qui. `Deriva` deve poter riconoscere la riga «mi hai dato il lavoro che
## sognavo», ma il `tipo` di quella riga è il nome del compito, e i nomi
## vivono in `COMPITI`: ricopiarli di là sarebbe la tabella gemella che questo
## progetto ha già pagato tre volte. Il dato attraversa il confine, non la
## tabella — è la stessa disciplina con cui il villaggio presta la compagnia.
func compiti_del_sogno() -> Array:
	if sogno == "":
		return []
	var out: Array = []
	for c in COMPITI:
		if str((COMPITI[c] as Dictionary).get("serve", "")) == sogno:
			out.append(str(c))
	return out


## I tratti come sono adesso, per chi ne vuole tutti insieme (il Limbico).
func _tratti_derivati() -> Dictionary:
	var out := {}
	for k in tratti:
		out[k] = tratto(str(k))
	return out


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


## IL LIBRO MASTRO VERSO QUALCUNO, prima che diventi un numero solo.
##
## Due colonne che il gioco calcolava già e teneva per sé dentro `rancore()`:
## i TORTI (il peso dei ricordi negativi, vivi e riassunti) e le PROVE, cioè
## «i ricordi belli scontano il rancore» — la riga che c'era da sempre e che
## nessuno poteva leggere da fuori.
##
## ⚠️ **STA QUI E NON IN DUE POSTI.** `rancore()` è la saturazione di questo
## conto, e `Rilettura` ne è il secondo lettore: se la rilettura si
## ricalcolasse le prove per conto suo avremmo due libri mastri sullo stesso
## dato, e il giorno che qualcuno tocca il perdono i due divergono in
## silenzio. È la regola delle fonti uniche applicata a un numero che
## esisteva già.
##
## Torna `{"torti", "prove", "prove_totali"}` — tre numeri, e ognuno ha il suo
## lettore: `rancore()` legge i primi due, `Rilettura` il terzo.
##
## ⚠️ **CE N'ERANO ALTRI DUE, `media_prove` e `n_prove`, E SONO STATI TOLTI.**
## Non perché fossero di troppo: perché erano **sbagliati e pubblici**, che è
## la combinazione peggiore. Nessuno dei due aveva un lettore — `media_prove`
## era l'ingresso di `Limbico.divario`, il cancello sulle `attese` che si è
## rivelato aperto per costruzione ed è stato tolto anche lui (vedi
## `Rilettura.disponibile`) — e tutti e due invitavano a un conto scorretto:
##
## · **`n_prove` mescolava DUE POPOLAZIONI.** Lo stesso contatore avanzava di
##   uno per ogni riga viva **e** di uno per ogni riga di sommario, ma `prove`
##   esclude il sommario per scelta misurata (vedi più sotto) mentre
##   `prove_totali` lo comprende: `prove / n_prove` era sbagliato per
##   costruzione, e `prove_totali / n_prove` contava un blocco di quaranta
##   gentilezze riassunte come **1**. Un campo pubblico che sta in mezzo a due
##   aggregati diversi non è un numero in più: è una divisione sbagliata che
##   aspetta il suo chiamante.
##
## · **`media_prove` SOMMAVA DUE UNITÀ DIVERSE.** Dalle righe vive prendeva la
##   `valenza` NUDA, dal sommario `peso / n` — dove `peso` è già una somma di
##   `valenza × intensita`. Cioè la stessa identica gentilezza valeva due
##   numeri a seconda di quale lato della soglia `RICORDI_VIVI` si trovasse, e
##   il valore **saltava nel fotogramma in cui la potatura scatta**.
##
## Non sono state riparate ma tolte, perché in questo progetto una guardia che
## nessun test può far fallire si toglie, e a maggior ragione un numero che
## nessuno legge e che chiunque leggesse userebbe male. **Chi un domani avrà
## davvero la domanda «quanto valeva in media una di quelle cose» la ricalcoli
## qui, con l'unità DICHIARATA** — `valenza × intensita` da tutte e due le
## parti — **e con un `n` che conti i ricordi veri e non i blocchi** (per il
## sommario `n += int(v["n"])`, non `n += 1`). E si porti dietro il proprio
## test: il costo di riscrivere sei righe è minore di quello di fidarsi di un
## numero che nessuno ha mai guardato.
func conto_verso(attore := "giocatore") -> Dictionary:
	var torti := 0.0
	for r in ricordi:
		if r["attore"] != attore or float(r["valenza"]) >= 0.0:
			continue
		torti += -float(r["valenza"]) * float(r["intensita"]) * _recenza(int(r["quando"]))
	for k in sommario:
		var parti: PackedStringArray = k.split("|")
		if parti.size() < 2 or parti[1] != attore:
			continue
		var v: Dictionary = sommario[k]
		if float(v["peso"]) >= 0.0:
			continue
		torti += -float(v["peso"]) * _recenza(int(v["ultimo"]))
	# le PROVE CHE ASSOLVONO. Solo `valenza > 0`, e il peso lo dà
	# `Rilettura.peso_prova` — il `maxf(0.0, …)` che rende questo modulo
	# strutturalmente incapace di accusare qualcuno sta LÌ, non qui.
	var prove := 0.0
	for r in ricordi:
		if r["attore"] != attore or float(r["valenza"]) <= 0.0:
			continue
		prove += RILETTURA.peso_prova(float(r["valenza"]), float(r["intensita"]),
				_recenza(int(r["quando"])))
	# ⚠️ **E QUI NASCONO DUE NUMERI, NON UNO — perché le domande sono due.**
	#
	# `prove` conta solo le righe VIVE. `prove_totali` conta anche il SOMMARIO.
	# Le leggono `rancore()` e la RILETTURA, e quale legge quale è cambiato il
	# 2026-09-12, fondendo due cure che due sessioni diverse avevano scritto
	# nello stesso punto in direzioni opposte. **Le due misure sono tutte e due
	# vere**, e vanno lette insieme o si rifà il giro:
	#
	# · SENZA il sommario, lo SCUDO DEL GIOCATORE EVAPORA. Le due metà negative
	#   qui sopra scandagliano `ricordi` **e** `sommario`; il perdono guardava
	#   solo i vivi. Oltre `RICORDI_VIVI` i piatti e i regali smettevano di
	#   scontare qualcosa mentre i torti fusi continuavano a contare — cioè
	#   un'asimmetria che non punisce un gesto ma il TEMPO DI GIOCO e la
	#   GENEROSITÀ. Misurato su una storia esattamente in pari (un regalo per
	#   ogni torto, che con `SCONTO_PERDONO` deve dare rancore ZERO per
	#   sempre): 20/20 → 0.0000 · 40/40 → 0.1828 · **100/100 → 0.5566**.
	#
	# · COL sommario, il villaggio SI PLACA COL CIBO. Misurato
	#   (`tools/misura_gradino.gd`, lo scenario canonico: `taglia_legna` ogni
	#   giorno per uno che sognava di fare il guerriero, 120 giornate):
	#
	#     un piatto      → confronto, col sommario   senza
	#     mai            giorno 71                    71
	#     ogni 3 giorni  giorno 105                   72
	#     ogni 2 giorni  **MAI**                      71
	#
	# ⚠️⚠️ **E LA RADICE NON È NESSUNA DELLE DUE: È CHE IL SOMMARIO NON
	# DECADE.** Una riga viva pesa `valenza × intensita × recenza(quando)` e
	# decade. Una riga fusa pesa `peso × recenza(ultimo)`, dove `peso` è la
	# somma NON scontata di tutte le occorrenze e `ultimo` è la più recente:
	# per un comportamento in corso la recenza resta 1,0 e il peso cresce
	# all'infinito. Incrociato con la potatura per schema del sé — che
	# sacrifica per prime le righe RIPETUTE e poco definenti — il conto esce
	# storto in un verso solo: il tradimento d'identità è congruente e RESTA
	# VIVO (decade, satura), le gentilezze ripetute del giocatore vanno nel
	# SOMMARIO (non decadono, crescono lineari). Il perdono cresce senza
	# limite e il rancore satura: ecco il «MAI».
	#
	# Qui vince la lettura simmetrica, perché delle due è quella che non
	# dipende da quanto a lungo hai giocato. La radice ha il suo commit, con
	# la misura: vedi «IL SOMMARIO NON DECADEVA» in CLAUDE.md.
	#
	# Non è una tabella gemella: è un conto solo, con due aggregati che dicono
	# quale domanda servono. Chi ne aggiunge un terzo si chieda prima quale
	# domanda nuova ha.
	var prove_totali := prove
	for k in sommario:
		var parti_b: PackedStringArray = k.split("|")
		if parti_b.size() < 2 or parti_b[1] != attore:
			continue
		var vb: Dictionary = sommario[k]
		if float(vb["peso"]) <= 0.0:
			continue
		prove_totali += RILETTURA.peso_prova(float(vb["peso"]), 1.0,
				_recenza(int(vb["ultimo"])))
	return {"torti": torti, "prove": prove, "prove_totali": prove_totali}


## Il rancore verso qualcuno: 0 (nessuno) .. 1 (insopportabile).
## È una saturazione, non una somma: cento torti non fanno un rancore cento
## volte più grande, ma quarantasette pesano molto più di cinque.
func rancore(attore := "giocatore") -> float:
	var c := conto_verso(attore)
	var somma: float = float(c["torti"])
	# ⚠️ **`prove_totali`, cioè ANCHE il sommario**: vedi la testata di
	# `conto_verso`. Con le sole righe vive lo scudo del giocatore evapora
	# nei villaggi vissuti, che è dove nessun collaudo arriva.
	var buoni: float = float(c["prove_totali"])
	# ⚠️ **IL PERDONO NON DIPENDE DA QUANTI AMICI TI HA DATO IL MONDO.** Qui
	# c'era un moltiplicatore sull'ossitocina, e l'ossitocina la fa
	# l'appartenenza (`sincronizza_neuro`), che a sua volta la fa `_chats` —
	# **una** chiacchierata per volta in tutto il villaggio. Misurato: lo
	# sconto dei ricordi buoni andava da ×1,146 con appartenenza 0.10 a
	# ×1,596 con 0.90, cioe' **chi il mondo non ha incontrato perdonava
	# meno**. E' la stessa forma della «tassa giornaliera per non essersi
	# visti» che la regola 3 degli Affetti vieta per iscritto: una ferita la
	# cui unica chiave sta in mano al caso invece che al giocatore. I ricordi
	# belli scontano il rancore, e li mette li' chi gioca.
	somma = maxf(0.0, somma - buoni * SCONTO_PERDONO)
	return 1.0 - exp(-somma / SATURAZIONE * 3.0)


## LA FIDUCIA verso qualcuno: 0 (nessuna) … 1 (piena). La gemella di
## `rancore()`, e nasce perché il libro mastro sa dire quanto qualcuno ti ha
## fatto del male e **non sa dire quanto ti ha fatto del bene**.
##
## Lo sconto del perdono — il `− buoni * 1.4` qui sopra — si ferma a zero,
## quindi cinquanta giornate di piatti caldi possono al massimo azzerare un
## torto, e da lì in poi non lasciano traccia da nessuna parte. E `opinione`,
## l'unico modello generalizzato che un vicino ha di una persona, ha **un solo
## scrittore in tutto il gioco**: `senti_dire()`, cioè il pettegolezzo. Quello
## che un vicino pensa di te era fatto soltanto di quello che gli hanno detto
## gli altri.
##
## È una LETTURA, come `Affetti.coppia()`, `assenza()` e `Deriva.spinta()`:
## zero chiavi nuove, zero migrazioni, niente che possa restare appeso a metà.
## `save()` non la conosce e non deve conoscerla — un salvataggio di ieri
## riaperto oggi risponde con le prove che aveva già. E **non ha cache**:
## `_ricalcola_deriva()` ne ha una per giornata, e una qui vorrebbe dire che
## un piatto conta solo dal mattino dopo.
##
## ⚠️ **IL NOME È GIÀ OCCUPATO DUE VOLTE, e questa non è nessuna delle due**:
## `Voce.si_confida()` chiama «fiducia» una porta sulle giornate del Filo
## Rosso, e `FiatoSospeso.SOGLIA_FIDUCIA` è la calma del prato verso gli
## animali. Questa è un'opinione su una persona, ricavata dal libro mastro di
## chi la pensa.
##
## [param tranne] salta le righe di QUEL tipo — serve al suo unico chiamante,
## e chiude un anello in codice invece che in un commento (vedi `punteggio`).
func fiducia(attore := "giocatore", tranne := "") -> float:
	var somma := 0.0
	for r in ricordi:
		if str(r["attore"]) != attore:
			continue
		if tranne != "" and str(r["tipo"]) == tranne:
			continue
		# ⚠️ **SI SCEGLIE PER SEGNO, MAI PER UNA LISTA DI TIPI.** Una lista
		# sarebbe la gemella di `Deriva.SPINTE["codardia"]`
		# (`piatto/regalo/festa`) — che infatti ha già dimenticato
		# «accompagnato» e non vede «consolato»: un elenco scritto a mano
		# nasce incompleto, e una riga che non entra non fa fallire nessun
		# test. Il segno vede per costruzione ogni gesto presente e futuro.
		var v := float(r["valenza"])
		if v <= 0.0:
			continue
		somma += v * float(r["intensita"]) * _recenza(int(r["quando"]))
	# --- e quelle FONDUTE nel sommario, che non si pota mai. Guardare solo
	#     `ricordi` farebbe sparire la fiducia oltre le `RICORDI_VIVI` righe,
	#     cioè PROPRIO nei villaggi vissuti — dove nessun collaudo arriva.
	for k in sommario:
		var parti: PackedStringArray = str(k).split("|")
		if parti.size() < 2 or str(parti[1]) != attore:
			continue
		if tranne != "" and str(parti[0]) == tranne:
			continue
		var voce: Dictionary = sommario[k]
		# `peso` è già `valenza * intensita` sommata: moltiplicarlo per
		# un'intensità la conterebbe due volte.
		var pe := float(voce["peso"])
		if pe <= 0.0:
			continue
		somma += pe * _recenza(int(voce["ultimo"]))
	# ⚠️ **NESSUNO SCONTO COI TORTI, ed è una decisione.** Il `− buoni * 1.4`
	# di `rancore()` non è una costante di simmetria: è un pollice sulla
	# bilancia A FAVORE del giocatore — un gesto bello cancella più del torto
	# che pareggia, «senza questa porta il sistema sarebbe una condanna».
	# Specchiarlo lo CAPOVOLGE: un torto cancellerebbe 1,4 volte la
	# gentilezza, e una brutta giornata spazzerebbe settimane di doni. E
	# darebbe due pene allo stesso evento — il rancore verso la porta della
	# diserzione, la fiducia verso qui — la seconda senza nessun telegrafo.
	# I torti passano da una porta sola.
	#
	# Conseguenza dichiarata: rancore e fiducia possono essere positivi
	# insieme, e va bene — una persona può ricordare quello che le hai fatto
	# e quello che le hai dato. Non vengono mai mostrati insieme.
	if not is_finite(somma) or somma <= 0.0:
		return 0.0
	# ⚠️ **ZERO ESATTO PER UNO SCONOSCIUTO**, e non per un `if` scritto
	# apposta: senza righe la somma è zero e questa forma dà 0.0. È il degrado
	# verso il gioco di ieri (`opinione.get(chiede, 0.0)` vale già zero per
	# chi non ha una storia), ed è l'unico valore che non sia né un regalo né
	# un'accusa. Un credito iniziale invaliderebbe in un colpo ogni misura mai
	# presa su `punteggio()` e `decide()`.
	return 1.0 - exp(-somma / SAZIETA_FIDUCIA * 3.0)


# ---------------------------------------------------------------- la scala

## Le soglie di QUESTO chibi: i tratti le spostano, ed è qui che due
## caratteri diversi prendono strade diverse davanti allo stesso torto.
## Un codardo non ti verrà mai a cercare: sparisce. Un orgoglioso non
## sabota alle spalle: ti affronta in faccia.
func soglie() -> Dictionary:
	# ⚠️ **QUESTE SONO PORTE, e leggono CHI ERA.** Sotto il gradino della
	# diserzione c'e' `Visitors._congeda()`: con la deriva dentro, «protetto
	# e nutrito» diventerebbe «se ne va prima», e il giocatore perderebbe i
	# vicini di cui si e' occupato di piu'. Misurato: 0.35 di codardia si
	# mangia il 60% del campo naturale fra quattordici residenti.
	var org: float = tratto_base("orgoglio")
	var lea: float = tratto_base("lealta")
	var cod: float = tratto_base("codardia")
	var gri: float = tratto_base("grinta")
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
	# le REAZIONI si pesano con la stessa macchina dei mestieri: e' l'unico
	# modo perche' la risposta esca dal carattere invece che da un ramo
	# scritto a mano
	var c: Dictionary = COMPITI.get(azione, REAZIONI.get(azione, {}))
	var s := 0.0
	# quanto quell'azione allevia ciò che sta pesando ORA
	for d in DRIVES:
		if not c.has(d):
			continue
		var delta: float = float(c[d])
		var sollievo: float = (-delta if d in MALESSERI else delta)
		# 2.2 era una costante uguale per tutti: adesso la scala il
		# carattere, ed è da qui che due vicini davanti alla stessa scelta
		# arrivano a due risposte diverse
		s += sollievo * malessere(d) * 2.2 * peso_drive(d)
	# Sotto cortisolo alto (> 0.45), le routine greedy di sollievo primario dai bisogni hanno priorità
	var cort: float = limbico.livello_neuro("cortisolo") if limbico else 0.0
	if cort > 0.45:
		var fattore_stress: float = (cort - 0.45) / 0.55
		for d in DRIVES:
			if c.has(d):
				var delta_s: float = float(c[d])
				var sollievo_s: float = (-delta_s if d in MALESSERI else delta_s)
				if sollievo_s > 0.0:
					s += sollievo_s * malessere(d) * fattore_stress * 1.5
	# IL CARATTERE TIRA. È l'equivalente, per le risposte, del tiro del
	# sogno: l'unico termine che non passa da `malessere()` e quindi l'unico
	# che sopravvive quando un vicino sta bene — che è il caso normale.
	if c.has("tratto"):
		var amp: float = float(c.get("ampiezza", AMPIEZZA_TRATTO))
		s += amp * (tratto(str(c["tratto"])) - 0.5) \
				* 2.0 * float(c.get("verso", 1))
	# il sogno tira: si fa volentieri ciò che ci avvicina a chi vogliamo essere
	if str(c.get("serve", "")) == sogno:
		s += 0.45 * (0.5 + tratto("ambizione"))
	elif sogno in (c.get("tradisce", []) as Array):
		s -= 0.5 * (0.5 + tratto("orgoglio"))
	# i ricordi: se questo compito ti ha già bruciato, pesa — ma da chi ti ha
	# voluto bene, la ventesima volta pesa meno. È l'UNICO posto di
	# `punteggio()` in cui il rapporto con chi chiede possa toccare il costo
	# di UNA cosa specifica.
	#
	# ⚠️ **MOLTIPLICATIVO, e il pavimento è STRUTTURALE**: con `fiducia == 0`
	# l'espressione è `* 1.0`, cioè **bit per bit la riga di ieri** — chi non
	# ha una storia col richiedente ha il gioco di prima, senza nessun ramo
	# scritto apposta. Il tetto è `SMORZO_FIDUCIA`: il logorio non scende mai
	# sotto il 60% di quello che era. Una cosa che ti ha bruciato ti brucia
	# comunque, anche se te la chiede chi ti vuole bene.
	#
	# ⚠️ E `fiducia(chiede, azione)` con il `tranne`: questa riga conta GIÀ le
	# righe di quel tipo (`quante_volte(azione, chiede)`), quindi pesarle di
	# nuovo con la fiducia sarebbe contare due volte le stesse righe dentro
	# una sola espressione. Non è una lista bianca — è non guardare due volte
	# la riga che il chiamante ha già in mano. E taglia il canale dominante
	# dell'anello di «se_stesso», che si auto-confermerebbe il lavoro dei
	# sogni.
	s -= 0.5 * minf(1.0, float(quante_volte(azione, chiede)) / 25.0) \
			* (1.0 - SMORZO_FIDUCIA * fiducia(chiede, azione))
	# ⚠️ **E LE DUE RIGHE QUI SOTTO NON POSSONO CAMBIARE NIENTE, MAI.**
	# `opinione` e `gradino` non dipendono da `azione`: dentro una chiamata a
	# `decide()` il `chiede` è fisso, quindi sono la STESSA costante su tutti
	# i candidati — e `decide()` ordina, prende le prime tre e pesa
	# `exp((s − base) * nitidezza)` con `base` preso dai voti stessi. Una
	# costante additiva si cancella ESATTAMENTE: stesso ordinamento, stesso
	# `top`, stessa differenza, stesso tiro. E `punteggio()` ha **un solo
	# lettore in tutto il gioco** (`decide()`), quindi non c'è nessun altro
	# che la possa vedere.
	#
	# Non si tolgono — il degrado va verso il gioco di ieri, e due test le
	# leggono in assoluto. Ma chi passa di qui deve saperlo: mettere un
	# termine nuovo ACCANTO a queste, invece che dentro la riga sopra, vuol
	# dire scrivere una funzione che compila, si legge benissimo, ha un test
	# facile che passa, e **non cambia nessuna decisione del gioco**. Sarebbe
	# la nona volta.
	s += float(opinione.get(chiede, 0.0)) * 0.6
	s -= float(gradino) / float(SCALA.size()) * 1.2
	return s


## Sceglie fra le azioni possibili. NON prende il massimo: campiona pesato
## fra le prime tre. Prendere sempre il massimo rende gli NPC prevedibili e
## meccanici; campiare fra le migliori li rende vivi restando sensati — non
## faranno mai la cosa assurda, ma nemmeno sempre la stessa.
## `nitidezza` è quanto la scelta è DECISA. 1.6 è una moneta appena
## sbilanciata (a 0.3 di scarto dà 62/38): giusta per «che mestiere faccio
## oggi», dove sbagliare costa una giornata. Per le scelte che cambiano una
## vita — chiudere la porta, andarsene dal villaggio — quella stessa moneta
## renderebbe il carattere irrilevante: chi ci guarda vedrebbe un dado.
## Alzandola, la persona fa quello che farebbe LEI, e il caso resta solo per
## i pareggi veri.
func decide(azioni: Array, chiede := "giocatore", nitidezza := 1.6) -> String:
	if azioni.is_empty():
		return ""
	var cort: float = limbico.livello_neuro("cortisolo") if limbico else 0.0
	var nitidezza_effettiva: float = nitidezza
	if cort > 0.45:
		# Irrigidimento del Softmax: il cortisolo alto stringe il campo, e chi
		# e' teso fa la cosa che lo solleva invece di guardarsi intorno.
		#
		# ⚠️ **MA NON PIU' DI UNA SCELTA DI VITA, ed e' il tetto che mancava.**
		# Senza, il fattore ×4 si moltiplicava anche per `NITIDEZZA_VITA`
		# (4.5) e dava 18: lo stress rendeva piu' certa una decisione che
		# cambia una vita, che e' l'opposto di quello che lo stress fa.
		# MISURATO su 240 caratteri veri × 30 rotture: il ventaglio delle
		# sette risposte di `REAZIONI` — «lo stesso carattere che in 30
		# rotture ne da' tre diverse», l'invariante che una revisione
		# avversariale precedente aveva stabilito — passava dall'87,9% al
		# **25,4%** col cortisolo a 0.90. Col tetto, una routine puo'
		# diventare decisa quanto una scelta di vita, mai di piu'.
		var fattore_stress: float = (cort - 0.45) / 0.55
		nitidezza_effettiva = minf(nitidezza * (1.0 + fattore_stress * 3.0),
				maxf(nitidezza, NITIDEZZA_VITA))
	var voti := []
	for a in azioni:
		voti.append({"a": a, "s": punteggio(a, chiede)})
	voti.sort_custom(func(x, y): return float(x["s"]) > float(y["s"]))
	var top: Array = voti.slice(0, mini(3, voti.size()))
	# softmax povero: si sposta tutto sopra lo zero e si pesa
	var base: float = float(top[top.size() - 1]["s"])
	var tot := 0.0
	for v in top:
		tot += exp((float(v["s"]) - base) * nitidezza_effettiva)
	var tiro := _rng.randf() * tot
	for v in top:
		tiro -= exp((float(v["s"]) - base) * nitidezza_effettiva)
		if tiro <= 0.0:
			return str(v["a"])
	return str(top[0]["a"])


## LA PORTA UNICA DELLA REGOLAZIONE — si chiede QUI, non dentro il Limbico.
##
## Davanti allo stesso impulso ci sono due strade, e sceglierle è di chi ha
## tutti e due i pezzi: `Animo` possiede i **ricordi** (dove stanno le prove)
## e il **limbico** (dove sta la forza per trattenersi). Prima `Visitors`
## scendeva dentro `animo.limbico.trattieni()`, cioè attraverso l'oggetto per
## arrivare al suo campo: con due strategie sarebbero diventate due decisioni
## prese da chi non ha il materiale per prenderle.
##
## L'ordine NON è una preferenza di gusto: **si rilegge prima di trattenersi**
## perché rileggere è a monte — se il fatto, riletto, non fa più male, non
## c'è niente da tenere dentro. Provare prima a mordersi la lingua e poi a
## rileggere vorrebbe dire pagare la `regolazione` per un'emozione che non
## sarebbe mai arrivata.
##
## Torna la scheda di `Rilettura.scheda` con in più `"modo"`:
## `"rilettura"` · `"morso"` (trattenuto) · `"scoppio"` (non ce l'ha fatta).
func regola(attore := "giocatore") -> Dictionary:
	if limbico == null:
		return {"modo": "morso", "riletto": false, "rapporto": 0.0}
	var c := conto_verso(attore)
	# ⚠️ **`prove_totali`, non `prove`**: la rilettura è l'unica che legge
	# anche il sommario. Vedi la testata di `conto_verso` — con le sole
	# righe vive sarebbe cieca a quanto il giocatore è stato generoso.
	var sch := RILETTURA.scheda(float(c["torti"]), float(c["prove_totali"]))
	if bool(sch["riletto"]) and not debug_niente_rilettura:
		# ⚠️ **E NON C'È NIENTE DA APPLICARE: rileggere È non pagare.** Non
		# si tocca `regolazione`, non si tocca il cortisolo, non si tocca il
		# ricordo e non si toccano le attese. Il torto resta intero — quello
		# che cambia è che quel vicino non ha dovuto spendere niente per
		# tenerselo dentro, ed è esattamente la previsione di Gross &
		# Levenson: la soppressione lascia il corpo attivato, la
		# rivalutazione no. Se un domani questo ramo cominciasse a scrivere
		# qualcosa, la meccanica sarebbe diventata una seconda soppressione
		# con un altro nome.
		var out := sch.duplicate()
		out["modo"] = "rilettura"
		return out
	# nessuna prova che regga: si torna esattamente al gioco di prima.
	var ok: bool = limbico.trattieni()
	var giu := sch.duplicate()
	giu["modo"] = "morso" if ok else "scoppio"
	giu["riletto"] = false
	return giu


## Tenta di mordersi la lingua delegando al Limbico (con costo modulato dal
## cortisolo). ⚠️ Non ha chiamanti di produzione: la porta e' `regola()`.
func trattieni(costo := -1.0) -> bool:
	if limbico == null:
		return true
	if costo < 0.0:
		return limbico.trattieni()
	return limbico.trattieni(costo)


# ---------------------------------------------------------------- il contagio

## Il pettegolezzo: quello che è successo a un altro chibi arriva qui.
## Quanto attecchisce dipende da quanto gli si crede (legame) e da quanto
## questo chibi è leale a chi comanda. È da qui che nascono le cascate:
## nessuno le scrive, si formano da sole quando le soglie sono giuste.
func senti_dire(da: String, su: String, valenza: float, forza := 1.0) -> float:
	var credito: float = clampf(float(legami.get(da, 0.25)), -1.0, 1.0)
	if credito <= 0.0:
		return 0.0          # da chi non stimi, le voci non attecchiscono
	# LA LEALTA' RESISTE ANCHE ALLE VOCI SUI VICINI. Prima resisteva SOLO a
	# quelle sul giocatore, e una voce su una PERSONA attecchiva piu' di una
	# sul re del villaggio — su tutto il grafo, due passaggi al giorno. E'
	# la via piu' corta perche' una storia triste diventi una gogna: un
	# villaggio dove basta dirlo a due perche' lo sappiano tutti, e nessuno
	# che sospenda il giudizio. Verso un vicino la resistenza e' piu'
	# morbida che verso il giocatore (si difende chi si conosce meglio), ma
	# non e' zero.
	var resistenza: float = tratto("lealta")
	if su != "giocatore":
		resistenza *= 0.6
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
			* (0.5 + 0.5 * tratto("orgoglio"))


## Quanto irradia chi ieri e' SCESO di gradino: la buona notizia.
##
## E' il gemello di `eco()`, e la differenza fra i due e' tutta la
## meccanica: `eco()` guarda il LIVELLO — chi sta in basso irradia ogni
## giorno, finche' ci resta — mentre questa guarda l'EVENTO, e lo racconta
## UNA VOLTA SOLA, con l'ampiezza del gradino da cui si e' scesi.
##
## ⚠️ IRRADIARE IL LIVELLO SAREBBE LA MACCHINA CHE SI AUTOCONSOLA: chi sta
## bene diventerebbe una sorgente permanente di sollievo, il villaggio si
## rimetterebbe a posto da solo e la riparazione del giocatore non varrebbe
## piu' niente. Per la stessa ragione la somma e' asimmetrica e deve
## restarlo: il rancore si irradia ogni giorno che uno resta lassu' (~3.0
## unita' su una salita fino al settimo gradino), il sollievo una volta
## sola (~1.0). Chi rompe e poi ripara NON ci guadagna.
##
## LA FINESTRA E' IERI, non oggi: cosi' ogni discesa ha la stessa latenza,
## e il sollievo resta strutturalmente piu' lento del rancore. Non si tocca.
func eco_serena() -> float:
	if scatti.is_empty():
		return 0.0
	var ultimo: Dictionary = scatti[scatti.size() - 1]
	if int(ultimo.get("giorno", -999)) != oggi - 1:
		return 0.0
	var da := int(indice(str(ultimo.get("da", ""))))
	var a := int(indice(str(ultimo.get("a", ""))))
	if da <= a:
		return 0.0          # si e' SALITI: non e' una buona notizia
	# l'ampiezza e' quella del gradino da cui si e' scesi — un ammutinato
	# che torna in se' e' una notizia piu' grande di uno svogliato
	return frazione(da) * (0.5 + 0.5 * tratto("orgoglio"))


# ---------------------------------------------------------------- IL PERCHÉ
# La parte che rende il sistema un sistema e non un generatore di rumore.

## Le cause del suo stato d'animo, dalla più pesante alla più lieve.
## Ogni voce: {"peso": 0..1, "chiave": …, "testo": "…"}. È la materia prima
## della ricostruzione a posteriori — e ciò che un LLM dovrebbe riscrivere,
## senza MAI inventarsi cause che qui non ci sono.
##
## `chiave` è la causa RIMANDATA (`L10n.rendi`): la si conserva per dopo,
## anche su disco. `testo` è la stessa causa detta adesso, nella lingua di
## adesso — non una seconda stesura da tenere allineata a mano, ma
## letteralmente `rendi(chiave)`, così le due non possono divergere.
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
					"chiave": {"k": "nel villaggio se ne parla male"}})
			continue
		var c: Dictionary = COMPITI.get(tipo, {})
		# col sogno tradito la riga è un'altra riga intera, non la stessa
		# con una parentesi appiccicata in fondo: la parentesi in un'altra
		# lingua può volere un altro posto nella frase
		var riga: Dictionary = {"k": "%s × %d", "args": [{"k": tipo}, n]}
		if sogno in (c.get("tradisce", []) as Array):
			riga = {"k": "%s × %d (e lui sognava di fare %s)",
					"args": [{"k": tipo}, n, {"k": sogno}]}
		# I TORTI CONCRETI VENGONO SEMPRE PRIMA DEI SINTOMI. Un giocatore può
		# agire su «ti ho mandato a spaccare legna sei volte»; su «stima al
		# limite» no — quello è l'effetto, non la causa. Perciò anche un
		# conteggio piccolo parte da 0.35 e scavalca ogni pressione interna.
		out.append({"peso": minf(1.0, 0.35 + float(n) / 30.0), "chiave": riga})
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
		var chiave := {}
		match str(r["tipo"]):
			"lutto":
				chiave = {"k": "ha perso %s", "args": [r["attore"]]}
			"lutto_ignorato":
				chiave = {"k": "e nessuno gli è stato vicino"}
			"sentito_dire":
				chiave = {"k": "gira voce su %s", "args": [r["attore"]]}
			_:
				chiave = {"k": "%s (%s)", "args": [{"k": str(r["tipo"])}, r["attore"]]}
		out.append({"peso": clampf(p, 0.0, 1.0), "chiave": chiave})
	# 3) le pressioni interne che stanno sopra la soglia del sopportabile
	for d in DRIVES:
		var m := malessere(d)
		if m > 0.55:
			# tetto a 0.33: le pressioni interne raccontano COME sta, non
			# PERCHÉ — e non devono mai finire in cima alla spiegazione
			out.append({"peso": m * 0.33,
					"chiave": {"k": "%s al limite", "args": [{"k": str(d)}]}})
	out.sort_custom(func(a, b): return float(a["peso"]) > float(b["peso"]))
	# la causa detta ADESSO, accanto a quella rimandata: una sola stesura,
	# due modi di leggerla (vedi il commento in cima)
	for voce in out:
		voce["testo"] = L10n.rendi(voce["chiave"])
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
	return L10n.rendi(sfogo_rimandato())


## LO SFOGO RIMANDATO: lo stesso, ma a chiavi (`L10n.rendi`) invece che a
## parole. Lo vuole chi lo deve CONSERVARE — la lettera d'addio finisce in
## coda alla posta e su disco, e la si apre il mattino dopo: se ci finisse
## già tradotta, l'ultima cosa che ti ha detto resterebbe per sempre nella
## lingua di ieri. E chi se n'è andato non c'è più per ridirla.
func sfogo_rimandato() -> Dictionary:
	var c := cause()
	if c.is_empty():
		return {"k": "Non è niente. Lascia stare."}
	# il torto principale, detto come lo direbbe lui
	var apertura := {"k": "Ti rendi conto?"}
	# ⚠️ **QUESTO E' TESTO, e legge CHI ERA.** Quello che uno dice quando
	# sbotta e' chi e' sempre stato — non l'effetto di come lo hai trattato
	# nell'ultima stagione.
	if tratto_base("orgoglio") > 0.65:
		apertura = {"k": "Guardami quando ti parlo."}
	elif tratto_base("codardia") > 0.65:
		apertura = {"k": "Scusa… posso dirti una cosa?"}
	var corpo_frase: Dictionary = c[0]["chiave"]
	# se c'è un secondo motivo, si aggiunge: sono le catene a fare male
	if c.size() > 1:
		corpo_frase = {"k": "%s, e %s", "args": [corpo_frase, c[1]["chiave"]]}
	var chiusa := {"k": "Non lo faccio più."}
	if almeno(gradino, "diserzione"):
		chiusa = {"k": "Me ne vado."}
	elif tratto_base("lealta") > 0.6:
		chiusa = {"k": "Io ti sono stato accanto. Tu no."}
	var trattenuto: Dictionary = limbico.perche_scoppio_rimandato()
	if not trattenuto.is_empty():
		chiusa = {"k": "%s (%s)", "args": [chiusa, trattenuto]}
	return {"k": "%s %s. %s", "args": [apertura, corpo_frase, chiusa]}


## La cronaca degli scatti: quando è salito di gradino e perché, allora.
## Serve al giocatore per ricostruire la storia dopo, non solo adesso.
func diario() -> Array:
	var out := []
	for s in scatti:
		var c: Array = s["cause"]
		# gli scatti SI SALVANO, e un diario riletto sei mesi dopo può
		# essere riletto in un'altra lingua: si rende la chiave adesso, non
		# si ricicla il `testo` di allora. (I diari salvati prima di questo
		# cambio la chiave non ce l'hanno: per loro resta il testo di
		# allora, che è tutto quello che ci è rimasto.)
		var motivo := L10n.t("malessere")
		if not c.is_empty():
			var prima: Dictionary = c[0]
			motivo = L10n.rendi(prima["chiave"]) if prima.has("chiave") \
					else str(prima.get("testo", motivo))
		out.append(L10n.tf("giorno %d: %s → %s (%s)",
				[s["giorno"], L10n.t(str(s["da"])), L10n.t(str(s["a"])), motivo]))
	return out


# ---------------------------------------------------------------- salvataggio

func save() -> Dictionary:
	# LO STATO DEL DADO. Senza, ricaricare fa ripartire lo stream dal seme,
	# e due tentativi di save-scumming smascherano che «libero arbitrio»
	# era `randf()`: stessa partita ricaricata, stessa situazione, risposta
	# diversa. Salvandolo, la persona resta quella che era.
	return {
		# COME STRINGA. Il salvataggio passa da JSON, che restituisce ogni
		# numero come float: misurato, lo stato perdeva undici bit e il dado
		# ripartiva da un altro punto dello stream. (Il save-scumming
		# restava bloccato lo stesso, perché la corruzione è deterministica,
		# ma la proprietà scritta qui sopra non era vera.)
		"rng": str(_rng.state),
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
	if d.has("rng"):
		_rng.state = int(str(d["rng"]))
	sincronizza_neuro()
	# ⚠️ **IN CODA, e l'ordine lavora per noi.** `_ensure_brain` fa
	# `setup(dna)` e POI `load(salvato)`: e' lo stesso ordine che oggi
	# cancella tutto quello che `setup` aveva calcolato. Qui la deriva si
	# ricava dalle prove — che `load` ha appena rimesso al loro posto — e
	# quindi arriva per ultima, quando tutto quello che le serve c'e'.
	_deriva_giorno = -1
	_ricalcola_deriva()
