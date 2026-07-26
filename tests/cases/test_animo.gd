## Test per l'ANIMO dei chibi (scenes/npc/Animo.gd).
##
## Qui non si verifica che il codice giri: si verifica che il sistema si
## COMPORTI COME UNA PERSONA e che sappia spiegarsi. In particolare che due
## caratteri diversi, davanti allo stesso identico torto, prendano strade
## diverse ma coerenti — e che la catena causale sia ricostruibile, perché è
## quello a fare la differenza fra «è intelligente» e «è un bug».

extends RefCounted

const ANIMO := preload("res://scenes/npc/Animo.gd")


func run(t) -> void:
	_test_nascita_deterministica(t)
	_test_drive(t)
	_test_sogno_tradito(t)
	_test_memoria_aggrega(t)
	_test_scala_non_interruttore(t)
	_test_caratteri_divergono(t)
	_test_perdono(t)
	_test_contagio(t)
	_test_catena_causale(t)
	_test_salvataggio(t)
	_test_dal_genoma_vero(t)
	_test_sfogo(t)


func _chibi(nome: String, tratti := {}, sogno := "boscaiolo"):
	var a = ANIMO.new()
	a.setup({"name": nome, "seed": abs(hash(nome)), "sogno": sogno, "tratti": tratti})
	return a


# ---- il carattere nasce dal genoma e non cambia a ogni avvio ----
func _test_nascita_deterministica(t) -> void:
	var a = _chibi("Nocciola")
	var b = _chibi("Nocciola")
	for tr in ANIMO.TRATTI:
		t.almost(float(a.tratti[tr]), float(b.tratti[tr]),
				"lo stesso genoma dà sempre lo stesso %s" % tr)
	var c = _chibi("Pepe")
	var diverso := false
	for tr in ANIMO.TRATTI:
		if absf(float(a.tratti[tr]) - float(c.tratti[tr])) > 0.01:
			diverso = true
	t.ok(diverso, "genomi diversi danno caratteri diversi")
	t.ok(a.descrizione().contains("Nocciola"), "sa presentarsi")


# ---- le pressioni interne salgono col lavoro e rientrano col riposo ----
func _test_drive(t) -> void:
	var a = _chibi("Miele")
	var fatica0: float = a.malessere("fatica")
	for i in 4:
		a.esegue("taglia_legna")
	t.ok(a.malessere("fatica") > fatica0, "spaccare legna stanca")
	t.ok(a.malessere("noia") > 0.0, "e annoia")
	var dopo: float = a.malessere("fatica")
	a.passa_giorno()
	t.ok(a.malessere("fatica") < dopo, "una notte di riposo rimette in sesto")
	# la polarità è quella dichiarata: sicurezza alta = malessere basso
	a.drive["sicurezza"] = 1.0
	t.almost(a.malessere("sicurezza"), 0.0, "sicurezza piena = nessun malessere")
	a.drive["sicurezza"] = 0.0
	t.almost(a.malessere("sicurezza"), 1.0, "sicurezza a zero = malessere pieno")


# ---- IL CUORE: lo stesso compito brucia in modo diverso secondo il sogno ----
func _test_sogno_tradito(t) -> void:
	var guerriero = _chibi("Zenzero", {}, "guerriero")
	var boscaiolo = _chibi("Castagna", {}, "boscaiolo")
	for i in 12:
		guerriero.esegue("taglia_legna")
		boscaiolo.esegue("taglia_legna")
	var rg: float = guerriero.rancore()
	var rb: float = boscaiolo.rancore()
	t.ok(rg > rb * 2.0,
			"a chi sognava di combattere, spaccare legna brucia molto di più (%.2f vs %.2f)" % [rg, rb])
	t.ok(rb < 0.25, "a chi voleva fare il boscaiolo, invece, quasi non pesa")
	# e chi fa ciò che sogna ci guadagna in stima
	var prima: float = boscaiolo.malessere("stima")
	boscaiolo.esegue("taglia_legna")
	t.ok(boscaiolo.malessere("stima") <= prima + 0.001,
			"fare ciò che si ama non umilia")


# ---- 47 volte è 47 volte, anche quando i ricordi vivi sono finiti ----
func _test_memoria_aggrega(t) -> void:
	var a = _chibi("Cannella", {}, "guerriero")
	for i in 47:
		a.esegue("taglia_legna")
	t.eq(a.quante_volte("taglia_legna"), 47,
			"il chibi sa dire QUANTE volte, non 'qualche volta'")
	t.ok(a.ricordi.size() <= ANIMO.RICORDI_VIVI,
			"i ricordi vivi restano pochi: il resto si fonde nel sommario")
	t.ok(not a.sommario.is_empty(), "e il sommario si è riempito")
	# il rancore satura ma cresce: 47 pesa più di 5
	var molti: float = a.rancore()
	var b = _chibi("Cannella2", {}, "guerriero")
	for i in 5:
		b.esegue("taglia_legna")
	t.ok(molti > b.rancore(), "quarantasette pesano più di cinque")
	t.ok(molti <= 1.0, "ma il rancore non esplode all'infinito")


# ---- la ribellione è una SCALA: si sale un gradino per volta ----
func _test_scala_non_interruttore(t) -> void:
	var a = _chibi("Biscotto", {"lealta": 0.2, "codardia": 0.2, "orgoglio": 0.6}, "guerriero")
	var visti := {}
	for giorno in 60:
		a.esegue("taglia_legna")
		a.aggiorna_scala()
		visti[a.stato()] = true
		a.passa_giorno()
	t.ok(visti.size() >= 3, "ha attraversato più gradini, non è scattato un interruttore")
	t.ok(visti.has("svogliato"), "è passato dal lavoro svogliato")
	t.ok(a.gradino > 0, "e alla fine non è più al lavoro sereno")
	# ogni scatto è UNO solo: il giocatore deve poterlo vedere e rimediare
	for s in a.scatti:
		var da: int = ANIMO.SCALA.find(str(s["da"]))
		var b: int = ANIMO.SCALA.find(str(s["a"]))
		t.ok(absf(float(b - da)) <= 1.0, "si sale (e si scende) un gradino per volta")
	# e ogni gradino si vede addosso
	var tel: Array = a.telegrafo()
	t.eq(tel.size(), 2, "ogni gradino ha una postura e una battuta")
	t.ok(str(tel[1]).length() > 0, "e la battuta non è vuota")


# ---- LA PROVA DEL CARATTERE: stessa storia, persone diverse, strade diverse ----
func _test_caratteri_divergono(t) -> void:
	var codardo = _chibi("Nuvola",
			{"codardia": 0.95, "orgoglio": 0.1, "lealta": 0.2, "grinta": 0.2, "ambizione": 0.5},
			"guerriero")
	var orgoglioso = _chibi("Pepita",
			{"codardia": 0.05, "orgoglio": 0.95, "lealta": 0.2, "grinta": 0.8, "ambizione": 0.5},
			"guerriero")
	for giorno in 70:
		codardo.esegue("taglia_legna")
		orgoglioso.esegue("taglia_legna")
		codardo.aggiorna_scala()
		orgoglioso.aggiorna_scala()
		codardo.passa_giorno()
		orgoglioso.passa_giorno()
	var sc := codardo.soglie()
	var so := orgoglioso.soglie()
	t.ok(float(so["confronto"]) < float(sc["confronto"]),
			"l'orgoglioso ti viene a cercare molto prima del codardo")
	t.ok(float(sc["diserzione"]) < float(sc["confronto"]),
			"il codardo scappa PRIMA di affrontarti: salta il confronto")
	t.ok(float(so["sabotaggio"]) > float(so["confronto"]),
			"l'orgoglioso preferisce lo scontro aperto al sabotaggio alle spalle")
	# e un leale sopporta molto più a lungo
	var leale = _chibi("Loto", {"lealta": 0.95}, "guerriero")
	var sl := leale.soglie()
	t.ok(float(sl["rifiuto"]) > float(so["rifiuto"]),
			"la lealtà alza tutte le soglie: sopporta più a lungo")


# ---- si può rimediare: il rancore non è una condanna ----
func _test_perdono(t) -> void:
	var a = _chibi("Fragolina", {}, "guerriero")
	for i in 20:
		a.esegue("taglia_legna")
	var prima: float = a.rancore()
	t.ok(prima > 0.1, "il torto ha lasciato il segno")
	for i in 8:
		a.ricorda("regalo", "giocatore", 0.8, 0.9)
	t.ok(a.rancore() < prima, "i gesti belli sciolgono il rancore")
	# e anche il tempo aiuta
	var b = _chibi("Vaniglia", {}, "guerriero")
	for i in 20:
		b.esegue("taglia_legna")
	var subito: float = b.rancore()
	for g in 40:
		b.passa_giorno()
	t.ok(b.rancore() < subito, "il tempo attenua (recenza): si può ricominciare")


# ---- il contagio sociale: le voci corrono, la lealtà resiste ----
func _test_contagio(t) -> void:
	var amico = _chibi("Sesamo")
	amico.legami["Pepita"] = 0.9        # si fidano molto
	var op0: float = float(amico.opinione.get("giocatore", 0.0))
	var peso: float = amico.senti_dire("Pepita", "giocatore", -1.0, 1.0)
	t.ok(peso > 0.0, "la voce di un amico attecchisce")
	t.ok(float(amico.opinione["giocatore"]) < op0, "e peggiora l'opinione sul giocatore")

	# da uno sconosciuto (o da chi non si stima) non attecchisce
	var scettico = _chibi("Camomilla")
	scettico.legami["Ignoto"] = -0.5
	t.eq(scettico.senti_dire("Ignoto", "giocatore", -1.0, 1.0), 0.0,
			"da chi non stimi, le voci non attecchiscono")

	# il leale fa da diga: la stessa voce lo scalfisce molto meno
	var leale = _chibi("Mirtillo", {"lealta": 0.95})
	leale.legami["Pepita"] = 0.9
	var sleale = _chibi("Brioche", {"lealta": 0.05})
	sleale.legami["Pepita"] = 0.9
	leale.senti_dire("Pepita", "giocatore", -1.0, 1.0)
	sleale.senti_dire("Pepita", "giocatore", -1.0, 1.0)
	t.ok(float(leale.opinione["giocatore"]) > float(sleale.opinione["giocatore"]),
			"la lealtà fa da diga al pettegolezzo")

	# chi si ribella irradia più di chi mugugna: è così che nasce la cascata
	var mugugno = _chibi("Ciliegia")
	var ribelle = _chibi("Zenzero2")
	ribelle.gradino = ANIMO.SCALA.size() - 1
	t.ok(ribelle.eco() > mugugno.eco(),
			"un ammutinato pesa molto più di uno svogliato")


# ---- LO SCENARIO DEL BRIEF: la catena causale dev'essere ricostruibile ----
func _test_catena_causale(t) -> void:
	# «si è ribellato perché l'ho mandato a tagliare legna 40 giorni di fila
	#  e ho ignorato la morte del suo amico»
	var a = _chibi("Nocciolina",
			{"lealta": 0.25, "orgoglio": 0.8, "codardia": 0.1, "grinta": 0.7, "ambizione": 0.7},
			"guerriero")
	for giorno in 40:
		a.esegue("taglia_legna")
		if giorno == 22:
			a.lutto("Pepe")          # nessuno lo consola: il torto è l'indifferenza
		a.aggiorna_scala()
		a.passa_giorno()

	t.ok(a.gradino >= 3, "dopo quaranta giorni così, si è ribellato davvero")

	var racconto: String = a.racconta()
	t.ok(racconto.contains("taglia_legna"), "il racconto nomina il lavoro ripetuto")
	t.ok(racconto.contains("40") or racconto.contains("39") or racconto.contains("38"),
			"e dice QUANTE volte: è il numero a rendere credibile il rancore")
	t.ok(racconto.contains("guerriero"), "e ricorda che lui sognava altro")

	# la morte dell'amico ignorata dev'essere fra le cause, non persa
	var trovato := false
	for c in a.cause():
		var testo := str(c["testo"])
		if testo.contains("Pepe") or testo.contains("vicino"):
			trovato = true
	t.ok(trovato, "il lutto ignorato è fra le cause: non è stato dimenticato")

	# e il diario racconta la STORIA, non solo lo stato di adesso
	var d: Array = a.diario()
	t.ok(d.size() >= 2, "il diario ha registrato gli scatti, giorno per giorno")
	t.ok(str(d[0]).contains("giorno"), "ogni scatto è datato")

	# un chibi senza torti non ha nulla da rimproverare: niente falsi allarmi
	var sereno = _chibi("Zucchero", {}, "boscaiolo")
	t.ok(sereno.racconta().contains("nulla"), "chi non ha torti non inventa rancori")


func _test_salvataggio(t) -> void:
	var a = _chibi("Ginger", {}, "guerriero")
	for i in 15:
		a.esegue("taglia_legna")
	a.lutto("Pepe")
	a.aggiorna_scala()
	var d: Dictionary = a.save()

	var b = ANIMO.new()
	b.load(d)
	t.eq(b.nome, a.nome, "il nome sopravvive al salvataggio")
	t.eq(b.sogno, a.sogno, "e il sogno")
	t.eq(b.gradino, a.gradino, "e il punto della scala in cui era arrivato")
	t.almost(b.rancore(), a.rancore(), "e il rancore è identico: nessuna amnesia")
	t.eq(b.quante_volte("taglia_legna"), a.quante_volte("taglia_legna"),
			"e ricorda ancora quante volte")


# ---- il cerchio si chiude: il genoma VERO porta sogno e tratti all'animo ----
# Senza questo test il sistema potrebbe essere perfetto e non arrivare mai ai
# residenti veri: è il ponte fra ChibiDNA e Animo, ed è la parte che si rompe
# per prima quando qualcuno tocca il genoma.
func _test_dal_genoma_vero(t) -> void:
	var DNA = load("res://scenes/npc/ChibiDNA.gd")
	var dna: Dictionary = DNA.generate(1234)
	t.ok(dna.has("sogno"), "il genoma porta un sogno")
	t.ok(dna.has("tratti"), "e i cinque tratti")
	t.ok(dna.has("seed"), "e il seme, perché il carattere sia stabile")
	for tr in ANIMO.TRATTI:
		t.ok(dna["tratti"].has(tr), "il genoma ha il tratto %s" % tr)
		var v: float = float(dna["tratti"][tr])
		t.ok(v >= 0.0 and v <= 1.0, "e %s sta fra 0 e 1" % tr)
	t.ok(dna["sogno"] in ANIMO.SOGNI, "il sogno è uno di quelli che il gioco conosce")

	# lo stesso seme dà lo stesso carattere: un residente salvato rinasce identico
	var dna2: Dictionary = DNA.generate(1234)
	t.eq(dna2["sogno"], dna["sogno"], "stesso seme, stesso sogno")
	for tr in ANIMO.TRATTI:
		t.almost(float(dna2["tratti"][tr]), float(dna["tratti"][tr]),
				"stesso seme, stesso %s" % tr)

	# e l'animo li adotta invece di inventarseli
	var a = ANIMO.new()
	a.setup(dna)
	t.eq(a.sogno, str(dna["sogno"]), "l'animo prende il sogno dal genoma")
	for tr in ANIMO.TRATTI:
		t.almost(float(a.tratti[tr]), float(dna["tratti"][tr]),
				"e il tratto %s, senza reinventarlo" % tr)

	# semi diversi danno persone diverse
	var altro: Dictionary = DNA.generate(999)
	var diverso: bool = altro["sogno"] != dna["sogno"]
	for tr in ANIMO.TRATTI:
		if absf(float(altro["tratti"][tr]) - float(dna["tratti"][tr])) > 0.05:
			diverso = true
	t.ok(diverso, "genomi diversi danno caratteri diversi")


# ---- LO SFOGO: ti rinfaccia FATTI, non rabbia generica ----
# È la differenza fra un NPC che urla (dimenticabile) e uno che ti fa sentire
# in colpa (lo racconti agli amici). Se questa frase diventasse generica, il
# sistema perderebbe l'unica cosa che lo rende diverso da un contatore.
func _test_sfogo(t) -> void:
	var a = _chibi("Cannella3",
			{"lealta": 0.2, "orgoglio": 0.9, "codardia": 0.05, "grinta": 0.8, "ambizione": 0.8},
			"guerriero")
	for g in 40:
		a.esegue("taglia_legna")
		if g == 20:
			a.lutto("Pepe")
		a.aggiorna_scala()
		a.passa_giorno()
	var frase: String = a.sfogo()
	t.ok(frase.length() > 20, "lo sfogo è una frase vera")
	t.ok(frase.contains("taglia_legna") or frase.contains("guerriero"),
			"e cita il torto CONCRETO, non una rabbia generica: «%s»" % frase)
	t.ok(frase.contains("40") or frase.contains("39") or frase.contains("41"),
			"col numero delle volte: è il numero a far sentire in colpa")
	# l'orgoglioso apre in modo diverso dal codardo: la stessa storia, due voci
	var codardo = _chibi("Tremolino",
			{"lealta": 0.2, "orgoglio": 0.05, "codardia": 0.95, "grinta": 0.2, "ambizione": 0.8},
			"guerriero")
	for g in 40:
		codardo.esegue("taglia_legna")
		codardo.aggiorna_scala()
		codardo.passa_giorno()
	t.ok(a.sfogo() != codardo.sfogo(),
			"orgoglioso e codardo non ti dicono la stessa cosa")
	t.ok(codardo.sfogo().contains("Scusa") or codardo.sfogo().contains("posso"),
			"il codardo chiede il permesso perfino per lamentarsi")

	# chi non ha torti non ha niente da rinfacciare: nessun falso allarme
	var sereno = _chibi("Zucchero2", {}, "boscaiolo")
	t.ok(sereno.sfogo().contains("niente") or sereno.sfogo().contains("Lascia"),
			"chi sta bene non inventa uno sfogo")
