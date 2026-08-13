#!/usr/bin/env python3
"""Assembla `misc/licenze/LICENZE-TERZE-PARTI.txt`, il file che VIAGGIA nel
pacchetto del gioco.

⚠️ NON si scrive a mano, e la ragione non è la comodità: la licenza MIT chiede
che l'avviso di copyright sia incluso «in all copies», e un avviso RICOPIATO
invecchia in silenzio. godot-cpp bumpa l'anno, EnTT cambia intestazione,
llama.cpp aggiunge un contributo — e il file spedito continua a dichiarare
quello di due anni fa, senza che niente diventi rosso. Qui le licenze si
LEGGONO da dove già vivono (la stessa REGOLA delle fonti uniche), e
`tests/cases/test_licenze.gd` fa la guardia che il file spedito le contenga
davvero.

    python3 tools/genera_licenze.py            # riscrive il file
    python3 tools/genera_licenze.py --verifica # esce 1 se è da rigenerare

Il testo di Godot Engine è l'unico che non vive nel repository (il motore si
scarica a parte), quindi sta qui sotto come costante, con la sua provenienza
scritta accanto. Tutti gli altri si leggono dal disco.
"""

import sys
import re
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
USCITA = RADICE / "misc" / "licenze" / "LICENZE-TERZE-PARTI.txt"
RIGA = "=" * 78
SOTTO = "-" * 78

# Godot Engine: il motore NON è in questo repository (si scarica a parte e si
# ridistribuisce dentro l'eseguibile esportato), quindi il suo testo non si può
# leggere dal disco. Copia verbatim da
# https://raw.githubusercontent.com/godotengine/godot/4.7/LICENSE.txt (2026-08-13).
GODOT_LICENSE = """Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE."""

# (titolo, a cosa serve, percorso del testo di licenza nel repo)
COMPONENTI = [
    ("Godot Engine",
     "Il motore su cui gira il gioco.  https://godotengine.org/license",
     None),
    ("godot-cpp",
     "I binding C++ con cui e' scritto il cuore nativo del gioco.",
     "godot-cpp/LICENSE.md"),
    ("lua-gdextension",
     "L'addon che porta Lua dentro Godot.  (C) Gil Barbosa Reis",
     "addons/lua-gdextension/LICENSE"),
    ("EnTT",
     "La libreria ECS del cuore nativo (registro delle entita').",
     "src/thirdparty/entt/LICENSE"),
    ("llama.cpp / ggml",
     "Il motore di inferenza che fa girare il modello linguistico in locale.",
     "src/thirdparty/llama.cpp/LICENSE"),
]

# Contributi di terzi che vivono DENTRO i sorgenti di ggml compilati nel gioco:
# la loro licenza sta nell'intestazione del file, non in un LICENSE a parte.
#
# ⚠️ L'intervallo comprende il PERMESSO per intero, non la sola riga di
# copyright: la MIT chiede «the above copyright notice AND this permission
# notice». Il primo giro ne portava una riga sola, e la riga sola non è un
# avviso MIT — è una citazione. (E per `ops.cpp` una riga di troppo si
# portava dietro `static void rope_yarn(`, cioè del codice dentro un file di
# licenze: si vede solo guardando il file generato.)
#
# I numeri di riga si spostano quando il sottomodulo si aggiorna: per questo
# `righe()` verifica di aver pescato davvero un avviso, e il generatore muore
# se non lo trova. Meglio una build rotta di un avviso di licenza sbagliato.
# (percorso, prima riga, ultima riga, un pezzo di testo che DEVE esserci)
INCORPORATI = [
    ("src/thirdparty/llama.cpp/ggml/src/ggml-cpu/llamafile/sgemm.cpp",
     1, 21, "Copyright 2024 Mozilla Foundation"),
    ("src/thirdparty/llama.cpp/ggml/src/ggml-cpu/ops.cpp",
     5827, 5828, "Copyright (c) 2023 Jeffrey Quesnelle and Bowen Peng"),
]


def leggi(rel: str) -> str:
    p = RADICE / rel
    if not p.is_file():
        raise SystemExit(
            f"MANCA {rel}\n"
            "Il sottomodulo non e' inizializzato? "
            "git submodule update --init --depth 1 <percorso>"
        )
    testo = p.read_text(encoding="utf-8")
    # I titoli markdown («# MIT License») non servono in un .txt: il titolo
    # della sezione lo mette gia' questo generatore.
    testo = re.sub(r"^#+ .*\n+", "", testo)
    return testo.strip()


def righe(rel: str, da: int, a: int, atteso: str) -> str:
    p = RADICE / rel
    if not p.is_file():
        raise SystemExit(f"MANCA {rel} (sottomodulo non inizializzato?)")
    tutte = p.read_text(encoding="utf-8", errors="replace").splitlines()
    fetta = [r.lstrip("/ ").rstrip() for r in tutte[da - 1:a]]
    testo = "\n".join(r for r in fetta if r)
    if atteso not in testo:
        raise SystemExit(
            f"ATTESO NON TROVATO in {rel} righe {da}-{a}:\n"
            f"  cercavo : {atteso}\n"
            f"  ho letto: {testo[:200]!r}\n"
            "Il sottomodulo llama.cpp si e' spostato: ritrova l'avviso e "
            "aggiorna i numeri di riga in INCORPORATI."
        )
    return testo


def costruisci() -> str:
    fuori = [
        RIGA,
        "  CHIBI CROSSING - LICENZE DEI COMPONENTI DI TERZE PARTI",
        "  CHIBI CROSSING - THIRD-PARTY LICENCES",
        RIGA,
        "",
        "Chibi Crossing e' software proprietario: vedi il file LICENSE.",
        "Chibi Crossing is proprietary software: see the LICENSE file.",
        "",
        "I componenti elencati qui sotto NON lo sono. Restano soggetti alle loro",
        "licenze, riportate per intero, e le licenze qui sotto si applicano SOLO a",
        "quei componenti.",
        "",
        "The components listed below are NOT. They remain subject to their own",
        "licences, reproduced in full; those licences apply ONLY to the components",
        "they accompany, not to Chibi Crossing itself.",
        "",
        "IL MODELLO LINGUISTICO HA UNA LICENZA SUA, CHE NON E' MIT:",
        "THE LANGUAGE MODEL HAS ITS OWN LICENCE, WHICH IS NOT MIT:",
        "  -> NOTICE-Gemma.txt",
        "  -> Gemma-Terms-of-Use.txt",
        "  -> Gemma-Prohibited-Use-Policy.txt",
        "",
        "Questo file e' GENERATO da tools/genera_licenze.py leggendo le licenze",
        "vere: non modificarlo a mano, le modifiche andrebbero perse.",
        "",
    ]

    for titolo, a_che_serve, rel in COMPONENTI:
        fuori += ["", SOTTO, "  " + titolo, SOTTO, "", a_che_serve, ""]
        fuori.append(GODOT_LICENSE if rel is None else leggi(rel))
        fuori.append("")

    fuori += ["", SOTTO,
              "  Contributi di terzi incorporati nei sorgenti di ggml",
              "  Third-party code embedded in the ggml sources",
              SOTTO, "",
              "Compilati dentro il motore di inferenza; l'avviso di licenza vive",
              "nell'intestazione del file sorgente e viene riportato qui.", ""]
    for rel, da, a, atteso in INCORPORATI:
        fuori += ["  " + rel, ""]
        fuori += ["    " + r for r in righe(rel, da, a, atteso).splitlines()]
        fuori.append("")

    return "\n".join(fuori).rstrip() + "\n"


def main() -> int:
    testo = costruisci()
    if "--verifica" in sys.argv:
        attuale = USCITA.read_text(encoding="utf-8") if USCITA.is_file() else ""
        if attuale == testo:
            print(f"{USCITA.relative_to(RADICE)}: aggiornato")
            return 0
        print(f"{USCITA.relative_to(RADICE)}: DA RIGENERARE "
              "(python3 tools/genera_licenze.py)", file=sys.stderr)
        return 1
    USCITA.parent.mkdir(parents=True, exist_ok=True)
    USCITA.write_text(testo, encoding="utf-8")
    print(f"scritto {USCITA.relative_to(RADICE)} - {len(testo)} byte, "
          f"{testo.count(chr(10))} righe")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
