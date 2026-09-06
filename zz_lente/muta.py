#!/usr/bin/env python3
"""IL BANCO DELLE MUTAZIONI — una riga di produzione per volta.

Regole pagate dai rapporti precedenti, e qui sono codice:
 1. l'ancora dev'essere UNICA nel file, o il ripristino rimette il codice in
    un punto a caso e si misura un file corrotto;
 2. il ripristino si verifica per IMPRONTA (SHA-256), sempre, anche quando
    la prova va in errore;
 3. si contano gli SCRIPT ERROR: un errore a runtime NON fa fallire un test,
    lo interrompe — e la suite resta verde.

  python3 muta.py <file> <ancora.txt> <sostituto.txt> [casi]
"""
import hashlib, os, re, subprocess, sys

RADICE = "/Users/duck/Developer/chibi-crossing"
GODOT = os.path.expanduser("~/Downloads/Godot.app/Contents/MacOS/Godot")


def impronta(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def prova(casi=None):
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
    errori = out.count("SCRIPT ERROR")
    parse = out.count("non compilabile")
    rossi = [l for l in out.splitlines() if "FAIL:" in l]
    if not m:
        return {"ok": 0, "ko": -1, "err": errori, "parse": parse, "rossi": rossi}
    return {"ok": int(m.group(1)), "ko": int(m.group(2)), "err": errori,
            "parse": parse, "rossi": rossi}


def main():
    f, anc_f, sub_f = sys.argv[1], sys.argv[2], sys.argv[3]
    casi = sys.argv[4] if len(sys.argv) > 4 else None
    p = os.path.join(RADICE, f)
    prima = open(p, encoding="utf-8").read()
    imp0 = impronta(p)
    anc = open(anc_f, encoding="utf-8").read()
    sub = open(sub_f, encoding="utf-8").read()
    n = prima.count(anc)
    if n != 1:
        print("ANCORA NON UNICA (%d occorrenze) — mutazione ANNULLATA" % n)
        sys.exit(2)
    try:
        open(p, "w", encoding="utf-8").write(prima.replace(anc, sub))
        r = prova(casi)
    finally:
        open(p, "w", encoding="utf-8").write(prima)
        assert impronta(p) == imp0, "RIPRISTINO FALLITO su %s" % f
    print("passati=%d falliti=%d SCRIPT_ERROR=%d parse=%d" %
          (r["ok"], r["ko"], r["err"], r["parse"]))
    for l in r["rossi"][:12]:
        print("   ", l)


if __name__ == "__main__":
    main()
