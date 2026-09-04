## Test per l'ANIMO dei chibi (scenes/npc/Animo.gd).
##
## Qui non si verifica che il codice giri: si verifica che il sistema si
## COMPORTI COME UNA PERSONA e che sappia spiegarsi. In particolare che due
## caratteri diversi, davanti allo stesso identico torto, prendano strade
## diverse ma coerenti — e che la catena causale sia ricostruibile, perché è
## quello a fare la differenza fra «è intelligente» e «è un bug».

extends RefCounted

const ANIMO := preload("res://scenes/npc/Animo.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")


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
	_test_neurochimica_animo(t)


	_il_substrato_dell_assenza(t)
	_quanto_contava_lo_dice_il_libro_mastro(t)
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


# ---- INTEGRAZIONE NEUROCHIMICA: drive -> neuro, ossitocina -> perdono, cortisolo -> tunnel-vision ----
func _test_neurochimica_animo(t) -> void:
	var a = _chibi("Zafferano", {"lealta": 0.8}, "boscaiolo")
	# 1. I BISOGNI SPOSTANO IL PUNTO DI RIPOSO, e il livello ci arriva col tempo
	a.drive["fatica"] = 0.8
	a.sincronizza_neuro()
	t.almost(float(a.limbico.neuro_base["adenosina"]), 0.8,
			"la fatica sposta il PUNTO DI RIPOSO dell'adenosina", 0.05)
	for _p in 150:
		a.limbico.passo_neuro(2.0)
	t.almost(a.limbico.livello_neuro("adenosina"), 0.8,
			"e col tempo il livello ci arriva", 0.05)

	a.drive["appartenenza"] = 0.9
	a.sincronizza_neuro()
	t.ok(float(a.limbico.neuro_base["ossitocina"]) > 0.6,
			"l'appartenenza alza il punto di riposo dell'ossitocina")

	# ⚠️ **E UN IMPULSO SOPRAVVIVE A UNA SINCRONIZZAZIONE.** E' il difetto
	# misurato: `sincronizza_neuro` ASSEGNAVA cinque canali su sette, ed e'
	# chiamata da sei posti (`ricorda` compreso, cioe' da ogni fatto della
	# vita del villaggio). La chiacchierata portava l'ossitocina a 1.0000 e
	# il primo `ricorda()` la riportava a 0.7575: il piatto caldo, l'onsen e
	# la chiacchierata non contavano NIENTE.
	var prima_imp = a.limbico.livello_neuro("ossitocina")
	a.limbico.stimola_neuro("ossitocina", 0.25)
	var dopo_imp = a.limbico.livello_neuro("ossitocina")
	t.ok(dopo_imp > prima_imp + 0.1, "l'impulso si vede subito")
	a.sincronizza_neuro()
	t.almost(a.limbico.livello_neuro("ossitocina"), dopo_imp,
			"e una sincronizzazione NON lo cancella: i drive muovono il riposo, "
			+ "non il livello", 0.0001)

	# ⚠️ E IL CORTISOLO NON SI RI-AGGANCIA SOLO VERSO L'ALTO. Misurato nella
	# scena vera del piatto caldo: un vicino con `sicurezza = 0.30` si
	# svegliava guarito (0.0800), il giocatore gli portava da mangiare, e
	# restava con 0.4400 — il gesto piu' affettuoso del gioco lo lasciava
	# piu' teso di come si era svegliato.
	var b = _chibi("Zafferano2", {}, "boscaiolo")
	b.drive["sicurezza"] = 0.30
	b.sincronizza_neuro()
	var teso := float(b.limbico.neuro_base["cortisolo"])
	t.ok(teso > 0.4, "poca sicurezza alza il punto di riposo del cortisolo (%.3f)" % teso)
	b.drive["sicurezza"] = 0.95
	b.sincronizza_neuro()
	t.ok(float(b.limbico.neuro_base["cortisolo"]) < teso * 0.5,
			"e quando torna la sicurezza il punto di riposo SCENDE: nessun max()")

	# 2. ⚠️ **IL PERDONO NON DIPENDE DA QUANTI AMICI TI HA DATO IL MONDO.**
	#
	# Qui c'era un moltiplicatore dell'ossitocina sullo sconto del rancore, e
	# l'ossitocina la fa l'appartenenza, che a sua volta la fa `_chats` — UNA
	# chiacchierata per volta in tutto il villaggio. Misurato: lo sconto
	# andava da ×1,146 a ×1,596 fra appartenenza 0.10 e 0.90, cioe' **chi il
	# mondo non ha incontrato perdonava meno**. E' la stessa forma della
	# «tassa giornaliera per non essersi visti» che la regola 3 degli Affetti
	# vieta per iscritto.
	#
	# ⚠️ E il caso che lo sorvegliava confrontava **due persone diverse**
	# (`Loto1` e `Loto2`, DNA diversi): misurato, invertendo l'ossitocina il
	# verso della disuguaglianza NON cambiava — a governare era il soggetto.
	# Qui si guarda lo STESSO individuo, che e' l'unico modo di isolare un
	# canale.
	var stesso = _chibi("Loto1", {}, "guerriero")
	for i in 6:
		stesso.esegue("taglia_legna")
	stesso.ricorda("regalo", "giocatore", 0.8, 1.0)
	stesso.limbico.neuro["ossitocina"] = 0.05
	var r_bassa = stesso.rancore()
	stesso.limbico.neuro["ossitocina"] = 0.95
	var r_alta = stesso.rancore()
	t.almost(r_alta, r_bassa,
			"l'ossitocina non tocca il perdono: la chiave e' del giocatore, "
			+ "non dell'appartenenza che il mondo ti ha assegnato", 1e-9)
	t.ok(r_bassa > 0.0, "…e c'e' del rancore da perdonare (%.4f)" % r_bassa)

	# 3. Cortisolo e tunnel-vision decisionale
	var calmo = _chibi("Salvia1")
	var stressato = _chibi("Salvia2")
	stressato.limbico.stimola_neuro("cortisolo", 0.85)
	stressato.drive["fatica"] = 0.95
	var opzioni := ["riposa", "gironzola", "canta"]
	var scelte_stress := {}
	for i in 20:
		var sc := stressato.decide(opzioni, "giocatore", 1.6)
		scelte_stress[sc] = int(scelte_stress.get(sc, 0)) + 1
	t.ok(int(scelte_stress.get("riposa", 0)) >= 18,
			"il cortisolo alto irrigidisce il Softmax creando tunnel-vision sulla routine greedy di sollievo")

	# ⚠️ **MA NON SFONDA UNA SCELTA DI VITA.** Il fattore ×4 si moltiplicava
	# anche per `NITIDEZZA_VITA` (4.5) e dava 18: lo stress rendeva piu'
	# CERTA una decisione che cambia una vita. Misurato su 240 caratteri ×
	# 30 rotture, il ventaglio delle sette risposte crollava dall'87,9% al
	# 25,4%. Il tetto e' fatto di un numero che non e' suo — `NITIDEZZA_VITA`
	# stessa — e questo caso lo misura sul VENTAGLIO, cioe' sulla cosa che
	# quel numero esiste per proteggere.
	var ventaglio := 0
	var quanti := 0
	for seme in 40:
		var chi = _chibi("Ventaglio%d" % seme)
		chi.limbico.neuro["cortisolo"] = 0.95
		var viste := {}
		for giro in 30:
			viste[chi.decide(ANIMO.REAZIONI.keys(), "giocatore",
					ANIMO.NITIDEZZA_VITA)] = true
		quanti += 1
		if viste.size() >= 3:
			ventaglio += 1
	var frazione := float(ventaglio) / float(maxi(1, quanti))
	t.ok(frazione >= 0.80,
			("e sotto stress il carattere da' ancora tre risposte diverse su trenta "
			+ "rotture nel %.0f%% dei casi (mai sotto l'80)") % (frazione * 100.0))

	# 4. Trattieni
	t.ok(calmo.trattieni(), "Animo.trattieni delega correttamente al Limbico")



## ⚠️ **IL SUBSTRATO: quanto pesa ancora cio' che non c'e' piu'.**
##
## Non e' un campo, non e' un bit, non e' una categoria: e' una LETTURA di
## due cose gia' persistite — la recenza dell'ultimo ricordo di perdita e
## quanto e' scavato il senso di appartenenza. E' la meta' su cui poggera'
## tutto il resto, e questo caso tiene le cinque proprieta' che la rendono
## dicibile in un gioco cozy.
func _il_substrato_dell_assenza(t) -> void:
	# --- 1. LA FORMA, pura: due orologi moltiplicati
	t.almost(ANIMO.assenza_da(0, 1.0, 0.0), 1.0,
			"appena successo, e senza radici: pieno", 1e-9)
	t.almost(ANIMO.assenza_da(int(ANIMO.MEZZA_VITA), 1.0, 0.0), 0.5,
			"una mezza vita dopo: la meta'", 1e-9)
	t.almost(ANIMO.assenza_da(0, 1.0, 1.0), 0.0,
			"e con l'appartenenza piena: zero, anche appena successo", 1e-9)
	t.ok(ANIMO.assenza_da(0, 0.2, 0.0) < ANIMO.assenza_da(0, 0.9, 0.0),
			"chi contava di piu' pesa di piu'")
	# monotona nel tempo, in tutte e due le direzioni
	var prec := 2.0
	for g in [0, 3, 9, 18, 40, 90]:
		var v: float = ANIMO.assenza_da(int(g), 1.0, 0.0)
		t.ok(v < prec, "dopo %d giornate pesa meno di prima (%.4f)" % [g, v])
		prec = v
	# e una lunga coda: mesi dopo non e' ancora zero
	t.ok(ANIMO.assenza_da(90, 1.0, 0.0) > 0.0,
			"e mesi dopo non e' ancora zero: la coda e' lunga")

	# --- 2. ⚠️ **A SALVATAGGIO VECCHIO E' ZERO.** Nessuna migrazione,
	#        nessuna chiave nuova: chi non ha una riga «lutto» risponde zero,
	#        e ogni moltiplicatore che ci verra' costruito sopra ha in quello
	#        zero il suo neutro esatto.
	var normale = _chibi("Assenza0")
	t.almost(normale.assenza(), 0.0,
			"un vicino a cui non e' successo niente: esattamente zero", 1e-12)
	for i in 20:
		normale.ricorda("regalo", "giocatore", 0.8, 1.0)
		normale.ricorda("visto", "giocatore", 0.3, 0.5)
	t.almost(normale.assenza(), 0.0,
			"…e resta zero per quanti ricordi qualunque accumuli", 1e-12)

	# --- 3. ⚠️ **IL GIOCATORE NON PUO' CAUSARLA.** `lutto()` incide DUE
	#        righe: «lutto» (la perdita) e «lutto_ignorato» (il rancore
	#        contro chi comanda il villaggio, se nessuno si e' fatto vivo).
	#        Il substrato legge SOLO la prima. Se leggesse la seconda, chi
	#        non ha fatto in tempo a salutare ventisette persone avrebbe
	#        causato lui lo stato che dura.
	# la riga contro il giocatore, DA SOLA: nessuna perdita, solo il rancore
	# per l'indifferenza. Il substrato non deve vederla.
	var ignorato = _chibi("Assenza1")
	ignorato.drive["appartenenza"] = 0.0
	ignorato.ricorda("lutto_ignorato", "giocatore", -0.7, 1.0)
	t.ok(ignorato.ricordi.any(func(r): return str(r.get("tipo", "")) == "lutto_ignorato"),
			"PREMESSA: la riga contro il giocatore c'e' davvero, e l'appartenenza e' a zero")
	t.almost(ignorato.assenza(), 0.0,
			"e il substrato resta ZERO: legge «lutto», mai «lutto_ignorato» — "
			+ "chi non ha fatto in tempo a salutare non ha causato niente", 1e-12)
	# …e la controprova: la riga della PERDITA, sullo stesso vicino, lo apre
	ignorato.ricorda("lutto", "Nocciola", -0.8, 1.0)
	t.ok(ignorato.assenza() > 0.5,
			"mentre la perdita vera si', e di parecchio (%.4f)" % ignorato.assenza())

	# --- 4. CONSOLARE CAMBIA LA PROFONDITA', NON CHI SI APRE. Due vicini
	#        identici, stessa perdita, uno consolato: **la stessa cosa gli e'
	#        successa**, e cambia solo quanto pesa.
	var solo = _chibi("Assenza2")
	var con = _chibi("Assenza3")
	solo.lutto("Malva", "")
	con.lutto("Malva", "Biscotto")
	t.ok(solo.assenza() > 0.0 and con.assenza() > 0.0,
			"a tutti e due e' successa la stessa cosa")
	t.ok(con.assenza() < solo.assenza(),
			"ma a chi e' stato consolato pesa meno (%.4f contro %.4f)"
					% [con.assenza(), solo.assenza()])

	# --- 5. ⚠️ **QUANTO CONTAVA distribuisce il grado.** Senza, una partenza
	#        toccherebbe dodici persone allo stesso identico modo.
	var caro = _chibi("Assenza4")
	var appena = _chibi("Assenza5")
	caro.lutto("Loto", "", 0.9)
	appena.lutto("Loto", "", 0.1)
	t.ok(caro.assenza() > appena.assenza() * 3.0,
			"chi ci teneva davvero porta molto piu' di chi lo conosceva appena "
			+ "(%.4f contro %.4f)" % [caro.assenza(), appena.assenza()])

	# --- 5b. ⚠️ **E SOPRAVVIVE ALLA POTATURA.** `_potatura()` fa `pop_front()`
	#         sopra i quaranta ricordi vivi: in un villaggio vivace la riga
	#         della perdita finisce nel SOMMARIO in poche giornate. Un
	#         substrato che guardasse solo `ricordi` sparirebbe **proprio dove
	#         il villaggio e' pieno di vita**, cioe' dove nessun collaudo
	#         arriva — e la suite resterebbe verde.
	var vivace = _chibi("Assenza7")
	vivace.lutto("Prugna", "")
	var appena_successo := vivace.assenza()
	t.ok(appena_successo > 0.0, "PREMESSA: la perdita pesa (%.4f)" % appena_successo)
	# ⚠️ UNA VITA PIENA E' FATTA DI COSE DIVERSE, non di sessanta volte la
	# stessa. Da quando la potatura non e' piu' un FIFO ma sceglie chi
	# sacrificare (`Schema`), sessanta ripetizioni identiche NON scacciano
	# un lutto: e' unico e intenso, e resiste — che e' la meccanica che
	# funziona, non un difetto. A spingerlo nel sommario e' una vita
	# piena DAVVERO, cioe' fatta di fatti forti e ognuno diverso.
	# (Misurato: con sessanta righe uguali il lutto resta vivo; con
	# sessanta diverse esce, e `assenza()` vale 0.5000 in tutti e due i
	# casi — che e' esattamente cio' che questo caso difende.)
	for i2 in 60:
		vivace.ricorda("evento_%d" % i2, "giocatore", -0.95, 1.0)
	t.ok(not vivace.ricordi.any(func(r): return str(r.get("tipo", "")) == "lutto"),
			"PREMESSA: la riga della perdita e' stata potata via dai ricordi vivi")
	t.almost(vivace.assenza(), appena_successo,
			"e il substrato la trova lo stesso nel sommario: una vita piena non "
			+ "cancella quello che e' successo", 1e-9)

	# --- 6. E LA VITA CHE CONTINUA LO CHIUDE. Non un contatore, non un
	#        traguardo: l'appartenenza che si riempie — da sola col tempo, e
	#        prima se qualcosa succede.
	var passa = _chibi("Assenza6")
	passa.lutto("Cannella", "")
	var subito := passa.assenza()
	for g2 in 8:
		passa.passa_giorno()
	t.ok(passa.assenza() < subito * 0.6,
			"otto giornate dopo pesa molto meno (%.4f contro %.4f)"
					% [passa.assenza(), subito])
	t.ok(passa.assenza() > 0.0, "…ma non e' sparito: non c'e' nessun traguardo")


## ⚠️ **QUANTO CONTAVA LO DERIVA IL VILLAGGIO, non lo scrive nessuno.**
##
## `Congedo` mette in lutto OGNI residente: con l'intensita' scritta a mano
## a 1.0 — com'era — una partenza toccava dodici persone allo stesso identico
## modo, e il substrato si sarebbe aperto su tutte insieme. Il reparto, al
## primo commit. A distribuire il grado non e' una curva inventata: e' il
## libro mastro degli Affetti, letto in assoluto (mai normalizzato sul
## massimo del villaggio — normalizzare su un massimo E' una classifica).
##
## ⚠️ Il finto qui dentro dice **un dato** (quanto vale un legame), non
## reimplementa niente: `lutto_di`, `lutto` e `assenza()` restano quelli del
## gioco. Se `lutto_di` smettesse di chiedere al libro mastro, questo caso
## diventa rosso.
func _quanto_contava_lo_dice_il_libro_mastro(t) -> void:
	var vis = RegistroLutto.new()
	t.stage(vis)
	var caro = ANIMO.new()
	caro.setup(DNA.generate(11))
	var appena = ANIMO.new()
	appena.setup(DNA.generate(22))
	(vis.get("_animi") as Dictionary)["C"] = caro
	(vis.get("_animi") as Dictionary)["A"] = appena
	vis.legami = {"C": 0.90, "A": 0.05}

	vis.lutto_di("C", "Loto", "")
	vis.lutto_di("A", "Loto", "")
	t.ok(caro.assenza() > 0.0 and appena.assenza() > 0.0,
			"a tutti e due e' successa la stessa cosa")
	t.ok(caro.assenza() > appena.assenza() * 3.0,
			("ma il grado nasce distribuito dal libro mastro: %.4f contro %.4f")
					% [caro.assenza(), appena.assenza()])


## Il registro VERO, col solo `_ready` scavalcato, e una sola fonte di dati
## dettata: quanto vale un legame. Tutto il resto e' il gioco.
class RegistroLutto extends "res://scenes/npc/Visitors.gd":
	var legami := {}

	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

	func _process(_d: float) -> void:
		pass

	func affetto_fra(a: String, _b: String) -> float:
		return float(legami.get(a, 0.0))

	func label_di_nome(_n: String) -> String:
		return "X"
