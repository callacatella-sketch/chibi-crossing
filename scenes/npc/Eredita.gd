extends RefCounted

## LA TRASMISSIONE — quello che un cucciolo si porta via dai suoi.
##
## Un bambino nato in questo villaggio eredita UNA cosa sola, e quella cosa è
## un LUOGO: il punto in cui i suoi genitori si ritrovavano mentre lui
## cresceva. Da grande, quando cerca dove sedersi, quel punto diventa una
## delle ancore — sotto il ritrovo suo, sopra casa sua, e **mai** sopra
## Mochi.
##
## Non c'è un momento in cui succede. Nessun toast, nessuna lettera, nessuna
## riga sul filo, nessun segno sopra la testa. C'è un adulto che un giorno si
## siede nell'angolo in cui stavano i suoi — e il giocatore, se quella
## panchina l'ha messa lui, se ne accorge o non se ne accorge. È la stessa
## grammatica della ricevuta della Fase 5 e del posto vuoto: **l'unica
## conseguenza è invisibile**.
##
## Questo file è **puro**: nessuno stato, nessun nodo, nessun orologio,
## nessun dado. Entra il filo di qualcuno (il Dictionary che `Legami` tiene e
## salva) più quanto è cresciuto, esce un bool o un punto. `Legami` fa
## **solo** la persistenza e non decide niente — è la disciplina di
## `Cricche`, `Deriva`, `Gesti`, `Regia`, ed è quella che rende provabile
## headless tutto ciò che decide.
##
## ⚠️ **E NON PRECARICA `Legami.gd`.** Legami può precaricare questo file; il
## contrario chiude il ciclo — e un ciclo di preload non dà un errore: fa
## morire il parse **in silenzio** nei test headless. È la regola già scritta
## per Strati/Scavi.
##
## ============================================================
## PERCHÉ UN LUOGO, E NON UN TRATTO NÉ UN'ORA
## ============================================================
## Le altre due cose che si sarebbero potute trasmettere — la fascia oraria e
## l'abitudine dell'agenda — **sono già trasmesse**, e non da qui: l'ora è
## `chibi::finestra_di_sonno(indole, quirk)`, e indole e quirk passano già da
## `ChibiDNA.incrocia`; i pesi dell'agenda sono già mediati fra i genitori.
## Ereditarle qui sarebbe **una seconda risposta alla stessa domanda**, in
## disaccordo con la prima il giorno che i due dadi divergono — che è
## esattamente la tabella gemella che questo progetto ha già pagato tre
## volte.
##
## Il posto è l'unica delle tre che non duplica niente, ed è anche l'unica
## che si vede in un fotogramma.
##
## ============================================================
## LA MEMORIA, NON LO SPECCHIO — si impara UNA volta sola
## ============================================================
## Il posto si incide una volta e poi non si tocca più, nemmeno se i genitori
## cambiano angolo, nemmeno se il loro ritrovo muore, nemmeno se se ne vanno.
## Se si riscrivesse ogni giorno, i genitori resterebbero una **sorgente
## permanente** e il figlio un riflesso: non sarebbe un'eredità, sarebbe un
## guinzaglio a due estremità: e in questo gioco i guinzagli non esistono
## (vedi `Visitors.SPOSTA_MAX`, che è la lunghezza di quello che NON deve
## esserci).
##
## ⚠️ È la stessa distinzione **evento/livello** che tiene in piedi il
## perdono collettivo, ed è la mutazione contro cui questo file va provato:
## togliere la riga «ce l'ha già» da `puo_imparare` e vedere arrossire
## `_si_impara_UNA_volta_sola`.
##
## ============================================================
## SI IMPARA GIORNO PER GIORNO, ALLA PRIMA OCCASIONE BUONA
## ============================================================
## E non con una fotografia a un giorno fisso — «il giorno in cui compie
## GIORNI_ADULTO si guarda il ritrovo dei suoi». Non è una comodità: quella
## forma crea un accoppiamento **muto** fra `Legami.GIORNI_ADULTO` (14) e
## `Cricche.MEMORIA` (21), cioè fra quanto ci mette a crescere un cucciolo e
## quanto indietro il registro degli incontri conserva le righe. Oggi regge
## per sei giornate di margine, e si rompe in silenzio il giorno che qualcuno
## alza `GIORNI_ADULTO` per un'altra ragione: la fotografia troverebbe un
## registro potato e non inciderebbe più niente, mai, senza un errore.
##
## Chiedendolo **ogni giorno** finché è cucciolo, l'unico requisito è che i
## suoi si siano ritrovati almeno una volta durante la sua infanzia. Questa è
## la scelta che toglie una mina invece di aggiungerne una.
##
## ============================================================
## NIENTE VERSO, QUINDI NIENTE CLASSIFICA
## ============================================================
## Quello che entra nel filo sono **due float**, e basta: `[x, z]`.
##
## ⚠️ **Niente campo `g` e niente campo `da`**, e non è una svista. Il giorno
## non lo leggerebbe nessuno; e «chi glielo ha insegnato» è già
## `filo["padre"]` / `filo["madre"]` — scriverlo una seconda volta sarebbe la
## tabella gemella, e soprattutto ricreerebbe un'attribuzione che **la
## sorgente non contiene**: le righe di `Cricche` sono senza verso (i due nomi
## in ordine alfabetico), quindi da lì «chi ha insegnato a chi» è
## strutturalmente non ricavabile. Da un campo `da` a «di chi sei figlio si
## vede da dove ti siedi» c'è un passo solo, e non si fa.
##
## ============================================================
## IL POSTO NON È UNA PERSONA
## ============================================================
## L'ancora è un punto congelato sul prato, non un corpo: i genitori possono
## traslocare, litigare, partire col fagotto — nessuno li insegue. È la
## stessa ragione per cui sono sicure le altre ancore di `_panchina_per`
## (`_ancora_ricordo` punta a un'opera, `_ancora_ritrovo` al punto medio
## delle CASE): una panchina non cammina.
##
## E il giocatore può sempre rimediare: se l'angolo dei suoi è spoglio, ci si
## mette una panchina; se la demolisce, `_free_bench` non trova niente e la
## cascata ripiega su casa — **l'adulto si siede come si è sempre seduto, non
## resta in piedi**. L'eredità AGGIUNGE, mai toglie: senza quel ripiego un
## cucciolo starebbe *peggio* per aver avuto dei genitori, che è l'esatto
## contrario del punto.
##
## ============================================================
## ⚠️ FIN DOVE ARRIVA L'ANCORA — l'aritmetica che decide se questa
## meccanica si può chiamare «IL POSTO dei suoi»
## ============================================================
## Il punto che si eredita **non è una panchina**: è la media dei punti-medi
## fra i due corpi quando si sono incontrati (`Cricche.rapporto_da` →
## `dove`), cioè un punto in mezzo al prato. E l'adulto **non abita a casa
## dei suoi**: `Visitors.accogli_nato` gli dà `_free_house()`, una casa
## qualunque, e il debito è già dichiarato per iscritto lì (la cella è la
## chiave di unicità del letto, e dare al nato la soglia della madre lo
## cancellava dal salvataggio).
##
## Il quinto anello quindi non porta il corpo SUL punto: sposta l'ancora da
## casa verso il punto di al massimo `Visitors.SPOSTA_MAX`, e da lì
## `_free_bench` cerca entro `Visitors.RAGGIO_SEDUTA` **la più vicina
## ALL'ANCORA, non al punto**. Da quelle due righe escono DUE confini, e non
## sono lo stesso numero — MISURATI sulla `_free_bench` di produzione da
## `test_eredita._fin_dove_arriva_l_ancora`, che li ricava dai numeri veri
## invece di riscriverli:
##
## | | dist(casa, punto) fin dove la seduta SUL punto vince | |
## |---|---|---|
## | c'è una seduta anche vicino a casa | **11 m** | il confine è `2 · SPOSTA_MAX` |
## | il punto è l'unica seduta in giro | **22 m** | il confine è `SPOSTA_MAX + RAGGIO_SEDUTA` |
##
## Il secondo è il limite di CANDIDATURA: oltre `SPOSTA_MAX + RAGGIO_SEDUTA`
## una seduta piantata sul punto esce dal raggio di `_free_bench`, e oltre
## `SPOSTA_MAX + RAGGIO_SEDUTA + POSTO_LARGO` (**26,5 m**) ne esce anche
## qualunque seduta entro `POSTO_LARGO` dal punto — cioè il cancello
## d'arresto G3 («la seduta scelta cade entro `POSTO_LARGO` dal posto
## appreso») è zero **per costruzione**, non per sfortuna.
##
## ⚠️ **MA QUELLO CHE DECIDE IN PARTITA È IL PRIMO, ed è meno della metà.**
## L'adulto una casa ce l'ha, e chi gioca le panchine le mette dove passa:
## appena esiste una seduta dalle parti di casa, l'ancora — che sta sempre a
## `SPOSTA_MAX` da casa — la trova più vicina di quella sul punto non appena
## `dist(casa, punto)` supera **12 m**. Sopra quella distanza questa
## meccanica non sta consegnando «il posto dei suoi»: sta consegnando «si
## siede da quella parte», che è un'altra frase.
##
## ⚠️ **E LA CURA NON È ALZARE `SPOSTA_MAX`.** Raddoppiarlo raddoppia tutti e
## due i confini e allunga il guinzaglio delle **altre tre** ancore, la cui
## ragione scritta non è un raggio ma che *nessuno cammini verso una
## PERSONA*. Il lavoro vero è `accogli_nato`: il debito è che il cucciolo
## non abita dai suoi, e sta già dichiarato nel sorgente di `Visitors`.
##
## ============================================================
## ⚠️ IL CERCHIO DEL FALÒ DICE LA STESSA COSA DALL'ALTRA PARTE — E I DUE
## NON SI FONDONO
## ============================================================
## Al falò il cucciolo siede **fra i suoi**; da grande va **nel posto dei
## suoi**. Sono due canali indipendenti, in due file diversi, che leggono due
## sorgenti diverse (`Legami.genitori_di` di là, `Cricche.ritrovo_di` di
## qua), e **nessuno dei due sa dell'altro**. La risonanza è voluta.
##
## Il primo che rifattorizza li vorrà fondere in una funzione sola «perché
## dicono la stessa cosa»: da quel giorno ci sarà una tabella gemella dove
## oggi ci sono due letture indipendenti dello stesso villaggio. **Non si
## fondono.**
##
## ============================================================
## ⚠️ E `Sentieri.gd` NON SI LEGGE — nemmeno «per il giorno che servirà»
## ============================================================
## La tela dell'usura sembra la fonte naturale per «dove passa questa
## famiglia», e non lo è: `PESO_MOCHI` e `PESO_RESIDENTE` scrivono lo
## **stesso canale, sommati e indistinguibili**, quindi la persona lì dentro
## non c'è mai stata scritta e nessuna ottimizzazione può inventarla. In più
## quel render target risponde tre cose diverse in tre ambienti (nero in
## headless, bianco se non è mai stato disegnato, la tela vera in partita):
## una guardia appoggiata lì passerebbe dicendo il contrario del vero, che è
## peggio di una guardia muta.
##
## E non se ne scrive nemmeno l'accessore: un'API senza lettori è la forma di
## debito che questo progetto ha già pagato sei volte (`giorno_partenza`
## scritto e mai letto, 247 righe di somatizzazione complete e mai eseguite).
## Se un giorno servirà davvero, la forma di quella lettura si scrive in
## CLAUDE.md, non nel codice.


## LA CHIAVE SUL FILO, in un posto solo.
##
## Non è una costante di taratura: è lo **schema**. Chi la scrivesse a mano
## da un'altra parte creerebbe un filo che si legge con una stringa e si
## scrive con un'altra — cioè un'eredità che si incide e non si ritrova, e
## solo a partita ricaricata.
const CHIAVE_POSTO := "posto_dei_suoi"


# =========================================================================
# LE DUE FINESTRE — imparare da piccoli, sedersi da grandi
# =========================================================================
# Sono complementari per costruzione e non si sovrappongono mai: `crescita`
# è `clampf(giorni / GIORNI_ADULTO, 0, 1)`, quindi vale esattamente 1.0 al
# compimento e mai di più. Sotto si può imparare; da lì in su l'ancora è
# accesa. Non c'è un buco e non c'è un doppio.
#
# ⚠️ **E il cancello è `crescita`, mai un «14» riscritto di qua.** La soglia
# dell'età adulta vive in `Legami.GIORNI_ADULTO` e ha già la sua rampa
# (`Legami.crescita`): ricopiare il numero in questo file sarebbe la
# quattordicesima tabella gemella del progetto, e questa meccanica ha per
# contratto **zero costanti nuove**. Per la stessa ragione la firma prende un
# `float` e non un `int` di giornate: due interi affiancati (`giorni`,
# `giorni_adulto`) si scambiano di posto senza che niente se ne accorga —
# è la lezione di `t.almost(a, b, messaggio, tolleranza)`.


## PUÒ IMPARARE, OGGI? Vero solo per un cucciolo **nato qui**, che **non ha
## già imparato**, e che **sta ancora crescendo**.
##
## ⚠️ «Solo da cuccioli» non è prudenza: un adulto che raccogliesse adesso
## l'angolo dei suoi non starebbe ricordando l'infanzia — starebbe imitando
## due persone che vede oggi, che è un'altra frase e vorrebbe un'altra
## meccanica.
##
## E un filo che non esiste non impara niente: `{}` risponde `false` alla
## prima riga. È la metà pura della difesa contro i fili fantasma — l'altra
## metà è che il chiamante interroghi `_fili.has(...)` e **mai `_filo()`**,
## che il filo lo creerebbe.
static func puo_imparare(filo: Dictionary, crescita: float) -> bool:
	if not bool(filo.get("nato", false)):
		return false
	if filo.has(CHIAVE_POSTO):
		return false
	if not is_finite(crescita):
		return false
	return crescita < 1.0


## COSA IMPARA OGGI: il punto da incidere, oppure `null`.
##
## `rit` è il referto di `Cricche.ritrovo_di(padre, madre)` — `{}` quando i
## suoi non hanno (o non hanno più) un ritrovo vivo. `null` vuol dire **«oggi
## no»**, mai «mai più»: domani si richiede, e finché è cucciolo c'è tempo.
##
## ⚠️ **Si interroga `ritrovo_di`, mai `compagni()`.** La seconda legge una
## cache (`Cricche._coppie`) che si riempie solo dentro `giro_del_giorno`, ed
## è **vuota** su una partita appena caricata prima del primo giro: la
## trasmissione morirebbe in silenzio proprio nel momento in cui deve
## funzionare. `ritrovo_di` rifà il conto dal registro ogni volta.
##
## E i due nomi non hanno bisogno di una guardia: se un genitore manca il suo
## nome è `""`, e nel registro non esiste nessuna riga con un nome vuoto —
## `ritrovo_di` risponde `{}` da sé. Una guardia che nessun test può far
## fallire è una guardia che non c'è.
static func da_imparare(filo: Dictionary, crescita: float,
		rit: Dictionary) -> Variant:
	if not puo_imparare(filo, crescita):
		return null
	return posto_dal_ritrovo(rit)


## INCIDE il posto sul filo, e torna `true` se l'ha fatto.
##
## Se non si può imparare — o se il punto non è un punto — **il filo non
## viene toccato di un bit**: nessuna chiave scritta a metà, niente da
## migrare, niente che possa restare appeso. Il chiamante non ha nessuna
## decisione da prendere e nessun formato da conoscere: è per questo che la
## codifica sta qui dentro e non nel suo salvataggio.
static func incidi(filo: Dictionary, crescita: float, dove: Vector3) -> bool:
	if not puo_imparare(filo, crescita):
		return false
	var riga: Variant = posto_da_salvare(dove)
	if riga == null:
		return false
	filo[CHIAVE_POSTO] = riga
	return true


## L'ANCORA: il posto dei suoi **se ha finito di crescere**, altrimenti
## `null`.
##
## Si accende al compimento e non prima. Un cucciolo che si sedesse nel posto
## dei suoi mentre ancora li ha davanti agli occhi non racconterebbe niente:
## è quando quel gesto sopravvive alle persone che diventa un'eredità.
static func posto_ereditato(filo: Dictionary, crescita: float) -> Variant:
	if not is_finite(crescita) or crescita < 1.0:
		return null
	return posto_sul_filo(filo)


# =========================================================================
# LA FORMA SUL DISCO — due float, e mai un Vector3
# =========================================================================
# ⚠️ **UN `Vector3` NON SOPRAVVIVE AL JSON, E IL DIFETTO SI VEDE SOLO A
# PARTITA RICARICATA.** MISURATO (Godot 4.7.1):
#
#     JSON.stringify({"p": Vector3(1, 0, 2)})  ->  {"p":"(1.0, 0.0, 2.0)"}
#
# cioè al ritorno il tipo è `String`, non `Vector3`. Il filo va su disco
# intero (`Legami.save_extra` restituisce `_fili` **per riferimento**), quindi
# dev'essere JSON-safe **già in RAM**: è la regola 2 della Stratigrafia. Con
# un `Vector3` dentro, l'eredità funzionerebbe per tutta la sessione in cui è
# nata e sparirebbe al primo riavvio — e chi la prova la prova sempre nella
# prima sessione.
#
# La `y` non si salva perché non c'è: il villaggio si siede sul piano, e
# `_free_bench` misura le distanze lì. Salvarla vorrebbe dire portarsi dietro
# la quota di un terreno che nel frattempo il giocatore ha spianato.


## Da un punto alla riga da incidere: `[x, z]` di float, o `null`.
static func posto_da_salvare(dove: Vector3) -> Variant:
	if not is_finite(dove.x) or not is_finite(dove.z):
		return null
	return [float(dove.x), float(dove.z)]


## Dalla riga incisa al punto, o `null` se sul filo non c'è niente di
## leggibile.
##
## ⚠️ **`null`, e MAI `Vector3.ZERO`.** L'origine è un punto vero del
## villaggio — ci passa il fiume, e non è lontana dalla piazza (sta scritto
## per esteso sopra `Visitors.posizione_mochi`). Usarla come «non lo so»
## vorrebbe dire mandare l'ancora nell'acqua per chiunque abbia un filo senza
## posto, cioè per quasi tutti, e nessuno andrebbe mai a guardare lì.
##
## Il degrado va SEMPRE verso ieri: una riga di formato ignoto, troncata,
## infinita o scritta da una versione che salvava un `Vector3` risponde
## `null`, e da lì in giù il vicino si siede come si è sempre seduto.
static func posto_sul_filo(filo: Dictionary) -> Variant:
	if not filo.has(CHIAVE_POSTO):
		return null
	var riga: Variant = filo[CHIAVE_POSTO]
	if riga is not Array:
		return null
	var a: Array = riga
	if a.size() != 2:
		return null
	# si guarda il TIPO e non ci si fida di `float()`: su una stringa
	# risponde 0.0 senza dire niente, e 0.0 è un punto vero del villaggio.
	# (Dal JSON i numeri tornano `float`; una riga scritta a mano da un banco
	# può portare degli `int`, e vanno bene tutti e due.)
	if not (a[0] is float or a[0] is int):
		return null
	if not (a[1] is float or a[1] is int):
		return null
	var x := float(a[0])
	var z := float(a[1])
	if not is_finite(x) or not is_finite(z):
		return null
	return Vector3(x, 0.0, z)


## Dal referto di `Cricche.ritrovo_di` al punto, o `null`.
##
## Il referto è `{giorni, dove, ora, ultimo}`; di tutto quello che sa, qui
## serve **solo `dove`**. Le giornate e l'ora restano di là: l'ora è già
## trasmessa dal genoma del sonno (vedi la testata), e il numero di giornate
## sarebbe una misura di «quanto sono affiatati i tuoi», cioè un giudizio su
## due persone messo nel filo di una terza.
static func posto_dal_ritrovo(rit: Dictionary) -> Variant:
	if rit.is_empty() or not rit.has("dove"):
		return null
	var d: Variant = rit["dove"]
	if d is not Vector3:
		return null
	var v: Vector3 = d
	if not is_finite(v.x) or not is_finite(v.z):
		return null
	return Vector3(v.x, 0.0, v.z)
