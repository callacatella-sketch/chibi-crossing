#!/usr/bin/env python3
"""IL METRO DELLA DIFFERENZA fra due vite del villaggio.

    python3 tools/confronta_tracce.py A.txt B.txt

Le tracce le scrive `tools/prova_identico.gd` (CHIBI_TRACCIA=...).

Una traccia e' una riga per vicino per campione:

    t  etichetta  stato  az=N  x y z  bisogno=valore ...

Il confronto NON e' un diff: un diff dice «diverse» e si ferma. Qui servono
tre numeri diversi, perche' tre cose diverse possono essere andate storte:

 1. **le DECISIONI** (stato del corpo + azione dell'agenda) — se cambiano,
    il vicino ha fatto un'altra cosa, ed e' la definizione stessa di «non
    identico»;
 2. **i POSTI** — due vite possono decidere lo stesso e finire a mezzo metro
    di distanza (un frame di cammino perso);
 3. **i BISOGNI** — scorrono di continuo e sono il rivelatore piu' fine che
    ci sia: un frame saltato si vede sulla quinta cifra.

E il TEMPO DEL PRIMO SCARTO, che dice se le due vite sono partite uguali.
"""
import sys, re


def leggi(p):
    righe = []
    for r in open(p, encoding="utf-8"):
        r = r.rstrip("\n")
        if not r.strip():
            continue
        m = re.match(r"\s*([-\d.]+)\s+(.+?)\s+(\S+)\s+az=\s*(-?\d+)\s+"
                     r"([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+(.*)$", r)
        if not m:
            righe.append(("?", r, "", 0, 0.0, 0.0, 0.0, {}))
            continue
        t, chi, stato, az, x, y, z, bis = m.groups()
        d = {}
        for kv in bis.split():
            k, _, v = kv.partition("=")
            d[k] = float(v)
        righe.append((float(t), chi, stato, int(az), float(x), float(y), float(z), d))
    return righe


def main():
    A, B = leggi(sys.argv[1]), leggi(sys.argv[2])
    n = min(len(A), len(B))
    if len(A) != len(B):
        print("  ⚠️ tracce di lunghezza diversa: %d vs %d righe" % (len(A), len(B)))
    dec = 0        # righe in cui stato o azione differiscono
    st = 0
    az = 0
    dpos_max = 0.0
    dpos_somma = 0.0
    dneed_max = 0.0
    primo = None
    primo_dec = None
    for i in range(n):
        a, b = A[i], B[i]
        if a[1] != b[1]:
            print("  ⚠️ righe disallineate a %d: «%s» vs «%s»" % (i, a[1], b[1]))
            break
        diverso = False
        if a[2] != b[2]:
            st += 1
            diverso = True
        if a[3] != b[3]:
            az += 1
            diverso = True
        if diverso:
            dec += 1
            if primo_dec is None:
                primo_dec = (a[0], a[1], a[2], b[2], a[3], b[3])
        d = ((a[4] - b[4]) ** 2 + (a[6] - b[6]) ** 2) ** 0.5
        dpos_somma += d
        dpos_max = max(dpos_max, d)
        for k in a[7]:
            if k in b[7]:
                dneed_max = max(dneed_max, abs(a[7][k] - b[7][k]))
        if primo is None and (diverso or d > 1e-9 or dneed_max > 1e-9):
            primo = (a[0], a[1])
    print("  righe confrontate      %d" % n)
    print("  decisioni diverse      %d (%.2f%%)  [stato %d · azione %d]"
          % (dec, 100.0 * dec / max(n, 1), st, az))
    print("  scarto di posizione    medio %.4f m · massimo %.3f m"
          % (dpos_somma / max(n, 1), dpos_max))
    print("  scarto sui bisogni     massimo %.6f" % dneed_max)
    print("  primo scarto           %s" % (("t=%.2f  %s" % primo) if primo else "nessuno: TRACCE IDENTICHE"))
    if primo_dec:
        print("  prima decisione div.   t=%.2f %s: stato %s/%s · az %d/%d" % primo_dec)
    # LE ISTOGRAMME, che è il confronto che regge anche quando le due vite
    # divergono: due villaggi che fanno le stesse cose nelle stesse
    # proporzioni sono lo stesso villaggio, anche se non sono sincronizzati.
    for nome, T in (("A", A), ("B", B)):
        h = {}
        for r in T:
            h[r[2]] = h.get(r[2], 0) + 1
        print("  stati %s: %s" % (nome, " ".join(
            "%s=%d" % (k, v) for k, v in sorted(h.items(), key=lambda kv: -kv[1]))))
    for nome, T in (("A", A), ("B", B)):
        h = {}
        for r in T:
            h[r[3]] = h.get(r[3], 0) + 1
        print("  azioni %s: %s" % (nome, " ".join(
            "az%d=%d" % (k, v) for k, v in sorted(h.items()))))


main()
