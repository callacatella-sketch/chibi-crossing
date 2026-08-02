#!/usr/bin/env python3
"""Monta il catalogo in PROVINI da guardare: un foglio per categoria.

Le 399 foto singole servono a esaminare un pezzo; per passarli in rassegna
tutti serve un foglio unico. Qui ogni asset diventa una striscia — nome,
misure, e le tre viste affiancate — e gli asset stanno due per riga.

    python3 tools/provini_catalogo.py [cartella_uscita]

Escono dei JPEG (uno per categoria) larghi ~1700 px: si aprono con un clic
e si scorrono. Il default è docs/catalogo/provini/.
"""

import json
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

RADICE = pathlib.Path(__file__).resolve().parent.parent
CATALOGO = RADICE / "docs" / "catalogo"

CATEGORIE = {
    0: ("0-struttura", "STRUTTURA"),
    1: ("1-arredo", "ARREDO"),
    2: ("2-giardino", "GIARDINO"),
    3: ("3-palestra", "PALESTRA"),
    4: ("4-chiesa", "CHIESA"),
    5: ("5-boutique", "BOUTIQUE"),
    6: ("6-personaggi", "PERSONAGGI"),
}
VISTE = ["1-fronte.jpg", "2-tre-quarti.jpg", "3-profilo.jpg"]

TILE = 260          # lato di ogni vista nel provino
GUTTER = 8
ETICHETTA = 30      # riga del nome sotto ogni striscia
COLONNE = 2         # asset per riga
MARGINE = 26
FONDO = (247, 247, 245)
INCHIOSTRO = (40, 40, 44)
TENUE = (125, 125, 132)


def _font(dim, grassetto=False):
    for nome in (["/System/Library/Fonts/Supplemental/Arial Bold.ttf",
                  "/System/Library/Fonts/Helvetica.ttc"] if grassetto else
                 ["/System/Library/Fonts/Supplemental/Arial.ttf",
                  "/System/Library/Fonts/Helvetica.ttc"]):
        try:
            return ImageFont.truetype(nome, dim)
        except OSError:
            continue
    return ImageFont.load_default()


def foglio(cartella, titolo, voci, dove):
    larghezza_blocco = TILE * 3 + GUTTER * 2
    altezza_blocco = TILE + ETICHETTA
    righe = (len(voci) + COLONNE - 1) // COLONNE
    w = MARGINE * 2 + larghezza_blocco * COLONNE + GUTTER * 3 * (COLONNE - 1)
    h = MARGINE * 2 + 54 + righe * (altezza_blocco + GUTTER * 3)

    foglio = Image.new("RGB", (w, h), FONDO)
    d = ImageDraw.Draw(foglio)
    f_tit = _font(30, True)
    f_nome = _font(17, True)
    f_mis = _font(14)

    d.text((MARGINE, MARGINE - 4), titolo, font=f_tit, fill=INCHIOSTRO)
    d.text((MARGINE + d.textlength(titolo, font=f_tit) + 14, MARGINE + 10),
           "%d pezzi · fronte · tre quarti · profilo" % len(voci),
           font=f_mis, fill=TENUE)

    y0 = MARGINE + 54
    for i, v in enumerate(voci):
        col = i % COLONNE
        rig = i // COLONNE
        x = MARGINE + col * (larghezza_blocco + GUTTER * 3)
        y = y0 + rig * (altezza_blocco + GUTTER * 3)
        for k, vista in enumerate(VISTE):
            f = CATALOGO / cartella / v["slug"] / vista
            if not f.exists():
                continue
            im = Image.open(f).convert("RGB").resize((TILE, TILE), Image.LANCZOS)
            foglio.paste(im, (x + k * (TILE + GUTTER), y))
        d.text((x + 2, y + TILE + 5), v["nome"], font=f_nome, fill=INCHIOSTRO)
        misure = "%.2f × %.2f m" % (float(v["largo"]), float(v["alto"]))
        d.text((x + 4 + d.textlength(v["nome"], font=f_nome) + 10, y + TILE + 7),
               misure, font=f_mis, fill=TENUE)

    foglio.save(dove, "JPEG", quality=88, optimize=True, progressive=True)
    return foglio.size


def main() -> int:
    uscita = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else CATALOGO / "provini"
    uscita.mkdir(parents=True, exist_ok=True)
    voci = json.loads((CATALOGO / "manifesto.json").read_text())
    per_cat = {}
    for v in voci:
        per_cat.setdefault(int(v["cat"]), []).append(v)
    for cat, elenco in sorted(per_cat.items()):
        cartella, titolo = CATEGORIE[cat]
        elenco = sorted(elenco, key=lambda x: x["nome"])
        f = uscita / ("provino-%s.jpg" % cartella)
        dim = foglio(cartella, titolo, elenco, f)
        print("%s  %d pezzi  %dx%d  %d KB" %
              (f.name, len(elenco), dim[0], dim[1], f.stat().st_size // 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main())
