extends RefCounted
## PROFONDITÀ SENZA FALLIMENTI: la filosofia "nessuno scappa mai" può avere
## lettura e attesa. Questi test tengono in piedi i quattro fronti del
## 2026-07-26:
##  1. pesca: l'ombra grande annuncia il raro, e il raro bussa prima di
##     abboccare (la specie si decide all'ammaraggio, non allo strattone);
##  2. meteo: la nebbiolina del mattino d'autunno ha la sua finestra PURA;
##  3. fame/sete: il languore è morbido (passo più corto, mai una penale)
##     e i vicini se ne accorgono — la premura del villaggio verso Mochi;
##  4. guardaroba: ogni capo nuovo è un ricordo indossabile, e le tabelle
##     (stagioni, archetipi) restano allineate alle loro fonti.

const FISH := preload("res://scenes/interact/Fishing.gd")
const WEA := preload("res://scenes/world/Weather.gd")
const PRE := preload("res://scenes/npc/Premura.gd")
const WAR := preload("res://scenes/characters/Wardrobe.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")


func run(t) -> void:
	_test_ombra_e_bussate(t)
	_test_finestra_della_nebbia(t)
	_test_languore_morbido(t)
	_test_tabelle_del_guardaroba(t)
	_test_builder_dei_capi(t)
	_test_sblocchi_su_istanza(t)
	_test_fili_attaccati(t)


# ------------------------------------------------------------ la pesca

func _test_ombra_e_bussate(t) -> void:
	t.ok(FISH.taglia_ombra(true) > FISH.taglia_ombra(false),
			"l'ombra del raro è più grande: la taglia È l'informazione")
	t.ok(FISH.taglia_ombra(false) > 0.0, "anche il pesce comune ha la sua ombra")


# ------------------------------------------------------------ la nebbia

func _test_finestra_della_nebbia(t) -> void:
	t.ok(WEA.nebbia_del_mattino(2, 0.30, true),
			"mattina d'autunno serena: la nebbiolina c'è")
	t.ok(WEA.nebbia_del_mattino(2, 0.27, true) and WEA.nebbia_del_mattino(2, 0.40, true),
			"la finestra copre tutto il primo mattino")
	t.ok(not WEA.nebbia_del_mattino(2, 0.55, true),
			"il sole alto la scioglie")
	t.ok(not WEA.nebbia_del_mattino(2, 0.30, false),
			"con la pioggia il cielo non è suo")
	for stagione in [0, 1, 3]:
		t.ok(not WEA.nebbia_del_mattino(stagione, 0.30, true),
				"solo d'autunno (stagione %d esclusa)" % stagione)
	t.ok(not WEA.nebbia_del_mattino(2, 0.9, true), "di notte niente nebbiolina")


# ------------------------------------------------------------ il languore

func _test_languore_morbido(t) -> void:
	t.ok(PRE.languida(0.0, 50.0), "pancia vuota = languore")
	t.ok(PRE.languida(50.0, 0.0), "gola secca = languore")
	t.ok(not PRE.languida(10.0, 10.0), "con qualcosa in corpo si cammina normali")
	t.ok(PRE.LENTA > 0.0 and PRE.LENTA < 1.0,
			"il passo languido rallenta senza fermare (%s)" % str(PRE.LENTA))
	t.ok(PRE.LENTA >= 0.7, "morbido davvero: mai una penale che punisce")
	t.ok(PRE.RIFOCILLO > 0.0 and PRE.RIFOCILLO <= 1.0, "il boccone rifocilla con misura")


# ------------------------------------------------------------ il guardaroba

func _test_tabelle_del_guardaroba(t) -> void:
	# ORDER e CAPI devono coincidere nei due sensi: un capo dimenticato
	# dall'elenco sarebbe invisibile nel pannello, per sempre
	t.eq(WAR.ORDER.size(), WAR.CAPI.size(), "ORDER elenca tutti i capi")
	for id in WAR.ORDER:
		t.ok(WAR.CAPI.has(id), "'%s' di ORDER esiste in CAPI" % id)
	for id in WAR.CAPI:
		t.ok(id in WAR.ORDER, "'%s' di CAPI compare in ORDER" % id)
	for id in WAR.CAPI:
		var capo: Dictionary = WAR.CAPI[id]
		for campo in ["nome", "slot", "sblocco", "icona"]:
			t.ok(str(capo.get(campo, "")) != "", "'%s' ha il campo '%s'" % [id, campo])
		t.ok(str(capo["slot"]) in ["testa", "polso", "collo", "corpo"],
				"'%s': slot indossabile (%s)" % [id, capo["slot"]])
	# le stagioni: quattro albe, quattro capi
	t.eq(WAR.STAGIONE_CAPO.size(), 4, "un capo per ogni stagione")
	for id in WAR.STAGIONE_CAPO:
		t.ok(WAR.CAPI.has(id), "il capo di stagione '%s' esiste" % id)
	# gli archetipi: la tabella combacia ESATTAMENTE con ChibiDNA
	t.eq(WAR.ARCHETIPO_CAPO.size(), (DNA.ARCHETYPES as Array).size(),
			"un capo per ogni archetipo del villaggio")
	for arch in DNA.ARCHETYPES:
		t.ok(WAR.ARCHETIPO_CAPO.has(arch),
				"l'archetipo '%s' ha il suo ricordo indossabile" % arch)
		t.ok(WAR.CAPI.has(str(WAR.ARCHETIPO_CAPO[arch])),
				"il capo dell'archetipo '%s' esiste in CAPI" % arch)
	# la soglia dell'amicizia piena vive DOPO la lettera del terzo cuoricino
	t.ok(int(WAR.AMICIZIA_MASSIMA) > 3,
			"l'amicizia piena arriva dopo la lettera del terzo cuoricino")


func _test_builder_dei_capi(t) -> void:
	# ogni capo del catalogo si costruisce davvero (niente match dimenticati)
	var w = WAR.new()
	for id in WAR.ORDER:
		var nodo: Node3D = w._build_capo(str(id))
		t.ok(nodo != null and nodo.get_child_count() > 0,
				"il capo '%s' si costruisce e non è vuoto" % id)
		nodo.free()
	w.free()


func _test_sblocchi_su_istanza(t) -> void:
	# la soglia dell'amicizia la decide il guardaroba, e morde davvero
	var w = WAR.new()
	w.unlock_amicizia("gatto", WAR.AMICIZIA_MASSIMA - 1)
	var salvo: Dictionary = w.save_extra()["wardrobe"]
	t.ok(not ("campanellino_gatto" in (salvo["unlocked"] as Array)),
			"sotto la soglia l'amicizia non basta ancora")
	w.unlock_amicizia("gatto", WAR.AMICIZIA_MASSIMA)
	salvo = w.save_extra()["wardrobe"]
	t.ok("campanellino_gatto" in (salvo["unlocked"] as Array),
			"alla soglia il ricordo entra nel baule")
	w.unlock_amicizia("archetipo_inesistente", 99)
	t.eq((w.save_extra()["wardrobe"]["unlocked"] as Array).size(), 1,
			"un archetipo sconosciuto non sblocca nulla")
	w.free()


# ------------------------------------------------------------ i fili

func _test_fili_attaccati(t) -> void:
	# pesca: la specie si decide all'ammaraggio e l'ombra la annuncia
	t.ok(_body("res://scenes/interact/Fishing.gd", "_launch_bobber")
			.contains("_spawn_preda"), "l'ammaraggio sceglie la preda")
	var preda := _body("res://scenes/interact/Fishing.gd", "_spawn_preda")
	t.ok(preda.contains("_weighted_fish") and preda.contains("rara"),
			"l'ombra nasce dalla specie vera (e dalla sua rarità)")
	t.ok(_body("res://scenes/interact/Fishing.gd", "_start_bite")
			.contains("_bussate"), "il raro bussa prima di abboccare")
	t.ok(_body("res://scenes/interact/Fishing.gd", "_catch").contains("_kind"),
			"lo strattone pesca il pesce annunciato, non un altro")
	t.ok(_body("res://scenes/interact/Fishing.gd", "_cleanup")
			.contains("_free_shadow"), "riavvolgere ripulisce anche l'ombra")
	# meteo: la finestra pura è cablata nel ciclo del Weather
	t.ok(_body("res://scenes/world/Weather.gd", "_process")
			.contains("nebbia_del_mattino"), "il ciclo del meteo interroga la finestra")
	# premura: il nodo esiste in scena e tocca passo e barre
	var tscn := _sorgente("res://scenes/levels/MainLevel.tscn")
	t.ok(tscn.contains("Premura.gd") and tscn.contains("name=\"Premura\""),
			"la Premura è un nodo della scena principale")
	var passo := _body("res://scenes/npc/Premura.gd", "_applica_passo")
	t.ok(passo.contains("set_walk_speed") and passo.contains("set_run_speed"),
			"il languore tocca il passo (e lo restituisce: base * k)")
	var soccorso := _body("res://scenes/npc/Premura.gd", "_porta_un_boccone")
	for filo in ["do_routine", "set_hunger", "set_water"]:
		t.ok(soccorso.contains(filo), "il soccorso arriva fino a '%s'" % filo)
	# guardaroba: i tre momenti chiamano il baule
	t.ok(_body("res://scenes/world/Stargazing.gd", "_confirm_name")
			.contains("cerchietto_stelle"), "la costellazione lascia il cerchietto")
	t.ok(_body("res://scenes/world/Calendar.gd", "throw_party")
			.contains("cappellino_festa"), "la festa lascia il cappellino")
	t.ok(_body("res://scenes/npc/Visitors.gd", "_bump_friend")
			.contains("unlock_amicizia"), "i cuoricini arrivano fino al baule")
	t.ok(_sorgente("res://scenes/characters/Wardrobe.gd")
			.contains("day_changed.connect(_on_alba)"),
			"le albe di stagione arrivano fino al baule")


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""


## Il corpo di una funzione: dal suo `func nome(` alla `func` successiva.
func _body(path: String, fn: String) -> String:
	var src := _sorgente(path)
	var start := src.find("func %s(" % fn)
	if start < 0:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end - start) if end > start else -1)
