#!/bin/bash
# IL BANCO DELLE MUTAZIONI: guasta UNA riga per volta e conta le
# asserzioni rosse. Una guardia che nessuna mutazione fa arrossire è una
# guardia che non c'è.
#
#   bash tools/muta.sh <prefisso_del_file_dei_casi> <elenco.txt>
#
# L'elenco è a blocchi separati da «=====»; ogni blocco è:
#   nome
#   file
#   testo-da (una o più righe)
#   -->
#   testo-a
#
# ⚠️ IL RIPRISTINO NON PASSA DA `git checkout`. Quello rimette l'ultimo
# COMMIT, non lo stato di partenza — e in un banco di mutazione c'è
# SEMPRE lavoro non committato, perché si sta provando la guardia che si
# è appena scritta. Il 2026-08-30 si è portato via una battuta
# asimmetrica e delle antenne proporzionali già finite.
#
# ⚠️ E LA COPIA DI SICUREZZA STA ACCANTO AL FILE, non in un temporaneo
# che il `trap EXIT` cancella: se la corsa muore fra la mutazione e il
# ripristino (Ctrl-C, Godot che si pianta, la macchina che si riavvia)
# il sorgente resterebbe GUASTO e l'originale non esisterebbe più. Il
# `trap` qui rimette i file PRIMA di uscire, e su INT e TERM.
#
# ⚠️ NON SI LANCIA IN UN ALBERO CONDIVISO con altre sessioni: per tutta
# la corsa i sorgenti sono guasti a intermittenza, e chi legge o compila
# in quel momento vede il guasto.
set -u
FILTRO="${1:-test_fiori}"
ELENCO="${2:-tools/muta_fiori.txt}"
G=~/Downloads/Godot.app/Contents/MacOS/Godot
SUFFISSO=".pre-muta"

ripristina_tutto() {
	local f
	for f in $(find scenes systems shaders tools tests src -name "*${SUFFISSO}" 2>/dev/null); do
		mv -f "$f" "${f%${SUFFISSO}}"
		echo "  (ripristinato ${f%${SUFFISSO}})"
	done
}
trap 'ripristina_tutto; exit 130' INT TERM
trap 'ripristina_tutto' EXIT
ripristina_tutto   # se una corsa precedente è morta a metà

TMP=$(mktemp -d)
python3 - "$ELENCO" "$TMP/m.json" <<'PY'
import sys, json
blocchi = open(sys.argv[1]).read().split("\n=====\n")
out = []
for b in blocchi:
	if not b.strip():
		continue
	nome, file, resto = b.split("\n", 2)
	da, a = resto.split("\n-->\n")
	out.append({"nome": nome, "file": file, "da": da, "a": a.rstrip("\n")})
json.dump(out, open(sys.argv[2], "w"))
PY

# UNA CORSA DI RIFERIMENTO: senza mutazioni il conto deve essere ZERO.
# Senza, «0 rosse» e «la suite non è nemmeno partita» si leggono uguali.
RIF=$($G --headless --path . --script res://tests/test_runner.gd 2>&1)
if ! grep -q "==== TEST" <<< "$RIF"; then
	echo "!! LA CORSA DI RIFERIMENTO NON È ARRIVATA IN FONDO: il banco non vale"
	exit 1
fi
RIF_N=$(grep -c "FAIL:" <<< "$RIF" || true)
echo "riferimento (nessuna mutazione): $RIF_N rosse in tutta la suite"
if [ "$RIF_N" != "0" ]; then
	echo "!! la suite è già rossa: le mutazioni non direbbero niente"
	exit 1
fi

N=$(python3 -c "import json;print(len(json.load(open('$TMP/m.json'))))")
for i in $(seq 0 $((N - 1))); do
	NOME=$(python3 -c "import json;print(json.load(open('$TMP/m.json'))[$i]['nome'])")
	FILE=$(python3 -c "import json;print(json.load(open('$TMP/m.json'))[$i]['file'])")
	cp "$FILE" "${FILE}${SUFFISSO}"
	if ! python3 - "$TMP/m.json" "$i" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))[int(sys.argv[2])]
s = open(m["file"]).read()
n = s.count(m["da"])
if n == 0:
	print("!! NON TROVATO:", m["da"][:70].replace("\n", " "))
	sys.exit(1)
if n > 1:
	# `replace(..., 1)` prenderebbe la prima occorrenza, che potrebbe
	# essere dentro un commento: la mutazione non sarebbe quella scritta
	print("!! AMBIGUO (%d occorrenze):" % n, m["da"][:60].replace("\n", " "))
	sys.exit(1)
open(m["file"], "w").write(s.replace(m["da"], m["a"], 1))
PY
	then
		mv -f "${FILE}${SUFFISSO}" "$FILE"
		printf 'SALTATA    %s\n' "$NOME"
		continue
	fi
	OUT=$($G --headless --path . --script res://tests/test_runner.gd 2>&1)
	mv -f "${FILE}${SUFFISSO}" "$FILE"
	if ! grep -q "==== TEST" <<< "$OUT"; then
		printf 'CORSA MORTA %s (la suite non è arrivata in fondo)\n' "$NOME"
		continue
	fi
	# se la mutazione rompe il PARSE, il runner SALTA il file: «0 rosse»
	# e «guardia muta» si leggerebbero uguali
	if grep -qE "SKIP|Parse Error" <<< "$OUT"; then
		printf 'PARSE ROTTO %s (la mutazione non compila: non dice niente)\n' "$NOME"
		continue
	fi
	QUI=$(grep -c "FAIL: \[$FILTRO" <<< "$OUT" || true)
	TUTTE=$(grep -c "FAIL:" <<< "$OUT" || true)
	printf 'MUTAZIONE  %-56s -> %3d rosse (%3d in tutta la suite)\n' \
			"$NOME" "$QUI" "$TUTTE"
done
rm -rf "$TMP"
