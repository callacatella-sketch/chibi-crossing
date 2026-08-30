extends RefCounted
## TRE MOTORI CHE GIRAVANO A VUOTO.
##
## Il difetto peggiore di un progetto grande non è il codice rotto: è il
## codice GIUSTO che non chiama nessuno. Passa i test, sembra vivo nel
## salvataggio, e non tocca il gioco di una virgola. Qui stanno le
## guardie dei tre che erano staccati:
##
##  1. `Animo.decide()` — la scelta pesata (softmax) con cui un vicino
##     decide da sé cosa fare. Zero chiamanti: i residenti senza
##     incarico non facevano niente di loro iniziativa.
##  2. `Limbico.visita_serena()` — la porta per guarire un trauma. Zero
##     chiamanti, e per costruzione irraggiungibile: chi evita un posto
##     non ci torna mai, quindi la paura non si spegneva più.
##  3. Le manopole della vignetta — quattro uniform che nessuno scriveva:
##     la carta restava congelata sui valori di fabbrica.

const ANIMO := preload("res://scenes/npc/Animo.gd")
const CARTA := preload("res://scenes/world/Carta.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")


func run(t) -> void:
	_test_decide_e_acceso(t)
	_test_guarigione_raggiungibile(t)
	_test_carta_respira(t)


# ------------------------------------------------- 1. la scelta libera

func _test_decide_e_acceso(t) -> void:
	var lav := _sorgente("res://scenes/npc/Lavori.gd")
	t.ok(lav.contains("animo.decide("),
			"il registro fa DECIDERE chi non ha un incarico")
	var corpo := _corpo(lav, "_scelte_di_giornata")
	t.ok(corpo.contains("_incarichi.has(label)"),
			"decide solo chi è LIBERO: gli ordini del giocatore vincono")
	# ⚠️ **QUESTA GUARDIA MATCHAVA IL PROPRIO COMMENTO.** Cercava la stringa
	# `"se_stesso"` nel sorgente — e c'era, dentro `decide()` — mentre la riga
	# finiva poi in `Visitors.assegna_compito`, che la incideva contro il
	# GIOCATORE. MISURATO nel salvataggio vero: tutte e settantotto le righe
	# di compito intestate a lui, con il registro degli incarichi vuoto.
	# Adesso si guarda il RICORDO, non il sorgente.
	var chi = ANIMO.new()
	chi.setup(DNA.generate(4242))
	chi.esegue("taglia_legna", "se_stesso")
	t.eq(chi.quante_volte("taglia_legna", "se_stesso"), 1,
			"una giornata scelta da se' resta scritta come SUA")
	t.eq(chi.quante_volte("taglia_legna", "giocatore"), 0,
			"…e non come una richiesta di chi comanda il villaggio")

	# ⚠️ **E IL CABLAGGIO VA ATTRAVERSATO, o si prova solo l'API.** La prima
	# stesura di questa guardia chiamava `Animo.esegue` diretto: le due
	# mutazioni che rimettono il difetto — l'ordinante cablato dentro
	# `assegna_compito`, e `Lavori` che smette di passarlo — la lasciavano
	# **verde tutte e due**. Qui si passa dalle funzioni vere.
	var vis = RegistroCompiti.new()
	t.stage(vis)
	var libero = ANIMO.new()
	libero.setup(DNA.generate(77))
	(vis.get("_animi") as Dictionary)["L"] = libero
	vis.assegna_compito("L", "taglia_legna", "se_stesso")
	t.eq(libero.quante_volte("taglia_legna", "se_stesso"), 1,
			"`assegna_compito` incide l'ordinante che gli si passa")
	vis.assegna_compito("L", "taglia_legna")
	t.eq(libero.quante_volte("taglia_legna", "giocatore"), 1,
			"…e di serie resta il giocatore, come una richiesta vera")

	# …e il registro dei lavori lo passa DAVVERO, per chi non ha un incarico
	var reg_lav = RegistroLavori.new()
	t.stage(reg_lav)
	reg_lav.set("_visitors", vis)
	(vis.get("_residents") as Array).append({"label": "L"})
	vis.ordinanti.clear()
	reg_lav._scelte_di_giornata()
	t.ok(vis.ordinanti.has("se_stesso"),
			"e chi non ha un incarico si sceglie la giornata da se': "
			+ "nel suo ricordo resta cosi' (%s)" % str(vis.ordinanti))
	t.ok(not vis.ordinanti.has("giocatore"),
			"…e non come una richiesta che nessuno gli ha fatto")


	t.ok(_corpo(lav, "_on_nuovo_giorno").contains("_scelte_di_giornata"),
			"e succede ogni mattina")
	t.ok(_sorgente("res://scenes/npc/Visitors.gd").contains("func animo_oggetto_di"),
			"Visitors passa l'animo vivo a chi lo deve far decidere")

	# il motore in sé: la scelta è pesata, non un sorteggio, e resta
	# dentro il vocabolario dei compiti
	var a = ANIMO.new()
	a.setup({"name": "Prova", "seed": 7,
			"sogno": "boscaiolo", "tratti": {}, "weights": {}})
	var azioni: Array = ANIMO.COMPITI.keys()
	var conteggio := {}
	for i in 200:
		var s := str(a.decide(azioni, "se_stesso"))
		t.ok(s in azioni, "decide() resta nel vocabolario dei compiti")
		conteggio[s] = int(conteggio.get(s, 0)) + 1
	t.ok(conteggio.size() >= 2,
			"la scelta è PESATA, non fissa: %d compiti diversi su 200 giri"
			% conteggio.size())
	t.ok(conteggio.size() <= azioni.size(),
			"…e nemmeno un sorteggio piatto su tutto")
	t.eq(str(a.decide([], "se_stesso")), "",
			"senza azioni non inventa nulla")


# --------------------------------------------- 2. la porta della cura

func _test_guarigione_raggiungibile(t) -> void:
	var vis := _sorgente("res://scenes/npc/Visitors.gd")
	t.ok(vis.contains("visita_serena"),
			"la porta per guarire un trauma ha finalmente un chiamante")
	var filtro := _corpo(vis, "_filtra_luogo")
	t.ok(filtro.contains("_player") and filtro.contains("distance_to"),
			"si apre quando il giocatore è ACCANTO: è lui la cura")
	var i_guardia := filtro.find("distance_to")
	var i_ripiego := filtro.find("return RIPIEGO")
	t.ok(i_guardia >= 0 and i_ripiego > i_guardia,
			"…e la cura viene PRIMA del ripiego, o non si raggiungerebbe mai")

	# il motore: una visita serena dimezza la carica, e bastano poche
	# volte perché il posto torni un posto qualunque
	var LIMB := load("res://scenes/npc/Limbico.gd")
	var l = LIMB.new()
	for i in 6:
		# `senti()` NON ESISTE in Limbico: il metodo vero è `rivaluta`. La
		# chiamata sbagliata sollevava un errore che INTERROMPEVA il resto
		# di questa funzione — cioè proprio la prova che la guarigione di un
		# trauma è raggiungibile — e la suite restava verde, perché un
		# errore a runtime non fa fallire niente.
		l.rivaluta("morso", "", -0.9, "orto")
	var evitava: bool = l.evita("orto")
	t.ok(evitava, "sei brutte esperienze e il posto diventa insopportabile")
	var giri := 0
	while l.evita("orto") and giri < 30:
		l.visita_serena("orto")
		giri += 1
	t.ok(not l.evita("orto"),
			"tornarci in compagnia lo guarisce (in %d visite)" % giri)
	t.ok(giri <= 8, "e non serve una vita: %d visite" % giri)
	# su un posto mai marchiato non fa nulla e non esplode
	l.visita_serena("posto_mai_visto")
	t.ok(true, "una visita a un posto senza marchio non rompe niente")


# ------------------------------------------------- 3. la carta viva

func _test_carta_respira(t) -> void:
	# il cablaggio: prima le manopole non le scriveva NESSUNO
	t.ok(_sorgente("res://scenes/levels/MainLevel.gd").contains("Carta.gd"),
			"il regista della carta vive nella scena principale")
	var c := _sorgente("res://scenes/world/Carta.gd")
	for manopola in ["strength", "calore", "grana", "tint"]:
		t.ok(c.contains("set_shader_parameter(\"%s\"" % manopola),
				"la manopola '%s' viene scritta davvero" % manopola)

	# i default dichiarati qui devono COMBACIARE con quelli dello shader,
	# o alla prima scrittura l'immagine salterebbe
	var sh := _sorgente("res://shaders/vignette.gdshader")
	t.ok(sh.contains("strength : hint_range(0.0, 1.0) = 0.24"),
			"strength: stesso valore di fabbrica di qua e di là")
	t.ok(sh.contains("grana : hint_range(0.0, 0.2) = 0.045"),
			"grana: idem")
	t.ok(sh.contains("calore : hint_range(0.0, 1.0) = 0.5"),
			"calore: idem")

	# LA MATEMATICA, pura: si prova a ogni ora e in ogni stato
	var sereno := {"ora": 0.5, "notte": false, "pioggia": false,
			"nebbia": false, "lutto": false, "festa": false}
	var m: Dictionary = CARTA.manopole(sereno)
	t.almost(float(m["strength"]), 0.24, "mezzogiorno sereno: la carta di sempre", 0.02)

	# l'oro delle sei: al tramonto si scalda e chiude un filo
	var tramonto := sereno.duplicate()
	tramonto["ora"] = 0.75
	var mt: Dictionary = CARTA.manopole(tramonto)
	t.ok(float(mt["calore"]) > float(m["calore"]) + 0.2,
			"al tramonto la carta si SCALDA (%.2f contro %.2f)"
			% [mt["calore"], m["calore"]])
	t.ok(float(mt["strength"]) > float(m["strength"]),
			"…e chiude un filo di più, come un'illustrazione")
	# e all'alba lo stesso: sono due campane, non una
	var alba := sereno.duplicate()
	alba["ora"] = 0.26
	t.ok(float((CARTA.manopole(alba) as Dictionary)["calore"])
			> float(m["calore"]) + 0.2, "e all'alba pure")

	# la notte stringe e raffredda
	var notte := sereno.duplicate()
	notte["ora"] = 0.95
	var mn: Dictionary = CARTA.manopole(notte)
	t.ok(float(mn["strength"]) > float(m["strength"]),
			"di notte il buio stringe l'inquadratura")
	t.ok(float(mn["calore"]) < float(m["calore"]),
			"…e il bruno si raffredda")

	# IL LUTTO: il gradino che conta. Si sente, non si annuncia.
	var lutto := sereno.duplicate()
	lutto["lutto"] = true
	var ml: Dictionary = CARTA.manopole(lutto)
	t.ok(float(ml["strength"]) > float(m["strength"]) + 0.1,
			"nel lutto l'inquadratura si CHIUDE (%.2f contro %.2f)"
			% [ml["strength"], m["strength"]])
	t.ok(float(ml["calore"]) < float(m["calore"]) - 0.2,
			"…e si spegne il calore")
	t.ok(float(ml["grana"]) > float(m["grana"]),
			"…e la grana della carta affiora")

	# LA FESTA fa l'opposto esatto: la carta si apre
	var festa := sereno.duplicate()
	festa["festa"] = true
	var mf: Dictionary = CARTA.manopole(festa)
	t.ok(float(mf["strength"]) < float(m["strength"]),
			"a festa la carta si APRE")
	t.ok(float(mf["calore"]) > float(m["calore"]), "…e si scalda")

	# la pioggia inumidisce
	var pioggia := sereno.duplicate()
	pioggia["pioggia"] = true
	var mp: Dictionary = CARTA.manopole(pioggia)
	t.ok(float(mp["grana"]) > float(m["grana"]) and float(mp["calore"]) < float(m["calore"]),
			"sotto la pioggia la carta si inumidisce")

	# NIENTE ESCE DAI BINARI, in nessuna combinazione: fuori dagli
	# hint_range Godot taglierebbe in silenzio e la manopola mentirebbe
	var fuori := 0
	for i in 25:
		for lu in [false, true]:
			for fe in [false, true]:
				for pi in [false, true]:
					var ctx := {"ora": float(i) / 24.0, "notte": i > 18,
							"pioggia": pi, "nebbia": false, "lutto": lu, "festa": fe}
					var v: Dictionary = CARTA.manopole(ctx)
					if float(v["strength"]) < 0.0 or float(v["strength"]) > 1.0 \
							or float(v["calore"]) < 0.0 or float(v["calore"]) > 1.0 \
							or float(v["grana"]) < 0.0 or float(v["grana"]) > 0.2:
						fuori += 1
	t.eq(fuori, 0, "in 200 combinazioni nessuna manopola esce dal suo hint_range")


func _corpo(src: String, nome: String) -> String:
	var da := src.find("func " + nome)
	if da < 0:
		return ""
	var fine := src.find("\nfunc ", da + 1)
	return src.substr(da, (fine - da) if fine > da else -1)


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""


## Un registro che REGISTRA. `assegna_compito` resta quella del gioco.
class RegistroCompiti extends "res://scenes/npc/Visitors.gd":
	var ordinanti: Array = []

	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

	func _process(_d: float) -> void:
		pass

	func assegna_compito(label: String, compito: String, ordinante := "giocatore") -> void:
		ordinanti.append(ordinante)
		super(label, compito, ordinante)

	func e_cucciolo(_l: String) -> bool:
		return false

	func animo_oggetto_di(label: String):
		return (get("_animi") as Dictionary).get(label)




## Il registro dei lavori VERO, col solo `_ready` scavalcato.
class RegistroLavori extends "res://scenes/npc/Lavori.gd":
	func _ready() -> void:
		set_process(false)
