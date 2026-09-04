extends RefCounted
## LO SCHEMA DEL SÉ — la potatura che smette di essere un FIFO.
##
## Non è un source-check: si costruiscono `Animo` VERI, si dà loro da
## ricordare più di quaranta cose, e si guarda **che cosa sanno ancora
## dire** — che è l'oracolo giusto, perché `cause()` è il consumatore che
## questa meccanica modifica per definizione.
##
## ⚠️ E l'oracolo NON è la funzione di costo: chiedere a `Schema` se ha
## protetto quello che voleva proteggere è chiedere al giudice se è
## d'accordo con sé stesso.

const SCHEMA := preload("res://scenes/npc/Schema.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")
const CHIBIDNA := preload("res://scenes/npc/ChibiDNA.gd")

## ⚠️ `Animo` è un `RefCounted`: si libera da solo, e chiamare `free()` è
## un errore a runtime che NON fa fallire il test — lo INTERROMPE. La
## prima stesura di questo file lo faceva dentro una lambda, e le liste
## tornavano VUOTE: il caso della divergenza dava «0 contro 0» e sembrava
## un risultato.


func run(t) -> void:
	_il_cancello_e_la_firma(t)
	_la_congruenza_e_il_valore_assoluto(t)
	_le_memorie_che_dicono_chi_sei_resistono(t)
	_a_parita_di_tutto_se_ne_va_il_piu_vecchio(t)
	_il_quarantesimo_uguale_vale_meno_dell_unico(t)
	_gli_intoccabili_non_bloccano_la_potatura(t)
	_la_memoria_resta_limitata(t)
	_il_sommario_dice_ancora_la_verita(t)
	_quello_che_sa_dire_e_cambiato(t)
	_la_leva_del_banco_non_la_accende_nessuno(t)


# ------------------------------------------------------------ attrezzi

func _sk(tipo: String, quando: int, valenza := -0.6, intensita := 0.6,
		congruenza := 0.0) -> Dictionary:
	return {"tipo": tipo, "quando": quando, "valenza": valenza,
			"intensita": intensita, "congruenza": congruenza}


func _animo(seme := 4242, sogno := "artista"):
	var a = ANIMO.new()
	a.setup(CHIBIDNA.generate(seme))
	a.sogno = sogno
	return a


# ------------------------------------------------------------- le guardie

## ⚠️ IL CANCELLO NON È UNA REGOLA, È LA FIRMA. `scheda()` non emette
## l'attore, quindi `costo()` non può pesarlo nemmeno per sbaglio. La
## prova: due ricordi identici in tutto tranne l'attore devono costare
## ESATTAMENTE lo stesso — e la scheda non deve avere quel campo.
func _il_cancello_e_la_firma(t) -> void:
	var compiti: Dictionary = ANIMO.COMPITI
	var a := {"tipo": "taglia_legna", "attore": "giocatore", "quando": 3,
			"valenza": -0.7, "intensita": 0.8}
	var b := {"tipo": "taglia_legna", "attore": "Nocciola", "quando": 3,
			"valenza": -0.7, "intensita": 0.8}
	var sa: Dictionary = SCHEMA.scheda(a, "artista", compiti)
	var sb: Dictionary = SCHEMA.scheda(b, "artista", compiti)
	t.ok(not sa.has("attore"),
			"la scheda NON porta l'attore: la potatura non può pesarlo")
	t.eq(sa, sb, "…e due ricordi che differiscono solo per CHI costano uguale")
	t.almost(SCHEMA.costo([sa], 0, 5, 18.0), SCHEMA.costo([sb], 0, 5, 18.0),
			"anche il costo, cifra per cifra", 0.0)


## LA CONGRUENZA È IL VALORE ASSOLUTO DELL'ALLINEAMENTO: `serve` e
## `tradisce` valgono uguale. Pesarne uno solo darebbe un diario rosa o
## un libro dei torti.
func _la_congruenza_e_il_valore_assoluto(t) -> void:
	var c: Dictionary = ANIMO.COMPITI
	# «taglia_legna» SERVE il boscaiolo e TRADISCE l'artista
	t.almost(SCHEMA.congruenza("taglia_legna", "boscaiolo", c),
			1.0, "il giorno in cui ho fatto la cosa che sognavo", 0.0001)
	t.almost(SCHEMA.congruenza("taglia_legna", "artista", c),
			1.0, "…e quello in cui mi è stato chiesto il contrario", 0.0001)
	t.almost(SCHEMA.congruenza("taglia_legna", "cuoco", c),
			0.0, "un compito che col mio sogno non c'entra non dice chi sono",
			0.0001)
	t.almost(SCHEMA.congruenza("taglia_legna", "", c), 0.0,
			"e senza sogno non c'è schema", 0.0001)
	t.almost(SCHEMA.congruenza("chiacchierata", "artista", c), 0.0,
			"un tipo che non è un compito non ha rapporto col sogno", 0.0001)


## IL CUORE: una memoria auto-definente resiste anche se è VECCHIA,
## RIPETUTA e TIEPIDA — cioè esattamente nelle tre condizioni in cui il
## FIFO la buttava per prima.
func _le_memorie_che_dicono_chi_sei_resistono(t) -> void:
	# ⚠️ LA PRETESA GIUSTA È «A PARITÀ DI TUTTO IL RESTO». Le memorie
	# auto-definenti resistono in modo SPROPORZIONATO, non ASSOLUTO: tre
	# fatti freschi, unici e intensi battono la quarta copia di una
	# routine vecchia e tiepida, e devono — un ricordo che dice chi sei è
	# un episodio singolo e vivido, non una consuetudine. Pretendere il
	# contrario sarebbe una memoria che si fossilizza.
	var pari: Array = [
		_sk("guardia", 8, -0.6, 0.6, 0.0),
		_sk("cucina", 8, -0.6, 0.6, 0.0),
		_sk("taglia_legna", 8, -0.6, 0.6, 1.0),
	]
	var v: int = SCHEMA.indice_da_sacrificare(pari, 12, 18.0)
	t.ok(v >= 0 and float((pari[v] as Dictionary)["congruenza"]) <= 0.0,
			"a parità di età, forza e rarità, a cadere NON è quella che "
			+ "dice chi sono")
	# la CONTROPROVA nello stesso caso: azzerata la congruenza, la scelta
	# torna a essere indifferente e cade la prima
	var senza: Array = []
	for x in pari:
		var c := (x as Dictionary).duplicate()
		c["congruenza"] = 0.0
		senza.append(c)
	t.eq(SCHEMA.indice_da_sacrificare(senza, 12, 18.0), 0,
			"CONTROPROVA: senza schema le tre sono identiche e cade la prima")

	# E LA SPROPORZIONE SI MISURA: quanta anzianità in più regge una
	# memoria congruente prima di essere sacrificata al posto di una che
	# non dice niente. È il numero che dà senso alla parola.
	var regge := 0
	for g in range(0, 200):
		var due: Array = [
			_sk("taglia_legna", 100 - g, -0.5, 0.5, 1.0),
			_sk("guardia", 100, -0.5, 0.5, 0.0),
		]
		if SCHEMA.indice_da_sacrificare(due, 100, 18.0) == 0:
			break
		regge = g
	t.ok(regge >= 18,
			"una memoria che dice chi sei regge %d giornate in più di una "
			% regge + "che non dice niente, prima di essere sacrificata")


## L'ANZIANITÀ RESTA. A parità di tutto il resto se ne va il più vecchio,
## che è la cosa giusta e che il FIFO faceva bene: senza, la memoria si
## fossilizzerebbe sul primo mese e non entrerebbe più niente di nuovo.
func _a_parita_di_tutto_se_ne_va_il_piu_vecchio(t) -> void:
	var schede: Array = []
	for g in [30, 2, 22, 14]:
		schede.append(_sk("dono", g, 0.5, 0.5))
	var v: int = SCHEMA.indice_da_sacrificare(schede, 30, 18.0)
	t.eq(int((schede[v] as Dictionary)["quando"]), 2,
			"a parità di tutto, se ne va il più vecchio")


## LA DISTINTIVITÀ: la quarantesima legna spaccata vale meno dell'unico
## litigio. È il termine che produce la DIVERGENZA fra vicini.
func _il_quarantesimo_uguale_vale_meno_dell_unico(t) -> void:
	var schede: Array = []
	schede.append(_sk("litigio", 10, -0.6, 0.6))
	for k in 9:
		schede.append(_sk("taglia_legna", 10, -0.6, 0.6))
	var v: int = SCHEMA.indice_da_sacrificare(schede, 10, 18.0)
	t.eq(str((schede[v] as Dictionary)["tipo"]), "taglia_legna",
			"fra dieci uguali e uno solo, si sacrifica uno dei dieci")
	# e la controprova: senza repliche, il litigio non è più protetto
	var due: Array = [_sk("litigio", 1, -0.6, 0.6), _sk("dono", 10, 0.6, 0.6)]
	var v2: int = SCHEMA.indice_da_sacrificare(due, 10, 18.0)
	t.eq(str((due[v2] as Dictionary)["tipo"]), "litigio",
			"CONTROPROVA: fra due unici decide il resto, e cade il più vecchio")


## GLI INTOCCABILI SONO POCHI PER COSTRUZIONE: al più uno per tipo di
## compito. Se potessero essere quaranta, la memoria crescerebbe senza
## fine — e `indice_da_sacrificare` tornerebbe -1 per sempre.
func _gli_intoccabili_non_bloccano_la_potatura(t) -> void:
	var schede: Array = []
	# quaranta ricordi TUTTI congruenti, ma di soli tre tipi
	for k in 40:
		var tipi: Array[String] = ["taglia_legna", "guardia", "cucina"]
		schede.append(_sk(tipi[k % 3], k, -0.5, 0.5, 1.0))
	var quanti_intoccabili := 0
	for i in schede.size():
		if SCHEMA.intoccabile(schede, i):
			quanti_intoccabili += 1
	t.eq(quanti_intoccabili, 3,
			"gli intoccabili sono il PRIMO di ogni tipo, e basta")
	t.ok(SCHEMA.indice_da_sacrificare(schede, 40, 18.0) >= 0,
			"…quindi qualcuno si sacrifica sempre")
	# e se davvero fosse tutto intoccabile, si sfora invece di buttare
	var soli: Array = [_sk("taglia_legna", 1, -0.5, 0.5, 1.0)]
	t.eq(SCHEMA.indice_da_sacrificare(soli, 1, 18.0), -1,
			"e con tutto intoccabile si sfora, come fa il filo dei Legami")


## LA MEMORIA RESTA LIMITATA. È l'invariante che il FIFO garantiva
## gratis, e che una potatura per costo può perdere in silenzio.
func _la_memoria_resta_limitata(t) -> void:
	var a = _animo(11, "artista")
	for k in 200:
		a.oggi = int(k / 4)
		var tipi: Array[String] = ["taglia_legna", "guardia", "cucina",
				"chiacchierata", "dono"]
		a.ricorda(tipi[k % 5], "giocatore" if k % 3 == 0 else "Nocciola",
				-0.5 if k % 2 == 0 else 0.4, 0.6)
	t.ok(a.ricordi.size() <= ANIMO.RICORDI_VIVI + 2,
			"dopo duecento fatti i ricordi vivi restano %d (tetto %d)"
			% [a.ricordi.size(), ANIMO.RICORDI_VIVI])


## IL SOMMARIO DICE ANCORA LA VERITÀ. La potatura non cancella un fatto,
## gli toglie la citabilità come episodio: `quante_volte()` deve contare
## tutto, come prima.
func _il_sommario_dice_ancora_la_verita(t) -> void:
	var a = _animo(23, "cuoco")
	for k in 120:
		a.oggi = int(k / 6)
		a.ricorda("taglia_legna", "giocatore", -0.5, 0.6)
	t.eq(a.quante_volte("taglia_legna", "giocatore"), 120,
			"il vicino sa ancora dire quante volte: %d"
			% a.quante_volte("taglia_legna", "giocatore"))


## ⚠️ E LA COSA CHE CONTA DAVVERO: **che cosa sa ancora DIRE**.
## L'oracolo è `cause()`, non la funzione di costo. Due vicini con lo
## stesso identico trattamento ma sogni diversi devono citare episodi
## diversi — è la DIVERGENZA che questa meccanica esiste per produrre, e
## il FIFO non poteva darla perché non guarda chi sei.
func _quello_che_sa_dire_e_cambiato(t) -> void:
	var citati := func(sogno: String) -> Array:
		var a = _animo(77, sogno)
		# lo STESSO trattamento per tutti e due: il giocatore fa quello che
		# fa sempre, più qualche fatto raro
		for k in 90:
			a.oggi = int(k / 5)
			var tipi: Array[String] = ["taglia_legna", "taglia_legna",
					"taglia_legna", "guardia", "suona", "cucina"]
			a.ricorda(tipi[k % 6], "giocatore", -0.62, 0.72)
		var out: Array = []
		for r in a.ricordi:
			out.append(str(r["tipo"]))
		return out
	var boscaiolo: Array = citati.call("boscaiolo")
	var artista: Array = citati.call("artista")
	var conta := func(v: Array, tipo: String) -> int:
		var n := 0
		for x in v:
			if str(x) == tipo:
				n += 1
		return n
	# «suona» SERVE l'artista e TRADISCE il boscaiolo: dice chi sono a
	# tutti e due, ma «guardia» tradisce l'artista e non il boscaiolo
	t.ok(conta.call(artista, "guardia") > conta.call(boscaiolo, "guardia"),
			"chi sogna di fare l'artista si tiene le volte in cui gli è "
			+ "stata chiesta la guardia (%d contro %d): quella lo definisce"
			% [conta.call(artista, "guardia"), conta.call(boscaiolo, "guardia")])
	t.ok(boscaiolo != artista,
			"e con lo STESSO trattamento due vicini con sogni diversi si "
			+ "tengono ricordi diversi — è la divergenza")


## ⚠️ LA LEVA DEL BANCO NON LA ACCENDE NESSUNO. `debug_potatura_fifo`
## rimette la potatura di prima e serve al CONTROLLO di
## `tools/misura_memoria.gd` — le due previsioni sono opposte e si
## misurano appaiate, quindi il termine di paragone dev'essere il vecchio
## codice VERO. Ma una leva che rimette un difetto, dimenticata accesa,
## è il difetto: si scandagliano i sorgenti perché resti spenta.
func _la_leva_del_banco_non_la_accende_nessuno(t) -> void:
	var a = _animo(5, "artista")
	t.eq(a.debug_potatura_fifo, false,
			"di serie la leva è spenta: il gioco pota per schema")
	var accesa := []
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
			var testo := FileAccess.get_file_as_string(via)
			for riga in testo.split("\n"):
				var r := str(riga).strip_edges()
				if r.begins_with("#") or r.begins_with("##"):
					continue
				if r.contains("debug_potatura_fifo") and r.contains("true"):
					fuori.append(via)
		n = d.get_next()
	d.list_dir_end()
