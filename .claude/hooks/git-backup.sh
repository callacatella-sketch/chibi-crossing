#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Backup automatico su Git.
# Registrato come hook "Stop" in .claude/settings.json: parte DOPO OGNI
# risposta di Claude. Fa commit di tutte le modifiche sul branch corrente e
# le pusha su origin (GitHub), cosi' la copia di backup e' sempre aggiornata.
#
# Regole di sicurezza:
#  - non deve MAI bloccare o rallentare Claude -> esce sempre con codice 0;
#  - non chiede mai credenziali in modo interattivo (GIT_TERMINAL_PROMPT=0):
#    se l'auth non e' in cache il push fallisce in fretta e il commit resta
#    comunque salvato in locale;
#  - non committa nulla se non ci sono modifiche (niente commit vuoti);
#  - rispetta .gitignore (git add -A non tocca i file ignorati).
# ---------------------------------------------------------------------------
set -uo pipefail
export GIT_TERMINAL_PROMPT=0
# SSH sempre non interattivo: niente prompt di passphrase o host key che
# possano bloccare l'hook (fallisce in fretta e il commit resta in locale).
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10}"

# Portati alla radice del repository (l'hook parte dalla cwd della sessione).
repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$repo_root" || exit 0

# Niente da fare se il working tree e' pulito.
[ -z "$(git status --porcelain)" ] && exit 0

# Nome del branch corrente. symbolic-ref fallisce solo in detached HEAD
# (a differenza di rev-parse, funziona anche su un branch senza commit).
branch="$(git symbolic-ref -q --short HEAD)" || exit 0

git add -A 2>/dev/null || exit 0

# Se dopo lo stage non c'e' nulla di staged, esci senza commit.
git diff --cached --quiet 2>/dev/null && exit 0

ts="$(date '+%Y-%m-%d %H:%M:%S')"
git commit -q -m "backup automatico: $ts" 2>/dev/null || exit 0

# Push. Imposta l'upstream se manca. Errori (offline, branch divergente,
# auth non in cache) non bloccano: il commit resta salvato in locale e si
# avvisa l'utente con un systemMessage.
do_push() {
	if git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
		git push -q origin "$branch" 2>&1
	else
		git push -q -u origin "$branch" 2>&1
	fi
}

push_err=""
push_err="$(do_push)" || push_ok=1

# Se il push e' stato rifiutato perche' il branch remoto e' avanti (tipico
# quando la CI di GitHub ha appena committato i binari in bin/), riconcilia con
# un rebase e riprova UNA volta. Qui il working tree e' pulito (abbiamo appena
# committato), quindi il rebase e' sicuro; se va in conflitto lo si annulla e il
# commit resta salvato in locale.
if [ "${push_ok:-0}" = "1" ] && git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
	if git pull --rebase -q origin "$branch" 2>/dev/null; then
		push_ok=0
		push_err="$(do_push)" || push_ok=1
	else
		git rebase --abort >/dev/null 2>&1 || true
	fi
fi

if [ "${push_ok:-0}" = "1" ]; then
	# Push fallito: avvisa senza bloccare (systemMessage non interrompe Claude).
	msg="Backup: commit salvato in locale ma push su origin fallito (offline, auth o branch divergente). Dettaglio: ${push_err//\"/\'}"
	printf '{"systemMessage": %s, "suppressOutput": true}\n' "\"$(printf '%s' "$msg" | tr '\n' ' ' | cut -c1-300)\""
fi

exit 0
