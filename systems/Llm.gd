class_name Llm
extends RefCounted

## IL CUORE CHE SCRIVE — e la domanda si fa QUI, una volta sola.
##
## Il gioco può avere dentro un modello linguistico piccolo, in locale, che
## scrive di suo pugno le lettere del Gufo, i pensieri e i discorsi. Può.
## **Il gioco deve funzionare IDENTICO senza**: chi non ce l'ha ha un gioco
## meno sorprendente, non un gioco a cui manca un pezzo. Nessuna schermata di
## errore, nessun caricamento che si pianta, nessun testo che non arriva —
## le lettere scritte a mano ci sono e restano.
##
## Come fa il gioco a saperlo: la GDExtension registra la classe nativa
## `LlmLocale` SOLO se il cuore è stato compilato con `scons llm=yes`.
## L'esistenza della classe **è** il segnale — non c'è un file di
## configurazione da tenere allineato, non c'è un flag salvato che possa
## mentire, e un binario compilato senza llama.cpp non ha nemmeno il codice
## per rispondere di sì.
##
##     if Llm.disponibile():
##         var cuore = Llm.apri()
##         ...
##
## LE DUE REGOLE DI CHI CI COSTRUISCE SOPRA:
##
## 1. **Il ramo senza è quello NORMALE, e si scrive per primo.** Non
##    «altrimenti mostra un errore»: altrimenti succede la cosa bella di
##    prima. Se una funzione non ha una risposta sensata senza il modello,
##    quella funzione non va scritta.
## 2. **Non si chiede mai `ClassDB.class_exists` altrove.** È la stessa
##    regola delle fonti uniche: la domanda ha una casa sola, così il giorno
##    in cui la risposta dipenderà anche da altro (un modello scaricato, una
##    impostazione del giocatore, poca memoria) cambia un posto e non venti.
##
## ⚠️ **E `disponibile()` NON vuol dire «il modello si aprirà».** Dice una
## cosa sola: che questo binario ha llama.cpp dentro. Il modello può poi non
## aprirsi per ragioni che nessuno può sapere prima — il file non c'è, non è
## sano (il portiere, `llm_gguf.h`), sfonda il tetto di RAM dell'autore,
## oppure **questa macchina non ha la memoria libera** per tenerlo senza
## mandare in swap il gioco (`Config::riserva_byte`). Tutti e quattro i casi
## finiscono nello stesso posto — `LlmLocale.stato()` che diventa `GUASTO` e
## una `diagnosi` leggibile nei log — e tutti e quattro sono **normali**: chi
## li incontra ha il gioco di sempre, quello con le lettere scritte a mano.
## Nessuno deve mostrarli a chi gioca.

## Il nome della classe nativa registrata da `src/llm_ponte.cpp`.
const CLASSE := "LlmLocale"


## C'è un cuore che scrive?
static func disponibile() -> bool:
	return ClassDB.class_exists(CLASSE)


## Il ponte, oppure `null` — e `null` non è un guasto, è la normalità.
## Non stampa niente: un avviso a ogni chiamata insegnerebbe a chi gioca
## (e a chi sviluppa) che manca qualcosa, e non manca niente.
static func apri() -> Object:
	if not disponibile():
		return null
	return ClassDB.instantiate(CLASSE)


## Una riga leggibile per i log e per i provini: cosa c'è dentro questo
## binario. Senza il modulo dice che non c'è, e va benissimo così.
static func riga_di_stato() -> String:
	var cuore := apri()
	if cuore == null:
		return "llm: assente (il gioco gira con i testi scritti a mano)"
	return "llm: %s — backend %s" % [str(cuore.versione()), ", ".join(cuore.backend())]


# =========================================================================
# IL MODELLO — dove sta, e se si accende
# =========================================================================
#
# `disponibile()` dice che questo BINARIO sa scrivere. Non dice che ci sia
# qualcosa da far scrivere: i pesi non entrano nel repository e non entrano
# nel `.pck` (sono gigabyte, e Git li conserverebbe per sempre). Perciò le
# due domande sono due, e stanno tutte e due qui — la casa unica della
# domanda «c'è un cuore che scrive?» è anche la casa di «e ha di che».

## Come si chiama il modello quando ce l'ha il giocatore. Un nome fisso e non
## una scansione della cartella: un `.gguf` qualunque trovato per caso è il
## modo in cui il gioco finisce a caricare due gigabyte che non sono suoi.
const NOME_MODELLO := "pensieri.gguf"

## E dove lo si mette. `user://` è l'unico posto scrivibile che esiste su
## tutte e tre le piattaforme, e `globalize_path` lo trasforma nel percorso
## VERO su disco — llama.cpp apre un file, non una risorsa di Godot.
const CARTELLA_MODELLI := "user://modelli"

## LO SHA-256 DEL MODELLO CHE SPEDIAMO — gemma-3-4b-it Q4_K_M, 2 489 757 856
## byte. Misurato sul file vero il 2026-08-13, tre letture identiche.
##
## Vale SOLO per il modello dentro il pacchetto (vedi `impronta_attesa`): è
## l'unico file di cui conosciamo i byte, e conoscerli chiude per costruzione
## il residuo dichiarato in `src/llm_gguf.h` — il bit girato dentro i pesi,
## che né il portiere né llama vedono, e gli iperparametri con invarianti che
## nessun controllo di forma può dedurre e che finiscono in `abort()`.
##
## ⚠️ **CAMBIA CON IL MODELLO, E DEVE ROMPERE SUBITO.** Chi sostituisce il
## `.gguf` spedito senza rifare questa riga si ritrova la funzione spenta per
## tutti, in silenzio (`Pensieri` stampa una riga nei log e il gioco continua
## con le lettere scritte a mano). Si ricalcola così:
##     shasum -a 256 pensieri.gguf
const IMPRONTA_SPEDITO := "882e8d2db44dc554fb0ea5077cb7e4bc49e7342a1f0da57901c0802ea21a0863"


# =========================================================================
# DA DOVE ARRIVA, QUANTO PESA, QUANTO CHIEDE
# =========================================================================
#
# Dal 2026-08-13 il modello **non viaggia più dentro il pacchetto**: si
# scarica al primo uso, quando chi gioca accende «Il villaggio pensa». Il
# gioco resta piccolo per tutti, e chi non userà mai la funzione non paga
# niente — né in byte scaricati, né in spazio sul disco.
#
# La ragione che l'ha forzata è tecnica e non si aggira: GitHub non accetta
# allegati sopra i 2 GiB e il pacchetto col modello ne pesava 2,4 (il modello
# da solo 2,32 GiB). Le conseguenze legali di questo cambio — chi accetta i
# Gemma Terms of Use, e quando — stanno in `docs/LICENZA_MODELLO.md`, e la
# risposta è: **il giocatore, scaricando**. Perciò glieli mostra la
# schermata, prima del primo byte.
#
# ⚠️ **QUESTE TRE RIGHE SONO LA CARTA D'IDENTITÀ DEL MODELLO E STANNO QUI.**
# Erano in `.github/workflows/release.yml` (che lo scaricava per metterlo nel
# pacchetto) e da lì non le può leggere il gioco. Adesso è il gioco che
# scarica, quindi la casa è questa — la stessa in cui vivono già il nome del
# file e l'impronta, e per la stessa ragione: due tabelle gemelle divergono
# in silenzio, e quando divergono la funzione non si rompe, si **spegne**.

## Come si chiama il modello davanti a una persona. **Non si traduce**: è un
## nome proprio, e chi lo cerca su internet lo cerca così.
const MODELLO_NOME := "Gemma 3 4B IT"
const MODELLO_DI_CHI := "Google DeepMind"

## Il nome del posto da cui arriva, come lo scriverebbe chi ci va col
## browser. Si mostra a chi gioca: «da huggingface.co» dice più di un URL
## lungo tre righe, e dice la stessa cosa.
const SORGENTE_CASA := "huggingface.co"

## QUANTO PESA, in byte esatti. VERIFICATO il 2026-08-13 sull'intestazione
## `content-length` della sorgente vera (e la stessa risposta porta
## `x-linked-etag` uguale, byte per byte, a `IMPRONTA_SPEDITO`).
##
## Serve a dirlo a chi gioca prima di chiederglielo: nella schermata che lo
## offre (`OffertaModello`) e nella pagina delle Note legali, che sono le due
## che devono raccontare la stessa cosa allo stesso modo.
##
## ⚠️ **E DEVE COMBACIARE CON `Scarico.DIMENSIONE`**, che è lo stesso numero
## visto dall'altra parte (quanti byte deve portare a casa il corriere). Sono
## due case per due domande diverse — «cos'è» qui, «dove andarlo a prendere»
## di là — ma il numero è uno solo, e due costanti che dicono lo stesso numero
## divergono in silenzio: qui il guasto sarebbe una schermata che promette un
## peso e un download che ne porta un altro. Il legame lo tiene stretto
## un'asserzione in `tests/cases/test_offerta_modello.gd`, e la strada giusta
## il giorno che qualcuno rimette mano a questa fase è farne sparire una.
const BYTE_MODELLO := 2489757856

## QUANTA MEMORIA CHIEDERÀ, quando lo si aprirà. 2640 MiB: è
## `stima_byte_totali(gemma-3-4b, 2048)` — la stessa stima che fa il portiere
## in C++, alla finestra che il gioco usa davvero (`Pensieri.FINESTRA`).
##
## ⚠️ **NON È UN NUMERO DECORATIVO: È IL CANCELLO CHE EVITA UN DOWNLOAD PER
## NIENTE.** Su una macchina che non ha questa memoria il modello non si apre
## (`Traduttore::_carica`, riserva compresa) e il villaggio non pensa lo
## stesso: chiedere prima due gigabyte e mezzo di rete e di disco sarebbe la
## cosa peggiore che questa fase possa fare a qualcuno. La domanda si fa
## PRIMA, in `Capienza.della_memoria()`.
##
## ⚠️ **PERCHÉ UNA COSTANTE E NON UNA MISURA.** Il numero vero lo dà
## `LlmLocale.esamina(percorso)["byte_stimati_2k"]` — leggendo il file, che
## però qui ancora non c'è: è esattamente il file che stiamo decidendo se
## scaricare. L'unica alternativa sarebbe scaricarlo per sapere se conveniva
## scaricarlo. La costante si verifica quando il file arriva:
## `tools/misura_modello.gd` la confronta con la stima vera, e `Pensieri`
## stampa la diagnosi del portiere se un giorno divergessero.
##
## E il verso dell'errore è scelto: la stima del portiere **sbaglia per
## eccesso** (`llm_gguf.h`: conta la cache a finestra piena su tutti gli
## strati, e gemma-3 ha la finestra scorrevole). Sovrastimare, al peggio, non
## offre il download a una macchina che ce l'avrebbe fatta di misura;
## sottostimare lo offre a una che non ce la fa. Fra i due si sceglie il
## primo, e non è un pareggio.
const RAM_MODELLO := 2640 * 1024 * 1024


## I PESI SONO SU QUESTO DISCO? La domanda ha un nome perché ha due lettori
## (la casella del pannello e la schermata che chiede) e perché
## `percorso_modello() != ""` letto in due posti diventa, prima o poi, due
## regole diverse.
##
## ⚠️ **DOVE ANDARLO A PRENDERE non sta qui**: sta in `Scarico` (repository,
## revisione, indirizzo, e la domanda `Scarico.serve()`). Questo file dice
## **cos'è** il modello e dove vive una volta a casa; quello dice **come ci
## arriva**. Sono due domande diverse e nessuno dei due ricopia l'altro.
static func modello_in_casa() -> bool:
	return percorso_modello() != ""


## IL MODELLO SPEDITO: dove finisce dentro il pacchetto, o "" se non c'è.
##
## **Accanto all'eseguibile, mai dentro il `.pck`**: llama.cpp apre un
## percorso su disco con `fopen`/`mmap`, e una risorsa impacchettata non ne
## ha uno. Non c'è nemmeno la via di mezzo — copiarselo in `user://` al primo
## avvio vorrebbe dire due volte due gigabyte e mezzo sul disco di chi gioca.
##
## «Accanto» però non è la stessa cartella su tutti e tre i sistemi, e la
## differenza non è cosmetica:
##  · **macOS** — l'eseguibile sta in `<gioco>.app/Contents/MacOS/`, e lì un
##    file di dati non ci può stare: `codesign` sigilla il bundle e tutto ciò
##    che finisce fuori da `Contents/Resources/` diventa «unsealed contents»,
##    cioè una firma che non verifica e una notarizzazione che non passa
##    (vedi `RELEASE_SIGNING.md`). Il posto giusto è `Contents/Resources/`,
##    che è anche dove Godot mette il `.pck`.
##  · **Windows e Linux** — accanto all'eseguibile, e basta.
##
## Nell'editor `get_executable_path()` è il binario di Godot: lì il file non
## c'è, la funzione torna "", e il ramo si spegne da solo senza una riga di
## codice in più. È il degrado giusto — dai banchi il modello si dice con
## `CHIBI_MODELLO`.
static func percorso_spedito() -> String:
	var p := spedito_accanto_a(OS.get_executable_path())
	return p if p != "" and FileAccess.file_exists(p) else ""


## DOVE FINIREBBE, dato un eseguibile — pura, e presa a parte apposta.
##
## ⚠️ **È L'UNICO PEZZO DI QUESTA FASE CHE NON SI PUÒ PROVARE DA UN MAC**, e
## cioè la riga che decide dove il gioco cercherà i pesi su Windows e su
## Linux. Un banco non può piantare un file dentro il bundle di Godot, e
## un'esportazione firmata gira solo in CI: se la mappa vivesse dentro
## `percorso_spedito()` — che chiede al sistema operativo qual è il suo
## eseguibile — l'unica verifica possibile sarebbe «su questo Mac torna
## vuoto», che è vera anche se la mappa è tutta sbagliata.
##
## Presa a parte, invece, si interroga con i percorsi delle TRE piattaforme e
## si guarda cosa risponde. `tests/cases/test_llm_spedito.gd` lo fa, e la
## riga di macOS è quella che vale il prezzo: un `.gguf` in `Contents/MacOS/`
## non è un residuo estetico — è «unsealed contents» per `codesign`, cioè una
## notarizzazione che non passa (vedi `RELEASE_SIGNING.md`).
static func spedito_accanto_a(exe: String) -> String:
	if exe == "":
		return ""
	var accanto := exe.get_base_dir()
	if accanto.ends_with("/Contents/MacOS"):
		accanto = accanto.get_base_dir().path_join("Resources")
	return accanto.path_join(NOME_MODELLO)


## IL PERCORSO DEL MODELLO, o "" — e "" resta una risposta normalissima
## (l'editor, i test, chiunque non abbia esportato il gioco).
##
## Tre posti, **dal più esplicito al più implicito**, ed è tutta la regola:
## nessuno si stupisce che una scelta detta più forte vinca su una detta più
## piano.
##  1. `CHIBI_MODELLO` — la leva dei banchi di prova e dei provini, che è
##     anche il modo in cui l'autore prova il gioco vero col modello vero.
##     Sta per prima apposta: chi la esporta sta dicendo esplicitamente quale
##     modello vuole, e nessun file trovato in giro deve poterlo scavalcare.
##  2. `user://modelli/pensieri.gguf` — quello che chi gioca ci ha messo.
##  3. Il modello SPEDITO, dentro il pacchetto — quello che è arrivato col
##     gioco.
##
## ⚠️ **PERCHÉ `user://` STA SOPRA IL MODELLO SPEDITO, E NON È UNA
## PREFERENZA DI GUSTO.** La lista dà UN percorso, non una catena di ripieghi:
## chi viene scelto qui è l'unico che verrà provato, e se il C++ lo rifiuta
## (tetto, riserva di RAM, portiere) la funzione si spegne — non passa al
## successivo. Perciò l'ordine decide una cosa sola, e importa:
##
##   il modello spedito è un 4B che chiede **2640 MB**, e su una macchina da
##   8 GB la riserva di RAM lo rifiuta — MISURATO su quella dell'autore:
##   2827 MB liberi, ne servirebbero 2640 + 1024. Se il file spedito venisse
##   prima, chi ha una macchina piccola non potrebbe far funzionare la
##   funzione **in nessun modo**: gli metteresti in mano un modello da un
##   miliardo di parametri, che ci starebbe, e il gioco continuerebbe a
##   provare l'altro. Con `user://` sopra, quel file è esattamente la via
##   d'uscita che sembra — «il modello che ho scelto io».
##
## Il residuo, dichiarato: un `pensieri.gguf` dimenticato in `user://` da
## prima che il gioco spedisse il suo continua a scavalcarlo per sempre. È il
## verso giusto (resta in mano a chi gioca una cartella che ha riempito
## apposta) e si vede: `Pensieri` stampa quale file ha aperto.
static func percorso_modello() -> String:
	var da_fuori := OS.get_environment("CHIBI_MODELLO")
	if not FileAccess.file_exists(da_fuori):
		da_fuori = ""
	var suo := CARTELLA_MODELLI.path_join(NOME_MODELLO)
	suo = ProjectSettings.globalize_path(suo) if FileAccess.file_exists(suo) else ""
	return il_primo_che_c_e(da_fuori, suo, percorso_spedito())


## LA REGOLA DELL'ORDINE, e nient'altro: il primo dei tre che non è vuoto.
##
## Sta in una funzione sua perché è **l'unica parte di `percorso_modello()`
## che si può interrogare**. Le altre tre righe chiedono al sistema operativo
## e al disco: da un banco si può piantare un file in `user://` e si può
## esportare `CHIBI_MODELLO`, ma il terzo candidato vive dentro il pacchetto
## di un gioco esportato, e nessun test può metterci niente (piantare un
## `.gguf` dentro il bundle di Godot vorrebbe dire romperne la firma). Con
## l'ordine cablato dentro, l'unica prova possibile sarebbe «qui torna vuoto»
## — verde anche con i tre candidati in ordine inverso.
static func il_primo_che_c_e(da_fuori: String, suo: String, spedito: String) -> String:
	if da_fuori != "":
		return da_fuori
	if suo != "":
		return suo
	return spedito


## L'IMPRONTA CHE QUEL PERCORSO DEVE AVERE, o "" per «non la controllo».
##
## ⚠️ **È UNA PROPRIETÀ DEL PERCORSO, NON UNA COSTANTE GLOBALE**, e la
## differenza è tutto il meccanismo. Se l'impronta fosse armata sempre,
## `CHIBI_MODELLO` non servirebbe più a niente — ogni banco, ogni provino,
## ogni prova con un modello diverso verrebbe rifiutato dal portiere con
## «questo non è il modello collaudato» — e il `.gguf` che un giocatore ha
## scelto di mettere in `user://` sarebbe rifiutato senza che lui possa
## capire perché. Dei tre candidati ce n'è uno solo di cui conosciamo i byte:
## quello che abbiamo messo noi dentro il pacchetto.
##
## ⚠️ E la domanda è **«è QUEL POSTO?»**, non «QUEL FILE C'È?»: si confronta
## con `spedito_accanto_a()` e non con `percorso_spedito()`, che aggiunge la
## prova di esistenza. Sono due cose diverse — l'impronta è una proprietà
## della *posizione*, e chiedere se il file c'è per rispondere «quale
## impronta deve avere» è una domanda in più che può solo sbagliare. (È anche
## ciò che rende questa riga provabile: nell'editor il posto esiste sempre,
## il file mai.)
## Nome del contrassegno che il corriere lascia accanto al modello scaricato.
## Non è una difesa — è una dichiarazione di PROVENIENZA, e la differenza
## conta: se sparisce, il peggio che succede è che non si verifica più (come
## per un modello messo a mano), mai che si accetti qualcosa di sbagliato.
const CONTRASSEGNO := "pensieri.provenienza"


## L'impronta che ci si aspetta da QUESTO file — "" vuol dire «non lo so», e
## non lo so non è mai un no.
##
## Due percorsi su tre la armano, e la ragione è la stessa: sono i due in cui
## il file lo abbiamo messo NOI, quindi sappiamo che byte deve avere.
##
##  - **accanto all'eseguibile**: c'è solo se ce l'abbiamo messo noi;
##  - **`user://` col contrassegno**: ce l'ha messo il corriere, che ha già
##    verificato l'impronta una volta. Ma verificarla di NUOVO a ogni
##    caricamento non è ridondante — è l'unica difesa contro un bit che
##    marcisce sul disco mesi dopo, che è precisamente il guasto per cui
##    l'impronta esiste (né il portiere né llama vedono un bit girato nei
##    pesi). Il corriere protegge dal download storto; questo dal disco.
##
## E `CHIBI_MODELLO` non la arma MAI: è la porta di chi vuole provare un
## altro modello, e armarla la chiuderebbe. Idem un `.gguf` piantato a mano
## in `user://` senza contrassegno: chi sperimenta continua a poterlo fare.
static func impronta_attesa(percorso: String) -> String:
	if percorso == "":
		return ""
	if percorso == spedito_accanto_a(OS.get_executable_path()):
		return IMPRONTA_SPEDITO
	if percorso == ProjectSettings.globalize_path(
			CARTELLA_MODELLI.path_join(NOME_MODELLO)):
		return impronta_del_contrassegno()
	return ""


## Cosa dice il contrassegno lasciato dal corriere. Vuoto se non c'è, se non
## si legge, o se dentro c'è qualcosa che non è un'impronta: **un
## contrassegno rotto vale come nessun contrassegno**, mai come un no.
static func impronta_del_contrassegno() -> String:
	var f := FileAccess.open(CARTELLA_MODELLI.path_join(CONTRASSEGNO),
			FileAccess.READ)
	if f == null:
		return ""
	var riga := f.get_line().strip_edges().to_lower()
	f.close()
	if riga.length() != 64:
		return ""
	for c in riga:
		if not (c in "0123456789abcdef"):
			return ""
	return riga


## Il corriere lo scrive quando il file è atterrato e l'impronta combacia.
static func segna_provenienza(impronta: String) -> void:
	DirAccess.make_dir_recursive_absolute(CARTELLA_MODELLI)
	var f := FileAccess.open(CARTELLA_MODELLI.path_join(CONTRASSEGNO),
			FileAccess.WRITE)
	if f != null:
		f.store_line(impronta)
		f.close()


## LA LEVA DI CHI GIOCA. Vera quando il villaggio ha il permesso di pensare:
## il binario sa scrivere, un modello c'è, e nessuno ha detto di no.
##
## ⚠️ **LA LEVA ADESSO SI VEDE, E SOLO A CHI HA UN MODELLO.** Fino al
## 2026-08-12 il bit c'era e la casella no, ed era la scelta giusta: una
## casella «il villaggio pensa» mostrata a chi non ha nessun modello è
## esattamente «un gioco a cui manca un pezzo» — la cosa che la Fase 5 non ha
## il permesso di essere. Una casella spenta e ingrigita insegna a chi gioca
## che gli manca qualcosa, e non gli manca niente: ha un gioco meno
## sorprendente, che è un'altra cosa.
##
## Da quando il modello viaggia DENTRO il pacchetto la stessa regola dice il
## contrario. La casella non racconta più una mancanza — racconta una cosa
## che c'è e che si può spegnere — e senza di lei la sola via d'uscita
## sarebbe cancellare un file dentro la cartella d'installazione: non è una
## via d'uscita, è un sabotaggio. E qualcosa da spegnere c'è davvero: la
## funzione costa RAM e core VERI (misurato: 2,7 GB di impronta col 4B, e su
## un Mac da 8 GB il resto della macchina se ne accorge).
##
## La condizione era già scritta qui dentro, ed è quella:
## `Llm.disponibile() and Llm.percorso_modello() != ""` — il binario sa
## scrivere E c'è di che. Il bit che governa è `Settings.llm_spento`,
## persistito. Come `prato_eterno`: il bit di là, il predicato di qua.
##
## ⚠️ **QUESTA NON È PIÙ LA CONDIZIONE DELLA RIGA NEL PANNELLO**, e la
## differenza è nata il 2026-08-13 col modello che non viaggia più dentro il
## pacchetto. Da allora la riga si mostra a chiunque abbia un binario che sa
## scrivere (`Llm.disponibile()`), perché per tutti loro c'è **qualcosa da
## scegliere**: chi ha i pesi può spegnerli, chi non li ha può averli. Questa
## funzione resta la domanda «c'è qualcosa da SPEGNERE?», che è un'altra cosa
## e ha ancora due lettori veri — la casella parte spuntata solo per loro, e
## `NoteLegali` la cita per spiegare perché *non* la usa.
##
## `CHIBI_LLM=0` spegne tutto anche dai banchi: serve alle misure appaiate
## (lo stesso villaggio, con e senza), che sono l'unico modo di dimostrare
## «identico» invece di dichiararlo.
static func acceso() -> bool:
	if not disponibile():
		return false
	if OS.get_environment("CHIBI_LLM") == "0":
		return false
	if spento_da_chi_gioca():
		return false
	return percorso_modello() != ""


## LA CASELLA NEL PANNELLO SI MOSTRA? — la casa unica della condizione.
##
## Vera quando c'è qualcosa da spegnere: il binario sa scrivere E un modello
## c'è. **Non guarda `llm_spento`**, ed è il punto: una casella che sparisce
## appena la si spegne sarebbe una porta che si chiude a chiave da sola.
##
## Sta qui e non nel pannello per la stessa ragione per cui ci sta
## `disponibile()`: il giorno in cui «si può scegliere» dipenderà anche da
## altro, cambia un posto e non due.
static func leva_visibile() -> bool:
	return disponibile() and modello_in_casa()


## Il bit del giocatore, letto da dove vivono le sue preferenze. Difensivo
## apposta: un salvataggio delle impostazioni scritto da una versione più
## vecchia non ha quella chiave, e «non lo so» non deve diventare «spento».
static func spento_da_chi_gioca() -> bool:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return false
	var s: Node = (loop as SceneTree).root.get_node_or_null("/root/Settings")
	if s == null:
		return false
	return bool(s.get("llm_spento"))
