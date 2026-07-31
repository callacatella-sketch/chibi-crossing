extends RefCounted
## IL MENÙ NON SI RIPETE MAI.
##
## Tre leve, e nessuna delle tre produce contenuto nuovo da disegnare:
##   · l'ORA VERA di chi gioca decide la luce (sei momenti);
##   · il CLIMA del villaggio ci si posa sopra (sette) — quarantadue
##     mattine diverse, nessuna disegnata a mano;
##   · e la REGIA fa scadere i mestieri, mette in scena scenette a due e
##     ogni tanto fa passare un ospite.
##
## Sono tutte cose che sbagliano in silenzio: una scenetta che parte nel
## lutto, una rincorsa senza chi scappa, una notte che resta gialla.
## Nessuna di queste rompe il gioco — rompono solo il tono, che è la cosa
## che questo menù esiste per tenere. Quindi si provano una per una.

const ORA := preload("res://scenes/ui/OraDelGiorno.gd")
const REGIA := preload("res://scenes/ui/RegiaDiorama.gd")
const ATTORE := preload("res://scenes/ui/AttoreTitolo.gd")

const CLIMI := ["attesa", "serena", "allegria", "armonia", "malinconia",
		"commiato", "lutto"]
const ALLEGRI := ["rincorre", "scappa", "gioca", "altalena", "saluta"]


func run(t) -> void:
	_test_ogni_ora_ha_il_suo_momento(t)
	_test_le_palette_sono_complete_e_diverse(t)
	_test_la_notte_e_notte(t)
	_test_il_lutto_scolora_a_qualunque_ora(t)
	_test_il_mestiere_nuovo_non_e_mai_quello_di_prima(t)
	_test_niente_rincorse_da_soli(t)
	_test_nel_lutto_solo_la_consolazione(t)
	_test_le_scenette_stanno_nel_cast(t)
	_test_gli_ospiti_al_momento_giusto(t)
	_test_la_scena_cambia_davvero(t)


static func _rng(seme := 1234) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seme
	return r


# ----------------------------------------------------------- l'ora

func _test_ogni_ora_ha_il_suo_momento(t) -> void:
	var conta := {}
	for h in 24:
		var m := ORA.momento(h)
		t.ok(m in ORA.MOMENTI, "le %d in punto hanno un momento vero (%s)" % [h, m])
		conta[m] = int(conta.get(m, 0)) + 1
	t.eq(conta.size(), ORA.MOMENTI.size(),
			"nell'arco delle 24 ore si vedono TUTTI i momenti")
	# l'ora fuori scala non deve inventare niente (fusi, orologi strani)
	for storta in [-3, 24, 47, 100]:
		t.ok(ORA.momento(storta) in ORA.MOMENTI,
				"anche un'ora storta (%d) dà un momento buono" % storta)


func _test_le_palette_sono_complete_e_diverse(t) -> void:
	var chiavi := ["top", "orizz", "terra", "sole", "energia", "amb",
			"angolo", "yaw", "nebbia", "notte"]
	var viste := {}
	for m in ORA.MOMENTI:
		var p: Dictionary = ORA.palette(m)
		for k in chiavi:
			t.ok(p.has(k), "la palette di «%s» ha «%s»" % [m, k])
		t.ok(float(p["energia"]) > 0.0, "«%s» ha una luce accesa" % m)
		viste[str(p["top"]) + str(p["sole"])] = true
	t.eq(viste.size(), ORA.MOMENTI.size(),
			"i sei momenti sono sei cieli DIVERSI (nessun copia-incolla)")


func _test_la_notte_e_notte(t) -> void:
	t.ok(ORA.e_notte(ORA.palette("notte")) > 0.9, "la notte è notte piena")
	t.ok(ORA.e_notte(ORA.palette("sera")) > 0.4, "la sera è già mezza notte")
	t.almost(ORA.e_notte(ORA.palette("mattina")), 0.0, "la mattina no", 0.01)
	t.almost(ORA.e_notte(ORA.palette("pomeriggio")), 0.0, "il pomeriggio no", 0.01)
	# e di notte il sole è più debole di quello di mezzogiorno, sempre
	t.ok(float(ORA.palette("notte")["energia"])
			< float(ORA.palette("pomeriggio")["energia"]) * 0.5,
			"di notte la luce è un'altra cosa, non la stessa abbassata di poco")


## IL LUTTO SCOLORA A QUALUNQUE ORA. È la proprietà che tiene in piedi
## tutto l'incastro fra le due leve: se all'alba (che è rosa e allegra) il
## lutto non riuscisse a spegnere il colore, il giocatore che apre il gioco
## la mattina dopo una perdita si vedrebbe accogliere da una cartolina.
func _test_il_lutto_scolora_a_qualunque_ora(t) -> void:
	for m in ORA.MOMENTI:
		var base: Dictionary = ORA.palette(m)
		var triste: Dictionary = ORA.con_clima(base, "lutto")
		var felice: Dictionary = ORA.con_clima(base, "armonia")
		t.ok(float(triste["sat"]) < 0.6,
				"a «%s» il lutto toglie il colore (sat %.2f)" % [m, triste["sat"]])
		t.ok(float(triste["sat"]) < float(felice["sat"]) * 0.6,
				"…e sta molto sotto all'armonia della stessa ora")
		t.eq(int(triste["petali"]), 0, "a «%s» nel lutto non cadono petali" % m)
		t.ok(float(triste["energia"]) < float(felice["energia"]),
				"e la luce è più bassa che nei giorni pieni")
		# ma NON si spegne: un menù al buio è rotto, non triste
		t.ok(float(triste["energia"]) > 0.0, "a «%s» il lutto non spegne la luce" % m)
	# e ogni clima conserva la forma della palette
	for clima in CLIMI:
		var p: Dictionary = ORA.con_clima(ORA.palette("tramonto"), clima)
		for k in ["top", "sole", "energia", "amb", "sat", "petali", "nebbia"]:
			t.ok(p.has(k), "il clima «%s» non perde «%s»" % [clima, k])


# ---------------------------------------------------------- la regia

func _test_il_mestiere_nuovo_non_e_mai_quello_di_prima(t) -> void:
	var r := _rng()
	for clima in CLIMI:
		for adesso in ATTORE.MESTIERI:
			for giro in 40:
				var n: String = REGIA.mestiere_nuovo(clima, adesso, 3, r)
				t.ok(n != adesso,
						"«%s» non ripesca «%s» (si vedrebbe il loop)" % [clima, adesso])
				t.ok(n in ATTORE.MESTIERI, "«%s» è un mestiere vero" % n)


## UNA RINCORSA SI FA IN DUE. Se non c'è nessun altro libero, chi ha
## finito il suo mestiere non deve mettersi a inseguire il vuoto.
func _test_niente_rincorse_da_soli(t) -> void:
	var r := _rng(99)
	for clima in CLIMI:
		for giro in 120:
			var n: String = REGIA.mestiere_nuovo(clima, "seduto", 0, r)
			t.ok(n not in ["rincorre", "scappa"],
					"senza nessuno libero, «%s» non manda a rincorrere (%s)"
					% [clima, n])
	# …e quando c'è qualcuno, prima o poi ci manda davvero
	var visto := false
	for giro in 400:
		if REGIA.mestiere_nuovo("armonia", "seduto", 4, r) == "rincorre":
			visto = true
			break
	t.ok(visto, "con qualcuno libero, in armonia le rincorse succedono")


## Nel lutto non parte nessuna scenetta allegra — solo la consolazione,
## che in quei giorni è l'unico gesto che non stona.
func _test_nel_lutto_solo_la_consolazione(t) -> void:
	var r := _rng(7)
	var viste := {}
	for giro in 3000:
		var s: String = REGIA.scenetta("lutto", 5, r)
		if s != "":
			viste[s] = true
	for nome in viste:
		t.eq(str(nome), "consolazione",
				"nel lutto l'unica scenetta possibile è la consolazione")
	# e nei giorni pieni ne succedono parecchie, diverse
	var allegre := {}
	for giro in 3000:
		var s: String = REGIA.scenetta("armonia", 5, r)
		if s != "":
			allegre[s] = true
	t.ok(allegre.size() >= 3,
			"in armonia il repertorio è vario (%d scenette diverse)" % allegre.size())
	t.ok(not allegre.has("consolazione"),
			"…e la consolazione non c'entra niente coi giorni pieni")


## Una scenetta non chiede mai più attori di quanti ce ne siano: se lo
## facesse, la regia la metterebbe in scena a metà e resterebbe appesa.
func _test_le_scenette_stanno_nel_cast(t) -> void:
	var r := _rng(31)
	for clima in CLIMI:
		for quanti in range(0, 8):
			for giro in 60:
				var s: String = REGIA.scenetta(clima, quanti, r)
				if s == "":
					continue
				t.ok(REGIA.SCENETTE.has(s), "«%s» è una scenetta vera" % s)
				t.ok(int(REGIA.SCENETTE[s]["attori"]) <= quanti,
						"«%s» non chiede più attori di quanti ce ne sono (%d)"
						% [s, quanti])
	# con un solo vicino non si fa niente in due, mai
	for giro in 300:
		t.eq(REGIA.scenetta("armonia", 1, r), "",
				"con un vicino solo non parte nessuna scenetta")


func _test_gli_ospiti_al_momento_giusto(t) -> void:
	var r := _rng(555)
	var di_giorno := {}
	var di_notte := {}
	for giro in 3000:
		var g: String = REGIA.ospite(0.0, "serena", r)
		if g != "":
			di_giorno[g] = true
		var n: String = REGIA.ospite(1.0, "serena", r)
		if n != "":
			di_notte[n] = true
	t.ok(di_giorno.has("farfalla"), "di giorno passa la farfalla")
	t.ok(not di_giorno.has("stella"), "…e non cadono stelle col sole")
	t.ok(di_notte.has("stella"), "di notte cade qualche stella")
	t.ok(not di_notte.has("farfalla"), "…e le farfalle dormono")
	# nel lutto non passa niente, ed è giusto
	for giro in 2000:
		t.eq(REGIA.ospite(0.0, "lutto", r), "", "nel lutto di giorno non passa niente")
		t.eq(REGIA.ospite(1.0, "lutto", r), "", "e nemmeno di notte")


## LA PROVA CHE LA SCENA CAMBIA. Si fa scadere un mestiere mille volte e
## si guarda quanti ne escono diversi: se la regia ne desse sempre uno o
## due, il menù «evolverebbe» fra le stesse tre pose e sarebbe un loop
## più lungo, non una scena viva.
func _test_la_scena_cambia_davvero(t) -> void:
	var r := _rng(2024)
	for clima in ["serena", "allegria", "armonia"]:
		var visti := {}
		var adesso := "seduto"
		for giro in 1000:
			adesso = REGIA.mestiere_nuovo(clima, adesso, 4, r)
			visti[adesso] = true
		t.ok(visti.size() >= 4,
				"in «%s» la scena passa per almeno quattro mestieri (%d)"
				% [clima, visti.size()])
	# anche nel lutto cambia qualcosa — ma resta dentro il suo registro
	var nel_lutto := {}
	var stato := "veglia"
	for giro in 500:
		stato = REGIA.mestiere_nuovo("lutto", stato, 4, r)
		nel_lutto[stato] = true
	for m in nel_lutto:
		t.ok(str(m) not in ALLEGRI,
				"nel lutto non si arriva mai a «%s», nemmeno cambiando" % m)
	t.ok(nel_lutto.size() >= 2, "ma qualcosa si muove lo stesso")
