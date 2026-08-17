extends RefCounted
## IL RITMO DELL'EMOZIONE — il grafo vive sull'entità, e il cuore si rilegge
## A GRADINI (Fase 4, passo 4).
##
## Il motore c'era già: `chibi::valuta` e `chibi::modulatori` sono puri e
## provati (test_occ), e `chibi::punteggi` prende il modulatore da P3. Quel
## che nasce qui è la cosa che li tiene insieme in partita — tre componenti
## su ogni residente, e la decisione di QUANDO rileggerli.
##
## LE QUATTRO COSE CHE QUESTO FILE ESISTE PER TENERE CHIUSE, e nessuna delle
## quattro produrrebbe un errore il giorno che si rompe:
##
##  0. **CHE L'EMOZIONE ARRIVI DAVVERO AL CORPO.** Tutte le altre asserzioni
##     guardano `debug_emozioni`, cioè il modulatore latchato — e un
##     `avanza()` che lo calcolasse diligentemente e poi passasse a
##     `punteggi()` otto 1.0 letterali le lascerebbe TUTTE verdi, con la
##     Fase 4 codice morto in partita. È lo stesso guasto che questo
##     progetto ha già pagato con gli affetti («nessuna coppia poteva
##     formarsi, MAI»: il sistema c'era, girava, aveva i suoi test verdi, e
##     in partita non succedeva niente). Perciò
##     `_l_emozione_inclina_davvero` guarda quel che il registro DECIDE: due
##     vicini identici, uno ha visto Mochi annaffiare, e solo lui va
##     all'aiuola.
##
##  1. **IL GRADINO.** Il cuore si rilegge solo quando il grafo cambia, o
##     ogni `PASSO_EMO` secondi. Misurato: 2 cambi del modulatore in 16,67 s
##     e 997 frame su 999 identici BIT PER BIT; togliendo il gradino, 999
##     cambi e zero frame identici, e il costo per frame di tutto il
##     villaggio ×2,6.
##     ONESTÀ SULLA MOTIVAZIONE, perché il piano ne dava un'altra: il
##     gradino NON serve contro il tremolio. Il «da 0,2 a 922 cambi d'idea al
##     minuto» della Fase 2 riguarda il DADO, non il modulatore — e
##     `_l_emozione_non_fa_tremare` qui sotto misura che col cuore al massimo
##     si passa da 9,20 a 9,60 cambi al minuto, e che togliendo il gradino
##     non cambia. Serve per il costo e per avere un numero che sta fermo
##     mentre lo si usa.
##
##  2. **IL TEMPO DELLA MEMORIA NON È L'ORA DEL GIORNO.** `avanza(delta, ora)`
##     riceve `ora` come FRAZIONE DI GIORNATA (0..1): torna indietro a ogni
##     mezzanotte, e in tutti i banchi di prova resta ferma per minuti
##     («avanza(DT, 0.5)» diecimila volte). Un ricordo timbrato con quella non
##     decadrebbe mai — un grafo eterno con la suite verde, che è il guasto
##     esatto che `peso()` esiste per rendere impossibile. Qui si fa passare
##     mezza vita di gioco a ORA COSTANTE e si pretende che l'interesse si
##     dimezzi.
##
##  3. **LA NEUTRALITÀ RESTA ESATTA.** Un residente che non ha ancora visto
##     niente ha otto modulatori a `1.0` LETTERALE, e il percorso vivo sceglie
##     ancora la stessa azione con lo stesso double dell'oracolo nudo. È su
##     quella esattezza che poggia la prova di equivalenza dell'agenda, e vale
##     per tutto il villaggio all'avvio.

const DT := 1.0 / 60.0


func run(t) -> void:
	# GUARDIA DURA, non molle: se la GDExtension non è caricata questo test
	# deve essere ROSSO. Un `return` silenzioso direbbe «tutto bene» a un
	# villaggio senza cuore.
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	var m = ClassDB.instantiate("EcsMondo")
	if not m.has_method("debug_emozioni"):
		t.ok(false, "EcsMondo non espone «debug_emozioni»: la Fase 4 non è nel binario")
		m.free()
		return
	_api(t, m)
	_i_tre_componenti_nascono_neutri(t, m)
	_il_villaggio_vergine_e_neutro(t, m)
	_l_emozione_inclina_davvero(t, m)
	_il_gradino(t, m)
	_l_emozione_non_fa_tremare(t, m)
	_la_prontezza_regge_col_cuore(t, m)
	_un_ricordo_nuovo_non_aspetta(t, m)
	_il_gusto_riproiettato_non_aspetta(t, m)
	_il_mod_resta_in_scala(t, m)
	_lo_scarto_vivo_non_passa_il_tetto(t, m)
	_il_tempo_della_memoria_non_e_l_ora_del_giorno(t, m)
	_l_orologio_non_torna_indietro(t, m)
	_il_ritmo_si_deriva(t, m)
	_niente_pose(t, m)
	m.free()


# ------------------------------------------------------------------ ferri

## Un residente pronto a decidere: bisogni a metà, corpo libero, dado a zero
## (così il punteggio del registro è il punteggio nudo).
func _abitante(m, indole := [], fatti := []) -> int:
	var id: int = m.registra(PackedStringArray(indole), "")
	m.riferisci_bisogni(id, PackedFloat64Array([0.5, 0.5, 0.5, 0.5, 0.5]))
	m.riferisci_agenda(id, m.maschera_fatti(PackedStringArray(fatti)), true, false)
	var zero := PackedFloat64Array()
	zero.resize(8)
	m.semina_agenda(id, zero)
	return id


func _mod(m, id: int) -> PackedFloat64Array:
	var d: Dictionary = m.debug_emozioni(id)
	return d["mod"]


func _uguali(a: PackedFloat64Array, b: PackedFloat64Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		# `!=` e non `is_equal_approx`: qui «circa» nasconderebbe proprio la
		# classe di errore che si sta cercando (un mod che si muove di un
		# nulla a ogni frame È il tremolio)
		if a[i] != b[i]:
			return false
	return true


# ------------------------------------------------------------------ i casi

func _api(t, m) -> void:
	for nome in ["osserva", "racconta", "riferisci_gusto", "imposta_ritmo",
			"debug_grafo", "debug_emozioni", "debug_ritmo", "debug_grafo_novita"]:
		t.ok(m.has_method(nome), "EcsMondo espone «%s» nel binario" % nome)


## I TRE COMPONENTI NASCONO CON L'ENTITÀ, e nascono neutri. Se uno di loro
## arrivasse «quando serve», `vista2` — che adesso li chiede tutti e tre —
## smetterebbe di iterare quel residente: sparirebbe dall'agenda in silenzio,
## e nessuna delle asserzioni della Fase 2 se ne accorgerebbe perché
## parlano tutte di UN residente che ce li ha.
func _i_tre_componenti_nascono_neutri(t, m) -> void:
	var id: int = m.registra(PackedStringArray([]), "")
	var g: Dictionary = m.debug_grafo(id)
	t.eq((g["ricordi"] as Array).size(), 0, "chi è appena arrivato non ha visto niente")
	t.eq(int(g["versione"]), 0, "e il suo grafo non è mai stato scritto")

	var d: Dictionary = m.debug_emozioni(id)
	var mod: PackedFloat64Array = d["mod"]
	t.eq(mod.size(), 8, "gli otto modulatori ci sono da subito")
	var uno := 0
	for i in 8:
		if mod[i] == 1.0:
			uno += 1
	t.eq(uno, 8, "e valgono 1.0 ESATTO, tutti e otto: il neutro è letterale")
	var gusto: PackedFloat64Array = d["gusto"]
	t.eq(gusto.size(), 6, "il gusto ha una voce per cosa")
	var neutri := 0
	for c in gusto.size():
		if gusto[c] == 1.0:
			neutri += 1
	t.eq(neutri, 6,
			"e nasce neutro: un vicino che nessuno ha ancora descritto tiene a tutto uguale")
	t.almost(float(d["ammirazione"]), 0.0, "nessun ricordo, nessuna ammirazione", 0.0)
	# «mai valutato» non si scrive a mano: si legge che la vista NON combacia
	# con la versione del grafo, che è l'unica cosa che quel numero significa
	t.ok(int(d["vista"]) != int(g["versione"]),
			"il latch dichiara di non aver mai valutato niente")
	# e l'entità è comunque completa per l'agenda: `avanza` la vede
	m.riferisci_bisogni(id, PackedFloat64Array([0.0, 1.0, 1.0, 1.0, 1.0]))
	m.riferisci_agenda(id, m.maschera_fatti(PackedStringArray(["spuntino_vicino"])), true, false)
	var zero := PackedFloat64Array()
	zero.resize(8)
	m.semina_agenda(id, zero)
	m.avanza(DT, 0.5)
	t.eq(int(m.azione(id)), int(m.AZ_SPUNTINO),
			"…e il residente coi tre componenti nuovi è ancora dentro l'agenda")
	m.dimentica(id)


## IL PERCORSO VIVO È ANCORA NEUTRO per chi non ha visto niente — cioè per
## tutto il villaggio all'avvio, e per la stragrande maggioranza dei
## residenti quasi sempre. Non è una ripetizione dell'equivalenza: quella
## prova l'oracolo, questa prova la funzione che il gioco chiama davvero, e
## sono due siti di chiamata diversi.
func _il_villaggio_vergine_e_neutro(t, m) -> void:
	var casi := [
		[PackedFloat64Array([0.1, 0.4, 0.3, 0.6, 0.2]), ["spuntino_vicino", "amico_in_giro"], ["goloso"]],
		[PackedFloat64Array([0.9, 0.1, 0.5, 0.5, 0.0]), ["aiuola_da_annaffiare", "meraviglia_posto"], ["ordinato"]],
		[PackedFloat64Array([0.5, 0.5, 0.0, 0.9, 0.9]), ["amico_in_giro", "sera_stellata"], ["sognatore"]],
		[PackedFloat64Array([0.2, 0.2, 0.2, 0.2, 0.2]), ["spuntino_vicino", "aiuola_da_annaffiare",
				"amico_in_giro", "meraviglia_posto", "mattina"], ["chiacchierone", "ordinato"]],
	]
	var uguali := 0
	var punteggi_uguali := 0
	for c in casi:
		var id: int = m.registra(PackedStringArray(c[2]), "")
		m.riferisci_bisogni(id, c[0])
		m.riferisci_agenda(id, m.maschera_fatti(PackedStringArray(c[1])), true, false)
		var zero := PackedFloat64Array()
		zero.resize(8)
		m.semina_agenda(id, zero)
		m.avanza(DT, 0.5)
		var atteso: PackedFloat64Array = m.debug_punteggi(c[0],
				m.maschera_fatti(PackedStringArray(c[1])),
				m.maschera_indole(PackedStringArray(c[2])), -1)
		var best := -1.0
		var chi := -1
		for i in 8:
			if atteso[i] > best:
				best = atteso[i]
				chi = i
		var d: Dictionary = m.debug_agenda(id)
		if int(d["azione"]) == chi:
			uguali += 1
		# `==` e non `almost`: il neutro dev'essere lo STESSO double
		if float(d["punteggio"]) == best:
			punteggi_uguali += 1
		m.dimentica(id)
	t.eq(uguali, casi.size(),
			"col grafo vuoto il registro vivo sceglie ancora l'azione dell'oracolo nudo")
	t.eq(punteggi_uguali, casi.size(),
			"…e con lo STESSO double, bit per bit: la Fase 4 non ha cambiato di un bit chi non ha visto niente")


## L'AIUOLA CHE HA VISTO — ed è la ragione per cui esiste tutta la fase.
##
## Due vicini identici: stesso carattere (nessuna indole), stessi bisogni,
## stessi fatti del mondo, stesso dado (zero). Fra loro c'è UNA differenza
## sola: uno ha guardato Mochi annaffiare e l'altro stava dall'altra parte
## del villaggio. Il primo va all'aiuola; il secondo va a mangiare.
##
## PERCHÉ QUESTO CASO È IL PIÙ IMPORTANTE DEL FILE. Tutte le altre
## asserzioni guardano `debug_emozioni`, cioè il modulatore LATCHATO — e un
## `avanza()` che calcolasse diligentemente il modulatore e poi passasse a
## `punteggi()` otto 1.0 letterali le lascerebbe TUTTE verdi. La Fase 4
## sarebbe codice morto in partita, con la suite verde: esattamente il
## guasto che questo progetto ha già pagato con gli affetti («nessuna coppia
## poteva formarsi, MAI»). Qui si guarda quel che il registro DECIDE.
##
## La configurazione non è indovinata: è stata cercata misurando i punteggi
## nudi e prendendone una in cui lo spuntino batte la cura di 0.30 — dentro
## DELTA_MAX, quindi ribaltabile, ma solo da un'emozione vera.
func _l_emozione_inclina_davvero(t, m) -> void:
	var fatti := ["spuntino_vicino", "aiuola_da_annaffiare"]
	var masc: int = m.maschera_fatti(PackedStringArray(fatti))
	var bisogni := PackedFloat64Array([0.50, 1.0, 1.0, 1.0, 0.35])
	var i_cura: int = m.indice_azione("cura_giardino")

	var ignaro: int = _abitante(m, [], fatti)
	var testimone: int = _abitante(m, [], fatti)
	m.riferisci_bisogni(ignaro, bisogni)
	m.riferisci_bisogni(testimone, bisogni)
	# L'UNICA DIFFERENZA FRA I DUE: tre aiuole viste annaffiare.
	for k in 3:
		m.osserva(testimone, m.indice_verbo("annaffia"), Vector3(float(k), 0.0, 4.0), -1)
	m.avanza(DT, 0.5)

	var nudo: PackedFloat64Array = m.debug_punteggi(bisogni, masc, 0, -1)
	var best := -1.0
	var chi := -1
	for i in 8:
		if nudo[i] > best:
			best = nudo[i]
			chi = i
	t.ok(chi != i_cura,
			"senza emozione il mondo direbbe di andare a fare altro (azione %d a %s, la cura vale %s)"
					% [chi, str(best), str(nudo[i_cura])])
	t.eq(int(m.azione(ignaro)), chi,
			"…e chi non ha visto niente fa proprio quello")
	t.eq(int(m.azione(testimone)), i_cura,
			"MA chi ha visto Mochi annaffiare va all'aiuola: l'unica differenza fra i due è un ricordo")

	# e il punteggio del testimone è ESATTAMENTE quello che si ottiene
	# passando il suo modulatore all'oracolo: `avanza()` usa quel vettore, non
	# un neutro che si è calcolato per niente
	var mod: PackedFloat64Array = _mod(m, testimone)
	var con: PackedFloat64Array = m.debug_punteggi_mod(bisogni, masc, 0, -1, mod)
	var d: Dictionary = m.debug_agenda(testimone)
	t.eq(float(d["punteggio"]), con[i_cura],
			"…e con lo STESSO double: il registro vivo moltiplica proprio quel modulatore")
	t.ok(con[i_cura] > nudo[i_cura],
			"che è il punteggio nudo inclinato (%s → %s), non un numero nuovo"
					% [str(nudo[i_cura]), str(con[i_cura])])
	m.dimentica(ignaro)
	m.dimentica(testimone)


## IL GRADINO, ed è la misura principale di questo file.
##
## Mille passi SENZA nessun evento. Il grafo non cambia, quindi l'unica cosa
## che può muovere il modulatore è il tempo che passa — e il tempo si guarda
## a gradini di PASSO_EMO secondi, non a ogni frame.
##
## Le quattro asserzioni non sono ridondanti, e vale la pena dire perché:
##  · la RELAZIONE fra `PASSO_EMO` e la finestra di fusione: sono due
##    costanti diverse del C++, e il tetto qui sotto si legge dalla SECONDA
##    apposta. Un tetto calcolato da `PASSO_EMO` sarebbe un tetto che si
##    sposta insieme al guasto — l'ho verificato: portando `PASSO_EMO` a
##    zero, un tetto derivato da lui diventava infinito e questo caso
##    restava VERDE mentre il modulatore si muoveva a ogni frame.
##  · il TETTO sui cambi prende il caso «si rivaluta sempre»;
##  · il PAVIMENTO sui cambi (>= 1) prende il caso opposto, ed è quello che
##    un test scritto in buona fede dimentica: un mod congelato per sempre
##    passerebbe le altre a occhi chiusi, e il tempo smetterebbe di contare
##    senza che nessuno lo dica;
##  · la DERIVA IMPERCETTIBILE — che è la ragione per cui qui si confronta
##    con `!=` e non con `is_equal_approx`. Un modulatore riletto a ogni
##    frame si muove di un nulla per volta: un test scritto «a meno di
##    1e-9» lo vedrebbe fermo, e il tremolio passerebbe. Qui si contano le
##    due cose separatamente e si pretende che coincidano: fra un frame e
##    l'altro il modulatore o è LO STESSO DOUBLE, o è un gradino. Mai una
##    derivetta.
func _il_gradino(t, m) -> void:
	var passo := float(m.debug_ritmo()["passo_emo"])
	var fusione := float(m.debug_grafo_costanti()["finestra_fusione"])
	t.ok(passo >= fusione,
			("il gradino del cuore (%.1f s) non è più corto della finestra di fusione "
			+ "dei ricordi (%.1f s): sotto quella scala si comincerebbe a reagire alle "
			+ "singole aiuole di uno stesso gesto") % [passo, fusione])

	var id: int = _abitante(m)
	# qualcosa nel grafo, se no il mod è 1.0 per sempre e il caso è vuoto
	for v in [0, 2, 5, 7]:
		m.osserva(id, v, Vector3(1.0, 0.0, 2.0), -1)

	var prec := PackedFloat64Array()
	var cambi := 0
	var identici := 0
	var quasi := 0
	var confronti := 0
	for k in 1000:
		m.avanza(DT, 0.5)
		var mod: PackedFloat64Array = _mod(m, id)
		if prec.size() == 0:
			prec = mod.duplicate()
			continue
		confronti += 1
		var vicini := true
		for i in 8:
			if absf(mod[i] - prec[i]) > 1.0e-9:
				vicini = false
		if vicini:
			quasi += 1
		if _uguali(mod, prec):
			identici += 1
		else:
			cambi += 1
			prec = mod.duplicate()

	var durata := 1000.0 * DT
	# IL TETTO SI LEGGE DALLA FINESTRA DI FUSIONE, non da PASSO_EMO: una
	# soglia derivata dalla costante che si sta sorvegliando non sorveglia
	# niente.
	var attesi := int(durata / fusione) + 1
	t.ok(cambi <= attesi,
			("mille passi senza eventi (%.2f s) muovono il modulatore %d volte, "
			+ "non piu di %d") % [durata, cambi, attesi])
	t.ok(cambi >= 1,
			"…ma il tempo conta ancora: senza questa riga un modulatore congelato per sempre passerebbe (%d cambi)"
					% cambi)
	# `identici` e `quasi` non si asseriscono: sono la stessa cosa contata in
	# due modi, e la loro differenza sarebbe una deriva più piccola di 1e-9,
	# che nessuna mutazione plausibile produce (misurato: togliendo il
	# gradino la deriva per frame è dell'ordine di 1e-5, e il conteggio
	# ESATTO qui sopra la prende tutta). Restano nel messaggio perché dicono
	# a colpo d'occhio di che natura è un'eventuale rottura.
	t.ok(identici == quasi,
			("fra un frame e l'altro il modulatore o è LO STESSO DOUBLE o è un gradino: "
			+ "%d frame identici bit-per-bit, %d entro 1e-9") % [identici, quasi])
	m.dimentica(id)


## L'EMOZIONE AL MASSIMO NON FA TREMARE.
##
## È il banco di `test_agenda_ritmo._non_trema`, rifatto su un vicino che ha
## visto tutto e a cui importa di tutto — cioè col modulatore più grande che
## il gioco possa produrre. Il banco vecchio resta com'è e continua a provare
## il motore NUDO; questo prova che accendergli il cuore non rompe nessuna
## delle quattro garanzie della Fase 2.
##
## LE SOGLIE SONO LE STESSE DI LÀ, non allentate, ed è il punto: se
## l'emozione avesse bisogno di soglie sue, vorrebbe dire che ha cambiato il
## ritmo del villaggio — che è precisamente la cosa che non deve fare. La
## memoria inclina CHE COSA si sceglie, mai QUANTO SPESSO si sceglie.
## Misurato: 9,60 cambi al minuto col cuore al massimo contro 9,20 a cuore
## spento, permanenza minima IDENTICA (4,017 s), e il 75% dei frame che
## sceglie un'altra cosa.
##
## ONESTÀ SU COSA QUESTE QUATTRO RIGHE SORVEGLIANO. Sono un REQUISITO
## verificato con una misura, non un rilevatore di mutazioni: ho provato a
## guastare il gradino (`PASSO_EMO = 0`) e a togliere il tetto `DELTA_MAX`, e
## nessuna delle due le fa diventare rosse — le prendono altri casi (il costo,
## il gradino, lo scarto). Quel che invece le tiene oneste sono le DUE righe
## in fondo: senza di loro, un `avanza()` che non usasse affatto il modulatore
## passerebbe questo caso a occhi chiusi, perché un banco freddo rispetta
## tutte e quattro le soglie per definizione.
func _l_emozione_non_fa_tremare(t, m) -> void:
	var caldo := _banco_ritmo(600.0, true)
	var freddo := _banco_ritmo(600.0, false)

	t.ok(float(caldo["cambi_min"]) <= 12.0,
			"col cuore al massimo non trema: %.2f cambi d'idea al minuto (%.1f s per azione), come a cuore spento (%.2f)"
					% [caldo["cambi_min"], 60.0 / maxf(float(caldo["cambi_min"]), 0.001),
							freddo["cambi_min"]])
	t.ok(float(caldo["dwell_min"]) >= 2.0 - DT * 1.5,
			"e nessuna azione dura meno del tempo minimo (%.3f s)" % caldo["dwell_min"])
	t.ok(int(caldo["distinte"]) >= 3,
			"e in dieci minuti fa comunque almeno tre cose diverse (%d)" % int(caldo["distinte"]))
	var quota := 0.0 if int(caldo["cominciate"]) == 0 else \
			float(caldo["completate"]) / float(caldo["cominciate"])
	t.ok(quota >= 0.70,
			"e PORTA A TERMINE quel che comincia: %d su %d (%.0f%%)"
					% [int(caldo["completate"]), int(caldo["cominciate"]), quota * 100.0])
	# ANTI-TAUTOLOGIA: il banco «caldo» dev'essere davvero caldo, se no si
	# starebbe misurando due volte il motore nudo e le quattro righe di sopra
	# non direbbero niente.
	t.ok(float(caldo["mod_max"]) > 1.2,
			"…e il banco caldo aveva davvero il cuore acceso (modulatore massimo %.4f)"
					% caldo["mod_max"])
	var a: PackedInt32Array = caldo["scelte"]
	var b: PackedInt32Array = freddo["scelte"]
	var diverse := 0
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			diverse += 1
	t.ok(diverse > 0,
			"…e l'emozione ha cambiato davvero delle scelte rispetto al banco freddo (%d frame su %d)"
					% [diverse, a.size()])


## Il banco, nella forma di `test_agenda_ritmo._corri`: bisogni che calano
## come nel gioco, il corpo che si occupa dopo ogni scelta e sazia il bisogno
## SOLO QUANDO ARRIVA, e il dado ritirato solo a decisione finita.
## `con_cuore`: il vicino ha visto tutto e tiene a tutto.
func _banco_ritmo(secondi: float, con_cuore: bool) -> Dictionary:
	var m = ClassDB.instantiate("EcsMondo")
	var id: int = m.registra(PackedStringArray([]), "")
	if con_cuore:
		m.riferisci_gusto(id, PackedFloat64Array([4.0, 4.0, 4.0, 4.0, 4.0, 4.0]))
		# soggetti diversi per riempire l'anello davvero (la fusione unirebbe
		# i gemelli); uno su due è «fatto a me», che è quel che alza di più
		for k in 40:
			m.osserva(id, k % 8, Vector3(float(k), 0.0, 0.0), id if (k % 2 == 0) else -1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var fatti: int = m.maschera_fatti(PackedStringArray(["spuntino_vicino",
			"amico_in_giro", "meraviglia_posto"]))
	var needs := [0.9, 1.0, 0.7, 0.6, 0.8]
	var rate := [0.010, 0.007, 0.009, 0.008, 0.008]
	var cambi := 0
	var faccenda := 0.0
	var in_corso: int = m.AZ_NESSUNA
	var completate := 0
	var cominciate := 0
	var prec: int = m.AZ_NESSUNA
	var dwell := 0.0
	var dwell_min := 1.0e9
	var viste := {}
	var mod_max := 0.0
	var scelte := PackedInt32Array()
	for k in int(secondi / DT):
		for i in 5:
			needs[i] = maxf(0.0, needs[i] - rate[i] * DT)
		var bp := PackedFloat64Array()
		bp.resize(5)
		for i in 5:
			bp[i] = needs[i]
		m.riferisci_bisogni(id, bp)
		m.riferisci_agenda(id, fatti, faccenda <= 0.0, false)
		if m.vuole_dado(id):
			var j := PackedFloat64Array()
			j.resize(8)
			for i in 8:
				j[i] = rng.randf() * 0.25
			m.semina_agenda(id, j)
		m.avanza(DT, 0.5)
		var az: int = m.azione(id)
		scelte.append(az)
		if az != prec:
			if prec != m.AZ_NESSUNA:
				cambi += 1
				dwell_min = minf(dwell_min, dwell)
			prec = az
			dwell = 0.0
		else:
			dwell += DT
		if az != m.AZ_NESSUNA:
			viste[az] = true
		if m.azione_cambiata(id) and az != m.AZ_NESSUNA:
			faccenda = 4.0 + float(az) * 1.3
			in_corso = az
			cominciate += 1
			var mm: PackedFloat64Array = m.debug_emozioni(id)["mod"]
			for i in 8:
				mod_max = maxf(mod_max, mm[i])
		elif faccenda > 0.0:
			faccenda -= DT
			if faccenda <= 0.0:
				completate += 1
				match in_corso:
					m.AZ_SPUNTINO: needs[0] = 1.0
					m.AZ_RIPOSO: needs[1] = 1.0
					m.AZ_CHIACCHIERE: needs[2] = 1.0
					m.AZ_MERAVIGLIA: needs[3] = 1.0
					m.AZ_CURA_GIARDINO: needs[4] = 1.0
	m.free()
	return {"cambi_min": float(cambi) / (secondi / 60.0),
			"dwell_min": (0.0 if dwell_min > 1.0e8 else dwell_min),
			"distinte": viste.size(), "cambi": cambi,
			"cominciate": cominciate, "completate": completate,
			"mod_max": mod_max, "scelte": scelte}


## PRONTEZZA: l'inerzia non deve diventare sordità, nemmeno con il cuore
## acceso. Un'aiuola che secca adesso ha il suo pavimento a 0.9 e deve poter
## passare davanti — anche a chi ha appena visto Mochi fare tutt'altro.
func _la_prontezza_regge_col_cuore(t, m) -> void:
	var id: int = m.registra(PackedStringArray([]), "")
	m.riferisci_gusto(id, PackedFloat64Array([4.0, 4.0, 4.0, 4.0, 4.0, 4.0]))
	for k in 40:
		m.osserva(id, k % 8, Vector3(float(k), 0.0, 0.0), id if (k % 2 == 0) else -1)
	var j := PackedFloat64Array()
	j.resize(8)
	var base: int = m.maschera_fatti(PackedStringArray(["meraviglia_posto"]))
	for k in 300:
		m.riferisci_bisogni(id, PackedFloat64Array([0.95, 0.95, 1.0, 0.95, 1.0]))
		m.riferisci_agenda(id, base, true, false)
		if m.vuole_dado(id):
			m.semina_agenda(id, j)
		m.avanza(DT, 0.5)
	var con_aiuola: int = m.maschera_fatti(PackedStringArray(["meraviglia_posto",
			"aiuola_da_annaffiare"]))
	var quanti := 0
	while quanti < 600 and m.azione(id) != m.AZ_CURA_GIARDINO:
		m.riferisci_bisogni(id, PackedFloat64Array([0.95, 0.95, 1.0, 0.95, 1.0]))
		m.riferisci_agenda(id, con_aiuola, true, false)
		if m.vuole_dado(id):
			m.semina_agenda(id, j)
		m.avanza(DT, 0.5)
		quanti += 1
	t.eq(int(m.azione(id)), int(m.AZ_CURA_GIARDINO),
			"l'aiuola secca chiama, e risponde anche chi ha la testa piena di ricordi")
	t.ok(float(quanti) * DT <= 3.0,
			"…e risponde in fretta lo stesso: %.2f s (tetto 3.0)" % (float(quanti) * DT))
	m.dimentica(id)


## IL GRADINO NON È UN TETTO SULLA PRONTEZZA. Un ricordo NUOVO alza la
## versione del grafo e fa rileggere il cuore nello stesso frame: la ricevuta
## di un gesto non può aspettare otto secondi, o il giocatore non la collega
## più al gesto — ed è la sola cosa che rende falsificabile tutto il resto.
func _un_ricordo_nuovo_non_aspetta(t, m) -> void:
	var id: int = _abitante(m)
	m.avanza(DT, 0.5)
	var prima: PackedFloat64Array = _mod(m, id)
	var i_cura: int = m.indice_azione("cura_giardino")
	t.eq(prima[i_cura], 1.0, "a grafo vuoto la voglia di giardino non è inclinata")

	# UN SOLO frame dopo aver visto: il modulatore dev'essere già mosso
	m.osserva(id, m.indice_verbo("annaffia"), Vector3(2.0, 0.0, 3.0), -1)
	m.avanza(DT, 0.5)
	var dopo: PackedFloat64Array = _mod(m, id)
	t.ok(dopo[i_cura] > prima[i_cura],
			"un frame dopo aver visto annaffiare, la voglia di giardino è già inclinata (%s → %s)"
					% [str(prima[i_cura]), str(dopo[i_cura])])
	var d: Dictionary = m.debug_emozioni(id)
	t.eq(int(d["vista"]), int(d["versione"]),
			"…e il latch si è allineato alla versione del grafo")
	m.dimentica(id)


## L'ALTRO INGRESSO DELLA LETTURA È IL GUSTO, e il latch guarda il grafo:
## senza un'invalidazione esplicita, il salone di bellezza cambierebbe il
## carattere di un vicino e il suo cuore continuerebbe a usare il modulatore
## di prima. Ma solo se è cambiato QUALCOSA — il cablaggio riproietta a ogni
## campionamento dei fatti, e invalidare sempre annullerebbe il gradino
## trenta volte al secondo.
func _il_gusto_riproiettato_non_aspetta(t, m) -> void:
	var id: int = _abitante(m)
	m.osserva(id, m.indice_verbo("annaffia"), Vector3.ZERO, -1)
	m.avanza(DT, 0.5)
	var prima: PackedFloat64Array = _mod(m, id)
	var i_cura: int = m.indice_azione("cura_giardino")

	# lo STESSO gusto: niente da rivalutare, il latch non si muove
	var d0: Dictionary = m.debug_emozioni(id)
	m.riferisci_gusto(id, d0["gusto"])
	var d1: Dictionary = m.debug_emozioni(id)
	t.eq(int(d1["vista"]), int(d0["vista"]),
			"riproiettare lo STESSO gusto non invalida niente: il gradino regge")

	# un gusto DIVERSO: rivalutazione al primo passo
	m.riferisci_gusto(id, PackedFloat64Array([4.0, 1.0, 1.0, 1.0, 1.0, 1.0]))
	m.avanza(DT, 0.5)
	var dopo: PackedFloat64Array = _mod(m, id)
	t.ok(dopo[i_cura] > prima[i_cura],
			"a chi tiene ai fiori quattro volte tanto, lo stesso ricordo inclina di più (%s → %s)"
					% [str(prima[i_cura]), str(dopo[i_cura])])
	m.dimentica(id)


## LA SCALA. Qualunque cosa un vicino abbia visto, il modulatore resta in
## [1.0, 1.5]: sotto 1.0 vorrebbe dire «da quando ti ho vista annaffiare ho
## meno voglia di parlare», cioè contenuto negativo su una persona — e la
## Fase 4 non lo vieta per gentilezza, se lo vieta per costruzione.
## E si muovono DUE azioni su otto: la stella è pinnata perché il cielo
## notturno non è una faccenda di simpatie.
func _il_mod_resta_in_scala(t, m) -> void:
	var i_chiacchiere: int = m.indice_azione("quattro_chiacchiere")
	var i_cura: int = m.indice_azione("cura_giardino")
	var i_stella: int = m.indice_azione("stella")
	var gusti := [
		PackedFloat64Array([1.0, 1.0, 1.0, 1.0, 1.0, 1.0]),
		PackedFloat64Array([4.0, 4.0, 4.0, 4.0, 4.0, 4.0]),
		PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0]),
		PackedFloat64Array([4.0, 0.0, 2.0, 0.0, 1.0, 3.0]),
	]
	var fuori := 0
	var mossi := 0
	var stella_ferma := 0
	var casi := 0
	for g in gusti:
		for quanti in [0, 1, 8, 24, 40]:
			var id: int = _abitante(m)
			m.riferisci_gusto(id, g)
			# soggetti diversi per riempire davvero l'anello (la fusione
			# unirebbe i gemelli): uno ogni tre è «fatto a me»
			for k in quanti:
				m.osserva(id, k % 8, Vector3(float(k), 0.0, 0.0),
						id if (k % 3 == 0) else -1)
			m.avanza(DT, 0.5)
			var mod: PackedFloat64Array = _mod(m, id)
			casi += 1
			for i in 8:
				if mod[i] < 1.0 or mod[i] > 1.5:
					fuori += 1
				if i != i_chiacchiere and i != i_cura and mod[i] != 1.0:
					fuori += 1000
			if mod[i_stella] == 1.0:
				stella_ferma += 1
			if quanti > 0 and g[0] > 0.0 and mod[i_cura] > 1.0:
				mossi += 1
			m.dimentica(id)
	t.eq(fuori, 0,
			"su %d grafi veri nessun modulatore esce da [1.0, 1.5], e sei azioni su otto non si muovono MAI"
					% casi)
	t.eq(stella_ferma, casi,
			"la stella resta pinnata a 1.0 in tutti e %d i casi" % casi)
	t.ok(mossi >= 12,
			"…e il modulatore si muove davvero (%d casi): una scala rispettata da un canale spento non prova niente"
					% mossi)


## LA COMPOSIZIONE COL PUNTEGGIO, dal vivo. `test_agenda_innesto` prova il
## tetto su modulatori inventati; qui si prende il modulatore che il registro
## VIVO produce a fondo scala e si guarda quanto sposta i punteggi veri.
## Deve restare sotto DELTA_MAX, che è la rete che tiene l'emozione fuori
## dalla corsia d'urgenza.
func _lo_scarto_vivo_non_passa_il_tetto(t, m) -> void:
	var dmax := float(m.debug_costanti_agenda()["delta_max"])
	var fatti := ["spuntino_vicino", "amico_in_giro", "aiuola_da_annaffiare",
			"meraviglia_posto", "mattina", "sera_stellata", "regia", "regia_pronta"]
	var masc: int = m.maschera_fatti(PackedStringArray(fatti))
	var bisogni := PackedFloat64Array([0.2, 0.2, 0.2, 0.2, 0.2])
	var id: int = m.registra(PackedStringArray(["sognatore"]), "")
	m.riferisci_gusto(id, PackedFloat64Array([4.0, 4.0, 4.0, 4.0, 4.0, 4.0]))
	for k in 40:
		m.osserva(id, k % 8, Vector3(float(k), 0.0, 0.0), id if (k % 2 == 0) else -1)
	m.riferisci_bisogni(id, bisogni)
	m.riferisci_agenda(id, masc, true, false)
	m.avanza(DT, 0.5)

	var mod: PackedFloat64Array = _mod(m, id)
	var indole: int = m.maschera_indole(PackedStringArray(["sognatore"]))
	var nudo: PackedFloat64Array = m.debug_punteggi(bisogni, masc, indole, -1)
	var con: PackedFloat64Array = m.debug_punteggi_mod(bisogni, masc, indole, -1, mod)
	var sforati := 0
	var peggiore := 0.0
	for i in 8:
		var d: float = absf(con[i] - nudo[i])
		peggiore = maxf(peggiore, d)
		if d > dmax + 1e-12:
			sforati += 1
	t.eq(sforati, 0,
			"col modulatore VIVO a fondo scala, lo scarto peggiore sui punteggi è %s (tetto %s)"
					% [str(peggiore), str(dmax)])
	t.ok(peggiore > 0.0,
			"…e c'è uno scarto vero da misurare (un modulatore spento passerebbe la riga di sopra)")
	m.dimentica(id)


## IL TEMPO DELLA MEMORIA È IN SECONDI, E NON È L'ORA DEL GIORNO.
##
## Questo è il difetto più silenzioso che questa fase poteva avere. `avanza`
## riceve la frazione di giornata (0..1): torna indietro a mezzanotte, e nei
## banchi resta ferma per minuti. Se i ricordi si timbrassero con quella, non
## decadrebbero mai — e un grafo eterno con la suite verde è precisamente il
## guasto che `peso()` è stato scritto per rendere impossibile.
##
## Qui si fa passare UNA MEZZA VITA a ora COSTANTE, e si pretende che
## l'interesse si dimezzi.
func _il_tempo_della_memoria_non_e_l_ora_del_giorno(t, m) -> void:
	var mv := float(m.debug_ritmo()["mezza_vita"])
	var id: int = _abitante(m)
	m.osserva(id, m.indice_verbo("annaffia"), Vector3.ZERO, -1)
	m.avanza(DT, 0.5)
	var d0: Dictionary = m.debug_emozioni(id)
	var i0 := float(d0["interesse"][0])
	t.ok(i0 > 0.0, "il ricordo fresco tinge davvero (%s)" % str(i0))

	var t0 := float(m.debug_ritmo()["tempo"])
	var passi := int(mv / DT)
	for k in passi:
		# L'ORA NON SI MUOVE DI UN MILLESIMO, esattamente come nei banchi
		m.avanza(DT, 0.5)
	var t1 := float(m.debug_ritmo()["tempo"])
	t.almost(t1 - t0, mv,
			"l'orologio della memoria ha contato una mezza vita (%.2f s) a ora del giorno FERMA"
					% (t1 - t0), 0.05)
	var d1: Dictionary = m.debug_emozioni(id)
	var i1 := float(d1["interesse"][0])
	t.almost(i1 / i0, 0.5,
			"…e l'interesse si è dimezzato: il ricordo invecchia col tempo VERO, non con l'ora del giorno",
			0.005)
	m.dimentica(id)


## L'orologio non torna indietro. Un delta negativo (un banco che va
## all'indietro, un frame patologico) farebbe RINGIOVANIRE i ricordi, e un
## ricordo che ringiovanisce non lo pota più nessuno.
func _l_orologio_non_torna_indietro(t, m) -> void:
	var prima := float(m.debug_ritmo()["tempo"])
	m.avanza(-5.0, 0.5)
	var dopo := float(m.debug_ritmo()["tempo"])
	t.almost(dopo, prima, "un delta negativo non sposta l'orologio della memoria", 1e-9)
	m.avanza(1.0, 0.5)
	t.almost(float(m.debug_ritmo()["tempo"]), prima + 1.0,
			"…mentre un delta vero lo sposta di quanto dice", 1e-9)


## LE MEZZE VITE SI DERIVANO DAL CICLO DEL GIORNO, non si riscrivono: un
## villaggio con le giornate lunghe ha ricordi lunghi, e il giorno che
## qualcuno muove `DayNight.cycle_seconds` non deve andare a cercare un 120
## nascosto in un header.
func _il_ritmo_si_deriva(t, m) -> void:
	var n = ClassDB.instantiate("EcsMondo")
	t.almost(float(n.debug_ritmo()["mezza_vita"]), 120.0,
			"la mezza vita di partenza è mezza giornata di gioco (ciclo 240 s)", 1e-9)
	n.imposta_ritmo(600.0)
	t.almost(float(n.debug_ritmo()["mezza_vita"]), 300.0,
			"con giornate da dieci minuti, i ricordi durano cinque", 1e-9)
	# Un ciclo assurdo si RIFIUTA e la taratura resta quella di prima. Non lo
	# si pinza: pinzarlo vorrebbe dire accettare in silenzio un DayNight rotto
	# e proseguire con una mezza vita inventata. (La riga `ERROR:` che questa
	# chiamata stampa è voluta — è la guardia che parla.)
	n.imposta_ritmo(0.0)
	t.almost(float(n.debug_ritmo()["mezza_vita"]), 300.0,
			"un ciclo di zero secondi si rifiuta, e il ritmo di prima resta in piedi", 1e-9)

	# e non è solo un numero nel dizionario: cambia il DECADIMENTO
	var id: int = n.registra(PackedStringArray([]), "")
	n.osserva(id, n.indice_verbo("annaffia"), Vector3.ZERO, -1)
	var i0 := float((n.debug_emozioni(id)["interesse"] as PackedFloat64Array)[0])
	for k in int(120.0 / DT):
		n.avanza(DT, 0.5)
	var i1 := float((n.debug_emozioni(id)["interesse"] as PackedFloat64Array)[0])
	t.ok(i1 / i0 > 0.60,
			"con la mezza vita a 300 s, dopo 120 s resta il %.0f%% (con 120 s ne resterebbe la metà)"
					% (100.0 * i1 / i0))
	n.dimentica(id)
	n.free()


## La Fase 4 non porta il `TransformComponent`: un componente scritto e letto
## da nessuno è un motore acceso a vuoto. Lo ripete anche `test_ecs_mondo`,
## e lo si ripete QUI perché è questa la fase che ha aggiunto componenti —
## chi ne aggiunge uno per abitudine deve trovare una riga rossa.
func _niente_pose(t, m) -> void:
	var id: int = _abitante(m)
	m.osserva(id, 0, Vector3.ONE, -1)
	m.avanza(DT, 0.5)
	t.eq(m.debug_quante_pose(), 0,
			"i tre componenti nuovi non hanno portato dentro nemmeno una posa")
	m.dimentica(id)
