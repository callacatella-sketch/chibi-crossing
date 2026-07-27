class_name Nascondino
extends Node
## NASCONDINO NEL BOSCO — il verbo "giocare" coi vicini.
##
## Un vicino dall'indole giocherellona (chiacchierone, sognatore,
## mattiniero — e con un po' d'amicizia: non si gioca con gli sconosciuti)
## ti saltella incontro di giorno e propone nascondino. Avvicìnati per
## dire di sì: lui e altri due corrono nel bosco e si nascondono DIETRO
## COSE VERE — i tronchi caduti, i ceppi, i massi che CozyWorld ha
## davvero piantato lì (nascondigli()). Tu li cerchi prima del tramonto.
##
## Ed è qui che le indoli diventano gioco:
##   • il TIMIDO si nasconde benissimo — sceglie il nascondiglio più
##     lontano e non fa un fiato: lo scovi solo arrivandogli addosso;
##   • il CHIACCHIERONE non ce la fa proprio — ogni pochi secondi, se
##     sei nei paraggi, gli scappa la risatina in Chibiese («hi-hi-hi»)
##     e si tradisce;
##   • gli altri stanno nel mezzo.
##
## Trovarli è una festa piccola (risata, cuoricino); trovarli TUTTI prima
## del tramonto annoda il momento "nascondino" sul Filo Rosso di ciascuno
## e fa salire l'amicizia. Se il sole scende prima, escono da soli
## ridendo: rivincita domani — a nascondino non si perde mai davvero.
##
## Una proposta al giorno. Tutto riusa ciò che c'è: le routine di
## cammino dei Visitor ("sniff"), il Chibiese (la risata è VOCAB), il
## Filo Rosso (momento "nascondino"), l'amicizia (_bump_friend), il
## Regista (asse socievole).

const COZYW := preload("res://scenes/world/CozyWorld.gd")

const PROPOSITORI := ["chiacchierone", "sognatore", "mattiniero"]
const AMICIZIA_MINIMA := 2
const FINESTRA := Vector2(0.30, 0.60)   # la fetta di giorno per proporre
const PREAVVISO := 0.70                  # "il sole tocca gli alberi"
const TRAMONTO := 0.75
const N_NASCOSTI := 3
const RAGGIO_PROPOSTA := 20.0            # da quanto lontano si accorre a proporre
const ACCETTA_R := 1.7                   # dire di sì = avvicinarsi
const RISATINA_R := 9.0                  # il chiacchierone si tradisce da qui
const DIST_NASCONDIGLI := 7.0            # i tre non si ammucchiano
const BOSCO_Z := -18.0                   # i nascondigli buoni sono nel folto

var _stato := "quiete"     # quiete | proposta | conteggio | caccia
var _giorno_fatto := -1
var _proponente := {}      # {r, nodo}
var _nascosti: Array = []  # [{r, nodo, spot, tipo, indole, trovato, t_risata}]
var _t_poll := 0.0
var _t_conteggio := 0.0
var _t_proposta := 0.0
var _t_resta := 0.0
var _preavvisato := false

var _hud: CanvasLayer
var _hud_label: Label


func _ready() -> void:
	add_to_group("nascondino")
	_fai_hud()


func _process(delta: float) -> void:
	match _stato:
		"quiete":
			_t_poll += delta
			if _t_poll >= 5.0:
				_t_poll = 0.0
				_prova_a_proporre()
		"proposta":
			_t_proposta -= delta
			var nodo = _proponente.get("nodo")
			if _t_proposta <= 0.0 or not is_instance_valid(nodo):
				_toast("%s sorride: «magari domani!»" % _label(_proponente))
				_riposa()
				return
			var player := get_node_or_null("../../Player") as Node3D
			if player and player.global_position.distance_to(
					(nodo as Node3D).global_position) <= ACCETTA_R:
				_accettato()
		"conteggio":
			_t_conteggio -= delta
			var pronti := true
			for n in _nascosti:
				if not is_instance_valid(n["nodo"]):
					continue
				if (n["nodo"] as Node3D).global_position.distance_to(n["spot"]) > 1.6:
					pronti = false
			if pronti or _t_conteggio <= 0.0:
				# chi è rimasto indietro sgattaiola all'ultimo (di là dagli
				# alberi non si vede: nessuna magia in scena)
				for n in _nascosti:
					if is_instance_valid(n["nodo"]) and (n["nodo"] as Node3D) \
							.global_position.distance_to(n["spot"]) > 1.6:
						(n["nodo"] as Node3D).global_position = n["spot"]
				_stato = "caccia"
				_hud.visible = true
				_hud_label.text = "Nascondino nel bosco  ·  trovati 0/%d  ·  prima del tramonto" \
						% _nascosti.size()
				_toast("Pronti! Cercali nel bosco prima del tramonto.")
		"caccia":
			_caccia(delta)


# ------------------------------------------------------------- la proposta

func _prova_a_proporre() -> void:
	var dn := get_node_or_null("../../DayNight")
	if dn == null:
		return
	var oggi := int(dn.get("day"))
	if oggi == _giorno_fatto:
		return
	var ora := float(dn.get("time"))
	if ora < FINESTRA.x or ora > FINESTRA.y:
		return
	var visitors := get_node_or_null("../../Visitors")
	var player := get_node_or_null("../../Player") as Node3D
	if visitors == null or player == null:
		return
	# chi ha l'indole del gioco, l'amicizia giusta ed è a portata
	var candidati: Array = []
	for r in (visitors.get("_residents") as Array):
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("is_hidden") and bool(node.call("is_hidden")):
			continue
		if int(r.get("friend", 0)) < AMICIZIA_MINIMA:
			continue
		if node.global_position.distance_to(player.global_position) > RAGGIO_PROPOSTA:
			continue
		var brain = visitors.call("_ensure_brain", r)
		if brain and _indole_giocherellona(brain):
			candidati.append(r)
	if candidati.is_empty():
		return
	# una proposta al giorno: che nasca o meno, oggi ci abbiamo provato
	_giorno_fatto = oggi
	if randf() > 0.65:
		return
	var r: Dictionary = candidati[randi() % candidati.size()]
	var nodo := r["node"] as Node3D
	_proponente = {"r": r, "nodo": nodo}
	_stato = "proposta"
	_t_proposta = 30.0
	var accanto := player.global_position \
			+ Vector3(randf_range(-0.6, 0.6), 0, randf_range(0.7, 1.1))
	if nodo.has_method("do_routine"):
		nodo.call("do_routine", "sniff", accanto, player.global_position)
	if nodo.has_method("chat_bubble"):
		nodo.call("chat_bubble", "?")
	if nodo.has_method("speak"):
		nodo.call("speak", ["amico", "felice"], "domanda")
	_toast("%s ti saltella incontro: nascondino nel bosco! (avvicìnati per dire di sì)"
			% _label(_proponente))


static func _indole_giocherellona(brain) -> bool:
	for indole in PROPOSITORI:
		if brain.has_indole(indole):
			return true
	return false


func _accettato() -> void:
	# il sì è già una festa: il proponente saltella e ride
	var prop = _proponente.get("nodo")
	if is_instance_valid(prop):
		if prop.has_method("celebrate"):
			prop.call("celebrate")
		if prop.has_method("speak"):
			prop.call("speak", ["risata", "felice"], "felice")
	var visitors := get_node_or_null("../../Visitors")
	var cozy := get_parent()
	var player := get_node_or_null("../../Player") as Node3D
	if visitors == null or cozy == null or not cozy.has_method("nascondigli") \
			or player == null:
		_riposa()
		return

	# i nascondigli: nel folto del bosco, ben distanziati
	var spots: Array = filtra_bosco(cozy.call("nascondigli"))
	if spots.size() < N_NASCOSTI:
		_toast("Il bosco è troppo giovane per nascondersi: sarà per un'altra volta.")
		_riposa()
		return
	var scelti := scegli_sparsi(spots, N_NASCOSTI,
			int(get_node_or_null("../../DayNight").get("day")) if \
			get_node_or_null("../../DayNight") else 0)

	# la squadra: il proponente + due compagni (il timido, se c'è, viene
	# SEMPRE: è la sua occasione di brillare nascondendosi)
	var squadra: Array = [_proponente["r"]]
	var altri: Array = []
	var timido = null
	for r in (visitors.get("_residents") as Array):
		if r == _proponente["r"]:
			continue
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("is_hidden") and bool(node.call("is_hidden")):
			continue
		if node.global_position.distance_to(player.global_position) > 26.0:
			continue
		var brain = visitors.call("_ensure_brain", r)
		if timido == null and brain and brain.has_indole("timido"):
			timido = r
		else:
			altri.append(r)
	if timido != null:
		squadra.append(timido)
	while squadra.size() < N_NASCOSTI and not altri.is_empty():
		squadra.append(altri.pop_front())

	# l'assegnazione parla delle indoli: il timido nel posto più lontano
	var ordinati := assegna_per_indole(scelti, player.global_position,
			_indoli_di(visitors, squadra))
	_nascosti = []
	for i in squadra.size():
		var r: Dictionary = squadra[i]
		var nodo := r["node"] as Node3D
		var voce := {
			"r": r, "nodo": nodo,
			"spot": (ordinati[i]["pos"] as Vector3),
			"tipo": str(ordinati[i]["tipo"]),
			"indole": _indole_breve(visitors, r),
			"trovato": false,
			"t_risata": randf_range(4.0, 8.0),
			"t_resta": randf_range(4.0, 7.0),
		}
		_nascosti.append(voce)
		if nodo.has_method("do_routine"):
			nodo.call("do_routine", "sniff", voce["spot"], voce["spot"])
		if nodo.has_method("speak"):
			nodo.call("speak", ["risata"], "felice")
	_stato = "conteggio"
	_t_conteggio = 30.0
	_preavvisato = false
	var sfx = get_node_or_null(^"/root/Sfx")
	if sfx and sfx.has_method("place_ok"):
		sfx.place_ok()
	_toast("Conta fino a dieci! %s corrono a nascondersi nel bosco…"
			% ", ".join(PackedStringArray(_nomi())))


# --------------------------------------------------------------- la caccia

func _caccia(delta: float) -> void:
	var player := get_node_or_null("../../Player") as Node3D
	var dn := get_node_or_null("../../DayNight")
	if player == null:
		_riposa()
		return

	var trovati := 0
	for n in _nascosti:
		if bool(n["trovato"]):
			trovati += 1
			continue
		var nodo = n["nodo"]
		if not is_instance_valid(nodo):
			n["trovato"] = true      # partito a metà gioco: non blocca la conta
			continue
		var d: float = player.global_position.distance_to((nodo as Node3D).global_position)

		# il chiacchierone non resiste: la risatina lo tradisce
		if str(n["indole"]) == "chiacchierone" and d <= RISATINA_R:
			n["t_risata"] = float(n["t_risata"]) - delta
			if float(n["t_risata"]) <= 0.0:
				n["t_risata"] = randf_range(5.0, 9.0)
				if nodo.has_method("speak"):
					nodo.call("speak", ["risata"], "felice")

		# il timido va proprio scovato; il chiacchierone sbuca prima
		var soglia := raggio_trovato(str(n["indole"]))
		if d <= soglia:
			_trovato(n)
			trovati += 1
			continue

		# resta acquattato al suo posto (la routine evapora, si rinnova)
		n["t_resta"] = float(n["t_resta"]) - delta
		if float(n["t_resta"]) <= 0.0:
			n["t_resta"] = randf_range(5.0, 8.0)
			if nodo.has_method("do_routine"):
				nodo.call("do_routine", "sniff", n["spot"], n["spot"])

	_hud_label.text = "Nascondino nel bosco  ·  trovati %d/%d  ·  prima del tramonto" \
			% [trovati, _nascosti.size()]

	if trovati >= _nascosti.size():
		_vittoria()
		return

	# il sole non aspetta
	if dn:
		var ora := float(dn.get("time"))
		if not _preavvisato and ora >= PREAVVISO and ora < TRAMONTO:
			_preavvisato = true
			_toast("Il sole tocca gli alberi: ultimi minuti!")
		if ora >= TRAMONTO or bool(dn.call("is_night")):
			_tramonto()


func _trovato(n: Dictionary) -> void:
	n["trovato"] = true
	var nodo = n["nodo"]
	if not is_instance_valid(nodo):
		return
	if nodo.has_method("celebrate"):
		nodo.call("celebrate")
	if nodo.has_method("speak"):
		nodo.call("speak", ["risata", "felice"], "felice")
	if nodo.has_method("_spawn_heart"):
		nodo.call("_spawn_heart")
	match str(n["indole"]):
		"timido":
			_toast("Trovato! %s sbuca da dietro il %s, rosso rosso ma raggiante."
					% [_label(n), str(n["tipo"])])
		"chiacchierone":
			_toast("Trovato! %s non tratteneva più le risatine dietro il %s."
					% [_label(n), str(n["tipo"])])
		_:
			_toast("Trovato! %s ride di gusto dietro il %s."
					% [_label(n), str(n["tipo"])])
	# il trovato trotterella alla radura ad aspettare gli altri
	if nodo.has_method("do_routine"):
		var radura: Vector3 = COZYW.CLEARING_CENTER
		nodo.call("do_routine", "sniff",
				radura + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)),
				radura)


func _vittoria() -> void:
	var visitors := get_node_or_null("../../Visitors")
	var ritardo := 0.0
	for n in _nascosti:
		var nodo = n["nodo"]
		if not is_instance_valid(nodo):
			continue
		# le risate arrivano sfalsate: un coro di gioia, non un accordo
		get_tree().create_timer(ritardo).timeout.connect(func() -> void:
			if is_instance_valid(nodo):
				if nodo.has_method("celebrate"):
					nodo.call("celebrate")
				if nodo.has_method("speak"):
					nodo.call("speak", ["risata", "amico"], "felice"))
		ritardo += 0.45
		if visitors:
			visitors.call("_bump_friend", n["r"], 2)
		get_tree().call_group("legami", "momento",
				str((n["r"].get("dna", {}) as Dictionary).get("name", "")),
				"nascondino", "")
	get_tree().call_group("regista", "note", "nascondino")
	var sfx = get_node_or_null(^"/root/Sfx")
	if sfx and sfx.has_method("place_ok"):
		sfx.place_ok()
	_toast("Trovati tutti prima del tramonto! Il bosco è pieno di risate.")
	_riposa()


func _tramonto() -> void:
	for n in _nascosti:
		var nodo = n["nodo"]
		if not is_instance_valid(nodo):
			continue
		if not bool(n["trovato"]):
			# escono da soli, ridendo: a nascondino non si perde mai davvero
			if nodo.has_method("speak"):
				nodo.call("speak", ["risata"], "felice")
			if nodo.has_method("do_routine"):
				nodo.call("do_routine", "wander", Vector3.ZERO)
		elif get_node_or_null("../../Visitors"):
			get_node_or_null("../../Visitors").call("_bump_friend", n["r"], 1)
	_toast("Il sole scende: escono dai nascondigli ridendo. Rivincita domani!")
	_riposa()


func _riposa() -> void:
	_stato = "quiete"
	_proponente = {}
	_nascosti = []
	_hud.visible = false


# ------------------------------------------------------- la testa del gioco
# Pura e statica: il test la esercita senza bosco né tramonto.

## Solo i nascondigli nel folto (z oltre BOSCO_Z verso nord).
static func filtra_bosco(spots: Array) -> Array:
	var out: Array = []
	for s in spots:
		if (s["pos"] as Vector3).z < BOSCO_Z:
			out.append(s)
	return out


## Tre nascondigli SPARSI (mai ammucchiati), deterministici per giorno:
## greedy — a ogni giro il posto più lontano da quelli già scelti.
static func scegli_sparsi(spots: Array, n: int, seme: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("nascondino|%d" % seme)
	var resto := spots.duplicate()
	var out: Array = [resto.pop_at(rng.randi() % resto.size())]
	while out.size() < n and not resto.is_empty():
		var meglio := 0
		var dist_meglio := -1.0
		for i in resto.size():
			var d_min := 1e9
			for s in out:
				d_min = minf(d_min, (resto[i]["pos"] as Vector3) \
						.distance_to(s["pos"] as Vector3))
			if d_min > dist_meglio:
				dist_meglio = d_min
				meglio = i
		out.append(resto.pop_at(meglio))
	return out


## L'assegnazione racconta le indoli: il TIMIDO prende il nascondiglio
## più lontano dal cercatore (si nasconde benissimo), il CHIACCHIERONE
## il più vicino (tanto si tradisce comunque), gli altri il resto.
static func assegna_per_indole(scelti: Array, cercatore: Vector3,
		indoli: Array) -> Array:
	var per_dist := scelti.duplicate()
	per_dist.sort_custom(func(a, b):
		return (a["pos"] as Vector3).distance_to(cercatore) \
				> (b["pos"] as Vector3).distance_to(cercatore))
	var out: Array = []
	out.resize(indoli.size())
	var liberi: Array = []
	for i in indoli.size():
		liberi.append(i)
	# prima il timido (il più lontano), poi il chiacchierone (il più
	# vicino), poi gli altri in ordine
	for i in indoli.size():
		if str(indoli[i]) == "timido" and not per_dist.is_empty():
			out[i] = per_dist.pop_front()
			liberi.erase(i)
	for i in indoli.size():
		if str(indoli[i]) == "chiacchierone" and out[i] == null \
				and not per_dist.is_empty():
			out[i] = per_dist.pop_back()
			liberi.erase(i)
	for i in liberi:
		out[i] = per_dist.pop_front()
	return out


## Quanto devi avvicinarti per scovarlo: il timido va proprio raggiunto,
## il chiacchierone sbuca appena ti vede.
static func raggio_trovato(indole: String) -> float:
	match indole:
		"timido":
			return 1.9
		"chiacchierone":
			return 2.7
	return 2.2


## La finestra della proposta: giorno pieno, col tempo di giocare.
static func finestra_buona(ora: float) -> bool:
	return ora >= FINESTRA.x and ora <= FINESTRA.y


# ------------------------------------------------------------------ aiuti

func _indoli_di(visitors: Node, squadra: Array) -> Array:
	var out: Array = []
	for r in squadra:
		out.append(_indole_breve(visitors, r))
	return out


## L'indole che conta per il nascondino ("timido" | "chiacchierone" | "").
func _indole_breve(visitors: Node, r: Dictionary) -> String:
	var brain = visitors.call("_ensure_brain", r)
	if brain == null:
		return ""
	if brain.has_indole("timido"):
		return "timido"
	if brain.has_indole("chiacchierone"):
		return "chiacchierone"
	return ""


func _label(voce: Dictionary) -> String:
	var r: Dictionary = voce.get("r", {})
	return str(r.get("label", "un vicino"))


func _nomi() -> Array:
	var out: Array = []
	for n in _nascosti:
		out.append(_label(n))
	return out


func _fai_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 19
	_hud.visible = false
	add_child(_hud)
	_hud_label = Label.new()
	_hud_label.add_theme_font_size_override("font_size", 15)
	_hud_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_hud_label.add_theme_color_override("font_shadow_color", Color(0.2, 0.12, 0.1, 0.6))
	_hud_label.add_theme_constant_override("shadow_offset_y", 1)
	_hud_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hud_label.offset_top = 14.0
	_hud_label.offset_bottom = 40.0
	_hud_label.offset_left = -320.0
	_hud_label.offset_right = 320.0
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_hud_label)


func _toast(testo: String) -> void:
	var visitors := get_node_or_null("../../Visitors")
	if visitors:
		visitors.call("_show_toast", testo)