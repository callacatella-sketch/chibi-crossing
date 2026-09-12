extends RefCounted

## LA RILETTURA — la guardia, e non e' un source-check.
##
## Si costruiscono `Animo` VERI con storie vere, si chiama la porta VERA
## (`Animo.regola`), e si guarda cosa succede alla `regolazione`, al
## cortisolo, alle `attese` e ai ricordi. Le mutazioni stanno in
## `tools/muta_rilettura.txt`.

const ANIMO := preload("res://scenes/npc/Animo.gd")
const RIL := preload("res://scenes/npc/Rilettura.gd")
const REGIA := preload("res://scenes/npc/Regia.gd")
const GESTI := preload("res://scenes/npc/Gesti.gd")

const TRATTI_A := {"codardia": 0.15, "grinta": 0.85, "lealta": 0.80,
		"ambizione": 0.20, "orgoglio": 0.25}
const TRATTI_B := {"codardia": 0.85, "grinta": 0.15, "lealta": 0.20,
		"ambizione": 0.80, "orgoglio": 0.75}


func _animo(tratti := TRATTI_A, sogno := "combattere") -> RefCounted:
	var a = ANIMO.new()
	a.setup({"name": "Prova", "tratti": tratti, "sogno": sogno})
	return a


func _gentilezze(a: RefCounted, quante: int, valenza := 0.8) -> void:
	for i in quante:
		a.ricorda("regalo", "giocatore", valenza, 0.9)


func _torti(a: RefCounted, quanti: int, valenza := -0.8) -> void:
	for i in quanti:
		a.ricorda("ignorato", "giocatore", valenza, 0.9)


## Il CODICE di un file, senza i commenti: una guardia che scandaglia un
## sorgente e non li salta finisce per giudicare quello che c'e' scritto
## invece di quello che succede.
func _codice(percorso: String) -> String:
	var out := ""
	for riga in FileAccess.get_file_as_string(percorso).split("\n"):
		var r := str(riga)
		var i := r.find("#")
		if i >= 0:
			r = r.substr(0, i)
		out += r + "\n"
	return out


## Una fotografia di TUTTO lo stato che una rilettura potrebbe toccare.
func _fotografia(a: RefCounted) -> Dictionary:
	var neuro := {}
	for k in a.limbico.neuro:
		neuro[k] = float(a.limbico.neuro[k])
	return {"attese": (a.limbico.attese as Dictionary).duplicate(true),
			"marchi": (a.limbico.marchi as Dictionary).duplicate(true),
			"ricordi": (a.ricordi as Array).duplicate(true),
			"sommario": (a.sommario as Dictionary).duplicate(true),
			"neuro": neuro,
			"regolazione": float(a.limbico.regolazione),
			"arousal": float(a.limbico.arousal),
			"umore": float(a.limbico.umore),
			"morsi": int(a.limbico.morsi_oggi)}


func run(t) -> void:
	_il_modulo_non_tira_dadi(t)
	_non_e_un_tratto(t)
	_solo_la_prova_che_assolve(t)
	_una_gentilezza_sola_non_compra_un_torto_grosso(t)
	_il_torto_minimo_morde(t)
	_rileggere_non_tocca_NIENTE(t)
	_due_domande_due_aggregati(t)
	_chi_rilegge_non_paga_e_chi_si_morde_si(t)
	_non_punisce_chi_e_stato_gentile(t)
	_le_prove_invecchiano(t)
	_senza_prove_il_gioco_e_quello_di_prima(t)
	_la_leva_del_banco_e_DAVVERO_il_gioco_di_prima(t)
	_il_perdono_legge_anche_il_sommario(t)
	_la_porta_legge_il_sommario(t)
	_il_rancore_e_derivato_dal_conto(t)
	_la_frase_e_cablata(t)
	_la_leva_del_banco_non_la_accende_nessuno(t)


# ── 1 ─────────────────────────────────────────────────────────────────────
## «La disponibilita' non va tirata a dadi.» Due controlli: il codice non
## nomina nessun generatore, e cento chiamate identiche danno cento risposte
## identiche.
##
## ⚠️ **SI SALTANO I COMMENTI**: la testata di quel file NOMINA `randf()` per
## dire che non c'e', e la prima stesura di questa riga arrossiva sul proprio
## commento. E' la stessa disciplina di `test_vento`.
func _il_modulo_non_tira_dadi(t) -> void:
	var src := _codice("res://scenes/npc/Rilettura.gd")
	t.ok(not src.contains("randf") and not src.contains("randi")
			and not src.contains("RandomNumber"),
			"la rilettura non tira dadi: nessun generatore nel codice")
	var primo := RIL.rapporto(0.7, 1.0)
	for i in 100:
		t.almost(RIL.rapporto(0.7, 1.0), primo,
				"la stessa storia da' sempre la stessa risposta", 1e-12)


# ── 2 ─────────────────────────────────────────────────────────────────────
## ⚠️ **«E NON DEVE DIVENTARE UN TRATTO».** Tre controlli, e il terzo e'
## l'unico che conta davvero.
##
## La prima stesura di questo caso aveva due TAUTOLOGIE (`f(x) == f(x)`) e
## non asseriva mai la proprieta' del titolo. E il buco che lasciava aperto
## era concreto: il source-check guarda `Rilettura.gd`, ma **il tratto puo'
## entrare al sito di chiamata** — `RILETTURA.scheda(torti, prove * (0.5 +
## tratto("lealta")))` in `Animo.regola` passerebbe il source-check e non
## toccherebbe nessuna delle due tautologie. Perciò si passa da `regola()`.
func _non_e_un_tratto(t) -> void:
	var src := _codice("res://scenes/npc/Rilettura.gd")
	for nome in ["codardia", "grinta", "lealta", "ambizione", "orgoglio"]:
		t.ok(not src.contains('"%s"' % nome),
				"la rilettura non conosce il tratto «%s»" % nome)

	# (a) la funzione pura: gli stessi numeri danno la stessa risposta
	t.eq(RIL.disponibile(1.0, 2.0, 0.5), RIL.disponibile(1.0, 2.0, 0.5),
			"la disponibilita' e' una funzione dei soli numeri")

	# (b) e la PORTA: due caratteri opposti, la stessa identica storia
	var a := _animo(TRATTI_A)
	var b := _animo(TRATTI_B)
	for x in [a, b]:
		_gentilezze(x, 10)
		_torti(x, 3)
	var ra: Dictionary = a.regola("giocatore")
	var rb: Dictionary = b.regola("giocatore")
	t.eq(str(ra["modo"]), str(rb["modo"]),
			"due caratteri OPPOSTI con la stessa storia scelgono lo stesso modo")
	t.eq(str(ra["modo"]), "rilettura", "e con quel passato rileggono")


# ── 3 ─────────────────────────────────────────────────────────────────────
## ⚠️ IL CANCELLO STRUTTURALE. Un mucchio di righe OSTILI deve dare
## **esattamente** la stessa risposta di zero righe: il modulo non sa
## accusare nessuno, e non e' una promessa ma un `maxf(0.0, …)`.
func _solo_la_prova_che_assolve(t) -> void:
	t.almost(RIL.peso_prova(-0.9, 1.0, 1.0), 0.0,
			"una riga ostile pesa ZERO, non poco", 1e-12)
	t.almost(RIL.peso_prova(-0.01, 1.0, 1.0), 0.0,
			"e anche una appena ostile", 1e-12)

	var pulito := _animo()
	_torti(pulito, 3)
	var vuoto := _animo()
	_torti(vuoto, 3)
	for i in 12:
		pulito.ricorda("urlato", "giocatore", -0.9, 1.0)
	var cp: Dictionary = pulito.conto_verso("giocatore")
	var cv: Dictionary = vuoto.conto_verso("giocatore")
	t.almost(float(cp["prove"]), 0.0, "nessuna prova da righe ostili", 1e-9)
	t.almost(float(cv["prove"]), 0.0, "ne' da nessuna riga", 1e-9)
	t.eq(RIL.disponibile(float(cp["torti"]), float(cp["prove"])), false,
			"con dodici torti in piu' non si rilegge di piu'")
	t.almost(RIL.rapporto(float(cp["torti"]), float(cp["prove"])),
			RIL.rapporto(float(cv["torti"]), float(cv["prove"])),
			"le righe ostili non spostano il rapporto di un bit", 1e-12)


# ── 4 ─────────────────────────────────────────────────────────────────────
## Il rapporto, non la quantita' assoluta: un torto grosso vuole
## proporzionalmente piu' passato. E' la riga che impedisce la lavanderia.
##
## ⚠️ E si giudica `scheda()["riletto"]`, che e' quello che il gioco legge —
## non `disponibile()` per conto suo. Le due devono anche COINCIDERE, o una
## delle due sarebbe una funzione che nessuno esegue.
##
## ⚠️ **E LA SPAZZATA FINALE NON ATTRAVERSAVA LA SOGLIA.** Andava da 0,30 a
## 3,60 con `prove = 2.0`, e il rapporto scende sotto `RAPPORTO_MIN` solo
## oltre `prove / RAPPORTO_MIN` = **4,00**: `riletto` era `true` per tutte e
## dodici le iterazioni, quindi `prima` restava `true` e `t.ok(prima or not
## ok, …)` era una **costante vera** — la stessa famiglia del `t.ok(… or
## true)` che questo progetto ha gia' tolto altrove. Adesso il fondo della
## spazzata si RICAVA da `RAPPORTO_MIN` (il doppio del punto di spegnimento),
## cosi' l'intervallo lo attraversa qualunque sia la taratura: un intervallo
## scritto a mano si smura da solo il giorno che qualcuno tocca la costante.
## E si pretende che il passaggio sia AVVENUTO, una volta sola — senza quella
## riga, una monotonia provata su un intervallo muto non si distingue da una
## monotonia provata davvero.
func _una_gentilezza_sola_non_compra_un_torto_grosso(t) -> void:
	t.eq(bool(RIL.scheda(2.0, 0.72)["riletto"]), false,
			"una gentilezza sola non rilegge un torto grosso")
	t.eq(bool(RIL.scheda(1.0, 0.72)["riletto"]), true,
			"ma contro un torto piccolo si")
	for i in 30:
		var torto := 0.2 + 0.3 * float(i)
		for j in 20:
			var prove := 0.1 * float(j) * torto
			t.eq(bool(RIL.scheda(torto, prove)["riletto"]),
					RIL.disponibile(torto, prove),
					"la scheda e la disponibilita' non divergono mai")
	# piu' grosso e' il torto, meno lo si rilegge — e la spazzata arriva al
	# DOPPIO del punto in cui la rilettura si spegne, che non e' un numero
	# scritto qui: e' `prove / RAPPORTO_MIN`, letto dalla costante vera.
	# ⚠️ il pavimento sotto `RAPPORTO_MIN` non e' una taratura: serve perche'
	# una mutazione che la porta a ZERO dia un ROSSO invece di un `fine` a
	# infinito (che produce torti NaN, e un NaN in `rapporto` torna 0.0, cioe'
	# «spenta» — la mutazione passerebbe proprio la riga scritta per lei).
	var prove_fisse := 2.0
	var inizio: float = maxf(0.2, RIL.TORTO_MIN * 2.0)
	var fine: float = prove_fisse / maxf(RIL.RAPPORTO_MIN, 0.01) * 2.0
	t.ok(fine > inizio * 2.0,
			"la spazzata ha spazio per attraversare la soglia (%.2f -> %.2f)"
			% [inizio, fine])
	var prima := true
	var spenta := false
	var cambi := 0
	for k in 41:
		var torto: float = inizio + (fine - inizio) * float(k) / 40.0
		var ok: bool = bool(RIL.scheda(torto, prove_fisse)["riletto"])
		t.ok(prima or not ok,
				"la disponibilita' non torna dopo essere sparita (%.2f)" % torto)
		if prima and not ok:
			cambi += 1
		if not ok:
			spenta = true
		prima = ok
	t.ok(spenta,
			"e dentro la spazzata (fino a %.2f di torto) la rilettura si SPEGNE"
			% fine + ": senza questa riga la monotonia e' una costante vera")
	t.eq(cambi, 1, "e si spegne una volta sola, non a intermittenza")


# ── 5 ─────────────────────────────────────────────────────────────────────
## ⚠️ **`TORTO_MIN` NON ERA SORVEGLIATA DA NIENTE.** Serve a non dividere per
## un denominatore che tende a zero — cioe' a non fabbricare un infinito che
## poi si legge come «rilettura sempre disponibile». Toglierla lasciava tutta
## la suite verde.
##
## ⚠️⚠️ **E LA PRIMA CURA LA GIUDICAVA CONTRO SE' STESSA.** I due campioni
## nascevano dalla costante (`TORTO_MIN * 0.5` e `* 2.0`): mettendo
## `TORTO_MIN := 0.001` si spostavano CON lei e tutte e cinque le asserzioni
## restavano verdi — e nessun altro caso mordeva, perche' tutti lavorano su
## torti veri, un ordine di grandezza sopra. La soglia che esiste «per non
## fabbricare un infinito» si poteva azzerare di fatto.
##
## La cura e' la stessa gia' applicata a `Deriva.FRAZIONE` in
## `test_finestra.gd`: **si ancora a un numero che non e' lei**, e il numero
## sta nella sua stessa testata — «meno di un decimo di un solo ricordo
## brutto». Quel «solo ricordo brutto» non si scrive a mano: si costruisce un
## `Animo` vero, gli si incide UN torto a piena forza, e si MISURA quanto vale
## sulla scala di `conto_verso` (che e' la sola scala su cui `TORTO_MIN` ha un
## significato: vedi la testata di `Rilettura.gd`, «non e' la
## `SOGLIA_SORPRESA` del Limbico anche se il numero e' lo stesso»).
##
## E i due campioni si ricavano dal torto MISURATO, non dalla costante: dentro
## la banda, un quarantesimo sta sempre sotto e un quarto sempre sopra. Con
## `TORTO_MIN := 0.001` diventano rosse **due** asserzioni, non una.
func _il_torto_minimo_morde(t) -> void:
	t.almost(RIL.rapporto(0.0, 5.0), 0.0,
			"senza torto il rapporto e' zero, non infinito", 1e-12)
	t.eq(bool(RIL.scheda(0.0, 5.0)["riletto"]), false,
			"e senza torto non c'e' niente da rileggere")

	# il METRO: un solo ricordo brutto a piena forza, inciso oggi, letto sulla
	# scala vera di `Animo.conto_verso`
	var uno_brutto := _animo()
	uno_brutto.ricorda("ignorato", "giocatore", -1.0, 1.0)
	var cb: Dictionary = uno_brutto.conto_verso("giocatore")
	var pieno: float = float(cb["torti"])
	t.ok(pieno > 0.5,
			"un solo ricordo brutto a piena forza vale %.3f di torto: e' il"
			% pieno + " metro, e se fosse degenere la banda non direbbe niente")
	t.ok(RIL.TORTO_MIN >= pieno / 20.0 and RIL.TORTO_MIN <= pieno / 5.0,
			"TORTO_MIN (%.4f) sta fra un ventesimo e un quinto di un solo"
			% RIL.TORTO_MIN + " ricordo brutto (%.3f): «meno di un decimo»,"
			% pieno + " come dichiara la sua testata")

	var sotto: float = pieno / 40.0
	var sopra: float = pieno / 4.0
	t.almost(RIL.rapporto(sotto, 5.0), 0.0,
			"sotto la soglia (%.4f) il rapporto resta zero" % sotto, 1e-12)
	t.ok(RIL.rapporto(sopra, 5.0) > RIL.RAPPORTO_MIN,
			"e sopra (%.3f) torna un numero vero (%.2f)"
			% [sopra, RIL.rapporto(sopra, 5.0)])
	t.ok(is_finite(RIL.rapporto(1e-12, 5.0)),
			"e non esce mai un infinito")


# ── 7 ─────────────────────────────────────────────────────────────────────
## ⚠️ **RILEGGERE NON TOCCA NIENTE — e non e' una promessa, e' la forma piu'
## forte in cui «una rilettura non cancella il fatto» si possa scrivere.**
##
## La prima stesura rialzava le `attese` verso quella persona. Una revisione
## avversariale ha mostrato che il conto non tornava: la `regolazione`
## risparmiata si rigenera ogni notte, un'attesa alzata sbiadisce di 0,04 al
## giorno; e le chiavi che salivano erano quelle dei COMPITI (le altre erano
## gia' sopra la media), cioe' lo stesso incarico si incideva peggio a chi ti
## aveva portato da mangiare. Adesso non si scrive niente, e questo caso
## fotografa TUTTO quello che si potrebbe toccare.
func _rileggere_non_tocca_NIENTE(t) -> void:
	var a := _animo()
	_gentilezze(a, 10)
	_torti(a, 3)
	var prima := _fotografia(a)
	var r: Dictionary = a.regola("giocatore")
	t.eq(str(r["modo"]), "rilettura", "si rilegge")
	var dopo := _fotografia(a)
	for k in prima:
		t.eq(dopo[k], prima[k],
				"rileggere non tocca «%s»" % k)


# ── 6 ─────────────────────────────────────────────────────────────────────
## ⚠️ **DUE AGGREGATI, E DAL 2026-09-12 UNA DOMANDA SOLA.**
##
## `prove` conta le righe positive VIVE; `prove_totali` anche quelle fuse nel
## SOMMARIO. Fino al merge con `origin/main` li leggevano due funzioni
## diverse; adesso `rancore()` **e** la rilettura leggono tutti e due
## `prove_totali`, e `prove` non ha più nessun lettore in produzione.
##
## Non è una semplificazione: è il risultato di due misure che due sessioni
## avevano preso nello stesso punto in direzioni opposte, e sono vere tutte e
## due.
##
## · SENZA il sommario lo SCUDO DEL GIOCATORE EVAPORA: una storia esattamente
##   in pari dà rancore **0.5566** invece di zero (100 righe per parte), e a
##   pagarlo è chi ha giocato di più ed è stato più generoso.
## · COL sommario il villaggio SI PLACA COL CIBO: un piatto a giorni alterni
##   rendeva il confronto irraggiungibile mentre ogni giorno si ruba la vita
##   a quella persona.
##
## ⚠️⚠️ **E LA RADICE NON È NESSUNA DELLE DUE: IL SOMMARIO NON DECADE.** Una
## riga viva pesa `valenza × intensita × recenza(quando)`; una riga fusa pesa
## `peso × recenza(ultimo)`, dove `peso` è la somma NON scontata di tutte le
## occorrenze — per un comportamento in corso la recenza resta 1 e il peso
## cresce lineare. Con la potatura per schema del sé il tradimento
## d'identità (congruente) resta VIVO e satura, le gentilezze ripetute vanno
## nel SOMMARIO e crescono senza limite: il perdono batte il rancore per
## costruzione. Vedi «IL SOMMARIO NON DECADEVA» in CLAUDE.md.
##
## `prove` resta perché è il CONTRASTO che rende misurabile quanto aggiunge
## il sommario — e perché la porta della rilettura ha una guardia sua
## (`_la_porta_legge_il_sommario`) che senza di lui non saprebbe dire niente.
func _due_domande_due_aggregati(t) -> void:
	var a := _animo()
	for g in 30:
		a.ricorda("piatto", "giocatore", 0.7, 0.8)
		a.ricorda("ignorato", "giocatore", -0.7, 0.8)
		a.passa_giorno()
	var c: Dictionary = a.conto_verso("giocatore")
	t.ok(float(c["prove_totali"]) > float(c["prove"]) + 1e-6,
			"le prove totali contano piu' delle sole vive (%.3f contro %.3f)"
			% [float(c["prove_totali"]), float(c["prove"])])
	# ⚠️ `rancore()` legge il TOTALE: si ricostruisce la sua formula con tutti
	# e due gli aggregati e si pretende che torni quella col sommario. Lo
	# sconto NON e' riscritto qui: si legge da `ANIMO.SCONTO_PERDONO`, o
	# questa asserzione giudicherebbe la funzione contro una sua copia.
	var con_vive: float = 1.0 - exp(-maxf(0.0,
			float(c["torti"]) - float(c["prove"]) * ANIMO.SCONTO_PERDONO)
			/ ANIMO.SATURAZIONE * 3.0)
	var con_tutte: float = 1.0 - exp(-maxf(0.0,
			float(c["torti"]) - float(c["prove_totali"]) * ANIMO.SCONTO_PERDONO)
			/ ANIMO.SATURAZIONE * 3.0)
	t.almost(a.rancore("giocatore"), con_tutte,
			"il rancore legge ANCHE il sommario: senza, lo scudo evapora", 1e-9)
	t.ok(con_tutte < con_vive - 1e-9,
			("e i due numeri sono DIVERSI (%.4f col sommario, %.4f con le sole"
			+ " vive): se coincidessero questa guardia sarebbe muta")
			% [con_tutte, con_vive])
	# la rilettura invece guarda il totale: la sua scheda deve cambiare
	# quando cambia `prove_totali`, non `prove`
	t.eq(bool(RIL.scheda(float(c["torti"]), float(c["prove_totali"]))["riletto"]),
			bool(a.regola("giocatore")["modo"] == "rilettura"),
			"la porta decide col totale, non con le vive")


# ── 7 ─────────────────────────────────────────────────────────────────────
## ⚠️ **LA PREVISIONE FALSIFICABILE DI TUTTO IL LAVORO.** Chi rilegge non
## spende `regolazione` e non alza il cortisolo; chi si morde la lingua fa
## tutti e due. Se un domani questa asserzione diventasse rossa, la
## rilettura sarebbe diventata una seconda soppressione con un altro nome.
func _chi_rilegge_non_paga_e_chi_si_morde_si(t) -> void:
	var legge := _animo()
	_gentilezze(legge, 10)
	_torti(legge, 2)
	var morde := _animo()
	_torti(morde, 2)

	var reg_l: float = legge.limbico.regolazione
	var cort_l: float = legge.limbico.livello_neuro("cortisolo")
	var reg_m: float = morde.limbico.regolazione
	var cort_m: float = morde.limbico.livello_neuro("cortisolo")

	var rl: Dictionary = legge.regola("giocatore")
	var rm: Dictionary = morde.regola("giocatore")

	t.eq(str(rl["modo"]), "rilettura", "con un passato buono si rilegge")
	t.eq(str(rm["modo"]), "morso", "senza, ci si morde la lingua")

	t.almost(legge.limbico.regolazione, reg_l,
			"chi rilegge non spende un grammo di regolazione", 1e-9)
	t.almost(legge.limbico.livello_neuro("cortisolo"), cort_l,
			"e non alza il cortisolo di un millesimo", 1e-9)
	t.ok(morde.limbico.regolazione < reg_m - 0.05,
			"chi si morde la lingua paga (%.3f -> %.3f)"
			% [reg_m, morde.limbico.regolazione])
	t.ok(morde.limbico.livello_neuro("cortisolo") > cort_m + 1e-4,
			"e il corpo resta attivato (%.4f -> %.4f)"
			% [cort_m, morde.limbico.livello_neuro("cortisolo")])


# ── 9 ─────────────────────────────────────────────────────────────────────
## ⚠️ **NON PUNISCE CHI E' STATO GENTILE.** Il torto DOPO una rilettura deve
## sentirsi esattamente come si sarebbe sentito senza: la rilettura non puo'
## avere un costo differito da nessuna parte. E' l'invariante che la
## revisione avversariale ha chiesto, ed e' la ragione per cui il rialzo
## delle attese e' stato tolto.
func _non_punisce_chi_e_stato_gentile(t) -> void:
	var legge := _animo()
	var no := _animo()
	for x in [legge, no]:
		_gentilezze(x, 10)
		_torti(x, 3)
	t.eq(str(legge.regola("giocatore")["modo"]), "rilettura", "uno dei due rilegge")
	# e adesso, lo STESSO identico compito, a tutti e due
	var dopo_l: Dictionary = legge.limbico.rivaluta("taglia_legna", "giocatore",
			-0.6, "", true)
	var dopo_n: Dictionary = no.limbico.rivaluta("taglia_legna", "giocatore",
			-0.6, "", true)
	t.almost(float(dopo_l["sentito"]), float(dopo_n["sentito"]),
			"lo stesso incarico si sente IDENTICO a chi ha riletto", 1e-9)
	t.almost(float(dopo_l["sorpresa"]), float(dopo_n["sorpresa"]),
			"e sorprende identico", 1e-9)


# ── 10 ────────────────────────────────────────────────────────────────────
## ⚠️ **LE PROVE INVECCHIANO, e questo caso e' nato da una mutazione MUTA.**
##
## Togliere la recenza dal peso delle prove lasciava la suite verde, e non
## perche' il test fosse pigro: la recenza moltiplica **anche** i torti,
## quindi un invecchiamento uniforme si semplifica dentro il rapporto. Conta
## solo quando le due cose stanno in tempi DIVERSI — ed e' esattamente la
## scena vera: «sei stato buono con me mesi fa, ma ultimamente no».
func _le_prove_invecchiano(t) -> void:
	# ⚠️ **IL NUMERO E' MISURATO, non scelto.** Con dieci gentilezze contro
	# quattro torti il rapporto scende sotto `RAPPORTO_MIN` fra la
	# trentesima e la quarantesima giornata (2.21 · 0.83 a 20 · 0.57 a 30 ·
	# 0.38 a 40): la prima stesura ne metteva trenta e restava «rilettura» —
	# e l'attesa sbagliata era la mia, non il codice.
	var vecchio := _animo()
	_gentilezze(vecchio, 10)
	for _g in 45:
		vecchio.passa_giorno()
	_torti(vecchio, 4)
	var fresco := _animo()
	for _g in 45:
		fresco.passa_giorno()
	_gentilezze(fresco, 10)
	_torti(fresco, 4)

	var cv: Dictionary = vecchio.conto_verso("giocatore")
	var cf: Dictionary = fresco.conto_verso("giocatore")
	t.ok(float(cv["prove"]) < float(cf["prove"]) * 0.5,
			"le prove di quarantacinque giorni fa pesano meno della meta' "
			+ "(%.3f contro %.3f)" % [float(cv["prove"]), float(cf["prove"])])
	t.ok(RIL.rapporto(float(cv["torti"]), float(cv["prove"]))
			< RIL.rapporto(float(cf["torti"]), float(cf["prove"])),
			"e il rapporto scende col tempo, non resta fermo")
	t.eq(str(vecchio.regola("giocatore")["modo"]), "morso",
			"chi e' stato gentile solo mesi fa non compra una rilettura")
	t.eq(str(fresco.regola("giocatore")["modo"]), "rilettura",
			"chi lo e' stato adesso si")


# ── 11 ────────────────────────────────────────────────────────────────────
## ⚠️ IL DEGRADO VA DOVE VA SEMPRE: senza prove, il gioco e' quello di
## prima, riga per riga.
func _senza_prove_il_gioco_e_quello_di_prima(t) -> void:
	var via_porta := _animo()
	var via_morso := _animo()
	for x in [via_porta, via_morso]:
		_torti(x, 4)
	for i in 3:
		var r: Dictionary = via_porta.regola("giocatore")
		var ok: bool = via_morso.limbico.trattieni()
		t.eq(str(r["modo"]), "morso" if ok else "scoppio",
				"stesso esito del gioco di prima, giro %d" % i)
		t.almost(via_porta.limbico.regolazione, via_morso.limbico.regolazione,
				"stessa regolazione al giro %d" % i, 1e-9)
		t.almost(via_porta.limbico.livello_neuro("cortisolo"),
				via_morso.limbico.livello_neuro("cortisolo"),
				"stesso cortisolo al giro %d" % i, 1e-9)


# ── 12 ────────────────────────────────────────────────────────────────────
## ⚠️ **LA LEVA DEL BANCO VA ESERCITATA, non solo trovata spenta.**
##
## `debug_niente_rilettura` e' il braccio di CONTROLLO di
## `tools/misura_rilettura.gd`: se non facesse davvero il gioco di prima, il
## banco misurerebbe due volte il codice nuovo, riporterebbe «zero
## differenza» e verrebbe creduto. E' la lezione del `MotoreFinto`: un doppio
## che mente e' peggio di nessun doppio.
func _la_leva_del_banco_e_DAVVERO_il_gioco_di_prima(t) -> void:
	var spento := _animo()
	var morso := _animo()
	for x in [spento, morso]:
		_gentilezze(x, 10)
		_torti(x, 3)
	spento.set("debug_niente_rilettura", true)
	# lo stesso animo, senza la leva, rileggerebbe: e' la controprova
	var acceso := _animo()
	_gentilezze(acceso, 10)
	_torti(acceso, 3)
	t.eq(str(acceso.regola("giocatore")["modo"]), "rilettura",
			"con la leva spenta si rilegge")
	for i in 3:
		var r: Dictionary = spento.regola("giocatore")
		var ok: bool = morso.limbico.trattieni()
		t.eq(str(r["modo"]), "morso" if ok else "scoppio",
				"con la leva accesa e' il gioco di prima, giro %d" % i)
		t.almost(spento.limbico.regolazione, morso.limbico.regolazione,
				"stessa regolazione al giro %d" % i, 1e-9)
		t.almost(spento.limbico.livello_neuro("cortisolo"),
				morso.limbico.livello_neuro("cortisolo"),
				"stesso cortisolo al giro %d" % i, 1e-9)


# ── 13 ────────────────────────────────────────────────────────────────────
## ⚠️ **IL SOMMARIO CONTA PER LA RILETTURA E NON PER IL RANCORE.** Con la
## potatura per SCHEMA si sacrificano per prime le righe RIPETUTE — e le
## gentilezze del giocatore sono per definizione le righe ripetute — quindi
## le sole righe vive si appiattiscono: misurato, 0.87 con un piatto a
## settimana e 0.75 con uno al giorno. La rilettura ha bisogno del sommario
## o e' cieca alla generosita'; `rancore()` no, o il villaggio diventa
## placabile col cibo (vedi `_due_domande_due_aggregati`).
func _il_perdono_legge_anche_il_sommario(t) -> void:
	var a := _animo()
	# si riempie oltre il tetto dei ricordi vivi, cosi' la potatura lavora
	for g in 30:
		a.ricorda("piatto", "giocatore", 0.7, 0.8)
		a.ricorda("ignorato", "giocatore", -0.7, 0.8)
		a.passa_giorno()
	t.ok(a.sommario.size() > 0, "il sommario si e' riempito")
	var somma_buona := 0.0
	for k in a.sommario:
		var p: PackedStringArray = str(k).split("|")
		if p.size() >= 2 and p[1] == "giocatore" and float(a.sommario[k]["peso"]) > 0.0:
			somma_buona += float(a.sommario[k]["peso"])
	t.ok(somma_buona > 0.0,
			"e c'e' roba BUONA dentro (%.3f): e' quella che si perdeva" % somma_buona)
	# le prove devono contenere anche quella
	var vive := 0.0
	for r in a.ricordi:
		if r["attore"] == "giocatore" and float(r["valenza"]) > 0.0:
			vive += RIL.peso_prova(float(r["valenza"]), float(r["intensita"]),
					pow(0.5, float(int(a.oggi) - int(r["quando"])) / ANIMO.MEZZA_VITA))
	var c: Dictionary = a.conto_verso("giocatore")
	t.almost(float(c["prove"]), vive,
			"`prove` sono ESATTAMENTE le sole righe vive: e' quello che"
			+ " legge `rancore()`", 1e-9)
	t.ok(float(c["prove_totali"]) > vive + 1e-6,
			"e `prove_totali` valgono di piu' (%.3f contro %.3f): e' quello"
			% [float(c["prove_totali"]), vive] + " che legge la rilettura")


# ── 13 bis ────────────────────────────────────────────────────────────────
## ⚠️ **E LA PORTA DEVE USARLO DAVVERO — questa riga non aveva una guardia.**
##
## Sostituire `prove_totali` con `prove` dentro `Animo.regola` lasciava tutta
## la suite verde: la rilettura diventava CIECA alla generosita' del
## giocatore, cioe' smetteva di leggere la cosa per cui esiste, e nessuna
## asserzione se ne accorgeva.
##
## Perche' nessun caso mordeva, ed e' la stessa forma gia' pagata altrove:
## `_due_domande_due_aggregati` e `_il_perdono_legge_anche_il_sommario`
## asseriscono sui tre numeri di `conto_verso` — che la mutazione non tocca —
## e le loro storie sono troppo corte perche' i due aggregati cadano su due
## LATI DIVERSI della soglia: `disponibile()` risponde la stessa cosa a tutti
## e due, quindi la porta sceglie lo stesso modo comunque e la riga mutata
## non decide piu' niente.
##
## Qui la storia e' quella che la testata di `conto_verso` descrive: quattro
## mesi con un piatto al giorno, poi un mese di indifferenza. Le righe
## RIPETUTE sono le prime che la potatura per schema del se' sacrifica, e le
## gentilezze del giocatore sono per definizione le righe ripetute — quindi
## la memoria VIVA resta piena dei torti recenti e tutta la generosita' sta
## nel sommario. Letto con le sole righe vive quel vicino non ha niente da
## rileggere; letto per intero, ne ha in abbondanza.
##
## ⚠️ **I NUMERI SONO MISURATI, non scelti**, e la storia e' stata cercata
## finche' la soglia non si e' attraversata con margine: torti **5.566**,
## prove vive **0.618** (rapporto 0.111, cioe' meno di un quarto di
## `RAPPORTO_MIN`), prove totali **7.025** (rapporto 1.262, il doppio e
## mezzo). Le storie piu' corte non bastano: con trenta giornate di
## piatto+ignorato i due rapporti valgono 0.705 e 1.010, cioe' stanno dalla
## **stessa parte** della soglia — ed e' esattamente per questo che i casi
## 6 e 13, che quella fixture la usano, non potevano mordere.
##
## FALSIFICATO facendo girare la porta VERA contro un `conto_verso` che
## riproduce la mutazione dal di fuori (`prove_totali := prove`): sano
## `modo=rilettura rapporto=1.2622`, mutato `modo=morso rapporto=0.1110`.
## ⇒ **due asserzioni rosse**, il modo e il rapporto. Le due righe della
## controprova restano verdi, e devono: parlano del libro mastro, non della
## porta — sono quelle che dicono PERCHE' il rosso e' quello giusto.
func _la_porta_legge_il_sommario(t) -> void:
	var a := _animo()
	for g in 120:
		a.ricorda("piatto", "giocatore", 0.7, 0.9)
		a.passa_giorno()
	for g in 30:
		a.ricorda("ignorato", "giocatore", -0.8, 0.9)
		a.passa_giorno()

	var c: Dictionary = a.conto_verso("giocatore")
	var tt: float = float(c["torti"])
	var pv: float = float(c["prove"])
	var pt: float = float(c["prove_totali"])

	# LA CONTROPROVA, e sta PRIMA perche' e' quella che rende il caso non
	# vacuo: i due numeri non sono intercambiabili, e su questa storia stanno
	# su due lati diversi della soglia. Senza queste righe l'asserzione sulla
	# porta resterebbe verde per il motivo sbagliato — sarebbe un caso che
	# passa perche' i due aggregati dicono la stessa cosa, non perche' la
	# porta legge quello giusto.
	t.eq(RIL.disponibile(tt, pv), false,
			"con le sole righe VIVE (%.3f di prove contro %.3f di torto) non"
			% [pv, tt] + " ci sarebbe niente da rileggere")
	t.eq(RIL.disponibile(tt, pt), true,
			"col SOMMARIO (%.3f) si': e' la stessa storia, letta per intero"
			% pt)
	# e il salto non e' un epsilon. Il metro non e' un numero scritto qui:
	# e' `RAPPORTO_MIN`, cioe' la soglia vera — sotto la meta' da una parte e
	# sopra il doppio dall'altra, cosi' la banda regge anche se un domani
	# qualcuno tara la costante.
	t.ok(RIL.rapporto(tt, pv) < RIL.RAPPORTO_MIN * 0.5
			and RIL.rapporto(tt, pt) > RIL.RAPPORTO_MIN * 2.0,
			"e la soglia (%.2f) si attraversa con margine: %.3f con le vive,"
			% [RIL.RAPPORTO_MIN, RIL.rapporto(tt, pv)]
			+ " %.3f col totale" % RIL.rapporto(tt, pt))

	# ⇒ E ADESSO LA PORTA, che e' dove la mutazione vive: asserire sui tre
	# numeri di `conto_verso` non basta, perche' quelli non cambiano — cambia
	# quale dei due la porta prende in mano.
	var r: Dictionary = a.regola("giocatore")
	t.eq(str(r["modo"]), "rilettura",
			"chi e' stato nutrito per mesi RILEGGE, anche se le sue righe"
			+ " vive raccontano soltanto l'ultimo mese")
	t.almost(float(r["rapporto"]), RIL.rapporto(tt, pt),
			"e la scheda che la porta restituisce e' pesata col totale", 1e-9)

	# IL CONTROLLO: lo stesso identico mese di indifferenza, senza i quattro
	# mesi prima. Nessun sommario da leggere, e ci si morde la lingua — cosi'
	# si legge che a fare la differenza e' il passato, non la fixture.
	var solo := _animo()
	for g in 30:
		solo.ricorda("ignorato", "giocatore", -0.8, 0.9)
		solo.passa_giorno()
	var rs: Dictionary = solo.regola("giocatore")
	t.ok(str(rs["modo"]) != "rilettura",
			"lo stesso mese senza quei piatti non si rilegge (%s)"
			% str(rs["modo"]))


# ── 14 ────────────────────────────────────────────────────────────────────
## `rancore()` e `Rilettura` leggono lo STESSO libro mastro. Se qualcuno
## rifacesse le prove per conto suo, i due divergerebbero in silenzio.
func _il_rancore_e_derivato_dal_conto(t) -> void:
	for n in [0, 1, 3, 7, 14]:
		var a := _animo()
		_gentilezze(a, n)
		_torti(a, 4)
		var c: Dictionary = a.conto_verso("giocatore")
		var atteso: float = 1.0 - exp(-maxf(0.0,
				float(c["torti"]) - float(c["prove"]) * 1.4)
				/ ANIMO.SATURAZIONE * 3.0)
		t.almost(a.rancore("giocatore"), atteso,
				"il rancore e' la saturazione del conto (%d gentilezze)" % n,
				1e-9)
	var poco := _animo()
	_gentilezze(poco, 1)
	_torti(poco, 4)
	var tanto := _animo()
	_gentilezze(tanto, 12)
	_torti(tanto, 4)
	t.ok(tanto.rancore("giocatore") < poco.rancore("giocatore"),
			"i ricordi belli scontano ancora il rancore")


# ── 15 ────────────────────────────────────────────────────────────────────
## La frase e' cablata da tutte e due le parti, e il villaggio non scende
## piu' dentro `animo.limbico` per decidere.
func _la_frase_e_cablata(t) -> void:
	t.eq(REGIA.frase_di("ha_riletto"), "rilettura",
			"l'occasione punta alla frase")
	t.ok(GESTI.FRASI.has("rilettura"), "e la frase esiste nel vocabolario")
	t.eq(str((GESTI.FRASI["rilettura"] as Dictionary)["g"]), "rialzo",
			"la rilettura e' il Rialzo")
	t.eq(bool(((GESTI.FRASI["rilettura"] as Dictionary)["d"] as Dictionary)
			.get("buio", false)), true,
			"e chiede il buio, come ogni Rialzo di questo gioco")
	t.ok(REGIA.frasi_coerenti(),
			"ogni occasione della regia punta a una frase che esiste")
	t.ok(REGIA.attesa_di("ha_riletto") < REGIA.attesa_di("si_e_trattenuto"),
			"e aspetta meno del morso, perche' e' piu' rara")

	var src := _codice("res://scenes/npc/Visitors.gd")
	t.ok(not src.contains("limbico.trattieni()"),
			"il villaggio chiede all'Animo, non al Limbico "
			+ "(source-check: la guardia vera e' _senza_prove…)")
	t.ok(src.contains('chiedi_gesto(label, "ha_riletto")'),
			"e chiede l'occasione GIUSTA, non quella del morso")
	# ⚠️ e il referto dei no legge la TABELLA: era `nome == \"sollievo\"`, e
	# ogni rifiuto della rilettura per mancanza di buio veniva contato come
	# «corpo occupato» — la causa sbagliata, nel banco scritto per misurarla
	t.ok(not src.contains('nome == "sollievo"'),
			"il referto dei no non ha un elenco di nomi ricopiato")


# ── 16 ────────────────────────────────────────────────────────────────────
## ⚠️ LA LEVA DEL BANCO NON LA ACCENDE NESSUNO.
func _la_leva_del_banco_non_la_accende_nessuno(t) -> void:
	var a := _animo()
	t.eq(a.debug_niente_rilettura, false,
			"di serie la leva e' spenta: il gioco rilegge")
	var accesa: Array = []
	for cartella: String in ["res://scenes", "res://systems"]:
		_scandaglia(cartella, accesa)
	t.eq(accesa.size(), 0,
			"e nessun file di gioco la accende: %s" % str(accesa))


func _scandaglia(dove: String, fuori: Array) -> void:
	var d := DirAccess.open(dove)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var via := dove + "/" + n
		if d.current_is_dir():
			if not n.begins_with("."):
				_scandaglia(via, fuori)
		elif n.ends_with(".gd"):
			for riga in FileAccess.get_file_as_string(via).split("\n"):
				var r := str(riga)
				var i := r.find("#")
				if i >= 0:
					r = r.substr(0, i)
				if r.contains("debug_niente_rilettura") and r.contains("true"):
					fuori.append(via)
		n = d.get_next()
	d.list_dir_end()
