extends RefCounted
## LA POSTA NON INVECCHIA IN UNA LINGUA.
##
## Una lettera si scrive stanotte e si legge domattina, e in mezzo c'è un
## salvataggio su disco — e magari il giocatore che va nelle impostazioni e
## cambia lingua. Se nella coda finisse il testo GIÀ TRADOTTO, quella
## lettera resterebbe per sempre nella lingua in cui è nata: un villaggio
## in inglese con dentro la posta di ieri in italiano, e nessun modo di
## rimediare perché chi l'ha scritta (un vicino che è partito) non c'è più.
##
## Perciò in coda ci va la CHIAVE italiana coi suoi argomenti, e la
## traduzione avviene in un punto solo, `Mail.rendi()`, quando la busta si
## apre. Qui si prova esattamente quello: si mette in coda in italiano, si
## cambia lingua, si legge in inglese.

const L := preload("res://systems/L10n.gd")
const MAIL := preload("res://scenes/interact/Mail.gd")
const PROMESSE := preload("res://scenes/npc/Promesse.gd")
const CRIT := preload("res://scenes/world/Critters.gd")

# una frase che l'inglese conosce di sicuro (è la lettera del Gufo per i
# primi peli d'argento: sta in locale/en/lettere.gd)
const CHIAVE_ARGENTO := "Ho visto i primi peli d'argento\nsul musetto di %s.\nLe stagioni passano anche per noi.\nStagli vicino."


func run(t) -> void:
	var prima := L.lingua_corrente()
	_test_la_lettera_cambia_lingua(t)
	_test_i_dati_dentro_la_lettera_no(t)
	_test_le_forme_composte(t)
	_test_le_lettere_vecchie(t)
	_test_il_giro_del_salvataggio(t)
	_test_nessuno_traduce_prima(t)
	L.imposta(prima)


# ------------------------------------------------- il cuore della cosa

func _test_la_lettera_cambia_lingua(t) -> void:
	# LA SCENA: la si mette in coda col gioco in italiano…
	L.imposta("it")
	var in_coda := {"from_key": "Il Gufo", "text_key": CHIAVE_ARGENTO,
			"args": ["Miele"], "gift": false}
	var italiano := MAIL.rendi(in_coda)
	t.eq(str(italiano["from"]), "Il Gufo", "in italiano il mittente è il Gufo")
	t.ok(str(italiano["text"]).begins_with("Ho visto i primi peli d'argento"),
			"in italiano la lettera è in italiano")

	# …e la si apre col gioco in inglese: DEVE parlare inglese
	L.imposta("en")
	var inglese := MAIL.rendi(in_coda)
	t.eq(str(inglese["from"]), "The Owl", "cambiata lingua, il mittente è tradotto")
	t.ok(not str(inglese["text"]).contains("Ho visto"),
			"la lettera in coda NON resta nella lingua in cui è nata")
	t.ok(str(inglese["text"]) != str(italiano["text"]),
			"la stessa lettera in coda esce in due lingue diverse")
	t.ok(str(inglese["text"]).contains("Miele"),
			"e il nome del vicino resta il suo, in ogni lingua")

	# e torna indietro: non è un cambio a senso unico
	L.imposta("it")
	t.eq(str(MAIL.rendi(in_coda)["text"]), str(italiano["text"]),
			"e si torna in italiano senza aver perso niente")


# ------------------------------------------------- i dati restano dati

func _test_i_dati_dentro_la_lettera_no(t) -> void:
	L.imposta("en")
	# un argomento NUDO è un dato: un nome proprio non si traduce mai,
	# nemmeno per sbaglio, nemmeno se somiglia a una parola in tabella
	var con_nome := {"from_key": "Panchina", "text_key": "Grazie per %s vicino a casa mia!\nOgni mattina gli do il buongiorno.",
			"args": ["Panchina"], "gift": true}
	var vista := MAIL.rendi(con_nome)
	t.ok(str(vista["text"]).contains("Panchina"),
			"un argomento nudo è un DATO e passa intatto (anche se in tabella c'è)")
	# lo stesso valore, dichiarato come frase, invece si traduce
	con_nome["args"] = [{"k": "Panchina"}]
	t.ok(not str(MAIL.rendi(con_nome)["text"]).contains("Panchina"),
			"lo stesso valore in `{\"k\": …}` invece è una frase, e si traduce")


# --------------------------------------------- le frasi a più pezzi

func _test_le_forme_composte(t) -> void:
	L.imposta("en")

	# più capoversi in fila (Mail.componi_lettera, la lettera dei momenti)
	var ricca := MAIL.componi_lettera("il gattino Miele",
			[{"t": "onsen", "d": 12}, {"t": "festa", "d": 20},
			{"t": "piatto", "d": 3}, {"t": "regalo", "d": 4},
			{"t": "onsen", "d": 5}, {"t": "festa", "d": 6}], 0)
	var testo := str(MAIL.rendi(ricca)["text"])
	t.ok(not testo.contains("L'acqua calda"), "la lettera dai momenti esce in inglese")
	t.ok(not testo.contains("E ho contato"),
			"e anche il capoverso in coda, che è un pezzo a sé")
	t.ok(testo.contains("12") and testo.contains("6"),
			"col giorno del momento e il conto del filo")

	# un elenco di chiavi tradotte una per una e unito dopo
	var pacco := {"from_key": "Il Gufo",
			"text_key": {"k": "\nE il pacco contiene: %s. E' tuo.",
					"args": [{"k": ["Panchina", "Letto"], "sep": " · "}]},
			"gift": true}
	var riga := str(MAIL.rendi(pacco)["text"])
	t.ok(riga.contains(" · "), "l'elenco resta un elenco")
	t.ok(not riga.contains("Panchina") and not riga.contains("Letto"),
			"e ogni pezzo è tradotto per conto suo (unire prima, tradurre dopo, non funziona)")

	# le frasi che tornano già rimandate da chi le scrive
	var big: Dictionary = PROMESSE.bigliettino("bruma")
	t.ok(not big.is_empty(), "il bigliettino della bruma esiste")
	t.ok(not L.rendi(big).begins_with("Domattina"),
			"anche il bigliettino della promessa viaggia a chiavi")

	# il nome di una creatura: composto in italiano, tradotto tutto intero
	var fidata := {"from_key": "Gufo",
			"text_key": "Mi dicono che %s\nsi è posata su di te e non è scappata.\nNon si insegna: si aspetta e basta.\nHai imparato il verbo più difficile.",
			"args": [{"k": CRIT.con_articolo_chiave("gialla")}], "gift": false}
	t.ok(str(MAIL.rendi(fidata)["text"]).contains("a golden butterfly"),
			"la creatura arriva con l'articolo inglese giusto")
	L.imposta("it")
	t.ok(str(MAIL.rendi(fidata)["text"]).contains("una farfalla dorata"),
			"…e in italiano col suo")


# ------------------------------------------- la coda dei salvataggi vecchi

func _test_le_lettere_vecchie(t) -> void:
	# Nei salvataggi fatti prima di questo cambio la coda contiene il testo
	# già composto. La sua chiave non esiste più da nessuna parte: non si
	# può ritradurre, e va mostrata com'è — mai una busta vuota, mai un
	# errore, mai il gioco che si rifiuta di aprire una lettera.
	L.imposta("en")
	var vecchia := {"from": "Il Gufo", "text": "Porto con me 42 momenti del nostro filo.",
			"gift": true}
	var vista := MAIL.rendi(vecchia)
	t.eq(str(vista["text"]), "Porto con me 42 momenti del nostro filo.",
			"la lettera vecchia si legge com'è (la sua chiave non esiste più)")
	t.eq(str(vista["from"]), "The Owl",
			"…ma il mittente, che una chiave ce l'ha, si traduce lo stesso")
	t.eq(bool(vista["gift"]), true, "e il regalino non si perde per strada")
	# la busta rotta non deve buttare giù la cassetta
	var rotta := MAIL.rendi({})
	t.eq(str(rotta["text"]), "", "una lettera senza niente dentro non fa danni")
	t.eq(bool(rotta["gift"]), false, "e non regala niente")


# ------------------------------------------ il giro vero: coda -> disco -> coda

func _test_il_giro_del_salvataggio(t) -> void:
	# La coda non resta in memoria: passa da JSON.stringify e torna
	# indietro (BuildSystem._save_village). Nel giro gli interi diventano
	# float — e una lettera che dice «giorno 12.0» sarebbe una lettera
	# rotta. Qui si controlla il giro completo, non la sola resa.
	L.imposta("it")
	var coda := [
		{"from_key": "Il Gufo", "text_key": CHIAVE_ARGENTO, "args": ["Miele"], "gift": false},
		MAIL.componi_lettera("il gattino Miele", [{"t": "onsen", "d": 12}], 0),
		{"from_key": "Il Gufo",
			"text_key": [{"k": "%s\n\nTi lascio %d stelline sul davanzale.",
					"args": [{"k": "Il villaggio ha una piazza."}, 3]},
				{"k": "\nE il pacco contiene: %s. E' tuo.",
					"args": [{"k": ["Panchina"], "sep": " · "}]}],
			"gift": true},
	]
	var rientrata: Array = JSON.parse_string(JSON.stringify(coda))
	t.eq(rientrata.size(), coda.size(), "la coda sopravvive al giro su disco")
	for i in coda.size():
		t.eq(str(MAIL.rendi(rientrata[i])["text"]), str(MAIL.rendi(coda[i])["text"]),
				"la lettera %d è la stessa dopo il salvataggio" % i)
	t.ok(str(MAIL.rendi(rientrata[1])["text"]).contains("12")
			and not str(MAIL.rendi(rientrata[1])["text"]).contains("12.0"),
			"il giorno resta un numero intero (il JSON lo restituisce float)")

	# e dopo il giro cambia lingua lo stesso: è tutto il punto
	L.imposta("en")
	t.ok(not str(MAIL.rendi(rientrata[0])["text"]).contains("Ho visto"),
			"una lettera riletta da disco parla la lingua di oggi")


# ------------------------------------- nessuno traduce prima di mettere in coda

func _test_nessuno_traduce_prima(t) -> void:
	# LA GUARDIA. Sette sistemi scrivono nella cassetta, e la tentazione di
	# tradurre lì (dove la frase si legge meglio) è forte: basta un
	# `"text": L10n.tf(…)` e quella lettera è di nuovo congelata. Qui si
	# guarda il sorgente di chi imbuca, e si pretende la forma a chiavi.
	var re_vecchio := RegEx.create_from_string('"(?:from|text)"\\s*:')
	var colpevoli: Array[String] = []
	var traduttori: Array[String] = []
	for percorso in _chi_imbuca():
		var testo := FileAccess.get_file_as_string(percorso)
		for corpo in _chiamate_a_queue(testo):
			if re_vecchio.search(corpo) != null:
				colpevoli.append(percorso.get_file())
			# e il travestimento: la stessa traduzione anticipata, ma
			# messa sotto il nome nuovo (`"text_key": L10n.t(…)`). La
			# chiave sarebbe già una frase inglese, e domani resterebbe tale
			if corpo.contains("L10n."):
				traduttori.append(percorso.get_file())
	for c in colpevoli:
		t.ok(false, "%s mette in coda \"from\"/\"text\": vanno le chiavi "
				% c + "(\"from_key\"/\"text_key\", vedi Mail.queue_letter)")
	for c in traduttori:
		t.ok(false, "%s traduce mentre imbuca: in coda va la chiave, " % c
				+ "la traduzione la fa Mail.rendi quando si apre la busta")
	t.eq(colpevoli.size(), 0, "nessuno mette più il testo tradotto nella cassetta")
	t.eq(traduttori.size(), 0, "e nessuno chiama L10n mentre imbuca")
	t.ok(_chi_imbuca().size() >= 7,
			"e il controllo guarda davvero tutti quelli che imbucano (%d)"
			% _chi_imbuca().size())


## Gli script che chiamano `queue_letter` (Mail escluso: è la cassetta).
static func _chi_imbuca() -> Array[String]:
	var out: Array[String] = []
	for percorso in _script_di("res://scenes"):
		if percorso.ends_with("/Mail.gd"):
			continue
		var testo := FileAccess.get_file_as_string(percorso)
		if testo.contains("\"queue_letter\""):
			out.append(percorso)
	return out


## Il testo di ogni `…("queue_letter", …)`: si torna indietro fino alla
## parentesi che apre la chiamata e si va avanti fino a quella che la
## chiude. Basta e avanza per vedere con che chiavi è fatto il dizionario,
## senza mettersi a interpretare GDScript. (Prende anche gli
## `has_method("queue_letter")`: dentro non c'è niente da trovare, e un
## controllo che pesca qualche riga in più non fa danni.)
static func _chiamate_a_queue(testo: String) -> Array[String]:
	var out: Array[String] = []
	var da := testo.find("\"queue_letter\"")
	while da >= 0:
		var apre := da
		while apre > 0 and testo[apre] != "(":
			apre -= 1
		var liv := 0
		var i := apre
		while i < testo.length():
			if testo[i] == "(":
				liv += 1
			elif testo[i] == ")":
				liv -= 1
				if liv == 0:
					break
			i += 1
		out.append(testo.substr(apre, i - apre))
		da = testo.find("\"queue_letter\"", maxi(i, da + 1))
	return out


static func _script_di(cartella: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(cartella)
	if dir == null:
		return out
	dir.list_dir_begin()
	var nome := dir.get_next()
	while nome != "":
		var percorso := cartella.path_join(nome)
		if dir.current_is_dir():
			if not nome.begins_with("."):
				out.append_array(_script_di(percorso))
		elif nome.ends_with(".gd"):
			out.append(percorso)
		nome = dir.get_next()
	dir.list_dir_end()
	return out
