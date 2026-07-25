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

func _ready():
	# Connette il componente C++ di sopravvivenza del player alla UI
	var survival_comp = player.get_node_or_null("SurvivalComponent")
	if survival_comp:
		hud.connect_survival_component(survival_comp)
		survival_comp.stamina_changed.connect(_on_stamina_changed)
	else:
		printerr("MainLevel: SurvivalComponent non trovato sul Player!")

	# verticalità: le scale sono ripide, Mochi le sale come rampe e
	# scende senza saltellare (snap al suolo più lungo)
	player.floor_max_angle = deg_to_rad(72.0)
	player.floor_snap_length = 0.5

	if OS.get_environment("CHIBI_SHOT") != "":
		_start_debug_harness("shot", OS.get_environment("CHIBI_SHOT"))
	elif OS.get_environment("CHIBI_MAKESAVE") != "":
		_start_debug_harness("makesave")

func _on_stamina_changed(value: float, max_value: float):
	var mochi = player.get_node_or_null("Mochi")
	if value <= 0.5 and not _exhausted:
		_exhausted = true
		player.run_speed = EXHAUSTED_RUN_SPEED
		if mochi:
			mochi.set_tired(true)
	elif _exhausted and value >= max_value * RECOVERY_FRACTION:
		_exhausted = false
		player.run_speed = NORMAL_RUN_SPEED
		if mochi:
			mochi.set_tired(false)


# ------------------------------------------------------------------ debug CLI
# Istanzia l'harness di verifica (DebugHarness.gd) come nodo figlio e gli passa
# se stesso, così tutto il codice di test resta fuori dallo script di gioco.
func _start_debug_harness(mode: String, arg: String = "") -> void:
	var h = DEBUG_HARNESS.new()
	h.name = "DebugHarness"
	add_child(h)
	h.run(self, mode, arg)
