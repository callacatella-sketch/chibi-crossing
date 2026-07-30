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

**Le regole che lo tengono in piedi** (guardia:
[`tests/cases/test_menu_vivo.gd`](tests/cases/test_menu_vivo.gd)):

- **Il lutto sta sopra tutto.** Un villaggio pieno di amici che ha perso
  qualcuno ieri deve avere il menù grigio: se la statistica dell'allegria
  coprisse il lutto sarebbe la cosa più fredda che il gioco possa fare.
  Passati i giorni, il menù torna a colori — non dimentica, ricomincia a
  respirare.
- **Il lutto si dice TOGLIENDO, non spegnendo.** Si abbassa la
  *saturazione*, non la luce (un menù al buio è rotto, non triste), e i
  mestieri allegri spariscono: nel lutto nessuno si rincorre.
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
  `Visitors._residents`, da cui i partiti sono stati tolti). Dentro il sogno
  il filo si annoda a mano con `FiloRosso.annoda(a, b, …)`.
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
- Convenzioni per nuovi test: file `tests/cases/test_<area>.gd`, `extends
  RefCounted`, niente `add_child` all'albero (le classi C++ si creano con
  `.new()` e si liberano con `.free()`); usa `var x = ...` (non `:=`) quando il
  valore viene da un'istanza non tipizzata, altrimenti l'inferenza fallisce.
