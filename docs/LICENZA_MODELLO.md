# La licenza dei pesi — Gemma 3 4B dentro un gioco commerciale chiuso

> **Chi scrive non è un avvocato, e questo documento non è un parere legale.**
> Riporta il **testo delle licenze** e le sue conseguenze pratiche sul
> pacchetto che spediamo. L'ultima sezione elenca, senza addolcirle, le
> domande che **devono** passare da un legale prima di pubblicare.
>
> Testi letti alla fonte il **2026-08-13**, non in riassunti di terzi:
> - Gemma Terms of Use — <https://ai.google.dev/gemma/terms> (ultima modifica **1 aprile 2026**)
> - Gemma Prohibited Use Policy — <https://ai.google.dev/gemma/prohibited_use_policy> (ultima modifica **21 febbraio 2024**)
> - llama.cpp — `src/thirdparty/llama.cpp/LICENSE` (**MIT**, ggml authors)
> - il repository da cui scarichiamo il `.gguf` — <https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF>

## Cosa stiamo spedendo, esattamente

| | |
|---|---|
| modello | Gemma 3 4B IT — Google DeepMind |
| file | `gemma-3-4b-it-Q4_K_M.gguf` (2 489 757 856 byte), spedito come `pensieri.gguf` |
| origine | `ggml-org/gemma-3-4b-it-GGUF`, quantizzazione di `google/gemma-3-4b-it` |
| licenza | **Gemma Terms of Use** + **Gemma Prohibited Use Policy** |
| modifiche nostre | **nessuna** — copia byte per byte |

**Chi ha riquantizzato non aggiunge condizioni sue.** Il repository di
`ggml-org` dichiara `license: gemma` nella scheda, non è *gated*, e — verificato
via API — non contiene nessun file di licenza proprio (solo `.gitattributes`,
`README.md` e i `.gguf`). La sua scheda è la copia della scheda Google. Le
uniche condizioni sono quelle di Google.

E prenderlo di lì non è una scappatoia: **Sezione 1.1(c)**, «Gemma» sono quei
pesi *«regardless of the source that you obtained it from»*. Lo conferma il
file stesso: la chiave `general.license` dentro il `.gguf` vale `gemma`.

---

## Le domande, con la clausola

### 1. Si possono ridistribuire i pesi dentro un prodotto commerciale chiuso?

**Sì, se si rispettano le quattro condizioni della Sezione 3.1.**

La **Sezione 3.1** apre con: *«You may reproduce or Distribute copies of Gemma
or Model Derivatives if you meet all of the following conditions»*. La
**Sezione 1.1(b)** definisce «Distribution» come qualunque trasmissione o
condivisione a un terzo — quindi mettere il `.gguf` nel pacchetto **è**
Distribution.

Due cose che l'accordo **non** dice, e che vale la pena dire esplicitamente
perché è lì che nascono le leggende:

- **la parola «commercial» non compare nel testo.** Non c'è un divieto d'uso
  commerciale, e non c'è una licenza separata da comprare;
- **e la chiusura del prodotto è espressamente prevista.** Ultimo capoverso
  della 3.1: si può aggiungere il proprio *«intellectual property statement»*
  e imporre *«additional or different terms and conditions»* sulle proprie
  modifiche o sul Model Derivative nel suo insieme — con un limite, che è la
  domanda 7.

### 2. Che avvisi e attribuzioni, e DOVE

Le quattro condizioni della 3.1, e dove sono state assolte:

| 3.1 | testo | assolto in |
|---|---|---|
| 1 | i vincoli d'uso della 3.2 come *«enforceable provision in any agreement … governing the use and/or distribution»*, **più** *«notice to subsequent users»* | [`LICENSE`](../LICENSE), sezione «GEMMA MODEL WEIGHTS» e la gemella italiana; l'avviso in `NOTICE-Gemma.txt` |
| 2 | *«provide all third party recipients … a copy of this Agreement»* | `misc/licenze/Gemma-Terms-of-Use.txt`, spedito |
| 3 | *«cause any modified files to carry prominent notices stating that you modified the files»* | **non ci riguarda**: non modifichiamo nulla. La catena (Google → ggml-org → noi) è dichiarata nel NOTICE |
| 4 | *«All Distributions … must be accompanied by a "Notice" text file»* con la frase esatta | `misc/licenze/NOTICE-Gemma.txt`, prima riga utile |

**Dove finiscono i file, in concreto:**

- **accanto all'eseguibile**, cartella `Licenze/` — la mette `release.yml`.
  Su **macOS** vanno *dentro* il bundle (`Contents/Resources/Licenze/`): il
  `.app` è l'artefatto che l'utente trascina, e una cartella lasciata accanto
  nello zip resterebbe indietro al primo trascinamento. (Il passo sta **prima**
  della firma: iniettare file in un bundle già firmato rompe la firma.)
- **dentro il `.pck`** (`include_filter` in `export_presets.cfg`), perché la
  pagina **Note legali** del gioco possa mostrarli.

Servono tutte e due: un file dentro un `.pck` non «accompagna» niente per chi
riceve il gioco (su Windows il `.pck` è pure embedded nell'`.exe`), e un file
accanto all'eseguibile non lo apre quasi nessuno.

**Una schermata nei crediti?** Il gioco **non ha** una schermata dei crediti.
Ne è stata fatta una dedicata — *Impostazioni → Note legali*
([`scenes/ui/NoteLegali.gd`](../scenes/ui/NoteLegali.gd)) — raggiungibile sia
dal titolo sia dalla pausa, che mostra le attribuzioni e lascia **leggere per
intero** i quattro documenti. Mostra la sezione del modello **solo se il
modello c'è davvero**: chi ha una build senza legge una pagina completa e vera
per il suo gioco, non una voce spenta che gli racconta che gli manca un pezzo.

### 3. Va spedito il testo della licenza? In che forma?

**Sì, per intero.** La 3.1 punto 2 chiede *«a copy of this Agreement»*, senza
prescrivere un formato. Spediamo:

- `Gemma-Terms-of-Use.txt` — copia verbatim, con in testa un riquadro
  **dichiarato come non facente parte dell'accordo** che registra URL e data
  di prelievo. L'unica trasformazione è la rimozione dei marcatori markdown
  (`**`, `#`, sintassi dei link): nessuna parola cambiata.
- `Gemma-Prohibited-Use-Policy.txt` — stessa cosa. Va spedita perché la
  **Sezione 3.2** la incorpora *«by reference»*: senza, l'accordo consegnato
  è incompleto.
- `NOTICE-Gemma.txt` — il file «Notice» del punto 4, con la frase esatta:
  *«Gemma is provided under and subject to the Gemma Terms of Use found at
  ai.google.dev/gemma/terms»*.

> ⚠️ **La frase del punto 4 deve stare su UNA riga.** La prima stesura la
> mandava a capo dopo «found at»: si leggeva benissimo e la stringa richiesta
> **non c'era**. Due guardie ora la cercano intera
> ([`tests/cases/test_licenze.gd`](../tests/cases/test_licenze.gd) e il passo
> «Le licenze sono DENTRO i pacchetti?» di `release.yml`).

E i **Termini che spediamo devono coprire il modello che spediamo**: l'Appendix
elenca **Gemma 3** — verificato, riga per riga, nel file spedito.

### 4. La Prohibited Use Policy va passata a valle? Un gioco cozy può violarla?

**Sì, va passata a valle, e non come cortesia.** La 3.1 punto 1 chiede che i
vincoli della 3.2 siano una *«enforceable provision»* nell'accordo che governa
l'uso — cioè, per questo gioco, il `LICENSE`. La clausola c'è, in entrambe le
lingue, e dice che chi usa il gioco non deve usare Gemma per gli usi vietati
né in violazione di legge. Quindi **sì: il giocatore ne diventa soggetto.**

**Un gioco cozy la può violare?** Le voci della policy che meritano una
risposta, non un'alzata di spalle:

- **contenuti sessualmente espliciti, odio, molestie, autolesionismo,
  disinformazione.** Il giocatore **non può scrivere un prompt**: il prompt lo
  costruisce `FoglioDelVicino` dallo stato del villaggio, e le righe libere
  escono da una grammatica GBNF **senza maiuscole e senza cifre**.
- **⚠️ MA UNA SUPERFICIE C'È, ed è bene che sia scritta invece che scoperta
  dopo.** Il giocatore **dà il nome ai cuccioli che nascono**
  (`scenes/world/Nascite.gd`, un `LineEdit` con `max_length = 18`). Quel nome
  diventa la `label` di un residente, entra in `rit["nomi"]` e da lì nel
  prompt (`Suggeritore._nomi_del_villaggio`). Sono **diciotto caratteri
  arbitrari per nascita**: l'unico testo del giocatore che raggiunge il
  modello. Attenuanti reali, nessuna delle quali è una difesa completa: il
  testo generato **non lascia la macchina** (nessuna rete, verificato con
  `nm -u` e `lsof`), non è pubblicato, non è condiviso, e la grammatica
  impedisce di riprodurre un nome proprio nelle righe libere. **Non è stata
  aggiunta nessuna lista di parole vietate**, e la scelta è dichiarata: un
  filtro sui nomi che il giocatore dà ai propri cuccioli è invasivo, sbaglia
  in tutte le lingue del mondo, e proteggerebbe il giocatore da sé stesso su
  un testo che nessun altro leggerà mai. **È una decisione da confermare con
  il legale** (vedi in fondo).
- **«pratica non autorizzata di una professione», «decisioni automatiche su
  diritti materiali»**: i vicini parlano di orti e di panchine. Fuori portata.

### 5. Obblighi di dichiarare che un testo è generato da un modello?

**Dalla Prohibited Use Policy: non un obbligo di etichetta, ma un divieto di
inganno.** Il testo vieta la *«Misrepresentation of the provenance of generated
content by claiming content was created by a human … in order to deceive»*.
La condizione *«in order to deceive»* è nel testo: una lettera firmata da un
gufo immaginario, dentro un gioco, non è una falsa attribuzione a un essere
umano. **Ma il gioco lo dichiara lo stesso**, nella pagina Note legali e nel
NOTICE, perché è la cosa onesta e costa una riga.

**Dalle regole dei negozi: qui un obbligo c'è, ed è di Valve.** Steam chiede
una **AI Content Disclosure** nel Content Survey, distinguendo *Pre-Generated*
(contenuto creato con l'IA durante lo sviluppo) da **Live-Generated**
(contenuto creato mentre il gioco gira). Chibi Crossing ricade in
**Live-Generated**: il modello scrive sulla macchina del giocatore, in
partita. Parte della dichiarazione finisce **sulla pagina del negozio**, e per
il Live-Generated Valve chiede anche un impegno sulle protezioni contro i
contenuti illegali.

> ⚠️ **Questo punto NON è verificato alla fonte.** La documentazione
> Steamworks sta dietro il login da partner, e Valve ha **riscritto le regole
> a gennaio 2026**. Quanto sopra viene da fonti secondarie. **Da rileggere
> sul Steamworks vero prima di compilare il Content Survey**, e lo stesso vale
> per gli altri canali (itch.io, Epic, Microsoft Store), che hanno regole
> proprie.

### 6. Soglie di utenti o di fatturato?

**Nessuna.** Cercate nel testo: «commercial», «monthly active», «revenue»,
«threshold» — **zero occorrenze**. I Gemma Terms of Use non hanno la clausola
a soglia che ha invece la licenza di Llama (700 milioni di utenti mensili).
Gli obblighi sono identici alla prima copia venduta e alla milionesima.

L'unica cosa che può cambiare da sola è il **testo**: la Sezione 4.1 dice che
Google può aggiornare Gemma, e le due pagine dichiarano una data di ultima
modifica. La copia che spediamo è quella del 2026-08-13; l'autorevole resta
quella online.

### 7. Conflitti con un `LICENSE` proprietario «All Rights Reserved»?

**Sì, ce n'era uno potenziale, ed è stato chiuso.** L'ultimo capoverso della
3.1 permette di imporre condizioni proprie, ma: *«Any additional or different
terms and conditions you impose must not conflict with the terms of this
Agreement»*.

Il `LICENSE` diceva: *«NO PERMISSION is granted to any person to use, copy,
modify, adapt, merge, translate, publish, distribute … the Work»* e vietava
di usare l'Opera *«to train, fine-tune or evaluate machine-learning models»*.
Se l'«Opera» avesse compreso i pesi, quelle righe avrebbero preteso di
togliere al destinatario diritti che i Gemma Terms of Use gli danno — cioè un
conflitto. Ora il `LICENSE` porta, in entrambe le lingue:

- **il carve-out** — i pesi non fanno parte dell'Opera e non sono licenziati
  da quel documento;
- **la clausola di prevalenza** — in caso di contrasto su Gemma prevalgono i
  Gemma Terms of Use;
- **il flow-down** dei vincoli d'uso (domanda 4);
- l'attribuzione **senza endorsement** (Sezione 4.2: nessun diritto sui
  marchi Google).

**Il resto del gioco resta chiuso, e questo non è in conflitto**: la 3.1
permette esplicitamente termini diversi sul Model Derivative *«as a whole»*.
Quello che non si può fare è pretendere di chiudere **Gemma**, ed è
esattamente ciò che il carve-out evita.

---

## ⚠️ DA PORTARE A UN LEGALE PRIMA DI PUBBLICARE

Nessuno di questi punti è stato risolto qui. Sono elencati in ordine di
rischio.

1. **Il carve-out regge?** Un `LICENSE` «All Rights Reserved» che contiene una
   sezione in cui una parte del pacchetto è esclusa e governata da un accordo
   di terzi è una costruzione che va **letta da chi sa leggerla**. La domanda
   precisa: *il testo attuale evita il conflitto vietato dall'ultimo capoverso
   della Sezione 3.1, oppure una clausola generale «All Rights Reserved»
   contamina comunque il tutto?*
2. **Il flow-down è davvero opponibile all'utente finale?** La 3.1 chiede una
   *enforceable provision*. Un file `LICENSE` dentro un pacchetto non è un
   EULA accettato con un clic: **serve un flusso di accettazione** (schermata
   al primo avvio, EULA sulla pagina del negozio)? E se sì, come si concilia
   con un gioco che vuole cominciare dal temporale del Prologo e non da un
   modulo? *Questa è la domanda con la conseguenza di prodotto più grossa.*
3. **Consumatori europei, e legge applicabile.** I Gemma Terms of Use sono
   governati dalla **legge della California** con **foro esclusivo a Santa
   Clara County** (Sezione 4.6). Il gioco lo vende un autore **italiano** a
   consumatori **europei**, per i quali esistono norme inderogabili su foro e
   diritto applicabile. Come si scrive un flow-down che vincoli il giocatore
   senza imporgli clausole nulle nei suoi confronti?
4. **L'AI Act europeo.** Il gioco è distribuito in UE e genera testo sintetico
   sulla macchina dell'utente. Gli obblighi di trasparenza dell'**articolo 50**
   (marcatura del contenuto sintetico, informazione all'utente) si applicano a
   un videogioco single-player? In che qualità agisce l'autore — *provider* o
   *deployer*? **Non è stata presa nessuna posizione qui**, oltre a dichiarare
   le cose in chiaro nel gioco perché è comunque la cosa giusta.
5. **La superficie dei nomi digitati.** I diciotto caratteri della domanda 4
   entrano nel prompt e non sono filtrati. *Quel residuo è accettabile
   rispetto agli obblighi assunti verso Google e verso i negozi, considerato
   che nulla lascia la macchina del giocatore?* Se la risposta è no, la cura
   tecnica è nota e piccola (non passare al modello i nomi scelti dal
   giocatore) — ma cambia cosa il modello può scrivere, e va decisa, non
   improvvisata.
6. **La dichiarazione IA sui negozi.** Da rileggere sul Steamworks vero
   (domanda 5), più le regole degli altri canali.
7. **Responsabilità sul testo generato.** La Sezione 3.3 dice che Google non
   rivendica diritti sugli Output e che *«You and your users are solely
   responsible»*. Il `LICENSE` lo ripete verso il giocatore. **Basta come
   limitazione di responsabilità verso un consumatore**, se un modello
   scrivesse su qualcuno una frase spiacevole? (Il rischio è basso: le righe
   libere non possono contenere maiuscole, quindi non possono nominare
   nessuno — ma «basso» non è «zero», e non è una valutazione che spetta a me.)

---

## Manutenzione

- **Se cambia il modello**, va rifatto tutto questo: licenza, NOTICE,
  `THIRD_PARTY_NOTICES.md`, e l'impronta in `Llm.gd`. In particolare
  **Gemma 4 è Apache 2.0**, non Gemma Terms of Use: sparirebbero il flow-down
  e i vincoli d'uso, e la pagina Note legali direbbe una cosa falsa.
- **Se cambia una libreria**, basta `python3 tools/genera_licenze.py`: l'avviso
  spedito si riassembla dai `LICENSE` veri. `--verifica` dice se è da
  rigenerare, e non va lasciato fallire.
- **Se cambia l'export o `release.yml`**, il cancello «Le licenze sono DENTRO
  i pacchetti?» apre gli zip veri e ferma la Release. Non aggiratelo: senza
  quei file il pacchetto è privo di licenza, non «privo di un dettaglio».
