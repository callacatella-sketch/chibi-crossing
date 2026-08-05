extends Node
## LA SBORNIA DI SUCCO DI MELA — il verbo «esagerare», al bancone.
##
## Al bar («Bancone bar») con E si beve un succo di mela: quattro
## noccioline il bicchiere. I primi due scendono e basta. Dal terzo il
## mondo comincia a ONDEGGIARE, e bicchiere dopo bicchiere si trasforma
## in uno scarabocchio da vecchio programma di disegno — pixel ciccioni,
## contorni che tremano, il cielo che torna foglio bianco, perfino il
## HUD disegnato male (il velo sta SOPRA il HUD apposta). Poi passa da
## sola: mezzo bicchiere smaltito al minuto, nessuna penale, nessun
## postumo. Un'esagerazione gentile, come tutto in questo villaggio.
##
## Le decisioni (quanto ondeggia a quanti bicchieri, quanto in fretta
## passa) sono funzioni PURE e si provano headless in
## tests/cases/test_sbornia.gd; il nodo fa la recita: prompt, monete,
## velo, battute. NON si salva: una sbornia che sopravvive al
## salvataggio sarebbe un postumo, e i postumi qui non esistono.

## Il listino e la portata del bancone.
const COSTO := 4                 # noccioline al bicchiere
const PORTATA := 2.4             # da quanto vicino si ordina

## La curva: sotto SOGLIA bicchieri non succede niente (due succhi sono
## solo due succhi), a PIENA il mondo e' tutto scarabocchio.
const SOGLIA := 2.0
const PIENA := 8.0
## Smaltimento: bicchieri al secondo (0.5/min: da pieni a sobri in ~12').
const SMALTIMENTO := 1.0 / 120.0

## Le battute, al bicchiere giusto (chiave = bicchieri appena bevuti).
const BATTUTE := {
	1: "Il succo di mela scende che è un piacere.",
	3: "Il pavimento ondeggia. Colpa del pavimento, sicuro.",
	5: "Da quando i banconi sono due?",
	8: "Il mondo sembra disegnato col mouse.",
}

var _bicchieri := 0.0
var _player: Node3D
var _build: Node
var _sfx

var _velo: ColorRect
var _velo_mat: ShaderMaterial
var _prompt: PanelContainer
var _prompt_label: Label
var _toast: Label
var _toast_t := 0.0
var _vicino: Node3D
var _scan_t := 0.0


## Quanto e' sbronzo il mondo, da 0 a 1: sotto la soglia niente, poi
## una salita morbida fino al tutto-scarabocchio. PURA.
static func livello(bicchieri: float) -> float:
	var t := clampf((bicchieri - SOGLIA) / (PIENA - SOGLIA), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Lo smaltimento del tempo, PURO: mai sotto zero, niente postumi.
static func smaltisci(bicchieri: float, secondi: float) -> float:
	return maxf(0.0, bicchieri - secondi * SMALTIMENTO)


func _ready() -> void:
	add_to_group("sbornia")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_ui()
	(func() -> void:
		_player = get_node_or_null("%Player")
		_build = get_node_or_null("../BuildSystem")).call_deferred()


func _process(delta: float) -> void:
	_bicchieri = smaltisci(_bicchieri, delta)
	var liv := livello(_bicchieri)
	if _velo_mat:
		_velo.visible = liv > 0.003
		if _velo.visible:
			_velo_mat.set_shader_parameter("sbronza", liv)
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.8, 0.0, 1.0)
		_toast.visible = _toast_t > 0.0

	# il bancone piu' vicino, cercato con calma (due volte al secondo)
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.5
		_vicino = _bancone_vicino()
	_aggiorna_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if _prompt == null or not _prompt.visible:
		return
	bevi()
	get_viewport().set_input_as_handled()


## Un bicchiere: si paga, si beve, e al bicchiere giusto parte la
## battuta. Se le noccioline non bastano, il barista e' spiacente.
func bevi() -> void:
	var eco := get_tree().get_first_node_in_group("economy")
	if eco and int(eco.get("nuts")) < COSTO:
		_di(L10n.tf("Servono %d 🌰 per un succo.", [COSTO]))
		return
	if eco:
		eco.call("add_nuts", -COSTO)
	_bicchieri += 1.0
	var n := int(floorf(_bicchieri))
	if BATTUTE.has(n):
		_di(L10n.t(str(BATTUTE[n])))
	if _sfx and _sfx.has_method("collect_item"):
		_sfx.collect_item()


## Per i provini e la regia: quanti bicchieri, subito.
func debug_bicchieri(n: float) -> void:
	_bicchieri = n


func _bancone_vicino() -> Node3D:
	if _build == null or _player == null:
		return null
	var meglio: Node3D = null
	var d_min := PORTATA
	for b in _build.call("get_placed_by_name", "Bancone bar"):
		var d: float = _player.global_position.distance_to((b as Node3D).global_position)
		if d < d_min:
			d_min = d
			meglio = b
	return meglio


func _aggiorna_prompt() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _vicino == null or _player == null:
		_prompt.visible = false
		return
	var wp: Vector3 = _vicino.global_position + Vector3(0, 1.35, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = L10n.tf("E — un succo di mela (%d 🌰)", [COSTO])
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _di(testo: String) -> void:
	_toast.text = testo
	_toast_t = 2.6
	_toast.visible = true
	_toast.modulate.a = 1.0


func _build_ui() -> void:
	# il VELO dello scarabocchio: sopra il HUD (layer 7 > 1) apposta —
	# nel disegno fatto male ci finiscono anche le barrette e i numeri
	var strato := CanvasLayer.new()
	strato.layer = 7
	add_child(strato)
	_velo = ColorRect.new()
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_velo_mat = ShaderMaterial.new()
	_velo_mat.shader = load("res://scenes/interact/sbornia.gdshader")
	_velo.material = _velo_mat
	_velo.visible = false
	strato.add_child(_velo)

	# il prompt e le battute: il velo li ripassa comunque (campiona lo
	# schermo intero), e va bene COSI' — nel disegno fatto male ci
	# finisce anche la scritta dell'ordinazione, che da sbronzi si
	# legge male come tutto il resto. Il tasto E, quello, non trema.
	var ui := CanvasLayer.new()
	ui.layer = 9
	add_child(ui)
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
	ui.add_child(_prompt)
	_prompt_label = Label.new()
	_prompt_label.add_theme_color_override("font_color", Color("6a4a3a"))
	_prompt_label.add_theme_font_size_override("font_size", 15)
	_prompt.add_child(_prompt_label)

	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.position += Vector2(0, -120)
	_toast.add_theme_color_override("font_color", Color(0.99, 0.97, 0.92))
	_toast.add_theme_color_override("font_outline_color", Color(0.25, 0.17, 0.12, 0.85))
	_toast.add_theme_constant_override("outline_size", 7)
	_toast.add_theme_font_size_override("font_size", 19)
	_toast.visible = false
	ui.add_child(_toast)
