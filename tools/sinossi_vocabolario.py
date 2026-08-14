#!/usr/bin/env python3
"""LA SINOSSI — tutti i gesti sulla stessa lastra, a UNA distanza.

    python3 tools/sinossi_vocabolario.py <dir> <distanza: 2|4|6|9>

Non renderizza niente: ritaglia le colonne di quella distanza dalle lastre
che `tools/provino_vocabolario.gd` ha gia' prodotto, e le impila per gesto.
E' il confronto che conta piu' di tutti — **il gesto vecchio (la testa che si
gira) e' la prima riga**, con lo stesso corpo, la stessa luce, la stessa
camera e lo stesso ritaglio: se un gesto nuovo non si stacca da quella riga,
non ha ragione di esistere.

⚠️ Le coordinate qui sotto NON sono indovinate: sono le stesse costanti del
provino (LM/TT/TM/TILE_D). Se cambiano di la', cambiano qui — e il ritaglio
uscirebbe storto in silenzio, che e' il motivo per cui questo file le nomina.
"""
import sys, os
from PIL import Image, ImageDraw, ImageFont

LM, TT, TM, TILE = 120, 44, 46, 195
VISTE = ["fronte", "trequarti", "profilo", "spalle"]
DIST = [2.0, 4.0, 6.0, 9.0]
ORDINE = ["ricevuta", "premessa", "pensiero", "rinuncia", "evitamento",
          "sollievo", "capo", "coda"]
NOMI = {
    "ricevuta": "IERI\nla testa\nche si gira",
    "premessa": "premessa\nil Punto",
    "pensiero": "pensiero\nPunto deciso",
    "rinuncia": "rinuncia\nil Raccolto",
    "evitamento": "evitamento\nil Largo",
    "sollievo": "sollievo\nil Rialzo",
    "capo": "livello\nil Capo",
    "coda": "livello\nla Coda",
}


def font(n):
    for p in ("/System/Library/Fonts/Supplemental/Arial.ttf",
              "/System/Library/Fonts/Helvetica.ttc"):
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, n)
            except Exception:
                pass
    return ImageFont.load_default()


def main():
    d = sys.argv[1]
    dist = float(sys.argv[2]) if len(sys.argv) > 2 else 6.0
    ci = DIST.index(dist)
    coppie = os.environ.get("COPPIE", "") != ""
    ncol = len(VISTE) * (2 if coppie else 1)
    MW, MH = 150, 54
    W = MW + ncol * TILE
    H = MH + len(ORDINE) * TILE
    out = Image.new("RGB", (W, H), (26, 26, 30))
    dr = ImageDraw.Draw(out)
    f1, f2 = font(21), font(16)
    dr.text((10, 14), "TUTTO IL VOCABOLARIO A %.0f METRI — il colmo di ogni gesto, "
            "dai quattro lati (prima riga: il gesto di IERI)" % dist,
            font=f1, fill=(255, 255, 255))
    for c in range(ncol):
        v = VISTE[c // 2] if coppie else VISTE[c]
        et = v + ("  riposo" if coppie and c % 2 == 0 else ("  GESTO" if coppie else ""))
        dr.text((MW + c * TILE + 8, MH - 24), et, font=f2, fill=(235, 235, 235))
    for r, g in enumerate(ORDINE):
        p = os.path.join(d, "%s_distanze.jpg" % g)
        if not os.path.exists(p):
            continue
        src = Image.open(p)
        for c in range(ncol):
            vi = c // 2 if coppie else c
            col = ci * 2 + (c % 2 if coppie else 1)
            box = (LM + col * TILE, TT + TM + vi * TILE,
                   LM + (col + 1) * TILE, TT + TM + (vi + 1) * TILE)
            out.paste(src.crop(box), (MW + c * TILE, MH + r * TILE))
        for i, riga in enumerate(NOMI[g].split("\n")):
            dr.text((8, MH + r * TILE + 60 + i * 20), riga, font=f2,
                    fill=(255, 235, 170) if g == "ricevuta" else (235, 235, 235))
    nome = os.path.join(d, "SINOSSI_%dm%s.jpg" % (int(dist), "_coppie" if coppie else ""))
    out.save(nome, quality=94)
    print(nome, out.size)


main()
