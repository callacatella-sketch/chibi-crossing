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
