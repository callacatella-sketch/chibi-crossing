extends RefCounted

## IL SUGGERITORE — quello che si sussurra a chi scrive, e che è VERO.
##
## Fase 5, il passo del prompt. Da qualche parte, fuori da questo file, gira
## un modello di linguaggio piccolo che scrive di suo pugno le lettere del
## Gufo, i pensieri e i discorsi. Questo file non lo chiama, non lo carica e
## non sa che esista: **prepara le parole da dargli, e la lista di quelle
## che ha il permesso di dire.** Tutto quello che c'è qui dentro è puro,
## deterministico e provabile senza un modello — perché se il modello non
## c'è (ed è il caso normale: chi non l'ha installato ha un gioco meno
## sorprendente, non un gioco a cui manca un pezzo) questo file resta
## comunque una funzione che trasforma un vicino in un foglio di carta.
##
## Il nome è quello del mestiere: nel teatro il suggeritore sta nella buca,
## conosce la parte meglio dell'attore, e **non recita mai**. Se l'attore non
## si presenta, lo spettacolo va in scena col copione scritto a mano — che
## qui sono le lettere del Gufo che esistono già
## (`Director.TACCUINO_LETTERE`).
##
## ────────────────────────────────────────────────────────────────────────
## LA REGOLA CHE VIENE PRIMA DI TUTTE: SI AFFERMA SOLO CIÒ CHE SI È VISTO
## ────────────────────────────────────────────────────────────────────────
##
## È la regola del taccuino del Gufo, e qui non cambia di una virgola —
## cambia solo chi la può violare. Là il rischio era una lettera scritta a
## mano citata nel momento sbagliato; qui è una macchina che sa scrivere
## frasi plausibili su un villaggio che non ha mai visto. La modalità di
## guasto è la stessa, ed è catastrofica: **una frase citata a vuoto non
## attenua l'effetto, lo INVERTE.** «Mirtillo ti ha vista pescare» detto a
## chi non ha mai pescato insegna al giocatore che le lettere sono
## generate, e da quel momento non crede più a nessuna — comprese le dodici
## scritte a mano che sono costate mesi.
##
## Perciò questo file taglia il problema in due metà e le tiene separate per
## COSTRUZIONE:
##
##  1. **LA METÀ CHE AFFERMA È CHIUSA.** Le frasi con cui il modello può
##     dire cos'è successo sono una LISTA FINITA, generata qui dal grafo dei
##     ricordi di quel vicino: `citazioni()`. Se una cosa non è nel grafo, la
##     frase che la dice non esiste — non «è sconsigliata»: non esiste. La
##     stessa lista genera la grammatica GBNF (che impedisce al modello di
##     campionare altro) e il collaudo `accetta()` (che impedisce a un testo
##     di arrivare allo schermo). Una lista, due guardiani: non possono
##     divergere perché leggono la stessa funzione.
##  2. **LA METÀ LIBERA NON PUÒ AFFERMARE NIENTE.** Quello che il modello
##     aggiunge di suo è un pensiero in prima persona — «ci ho pensato tutto
##     il pomeriggio, sul mio ramo» — cioè materia di CHI PARLA, sempre vera
##     perché è sua e non si può smentire. È esattamente la divisione delle
##     lettere del Gufo già scritte: la prima metà è verificabile, la seconda
##     è sempre vera perché è sua.
##
## E per rendere la seconda metà incapace di nominare il villaggio, la
## grammatica non le dà le MAIUSCOLE: senza maiuscole non ci sono nomi
## propri. Il gioco rimette la maiuscola a inizio riga quando stampa
## (`rifinisci`), che è una trasformazione di presentazione — non un
## permesso restituito a chi scrive.
##
## ⚠️ IL RESIDUO, dichiarato: una parola minuscola inventata («il bosco di
## ombrafitta») è grammaticalmente possibile e nessun controllo puro la può
## distinguere da un nome comune. Quello che NON è più possibile è
## affermare un fatto: i fatti stanno tutti nella riga chiusa, e una riga
## libera che dicesse «ti ha vista pescare» sarebbe scartata da `accetta()`
## perché quella frase non è nella lista.
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ STA IN GDSCRIPT E NON IN C++ (dove sta il grafo)
## ────────────────────────────────────────────────────────────────────────
##
## Il grafo dei ricordi vive nel cuore C++ (`src/grafo_ricordi.h`), e i
## quattro sistemi puri di là (sonno, agenda, piani, occ) sarebbero il posto
## naturale per un quinto gemello. Non è dove va questo. Tre ragioni, in
## ordine di peso:
##
##  1. **Un prompt è fatto di PAROLE, e le parole di questo gioco vivono
##     tutte di qua.** Le indoli e le loro descrizioni
##     (`VillagerBrain.INDOLI`), le stravaganze (`QUIRK_LINES`), le otto
##     azioni (`AZIONI`), gli obiettivi (`Piani.OBIETTIVO`), le età
##     (`Legami.eta_di`), le stagioni (`DayNight.SEASON_NAMES`), i momenti
##     del giorno (`OraDelGiorno.MOMENTI`). Un costruttore di prompt in C++
##     dovrebbe farsele passare tutte dal ponte — cioè il GDScript
##     preparerebbe comunque il materiale e il C++ farebbe la colla. La colla
##     non è il mestiere interessante, e in mezzo ci sarebbero sei tabelle in
##     più che possono divergere.
##  2. **I quattro gemelli sono puri E SENZA ALLOCAZIONI**, e non per vezzo
##     (un sistema che alloca durante il frame ogni tanto fa un singhiozzo, e
##     i singhiozzi si vedono). Un file il cui unico mestiere è costruire
##     stringhe sarebbe un gemello che tradisce la regola di famiglia il
##     primo giorno — e senza motivo: un prompt si costruisce quando parte
##     una lettera, non trenta volte al secondo.
##  3. **Provabile senza il binario.** `componi()` prende un Dictionary
##     scritto a mano e torna una stringa: il test guasta una valvola per
##     volta senza accendere né un villaggio né una GDExtension. In questo
##     progetto una guardia che nessun test può far diventare rossa è già
##     stata, tre volte, una guardia che non c'era.
##
## Quello che invece NON si copia di qua: gli otto verbi, le sei cose, i
## quattro obiettivi, le tre bandiere e il peso di un ricordo. Quelli
## arrivano dal binario dentro il ritratto (vedi `ritratto()`); le tabelle
## lessicali di questo file sono legate alle loro dall'alto da
## `test_suggeritore.gd`, e un nono verbo fa diventare rossa la suite qui.
##
## ────────────────────────────────────────────────────────────────────────
## LA LINGUA
## ────────────────────────────────────────────────────────────────────────
##
## Il prompt è in ITALIANO e non passa da `L10n`, per due motivi che non
## sono lo stesso motivo:
##  · non è testo che il giocatore vede — è testo che legge un modello, e
##    quel modello scrive nella lingua sorgente del gioco (è la ragione per
##    cui l'autore ha scelto un 3B e non un 1B: l'italiano di un 1B non
##    supererebbe le lettere già scritte a mano);
##  · gli otto verbi e le sei cose sono DATI, non testo: viaggiano dentro il
##    grafo e restano italiani per sempre, come i nomi dei pezzi e i gradini
##    di `Animo.SCALA` («si traduce solo al momento di mostrare, mai il
##    dato»).
##
## ⚠️ CONSEGUENZA DICHIARATA, per chi cablerà l'uscita allo schermo: il testo
## che il modello produce **non ha, e non può avere, una voce in tabella** —
## nasce a runtime, e `tests/cases/test_localizzazione.gd` non potrà mai
## vederlo. Perciò chi lo mostra deve chiedersi in che lingua si sta
## giocando: in inglese la strada giusta è NON mostrarlo e lasciare le
## lettere scritte a mano, che sono tradotte. Un villaggio inglese con una
## lettera italiana in mezzo è peggio di un villaggio senza sorprese.

## Le descrizioni di indole e stravaganza si leggono da dove già vivono. Non
## si passa da `VillagerBrain.descrizione()` per una ragione sola: quella
## traduce con `L10n.t()` (giustamente: la mostra al giocatore), e qui il
## testo va a un modello che scrive in italiano.
const BRAIN := preload("res://scenes/npc/VillagerBrain.gd")


# =========================================================================
# LE TABELLE LESSICALI, e come si tengono legate alle enum
# =========================================================================

## L'INFINITO DEGLI OTTO VERBI. La tabella vera dei verbi è nel binario
## (`chibi::Verbo` / `VERBI[]` in src/ecs_mondo.cpp): questa non è una
## seconda tabella dei verbi, è la loro CONIUGAZIONE — una cosa che il C++
## non ha e non deve avere.
##
## Le chiavi si legano alle otto vere da `test_suggeritore.gd`, che le legge
## con `EcsMondo.nome_verbo()` e pretende gli stessi otto nomi: un nono
## verbo, o un verbo rinominato, fa diventare rossa la suite QUI invece di
## far uscire una lettera con dentro un buco.
const INFINITO := {
	"annaffia": "annaffiare le aiuole",
	"semina": "seminare",
	"raccoglie": "raccogliere quello che era maturo",
	"costruisce": "costruire",
	"taglia": "tagliare la legna",
	"pesca": "pescare",
	"cucina": "cucinare",
	"dona": "regalare qualcosa",
}

## LE SEI COSE, come si nominano in una frase. Stessa disciplina di sopra:
## chiavi legate a `EcsMondo.nome_cosa()`. È l'idioma di
## `Critters.etichetta()` — un secondo registro dello stesso nome, derivato
## in un posto solo e mai un secondo dato da tenere allineato a mano.
const NOMI_COSE := {
	"fiore": "i fiori",
	"cibo": "quello che si mangia",
	"casa": "le case",
	"fuoco": "il fuoco",
	"pesce": "i pesci",
	"amico": "gli amici",
}

## LE OTTO AZIONI, dette in italiano. La tabella vera è `VillagerBrain.AZIONI`
## (che il C++ traduce e basta), e un test lega queste chiavi a quella.
## «regia» è la routine composta dal giocatore e «gironzola» è il ripiego:
## si dicono per quello che si VEDE, non per come si chiamano dentro.
##
## ⚠️ TUTTO QUESTO FILE PARLA SENZA GENERE dei vicini, e non è pudore: il
## villaggio non sa se un chibi è maschio o femmina — nessuna delle sue voci
## lo dice (`VillagerBrain.INDOLI` sono tutte neutre, i toast usano il nome),
## e l'unico genere che il gioco dichiara è quello di Mochi, femminile, che
## infatti si sente in «ti ho vista». Un «si è fermato» qui dentro non
## resterebbe qui dentro: insegnerebbe al modello il genere sbagliato e
## uscirebbe nella lettera, dove il giocatore lo legge.
const AZIONI_DETTE := {
	"spuntino": "cerca qualcosa da sgranocchiare",
	"riposo": "si riposa",
	"quattro_chiacchiere": "cerca qualcuno con cui parlare",
	"cura_giardino": "si occupa di un'aiuola",
	"meraviglia": "guarda qualcosa di bello",
	"stella": "guarda il cielo",
	"regia": "fa il suo giro",
	"gironzola": "gironzola senza una meta",
}

## I QUATTRO OBIETTIVI del pianificatore, detti in italiano. La tabella vera
## è `Piani.OBIETTIVO` (e di là `chibi::Provvedimento`): il test lega queste
## quattro chiavi a quei quattro nomi **e** chiede al binario che ognuno
## abbia una maschera vera, così una quinta voce inventata qui non passa.
##
## Il verbo è «provvedere», non «essere sazio», ed è la stessa precisione del
## risolutore: l'obiettivo non è «sono sazio» ma «ho fatto qualcosa per la
## mia fame» — se il prompt dicesse la prima, la lettera racconterebbe una
## pancia piena che nessuno ha riempito.
##
## TUTTE E QUATTRO COMINCIANO CON «sta », e non è un caso: da quella forma si
## ricavano le altre due che servono (`stava` per la lettera, che si legge il
## mattino dopo; `sto` per il pensiero, che è in prima persona) con una
## sostituzione sola e visibile. Chi ne aggiunge una quinta la scriva così, o
## `fatto_obiettivo()` gli restituisce una frase sgrammaticata — e il test la
## legge per esteso, tutte e quattro per tutti e tre i compiti.
const OBIETTIVI_DETTI := {
	"provvedi_pancino": "sta facendo qualcosa per la fame",
	"provvedi_cura": "sta facendo qualcosa per un'aiuola",
	"provvedi_energia": "sta cercando un posto dove riposare",
	"provvedi_meraviglia": "sta andando a cercare qualcosa di bello",
}


# =========================================================================
# LE SCALE — quando una misura diventa una parola
# =========================================================================

## LE DUE SOGLIE DEL PESO DI UN RICORDO, e non sono scelte qui.
##
## L'unità è **l'OCCHIATA**: un ricordo fresco, visto una volta, non fatto a
## me, a gusto neutro pesa esattamente 1.0 (`chibi::peso`). Su quella scala
## il gioco ha già deciso due cose, e questo file non ne inventa una terza:
##  · `Visitors.AMMIRA_SOGLIA` (0.35) — sotto, il villaggio smette di
##    tenerne conto: l'ancora di un vicino torna a casa;
##  · `Visitors.RICORDO_SOGLIA` (1.0) — sopra, il ricordo merita di
##    attraversare un riavvio.
## Stanno ricopiate qui perché `Visitors.gd` è un nodo da quattromila righe e
## un file puro non deve dipenderne per due numeri; `test_suggeritore.gd` le
## legge di là e pretende che combacino.
const SOGLIA_TIEPIDO := 0.35
const SOGLIA_VIVO := 1.0

## E la terza è DERIVATA, non scelta: `ripetizioni(6)` con la curva del
## binario (`RIP_TETTO`/`RIP_MEZZA`) vale esattamente 2.25 — «sei aiuole
## annaffiate nello stesso gesto valgono 2.25 volte una, non sei», l'esempio
## già scritto in `src/grafo_ricordi.h`. Il test la ricalcola da quella curva
## invece di fidarsi di questo numero.
const SOGLIA_VIVISSIMO := 2.25

## Quanti ricordi entrano nel foglio. Sei, e non ventiquattro, per due
## ragioni che tirano nella stessa direzione:
##  · un modello da tre miliardi di parametri annega in un elenco lungo, e
##    la prima cosa che perde è proprio l'attenzione al primo elemento;
##  · il settimo ricordo è per costruzione più debole del sesto (si ordina
##    per peso), quindi quello che si taglia è sempre la coda.
const MAX_RICORDI := 6

## QUANTO STA LONTANO DA CASA SUA, in metri, perché valga la pena dirlo.
## In mezzo c'è una FASCIA GRIGIA in cui non si dice niente: è la regola 2
## del taccuino («il silenzio è il comportamento normale»), e qui serve
## perché «a due passi da casa sua» detto di una cosa successa a quindici
## metri è il genere di quasi-verità che il giocatore smaschera al primo
## colpo d'occhio. I due numeri vengono dal villaggio: `Visitors.SPOSTA_MAX`
## è 6 m (quanto un vicino si sposta per un ricordo) e `MOCHI_VICINA` è 20 m
## (oltre quella, «più vicino» vuol dire dall'altra parte del prato).
const VICINO_M := 8.0
const LONTANO_M := 25.0

## QUANTE VOLTE, perché diventi «a lungo». Due è la ripetizione minima che il
## grafo sappia contare (`quante` cresce solo dentro `FINESTRA_FUSIONE`);
## quattro è dove la curva delle ripetizioni ha già speso metà della sua
## corsa (2.0 su un tetto di 4.0), cioè dove «ancora» diventa «a lungo».
const VOLTE_PIU := 2
const VOLTE_LUNGO := 4


# =========================================================================
# I TRE COMPITI — chi parla, a chi, e quanto respira
# =========================================================================

## Un solo costruttore, tre registri. Le chiavi:
##  · `ruolo`    — la riga che apre il messaggio di sistema;
##  · `apertura` — se è concesso un rigo di prosa PRIMA della citazione;
##  · `chiusura_min`/`chiusura_max` — quante righe di prosa dopo.
##
## «lettera» è il Gufo che scrive a Mochi **di un vicino**, ed è la novità
## vera: la Fase 4 ha costruito una vita interiore che il giocatore non può
## vedere in nessun modo (le sue conseguenze sono tutte mute, per scelta —
## dove uno si mette, come tiene il corpo, che simbolo esce fra due di loro).
## Il Gufo è l'unico personaggio del gioco che ha il permesso di guardare
## dall'alto e dire cos'ha visto: è già il suo mestiere, e non ne apre uno.
const COMPITI := {
	"lettera": {
		"ruolo": "Scrivi come il Gufo, che guarda il villaggio dal suo ramo e ogni tanto manda una lettera a %s.",
		"apertura": true, "chiusura_min": 1, "chiusura_max": 2,
	},
	"pensiero": {
		"ruolo": "Scrivi il pensiero che passa per la testa di %s mentre non sta facendo niente di importante.",
		"apertura": false, "chiusura_min": 1, "chiusura_max": 1,
	},
	"discorso": {
		"ruolo": "Scrivi quello che %s dice a voce, adesso, a chi si è appena avvicinato.",
		"apertura": false, "chiusura_min": 1, "chiusura_max": 1,
	},
}

## Quante parole può avere una riga libera. Il minimo esiste perché tre
## parole non sono un pensiero (sono un titolo); il massimo perché le lettere
## del Gufo vanno a capo a mano, e una riga lunga la busta la spezza a metà
## parola — regola 7 del taccuino, pagata guardando una lettera vera.
const PAROLE_MIN := 4
const PAROLE_MAX := 15

## Le lettere che una riga libera può contenere. **Nessuna maiuscola**, e
## nessuna cifra: senza maiuscole non ci sono nomi propri, senza cifre non ci
## sono quantità inventate. Le uniche punteggiature ammesse dentro la riga
## sono la virgola e l'apostrofo, che in italiano servono a respirare
## («l'ho vista», «non so, forse»).
const LETTERE := "abcdefghijklmnopqrstuvwxyzàáèéìíòóùúç'"
const FINALI := [".", "…"]


# =========================================================================
# IL RITRATTO — cosa serve sapere di un vicino per parlare di lui
# =========================================================================

## RACCOGLIE IL RITRATTO dal cuore vivo. È l'UNICO punto di questo file che
## tocca la GDExtension, ed è di proposito: tutto il resto lavora sul
## Dictionary che esce di qui, quindi un test può fabbricarne uno a mano e
## guastarlo una valvola per volta.
##
##  · `cuore` — l'oggetto `EcsMondo` (`Visitors.cuore()`), o null;
##  · `id`    — l'handle ECS di quel vicino (`r["ecs"]`);
##  · `chi`   — quel che sa il registro dei vicini e il cuore non sa:
##              {nome, eta, indole, quirk, casa, azione, obiettivo};
##  · `mondo` — quel che sa il livello: {stagione, momento, ciclo,
##              protagonista, nomi, compito}.
##
## `nomi` è la mappa handle → nome dei residenti VIVI, e ha una ragione
## sola: un ricordo porta dentro l'handle completo di chi ha ricevuto un
## dono, e un handle morto non deve risolvere a nessuno. Chi non è nella
## mappa non viene nominato — non diventa «qualcuno», sparisce dalla frase.
## È il degrado dichiarato dal grafo stesso: «un'etichetta assente, mai un
## comportamento sbagliato».
##
## ⚠️ QUI SI CHIAMANO I `debug_*` DEL CUORE, e non è una svista. `debug_grafo`
## e `debug_emozioni` sono ORACOLI (allocano un Dictionary), e la loro
## intestazione lo dice; le tre letture vive della Fase 4 — `ammirazione`,
## `dove`, `cosa_da_ricordare` — sono altre domande, e nessuna di loro
## risponde a «tutto quello che questo vicino ricorda». Il motivo per cui si
## può fare: un prompt si costruisce quando parte una lettera (una manciata
## di volte al giorno di gioco), non dentro un frame — è la stessa ragione
## per cui questo file può permettersi di costruire stringhe. Chi un domani
## volesse chiamare `ritratto()` a ogni frame ha sbagliato prima, non qui.
static func ritratto(cuore: Object, id: int, chi: Dictionary, mondo: Dictionary) -> Dictionary:
	var r := {}
	for k in chi:
		r[k] = chi[k]
	for k in mondo:
		r[k] = mondo[k]
	if cuore == null or not is_instance_valid(cuore):
		# NIENTE CUORE, NIENTE RICORDI, quindi niente da affermare: il prompt
		# uscirà vuoto e il gioco userà le lettere scritte a mano. È il
		# comportamento che deve avere anche un clone appena scaricato, dove
		# la GDExtension non è ancora stata compilata.
		return r
	var costanti: Dictionary = cuore.call("debug_grafo_costanti")
	var ritmo: Dictionary = cuore.call("debug_ritmo")
	var grafo: Dictionary = cuore.call("debug_grafo", id)
	var emo: Dictionary = cuore.call("debug_emozioni", id)

	var verbi := []
	for i in int(costanti.get("n_verbi", 0)):
		verbi.append(str(cuore.call("nome_verbo", i)))
	var cose := []
	for i in int(costanti.get("n_cose", 0)):
		cose.append(str(cuore.call("nome_cosa", i)))

	var ora := float(ritmo.get("tempo", 0.0))
	var mezza := float(ritmo.get("mezza_vita", 0.0))
	var righe: Array = grafo.get("ricordi", [])
	# IL PESO NON SI RICALCOLA DI QUA. La formula sta in `chibi::peso` e ha
	# già due lettori di là: scriverne una terza copia qui vorrebbe dire che
	# il giorno che si tara la curva delle ripetizioni il foglio comincia a
	# raccontare un villaggio con altre proporzioni — in silenzio, e con la
	# suite verde. Si chiede all'oracolo, riga per riga.
	var pesi := PackedFloat64Array()
	pesi.resize(righe.size())
	for i in righe.size():
		pesi[i] = float(cuore.call("debug_grafo_peso", righe[i], ora, mezza))

	r["ricordi"] = righe
	r["pesi"] = pesi
	r["verbi"] = verbi
	r["cose"] = cose
	r["gusto"] = emo.get("gusto", PackedFloat64Array())
	r["tinte"] = {
		"ammirazione": float(emo.get("ammirazione", 0.0)),
		"gratitudine": float(emo.get("gratitudine", 0.0)),
		"interesse": emo.get("interesse", PackedFloat64Array()),
	}
	r["ora"] = ora
	r["mezza_vita"] = mezza
	# LE TRE BANDIERE ARRIVANO DAL BINARIO, mai scritte a mano: un file che
	# scrive «2» per R_SU_DI_ME resta verde il giorno che le bandiere
	# cambiano valore, e comincia a chiamare «regalo» un'annaffiata.
	r["bandiere"] = {
		"sentito": int(costanti.get("r_sentito", 0)),
		"su_di_me": int(costanti.get("r_su_di_me", 0)),
		"detto": int(costanti.get("r_detto", 0)),
		"nessuno": int(costanti.get("sogg_nessuno", -1)),
	}
	return r


# =========================================================================
# I FATTI — la lista finita di ciò che si può affermare
# =========================================================================

## I RICORDI ORDINATI, potati e tradotti in atomi di frase. È il cuore del
## file: da qui escono le frasi ammesse, il blocco del prompt che le mostra
## e il collaudo. Una volta sola.
##
## Ogni voce: {"base", "mods", "forza", "riga"} — l'ultima è l'indice nel
## grafo, cioè la prova di provenienza.
##
## LE TRE POTATURE, e ognuna chiude un modo preciso di affermare il falso:
##  1. **senza le bandiere non si afferma NIENTE.** Se il ritratto non porta
##     i valori veri delle bandiere non si può distinguere ciò che uno ha
##     VISTO da ciò che gli hanno RACCONTATO — e sono due frasi diverse, di
##     cui una sarebbe falsa. Si torna la lista vuota, cioè silenzio.
##  2. **un ricordo spento non è conoscenza.** È la stessa riga che il
##     passaparola ha già dovuto scrivere (`EcsMondo::racconta`): un peso che
##     non è > 0 (e `!(p > 0)` prende anche il NaN) è un ricordo che il
##     villaggio non usa più per niente, e citarlo vorrebbe dire far parlare
##     un vicino di una cosa che non ha più in testa.
##  3. **un verbo fuori tabella non ha una frase.** Non si inventa un
##     infinito: la riga sparisce.
static func fatti(rit: Dictionary) -> Array:
	var bandiere: Dictionary = rit.get("bandiere", {})
	if not (bandiere.has("sentito") and bandiere.has("su_di_me") and bandiere.has("nessuno")):
		return []
	var f_sentito := int(bandiere["sentito"])
	var f_su_di_me := int(bandiere["su_di_me"])
	var nessuno := int(bandiere["nessuno"])

	var righe: Array = rit.get("ricordi", [])
	var pesi = rit.get("pesi", null)
	var verbi: Array = rit.get("verbi", [])
	var compito := compito_di(rit)

	# --- si ordina per peso, e i pari li rompe l'indice ------------------
	# «A parità vince l'indice più basso: nessun dado, mai» è la regola di
	# `da_raccontare` e di `dove`, e vale anche qui: `sort_custom` in Godot
	# NON è stabile, quindi il criterio di pareggio si scrive a mano o due
	# esecuzioni identiche danno due lettere diverse.
	var ordine := []
	for i in righe.size():
		var p := 1.0
		if pesi != null and i < pesi.size():
			p = float(pesi[i])
			if not (p > 0.0):
				continue
		ordine.append({"i": i, "p": p})
	ordine.sort_custom(func(a, b):
		if float(a["p"]) == float(b["p"]):
			return int(a["i"]) < int(b["i"])
		return float(a["p"]) > float(b["p"]))

	var out := []
	for voce in ordine:
		if out.size() >= MAX_RICORDI:
			break
		var riga: Dictionary = righe[int(voce["i"])]
		var v := int(riga.get("verbo", -1))
		if v < 0 or v >= verbi.size():
			continue
		var inf := str(INFINITO.get(str(verbi[v]), ""))
		if inf == "":
			continue
		var b := int(riga.get("bandiere", 0))
		var sentito := (b & f_sentito) != 0
		var su_di_me := (b & f_su_di_me) != 0
		out.append({
			"base": _base(rit, compito, inf, sentito, su_di_me, riga, nessuno),
			"mods": _mods(rit, riga, sentito),
			"forza": _forza(float(voce["p"]), pesi != null),
			# L'INDICE DELLA RIGA NEL GRAFO, e non è per il debug: è la prova
			# di provenienza. Con lui una verifica può chiedere «questa frase
			# da quale ricordo viene?» e ricevere un numero, invece di cercare
			# una parola dentro una stringa — che è come si scrive una verifica
			# che passa per il motivo sbagliato (la prima stesura di
			# `prova_prompt.gd` dichiarava orfane le frasi del dono, perché il
			# dono si dice senza nominare il verbo).
			"riga": int(voce["i"]),
		})
	return out


## LA FRASE SULL'OBIETTIVO — l'unico posto in cui i quattro provvedimenti
## del pianificatore diventano una cosa che si può dire, e l'unica frase
## chiusa che non parla di Mochi.
##
## È una lista che ne contiene al massimo UNA: gli obiettivi sono quattro
## nell'enum, ma **uno solo è vero adesso** (quello dell'azione che l'agenda
## ha scelto), e tre azioni su otto non ne hanno nessuno — «quattro
## chiacchiere» e «gironzola» non hanno un piano APPOSTA, perché un piano su
## una cosa che cammina è sbagliato appena lo consegni. Se l'obiettivo non
## arriva, o non è dei quattro, qui non esce niente.
##
## ⚠️ IL TEMPO DELLA FRASE NON È UN VEZZO. Una lettera si mette in coda
## stanotte e si apre domattina (è la regola della posta): «sta cercando
## qualcosa da mangiare», letto il mattino dopo, è falso. Perciò nella
## lettera la frase è incorniciata da chi la scrive — «quando l'ho guardato»
## — che è vero per sempre perché è del Gufo. Nel pensiero e nel discorso,
## che sono immediati, il presente resta presente.
static func fatto_obiettivo(rit: Dictionary) -> Array:
	var ob := str(rit.get("obiettivo", ""))
	var detto := str(OBIETTIVI_DETTI.get(ob, ""))
	if detto == "":
		return []
	var nome := str(rit.get("nome", ""))
	match compito_di(rit):
		"lettera":
			# la cornice («quando ho guardato giù») è del Gufo, quindi vera
			# per sempre; e non nomina nessuno, quindi non ha bisogno di una
			# preposizione davanti a un nome. Vedi la nota qui sopra.
			return ["Quando ho guardato giù, %s %s" % [nome, detto.replace("sta ", "stava ")]]
		"discorso":
			return []  # non si annuncia il proprio piano a voce: si fa
		_:
			return [detto.replace("sta ", "sto ")]


## LA FRASE NUDA: chi, come l'ha saputo, e cosa. Nient'altro.
static func _base(rit: Dictionary, compito: String, inf: String, sentito: bool,
		su_di_me: bool, riga: Dictionary, nessuno: int) -> String:
	var nome := str(rit.get("nome", ""))
	var altro := _destinatario(rit, riga, nessuno)

	if compito == "lettera":
		if sentito:
			# «se l'è sentito raccontare» e non «ha saputo che hai»: l'eco non
			# riparte mai da chi l'ha solo sentita, quindi chi gliel'ha detta
			# l'aveva vista con i propri occhi. È vero, ed è la sola forma che
			# non promuove un sentito dire a testimonianza.
			#
			# ⚠️ E NON COMINCIA CON UNA PREPOSIZIONE, che è una cosa che si
			# scopre solo guardando: il nome di un vicino non è «Papavero», è
			# «la volpina Papavero» (è la sua `label`, quella che il giocatore
			# legge nei toast). «A la volpina Papavero hanno raccontato…» è
			# sgrammaticato, e l'unico modo di aggiustarlo sarebbe una tabella
			# di preposizioni articolate — cioè inventarsi una grammatica
			# italiana dentro un generatore di prompt. Si gira la frase, e il
			# problema non esiste: nessuna delle frasi di questo file mette
			# una preposizione davanti a un nome.
			return "%s se l'è sentito raccontare: ti hanno vista %s" % [nome, inf]
		if su_di_me:
			return "%s si ricorda quello che ha ricevuto dalle tue zampe" % nome
		if altro != "":
			return "%s ti ha vista %s per %s" % [nome, inf, altro]
		return "%s ti ha vista %s" % [nome, inf]

	if compito == "discorso":
		if sentito:
			return "Mi hanno raccontato di averti vista %s" % inf
		if su_di_me:
			return "Mi hai messo una cosa fra le zampe"
		if altro != "":
			return "Ti ho vista %s per %s" % [inf, altro]
		return "Ti ho vista %s" % inf

	# «pensiero»: parla fra sé, e di lei in terza persona
	var lei := str(rit.get("protagonista", ""))
	if lei == "":
		lei = "Qualcuno"
	if sentito:
		return "Mi hanno raccontato di averla vista %s" % inf
	if su_di_me:
		return "%s mi ha messo una cosa fra le zampe" % lei
	if altro != "":
		return "L'ho vista %s per %s" % [inf, altro]
	return "L'ho vista %s" % inf


## A CHI ERA DIRETTO IL GESTO, e solo se si può ancora dire con certezza.
## Torna "" in tutti i casi in cui non si sa: nessun soggetto (è la
## stragrande maggioranza — nel gioco solo il dono ne porta uno), soggetto
## perso nel passaparola, handle che non risolve più perché quel vicino è
## partito.
static func _destinatario(rit: Dictionary, riga: Dictionary, nessuno: int) -> String:
	var s := int(riga.get("soggetto", nessuno))
	if s == nessuno:
		return ""
	var nomi: Dictionary = rit.get("nomi", {})
	return str(nomi.get(s, ""))


## I PEZZI FACOLTATIVI, in ordine fisso. Il modello sceglie quali tenere; non
## può cambiarli, non può riordinarli, non può aggiungerne.
##
## ⚠️ IL «QUANDO» NON ESISTE PER IL SENTITO DIRE, ed è l'unica cosa non ovvia
## del file. Nel grafo di chi ascolta, `quando` è il momento del RACCONTO —
## `inserisci()` timbra sempre l'ora di adesso, apposta (un ricordo
## antidatato non si potrebbe più potare). Dire «gliel'hanno raccontato poco
## fa» sarebbe vero; dire «è successo poco fa» sarebbe falso, e in una frase
## sola le due cose non si distinguono. Il luogo invece attraversa il
## passaparola INTATTO — è scritto in `racconta`, ed è la ragione per cui chi
## non c'era sa dov'è l'aiuola — e anche `quante` («l'ho visto annaffiare
## tutto il pomeriggio» è parte della notizia).
static func _mods(rit: Dictionary, riga: Dictionary, sentito: bool) -> Array:
	var out := []
	var q := int(riga.get("quante", 1))
	if q >= VOLTE_LUNGO:
		out.append("a lungo")
	elif q >= VOLTE_PIU:
		out.append("più di una volta")

	if not sentito:
		var quando := _quando(rit, riga)
		if quando != "":
			out.append(quando)

	var dove := _dove(rit, riga)
	if dove != "":
		out.append(dove)
	return out


## QUANTO TEMPO FA, in ore DEL VILLAGGIO. Il ciclo del giorno arriva dal
## ritratto (`DayNight.cycle_seconds`, la stessa fonte da cui il cuore deriva
## la mezza vita dei ricordi): senza quel numero non si dice niente, perché
## «poco fa» misurato in secondi veri sarebbe una scala che nel villaggio non
## esiste — lì una giornata intera dura quattro minuti.
##
## E non si dice mai «stamattina» né «ieri»: il grafo tiene i secondi
## monotoni del cuore, non la fase del cielo, e i due orologi non sono
## allineati. Ricostruire un'ora del giorno da qui sarebbe la più verosimile
## delle bugie.
static func _quando(rit: Dictionary, riga: Dictionary) -> String:
	var ciclo := float(rit.get("ciclo", 0.0))
	if not (ciclo > 0.0):
		return ""
	var dt := float(rit.get("ora", 0.0)) - float(riga.get("quando", 0.0))
	if dt < 0.0:
		return ""
	var ore := dt / (ciclo / 24.0)
	if ore < 1.0:
		return "poco fa"
	if ore < 4.0:
		return "qualche ora fa"
	if ore < 12.0:
		return "un pezzo fa"
	return "tanto tempo fa"


## DOVE, misurato da casa sua. In mezzo c'è la fascia grigia: silenzio.
static func _dove(rit: Dictionary, riga: Dictionary) -> String:
	if not rit.has("casa"):
		return ""
	var casa = rit["casa"]
	if not (casa is Vector3):
		return ""
	var d := Vector2(casa.x, casa.z).distance_to(
			Vector2(float(riga.get("px", 0.0)), float(riga.get("pz", 0.0))))
	if d <= VICINO_M:
		return "a due passi da casa sua"
	if d >= LONTANO_M:
		return "dall'altra parte del villaggio"
	return ""


## QUANTO PESA, detto in parole. Il numero non entra mai nel prompt: un
## modello piccolo che legge «2.31» o lo ricopia (e le cifre sono vietate
## nella metà libera) o lo ignora. La parola invece la usa per scegliere di
## cosa vale la pena parlare, che è l'unica cosa per cui il peso serve qui.
static func _forza(p: float, misurato: bool) -> String:
	if not misurato:
		return ""
	if p >= SOGLIA_VIVISSIMO:
		return "non se lo toglie dagli occhi"
	if p >= SOGLIA_VIVO:
		return "se lo ricorda bene"
	if p >= SOGLIA_TIEPIDO:
		return "resta addosso appena"
	return "sta già sbiadendo"


## TUTTE LE FRASI CHE IL MODELLO PUÒ AFFERMARE, per esteso e in ordine.
##
## È la lista che genera la grammatica E che collauda il testo: due
## guardiani, una sola fonte. Se un giorno qualcuno la spezza in due, il modo
## in cui se ne accorgerà è un modello che campiona una frase che il collaudo
## poi butta — cioè una lettera che non arriva mai, in silenzio.
##
## Le combinazioni sono i sottoinsiemi dei pezzi facoltativi IN ORDINE (mai
## permutati): con tre pezzi fanno otto frasi per ricordo, e con sei ricordi
## quarantotto in tutto, più quella dell'obiettivo. Una lista finita, corta e
## leggibile a occhio — che è la proprietà per cui si può aprire la
## grammatica e sapere, senza fidarsi di nessuno, tutto quello che il
## villaggio ha il permesso di dire stasera.
static func citazioni(rit: Dictionary) -> Array:
	var out := []
	for f in fatti(rit):
		var base := str(f["base"])
		var mods: Array = f["mods"]
		for maschera in (1 << mods.size()):
			var s := base
			for k in mods.size():
				if (maschera & (1 << k)) != 0:
					s += ", " + str(mods[k])
			out.append(_frase(s))
	for o in fatto_obiettivo(rit):
		out.append(_frase(str(o)))
	return out


## Una frase è una frase: comincia con la maiuscola e finisce col punto.
## La maiuscola si mette QUI e non dentro i modelli di frase, perché la prima
## parola non è sempre la stessa cosa — a volte è un nome («la volpina
## Papavero»), a volte un pronome, a volte una congiunzione. È la stessa
## trasformazione di presentazione di `rifinisci()`, e vale per la metà
## chiusa come per quella libera.
static func _frase(s: String) -> String:
	if s == "":
		return s
	return s.substr(0, 1).to_upper() + s.substr(1) + "."


## Il compito, normalizzato. Uno sconosciuto degrada verso la lettera invece
## di far esplodere una riga più in là: il degrado va sempre verso il
## comportamento di sempre.
static func compito_di(rit: Dictionary) -> String:
	var c := str(rit.get("compito", "lettera"))
	return c if COMPITI.has(c) else "lettera"


# =========================================================================
# IL PROMPT
# =========================================================================

## IL PROMPT IN DUE PARTI, come lo vuole un modello istruito: il ruolo e le
## regole nel messaggio di sistema, il villaggio di stasera in quello
## dell'utente. Torna {} quando non c'è niente di vero da dire — ed è il caso
## normale, non un errore: un vicino che non ha visto niente non ha niente da
## raccontare, e il gioco usa la lettera scritta a mano.
static func parti(rit: Dictionary) -> Dictionary:
	if citazioni(rit).is_empty():
		return {}
	var compito := compito_di(rit)
	return {
		"sistema": _sistema(rit, compito),
		"utente": _utente(rit, compito),
	}


## Il prompt intero, per chi lo vuole in un pezzo solo (la riga di comando, i
## provini, i modelli senza template di chat). "" se non c'è niente da dire.
static func componi(rit: Dictionary) -> String:
	var p := parti(rit)
	if p.is_empty():
		return ""
	return "%s\n\n%s" % [p["sistema"], p["utente"]]


static func _sistema(rit: Dictionary, compito: String) -> String:
	var reg: Dictionary = COMPITI[compito]
	var chi := str(rit.get("protagonista", "Mochi")) if compito == "lettera" \
			else str(rit.get("nome", "un vicino"))
	var r := []
	r.append(str(reg["ruolo"]) % chi)
	r.append("")
	r.append("Scrivi in italiano, con parole semplici, e poche.")
	r.append("Non spieghi, non elenchi, non fai domande, non saluti.")
	r.append("Non sai NIENTE di questo villaggio a parte quello che leggi qui")
	r.append("sotto: quello che non c'è scritto non è successo, e nominarlo")
	r.append("rovina tutto.")
	r.append("")
	r.append("La forma è sempre questa, e non ha varianti:")
	if bool(reg["apertura"]):
		r.append("  · una riga tua, se ti va;")
	r.append("  · UNA delle frasi che ti do, copiata parola per parola (i pezzi")
	r.append("    fra parentesi puoi tenerli o toglierli, mai cambiarli);")
	var quante := "una riga" if int(reg["chiusura_max"]) == 1 else "una riga o due"
	r.append("  · poi %s che sono quello che ti resta addosso." % quante)
	r.append("")
	r.append("Le righe tue: tutte minuscole, senza nomi, senza cifre, senza")
	r.append("virgolette. Parlano di quello che senti tu, mai di cose successe:")
	r.append("quelle le dice la frase che ti ho dato, e nessun'altra è vera.")
	r.append("")
	# LA SAGOMA, e non un esempio scritto. Un esempio con dentro delle parole
	# vere un modello piccolo lo ricopia — e ricopiarlo vorrebbe dire che
	# tutte le lettere del villaggio si somigliano. Qui c'è la forma e basta.
	r.append("Così, e nient'altro:")
	if bool(reg["apertura"]):
		r.append("  <una riga tua>")
	r.append("  <una delle frasi che ti do>")
	for _k in int(reg["chiusura_min"]):
		r.append("  <una riga tua>")
	return "\n".join(r)


static func _utente(rit: Dictionary, compito: String) -> String:
	var r := []
	r.append(_blocco_chi(rit, compito))
	var quando := _blocco_quando(rit)
	if quando != "":
		r.append(quando)
	r.append(_blocco_frasi(rit, compito))
	var cuore := _blocco_cuore(rit)
	if cuore != "":
		r.append(cuore)
	return "\n\n".join(r)


## CHI È. L'indole e la stravaganza si dicono con le parole che il gioco già
## usa per dirle (`VillagerBrain.INDOLI` e `QUIRK_LINES`): un vicino
## «brontolone» qui è «brontola, ma ha un cuore di panna», che è la stessa
## frase che il giocatore legge nella sua scheda. Due descrizioni dello
## stesso carattere sarebbero due caratteri.
static func _blocco_chi(rit: Dictionary, compito: String) -> String:
	var r := []
	r.append("CHI È" if compito == "lettera" else "CHI SEI")
	var testa := "  " + str(rit.get("nome", ""))
	var eta := str(rit.get("eta", ""))
	if eta != "":
		testa += ", " + eta
	r.append(testa)

	var tratti := []
	for id in (rit.get("indole", []) as Array):
		var voce = BRAIN.INDOLI.get(str(id), null)
		if voce != null and (voce as Array).size() > 0:
			tratti.append(str(voce[0]))
	var quirk := str(BRAIN.QUIRK_LINES.get(str(rit.get("quirk", "")), ""))
	if quirk != "":
		tratti.append(quirk)
	if not tratti.is_empty():
		r.append("  " + " · ".join(tratti))

	var azione := str(AZIONI_DETTE.get(str(rit.get("azione", "")), ""))
	if azione != "":
		r.append("  adesso " + azione)
	var gusto := _gusto_in_parole(rit)
	if gusto != "":
		r.append("  " + gusto)
	return "\n".join(r)


## QUANDO. Stagione e momento arrivano già in parola dal livello
## (`DayNight.season_name()` e i sei momenti di `OraDelGiorno`): questo file
## non guarda un orologio e non calcola una stagione — sarebbe la seconda
## implementazione di due cose che il gioco sa già dire.
static func _blocco_quando(rit: Dictionary) -> String:
	var pezzi := []
	var momento := str(rit.get("momento", ""))
	var stagione := str(rit.get("stagione", ""))
	if momento != "":
		pezzi.append(momento)
	if stagione != "":
		# «d'estate, d'inverno» e «di primavera, di autunno»: l'elisione la
		# vuole solo la vocale, e sbagliarla si sente leggendo ad alta voce.
		var vocale := stagione.substr(0, 1) in ["a", "e", "i", "o", "u"]
		pezzi.append(("d'" if vocale else "di ") + stagione)
	if pezzi.is_empty():
		return ""
	return "QUAND'È\n  " + ", ".join(pezzi)


## LE FRASI. Un ricordo per riga, coi pezzi facoltativi fra parentesi e, in
## coda, quanto quel ricordo pesa detto in parole: è lì che il modello capisce
## di cosa vale la pena parlare, ed è l'unico posto del prompt in cui il peso
## serve a qualcosa.
static func _blocco_frasi(rit: Dictionary, compito: String) -> String:
	var r := []
	r.append("LE FRASI CHE PUOI DIRE — una sola, copiata com'è")
	for f in fatti(rit):
		var riga := str(f["base"])
		for m in (f["mods"] as Array):
			riga += "(, %s)" % str(m)
		riga = "  · " + _frase(riga)
		var forza := str(f["forza"])
		if forza != "":
			riga += "   [%s]" % forza
		r.append(riga)
	for o in fatto_obiettivo(rit):
		r.append("  · " + _frase(str(o)))
	if compito == "lettera":
		r.append("  (in quelle frasi «ti» e «tu» sono %s, a cui stai scrivendo.)"
				% str(rit.get("protagonista", "Mochi")))
	return "\n".join(r)


## IL TONO — le tinte, cioè la lettura di adesso del grafo. Non è un umore e
## non è uno stato: è la somma di quello che ha visto, pesata da quanto
## gliene importa. Qui serve a scegliere il TONO, mai un fatto: perciò si dice
## in parole e mai in numeri.
static func _blocco_cuore(rit: Dictionary) -> String:
	var tinte: Dictionary = rit.get("tinte", {})
	if tinte.is_empty():
		return ""
	var amm := float(tinte.get("ammirazione", 0.0))
	var gra := float(tinte.get("gratitudine", 0.0))
	var lei := str(rit.get("protagonista", "Mochi"))
	var nome := str(rit.get("nome", ""))
	var riga := ""
	if amm >= SOGLIA_VIVISSIMO:
		riga = "%s conta molto per %s" % [lei, nome]
	elif amm >= SOGLIA_VIVO:
		riga = "a %s fa piacere che %s sia da queste parti" % [nome, lei]
	elif amm >= SOGLIA_TIEPIDO:
		riga = "%s l'ha notata appena" % nome
	else:
		riga = "per %s, %s è ancora quasi un'estranea" % [nome, lei]
	if gra >= SOGLIA_TIEPIDO:
		riga += ", e le deve qualcosa"
	return "IL TONO\n  " + riga.substr(0, 1).to_upper() + riga.substr(1) + "."


## QUANTO GLI IMPORTA, in parole. Si nominano solo gli estremi: la cosa che
## gli sta più a cuore e quelle che non gli dicono niente (gusto zero, che nel
## villaggio vuol dire esattamente «quella cosa smette di parlargli»). Il
## centro non si dice: un elenco di sei voci tiepide è rumore per un modello
## piccolo, e non cambierebbe una parola di quello che scrive.
static func _gusto_in_parole(rit: Dictionary) -> String:
	var gusto = rit.get("gusto", null)
	var cose: Array = rit.get("cose", [])
	if gusto == null or gusto.size() != cose.size() or cose.is_empty():
		return ""
	var top := 0
	for i in cose.size():
		if float(gusto[i]) > float(gusto[top]):
			top = i
	# I DUE ELENCHI SI DICONO COI DUE PUNTI, e non con una frase che concorda.
	# «non gli dice niente il fuoco» / «non gli dicono niente il fuoco e i
	# pesci»: l'accordo del verbo dipende da quante voci ci sono, e un
	# generatore che lo sbaglia produce righe che si sentono leggendo ad alta
	# voce. Coi due punti l'elenco è un elenco, e resta giusto a qualunque
	# lunghezza.
	var pezzi := []
	if float(gusto[top]) > 1.0:
		pezzi.append("quello che sta più a cuore: %s"
				% str(NOMI_COSE.get(str(cose[top]), "")))
	var niente := []
	for i in cose.size():
		if float(gusto[i]) <= 0.0:
			niente.append(str(NOMI_COSE.get(str(cose[i]), "")))
	if not niente.is_empty():
		pezzi.append("quello che non dice niente: " + ", ".join(niente))
	return "; ".join(pezzi)


# =========================================================================
# LA GRAMMATICA
# =========================================================================

## LA GRAMMATICA GBNF, GENERATA. Mai scritta a mano, e non è una preferenza:
## il punto di tutta questa faccenda è che il modello **non possa nominare
## qualcosa che non esiste**, e una grammatica ricopiata è una lista che il
## giorno dopo racconta un altro villaggio. Qui i terminali che affermano
## qualcosa sono `citazioni()` per esteso — le stesse stringhe che il
## collaudo accetta — e tutto il resto è un alfabeto senza maiuscole e senza
## cifre, cioè incapace di contenere un nome proprio o una quantità.
##
## Gli otto verbi, le sei cose e i quattro obiettivi entrano tutti da lì
## dentro, e nessuno per intero: entrano **quelli che sono veri per questo
## vicino stasera**. Un'enum chiusa dice cosa può esistere; il grafo dice
## cosa esiste. La grammatica è l'intersezione, ed è la sola cosa che il
## modello vede.
##
## Il formato è quello di llama.cpp (`grammars/README.md`): nomi di regola
## minuscoli-con-trattino, letterali fra virgolette, `{m,n}` per le
## ripetizioni. La forma dell'uscita ricalca le lettere del Gufo già scritte,
## compresa la regola 7 del taccuino — **la citazione va su una riga sua** —
## che qui smette di essere una raccomandazione e diventa una proprietà della
## grammatica.
##
## Torna "" quando non c'è niente da affermare: senza citazioni la grammatica
## accetterebbe soltanto prosa libera, cioè l'esatto contrario del suo
## mestiere.
static func grammatica(rit: Dictionary) -> String:
	var cit := citazioni(rit)
	if cit.is_empty():
		return ""
	var reg: Dictionary = COMPITI[compito_di(rit)]

	var r := []
	r.append("# GENERATA DA Suggeritore.grammatica() — non modificare a mano.")
	r.append("# Tutto ciò che questa grammatica permette di AFFERMARE sta qui")
	r.append("# sotto per esteso: %d frasi, tutte da ricordi veri di un vicino"
			% cit.size())
	r.append("# solo — %s." % str(rit.get("nome", "un vicino")))
	r.append("")
	var radice := "root ::= "
	if bool(reg["apertura"]):
		radice += "libera? "
	radice += "citazione \"\\n\" "
	var lo := int(reg["chiusura_min"])
	var hi := int(reg["chiusura_max"])
	if lo == hi:
		radice += "libera{%d}" % lo
	else:
		radice += "libera{%d,%d}" % [lo, hi]
	r.append(radice)
	r.append("")
	r.append("# La metà che AFFERMA: chiusa, finita, generata dal grafo.")
	# ⚠️ LA BARRA VA IN FONDO ALLA RIGA, non in testa alla successiva. In
	# llama.cpp una sequenza di primo livello FINISCE al ritorno a capo
	# (`parse_space(..., is_nested=false)`), e l'alternanza continua solo se
	# il carattere dopo è `|`; una barra a inizio riga farebbe cominciare lì
	# una regola nuova e il file non si aprirebbe affatto. Dopo la barra,
	# invece, il ritorno a capo è ammesso — ed è la forma delle grammatiche
	# che llama.cpp spedisce (`grammars/c.gbnf`).
	var alt := []
	for c in cit:
		alt.append("\t\"%s\"" % _gbnf_letterale(str(c)))
	r.append("citazione ::=\n" + " |\n".join(alt))
	r.append("")
	r.append("# La metà LIBERA: nessuna maiuscola, quindi nessun nome proprio;")
	r.append("# nessuna cifra, quindi nessuna quantità inventata.")
	r.append("libera ::= (parola \" \"){%d,%d} finale \"\\n\"" % [PAROLE_MIN - 1, PAROLE_MAX - 1])
	r.append("parola ::= lettera{1,15} \",\"?")
	r.append("finale ::= lettera{1,15} fine")
	var fini := []
	for f in FINALI:
		fini.append("\"%s\"" % str(f))
	r.append("fine ::= " + " | ".join(fini))
	r.append("lettera ::= [%s]" % LETTERE)
	return "\n".join(r) + "\n"


## Un letterale GBNF. Le virgolette e la barra rovescia si scudano; il resto
## dell'Unicode ci va dentro com'è (lo dice la guida: «Terminals support the
## full range of Unicode»), ed è quello che ci vuole per le accentate.
static func _gbnf_letterale(s: String) -> String:
	return s.replace("\\", "\\\\").replace("\"", "\\\"")


# =========================================================================
# IL COLLAUDO — l'ultima porta prima dello schermo
# =========================================================================

## ACCETTA, O DICE PERCHÉ NO. Torna {"ok": bool, "motivo": String}.
##
## PERCHÉ ESISTE, VISTO CHE C'È GIÀ LA GRAMMATICA. Sono due guardiani con due
## mestieri diversi, e il secondo è quello che tiene in piedi la promessa
## della fase:
##  · la grammatica governa il CAMPIONAMENTO, e vale solo se chi chiama il
##    modello gliela passa. È una condizione su un file di configurazione,
##    cioè la specie di condizione che prima o poi qualcuno dimentica —
##    magari fra sei mesi, in un ramo che prova un modello nuovo;
##  · questo governa COSA ARRIVA ALLO SCHERMO, non ha configurazione, ed è
##    puro: si prova con una stringa scritta a mano, senza modello, senza
##    villaggio, senza GDExtension.
## Quando dice di no, il degrado è la cosa migliore che ci sia: il gioco usa
## la lettera scritta a mano. Il silenzio è il comportamento normale.
static func accetta(testo: String, rit: Dictionary) -> Dictionary:
	var cit := citazioni(rit)
	if cit.is_empty():
		return {"ok": false, "motivo": "non c'è niente di vero da dire"}
	var reg: Dictionary = COMPITI[compito_di(rit)]

	var righe := []
	for r in testo.split("\n"):
		var s := str(r).strip_edges()
		if s != "":
			righe.append(s)
	if righe.is_empty():
		return {"ok": false, "motivo": "testo vuoto"}

	var quante_cit := 0
	var i_cit := -1
	for i in righe.size():
		if cit.has(righe[i]):
			quante_cit += 1
			i_cit = i
	if quante_cit == 0:
		return {"ok": false, "motivo": "non cita niente di vero"}
	if quante_cit > 1:
		return {"ok": false, "motivo": "cita più di una cosa"}

	if i_cit > (1 if bool(reg["apertura"]) else 0):
		return {"ok": false, "motivo": "la citazione non è al suo posto"}
	var chiusure := righe.size() - i_cit - 1
	if chiusure < int(reg["chiusura_min"]) or chiusure > int(reg["chiusura_max"]):
		return {"ok": false, "motivo": "il numero di righe non è quello chiesto"}

	for i in righe.size():
		if i == i_cit:
			continue
		var m := _riga_libera_ok(str(righe[i]))
		if m != "":
			return {"ok": false, "motivo": m}
	return {"ok": true, "motivo": ""}


## Una riga libera è fatta SOLO delle lettere ammesse. Nessuna maiuscola
## (quindi nessun nome), nessuna cifra (quindi nessuna quantità), niente
## virgolette né parentesi né trattini: le uniche punteggiature sono la
## virgola dentro e il punto (o i puntini) in fondo.
static func _riga_libera_ok(riga: String) -> String:
	if riga.length() == 0:
		return "riga vuota"
	var corpo := ""
	if riga.ends_with("..."):
		# i puntini sono un carattere solo (…), ma un modello può batterli
		# come tre punti: si accetta la forma lunga e la si giudica uguale
		corpo = riga.substr(0, riga.length() - 3)
	elif FINALI.has(riga.substr(riga.length() - 1, 1)):
		corpo = riga.substr(0, riga.length() - 1)
	else:
		return "una riga libera finisce con un punto"

	var parole := 0
	var in_parola := false
	for k in corpo.length():
		var c := corpo.substr(k, 1)
		if c == " ":
			in_parola = false
			continue
		if c == ",":
			continue
		if not LETTERE.contains(c):
			return "una riga libera non può contenere «%s»" % c
		if not in_parola:
			in_parola = true
			parole += 1
	if parole < PAROLE_MIN:
		return "una riga libera troppo corta"
	if parole > PAROLE_MAX:
		return "una riga libera troppo lunga"
	return ""


## LA MAIUSCOLA LA METTE IL GIOCO. Il modello scrive in minuscolo perché così
## non può nominare nessuno; la lettera però si legge come una lettera. È una
## trasformazione di presentazione — la stessa idea di `Critters.etichetta()`
## — non un permesso restituito a chi scrive.
static func rifinisci(testo: String) -> String:
	var out := []
	for r in testo.split("\n"):
		var s := str(r).strip_edges()
		if s == "":
			continue
		out.append(s.substr(0, 1).to_upper() + s.substr(1))
	return "\n".join(out)
