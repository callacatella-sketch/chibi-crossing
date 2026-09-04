class_name Dadi
extends RefCounted

## I DADI DEL VILLAGGIO — un seme di radice, e flussi NOMINATI che ne derivano.
##
## ────────────────────────────────────────────────────────────────────────
## IL DIFETTO CHE QUESTO FILE ESISTE PER CHIUDERE
## ────────────────────────────────────────────────────────────────────────
##
## Due corse della stessa misura, con gli stessi identici parametri, davano
## **0,31 e 1,77** righe di co-presenza per residente — un fattore 5,7. Non è
## un difetto di misura: è che **una giornata di questo villaggio non si può
## ripetere**. E senza ripetizione non esiste ablazione (spegnere un
## meccanismo e vedere cosa cambia), non esiste sensibilità (muovere una
## costante e vedere quanto pesa), non esiste confronto fra condizioni.
## Tutte le misure psicologiche del progetto — l'inerzia dell'insieme, la
## saturazione della deriva, il grappolo che si ferma a tre — restano
## **ipotesi ben poste finché una corsa non si può ripetere**.
##
## L'epicentro era una riga sola, in [VillagerBrain.gd](../scenes/npc/VillagerBrain.gd):
##
##     _rng.seed = hash(str(dna.get("name", "?"))) + Time.get_ticks_msec() % 1000
##
## Il dado di ogni vicino partiva dall'OROLOGIO. La regola del progetto era
## già scritta — «semi da `hash()` stabili, mai da `get_instance_id()`» — e
## quella riga la violava con l'unica sorgente che nessuno aveva pensato a
## vietare. Da quel dado esce `jitter()`, cioè **il dado congelato
## dell'agenda**: quello che in Fase 2 decide fra due azioni quasi pari.
##
## ────────────────────────────────────────────────────────────────────────
## ⚠️ LA PROPRIETÀ CHE TIENE IN PIEDI TUTTO: SI DERIVA, NON SI CONDIVIDE
## ────────────────────────────────────────────────────────────────────────
##
## Un flusso qui **non è un generatore condiviso**: è una *regola per
## derivarne uno* da una chiave. `rng(VILLAGGIO, "Ciliegia")` e
## `rng(VILLAGGIO, "Nocciola")` sono due generatori indipendenti, e nessuno
## dei due consuma i numeri dell'altro.
##
## Non è eleganza: è la ragione per cui l'ablazione può funzionare. Con un
## flusso condiviso, **aggiungere un chiamante sposta tutti i numeri a
## valle** — e allora spegnere un meccanismo per misurarlo cambierebbe anche
## tutti gli altri, cioè misurerebbe la somma di quel che si è spento e di
## quel che si è sfasato. Il banco delle repliche direbbe numeri, e i numeri
## non vorrebbero dire niente.
##
## Corollario operativo: **si può aggiungere un consumatore senza invalidare
## nessuna misura già presa.** Ed è sorvegliato da un caso di test, perché è
## la proprietà che si perde per prima quando qualcuno «ottimizza».
##
## ────────────────────────────────────────────────────────────────────────
## I FLUSSI, e perché sono quattro
## ────────────────────────────────────────────────────────────────────────
##
## Non sono categorie estetiche: sono **ciò che un banco può chiedere di
## tenere fermo separatamente**. Due misure che vogliono lo stesso villaggio
## ma due meteo diversi hanno bisogno che il meteo abbia un flusso suo.
##
##  · `VILLAGGIO` — le decisioni degli abitanti: l'agenda, il carattere, le
##                  chiacchiere, i gesti, i ritrovi. È il flusso che quasi
##                  tutte le misure psicologiche guardano.
##  · `AMBIENTE`  — il mondo: la generazione, il meteo, le creature, i
##                  raccolti, i luccichii. Cambia cosa c'è, non chi decide.
##  · `CORPO`     — il micro-movimento del rig: l'andatura, gli sguardi, i
##                  respiri. Non cambia nessuna decisione, ma cambia quello
##                  che si VEDE — e i provini lo vogliono fermo.
##  · `LIBERO`    — **dichiarato cosmetico**: particelle, sfarfallii, jitter
##                  che non può raggiungere nessuna misura. Non è seminato,
##                  ed è giusto così. Passa comunque da qui, e questa è
##                  l'unica ragione per cui esiste: un canale libero che
##                  passa da un'API **è censibile**; uno che chiama `randf()`
##                  a mano è indistinguibile da una svista.
##
## ────────────────────────────────────────────────────────────────────────
## DA DOVE VIENE LA RADICE
## ────────────────────────────────────────────────────────────────────────
##
## In ordine, e il primo che risponde vince:
##
## 1. `CHIBI_SEME` — i banchi, e l'autore. È la leva che rende ripetibile
##    una corsa.
## 2. il **salvataggio**: ogni villaggio nasce con la sua radice e se la
##    porta dietro per sempre (`village.json`, chiave `"seme"`). Così la
##    partita di chi gioca è **sua** — due villaggi non si somigliano — e
##    insieme è **ripetibile con sé stessa**, che è quello che serve per
##    diagnosticare un difetto segnalato da chi gioca.
## 3. se non c'è nessuna delle due (partita nuova, o salvataggio anteriore a
##    questa versione), se ne conia una con entropia VERA — ed è **l'unico
##    posto autorizzato del progetto** a usarla — e la si salva. Il villaggio
##    di chi aveva già una partita cambia un filo una volta sola, e poi è
##    stabile per sempre.
##
## ⚠️ Il degrado va SEMPRE verso «il gioco funziona»: se nessuno ha posato
## una radice, `radice()` se ne conia una da sé invece di restituire zero.
## Zero vorrebbe dire che tutti i villaggi del mondo nascono identici.


## I nomi dei flussi. Sono stringhe e non una enum apposta: finiscono in
## `CHIBI_SEME`, nei referti dei banchi e nei messaggi di guasto, e un
## intero lì dentro non si legge.
const VILLAGGIO := "villaggio"
const AMBIENTE := "ambiente"
const CORPO := "corpo"
const LIBERO := "libero"

## L'elenco è la fonte unica: un test lo confronta con i flussi realmente
## usati nei sorgenti, in tutti e due i versi (un flusso dichiarato e mai
## usato è una promessa vuota; uno usato e non dichiarato è un errore di
## battitura che non fallisce da nessuna parte).
const FLUSSI := [VILLAGGIO, AMBIENTE, CORPO, LIBERO]

## La radice, e se qualcuno l'ha posata. Sono due variabili e non una perché
## **zero è una radice legittima** (un banco può chiedere `CHIBI_SEME=0`) e
## non deve essere indistinguibile da «nessuno ha ancora deciso».
static var _radice := 0
static var _posata := false


## La radice di questa corsa. Vedi «DA DOVE VIENE LA RADICE».
static func radice() -> int:
	if not _posata:
		var da_ambiente := OS.get_environment("CHIBI_SEME")
		if da_ambiente != "":
			posa_radice(int(da_ambiente))
		else:
			posa_radice(conia())
	return _radice


## La posa chi possiede la radice: il caricamento del villaggio, o un banco.
## È idempotente nel valore ma non nel tempo: chi la chiama dopo che i primi
## dadi hanno già tirato sposta la vita di quei dadi soltanto, e ottiene una
## corsa che non è né la vecchia né la nuova. Si posa PRIMA.
static func posa_radice(s: int) -> void:
	_radice = s
	_posata = true


## Se la radice è già stata posata da qualcuno (l'ambiente, o il
## salvataggio). Serve a `BuildSystem`: un villaggio che ne ha già una non
## deve farsela scavalcare dal caricamento.
static func radice_posata() -> bool:
	return _posata


## ⚠️ L'UNICO POSTO DEL PROGETTO AUTORIZZATO A USARE ENTROPIA VERA, e serve
## a coniare la radice di un villaggio NUOVO. Ogni altra sorgente di caso
## nel gioco deve poter essere ricondotta a questo numero: è quello che
## rende una giornata ripetibile.
static func conia() -> int:
	var g := RandomNumberGenerator.new()
	g.randomize()
	return int(g.randi())


## Il seme di un dado, derivato. Deterministico fra avvii, fra piattaforme e
## fra ORDINI DI CREAZIONE — cioè non dipende da chi ha chiamato prima.
##
## Si passa per una stringa e per `hash()` perché è l'idioma già scritto in
## questo progetto («semi da `hash()` stabili»), è stabile per contratto, e
## soprattutto **si legge**: chi diagnostica una divergenza vuole poter
## stampare la chiave e riconoscerla.
static func seme(flusso: String, chiave) -> int:
	return hash("%s|%s|%d" % [flusso, str(chiave), radice()])


## Il dado di (flusso, chiave). Chiamarla due volte con gli stessi argomenti
## dà due generatori che partono dallo stesso punto: è voluto, ed è il modo
## in cui un banco può ricominciare una vita da capo.
##
## ⚠️ Chi ne tiene uno se lo TIENE: rifarlo a metà partita lo rimanda
## indietro nel tempo — ripetibile, e falso. (È la trappola che
## `prova_identico._semina_cervelli` aveva già dovuto chiudere a mano con un
## registro di chi era già passato di lì.)
static func rng(flusso: String, chiave) -> RandomNumberGenerator:
	var g := RandomNumberGenerator.new()
	g.seed = seme(flusso, chiave)
	return g


## Il canale COSMETICO, dichiarato tale. Non è seminato: due corse lo vedono
## diverso, e va bene — se il suo numero potesse raggiungere una misura non
## sarebbe cosmetico. Passa da qui solo per essere censibile.
static func libero() -> RandomNumberGenerator:
	var g := RandomNumberGenerator.new()
	g.randomize()
	return g


## Rimette il modulo com'era. Serve a un banco che fa più repliche dentro lo
## stesso processo: senza, la seconda replica erediterebbe la radice della
## prima e il banco misurerebbe una sola corsa ripetuta.
static func dimentica() -> void:
	_radice = 0
	_posata = false
