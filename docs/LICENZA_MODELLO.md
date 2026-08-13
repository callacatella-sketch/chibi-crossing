# La licenza del modello — Gemma 3 4B, che il GIOCATORE scarica

> **Chi scrive non è un avvocato, e questo documento non è un parere legale.**
> Riporta il **testo delle licenze** e le sue conseguenze pratiche sulla nuova
> forma della funzione. L'ultima sezione elenca, senza addolcirle, le domande
> che **devono** passare da un legale prima di pubblicare.
>
> Testi riletti alla fonte il **2026-08-13**, non in riassunti di terzi:
> - Gemma Terms of Use — <https://ai.google.dev/gemma/terms> (ultima modifica **1 aprile 2026**)
> - Gemma Prohibited Use Policy — <https://ai.google.dev/gemma/prohibited_use_policy> (ultima modifica **21 febbraio 2024**)
> - le copie che il gioco porta con sé: [`misc/licenze/`](../misc/licenze/)

## ⚠️ COSA È CAMBIATO, E PERCHÉ QUESTO DOCUMENTO È STATO RIFATTO

Fino al 2026-08-13 il piano era **spedire i pesi dentro il pacchetto**. Da qui
in avanti no: **il modello lo scarica il gioco sulla macchina del giocatore,
al primo uso, quando è lui ad accendere la funzione.** (La ragione che l'ha
forzata è tecnica — GitHub non accetta allegati sopra 2 GiB, e il pacchetto
col modello ne pesa ~2,4.)

La conseguenza legale non è un dettaglio di forma: **smettiamo di essere un
distributore**. La Sezione 3.1 dei Termini — le quattro condizioni che erano
tutto il lavoro della versione precedente di questo documento — è il **prezzo
di una licenza a ridistribuire**, e una licenza a ridistribuire non ci serve
più. Ciò che resta è di specie diversa, e non è meno importante: resta l'uso,
resta chi *permette* l'uso, e resta il fatto che **a monte c'è un cancello di
accettazione che il nostro scaricamento scavalca**.

| | prima (pesi nel pacchetto) | adesso (li scarica il giocatore) |
|---|---|---|
| noi «Distribute» ai sensi della 1.1(b)? | **sì** | **no** |
| le quattro condizioni della 3.1 | quattro obblighi da assolvere | **nessun destinatario su cui mordere** |
| copia dell'accordo al giocatore | **obbligo** (3.1 p.2) | **scelta nostra** — ma è l'unico posto in cui la vedrà |
| il file «Notice» | **obbligo** (3.1 p.4) | **cautela dichiarata** |
| vincoli d'uso (3.2 + PUP) | dovuti in *flow-down* dalla 3.1 p.1 | **dovuti lo stesso**, su un'altra base (vedi Q3) |
| chi accetta i Termini, e quando | il giocatore, per contratto con noi | **il giocatore, scaricando** — quindi glieli si mostra PRIMA |
| responsabilità sull'Output (3.3) | invariata | **invariata** |

---

## Cosa succede esattamente, adesso

| | |
|---|---|
| modello | Gemma 3 4B IT — Google DeepMind |
| file | `gemma-3-4b-it-Q4_K_M.gguf` (2 489 757 856 byte), salvato come `pensieri.gguf` |
| da dove | `ggml-org/gemma-3-4b-it-GGUF` su Hugging Face, revisione `d0976223…fe52e` |
| chi lo scarica | **il gioco, sulla macchina del giocatore**, dopo che il giocatore ha acceso la funzione e accettato |
| chi lo ospita | Hugging Face e la sua CDN (`us.aws.cdn.hf.co`) — **non noi** |
| integrità | SHA-256 `882e8d2d…a0863`, verificato dal portiere C++ prima di aprire il file |
| licenza | **Gemma Terms of Use** + **Gemma Prohibited Use Policy** |
| modifiche nostre | **nessuna**: non lo addestriamo, non lo rifiniamo, non lo quantizziamo |

**MISURATO il 2026-08-13** (`curl` anonimo, nessuna credenziale):

```
GET  https://huggingface.co/api/models/ggml-org/gemma-3-4b-it-GGUF
     gated: False   private: False   license: gemma
     file nel repo: .gitattributes, README.md, 4 .gguf  →  nessun LICENSE proprio

HEAD .../resolve/d0976223…/gemma-3-4b-it-Q4_K_M.gguf
     HTTP/2 302 → us.aws.cdn.hf.co ... HTTP/2 200
     x-linked-size : 2489757856            (= quello che il gioco si aspetta)
     x-linked-etag : "882e8d2d…a0863"      (= Llm.IMPRONTA_SPEDITO, identico)
```

Due cose che questa misura dice e che valgono più di un'opinione: il file **si
scarica senza credenziali** (quindi la funzione può esistere senza chiedere a
nessuno un account), e **Hugging Face pubblica lo SHA-256 nell'intestazione**,
identico a quello che il gioco pretende — cioè si può verificare *prima* di
scaricare che il file a monte sia ancora quello collaudato.

---

## Le domande, con la clausola

### Q1. Senza distribuire i pesi, la Sezione 3.1 si applica ancora? In che misura?

**Praticamente no, e la ragione è nel primo rigo della clausola.** La 3.1 apre
con:

> *«You may reproduce or Distribute copies of Gemma or Model Derivatives **if
> you meet all of the following conditions**»*

È una **permissione condizionata**: le quattro condizioni sono ciò che si paga
per avere il diritto di riprodurre o Distribuire. La **1.1(b)** definisce
Distribution come

> *«any transmission, publication, or other sharing of Gemma or Model
> Derivatives to a third party, including by providing or making Gemma or its
> functionality available as a hosted service via API, web access, or any
> other electronic or remote means ("Hosted Service")»*

e nessuno dei quattro verbi ci descrive più:

- **transmission** — i byte viaggiano da Hugging Face al disco del giocatore.
  Non passano da noi, e non esiste nessuna nostra macchina in quella catena;
- **publication** — non c'è nessuna copia nostra da nessuna parte: né nel
  pacchetto, né nel repository (`*.gguf` in `.gitignore`), né su un server;
- **other sharing** — condividere presuppone possedere una copia e passarla;
- **Hosted Service** — non ospitiamo niente: l'inferenza gira sulla macchina
  del giocatore, e il gioco non apre nessuna connessione dopo lo scaricamento.

**La misura precisa, però, è «si applica a vuoto», non «non si applica».** Il
verbo *reproduce* copre anche le copie che teniamo noi per sviluppare e
provare; per quelle la 3.1 vale, e le sue condizioni sono soddisfatte
**vacuamente**, perché tre parlano di destinatari (*«provide all third party
recipients»*, *«notice to subsequent users you Distribute to»*, *«All
Distributions … must be accompanied by»*) e destinatari non ce ne sono, e la
quarta (*«cause any modified files to carry prominent notices»*) non ci ha mai
riguardato perché non modifichiamo niente.

> **La formulazione onesta è questa**: non abbiamo più bisogno del permesso che
> la 3.1 concede, quindi non paghiamo più il suo prezzo. Non che la clausola
> sia sparita — che non abbiamo più niente da metterci dentro.

### Q2. Il carve-out nel nostro LICENSE serve ancora?

**Metà serviva a descrivere il pacchetto ed è diventata falsa: quella è stata
tolta.** Erano le righe *«Distributed builds of the Work may include a copy of
Google's Gemma model weights»* e *«A copy of those Terms … is included with
every build that contains Gemma»*. Un `LICENSE` che descrive un file che non
spediamo non è un eccesso di zelo: è un documento che dice il falso proprio
dove deve dire il vero.

**L'altra metà serve ancora, e serve a noi.** Il `LICENSE` dice *«NO PERMISSION
is granted to any person to use, copy, modify … the Work»* e vieta di usare
l'Opera *«to train, fine-tune or evaluate machine-learning models»*. Dopo lo
scaricamento il `.gguf` **sta nella cartella del gioco**, sul disco del
giocatore: senza una riga che lo escluda, un lettore ragionevole può leggere
quel file come parte dell'«Opera» e concludere che gli abbiamo tolto diritti
che Google gli dà. Perciò il carve-out resta, **rimpicciolito e cambiato di
tempo verbale**: non «i pesi che spediamo», ma

> «Gemma NON fa parte dell'Opera e NON è concesso in licenza da questa licenza
> — **né prima che tu lo scarichi, né dopo**, quando il file sta nella cartella
> del gioco sul tuo disco.»

Restano con lui la **clausola di prevalenza** (in conflitto su Gemma prevalgono
i Gemma Terms of Use), l'attribuzione **senza endorsement** (Sezione 4.2: nessun
diritto sui marchi) e la responsabilità sull'Output (Sezione 3.3).

⚠️ **Un cambio di natura, che va detto**: prima il carve-out serviva anche a
non violare l'ultimo capoverso della 3.1 (*«Any additional or different terms
and conditions you impose must not conflict with the terms of this
Agreement»*), che è una **condizione della distribuzione**. Non distribuendo,
quel capoverso non ci vincola più: il carve-out oggi non evita una violazione,
**evita di dire una cosa scorretta al giocatore**. È una ragione più debole in
diritto e più forte in onestà, e costa cinque righe.

### Q3. Il flow-down della Prohibited Use Policy resta dovuto?

**Sono due domande, e vanno separate o si sbaglia.**

**(a) Come condizione della ridistribuzione (3.1 punto 1): no.** La clausola
chiede i vincoli d'uso *«as an enforceable provision in any agreement …
governing the use and/or distribution of Gemma»* **più** l'avviso *«to
subsequent users you Distribute to»*. Non distribuiamo, non ci sono subsequent
users, la condizione non è innescata.

**(b) Come obbligo nostro: sì, e non è un ripiego.** La frase operativa della
Prohibited Use Policy è:

> *«You may not use **nor allow others to use** Gemma or Model Derivatives
> to: …»*

Quella seconda metà non nomina la distribuzione. Noi scegliamo il modello,
scegliamo la fonte, pinniamo la revisione, facciamo la richiesta di rete,
scriviamo il file sul disco e poi lo facciamo girare col nostro codice: se
questo non è *«allow others to use»*, gli somiglia abbastanza che la cosa
onesta e a costo zero è tenere il vincolo. Si aggiunge la **Sezione 2.2**
(*«You may use … any of the Gemma Services only in accordance with the terms
of this Agreement, and must not violate (or **encourage or permit anyone else
to violate**) any term»*), che dice la stessa cosa dal lato dell'accordo
principale.

**Quindi il testo del vincolo resta nel `LICENSE`, ma cambia la sua base**, e
nel file c'è scritto:

> «Non è una clausola di ridistribuzione: l'Opera non ridistribuisce niente.
> Sta qui perché la Gemma Prohibited Use Policy vincola non solo chi usa Gemma,
> ma anche chi *allow[s] others to use* — e l'Opera è ciò che ti mette Gemma
> fra le mani.»

Citare ancora «come richiesto dalla Sezione 3.1» sarebbe stato invocare una
clausola che non ci vincola più: una citazione a vuoto, che è la stessa
famiglia di guasto della lettera del Gufo che cita un momento mai successo.

### Q4. Che il GIOCO scarichi per conto del giocatore cambia qualcosa? Stiamo distribuendo, facilitando, o niente?

La risposta ha tre parti, e la terza è quella che conta.

**1. Contro il testo della 1.1(b): niente.** In tutti e due i casi — il gioco
che scarica, o il giocatore che va sul sito e clicca — i byte fanno la stessa
identica strada: Hugging Face → disco del giocatore. Non c'è un momento in cui
noi ne abbiamo una copia da passare, e non c'è un momento in cui la
funzionalità è resa disponibile *«as a hosted service»*.

**2. Ma non è nemmeno «niente», in italiano corrente: è FACILITARE.** Scegliamo
noi *quale* modello, *da dove*, *quale revisione*; è il nostro codice a fare la
richiesta e a scrivere il file. È esattamente questo che rende i vincoli d'uso
affar nostro (Q3) — e sarebbe disonesto scrivere «noi non c'entriamo» in un
documento e «il gioco scarica il modello per te» nel gioco.

**3. E c'è una differenza MISURATA che pesa più delle parole: a monte esiste un
cancello di accettazione, e il nostro scaricamento gli passa accanto.**

| repository | `gated` | cosa vede chi ci va |
|---|---|---|
| `google/gemma-3-4b-it` (Google) | **`manual`** | *«To access Gemma on Hugging Face, you're required to review and agree to Google's usage license … [Acknowledge license]»* |
| `ggml-org/gemma-3-4b-it-GGUF` (il nostro) | **`false`** | il file, e basta |

Chi va a prendere Gemma **da Google** la licenza la legge e la accetta: Google
ha messo lì, apposta, il posto in cui questo succede. Il mirror quantizzato non
ha quel cancello, e **non contiene nemmeno una copia dell'accordo** (verificato:
nel repository ci sono `.gitattributes`, `README.md` e i `.gguf`). Un giocatore
il cui gioco scarica da lì, senza che nessuno gli mostri niente, si ritrova
vincolato a un accordo che non ha mai visto.

> **Non stiamo distribuendo. Stiamo però occupando il posto in cui, a monte,
> qualcuno viene informato — e se non ci mettiamo noi quel passo, non c'è
> nessun altro che lo faccia.** È da qui, e non dalla 3.1, che nasce la
> risposta alla domanda dopo.

### Q5. Il giocatore deve ACCETTARE i termini prima dello scaricamento? Dove e come?

**Sì. E non lo dice la 3.1: lo dice il preambolo dell'accordo**, che è la prima
frase del documento e vale sempre:

> *«**By using, reproducing**, modifying, distributing, performing or displaying
> any portion or element of Gemma, Model Derivatives … or otherwise accepting
> the terms of this Agreement, **you agree to be bound by this Agreement**.»*

Scaricare una copia è *reproducing*; farla girare è *using*. **Il giocatore si
vincola con l'atto stesso**, che qualcuno gliel'abbia mostrato o no. Prima, la
3.1 punto 2 metteva su di noi il dovere di consegnargli il testo; adesso quel
dovere non c'è più — e il mirror non glielo consegna. Quindi: o glielo mostra
il gioco, o non glielo mostra nessuno.

**E c'è una seconda clausola che nessuno aveva ancora tirato fuori, la 2.1:**

> *«You represent and warrant that you have the legal capacity to enter into
> this Agreement (**including being of sufficient age of consent**).»*

Chibi Crossing è un gioco cozy: fra chi lo aprirà ci sono bambini. Non riguarda
il **gioco** — riguarda **questa funzione facoltativa**, che è l'unica cosa che
chiede a chi la accende di stipulare un accordo con Google. È una delle ragioni
per cui deve stare spenta, dietro una porta, e con una schermata che *dica* cosa
si sta accettando. **Se serva un vero controllo dell'età o il consenso di un
genitore è una domanda da legale**, ed è nell'elenco in fondo.

#### Quello che la schermata dello scaricamento deve fare (per l'agente della schermata)

Requisiti, con la ragione accanto — nessuno è decorativo:

1. **PRIMA del primo byte.** Non durante lo scaricamento, non dopo: dopo, il
   giocatore ha già *reproduced* Gemma ed è già vincolato.
2. **Deve mostrare i due documenti per intero, leggibili lì.** Sono già nel
   pacchetto: `res://misc/licenze/Gemma-Terms-of-Use.txt` e
   `Gemma-Prohibited-Use-Policy.txt`. La pagina Note legali
   ([`scenes/ui/NoteLegali.gd`](../scenes/ui/NoteLegali.gd)) li apre già e ha
   il lettore fatto: **si riusa quello, non si ricopia il testo** (regola 2 di
   quella pagina, e la stessa regola delle fonti uniche).
3. **Deve dire, in una lingua che si capisce senza sapere cos'è un modello:**
   che cosa si scarica (~2,5 GB), **da dove** (huggingface.co), che è di
   Google e che vale la licenza di Google, che i vincoli d'uso valgono anche
   per lui, e che lo scaricamento mostra il suo indirizzo IP a Hugging Face e
   alla sua CDN — come ogni scaricamento, ma va detto — mentre **non viene
   caricato niente**, mai, in nessun momento.
4. **L'atto di accettazione deve essere esplicito, spento di serie, e nominare
   ciò che si accetta.** Non una riga di testo piccola sotto un bottone
   «Scarica»: una casella non spuntata + un bottone, e l'etichetta dice
   «Accetto i Gemma Terms of Use», non «Ho capito».
5. **Deve portare la rappresentazione della 2.1** (capacità legale / età): è
   testo dell'accordo, e chi accetta la sta dando.
6. **Rifiutare dev'essere facile quanto accettare, e non deve degradare
   niente.** Il gioco è identico: è la REGOLA ZERO della Fase 5, e una
   schermata che fa sentire in colpa chi dice di no la viola.
7. **L'accettazione si registra** (data + la data di «ultima modifica» dei due
   documenti che sono stati mostrati): così non si richiede due volte, e
   quando Google aggiorna i Termini (Sezione 4.1: *«Google may update Gemma
   from time to time»*, e i documenti portano una data) si sa cosa aveva letto.
8. **Dopo, i due documenti restano leggibili per sempre** da Impostazioni →
   Note legali. Quella pagina esiste già e li mostra.

> ⚠️ **Una cosa che la schermata NON deve fare: mostrare l'accettazione a chi
> non ha chiesto niente.** Non al primo avvio, non nel Prologo, non come
> ostacolo fra il tasto «nuova avventura» e il temporale. Solo dietro «Il
> villaggio pensa».

### Q6. E a valle, che non cambia: chi USA l'output ha obblighi? Il gioco deve dichiarare che un testo è generato?

**Questa metà è identica a prima**, perché non dipende da chi consegna il file.

**Dai Gemma Terms of Use: nessun obbligo sull'Output.** Sezione 3.3:

> *«Google claims no rights in Outputs you generate using Gemma. You and your
> users are solely responsible for Outputs and their subsequent uses.»*

Nessuna attribuzione dovuta, nessuna licenza che si propaga al testo, nessuna
etichetta «generato da Gemma» richiesta dall'accordo. E il testo è del
giocatore, non nostro: nasce sulla sua macchina.

**Dalla Prohibited Use Policy: non un obbligo di etichetta, ma un divieto di
inganno.** Punto 3.1 della policy:

> *«Misrepresentation of the provenance of generated content by claiming
> content was created by a human, or represent generated content as original
> works, **in order to deceive**»*

La condizione *«in order to deceive»* è nel testo. Una lettera firmata da un
gufo immaginario, dentro un gioco, non è una falsa attribuzione a un essere
umano fatta per ingannare. **Il gioco lo dichiara lo stesso** — nella pagina
Note legali e in `NOTICE-Gemma.txt` — perché è la cosa onesta e costa una riga.

**Fuori da Gemma, invece, gli obblighi ci sono e restano da verificare**
(nell'elenco in fondo): la trasparenza dell'**AI Act** europeo e la
**dichiarazione IA dei negozi**. Steam distingue *Pre-Generated* da
**Live-Generated**, e Chibi Crossing ricade nel secondo: il modello scrive in
partita, sulla macchina di chi gioca. Con lo scaricamento si aggiunge un fatto
nuovo da dichiarare a certi negozi: **il gioco scarica ~2,5 GB da un terzo**,
su richiesta del giocatore.

> ⚠️ **Non verificato alla fonte**: la documentazione Steamworks sta dietro il
> login da partner e Valve ha riscritto le regole a gennaio 2026. Da rileggere
> sul Steamworks vero prima del Content Survey, e lo stesso per itch.io, Epic e
> Microsoft Store.

---

## Un residuo che lo scaricamento NON risolve: i nomi che il giocatore digita

Resta identico a prima ed è l'unica superficie per cui il giocatore può
mettere testo suo davanti al modello: **dà il nome ai cuccioli che nascono**
([`scenes/world/Nascite.gd`](../scenes/world/Nascite.gd), un `LineEdit` con
`max_length = 18`). Quel nome diventa la `label` di un residente, entra in
`rit["nomi"]` e da lì nel prompt (`Suggeritore._nomi_del_villaggio`).

Attenuanti reali, nessuna delle quali è una difesa completa: il testo generato
**non lascia la macchina** (nessuna rete: verificato con `nm -u` e `lsof`), non
è pubblicato, non è condiviso, e la grammatica GBNF delle righe libere è **senza
maiuscole e senza cifre**, quindi non può riprodurre un nome proprio. **Non è
stata aggiunta nessuna lista di parole vietate**, e la scelta è dichiarata: un
filtro sui nomi che il giocatore dà ai propri cuccioli è invasivo, sbaglia in
tutte le lingue del mondo, e proteggerebbe il giocatore da sé stesso su un
testo che nessun altro leggerà mai. **Da confermare col legale.**

---

## ⚠️ DA PORTARE A UN LEGALE PRIMA DI PUBBLICARE

Nessuno di questi punti è stato risolto qui. In ordine di rischio, e i primi
tre sono **nuovi o cambiati** rispetto alla versione col modello nel pacchetto.

1. **«Non stiamo distribuendo» regge?** È la tesi su cui poggia tutto il
   resto (Q1, Q4): scaricare *per conto del giocatore*, da una fonte scelta da
   noi, con una revisione pinnata da noi, non è Distribution ai sensi della
   1.1(b) perché non c'è nessuna trasmissione, pubblicazione o condivisione da
   parte nostra. *Un legale la legge allo stesso modo? E se la leggesse
   diversamente, cosa mancherebbe?* (Risposta tecnica: quasi niente — i quattro
   artefatti della 3.1 sono già tutti nel pacchetto, per cautela. È il motivo
   per cui non sono stati buttati.)
2. **La schermata di accettazione: forma e conservazione.** Il giocatore si
   vincola ai Gemma Terms of Use scaricando (preambolo). *Che forma deve avere
   il consenso perché valga — e che cosa va conservato, per quanto, e dove,
   senza raccogliere dati personali che oggi non raccogliamo?*
3. **L'ETÀ (Sezione 2.1).** *«legal capacity … including being of sufficient
   age of consent»*. Un gioco cozy lo giocano i bambini. *Serve un controllo
   dell'età o il consenso di un genitore davanti a questa funzione? Basta la
   rappresentazione scritta nella schermata? E come si concilia con le regole
   dei negozi sui contenuti per minori?* **È la domanda con la conseguenza di
   prodotto più grossa.**
4. **Lo scaricamento e i dati personali.** Il gioco fa fare al giocatore una
   richiesta a huggingface.co e alla sua CDN, che vedono il suo **indirizzo
   IP**. *Basta dirlo nella schermata, o serve una riga in una informativa
   privacy? Cambia qualcosa il fatto che sia il gioco a fare la richiesta
   invece del browser?* (E: le condizioni d'uso di Hugging Face permettono lo
   scaricamento programmatico che facciamo? Non le ho lette.)
5. **Consumatori europei, e legge applicabile.** I Gemma Terms of Use sono
   governati dalla **legge della California** con **foro esclusivo a Santa
   Clara County** (Sezione 4.6). Il gioco lo vende un autore **italiano** a
   consumatori **europei**, per i quali esistono norme inderogabili su foro e
   diritto applicabile. *Come si scrive una schermata che faccia accettare
   quell'accordo senza imporre al giocatore clausole nulle nei suoi confronti?*
6. **Il carve-out nel `LICENSE`.** Adesso è più piccolo e non ha più il
   compito di evitare il conflitto vietato dalla 3.1 (Q2). *Il testo attuale
   dice il vero e basta a sé stesso, o una clausola generale «All Rights
   Reserved» può ancora essere letta come se coprisse un file che il giocatore
   si è scaricato dentro la cartella del gioco?*
7. **L'AI Act europeo.** Il gioco è distribuito in UE e genera testo sintetico
   sulla macchina dell'utente. *Gli obblighi di trasparenza dell'articolo 50
   si applicano a un videogioco single-player? In che qualità agisce l'autore
   — provider o deployer?* **Non è stata presa nessuna posizione**, oltre a
   dichiarare le cose in chiaro nel gioco perché è comunque la cosa giusta.
8. **La dichiarazione IA sui negozi** (Q6), più il fatto nuovo dello
   scaricamento di 2,5 GB da un terzo.
9. **La superficie dei nomi digitati** (sopra). *Quel residuo è accettabile,
   considerato che nulla lascia la macchina del giocatore?* Se la risposta è
   no, la cura tecnica è nota e piccola (non passare al modello i nomi scelti
   dal giocatore) — ma cambia cosa il modello può scrivere.
10. **Responsabilità sul testo generato.** La 3.3 dice che Google non
    rivendica diritti sugli Output e che *«You and your users are solely
    responsible»*. Il `LICENSE` lo ripete verso il giocatore. *Basta come
    limitazione di responsabilità verso un consumatore?*

---

## Manutenzione

- **Se cambia il modello**, va rifatto tutto questo: `LICENSE`,
  `NOTICE-Gemma.txt`, `THIRD_PARTY_NOTICES.md`, l'impronta e la revisione in
  `Llm.gd` e in chi scarica, e il testo della schermata di accettazione. In
  particolare **Gemma 4 è Apache 2.0**, non Gemma Terms of Use: sparirebbero i
  vincoli d'uso **e la ragione stessa della schermata di accettazione**.
- **Se cambia la FONTE** (il mirror sparisce, o diventa *gated*): la funzione
  deve spegnersi da sola, come si spegne per un modello che non c'è. Un
  repository diventato *gated* è anche un cancello di accettazione che
  ricompare a monte: **non lo si aggira con un token nostro**, si va a
  prendere il file da dove è ancora lecito prenderlo, o non lo si prende.
- **Se cambia una libreria**, basta `python3 tools/genera_licenze.py`: l'avviso
  spedito si riassembla dai `LICENSE` veri. `--verifica` dice se è da
  rigenerare, e non va lasciato fallire.
- **Se cambia l'export o `release.yml`**, il cancello «Le licenze sono DENTRO
  i pacchetti?» apre gli zip veri e ferma la Release. I quattro `.txt` di
  `misc/licenze/` continuano a viaggiare **anche se non spediamo più i pesi**:
  tre servono a far leggere e accettare, uno è l'avviso MIT delle librerie —
  che quello sì, resta un obbligo pieno.
