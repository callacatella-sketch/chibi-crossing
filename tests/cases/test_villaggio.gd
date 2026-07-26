## Test per IL VILLAGGIO (scenes/npc/Villaggio.gd): il grafo delle relazioni
## e il passaparola.
##
## Qui si verifica la parte più difficile da bilanciare di tutto il sistema:
## che una rivolta collettiva EMERGA da sola, senza che nessuno la scriva, e
## che resti raccontabile. Un villaggio che non si ribella mai è apatico; uno
## che si ribella al primo mugugno è isterico. In mezzo c'è il gioco.

extends RefCounted

const ANIMO := preload("res://scenes/npc/Animo.gd")
const VILLAGGIO := preload("res://scenes/npc/Villaggio.gd")


func run(t) -> void:
	_test_villaggio_sereno(t)
	_test_le_voci_girano(t)
	_test_cascata(t)
	_test_lealta_ferma_la_cascata(t)
	_test_racconto(t)
	_test_niente_fantasmi(t)


func _abitante(nome: String, tratti := {}, sogno := "boscaiolo"):
	var a = ANIMO.new()
	a.setup({"name": nome, "seed": abs(hash(nome)), "sogno": sogno, "tratti": tratti})
	return a


# un villaggio trattato bene NON deve ribellarsi: niente isteria
func _test_villaggio_sereno(t) -> void:
	var v = VILLAGGIO.new()
	for nome in ["Anna", "Bea", "Ciro"]:
		v.aggiungi(_abitante(nome, {}, "boscaiolo"))
	v.lega("Anna", "Bea")
	v.lega("Bea", "Ciro")
	for giorno in 30:
		for nome in v.animi:
			v.animi[nome].esegue("taglia_legna")    # è il loro sogno: va bene
		v.simula_giorno()
	t.eq(v.quanti_oltre("rifiuto"), 0, "chi fa il lavoro che ama non si ribella")
	t.ok(v.tensione() < 0.25, "e il villaggio resta sereno")
	t.ok(str(v.cronaca_rivolta()[0]).contains("sereno"), "e lo sa dire")


# le voci arrivano solo a chi ha legami: il grafo conta davvero
func _test_le_voci_girano(t) -> void:
	var v = VILLAGGIO.new()
	# la scala NON si mette a mano: si guadagna. Le si dà una vera storia di
	# torti, così il gradino alto è coerente col suo stato interno (se lo si
	# forzasse, simula_giorno lo ricalcolerebbe e lo farebbe ridiscendere —
	# ed è giusto così: il sistema non accetta stati inventati).
	var ribelle = _abitante("Rissa",
			{"lealta": 0.0, "orgoglio": 0.9, "codardia": 0.05,
			"grinta": 0.8, "ambizione": 0.9}, "guerriero")
	for giorno in 60:
		ribelle.esegue("taglia_legna")
		if giorno == 20:
			ribelle.lutto("Pepe")
		ribelle.aggiorna_scala()
		ribelle.passa_giorno()
	v.aggiungi(ribelle)
	t.ok(ribelle.gradino > 0, "dopo sessanta giorni così, si è ribellata sul serio")
	v.aggiungi(_abitante("Amica", {"lealta": 0.1}))
	v.aggiungi(_abitante("Estranea", {"lealta": 0.1}))
	v.lega("Rissa", "Amica", 0.9)
	# "Estranea" non è legata a nessuno
	var cronaca: Array = v.simula_giorno()
	var voci := 0
	for c in cronaca:
		if c["tipo"] == "voce":
			voci += 1
	t.ok(voci > 0, "le voci girano fra chi si conosce")
	t.ok(float(v.animi["Amica"].opinione.get("giocatore", 0.0)) < 0.0,
			"l'amica della ribelle peggiora l'opinione sul giocatore")
	t.almost(float(v.animi["Estranea"].opinione.get("giocatore", 0.0)), 0.0,
			"chi non ha legami non sente nulla: il grafo conta")


# LA PROVA DEL NOVE: una cascata che nessuno ha scritto
func _test_cascata(t) -> void:
	var v = VILLAGGIO.new()
	# cinque guerrieri mancati, poco leali, mandati a spaccare legna
	var nomi := ["Uno", "Due", "Tre", "Quattro", "Cinque"]
	for i in nomi.size():
		v.aggiungi(_abitante(nomi[i],
				{"lealta": 0.15, "orgoglio": 0.6, "codardia": 0.2,
				"grinta": 0.6, "ambizione": 0.8}, "guerriero"))
	# tutti si conoscono: il villaggio è piccolo
	for i in nomi.size():
		for j in range(i + 1, nomi.size()):
			v.lega(nomi[i], nomi[j], 0.8)

	var tensione_iniziale: float = v.tensione()
	for giorno in 45:
		for nome in v.animi:
			v.animi[nome].esegue("taglia_legna")
		v.simula_giorno()

	t.ok(v.tensione() > tensione_iniziale + 0.2,
			"la tensione del villaggio è salita davvero (%.2f)" % v.tensione())
	t.ok(v.quanti_oltre("rifiuto") >= 2,
			"più abitanti hanno passato il rifiuto: è una rivolta, non un caso isolato")
	# e la rivolta ha un primo focolaio identificabile
	var f: Dictionary = v.primo_focolaio()
	t.ok(not f.is_empty(), "la rivolta ha un primo focolaio")
	t.ok(f.has("chi") and f.has("giorno"), "con un nome e una data")
	t.ok(str(f["perche"]).length() > 0, "e un motivo")


# la lealtà è la diga: lo stesso villaggio, gente leale, non degenera
func _test_lealta_ferma_la_cascata(t) -> void:
	var v = VILLAGGIO.new()
	var nomi := ["Leale1", "Leale2", "Leale3", "Leale4", "Leale5"]
	for n in nomi:
		v.aggiungi(_abitante(n,
				{"lealta": 0.95, "orgoglio": 0.3, "codardia": 0.3,
				"grinta": 0.6, "ambizione": 0.4}, "guerriero"))
	for i in nomi.size():
		for j in range(i + 1, nomi.size()):
			v.lega(nomi[i], nomi[j], 0.8)
	for giorno in 45:
		for nome in v.animi:
			v.animi[nome].esegue("taglia_legna")
		v.simula_giorno()
	t.ok(v.quanti_oltre("ammutinamento") == 0,
			"un villaggio leale non arriva all'ammutinamento nello stesso tempo")


# la rivolta dev'essere RACCONTABILE: è questa la differenza fra sistema e bug
func _test_racconto(t) -> void:
	var v = VILLAGGIO.new()
	for n in ["Rosa", "Vera"]:
		v.aggiungi(_abitante(n, {"lealta": 0.1, "orgoglio": 0.8, "ambizione": 0.8},
				"guerriero"))
	v.lega("Rosa", "Vera", 0.9)
	for giorno in 40:
		for nome in v.animi:
			v.animi[nome].esegue("taglia_legna")
			if giorno == 15 and nome == "Rosa":
				v.animi[nome].lutto("Pepe")     # e nessuno la consola
		v.simula_giorno()

	var racconto: Array = v.cronaca_rivolta()
	t.ok(racconto.size() >= 2, "la rivolta ha una cronaca")
	t.ok(str(racconto[0]).contains("Ha cominciato"),
			"che dice CHI ha cominciato: la domanda che si farà il giocatore")
	t.ok(str(racconto[0]).contains("giorno"), "e quando")
	var tutto := " ".join(racconto)
	t.ok(tutto.contains("taglia_legna") or tutto.contains("Pepe") or tutto.contains("guerriero"),
			"e il motivo è uno di quelli veri, non una frase generica")


# ---- IL FANTASMA NEL GRAFO ----
# _congeda toglieva il residente da _animi ma NON dal Villaggio: il disertore
# continuava a spettegolare contro il giocatore a ogni simula_giorno e a
# tenere alta la tensione di un posto che aveva già lasciato. Qui si verifica
# che chi parte taccia davvero — e che la sua storia però non vada persa.
func _test_niente_fantasmi(t) -> void:
	var v = VILLAGGIO.new()
	# un ribelle con una storia VERA di torti (la scala si guadagna), più due
	# amici che finora non hanno nulla contro nessuno
	var ribelle = _abitante("Focoso",
			{"lealta": 0.0, "orgoglio": 0.9, "codardia": 0.05, "grinta": 0.8,
			"ambizione": 0.9}, "guerriero")
	for giorno in 60:
		ribelle.esegue("taglia_legna")
		ribelle.aggiorna_scala()
		ribelle.passa_giorno()
	t.ok(ribelle.gradino > 0, "il ribelle si è guadagnato la sua rabbia")
	v.aggiungi(ribelle)
	v.aggiungi(_abitante("Quieto1", {"lealta": 0.2}))
	v.aggiungi(_abitante("Quieto2", {"lealta": 0.2}))
	v.lega("Focoso", "Quieto1", 0.9)
	v.lega("Focoso", "Quieto2", 0.9)

	var tensione_con_lui: float = v.tensione()
	t.ok(tensione_con_lui > 0.0, "finché c'è, la sua rabbia pesa sul villaggio")

	# SE NE VA. Da qui in poi: silenzio da parte sua, storia conservata.
	v.rimuovi("Focoso")
	t.eq(v.animi.size(), 2, "non è più fra gli abitanti")
	t.ok(not v.amicizie.has("Focoso"), "né nel grafo delle amicizie")
	for altro in v.amicizie:
		t.ok(not (v.amicizie[altro] as Dictionary).has("Focoso"),
				"e nessun arco punta più a lui (%s)" % altro)

	var cronaca: Array = v.simula_giorno()
	for c in cronaca:
		if c.get("tipo", "") == "voce":
			t.ok(str(c["da"]) != "Focoso",
					"un disertore non spettegola più: non è un fantasma")
	t.ok(v.tensione() < tensione_con_lui,
			"e la tensione cala: il malanimo di chi è partito non pesa più")

	# ma la STORIA resta: la cronaca sa ancora chi ha acceso la miccia
	var f: Dictionary = v.primo_focolaio()
	t.eq(str(f.get("chi", "")), "Focoso",
			"la cronaca ricorda che è stato lui a cominciare, anche se è partito")
	var racconto := " ".join(v.cronaca_rivolta())
	t.ok(racconto.contains("Focoso"), "e la rivolta ha ancora il suo nome dentro")
	# rimuovere due volte non fa danni
	v.rimuovi("Focoso")
	t.eq(v.animi.size(), 2, "rimuovere chi non c'è più è innocuo")
