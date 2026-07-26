extends Node3D

# L'harness di debug (screenshot/salvataggi da CLI) vive in un file a parte,
# istanziato solo quando servono le env var CHIBI_SHOT / CHIBI_MAKESAVE.
const DEBUG_HARNESS := preload("res://scenes/levels/DebugHarness.gd")

@onready var player = %Player
@onready var hud = %HUD
@onready var sun: DirectionalLight3D = $Sun
@onready var build_system: Node3D = $BuildSystem
@onready var interactions: Node = $Interactions

# quando la stamina si azzera Mochi è sfinita: correre diventa arrancare
# (più lento che camminare) finché non recupera oltre la soglia
var _exhausted := false
const EXHAUSTED_RUN_SPEED := 1.7
const NORMAL_RUN_SPEED := 6.0
const RECOVERY_FRACTION := 0.35

# moltiplicatore velocità dalle Impostazioni ("Velocità di Mochi")
var _speed_scale := 1.0

var _mochi: Node
# quali bisogni sono nel critico adesso: se anche solo uno lo è (o Mochi è
# sfinita), il musetto si affloscia — la faccia racconta lo stato peggiore
var _need_crit := {"water": false, "hunger": false, "stamina": false}

func _ready():
	_mochi = player.get_node_or_null("Mochi")
	# Connette il componente C++ di sopravvivenza del player alla UI
	var survival_comp = player.get_node_or_null("SurvivalComponent")
	if survival_comp:
		# ascolta i cambi di fascia della HUD PRIMA di inizializzarla, così il
		# musetto è sempre allineato ai ciondoli
		hud.need_state_changed.connect(_on_need_state_changed)
		hud.connect_survival_component(survival_comp)
		survival_comp.stamina_changed.connect(_on_stamina_changed)
	else:
		printerr("MainLevel: SurvivalComponent non trovato sul Player!")

	# verticalità: le scale sono ripide, Mochi le sale come rampe e
	# scende senza saltellare (snap al suolo più lungo)
	player.floor_max_angle = deg_to_rad(72.0)
	player.floor_snap_length = 0.5

	# --- economia gentile + menu (istanziati da codice: non tocco la scena) ---
	player.add_to_group("player_controller")
	add_child(_spawn_system("res://scenes/ui/Economy.gd", "Economy"))
	add_child(_spawn_system("res://scenes/ui/Shop.gd", "Shop"))
	add_child(_spawn_system("res://scenes/ui/PauseMenu.gd", "PauseMenu"))
	# il boschetto da legna: l'ascia, il taglio e la ricrescita
	add_child(_spawn_system("res://scenes/interact/Woodcutting.gd", "Woodcutting"))
	# il registro dei lavori: dare ordini ai residenti e leggerne l'animo
	add_child(_spawn_system("res://scenes/npc/Lavori.gd", "Lavori"))
	var settings := get_node_or_null(^"/root/Settings")
	if settings:
		settings.apply_to_player(player)

	if OS.get_environment("CHIBI_SHOT") != "":
		_start_debug_harness("shot", OS.get_environment("CHIBI_SHOT"))
	elif OS.get_environment("CHIBI_LEGNA") != "":
		_start_debug_harness("legna", OS.get_environment("CHIBI_LEGNA"))
	elif OS.get_environment("CHIBI_LAVORI") != "":
		_start_debug_harness("lavori", OS.get_environment("CHIBI_LAVORI"))
	elif OS.get_environment("CHIBI_MAKESAVE") != "":
		_start_debug_harness("makesave")

func _on_stamina_changed(value: float, max_value: float):
	if value <= 0.5 and not _exhausted:
		_exhausted = true
		player.run_speed = EXHAUSTED_RUN_SPEED * _speed_scale
		_refresh_tired()
	elif _exhausted and value >= max_value * RECOVERY_FRACTION:
		_exhausted = false
		player.run_speed = NORMAL_RUN_SPEED * _speed_scale
		_refresh_tired()

# la HUD ci dice quando un bisogno cambia fascia (0 sereno · 1 basso · 2 critico)
func _on_need_state_changed(kind: String, level: int):
	var was_crit: bool = _need_crit.get(kind, false)
	var now_crit := level >= 2
	_need_crit[kind] = now_crit
	# nell'istante in cui scivola nel critico, Mochi se ne accorge: una
	# bollicina del colore del bisogno sale dal musetto
	if now_crit and not was_crit and _mochi and _mochi.has_method("emote_need"):
		_mochi.emote_need(kind)
	_refresh_tired()

# il musetto è affaticato se Mochi è sfinita o se un qualsiasi bisogno è critico
func _refresh_tired():
	if not _mochi:
		return
	var tired: bool = _exhausted or _need_crit["water"] or _need_crit["hunger"] or _need_crit["stamina"]
	_mochi.set_tired(tired)


## Le Impostazioni cambiano la velocità di Mochi: riscala la corsa corrente.
func set_speed_scale(s: float) -> void:
	_speed_scale = maxf(0.1, s)
	player.run_speed = (EXHAUSTED_RUN_SPEED if _exhausted else NORMAL_RUN_SPEED) * _speed_scale


func _spawn_system(path: String, node_name: String) -> Node:
	var n: Node = (load(path) as GDScript).new()
	n.name = node_name
	return n


# ------------------------------------------------------------------ debug CLI
# Istanzia l'harness di verifica (DebugHarness.gd) come nodo figlio e gli passa
# se stesso, così tutto il codice di test resta fuori dallo script di gioco.
func _start_debug_harness(mode: String, arg: String = "") -> void:
	var h = DEBUG_HARNESS.new()
	h.name = "DebugHarness"
	add_child(h)
	h.run(self, mode, arg)
