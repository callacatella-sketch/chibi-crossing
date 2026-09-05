#!/usr/bin/env python3
"""IL BANCO DELLE REPLICHE — N semi × K condizioni, e in uscita una
DISTRIBUZIONE invece di un numero.

────────────────────────────────────────────────────────────────────────────
IL DIFETTO CHE QUESTO BANCO ESISTE PER CHIUDERE
────────────────────────────────────────────────────────────────────────────

Due corse di `misura_insieme` con gli stessi identici parametri davano 0,31 e
1,77 righe di co-presenza per residente: un fattore 5,7. Da lì in poi ogni
referto del progetto ha dovuto scrivere «le due corse non sono appaiate», e
una volta uno scarto da 0,80 a 1,27% è stato indicato come «il numero da
confrontare in futuro» — era rumore.

Un numero solo non dice niente. Quello che dice qualcosa è:

  · **il rumore proprio** — la stessa condizione, lo stesso seme, due volte.
    Finché non lo si è misurato, uno scarto non è la prova di niente. È la
    regola scritta in testata a `tools/prova_identico.gd`, e questo banco la
    applica per primo, sempre, prima di ogni altra cosa;
  · **la distribuzione** dentro una condizione — mediana e quartili su N
    semi, mai una media su due corse;
  · **lo scarto APPAIATO** — la condizione A e la B condividono il seme, si
    guarda la distribuzione di (A−B) sui semi, e si conta quanti scarti
    hanno lo stesso segno. È l'unica forma in cui «questo meccanismo pesa
    tanto così» diventa una frase che regge.

────────────────────────────────────────────────────────────────────────────
LE CINQUE REGOLE, e ognuna chiude una trappola già pagata
────────────────────────────────────────────────────────────────────────────

1. ⚠️ **`--fixed-fps 60`, SEMPRE.** Senza, il passo del tempo arriva
   dall'orologio vero: `prova_identico` ne ha misurati **19 valori distinti**
   in una corsa, e due corse identiche divergevano del **37,9%** contro un
   segnale del 25,0%. Il banco era più rumoroso di quello che doveva
   rilevare. (E «--headless forza il passo fisso» è FALSO: quella riga
   di `--help` sta sotto `--write-movie`.)
2. ⚠️ **UN PROCESSO PER REPLICA.** Non è prudenza: `tools/banco.gd::apri()`
   non è rientrante (connette `_tieni_ora` a `process_frame` senza mai
   disconnetterlo, e appende la camera a `tree.root`, che sopravvive al
   cambio di scena), il `Traduttore` della Fase 5 si apre **una volta per
   processo**, e il dado globale del motore sopravvive a `change_scene_to_file`.
3. ⚠️ **UN VILLAGGIO ERMETICO.** Fino al 2026-09-04 ogni banco girava sopra
   il `user://village.json` dell'autore: «stessi parametri» non implicava
   «stesso villaggio». Qui ogni replica riceve `CHIBI_VILLAGGIO` in una
   cartella temporanea, e il salvataggio vero non viene né letto né toccato.
4. **IL BANCO NON INVENTA UN NUMERO.** Legge le righe che il banco misurato
   dichiara: `MISURA <nome> <valore>`. Se non ne trova nessuna lo DICE
   invece di riportare zero — un banco che tace non è un banco a zero.
5. **NIENTE TAGLI SILENZIOSI.** Ogni replica caduta viene contata e
   nominata: una distribuzione calcolata su meno repliche di quelle chieste,
   senza dirlo, si legge come un risultato pulito.

────────────────────────────────────────────────────────────────────────────
COME SI USA
────────────────────────────────────────────────────────────────────────────

    python3 tools/banco_repliche.py tools/misura_insieme.gd \\
        --semi 8 --condizioni "tutto" "insieme" \\
        --env CHIBI_GIORNI=2 CHIBI_QUANTI=13 CHIBI_GAZEBO=1

`--condizioni` prende nomi di leve da spegnere: `tutto` è la condizione di
controllo (niente spento), `insieme` spegne quella leva, `insieme+deriva` ne
spegne due.
"""

import argparse
import functools
import os
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import time

GODOT_CANDIDATI = [
    os.path.expanduser("~/Downloads/Godot.app/Contents/MacOS/Godot"),
    "/Applications/Godot.app/Contents/MacOS/Godot",
    shutil.which("godot") or "",
]

# ⚠️ SI STAMPA SUBITO. Una replica costa minuti; con lo stdout bufferizzato il
# banco resta muto per mezz'ora e chi guarda non sa distinguerlo da un banco
# piantato — e lo ammazza. È la stessa ragione per cui `prova_si_trovano`
# stampa ogni no col suo nome.
print = functools.partial(__builtins__.print if not isinstance(__builtins__, dict)
                          else __builtins__["print"], flush=True)

RIGA_MISURA = re.compile(r"^\s*MISURA\s+([A-Za-z0-9_.:]+)\s+(-?[0-9.eE+]+)\s*$", re.M)


def trova_godot() -> str:
    for c in GODOT_CANDIDATI:
        if c and os.path.exists(c):
            return c
    sys.exit("Godot non trovato: metti l'eseguibile in ~/Downloads/Godot.app")


def una_replica(godot, progetto, script, seme, leve, extra_env, cartella, timeout):
    """Una corsa isolata. Torna (misure, secondi, errore-o-None)."""
    env = dict(os.environ)
    env.update(extra_env)
    env["CHIBI_SEME"] = str(seme)
    env["CHIBI_LEVE"] = ",".join("%s:off" % l for l in leve) if leve else ""
    # il villaggio di QUESTA replica, e di nessun'altra
    env["CHIBI_VILLAGGIO"] = os.path.join(cartella, "villaggio_%d.json" % seme)
    cmd = [godot, "--headless", "--path", progetto,
           "--fixed-fps", "60",              # regola 1: non è opzionale
           "--script", "res://" + script]
    t0 = time.time()
    try:
        p = subprocess.run(cmd, env=env, capture_output=True, text=True,
                           timeout=timeout)
    except subprocess.TimeoutExpired:
        return {}, time.time() - t0, "scaduta dopo %ds" % timeout
    dt = time.time() - t0
    misure = {}
    for nome, val in RIGA_MISURA.findall(p.stdout):
        try:
            misure[nome] = float(val)
        except ValueError:
            pass
    if not misure:
        coda = (p.stdout or p.stderr or "").strip().splitlines()[-3:]
        return {}, dt, "nessuna riga MISURA (coda: %s)" % " / ".join(coda)
    return misure, dt, None


def riassunto(valori):
    v = sorted(valori)
    n = len(v)
    if n == 0:
        return None
    mediana = statistics.median(v)
    q1 = v[n // 4] if n >= 4 else v[0]
    q3 = v[(3 * n) // 4 - (1 if n % 4 == 0 else 0)] if n >= 4 else v[-1]
    return {"n": n, "mediana": mediana, "min": v[0], "max": v[-1],
            "q1": q1, "q3": q3}


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("script", help="il banco da replicare, es. tools/misura_insieme.gd")
    ap.add_argument("--semi", type=int, default=6)
    ap.add_argument("--da", type=int, default=1000, help="il primo seme")
    ap.add_argument("--condizioni", nargs="+", default=["tutto"],
                    help="«tutto», oppure leve da spegnere: «insieme», «insieme+deriva»")
    ap.add_argument("--env", nargs="*", default=[], help="VAR=valore per il banco")
    ap.add_argument("--progetto", default=".")
    ap.add_argument("--timeout", type=int, default=1800)
    ap.add_argument("--salta-controllo", action="store_true",
                    help="⚠️ salta la corsa di controllo: da usare solo se il"
                         " rumore proprio è già stato misurato in questa sessione")
    a = ap.parse_args()

    godot = trova_godot()
    extra = dict(kv.split("=", 1) for kv in a.env if "=" in kv)
    semi = [a.da + i for i in range(a.semi)]
    condizioni = [(c, [] if c == "tutto" else c.split("+")) for c in a.condizioni]
    cartella = tempfile.mkdtemp(prefix="chibi_repliche_")

    print("=" * 74)
    print("BANCO DELLE REPLICHE — %s" % a.script)
    print("  %d semi × %d condizioni = %d repliche · un processo ciascuna"
          % (len(semi), len(condizioni), len(semi) * len(condizioni)))
    print("  condizioni: %s" % ", ".join(c for c, _ in condizioni))
    print("  ambiente:   %s" % (", ".join("%s=%s" % kv for kv in extra.items()) or "—"))
    print("  villaggi:   %s (ermetici, il salvataggio vero non si tocca)" % cartella)
    print("=" * 74)

    caduti = []

    # ── 1. IL CONTROLLO. Va per primo, sempre: uno scarto fra due condizioni
    #       non vuol dire niente finché non si sa quanto ballano due corse
    #       IDENTICHE. Con i dadi nominati deve dare zero esatto.
    if not a.salta_controllo:
        print("\n1. IL CONTROLLO — stesso seme, stessa condizione, DUE volte")
        print("   (se non è zero, tutto quello che segue è sospetto)")
        nome0, leve0 = condizioni[0]
        rumore = []
        for s in semi[:2]:
            m1, t1, e1 = una_replica(godot, a.progetto, a.script, s, leve0, extra, cartella, a.timeout)
            m2, t2, e2 = una_replica(godot, a.progetto, a.script, s, leve0, extra, cartella, a.timeout)
            if e1 or e2:
                print("   seme %-6d CADUTA (%s)" % (s, e1 or e2))
                caduti.append("controllo/%d: %s" % (s, e1 or e2))
                continue
            for k in sorted(set(m1) & set(m2)):
                d = abs(m1[k] - m2[k])
                rumore.append(d)
                segno = "IDENTICO" if d == 0.0 else "⚠️  DIVERSO"
                print("   seme %-6d %-24s %12.6f / %-12.6f  %s"
                      % (s, k, m1[k], m2[k], segno))
        if rumore:
            print("   → il rumore proprio è %.6f (massimo su %d misure)"
                  % (max(rumore), len(rumore)))
            if max(rumore) > 0:
                print("   ⚠️  NON È ZERO: una differenza più piccola di questo"
                      " numero non è un risultato.")

    # ── 2. LE REPLICHE ────────────────────────────────────────────────────
    print("\n2. LE REPLICHE")
    risultati = {}   # condizione -> {misura -> {seme -> valore}}
    for nome, leve in condizioni:
        risultati[nome] = {}
        for s in semi:
            m, dt, err = una_replica(godot, a.progetto, a.script, s, leve, extra, cartella, a.timeout)
            if err:
                print("   %-16s seme %-6d CADUTA — %s" % (nome, s, err))
                caduti.append("%s/%d: %s" % (nome, s, err))
                continue
            print("   %-16s seme %-6d %5.0fs  %s" % (nome, s, dt,
                  "  ".join("%s=%.4f" % kv for kv in sorted(m.items())[:4])))
            for k, v in m.items():
                risultati[nome].setdefault(k, {})[s] = v

    # ── 3. LA DISTRIBUZIONE, mai una media su due corse ───────────────────
    print("\n3. LA DISTRIBUZIONE per condizione")
    misure_tutte = sorted({k for c in risultati.values() for k in c})
    for k in misure_tutte:
        print("\n   · %s" % k)
        for nome, _ in condizioni:
            r = riassunto(list(risultati[nome].get(k, {}).values()))
            if r is None:
                print("     %-16s (nessuna replica)" % nome)
                continue
            print("     %-16s mediana %10.4f   [%.4f – %.4f]   IQR %.4f   n=%d"
                  % (nome, r["mediana"], r["min"], r["max"], r["q3"] - r["q1"], r["n"]))

    # ── 4. LO SCARTO APPAIATO — l'unica forma che regge ───────────────────
    if len(condizioni) >= 2:
        base = condizioni[0][0]
        print("\n4. LO SCARTO APPAIATO (stesso seme, due condizioni)")
        print("   ⚠️ È l'unico confronto che vale: due corse con semi diversi")
        print("      sono due villaggi, e la loro differenza non è del meccanismo.")
        for altra, _ in condizioni[1:]:
            for k in misure_tutte:
                A = risultati[base].get(k, {})
                B = risultati[altra].get(k, {})
                comuni = sorted(set(A) & set(B))
                if not comuni:
                    continue
                d = [A[s] - B[s] for s in comuni]
                concordi = max(sum(1 for x in d if x > 0), sum(1 for x in d if x < 0))
                r = riassunto(d)
                print("\n   %s  «%s» − «%s»" % (k, base, altra))
                for s in comuni:
                    print("     seme %-6d %+12.4f   (%.4f → %.4f)"
                          % (s, A[s] - B[s], A[s], B[s]))
                print("     → mediana %+.4f  [%+.4f – %+.4f]"
                      % (r["mediana"], r["min"], r["max"]))
                print("     → stesso segno in %d casi su %d%s"
                      % (concordi, len(d),
                         "" if concordi == len(d)
                         else "  ⚠️ non tutti: lo scarto non è solido"))

    if caduti:
        print("\n⚠️ REPLICHE CADUTE (%d), e sono nominate perché una"
              " distribuzione su meno repliche di quelle chieste non è" % len(caduti))
        print("   un risultato pulito:")
        for c in caduti:
            print("     · %s" % c)

    shutil.rmtree(cartella, ignore_errors=True)
    print("\n" + "=" * 74)
    return 1 if caduti else 0


if __name__ == "__main__":
    sys.exit(main())
