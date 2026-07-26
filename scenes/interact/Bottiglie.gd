extends Node

## I MESSAGGI IN BOTTIGLIA — il mondo oltre la cascata scrive al villaggio.
##
## Ogni tanto (mai più di una ogni due giorni) la cascata porta giù una
## bottiglia col tappo di sughero: entra in scena a valle del salto e
## scivola verso sud con la corrente, dondolando tra le ninfee, con un
## luccichio che la fa notare da lontano. Se nessuno la ripesca prima
## della fine del fiume se ne va — un'urgenza gentile, mai una punizione:
## un'altra arriverà. Con E dalla riva Mochi si sporge e la ripesca:
## dentro c'è SEMPRE una lettera di un mittente lontano (mai due volte la
## stessa finché il giro non si chiude) e un piccolo dono.
##
## Le decisioni (quando spunta, quale lettera, che dono) sono funzioni
## PURE e si provano headless in tests/cases/test_bottiglie.gd; il nodo
## fa solo la recita: corrente, dondolio, la zampa tesa, la carta crema.

const CRIT := preload("res://scenes/world/Critters.gd")
const UI_BROWN := Color("6a4a3a")

# la geografia della deriva: si entra a valle della cascata (FALL_Z = -4,
# vedi WorldMath) e si esce dove il fiume lascia il mondo
const SPAWN_Z := -2.0
const FINE_Z := 47.0
const VELOCITA := 0.45          # m/s: ~110 secondi di finestra per accorgersene
const PRESA := 2.6              # da quanto lontano si allunga la zampa
const OGNI_GIORNI := 2          # mai due bottiglie in due giorni
const PROB_GIORNO := 0.65       # la mattina buona non è garantita: si spera

## I mittenti di là dalla cascata. Ogni lettera arriva UNA volta per giro:
## solo quando le hai lette tutte il giro ricomincia.
const LETTERE := [
	{"da": "La lontra viaggiatrice",
		"testo": "Ho risalito tre fiumi e nessuno aveva un villaggio così.\nL'ho visto dall'orlo della cascata: sembrava una lanterna accesa.\nContinuate a tenere la luce, laggiù."},
	{"da": "Il capitano Gabbiano",
		"testo": "Questo fiume, per chi non lo sapesse, finisce nel MARE.\nUn giorno vi porto un po' di vento salato.\nNel frattempo: si naviga anche restando fermi."},
	{"da": "Nonna Castoro",
		"testo": "Sento battere i colpi d'ascia fin quassù, alla mia diga.\nChi costruisce non è mai solo: il legno si ricorda le zampe.\nMangia qualcosa di caldo, che l'autunno morde."},
	{"da": "Il pescatore di stelle",
		"testo": "Di notte pesco le stelle che cadono nel lago di sopra.\nSe ne vedi passare una, esprimi il desiderio per me:\ni miei li ho finiti tutti, e sono avanzate solo grazie."},
	{"da": "La rana del lago di sopra",
		"testo": "Se nello stagno trovi un girino con l'aria di chi sa il fatto suo,\nè uno dei miei. Digli che a casa va tutto bene\ne che la ninfea grande è ancora sua, se torna."},
	{"da": "La talpa cartografa",
		"testo": "Sto disegnando la mappa di tutto quel che c'è SOTTO.\nSotto il tuo prato passa una galleria che profuma di noccioline:\nqualcuno, tanto tempo fa, ci ha nascosto qualcosa."},
	{"da": "L'airone postino",
		"testo": "Consegno lettere da prima che esistessero le cassette.\nQuesta l'ho affidata all'acqua perché l'acqua non sbaglia strada.\nSe la stai leggendo, avevo ragione io."},
	{"da": "Una zampa sconosciuta",
		"testo": "Non so chi troverà questa bottiglia.\nSo che quando il mondo mi sembra troppo grande, ne scrivo una,\ne il fiume se la porta via. Ora il troppo è un po' di meno.\nGrazie."},
]

var _player: Node3D
var _mochi: Node3D
var _cozy: Node3D
var _daynight: Node3D
var _sfx

# lo stato che viaggia nel salvataggio
var _giorno_ultima := -99       # l'ultimo giorno in cui una bottiglia è spuntata
var _lette: Array = []          # indici delle lettere già lette (giro corrente)
var _attiva := false
var _z := 0.0

var _bottiglia: Node3D
var _glint_mat: StandardMaterial3D
var _t := 0.0
var _busy := false
var _reading := false
var _prima := true              # la prima bottiglia si incide sul Grande Albero

var _prompt: PanelContainer
var _prompt_label: Label
var _card: PanelContainer
var _card_da: Label
var _card_testo: Label
var _card_dono: Label


func _ready() -> void:
	add_to_group("persistable")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_ui()
	(func() -> void:
		_player = get_node_or_null("%Player")
		_mochi = _player.get_node("Mochi") if _player else null
		_cozy = get_node_or_null("../CozyWorld")
		_daynight = get_node_or_null("../DayNight")
		if _daynight and _daynight.has_signal("day_changed"):
			_daynight.day_changed.connect(_su_nuovo_giorno)
	).call_deferred()


# ---------------------------------------------------------- le decisioni (pure)

## Stamattina spunta una bottiglia? Mai con una già in acqua, mai prima di
## due giorni dall'ultima, e comunque non sempre: l'attesa fa parte del dono.
static func decide_spawn(giorno: int, giorno_ultima: int, attiva: bool, caso: float) -> bool:
	if attiva:
		return false
	if giorno - giorno_ultima < OGNI_GIORNI:
		return false
	return caso < PROB_GIORNO


## L'indice della prossima lettera: mai una già letta finché il giro non si
## chiude; a giro chiuso si ricomincia da capo (le lettere sono otto, la
## vita del villaggio è più lunga).
static func scegli_lettera(lette: Array, caso: float) -> int:
	var pool := []
	for i in LETTERE.size():
		if not (i in lette):
			pool.append(i)
	if pool.is_empty():
		for i in LETTERE.size():
			pool.append(i)
	return int(pool[int(clampf(caso, 0.0, 0.999999) * pool.size())])


## Il dono nella bottiglia: noccioline (metà delle volte), un sacchetto di
## ingredienti, la conchiglia di fiume, o — di rado — una stellina.
static func contenuto(caso: float) -> Dictionary:
	if caso < 0.50:
		return {"tipo": "noccioline", "n": 10 + int(caso * 30.0)}   # 10..24
	if caso < 0.75:
		return {"tipo": "ingredienti", "n": 2 + (int(caso * 100.0) % 2)}
	if caso < 0.90:
		return {"tipo": "tesoro", "id": "conchiglia_fiume"}
	return {"tipo": "stellina", "n": 1}


# ---------------------------------------------------------------- il ciclo

func _su_nuovo_giorno(giorno: int) -> void:
	if decide_spawn(giorno, _giorno_ultima, _attiva, randf()):
		_giorno_ultima = giorno
		_spawn()
		_salva()


func _process(delta: float) -> void:
	_t += delta
	if not _attiva or _bottiglia == null:
		_aggiorna_prompt()
		return
	# la corrente la porta a valle (verso sud, come le ninfee)
	_z += VELOCITA * delta
	if _z > FINE_Z:
		_via()
		return
	var wob := sin(_z * 0.5 + _t * 0.4) * 0.9
	_bottiglia.position = Vector3(
		_river_x(_z) + wob,
		_water_y() + 0.05 + sin(_t * 1.6) * 0.03,
		_z)
	_bottiglia.rotation.y += delta * 0.3
	_bottiglia.rotation.z = sin(_t * 1.1) * 0.18
	# il luccichio che la fa notare dalla riva
	if _glint_mat:
		var blink := maxf(0.0, sin(_t * 2.2))
		_glint_mat.albedo_color.a = 0.25 + blink * blink * 0.55
	_aggiorna_prompt()


func _river_x(z: float) -> float:
	return float(_cozy.call("river_x_at", z)) if _cozy else 18.6


func _water_y() -> float:
	return float(_cozy.RIVER_WATER_Y) if _cozy else -0.45


# la bottiglia non ripescata esce dal mondo in punta di piedi
func _via() -> void:
	_attiva = false
	if _bottiglia:
		var b := _bottiglia
		_bottiglia = null
		var tw := create_tween()
		tw.tween_property(b, "scale", Vector3.ONE * 0.02, 0.6) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(b.queue_free)
	_salva()


# ---------------------------------------------------------------- la recita

func _spawn() -> void:
	_attiva = true
	_z = SPAWN_Z
	_bottiglia = _fai_bottiglia()
	_bottiglia.position = Vector3(_river_x(_z), _water_y() + 0.05, _z)
	_bottiglia.scale = Vector3.ONE * 0.05
	add_child(_bottiglia)
	var tw := create_tween()
	tw.tween_property(_bottiglia, "scale", Vector3.ONE, 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _sfx:
		_sfx.plop()


func _fai_bottiglia() -> Node3D:
	var node := Node3D.new()
	# il vetro verde-acqua, coricato sull'acqua
	var vetro := MeshInstance3D.new()
	var vm := CylinderMesh.new()
	vm.top_radius = 0.05
	vm.bottom_radius = 0.06
	vm.height = 0.22
	vetro.mesh = vm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.62, 0.82, 0.72, 0.5)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.1
	vetro.material_override = gm
	vetro.rotation.z = PI * 0.5
	node.add_child(vetro)
	# il collo e il sughero
	var collo := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.022
	cm.bottom_radius = 0.032
	cm.height = 0.07
	collo.mesh = cm
	collo.material_override = gm
	collo.rotation.z = PI * 0.5
	collo.position = Vector3(0.14, 0, 0)
	node.add_child(collo)
	var tappo := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.02
	tm.bottom_radius = 0.024
	tm.height = 0.035
	tappo.mesh = tm
	var km := StandardMaterial3D.new()
	km.albedo_color = Color("c89a6b")
	tappo.material_override = km
	tappo.rotation.z = PI * 0.5
	tappo.position = Vector3(0.185, 0, 0)
	node.add_child(tappo)
	# il rotolino di carta, in controluce dentro il vetro
	var carta := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.025
	rm.bottom_radius = 0.025
	rm.height = 0.12
	carta.mesh = rm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.99, 0.96, 0.88)
	carta.material_override = pm
	carta.rotation.z = PI * 0.5
	node.add_child(carta)
	# il luccichio (lo stesso trucco delle lucciole: un billboard additivo)
	var glint := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.95, 0.7, 0.8), Color(1.0, 0.95, 0.7, 0.3), Color(1.0, 0.95, 0.7, 0.0)])
	tex.gradient = grad
	_glint_mat = StandardMaterial3D.new()
	_glint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glint_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glint_mat.albedo_texture = tex
	_glint_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = _glint_mat
	glint.mesh = quad
	glint.material_override = _glint_mat
	glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glint.position = Vector3(0, 0.12, 0)
	node.add_child(glint)
	return node


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if _reading:
		_chiudi_card()
		get_viewport().set_input_as_handled()
		return
	if _busy or not _attiva or _bottiglia == null:
		return
	if _player == null or not _player.is_physics_processing():
		return
	if _player.global_position.distance_to(_bottiglia.global_position) > PRESA:
		return
	_ripesca()
	get_viewport().set_input_as_handled()


func _ripesca() -> void:
	_busy = true
	_attiva = false
	var b := _bottiglia
	_bottiglia = null
	# Mochi si volta verso l'acqua e si sporge
	var dir := ((b.global_position - _player.global_position) * Vector3(1, 0, 1)).normalized()
	_mochi.set("_yaw", atan2(-dir.x, -dir.z))
	_mochi.call("hold_reach", true)
	if _sfx:
		_sfx.play("step_wet1", -14.0, 1.2)
	# la bottiglia vola in un arco fino alle zampine
	var dest: Vector3 = _player.global_position + Vector3(0, 1.05, 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(b, "global_position:x", dest.x, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(b, "global_position:z", dest.z, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(b, "global_position:y", dest.y + 0.5, 0.24) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(b, "global_position:y", dest.y, 0.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(b, "rotation:z", 0.0, 0.45)
	tw.chain().tween_callback(func() -> void:
		# POP: il sughero salta e la lettera si apre
		if _sfx:
			_sfx.place_ok()
		var st := create_tween()
		st.tween_property(b, "scale", Vector3.ONE * 0.02, 0.25) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		st.tween_callback(b.queue_free)
		_apri())


func _apri() -> void:
	var i := scegli_lettera(_lette, randf())
	if not (i in _lette):
		_lette.append(i)
	# giro chiuso: si riparte con la memoria pulita (i era il primo del nuovo giro)
	if _lette.size() >= LETTERE.size():
		_lette = [i]
	var dono := contenuto(randf())
	var lettera: Dictionary = LETTERE[i]
	_card_da.text = "~  %s  ~" % str(lettera["da"])
	_card_testo.text = str(lettera["testo"])
	_card_dono.text = _consegna_dono(dono)
	_card.visible = true
	_reading = true
	_busy = false
	if _mochi:
		_mochi.call("hold_reach", false)
	# la prima bottiglia della vita del villaggio va negli anelli
	if _prima:
		_prima = false
		var gtree := get_tree().get_first_node_in_group("grande_albero")
		if gtree:
			gtree.engrave("♦", "una bottiglia da oltre la cascata")
	_salva()


## Applica il dono e ritorna la riga da mostrare in calce alla lettera.
func _consegna_dono(dono: Dictionary) -> String:
	var eco := get_tree().get_first_node_in_group("economy")
	match str(dono["tipo"]):
		"noccioline":
			var n := int(dono["n"])
			if eco:
				eco.add_nuts(n)
			return "Nel fondo: %d noccioline. 🌰" % n
		"ingredienti":
			var cucina := get_node_or_null("../Cooking")
			var scelte := ["carota", "zucca", "bacca", "fungo"]
			var presi: Array[String] = []
			for k in int(dono["n"]):
				var id: String = scelte[randi() % scelte.size()]
				if cucina:
					cucina.add_ingredient(id, 1)
				presi.append(CRIT.nome(id))
			return "Nel fondo: %s, per la dispensa." % ", ".join(presi)
		"tesoro":
			var inv := get_node_or_null("../Inventory")
			if inv:
				inv.add_treasure(str(dono["id"]), 1)
			return "E incastrata nel vetro: una conchiglia di fiume."
		_:
			if eco:
				eco.add_stars(1)
			return "E sul fondo, una stellina. ⭐"


func _chiudi_card() -> void:
	_reading = false
	_card.visible = false
	if _sfx:
		_sfx.build_close()


# ---------------------------------------------------------------- UI

func _aggiorna_prompt() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _busy or _reading or not _attiva or _bottiglia == null \
			or _player == null:
		_prompt.visible = false
		return
	if _player.global_position.distance_to(_bottiglia.global_position) > PRESA:
		_prompt.visible = false
		return
	var wp: Vector3 = _bottiglia.global_position + Vector3(0, 0.45, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = "E — ripesca la bottiglia!"
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


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

	# la lettera: carta crema al centro, come la posta del mattino
	_card = PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.99, 0.96, 0.89, 0.97)
	cs.set_corner_radius_all(16)
	cs.border_color = Color(0.62, 0.46, 0.34, 0.6)
	cs.set_border_width_all(2)
	cs.content_margin_left = 26.0
	cs.content_margin_right = 26.0
	cs.content_margin_top = 18.0
	cs.content_margin_bottom = 16.0
	cs.shadow_color = Color(0.25, 0.15, 0.1, 0.3)
	cs.shadow_size = 14
	_card.add_theme_stylebox_override("panel", cs)
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_card)
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.offset_left = -230.0
	_card.offset_right = 230.0
	_card.offset_top = -140.0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_card.add_child(box)
	_card_da = Label.new()
	_card_da.add_theme_font_size_override("font_size", 16)
	_card_da.add_theme_color_override("font_color", Color("8a5a3a"))
	_card_da.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_card_da)
	_card_testo = Label.new()
	_card_testo.add_theme_font_size_override("font_size", 13)
	_card_testo.add_theme_color_override("font_color", UI_BROWN)
	_card_testo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_testo.custom_minimum_size = Vector2(400, 0)
	box.add_child(_card_testo)
	_card_dono = Label.new()
	_card_dono.add_theme_font_size_override("font_size", 13)
	_card_dono.add_theme_color_override("font_color", Color("a83a5c"))
	_card_dono.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_card_dono)
	var chiudi := Label.new()
	chiudi.text = "E — chiudi"
	chiudi.add_theme_font_size_override("font_size", 11)
	chiudi.add_theme_color_override("font_color", Color(0.42, 0.29, 0.23))
	chiudi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(chiudi)


# ---------------------------------------------------------------- persistenza

func _salva() -> void:
	var build := get_tree().get_first_node_in_group("build_system")
	if build:
		build.call("request_save")


func save_extra() -> Dictionary:
	return {"bottiglie": {
		"ultima": _giorno_ultima,
		"lette": _lette,
		"attiva": _attiva,
		"z": _z,
		"prima": _prima,
	}}


func load_extra(data: Dictionary) -> void:
	var d: Variant = data.get("bottiglie")
	if not (d is Dictionary):
		return
	_giorno_ultima = int(d.get("ultima", -99))
	_prima = bool(d.get("prima", true))
	_lette = []
	for i in d.get("lette", []):
		_lette.append(int(i))
	# salvato e uscito con la bottiglia in acqua: rieccola dov'era
	if bool(d.get("attiva", false)) and not _attiva:
		_z = clampf(float(d.get("z", SPAWN_Z)), SPAWN_Z, FINE_Z - 1.0)
		(func() -> void: _spawn()).call_deferred()


# ---------------------------------------------------------------- debug CLI

func debug_spawn() -> void:
	if not _attiva:
		_spawn()


func debug_state() -> Dictionary:
	return {"attiva": _attiva, "z": _z, "lette": _lette.size(),
			"ultima": _giorno_ultima}
