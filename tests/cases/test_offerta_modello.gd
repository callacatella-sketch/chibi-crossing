extends RefCounted
## LA SCHERMATA CHE CHIEDE, e chi va a prendere il modello.
##
## Dal 2026-08-13 il modello non viaggia più dentro il pacchetto: si scarica
## al primo uso. Fra il giocatore e due gigabyte e mezzo c'è una sola pagina,
## e questo file la tiene onesta.
##
## ────────────────────────────────────────────────────────────────────────
## CHE COSA SI PUÒ PROVARE, E COME
## ────────────────────────────────────────────────────────────────────────
##
## Non si prova scaricando: in CI non c'è rete, e due gigabyte e mezzo non ci
## sarebbero comunque. Ma **quasi niente di quello che conta è la rete**:
##
##  · il VERDETTO sulla macchina è aritmetica pura (`Capienza`), e si
##    interroga con i numeri veri di tre computer diversi;
##  · le PAGINE si costruiscono davvero e si guarda cosa c'è scritto sopra —
##    non si cercano stringhe in un sorgente, si cercano `Label` in un albero;
##  · lo STATO dello scaricamento si guarda su un `Scarico` VERO a cui si
##    scrivono a mano i numeri che il thread scriverebbe: non è un doppio —
##    è il nodo di produzione, con le sue frasi e i suoi conti, e quello che
##    manca è soltanto il socket. (Il viaggio in sé — i rimbalzi, il `Range`,
##    la rete che cade — ha il suo banco in `test_scarico.gd`: è roba del
##    corriere, non della schermata.)
##
## ⚠️ **QUELLO CHE QUESTO FILE NON PROVA, scritto qui per non dimenticarlo:**
##  1. che il download vero funzioni. Quello è del corriere, non della
##    schermata, e ha il suo banco: `tests/cases/test_scarico.gd` fa
##    camminare la macchina VERA con un tubo finto (che sa cadere a metà,
##    ignorare il `Range`, mandare byte sbagliati) e confronta i byte sul
##    disco uno per uno. Quello che nessuno dei due può provare è la rete
##    vera: si guarda a mano, una volta, e la prova è che il file arriva e
##    l'impronta combacia.
##  2. l'IMPAGINAZIONE. Che le pagine si LEGGANO — che il paragrafo non esca
##    dal pannello, che i due bottoni abbiano davvero la stessa misura, che la
##    casella del consenso non finisca sotto la piega — lo dice
##    `tools/provino_offerta.gd`, che le rende e le fotografa. La prima
##    stesura di questa pagina aveva la casella sotto la piega e questa suite
##    era verde.

const OFFERTA := preload("res://scenes/ui/OffertaModello.gd")
const SCARICO := preload("res://systems/Scarico.gd")
const CAPIENZA := preload("res://systems/Capienza.gd")
const LLM := preload("res://systems/Llm.gd")
const PANNELLO := preload("res://scenes/ui/CozySettingsPanel.gd")

const GB := 1024 * 1024 * 1024

## Una macchina che ce la fa: sedici giga, dodici liberi.
const GRANDE := {"totale": 16 * GB, "libera": 12 * GB, "riserva": GB, "tetto": 3 * GB}


func run(t) -> void:
	_il_verdetto_sulla_macchina(t)
	_come_si_dicono_i_numeri(t)
	_la_pagina_giusta_al_momento_giusto(t)
	_dire_di_no_non_scrive_niente(t)
	_il_consenso_e_un_atto(t)
	_le_due_risposte_hanno_lo_stesso_peso(t)
	_l_avanzamento_dice_i_numeri_veri(t)
	_ogni_guasto_ha_la_sua_frase(t)
	_il_pezzo_si_riprende(t)
	_la_riga_nel_pannello(t)
	_la_casella_apre_davvero_la_pagina(t)
	_i_due_numeri_gemelli(t)


# =========================================================================
# 1. IL VERDETTO SULLA MACCHINA — la domanda che si fa PRIMA
# =========================================================================

## ⚠️ È LA REGOLA PIÙ IMPORTANTE DI TUTTA LA SCHERMATA. Su un computer che
## non ha la memoria per tenere aperto il modello, il villaggio non
## penserebbe comunque: chiedere mezz'ora di rete e due gigabyte e mezzo di
## disco per arrivare a quel niente è il guasto che non si può nemmeno
## diagnosticare, perché chi gioca vede solo un gioco che non fa quello che
## ha promesso.
##
## I numeri non sono inventati: `serve` è `Llm.RAM_MODELLO` (la stima del
## portiere per gemma-3-4b a finestra 2048) e `riserva`/`tetto` sono quelli
## veri del C++ (`LlmLocale.limiti()`, misurati su questo Mac: 1024 e 3072
## MiB). La macchina dell'autore — 8 GiB, 3391 MiB liberi il 2026-08-13 — è
## uno dei casi.
##
## FALSIFICATO, una riga per volta, sulla suite intera (66322 asserzioni
## verdi senza mutazioni): togliendo la riga del totale da `della_memoria`
## **3 rosse** (la macchina piccola diventa «adesso_no», cioè «riprova più
## tardi» detto a chi non potrà mai); togliendo quella della libera **4** (si
## offre il download a chi non lo può aprire adesso); togliendo il tetto
## **2**; facendo cadere «non lo so» dentro «ci sta» **1** (diventerebbe un sì
## per caso invece che per scelta).
func _il_verdetto_sulla_macchina(t) -> void:
	var serve: int = LLM.RAM_MODELLO
	var riserva := GB
	var tetto := 3 * GB

	t.eq(CAPIENZA.della_memoria(16 * GB, 12 * GB, serve, riserva, tetto), "ci_sta",
			"sedici giga con dodici liberi: si può offrire")

	# LA MACCHINA DELL'AUTORE, misurata: 8192 MiB in tutto, 3391 liberi.
	# Servono 2640 + 1024 = 3664: non ci stanno. Ma la macchina è grande
	# abbastanza, quindi la risposta è «adesso», non «mai».
	t.eq(CAPIENZA.della_memoria(8192 * 1024 * 1024, 3391 * 1024 * 1024,
			serve, riserva, tetto), "adesso_no",
			"un Mac da 8 GiB occupato: adesso no, e si può riprovare")
	t.eq(CAPIENZA.della_memoria(8192 * 1024 * 1024, 6 * GB, serve, riserva, tetto),
			"ci_sta", "lo stesso Mac, ma con sei giga liberi: ci sta")

	# LA MACCHINA PICCOLA: non basterebbe nemmeno vuota. Dirle «riprova più
	# tardi» è una presa in giro gentile che costa tempo a chi non ha niente
	# da guadagnarci.
	t.eq(CAPIENZA.della_memoria(3 * GB, 3 * GB, serve, riserva, tetto), "mai",
			"tre giga in tutto: non è una cosa che si aggiusta chiudendo una finestra")

	# ZERO VUOL DIRE «NON LO SO», e «non lo so» non è mai un no: spegnere una
	# funzione per un numero che non abbiamo sarebbe il degrado dalla parte
	# sbagliata (è la regola scritta in `llm_memoria.h`).
	t.eq(CAPIENZA.della_memoria(0, 0, serve, riserva, tetto), "non_lo_so",
			"una piattaforma che non sa rispondere: non lo so")
	t.ok(CAPIENZA.si_puo_offrire("non_lo_so"),
			"e «non lo so» lascia offrire (mai spegnere per un numero che manca)")
	t.ok(CAPIENZA.si_puo_offrire("ci_sta"), "«ci sta» lascia offrire")
	t.ok(not CAPIENZA.si_puo_offrire("adesso_no"), "«adesso no» no")
	t.ok(not CAPIENZA.si_puo_offrire("mai"), "«mai» nemmeno")

	# UN MODELLO CHE SFONDA IL TETTO non si offre a nessuno: è uno sbaglio
	# nostro di scelta del modello, ma chi sta davanti allo schermo non ci può
	# fare niente, quindi la risposta è la stessa.
	t.eq(CAPIENZA.della_memoria(64 * GB, 64 * GB, 5 * GB, riserva, tetto), "mai",
			"sopra il tetto di RAM dell'autore non si offre nemmeno su un mostro")
	t.eq(CAPIENZA.della_memoria(64 * GB, 64 * GB, 5 * GB, riserva, 0), "ci_sta",
			"e senza tetto (0) il tetto non esiste")

	# ⚠️ **IL DISCO NON SI CHIEDE QUI.** Lo guarda `ScaricoMacchina` come
	# primo passo del viaggio, ed è giusto: la memoria si guarda PRIMA di
	# offrire (perché la risposta cambia se si offre o no), il disco si guarda
	# quando si comincia (perché fino ad allora non c'è niente da scrivere, e
	# nel frattempo il disco può essersi liberato).


## ⚠️ **LA STESSA REGOLA DEL CUORE, non una sua approssimazione.**
## `Traduttore::_carica` rifiuta se `serve > tetto` e poi se
## `serve + riserva > libera`. Se un giorno il C++ cambiasse e questo file no,
## il guasto sarebbe muto e nella direzione peggiore: si offrirebbe un
## download che il portiere poi rifiuta, cioè esattamente la cosa che questa
## schermata esiste per non fare. Qui si rifà il conto del C++ a mano e si
## pretende lo stesso verdetto su una griglia di casi.
##
## FALSIFICATO: portando `<` a `<=` dentro `della_memoria` — cioè cambiando
## la regola di un solo byte rispetto a quella del C++ — **2 rosse**. E
## rimettendo `in_giga` in gigabyte decimali (la misura che diverge da quella
## del corriere): **7 rosse**.
func _come_si_dicono_i_numeri(t) -> void:
	var riserva := GB
	var tetto := 3 * GB
	var casi := [[8 * GB, 4 * GB, 2 * GB], [8 * GB, 3 * GB, 2 * GB],
			[16 * GB, 5 * GB, 2600 * 1024 * 1024], [4 * GB, 4 * GB, 2 * GB],
			[32 * GB, 30 * GB, GB]]
	for c in casi:
		var totale: int = c[0]
		var libera: int = c[1]
		var serve: int = c[2]
		var cuore_direbbe := not (serve > tetto or serve + riserva > libera)
		var qui := CAPIENZA.si_puo_offrire(
				CAPIENZA.della_memoria(totale, libera, serve, riserva, tetto))
		t.eq(qui, cuore_direbbe,
				"la schermata e il cuore dicono la stessa cosa (%d/%d/%d)"
						% [totale / GB, libera / GB, serve / GB])

	# E COME SI SCRIVONO. Il peso si dice in gigabyte DECIMALI, come il
	# browser e come la bolletta della linea: dire «2,3 GB» a chi poi vedrà
	# «2,49 GB» nel suo gestore di download vuol dire aver raccontato un file
	# più piccolo di quello che arriva.
	L10n.imposta("it")
	t.eq(CAPIENZA.in_giga(LLM.BYTE_MODELLO), "2,3 GB",
			"il modello si dice «2,3 GB» (2 489 757 856 byte, in gibibyte)")
	# ⚠️ E LE DUE MISURE DEVONO COMBACIARE. La scheda dei fatti («quanto
	# pesa») e la riga sotto la barra («… di …») stanno nella stessa pagina a
	# tre centimetri di distanza, e le scrivono due funzioni diverse: se una
	# contasse in giga da 1000 e l'altra in giga da 1024, il giocatore
	# leggerebbe due pesi diversi per lo stesso file e avrebbe ragione a non
	# fidarsi di nessuno dei due.
	# FALSIFICATO: rimettendo `in_giga` in gigabyte decimali (1 rossa).
	t.eq(CAPIENZA.in_giga(LLM.BYTE_MODELLO), SCARICO.misura_umana(LLM.BYTE_MODELLO),
			"la schermata e il corriere dicono lo stesso peso")
	L10n.imposta("en")
	t.ok(CAPIENZA.in_giga(LLM.BYTE_MODELLO).contains("."),
			"in inglese il separatore è il punto (è presentazione, non dato)")
	t.eq(CAPIENZA.in_giga(LLM.BYTE_MODELLO), SCARICO.misura_umana(LLM.BYTE_MODELLO),
			"e combaciano in tutte e due le lingue")
	L10n.imposta("it")

	# IL TEMPO, detto come lo direbbe una persona. Mai i secondi esatti: una
	# stima al secondo su un download da mezz'ora è una precisione finta che
	# si smentisce da sola a ogni respiro della linea.
	t.eq(str(CAPIENZA.quanto_manca(0, 0.0)["k"]), "ancora un momento",
			"senza velocità non si inventa un numero")
	t.eq(str(CAPIENZA.quanto_manca(1000000, 1000000.0)["k"]), "meno di un minuto",
			"un secondo di roba: meno di un minuto")
	var dieci := CAPIENZA.quanto_manca(600 * 1000000, 1000000.0)
	t.eq(str(dieci["k"]), "circa %d minuti", "dieci minuti si dicono in minuti")
	t.eq(int((dieci["args"] as Array)[0]), 10, "e sono dieci")
	t.eq(str(CAPIENZA.quanto_manca(2489757856, 200000.0)["k"]), "più di %d ore",
			"il modello intero su una linea lenta: ore, e si dice")


# =========================================================================
# 2. LA PAGINA GIUSTA AL MOMENTO GIUSTO
# =========================================================================

## Le sei pagine non si scelgono a mano: le sceglie `riparti()` guardando il
## mondo. Qui il mondo si costruisce (i numeri della macchina, il pezzo sul
## disco, la ricevuta) e si guarda dove va.
##
## FALSIFICATO: togliendo il ramo del verdetto da `riparti()` **7 rosse** (si
## offrirebbe il download a una macchina che non ce la fa — il guasto che la
## regola 1 esiste per non commettere); togliendo il ramo del pezzo **2** (chi
## si era fermato ricomincerebbe da capo).
func _la_pagina_giusta_al_momento_giusto(t) -> void:
	_pulisci()

	var p = _apri(t, GRANDE)
	t.eq(str(p.get("_pagina")), "offerta", "macchina capace, niente pezzo: si chiede")

	var q = _apri(t, {"totale": 16 * GB, "libera": 2 * GB, "riserva": GB, "tetto": 3 * GB})
	t.eq(str(q.get("_pagina")), "macchina", "macchina occupata: non si nomina il download")
	t.eq(str(q.get("_verdetto")), "adesso_no", "e si dice che è adesso, non per sempre")

	var r = _apri(t, {"totale": 2 * GB, "libera": 2 * GB, "riserva": GB, "tetto": 3 * GB})
	t.eq(str(r.get("_verdetto")), "mai", "macchina piccola: e non si dice «riprova»")

	# ⚠️ E LA PAGINA DELLA MACCHINA NON NOMINA IL DOWNLOAD. Non è una
	# sfumatura di tono: nominarlo vorrebbe dire far venire voglia di una cosa
	# che su quel computer non funzionerà.
	for testo in _tutte_le_scritte(r):
		t.ok(not testo.contains("Scaricalo"),
				"la pagina della macchina non offre di scaricare («%s»)" % testo)

	_pulisci()


# =========================================================================
# 3. DIRE DI NO NON SCRIVE NIENTE
# =========================================================================

## ⚠️ **LA REGOLA ZERO DELLA FASE 5, applicata a una schermata.** Il gioco
## deve restare IDENTICO per chi dice di no — e «identico» comincia dal non
## portarsi a casa una preferenza che nessuno ha espresso.
##
## Se accendere la casella scrivesse `llm_spento = false`, chi apre la pagina
## e dice «non adesso» tornerebbe indietro con una casella spuntata sopra un
## villaggio che non pensa: la bugia esatta che questa riga esiste per non
## dire. E se dire di no scrivesse `llm_spento = true`, il giorno in cui
## quella persona si mettesse un `.gguf` in `user://modelli/` da sola il
## villaggio resterebbe muto senza che niente glielo spieghi.
##
## FALSIFICATO: facendo scrivere il bit a `_llm_toggled` quando il modello non
## c'è — cioè al solo gesto di aprire la pagina — **1 rossa**.
func _dire_di_no_non_scrive_niente(t) -> void:
	_pulisci()
	var s: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/Settings")
	if s == null:
		t.ok(false, "l'autoload delle impostazioni c'è")
		return
	var prima: bool = bool(s.get("llm_spento"))
	s.set("llm_spento", true)

	# si apre la pagina, si guarda, si chiude: il mondo non si è mosso.
	var p = _apri(t, GRANDE)
	t.eq(bool(s.get("llm_spento")), true,
			"aprire la pagina non tocca la preferenza di chi gioca")
	t.ok(not FileAccess.file_exists(OFFERTA.RICEVUTA),
			"e non lascia nessuna ricevuta: il consenso si dà premendo, non guardando")
	t.ok(SCARICO.parziale_byte() == 0, "né un pezzo di file")
	p.closed.emit()
	t.eq(bool(s.get("llm_spento")), true, "e dire «non adesso» non scrive niente")

	s.set("llm_spento", prima)
	_pulisci()


# =========================================================================
# 4. IL CONSENSO È UN ATTO
# =========================================================================

## I requisiti stanno in `docs/LICENZA_MODELLO.md` e non sono di gusto:
## scaricando Gemma il giocatore si vincola ai Gemma Terms of Use (preambolo
## dell'accordo: *reproducing*), e nessun altro glieli mostra. Quindi: prima
## del primo byte, i due documenti leggibili lì, la casella **spenta di
## serie**, e l'etichetta che nomina quello che si accetta più la
## dichiarazione di capacità della Sezione 2.1.
##
## FALSIFICATO: facendo nascere la casella spuntata **2 rosse**; togliendo il
## `disabled` iniziale dal bottone di scaricamento **1**.
func _il_consenso_e_un_atto(t) -> void:
	_pulisci()
	L10n.imposta("it")
	var p = _apri(t, GRANDE)

	var caselle: Array = p.find_children("*", "CheckBox", true, false)
	t.eq(caselle.size(), 1, "c'è una casella, e una sola")
	if caselle.is_empty():
		return
	var cb: CheckBox = caselle[0]
	t.eq(cb.button_pressed, false, "spenta di serie: un consenso non si eredita")

	var etichetta := ""
	for testo in _tutte_le_scritte(p):
		if testo.begins_with("Accetto"):
			etichetta = testo
	t.ok(etichetta.contains("Gemma Terms of Use"),
			"l'etichetta nomina i Terms of Use, non un generico «le condizioni»")
	t.ok(etichetta.contains("Prohibited Use Policy"),
			"e nomina anche la Prohibited Use Policy")
	t.ok(etichetta.contains("età"),
			"e porta la dichiarazione della Sezione 2.1 (un gioco cozy lo aprono anche i bambini)")

	# IL BOTTONE SEGUE LA CASELLA, nei due versi.
	var scarica: Button = p.get("_bottone_scarica")
	t.ok(scarica != null and scarica.disabled,
			"prima del consenso non si può scaricare")
	cb.button_pressed = true
	t.ok(not scarica.disabled, "spuntata la casella, il bottone si accende")
	cb.button_pressed = false
	t.ok(scarica.disabled, "e togliendola si rispegne (il consenso si può ritirare)")

	# I DUE DOCUMENTI SI LEGGONO DI LÌ. Non basta che i file esistano: deve
	# esserci il bottone, e deve aprirli.
	var nomi := _tutte_le_scritte(p)
	t.ok(nomi.has("Gemma Terms of Use"), "il documento si apre da qui")
	t.ok(nomi.has("Gemma Prohibited Use Policy"), "e anche l'altro")
	p.call("_apri_documento", "Gemma-Terms-of-Use.txt")
	var lettore := (p.get("_note") as Node).find_children("*", "RichTextLabel", true, false)
	t.ok(not lettore.is_empty() and (lettore[0] as RichTextLabel).text.length() > 2000,
			"e quello che si apre è il testo dell'accordo, per intero")

	_pulisci()


## LE DUE RISPOSTE HANNO LA STESSA MISURA — e non è un vezzo: un «no» piccolo
## accanto a un «sì» grande è la forma grafica dell'insistenza.
##
## E la pagina non insiste **con le parole**: niente esclamativi, niente
## «sblocca», niente elenco di quello che ti perdi.
##
## FALSIFICATO: rimpicciolendo il bottone di rifiuto — 120×40 invece di
## 210×52, cioè l'insistenza fatta con la grafica invece che con le parole —
## **2 rosse**.
func _le_due_risposte_hanno_lo_stesso_peso(t) -> void:
	_pulisci()
	L10n.imposta("it")
	var p = _apri(t, GRANDE)
	var no: Button = null
	var si: Button = null
	for b in p.find_children("*", "Button", true, false):
		if (b as Button).text == "Non adesso":
			no = b
		elif (b as Button).text == "Scaricalo":
			si = b
	t.ok(no != null and si != null, "ci sono tutte e due le risposte")
	if no == null or si == null:
		return
	t.eq(no.custom_minimum_size, si.custom_minimum_size,
			"e hanno la stessa misura")

	for testo in _tutte_le_scritte(p):
		t.ok(not testo.contains("!"), "nessuna frase alza la voce («%s»)" % testo)
		for parola in ["sblocca", "Sblocca", "gratis", "Gratis"]:
			t.ok(not testo.contains(parola),
					"nessuna parola da negozio («%s» in «%s»)" % [parola, testo])

	# E LA FRASE CHE DICE LA VERITÀ: dire di no non toglie niente.
	var rassicura := false
	for testo in _tutte_le_scritte(p):
		if testo.contains("Se dici di no non cambia niente"):
			rassicura = true
	t.ok(rassicura, "e c'è scritto, come un fatto, che dire di no non cambia niente")
	_pulisci()


# =========================================================================
# 5. MENTRE ARRIVA
# =========================================================================

## Lo stato si muove a mano attraverso le funzioni vere. Non c'è nessun
## doppio: `banco_stato` scrive i quattro numeri sotto lo STESSO lucchetto
## che usa il thread, e `avanzamento()` è quella che legge la pagina.
##
## FALSIFICATO: lasciando muta la riga sotto la barra **4 rosse** (una barra
## piena e ferma per dieci secondi, senza una parola, sembra un gioco
## piantato); stimando il tempo anche quando non arrivano byte **1**.
func _l_avanzamento_dice_i_numeri_veri(t) -> void:
	_pulisci()
	L10n.imposta("it")
	var p = _apri(t, GRANDE)
	# UN CORRIERE VERO, con i numeri scritti a mano: quello che manca è il
	# socket, non la macchina. `frase_fase()` è la sua, `fatti()`/`totali()`
	# sono le sue, e la pagina non sa che non c'è nessuna rete dietro.
	var s = SCARICO.new()
	t.stage(s)
	s.set("_fase", ScaricoMacchina.FASE_CORPO)
	s.set("_fatti", 1_244_878_928)
	s.set("_al_secondo", 1_500_000.0)
	p.set("_scarico", s)
	p.call("_vai", "scarico")

	var barra: ProgressBar = p.get("_barra")
	t.ok(barra != null, "c'è la barra")
	t.almost(barra.value, 50.0, "a metà file la barra è a metà", 0.5)
	var riga := str((p.get("_riga_barra") as Label).text)
	t.eq(riga, s.frase_fase(), "la riga sotto la barra è quella del corriere")
	t.ok(riga.contains(" di "), "e dice due numeri: quello fatto e quello totale («%s»)" % riga)
	t.ok(str((p.get("_riga_tempo") as Label).text).contains("minuti"),
			"più quanto manca, detto in minuti")

	var puoi_andare := false
	for testo in _tutte_le_scritte(p):
		if testo.contains("tornare a giocare"):
			puoi_andare = true
	t.ok(puoi_andare, "e la cosa che conta: puoi chiudere e tornare a giocare")

	# ⚠️ IL TEMPO SI DICE SOLO MENTRE ARRIVANO BYTE. Durante il preflight e
	# durante l'impronta non c'è nessun tempo da stimare, e un «circa 14
	# minuti» che resta lì fermo mentre la barra non si muove è una bugia
	# piccola detta nel momento in cui chi guarda è più teso.
	s.set("_fase", ScaricoMacchina.FASE_IMPRONTA)
	s.set("_fatti", LLM.BYTE_MODELLO)
	p.call("_aggiorna_barra")
	t.almost(barra.value, 100.0, "a file intero la barra è piena", 0.01)
	t.eq(str((p.get("_riga_tempo") as Label).text), "",
			"e mentre si controlla l'impronta non si stima nessun tempo")
	t.ok(str((p.get("_riga_barra") as Label).text) != "",
			"ma si dice cosa sta succedendo (una barra piena e muta sembra un gioco piantato)")
	_pulisci()


## OGNI GUASTO HA LA SUA FRASE, e nessuna dà la colpa a chi legge. Sono
## quattro, e le prime tre dicono che cosa ne è stato del pezzo già
## scaricato: è la sola cosa che una persona vuole sapere davanti a un errore.
##
## FALSIFICATO: togliendo la frase del corriere dalla pagina **1 rossa**
## (resterebbero i soli bottoni: «non ha funzionato» senza dire cosa);
## promettendo «Riprendi» dopo un file buttato **26 rosse**.
func _ogni_guasto_ha_la_sua_frase(t) -> void:
	_pulisci()
	L10n.imposta("it")
	var p = _apri(t, GRANDE)
	var viste := {}
	var esiti := [ScaricoMacchina.ESITO_RETE, ScaricoMacchina.ESITO_SPAZIO,
			ScaricoMacchina.ESITO_IMPRONTA, ScaricoMacchina.ESITO_SORGENTE,
			ScaricoMacchina.ESITO_DISCO, ScaricoMacchina.ESITO_CHIUSO]
	for e in esiti:
		p.set("_esito", e)
		p.call("_vai", "guasto")
		var scritte := _tutte_le_scritte(p)
		t.ok(scritte.size() >= 2, "il guasto %d dice qualcosa e offre una via" % e)
		for testo in scritte:
			t.ok(not testo.contains("!"), "e non alza la voce nemmeno quando va storto")
		# LA VIA D'USCITA È DIVERSA A SECONDA DI COSA È RIMASTO SUL DISCO: un
		# «Riprendi» dopo un file buttato prometterebbe una cosa impossibile.
		var bottoni := PackedStringArray()
		for b in p.find_children("*", "Button", true, false):
			bottoni.append(str((b as Button).text))
		viste[e] = ", ".join(bottoni)

	t.ok(str(viste[ScaricoMacchina.ESITO_RETE]).contains(L10n.t("Riprendi")),
			"la rete caduta offre di riprendere (il pezzo è lì)")
	t.ok(str(viste[ScaricoMacchina.ESITO_IMPRONTA]).contains(L10n.t("Ricomincia")),
			"il file rovinato offre di RICOMINCIARE, non di riprendere: non c'è più niente da riprendere")
	t.ok(not str(viste[ScaricoMacchina.ESITO_SORGENTE]).contains(L10n.t("Riprendi")),
			"e quando a monte non c'è, non si promette niente")

	# LA FRASE È QUELLA DEL CORRIERE, non una gemella scritta qui: due
	# tabelle di frasi per lo stesso errore divergono, e divergono proprio
	# dove il gioco deve dire il vero.
	p.set("_esito", ScaricoMacchina.ESITO_RETE)
	p.call("_vai", "guasto")
	t.ok(_tutte_le_scritte(p).has(SCARICO.frase(ScaricoMacchina.ESITO_RETE)),
			"la frase del guasto viene da Scarico.frase(), non da qui")
	_pulisci()


# =========================================================================
# 6. IL VIAGGIO — le parti che si possono interrogare senza rete
# =========================================================================

## IL PEZZO SI RIPRENDE, e la pagina lo dice col numero in mano. Il file di
## prova è **sparso** (si salta in fondo e si scrive un byte): costa zero byte
## veri su APFS e su NTFS, e `byte_del_pezzo` legge comunque la lunghezza —
## che è l'unica cosa che la pagina guarda.
##
## FALSIFICATO: togliendo la condizione sulla ricevuta da `riparti()` **1
## rossa** (un pezzo trovato senza consenso salterebbe la domanda, cioè si
## scaricherebbe senza aver mai mostrato i termini); e non riprendendo affatto
## il pezzo **2**.
func _il_pezzo_si_riprende(t) -> void:
	_pulisci()
	L10n.imposta("it")
	var dove: String = SCARICO.destinazione()
	t.eq(dove, LLM.CARTELLA_MODELLI.path_join(LLM.NOME_MODELLO),
			"il corriere posa il file dove Llm va a cercarlo")
	t.ok(dove.ends_with(".gguf"), "il file finito si chiama come il modello")

	_scrivi_sparso(dove + ".parte", 1_244_878_928)
	t.eq(SCARICO.parziale_byte(), 1_244_878_928, "il pezzo si misura")
	t.eq(LLM.percorso_modello(), "",
			"⚠️ e un pezzo monco NON è un modello: chi cerca i pesi non lo trova")

	# Senza ricevuta: si RIFÀ la domanda. Un pezzo senza consenso vuol dire
	# che qualcuno ha rovistato nella cartella.
	var p = _apri(t, GRANDE)
	t.eq(str(p.get("_pagina")), "offerta",
			"un pezzo senza consenso non salta la domanda")

	# Con la ricevuta: si riprende, e si dice da dove.
	_scrivi(OFFERTA.RICEVUTA, "{}")
	var q = _apri(t, GRANDE)
	t.eq(str(q.get("_pagina")), "pezzo", "con il consenso agli atti, si riprende")
	t.ok("\n".join(_tutte_le_scritte(q)).contains(CAPIENZA.in_giga(1_244_878_928)),
			"e si dice a che punto era")

	# E si può buttare, ricevuta compresa.
	q.call("_butta")
	t.eq(SCARICO.parziale_byte(), 0, "buttato il pezzo, il disco torna com'era")
	t.ok(not FileAccess.file_exists(OFFERTA.RICEVUTA),
			"e va via anche il consenso: chi ricomincerà da zero rifarà la domanda")
	_pulisci()


# =========================================================================
# 7. LA RIGA NEL PANNELLO
# =========================================================================

## ⚠️ **LA RIGA C'È QUANDO IL BINARIO SA SCRIVERE**, non quando i pesi ci
## sono già. È il cambio del 2026-08-13, e senza di lui la funzione sarebbe
## irraggiungibile per chiunque, per sempre, con la suite verde: `Llm`
## `leva_visibile()` è vera solo col file sul disco, e il file arriva solo
## passando da questa riga.
##
## E LA CASELLA MOSTRA `Llm.acceso()`, non il bit salvato: il valore di serie
## di `llm_spento` è `false`, quindi mostrando il bit la casella nascerebbe
## **spuntata** per chiunque non abbia mai scaricato niente — spuntata sopra
## un villaggio che non pensa.
##
## FALSIFICATO: rimettendo `Llm.leva_visibile()` come condizione della riga
## **3 rosse** (sul binario con llama e senza i pesi — cioè la configurazione
## di OGNI giocatore alla prima apertura); mostrando `not llm_spento` invece
## di `acceso()` **2**.
func _la_riga_nel_pannello(t) -> void:
	_pulisci()
	L10n.imposta("it")
	var pan: Control = PANNELLO.new()
	t.stage(pan)
	t.eq(_c_e_la_riga(pan, L10n.t("Il villaggio pensa")), LLM.disponibile(),
			"la riga c'è esattamente quando questo binario sa scrivere")

	if not LLM.disponibile():
		# Sul binario normale (llm=no, quello che gioca la gente) non c'è
		# niente da mostrare, ed è giusto così: la riga non esiste.
		_pulisci()
		return

	var caselle: Array = pan.find_children("*", "CheckButton", true, false)
	var casella: CheckButton = null
	for c in caselle:
		if _riga_di(c) == L10n.t("Il villaggio pensa"):
			casella = c
	t.ok(casella != null, "e la riga ha la sua casella")
	if casella != null:
		t.eq(casella.button_pressed, LLM.acceso(),
				"che mostra se il villaggio pensa DAVVERO, non il bit salvato")
		t.eq(casella.button_pressed, false,
				"senza modello: spenta (una spuntata sopra un villaggio muto è una bugia)")
	_pulisci()


# =========================================================================
# 8. I DUE NUMERI GEMELLI
# =========================================================================

## ⚠️ **QUANTO PESA IL MODELLO È SCRITTO IN DUE POSTI**, e per una ragione:
## `Llm.BYTE_MODELLO` è «cos'è» (lo leggono questa schermata e le Note
## legali, per dirlo a chi gioca) e `Scarico.DIMENSIONE` è «quanto deve
## portare a casa il corriere». Sono due domande diverse con due case
## diverse, ma il numero è uno — e due costanti che dicono lo stesso numero
## divergono in silenzio.
##
## Il guasto sarebbe muto e cattivo: una schermata che promette un peso e un
## download che ne porta un altro, oppure una barra che arriva al 97% e si
## ferma. Finché le due costanti esistono, questa riga le tiene legate.
##
## FALSIFICATO: cambiando una cifra a una delle due **1 rossa**. La strada
## giusta, il giorno che qualcuno rimette mano a questa fase, è farne sparire
## una — e allora questo caso si cancella.
func _i_due_numeri_gemelli(t) -> void:
	t.eq(SCARICO.DIMENSIONE, LLM.BYTE_MODELLO,
			"il peso che la schermata promette è quello che il corriere va a prendere")
	t.eq(SCARICO.destinazione(), LLM.CARTELLA_MODELLI.path_join(LLM.NOME_MODELLO),
			"e il posto in cui lo posa è quello in cui Llm lo cerca")


# =========================================================================
# I FERRI
# =========================================================================

## Apre la pagina con dei numeri di macchina dichiarati. `forza_macchina` si
## scrive PRIMA di entrare nell'albero: `riparti()` gira dentro `_ready`, e
## dei numeri arrivati dopo non se ne accorgerebbe.
func _apri(t, macchina: Dictionary):
	var p = OFFERTA.new()
	p.forza_macchina = macchina
	t.stage(p)
	return p


## Tutte le scritte della pagina, in un array. Si guarda l'ALBERO e non il
## sorgente: un `source-check` che cerca una frase in un `.gd` resta verde
## anche se quella frase non viene mai messa in scena.
func _tutte_le_scritte(radice: Node) -> Array:
	var fuori := []
	for n in radice.find_children("*", "Label", true, false):
		if (n as Label).text != "":
			fuori.append(str((n as Label).text))
	for n in radice.find_children("*", "Button", true, false):
		if (n as Button).text != "":
			fuori.append(str((n as Button).text))
	return fuori


## ⚠️ **L'UNICA PORTA CHE ESISTE, e per un giorno intero non si apriva.**
##
## Tutto quello che c'è sopra in questo file prova la PAGINA: che dica i
## numeri veri, che non insista, che non scriva niente. Nessun caso provava
## la cosa prima — che il gesto del giocatore ce lo PORTI, su quella pagina —
## perché ogni caso si costruisce l'`OffertaModello` per conto suo con
## `_apri()`. E la porta era murata: `_llm_toggled` apriva la pagina e poi
## chiamava `_ricostruisci()`, che a fine frame butta tutti i figli del
## pannello — compresa la pagina appena nata. MISURATO col pannello vero
## (`tools/prova_scelta.gd`): `_offerta` è un `PanelContainer` vivo e
## visibile nel fotogramma del gesto, e `<null>` in quello dopo. Il
## giocatore vedeva la casella tornare da sola al suo posto, e **niente
## altro**: la funzione, il corriere, il consenso, le licenze — tutto
## irraggiungibile, con 66322 asserzioni verdi.
##
## Il caso guarda due cose che sono la stessa cosa detta a due distanze:
## quello che accade ADESSO (la pagina c'è, il pannello si è fatto da parte)
## e quello che accadrà a FINE FRAME (`_rifacimento_in_coda`), che dentro un
## caso di test non si esegue mai e che perciò va guardato da fermo. Poi si
## fa girare il rifacimento a mano, nell'ordine in cui lo farebbe il motore,
## e si controlla che la pagina sia sopravvissuta.
##
## FALSIFICATO su una suite sana da 66327 asserzioni: rimettendo il
## `_ricostruisci()` sul ramo che apre — cioè il codice di prima, quello che
## murava la porta — **2 rosse**; togliendo il `_ricostruisci()` dalla
## chiusura — cioè la casella che resta spuntata sopra un villaggio che non
## pensa — **1 rossa**.
func _la_casella_apre_davvero_la_pagina(t) -> void:
	if not LLM.disponibile():
		return
	_pulisci()
	L10n.imposta("it")
	var pan: Control = PANNELLO.new()
	t.stage(pan)

	var casella: CheckButton = null
	for c in pan.find_children("*", "CheckButton", true, false):
		if _riga_di(c) == L10n.t("Il villaggio pensa"):
			casella = c
	if casella == null:
		t.ok(false, "la casella «Il villaggio pensa» c'è")
		return

	# IL GESTO VERO: si tocca la casella. Non si chiama `_apri_offerta()` —
	# quella è la porta vista da dentro, e da dentro era sempre aperta.
	casella.button_pressed = true
	casella.toggled.emit(true)

	var pagina = pan.get("_offerta")
	t.ok(pagina != null, "toccare la casella porta alla pagina che chiede")
	t.ok(pagina != null and pagina.visible, "e la pagina è visibile")
	t.eq(bool(pan.get("_rifacimento_in_coda")), false,
			"e il pannello NON si è condannato a rifarsi: butterebbe la pagina a fine frame")

	# Adesso si fa a mano quello che il motore farebbe a fine frame, nello
	# stesso ordine. Se qualcuno avesse chiesto un rifacimento, qui la pagina
	# verrebbe condannata — ed è esattamente quello che succedeva.
	#
	# ⚠️ Si guarda `is_queued_for_deletion()`, NON `is_instance_valid()`:
	# `queue_free()` non libera niente sul momento, mette in coda per fine
	# frame. Dentro un caso di test quel momento non arriva mai, quindi
	# `is_instance_valid` resta **vera anche su un nodo appena condannato** e
	# l'asserzione non morde (misurato: con il difetto rimesso, una sola
	# rossa invece di due). La condanna, invece, si vede subito.
	if bool(pan.get("_rifacimento_in_coda")):
		pan._rifai_adesso()
	t.ok(is_instance_valid(pagina) and not pagina.is_queued_for_deletion(),
			"e a fine frame la pagina è ancora viva: il giocatore la può leggere")

	# LA CHIUSURA, invece, IL RIFACIMENTO LO DEVE CHIEDERE: è quello che
	# rimette la casella al suo posto (spenta, perché il villaggio non pensa).
	pan._chiudi_offerta()
	t.eq(bool(pan.get("_rifacimento_in_coda")), true,
			"chiudendo la pagina il pannello si rifà: la casella torna alla verità")
	_pulisci()


func _c_e_la_riga(radice: Node, testo: String) -> bool:
	for n in radice.find_children("*", "Label", true, false):
		if str((n as Label).text) == testo:
			return true
	return false


## L'etichetta accanto a una casella: è la prima `Label` fra i suoi fratelli.
func _riga_di(casella: Node) -> String:
	var padre := casella.get_parent()
	if padre == null:
		return ""
	for f in padre.get_children():
		if f is Label:
			return str((f as Label).text)
	return ""


func _scrivi(dove: String, cosa: String) -> void:
	DirAccess.make_dir_recursive_absolute(dove.get_base_dir())
	var f := FileAccess.open(dove, FileAccess.WRITE)
	if f != null:
		f.store_string(cosa)
		f.close()


func _scrivi_sparso(dove: String, quanti: int) -> void:
	DirAccess.make_dir_recursive_absolute(dove.get_base_dir())
	var f := FileAccess.open(dove, FileAccess.WRITE)
	if f != null:
		f.seek(quanti - 1)
		f.store_8(0)
		f.close()


func _pulisci() -> void:
	for p in [SCARICO.destinazione() + ".parte", OFFERTA.RICEVUTA, SCARICO.destinazione()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
