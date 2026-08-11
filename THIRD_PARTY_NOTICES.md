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
> licenza sua, e il modello di questo gioco viaggerà **dentro il pacchetto**
> (quindi si ridistribuisce, e per giunta a scopo commerciale). Prima di
> sceglierne uno va letta la sua licenza, non quella di llama.cpp; e quando è
> scelto, la sua voce va aggiunta qui sotto insieme al file di licenza.

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
