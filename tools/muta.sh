#!/bin/bash
# IL BANCO DELLE MUTAZIONI: guasta UNA riga per volta e conta le
# asserzioni rosse. Una guardia che nessuna mutazione fa arrossire è una
# guardia che non c'è.
#
#   bash tools/muta.sh <file_dei_casi> <elenco.txt>
#
# L'elenco ha, per ogni mutazione, tre righe separate da una riga «---»:
#   nome | file | testo-da | testo-a   (in blocchi, vedi tools/muta_fiori.txt)
#
# ⚠️ IL RIPRISTINO PASSA DA UNA COPIA SU DISCO, MAI DA `git checkout`.
# Con `git checkout -- <file>` si ripristina l'ultimo COMMIT, non lo
# stato di partenza: se nel file c'era lavoro non ancora committato —
# e in un banco di mutazione c'è sempre, perché si sta provando la
# guardia che si è appena scritta — quel lavoro sparisce. È successo il
# 2026-08-30 e si è portato via la battuta asimmetrica e le antenne
# proporzionali, che sono state riscritte a mano.
set -u
FILTRO="${1:-test_fiori}"
ELENCO="${2:-tools/muta_fiori.txt}"
G=~/Downloads/Godot.app/Contents/MacOS/Godot
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

python3 - "$ELENCO" "$TMP" <<'PY'
import sys, os, json
elenco, tmp = sys.argv[1], sys.argv[2]
blocchi = open(elenco).read().split("\n=====\n")
out = []
for b in blocchi:
    if not b.strip():
        continue
    nome, file, resto = b.split("\n", 2)
    da, a = resto.split("\n-->\n")
    out.append({"nome": nome, "file": file, "da": da, "a": a.rstrip("\n")})
json.dump(out, open(os.path.join(tmp, "m.json"), "w"))
PY

N=$(python3 -c "import json,sys; print(len(json.load(open('$TMP/m.json'))))")
for i in $(seq 0 $((N - 1))); do
	NOME=$(python3 -c "import json;print(json.load(open('$TMP/m.json'))[$i]['nome'])")
	FILE=$(python3 -c "import json;print(json.load(open('$TMP/m.json'))[$i]['file'])")
	cp "$FILE" "$TMP/originale"
	if ! python3 - "$TMP/m.json" "$i" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))[int(sys.argv[2])]
s = open(m["file"]).read()
if m["da"] not in s:
	print("!! NON TROVATO nel sorgente:", m["da"][:70].replace("\n", " "))
	sys.exit(1)
open(m["file"], "w").write(s.replace(m["da"], m["a"], 1))
PY
	then
		cp "$TMP/originale" "$FILE"
		echo "SALTATA    $NOME"
		continue
	fi
	R=$($G --headless --path . --script res://tests/test_runner.gd 2>&1 \
			| grep -c "FAIL: \[$FILTRO" || true)
	cp "$TMP/originale" "$FILE"
	printf 'MUTAZIONE  %-58s -> %3d rosse\n' "$NOME" "$R"
done
