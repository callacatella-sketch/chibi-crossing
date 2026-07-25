#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Backup automatico su Git — AL PIÙ UNA VOLTA OGNI 24 ORE.
#
# Registrato come hook "Stop" in .claude/settings.json: l'hook parte dopo ogni
# risposta di Claude, MA questo script fa il backup vero (commit + push) solo se
# è passato almeno un giorno dall'ultimo. Le altre volte esce subito senza
# toccare nulla (pochi millisecondi, nessun commit, nessun push, nessun rebase).
#
# Perché a intervallo e non "dopo ogni modifica": lavorando con PIÙ AGENTI in
# parallelo, un commit+push+rebase dopo ogni risposta muove il working tree
# mentre gli altri agenti stanno ancora lavorando/attendendo -> conflitti di
# merge. Un backup una volta al giorno tiene comunque la copia su GitHub
# aggiornata senza disturbare il lavoro concorrente.
#
# Regole di sicurezza (invariate):
#  - non deve MAI bloccare Claude -> esce sempre con codice 0;
#  - non chiede mai credenziali (GIT_TERMINAL_PROMPT=0 / ssh BatchMode): se
#    l'auth non è in cache il push fallisce in fretta e il commit resta locale;
#  - non committa nulla se il working tree è pulito (niente commit vuoti);
#  - rispetta .gitignore (git add -A non tocca i file ignorati);
#  - un solo backup alla volta anche con agenti concorrenti (lock).
#
# Intervallo regolabile con la variabile d'ambiente CHIBI_BACKUP_INTERVAL
# (secondi). Per forzare un backup subito: `rm .git/chibi-last-backup`.
# ---------------------------------------------------------------------------
set -uo pipefail
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10}"

# Intervallo minimo tra due backup, in secondi. 24 ore = 86400.
INTERVAL="${CHIBI_BACKUP_INTERVAL:-86400}"

# Portati alla radice del repository (l'hook parte dalla cwd della sessione).
repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$repo_root" || exit 0

# Il timbro e il lock vivono in .git/ (per-clone, non versionati, non pushati).
git_dir="$(git rev-parse --git-dir 2>/dev/null)" || exit 0
case "$git_dir" in /*) : ;; *) git_dir="$repo_root/$git_dir" ;; esac
stamp="$git_dir/chibi-last-backup"
lock="$git_dir/chibi-backup.lock"

now="$(date +%s)"

# 0 (vero) se un backup è avvenuto da meno di INTERVAL secondi.
_fresh() {
	[ -f "$stamp" ] || return 1
	local last; last="$(cat "$stamp" 2>/dev/null || echo 0)"
	case "$last" in ''|*[!0-9]*) last=0 ;; esac
	[ $(( now - last )) -lt "$INTERVAL" ]
}

# 1) Throttle: se il backup di oggi è già stato fatto, niente da fare.
_fresh && exit 0

# 2) Lock: un solo backup per volta (agenti concorrenti). Un lock rimasto
#    orfano da oltre 10 minuti è stantìo (processo morto): si rimuove.
if [ -d "$lock" ]; then
	lock_mtime="$(stat -f %m "$lock" 2>/dev/null || echo "$now")"
	[ $(( now - lock_mtime )) -gt 600 ] && rmdir "$lock" 2>/dev/null || true
fi
mkdir "$lock" 2>/dev/null || exit 0
trap 'rmdir "$lock" 2>/dev/null || true' EXIT

# 3) Ri-controlla dentro il lock: un altro agente può aver appena fatto backup.
_fresh && exit 0

# 4) Niente da fare se il working tree è pulito.
[ -z "$(git status --porcelain)" ] && exit 0

# Nome del branch corrente (symbolic-ref funziona anche su branch senza commit;
# fallisce solo in detached HEAD).
branch="$(git symbolic-ref -q --short HEAD)" || exit 0

git add -A 2>/dev/null || exit 0
git diff --cached --quiet 2>/dev/null && exit 0

ts="$(date '+%Y-%m-%d %H:%M:%S')"
git commit -q -m "backup automatico: $ts" 2>/dev/null || exit 0

# Il backup è avvenuto (commit locale): timbra SUBITO, così per le prossime 24h
# non si ritenta — anche se il push qui sotto fallisse per rete/auth.
printf '%s\n' "$now" > "$stamp"

# Push. Imposta l'upstream se manca. Errori (offline, branch divergente, auth
# non in cache) non bloccano: il commit resta salvato in locale.
do_push() {
	if git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
		git push -q origin "$branch" 2>&1
	else
		git push -q -u origin "$branch" 2>&1
	fi
}

push_err=""
push_err="$(do_push)" || push_ok=1

# Push rifiutato perché il remoto è avanti: riconcilia con un rebase e riprova
# UNA volta. Qui il working tree è pulito (abbiamo appena committato), quindi il
# rebase è sicuro; se va in conflitto lo si annulla e il commit resta in locale.
if [ "${push_ok:-0}" = "1" ] && git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
	if git pull --rebase -q origin "$branch" 2>/dev/null; then
		push_ok=0
		push_err="$(do_push)" || push_ok=1
	else
		git rebase --abort >/dev/null 2>&1 || true
	fi
fi

if [ "${push_ok:-0}" = "1" ]; then
	msg="Backup: commit salvato in locale ma push su origin fallito (offline, auth o branch divergente). Dettaglio: ${push_err//\"/\'}"
	printf '{"systemMessage": %s, "suppressOutput": true}\n' "\"$(printf '%s' "$msg" | tr '\n' ' ' | cut -c1-300)\""
fi

exit 0
