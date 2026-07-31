#!/usr/bin/env python3
"""Genera un salvataggio DI PROVA per Chibi Crossing: molte case gia costruite
e nessun abitante, per verificare che i vicini si trasferiscano davvero e per
avere sottomano tutti i sistemi senza doverli sbloccare giocando.

    python3 tools/genera_salvataggio_prova.py --out tools/village_prova.json

Le liste che questo generatore usa (i nomi dei pezzi, i nomi dei chibi, il
listino del mercante, le tinte) NON sono ricopiate qui: si leggono dai file
dove gia vivono, come vuole la regola delle fonti uniche. Se un'altra sessione
aggiunge un pezzo al catalogo, questo generatore se ne accorge da solo.

COME E FATTA UNA CASA che un vicino accetta davvero (Visitors._free_house e
Visitors._house_features):

  * il gioco chiama "casa libera" un pezzo di nome esatto `Letto` che abbia una
    COPERTURA sulla sua stessa cella (`Tetto`, oppure un Solaio sopra) e che non
    sia gia occupato ne segnato come casa del giocatore. Il minimo assoluto e
    quindi Letto + Tetto: due righe.
  * ma «libera» non vuol dire «accettata». Il candidato guarda la casa, la
    riduce a otto numeri (tetto, muri, porta, finestra, comodita, giardino,
    calore, sole) e la passa a un percettrone con soglia p > 0.72. Una casa
    Letto+Tetto nuda vale p ~ 0.016: il candidato la guarda e riparte col
    trolley. Ecco perche qui ogni casa e completa: quattro muri di cui una
    porta e una finestra, due tappeti, comodino, libreria, camino e tre pezzi
    di giardino. Cosi tutte e otto le feature valgono 1.0.
  * e c'e una seconda leva: `cand_mem` (le visite passate). Vale +0.35 a visita
    fino a tre. Con `cand_mem = 3` anche il carattere piu difficile che il gioco
    sappia generare supera la soglia: gli arrivi diventano CERTI invece che
    probabili, che e quello che serve a un salvataggio di prova.

Con `--cand-mem 0` si ottiene il comportamento vero del gioco (accettano quasi
tutti, ma qualcuno rifiuta): utile per provare anche il rifiuto.
"""

import argparse
import json
import math
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


# --------------------------------------------------------------- le fonti

def _sorgente(rel: str) -> str:
    return (REPO / rel).read_text(encoding="utf-8")


def nomi_catalogo() -> set:
    """I nomi dei pezzi, letti da BuildCatalog.items() (la fonte unica)."""
    return set(re.findall(r'\{"name":\s*"([^"]+)"', _sorgente("scenes/build/BuildCatalog.gd")))


def nomi_chibi() -> list:
    """I 28 nomi di ChibiDNA.NAMES: sono le chiavi di `cand_mem`."""
    src = _sorgente("scenes/npc/ChibiDNA.gd")
    blocco = re.search(r"const NAMES := \[(.*?)\]", src, re.S)
    if not blocco:
        raise SystemExit("non trovo ChibiDNA.NAMES: la fonte e cambiata")
    return re.findall(r'"([^"]+)"', blocco.group(1))


def pezzi_negozio() -> list:
    """I nomi in Economy.SHOP_PIECES: scavalcano il recinto del Gufo, quindi
    senza questa lista meta dei sistemi da provare resta irraggiungibile."""
    src = _sorgente("scenes/ui/Economy.gd")
    blocco = re.search(r"const SHOP_PIECES := \[(.*?)\n\]", src, re.S)
    if not blocco:
        raise SystemExit("non trovo Economy.SHOP_PIECES: la fonte e cambiata")
    return re.findall(r'\{"name":\s*"([^"]+)"', blocco.group(1))


def tinte() -> list:
    src = _sorgente("scenes/ui/Economy.gd")
    blocco = re.search(r"const VARIANTS := \[(.*?)\n\]", src, re.S)
    if not blocco:
        raise SystemExit("non trovo Economy.VARIANTS: la fonte e cambiata")
    return re.findall(r'\{"id":\s*"([^"]+)"', blocco.group(1))


def ordini_del_gufo() -> list:
    """Gli id della campagna, per marcarla tutta fatta."""
    src = _sorgente("scenes/npc/GufoOrders.gd")
    blocco = re.search(r"const CHAIN := \[(.*?)\n\]", src, re.S)
    if not blocco:
        return []
    return re.findall(r'"id":\s*"([^"]+)"', blocco.group(1))


# ------------------------------------------------------------- il mondo

def river_x(z: float) -> float:
    """La stessa curva di WorldMath.river_x: serve a non piazzare una casa
    dentro il fiume — place_cell scarta quelle celle IN SILENZIO, senza
    nemmeno un avviso, e ti ritrovi una casa a cui manca meta pavimento."""
    return 18.6 + math.sin(z * 0.061) * 1.35 + math.sin(z * 0.023 + 2.0) * 0.85


def nel_fiume(x: int, z: int) -> bool:
    return abs(x - river_x(z)) < 2.9 and -56 < z < 56


# Le dieci origini: tre strade attorno alla radura centrale. Scelte per non
# sovrapporsi (ogni casa occupa 4x4 celle contando il giardino), per stare
# lontane dal fiume (x <= 11 contro un fiume che comincia a x ~ 16.4), fuori
# dal bosco (che comincia a z <= -15) e per non tappare i tre varchi da cui
# entrano i visitatori: (14, 8), (-14, 7), (11, -6).
ORIGINI = [
    (-13, 10), (-7, 10), (-1, 10), (5, 10),      # la fila a sud della piazza
    (-13, -11), (-13, -5), (-13, 1),             # la strada a ovest
    (9, -4), (9, 2), (9, 8),                     # la strada a est
]


def casa(ox: int, oz: int, tinta: str) -> tuple:
    """Una casa 2x2 col suo giardino: 17 celle e 8 bordi.

    L'ordine delle righe conta: `_free_house` restituisce il PRIMO Letto
    libero nell'ordine di inserimento, quindi il villaggio si popola
    nell'ordine in cui scriviamo le case.
    """
    celle = [
        # il pavimento delle quattro celle
        [0, ox, oz, "Pavimento", 0],
        [0, ox + 1, oz, "Pavimento", 0],
        [0, ox, oz + 1, "Pavimento", 0],
        [0, ox + 1, oz + 1, "Pavimento", 0],
        # comodita: due tappeti (contano nel raggio di 3 m dal letto)
        [1, ox + 1, oz, "Tappeto", 0],
        [1, ox, oz + 1, "Tappeto", 0],
        # il letto: e LUI la casa, tutto il resto e contorno che convince
        [2, ox, oz, "Letto", 0],
        [2, ox + 1, oz, "Comodino", 0],
        [2, ox, oz + 1, "Libreria", 1],
        [2, ox + 1, oz + 1, "Camino", 2],
        # la copertura: senza una di queste righe sulla cella del letto la
        # casa non esiste per il gioco, per quanto bella sia
        [3, ox, oz, "Tetto", 0],
        [3, ox + 1, oz, "Tetto", 0],
        [3, ox, oz + 1, "Tetto", 0],
        [3, ox + 1, oz + 1, "Tetto", 0],
        # il giardino: tre pezzi entro 4.5 m
        [2, ox - 1, oz - 1, "Alberello", 0],
        [2, ox - 1, oz + 2, "Cespuglio", 0],
        [2, ox + 2, oz + 2, "Pianta", 0],
    ]
    # i bordi hanno la chiave RADDOPPIATA: la cella (cx,cz) ha nord (2cx,2cz-1),
    # sud (2cx,2cz+1), ovest (2cx-1,2cz), est (2cx+1,2cz)
    bordi = [
        [2 * ox, 2 * oz - 1, "Finestra", False],       # sopra la testata
        [2 * ox + 2, 2 * oz - 1, "Muro", False],
        [2 * ox, 2 * oz + 3, "Porta", True],           # l'uscio, a sud
        [2 * ox + 2, 2 * oz + 3, "Muro", False],
        [2 * ox - 1, 2 * oz, "Muro", False],
        [2 * ox - 1, 2 * oz + 2, "Muro", False],
        [2 * ox + 3, 2 * oz, "Muro", False],
        [2 * ox + 3, 2 * oz + 2, "Muro", False],
    ]
    # la tinta del letto, per riconoscere le case a colpo d'occhio
    varianti = {"0:2:%d:%d" % (ox, oz): tinta} if tinta else {}
    return celle, bordi, varianti


# ------------------------------------------------------------ la piazza

def piazza() -> tuple:
    """Qualche pezzo al centro: non serve alle case, serve a chi prova. Una
    panchina dove sedersi, la lavagna delle promesse, la cassetta della posta
    (le lettere del Gufo), un lampione e un orto da raccogliere."""
    celle = [
        [2, 0, 5, "Panchina", 0],
        [2, 2, 5, "Lavagna", 0],
        [2, -2, 5, "Cassetta posta", 0],
        [2, 3, 6, "Lampione", 0],
        [1, -3, 6, "Orto", 0],
        [1, -3, 7, "Orto", 0],
        [2, 1, 7, "Fontana", 0],
    ]
    return celle, [], {}


# ---------------------------------------------------------- il montaggio

def genera(quante: int, cand_mem: int, giorno: int) -> dict:
    if quante > len(ORIGINI):
        raise SystemExit("ho solo %d posizioni studiate: chiedine al massimo %d"
                         % (len(ORIGINI), len(ORIGINI)))
    catalogo = nomi_catalogo()
    colori = tinte()

    celle, bordi, varianti = [], [], {}
    for i in range(quante):
        ox, oz = ORIGINI[i]
        c, b, v = casa(ox, oz, colori[i % len(colori)])
        celle += c
        bordi += b
        varianti.update(v)
    c, b, v = piazza()
    celle += c
    bordi += b
    varianti.update(v)

    # rete di sicurezza: un nome fuori catalogo viene saltato al caricamento
    # con un solo push_warning che nessuno legge, e al primo salvataggio
    # successivo sparisce per sempre. Meglio accorgersene qui.
    ignoti = sorted(({r[3] for r in celle} | {r[2] for r in bordi}) - catalogo)
    if ignoti:
        raise SystemExit("nomi che il catalogo non conosce: %s" % ", ".join(ignoti))
    fuori = [(r[1], r[2]) for r in celle if nel_fiume(r[1], r[2])]
    if fuori:
        raise SystemExit("celle dentro il fiume (sparirebbero in silenzio): %s" % fuori)

    ordini = ordini_del_gufo()
    dati = {
        "cells": celle,
        "edges": bordi,
        "up_cells": [],
        "up_edges": [],
        "variants": varianti,

        # NESSUN ABITANTE: e tutto qui il «senza abitanti» del titolo
        "residents": [],
        # le visite passate: la leva che rende gli arrivi certi invece che
        # probabili (0.35 a visita, fino a tre)
        "cand_mem": {n: cand_mem for n in nomi_chibi()} if cand_mem > 0 else {},
        "villaggio": {"partiti": {}},

        # il giorno decide la stagione (1-7 primavera, 8-14 estate,
        # 15-21 autunno, 22-28 inverno). L'ora non si salva: si riparte
        # sempre dal mattino.
        "day": giorno,
        "legna": 999,
        "nuts": 99999,
        "stars": 99,
        # i pezzi del negozio scavalcano il recinto del Gufo: senza questa
        # lista restano bloccati anche a campagna finita
        "shop_pieces": pezzi_negozio(),
        "shop_variants": colori,
        "shop_stock": [],
        "shop_stock_day": -1,
        # la campagna del Gufo tutta fatta: recinto dei pezzi spento
        "gufo": {
            "current": len(ordini),
            "veteran": True,
            "arrivals": 0,
            "wish_week": -1,
            "wish_done_week": -1,
            "unlocked": [],
            "done": ordini,
            "announced": ordini,
        },
        "pantry": {"carota": 9, "zucca": 9, "bacca": 9, "fungo": 9,
                   "porcino": 9, "mela": 9, "pera": 9},
    }
    return dati


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", required=True, help="dove scrivere il village.json")
    ap.add_argument("--case", type=int, default=10, help="quante case (max %d)" % len(ORIGINI))
    ap.add_argument("--cand-mem", type=int, default=3,
                    help="visite passate precaricate: 3 = arrivi certi, 0 = comportamento vero")
    ap.add_argument("--giorno", type=int, default=2,
                    help="il giorno del calendario: decide la stagione")
    args = ap.parse_args()

    dati = genera(args.case, args.cand_mem, args.giorno)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(dati, ensure_ascii=False, indent=1), encoding="utf-8")

    letti = sum(1 for r in dati["cells"] if r[3] == "Letto")
    print("scritto %s" % out)
    print("  %d pezzi (%d celle, %d bordi)" % (
        len(dati["cells"]) + len(dati["edges"]), len(dati["cells"]), len(dati["edges"])))
    print("  %d case con letto libero, %d abitanti" % (letti, len(dati["residents"])))
    print("  giorno %d, %d noccioline, %d stelline, %d pezzi di negozio sbloccati" % (
        dati["day"], dati["nuts"], dati["stars"], len(dati["shop_pieces"])))
    print("  cand_mem: %s" % ("3 visite su %d nomi (arrivi certi)" % len(dati["cand_mem"])
                              if dati["cand_mem"] else "vuoto (comportamento vero del gioco)"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
