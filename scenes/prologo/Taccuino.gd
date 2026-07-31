extends RefCounted

## Gli assi del profilo del giocatore stanno LÌ, e da lì si leggono: il
## Prologo non ne tiene una copia (vedi `_sotto_soglia`).
const DIRECTOR := preload("res://scenes/npc/Director.gd")

## IL TACCUINO — quello che il gioco ha visto nei primi tre minuti.
##
## Nel Prologo non c'è un bivio. Non c'è una scritta «vuoi ripararti?», non
## c'è un pallino che lampeggia sulla foglia, non c'è un menu con due voci.
## C'è una cucciola sotto un temporale, e ci sei tu che la muovi. Le due o
## tre cose che fai in quei tre minuti le fai perché ti vengono, non perché
## il gioco te le ha proposte — ed è tutta la differenza: una scelta
## annunciata dice al giocatore «adesso ti sto misurando», e da lì in poi
## non risponde più lui, risponde il suo personaggio-di-facciata.
##
## Quindi il gioco prende appunti e sta zitto. Poi, a tutorial finito, la
## prima lettera glieli recita — ed è lì che uno capisce che il tutorial
## aveva delle conseguenze, e che le ha già avute.
##
## Questo file è la parte PURA: entrano quattro numeri misurati dalla
## scena, escono le tre conclusioni. Nessun nodo, nessun albero, niente
## `_process`: si prova headless (tests/cases/test_prologo.gd), e si può
## rispondere alla domanda «se uno fa così, cosa gli succede?» senza
## aprire il gioco.
##
## Le tre conclusioni:
##   · i SEMI del Regista — i suoi contatori partono inclinati, mai decisi
##     (vedi `semi()`);
##   · il MARCHIO del Limbico — quanto quel temporale resta addosso a
##     Mochi, e per quanti mesi (vedi `marchio()`);
##   · le RIGHE della lettera del Gufo — le stesse cose, dette da lui
##     (vedi `righe()`).

# ---------------------------------------------------------------- misure
#
# Quattro numeri, e nient'altro. La scena li riempie mentre si gioca; qui
# non si sa NIENTE di come siano stati misurati, ed è voluto: cambiare la
# forma della foglia non deve poter cambiare le conclusioni.

## Quanto della tempesta ha passato al riparo, 0..1.
var riparo := 0.0
## Quanto si è avvicinata al rigonfiamento nell'erba, 0..1 (1 = gli è
## arrivata col naso addosso; 0 = non ci è mai andata vicino).
var vicinanza := 0.0
## Quanti secondi è rimasta ferma, sotto l'acqua, senza scappare da nessuna
## parte. È il seme del Fiato Sospeso: qualcuno lo scopre già qui.
var fermo := 0.0
## Quanti secondi è durata la tempesta (per normalizzare `fermo`).
var durata := 1.0

# --------------------------------------------------------------- soglie
#
# Le soglie sono generose di proposito. Non si sta misurando un'abilità:
# si sta guardando UN'INCLINAZIONE, e chi ha esitato un momento sotto la
# foglia si è comunque riparato. Un prologo che pretende la precisione
# trasforma un gesto in una prova.

## Sopra questa frazione di tempesta al coperto: «si è messa al riparo».
const SOGLIA_RIPARO := 0.34
## Sotto questa: «è rimasta sotto l'acqua» (in mezzo non si giudica).
const SOGLIA_ACQUA := 0.12
## Sopra questa vicinanza: «è andata a vedere».
const SOGLIA_VICINO := 0.55
## Sotto questa: «ha fatto un passo indietro».
const SOGLIA_LONTANO := 0.22
## Oltre questa frazione di tempesta passata ferma: «è stata a guardare».
const SOGLIA_FERMA := 0.28


## Quanta parte della tempesta ha passato al coperto, 0..1. `riparo` sono
## SECONDI: le soglie sono frazioni, e confrontare le une con gli altri
## voleva dire dichiarare «si è riparata» a chiunque ci fosse passata
## sotto un secondo e mezzo.
func frazione_al_riparo() -> float:
	return clampf(riparo / maxf(0.001, durata), 0.0, 1.0)


## Come si è comportata col riparo: "riparo" | "acqua" | "" (né l'uno né
## l'altro: si è riparata a metà, e il gioco non ha niente da dire).
func scelta_riparo() -> String:
	var f := frazione_al_riparo()
	if f >= SOGLIA_RIPARO:
		return "riparo"
	return "acqua" if f <= SOGLIA_ACQUA else ""


## Come si è comportata col rigonfiamento: "vicino" | "indietro" | "".
func scelta_erba() -> String:
	if vicinanza >= SOGLIA_VICINO:
		return "vicino"
	return "indietro" if vicinanza <= SOGLIA_LONTANO else ""


## È stata ferma a guardare la tempesta invece di sbatterci dentro?
func e_stata_a_guardare() -> bool:
	return durata > 0.0 and fermo / durata >= SOGLIA_FERMA


# ----------------------------------------------------------- i tre esiti

## I SEMI DEL REGISTO: contatore -> quanti, da sommare a `Director._contatori`.
##
## Massimo DUE per asse, ed è la cosa importante di questa funzione.
## `Director.profilo()` chiede più di due gesti prima di dire chi sei
## (`best_v := 2`): con un seme da due, il Prologo non decide niente — mette
## il pollice sulla bilancia, e il primo gesto vero che fai nel villaggio
## la fa pendere. Con un seme da tre avrebbe deciso lui, e il giocatore si
## sarebbe ritrovato etichettato da tre minuti di pioggia.
##
## I contatori sono quelli VERI di `Director.ASSI` — non una tabella
## parallela: un asse rinominato lì deve rompere il test, non scollegare
## il Prologo in silenzio.
func semi() -> Dictionary:
	var out := {}
	match scelta_riparo():
		"riparo":
			# cercarsi un tetto è il primo gesto di chi poi ne costruirà
			out["costruzione"] = 2
		"acqua":
			# stare nel mondo com'è, anche quando è scomodo
			out["bosco"] = 2
	match scelta_erba():
		"vicino":
			# è andata verso una cosa viva che non conosceva: è tutto qui
			out["socievole"] = 2
		"indietro":
			out["bosco"] = int(out.get("bosco", 0)) + 1
	if e_stata_a_guardare():
		out["stelle"] = 1
	return _sotto_soglia(out)


## LA CINTURA: nessun ASSE esce di qui già deciso, mai.
##
## Il tetto va messo per asse e non per contatore, ed è un errore che era
## già dentro: «bosco» e «stelle» sono due contatori diversi ma stanno
## nello stesso asse (contemplativo), e chi era rimasta sotto l'acqua, era
## andata a vedere ed era stata ferma si ritrovava 2+1 = tre. Tre è la
## soglia di `Director.profilo()`: il Prologo le aveva deciso il carattere
## prima ancora che entrasse nel villaggio.
##
## Gli assi si leggono da `Director.ASSI` — mai una copia: un asse
## rinominato di là deve rompere il test, non scollegare il Prologo in
## silenzio. Quando un asse sfora si toglie dal contatore più PICCOLO,
## così il segnale principale (quello da due) resta in piedi.
const MASSIMO_PER_ASSE := 2

static func _sotto_soglia(semi_grezzi: Dictionary) -> Dictionary:
	var out := semi_grezzi.duplicate()
	for asse in DIRECTOR.ASSI:
		var somma := 0
		for evento in DIRECTOR.ASSI[asse]:
			somma += int(out.get(evento, 0))
		while somma > MASSIMO_PER_ASSE:
			var minore := ""
			for evento in DIRECTOR.ASSI[asse]:
				var q := int(out.get(evento, 0))
				if q > 0 and (minore == "" or q < int(out[minore])):
					minore = str(evento)
			if minore == "":
				break
			out[minore] = int(out[minore]) - 1
			if int(out[minore]) <= 0:
				out.erase(minore)
			somma -= 1
	return out


## IL MARCHIO DEL LIMBICO: {"carica": -1..0, "conferme": n}, pronto per
## `Limbico.marchi["luogo|temporale"]`.
##
## Quanto quel temporale le è entrato addosso. Non è una punizione per
## aver giocato «male» — non c'è un male: è che una notte passata sotto
## l'acqua e una notte passata sotto una foglia non sono la stessa notte, e
## il corpo se le ricorda diverse.
##
## Due cose la attenuano, e sono le due cose che l'hanno attenuata davvero:
## essersi trovata un riparo (il temporale è successo, ma da dentro), ed
## essersi avvicinata a quel rigonfiamento (una paura divisa in due è
## un'altra paura — e sotto quell'erba c'era qualcuno che tremava come lei).
##
## `conferme` è a 2 e non a 1 di proposito: il marchio deve reggere alla
## prima pioggia del villaggio senza spegnersi, o «mesi dopo puoi
## spegnerlo» diventa «la settimana dopo si è spento da solo».
func marchio() -> Dictionary:
	var c := -0.85
	if scelta_riparo() == "riparo":
		c += 0.24
	if scelta_erba() == "vicino":
		c += 0.20
	# chi è rimasta ferma a guardarla, la tempesta, l'ha anche GUARDATA:
	# non è solo una cosa che le è caduta addosso
	if e_stata_a_guardare():
		c += 0.08
	return {"carica": clampf(c, -1.0, -0.25), "conferme": 2}


## LE RIGHE DELLA LETTERA: le chiavi italiane dei versi che il Gufo le
## recita, nell'ordine in cui le cose sono successe.
##
## Sono chiavi e non frasi (vedi `L10n.rendi`): la lettera passa dalla coda
## della posta, quindi dal disco, e deve poter parlare la lingua di chi la
## apre — non quella di chi l'ha scritta tre minuti dopo l'avvio.
##
## Il Gufo NON commenta e NON approva: dice cosa ha visto. È la differenza
## fra «hai fatto la scelta prudente» (che ti dice che c'era una scelta, e
## ti fa venire voglia di rigiocarla) e «ti sei messa sotto la foglia»
## (che ti dice solo che qualcuno guardava).
func righe() -> Array:
	var out: Array = []
	match scelta_riparo():
		"riparo":
			out.append({"k": "Ti sei infilata sotto la foglia grande\ne ci sei rimasta finché non è passata."})
		"acqua":
			out.append({"k": "C'era una foglia grande, a due passi.\nNon ci sei andata. Sei rimasta sotto l'acqua\ntutto il tempo, e l'acqua ti è passata addosso."})
		_:
			out.append({"k": "Sei entrata e uscita da sotto la foglia\ncome se non ti decidessi. Anch'io facevo così."})
	match scelta_erba():
		"vicino":
			out.append({"k": "\n\nPoi l'erba si è mossa, e tu ci sei andata VICINO.\nDi tutte le cose che potevi fare, quella notte,\nquella lì non me l'aspettavo."})
		"indietro":
			out.append({"k": "\n\nPoi l'erba si è mossa, e tu hai fatto un passo indietro.\nHai fatto bene. Non sapevi cosa c'era."})
		_:
			out.append({"k": "\n\nPoi l'erba si è mossa. Ti sei fermata a metà strada\ne sei rimasta lì, a decidere."})
	if e_stata_a_guardare():
		out.append({"k": "\n\nE per un pezzo sei stata ferma, sotto l'acqua,\nsenza fare niente. Tienitelo da parte, quel niente:\nda queste parti serve più di quanto sembri."})
	out.append({"k": "\n\nNon te l'ho chiesto io, di fare così.\nL'hai fatto e basta. — Il Gufo"})
	return out


# --------------------------------------------------------- disco e ritorno

## Gli appunti come dizionario da salvare (le MISURE, non le conclusioni:
## le conclusioni si ricalcolano, così ritoccare una soglia sistema anche
## i villaggi già cominciati invece di lasciarli con la vecchia lettura).
func da_salvare() -> Dictionary:
	return {"riparo": riparo, "vicinanza": vicinanza,
			"fermo": fermo, "durata": durata}


static func da_dizionario(d: Dictionary) -> RefCounted:
	var t := new()
	t.riparo = float(d.get("riparo", 0.0))
	t.vicinanza = float(d.get("vicinanza", 0.0))
	t.fermo = float(d.get("fermo", 0.0))
	t.durata = maxf(0.001, float(d.get("durata", 1.0)))
	return t
