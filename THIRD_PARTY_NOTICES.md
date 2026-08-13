# Note sui componenti di terze parti

Chibi Crossing è software proprietario (vedi [`LICENSE`](LICENSE)), ma include o
si appoggia a componenti di terze parti che restano soggetti alle **proprie**
licenze. Le licenze qui sotto si applicano SOLO a quei componenti, non al codice
di Chibi Crossing.

Mantenere questo file (e i file `LICENSE` dentro le rispettive cartelle) è un
**obbligo** delle licenze MIT: richiedono che l'avviso di copyright sia incluso
nelle distribuzioni. Non rimuoverli.

---

## godot-cpp

Bindings C++ per le GDExtension di Godot (`godot-cpp/`, incluso come submodule).
Licenza: **MIT** — Copyright (c) 2017-present Godot Engine contributors,
Copyright (c) 2022-present Godot Foundation.
Testo completo: [`godot-cpp/LICENSE.md`](godot-cpp/LICENSE.md).

## lua-gdextension

Addon che porta Lua in Godot (`addons/lua-gdextension/`).
Licenza: **MIT** — Copyright (C) 2026 Gil Barbosa Reis.
Testo completo: [`addons/lua-gdextension/LICENSE`](addons/lua-gdextension/LICENSE).

## EnTT

Libreria ECS (Entity Component System) header-only, vendorizzata come singolo
header in `src/thirdparty/entt/entt.hpp` (versione **3.13.2**, presa da
`single_include/entt/entt.hpp` del repo a monte). La usa il cuore C++ del gioco
per il registro delle entità (`src/ecs_mondo.cpp`).
Licenza: **MIT** — Copyright (c) 2017-2023 Michele Caini, author of EnTT.
Testo completo: [`src/thirdparty/entt/LICENSE`](src/thirdparty/entt/LICENSE).

## llama.cpp (e ggml)

Motore di inferenza per modelli linguistici, incluso come **submodule** in
`src/thirdparty/llama.cpp` e **pinnato al tag `b10326`** (SHA `3653e6d`).
Comprende `ggml`, che vive nello stesso repository (`ggml/`).
Licenza: **MIT** — Copyright (c) 2023-2026 The ggml authors.
Testo completo: [`src/thirdparty/llama.cpp/LICENSE`](src/thirdparty/llama.cpp/LICENSE).

Entra nel gioco **solo** nelle build compilate con `scons llm=yes`; con la leva
spenta (il default) non una riga di llama.cpp finisce nel binario. Quando è
acceso, il codice compilato è quello delle librerie `llama`, `ggml`,
`ggml-base` e dei backend di calcolo: `common/`, i tool, il server e la
cartella `vendor/` (cpp-httplib, nlohmann/json, miniaudio, stb, sheredom) **non
vengono compilati** (`LLAMA_BUILD_COMMON=OFF`), quindi le loro licenze non
riguardano il gioco distribuito.

Dentro il codice compilato ci sono due contributi di terzi, tutti e due MIT e
tutti e due con l'avviso nel file sorgente:

- `ggml/src/ggml-cpu/llamafile/sgemm.cpp` — Copyright 2024 Mozilla Foundation;
- `rope_yarn` in `ggml/src/ggml-cpu/ops.cpp` — Copyright (c) 2023 Jeffrey
  Quesnelle e Bowen Peng.

> **I PESI DEI MODELLI SONO UN'ALTRA COSA.** La licenza MIT di llama.cpp copre
> il motore, non i modelli che gli si danno da leggere: ogni `.gguf` ha la
> licenza sua. Il modello di questo gioco **non viaggia nel pacchetto** — lo
> scarica il giocatore, dal gioco, se accende la funzione. La sua voce è qui
> sotto: è l'unica di questo file che **non** è MIT, ed è anche l'unica che
> descrive una cosa che noi **non distribuiamo**.

## Gemma 3 4B IT — il modello che NON spediamo (e non è MIT)

Il modello linguistico che scrive in locale le lettere del Gufo e i pensieri
dei vicini. **Non è nel pacchetto e non è nel repository** (`*.gguf` in
`.gitignore`): se il giocatore accende «Il villaggio pensa», è il **gioco sulla
sua macchina** a scaricarne una copia, una volta, da Hugging Face. Noi non lo
ospitiamo, non lo serviamo e non lo consegniamo a nessuno.

Sta in questo file lo stesso, e per tre ragioni che non sono formali: il gioco
**nomina** Gemma, **porta con sé** i suoi documenti di licenza, ed è il gioco a
**farlo girare** sulla macchina di chi gioca.

| | |
|---|---|
| modello | **Gemma 3 4B IT** — Google DeepMind |
| file | `gemma-3-4b-it-Q4_K_M.gguf`, salvato come `pensieri.gguf` (2 489 757 856 byte) |
| scaricato da | <https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF> (quantizzazione di `google/gemma-3-4b-it`) |
| revisione | `d0976223747697cb51e056d85c532013931fe52e` |
| impronta | SHA-256 `882e8d2d…a0863` — `Llm.IMPRONTA_SPEDITO`, verificata dal portiere prima di aprire il file |
| licenza | **Gemma Terms of Use** — <https://ai.google.dev/gemma/terms> |
| più | **Gemma Prohibited Use Policy**, richiamata dalla Sezione 3.2 dei Termini |

**Chi ha quantizzato non aggiunge condizioni sue.** Il repository di ggml-org
dichiara `license: gemma` nella scheda del modello, non è *gated*, e non
contiene nessun file di licenza proprio (verificato via API il 2026-08-13: i
soli file sono `.gitattributes`, `README.md` e i `.gguf`). Le uniche condizioni
sono quelle di Google. E prenderlo da lì non cambia niente — Sezione 1.1(c):
«Gemma» sono quei pesi *«regardless of the source that you obtained it from»*.
Lo dice anche il file: la chiave `general.license` dentro il `.gguf` vale
`gemma`.

### La Sezione 3.1 non ci vincola più — e cosa resta al suo posto

La **Sezione 3.1** apre con *«You may reproduce or **Distribute** copies of
Gemma … **if** you meet all of the following conditions»*: le quattro
condizioni sono il **prezzo di una licenza a ridistribuire**. La **1.1(b)**
definisce «Distribution» come *«any transmission, publication, or other
sharing of Gemma … to a third party»*, incluso il metterne a disposizione la
funzionalità *«as a hosted service»*. Da quando il modello lo scarica il
giocatore: non trasmettiamo (i byte vanno da Hugging Face al suo disco), non
pubblichiamo (nessuna copia nostra, da nessuna parte), non condividiamo (non
ne possediamo una da passare) e non ospitiamo niente (l'inferenza è sulla sua
macchina). **Le tre condizioni che parlano di destinatari non hanno più
destinatari su cui mordere, e la quarta — gli avvisi sui file modificati — non
ci ha mai riguardato.**

| Sezione 3.1 | cosa chiedeva | adesso |
|---|---|---|
| punto 1 | i vincoli d'uso della 3.2 come clausola vincolante, più l'avviso a chi riceve | **non dovuto per la 3.1** — ma la clausola resta nel [`LICENSE`](LICENSE), su un'altra base: vedi qui sotto |
| punto 2 | una copia dell'accordo a ogni destinatario | **nessun destinatario** — la copia si spedisce lo stesso, perché il gioco è l'unico posto in cui il giocatore la vedrà |
| punto 3 | avvisi sui file modificati | non ci ha mai riguardato: non modifichiamo niente |
| punto 4 | un file «Notice» con la frase esatta | **non dovuto** — il file resta, come cautela dichiarata (`misc/licenze/NOTICE-Gemma.txt`) |

**Quello che NON è cambiato di una virgola**, e vale la pena elencarlo perché
è la parte che continua a vincolare qualcuno:

- **Sezione 2.2 e 3.2 — l'uso.** *«You may use … any of the Gemma Services only
  in accordance with the terms»*, e *«You must not use any of the Gemma
  Services … for the restricted uses set forth in the Gemma Prohibited Use
  Policy»*. Vale per chi usa Gemma: il giocatore (che vi si vincola da sé,
  scaricando o usando) e noi, che lo usiamo per svilupparlo e provarlo.
- **La Prohibited Use Policy vincola anche chi PERMETTE.** La sua frase
  operativa è *«You may not use **nor allow others to use** Gemma or Model
  Derivatives to: …»*, e quella metà non dipende da nessuna distribuzione. Noi
  scegliamo il modello, scegliamo la fonte, pinniamo la revisione, facciamo la
  richiesta e scriviamo il file: è il motivo per cui il vincolo d'uso resta
  scritto nel `LICENSE` **come clausola nostra**, non più «come richiesto dalla
  Sezione 3.1».
- **Sezione 3.3 — il testo generato.** *«Google claims no rights in Outputs …
  You and your users are solely responsible»*.
- **Sezione 4.2 — i marchi.** Nessun diritto sui marchi Google: «Gemma» e
  «Google» compaiono solo per dire quale modello, e il gioco dichiara di non
  essere affiliato.

### ⚠️ A monte c'è un cancello di accettazione, e noi ci passiamo accanto

MISURATO il 2026-08-13, con l'API di Hugging Face:

| repository | `gated` | cosa vede chi ci va |
|---|---|---|
| `google/gemma-3-4b-it` (Google) | **`manual`** | *«you're required to review and agree to Google's usage license … [Acknowledge license]»* |
| `ggml-org/gemma-3-4b-it-GGUF` (da cui scarichiamo) | **`false`** | il file, e basta: HTTP 200 senza credenziali |

Chi va a prendere Gemma da Google **la licenza la legge e la accetta**. Chi
lascia scaricare il file al nostro gioco, dal mirror quantizzato, non vedrebbe
niente — e nemmeno il mirror gli consegna l'accordo. Il gioco quindi **mostra i
Gemma Terms of Use e la Prohibited Use Policy, e chiede di accettarli, prima di
scaricare**: non per la 3.1, che non ci vincola più, ma perché il **preambolo**
dei Termini dice che ci si vincola *«by using, reproducing … any portion or
element of Gemma»*, cioè con lo scaricamento stesso. Senza quel passo, il
giocatore sarebbe vincolato a un accordo che nessuno gli ha mai fatto vedere.

La cartella `misc/licenze/` continua perciò a **viaggiare**: accanto
all'eseguibile (su macOS in `Contents/Resources/Licenze/`) e dentro il `.pck`,
così la schermata «Note legali» del gioco e la schermata dello scaricamento
possono leggerla. Chi tocca l'export o `release.yml` non deve perderla per
strada: `tests/cases/test_licenze.gd` fa la guardia.

> ⚠️ **NESSUNA SOGLIA, E NESSUN LIMITE COMMERCIALE.** Nei Gemma Terms of Use
> la parola «commercial» non compare affatto, e non c'è nessuna soglia di
> utenti o di fatturato (a differenza della licenza di Llama, che ne ha una a
> 700 milioni di utenti mensili). Non c'è quindi niente che scatti quando il
> gioco vende.

> ⚠️ **GEMMA 3 E GEMMA 4 NON HANNO LA STESSA LICENZA.** I Termini qui sopra
> valgono per i modelli elencati nella loro Appendix, dove **Gemma 3 c'è**.
> **Gemma 4 no**: è sotto **Apache 2.0** (<https://ai.google.dev/gemma/apache_2>),
> che non ha né la clausola di *flow-down* della 3.1 né i vincoli d'uso della
> 3.2. Se un domani si passasse a `gemma-4-E2B` — l'altro candidato misurato
> in `CLAUDE.md` — questa sezione andrebbe **rifatta da capo**, non ritoccata:
> cambierebbe cosa va mostrato, cosa va scritto nel `LICENSE`, e sparirebbe la
> ragione stessa della schermata di accettazione (con Apache 2.0 non c'è
> nessuna policy d'uso a cui il giocatore debba vincolarsi).

## Godot Engine

Il gioco gira sul motore **Godot Engine** (MIT — Copyright (c) 2014-present
Godot Engine contributors, Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur).
Il motore non è incluso in questo repository: viene scaricato a parte e
ridistribuito nelle build esportate secondo la sua licenza.
<https://godotengine.org/license>

---

> **Nota storica:** fino al 2026-07-26 il file `LICENSE` nella radice del
> repository conteneva per errore la licenza MIT di *lua-gdextension* (intestata
> a Gil Barbosa Reis), il che faceva sembrare l'intero progetto licenziato MIT.
> È stato sostituito con la licenza proprietaria di Chibi Crossing; la licenza
> dell'addon resta correttamente nella sua cartella.
