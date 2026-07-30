#!/usr/bin/env python3
"""Controlla un salvataggio di Chibi Crossing PRIMA di darlo in pasto al gioco.

    python3 tools/verifica_salvataggio_prova.py <village.json>

Serve perche il caricamento di un salvataggio e pieno di scarti SILENZIOSI:
una riga con un elemento in meno viene saltata senza un messaggio, un nome di
pezzo scritto male produce solo un push_warning che nessuno legge, e una cella
finita nel letto del fiume sparisce senza nemmeno quello. Il risultato non e
un errore: e una casa senza tetto che non risultera mai libera, e mezz'ora
passata a chiedersi perche i vicini non arrivano.

Qui si ricalcolano a mano, sugli stessi numeri del gioco, le otto feature che
il candidato guarda e la soglia che deve superare — cosi «la casa e valida» e
una cosa dimostrata, non sperata.
"""

import json
import math
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def _sorgente(rel: str) -> str:
    return (REPO / rel).read_text(encoding="utf-8")


# ------------------------------------------------ le regole, dal sorgente

def catalogo() -> dict:
    """nome -> (tipo, layer), letto da BuildCatalog.items(). Il layer VERO di
    un pezzo e questo, non quello scritto nella riga del salvataggio."""
    src = _sorgente("scenes/build/BuildCatalog.gd")
    out = {}
    for m in re.finditer(r'\{"name":\s*"([^"]+)"', src):
        coda = src[m.end():m.end() + 320]
        tipo = re.search(r'"type":\s*"(\w+)"', coda)
        layer = re.search(r'"layer":\s*(\d+)', coda)
        if tipo and layer:
            out[m.group(1)] = (tipo.group(1), int(layer.group(1)))
    return out


def _generate() -> str:
    """Il sorgente della SOLA ChibiDNA.generate(): e lei che fa il DNA di chi
    bussa alla porta. In ChibiDNA c'e anche incrocia() (i pesi di chi NASCE,
    media dei genitori): ha una tabella di pesi tutta sua, piu bassa, e
    prenderla per sbaglio fa credere che nessuno accettera mai la casa."""
    src = _sorgente("scenes/npc/ChibiDNA.gd")
    i = src.find("static func generate(")
    if i < 0:
        raise SystemExit("non trovo ChibiDNA.generate(): la fonte e cambiata")
    return src[i:]


def pesi_minimi() -> dict:
    """I pesi base del percettrone, letti da ChibiDNA: `"roof": 1.2 + rng...`
    vuol dire che 1.2 e il minimo che quel peso puo valere."""
    src = _generate()
    blocco = re.search(r'var w := \{\n(.*?)\n\t\}', src, re.S)
    if not blocco:
        raise SystemExit("non trovo i pesi in ChibiDNA: la fonte e cambiata")
    pesi = {}
    for chiave, val in re.findall(r'"(\w+)":\s*(-?[\d.]+)', blocco.group(1)):
        pesi[chiave] = float(val)
    return pesi


def bonus_archetipo_minimo() -> float:
    """Ogni archetipo aggiunge qualcosa ai pesi: il caso peggiore e quello
    che aggiunge di meno."""
    src = _generate()
    blocco = re.search(r'match arche:(.*?)\n\n', src, re.S)
    if not blocco:
        return 0.0
    somme, corrente = [], None
    for riga in blocco.group(1).splitlines():
        if re.match(r'\s*"(\w+)":\s*$', riga):
            if corrente is not None:
                somme.append(corrente)
            corrente = 0.0
        elif corrente is not None:
            m = re.search(r'\+=\s*([\d.]+)', riga)
            if m:
                corrente += float(m.group(1))
    if corrente is not None:
        somme.append(corrente)
    return min(somme) if somme else 0.0


def river_x(z: float) -> float:
    return 18.6 + math.sin(z * 0.061) * 1.35 + math.sin(z * 0.023 + 2.0) * 0.85


def nel_fiume(x: int, z: int) -> bool:
    return abs(x - river_x(z)) < 2.9 and -56 < z < 56


# le tabelle di Visitors._house_features
COMFORT = ["Comodino", "Tappeto", "Lampada", "Libreria", "Sedia", "Tavolino", "Sgabello"]
GIARDINO = ["Aiuola", "Pianta", "Cespuglio", "Fungo", "Alberello"]


def feature_della_casa(cella_letto, celle, bordi) -> dict:
    """Le stesse otto feature che calcola Visitors._house_features, sulle
    stesse distanze. I pezzi stanno a Vector3(x, 0, z) e i bordi a
    Vector3(kx/2, 0, ky/2): a terra la distanza e tutta nel piano."""
    bx, bz = cella_letto
    f = {"roof": 1.0, "walls": 0.0, "door": 0.0, "window": 0.0,
         "comfort": 0.0, "garden": 0.0, "warmth": 0.0, "sunny": 1.0}

    muri = 0
    for kx, ky, nome, _flip in bordi:
        d = math.dist((kx * 0.5, ky * 0.5), (bx, bz))
        if d > 3.4:
            continue
        if nome == "Muro":
            muri += 1
        elif nome == "Finestra":
            muri += 1
            f["window"] = 1.0
        elif nome == "Porta":
            muri += 1
            f["door"] = 1.0
    f["walls"] = min(muri / 4.0, 1.0)

    cat = catalogo()
    comfort = giardino = 0
    for _layer, x, z, nome, _rot in celle:
        vero_layer = cat.get(nome, ("cell", 2))[1]
        if vero_layer not in (1, 2):
            continue
        d = math.dist((x, z), (bx, bz))
        if nome in COMFORT and d < 3.0:
            comfort += 1
        elif nome == "Camino" and d < 3.2:
            f["warmth"] = 1.0
        elif nome in GIARDINO and d < 4.5:
            giardino += 1
    f["comfort"] = min(comfort / 4.0, 1.0)
    f["garden"] = min(giardino / 3.0, 1.0)
    return f


# ------------------------------------------------------------ i controlli

def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    percorso = Path(sys.argv[1])
    guasti, avvisi = [], []

    try:
        dati = json.loads(percorso.read_text(encoding="utf-8"))
    except Exception as e:
        print("GUASTO: il file non e JSON valido (%s)" % e)
        print("        il gioco ripiegherebbe sul .bak: ti ritroveresti un ALTRO villaggio")
        return 1
    if not isinstance(dati, dict):
        print("GUASTO: il salvataggio deve essere un dizionario")
        return 1

    celle = dati.get("cells", [])
    bordi = dati.get("edges", [])
    cat = catalogo()

    # 1. la forma delle righe: una riga di lunghezza sbagliata viene SALTATA
    for i, r in enumerate(celle):
        if not isinstance(r, list) or len(r) != 5:
            guasti.append("cells[%d] non ha 5 elementi: la riga verrebbe saltata" % i)
    for i, r in enumerate(bordi):
        if not isinstance(r, list) or len(r) != 4:
            guasti.append("edges[%d] non ha 4 elementi: la riga verrebbe saltata" % i)
    if guasti:
        for g in guasti:
            print("GUASTO: " + g)
        return 1

    # 2. i nomi: fuori catalogo = pezzo perso, e al primo salvataggio sparisce
    for r in celle:
        if r[3] not in cat:
            guasti.append("nome fuori catalogo in cells: «%s»" % r[3])
    for r in bordi:
        if r[2] not in cat:
            guasti.append("nome fuori catalogo in edges: «%s»" % r[2])

    # 3. doppioni: due pezzi dello stesso layer sulla stessa cella, il secondo
    #    viene scartato (il dizionario dei piazzati e keyed sulla cella)
    visti = {}
    for r in celle:
        chiave = (cat.get(r[3], ("cell", 2))[1], r[1], r[2])
        if chiave in visti:
            guasti.append("due pezzi sullo stesso layer e cella %s: «%s» copre «%s»"
                          % ((r[1], r[2]), visti[chiave], r[3]))
        visti[chiave] = r[3]

    # 4. il fiume: place_cell scarta senza nemmeno un avviso
    for r in celle:
        if nel_fiume(r[1], r[2]):
            guasti.append("cella (%d,%d) e nel letto del fiume: sparirebbe in silenzio"
                          % (r[1], r[2]))

    # 5. le case: un Letto e una casa solo se ha una copertura sulla SUA cella
    letti = [(r[1], r[2]) for r in celle if r[3] == "Letto"]
    coperture = {(r[1], r[2]) for r in celle if cat.get(r[3], ("cell", 2))[1] == 3}
    coperture |= {(r[1], r[2]) for r in dati.get("up_cells", [])
                  if isinstance(r, list) and len(r) == 5
                  and cat.get(r[3], ("cell", 2))[1] in (0, 3)}
    scoperti = [c for c in letti if c not in coperture]
    for c in scoperti:
        guasti.append("il letto in %s non ha copertura: non sara MAI una casa libera" % (c,))

    # 6. le feature: «libera» non basta, la casa deve anche convincere
    pesi = pesi_minimi()
    somma_minima = sum(v for k, v in pesi.items()
                       if k not in ("bias", "welcome")) + bonus_archetipo_minimo()
    visite = min(max(int(v) for v in dati.get("cand_mem", {}).values()) if dati.get("cand_mem") else 0, 3)
    x_peggiore = pesi.get("bias", -6.0) + somma_minima + 0.35 * visite
    p_peggiore = 1.0 / (1.0 + math.exp(-x_peggiore))

    fiacche = []
    for c in letti:
        f = feature_della_casa(c, celle, bordi)
        magre = [k for k, v in f.items() if v < 1.0]
        if magre:
            fiacche.append((c, magre, f))

    # 7. zero abitanti, e nessuna casa marcata come casa del giocatore
    if dati.get("residents"):
        guasti.append("residents non e vuoto: %d abitanti (doveva essere senza)"
                      % len(dati["residents"]))
    if "home" in dati:
        guasti.append("c'e la chiave «home»: quel letto uscirebbe dai candidati")

    # ------------------------------------------------------------- referto
    print("SALVATAGGIO: %s" % percorso)
    print("  pezzi: %d celle + %d bordi = %d" % (len(celle), len(bordi), len(celle) + len(bordi)))
    print("  case (letti con copertura): %d su %d letti" % (len(letti) - len(scoperti), len(letti)))
    print("  abitanti: %d" % len(dati.get("residents", [])))
    print("  giorno %s · noccioline %s · stelline %s · pezzi di negozio %d"
          % (dati.get("day", "?"), dati.get("nuts", "?"), dati.get("stars", "?"),
             len(dati.get("shop_pieces", []))))
    print("  cand_mem: %d nomi a %d visite" % (len(dati.get("cand_mem", {})), visite))
    print()
    print("  LA MENTE DEL CANDIDATO (caso peggiore: il carattere piu difficile)")
    print("    x = %.3f  ->  p = %.3f   (serve p > 0.72, cioe x > 0.945)"
          % (x_peggiore, p_peggiore))
    if p_peggiore > 0.72:
        print("    -> anche il piu difficile ACCETTA: gli arrivi sono certi")
    else:
        print("    -> qualcuno RIFIUTERA (comportamento vero del gioco).")
        print("       Per arrivi certi: --cand-mem 3 al generatore.")

    if fiacche:
        print()
        print("  CASE CHE NON CONVINCONO (feature sotto 1.0):")
        for c, magre, f in fiacche:
            print("    %s manca: %s" % (c, ", ".join("%s=%.2f" % (k, f[k]) for k in magre)))
        avvisi.append("%d case su %d hanno feature sotto 1.0" % (len(fiacche), len(letti)))

    print()
    for g in guasti:
        print("GUASTO: " + g)
    for a in avvisi:
        print("AVVISO: " + a)
    if not guasti and not avvisi:
        print("TUTTO A POSTO: il salvataggio carica intero e ogni casa convince.")
    return 1 if guasti else 0


if __name__ == "__main__":
    sys.exit(main())
