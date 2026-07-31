# Caccia ai difetti — rapporto del 2026-07-30

Otto cacciatori su lenti indipendenti (collisioni, cablaggio, animazioni,
persistenza, architettura, logica, lingua/UI, test bugiardi), ogni
ritrovamento passato da un verificatore avversariale con l'istruzione di
SMENTIRLO. 28 confermati su 30 esaminati, deduplicati a 23.

**Già corretti in questa passata** (suite verde, 44.147 asserzioni):
A1 A2 A3 A4 A5, B2, C1, E3, F1, F2, più tre difetti trovati ESEGUENDO il
gioco e non elencati qui sotto:

- `FiloRosso.annoda()` riceveva un nodo già liberato dalla coda: i
  parametri sono tipizzati `Node3D` e il motore controlla il tipo PRIMA di
  entrare, quindi la guardia interna non poteva salvare nulla — e la
  richiesta viva rimasta dietro a una morta non si annodava mai più.
- `Visitor` in `r_wander` con `_house` vuoto: la funzione di stato si
  interrompeva a metà e il vicino restava piantato per sempre. `r_wander`
  è il ripiego universale di `Visitors._recita()`.
- L'harness dell'estetista fotografava `residenti[1]` mentre i suoi due
  chibi finivano in coda all'array: stampava «cambiato -> []» da sempre.

**Da fare, in ordine di costo per chi gioca:** B1, B3, D1-D4, E1, E2, E4,
A6, G1, G2.

---

# RIEPILOGO ORDINATO — 23 difetti veri (dai 28 rapporti: 5 erano doppioni)

Doppioni fusi: #5+#15+#19 (Rispondere), #7+#20 (Salone), #6+#21 (Concerto), #14+#24 (Grande Albero). Numerazione nuova, ordinata per costo reale.

---

## GRUPPO A — LA PARENTELA RUNTIME DI CozyWorld (6 difetti, una sola causa)

**La causa, detta una volta.** `Legami`, `Nascite`, `Director`, `SaltoTrota`… non stanno in `MainLevel.tscn`: li crea `CozyWorld._ready()` (CozyWorld.gd:171, :178, :196) **dopo tre `await get_tree().process_frame`**. Chi li cerca in un `call_deferred` del proprio `_ready` (che si svuota a fine frame 0) li trova `null` **per sempre**, e chi conta i livelli come se fosse figlio diretto di MainLevel sbaglia di uno. In entrambi i casi il consumatore è protetto da un `if x:` e il fallimento è **muto**: nessun errore, suite verde. È già successo due volte (Taccuino, Sogni) e la cura esiste già in `PostoDiSempre.gd:293-295` (accessore pigro) e `Sogni.gd:167-180` (`_cabla()` che riprova).

**A1. `Rispondere` non si apre MAI — scenes/interact/Rispondere.gd:80** — *gravità alta, correzione: una riga (+ un accessore)*
`_legami` resta null → `apri()` (riga 195) esce alla guardia `if _aperto or _legami == null: return`. Alla cassetta senza posta Mail.gd:628 mostra **«E — rispondi»** e poi il tasto non fa nulla: l'intero verbo (scelta del vicino, pagina del Filo Rosso, Chibiese, `queue_letter` di ritorno, momento `risposta` che è in `Legami.INTOCCABILI`) è irraggiungibile in partita. Verificato a runtime: `risp._legami = null` mentre il gruppo `legami` è popolato; assegnandolo a mano, `apri()` funziona. Il test tests/cases/test_rispondere.gd:127 è un source-check e resta verde.

**A2. `Nascite`: la lettera del Gufo per la nascita non parte — scenes/world/Nascite.gd:263** — *alta, una riga*
`get_node_or_null("../Mail")` da un figlio di CozyWorld significa `CozyWorld/Mail` → null; il ripiego `get_first_node_in_group("mail")` è morto perché **nessuno popola quel gruppo** (unica occorrenza di `"mail"` in tutto scenes/ è quella riga). Il percorso giusto è `../../Mail`, e lo stesso file lo sa: riga 113 usa `../../Player`. La lettera esiste ed è già tradotta (locale/en/lettere.gd:344) e non arriva mai: la catena `nascita → battesimo → prima_parola` si rompe al primo anello per chi non era davanti allo schermo.

**A3. `Concerto` non annoda il Filo Rosso — scenes/interact/Concerto.gd:85 + Legami.gd:59-105** — *media, un file*
Due guasti indipendenti sulla stessa riga d'arrivo (Concerto.gd:334): (a) `_legami` null; (b) **il tipo `"musica"` non esiste in `Legami.TIPI`**, quindi `momento()` (Legami.gd:179) esce comunque alla prima riga. Riparare uno solo dei due non basta. La serata del concerto non entra in nessuna lettera, in nessun sogno, in nessuna pagina di Rispondere, e non conta in `filo["n"]` («porto con me N momenti»). Nota: Concerto è l'**unico** chiamante che usa un riferimento cablato invece di `call_group("legami", "momento", …)`, la convenzione documentata in Legami.gd:15.

**A4. `Salone` non annoda il momento — scenes/interact/Salone.gd:77** — *media, una riga*
Stesso null; Salone.gd:270 `if _legami and …` fallisce muto. Si perde un momento `regalo` sul filo del cliente. Attenuanti oneste: `regalo` non è esclusivo del salone (Visitors.gd:1821) e `momento()` tiene un momento per tipo al giorno, quindi in alcuni giorni sarebbe stato comunque no-op.

**A5. «E — conosci il cucciolo» sopra il velo nero del sonno — scenes/world/Nascite.gd:311** — *media, una riga*
`get_node_or_null("../Interactions")` → null, quindi la guardia `is_sleeping()` **non si esegue mai** (`has_method()` su null non solleva errore). Il cartellino sta al livello 12, il velo al 10: resta acceso durante la dormita e **dentro il sogno**, che ha come regola prima di non avere parole. Serve solo che un genitore sia entro 2,6 m dal letto. La riga è stata copiata da PhotoMode.gd:44, dove `..` è corretto. Il test tests/cases/test_sogni.gd:269 è un source-check su `is_sleeping` e resta verde.

**A6. `SaltoTrota` posato sulla fonte sbagliata — scenes/world/SaltoTrota.gd:42** — *media, una riga (+ taratura)*
`MATH.river_x(FALL_Z) - 0.55`, ma la cascata la posa `MATH.cliff_x(FALL_Z) - 0.55` (CozyWorld.gd:2339), e per definizione `cliff_x(FALL_Z) = river_x(FALL_Z) + 2.9`. **Misurato: 2,90 m esatti di scarto**, più di mezza larghezza del fiume. Il guizzo esce in acqua liscia, fuori dalla foschia (raggio utile < 0,8 m) e lontano dalle rocce; il tonfo genera un secondo grappolo di increspature scollegato dal primo. L'indizio del bestiario («salta dove la cascata spumeggia») insegna il posto sbagliato. **Attenzione**: tests/cases/test_salto_trota.gd:64 *certifica il valore sbagliato* e diventerà rosso con la correzione; e applicare `cliff_x - 0.55` alla lettera mette la trota sul bordo est con il salto dentro il velo → serve un rientro di ~1,0-1,2 m e la corsa ritarata **guardando il MainLevel vero**.

> Correzione di gruppo (progetto): un solo idioma per tutti — `_cabla()` che riprova, o `call_group("legami", …)` — e una regola scritta: **nessun figlio runtime di CozyWorld cattura riferimenti nel `_ready`**. Più un test comportamentale che monti MainLevel, aspetti il mondo e pretenda i riferimenti valorizzati.

---

## GRUPPO B — DATI CHE SI CORROMPONO O SI PERDONO IN SILENZIO (3)

**B1. La lettera consegnata ma non aperta viene distrutta dal salvataggio — scenes/interact/Mail.gd:244** — *alta, un file*
`_deliver()` fa `pop_front()` **e poi `request_save()`**, ma `save_extra()` (righe 188-195) persiste solo `_letter_queue`: `_current` e `_has_mail` vivono solo in RAM. La busta esce dal disco e non entra da nessuna parte. Al riavvio `_has_mail = false` e non c'è ripescaggio (`_check_delivery` consegna solo al valico del mattino, e `time` riparte da 0.38 perché DayNight persiste solo `day`): la cassetta resta muta per sempre. **Con la lettera muore il regalo** (`_spawn_gift` gira solo dentro `_open_letter`). Colpisce l'addio del congedo con `gift: true` (Congedo.gd:505-514), le lettere-stagione del Gufo, del taccuino, delle Promesse, delle Commissioni. La finestra non è esotica: la consegna scatta anche **al risveglio**, e «dormo e poi chiudo» è il modo normale di finire una sessione.

**B2. Il taccuino conta due volte lo stesso giorno dopo un riavvio — scenes/npc/Taccuino.gd:436 + load_extra:593** — *alta, una riga*
`_rinunce` torna dal JSON grezzo, quindi i giorni sono `float`: **`7 in [7.0]` è FALSO** (verificato headless su questo progetto). Il giorno già timbrato si riaggiunge, `giorni.size()` arriva a `REGOLA_VOLTE = 2` e parte la lettera del Gufo «è la seconda volta… credo sia una regola tua» **nello stesso pomeriggio** — esattamente il caso che il codice dichiara di escludere. È il guasto che CLAUDE.md chiama catastrofico: un'affermazione sul tempo non guadagnata insegna che le lettere sono generiche. Riprodotto sul codice vero: con giorni interi `_detti = {}`; passati per JSON, `[1.0, 1]` e `_detti = {"regola_creatura": 1}`. È **l'ultima istanza rimasta** della trappola già normalizzata in PostoDiSempre.gd:383, Scavi.gd:513, Bottiglie.gd:513.

**B3. La cronaca del Grande Albero salva testo già impaginato o già tradotto — scenes/world/GrandTree.gd:122 e :455** — *alta, un file + 11 chiamanti*
Il contratto è dichiarato a GrandTree.gd:452-455 («salvato in italiano, si traduce solo qui») e rispettato da tre soli chiamanti. Gli altri lo violano in due modi opposti:
- **formattano prima** (chiave mai in tabella, riga italiana per sempre anche in inglese): GrandTree.gd:122, Stargazing.gd:253, Stargazing.gd:596, Rispondere.gd:353;
- **traducono prima** (su disco finisce la lingua del momento, per sempre): Calendar.gd:267, Calendar.gd:812, Collection.gd:730, Visitors.gd:2187, Congedo.gd:525, Nascite.gd:405, Legami.gd:496, Garden.gd:577.

Con `L10n.PREDEFINITA = "en"` il caso «riga italiana in un pannello inglese» è **normale, non limite** — e una di quelle righe è l'anello di chi è partito per il Grande Prato. **Danno collaterale non nel reclamo originale**: `engrave_once` (GrandTree.gd:109-112) deduplica confrontando il testo *tradotto*, quindi un salvataggio nato in una lingua e riaperto nell'altra può incidere due volte lo stesso evento. La cura è quella già esistente per la posta: frase rimandata `{"k": …, "args": […]}` + `L10n.rendi()` al disegno + migrazione gentile per le `String` vecchie + dedup sulla chiave.

---

## GRUPPO C — MECCANICHE CHE GIRANO A VUOTO (1)

**C1. Il sogno salta la notte se il filo estratto ha tutti i momenti già sognati — scenes/interact/Sogni.gd:238** — *media, una riga*
`scegli()` estrae **un** filo e, se `indice_da_sognare` torna -1, fa `return {}` invece di ripescare fra gli altri. Chi è partito pesa 4 contro 1 e il suo filo è **congelato** (non guadagna più momenti): appena è tutto sognato, quella quota di peso diventa notti buttate, mentre i vivi hanno ricordi freschi da salvare. Riprodotto headless: partito esaurito (3 momenti, peso 4) + vicino fresco (2, peso 1) → nessun sogno per tiro 0.0/0.2/0.5/0.8. Basta anche un residente appena arrivato: ha **un solo** momento (`benvenuto`), sognato quello il suo filo è esaurito. Il degrado cresce con la partita, in silenzio, e colpisce proprio la persona per cui il sistema esiste (il commento in DebugHarness.gd:3009 descrive già il sintomo, attribuito lì a un banco sporco). Correzione: scartare in partenza i fili con `indice_da_sognare(momenti) < 0`, accanto al `if momenti.is_empty(): continue` (riga 214).

---

## GRUPPO D — I CORPI ENTRANO DENTRO GLI OGGETTI (4)

**La causa comune dei primi tre.** `Visitor` estende `Node3D` e si muove con `position +=`: **nessuna fisica, nessun evitamento**. `_walk_to` inchioda `position.y = 0.0` e porta il corpo al punto esatto. `do_routine("bench", pos, look, aux)` solleva sulla seduta **solo dentro `if _routine_aux …`** (Visitor.gd:582-589): chiamarla a tre argomenti significa accovacciarsi a terra dentro il mobile — ed è scritto nero su bianco nel commento Visitor.gd:1904-1908. L'unico chiamante corretto del progetto è Visitors.gd:474-475.

**D1. Il pubblico del concerto e il pianista — scenes/interact/Concerto.gd:258 e :188** — *alta, due righe (+ r_bench)*
Il pubblico si conficca nell'alzata di pietra del primo scalino (`_box(..., Vector3(1.02, 0.28, 0.26), ..., Vector3(0, 0.08, -0.06))`, BuildCatalog.gd:3077), tagliato ai fianchi, col cuscino alla vita. Il pianista si accovaccia sull'erba con la Panchetta che lo attraversa (tavola a y 0.28-0.315, BuildCatalog.gd:2929-2933). E `r_bench` **non legge mai `_fire_look`**: nessuno guarda il palco. Aggravante: l'uscita da `r_bench` (Visitor.gd:817) pretende anch'essa l'aux — il pubblico lo libera `_chiudi()`, **il pianista no** e resta piantato fino alla routine del mattino.

**D2. Il cliente del Salone dentro la poltrona — scenes/interact/Salone.gd:250** — *alta, una riga (+ r_bench)*
Si accovaccia sotto la poltrona: il pistone (cilindro y 0.055→0.255, BuildCatalog.gd:1583) gli passa nella pancia, la seduta (y 0.266→0.320) nel petto. Ed è dentro la scatola di collisione del pezzo, quindi il giocatore non può nemmeno avvicinarsi a guardare. Anche qui lo yaw resta quello dell'ultimo passo: **non guarda lo specchio**, malgrado il commento alla riga 249. È la scena per cui il salone esiste, per 14 secondi a cliente.

**D3. A nascondino ci si nasconde DENTRO il masso — scenes/interact/Nascondino.gd:235** — *media, un file*
`voce["spot"]` è la posizione **esatta** della prop (CozyWorld.gd:1352, :1404), senza nessuno scostamento. Il corpo arriva al centro: su un masso grande spunta il collo, su uno piccolo (ammesso a `r.y >= 0.55`, cioè alto ~0.29) il vicino è in piena vista mentre il toast dice «sbuca da dietro il masso». Non è transitorio: `_caccia` lo rimanda allo stesso punto ogni 5-8 s e la fase di conteggio **teletrasporta** i ritardatari sulla prop (riga 96). Il timido è assegnato apposta al posto più lontano: la scena migliore è quella che si vede peggio. Serve che `nascidigli()` esporti **scala e orientamento**, oggi buttati via.

**D4. Il fiume si attraversa a piedi asciutti — scenes/world/CozyWorld.gd:2590** — *alta, un file*
`_build_river_barriers()` campiona ogni 2,4 m e salta il campione con `absf(z - BRIDGE_Z) > 1.8 and absf(z - LOG_Z) > 1.8`: **due campioni saltati per guado = 4,65 m di muro mancante**, contro un camminatoio largo 1,62 m sul ponte e 0,80 m sul tronco. Verificato in scena vera spazzando la capsula del player: quattro corridoi completi da sponda a sponda, a z∈[0.8, 2.0], [4.4, 4.8], [-28.0, -26.8], [-25.2, -24.0]. Il suolo di collisione è **piatto a y=0** (MainLevel.tscn:45, sei vertici) mentre `ground.gdshader:94` scava fino a 1,15 m e l'acqua sta a -0.45: si attraversa **sospesi 45 cm sopra il pelo dell'acqua**. Nessun altro collider chiude (la scogliera è ~10,5 m più a est), nessuna logica lato player. Contraddice il commento che apre la funzione e rende decorativi i due guadi. Correzione: ricavare la finestra di salto dalla larghezza vera del deck (±0.81 / ±0.40) invece che dal 1.8 fisso, o aggiungere i quattro segmenti di raccordo.

---

## GRUPPO E — CANALI DEL RIG SCRITTI MALE (4)

**La causa comune.** `_gait_misura` (Visitor.gd:1085-1122), la rete di sicurezza che gira per **ogni** stato, richiama a riposo solo coda e `arms.z`. Gambe, `_vis.position.y` e **orecchie** non le tocca nessuno: chi scrive un canale in uno stato solo lo lascia fuori posa.

**E1. Il vicino che scrive alla lavagna resta congelato a metà passo — scenes/npc/Visitor.gd:921 (ramo `"write"`)** — *media, una riga*
Il ramo non chiama nessuna `_anim_*`. **Misurato eseguendo** (caso di test temporaneo, poi rimosso): dopo il cammino `leg0.rot.x=0.333, leg0.pos.y=0.202, vis.y=0.025`; dopo 3,4 s di `write` **identici al terzo decimale**. Gamba a 19° in avanti, sollevata 4,2 cm, corpo bloccato, niente respiro — mentre il toast del compleanno invita a guardare. Stesso guasto, peggiore, in `"tk_twirl"/"tk_startle"` (righe 902-905): posa statica che **gira su sé stessa** o scivola indietro di 70 cm per via del tween. (`"dismount"` invece è innocuo: ci si arriva già rilassati.) Correzione: `_anim_idle()` come prima riga del ramo.

**E2. Il pasto rialza le orecchie di un anziano dimenticando `_eta` — scenes/npc/Visitor.gd:1558** — *media, una riga*
`(orecchio as Node3D).rotation.x = -0.28 * sin(avanti * PI)` — assoluto, senza `_eta`. La base dell'anziano è `0.38 * _eta` e la scrivono solo `_gait_chibi`, `_anim_dorme` (col commento che spiega questo identico motivo) e `set_eta`. Al primo frame di «annusa» le orecchie **scattano su di 22°** e ci restano per tutto il pasto (3,7 s) più i 4-8 s di `r_idle`; tornano giù solo al primo passo. È letteralmente l'esempio scritto in CLAUDE.md, nel gesto più tenero del gioco.

**E3. Nel sogno «cercarsi» la rotazione del corpo si ACCUMULA — scenes/interact/Sogni.gd:682** — *media, una riga (+ provino)*
`corpo["nodo"].rotation.y += sin(u*PI) * 0.004` è l'unico `+=` su un canale la cui base non viene riscritta, dentro una funzione chiamata **una volta per frame**. Deriva misurata: 30 fps → 9,6°; 60 → 19,3°; 120 → 38,5°; 144 → 46,2°, e resta per i restanti 4,4 s del sogno. Nessun `max_fps` nel progetto. In un primo piano dove le parole sono vietate, il corpo è l'unico canale che dice **chi** hai sognato: a 120 Hz finisce quasi di profilo. Riscritto in assoluto, 0.004 rad è invisibile (0,23°): **l'ampiezza attuale la produce interamente il framerate** — quella vera va scelta con un provino affiancato.

**E4. La postura «attento» del pubblico non esiste — scenes/interact/Concerto.gd:308** — *bassa, una riga*
`set_meta("postura", "attento")`, ma "attento" non è né in `RECITA` né in `RECITA_TRANS`: `_recita_applica` (Visitor.gd:2616-2626) cade fuori da entrambi i rami e non consuma nemmeno il meta. È l'unico dei 15 `set_meta("postura", …)` del progetto con un nome orfano. Il pubblico è comunque seduto e rivolto al palco (D1 a parte): manca solo lo strato «attento» sopra la posa. Vale la pena aggiungere anche il `push_warning` per i nomi sconosciuti, e un test che scandisca i letterali.

---

## GRUPPO F — LA RETE DELLA LOCALIZZAZIONE HA UN BUCO PRECISO (3)

**La causa comune.** `tests/cases/test_localizzazione.gd:57-67` cerca i **letterali** dentro `L10n.t("…")` e le chiavi `"text_key"/"from_key"/"k"`. Tutto il testo che arriva da una **tabella dati** (`str(d["title"])`, `str(offer.get("desc"))`) è invisibile al guardiano: la suite è verde per costruzione.

**F1. Le due lettere-stagione di Salone e Anfiteatro escono INTERE in italiano — scenes/npc/GufoOrders.gd:68-69** — *alta, un file di tabella*
Verificato a macchina contro le tabelle vere: mancano **esattamente 8 chiavi**, tutte e sole quelle di quelle due righe (`title`, `letter_text` di 7 righe, `hint`, `done_text` ×2); ogni altra riga di `CHAIN`+`DESIDERI` è tradotta. Escono in italiano: il toast-lettera, il banner «Il Gufo sogna: …» per tutta la settimana, la pagina del diario, il toast di completamento **e la busta in posta**. Raggiungibili a giorno 29-35 e 57-63. Nota per chi corregge: l'hint di riga 69 è scritto `l\'artista`; a runtime l'apostrofo è semplice, la chiave inglese va **senza** backslash o non combacia.

**F2. Sei descrizioni del negozio (+ cinque nomi + una variante) in italiano — scenes/ui/Economy.gd:52, 54, 56, 58, 60, 74, 93** — *media, un file di tabella*
Verificato a macchina contro l'unione `ui+mondo+npc+lettere`: mancano le `desc` di Salone, Palco, Fondale, Gradinata, Pianoforte, Sacco; manca la variante `"Miele"`; e — non nel reclamo originale — mancano anche i **nomi mostrati** Salone, Palco, Fondale, Gradinata, Pianoforte (Shop.gd:324). Sono i pezzi da 60 a 420 noccioline: il giocatore inglese decide la spesa di mezza stagione leggendo una riga che non capisce, sia nel carretto (Shop.gd:327) sia nel pannello di costruzione (BuildSystem.gd:1608).

**F3. «I remember di the game of hide-and-seek» — scenes/interact/Rispondere.gd:167** — *media, una riga*
`con_di()` fonde «di» con l'articolo italiano e, non trovandolo, cade su `return "di " + racconto`. Il chiamante (riga 178-180) **traduce prima e fonde dopo**, quindi in inglese si passa sempre da lì. Output reale della funzione, eseguita: `I remember di the first welcome on the doorstep.` Confinato all'anteprima della lettera (Rispondere.gd:415) — la busta spedita usa un'altra chiave — ma è sempre visibile. **Il test certifica il difetto**: tests/cases/test_rispondere.gd:123 pretende `"di the game of hide-and-seek"` e lo chiama «intatta». La fusione è una regola della *lingua*: va fatta solo se `L10n.lingua_corrente() == L10n.SORGENTE`, e vanno corretti i due commenti bugiardi (Rispondere.gd:155-156 e locale/en/ui.gd:51-52).

> Correzione di gruppo: estendere `test_localizzazione` a una passata sulle **tabelle dati** — `GufoOrders.CHAIN/DESIDERI` (`title/letter_text/hint/done_text/celebrate_letter`) e `Economy.SHOP_PIECES[*].name/.desc`, `Economy.VARIANTS[*].label`. Altrimenti il prossimo pezzo nuovo rifà lo stesso buco.

---

## GRUPPO G — TEST CHE MENTONO (2 + 3 già segnalati sopra)

**G1. `test_pasto` legge una proprietà su un nodo già liberato e abortisce — tests/cases/test_pasto.gd:182** — *media, sei righe*
Riga 179 `vapore.free()`, riga 182 `vapore.lifetime`. L'errore risale fino a `run()` (riga 22) e porta via **l'intera `_test_il_filo_col_corpo`, 11 asserzioni**: la guardia che verifica `mangia()`, lo stato `"r_pasto"`, `_pasto_recita` e soprattutto il **recinto** che impedisce alla routine di rubare lo stato a metà pasto (trappola già pagata: il vicino se ne andava a spasso col piatto in mano). Oggi passerebbe 11/11 — è una rete scollegata, non un buco aperto, ma diventa un buco al primo tocco di Visitor.gd fatto in buona fede con la suite verde a fare da conferma. Riprodotto nella suite vera: `exit=0`, `43687 passati`, e dentro il log lo `SCRIPT ERROR`.
**Nello stesso log, stessa firma, non ancora indagato:** `SCRIPT ERROR: Nonexistent function 'senti' in base 'RefCounted (Limbico.gd)' at: _test_guarigione_raggiungibile (tests/cases/test_motori_accesi.gd:83)` — secondo abort silenzioso, da guardare a parte.

**G2. `test_bucato_gesto` verifica un commento — tests/cases/test_bucato_gesto.gd:43** — *bassa, tre righe*
Cerca `"il vecchio istante, senza gesto"`, che in VitaSecondaria.gd vive **solo alla riga 654, dentro un commento**; il codice vero è la 655-656. Rotto in entrambi i versi: verde cancellando il ripiego, rosso riformulando il commento. Passando al setaccio tutti i 173 `_sorgente(...).contains(...)` della suite spogliati dei commenti, **è l'unico caso**. Il gemello `_ritira_con_gesto` → `_stendini_fallback_ritira` (VitaSecondaria.gd:740) è del tutto scoperto.

**Altri tre test che difendono il difetto invece della verità** (già citati sopra, li raccolgo qui perché vanno corretti *insieme* al codice, o la correzione diventa rossa): tests/cases/test_salto_trota.gd:64 (certifica la X sbagliata della trota), tests/cases/test_rispondere.gd:123 (certifica il «di» di troppo) e :127 (source-check sul cablaggio morto), tests/cases/test_sogni.gd:269 (source-check su una guardia che non si esegue mai).

---

# COSA TOCCARE PER PRIMO

**Il Gruppo A, tutto insieme, in una passata sola.** Non perché sia il più vistoso — il fiume attraversabile (D4) si vede di più — ma perché è l'**unica classe che si sta ancora propagando**: sei difetti da una causa, tre già pagati in passato (Taccuino, Sogni, Congedo), e la firma è sempre la stessa — codice scritto, tradotto, testato e **irraggiungibile**, con la suite verde a certificare che va tutto bene. Ogni sistema nuovo che nascerà come figlio di CozyWorld ripeterà l'errore finché non esiste un idioma unico e un test comportamentale che monti MainLevel e pretenda i riferimenti valorizzati. Dentro il gruppo, l'ordine è A1 (una funzione intera irraggiungibile, con il gioco che la *promette* col cartellino «E — rispondi») → A2 → A3/A4 → A5 → A6.

**Subito dopo, e prima di qualsiasi lavoro estetico: B1.** È l'unico difetto dell'elenco che **distrugge dati del giocatore**, colpisce l'addio di chi è partito (col suo ricordino), e la finestra è il modo normale di chiudere una sessione. Poi B2, che è una riga sola e sta rovinando l'unica meccanica che CLAUDE.md dichiara a danno permanente.