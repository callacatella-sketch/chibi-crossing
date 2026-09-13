extends RefCounted
## ⚠️ **ESSERE GUARDATI — e il gesto è lo STESSO con cui il prato impara a
## fidarsi di te.**
##
## Il Fiato Sospeso (tenere C: fermarsi, accovacciarsi, non fare rumore) è la
## cosa più gentile che questo gioco conosca. `FiatoSospeso.calma()` sale, e
## il mondo si avvicina: la farfalla si posa su di te, la rana non salta, la
## trota resta. È il verbo dell'aspettare, ed è tarato e misurato.
##
## Fatto addosso a una PERSONA, e tenuto, è un'altra cosa. Non perché il gioco
## decida che lo sia: perché **la differenza fra guardare una bestiola e
## guardare qualcuno che ti può guardare indietro è che il secondo se ne
## accorge.** Il canale c'è già — `Percezione.puo_vedere` — e finora serviva
## solo a decidere chi vede i gesti di Mochi.
##
## ⚠️ **NIENTE DI TUTTO QUESTO È UN SISTEMA NUOVO.** Non c'è un raycast, non
## c'è un contatore salvato, non c'è uno stato «osservato» addosso a nessuno.
## C'è una LETTURA pura — la stessa disciplina di `coppia()`, `cricca()`,
## `fiducia()` — che dice, dati i numeri che il mondo già calcola, se quello
## che sta succedendo è ancora guardare o è diventato un'altra cosa.
##
## ## IL SEGNO VA SUL POSTO, MAI SULLA PERSONA
##
## Quello che resta non è «Cannella ti teme»: è un **marchio sul LUOGO** da
## cui guardavi (`Limbico.rivaluta(..., luogo)`, lo stesso meccanismo della
## catasta e dell'orto). Tre ragioni, e la terza è quella che decide:
##  1. è vero: chi si è sentito osservato ricorda il posto, non la faccia;
##  2. il gioco ha già tutto — l'estinzione a 0,12 al giorno, `evita()`,
##    `visita_serena()`, e **l'Accompagnare che è la chiave a forma di
##    giocatore**;
##  3. e perché un marchio su una PERSONA sarebbe un giudizio su di te che
##    tu non vedi e non puoi disfare, mentre un posto lo vedi: ci passi
##    davanti, e vedi qualcuno girare al largo.
##
## ## LE TRE VALVOLE, e ognuna chiude un modo di sbagliare
##
## **1. LA SOGLIA DI TEMPO.** Guardare qualcuno è normale e deve restarlo. Il
## segno comincia solo dopo `PAZIENZA` secondi di osservazione CONTINUA: sotto,
## non succede niente di niente, e il gioco è quello di ieri al bit.
##
## **2. LA DISTANZA.** Si è osservati da vicino, non dal prato. Oltre
## `RAGGIO` non conta — ed è lo stesso numero con cui il gioco ha già deciso,
## per un'altra ragione, che a quella distanza una faccia vale la pena
## puntarla (`Visitor.FACCIA_AL_GIOCATORE`).
##
## **3. ⚠️ E DEVE POTERTI VEDERE.** Chi dorme, chi è dentro casa, chi è in
## scena non si accorge di niente — e non deve. Senza questa valvola il
## giocatore verrebbe marchiato per essere stato fermo dietro una parete, che
## è il guasto che inverte il meccanismo: un segno che non si può collegare a
## un gesto insegna che il gioco marchia a caso.
##
## ## E CHI NON FA QUESTA COSA NON SE NE ACCORGE MAI
##
## Il Fiato Sospeso su una bestiola resta esattamente quello di ieri. Il
## giocatore che non passa i secondi della `PAZIENZA` incollato a una persona
## non incontra questo meccanismo in tutta la partita, e deve essere così.

## Quanto dura il guardare prima di diventare un'altra cosa, in secondi.
## ⚠️ Non è tarato a occhio ed è un numero GROSSO apposta: `Percezione.DURATA_SGUARDO`
## (3,2 s) è quanto dura una testa che si gira, cioè uno sguardo normale.
## Questo dev'essere fuori scala rispetto a quello, o il meccanismo scatterebbe
## su un'occhiata.
const PAZIENZA := 14.0

## Fin dove si è osservati. È `Visitor.FACCIA_AL_GIOCATORE`: la distanza sotto
## la quale il gioco aveva già deciso, per un'altra ragione, che la faccia di
## un chibi vale la pena puntarla verso di te.
const RAGGIO := 4.5

## Quanta calma serve perché guardare sia GUARDARE. Sotto, ti stai muovendo e
## sei solo uno che passa. È la soglia con cui `FiatoSospeso` decide che il
## prato si fida (`SOGLIA_FIDUCIA`), letta di là e non ricopiata.
const CALMA_MINIMA := 0.70

## ⚠️ **I DUE NUMERI SONO MISURATI CONTRO IL LIMBICO VERO, e la prima stesura
## li aveva scelti su un'idea sbagliata di come funziona.**
##
## L'idea era «accumulo graduale: tante volte, un pochino per volta». MISURATO
## (`Limbico.rivaluta` con un peso costante, marchio letto a ogni episodio):
##
##   peso 0.30 → non marchia AFFATTO   (il gioco ha un pavimento suo:
##                                      `absf(sentito) > 0.3`)
##   peso 0.42 → plateau a 0.344, **mai chiuso in 60 episodi**
##   peso 0.48 → plateau a 0.444, **mai chiuso in 60 episodi**
##   peso 0.52 → **chiuso in 3**
##
## Cioè: **l'accumulo graduale non esiste, e non per un difetto — per
## l'ABITUAZIONE.** `rivaluta` smorza ciò che si ripete uguale (è la stessa
## distinzione abitudine/sensibilizzazione che questo progetto documenta con
## un rapporto misurato di 4,5×), quindi ripetere lo stesso gesto porta a un
## plateau e basta. È psicologia giusta: ci si abitua a essere guardati.
##
## Quindi la scala non è «quante volte»: è **QUANTO A LUNGO**. Chi si ferma
## venti secondi non lascia niente, mai, per quante volte lo faccia. Chi ci
## sta un minuto e mezzo lascia un segno. La differenza fra osservare e
## FISSARE è la durata, e adesso il numero lo dice.
##
##   · sotto ~30 s oltre la pazienza → peso sotto il pavimento: **niente**
##   · verso i 45 s → marchia, ma abitua e si ferma sotto la soglia
##   · oltre ~70 s → arriva a chiudere il posto, in due o tre volte
const PESO_AL_SECONDO := 0.0083

## Il tetto di un episodio. ⚠️ Sta SOPRA `Limbico.SOGLIA_EVITAMENTO` apposta,
## ed è il contrario di quello che sembra prudente: sotto la soglia il posto
## non si chiuderebbe MAI (misurato: mai in 60 episodi), e la conseguenza
## sarebbe codice morto in partita con la suite verde — il guasto che questo
## progetto ha pagato nove volte. Quello che impedisce a un episodio solo di
## chiudere il posto non è il tetto: è che per arrivarci servono settanta
## secondi di sguardo ininterrotto, e che il marchio ci arriva in due o tre
## volte, non in una.
const TETTO_EPISODIO := 0.58


## È osservazione, adesso? Pura: entrano i numeri che il mondo calcola già.
##
## `da_quanto` è da quanti secondi dura senza interruzioni — lo tiene chi
## chiama, perché è lui che sa quando si è rotta.
static func osserva(distanza: float, calma: float, da_quanto: float,
		puo_vedermi: bool) -> bool:
	if not puo_vedermi:
		return false
	if not (is_finite(distanza) and is_finite(calma) and is_finite(da_quanto)):
		return false
	if distanza > RAGGIO or distanza < 0.0:
		return false
	if calma < CALMA_MINIMA:
		return false
	return da_quanto >= PAZIENZA


## Quanto pesa quello che è appena successo, su un posto. Zero finché
## l'osservazione non ha superato la pazienza, e mai più di `TETTO_EPISODIO`.
##
## ⚠️ **IL SEGNO È NEGATIVO MA NON È UNA PUNIZIONE**, e la differenza sta
## nella chiave: `Limbico.visita_serena()` lo dimezza, l'estinzione lo consuma
## di 0,12 al giorno, e l'Accompagnare esiste apposta. Chi si accorge di aver
## chiuso un posto lo può riaprire con gli stessi gesti con cui cura ogni
## altra paura di questo gioco — non ce n'è uno nuovo da imparare.
static func peso(da_quanto: float) -> float:
	if not is_finite(da_quanto) or da_quanto <= PAZIENZA:
		return 0.0
	return minf(TETTO_EPISODIO, (da_quanto - PAZIENZA) * PESO_AL_SECONDO)


## Il nome del posto per il Limbico, da una cella. ⚠️ Un NOME e non una
## coordinata: i marchi del Limbico sono su nomi («orto», «catasta»), e
## `perche_evita_dati` li sa già raccontare. La cella entra nel nome perché
## due posti diversi devono restare due posti diversi.
static func luogo_di(cella: Vector2i) -> String:
	return "sguardo_%d_%d" % [cella.x, cella.y]


## Vero se questo nome viene da qui. Serve a chi legge i marchi per sapere
## che quel posto non è un pezzo del mondo ma una cosa che è successa.
static func e_un_posto_guardato(luogo: String) -> bool:
	return luogo.begins_with("sguardo_")
