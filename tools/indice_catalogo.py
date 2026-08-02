#!/usr/bin/env python3
"""Costruisce le pagine sfogliabili del catalogo visivo.

Legge `docs/catalogo/manifesto.json` (lo scrive `tools/scatto_catalogo.gd`) e
genera un README per ogni categoria piu' l'indice generale. Si rilancia dopo
ogni nuova infornata di scatti:

    python3 tools/indice_catalogo.py

Le miniature sono <img> HTML dentro la tabella Markdown: e' l'unico modo per
imporre una larghezza su GitHub, e senza larghezza una pagina con 90 immagini
a piena risoluzione non si apre.
"""

import json
import pathlib
import sys

RADICE = pathlib.Path(__file__).resolve().parent.parent
CATALOGO = RADICE / "docs" / "catalogo"

CATEGORIE = {
    0: ("0-struttura", "Struttura", "muri, pavimenti, tetti e i pezzi-guscio dei luoghi"),
    1: ("1-arredo", "Arredo", "quello che si mette dentro: mobili, banconi, strumenti"),
    2: ("2-giardino", "Giardino", "quello che sta fuori: verde, luci, giochi, servizi"),
    3: ("3-palestra", "Palestra", "gli otto attrezzi di legno, tela e sassi di fiume"),
    4: ("4-chiesa", "Chiesa", "la chiesa del paese, pezzo per pezzo"),
    5: ("5-boutique", "Boutique", "il negozio di vestiti: vetrina, stender, camerini"),
    6: ("6-personaggi", "Personaggi", "i cinque archetipi dei chibi, generati dal DNA"),
}

VISTE = [("1-fronte.png", "fronte"), ("2-tre-quarti.png", "tre quarti"),
         ("3-profilo.png", "profilo")]


def main() -> int:
    manifesto_file = CATALOGO / "manifesto.json"
    if not manifesto_file.exists():
        print("manca %s: lancia prima tools/scatto_catalogo.gd" % manifesto_file)
        return 1
    voci = json.loads(manifesto_file.read_text())

    per_cat: dict[int, list] = {}
    for v in voci:
        per_cat.setdefault(int(v["cat"]), []).append(v)

    for cat, elenco in sorted(per_cat.items()):
        cartella, titolo, sottotitolo = CATEGORIE[cat]
        righe = [
            "# %s" % titolo,
            "",
            "*%s* — %d pezzi." % (sottotitolo, len(elenco)),
            "",
            "| | fronte | tre quarti | profilo |",
            "|---|---|---|---|",
        ]
        for v in sorted(elenco, key=lambda x: x["nome"]):
            celle = []
            for file, _ in VISTE:
                percorso = "%s/%s" % (v["slug"], file)
                if (CATALOGO / cartella / v["slug"] / file).exists():
                    celle.append('<img src="%s" width="200">' % percorso)
                else:
                    celle.append("—")
            misure = "%.2f × %.2f m" % (float(v["largo"]), float(v["alto"]))
            righe.append("| **%s**<br><sub>%s</sub> | %s | %s | %s |"
                         % (v["nome"], misure, celle[0], celle[1], celle[2]))
        righe += ["", "[« torna all'indice](../README.md)", ""]
        (CATALOGO / cartella / "README.md").write_text("\n".join(righe))
        print("scritto %s/README.md (%d pezzi)" % (cartella, len(elenco)))

    totale = len(voci)
    indice = [
        "# Il catalogo visivo di Chibi Crossing",
        "",
        "Tre foto di **ogni singolo asset** del gioco — fronte, tre quarti e",
        "profilo — una cartella per pezzo. In tutto **%d asset**, **%d immagini**."
        % (totale, totale * 3),
        "",
        "Le foto NON sono disegni: sono i pezzi veri, costruiti dal loro builder e",
        "renderizzati in uno studio con la luce e l'ombra del gioco. Se un pezzo",
        "cambia, si rifanno con un comando solo e il catalogo torna vero.",
        "",
        "```bash",
        "CHIBI_CATALOGO=docs/catalogo ~/Downloads/Godot.app/Contents/MacOS/Godot \\",
        "    --path . --script res://tools/scatto_catalogo.gd",
        "python3 tools/indice_catalogo.py",
        "```",
        "",
        "| categoria | pezzi | cos'è |",
        "|---|---|---|",
    ]
    for cat, elenco in sorted(per_cat.items()):
        cartella, titolo, sottotitolo = CATEGORIE[cat]
        indice.append("| [%s](%s/README.md) | %d | %s |"
                      % (titolo, cartella, len(elenco), sottotitolo))
    indice += [
        "",
        "## Come sono fatte le foto",
        "",
        "- **900 × 900**, sempre: si renderizza in un `SubViewport`, non nella",
        "  finestra (che su macOS non rispetta `--resolution` e cambia misura da",
        "  una macchina all'altra).",
        "- **L'inquadratura è calcolata**, non scelta a mano: si misura l'ingombro",
        "  vero delle mesh e si arretra quanto basta perché ogni pezzo riempia la",
        "  stessa frazione di immagine — dal fungo da dieci centimetri al",
        "  campanile da due metri e mezzo.",
        "- **Il fronte è -Z**: la vista «fronte» è quella che vede il giocatore",
        "  quando posa il pezzo senza ruotarlo.",
        "",
    ]
    (CATALOGO / "README.md").write_text("\n".join(indice))
    print("scritto README.md (%d asset)" % totale)
    return 0


if __name__ == "__main__":
    sys.exit(main())
