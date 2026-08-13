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
> licenza sua, e il modello di questo gioco viaggia **dentro il pacchetto**
> (quindi si ridistribuisce, e per giunta a scopo commerciale). La sua voce è
> qui sotto — ed è l'unica di questo file che **non** è MIT.

## Gemma 3 4B IT — i pesi del modello (NON è MIT)

Il modello linguistico che scrive in locale le lettere del Gufo e i pensieri
dei vicini. **Viaggia dentro il pacchetto del gioco** (mai nel repository:
vedi `*.gguf` in `.gitignore`), quindi lo stiamo **ridistribuendo**, a scopo
commerciale, dentro un prodotto la cui [`LICENSE`](LICENSE) è proprietaria.

| | |
|---|---|
| modello | **Gemma 3 4B IT** — Google DeepMind |
| file | `gemma-3-4b-it-Q4_K_M.gguf`, spedito come `pensieri.gguf` (2 489 757 856 byte) |
| preso da | <https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF> (quantizzazione di `google/gemma-3-4b-it`) |
| licenza | **Gemma Terms of Use** — <https://ai.google.dev/gemma/terms> |
| più | **Gemma Prohibited Use Policy**, richiamata dalla Sezione 3.2 dei Termini |

**Chi ha quantizzato non aggiunge condizioni sue.** Il repository di ggml-org
dichiara `license: gemma` nella scheda del modello, non è *gated*, e non
contiene nessun file di licenza proprio: le uniche condizioni sono quelle di
Google. E prenderlo da lì non cambia niente — Sezione 1.1(c): «Gemma» sono
quei pesi *«regardless of the source that you obtained it from»*. Lo dice
anche il file: la chiave `general.license` dentro il `.gguf` vale `gemma`.

**I pesi si ridistribuiscono SENZA MODIFICHE.** Non li abbiamo addestrati,
rifiniti, quantizzati né alterati: il `.gguf` è copia byte per byte di quello
pubblicato da ggml-org. Perciò la Sezione 3.1 punto 3 («i file modificati
devono portare avvisi ben visibili che li avete modificati») non ci riguarda —
ma la catena è scritta lo stesso in `misc/licenze/NOTICE-Gemma.txt`, perché
dire *quale* file si sta spedendo è l'unico modo di rendere verificabile che
non è stato toccato.

### I QUATTRO OBBLIGHI, e dove sono stati assolti

La Sezione 3.1 dei Termini pone quattro condizioni alla ridistribuzione. Non
sono decorative: senza, la licenza per ridistribuire semplicemente non c'è.

| Sezione 3.1 | cosa chiede | dove è |
|---|---|---|
| punto 1 | i vincoli d'uso della 3.2 come **clausola vincolante** nell'accordo che governa l'uso, **più** l'avviso a chi riceve | [`LICENSE`](LICENSE), sezione «GEMMA MODEL WEIGHTS» / «I PESI DEL MODELLO GEMMA»; l'avviso in `NOTICE-Gemma.txt` |
| punto 2 | **una copia dell'accordo** a ogni destinatario | `misc/licenze/Gemma-Terms-of-Use.txt`, spedito nel pacchetto |
| punto 3 | avvisi sui **file modificati** | nessun file modificato; la catena è dichiarata in `NOTICE-Gemma.txt` |
| punto 4 | un file **«Notice»** con la frase esatta | `misc/licenze/NOTICE-Gemma.txt`, prima riga utile, parola per parola |

La cartella `misc/licenze/` è **quella che viaggia**: finisce accanto
all'eseguibile (su macOS in `Contents/Resources/Licenze/`, cioè dove sta anche
il modello) e dentro il `.pck`, così la schermata «Note legali» del gioco può
leggerla. Chi tocca l'export o `release.yml` non deve perderla per strada:
`tests/cases/test_licenze.gd` fa la guardia.

> ⚠️ **NESSUNA SOGLIA, E NESSUN LIMITE COMMERCIALE.** Nei Gemma Terms of Use
> la parola «commercial» non compare affatto, e non c'è nessuna soglia di
> utenti o di fatturato (a differenza della licenza di Llama, che ne ha una a
> 700 milioni di utenti mensili). Non c'è quindi niente che scatti quando il
> gioco vende: gli obblighi sono gli stessi alla prima copia e alla milionesima.

> ⚠️ **GEMMA 3 E GEMMA 4 NON HANNO LA STESSA LICENZA.** I Termini qui sopra
> valgono per i modelli elencati nella loro Appendix, dove **Gemma 3 c'è**.
> **Gemma 4 no**: è sotto **Apache 2.0** (<https://ai.google.dev/gemma/apache_2>),
> che non ha né la clausola di *flow-down* della 3.1 né i vincoli d'uso della
> 3.2. Se un domani si passasse a `gemma-4-E2B` — l'altro candidato misurato
> in `CLAUDE.md` — questa sezione andrebbe **rifatta da capo**, non ritoccata:
> cambierebbe cosa va spedito, cosa va scritto nel `LICENSE` e se il giocatore
> resta soggetto a una policy d'uso.

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
