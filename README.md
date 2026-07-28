# Chibi Crossing

Un life-sim *cozy* alla Animal Crossing con protagonista **Mochi**, una
gattina chibi. Tutto è morbido, pastello e "dipinto a mano". (C'è anche
un lato horror, per ora dormiente — vedi in fondo.)

**Motore:** Godot 4.7 (Forward+, D3D12, Jolt Physics) con gameplay core in
C++ via GDExtension. Tutta l'arte è procedurale: zero asset esterni.

## Come si gioca

| Input | Azione |
|---|---|
| WASD / frecce / stick | cammina |
| Spazio | corri (consuma stamina, occhi ">.<") |
| **E** | siediti su sedie/sgabelli/panchine · dormi nel letto · alzati |
| **B** | modalità costruzione |
| rotella / 1-9 / tab categorie | scegli il pezzo |
| R | ruota il pezzo da piazzare |
| F | ruota un oggetto già piazzato |
| clic sinistro | piazza (o demolisce, con ✕ Demolisci attivo) |
| X | rimuovi |

## Cosa c'è

- **Mochi** (`scenes/characters/Mochi.gd`) — chibi procedurale con
  cel-shading pastello (scala 0.75: passa dalle porte). Legge la velocità
  del `PlayerController` C++ e anima da sola la camminata: rotazione
  fluida, passo saltellante, ondeggiamento, braccine, orecchie che
  sobbalzano, coda vivace e sbuffi di polvere. In corsa strizza gli occhi
  **">.<"** (con isteresi). In idle respira, sbatte le palpebre, si
  guarda intorno. Ha pose di **seduta** (gambette piegate, zampine in
  grembo) e di **sonno** (occhi chiusi, respiro profondo, "z" di
  carillon che salgono fluttuando).
- **Il prato** (`scenes/world/CozyWorld.gd`) — 3200 fili d'erba che
  ondeggiano al vento (MultiMesh + shader), fiori in tre varietà, alberi
  con un ciliegio che perde petali, cespugli, sassi del sentiero, nuvole
  soffici alla deriva, farfalle che svolazzano e pulviscolo dorato.
- **Il builder** (`scenes/build/BuildSystem.gd` + `BuildCatalog.gd`) —
  modalità costruzione stile AC su griglia (snap via `GridManager` C++),
  con griglia visiva che sfuma attorno al cursore. I pezzi "cell"
  occupano celle su 3 layer sovrapponibili (pavimenti / tappeti /
  oggetti); muri, finestre, porte e staccionate sono pezzi **"edge"**:
  agganciano i bordi tra le celle e si orientano da soli, come in AC.
  **23 pezzi in 3 categorie** (Struttura / Arredo / Giardino), tra cui
  **tetto** (diventa trasparente quando Mochi è in casa), letto, libreria
  con libri generati, camino con fuoco particellare e luce, panchina,
  cassetta della posta. Le **porte riempiono il varco**, si aprono da
  sole quando Mochi si avvicina e si richiudono alle sue spalle. I muri
  fanno il **cutaway alla The Sims**: quando un muro sta tra la camera e
  Mochi si dissolve, così dentro casa si vede sempre. Ogni pezzo
  piazzato riceve le sue **collisioni** (StaticBody3D). Strumento
  **✕ Demolisci** dedicato: evidenzia in rosso e abbatte col clic.
  Fantasma verde/rosso, R ruota, F ruota il già piazzato, pop + scintille.
- **Interazioni** (`scenes/interact/Interactions.gd`) — prompt
  contestuale sopra i mobili: **E** per sedersi su sedie, sgabelli e
  panchine, per dormire nel letto e per rialzarsi. Sedendosi Mochi si
  abbassa davvero sul sedile, piega le gambette che restano a penzoloni
  dall'orlo del vestitino e si appoggia allo schienale; nel letto si
  **reclina sul cuscino** a pancia in su, chiude gli occhi, respira
  piano e sogna "z" fluttuanti. Il controller C++ va in pausa durante
  l'interazione.
- **Audio** (`audio/Sfx.gd`, autoload) — tutto sintetizzato in codice,
  zero file esterni: passi sincronizzati col ciclo del passo e **diversi
  per superficie** (fruscio sull'erba, "tok" cavo sul parquet, "tak"
  secco sulla pietra), porta con soffio d'aria + click della maniglia in
  apertura e tonfo + scatto della serratura in chiusura, pop di
  piazzamento con arpeggio, errore morbido, poof, tic, plin, cinguettii
  casuali, vento in loop senza cuciture e una **musichetta carillon**
  (giro I-V-vi-IV) renderizzata in un thread e riprodotta in loop
  perfetto.
- **La foresta** (`scenes/world/CozyWorld.gd`, mappa 120×120) — un bioma
  procedurale a nord del prato: pini e latifoglie su griglia con jitter,
  un **sentiero sterrato serpeggiante** (Catmull-Rom di dischi di terra)
  che porta a una **radura col falò** scoppiettante, felci che
  costeggiano il sentiero, rocce muschiose, tronchi caduti, ceppi,
  funghi rossi e **funghi luminosi** teal, **fasci di luce** tra le
  chiome (svaniscono di notte), nebbiolina alla deriva e foglie d'oro
  che planano. Il sottobosco è dipinto nello shader del terreno con un
  bordo bioma irregolare. **Tutto ottimizzato**: ogni specie è una mesh
  fusa istanziata via MultiMesh (l'intera foresta sta in una manciata di
  draw call, divisa in blocchi est/ovest per il culling), le collisioni
  dei ~200 tronchi vivono in un unico StaticBody3D, le particelle sono
  GPU con AABB delimitati e il terreno resta un singolo piano.
- **Ciclo giorno/notte** (`scenes/world/DayNight.gd`) — il sole
  attraversa il cielo da est a ovest (le ombre girano con lui) e cede il
  posto alla luna; il cielo scivola tra quattro palette con il bagliore
  dell'alba e del tramonto all'orizzonte; di notte si accendono 260
  stelle, arrivano le **lucciole lampeggianti** e pollini e farfalle
  vanno a riposo; i dischi di sole e luna sono nel cielo. Ciclo di 4
  minuti, `set_time()` per saltare a un'ora precisa.
- **Sopravvivenza con conseguenze** — a stamina zero Mochi è **sfinita**:
  correre diventa arrancare (più lento che camminare), le orecchie si
  afflosciano, gli occhi restano a mezz'asta e spunta una goccia di
  sudore, finché la stamina non risale oltre il 35%.
- **Giardinaggio** (`scenes/interact/Garden.gd`) — pianta i semi in
  un'Aiuola, annaffiala (l'acqua viene dalla tua barra: annaffiatoio,
  pioggerella e terra che si scurisce) e a ogni notte i semi crescono di
  un passo: monticelli, germogli, boccioli, **fioritura** — festeggiata
  con petali e campanellini. Mai punitiva: senza acqua l'aiuola aspetta
  e basta. Con E raccogli il mazzolino e ricominci. Stadi e annaffiature
  vivono nel JSON del villaggio.
- **L'Orto** (`Garden.gd` + catalogo) — la variante contadina
  dell'Aiuola: terra squadrata coi solchi e i picchetti. Stessi stadi di
  crescita, ma la cella decide la coltura — **carote** (ciuffi piumati
  con la puntina arancione che spunta), **zucche** (panciute a spicchi
  col picciolo ricurvo) o **bacche** (cespuglietti punteggiati di viola)
  — e il raccolto finisce **nella dispensa** con una festa di colori.
- **I funghi del bosco** — tra gli alberi spuntano funghi rossi da
  raccolta (più grandi dei decorativi): con E si staccano con uno
  sbuffo di terra e **saltellano in un arco** fino al cestino, +1 in
  dispensa. Il bosco ne fa ricrescere sempre altri, altrove: la
  passeggiata ha uno scopo.
- **Il ricettario del camino** (`scenes/interact/Cooking.gd`) — davanti
  a un Camino, E apre il **ricettario**: sette piatti su carta crema
  (tè del prato, zuppa di carote, vellutata di zucca, risotto ai funghi,
  spiedini di bosco, crumble e tè alle bacche), coi requisiti di
  dispensa e i tasti 1-7. Scelto il piatto, il rituale: il **pentolino
  sobbolle davanti al fuoco** col vapore che sale, poi la ciotola (o la
  tazza col manico, per i tè) passa tra le zampine di Mochi, lei **ci
  soffia sopra** a occhi socchiusi… e finalmente **mangia**: tre
  morsetti con le briciole che cadono e il "gnam gnam" sintetizzato.
  Ogni ricetta ricarica le sue barre (la vellutata tutte e tre!), ne
  avanza sempre una **porzione da regalare**, e i residenti giudicano
  il piatto coi gusti del loro DNA — chi ama il calduccio adora i
  piatti caldi, i giardinieri quelli freddi. Dispensa nel JSON.
- **Il calendario** (`DayNight.day`) — ogni mattino conta: al risveglio
  il sipario dice "Buongiorno! · Giorno N", salvato nel JSON del
  villaggio. Il segnale `day_changed` guida posta e giardino.
- **La posta del mattino** (`scenes/interact/Mail.gd`) — a ogni nuovo
  giorno (dormito o vissuto) un amico del bosco lascia una letterina
  nella **Cassetta posta**: scampanellio d'ali, scintille e bandierina
  che si alza. Avvicinandosi lo **sportello si apre da solo** con un
  rimbalzino elastico e la busta col sigillo a cuoricino fa capolino;
  con E si legge la lettera su una card di carta crema — otto mittenti
  (passerotto, riccio, volpe, gufo…), e a volte un **regalino** che
  sboccia dalla cassetta tra le scintille. Dormire diventa un'attesa.
- **Character creation a DNA** (`scenes/npc/ChibiDNA.gd` +
  `ChibiBuilder.gd`) — ogni nuovo villager nasce da un **genoma**
  generato (e serializzato nel JSON: rinasce identico): archetipo
  (gattino, coniglietta, orsetto, volpina, topolino — orecchie e musetti
  dedicati), palette pelo/vestitino, proporzioni (testa, occhi,
  orecchie), bocca (w / sorriso / o), guanciotte, lentiggini, quattro
  code, accessori (fiore, fiocco, sciarpina), un **nome** (Nocciola,
  Miele, Brioche…) e una **personalità**: i pesi della mente, colorati
  dall'archetipo (la coniglietta sogna il giardino, l'orsetto il
  camino) più rumore individuale. I candidati al trasloco sono sempre
  villager nuovi di zecca, fino a 4 residenti.
- **Casa e trasloco** (`scenes/interact/Home.gd` + `scenes/npc/`) — vicino
  a un letto, **H** lo imposta come casa tua (una sola, col cuoricino che
  ci fluttua sopra): al prossimo avvio ti sveglierai lì. Costruisci
  un'altra casa con un letto e un tetto e arriva un **aspirante
  villager con la valigia**: ispeziona la casa, aspetta sull'uscio il
  tuo **benvenuto** (E, fino a tre volte) e poi decide. La sua testa è
  `VillagerMind.gd`: un valutatore **in stile percettrone** — la casa
  ridotta a feature (tetto, pareti, porta, finestra, comfort, giardino,
  calore, accoglienza, bel tempo), pesi diversi per specie (il riccio
  sogna il giardino, il passerotto le finestre), somma pesata →
  sigmoide → decisione. E la mente **si spiega**: ti dice cosa adora e
  cosa le manca («…però un caminetto scalderebbe le zampe»), così sai
  sempre cosa costruire. Ricorda le visite passate (torna meno
  diffidente) e, se dice sì, **si trasferisce**: valigia accanto al
  letto, vive attorno a casa sua, ti saluta coi cuoricini, dorme la
  notte. Tutto persistito nel JSON.
- **Visitatori** (`scenes/npc/`) — di giorno, col sereno, ogni tanto un
  animaletto del bosco viene a trovarti: il **Riccio** (trotterella
  dondolando, nasino che annusa) o il **Passerotto** (saltelli
  parabolici con squash & stretch, ali che battono in aria, avanza solo
  durante il balzo). Entra dal bordo del mondo, **curiosa tra i mobili**
  con un "?" sopra la testa, si riposa **sulla panchina** (il passerotto
  si appollaia sullo schienale, il riccio si accoccola sul sedile con
  cuoricini), poi lascia un **regalino** col fiocco che fluttua e se ne
  torna nel bosco. Con E lo raccogli: cuoricini e un messaggio ("Il
  Riccio ti ha lasciato una bacca lucida!"). Non chiede mai niente.
- **La vita dei residenti** (`Visitors.gd` + `Visitor.gd`) — i villager
  hanno una **routine**: al mattino escono ad annusare aiuole e funghi
  (col "?" e il cuoricino), di giorno si alternano tra passeggiate e
  **panchine** (mai in due sulla stessa), e al tramonto **si ritrovano
  tutti al falò della radura**, seduti in cerchio a guardare il fuoco:
  la radura diventa un luogo. Due vicini si scambiano **nuvolette di
  chiacchiere** (tondi bianchi con simboli e cuoricini — zero testo,
  tanta vita). Dopo il trasloco arrivano i **piccoli desideri** («sogno
  un fungo vicino a casa…», generati dai pesi della mente): esaudirli
  = doppio salto di gioia, cuoricini e una **letterina di
  ringraziamento** nella cassetta il mattino dopo. E i piatti del
  camino **avanzano una porzione regalabile**: ogni villager ha i suoi
  gusti dal DNA (piatti caldi per i freddolosi, freddi per i
  giardinieri) — l'**amicizia** cresce, e al terzo cuore arriva la
  lettera d'amicizia.
  Tutto persistito nel JSON.
- **L'onsen del bosco ♨** (`scenes/world/Onsen.gd`) — oltre la radura
  del falò, una pozza termale VERA: lo **specchio d'acqua** usa lo
  shader dello stagno (il cielo e la lanterna **si riflettono davvero**)
  in palette termale, la corona è di **massi sfaccettati** (sfere
  low-poly coi vertici perturbati e normali di faccia, mai marshmallow),
  sassi bagnati scuri semi-sommersi lungo la linea d'acqua, un filo di
  schiuma, il **cairn di pietre in equilibrio**, il **deck di legno**
  d'ingresso col secchiello e gli asciugamanini, ghiaia scura, muschio
  e felci tutt'attorno. Il **vapore** sale in colonne morbide e una
  **nebbiolina bassa scivola sul pelo dell'acqua**; la **lanterna di
  pietra** (tōrō) accende la sera, e di notte le **lucciole ballano
  sull'acqua**. Con E sul bordo Mochi **si immerge
  fino al musetto** — posa dedicata: occhi socchiusi beati, guanciotte
  rosse al massimo, dondolio d'acqua — e la stamina risale veloce
  (l'acqua calda disseta pure), coi cuoricini che salgono col vapore.
  E ogni tanto **un residente arriva in accappatoio** con
  l'asciugamanino piegato in testa, scivola in acqua accanto a te e
  **sospira in Chibiese**: il bagno condiviso scalda l'amicizia (+1).
  Chi è a mollo non viene mandato a nanna a metà bagno: finisce con
  calma, poi va a dormire.
- **Il guardaroba di Mochi** (`scenes/characters/Wardrobe.gd`) — ogni
  capo è un **ricordo indossabile**: si sblocca vivendo, non comprando.
  Il **cappello di petali** con la prima fioritura del giardino, la
  **lanterna-lucciola da polso** (si accende da sola col buio) con la
  prima lucciola in collezione, la **sciarpina di lana** coi regali del
  passerotto, l'**impermeabilino giallo** con la prima pioggia — e
  indossarlo sotto la pioggia la rende felice: scintille dorate ai
  piedi. **G** apre il guardaroba (1-4 indossa/togli, un capo per
  slot); i capi si agganciano a testa, polso e corpo e seguono ogni
  animazione. I residenti vicini si voltano e commentano il vestito
  nuovo in Chibiese («wa-wi!») coi cuoricini. Persistito nel JSON.
- **Le costellazioni di Mochi** (`scenes/world/Stargazing.gd`) — di
  notte, E sull'erba libera: Mochi **si sdraia a pancia in su** e la
  camera sale piano verso la cupola. Le 260 stelle si uniscono come un
  puntini-da-collegare (clic per unire, destro per annullare), dai un
  nome alla tua costellazione e da quella notte **esiste per sempre**:
  linee sottili che si accendono al crepuscolo, il nome dorato sospeso
  tra le stelle, l'evento inciso negli anelli del Grande Albero. E ogni
  tanto una **stella cadente** attraversa il cielo: SPAZIO per
  esprimere un desiderio… e qualche mattina dopo, nella posta, una
  lettera con un regalino. Tutto persistito nel JSON.
- **Il calendario del villaggio** (`scenes/world/Calendar.gd` +
  la **Lavagna** nel catalogo) — ogni nuovo abitante, sistemata la
  valigia, **va alla lavagna e scrive il suo compleanno col gessetto**
  (animazione di scrittura, righe che appaiono sulla lavagna). Con E
  davanti alla lavagna: gli eventi in arrivo in bella copia —
  compleanni, il compleanno del villaggio, l'arrivo del **mercante**.
  Il giorno giusto il festeggiato gira col **cappellino a cono**: se
  gli regali un piatto del camino scatta la **FESTA A SORPRESA** —
  coriandoli, tutto il villaggio che accorre a ballare, amicizia
  che vola, l'evento negli anelli e la lettera di ringraziamento.
  E ogni ~6 giorni (annunciato il giorno prima) arriva il mercante
  col **carretto a strisce**: baratta un piatto caldo del camino con
  un sacchetto di ingredienti rari per la dispensa.
- **Il timelapse dei ricordi** (`scenes/world/Memories.gd`) — ogni
  mattina, poco dopo il "Buongiorno", il gioco scatta UNA foto del
  villaggio dalla **stessa identica inquadratura** — senza mai
  interrompere il gioco: un SubViewport dedicato che condivide il mondo
  renderizza un solo frame e lo salva in `user://ricordi/`. Ai piedi
  del Grande Albero, **R accende il proiettore**: il film del tuo
  villaggio che nasce, giorno per giorno, foto in dissolvenza su
  cornice di carta crema col contatore dei giorni — e chiude con
  "…e la storia continua".
- **Co-op sul divano** (`scenes/characters/Coop.gd`) — **F2** e accanto
  a Mochi sboccia un secondo chibi per chi ti siede accanto: generato
  dal DNA la prima volta e **poi sempre lui** (l'identità dell'amico
  del divano è salvata nel villaggio). Si muove con **IJKL** (fisica
  vera: gravità, scale, solai), parla Chibiese («ya-ho, mi-ka!» quando
  arriva), scodinzola, e con **U aiuta davvero in giardino**: pianta,
  annaffia (gratis — gli ospiti non consumano la borraccia di Mochi) e
  raccoglie nella stessa dispensa. Se si allontana troppo dallo schermo
  condiviso torna con uno sbuffo accanto a te. Costruire in due lo
  stesso giardino, appunto.
- **Il Grande Albero** (`scenes/world/GrandTree.gd`) — il monumento al
  centro del prato, un bonsai condiviso: **cresce di giorno in giorno**
  col calendario del villaggio, da alberello a gigante in un mese (curva
  dolce, `day^0.62`), e all'alba di ogni nuovo giorno si stira di un
  anello con un tween elastico e le scintille dorate. Sul tronco il
  gioco **incide gli eventi**: gli arrivi (♥), le fioriture (✿), i
  compleanni settimanali del villaggio e le case sull'albero (★), le
  prime volte della collezione (♦) — i segni salgono a spirale con la
  vita del villaggio. Con E ai piedi dell'albero si leggono **gli
  anelli**: la cronaca su carta crema, "Giorno 5 · ♥ Nocciola si è
  trasferita". Dal ramo basso pende un'**altalena di corda** che
  ondeggia nella brezza. Cronaca persistita nel JSON.
- **L'ecosistema vero** (`src/ecosystem_manager.cpp` +
  `scenes/world/Ecosystem.gd`) — farfalle e lucciole non sono più
  particelle: sono **popolazioni simulate in C++** (GDExtension) con
  capacità portante e rendering MultiMesh a costo fisso. Le farfalle
  scelgono un fiore, lo raggiungono, ci sorseggiano sopra e
  **impollinano**: dove impollinano nascono **fiori selvatici** (che
  germogliano, crescono e ondeggiano nella brezza — specie e maturità
  per istanza); più fiori alzano la capacità portante e attirano altre
  farfalle. Le **lucciole depongono le uova vicino all'acqua** dello
  stagno di notte; le uova si schiudono dopo due giorni. Semina e
  raccolto **spargono semi** attorno alle aiuole: o li becchi... o li
  beccano i **passerotti** che calano dal cielo, oppure germogliano in
  fiori selvatici. Ogni giorno un po' di mortalità tiene l'equilibrio.
  Il prato risponde davvero a come giochi: due giocatori dopo un mese
  hanno due ecosistemi diversi — e tutto (fiori, uova, semi,
  popolazioni) vive nel JSON del villaggio. L'arte resta in GDScript
  (mesh procedurali + shader: battito d'ali nel vertex shader, bagliore
  additivo con fase per lucciola, corolle tinte per istanza).
- **La verticalità** (`BuildSystem.gd` + catalogo) — il secondo piano
  che i giocatori di AC sognano da vent'anni: in modalità costruzione
  **V** alterna il piano (la griglia sale a quota solaio). La **Scala**
  è ripida ma vera: Mochi la sale in pura fisica (rampa + gravità del
  controller C++). Il **Solaio** è il pavimento di sopra (vuole un
  appoggio: un muro sotto, un solaio vicino o una scala accanto), il
  **Ponticello di corda** ondeggia tra le piattaforme, e sopra ci vanno
  muri, finestre, tetti e mobili. Le dissolvenze sono a tre strati: i
  muri fanno cutaway, i tetti svaniscono quando sei coperto, e l'intero
  piano di sopra si dissolve quando cammini al piano terra — la casa in
  sezione, come una casa di bambola. Salvataggio con le chiavi estese
  al piano (`up_cells`/`up_edges`), retrocompatibile.
- **La casa sull'albero** — il premio finale: un pezzo unico con
  tronco, chioma, piattaforma con ringhiera, casetta con la finestrella
  accesa, scala a pioli percorribile e la **lanterna che dondola** nel
  vento con la sua luce calda. E quando sali e ti fermi lassù, ogni
  tanto **un residente si arrampica a trovarti**: su per i pioli a
  saltelli, un «ya-ho!» dal trespolo col cuoricino, un po' di compagnia
  guardando il tramonto, e poi giù. La verticalità è anche questo.
- **Il Chibiese** (`audio/Chibiese.gd`) — la lingua parlata dei
  villager, sintetizzata dal DNA. Il timbro nasce dall'archetipo
  (l'orsetto brontola grave e ruvido, la topolina squittisce), l'altezza
  dalla taglia, la cadenza dal seed: ogni residente ha una voce sua,
  riconoscibile a orecchio. Le sillabe sono **grani di formante** (un
  impulso glottale che fa risuonare F1/F2 a ogni periodo del pitch) con
  vibrato, respiro e prosodia per stato d'animo (neutro, felice,
  domanda, triste). E il vocabolario: **quindici parole fisse**, le
  stesse sillabe per tutti — «ta-ki» è grazie, «ni-nu» la pioggia,
  «po-mo» la casa — così col tempo il giocatore impara davvero a
  capirli, senza una riga di testo. Parlano nei momenti giusti: il
  saluto («ya-ho!»), il grazie per un piatto, il commento alla prima
  goccia di pioggia, il buongiorno al sole, il desiderio sussurrato
  quando passi vicino, il «ha! po-mo!» di chi accetta il trasloco. Al
  falò le chiacchiere hanno un **tema**: la parola detta a voce e il
  simbolo nella nuvoletta sono la stessa cosa — la lingua si impara
  per affetto. Voci spaziali (AudioStreamPlayer3D), frasi renderizzate
  al volo e messe in cache.
- **Retino e collezione** (`scenes/interact/Collection.gd`) — di giorno
  acchiappi le **farfalle** del prato (rosa, azzurre, gialle), di notte
  le **lucciole** vere che si accendono vicino a te: E fa apparire il
  retino nella zampa di Mochi con una sventagliata elastica e uno
  swoosh sintetizzato, la creaturina scivola nel retino tra le
  scintille. Mai un fallimento, il prato si ripopola da solo. La
  collezione va **in mostra in cima a ogni Libreria** (ricostruita col
  fronte aperto e i libri a vista): barattoli col sughero, farfalle
  dietro il vetro, la lucciola che brilla, e i contatori. Persistita
  nel JSON.
- **Il calendario delle specie** (`scenes/world/Critters.gd`) — il
  bestiario è cresciuto a **22 specie collezionabili** e ognuna sa
  QUANDO esiste (`cond`: stagione, ora, meteo): la **farfalla di
  ciliegio** vola in primavera tra i petali del ciliegio, il **girino**
  nuota solo in primavera, d'estate la **cicala** canta sugli alberi del
  bosco, lo **scarabeo dorato** luccica nell'erba di notte e la
  **lucciola regale** (grande, d'oro caldo) appare tra le lucciole;
  d'autunno la **falena della luna** vola di notte, la **carpa foglia
  d'oro** abbocca e nel bosco spunta il **porcino** (che il mercante
  paga bene); d'inverno c'è il **pesce ghiaccio** e — rarissima, solo
  mentre la neve scende fitta — la **farfalla di neve**. La **libellula
  ambrata** e il **pesce dell'alba** escono solo al crepuscolo, e con
  la pioggia arrivano la **lumachina** e la **rana blu** sulla riva
  dello stagno. E quando la mattina d'autunno fuma di nebbiolina
  (`Weather.is_misty`), aleggia la **farfalla di bruma** e — rara,
  solo sullo stagno velato — la **damigella di velo** cuce l'aria. Nelle Tasche il segnalibro Collezione è diventato
  un'**enciclopedia**: le specie mai viste sono **sagome grigie** con
  un indizio ("solo quando piove", "nelle notti d'autunno") — è la
  scheda vuota a farti uscire col retino. E d'inverno la pioggerella
  diventa una **nevicata fitta**: fiocchi lenti, silenzio, niente
  erba zuppa.
- **Lo stagno e la pesca** (`scenes/interact/Fishing.gd` + CozyWorld) —
  un piccolo specchio d'acqua tra prato e foresta: shader acqua con i
  **riflessi veri del cielo**, luccichii di sole, fresnel e piccole
  onde; sponda sabbiosa, ninfee in fiore che respirano, canne con le
  pannocchie al vento, e **rane che si tuffano** quando ti avvicini,
  con l'anello nell'acqua. La pesca alla AC ma senza fallimenti:
  E lancia (canna con **filo fisico** fino al galleggiante, arco, bloop
  e ripple), i cerchi si stringono, il galleggiante affonda —
  "E — tira!" — e il pesciolino (carpetta dorata, azzurrino o carpa
  rosina) salta fuori roteando tra gli spruzzi. Se non tiri, ribussa.
  I pesci finiscono nei **barattoli-acquario** sulla Libreria, accanto
  alle farfalle. Allontanarsi riavvolge, il tutto persiste nel JSON.
- **I messaggi in bottiglia** (`scenes/interact/Bottiglie.gd`) — ogni
  tanto (mai più di una ogni due giorni) la cascata porta giù una
  **bottiglia col sughero**: scivola a valle con la corrente, dondolando
  tra le ninfee, con un luccichio che si nota dalla riva. Se nessuno la
  ripesca prima della fine del fiume se ne va — un'urgenza gentile:
  un'altra arriverà. Con **E** Mochi si sporge e la ripesca: dentro c'è
  sempre una **lettera da oltre la cascata** (otto mittenti — la lontra
  viaggiatrice, il capitano Gabbiano, nonna Castoro… — mai due volte la
  stessa finché il giro non si chiude) e un dono: noccioline, ingredienti,
  una stellina o la **conchiglia di fiume** per i Tesori. La prima
  bottiglia si incide negli anelli del Grande Albero. Persistito nel JSON.
- **I luccichii del mattino** (`scenes/interact/Scavi.gd`) — ogni giorno
  due o tre punti del prato **scintillano d'oro**: lì sotto c'è qualcosa.
  Con **E** Mochi si accuccia e **scava con le zampine** (tre zampate,
  sbuffi di terra) e il trovamento salta fuori in un arco: un sacchettino
  di noccioline, un ingrediente, la **campanella di coccio** che qualcuno
  perse tanto tempo fa, o — di rado — una stellina. I punti sono
  deterministici nel giorno e rinascono altrove ogni mattina: insieme
  alla posta e alla foto dei ricordi, un motivo in più per cui ogni
  mattina conta.
- **Modalità foto** (`scenes/interact/PhotoMode.gd`) — **P** nasconde
  tutta la UI e libera la camera: WASD per volare, mouse per guardare,
  Q/E giù/su, rotella per lo zoom, e **clic per scattare**: flash,
  click e la foto è salvata in `user://photos`. Il mondo continua a
  vivere davanti all'obiettivo. P o Esc per tornare.
- **Meteo gentile** (`scenes/world/Weather.gd`) — ogni tanto una
  pioggerella, mai un temporale: il cielo si ammorbidisce in
  grigio-lavanda, gocce sottili seguono Mochi (e **si fermano sui
  tetti**: dentro casa non piove e il suono diventa ovattato), anellini
  di splash sull'erba, il prato **si scurisce e prende un velo lucido**
  (uniform `wetness` nello shader), i passi sull'erba diventano
  **splash acquosi**, il suono di pioggia è un loop sintetizzato senza
  cuciture col vento che si alza, e il camino invita: "tè al riparo
  dalla pioggia". Quando smette, se è giorno, un **arcobaleno a 7 bande
  pastello** (mesh procedurale con vertex color, punte che sfumano) si
  distende sul villaggio e svanisce piano.
- **Una sola aria** (`shaders/vento.gdshaderinc`) — l'erba aveva le sue
  folate, il bucato la sua oscillazione, e le chiome degli alberi… niente:
  stavano immobili in mezzo a un mondo che ondeggiava, e si muovevano solo
  quando il taglialegna le colpiva. Ora la folata è **una sola** e viaggia
  sul terreno: quando passa si piega prima l'erba di là, poi la chioma
  dell'albero, poi l'erba di qua — è quel **ritardo** a far sembrare vivo
  il vento. Le chiome si piegano dall'attaccatura al ramo in su (il tronco
  resta piantato), i lobi esterni ballano più del cuore, ogni albero ha la
  sua fase presa dal punto in cui è piantato (due alberi vicini non
  respirano mai all'unisono) e le foglie hanno un fremito d'alta frequenza
  che si accende col pieno della folata. Ogni famiglia di fronde ha il suo
  peso: il ciliegio è una vela, la conifera si piega appena, il cespuglio
  freme e basta. E il vento **segue il cielo**: raffiche quando si copre,
  neve che scende piano, e nella nebbiolina del mattino l'aria si ferma.
- **I vicini mangiano davvero** (`scenes/npc/Pasto.gd`) — il piatto regalato
  non svanisce più a mezz'aria: gliela si **consegna**, e lui la mangia col
  rituale di Mochi visto da fuori. Le zampine salgono ad accogliere la
  ciotola, la testona si sporge sul piatto e le orecchie si drizzano al buon
  odore, ci **soffia** sopra se scotta (occhi socchiusi e sbuffi), poi **tre
  morsetti**: la testona scende nella ciotola che le viene incontro, il corpo
  si schiaccia appena, cadono le **briciole** e il cibo dentro la ciotola
  **cala di un terzo per morso**. Alla fine il sospiro beato, il cuoricino e
  solo allora il grazie in Chibiese — è il boccone a parlare, non l'educazione
  — e la ciotola si inclina per mostrarsi **vuota** prima di sparire. Chi
  adora quel piatto lo mangia con più foga; sul freddo non ci soffia. I tempi
  sono una tabella sola, verificata headless (`tests/cases/test_pasto.gd`), e
  mentre mangia **nessuno lo interrompe**: il corpo è del pasto.
- **Italiano e inglese** (`systems/L10n.gd`) — il gioco parla due lingue,
  e si sceglie in cima alle Impostazioni (o segue quella del sistema).
  L'italiano è la **lingua sorgente**: nel codice le frasi restano quelle
  vere (`L10n.t("Buongiorno!")`), così una traduzione mancante mostra
  l'italiano e mai una sigla. Si traduce **solo ciò che si mostra**: i nomi
  dei pezzi, gli id delle specie e i gradini della scala restano italiani
  nel salvataggio — un villaggio salvato in inglese si riapre in italiano.
  Le tabelle stanno in `locale/en/` (quattro parti: schermate, lettere,
  mondo, vicini) e un test verifica segnaposto, a capo, grafie britanniche
  e glossario. Guida e glossario: [`docs/TRADUZIONE.md`](docs/TRADUZIONE.md).
- **Atmosfera** — cielo procedurale, ACES, SSAO, glow, profondità di
  campo, vignettatura, MSAA 4×, shader "handpaint" con lavaggio
  pittorico per tutti i materiali del mondo.

## Avvio

Apri il progetto con Godot 4.7 e premi Play. La build C++ (già compilata
in `bin/`) si rigenera con `scons` dalla radice del progetto.

### Screenshot di verifica da CLI

```powershell
$env:CHIBI_SHOT = "C:\percorso\output"
godot --path .
```

Salva `cozy_vista.png`, `mochi_walk.png`, `mochi_closeup.png` e
`mochi_builder.png` (con una casetta demo costruita col sistema vero),
poi esce da solo.

## Architettura

```
src/                       gameplay core in C++ (GDExtension)
  player_controller.*      movimento WASD/gamepad + stamina
  survival_component.*     fame / acqua / stamina con segnali per la UI
  grid_manager.*           snap alla griglia (usato dal builder)
audio/Sfx.gd               tutta la colonna sonora, sintetizzata in codice
scenes/
  characters/Mochi.*       la chibi: costruzione + idle + camminata (+ anomalie)
  characters/Player.tscn   PlayerController C++ + Mochi + camera
  world/CozyWorld.gd       erba, fiori, alberi, nuvole, farfalle, particelle
  world/DayNight.gd        ciclo giorno/notte, luna, stelle, lucciole
  build/BuildSystem.gd     modalità costruzione, celle + bordi, collisioni, UI
  build/BuildCatalog.gd    i 22 pezzi d'arredo procedurali
  levels/MainLevel.*       livello, ambiente, wiring, verifica CLI
  ui/HUD.*                 barre sopravvivenza pastello
shaders/
  toon.gdshader            cel-shading di Mochi
  handpaint.gdshader       materiali "dipinti a mano" + vento
  ground.gdshader          prato acquerello
  grid.gdshader            griglia di costruzione
  vignette.gdshader        vignettatura calda
addons/lua-gdextension     scripting Lua (per mod / eventi)
```

## Roadmap

1. **Mochi, la protagonista chibi** *(fatto)*
2. **Camminata animata + mondo cozy + prototipo builder** *(fatto)*
3. **Audio completo, muri sui bordi, 23 arredi, collisioni** *(fatto)*
4. **Porte animate, tetti, demolizione, sedersi/dormire, ciclo giorno/notte** *(fatto)*
5. **Mappa 120×120 + bioma foresta procedurale con sentiero e radura** *(fatto)*
6. Villager NPC con dialoghi; tetti automatici a stanza chiusa
7. *(dormiente)* Il lato horror: `Mochi.anomalies_enabled = true` riattiva
   le anomalie — occhi-voragine, mondo che si spegne. Per quando sarà ora.
