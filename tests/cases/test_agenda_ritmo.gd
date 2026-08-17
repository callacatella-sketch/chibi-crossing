extends RefCounted
## IL RITMO: valutare di continuo SENZA tremare.
##
## È il cuore della Fase 2, e la tensione è tutta qui. «Valutazione
## continua» e «cambiano idea dinamicamente» tirano da una parte; «sembrano
## vivi» tira dall'altra — perché un vicino che ricalcola sessanta volte al
## secondo e cambia idea a ogni ricalcolo non sembra vivo: VIBRA. E il
## danno peggiore non è nemmeno estetico: rilanciare il cammino ogni frame
## vuol dire non ARRIVARE mai, quindi non completare mai il gesto, quindi
## non soddisfare mai il bisogno — e il bisogno insoddisfatto rilancia il
## ciclo. Un livelock che non stampa nessun errore.
##
## Le tre leve, e qui si misura ognuna TOGLIENDOLA (il metodo di
## test_taccuino: si guasta una valvola per volta e si pretende che
## qualcosa fallisca; se un'ablazione non rompe niente, quella valvola è
## diventata inutile e il test lo dice).
##   1. il lucchetto del corpo — mentre cammina non si commuta
##   2. T_MIN = 2.0 s — a corpo fermo, il tempo minimo in un'azione
##   3. il dado CONGELATO per decisione, non ritirato a ogni frame

const DT := 1.0 / 60.0
const ORDINE := ["pancino", "energia", "compagnia", "meraviglia", "cura"]


func run(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	_non_trema(t)
	_ablazione_tempo_minimo(t)
	_ablazione_dado_congelato(t)
	_lucchetto_del_corpo(t)
	_prontezza(t)
	_chi_dorme_non_ha_agenda(t)
	_gli_altri_sistemi_comandano(t)


## Il banco: un residente, bisogni che calano come nel gioco, contesto
## ricco (così più azioni se la giocano davvero), e il dado ritirato SOLO
## quando il registro lo chiede.
## `occupa`: se vero il corpo si mette in moto dopo ogni scelta e sazia il
## bisogno solo QUANDO ARRIVA — che è come funziona il gioco, ed è anche il
## motivo per cui saziare nel frame della decisione (come fanno oggi
## «riposo» e «falò») sarebbe una macchina per oscillare cablata nel codice:
## l'azione appena scelta si azzera il punteggio da sola.
## Se falso, il corpo resta sempre libero e nessun bisogno si sazia: è il
## caso peggiore per il tremolio, e serve a isolare le leve 2 e 3.
func _corri(t, secondi: float, tar: Array, congela := true, rng_seme := 12345,
		occupa := true) -> Dictionary:
	var m = ClassDB.instantiate("EcsMondo")
	m.debug_tara_agenda(tar[0], tar[1], tar[2], tar[3])
	var id: int = m.registra(PackedStringArray([]), "")
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seme
	var fatti: int = m.maschera_fatti(PackedStringArray(["spuntino_vicino",
			"amico_in_giro", "meraviglia_posto"]))

	# i bisogni calano come in VillagerBrain.tick: il motore non li possiede,
	# glieli si riferisce — ed è esattamente quel che fa il gioco
	var needs := [0.9, 1.0, 0.7, 0.6, 0.8]
	var rate := [0.010, 0.007, 0.009, 0.008, 0.008]

	var cambi := 0
	var faccenda := 0.0        # quanto manca a compiere il gesto
	var in_corso: int = m.AZ_NESSUNA
	var completate := 0
	var cominciate := 0
	var prec: int = m.AZ_NESSUNA
	var dwell := 0.0
	var dwell_min := 1.0e9
	var viste := {}
	var passi := int(secondi / DT)
	for k in passi:
		for i in 5:
			needs[i] = maxf(0.0, needs[i] - rate[i] * DT)
		var bp := PackedFloat64Array()
		bp.resize(5)
		for i in 5:
			bp[i] = needs[i]
		m.riferisci_bisogni(id, bp)
		# il corpo è occupato finché non ha finito quel che stava facendo
		m.riferisci_agenda(id, fatti, faccenda <= 0.0, false)
		# LA LEVA 3: il dado si ritira solo a decisione finita. Con
		# `congela = false` si simula il ritiro a ogni frame, che è il modo
		# più diretto di far vibrare un utility AI.
		if (congela and m.vuole_dado(id)) or not congela:
			var j := PackedFloat64Array()
			j.resize(8)
			for i in 8:
				j[i] = rng.randf() * 0.25
			m.semina_agenda(id, j)
		m.avanza(DT, 0.5)
		var az: int = m.azione(id)
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
		# L'ANELLO CHIUSO: si decide, ci si va, e SOLO ALL'ARRIVO il bisogno
		# si sazia. Senza chiudere l'anello il banco misurerebbe un limite
		# INFERIORE del tremolio, cioè una misura consolatoria.
		if occupa:
			if m.azione_cambiata(id) and az != m.AZ_NESSUNA:
				# durata VERA di un gesto: col Visitor in mano sono stati
				# misurati 2.02 s su 3 m e 8.22 s su 12 m. Tre secondi fissi
				# erano una scorciatoia che gonfiava i cambi al minuto.
				faccenda = 4.0 + float(az) * 1.3
				in_corso = az
				cominciate += 1
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
			"cominciate": cominciate, "completate": completate}


## LA MISURA PRINCIPALE. Le soglie non sono di gusto: 6 cambi al minuto è
## il tetto della cadenza di oggi (si ridecideva ogni 9-15 s, cioè al più
## ~6,7 decisioni al minuto, e non tutte cambiavano qualcosa).
func _non_trema(t) -> void:
	var r := _corri(t, 600.0, [2.0, 1.08, 0.60, 45.0])
	# LA SOGLIA, e da dove viene. Prima l'avevo messa a 6.0 leggendo la
	# cadenza di oggi (si ridecideva ogni 9-15 s), ma le due cose non si
	# misurano allo stesso metro: là erano DECISIONI, e quasi tutte
	# confermavano l'azione in corso. Qui ogni gesto portato a termine sazia
	# il suo bisogno e apre legittimamente una scelta nuova, quindi il numero
	# giusto da guardare è la permanenza MEDIA: 12 cambi al minuto vuol dire
	# cinque secondi per azione, che è la durata di un gesto vero. Sotto i
	# cinque secondi comincerebbe a sembrare indeciso.
	t.ok(r["cambi_min"] <= 12.0,
			"non trema: %.2f cambi d'idea al minuto, cioè %.1f s per azione"
					% [r["cambi_min"], 60.0 / maxf(r["cambi_min"], 0.001)])
	# LA METRICA NON BARABILE: i cambi al minuto sono una media, e una media
	# non vede il singolo frame sfuggito. La permanenza minima sì.
	t.ok(r["dwell_min"] >= 2.0 - DT * 1.5,
			"e nessuna azione dura meno del tempo minimo (%.3f s)" % r["dwell_min"])
	# ma nemmeno si impantana: «T_MIN = un giorno» passerebbe le prime due
	t.ok(int(r["distinte"]) >= 3,
			"e in dieci minuti fa almeno tre cose diverse (%d)" % int(r["distinte"]))
	# LA METRICA CHE VEDE IL LIVELOCK. Un vicino che cambia idea prima di
	# arrivare non completa mai niente, e non stampa nessun errore: senza
	# questa asserzione la suite resterebbe verde su un villaggio paralizzato.
	var quota := 0.0 if int(r["cominciate"]) == 0 else \
			float(r["completate"]) / float(r["cominciate"])
	t.ok(quota >= 0.70,
			"e PORTA A TERMINE quel che comincia: %d su %d (%.0f%%)"
					% [int(r["completate"]), int(r["cominciate"]), quota * 100.0])


## ABLAZIONE 1 — via il tempo minimo, misurato DOVE MORDE.
##
## Due stesure di questa ablazione non rompevano niente, e avevano ragione
## tutte e due: con bisogni che scorrono piano il lucchetto del corpo basta
## da solo, e sul PAREGGIO ESATTO il dado congelato più il bonus bloccano
## l'azione per sempre (misurato: zero cambi in cinque minuti). Misurare una
## valvola dove non lavora è un modo elegante di non misurarla.
##
## T_MIN è l'ULTIMA linea, e morde in un caso preciso — che non è teorico,
## è quello che il codice fa OGGI: un'azione che sazia il proprio bisogno
## nel frame in cui viene scelta (è così per «riposo» e per il falò) si
## azzera il punteggio da sola, il secondo classificato vince subito, il
## dado si ritira, e si riparte. È una macchina per oscillare, e senza un
## tempo minimo gira alla frequenza del frame.
func _sazia_subito(t, t_min: float) -> Dictionary:
	var m = ClassDB.instantiate("EcsMondo")
	m.debug_tara_agenda(t_min, 1.08, 0.60, 45.0)
	var id: int = m.registra(PackedStringArray([]), "")
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var fatti: int = m.maschera_fatti(PackedStringArray(["spuntino_vicino",
			"amico_in_giro", "meraviglia_posto"]))
	var needs := [0.2, 0.2, 0.2, 0.2, 1.0]
	var rate := [0.010, 0.007, 0.009, 0.008, 0.008]
	var cambi := 0
	var prec: int = m.AZ_NESSUNA
	var dwell := 0.0
	var dwell_min := 1.0e9
	var passi := 18000   # cinque minuti simulati
	for k in passi:
		for i in 5:
			needs[i] = maxf(0.0, needs[i] - rate[i] * DT)
		var bp := PackedFloat64Array()
		bp.resize(5)
		for i in 5:
			bp[i] = needs[i]
		m.riferisci_bisogni(id, bp)
		m.riferisci_agenda(id, fatti, true, false)   # corpo SEMPRE libero
		if m.vuole_dado(id):
			var j := PackedFloat64Array()
			j.resize(8)
			for i in 8:
				j[i] = rng.randf() * 0.25
			m.semina_agenda(id, j)
		m.avanza(DT, 0.5)
		var az: int = m.azione(id)
		if az != prec:
			if prec != m.AZ_NESSUNA:
				cambi += 1
				dwell_min = minf(dwell_min, dwell)
			prec = az
			dwell = 0.0
		else:
			dwell += DT
		# LA SAZIETÀ NEL FRAME DELLA DECISIONE, come fa oggi «riposo»
		if m.azione_cambiata(id):
			match az:
				m.AZ_SPUNTINO: needs[0] = 1.0
				m.AZ_RIPOSO: needs[1] = 1.0
				m.AZ_CHIACCHIERE: needs[2] = 1.0
				m.AZ_MERAVIGLIA: needs[3] = 1.0
	m.free()
	# se non ha MAI cambiato, la permanenza minima è tutta la corsa: dire
	# «zero» sarebbe il contrario della verità
	var minimo: float = (float(passi) * DT) if dwell_min > 1.0e8 else dwell_min
	return {"cambi_min": float(cambi) / 5.0, "dwell_min": minimo}


func _ablazione_tempo_minimo(t) -> void:
	var sano := _sazia_subito(t, 2.0)
	var guasto := _sazia_subito(t, 0.0)
	# il pavimento è UN QUARTO di T_MIN, perché qui ogni scelta si azzera il
	# punteggio da sola e quindi passa sempre dalla corsia d'urgenza
	t.ok(sano["dwell_min"] >= 0.5 - DT * 1.5,
			"con T_MIN nemmeno l'urgenza scende sotto mezzo secondo (%.3f s)"
					% sano["dwell_min"])
	t.ok(guasto["dwell_min"] < 0.5 - DT * 1.5,
			"togliendolo compaiono le azioni lunghe un respiro (%.3f s)"
					% guasto["dwell_min"])
	# NON si asserisce il verso dei cambi al minuto, e vale la pena dire
	# perché: in questo scenario togliere T_MIN ne produce di MENO (misurato
	# 1.0 contro 21.6), perché senza freno il vicino brucia tutti e quattro i
	# bisogni nei primi frame e poi si siede sul gironzolare. Un numero più
	# basso può voler dire «più calmo» o «paralizzato», e da solo non
	# distingue: per quello c'è la permanenza minima.
	t.ok(sano["cambi_min"] > 0.0 and guasto["cambi_min"] > 0.0,
			"e in entrambi i casi qualcosa succede (%.1f e %.1f al minuto)"
					% [sano["cambi_min"], guasto["cambi_min"]])


## ABLAZIONE 2 — via il dado congelato. Il rumore vale 0.25 e la variazione
## di un punteggio in un frame è dell'ordine di 0.0003: ritirare il dado a
## ogni frame vuol dire decidere con un dado invece che con i bisogni.
func _ablazione_dado_congelato(t) -> void:
	var sano := _corri(t, 300.0, [2.0, 1.08, 0.60, 45.0], true, 12345, false)
	var guasto := _corri(t, 300.0, [2.0, 1.08, 0.60, 45.0], false, 12345, false)
	t.ok(guasto["cambi_min"] > sano["cambi_min"],
			"col dado ritirato ogni frame si cambia idea molto più spesso (%.2f contro %.2f al minuto)"
					% [guasto["cambi_min"], sano["cambi_min"]])


## LA LEVA 1, quella che conta di più: mentre il corpo è occupato non si
## commuta. Senza, il residente rilancia il cammino ogni frame e non arriva
## mai — nessun errore, nessun test rosso, e i bisogni che non si saziano.
func _lucchetto_del_corpo(t) -> void:
	var m = ClassDB.instantiate("EcsMondo")
	m.debug_tara_agenda(0.0, 1.0, 1.0e9, 1.0e9) # tolte TUTTE le altre leve
	var id: int = m.registra(PackedStringArray([]), "")
	var fatti: int = m.maschera_fatti(PackedStringArray(["spuntino_vicino",
			"amico_in_giro", "meraviglia_posto"]))
	var j := PackedFloat64Array()
	j.resize(8)
	# si comincia con un'azione qualunque
	m.riferisci_bisogni(id, PackedFloat64Array([0.0, 1.0, 1.0, 1.0, 1.0]))
	m.riferisci_agenda(id, fatti, true, false)
	m.semina_agenda(id, j)
	m.avanza(DT, 0.5)
	var prima: int = m.azione(id)
	t.eq(prima, m.AZ_SPUNTINO, "affamato, va a mangiare")

	# adesso il corpo si mette in moto, e nel frattempo un altro bisogno
	# diventa più forte: NON deve cambiare idea a metà strada
	var cambi := 0
	for k in 600:
		m.riferisci_bisogni(id, PackedFloat64Array([1.0, 0.0, 0.0, 0.0, 1.0]))
		m.riferisci_agenda(id, fatti, false, false) # corpo OCCUPATO
		m.avanza(DT, 0.5)
		if m.azione(id) != prima:
			cambi += 1
	t.eq(cambi, 0,
			"mentre il corpo cammina non si cambia idea, nemmeno se un altro bisogno urla")

	# e appena il corpo è libero, la nuova voglia vince
	m.riferisci_agenda(id, fatti, true, false)
	m.avanza(DT, 0.5)
	t.ok(m.azione(id) != prima, "…ma appena arriva, cambia")
	m.free()


## PRONTEZZA: l'inerzia non deve diventare sordità. Un'aiuola che secca
## adesso ha il suo «pavimento» a 0.9 e deve poter passare davanti.
func _prontezza(t) -> void:
	var m = ClassDB.instantiate("EcsMondo")
	m.debug_tara_agenda(2.0, 1.08, 0.60, 45.0)
	var id: int = m.registra(PackedStringArray([]), "")
	var j := PackedFloat64Array()
	j.resize(8)
	var base: int = m.maschera_fatti(PackedStringArray(["meraviglia_posto"]))
	# bisogni quasi pieni: sta gironzolando
	for k in 300:
		m.riferisci_bisogni(id, PackedFloat64Array([0.95, 0.95, 1.0, 0.95, 1.0]))
		m.riferisci_agenda(id, base, true, false)
		if m.vuole_dado(id):
			m.semina_agenda(id, j)
		m.avanza(DT, 0.5)
	# l'aiuola secca compare ADESSO
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
	t.eq(m.azione(id), m.AZ_CURA_GIARDINO, "l'aiuola secca chiama, e qualcuno risponde")
	t.ok(float(quanti) * DT <= 3.0,
			"e risponde in fretta: %.2f s (tetto 3.0)" % (float(quanti) * DT))
	m.free()


## CHI DORME NON HA UN'AGENDA. Il sonno è l'altra autorità del C++ e sta
## SOPRA questa: se qui si decidesse anche da addormentati, al risveglio il
## corpo riceverebbe un ordine deciso durante la notte.
func _chi_dorme_non_ha_agenda(t) -> void:
	var m = ClassDB.instantiate("EcsMondo")
	var id: int = m.registra(PackedStringArray([]), "")
	var j := PackedFloat64Array()
	j.resize(8)
	var fatti: int = m.maschera_fatti(PackedStringArray(["spuntino_vicino",
			"amico_in_giro", "meraviglia_posto", "aiuola_da_annaffiare"]))
	# lo si porta a dormire (ora dentro la finestra, corpo libero)
	for k in 10:
		m.riferisci_bisogni(id, PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0]))
		m.riferisci_agenda(id, fatti, true, false)
		m.semina_agenda(id, j)
		m.avanza(DT, 0.85)
	t.eq(m.stato(id), m.STATO_DORME, "dorme")
	t.eq(m.azione(id), m.AZ_NESSUNA,
			"e con ogni bisogno a zero l'agenda TACE lo stesso: il sonno viene prima")
	m.free()


## GLI UNDICI SISTEMI A EVENTO COMANDANO. Quando il falò, un congedo o una
## promessa hanno preso il corpo, l'agenda non emette ordini — con qualunque
## punteggio.
func _gli_altri_sistemi_comandano(t) -> void:
	var m = ClassDB.instantiate("EcsMondo")
	var id: int = m.registra(PackedStringArray([]), "")
	var j := PackedFloat64Array()
	j.resize(8)
	var fatti: int = m.maschera_fatti(PackedStringArray(["spuntino_vicino",
			"amico_in_giro", "meraviglia_posto", "aiuola_da_annaffiare"]))
	var cambi := 0
	for k in 3600:
		m.riferisci_bisogni(id, PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0]))
		m.riferisci_agenda(id, fatti, true, true) # ZITTITA
		m.semina_agenda(id, j)
		m.avanza(DT, 0.5)
		if m.azione_cambiata(id):
			cambi += 1
	t.eq(cambi, 0,
			"con l'agenda zittita non parte un solo ordine in un minuto, a bisogni a zero")
	t.eq(m.azione(id), m.AZ_NESSUNA, "e nessuna azione viene adottata alle loro spalle")
	m.free()
