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
## ⚠️ Quanto resta di una cosa bella vista da chi sta malissimo. Non zero (il
## malumore toglie colore davvero) e non uno (la lente deve pesare): un sesto.
## Il numero non è tarato a occhio — è scelto perché la valenza più piccola e
## positiva del gioco (`+0.12`, il compito del sogno) resti **sopra zero** con
## l'umore al fondo, che è l'invariante che questa costante esiste per
## garantire.
const RESIDUO_BELLO := 0.167

# =========================================================== IL CARICO
#
# ⚠️ **UNO STATO LENTO, e sposta il PUNTO DI RIPOSO — non il livello.**
#
# Il sostrato chimico non poteva avere due stati stabili, e non per taratura:
# i sette archi formano un DAG (ascissa spettrale −0.02 per tutti) e il budget
# di riga lo rende una CONTRAZIONE, che ha UN punto fisso. Un sistema così non
# può crollare e non può restare giù.
#
# La prima cura provata fu un autofeedback saturo sul LIVELLO del cortisolo.
# Era sbagliata in due modi, tutti e due MISURATI, e tutti e due della stessa
# famiglia — **misurare col caso di riposo invece che col caso vero**:
#  1. il certificato usava la baseline (0.08) invece del bersaglio vero
#     `B + Π/λ`, che col maltempo arriva a **0.49** per un codardo: il termine
#     lo sfondava del 67%, lo stato cavalcava il clamp a 1.0, e quel vicino
#     sedeva a otto centesimi dal ribaltamento. Il villaggio come ospedale;
#  2. e **una notte lo cancellava comunque**: `consolida_sonno` fa
#     `move_toward(cortisolo, base_cort, 0.85)`, che da 0.91 alla baseline
#     arriva in un colpo. Bistabilità irraggiungibile oltre una giornata.
#
# Qui il carico **non tocca il livello**: sposta `neuro_base`, cioè dove il
# livello TORNA. Tre conseguenze, e nessuna è una taratura:
#
#  1. **la matrice resta esattamente quella di prima** — Gershgorin, il DAG, i
#     cinque `static_assert`, «il bersaglio sta fuori dalla matrice»: intatti;
#  2. **`consolida_sonno` punta a `neuro_base`**, quindi il sonno smette di
#     riparare **senza toccarne una riga**. Una notte non cancella più niente:
#     riporta il livello al riposo, e il riposo è quello spostato;
#  3. **`trattieni()` scala su `livello − riposo`**, che all'equilibrio è
#     **zero**. L'autocontrollo di chi è crollato costa esattamente quanto
#     quello di chiunque altro — e «una condizione non rende nessuno
#     inaffidabile» smette di essere una mitigazione e diventa un TEOREMA.
#
# ⚠️ **E L'ANELLO NON SI CHIUDE — MISURATO, e il limite è STRUTTURALE.**
#
# Il disegno voleva un circolo: carico ↑ ⇒ riposo peggiore ⇒
# `bersaglio_umore` ↓ ⇒ umore ↓ ⇒ `s(−umore)` ↑ ⇒ carico ↑, cioè un secondo
# stato stabile. **Non succede**, e il conto dice perché.
#
# `bersaglio_umore` pesa i canali così: dopamina 0.20, serotonina 0.35,
# ossitocina 0.20, endorfine 0.15, cortisolo −0.40. Con lo scarto qui sopra
# il guadagno sarebbe K = 0.5425 — ma **i clamp se ne mangiano un pezzo**: la
# dopamina scende di 0.50 e ne ha solo 0.40 di margine, le endorfine di 0.30
# e ne hanno 0.15. K efficace = **0.50**.
#
# MISURATO: a carico **pieno** l'umore si posa a **−0.325** (e 0.175 − 0.50 =
# −0.325: il conto torna al millesimo). La soglia `CARICO_M0` è **0.35**.
# Quindi la spinta vale **0.0000 a ogni livello di carico**, e il guadagno
# d'anello è **zero**.
#
# E non è una taratura da trovare: perché l'anello si chiudesse a metà strada
# servirebbe K ≈ **1.35**, cioè quasi tre volte quello che i cinque canali
# possono dare portati tutti al proprio limite. **Il margine non c'è.**
#
# Le due strade per chiuderlo, per chi ci tornerà, e nessuna è gratis:
#  · **abbassare `CARICO_M0`** — ma è tarata sulla soglia con cui
#    `stato_corpo()` dice «di malumore» (−0.35) e sull'umore medio del
#    villaggio (+0.32): abbassarla vuol dire che le brutte giornate normali
#    cominciano a caricare, cioè **il villaggio come ospedale**;
#  · **un secondo termine nell'anello** che non passi dall'umore (il carico
#    che si alimenta da sé, o da qualcosa che non sia `bersaglio_umore`) — e
#    allora serve un certificato nuovo, di nuovo.
#
# **QUINDI QUESTO NON È UN SECONDO STATO STABILE, ed è scritto qui perché
# nessuno lo chiami così.** È un **carico lento con isteresi nei tempi**: tre
# giornate per prenderselo, trenta per smaltirlo da solo, e i gesti che lo
# scaricano davvero sono quelli **portati a termine**. Una brutta stagione
# lascia qualcosa, e quel qualcosa non se ne va aspettando. È meno di quello
# che il disegno prometteva, ed è quello che i numeri concedono.
#
# **IL CERTIFICATO**, e sostituisce quello di contrazione che qui non basta:
#  · **[0,1] è invariante per il carico, ESATTAMENTE e senza clamp**: in
#    salita `ȧ = (s−a)/τ` con `s ∈ [0,1]`, quindi in a=0 è ≥ 0 e in a=1 è ≤ 0;
#    in discesa `ȧ = −a·r ≤ 0` e si annulla in zero;
#  · **i sette canali restano limitati**, ereditato: `neuro_base(a)` è affine
#    in `a`, quindi il bersaglio sta nell'inviluppo convesso di quello a
#    carico zero e di quello a carico uno — tutti e due già in [0,1] per i
#    clamp che ci sono. E per ogni `a` fissato la mappa è la contrazione di
#    prima. **Niente muri, niente clamp che facciano finta di essere un punto
#    fisso.**

## Dove comincia e dove satura la spinta del malumore sul carico. Sotto M0 non
## si accumula niente: è la zona morta, e garantisce che una brutta giornata
## non lasci niente.
## ⚠️ MISURATI contro le grandezze vere di questo gioco: l'umore medio del
## villaggio sta a **+0.32**, il peggio assoluto dei bisogni a **−0.5615**, e
## la soglia con cui `stato_corpo()` dice «di malumore» è **−0.35**. M0 sta lì.
const CARICO_M0 := 0.35
const CARICO_M1 := 0.65

## Le costanti di tempo, in secondi di gioco (una giornata ne dura 240).
## ⚠️ **ASIMMETRICHE DI DIECI VOLTE, ed è l'isteresi**: tre giornate per
## caricarsi, trenta per scaricarsi da solo. Il ritorno non è la strada
## dell'andata, e senza l'aiuto di qualcuno è lunghissimo.
const CARICO_TAU_SU := 720.0
const CARICO_TAU_GIU := 7200.0

## Quanto ogni atto PORTATO A TERMINE scarica il carico. ⚠️ È la
## *behavioural activation*, che è il trattamento con più evidenza per la
## depressione e funziona attraverso il FARE, non attraverso l'umore che
## migliora prima. Per questo è un conteggio di gesti compiuti e non una
## somma di conforto ricevuto.
const CARICO_PER_ATTO := 0.05

## Di quanto il carico pieno sposta il punto di riposo, canale per canale.
## Stessa disciplina di `AMPIEZZA_TINTA`: uno SCARTO, e a carico zero somma
## **zero esatto**.
const CARICO_SCARTO := {
	"cortisolo": 0.45, "serotonina": -0.45, "dopamina": -0.50,
	"ossitocina": -0.30, "endorfine": -0.30,
}

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
## Sotto questa misura il corpo non fa proprio niente. Vale per tutte e due
## le monete della strada veloce (l'allarme e il calore): il silenzio è il
## comportamento normale, e la soglia è UNA.
const SOGLIA_SUSSULTO := 0.22
## Oltre questa bruschezza il corpo parte comunque, anche se chi arriva è
## caro: il riflesso non sa ancora chi sia. Ed è anche il tetto sotto cui una
## gioia può farsi vedere — in mezzo a qualcosa di brusco un cuoricino non ci
## sta.
const RIFLESSO_GREZZO := 0.25
## Quanta scia lascia un allarme nel corpo.
const SCIA_ALLARME := 0.55
## **IL TAMPONE SOCIALE** — quanto la presenza della figura di attaccamento
## smorza l'allarme. Entra come DIVISORE del guadagno (`reattivita`), non come
## sottrazione dal risultato, e la differenza è tutta la meccanica:
##
##  · **sottrarre sarebbe un BONUS**: lo stesso identico sollievo per tutti,
##    cioè una costante che chi è già calmo non usa (finisce sotto zero e la
##    perde) e che chi è terrorizzato non sente. Il conforto diventerebbe una
##    proprietà del CONFORTO, non della persona confortata;
##  · **dividere il guadagno è un'INTERAZIONE**: `reattivita` è per definizione
##    il guadagno della paura («la codardia lo alza, la grinta lo abbassa»),
##    quindi lo smorzamento ASSOLUTO resta proporzionale a quanto quel corpo è
##    reattivo. Chi trasale di più riceve di più — che è la firma psicologica
##    del fenomeno, e **non c'è niente da tarare, perché quella proporzione la
##    porta la struttura** invece di un secondo numero da tenere allineato.
##
## A 1.0 la presenza piena dimezza il guadagno. Zero è il neutro **ESATTO** e
## non per tolleranza: `0.0 * K` è +0.0, `1.0 + 0.0` è 1.0 esatto, e `x / 1.0`
## è esatto in IEEE-754 — quindi a conforto zero (cioè in tutti i banchi, nel
## Prologo, nel diorama e in ogni chiamante che non lo passa) il gioco è
## bit-identico a prima, e le guardie possono pretendere `==`.
const TAMPONE_SOCIALE := 1.0

# ================== I 7 CANALI NEUROCHIMICI, e la loro casa ==============
#
# ⚠️ **QUESTA E' L'UNICA CASA.** C'era anche un modello C++ (`ComponenteNeuro-
# chimica` + `sistema_neurochimica.{h,cpp}`): girava sessanta volte al secondo
# per ogni residente e **non lo leggeva nessuno** — misurato mettendo un
# `return` in testa al suo passo, la suite restava identica (68157/0) e
# `avanza()` scendeva da 11,4 a 8,2 µs. Aveva per giunta baseline DIVERSE da
# queste in cinque canali su sette (cortisolo 0.20 contro 0.08, adenosina 0.20
# contro 0.0…): due tabelle gemelle per la stessa cosa, che e' quello che la
# regola delle fonti uniche vieta.
#
# La casa e' qui e non di la' per una ragione scritta: **questo dato e'
# PERSISTITO** (`save()`/`load()` piu' sotto), e il capitolo dell'ECS dice che
# i dati persistiti restano in GDScript e il C++ ne riceve al massimo uno
# specchio — «due case sullo stesso dato salvato e' il guasto che le fonti
# uniche vietano». Quello che il C++ aveva di buono (l'integrazione, la
# produzione ambientale, il decadimento per canale) e' stato portato QUI.
const NEURO_TRASMETTITORI := [
	"dopamina", "ossitocina", "serotonina", "cortisolo",
	"melatonina", "adenosina", "endorfine"
]

## Dove torna ogni canale quando non succede niente. E' il punto di riposo
## della persona: `setup()` lo tinge col carattere e `Animo.sincronizza_neuro`
## lo sposta coi bisogni. **I bisogni spostano il PUNTO DI RIPOSO, non il
## livello** — scriverci sopra il livello, com'era prima, cancellava ogni
## impulso degli eventi: la chiacchierata alzava l'ossitocina a 1.0 e il primo
## `ricorda()` qualunque la riportava a 0.7575, misurato. Cioe' il piatto
## caldo e l'onsen non contavano niente.
const NEURO_BASELINE := {
	"dopamina": 0.40,
	"ossitocina": 0.40,
	"serotonina": 0.50,
	"cortisolo": 0.08,
	"melatonina": 0.0,
	"adenosina": 0.0,
	"endorfine": 0.15,
}

## λ: quanto in fretta ogni canale torna al suo punto di riposo, in 1/secondo
## di gioco (una giornata ne dura 240). Portate dal modello C++, dove erano
## gia' tarate: la serotonina e' il canale lento, la melatonina il piu' svelto.
const NEURO_DECADIMENTO := {
	"dopamina": 0.05,
	"ossitocina": 0.05,
	"serotonina": 0.02,
	"cortisolo": 0.08,
	"melatonina": 0.10,
	"adenosina": 0.04,
	"endorfine": 0.06,
}

## Quanta produzione continua puo' arrivare dal MONDO, per canale. Il punto
## fisso di un canale e' `B + Π/λ`, ed e' li' che il modello C++ era rotto:
## la serotonina aveva Π = 0.04 contro λ = 0.02, cioe' equilibrio **2.50** —
## il 150% oltre il tetto. Misurato: arrivava a 0.999 in quattordici secondi e
## ci restava, e un impulso di +0.50 la muoveva di `+0.000000`. Su quel canale
## l'omeostasi non esisteva: era una costante 1.0 per tutta la parte
## illuminata della giornata, per chiunque, qualunque cosa succedesse.
##
## ⚠️ **QUINDI OGNI RIGA QUI DENTRO SI LEGGE COL SUO λ ACCANTO**, e il punto
## fisso a produzione piena sta scritto in fondo. Chi ne cambia una rifaccia
## il conto: un canale che sfonda il tetto smette di essere un canale.
const NEURO_PRODUZIONE := {
	"dopamina": 0.010,     # λ 0.05  → 0.40 + 0.20 = 0.60
	"ossitocina": 0.005,   # λ 0.05  → 0.40 + 0.10 = 0.50
	"serotonina": 0.007,   # λ 0.02  → 0.50 + 0.35 = 0.85   (era 2.50)
	"cortisolo": 0.030,    # λ 0.08  → 0.08 + 0.375 = 0.455
	"melatonina": 0.045,   # λ 0.10  → 0.00 + 0.45 = 0.45
	"adenosina": 0.012,    # λ 0.04  → 0.00 + 0.30 = 0.30
	"endorfine": 0.010,    # λ 0.06  → 0.15 + 0.167 = 0.317
}

## Il passo piu' lungo che il modello accetta, in secondi. Un caricamento, una
## pausa o un `time_scale` possono consegnare un delta enorme: con
## l'integrazione esatta il risultato resterebbe corretto, ma «corretto» qui
## vuol dire che un vicino attraversa mezza giornata in un fotogramma. Si
## tronca, e il tempo perduto e' perduto.
const NEURO_PASSO_MAX := 2.0

## La costante di tempo dell'UMORE, in secondi di gioco. L'umore e' il canale
## lento del gioco — «colora la lettura di tutto il resto» — e con questo
## valore un secondo lo sposta al massimo di 0.022, contro i 0.18 che gli
## rimette a posto una notte di sonno.
##
## ⚠️ **E QUESTO NUMERO ESISTE PERCHE' PRIMA NON C'ERA NESSUN TEMPO.**
## `_modula_stati_da_neuro` faceva `umore += spinta * 0.05` **per CHIAMATA**,
## e `Visitors._ciclo_sonno` la chiamava due volte per fotogramma per ogni
## residente: l'umore era una rampa alla frequenza del fotogramma. MISURATO
## nel MainLevel vero, dieci residenti che nessuno tocca: **umore +1.0000 su
## dieci vicini su dieci**, saturo in 17,5 s a 60 fps e in 42,1 s a 25 —
## esattamente il rapporto 60/25. Un carattere codardo saturava a **−1.0000
## in 2,77 s**, e con drive un po' piu' bassi ci finiva chiunque. Cioe':
## `stato_corpo()` non avrebbe mai piu' detto «di malumore» a nessuno, il capo
## che pende avrebbe perso una delle tre cause, e un LUTTO si cancellava in
## **tre secondi**.
const UMORE_TAU := 90.0

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

## Il livello attuale dei sette canali (0.0 .. 1.0). E' l'unico stato
## neurochimico del gioco, ed e' persistito.
var neuro: Dictionary = NEURO_BASELINE.duplicate()
## DOVE TORNA quando non succede niente — il punto di riposo di QUESTA
## persona. Lo tinge il carattere (`setup`) e lo spostano i bisogni
## (`Animo.sincronizza_neuro`). Non si salva: si ricalcola da tratti e drive,
## che sono gia' persistiti tutti e due.
var neuro_base: Dictionary = NEURO_BASELINE.duplicate()
## ⚠️ **LO SCARTO DEL CARATTERE**, e non si salva: e' una funzione pura dei
## tratti (`tinta_carattere`), che sono gia' persistiti. Rifarla al caricamento
## costa cinque moltiplicazioni; salvarla vorrebbe dire una seconda casa per un
## dato derivato — e quelle in questo progetto divergono sempre.
var neuro_tinta: Dictionary = {}

## Quanto il carattere puo' spostare il punto di riposo di ogni canale, da un
## estremo all'altro del tratto. **Sono le ampiezze delle righe che stavano in
## `setup()`**, riportate qui intere: la riga del cortisolo era `0.05 + cod *
## 0.10`, cioe' un decimo di canale fra il coraggioso e il codardo.
##
## ⚠️ Si tarano **guardando** (`tools/provino_carattere.gd`), mai a occhio: un
## decimo di cortisolo sul corrugatore puo' essere invisibile, e un carattere
## che non si vede non e' un carattere. E si tarano sapendo che TUTTO il
## villaggio le indossa insieme — un'ampiezza che rende leggibile il codardo
## rende anche tutti gli altri un po' piu' se stessi.
const AMPIEZZA_TINTA := {
	"cortisolo": 0.10,
	"ossitocina": 0.25,
	"dopamina": 0.25,
	"endorfine": 0.20,
	"serotonina": 0.20,
}

## Quanto è reattivo questo individuo (dal carattere: la codardia alza
## l'allarme, la grinta lo abbassa). 1.0 = nella media.
var reattivita := 1.0
## Quanto in fretta si abitua: gli ambiziosi si abituano prima al bene.
var abitudine := ABITUDINE


func setup(tratti: Dictionary) -> void:
	# ⚠️ I TRATTI SI CONSERVANO, e NON si salvano: `Animo.setup(dna)` li
	# ripassa a ogni caricamento, quindi sono derivati da un dato che sta già
	# nel salvataggio (il DNA). Una seconda copia salvata sarebbe la doppia
	# casa che questo progetto vieta — e questo file ne ha già pagata una
	# (`dna.tratti` contro `animo.tratti`).
	_tratti = tratti.duplicate()
	var cod: float = float(tratti.get("codardia", 0.5))
	var gri: float = float(tratti.get("grinta", 0.5))
	var amb: float = float(tratti.get("ambizione", 0.5))
	var lea: float = float(tratti.get("lealta", 0.5))
	reattivita = clampf(0.6 + cod * 0.9 - gri * 0.35, 0.2, 1.8)
	abitudine = clampf(ABITUDINE * (0.7 + amb * 0.8), 0.05, 0.75)
	# il carattere tinge il PUNTO DI RIPOSO, e il livello ci parte sopra:
	# cosi' un vicino appena nato e' gia' se stesso, e ci torna dopo ogni cosa
	# che gli succede.
	neuro_tinta = tinta_carattere(tratti)
	neuro_base = NEURO_BASELINE.duplicate()
	applica_tinta(neuro_base)
	neuro = neuro_base.duplicate()


## LE DUE GRANDEZZE CHE IL CORPO DERIVA DAI TRATTI, rifatte.
##
## Erano due righe dentro `setup()`, cioe' calcolate una volta sola nella vita
## di un vicino. Adesso i tratti possono muoversi (vedi `Animo.tratto()`), e
## una formula che gira una volta sola e' una formula che si ferma un
## millimetro prima del corpo. Il precedente e' `EcsMondo::riproietta`, un
## piano piu' giu': chi ha dei geni derivati li rifa' quando i geni cambiano.
##
## ⚠️ **E queste due NON si rileggono piu' dal salvataggio.** Erano scritte E
## rilette con un default di 1.0, cioe' **congelate sul disco per sempre**: un
## salvataggio vecchio riportava una reattivita' che non corrispondeva piu' ai
## tratti di quella persona, e nessuno se ne accorgeva. Si continuano a
## SCRIVERE in `save()`, e va detto perche': un valore derivato scritto e mai
## riletto e' una diagnostica, non una seconda fonte — e toglierlo dal file
## farebbe regredire una build vecchia che aprisse un salvataggio nuovo
## (`load` aveva il default a 1.0, cioe' appiattirebbe la reattivita' di tutti
## alla media). Un test prova che nessuno le rilegge.
func riproietta(tratti: Dictionary) -> void:
	var cod: float = float(tratti.get("codardia", 0.5))
	var gri: float = float(tratti.get("grinta", 0.5))
	var amb: float = float(tratti.get("ambizione", 0.5))
	reattivita = clampf(0.6 + cod * 0.9 - gri * 0.35, 0.2, 1.8)
	abitudine = clampf(ABITUDINE * (0.7 + amb * 0.8), 0.05, 0.75)
	# ⚠️ **E LA TINTA, o la deriva si ferma un millimetro prima del corpo.**
	# Questa funzione rifaceva DUE grandezze delle sette che `setup` deriva
	# dai tratti; le altre cinque sono i canali della chimica, cioe' proprio
	# quelli che arrivano addosso a un corpo (il corrugatore, le pupille, il
	# rimbalzo, la coda). Un tratto che deriva senza rifarle muove il
	# comportamento e non muove NIENTE che si veda.
	neuro_tinta = tinta_carattere(tratti)
	# ⚠️ **E IL VETTORE DEI TRATTI, che e' la QUARTA delle grandezze e per un
	# pezzo e' stata l'unica dimenticata.** `_tratti` alimenta
	# `_tratti_vettore()`, cioe' le sette tinte di carattere sugli archi della
	# matrice di accoppiamento dell'INTRECCIO — e quella matrice non e' una
	# diagnostica: `_intreccio_passo` e' il passo VIVO della chimica, che il
	# villaggio fa per ogni residente a ogni fotogramma. Senza questa riga la
	# mente di chi e' diventato codardo restava accoppiata come quella di chi
	# era alla nascita, per sempre.
	# MISURATO (codardia 0.20 -> 0.85, grinta 0.80 -> 0.25): `reattivita`
	# 0.500000 -> 1.277500, cioe' la deriva arrivava; `phi()` 0.000077234 ->
	# 0.000077234, cioe' **bit-identico**, mentre chi NASCE con quel carattere
	# sta a 0.000051215 (-34%).
	_tratti = tratti.duplicate()


## ⚠️ **IL CARATTERE E' UNO SCARTO, non una scrittura.**
##
## Queste cinque righe stavano dentro `setup()` e ASSEGNAVANO cinque canali
## di `neuro_base`. Erano **morte**: `Animo.sincronizza_neuro()` riassegna gli
## stessi cinque canali dai bisogni, e la chiamano sette posti — a partire da
## `Animo.setup()` stesso, tre righe dopo. MISURATO: con la codardia da 0.20 a
## 0.85 i cinque canali uscivano **bit-identici** (cortisolo 0.1200,
## ossitocina 0.7575, dopamina 0.8315, serotonina 0.8650, endorfine 0.7935).
## Il carattere non tingeva la chimica a riposo: ne' alla nascita, ne' mai —
## quindi ogni vicino del villaggio aveva lo stesso corpo a riposo, e le
## differenze passavano solo dai drive. E' la stessa forma di guasto dei 247
## righe di somatizzazione senza chiamanti: codice completo, provato, verde e
## mai eseguito.
##
## La cura NON puo' essere «riassegnare dopo i bisogni»: cancellerebbe i
## bisogni, che e' esattamente il difetto che `sincronizza_neuro` documenta
## nella sua testata. Il carattere diventa uno **SCARTO dal carattere neutro**
## (tutti i tratti a 0.5) che si SOMMA a quel che i bisogni hanno deciso:
##
##   · un carattere perfettamente medio contribuisce **zero esatto**, quindi
##     per lui il gioco e' bit-identico a prima (e con lui restano intatte
##     tutte le misure gia' prese: il piatto caldo, il ri-aggancio del
##     cortisolo, il morso della lingua);
##   · un codardo sta un filo piu' in alto sul cortisolo **sempre**, qualunque
##     cosa dicano i suoi bisogni — che e' cosa vuol dire avere un carattere;
##   · e siccome e' una funzione dei TRATTI, la deriva la muove.
static func tinta_carattere(tratti: Dictionary) -> Dictionary:
	var cod: float = float(tratti.get("codardia", 0.5)) - 0.5
	var gri: float = float(tratti.get("grinta", 0.5)) - 0.5
	var amb: float = float(tratti.get("ambizione", 0.5)) - 0.5
	var lea: float = float(tratti.get("lealta", 0.5)) - 0.5
	return {
		"cortisolo": cod * AMPIEZZA_TINTA["cortisolo"],
		"ossitocina": lea * AMPIEZZA_TINTA["ossitocina"],
		"dopamina": amb * AMPIEZZA_TINTA["dopamina"],
		"endorfine": gri * AMPIEZZA_TINTA["endorfine"],
		"serotonina": -cod * AMPIEZZA_TINTA["serotonina"],
	}


## Somma la tinta a un punto di riposo gia' deciso dai bisogni. Un posto solo,
## chiamato in coda a `Animo.sincronizza_neuro()`: se ne esistessero due,
## sarebbero due composizioni da tenere allineate a mano.
func applica_tinta(base: Dictionary) -> void:
	# ⚠️ E IL CARICO ENTRA QUI, insieme alla tinta del carattere e per la
	# stessa ragione: è uno SCARTO dal punto di riposo, non un'assegnazione.
	# A carico zero somma **zero esatto**, quindi per chi non è mai stato
	# spinto oltre il crinale il gioco è quello di ieri, al bit.
	var _c := clampf(carico, 0.0, 1.0) if is_finite(carico) else 0.0
	if _c > 0.0:
		for _k in CARICO_SCARTO:
			base[_k] = clampf(float(base.get(_k, 0.0))
					+ float(CARICO_SCARTO[_k]) * _c, 0.0, 1.0)
	for c in neuro_tinta:
		if base.has(c):
			base[c] = clampf(float(base[c]) + float(neuro_tinta[c]), 0.0, 1.0)


## UN IMPULSO: una cosa che e' appena successa sposta un canale, adesso.
##
## ⚠️ **E NON TOCCA L'UMORE.** Prima chiamava `_modula_stati_da_neuro()`, che
## faceva `umore += spinta * 0.05` a ogni chiamata: l'umore diventava funzione
## di QUANTE VOLTE si chiama questa riga, non di cosa e' successo — misurato,
## cinquanta stimoli da ZERO (che non cambiano un bit della chimica) lo
## spostavano da 0.000000 a −0.116250. L'umore adesso lo muove il TEMPO, in
## `passo_neuro`, e questa funzione fa una cosa sola.
func stimola_neuro(tipo: String, quantita: float) -> void:
	if not neuro.has(tipo):
		return
	# ⚠️ **IL CANCELLO DEL NaN STA ALL'INGRESSO, e ce n'e' uno solo.** Lo
	# stato e' ricorsivo, quindi un NaN e' ASSORBENTE: `clamp(NaN)` restituisce
	# NaN, e un canale avvelenato non torna piu' indietro. Misurato sul modello
	# di prima: un SOLO fotogramma con un NaN dall'ambiente uccideva **quattro
	# canali su sette per sempre**, e dieci secondi puliti dopo erano ancora
	# NaN.
	if not is_finite(quantita):
		return
	neuro[tipo] = clampf(float(neuro[tipo]) + quantita, 0.0, 1.0)


## Restituisce il livello corrente (0.0 .. 1.0) del neurotrasmettitore
func livello_neuro(tipo: String) -> float:
	return float(neuro.get(tipo, float(NEURO_BASELINE.get(tipo, 0.0))))


## DOVE STAREBBE L'UMORE se la chimica di adesso durasse per sempre, -1..1.
## Non e' l'umore: e' il posto verso cui l'umore si muove, e ci arriva col
## suo tempo (`UMORE_TAU`).
func bersaglio_umore() -> float:
	var cort: float = float(neuro.get("cortisolo", 0.08))
	var dop: float = float(neuro.get("dopamina", 0.40))
	var ser: float = float(neuro.get("serotonina", 0.50))
	var ox: float = float(neuro.get("ossitocina", 0.40))
	var endo: float = float(neuro.get("endorfine", 0.15))
	return clampf((dop - 0.40) * 0.20 + (ser - 0.50) * 0.35
			+ (ox - 0.40) * 0.20 + (endo - 0.15) * 0.15
			- (cort - 0.08) * 0.40, -1.0, 1.0)


## IL PASSO OMEOSTATICO — l'unico posto in cui il tempo tocca la chimica.
##
## Integrazione ESATTA della `dN/dt = −λ(N − B) + Π`, cioe'
##
##     N(t+Δt) = (B + Π/λ) + (N − B − Π/λ) · e^(−λΔt)
##
## ⚠️ **E il `Π/λ` sta DENTRO la parentesi, che e' proprio il pezzo che il
## modello di prima non aveva**: scriveva `B + (N−B)·e^(−λΔt) + Π·Δt`, cioe'
## un Eulero esplicito innestato su un decadimento esatto. Sembrava esatta e
## non lo era: il punto fisso diventava `B + Π·Δt/(1−e^(−λΔt))`, cioe' una
## funzione del PASSO. MISURATO sul binario vero: un minuto simulato a 1 fps
## contro 60 fps dava melatonina 0.697490 contro 0.669030, e a passi grandi i
## canali arrivavano a 1.000000 invece che a 0.69. Lo stato era funzione del
## frame rate. Cosi' com'e' scritta adesso, il risultato **non dipende dal
## passo**: e' la stessa curva campionata piu' o meno fitto.
##
## [param amb] e' quello che dice il mondo adesso — `luce`, `pioggia`,
## `temperatura` — e arriva da `DayNight.parametri_ambientali()`.
func passo_neuro(dt: float, amb: Dictionary = {}, dorme := false,
		notte := 0.0) -> void:
	if not is_finite(dt) or dt <= 0.0:
		return
	dt = minf(dt, NEURO_PASSO_MAX)
	var prod := produzione_ambientale(amb, dorme, notte)
	# ⚠️ **L'INTRECCIO, se il cuore sa farlo.** Fino a oggi questo era un
	# ciclo di sette equazioni che non si guardavano — matrice di transizione
	# `diag(exp(-λ·dt))`, cioè informazione integrata **zero per teorema**.
	# Sette macchine separate che per caso le legge lo stesso corpo.
	# Adesso i canali si parlano (`src/intreccio.{h,cpp}`), e il bersaglio
	# resta FUORI dalla matrice: il punto di riposo è invariante al bit, così
	# nessuna delle tarature di questo gioco si sposta.
	#
	# Il degrado va dove va sempre: se il binario non sa rispondere — una
	# GDExtension più vecchia di questa riga, un banco, il Prologo — si fa
	# esattamente quel che si faceva ieri.
	if _intreccio_passo(dt, prod):
		var bers := bersaglio_umore()
		umore = clampf(bers + (umore - bers) * exp(-dt / UMORE_TAU), -1.0, 1.0)
		return
	for tipo in NEURO_TRASMETTITORI:
		var lam: float = float(NEURO_DECADIMENTO.get(tipo, 0.05))
		var b: float = float(neuro_base.get(tipo, NEURO_BASELINE.get(tipo, 0.0)))
		var n: float = float(neuro.get(tipo, b))
		var p: float = float(prod.get(tipo, 0.0))
		if lam > 0.0:
			var eq: float = b + p / lam
			n = eq + (n - eq) * exp(-lam * dt)
		else:
			n += p * dt
		neuro[tipo] = clampf(n, 0.0, 1.0) if is_finite(n) else b
	# …e l'umore insegue la chimica, col suo tempo. Il tempo, non il numero
	# di chiamate.
	var bers := bersaglio_umore()
	umore = clampf(bers + (umore - bers) * exp(-dt / UMORE_TAU), -1.0, 1.0)


## QUANTO NE PRODUCE IL MONDO, adesso, per canale. Pura: entra quel che dice
## il cielo, esce un dizionario. E' la parte del modello C++ che valeva la
## pena portare di qua — la luce che fa la serotonina e spegne la melatonina,
## il freddo e la pioggia che fanno il cortisolo, la veglia che accumula
## adenosina.
##
## ⚠️ **Il mondo non e' obbligato a rispondere**: senza `amb` (i banchi, il
## diorama del titolo, il Prologo) si resta al punto di riposo e basta. Il
## degrado va verso «non succede niente», mai verso un numero inventato.
static func produzione_ambientale(amb: Dictionary, dorme: bool,
		notte := 0.0) -> Dictionary:
	var out := {}
	for tipo in NEURO_TRASMETTITORI:
		out[tipo] = 0.0
	if amb.is_empty():
		return out
	var luce: float = clampf(float(amb.get("luce", 0.0)), 0.0, 1.0)
	var pioggia: float = clampf(float(amb.get("pioggia", 0.0)), 0.0, 1.0)
	var temp: float = float(amb.get("temperatura", 20.0))
	if not (is_finite(luce) and is_finite(pioggia) and is_finite(temp)):
		return out
	var comfort: float = clampf(1.0 - absf(temp - 20.0) / 20.0, 0.0, 1.0)
	out["dopamina"] = NEURO_PRODUZIONE["dopamina"] * comfort * luce
	out["ossitocina"] = NEURO_PRODUZIONE["ossitocina"] * comfort
	out["serotonina"] = NEURO_PRODUZIONE["serotonina"] * luce * (1.0 - 0.5 * pioggia)
	# ⚠️ **LA MELATONINA NON SEGUE LA LUCE: SEGUE LA PROPRIA NOTTE.**
	#
	# Era `Π * (1 − luce)`, e il difetto NON era «una seconda risposta a che
	# ora è» — era peggio e si misura: **quella riga non era un orologio, era
	# un barometro.** Il cielo di `DayNight.luce_ambiente()` cala col
	# `weather_gloom`, quindi a MEZZOGIORNO con un temporale la luce scende a
	# 0.550 e il punto di riposo della melatonina saliva a **0.202** — cioè il
	# **94%** del picco che il canale endogeno raggiunge la sera (0.216),
	# addosso a tutti e ventotto insieme. Un ritmo circadiano non si sposta
	# perché piove.
	#
	# E la seconda metà: tutti i vicini avevano la stessa identica curva,
	# mentre il gioco ha da sempre una fase PER PERSONA
	# (`chibi::finestra_di_sonno`, il genoma del sonno: persistito, visibile,
	# ed è perfino il grafo sociale del villaggio — le cricche nascono da chi
	# si stanca alla stessa ora).
	#
	# Adesso la sorgente è `notte` (0..1), che arriva dal C++ e ANTICIPA: sale
	# nell'anticipo prima della propria finestra di sonno.
	#
	# ⚠️ **E LA LUCE NON ENTRA PIÙ AFFATTO**, nemmeno come soppressore. Una
	# prima stesura la teneva con un `(1 − 0.85·luce)` e il perché scritto era
	# «così comincia a calare all'alba»: MISURATO, comprava −14% di picco e
	# −2,4 s di finestra, e la conseguenza che prometteva **non esiste** —
	# all'alba il corpo è già nascosto a scala 0.03 (`Visitor.resident_sleep`)
	# e `consolida_sonno` azzera comunque il canale. Una terza manopola con un
	# perché decorativo è debito, e si toglie.
	out["melatonina"] = NEURO_PRODUZIONE["melatonina"] * clampf(notte, 0.0, 1.0)
	out["endorfine"] = NEURO_PRODUZIONE["endorfine"] * comfort * (1.0 - 0.5 * pioggia)
	# chi dorme non accumula stress e non accumula sonno
	if not dorme:
		out["cortisolo"] = NEURO_PRODUZIONE["cortisolo"] \
				* (0.6 * pioggia + 0.4 * (1.0 - comfort))
		out["adenosina"] = NEURO_PRODUZIONE["adenosina"]
	return out


# ============================================================ le due strade

## STRADA VELOCE — il corpo, prima della testa.
## Guarda solo due cose: com'è marchiato il posto (o chi ha davanti) e quanto
## è già attivato. Non sa nulla del significato dell'evento: può benissimo
## sbagliarsi, ed è proprio quello a renderla vera.
## [param indizio] 0..1 è quanto è GREZZO il segnale che arriva adesso:
## qualcosa di grosso che si muove veloce, nel buio, addosso. La strada
## veloce non sa CHE COSA sia — sa solo che è brusco — e per questo può
## spaventarsi di un amico. È il caso in cui sbaglia, ed è esattamente
## quello che la rende vera: un attimo dopo la strada lenta la corregge
## («ah… sei tu»). Senza questo parametro il corpo poteva allarmarsi solo
## per chi già temeva, e la doppia strada non si vedeva mai.
## [param conforto] 0..1 è quanto è VICINA adesso la figura di attaccamento di
## chi percepisce (vedi `TAMPONE_SOCIALE`). Può solo ABBASSARE l'allarme, e
## zero — il valore di serie, cioè quello di ogni chiamante che non lo passa —
## è il neutro esatto. Chi lo calcola sta in `Visitors._tick_sussulti`: qui non
## si sa e non si deve sapere CHI sia quella persona, si riceve solo un numero.
func percepisci(attore := "", luogo := "", indizio := 0.0,
		conforto := 0.0) -> Dictionary:
	var carica := 0.0
	var fonte := ""
	for chiave in [("chi|" + attore) if attore != "" else "", ("luogo|" + luogo) if luogo != "" else ""]:
		if chiave == "" or not marchi.has(chiave):
			continue
		var c: float = float(marchi[chiave]["carica"])
		if absf(c) > absf(carica):
			carica = c
			fonte = chiave
	var grezzo := clampf(indizio, 0.0, 1.0)
	# ⚠️ **IL CANCELLO DEL NaN STA PRIMA DEL CLAMP, e l'ordine è tutto:**
	# `clampf(NAN, 0, 1)` restituisce **NaN** (le due comparazioni sono false, e
	# il valore passa intatto), quindi un clamp messo davanti non ferma niente e
	# fa solo credere di aver chiuso la porta. E qui un NaN non si fermerebbe
	# alla riga dopo: `allarme` alimenta `arousal`, che è **PERSISTITO** — cioè
	# la stessa forma assorbente già pagata in `stimola_neuro`, ma su un canale
	# che finisce nel salvataggio.
	if not is_finite(conforto):
		conforto = 0.0
	# ⚠️ **E il clamp a [0,1] è la garanzia ANTI-MALUS, non igiene.** Un conforto
	# NEGATIVO e finito passa `is_finite`, porta il divisore sotto 1, e la
	# divisione **AMPLIFICA** l'allarme: sarebbe il malus «stai peggio perché
	# sei solo» — quello che la REGOLA SACRA vieta — entrato dalla porta di
	# servizio, senza che nessuno l'abbia scritto da nessuna parte. Sopra 1 il
	# tetto tiene il tampone a un dimezzamento: la compagnia non azzera la
	# paura, la smorza.
	conforto = clampf(conforto, 0.0, 1.0)
	# La presenza entra sul GUADAGNO, non sul risultato: vedi `TAMPONE_SOCIALE`
	# per il perché (è un'interazione, non un bonus).
	var guadagno: float = reattivita / (1.0 + conforto * TAMPONE_SOCIALE)
	# ⚠️ **DUE MONETE, NON UNA — ed è la correzione più importante di questo
	# file.** Una sola `forza` pagava tutte e due le reazioni, e quella forza
	# era fatta di soli ingredienti dell'ALLARME: il valore assoluto del
	# marchio (cioè la paura e l'affetto sulla stessa scala), la `reattivita`
	# — che è per definizione il guadagno della paura, «la codardia lo alza,
	# la grinta lo abbassa» — e l'autoalimentazione dell'allerta.
	#
	# Le conseguenze erano tre, tutte MISURATE nel villaggio vero
	# (`tools/misura_sussulti.gd`, 28 residenti, 8 minuti):
	#  · un amico dopo sei incontri felici valeva **0,600**, cioè PIÙ di uno
	#    sconosciuto caricato di corsa (0,394): chi ti vuole bene reagiva più
	#    forte di chi si è spaventato;
	#  · quella forza alzava l'`arousal`, che in questo gioco ha un
	#    vocabolario solo — «ancora guardingo», «col cuore in gola» — e un
	#    consumatore che cambia il gioco (`Visitors._spiega_come_sta` toglie
	#    il saluto felice a chi ha il corpo scosso): **13 residenti su 28**
	#    finivano la giornata così, e più ti volevano bene prima ci
	#    arrivavano;
	#  · e `si_illumina` era il ramo DI SERIE, quindi bastava una camminata
	#    addosso per far comparire un cuoricino sopra la testa di uno che non
	#    ti aveva mai visto: **45 cuoricini su 48 senza nessuna storia
	#    dietro**. Un cuore che il giocatore non sa ricondurre a niente non
	#    attenua l'affetto vero: lo rende illeggibile.
	#
	# Adesso l'ALLARME lo alimenta solo ciò che allarma (la carica NEGATIVA e
	# la bruschezza), e il CALORE è la carica positiva e basta: nessun
	# guadagno di paura, nessuna autoalimentazione. Per tutto ciò che
	# allarmava, il conto è identico al bit — `maxf(0, -carica)` è
	# `absf(carica)` quando la carica è negativa — e un test lo dimostra su
	# una griglia (`test_gioia._la_paura_non_e_cambiata`).
	#
	# `forza` resta l'allarme e SOLO l'allarme, anche quando non basta a far
	# trasalire nessuno: chi la legge legge quanto il corpo si è attivato.
	#
	# ⚠️ **IL RESIDUO DEL TETTO, dichiarato e non curato.** Il `clampf` finale
	# è PRE-ESISTENTE al tampone, e in cima alla scala se lo mangia. Chiamando
	# `P` il prodotto prima del taglio:
	#  · da `P >= 1 + conforto` in su il tamponamento **sparisce del tutto**
	#    (tutte e due le versioni tagliano a 1.0): col conforto pieno è `P = 2`;
	#  · fra `P = 1` e `P = 1 + conforto` lo smorzamento c'è ancora, ma **la
	#    firma 1 si degrada** — il termine di paragone è già stato tagliato dal
	#    tetto, quindi lo scarto non è più proporzionale alla reattività.
	# E il caso limite NON è remoto: `P` arriva fino a **4.8**, e per sfondare
	# il 2.0 basta un marchio pieno più qualcosa di brusco addosso a un codardo
	# già in allerta. Cioè, nella parte alta della scala, il corpo trasale
	# uguale con o senza la persona a cui vuole bene.
	# ⚠️ E il massimo di `reattivita` è **1.5**, non 1.8: 1.8 è il tetto del
	# `clampf`, ma la formula dai tratti (`0.6 + cod·0.9 − gri·0.35`) non ci
	# arriva — il campo vero è [0.25, 1.5]. Chi rifà questo conto leggendo la
	# costante invece della formula lo sbaglia del 20%.
	# È un tetto che c'era già: va MISURATO e detto — **non curato cambiando la
	# forma**, che è decisa: il conforto divide il guadagno e basta.
	var allarme: float = clampf((maxf(0.0, -carica) + grezzo) * guadagno
			* (1.0 + arousal * 0.6), 0.0, 1.0)
	# ⚠️ **E IL CONFORTO NON TOCCA QUESTA RIGA.** Il `calore` è la carica
	# positiva e basta: nessun guadagno, nessuna allerta, e **nessun tampone**.
	# Il cuoricino di chi ti vuole bene non si spegne perché il suo compagno gli
	# è accanto — sarebbe la felicità smorzata dalla compagnia, cioè l'esatto
	# contrario di quello che questo parametro dice. Il tampone smorza l'ALLARME
	# e solo l'allarme, come `forza` è l'allarme e solo l'allarme.
	var calore: float = maxf(0.0, carica)
	var reazione := "nulla"
	if allarme > SOGLIA_SUSSULTO and (carica < 0.0 or grezzo > RIFLESSO_GREZZO):
		# un segnale brusco fa trasalire ANCHE se chi arriva è caro: il
		# corpo non ha ancora idea di chi sia.
		reazione = "trasalisce"
		# e la scia la lascia l'allarme, perché è lui che resta nel corpo
		arousal = clampf(arousal + allarme * SCIA_ALLARME, 0.0, 1.0)
		stimola_neuro("cortisolo", allarme * 0.30)
	elif calore > SOGLIA_SUSSULTO and grezzo <= RIFLESSO_GREZZO:
		# niente di brusco, e una storia vera alle spalle: chi ti vuole bene
		# si illumina — e adesso il cuoricino dice una cosa che è successa.
		reazione = "si_illumina"
		stimola_neuro("ossitocina", calore * 0.20)
		stimola_neuro("dopamina", calore * 0.15)
	# `conforto` è quello RIPULITO (finito e dentro [0,1]), cioè esattamente il
	# numero che ha diviso il guadagno: serve ai banchi per ricostruire la gamba
	# vera senza rifarne il conto — chiedere a un oracolo di ricalcolare la
	# formula che sta provando è chiedere al giudice se è d'accordo con sé
	# stesso. Non è persistito: `ultimo_sussulto` è una fotografia dell'istante,
	# non uno stato, e infatti `save()` non lo guarda.
	ultimo_sussulto = {"reazione": reazione, "forza": allarme, "calore": calore,
			"fonte": fonte, "carica": carica, "grezzo": grezzo,
			"conforto": conforto}
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
	# l'umore è la lente: di malumore anche un gesto neutro sembra un torto.
	#
	# ⚠️ **MA UNA LENTE NON PUÒ ROVESCIARE IL SEGNO DI UNA COSA BELLA.**
	# `umore * 0.22` è uno scarto, e su una valenza piccola e positiva bastava
	# a portarla sotto zero: MISURATO, per `umore < −0.5455` il gesto più
	# significativo che questo gioco conosca — leggere il sogno di qualcuno e
	# dargli quel lavoro (`Animo.esegue`, valenza fissa **+0.12**) — si
	# incideva come un **TORTO**. E chi ha quell'umore è chi ha perso
	# qualcuno, chi è stato lasciato, chi è stato trascurato: **esattamente
	# la persona che stavi provando ad aiutare.**
	#
	# Il gioco aveva già incontrato questa famiglia di guasto e ne aveva
	# chiusa una via: il commento di `esegue` racconta che l'ordine della
	# classificazione era sbagliato e «il lavoro-del-sogno maturava un ricordo
	# NEGATIVO». Quella porta fu chiusa; questa era rimasta aperta.
	#
	# La cura non toglie la lente — il malumore deve continuare a togliere
	# colore, ed è vero — ma le impedisce di attraversare lo zero: **una cosa
	# bella, vista da chi sta male, vale MENO. Non diventa una cosa brutta.**
	# Il gesto neutro (valenza zero) resta tingibile in negativo, che è la
	# cosa che il commento qui sopra promette e che resta vera.
	var letto: float = clampf(valenza + umore * 0.22, -1.0, 1.0)
	if valenza > 0.0 and letto < valenza * RESIDUO_BELLO:
		letto = valenza * RESIDUO_BELLO
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
	#
	# ⚠️ **E L'ALLARME LO ALZA SOLO CIÒ CHE ALLARMA** — la stessa regola della
	# strada veloce, qui sopra. `absf(sorpresa)` metteva sulla stessa scala il
	# tradimento e il regalo: MISURATO, **un solo regalo** portava l'arousal a
	# 0,315 e il gioco dichiarava quel vicino «ancora guardingo». Non è una
	# parola in un diario: `Visitors._spiega_come_sta` legge proprio quella
	# riga e, salutando (T), TOGLIE il saluto felice e ci mette una nuvoletta
	# di puntini. Fare un regalo a qualcuno e vederselo restituire con un
	# «…» è la gioia con addosso la faccia della paura, un piano più in alto.
	#
	# La sorpresa NEGATIVA resta tutta: la delusione e il tradimento scuotono
	# il corpo, ed è la riga che tiene in piedi «il male da chi ti aspettavi
	# il bene». Quella positiva va dove è sempre andata la parte cronica —
	# nell'UMORE, che ha le sue parole («di buonumore») e nessuna paura
	# dentro.
	var acuto: float = 0.08 if identita else 0.40
	var cronico: float = 0.26 if identita else 0.16
	arousal = clampf(arousal + maxf(0.0, -sorpresa) * acuto * reattivita, 0.0, 1.0)
	umore = clampf(umore + sentito * cronico, -1.0, 1.0)

	# Stimolazione dei canali neurochimici in base alla valenza e sorpresa
	if sentito > 0.0:
		stimola_neuro("dopamina", sentito * 0.25)
		stimola_neuro("serotonina", sentito * 0.20)
		if attore != "":
			stimola_neuro("ossitocina", sentito * 0.20)
	elif sentito < 0.0:
		stimola_neuro("cortisolo", -sentito * 0.35 * reattivita)

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
## Il cortisolo alto rende più faticoso trattenersi, scalando il costo del morso.
func trattieni(costo := COSTO_MORSO) -> bool:
	# ⚠️ **SI PAGA LO STRESS IN PIU', non lo stress che si ha sempre.** La
	# prima stesura scalava sul cortisolo ASSOLUTO, e il cortisolo di riposo
	# vale 0.05-0.15: il morso costava dal 4 all'11% in piu' **per tutti, dal
	# primo fotogramma di gioco**. Misurato A/B su un carattere codardo:
	# due morsi invece di tre prima di scoppiare, cioe' un sistema tarato
	# altrove spostato da un effetto collaterale. Sopra il proprio riposo
	# invece e' quello che la frase vuole dire: chi ha addosso qualcosa fa
	# piu' fatica a trattenersi.
	var base_cort: float = float(neuro_base.get("cortisolo", NEURO_BASELINE["cortisolo"]))
	var cort := maxf(0.0, livello_neuro("cortisolo") - base_cort)
	var costo_effettivo: float = costo * (1.0 + cort * 0.75)
	if regolazione < costo_effettivo:
		regolazione = 0.0
		stimola_neuro("cortisolo", 0.08)
		return false
	regolazione -= costo_effettivo
	morsi_oggi += 1
	stimola_neuro("cortisolo", 0.02)
	return true


## Ha finito la pazienza? (Serve a chi decide se far uscire la battuta.)
func esausto() -> bool:
	return regolazione <= 0.001


## Perché è scoppiato adesso: la frase che spiega la sproporzione.
func perche_scoppio() -> String:
	return L10n.rendi(perche_scoppio_rimandato())


## La stessa cosa un passo prima: la chiave e il suo conto, per chi la
## deve CONSERVARE invece che dirla subito (la posta la tiene in coda
## una notte, e la notte può cambiare lingua). {} se non c'è niente
## da spiegare.
func perche_scoppio_rimandato() -> Dictionary:
	if morsi_oggi >= 3:
		return {"k": "si era trattenuto %d volte oggi", "args": [morsi_oggi]}
	if regolazione <= 0.001:
		return {"k": "non gli restava più pazienza"}
	return {}


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


## Il perché di un evitamento. Senza questa frase il giocatore vedrebbe
## solo un residente che fa un giro strano e penserebbe a un bug.
##
## Ritorna il TEMPLATE, col segnaposto ancora dentro, e il numero a parte:
## una frase già riempita non sta in nessuna tabella di traduzione (vedi
## CLAUDE.md, «mai formattare prima di tradurre»). Chi la mostra fa
## `L10n.tf(esito["testo"], [esito["n"]])`.
func perche_evita_dati(luogo: String) -> Dictionary:
	var k := "luogo|" + luogo
	if not marchi.has(k):
		return {}
	var v: Dictionary = marchi[k]
	if float(v["carica"]) > -SOGLIA_EVITAMENTO:
		return {}
	return {"testo": "gli è successo qualcosa di brutto lì (%d volte)",
			"n": int(v["conferme"])}


## La stessa cosa già in italiano, per il registro e per i test: comoda
## dove non c'è nulla da tradurre.
func perche_evita(luogo: String) -> String:
	var d := perche_evita_dati(luogo)
	return "" if d.is_empty() else str(d["testo"]) % int(d["n"])


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

## Consolida il sonno simulando le fasi NREM e REM:
## - NREM: azzeramento adenosina (eliminazione pressione omeostatica),
##   drenaggio cortisolo verso baseline, ricarica regolazione
## - REM: reset arousal somatico, stabilizzazione emotiva e integrazione neurotrasmettitori
## ⚠️ **`resa` E' UN GRADO, NON UN INTERRUTTORE — e non e' un parametro
## nuovo: e' quello di prima, reso continuo.** 1.0 e' ESATTAMENTE la notte
## che il gioco ha sempre dato a tutti; 0.0 e' ESATTAMENTE il ramo che
## esisteva gia' per la notte che non ripara — **e che non chiamava
## nessuno**. In mezzo c'e' un `lerp` fra i due, e in questa funzione non
## compare **un solo numero nuovo**.
##
## Il `bool` di prima e' stato CANCELLATO, non affiancato: e' la regola 2
## («non e' una categoria, e' un grado») scritta in una struttura invece
## che in un commento. Se restasse, ci sarebbe ancora un posto in cui
## scrivere un bit, e prima o poi qualcuno lo scriverebbe.
func consolida_sonno(resa := 1.0) -> void:
	var r: float = clampf(resa, 0.0, 1.0) if is_finite(resa) else 1.0
	# --- FASE NREM (Non-Rapid Eye Movement) ---
	# 1. Azzeramento adenosina
	neuro["adenosina"] = 0.0
	# 2. Drenaggio cortisolo verso baseline
	var base_cort: float = float(neuro_base.get("cortisolo", NEURO_BASELINE["cortisolo"]))
	var drenaggio: float = lerpf(0.40, 0.85, r)
	neuro["cortisolo"] = move_toward(float(neuro.get("cortisolo", base_cort)), base_cort, drenaggio)
	# 3. Ricarica regolazione (autocontrollo ricaricato)
	regolazione = clampf(regolazione + lerpf(0.35, 0.85, r), 0.0, 1.0)

	# --- FASE REM (Rapid Eye Movement) ---
	# 4. Calma / reset arousal somatico
	arousal = clampf(arousal * (1.0 - CALMA), 0.0, 1.0)
	# 5. Stabilizzazione emotiva (rientro dell'umore verso neutro)
	#
	# ⚠️ **IL MOLTIPLICATORE E' 1.0, e prima era 1.3.** Quel ×1.3 era una
	# ritaratura di un sistema esistente infilata dentro un rifattoring che
	# si presentava come «fasi del sonno»: `RIENTRO_UMORE` vale 0.18 ed e'
	# il numero con cui questo gioco ha deciso, altrove e con la sua misura,
	# quanto una notte rimette a posto l'umore. Chi lo vuole cambiare lo
	# cambi li', con il suo perche'.
	var rientro: float = RIENTRO_UMORE * lerpf(0.8, 1.0, r)
	umore = move_toward(umore, 0.0, rientro)
	# Rientro verso baseline dei neurotrasmettitori
	for k in ["dopamina", "ossitocina", "serotonina", "endorfine"]:
		var base_nt: float = float(neuro_base.get(k, NEURO_BASELINE.get(k, 0.5)))
		neuro[k] = move_toward(float(neuro.get(k, base_nt)), base_nt, lerpf(0.10, 0.20, r))
	neuro["melatonina"] = 0.0


## La notte rimette a posto il corpo, non la memoria: l'attivazione cala in
## fretta, l'umore molto più piano, la pazienza torna piena.
##
## Con [param sbiadisci_marchi] false i marchi NON si spengono da soli:
## restano finché qualcosa non li spegne davvero (`visita_serena`). Serve
## a una paura sola in tutto il gioco — quella che Mochi si porta dal
## Prologo. Un marchio da -0.85 con lo sbiadimento normale sparisce in
## sette giorni: la paura del temporale se ne sarebbe andata da sé prima
## che il giocatore avesse il tempo di accorgersi che c'era, e «tornarci
## sotto finché non fa più paura» non sarebbe stato niente. Per i vicini
## resta com'è sempre stato: le loro paure si consumano col tempo.
## [param resa] e' quanto la notte ha rimesso a posto: 1.0 una notte come
## tutte, meno di 1.0 una notte che ha reso meno. Vedi `consolida_sonno`.
func passa_giorno(resa := 1.0, sbiadisci_marchi := true) -> void:
	consolida_sonno(resa)
	morsi_oggi = 0
	# i marchi non confermati si spengono piano
	if sbiadisci_marchi:
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
			"reattivita": reattivita, "abitudine": abitudine,
			"neuro": neuro.duplicate(), "carico": carico}


func load(d: Dictionary) -> void:
	arousal = float(d.get("arousal", 0.0))
	umore = float(d.get("umore", 0.0))
	regolazione = float(d.get("regolazione", 1.0))
	attese = (d.get("attese", {}) as Dictionary).duplicate()
	marchi = (d.get("marchi", {}) as Dictionary).duplicate(true)
	# ⚠️ `reattivita` e `abitudine` NON si rileggono: sono DERIVATE dai tratti
	# (`riproietta`), e rileggerle dal disco le congelava per sempre — un
	# salvataggio vecchio riportava una reattivita' che non corrispondeva piu'
	# a quella persona. Si continuano a scrivere in `save()` come diagnostica.
	# ⚠️ IL CARICO SI RILEGGE — è la cosa lenta, e senza di lui una brutta
	# stagione sparirebbe a ogni caricamento. Un salvataggio di ieri non ce
	# l'ha e risponde 0.0, che è esattamente il gioco di prima: nessuna
	# migrazione.
	carico = clampf(float(d.get("carico", 0.0)), 0.0, 1.0)
	if not is_finite(carico):
		carico = 0.0
	var n_salvato: Dictionary = d.get("neuro", {})
	neuro = NEURO_BASELINE.duplicate()
	for k in n_salvato:
		neuro[k] = float(n_salvato[k])


# =========================================================== L'INTRECCIO

## Il ponte verso il cuore, cercato UNA volta e ricordato. `null` vuol dire
## «non c'è», e allora non si riprova a ogni fotogramma: con ventotto vicini a
## 60 Hz un `has_method` fallito milleseicento volte al secondo è un costo
## vero per una risposta che non cambierà mai.
## L'ordine dei cinque tratti come li aspetta il cuore. Fonte unica di questo
## lato del ponte.
const ORDINE_TRATTI := ["codardia", "grinta", "lealta", "ambizione", "orgoglio"]

## ⚠️ I TRATTI CON CUI IL CORPO E' STATO PROIETTATO L'ULTIMA VOLTA — non
## quelli di NASCITA. `setup()` ci mette quelli del DNA, `riproietta()` ci
## mette quelli DERIVATI: e' l'unico lettore (`_tratti_vettore()`) ad avere
## bisogno del carattere di ADESSO, perche' da li' passa l'accoppiamento
## della chimica. Resta non persistito: si ricostruisce a ogni caricamento
## da `Animo.setup(dna)` piu' `Animo.load()`, che finisce con
## `_ricalcola_deriva()` — cioe' con una riproiezione.
var _tratti := {}

## ⚠️ **IL CARICO, 0..1 — ed è PERSISTITO.** È la cosa lenta: quello che resta
## addosso quando una brutta stagione ha smesso di essere una brutta giornata.
## Sta in GDScript e non nel C++ perché **si salva**, ed è la regola che questo
## progetto applica da sempre («due case sullo stesso dato salvato è il guasto
## che le fonti uniche vietano»).
var carico := 0.0

static var _ecs_intreccio = null
static var _ecs_cercato := false


## ⚠️ **IL PONTE, E LA RICERCA STA QUI E NON DENTRO IL PASSO.**
##
## Alla prima stesura la ricerca viveva dentro `_intreccio_passo`, e chi
## chiedeva `phi()` o `dove_si_spezza()` **prima** che quella mente avesse
## fatto un passo riceveva zero — o un array vuoto — **in silenzio**. Cioè le
## due funzioni che esistono per far VEDERE la mente rispondevano «niente»
## proprio a chi si era limitato a guardarla: misurato, cinque vicini su
## cinque e cinque livelli di tensione su cinque.
##
## È la forma piccola del difetto pagato nove volte: un dato calcolato e un
## lettore che non lo riceve mai.
static func _ponte():
	if not _ecs_cercato:
		_ecs_cercato = true
		if ClassDB.class_exists("EcsMondo"):
			var n = ClassDB.instantiate("EcsMondo")
			if n != null:
				if n.has_method("intreccio_passo"):
					_ecs_intreccio = n
				else:
					# ⚠️ **UN `EcsMondo` È UN `Node`, NON UN `RefCounted`.**
					# Non è contato per riferimento e non sta nell'albero:
					# lasciarlo cadere non lo libera — resta appeso per tutta
					# la vita del processo col suo `Registro` (l'`entt::registry`
					# e le tre tarature) allocato nel costruttore.
					# Questo ramo si imbocca quando il binario è più VECCHIO
					# del metodo, cioè esattamente quando qualcuno sta provando
					# una GDExtension non ricompilata — e lì un oggetto appeso
					# è l'ultima cosa che aiuta a capire cosa non va.
					# La cura è strutturale: non c'è nessun cammino in cui un
					# `EcsMondo` istanziato qui possa restare senza padrone.
					n.free()
	return _ecs_intreccio


## Vero se il passo l'ha fatto l'intreccio. Falso = il chiamante faccia quello
## che faceva ieri.
##
## ⚠️ **`kappa` È LA STRETTA DA STRESS, e la porta è il cortisolo di ADESSO.**
## È la riga che rende Φ una misura di questa mente in questo momento invece
## che una proprietà di una tabella: sotto tensione l'accoppiamento si
## restringe, e MISURATO l'informazione integrata cala di 3,4 volte fra un
## corpo calmo e uno teso. «La mente si restringe» smette di essere una
## metafora e diventa un numero che si può far crollare.
func _intreccio_passo(dt: float, prod: Dictionary) -> bool:
	if _ponte() == null:
		return false
	var lam := PackedFloat64Array()
	var ber := PackedFloat64Array()
	var cur := PackedFloat64Array()
	for tipo in NEURO_TRASMETTITORI:
		var l: float = float(NEURO_DECADIMENTO.get(tipo, 0.05))
		var b: float = float(neuro_base.get(tipo, NEURO_BASELINE.get(tipo, 0.0)))
		var p: float = float(prod.get(tipo, 0.0))
		if l <= 0.0:
			return false      # il ramo senza decadimento resta di chi l'aveva
		lam.append(l)
		# il BERSAGLIO di oggi, canale per canale: `B + Π/λ`. È lo stesso
		# punto fisso di prima — ed è quello che l'intreccio promette di non
		# spostare.
		ber.append(b + p / l)
		cur.append(float(neuro.get(tipo, b)))
	var tr := _tratti_vettore()
	var kappa: float = _kappa()
	var fuori: PackedFloat64Array = _ecs_intreccio.call(
			"intreccio_passo", lam, tr, dt, kappa, ber, cur)
	if fuori.size() != NEURO_TRASMETTITORI.size():
		return false
	var i := 0
	for tipo in NEURO_TRASMETTITORI:
		var v: float = fuori[i]
		if not is_finite(v):
			return false
		neuro[tipo] = clampf(v, 0.0, 1.0)
		i += 1
	return true


## L'INFORMAZIONE INTEGRATA di questa mente, adesso. In nat.
##
## ⚠️ **Zero non è un guasto: è la risposta giusta per la chimica di ieri.**
## Sette canali che non si parlano hanno Φ = 0 per teorema, non per
## approssimazione — ed è il confronto che dà un senso al numero.
func phi(dt := 0.05) -> float:
	if _ponte() == null:
		return 0.0
	var lam := PackedFloat64Array()
	for tipo in NEURO_TRASMETTITORI:
		lam.append(float(NEURO_DECADIMENTO.get(tipo, 0.05)))
	return float(_ecs_intreccio.call("intreccio_phi", lam,
			_tratti_vettore(), dt, _kappa()))


## I cinque tratti nell'ordine di `ChibiDNA`. ⚠️ L'ordine è una convenzione
## condivisa col C++ (`T_CODARDIA`… in `intreccio.cpp`): un test lo lega, o
## due elenchi scritti a mano divergerebbero in silenzio e il carattere
## tingerebbe l'arco sbagliato senza che nessuno se ne accorga.
func _tratti_vettore() -> PackedFloat64Array:
	var tr := PackedFloat64Array()
	for nome in ORDINE_TRATTI:
		tr.append(clampf(float(_tratti.get(nome, 0.5)), 0.0, 1.0))
	return tr


## LA STRETTA DA STRESS: quanto il cortisolo di adesso restringe
## l'accoppiamento. È la riga che rende Φ una misura di questa mente in
## questo momento — e non di una tabella uguale per tutti e per sempre.
func _kappa() -> float:
	return clampf(1.0 - 0.9 * clampf(float(neuro.get("cortisolo", 0.0)),
			0.0, 1.0), 0.0, 1.0)


## ⚠️⚠️ **E OGGI NESSUNO LA CHIAMA — né questa né `phi()`.** Verificato il
## 2026-09-22 su tutto `scenes/` e `systems/`: le due funzioni compaiono solo
## nella propria definizione e nei test. Sono una LETTURA, non una meccanica
## (non muovono un corpo, non decidono niente), e questo le rende meno gravi
## del carico e di `Osservare.gd` — che erano meccaniche promesse e spente, e
## che nella stessa tornata hanno avuto il loro lettore. Ma finché non c'è una
## superficie che le mostra, quello che questo commento racconta è una cosa
## che il giocatore non vede mai: chi legge non lo creda già successo.
##
## ⚠️ **DOVE SI SPEZZEREBBE QUESTA MENTE, adesso.** I nomi dei canali, divisi
## nei due lati della partizione minima: `[["cortisolo", …], ["dopamina", …]]`.
## Vuoto se il sostrato non regge — e vuoto è anche la risposta onesta per la
## chimica diagonale, che si spezza dappertutto allo stesso modo perché non è
## attaccata da nessuna parte.
##
## ⚠️ **E NON È Φ.** Φ è un numero ordinato: appena lo si vede si vuole farlo
## salire, e una mente diventa un punteggio da ottimizzare. Una partizione non
## ha un verso — non esiste una partizione «migliore» — quindi non c'è niente
## da massimizzare. Dice una cosa sola: *se questa mente cedesse, cederebbe
## QUI.* E cambia mentre la si guarda, perché cambia con la tensione.
func dove_si_spezza(dt := 0.05) -> Array:
	if _ponte() == null or not _ecs_intreccio.has_method("intreccio_mip"):
		return []
	var lam := PackedFloat64Array()
	for tipo in NEURO_TRASMETTITORI:
		lam.append(float(NEURO_DECADIMENTO.get(tipo, 0.05)))
	var lati: PackedInt32Array = _ecs_intreccio.call("intreccio_mip", lam,
			_tratti_vettore(), dt, _kappa())
	if lati.size() != NEURO_TRASMETTITORI.size():
		return []
	var a: Array = []
	var b: Array = []
	var i := 0
	for tipo in NEURO_TRASMETTITORI:
		if lati[i] == 0:
			a.append(tipo)
		else:
			b.append(tipo)
		i += 1
	return [a, b]


## ⚠️ **IL PASSO DEL CARICO.** Lento apposta, e con l'isteresi nelle costanti
## di tempo: tre giornate per caricarsi, trenta per scaricarsi da solo.
##
## `atti` sono i gesti PORTATI A TERMINE nell'intervallo — non il conforto
## ricevuto: la *behavioural activation* funziona attraverso il fare, ed è il
## trattamento con più evidenza per la depressione. È anche la ragione per cui
## l'uscita non è «stargli vicino»: è dargli qualcosa da finire.
func passo_carico(dt: float, atti := 0.0) -> void:
	if not is_finite(dt) or dt <= 0.0:
		return
	dt = minf(dt, NEURO_PASSO_MAX)
	if not is_finite(carico):
		carico = 0.0
	var m: float = -clampf(umore, -1.0, 1.0)
	# la spinta: zero sotto M0 (la zona morta), satura sopra M1
	var spinta: float = smoothstep(CARICO_M0, CARICO_M1, m)
	var prima := carico
	if spinta > carico:
		carico += (spinta - carico) * (dt / CARICO_TAU_SU)
	else:
		var tasso: float = 1.0 / CARICO_TAU_GIU
		if is_finite(atti) and atti > 0.0:
			tasso += CARICO_PER_ATTO * atti / maxf(dt, 1e-6)
		carico -= carico * minf(1.0, tasso * dt)
	carico = clampf(carico, 0.0, 1.0)
	if not is_finite(carico):
		carico = prima
	# ⚠️ **E IL RIPOSO NON SI RIFÀ QUI.** C'era
	# `neuro_base = NEURO_BASELINE.duplicate(); applica_tinta(neuro_base)`, e
	# quelle due righe **cancellavano i bisogni**: `Animo.sincronizza_neuro`
	# scrive cinque canali su sette a partire dai drive, e ripartire dalla
	# baseline li buttava tutti a ogni passo. È il difetto che la testata di
	# `sincronizza_neuro` documenta di aver già pagato una volta — rifatto un
	# piano più giù, e da me.
	#
	# Il carico entra nel mondo da `applica_tinta`, che è dove entra anche la
	# tinta del carattere, e a chiamarla è `sincronizza_neuro` **dopo** aver
	# scritto i bisogni. Rifare il punto di riposo è quindi mestiere di chi
	# possiede i bisogni: `Animo.passo_carico` lo fa in coda, in un posto solo.


## Quanto pesa il carico su questa mente, adesso: 0 (niente) .. 1 (pieno).
## ⚠️ È una LETTURA e non un'etichetta. Il gioco non dice mai «è depressa»:
## dice quanto è carico, e il resto si vede addosso al corpo.
func quanto_carico() -> float:
	return clampf(carico, 0.0, 1.0) if is_finite(carico) else 0.0
