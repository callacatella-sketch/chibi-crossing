#!/usr/bin/env python3
"""Fa girare una BATTERIA di mutazioni, una per volta, e riporta quante
asserzioni diventano rosse. Ogni mutazione si ripristina subito, e il
ripristino si verifica per impronta."""
import hashlib, json, os, re, subprocess, sys

RADICE = "/Users/duck/Developer/chibi-crossing"
GODOT = os.path.expanduser("~/Downloads/Godot.app/Contents/MacOS/Godot")
CASI = ("test_gesti.gd,test_regia.gd,test_gioia.gd,test_percezione.gd,"
        "test_limbico.gd,test_recita_corpo.gd,test_cuore_vicini.gd,"
        "test_due_strade.gd,test_camminata_visitor.gd,test_villaggio.gd,"
        "test_postura_ritorno.gd,test_deduzioni.gd,test_fonti_uniche.gd,"
        "test_cablaggio.gd,test_scena_cablaggi.gd,test_motori_accesi.gd")


def impronta(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def prova(casi):
    if casi:
        env = dict(os.environ, CHIBI_CASI=casi)
        cmd = [GODOT, "--headless", "--path", RADICE, "--script",
               "res://zz_lente/runner_filtrato.gd"]
    else:
        env = dict(os.environ)
        cmd = [GODOT, "--headless", "--path", RADICE, "--script",
               "res://tests/test_runner.gd"]
    r = subprocess.run(cmd, capture_output=True, text=True, env=env, cwd=RADICE)
    out = r.stdout + r.stderr
    m = re.search(r"TEST: (\d+) passati, (\d+) falliti", out)
    err = out.count("SCRIPT ERROR")
    if not m:
        return {"ok": -1, "ko": -1, "err": err, "rossi": ["(nessun referto)"]}
    return {"ok": int(m.group(1)), "ko": int(m.group(2)), "err": err,
            "rossi": [l.strip() for l in out.splitlines() if "FAIL:" in l]}


def main():
    lista = json.load(open(sys.argv[1]))
    casi = None if (len(sys.argv) > 2 and sys.argv[2] == "intera") else CASI
    solo = sys.argv[3] if len(sys.argv) > 3 else None
    base = prova(casi)
    print("BASE  passati=%d falliti=%d err=%d" % (base["ok"], base["ko"], base["err"]))
    for m in lista:
        if solo and m["id"] != solo:
            continue
        p = os.path.join(RADICE, m["file"])
        testo = open(p, encoding="utf-8").read()
        imp0 = impronta(p)
        n = testo.count(m["da"])
        if n != 1:
            print("%-42s ANCORA NON UNICA (%d)" % (m["id"], n))
            continue
        try:
            open(p, "w", encoding="utf-8").write(testo.replace(m["da"], m["a"]))
            r = prova(casi)
        finally:
            open(p, "w", encoding="utf-8").write(testo)
            assert impronta(p) == imp0, "RIPRISTINO FALLITO " + m["file"]
        stato = "ROSSE %d" % r["ko"] if r["ko"] > 0 else ">>> VERDE <<<"
        print("%-42s %-14s err=%d  (pass %d)" % (m["id"], stato, r["err"], r["ok"]))
        for l in r["rossi"][:4]:
            print("        ", l[:150])
        sys.stdout.flush()


if __name__ == "__main__":
    main()
