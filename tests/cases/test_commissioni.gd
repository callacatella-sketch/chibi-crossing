extends RefCounted
## Le commissioni della lavagna (scenes/npc/Commissioni.gd): il generatore
## PURO guidato da DNA e bestiario, e il MOLTIPLICATORE stagionale — la
## prova che d'autunno si può chiedere la carpa foglia d'oro e d'inverno
## la farfalla di neve (cioè: la lavagna ti manda fuori col retino sotto
## la nevicata). Più i fili del cablaggio: lavagna, consegna, salvataggio.

const COMM := preload("res://scenes/npc/Commissioni.gd")
const CRIT := preload("res://scenes/world/Critters.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")


func run(t) -> void:
	_test_moltiplicatore_stagionale(t)
	_test_generatore(t)
	_test_fili_delle_commissioni(t)


## di_stagione: la finestra vera di ogni specie, meteo compreso.
func _test_moltiplicatore_stagionale(t) -> void:
	t.ok(COMM.di_stagione("foglia", 2), "la carpa foglia d'oro E' d'autunno")
	t.ok(not COMM.di_stagione("foglia", 1), "e d'estate non abbocca")
	t.ok(COMM.di_stagione("neve", 3),
			"la farfalla di neve E' d'inverno (il retino sotto la nevicata!)")
	t.ok(not COMM.di_stagione("neve", 0), "in primavera no")
	t.ok(COMM.di_stagione("bruma", 2), "la farfalla di bruma nelle nebbie d'autunno")
	t.ok(COMM.di_stagione("lucciola", 0) and COMM.di_stagione("lucciola", 3),
			"la lucciola di sempre c'e' in ogni stagione")
	t.ok(COMM.di_stagione("carpetta", 1), "la carpa dorata pure")
	# OGNI stagione ha almeno cinque specie chiedibili: la lavagna non
	# resta mai senza materia stagionale
	for stagione in 4:
		var quante := 0
		for id in CRIT.collezionabili():
			if COMM.di_stagione(str(id), stagione):
				quante += 1
		t.ok(quante >= 5,
				"la stagione %d ha %d specie chiedibili (almeno 5)" % [stagione, quante])


## Il generatore: deterministico, firmato dal DNA, premi sensati.
func _test_generatore(t) -> void:
	var chi := {"label": "il gattino Miele", "nome": "Miele", "sogno": "cuoco"}
	var c1: Dictionary = COMM.genera(42, 2, chi)
	var c2: Dictionary = COMM.genera(42, 2, chi)
	t.eq(str(c1["testo"]), str(c2["testo"]), "stesso seed, stessa richiesta")
	t.eq(str(c1["chi"]), "il gattino Miele", "la richiesta e' firmata")
	t.ok(int(c1["premio"]) > 0, "il premio c'e'")
	t.ok(int(c1["n"]) >= 1, "si chiede almeno un pezzo")
	# cento estrazioni d'autunno: escono SIA creature SIA raccolti, i
	# premi pagano piu' del mercante, e le creature sono di stagione
	var creature := 0
	var raccolti := 0
	for seed_v in 100:
		var c: Dictionary = COMM.genera(seed_v, 2, chi)
		var id := str(c["id"])
		t.ok(CRIT.SPECIE.has(id), "seed %d: '%s' esiste nel bestiario" % [seed_v, id])
		t.ok(int(c["premio"]) > CRIT.vendita(id) * int(c["n"]),
				"seed %d: il desiderio paga piu' del bancone" % seed_v)
		t.ok(str(c["testo"]).length() > 10, "seed %d: il biglietto e' scritto" % seed_v)
		if CRIT.classe(id) == "raccolto":
			raccolti += 1
			t.ok(int(c["n"]) >= 2 and int(c["n"]) <= 4,
					"seed %d: un cestino ragionevole (%d)" % [seed_v, c["n"]])
		else:
			creature += 1
			t.ok(COMM.di_stagione(id, 2),
					"seed %d: la creatura chiesta (%s) esiste in autunno" % [seed_v, id])
			t.eq(int(c["n"]), 1, "seed %d: le creature si chiedono una alla volta" % seed_v)
	t.ok(creature > 20 and raccolti > 20,
			"il menu' e' vario (creature %d, raccolti %d)" % [creature, raccolti])
	# il sogno del DNA firma il testo: il cuoco parla di ricette
	var trovato_cuoco := false
	for seed_v in 60:
		var c3: Dictionary = COMM.genera(seed_v, 1, chi)
		if str(c3["testo"]).contains("ricetta segreta"):
			trovato_cuoco = true
			break
	t.ok(trovato_cuoco, "il sogno 'cuoco' del DNA firma le sue richieste")
	# ogni sogno dell'Animo ha la sua voglia: niente sogni muti
	for sogno in ANIMO.SOGNI:
		t.ok(COMM.VOGLIE.has(str(sogno)),
				"il sogno '%s' ha la sua voce sulla lavagna" % sogno)


## I fili: la lavagna la mostra, la consegna consuma dai canali giusti,
## tutto persiste, la CLI non tocca il salvataggio.
func _test_fili_delle_commissioni(t) -> void:
	var fonte := _sorgente("res://scenes/npc/Commissioni.gd")
	t.ok(fonte.contains("remove_catch"),
			"le creature escono dal barattolo col canale della vendita")
	t.ok(fonte.contains("add_ingredient"),
			"i raccolti escono dalla dispensa")
	t.ok(fonte.contains("\"desiderio\""),
			"la consegna annoda il momento sul Filo Rosso")
	t.ok(fonte.contains("add_nuts"), "e paga in noccioline")
	t.ok(_sorgente("res://scenes/world/Calendar.gd").contains("per_lavagna"),
			"il pannello della lavagna mostra le commissioni")
	t.ok(_sorgente("res://scenes/levels/MainLevel.gd").contains("Commissioni.gd"),
			"le commissioni vivono nella scena principale")


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""
