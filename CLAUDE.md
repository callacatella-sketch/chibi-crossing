# Chibi Crossing — istruzioni per gli agenti Claude

Progetto di gioco in **Godot 4.7** con una **GDExtension in C++** (il "cuore"):
le classi native stanno in `src/` (`PlayerController`, `SurvivalComponent`,
`GridManager`, `EcosystemManager`) e vengono registrate da `register_types.cpp`.
Molta logica di gioco è in GDScript sotto `scenes/`. C'è anche l'addon
`addons/lua-gdextension`. La scena principale è `scenes/levels/MainLevel.tscn`.

## REGOLA: backup Git automatico (sempre attivo)

Questo repository deve avere **sempre una copia di backup aggiornata su GitHub**
(`origin`). Il backup è **automatico** e va mantenuto funzionante:

- Un hook **`Stop`** (in `.claude/settings.json`) esegue
  [`.claude/hooks/git-backup.sh`](.claude/hooks/git-backup.sh) dopo ogni risposta
  dell'agente, ma lo script fa il backup vero (commit + push) **al più una volta
  ogni 24 ore**: se l'ultimo backup è recente esce subito senza toccare nulla.
  Quando scatta, fa `git add -A`, committa sul **branch corrente** con messaggio
  `backup automatico: <data ora>` e fa `git push` su `origin`.
- **Perché a intervallo e non dopo ogni modifica:** lavorando con **più agenti in
  parallelo**, un commit+push+rebase dopo ogni risposta muove il working tree
  mentre gli altri agenti stanno ancora lavorando → conflitti di merge. Un backup
  giornaliero tiene comunque la copia su GitHub aggiornata senza disturbare il
  lavoro concorrente.
- Lo script è pensato per non dare mai fastidio: non blocca il lavoro, non
  chiede credenziali (se l'auth non è in cache il push fallisce ma il commit
  resta salvato in locale), non crea commit se non ci sono modifiche, e usa un
  lock (`.git/chibi-backup.lock`) così due agenti non fanno backup insieme.
- Il timbro dell'ultimo backup è in `.git/chibi-last-backup` (per-clone, non
  versionato). Per **forzare un backup subito**: `rm .git/chibi-last-backup`.
  Per cambiare l'intervallo: variabile d'ambiente `CHIBI_BACKUP_INTERVAL` (in
  secondi; default 86400 = 24 ore).

**Cosa devono fare gli agenti futuri:**

1. **Non disattivare** questo hook e non rimuovere lo script: sono il backup.
   Non riportarlo a "commit dopo ogni risposta": la cadenza a 24 ore è voluta
   (evita conflitti di merge tra agenti concorrenti).
2. Va bene fare commit "puliti" a mano durante il lavoro (messaggi descrittivi):
   l'hook interviene solo se restano modifiche non committate, quindi non
   disturba i tuoi commit.
3. Se il push automatico fallisce di continuo, avvisa l'utente: probabilmente
   servono le credenziali GitHub nel portachiavi (`git push` una volta a mano).
4. Il push va sul **branch corrente**. Se stai lavorando su un branch di
   feature, il backup finisce lì; per portarlo su `main` fai un merge/PR.

## Compilare il "cuore" (GDExtension C++)

Serve **SCons** (es. in un virtualenv, oppure `pipx install scons`) e Xcode.
La `godot-cpp` è un submodule (`git submodule update --init --recursive`).

- macOS (universale arm64+x86_64), debug e release:
  ```
  scons platform=macos arch=universal target=template_debug  -j8
  scons platform=macos arch=universal target=template_release -j8
  ```
  Producono `bin/libchibi_crossing.macos.template_{debug,release}.universal.dylib`,
  già referenziati in `chibi_crossing.gdextension`.
- Il `SConstruct` sul ramo non-Windows usa l'environment restituito da
  `godot-cpp/SConstruct` (standard C++17, define, flag di architettura e link
  corretti). **Non spostare** la build macOS sul ramo Windows.
- Dopo aver ricompilato l'estensione, **riavvia l'editor Godot**: le
  GDExtension si caricano solo all'avvio. Sintomo tipico di estensione non
  caricata: schermo grigio con la sola musica (il `PlayerController`, che
  contiene la camera, non viene creato).

## REGOLA: ottimizzazione multipiattaforma (Windows **e** macOS)

Il gioco verrà pubblicato **sia per Windows sia per macOS**: la build release del
cuore C++ va tenuta ottimizzata **su entrambe le piattaforme**, anche quando si
lavora da Mac.

- **Windows** (ramo `win32` del `SConstruct`, setup MSVC manuale): la release
  DEVE usare i flag di ottimizzazione — `/O2 /Oi /Gy`, define `NDEBUG` e link
  `/OPT:REF /OPT:ICF`; la debug usa `/Od /Z7` con link `/DEBUG` (**/Z7 e non
  /Zi**: con la build parallela `-j` i cl.exe si scontrano sul PDB condiviso ->
  errore C1041). Non farli
  regredire (in passato la release veniva compilata senza ottimizzazione, come
  una debug). La build Windows va verificata **compilandola su Windows**: non è
  testabile da Mac.
- **macOS / Linux**: la build eredita l'ambiente di `godot-cpp/SConstruct`, che
  applica già l'ottimizzazione in `target=template_release` (`-O3`). Quindi
  l'ottimizzazione qui è automatica: **non rompere** l'ereditarietà da
  `godot_env` e non spostare la build macOS sul ramo Windows.
- Compilare sempre entrambi i target (`template_debug` e `template_release`) per
  la piattaforma su cui si lavora prima di considerare finito un cambiamento al
  cuore C++.

## Build in cloud (GitHub Actions) — nessun PC Windows necessario

Lo sviluppatore **non possiede un PC Windows**: la `.dll` di Windows si ottiene
in cloud. Il workflow [`.github/workflows/build.yml`](.github/workflows/build.yml)
compila il cuore C++ su **Windows (MSVC reale)** e **macOS (universale)** e
pubblica i binari come **artifact scaricabili** dal run.

- **I binari NON sono versionati** nel repo: `bin/*.dll`, `bin/*.dylib`,
  `bin/*.lib` sono in `.gitignore`. In locale si producono con `scons`
  (macOS/Linux), la `.dll` Windows si scarica dagli artifact di questo workflow,
  e per le release li ricostruisce `release.yml`. **Un clone pulito deve
  ricompilare il cuore prima di aprire Godot** (altrimenti la GDExtension non si
  carica: schermo grigio con la sola musica).
- Si attiva sui push a `main` che toccano `src/**`, `SConstruct`,
  `chibi_crossing.gdextension` o il workflow stesso; oppure a mano da
  *Actions → Run workflow* (`workflow_dispatch`).
- Non serve più compilare Windows a mano. Per verificare le modifiche al
  `SConstruct` (ramo `win32`) basta lasciar girare la CI e guardare il log del
  job *Compila (windows)*, poi scaricare l'artifact `bin-windows` se serve la DLL.
- Nota: l'hook di backup [`git-backup.sh`](.claude/hooks/git-backup.sh) fa
  comunque `pull --rebase` prima del push (rete di sicurezza se il remoto è
  avanti, es. per un push manuale o la release); ora che i binari non vengono
  più committati dalla CI, i conflitti di push sono molto più rari.

## Release firmate/notarizzate (Windows + macOS)

Il workflow [`.github/workflows/release.yml`](.github/workflows/release.yml)
esporta il **gioco completo** (non solo i binari C++), lo firma/notarizza e lo
allega a una **GitHub Release**. Si lancia con un tag (`git tag v1.0.0 && git
push origin v1.0.0`) o a mano da *Actions → Run workflow*.

- Usa l'action `chickensoft-games/setup-godot@v2` per installare Godot +
  export templates; la versione è in `env.GODOT_VERSION` e **deve combaciare**
  con `project.godot` (attualmente **4.7.1**).
- I preset di export sono in [`export_presets.cfg`](export_presets.cfg) ("Windows
  Desktop" e "macOS"). L'export macOS richiede **ETC2 ASTC abilitato** in
  `project.godot` (`rendering/textures/vram_compression/import_etc2_astc=true`):
  senza, l'export universale/x86_64 fallisce. Non rimuovere quel setting.
- **Firma condizionale ai secret:** senza i certificati il gioco esce **non
  firmato** (avviso giallo nel log); appena i secret ci sono, la firma parte da
  sola. Windows usa **Azure Trusted Signing**; macOS usa `codesign` +
  `notarytool` + `stapler` con le entitlement in
  [`misc/macos_entitlements.plist`](misc/macos_entitlements.plist).
- Guida completa ai certificati e all'elenco dei secret:
  [`RELEASE_SIGNING.md`](RELEASE_SIGNING.md). I certificati costano e sono legati
  all'identità dell'utente: **li carica solo lui** come GitHub Secrets, l'agente
  non li vede né li inserisce.
- **Godot in locale** è portabile in `~/Downloads/Godot.app` (4.7.1): utile per
  validare in fretta un export headless
  (`.../Godot.app/Contents/MacOS/Godot --headless --path . --export-release ...`).
  Gli export templates NON sono installati in locale, quindi l'export completo
  gira solo in CI, ma l'import/validazione dei preset si fa anche da qui.

## Test

Test-suite **dependency-free** (nessun addon, nessuna rete) in `tests/`:
`test_runner.gd` (estende `SceneTree`) carica ed esegue tutti i `tests/cases/test_*.gd`
— ognuno espone `func run(t)` e usa gli helper `t.ok/eq/almost`. Copre le classi
C++ (`SurvivalComponent`, `GridManager`, `PlayerController`, `EcosystemManager`)
e la logica pura GDScript (`ChibiDNA`, funzioni matematiche di `CozyWorld`).

- **In locale** (col Godot in `~/Downloads`):
  ```
  Godot --headless --path . --script res://tests/test_runner.gd
  ```
  Esce con codice 0 (tutti passati) o 1 (fallimenti). Il runner **salta** gli
  script con errori di parse senza appendersi.
- **In CI**: [`.github/workflows/tests.yml`](.github/workflows/tests.yml) compila
  il cuore C++ per Linux (i binari non sono versionati) e poi esegue la suite a
  ogni push.
- Convenzioni per nuovi test: file `tests/cases/test_<area>.gd`, `extends
  RefCounted`, niente `add_child` all'albero (le classi C++ si creano con
  `.new()` e si liberano con `.free()`); usa `var x = ...` (non `:=`) quando il
  valore viene da un'istanza non tipizzata, altrimenti l'inferenza fallisce.
