# Chibi Crossing 🐾🌸

Un life-sim *cozy* psicologico e sistemico con protagonista **Mochi**, una gattina chibi. Tutto è morbido, pastello e "dipinto a mano" — ma sotto la superficie pulsa un'architettura tecnologica e di intelligenza artificiale all'avanguardia nell'industria videoludica. (C'è anche un lato horror, per ora dormiente — vedi in fondo.)

**Motore:** Godot 4.7 (Forward+, D3D12/Metal, Jolt Physics) con gameplay core in C++ via GDExtension (ECS EnTT, llama.cpp, simulazione ecologica).  
**Arte e Audio:** 100% Procedurali — **zero texture esterne, zero file audio registrati**.

---

## 🌟 Le Eccellenze Tecniche & Il Cuore AI (Perché è Unico)

Chibi Crossing si distingue da qualsiasi altro simulatore di vita per l'integrazione di sistemi ingegneristici di livello accademico applicati al genere cozy:

### 1. 🧠 Intelligenza Artificiale Generativa Locale (LLM C++ Nativo)
* **Modello Linguistico Integrato:** Esegue modelli LLM locali in formato GGUF (architettura Llama/Gemma via `llama.cpp` nativo) direttamente dentro la GDExtension C++.
* **Zero Cloud, 100% Privacy e Offline:** Nessun server esterno, nessuna chiamata API, nessun costo o latenza: le lettere del Gufo, i monologhi interiori e le reazioni dei vicini sono generati localmente sulla macchina del giocatore.
* **Fallback Invisibile ("Regola della Fase 5"):** Se il modello non è presente o la macchina non lo supporta, il gioco ricade istantaneamente e senza errori sui testi procedurali pre-scritti: il gioco è intero e godibile su qualsiasi hardware.

### 2. ⚡ Architettura ECS in C++ ad Alte Prestazioni (EnTT)
* **Simulazione Nativa:** Il cuore logico (`src/ecs_mondo.cpp`, `sistema_piani.cpp`, `sistema_agenda.cpp`, `sistema_sonno.cpp`) utilizza un pattern Entity-Component-System basato sulla libreria nativa **EnTT**.
* **Decine di Abitanti a 60+ FPS:** Gestisce pianificazione, biosfere, navigazione e memorie di decine di entità contemporaneamente con footprint di memoria ridottissimo e zero overhead da garbage collector.

### 3. 🎯 Utility AI Psicologica & Percettrone Explainable (XAI)
* **L'Animo (`Animo.gd`):** Gli NPC non seguono binari temporali rigidi. Sono guidati da 6 bisogni primari (*fatica, noia, sicurezza, autonomia, appartenenza, stima*) e 5 tratti del carattere (*orgoglio, lealtà, grinta, codardia, ambizione*). Calcolano l'utilità marginale delle azioni e scelgono liberamente cosa fare.
* **Spiegabilità all'Indietro (`racconta()`):** Il sistema è un'Explainable AI: ogni decisione o scatto di ribellione sa spiegare matematicamente la sua causa (es. *"L'ho fatto perché ero stanco e mi mancava autonomia"*). L'LLM legge questa logica formale per formulare il dialogo.
* **La Mente del Candidato (Percettrone):** La valutazione delle case costruite per i traslochi usa una rete neurale a singolo strato (Percettrone con funzione di attivazione sigmoidea) che pesa le feature della casa rispetto alla specie e al DNA dell'aspirante abitante.

### 4. 🕸️ Memoria Sociale a Grafo, Deduzioni e Gossip
* **Libro Mastro degli Affetti (`Affetti.gd`):** Le relazioni non sono barre numeriche 0-100. Ogni gesto (un aiuto, una veglia, un pasto) viene registrato con data e peso. L'amicizia e l'amore sono predicati derivati con curva di decadimento temporale (`mezza_vita = 18 giorni`).
* **Grafi di Conoscenza (`grafo_ricordi.cpp`, `grafo_deduzioni.cpp`):** I ricordi transitano tra gli abitanti via pettegolezzo; le voci si attenuano e si deformano fisiologicamente nel tempo senza creare fazioni tossiche o giudizi morali.

### 5. 🎭 Il Vocabolario del Corpo (Animazione Espressiva a Distanza)
* **Sette Gesti Leggibili:** L'interiorità degli NPC è tradotta visivamente attraverso pose fisiche e procedurali ottimizzate per essere leggibili da 2 a 9 metri da ogni angolazione (tra cui *Il Punto* — l'arresto che spicca nel movimento — e *Il Raccolto*).
* **Zero Falsi Positivi:** Corretta ogni discrepanza emotiva (la coda guardinga scatta solo per paure reali e mai per gioia; la testa affonda nelle spalle per mostrare timore senza perdere il profilo della silhouette).

### 6. 👥 Cricche e Dinamiche di Gruppo Derivate
* **Nessun Gruppo Forzato:** Il predicato `cricca()` è calcolato matematicamente senza campi salvati o classifiche sociali. Chi ama stare da solo non viene penalizzato.
* **Chiusura Transitiva dell'Amicizia:** Se A è amico intimo di B e di C, fungerà da "ponte" facendoli conoscere, originando cricche spontanee ed evitando agglomerati artificiali al falò.

### 7. 🦋 Ecosistema Dinamico Emergente (C++)
* **Manager Demografico (`src/ecosystem_manager.cpp`):** Farfalle e lucciole non sono particelle grafiche casuali, ma popolazioni simulate con capacità portante.
* **Impollinazione Reale:** Le farfalle visitano i fiori e li impollinano generando nuovi fiori selvatici; le lucciole depongono uova vicino allo specchio d'acqua. Semine e raccolti del giocatore disperdono semi che i passerotti possono mangiare o che possono germogliare: ogni villaggio ha un ecosistema biologico unico.

---

## 🌺 Il Sistema Emozionale "Il Filo Rosso"

Un legame invisibile connette Mochi ai suoi compagni di villaggio ([`docs/SISTEMA_EMOZIONALE.md`](docs/SISTEMA_EMOZIONALE.md)):

* **La Memoria dei Momenti:** Il gioco registra i momenti chiave (il benvenuto sulla soglia, il primo bagno insieme all'Onsen, la tazza di tè condivisa sotto la pioggia).
* **Invecchiamento Biologico Visibile e Uditivo:** Con il passare dei mesi i vicini invecchiano: il pelo assume sfumature argentee, il passo rallenta (-38%), compare il bastoncino di ciliegio e la **voce Chibiese invecchia organicamente** (frequenze più basse, incrinature di respiro, cadenza lenta).
* **Il Congedo Gentile (Il Grande Prato):** Nessun personaggio muore o sparisce bruscamente. Dopo una vita piena e una settimana di desideri condivisi, il vicino parte per il "Grande Prato". Sul posto nasce un **fiore unico generato dal suo DNA**, in cielo si accende la sua costellazione, sul Grande Albero viene inciso un anello dorato e il suo accessorio entra nel guardaroba di Mochi.
* **Lutto Giocato ed Empatia Bidirezionale:** Nel periodo di lutto Mochi cammina a testa bassa; gli altri residenti se ne accorgono, la raggiungono e le si siedono accanto in silenzio per farle compagnia o le portano un piatto caldo.
* **I Sogni Notturni (`Sogni.gd`):** Durante il sonno, il gioco recupera i ricordi più a rischio di essere dimenticati e li mette in scena in sequenze oniriche mute, rendendoli indelebili per sempre nel cuore del villaggio.

---

## 🎮 Come si gioca

| Input | Azione |
|---|---|
| **WASD / Frecce / Stick** | Cammina |
| **Spazio** | Corri (consuma stamina, occhi ">.<" con isteresi) |
| **E** | Interagisci (siediti, dormi, parla, raccogli, pesca, cucina, annaffia) |
| **B** | Modalità Costruzione (Builder) |
| **Rotella / 1-9 / Tab** | Scegli pezzo nel catalogo di costruzione |
| **R** | Ruota pezzo in costruzione / Avvia proiettore dei Ricordi |
| **F** | Ruota oggetto già piazzato |
| **V** | Alterna piano di costruzione (Piano Terra / Secondo Piano) |
| **Clic Sinistro** | Piazza pezzo / Demolisci (se ✕ Demolisci attivo) |
| **X** | Rimuovi / Demolisci rapido |
| **H** | Imposta letto corrente come Casa Propria |
| **G** | Apri Guardaroba / Cambia abito |
| **P** | Modalità Fotografica (volo libero con WASD + Mouse, clic per scatto) |
| **F2** | Attiva/Disattiva Co-op Locale sul Divano (Giocatore 2 con IJKL + U) |

---

## 🏡 Cosa c'è nel Mondo

### Mochi & I Residenti
* **Mochi Procedurale (`scenes/characters/Mochi.gd`):** Cel-shading pastello, animazioni a codice con molleggio, orecchie vive, coda reattiva, battito di ciglia e posa a letto con "z" di carillon.
* **DNA & Archetipi (`ChibiDNA.gd` + `ChibiBuilder.gd`):** Ogni vicino nasce da un genoma unico (gattini, conigliette, orsetti, volpine, topolini), proporzioni, orecchie, accessori e personalità dedicati.
* **La Lingua "Chibiese" (`audio/Chibiese.gd`):** Voci spaziali generate da sintesi di formanti con 15 vocaboli fissi (*"ta-ki"* = grazie, *"ni-nu"* = pioggia, *"po-mo"* = casa) che il giocatore può imparare a comprendere a orecchio.

### Il Builder Architettonico & Le Grandi Opere
* **Verticalità e Secondi Piani (`BuildSystem.gd`):** Griglia multilivello, scale salibili in fisica reale, solai calpestabili, ponticelli di corda e dissolvenze a "casa di bambola" (cutaway dei muri e tetti trasparenti quando Mochi è all'interno).
* **Edifici Speciali Modulari:**
  * **La Boutique (`BuildBoutique.gd`):** 15 pezzi dedicati alla moda di paese, vetrine a tutta altezza, stender regolari, luce calda puntata sui manichini.
  * **La Chiesa di Paese (`BuildChiesa.gd`):** Navata simmetrica, campanile con banderuola a rondine, abside tondo, rosone con cuore rosso e vetrate colorate procedurali.
  * **La Palestra Rustica (`BuildPalestra.gd`):** Attrezzi in legno, corda, cuoio e pietra di fiume con punti d'uso esatti per gli allenamenti dei villager.
  * **La Casa sull'Albero:** Rifugio panoramico con lanterne oscillanti al vento dove i vicini salgono ad ammirare il tramonto.
  * **Serre & Rastrelliere Modulari:** Strutture che si fondono e si allineano automaticamente posizionando i pezzi vicini.

### Attività, Raccolta & Sopravvivenza Dolce
* **Giardinaggio & Orto (`Garden.gd`):** Aiuole fiorite e orto contadino con carote, zucche e bacche. Crescita non punitiva (senza acqua le piante aspettano senza morire).
* **Cucina del Camino (`Cooking.gd` + `Pasto.gd`):** 7 ricette su carta crema. Pentolino che sobbolle al fuoco, vapore, e rituale del pasto a tre bocconi visibili con briciole, ciotola che si svuota e soffio sul cibo caldo.
* **Pesca nello Stagno (`Fishing.gd`):** Canna con filo a simulazione fisica, galleggiante, increspature dell'acqua e pesciolini esposti in barattoli-acquario.
* **Messaggi in Bottiglia (`Bottiglie.gd`):** Bottiglie che scendono lungo la cascata portando lettere da mittenti lontani e regali rari.
* **Scavi del Mattino (`Scavi.gd`):** Punti dorati luccicanti sull'erba da scavare a zampate per dissotterrare tesori e campanelle di coccio.
* **L'Onsen del Bosco ♨ (`Onsen.gd`):** Pozza termale con riflessi in tempo reale, vapori bassi, lanterne tōrō e recupero rapido di stamina. I vicini entrano in accappatoio per condividere il bagno.
* **Costellazioni & Desideri (`Stargazing.gd`):** Collega le 260 stelle del cielo notturno per tracciare e battezzare costellazioni permanenti; esprimi desideri sulle stelle cadenti.
* **Il Grande Albero (`GrandTree.gd`):** Albero centrale che cresce giorno dopo giorno (`day^0.62`), incidendo a spirale sul tronco tutti gli eventi storici del villaggio.
* **Timelapse dei Ricordi (`Memories.gd`):** Ogni mattina scatta una foto identica in SubViewport invisibile: accendendo il proiettore ai piedi del Grande Albero puoi rivedere il film della nascita del tuo villaggio.
* **Il Rimbalzello (`Rimbalzello.gd`):** Fai rimbalzare sassi piatti sull'acqua dello stagno; ogni salto suona una nota pentatonica pura che dipende dal vento reale.
* **La Veglia Notturna (`Veglia.gd`):** Il guardiano designato compie la ronda accendendo lanterne di carta per regalare sogni tranquilli a chi riposa.

### Il Prologo Interattivo & Il Menù Vivente
* **Il Temporale del Prologo (`scenes/prologo/`):** 3 minuti giocabili senza scelte esplicite sotto una tempesta che forgeranno la personalità di Mochi, lasciando un marchio limbico curabile solo esponendosi serenamente alla pioggia.
* **Menù Principale Dinamico (`TitleScreen.gd`):** Carica i dati del villaggio in un istante, sincronizzandosi con l'ora reale dell'orologio del giocatore (alba, mezzogiorno, notte stellata) e riflettendo il clima emotivo della comunità (allegria, attesa o lutto).

---

## 🎨 Arte, Shader e Audio 100% Procedurali

* **Nessun File Audio Esterno (`audio/Sfx.gd`):** Tutti i suoni (passi su erba/parquet/pietra, vento, cinguettii, sciabordio dell'acqua, fusa, scatti di porte e carillon I-V-vi-IV) sono generati da sintesi matematica in codice.
* **Shaders Pittorici:**
  * `ground.gdshader`: Terreno acquerellato a transizione sfumata tra biomi.
  * `water.gdshader`: Acqua termale e fluviale con riflessi speculari veri, fresnel, increspature e spuma.
  * `vento.gdshaderinc`: Modello di vento unificato che attraversa il mondo facendo piegare erba, chiome e panni con ritardo fisico naturale.
  * `toon.gdshader` & `handpaint.gdshader`: Cel-shading pastello e lavaggio artistico applicato su ogni mesh generata.

---

## 👁️ Il Lato Oscuro (Dormiente)

Il gioco nasconde una variabile dormiente: `Mochi.anomalies_enabled = true`.  
Se attivata, il mondo fatato si spegne, gli occhi dei chibi diventano voragini nere e i comportamenti dell'AI deviano in una dimensione psicologica inquietante. Per quando sarà il momento.

---

## 📁 Architettura del Repository

```
src/                       Gameplay Core & Sistemi Nativi in C++ (GDExtension)
  ecs_mondo.*              Mondo Entity-Component-System (EnTT)
  curve_utilita.*          Calcolo curve matematiche per Utility AI
  grafo_ricordi.*          Grafo sociale delle memorie residenti
  grafo_deduzioni.*        Motore di deduzione a grafo
  sistema_piani.*          GOAP & Pianificazione autonoma
  sistema_agenda.*         Agende dinamiche residenti
  sistema_sonno.*          Gestione del riposo ed emissione sogni
  llm_gguf.* / llm_llama.* Integrazione motore llama.cpp (GGUF locale)
  llm_pensieri.*           Generazione pensieri e lettere interiori
  ecosystem_manager.*      Simulatore demografico di popolazioni (farfalle/lucciole)
  player_controller.*      Controller fisico WASD/gamepad
  survival_component.*     Barre fame/acqua/stamina native
  grid_manager.*           Snap geometrico per il builder

scenes/
  characters/              Mochi, rig animazioni, guardaroba, co-op
  npc/                     Animo, Affetti, Cricche, Gesti, VillagerMind, Limbico, Pasto
  build/                   BuildSystem, BuildCatalog, BuildBoutique, BuildChiesa, BuildPalestra
  interact/                Giardino, Cucina, Pesca, Sogni, Onsen, Scavi, Mail, Foto, Rimbalzello
  world/                   CozyWorld, DayNight, GrandTree, Weather, Ecosystem, Stargazing
  prologo/                 Sequenza iniziale del temporale e marchi psicologici
  ui/                      TitleScreen viva, HUD pastello, Tasche, Negozio, Diorama
  levels/                  MainLevel.tscn

systems/                   Autoload e Singletons (Llm.gd, L10n.gd, Settings.gd, ArbitroE.gd)
shaders/                   Shaders procedurali (vento, terreno, acqua, cel-shading, cielo)
audio/                     Sintetizzatore Sfx.gd e motore vocale Chibiese.gd
docs/                      Specifiche di design (Filo Rosso, Prologo, Traduzioni)
```

---

## 🛠️ Avvio e Compilazione

### Avvio Rapido
Apri la cartella con **Godot 4.7.1** e premi **Play (F5)**.

### Compilazione del Cuore C++ (SCons)
Assicurati di avere `scons`, `cmake` e un compilatore C++17 (MSVC su Windows, Clang/Xcode su macOS, GCC su Linux):

```bash
# Sottomoduli (godot-cpp e llama.cpp)
git submodule update --init --recursive

# Compilazione debug / release standard
scons platform=macos arch=universal target=template_debug -j8
scons platform=windows target=template_release -j8

# Compilazione con LLM locale attivo (Fase 5)
scons platform=macos arch=universal target=template_debug llm=yes -j8
```

### Verifica Automatica da CLI
```powershell
$env:CHIBI_SHOT = "output_folder"
godot --path .
```
Salva automaticamente gli screenshot di verifica (`cozy_vista.png`, `mochi_walk.png`, `mochi_closeup.png`, `mochi_builder.png`) ed esce.
