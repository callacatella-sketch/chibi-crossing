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

## ⚜️ REGOLA SACRA: il GENERE viene prima dell'idea — nessun agente devia

**Chibi Crossing è un gioco COZY, e prima di tutto un posto dove si torna
volentieri.** Questa non è una preferenza estetica: è la promessa che il
gioco fa a chi lo apre. Un'idea che sarebbe geniale in un altro gioco, qui,
**è sbagliata** — e non «sbagliata ma interessante»: sbagliata e basta.

L'errore da cui questa regola nasce ha un nome preciso, ed è il più comune
nei sistemi complessi: **slegare un sistema dai vincoli del suo genere per
mostrare quanto è intelligente.** Un sistema che dimostra la propria
sofisticazione a spese del genere non è intelligente — è fuori posto. Il
villaggio è un simulatore di personalità *psicologico*, sì, ma di persone che
si vogliono bene.

### IL COLLAUDO, e si applica PRIMA di scrivere una riga

Tre domande. Se una sola risposta è «no», l'idea non entra come sta:

1. **Il giocatore può rimediare?** Ogni ferita di questo gioco ha *una chiave
   a forma di giocatore* (è la regola 1 degli Affetti). Un danno che il
   giocatore non può riparare — perché non l'ha causato, o perché non esiste
   il gesto che lo ripara — non è profondità: è impotenza.
2. **Il gioco accusa qualcuno?** Nessun giudizio su una persona, nessuna
   classifica, nessuna colpa attribuita. «Il gioco non dice mai chi ha
   sbagliato» non vale solo per gli Affetti: vale per tutto.
3. **Il villaggio resta un posto dove si sta bene?** Si può stare da soli
   senza essere puniti; nessuno ti orbita attorno; nessuno ti guarda storto.
   Un gioco cozy in cui non si può stare in pace è un incubo — e ci si
   arriva **tarando bene un sistema progettato male**.

### E LA COSA CHE SI FA INVECE DI RIFIUTARE

Quasi sempre l'idea ha un nucleo buono e una veste tossica. **Non si butta:
si trova la versione che sta sui binari.** È già successo tre volte, e ogni
volta la versione salvata era *migliore* dell'originale:

| l'idea, come nasce | perché non entra | la versione che sta sui binari |
|---|---|---|
| i sogni che diventano ricordi veri: un vicino «ricorda» che gli hai rubato una mela | colpa falsa, inattribuibile, **senza chiave**; ed è la gogna che `Animo.senti_dire()` esiste per impedire | il sogno produce una credenza **sul mondo, non su una persona**: sogna un pesce nello stagno che non c'è, e va a guardare |
| gli abitanti che **mentono** per danneggiare un rivale | idem, più una meccanica investigativa in un gioco che serve a stare tranquilli | **l'errore onesto**: la voce si deforma viaggiando perché la memoria decade (il grafo già smorza e azzera il soggetto). Stessa texture, nessuno è cattivo |
| le **fazioni per inimicizia** (A odia B, l'amico di A diffida di B) | «A odia B» non esiste in questo gioco, e le fazioni sono una classifica resa sociale | le **cricche per affinità**: chi passa tempo con chi. Stessa struttura visibile, e più bella: ti accorgi che due si sono trovati |

*La differenza fra un villaggio dove la gente si sbaglia e un villaggio dove
la gente è crudele è tutta la differenza fra cozy e non.*

### PER OGNI AGENTE CHE LEGGE

**Segui i binari anche quando l'idea tira dall'altra parte** — anche quando
è tua, anche quando è brillante, anche quando te l'ha chiesta qualcuno.
Se ti accorgi che un compito ti sta portando fuori genere: **non eseguirlo in
silenzio e non rifiutarlo**. Dillo, spiega quale delle tre domande fallisce, e
proponi la versione che sta sui binari. Poi decide l'autore.

E una nota di scala: questa regola sta **sopra** ogni consegna tecnica. Una
funzione che rispetta la specifica e rovina il gioco ha fallito.

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
- **La release compila il cuore con `llm=yes`**, su tutte e due le piattaforme
  e su tutti e due i target. Non è un dettaglio di build: la classe nativa
  `LlmLocale` esiste solo così, e senza di lei `Llm.disponibile()` è falsa per
  chiunque installi il gioco — la casella «Il villaggio pensa» non compare, il
  modello non viene mai scaricato, e **la Fase 5 è morta in silenzio**. Il
  sottomodulo `src/thirdparty/llama.cpp` entra nel checkout, `ninja` si
  installa (senza, su Windows CMake sceglierebbe il generatore Visual Studio,
  che porta un toolset diverso da quello di SCons) e la compilazione di ggml si
  tiene da parte con **la stessa chiave di cache di `build.yml`** — un tag
  riusa quel che `build.yml` ha già pagato su `main`, e chi cambia la chiave di
  qua e non di là fa pagare venti minuti in più a ogni tag, in silenzio.
  ⚠️ **Il CRT su Windows NON si passa**: il nostro ramo `win32` non dà né `/MD`
  né `/MT`, quindi `cl.exe` usa il runtime C statico — la stessa scelta di
  godot-cpp — e lo SConstruct lo dice già a CMake (`llm_msvc_crt`, di serie
  `MultiThreaded`). `llm_msvc_crt=MultiThreadedDLL` è il RIMEDIO se il link
  muore con LNK2038, non una precauzione da prendere prima: scritto a priori,
  crea proprio lo scontro che dovrebbe evitare.
- **Il modello NON viaggia nel pacchetto** (decisione dell'autore, 2026-08-13):
  se lo scarica il gioco al primo uso. Il `curl` che lo metteva dentro non c'è
  più, e con lui il cancello dei 2 GiB di GitHub. Restano **tre** cancelli, e
  sono l'unico posto in cui il silenzio della Fase 5 si può rompere: il
  preflight interroga la sorgente con una `HEAD` **senza token** (chi gioca non
  ce l'ha: una CI che passasse grazie a un token direbbe di sì proprio quando
  tutti sono rotti) e confronta `x-linked-etag`/`x-linked-size` con
  `Llm.IMPRONTA_SPEDITO`/`Llm.BYTE_MODELLO`; i due job che compilano
  interrogano il **binario**; il job che pubblica apre i **pacchetti veri** e
  ripete la domanda alla libreria che riceve chi gioca. E il cancello delle
  licenze non ha più l'elenco scritto a mano: l'elenco è `misc/licenze/*.txt`,
  perché quattro nomi ricopiati erano una tabella gemella che divergeva in
  silenzio il giorno in cui gli avvisi si rivedono.
- **I cancelli della release si provano SENZA aspettare un tag**:
  [`tools/prova_release.py`](tools/prova_release.py) estrae gli script dal
  workflow vero (non li ricopia), li fa girare su pacchetti fabbricati e poi
  guasta una cosa per volta pretendendo il rosso GIUSTO — messaggio compreso,
  perché un cancello che rifiuta tutto sarebbe verde qui e inutile in partita.
  Ha trovato, fra le altre cose, dei backtick vivi dentro un messaggio d'errore
  (facevano partire un `sed` senza argomenti: legge stdin, e il passo si
  piantava per sempre) che `bash -n` non poteva vedere. Con `--rete` interroga
  anche la sorgente vera, con una `HEAD`.
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

## REGOLA: la Stratigrafia — il salvataggio come sito archeologico

Il prato ricorda in profondità ([`scenes/world/Strati.gd`](scenes/world/Strati.gd),
nodo nel MainLevel, gruppi `persistable` + `strati`): ciò che il giocatore
DEMOLISCE lascia un reperto sepolto nella cella; chi PARTE per sempre
sotterra un oggettino vicino a casa (scelto dal carattere: quirk → mestiere
→ indole); le STAGIONI depositano di rado un segno. Li riporta alla luce il
verbo che esiste già — i luccichii di Scavi: ogni tanto uno nasce sopra uno
strato, e quel giorno il trovamento È il reperto (che finisce nelle Tasche
come tesoro, e per i ricordi scrive il momento «reperto» sul filo del
partito e può riaffiorare nei Sogni).

Le regole che NON si negoziano:

1. **Seppellisce solo il GIOCATORE.** L'hook vive in `_try_remove()` (con
   la cintura `_loading`), MAI in `_remove_at`: `debug_clear`,
   `debug_remove_edge` e i caricamenti non lasciano strati — o il
   pulisci-tutto dell'harness seppellirebbe un villaggio intero.
2. **Il ledger è JSON-safe GIÀ IN RAM** (`cella` = `[x, z]`, mai Vector2i)
   e si legge con `int()`: gli interi tornano float dal disco.
3. **La potatura protegge i ricordi**: cap `MAX_STRATI`, si lascia andare
   prima stagione, poi demolizione, poi (mai, finché si può) i ricordi.
4. **Determinismo nel giorno**: per i luccichii contano solo strati con
   `g < oggi` — una demolizione a metà giornata NON cambia i punti già
   nati. Semi da `hash()` stabili, mai da `get_instance_id()`.
5. **Chiave = NOME del DNA** (le due anagrafi): il momento «reperto» va sul
   filo col nome; la label è solo per il toast.
6. **`estratto` si marca SUBITO**, prima dell'animazione: salvare a metà
   scavata non duplica il reperto né lo perde.
7. **Cozy**: niente rovine in superficie, niente pannelli, niente annunci.
   Il silenzio è il comportamento normale (`PROB_AFFIORA`), e il reperto di
   chi è partito è tenerezza, mai colpa.
8. **Ciclo di preload**: Strati precarica Scavi (fonte unica di RECT);
   Scavi NON deve mai precaricare Strati (lo trova nel gruppo) o il parse
   muore in silenzio nei test headless.

Guardie: [`tests/cases/test_strati.gd`](tests/cases/test_strati.gd) (977
righe, coi test che SANNO fallire: mutare `g < oggi` in `g <= oggi` accende
10 rossi). Prova viva: `tools/prova_strati.gd` (MainLevel vero, exit 0).
Provino visivo: `CHIBI_STRATI=<dir> Godot --path . --script
res://tools/provino_strati.gd`.

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

## FASE 5 — il cuore che scrive (llama.cpp), e la leva del giocatore

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
10. **Su Windows il link vuole `advapi32`, e a monte non si vede.** `ggml-cpu`
   legge il nome della CPU dal REGISTRO (`RegOpenKeyEx`/`RegQueryValueExA`/
   `RegCloseKey`, in `ggml-cpu.cpp`). llama.cpp si linka con CMake, che passa a
   MSVC una lista di librerie di sistema di serie (`CMAKE_C_STANDARD_LIBRARIES`,
   dove `advapi32` c'è); il nostro ramo `win32` costruisce la riga di link **a
   mano** e quella lista non ce l'ha. MISURATO in CI (`build.yml`, job
   *Compila con llama.cpp (windows)*, run 31681424170): tre `LNK2019` e poi
   `LNK1120`. Adesso `_llm_cabla` lo aggiunge. ⚠️ E NON era il CRT — il
   sospettato numero uno di questo ramo: il link era arrivato fino in fondo,
   quindi le due metà avevano già lo stesso runtime C (`/MT` da tutte e due le
   parti, che è il default di `cl.exe` e la scelta di `llm_msvc_crt`).
11. **Su Linux `std::strtoull` vuole `<cstdlib>`**, e da un Mac non si vede:
   libc++ lo tira dentro per conto suo, libstdc++ no. `src/llm_memoria.cpp` lo
   usa per leggere `/proc/meminfo` e non lo includeva — il job *Compila con
   llama.cpp (linux)* moriva con «'strtoull' is not a member of 'std'». È la
   forma generale della regola: **una build che compila solo dove la scrivi non
   è compilata**, e il giudice è la CI su tutti e tre i sistemi.

**Come si verifica** (la suite verde non dice niente sul terreno):

- `build.yml` ha un job **`build-llm`** che compila con `llm=yes` su tutti e
  tre i sistemi (con cache della build di ggml: la prima volta è lunga, poi no);
- `tests.yml` ha un job **`test-llm`** che fa girare **la stessa suite** sul
  cuore con llama dentro. È il gemello che nessuno guarda mai: «funziona
  identico senza» ha senso solo se qualcuno prova anche «e identico con»;
- in locale, l'impronta: con `llm=no` il binario dev'essere **byte per byte**
  quello di prima (`shasum -a 256 bin/*.dylib` prima e dopo).

### IL PORTIERE — il file si guarda PRIMA che lo guardi llama

Il punto 6 qui sopra («ggml ABORTISCE il processo, e non c'è callback») non è
più un residuo generico: è stato **misurato**, e la parte che si poteva
chiudere è chiusa. Il pezzo è [`src/llm_gguf.{h,cpp}`](src/llm_gguf.h) —
legge il `.gguf` per conto suo, con un controllo di limite su ogni campo, e
dice di no **senza che llama lo abbia mai aperto**. Sta davanti all'unico
caricamento che esiste (`Traduttore::_carica`, sul thread: il frame non paga
niente) e costa **45–184 ms** su un modello vero.

**Cosa succede DAVVERO a un file guasto** (b10326, misurato su
gemma-3-1b con [`tools/rovina_gguf.py`](tools/rovina_gguf.py), che fabbrica
quindici guasti e per ognuno chiede a due processi diversi cosa ne pensano il
portiere e llama da sola):

| guasto | llama da sola | portiere |
|---|---|---|
| `general.alignment` col tipo sbagliato | **MORTO — abort()** | rifiutato |
| `tokenizer.ggml.token_type` come f32 | **accettato**, tokenizzatore corrotto in silenzio | rifiutato |
| `tokenizer.ggml.scores` come i32 | **accettato**, idem | rifiutato |
| troncato (1 byte o 8 MB), firma, tipi, offset, dimensione a zero… (11 casi) | rifiutato pulito | rifiutato |
| un bit girato dentro i pesi | accettato | accettato |

Le tre righe che contano:

1. **L'unico `abort()` che sono riuscito a raggiungere è
   `general.alignment`**, e non è in llama: è in **ggml**.
   `gguf_init_from_file` lo legge con `gguf_get_val_u32`, che dentro fa
   `GGML_ASSERT(tipo == u32)`. Tutti gli altri metadati passano dal ramo di
   llama (`GKV::get_kv`), che **tira un'eccezione** — e un'eccezione il gioco
   la vede come «modello non caricato», che è sano. Un byte cambiato lì
   dentro è il processo che muore.
   ⚠️ «Che sono riuscito a raggiungere» è la formulazione onesta: sono quindici
   guasti fabbricati a mano, non una dimostrazione. Gli iperparametri hanno
   invarianti che nessun controllo di forma può dedurre
   (`GGML_ASSERT(n_expert_used > 0)` e compagnia), e contro quelle c'è solo
   l'impronta.
2. **Due guasti llama non li vede affatto.** Gli elenchi del tokenizzatore li
   legge con un cast crudo (`(const float *) gguf_get_arr_data`,
   llama-vocab.cpp:2419): con il tipo sbagliato non c'è né errore né abort —
   c'è un tokenizzatore che legge spazzatura. È il guasto peggiore da
   diagnosticare, ed è il motivo per cui il portiere ha una tabella di attese
   sui **soli** elenchi che llama legge così.
3. **Il resto di llama è più robusto di quanto la nota vecchia temesse.** Su
   quindici guasti, undici li rifiuta pulito. Il portiere quindi non serve a
   «salvare il gioco da llama»: serve a chiudere i due buchi veri, a dire di
   no **prima** (con una frase in italiano invece che con un `nullptr`), e a
   fare da posto dove mettere il tetto di RAM.

**Il residuo, dichiarato:** un bit girato dentro i pesi non lo vede nessuno
dei due. Contro quello c'è **solo l'impronta**, e dal **2026-08-13 È ACCESA**:
`Config::impronta_attesa` fa rifiutare il file che non combacia, la costante
vive in `Llm.IMPRONTA_SPEDITO`, e `Llm.impronta_attesa(percorso)` la arma
**solo sul modello che spediamo** — dei tre candidati è l'unico di cui
conosciamo i byte. Costa una lettura completa del file (misurata: 12 s a
priorità normale e ≈37 s alla priorità di fondo che usa il gioco), e per
questo è l'**ultimo** dei quattro cancelli invece del primo. Il quadro
completo, coi numeri e con l'ordine, sta in «IL MODELLO CHE SPEDIAMO».

**E il PROCESSO SEPARATO?** Valutato e **non fatto**, con la misura in mano:
l'unica famiglia di abort raggiungibile è chiusa dal portiere, un helper
eseguibile andrebbe compilato, impacchettato, firmato e notarizzato su due
piattaforme (e su Windows non è verificabile da qui), e `fork()` senza `exec`
dentro un processo Godot con audio e Objective-C vivi è il rimedio che
introduce il guasto che dovrebbe curare. Se un domani si volesse davvero,
la strada onesta è un eseguibile suo con IPC — non una fork.

### LA FINESTRA DI `annulla()`, e le tre uscite

Due difetti di concorrenza, tutti e due muti, tutti e due riprodotti prima di
essere corretti. Il banco è [`tools/prova_concorrenza.cpp`](tools/prova_concorrenza.cpp)
(eseguibile a parte, come `portiere_vs_llama.cpp`: serve un `Traduttore` vero,
un modello vero e il controllo dei microsecondi) e
[`tools/prova_uscita.gd`](tools/prova_uscita.gd) (il gioco vero che se ne va).

**1. IL VILLAGGIO AMMUTOLIVA PER SEMPRE, IN SILENZIO.** `accoda()` accende
`_in_volo` mettendo in coda; a spegnerlo c'era **un posto solo**, la fine di un
lavoro ESEGUITO. Fra la coda e il prelievo del thread passa però un tempo
vero — misurato: **mediana 27 µs** a macchina scarica (min 12, max 34), e
**mediana 5.7 ms con punte di 24 ms** a carico 37, cioè proprio quando il
modello sta generando, che è quando la macchina è carica. Un `annulla()` che
prendeva il lucchetto lì dentro buttava la coda: quel lavoro non esisteva più,
nessuno l'avrebbe finito, `_in_volo` restava acceso **per sempre** →
`libero()` falso per sempre → `accoda()` che rifiuta tutto per il resto del
processo. Riprodotto al primo giro. E il corollario era altrettanto muto:
nella stessa finestra si alzava `g_abbandoni` e non la riabbassava nessuno,
quindi **ogni** errore di llama restava declassato — si spegneva la rete.

La cura è sapere **di chi è** il lavoro, e si sa solo sotto il lucchetto:
`_preso` lo accende il thread nello stesso istante in cui toglie la richiesta
dalla coda, e l'epilogo del thread sta tutto sotto un lucchetto solo (deve
essere indivisibile rispetto ad `annulla()`, o i due rami di là guarderebbero
uno stato a metà). Dopo: **8 giri su 8** con annullamento a distanza zero, il
motore libero in 0 ms, il pensiero dopo che arriva sempre, la finestra del
silenzio che si apre solo durante una generazione VERA e si richiude quando
llama molla.

**2. AL CAMBIO DI SCENA NON FERMAVA NIENTE NESSUNO.** Le due uscite che la
documentazione dava per esistenti erano rotte tutte e due: `Pensatoio._exit_tree`
**non può esistere** (è un `RefCounted`, non sta nell'albero) e `annulla()`
«si chiama al cambio di scena» non la chiamava nessuno. Misurato: lasciando
cadere ogni riferimento, il thread continuava a scrivere **quaranta secondi**,
cioè fino alla fine della generazione, mentre il gioco caricava un'altra
scena. Adesso le uscite sono tre e nessuna chiede di ricordarsi niente:

| uscita | chi la tira | misurato |
|---|---|---|
| muore l'ULTIMO maniglione (`~LlmLocale`) | il cambio di scena, il ritorno al titolo | 40 s → **6 ms** |
| muore il Pensatoio (`NOTIFICATION_PREDELETE`) | chi ospita il ritmo se ne va | 40 s → **35 ms** |
| si scarica la GDExtension (`register_types.cpp`) | la chiusura del gioco | **funzionava**: sonda temporanea su stderr, terminatore chiamato ai livelli 3·2·1·0, `spegni_tutto` al livello SCENE, processo chiuso in 2.4 s mentre generava |

L'ULTIMO maniglione e non ognuno: `Llm.apri()` ne torna uno nuovo a ogni
chiamata e ce n'è di usa-e-getta (`Llm.riga_di_stato()`) — se ogni distruttore
buttasse il volo, stampare una riga di diagnostica ucciderebbe il pensiero di
un vicino. E si annulla, **non** si chiude: `chiudi()` libera il modello, e
riaprire due gigabyte e mezzo a ogni cambio di scena sarebbe la cura peggiore
della malattia.

> ⚠️ **TRAPPOLA DI GODOT, misurata (4.7.1): dentro `NOTIFICATION_PREDELETE` i
> PROPRI metodi non si possono chiamare.** I campi si leggono ancora e i
> metodi degli ALTRI oggetti si chiamano, ma `svuota()` — un metodo di sé
> stessi — dà «Attempt to call function … in base 'null instance'», che in
> questo runner è un `SCRIPT ERROR` che **non fa fallire niente**: il
> Pensatoio si portava dietro un errore rosso e nessun annullamento. Il gesto
> vive perciò in una funzione **statica** (`Pensatoio.butta_il_volo`), che
> sta sullo script e non sull'istanza.

> ⚠️ **E IL DOPPIO MENTIVA — al contrario.** `MotoreFinto.annulla()` faceva
> `occupato = false` **sempre**: implementava il comportamento giusto che il
> C++ non aveva, quindi nessun test poteva vedere il difetto. Adesso il finto
> sa la cosa che il vero sa (un lavoro può essere in coda o già in mano a chi
> scrive: `prende()` / `molla()`) e il caso che ne è nato è rosso appena si
> tocca la riga che sorveglia. **Un doppio che mente è peggio di nessun
> doppio: nessun doppio ti fa scrivere un test vero, uno che mente ti fa
> credere di averlo già scritto.**

> ### ⚠️ E LA CURA NON ERA PROVATA DA NIENTE — il BANCO DELLA CONCORRENZA
>
> Riparare il doppio ha reso provabile il **Pensatoio**, non il **motore**.
> MISURATO il 2026-08-12, togliendo dal C++ una per volta le due righe che
> curano il difetto qui sopra — `_in_volo.store(false)` dal ramo «era ancora
> in coda» di `annulla()`, e `_preso = true` dal prologo di chi scrive — e
> rifacendo la suite intera: **63942 passati, 0 falliti** tutte e due le
> volte. L'unico giudice era `prova_concorrenza.cpp`, che vuole due gigabyte
> di pesi e un eseguibile compilato a mano: non gira in nessuna suite, non
> gira in CI.
>
> Adesso il difetto si vede **senza modello e senza thread**, in
> [`tests/cases/test_llm_banco.gd`](tests/cases/test_llm_banco.gd). La chiave
> è che **il difetto non è di tempistica: è una transizione di stato che
> nessuno gestiva**, e il tempo decideva solo quanto spesso ci si cascava.
> Perciò non si cerca di infilarsi in una finestra da 27 µs da GDScript (un
> test che passa *quasi* sempre non dice niente): si toglie di mezzo **il
> lavoro**, e si muove la richiesta a mano attraverso le funzioni VERE —
> `accoda()`, `annulla()`, `_prendi_lavoro()`, `_epilogo()`, chiamate dagli
> stessi posti e sotto lo stesso lucchetto (`Traduttore::banco_*`,
> `LlmLocale.banco_*`).
>
> **È l'opposto di un doppio**: un doppio reimplementa la cosa da provare;
> qui non si reimplementa niente, si toglie la cosa che non c'entra. Il
> prologo e l'epilogo sono stati estratti in due funzioni proprio perché
> hanno due chiamanti — ricopiarli nel banco sarebbe stato rifare, in
> piccolo, il difetto del `MotoreFinto`.
>
> **Tre regole per chi ci mette le mani:**
> 1. il banco **non inventa una parola**: il testo dell'esito lo passa chi
>    prova, e `banco_accendi()` rifiuta un traduttore già acceso;
> 2. è un `Traduttore` **del maniglione**, non quello del processo — se
>    accendesse il singleton, tutti i casi successivi della suite si
>    troverebbero un motore che non hanno chiesto (`test_pensatoio` pretende,
>    giustamente, di trovarlo SPENTO);
> 3. **nel gioco non lo chiama nessuno**, e un caso del file scandaglia
>    `scenes/` e `systems/` perché resti così. Quel caso gira anche nel
>    binario senza llama, che è l'unico che la CI normale compila.
>
> VERIFICATO che i due banchi vedono **la stessa cosa**: sulla stessa
> mutazione, `prova_concorrenza annulla <gguf> 0 8` dice «libero dopo MAI ·
> pensiero PERSO · appesi 1» e la suite diventa rossa in tre asserzioni. E
> le sei mutazioni provate una per una (le due righe della cura, la guardia
> che alza la finestra del silenzio una volta sola, l'esito vuoto che si
> consegna lo stesso, la finestra richiusa da `chiudi()` senza thread) danno
> 3 · 8 · 2 · 3 · 1 asserzioni rosse. La sesta — un `chiudi()` scritto a mano
> nel distruttore del ponte — non è arrossita **perché era ridondante**
> (`~Traduttore` lo chiama già): è stata tolta, che è quello che si fa con
> una guardia che nessun test può far fallire.
>
> Il rifacimento è stato riprovato **col modello vero**:
> `prova_uscita.gd` dà di nuovo 5 ms e 29 ms sulle prime due uscite, e
> `prova_concorrenza annulla` 8 giri su 8 con zero appesi.

**E le quattro righe per abbandono.** Quando `abort_callback` ferma
`llama_decode` a metà, llama stampa quattro righe (misurate una per una: tre
ERROR e una WARN). Prima venivano declassate ad avviso; adesso che le uscite
funzionano davvero, un abbandono capita a **ogni cambio di scena**, e quattro
avvisi per cambio di scena insegnano a non leggere gli avvisi — lo stesso
guasto di prima, un gradino più in basso. Dentro la finestra dell'abbandono
quindi non si stampa: si **conta** (`misure()["righe_zittite"]`), perché un
rumore che nessuno misura è un rumore che cresce. Fuori da quella finestra un
errore di llama resta un errore, e si vede.

### Il tetto dei 3 GB, e la RAM che la macchina ha DAVVERO

Il tetto è dell'autore e dal **2026-08-12 vale 3 GB** (erano 2). La ragione è
una misura, non un ripensamento: sotto i 2 GB, con questa quantizzazione, ci
stava **solo** un modello da un miliardo di parametri — e col 1B ventuno
lettere su ventiquattro erano rotte. A 3072 MB ci stanno tutti e due i modelli
che il provino aveva trovato ONESTI (zero invenzioni su quindici):
gemma-3-4b e gemma-4-E2B.

`stima_byte_totali()` (pesi + cache di attenzione alla finestra scelta) lo
dice **prima** di allocare, e `Config::tetto_byte` fa rifiutare il modello che
lo sfonda. Il numero vero, dopo il carico, lo dà `LlmLocale.memoria()` letto
da dentro il processo — **mai `ps rss`**, che su macOS conta male le pagine
mappate da file (su gemma-3-1b dichiara 1947 MB dove l'impronta fisica ne
dice 1301).

| modello | sul disco | stima a 1024 | a 2048 | a 4096 | ci sta (2048)? |
|---|---|---|---|---|---|
| gemma-3-1b Q4_K_M | 769 MB | 788 MB | **814 MB** | 866 MB | sì |
| llama-3.2-3b Q4_K_M | 1926 MB | 2030 MB | 2142 MB | 2366 MB | sì |
| gemma-3-4b Q4_K_M | 2374 MB | 2504 MB | **2640 MB** | 2912 MB | sì |
| qwen-3.5-4b Q4_K_M | 2582 MB | 2700 MB | 2828 MB | 3084 MB | sì (a 4096 no) |
| gemma-4-E2B Q4_0 | 2710 MB | 2765 MB | **2835 MB** | 2975 MB | sì |

**⚠️ MA IL TETTO DA SOLO È MEZZA DIFESA, e la metà che manca è quella che si
vede.** Il tetto dice quanto costa il MODELLO; non dice se quei byte la
macchina ce li ha. Misurato su questo Mac da 8 GB con altri lavori aperti:
con **1781 MB liberi**, aprire gemma-3-4b (2640 MB) col MainLevel acceso ha
mandato la macchina in swap — **più di cinque minuti di caricamento**, carico
medio da 4 a 30, swap da 3.5 a 4.8 GB. Il giocatore non ha modo di collegare
quel singhiozzo a una funzione facoltativa che non ha chiesto: vedrebbe solo
un gioco che si è rotto.

Perciò il portiere adesso guarda anche **la RAM DISPONIBILE della macchina**
(`Config::riserva_byte`, di serie 1 GB) e, se dopo il carico al gioco non ne
resterebbe abbastanza, **il modello non si apre**: la funzione si spegne da
sola, il gioco resta identico, le lettere scritte a mano ci sono. Il numero
non è a occhio — è quello che il gioco ANCORA CHIEDERÀ dopo che il modello è
aperto: il MainLevel con ventotto residenti costa ~700 MB (e il modello si
apre prima che il mondo esista) più la cache di attenzione che cresce
generando e non torna indietro (+166 MB misurati su gemma-3-1b dopo cinque
bozze).

Come si legge la RAM, piattaforma per piattaforma
([`src/llm_memoria.cpp`](src/llm_memoria.cpp)):

| | totale | disponibile |
|---|---|---|
| macOS | `sysctl hw.memsize` | `host_statistics64`: libere + inattive + eliminabili (**non** `external`, che è già dentro le altre: contarlo due volte direbbe più memoria di quanta ce n'è) |
| Linux | `MemTotal` | `MemAvailable` (la stima del kernel; se manca, `MemFree`, che sottostima — il verso giusto) |
| Windows | `GlobalMemoryStatusEx().ullTotalPhys` | `ullAvailPhys`. Sta in kernel32, già linkata: nessuna libreria in più (per questo qui c'è Windows e in `memoria_impronta()` no, dove servirebbe psapi). **Non verificabile da un Mac: il giudice è la CI.** |

**Zero vuol dire «non lo so», e «non lo so» non è mai un no**: se la
piattaforma non sa rispondere si passa oltre. Spegnere una funzione per un
numero che non abbiamo sarebbe il degrado dalla parte sbagliata.

**E il tetto non si ricopia**: vive in `chibi::Config` e il ponte lo racconta
con `LlmLocale.limiti()`. `tools/sonda_llm.gd` lo scriveva a mano (2 GB) ed
era già diverso da quello del gioco — un provino che confronta un modello con
un tetto sbagliato non è un provino, è un secondo tetto.

### Il prezzo, e cosa NON è misurato

Con `tools/sonda_llm.gd` (gemma-3-1b, finestra 2048, prompt vero da 607
gettoni, grammatica vera):

| | lettura del prompt | scrittura |
|---|---|---|
| priorità 0 (core normali) | 148.7 gettoni/s | 4.4 gettoni/s |
| priorità 2 (core di efficienza, il valore di serie) | 36.9 gettoni/s | 1.1 gettoni/s |

Il carico del modello: **1.4 s** con la cache del disco calda, **5 s**
fredda, e fino a **11 s** con la macchina occupata — sempre sul thread, con
il gioco che continua a disegnare.

**Due cose vanno sapute prima di credere a questi numeri.**

1. **Scrivere è trentaquattro volte più lento che leggere**, e non è il
   modello: è il **vocabolario di gemma-3, 262.144 parole**. Ogni gettone
   scritto costa una passata su tutte per campionare. Misurato con
   `portiere_vs_llama campionatori`: la grammatica in testa alla catena
   raddoppia il tempo per gettone e si prende il 27% del totale.
   **Ma la grammatica non si tocca** (senza, il 27% delle citazioni è
   inventato): la manopola giusta, semmai, è il vocabolario del modello che
   si sceglie.
2. **⚠️ E l'ordine della catena non è una questione di velocità.** Mettere la
   grammatica DOPO `top_k` la fa costare quasi niente — e fa **morire il
   processo**: se tutti i candidati rimasti sono vietati, il dado ne sceglie
   uno comunque e il passo dopo llama tira `Unexpected empty grammar stack
   after accepting piece`. Riprodotto in dieci secondi. Da lì viene
   `Traduttore::_riparata`, l'ombrello che trasforma una qualunque eccezione
   di llama in un pensiero perso invece che in un gioco chiuso: **un'eccezione
   che esce dalla funzione di un `std::thread` è `std::terminate`**, e prima
   non c'era nessun `try` su quel cammino.

**Cosa non è misurato, ed è onesto dirlo:** la generazione **col gioco
acceso** non ha un numero affidabile. Il Mac su cui è stata fatta questa
tornata è a 8 core e 8 GB, e per tutta la durata delle prove aveva **altri
agenti che compilavano e misuravano sopra** (carico medio fra 9 e 42, un
secondo Godot al 210% di CPU con 2.2 GB residenti). I gettoni al secondo qui
sopra sono perciò **un pavimento**, non una misura: vanno rifatti su una
macchina ferma, ed è la prima cosa da fare prima di scegliere il modello.

### I DUE CANDIDATI DEL 3B, misurati dal vivo (2026-08-12)

Stessa macchina (M1, 8 GB), stesso prompt vero (651–659 gettoni), finestra
2048, priorità 1, cinque bozze. **Ogni riga porta il carico della macchina,
perché senza quello non vuol dire niente**: questi sono pavimenti, non
misure pulite.

| modello | carico | impronta VERA | prompt | uscita | loadavg · swap |
|---|---|---|---|---|---|
| gemma-3-1b Q4_K_M | 54 s | 620 MB | 22.3 g/s | 1.1 g/s | 26 · 5.2 GB |
| gemma-3-4b Q4_K_M | 47 s | **2745 MB** | 18–32 g/s | **4.0–4.7 g/s** | 14 · 4.6 GB |
| gemma-3-4b (secondo giro) | 39 s | 2773 MB | 9.2 g/s | **0.2 g/s** | 12 · 4.2 GB |
| gemma-4-E2B Q4_0 | 20 s | **1649 MB** | 24.8 g/s | 1.7 g/s | 5 · 2.9 GB |
| gemma-3-4b, senza gioco e senza swap | 33 s | 2760 → 2849 dopo aver scritto | | | 15 · — |

**Tre cose che questa tabella dice e la tabella delle stime non poteva
dire:**

1. **La stima SBAGLIA di brutto su gemma-4-E2B, e in nostro favore**: stima
   2835 MB, impronta vera **1649**. È un modello «E2B» — due miliardi di
   parametri *attivi* su un file da 2.7 GB — e la stima, che parte dalla
   dimensione del file, conta pesi che non vengono mai toccati. Sul 4B
   normale invece la stima è quasi esatta (2640 stimati, 2745 veri).
   **Su una macchina da 8 GB questo cambia la classifica**: E2B costa un
   gigabyte in meno del 4B, non duecento megabyte in più.
2. **Il 4B è più veloce a scrivere di E2B** (4.0–4.7 contro 1.7 g/s), e a
   scrivere è dove il tempo si spende. Le due righe del 4B però differiscono
   di **venticinque volte** fra loro con la stessa configurazione: la
   variabile non è la CPU (carico 14 contro 12) ma la **memoria** — nel
   secondo giro lo swap era a 4.2 GB con 881 MB liberi, e ogni gettone
   toccava pesi che il sistema aveva paginato via. Quando la RAM non c'è, la
   funzione non degrada: **collassa** (una lettera in dieci minuti) e si
   porta dietro tutta la macchina. È esattamente il guasto che
   `riserva_byte` esiste per non far succedere.
3. **Il frame, invece, non se ne accorge.** Misurato nel MainLevel vero con
   ventotto residenti, a blocchi alternati (`tools/misura_pensieri.gd`,
   gemma-3-4b, finestra 2048):

   | | n | medio | p50 | p99 | MAX | frame > 2×p50 |
   |---|---|---|---|---|---|---|
   | motore spento | 1180 | 60.84 ms | 60.27 | 77.47 | 373.04 | 3 |
   | il villaggio pensa | 1200 | **59.88 ms** | 59.71 | 76.17 | **98.67** | **0** |

   Scarto sul frame medio **−0.96 ms (−1.6%)**: il cuore che scrive non si
   sente, e il frame peggiore è *migliore* col motore acceso (il picco da
   373 ms è caduto in un blocco spento — è la macchina, non noi). Anche
   durante il **caricamento** (70 s col gioco acceso, mentre la macchina
   swappava) il frame resta a 64.75 ms di media con tre soli frame oltre il
   doppio della mediana.

**La scelta, onestamente, non è ancora chiusa da questi numeri.** Il 4B
scrive più in fretta ma costa un gigabyte in più di RAM vera; E2B costa
poco e scrive piano. Su un Mac da 8 GB — che è la macchina dell'autore — il
4B col gioco acceso porta il processo a **3534 MB**, e il resto della
macchina se ne accorge. **Il pezzo che manca è di qualità, non di
prestazioni: quale dei due scrive lettere migliori** (le due righe libere,
non la grammatica). Quello lo dice il provino delle lettere, non questa
tabella.

**Come si guarda:**

```
CHIBI_MODELLI=<dir dei gguf> CHIBI_IMPRONTA=1 \
  Godot --headless --path . --script res://tools/sonda_llm.gd
CHIBI_MODELLO=<file.gguf> CHIBI_PROMPT=<dir> CHIBI_GIOCO=1 CHIBI_PRIORITA=0 \
  Godot --path . --script res://tools/sonda_llm.gd

clang++ -std=c++17 -fexceptions -O2 -DCHIBI_LLM -Isrc \
  -Isrc/thirdparty/llm-build/macos-universal/inst/include \
  tools/portiere_vs_llama.cpp src/llm_gguf.cpp \
  src/thirdparty/llm-build/macos-universal/inst/lib/lib{llama,ggml,ggml-cpu,ggml-blas,ggml-base}.a \
  -framework Accelerate -o /tmp/portiere_vs_llama
PORTIERE=/tmp/portiere_vs_llama python3 tools/rovina_gguf.py <modello.gguf>

# la CONCORRENZA (la finestra di annulla, la rete del silenzio): stesso
# schema, ma vogliono anche llm_pensieri.cpp e llm_memoria.cpp
clang++ … tools/prova_concorrenza.cpp src/llm_pensieri.cpp src/llm_gguf.cpp \
  src/llm_memoria.cpp … -o /tmp/prova_concorrenza
/tmp/prova_concorrenza finestra  <gguf> 30      # quanto dura la finestra
/tmp/prova_concorrenza annulla   <gguf> 0 8     # accoda+annulla dentro la finestra
/tmp/prova_concorrenza abbandono <gguf>         # la rete degli errori si richiude?

# le tre uscite, nel gioco vero
CHIBI_MODELLO=<file.gguf> Godot --headless --path . \
  --script res://tools/prova_uscita.gd

# il frame con ventotto residenti, a blocchi alternati (CHIBI_RISERVA=0
# spegne il cancello della RAM: un banco deve poter misurare anche il
# modello che il gioco rifiuterebbe)
CHIBI_MODELLO=<file.gguf> CHIBI_CTX=2048 CHIBI_RISERVA=0 \
  Godot --path . --script res://tools/misura_pensieri.gd
```

La guardia headless è
[`tests/cases/test_llm_portiere.gd`](tests/cases/test_llm_portiere.gd), e non
prova un modello vero (due gigabyte non stanno in CI): **si costruisce un
`.gguf` di trecento byte in GDScript e lo si rompe in quindici modi**,
pretendendo ogni volta il no GIUSTO — il motivo si legge, perché un portiere
che rifiuta tutto sarebbe verde qui e inutile in partita. Le cinque guardie
sono state **falsificate una per una** (spente nel sorgente, ricompilato,
riprovato): tolta la troncatura 3 asserzioni diventano rosse, tolto il tipo
dell'allineamento 4, tolte le attese sugli array 2, tolto `ne >= 1` 2, tolto
l'offset in fila 2. E l'ultima asserzione del file prova che il portiere sia
**davvero cablato** davanti al caricamento vero: togliendo la chiamata, il no
arriva da llama con un'altra frase e il caso diventa rosso.

**La rete: nessuna.** Verificato in tre modi — nella dylib non c'è **nessun
simbolo** di rete non risolto (`nm -u`: zero fra `socket`, `connect`,
`getaddrinfo`, `SSL_`, `curl_`, CFNetwork), le uniche librerie di sistema
linkate sono Accelerate, libc++ e libSystem, e negli archivi di llama.cpp non
c'è un solo simbolo di rete (`LLAMA_BUILD_COMMON=OFF` lascia fuori httplib e
curl). Dal vivo, `lsof -i` sul processo del gioco durante carico e generazione
dice **zero connessioni**.

### L'INJECTION — la deduzione entra nel mondo, e si VEDE prima di succedere

La terza consegna dell'autore: «l'LLM restituisce un JSON. Questo JSON viene
parsato dal C++ e trasformato in un nuovo nodo nel Knowledge Graph (una
deduzione astratta) o in un nuovo Obiettivo prioritario per il GOAP.» Sono
tutte e due le cose, e in quest'ordine: il nodo è la deduzione, l'obiettivo è
quello che produce — **ma solo dopo aver pagato la sua ricevuta.**

Il cammino, e ogni pezzo ha una casa sola:

| dove | cosa |
|---|---|
| [`Suggeritore.grammatica_deduzione()`](scenes/npc/Suggeritore.gd) | la grammatica GBNF del JSON, generata dalle enum |
| [`Giudice.utile()` / `scegli_deduzione()`](scenes/npc/Giudice.gd) | il collaudo e la scelta |
| [`Deduzioni.gd`](scenes/npc/Deduzioni.gd) | l'ufficio: incassa · ricevuta · dirottamento |
| [`src/grafo_deduzioni.{h,cpp}`](src/grafo_deduzioni.h) | il nodo, puro (quinto gemello) |
| `EcsMondo::deduci / deduzione_*` | il ponte |
| `Visitors._cuore_di` / `_gesti_agenda` | i due punti di cablaggio, due righe |

#### 1. Perché una deduzione NON è un `Ricordo`

La strada corta era una bandiera in più su una riga dell'anello dei
ventiquattro. Sarebbe stata la cosa peggiore di tutta la fase, per **tre**
strade indipendenti e tutte mute:

1. **`da_raccontare()` la prenderebbe** — un vicino andrebbe a raccontare a un
   altro una cosa mai successa, e l'eco la inciderebbe come `R_SENTITO` in un
   terzo: l'allucinazione propagata dal sistema che serve a propagare i fatti
   veri;
2. **`cosa_da_ricordare()` la promuoverebbe** — cioè finirebbe in
   `VillagerBrain.remember()`, che è **persistito**: una frase di un modello
   linguistico dentro `village.json`;
3. **`inserisci()` POTA PER PESO** — una deduzione forte scaccerebbe un
   ricordo vero. La macchina cancellerebbe quello che il giocatore ha fatto
   davvero per far posto a quello che si è immaginata.

Perciò le deduzioni stanno in un **array loro** (due slot per vicino). Non è
una potatura tarata bene: è una potatura che non le vede proprio. La domanda
dell'autore («senza che una deduzione possa scacciare un ricordo vero») ha
l'unica risposta che non dipende da un numero.

**E porta le COPIE dei suoi perché, non gli indici.** Un indice dentro
l'anello è la stessa trappola dell'handle nudo che `Ricordo.soggetto` ha già
pagato: l'anello ricicla gli slot, quindi la riga 3 di adesso non è la riga 3
di fra un minuto, e la deduzione comincerebbe a citare un altro gesto — in
silenzio, e solo in un villaggio dove il giocatore lavora molto, cioè dove
nessun collaudo arriva. La copia **non è un secondo orologio**: conserva il
`quando` originale e si legge con `chibi::peso`, la stessa funzione. È quello
che fa una citazione dentro una lettera del Gufo. Residuo dichiarato: una
deduzione può sopravvivere al ricordo che l'ha prodotta, ed è il verso giusto
— *la conclusione sopravvive al dettaglio, mai il contrario*.

**Il peso di una deduzione è quello del suo anello più debole**, riletto
adesso — la regola che il Giudice applica alla nascita, fatta vivere nel
tempo. Chi cita di più non dura di più. E **le ripetizioni si RIFIUTANO, non
si fondono**: è l'opposto dell'anello dei ricordi, apposta. Se fondessero, un
modello che si ripete — che è il difetto naturale dei modelli piccoli: due
incipit su quindici, misurati — si costruirebbe da solo un obiettivo
inarrestabile.

#### 2. La RICEVUTA, e perché è un bit e non una buona pratica

**Una deduzione entra nel mondo come un fatto osservabile prima che come un
obiettivo.** Finché la testa non si è girata, `deduzione_pronta()` risponde
-1: `chibi::D_RICEVUTA` è la regola scritta in un bit, e
`inserisci_deduzione()` azzera le bandiere in ingresso — **una deduzione nasce
muta**, e nemmeno un chiamante sbagliato può fabbricarne una con la ricevuta
già in tasca.

**Il canale non è nuovo: è la testa della Fase 4** (`Visitor.guarda_gesto`,
`Percezione.DURATA_SGUARDO`). La differenza fra le due scene non la fa il
codice, la fa il mondo: là la testa si gira verso una cosa che sta succedendo
adesso, qui verso un posto in cui non succede niente. Un vicino che guarda
l'aiuola vuota e poi ci va si legge senza una parola — e le parole qui non
sono ammesse (`Percezione`: «nessun testo, nessun toast, nessuna lettera»).

Due tempi, e **nessuno dei due è scelto**:

- **l'attesa** è `Percezione.DURATA_SGUARDO`, letta di là: la premessa e la
  sua durata sono la stessa cosa. Una testa che si gira e un corpo che parte
  nello stesso frame non sono due battute, sono una cosa illeggibile;
- **la finestra** è il `tetto_impegno` dell'agenda, letto dal binario: è il
  tempo massimo che l'agenda può metterci ad aprire una decisione. Più corta
  farebbe scadere deduzioni che non hanno avuto la loro occasione; più lunga
  farebbe arrivare la conseguenza quando il giocatore non ricorda più la
  premessa — e quello non attenua l'effetto, **lo inverte**.

E si paga **solo a chi può guardare, e solo se c'è QUALCUNO A GUARDARE.** La
domanda si fa a `Percezione.puo_vedere` — di là e non con quattro `if`
scritti a mano, così il giorno che qualcuno aggiunge una quinta valvola la
ricevuta la eredita — ma le si passa **dove sta Mochi**, non la posizione del
vicino stesso.

> ⚠️ **IL DIFETTO CHE QUESTA RIGA HA AVUTO PER UN PEZZO, ed era di progetto.**
> La domanda era `puo_vedere(node, node.global_position, 1.0)`: la distanza
> era zero **per costruzione**, quindi delle quattro valvole ne vivevano tre
> (dentro casa, addormentato, a un appuntamento) e mancava proprio quella che
> dà il nome al meccanismo. MISURATO nel villaggio vero
> (`tools/misura_attribuzione.gd`, le due regole appaiate sulle stesse
> deduzioni): **8 ricevute su 8 pagate con Mochi a 20 metri di mediana**.
> La scena era: il giocatore è nel bosco o in modalità costruzione, dall'altra
> parte del prato un vicino gira la testa, nessuno lo vede, e tre secondi dopo
> cambia mestiere. **Il giocatore vede solo la conseguenza** — cioè il guasto
> che inverte l'effetto, non una sua approssimazione.
> Dopo: **0 su 8 fuori raggio**, mediana 4,1 m. E il canale non muore: una
> deduzione resta muta e ASPETTA (come già faceva col collo), e dentro la sua
> vita il momento buono arriva nel **65–90%** dei casi — misurato facendo
> girare Mochi per il villaggio come gira un giocatore.

**`Deduzioni.RAGGIO` non è `Percezione.RAGGIO`, ed è una domanda diversa.**
Nove metri è fin dove un vicino si accorge di un gesto di Mochi; qui la
domanda è rovesciata — fin dove *il giocatore* legge una testa che si gira,
con la camera incollata a Mochi a 2,7 m d'altezza. È
`Visitor.FACCIA_AL_GIOCATORE` (**4,5 m**), cioè la distanza sotto la quale il
gioco aveva già deciso, per un'altra ragione, che la faccia di un chibi vale
la pena di puntarla verso di te. PROVINATO guardando
(`tools/provino_ricevuta.gd`, la camera VERA del gioco, cinque distanze): a
4,5 m l'imbardata si legge, a 6,5 è al limite, a 9 la testa è venti pixel e
**la ricevuta non esiste**.

> ⚠️ **E SI ASPETTA CHE IL COLLO CI ARRIVI — il difetto che solo la prova
> viva poteva vedere.** Il rig ha un tetto (`Visitor.TESTA_MAX`, meno il
> vagare e lo scarto personale: **0.775 rad, 44,4°**), e con il posto alle
> spalle la testa si ferma lì. Misurato nel MainLevel vero, prima:
> **la testa a 45° e il bersaglio a 148°, cioè 102° di scarto**. Nella Fase 4
> quella mezza girata bastava — il gesto vero è già davanti al giocatore, e
> una testa che si sforza dice comunque «mi sono accorto di qualcosa». Qui
> **la testa È tutta la scena**, e una testa che punta altrove non è una
> premessa: è rumore, cioè il guasto che inverte l'effetto.
> Perciò `Visitor.collo_ci_arriva()` (stesso `look_at` di
> `_sguardo_testimone`, stesso tetto, letto da `tetto_ricevuta()` che ora ha
> due lettori invece di un conto ripetuto) e la ricevuta **aspetta**. Non è
> una rinuncia: un vicino si gira di continuo, e la deduzione ha minuti per
> trovare il suo momento; se non lo trova muore senza che nessuno se ne
> accorga. Misurato dopo: ricevuta pagata a **0,67 s con 16,3° di scarto**, e
> la testa scende poi a **0,0°** sul bersaglio.
> Questa valvola ha anche **assorbito** il controllo che c'era prima («il
> ripiego è tornato indietro tale e quale: non si guardano i propri piedi»):
> era un sottoinsieme stretto di questo, e nessuna mutazione poteva più
> renderlo rosso. Una guardia che nessun test può far fallire è una guardia
> che non c'è, e si toglie.

#### 3. «Prioritario», detto preciso

Vuol dire **che quando l'agenda apre una decisione, la deduzione è la prima a
cui si chiede** — e se il mondo le dà una strada intera, il piano è il suo.
Non vuol dire niente di più, e le tre cose che *non* vuol dire sono le tre
leve della Fase 2:

1. **non scavalca il lucchetto del corpo**: si dirotta solo dentro
   `_gesti_agenda`, sul FRONTE (`azione_cambiata`), che esiste solo quando il
   registro ha già deciso che si può cambiare;
2. **non tocca `T_MIN`**: non c'è nessuna corsia d'urgenza — la deduzione non
   alza un punteggio, non muove un modulatore, non entra nell'argmax. Arriva
   DOPO che l'argmax ha parlato;
3. **non tocca il dado congelato**: in tutto questo cammino non c'è un dado
   (il Giudice è puro, il seme del modello arriva da fuori).

E la quarta, della Fase 3: **MAI un piano a metà.** Si chiede al risolutore, e
se torna a mani vuote non si dirotta niente.

**La deduzione si spende ANCHE quando non dirotta**, ed è voluto: «il mondo
non ha una strada», «l'agenda voleva già quello» e «l'ho fatto» sono tutte la
fine della sua vita. Tenerla in caldo vorrebbe dire che alla decisione dopo —
fra quaranta secondi — parte una conseguenza la cui premessa il giocatore non
ha più in mente. **Una deduzione vale UN'occasione, quella subito dopo la sua
ricevuta.**

#### 4. Il VETO: quattro assenze, non quattro promesse

- **nessun testo verso il giocatore** — una deduzione ha due campi e nessuno
  dei due è una stringa (`Giudice.CAMPI_DEDUZIONE`), e la grammatica non ha un
  posto in cui infilarne una: nessuna classe di caratteri, nessuna ripetizione
  aperta, solo letterali. Le due guardie sono indipendenti apposta (una governa
  il campionamento e vale solo se chi chiama passa la grammatica; l'altra
  governa cosa entra nel mondo e non ha configurazione);
- **nessun giudizio su una persona, nessuna classifica** — `EcsMondo::deduci`
  **azzera il soggetto** delle copie. Non c'è una regola da rispettare: non
  c'è un campo in cui scriverlo. (E il peso non cambia di un bit: `peso()`
  guarda le bandiere, non il soggetto.);
- **nessun corteo dietro Mochi** — i quattro provvedimenti non dicono «vai da
  qualcuno», e il posto che si guarda è quello di un ricordo: un'aiuola, una
  panchina, un cespuglio. Cose che non camminano, che è lo stesso argomento
  per cui `_ancora_ricordo` non ha bisogno delle valvole di `ancora_riposo`;
- **e non ci si mette in fila** — il Pensatoio consegna un pensiero per volta
  in tutto il villaggio e mette a riposo chi l'ha ricevuto per cinque minuti.

#### 5. La grammatica del JSON, e il giro chiuso

`grammatica_deduzione()` non ha un letterale scritto a mano: gli **obiettivi**
sono le chiavi di `OBIETTIVI_DETTI` (che un test lega a `Piani.OBIETTIVO` e a
`maschera_obiettivo()`), le **righe** sono i `riga` di `fatti(rit)`, cioè gli
indici veri delle righe vive del grafo di quel vicino stasera. Escono
l'obiettivo che sta già perseguendo (proporlo non è una deduzione) e quelli
per cui il mondo non ha una strada adesso (`Visitors.obiettivi_fattibili`).

E le combinazioni si scrivono **per esteso**, come `citazioni()`: i
sottoinsiemi *crescenti* di uno, due o tre indici — quarantuno alternative con
sei ricordi. Costa qualche riga e in cambio rende impossibili le due forme che
una regola ricorsiva lascerebbe passare: il **doppione** (gonfia una catena
senza renderla più solida) e la **permutazione** (la stessa deduzione contata
come due bozze diverse).

Siccome le uscite possibili sono finite, il test le **enumera tutte** e
pretende che il gioco le incassi tutte: *tutto ciò che la grammatica può
produrre, il gioco lo sa aprire e collaudare*. Non è un campione, è l'insieme.

E una cosa che si è vista solo **guardando il foglio**, non contando:
nell'elenco numerato dei ricordi i pezzi facoltativi della lettera (quando,
dove, quante volte) **non sono facoltativi**. Senza, due annaffiate in due
posti diversi escono come due righe identiche con due numeri davanti — in una
lettera non è un guaio (il modello ne copia una e basta), qui il modello deve
dire QUALI ricordi lo hanno fatto pensare, e su due righe uguali la scelta è
un dado. Un dado che poi decide **dove il vicino gira la testa**, perché
l'ancora della ricevuta è il posto di quel ricordo.

> ⚠️ **UNO SCOSTAMENTO DICHIARATO dal piano dell'autore:** «il JSON viene
> parsato dal C++». Si apre in GDScript (`JSON.parse_string`), per due ragioni
> che tirano nella stessa direzione. (a) Il collaudo di una deduzione è già
> tutto in GDScript — `Giudice.utile` sa quali obiettivi il mondo può servire
> adesso e quali ricordi sono ancora vivi — e un parser di là vorrebbe dire
> due posti che decidono se una deduzione è buona: le tabelle gemelle questo
> progetto le ha già pagate tre volte. (b) Il testo di un modello è l'ingresso
> più ostile del gioco, e un parser scritto a mano in C++ su quell'ingresso è
> una superficie nuova dentro il processo del giocatore. Quello che attraversa
> il confine sono **due interi e una lista di indici** — la stessa disciplina
> del foglio del Pensatoio: byte, non frasi.

#### 6. Come si verifica

```
Godot --headless --path . --script res://tests/test_runner.gd       # 290 asserzioni
Godot --headless --path . --script res://tools/prova_deduzione.gd   # la scena vera
Godot --headless --path . --script res://tools/misura_attribuzione.gd  # i NUMERI
CHIBI_RICEVUTA=<dir> Godot --path . --script res://tools/provino_ricevuta.gd
```

I due banchi nuovi rispondono alle domande che nessuna asserzione sa fare.

[`tools/misura_attribuzione.gd`](tools/misura_attribuzione.gd) è **il metro
dell'attribuzione**, e non gli serve nessun `.gguf`: quello che un modello
può scrivere è un insieme FINITO e lo genera il gioco (un obiettivo fra i
fattibili, da uno a tre indici fra le righe vive), quindi lo **enumera
tutto** — che è più onesto che campionarne ottantaquattro con un modello,
perché la geometria non dipende da quale il modello sceglie. Poi mette **le
due regole (prima e adesso) sulla STESSA corsa, sullo stesso istante, sulla
stessa deduzione**: due corse diverse sarebbero due villaggi, e la differenza
misurata non sarebbe della regola. E fa girare Mochi per il villaggio come
gira un giocatore — modello dichiarato in cima al file — per rispondere a
«dentro la vita di una deduzione, il momento buono arriva?».

[`tools/provino_ricevuta.gd`](tools/provino_ricevuta.gd) è **il provino**, e
guarda dalla **camera vera del gioco** (incollata a Mochi, 2,7 m d'altezza,
niente imbardata): una macchina piazzata a un metro dal muso risponderebbe a
una domanda che nessuno si fa. Tre scene: le cinque distanze, i cinque angoli
fra l'ancora e la meta, e la curva del «perché resta muta».

[`tests/cases/test_deduzioni.gd`](tests/cases/test_deduzioni.gd) non cerca
stringhe nei sorgenti: interroga il binario, fa girare i passi veri, e guarda
cosa succede al grafo e al collo. **Trentatré mutazioni, una riga per volta,
tutte rosse** — e la falsificazione ha trovato quattro guardie che i test non
coprivano davvero:

- **il tetto della catena nel Giudice**: il caso usava un ritratto con meno
  ricordi vivi del tetto, quindi la bozza troppo lunga cadeva prima su
  «si appoggia a un ricordo che non c'è». Serviva un banco più largo;
- **il rifiuto di una catena troppo lunga nel ponte**: la mutazione «ingenua»
  (togliere il controllo) è un accesso fuori array, quindi non misura niente;
  quella *plausibile* — **troncare invece di rifiutare** — consegnerebbe al
  mondo una deduzione diversa da quella collaudata. E per vederla il caso
  doveva citare indici tutti DIVERSI, o il doppione lo copriva;
- **«una deduzione nasce muta»**: da sola non è falsificabile (nessun
  chiamante passa le bandiere). Si dimostra in COPPIA — un chiamante che
  prova a portarsi la ricevuta in tasca resta verde *perché* il ponte
  pulisce, e diventa rosso appena si toglie la riga che pulisce;
- **«non si guardano i propri piedi»**: dopo la valvola del collo era
  diventata irraggiungibile, e si è tolta. **È tornata, ed è tornata come
  SCELTA invece che come rinuncia**: adesso `perche_piu_forte` salta un
  perché che sta addosso al corpo (direzione non definita) e mostra quello
  dopo, che è vero uguale. Così è di nuovo falsificabile — la mutazione «non
  saltarlo» fa arrossire un caso.

E **quattro mutazioni nuove**, una per ogni valvola aggiunta, tutte rosse:
togliere l'occhio di Mochi dalla domanda della percezione (5 asserzioni),
portare il raggio a cento metri, passare apertura zero al ponte, spegnere il
filtro dentro `perche_piu_forte`, allargare il cono al doppio, e prendere il
vertice della lettura dalla meta invece che dal corpo (16 asserzioni).
Una mutazione **non** ha morso alla prima stesura, ed è la lezione di sempre:
togliere il `return` quando non c'è la meta è un accesso a un Dictionary
vuoto, cioè un errore a runtime — che **non fa fallire il test**, lo
interrompe a metà lasciando la suite verde. La mutazione plausibile è
*ripiegare sulla posizione del corpo*, e quella arrossisce.

> ### ⚠️ E IL CORPO DI QUEL BANCO ERA UN DOPPIO CHE MENTIVA (2026-08-12)
>
> Il `Corpo` del test era un `Node3D` che **ri-implementava**
> `collo_ci_arriva` — un `angle_to` fra il −Z del corpo e il posto. Il conto
> tornava, e proprio per questo era il guasto peggiore che quel file potesse
> avere: **la valvola vera non aveva nessun lettore.** MISURATO, guastando
> `Visitor.collo_ci_arriva` nel sorgente e rifacendo la suite: `return true`
> sempre (ricevute pagate col posto a 180°) → **63942/0/0**; `return false`
> sempre (nessuna ricevuta, MAI, in tutto il gioco) → **63942/0/0**. La riga
> che decide se una ricevuta si paga poteva diventare una costante, **in
> tutte e due le direzioni**, senza che una sola asserzione se ne accorgesse.
>
> Adesso il corpo del banco **è un `Visitor`**, col rig di `ChibiBuilder`:
> `collo_ci_arriva`, `is_hidden`, `dorme` e `in_scena` sono le funzioni di
> produzione, e le tre valvole si accendono scrivendo lo **stato vero**
> (`_hidden`, `_state = "tk_nap"`, `_scena_t`) invece di tre booleani del
> banco. Di finto resta solo `guarda_gesto`, che REGISTRA e poi chiama
> `super()`. Il cambio non sposta la geometria: **la testa di un chibi sta
> esattamente sopra l'origine del corpo** (scarto orizzontale 0.0000 m su tre
> genomi), che è il punto da cui misurava il doppio. Le due mutazioni adesso
> danno **9 e 16 asserzioni rosse**.
>
> **E i due numeri della ricevuta erano sorvegliati solo rispetto a sé
> stessi**: le sonde stavano a `RAGGIO ± 0.1` e `APERTURA ± 0.06`, cioè
> dicevano che la valvola morde, non che morde nel posto giusto — portando
> `FACCIA_AL_GIOCATORE` a cento metri restavano verdi. Adesso ognuno ha una
> guardia fatta di numeri che **non sono lui**, e tutti provinati o misurati
> altrove: due metri (si paga) e nove (tace, ed è anche `Percezione.RAGGIO`:
> le due domande devono restare diverse) per il raggio; 20° (il MASSIMO che
> il villaggio vero produce, `misura_attribuzione`) e 45° (dove il provino ha
> visto il corpo uscire dall'inquadratura) per l'apertura. Le quattro
> mutazioni corrispondenti sono rosse.
>
> **E la promessa del collo la mantiene il rig.** Anche `tetto_ricevuta()`
> era giudicato contro sé stesso: portandolo a π restava tutto verde. Il caso
> nuovo chiede al collo *e poi gira la testa per davvero* (`guarda_gesto` +
> tre quarti di secondo di `_process`), e misura quanto le manca. MISURATO,
> deterministico su tre corse: posto a 34° → **0.0057 rad (0.3°)**; posto a
> 148° → **1.8128 rad (103.9°)** — cioè gli stessi 102° che la prova viva
> aveva misurato nel MainLevel, da un banco completamente diverso. ⚠️ E il
> posto raggiungibile **non sta davanti**: davanti la testa è già puntata, e
> il residuo resterebbe minuscolo anche con lo sguardo spento (verificato:
> spegnendo `guarda_gesto` il residuo diventa 0.600 rad e il caso arrossisce).

[`tools/prova_deduzione.gd`](tools/prova_deduzione.gd) è la prova viva, **e
non serve nessun `.gguf`**: le bozze sono tre JSON scritti a mano, come li
scriverebbe un modello, e tutto il resto del cammino è quello vero — la
percezione vera, il Giudice vero, il ponte vero, il registro vero, il corpo
vero. Stampa la grammatica per esteso (si legge a occhio, come le citazioni),
poi la pellicola della ricevuta frame per frame, poi dove cammina il corpo.
Misurato: **ricevuta a 0,67 s con 16,3° di scarto**, testa sul bersaglio a
**0,0°**, obiettivo pronto a **8,40 s** (7,7 s dopo la premessa), e il corpo
che si ferma a **0,60 m dal posto che ha guardato**. L'ultima scena rifà lo
stesso identico gesto a deduzione spesa: il vicino se ne va dall'altra parte,
che è il ramo su cui gira il gioco di chi non ha installato niente.

E **due cose che il banco deve fare, o non prova quello che dice**: zittire
l'agenda con il lease (senza, fra il gesto e la deduzione il registro cambia
mestiere da solo e l'obiettivo che il vicino sta già perseguendo esce dai
deducibili — giustamente), e insediare **due** vicini (senza qualcuno con cui
parlare, «quattro_chiacchiere» non manda il corpo da nessuna parte e la scena
4 misurerebbe un corpo fermo dov'era).

### IL CIELO — l'unica cosa del mondo che una riga libera può smentire

L'ancoraggio ferma «chi ha fatto cosa a chi» perché confronta col grafo. Il
CIELO non aveva un confronto, e sul mazzo vero del 4B — **trenta lettere
mandate**, quelle che il giocatore avrebbe letto — otto righe affermavano un
tempo che non era quello: «la pioggia mi avvolge» col sereno **cinque volte**,
«la neve, un peso» d'autunno, «le foglie bruciano al sole» alle 22:50. E il
conto sulle bozze è peggio: **il cielo è nominato 27 volte e 27 volte è
sbagliato**. Zero su 27 — non è un modello che ogni tanto sbaglia il tempo, è
un modello che il tempo non ce l'ha e se lo inventa.

Adesso `Suggeritore.accetta()` ha una **quarta porta**, `cielo`
(`afferma_sul_cielo`), e la fonte non è nuova: sono le tre chiavi che il
livello mette già nel ritratto per scrivere il prompt —

| chiave | da dove | chi la usa già |
|---|---|---|
| `rit["meteo"]` | `CozyWorld.contesto_critter()` | il bestiario, per la farfalla di neve |
| `rit["momento"]` | `OraDelGiorno.momento()` | il blocco `QUAND'È` del prompt |
| `rit["stagione"]` | `DayNight.season_name()` | idem |

`FoglioDelVicino` chiede il meteo a **`contesto_critter()` e non a `Weather`**:
chiederlo a Weather vorrebbe dire riscrivere «d'inverno la precipitazione è una
nevicata, non pioggia», cioè dare una seconda risposta a «è inverno?» — che qui
è vietato per iscritto. E le chiavi della tabella delle parole sono i nomi veri
degli stati (**`Critters.METEO`**, che era un commento ed è diventato una
lista): un test le lega nei due versi, perché una chiave scritta storta non
fallisce — **smette di giudicare, in silenzio**.

**MISURATO, appaiato, sullo stesso mazzo** (`tools/prova_cielo.gd`: rigioca la
gara con le stesse bozze e gli stessi punteggi, cambiando solo il collaudo; e
prima di misurare qualunque cosa rigioca la gara di IERI con le regole di ieri
e pretende la stessa scelta — 40 su 40):

| | prima | dopo |
|---|---|---|
| lettere mandate | 30 | 22 |
| lettere con una riga rotta *(che il filtro riconosce)* | 14 | 0 |
| righe rotte | 16 | 0 |
| lettere toccate dal filtro | | 14 |
| ...di cui **erano rotte** | | **14** |
| **lettere sane cambiate per sbaglio** | | **0** |

Le otto lettere diventate silenzio erano **tutte e otto** rotte, e il silenzio
è un esito legittimo (il gioco manda la lettera scritta a mano). Delle 163
righe libere che il collaudo di ieri promuoveva ne cadono **38** (21 cielo, 10
parola, 7 sagoma): **rilette una per una, nessuna era una riga da tenere.**

**LA REGOLA CHE HA GUIDATO OGNI TARATURA: il filtro non deve uccidere la
poesia, che è l'unica cosa per cui il modello è lì.** Perciò ogni parola è
stata contata sul mazzo vero (**1395 righe libere**, quattro modelli):

- si giudicano **pioggia · neve · nebbia** (32 righe in tutto, zero collisioni:
  le radici non prendono nient'altro). `sereno` non è nella tabella ed è la sua
  definizione — è quel che resta quando nessuna delle altre è vera;
- **due valvole salvano la figura retorica**: il PARAGONE («il silenzio cade
  come pioggia») e l'IMPRESSIONE («la legna sa di pioggia», «un senso di
  pioggia» — telaio adiacente *nome/verbo di percezione + di + parola del
  cielo*, che infatti non salva «piccole gocce di pioggia»). L'impressione
  costa 3 righe su 27, e sono tre righe belle;
- **il SOLE non si giudica**, tranne addosso e di notte. «sole» compare in
  **60 righe su 1395** ed è la parola preferita del Gufo («il sole cala lento
  sul mio ramo», «un vago ricordo del sole», «l'ombra del sole»): **una sola**
  è una bugia. Una regola larga abbastanza da prenderla ne ucciderebbe 59.
  Resta il telaio locativo (`al/nel/dal/sotto il sole`) e **solo di notte**: un
  caso, zero falsi positivi su 1395 righe;
- **la NOTTE come parola non si giudica affatto.** Il mazzo ha «la notte è
  lunga e io resto qui ad aspettare»: è esattamente la frase che il residuo
  vecchio aveva previsto, e non è una bugia nemmeno a mezzogiorno.

**E il prompt NON è stato toccato.** La cura alla radice sarebbe una riga in
più in `_blocco_quando` (il modello non sa che tempo fa, e questa porta lo
boccia per una cosa che nessuno gli ha detto) — ma quella cambia le
GENERAZIONI, e le generazioni si misurano solo rigenerando il mazzo con un
modello da 2,6 GB. Finché quella misura non c'è, si è cambiato **solo ciò che
si poteva contare**.

**Le altre due cicatrici**, dalla stessa rilettura:

- **«ivi»** — italiano vero, l'avverbio degli atti notarili, in **cinque delle
  trenta lettere** («il legno scricchiola ivi», «pioggia leggera ivi ivi») e 19
  volte sul mazzo. `FUORI_REGISTRO` è una lista corta di deittici e connettivi
  da atto pubblico. ⚠️ **È una regola di GUSTO, e nel sorgente è scritto che lo
  è**: tutte le altre di quel file sono di lingua o di grafo. Non deve
  allungarsi a ogni bozza brutta. Costo misurato: zero righe buone;
- **la sagoma del foglio** — «una riga tua, se ti va.» è arrivata in una
  lettera vera, e non è un'invenzione del modello: è **il messaggio di sistema
  ricopiato**. La regola guarda la COPPIA (`riga`/`righe` + un possessivo di
  prima o seconda persona), e ci sono voluti due giri: la prima stesura
  guardava la parola «riga» e ha fatto diventare rossa la suite in sei punti
  perché bocciava *«una lucciola sola scrive una riga d'oro sull'acqua nera»*,
  la bozza bella scritta a mano in `test_giudice.gd`. **26 su 26 prese, 0
  righe buone perdute.**

**LA REGOLA PROVATA E BUTTATA, che vale quanto quelle scritte.** «Due
parole-attrezzo incollate» (`ildi` = «il»+«di») funzionava e chiudeva una riga.
È stata tolta dopo aver **enumerato** cosa prendeva: con `ARTICOLI` come lista
di pezzi boccia **«dello», «dagli», «digli», «dadi», «loda», «lodi»**. E c'è di
peggio del falso positivo di oggi: `ARTICOLI` esiste per tagliare le etichette
dei vicini: il giorno che qualcuno ci aggiunge «nel», «dal», «sul» — una
modifica innocua, fatta per un'altra ragione — la regola comincia a bocciare
**«nella», «dalla», «sulla»** e nessun test può accorgersene. Una riga su 1751
non paga una trappola così.

**COSA RESTA APERTO.** Il numero onesto non lo dà un contatore: si legge. Le
22 lettere di dopo, rilette a mano, hanno **4 righe rotte in 3 lettere** (più
due righe discutibili in una quarta, l'eco del foglio) — contro **20 righe in
17 lettere** delle 30 di prima, contate con lo stesso metro:

- **le non-parole con le vocali dentro** («ivieta», «orteccio», «moffa»,
  «ildi»): servirebbe un dizionario italiano. Tre strade provate e misurate,
  tutte e tre buttate — l'ultima è quella qui sopra, le altre due
  («finisce per vocale», «la parola non compare altrove») stanno in
  `Suggeritore.gd`, con i numeri;
- **la riga ripetuta identica** («mangiando un nocciolo arido» due volte);
- **l'eco del blocco `QUAND'È`** («mattina, d'estate…»): è la stessa famiglia
  di `_frasi_del_foglio`, ma le sue code chiedono tre parole e «mattina,
  d'estate» ne ha due;
- **il tempo verbale del sole** («il sole si spegne» di notte): il residuo
  vecchio diceva «chi la vorrà chiudere deve portarsi dietro il TEMPO
  VERBALE», e aveva ragione — questa metà non è chiusa.

```
CHIBI_MAZZO=<pensieri.jsonl> Godot --headless --path . \
  --script res://tools/prova_cielo.gd
```

### LA PROVA VIVA: il modello vero dentro il villaggio vero

Gli altri quattro banchi della Fase 5 provano **un pezzo per volta**, e tre su
quattro lo provano **senza modello** (bozze scritte a mano). Il quinto è
[`tools/prova_pensieri.gd`](tools/prova_pensieri.gd), ed è l'unico posto in
cui un `.gguf` vero scrive dentro il MainLevel vero e si guarda cosa succede:

```
CHIBI_MODELLO=/percorso/al.gguf CHIBI_PENSIERI=/dove/le/foto \
  ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
  --script res://tools/prova_pensieri.gd        # senza --headless: le foto
CHIBI_GIRI=0 CHIBI_GIOSTRA=1 …                  # solo le scene, per tarare le inquadrature
```

Stampa i **prompt per esteso**, **tutte** le bozze con la scheda del Giudice
(perché una gara senza gli altri corridori non è una gara), la deduzione che
entra nel grafo, la ricevuta frame per frame e dove cammina il corpo; e
fotografa i tre momenti — prima, durante, dopo — **dalle stesse quattro
macchine**, perché una testa che si gira non si vede in una foto sola.

**Cosa ha misurato** (gemma-3-1b Q4_K_M, tre vicini, 5 bozze per pensiero, un
M1 da 8 GB):

- **il silenzio è la metà degli esiti**: 6 pensieri → 3 lettere e 3 silenzi;
  **30 bozze generate, 7 ammesse (23%)**, buttate 10 all'ancoraggio e 13 alla
  forma. La porta dell'ancoraggio non è teorica: in un pensiero su due il
  modello scrive nella metà libera una frase che AFFERMA («la volpina papavero
  ti ha vista costruire, più di una volta, poco fa»), e senza quella porta la
  lettera uscirebbe con la stessa frase tre volte di fila;
- **le deduzioni valgono per costruzione**: 5 JSON su 5 validi, in 6 s. È la
  prima volta che un modello vero vede `grammatica_deduzione`;
- **la ricevuta si vede, quasi sempre**: su **nove ricevute pagate, sette**
  portano la testa sul posto (picco 0.0–6.3°); **due no** (26.2°→28.2° e
  25.6°→23.3°), e in quei due casi il bit è acceso e il giocatore non vede
  niente.

  > **ADESSO È SPIEGATO, e non erano i due sospettati.** Né
  > `Visitor._sguardo_applica` né la stanchezza: **è il corpo che si gira
  > dopo**. `collo_ci_arriva` si chiede UNA volta, nell'istante in cui la
  > ricevuta si paga; poi il vicino continua a vivere, e
  > `_sguardo_testimone` **ripinza il bersaglio a `tetto_ricevuta()` a ogni
  > frame** — se il corpo si volta, la testa resta incollata al tetto e il
  > residuo è quello che avanza. MISURATO
  > (`tools/provino_ricevuta.gd`, provino 3: si paga la ricevuta e poi si
  > gira il corpo a gradini):
  >
  > | corpo girato di | la testa manca il posto di |
  > |---|---|
  > | 0°–45° | 2,2°–4,3° (ci arriva) |
  > | 60° | 8,6° |
  > | 75° | 17,3° |
  > | **90°** | **29,0°** |
  > | 120° | 37,8° |
  >
  > I 28,2° e i 23,3° sono un corpo che si è voltato di **ottanta-novanta
  > gradi** durante i 3,2 s dello sguardo. E la porta dell'apertura (qui
  > sotto) è anche la sua cura strutturale: adesso il posto guardato sta
  > entro 30° da dove il corpo sta per andare, quindi mettersi in cammino
  > porta la testa VERSO il bersaglio invece che via. Resta scoperto solo
  > chi si volta per una ragione che con la deduzione non c'entra (l'agenda
  > non ha ancora aperto la sua decisione).

**⚠️ UNO SGUARDO È UNA DIREZIONE, NON UN PUNTO** — e questa è la seconda metà
dell'attribuzione, vista per la prima volta qui e poi curata.

La ricevuta punta il posto di un RICORDO, il corpo va dove la messa in scena
manda l'obiettivo, e i due non coincidono quasi mai: misurato su **tutto ciò
che la grammatica può produrre** in un villaggio vero
(`tools/misura_attribuzione.gd`), la distanza fra i due posti ha mediana 5–8 m.
Chiedere che coincidessero — due metri di tolleranza — lasciava in vita **8
deduzioni su 100**, cioè il canale spento.

Ma era la domanda sbagliata. Il giocatore non misura i metri lungo un raggio
di sguardo: vede una testa girarsi di là e un corpo andare di là, e giudica
**dallo stesso vertice**, che è il corpo del vicino. Cinque metri a venti
metri di distanza sono quattordici gradi (la stessa cosa); cinque metri a sei
sono quarantacinque (due cose diverse). Perciò:

1. **la porta è ANGOLARE** (`Deduzioni.APERTURA`, 30°), e in gradi la stessa
   scena sopravvive nel **90%** dei casi invece che nell'8%;
2. **l'ancora si SCEGLIE fra i perché veri.** Una deduzione ne porta fino a
   tre, tutti collaudati dal Giudice: `chibi::perche_piu_forte` prende il più
   pesante **fra quelli che stanno nella direzione giusta**. Il criterio non
   cambia, cambia il campo — e fra cose tutte vere si può mostrare quella che
   il gesto sa indicare, che è quello che fa una persona quando indica
   qualcosa. Vale venti punti percentuali di sopravvivenza (70% → 90%);
3. **e se non ne resta nessuno, si tace.** La deduzione resta muta e aspetta,
   come già faceva col collo.

La meta la dice il **risolutore**, non una tabella nuova: il primo passo di
ogni piano è un trasferimento (`sistema_piani.h`), e il luogo di quel
trasferimento è l'indice dentro `r["luoghi"]` (`Deduzioni.meta_del_gesto`).
Misurato appaiato sulle stesse deduzioni: l'angolo fra il posto guardato e la
meta passa da **mediana 28°, massimo 62°** a **mediana 0–12°, massimo 20°**.
PROVINATO guardando (`tools/provino_ricevuta.gd`, provino 2, la camera vera):
a 0° e 30° il corpo se ne va nella direzione in cui la testa aveva guardato;
a 45° esce dall'inquadratura da un'altra parte.

**Residuo dichiarato:** quando la meta è **addosso** al vicino (meno di 5 cm:
è già sul posto) non c'è nessuna direzione da confrontare e il filtro non
filtra — è il degrado dichiarato di `chibi::Lettura`, la stessa convenzione di
`p_finestra <= 0`. Misurato: 1 caso su 5 in una corsa, 0 nell'altra.

**Le trappole di banco già pagate, tutte scritte nel file:**

1. **`_yaw`, non `rotation.y`.** `Visitor._process` finisce con `rotation.y =
   _yaw` per ogni stato, ogni frame: un'imbardata scritta da fuori vive un
   frame. Due stesure «convergevano» a 64° e 172° invece che a 30, la testa
   non arrivava più al bersaglio (il tetto del collo è 44°) e il banco
   dichiarava un silenzio che era suo.
2. **L'orologio si ferma** (`cycle_seconds`): un giorno dura quattro minuti e
   il banco venti. Senza, a metà prova i vicini vanno a dormire —
   `resident_sleep()` li rimpicciolisce a **scala 0.03**, la ricevuta non si
   paga più a chi è dentro casa, e le foto inquadrano un granello al buio.
3. **Le due valvole si stampano** (`vede?` e `collo?`). Una ricevuta che non
   arriva ha due sole ragioni, e un banco che dice solo «non è stata pagata»
   lascia indovinare: la colonna `vede? NO` ha spiegato in un colpo venticinque
   secondi di silenzio (era a un appuntamento).
4. **Il gesto della scena si fa ADESSO**, non all'inizio: dopo cinque lettere
   i ricordi dell'apertura pesavano **0.17** e il ponte rifiutava tutto. E con
   verbi e posti DIVERSI da quelli dell'apertura, o il grafo si ritrova due
   righe che in italiano si leggono uguali e il modello cita la vecchia (5
   bozze su 5, misurato).
5. **Le celle si provano una per una**: `place_cell` rifiuta in silenzio nel
   letto del fiume, e `debug_settle` su una cella rifiutata non insedia
   nessuno. Il banco conta i letti e si ferma.
6. **Una giostra di azimut si guarda a movimento finito**: scattata durante la
   ricevuta confonde l'angolo col tempo (a 45° la faccia, a 90° la nuca, a
   315° di nuovo la faccia).

### IL CABLAGGIO IN PARTITA — il nodo che possiede il ritmo

Fino al 2026-08-12 la Fase 5 era un laboratorio completo e **non collegato**:
il Suggeritore sapeva scrivere il prompt, il Pensatoio sapeva fare la fila, il
Giudice sapeva scegliere, `Deduzioni` sapeva incassare, e a valle `Visitors`
sapeva già pagare la ricevuta (`_cuore_di`) e dirottare l'agenda
(`_deduzione_dirotta`) — tutto provato, tutto misurato, **e il grafo delle
deduzioni restava vuoto per sempre**, perché nessuno chiamava niente. I cinque
banchi accendevano il ritmo a mano: se il pezzo che li mette insieme non fosse
mai esistito, sarebbero stati verdi lo stesso.

Il pezzo che mancava è [`scenes/npc/Pensieri.gd`](scenes/npc/Pensieri.gd), un
nodo che sta in `MainLevel.tscn` **accanto a Percezione** — il gemello più
vicino, e non per simmetria: ha gli stessi collaboratori che nascono tardi.

    un vicino → FoglioDelVicino.foglio_deduzione() → Pensatoio.accoda
      → il thread C++ scrive N bozze JSON → Deduzioni.incassa()
      → un nodo MUTO nel grafo, che aspetta di farsi vedere

> #### ⚠️ SENZA MODELLO NON SUCCEDE NIENTE — e «niente» è letterale
>
> La porta è `Llm.acceso()`, **non** `Llm.disponibile()`, e la differenza è
> tutta la fase: `disponibile()` dice che il BINARIO sa scrivere, ed è vera su
> `llm=yes` anche quando i pesi non ci sono — cioè per chi ha cancellato il
> modello spedito, per chi gioca da un albero di sorgenti, e per ogni banco.
> (Dal 2026-08-13 il modello viaggia dentro il pacchetto: vedi «IL MODELLO CHE
> SPEDIAMO», più sotto.) Con la porta chiusa il `_ready`
> spegne il proprio `_process` e ritorna prima di aver allocato un solo
> oggetto: niente ponte, niente Pensatoio, niente elenco, nessuna riga
> stampata. Un `_process` spento non viene *chiamato*, quindi il costo per
> fotogramma non è «piccolo»: è **zero**.

**Le sette regole del nodo**, e ognuna chiude un guasto vero:

1. **Il cablaggio si riprova, sempre** (`_cabla`, l'idioma di `Percezione`).
   L'`EcsMondo` nasce al primo ciclo del sonno e i figli di CozyWorld nascono
   su più frame: cablare una volta sola dentro un `call_deferred` del `_ready`
   trova `null` **per sempre**, ed è così che è morto il taccuino del Gufo.
2. **Il modello si apre quando c'è qualcuno che può pensare**, non al
   caricamento della scena: due gigabyte e mezzo mappati in un villaggio senza
   abitanti sono due gigabyte e mezzo pagati per una funzione senza soggetto.
3. **Si pensa solo su chi si può vedere.** Chi è dentro casa non è candidato:
   la sua ricevuta non si potrebbe pagare a nessuno, e con un pensiero ogni
   parecchi secondi spendere lo slot su di lui vuol dire buttarlo. (Di notte i
   ventotto sono tutti dentro, e allora **l'elenco vuoto si ricorda anche
   lui**, o si ricostruirebbe sessanta volte al secondo per tutta la notte.)
4. **`gia_dedotto` si riempie.** Il ponte rifiuta la gemella di una deduzione
   viva e il Giudice non ha modo di saperlo: lasciandolo vuoto si promuovono
   bozze che il mondo butta, **e la seconda bocciatura è muta**.
5. **Si collauda contro il ritratto con cui il pensiero è PARTITO**, che
   arriva col foglio: ricostruirlo alla consegna vuol dire giudicare contro un
   villaggio di un minuto dopo.
6. **Il seme è derivato, mai tirato**, e conta i tentativi: due pensieri dello
   stesso vicino non devono chiedere la stessa identica cosa.
7. **Non si scrive mai nel mondo da qui.** Quello che entra è un nodo muto nel
   grafo; la prima cosa che ne esce è una testa che si gira.

**Le uscite sono due**, e la prima è quella che nel 2026-08-11 mancava del
tutto: `_exit_tree` (che a un `RefCounted` come il Pensatoio non arriva mai) e
la morte del maniglione. MISURATO col cambio di scena verso il titolo con una
generazione in volo: **il motore torna libero in 170–644 ms** invece dei
quaranta secondi di una generazione intera, e **accetta ancora lavoro** — che
è la controprova che la riparazione della finestra di `annulla()` regge anche
dal chiamante vero.

**La porta del giocatore.** Il bit sta in `Settings.llm_spento` (persistito,
come `prato_eterno`), la domanda in `Llm.acceso()`. Fino al 2026-08-12 non
aveva una casella nel pannello, ed era la scelta giusta: mostrata a chi non ha
nessun modello racconta che gli manca un pezzo. Adesso che il modello viaggia
dentro il pacchetto la casella c'è, sotto `Llm.leva_visibile()` — vedi «IL
MODELLO CHE SPEDIAMO», più sotto.

**Dove sta il modello**: `Llm.percorso_modello()`, **tre** candidati in ordine
— `CHIBI_MODELLO` (i banchi, e l'autore), `user://modelli/pensieri.gguf` (quello
che chi gioca ci ha messo) e il modello SPEDITO accanto all'eseguibile. Mai
dentro il `.pck`, perché llama vuole un percorso su disco e una risorsa
impacchettata non ne ha uno. L'ordine — e perché `user://` sta sopra quello
spedito — sta nella sezione dedicata.

#### Come si guarda, e cosa ha detto

```
CHIBI_MODELLO=<file.gguf> CHIBI_RISERVA=0 CHIBI_MINUTI=12 CHIBI_QUANTI=28 \
  Godot --path . --resolution 1280x720 \
  --script res://tools/prova_villaggio_pensa.gd
```

[`tools/prova_villaggio_pensa.gd`](tools/prova_villaggio_pensa.gd) è l'unico
banco che **non collega niente**: apre il MainLevel vero, trova il nodo dov'è,
insedia i residenti, fa camminare Mochi come cammina un giocatore, e guarda.

**MISURATO** (gemma-3-1b Q4_K_M, finestra 2048, 28 residenti, 12 minuti di
partita ciascuna, M1 da 8 GB **con altre sessioni di agente addosso** —
loadavg 3.2–4.9, quindi questi sono PAVIMENTI e non misure pulite):

| | prio 1 | prio 2 (a) | prio 2 (b) |
|---|---|---|---|
| pensieri consegnati | 48 | 41 | 39 |
| deduzioni ENTRATE nel grafo | 41 | 35 | 36 |
| **ricevute pagate** (teste girate) | **32** | **8** | **19** |
| **mestieri cambiati per una deduzione** | **18** | **3** | **12** |
| tentativi muti | 3 | 13 | 2 |
| pensieri persi / buttati dal ritmo | 0 / 0 | 0 / 0 | 0 / 0 |
| un pensiero, in tutto il villaggio, ogni | 15.0 s | 17.6 s | 18.5 s |
| un dato vicino ne riceve uno ogni | 7.0 min | 8.2 min | 8.6 min |
| il foglio costa (peggiore) | 1.12 (1.33) ms | 0.52 (2.14) | 0.62 (1.08) |
| la consegna costa (peggiore) | 1.18 (1.74) ms | 0.40 (1.59) | 0.80 (1.06) |
| **fotogramma medio, misura APPAIATA** | **+4.43 ms (+9.8%)** | +2.56 (+8.0%) | **+1.19 ms (+3.4%)** |
| il `_process` del nodo, cronometrato | 18.8 µs (peggio 826) | 13.5–19.4 µs | idem |
| cambio scena con un pensiero in volo | 176 ms | 316 ms | **92 ms** |

E il **contatore delle ricevute di `Visitors` combacia esattamente con
l'oracolo indipendente** (le bandiere lette dal grafo) in tutte e tre le
corse: 32/32, 8/8, 19/19.

Le tre righe che contano:

1. **IL GIRO GIRA DA SOLO.** Nessun banco lo spinge: il nodo trova il
   villaggio, apre il modello (1–4 s, sul thread, col gioco che disegna),
   sceglie i vicini a turno, le deduzioni entrano, le teste si girano e
   qualcuno cambia mestiere. **Zero pensieri persi, zero buttati dal ritmo**
   in trentasei minuti di partita.
2. **IL COSTO NON È IL NODO, È IL THREAD.** Il `_process` del nodo costa
   **diciotto microsecondi** in media (il peggiore, 0.8–2 ms, è il fotogramma
   in cui si monta un foglio, una volta ogni parecchi secondi): il
   millimetro-e-mezzo sul fotogramma medio è llama che scrive, cioè un core
   che il gioco non ha più. Ed è la ragione per cui `PRIORITA` è la più bassa
   — il numero sta accanto alla costante, e non è stato indovinato.
3. **⚠️ LE RICEVUTE VARIANO MOLTISSIMO FRA UNA CORSA E L'ALTRA, e non l'ho
   spiegato.** 32 su 41 deduzioni, poi 8 su 35, poi 19 su 36 — stesso
   villaggio, stesso dado per il giro di Mochi. La ricevuta è per costruzione
   una COINCIDENZA (Mochi entro 4,5 m **mentre** il collo di quel vicino ci
   arriva **mentre** quella deduzione è ancora muta), e il giro del ritmo cade
   su vicini diversi a fotogrammi diversi — ma «è una coincidenza» non è una
   spiegazione, è un'ipotesi. **Chi ci torna misuri questo prima di qualunque
   altra cosa**: è il numero che decide se il giocatore VEDE la premessa, e
   una conseguenza senza premessa non attenua l'effetto — lo inverte.

**Le due trappole di banco, tutte e due pagate scrivendo questo file:**

1. **UN PRATO NUDO NON PAGA NESSUNA RICEVUTA, e non è colpa del cablaggio.**
   Alla prima corsa: cinque deduzioni entrate nel grafo e **zero ricevute**.
   La ricevuta chiede `Deduzioni.meta_del_gesto`, che chiede al risolutore
   dove andrà il corpo: senza cespugli e senza panchine nessuno dei cinque
   luoghi è `ok`, quindi nessun piano, quindi nessuna direzione a cui legare
   lo sguardo. Il banco adesso **costruisce** e stampa «residenti con almeno
   un posto raggiungibile»: se quel numero è zero, le ricevute saranno zero e
   il cablaggio non c'entra.
2. **I corpi vanno messi SULLA PROPRIA CELLA.** `Visitors` calcola i luoghi a
   partire da `home = cell`: un corpo a trenta metri dalla sua cella pianifica
   per un posto e cammina in un altro. (`misura_pensieri` li mette in griglia
   comoda, ed è giusto per lui: misura il costo, non il comportamento.)

**E i due contatori di `Visitors`** (`debug_deduzioni_contatori`: ricevute
pagate, mestieri cambiati) hanno un **oracolo indipendente** dentro il banco —
le bandiere `D_RICEVUTA`/`D_SPESA` lette dal grafo. Chiedere al contatore se
ha ragione sarebbe chiedere al giudice se è d'accordo con sé stesso, che è
l'errore che `tools/misura_cammino.gd` esiste per non commettere.

### IL MODELLO CHE SPEDIAMO — il terzo posto, l'impronta accesa, la casella

Dal **2026-08-13** il gioco viaggia col suo modello dentro: **gemma-3-4b-it
Q4_K_M**, 2 489 757 856 byte. Cambiano tre cose, e nessuna delle tre tocca il
ramo di chi non ce l'ha (verificato nel modo più forte che c'è: con `llm=no`
il binario è **byte per byte** quello di prima — stesso SHA-256 —, perché i
`src/llm_*.cpp` non entrano nemmeno nella lista dei file da compilare).

#### 1. Il terzo posto, e perché `user://` gli sta SOPRA

`Llm.percorso_modello()` ha tre candidati, **dal più esplicito al più
implicito**: `CHIBI_MODELLO` → `user://modelli/pensieri.gguf` → **accanto
all'eseguibile**. Mai dentro il `.pck`: llama apre un percorso su disco, e una
risorsa impacchettata non ne ha uno.

- «Accanto» non è la stessa cartella dappertutto, e la differenza non è
  cosmetica. Su **macOS** l'eseguibile sta in `<gioco>.app/Contents/MacOS/`, e
  lì un file di dati non ci può stare: `codesign` sigilla il bundle e tutto ciò
  che finisce fuori da `Contents/Resources/` diventa «unsealed contents» — una
  firma che non verifica e una notarizzazione che non passa. Su **Windows e
  Linux**, accanto e basta. La mappa vive in `Llm.spedito_accanto_a(exe)`,
  **presa a parte apposta**: è l'unica riga di questa fase che decide qualcosa
  su Windows, e da un Mac non si può verificare in nessun altro modo — un
  banco non può piantare un `.gguf` dentro il bundle di Godot, e un export
  firmato gira solo in CI.
- **`user://` sta sopra il modello spedito, e non è una preferenza di gusto.**
  La lista dà UN percorso, non una catena di ripieghi: se il C++ rifiuta quello
  scelto (tetto, riserva di RAM, portiere) la funzione si spegne — non passa al
  successivo. Il modello spedito chiede **2640 MB** e su una macchina da 8 GB
  la riserva lo rifiuta: se stesse sopra, chi ha una macchina piccola non
  potrebbe far funzionare la funzione **in nessun modo**. Con `user://` sopra,
  quel file è esattamente la via d'uscita che sembra.
  *Residuo dichiarato:* un `pensieri.gguf` dimenticato in `user://` scavalca
  per sempre quello spedito. È il verso giusto, e si legge — `Pensieri` stampa
  il percorso **per intero**, non `get_file()` (i candidati 2 e 3 si chiamano
  uguale, e col solo nome del file quel sorpasso è invisibile in un log).

#### 2. L'IMPRONTA È ACCESA, ed è l'ultimo dei quattro cancelli

`Llm.IMPRONTA_SPEDITO` è lo SHA-256 del file che spediamo, e
`Llm.impronta_attesa(percorso)` la arma **solo su quel percorso**: se fosse
globale, `CHIBI_MODELLO` non servirebbe più a niente (ogni banco si prenderebbe
«questo non è il modello collaudato») e il `.gguf` di chi gioca verrebbe
rifiutato senza che lui possa capire perché. Dei tre candidati ce n'è uno solo
di cui conosciamo i byte.

> ⚠️ **E L'ORDINE DEI CANCELLI IN `Traduttore::_carica` È CAMBIATO.** Era
> FORMA → **IMPRONTA** → TETTO → RISERVA; adesso l'impronta è **ultima**.
> MISURATO sulla macchina dell'autore, che il modello non lo aprirà mai (la
> riserva dice di no): il rifiuto arrivava dopo **37 431 ms** di lettura
> ininterrotta di due gigabyte e mezzo, a ogni avvio, per un no che si sapeva
> già. Adesso **490 ms** (e **1,35 s** nel MainLevel vero, dal nodo). È la
> regola dei quattro cancelli di `BuildSystem.deviazione`: in ordine di prezzo,
> e il caso comune non paga il caso raro.

Quanto costa, e a quale priorità — **la seconda cifra è quella vera**, perché
il thread del traduttore gira a `Pensieri.PRIORITA = 2` e su macOS quella QoS
**strozza anche l'I/O**:

| | il portiere (forma) | l'impronta, priorità 0/1 | l'impronta, **priorità 2** |
|---|---|---|---|
| gemma-3-4b, 2,4 GB | 17 ms | 11,7–12,3 s (194 MB/s) | **≈37 s** (66 MB/s) |
| gemma-3-1b, 806 MB | — | — | 15,5 s |

**Si verifica per INTERO, a ogni avvio, e non «una volta sola ricordandosela».**
Un promemoria del genere vivrebbe in `user://`, che chi gioca può scrivere: una
difesa che si spegne modificando un file di testo è la stessa leva che
`Config::valida` non ha, per la stessa ragione. E contro il logorio del disco
non varrebbe niente comunque — **un bit che marcisce non sposta la data del
file**. Il prezzo lo paga solo chi il modello lo apre davvero, sul thread, col
gioco che disegna: il primo pensiero della serata arriva mezzo minuto più
tardi, in un gioco che ne fa uno ogni quindici secondi. (Scartato anche
l'*hash parziale*: il portiere copre già l'intestazione per intero in 17 ms, e
campionare l'1% dei pesi mancherebbe un bit girato 99 volte su 100 — mezza
difesa che si legge come una difesa è peggio di nessuna.)

> ⚠️ **E L'IMPRONTA SI PUÒ MOLLARE A METÀ.** `Traduttore::chiudi()` fa
> `_thread.join()`: senza una via d'uscita, chi torna al titolo mentre
> l'impronta legge aspetterebbe la fine con lo schermo fermo — cioè
> riaprirebbe da un'altra porta il guasto che le «tre uscite» hanno chiuso
> (40 s → 6 ms). `impronta_file` interroga adesso un `molla` ogni blocco da
> 1 MB. MISURATO: `chiudi()` a impronta iniziata costa **3,0 ms**;
> **falsificato** togliendo quella riga e ricompilando → **11 872 ms**.

#### 3. La casella nel pannello — adesso ha senso, e prima no

«Il villaggio pensa» compare in `CozySettingsPanel` **solo** sotto
`Llm.leva_visibile()` (= il binario sa scrivere E c'è un modello). Fino a ieri
la casella non c'era, ed era la scelta giusta: mostrata a chi non ha nessun
modello racconta che gli manca un pezzo, e non gli manca niente. Da quando il
modello viaggia dentro il pacchetto la stessa regola dice il contrario — non
racconta una mancanza, racconta una cosa che c'è e che si può spegnere — e
senza di lei l'unica via d'uscita sarebbe cancellare un file dentro la cartella
d'installazione, che non è una via d'uscita: è un sabotaggio.

- **O la riga c'è, o non esiste**: niente casella ingrigita.
- Il bit salvato è `Settings.llm_spento` (**spento**, non «acceso»: il valore
  di serie di un `bool` è `false`, e il valore di serie della funzione dev'essere
  ACCESA). Il verso si gira in un posto solo, `set_llm_acceso()`.
- La riga **non nomina nessuna macchina**: chi gioca non deve sapere cos'è un
  modello linguistico per decidere se vuole che i suoi vicini abbiano idee
  loro. Sotto la casella ci sono le tre cose che gli servono — cosa fa, cosa
  costa, da quando vale.

#### 4. E su una macchina che non ce la fa, cosa vede chi gioca? NIENTE

È il caso dell'autore, ed è probabilmente il caso della maggioranza.
MISURATO nel MainLevel vero, con la riserva VERA (`tools/prova_rete_ram.gd`,
gemma-3-4b, 2583 MB liberi):

| | |
|---|---|
| il nodo si spegne dopo | **1,35 s** |
| fotogrammi durante il rifiuto | 33,2/s (identici a dopo: 33,2/s) |
| `_process` del nodo, dopo | **false** (un nodo spento non viene chiamato) |
| ritmo acceso / pensieri partiti | false / 0 |
| frasi del guasto a schermo | **0 su 13** |
| la diagnosi di oggi, a schermo | **0 volte** |
| finestre di dialogo | **0** |
| `village.json` scritto con `save_now()` | **sì**, 85 769 byte |

La riga nel log — l'unica traccia, e serve a chi diagnostica un difetto
segnalato — è: `pensieri: spento — questa macchina ha 2583 MB liberi: il
modello ne chiede 2640 e al gioco ne devono restare almeno 1024 (il gioco
continua con i testi scritti a mano)`.

**La controprova sta nello stesso banco**: rifatto col 1B (814 MB stimati, che
ci stanno) lo stato è **«pensa»** in 4,45 s. Un banco che dicesse «rifiutato»
comunque non misurerebbe niente.

⚠️ E una trappola di banco già pagata: la prima stesura cercava a schermo le
parole «memoria» e «modello», e segnalava — giustamente, secondo la sua regola
— la **descrizione della casella** nelle impostazioni. Adesso cerca i pezzi
LETTERALI delle diagnosi del C++ più la diagnosi vera di quella corsa, e guarda
`is_visible_in_tree()` e non `visible` (il menu di pausa costruisce il pannello
all'avvio e lo tiene nascosto: con `visible` il banco misurava un albero, non
uno schermo).

#### Come si verifica

```
CHIBI_MODELLO=<file.gguf> Godot --headless --path . \
    --script res://tools/misura_impronta.gd          # l'ordine dei cancelli
... CHIBI_SCENA=molla ...    # chiudere mentre l'impronta legge
... CHIBI_SCENA=apre  ...    # l'impronta GIUSTA non impedisce nulla
... CHIBI_SCENA=falsa ...    # e quella sbagliata ferma tutto, col SUO motivo

CHIBI_MODELLO=<file.gguf> Godot --path . --resolution 1280x720 \
    --script res://tools/prova_rete_ram.gd           # il gioco vero, senza rete
```

⚠️ **Un'apertura per processo**, e non è pigrizia dei banchi: `Traduttore::apri()`
si chiama una volta sola nella vita del processo, e `chiudi()` non la riabilita.
Le scene che aprono vanno in corse diverse.

La guardia headless è
[`tests/cases/test_llm_spedito.gd`](tests/cases/test_llm_spedito.gd): **24
mutazioni, una riga per volta, tutte rosse** (la mappa delle piattaforme,
l'ordine dei tre candidati in tutte e otto le combinazioni, l'impronta armata
sul percorso sbagliato o su nessuno, la costante troncata, il verso della leva,
il giro completo `_save`→`_load`, e la riga del pannello nei due versi).

**Due cose che quel file NON prova, ed è scritto lì dentro:**
1. che `Llm.IMPRONTA_SPEDITO` sia davvero lo SHA-256 del file spedito — per
   saperlo bisogna avere il file, e il file non sta nel repository. Si controlla
   solo che abbia la FORMA di uno SHA-256 (una costante troncata o con una
   maiuscola spegnerebbe la funzione per tutti, in silenzio). La verifica vera
   è `tools/misura_impronta.gd`, che legge il file e confronta.
2. l'ORDINE dei quattro cancelli dentro `Traduttore::_carica`: quel gettone di
   `apri()` è già speso da `test_llm_portiere`. La sua guardia è la misura —
   37 431 ms prima, 490 ms dopo.

⚠️ **E DUE MUTAZIONI SONO SOPRAVVISSUTE alla prima stesura dei test**, tutte e
due della stessa famiglia («si guarda a metà»):
- togliere `llm_spento` da `Settings._load` restava verde, perché il caso
  guardava il **file** e non il ritorno: una leva che si salva e non si rilegge
  è una leva che chi gioca deve ritirare ogni sera;
- e la guardia sul fatto che `Pensieri` chieda l'impronta era un **source-check
  che matchava il proprio commento**: sostituendo la chiamata con `var imp := ""`
  — cioè spegnendo l'unica difesa contro il bit girato nei pesi — la suite
  restava verde. Adesso `Pensieri.opzioni_modello(percorso)` è una funzione a
  sé, interrogabile con **il percorso del modello spedito** (che
  `spedito_accanto_a` sa dire anche quando il file non c'è), e il dizionario che
  arriva ad `apri_modello` deve esserle **uguale**.

### IL CORRIERE — due gigabyte e mezzo presi bene, o non presi affatto

Dal 2026-08-13 il modello **non viaggia più nel pacchetto**: se lo scarica il
gioco al primo uso, quando chi gioca accende la funzione. Il pezzo che va a
prenderlo è in tre file, e ognuno fa una cosa sola:

| dove | cosa |
|---|---|
| [`systems/Scarico.gd`](systems/Scarico.gd) | il NODO: il thread, il lucchetto, i segnali, le parole per chi gioca, e l'indirizzo da cui si prende |
| [`systems/ScaricoMacchina.gd`](systems/ScaricoMacchina.gd) | il VIAGGIO: tutte le decisioni, a passi, senza thread e senza `HTTPClient` |
| [`systems/ScaricoRete.gd`](systems/ScaricoRete.gd) | il TUBO: sei metodi sopra `HTTPClient`, zero decisioni |

**Il nodo vive sotto `/root`**, non dentro il livello: chi comincia dal menù di
pausa e poi torna al titolo non perde quello che ha già preso. Le costanti non
si ricopiano — `Llm` dice **cos'è** il modello (nome, impronta, peso, cartella),
`Scarico` dice **dove andarlo a prendere** (repository, revisione, indirizzo).

**Le sette regole del viaggio** stanno per esteso in cima a `ScaricoMacchina`.
Le tre che nessuno deve toccare:

1. **Il file buono nasce all'ultimo istante.** Finché non è arrivato tutto e
   l'impronta non combacia si chiama `pensieri.gguf.parte` — un nome che
   `Llm.percorso_modello()` non guarda. Un download interrotto non «sembra
   valido» mai: non è una convenzione, è una proprietà del nome.
2. **L'impronta non è facoltativa, e chi non combacia si BUTTA.** Un file
   rovinato lasciato sul disco spegne la funzione per sempre, e chi gioca non
   ha modo di collegare le due cose.
3. **Il degrado va verso «ricominciare», mai verso «scrivere storto».** Se il
   server ignora il `Range` (200 invece di 206), o il `Content-Range` comincia
   altrove, si tronca e si riparte: un file cucito male passa tutti i controlli
   tranne l'ultimo, e l'ultimo costa una rilettura di due gigabyte e mezzo.

**Le trappole MISURATE, e tre sono di Godot:**

- ⚠️ **`HTTPRequest` non sa riprendere: `download_file` TRONCA.** Misurato
  (4.7.1): un file di 1 MiB di `0xAA`, una richiesta con `Range:
  bytes=1048576-2097151`, e dopo il file è 1 MiB e comincia coi byte nuovi. Da
  qui `HTTPClient` a mano, su un thread.
- ⚠️ **`get_response_headers()` SVUOTA le intestazioni**, quindi
  `has_response()` diventa **falso** subito dopo averle lette — mentre lo stato
  è `STATUS_BODY` e i byte stanno arrivando. Chiedendola nell'ordine sbagliato
  il tubo restituiva `ATTENDE` **7932 volte in dodici secondi e zero byte**, con
  la suite verde: il tubo è l'unica parte che i test non possono coprire, ed è
  per questo che esiste il banco che scarica davvero.
- ⚠️ **Prima del primo fotogramma la cifratura non si accende.** In `_init()` di
  uno script `SceneTree`, `TLSOptions.client()` dà «SSL module failed to
  initialize!» e lo stato resta `CANT_CONNECT`; dopo un `await process_frame`,
  la stessa riga si connette in 190 ms — **e funziona anche da un thread**. In
  partita non capita mai (si scarica da un bottone); un banco che chiede in
  `_init` diagnostica «rete morta» con la rete viva.
- ⚠️ **L'indirizzo firmato della CDN è legato al `Range` chiesto all'ORIGINE.**
  Riusarlo con un altro intervallo risponde `403 Auth failed: invalid range`.
  Perciò il rimbalzo si segue con le stesse identiche intestazioni, e ogni
  ripresa riparte da casa: un indirizzo del CDN non si conserva MAI.
- ⚠️ **Il giro infinito del progresso.** Contare «ha portato byte da quando è
  cominciato questo tentativo» più la rincorsa all'indietro (`INDIETRO`, 1 MiB)
  fa un ciclo che non finisce: il file cresce di mille byte e ne ritorna
  indietro quattromila, ma «ha portato dei byte» azzera i tentativi. Il metro è
  **il punto più lontano a cui si sia mai arrivati**.

**Cosa è stato MISURATO scaricando davvero** (2,32 GiB da Hugging Face, linea di
casa, M1 da 8 GB con altre sessioni addosso — loadavg 2,2–3,7):

| | |
|---|---|
| preflight (una `HEAD`, zero byte di modello) | 221–631 ms, `x-linked-etag` e `x-linked-size` combaciano |
| velocità | **7,4 MB/s**, la linea: `curl` sullo stesso pezzo ne fa 7,31 |
| annullamento (thread che molla una connessione viva) | **37–47 ms** medi, peggiore 54 |
| riprese vere dalla CDN firmata | 6 + 2, tutte con `Range`, file finale corretto |
| impronta di 2,32 GiB | **~8 s** (312 MB/s misurati su `HashingContext`) |
| **fotogramma, misura APPAIATA** | +0,29 ms (+0,7%) in una corsa, **−1,47 ms (−2,8%)** nell'altra: sotto il rumore |
| rete col villaggio acceso e nessuno scarico | **0 connessioni** (`lsof` sul processo) |
| rete mentre scarica | **1** |
| rete subito dopo l'annullamento | **0** — annullare chiude il socket, non solo la barra |

E la ripresa funziona anche **fra due processi diversi**: una corsa uccisa a
334 MiB è ripartita da lì in quella dopo, e il file finale ha l'impronta giusta.

**Come si guarda:**

```
Godot --headless --path . --script res://tools/prova_scarico.gd     # CHIBI_SOLO_PREFLIGHT=1
CHIBI_ACCESO=45 CHIBI_SPENTO=8 CHIBI_DOVE=<cartella> \
  Godot --path . --resolution 1280x720 --script res://tools/prova_scarico.gd
```

Il banco alterna blocchi «scarica» e «fermo»: ogni passaggio è un annullamento
VERO e ogni ritorno una ripresa VERA, e i fotogrammi dei due tipi di blocco si
confrontano **nella stessa corsa** (su questa macchina non ce n'è un'altra di
utile). La guardia headless è
[`tests/cases/test_scarico.gd`](tests/cases/test_scarico.gd): fa camminare la
macchina VERA davanti a un tubo che sa cadere, ignorare il `Range`, mandare byte
sbagliati e chiudere la porta — 147 asserzioni, e **venticinque mutazioni una
per volta, tutte rosse**. Due erano mute alla prima stesura e sono state
riscritte: il tubo dichiarava un `Content-Range` storto e poi mandava i byte
GIUSTI (spegnere il controllo lasciava il file corretto), e il `flush()` prima
di rileggere non era falsificabile perché lasciar cadere il `FileAccess` chiude
— quella riga è stata tolta.

> ⚠️ **E UNA TRAPPOLA DI BANCO CHE COSTA DUE GIGABYTE.**
> `test_offerta_modello.gd::_pulisci()` cancella `Scarico.destinazione()` e il
> suo `.parte` — cioè **il modello vero di chi sta sviluppando**. Misurato due
> volte: una corsa della suite fatta da un'altra sessione si è portata via
> prima 211 MiB di scarico a metà, poi il file intero appena atterrato. Per
> questo `test_scarico.gd` lavora in `user://prova_scarico` e
> `tools/prova_scarico.gd` posa il file nella cartella vera **solo se glielo
> si chiede** (`CHIBI_POSA=1`).

### LA STRADA DEL GIOCATORE — e la porta che per un giorno è stata murata

I banchi qui sopra provano ognuno un PEZZO: il corriere coi suoi byte, la
pagina coi suoi `Label`, il portiere coi suoi quindici guasti. Nessuno
camminava la strada **come la cammina una persona** — la casella, la pagina,
il sì, la rete che cade, il file rotto — e in quel buco ci stava un difetto
che rendeva l'intera fase irraggiungibile.

> ### ⚠️ IL DIFETTO: la pagina si apriva e spariva un fotogramma dopo
>
> `CozySettingsPanel._llm_toggled` faceva `_apri_offerta()` **e poi**
> `_ricostruisci()`. Il secondo butta TUTTI i figli del pannello a fine
> frame, e da quando la pagina dello scaricamento è uno di quei figli, il
> gesto la creava, la mostrava e la condannava nello stesso respiro.
> MISURATO col pannello vero: `_offerta` è un `PanelContainer` **vivo e
> visibile** nel fotogramma del gesto, e **`<null>`** in quello dopo. Chi
> giocava vedeva la casella tornare da sola al suo posto e nient'altro:
> **il download, il consenso, le licenze, il villaggio che pensa — tutto
> irraggiungibile dall'interfaccia, per chiunque**, con 66322 asserzioni
> verdi.
>
> **Perché nessuno se n'era accorto, ed è la lezione vera:** il runner fa
> girare **un caso per fotogramma**, e dentro un caso non passa nessun
> frame. Una `call_deferred` quindi **non si esegue MAI** mentre le
> asserzioni guardano — un pannello che si è appena condannato da solo è
> indistinguibile da uno sano. E tutti i casi della pagina si costruivano
> l'`OffertaModello` per conto loro: **provavano la stanza, mai la porta.**
>
> La cura è un `return`; la guardia è `_rifacimento_in_coda`, la bandiera
> che rende la condanna un fatto osservabile nell'istante in cui viene
> chiesta, più `_rifai_adesso()` — il corpo del rifacimento con un nome suo,
> così un banco può fare a mano quello che il motore farebbe a fine frame
> (è l'idioma di `_apparecchia` in `test_salvataggio_finestra`).
> FALSIFICATO: rimettendo il difetto **2 rosse**, togliendo il rifacimento
> dalla chiusura **1**.
>
> ⚠️ E l'asserzione che chiude il cerchio guarda **`is_queued_for_deletion()`,
> non `is_instance_valid()`**: `queue_free()` non libera niente sul momento,
> e dentro un caso di test quel momento non arriva mai — con
> `is_instance_valid` la seconda asserzione **non mordeva** (misurato: una
> rossa invece di due).

Il banco che cammina la strada intera è
[`tools/prova_strada.gd`](tools/prova_strada.gd), sei scene, e gira **su
tutti e due i binari** (con llama e senza: sul secondo pretende che la riga
«Il villaggio pensa» NON esista, che è il gioco che la CI normale compila).
Guida il corriere VERO col tubo finto di `test_scarico`, e il metro non è
«torna il codice giusto» ma **cosa legge chi sta davanti allo schermo**:

| scena | misurato |
|---|---|
| dice di no | pagina aperta e chiusa: **zero byte scritti**, bit non toccato, nessuna ricevuta, nessun corriere |
| la rete CADE e torna | ogni tentativo porta a casa un pezzo, il file rimesso insieme ha l'impronta giusta |
| la rete è MORTA | «La connessione non ha retto…», nessun file col nome buono |
| chi gioca FERMA | 2 105 344 byte restano, col nome sbagliato; riprendendo si chiede `Range: bytes=1056768-` |
| la rete LENTA | il file arriva; «meno di un minuto · 12 Mbit/s», mai una percentuale al secondo |
| il DISCO finisce | detto **prima di scaricare un solo byte** (`fatti() == 0`) |
| il file arriva ROTTO | l'impronta lo becca, il file viene **buttato**, e riprovando arriva quello giusto |
| la macchina non ce la fa | col computer dell'autore quel giorno (2583 MiB liberi) **il download non viene nemmeno nominato** |

⚠️ **Due trappole di banco, tutte e due pagate scrivendolo:**

1. **Il file di prova dev'essere più grande di `ScaricoMacchina.INDIETRO`**
   (la rincorsa di 1 MiB con cui si riprende). Con trecento kilobyte ogni
   ripresa rincorre fino a zero, nessun tentativo guadagna un byte, e quello
   che si osserva è **una costante del corriere invece del suo
   comportamento**.
2. **Si aspetta con l'OROLOGIO, non a fotogrammi.** Fra un tentativo e
   l'altro il corriere riposa davvero (2+4+8+16 s), e in headless i
   fotogrammi volano: un tetto a fotogrammi scade mentre il corriere sta
   ancora aspettando il suo turno, e il banco dichiara «non ha fatto niente»
   di uno che stava facendo la cosa giusta. Mi ha dato tre falsi guasti in
   tre scene diverse.

### Il fotogramma mentre il modello arriva, e il bit girato a riposo

[`tools/misura_scarico_fps.gd`](tools/misura_scarico_fps.gd) conta i
fotogrammi del MainLevel VERO mentre il file arriva **davvero** dalla
sorgente vera, a blocchi alternati *scarica · fermo* nella stessa corsa
(vsync spento, in una cartella sua che poi butta). Due corse, macchina
scarica (loadavg 1.2–1.6), ~60 Mbit/s, 427 MB per corsa:

| | medio | MAX | >2×p50 |
|---|---|---|---|
| mentre scarica | 29.34 / 28.90 ms | 53.69 / 52.91 | **0** |
| a motore fermo | 29.70 / 29.20 ms | 32.36 / 31.94 | **0** |
| **scarto** | **−0.36 ms (−1.2%) · −0.30 ms (−1.0%)** | | |

Lo scarto è **negativo** in tutte e due le corse: il download non si sente,
e la promessa «puoi tornare a giocare» si mantiene. L'unico solco vero è
**un fotogramma solo da ~53 ms all'apertura della connessione**, riprodotto
in tutte e due le corse e sempre nel primo blocco — sotto la soglia del
doppio della mediana, ma c'è.

[`tools/prova_bit_girato.gd`](tools/prova_bit_girato.gd) risponde all'altra
metà: **dopo l'installazione, chi riverifica il file?** La risposta,
misurata sul modello VERO da 2,4 GB, è **nessuno**:
`Llm.impronta_attesa()` torna l'impronta solo per il posto accanto
all'eseguibile — che da quando il modello non viaggia più nel pacchetto **non
esiste per nessuno** — e per il file scaricato in `user://` torna `""`.
Resta il portiere, e questo è fin dove arriva:

| dove cade il bit | il portiere |
|---|---|
| nella firma (primi 4 byte) | **FERMATO** — «non è un file GGUF» |
| nei conti di testa | **FERMATO** — «dichiara 4294967740 tensori» |
| dentro i metadati | passa |
| dentro i pesi (metà file, e in fondo) | passa |

Cioè: **in transito l'impronta becca qualunque cosa** (scena 5), **a riposo
no**. È il residuo che la Fase 5 dichiarava già in teoria, adesso misurato in
partita. Chi lo vorrà chiudere ha una strada che non punisce chi si mette un
`.gguf` suo in `user://modelli/`: la **ricevuta** che il consenso scrive già
può portarsi l'impronta di ciò che il gioco ha scaricato — si riverifica solo
quel file, e solo perché sappiamo cosa deve essere.

## IL VOCABOLARIO DEL CORPO CHE PENSA

Questo gioco è un **simulatore di personalità umana**, e da lì discende la
regola che governa tutto il resto: **la leggibilità è la cosa più
importante.** Fino al 2026-08-13 l'unico segno che un vicino avesse una vita
interiore era **una testa che si gira** per 3,2 s — ed era stata misurata:

- si legge solo da davanti e solo da vicino;
- **di spalle non ha VERSO**: si vedono le orecchie muoversi e non si sa da
  che parte (rapporto misurato **1,04**, e in questa tornata 0,67–1,11);
- a diciassette metri la testa è venti pixel;
- e in partita, **sette teste girate in venticinque minuti**.

Adesso c'è un vocabolario: [`scenes/npc/Gesti.gd`](scenes/npc/Gesti.gd) (le
buste, pure, senza Godot) e il motore in `Visitor` (`_gesto_passo`,
`_recita_applica`, `_gesto_scala`). Quattro FRASI, non sei gesti — e ognuna
corrisponde a una cosa che il gioco aveva GIÀ da dire:

| frase | corpo | chi la chiede, e già esisteva |
|---|---|---|
| **la premessa** | il Punto (molle) | `Percezione._testimonia`, la terza riga |
| **il pensiero** | il Punto deciso + il Capo | la ricevuta di una deduzione (`Visitors._cuore_di`) |
| **la rinuncia** | il Raccolto → il Rialzo | `Limbico.trattieni()` che torna **true** |
| **l'evitamento** | il Largo, camminando | `Limbico.evita(luogo)` in `_filtra_luogo` |

Più due **LIVELLI**, che non prendono il gettone: il **Capo che pende**
(`regolazione < 0.45`) e la **coda somatica** (la `forza` che
`_tick_sussulti` calcola già). **Zero inneschi nuovi**: il vocabolario non
può aumentare la frequenza degli eventi, può solo renderli visibili.

### IL CRITERIO UNICO, e cosa ha bocciato

«Pixel di contorno cambiati» misura la **rilevabilità** (è successo
qualcosa), non la **leggibilità** (è successo *di là*). Il criterio è

    |maschera(+A) XOR maschera(−A)| / |maschera(A) XOR riposo|  ≥  1,6

cioè: le due versioni OPPOSTE dello stesso gesto si distinguono FRA LORO?
Misurato sul rig vero con [`tools/provino_verso.gd`](tools/provino_verso.gd)
(quattro azimut × 6/9/17 m, pixel contati dal fotogramma renderizzato contro
una lastra di fondo, posa scritta dallo **scrittore vero**):

| canale, isolato | verso | | |
|---|---|---|---|
| **verticale** (`vy`) | 1,76–1,89 ✅ | il più direzionale del rig | |
| **profondità** (`vz`) | 1,67–1,97 ✅ | e nessuno se l'aspettava | |
| **laterale** (`px`) | 1,62–1,94 ✅ | e il più GROSSO (3682 px a 6 m) | |
| **scala** (`sy`) | 1,64–1,85 ✅ fino a −10%; a −13% cade | | |
| **rollio del capo** (`hz`) | 1,74–1,86 a 0,08 · **1,60–1,74 a 0,11** · 1,47 a 0,14 ❌ | | |
| **orecchie** (`ear`) | 1,84–1,97 a 0,20 · 1,39 a 0,55 ❌ · **di profilo non passa mai** | | |
| **braccia** (`ax`) | 3–33 px in tutto: fuori dalla campana della testona | | |
| **coda** (`tail`) | **0 px di fronte**, 82 al massimo | | |
| *(la ricevuta di oggi: testa 44°)* | **0,67–1,11** ❌ | | |

**Tre cose che questa tabella dice e che nessun ragionamento avrebbe dato:**

1. **L'ampiezza di una ROTAZIONE va al contrario dell'intuizione.** Il verso
   di un rollio *cala* crescendo (1,86 → 1,10 fra 0,08 e 0,24 rad): le due
   regioni spazzate si sovrappongono sempre di più. Un gesto rotatorio non si
   fa più leggibile facendolo più grosso — si fa più leggibile facendolo più
   **raro**. La sintesi da cui parte questo lavoro diceva «rollio 0,10–0,18
   rad»: **0,18 è fuori**.
2. **Traslazione e scala portano il verso; le rotazioni no.** Vale per
   l'imbardata (0,88), per il busto (1,47 a 0,18) e per le orecchie. È la
   ragione per cui il canale portante di ogni gesto qui è `vy`, `vz`, `px` o
   `sy`, e le rotazioni sono accenti.
3. **Un accento può COPRIRE la parola.** Le orecchie a 0,55 (la sintesi le
   voleva a 0,55 e 0,70) facevano scendere il gesto INTERO a 1,45–1,54
   mentre il suo canale portante stava a 1,67–1,83. La diagnosi si fa
   spegnendo un accento per volta (`provino_verso`, il blocco «RACCOLTO
   senza…»): a tre quarti, `vx` valeva 0,15 di verso perduto, le orecchie
   0,09, il mento 0,03.

**Dove si è arrivati** (gesto intero, dodici colonne): Largo 1,62–1,78 ·
Capo 1,60–1,84 · Rialzo (tenuta) 1,67–1,91 · Raccolto 1,54–1,71 · Rialzo
(picco) 1,56–1,74. **Residuo dichiarato:** i due gesti che portano più
accenti restano 0,06–0,10 sotto il loro canale portante nelle colonne di tre
quarti. La regola operativa è quindi: **il canale PORTANTE deve passare a
ogni azimut, e gli accenti non possono costare più di un decimo.**

### IL PUNTO — se se ne consegna uno solo, è questo

Non perché sia il più bello: perché è **l'unico che fabbrica lo sfondo su cui
gli altri diventano leggibili**, e perché costa **zero canali del rig** —
moltiplica `_move_gait()`, che ha un solo consumatore. Niente da togliere,
niente che possa restare fuori posa.

Il suo segnale non è una forma: è un **contrasto di MOTO**. Misurato
(`provino_verso`, parte 3): la sagoma di un corpo che cammina cambia
472–2949 px per fotogramma; **fermo, sta al livello del rumore del renderer**
— 0 px netti in tre viste su quattro. I rapporti misurabili vanno da **6,8:1
a 27,4:1**.

> ⚠️ **QUELLA MISURA HA TRE PAVIMENTI, e la prima stesura li aveva tutti e
> tre addosso.** (a) L'**erba che ondeggia**: confrontando due fotogrammi
> crudi il fondo dava 15.000 px e il rapporto usciva 1,3:1, cioè «il fermo non
> si vede» — l'esatto contrario del vero. Si spegne il vento e si conta la
> **maschera**, non il fotogramma. (b) L'**antialiasing**: TAA e FXAA fanno
> ballare ogni pixel di bordo, e il bordo di un chibi è dello stesso ordine
> del segnale. (c) Il **dithering del renderer**, ~1% di pixel ovunque: si
> stampa il pavimento accanto al segnale, a quattro soglie. E il riquadro va
> tenuto STRETTO ma non troppo: chi cammina di traverso esce da un riquadro
> stretto in due decimi, e la prima misura dichiarava **zero pixel di moto**
> per «profilo» e «trequarti».

**L'anziano non riceve un secondo fermo.** `_move_gait` ferma già chi ha
`_eta > 0.55` per 1,3 s ogni 7,5 — quello *è* il fermo, e batte il gettone di
villaggio di venti volte. Su un anziano il Punto **non frena**: aspetta il
prossimo fiato (`_in_fiato()`, fonte unica della finestra) e ci veste sopra
il payload; se non arriva in tempo, **silenzio**.

### LE REGOLE CHE NON SI NEGOZIANO

**R1 — Il verso, o non è una parola.** Nessun gesto porta il proprio
significato su un'imbardata. Chi ne aggiunge uno lo fa passare da
`provino_verso` **prima** di scriverlo.

**R2 — Uno per volta in tutto il villaggio, e il gettone ha un PERIODO.**
`Visitors.GESTO_PASSO := 12 s` (accumulatore di villaggio) + `GESTO_RIPOSO :=
300 s` per vicino (±15% dal nome) + `GESTO_RAGGIO := 9 m`. **Chi perde muore
in silenzio, non si accoda**: una coda su ventotto corpi trasforma un picco
(il falò, quaranta pietre di sentiero) in un minuto di pantomima.
> ⚠️ **UN GETTONE SENZA PERIODO È UN MIMO PERMANENTE.** «Uno per volta»
> significa da solo *sempre esattamente un mimo in scena, per sempre*: appena
> uno finisce, il primo che passa prende il posto. `GESTO_PASSO` è l'unico
> numero che può uccidere il lavoro in tutte e due le direzioni, e si tara
> **in partita** (`tools/prova_villaggio_gesti.gd`), mai contro zero.

**IL METRO, in partita** (quattordici residenti, cinque minuti, un giocatore
che cammina e lavora — il banco costruisce le situazioni, non chiama mai
`chiedi_frase` a mano):

| gettone | richieste | rifiutate DAL GETTONE | gesti | simultanei | frazione mimo |
|---|---|---|---|---|---|
| 20 s | 383 | **193 (50%)** | 6 in 5 min | **1** | 1,13% |
| **12 s** | 175 | **26 (15%)** | 4 in 5 min | **1** | 1,41% |

Sei vicini diversi su quattordici, **nessuno due volte**, tutti col giocatore
dentro i nove metri. Il metro di partenza era *sette teste girate in
venticinque minuti*.

> ⚠️ **E LE DUE CORSE NON SONO APPAIATE.** Il numero di RICHIESTE è più che
> raddoppiato fra l'una e l'altra, perché dipende da quante volte il lavoro
> di Mochi trova dei testimoni — cioè dal giro del giocatore, non dal
> gettone. «Sei gesti contro quattro» **non dice niente**. Quello che si
> confronta è la SELETTIVITÀ del gettone rispetto alla domanda della sua
> corsa: a venti secondi il gettone ERA il collo di bottiglia (metà dei no
> erano suoi), a dodici lo sono le condizioni del mondo. **È l'ordine
> giusto: il mondo decide quando un gesto ha senso, il gettone impedisce
> soltanto che se ne vedano due insieme.**

> ⚠️ **UN VILLAGGIO APPENA NATO NON GESTICOLA, E NON È UN GUASTO.** Prima
> versione del banco: quattordici residenti, un giocatore che passeggia, e
> **zero gesti in novanta secondi**. Giusto così — le quattro frasi hanno
> inneschi VERI: la premessa vuole che Mochi FACCIA qualcosa, la rinuncia
> vuole qualcuno che abbia qualcosa da rinfacciarti, l'evitamento vuole un
> posto che qualcuno abbia imparato a temere. **Il silenzio è il
> comportamento normale**, e un banco che non costruisce le situazioni
> misura il proprio prato vuoto.

E il silenzio ha SEI RAGIONI DIVERSE, che da fuori si vedono tutte uguali:
`Visitors.debug_gesti_contatori()` le conta una per una (gettone · riposo ·
fuori raggio · non cammina · passo non a regime · troppo vicino all'arrivo).
Senza quel conto si finisce per accusare il cablaggio quando era il gettone.

**Residuo dichiarato:** in queste corse è partita **solo la premessa**. La
rinuncia vuole Mochi a meno di 2,6 m da chi si trattiene, l'evitamento vuole
che l'agenda scelga proprio il posto marchiato, il pensiero vuole il modello
della Fase 5. Le altre tre frasi sono provate al banco
(`tests/cases/test_gesti.gd`) e in pellicola (`tools/provino_gesti.gd`), **non
ancora in partita**.

**R3 — La ricevuta non è MAI condizionata dal gettone.** Se il turno è
occupato la testa si gira lo stesso, e il gesto semplicemente non parte. Il
degrado va SEMPRE verso il comportamento che c'era già.

**R4 — Un livello TINGE, non posa mai; e ogni coda decade più in fretta del
proprio riarmo.** `arousal` e `regolazione` scendono solo in `passa_giorno`,
cioè quattro minuti reali: una posa legata al loro livello resterebbe accesa
per una giornata di gioco. La coda somatica ha `τ = 2,8` (vita 6 s) contro i
**9 s** di raffreddamento del sussulto — con τ=7 resterebbe accesa il 100%
del tempo su chiunque il giocatore sfiori camminando.

**R5 — Il gesto è la premessa di una conseguenza, o non si fa.** Nessun gesto
di colore, nessun idle arricchito, **il silenzio è il comportamento normale**.

**R6 — Ogni canale ha un padrone, e la rete gira per OGNI stato.**
`_gesto_passo` sta FUORI dal `match`, e `_enter_state` spegne il gesto: senza
quella riga il Punto teneva il ritmo a **zero** dopo il cambio di stato
(misurato in `r_idle` e in `r_pasto`), e il corpo sarebbe rimasto incollato al
terreno al viaggio dopo — invisibile, perché nessun test guarda la velocità.

### LE TRAPPOLE DEL RIG, tutte pagate

1. **La scala vive su `_corpo`, non su `_vis`.** `_vis.scale` ha **cinque
   tween** (ingresso, sonno, risveglio, congedo, pasto) e l'ordine del frame
   è `process_frame → _process → tween`: un togli additivo su un valore
   posato da un tween lo corrompe. `_corpo.scale` ha un solo scrittore,
   `set_cucciolo`, e sta fuori dal `_process`. **Un canale la cui base è
   scritta da un tween si RIFIUTA, non si combatte.**
2. **Una sola rete, non due.** I canali nuovi (`px sy hz hpy vrz ear_dx`)
   entrano nello **stesso** `_rc_appl` della recita: un togli, una somma. Ma
   le due sorgenti restano separate mentre si calcolano — sommare il gesto
   dentro `_rc_cur` (che è lo stato di un filtro) farebbe ripartire la
   postura da dove l'ha lasciata il gesto, con una deriva invisibile.
3. **Le buste sono ESPLICITE, non un passa-basso.** Il dizionario della
   recita fonde ogni canale a 6,0 (90% in 0,38 s): il Rialzo, che vive di
   46 cm/s nel primo decimo, dentro quel filtro sarebbe arrivato a cinque
   millimetri. Il prezzo è che un gesto troncato salterebbe — per quello c'è
   la rampa `Gesti.SPEGNI`, che è la rete e non un secondo filtro.
4. **Il Rialzo non si recita da solo.** Vive INNESTATO: dentro la ripartenza
   decisa del Punto e dentro il rilascio del Raccolto. Una scintilla senza il
   buio prima è una lampadina accesa a mezzogiorno, e un gesto che si recita
   da solo insegna al giocatore che non vuol dire niente.
5. **`DEBITO_MAX` non è 1,20 m.** La sintesi lo diceva, ed è aritmeticamente
   incompatibile con una tenuta di 1,6–2,4 s: a 1,45 m/s fermarsi due secondi
   costa **tre metri**. Con 1,20 il Punto si sarebbe rifiutato **sempre**, e
   il gesto che tutta questa fase esiste per consegnare non sarebbe mai
   partito — con la suite verde, perché nessuna asserzione guarda «è mai
   successo».
6. **`Andatura.misura` usava il MODULO** dello spostamento: la fase avanzava
   anche per un corpo che va indietro — le zampe facevano il passo in avanti
   mentre il corpo indietreggiava. **Non era un rischio futuro: era in
   partita** (`tk_startle` tweena il corpo verso `position + basis.z * 0.7`).
   Adesso c'è il segno; per chi cammina avanti **non cambia un bit**.
7. **`FaceController.head_tilt()` aveva un lettore solo, ed era Mochi.** I
   vicini avevano la faccia giusta sul collo sbagliato da anni. Entra dal
   canale `hz`, così se lo porta via la stessa rete di tutto il resto.

### LE TRAPPOLE DI BANCO (i test e i provini sbagliavano da soli)

- **L'oracolo è un GEMELLO.** Confrontare il rig prima e dopo un gesto non
  prova niente: `Andatura.applica` scrive orecchie e busto **in assoluto** a
  ogni fotogramma, e la differenza misurata era la fase del passo. Undici
  asserzioni rosse su un codice sano — e un test rumoroso lo si finisce per
  allentare finché non dice più niente.
- **…e prima di confrontare si NORMALIZZA il passo.** Quei canali sono
  riscritti **solo negli stati di movimento**: da fermo restano congelati
  all'ultimo fotogramma camminato, e il Punto, che ferma il suo corpo, ha per
  forza una fase diversa (0,116 rad di scarto, su codice sano).
- **La camera ha una molla.** Spostare Mochi e scattare subito produce una
  pellicola che scivola: è sembrata una traslazione del gesto per un minuto
  buono. E a distanza ravvicinata **la testona di Mochi copre esattamente il
  vicino** che si sta guardando — una pellicola intera del Rialzo era dietro
  la protagonista.
- **Il ritaglio lo calcola la CAMERA**, non chi guarda dopo: in una pellicola
  il corpo si sposta (è il punto), e un riquadro fisso finisce per
  fotografare l'erba dicendo «il gesto non si vede».

### QUATTRO GUARDIE CHE NESSUN TEST POTEVA FAR FALLIRE

[`tests/cases/test_gesti.gd`](tests/cases/test_gesti.gd) è comportamentale (un
`Visitor` vero, il `_process` a 60 Hz, si guarda il rig) e ha **quindici
mutazioni** annotate con le asserzioni rosse. Quattro righe, alla prima
stesura, erano **zero rosse**:

- togliere il `* _gs_r` da `_move_gait` — cioè **scollegare il gesto dal
  passo** — lasciava due asserzioni rosse e nessuna diceva la cosa che conta:
  il banco guardava `_gs_r`, che è il numero *prima* di essere usato. Adesso
  si misurano i **metri**, contro un gemello che non si è fermato;
- la **restituzione della scala** e la **rampa di spegnimento**: zero rosse.
  Due guardie che nessun test poteva far fallire, cioè due guardie che non
  c'erano;
- e l'**assestamento della tenuta** — il micro-movimento, cioè la regola che
  questo progetto mette per prima — si poteva azzerare con 582 asserzioni
  tutte verdi. Adesso c'è un caso che cerca un PERIODO nella curva e pretende
  di non trovarlo, **con la controprova**: sullo stesso banco, un `sin()`
  puro il periodo lo fa trovare.

### Come si guarda

```
CHIBI_VERSO=<dir> Godot --path . --resolution 1280x720 \
  --script res://tools/provino_verso.gd          # il CANCELLO (CHIBI_PARTI=1|2|3)
CHIBI_GESTI=<dir> CHIBI_VISTA=profilo CHIBI_DIST=2.6 Godot --path . \
  --script res://tools/provino_gesti.gd          # la PELLICOLA (CHIBI_TENUTE=1)
CHIBI_MINUTI=6 CHIBI_QUANTI=14 Godot --path . \
  --script res://tools/prova_villaggio_gesti.gd  # la PROVA VIVA, e GESTO_PASSO
```


## LA REGIA — quando i gesti succedono, e quando NON succede niente

Il vocabolario del corpo (qui sopra) è un repertorio: sa COME si dice una
cosa. La REGIA è l'altra metà, ed è quella che decide se il villaggio sembra
abitato o sembra un carillon di pupazzi: **quale momento della vita interiore
di un vicino vale il palco, e quanto spesso.**

Vive in [`scenes/npc/Regia.gd`](scenes/npc/Regia.gd) — pura, senza Godot — e
si esegue nell'usciere di `Visitors` (`chiedi_gesto`).

### LE SETTE OCCASIONI, e nessuna casa nuova

Tutte e sette sono momenti che il gioco **simulava già** e che non avevano un
corpo. Zero contatori nuovi, zero campi nel salvataggio, zero dadi: il
vocabolario non può far succedere le cose più spesso, può solo renderle
visibili.

| occasione | frase | dove vive il dato, e da SEMPRE | attesa |
|---|---|---|---|
| `ha_visto` | premessa (Punto molle) | il grafo dei ricordi, via `Percezione._testimonia` | 1,00 |
| `era_per_me` | premessa | `R_SU_DI_ME`, la sola asimmetria del grafo | 0,35 |
| `se_lo_tiene` | pensiero (Punto deciso) | `EcsMondo.cosa_da_ricordare` — la promozione | 0,30 |
| `ha_dedotto` | pensiero | il grafo delle deduzioni (Fase 5) | 0,15 |
| `si_e_trattenuto` | rinuncia (Raccolto→Rialzo) | `Limbico.trattieni()` che torna TRUE | 0,45 |
| `quel_posto_no` | evitamento (il Largo) | `Limbico.evita()` (i marchi) | 0,45 |
| `ah_sei_tu` | **sollievo** (il Rialzo) | `Limbico.rivaluta()` dopo un sussulto | 0,10 |

Più i due LIVELLI, che non prendono il palco: il **capo che pende** e la
**coda somatica**.

### L'USCIERE NON SERVE CHI BUSSA PER PRIMO

`attesa` è la frazione di orologio che dev'essersi consumata perché quella
occasione valga il disturbo. **Uno vuol dire «aspetta tutto il giro».**

L'ordine non è gusto: sta scritto in due colonne che si misurano — quanto
spesso l'occasione capita (più è rara, meno aspetta) e quanto il giocatore
può ricondurla a sé (più gli è addosso, meno aspetta). Le due tirano nella
stessa direzione, perché in questo gioco le occasioni frequenti sono quelle
in cui fai una cosa qualunque a nove metri da qualcuno, e le rare sono quelle
in cui a qualcuno succede qualcosa addosso a te.

> ⚠️ **PERCHÉ NON UNA CODA A PRIORITÀ.** Una coda consegnerebbe il gesto DOPO
> il suo momento, e un gesto separato dalla sua premessa è il guasto che
> tutta questa fase esiste per impedire. **Chi perde muore in silenzio.**

> ⚠️ **DUE SCARSITÀ, UNA REGOLA, UN NUMERO SOLO.** `Regia.palco_libero()` ha
> due chiamanti: il **gettone del villaggio** (12 s: uno per volta, e non
> troppo spesso) e il **riposo della persona** (5 min: non sempre lo stesso).
> Due orologi di durata diversa, la stessa aritmetica. Averne ordinato uno
> solo era un ordine applicato a metà — vedi la misura qui sotto.

### IL SILENZIO HA SETTE NOMI, e si contano tutti

Un banco che dice «zero gesti» lascia indovinare, e si finisce per accusare
il cablaggio quando era semplicemente il palco occupato. `chiedi_gesto` conta
ogni no per nome, e `debug_gesti_contatori()` li stampa: *un altro sta
parlando · palco caldo · riposo · fuori raggio · non cammina · passo non a
regime · già un Punto in questo viaggio · troppo vicino all'arrivo · nessun
buio prima · nessun corpo*.

### LA REGOLA DELL'ATTRIBUZIONE, in tre righe di codice

1. **La premessa segue il RICORDO, non il gesto.** `guarda_gesto` adesso
   *restituisce* se il ricordo era nuovo, e `Percezione` gira quella risposta
   alla regia: nel grafo gesti uguali e ravvicinati fondono in uno solo, e il
   ventesimo sasso di un sentiero non è una cosa vista in più. Senza,
   **il 79% delle richieste erano ripetizioni** e il corpo si fermava quasi
   sempre in mezzo a una raffica monotona invece che sul gesto singolo — che
   è l'unico che si legge. Il numero non si ricalcola: la finestra di fusione
   vive nel C++ e ha **un** lettore.
2. **L'ancora si verifica, o si tace.** `Regia.ancora_valida()`: il ripiego
   di `EcsMondo.dove()` è casa propria, e guardarsi la porta di casa non
   racconta niente a nessuno.
3. **Un gesto rimandato vive quanto la sua premessa.** La sala d'attesa di
   `Visitors` (`_rimanda_gesto`) tiene un'occasione finché il corpo non è
   nelle condizioni — ma la promozione scade con la **testa girata**
   (`Percezione.DURATA_SGUARDO`), che è letteralmente la premessa che il
   giocatore sta guardando, e l'evitamento con i pochi secondi in cui quel
   posto è ancora «quello lì».

### LE SCENE RARE SONO INTOCCABILI

Il concerto, il congedo, il nascondino, il concertino, la prima parola di un
cucciolo, l'appuntamento delle Promesse. Durante una di quelle il corpo non è
suo: è di chi ha scritto la scena.

- `in_scena()` è entrato in `sospeso` dentro `_gesto_passo`: spegne il gesto
  **e i due livelli**. Non è pignoleria — il rallentando moltiplica
  `_move_gait`, cioè cambierebbe i tempi di una coreografia scritta a mano.
- `apri_scena()` spegne il gesto in corso **nello stesso istante**, con la
  rampa: le scene si aprono su un villaggio che stava già vivendo.
- ⚠️ **E L'OROLOGIO DEI LIVELLI GIRA ANCHE DA SOSPESI.** Un livello sospeso
  che non invecchia non è sospeso: è in PAUSA, e riemerge intatto dall'altra
  parte. La coda somatica vive otto secondi; una notte di sonno o un concerto
  di dieci minuti la ritrovavano viva — cioè un vicino che ricomincia a
  essere guardingo per uno spavento di dieci minuti prima, senza nessuna
  premessa che il giocatore possa ancora avere in mente.

### IL SOLLIEVO: il Rialzo che non si recita da solo, e non è un'eccezione

«Ah… sei tu» — il sussulto che si scioglie nel riconoscimento
(`Visitors._tick_riconoscimenti`, la strada veloce e la strada lenta a 0,4 s
di distanza). Era una posa (`si_illumina`) e basta; adesso il corpo **sale
davvero**, quattro centimetri a mezzo metro al secondo.

Il Rialzo non si recita da solo perché una scintilla senza il buio prima è
una lampadina accesa a mezzogiorno. Qui il buio c'è, e **non lo mette la
tabella delle frasi**: è il sussulto, che ha irrigidito quel corpo quattro
decimi di secondo prima. La regola non è affidata a un commento —
`Visitor.gesto()` legge il CORPO (`_sussulto_fresco()`) e si rifiuta se il
buio non c'è: nessun chiamante può prendersi quel gesto barando.

> ⚠️ **E SENZA UN'ECCEZIONE NON SAREBBE MAI PARTITO.** `trasalisce` dura
> 1,3 s e il riconoscimento arriva dopo 0,4: il sollievo cade **sempre**
> dentro il transitorio del sussulto, cioè dentro la valvola che tiene il
> vocabolario fuori dai riflessi. L'eccezione è stretta a quel transitorio e
> a quel gesto, e un caso di test prova che non si allarghi.

### IL CAPO CHE PENDE HA TRE CAUSE, e non è un cruscotto

Non ho più forza di trattenermi (`Limbico.regolazione`) · sono di malumore da
giorni (`umore`, la stessa soglia di `stato_corpo()`) · ho una cosa in testa
che non ho ancora detto (una deduzione muta). Una sola causa sarebbe un gesto
che mappa uno-a-uno su una variabile interna, cioè la legenda che un
giocatore attento impara in tre ore. E senza modello linguistico la terza è
sempre falsa: restano le prime due, cioè il gioco è identico.

`CAPO_MAX = 2` in tutto il villaggio, e **il tetto conta le TESTE, non le
righe di un registro.** Il rollio ha due padroni — `Visitors._tick_capo` (un
LIVELLO che dura minuti) e `Visitor.frase("pensiero")` (che dura quanto il
gesto) — e i due non si parlavano: il registro concedeva i suoi due posti e
la frase ne accendeva un terzo che nessuno contava. MISURATO nel MainLevel
vero ([`tools/misura_capi.gd`](tools/misura_capi.gd), dodici residenti, tre
minuti di partita): **tre teste storte insieme per il 5,4% del tempo**, col
registro che ne dichiarava due e **282 fotogrammi di divergenza**. E dopo un
passaggio dal Salone di bellezza (`rifai_il_look` → `gesto_spegni(true)`, il
ramo che usciva prima di arrivare alla riga che spegneva il capo) una testa
restava inclinata **per sempre**: 5,9° trentacinque secondi dopo, e ancora in
movimento.

- il bit che il rig legge è **DERIVATO** (`_gs_capo_liv or _gs_capo_frase`) e
  ogni padrone scrive solo il suo: la fine di una frase non spegne più il
  pensiero del villaggio, e il villaggio non tronca più una frase a metà;
- il conto è **derivato dal mondo** (`Visitors.capi_storti()`): niente
  registro da tenere allineato e niente da potare — il posto di chi parte col
  fagotto si libera da sé, nello stesso istante;
- si contano le teste **come le vede il giocatore**: una a cui il livello è
  appena stato tolto è ancora storta finché la molla non rientra
  (`Visitor.CAPO_STORTO`, 1,1°). Senza, la terza testa compariva mentre la
  prima tornava su — misurata a **4,7° di media**, cioè il rollio quasi
  pieno: i BIT non sono il RIG, ed è la stessa divergenza un piano più giù;
- e la RETE che spegne il capo di una frase finita gira in `_gesto_passo`,
  **per OGNI stato** — non nei due o tre posti che vengono in mente — e
  guarda `gesto_in_corso()`, non `_gs_nome`: sull'anziano il Punto aspetta il
  suo fiato, e per qualche decimo di secondo la frase è partita senza che
  nessun gesto sia acceso.

Dopo, sullo stesso banco: **zero fotogrammi con più di due teste storte** in
tre minuti di partita (erano 9,7 s), il tetto che tiene anche con dodici
vicini che ci pensano tutti, e la testa dell'estetista dritta in **0,03 s**.
La guardia è nei casi 12–12d di
[`test_regia.gd`](tests/cases/test_regia.gd), con dodici mutazioni tutte
rosse: quella di prima asseriva su `_gesto_capi.size()`, cioè sul REGISTRO,
mentre l'invariante scritta parla di TESTE — **un test che guarda il registro
invece del mondo è verde mentre il mondo è rotto**.

### QUANTI GESTI AL MINUTO, MISURATO

`tools/prova_villaggio_gesti.gd`, **28 residenti, 10 minuti**, un giocatore
che lavora (raffiche vere, come il BuildSystem che emette un gesto per pezzo),
va a trovare qualcuno una volta su tre e **si ferma** quando arriva:

| | |
|---|---|
| ⇒ **gesti al minuto in tutto il villaggio** | **2,10** (uno ogni 28,6 s) |
| un dato vicino ne fa uno ogni | 13,3 min |
| vicini diversi che hanno gesticolato | 15 su 28 (il più prolifico: 3) |
| **simultanei, massimo** | **1** — sempre |
| col giocatore dentro i nove metri | **21 su 21** |
| frazione di secondi-vicino dentro un gesto | **1,36%** (tetto del mimo: 15%) |
| frasi viste | Punto 9 · Rialzo 8 · Raccolto 4 |

Il metro di partenza era **sette teste girate in venticinque minuti** (0,28 al
minuto), e la testa continua a girarsi come prima: questi 2,10 sono in più.

**E la regia si legge in una tabella sola** — chieste contro concesse:

| occasione | chieste | concesse | quota del palco |
|---|---|---|---|
| `ha_visto` | 781 | 6 | 0,8% delle sue richieste |
| `era_per_me` | 36 | 1 | |
| `se_lo_tiene` | 26 | 2 | |
| `si_e_trattenuto` | 9 | 4 | **44%** |
| `ah_sei_tu` | 16 | 8 | **50%** |

L'occasione che bussa il **90%** delle volte si prende il **29%** del palco;
le due più rare e più attribuibili ottengono metà di quello che chiedono.

⚠️ **E IL PRIMA NON È APPAIATO — lo dico prima che qualcuno ci creda.** Con
il palco ordinato e il riposo no, il referto diceva **13 gesti, 13 su 13
`ha_visto`, zero di tutto il resto**; ma fra quella corsa e questa il banco è
cambiato tre volte (la velocità di Mochi, la sosta, la popolazione del
morso), quindi «13 contro 21» **non dice niente**. Quello che si può
confrontare è la FORMA della distribuzione dentro la corsa: là una sola
occasione su cinque arrivava al corpo, qui cinque su cinque. La misura
appaiata vera sarebbe una leva A/B dentro la stessa corsa, e non c'è: è il
residuo di metodo di questa fase.

**I residui, dichiarati:**

- **`quel_posto_no` non è mai stato chiesto** in nessuna delle corse. Vuole
  che il pianificatore mandi un vicino MARCHIATO proprio in quel luogo, e in
  dieci minuti di banco non è capitato. È cablato e provato al banco, non
  ancora visto in partita.
- **La sala d'attesa riprova a ogni fotogramma** (2.194 riprove in dieci
  minuti, cioè 3,5 al secondo): sono un `node_di` e una `frase()` rifiutata.
  Misurabile, non misurato — se un domani costasse, la cadenza è la manopola.
- **`ha_dedotto` è a zero senza modello linguistico**, ed è la regola della
  Fase 5: la sua gemella `se_lo_tiene` è la ragione per cui il «pensiero» si
  vede lo stesso.

### LE TRAPPOLE DI BANCO, tutte pagate misurando

Tre volte su quattro, un'occasione a zero **era colpa del banco**, e ogni
volta il referto la dichiarava come un silenzio del gioco:

1. **Mochi camminava a 2,6 m/s**, cioè più piano di quanto un giocatore possa
   camminare (`PlayerController`: 3,0 a passo, 6,0 di corsa). La strada
   veloce del Limbico guarda proprio COME arrivi (`indizio_grezzo` non vede
   niente di brusco sotto 1,6 m/s): a 2,6 la forza del sussulto vale 0,13
   contro una soglia di 0,22 — **nessuno sussultava mai**. Le velocità si
   leggono dal giocatore vero, non si scrivono.
2. **Passava e ripartiva.** Il morso trattenuto ha 12 s di raffreddamento e
   il sussulto 9: sfiorando qualcuno a sei metri al secondo la finestra è di
   mezzo secondo. Adesso, quando arriva, **si ferma due secondi e mezzo** —
   che è quello che fa un giocatore.
3. **Preparava la popolazione IMPOSSIBILE.** Per provare «si è trattenuto e
   ce l'ha fatta» il banco consumava cinque morsi, cioè fabbricava
   esattamente chi la forza NON ce l'ha più — il ramo in cui `trattieni()`
   torna falso. Chiedeva zero e otteneva zero.
4. E il **passo del banco era 1/60 fisso** mentre la scena ne disegna 25:
   muovendo Mochi di `6.0/60` per fotogramma il gioco misurava 2,5 m/s. Una
   misura che non sa che ora è non misura niente.

### Come si guarda

```
CHIBI_MINUTI=10 CHIBI_QUANTI=28 Godot --path . --resolution 1280x720 \
  --script res://tools/prova_villaggio_gesti.gd   # i GESTI AL MINUTO, e le occasioni
CHIBI_SOLLIEVO=<dir> Godot --path . --resolution 900x600 \
  --script res://tools/provino_sollievo.gd        # «ah… sei tu», tre azimut
```

`provino_sollievo` **non spara il gesto a mano**: muove solo il giocatore, e
tutto il resto è il gioco — il sussulto vero, la strada lenta vera, l'usciere
vero. Se il cablaggio non ci fosse, quella pellicola sarebbe un chibi fermo.
Misurato: sussulto a 7,0 s, il Rialzo parte a **0,56 s** dal sussulto con
`vy = +0,050` e `sy = 1,037`, e a confronto fotogramma per fotogramma (stessa
camera, stessa ombra) il corpo è visibilmente più alto e le orecchie sono
passate da indietro a su.


## LA GIOIA NON PORTA LA FACCIA DELLA PAURA

La strada veloce del `Limbico` ha due risposte — **chi ti teme trasalisce, chi
ti vuole bene si illumina** — e il commento di `_tick_sussulti` chiama la
seconda «il segnale più onesto che il giocatore riceve». Per un giorno intero
quel segnale ha avuto addosso la faccia della paura, per tre difetti diversi
che tiravano tutti dalla stessa parte.

### 1 · LA CODA GUARDINGA SEGUIVA TUTTE LE REAZIONI

`somatico(forza)` stava **prima** del `match`, quindi la coda somatica — che è
la posa dell'allarme: orecchie GIÙ, braccia chiuse, coda irrigidita, corpo
rimpicciolito, passo al 72% — si posava anche sopra il cuoricino, e perfino
sopra i percetti che non producevano nessuna reazione.

MISURATO nel villaggio vero ([`tools/misura_sussulti.gd`](tools/misura_sussulti.gd),
28 residenti, 8 minuti, Mochi che cammina e lavora come un giocatore):

| | percetti | la coda si ARMA | | percetti | la coda si arma |
|---|---|---|---|---|---|
| | **prima** | | | **dopo** | |
| `trasalisce` | 4 | 4 (100%) | | 13 | 10 (77%) |
| `si_illumina` | **48** | **45 (94%)** | | 0 | — |
| `nulla` | 129 | **91 (71%)** | | 129 | **1 (1%)** |

**La gioia è dodici volte più frequente della paura** (48 contro 4): il livello
«guardingo» stava addosso a chi ti vuole bene molto più che a chi ti teme. E
il rallentando — l'unica cosa del vocabolario che arriva ai vicini lontani —
restava acceso il **41,6%** dei secondi-vicino, contro il **5,4%** di adesso.
La coda visibile: 7,2% → 1,1%.

### 2 · L'ARITMETICA: una moneta sola, e tutta fatta di paura

`forza` usciva da `(absf(carica) + grezzo) × reattivita × (1 + arousal·0,6)`, e
tutti e tre gli ingredienti sono dell'ALLARME — il valore assoluto del marchio
mette la paura e l'affetto sulla stessa scala; `reattivita` è per definizione
il guadagno della paura («la codardia lo alza, la grinta lo abbassa»);
l'ultimo è l'allerta che si autoalimenta. Conseguenze misurate:

- **un amico dopo sei incontri felici valeva 0,600, PIÙ di uno sconosciuto
  caricato di corsa (0,394)**: chi ti vuole bene reagiva più forte di chi si è
  spaventato;
- quella forza alzava l'`arousal`, che in questo gioco ha un vocabolario solo
  («ancora guardingo», «col cuore in gola») e un consumatore che cambia il
  gioco: `Visitors._spiega_come_sta` toglie il saluto felice a chi ha il corpo
  scosso e ci mette una nuvoletta di puntini. **Un solo regalo** portava
  l'arousal a 0,315, cioè oltre la soglia: fare un regalo a qualcuno e
  vederselo restituire con un «…»;
- e `si_illumina` era il ramo **di serie** — bastava superare la soglia e non
  avere niente di brusco — quindi una camminata addosso (0,185 di bruschezza)
  faceva comparire un cuoricino sopra la testa di chi non ti aveva mai visto:
  **45 cuoricini su 48 senza nessuna storia dietro**.

Adesso ci sono **due monete**: l'`allarme` (solo la carica NEGATIVA più la
bruschezza, coi suoi guadagni) e il `calore` (la carica positiva, e basta).
`forza` è l'allarme e solo l'allarme — una gioia ne ha **zero** — e la stessa
regola vale sulla strada lenta: `rivaluta` pompa l'attivazione con
`maxf(0, −sorpresa)`, così la delusione e il tradimento scuotono il corpo e un
regalo no.

**Il cuoricino adesso si guadagna**, e la porta esiste già: un piatto, una
festa, un accompagnamento (`Visitors.gesto_gentile` → `Animo.ricorda` →
`rivaluta`) lasciano un marchio di 0,44 sul giocatore, sopra la soglia. Un
gesto gentile solo, e da lì in poi quel vicino ti si illumina quando arrivi.

### 3 · «IL RIALZO LA SCIOGLIE» — una promessa che non manteneva nessuno

`Gesti.FRASI` lo scriveva a chiare lettere: *il corpo si è irrigidito davvero
— la coda somatica è accesa e si vede — e il Rialzo la scioglie*. Non la
scioglieva niente: dopo «ah… sei tu» il vicino restava guardingo per altri
otto secondi di posa e **settantaquattro** di passo rallentato. Un sollievo
che non scioglie niente non è un sollievo: è una seconda posa sopra la prima.

Adesso `Gesti.coda_rilascio` moltiplica la FORZA (così i due strati mollano
insieme, senza una seconda composizione da tenere allineata) e `Visitor.
soma_sciogli()` è la sorella di `somatico()`. **La rampa è `Gesti.SPEGNI`**, la
stessa con cui si mette giù un gesto troncato: in questo progetto, quando
qualcosa si molla, si molla così — un secondo tempo di rilascio scritto lì
sarebbe una costante gemella da tenere allineata a mano. E non taglia: un
livello che sparisce in un fotogramma è un salto del rig, e sarebbe il salto
peggiore possibile, perché arriva nell'istante in cui il giocatore ha quel
corpo in faccia a due metri.

### LE REGOLE, per chi ci torna

1. **La coda somatica è la faccia della PAURA.** Sta dentro il ramo di chi ha
   trasalito, e ci sono **due guardie indipendenti**: il cablaggio (`Visitors`)
   e l'aritmetica (`Limbico`, dove una gioia non ha forza d'allarme da
   passare). Romperne una sola non riapre il difetto — le mutazioni lo
   dimostrano, e fanno arrossire asserzioni diverse.
2. **`arousal` è l'allarme: lo alza solo ciò che allarma.** Vale sulle due
   strade. Ha un vocabolario solo, e quel vocabolario è di paura.
3. **Un cuoricino deve dire una cosa che è successa.** Un cuore che il
   giocatore non sa ricondurre a niente non attenua l'affetto vero: lo rende
   illeggibile. È la stessa regola del taccuino del Gufo e della ricevuta
   della Fase 5.
4. **La paura non è cambiata di un bit**, ed è dimostrato su una griglia
   (`test_gioia._la_paura_non_e_cambiata`, 270 spaventi veri contro la formula
   di ieri scritta nel test): `maxf(0, −carica)` è `absf(carica)` quando la
   carica è negativa. Se cambiasse anche lei non sarebbe una correzione, ma
   una taratura nuova con dentro una correzione.
5. **Le altre sei `si_illumina` del gioco** (il Salone, il Concerto, le
   Promesse, l'Accompagnare, la visita serena) non sono state toccate e
   guadagnano lo stesso: capitano tutte col giocatore a meno di 3,5 metri —
   cioè dentro il raggio del percetto — e due di loro non aprono nessuna
   scena, quindi la coda ci si posava sopra.

### Come si guarda

```
CHIBI_MINUTI=8 CHIBI_QUANTI=28 Godot --headless --path . \
  --script res://tools/misura_sussulti.gd    # i NUMERI: chi arma la coda, e perché
CHIBI_GIOIA=<dir> Godot --path . --resolution 1280x720 \
  --script res://tools/provino_gioia.gd      # le due lastre: si vede o non si vede
```

[`tools/misura_sussulti.gd`](tools/misura_sussulti.gd) ha un **oracolo
indipendente**: non chiede a `Visitors` se ha acceso la coda, legge il CORPO
(`_gs_soma`, `_gs_soma_t`) e a parte il `Limbico`, e rileva il percetto dal
salto all'insù del raffreddamento. ⚠️ E guarda **l'orologio**, non il livello:
«acceso da poco» sbaglia in silenzio ogni volta che la coda di prima brucia
ancora più forte — la prima stesura sottocontava del 30%.

[`tools/provino_gioia.gd`](tools/provino_gioia.gd) mette **tre corpi identici
nello stesso fotogramma** (due corse sarebbero due villaggi): la posa della
gioia con la coda addosso, la posa da sola, e il riposo. MISURATO, orecchie
applicate al rig (negativo = SU):

| istante | A · con la coda | B · senza |
|---|---|---|
| 0,00 s | **+0,258** (giù) | −0,004 |
| **0,17 s** (il cuoricino) | **+0,150** (giù) | **−0,099** (su) |
| 0,45 s (il colmo) | −0,244 | **−0,473** |
| 0,90 s | −0,392 | **−0,591** |

Segno OPPOSTO nell'istante in cui compare il cuoricino, e **al colmo della
posa la gioia vale la metà**. La seconda lastra fa la stessa cosa col
sollievo: due corpi che hanno sussultato davvero, e a uno solo arriva il
riconoscimento — a 0,30 s le sue orecchie sono a −0,583 e la coda è a zero,
mentre il gemello è ancora a +0,274 con la coda a 0,800.

⚠️ **E QUEL PROVINO SI ERA ACCECATO DA SOLO.** La prima stesura chiedeva la
forza di ieri al `Limbico` VIVO — che dopo la cura risponde **0,000**, perché
una gioia non ha forza d'allarme: il corpo A riceveva `somatico(0)` e la
lastra mostrava due corpi identici, cioè un difetto che non esiste più
sembrava non essere mai esistito. Un provino che chiede al codice curato di
rifare il difetto misura la cura. La forza di ieri è una **misura**, e sta
scritta nel file con la sua provenienza.

## IL PROVINO DEL VOCABOLARIO — l'unica fase che decide se quel lavoro esiste

Il vocabolario del corpo (sopra) e la regia (sopra) sono stati **guardati**,
uno per uno, alle distanze vere e dai quattro lati, nel MainLevel vero e con
la camera vera del gioco: [`tools/provino_vocabolario.gd`](tools/provino_vocabolario.gd).
Da lì escono due correzioni misurate e sette verdetti onesti — uno per gesto,
compreso quello che dice «questo qui, a nove metri, non c'è».

### LO STRUMENTO, e le cinque regole che chiudono cinque modi di mentirsi

1. **La camera è quella VERA.** `Player.tscn`: 2,70 m sopra Mochi, 3,70
   dietro, inclinata di 28°, fov 50, e **senza imbardata**. Una macchina
   piazzata a un metro dal muso risponde a una domanda che nessun giocatore
   si fa.
2. **Il ritaglio non bara.** Nella lastra delle distanze il riquadro è di
   **pixel fissi** (195 su un fotogramma da 1920×1080), non «tanti quanti ne
   occupa il corpo»: a due metri il chibi riempie la tessera, a nove ne
   occupa un quarto — che è quello che vede chi gioca. Un ritaglio che scala
   col corpo mostra un gesto leggibile a nove metri che in partita non
   esiste.
3. **L'azimut si CALCOLA.** Il vicino sta di lato rispetto a Mochi (o la sua
   testona lo copre): «di profilo» rispetto alla camera **non** è `yaw = 90°`
   — è un errore di dieci-diciassette gradi, e si porta via proprio la
   colonna che si sta misurando. L'angolo si prende fra la direzione
   *camera → corpo* e il muso.
4. **Il tempo si rallenta, non si campiona a caso.** `Engine.time_scale` a
   0,35: il gioco gira identico e il provino può chiedere il fotogramma a
   0,12 s dall'inizio. Il colmo del Rialzo dura un decimo di secondo — a
   venticinque fotogrammi al secondo, a velocità piena, quel fotogramma **non
   esiste**.
5. **Il gesto vecchio sta nella stessa matrice, e nel suo caso migliore** (il
   bersaglio a 90°, cioè la testa al tetto dei 44°). Un confronto in cui il
   termine di paragone è messo male non è un confronto.

E **tre riquadri diversi, perché i gesti non sono tutti della stessa specie**:
fermo sul corpo (le pose), **fermo sul MONDO** (chi si ferma: il Punto è la
sua traversata, e un riquadro che insegue il corpo cancella esattamente il
segnale), e **fermo sulla strada che il corpo avrebbe fatto senza il gesto**
(chi continua a camminare: il Largo e il rallentando, dove la notizia è lo
SCARTO).

### I SETTE VERDETTI, guardati

| | 2 m | 6 m | 9 m | di SPALLE | mimo? |
|---|---|---|---|---|---|
| **ricevuta** (la testa che si gira) | sì | solo di fronte | **no, da nessun lato** | **no** | — |
| **premessa · pensiero** (il Punto) | sì | **sì** | **sì** | **sì** | no |
| **rinuncia** (il Raccolto) | sì | **sì** | **sì** | **sì** | no |
| **sollievo** (il Rialzo) | sì | sì | debole | sì (le orecchie) | no |
| **evitamento** (il Largo) | sì (dopo la cura) | sì (dopo) | debole | debole | no |
| **il Capo** (livello) | sì, anche di spalle | debole | **no** | sì a 2 m | no |
| **la Coda** (livello) | sì | sì | debole | sì | no |

- **La ricevuta di ieri è confermata dal vero, con un altro strumento.** Nella
  pellicola a sei metri, di **profilo** e di **spalle**, i sette fotogrammi
  del gesto sono **la stessa immagine**; a nove metri non cambia niente da
  nessuno dei quattro lati. Il numero della sintesi (verso 0,67–1,11) non era
  pessimismo: è quello che si vede.
- **IL PUNTO È IL GESTO DI QUESTO VOCABOLARIO.** Nella lastra del moto — otto
  istanti, riquadro fermo sul mondo — il corpo entra da un bordo, sta **fermo
  in quattro tessere consecutive**, e riparte. Succede identico a due, a
  quattro, a sei e a nove metri, e **di spalle come di fronte**: è l'unico
  segno del gioco che sopravvive all'inquadratura che oggi non dice niente. E
  costa zero canali del rig.
- **Il Raccolto è l'unica POSA che regge a nove metri**, da tutti e quattro i
  lati, e regge per la ragione giusta: un solido di rotazione non ha
  orientamento ma ha una **proporzione**, e la proporzione si vede da
  ovunque. Nella coppia riposo|gesto a nove metri il corpo è visibilmente più
  basso e più largo, con le orecchie cadute.
- **Il sollievo funziona perché il buio c'è davvero**: nei fotogrammi prima
  le orecchie sono ripiegate all'indietro (la coda somatica del sussulto) e
  in tre decimi di secondo tornano su, dritte, col corpo che sale. **Di
  spalle si legge**, ed è l'orecchio a dirlo.
- **Il Capo si legge a due metri — anche di spalle** (le due orecchie che si
  inclinano insieme sono un segno pulito) — **a sei è debole, a nove non
  c'è.** È un LIVELLO e resta dichiarato così: si nota quando ci si avvicina
  a qualcuno, non attraverso il prato. **Non gli si alza l'ampiezza**: questo
  progetto ha già misurato che il verso di un rollio *cala* crescendo. La
  strada giusta, se un giorno lo si vorrà chiudere, è quella del Raccolto —
  una componente di **silhouette** (la testa che affonda nelle spalle), non
  una rotazione più grossa.

### LA CURA GROSSA: due gesti su tre non li vedeva nessuno

**MISURATO** (parte V del provino: venti residenti, otto minuti, un giocatore
che cammina e lavora — e ogni gesto concesso viene confrontato col frustum
della camera vera):

| | gesti concessi | nell'inquadratura | fuori |
|---|---|---|---|
| prima | 12 | 4 | **8 (67%)** |
| dopo | 6 | **6** | **0 (0%)** |

Il raggio dei nove metri era un'**approssimazione della visibilità**, e in
questo gioco approssima male: la camera non ha imbardata e il giocatore non
la può girare, quindi **buona parte del cerchio dei nove metri sta dietro la
macchina da presa**. Un gesto che parte lì consumava il gettone del villaggio
(12 s) e il riposo di quella persona (5 minuti) per mostrare una cosa che
nessuno poteva vedere in nessun modo — cioè non era neutro: **rubava il palco
a quelli che si sarebbero visti**. Era la regola 4 della `Regia` scritta nel
commento e non nel codice.

Adesso c'è `Visitors._nell_inquadratura()`, una riga sopra `frase()`. I gesti
che il giocatore VEDE passano da **quattro a sei**, e il totale scende perché
un'occasione fuori campo muore in silenzio — che è quello che deve fare.

> ⚠️ **IL DEGRADO VA VERSO QUELLO CHE C'ERA: senza camera si passa.** Le
> suite headless, i banchi, il diorama del titolo non hanno un `Camera3D`
> corrente e non cambiano di un bit. Spegnere una funzione per una domanda a
> cui non sappiamo rispondere è il degrado dalla parte sbagliata. Le due
> mutazioni sono rosse: togliere il cancello ne arrossisce **3**, invertire
> il degrado (nessuna camera → nessun gesto) ne arrossisce **10**.

> ⚠️ **E LE DUE CORSE NON SONO APPAIATE.** Appena il comportamento cambia i
> due villaggi divergono, quindi «12 contro 6» non dice niente da solo.
> Quello che si confronta è la FRAZIONE dentro la propria corsa: 33% contro
> 100%.

### LA CURA PICCOLA: il Largo non aveva un canale di TEMPO

Era l'unico evento del vocabolario il cui carico utile si misura **solo
contro la riga che il corpo avrebbe fatto**: nove centimetri di scostamento e
cinque gradi di inclinazione. Ma quella riga il giocatore non ce l'ha. Il
Punto si legge perché un corpo fermo si confronta col corpo di prima; un
corpo che cammina nove centimetri più in là non si confronta con niente —
**guardato**, con `dip = 0` le otto tessere della striscia sono la stessa
immagine, a sei metri, di tre quarti e di spalle.

Adesso il Largo **esita**: `Gesti.LARGO_DIP = 0.45` dimezza il passo per due
decimi di secondo *prima* di scostarsi, e poi il corpo riprende e va via un
filo più svelto. Scelto su **cinque varianti affiancate ed etichettate**
(A com'è · B esitazione 0,45 · C inclinazione 0,15 · D le due insieme ·
E esitazione 0,70): C non aggiunge niente a sei metri, **E diventa una
fermata** — cioè la parola del Punto, detta male — e B è quella che si vede
restando un'esitazione. Costa sedici centimetri di strada, e il Largo
continua a guadagnarne più di quanti ne perda.

La guardia è `test_gesti._il_largo_esita_prima_di_scostarsi`, e sorveglia la
FORMA con tre numeri che non sono suoi: c'è (< 0,85), non è una fermata
(> 0,40 — e la soglia è 0,40 e non 0,30 apposta, o la variante scartata
sarebbe passata per un centesimo), è già finita quando il corpo si scosta.

### LE TRAPPOLE DI BANCO, tutte pagate

1. **DA QUANTO INDIETRO PARTE IL CORPO È UN CONTO.** Fra il `_walk_to` e
   l'accensione del gesto passano l'assestamento e tutto il pre-rullo della
   pellicola: a 1,45 m/s sono **tre metri**, e la prima stesura ne concedeva
   1,6. Il corpo arrivava un metro e mezzo oltre il punto inquadrato e
   continuava ad andarsene: a sei metri, di profilo, **usciva dal
   fotogramma**, e la tessera veniva fuori mezza nera. Un provino che perde
   il corpo non dice «il gesto non si vede» — non dice niente.
2. **UN RIQUADRO CHE INSEGUE IL CORPO CANCELLA IL PUNTO.** È il gesto il cui
   segnale È lo spostamento: centrandolo su di lui, la striscia diventa una
   successione di fotogrammi identici. Il riquadro sta fermo sul MONDO.
3. **…E PER CHI NON SI FERMA NON PUÒ STARE FERMO NEMMENO QUELLO.** Il Largo e
   il rallentando attraversano un riquadro fisso in mezzo secondo. Il loro
   riquadro insegue **la strada che il corpo avrebbe fatto senza il gesto**.
4. **LA CHIAVE DI UN CENSIMENTO È IL CORPO, NON IL NOME.** Con diciannove
   residenti due etichette si ripetono, e la riga che spegne il segno «sta
   gesticolando» lo spegneva a un OMONIMO: ogni gesto veniva ricontato a ogni
   fotogramma. **150 «gesti» dove l'usciere ne aveva concessi 17.** Un banco
   che conta male non dice una cosa un po' sbagliata: dice una cosa che non
   esiste.
5. **La testona di Mochi copre il vicino.** A dodici gradi di scostamento
   laterale entra nel riquadro da sotto e a due metri lo riempie per un
   quarto. A ventitré gradi il vicino sta a due terzi di schermo, dentro
   l'inquadratura vera e fuori dalla testona — che è poi quello che fa un
   giocatore quando guarda qualcuno.

### I RESIDUI, dichiarati

- **`premessa` e `pensiero` si leggono come UN gesto solo.** La differenza —
  ripartenza molle contro decisa, più il Rialzo innestato — si vede a due
  metri e si perde a sei. Non è un guasto (il significato lo porta il
  contesto, non il corpo), ma «quattro frasi» in scena sono **tre corpi
  distinti più una variante**.
- **IN MEZZO A UNA FOLLA, UN CORPO FERMO NON SPICCA.** La premessa del Punto
  è «venti corpi che camminano sono il riferimento» — ma in un villaggio vero
  la maggioranza dei vicini in un dato istante *non* cammina: sta seduta,
  chiacchiera, oziona. Guardando due fotogrammi pieni a 1,25 s di distanza
  **non sono riuscito a dire quale dei nove chibi in campo stesse
  gesticolando**. In movimento il giocatore ha molto più di due fotogrammi, e
  una decelerazione a mezzo metro da sé è saliente in modo che una coppia di
  istantanee non può mostrare: ma il residuo resta, e la misura che manca è
  «quanti vicini camminano davvero, in media, dentro l'inquadratura».
- **Il giocatore si occlude da solo.** In un villaggio costruito fitto, i
  tetti e le spalliere dei letti coprono i corpi: due gesti su sei di una
  corsa erano dietro qualcosa. Il cancello dell'inquadratura non lo sa (prova
  il frustum, non la visibilità).
- **`quel_posto_no` continua a non essere mai stato visto in partita**, quindi
  l'esitazione del Largo è provata al banco e in provino, non sul campo.
- E il provino **non prova un solo canale in movimento continuo**: giudica
  pellicole di fotogrammi fermi, che è il metro più severo dei due.

### Come si guarda

```
CHIBI_VOC=<dir> Godot --path . --resolution 1280x720 \
  --script res://tools/provino_vocabolario.gd
#   CHIBI_PARTI=D  le distanze (4 distanze × 4 lati, riposo|gesto)
#              F   la pellicola a 6 m · G il dettaglio a 2 m
#              M   il contrasto di MOTO (solo chi cammina)
#              X   le VARIANTI affiancate · V il villaggio vivo
#   CHIBI_SOLO=premessa,rinuncia   CHIBI_VISTE=profilo,spalle
python3 tools/sinossi_vocabolario.py <dir> 9      # tutti i gesti, una lastra
COPPIE=1 python3 tools/sinossi_vocabolario.py <dir> 9   # riposo|gesto appaiati
```


## LE CRICCHE, e la nozione di INSIEME che mancava al motore

Tre vicini che da qualche giorno finiscono nello stesso angolo alla stessa
ora non hanno deciso niente: **si trovano**. Il predicato che lo riconosce
sta in [`scenes/npc/Cricche.gd`](scenes/npc/Cricche.gd); la metà che glielo
rende possibile sta nel punteggio del C++ e in `Visitors`, ed è arrivata
dopo — perché il predicato era giusto e **il villaggio non gli dava da
mangiare**.

### La cricca è un PREDICATO DERIVATO, come `coppia()`

Non esiste da nessuna parte un dato «sono un gruppo». Esiste un **elenco
datato di incontri** — chi, con chi, che giorno, a che ora, in che punto — e
tutto il resto si rilegge da lì ogni volta. Niente da tenere sincronizzato,
nessun salvataggio da migrare, e soprattutto: **la dissoluzione non è un
evento.** Non c'è nessuna riga «si sono lasciati», nessun contatore che
scende, nessuna posa da togliere. Una cricca smette di esistere come si
smette di passare da un posto.

**Il dato non è nuovo: oggi finiva nel cestino.** `Visitors._chats`
costruisce ogni 3,5 s la lista di TUTTE le coppie entro `VICINI` in uno stato
chiacchierabile, e ne usa UNA. Quella lista *è* la co-presenza del villaggio,
già filtrata e già pagata.

**E la riga non ha un VERSO** (i due nomi in ordine alfabetico, cioè in un
ordine che non vuol dire niente): da una riga senza verso non si ricava chi
cercava chi, quindi non si ricava un giudizio. È l'opposto esatto di
`Affetti.ASIMMETRIA`, ed è voluto — l'asimmetria è la grammatica
dell'AFFETTO, non quella dell'ABITUDINE. Per la stessa ragione la riga **non
va in `Affetti._righe`**: lì dentro cambierebbe `conto()`, quindi
`il_piu_caro()`, quindi `coppia()`.

⚠️ **E si conta solo dove si va da sé.** Al falò i posti li assegna
`_posto_al_falo(i)`, cioè l'ordine in cui la gente ha traslocato: le cricche
che ne uscirebbero sarebbero clique **per costruzione** `(i, i+1, i+2)`, e
passerebbero ogni collaudo. Il falò resta il posto dove una cricca si VEDE,
mai quello dove si CONTA — i quattro cancelli stanno in
`Visitors._segna_incontro`, e uno di loro è `LEASE_SPONTANEO` (vedi sotto).

### L'INSIEME — la nozione che l'utility AI non aveva

Ventotto vicini risolvevano ventotto argmax separati. Nessun termine, in
nessuna delle otto azioni, guardava **dove sono gli altri**: la co-presenza
era una coincidenza, le coincidenze sono rare, e le triadi non nascevano.
Misurato: **22 giornate, sei coppie che si ritrovano, ZERO cricche.**

> **`insieme` = «il posto che sceglierei ha, entro `VICINI`, qualcuno che ci
> È SEDUTO ADESSO».**

Tre proprietà strutturali, e nessuna è una taratura:

- **è un POSTO, non un corpo.** Un'ancora che insegue un corpo è un corteo;
  una seduta non cammina.
- **è un FATTO DEL MONDO, non un'intenzione.** Chi *cammina verso* una
  seduta non conta — vedi la trappola dello stallo, più sotto.
- **ha una CAPIENZA DI FALEGNAMERIA.** Per essere «accanto» bisogna occupare
  un `Posto*` fratello: una panchina isolata contribuisce zero, il Gazebo
  tre, la Gradinata quattro. **Il tetto al grumo è quanti sgabelli ha
  costruito il giocatore**, non un numero in un file.

Dove vive: `F_INSIEME` (bit 13) in [`src/sistema_agenda.h`](src/sistema_agenda.h),
quarto fattore **in coda** alla riga `AZ_RIPOSO`; il fatto lo calcola
`Visitors._luoghi_del_piano` **sul posto che `_panchina_per` ha già scelto**
(zero query nuove), e ci arriva a gradini di `FATTI_OGNI`.

### ⚠️ LA COSA DA MISURARE PRIMA DI PROGETTARE: una seduta durava 0,01 s

Il termine, da solo, era **impossibile**. Tre giornate nel villaggio vero,
prima di toccare niente: il bit acceso **0 volte su 169.286 campioni**,
perché una seduta in panchina durava **un centesimo di secondo** (nove
sedute, il 100% sotto il secondo). Non esisteva nessuna finestra dentro cui
un secondo potesse arrivare.

Eppure `Visitor._enter_state("r_bench")` scrive `randf_range(14, 22)` **da
sempre**. Tre righe si combinavano, e ognuna era giusta per conto suo:

1. il gesto **paga la sazietà nel fotogramma d'arrivo** (`STATO_CHE_SAZIA`);
2. `r_bench` sta in `STATI_A_RIPOSO`, cioè **il lucchetto del corpo è aperto
   mentre si è seduti**;
3. energia 1.0 vuol dire `riposo` a zero, quindi qualunque altra cosa vince,
   quindi il fronte, quindi si riparte.

Il controesempio era già in casa: **`r_fire` sazia esattamente allo stesso
modo** e dura **12,96 s durante il falò** contro **0,746 s fuori** — e
l'unica differenza è che il falò si scrive il suo lease. Adesso la sosta se
lo scrive da sé (`Visitor.resta_in_posa()` + una riga nel latch di
`_gesti_agenda`): **p50 da 0,01 a 16,20 s**.

**Senza quel pezzo, tutto il resto sarebbe stato codice morto in partita con
la suite verde** — il guasto che questo progetto ha già pagato tre volte.

### LE SETTE REGOLE CHE NON SI NEGOZIANO

1. **UN POSTO, MAI UN CORPO.** *(oscillazione, corteo)*
2. **UN BOOLEANO, MAI UN CONTEGGIO.** *(grumo)* «C'è qualcuno» e «ce ne sono
   cinque» valgono lo stesso: un posto che si riempie **non diventa più
   forte, diventa PIENO**. Un conteggio è *preferential attachment*, e in
   poche giornate è una legge di potenza.
3. **ZERO RAGGIO NUOVO: si RIORDINA, mai si AGGIUNGE.** *(grumo)* Stessa
   ancora, stesso `RAGGIO_SEDUTA`: l'insieme dei candidati non cambia di un
   elemento, cambia solo l'ordine. Un meccanismo che non può portare nessuno
   dove non sarebbe già potuto andare non può fare un mucchio, **qualunque
   sia K**. È il criterio con cui si giudicano tutte le mosse sociali future.
4. **IL FATTO È SU CHI È SEDUTO ADESSO, MAI SU CHI STA ARRIVANDO.**
   *(stallo)* Mai condizionare sull'intenzione di un altro agente: nessuno va
   per primo, il fatto non è mai vero, e la funzione è codice morto in
   partita con la suite verde. Il bootstrap non serve — la sosta è
   incondizionata, quindi il primo si siede i suoi quindici secondi comunque,
   **e quella È la finestra**.
5. **IL RIFIUTO NON HA UN RAMO.** *(esclusione)* Alzarsi è ciò che fanno
   tutti tutto il giorno: accettazione e rifiuto sono **lo stesso gesto visto
   in due momenti**, e non esiste codice che sappia distinguerli. E nessuna
   regola per cui B che si siede fa alzare A. Il carattere può dire quanto
   uno **cerca** compagnia (`timido ×0.6` su `AZ_CHIACCHIERE`, che esiste
   già); **non può mai dire chi accetta** — e il fattore dell'insieme è cieco
   al carattere, apposta.
6. **LA SOSTA È INCONDIZIONATA, E STA SOTTO `LEASE_SPONTANEO`.** Chi è solo
   si siede quindici secondi come tutti — un pisolino che durasse solo in
   compagnia sarebbe l'esclusione scritta nel motore. E sopra i 30 s
   `_segna_incontro` smette di registrare **in silenzio**: si formerebbero
   cricche che il registro non vede mai. Una costante sola, letta dai due.
7. **IL TETTO DI K LO VERIFICA IL COMPILATORE.** `K_INSIEME = 1.20`, e un
   `static_assert` su costanti **estratte dalla riga** (non ricopiate) vieta
   di sfondare il margine d'urgenza: a 1.30 la build non parte. Il fattore
   **non è mai in `richiede`** — uno stanco e solo deve poter fare un
   pisolino sempre.

**E chi sta da solo non cambia di un bit.** Ogni condizione è un fatto
**positivo** («quel posto ha qualcuno accanto»): nessun ramo si accende sul
vuoto. **Non esiste e non deve esistere** una funzione «chi è solo», «da
quante giornate non sta con nessuno», «chi ha rifiutato chi» — niente
partizione, quindi niente complemento.

### IL DOVE: lo spareggio sta DENTRO ogni anello

`_seduta_da(ancora)` prova prima `_free_bench(ancora, true)` — i soli posti
che hanno compagnia — e **si ripiega** su `_free_bench(ancora)`.

⚠️ **Un quinto anello sotto il ritrovo sarebbe stato IRRAGGIUNGIBILE** per
chiunque abbia una coppia viva: 13 residenti su 13 hanno fra le 14 e le 27
sedute entro sedici metri, quindi il terzo anello restituisce quasi sempre
qualcosa e l'invito **si spegnerebbe da solo man mano che il villaggio
diventa sociale** — cioè al contrario di come deve andare.

⚠️ **E l'ordine dei quattro anelli non si tocca: Mochi resta la PRIMA.** Se
la compagnia salisse sopra `ancora_riposo`, il villaggio si raggrupperebbe
altrove **proprio nel momento in cui arrivi**: è la terza domanda della
REGOLA SACRA, e la risposta sbagliata.

**La chiave del filtro è DOPPIA, e l'ordine dei due confronti è il punto:**
prima **quale compagnia** (quella più vicina all'ancora), poi **quale sedia
accanto a quella compagnia**. Ordinare solo sulla seconda — la prima stesura
— aveva un difetto che si vede solo con due gruppi in scena: fra una panchina
occupata a tre metri e una a quindici vinceva quella a quindici, se il suo
vicino era quaranta centimetri più accosto. Il corpo attraversava il
villaggio per una differenza che nessuno può vedere.

⚠️ **E «quale seduta» non è una sottigliezza: sono due FRASI diverse.** Due
sedute accanto col vuoto di lato si legge «stanno insieme»; due sedute agli
estremi col vuoto in mezzo si legge «si evitano». Nessun conteggio distingue
le due scene — in tutte e due ci sono due persone sedute vicine, e il
registro incassa la stessa riga: se ne accorge solo l'occhio, su
`tools/provino_sosta.gd` scena 2b (tre panchine accostate, le due lastre
affiancate).

⚠️ **MA A ESCLUDERE «AGLI ESTREMI» È IL FILTRO, NON L'ORDINAMENTO — e la
prima stesura di questo capitolo diceva il contrario.** Su tre panchine a
1,2 m l'una dall'altra, quella all'altro capo sta a **2,4 m** dal seduto,
cioè oltre `VICINI`: non è «accanto» affatto, e non entra nemmeno fra i
candidati filtrati. Perché la seconda chiave decida servono **tre o più
sedute tutte entro `VICINI` dalla stessa**, e in questo catalogo — misurato,
non dedotto — ce l'hanno solo il **Gazebo** (dove però i tre sgabelli sono un
triangolo quasi equilatero, 0,92 · 0,95 · 1,00 m: la scelta è fra cose
uguali) e la **Gradinata**, che non è fra i candidati di `_free_bench`.
Quindi `k2` oggi è **quasi inerte**, e vale la pena scriverlo invece di
lasciar credere che stia lavorando: resta perché costa un confronto e chiude
la porta al mobile che verrà.

⚠️ **E SE UN GIORNO SI AGGIUNGE LA GRADINATA ai posti dove ci si siede**, si
guardi prima `provino_sosta` scena 2c: le sue quattro sedute stanno tutte
entro `VICINI` l'una dall'altra, e quattro chibi lì sopra **si
compenetrano** — non si leggono come quattro persone, si leggono come un
mucchio. Il tetto al grumo in questo progetto è la falegnameria, e quel pezzo
di falegnameria non regge quattro corpi.

E il vuoto **non è generico**: i tre cuscini del Gazebo sono di tre colori
diversi, con le tazze degli ospiti sul tavolino («il tè è per tre», sta
scritto nel sorgente). La sedia libera è *quella azzurra, con la sua tazza
davanti* — un vuoto specifico si legge come un invito, uno generico non si
legge affatto. **Zero righe: è già costruito.**

### MOCHI È IL PONTE PIÙ FORTE DEL VILLAGGIO

Ti siedi su uno sgabello del Gazebo, e i due sgabelli accanto cominciano a
chiamare. Due vicini stanchi arrivano e si siedono **a 92 cm l'uno
dall'altro**: `_chats` scrive la riga B—C, e un triangolo che non poteva
chiudersi si chiude. Se ti alzi, non ti segue nessuno — la dichiarazione era
il posto.

⚠️ **Non è gatata sull'ammirazione**, apposta: gaterla escluderebbe dalla
vita sociale nuova proprio chi non si è ancora fatto ammirare. Ed è
**l'unica chiave a forma di GIOCATORE** che questo sistema abbia. La stessa
riga chiude un difetto vivo: `_free_bench` cicla solo `_residents`, e un
vicino **si sedeva dentro Mochi** — invisibile finché una seduta durava
trenta millisecondi.

### L'AFFINITÀ È UN ORARIO — niente da scrivere, tutto da proteggere

`Cricche` chiede tre giornate alla stessa ora nello stesso posto. Chi può?
**Chi si stanca alla stessa ora** — e l'ora del risveglio è
`chibi::finestra_di_sonno(indole, quirk)`. Il grafo sociale del villaggio è
generato dal **genoma del sonno**, che esiste già, è già persistito, ed è già
visibile (chi si alza presto lo vedi).

Non c'è nessuna tabella di compatibilità da nessuna parte, e **la ragione per
cui due non si trovano è un orologio, non un giudizio**: il gioco è
strutturalmente incapace di accusare qualcuno. Conseguenza operativa: **non
aggiungere MAI una tabella di affinità**, in nessuna forma.

### IL TEOREMA, e perché non si alza un numero

*Un termine di attrazione produce **ARCHI**; una cricca è un **TRIANGOLO**
(`Cricche._e_clique`: nessuno entra per catena). L'attrazione è binaria, la
chiusura è ternaria: **nessuna quantità di archi chiude un triangolo**.*

Raddoppiare le coppie vive compra un candidato ogni ventidue giornate e zero
confermati, se non nascono sullo stesso mobile. **Chi vuole cricche
costruisce un mobile a tre sedute fratelle, non alza un numero.** Se in
partita si misura che nessuno costruisce il Gazebo, la risposta è un **Ordine
del Gufo** che lo mette in mano al giocatore — non un termine più forte.

### COSA HANNO DETTO LE MISURE — tre coppie appaiate

Due giornate di gioco, 13 residenti, un Gazebo raggiungibile; ogni coppia è
la stessa corsa con e senza il filtro, e si riporta la **distribuzione**, mai
un numero.

| | senza il filtro | col filtro |
|---|---|---|
| il fatto è acceso | 0,56 · 0,98 · 0,60 % | **4,36 · 6,20 · 5,83 %** |
| residenti che lo vedono | 1 · 3 · 2 su 13 | **13 · 12 · 13** |
| **il termine scavalca l'argmax** | **0,00 · 0,00 · 0,00 %** | 3,01 · 3,04 · 10,90 % |
| campioni-coppia seduti accanto | 0 · 0 · 0 | 308 · 0 · 528 |
| grappolo massimo | 1 · 1 · 1 | **3 · 1 · 3** |
| righe al giorno nel registro | 50,5 · 54,0 · 52,5 | 55,0 · 57,0 · 57,0 |

**La riga che conta è la terza.** Senza il filtro il termine non è debole:
è **inerte**, in tutte e tre le corse — zero decisioni cambiate su
seicentoventotto e più valutazioni col bit acceso. È la conferma del residuo
che chi aveva scritto il termine aveva dichiarato da sé: *«l'incidenza non la
alza K, la alza quale seduta viene scelta»*. Il punteggio senza il posto è
metà meccanismo, e la metà che non fa niente.

E **il grappolo si ferma a tre**, che è il numero di sgabelli del Gazebo: il
tetto al mucchio è la falegnameria del giocatore, non una costante in un
file. È l'unica garanzia di questa fase che non dipende da una taratura.

### ⚠️ IL CANCELLO DI ARRESTO NON SAPEVA MISURARSI

La barra dello zero — la frazione di tempo in cui un residente non ha nessuno
entro tre metri — è **il cancello di arresto** di tutta questa fase: se scende,
il villaggio si sta ammucchiando e il meccanismo va tolto, qualunque cosa
dicano gli altri numeri. Alla prima misura dava **44,18% col filtro contro
47,09% senza**, cioè il verso da temere. Ma dentro lo stesso modo ballava di
**4,6 e 7,6 punti** fra una corsa e l'altra: *la differenza fra i due modi era
più piccola della differenza fra due corse identiche.* Un cancello che non
distingue il proprio segnale dal proprio rumore non è un cancello — è peggio
di nessun cancello, perché lo si legge come una risposta.

**Il rumore erano due cose, e nessuna delle due è il meccanismo.**

1. **Il FALÒ, e non si riconosce dallo stato.** La prima correzione escludeva
   chi fosse in `r_fire`, e non è bastata: durante la *fase* del falò i corpi
   ci **camminano verso** e ci stanno intorno senza mai entrare in quello
   stato, e la coda restava tutta lì (9,31% a sette vicini). Il rito si
   riconosce dalla **fase** (`Visitors._phase() == "fire"`), che è la stessa
   con cui il rito viene comandato.
2. **I CORPI DENTRO CASA.** Di notte i residenti sono nascosti
   (`resident_sleep` li rimpicciolisce a scala 0.03) ma la loro **posizione
   resta sulla cella di casa**: due case adiacenti facevano due «vicini entro
   tre metri» per tutta la notte, con due corpi che il giocatore non vedeva.
   La domanda del grumo è *«si vede un mucchio?»*, quindi si contano i corpi
   che si vedono — `is_hidden()` e `dorme()`, i predicati del gioco.

Effetto sullo strumento: la coda oltre i cinque vicini passa da **18,15% a
0,13%**. E l'esclusione del rito non è una comodità di misura: è la **stessa
regola** con cui `_segna_incontro` rifiuta di registrare la co-presenza al
falò — lì la vicinanza non la sceglie nessuno, e un meccanismo che non tocca
il rito non va misurato attraverso il rito.

### IL VERDETTO — misurato DUE VOLTE, e la prima volta era sporca

⚠️ **Le prime tre coppie appaiate sono state prese col difetto
dell'auto-compagnia dentro** (un vicino seduto si accendeva il fatto da sé,
vedi la revisione più sotto), quindi gonfiavano l'incidenza del fatto e
sporcavano il ramo senza filtro. Rifatte sul codice riparato:

| | senza il filtro | col filtro |
|---|---|---|
| il fatto è acceso | **0,00 % · 0,28 %** (0 e 1 residente su 13) | 2,93 % · 4,62 % (12 e 13 su 13) |
| **il termine scavalca l'argmax** | **0,00 % · 0,00 %** | 16,29 % · 7,98 % |
| coppie sedute DISTINTE | **0 · 0** | **2 · 2** |
| grappolo massimo | **1 · 1** | **3 · 3** |
| campioni con ≥3 seduti vicini | **0 · 0** | 74 · 164 |
| chi resta senza NESSUN partner | 0 su 13 | **0 su 13** |
| barra dello ZERO | 65,59 · 60,51 | 54,50 · 59,73 |
| coda da 4 vicini in su | 0,80 · **4,75** % | 1,20 · 1,22 % |

**Senza il filtro il fatto non si accende MAI** — zero volte su 113.009
campioni in una corsa, e per una persona sola nell'altra — e non cambia
**nessuna** decisione. Il termine da solo è un pezzo di motore staccato; a
farlo girare è il posto.

**E il grappolo si ferma a tre**, che è il numero di sgabelli del Gazebo.

> ### ⚠️ IL CANCELLO, COM'ERA SCRITTO, VIETAVA DI FUNZIONARE
>
> *Qualunque* meccanismo che faccia sedere due vicini insieme abbassa la
> frazione di tempo passato da soli: è l'effetto voluto, non il guasto. Preso
> alla lettera, «la barra non deve scendere» boccia la funzione **per il
> fatto di funzionare**.
>
> E la barra **non risponde**: fra i due modi la differenza va da 11 punti a
> **0,8**, cioè meno della dispersione dentro un modo solo (e su tre coppie
> precedenti cambiava di segno). Con questi numeri non è una domanda a cui
> questa barra sappia rispondere, e dirlo è più utile che scegliere la coppia
> che dà ragione.
>
> ⚠️ **E NEMMENO LA CODA RISPONDE — la stesura di ieri diceva di sì, e
> sbagliava.** Sulle tre coppie sporche la coda da quattro vicini in su
> passava da 0,80 % a 1,27 %, «coerente in tutte e tre», e l'avevo indicata
> come *il numero da confrontare in futuro*. Sulle due coppie pulite: col
> filtro **1,20 e 1,22**, senza **0,80 e 4,75**. Una corsa SENZA ha la coda
> quattro volte quella di entrambe le corse CON. Quel mezzo punto era rumore,
> e chiamarlo segnale era esattamente l'errore che questa sezione denuncia un
> paragrafo più sopra.
>
> **Quel che resta, e regge:** il grappolo di seduti non supera mai TRE, in
> nessuna corsa e in nessuna geometria — compresa la fila di otto panchine
> accostate costruita apposta per farlo salire, dove si ferma a **due**. È
> l'unico limite di questa fase che non dipende da una taratura né da una
> media: dipende da quante sedute fratelle il giocatore ha costruito. **Se
> un giorno il grappolo supera la capienza del mobile più grande, allora il
> villaggio si sta ammucchiando** — e quello è un fatto, non una
> percentuale.

**E la domanda della REGOLA SACRA ha una risposta misurata, non argomentata:**
partner **distinti** per residente, contati dalle posizioni dei corpi (mai
chiedendo a `Cricche`), fuori dal rito e sui soli corpi in scena:

```
Ciliegia 12 · Biscotto 11 · Castagna 11 · Prugna 11 · Amaretto 10 · Malva 10
Timo 10 · Loto 9 · Cannella 8 · Nuvola 8 · Cacao 8 · Brioche 7 · Nocciola 7
→ chi non ha avuto NESSUN partner: 0 su 13   (in tutte e sei le corse)
```

**Zero esclusi, e nessun blocco.** Da cinque a dodici partner diversi a testa
è un villaggio che si mescola, non uno che si divide in gruppi chiusi — ed è
la cosa che i numeri della co-presenza non potevano dire: cento righe possono
essere venti persone che si mescolano o quattro che si vedono sempre. Nessuno
dei tre disegni la misurava.

*Residuo dichiarato:* la curva spezzata per **indole** oggi raggruppa per la
coppia di tratti (`["goloso", "chiacchierone"]`), quindi i gruppi hanno uno o
due elementi e le medie non dicono niente di solido. Per rispondere davvero a
«il carattere è diventato un cancello?» va spezzata per **tratto singolo**, e
su più giornate di due.

### COME SI MISURA (e il CANCELLO DI ARRESTO)

```
CHIBI_GIORNI=2 CHIBI_QUANTI=13 CHIBI_GAZEBO=1 \
  Godot --headless --path . --script res://tools/misura_insieme.gd
CHIBI_SOSTA=<dir> Godot --path . --resolution 1280x720 \
  --script res://tools/provino_sosta.gd
Godot --headless --path . --script res://tools/prova_insieme_mochi.gd
Godot --headless --path . --script res://tools/misura_k_insieme.gd
```

⚠️ **`misura_insieme` ha un oracolo INDIPENDENTE**: i grappoli e le coppie si
contano dalle **posizioni dei corpi**, campionate dal banco, mai chiedendo a
`Cricche` né al fatto stesso. Chiedere al giudice se è d'accordo con sé
stesso è l'errore che `tools/misura_cammino.gd` esiste per non commettere.

⚠️ **LA BARRA DELLO ZERO È IL CANCELLO DI ARRESTO.** È la frazione di tempo
in cui un residente non ha nessuno entro **tre metri** (`PARAGGI`, che non è
`VICINI`: il grumo si vede alla scala della SCENA, non a quella della
panchina). **Se scende, il villaggio si sta ammucchiando e il meccanismo va
tolto, qualunque cosa dicano gli altri otto numeri.** Un villaggio-grumo è la
fine del cozy: non si distinguono più le persone, non ci sono più posti,
spariscono le distanze che raccontano qualcosa.

⚠️ **E la corsa sulle CRICCHE non può essere A/B nella stessa corsa**: il
meccanismo cambia la STORIA, e una storia non si biforca a metà giornata.
Corse **appaiate** con lo stesso salvataggio, e si riporta la distribuzione,
mai un numero. È l'unica eccezione alla regola A/B di questo progetto, e ha
una ragione, non una comodità.

⚠️ **E il banco non tocca il `village.json` dell'autore**
(`set_persist_for_debug(false)`, impronta confrontata prima e dopo): un banco
altrui si è già portato via due gigabyte.

### ⚠️ COSA HA TROVATO LA REVISIONE AVVERSARIALE (quattro lenti)

Il lavoro è stato passato a quattro lenti indipendenti — correttezza,
integrazione, il GENERE, e i test. Hanno trovato **sette difetti veri**, e i
due peggiori erano contro cose che il sorgente dichiarava già chiuse.

1. **UN VICINO SEDUTO FACEVA COMPAGNIA A SÉ STESSO.** La guardia c'era
   (`if n.get("_routine_aux") == seat: continue`) e non serviva a niente:
   morde solo sul posto che quel corpo ha prenotato, e quel posto
   `_free_bench` non lo restituisce **mai** (è già «taken»). I posti che
   arrivano a `_seduto_accanto` sono per costruzione diversi dal proprio, e
   lì un vicino solo su uno sgabello del Gazebo si accendeva il fatto da sé
   guardando lo sgabello di fianco: il riposo prendeva il suo ×1,20 e
   restava incollato lì. Ora `_seduto_accanto` sa CHI sta chiedendo.
   ⚠️ **E la lezione di metodo vale più del difetto**: una mutazione su
   quella riga *arrossisce*, quindi la guardia risultava viva. **Una guardia
   che fallisce sulla mutazione sbagliata è più insidiosa di una muta: dice
   «coperto» e non lo è.**
2. **CHI È DENTRO UNA SCENA FACEVA COMPAGNIA.** Il pubblico del Concerto sta
   seduto fino a 48 s — tre volte la sosta — e dominava il segnale; ma
   `_segna_incontro` rifiuta per costruzione ogni co-presenza in cui uno dei
   due sia `in_scena()`. L'invito spendeva il gettone e una camminata per
   portare due vicini **dove il registro non li vede**.
3. **IL LETTO DI MOCHI CONTAVA COME SEDUTA.** `_sit_down` scrive `_seat_node`
   per ogni `kind`, letto compreso, e `_sleep_until_morning` non lo azzera:
   tutta la notte il letto risultava «un corpo seduto» e chiamava i vicini
   verso un corpo dietro una tenda nera.
4. **IL COSTO.** `_seduto_accanto` girava anche nel ramo NON filtrato e ne
   buttava il risultato — una scansione di tutti i residenti **per ogni
   candidato**, più un `get_first_node_in_group` a testa, sul cammino che
   gira sempre. Misurato con 28 residenti: `_free_bench` da 83 a **445 µs**,
   `_seduta_da` a **804**. Adesso si cerca solo se serve.
5. **LO `static_assert` NON ERA LA RETE CHE DICEVA DI ESSERE.** La relazione
   scritta ignorava che l'emozione si innesta **dopo** i fattori
   (`v += clamp(v·mo − v, ±DELTA_MAX)`): lo scarto vero è
   `v0(K−1) + DELTA_MAX(1 − 1/K)` = 0,523, e il tetto non è a 1,2678 ma a
   **K ≈ 1,2305**. In mezzo c'era **1,25**, che la tabella di taratura
   presentava come opzione «0 urgenze» — vera, ma *a modulatore neutro*.
   Falsificato: con la relazione corretta la build si ferma a 1,25 e passa a
   1,23.
6. **`sedile_attuale()` non aveva un solo lettore nei test**, perché il banco
   ne aveva una gemella finta — ed è la classe in cui viveva il difetto 3.
   Ora si prova la classe VERA col solo `_ready` scavalcato.
7. **Sette guardie erano MUTE** (zero asserzioni rosse su 34 mutazioni
   provate): il fatto derivato dal posto scelto, «accanto è il più vicino»,
   l'ordine dei quattro anelli con Mochi per prima, `LEASE_SPONTANEO`
   giudicato solo contro sé stesso, e un caso il cui nome non coincideva con
   ciò su cui poteva fallire. Tutte chiuse, e **falsificate una per una**:
   3 · 1 · 1 · 1 · 1 · 1 · 1 · 1 · 4 asserzioni rosse.

**E la geometria che il cancello d'arresto non aveva mai visto.** La lente
del genere ha dimostrato che «il grappolo si ferma a tre» era una proprietà
della **fixture**: il banco posava otto panchine isolate (la coppia più
vicina a quattro metri), quindi il grafo delle sedute aveva componenti da
uno. Le celle sono da un metro, quindi due panchine accostate stanno dentro
`VICINI` e una fila *in teoria* si riempie a catena. MISURATO con la fila
vera (otto panchine accostate, due coppie appaiate): **il grappolo massimo
resta 2**. La catena non si forma perché le decisioni di riposo sono rare
rispetto alla finestra di 14–22 s — ma il tetto **non è il mobile**, ed è
scritto qui perché nessuno ci ricaschi.

### ⚠️ I RESIDUI DICHIARATI, con la ragione

- **Il fatto e il corpo possono guardare due posti diversi.** `_recita`
  chiama `_panchina_per` una seconda volta, fino a mezzo secondo dopo, e da
  quando esiste il filtro la risposta dipende da chi è seduto *in questo
  istante*. Ho provato a chiudere il buco **promettendo** il posto, e **tre
  asserzioni di `test_cuore_vicini` sono diventate rosse**: fra le due
  chiamate cambia anche l'ANCORA, e una promessa congelata fa inseguire al
  corpo un posto che non ha più ragione di esistere — *«se il giocatore se ne
  va dall'altra parte, nessuno insegue nessuno»*. Quella proprietà vale di
  più. Chi vorrà chiudere il cerchio deve far scadere la promessa **quando
  cambia l'ancora**, non quando cambia il posto.
- **Il Salone non dichiara la sua scena.** Mette il cliente in `r_bench` per
  16 s senza `apri_scena`, quindi quel corpo conta come compagnia e la sua
  co-presenza si registra come spontanea — la stessa forma del difetto del
  falò, un piano più in là. La cura è in `Salone.gd`, non qui.
- **`_resident_greet` in `r_bench` chiude il vocabolario del corpo** per
  1,47 s a ogni saluto, cioè il 18% del tempo seduto, e il metro dei gesti
  (2,10 al minuto) non è stato rimisurato dopo.
- **`FATTI_OGNI` è sorvegliata da `test_cuore_vicini`, non da
  `test_insieme`**: in quel banco il mondo alterna con un periodo che si
  allinea alla cadenza del rinfresco, e i cambi sono **3 col gradino a 30 e
  2 col gradino a 1**. Un tetto assoluto scritto lì sembrerebbe una guardia
  e non lo sarebbe.

### LE TRAPPOLE GIÀ PAGATE

1. **Il termine da solo era codice morto** — la sosta, sopra. È la lezione
   generale: prima di aggiungere un termine, **misura se la finestra in cui
   può accendersi esiste**.
2. **La chiave che faceva due mestieri.** `d_migliore` era insieme il limite
   dei candidati e il migliore trovato finora, e finché si ordinava per
   distanza dall'ancora i due coincidevano. Col filtro non coincidono più: la
   mutazione che allarga il raggio **lasciava la suite completamente verde**,
   perché a bocciarla era il valore iniziale della variabile e non un
   cancello. Adesso il cancello ha un nome (`RAGGIO_SEDUTA`) e il caso che lo
   sorveglia ha la geometria stretta — seduta a 17 m, compagno a 15,5 —
   perché è l'unica in cui si vede quale delle due righe lavora.
3. **Le mutazioni ingenue non fanno fallire un test: lo interrompono.**
   Togliere il controllo dello stato in `_seduto_accanto` o nella
   prenotazione è un accesso a un campo che non c'è, cioè un errore a runtime
   che lascia la suite verde. Le plausibili sono «accetta anche chi cammina»
   e «guarda `r_bench` e dimentica `walk`».
4. **Un doppio che ri-implementa la cosa da provare la lascia senza
   lettori.** In `test_insieme` il finto BuildSystem dice DOVE sono i pezzi
   (che è un dato) e non decide niente: `_free_bench`, `_seduto_accanto` e
   `_panchina_per` restano quelli del gioco. E il finto è un `Node3D` e non
   un `Node`, perché `Visitors._build` è tipizzato e un `set()` col tipo
   sbagliato **non assegna e non dice niente**.
5. **La prova bit-esatta dell'agenda è CIECA a questo fattore**, per
   costruzione: la sua spazzata accende solo i sei fatti storici, quindi il
   bit 13 non può accendersi e `alt = 1.0` è il neutro esatto. Resta verde
   senza toccarne una riga — **e per questo la guardia del fattore è un caso
   NOMINATO**, che legge `K` dal binario invece di riscriverlo.


## LA NEUROCHIMICA — sette canali, una casa sola, e il tempo che li muove

Ogni vicino ha sette canali che si muovono da soli: **dopamina, ossitocina,
serotonina, cortisolo, melatonina, adenosina, endorfine**. Vivono in
[`scenes/npc/Limbico.gd`](scenes/npc/Limbico.gd), tornano al loro punto di
riposo quando non succede niente, e da lì escono l'umore, la fatica di
mordersi la lingua, e quello che si vede addosso a un corpo.

### La forma: un punto di riposo, gli impulsi, e il tempo

- **`neuro`** è il livello adesso, ed è l'unico stato — persistito.
- **`neuro_base`** è dove torna: lo spostano i bisogni
  (`Animo.sincronizza_neuro`) e ci si somma sopra lo **scarto del carattere**
  (`tinta_carattere` → `applica_tinta`). ⚠️ Fino al 2026-08-18 la tinta del
  carattere era una SCRITTURA dentro `setup`, e i bisogni la cancellavano tre
  righe dopo: vedi «IL CARATTERE NON TINGEVA NIENTE», più sotto. ⚠️ **I bisogni spostano il PUNTO DI
  RIPOSO, non il livello.** Prima lo assegnavano, e siccome
  `sincronizza_neuro` la chiamano sei posti (`ricorda` compreso, cioè ogni
  fatto della vita del villaggio), **ogni impulso degli eventi veniva
  cancellato**: misurato, la chiacchierata portava l'ossitocina a 1,0000 e il
  primo `ricorda()` la riportava a 0,7575. Il piatto caldo, l'onsen e la
  chiacchierata non contavano niente.
- **`stimola_neuro`** è un impulso: una cosa che è appena successa.
- **`passo_neuro(dt, ambiente, dorme)`** è l'unico posto in cui il tempo tocca
  la chimica.

**L'integrazione è ESATTA, e il pezzo che conta è dove sta `Π/λ`:**

```
N(t+Δt) = (B + Π/λ) + (N − B − Π/λ) · e^(−λΔt)
```

La prima stesura scriveva `B + (N−B)·e^(−λΔt) + Π·Δt` — decadimento esatto e
produzione in Eulero esplicito, **fuori** dall'esponenziale. Sembrava esatta e
non lo era: il punto fisso diventava `B + Π·Δt/(1−e^(−λΔt))`, cioè una
funzione del PASSO, e il passo è il fotogramma. MISURATO sul binario di
allora: un minuto simulato a 1 fps contro 60 fps dava melatonina **0,697490
contro 0,669030**. *Lo stato era funzione del frame rate.*

⚠️ **E ogni riga di `NEURO_PRODUZIONE` si legge col suo λ accanto**, perché il
punto fisso è `B + Π/λ`. È lì che il modello era rotto: la serotonina aveva
Π = 0,04 contro λ = 0,02, cioè equilibrio **2,50** — il 150% oltre il tetto.
Misurato: arrivava a 0,999 in quattordici secondi e ci restava, e un impulso
di +0,50 la muoveva di `+0.000000`. Su quel canale l'omeostasi **non
esisteva**: era una costante 1,0 per tutta la parte illuminata della giornata,
per chiunque, qualunque cosa succedesse.

### ⚠️ L'UMORE SI MUOVE COL TEMPO, e per un pezzo si è mosso PER CHIAMATA

È il difetto peggiore che questo sistema abbia avuto, ed è l'unico che
arrivava davvero a schermo. `_modula_stati_da_neuro` faceva
`umore += spinta * 0.05` **a ogni chiamata**, e `Visitors._ciclo_sonno` la
chiamava due volte per fotogramma per ogni residente: l'umore era una rampa
alla frequenza del fotogramma.

| MISURATO nel MainLevel vero, 10 residenti che nessuno tocca | |
|---|---|
| umore, dopo qualche secondo | **+1,0000 su 10 su 10** |
| carattere medio, tempo di saturazione | 17,5 s a 60 fps · **42,1 s a 25 fps** |
| carattere codardo | **−1,0000 in 2,77 s** |
| un LUTTO | cancellato in **tre secondi** |

Il rapporto 17,5/42,1 è esattamente 60/25. E le conseguenze non erano
teoriche: `stato_corpo()` non avrebbe mai più detto «di malumore» a nessuno,
il capo che pende perdeva una delle sue tre cause (diventava una legenda
uno-a-uno decisa dai tratti alla nascita), e con i drive un po' più bassi —
cioè in un villaggio che ha vissuto — **tutti finivano a −1,0000**.

Adesso l'umore insegue la chimica con la sua costante di tempo
(`UMORE_TAU = 90 s`), e la soglia che lo sorveglia non è un numero comodo: è
**quanto rimette a posto una notte di sonno**. *Un secondo di villaggio non
può spostare l'umore più di una notte.*

### ⚠️ UNA CASA SOLA — il modello C++ è stato TOLTO

C'era anche `src/sistema_neurochimica.{h,cpp}` più un `ComponenteNeurochimica`
in ECS: girava sessanta volte al secondo per ogni residente e **non lo leggeva
nessuno**. Misurato mettendo un `return` in testa al suo passo: la suite
restava **identica** (68157/0) e `avanza()` scendeva da 11,4 a 8,2 µs — il
tempo dimostra che la mutazione era nel binario, e nessuna asserzione se n'è
accorta.

Ed era un **doppione**, con baseline già divergenti in cinque canali su sette
(cortisolo 0,20 contro 0,08, adenosina 0,20 contro 0,0, endorfine 0,40 contro
0,15). La casa è in GDScript e non di là per una ragione già scritta nel
capitolo dell'ECS: **quel dato è persistito**, e i dati persistiti restano in
GDScript — «due case sullo stesso dato salvato è il guasto che le fonti uniche
vietano». Quello che il C++ aveva di buono — l'integrazione, il decadimento
per canale, la produzione ambientale — è stato portato in `Limbico`.

**Tre cose di quel codice che vale la pena non ripetere, tutte misurate:**

1. **`alignas(32)` era decorativo.** Zero istruzioni SIMD generate (l'oggetto
   chiama `_expf` scalare), e degli array solo il primo era allineato a 32 —
   gli altri stavano a 28/56/84/112/140, quindi **un load allineato AVX2 su
   `baseline` avrebbe fatto fault**. Su un target universale che comprende
   **arm64**, dove AVX2 non esiste. Costo: +14% di memoria per niente.
2. **La funzione «batch» era una TRAPPOLA.** `passo_neurochimico_batch(n, …)`
   presume due pool EnTT paralleli, e paralleli non sono: chi l'avesse usata
   davvero come batch avrebbe accoppiato **il neuro di X con lo stato di Y**.
   Il sito di chiamata la evitava passando `n = 1` — cioè l'unica ragione
   d'essere di quella funzione non è mai stata usata, e il resto era una mina.
3. **`AmbienteContesto.ora` era scritto ogni fotogramma e non letto mai.** Il
   commento di testata prometteva «e ciclo circadiano»: la seconda metà non
   esisteva.

### ⚠️ IL MONDO ENTRA DA UNA PORTA SOLA, e il cielo non spinge niente

`DayNight` sa già luce, temperatura e pioggia (le calcola per i suoi shader) e
le pubblica in `parametri_ambientali()`. `Visitors` le legge **una volta per
fotogramma** — non ventotto — e le passa al passo. Prima il cielo SPINGEVA
l'ambiente al gruppo `ecs_mondo` a ogni frame, con le tre formule **ricopiate**
dalle funzioni che avevano un solo chiamante: sé stesse.

**Il cancello del NaN sta all'ingresso, e ce n'è uno solo.** Lo stato è
ricorsivo e `clamp(NaN)` restituisce NaN: un NaN è **assorbente**. Misurato
sul modello di allora, con un solo fotogramma sporco: **quattro canali su
sette morti per sempre**, ancora NaN dieci secondi dopo.

**E senza mondo non succede niente**: nei banchi, nel diorama del titolo e nel
Prologo la chimica sta ferma al punto di riposo. Il degrado va verso «non
succede niente», mai verso un numero inventato.

### ⚠️ IL CORPO INDOSSA LA CHIMICA — e per un pezzo non la indossava nessuno

`FaceController` e `Andatura` avevano tutto scritto e provato — corrugatore
col cortisolo, pupille con la dopamina, blush con l'ossitocina, rimbalzo con
l'adenosina, coda con la serotonina — e **nessun chiamante in tutto il gioco**.
MISURATO: sessanta secondi di cammino, dieci canali del rig, il corpo usciva
**bit-identico** a quello di prima (scarto `0.0000000000`). Duecentoquarantasette
righe complete, provate, verdi, e mai eseguite: la forma di guasto che questo
progetto ha già pagato tre volte.

La riga che mancava è `Visitor.indossa_neuro(neuro)`, chiamata da `Visitors`
una volta per fotogramma.

⚠️ **E SI PASSANO I CANALI VERI, non se ne inventano da altri livelli.** La
prima stesura ri-derivava la chimica: `cortisolo = arousal`,
`serotonina = 0.5 + 0.5·umore` e — la peggiore — **`adenosina = 1 −
regolazione`**. Ma `regolazione` è *la forza di trattenersi*, non la
stanchezza: con quella riga **chi si è appena morso la lingua cammina come un
esausto** (rimbalzo ×0,45, orecchie cadute), e il giocatore non ha modo di
leggerlo come autocontrollo. È un'etichetta clinica addosso a una persona, ed
è la stessa famiglia del difetto del capitolo «LA GIOIA NON PORTA LA FACCIA
DELLA PAURA»: *un livello che si posa su un canale che non gli appartiene*.
Lo stesso valeva per l'umore: −0,9 dava una gobba **permanente** di 11,3°, più
di due terzi della vecchiaia piena. Un umore basso passa; una gobba no.

### Le tre chiavi del giocatore, e quelle che gli erano state tolte

- **Il cortisolo non è cronico**: `consolida_sonno` lo drena ogni notte, e la
  Veglia lo sconta. Questo era già giusto.
- ⚠️ **Ma il ri-aggancio era un `max()`, cioè solo verso l'alto.** Misurato
  nella scena vera del piatto caldo: un vicino con `sicurezza = 0,30` si
  sveglia guarito (0,0800), il giocatore gli porta da mangiare, e resta con
  **0,4400** — *il gesto più affettuoso del gioco lo lasciava più teso di come
  si era svegliato*. Adesso il piatto sposta il livello, i drive spostano solo
  il punto di riposo, e quando la sicurezza torna il riposo **scende**.
- ⚠️ **Il perdono non dipende da quanti amici ti ha dato il mondo.** C'era un
  moltiplicatore dell'ossitocina sullo sconto del rancore, e l'ossitocina la
  fa l'appartenenza, che a sua volta la fa `_chats` — **una** chiacchierata per
  volta in tutto il villaggio. Misurato: da ×1,146 a ×1,596 fra appartenenza
  0,10 e 0,90, cioè **chi il mondo non ha incontrato perdonava meno**. È la
  stessa forma della «tassa giornaliera per non essersi visti» che la regola 3
  degli Affetti vieta per iscritto. Tolto.
- ⚠️ **E il morso della lingua paga lo stress IN PIÙ, non quello che si ha
  sempre.** Scalava sul cortisolo assoluto, e il cortisolo di riposo vale
  0,05–0,15: il morso costava dal 4 all'11% in più **per tutti, dal primo
  fotogramma**. Misurato A/B su un codardo: due morsi invece di tre prima di
  scoppiare — un sistema tarato altrove spostato da un effetto collaterale.

### ⚠️ IL CARATTERE NON TINGEVA NIENTE, e la controprova ha smontato anche me

`Limbico.setup()` aveva cinque righe che scrivevano `neuro_base` dai tratti —
cortisolo dalla codardia, ossitocina dalla lealtà, dopamina dall'ambizione,
endorfine dalla grinta, serotonina dalla codardia al contrario — col commento
*«il carattere tinge il punto di riposo, così un vicino appena nato è già sé
stesso»*. Erano **morte**: `Animo.sincronizza_neuro()` riassegna gli stessi
cinque canali dai bisogni, e la chiamano **sette** posti — a partire da
`Animo.setup()` stesso, **tre righe dopo**.

MISURATO, con la codardia da 0,20 a 0,85:

| | cortisolo | ossitocina | dopamina | serotonina | endorfine |
|---|---|---|---|---|---|
| **prima** (qualunque carattere) | 0.1200 | 0.7575 | 0.8315 | 0.8650 | 0.7935 |

**Bit-identici.** Ogni vicino del villaggio aveva la stessa identica chimica a
riposo, e il carattere non ci arrivava né alla nascita né mai. È la stessa
forma delle 247 righe di somatizzazione senza chiamanti: codice completo,
provato, verde e mai eseguito — la sesta volta in questo progetto.

**La cura non poteva essere «riassegnare dopo i bisogni»**: cancellerebbe i
bisogni, cioè rifarebbe un piano più giù il difetto che la testata di
`sincronizza_neuro` documenta. Il carattere è diventato uno **SCARTO dal
carattere neutro** (`Limbico.tinta_carattere`, pura) che si **somma** a quel
che i bisogni hanno deciso, in un posto solo (`applica_tinta`, chiamata in
coda a `sincronizza_neuro`). Tre proprietà, e nessuna è una taratura:

1. **un carattere medio somma zero esatto** — per lui il gioco è bit-identico
   a prima, quindi tutte le misure già prese (il piatto caldo, il ri-aggancio
   del cortisolo, il morso della lingua) restano valide senza rifarle;
2. **un codardo sta più in alto sul cortisolo sempre**, qualunque cosa dicano
   i suoi bisogni — che è cosa vuol dire avere un carattere;
3. **è una funzione dei TRATTI, quindi la deriva la muove** — `riproietta()`
   rifaceva due delle sette grandezze che `setup` deriva dai tratti, e le
   altre cinque erano proprio quelle che arrivano addosso a un corpo.

E c'è un lettore vero, che è quello che rende la tinta una cosa che succede:
`bersaglio_umore()` legge la chimica a riposo, e l'umore ha consumatori
(`stato_corpo()`, il capo che pende, il vocabolario del corpo).

| codardia | cortisolo | serotonina | reattività | umore a cui tende |
|---|---|---|---|---|
| 0,15 | 0.0850 | 0.9350 | 0.5080 | **+0.4098** |
| 0,50 (il neutro) | 0.1200 | 0.8650 | 0.8230 | +0.3713 |
| 0,90 | 0.1600 | 0.7850 | 1.1830 | **+0.3273** |

### IL PROVINO, e il verdetto onesto: a riposo NON si vede — e non deve

La deriva era stata **misurata e mai guardata**, ed è la REGOLA ZERO al
contrario. Lo strumento è
[`tools/provino_carattere.gd`](tools/provino_carattere.gd): cinque corpi con
lo **stesso genoma**, la stessa imbardata, la stessa distanza, nello **stesso
fotogramma**, che differiscono per una cosa sola — il carattere. Catena vera
dal tratto al pixel (`setup` → `tinta_carattere` → `sincronizza_neuro` →
`passo_neuro` fatto girare fino al punto di riposo → `indossa_neuro` → rig):
nessun canale scritto a mano, o la lastra mostrerebbe cinque corpi identici
comunque.

> ### ⚠️ **E LA CONTROPROVA HA SMONTATO LA MIA PRIMA LETTURA**
>
> Guardando il dettaglio 3× della lastra del carattere avevo letto una
> progressione pulita delle sopracciglia, e stavo per scriverla. Poi ho
> scattato la **stessa lastra con cinque corpi IDENTICI** (chimica bit-uguale:
> 0.1200 / 0.8650 / 0.8224 per tutti e cinque) — e le sopracciglia erano
> **visibilmente diverse fra loro**. Quello che avevo letto come «il
> carattere» era la fase dell'ammicco e delle micro-espressioni.
>
> Il conto lo diceva già, e non l'avevo fatto: il canale del sopracciglio è
> `(serotonina − 0.5) * 0.08`, cioè **0,7 gradi su TUTTO il campo del
> carattere** — sotto il rumore del volto vivo. È la stessa scala a cui un
> oracolo sbagliato produce undici asserzioni rosse su codice sano.
> **Una lastra affiancata senza controprova è un test senza oracolo.**

**Il verdetto, guardato:**

| | si vede? |
|---|---|
| il carattere **a riposo**, 2 m, dettaglio 3× | **no** — sotto la fase delle micro-espressioni |
| la **deriva** a riposo (0,019 di cortisolo) | **no**, nemmeno a 3× |
| il carattere **nel momento** (lo stesso spavento), 2 m di fronte | **sì**, progressione monotona su cinque colonne |
| …**di spalle** | sì, più debole — ed è silhouette, non faccia |
| la **deriva** nel momento (forza 0,90 → 0,75) | **al limite**: un gradino su cinque, e affiancati non si è mai |

**E l'ampiezza NON è stata alzata**, con la ragione: per rendere un codardo
visibile da fermo bisognerebbe tenerlo a cortisolo alto **sempre**, cioè
cucirgli addosso in permanenza la faccia della paura. È il difetto che il
capitolo «LA GIOIA NON PORTA LA FACCIA DELLA PAURA» esiste per impedire, ed è
un'etichetta clinica su una persona — la seconda domanda della REGOLA SACRA.

**Dove il carattere si vede è la REAZIONE, e lì l'ampiezza c'era già.** Stesso
spavento (`indizio_grezzo` 0,430, marchio −0,45 per tutti, la catena vera di
`_tick_sussulti`), e la forza che ne esce va da **0,447 a 1,000** — più del
doppio, perché `reattivita` va da 0,51 a 1,18. Nella lastra si legge come
silhouette: il corpo che si rimpicciolisce e le orecchie che vanno indietro,
in progressione, colonna dopo colonna. La controprova sotto spavento (cinque
forze identiche, 0.7240) dà **cinque pose identiche**: la progressione è del
carattere.

**I residui, dichiarati:**

- **la deriva è una cosa che si SENTE, non che si vede.** Muove `reattivita`
  di 0,17, l'umore di riposo di 0,033, il peso dell'appartenenza, la
  resistenza alle voci — cioè dove va quella persona e come reagisce, non che
  faccia ha. Chi vorrà renderla visibile deve trovare un canale di
  **silhouette** (la strada del Raccolto), non alzare un guadagno.
- **a 9 m la misura non c'è**: i corpi erano coperti da un edificio del
  villaggio. È il residuo che `provino_vocabolario` aveva già dichiarato — il
  cancello prova il frustum, non la visibilità.
- **la lastra del carattere a riposo resta nel provino** anche se il verdetto
  è «no»: è la lastra che dimostra il no, e toglierla vorrebbe dire dover
  ricredersi da capo.

### Come si guarda

```
CHIBI_CAR=<dir> Godot --path . --resolution 1280x720 \
    --script res://tools/provino_carattere.gd
```

⚠️ **Non `--headless`: qui si guarda.** E tre trappole di banco già pagate
scrivendolo: **la testona di Mochi copriva esattamente il corpo di mezzo** (si
nasconde il solo modello, la camera resta dov'è); **i cartellini non stanno
nell'HUD** e il gioco ne crea di nuovi mentre il provino gira, quindi si
rispengono prima di ogni scatto con la regola della Modalità Foto; e **la fila
si apre con la distanza**, o a sei metri in ogni cella del ritaglio a pixel
fissi ci finiscono due corpi.

### ⚠️ LO STRESS STRINGE UNA ROUTINE, MAI UNA SCELTA DI VITA

Il cortisolo alto irrigidisce il softmax di `Animo.decide()` — chi è teso fa
la cosa che lo solleva invece di guardarsi intorno. Ma il fattore ×4 si
moltiplicava **anche** per `NITIDEZZA_VITA` (4,5) e dava 18: lo stress rendeva
più *certa* una decisione che cambia una vita, che è l'opposto di quello che
lo stress fa.

MISURATO su 240 caratteri veri × 30 rotture, il ventaglio delle sette risposte
di `REAZIONI` — «lo stesso carattere che in 30 rotture ne dà tre diverse»,
l'invariante che una revisione avversariale precedente aveva stabilito:

| cortisolo | 0,08 | 0,46 | 0,60 | 0,90 |
|---|---|---|---|---|
| ventaglio ≥ 3 risposte | 87,9 % | 86,7 % | 53,8 % | **25,4 %** |

Il tetto è fatto di un numero che non è suo (`NITIDEZZA_VITA` stessa): una
routine può diventare decisa quanto una scelta di vita, **mai di più**. E
`Animo.decide()` è il SECONDO softmax del gioco: `DELTA_MAX` e il suo
`static_assert` sorvegliano solo quello del C++, questo non lo vede nessun
compilatore — la sua rete è il caso che misura il ventaglio.

### Come si verifica

```
Godot --headless --path . --script res://tests/test_runner.gd
CHIBI_MINUTI=2 Godot --headless --path . --script res://tools/prova_neuro_vivo.gd
```

Il banco vivo è l'unico che dice le cose che la suite non sa dire, e ha tre
domande: **la chimica arriva al corpo?** (si guasta il cortisolo e si guarda
il rig: `0,051 → 0,941`); **l'umore è ancora una cosa che si muove?** (dopo due
minuti di villaggio: media 0,316, **zero saturi, zero estremi**); **un colpo
resta addosso?** (tre secondi dopo un lutto: **−0,857**).

⚠️ **E l'animo si prende da `Visitors`, non se ne fabbrica uno**: `_ensure_brain`
ne crea uno suo dal genoma e **sovrascrive** `_animi[key]`. Un animo di banco
messo lì prima viene buttato, e il caso misurerebbe un oggetto che il gioco non
guarda — il rig resta alla baseline del carattere qualunque cosa gli si scriva.

**Le guardie sono state falsificate una per una, dodici mutazioni tutte rosse**
(il corpo che non indossa più la chimica · l'umore per chiamata · l'Eulero
fuori dall'esponenziale · il cancello del NaN · i drive che scrivono il livello
· il tetto della tunnel-vision · l'ossitocina sul perdono · la regolazione
travestita da fatica · la serotonina che sfonda il tetto · il morso sul
cortisolo assoluto · la compatibilità che fa scrivere un canale a un livello).

**Residuo dichiarato, e sta scritto nel test:** la correzione alla molla del
sopracciglio — un filtro che era finito **in serie** con la molla del rig,
0,0384 rad di ritardo anche a chimica neutra, su Mochi e su ogni chibi a ogni
cambio di espressione — **non ha una guardia**. Ne ho provate due e la
mutazione le lascia verdi tutte e due, perché in quel banco il sopracciglio
non passa affatto dalla molla. Un'asserzione che passa in tutti e due i casi
non è una guardia: è un'asserzione che dice «coperto» senza esserlo.


## LE PERSONE CAMBIANO — i tratti che derivano, e i tre posti in cui non entrano

I tratti (codardia, grinta, lealtà, ambizione, orgoglio) erano decisi alla
nascita e non si muovevano di un millesimo, qualunque cosa succedesse a quella
persona. Adesso **tre** di loro derivano, lentissimamente, nella direzione in
cui la vita di quel vicino ha spinto — la **codardia** da come il giocatore
l'ha trattata, la **lealtà** dal tempo passato con qualcuno, l'**ambizione**
dal vedersi dare il lavoro che si sognava — e siccome tutto il gioco legge i
tratti, spostarne uno muove tutta la persona.

Vive in [`scenes/npc/Deriva.gd`](scenes/npc/Deriva.gd) (puro, senza Godot e
senza stato) più `Animo.tratto()` / `tratto_base()`.

### ⚠️ LA DERIVA NON SI SALVA, ed è la decisione che tiene su tutto

È una **lettura**, come `Affetti.coppia()` e come `Animo.assenza()`: si ricava
ogni volta dalle prove che erano già nel salvataggio. Zero chiavi nuove, zero
migrazioni, niente che possa restare appeso a metà.

Non è eleganza. **I tratti in questo gioco sono salvati DUE volte** —
`dna.tratti` e `animo.tratti` — e la copia da cui il gioco legge è la seconda:
`_ensure_brain` fa `setup(dna)` e **poi** `load(salvato)`, che riscrive
`tratti`. Un delta scritto lì dentro sarebbe diventato permanente al primo
`save()` e si sarebbe **ricomposto a ogni caricamento**: chi era sarebbe
perduto, e non ci sarebbe più nessun posto da cui tornare.

### LA REGOLA: la deriva entra dove il tratto COLORA

> **e non entra in nessuna funzione la cui uscita è una PORTA, una SOGLIA o
> una FRASE.**

Non è pignoleria: sono due vie d'uscita dal genere, trovate leggendo il codice
invece che scoprendole in partita.

- **`soglie()` decide chi se ne va dal villaggio.** Abbassa il gradino della
  diserzione di `codardia × 0,28`, e sotto c'è `Visitors._congeda()`. Con la
  deriva dentro, *«protetto e nutrito»* sarebbe diventato **«se ne va
  prima»**: il giocatore avrebbe perso i vicini di cui si è occupato di più.
  Misurato: 0,35 di codardia si mangia il **60%** del campo naturale fra
  quattordici residenti.
- **`Affetti.conto()` legge tutto il libro mastro con la mezza vita della
  lealtà**, comprese le righe di sei mesi fa. Una lealtà che deriva
  **riscriverebbe il passato**, e potrebbe sciogliere una coppia senza che
  nessuno abbia fatto niente — `ancora_coppia()` è un confronto fra conti, e
  una mezza vita più corta schiaccia il passato e lascia in piedi il recente.
  *La mezza vita è la grammatica con cui si legge la storia, non un colore.*
- E il **testo** legge la base per una ragione più semplice: quello che uno
  dice quando sbotta è chi è sempre stato.

### LA FORMA: una frazione della PROPRIA distanza dal bordo

`δ = FRAZIONE × pressione × (distanza dal proprio bordo, in quella direzione)`

È il vincolo «mai oltre una frazione del tratto originale» letto alla lettera,
e in cambio regala **tre teoremi invece di tre tarature**:

1. **nessuno arriva al muro, a nessuna ampiezza.** Un tetto additivo di ±0,35
   porterebbe al muro il **47%** dei valori veri — tre codardi a 0,85 / 0,92 /
   0,98 diventerebbero *tre volte la stessa persona*. Qui è zero per
   costruzione.
2. **a parità di prove l'ordine si conserva** (la derivata rispetto alla base
   vale `1 − FRAZIONE·|s| > 0`).
3. **chi nasce a 0 o a 1 non deriva** — non ha strada da fare.

`FRAZIONE = 0.40` non è scelta: sotto 0,20 di spostamento **non si vede niente
su nessun canale** e 0,35 è il 94° percentile. In mezzo c'è **una deviazione
standard (0,2146)**, misurata sul generatore vero, e al valore mediano della
codardia questa frazione dà esattamente quello.

### LE TRE REGOLE DELLE SPINTE, e sono strutture

1. **Solo prove POSITIVE e datate di cose ACCADUTE.** Mai il conteggio di ciò
   che non è successo: sarebbe una punizione per chi gioca in un altro modo.
   Collaudo meccanico: **senza righe, δ = 0.000**.
2. **Solo carburante UNO-A-UNO**, col cancello sulla chiave
   `attore == "giocatore"` — non su una lista di esclusioni.
3. **La quantità la porta la RIGA**: qui si dichiara solo la **direzione**.
   Questo cancella una classe intera di taratura, e fa sì che lo stesso piatto
   valga numeri diversi per due vicini (la valenza passa già dal `Limbico` di
   quella persona).

⚠️ **E DUE ESEMPI DELL'AUTORE NON SONO ENTRATI, con la misura in mano.**

- *«chi è stato protetto per venti notti»*: la riga `vegliato` la Veglia la
  scrive a **ogni** residente **ogni** mattina — 1,000 per residente per
  giornata, identica per tutti. È una marea che solleva tutte le barche, cioè
  nessuna. La versione sui binari vuole prima che la Veglia sappia dire **chi**
  ha avuto la *propria* porta al buio.
- *«chi è stato spesso solo diventa più autonomo»*: il suo carburante è
  un'**assenza** (regola 1), e «più autonomo» in questo codice è l'orgoglio —
  il solo tratto che **non tinge nessun canale del corpo**. La versione sui
  binari è la sua metà positiva: *chi ha passato molto tempo con qualcuno
  diventa un filo più leale*, dalle righe di co-presenza — **ed è entrata**
  (sotto, «LA LEALTÀ DALLA CO-PRESENZA»).

### I TRATTI CHE NON DERIVANO, e non è una dimenticanza

- **la GRINTA**: il suo unico carburante candidato è il lavoro, che fa fuoco
  1,000 volte per residente per giornata **per tutti**; e il suo canale sul
  corpo è l'**adenosina**, cioè la stanchezza — la sola direzione che non si
  riesce a dichiarare «diversa e non peggiore».
- **l'ORGOGLIO**: non tinge nessun canale, e i suoi tre lettori sono una
  porta, una crisi e una frase. Un tratto che non può colorare nulla non
  deriva.
- **l'AMBIZIONE deriva**, e vedi «IL SOGNO SERVITO» più sotto: il carburante
  che il piano proponeva non poteva entrare, ma la sua metà positiva sì.

### I NUMERI, misurati sulle biografie vere

`tools/misura_deriva_vera.gd`, tredici residenti del salvataggio vero:

| | |
|---|---|
| prove del giocatore per residente per giornata | media **0,744** · massimo 2,333 · **dev.std 1,014** |
| chi si è mosso di più | Cannella `0,724 → 0,534` · Ciliegia `0,617 → 0,434` · Nuvola `0,544 → 0,397` |
| chi non ha prove del giocatore | δ **esattamente +0,0000** |
| ⚠️ **tratti al muro** | **0** |
| ⚠️ **dispersione della codardia** | di nascita **0,2339** → derivata **0,2373** |
| inversioni d'ordine | 8 su 78 coppie (10%) |

**La dispersione non scende: sale.** È il cancello di arresto più importante —
se il villaggio rendesse le persone uguali, il meccanismo andrebbe tolto
qualunque cosa dicano gli altri numeri — e passa perché la dev.std del flusso
(1,014) è **più grande della sua media**: il giocatore non può essere gentile
con ventotto persone nello stesso pomeriggio, e *quello* è il vincolo che fa
la varietà.

⚠️ **E due cose vanno dette sui numeri, invece che lasciate credere:**

- **il flusso misurato è il MIO banco, non un giocatore.** Il mio porta
  qualcosa a qualcuno ogni ventisette secondi: è un tetto, non una media. Con
  un giocatore più parco la deriva è più lenta, e la tabella slitta.
- **la deriva satura in fretta**: proiettata, una stagione dà δ −0,195, tre
  stagioni −0,228, dodici −0,233. Quasi tutto il movimento è nella **prima**
  stagione, non «fra la prima e la terza» come il progetto prevedeva.

### E il RITORNO è più lento di quanto il progetto dicesse

Il piano diceva «δ si dimezza in diciotto giornate». Vero solo dove la
saturazione è quasi lineare. Misurato: con cinque gesti leggeri dopo una mezza
vita resta il **54%**; con venti gesti pieni resta l'**86%**. *Chi è stato
curato molto non torna indietro in tre settimane* — detta così è anche più
vera, ma andava saputa.

### Come si verifica

```
Godot --headless --path . --script res://tests/test_runner.gd
CHIBI_GIORNI=3 Godot --headless --path . --script res://tools/misura_deriva_vera.gd
CHIBI_GIORNI=2 CHIBI_QUANTI=13 CHIBI_GAZEBO=1 \
  Godot --headless --path . --script res://tools/misura_insieme.gd   # sez. 11
```

Il primo banco ha **tre numeri di arresto dichiarati prima di misurare**:
nessun tratto al muro, la dispersione che non scende, e il flusso che non è
uniforme. Il secondo è quello della lealtà, e va letto **due volte**: il suo
flusso balla di cinque volte fra due corse uguali, e una corsa sola non dice
niente.
Se uno esce storto, **il piano è sbagliato e va detto, non tarato** — e in
particolare *non si abbassa `SAZIETA`*: abbassarla fa saturare tutti e cancella
proprio la varietà.

**Le guardie sono state falsificate una per una, ventidue mutazioni.** E
**sette erano mute alla prima stesura**, tutte della stessa famiglia — un caso
che passa perché un altro cancello lo copre:

- il caso del TESTO ha avuto bisogno di **tre** stesure: la prima confrontava
  due chibi qualunque (se la codardia non sta vicino alla soglia la frase non
  cambia in nessuno dei due casi); la seconda dava al termine di paragone gli
  stessi ricordi, e allora **derivava anche lui**. La forma che funziona ha
  **tre corpi** e rende la soglia osservabile. E il fixture deve avere
  qualcosa di cui lamentarsi, o `sfogo_rimandato` esce alla prima riga;
- il caso del carburante aveva **due cancelli in gioco insieme** (il tipo e
  l'attore) e ognuno mascherava la mutazione dell'altro;
- la recenza era coperta solo sulle righe vive e **non sul sommario**, che è
  la metà che sopravvive nei villaggi pieni di vita;
- e il **colore** non era sorvegliato affatto: la mutazione che scollega la
  deriva dal suo unico consumatore lasciava la suite verde.

### ⚠️ E DUE RIPARAZIONI CHE SERVIVANO PRIMA — «protetto» e «l'ho scelto io»

Due dati che il gioco produceva ogni giorno erano **inutilizzabili come
spinte**, e in tutti e due i casi per la stessa ragione: non distinguevano
nessuno.

**La giornata scelta era incisa contro il giocatore.** `Lavori` fa decidere
da sé chi non ha un incarico — passa `"se_stesso"` a `decide()`, e il commento
accanto promette *«nel ricordo resterà così»* — ma poi `assegna_compito` la
incideva con `"giocatore"` cablato. Misurato nel salvataggio vero: il registro
degli incarichi **vuoto**, e tutte e settantotto le righe di compito intestate
a lui. Non è contabilità: `rancore("giocatore")` contava così dei torti che il
giocatore non ha ordinato, e la distinzione *«quante delle mie giornate le ha
decise qualcun altro»* — il carburante della lealtà e dell'ambizione — non
poteva nascere.

⚠️ **E la guardia che sorvegliava quella riga matchava il proprio commento**:
cercava la stringa `"se_stesso"` nel sorgente, e c'era — dentro `decide()`,
mentre il difetto stava tre chiamate più in là. Adesso è comportamentale, e
attraversa il cablaggio vero: la prima stesura chiamava `Animo.esegue` diretto
e **lasciava verdi tutte e due le mutazioni**.

**E «protetto» era il meteo del villaggio.** `Veglia` chiedeva `al_buio()`
**solo nel ramo senza guardia**: con una guardia in servizio ogni residente
riceveva la stessa identica riga `vegliato` — 1,000 per residente per giornata,
uguale per tutti e quattordici. Adesso la riga va a chi la ronda ha **davvero**
protetto, cioè a chi era al buio; chi ha una luce davanti a casa era già al
sicuro, per un gesto che il giocatore ha fatto mesi prima e che si vede nel
fatto che *non perde sicurezza*.

Le chiavi restano due, tutte e due sue: **assegnare la guardia** e **piantare i
lampioni** — e la seconda si può fare *prima di sapere che serve*. È la
condizione che mancava perché «chi è stato protetto per venti notti» possa un
giorno entrare fra le spinte: il numero che lo falsifica è che le righe per
residente abbiano **min ≠ max**.

### IL SOGNO SERVITO — «mi hai dato il lavoro che sognavo»

Terzo tratto che deriva, e il primo per cui **il carburante proposto non
poteva entrare**. L'idea era *«quante delle mie giornate le ha decise qualcun
altro»* → ambizione. Quelle righe non passano **nessuno** dei due cancelli di
`Deriva`: hanno `attore == "se_stesso"` (non uno-a-uno col giocatore) e
valenza **negativa** — `Animo.esegue()` scrive `-0.08 * mult` per un compito
qualunque, cioè sono torti, e *un torto non deve poter spostare chi sei*.

Ma dentro la stessa funzione c'è **l'unica riga di compito con valenza
positiva**: `+0.12`, e la scrive *soltanto* quando il compito serve il sogno
di quella persona. E l'ordinante è `"giocatore"` quando il lavoro viene
dall'incarico della Lavagna. Cioè il gesto è: **leggere il sogno di qualcuno e
dargli quel lavoro**.

- `Deriva.SOGNO := {"ambizione": 1}`, e la direzione è verso l'alto: chi si
  vede riconosciuto osa di più. **Non è «meglio»** — l'ambizione fa pesare la
  noia, rende i compiti umili più amari, fa tirare il sogno, e alza la
  dopamina di riposo. È un carattere diverso.
- **La metà speculare resta fuori**, e non per simmetria: «chi non ha deciso
  da sé» sarebbe una punizione per chi usa la Lavagna, cioè per uno stile di
  gioco. La Lavagna è una meccanica del gioco: non può costare.
- **Il tipo della riga è il nome del compito**, e i nomi vivono in
  `Animo.COMPITI`: `Animo.compiti_del_sogno()` li passa a `Deriva` come DATO.
  Ricopiarli di là sarebbe la tabella gemella — la stessa disciplina con cui
  il villaggio presta la compagnia.

**MISURATO in partita** con la porta VERA (`Lavori.assegna` → `_on_nuovo_giorno`
→ `assegna_compito` → `esegue`), tredici residenti, quattro giornate:

| | δ ambizione |
|---|---|
| col **sogno servito** (7 residenti) | media **+0,0169** · da +0,0030 a **+0,0342** |
| con un lavoro **qualunque** (6) | **+0,0000 · +0,0000 · +0,0000** |

È la separazione che «vegliato» non aveva: lì il flusso era 1,000 righe per
residente per giornata **identiche per tutti**, qui è tutto o niente e lo
decide il giocatore.

**Sei mutazioni, tutte rosse.** Una era muta alla prima stesura, e per la
ragione già pagata: **il cancello della valenza è coperto dal cancello del
tipo** — passando dal gioco un compito-del-sogno ha *sempre* `+0.12`, quindi
toglierlo non cambiava niente. Ma `spinta()` è pura e riceve `ricordi` come
DATO: il cancello è una proprietà sua, non del suo unico chiamante di oggi. Si
prova fabbricando la riga che il gioco non produce (un compito del sogno con
valenza `-0.9`) e pretendendo zero, con la controprova positiva accanto.

### LA LEALTÀ DALLA CO-PRESENZA — e il residuo che si chiude

*Chi ha passato molto tempo con qualcuno diventa un filo più leale.* È il
secondo tratto che deriva, ed è la metà positiva di un'idea dell'autore che
non poteva entrare com'era («chi è stato spesso solo diventa più autonomo»,
che ha per carburante un'**assenza**).

**Il carburante esisteva già e finiva nel cestino**: le righe di co-presenza
del registro delle Cricche (`_incontri`), che sono datate, **senza verso** (i
due nomi in ordine alfabetico) e distinguono per davvero. Zero contatori
nuovi, zero campi nel salvataggio.

- `Deriva.COMPAGNIA := {"lealta": 1}` — una direzione, e la quantità la porta
  la riga, come tutte le altre spinte.
- **Ogni riga è pesata dalla stessa recenza di tutto il resto.** Non è un
  dettaglio: è il vincolo dell'autore — *il ritorno dev'essere sempre
  possibile*. Senza la data, chi ha passato tre settimane con qualcuno due
  anni fa resterebbe più leale **per sempre**, e la deriva diventerebbe una
  cicatrice.
- **Il ponte è una riga al giorno** (`Visitors._presta_la_compagnia`, dentro
  `_giorno_di_animo`, **prima** di far passare la giornata): il registro vive
  in un altro nodo e si passa come DATO, invece di far leggere ad `Animo`
  mezzo albero della scena. Senza il ponte, tutto questo è aritmetica che
  nessuno esegue mai — il guasto che questo progetto ha già pagato cinque
  volte, e per questo la guardia chiama il **giorno vero**, non la funzione.
- **La chiave a forma di GIOCATORE** non è nuova ed è già forte: è tutto il
  lavoro dell'INSIEME. Lui posa i mobili a sedute fratelle, e **lui fa da
  ponte sedendosi** — due vicini che si siedono accanto a Mochi scrivono una
  riga fra loro due.

**I NUMERI, dal villaggio vero** (`tools/misura_insieme.gd`, sezione 11 —
tredici residenti, due giornate, col Gazebo). **Due corse con gli stessi
identici parametri**, e la prima cosa da dire è che non si somigliano:

| | corsa A | corsa B |
|---|---|---|
| righe di co-presenza per residente per giornata | **0,31** | **1,77** |
| chi si è mosso dopo due giornate | 5 su 13 | **12 su 13** |
| δ medio · massimo | +0,042 · +0,216 | **+0,148** · +0,267 |
| proiezione a 7 · 28 · 112 giornate | +0,173 · +0,240 · **+0,245** | +0,2455 · +0,2457 · **+0,2457** |
| il tetto di `delta` su quel residente (`FRAZIONE` 0,40) | +0,246 | +0,246 |

⚠️ **IL FLUSSO BALLA DI CINQUE VOLTE E MEZZO FRA DUE CORSE UGUALI**, e chi
scrive «0,31 righe al giorno» come se fosse una misura sta scrivendo il
rumore di un villaggio. Dipende da come quel villaggio è nato: quanti letti
finiscono vicini, chi si stanca alla stessa ora, se il Gazebo è sulla strada
di qualcuno. Il numero onesto è **fra 0,3 e 1,8**, e va riportato così.

**Ed è proprio per questo che il risultato conta: le due corse finiscono
nello stesso posto.** Tutte e due si fermano a **+0,246 sul tetto di
`delta`** — il 99,5% e il 99,96% di quanto la forma concede. Il flusso decide
*quanto in fretta*, la forma decide *fin dove*, e fin dove è il 40% della
distanza che quella persona aveva dal bordo. Nessuno diventa irriconoscibile
perché non gli è permesso, non perché il flusso sia stato tarato piano.
E la saturazione è più rapida di quanto la codardia avesse mostrato: nella
corsa B la deriva è **già tutta lì dopo sette giornate**.

⚠️ E i due zeri della tabella sono la regola che morde, non un guasto: chi ha
**zero righe** resta esattamente dov'era (`Loto: 0 righe, +0,000` — nessun
malus per chi sta per conto suo), e chi ha la lealtà **già al muro** non si
muove perché `delta` lì vale zero per costruzione. Il banco stampa perciò la
**base accanto al δ**: nella corsa A un residente con una riga e +0,000 non
era spiegabile, ed è per quello che quel numero adesso c'è di fianco.

**IL RESIDUO CHE SI CHIUDE, e perché era il pezzo importante.** Stava scritto
in `Affetti._lealta_di` che la mutazione `tratto_base` → `tratto` non era
falsificabile (la lealtà non derivava ancora: i due davano lo stesso numero) e
che **chi avesse cablato la deriva doveva renderla rossa prima di
consegnare**. È stata resa rossa (`test_deriva`, il caso della lealtà che
deriva senza riscrivere il passato).

E **la misura ha corretto il timore di allora**, che diceva «una mezza vita
più corta schiaccia il passato e scioglie una coppia». La deriva della lealtà
è solo POSITIVA, quindi la mezza vita si **allunga**: sullo stesso identico
libro mastro il conto passa da **0,5874 a 0,7443, +27%**. Non scioglie una
coppia — ne **fabbrica** una. `SOGLIA_COPPIA` è un confronto assoluto, e chi
ha passato molto tempo con C si vedrebbe gonfiare il conto con B, cioè
finirebbe in coppia con B **senza che fra loro sia successo niente di nuovo**.
È lo specchio esatto della regola 3 degli Affetti.

**Le cinque mutazioni, tutte rosse** (e tre erano mute alla prima stesura,
cioè tre buchi veri): la compagnia non è più un carburante · non ha più
recenza · il villaggio non fa più il ponte · le giornate insieme guardano un
lato solo della riga (che non ha verso, quindi dimenticarne uno è la
distrazione plausibile) · senza il registro si tiene la compagnia di ieri.

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

## LA LICENZA DEI PESI — si spedisce Gemma, e ha condizioni

Dal 2026-08-13 il gioco **spedisce il modello dentro il pacchetto**:
`gemma-3-4b-it` Q4_K_M, la riquantizzazione pubblicata da
[`ggml-org`](https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF). Quindi non
lo usiamo soltanto: lo **ridistribuiamo**, a scopo commerciale, dentro un
prodotto la cui [`LICENSE`](LICENSE) è proprietaria. Sono due cose diverse, e
la seconda ha obblighi che la prima non aveva.

**La licenza del motore NON è la licenza dei pesi.** llama.cpp è MIT; i pesi
stanno sotto i **Gemma Terms of Use** (<https://ai.google.dev/gemma/terms>),
che richiamano per riferimento la **Gemma Prohibited Use Policy**. Chi ha
quantizzato non aggiunge niente di suo: `ggml-org` dichiara `license: gemma`,
non è *gated*, e non ha un file di licenza proprio. E prendere il file da lì
non cambia nulla — Sezione 1.1(c): «Gemma» sono quei pesi *«regardless of the
source that you obtained it from»*. Lo dice anche il `.gguf`, nella chiave
`general.license`.

### I quattro obblighi, e dove stanno

La **Sezione 3.1** pone quattro condizioni alla ridistribuzione. Non sono
formalità: senza, il permesso di ridistribuire non c'è.

| 3.1 | cosa chiede | dove |
|---|---|---|
| 1 | i vincoli d'uso della 3.2 come **clausola vincolante** nell'accordo d'uso, più l'avviso a chi riceve | [`LICENSE`](LICENSE), sezione «GEMMA MODEL WEIGHTS» (e la gemella italiana) |
| 2 | **una copia dell'accordo** a ogni destinatario | `misc/licenze/Gemma-Terms-of-Use.txt` |
| 3 | avvisi sui **file modificati** | non ne modifichiamo nessuno; la catena è dichiarata nel NOTICE |
| 4 | un file **«Notice»** con la frase esatta | `misc/licenze/NOTICE-Gemma.txt` |

**I file viaggiano DUE volte, e servono tutte e due le strade.** Accanto
all'eseguibile (`release.yml`: cartella `Licenze/`; su macOS **dentro** il
bundle, in `Contents/Resources/Licenze/`, perché il `.app` è l'artefatto che
l'utente trascina e una cartella lasciata accanto resterebbe indietro), e
dentro il `.pck` (`include_filter` in `export_presets.cfg`) perché la pagina
**Note legali** del gioco possa leggerli. Un file dentro un `.pck` non
«accompagna» niente per chi riceve il gioco — su Windows il `.pck` è pure
embedded nell'`.exe`; un file accanto all'eseguibile non lo apre quasi
nessuno. Una la legge il gioco, l'altra la legge una persona.

> ⚠️ **NESSUNA SOGLIA.** Nei Gemma Terms of Use la parola «commercial» non
> compare, e non c'è nessuna soglia di utenti o fatturato (Llama ne ha una a
> 700 milioni di utenti mensili; questa no). Gli obblighi sono identici alla
> prima copia e alla milionesima.

> ⚠️ **GEMMA 3 E GEMMA 4 NON HANNO LA STESSA LICENZA.** L'Appendix dei
> Termini elenca **Gemma 3**; **Gemma 4 no** — è **Apache 2.0**
> (<https://ai.google.dev/gemma/apache_2>), senza flow-down e senza vincoli
> d'uso. Passare a `gemma-4-E2B` (l'altro candidato misurato più sopra) vuol
> dire **rifare questa sezione da capo**, non ritoccarla.

### Le tre trappole già pagate

1. **La frase della 3.1 punto 4 deve stare su UNA riga.** La prima stesura
   del NOTICE la mandava a capo dopo «found at»: si leggeva benissimo e la
   stringa richiesta **non c'era**. Stessa cosa era successa alla clausola
   italiana del `LICENSE` («prevalgono i Gemma Terms of Use», spezzata a
   metà). Se n'è accorto il banco, non la rilettura — e ora ci sono due
   guardie che la cercano intera.
2. **Gli avvisi MIT non si ricopiano a mano.** `tools/genera_licenze.py`
   assemble `LICENZE-TERZE-PARTI.txt` **leggendo i LICENSE veri** (godot-cpp,
   EnTT, lua-gdextension, llama.cpp, più i due contributi incorporati nei
   sorgenti di ggml). Un avviso ricopiato invecchia in silenzio: il giorno
   che EnTT cambia intestazione, il file spedito dichiara il falso e nessun
   test lo vede. E l'intervallo di righe comprende il **permesso** per
   intero, non la sola riga di copyright — «the above copyright notice AND
   this permission notice».
3. **Il gioco esportato non aveva MAI avuto un avviso di licenza.** Non è un
   difetto della Fase 5: godot-cpp, EnTT, lua-gdextension e Godot stesso sono
   MIT e chiedono l'avviso «in all copies» da sempre. Il pacchetto usciva
   senza. Adesso `release.yml` ha un cancello che apre gli zip **veri** e si
   ferma se manca un file o se la frase è stata riscritta.

### Come si verifica

```
python3 tools/genera_licenze.py --verifica      # l'avviso spedito è aggiornato?
Godot --headless --path . --script res://tests/test_runner.gd   # test_licenze.gd
CHIBI_NOTE=/tmp/note Godot --path . --resolution 1280x720 \
    --script res://tools/provino_note_legali.gd  # e come si LEGGE la pagina
```

MISURATO che `include_filter` funziona davvero, invece di sperarlo:
`--export-pack` (che non richiede gli export template) produce un `.pck`
dove i quattro file ci sono — l'indice li elenca senza il prefisso `res://`,
ed è per questo che una prima ricerca con `res://misc/licenze/` non trovava
niente e sembrava che l'export li lasciasse fuori.

**Quello che NON è chiuso** sta in fondo a
[`docs/LICENZA_MODELLO.md`](docs/LICENZA_MODELLO.md): sono le domande da
girare a un legale prima di pubblicare. **Non sono state risolte qui, e non
vanno spuntate da un agente.**
