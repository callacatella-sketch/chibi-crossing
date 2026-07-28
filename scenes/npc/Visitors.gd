extends Node

## Il via vai del villaggio. Ogni tanto — di giorno, col sereno — un
## animaletto del bosco viene a trovarti: curiosa tra i mobili, si
## riposa sulla panchina e lascia un regalino che puoi raccogliere con E.

const VISITOR := preload("res://scenes/npc/Visitor.gd")
const MIND := preload("res://scenes/npc/VillagerMind.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")
const BRAIN := preload("res://scenes/npc/VillagerBrain.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")
const VILLAGGIO := preload("res://scenes/npc/Villaggio.gd")
const UI_BROWN := Color("6a4a3a")
# Fino a ventotto vicini: il passaparola del Villaggio, le chiacchiere, le
# indoli e le stravaganze rendono per densità — la scala dell'Animo produce
# storie corali (era 4, poi 8: mezzo coro). Il tetto NON è un rubinetto: un
# candidato arriva solo se il giocatore ha costruito un letto libero sotto
# un tetto (_free_house) — 28 abitanti = 28 case volute, una per una.
const MAX_RESIDENTS := 28

const SPECIES := ["riccio", "passerotto"]
const SPECIES_LABEL := {"riccio": "Il Riccio", "passerotto": "Il Passerotto"}
const GIFTS := {
	"riccio": ["una bacca lucida", "un funghetto profumato", "una foglia a forma di cuore"],
	"passerotto": ["una piuma morbidissima", "un semino raro", "un fiocco di lana"],
}

const ENTRIES := [Vector3(14, 0, 8), Vector3(-14, 0, 7), Vector3(11, 0, -6)]
const PLAZA := Vector3(2.5, 0, 5.5)
const CLEARING := Vector3(-1.0, 0.0, -46.0)

const WISH_POOL := [["Aiuola", "garden"], ["Fungo", "garden"], ["Cespuglio", "garden"],
		["Lampada", "comfort"], ["Panchina", "comfort"]]
const WISH_ART := {"Aiuola": "un'aiuola", "Fungo": "un fungo", "Cespuglio": "un cespuglio",
		"Lampada": "una lampada", "Panchina": "una panchina"}

var _player: Node3D
var _build: Node3D
var _daynight: Node3D
var _weather: Node3D
var _sfx

var _active: Node3D
var _timer := 45.0
var _gift: Node3D
var _gift_bob: Tween
var _gift_species := ""

# il gestionale del trasloco: candidato corrente, mente, memoria, residenti
var _mind: RefCounted
var _decided := false
var _welcomes := 0
var _cand_label := ""
var _cand_visits := {}                  # nome -> visite passate (persistito)
var _residents: Array[Dictionary] = [] # {species, cell, node, dna, label, friend, wish, phase, next_act}
var _cooking: Node
var _mail: Node
var _garden: Node
var _cozy: Node3D
var _inventory: Node
var _pockets: Node
var _chat_acc := 0.0
var _wish_acc := 0.0
var _pair_cd := {}

# la vita interiore: label -> VillagerBrain (bisogni, indole, memoria)
var _brains := {}
## L'ANIMA di ogni residente (scenes/npc/Animo.gd) e il villaggio che li
## tiene insieme: pressioni, ricordi, carattere e passaparola. Il cervello
## decide cosa fare adesso; l'animo decide come STA, e se ti perdona.
var _animi := {}
var _villaggio: RefCounted
# la memoria dei partiti dal salvataggio, in attesa che il grafo nasca
# (lazy): reiniettata in _iscrivi_al_villaggio, salvata in save_extra
var _partiti_salvati := {}
## Il raffreddamento del sussulto: uno per residente, così la reazione
## istintiva scatta all'AVVICINARSI e non a ogni fotogramma.
var _sussulto_cd := {}
## Chi ti sta venendo a cercare, e da quanto: {label -> secondi di attesa}.
var _in_confronto := {}
var _vita_cd := 0.0     # un solo toast di vita quotidiana ogni tanto

var _prompt: PanelContainer
var _prompt_label: Label
var _toast: PanelContainer
var _toast_label: Label


func _ready() -> void:
	add_to_group("persistable")
	_player = get_node("%Player")
	_build = get_node("../BuildSystem")
	_daynight = get_node_or_null("../DayNight")
	_weather = get_node_or_null("../Weather")
	_sfx = get_node_or_null(^"/root/Sfx")
	(func():
		_cooking = get_node_or_null("../Cooking")
		_mail = get_node_or_null("../Mail")
		_garden = get_node_or_null("../Garden")
		_cozy = get_node_or_null("../CozyWorld")
		_inventory = get_node_or_null("../Inventory")
		_pockets = get_node_or_null("../Pockets")).call_deferred()
	if _daynight:
		_daynight.day_changed.connect(_on_new_day)
	_build_ui()


# a ogni nuovo mattino i desideri esauditi lasciano posto a sogni nuovi
var _was_raining := false
var _th_cd := 5.0


# l'età di ogni residente (dal Filo Rosso) attraversa corpo e voce
func _apply_eta() -> void:
	var legami: Node = get_tree().get_first_node_in_group("legami")
	if legami == null:
		return
	for r in _residents:
		if str(r.get("species", "")) != "chibi":
			continue
		var node := r.get("node") as Node3D
		if node and is_instance_valid(node):
			node.call("set_eta", float(legami.call("eta_f",
					str(r.get("dna", {}).get("name", "")))))


func debug_eta(f: float) -> void:
	for r in _residents:
		var node := r.get("node") as Node3D
		if node and is_instance_valid(node):
			node.call("set_eta", f)


func _random_resident_node() -> Node3D:
	var pool: Array[Node3D] = []
	for r in _residents:
		var node := r.get("node") as Node3D
		if node and is_instance_valid(node) and not node.call("is_hidden"):
			pool.append(node)
	return pool[randi() % pool.size()] if not pool.is_empty() else null


func _on_new_day(_day: int) -> void:
	_giorno_di_animo()
	# «sa-la! ya-ho!» — il buongiorno al sole di un mattiniero
	var speaker := _random_resident_node()
	if speaker:
		speaker.call("speak", ["sole", "ciao"], "felice")
	# le stagioni della vita avanzano: il Filo Rosso detta l'età
	_apply_eta()
	for r in _residents:
		var wish: Dictionary = r.get("wish", {})
		if not wish.is_empty() and bool(wish.get("done", false)):
			r["wish"] = {}


func is_bed_claimed(cell: Vector2i) -> bool:
	for r in _residents:
		if r["cell"] == cell:
			return true
	return false


func _process(delta: float) -> void:
	_tick_sussulti(delta)
	_tick_confronti(delta)
	_tick_partenze(delta)
	# il prossimo ospite arriva col sereno, di giorno, quando non c'è nessuno
	if _active == null:
		var day: bool = _daynight == null or not _daynight.is_night()
		var dry: bool = _weather == null or not _weather.is_raining()
		if day and dry:
			_timer -= delta
			if _timer <= 0.0:
				# se c'è una casa libera, il prossimo arriva con la valigia:
				# un villager NUOVO, generato dal DNA
				var house := _free_house()
				if not house.is_empty() and _residents.size() < MAX_RESIDENTS:
					_spawn_candidate(DNA.generate(), house)
				else:
					_spawn(SPECIES[randi() % SPECIES.size()])

	# il candidato in attesa sull'uscio: verdetto quando la pazienza finisce
	if _active and _active.get("mode") == "candidate" and not _decided \
			and _active.get("_state") == "c_decide":
		_decide()

	# ciclo giorno/notte dei residenti: ognuno con la SUA finestra di
	# sonno (il mattiniero all'alba, il dormiglione poltrisce, il
	# sognatore resta sotto le stelle) — si va a nanna solo dagli stati
	# di routine, chi è impegnato (onsen, casa sull'albero) finisce.
	# E intanto i bisogni scorrono: dormendo si ricarica l'energia.
	var t_ora: float = float(_daynight.get("time")) if _daynight else 0.5
	_vita_cd -= delta
	for r in _residents:
		var node := r["node"] as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var brain: RefCounted = _ensure_brain(r)
		var nascosto: bool = node.call("is_hidden")
		brain.tick(delta, nascosto)
		if _sleep_window(brain, t_ora) and not nascosto \
				and str(node.get("_state")) in ["r_idle", "r_wander", "r_fire", "r_bench", "r_sniff", "tk_stella", "tk_sing", "tk_nap"]:
			node.call("resident_sleep")
		elif not _sleep_window(brain, t_ora) and nascosto:
			node.call("resident_wake")
		elif not nascosto:
			_quirk_tick(r, node, brain, delta, t_ora)

	# la prima goccia fa alzare il musetto: qualcuno commenta la pioggia
	var raining: bool = _weather != null and _weather.is_raining()
	if raining and not _was_raining:
		var speaker := _random_resident_node()
		if speaker:
			speaker.call("speak", ["pioggia", "casa"], "domanda")
	_was_raining = raining

	# la pioggia ADDOSSO: chi è fuori senza un tetto si ripara (zampina a
	# visiera, orecchie basse, passetto svelto — il livello _riparo del
	# Visitor). Sotto una copertura il corpo si rilassa da solo.
	for r in _residents:
		var rn := r.get("node") as Node3D
		if rn != null and is_instance_valid(rn):
			var cella := Vector2i(roundi(rn.global_position.x),
					roundi(rn.global_position.z))
			rn.set("riparo_pioggia", raining and not _build.has_cover(cella))
	if _active != null and is_instance_valid(_active):
		var ca := Vector2i(roundi(_active.global_position.x),
				roundi(_active.global_position.z))
		_active.set("riparo_pioggia", raining and not _build.has_cover(ca))

	# (Fase 6) i vicini leggono Mochi: l'empatia bidirezionale
	_tick_empatia(delta, raining)

	# se Mochi è salita sulla casa sull'albero, ogni tanto un residente
	# si arrampica a trovarla: la verticalità è anche compagnia
	_th_cd -= delta
	if _th_cd <= 0.0 and _player.global_position.y > 1.8:
		_th_cd = 8.0
		for th in _build.get_placed_by_name("Casa albero"):
			var plat: Vector3 = (th as Node3D).global_position + Vector3(0, 2.5, 0)
			if _player.global_position.distance_to(plat) < 2.8:
				var guest := _random_resident_node()
				if guest:
					var tf: Transform3D = (th as Node3D).global_transform
					guest.call("treehouse_visit", tf * _build.TH_BASE,
							tf * _build.TH_TOP, tf * _build.TH_PERCH)
					_th_cd = 55.0
				break

	_routine(delta)
	_chats(delta)
	_wishes(delta)

	_update_prompts()


# ---------------------------------------------------------------- visite

func _spawn(species: String) -> void:
	_timer = randf_range(80.0, 160.0)
	var v: Node3D = VISITOR.new()
	v.species = species

	# tappe della visita: 2 mobili all'aperto scelti a caso (mai in casa)
	var pois: Array[Vector3] = []
	var candidates: Array[Node3D] = []
	for node in _build.call("get_placed_by_name", "Lampada") + \
			_build.call("get_placed_by_name", "Cassetta posta") + \
			_build.call("get_placed_by_name", "Aiuola") + \
			_build.call("get_placed_by_name", "Fungo") + \
			_build.call("get_placed_by_name", "Cespuglio"):
		var cell := Vector2i(roundi(node.position.x), roundi(node.position.z))
		if not (_build.get("_placed")[3] as Dictionary).has(cell):
			candidates.append(node)
	candidates.shuffle()
	for i in mini(2, candidates.size()):
		var p: Vector3 = candidates[i].global_position
		pois.append(p + (PLAZA - p).normalized() * 0.65)

	var bench: Node3D = null
	var benches: Array[Node3D] = _build.call("get_placed_by_name", "Panchina")
	if not benches.is_empty():
		bench = benches[0]

	add_child(v)
	v.setup(species, ENTRIES[randi() % ENTRIES.size()], PLAZA, pois, bench,
			Vector3(0, 0, -9), Vector3(-2, 0, -15))
	v.wants_gift.connect(_on_gift_dropped)
	v.finished.connect(func(): if _active == v: _active = null)
	_active = v


func _on_gift_dropped(pos: Vector3, species: String) -> void:
	if _gift_bob:
		_gift_bob.kill()
	if _gift:
		_gift.queue_free()
	_gift_species = species
	_gift = _make_present()
	_gift.position = Vector3(pos.x, 0.09, pos.z)
	add_child(_gift)
	_gift.scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(_gift, "scale", Vector3.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# fluttua piano finché non lo raccogli
	_gift_bob = create_tween().set_loops()
	_gift_bob.tween_property(_gift, "position:y", 0.16, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_gift_bob.tween_property(_gift, "position:y", 0.09, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _sfx:
		_sfx.place_ok()


func _make_present() -> Node3D:
	var g := Node3D.new()
	var carta := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 0.14, 0.16)
	carta.mesh = bm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color("f4b8c8")
	carta.material_override = wm
	g.add_child(carta)
	for rot in [0.0, PI * 0.5]:
		var ribbon := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.035, 0.15, 0.165)
		ribbon.mesh = rm
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color("fff3e0")
		ribbon.material_override = rmat
		ribbon.rotation.y = rot
		g.add_child(ribbon)
	var knot := MeshInstance3D.new()
	var km := SphereMesh.new()
	km.radius = 0.035
	km.height = 0.07
	knot.mesh = km
	var kmat := StandardMaterial3D.new()
	kmat.albedo_color = Color("fff3e0")
	knot.material_override = kmat
	knot.position.y = 0.085
	g.add_child(knot)
	return g


# ------------------------------------------------------- vita dei residenti

# la fase della giornata: mattina alle aiuole, giorno in giro, sera al falò
func _phase() -> String:
	if _daynight == null:
		return "day"
	var t: float = _daynight.time
	if t >= 0.28 and t < 0.42:
		return "morning"
	if t >= 0.66 and t < 0.82:
		return "fire"
	return "day"


func _routine(delta: float) -> void:
	var ph := _phase()
	for i in _residents.size():
		var r := _residents[i]
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node) or node.call("is_hidden"):
			continue
		if str(r.get("phase", "")) != ph:
			r["phase"] = ph
			r["next_act"] = randf_range(0.4, 1.8)
		r["next_act"] = float(r.get("next_act", 1.0)) - delta
		if float(r["next_act"]) > 0.0:
			continue
		match ph:
			"fire":
				# la sera ci si ritrova tutti attorno al fuoco
				r["next_act"] = 9999.0
				node.call("do_routine", "fire", _posto_al_falo(i), CLEARING)
				_ensure_brain(r).satisfy("falo")
			"morning", "day":
				r["next_act"] = randf_range(9.0, 15.0)
				# il cervello decide, la macchina a stati recita: bisogni,
				# indole e contesto scelgono l'attività della mezz'ora
				var brain: RefCounted = _ensure_brain(r)
				var act: String = brain.choose(_brain_ctx(r, ph))
				# e se quel posto è diventato insopportabile, cambia idea
				act = _filtra_luogo(str(r.get("label", "")), act)
				_recita(r, node, brain, act, ph)


# ------------------------------------------------------- l'agenda recitata

# il contesto che il cervello legge prima di decidere
func _brain_ctx(r: Dictionary, ph: String) -> Dictionary:
	var home := Vector3(r["cell"].x, 0, r["cell"].y)
	var t_ora: float = float(_daynight.get("time")) if _daynight else 0.5
	var amico := false
	for other in _residents:
		if other == r:
			continue
		var on := other.get("node") as Node3D
		if on and is_instance_valid(on) and not on.call("is_hidden"):
			amico = true
			break
	return {
		"mattina": ph == "morning",
		"sera_stellata": t_ora >= 0.80 and t_ora < 0.92,
		"aiuola_da_annaffiare": _garden != null \
				and _garden.bed_needing_water(home, 14.0) != null,
		"spuntino_vicino": _nearest_named(["Cespuglio", "Fungo", "Orto"], home, 12.0) != null,
		"amico_in_giro": amico,
		"regia": get_tree().get_first_node_in_group("regista") != null,
	}


# dall'attività scelta ai passi concreti — con la vita che si vede:
# ogni tanto un toast racconta cosa stanno combinando
func _recita(r: Dictionary, node: Node3D, brain: RefCounted, act: String, ph: String) -> void:
	var home := Vector3(r["cell"].x, 0, r["cell"].y)
	match act:
		"spuntino":
			var cibo := _nearest_named(["Cespuglio", "Fungo", "Orto"], home, 12.0)
			if cibo:
				var pos: Vector3 = cibo.global_position
				pos += (home - pos).normalized() * 0.6
				node.call("do_task", "nibble", pos, func():
					brain.satisfy("spuntino")
					brain.remember("cibo", "uno spuntino ai cespugli"))
				_vita_toast(L10n.tf("%s sgranocchia qualcosa tra i cespugli…", [r["label"]]))
				return
		"cura_giardino":
			if _garden:
				var bed: Node3D = _garden.bed_needing_water(home, 14.0)
				if bed:
					var lato: Vector3 = bed.global_position + Vector3(0.75, 0, 0.1)
					node.call("do_task", "water", lato, func():
						if _garden:
							_garden.villager_water(bed)
						brain.satisfy("cura_giardino")
						brain.remember("fiore", "un'aiuola annaffiata"))
					_vita_toast(L10n.tf("♥ %s sta annaffiando le tue aiuole!", [r["label"]]))
					return
		"riposo":
			if brain.get("quirk") == "pisolini_ovunque" and randf() < 0.5:
				node.call("do_task", "nap", Vector3.ZERO, func(): brain.satisfy("pisolino"))
				_vita_toast(L10n.tf("%s si è addormentato lì, così.", [r["label"]]))
				return
			var bench := _free_bench(home)
			if bench:
				node.call("do_routine", "bench",
						bench.global_transform * Vector3(0, 0, 0.8), Vector3.ZERO, bench)
				brain.satisfy("riposo")
				return
			node.call("do_task", "nap", Vector3.ZERO, func(): brain.satisfy("pisolino"))
			return
		"quattro_chiacchiere":
			# cerca compagnia: il migliore amico se c'è, chiunque altrimenti
			var meta: Node3D = null
			var best_label: String = brain.migliore_amico()
			for other in _residents:
				if other == r:
					continue
				var on := other.get("node") as Node3D
				if on == null or not is_instance_valid(on) or on.call("is_hidden"):
					continue
				if meta == null or str(other["label"]) == best_label:
					meta = on
			if meta:
				var fianco: Vector3 = meta.global_position + Vector3(randf_range(-0.9, 0.9), 0, 0.9)
				node.call("do_routine", "sniff", fianco)
				return
		"meraviglia":
			var posti: Array[Vector3] = []
			if _cozy:
				posti.append(_cozy.POND_CENTER + Vector3(0, 0, _cozy.POND_R + 0.9))
			var albero := get_tree().get_first_node_in_group("grande_albero")
			if albero:
				posti.append((albero as Node3D).global_position + Vector3(1.6, 0, 1.2))
			if not posti.is_empty():
				node.call("do_task", "wonder", posti[randi() % posti.size()], func():
					brain.satisfy("meraviglia")
					brain.remember("sole", "un posto bellissimo"))
				return
		"stella":
			node.call("do_task", "stella", Vector3.ZERO, func():
				brain.satisfy("stella")
				brain.remember("dormire", "una notte di stelle"))
			_vita_toast(L10n.tf("%s è rimasto fuori a guardare le stelle…", [r["label"]]))
			return
		"regia":
			var piano := _regia_plan(r, ph)
			if not piano.is_empty():
				node.call("run_plan", piano)
				return
	# nessuna scena disponibile: due passi intorno a casa
	node.call("do_routine", "wander", Vector3.ZERO)


# la finestra di sonno personale: [inizio sera, fine all'alba]
func _sleep_window(brain: RefCounted, t: float) -> bool:
	var inizio := 0.80
	var fine := 0.295
	if brain.has_indole("mattiniero"):
		fine = 0.262
	elif brain.has_indole("dormiglione"):
		fine = 0.36
	if brain.nottambulo():
		inizio = 0.92
	return t >= inizio or t < fine


func _ensure_brain(r: Dictionary) -> RefCounted:
	var key := str(r.get("label", "?"))
	if not _brains.has(key):
		var brain: RefCounted = BRAIN.new()
		brain.setup(r.get("dna", {}))
		var salvato: Dictionary = r.get("brain", {})
		if not salvato.is_empty():
			brain.from_dict(salvato)
		_brains[key] = brain
		# insieme al cervello nasce l'ANIMO: dal genoma prende sogno e tratti
		var animo: RefCounted = ANIMO.new()
		animo.setup(r.get("dna", {}))
		animo.nome = key
		var salvato_a: Dictionary = r.get("animo", {})
		if not salvato_a.is_empty():
			animo.load(salvato_a)
		_animi[key] = animo
		_iscrivi_al_villaggio(key, animo)
		# il timido saluta solo gli amici veri
		var node := r.get("node") as Node3D
		if node:
			node.set("greet_enabled",
					not brain.has_indole("timido") or int(r.get("friend", 0)) >= 3)
	return _brains[key]


# I POSTI CHE NON SI SOPPORTANO PIÙ.
#
# L'ultimo pezzo del limbico: un marchio non è solo un numero nel salvataggio,
# è una deviazione nel cammino. Il residente arriva in vista dell'orto, si
# ferma, e va da un'altra parte — e siccome il giocatore vede la scena senza
# spiegazione, il registro gliela dà: «gira al largo dalla catasta».
#
# Ritorna l'attività da fare DAVVERO: quella scelta, o un ripiego se il posto
# è diventato insopportabile.
func _filtra_luogo(label: String, act: String) -> String:
	if not _animi.has(label):
		return act
	var luogo := str(LUOGO_ATTIVITA.get(act, ""))
	if luogo == "":
		return act
	var animo: RefCounted = _animi[label]
	if not animo.limbico.evita(luogo):
		return act
	# ci arriva vicino e si blocca: è la scena che il giocatore vede
	for r in _residents:
		if str(r.get("label", "")) == label:
			var node := r.get("node") as Node3D
			if node != null and is_instance_valid(node) and node.has_method("chat_bubble"):
				node.call("chat_bubble", "…")
				node.set_meta("postura", "esita")
			break
	return RIPIEGO           # cambia idea e va a cercare compagnia


## Da quali posti questo residente gira al largo, e perché. Il registro lo
## mostra: una deviazione senza spiegazione sembra un difetto di percorso.
func luoghi_evitati(label: String) -> Array:
	if not _animi.has(label):
		return []
	var out := []
	var lim = (_animi[label] as RefCounted).limbico
	for posto in ["catasta", "orto", "cucina", "confine", "bosco"]:
		if lim.evita(posto):
			out.append(posto)
	return out


# ============================================ la partenza

## Dopo quanti secondi dallo sfogo chi ha detto «me ne vado» se ne va davvero.
## Non subito: il giocatore deve avere il tempo di corrergli dietro con un
## regalo. È l'ultima finestra per rimediare, e dev'essere una finestra vera.
const ATTESA_PARTENZA := 90.0

# CHI DICE «ME NE VADO» SE NE VA.
#
# Era il buco più grande del sistema: la scala arrivava in fondo e non
# succedeva niente, e una minaccia che non si avvera insegna al giocatore che
# può ignorare tutto. Ora il residente prepara le sue cose, lascia una
# LETTERA (non sparisce e basta: sparire è un bug, una lettera è una storia)
# e il suo letto torna libero.
func _tick_partenze(delta: float) -> void:
	for i in range(_residents.size() - 1, -1, -1):
		var r: Dictionary = _residents[i]
		var label := str(r.get("label", ""))
		if label == "" or not _animi.has(label):
			continue
		var animo: RefCounted = _animi[label]
		if not ANIMO.almeno(int(animo.gradino), "diserzione"):
			r["parte_fra"] = 0.0        # ha cambiato idea: si rimette a posto
			continue
		var resta: float = float(r.get("parte_fra", 0.0))
		if resta <= 0.0:
			r["parte_fra"] = ATTESA_PARTENZA
			continue
		var prima := resta
		resta -= delta
		r["parte_fra"] = resta
		if resta > 0.0:
			# I NOVANTA SECONDI DEVONO VEDERSI. Se l'unico segnale fosse il
			# toast finale, la partenza sembrerebbe arbitraria: il giocatore
			# non ha avuto modo di accorgersene. Invece lo si vede raccogliere
			# le sue cose, fermarsi sulla soglia, guardarsi intorno — e ha
			# tutto il tempo di andargli incontro con qualcosa in mano.
			var node_p := r.get("node") as Node3D
			for soglia in [ATTESA_PARTENZA * 0.75, ATTESA_PARTENZA * 0.45,
					ATTESA_PARTENZA * 0.15]:
				if prima > soglia and resta <= soglia:
					if node_p != null and is_instance_valid(node_p):
						node_p.set_meta("postura", "fagotto_in_spalla")
						if node_p.has_method("chat_bubble"):
							node_p.call("chat_bubble", "…")
					_show_toast(L10n.tf("%s sta raccogliendo le sue cose.", [label]))
					break
			continue
		_congeda(i, r, animo)


# Il congedo: la lettera, il ricordo sul Filo Rosso, il letto che si libera.
func _congeda(i: int, r: Dictionary, animo: RefCounted) -> void:
	var label := str(r.get("label", ""))
	var node := r.get("node") as Node3D
	# la lettera d'addio, coi SUOI motivi: è ciò che trasforma una partenza
	# in una storia che il giocatore si ricorda invece che in un bug
	var mail := get_node_or_null("../Mail")
	if mail and mail.has_method("queue_letter"):
		mail.call("queue_letter", {
			"from": label,
			"text": L10n.tf("%s\n\nHo lasciato le mie cose in ordine.\nNon serbo rancore: serbo memoria.", [animo.sfogo()]),
			"gift": false,
		})
	# il Filo Rosso se lo ricorda: chi se n'è andato non si cancella
	for legami in get_tree().get_nodes_in_group("legami"):
		if legami.has_method("momento"):
			legami.call("momento", label, "addio", animo.racconta())
			break
	_show_toast(L10n.tf("%s se n'è andato.", [label]))
	if node != null and is_instance_valid(node):
		var tw := create_tween()
		tw.tween_property(node, "scale", Vector3.ONE * 0.01, 0.8) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(node.queue_free)
	_residents.remove_at(i)          # il letto torna libero
	_animi.erase(label)
	_brains.erase(label)
	# e si congeda anche dal GRAFO del villaggio: senza questa riga il
	# disertore restava lì come un fantasma — continuava a spettegolare
	# contro di te a ogni simula_giorno e a tenere alta la tensione di un
	# posto che aveva già lasciato
	if _villaggio != null:
		_villaggio.rimuovi(label)
	_in_confronto.erase(label)
	_sussulto_cd.erase(label)
	_sussulto_cd.erase("morso_" + label)
	# e l'incarico si azzera: una label riciclata in futuro non deve
	# ereditare dal giorno uno un lavoro mai assegnato (rancore invisibile)
	get_tree().call_group("lavori", "assegna", label, "")


func _label_in_use(label: String) -> bool:
	for r in _residents:
		if str(r.get("label", "")) == label:
			return true
	return false


# ================================================= API per il Filo Rosso
# (Congedo.gd orchestra il congedo, il lutto e l'empatia: queste sono le
#  mani che gli servono per muovere i residenti senza frugare nell'agenda)

func node_di(label: String) -> Node3D:
	for r in _residents:
		if str(r.get("label", "")) == label:
			return r.get("node") as Node3D
	return null


func dna_di(label: String) -> Dictionary:
	for r in _residents:
		if str(r.get("label", "")) == label:
			return r.get("dna", {})
	return {}


func cella_di(label: String) -> Vector2i:
	for r in _residents:
		if str(r.get("label", "")) == label:
			return r["cell"]
	return Vector2i(999, 999)


## Manda un residente in un punto (il giro delle ultime cose): l'agenda
## si mette da parte e lui va, si guarda intorno, resta un po'.
func manda(label: String, pos: Vector3) -> void:
	for r in _residents:
		if str(r.get("label", "")) != label:
			continue
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			return
		if node.call("is_hidden"):
			node.call("resident_wake")
		r["next_act"] = 45.0
		node.call("do_task", "wonder", pos)
		return


## Il posto di ognuno attorno al fuoco: cerchi concentrici — undici per
## anello, poi si allarga — così anche in ventotto nessuno finisce seduto
## in braccio a un altro.
func _posto_al_falo(i: int) -> Vector3:
	@warning_ignore("integer_division")
	var anello := i / 11
	var ang := 0.9 + float(i) * 0.55 + float(anello) * 0.27
	return CLEARING + Vector3(cos(ang), 0, sin(ang)) * (1.7 + 0.85 * float(anello))


## Il raduno al falò: tutti attorno al fuoco (l'ultima sera del congedo
## la chiama il Congedo; la CLI la usa da sempre via debug_gather_fire).
func gather_fire() -> void:
	for i in _residents.size():
		var r := _residents[i]
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node) or node.call("is_hidden"):
			continue
		r["next_act"] = 9999.0
		node.call("do_routine", "fire", _posto_al_falo(i), CLEARING)


## La partenza per il Grande Prato: GENTILE. Niente lettera di rancore
## (quella è della diserzione): la storia l'ha già raccontata il congedo.
## La pulizia è la stessa di _congeda: letto libero, grafo, incarichi.
func parte_per_il_grande_prato(label: String) -> void:
	for i in _residents.size():
		var r := _residents[i]
		if str(r.get("label", "")) != label:
			continue
		var node := r.get("node") as Node3D
		if node != null and is_instance_valid(node):
			var tw := create_tween()
			tw.tween_property(node, "scale", Vector3.ONE * 0.01, 1.6) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_callback(node.queue_free)
		_residents.remove_at(i)
		_animi.erase(label)
		_brains.erase(label)
		if _villaggio != null:
			_villaggio.rimuovi(label)
		_in_confronto.erase(label)
		_sussulto_cd.erase(label)
		_sussulto_cd.erase("morso_" + label)
		get_tree().call_group("lavori", "assegna", label, "")
		_build.request_save()
		return


# ------------------------------------------- l'empatia bidirezionale
# (Fase 6) Il colpo di scena del Filo Rosso: quando Mochi ha bisogno,
# sono i VICINI ad accorgersene. Ogni gentilezza al più una volta al
# giorno, mai due insieme: l'empatia vera è discreta.
# NB: la FAME è affare della Premura (scenes/npc/Premura.gd): il languore,
# il passo piccolo e il boccone diviso vivono là — qui restano il ritorno,
# la pioggia e il lutto, così nessun bisogno riceve due premure doppie.

var _pioggia_acc := 0.0
var _pioggia_fatta := false     # una premura per acquazzone, non una al secondo
var _ritorno_visto := false
var _empatia_giorno := {}       # motivo -> giorno in cui è già successa


func _tick_empatia(delta: float, raining: bool) -> void:
	if _residents.is_empty() or _player == null:
		return
	var oggi: int = int(_daynight.get("day")) if _daynight else 1

	# il ritorno dopo un'assenza REALE: ti sono mancati, e te lo dicono
	# venendoti incontro tutti insieme (una volta sola, poco dopo il load)
	if not _ritorno_visto:
		_ritorno_visto = true
		var legami: Node = get_tree().get_first_node_in_group("legami")
		if legami and float(legami.call("assenza_reale_giorni")) >= 2.0 \
				and _residents.size() >= 2:
			var pp: Vector3 = _player.global_position
			var quanti := 0
			for r in _residents:
				var node := r.get("node") as Node3D
				if node == null or not is_instance_valid(node) or node.call("is_hidden"):
					continue
				r["next_act"] = 30.0
				var ang := TAU * float(quanti) / 4.0
				node.call("do_routine", "sniff",
						pp + Vector3(cos(ang), 0, sin(ang)) * 1.3, pp)
				node.call("speak", ["ciao", "felice"], "felice")
				node.call("_spawn_heart")
				quanti += 1
				if quanti >= 4:
					break
			if quanti > 0:
				_show_toast(L10n.t("Bentornata! Ti hanno aspettata, giorno dopo giorno."))

	# la pioggia con Mochi fuori: qualcuno la raggiunge sotto l'acqua
	if raining:
		var cell := Vector2i(roundi(_player.global_position.x),
				roundi(_player.global_position.z))
		var al_coperto: bool = _build != null and bool(_build.call("has_cover", cell))
		if not al_coperto and not _pioggia_fatta \
				and int(_empatia_giorno.get("pioggia", -1)) != oggi:
			_pioggia_acc += delta
			if _pioggia_acc >= 25.0:
				_pioggia_fatta = conforta_mochi("pioggia")
				if _pioggia_fatta:
					_empatia_giorno["pioggia"] = oggi
		elif al_coperto:
			_pioggia_acc = 0.0
	else:
		_pioggia_acc = 0.0
		_pioggia_fatta = false


## Un amico si accorge di Mochi e viene a starle vicino (Fasi 4 e 6:
## lutto, fame, pioggia, ritorno). Ritorna false se nessuno può.
func conforta_mochi(motivo: String) -> bool:
	var vicino: Node3D = null
	var vicino_r := {}
	var best_d := INF   # 999 non basta: un amico viene anche da lontano
	var dorme: Node3D = null      # un amico vero si alza anche dal letto
	var dorme_r := {}
	for r in _residents:
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		if node.call("is_hidden"):
			dorme = node
			dorme_r = r
			continue
		var d: float = _player.global_position.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			vicino = node
			vicino_r = r
	if vicino == null and dorme != null:
		dorme.call("resident_wake")
		vicino = dorme
		vicino_r = dorme_r
	if vicino == null:
		return false
	var label := str(vicino_r.get("label", ""))
	vicino_r["next_act"] = 30.0
	var fianco: Vector3 = _player.global_position + Vector3(randf_range(-0.8, 0.8), 0, 0.9)
	vicino.call("do_routine", "sniff", fianco, _player.global_position)
	# le parole giuste per ogni premura (nel lutto: quasi niente — si siede
	# accanto e basta, è il capolavoro dell'empatia)
	var parole: Array = ["felice", "amico"]
	var umore := "felice"
	var cuore := true
	match motivo:
		"lutto":
			parole = ["amico", "~"]
			umore = "triste"
			cuore = false
			_show_toast(L10n.tf("%s viene a sederti accanto. Non dice niente.", [label]))
		"pioggia":
			parole = ["pioggia", "amico"]
			umore = "neutro"
			_show_toast(L10n.tf("%s ti ha raggiunta sotto la pioggia, per non lasciarti sola.", [label]))
	# e le dice sottovoce, quando è arrivato accanto a lei
	var conforto := vicino
	get_tree().create_timer(2.6).timeout.connect(func():
		if not is_instance_valid(conforto):
			return
		conforto.call("face_towards", _player.global_position)
		conforto.call("speak", parole, umore)
		if cuore:
			conforto.call("_spawn_heart")
		else:
			conforto.call("chat_bubble", "…"))
	return true


# ============================================ il confronto e il morso
# Le soglie si interrogano PER NOME (ANIMO.almeno): prima erano due indici
# scritti a mano, 5 e 6, e bastava inserire un gradino in mezzo alla scala
# perché puntassero al gradino sbagliato senza un errore.

# CHI HA QUALCOSA DA DIRTI TE LO VIENE A DIRE.
#
# È il momento che il giocatore ricorderà: non un contatore che sale in un
# menù, ma qualcuno che attraversa il prato, ti si pianta davanti e ti
# rinfaccia FATTI PRECISI — quante volte, e cosa aveva sognato di fare.
# Chi sta più in basso sulla scala invece si morde la lingua: e siccome
# mordersi la lingua COSTA (Limbico.trattieni), prima o poi qualcosa esce
# lo stesso, di sbieco. È così che si scoppia «per una sciocchezza».
func _tick_confronti(delta: float) -> void:
	if _player == null:
		return
	var pp: Vector3 = _player.global_position
	for r in _residents:
		var label := str(r.get("label", ""))
		if label == "" or not _animi.has(label):
			continue
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var animo: RefCounted = _animi[label]
		var d: float = pp.distance_to(node.global_position)

		if ANIMO.almeno(int(animo.gradino), "confronto"):
			# ti viene incontro: si ferma poco distante, non addosso
			var attesa: float = float(_in_confronto.get(label, 0.0)) - delta
			if d > 2.2:
				if attesa <= 0.0 and node.has_method("do_routine"):
					var verso: Vector3 = pp + (node.global_position - pp).normalized() * 1.6
					node.call("do_routine", "confronto", verso, pp)
					_in_confronto[label] = 4.0
				else:
					_in_confronto[label] = attesa
				continue
			# è arrivato: lo sfogo, una volta sola finché non cambia qualcosa
			if bool(r.get("sfogato", false)):
				continue
			r["sfogato"] = true
			if node.has_method("face_towards"):
				node.call("face_towards", pp)   # ti guarda in faccia
			_show_toast("%s: %s" % [label, animo.sfogo()])
			if node.has_method("chat_bubble"):
				node.call("chat_bubble", "!")
			node.set_meta("postura", "petto_in_fuori")
			continue

		# sotto il confronto: si trattiene. Ma la forza per farlo è finita.
		if d < 2.6 and ANIMO.almeno(int(animo.gradino), "svogliato"):
			var cd: float = float(_sussulto_cd.get("morso_" + label, 0.0)) - delta
			if cd > 0.0:
				_sussulto_cd["morso_" + label] = cd
				continue
			_sussulto_cd["morso_" + label] = 12.0
			if not animo.limbico.trattieni():
				# non ce l'ha fatta: qualcosa esce, di sbieco
				_show_toast(L10n.tf("%s: «…niente. Lascia stare.»", [label]))
				if node.has_method("chat_bubble"):
					node.call("chat_bubble", "…")
				node.set_meta("postura", "spalle_basse")


# LA STRADA VELOCE, ADDOSSO AL RESIDENTE. Quando Mochi arriva, il corpo del
# residente reagisce PRIMA che la testa abbia valutato qualcosa: chi ti teme
# trasalisce, chi ti vuole bene si illumina. È il segnale più onesto che il
# giocatore riceve — e arriva senza che nessuno debba parlargli.
func _tick_sussulti(delta: float) -> void:
	if _player == null:
		return
	var pp: Vector3 = _player.global_position
	for r in _residents:
		var label := str(r.get("label", ""))
		if label == "" or not _animi.has(label):
			continue
		var cd: float = float(_sussulto_cd.get(label, 0.0)) - delta
		if cd > 0.0:
			_sussulto_cd[label] = cd
			continue
		var node := r.get("node") as Node3D
		if node == null or pp.distance_to(node.global_position) > 3.2:
			continue
		var animo: RefCounted = _animi[label]
		var s: Dictionary = animo.limbico.percepisci("giocatore")
		_sussulto_cd[label] = 9.0
		match str(s.get("reazione", "nulla")):
			"trasalisce":
				node.set_meta("postura", "trasalisce")
				if node.has_method("chat_bubble"):
					node.call("chat_bubble", "!")
			"si_illumina":
				node.set_meta("postura", "si_illumina")
				if node.has_method("chat_bubble"):
					node.call("chat_bubble", "\u2665")


# ============================================ l'animo e il villaggio

# Iscrive un residente al grafo del villaggio e lo lega a chi già conosce,
# usando l'affinità che il cervello tiene da sempre: le voci corrono lungo
# le amicizie vere, non lungo un grafo inventato per l'occasione.
func _iscrivi_al_villaggio(key: String, animo: RefCounted) -> void:
	if _villaggio == null:
		_villaggio = VILLAGGIO.new()
		# reinietta la memoria dei partiti dal salvataggio: la cronaca
		# della rivolta ricorda il primo focolaio anche dopo un riavvio
		if not _partiti_salvati.is_empty():
			_villaggio.partiti = _partiti_salvati.duplicate(true)
	_villaggio.aggiungi(animo)
	var brain: RefCounted = _brains.get(key)
	for altro in _animi:
		if altro == key:
			continue
		var forza := 0.45
		if brain and brain.affinita.has(altro):
			forza = clampf(0.25 + float(brain.affinita[altro]) * 0.12, 0.0, 1.0)
		_villaggio.lega(key, altro, forza)


## Dove si svolge ogni lavoro. Serve perché il rancore non resti astratto: chi
## viene mandato novanta giorni alla catasta finisce per non sopportare più
## LA CATASTA, e gira al largo anche quando è libero. È il condizionamento
## del limbico (Limbico.marchi) applicato alla geografia del villaggio.
const LUOGO_DEL_LAVORO := {
	"taglia_legna": "catasta", "coltiva": "orto", "cucina": "cucina",
	"guardia": "confine", "esplora": "bosco",
}

## E dove si svolgono le ATTIVITÀ LIBERE che sceglie il cervello. Sono due
## vocabolari diversi — il giocatore ordina «coltiva», il cervello sceglie
## «cura_giardino» — e il ponte fra i due è il LUOGO: chi è stato costretto
## all'orto per novanta giorni non ci va più nemmeno di sua volontà.
## (Il filtro prima leggeva le chiavi dei lavori su nomi di attività: non
## poteva scattare mai. È il tipo di silenzio che non dà errori e non fa
## niente — il peggiore.)
const LUOGO_ATTIVITA := {
	"cura_giardino": "orto", "spuntino": "cucina", "meraviglia": "bosco",
}
## Dove ripiega chi cambia idea: deve essere un'attività che _recita CONOSCE,
## o il ripiego cadrebbe nel vuoto e il residente resterebbe immobile.
const RIPIEGO := "quattro_chiacchiere"

## Un compito assegnato dal giocatore passa di qui: è il canale che porta al
## risentimento. Chi sognava altro lo vive tre volte più amaro di chi quel
## lavoro lo amava — ed è per questo che due residenti mandati allo stesso
## posto finiscono in due punti diversi della scala.
func assegna_compito(label: String, compito: String) -> void:
	if not _animi.has(label):
		return
	var animo: RefCounted = _animi[label]
	animo.esegue(compito, "giocatore")
	# e il POSTO si carica di com'è andata: dopo abbastanza volte, quel posto
	# diventa qualcosa da evitare — senza che nessuno lo scriva
	var luogo := str(LUOGO_DEL_LAVORO.get(compito, ""))
	if luogo != "" and not animo.ricordi.is_empty():
		var ultimo: Dictionary = animo.ricordi[animo.ricordi.size() - 1]
		var sentito: float = float(ultimo.get("valenza", 0.0))
		if absf(sentito) > 0.25:
			animo.limbico._marchia("luogo|" + luogo, sentito)


## Un gesto bello verso un residente: i regali e le attenzioni SCIOLGONO il
## rancore. Senza questa porta il sistema sarebbe una condanna, non un
## dialogo — e il giocatore non avrebbe modo di rimediare.
func gesto_gentile(label: String, tipo := "regalo", peso := 0.8) -> void:
	if not _animi.has(label):
		return
	(_animi[label] as RefCounted).ricorda(tipo, "giocatore", peso, 0.9)
	# rimediare RIAPRE il discorso: se scende di gradino tornerà a cercarti
	# solo se glielo dai di nuovo il motivo
	for r in _residents:
		if str(r.get("label", "")) == label:
			r["sfogato"] = false
			return


## Il lutto di un residente: se nessuno lo consola, il rancore va a chi
## comanda il villaggio. È l'indifferenza a ferire, non la perdita.
func lutto_di(label: String, amico: String, consolato_da := "") -> void:
	if _animi.has(label):
		(_animi[label] as RefCounted).lutto(amico, consolato_da)


## LA FUNZIONE DELLA LEGGIBILITÀ: perché quel residente si comporta così.
## È ciò che il giocatore legge parlando con lui, ed è la differenza fra
## «questo gioco è profondo» e «questo gioco ha un bug».
func perche(label: String) -> String:
	if not _animi.has(label):
		return ""
	return (_animi[label] as RefCounted).racconta()


## Come sta il CORPO di un residente (guardingo, di malumore, a corto di
## pazienza…): è la riga che spiega una reazione sproporzionata.
func corpo_di(label: String) -> String:
	if not _animi.has(label):
		return ""
	return str((_animi[label] as RefCounted).limbico.stato_corpo())


## Il diario di un residente: la STORIA dei suoi scatti, giorno per giorno.
func diario_di(label: String) -> Array:
	if not _animi.has(label):
		return []
	return (_animi[label] as RefCounted).diario()


## Lo stato d'animo attuale (il gradino della scala), per la UI e i test.
func animo_di(label: String) -> String:
	if not _animi.has(label):
		return ""
	return (_animi[label] as RefCounted).stato()


## Il sogno di un residente ("boscaiolo", "cuoco"…). Serve al registro dei
## lavori per la resa: chi fa il lavoro che sognava produce di più.
func sogno_di(label: String) -> String:
	if not _animi.has(label):
		return ""
	return str((_animi[label] as RefCounted).sogno)


## La cronaca della rivolta, se ce n'è una: chi ha cominciato e perché.
func cronaca_villaggio() -> Array:
	if _villaggio == null:
		return ["Il villaggio è sereno."]
	return _villaggio.cronaca_rivolta()


# Un giorno di vita interiore: ognuno fa i conti con sé stesso, poi le voci
# girano. Chi scatta di gradino lo TELEGRAFA subito — postura e battuta —
# perché il giocatore possa accorgersene e correggere in tempo.
func _giorno_di_animo() -> void:
	if _villaggio == null:
		return
	for evento in _villaggio.simula_giorno():
		if str(evento.get("tipo", "")) != "scatto":
			continue
		var chi := str(evento["chi"])
		var animo: RefCounted = _animi.get(chi)
		if animo == null:
			continue
		var tel: Array = animo.telegrafo()
		_mostra_telegrafo(chi, tel)
		# solo i passaggi che contano finiscono nei toast: se avvisassimo a
		# ogni mugugno, il giocatore smetterebbe di leggere
		if ANIMO.almeno(int(animo.gradino), "rifiuto"):
			_show_toast("%s: «%s»" % [chi, L10n.t(str(tel[1]))])


# La postura e la battuta del gradino, addosso al residente.
func _mostra_telegrafo(label: String, tel: Array) -> void:
	for r in _residents:
		if str(r.get("label", "")) != label:
			continue
		var node := r.get("node") as Node3D
		if node == null:
			return
		node.set_meta("postura", str(tel[0]))
		if node.has_method("chat_bubble"):
			node.call("chat_bubble", "!")
		return


# ------------------------------------------------------- le stravaganze

# rare, innocue, indimenticabili: il tocco che rende ognuno SUO
func _quirk_tick(r: Dictionary, node: Node3D, brain: RefCounted, delta: float, t_ora: float) -> void:
	r["quirk_cd"] = float(r.get("quirk_cd", randf_range(20.0, 40.0))) - delta
	if float(r["quirk_cd"]) > 0.0:
		return
	r["quirk_cd"] = randf_range(45.0, 90.0)
	if str(node.get("_state")) not in ["r_idle", "r_wander", "r_sniff"]:
		return
	match str(brain.get("quirk")):
		"parla_ai_funghi":
			var fungo := _nearest_named(["Fungo"], node.global_position, 10.0)
			if fungo:
				node.call("do_task", "chat_fungo",
						fungo.global_position + Vector3(0.5, 0, 0.4), Callable())
				_vita_toast(L10n.tf("%s sta confidando un segreto a un fungo…", [r["label"]]))
		"paura_farfalle":
			if _cozy and int(_cozy.call("nearest_butterfly", node.global_position, 1.6)) >= 0:
				node.call("do_task", "startle", Vector3.ZERO, Callable())
				_vita_toast(L10n.tf("Una farfalla ha spaventato %s!", [r["label"]]))
		"canta_alla_luna":
			if t_ora >= 0.78 and t_ora < 0.95:
				node.call("do_task", "sing", Vector3.ZERO, Callable())
				_vita_toast(L10n.tf("♪ %s sta cantando alla luna.", [r["label"]]))
		"colleziona_sassolini":
			node.call("do_task", "sasso", Vector3.ZERO, Callable())
		"ballerino":
			node.call("do_task", "twirl", Vector3.ZERO, Callable())
		"pisolini_ovunque":
			if randf() < 0.4:
				node.call("do_task", "nap", Vector3.ZERO,
						func(): brain.satisfy("pisolino"))


# un solo racconto di vita ogni tanto: la quiete è il prodotto
func _vita_toast(testo: String) -> void:
	if _vita_cd > 0.0:
		return
	_vita_cd = 25.0
	_show_toast(testo)


# il piano del Regista per questo residente, o [] = routine di default
func _regia_plan(r: Dictionary, fase: String) -> Array:
	var regista := get_tree().get_first_node_in_group("regista")
	if regista == null:
		return []
	return regista.plan_for(r, fase)


func _nearest_named(names: Array, from: Vector3, max_d: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_d
	for item_name in names:
		for node in _build.get_placed_by_name(item_name):
			var d: float = (node as Node3D).global_position.distance_to(from)
			if d < best_d:
				best_d = d
				best = node
	return best


func _free_bench(from: Vector3) -> Node3D:
	for bench in _build.get_placed_by_name("Panchina"):
		if (bench as Node3D).global_position.distance_to(from) > 16.0:
			continue
		var taken := false
		for r in _residents:
			var node := r.get("node") as Node3D
			if node and is_instance_valid(node) and node.get("_routine_aux") == bench \
					and str(node.get("_state")) in ["walk", "r_bench"]:
				taken = true
				break
		if not taken:
			return bench
	return null


# due vicini si scambiano nuvolette: zero testo, tanta vita
func _chats(delta: float) -> void:
	_chat_acc -= delta
	if _chat_acc > 0.0:
		return
	_chat_acc = 3.5
	var chatty := ["r_idle", "r_wander", "r_sniff", "r_fire", "r_bench"]
	for i in _residents.size():
		for j in range(i + 1, _residents.size()):
			var a := _residents[i].get("node") as Node3D
			var b := _residents[j].get("node") as Node3D
			if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
				continue
			if a.call("is_hidden") or b.call("is_hidden"):
				continue
			if str(a.get("_state")) not in chatty or str(b.get("_state")) not in chatty:
				continue
			if a.global_position.distance_to(b.global_position) > 1.9:
				continue
			var key := "%d_%d" % [i, j]
			var now := Time.get_ticks_msec()
			if now - int(_pair_cd.get(key, -99999)) < 35000:
				continue
			_pair_cd[key] = now
			_run_chat(a, b)
			return


# le chiacchiere hanno un TEMA: la parola Chibiese detta a voce e il
# simbolo nella nuvoletta sono la stessa cosa — così si impara
const CHAT_TOPICS := {
	"fiore": "✿", "cibo": "!", "amico": "♥", "dormire": "z",
	"fuoco": "~", "pioggia": "…", "felice": "!",
}


func _res_of(node: Node3D) -> Dictionary:
	for r in _residents:
		if r.get("node") == node:
			return r
	return {}


func _run_chat(a: Node3D, b: Node3D) -> void:
	a.call("face_towards", b.global_position)
	b.call("face_towards", a.global_position)
	var ra := _res_of(a)
	var rb := _res_of(b)
	var brain_a: RefCounted = _ensure_brain(ra) if not ra.is_empty() else null
	var brain_b: RefCounted = _ensure_brain(rb) if not rb.is_empty() else null

	# il tema lo detta il momento: la pioggia, il falò della sera, un
	# RICORDO recente («ho visto un posto bellissimo…»), o la testolina
	var topic := "fiore"
	if _weather and _weather.is_raining():
		topic = "pioggia"
	elif brain_a and randf() < 0.35 and not (brain_a.ricordo_recente() as Array).is_empty():
		topic = str((brain_a.ricordo_recente() as Array)[0])
	elif _daynight and float(_daynight.get("time")) > 0.68:
		topic = ["fuoco", "dormire", "cibo", "amico"][randi() % 4]
	else:
		topic = ["fiore", "cibo", "amico", "felice"][randi() % 4]
	if not CHAT_TOPICS.has(topic):
		topic = "amico"

	# le chiacchiere nutrono l'amicizia (e il bisogno di compagnia)
	if brain_a and not rb.is_empty():
		brain_a.bump_affinita(str(rb["label"]))
		brain_a.satisfy("quattro_chiacchiere")
	if brain_b and not ra.is_empty():
		brain_b.bump_affinita(str(ra["label"]))
		brain_b.satisfy("quattro_chiacchiere")

	a.call("chat_bubble", CHAT_TOPICS[topic])
	a.call("speak", [topic, "~"], "neutro")
	var brontolone: bool = brain_b != null and brain_b.has_indole("brontolone")
	get_tree().create_timer(1.1).timeout.connect(func():
		if is_instance_valid(b):
			if brontolone:
				# brontola («bu…»), ma resta ad ascoltare: cuore di panna
				b.call("chat_bubble", "…")
				b.call("speak", ["no", "~"], "neutro")
			else:
				b.call("chat_bubble", CHAT_TOPICS[topic])
				# la risposta: d'accordo («ha!») o entusiasta
				b.call("speak", ["si", topic] if randf() < 0.5 else ["~", "felice"], "felice"))
	get_tree().create_timer(2.2).timeout.connect(func():
		if is_instance_valid(a):
			if randf() < 0.5:
				a.call("_spawn_heart")
			else:
				a.call("chat_bubble", "!"))


# i piccoli desideri: la stessa mente, ma dopo il trasloco
func _wishes(delta: float) -> void:
	_wish_acc -= delta
	if _wish_acc > 0.0:
		return
	_wish_acc = 2.5
	for r in _residents:
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var wish: Dictionary = r.get("wish", {})
		if wish.is_empty():
			r["wish"] = _gen_wish(r.get("dna", {}))
			_show_toast(L10n.tf("%s sogna %s vicino a casa…",
					[r["label"], L10n.t(str(WISH_ART[r["wish"]["item"]]))]))
			_build.request_save()
			continue
		if bool(wish.get("done", false)):
			continue
		var home := Vector3(r["cell"].x, 0, r["cell"].y)
		for it in _build.get_placed_by_name(str(wish["item"])):
			if (it as Node3D).global_position.distance_to(home) < 4.5:
				wish["done"] = true
				node.call("celebrate")
				# «ta-ki, mi-ka!» — grazie, amico
				node.call("speak", ["grazie", "amico"], "felice")
				_bump_friend(r, 2)
				get_tree().call_group("legami", "momento",
						str(r.get("dna", {}).get("name", "")), "desiderio", "")
				_show_toast(L10n.tf("%s è al settimo cielo: %s vicino a casa!",
						[r["label"], L10n.t(str(WISH_ART[wish["item"]]))]))
				if _mail:
					_mail.call("queue_letter", {
						"from": str(r.get("dna", {}).get("name", L10n.t("Un amico"))),
						"text": L10n.tf("Grazie per %s vicino a casa mia!\nOgni mattina gli do il buongiorno.",
								[L10n.t(str(WISH_ART[wish["item"]]))]),
						"gift": true,
					})
				if _sfx:
					_sfx.place_ok()
				_build.request_save()
				break


func _gen_wish(dna: Dictionary) -> Dictionary:
	var w: Dictionary = dna.get("weights", {})
	var best := "Fungo"
	var best_v := -99.0
	for entry in WISH_POOL:
		var v: float = float(w.get(entry[1], 0.5)) * randf_range(0.85, 1.15)
		if v > best_v:
			best_v = v
			best = entry[0]
	return {"item": best, "done": false}


func _bump_friend(r: Dictionary, amount: int) -> void:
	var before := int(r.get("friend", 0))
	r["friend"] = before + amount
	# il timido si scioglie: dal terzo cuoricino ricomincia a salutare
	var node := r.get("node") as Node3D
	if node and is_instance_valid(node):
		var brain: RefCounted = _ensure_brain(r)
		node.set("greet_enabled",
				not brain.has_indole("timido") or int(r["friend"]) >= 3)
	# al terzo cuoricino, la lettera d'amicizia
	if before < 3 and before + amount >= 3 and _mail:
		# due frasi intere invece di una desinenza incollata: il maschile e il
		# femminile sono DUE frasi da tradurre, non una stringa più una lettera
		# (in inglese quella lettera non ha dove andare)
		var grazie := "Mi trovo così bene nel villaggio.\nGrazie di essermi amica." \
				if randf() < 0.5 \
				else "Mi trovo così bene nel villaggio.\nGrazie di essermi amico."
		_mail.call("queue_letter", {
			"from": str(r.get("dna", {}).get("name", L10n.t("Un amico"))),
			"text": L10n.t(grazie),
			"gift": true,
		})
	# l'amicizia PIENA lascia un ricordo indossabile: la soglia e il capo
	# per archetipo li decide il guardaroba, qui si passa solo il conto
	if is_inside_tree():
		var arch := str(r.get("dna", {}).get("archetype", ""))
		if arch != "":
			get_tree().call_group("guardaroba", "unlock_amicizia", arch, int(r["friend"]))


# il regalo della zuppetta: i gusti vengono dal DNA
func _dish_target() -> Dictionary:
	if _cooking == null or not _cooking.call("has_dish"):
		return {}
	for r in _residents:
		var node := r.get("node") as Node3D
		if node and is_instance_valid(node) and not node.call("is_hidden") \
				and _player.global_position.distance_to(node.global_position) < 1.6:
			return r
	return {}


func _give_dish(r: Dictionary) -> void:
	# un piatto caldo non è solo un piatto: SCIOGLIE il rancore. È la porta
	# che rende il sistema dell'animo un dialogo invece che una condanna.
	gesto_gentile(str(r.get("label", "")), "piatto", 0.85)
	get_tree().call_group("regista", "note", "socievole")
	var dish: Dictionary = _cooking.call("take_dish")
	var node := r.get("node") as Node3D
	var w: Dictionary = r.get("dna", {}).get("weights", {})
	# chi ama il calduccio adora i piatti caldi, chi ama il giardino i freddi
	var loves_it: bool = bool(dish.get("warm", true)) == \
			(float(w.get("warmth", 0.5)) >= float(w.get("garden", 0.5)))
	node.call("face_towards", _player.global_position)
	var art := String(dish.get("art", "il"))
	var kind := String(dish.get("name", "zuppetta"))
	# se oggi è il suo compleanno, il piatto diventa la FESTA A SORPRESA
	var cal := get_tree().get_first_node_in_group("calendario")
	var dish_dna: Dictionary = r.get("dna", {})
	if cal and cal.call("is_birthday", str(dish_dna.get("name", ""))):
		cal.call("throw_party", str(dish_dna.get("name", "")), str(r["label"]), node)
		_bump_friend(r, 3)
		get_tree().call_group("legami", "momento",
				str(dish_dna.get("name", "")), "festa", "")
		_build.request_save()
		return
	# --- l'OFFERTA: zampine protese, inchino, il piatto che fluttua ---
	var mochi := _player.get_node_or_null("Mochi")
	var dir := ((node.global_position - _player.global_position) * Vector3(1, 0, 1)).normalized()
	if mochi:
		mochi.set("_yaw", atan2(-dir.x, -dir.z))
		mochi.call("hold_offer", true)
	var dish_col := Color("e8944a") if bool(dish.get("warm", true)) else Color("b04a7a")
	var bowl := _make_bowl(dish_col)
	add_child(bowl)
	bowl.global_position = _player.global_position + dir * 0.34 + Vector3(0, 0.55, 0)
	bowl.scale = Vector3.ONE * 0.05

	var tw := create_tween()
	# la ciotolina sboccia sulle zampine mentre Mochi si inchina
	tw.tween_property(bowl, "scale", Vector3.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if mochi:
		tw.parallel().tween_property(mochi, "pour", 1.0, 0.4) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.3)
	# il piatto fluttua fino alle zampine dell'amico
	tw.tween_property(bowl, "global_position",
			node.global_position + Vector3(0, 0.55, 0), 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# la reazione arriva COL piatto, non prima
	tw.tween_callback(func():
		if loves_it:
			_bump_friend(r, 2)
			get_tree().call_group("legami", "momento",
					str(r.get("dna", {}).get("name", "")), "piatto", kind)
			_show_toast(L10n.tf("%s ADORA %s %s!", [r["label"], art, kind]))
			if mochi:
				var jt := create_tween()
				jt.tween_property(mochi, "joy", 1.0, 0.42).set_trans(Tween.TRANS_SINE)
				jt.tween_callback(func(): mochi.set("joy", 0.0))
		else:
			_bump_friend(r, 1)
			_show_toast(L10n.tf("%s ringrazia sorridendo per %s %s.", [r["label"], art, kind]))
		if _sfx:
			_sfx.place_ok()
		if mochi:
			mochi.call("hold_offer", false)
		# IL CERCHIO SI CHIUDE: la ciotola non svanisce più a mezz'aria —
		# gliela si consegna, e lui la MANGIA davvero (Pasto.gd: annusa,
		# soffia se scotta, tre morsetti, e solo allora ringrazia).
		if node.has_method("mangia"):
			node.call("mangia", bowl, dish_col, bool(dish.get("warm", true)), loves_it)
		else:
			node.call("_spawn_heart")
			node.call("speak", ["grazie"], "neutro")
			var via := create_tween()
			via.tween_property(bowl, "scale", Vector3.ONE * 0.03, 0.28) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			via.tween_callback(bowl.queue_free))
	_build.request_save()


## Il gesto del regalo generalizzato: una porzione (ciotola) o un tesoro
## (pacchetto) scelto dalle Tasche. La reazione nasce dall'affinità col gusto
## del residente; il resto è la stessa coreografia di offerta di _give_dish.
func offer_item(r: Dictionary, item: Dictionary) -> void:
	if r.is_empty() or item.is_empty():
		return
	var node := r.get("node") as Node3D
	if node == null or not is_instance_valid(node):
		return
	get_tree().call_group("regista", "note", "socievole")
	var w: Dictionary = r.get("dna", {}).get("weights", {})
	var loves_it := _item_loved(item, w)
	node.call("face_towards", _player.global_position)
	var art := String(item.get("art", "il"))
	var what := "%s %s" % [art, String(item.get("name", "un regalo")).to_lower()]
	var is_treasure := String(item.get("kind", "dish")) == "treasure"
	var dna: Dictionary = r.get("dna", {})
	# se oggi è il suo compleanno, il regalo diventa la FESTA A SORPRESA
	var cal := get_tree().get_first_node_in_group("calendario")
	if cal and cal.call("is_birthday", str(dna.get("name", ""))):
		cal.call("throw_party", str(dna.get("name", "")), str(r["label"]), node)
		_bump_friend(r, 3)
		# la festa è il gesto gentile più grande: scioglie il rancore
		gesto_gentile(str(r.get("label", "")), "festa", 1.0)
		get_tree().call_group("legami", "momento", str(dna.get("name", "")), "festa", "")
		_build.request_save()
		return
	# --- l'OFFERTA: zampine protese, inchino, il dono che fluttua ---
	var mochi := _player.get_node_or_null("Mochi")
	var dir := ((node.global_position - _player.global_position) * Vector3(1, 0, 1)).normalized()
	if mochi:
		mochi.set("_yaw", atan2(-dir.x, -dir.z))
		mochi.call("hold_offer", true)
	var item_col := Color("e8944a") if bool(item.get("warm", true)) else Color("b04a7a")
	var prop: Node3D = _make_present() if is_treasure else _make_bowl(item_col)
	add_child(prop)
	prop.global_position = _player.global_position + dir * 0.34 + Vector3(0, 0.55, 0)
	prop.scale = Vector3.ONE * 0.05

	var tw := create_tween()
	tw.tween_property(prop, "scale", Vector3.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if mochi:
		tw.parallel().tween_property(mochi, "pour", 1.0, 0.4) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.3)
	tw.tween_property(prop, "global_position",
			node.global_position + Vector3(0, 0.55, 0), 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		# ogni dono si annoda al Filo Rosso (una volta al giorno per tipo)
		get_tree().call_group("legami", "momento", str(dna.get("name", "")),
				"regalo" if is_treasure else "piatto", String(item.get("name", "")).to_lower())
		# il dono arriva anche all'ANIMO: è l'unico canale con cui il giocatore
		# scioglie il rancore (senza, il sistema sarebbe una condanna)
		gesto_gentile(str(r.get("label", "")),
				"regalo" if is_treasure else "piatto",
				0.9 if loves_it else 0.55)
		# una PORZIONE si mangia (il rituale del Pasto la chiude davvero); un
		# tesoro invece si stringe al petto: le feste del corpo restano quelle
		var mangiabile: bool = not is_treasure and node.has_method("mangia")
		if loves_it:
			if not mangiabile:
				node.call("celebrate")
				node.call("speak", ["grazie", "felice"], "felice")
			_bump_friend(r, 2)
			_show_toast(L10n.tf("%s ADORA %s!", [r["label"], what]))
			if mochi:
				var jt := create_tween()
				jt.tween_property(mochi, "joy", 1.0, 0.42).set_trans(Tween.TRANS_SINE)
				jt.tween_callback(func(): mochi.set("joy", 0.0))
		else:
			if not mangiabile:
				node.call("_spawn_heart")
				node.call("speak", ["grazie"], "neutro")
			_bump_friend(r, 1)
			_show_toast(L10n.tf("%s ringrazia sorridendo per %s.", [r["label"], what]))
		if _sfx:
			_sfx.place_ok()
		if mochi:
			mochi.call("hold_offer", false)
		if mangiabile:
			node.call("mangia", prop, item_col, bool(item.get("warm", true)), loves_it)
		else:
			var via := create_tween()
			via.tween_property(prop, "scale", Vector3.ONE * 0.03, 0.28) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			via.tween_callback(prop.queue_free))
	_build.request_save()


# lo adorerebbe? l'affinità del modello, o il vecchio caldo-vs-giardino
func _item_loved(item: Dictionary, weights: Dictionary) -> bool:
	if _inventory:
		return _inventory.affinity(item.get("tags", []), weights) == _inventory.REACT_LOVES
	return bool(item.get("warm", true)) == \
			(float(weights.get("warmth", 0.5)) >= float(weights.get("garden", 0.5)))


## Il residente non nascosto più vicino entro raggio, o {} — usato dalle
## Tasche per sapere a chi stai per regalare.
func nearest_giftable_resident(pos: Vector3, radius: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := radius
	for r in _residents:
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node) or node.call("is_hidden"):
			continue
		var d: float = pos.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = r
	return best


# la ciotolina del piatto avanzato: legno chiaro, contenuto colorato
func _make_bowl(col: Color) -> Node3D:
	var bowl := Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("e8cfae")
	var body := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.11
	bm.bottom_radius = 0.075
	bm.height = 0.09
	body.mesh = bm
	body.material_override = wood
	bowl.add_child(body)
	var food := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.095
	fm.bottom_radius = 0.095
	fm.height = 0.03
	food.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = col
	food.material_override = fmat
	food.position = Vector3(0, 0.045, 0)
	bowl.add_child(food)
	return bowl


# ---------------------------------------------------------------- trasloco

# una casa libera = un Letto col tetto, non reclamato, non casa del giocatore
## C'è una casa pronta per un ospite (Letto coperto, libero, non di casa)?
## Lo usano gli Ordini del Gufo per sapere se un trasloco è davvero possibile.
func has_free_house() -> bool:
	return not _free_house().is_empty()


func _free_house() -> Dictionary:
	var home := get_node_or_null("../Home")
	for bed in _build.get_placed_by_name("Letto"):
		var cell := Vector2i(roundi(bed.position.x), roundi(bed.position.z))
		if not _build.has_cover(cell):
			continue
		if is_bed_claimed(cell):
			continue
		if home and home.call("is_home", cell):
			continue
		return _make_house(bed, cell)
	return {}


func _make_house(bed: Node3D, cell: Vector2i) -> Dictionary:
	# l'uscio: appena fuori dalla porta più vicina, o davanti al letto
	var front: Vector3 = bed.global_position + Vector3(0, 0, 1.6)
	var best_d := 4.0
	for door in _build.get_placed_by_name("Porta"):
		var dp: Vector3 = (door as Node3D).global_position
		var d := dp.distance_to(bed.global_position)
		if d < best_d:
			best_d = d
			var out: Vector3 = (dp - bed.global_position) * Vector3(1, 0, 1)
			front = dp + out.normalized() * 1.1
	front.y = 0.0
	return {"bed": bed, "cell": cell, "front": front}


# la casa ridotta al vettore di feature che la mente sa leggere
func _house_features(house: Dictionary) -> Dictionary:
	var f := {
		"roof": 1.0, "walls": 0.0, "door": 0.0, "window": 0.0,
		"comfort": 0.0, "garden": 0.0, "warmth": 0.0,
		"sunny": 0.0 if (_weather and _weather.is_raining()) else 1.0,
	}
	var bed := house.get("bed") as Node3D
	if not is_instance_valid(bed):
		return f  # letto demolito durante la visita: feature neutre
	var bp: Vector3 = bed.global_position
	var walls := 0
	for node in (_build.get("_placed")["edge"] as Dictionary).values():
		var n: String = (node as Node3D).get_meta("item_name", "")
		var d: float = (node as Node3D).global_position.distance_to(bp)
		if d > 3.4:
			continue
		match n:
			"Muro":
				walls += 1
			"Finestra":
				walls += 1
				f["window"] = 1.0
			"Porta":
				walls += 1
				f["door"] = 1.0
	f["walls"] = clampf(walls / 4.0, 0.0, 1.0)

	var comfort := 0
	var garden := 0
	for layer in [1, 2]:
		for node in (_build.get("_placed")[layer] as Dictionary).values():
			var n: String = (node as Node3D).get_meta("item_name", "")
			var d: float = (node as Node3D).global_position.distance_to(bp)
			if n in ["Comodino", "Tappeto", "Lampada", "Libreria", "Sedia", "Tavolino", "Sgabello"] and d < 3.0:
				comfort += 1
			elif n == "Camino" and d < 3.2:
				f["warmth"] = 1.0
			elif n in ["Aiuola", "Pianta", "Cespuglio", "Fungo", "Alberello"] and d < 4.5:
				garden += 1
	f["comfort"] = clampf(comfort / 4.0, 0.0, 1.0)
	f["garden"] = clampf(garden / 3.0, 0.0, 1.0)
	return f


## Gli archetipi non ancora rappresentati tra i residenti dati. PURA e
## statica (la testa il test): è la garanzia di varietà — con otto posti
## devono arrivare tutti e cinque, non un villaggio di soli gattini.
static func archetipi_mancanti(presenti: Array) -> Array:
	var visti := {}
	for a in presenti:
		visti[str(a)] = true
	var out := []
	for a in DNA.ARCHETYPES:
		if not visti.has(str(a)):
			out.append(str(a))
	return out


func _spawn_candidate(dna: Dictionary, house: Dictionary) -> void:
	# etichette UNICHE: animo, cervello, incarichi e salvataggio sono tutti
	# keyed sulla label (solo ~80 combinazioni possibili) — due omonimi
	# condividerebbero la stessa vita interiore. Se il caso la ripesca,
	# si rigenera il DNA finché la label non è nuova. E la VARIETÀ: finché
	# un archetipo manca all'appello, il prossimo candidato tende a essere
	# uno di quelli (tentativi limitati: se il caso si impunta, va bene
	# comunque chiunque — mai bloccare l'arrivo).
	var presenti := []
	for r in _residents:
		presenti.append(str((r.get("dna", {}) as Dictionary).get("archetype", "")))
	var mancanti := archetipi_mancanti(presenti)
	for _tent in 24:
		var label_ok := not _label_in_use(str(dna["label"]))
		var arche_ok: bool = mancanti.is_empty() or str(dna["archetype"]) in mancanti
		if label_ok and arche_ok:
			break
		dna = DNA.generate()
	_timer = randf_range(80.0, 160.0)
	_cand_label = str(dna["label"])
	_mind = MIND.new("chibi", int(_cand_visits.get(dna["name"], 0)), dna["weights"])
	_decided = false
	_welcomes = 0
	var v: Node3D = VISITOR.new()
	v.species = "chibi"
	v.dna = dna
	add_child(v)
	v.setup_candidate(house, ENTRIES[randi() % ENTRIES.size()], Vector3(0, 0, -9), Vector3(-2, 0, -15))
	v.finished.connect(func(): if _active == v: _active = null)
	_active = v
	var trait_line: String = (dna["traits"] as Array)[0]
	_show_toast(L10n.tf("C'è %s alla porta, valigia in zampa! (%s)",
			[_cand_label, L10n.t(trait_line)]))


## Il benvenuto del giocatore: scalda la mente e la fa parlare.
func welcome_candidate() -> void:
	if _active == null or _mind == null or _welcomes >= 3:
		return
	if not is_instance_valid((_active.get("_house") as Dictionary).get("bed")):
		return  # la casetta non c'è più: lascia che sia _decide a congedarlo
	_welcomes += 1
	get_tree().call_group("regista", "note", "socievole")
	get_tree().call_group("legami", "momento",
			str((_active.get("dna") as Dictionary).get("name", "")), "benvenuto", "")
	_mind.call("add_welcome")
	var f := _house_features(_active.get("_house"))
	var line: String = _mind.call("best_liked", f)
	var miss: String = _mind.call("most_missed", f)
	if _welcomes == 1 and miss != "":
		_show_toast(L10n.tf("«%s… però %s»", [line, miss]))
	else:
		_show_toast("«%s»" % line)
	# risponde al benvenuto nella sua lingua: ciao, casa!
	_active.call("speak", ["ciao", "casa"], "felice" if miss == "" else "neutro")
	_active.call("_spawn_heart")
	if _sfx:
		_sfx.ui_select()
		if _active.get("species") == "passerotto":
			_sfx.play("chirp1", -16.0, 1.15)


func _decide() -> void:
	_decided = true
	var house: Dictionary = _active.get("_house")
	# il letto può essere stato demolito durante la visita
	if not is_instance_valid(house.get("bed")):
		_show_toast(L10n.tf("«Oh… la casetta non c'è più.» E %s riparte col trolley.",
				[_cand_label]))
		_active.call("candidate_result", false, Vector3.ZERO)
		_mind = null
		return
	var f := _house_features(house)
	var p: float = _mind.call("evaluate", f)
	var dna: Dictionary = _active.get("dna")
	if p > 0.72:
		var cell: Vector2i = house["cell"]
		var newcomer := _active
		_residents.append({"species": "chibi", "cell": cell, "node": newcomer,
				"dna": dna, "label": _cand_label})
		newcomer.call("candidate_result", true, (house["bed"] as Node3D).global_position + Vector3(0.0, 0, 0.6))
		# il primo nodo sul Filo Rosso: il giorno della valigia
		get_tree().call_group("legami", "momento",
				str(dna.get("name", "")), "trasloco", "")
		# da qui in poi è un residente: libera lo slot delle visite
		_active = null
		_spawn_suitcase_prop(cell)
		_show_toast(L10n.tf("%s ha deciso: si trasferisce nel villaggio!", [_cand_label]))
		# gli Ordini del Gufo aspettano il primo abitante
		get_tree().call_group("gufo", "note_arrival")
		# un arrivo si incide sugli anelli del Grande Albero
		var gtree := get_tree().get_first_node_in_group("grande_albero")
		if gtree:
			gtree.engrave("♥", L10n.tf("%s si è trasferito nel villaggio", [_cand_label]))
		# e il nuovo abitante andrà a scrivere il compleanno sulla lavagna
		var cal := get_tree().get_first_node_in_group("calendario")
		if cal:
			cal.call("register_resident", str(dna.get("name", _cand_label)), _cand_label, newcomer)
		if _sfx:
			_sfx.place_ok()
			get_tree().create_timer(0.4).timeout.connect(func():
				# il timer sopravvive al nodo: guardia anti-freed
				if is_instance_valid(self) and _sfx: _sfx.build_open())
	else:
		_cand_visits[dna["name"]] = int(_cand_visits.get(dna["name"], 0)) + 1
		var miss: String = _mind.call("most_missed", f)
		_show_toast(L10n.tf("«Ci devo pensare… %s» E %s riparte col trolley.",
				[miss, _cand_label]))
		_active.call("candidate_result", false, Vector3.ZERO)
	_mind = null
	_build.request_save()


func _spawn_suitcase_prop(cell: Vector2i) -> void:
	var prop: Node3D = VISITOR.make_suitcase()
	prop.position = Vector3(cell.x + 0.55, 0.08, cell.y + 0.4)
	prop.rotation.y = 0.5
	add_child(prop)


# ---------------------------------------------------------------- raccolta

# il candidato aspetta sull'uscio: se ti avvicini puoi dargli il benvenuto
func _welcome_ready() -> bool:
	return _active != null and _active.get("mode") == "candidate" \
			and _active.get("_state") in ["c_wait", "c_inspect"] and _welcomes < 3 \
			and _player.global_position.distance_to(_active.global_position) < 1.7


func _update_welcome_prompt() -> void:
	if not _welcome_ready():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var wp: Vector3 = _active.global_position + Vector3(0, 0.85, 0)
	if cam.is_position_behind(wp):
		return
	_prompt_label.text = L10n.t("E — dai il benvenuto")
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


# un solo pannello, quattro voci in ordine di priorità: benvenuto,
# regalino a terra, porzione da regalare, sogno del residente
func _update_prompts() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_prompt.visible = false
		return
	if _welcome_ready():
		_update_welcome_prompt()
		return
	if _gift and _player.global_position.distance_to(_gift.global_position) <= 1.2:
		_update_gift_prompt()
		return
	if _inventory and _inventory.has_giftable():
		var gr := nearest_giftable_resident(_player.global_position, 1.8)
		if not gr.is_empty():
			var gnode := gr.get("node") as Node3D
			_show_prompt_at(L10n.tf("E / Tab — regala a %s", [str(gr.get("label", ""))]),
					gnode.global_position + Vector3(0, 1.0, 0), cam)
			return
	for r in _residents:
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node) or node.call("is_hidden"):
			continue
		var wish: Dictionary = r.get("wish", {})
		if wish.is_empty() or bool(wish.get("done", false)):
			continue
		if _player.global_position.distance_to(node.global_position) < 2.0:
			# e lo dice pure, in Chibiese: il concetto del desiderio
			var wish_concepts := {"Aiuola": "fiore", "Fungo": "cibo",
					"Cespuglio": "fiore", "Lampada": "casa", "Panchina": "casa"}
			node.call("speak", [wish_concepts.get(str(wish["item"]), "casa"), "~"], "domanda")
			_show_prompt_at(L10n.tf("«sogno %s vicino a casa…»",
					[L10n.t(str(WISH_ART[wish["item"]]))]),
					node.global_position + Vector3(0, 1.0, 0), cam)
			return
	_prompt.visible = false


func _show_prompt_at(text: String, wp: Vector3, cam: Camera3D) -> void:
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = text
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _update_gift_prompt() -> void:
	if _welcome_ready():
		return
	var cam := get_viewport().get_camera_3d()
	if _gift == null or cam == null:
		_prompt.visible = false
		return
	if _player.global_position.distance_to(_gift.global_position) > 1.2:
		_prompt.visible = false
		return
	var wp: Vector3 = _gift.global_position + Vector3(0, 0.55, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = L10n.t("E — raccogli il regalino")
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("saluta"):
		_saluta()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("interact"):
		return
	if _welcome_ready():
		welcome_candidate()
		get_viewport().set_input_as_handled()
		return
	if _gift and _player.global_position.distance_to(_gift.global_position) <= 1.2:
		_collect_gift()
		get_viewport().set_input_as_handled()
		return
	if _inventory and _inventory.has_giftable() and _pockets:
		var gr := nearest_giftable_resident(_player.global_position, 1.8)
		if not gr.is_empty():
			# il carretto ha la precedenza: se il mercante è a portata ed è
			# più vicino dell'amico, la E è del negozio, non del regalo
			# (altrimenti col taccuino pieno il mercante era irraggiungibile)
			var md := INF
			var cal := get_tree().get_first_node_in_group("calendario")
			if cal and cal.has_method("merchant_distance"):
				md = float(cal.call("merchant_distance", _player.global_position))
			var gd := INF
			var gnode := gr.get("node") as Node3D
			if gnode and is_instance_valid(gnode):
				gd = _player.global_position.distance_to(gnode.global_position)
			if md < 1.6 and md < gd:
				return   # la E prosegue fino a Calendar._merchant_trade
			_pockets.open_for_gift(gr)
			get_viewport().set_input_as_handled()


## T — Mochi saluta con la zampina; il vicino più caro si volta e
## risponde («ya-ho!» col cuoricino), dopo un attimo di reazione.
func _saluta() -> void:
	var mochi := _player.get_node_or_null("Mochi")
	if mochi:
		mochi.call("wave")
	var best: Node3D = null
	var best_r := {}
	var best_d := 4.5
	for r in _residents:
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node) or node.call("is_hidden"):
			continue
		var d: float = _player.global_position.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
			best_r = r
	if best:
		var nome := str((best_r.get("dna", {}) as Dictionary).get("name", ""))
		get_tree().create_timer(0.4).timeout.connect(func():
			if is_instance_valid(best):
				best.call("face_towards", _player.global_position)
				best.call("_spawn_heart")
				best.call("speak", ["ciao", "felice"], "felice")
				# la prima zampina alzata si annoda al Filo Rosso;
				# e a volte, salutandosi, un ricordo riaffiora
				get_tree().call_group("legami", "momento", nome, "primo_saluto", "")
				get_tree().call_group("legami", "ricorda", nome, best)
				# durante un lutto, la zampina alzata È la consolazione:
				# il Congedo sa chi sta aspettando un pensiero
				get_tree().call_group("congedo", "consolato",
						str(best_r.get("label", "")), nome))


func _collect_gift() -> void:
	if _gift_bob:
		_gift_bob.kill()
	# il dono del bosco diventa un Tesoro vero nelle Tasche (era solo testo)
	var what := ""
	if _inventory:
		var scheda: Dictionary = _inventory.add_random_gift(_gift_species, randi())
		if not scheda.is_empty():
			what = "%s %s" % [scheda.get("art", ""), scheda.get("name", "")]
			_build.request_save()
	if what == "":
		var gifts: Array = GIFTS[_gift_species]
		what = L10n.t(str(gifts[randi() % gifts.size()]))
	_show_toast(L10n.tf("%s ti ha lasciato %s!",
			[L10n.t(str(SPECIES_LABEL[_gift_species])), what]))
	# dai regali del passerotto nasce la sciarpina di lana
	if _gift_species == "passerotto":
		var wr := get_tree().get_first_node_in_group("guardaroba")
		if wr:
			wr.unlock("sciarpina_lana")
	var pos := _gift.global_position
	var tw := create_tween()
	tw.tween_property(_gift, "scale", Vector3.ONE * 0.03, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(_gift.queue_free)
	_gift = null
	if _sfx:
		_sfx.place_ok()
	# cuoricini di gratitudine
	for i in 3:
		get_tree().create_timer(0.15 * i).timeout.connect(func():
			_mini_heart(pos + Vector3(randf_range(-0.12, 0.12), 0.3, randf_range(-0.08, 0.08))))


func _mini_heart(pos: Vector3) -> void:
	var heart := Node3D.new()
	var pink := StandardMaterial3D.new()
	pink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pink.albedo_color = Color(1.0, 0.55, 0.68)
	for side: float in [-1.0, 1.0]:
		var b := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.035
		sm.height = 0.07
		b.mesh = sm
		b.material_override = pink
		b.position = Vector3(side * 0.026, 0.02, 0)
		heart.add_child(b)
	var tip := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.052
	cm.height = 0.07
	tip.mesh = cm
	tip.material_override = pink
	tip.position = Vector3(0, -0.025, 0)
	tip.rotation.x = PI
	heart.add_child(tip)
	heart.position = pos
	add_child(heart)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(heart, "position:y", pos.y + 0.6, 1.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(heart, "scale", Vector3.ONE * 0.2, 1.4).set_ease(Tween.EASE_IN)
	tw.tween_property(heart, "rotation:y", 2.0, 1.4)
	tw.chain().tween_callback(heart.queue_free)


# ---------------------------------------------------------------- UI

func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.reset_size()
	_toast.modulate.a = 0.0
	_toast.visible = true
	var vp_w := get_viewport().get_visible_rect().size.x
	_toast.position = Vector2(vp_w * 0.5 - _toast.size.x * 0.5, 64)
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.35)
	tw.tween_interval(2.8)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): _toast.visible = false)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	_prompt = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.95, 0.88, 0.92)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(0.62, 0.46, 0.34, 0.5)
	sb.set_border_width_all(2)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	_prompt.add_theme_stylebox_override("panel", sb)
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_prompt)
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 13)
	_prompt_label.add_theme_color_override("font_color", UI_BROWN)
	_prompt.add_child(_prompt_label)

	_toast = PanelContainer.new()
	var ts := sb.duplicate() as StyleBoxFlat
	ts.bg_color = Color(0.99, 0.96, 0.9, 0.96)
	ts.content_margin_left = 16.0
	ts.content_margin_right = 16.0
	ts.content_margin_top = 8.0
	ts.content_margin_bottom = 8.0
	_toast.add_theme_stylebox_override("panel", ts)
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_toast)
	_toast_label = Label.new()
	_toast_label.add_theme_font_size_override("font_size", 15)
	_toast_label.add_theme_color_override("font_color", Color("8a5a3a"))
	_toast.add_child(_toast_label)


# ---------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	var rows := []
	for r in _residents:
		var row := {"sp": r["species"], "x": r["cell"].x, "z": r["cell"].y,
				"dna": r.get("dna", {}), "label": r.get("label", ""),
				"friend": int(r.get("friend", 0)), "wish": r.get("wish", {})}
		# la vita interiore si salva con lui: bisogni, amicizie, ricordi
		var key := str(r.get("label", "?"))
		if _brains.has(key):
			row["brain"] = (_brains[key] as RefCounted).to_dict()
		if _animi.has(key):
			row["animo"] = (_animi[key] as RefCounted).save()
		rows.append(row)
	# la memoria dei PARTITI (chi ha acceso la miccia della rivolta) vive
	# nel grafo del villaggio, ricostruito da zero a ogni avvio: senza
	# salvarla, la cronaca perdeva il primo focolaio a ogni riavvio
	var partiti: Dictionary = _partiti_salvati
	if _villaggio != null:
		partiti = _villaggio.partiti
	return {"residents": rows, "cand_mem": _cand_visits,
			"villaggio": {"partiti": partiti}}


func load_extra(data: Dictionary) -> void:
	_cand_visits = data.get("cand_mem", {})
	var vdata: Dictionary = data.get("villaggio", {})
	_partiti_salvati = vdata.get("partiti", {})
	for row in data.get("residents", []):
		if row is not Dictionary:
			continue
		var species := str(row.get("sp", "chibi"))
		var cell := Vector2i(int(row.get("x", 0)), int(row.get("z", 0)))
		if is_bed_claimed(cell):
			continue
		# il letto deve esistere ancora, altrimenti il villager è partito
		for bed in _build.get_placed_by_name("Letto"):
			if Vector2i(roundi(bed.position.x), roundi(bed.position.z)) == cell:
				var house := _make_house(bed, cell)
				var v: Node3D = VISITOR.new()
				v.species = species
				var dna: Dictionary = row.get("dna", {})
				if not dna.is_empty():
					v.dna = dna
				add_child(v)
				v.setup_resident(house)
				_residents.append({"species": species, "cell": cell, "node": v,
						"dna": dna, "label": str(row.get("label", "")),
						"friend": int(row.get("friend", 0)), "wish": row.get("wish", {}),
						"brain": row.get("brain", {}),
						# senza questa riga l'animo salvato non tornava mai:
						# _ensure_brain lo cerca in r["animo"] (rancore, ricordi,
						# gradino di ribellione ripartivano da zero a ogni avvio)
						"animo": row.get("animo", {})})
				_spawn_suitcase_prop(cell)
				# il Filo Rosso lo riconosce (o lo adotta, dai salvataggi
				# di prima del Filo) e l'età gli torna addosso
				get_tree().call_group("legami", "registra_arrivo",
						str(dna.get("name", "")))
				_apply_eta.call_deferred()
				break


# ---------------------------------------------------------------- debug CLI

func debug_visit(species: String) -> void:
	if _active:
		_active.queue_free()
		_active = null
	_spawn(species)


func debug_candidate(seed_v := -1) -> void:
	if _active:
		_active.queue_free()
		_active = null
	var house := _free_house()
	if house.is_empty():
		return
	_spawn_candidate(DNA.generate(seed_v), house)


func debug_goto_wait() -> void:
	if _active == null:
		return
	_active.position = (_active.get("_house") as Dictionary)["front"]
	_active.call("_enter_state", "c_wait")


func debug_force_decide() -> void:
	if _active and not _decided:
		_decide()


func debug_add_resident(seed_v: int, pos: Vector3) -> void:
	var dna: Dictionary = DNA.generate(seed_v)
	var v: Node3D = VISITOR.new()
	v.species = "chibi"
	v.dna = dna
	add_child(v)
	v.setup_resident({"bed": null, "cell": Vector2i(999, 999), "front": pos})
	_residents.append({"species": "chibi", "cell": Vector2i(999, 999), "node": v,
			"dna": dna, "label": str(dna["label"]), "friend": 0,
			"wish": {"item": "Fungo", "done": true}})


func debug_gather_fire() -> void:
	for i in _residents.size():
		var node := _residents[i].get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var spot := _posto_al_falo(i)
		node.position = spot + Vector3(0.04, 0, 0.04)
		node.call("do_routine", "fire", spot, CLEARING)
		_residents[i]["phase"] = "fire"
		_residents[i]["next_act"] = 9999.0


func debug_force_chat() -> void:
	if _residents.size() >= 2:
		_run_chat(_residents[0]["node"], _residents[1]["node"])


func debug_stage_resident(i: int, pos: Vector3) -> void:
	var node := _residents[i].get("node") as Node3D
	node.position = pos
	node.call("_enter_state", "r_idle")
	# la fase CORRENTE, così _routine non azzera il next_act in scena
	_residents[i]["phase"] = _phase()
	_residents[i]["next_act"] = 9999.0


func debug_give_dish(i := 0) -> void:
	if i >= 0 and i < _residents.size():
		_give_dish(_residents[i])


## Per il bootstrap del salvataggio: insedia un residente VERO al letto
## nella cella data — DNA generato dal seed, casa, valigia e amicizia.
func debug_settle(seed_v: int, cell: Vector2i) -> void:
	for bed in _build.get_placed_by_name("Letto"):
		if Vector2i(roundi(bed.position.x), roundi(bed.position.z)) != cell:
			continue
		var dna: Dictionary = DNA.generate(seed_v)
		var house := _make_house(bed, cell)
		var v: Node3D = VISITOR.new()
		v.species = "chibi"
		v.dna = dna
		add_child(v)
		v.setup_resident(house)
		_residents.append({"species": "chibi", "cell": cell, "node": v,
				"dna": dna, "label": str(dna["label"]), "friend": 1, "wish": {}})
		_spawn_suitcase_prop(cell)
		return


## Per il bootstrap: via tutti i residenti (e i loro cervelli).
func debug_reset() -> void:
	for r in _residents:
		var node := r.get("node") as Node3D
		if node and is_instance_valid(node):
			node.queue_free()
	_residents.clear()
	_brains.clear()
	_animi.clear()
	_villaggio = null


func debug_brain(i: int) -> RefCounted:
	if i < 0 or i >= _residents.size():
		return null
	return _ensure_brain(_residents[i])


## Forza un'attività dell'agenda (per la verifica CLI). Vero se la
## scena è partita davvero.
func debug_force_activity(i: int, act: String) -> bool:
	if i < 0 or i >= _residents.size():
		return false
	var r := _residents[i]
	var node := r.get("node") as Node3D
	if node == null or not is_instance_valid(node) or node.call("is_hidden"):
		return false
	r["next_act"] = 9999.0
	r["phase"] = _phase()
	_recita(r, node, _ensure_brain(r), act, "day")
	return true


func debug_quirk(i: int, q: String) -> void:
	if i < 0 or i >= _residents.size():
		return
	var r := _residents[i]
	var brain: RefCounted = _ensure_brain(r)
	brain.set("quirk", q)
	r["quirk_cd"] = 0.0
	var node := r.get("node") as Node3D
	if node and is_instance_valid(node):
		var t_ora: float = float(_daynight.get("time")) if _daynight else 0.85
		_quirk_tick(r, node, brain, 0.0, t_ora)
