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

## QUANTO PESA UN RICORDO CHE NESSUNO HA MISURATO. È l'unità della scala —
## «un ricordo fresco, visto una volta, non fatto a me, a gusto neutro pesa
## esattamente 1.0» (`chibi::peso`) — e serve ai ritratti scritti a mano, che
## non portano i pesi. Sta qui invece che sparso perché `fatti()` e
## `peso_riga()` devono rispondere lo stesso: un ritratto senza pesi non deve
## avere due letture, una che ordina i ricordi e una che li potrebbe potare.
const PESO_OCCHIATA := 1.0

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

## QUANTO PUÒ ESSERE LUNGA UNA PAROLA, nella grammatica e nel collaudo.
## Sta qui, in un posto solo, perché i due la leggono per motivi opposti: la
## grammatica per METTERE il tetto (`parola ::= lettera{1,15}`), il collaudo
## per accorgersi di chi ci ha SBATTUTO CONTRO. Un modello a cui la
## grammatica nega lo spazio non si ferma: incolla. Misurato sulle 392 righe
## libere del provino — le uniche sei parole lunghe quindici lettere sono
## tutte parole incollate («stataannaffiata», «aduepassidacasa»,
## «dall'altraparts»), e la più lunga parola italiana vera del mazzo ne ha
## tredici. Il tetto non è un limite di stile: è una cicatrice riconoscibile.
const LETTERE_MAX := 15


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
		var p := PESO_OCCHIATA
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
	return _citazioni_da(fatti(rit), rit)


## IL BANCO DI PROVA DI UN RITRATTO: le quattro cose che il collaudo ricava dal
## ritratto e che NON cambiano da una bozza all'altra.
##
## Esiste per una ragione misurata. Il giudizio arriva su molte bozze insieme
## (`Giudice.gd`), e `accetta()` ricostruiva ogni volta i fatti, le ventidue
## frasi, i nomi del villaggio e le radici degli otto verbi: **quattro volte
## per bozza** (una per `citazioni`, una per ogni riga libera dentro
## `_ponteggio`). Col banco, una scelta passa da 1.71 a 1.51 ms su cinque
## bozze e da 4.17 a 3.22 ms su quindici (`tools/prova_giudice.gd`, il giro
## migliore su duecento). Il risparmio CRESCE col numero di bozze, perché la
## roba rifatta era per bozza — ed è il verso giusto, visto che di bozze ne
## devono arrivare molte.
##
## ⚠️ E una nota di MISURA, perché su questa macchina ci lavorano più agenti
## insieme: le prime cifre che avevo scritto qui (6.3 ms per bozza, 33 ms per
## scelta) erano MEDIE prese con carico 30–60, cioè il ritratto della
## macchina, non del codice. Le stesse chiamate, a macchina quieta, stavano
## sotto i 2 ms. Si misura col giro migliore, e si confronta A-B-A.
##
## Non è una cache e non scade: è il ritratto stesso, letto una volta. Chi lo
## passa deve averlo costruito dallo STESSO ritratto con cui giudica — un
## banco di un altro vicino collauderebbe una lettera contro il villaggio
## sbagliato, e sarebbe verde.
static func banco(rit: Dictionary) -> Dictionary:
	var f := fatti(rit)
	return {
		"fatti": f,
		"citazioni": _citazioni_da(f, rit),
		"nomi": _nomi_del_villaggio(rit),
		"radici": _radici_dei_verbi(),
		"ponteggio": _frasi_del_foglio(rit, f),
	}


static func _citazioni_da(elenco: Array, rit: Dictionary) -> Array:
	var out := []
	for f in elenco:
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
		pezzi.append("%s: %s" % [GUSTO_PIU, str(NOMI_COSE.get(str(cose[top]), ""))])
	var niente := []
	for i in cose.size():
		if float(gusto[i]) <= 0.0:
			niente.append(str(NOMI_COSE.get(str(cose[i]), "")))
	if not niente.is_empty():
		pezzi.append(GUSTO_NIENTE + ": " + ", ".join(niente))
	return "; ".join(pezzi)


## LE DUE APERTURE DELL'ELENCO DEL GUSTO, in un posto solo perché le legge
## anche il collaudo: il dossier che il foglio scrive è la prima cosa che un
## modello piccolo ricopia, e per riconoscerlo bisogna saperlo com'è scritto.
## Vedi `_frasi_del_foglio`.
const GUSTO_PIU := "quello che sta più a cuore"
const GUSTO_NIENTE := "quello che non dice niente"


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
	r.append("parola ::= lettera{1,%d} \",\"?" % LETTERE_MAX)
	r.append("finale ::= lettera{1,%d} fine" % LETTERE_MAX)
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
# L'ALTRA GRAMMATICA: le DEDUZIONI, cioè i JSON
# =========================================================================

## QUANTI RICORDI PUÒ CITARE UNA DEDUZIONE. È `chibi::MAX_PERCHE`, e sta
## qui ricopiato per la stessa ragione di `SOGLIA_TIEPIDO`: questo file è
## puro e non apre la GDExtension. `test_deduzioni.gd` lo legge dal binario
## (`debug_deduzioni_costanti`) e pretende che combacino — se un domani il
## C++ ne accetta quattro, la suite lo dice qui invece di far generare al
## modello una catena che il ponte poi rifiuta in silenzio.
const PERCHE_MAX := 3

## LA GRAMMATICA DELLE DEDUZIONI, GENERATA — e generata dalle stesse due
## enum chiuse da cui viene tutto il resto.
##
## ⚠️ **UNA GRAMMATICA CHE PERMETTE UN OBIETTIVO INESISTENTE È PEGGIO DI
## NIENTE.** La grammatica delle lettere impedisce al modello di *dire* una
## cosa falsa; questa gli impedisce di *far fare* una cosa impossibile — ed è
## un guasto peggiore, perché non si legge: si vede un vicino che si
## incammina e non arriva da nessuna parte. Perciò qui dentro non c'è un solo
## letterale scritto a mano:
##
##  · gli **obiettivi** sono le chiavi di `OBIETTIVI_DETTI`, che è la stessa
##    tabella da cui esce la frase del prompt e che `test_suggeritore.gd`
##    lega a `Piani.OBIETTIVO` **e** a `EcsMondo.maschera_obiettivo()`: un
##    quinto obiettivo inventato qui non ha una maschera, e il test lo dice;
##  · le **righe** sono i `riga` di `righe_vive(rit)`, cioè gli indici veri
##    delle righe del grafo di QUESTO vicino stasera **che pesano abbastanza
##    da reggere una deduzione** (vedi `regge_una_deduzione`). Un indice che
##    non esiste non è campionabile, e nemmeno uno che il ponte butterebbe.
##
## E le combinazioni si scrivono PER ESTESO, come `citazioni()`: i
## sottoinsiemi crescenti di uno, due o tre indici. Con sei ricordi sono
## quarantuno alternative — una lista finita che si legge a occhio. Costa
## qualche riga di file e in cambio rende **strutturalmente impossibili** le
## due forme sbagliate che una regola ricorsiva (`riga ("," riga){0,2}`)
## lascerebbe passare: il doppione (che gonfia una catena senza aggiungerci
## niente) e la permutazione (che è la stessa deduzione scritta in un altro
## ordine, cioè due bozze che il Giudice conterebbe come diverse).
##
## `rit["fattibili"]` — se c'è — sono i nomi degli obiettivi per cui il mondo
## ha una strada ADESSO. Non è obbligatorio (un ritratto scritto a mano non
## ce l'ha, e il degrado è «tutti e quattro, poi ci pensa `Giudice.utile`»),
## ma quando c'è toglie dal mazzo le generazioni sprecate.
##
## E l'obiettivo che il vicino **sta già perseguendo** esce sempre: proporre
## quello che sta già facendo non è una deduzione, non produce nessuna
## ricevuta, e `Giudice.utile()` lo boccerebbe comunque — campionarlo
## vorrebbe dire pagare una bozza per buttarla.
##
## Torna "" quando non c'è niente da dedurre: nessun ricordo vivo, oppure
## nessun obiettivo rimasto. È il caso normale, non un errore.
static func grammatica_deduzione(rit: Dictionary) -> String:
	var righe := righe_vive(rit)
	var obiettivi := obiettivi_deducibili(rit)
	if righe.is_empty() or obiettivi.is_empty():
		return ""

	var alt_ob := []
	for o in obiettivi:
		alt_ob.append("\t\"\\\"%s\\\"\"" % _gbnf_letterale(str(o)))

	var alt_righe := []
	for combo in _sottoinsiemi(righe, PERCHE_MAX):
		var pezzi := []
		for i in combo:
			pezzi.append(str(int(i)))
		alt_righe.append("\t\"%s\"" % ",".join(pezzi))

	var r := []
	r.append("# GENERATA DA Suggeritore.grammatica_deduzione() — non modificare a mano.")
	r.append("# %d obiettivi × %d combinazioni di ricordi: tutto ciò che questa"
			% [obiettivi.size(), alt_righe.size()])
	r.append("# grammatica permette di CHIEDERE sta qui sotto per esteso.")
	r.append("")
	# NIENTE SPAZI, e nessuna regola `ws`. Una grammatica che ammette la
	# spaziatura ammette anche mille modi di scrivere la stessa cosa: sono
	# gettoni spesi per niente, e due bozze identiche che il Giudice conta
	# come due. La forma è UNA.
	r.append("root ::= \"{\\\"obiettivo\\\":\" obiettivo \",\\\"perche\\\":[\" righe \"]}\"")
	r.append("")
	r.append("# I QUATTRO PROVVEDIMENTI del pianificatore, meno quelli che il")
	r.append("# mondo non sa servire adesso. Non ce n'è un quinto possibile.")
	r.append("obiettivo ::=\n" + " |\n".join(alt_ob))
	r.append("")
	r.append("# I RICORDI VIVI di questo vicino, in ogni combinazione crescente")
	r.append("# fino a %d. Nessun doppione, nessuna permutazione." % PERCHE_MAX)
	r.append("righe ::=\n" + " |\n".join(alt_righe))
	return "\n".join(r) + "\n"


## ═══════════════════════════════════════════════════════════════════════
## LA SOGLIA DELLA DEDUZIONE — una sola, e si chiede QUI
## ═══════════════════════════════════════════════════════════════════════
##
## ⚠️ IL GUASTO CHE QUESTE TRE FUNZIONI CHIUDONO, e come si è visto.
##
## Un ricordo abbastanza vivo per una LETTERA non è abbastanza vivo per una
## DEDUZIONE, e per anni le due domande erano la stessa: `fatti()` pota a
## `p > 0` (giusto: una lettera che dice «sta già sbiadendo» è vera, ed è una
## delle quattro etichette che `_forza` sa scrivere), la grammatica offriva
## quelle righe, `Giudice.utile()` le accettava — e poi
## `chibi::inserisci_deduzione` rifiutava la deduzione, perché di là la
## soglia c'è (`!(forza > p_soglia)`, `src/grafo_deduzioni.cpp`).
##
## Misurato su un banco deterministico (un ricordo che invecchia, nessun
## modello): a 240 s di età un ricordo pesa 0.250 — passa i primi tre
## cancelli e viene rifiutato dal quarto. Su una partita lunga vera, 34
## deduzioni scelte su 118 non entravano. Costo per il giocatore: zero,
## perché il silenzio è l'esito buono. Costo per il gioco: una generazione
## intera pagata per essere buttata, **e la bocciatura è muta** — chi chiama
## vede solo «il ponte l'ha rifiutata».
##
## LA CURA È UNA SOLA DOMANDA, non due soglie che si somigliano:
## `regge_una_deduzione()`. La chiedono tutti e tre quelli che devono
## saperlo, e nessuno di loro riscrive il confronto:
##  · `grammatica_deduzione()` — così il modello non può nemmeno campionare
##    la riga che verrà buttata;
##  · `_blocco_ricordi_numerati()` — così il foglio non mostra un numero che
##    la grammatica non ammette (un ricordo elencato e non scrivibile è una
##    trappola per un modello piccolo);
##  · `Giudice.utile()` — che è il posto che sa dire anche PERCHÉ no.
##
## E il confronto è `>` stretto, come di là: `!(forza > p_soglia)` prende
## anche il NaN, e le due parti devono rispondere lo stesso sul filo.
##
## ⚠️ IL RESIDUO, dichiarato e MISURATO: il ritratto è una fotografia, il
## ponte legge il grafo VERO. Fra i due c'è la generazione — secondi, a volte
## decine — e in quel tempo un ricordo decade (`2^(-dt/mezza_vita)`). Un
## ricordo che al momento del foglio pesava appena sopra la soglia può essere
## sceso sotto quando la bozza torna: la fascia a rischio è
## `[soglia, soglia / 2^(-durata/mezza_vita)]`, cioè larga il 12% della
## soglia per una generazione di 20 s con la mezza vita del villaggio
## (120 s). **L'ultima parola resta del ponte**, ed è giusto così: allargare
## di qua per «coprire» il decadimento vorrebbe dire inventare una seconda
## soglia con un margine tarato a occhio — esattamente la cosa che questa
## sezione toglie.

## REGGE UNA DEDUZIONE? La domanda si fa qui e in nessun altro posto.
static func regge_una_deduzione(rit: Dictionary, riga: int) -> bool:
	return peso_riga(rit, riga) > SOGLIA_TIEPIDO


## IL PESO DI UNA RIGA nel ritratto. `PESO_OCCHIATA` quando il ritratto non
## porta i pesi (un dizionario scritto a mano, un clone senza GDExtension):
## il degrado va verso «si può dire», che è il comportamento che c'era prima
## che questa valvola esistesse. Zero per una riga che non c'è.
static func peso_riga(rit: Dictionary, riga: int) -> float:
	var pesi = rit.get("pesi", null)
	if pesi == null:
		return PESO_OCCHIATA
	if riga < 0 or riga >= pesi.size():
		return 0.0
	return float(pesi[riga])


## L'ANELLO PIÙ DEBOLE di una catena di ricordi — cioè quanto pesa la
## deduzione che ci si appoggia. È `chibi::peso_deduzione` detto di qua, e i
## due si devono a un numero identico: `Giudice.scegli_deduzione` ordina con
## questo, il ponte pota con quello. Zero per una catena vuota (che non può
## esistere, ma la riga che lo dice costa un confronto e toglie un modo di
## sbagliare — è la stessa riga che c'è di là).
static func peso_catena(rit: Dictionary, righe) -> float:
	var minimo := INF
	for r in righe:
		minimo = min(minimo, peso_riga(rit, int(r)))
	return 0.0 if minimo == INF else minimo


## I FATTI CHE POSSONO REGGERE UNA DEDUZIONE, nell'ordine in cui il prompt
## li mostra. Sono un SOTTOINSIEME di `fatti()`, mai un secondo elenco.
static func fatti_deducibili(rit: Dictionary) -> Array:
	var out := []
	for f in fatti(rit):
		if regge_una_deduzione(rit, int((f as Dictionary)["riga"])):
			out.append(f)
	return out


## GLI INDICI DELLE RIGHE che possono reggere una deduzione. È la stessa
## lista che `Giudice.utile()` usa per bocciare una deduzione appoggiata a un
## ricordo che non c'è **o troppo debole per reggerla**.
static func righe_vive(rit: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	for f in fatti_deducibili(rit):
		out.append(int((f as Dictionary)["riga"]))
	return out


## GLI OBIETTIVI CHE QUESTO VICINO PUÒ DEDURRE, adesso. Vedi
## `grammatica_deduzione` per le due sottrazioni e il perché di ognuna.
static func obiettivi_deducibili(rit: Dictionary) -> Array:
	var suo := str(rit.get("obiettivo", ""))
	var fattibili: Array = rit.get("fattibili", [])
	var out := []
	for k in OBIETTIVI_DETTI:
		var nome := str(k)
		if nome == suo:
			continue
		if not fattibili.is_empty() and not fattibili.has(nome):
			continue
		out.append(nome)
	return out


## I SOTTOINSIEMI CRESCENTI, da uno a `quanti` elementi, nell'ordine
## dell'elenco. Puro e piccolo apposta: è la funzione che rende la grammatica
## una LISTA invece che una regola ricorsiva.
static func _sottoinsiemi(elenco: PackedInt32Array, quanti: int) -> Array:
	var out := []
	var n := elenco.size()
	for i in n:
		out.append([elenco[i]])
		if quanti < 2:
			continue
		for j in range(i + 1, n):
			out.append([elenco[i], elenco[j]])
			if quanti < 3:
				continue
			for k in range(j + 1, n):
				out.append([elenco[i], elenco[j], elenco[k]])
	return out


## IL PROMPT DELLA DEDUZIONE, in due parti come `parti()`. `{}` quando non
## c'è niente da dedurre.
##
## ⚠️ **QUI NON SI CHIEDE UNA FRASE, E NON SE NE ACCETTA UNA.** Il messaggio
## di sistema non dice «spiega perché»: il `perche` è una lista di NUMERI, e
## la grammatica non ha un posto in cui infilare del testo. È la stessa
## regola di `Giudice.CAMPI_DEDUZIONE` («una deduzione non ha campi liberi»)
## vista dall'altra parte — là si butta quello che arriva, qui non si può
## nemmeno campionare. Le due guardie servono tutte e due, per la stessa
## ragione per cui esistono sia la grammatica sia `accetta()`: una governa il
## campionamento e vale solo se chi chiama il modello la passa; l'altra
## governa cosa entra nel mondo, e non ha configurazione.
static func parti_deduzione(rit: Dictionary) -> Dictionary:
	if grammatica_deduzione(rit) == "":
		return {}
	var nome := str(rit.get("nome", "un vicino"))
	var s := []
	s.append("Sei %s, che vive in un villaggio." % nome)
	s.append("")
	s.append("Qui sotto c'è quello che hai visto fare a chi ci abita, numerato.")
	s.append("Guardalo e decidi UNA cosa che ti va di fare adesso, fra quelle")
	s.append("elencate, e quali di quei ricordi te l'hanno fatta venire in mente.")
	s.append("")
	s.append("Rispondi SOLO con la riga richiesta. Niente parole tue, niente")
	s.append("spiegazioni: i numeri dicono già tutto.")

	var u := []
	u.append(_blocco_chi(rit, "pensiero"))
	var quando := _blocco_quando(rit)
	if quando != "":
		u.append(quando)
	u.append(_blocco_ricordi_numerati(rit))
	u.append(_blocco_scelte(rit))
	var cuore := _blocco_cuore(rit)
	if cuore != "":
		u.append(cuore)
	return {"sistema": "\n".join(s), "utente": "\n\n".join(u)}


## I RICORDI COL LORO NUMERO — e il numero è quello VERO della riga nel
## grafo, lo stesso che la grammatica ammette e che il ponte poi rilegge. Un
## elenco rinumerato da uno (o riordinato per bellezza) sarebbe una seconda
## numerazione: il modello citerebbe il ricordo giusto e il mondo ne
## incasserebbe un altro, in silenzio.
##
## ⚠️ **I PEZZI FACOLTATIVI QUI NON SONO FACOLTATIVI**, e la differenza si è
## vista solo guardando il foglio vero (`tools/prova_deduzione.gd`): due
## annaffiate in due posti diversi uscivano come **due righe identiche**,
## «L'ho vista annaffiare le aiuole» due volte, con due numeri davanti. In una
## lettera non è un guaio (il modello ne copia una e basta); qui il modello
## deve dire QUALI ricordi lo hanno fatto pensare, e su due righe uguali la
## scelta è un dado — dado che poi decide **dove il vicino gira la testa**,
## perché l'ancora della ricevuta è il posto di quel ricordo.
## Perciò i `mods` si stendono per esteso, senza parentesi: sono gli stessi
## atomi chiusi della lettera (quando, dove, quante volte), ed è esattamente
## quello che distingue una riga dall'altra.
## ⚠️ E L'ELENCO È QUELLO DEDUCIBILE, non tutti i fatti: un ricordo mostrato
## col suo numero ma non ammesso dalla grammatica è una trappola per un
## modello piccolo — lo legge, lo sceglie, e il campionatore glielo nega a
## metà riga. Vedi `regge_una_deduzione`.
static func _blocco_ricordi_numerati(rit: Dictionary) -> String:
	var r := ["QUELLO CHE HAI VISTO"]
	for f in fatti_deducibili(rit):
		var voce: Dictionary = f
		var testo := str(voce["base"])
		for m in (voce["mods"] as Array):
			testo += ", " + str(m)
		var riga := "  %d) %s" % [int(voce["riga"]), _frase(testo)]
		var forza := str(voce["forza"])
		if forza != "":
			riga += "   [%s]" % forza
		r.append(riga)
	return "\n".join(r)


## LE COSE CHE PUOI VOLERE. Sono gli stessi quattro provvedimenti detti in
## italiano di `OBIETTIVI_DETTI`, in prima persona come nel pensiero — e col
## nome interno accanto, perché è quello che va scritto nella risposta.
static func _blocco_scelte(rit: Dictionary) -> String:
	var r := ["QUELLO CHE PUOI VOLERE FARE"]
	for o in obiettivi_deducibili(rit):
		r.append("  %s = %s" % [str(o), str(OBIETTIVI_DETTI[o]).replace("sta ", "sto ")])
	return "\n".join(r)


# =========================================================================
# L'ANCORAGGIO — quello che una riga libera non ha il diritto di dire
# =========================================================================

## ⚠️ IL BUCO CHE QUESTA SEZIONE CHIUDE, e come si è visto.
##
## Fino al 2026-08-11 il collaudo guardava le righe libere **carattere per
## carattere**: niente maiuscole, niente cifre, quattro parole almeno,
## quindici al più. Contro i nomi propri funzionava (una maiuscola si vede) e
## contro le quantità inventate pure. Contro i FATTI no: «ti hanno sentito
## parlare a lungo con la volpina perua, e l'ho vista allontanarsi» è tutta
## minuscola, non ha cifre e sta in quattordici parole — passava con la luce
## verde. Otto lettere inventate su otto passavano.
##
## E non è un caso raro. Sulle 392 righe libere italiane del provino (quattro
## modelli), **novantotto — una su quattro** — dicono qualcosa che nel grafo
## non c'è: «la volpina papavero si sente sola nella sua casa di foglie
## secche», «le case sono state regolate con cura», «ho visto come hai
## fissato quel pezzo di legno». Ottantadue delle novantotto nominano
## qualcuno. Ognuna è la modalità di guasto che inverte l'effetto — con la
## differenza, rispetto alle lettere scritte a mano, che qui a inventare è
## una macchina, e non si stanca.
##
## In lettere INTERE: delle 152 generazioni italiane, il collaudo di prima ne
## promuoveva 98, e 33 di quelle (**il 34%**) arrivavano allo schermo rotte —
## 27 affermavano un fatto mai successo, 6 avevano una parola incollata. Si
## rimisura con `tools/prova_giudice.gd`, che stampa la tabella per porta.
##
## LA REGOLA, in una riga: **la riga libera non può fare il mestiere della
## citazione.** La citazione dice cos'è successo, e viene da una lista chiusa
## generata dal grafo; la riga libera dice quello che sente chi parla, che è
## vero perché è suo. Tutte le regole qui sotto sono la stessa regola detta
## in cinque modi, e ognuna ha una FONTE CHIUSA — mai una lista di parole
## proibite scritta a occhio:
##
##  1. **nessun nome** — i nomi arrivano dal ritratto (`nomi`, `nome`,
##     `protagonista`), cioè da chi il villaggio ha davvero;
##  2. **nessun passato della seconda persona** — «hai fissato», «sei
##     andata»: il passato di Mochi è la citazione, e non ce n'è un altro;
##  3. **nessun telaio di percezione seguito da un'azione** — «l'ho vista
##     costruire» è una seconda citazione, scritta da chi non ne ha il
##     diritto;
##  3b. **e nemmeno con un OGGETTO NOMINALE** — «ho visto i tuoi passi»: è il
##     buco che la 3 lasciava aperto, misurato e chiuso il 2026-08-12 (vedi
##     più sotto);
##  4. **nessun verbo del mondo coniugato** — gli otto verbi arrivano da
##     `INFINITO`, che è la coniugazione della tabella del binario;
##  5. **nessuna cosa del villaggio messa al passato** — le sei cose
##     arrivano da `rit["cose"]`, cioè da `EcsMondo.nome_cosa()`.
##
## E l'ASIMMETRIA che giustifica ogni scelta di taratura qui dentro: da oggi
## le bozze sono tante (è il mestiere di `Giudice.gd`). **Una bozza bocciata
## per sbaglio costa una bozza; una bozza falsa che passa costa la fiducia
## del giocatore, e per sempre.** Dove una regola è incerta, si stringe.
##
## ────────────────────────────────────────────────────────────────────────
## IL BUCO DELLA REGOLA 3, misurato il 2026-08-12
## ────────────────────────────────────────────────────────────────────────
##
## La regola 3 pretende PERCEZIONE **+ un infinito o un participio**. Con un
## oggetto NOMINALE non scattava, e la regola 2 non copriva il buco perché
## guarda gli ausiliari della seconda persona («hai», «sei») mentre queste
## frasi sono in PRIMA persona. Banco puro, senza modello:
##
##     «ho visto i tuoi passi e ho visto le tue zampe.»      PASSAVA
##     «ho visto la tua casa e ho visto il tuo focolare.»    PASSAVA
##     «ti ho vista annaffiare le aiuole.»                   bocciata
##
## La prima è una lettera vera, uscita in partita. La cura è la regola 3b: un
## telaio di percezione insieme a un modo di dire «tuo» (`TUO`, che è una
## lista di grammatica italiana, non di parole vietate) non è mai una riga di
## chi parla.
##
## ────────────────────────────────────────────────────────────────────────
## E LE ALTRE DUE PORTE, che non sono l'ancoraggio ma stanno con lui
## ────────────────────────────────────────────────────────────────────────
##
## Rileggendo **180 bozze registrate in partita** (non un provino: la catena
## vera, un modello piccolo), delle 77 che il collaudo promuoveva solo una
## ventina erano davvero righe di chi parla. Le altre erano due cose che
## l'ancoraggio non può vedere, perché non affermano niente:
##  · **le virgolette** — 44 bozze su 180, vedi `_riga_libera_ok`;
##  · **il foglio riletto ad alta voce** — 19÷29 bozze, vedi
##    `_frasi_del_foglio`.
## Dopo: **da 77 promosse su 180 a 21÷31**. L'intervallo è onesto — il
## dossier vero di quel mazzo non era stato registrato, quindi il conto
## stretto usa solo le frasi certe (mestiere, obiettivo, gusto, ponteggio) e
## quello largo tutte le indoli invece della sola scritta su quel foglio.
##
## ────────────────────────────────────────────────────────────────────────
## IL RESIDUO, dichiarato e misurato
## ────────────────────────────────────────────────────────────────────────
##
##  · **un nome INVENTATO in minuscolo** («la volpina perua») resta
##    indistinguibile da un nome comune. Quello che non può più passare è un
##    FATTO;
##  · **le non-parole** («irds», «uisce», «izzazione»): `_non_e_una_parola`
##    prende solo quelle senza vocali, che è una regola di lingua vera ma
##    stretta. Le altre sono pezzi di gettone rimasti attaccati, e per
##    riconoscerli servirebbe un dizionario italiano dentro il gioco. Vedi
##    più sotto («LE CICATRICI DEL GETTONE») le tre strade provate e
##    misurate per chiuderlo, e perché si buttano tutte e tre;
##  · **le affermazioni sul MONDO** — questa era la voce più grossa, ed è
##    quella che il paragrafo qui sotto chiude a metà. La metà chiusa è il
##    CIELO; la metà aperta (il sole, la notte come parola, la stagione) è
##    dichiarata lì con la misura che dice perché.

## I PARTICIPI DELLA PERCEZIONE. Sono i verbi con cui in italiano si dice di
## aver visto o saputo una cosa — cioè l'attacco di tutte le frasi chiuse che
## `_base()` sa scrivere. Ritrovarli in una riga libera, seguiti da
## un'azione, vuol dire che lì si sta scrivendo una citazione a mano.
const PERCEZIONE := ["vista", "visto", "viste", "visti",
	"sentita", "sentito", "sentite", "sentiti",
	"guardata", "guardato", "guardate", "guardati",
	"osservata", "osservato", "osservate", "osservati",
	"notata", "notato", "notate", "notati",
	"raccontata", "raccontato", "raccontate", "raccontati"]

## Gli ausiliari della SECONDA persona: dietro di loro c'è sempre e solo
## Mochi, perché è l'unica persona a cui questo gioco dà del tu.
const TU_AUSILIARI := ["hai", "sei", "avevi", "eri"]

## E I MODI IN CUI L'ITALIANO DICE «TUO». Stessa ragione: in questo gioco il
## «tu» è una persona sola. Serve alla regola 3b — un telaio di percezione più
## uno di questi è una citazione riscritta a mano, anche quando quel che
## afferma sta in un nome invece che in un verbo («ho visto i tuoi passi»).
## L'apostrofo separa le parole (vedi `parole()`), quindi «t'ho» dà «t» e
## «ho»: la «t» sta in lista per quello, e da sola non è una parola italiana.
const TUO := ["tuo", "tua", "tuoi", "tue", "ti", "te", "t"]

## Gli ausiliari della TERZA. «essere stato» da solo non è un fatto, è la
## copula («non c'è mai stato un vuoto»): il participio che conta è quello
## che dice cosa è ACCADUTO («le case sono state regolate»).
const TERZA_AUSILIARI := ["ha", "hanno", "è", "era", "erano", "fu", "furono",
	"aveva", "avevano", "sono"]
const STATO := ["stato", "stata", "stati", "state"]

## LE DESINENZE. Solo i participi REGOLARI, e non per pigrizia: gli
## irregolari (sceso, spento, preso, visto) finiscono come gli aggettivi
## («tristi», «silenzioso»), e con quelli dentro la regola bocciava «le case
## sono ancora tristi» e «il sole è sceso lento» — cioè proprio la voce del
## Gufo, che guarda il cielo e non afferma niente su nessuno.
const PARTICIPIO := ["ato", "ata", "ati", "ate", "ito", "ita", "iti", "ite",
	"uto", "uta", "uti", "ute"]
const INFINITIVO := ["are", "ere", "ire"]
## Participio + imperfetto + gerundio: le forme in cui un verbo del mondo
## smette di essere un'idea («tagliare sarebbe più corto», che il Gufo scrive
## a mano da sempre) e diventa un fatto capitato a qualcuno.
const CONIUGATO := ["ato", "ata", "ati", "ate", "ito", "ita", "iti", "ite",
	"uto", "uta", "uti", "ute", "ava", "avano", "ando", "endo"]

## Le parole che in un'etichetta non sono un nome. «la volpina Papavero» dà
## «volpina» e «papavero»; l'articolo no, o il Gufo non potrebbe più dire
## «la».
const ARTICOLI := ["la", "il", "lo", "le", "i", "gli", "un", "una", "uno",
	"l", "di", "del", "della", "dei", "delle", "da"]


## ═══════════════════════════════════════════════════════════════════════
## IL CIELO — l'unica cosa del mondo che una riga libera può smentire
## ═══════════════════════════════════════════════════════════════════════
##
## L'ancoraggio ferma «chi ha fatto cosa a chi» perché ha il grafo contro cui
## confrontare. Il CIELO non ce l'aveva, e si è visto: sul mazzo vero del 4B
## — trenta lettere mandate, quelle che il giocatore avrebbe letto — **otto
## righe affermavano un tempo che non era quello**:
##
##     «la pioggia mi avvolge» col sereno            (cinque righe, cinque lettere)
##     «la neve, un peso» d'autunno, col sereno      (due righe)
##     «le foglie bruciano al sole» alle 22:50       (una riga)
##
## E il conto vero è peggiore di così: su TUTTE le bozze di quel mazzo il
## cielo è nominato **27 volte, e 27 volte è sbagliato**. Zero su 27. Non è
## un modello che ogni tanto sbaglia il tempo: è un modello che il tempo non
## ce l'ha, e quando gli serve una riga d'atmosfera se lo inventa — il che
## vuol dire che la probabilità di azzeccarlo è quella di un dado.
##
## ────────────────────────────────────────────────────────────────────────
## LA FONTE È UNA, ED È QUELLA CHE IL FOGLIO GIÀ USA
## ────────────────────────────────────────────────────────────────────────
##
## Non c'è nessuna nuova verità sul meteo dentro questo file, e non deve
## essercene: si guardano le tre chiavi del ritratto che il livello ha già
## riempito per scrivere il prompt —
##
##     `rit["meteo"]`     ← `CozyWorld.contesto_critter()`, cioè la riga con
##                          cui il bestiario decide se stasera vola la
##                          farfalla di neve. Uno dei quattro `Critters.METEO`;
##     `rit["momento"]`   ← `OraDelGiorno.momento()`, i sei momenti che il
##                          blocco `QUAND'È` scrive nero su bianco;
##     `rit["stagione"]`  ← `DayNight.season_name()`, idem.
##
## Nessuna delle tre si ricalcola qui: questo file non ha mai guardato un
## orologio e continua a non guardarlo. Quello che c'è qui dentro sono le
## PAROLE con cui una riga afferma uno di quegli stati — e le chiavi di
## quella tabella sono i nomi degli stati veri, così che un test possa
## legarle a `Critters.METEO` e a `OraDelGiorno.MOMENTI`. Se un domani
## nasce un quinto stato del cielo, quel test diventa rosso invece di
## lasciare una parola che non giudica più niente.
##
## ────────────────────────────────────────────────────────────────────────
## E LA METAFORA? È LA METÀ PER CUI IL MODELLO È QUI
## ────────────────────────────────────────────────────────────────────────
##
## Una regola larga qui non fa danno all'ancoraggio: fa danno alla POESIA,
## che è l'unica cosa che un modello aggiunge a questo gioco. Perciò ogni
## parola di questa tabella è stata contata sul mazzo vero — **1395 righe
## libere italiane**, quattro modelli, il provino e la partita:
##
##     «pioggia» (17 righe) · «neve» (10) · «nebbia» (5)   → 32 in tutto,
##       e le radici non prendono nient'altro: zero collisioni su 1395 righe.
##     il telaio «al sole» (1 riga)                        → e le altre
##       **59** righe che contengono «sole» NON vengono toccate.
##
## Le due valvole che salvano la figura retorica, tutte e due misurate:
##  · **il PARAGONE non afferma** («il silenzio cade come pioggia»). Zero
##    occorrenze nel mazzo: non costa e non salva niente di misurato — sta
##    qui perché un paragone, per definizione, non dice che sta piovendo;
##  · **l'IMPRESSIONE non è il cielo** («la legna sa di pioggia», «un senso
##    di pioggia», «il legno profuma di pioggia»). Questa costa: sono **3
##    righe delle 27**, cioè l'11% della famiglia, e sono tre righe belle.
##    Il telaio è chiuso e adiacente — un verbo o un nome di percezione, poi
##    «di», poi la parola del cielo — quindi non fa passare «piccole gocce
##    di pioggia» né «una sera di pioggia», che invece affermano eccome.
##
## ────────────────────────────────────────────────────────────────────────
## COSA RESTA APERTO, e perché è una DECISIONE e non una dimenticanza
## ────────────────────────────────────────────────────────────────────────
##
## Il vecchio residuo diceva: «chi la vorrà chiudere deve portarsi dietro il
## TEMPO VERBALE, non l'elenco delle stagioni». Aveva ragione, e la misura
## lo conferma parola per parola:
##
##  · **il SOLE non si giudica**, tranne addosso e di notte. «sole» compare
##    in **60 righe su 1395**, ed è la parola preferita del Gufo: «il sole
##    cala lento sul mio ramo», «il sole è un peso», «un vago ricordo del
##    sole», «come un sole che non brucia mai», «qui siede l'ombra del
##    sole». Di quelle 60 **una sola** è una bugia sul mondo. Una regola su
##    «sole» abbastanza larga da prenderla ne ucciderebbe cinquantanove: è
##    il filtro che uccide la poesia, misurato. Resta il telaio LOCATIVO —
##    «al sole», «nel sole», «sotto il sole», «dal sole» — che chiede che il
##    sole ci SIA addosso, e solo quando il momento vero è la notte: un
##    caso, zero falsi positivi su 1395 righe;
##  · **la NOTTE come parola non si giudica affatto.** Il mazzo ha «la notte
##    è lunga e io resto qui ad aspettare» e «la notte è lunga ma ora dormo
##    su quel ramo secco»: è ESATTAMENTE la frase che il vecchio residuo
##    aveva previsto, e non è una bugia nemmeno a mezzogiorno — è un
##    pensiero di chi scrive. Undici righe su 1395 parlano di notte o di
##    buio, e nessuna afferma che sia notte adesso;
##  · **la STAGIONE non si giudica.** Zero occorrenze sbagliate misurate, e
##    «d'estate» in una riga libera è quasi sempre l'eco del blocco
##    `QUAND'È` — un altro guasto, con un'altra cura (`_frasi_del_foglio`),
##    non una bugia;
##  · **il grado non si giudica.** Sotto una pioggerella si può scrivere
##    «acquazzone» e passa: sono la stessa famiglia. Un'esagerazione di
##    stile non è un mondo diverso;
##  · **e il FOGLIO non dice al modello che tempo fa.** Questa regola boccia
##    chi indovina male una cosa che non gli è stata detta, ed è il motivo
##    per cui butta parecchio (la misura sta in `tools/prova_cielo.gd`). La
##    cura alla radice sarebbe una riga in più in `_blocco_quando` — ma
##    quella cambia le GENERAZIONI, e le generazioni si misurano
##    rigenerando il mazzo con un modello da 2,6 GB. Finché quella misura
##    non c'è, il prompt non si tocca: qui si è cambiato solo ciò che si
##    poteva contare.

## LE PAROLE CHE AFFERMANO UNO STATO DEL CIELO. La chiave è lo stato, e i
## nomi sono quelli veri (`Critters.METEO`): un test li lega, perché una
## chiave scritta storta non fallisce — smette di giudicare, e in silenzio.
##
## Si guarda la RADICE e non la parola intera, perché un modello coniuga e
## una lista di forme scritta a mano ne dimentica sempre una («piovigginava»
## non l'avrei messa). Le radici sono lunghe apposta: verificate sul mazzo
## vero, prendono 32 righe su 1395 e sono tutte e sole quelle che parlano del
## cielo — zero collisioni.
##
## `sereno` NON è qui, ed è la sua definizione: il sereno è quello che resta
## quando nessuna di queste parole è vera. Non esiste una riga che «afferma
## il sereno» e che si possa smentire.
const CIELO := {
	"pioggia": ["piogg", "piov", "acquazzon"],
	"neve": ["nev"],
	"nebbia": ["nebbi"],
}

## IL SOLE ADDOSSO. Non è una parola, è un TELAIO: «al sole» chiede che il
## sole ci sia, mentre «il sole cala» parla del sole come di una cosa, e di
## notte è vero uguale. Sono le uniche quattro forme in cui, in italiano, il
## sole diventa un posto in cui si sta.
const SOLE_ADDOSSO := [["al", "sole"], ["nel", "sole"], ["dal", "sole"],
	["sotto", "il", "sole"]]

## IL MOMENTO IN CUI IL SOLE NON C'È. Uno dei sei di `OraDelGiorno.MOMENTI`
## (il test lo lega), ed è l'unico che non ammette discussione: all'alba e al
## tramonto il sole c'è ancora, di sera dipende.
const MOMENTO_SENZA_SOLE := "notte"

## IL PARAGONE NON AFFERMA. «come pioggia», «come la neve», «quanto una
## nebbia»: la finestra è di due parole perché in mezzo ci sta l'articolo.
const PARAGONE := ["come", "quanto"]

## L'IMPRESSIONE NON È IL CIELO. «sa di pioggia», «profuma di pioggia», «un
## senso di pioggia» — l'odore di una cosa non è quella cosa. Il telaio è
## adiacente (parola, «di», parola del cielo) e per questo non copre «gocce
## di pioggia», che invece la pioggia ce l'ha dentro davvero.
const IMPRESSIONE := ["sa", "sanno", "sapeva", "sapevano",
	"profuma", "profumano", "profumava", "odora", "odorano", "odorava",
	"senso", "sapore", "odore", "profumo", "sentore"]
const DI := ["di", "d"]


## LA RIGA LIBERA SMENTISCE IL CIELO? Torna "" se non lo smentisce (il caso
## buono), altrimenti il motivo. Pura come `afferma`: una stringa scritta a
## mano e un ritratto scritto a mano.
##
## ⚠️ SENZA LA CHIAVE NON SI GIUDICA, e non è prudenza generica: è che non
## c'è un oracolo. Il prologo, il diorama del titolo e i banchi di prova non
## hanno un cielo da smentire, e un ritratto senza `meteo` deve comportarsi
## ESATTAMENTE come si comportava prima che questa funzione esistesse. Il
## degrado va sempre verso «passa»: bocciare per una chiave mancante vorrebbe
## dire che il gioco tace di più proprio dove il mondo è più piccolo.
static func afferma_sul_cielo(riga: String, rit: Dictionary) -> String:
	var ws := parole(riga)

	var meteo := str(rit.get("meteo", ""))
	if meteo != "":
		for i in ws.size():
			var stato := _stato_del_cielo(str(ws[i]))
			if stato == "" or stato == meteo:
				continue
			if _e_un_paragone(ws, i) or _e_un_impressione(ws, i):
				continue
			return "una riga libera non cambia il tempo che fa: dice «%s», e c'è %s" \
					% [str(ws[i]), meteo]

	if str(rit.get("momento", "")) == MOMENTO_SENZA_SOLE:
		for tel in SOLE_ADDOSSO:
			var k := _telaio(ws, tel as Array)
			if k >= 0 and not _e_un_paragone(ws, k):
				return "una riga libera non accende il sole di notte: «%s»" \
						% " ".join(tel as Array)
	return ""


## QUALE STATO DEL CIELO AFFERMA QUESTA PAROLA, o "".
static func _stato_del_cielo(w: String) -> String:
	for stato in CIELO:
		for rad in (CIELO[stato] as Array):
			if w.begins_with(str(rad)):
				return str(stato)
	return ""


## LA PAROLA IN POSIZIONE `i` STA DENTRO UN PARAGONE? Si guarda indietro di
## due, che è quanto basta a scavalcare l'articolo («come la neve»).
static func _e_un_paragone(ws: PackedStringArray, i: int) -> bool:
	for k in [i - 1, i - 2]:
		if k >= 0 and PARAGONE.has(str(ws[k])):
			return true
	return false


## ...O DENTRO UN'IMPRESSIONE? Telaio adiacente e nient'altro: `w di X`.
static func _e_un_impressione(ws: PackedStringArray, i: int) -> bool:
	if i < 2:
		return false
	return IMPRESSIONE.has(str(ws[i - 2])) and DI.has(str(ws[i - 1]))


## DOVE COMINCIA QUESTO TELAIO DI PAROLE, o -1.
static func _telaio(ws: PackedStringArray, tel: Array) -> int:
	if tel.is_empty() or ws.size() < tel.size():
		return -1
	for i in range(ws.size() - tel.size() + 1):
		var tutte := true
		for k in tel.size():
			if str(ws[i + k]) != str(tel[k]):
				tutte = false
				break
		if tutte:
			return i
	return -1


## LA RIGA LIBERA AFFERMA QUALCOSA? Torna "" se non afferma niente (il caso
## buono), altrimenti il motivo. Pura: si prova con una stringa scritta a
## mano e un ritratto scritto a mano, senza modello e senza villaggio.
static func afferma(riga: String, rit: Dictionary, b := {}) -> String:
	var ws := parole(riga)
	var nomi: PackedStringArray = b["nomi"] if b.has("nomi") else _nomi_del_villaggio(rit)
	var radici: PackedStringArray = b["radici"] if b.has("radici") else _radici_dei_verbi()

	# 1. UN NOME. In qualunque forma: la grammatica vieta le maiuscole, quindi
	# un modello che nomina qualcuno lo fa in minuscolo — ed è per questo che
	# la maiuscola non bastava.
	for w in ws:
		if nomi.has(w):
			return "una riga libera non nomina nessuno, e nomina «%s»" % w

	for i in ws.size():
		var w: String = ws[i]

		# 2. IL PASSATO DELLA SECONDA PERSONA. «hai fissato», «sei andata»:
		# quello che ha fatto Mochi lo dice la citazione, e non ce n'è altro.
		if TU_AUSILIARI.has(w) and i + 1 < ws.size() and _e_participio(ws[i + 1]):
			return "una riga libera non racconta cosa hai fatto tu: «%s %s»" % [w, ws[i + 1]]
		# «ti ho vista», «ti hanno raccontato»: la citazione, riscritta a mano.
		if w == "ti" and i + 2 < ws.size() and TERZA_AUSILIARI.has(ws[i + 1]) \
				and PERCEZIONE.has(ws[i + 2]):
			return "una riga libera non dice cosa si è visto di te: «%s %s %s»" \
					% [w, ws[i + 1], ws[i + 2]]

		# 3. IL TELAIO DELLA PERCEZIONE + UN'AZIONE. «l'ho vista costruire».
		# Un telaio nudo invece passa, ed è voluto: «l'ho guardato dall'alto,
		# stamattina» è una riga del Gufo scritta a mano.
		if PERCEZIONE.has(w):
			for j in [i + 1, i + 2]:
				if j < ws.size() and (_e_infinito(ws[j]) or _e_participio(ws[j])):
					return "una riga libera non dice cos'ha visto: «%s %s»" % [w, ws[j]]

			# 3b. ...E NEMMENO CON UN OGGETTO NOMINALE, che è il buco che la
			# regola qui sopra lasciava aperto — misurato su un banco puro,
			# senza modello:
			#     «ho visto i tuoi passi e ho visto le tue zampe.»   PASSAVA
			#     «ho visto la tua casa e ho visto il tuo focolare.» PASSAVA
			#     «ti ho vista annaffiare le aiuole.»                bocciata
			# La regola 2 copre solo gli ausiliari della seconda persona
			# («hai», «sei»); questa forma è in PRIMA persona («ho visto») e
			# quel che afferma sta in un NOME, non in un verbo. È la stessa
			# frase della citazione — cos'ho visto di te — scritta da chi non
			# ne ha il diritto, e quella lettera è uscita davvero.
			#
			# La fonte è chiusa e minuscola: i modi in cui l'italiano dice
			# «tuo». Un telaio di percezione insieme a uno di questi, nella
			# stessa riga, non è mai una riga di chi parla.
			for altra in ws:
				if TUO.has(altra):
					return "una riga libera non dice cos'ha visto di te: «%s … %s»" % [w, altra]

		# 4. UN VERBO DEL MONDO CONIUGATO. L'infinito nudo resta lecito
		# («anche quando tagliare sarebbe più corto» è del Gufo).
		for rad in radici:
			if w.length() > rad.length() and w.begins_with(rad) \
					and CONIUGATO.has(w.substr(rad.length())):
				return "una riga libera non coniuga i verbi del villaggio: «%s»" % w

	# 5. UNA COSA DEL VILLAGGIO AL PASSATO. «le case sono state regolate con
	# cura» è un fatto sul villaggio del giocatore che nessuno ha visto.
	var cosa := _cosa_nominata(ws, rit)
	if cosa != "":
		var p := _passato_di_terza(ws)
		if p != "":
			return "una riga libera non racconta cos'è successo a %s: «%s»" % [cosa, p]
	return ""


## LE PAROLE, in minuscolo e senza punteggiatura. L'apostrofo SEPARA («l'ho»
## fa «l» e «ho»): dentro una parola sola, il clitico non si vedrebbe.
##
## È pubblica perché `Giudice.gd` misura la novità sulle STESSE parole con
## cui questo file giudica il senso: due spezzettature diverse dello stesso
## testo sono due testi, e prima o poi divergono in silenzio.
## Si lavora sui PUNTI DI CODICE e si taglia una volta per parola. La prima
## stesura tagliava una stringa di un carattere per ogni carattere (`substr`
## alloca, `LETTERE.contains` riscorre trentotto lettere ogni volta): 160 µs
## per una riga di sessanta caratteri, e il giudice la chiama una volta per
## riga di ogni bozza e di ogni lettera in memoria. Il conto è lo stesso, il
## risultato pure — c'è un caso di prova che lo pretende.
static func parole(riga: String) -> PackedStringArray:
	var lettere := _alfabeto()
	lettere.erase(APOSTROFO)

	var out := PackedStringArray()
	var s := riga.to_lower()
	var inizio := -1
	for k in s.length():
		if lettere.has(s.unicode_at(k)):
			if inizio < 0:
				inizio = k
		elif inizio >= 0:
			out.append(s.substr(inizio, k - inizio))
			inizio = -1
	if inizio >= 0:
		out.append(s.substr(inizio, s.length() - inizio))
	return out

## Le lettere ammesse come punti di codice, in un dizionario nuovo a ogni
## chiamata: chi lo riceve può togliersi quello che non gli serve (`parole`
## toglie l'apostrofo) senza rovinarlo a nessun altro.
static func _alfabeto() -> Dictionary:
	var out := {}
	for i in LETTERE.length():
		out[LETTERE.unicode_at(i)] = true
	return out

const APOSTROFO := 39
const SPAZIO := 32
const VIRGOLA := 44


static func _e_participio(w: String) -> bool:
	if w.length() < 5:
		return false
	return PARTICIPIO.has(w.substr(w.length() - 3))


static func _e_infinito(w: String) -> bool:
	if w.length() < 5:
		return false
	return INFINITIVO.has(w.substr(w.length() - 3))


## LE RADICI DEGLI OTTO VERBI, ricavate TOGLIENDO la desinenza dell'infinito
## a `INFINITO` — che è la coniugazione della tabella del binario, cioè la
## fonte. Tagliare a lunghezza fissa dava «annaf», che non è la radice di
## niente: la regola non scattava mai, e sembrava a posto (misurato: zero
## bocciature su 392 righe).
static func _radici_dei_verbi() -> PackedStringArray:
	var out := PackedStringArray()
	for k in INFINITO:
		var inf := str(INFINITO[k]).split(" ")[0]
		for fine in INFINITIVO:
			if inf.ends_with(fine):
				out.append(inf.substr(0, inf.length() - 3))
				break
	return out


## LA COSA DEL VILLAGGIO nominata da questa riga, o "". Le sei arrivano da
## `rit["cose"]`, cioè da `EcsMondo.nome_cosa()`: qui non c'è una settima
## lista da tenere allineata.
##
## Si accettano due lettere di scarto sulla radice, che sono il plurale e il
## femminile (casa/case, pesce/pesci) e non di più: senza quel tetto «cas»
## si prendeva «castagna» e «pesc» si prendeva «pescare» — cioè il mestiere
## della regola 4, fatto peggio.
static func _cosa_nominata(ws: PackedStringArray, rit: Dictionary) -> String:
	var cose: Array = rit.get("cose", [])
	for w in ws:
		for c in cose:
			var rad := str(c).substr(0, max(3, str(c).length() - 1))
			if w.begins_with(rad) and w.length() <= rad.length() + 2:
				return w
	return ""


## IL PASSATO DI TERZA PERSONA presente in questa riga, o "". La prima
## persona non conta, ed è la differenza fra «ci ho pensato tutto il
## pomeriggio» (il Gufo, sempre vero perché è suo) e «le case sono state
## regolate» (un fatto che nessuno ha visto).
static func _passato_di_terza(ws: PackedStringArray) -> String:
	for i in ws.size():
		if not TERZA_AUSILIARI.has(ws[i]):
			continue
		for j in [i + 1, i + 2]:
			if j >= ws.size():
				break
			if STATO.has(ws[j]):
				continue        # la copula non è un fatto
			if _e_participio(ws[j]):
				return "%s %s" % [ws[i], ws[j]]
	return ""


## LE TRE CICATRICI DELLA PAROLA, in una passata sola: torna "" se le
## parole di questa riga sono parole (il caso buono), altrimenti il motivo.
##
## Sono tre domande diverse — il tetto della grammatica, le vocali, il
## registro — e stanno insieme
## perché escono tutte dalla stessa porta (`parola`) e perché così un banco
## di prova può misurarle su una stringa scritta a mano, senza villaggio.
## È pubblica per quello: `tools/prova_cielo.gd` le fa girare sul mazzo vero
## e conta quante righe ognuna prende.
static func parole_storte(riga: String) -> String:
	var w := _parola_incollata(riga)
	if w != "":
		return "«%s» non è una parola: è il tetto della grammatica" % w
	var q := _non_e_una_parola(riga)
	if q != "":
		return "«%s» non è una parola italiana: non ha vocali" % q
	var v := _fuori_registro(riga)
	if v != "":
		return "«%s» non è una parola che il Gufo ha in bocca" % v
	return ""


## UNA PAROLA INCOLLATA: il modello ha sbattuto contro il tetto della
## grammatica e ha tolto lo spazio. Vedi `LETTERE_MAX`.
static func _parola_incollata(riga: String) -> String:
	for p in riga.split(" ", false):
		var w := str(p).strip_edges().trim_suffix(",")
		for f in FINALI:
			w = w.trim_suffix(f)
		if w.length() >= LETTERE_MAX:
			return w
	return ""


## LE CINQUE VOCALI, accentate comprese. Si ricavano da `LETTERE`, che è
## l'alfabeto vero della metà libera: una lista scritta a mano qui sarebbe la
## seconda, e il giorno che l'alfabeto cambia divergerebbero.
const VOCALI := "aeiouàáèéìíòóùú"

## UNA PAROLA SENZA VOCALI NON È UNA PAROLA. Non è una regola di stile: è una
## regola della lingua — in italiano ogni parola ne ha almeno una, e le uniche
## eccezioni sono sigle, che qui non possono esistere (non ci sono maiuscole).
##
## Chiude un pezzetto di un guasto più grande, e la misura dice quanto: fra le
## righe promosse dal mazzo vero c'erano «ryst», «irds», «uisce»,
## «izzazione» — pezzi di gettone rimasti attaccati a una riga. Questa regola
## prende solo il primo. **IL RESTO È RESIDUO DICHIARATO**: una non-parola con
## dentro una vocale è indistinguibile, per una funzione pura, da una parola
## rara — e un dizionario italiano dentro il gioco è un'altra faccenda.
##
## ⚠️ SI GUARDA FRA GLI SPAZI, NON CON `parole()`, e la differenza è tutto il
## caso: `parole()` spezza sull'apostrofo apposta (il clitico dentro una
## parola sola non si vedrebbe), quindi «l'ho» le dà «l» e «ho» — e «l» non ha
## vocali. Misurato: con `parole()` questa regola bocciava **19 bozze su 180**,
## e quasi tutte per un'elisione perfettamente italiana.
static func _non_e_una_parola(riga: String) -> String:
	for p in riga.to_lower().split(" ", false):
		var w := str(p).strip_edges().trim_suffix(",")
		for f in FINALI:
			w = w.trim_suffix(f)
		if w == "":
			continue
		var vocale := false
		for k in w.length():
			if VOCALI.contains(w.substr(k, 1)):
				vocale = true
				break
		if not vocale:
			return w
	return ""




## ═══════════════════════════════════════════════════════════════════════
## LE CICATRICI DEL GETTONE — quella che si chiude, e quella che no
## ═══════════════════════════════════════════════════════════════════════
##
## Rileggendo le trenta lettere mandate dal 4B, due guasti di PAROLA non li
## vedeva nessuna regola. Uno si chiude qui, l'altro no — e il modo in cui si
## distinguono è tutta la questione, perché la differenza non è quanto sono
## brutti: è se esiste una regola che li prende senza portarsi via
## dell'italiano vero.
##
## 1. **UNA PAROLA VERA, NEL REGISTRO SBAGLIATO.** «ivi» è italiano — è
##    l'avverbio di luogo degli atti notarili — e compare in **cinque delle
##    trenta lettere mandate** («il legno scricchiola ivi», «piume sulla
##    corteccia ivi», «pioggia leggera ivi ivi»), diciannove volte sul mazzo
##    intero. Nessuna delle diciannove vuol dire niente: il modello ci tappa
##    i buchi, come farebbe con un gettone qualunque, e il risultato è una
##    lettera che sembra uscita da un ufficio.
##    ⚠️ **QUESTA È UNA REGOLA DI GUSTO, e va detto.** Tutte le altre di
##    questo file sono di lingua o di grafo; questa dice «il Gufo non ha
##    queste parole in bocca», e il criterio è quello che il messaggio di
##    sistema chiede già: *parole semplici*. La lista è corta apposta e non
##    deve allungarsi a ogni bozza brutta — ci stanno solo i deittici e i
##    connettivi da atto pubblico, che in una lettera di questo gioco non
##    hanno un uso possibile. Costo misurato sul mazzo vero: **zero righe
##    buone**, perché nessuna delle diciannove lo era.
##
## 2. **E QUELLO CHE RESTA APERTO: le non-parole con le vocali dentro**
##    («ivieta», «orteccio», «moffa», «orte», «ervingo», «ialogo», «ildi»).
##    Sono code di parole vere a cui il gettone ha mangiato l'inizio (o due
##    parole senza lo spazio in mezzo), e per riconoscerle serve un
##    dizionario italiano — che è un'altra faccenda. **Tre** strade sono
##    state provate e MISURATE, e tutte e tre si buttano:
##     · «una parola italiana finisce per vocale» — vera come regola, ma sul
##       mazzo prende soltanto due parole (e sono inglesi), mentre il
##       troncamento poetico che il Gufo ha diritto di usare («andar via»,
##       «il fior di neve», «cuor») finirebbe bocciato: si perde più di
##       quanto si prenda;
##     · «la parola non compare in nessun'altra riga del mazzo» — cioè un
##       dizionario improvvisato con la frequenza: **493 parole su 1036**
##       compaiono una volta sola in tutto il corpus, e sono quasi tutte
##       italiano bellissimo («fronde», «luccichio», «smarrita»,
##       «piumaggio»). Sarebbe la mannaia sulla varietà, che è l'unica cosa
##       per cui il modello è qui;
##     · **«due parole-attrezzo incollate»** — questa era scritta, funzionava
##       e prendeva `ildi` («il»+«di»). È stata tolta dopo aver ENUMERATO
##       quello che prendeva: con `ARTICOLI` come lista di pezzi boccia
##       **«dello»** («del»+«lo»), **«dagli»**, **«digli»**, **«dadi»**,
##       **«loda»** e **«lodi»**, che sono italiano di tutti i giorni. E c'è
##       di peggio del falso positivo di oggi: `ARTICOLI` esiste per
##       tagliare le ETICHETTE dei vicini, non per questo. Il giorno che
##       qualcuno ci aggiunge «nel», «dal», «sul» — una modifica innocua,
##       fatta per un'altra ragione, in un altro punto del file — la regola
##       comincia a bocciare **«nella»**, **«dalla»** e **«sulla»** senza che
##       nessun test possa accorgersene. Un guadagno di **una riga su 1751**
##       non paga una trappola così. Chi la riscriverà: serve un elenco di
##       parole-attrezzo che sia SUO, e la dimostrazione che le
##       concatenazioni non sono parole vere — cioè, di nuovo, un
##       dizionario.

## LE PAROLE CHE IL GUFO NON HA IN BOCCA. Deittici e connettivi da atto
## notarile: parole vere, ma di un registro che questo gioco non parla in
## nessun altro punto — né nelle lettere scritte a mano, né nei dialoghi.
## Non è un elenco di parole brutte, e non deve diventarlo: se un domani ci
## si aggiunge una parola che qualcuno potrebbe dire davvero, questa lista ha
## smesso di essere una regola ed è diventata un gusto personale.
const FUORI_REGISTRO := ["ivi", "quivi", "colà", "altresì", "nonché",
	"laddove", "allorché", "ovverosia", "testé", "orbene",
	"suddetto", "suddetta", "suddetti", "suddette",
	"predetto", "predetta", "predetti", "predette",
	"codesto", "codesta", "codesti", "codeste"]


## LA PAROLA DI QUESTA RIGA CHE IL GUFO NON HA IN BOCCA, o "".
static func _fuori_registro(riga: String) -> String:
	for w in parole(riga):
		if FUORI_REGISTRO.has(str(w)):
			return str(w)
	return ""


## I NOMI CHE IL VILLAGGIO HA DAVVERO, in minuscolo e a pezzi. Un'etichetta
## è «la volpina Papavero»: vale «volpina» quanto «papavero», perché in
## questo villaggio non ci sono volpine che non siano qualcuno.
##
## ⚠️ IL PREZZO, dichiarato e voluto: i nomi dei chibi sono nomi comuni
## (`ChibiDNA.NAMES`: Nuvola, Miele, Farina, Prugna…). Un villaggio con una
## Nuvola toglie al Gufo la parola «nuvola» — quella bozza viene bocciata e
## se ne sceglie un'altra. Si paga in SILENZIO, che è l'esito legittimo di
## questo sistema; l'alternativa sarebbe pagare in una frase che il
## giocatore legge come una cosa detta della sua vicina.
static func _nomi_del_villaggio(rit: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var fonti := [str(rit.get("nome", "")), str(rit.get("protagonista", ""))]
	for k in (rit.get("nomi", {}) as Dictionary):
		fonti.append(str(rit["nomi"][k]))
	for f in fonti:
		for w in parole(str(f)):
			if not ARTICOLI.has(w) and not out.has(w):
				out.append(w)
	return out


# =========================================================================
# IL COLLAUDO — l'ultima porta prima dello schermo
# =========================================================================

## ACCETTA, O DICE PERCHÉ NO. Torna {"ok": bool, "motivo": String,
## "porta": String}.
##
## LE TRE PORTE, in quest'ordine, e l'ordine è parte del progetto:
##  · `forma`      — com'è fatto il testo: la citazione esatta e sola, al suo
##                   posto, e righe libere di soli caratteri ammessi;
##  · `parola`     — una parola incollata al tetto della grammatica;
##  · `ancoraggio` — il SENSO: quello che una riga libera non ha il diritto
##                   di dire (vedi la sezione qui sopra);
##  · `cielo`      — il MONDO: quello che una riga libera non può smentire,
##                   perché il villaggio lo sa (vedi «IL CIELO»).
## Stanno in tre passate separate e non intrecciate perché il motivo dica
## sempre la stessa cosa, e perché un banco di prova possa misurare quanto
## pesa ognuna: un testo che esce con `porta = "ancoraggio"` è un testo che
## il collaudo di prima — quello che guardava solo i caratteri — avrebbe
## promosso.
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
static func accetta(testo: String, rit: Dictionary, b := {}) -> Dictionary:
	var banc: Dictionary = b if not b.is_empty() else banco(rit)
	var cit: Array = banc["citazioni"]
	if cit.is_empty():
		return _no("non c'è niente di vero da dire", "forma")
	var reg: Dictionary = COMPITI[compito_di(rit)]

	var righe := []
	for r in testo.split("\n"):
		var s := str(r).strip_edges()
		if s != "":
			righe.append(s)
	if righe.is_empty():
		return _no("testo vuoto", "forma")

	var quante_cit := 0
	var i_cit := -1
	for i in righe.size():
		if cit.has(righe[i]):
			quante_cit += 1
			i_cit = i
	if quante_cit == 0:
		return _no("non cita niente di vero", "forma")
	if quante_cit > 1:
		return _no("cita più di una cosa", "forma")

	if i_cit > (1 if bool(reg["apertura"]) else 0):
		return _no("la citazione non è al suo posto", "forma")
	var chiusure := righe.size() - i_cit - 1
	if chiusure < int(reg["chiusura_min"]) or chiusure > int(reg["chiusura_max"]):
		return _no("il numero di righe non è quello chiesto", "forma")

	var libere := []
	for i in righe.size():
		if i != i_cit:
			libere.append(str(righe[i]))

	for riga in libere:
		var m := _riga_libera_ok(str(riga))
		if m != "":
			return _no(m, "forma")

	for riga in libere:
		var w := parole_storte(str(riga))
		if w != "":
			return _no(w, "parola")

	# LA TERZA PORTA, E NON È UN DOPPIONE DELLA GRAMMATICA. La grammatica sa
	# impedire di CAMPIONARE una frase falsa fra quelle chiuse; non sa niente
	# della prosa libera, che è libera per costruzione. Il senso di quelle
	# righe si può guardare soltanto qui.
	for riga in libere:
		var m := afferma(str(riga), rit, banc)
		if m != "":
			return _no(m, "ancoraggio")

	# LA QUARTA PORTA: IL CIELO. Sta a parte dall'ancoraggio e non dentro,
	# perché non è la stessa domanda e non ha la stessa fonte — l'ancoraggio
	# confronta col GRAFO di quel vicino, questa col MONDO di adesso — e
	# perché un banco di prova deve poter contare quanto pesa ognuna delle
	# due. Un testo che esce con `porta = "cielo"` è un testo che il collaudo
	# di ieri avrebbe mandato al giocatore.
	for riga in libere:
		var c := afferma_sul_cielo(str(riga), rit)
		if c != "":
			return _no(c, "cielo")

	# ...e IL PONTEGGIO NON È TESTO. Due cose che il gioco scrive per il
	# MODELLO e che il giocatore non deve mai leggere:
	#  · un pezzo della citazione rimasto per aria, quando il modello è
	#    andato a capo in mezzo («dall'altra parte del villaggio.» da sola è
	#    minuscola, sta in cinque parole e non afferma niente — e passava);
	#  · l'etichetta del PESO, che nel foglio sta fra quadre per dire di cosa
	#    valga la pena parlare. Trovata in una lettera vera del provino: «il
	#    peso di quel gesto resta addosso appena, come se fosse una pietra».
	#    Si confronta l'etichetta INTERA, non un pezzo: «che resta addosso» è
	#    italiano normale e resta lecito, «resta addosso appena» no — quello
	#    è il ponteggio, e si sente leggendo.
	for riga in libere:
		var p := _ponteggio(str(riga), banc)
		if p != "":
			return _no(p, "forma")
	return {"ok": true, "motivo": "", "porta": ""}


static func _no(motivo: String, porta: String) -> Dictionary:
	return {"ok": false, "motivo": motivo, "porta": porta}


## Questa riga è un frammento di una delle frasi chiuse? Si confronta senza
## il punto finale, che il modello aggiunge dove va a capo.
static func _ponteggio(riga: String, b: Dictionary) -> String:
	var s := riga.to_lower().strip_edges()
	for f in FINALI:
		s = s.trim_suffix(f)

	# IL FOGLIO NON È TESTO. La lista non si ricopia: la costruisce
	# `_frasi_del_foglio()` dal ritratto, cioè dallo stesso posto da cui esce
	# il foglio.
	for voce in (b.get("ponteggio", []) as Array):
		if s.contains(str(voce)):
			return "«%s» è una frase del foglio, non una riga tua" % str(voce)

	# ...E NEMMENO LA SAGOMA.
	var sag := sagoma_del_foglio(riga)
	if sag != "":
		return sag

	if s.length() < 8:
		return ""
	for c in (b["citazioni"] as Array):
		if str(c).to_lower().contains(s):
			return "«%s» è un pezzo della citazione, non una riga tua" % riga
	return ""


## ═══════════════════════════════════════════════════════════════════════
## LA SAGOMA LETTA AD ALTA VOCE — l'istruzione che esce dalla busta
## ═══════════════════════════════════════════════════════════════════════
##
## `_frasi_del_foglio` guarda il blocco UTENTE (il dossier, le etichette, i
## pezzi fra parentesi). Il messaggio di SISTEMA non lo guardava nessuno — e
## quello, a un modello piccolo, si ricopia meglio di tutto il resto, perché
## è la cosa che gli è stata detta per ultima e in imperativo. Sul mazzo
## vero:
##
##     «una riga tua, se ti va.»    dieci volte, e in UNA LETTERA MANDATA
##     «a riga tua ivi.»            due volte, mandata
##     «una riga mia orte.»         due volte
##     «mia riga a te.»             mandata
##     «una riga tua il vento e il miele.»
##
## Sono l'istruzione che esce dalla busta: il giocatore apre una lettera del
## Gufo e ci trova scritto il modulo con cui è stata compilata.
##
## LA REGOLA NON È SULLA FRASE, e non è nemmeno sulla parola. Ci sono
## voluti due giri e una bocciatura per arrivarci:
##
##  1. **la frase intera** («una riga tua») ne prende diciannove su ventisei:
##     le altre sette sono mutazioni («a riga tua», «una riga mia», «mia riga
##     a te») che a un confronto letterale sfuggono tutte;
##  2. **la parola sola** («riga») le prende tutte e ventisei — e boccia
##     anche *«una lucciola sola scrive una riga d'oro sull'acqua nera»*,
##     che non viene da nessun modello: è la bozza bella scritta a mano
##     dentro `test_giudice.gd`, quella che serve a provare che la rarità
##     funziona. La suite è diventata rossa in sei punti, ed è stato il modo
##     giusto di scoprirlo: «riga» è una parola che questa voce PUÒ usare;
##  3. quello che il villaggio non ha è **la riga DI QUALCUNO**. «una riga
##     tua», «le righe tue», «una riga mia» sono il prompt che divide il
##     lavoro fra chi dà le frasi e chi le scrive: un possessivo di prima o
##     seconda persona attaccato al nome del foglio. Fuori dal foglio quella
##     cosa non esiste — a un vicino che scrive a Mochi non tocca «una riga
##     sua».
##
## Misurato sul mazzo vero: **ventisei righe su ventisei** prese, e **zero**
## righe buone perdute — passano la lucciola d'oro, «una riga bianca,
## fredda» e «mi manda una riga».
##
## Un test lega queste liste al messaggio di sistema VERO: se un domani il
## prompt chiederà «un verso tuo», qui diventa rosso invece di continuare a
## sorvegliare una parola che il foglio non usa più.
const PAROLE_DEL_FOGLIO := ["riga", "righe"]
const POSSESSIVI := ["mia", "mio", "mie", "miei", "tua", "tuo", "tue", "tuoi"]


## LA SAGOMA DEL FOGLIO IN QUESTA RIGA, o "". Si guarda la COPPIA, perché è
## il possessivo a fare del foglio una cosa di qualcuno — e sta di qua o di
## là («una riga tua», «mia riga a te»).
static func sagoma_del_foglio(riga: String) -> String:
	var ws := parole(riga)
	for i in ws.size():
		if not PAROLE_DEL_FOGLIO.has(str(ws[i])):
			continue
		for k in [i - 1, i + 1]:
			if k >= 0 and k < ws.size() and POSSESSIVI.has(str(ws[k])):
				var coppia := [str(ws[i]), str(ws[k])] if k > i else [str(ws[k]), str(ws[i])]
				return "«%s %s» è la sagoma del foglio, non una riga tua" % coppia
	return ""


## ═══════════════════════════════════════════════════════════════════════
## IL FOGLIO LETTO AD ALTA VOCE — e perché è un guasto e non uno stile
## ═══════════════════════════════════════════════════════════════════════
##
## Il prompt di questo file scrive tre cose che il modello deve LEGGERE e mai
## ripetere: il dossier del vicino (chi è, cosa sta facendo, cosa gli sta a
## cuore), le etichette del peso fra quadre, e i pezzi facoltativi fra
## parentesi. Nessuna delle tre è una bugia — sono tutte vere — ma nessuna è
## una frase da mettere in una lettera: sono **appunti di regia**, e una
## lettera che li recita suona come un referto.
##
## Misurato sul mazzo vero (180 bozze italiane registrate in partita, un
## modello piccolo): fra le 77 righe promosse dal collaudo, **una su cinque**
## era il foglio riletto ad alta voce —
##   «non sopporta un'aiuola trascurata, adesso fa il suo giro, quello che
##    sta più a cuore»
##   «confida i suoi segreti ai funghi, adesso cerca qualcosa da sgranocchiare»
##   «un pezzo fa, un pezzo fa, un pezzo fa»
##   «che a due passi da casa sua»
##   «'un rametto di salvia' lo ricorda bene»
## — e la penultima è anche la prova che serviva la CODA e non solo la frase
## intera: l'etichetta è «se lo ricorda bene», la riga dice «lo ricorda bene».
##
## LE DUE REGOLE CHE LA TENGONO ONESTA:
##
## 1. **Solo le frasi di QUESTO foglio.** Non le otto azioni, non le otto
##    indoli: quella scritta stasera per questo vicino. Un villaggio dove
##    nessuno guarda il cielo non toglie al Gufo la parola «guarda il cielo».
## 2. **Almeno tre parole.** Sotto le tre, un frammento smette di essere la
##    frase del gioco e torna a essere italiano di tutti («si riposa»,
##    «poco fa», «a lungo»). È la stessa fascia grigia del taccuino: meglio
##    lasciar passare un'eco corta che vietare una parola comune.
static func _frasi_del_foglio(rit: Dictionary, elenco: Array) -> Array:
	var frasi := []
	# il dossier: chi è, cosa fa, cosa vuole, cosa gli sta a cuore
	for id in (rit.get("indole", []) as Array):
		var voce = BRAIN.INDOLI.get(str(id), null)
		if voce != null and (voce as Array).size() > 0:
			frasi.append(str(voce[0]))
	frasi.append(str(BRAIN.QUIRK_LINES.get(str(rit.get("quirk", "")), "")))
	frasi.append(str(AZIONI_DETTE.get(str(rit.get("azione", "")), "")))
	frasi.append(str(OBIETTIVI_DETTI.get(str(rit.get("obiettivo", "")), "")))
	frasi.append(GUSTO_PIU)
	frasi.append(GUSTO_NIENTE)
	# il ponteggio della citazione: l'etichetta del peso e i pezzi facoltativi
	for f in elenco:
		var voce: Dictionary = f
		frasi.append(str(voce["forza"]))
		for m in (voce["mods"] as Array):
			frasi.append(str(m))

	var out := []
	for f in frasi:
		for coda in _code(str(f)):
			if not out.has(coda):
				out.append(coda)
	return out


## LE CODE DI UNA FRASE, da tre parole in su: la frase intera e quello che
## resta togliendole la prima parola, poi la seconda. Non di più — «sta
## facendo qualcosa per la fame» diventa «qualcosa per la fame», che è ancora
## la frase del gioco; una parola più in là sarebbe «per la fame», cioè
## italiano di chiunque.
const CODA_PAROLE_MIN := 3
const CODA_TAGLI := 2

static func _code(frase: String) -> Array:
	var out := []
	if frase == "":
		return out
	var ws := frase.to_lower().split(" ", false)
	for k in (CODA_TAGLI + 1):
		if ws.size() - k < CODA_PAROLE_MIN:
			break
		var pezzi := []
		for i in range(k, ws.size()):
			pezzi.append(str(ws[i]))
		out.append(" ".join(pezzi))
	return out


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

	# come in `parole()`: punti di codice, e si taglia una stringa solo per
	# dire quale carattere non andava bene
	var lettere := _alfabeto()
	var quante := 0
	var in_parola := false
	var prec := SPAZIO
	for k in corpo.length():
		var cp := corpo.unicode_at(k)
		if cp == SPAZIO:
			in_parola = false
			prec = cp
			continue
		if cp == VIRGOLA:
			prec = cp
			continue
		if not lettere.has(cp):
			return "una riga libera non può contenere «%s»" % corpo.substr(k, 1)
		# ⚠️ L'APOSTROFO DEVE ELIDERE, o è una VIRGOLETTA.
		#
		# Le virgolette sono vietate (il messaggio di sistema lo dice, e
		# l'alfabeto non le contiene): l'apostrofo era passato perché in
		# italiano serve a respirare — «l'ho vista», «un'ombra». Ma un modello
		# piccolo se lo prende come virgoletta, e allora la riga libera smette
		# di essere una riga sua e diventa una CITAZIONE di qualcosa: del
		# foglio, della sagoma del prompt, di una frase inventata.
		#
		# Misurato sul mazzo vero (180 bozze italiane registrate in partita):
		# **30 delle 77 righe promosse** cominciavano un pezzo con un
		# apostrofo che non elide — «'scrive' a te», «'una riga tua' irds un
		# fiore» (che è la SAGOMA del prompt, letta ad alta voce), «' ' uisce
		# verso l'alto».
		#
		# La regola è di lingua, non di gusto, e non ha eccezioni da tarare:
		# un apostrofo italiano ha SEMPRE una lettera davanti — elisione
		# («l'ho») o troncamento («un po'», «be'»). Uno che apre non elide
		# niente: apre una citazione.
		#
		# (E l'apostrofo NON conta come lettera davanti a sé stesso: «' '» è
		# una virgoletta aperta e una chiusa, non una parola elisa.)
		if cp == APOSTROFO and (prec == APOSTROFO or not lettere.has(prec)):
			return "un apostrofo che non elide è una virgoletta, e le virgolette non ci sono"
		prec = cp
		if not in_parola:
			in_parola = true
			quante += 1
	var parole := quante
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
