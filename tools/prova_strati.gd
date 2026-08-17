extends SceneTree
## USA E GETTA — la prova VIVA della Stratigrafia (progetto §5.2), nel
## MainLevel VERO: Scavi, Strati, BuildSystem, Visitors, Legami e Inventory
## quelli del gioco, persistenza spenta.
##
##   Godot --headless --path . --script res://tools/prova_strati.gd
##
## Il lato puro è già coperto headless da test_strati; qui si prova ciò che
## SOLO la scena vera può dire:
##   (a) le righe iniettate con g = oggi−1 fanno nascere AL PIÙ un
##       luccichio in più in Scavi._rigenera, con gli ostacoli veri;
##   (b) lo scavo consegna DAVVERO: il tesoro nelle Tasche e il momento
##       «reperto» sul filo NELLO STESSO FRAME dello scavo (l'accredito è
##       atomico con estratto: un salvataggio a metà volo non perde più il
##       reperto), e a fine volo il toast del reperto — che SOVRASCRIVE
##       quello dei Legami («il filo si colora») ed esce con la grammatica
##       giusta (label da soggetto, mai «Era di il gattino»);
##   (c) debug_clear NON seppellisce (l'harness non è il giocatore);
##   (d) debug_remove_edge idem;
##   (e) su un giorno di CONFINE di stagione il replay di season_changed
##       (il load) non deposita doppioni: UNA sola riga stagione per quel g;
##   (f) demolire due volte lo stesso pezzo con _try_remove lascia UNA
##       riga («la trave del PRIMO ponte»).

const STRATI_S := preload("res://scenes/world/Strati.gd")
const SCAVI_S := preload("res://scenes/interact/Scavi.gd")
const DN_S := preload("res://scenes/world/DayNight.gd")

var _guasti := 0


func _init() -> void:
	_go()


func _dico(ok: bool, testo: String) -> void:
	if not ok:
		_guasti += 1
	print(("  ok    " if ok else "  GUASTO ") + testo)


## Le prime N celle del prato buone per una sepoltura ADESSO: dentro il
## RECT, fuori dagli ostacoli veri, senza copertura. Il filtro extra
## (Callable) serve al punto (a) per stare lontani dai punti del giorno.
func _celle_libere(cozy: Node, build: Node, quante: int,
		extra := Callable()) -> Array:
	var ostacoli: Array = cozy.call("obstacle_circles")
	var out: Array = []
	for x in range(-12, 13):
		for z in range(-14, 8):
			var c := [x, z]
			if not STRATI_S.valida_cella(c, ostacoli):
				continue
			if bool(build.call("has_cover", Vector2i(x, z))):
				continue
			if extra.is_valid() and not bool(extra.call(c)):
				continue
			out.append(c)
			if out.size() >= quante:
				return out
	return out


func _righe_stagione_di(strati: Node, g: int) -> int:
	var n := 0
	for r in strati.get("_strati"):
		if r is Dictionary and str((r as Dictionary).get("tipo", "")) == "stagione" \
				and int((r as Dictionary).get("g", 0)) == g:
			n += 1
	return n


func _azzera(strati: Node) -> void:
	strati.set("_strati", [])
	strati.set("_g_aff", -1)
	strati.set("_g_pota", -1)


func _go() -> void:
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 8:
		await process_frame
	var livello := current_scene
	if livello == null:
		print("GUASTO: il MainLevel non si è caricato")
		quit(1)
		return
	var build := livello.get_node_or_null("BuildSystem")
	var visitors := livello.get_node_or_null("Visitors")
	var cozy := livello.get_node_or_null("CozyWorld")
	var scavi := livello.get_node_or_null("Scavi")
	var strati := livello.get_node_or_null("Strati")
	var daynight := livello.get_node_or_null("DayNight")
	var inventory := livello.get_node_or_null("Inventory")
	if build == null or visitors == null or cozy == null or scavi == null \
			or strati == null or daynight == null or inventory == null:
		print("GUASTO: manca un nodo (build=%s visitors=%s cozy=%s scavi=%s strati=%s dn=%s inv=%s)"
				% [build, visitors, cozy, scavi, strati, daynight, inventory])
		quit(1)
		return
	# PRIMA di ogni altra cosa: niente scritture sul salvataggio
	build.call("set_persist_for_debug", false)
	print("persistenza: spenta")
	# il mondo si costruisce differito: gli ostacoli veri arrivano dopo
	await create_timer(2.0).timeout
	var legami := get_first_node_in_group("legami")
	var ostacoli: Array = cozy.call("obstacle_circles")
	print("giorno del salvataggio: ", int(daynight.get("day")),
			"  ostacoli: ", ostacoli.size())

	# ---------------------------------------------------- (c) e (d): l'harness
	print("\n[c/d] l'harness non seppellisce")
	_azzera(strati)
	var celle := _celle_libere(cozy, build, 3)
	if celle.size() < 3:
		print("GUASTO: nel prato non ci sono tre celle libere")
		quit(1)
		return
	build.call("place_cell", Vector2i(celle[0][0], celle[0][1]), "Sedia", 0, false, 0)
	build.call("place_cell", Vector2i(celle[1][0], celle[1][1]), "Panchina", 0, false, 0)
	build.call("place_edge", Vector2i(1, 0), "Staccionata", false, false, 0)
	build.call("debug_remove_edge", Vector2i(1, 0), 0)
	_dico(int(strati.call("debug_state")["strati"]) == 0,
			"(d) debug_remove_edge non seppellisce")
	build.call("debug_clear")
	_dico(int(strati.call("debug_state")["strati"]) == 0,
			"(c) debug_clear spazza il villaggio e la terra resta a zero strati")
	_dico(int(build.call("piece_count")) == 0, "premessa: il villaggio è sgombro")

	# ------------------------------- (f) due demolizioni dello stesso pezzo
	print("\n[f] la trave del PRIMO ponte")
	celle = _celle_libere(cozy, build, 2)
	build.call("place_cell", Vector2i(celle[0][0], celle[0][1]), "Sedia", 0, false, 0)
	build.call("place_cell", Vector2i(celle[1][0], celle[1][1]), "Sedia", 0, false, 0)
	build.set("_level", 0)
	build.set("_hover_cell", Vector2i(celle[0][0], celle[0][1]))
	build.call("_try_remove")
	var righe: Array = strati.get("_strati")
	_dico(righe.size() == 1, "la prima Sedia demolita seppellisce UNO strato")
	if righe.size() == 1:
		var riga: Dictionary = righe[0]
		_dico(str(riga.get("tipo", "")) == "demolizione"
				and str(riga.get("pezzo", "")) == "Sedia"
				and riga.get("cella", []) == celle[0],
				"…tipo demolizione, pezzo Sedia, nella cella demolita (meta vivi nel call_group sincrono)")
	build.set("_hover_cell", Vector2i(celle[1][0], celle[1][1]))
	build.call("_try_remove")
	_dico(int(build.call("piece_count")) == 0,
			"premessa: anche la seconda Sedia è stata demolita davvero")
	_dico((strati.get("_strati") as Array).size() == 1,
			"la seconda demolizione dello stesso pezzo NON seppellisce doppioni")

	# ------------------------- (e) il confine di stagione e il replay del load
	print("\n[e] il giorno di confine di stagione")
	_azzera(strati)
	var giorno_vero := int(daynight.get("day"))
	# un confine dove il segno ESCE davvero (riga_stagionale è deterministica:
	# si scandisce finché il dado del giorno dice sì — così il dedupe lavora)
	var confine := -1
	for k in range(1, 60):
		var g := 1 + k * DN_S.SEASON_DAYS
		if not (STRATI_S.riga_stagionale(g, ostacoli) as Dictionary).is_empty():
			confine = g
			break
	_dico(confine > 0, "esiste un confine di stagione col segno (deterministico)")
	daynight.set("day", confine)
	# il replay: al caricamento season_changed può arrivare più volte
	strati.call("_su_stagione", 0)
	strati.call("_su_stagione", 0)
	strati.call("_su_stagione", 0)
	_dico(_righe_stagione_di(strati, confine) == 1,
			"tre season_changed nello stesso giorno: UNA sola riga stagione")
	# il giro del disco: save_extra → JSON → load_extra, poi il segnale
	# ri-emesso al caricamento e la rete di sicurezza di strato_del_giorno
	var payload = JSON.parse_string(JSON.stringify(strati.call("save_extra")))
	strati.call("load_extra", payload)
	strati.call("_su_stagione", 0)
	strati.call("strato_del_giorno", confine)
	_dico(_righe_stagione_di(strati, confine) == 1,
			"dopo il load sul confine il replay non deposita doppioni")

	# --------------------- (a) il luccichio in più, con gli ostacoli veri
	print("\n[a] il luccichio del mattino sopra uno strato")
	_azzera(strati)
	# un giorno NON di confine in cui il dado di PROB_AFFIORA dice sì
	var giorno := -1
	for d in range(2, 400):
		if (d - 1) % DN_S.SEASON_DAYS == 0:
			continue
		var sonda := [STRATI_S.riga_demolizione([0, 0], "Sonda", d - 1)]
		if not (STRATI_S.strato_affiorante(d, sonda) as Dictionary).is_empty():
			giorno = d
			break
	_dico(giorno > 0, "esiste un mattino in cui la terra parla (deterministico)")
	var punti: Array = SCAVI_S.punti_del_giorno(giorno, ostacoli)
	var lontana := func(c: Array) -> bool:
		for q in punti:
			if Vector2(float(q.x) - float(c[0]), float(q.z) - float(c[1])).length() \
					< SCAVI_S.DIST_MIN + 0.6:
				return false
		return true
	var buone := _celle_libere(cozy, build, 2, lontana)
	if buone.size() < 2:
		print("GUASTO: nessuna cella libera lontana dai punti del giorno")
		quit(1)
		return
	var dna := {"name": "Nocciola", "quirk": "colleziona_sassolini", "fur": "f7e6d0"}
	var riga_a: Dictionary = STRATI_S.riga_ricordo(buone[0], "Nocciola",
			"il gattino Cannella", dna, "", giorno - 1)
	var riga_b: Dictionary = STRATI_S.riga_demolizione(buone[1], "Ponte", giorno - 1)
	strati.set("_strati", [riga_a, riga_b])
	daynight.set("day", giorno)
	scavi.set("_giorno", giorno)
	scavi.set("_scavati", [])
	scavi.call("_rigenera")
	var spots: Array = scavi.get("_spots")
	var con_strato: Array = []
	for s in spots:
		if (s as Dictionary).has("strato"):
			con_strato.append(s)
	_dico(con_strato.size() == 1,
			"due strati eleggibili, AL PIÙ un luccichio in più (n=%d)" % con_strato.size())
	_dico(spots.size() <= punti.size() + 1,
			"il mattino resta sobrio: mai più di un luccichio oltre i punti del giorno")

	# ------------------------------------- (b) lo scavo consegna davvero
	print("\n[b] lo scavo: Tasche, filo e toast")
	# per lo scavo si torna a UN solo strato sotto terra: con due celle il
	# dado del giorno pesca chi capita, e qui serve che affiori il RICORDO
	# (Tasche + momento sul filo + label nel toast, tutt'e tre in un colpo)
	_azzera(strati)
	strati.set("_strati", [riga_a.duplicate(true)])
	scavi.set("_scavati", [])
	scavi.call("_rigenera")
	spots = scavi.get("_spots")
	con_strato = []
	for s2 in spots:
		if (s2 as Dictionary).has("strato"):
			con_strato.append(s2)
	if con_strato.size() != 1:
		print("GUASTO: senza luccichio-strato lo scavo non si può provare")
		quit(1)
		return
	var scavato: Dictionary = (con_strato[0] as Dictionary)["strato"]
	_dico(str(scavato.get("tipo", "")) == "ricordo",
			"sotto il luccichio c'è il ricordo del partito")
	var oggetto := str(scavato.get("oggetto", ""))
	var tesoro_id := str(SCAVI_S.tesoro_del_reperto(scavato))
	var k := (scavi.get("_spots") as Array).find(con_strato[0])
	var tasca_prima := int((inventory.get("treasures") as Dictionary).get(tesoro_id, 0))
	scavi.call("_scava", k)
	# L'ATOMICITÀ, misurata in vivo: ledger, Tasche e Legami nello STESSO
	# frame dello scavo, prima di qualunque await (un save_now qui in mezzo
	# non può più perdere il reperto).
	_dico(int(strati.get("_g_aff")) == giorno,
			"nel frame dello scavo il gate del giorno è già chiuso")
	_dico((strati.get("_strati") as Array).size() == 0,
			"…la riga scavata è già fuori dal ledger")
	var tasca_subito := int((inventory.get("treasures") as Dictionary).get(tesoro_id, 0))
	_dico(tasca_subito == tasca_prima + 1,
			"…e «%s» è già nelle Tasche (+1)" % tesoro_id)
	var annodato := false
	if legami != null and str(scavato.get("tipo", "")) == "ricordo":
		for m in legami.call("momenti_di", "Nocciola"):
			if str((m as Dictionary).get("t", "")) == "reperto":
				annodato = true
		_dico(annodato, "…e il momento «reperto» è già sul filo del partito (per NOME)")
	# il volo, poi il toast: l'ULTIMO a parlare dev'essere il reperto, non
	# «il filo si colora» dei Legami
	await create_timer(2.2).timeout
	var toast := str((visitors.get("_toast_label") as Label).text)
	print("  toast finale: «%s»" % toast)
	_dico(toast.begins_with("Sotto terra:"),
			"a fine volo parla il reperto (il toast dei Legami è sovrascritto)")
	_dico("il gattino Cannella" in toast,
			"il toast nomina il partito con la label")
	_dico(not ("di il " in toast) and not ("di l'" in toast) and not ("di la " in toast),
			"…con la grammatica giusta (mai «Era di il gattino»)")
	_dico(oggetto == "sassolino_lucido" and tesoro_id == "sassolino_lucido",
			"il reperto è quello del carattere (quirk → sassolino)")
	_dico((strati.call("strato_del_giorno", giorno) as Dictionary).is_empty(),
			"oggi la terra non parla più: «ogni tanto» resta vero")

	daynight.set("day", giorno_vero)
	print("")
	if _guasti == 0:
		print("ESITO: TUTTO A POSTO")
	else:
		print("ESITO: %d GUASTI" % _guasti)
	quit(0 if _guasti == 0 else 1)
