#!/usr/bin/env bash
# Installa il salvataggio DI PROVA di Chibi Crossing (molte case, nessun
# abitante) al posto di quello vero — dopo averne fatto una copia di sicurezza.
#
#   tools/installa_salvataggio_prova.sh                 installa (10 case)
#   tools/installa_salvataggio_prova.sh --case 4        installa con 4 case
#   tools/installa_salvataggio_prova.sh --vero          arrivi non garantiti
#   tools/installa_salvataggio_prova.sh --pulisci       toglie anche i depositi
#   tools/installa_salvataggio_prova.sh --ripristina    rimette l'ultimo backup
#
# Il salvataggio del giocatore NON viene mai perso: prima di ogni cosa questa
# cartella viene copiata in ChibiCrossing.backup-<data-ora>, e --ripristina
# rimette la piu recente. Le copie non vengono mai cancellate da qui.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# la cartella user:// del gioco. Si puo puntare altrove (CHIBI_USERDIR) per
# provare questo script senza andare a toccare il salvataggio vero.
U="${CHIBI_USERDIR:-$HOME/Library/Application Support/Godot/app_userdata/ChibiCrossing}"
CASE=10
CAND_MEM=3
PULISCI=0
RIPRISTINA=0

while [ $# -gt 0 ]; do
	case "$1" in
		--case) CASE="$2"; shift 2 ;;
		--vero) CAND_MEM=0; shift ;;          # niente leva: qualcuno rifiutera
		--pulisci) PULISCI=1; shift ;;
		--ripristina) RIPRISTINA=1; shift ;;
		-h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"; exit 0 ;;
		*) echo "opzione sconosciuta: $1" >&2; exit 2 ;;
	esac
done

ultimo_backup() {
	ls -d "$U.backup-"* 2>/dev/null | sort | tail -1
}

if [ "$RIPRISTINA" = "1" ]; then
	B="$(ultimo_backup)"
	if [ -z "$B" ]; then
		echo "nessuna copia di sicurezza da rimettere." >&2
		exit 1
	fi
	rm -rf "$U"
	cp -R "$B" "$U"
	echo "ripristinato da $B"
	exit 0
fi

# --- 1. la copia di sicurezza, sempre e comunque -------------------------
if [ -d "$U" ]; then
	B="$U.backup-$(date +%Y%m%d-%H%M%S)"
	cp -R "$U" "$B"
	echo "copia di sicurezza: $B"
else
	mkdir -p "$U"
	echo "cartella creata: $U"
fi

# --- 2. i depositi che appartengono all'altra storia ----------------------
# Niente di tutto questo sta dentro village.json: sopravvive al villaggio
# nuovo e resta appeso a cose che non esistono piu.

# LA TELA DEI SENTIERI si toglie SEMPRE. Non e un ricordo, e la somma dei passi
# di qualcun altro: copre 44x44 metri esatti (Sentieri.AREA) e, se arriva
# satura da un'altra partita, il villaggio di prova nasce su una spianata di
# terra battuta. Si vede solo guardando lo schermo, e sembra un bug del mondo.
rm -f "$U/sentieri_consumati.png"

# LE FOTO E I RICORDI invece sono roba di qualcuno: si tolgono solo se lo chiedi
# (le cornici sopra i letti resterebbero appese a letti che non ci sono piu).
if [ "$PULISCI" = "1" ]; then
	rm -f "$U/foto_ricordi.json"
	rm -rf "$U/foto_ricordi" "$U/ricordi"
	echo "foto e ricordi rimossi (stanno nella copia di sicurezza)"
fi

# --- 3. generare, controllare, installare --------------------------------
MASTER="$REPO/tools/village_prova.json"
python3 "$REPO/tools/genera_salvataggio_prova.py" --out "$MASTER" \
		--case "$CASE" --cand-mem "$CAND_MEM"
echo
python3 "$REPO/tools/verifica_salvataggio_prova.py" "$MASTER"
echo

cp "$MASTER" "$U/village.json"
# il .bak DEVE essere la stessa storia: se village.json fosse illeggibile il
# gioco ripiegherebbe la, e ti ritroveresti un villaggio che non hai scritto tu
cp "$MASTER" "$U/village.json.bak"
echo "installato in $U/village.json"
echo
echo "Adesso: apri il gioco e premi «Continua»."
echo "  ~/Downloads/Godot.app/Contents/MacOS/Godot --path \"$REPO\""
echo "Per tornare al salvataggio di prima: $0 --ripristina"
