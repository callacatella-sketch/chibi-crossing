extends SceneTree
## IL METRO DELLE CRICCHE — quanti incontri capitano DAVVERO, e quanto costa
## rileggerli.
##
## `tests/cases/test_cricche.gd` prova le regole su registri fabbricati a
## mano: dice che il predicato è giusto, e non dice NIENTE sulla domanda da
## cui dipende tutto il resto — *in una giornata di gioco vera, quante
## coppie di vicini si trovano fuori dal falò?* Se la risposta fosse «quasi
## nessuna», `GIORNATE_RITROVO = 3` sarebbe irraggiungibile e l'intera
## meccanica sarebbe codice morto in partita, con la suite verde. È la forma
## di guasto che questo progetto ha già pagato tre volte.
##
## Perciò qui si apre il MainLevel VERO, ci si insediano dei residenti veri,
## e si lascia passare una giornata di gioco a velocità NORMALE (quattro
## minuti reali: l'orologio non si accelera, o si misurerebbe un villaggio
## che non esiste — `_chats` guarda ogni 3,5 s e i corpi camminano a metri
## al secondo, e cambiare la scala del tempo cambia il numero di incontri).
##
##   CHIBI_GIORNI=1    quante giornate di gioco (ognuna costa 4 minuti veri)
##   CHIBI_QUANTI=12   quanti residenti
##
##   Godot --headless --path . --script res://tools/misura_cricche.gd
##
## ============================================================
## MISURATO (2026-08-14): 12 residenti, 7 giornate, 1680 s reali
## ============================================================
##   righe 52 · 24 coppie distinte su 66 possibili · 7,4 incontri al giorno
##   giornate per coppia:  13 coppie×1 · 6×2 · 1×3 · 1×4 · 1×5 · 1×7 · 1×8
##   AL FALÒ: l'oracolo ha visto 52 coppie vicine, il registro ZERO righe
##   `cricche()` sul registro vero: 0,68 ms
##
## Le due righe che contano, e vanno lette insieme:
##
##  1. **LE SOGLIE SEPARANO DAVVERO.** Due coppie hanno passato il predicato
##     (7 giornate, ora 0,0003, posto 0,00 m — e 4 giornate, 0,0002, 0,00 m);
##     due coppie con ALTRETTANTE giornate (7 e 4) sono state rifiutate
##     perché si erano viste a ore a caso in posti a caso (ora 0,65 e 0,40,
##     posto 23,5 m e 20,9 m). Senza le due soglie fini, il predicato avrebbe
##     detto «si ritrovano» a quattro coppie invece che a due, e le due in
##     più erano gente che si è solo incrociata.
##  2. **UNA CRICCA NON SI È FORMATA — zero in sette giornate.** Il ritrovo a
##     DUE succede (due coppie su dodici residenti in una settimana); il
##     gruppo a tre no. Chi lavora sui canali visibili deve sapere che il
##     caso comune è la COPPIA, e che una cricca vera è un evento raro che
##     probabilmente lo fa succedere il giocatore, mettendo un posto dove
##     tre persone convergono.
##
## ⚠️ E UN DIFETTO DEL BANCO, DICHIARATO: `_cella()` mette i residenti su una
## griglia con **due metri di passo**, il che fabbrica co-presenza — due
## vicini fermi davanti a casa propria sono già a portata. In un villaggio
## vero le case le posa il giocatore e stanno più larghe: questi numeri sono
## un TETTO, non una media.
##
## L'ORACOLO È INDIPENDENTE: il banco tiene un proprio conto della
## co-presenza (chi è entro 1,9 m di chi, e in che fase della giornata)
## campionandolo per conto suo, e alla fine lo confronta col registro.
## Chiedere al registro se ha ragione sarebbe chiedere al giudice se è
## d'accordo con sé stesso.

const CRICCHE := preload("res://scenes/npc/Cricche.gd")

var _vis: Node
var _dn: Node3D
var _build: Node
var _cric: Node
var _quanti := 12
var _giorni := 1
## l'oracolo: chiave della coppia -> {giorno: fase} visti dal banco
var _oracolo := {}
var _oracolo_falo := {}


func _init() -> void:
	_go()


func _trova(gruppo: String) -> Node:
	for n in get_nodes_in_group(gruppo):
		return n
	return null


func _cella(k: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(-6 + (k % 7) * 2, 3 + (k / 7) * 2)


func _go() -> void:
	if OS.get_environment("CHIBI_QUANTI") != "":
		_quanti = int(OS.get_environment("CHIBI_QUANTI"))
	if OS.get_environment("CHIBI_GIORNI") != "":
		_giorni = int(OS.get_environment("CHIBI_GIORNI"))
	if change_scene_to_file("res://scenes/levels/MainLevel.tscn") != OK:
		push_error("MainLevel non si apre")
		quit(1)
		return
	for _i in 40:
		await process_frame
	_vis = _trova("visitors")
	_dn = _trova("daynight") as Node3D
	_build = _trova("build_system")
	_cric = _trova("cricche")
	if _vis == null or _dn == null or _cric == null:
		push_error("manca Visitors, DayNight o Cricche")
		quit(1)
		return
	print("Cricche in scena: sì")

	# IL VILLAGGIO DEVE AVERE DEI POSTI, o i vicini non hanno dove andare e
	# la co-presenza che si misura è quella di un prato vuoto
	if _build != null:
		for k in 4:
			var z := 3 + k * 2
			for x in [-9, 9]:
				_build.call("place_cell", Vector2i(x, z), "Cespuglio", 0, false)
			for x2 in [-3, 3]:
				_build.call("place_cell", Vector2i(x2, z), "Panchina", 0, false)
		_build.call("aggiorna_varchi_ora")

	var VS := load("res://scenes/npc/Visitor.gd")
	var DNAG := load("res://scenes/npc/ChibiDNA.gd")
	var residenti: Array = _vis.get("_residents")
	for k in _quanti:
		var c := _cella(k)
		var v = VS.new()
		v.dna = DNAG.generate(9000 + k * 37)
		_vis.add_child(v)
		v.mode = "resident"
		v.position = Vector3(float(c.x), 0.0, float(c.y))
		v._enter_state("r_idle")
		var r := {"node": v, "label": "Prova%02d" % k, "dna": v.dna,
				"cell": c, "species": "chibi"}
		residenti.append(r)
		_vis.call("_ensure_brain", r)
	for _i2 in 8:
		await process_frame
	print("residenti insediati: %d" % residenti.size())

	# ⚠️ NON ci si affida al contatore `day` per sapere quando la giornata è
	# finita: il MainLevel carica il salvataggio, e il giorno che si trova
	# non è quello da cui si è partiti. Si conta il tempo di gioco a mano.
	_dn.call("set_time", 0.02)
	var t0 := Time.get_ticks_msec()
	var scatti := 0
	var prima := float(_dn.get("time"))
	var passato := 0.0
	while passato < float(_giorni):
		await process_frame
		var ora := float(_dn.get("time"))
		passato += fposmod(ora - prima, 1.0)
		prima = ora
		scatti += 1
		if scatti % 12 == 0:
			_campiona(residenti)
		if scatti % 900 == 0:
			print("   … %.2f giornate, ora %.2f (%s), righe %d"
					% [passato, ora, _vis.call("_phase"),
					(_cric.get("_incontri") as Array).size()])
	var reali := (Time.get_ticks_msec() - t0) / 1000.0
	print("\npassate %d giornate di gioco in %.0f s reali" % [_giorni, reali])
	_referto(residenti)
	quit()


## L'oracolo del banco: chi è vicino a chi, adesso, in che fase — e, per
## ogni coppia a portata, **quale cancello la fermerebbe**.
##
## Un banco che dicesse solo «zero righe» lascerebbe indovinare, ed è
## esattamente la lezione della colonna `vede?/collo?` di
## `prova_pensieri.gd`: la ragione del silenzio si stampa, o non si sa se il
## sistema è tarato stretto o rotto.
const CHIATTY := ["r_idle", "r_wander", "r_sniff", "r_fire", "r_bench"]
var _motivi := {}


func _campiona(residenti: Array) -> void:
	var fase := str(_vis.call("_phase"))
	var g := int(_dn.get("day"))
	for i in residenti.size():
		for j in range(i + 1, residenti.size()):
			var ri := residenti[i] as Dictionary
			var rj := residenti[j] as Dictionary
			var a := ri.get("node") as Node3D
			var b := rj.get("node") as Node3D
			if a == null or b == null or not is_instance_valid(a) \
					or not is_instance_valid(b):
				continue
			if a.global_position.distance_to(b.global_position) > 1.9:
				continue
			if a.call("is_hidden") or b.call("is_hidden"):
				continue
			var k := CRICCHE.chiave(
					str((ri["dna"] as Dictionary)["name"]),
					str((rj["dna"] as Dictionary)["name"]))
			var dove := _oracolo_falo if fase == "fire" else _oracolo
			if not dove.has(k):
				dove[k] = {}
			(dove[k] as Dictionary)[g] = true
			# perché questa vicinanza non diventerebbe una riga?
			var perche := "REGISTRABILE"
			if not (str(a.get("_state")) in CHIATTY and str(b.get("_state")) in CHIATTY):
				perche = "stato non chiacchierabile (%s / %s)" \
						% [str(a.get("_state")), str(b.get("_state"))]
			elif fase == "fire":
				perche = "fase del falò"
			elif str(a.get("_state")) == "r_fire" or str(b.get("_state")) == "r_fire":
				perche = "seduto al fuoco"
			elif bool(a.call("in_scena")) or bool(b.call("in_scena")):
				perche = "in scena"
			elif float(ri.get("next_act", 0.0)) > 30.0 \
					or float(rj.get("next_act", 0.0)) > 30.0:
				perche = "lease lungo (l'ha messo lì un sistema)"
			_motivi[perche] = int(_motivi.get(perche, 0)) + 1


func _referto(residenti: Array) -> void:
	var inc: Array = _cric.get("_incontri")
	var per_coppia := {}
	for r in inc:
		var riga := r as Dictionary
		var k := str(riga["a"]) + "\n" + str(riga["b"])
		per_coppia[k] = int(per_coppia.get(k, 0)) + 1
	var possibili := residenti.size() * (residenti.size() - 1) / 2
	print("── IL REGISTRO ──")
	print("  righe: %d   coppie distinte: %d su %d possibili"
			% [inc.size(), per_coppia.size(), possibili])
	print("  incontri registrati per giornata: %.1f"
			% (float(inc.size()) / maxf(1.0, float(_giorni))))
	var quante := {}
	for k2 in per_coppia:
		var n := int(per_coppia[k2])
		quante[n] = int(quante.get(n, 0)) + 1
	var chiavi: Array = quante.keys()
	chiavi.sort()
	for n2 in chiavi:
		print("    %d coppie si sono trovate in %d giornate su %d"
				% [quante[n2], n2, _giorni])
	print("── L'ORACOLO INDIPENDENTE ──")
	print("  coppie viste vicine dal banco FUORI dal falò: %d" % _oracolo.size())
	print("  coppie viste vicine dal banco AL falò:        %d" % _oracolo_falo.size())
	var solo_falo := 0
	for k3 in _oracolo_falo:
		if not _oracolo.has(k3):
			solo_falo += 1
	print("  …di cui SOLO al falò: %d — e nel registro devono essere ZERO"
			% solo_falo)
	var intrusi := 0
	for k4 in per_coppia:
		if not _oracolo.has(k4):
			intrusi += 1
	print("  coppie nel registro che il banco non ha mai visto vicine: %d"
			% intrusi)
	print("── PERCHÉ UNA VICINANZA NON DIVENTA UNA RIGA ──")
	var righe_motivi: Array = _motivi.keys()
	righe_motivi.sort_custom(func(x, y): return int(_motivi[x]) > int(_motivi[y]))
	var tot := 0
	for m in righe_motivi:
		tot += int(_motivi[m])
	for m2 in righe_motivi:
		print("    %6d (%5.1f%%)  %s"
				% [_motivi[m2], 100.0 * float(_motivi[m2]) / maxf(1.0, float(tot)),
				m2])
	# ⚠️ **LE SOGLIE SONO RAGGIUNGIBILI?** È la domanda vera, e nessuna
	# asserzione la sa fare: per ogni coppia che si è vista più di una volta
	# si stampano le giornate, quanto balla l'ora e quanto balla il posto,
	# accanto alle due soglie. Se nessuna riga ci va vicino, la meccanica è
	# codice morto in partita e la suite resta verde.
	print("── LE COPPIE, UNA PER UNA (soglie: giornate>=%d, ora<=%.3f, posto<=%.1f) ──"
			% [CRICCHE.GIORNATE_RITROVO, CRICCHE.ORA_STRETTA, CRICCHE.POSTO_STRETTO])
	var oggi := int(_dn.get("day"))
	var righe_coppie: Array = []
	for k5 in per_coppia:
		if int(per_coppia[k5]) < 2:
			continue
		var due: PackedStringArray = str(k5).split("\n")
		var rap := CRICCHE.rapporto_da(
				CRICCHE.profilo(CRICCHE.campioni(inc, due[0], due[1]), oggi),
				oggi, CRICCHE.FINESTRA)
		if rap.is_empty():
			continue
		righe_coppie.append([int(rap["giorni"]), float(rap["disp"]),
				float(rap["rms"]), str(k5).replace("\n", " + "),
				CRICCHE.abitudine(inc, due[0], due[1], oggi)])
	righe_coppie.sort_custom(func(x, y): return int(x[0]) > int(y[0]))
	for r3 in righe_coppie:
		print("    giornate %d  ora %.4f  posto %5.2f m  %s  %s"
				% [r3[0], r3[1], r3[2], "SI RITROVANO" if r3[4] else "            ",
				r3[3]])
	print("    (coppie con almeno due incontri: %d)" % righe_coppie.size())
	print("── IL COSTO ──")
	var nomi := PackedStringArray()
	for r2 in residenti:
		nomi.append(str(((r2 as Dictionary)["dna"] as Dictionary)["name"]))
	var t1 := Time.get_ticks_usec()
	var out := CRICCHE.cricche(inc, nomi, nomi.size(), int(_dn.get("day")))
	print("  cricche() su questo registro: %.2f ms, %d cricche"
			% [(Time.get_ticks_usec() - t1) / 1000.0, out.size()])
	for c in out:
		print("    ", "+".join(c as PackedStringArray))
