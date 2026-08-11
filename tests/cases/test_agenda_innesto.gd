extends RefCounted
## L'INNESTO DELL'EMOZIONE NEL PUNTEGGIO (Fase 4, passo 3).
##
## `chibi::punteggi()` ha preso un nono argomento: otto modulatori, uno per
## azione, OBBLIGATORI e mai nullable. In questo passo il gioco non è
## cambiato di un bit — il percorso vivo passa otto 1.0 letterali — ma il
## motore della Fase 2, che gira in partita, adesso ha una porta in mezzo.
## Qui si prova che quella porta si apre esattamente quanto deve.
##
## L'uguaglianza col passato sta in `test_agenda_equivalenza.gd`, che rifà
## i suoi 67.200 confronti bit-esatti anche ATTRAVERSO il codice nuovo.
## Questo file prova le cose che l'equivalenza, per costruzione, non può
## vedere: cosa succede quando il modulatore NON è 1.0.
##
## Le quattro regole che il file difende, e ognuna è una scena:
##
##  1. **L'emozione inclina, non accelera.** Lo scarto è pinzato in valore
##     ASSOLUTO a DELTA_MAX, che sta sotto il `margine` d'urgenza: partendo
##     da un pareggio, l'ammirazione da sola non può mai aprire la corsia
##     che porta il tempo minimo da 2,0 s a 0,5 s. Se potesse, un vicino
##     che ti ammira cambierebbe idea quattro volte più spesso PER SEMPRE,
##     e ogni asserzione sui punteggi resterebbe verde.
##  2. **Il mondo batte l'emozione.** Il modulatore entra PRIMA del
##     pavimento: un'aiuola che secca chiama chiunque, anche chi ti ama
##     poco. Rovesciando l'ordine, un vicino tiepido lascerebbe morire il
##     giardino perché non gli stai simpatica — e il giocatore non avrebbe
##     nessun modo di capire perché.
##  3. **Il cielo non è una faccenda di simpatie.** Il modulatore entra
##     PRIMA che il DNA spenga la stella: nessuna ammirazione rimette in
##     piedi una veglia che il carattere non fa.
##  4. **Un modulatore non è un veto.** A mod = 0 l'azione perde al massimo
##     DELTA_MAX e resta in gara. La memoria inclina; non cancella.

const ORDINE := ["pancino", "energia", "compagnia", "meraviglia", "cura"]

## bisogni tutti VUOTI: ogni azione chiama al massimo, così il modulatore ha
## un numero vero su cui mordere invece che uno zero
var VUOTI := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])
var PIENI := PackedFloat64Array([1.0, 1.0, 1.0, 1.0, 1.0])
var UNO := PackedFloat64Array([1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0])


func run(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	var m = ClassDB.instantiate("EcsMondo")
	_api(t, m)
	_il_tetto_sta_sotto_il_margine(t, m)
	_il_neutro_e_neutro(t, m)
	_lo_scarto_non_supera_mai_il_tetto(t, m)
	_il_pavimento_batte_l_emozione(t, m)
	_la_stella_resta_del_cielo(t, m)
	_non_e_un_veto(t, m)
	_niente_punteggi_negativi(t, m)
	_solo_due_azioni_si_muovono(t, m)
	_la_lista_storta_si_rifiuta(t, m)
	_il_percorso_vivo_e_neutro(t, m)
	m.free()


func _p(m, bisogni: PackedFloat64Array, fatti: Array, indole: Array,
		quirk := "") -> PackedFloat64Array:
	return m.debug_punteggi(bisogni, m.maschera_fatti(PackedStringArray(fatti)),
			m.maschera_indole(PackedStringArray(indole)), m.indice_quirk(quirk))


func _pm(m, bisogni: PackedFloat64Array, fatti: Array, indole: Array,
		mod: PackedFloat64Array, quirk := "") -> PackedFloat64Array:
	return m.debug_punteggi_mod(bisogni, m.maschera_fatti(PackedStringArray(fatti)),
			m.maschera_indole(PackedStringArray(indole)), m.indice_quirk(quirk), mod)


## Otto 1.0, e poi si muove UNA voce: così ogni caso dice quale azione sta
## guardando invece di far muovere tutto insieme.
func _solo(m, azione: int, valore: float) -> PackedFloat64Array:
	var v := PackedFloat64Array()
	v.resize(8)
	for i in 8:
		v[i] = 1.0
	v[azione] = valore
	return v


func _api(t, m) -> void:
	for nome in ["debug_punteggi", "debug_punteggi_mod", "debug_costanti_agenda"]:
		t.ok(m.has_method(nome), "EcsMondo espone «%s» nel binario" % nome)


## LA RELAZIONE CHE TIENE IN PIEDI TUTTO, e si legge — non si ricorda.
## Entrambi i numeri arrivano dal C++: riscriverne uno qui vorrebbe dire
## avere un test che continua a raccontare una regola dopo che qualcuno
## l'ha cambiata.
func _il_tetto_sta_sotto_il_margine(t, m) -> void:
	var c: Dictionary = m.debug_costanti_agenda()
	t.ok(c.has("delta_max") and c.has("margine"),
			"le costanti dell'innesto si leggono dal C++")
	var dmax := float(c["delta_max"])
	var margine := float(c["margine"])
	t.ok(dmax > 0.0, "il tetto sullo scarto esiste (%s)" % str(dmax))
	t.ok(dmax < margine,
			("il tetto (%s) sta SOTTO il margine d'urgenza (%s): partendo da un "
			+ "pareggio l'emozione non può aprire la corsia che porta T_MIN da "
			+ "%s a %s secondi") % [str(dmax), str(margine),
					str(c["t_min"]), str(float(c["t_min"]) * 0.25)])
	t.eq(int(c["n_azioni"]), 8, "e le azioni sono otto, come i modulatori")


## OTTO 1.0 = NIENTE. Non «quasi niente»: il neutro dev'essere lo stesso
## double, bit per bit, o l'equivalenza dell'agenda cadrebbe — o peggio,
## passerebbe per un pelo oggi e cadrebbe fra sei mesi.
func _il_neutro_e_neutro(t, m) -> void:
	var fatti := ["spuntino_vicino", "amico_in_giro", "aiuola_da_annaffiare",
			"meraviglia_posto", "mattina", "sera_stellata", "regia", "regia_pronta"]
	var uguali := 0
	for b in [VUOTI, PIENI, PackedFloat64Array([0.3, 0.7, 0.1, 0.9, 0.42])]:
		var base := _p(m, b, fatti, ["sognatore", "ordinato"])
		var neutro := _pm(m, b, fatti, ["sognatore", "ordinato"], UNO)
		for i in 8:
			# il confronto è `==` e non `almost`: qui «circa» nasconderebbe
			# proprio la classe di errore che si sta cercando
			if base[i] == neutro[i]:
				uguali += 1
	t.eq(uguali, 24,
			"con otto 1.0 il punteggio è lo STESSO DOUBLE di sempre (24 confronti bit-esatti)")


## IL TETTO, misurato su una spazzata vera: qualunque modulatore, qualunque
## bisogno, lo scarto dal punteggio nudo non passa mai DELTA_MAX. E deve
## SCATTARE almeno una volta, se no è una rete che nessuno tocca.
func _lo_scarto_non_supera_mai_il_tetto(t, m) -> void:
	var dmax := float(m.debug_costanti_agenda()["delta_max"])
	var fatti := ["spuntino_vicino", "amico_in_giro", "aiuola_da_annaffiare",
			"meraviglia_posto", "mattina", "sera_stellata", "regia", "regia_pronta"]
	var caratteri := [[], ["goloso", "ordinato"], ["sognatore"],
			["chiacchierone", "dormiglione"]]
	var mods := [0.0, 0.5, 0.9, 1.0, 1.1, 1.5, 3.0, 50.0]
	var sforati := 0
	var peggiore := 0.0
	var pinzati := 0
	var mossi := 0
	var casi := 0
	for c in caratteri:
		for l in [0.0, 0.25, 0.6, 1.0]:
			var b := PackedFloat64Array([l, l, l, l, l])
			var base := _p(m, b, fatti, c, "canta_alla_luna")
			for a in 8:
				for k in mods:
					var mm := _solo(m, a, k)
					var p := _pm(m, b, fatti, c, mm, "canta_alla_luna")
					casi += 1
					var d: float = absf(p[a] - base[a])
					peggiore = maxf(peggiore, d)
					if d > dmax + 1e-12:
						sforati += 1
					if d >= dmax - 1e-12:
						pinzati += 1
					if d > 0.0:
						mossi += 1
					# e le ALTRE sette non si muovono di un bit: il
					# modulatore è per azione, e se qualcuno leggesse
					# p_mod[0] per tutti questo diventerebbe rosso
					for j in 8:
						if j != a and p[j] != base[j]:
							sforati += 1000
	t.eq(sforati, 0,
			"su %d casi nessuno scarto passa il tetto (il peggiore è %s) e nessuna "
					% [casi, str(peggiore)]
			+ "azione si muove per il modulatore di un'altra")
	t.ok(pinzati > 0,
			"…e il tetto SCATTA davvero (%d casi ci finiscono contro): una rete "
					% pinzati
			+ "che nessun caso tocca non è falsificabile")
	t.ok(mossi > casi / 8,
			"…e il modulatore muove davvero i numeri (%d casi su %d)" % [mossi, casi])


## REGOLA 9 DEL PIANO: il pavimento del mondo batte l'emozione.
##
## Un'aiuola che secca vale 0.9 per CHIUNQUE. Se il modulatore entrasse dopo
## il pavimento, chi ti ama poco la lascerebbe seccare (0.9 − 0.45 = 0.45,
## sotto il piano del Regista) e chi ti ama troppo ci correrebbe a 1.35: la
## cura del giardino smetterebbe di essere una faccenda del MONDO e
## diventerebbe una faccenda di simpatie.
func _il_pavimento_batte_l_emozione(t, m) -> void:
	var fatti := ["aiuola_da_annaffiare"]
	var i_cura: int = m.indice_azione("cura_giardino")
	# cura PIENA: la voglia è zero, resta solo il pavimento
	var freddo := _pm(m, PIENI, fatti, [], _solo(m, i_cura, 0.0))
	var caldo := _pm(m, PIENI, fatti, [], _solo(m, i_cura, 1.5))
	t.almost(freddo[i_cura], 0.9,
			"a chi non ti ama, un'aiuola secca vale comunque 0.9", 1e-12)
	t.almost(caldo[i_cura], 0.9,
			"e a chi ti ammira NON vale di più: sotto il pavimento non si sale", 1e-12)
	t.ok(freddo[i_cura] > 0.75,
			"cioè batte sempre il piano del Regista (0.75), che è il senso del pavimento")
	# ma SOPRA il pavimento il modulatore torna a contare: se non fosse così
	# l'innesto sarebbe spento per quest'azione e nessuno lo direbbe
	var voglioso := PackedFloat64Array([1.0, 1.0, 1.0, 1.0, 0.0])
	var base := _p(m, voglioso, fatti, [])
	var su := _pm(m, voglioso, fatti, [], _solo(m, i_cura, 1.5))
	t.ok(base[i_cura] > 0.9, "con l'aiuola secca E la voglia, si sta sopra il pavimento")
	t.ok(su[i_cura] > base[i_cura],
			"e lì l'ammirazione conta di nuovo (%s → %s)" % [str(base[i_cura]), str(su[i_cura])])


## REGOLA 8 DEL PIANO: `AZ_STELLA` non è una faccenda di simpatie.
##
## `modulatori()` la pinna a 1.0, ma `punteggi()` è una funzione pura e non
## può contare su chi la chiama: anche se un giorno arrivasse un modulatore
## sulla stella, il DNA la spegne comunque. Chi va a letto presto non resta
## a guardare il cielo perché gli sei simpatica.
##
## ONESTÀ SU COSA QUESTO TEST NON SORVEGLIA: non pinza l'ORDINE fra
## l'innesto e lo spegnimento del nottambulo. Con un modulatore
## moltiplicativo i due ordini danno lo stesso double — `0 × qualunque cosa`
## resta zero — e l'ho verificato spostando l'innesto: la suite resta verde.
## È una mutazione EQUIVALENTE, non un buco. Quel che questo caso sorveglia
## è la conseguenza che si vede: la stella spenta resta spenta, e su chi le
## veglia lo scarto è PINZATO (3.45, non 4.5).
func _la_stella_resta_del_cielo(t, m) -> void:
	var i_stella: int = m.indice_azione("stella")
	var sera := ["sera_stellata"]
	var ammirato := _pm(m, PIENI, sera, [], _solo(m, i_stella, 1.5))
	t.almost(ammirato[i_stella], 0.0,
			"nessuna ammirazione tiene sveglio chi non è nottambulo", 1e-12)
	# e sul nottambulo il modulatore c'è, ma pinzato: 3.0 → 3.45, non 4.5
	var notturno := _pm(m, PIENI, sera, ["sognatore"], _solo(m, i_stella, 1.5))
	t.almost(notturno[i_stella], 3.45,
			"e sul nottambulo lo scarto è pinzato: 3.0 + 0.45, non 3.0 × 1.5", 1e-12)


## REGOLA 8: un modulatore non è un veto. A zero, l'azione perde DELTA_MAX e
## resta in gara — il jitter del villaggio arriva a 0.25 e la rimette in
## corsa. Se un mod potesse azzerare, la memoria smetterebbe di inclinare e
## comincerebbe a DECIDERE, e il giocatore si troverebbe vicini che non
## fanno più certe cose senza nessun modo di capire perché.
func _non_e_un_veto(t, m) -> void:
	var i_regia: int = m.indice_azione("regia")
	var fatti := ["regia", "regia_pronta"]
	var base := _p(m, PIENI, fatti, [])
	var spento := _pm(m, PIENI, fatti, [], _solo(m, i_regia, 0.0))
	t.almost(base[i_regia], 0.75, "il piano del Regista vale 0.75", 1e-12)
	t.almost(spento[i_regia], 0.30,
			"e col modulatore a ZERO vale 0.30, non zero: si perde il tetto, non l'azione", 1e-12)
	t.ok(spento[i_regia] > 0.25,
			"…cioè resta sopra il dado del villaggio (0.25), quindi in gara davvero")


## Nessun punteggio può scendere sotto zero, nemmeno con un modulatore
## ostile. Un punteggio negativo perderebbe QUALUNQUE confronto — compreso
## quello con «questa azione non si può fare» — e il corpo resterebbe fermo
## senza che niente si lamenti.
func _niente_punteggi_negativi(t, m) -> void:
	var fatti := ["spuntino_vicino", "amico_in_giro", "aiuola_da_annaffiare",
			"meraviglia_posto", "mattina", "sera_stellata", "regia", "regia_pronta"]
	var ostile := PackedFloat64Array([-5.0, -1.0, -0.001, -1e9, 0.0, -2.0, -0.5, -3.0])
	var sotto := 0
	var nan := 0
	for l in [0.0, 0.3, 0.75, 1.0]:
		var b := PackedFloat64Array([l, l, l, l, l])
		var p := _pm(m, b, fatti, ["goloso", "sognatore"], ostile)
		for i in 8:
			if is_nan(p[i]):
				nan += 1
			elif p[i] < 0.0:
				sotto += 1
	t.eq(nan, 0, "un modulatore ostile non produce NaN")
	t.eq(sotto, 0,
			"…né punteggi negativi: il mod si pinza a zero prima di moltiplicare")


## LA COMPOSIZIONE con `modulatori()`: sei azioni su otto non si muovono
## MAI, e il gioco ci conta. È il collegamento fra i due sistemi, e vale la
## pena provarlo QUI e non solo in `test_occ`: là si prova che il vettore
## esce fatto così, qui che l'agenda ne ricava sei punteggi identici bit per
## bit — che è la cosa da cui dipende l'equivalenza in partita.
func _solo_due_azioni_si_muovono(t, m) -> void:
	var neutro := PackedFloat64Array([1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
	var cost: Dictionary = m.debug_occ(PackedFloat64Array(), neutro, 0.0, {})
	if not cost.has("mod") or not cost.has("su_di_me"):
		t.ok(false, "debug_occ non torna i modulatori: il ponte con l'occ è rotto")
		return
	# un grafo PIENO e caldo: le tinte a fondo scala, cioè il modulatore più
	# grande che il gioco possa produrre
	var ricordi := PackedFloat64Array()
	var verbo_annaffia: int = m.indice_verbo("annaffia")
	var verbo_dona: int = m.indice_verbo("dona")
	var su_di_me := int(cost["su_di_me"])
	for i in 12:
		ricordi.append_array(PackedFloat64Array([float(verbo_annaffia), 0.0, 255.0, 255.0, 0.0]))
	for i in 12:
		ricordi.append_array(PackedFloat64Array([float(verbo_dona), float(su_di_me), 255.0, 255.0, 0.0]))
	var forti := PackedFloat64Array([4.0, 4.0, 4.0, 4.0, 4.0, 4.0])
	var letto: Dictionary = m.debug_occ(ricordi, forti, 0.0, {})
	var mod: PackedFloat64Array = letto["mod"]
	t.eq(mod.size(), 8, "gli otto modulatori escono dall'occ")

	var i_chiacchiere: int = m.indice_azione("quattro_chiacchiere")
	var i_cura: int = m.indice_azione("cura_giardino")
	var fatti := ["spuntino_vicino", "amico_in_giro", "aiuola_da_annaffiare",
			"meraviglia_posto", "mattina", "sera_stellata", "regia", "regia_pronta"]
	var b := PackedFloat64Array([0.2, 0.2, 0.2, 0.2, 0.2])
	var base := _p(m, b, fatti, ["sognatore"])
	var con: PackedFloat64Array = _pm(m, b, fatti, ["sognatore"], mod)
	var fermi := 0
	for i in 8:
		if i != i_chiacchiere and i != i_cura and con[i] == base[i]:
			fermi += 1
	t.eq(fermi, 6,
			"col modulatore VERO al massimo, sei azioni su otto restano lo stesso double")
	t.ok(con[i_chiacchiere] > base[i_chiacchiere],
			"le chiacchiere sì (%s → %s)" % [str(base[i_chiacchiere]), str(con[i_chiacchiere])])
	t.ok(con[i_cura] > base[i_cura],
			"e la cura del giardino pure (%s → %s)" % [str(base[i_cura]), str(con[i_cura])])


## Un modulatore di lunghezza sbagliata si RIFIUTA. Leggere oltre il fondo
## di un array produrrebbe punteggi plausibili e sbagliati: un test scritto
## male dev'essere un test che fallisce, non un test che mente.
func _la_lista_storta_si_rifiuta(t, m) -> void:
	var storta := PackedFloat64Array([1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
	var p: PackedFloat64Array = m.debug_punteggi_mod(VUOTI,
			m.maschera_fatti(PackedStringArray(["spuntino_vicino"])), 0, -1, storta)
	t.eq(p.size(), 0, "sette modulatori per otto azioni: si rifiuta invece di indovinare")


## IL PERCORSO VIVO. `avanza()` è quello che gira in partita, e in questo
## passo dev'essere NEUTRO: il punteggio che il registro sceglie è ancora
## esattamente l'argmax dei punteggi nudi. Non è una ripetizione
## dell'equivalenza — quella prova l'oracolo, questa prova la funzione che
## il gioco chiama davvero, e sono due siti di chiamata diversi.
func _il_percorso_vivo_e_neutro(t, m) -> void:
	var id: int = m.registra(PackedStringArray(["goloso"]), "")
	var b := PackedFloat64Array([0.1, 0.4, 0.3, 0.6, 0.2])
	m.riferisci_bisogni(id, b)
	var fatti_nomi := ["spuntino_vicino", "amico_in_giro", "aiuola_da_annaffiare",
			"meraviglia_posto"]
	m.riferisci_agenda(id, m.maschera_fatti(PackedStringArray(fatti_nomi)), true, false)
	# dado a ZERO: così il punteggio del registro è il punteggio nudo, senza
	# un termine che maschererebbe uno scarto piccolo
	var zero := PackedFloat64Array()
	zero.resize(8)
	m.semina_agenda(id, zero)
	m.avanza(1.0 / 60.0, 0.5)

	var atteso := _p(m, b, fatti_nomi, ["goloso"])
	var best := -1.0
	var chi := -1
	for i in 8:
		if atteso[i] > best:
			best = atteso[i]
			chi = i
	var d: Dictionary = m.debug_agenda(id)
	t.eq(int(d["azione"]), chi,
			"il registro vivo sceglie la stessa azione dell'oracolo")
	t.almost(float(d["punteggio"]), best,
			"…e con lo STESSO punteggio: in P3 il percorso vivo è neutro", 1e-12)
	m.dimentica(id)
