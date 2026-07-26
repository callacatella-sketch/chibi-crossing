extends RefCounted

## IL LIMBICO — l'apparato affettivo che sta SOTTO l'animo.
##
## Animo.gd ragiona: pesa drive, ricordi e carattere e decide cosa fare. Ma le
## persone, prima di ragionare, SENTONO — e sentono in modi che non sono
## affatto proporzionali a quello che succede. È qui che vivono quei modi.
##
## Sei meccanismi, tutti presi dall'affettività vera, tutti scelti perché
## producono una frase che il giocatore capisce al volo:
##
## 1. SORPRESA (errore di previsione). Non conta cosa ricevi: conta quanto
##    è diverso da quello che ti aspettavi. Il decimo regalo di fila non
##    commuove più nessuno; una gentilezza dopo settimane di indifferenza
##    vale dieci regali. Il tradimento è violento non per il male in sé, ma
##    perché arriva da chi ti aspettavi il bene. Tutto questo NON è scritto
##    da nessuna parte: esce da solo dalla stessa formula.
## 2. LE DUE STRADE. Il corpo reagisce prima che la testa capisca: un
##    sussulto parte su un indizio grezzo, e un istante dopo la valutazione
##    lenta lo conferma o lo smentisce. È così che nascono i «ha trasalito,
##    poi ha visto che eri tu» — e sono momenti che il giocatore ricorda.
## 3. MARCHI (condizionamento). Un posto, una persona, un oggetto si
##    CARICANO di quello che è successo lì. Il residente che si è spaventato
##    vicino alla catasta gira al largo dalla catasta, e non sa dirti perché.
##    I marchi si spengono da soli se non vengono più confermati: si può
##    disinnescare una paura tornandoci senza che accada nulla.
## 4. ATTIVAZIONE SOMATICA. Lo spavento resta nel corpo molto dopo che la
##    testa ha capito: si resta guardinghi per un pezzo. È lentezza fisica,
##    non testardaggine.
## 5. UMORE come lente. Non è un'emozione: è la tinta con cui si legge tutto
##    il resto. Di malumore, un gesto neutro sembra un torto.
## 6. TRATTENERSI COSTA. La forza per mordersi la lingua è FINITA e si
##    consuma. È per questo che le persone scoppiano «per una sciocchezza»:
##    non è la sciocchezza, è la decima volta che si trattengono in un giorno.
##
## Tutto puro e testabile: entra un evento, esce come è stato SENTITO, con la
## sua spiegazione in italiano (tests/cases/test_limbico.gd).

# ---------------------------------------------------------------- costanti

## Quanto in fretta ci si abitua: 0 = non ci si abitua mai (ogni regalo
## commuove come il primo, e il gioco diventa una macchinetta), 1 = subito.
const ABITUDINE := 0.30
## Sotto questa sorpresa l'evento non si sente proprio: è routine.
const SOGLIA_SORPRESA := 0.08
## Quanto scende l'attivazione del corpo a ogni giorno.
const CALMA := 0.45
## Quanto rientra l'umore verso il neutro ogni giorno (lento: è un tono, non
## un lampo — chi ha avuto una brutta settimana non si sveglia allegro).
const RIENTRO_UMORE := 0.18
## Quanto si spengono i marchi non confermati (estinzione).
const ESTINZIONE := 0.12
## Sopra questa carica un marchio fa girare al largo.
const SOGLIA_EVITAMENTO := 0.45
## Quanto costa trattenersi una volta.
const COSTO_MORSO := 0.22

# ---------------------------------------------------------------- stato

## Attivazione del corpo: 0 = calmo, 1 = cuore in gola. Decade in fretta ma
## non subito: è il residuo che tiene guardinghi.
var arousal := 0.0
## Tono dell'umore, -1..1. Lento: colora la lettura di tutto il resto.
var umore := 0.0
## Quanta forza resta per trattenersi, 0..1. Si consuma e si ricarica dormendo.
var regolazione := 1.0
## Cosa ci si aspetta da ognuno: "tipo|attore" -> valore atteso (-1..1).
var attese := {}
## I marchi appresi: "luogo|X" / "chi|Y" -> carica (-1..1), e quando è stata
## confermata l'ultima volta.
var marchi := {}
## L'ultima reazione istintiva (la strada veloce), per la UI e i test.
var ultimo_sussulto := {}
## Quante volte si è morso la lingua oggi: serve a raccontare lo scoppio.
var morsi_oggi := 0

## Quanto è reattivo questo individuo (dal carattere: la codardia alza
## l'allarme, la grinta lo abbassa). 1.0 = nella media.
var reattivita := 1.0
## Quanto in fretta si abitua: gli ambiziosi si abituano prima al bene.
var abitudine := ABITUDINE


func setup(tratti: Dictionary) -> void:
	var cod: float = float(tratti.get("codardia", 0.5))
	var gri: float = float(tratti.get("grinta", 0.5))
	var amb: float = float(tratti.get("ambizione", 0.5))
	reattivita = clampf(0.6 + cod * 0.9 - gri * 0.35, 0.2, 1.8)
	abitudine = clampf(ABITUDINE * (0.7 + amb * 0.8), 0.05, 0.75)


# ============================================================ le due strade

## STRADA VELOCE — il corpo, prima della testa.
## Guarda solo due cose: com'è marchiato il posto (o chi ha davanti) e quanto
## è già attivato. Non sa nulla del significato dell'evento: può benissimo
## sbagliarsi, ed è proprio quello a renderla vera.
func percepisci(attore := "", luogo := "") -> Dictionary:
	var carica := 0.0
	var fonte := ""
	for chiave in [("chi|" + attore) if attore != "" else "", ("luogo|" + luogo) if luogo != "" else ""]:
		if chiave == "" or not marchi.has(chiave):
			continue
		var c: float = float(marchi[chiave]["carica"])
		if absf(c) > absf(carica):
			carica = c
			fonte = chiave
	# il corpo già attivato reagisce più forte a tutto: è l'allerta che si
	# autoalimenta, ed è il motivo per cui dopo uno spavento tutto spaventa
	var forza: float = clampf(absf(carica) * reattivita * (1.0 + arousal * 0.6), 0.0, 1.0)
	var reazione := "nulla"
	if forza > 0.22:
		reazione = "trasalisce" if carica < 0.0 else "si_illumina"
		arousal = clampf(arousal + forza * 0.55, 0.0, 1.0)
	ultimo_sussulto = {"reazione": reazione, "forza": forza, "fonte": fonte,
			"carica": carica}
	return ultimo_sussulto


## STRADA LENTA — la valutazione vera, un istante dopo.
##
## Qui succede la cosa più importante di tutto il file: quello che si sente
## NON è [param valenza], è la SORPRESA — la differenza fra quel che è
## successo e quel che ci si aspettava da quella persona. Da questa sola
## formula escono, senza che nessuno le scriva:
##   · l'abitudine  (il decimo regalo non si sente più)
##   · il contrasto (una gentilezza dopo il gelo vale dieci volte tanto)
##   · il tradimento (il male da chi ti aspettavi il bene è insopportabile)
##
## Ritorna {"sentito", "sorpresa", "atteso", "perche"}.
## Con [param identita] true l'evento non tocca una comodità ma CHI SEI: a
## quello non ci si abitua mai. Anzi: succede il contrario.
func rivaluta(tipo: String, attore: String, valenza: float, luogo := "",
		identita := false) -> Dictionary:
	var k := "%s|%s" % [tipo, attore]
	var atteso: float = float(attese.get(k, 0.0))
	# l'umore è la lente: di malumore anche un gesto neutro sembra un torto
	var letto: float = clampf(valenza + umore * 0.22, -1.0, 1.0)
	var sorpresa: float = letto - atteso
	# ABITUDINE contro SENSIBILIZZAZIONE — la distinzione che fa la
	# differenza fra un sistema realistico e uno vero.
	# Alle cose ci si abitua: l'attesa insegue quello che succede, la
	# sorpresa si spegne, il decimo regalo non commuove.
	# Ma a ciò che nega CHI SEI non ci si abitua mai: l'attesa si muove al
	# CONTRARIO — continui ad aspettarti di meglio e continui a restare
	# deluso, e ogni volta un po' di più. È il motivo per cui il quarantesimo
	# giorno a spaccare legna, per uno che sognava di combattere, brucia più
	# del primo invece che meno. Senza questa riga il limbico anestetizzava
	# proprio il torto che deve portare alla ribellione.
	var verso: float = -0.30 if identita else 1.0
	attese[k] = clampf(atteso + (letto - atteso) * abitudine * verso, -1.0, 1.0)

	# quello che si SENTE è la sorpresa, non il fatto. Un filo del fatto resta
	# comunque (0.25): l'abitudine attutisce, non anestetizza.
	var sentito: float = clampf(sorpresa * 0.75 + letto * 0.25, -1.0, 1.0)

	# ACUTO contro CRONICO — l'allarme non è l'umore.
	# Uno spavento fa battere il cuore; un lavoro ingrato per la quarantesima
	# volta non fa battere niente: AVVILISCE. Prima l'attivazione veniva
	# pompata anche dalla sensibilizzazione, e un residente restava «col cuore
	# in gola» per quaranta giorni di fila — vero per un trauma, ridicolo per
	# una giornata di legna. Ora il logorio cronico va quasi tutto nell'umore,
	# e il corpo si allarma solo per ciò che arriva di colpo.
	var acuto: float = 0.08 if identita else 0.40
	var cronico: float = 0.26 if identita else 0.16
	arousal = clampf(arousal + absf(sorpresa) * acuto * reattivita, 0.0, 1.0)
	umore = clampf(umore + sentito * cronico, -1.0, 1.0)

	# e il posto (o la persona) si CARICA di quello che si è sentito
	if absf(sentito) > 0.3:
		if luogo != "":
			_marchia("luogo|" + luogo, sentito)
		if attore != "":
			_marchia("chi|" + attore, sentito)

	return {"sentito": sentito, "sorpresa": sorpresa, "atteso": atteso,
			"perche": _perche_sentito(tipo, attore, letto, atteso, sorpresa)}


func _marchia(chiave: String, carica: float) -> void:
	var voce: Dictionary = marchi.get(chiave, {"carica": 0.0, "conferme": 0})
	# i marchi si formano in fretta ma non si saturano: bastano due spaventi
	# nello stesso posto per non volerci più andare
	voce["carica"] = clampf(float(voce["carica"]) * 0.7 + carica * 0.55, -1.0, 1.0)
	voce["conferme"] = int(voce["conferme"]) + 1
	marchi[chiave] = voce


# la spiegazione in italiano di COME è stato sentito: è questa che rende
# leggibile una reazione sproporzionata
func _perche_sentito(tipo: String, attore: String, letto: float,
		atteso: float, sorpresa: float) -> String:
	if absf(sorpresa) < SOGLIA_SORPRESA:
		return "ormai se l'aspetta: non fa più né caldo né freddo"
	if letto > 0.0 and atteso < -0.2:
		return "non se l'aspettava più da %s: vale il doppio" % attore
	if letto < 0.0 and atteso > 0.2:
		return "proprio da %s non se l'aspettava" % attore
	if letto > 0.0 and atteso > 0.35:
		return "gli fa piacere, ma ci ha fatto l'abitudine"
	if letto < 0.0 and sorpresa < -0.5:
		return "e ogni volta gli pesa di più"
	if letto < 0.0 and umore < -0.3:
		return "e in questi giorni prende tutto storto"
	return "lo sente per quello che è"


# ============================================================ trattenersi

## Prova a mordersi la lingua. Torna true se ce l'ha fatta.
##
## La forza per trattenersi è FINITA. È per questo che le persone scoppiano
## «per una sciocchezza»: la sciocchezza non c'entra, era la decima volta in
## un giorno che si trattenevano. Un leale ci prova più a lungo; un orgoglioso
## spende più forza ogni volta, perché gli costa di più.
func trattieni(costo := COSTO_MORSO) -> bool:
	if regolazione < costo:
		regolazione = 0.0
		return false
	regolazione -= costo
	morsi_oggi += 1
	return true


## Ha finito la pazienza? (Serve a chi decide se far uscire la battuta.)
func esausto() -> bool:
	return regolazione <= 0.001


## Perché è scoppiato adesso: la frase che spiega la sproporzione.
func perche_scoppio() -> String:
	if morsi_oggi >= 3:
		return "si era trattenuto %d volte oggi" % morsi_oggi
	if regolazione <= 0.001:
		return "non gli restava più pazienza"
	return ""


# ============================================================ i marchi

## Gira al largo da questo posto (o da questa persona)?
func evita(luogo := "", attore := "") -> bool:
	return carica_di(luogo, attore) <= -SOGLIA_EVITAMENTO


## Quanto è carico un posto o una persona, -1..1.
func carica_di(luogo := "", attore := "") -> float:
	var c := 0.0
	if luogo != "" and marchi.has("luogo|" + luogo):
		c = float(marchi["luogo|" + luogo]["carica"])
	if attore != "" and marchi.has("chi|" + attore):
		var c2: float = float(marchi["chi|" + attore]["carica"])
		if absf(c2) > absf(c):
			c = c2
	return c


## Il perché di un evitamento, in italiano. Senza questa frase il giocatore
## vedrebbe solo un residente che fa un giro strano e penserebbe a un bug.
func perche_evita(luogo: String) -> String:
	var k := "luogo|" + luogo
	if not marchi.has(k):
		return ""
	var v: Dictionary = marchi[k]
	if float(v["carica"]) > -SOGLIA_EVITAMENTO:
		return ""
	return "gli è successo qualcosa di brutto lì (%d volte)" % int(v["conferme"])


## Tornarci senza che accada nulla SPEGNE la paura: è l'estinzione, ed è la
## porta che permette al giocatore di rimediare anche a un trauma.
func visita_serena(luogo: String) -> void:
	var k := "luogo|" + luogo
	if not marchi.has(k):
		return
	var v: Dictionary = marchi[k]
	v["carica"] = float(v["carica"]) * 0.62
	marchi[k] = v


# ============================================================ il giorno

## La notte rimette a posto il corpo, non la memoria: l'attivazione cala in
## fretta, l'umore molto più piano, la pazienza torna piena.
func passa_giorno(riposato := true) -> void:
	arousal = clampf(arousal * (1.0 - CALMA), 0.0, 1.0)
	umore = move_toward(umore, 0.0, RIENTRO_UMORE)
	regolazione = clampf(regolazione + (0.85 if riposato else 0.35), 0.0, 1.0)
	morsi_oggi = 0
	# i marchi non confermati si spengono piano
	for k in marchi:
		var v: Dictionary = marchi[k]
		v["carica"] = move_toward(float(v["carica"]), 0.0, ESTINZIONE)
		marchi[k] = v
	# le attese sbiadiscono verso il neutro: si può ricominciare a stupire
	for k in attese:
		attese[k] = move_toward(float(attese[k]), 0.0, 0.04)


## Come sta il corpo, in una riga: per la postura, la voce e il diario.
func stato_corpo() -> String:
	if arousal > 0.6:
		return "col cuore in gola"
	if arousal > 0.3:
		return "ancora guardingo"
	if umore < -0.35:
		return "di malumore"
	if umore > 0.35:
		return "di buonumore"
	if regolazione < 0.25:
		return "a corto di pazienza"
	return "tranquillo"


# ============================================================ salvataggio

func save() -> Dictionary:
	return {"arousal": arousal, "umore": umore, "regolazione": regolazione,
			"attese": attese.duplicate(), "marchi": marchi.duplicate(true),
			"reattivita": reattivita, "abitudine": abitudine}


func load(d: Dictionary) -> void:
	arousal = float(d.get("arousal", 0.0))
	umore = float(d.get("umore", 0.0))
	regolazione = float(d.get("regolazione", 1.0))
	attese = (d.get("attese", {}) as Dictionary).duplicate()
	marchi = (d.get("marchi", {}) as Dictionary).duplicate(true)
	reattivita = float(d.get("reattivita", 1.0))
	abitudine = float(d.get("abitudine", ABITUDINE))
