extends RefCounted
## Nascondino nel bosco: il verbo "giocare". La testa del gioco è pura e
## si verifica headless:
##  • i nascondigli scelti sono SPARSI (mai ammucchiati) e deterministici
##    per giorno;
##  • l'assegnazione racconta le indoli: il TIMIDO prende il nascondiglio
##    più lontano dal cercatore, il CHIACCHIERONE il più vicino;
##  • i raggi di scoperta: il timido va scovato (raggio piccolo), il
##    chiacchierone sbuca prima — timido < normale < chiacchierone;
##  • la finestra della proposta è di giorno pieno (mai al tramonto);
##  • filtra_bosco tiene solo il folto (z oltre la soglia);
##  • la risata esiste nel VOCAB del Chibiese, il momento "nascondino"
##    nel Filo Rosso, l'evento nell'asse socievole del Regista;
##  • CozyWorld ha i nascondigli VERI (tronchi/ceppi/massi trattenuti) e
##    monta il gioco;
##  • REGRESSIONE "inspect": la routine non esiste in do_routine — chi
##    la usava non muoveva nessuno; i sistemi devono usare "sniff".

const NASCONDINO := "res://scenes/interact/Nascondino.gd"


func run(t) -> void:
	var s: GDScript = load(NASCONDINO)
	t.ok(s != null and s.can_instantiate(), "Nascondino.gd compila")
	if s == null or not s.can_instantiate():
		return

	_test_sparsi(t, s)
	_test_indoli(t, s)
	_test_raggi(t, s)
	_test_finestra(t, s)
	_test_bosco(t, s)
	_test_vocaboli(t)
	_test_cablaggio(t)
	_test_regressione_inspect(t)


func _spots_finti() -> Array:
	var out: Array = []
	for i in 10:
		out.append({"pos": Vector3(float(i) * 3.0, 0, -25.0 - float(i % 3) * 4.0),
				"tipo": ["tronco", "ceppo", "masso"][i % 3]})
	return out


func _test_sparsi(t, s: GDScript) -> void:
	var scelti: Array = s.scegli_sparsi(_spots_finti(), 3, 7)
	t.eq(scelti.size(), 3, "tre nascondigli scelti")
	var d_min := 1e9
	for i in 3:
		for j in range(i + 1, 3):
			d_min = minf(d_min, (scelti[i]["pos"] as Vector3) \
					.distance_to(scelti[j]["pos"] as Vector3))
	t.ok(d_min >= float(s.DIST_NASCONDIGLI),
			"i nascondigli sono sparsi (min %.1f)" % d_min)
	var ancora: Array = s.scegli_sparsi(_spots_finti(), 3, 7)
	t.eq(str(scelti), str(ancora), "stesso giorno → stessi nascondigli")


func _test_indoli(t, s: GDScript) -> void:
	var cercatore := Vector3.ZERO
	var scelti: Array = s.scegli_sparsi(_spots_finti(), 3, 7)
	var ordinati: Array = s.assegna_per_indole(scelti, cercatore,
			["chiacchierone", "timido", ""])
	t.eq(ordinati.size(), 3, "un posto a testa")
	var d_timido: float = (ordinati[1]["pos"] as Vector3).distance_to(cercatore)
	var d_chiacchierone: float = (ordinati[0]["pos"] as Vector3).distance_to(cercatore)
	var d_terzo: float = (ordinati[2]["pos"] as Vector3).distance_to(cercatore)
	t.ok(d_timido >= d_chiacchierone and d_timido >= d_terzo,
			"il timido si nasconde nel posto PIÙ LONTANO (%.1f)" % d_timido)
	t.ok(d_chiacchierone <= d_terzo,
			"il chiacchierone nel più vicino: tanto si tradisce (%.1f)" % d_chiacchierone)


func _test_raggi(t, s: GDScript) -> void:
	var timido: float = s.raggio_trovato("timido")
	var normale: float = s.raggio_trovato("")
	var chiacchierone: float = s.raggio_trovato("chiacchierone")
	t.ok(timido < normale and normale < chiacchierone,
			"scovare: timido (%.1f) < normale (%.1f) < chiacchierone (%.1f)"
			% [timido, normale, chiacchierone])


func _test_finestra(t, s: GDScript) -> void:
	t.ok(s.finestra_buona(0.4), "a metà giornata si propone")
	t.ok(not s.finestra_buona(0.72), "al tramonto non si comincia più")
	t.ok(not s.finestra_buona(0.1), "e nemmeno nel cuore della notte")
	t.ok(float(s.TRAMONTO) == 0.75, "il tramonto è QUELLO di DayNight (0.75)")


func _test_bosco(t, s: GDScript) -> void:
	var spots := [{"pos": Vector3(0, 0, -30), "tipo": "tronco"},
			{"pos": Vector3(0, 0, -5), "tipo": "ceppo"}]
	var folto: Array = s.filtra_bosco(spots)
	t.eq(folto.size(), 1, "solo il folto del bosco nasconde (z < -18)")
	t.eq(str(folto[0]["tipo"]), "tronco", "…ed è il tronco in fondo al bosco")


func _test_vocaboli(t) -> void:
	var chibiese: GDScript = load("res://audio/Chibiese.gd")
	t.ok((chibiese.VOCAB as Dictionary).has("risata"),
			"la risata esiste nel Chibiese («hi-hi-hi»)")
	var legami: GDScript = load("res://scenes/world/Legami.gd")
	t.ok((legami.TIPI as Dictionary).has("nascondino"),
			"il momento 'nascondino' si annoda sul Filo Rosso")
	var director: GDScript = load("res://scenes/npc/Director.gd")
	var socievole: Array = (director.ASSI as Dictionary)["socievole"]
	t.ok("nascondino" in socievole, "il Regista conta il gioco fra le gentilezze")


func _test_cablaggio(t) -> void:
	var cozy := FileAccess.get_file_as_string("res://scenes/world/CozyWorld.gd")
	t.ok(cozy.contains("func nascondigli()"),
			"CozyWorld espone i nascondigli veri del bosco")
	t.ok(cozy.contains("_log_spots.append") and cozy.contains("_stump_spots.append"),
			"tronchi e ceppi vengono TRATTENUTI quando il bosco nasce")
	t.ok(cozy.contains("Nascondino.gd"), "CozyWorld monta il nascondino")


func _test_regressione_inspect(t) -> void:
	# do_routine conosce solo sniff/bench/fire/wander/confronto: chi passa
	# "inspect" non muove NESSUNO (il match cade nel vuoto). È già successo.
	for percorso in ["res://scenes/interact/Nascondino.gd",
			"res://scenes/interact/Concertino.gd",
			"res://scenes/interact/RichiesteFoto.gd"]:
		var testo := FileAccess.get_file_as_string(percorso)
		t.ok(not testo.contains("do_routine\", \"inspect"),
				"%s non usa la routine-fantasma 'inspect'" % percorso.get_file())