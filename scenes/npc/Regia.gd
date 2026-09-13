extends RefCounted

## LA REGIA — quando un corpo ha qualcosa da dire, e soprattutto quando NO.
##
## `Gesti.gd` sa COME si dice una cosa col corpo; `Visitor.gd` la indossa;
## `Visitors.gd` fa l'usciere. Qui c'è l'unica domanda che nessuno dei tre
## può rispondere da solo: **quale momento della vita interiore di un vicino
## vale il palco, e quanto spesso.**
##
## Ed è la domanda pericolosa. Un repertorio di gesti bellissimi recitati a
## caso non è una persona: è un mimo. Il metro non è «quanti gesti si
## vedono» — è **quanti gesti il giocatore sa ricondurre a qualcosa**.
##
## ────────────────────────────────────────────────────────────────────────
## LA REGOLA CHE VIENE PRIMA DI TUTTE: IL SILENZIO È IL COMPORTAMENTO NORMALE
## ────────────────────────────────────────────────────────────────────────
##
## Un gesto che il giocatore non sa attribuire non attenua l'effetto: **lo
## INVERTE**. È la stessa regola del taccuino del Gufo («si afferma solo ciò
## che si è VISTO») e della ricevuta della Fase 5, e il danno che fa è
## permanente — da quel momento il giocatore non riconosce più NESSUNA
## conseguenza vera, comprese quelle che gli sono costate mesi.
##
## Perciò questo file è fatto quasi tutto di NO, e ogni no ha il suo nome:
##
##   1. **non c'è un'occasione** — nessuno dei sette momenti qui sotto è
##      capitato. È il caso normale, ed è la maggioranza schiacciante del
##      tempo di gioco.
##   2. **il palco è ancora caldo** — `attesa_di()`: quanta parte del
##      periodo del villaggio dev'essere passata perché QUESTA occasione
##      valga il disturbo. Non è una coda: chi arriva presto muore.
##   3. **quel vicino ha appena parlato** — il riposo per persona
##      (`Visitors.GESTO_RIPOSO`): un villaggio con un attore solo è un
##      teatrino.
##   4. **il giocatore è lontano** — oltre `Visitors.GESTO_RAGGIO` non si
##      vede niente, e un gesto che nessuno vede non è mezzo gesto: è zero.
##   5. **manca l'ANCORA** — `ancora_valida()`: l'occasione non ha una cosa
##      nel mondo a cui il giocatore possa legarla. Silenzio.
##   6. **il corpo non è nelle condizioni** — `Visitor.gesto_libero()` più
##      le precondizioni del gesto (un Punto vuole un passo da spezzare).
##   7. **c'è una scena scritta in corso** — il concerto, il congedo, il
##      nascondino, il concertino, la prima parola di un cucciolo,
##      l'appuntamento delle Promesse. Lì il corpo è di chi l'ha scritta.
##
## ────────────────────────────────────────────────────────────────────────
## NESSUNA CASA NUOVA
## ────────────────────────────────────────────────────────────────────────
##
## Tutte e sette le occasioni sono momenti che il gioco **simulava già** e
## che non aveva un corpo. Non c'è un contatore nuovo, non c'è un campo nuovo
## nel salvataggio, non c'è un dado. Il vocabolario non può far succedere le
## cose più spesso: può solo renderle visibili.
##
##   | occasione          | dove vive il dato, e da SEMPRE                |
##   |--------------------|-----------------------------------------------|
##   | `ha_visto`         | il grafo dei ricordi (src/grafo_ricordi.h),   |
##   |                    | via `Percezione._testimonia`                  |
##   | `era_per_me`       | `R_SU_DI_ME`, la sola asimmetria del grafo    |
##   | `se_lo_tiene`      | `EcsMondo.cosa_da_ricordare` (la promozione)  |
##   | `ha_dedotto`       | il grafo delle deduzioni (Fase 5)             |
##   | `si_e_trattenuto`  | `Limbico.trattieni()` che torna TRUE          |
##   | `quel_posto_no`    | `Limbico.evita()` (i marchi)                  |
##   | `ah_sei_tu`        | `Limbico.rivaluta()` dopo un sussulto         |
##   | `ci_si_trova`      | `Cricche.ritrovo_vivo()`, derivato dalla      |
##   | `ci_sei_anche_tu`  | co-presenza che `_chats` costruiva e buttava  |
##
## ⚠️ Le ultime due valgono la regola nella sua forma più forte: **il
## villaggio non si incontra una volta di più** per averle. Chi si ritrova ci
## andava comunque, all'ora in cui ci va sempre, con quella persona lì;
## l'unica cosa che cambia è che adesso, ogni tanto, lo si VEDE.
##
## E i due LIVELLI (il capo che pende, la coda somatica) leggono `Limbico`
## come lo leggeva già `stato_corpo()`.

const GESTI := preload("res://scenes/npc/Gesti.gd")


# =========================================================================
# LE SETTE OCCASIONI
# =========================================================================
#
# `attesa` è la frazione del periodo del villaggio (`Visitors.GESTO_PASSO`)
# che dev'essere trascorsa dall'ultimo gesto perché questa occasione possa
# prendere il palco. **Uno vuol dire «aspetta tutto il giro»; zero vuol dire
# «appena il corpo di prima ha finito».**
#
# ⚠️ **PERCHÉ NON UNA CODA A PRIORITÀ, che è la prima idea che viene.** Una
# coda consegnerebbe il gesto DOPO il suo momento, e un gesto separato dalla
# sua premessa è esattamente il guasto che questo file esiste per impedire —
# lo stesso motivo per cui una deduzione vale UN'occasione, quella subito
# dopo la sua ricevuta. Chi perde muore in silenzio.
#
# ⚠️ **E PERCHÉ NON PRIMO-ARRIVATO-PRIMO-SERVITO, che è quello che c'era.**
# `ha_visto` capita a OGNI gesto del giocatore che qualcuno veda: misurato
# nel villaggio vero, 383 richieste in cinque minuti contro le zero-o-una di
# `ha_dedotto`. Con un gettone solo e nessun ordine, l'occasione più
# frequente si prende il palco sempre — e le cinque che valgono di più non
# si vedono mai. Un usciere che serve chi bussa più forte non è un usciere.
#
# L'ORDINE NON È GUSTO. Sta scritto in due colonne che si misurano:
# **quanto spesso quell'occasione capita** (più è rara, meno deve aspettare)
# e **quanto il giocatore può ricondurla a sé** (più è vicino e più il gesto
# è suo, meno deve aspettare). Le due tirano nella stessa direzione, e per
# una ragione sola: le occasioni frequenti di questo gioco sono quelle in
# cui il giocatore fa una cosa qualunque a nove metri da qualcuno, e le rare
# sono quelle in cui gli succede qualcosa addosso.
const OCCASIONI := {
	# HA VISTO un gesto di Mochi, e nel grafo è nato un ricordo NUOVO.
	# L'occasione più frequente del gioco, e la più debole: il giocatore ha
	# già la sua ricevuta (la testa che si gira, `Percezione`). Paga il
	# periodo intero, ed è giusto che sia lei a pagarlo.
	"ha_visto": {"frase": "premessa", "attesa": 1.00},
	# ERA PER ME. Lo stesso gesto, ma fatto a lui: un dono, un piatto. È
	# `R_SU_DI_ME`, l'unica asimmetria fra persone che il grafo dei ricordi
	# conosce (e non è un giudizio: è «quella cosa lì l'hai fatta a me»).
	# Il giocatore è in faccia, e sa esattamente cos'ha appena fatto.
	"era_per_me": {"frase": "premessa", "attesa": 0.35},
	# SE LO TIENE: il ricordo diventa permanente (`cosa_da_ricordare` →
	# `VillagerBrain.remember`). Una al giorno per vicino, e solo per quello
	# che ha visto coi propri occhi. È l'unica occasione da «pensiero» che
	# **funziona senza il modello linguistico**, cioè per tutti.
	"se_lo_tiene": {"frase": "pensiero", "attesa": 0.30},
	# HA DEDOTTO: la ricevuta di una deduzione della Fase 5. Al massimo una
	# ogni cinque minuti per vicino (`Pensatoio.RIPOSO`), e con una
	# conseguenza vera dietro (il mestiere che cambia). Se questa perde il
	# palco, il giocatore vede la conseguenza senza la premessa.
	"ha_dedotto": {"frase": "pensiero", "attesa": 0.15},
	# SI È TRATTENUTO, e ce l'ha fatta. Mochi è a meno di 2,6 m e quel
	# vicino ha qualcosa da rinfacciarle: non c'è momento più attribuibile
	# di questo, ed era il caso COMUNE senza corpo (il gioco reagiva solo al
	# morso fallito).
	"si_e_trattenuto": {"frase": "rinuncia", "attesa": 0.45},
	# L'HA RILETTA. Stesso identico momento del morso della lingua — Mochi a
	# meno di 2,6 m, e quel vicino ha qualcosa da rinfacciarle — ma questa
	# volta nei suoi ricordi c'e' abbastanza roba bella da reggere una
	# lettura piu' benevola, e allora non c'e' niente da tenere dentro.
	#
	# ⚠️ **ASPETTA UN FILO MENO DI `si_e_trattenuto`, e la ragione e' la
	# colonna della RARITA'.** Sull'attribuibilita' pareggiano (e' lo stesso
	# istante, la stessa distanza, la stessa cosa appena fatta dal giocatore);
	# sulla frequenza no — trattenersi lo puo' fare chiunque abbia un torto,
	# rileggere solo chi ha anche un passato che lo regge. E quel passato ce
	# l'ha messo il giocatore, il che la rende **la piu' sua** delle due.
	"ha_riletto": {"frase": "rilettura", "attesa": 0.40},
	# QUEL POSTO LÌ, NO. Un marchio del Limbico gli fa cambiare idea. Capita
	# solo a chi ha imparato a temere qualcosa, e solo quando ci stava
	# andando.
	"quel_posto_no": {"frase": "evitamento", "attesa": 0.45},
	# AH… SEI TU. Il sussulto che si scioglie nel riconoscimento: la strada
	# veloce e la strada lenta, a 0,4 s di distanza. Il giocatore è a meno
	# di 3,2 metri, ha appena fatto saltare qualcuno, e un istante dopo
	# quello lo riconosce. **È il momento più attribuibile che questo gioco
	# abbia**, e per questo aspetta quasi niente.
	"ah_sei_tu": {"frase": "sollievo", "attesa": 0.10},
	# CI SI TROVA. Due che da giorni finiscono nello stesso angolo alla
	# stessa ora ci stanno tornando, e a qualche metro l'uno dall'altro si
	# fermano — prima uno, un battito dopo l'altro. **È l'occasione più rara
	# del gioco**: una al giorno in tutto il villaggio, e mai due volte sulla
	# stessa coppia dentro la settimana.
	#
	# ⚠️ **PAREGGIA CON «ah… sei tu», E NON LA SUPERA.** Sulla colonna della
	# rarità la batte di parecchio; su quella dell'attribuibilità no — «ah…
	# sei tu» è una cosa che il giocatore ha appena fatto lui, a tre metri,
	# mezzo secondo fa, mentre questa gliela si può ricondurre solo attraverso
	# giorni (dove ha posato un letto, dove ha posato una panchina). Le due
	# colonne tirano in direzioni opposte, e **a pari merito non si elegge**,
	# che è la stessa regola con cui questo sistema sceglie una cricca.
	#
	# E non le serve vincere: ha già un tetto suo, durissimo, che nessun'altra
	# occasione ha — una al giorno. Chi ha una scorta non ha bisogno anche
	# della precedenza.
	"ci_si_trova": {"frase": "incontro", "attesa": 0.10},
	# CI SEI ANCHE TU. Uno sta arrivando al posto in cui si trova con
	# qualcuno, alla sua ora, e lì c'è MOCHI. Si ferma un momento, e poi va.
	# È lo stesso Punto molle di `ha_visto`, ma l'ancora è il giocatore e la
	# premessa è che il giocatore *è nel loro posto* — cioè una cosa che ha
	# fatto lui, e che può rifare domani alla stessa ora.
	"ci_sei_anche_tu": {"frase": "premessa", "attesa": 0.45},
}


## La frase di un'occasione, "" se l'occasione non esiste. Il nome della
## frase è quello di `Gesti.FRASI`: una sola tabella, e un test le lega.
static func frase_di(occasione: String) -> String:
	var v: Dictionary = OCCASIONI.get(occasione, {})
	return str(v.get("frase", ""))


static func attesa_di(occasione: String) -> float:
	var v: Dictionary = OCCASIONI.get(occasione, {})
	return float(v.get("attesa", 1.0))


## IL PALCO È LIBERO per questa occasione? `residuo` è quanto manca a un
## orologio, `passo` è quanto dura quell'orologio intero. Pura: si prova
## senza villaggio.
##
## ⚠️ **DUE SCARSITÀ, UNA REGOLA, UN NUMERO SOLO.** Questa funzione ha due
## chiamanti e sono due domande diverse: il **gettone del villaggio** («si
## vede un gesto per volta, e non troppo spesso») e il **riposo della
## persona** («non sempre lo stesso vicino»). Sono due orologi con due
## durate — dodici secondi e cinque minuti — e la stessa aritmetica: quanto
## deve essersene consumato perché QUESTA occasione valga il disturbo.
##
## Averne una sola è ciò che chiude la fame che questo file esiste per
## chiudere. MISURATO: col palco ordinato e il riposo no, i **439 no più
## numerosi erano del riposo** — `ha_visto` bussa mille volte, brucia il
## riposo di chiunque passi, e le occasioni rare trovano sempre gente che
## «ha appena parlato». Un ordine applicato a metà non è un ordine.
##
## L'occasione sconosciuta paga l'orologio intero — il degrado va verso il
## silenzio, che è il comportamento normale.
static func palco_libero(occasione: String, residuo: float, passo: float) -> bool:
	if not OCCASIONI.has(occasione):
		return false
	return residuo <= passo * (1.0 - attesa_di(occasione)) + 0.0001


## COSA DICE UNO SGUARDO. È l'unica regola di questo file che TOGLIE
## occasioni invece di ordinarle, ed è la più importante delle sette.
##
## ⚠️ **L'UNITÀ È IL RICORDO, NON IL GESTO** — e non è una regola nuova: è
## quella che `Visitor.guarda_gesto` applica da sempre alla testa. Nel grafo
## dei ricordi gesti uguali e ravvicinati NON fanno ricordi nuovi: fondono
## in uno solo che si rinfresca e conta `quante` (`FINESTRA_FUSIONE`,
## src/grafo_ricordi.h). Il ventesimo pezzo di un sentiero non è una cosa
## vista in più — è la stessa cosa, ancora.
##
## Senza questa riga il corpo si fermava per il quattordicesimo sasso di un
## sentiero esattamente come per il primo, e siccome il gettone lo prende
## chi bussa per primo, il gesto usciva **quasi sempre in mezzo a una
## raffica monotona** invece che sul gesto singolo che si legge. Misurato:
## il 79% delle richieste erano ripetizioni.
##
## La risposta arriva da `guarda_gesto`, che la calcola già e adesso la
## restituisce: **non si ricalcola qui**, o la finestra di fusione avrebbe
## due letture e un giorno divergerebbero (è la lezione delle tabelle
## gemelle, pagata tre volte in questo progetto).
static func occasione_dello_sguardo(ricordo_nuovo: bool, per_me: bool) -> String:
	if not ricordo_nuovo:
		return ""          # la raffica: la testa si rialza, il corpo no
	return "era_per_me" if per_me else "ha_visto"


## L'ANCORA. Un'occasione senza un posto nel mondo a cui legarla non si
## recita: è la regola 5 del silenzio, scritta in una riga.
##
## `Vector3.ZERO` è il modo in cui tutto questo progetto dice «non lo so»
## (`Visitors._luogo_posizione`, `EcsMondo.dove` che ripiega su casa), e qui
## «non lo so» è sempre un no. Le occasioni la cui ancora è il GIOCATORE —
## si è trattenuto, ah sei tu — non passano di qui: il giocatore è a meno di
## tre metri per costruzione, ed è l'ancora più forte che ci sia.
static func ancora_valida(posto: Vector3, casa: Vector3) -> bool:
	if posto == Vector3.ZERO:
		return false
	# il ripiego di `EcsMondo.dove()` è CASA PROPRIA: vuol dire «di quella
	# cosa non mi resta abbastanza», e guardarsi la porta di casa non
	# racconta niente a nessuno
	return posto.distance_to(casa) > 0.25


# =========================================================================
# I DUE LIVELLI — che non prendono il palco, e hanno la loro scarsità
# =========================================================================

## Sotto questa forza di trattenersi il capo comincia a pendere.
const CAPO_REGOLAZIONE := 0.45
## …e sotto questo umore pure. È la stessa soglia con cui `Limbico.
## stato_corpo()` dice «di malumore» da sempre: non è un numero nuovo, è
## quello, e un test lo lega.
const CAPO_UMORE := -0.35

## «CI STO PENSANDO» — il rollio del capo, e le sue TRE cause.
##
## ⚠️ **TRE E NON UNA, ed è una regola non un ornamento.** «Nessun gesto è
## una coordinata»: un gesto che mappa uno-a-uno su una variabile interna è
## un cruscotto, e un giocatore attento dopo tre ore ha in testa la legenda
## e legge il villaggio invece di viverci. Con tre cause diverse — non ho
## più forza di trattenermi · sono di malumore da giorni · ho una cosa in
## testa che non ho ancora detto — il capo storto dice «a lui sta
## succedendo qualcosa», mai QUALE leva. È lo stesso argomento del
## rallentando, che è indecodificabile per costruzione.
##
## E sono tre cose che DURANO: un livello non si accende su un evento.
static func capo_pensa(regolazione: float, umore: float, rimugina: bool) -> bool:
	return regolazione < CAPO_REGOLAZIONE or umore < CAPO_UMORE or rimugina


# =========================================================================
# LA GRAMMATICA È QUELLA DI `Gesti`, E QUESTA È LA SUA UNICA GIUNTURA
# =========================================================================

## Ogni occasione nomina una frase che esiste davvero. Non è una comodità:
## una frase scritta storta qui non fallisce — **smette di parlare, in
## silenzio**, ed è il guasto che la tabella delle parole del cielo aveva.
## Lo si chiama dal test, e nessuno in partita.
static func frasi_coerenti() -> bool:
	for o in OCCASIONI:
		if not GESTI.FRASI.has(frase_di(str(o))):
			return false
	return true
