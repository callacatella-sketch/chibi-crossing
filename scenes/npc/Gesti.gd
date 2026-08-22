extends RefCounted

## IL VOCABOLARIO DEL CORPO CHE PENSA — le buste, pure.
##
## Fino a ieri l'unico segno che un vicino avesse una vita interiore era UNA
## TESTA CHE SI GIRA per 3,2 secondi. È stata misurata, e non basta: si legge
## solo da davanti e solo da vicino, **di spalle non ha verso** (le orecchie
## si muovono tanto a destra quanto a sinistra: rapporto 1,04) e a sei metri
## — l'altezza da cui un giocatore vede un vicino mentre passa — la testa è
## venti pixel. Sette teste girate in venticinque minuti di partita.
##
## Qui vivono i GESTI che quel segno non poteva dare. Non sono pose: sono
## BUSTE, cioè funzioni esplicite del tempo, e questo file non conosce Godot
## né l'albero della scena — gli si chiede «a 0,42 secondi dall'inizio, quanto
## vale ogni canale?» e risponde. Il corpo lo mette `Visitor`.
##
## ────────────────────────────────────────────────────────────────────────
## IL CRITERIO CHE HA DECISO OGNI CANALE, e che va riletto prima di aggiungerne
## ────────────────────────────────────────────────────────────────────────
##
## «Pixel di contorno cambiati» misura la RILEVABILITÀ (è successo qualcosa),
## non la LEGGIBILITÀ (è successo *di là*). Il criterio unico è:
##
##     |maschera(+A) XOR maschera(−A)| / |maschera(A) XOR riposo|  ≥  1,6
##
## cioè: le DUE versioni opposte dello stesso gesto si distinguono FRA LORO?
## Misurato sul rig vero, quattro azimut: verticale 1,79–1,87 · scala
## 1,64–1,84 · laterale 1,60–1,79 · rollio del capo 1,65–1,79 ✅ — e **ogni
## imbardata 0,90–1,57** ❌.
##
## **CONSEGUENZA VINCOLANTE: nessun gesto porta il proprio significato su
## un'imbardata** (né della testa, né del busto, né del corpo). Un corpo di
## rivoluzione è CIECO AL SEGNO in imbardata: girarlo a destra cambia gli
## stessi pixel che girarlo a sinistra. L'imbardata resta come *contorno* (si
## nota), mai come *parola* (non si legge). Chi aggiunge un gesto qui dentro
## lo fa passare da `tools/provino_verso.gd` PRIMA di scriverlo.
##
## E le altre due misure trasversali: la **coda** vale 0–58 px (sta dentro la
## campana della testona, come le mani) → non è mai una colonna obbligatoria;
## il moto lungo l'**asse ottico** paga 4,2× → ogni `vz` vuole un socio
## isotropo.
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ BUSTE ESPLICITE E NON UN FILTRO PASSA-BASSO
## ────────────────────────────────────────────────────────────────────────
##
## Il dizionario della recita fonde OGNI canale con una sola costante (6,0 →
## 90% in 0,38 s). Va benissimo per una postura, che è uno stato d'animo che
## si posa; è la morte di un gesto, che è un EVENTO con un attacco. Il Rialzo
## vuole 46 cm/s nel primo decimo di secondo: dentro un filtro a 6,0 gli
## sarebbero arrivati cinque millimetri, e nessuno avrebbe capito perché il
## gesto «non si vede».
##
## Le buste qui sotto hanno attacco, tenuta e rilascio DIVERSI fra loro, e in
## un caso (il Raccolto) il rilascio è più lento dell'attacco — da una
## rinuncia si esce piano. Il prezzo è che un gesto TRONCATO a metà
## salterebbe: per quello c'è la rampa di spegnimento (`SPEGNI`), che è la
## rete e non un secondo filtro.
##
## ────────────────────────────────────────────────────────────────────────
## MAI «POSA + ADESIVO»
## ────────────────────────────────────────────────────────────────────────
##
## Ogni busta porta il suo micro-movimento, e nessuno è un `sin()` puro: gli
## orologi sono a coppie e incommensurabili (0,83 e 2,17 rad/s: il rapporto è
## irrazionale, la figura non si richiude mai), l'attacco e il rilascio non
## sono simmetrici, e le molle hanno l'overshoot. Un `sin()` puro si smaschera
## in due cicli — e questi gesti il giocatore li vedrà centinaia di volte.

# =========================================================================
# I CANALI
# =========================================================================
#
# `r` NON è un canale del rig: è il moltiplicatore del RITMO, cioè quanto
# cammina il corpo (moltiplica `Visitor._move_gait`, che ha un solo
# consumatore). Tutti gli altri si sommano al rig, tranne `sy` che è un
# FATTORE moltiplicativo sulla scala del corpo (1,0 = riposo).
#
#   vx   busto: + curva in avanti, − petto in fuori     (_vis.rotation.x)
#   vy   il corpo su e giù                              (_vis.position.y)
#   vz   avanti/indietro: − è AVANTI (il rig guarda −Z) (_vis.position.z)
#   vrz  il corpo che si inclina di lato                (_vis.rotation.z)
#   px   il corpo che si sposta di LATO                 (_vis.position.x)
#   sy   il fattore verticale della scala del corpo     (_corpo.scale)
#   hx   mento: + giù, − su                             (_head.rotation.x)
#   hy   imbardata della testa                          (_head.rotation.y)
#   hz   ROLLIO del capo                                (_head.rotation.z)
#   hpy  la testa che affonda nelle spalle              (_head.position.y)
#   ear  orecchie: + giù, − su                          (_c_ears.rotation.x)
#   ear_dx quanto in PIÙ l'orecchio destro (l'asimmetria)
#   ax0/ax1 le due braccia                              (_c_arms.rotation.x)
#   tail la coda: − si irrigidisce                      (_tail_p.rotation.x)
const CANALI := ["r", "vx", "vy", "vz", "vrz", "px", "sy", "hx", "hy", "hz",
		"hpy", "ear", "ear_dx", "ax0", "ax1", "tail"]

## I canali a riposo. `r` e `sy` riposano a UNO (sono moltiplicatori), tutti
## gli altri a zero — ed è la ragione per cui esiste questa funzione invece di
## un dizionario vuoto: un `sy` dimenticato a 0.0 schiaccerebbe il corpo a
## un foglio di carta, e sarebbe la prima cosa che si vede.
static func riposo() -> Dictionary:
	return {"r": 1.0, "vx": 0.0, "vy": 0.0, "vz": 0.0, "vrz": 0.0, "px": 0.0,
			"sy": 1.0, "hx": 0.0, "hy": 0.0, "hz": 0.0, "hpy": 0.0,
			"ear": 0.0, "ear_dx": 0.0, "ax0": 0.0, "ax1": 0.0, "tail": 0.0}


# =========================================================================
# LE DUE METÀ — e perché due ampiezze diverse NON sono un'asimmetria
# =========================================================================
#
# Un chibi ha due orecchie e due braccia, e in questo file le due metà non
# devono fare MAI la stessa cosa: due arti che si muovono sullo stesso filo
# sono un manichino, e un manichino il giocatore lo riconosce senza sapere
# perché. La regola sembra ovvia, e la prima stesura l'ha rotta in **quattro
# punti su sette** — sempre con lo stesso errore, che è quello che si fa
# credendo di averla rispettata: **due quote diverse sullo stesso orologio.**
#
# ⚠️ Se la destra vale sempre `k` volte la sinistra — 0,28 contro 0,22, per
# tutta la durata del gesto — le due partono nello stesso fotogramma,
# arrivano nello stesso fotogramma, e in mezzo hanno la stessa identica
# forma. Quello che si legge non è «due orecchie»: è «un orecchio più
# lungo». Le parti di un manichino sono esattamente questo — legate da
# costanti.
#
# MISURATO (`tools/misura_asimmetrie.gd`) col **RESIDUO DI FORMA**: si cerca
# la costante che meglio sovrappone la destra alla sinistra, e si guarda
# quanto resta, in frazione dell'ampiezza. Zero = un filo solo, e nessuna
# differenza di quota può salvarlo. (Il numero è quello del corpo PEGGIORE su
# sedici genomi: la garanzia è per ogni vicino, non per il vicino medio.)
#
#                              PRIMA                    DOPO
#     il Punto · orecchie      48,5 %  ·  33 ms  ✅     48,5 %  ·  33 ms
#     il Rialzo · orecchie     79,7 %  ·  83 ms  ✅     79,7 %  ·  83 ms
#     il Raccolto · orecchie    0,0 %  ·   0 ms  ❌     17,4 %  · 117 ms
#     il Raccolto · braccia     0,0 %  ·   0 ms  ❌     16,3 %  · 167 ms
#     il Largo · orecchie       0,0 %  ·   0 ms  ❌     32,9 %  · 100 ms
#     il Largo · braccia        0,0 %  ·   0 ms  ❌     33,0 %  · 117 ms
#     la Coda · orecchie        0,0 %  ·   0 ms  ❌      6,5 %  · 500 ms
#     la Coda · braccia         0,0 %  ·   0 ms  ❌      4,1 %  · 500 ms
#
# ⚠️ E i due LIVELLI restano più bassi degli altri, **ed è strutturale**: un
# livello non ha un attacco. Il residuo di un gesto viene dalla busta (una
# metà arriva dopo); un livello ha solo un'ampiezza che decade, e ritardare
# un esponenziale non ne cambia la forma di un capello (`a(t−r) = a(t)·e^{r/τ}`
# è una COSTANTE). Là l'unica asimmetria possibile è il micro-movimento, e il
# micro-movimento è piccolo per definizione: più grosso sarebbe un tremore,
# che è un'altra parola.
#
# La cura è **un secondo orologio**, e ha tre pezzi che servono tutti e tre:
#
#  1. **IL RITARDO.** La metà che segue parte dopo. Da solo basta su un
#     attacco ripido (il Punto ne usa 40 ms su una salita di 50: si vedono);
#     su un attacco lento non basta — 70 ms dentro una salita di 900 sono un
#     errore di arrotondamento, e infatti il residuo resterebbe sotto il 3%.
#  2. **LA COSTANTE DI TEMPO.** La metà che segue ha la SUA: più pigra a
#     chiudersi, più molla a riaprirsi. È l'inerzia di un orecchio floscio e
#     di un braccio che pesa, ed è l'unica cosa che si vede su una busta
#     lunga.
#  3. **IL TREMOLIO.** Dentro la TENUTA le due metà sono arrivate tutte e
#     due e ci resterebbero ferme nello stesso rapporto per due secondi: una
#     posa, cioè l'adesivo. Due orologi incommensurabili per metà — e
#     diversi fra le due — e il rapporto non è mai lo stesso due volte.
#     ⚠️ E la prova che serve non è «il rapporto cambia»: le due buste
#     CONVERGONO per tutta la tenuta, quindi il rapporto sale comunque, e
#     una deriva monotòna non è vita — è la stessa posa che arriva piano.
#     Quel che distingue un corpo da un adesivo è che il movimento **cambia
#     verso** (vedi `test_gesti._la_tenuta_non_e_una_posa`).
#
# ⚠️ **E LA METÀ CHE SEGUE RIAPRE PRIMA, NON DOPO.** La tentazione è
# dilatare il tempo di quella metà (più lenta in tutto). A fine gesto però
# la tabella torna al riposo ESATTO, e una metà rimasta indietro ci arriva
# con un salto: misurato, **0,0245 rad in un fotogramma** contro i 0,0074 di
# adesso. Chi tarda a chiudersi è il primo a mollare — si legge come «meno
# convinta», che è per giunta la cosa giusta da dire, e il residuo alla coda
# resta della metà che comanda.

## QUANTO PIGRA È LA METÀ CHE SEGUE, per QUESTO corpo. Non è mai zero:
## l'asimmetria è una regola, non un dado — il genoma decide di QUANTO, mai
## di SE. Viene dalla fase (che è del genoma, non di un `randf()`), quindi il
## vicino con l'orecchio pigro ce l'ha per sempre e venti vicini nello stesso
## prato non hanno tutti la stessa pigrizia.
static func pigrizia(fase: float) -> float:
	return 0.85 + 0.15 * sin(fase * 2.3 + 0.7)


## IL TREMOLIO DI UNA METÀ, ±1. Due orologi il cui rapporto è irrazionale: la
## figura non si richiude mai. `w` è il tempo di QUELLA metà — le due si
## chiamano con `w` diversi, o tornerebbero a essere un filo solo appena il
## gesto smette di muoversi.
static func tremolio(t: float, fase: float, w := 1.0) -> float:
	return sin(t * 2.9 * w + fase) * 0.58 + sin(t * 6.83 * w + fase * 2.7) * 0.42


## L'orologio della metà che segue: né armonico né sottomultiplo di quello
## che comanda (0,73 · 2,9 = 2,117 rad/s contro 2,9), o i due tremolii si
## richiuderebbero l'uno sull'altro e la seconda lancetta non servirebbe.
const TREM_DX := 0.73


## LO SCATTO DI UN ORECCHIO, 0…1: sta a zero quasi sempre e ogni pochi
## secondi fa una gobba stretta — la forma di un orecchio che si gira di
## colpo e torna. Due orologi il cui rapporto è irrazionale (1,626): gli
## istanti degli scatti sono la loro UNIONE, quindi non si ripetono mai, e
## due orecchie chiamate con `w` diversi non scattano mai insieme.
static func scatto_orecchio(t: float, fase: float, w := 1.0) -> float:
	var a := maxf(0.0, sin(t * 2.13 * w + fase))
	var b := maxf(0.0, sin(t * 1.31 * w + fase * 1.7 + 1.1))
	return minf(1.0, pow(a, 14.0) + 0.7 * pow(b, 14.0))


# =========================================================================
# LE COSTANTI DI TEMPO
# =========================================================================

## Quanto ci mette un gesto TRONCATO a rientrare. Non è un filtro sui gesti
## (quelli hanno la loro busta): è la rete per quando il mondo li interrompe
## — una chiacchierata, il falò, un pisolino. Un taglio secco è un salto del
## rig, e un salto del rig è la firma dell'adesivo staccato male.
const SPEGNI := 0.35

## …e quanto ci mette un LIVELLO a passare di mano. È una cosa diversa dalla
## rampa di un gesto troncato, e per questo è un numero diverso: un gesto è
## un EVENTO che qualcuno ha interrotto, e rientrare in fretta è il modo di
## non farsi notare; un livello è uno STATO — l'allerta di uno spavento, il
## rollio di chi sta pensando — e uno stato che sparisce in tre decimi si
## legge come un interruttore. Qui il corpo si scarica, non si stacca.
##
## GUARDATO (`tools/provino_asimmetrie.gd`, cinque rampe affiancate, la testa
## a 2,6 m, otto istanti dall'apertura della scena): a **0,25** l'orecchio è
## a posto entro la seconda tessera — cioè un interruttore; a **1,10**, otto
## decimi dentro la scena, l'allerta si vede ancora, ed è esattamente quello
## che la sospensione esiste per impedire. A **0,55** il rientro occupa
## quattro tessere e finisce prima di otto decimi: un corpo che si ricompone,
## e fuori dai piedi prima che la scena cominci davvero.
##
## E MISURATO (`tools/misura_asimmetrie.gd`: lo scatto per fotogramma sul
## canale più grosso del vocabolario — l'orecchio della coda, mezzo
## radiante): 0,0367 a 0,25 · 0,0261 a 0,35 · 0,0206 a 0,45 · **0,0171 a
## 0,55** · 0,0121 a 0,80 · 0,0089 a 1,10. Il tetto che lo stesso banco
## concede a un GESTO troncato è 0,030: sotto 0,45 la rampa dei livelli
## salterebbe più di quanto è permesso saltare a un gesto — e i canali di un
## livello sono i più grossi che il vocabolario abbia.
const LIVELLI_RAMPA := 0.55

## Quanti metri di strada può rubare UN gesto. È una rete, non una tara: se
## `r` restasse incastrato (un gesto che non finisce mai) il vicino
## camminerebbe a un terzo per il resto della partita, e nessun test guarda
## la velocità. Sopra questo tetto il gesto si spegne e il ritmo torna a 1.
##
## ⚠️ **IL NUMERO NON È QUELLO DELLA SINTESI, ed è una correzione.** Là
## diceva 1,20 m «(0,83 s)», che è aritmeticamente incompatibile con una
## tenuta di 1,6–2,4 s: a 1,45 m/s, fermarsi due secondi costa TRE METRI. Con
## 1,20 il Punto si sarebbe rifiutato sempre, e il gesto che tutta questa
## fase esiste per consegnare non sarebbe mai partito — con la suite verde,
## perché nessuna asserzione guarda «è mai successo». Il tetto vero lo dice
## la tabella: `costo_massimo("punto")` (misurato: 3,09 m con la tenuta di
## serie), più il margine per la variazione personale.
const DEBITO_MAX := 4.0

## La velocità di crociera con cui si converte il ritmo perso in metri. È
## quella di `Visitor._speed` a età zero (`1.45 * ...`), e serve solo al
## conto del debito: il corpo cammina con la sua, questa è il metro.
const VELOCITA_METRO := 1.45


# =========================================================================
# 1 · IL PUNTO — «mi sono accorto» · «mi è tornato in mente»
# =========================================================================
#
# Se se ne consegna UNO SOLO, è questo. Non perché sia il più bello: perché è
# **l'unico che fabbrica lo sfondo su cui gli altri diventano leggibili**.
#
#  · **Costa zero canali del rig.** Moltiplica `_move_gait()`, che ha UN solo
#    consumatore. Niente da togliere, niente che possa restare fuori posa.
#  · **È un contrasto di MOTO, non di forma.** Misurato: un corpo a velocità
#    di crociera cambia 222–980 px per fotogramma, fermo ne cambia 14–25 —
#    **8,9:1 di fronte, 54:1 di profilo, 11:1 di spalle**. Nessuna posa si
#    avvicina, e nessuna sopravvive a 17 m, che è la mediana vera degli
#    avvistamenti in partita.
#  · **È l'unico che GUADAGNA dalla folla.** I corpi che camminano sono il
#    riferimento; uno che si ferma è il segnale. Ogni altro gesto compete con
#    la locomozione degli altri; questo la usa.
#
# ⚠️ **MA LA FOLLA NON C'È, ED È MISURATA.** «Venti corpi che camminano»
# diceva la prima stesura di questa nota, e non è il villaggio che esiste.
# MISURATO in partita con VENTOTTO residenti, quattro campioni al secondo per
# quattordici minuti (2823 campioni, `tools/misura_occlusione.gd`, parte 2):
#
#   corpi dentro l'inquadratura, entro nove metri ....... media 2,54
#     (nessuno 13% · uno 10% · due 21% · tre 30% · quattro 21% · cinque+ 5%)
#   ...di quelli, quanti CAMMINANO .................... media 0,59
#     (nessuno 55% · uno 32% · due 10% · tre 2%)
#   ...quanti SI SPOSTANO davvero (>0,35 m/s) ......... media 0,71
#   e nell'istante in cui parte un Punto, altri che camminavano in quadro:
#     mediana DUE, e nessuno in quattro casi su otto.
#
# Cioè: l'inquadratura tiene due o tre vicini, e **più della metà del tempo
# non ne cammina nessuno**. La conclusione però non è quella che sembra, e
# va letta prima di «rinforzare» il Punto:
#
#  · il guasto temuto — «in mezzo a una folla un corpo fermo non spicca» —
#    **non può capitare**: una folla che cammina non c'è mai. Il massimo
#    misurato è TRE che camminano insieme, nel 2% dei fotogrammi;
#  · e quando l'attore è l'unico che si muove (metà delle volte), fermarsi
#    non lo confonde col fondo: **spegne tutto il moto del quadro**, che è il
#    cambiamento più grosso che quel fotogramma possa contenere;
#  · quello che resta senza riferimento è la TENUTA — 1,8 s in cui l'attore è
#    uno dei due o tre corpi fermi. Se un domani si vorrà rinforzare il
#    Punto, **il carico utile va lì e non sulla frenata**, e il canale non
#    può essere uno che porta già un'altra parola (la scala è del Raccolto,
#    il verticale del Rialzo, il rollio del Capo). Non lo si aggiunge senza
#    un provino: qui dentro nessun numero è stato indovinato.

## Quanto dura la frenata. Una rampa LINEARE, non un esponenziale: un
## esponenziale non ha un istante in cui il corpo si è fermato, e l'istante è
## tutto il gesto. Sotto `Andatura.VELOCITA_FERMO` (0,12) dopo 0,155 s, poi il
## blend estingue il ciclo del passo da sé in 0,288 s: **non c'è nessuna
## animazione d'arresto da scrivere**.
const PUNTO_FRENO := 0.16

## Quanto resta fermo. È l'unico numero in forbice di tutto il vocabolario, e
## lo ha scelto `tools/provino_ampiezze.gd` (0,8 / 1,2 / 1,8 / 2,4 / 3,5 s):
## sotto 1,2 il fermo si confonde con un'esitazione del passo, sopra 2,4 il
## vicino sembra rotto. Il ±12% personale viene dal genoma.
const PUNTO_TENUTA := 1.8
const PUNTO_TENUTA_SCARTO := 0.12

## Le due ripartenze. Sono `Visitor.TESTA_TORNA` e `TESTA_VAI` invertiti — la
## stessa coppia di costanti con cui questo gioco dice «torna piano» e «vai
## deciso», e non due numeri nuovi.
const PUNTO_MOLLE := 4.0      # 90% in 0,58 s: niente è cambiato
const PUNTO_DECISA := 9.0     # e in più ripaga il debito

## Il sovrappiù della ripartenza decisa, e per quanto dura. **Ha deciso**: si
## riparte più svelti del normale e si recupera un po' della strada persa.
const PUNTO_SPINTA := 1.12
const PUNTO_SPINTA_DUR := 0.8

## Le orecchie ARRIVANO PRIME, e questo è un segnale di TEMPO, non di
## ampiezza: l'ampiezza di un orecchio varia 2,6× col genoma (coniglio contro
## orso) e non è affidabile; l'istante no. 0,11 s di attacco vuol dire che
## sono già su quando il corpo comincia appena a rallentare.
const PUNTO_EAR := -0.30
const PUNTO_EAR_K := 20.0

## IL PESO CHE CONTINUA. Tre centimetri avanti che rientrano con un
## contraccolpo: è l'overshoot che dice *muscolo* invece di *interruttore*.
## Il socio isotropo obbligatorio (il moto lungo l'asse ottico paga 4,2×) è
## il fermo stesso, che è isotropo per costruzione.
const PUNTO_VZ := 0.030

## L'ASSESTAMENTO DEL FERMO. Un corpo fermo non è un corpo in pausa: il peso
## passa da una zampa all'altra, appena. Due orologi incommensurabili, fase
## dal genoma.
const PUNTO_SWAY_PX := 0.008
const PUNTO_SWAY_VRZ := 0.014


## La durata totale del Punto, coda della ripartenza compresa.
static func punto_durata(tenuta: float, decisa: bool) -> float:
	# la coda del deciso è quella del Rialzo che ci sta dentro, non quella
	# della molla del ritmo: se finisse prima, il gesto verrebbe troncato
	# dalla sua stessa tabella — e il troncamento lo si vedrebbe
	return PUNTO_FRENO + tenuta + (RIALZO_DUR if decisa else 1.45)


## IL RITMO del Punto: 1 → 0 → 1. È l'unico canale che porta il significato.
##
## `frena == false` è **l'anziano**, e non è un caso limite: `_move_gait`
## ferma già chi ha `_eta > 0,55` per 1,3 s ogni 7,5 (il fiato), e quel fermo
## batte il gettone di villaggio di venti volte. Due sistemi che rallentano
## lo stesso corpo sono un corpo che si impunta; togliergli il fiato è
## riscrivere un canale dimenticando `_eta`. Perciò su un anziano il Punto
## **non frena**: aspetta il prossimo fiato e ci veste sopra il payload.
static func punto_ritmo(t: float, tenuta: float, decisa: bool,
		frena := true) -> float:
	if not frena:
		return 1.0
	if t < PUNTO_FRENO:
		return maxf(0.0, 1.0 - t / PUNTO_FRENO)
	var fine := PUNTO_FRENO + tenuta
	if t < fine:
		return 0.0
	var s := t - fine
	if not decisa:
		return 1.0 - exp(-PUNTO_MOLLE * s)
	if s < PUNTO_SPINTA_DUR:
		return PUNTO_SPINTA * (1.0 - exp(-PUNTO_DECISA * s))
	var r08 := PUNTO_SPINTA * (1.0 - exp(-PUNTO_DECISA * PUNTO_SPINTA_DUR))
	return 1.0 + (r08 - 1.0) * exp(-PUNTO_DECISA * (s - PUNTO_SPINTA_DUR))


static func _punto(t: float, d: Dictionary, fase: float) -> Dictionary:
	var out := riposo()
	var tenuta := float(d.get("tenuta", PUNTO_TENUTA))
	var decisa := bool(d.get("decisa", false))
	var frena := bool(d.get("frena", true))
	var dur := punto_durata(tenuta, decisa)
	var fine := PUNTO_FRENO + tenuta
	out["r"] = punto_ritmo(t, tenuta, decisa, frena)

	# le orecchie: su di scatto, giù col ripartire
	var ear_giu := 1.0 if t < fine else exp(-3.4 * (t - fine))
	out["ear"] = PUNTO_EAR * (1.0 - exp(-PUNTO_EAR_K * maxf(t, 0.0))) * ear_giu
	# e non insieme: l'orecchio destro arriva 40 ms dopo. Due orecchie che
	# scattano allo stesso millesimo sono due orecchie sullo stesso filo.
	var td := t - 0.04
	var ear_dx := 0.0
	if td > 0.0:
		var g2 := 1.0 if td < fine else exp(-3.4 * (td - fine))
		ear_dx = PUNTO_EAR * (1.0 - exp(-PUNTO_EAR_K * td)) * g2
	out["ear_dx"] = ear_dx - out["ear"]

	# IL PESO CHE CONTINUA: parte da zero (il corpo sta ancora andando),
	# monta col freno, rientra e fa un contraccolpo che muore.
	# `sin` e non `cos`: con `cos` il gesto comincia già al massimo, cioè
	# comincia con un salto — che è la firma di ciò che qui non si fa.
	if frena:
		out["vz"] = -PUNTO_VZ * exp(-2.6 * t) * sin(7.0 * t) / 0.5626
	# il busto si raddrizza fermandosi, e si china sul primo passo dopo
	out["vx"] = -0.045 * exp(-2.2 * t) * sin(5.0 * t) / 0.5065
	if t > fine:
		out["vx"] += 0.030 * (1.0 - exp(-6.0 * (t - fine))) \
				* exp(-1.9 * (t - fine))
	# il mento sale un dito, poi si posa
	out["hx"] = -0.055 * (1.0 - exp(-9.0 * maxf(t, 0.0))) * exp(-1.1 * t) + 0.015
	# e il corpo si SIEDE sulle zampe un attimo dopo essersi fermato: la
	# massa che arriva dopo lo scheletro
	var sd := t - PUNTO_FRENO - 0.14
	if sd > 0.0:
		out["vy"] = -0.010 * sd * exp(-3.8 * sd) / 0.0968

	# L'ASSESTAMENTO. Vive solo dentro la tenuta, sfuma agli estremi, e non
	# si richiude mai su se stesso (0,83 e 2,17 rad/s).
	var dentro := smoothstep(PUNTO_FRENO, PUNTO_FRENO + 0.45, t) \
			* (1.0 - smoothstep(fine - 0.35, fine, t))
	if dentro > 0.0:
		var w := sin(t * 0.83 + fase) * 0.62 + sin(t * 2.17 + fase * 2.7) * 0.38
		out["px"] += PUNTO_SWAY_PX * w * dentro
		out["vrz"] += PUNTO_SWAY_VRZ * w * dentro

	# LA RIPARTENZA DECISA PORTA IL RIALZO ADDOSSO, e non è una scorciatoia
	# di scrittura: è la ragione per cui il Rialzo «non esiste da solo». Una
	# scintilla senza il buio prima è una lampadina accesa a mezzogiorno — e
	# qui il buio è la tenuta che l'ha appena preceduta. Il RITMO resta del
	# Punto: il Rialzo gli presta il corpo, non il passo.
	if decisa and t > fine:
		_innesta(out, _rialzo(t - fine, {"lato": float(d.get("lato", 1.0))}, fase))
	if t >= dur:
		return riposo()
	return out


## Somma un gesto DENTRO un altro: le deviazioni si sommano, i moltiplicatori
## si moltiplicano, il ritmo resta di chi ospita.
static func _innesta(out: Dictionary, altro: Dictionary) -> void:
	for c in altro:
		if c == "r":
			continue
		if c == "sy":
			out["sy"] = float(out["sy"]) * float(altro["sy"])
		else:
			out[c] = float(out[c]) + float(altro[c])


# =========================================================================
# 2 · IL RACCOLTO — «vorrei, e non lo faccio»
# =========================================================================
#
# L'unica POSA che passa la lente del verso a OGNI azimut: 1312 px
# nell'azimut peggiore a 6 m (802 a 9 m), rapporto peggio/meglio 2,14, verso
# 1,64–1,84. Funziona per la ragione giusta: un solido di rotazione non ha
# orientamento, ma ha una PROPORZIONE, e la proporzione si vede da ovunque.
#
# ⚠️ **LA SCALA VIVE SU `_corpo`, NON SU `_vis`.** `_vis.scale` ha cinque
# tween (l'ingresso, il sonno, il risveglio, il congedo, il pasto) e l'ordine
# del frame è `process_frame → _process → tween`: un togli additivo su un
# valore posato da un tween lo corrompe. `_corpo.scale` ha **un solo
# scrittore, `set_cucciolo`, fuori dal `_process`**, e ha già la sua base
# memorizzata (`_corpo_base`). Un canale la cui base è scritta da un tween
# **si rifiuta, non si combatte**.

## Il volume si conserva: un corpo che si comprime si ALLARGA. Uno che si
## rimpicciolisce e basta non è un corpo che si trattiene — è un errore di
## scala, e si legge come tale in un decimo di secondo.
##
## MISURATO (`provino_verso`, la scala delle ampiezze, quattro azimut a 6 m):
## 0,95 → verso 1,85–1,88 · 0,92 → 1,73–1,83 · **0,90 → 1,65–1,83** ·
## 0,87 → 1,56–1,85 ✗ · 0,84 → 1,54–1,87 ✗. Dieci per cento è **l'ultimo
## gradino che passa da tutti e quattro gli azimut**, ed è anche il più
## grosso: 1336–1717 px di corpo che cambia.
const RACCOLTO_SY := 0.90
const RACCOLTO_ATTACCO := 2.6      # 90% in 0,885 s
const RACCOLTO_RILASCIO := 1.65    # 90% in 1,40 s: da una rinuncia si esce PIANO
const RACCOLTO_TENUTA := 2.0

## Le braccia sono un canale di PROSSIMITÀ, ≤ 4 m, ed è dichiarato: 52 px su
## 7500 nel caso peggiore — il braccio è lungo 0,266 m e il raggio della
## testona 0,287, quindi non esce dalla campana. Si scrive lo stesso perché a
## 2,8 m — dove sta il vicino più vicino — si vede, e perché a quella distanza
## è la differenza fra «si è rimpicciolito» e «si è tenuto».
const RACCOLTO_AX := 0.30
## …e non con la stessa forza. **Il braccio che segue si tiene di meno**: una
## differenza di quota da sola non basta (vedi «LE DUE METÀ»), ma insieme al
## suo orologio è quel che rende le due braccia due braccia.
const RACCOLTO_AX_DX := 0.23

## ⚠️ **LE ORECCHIE NON SONO UN CANALE PORTANTE, e questa è una misura, non
## un'opinione.** Sono una ROTAZIONE attorno a un perno, e le due regioni che
## i due versi spazzano si sovrappongono: il verso di un orecchio è 1,97 a
## 0,20 · 1,78 a 0,30 · 1,62 a 0,40 · **1,39 a 0,55** · 1,12 a 0,75 — e **di
## PROFILO non passa a nessuna ampiezza** (1,57 al massimo, a 0,20).
##
## La prima stesura di questo file le portava a 0,55 nel Raccolto e a 0,70
## nel Rialzo, copiandole dalla sintesi: il gesto INTERO scendeva a 1,45–1,54
## mentre il suo canale portante stava a 1,67–1,83. Non era il gesto a essere
## poco leggibile — era **un accento che copriva la parola**. Le orecchie
## restano, perché sono la cosa più viva di un chibi; restano a un'ampiezza
## che non urla sopra la scala e sopra il verticale.
const RACCOLTO_EAR := 0.22
## …e l'orecchio che segue si piega di PIÙ. Era l'unica asimmetria che il
## Raccolto aveva, e da sola non bastava: una quota diversa sullo stesso
## orologio è un orecchio più lungo, non due orecchie.
const RACCOLTO_EAR_DX := 0.06
## E il busto: `vx` è anche lui una rotazione, e paga come tale. La DIAGNOSI
## (lo stesso Raccolto con un accento spento per volta, `provino_verso`) dice
## che è **lui** il diluente principale: spegnendolo il gesto guadagna 0,15 di
## verso di tre quarti, contro 0,09 delle orecchie e 0,03 del mento. A 0,05 il
## canale da solo vale 1,87 e il busto si curva ancora.
const RACCOLTO_VX := 0.05
## IL PASSO INDIETRO — e non è un accento, è il **secondo canale portante**.
##
## `vz` è il canale più direzionale di tutto il rig (verso 1,88–1,97 a ogni
## azimut e a ogni ampiezza misurata: la profondità non ha la simmetria che
## uccide le rotazioni), e qui dice esattamente la cosa giusta: chi vorrebbe e
## non lo fa **si tira indietro di tre centimetri**. La sintesi lo cercava
## come «socio isotropo» di un canale ottico; è venuto fuori che è lui il
## socio migliore che ci sia. (+ = indietro: il rig guarda −Z.)
const RACCOLTO_VZ := 0.030

## LA METÀ CHE SEGUE, qui. L'attacco del Raccolto dura quasi un secondo: il
## ritardo da solo sarebbe invisibile (misurato: residuo 2,6%), quindi il
## grosso lo fa la costante di tempo — 0,62 vuol dire che la metà che segue
## ci mette una volta e mezza a chiudersi, e per tutta la salita le due
## orecchie sono a due quote diverse **che cambiano**. Poi molla per prima
## (1,30), che è anche l'unico modo perché il riposo finale resti esatto.
##
## Il BRACCIO è più lento dell'orecchio, e non è una taratura: un braccio
## pesa. 0,14 s contro 0,07.
const RACCOLTO_MEZZA_RIT := 0.07
const RACCOLTO_MEZZA_PIGRO := 0.62
const RACCOLTO_MEZZA_MOLLA := 1.30
const RACCOLTO_BRACCIO_RIT := 0.14
const RACCOLTO_BRACCIO_PIGRO := 0.70
const RACCOLTO_BRACCIO_MOLLA := 1.20
## Il tremolio dentro la tenuta: un sussurro (0,4° sull'orecchio, 0,3° sul
## braccio) che serve a UNA cosa sola — che le due metà non stiano ferme
## nello stesso rapporto per due secondi. Sopra questi valori si legge come
## un tremore, che è un'altra parola e non è quella che il Raccolto dice.
const RACCOLTO_EAR_TREM := 0.007
const RACCOLTO_AX_TREM := 0.006


static func raccolto_durata(tenuta: float) -> float:
	# la coda del rilascio: 1,4 s per il 90%, 2,2 per l'inavvertibile
	return 0.9 + tenuta + 2.2


## La busta del Raccolto — attacco, tenuta, rilascio — presa a parte perché
## **la metà che segue la percorre con le SUE costanti**. Con i valori di
## serie è, riga per riga, quella di prima.
static func _busta_raccolto(t: float, t_ril: float, att: float,
		ril: float) -> float:
	if t <= 0.0:
		return 0.0
	if t <= t_ril:
		return 1.0 - exp(-att * t)
	return (1.0 - exp(-att * t_ril)) * exp(-ril * (t - t_ril))


static func _raccolto(t: float, d: Dictionary, fase: float) -> Dictionary:
	var out := riposo()
	var tenuta := float(d.get("tenuta", RACCOLTO_TENUTA))
	var t_ril := 0.9 + tenuta
	var a := _busta_raccolto(t, t_ril, RACCOLTO_ATTACCO, RACCOLTO_RILASCIO)
	if t >= raccolto_durata(tenuta):
		return riposo()

	# IL RESPIRO TRATTENUTO. Chi si morde la lingua respira corto e in alto,
	# e non a tempo con niente: due orologi che non si richiudono.
	var fiato := 0.0065 * (sin(t * 1.9 + fase) * 0.6 + sin(t * 4.3 + fase * 1.7) * 0.4)
	# e UN assestamento solo, a 0,7 s: le spalle che scendono di un altro
	# dito quando la decisione è presa davvero
	var dip := 0.0
	var sd := t - 0.7
	if sd > 0.0:
		dip = -0.013 * sd * exp(-3.0 * sd) / 0.1226

	out["sy"] = 1.0 + (RACCOLTO_SY - 1.0) * a + (fiato + dip) * a
	# il passo indietro arriva un filo DOPO la compressione: prima ci si
	# raccoglie, poi ci si ritrae. Due tempi, non uno.
	var ritratto := 0.0
	if t > 0.18:
		ritratto = a * (1.0 - exp(-3.0 * (t - 0.18)))
	out["vz"] = RACCOLTO_VZ * ritratto
	out["vx"] = RACCOLTO_VX * a   # si somma a −0,28·_eta: un anziano che si
	                              # trattiene si curva DI PIÙ, gratis
	out["hpy"] = -0.025 * a

	# LE DUE METÀ, ognuna sul suo orologio. `mezza`, `quota` e `quota_ax` sono
	# le manopole del provino — 1,0 è il gioco — e servono perché un banco che
	# non può spegnere la cura non può mostrare cosa cura. Sono TRE e non due
	# apposta: «com'è oggi» non è una coppia di valori, è *orecchie a due
	# quote sullo stesso orologio e braccia identiche*, e una lastra che non
	# sa riprodurre lo stato di partenza confronta la cura con niente.
	var mz := float(d.get("mezza", 1.0)) * pigrizia(fase)
	var qt := float(d.get("quota", 1.0))
	var qb := float(d.get("quota_ax", 1.0))
	var a_or := _busta_raccolto(t - RACCOLTO_MEZZA_RIT * mz, t_ril,
			RACCOLTO_ATTACCO * lerpf(1.0, RACCOLTO_MEZZA_PIGRO, mz),
			RACCOLTO_RILASCIO * lerpf(1.0, RACCOLTO_MEZZA_MOLLA, mz))
	var a_br := _busta_raccolto(t - RACCOLTO_BRACCIO_RIT * mz, t_ril,
			RACCOLTO_ATTACCO * lerpf(1.0, RACCOLTO_BRACCIO_PIGRO, mz),
			RACCOLTO_RILASCIO * lerpf(1.0, RACCOLTO_BRACCIO_MOLLA, mz))
	var e_sx := RACCOLTO_EAR * a \
			+ RACCOLTO_EAR_TREM * mz * a * tremolio(t, fase)
	var e_dx := (RACCOLTO_EAR + RACCOLTO_EAR_DX * qt) * a_or \
			+ RACCOLTO_EAR_TREM * mz * a_or * tremolio(t, fase * 1.9 + 2.1, TREM_DX)
	out["ear"] = e_sx
	out["ear_dx"] = e_dx - e_sx
	out["ax0"] = RACCOLTO_AX * a \
			+ RACCOLTO_AX_TREM * mz * a * tremolio(t, fase * 0.7 + 1.3, 1.19)
	out["ax1"] = lerpf(RACCOLTO_AX, RACCOLTO_AX_DX, qb) * a_br \
			+ RACCOLTO_AX_TREM * mz * a_br * tremolio(t, fase * 2.4, 0.61)
	out["tail"] = 0.22 * a        # accento puro: 0 px di fronte, 41 di profilo
	out["hx"] = 0.05 * a

	# E SI ESCE CON UN RIALZO, se la frase lo prevede: la rinuncia si scioglie
	# in un mezzo respiro invece di sfumare nel niente. Più piccolo del
	# Rialzo pieno — da una rinuncia non si esce trionfanti.
	var su := float(d.get("rialzo", 0.0))
	if su > 0.0 and t > t_ril:
		var r := _rialzo(t - t_ril, {"lato": float(d.get("lato", 1.0))}, fase)
		for c in r:
			if c == "r":
				continue
			if c == "sy":
				out["sy"] = float(out["sy"]) * (1.0 + (float(r["sy"]) - 1.0) * su)
			else:
				out[c] = float(out[c]) + float(r[c]) * su
	return out


# =========================================================================
# 3 · IL RIALZO — «mi è tornato in mente» · «ecco»
# =========================================================================
#
# Il verso più pulito misurato (1,79–1,87), 1262 px nell'azimut peggiore a
# 6 m. **NON ESISTE DA SOLO**: è il RILASCIO di un Raccolto o di un Punto.
# Una scintilla senza il buio prima è una lampadina accesa a mezzogiorno, e
# un gesto che si recita da solo insegna al giocatore che non vuol dire
# niente.
#
# ⚠️ È il gesto il cui segnale **È la velocità**: 46 cm/s veri nel primo
# decimo. Dentro il filtro della recita (k=6) sarebbero stati cinque
# millimetri — ed è esattamente per questo che le buste qui sono esplicite.

## MISURATO: il verticale è **il canale più direzionale del rig** — verso
## 1,81–1,89 a qualunque ampiezza fino a 0,075, e passa ancora a 0,10. 5,5 cm
## sono 1169–1272 px di corpo che cambia, e 46 cm/s veri nel primo decimo.
const RIALZO_VY := 0.055
const RIALZO_SALITA := 22.0    # 90% in 0,10 s
const RIALZO_DUR := 1.6
## Gli accenti, tarati contro la stessa scala del Raccolto: l'orecchio arriva
## a 0,745 del suo massimo (la forma di `_scatto`), quindi 0,40 di ampiezza
## sono 0,30 di posa — l'ultimo gradino che non copre il verticale.
const RIALZO_EAR := 0.34
const RIALZO_VX := 0.05
## E le orecchie PARTONO DOPO IL CORPO: sono floscie, hanno inerzia, e un
## orecchio che scatta nello stesso fotogramma del salto è un orecchio
## incollato al cranio. Sessanta millisecondi di ritardo — più gli ottanta
## fra l'una e l'altra — e il ritardo fa due mestieri insieme: racconta il
## peso, e toglie l'accento dall'istante in cui il verticale deve parlare da
## solo (il picco a 0,12 s).
const RIALZO_EAR_RIT := 0.06


static func _rialzo(t: float, d: Dictionary, fase: float) -> Dictionary:
	var out := riposo()
	if t >= RIALZO_DUR:
		return riposo()
	var lato := signf(float(d.get("lato", 1.0)))
	if lato == 0.0:
		lato = 1.0
	# LA SALITA e LA RICADUTA, asimmetriche: si sale di scatto e si ricade
	# con UN solo rimbalzo. Due rimbalzi sono un pallone.
	var tp := 0.12
	var vy := 0.0
	if t < tp:
		vy = 1.0 - exp(-RIALZO_SALITA * t)
	else:
		var s := t - tp
		vy = (1.0 - exp(-RIALZO_SALITA * tp)) * exp(-2.6 * s) * cos(5.2 * s)
	out["vy"] = RIALZO_VY * vy

	# LA SCALA: picco 1,05 → si POSA a 1,015 e ci resta. Il picco è un
	# istante, la tenuta è la notizia — ed è la tenuta che si legge a nove
	# metri, dove l'istante è passato prima che l'occhio arrivasse.
	var picco := 0.0
	if t < tp:
		picco = 1.0 - exp(-RIALZO_SALITA * t)
	else:
		picco = exp(-6.0 * (t - tp))
	var posa := (1.0 - exp(-RIALZO_SALITA * minf(t, tp))) \
			* (1.0 - smoothstep(RIALZO_DUR - 0.45, RIALZO_DUR, t))
	out["sy"] = 1.0 + 0.035 * picco + 0.015 * posa

	# il petto si apre: l'unico canale di questo gesto leggibile di profilo
	out["vx"] = -RIALZO_VX * posa
	out["hx"] = -0.07 * posa
	out["hpy"] = 0.012 * posa

	# LE ORECCHIE, con 80 ms di sfasamento fra le due. Mai simmetriche: due
	# orecchie che scattano insieme sono un giocattolo a molla.
	var e0 := -RIALZO_EAR * _scatto(t - RIALZO_EAR_RIT)
	var e1 := -RIALZO_EAR * _scatto(t - RIALZO_EAR_RIT - 0.08)
	out["ear"] = e0
	out["ear_dx"] = e1 - e0

	# IL ROLLIO DEL CAPO, che è l'unico canale della testa con un verso
	# leggibile di spalle (1,65 contro 1,04 dell'imbardata).
	out["hz"] = lato * 0.07 * posa   # accento: il rollio è del CAPO, non suo
	out["tail"] = -0.18 * picco
	# e il corpo si porta avanti di un dito: «ecco» è un movimento VERSO
	out["vz"] = -0.018 * posa
	# il micro che tiene viva la tenuta (senza, la posa a 1,015 è un fermo)
	out["vrz"] = 0.010 * posa * sin(t * 2.9 + fase)
	return out


## Uno scatto: su in fretta, giù piano. La forma di un orecchio che sente.
static func _scatto(t: float) -> float:
	if t <= 0.0:
		return 0.0
	return (1.0 - exp(-16.0 * t)) * exp(-1.3 * t)


# =========================================================================
# 4 · IL CAPO CHE PENDE — «ci sto pensando»
# =========================================================================
#
# **L'unico canale della testa con un verso leggibile DI SPALLE**: a soli 10°
# dà 719 px e verso 1,65, contro 886 px e verso **1,04** dell'imbardata. E di
# spalle un vicino si guarda il 49,6% delle volte — è il gesto che risponde
# all'inquadratura che oggi non dice niente («cosa sta guardando?»).
#
# NON È UN `sin`. È una sequenza di TRASFERIMENTI: ogni 4,5–9,0 s il capo si
# sposta in 0,35 s con una molla sottosmorzata, e poi **non succede niente**.
# È l'immobilità fra un trasferimento e l'altro che rende leggibile il
# trasferimento; un'oscillazione continua è un metronomo, e un metronomo si
# smette di vedere in due cicli.
#
# È un LIVELLO, non un evento: non ferma nessuno e non trasla nessuno, quindi
# non consuma il gettone del villaggio.

## ⚠️ **L'AMPIEZZA VA AL CONTRARIO DELL'INTUIZIONE, ed è misurata.** Il verso
## di un rollio *cala* crescendo: 1,74–1,86 a 0,08 · **1,60–1,74 a 0,11** ·
## 1,47–1,61 a 0,14 ✗ · 1,10–1,17 a 0,24 ✗. È la stessa ragione per cui
## l'imbardata non porta niente: una rotazione attorno a un perno spazza due
## regioni che, crescendo l'angolo, si sovrappongono sempre di più con la
## sagoma di partenza — la rilevabilità sale e la leggibilità no.
##
## La sintesi diceva «0,10–0,18 rad», e 0,18 è **fuori**. Il gesto non si fa
## più leggibile facendolo più grosso: si fa più leggibile facendolo più
## RARO, che è il mestiere di `capo_intervallo`.
const CAPO_AMP_MIN := 0.08
const CAPO_AMP_MAX := 0.11
const CAPO_IV_MIN := 4.5
const CAPO_IV_MAX := 9.0
## Le costanti della molla: sono quelle che `FaceController` ha già tarato per
## le sopracciglia. ζ = 10/(2·√170) = 0,383 — sottosmorzata, overshoot del
## 27%, assestata in ~0,35 s.
const CAPO_K := 170.0
const CAPO_C := 10.0


## Il prossimo intervallo, e la prossima ampiezza. Due orologi
## incommensurabili valutati nell'istante del trasferimento: nessun dado (i
## dadi di questo villaggio si salvano), nessuna tabella, e due vicini con
## genomi diversi non si sincronizzano mai.
static func capo_intervallo(t: float, fase: float) -> float:
	var w := sin(t * 0.31 + fase) * 0.58 + sin(t * 0.73 + fase * 2.3) * 0.42
	return lerpf(CAPO_IV_MIN, CAPO_IV_MAX, clampf(0.5 + 0.5 * w, 0.0, 1.0))


static func capo_bersaglio(t: float, fase: float, verso: float) -> float:
	var w := sin(t * 0.47 + fase * 1.9) * 0.6 + sin(t * 1.13 + fase) * 0.4
	var amp := lerpf(CAPO_AMP_MIN, CAPO_AMP_MAX, clampf(0.5 + 0.5 * w, 0.0, 1.0))
	return verso * amp


## L'AFFONDO — la testa che scende fra le spalle, e l'unica ragione per cui
## questo livello arriva anche a nove metri.
##
## ⚠️ **NON SI FA UN GESTO PIÙ GROSSO PER FARLO ARRIVARE PIÙ LONTANO.** Il
## rollio, misurato, ha il verso che CALA crescendo (1,74–1,86 a 0,08 ·
## 1,60–1,74 a 0,11 · 1,10–1,17 a 0,24): una rotazione attorno a un perno
## spazza due regioni che, crescendo l'angolo, si sovrappongono sempre di più
## con la sagoma di partenza. Sei gradi di rollio su una testona sono
## quattrocento pixel a due metri e **sedici** a nove — e sedici pixel su una
## sagoma di cinquanta non sono un gesto, sono l'antialiasing.
##
## La strada giusta è un'altra grandezza: la SAGOMA. La testa che scende
## chiude la tacca del collo, e il contorno cambia FORMA invece che
## inclinazione — che è quello che sopravvive quando il corpo è alto
## cinquanta pixel.
##
## **Il quadrato non è una comodità, sono tre cose insieme:**
##  1. **niente spigolo al passaggio.** `|x|` avrebbe una V nell'istante in
##     cui la molla attraversa lo zero, cioè uno scatto in mezzo al
##     trasferimento;
##  2. **il trasferimento diventa un EVENTO anche in sagoma.** Passando da
##     una parte all'altra la testa risale e riscende: a nove metri il rollio
##     non si vede e quel tuffo sì, ed è l'unica cosa che distingue «sta
##     pensando» da «sta lì»;
##  3. **due trasferimenti non affondano uguale.** L'ampiezza del rollio vive
##     fra 0,08 e 0,11, quindi il quadrato normalizzato vive fra 0,53 e 1,00:
##     la profondità cambia da sola, senza un secondo orologio.
##
## Torna un numero NEGATIVO (giù), come vuole il canale.
const CAPO_AFFONDO := 0.05


static func capo_affondo(x: float) -> float:
	var n := x / CAPO_AMP_MAX
	# non si taglia a uno: l'overshoot della molla (27%) porta il tuffo un
	# filo più giù del suo assestamento, ed è l'assestamento a leggersi
	return -CAPO_AFFONDO * minf(n * n, 1.25)


# =========================================================================
# 5 · IL LARGO — «quel posto lì, no»
# =========================================================================
#
# Il momento esiste già nella simulazione e il corpo non lo dice:
# `Visitors._filtra_luogo` consuma `Limbico.evita()`, posa un'esitazione, e
# poi il vicino se ne va **senza nessun segno residuo**. Zero inneschi nuovi.
#
# **È l'unico gesto che si recita CAMMINANDO** — attraversa la vita invece di
# interromperla.
#
# ⚠️ **NON `_vis.rotation.y`.** Il progetto di partenza appoggiava qui il suo
# gesto di punta («le due rotazioni opposte si sommano in sagoma»): misurato,
# il busto girato di 24° ha verso **1,06** — girarlo a destra cambia gli
# stessi pixel che girarlo a sinistra. L'idea è giusta (testa contro corpo),
# il canale era sbagliato: **la traslazione laterale porta il verso,
# l'imbardata no.** Misurata a 7,5 cm: 4279/3417/1011/4316 px, verso
# 1,60–1,79.

const LARGO_PX := 0.09
const LARGO_VRZ := 0.085
const LARGO_HZ := 0.11
const LARGO_RITMO := 1.08
const LARGO_DUR := 3.0
## L'ESITAZIONE — e senza di lei questo gesto non aveva NIENTE che si vedesse.
##
## ⚠️ **IL LARGO ERA L'UNICO EVENTO DEL VOCABOLARIO SENZA UN CANALE DI
## TEMPO**, e il suo carico utile — nove centimetri di scostamento e cinque
## gradi di inclinazione — è misurabile solo CONTRO LA RIGA CHE IL CORPO
## AVREBBE FATTO, cioè contro un riferimento che al giocatore non arriva: il
## Punto si legge perché un corpo fermo si confronta col corpo di prima, ma
## un corpo che cammina nove centimetri più in là non si confronta con
## niente. GUARDATO (`tools/provino_vocabolario.gd`, parte X: cinque
## varianti affiancate ed etichettate, a sei metri, di tre quarti e di
## spalle): con `dip = 0` le otto tessere della striscia sono la stessa
## immagine; a 0,45 il corpo resta indietro visibilmente fra 0,3 e 0,6 s e
## poi riprende.
##
## **0,45 e non 0,70**: a 0,70 il ritmo scende a 0,30 e il gesto diventa una
## fermata — cioè la parola del Punto, detta male. Qui il corpo dimezza il
## passo per due decimi di secondo e riparte: è un'esitazione, e costa
## sedici centimetri di strada.
const LARGO_DIP := 0.45
const LARGO_DIP_SU := 0.15    # quanto ci mette a smorzare
const LARGO_DIP_GIU := 0.20   # e a riprendere
## Quanto della girata piena vale la testa che resta indietro. Non è una
## ricevuta: è uno sguardo che si stacca a fatica, e a metà strada si legge
## come tale.
const LARGO_TESTA := 0.55

## LA METÀ CHE SEGUE, qui — e qui **chi guida non è sempre la stessa**: è la
## metà dalla parte in cui ci si scosta. Chi si sposta a destra porta prima il
## braccio e l'orecchio destri, e i sinistri inseguono; scostandosi a
## sinistra è il contrario. Non è un vezzo: il Largo è l'unico gesto che si
## recita camminando, e il corpo che si sposta di lato ha un lato che parte e
## uno che arriva. (E resta un ACCENTO — il verso del gesto lo porta `px`,
## come dice il cappello: nove centimetri di traslazione, non due braccia.)
##
## L'attacco è ripido (90% in 0,46 s), quindi qui 80 ms di ritardo si vedono
## davvero e la costante di tempo fa il resto.
const LARGO_MEZZA_RIT := 0.08
const LARGO_MEZZA_PIGRO := 0.66
const LARGO_MEZZA_MOLLA := 1.25
const LARGO_EAR := 0.20
const LARGO_EAR_DX := 0.05       # …e non alla stessa quota
const LARGO_AX := 0.12
const LARGO_AX_DX := 0.085
const LARGO_TREM := 0.006


## La busta del Largo, presa a parte per la stessa ragione della sua gemella
## del Raccolto: la metà che segue la percorre con le SUE costanti. Coi valori
## di serie è, riga per riga, quella di prima.
static func _busta_largo(t: float, t_ril: float, att: float,
		ril: float) -> float:
	if t <= 0.0:
		return 0.0
	if t <= t_ril:
		return (1.0 - exp(-att * t)) * (1.0 + 0.10 * exp(-3.0 * t) * sin(6.0 * t))
	return (1.0 - exp(-att * t_ril)) * exp(-ril * (t - t_ril))


static func _largo(t: float, d: Dictionary, fase: float) -> Dictionary:
	var out := riposo()
	if t >= LARGO_DUR:
		return riposo()
	var via := signf(float(d.get("via", 1.0)))
	if via == 0.0:
		via = 1.0
	# lo scostamento: attacco con un filo di overshoot (ci si scosta di
	# slancio), tenuta, e rientro più lento del rientro di un passo
	var t_ril := LARGO_DUR - 0.9
	var a := _busta_largo(t, t_ril, 5.0, 3.2)
	# le tre ampiezze si possono variare da fuori: sono i valori che il
	# provino mette a confronto, e le costanti sono i valori scelti
	out["px"] = float(d.get("px", LARGO_PX)) * via * a
	# ci si INCLINA dentro lo scostamento: un corpo che trasla senza
	# inclinarsi non si sposta, scivola
	out["vrz"] = -float(d.get("vrz", LARGO_VRZ)) * via * a
	out["hz"] = float(d.get("hz", LARGO_HZ)) * via * a
	out["r"] = 1.0 + (LARGO_RITMO - 1.0) * a
	# L'ESITAZIONE, se c'è: mezzo passo di indecisione PRIMA di scostarsi.
	# È l'unico canale del vocabolario che si legge a nove metri e di
	# spalle (il Punto lo dimostra), e qui costa pochi centimetri di strada:
	# non ferma il corpo, lo fa esitare.
	var dip := clampf(float(d.get("dip", LARGO_DIP)), 0.0, 0.9)
	if dip > 0.0:
		var e := clampf(t / LARGO_DIP_SU, 0.0, 1.0) \
				* exp(-maxf(0.0, t - LARGO_DIP_SU) / LARGO_DIP_GIU)
		out["r"] *= 1.0 - dip * e
	# LE DUE METÀ. `guida` è la metà dalla parte in cui ci si scosta: parte
	# lei, e l'altra insegue col suo orologio.
	var mz := float(d.get("mezza", 1.0)) * pigrizia(fase)
	var qt := float(d.get("quota", 1.0))
	var qb := float(d.get("quota_ax", 1.0))
	var a_seg := _busta_largo(t - LARGO_MEZZA_RIT * mz, t_ril,
			5.0 * lerpf(1.0, LARGO_MEZZA_PIGRO, mz),
			3.2 * lerpf(1.0, LARGO_MEZZA_MOLLA, mz))
	var e_gui := LARGO_EAR * a \
			+ LARGO_TREM * mz * a * tremolio(t, fase * 1.4)
	var e_seg := (LARGO_EAR - LARGO_EAR_DX * qt) * a_seg \
			+ LARGO_TREM * mz * a_seg * tremolio(t, fase * 2.2 + 0.9, TREM_DX)
	var b_gui := LARGO_AX * a \
			+ LARGO_TREM * mz * a * tremolio(t, fase * 0.8 + 2.6, 1.19)
	var b_seg := lerpf(LARGO_AX, LARGO_AX_DX, qb) * a_seg \
			+ LARGO_TREM * mz * a_seg * tremolio(t, fase * 3.1, 0.61)
	# `ear` è di TUTTE E DUE, `ear_dx` è il di più della destra: chi guida
	# finisce nell'una o nell'altra a seconda del verso dello scostamento.
	if via > 0.0:
		out["ear"] = e_seg
		out["ear_dx"] = e_gui - e_seg
		out["ax0"] = b_seg
		out["ax1"] = b_gui
	else:
		out["ear"] = e_gui
		out["ear_dx"] = e_seg - e_gui
		out["ax0"] = b_gui
		out["ax1"] = b_seg
	out["tail"] = 0.14 * a
	# il micro: il passo che si accorcia non è liscio
	out["vy"] = 0.006 * a * sin(t * 3.1 + fase)
	# `testa` non è un canale: è la FRAZIONE con cui chi ha il mondo davanti
	# (Visitor: solo lui sa dov'è il posto) scala la propria mira.
	out["hy"] = LARGO_TESTA * a
	return out


# =========================================================================
# 6 · LA CODA e IL RALLENTANDO — «sono ancora guardingo»
# =========================================================================
#
# Due strati, una causa, **nessun innesco nuovo**: cavalcano la `forza` che
# `Visitors._tick_sussulti` calcola già. È la promessa scritta in
# `Limbico.gd` («*è lentezza fisica, non testardaggine*») che nessuno aveva
# mai mantenuto: oggi `arousal` ha due lettori e sono una stringa e la voce.
#
# ⚠️ **τ = 2,8 e NON 7,0, ed è una correzione misurata.** Il cooldown del
# sussulto è 9 s per residente e `percepisci` rialza `arousal`: con τ=7 (vita
# 15–19 s) la posa si riaccende prima di essersi spenta e resta accesa **il
# 100% del tempo** su chiunque il giocatore sfiori camminando — cioè il
# livello monotono, che è proprio il guasto che la regola dei livelli vieta.
# **Una coda deve decadere più in fretta del proprio riarmo.** 6,0 < 9,0.
const CODA_TAU := 2.8
const CODA_SOGLIA := 0.06
## …e il tempo di vita che ne discende: `−τ·ln(soglia)` a forza piena.
const CODA_VITA := 7.87

## Lo strato lento: il RALLENTANDO. Il *quanto* viene dal dato che esiste, il
## *per quanto* è del corpo — e il corpo non si salva.
##
## ⚠️ La finestra somatica vive in RAM e **non è legata al livello di
## `arousal`**, che decade solo in `passa_giorno`, cioè quattro minuti reali
## di gioco: un vicino al 77% della velocità per quattro minuti non è
## guardingo, è rotto.
const SOMA_TAU := 18.0
const SOMA_CALO := 0.42
const SOMA_PAVIMENTO := 0.72


## ⚠️ **E SOTTO LA SOGLIA NON SI TAGLIA, SI SPEGNE.** La soglia serve a far
## MORIRE il livello (senza, `_gs_soma` non si azzera mai e la coda resta
## accesa a un millesimo per sempre), ma una soglia secca è un gradino: al
## momento di sparire le orecchie valevano ancora 0,027 rad, e sparivano in
## un fotogramma. Sotto il doppio della soglia l'ampiezza si smorza, così il
## livello si spegne invece di essere staccato — la stessa regola della rampa
## dei livelli, applicata all'unico modo che questo livello ha di finire da
## solo.
static func coda_ampiezza(forza: float, t: float) -> float:
	var a := clampf(forza, 0.0, 1.0) * exp(-t / CODA_TAU)
	if a < CODA_SOGLIA:
		return 0.0
	return a * smoothstep(CODA_SOGLIA, CODA_SOGLIA * 2.0, a)


## IL RILASCIO — quanto resta della coda `s` secondi dopo che qualcosa l'ha
## SCIOLTA. Moltiplica la FORZA, non l'ampiezza: così i due strati (la posa e
## il rallentando) mollano insieme, e nessuno deve comporli a mano.
##
## Serve a un momento solo, ed è il più bello che questa meccanica abbia:
## «ah… sei tu». Il commento della grammatica lo prometteva per iscritto — *il
## corpo si è irrigidito davvero, e il Rialzo la scioglie* — e non lo faceva
## nessuno: dopo il riconoscimento il vicino restava guardingo per otto
## secondi di posa e settantaquattro di passo rallentato. Un sollievo che non
## scioglie niente non è un sollievo: è una seconda posa sopra la prima.
##
## ⚠️ **NON È UN TAGLIO.** Un livello che sparisce in un fotogramma è un salto
## del rig — e sarebbe il salto peggiore possibile, perché arriva nell'istante
## in cui il giocatore ha quel corpo in faccia a due metri.
##
## ⚠️ **E LA RAMPA NON È UNA COSTANTE NUOVA: è `SPEGNI`**, la stessa con cui si
## mette giù un gesto troncato. In questo progetto, quando qualcosa si molla,
## si molla così; un secondo tempo di rilascio scritto qui sarebbe una
## costante gemella da tenere allineata a mano.
static func coda_rilascio(s: float) -> float:
	if s <= 0.0:
		return 1.0
	var x := clampf(s / SPEGNI, 0.0, 1.0)
	return 1.0 - x * x * (3.0 - 2.0 * x)


## Il ritmo del rallentando. Un rate scalare che compone per prodotto è
## **indecodificabile per costruzione**, ed è voluto: un vicino lento può
## essere guardingo, stanco o pensieroso, e il giocatore legge «a lui sta
## succedendo qualcosa», mai quale leva. È l'unica cosa di tutto il
## vocabolario che arriva ai venti vicini lontani.
# =========================================================================
# LA NOTTE CHE ARRIVA — il livello della melatonina
# =========================================================================
#
# ⚠️ **NON È UN GESTO, ed è la ragione per cui non prende il gettone.** Un
# gesto è un EVENTO che si vede una volta e vuole il palco; questo è uno
# STATO, come la coda somatica e il capo che pende: capita a tutti, ogni
# sera, e l'unica cosa che dice è «sta arrivando la MIA ora».
#
# ⚠️ **E DICE UNA COSA CHE L'ADENOSINA NON SA DIRE.** L'adenosina è la
# pressione di sonno: sale con le ore di veglia, e vuol dire «sono stanco».
# Questa anticipa la PROPRIA finestra, e vuol dire «è la mia sera» — due
# processi diversi, ed è per questo che i canali non si sovrappongono: le
# orecchie sono già dell'adenosina (`Andatura.applica`, `+0.18 · adenosina`),
# e scriverci sopra vorrebbe dire ripetere una parola che il corpo dice già.
#
# Il canale portante è la SILHOUETTE, che è l'unica cosa che questo progetto
# ha misurato leggersi da tutti e quattro i lati e a distanza: il corpo che
# si abbassa e la testa che affonda fra le spalle.
#
# ⚠️ **La soglia SMORZA, non taglia.** Un livello che si accende su un
# confronto compare in un fotogramma, e un salto del rig è la cosa peggiore
# che possa fare un canale che dovrebbe dire «piano piano».
const NOTTE_SOGLIA := 0.08
const NOTTE_PIENA := 0.42
## Quanto si abbassa il corpo, a livello pieno.
##
## ⚠️ **NON è scelto: è il massimo che il verso regge.** Il cancello del verso
## (`tools/provino_verso.gd`) ha già misurato questo canale una volta per
## tutte — la scala porta il verso a **1,64–1,85 fino a −10%, e a −13% cade**
## — quindi qualunque numero più grosso comprerebbe visibilità pagandola in
## leggibilità, che è il contrario di quello che serve.
##
## E GUARDATO (`tools/provino_notte.gd`, cinque varianti affiancate nello
## stesso fotogramma, a quattro azimut e due distanze): a 2 m −0,04 e −0,07
## non si leggono, −0,10 si legge e il corpo resta un corpo, −0,15 si legge
## ma comincia a sembrare **schiacciato**, −0,22 è deforme. A 6 m −0,10 è al
## limite. La controprova a livello zero dà cinque silhouette **identiche**:
## la progressione è del canale, non della fase delle micro-espressioni.
##
## ⚠️ **Residuo dichiarato: a 6 m è debole, a 9 non c'è.** È la stessa cosa
## che il progetto ha già scritto del capo che pende — un livello si nota
## quando ci si avvicina a qualcuno, non attraverso il prato.
const NOTTE_SY := 0.10
## Quanto affonda la testa fra le spalle, in metri, a livello pieno.
const NOTTE_HPY := 0.022


## Il livello, da un canale di melatonina. Puro.
static func notte_livello(melatonina: float) -> float:
	var m := clampf(melatonina, 0.0, 1.0)
	if not is_finite(m):
		return 0.0
	return smoothstep(NOTTE_SOGLIA, NOTTE_PIENA, m)


## I canali del rig, dal livello. `sy` è un FATTORE (si moltiplica), `hpy` un
## termine (si somma) — la stessa convenzione della coda somatica.
static func notte_canali(livello: float, sy := -1.0) -> Dictionary:
	var out := riposo()
	var l := clampf(livello, 0.0, 1.0)
	if l <= 0.0:
		return out
	# `sy < 0` = usa la costante. Il parametro esiste solo per il provino che
	# affianca cinque guadagni nello stesso fotogramma: in partita non lo
	# passa nessuno, e un test lo prova.
	out["sy"] = 1.0 - (NOTTE_SY if sy < 0.0 else sy) * l
	out["hpy"] = NOTTE_HPY * l
	return out


static func soma_ritmo(forza: float, t: float) -> float:
	var b := clampf(forza, 0.0, 1.0) * exp(-t / SOMA_TAU)
	return maxf(SOMA_PAVIMENTO, 1.0 - SOMA_CALO * b)


## LA METÀ CHE SEGUE, in un LIVELLO — e qui la cura non può essere la stessa.
##
## ⚠️ Un livello non ha una busta: ha un'ampiezza che decade, e **ritardare un
## esponenziale non cambia niente** — `a(t−r) = a(t)·exp(r/τ)`, cioè una
## costante, cioè esattamente il filo solo che si voleva rompere. Restano due
## strade, e servono tutte e due: una costante di tempo diversa (il rapporto
## fra i due τ è l'esponente: `a^(τ/τ₂)`, che è la *definizione* di un altro
## τ, non un trucco) e il tremolio, che qui è l'unica cosa che si muove.
##
## E il tremolio qui è più grosso che nei gesti (0,7° invece di 0,4): un
## livello dura otto secondi, e in otto secondi due orecchie ferme sono due
## orecchie di gomma.
const CODA_MEZZA_TAU := 2.55     # τ della metà che segue: molla per prima
const CODA_EAR := 0.45
const CODA_EAR_DX := 0.50
const CODA_AX := 0.30
const CODA_AX_DX := 0.245
const CODA_TREM := 0.012
## LE BRACCIA, in un livello, hanno bisogno di PIÙ delle orecchie e di più
## lento: sono l'unica cosa che resta ferma per otto secondi, e un tremolio
## da mezzo grado su una posa da diciassette è un pixel. Non è un tremore —
## è il peso che passa da una zampa all'altra, il parente dell'assestamento
## del Punto — quindi l'ampiezza è tripla e gli orologi sono lenti (`w` a
## 0,52 e 0,37: 1,5 e 1,1 rad/s).
const CODA_AX_TREM := 0.040
## E LO SCATTO. Un animale guardingo non «trema»: ogni tanto GIRA un
## orecchio in avanti — «ho sentito?» — e l'altro no. È la cosa che dice
## *guardingo* meglio di qualunque quota, ed è anche l'unica che sopravvive
## a otto secondi di livello: una posa tenuta per otto secondi è un adesivo
## anche se le due metà stanno a due quote diverse.
##
## ⚠️ **NON UNA SOLA LANCETTA.** Uno scatto periodico è un metronomo, e un
## metronomo si smette di vedere in due cicli — è scritto nel cappello del
## Capo che pende, ed è la stessa trappola. Qui gli scatti sono l'UNIONE di
## due orologi incommensurabili: gli istanti non si ripetono mai, e le due
## orecchie non scattano mai insieme.
const CODA_SCATTO := 0.09


## `d` sono le manopole del provino, con le stesse chiavi che gli EVENTI
## ricevono nei loro dati: vuoto è il gioco, e il gioco non paga niente.
static func coda_canali(a: float, t: float, fase: float,
		d := {}) -> Dictionary:
	var out := riposo()
	if a <= 0.0:
		return out
	out["sy"] = 1.0 - 0.035 * a
	var mz := 1.0
	var quota := 1.0
	var quota_ax := 1.0
	var scatto := CODA_SCATTO
	if not d.is_empty():
		mz = float(d.get("mezza", 1.0))
		quota = float(d.get("quota", 1.0))
		quota_ax = float(d.get("quota_ax", 1.0))
		scatto = float(d.get("scatto", CODA_SCATTO))
	mz *= pigrizia(fase)
	# la metà che segue vive sul suo τ. `pow` su un'ampiezza che è già zero
	# resta zero: il livello muore insieme, non uno prima dell'altro.
	var a2 := pow(a, lerpf(1.0, CODA_TAU / CODA_MEZZA_TAU, mz))
	# `− scatto`: l'orecchio si gira in AVANTI (il canale è + = giù), che è
	# il verso dell'«ho sentito?» dentro una posa che dice «sto indietro».
	var e_sx := CODA_EAR * a + CODA_TREM * mz * a * tremolio(t, fase) \
			- scatto * mz * a * scatto_orecchio(t, fase)
	var e_dx := lerpf(CODA_EAR, CODA_EAR_DX, quota) * a2 \
			+ CODA_TREM * mz * a2 * tremolio(t, fase * 1.9 + 2.1, TREM_DX) \
			- scatto * mz * a2 * scatto_orecchio(t, fase * 2.6 + 0.4, 0.79)
	out["ear"] = e_sx
	out["ear_dx"] = e_dx - e_sx
	out["ax0"] = CODA_AX * a \
			+ CODA_AX_TREM * mz * a * tremolio(t, fase * 0.7 + 1.3, 0.52)
	out["ax1"] = lerpf(CODA_AX, CODA_AX_DX, quota_ax) * a2 \
			+ CODA_AX_TREM * mz * a2 * tremolio(t, fase * 2.4, 0.29)
	out["hpy"] = -0.025 * a
	out["tail"] = -0.30 * a
	# CHI È GUARDINGO SI GUARDA INTORNO. Non è il vagare della ricevuta
	# (quello vive solo mentre la testa è girata su un gesto): è una
	# scansione lenta, due orologi incommensurabili, che esiste anche
	# quando non sta succedendo niente — ed è proprio quello a dire
	# «guardingo» invece di «attento a qualcosa».
	out["hy"] = 0.10 * a * (sin(t * 0.61 + fase) * 0.58
			+ sin(t * 1.43 + fase * 2.2) * 0.42)
	return out


# =========================================================================
# L'ANAGRAFE DEI GESTI
# =========================================================================

## Gli eventi: quelli che prendono il gettone del villaggio. I due LIVELLI
## (il Capo e la Coda) non stanno qui apposta — non fermano nessuno e non
## traslano nessuno, quindi competono con niente.
const EVENTI := ["punto", "raccolto", "rialzo", "largo"]


static func e_evento(nome: String) -> bool:
	return EVENTI.has(nome)


static func durata(nome: String, d: Dictionary) -> float:
	match nome:
		"punto":
			return punto_durata(float(d.get("tenuta", PUNTO_TENUTA)),
					bool(d.get("decisa", false)))
		"raccolto":
			var base := raccolto_durata(float(d.get("tenuta", RACCOLTO_TENUTA)))
			if float(d.get("rialzo", 0.0)) > 0.0:
				base = maxf(base, 0.9 + float(d.get("tenuta", RACCOLTO_TENUTA))
						+ RIALZO_DUR)
			return base
		"rialzo":
			return RIALZO_DUR
		"largo":
			return LARGO_DUR
	return 0.0


## I canali di un evento a `t` secondi dal suo inizio. Fuori dalla durata
## torna il riposo esatto — mai un residuo, mai un valore «quasi zero» che
## il frame dopo qualcuno somma di nuovo.
static func bersagli(nome: String, t: float, d: Dictionary,
		fase := 0.0) -> Dictionary:
	if t < 0.0:
		return riposo()
	match nome:
		"punto":
			return _punto(t, d, fase)
		"raccolto":
			return _raccolto(t, d, fase)
		"rialzo":
			return _rialzo(t, d, fase)
		"largo":
			return _largo(t, d, fase)
	return riposo()


## QUANTI METRI COSTA un gesto, integrando il ritmo perso. Puro e senza
## effetti: serve al banco (che pretende `≤ DEBITO_MAX`) e serve a chi vuole
## sapere quanto si allunga un viaggio, senza doverlo far camminare.
static func costo_metri(nome: String, d: Dictionary, passo := 1.0 / 240.0) -> float:
	var dur := durata(nome, d)
	var m := 0.0
	var t := 0.0
	while t < dur:
		m += (1.0 - bersagli(nome, t, d)["r"]) * passo
		t += passo
	return m * VELOCITA_METRO


# =========================================================================
# LA GRAMMATICA — cinque FRASI, non sei gesti
# =========================================================================
#
# Ognuna corrisponde a una cosa che il gioco ha GIÀ da dire, e nessuna ha
# bisogno di un innesco nuovo. Il vocabolario non può aumentare la frequenza
# degli eventi: può solo renderli visibili. QUANDO si dicono lo decide
# `Regia.gd`, che è l'unico posto in cui sta scritto quale momento della
# vita interiore vale il palco.
#
#   la premessa   Punto molle              un ricordo NUOVO in `Percezione`
#   il pensiero   Punto deciso + il Capo   la promozione di un ricordo · una deduzione
#   la rinuncia   Raccolto → Rialzo        `Limbico.trattieni()` che torna TRUE
#   l'evitamento  Largo, camminando        `Limbico.evita(luogo)`
#   il sollievo   Rialzo                   il sussulto che si scioglie: «ah… sei tu»
#
# ⚠️ **IL RIALZO NON SI RECITA DA SOLO, e il sollievo NON È UN'ECCEZIONE.**
# «Mi è tornato in mente» detto da solo è una lampadina accesa a mezzogiorno:
# senza il buio di una tenuta prima, non c'è niente da illuminare. Il Rialzo
# vive perciò INNESTATO — dentro la ripartenza decisa del Punto e dentro il
# rilascio del Raccolto — e la frase `sollievo` esiste solo perché lì il buio
# **c'è, e non lo mette questa tabella**: è il SUSSULTO, che è passato quattro
# decimi di secondo prima (`Visitors._tick_riconoscimenti`, la strada veloce
# che precede la strada lenta di `Limbico`). Il corpo si è irrigidito davvero
# — la coda somatica è accesa e si vede — e il Rialzo la scioglie.
#
# La regola non è affidata a questo commento: `Visitor.frase("sollievo")` si
# RIFIUTA se la coda somatica non è viva. Il buio è una **precondizione
# eseguibile**, non una buona intenzione, e un test la rompe apposta.
#
# ⚠️ E **la rinuncia è l'unica frase con un innesco che oggi non ha corpo**:
# `Visitors._tick_confronti` reagisce solo al `trattieni()` FALSO (il morso
# che non riesce, e allora qualcosa esce di sbieco). Il morso RIUSCITO — cioè
# il caso comune, cioè mordersi la lingua e riuscirci — non si vedeva.
#
# ⚠️ E **`incontro` NON È UN GESTO NUOVO: è una COMBINAZIONE.** «Ci siamo
# trovati» non ha bisogno di un canale che non c'è — ha bisogno di due corpi
# e di un ritardo. È il Punto deciso, cioè il Punto col Rialzo innestato
# nella ripartenza, che questa stessa tabella dichiara essere il solo posto
# in cui il Rialzo ha diritto di esistere; e quello che lo rende una frase a
# due non sta qui dentro, perché non è del corpo: è il QUARTO DI SECONDO fra
# l'uno e l'altro, e vive dove vivono le due persone (`Visitors.chiedi_duetto`).
#
# Non porta il `capo` del pensiero apposta. Trovarsi non è pensare: il rollio
# racconta una cosa che dura, e questa dura un secondo e mezzo.
const FRASI := {
	"premessa": {"g": "punto", "d": {}},
	"pensiero": {"g": "punto", "d": {"decisa": true, "capo": true}},
	"incontro": {"g": "punto", "d": {"decisa": true}},
	"rinuncia": {"g": "raccolto", "d": {"rialzo": 0.6}},
	"evitamento": {"g": "largo", "d": {}},
	"sollievo": {"g": "rialzo", "d": {"buio": true}},
}
