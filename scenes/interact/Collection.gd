extends Node

## Retino e collezione. Di giorno si acchiappano le farfalle del prato,
## di notte le lucciole (quelle vere, che spawmano vicino a te al calare
## del buio): E fa apparire il retino nella zampa di Mochi con una
## sventagliata elastica, la creaturina finisce nel barattolo — e i
## barattoli vanno in mostra sugli scaffali di ogni Libreria, col
## contatore. Collezionismo senza fretta: nessuna fuga, nessun fallimento.

const UI_BROWN := Color("6a4a3a")

# Nomi, colori e classi delle specie vengono dal BESTIARIO: una riga per
# specie, un posto solo (prima erano duplicati qui, in Economy e in CozyWorld,
# e avevano già cominciato a divergere). Qui restano i metodi che il resto del
# gioco chiedeva a questo nodo, ora sottili deleghe.
const CRIT := preload("res://scenes/world/Critters.gd")
var _jar_order: Array = CRIT.collezionabili()

## L'ordine delle vetrine dei barattoli (letto anche da Pockets).
func jar_order() -> Array:
	return _jar_order


## Il colore del barattolo di una specie (letto anche da Fishing).
func jar_color(kind: String) -> Color:
	return CRIT.colore(kind)


## "una farfalla dorata" — il nome dentro una frase.
func kind_label(kind: String) -> String:
	return CRIT.con_articolo(kind)


## Questa specie si prende con la canna (e non col retino)?
func is_fish(kind: String) -> bool:
	return CRIT.classe(kind) == "pesce"


var _player: Node3D
var _mochi: Node3D
var _cozy: Node3D
var _build: Node3D
var _daynight: Node3D
var _sfx

var _counts := {}
var _seen := {}          # specie incontrate almeno una volta (per l'enciclopedia:
                         # vendere l'ultimo esemplare non ti ri-nasconde la scheda)
var _busy := false
var _fireflies: Array[Dictionary] = []
var _ff_respawn := 0.0
var _bestiole: Array[Dictionary] = []   # cicale, scarabei, lumachine, rane
var _bst_respawn := 0.0
var _t := 0.0
var _libreria_count := -1

var _prompt: PanelContainer
var _prompt_label: Label
var _toast: PanelContainer
var _toast_label: Label


## La calma del giocatore (0..1): la scrive il Fiato Sospeso, ed è la
## stessa che moltiplicano tutte le altre paure del mondo.
var _calma := 0.0


## Il Fiato Sospeso pubblica quanto il prato si fida di te adesso.
func set_calma(q: float, _pos: Vector3) -> void:
	_calma = clampf(q, 0.0, 1.0)


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("calma_listener")
	_iscrivi_alla_e.call_deferred()
	_player = get_node("%Player")
	_mochi = _player.get_node("Mochi")
	_cozy = get_node_or_null("../CozyWorld")
	_build = get_node("../BuildSystem")
	_daynight = get_node_or_null("../DayNight")
	_sfx = get_node_or_null(^"/root/Sfx")
	if _build.has_signal("placed_changed"):
		_build.connect("placed_changed", func(): _displays_dirty = true)
	_build_ui()


func _is_night() -> bool:
	return _daynight != null and _daynight.is_night()


# ---------------------------------------------------------------- ciclo

var _displays_dirty := false


func _process(delta: float) -> void:
	_t += delta
	_update_fireflies(delta)
	_update_bestiole(delta)
	_update_prompt()
	# librerie piazzate/rimosse -> barattoli aggiornati (via segnale,
	# niente scansione completa a ogni frame)
	if _displays_dirty:
		_displays_dirty = false
		_libreria_count = _build.get_placed_by_name("Libreria").size()
		_refresh_displays()


# ---------------------------------------------------------------- lucciole

# al calare della notte, tre lucciole vere si accendono vicino a te
func _update_fireflies(delta: float) -> void:
	if _is_night():
		_ff_respawn -= delta
		if _fireflies.size() < 3 and _ff_respawn <= 0.0:
			_ff_respawn = randf_range(4.0, 10.0)
			_spawn_firefly()
	else:
		for f in _fireflies:
			(f["node"] as Node3D).queue_free()
		_fireflies.clear()

	# la fretta di Mochi: di corsa le lucciole si scansano, da ferma tornano
	var fretta := 0.0
	if _player:
		var pv: Variant = _player.get("velocity")
		if pv is Vector3:
			fretta = clampf((pv as Vector3).length() / 3.0, 0.0, 1.0)
	for f in _fireflies:
		var s: float = f["seed"]
		var base: Vector3 = f["base"]
		var node := f["node"] as Node3D
		var pos := base + Vector3(
			sin(_t * 0.7 + s) * 2.2,
			0.85 + sin(_t * 1.3 + s) * 0.3 + sin(_t * 5.0 + s) * 0.05,
			cos(_t * 0.9 + s * 2.0) * 2.2)
		# la timidezza: se arrivi di fretta la lucciola sale e scivola in
		# là, e il suo respiro si fa piccolo (si nasconde nella sua luce);
		# fermati un attimo e torna a danzarti attorno
		var dodge: Vector3 = f.get("dodge", Vector3.ZERO)
		var voglia := Vector3.ZERO
		if _player:
			var diff: Vector3 = (pos + dodge) - _player.global_position
			diff.y = 0.0
			var d := diff.length()
			if d < 1.8:
				var via := diff / maxf(d, 0.05)
				var forza := (1.8 - d) / 1.8
				# la CALMA (fonte unica: FiatoSospeso) spegne anche il
				# pavimento della paura: da immobile le lucciole vengono
				var paura := (0.18 + 0.82 * fretta) * forza * forza * (1.0 - _calma)
				voglia = via * paura * 1.1 + Vector3(0, 0.6 * paura, 0)
		dodge = dodge.lerp(voglia, 1.0 - exp(-2.6 * delta))
		f["dodge"] = dodge
		node.position = pos + dodge
		# il respiro luminoso (la paura lo smorza di un terzo, non di più:
		# una lucciola spaventata si vede ancora — solo più piccina)
		var blink := maxf(0.0, sin(_t * 2.3 + s))
		(f["halo_mat"] as StandardMaterial3D).albedo_color.a = \
				(0.15 + blink * blink * 0.6) * (1.0 - minf(dodge.length() * 0.4, 0.35))


func _spawn_firefly() -> void:
	# quale lucciola si accende lo dice il bestiario: quella di sempre, o —
	# nelle notti d'estate — la RARA lucciola regale: più grande, luce d'oro
	# caldo, mai più di una per volta (il suo `max` sta in Critters)
	var kind := "lucciola"
	if _cozy and _cozy.has_method("contesto_critter"):
		var vivi := {}
		for f in _fireflies:
			var k := str(f.get("kind", "lucciola"))
			vivi[k] = int(vivi.get(k, 0)) + 1
		var pool := []
		for id in CRIT.disponibili("lucciola", _cozy.call("contesto_critter")):
			if int(vivi.get(str(id), 0)) < CRIT.max_vivi(str(id)):
				pool.append(id)
		kind = CRIT.estrai(pool, randf())
		if kind == "":
			return
	var regale := kind == "regale"
	var glow_col := Color(1.0, 0.87, 0.45) if regale else Color(0.9, 1.0, 0.6)

	var node := Node3D.new()
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.046 if regale else 0.028
	sm.height = sm.radius * 2.0
	core.mesh = sm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color("ffe98a") if regale else Color("e8ffa8")
	cm.emission_enabled = true
	cm.emission = Color(1.0, 0.82, 0.4) if regale else Color(0.85, 1.0, 0.5)
	cm.emission_energy_multiplier = 2.6 if regale else 2.2
	core.material_override = cm
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(core)

	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5) if regale else Vector2(0.32, 0.32)
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([
		Color(glow_col, 0.8), Color(glow_col, 0.3), Color(glow_col, 0.0)])
	tex.gradient = grad
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.albedo_texture = tex
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = hm
	halo.mesh = quad
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(halo)

	var a := randf() * TAU
	var base: Vector3 = _player.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 7.0)
	base.y = 0.0
	add_child(node)
	_fireflies.append({"node": node, "seed": randf() * 100.0, "base": base,
			"halo_mat": hm, "kind": kind})


# ---------------------------------------------------------------- bestiole

# Le bestiole: chi si acchiappa col retino ma non vola nel prato — la cicala
# sugli alberi del bosco d'estate, lo scarabeo dorato nelle notti estive, la
# lumachina e la rana blu che escono solo con la pioggia. Chi c'è lo decide
# il bestiario (Critters.disponibile); qui si decide solo DOVE metterle e
# come si muovono. Massimo due per volta, come le lucciole.

var _bst_ctx_t := 0.0

func _update_bestiole(delta: float) -> void:
	if _cozy == null or not _cozy.has_method("contesto_critter"):
		return
	_bst_respawn -= delta
	# il contesto si ricalcola una volta al secondo (non a ogni frame): chi
	# non è più di stagione/ora/meteo se ne va — la pioggia che smette si
	# porta via la lumachina, l'alba spegne lo scarabeo
	_bst_ctx_t -= delta
	if _bst_ctx_t <= 0.0:
		_bst_ctx_t = 1.0
		var ctx: Dictionary = _cozy.call("contesto_critter")
		for i in range(_bestiole.size() - 1, -1, -1):
			if not CRIT.disponibile(str(_bestiole[i]["kind"]), ctx):
				(_bestiole[i]["node"] as Node3D).queue_free()
				_bestiole.remove_at(i)
		if _bestiole.size() < 2 and _bst_respawn <= 0.0:
			_bst_respawn = randf_range(6.0, 14.0)
			_spawn_bestiola(ctx)
	for b in _bestiole:
		_anima_bestiola(b, delta)


func _spawn_bestiola(ctx: Dictionary) -> void:
	var vivi := {}
	for b in _bestiole:
		var k := str(b["kind"])
		vivi[k] = int(vivi.get(k, 0)) + 1
	var pool := []
	for id in CRIT.disponibili("bestiola", ctx):
		if int(vivi.get(str(id), 0)) < CRIT.max_vivi(str(id)):
			pool.append(id)
	if pool.is_empty():
		return
	var kind := CRIT.estrai(pool, randf())
	# il posto giusto deve esistere: la cicala vuole un tronco del bosco
	# vicino, la rana la riva dello stagno — se qui non c'è, sarà per dopo
	var pp: Vector3 = _player.global_position
	var base := Vector3.ZERO
	var trunk := Vector3.ZERO
	match CRIT.luogo(kind):
		"bosco":
			var tree: Dictionary = _cozy.call("nearest_forest_tree", pp, 11.0)
			if tree.is_empty():
				return
			trunk = tree["pos"]
			var to_me := ((pp - trunk) * Vector3(1, 0, 1)).normalized()
			base = trunk + to_me * 0.22 + Vector3(0, 0.9 * float(tree["scale"]), 0)
		"stagno":
			var centro: Vector3 = _cozy.POND_CENTER
			if pp.distance_to(centro) > 10.0:
				return
			var dir := ((pp - centro) * Vector3(1, 0, 1)).normalized()
			if dir.length() < 0.5:
				dir = Vector3(1, 0, 0)
			base = centro + dir * (_cozy.POND_R + 0.5)
			base.y = 0.0
		_:
			var a := randf() * TAU
			base = pp + Vector3(cos(a), 0, sin(a)) * randf_range(2.5, 5.0)
			base.y = 0.0
	var node := _make_bestiola(kind)
	node.position = base
	node.scale = Vector3.ONE * 0.05
	add_child(node)
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bestiole.append({"node": node, "kind": kind, "seed": randf() * 100.0,
			"base": base, "trunk": trunk, "hop": randf_range(1.5, 3.5),
			"heading": randf() * TAU})


func _make_bestiola(kind: String) -> Node3D:
	var node := Node3D.new()
	var col: Color = CRIT.colore(kind)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = col
	match kind:
		"lumachina":
			# il corpicino morbido e il guscio a spirale
			var body := MeshInstance3D.new()
			var bm := CapsuleMesh.new()
			bm.radius = 0.03
			bm.height = 0.13
			body.mesh = bm
			var soft := StandardMaterial3D.new()
			soft.albedo_color = Color("e8ddc8")
			body.material_override = soft
			body.rotation.x = PI * 0.5
			body.position = Vector3(0, 0.03, 0)
			node.add_child(body)
			var shell := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.018
			tm.outer_radius = 0.05
			shell.mesh = tm
			shell.material_override = body_mat
			shell.rotation.x = PI * 0.5
			shell.rotation.z = PI * 0.5
			shell.position = Vector3(0, 0.075, 0.02)
			node.add_child(shell)
			var spira := MeshInstance3D.new()
			var sm2 := TorusMesh.new()
			sm2.inner_radius = 0.006
			sm2.outer_radius = 0.026
			spira.mesh = sm2
			var dark := StandardMaterial3D.new()
			dark.albedo_color = col.darkened(0.35)
			spira.material_override = dark
			spira.rotation.x = PI * 0.5
			spira.rotation.z = PI * 0.5
			spira.position = Vector3(0.001, 0.075, 0.02)
			node.add_child(spira)
			for side: float in [-1.0, 1.0]:
				var eye := MeshInstance3D.new()
				var em := SphereMesh.new()
				em.radius = 0.008
				em.height = 0.016
				eye.mesh = em
				var ed := StandardMaterial3D.new()
				ed.albedo_color = Color("4a3e33")
				eye.material_override = ed
				eye.position = Vector3(side * 0.014, 0.085, -0.065)
				node.add_child(eye)
		"rana":
			var body := MeshInstance3D.new()
			var bm := SphereMesh.new()
			bm.radius = 0.065
			bm.height = 0.13
			body.mesh = bm
			body.material_override = body_mat
			body.scale = Vector3(1.0, 0.72, 1.1)
			body.position = Vector3(0, 0.05, 0)
			node.add_child(body)
			var belly := MeshInstance3D.new()
			var lm := SphereMesh.new()
			lm.radius = 0.045
			lm.height = 0.09
			belly.mesh = lm
			var light := StandardMaterial3D.new()
			light.albedo_color = col.lightened(0.4)
			belly.material_override = light
			belly.position = Vector3(0, 0.035, -0.02)
			belly.scale = Vector3(0.9, 0.6, 0.9)
			node.add_child(belly)
			for side: float in [-1.0, 1.0]:
				var eye := MeshInstance3D.new()
				var em := SphereMesh.new()
				em.radius = 0.018
				em.height = 0.036
				eye.mesh = em
				var white := StandardMaterial3D.new()
				white.albedo_color = Color("fff6e6")
				eye.material_override = white
				eye.position = Vector3(side * 0.032, 0.105, -0.03)
				node.add_child(eye)
				var pup := MeshInstance3D.new()
				var pm := SphereMesh.new()
				pm.radius = 0.008
				pm.height = 0.016
				pup.mesh = pm
				var dk := StandardMaterial3D.new()
				dk.albedo_color = Color("2a1d1d")
				pup.material_override = dk
				pup.position = Vector3(side * 0.032, 0.108, -0.045)
				node.add_child(pup)
		"scarabeo":
			var body := MeshInstance3D.new()
			var bm := SphereMesh.new()
			bm.radius = 0.035
			bm.height = 0.07
			body.mesh = bm
			body_mat.metallic = 0.6
			body_mat.roughness = 0.25
			body_mat.emission_enabled = true
			body_mat.emission = Color(col.r, col.g * 0.85, col.b * 0.3)
			body_mat.emission_energy_multiplier = 0.5
			body.material_override = body_mat
			body.scale = Vector3(0.8, 0.55, 1.25)
			body.position = Vector3(0, 0.028, 0)
			node.add_child(body)
			var head := MeshInstance3D.new()
			var hm := SphereMesh.new()
			hm.radius = 0.016
			hm.height = 0.032
			head.mesh = hm
			var dk := StandardMaterial3D.new()
			dk.albedo_color = Color("6a5a2a")
			head.material_override = dk
			head.position = Vector3(0, 0.024, -0.045)
			node.add_child(head)
		_:  # cicala del bosco, appoggiata al tronco
			var body := MeshInstance3D.new()
			var bm := CapsuleMesh.new()
			bm.radius = 0.022
			bm.height = 0.09
			body.mesh = bm
			body.material_override = body_mat
			body.rotation.x = PI * 0.5
			node.add_child(body)
			for side: float in [-1.0, 1.0]:
				var wing := MeshInstance3D.new()
				var qm := QuadMesh.new()
				qm.size = Vector2(0.035, 0.1)
				var wm := StandardMaterial3D.new()
				wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				wm.albedo_color = Color(0.95, 0.97, 0.9, 0.55)
				wm.cull_mode = BaseMaterial3D.CULL_DISABLED
				qm.material = wm
				wing.mesh = qm
				wing.rotation.x = -PI * 0.45
				wing.rotation.z = side * 0.25
				wing.position = Vector3(side * 0.014, 0.012, 0.03)
				node.add_child(wing)
	return node


func _anima_bestiola(b: Dictionary, delta: float) -> void:
	var node := b["node"] as Node3D
	var s: float = b["seed"]
	var kind := str(b["kind"])
	match kind:
		"lumachina":
			# striscia piano piano, con l'ondina del guscio
			var dir := Vector3(cos(b["heading"]), 0, sin(b["heading"]))
			b["base"] = (b["base"] as Vector3) + dir * 0.028 * delta
			node.position = b["base"]
			node.rotation.y = -b["heading"] + PI * 0.5
			node.rotation.z = sin(_t * 2.0 + s) * 0.05
		"rana":
			# ferma che respira, poi il balzetto con lo splash morbido
			b["hop"] = float(b["hop"]) - delta
			if float(b["hop"]) <= 0.0:
				b["hop"] = randf_range(2.2, 4.5)
				var a := randf() * TAU
				var dest: Vector3 = (b["base"] as Vector3) + Vector3(cos(a), 0, sin(a)) * 0.35
				b["base"] = dest
				node.rotation.y = -a + PI * 0.5
				var tw := create_tween()
				tw.tween_property(node, "position",
						dest + Vector3(0, 0.22, 0), 0.16) \
						.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw.tween_property(node, "position", dest, 0.14) \
						.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			elif float(b["hop"]) > 0.5:
				node.scale.y = 1.0 + sin(_t * 3.0 + s) * 0.05
		"scarabeo":
			# corre a scatti brevi, col luccichio che pulsa
			b["hop"] = float(b["hop"]) - delta
			if float(b["hop"]) <= 0.0:
				b["hop"] = randf_range(1.2, 2.8)
				b["heading"] = randf() * TAU
			var dir := Vector3(cos(b["heading"]), 0, sin(b["heading"]))
			b["base"] = (b["base"] as Vector3) + dir * 0.32 * delta
			node.position = b["base"] + Vector3(0, absf(sin(_t * 14.0 + s)) * 0.006, 0)
			node.rotation.y = -b["heading"] + PI * 0.5
		_:  # cicala: sta sul tronco e fa frusciare le ali
			node.position = b["base"]
			node.rotation.y = sin(_t * 0.6 + s) * 0.2
			node.scale = Vector3.ONE * (1.0 + sin(_t * 22.0 + s) * 0.02)


# ---------------------------------------------------------------- cattura

func _nearest_catch() -> Dictionary:
	var pp: Vector3 = _player.global_position
	for i in _bestiole.size():
		var node := _bestiole[i]["node"] as Node3D
		if pp.distance_to(node.global_position) < 1.6:
			return {"type": "bestiola", "index": i}
	for i in _fireflies.size():
		var node := _fireflies[i]["node"] as Node3D
		if pp.distance_to(node.global_position) < 1.5:
			return {"type": "lucciola", "index": i}
	# le farfalle (e la falena, di notte: chi vola adesso lo sa il prato)
	if _cozy:
		var i: int = _cozy.call("nearest_butterfly", pp, 1.5)
		if i >= 0:
			return {"type": "farfalla", "index": i}
	return {}


# ---------------------------------------------------- l'arbitro della E
# Una farfalla che passa non ripassa: la retinata sta sul gradino FUGACE
# e batte semina, asciata e scavo — che saranno lì anche domani. Prima
# perdeva contro tutti e tre (era tredicesima nella catena).

## La distanza dalla creatura a portata di retino, o -1 se non ce n'è.
func distanza_e() -> float:
	if _busy or _player == null or not _player.is_physics_processing():
		return -1.0
	var t := _nearest_catch()
	if t.is_empty():
		return -1.0
	return 0.5


func agisci_e() -> void:
	var t := _nearest_catch()
	if not t.is_empty():
		_catch(t)


## COME SI CHIAMA cio' che hai davanti — «una farfalla dorata», non «una
## creaturina». Lo chiede il taccuino del Gufo quando ti fermi e non
## prendi: una lettera che cita la SPECIE e' impossibile da liquidare come
## generica, e la specie ce l'ha solo chi tiene in mano la bestiola.
##
## Il nome viene da Critters (fonte unica) e si ferma UN PASSO PRIMA della
## traduzione: la posta va su disco in italiano e si traduce all'apertura.
func bersaglio_umano() -> String:
	var t := _nearest_catch()
	if t.is_empty():
		return ""
	var kind := ""
	match str(t["type"]):
		"bestiola":
			kind = str(_bestiole[int(t["index"])].get("kind", ""))
		"lucciola":
			kind = str(_fireflies[int(t["index"])].get("kind", ""))
		"farfalla":
			if _cozy and _cozy.has_method("butterfly_kind"):
				kind = str(_cozy.call("butterfly_kind", int(t["index"])))
	if kind == "" or not CRIT.esiste(kind):
		return ""
	return CRIT.con_articolo_chiave(kind)


func _iscrivi_alla_e() -> void:
	var arb := get_tree().get_first_node_in_group("arbitro_e")
	if arb:
		arb.iscrivi(self, "retino", arb.FUGACE,
				Callable(self, "distanza_e"), Callable(self, "agisci_e"))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or _busy:
		return
	# player congelato da un pannello: niente retinate col menu aperto
	if _player == null or not _player.is_physics_processing():
		return
	var target := _nearest_catch()
	if target.is_empty():
		return
	_catch(target)
	get_viewport().set_input_as_handled()


func _catch(target: Dictionary) -> void:
	_busy = true
	var kind := ""
	var bug: Node3D = null
	if target["type"] == "lucciola":
		var f: Dictionary = _fireflies[target["index"]]
		kind = str(f.get("kind", "lucciola"))
		_fireflies.remove_at(target["index"])
		bug = f["node"]
	elif target["type"] == "bestiola":
		var f: Dictionary = _bestiole[target["index"]]
		kind = str(f["kind"])
		_bestiole.remove_at(target["index"])
		bug = f["node"]
	else:
		var got: Dictionary = _cozy.call("catch_butterfly", target["index"])
		kind = got["kind"]
		bug = got["node"]

	# Mochi si volta verso la preda gentile
	var dir := ((bug.global_position - _player.global_position) * Vector3(1, 0, 1)).normalized()
	_mochi.set("_yaw", atan2(-dir.x, -dir.z))

	# il retino sboccia NELLA zampa mentre il braccio CARICA all'indietro
	# (l'anticipazione è ciò che vende il colpo), poi la FRUSTATA
	var net := _make_net()
	_mochi.call("attach_to_paw", net)
	net.rotation.z = PI          # il manico prosegue oltre la zampa
	net.rotation.x = -0.35       # polso armato
	net.scale = Vector3.ONE * 0.05
	_mochi.call("hold_swing", true)

	var tw := create_tween()
	tw.tween_property(net, "scale", Vector3.ONE, 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.08)      # il respiro prima del colpo
	tw.tween_callback(func():
		if _sfx:
			_sfx.net_swish())
	# la frustata: rapida, con overshoot — e il colpo di polso del retino
	tw.tween_property(_mochi, "pour", 1.0, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(net, "rotation:x", 0.55, 0.2) \
			.set_trans(Tween.TRANS_SINE)
	# la creaturina scivola nel CERCHIO vero del retino, dov'è ADESSO
	tw.tween_callback(func():
		var hoop: Vector3 = net.to_global(Vector3(0, 0.58, 0))
		var bt := create_tween().set_parallel(true)
		bt.tween_property(bug, "global_position", hoop, 0.22) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		bt.tween_property(bug, "scale", Vector3.ONE * 0.15, 0.24)
		bt.chain().tween_callback(func():
			_sparkle(net.to_global(Vector3(0, 0.58, 0)),
					CRIT.colore(kind))
			bug.queue_free()))

	get_tree().create_timer(0.95).timeout.connect(func():
		if _sfx:
			_sfx.place_ok()
		add_catch(kind)
		# il recupero: la presa si scioglie, il retino svanisce
		_mochi.call("hold_swing", false)
		var nt := create_tween()
		nt.tween_property(net, "scale", Vector3.ONE * 0.03, 0.22) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		nt.tween_callback(net.queue_free)
		_busy = false)


func _make_net() -> Node3D:
	var net := Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("c89a6b")
	var handle := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.014
	hm.bottom_radius = 0.016
	hm.height = 0.55
	handle.mesh = hm
	handle.material_override = wood
	handle.position = Vector3(0, 0.27, 0)
	net.add_child(handle)
	var hoop := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.1
	tm.outer_radius = 0.115
	hoop.mesh = tm
	hoop.material_override = wood
	hoop.position = Vector3(0, 0.58, 0)
	net.add_child(hoop)
	var bag := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.015
	cm.height = 0.2
	bag.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1, 1, 1, 0.35)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bag.mesh = cm
	bag.material_override = bm
	bag.position = Vector3(0, 0.48, 0)
	net.add_child(bag)
	return net


## I conteggi della collezione, in sola lettura: le Tasche li mostrano
## nell'album (i barattoli veri restano sugli scaffali della Libreria).
func counts() -> Dictionary:
	return _counts.duplicate()


## Una specie è già stata incontrata? (Per l'enciclopedia delle Tasche: la
## scheda resta anche dopo aver venduto l'ultimo esemplare.)
func has_seen(kind: String) -> bool:
	return _seen.has(kind) or int(_counts.get(kind, 0)) > 0


## Aggiunge una cattura alla collezione: contatore, toast, vetrine, salvataggio.
## Usata anche dalla pesca.
func add_catch(kind: String) -> void:
	_counts[kind] = int(_counts.get(kind, 0)) + 1
	_seen[kind] = true
	get_tree().call_group("regista", "note", "pesca" if is_fish(kind) else "retino")
	# economia gentile: le catture rare regalano una stellina
	var eco := get_tree().get_first_node_in_group("economy")
	var got_star := (int(eco.award_catch(kind)) if eco and eco.has_method("award_catch") else 0)
	if got_star > 0:
		_show_toast(L10n.tf("%s — che rarità! Una stellina per te.",
				[CRIT.con_articolo(kind)]))
	else:
		_show_toast(L10n.tf("Hai preso %s! (n. %d)",
				[CRIT.con_articolo(kind), _counts[kind]]))
	# la prima di ogni specie finisce negli anelli del Grande Albero
	if int(_counts[kind]) == 1:
		var gtree := get_tree().get_first_node_in_group("grande_albero")
		if gtree:
			gtree.engrave("♦", L10n.tf("in collezione: %s", [CRIT.con_articolo(kind)]))
		# la prima lucciola (regale compresa) accende la lanterna da polso
		if CRIT.classe(kind) == "lucciola":
			var wr := get_tree().get_first_node_in_group("guardaroba")
			if wr:
				wr.unlock("lanterna_lucciola")
	_refresh_displays()
	_build.request_save()


## Toglie n esemplari di una specie dalla collezione (usato dal negozio per la
## vendita). Ritorna quanti ne restano.
func remove_catch(kind: String, n := 1) -> int:
	var cur := maxi(0, int(_counts.get(kind, 0)) - n)
	if cur <= 0:
		_counts.erase(kind)
	else:
		_counts[kind] = cur
	_refresh_displays()
	_build.request_save()
	return cur


## Quanti esemplari di una specie ci sono in collezione.
func count_of(kind: String) -> int:
	return int(_counts.get(kind, 0))


## Tutte le specie possedute con conteggio > 0 (per il negozio).
func owned_kinds() -> Array:
	var out := []
	for k in _jar_order:
		if int(_counts.get(k, 0)) > 0:
			out.append(k)
	return out


# ---------------------------------------------------------------- vetrina

## I barattoli in mostra su ogni Libreria: uno per specie collezionata.
func _refresh_displays() -> void:
	for lib in _build.get_placed_by_name("Libreria"):
		var old := (lib as Node3D).find_child("Jars", true, false)
		if old:
			# staccato subito: un nodo in queue_free tiene occupato il nome
			# fino a fine frame e il nuovo verrebbe rinominato in "Jars2"
			old.get_parent().remove_child(old)
			old.queue_free()
		var jars := Node3D.new()
		jars.name = "Jars"
		lib.add_child(jars)
		var xi := 0
		for kind in _jar_order:
			if int(_counts.get(kind, 0)) <= 0:
				continue
			var jar := _make_jar(kind, int(_counts[kind]))
			# due file da dieci: il bestiario è cresciuto (20 specie) e una
			# fila sola sborderebbe dal piano della Libreria
			jar.position = Vector3(-0.36 + (xi % 10) * 0.08, 1.55,
					0.07 - float(int(xi / 10.0)) * 0.14)
			jar.scale = Vector3.ONE * 0.8
			jars.add_child(jar)
			xi += 1


func _make_jar(kind: String, count: int) -> Node3D:
	var jar := Node3D.new()
	var glass := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 0.05
	gm.bottom_radius = 0.055
	gm.height = 0.11
	glass.mesh = gm
	var glm := StandardMaterial3D.new()
	glm.albedo_color = Color(0.8, 0.92, 0.95, 0.3)
	glm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glm.roughness = 0.15
	glass.material_override = glm
	glass.position = Vector3(0, 0.055, 0)
	jar.add_child(glass)
	var cork := MeshInstance3D.new()
	var km := CylinderMesh.new()
	km.top_radius = 0.045
	km.bottom_radius = 0.05
	km.height = 0.03
	cork.mesh = km
	var ckm := StandardMaterial3D.new()
	ckm.albedo_color = Color("c89a6b")
	cork.material_override = ckm
	cork.position = Vector3(0, 0.12, 0)
	jar.add_child(cork)

	var col: Color = CRIT.colore(kind)
	if is_fish(kind):
		# barattolo-acquario: acqua azzurrina e il pesciolino dentro
		var water := MeshInstance3D.new()
		var wm := CylinderMesh.new()
		wm.top_radius = 0.045
		wm.bottom_radius = 0.05
		wm.height = 0.08
		water.mesh = wm
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.55, 0.8, 0.9, 0.4)
		wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		water.material_override = wmat
		water.position = Vector3(0, 0.045, 0)
		jar.add_child(water)
		var fmat := StandardMaterial3D.new()
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fmat.albedo_color = col
		var fish_body := MeshInstance3D.new()
		var fb := SphereMesh.new()
		fb.radius = 0.022
		fb.height = 0.044
		fish_body.mesh = fb
		fish_body.material_override = fmat
		fish_body.position = Vector3(0.008, 0.055, 0)
		fish_body.scale = Vector3(1.5, 0.9, 0.7)
		jar.add_child(fish_body)
		var fish_tail := MeshInstance3D.new()
		var ft := CylinderMesh.new()
		ft.top_radius = 0.0
		ft.bottom_radius = 0.016
		ft.height = 0.026
		fish_tail.mesh = ft
		fish_tail.material_override = fmat
		fish_tail.position = Vector3(-0.036, 0.055, 0)
		fish_tail.rotation.z = -PI * 0.5
		jar.add_child(fish_tail)
	elif CRIT.classe(kind) == "lucciola":
		var glow := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.026 if kind == "regale" else 0.02
		sm.height = sm.radius * 2.0
		glow.mesh = sm
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = col
		gmat.emission_enabled = true
		gmat.emission = Color(1.0, 0.82, 0.4) if kind == "regale" else Color(0.85, 1.0, 0.5)
		gmat.emission_energy_multiplier = 1.6
		glow.material_override = gmat
		glow.position = Vector3(0, 0.06, 0)
		jar.add_child(glow)
	elif CRIT.classe(kind) == "bestiola":
		# la bestiola nel barattolo: un corpicino tondo col capino
		var bmat := StandardMaterial3D.new()
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bmat.albedo_color = col
		var corpo := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.024
		bm.height = 0.048
		corpo.mesh = bm
		corpo.material_override = bmat
		corpo.position = Vector3(0, 0.05, 0)
		corpo.scale = Vector3(1.0, 0.8, 1.25)
		jar.add_child(corpo)
		var capo := MeshInstance3D.new()
		var km2 := SphereMesh.new()
		km2.radius = 0.013
		km2.height = 0.026
		capo.mesh = km2
		var kmat := StandardMaterial3D.new()
		kmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		kmat.albedo_color = col.darkened(0.3)
		capo.material_override = kmat
		capo.position = Vector3(0, 0.055, -0.03)
		jar.add_child(capo)
	else:
		for side: float in [-1.0, 1.0]:
			var wing := MeshInstance3D.new()
			var wm := SphereMesh.new()
			wm.radius = 0.024
			wm.height = 0.048
			wing.mesh = wm
			var wmat := StandardMaterial3D.new()
			wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			wmat.albedo_color = col
			wing.material_override = wmat
			wing.position = Vector3(side * 0.018, 0.06, 0)
			wing.scale = Vector3(0.9, 1.2, 0.3)
			wing.rotation.z = side * -0.4
			jar.add_child(wing)

	if count > 1:
		var lbl := Label3D.new()
		lbl.text = "×%d" % count
		lbl.font_size = 26
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.modulate = Color(0.42, 0.3, 0.24, 0.95)
		lbl.outline_size = 8
		lbl.outline_modulate = Color(1, 1, 1, 0.9)
		lbl.position = Vector3(0, 0.19, 0)
		jar.add_child(lbl)
	return jar


func _sparkle(pos: Vector3, color: Color) -> void:
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([color, Color(color, 0.5), Color(color, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.08
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.7
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, -2.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var burst := GPUParticles3D.new()
	burst.amount = 14
	burst.lifetime = 0.6
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.local_coords = false
	burst.process_material = pm
	burst.draw_pass_1 = quad
	burst.position = pos
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(1.2).timeout.connect(burst.queue_free)


# ---------------------------------------------------------------- UI

func _update_prompt() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _busy:
		_prompt.visible = false
		return
	var target := _nearest_catch()
	if target.is_empty():
		_prompt.visible = false
		return
	# il prompt dice CHI stai per acchiappare: "una falena della luna" invita
	# più di un generico "la farfalla" (ed è il nome del bestiario, non un altro)
	var pos: Vector3
	var kind := ""
	if target["type"] == "lucciola":
		var f: Dictionary = _fireflies[target["index"]]
		pos = (f["node"] as Node3D).global_position
		kind = str(f.get("kind", "lucciola"))
	elif target["type"] == "bestiola":
		var f: Dictionary = _bestiole[target["index"]]
		pos = (f["node"] as Node3D).global_position
		kind = str(f["kind"])
	else:
		var b: Dictionary = _cozy.get("_butterflies")[target["index"]]
		pos = (b["node"] as Node3D).global_position
		kind = str(b["kind"])
	var text := L10n.tf("E — acchiappa %s!", [CRIT.con_articolo(kind)])
	var wp := pos + Vector3(0, 0.4, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = text
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.reset_size()
	_toast.modulate.a = 0.0
	_toast.visible = true
	var vp_w := get_viewport().get_visible_rect().size.x
	_toast.position = Vector2(vp_w * 0.5 - _toast.size.x * 0.5, 64)
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
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
	return {"collection": _counts, "collection_seen": _seen.keys()}


func load_extra(data: Dictionary) -> void:
	_counts = data.get("collection", {})
	# migrazione gentile: chi ha esemplari li ha per forza già visti
	_seen = {}
	for k in data.get("collection_seen", []):
		_seen[str(k)] = true
	for k in _counts:
		_seen[str(k)] = true
	_refresh_displays()


# ---------------------------------------------------------------- debug CLI

## Mette in scena una cattura vera: farfalla temporanea davanti a Mochi.
func debug_demo_catch() -> void:
	if _cozy == null:
		return
	_cozy.call("_make_butterfly", 0)
	var bfs: Array = _cozy.get("_butterflies")
	var b: Dictionary = bfs[bfs.size() - 1]
	b["seed"] = 0.0
	var fwd: Vector3 = -(_mochi.global_transform.basis.z).normalized()
	(b["node"] as Node3D).global_position = _player.global_position + fwd * 0.9 + Vector3(0, 0.8, 0)
	_catch({"type": "farfalla", "index": bfs.size() - 1})


func debug_fill() -> void:
	for kind in _jar_order:
		_counts[kind] = 1 + randi() % 4
	_refresh_displays()
