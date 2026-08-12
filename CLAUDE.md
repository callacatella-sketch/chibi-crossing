# Chibi Crossing — istruzioni per gli agenti Claude

Progetto di gioco in **Godot 4.7** con una **GDExtension in C++** (il "cuore"):
le classi native stanno in `src/` (`PlayerController`, `SurvivalComponent`,
`GridManager`, `EcosystemManager`) e vengono registrate da `register_types.cpp`.
Molta logica di gioco è in GDScript sotto `scenes/`. C'è anche l'addon
`addons/lua-gdextension`. La scena principale è `scenes/levels/MainLevel.tscn`.

## REGOLA ZERO: qualità da gioco AAA, sempre — è la regola che precede tutte

**Ogni agente che tocca questo progetto è OBBLIGATO a consegnare qualità da
gioco AAA professionale, degna dell'industria videoludica.** Vale per tutto,
senza eccezioni: creare effetti grafici, visivi e particellari; animazioni;
asset e modelli 3D; shader; suoni; e allo stesso modo modificare, aggiungere
o estendere sistemi, contenuti e implementazioni.

**Prenditi tutto il tempo che serve e consuma tutti i token che vuoi.** Non
esiste un budget da rispettare: esiste solo il risultato. Meglio un lavoro in
meno fatto in modo mozzafiato che tre lavori mediocri. Se una scelta è fra
"veloce" e "bello", si sceglie **bello**; fra "funziona" e "emoziona", si
sceglie **emoziona**.

Il metro non è «compila» né «il test passa»: è **cosa prova chi guarda lo
schermo**. Qualcosa che funziona ma non commuove non è finito.

**Cosa significa in pratica, in questo progetto** (le lezioni già pagate):

1. **Guardare con gli occhi, sempre.** Una suite verde non dice NIENTE sulla
   resa. Prima di considerare finito un lavoro visivo, renderizzalo nel
   MONDO VERO (`change_scene_to_file("res://scenes/levels/MainLevel.tscn")` in
   uno script `--script` temporaneo, camera propria, timer forzati) e GUARDA
   le immagini. Verifica anche **di profilo e di tre quarti**, non solo
   frontale: è lì che si smascherano i trucchi (la bocca "in volo" davanti al
   muso viveva così).
2. **Se non sei sicuro di un valore, fai un PROVINO.** Renderizza cinque
   varianti affiancate ed etichettate, e scegli con l'occhio. Indovinare un
   numero e sperare è il contrario di questo mestiere. (La posa del sonno è
   nata così: a 0.30 rad il chibi sembrava sveglio.)
3. **Mai "posa + adesivo".** La differenza fra vivo e spento è il
   micro-movimento: il respiro, l'assestamento, l'overshoot della molla,
   l'asimmetria (inspiro più corto dell'espiro), gli orologi incommensurabili
   che non si richiudono mai. Un `sin()` puro si smaschera in due cicli.
4. **Conserva il carattere già scritto.** Ogni animazione nuova deve
   rispettare l'età (gobba, orecchie stanche, voce), la pioggia, l'indole,
   la postura. Riscrivere un canale dimenticando `_eta` fa scattare le
   orecchie di un anziano.
5. **Fonti uniche.** Colori, luoghi, tabelle: si leggono da dove già vivono
   (vedi la REGOLA sulle fonti uniche), mai ricopiati.
6. **Test COMPORTAMENTALI, non di facciata.** Un `source-check` che matcha un
   commento resta verde anche cancellando il codice. Entra nello stato vero,
   fai girare `_process`, e guarda il rig. Le tolleranze si tarano sul
   residuo MISURATO, non a occhio.
7. **Fatti smontare il lavoro.** Prima di chiudere una feature importante,
   passala a una revisione avversariale (lenti indipendenti: correttezza,
   integrazione, resa, test). Trova sempre difetti veri che chi ha scritto il
   codice non vede — inclusi quelli che corrompono altri sistemi in silenzio.
8. **Attenzione ai canali orfani.** Se solo uno stato scrive un canale del
   rig, un'interruzione lo lascia fuori posa per sempre: serve una rete di
   sicurezza che giri per OGNI stato.

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

## Commit firmati (SSH)

Dal 2026-07-26 i commit e i tag di questo repository sono **firmati con SSH**:
provano che il codice è dell'autore e non è stato alterato (prova di paternità;
NON impediscono a terzi di usare il codice — a quello serve la
[`LICENSE`](LICENSE) proprietaria).

- Config (già impostata, a livello di repo): `gpg.format=ssh`,
  `user.signingkey=~/.ssh/id_ed25519.pub`, `commit.gpgsign=true`,
  `tag.gpgsign=true`, `gpg.ssh.allowedSignersFile=~/.ssh/allowed_signers`.
- La chiave **non ha passphrase**: la firma automatica non blocca l'hook di
  backup. Se un domani la chiave venisse protetta da passphrase, servirebbe
  `ssh-agent` altrimenti l'hook fallirebbe silenziosamente il commit.
- La chiave pubblica è registrata su GitHub come **Signing Key** (tipo diverso
  da "Authentication"): senza, i commit non mostrano la spunta *Verified*.
- Verifica locale: `git log --show-signature -1` (atteso: `Good "git" signature`).

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
compila il cuore C++ su **Windows (MSVC reale)**, **macOS (universale)** e
**Linux**, e pubblica i binari come **artifact scaricabili** dal run.

> ### ⚠️ REGOLA OBBLIGATORIA — ricompilare il C++ SEMPRE via GitHub, per tutti gli OS
>
> Ogni volta che serve **ricompilare il cuore C++** (`src/`) o le librerie
> native, ogni agente **DEVE**, senza eccezioni:
> 1. **Committare e pushare** le modifiche su GitHub — anche **a mano e subito**
>    (`git add … && git commit && git pull --rebase --autostash origin main &&
>    git push origin main`). Il backup automatico è throttled a 24h: se ti affidi
>    a quello, la CI continua a compilare codice **vecchio**.
> 2. Lasciar **compilare la CI** (`build.yml`) per **TUTTI i sistemi operativi
>    supportati** (Windows, macOS, Linux). Verificare che il run sia verde.
> 3. **Riscaricare** i binari compilati dagli **artifact** del run quando servono
>    in locale (i binari NON sono versionati: vedi `.gitignore`).
>
> **Non considerare finita** una modifica al C++ basandosi solo sulla build
> locale: da Mac non si compila Windows, e una singola build locale non copre
> tutti gli OS. La verità la dà la CI su tutte le piattaforme.

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

## Il mondo: CozyWorld e le sue librerie

`scenes/world/CozyWorld.gd` costruisce il villaggio procedurale. Era un file
unico da oltre 3000 righe; le parti **pure** (senza stato né albero della scena)
sono state estratte in due librerie di funzioni `static`:

- [`scenes/world/WorldMath.gd`](scenes/world/WorldMath.gd) — matematica del
  mondo: `river_x`, `cliff_x` (il corso del fiume e la parete di scogliera, la
  stessa curva che vive in `ground.gdshader`), `catmull`, `tuft_hash/vnoise/field`.
  È anche la **fonte di verità per `FALL_Z`** (CozyWorld ne tiene un alias).
- [`scenes/world/WorldGeo.gd`](scenes/world/WorldGeo.gd) — fabbriche di
  geometria: mesh procedurali (`puff_mesh`, `trunk_mesh`, `skirt_mesh`,
  `blade_mesh`, fiori), primitive, `merge`, materiali `paint_mat`, texture
  `soft_circle`, emettitori `drift_emitter`.

Si usano tramite i `const MATH`/`const GEO` in cima a CozyWorld
(`GEO.cone_mesh(...)`). Nelle librerie i nomi NON hanno l'underscore iniziale.
CozyWorld resta il nodo: mantiene lo stato, `_process`, la generazione differita
in `_ready` (con il segnale `world_built`) e tutta la sua API pubblica.

**Attenzione per chi rifattorizza ancora:** la generazione del mondo NON è
deterministica nel numero di nodi (varia di poche unità tra un avvio e l'altro),
quindi un confronto esatto dell'albero dà falsi allarmi. Usare
[`tests/world_snapshot.gd`](tests/world_snapshot.gd) confrontando
l'**istogramma per classe** (quello sì stabile) e, per le funzioni pure, scrivere
una prova di equivalenza vecchia-vs-nuova implementazione.

## Il Prologo: il tutorial che ha avuto conseguenze

Un villaggio nuovo comincia da [`scenes/prologo/`](scenes/prologo/): tre
minuti sotto un temporale, da cucciola. Ci si ripara sotto una foglia o si
resta sotto l'acqua; ci si avvicina al rigonfiamento nell'erba o si fa un
passo indietro. **Nessuna scelta è annunciata**: niente bivi, niente
prompt, niente evidenziato — perché una scelta annunciata fa rispondere il
personaggio-di-facciata del giocatore invece del giocatore.

Il gioco intanto prende appunti ([`Taccuino.gd`](scenes/prologo/Taccuino.gd),
logica pura) e da quei tre minuti escono **tre conseguenze vere**:

1. i **contatori del Regista** partono inclinati — mai decisi;
2. Mochi si porta dietro un **marchio Limbico** vero sul temporale
   ([`CuoreDiMochi.gd`](scenes/world/CuoreDiMochi.gd)): trasalisce alle
   prime gocce, e mesi dopo lo si spegne con l'estinzione (starci sotto
   senza che succeda niente);
3. la **prima lettera** del Gufo glieli recita.

**Le trappole già pagate** (le tiene chiuse
[`tests/cases/test_prologo.gd`](tests/cases/test_prologo.gd)):

- **Il tetto dei semi va per ASSE, non per contatore.** `Director.ASSI`
  somma più contatori in un asse solo: `bosco 2 + stelle 1` fa tre, e tre
  è la soglia di `profilo()` — il Prologo decideva il carattere prima che
  il giocatore entrasse nel villaggio. Gli assi si leggono da `Director`,
  mai ricopiati.
- **I semi devono ASPETTARE il Regista.** Nasce figlio runtime di
  CozyWorld (mondo costruito su più frame): al risveglio di
  `CuoreDiMochi` il gruppo `regista` è vuoto, e consegnare lì per lì
  buttava i semi nel niente in silenzio — marchio e lettera arrivavano, i
  contatori restavano a zero.
- **Il marchio del temporale non sbiadisce da solo.** Lo sbiadimento
  normale dei marchi (0.12 al giorno) lo cancellava in una settimana:
  `Limbico.passa_giorno(riposato, sbiadisci_marchi)` con `false` è per lui
  e per nessun altro (le paure dei vicini devono continuare a consumarsi).
- **Le misure sono secondi, le soglie sono frazioni.** Confrontarle
  direttamente dichiarava «si è riparata» a chi era passata sotto la
  foglia un secondo e mezzo — e la lettera raccontava una notte mai
  successa.
- **Nel villaggio non c'è MAI un temporale** (regola di `Weather.gd`): il
  Prologo è l'unico, ed è per questo che marchia. Nel villaggio è la
  PIOGGIA a ricordarglielo.

## Il menù principale è vivo (e sente)

Il titolo ([`scenes/ui/TitleScreen.gd`](scenes/ui/TitleScreen.gd)) non è una
cartolina: legge `village.json` — senza caricare la partita, bastano poche
righe ([`RiassuntoSalvataggio.gd`](scenes/ui/RiassuntoSalvataggio.gd)) — e
mostra il villaggio VERO. Il Grande Albero alla taglia raggiunta, i vicini
veri che nel diorama FANNO qualcosa
([`AttoreTitolo.gd`](scenes/ui/AttoreTitolo.gd): si rincorrono, dondolano
sull'altalena, dormono, annusano un fiore, salutano te), e un **CLIMA**
emotivo — `attesa · serena · allegria · armonia · malinconia · commiato ·
lutto` — che comanda cielo, luce, saturazione, petali, fiori, posa e faccia
di Mochi, e perfino quanto in fretta respira la camera.

**E non si ripete mai.** Tre leve, nessuna delle quali produce contenuto
nuovo da disegnare (guardia:
[`tests/cases/test_menu_imprevedibile.gd`](tests/cases/test_menu_imprevedibile.gd)):

1. **L'ORA VERA di chi gioca** ([`OraDelGiorno.gd`](scenes/ui/OraDelGiorno.gd)):
   sei momenti (notte · alba · mattina · pomeriggio · tramonto · sera). Chi
   apre a mezzanotte trova il prato blu con le lucciole; alle sette,
   un'alba rosa. Il clima ci si posa SOPRA come modificatore — sei per
   sette fanno quarantadue mattine, nessuna disegnata a mano. Per i
   provini: `CHIBI_ORA=23`.
2. **I mestieri SCADONO** e la regia ne assegna altri
   ([`RegiaDiorama.gd`](scenes/ui/RegiaDiorama.gd)): chi resta un minuto
   sul menù vede finire una rincorsa, uno che si sveglia, uno che va
   all'altalena. Mai due volte di fila lo stesso mestiere.
3. **Le SCENETTE a due**, rare apposta: incontro · fiore · risata ·
   consolazione · girotondo. Quello che le rende speciali è non averle
   mai viste, e questo menù si apre centinaia di volte. Più gli OSPITI:
   una farfalla che passa di giorno (e tutti la seguono con gli occhi),
   una stella cadente di notte.

La semina viene dal tempo vero: chi fa cosa, e dove, cambia a ogni
apertura. **L'albero no** — quello ha semina fissa: è *il* tuo albero, non
deve rifarsi la chioma ogni volta.

**Le regole che lo tengono in piedi** (guardia:
[`tests/cases/test_menu_vivo.gd`](tests/cases/test_menu_vivo.gd)):

- **Il lutto sta sopra tutto.** Un villaggio pieno di amici che ha perso
  qualcuno ieri deve avere il menù grigio: se la statistica dell'allegria
  coprisse il lutto sarebbe la cosa più fredda che il gioco possa fare.
  Passati i giorni, il menù torna a colori — non dimentica, ricomincia a
  respirare.
- **Il lutto si dice TOGLIENDO, non spegnendo.** Si abbassa la
  *saturazione*, non la luce (un menù al buio è rotto, non triste), e i
  mestieri allegri spariscono: nel lutto nessuno si rincorre, non parte
  nessuna scenetta tranne la consolazione, e non passa nessun ospite.
  Vale **a qualunque ora**: se all'alba (che è rosa e allegra) il lutto
  non riuscisse a scolorire, chi apre il gioco la mattina dopo una
  perdita si vedrebbe accogliere da una cartolina.
- **Il menù non si rompe MAI.** È l'unica schermata da cui si può ancora
  rimediare a un salvataggio andato storto: `da_salvataggio()` accetta
  qualunque schifezza e torna comunque un villaggio al giorno uno.
- **Fonti uniche.** L'albero è quello del villaggio
  ([`AlberoGeo.gd`](scenes/world/AlberoGeo.gd), estratto da GrandTree) e
  l'andatura è quella dei vicini ([`Andatura.gd`](scenes/npc/Andatura.gd),
  estratta da Visitor): camminano identici nel menù e nel gioco perché c'è
  UNA implementazione. Mai ricopiarne le formule.
- **Attenzione al `:=` sul riassunto.** `_save` non è tipizzato:
  `var x := _save.qualcosa()` non compila (vedi la convenzione dei test).
- **Mochi guarda a −Z, i chibi di ChibiBuilder a +Z.** Girarla come loro
  la lascia di spalle — ed è la protagonista del menù.

## REGOLA: le fonti uniche di verità (una tabella, un posto)

Tre dati del gioco vivevano duplicati in più file e avevano **già cominciato a
divergere in silenzio**. Ora ognuno ha UNA casa. Non reintrodurre copie: un test
in [`tests/cases/test_fonti_uniche.gd`](tests/cases/test_fonti_uniche.gd) fa la
guardia.

- **Le specie** (farfalle, lucciole, pesci, bestiole, raccolti) →
  [`scenes/world/Critters.gd`](scenes/world/Critters.gd), `const SPECIE`: una
  riga per specie con `nome/articolo/classe/colore/vendita/rara`. Prima le
  tabelle stavano in `Economy` (negozio), `Collection` (barattoli) **e**
  `CozyWorld` (chi vola): la stessa farfalla era "Farfalla dorata" sul bancone e
  "una farfalla gialla" in vetrina, con due rosa diversi.
  Le specie **stagionali** dichiarano QUANDO esistono col campo facoltativo
  `cond` (`stagioni`/`ora`/`meteo`) più `peso/max/luogo/indizio`: la verità la
  dice SOLO `Critters.disponibile(id, ctx)` col contesto costruito da
  `CozyWorld.contesto_critter()` — nessun altro file deve chiedersi "è
  inverno?" a mano. Logica pura, testata headless in
  [`tests/cases/test_critters_stagioni.gd`](tests/cases/test_critters_stagioni.gd)
  (lo stagno non deve MAI restare senza pesci).
  I due registri del nome si **derivano** da un unico nome minuscolo:
  `etichetta()` → "Farfalla dorata" (titolo), `con_articolo()` → "una farfalla
  dorata" (dentro una frase). Il pallino del negozio è
  `colore_pallino()` = il colore della creatura più saturo: una trasformazione
  di presentazione, **non** un secondo colore da mantenere a mano.
- **La scala della ribellione** → `const SCALA` in
  [`scenes/npc/Animo.gd`](scenes/npc/Animo.gd), sola definizione. Si interroga
  **per nome** con `ANIMO.indice(g)` / `ANIMO.almeno(gradino, "diserzione")` /
  `ANIMO.frazione(gradino)`. Mai indici a mano: `GRADINO_CONFRONTO := 5` e un
  `.find()` su una lista ricopiata puntavano al gradino sbagliato appena si
  inseriva un gradino in mezzo — senza un errore. Le tabelle parallele
  (`SOGLIA`, `TELEGRAFO`, `Lavori.STATO_UMANO`) sono indicizzate per nome e il
  test verifica che coprano **tutti** i gradini.
- **Salvare il villaggio** → si chiede con l'**API pubblica** del BuildSystem:
  `request_save()` (idempotente nel frame: N richieste = UNA scrittura, a fine
  frame) oppure `save_now()` se si sta uscendo (pausa → titolo, quit, CLI), dove
  un differito non verrebbe mai eseguito. **Non** chiamare `_save_village()` da
  fuori: era chiamato da 16 file e ogni singola nocciolina riscriveva il file
  INTERO due volte. Un test in
  [`tests/cases/test_cablaggio.gd`](tests/cases/test_cablaggio.gd) tiene chiusa
  la porta.
- **La calma del giocatore** (quanta paura fai al prato adesso) →
  [`scenes/world/FiatoSospeso.gd`](scenes/world/FiatoSospeso.gd), `calma()`:
  pura, testata, pubblicata ogni frame al gruppo **`calma_listener`**. La
  moltiplicano TUTTE le paure del mondo — farfalle e rane (`CozyWorld`),
  lucciole (`Collection`), e per il ponte `Ecosystem.set_calma()` anche le
  farfalle del MultiMesh e i passerotti del C++. Erano tre formule scritte a
  mano in tre file, ognuna col suo pavimento che non si spegneva mai: a
  giocatore immobile la farfalla si scostava lo stesso, e «il prato smette di
  avere paura di te» non poteva avverarsi. **Non ritoccare le tre costanti:
  si tara `calma()`.**
- **Il vento del momento** (quanto tira adesso) →
  [`scenes/world/Weather.gd`](scenes/world/Weather.gd), `vento()`. Lo stesso
  numero che il cielo manda agli shader (il globale `vento_forza`) lo
  leggono di lì le corde vive e il rimbalzello. **Un globale di shader si
  SCRIVE e basta: non lo si riprende dal server di rendering.**
  `RenderingServer.global_shader_parameter_get()` è una lettura da EDITOR, e
  a runtime Godot la rifiuta con un errore per FOTOGRAMMA («This function
  should never be used outside the editor») — senza restituire il valore.
  `CordeVive` la chiamava a ogni `_process` e si riprendeva sempre **1.0**,
  la brezza del sereno, mentre il cielo era a 1.775: sotto l'acquazzone ogni
  corda del villaggio ha continuato a dondolare come in una giornata serena.
  E la suite era verde, perché i test passano dalla leva `vento_forzato` e
  quel ramo non lo attraversavano mai — la stessa forma del difetto del
  Filo Rosso (codice morto in partita, test contenti).
  Misurato nel MainLevel vero con
  [`tools/misura_fps.gd`](tools/misura_fps.gd): la chiamata torna
  **`<null>`** anche col cielo a 1.786, costa **283 µs** cronometrata sulla
  riga, e il suo errore-per-fotogramma (1710 righe in quattro minuti di
  gioco; 242 in un provino da due) è ora **zero in tutto il log**.
  **Il grosso dei fotogrammi persi però NON era suo**: 283 µs non fanno
  crollare un fotogramma, e la fama di «funzione che distrugge le
  prestazioni» ha quasi fatto chiudere il caso sul colpevole sbagliato. Chi
  torna a misurare qui: vedi la sezione sulle prestazioni in fondo, e
  soprattutto **guarda il carico della macchina** prima di attribuire un
  numero al codice. La guardia sta in
  [`test_vento.gd`](tests/cases/test_vento.gd) e scandaglia TUTTI i
  sorgenti di `scenes/` e `systems/` — saltando i commenti, perché questa
  lezione la chiamata vietata la nomina apposta.

## REGOLA: gli affetti fra vicini, e il libero arbitrio

Due vicini si affezionano, mettono su famiglia, e possono lasciarsi. Il
sistema vive in [`scenes/npc/Affetti.gd`](scenes/npc/Affetti.gd) e in
`Animo.REAZIONI`, e ha cinque regole che NON si negoziano — vengono da una
revisione avversariale che ha smontato tre progetti prima che ne scrivessi
uno.

1. **Ogni ferita ha una chiave a forma di GIOCATORE.** `MOMENTI_CHIAVE` dice
   quanti momenti del Filo Rosso servono per richiudere ogni risposta.
   Nessuno stato permanente la cui unica chiave sia in mano a un altro NPC:
   è la stessa regola per cui esiste `Visitors._filtra_luogo`.
2. **Niente classifica visibile.** Il posto al falò ordinato per affetto *è*
   la classifica resa leggibile, e questo gioco non prende posizione su
   quanto vale una persona rispetto a un'altra. Il telegrafo è il CORPO
   (`spalle_basse`, `distratto`), mai un numero.
3. **Niente penale per stare in coppia.** Il mondo non garantisce gli
   incontri (`_chats` fa UNA chiacchierata per volta in tutto il villaggio):
   una tassa giornaliera per non essersi visti sarebbe una macchina del
   divorzio. **La rottura non è un evento: è il predicato `coppia()` che
   smette di essere vero**, e per smettere servono gesti veri altrove —
   la stessa moneta con cui la coppia si era formata.
4. **Il bambino non è uno strumento.** Non si congela mai la sua crescita
   (`GIORNI_ADULTO := 14`): un bambino tenuto piccolo dalla separazione dei
   genitori è ricatto emotivo. E `_tick_partenze` ora controlla
   `e_cucciolo`: un piccolo non fa il fagotto da solo.
5. **Il gioco non dice chi ha sbagliato.** Nel libro mastro non esiste una
   riga «tradimento»: esistono solo gesti, e la stessa colonna letta da due
   persone diverse dà due numeri diversi.

**Come si legge il libro mastro** (`conto()`, pura): chi è LEALE ha un
passato che non sbiadisce (mezza vita del ricordo da 36 a 72 giorni) — ed è
questo, non un'eccezione scritta apposta, a rendere certe coppie
inespugnabili. ESSERE CERCATI conta quasi il doppio che cercare. E una
chiacchiera vale un ventesimo di un atto di coraggio: senza quella
proporzione il sistema sposerebbe i due che lavorano accanto.

**La coppia non è un campo:** `coppia()` è un predicato derivato (minimo
reciproco + soglia + gesti veri). Niente da tenere sincronizzato, niente
che resti appeso a metà, nessun salvataggio da migrare.

**Trappole già pagate (tutte MISURATE da una revisione avversariale, non
immaginate):**
- **Le REAZIONI valevano zero.** `punteggio()` ha due termini vivi per i
  mestieri (il sollievo sui drive E il tiro del sogno); per le reazioni ne
  viveva uno solo, moltiplicato per `malessere()` — che `passa_giorno()`
  porta a zero. Per un vicino che sta bene, cioè NEL CASO COMUNE, i sette
  punteggi valevano esattamente `0.000000`: il softmax su tre pareggi dava
  un **dado uniforme sulle prime tre chiavi nell'ordine in cui la tabella è
  scritta**, identico per un orgoglioso e per un codardo. Serviva un termine
  che NON passasse dal malessere: `AMPIEZZA_TRATTO`, il tiro del carattere.
  Misurato dopo: sette risposte fra il 10 e il 19% su 400 caratteri veri, e
  lo stesso carattere che in 30 rotture ne dà tre diverse nel 98% dei casi.
- **Nessuna coppia poteva formarsi, MAI.** Dei tredici tipi di gesto il
  gioco ne emetteva TRE, tutti sotto `PESO_VERO`: `coppia()` era falsa per
  costruzione e tutto il sistema era codice morto in partita — con la suite
  verde su un villaggio che non esiste. Ora i gesti pesanti arrivano dal
  LAVORO che il giocatore assegna (chi fa la guardia veglia su chi dorme,
  chi cucina divide quello che ha) e dalle nascite.
- **Il tempo rompeva le coppie.** `coppia()` chiede il valore assoluto sopra
  soglia e il conto decade: una coppia nata sul filo si scioglieva in
  quattro giorni di niente — sedici minuti reali. Il decadimento ERA il tick
  giornaliero che la regola 3 vieta. Ora `ancora_coppia()` è l'isteresi:
  formarsi costa, restare no.
- **Il cucciolo spariva al ricaricamento.** Dargli la cella della madre per
  farli uscire dalla stessa porta lo cancellava: `load_extra` scarta le
  righe la cui cella è già presa, e la madre è sempre prima nell'array. La
  convivenza per CELLA è sbagliata — la cella è la chiave di unicità del
  letto. **Un bambino cancellato dal salvataggio è la cosa peggiore che
  questo sistema potesse fare**, ed era una regressione mia.
- **`_rng.state` non sopravviveva al JSON:** salvato come intero perdeva
  undici bit. Si salva come stringa.
- `Animo.punteggio()` era CIECO ai tratti: i pesi di carattere vivevano in
  `disagio()` e non venivano mai chiamati, quindi due vicini con gli stessi
  bisogni ricevevano punteggi identici. Finché era così, «libero arbitrio»
  non poteva essere altro che un dado. Ora `peso_drive()` è fonte unica.
- `decide()` usava il softmax a 1.6 per tutto: una moneta appena sbilanciata
  (62/38 con 0.3 di scarto). Va bene per «che mestiere faccio oggi», non per
  «me ne vado dal villaggio»: la nitidezza è un parametro per decisione, e
  le scelte di vita usano `NITIDEZZA_VITA`.
- `Animo.save()` non serializzava `_rng`: due save-scumming e il giocatore
  scopriva il dado. Ora lo stato del dado sopravvive.
- `senti_dire()` resisteva alle voci solo se erano sul GIOCATORE: una voce
  su una persona attecchiva più di una sul re del villaggio. È la via più
  corta perché una storia triste diventi una gogna.

## REGOLA: il tween che muove il CORPO è di chi l'ha acceso

Un `Tween` è legato al **nodo**, non allo stato che l'ha creato: continua a
scrivere `position` anche dopo che quello stato è finito. In `Visitor.gd`
questo è costato per anni, in silenzio, la cosa più brutta che si vedesse
muoversi nel villaggio — e nessuno l'aveva mai misurata.

**Cosa succedeva davvero** (misurato in 45 s di MainLevel vero con
[`tools/prova_seduta_troncata.gd`](tools/prova_seduta_troncata.gd)):

- il montaggio sulla panchina copriva quasi **un metro in 0,4 s** con
  TRANS_BACK/EASE_OUT, cioè partendo alla massima velocità: **8,9 m/s**
  misurati, col ciclo del passo a **blend 1,00**. E sopra i 2,8 m/s
  (`Andatura.VELOCITA_ASSURDA`) l'andatura legge un teletrasporto e SMETTE
  di far girare la fase: le zampe si congelavano a mezz'aria mentre il
  corpo traslava. Nel provino a fotogrammi, la seduta durava **un frame**;
- e se qualcuno cambiava stato in quei 0,4 s — la routine, una
  chiacchierata, il Salone, un piano del Regista — il tween continuava a
  scrivere `position` **mentre il corpo camminava da un'altra parte**, e
  l'ultimo a scrivere `position.y` restava lui: **928 frame su 2704 con un
  vicino che cammina a 52 cm dall'erba**. Un sesto del tempo.

**La cura, e la regola per chi verrà** (guardia:
[`tests/cases/test_seduta_corpo.gd`](tests/cases/test_seduta_corpo.gd)):

1. **Un solo tween per il corpo, e porta il nome del suo padrone.** Si crea
   con `_corpo_muovi()`, che registra `_state` in `_corpo_tw_padrone`.
   `_enter_state` e `_walk_to` lo spengono; `_corpo_rete()` in `_process` lo
   spegne comunque, ogni frame, per gli stati che si assegnano a mano
   (`dismount`, `r_pasto`, `hidden`). **Mai** `create_tween()` crudo su
   `position`: il test lo cerca nel sorgente e fa la guardia.
2. **L'ALTEZZA del corpo è il canale più orfano che ci sia.** `STATI_SOLLEVATI`
   elenca chi ha diritto di stare su; per tutti gli altri la rete rimette i
   piedi a terra. È la stessa regola di `Andatura.rilassa`, applicata al
   canale che nessuno guardava.
3. **Ma «seduto» non è deducibile dallo stato:** chi riceve un piatto in
   panchina passa a `r_pasto`, che non è uno stato sollevato, ed è ancora
   sul legno. Per questo esiste `_su_un_sedile` — lo accende `_siediti`, lo
   spengono `_alzati`, `_walk_to` e ogni `_enter_state`.
4. **Un tween che muove il corpo deve avere una velocità VERA.** Sedersi è
   `_siediti`: l'ultimo tratto si copre a 1,15 m/s (poco meno del passo, ci
   si avvicina rallentando) e la salita sul sedile parte MENTRE si arriva —
   due tempi sovrapposti, non un teletrasporto. Il tempo della salita cresce
   come la **radice** dell'altezza, che è il tempo di un salto vero (il
   passerotto sul trespolo a 86 cm ci mette più della panchina a 52).
5. **Il plop aspetta l'atterraggio.** L'assestamento vive in
   `assesto_seduta`, e `_sit_attesa` lo tiene fermo finché il corpo non
   tocca il legno: un tonfo mentre si è per aria è una bugia come un'altra.
6. **Scendere è un movimento.** Lo stato `dismount` aveva `pass`: il rig
   restava inchiodato all'ultima posa da seduto mentre il corpo scivolava a
   terra — un fermo immagine che trasla.

**E una trappola di MISURA, non di codice.** L'ordine del frame in Godot è
`process_frame` → `_process` dei nodi → **tween**. Una sonda dentro
`_process` cade in mezzo, e la differenza fra due suoi campioni somma due
spostamenti che il giocatore non ha mai visto insieme: 3,2 m/s di picco
puramente inventato, che per mezz'ora ho preso per un residuo del guasto.
Ci si aggancia a `process_frame`, che vede il corpo com'è stato disegnato.

Dopo: **1,81 m/s di massimo, zero scivoli, zero frame di levitazione**.
Si guarda con [`tools/provino_seduta.gd`](tools/provino_seduta.gd), che
fotografa salita e discesa **di profilo** a intervalli fissi — il movimento
non si giudica in una posa, si giudica in una pellicola.

## REGOLA: i sogni — sognare è ciò che salva un ricordo

Nel proprio letto, «E — vai a dormire»: lo schermo si chiude e **prima del
mattino arriva un sogno**, in [`scenes/interact/Sogni.gd`](scenes/interact/Sogni.gd).
Non è un riepilogo: è una scena breve e **muta**, sette secondi di lanterna
sopra un ricordo. Ogni tanto è un vicino che è **partito**, che fa una cosa
che facevate insieme.

**La meccanica sotto la scena, che è la ragione per cui questo sistema
esiste.** `Legami` ha una potatura gentile: oltre `MAX_MOMENTI` il filo
comincia a lasciar andare, e `indice_da_potare()` sa quale ricordo
sacrificherebbe per primo. **Il sogno va a prendere proprio quello**, e al
risveglio `Legami.segna_sognato()` lo rende intoccabile. Su una partita
lunga, i momenti che sopravvivono sono quelli che hai sognato — e nessuno
te lo dice mai. Chi è partito pesa quattro volte tanto nella scelta: il suo
filo può solo accorciarsi.

**Le regole della messa in scena.** «Se il sogno diventa una schermata con
i numeri della giornata, è morto» — e non basta togliere i numeri, perché un
riepilogo può essere muto e restare un referto:

1. **Niente parole, mai.** Nessun nome, nessuna data, nessuna icona. Chi è
   si riconosce dal corpo.
2. **Niente prop-pittogramma.** Una stellina per «desiderio», una busta per
   «risposta» non sono oggetti di scena: sono icone di UI in 3D. Un oggetto
   entra solo se il giocatore l'ha tenuto in zampa da sveglio.
3. **I gesti non si compiono.** Un gesto interrotto è strutturalmente
   incapace di informare.
4. **Niente segno al risveglio.** Niente filo dorato verso il Prato Eterno
   (waypoint), niente fiore acceso (marcatore su una tomba), niente riga in
   grassetto nella pagina del filo. L'unica conseguenza è invisibile.
5. **Il sogno SBAGLIA.** Un ricordo riprodotto senza errori è un *replay*,
   cioè la forma emotiva del riepilogo. `dna_sognato()` mette **una** cosa
   fuori posto — mai due, e mai tanto da rendere irriconoscibile chi hai
   sognato: schiarire il pelo verso il bianco spegneva l'unico canale che
   dice CHI era.
6. **Quattro grammatiche, non venti scene.** Il corpo conosce quattro modi
   di stare con qualcuno: `accanto`, `porgere`, `cercarsi`, `contatto`.

**Le trappole del motore, tutte pagate:**

- **`DayNight._apply()` gira ogni frame** e riscrive sole, ambiente, nebbia,
  glow e saturazione: abbassare le luci non spegne il mondo. Si **sostituisce
  la risorsa** sul `WorldEnvironment` (DayNight continua a scrivere su quella
  vera, a vuoto) e si usa `_sun.visible = false`, che `_apply()` non tocca.
- **Il rig guarda −Z** ([ChibiBuilder.gd:11](scenes/npc/ChibiBuilder.gd:11)).
  `Congedo._eco_presenza` aveva `atan2(dir.x, dir.z)` con un commento che
  giurava il contrario: **il fantasma del congedo dava le spalle a Mochi da
  sempre**. Due secondi fra le lucine non lo mostrano; un sogno in primo
  piano sì.
- **`Legami.mostra_filo()` è un no-op per chi è partito** (cicla su
  `Visitors._residents`, da cui i partiti sono stati tolti). Il sogno
  perciò NON mostra il filo: sarebbe un segno, e la regola 4 lo vieta.
  (Una prima stesura di questa nota diceva che il filo «si annoda a mano»
  dentro il sogno: non era vero, non c'era nessuna chiamata.)
- **`_fade` sta al livello 10, ma Nascite e PhotoMode stanno sopra.** Il
  cartellino «E — conosci il cucciolo» compariva sul nero, e **P** in pieno
  sonno spegneva la tenda stessa (`PhotoMode._hide_ui()`): ora entrambi
  chiedono `Interactions.is_sleeping()`.
- **Il contrassegno `sognato` è SORELLA di `x`, non dentro:** `x` è una
  `String`, e `x["sognato"]` esploderebbe dentro la potatura al
  trentunesimo momento annodato. Il salvataggio è JSON: il giorno torna
  `float`, quindi si legge con `int()`, mai con `is int`.
- **`ChibiBuilder.build()` vuole un genoma INTERO.** Quello conservato nel
  filo è parziale, e senza i campi mancanti il corpo non si costruisce
  affatto: si parte da `ChibiDNA.generate(hash(nome))` e ci si scrive sopra
  quel che il filo ricorda. (Ed è anche giusto: ciò che non ricordi, il
  sogno se lo inventa.)
- **Il banco di prova va PULITO.** I contrassegni `sognato` vivono nel
  salvataggio: dopo qualche corsa dell'harness erano tutti sognati,
  `scegli()` non trovava più niente e lo schermo restava nero. Tre rese di
  fila le ho lette come un errore di illuminazione: era un banco sporco.
  `CHIBI_SOGNI` adesso azzera i contrassegni prima di partire.

**Lo stato della resa, onestamente:** il sistema è completo e provato
headless ([test_sogni.gd](tests/cases/test_sogni.gd)), e la scena si
costruisce, si illumina e si legge. Ma **non è ancora al livello del resto
del progetto**: la testona chiara riempie il quadro e gli occhi non hanno il
contrasto che hanno di giorno. Chi ci torna: la manopola è il rapporto fra
`PIENA`/`AVANTI` della lanterna e il `glow_intensity` dell'Environment del
sogno, e la strada giusta è un provino affiancato che funzioni (quello in
`CHIBI_PROVLUCE` accavalla i sogni e va sistemato prima di fidarsene).

## REGOLA: il taccuino del Gufo — si afferma solo ciò che si è VISTO

Il Regista ha due canali. Il primo conta i gesti grossi e il Gufo te li
rimanda come totale («%d opere!»). Il secondo è
[`scenes/npc/Taccuino.gd`](scenes/npc/Taccuino.gd): i **micro-gesti** che
nessuno ti ha chiesto di fare — l'esitazione davanti a una creatura, il
sentiero che percorri sempre (o che hai posato e non usi), la sosta lunga
all'aperto, la rinuncia che si ripete e diventa una regola tua. Il taccuino
scrive pagine, il Regista le cita, e **la pagina batte sempre il
contatore**: un istante citato è l'unica delle due lettere che il giocatore
non può liquidare con «era scriptato».

**Questa meccanica ha una sola modalità di guasto, ed è catastrofica.** Una
frase citata a vuoto non attenua l'effetto: **lo inverte**. «Ti ho vista
fermarti davanti a una farfalla» detto a chi stava cercando il menu insegna
al giocatore che le lettere sono generiche, e da quel momento non crede più
a nessuna. Il danno è permanente. Perciò, chi tocca questa roba:

1. **Il Gufo non dice mai cosa hai PENSATO.** Dice cosa è ACCADUTO (ti sei
   fermata, sei ripartita, tutto è rimasto dov'era) e poi cosa ha pensato
   LUI («ci ho pensato tutto il pomeriggio»). La prima metà è verificabile,
   la seconda è sempre vera perché è sua. Mai scrivere «hai esitato»: è
   un'inferenza, e un'inferenza si può smentire.
2. **Il silenzio è il comportamento normale.** Ogni giudizio ha una fascia
   grigia in cui NON scatta. Meglio nessuna lettera che una a vuoto.
3. **Le valvole non sono decorative.** La fisica spenta del player (=
   pannello, seduta, onsen, foto, costellazioni), il salto di posizione,
   il tetto massimo della sosta, il tasto premuto: toglierne una apre un
   modo preciso di scattare a caso. Il test
   [`tests/cases/test_taccuino.gd`](tests/cases/test_taccuino.gd) prende
   una finestra buona e **guasta una cosa sola per volta** pretendendo
   silenzio: se una valvola diventa inutile, quel test lo dice.
4. **Non duplicare `PostoDiSempre`.** Il posto in cui torni sempre lo nota
   già lui, e lo dice **senza parole** (un vicino è già lì). Metterci sopra
   una lettera rovinerebbe il suo silenzio.
5. **L'oracolo dell'esitazione è `ArbitroE.candidato()`** — non `scegli()`:
   chiedere «cosa farebbe se premesse E» cinque volte al secondo non è una
   contesa e non deve finire in `ultimo_verdetto()`.
6. **Le lettere stanno sotto la chiave `text_key`** in
   `Director.TACCUINO_LETTERE`, e il nome del campo è voluto: il guardiano
   della localizzazione cerca i letterali `"text_key": "…"`. Con un nome
   qualunque quelle lettere gli sfuggono e uscirebbero **in italiano dentro
   la versione inglese, con la suite verde**.
7. **La citazione va su una riga sua.** La cosa citata ha lunghezza
   variabile («una farfalla dorata», «quell'ombra nell'acqua»): in mezzo a
   una riga lunga la busta la spezza a metà parola. Si verifica **guardando
   la lettera** (`CHIBI_TACCUINO=<dir>`), non leggendo un `print()`.

Trappola già pagata: il taccuino cercava il Regista in un `call_deferred`
del `_ready` e lo trovava `null` **per sempre**, perché il Regista è un
figlio RUNTIME di CozyWorld creato a generazione differita. Il cablaggio si
**riprova** a ogni campionamento finché non ha trovato tutto.

## Le serre che si fondono (la Vetreria)

Due serre vicine non sono due serre: sono **una serra piu' grande**. Il muro
in mezzo non sparisce — diventa un'**arcata** — il colmo prosegue attraverso
il confine, e fra due campate affiancate di traverso nasce il **compluvio**,
il canale di rame che ogni serra a piu' navate ha. Con tre, quattro, nove
campate cambia anche il mestiere di dentro: serretta da giardino → galleria
→ giardino d'inverno → palmeria.

**Come sta in piedi** (`serra_pianta` / `serra_cella` in
[`BuildCatalog.gd`](scenes/build/BuildCatalog.gd), `rinfresca`/`gruppo_serra`/
`ricostruisci_serra` in [`BuildSystem.gd`](scenes/build/BuildSystem.gd)):

- **La fusione e' DERIVATA dalle celle occupate**, come `coppia()` in Affetti:
  il salvataggio resta una riga per cella, niente da migrare, e
  `get_placed_by_name("Serra")` continua a contare N nodi per N celle (Garden
  e gli Ordini del Gufo non cambiano comportamento).
- **Ogni cella disegna la PROPRIA campata** guardandosi intorno (e' il
  mestiere di `aiuola_cella`, portato su un edificio): niente capogruppo,
  quindi ogni nodo tiene identita', collisioni e meta.
- Il gruppo e' **8-connesso**: due serre che si toccano d'angolo sono un
  edificio solo, perche' i loro gusci si compenetrerebbero comunque.
- Il **rettangolo** di ogni cella si spinge a `SERRA_MURO` (0.95) sui lati
  aperti e a `SERRA_BORDO` (0.50) sui lati condivisi: **la serra sola resta
  identica a prima**.
- **Dove c'e' muro** lo decide la copertura (`serra_estremo`: 0.05 / 0.50 /
  0.95); **di chi e' il tetto** lo decide la tenda piu' alta. Sono due regole
  DIVERSE, ed e' li' che si sbaglia: due campate diagonali si incontrano
  sempre a meta' strada, a 2.19 — che e' il compluvio, gratis.
- L'elemento condiviso (montante, canale, arcata) appartiene alla cella
  **lessicograficamente minima** fra quelle che lo toccano: nessun doppione.

**Le trappole gia' pagate:**

1. **Le collisioni si rifanno SEMPRE a parte.** Le `CollisionShape3D` sono
   figlie dirette dello `StaticBody3D`, e una shape dentro un contenitore
   **non viene registrata affatto, senza errori**: il gesto dell'aiuola
   («scambio il figlio e ho finito») darebbe una vetreria bellissima e
   completamente ATTRAVERSABILE, con la suite verde. Si tolgono con
   `remove_child` (immediato), mai `queue_free` (che le lascia attive un
   frame: il varco della porta tappato proprio mentre la serra si fonde).
2. **Il rinfresco e' DIFFERITO** (`_segna_serre` + `_flush_serre.call_deferred`,
   l'idioma di `request_save`): il caricamento piazza le celle una per una, e
   un rinfresco ingenuo rifarebbe il gruppo 1+2+3+4 volte, le prime tre di
   forma sbagliata. Chi costruisce e fotografa nello stesso frame usa
   `aggiorna_serre_ora()`.
3. **La guardia in `_segna_serre` non e' decorativa**: i rinfresca ricevono il
   dizionario del LAYER, non del nome — senza di lei, posare una Sedia
   accanto a una serra ricostruirebbe un edificio intero.
4. **Il figlio «Vetreria» si RINOMINA prima di liberarlo**: un nodo in coda
   tiene occupato il nome fino a fine frame e il nuovo diventerebbe
   «Vetreria2» — al rinfresco dopo non lo trovi piu'.
5. **Le due arcate erano invertite** e nessun test poteva dirlo: il confine
   sotto il COLMO vuole l'arcone a cuspide (ci si cammina in navata), quello
   sotto il COMPLUVIO vuole l'architrave con la colonnina che lo regge. Con
   l'errore, in mezzo alla navata c'erano dei pali.
6. **Il portale deve stare SOTTO la gronda** (1.92): la prima stesura
   arrivava a 2.46 e la pensilina volava sopra le falde.
7. Gli interni cambiano **TOGLIENDO**: a due celle l'aiuola rialzata
   SPARISCE (una serra grande coltiva in vaso). Se un salto aggiunge soltanto,
   «cambia radicalmente» e' diventato «piu' vasi» — e
   [`test_serre.gd`](tests/cases/test_serre.gd) lo fa fallire.

**Gli interni si USANO.** Ogni taglia ha almeno un posto dove sedersi — lo
sgabello al bancone da rinvaso, le sedie del tavolino, la panca ad anello
sotto l'agrume — dichiarato col nodo **`Posto*`** e il meta `seduta`
(l'ancoraggio E' il posto) piu' il meta `tavolo` (cosa si guarda da seduti).
Lo trovano **tutti e due** i consumatori: il giocatore
(`BuildSystem.get_interactables`, che ora emette anche gli ancoraggi — e
cosi' funziona pure il Gazebo, dove prima potevi guardare due sgabelli e non
sederti) e i vicini (`Visitors._free_bench`). In `Interactions.SEATS` la voce
**`"Posto"`** ha scostamento ZERO e `yaw_seduta` NON la gira di mezzo giro:
il verso ce l'ha addosso l'ancoraggio, perche' solo chi costruisce il pezzo
sa dov'e' il tavolo.

**Altre due trappole pagate:**

8. **Gli ANGOLI.** Due fili di muro che si incontrano fanno un angolo, e un
   angolo senza montante e' una fessura: in controluce — che e' come si
   guarda una serra — ci si vede passare il cielo. Ce ne sono di due specie:
   i convessi del perimetro (0.95, 0.95) e i **concavi del pizzico
   diagonale**, dove i fili si fermano a 0.05 e gli spigoli veri sono DUE.
9. **Le lambda di GDScript catturano per VALORE.** Un contatore dentro una
   lambda non avanza: tutti gli ancoraggi nascevano «Posto0», Godot
   rinominava i doppioni in «@Node3D@78» — che non risponde piu' a
   `find_children("Posto*")` — e restava UNA seduta su quattro, con la
   geometria giusta e nessun test in grado di accorgersene. I nomi si danno
   con l'INDICE del ciclo.

**Come si guarda** (la suite non dice niente sulla resa):
`CHIBI_SERRE=<dir> Godot --path . --script res://tools/provino_serre.gd`
rende tutte le forme (fila, traverso, L, quadrato, croce, 3×3, diagonale) su
cinque viste; `tools/prova_serre_vive.gd` le posa nel **MainLevel vero** col
BuildSystem vero e misura i confini interni (devono essere 0 bloccati) e il
guscio (0 buchi).

## Le rastrelliere che si uniscono in fila

Seconda famiglia che si fonde, con la stessa idea della Vetreria ma una
regola di gruppo diversa: **la FILA**, non la macchia. Celle adiacenti lungo
l'asse X del pezzo **con la stessa rotazione** (come `rinfresca_braccioli`
della Gradinata) diventano una scaffalatura sola: il montante in mezzo e'
UNO, i ripiani proseguono attraverso il confine, e il piede a slitta con la
croce di controvento restano solo alle **due testate**.

- Le **tre varianti** — `Rastrelliera` (manubri di pietra), `Rastrelliera
  dischi`, `Rastrelliera pietre` — si uniscono **fra loro**: cambia il
  contenuto, non il mobile. Un unico builder,
  `BuildPalestra.rastrelliera_cella(vicini, variante, seme)`, e i tre pezzi
  a catalogo sono solo tre chiamate diverse.
- Il **montante condiviso lo disegna la campata di sinistra** (ognuna
  disegna il proprio montante sinistro; l'ultima disegna anche il destro):
  nessun doppione, verificato contando i pali verticali.
- Il **seme e' della cella** (`hash(c)`): allungare la fila non rimescola
  gli straccetti e le ciotole gia' posate.
- Il rinfresco passa dalla **stessa coda differita** delle serre
  (`_segna_serre` → `_flush_serre`), che ora rifa' entrambe le famiglie: una
  sola ricostruzione a fine frame anche quando il caricamento posa venti
  pezzi di fila.
- Aggiungere una variante vuol dire **quattro cablaggi, non uno**: la voce a
  catalogo, `Economy.CORREDO` (o resta irraggiungibile), il costo in legna in
  `Woodcutting.gd`, e la voce inglese in `locale/en/ui.gd`. Tre test diversi
  fanno la guardia a queste quattro cose.

Si guarda con `CHIBI_RAST=<dir> Godot --path . --script
res://tools/provino_rastrelliere.gd` (una, due, tre miste, quattro) e con
`tools/prova_rastrelliere_vive.gd`, che le posa nel MainLevel vero e conta i
piedi a slitta: **due** su una fila di tre, **quattro** dopo aver tolto
quella di mezzo.

## I VARCHI e i PIANI: il villaggio come grafo, e l'IA che cambia idea

Un vicino che ha fame va al cespuglio. Se il giocatore **chiude il
cespuglio dentro un recinto**, lo stesso vicino — stessa fame, stesso
cespuglio — va alla **Lavagna** e appende un biglietto per Mochi. Non è
uno script: è un pianificatore che ha smesso di trovare una strada e ne ha
cercata un'altra.

**La tesi, e spiega tutte le scelte.** L'esempio da manuale (`Ha_Mela`,
`Mela_Su_Albero`) qui non regge: i vicini non hanno un inventario (la
loro riga salvata non ne ha uno) e il cammino è `position += dir * _speed`
su un `Node3D`. In questo villaggio la risorsa scarsa **non sono gli
oggetti, è l'ACCESSO** — l'unico ostacolo che il gioco modella davvero è
una porta chiusa. Quindi il dominio è «ci arrivo / non ci arrivo», e la
mela arriva lo stesso: dalla zampa del giocatore, che è l'unica versione
della storia in cui qualcuno si diverte.

### [`Varchi.gd`](scenes/build/Varchi.gd) — dove si passa

Niente navmesh: **la topologia è già nel salvataggio**, ed è migliore. I
muri non stanno nelle celle, stanno **sui bordi** con la chiave
raddoppiata: un bordo *è* un arco del grafo, e piantare una staccionata
*è* tagliarlo.

- **Cosa blocca NON è una tabella.** Si deriva dalle `cols` del catalogo,
  cioè da dove il pezzo pianta i piedi: si passa se resta **mezzo metro di
  luce** fra 0.20 e 0.80 m d'altezza. Le conseguenze le decide la
  geometria — la Porta ne lascia 0.68 (una casa non è una prigione), la
  Staccionata zero, l'Insegna guardia è un palo da 14 cm, il Casco appeso
  non ha `cols` affatto. **Un pezzo di bordo nuovo non richiede di toccare
  questo file.**
- **`componenti()` etichetta le isole, e zero è IL FUORI.** Si semina da
  un anello oltre l'ultimo muro; quel che resta non toccato è chiuso.
  Nel dizionario finiscono **solo i posti chiusi** — il prato è quasi
  tutto, e ricordarselo cella per cella vorrebbe dire tenere in memoria un
  villaggio per descrivere il niente. Poi `raggiungibile()` è un confronto
  fra due interi.
- **Il degrado va SEMPRE verso «nessuno è in trappola»**: oltre
  `MAX_CELLE` si dichiara tutto raggiungibile. Il guasto opposto — un
  vicino che si crede murato in mezzo al prato — è quello che si vede.
- **La diagonale**: `filo_libero` la accetta solo se **tutti e due** i giri
  sono aperti. Rifiutarla sempre fa camminare i vicini a scaletta come
  carrelli elevatori; accettarla sempre li fa sgusciare per lo spigolo fra
  due staccionate, cioè attraverso il recinto chiuso; accettarla con UN
  giro aperto (la prima stesura) li fa passare sopra il palo dove la
  staccionata finisce — vero nel grafo, falso addosso a un corpo. E la
  domanda si fa su PUNTI, non su celle: vedi «il filo giudicato è il filo
  camminato», più sotto.
- Il grafo si rifà **pigro** quando cambia un bordo (`_varchi_sporchi`),
  non a ogni domanda; `aggiorna_varchi_ora()` per chi costruisce e
  interroga nello stesso frame.

### [`sistema_piani.{h,cpp}`](src/sistema_piani.h) — il risolutore

A\* in avanti su stati che sono `uint32_t`, dodici operatori con
precondizioni, **divieti** ed effetti. Puro, senza Godot, senza rng e
**senza allocazioni** (l'arena sta nello stack: un pianificatore che alloca
durante il frame ogni tanto fa un singhiozzo).

- L'obiettivo non è «sono sazio», è **«ho fatto qualcosa per la mia
  fame»**: se chiedere accendesse «sazio» il pianificatore mentirebbe. La
  sazietà resta di chi la pagava già (`STATO_CHE_SAZIA`, le callback
  d'arrivo, la consegna vera): la regola della Fase 2 — si paga quando il
  gesto ACCADE — non si tocca.
- Il pisolino per terra è **vietato** se c'è una panchina libera, non
  precondizionato: se fosse un gate, chi non ha panchina non recupererebbe
  energia mai.
- **MAI un piano a metà**: a budget esaurito torna vuoto e lo dice.
  Portare il corpo a metà strada e piantarcelo è il guasto che questa fase
  esiste per rendere impossibile.

### [`Piani.gd`](scenes/npc/Piani.gd) — l'ufficio, e dove interviene

`OBIETTIVO` lega quattro azioni della Fase 2 ai quattro obiettivi; le
altre — «quattro_chiacchiere», «gironzola» — non hanno piano **apposta**:
un piano su una cosa che cammina è sbagliato appena lo consegni.

`Visitors._piano_dirotta()` chiede al risolutore **prima** di recitare, e
torna `true` **solo** quando il piano comincia con `vai_alla_lavagna`. Nel
caso comune il piano conferma quello che `_recita` farebbe comunque, e
allora recita lei: non si ricostruisce la messa in scena di quattro gesti
che esistono già, tarati, coi loro toast e le loro callback. **Il
pianificatore non è arrivato per rifare quello che funzionava.**

**Le trappole già pagate:**

1. **`_nearest_named` era cieca ai recinti.** Il posto chiuso dentro una
   staccionata vinceva lo stesso perché era il più vicino. Adesso il muro
   si guarda lì, una volta per tutti i sistemi che chiedono «qual è il più
   vicino» — non solo per il pianificatore.
2. **La lavagna è «pronta» solo se quel vicino non ha già un biglietto.**
   Senza, «vai a chiedere» resterebbe il piano più economico per sempre e
   i vicini passerebbero la giornata alla Lavagna.
3. **La distanza è in linea d'aria, la raggiungibilità no.** La rotta vera
   costerebbe una BFS per luogo per vicino (centoquaranta al secondo in un
   villaggio pieno) e servirebbe solo a scegliere fra due posti quasi
   uguali. Si può sbagliare di qualche metro quale cespuglio conviene, mai
   credere di arrivare a un cespuglio murato.
4. **`debug_force_activity` non rinfrescava i fatti**, quindi la verifica
   CLI provava sempre e solo il ramo scritto a mano — cioè non provava la
   Fase 3.
5. **Il muro non è solido, è CONOSCIUTO.** I vicini si muovono senza
   collisioni e continuano a farlo: quello che è cambiato è che sanno
   dov'è il muro — chi non ci arriva non ci prova, e chi ci va gira
   attorno (vedi il paragrafo qui sotto).
6. **Il grafo conosceva i muri, non il MONDO.** Il letto del fiume è
   permanentemente privo di muri (`place_cell` ci rifiuta ogni pezzo),
   quindi era il corridoio più economico per aggirare qualunque recinto
   vicino alla riva — e il vicino ci camminava sopra, sospeso a mezz'aria.
   Adesso c'è `CozyWorld.terreno_vietato`: il paragrafo «La deviazione
   conosce il MONDO» dice cosa entra, cosa no, e perché `componenti()`
   continua a non guardarlo.

### Il corpo segue la ROTTA, non la retta

L'ultimo pezzo, e sta **sotto** l'IA: `Visitor._walk_to` non mette più
UN punto e ci va dritto — chiede al villaggio la strada
(`BuildSystem.deviazione`) e la percorre come **coda di tappe**, entrando
in `_next_state` solo all'ultima. Siccome la coda vive dove il corpo
cammina, **tutti** i cammini del gioco girano attorno ai muri: la
routine, il vagabondaggio, i mestieri, i visitatori del bosco. Nessuno
dei trenta chiamanti di `_walk_to` sa che esiste.

- **Vuoto vuol dire «vai dritto», mai «resta fermo».** `deviazione()`
  torna vuota quando la retta basta (il caso normale), quando non c'è
  BuildSystem (bosco, prologo, diorama), quando la meta è murata e
  quando la meta è nell'acqua. Il degrado va SEMPRE verso «si cammina»:
  un vicino piantato a metà strada è il guasto che si vede.
- **Una rotta si paga solo quando serve.** Una ricerca in GDScript costa
  centinaia di µs, quindi `deviazione` ha quattro cancelli in ordine di
  prezzo: niente muri → stessa cella → **la retta non ha muri davanti**
  (`Varchi.filo_libero`, decine di µs, ed è il caso comune) → la meta è
  nell'acqua. Misurato nel MainLevel vero con dieci residenti: **0.57
  domande al secondo, 0.068 ms al secondo in tutto**.
- **`ROTTA_TETTO` è l'UNICO guardiano del costo**, e conta le celle
  espanse. C'era anche un `ROTTA_RAGGIO := 24` sulla distanza: è stato
  tolto, perché non proteggeva da niente e **escludeva il falò per
  costruzione** (vedi il paragrafo sul mondo). Misurato sui ventotto
  tragitti veri piazza→falò con una staccionata di traverso: da 232 a
  546 celle espanse, tutti alla stessa distanza. Il prezzo lo fa
  **quanto si somigliano i due giri**, non quanto è lontana la meta.
- **IL FILO GIUDICATO È IL FILO CAMMINATO.** È la regola che tiene su
  tutto il resto, e le prime due stesure l'avevano rotta in due modi
  diversi. Il villaggio giudicava una spezzata (centro cella → centro
  cella, con `tira_filo` che la tende fino a rasentare gli spigoli **per
  costruzione**) e poi il corpo ne camminava un'altra: partiva da dov'era,
  smussava gli angoli a 25 cm, e finiva sul punto chiesto invece che sul
  centro dell'ultima cella. Tre scarti sub-cella su una spezzata che
  rasenta i muri, e la gamba passa dall'altra parte **per tutta la sua
  lunghezza**. Misurato su mille viaggi in un villaggio con una casa e due
  staccionate: **36 viaggi attraversavano un muro** (25 nella prima
  tratta, 7 nell'ultima, 4 negli smussi). Adesso zero. Tre cose lo
  garantiscono, e nessuna è una costante tarata meglio:
    1. **`Varchi.filo_libero` lavora su PUNTI, non su celle**: la
       traversata di griglia si calcola su coordinate continue, quindi la
       domanda che si fa il villaggio è esattamente il segmento che
       percorrerà il corpo. (`filo_libero_celle` resta per il grafo, e
       delega.)
    2. **`rotta_mondo` costruisce una spina dorsale che comprende gli
       estremi VERI** — punto di partenza → centro della sua cella →
       centri della rotta → centro dell'ultima → punto d'arrivo. Ogni
       coppia consecutiva è libera *per costruzione* (dentro una cella, o
       fra centri adiacenti col bordo aperto), e il filo tirato può solo
       togliere tappe verificate. La garanzia si dimostra, non si spera.
    3. **`Visitor._avanza` non smussa niente**: sulla tappa ci si posa
       sopra e il resto del passo si spende sulla gamba dopo. Lo smusso
       sembrava innocuo («25 cm sono meno del mezzo metro fra centro cella
       e muro») ma quel mezzo metro è **perpendicolare** al bordo, mentre
       lo smusso avviene lungo la direzione del cammino: taglia l'angolo,
       e l'angolo è dove c'è il palo.
- **Per lo spigolo si passa solo se tutti e due i giri sono aperti**,
  cioè se su quello spigolo non c'è nessun palo. La regola vecchia («ne
  basta uno») faceva uscire i vicini di casa tagliando per il muro
  accanto all'anta. E «per lo spigolo» non è solo «esattamente sul
  punto»: è dentro `Varchi.SPIGOLO_LUCE` (14 cm). Il numero è misurato sul
  pezzo — la Staccionata chiude i correnti con una pallina di raggio 3 cm
  **centrata sullo spigolo**, ad altezze 0.315 e 0.585, cioè in mezzo alla
  fascia in cui cammina un chibi — e serve anche all'aritmetica: un filo
  teso passa per gli spigoli veri per costruzione, e in virgola mobile
  «esattamente sullo spigolo» è «di qua o di là a caso». Misurato: i frame
  passati a meno di 5 cm da una testata scendono da 235 a 93 su mille
  viaggi.
- **Gli angoli si girano rallentando, non scivolando.** Camminare la
  spezzata esatta vuol dire che la direzione cambia in un frame, mentre il
  muso la insegue con la sua costante di tempo: un corpo che si sposta di
  qua e guarda di là, col ciclo del passo a cadenza piena, è un carrello
  elevatore (misurato prima: 837 sbandate su mille viaggi, fino a 122
  gradi, 28 cm di scivolata di lato col passo acceso). La cura sta in
  `Visitor._cammina` ed è di corpo, non di numeri: il muso **mira più
  avanti della tappa** (`GUARDA_AVANTI`, 15 cm — provinati 0/0.15/0.25/
  0.40/0.70: sopra i 40 cm il corpo si pianta ad avvicinarsi all'angolo,
  fino a 2.8 s) e la velocità è **moltiplicata per quanto si va dove si
  guarda**. Il pavimento `PASSO_PIVOT` sta sotto `Andatura.VELOCITA_FERMO`
  apposta: così il ciclo del passo si spegne da solo mentre il corpo
  perna, e nessuno deve scrivere un'animazione di svolta. Dopo: scivolata
  col passo acceso **0.187 → 0.115 m per viaggio**, sbandata peggiore
  **0.283 → 0.094 m**, deriva media 39 → 25 gradi, al prezzo del 3.7% di
  tempo di viaggio.
- **Il cammino DRITTO non è cambiato.** Provato: su mille viaggi in campo
  aperto, zero sbandate e zero gradi di deriva prima e dopo. Su una retta
  il punto mirato più avanti sta sulla stessa retta della meta, e
  l'allineamento vale uno: il conto è quello di sempre. L'unica differenza
  misurabile è che il corpo cammina gli ultimi 12 cm invece di fermarsi
  lì — **adesso si posa sul punto chiesto**, non nei paraggi.
- **`Andatura` NON è stata toccata**, e la tentazione c'era (far avanzare
  la fase sulla velocità in avanti invece che sul modulo dello
  spostamento). Provato e misurato: **non cambia niente** (0.115 e 0.094,
  identici al millimetro), perché la velocità proporzionale
  all'allineamento ha già tolto la condizione che quella modifica
  compenserebbe. In cambio avrebbe rotto due fixture e messo a rischio il
  diorama del titolo. Non si paga un rischio per zero.
- **`_target` non è più la meta**: è la prossima tappa. Chi vuole sapere
  dove uno è diretto chiede `Visitor.meta_cammino()`.
- **La coda `_tappe` NON è un canale orfano.** Si svuota in `_process`,
  per ogni stato che non sia "walk". Non in `_walk_to` e non nei due o tre
  posti che vengono in mente: un viaggio si interrompe da undici parti
  diverse (il pasto, il concerto, il congedo, il nascondino) e nessuna
  passa da un posto solo. Senza, `meta_cammino()` di un vicino seduto o
  che dorme raccontava la meta del viaggio PRECEDENTE.
- **La rotta si calcola alla partenza, non si rinfresca**: una
  staccionata piantata mentre uno cammina se la trova ancora davanti,
  fino al viaggio dopo.

### La deviazione conosce il MONDO, non solo i muri costruiti

Il grafo era fatto dei soli **bordi costruiti**, e aveva un buco a forma
di fiume: `place_cell` **rifiuta** una cella nel letto («il letto del
fiume resta del fiume»), quindi lì un muro non ci può essere *per
costruzione* — il letto era il corridoio più sgombro della mappa, e la
ricerca ci si infilava dentro ogni volta che doveva aggirare un recinto
vicino alla riva. Misurato nel MainLevel vero: tre metri di strada
diventavano nove, di cui **2.54 dentro l'acqua**, col corpo sospeso 45 cm
sopra il pelo per due secondi. Finché si andava dritti non succedeva
(la retta stava fra due punti che il gioco aveva scelto, sul prato): a
metterci il corpo era stata **la deviazione**.

- **La fonte è `CozyWorld.terreno_vietato(cella)`**, composta da quelle
  che esistevano già: `distanza_dall_acqua` (fiume **e** stagno, ellisse
  compresa), `is_river` (il letto, più largo del pelo dell'acqua — la
  stessa domanda di `place_cell`) e `cliff_x` col piede della parete
  (`CLIFF_PROFILO`, ora una costante invece di un array locale di
  `_build_cliff`). **Le colline no**: la formula del sollevamento vive
  nel vertex di `ground.gdshader` e non ha una gemella in GDScript;
  portarcela per coprire un posto dove nessuno può essere mandato sarebbe
  la copia che questo progetto vieta.
- **I pezzi bloccano un BORDO, il mondo toglie una CELLA**, e restano due
  cose diverse. Un bordo è un arco del grafo; una cella senza pavimento è
  un buco. Chi le fondesse dovrebbe inventarsi quattro muri attorno a
  ogni cella d'acqua, e si ritroverebbe un recinto chiuso dove c'è solo
  una riva.
- **Si guarda la cella in cui si ARRIVA, mai quella da cui si parte**:
  da un guado si deve poter uscire sempre (il ponte, un salvataggio
  vecchio, un banco di prova). Il degrado va verso «si cammina».
- **`componenti()` NON lo guarda, ed è una decisione.** Lei risponde a
  «mi hanno chiuso dentro?», e la sua risposta fa RINUNCIARE un vicino a
  un posto (`_nearest_named`, `Piani`). Il fiume non è una porta che
  qualcuno ha chiuso: ha due ponti, che vivono nella geometria del mondo
  e non in questo grafo. Metterlo lì dichiarerebbe prigioniera l'intera
  riva est — il guasto che `MAX_CELLE` esiste per non commettere. Il
  residuo è dichiarato: un recinto appoggiato alla riva non viene
  riconosciuto come chiusura, chi ci abita ci si incammina e va dritto
  attraverso la staccionata (la resa che c'era già).
- **L'INVARIANTE**: *il corpo o cammina la retta di sempre, oppure una
  spezzata che non tocca né un muro né l'acqua.* Non c'è una terza
  risposta — ed è per questo che il cancello della retta guarda **solo i
  muri**. Chiedere una strada anche per schivare l'acqua sembra più bello
  e non lo è: le mete di questo gioco sono spesso in riva (il posto da cui
  si guardano le rane, il ponte), e la ricerca finirebbe per pagare
  millisecondi e ridare comunque la retta.
- **Il costo si paga una volta per cella, per sempre.** `Varchi.Suolo` è
  un quaderno che non scade, perché il terreno non si muove. Misurato: una
  sera intera di ricerche costa **998 domande al mondo invece di 14.695**.
  E `terreno_vietato` campiona **dove serve** — una domanda per l'acqua
  (che risponde con una distanza, quindi è già omnidirezionale), due in x
  per il letto (il corso si sposta di 0.102 m/m), tre in z per la parete
  (che alla cascata si sposta di 1.82 m/m): **2.01 µs a cella invece di
  3.77**.

### Il falò non è più l'eccezione

La radura sta a **cinquantasei celle** dalla piazza, e il raggio ne
concedeva ventiquattro: ogni sera ventotto vicini attraversavano in fila
indiana qualunque staccionata avessero davanti, nell'unico evento
comunitario della giornata. Alzare il raggio non bastava — una ricerca in
ampiezza, per una meta così lontana, esplora **5.176 celle** e il tetto ne
concede 2.048.

- **`Varchi.rotta` è guidata dalla distanza che manca** (A\*, coda a
  secchi alla Dial: i passi costano uno e la stima è intera, quindi `f`
  cambia di zero o di due e un mucchio binario sarebbe sprecato). Stesso
  tragitto: **354 celle espanse invece di 5.176**, e la strada è **lunga
  uguale** — verificato su 200 villaggi a caso contro una BFS scritta nel
  test. Attenzione: la stima è ammissibile *e consistente*, ma una cella
  va chiusa quando la si SPENDE, non quando la si scopre. Chiudere alla
  scoperta accorcia il conto e allunga la strada, e si vede **solo dove i
  muri sono fitti** (misurato: 4 casi su 200 con muri radi, 15 su 200 con
  muri fitti — un banco rado sarebbe stato verde su un codice sbagliato).
- **IL TURNO.** Con una staccionata di traverso una domanda costa ~1.5 ms;
  ventotto insieme farebbero cinquanta millisecondi. `BuildSystem` ne
  concede uno scampolo per frame (`BUDGET_ROTTE_US`, misurato in µs veri —
  così le domande a buon mercato non consumano niente e in un villaggio
  normale il turno è sempre aperto). Chi lo trova occupato **non perde la
  sua strada**: cammina dritto per un frame (quattro centimetri) e
  ripropone la domanda (`Visitor._rotta_attesa`). Misurato col caso
  peggiore possibile — tutti e ventotto nello stesso identico frame —
  **28 serviti in 28 frame (0.47 s), il frame peggiore 4.5 ms invece di 50**.
- **Un banco di prova deve spegnere il turno.** `tools/misura_cammino.gd`
  e le fixture di `test_rotta_corpo.gd` fanno decine di viaggi dentro UN
  frame del motore: col turno acceso, dal secondo in poi nessuno avrebbe
  più una strada e il banco proverebbe un gioco che non esiste. Chi scrive
  un usciere finto nel gruppo `build_system` deve rispondere a **tutti e
  due** i metodi (`deviazione` e `turno_rotte_libero`), o `Visitor` non lo
  riconosce affatto.

**Come si guarda** (la suite non dice niente sulla scena):

```
Godot --headless --path . --script res://tools/prova_recinto.gd
Godot --headless --path . --script res://tools/prova_fiume.gd
Godot --headless --path . --script res://tools/misura_cammino.gd
Godot --headless --path . --script res://tools/misura_rotta.gd
```

Il primo costruisce casa, Lavagna e Cespuglio nel MainLevel vero, ci mette
un vicino vero, e guarda **dove va il corpo**: al cespuglio prima, alla
Lavagna dopo aver chiuso il recinto, col biglietto che compare quando il
gessetto si ferma — non prima. Poi pianta una staccionata da undici metri,
manda un chibi **da un punto sfasato** (mai un centro di cella: è l'unico
posto in cui le due spezzate coincidono, ed è così che questa prova era
cieca) e stampa la traiettoria **frame per frame**.

Il secondo pianta una staccionata **fino alla riva**, una **contro la
parete** e una **di traverso sul tragitto del falò**, e per ognuna stampa
la traiettoria chiedendo a `CozyWorld.is_river` se quel campione è acqua.
Poi simula due sere: quella vera (col lease 0.4–1.8 s di
`Visitors._routine`) e il caso peggiore possibile, e conta i millisecondi
frame per frame.

Il terzo è il METRO DEL CAMMINO: mille viaggi con estremi a caso, e due
numeri che nessuna asserzione booleana sa dare — quanti attraversano un
muro, e quanto scivola di lato il corpo col passo acceso. Il quarto è il
METRO DELLA RICERCA: celle espanse (contate per **bisezione sul tetto**,
senza strumentare il codice di produzione), guidata contro ampiezza,
prezzo di una domanda al mondo, e la controprova che la strada è la più
corta.

**In tutti l'oracolo è indipendente da `Varchi`**: i muri diventano i
segmenti veri che occupano sul confine, ogni spostamento di un frame è un
segmento a sua volta, e la domanda è se i due si tagliano. Chiedere a
`Varchi` se il corpo ha attraversato un muro vuol dire chiedere al giudice
se è d'accordo con sé stesso — e la prima stesura di questa verifica faceva
esattamente quello, per giunta sulla traiettoria ridotta a celle (un corpo
che entra ed esce da un muro fra due campioni non lasciava traccia).

La guardia headless è
[`tests/cases/test_rotta_corpo.gd`](tests/cases/test_rotta_corpo.gd), e
non è un source-check: fa girare il `_process` di un villager vero
sessanta volte al secondo e guarda **dove passa il corpo**. Ha la
controprova nello stesso file — senza il muro, lo stesso viaggio ci passa
in mezzo — perché un test che non sa fallire non dice niente.

**E le sue coordinate sono SFASATE, apposta.** La prima stesura provava un
viaggio solo, fra due punti interi: l'unico caso in cui la spezzata
giudicata e quella camminata coincidono, cioè l'unico in cui la garanzia
valeva. Rifacendo lo stesso scenario spostando la partenza dentro la sua
cella, **24 viaggi su 81 attraversavano il recinto con la suite verde**.
Adesso c'è `_la_griglia_degli_sfasamenti`: quarantanove viaggi con
partenza E arrivo fuori dai centri di cella, e zero attraversamenti — e
sul codice di prima ne fallisce nove. Un test che sceglie l'unico punto in
cui il codice è giusto non è un test: è un ritratto.

Ci sono altri tre casi che prima non esistevano, e ognuno è stato
verificato **rompendo apposta la riga che sorveglia**:
`_la_politica_della_deviazione` (togliere `tappe.remove_at(0)` lasciava la
suite completamente verde), `_la_cella_di_un_punto` (sostituire `roundi`
con `floori` in `Varchi.cella` lasciava verdi sessantunmila asserzioni) e
`_la_coda_non_e_orfana`.

## REGOLA: la lingua (italiano sorgente, inglese sopra)

Il gioco è **bilingue** dal 2026-07-28: italiano (lingua sorgente) e inglese.
Il motore è [`systems/L10n.gd`](systems/L10n.gd); il glossario vincolante e le
regole di stile stanno in [`docs/TRADUZIONE.md`](docs/TRADUZIONE.md).

- **La chiave È la frase italiana.** Nel codice le stringhe restano quelle
  vere e leggibili: `L10n.t("Buongiorno!")`. Niente chiavi opache tipo
  `MAIL_LETTER_3` sparse nei sorgenti. Una traduzione mancante mostra
  l'italiano, mai una sigla.
- **Si traduce SOLO al momento di mostrare, mai il dato.** I nomi dei pezzi
  (`"Cassetta posta"`), gli id delle specie, i gradini di `Animo.SCALA`, i
  tipi di momento dei Legami viaggiano nei **salvataggi** e nei predicati:
  restano italiani per sempre. Un villaggio salvato in inglese si riapre in
  italiano, e viceversa.
- **Vale anche per il TESTO che passa dal disco prima di arrivare a
  schermo.** La **posta** è il caso di scuola: si mette in coda stanotte e
  si apre domattina, e in mezzo il giocatore può cambiare lingua. Perciò in
  coda va la **chiave**, mai la frase tradotta — `queue_letter({"from_key":
  …, "text_key": …, "args": […]})`, e la traduzione la fa `Mail.rendi()`
  quando la busta si apre. Il meccanismo generale è `L10n.rendi()` (la
  «frase rimandata»); chi produce testo destinato alla coda ha la sua
  versione a chiavi (`Animo.sfogo_rimandato()`,
  `Promesse.bigliettino()`, `Critters.con_articolo_chiave()`…). Dettagli e
  regole di taglio in [`docs/TRADUZIONE.md`](docs/TRADUZIONE.md); la
  guardia è [`tests/cases/test_posta_lingua.gd`](tests/cases/test_posta_lingua.gd).
> ### ⚠️ REGOLA OBBLIGATORIA — testo nuovo = traduzione nuova, SUBITO
>
> Ogni volta che aggiungi al gioco **testo che il giocatore vede** — dialoghi,
> lettere, nomi, prompt, toast, etichette di UI — nella **stessa sessione**:
> 1. avvolgi la frase dove si mostra: `L10n.t("...")` (con segnaposto:
>    `L10n.tf("Giorno %d", [n])` — **mai formattare prima di tradurre**, la
>    frase già riempita non sta in tabella);
> 2. aggiungi la voce inglese nella parte giusta di `locale/en/`
>    (`ui` · `lettere` · `mondo` · `npc`), con la chiave copiata
>    **byte-per-byte** dall'italiano del sorgente;
> 3. segui [`docs/TRADUZIONE.md`](docs/TRADUZIONE.md): glossario vincolante,
>    inglese britannico, qualità letteraria (non traduzione tecnica).
>
> **Non rimandare a "una passata di localizzazione dopo".** Una frase tradotta
> mesi dopo, fuori dal suo contesto, esce peggiore; e nel frattempo il gioco è
> metà in una lingua e metà nell'altra. Il test
> [`tests/cases/test_localizzazione.gd`](tests/cases/test_localizzazione.gd)
> diventa **rosso** se una frase avvolta in `L10n.t()` non ha la sua voce in
> tabella: la suite verde è la prova che hai finito.

Il test controlla anche: segnaposto identici (`%s`/`%d` — uno in meno e il
gioco crasha al primo format), a capo conservati (sono l'impaginazione delle
lettere del Gufo), grafie britanniche e parole vietate dal glossario. La
soglia di copertura sale con la traduzione: **non abbassarla** per far passare
la suite — aggiungi le voci che mancano.

## Trappola: i commenti nei file ConfigFile (`;` non `#`)

`*.gdextension`, `export_presets.cfg`, `project.godot` sono in formato
**ConfigFile**: i commenti vanno con **`;`**. Con `#` il parser **fonde** la riga
di commento con la successiva in una chiave spazzatura, e la chiave che segue
**scompare senza errore**. È già costato due volte:

- in `chibi_crossing.gdextension` spariva `compatibility_minimum` → l'intera
  GDExtension C++ non si caricava (schermo grigio con la sola musica, e le
  classi native assenti nei test);
- in `export_presets.cfg` spariva `codesign/codesign=0` dal preset macOS.

I valori vanno anche **fra virgolette** dove sono stringhe: senza, un
`compatibility_minimum = 4.10` viene letto come il float `4.1`.

## Come deve COMINCIARE il gioco (il prologo)

L'apertura del gioco è già decisa dall'autore e sta in
[`docs/PROLOGO.md`](docs/PROLOGO.md): dal tasto «nuova avventura» si parte con una
**piccola Mochi cucciola sotto una tempesta**, sola e spaventata, che si gira
verso la camera e **parla al giocatore** rompendo la quarta parete; il cielo si
apre, e il tutorial la fa **crescere** fino alla Mochi adulta di adesso.

**Non è una proposta: è la direzione.** Prima di toccare la schermata del titolo,
il primo avvio o il tutorial, leggi quel documento. Si realizza un passo alla
volta insieme all'autore, e il gancio tecnico è già in casa: la crescita
cucciolo→adulto è `Visitor.set_cucciolo(t)`, con `t` da 0.0 a 1.0.

## Il salvataggio di prova (molte case, nessun abitante)

Per provare i sistemi senza giocare venti ore c'è un villaggio generabile in
`tools/`: **dieci case complete e vuote**, campagna del Gufo finita, catalogo e
negozio sbloccati, dispensa piena.

```
tools/installa_salvataggio_prova.sh            # copia di sicurezza + installa
tools/installa_salvataggio_prova.sh --vero     # senza la leva: qualcuno rifiuta
tools/installa_salvataggio_prova.sh --ripristina
```

- [`genera_salvataggio_prova.py`](tools/genera_salvataggio_prova.py) scrive il
  `village.json`. Le liste (nomi dei pezzi, nomi dei chibi, listino, tinte) le
  **legge dai sorgenti**, non le ricopia: se qualcuno aggiunge un pezzo, il
  generatore se ne accorge da solo.
- [`verifica_salvataggio_prova.py`](tools/verifica_salvataggio_prova.py)
  controlla il file **prima** di darlo al gioco, perché il caricamento scarta in
  silenzio: una riga che non ha esattamente 5 elementi (4 per i bordi) sparisce
  senza un messaggio, un nome fuori catalogo dà solo un `push_warning`, e una
  cella nel letto del fiume non lascia traccia. Ricalcola anche le otto feature
  della casa e la soglia della mente del candidato.
- [`prova_arrivi.gd`](tools/prova_arrivi.gd) è la verifica **viva**: carica il
  MainLevel vero, spegne la persistenza e fa arrivare quattro candidati.
  `Godot --headless --path . --script res://tools/prova_arrivi.gd`

**Due cose da sapere prima di dire «non funziona»:**

1. **Una casa non è un letto.** Il gioco chiama casa libera un `Letto` che abbia
   una **copertura sulla sua stessa cella** (`Visitors._free_house` +
   `BuildSystem.has_cover`). Ma «libera» non è «accettata»: il candidato riduce
   la casa a otto feature e serve `p > 0.72`. Una casa `Letto+Tetto` nuda vale
   p ≈ 0.016 — arriva, guarda e riparte col trolley. Per questo le case generate
   hanno muri, porta, finestra, comodità, giardino e camino.
2. **Gli arrivi sono seriali**: uno alla volta (`if _active == null`), solo di
   giorno e col sereno, con 45 s il primo e poi 80–160 s fra uno e l'altro.
   Dieci case non si riempiono in un minuto. Per riempirle subito ci sono
   `Visitors.debug_candidate/debug_goto_wait/debug_force_decide`.

## L'ECS in C++, e la sua UNICA autorità

Dal 2026-08-10 il cuore C++ ha un registro **ECS** (EnTT 3.13.2, header-only,
MIT) e una prima decisione che **non sta più in GDScript**: il ciclo
sonno/veglia dei residenti.

**Com'è fatto.** `EcsMondo` (`src/ecs_mondo.{h,cpp}`) è un `Node` che possiede
un `entt::registry` in PImpl. I componenti stanno in `src/ecs_componenti.h`, la
regola pura in `src/sistema_sonno.{h,cpp}`. Il cablaggio è tutto in
`Visitors._ciclo_sonno()`: **fatti → passo → gesti**, dentro un frame.

- Il nostro codice sta **flat in `src/`**; EnTT sta in `src/thirdparty/` col suo
  `.gdignore` (l'importer scandaglia `src/` sul serio) e la sua voce in
  [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
- **`src/ecs_entt.h` è l'UNICO posto autorizzato a includere `entt.hpp`.** Lì si
  pareggiano due asimmetrie fra i rami del build: `-fno-exceptions` su
  macOS/Linux contro `/EHsc` su Windows, e `NDEBUG` che non è definito nelle
  stesse quattro combinazioni. Chi includesse EnTT da un altro `.cpp` le
  riaprirebbe **e nessun test lo vedrebbe**.
- Il `SConstruct` **non si tocca** (entrambi i rami hanno già `src/` nel
  CPPPATH) e il `.gdextension` **non si apre** (header-only: nessuna dipendenza).

### Le cinque regole che NON si negoziano

1. **L'autorità è su UN canale solo, ed è il sonno.** Il villaggio ha **undici**
   sistemi che impongono stati a evento (Concerto, Salone, Nascondino,
   Concertino, Promesse, Calendar, Congedo, Bancarella, RichiesteFoto, Premura,
   DebugHarness). Un C++ che scrivesse «lo stato» ogni frame vincerebbe su di
   loro **senza un errore**. Chi allarga lo `StatoComponent` ai 43 stati del
   Visitor senza prima convertire quegli undici sistemi in comandi verso l'ECS
   scioglie il concerto dopo un frame.
2. **`passo_sonno()` comincia RICONCILIANDO.** Se un altro sistema ha svegliato
   o nascosto qualcuno, il registro lo **accetta**. Togliere quelle due righe
   rimette a dormire chiunque il mondo abbia svegliato, un frame dopo — ed è la
   forma di guasto che non lascia tracce.
3. **Il `DnaComponent` porta SOLO geni fuori da `ChibiDNA.ESTETICI`** (oggi:
   `indole` e `quirk`). Il salone di bellezza riscrive i geni estetici **dentro**
   il Dictionary del DNA, che è lo stesso oggetto della riga del salvataggio: una
   copia C++ di un gene estetico diventerebbe stale al primo cambio di look, **con
   la suite verde**.
   Ma «non estetico» non vuol dire «immutabile»: `debug_quirk()` scrive il quirk
   su un cervello vivo. Per questo il cablaggio **confronta e riproietta**
   (`EcsMondo::riproietta`) quando i valori cambiano. Chi aggiunge un campo al
   `DnaComponent` deve chiedersi **chi lo scrive a runtime**, non solo chi lo
   genera.
4. **Dove muore il cervello, muore l'entità.** Accanto a ogni `_brains.erase` c'è
   un `_dimentica_ecs`. L'handle vive SOLO in `r["ecs"]`, in RAM: non entra in
   nessun salvataggio e non fa da chiave a nessun altro sistema (il villaggio ha
   già due anagrafi, nome e label — questa non deve diventare la terza).
   **Questa regola la tiene una convenzione, non il compilatore:** i due punti
   veri (`_congeda` e la partenza) non sono coperti da un test, perché
   chiamarli vuole il villaggio in scena. La rete è l'invariante
   `quanti() == _brains.size()` in `test_sonno_residenti`. Chi aggiunge un
   percorso che toglie un residente **deve** aggiungere la riga: un'entità
   orfana oggi non si vede, alla Fase 2 decide per un corpo che non c'è.
5. **Il passo è `avanza(delta, ora)`, chiamato a mano.** Niente `_process` né
   `_physics_process` in `EcsMondo`: l'ordine dev'essere deterministico e
   guidabile dai test, e i virtuali di una GDExtension non sono chiamabili per
   nome da GDScript. `test_ecs_mondo._motore_spento` fa la guardia.

### FASE 2 — il motore dei bisogni, e il ritmo

Dal 2026-08-10 la SCELTA DELL'ATTIVITÀ è la seconda autorità del C++.
`src/curve_utilita.{h,cpp}` è una macchina IAUS vera (sei curve di risposta
+ compensation factor); `src/sistema_agenda.{h,cpp}` è la tabella delle otto
azioni come considerazioni componibili. Il cablaggio sta in
`Visitors._fatti_di()` e `_gesti_agenda()`.

- **I BISOGNI NON SONO TRASLOCATI.** Restano di `VillagerBrain` perché sono
  PERSISTITI: due case sullo stesso dato salvato è il guasto che le fonti
  uniche vietano. Il C++ ne riceve uno SPECCHIO (`const double*`: non ha la
  possibilità sintattica di scriverli).
- **Le curve TRASPORTANO le formule di prima, non le rimodellano.** La prova
  di equivalenza (`test_agenda_equivalenza`) confronta ~63.000 casi contro
  `tests/oracolo_agenda.gd` e pretende l'uguaglianza ESATTA sui double.
  Cambiare una curva è un commit suo, con la misura in mano.
- **SI RECITA SOLO SUL FRONTE** (`azione_cambiata`). `_recita` rimette il
  corpo in cammino: chiamarla ogni frame vuol dire non ARRIVARE mai, quindi
  non saziare mai il bisogno, quindi ridecidere — un livelock che non stampa
  errori.
- **Le tre leve contro il tremolio**: il lucchetto del corpo, `T_MIN = 2 s`,
  e il dado CONGELATO per decisione (il dado si tira in GDScript: in C++ non
  c'è e non ci sarà un RNG). **L'urgenza ABBASSA T_MIN a un quarto, non lo
  abolisce**: un'azione che sazia il proprio bisogno nel frame in cui viene
  scelta sembra urgente per sempre, e senza pavimento si cambia idea alla
  frequenza del frame (misurato).
- **I FATTI del mondo si rinfrescano ogni 30 frame, sfalsati per residente.**
  A 60 Hz per 28 vicini il contesto costerebbe metà frame, e il costo
  crescerebbe con quanto il giocatore costruisce: il gioco punirebbe chi
  costruisce.
- **`AzioneVaiAlLetto` non esiste e non deve esistere**: il sonno è l'altra
  autorità e sta SOPRA l'agenda (`passo_agenda` tace se non sveglio). E il
  falò resta un COMANDO, non un'azione in gara: è un rito coi posti
  assegnati, e farlo competere significa che qualcuno non ci va.
- Le tre divergenze volute («meraviglia» e «regia» diventano infattibili
  senza il posto/il piano; `gironzola` è il ripiego che diventa una scelta
  dichiarata) hanno ognuna il suo caso di test nominato.

### Cosa la Fase 1 NON possiede — leggere prima di allargare

`VillagerBrain.choose()` (pura, ma il contesto è tutto-mondo e l'esecutore può
disattenderla), `brain.tick()` e i cinque `needs` (sono **persistiti**), il
canale `postura` (22 scrittori in 6 file), `Animo`/`Affetti`/`Lavori`,
qualunque RNG (i dadi del villaggio si salvano) e qualunque persistenza.
`TransformComponent` è **dichiarato e mai istanziato**: entra vivo quando
arriva il suo primo lettore (il cammino), e fino ad allora
`debug_quante_pose()` deve tornare 0 — un test lo pretende.

E `VillagerBrain.nottambulo()` **resta in GDScript** (la usa anche l'attività
«stella», `VillagerBrain.gd:180`): è l'unica formula che vive in due lingue, e
la prova di equivalenza in `test_ecs_mondo` fa la guardia su entrambe.

### Come si verifica

```bash
python3 -m SCons platform=macos arch=universal target=template_debug -j8
Godot --headless --path . --import
Godot --headless --path . --script res://tests/test_runner.gd
CHIBI_SONNO=/tmp/sonno Godot --path . --script res://tools/prova_sonno_ecs.gd
```

L'ultimo apre il **MainLevel vero**, insedia tre vicini, porta l'orologio a
0.55 → 0.86 → 0.40 e fotografa: alle 0.86 il prato dev'essere **vuoto**. La
suite non dice niente su questo. E il ramo Windows del `SConstruct` non è
verificabile da un Mac: la CI (`build.yml`, che ora gira anche sui rami di
lavoro) è l'unico giudice per Windows e Linux.

## FASE 5 — il cuore che scrive (llama.cpp), e la leva spenta

Il gioco **può** avere dentro un modello linguistico piccolo, in locale, che
scrive di suo pugno le lettere del Gufo, i pensieri e i discorsi. Il terreno
c'è: `llama.cpp` è un **sottomodulo pinnato** e il `SConstruct` lo compila e lo
linka con `scons llm=yes`. Di default è **spento**, e non «spento» come «c'è ma
non si usa»: con `llm=no` i sorgenti `src/llm_*.cpp` non entrano nemmeno nella
lista dei file da compilare.

> ### ⚠️ LA REGOLA CHE PRECEDE TUTTE, QUI: il gioco funziona IDENTICO senza
>
> Chi non ha il modello ha un gioco **meno sorprendente**, non un gioco a cui
> manca un pezzo. Niente schermate di errore, niente caricamenti che si
> piantano, niente lettera che non arriva: le lettere scritte a mano ci sono e
> restano. Chi scrive il ramo «c'è il modello» **scrive prima quello senza** —
> e se una funzione non ha una risposta bella senza, quella funzione non si fa.

**Come fa il gioco a saperlo.** La GDExtension registra la classe nativa
`LlmLocale` **solo** se compilata con `llm=yes`: l'esistenza della classe *è* il
segnale. Non c'è un file di configurazione da tenere allineato né un flag
salvato che possa mentire — un binario compilato senza llama.cpp non ha proprio
il codice per rispondere di sì. La domanda si fa in un posto solo,
[`systems/Llm.gd`](systems/Llm.gd) (`Llm.disponibile()` / `Llm.apri()`), e un
test fa la guardia perché resti così.

**Il pin.** Tag **`b10326`** (SHA `3653e6d`, 7 agosto 2026), in
`src/thirdparty/llama.cpp`. A monte non esistono rami stabili: solo tag di
build, più d'uno al giorno. Quindi in `.gitmodules` **non c'è `branch`** — la
verità è il SHA del gitlink — e c'è `shallow = true`, perché il clone completo
pesa 436 MB di storia per un sorgente che ci serve fermo. Con `shallow`:
`git submodule update --init --depth 1 src/thirdparty/llama.cpp` → 40 MB di
`.git` e 168 MB di albero. Cambiare tag è **un commit suo**, dopo aver visto la
CI verde su tutti e tre i sistemi.

**Come si compila** (serve `cmake`; llama.cpp non ha altro build supportato a
monte, ed è la sua CMake a scegliere sorgenti e flag per architettura):

```
scons platform=macos arch=universal target=template_debug llm=yes -j8
```

La prima volta sono venti minuti scarsi (ggml è qualche centinaio di file);
dopo, un timbro (`llm-build/<piattaforma>-<arch>/timbro.json`) tiene conto del
SHA e delle opzioni e non rifà niente finché non cambiano. Le leve:
`llm_metal=yes` (GPU su macOS, spenta finché non c'è un modello vero da
misurare), `llm_avx2=no` (x86: rinuncia alla baseline Haswell), `llm_cmake=…`,
`llm_msvc_crt=…`, `llm_ricostruisci=yes`.

**Le trappole, e sono quasi tutte di piattaforma:**

1. **Il CRT di MSVC è il rischio numero uno, e non è verificabile da un Mac.**
   Il nostro ramo win32 non passa né `/MD` né `/MT`: `cl.exe` senza opzioni usa
   il runtime C **statico** (`/MT`), che è anche quello che sceglie godot-cpp
   (`use_static_cpp=True`). CMake invece parte da `/MD`. Due metà con CRT
   diversi si fermano al link con **LNK2038**, e il rimedio è una variabile:
   `llm_msvc_crt=MultiThreadedDLL`. Il giudice è il job *Compila con llama.cpp
   (windows)* di `build.yml`.
2. **macOS universale = DUE passate + `lipo`.** `CMAKE_OSX_ARCHITECTURES` con
   due valori insieme non funziona: ggml sceglie sorgenti e flag guardando
   proprio quella variabile (`ggml/cmake/common.cmake`) e con `arm64;x86_64`
   non riconosce nessuna delle due. Si compila una volta per architettura e si
   uniscono gli archivi.
3. **`-fPIC` non è opzionale**: le `.a` finiscono dentro una libreria
   *condivisa*, e su Linux senza `CMAKE_POSITION_INDEPENDENT_CODE=ON` il link
   muore con «relocation R_X86_64_32 … can not be used when making a shared
   object».
4. **`GGML_NATIVE=OFF` non vuol dire «senza SIMD»**: in ggml spegne
   `-march=native` (che darebbe un binario buono solo per il PC che l'ha
   compilato) e **accende** la baseline fissa Haswell su x86. È quello che
   fanno le release ufficiali di llama.cpp. Metterlo a `ON` significa
   spedire un gioco che va in SIGILL sulla macchina di qualcun altro.
5. **Le eccezioni: il confine si compila DIVERSO dal resto del cuore.**
   godot-cpp compila tutto con `-fno-exceptions`; llama.cpp compila i suoi con
   le eccezioni, e `llama_decode`, `llama_tokenize` e `llama_token_to_piece`
   **non se le riprendono da sole** (`llama_model_load_from_file` e
   `llama_init_from_model` sì: hanno il loro try/catch e tornano `nullptr`).
   Un throw che arriva su un frame senza eccezioni non è un errore da gestire,
   è `std::terminate`. Perciò il `SConstruct` compila `src/llm_*.cpp` — e solo
   quelli — con `-fexceptions`, e [`src/llm_llama.h`](src/llm_llama.h) fa
   fallire la build con un `#error` se quel flag sparisce.
6. **`ggml` ABORTISCE il processo, e non c'è callback.** `GGML_ABORT` non è
   `assert()`: `NDEBUG` non lo spegne e chiama `abort()`. Un `.gguf` corrotto o
   troncato può portarsi via il gioco del giocatore, e **nessun `try` lo
   prende**. È un residuo dichiarato di questa fase: chi porterà il modello
   vero deve validarlo prima di darlo in pasto a llama, e valutare seriamente
   se farlo girare in un processo suo — che è l'unica difesa vera.
7. **`src/thirdparty/` ha un `.gdignore`, e serve.** L'importer di Godot
   scandaglia `src/` sul serio, e lì dentro ci sono migliaia di file e dei
   `.gguf` di prova del repository a monte.
8. **I pesi non entrano MAI nel repository** (`*.gguf` in `.gitignore`). Git
   conserva ogni versione di ogni file per sempre: due gigabyte messi lì una
   volta non si tolgono più, e rallentano il clone di chiunque per sempre.
9. **La licenza dei PESI non è quella di llama.cpp.** Il motore è MIT; ogni
   modello ha la licenza sua, e questo viaggerà **dentro il pacchetto** di un
   gioco commerciale. Si legge prima di sceglierlo, e si annota in
   [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

**Come si verifica** (la suite verde non dice niente sul terreno):

- `build.yml` ha un job **`build-llm`** che compila con `llm=yes` su tutti e
  tre i sistemi (con cache della build di ggml: la prima volta è lunga, poi no);
- `tests.yml` ha un job **`test-llm`** che fa girare **la stessa suite** sul
  cuore con llama dentro. È il gemello che nessuno guarda mai: «funziona
  identico senza» ha senso solo se qualcuno prova anche «e identico con»;
- in locale, l'impronta: con `llm=no` il binario dev'essere **byte per byte**
  quello di prima (`shasum -a 256 bin/*.dylib` prima e dopo).

## Test

Test-suite **dependency-free** (nessun addon, nessuna rete) in `tests/`:
`test_runner.gd` (estende `SceneTree`) carica ed esegue tutti i `tests/cases/test_*.gd`
— ognuno espone `func run(t)` e usa gli helper `t.ok/eq/almost`. Copre le classi
C++ (`SurvivalComponent`, `GridManager`, `PlayerController`, `EcosystemManager`)
e la logica pura GDScript (`ChibiDNA`, funzioni matematiche di `CozyWorld`).

- **In locale** (col Godot in `~/Downloads`): serve prima un import per
  registrare le GDExtension (vedi sotto), poi:
  ```
  Godot --headless --path . --import
  Godot --headless --path . --script res://tests/test_runner.gd
  ```
  Esce con codice 0 (tutti passati) o 1 (fallimenti). Il runner **salta** gli
  script con errori di parse senza appendersi.
- **`--import` è obbligatorio prima dei test**: in modalità `--script` Godot
  carica le GDExtension (cuore C++ chibi + addon lua) SOLO se esiste la cache
  `.godot/extension_list.cfg`, che è gitignored; l'import la (ri)genera. Senza,
  nessuna classe C++ risulta registrata (lo smoke test lo rileva).
- **In CI**: [`.github/workflows/tests.yml`](.github/workflows/tests.yml) gira su
  **macOS** (non Linux: i binari dell'addon lua sono committati solo per
  macOS/Windows), compila il cuore C++, fa `--import` e poi esegue la suite. I
  trigger sono ristretti (i runner macOS costano 10×).
> ### ⚠️ La suite verde NON vuol dire che le asserzioni siano girate
>
> Il runner **non fa fallire** un test che va in errore a runtime: l'errore
> interrompe la funzione a metà, le asserzioni successive non vengono eseguite,
> e la suite resta **verde**. Dopo ogni run, quindi, si contano anche gli errori:
>
> ```
> Godot --headless --path . --script res://tests/test_runner.gd 2>&1 | grep -c "SCRIPT ERROR"
> ```
>
> Deve dare **0**. Ogni riga `at: res://tests/cases/...` è una funzione di test
> che si è fermata lì. Il 2026-07-31 ce n'erano dieci: nove test scritti male
> (sette con gli argomenti di `t.almost` invertiti — la firma è
> `almost(a, b, messaggio, tolleranza)`, **il numero va in fondo**) e **un bug di
> produzione vero** che il test copriva davvero e che nessuno vedeva.
> Utile anche guardare il NUMERO di asserzioni: se dopo una correzione sale,
> quelle erano asserzioni che non giravano.

- Convenzioni per nuovi test: file `tests/cases/test_<area>.gd`, `extends
  RefCounted`, niente `add_child` all'albero (le classi C++ si creano con
  `.new()` e si liberano con `.free()`); usa `var x = ...` (non `:=`) quando il
  valore viene da un'istanza non tipizzata, altrimenti l'inferenza fallisce.

## Le PRESTAZIONI non si misurano headless (né a occhio)

Senza rendering non c'è niente da contare, e `--headless` è proprio il modo
in cui una stalla del server di rendering diventa invisibile. Per i
fotogrammi c'è [`tools/misura_fps.gd`](tools/misura_fps.gd): apre il
MainLevel VERO con la finestra, spegne il vsync (o si misura il monitor) e
conta i fotogrammi a orologio.

```
CHIBI_FPS_SEC=8 CHIBI_FPS_GIRI=2 ~/Downloads/Godot.app/Contents/MacOS/Godot \
    --path . --resolution 1280x720 --script res://tools/misura_fps.gd
```

- **Si misura sempre A/B nella STESSA corsa** (qui: col gestore delle corde
  acceso e spento, a finestre ALTERNATE). Due processi diversi non sono
  confrontabili — compilazione degli shader, cache, e soprattutto **le altre
  sessioni di agente**.
- **Guarda il carico PRIMA di credere a un numero** (`uptime`, e quanti
  Godot girano). Il 2026-08-12, con venti processi Godot di altre sessioni
  addosso, il MainLevel stava a **8 fps prendendo il 25% di UN core**; due
  ore dopo, **stesso codice** e macchina più libera, **17.8 fps**: il gioco
  era affamato, non lento. In quelle condizioni due finestre
  consecutive ballano di ±10 ms, e infatti una prima lettura attribuiva
  **14.6 ms** a un difetto che, cronometrato sulla riga, ne costa **0.28**;
  la classifica per nodo dava «+10 ms» perfino a chi in `_process` non fa
  nulla. Se le differenze che cerchi sono dell'ordine del rumore, la misura
  non è pronta: **cronometra la riga** (`Time.get_ticks_usec()` attorno alla
  chiamata sospetta, una volta per fotogramma) invece dei fotogrammi.
- `CHIBI_FPS_SONDA=1` aggiunge un nodo che fa **solo** la chiamata sospetta,
  un fotogramma per volta: è il difetto in provetta, e dice quanto costa
  quella riga e nient'altro.
- `CHIBI_FPS_DIAGNOSI=1` chiede prima **pixel o codice** (si rimpicciolisce
  la finestra: se i fotogrammi volano, il collo di bottiglia è nel disegno)
  e poi spegne il `_process` di un figlio del livello per volta.
