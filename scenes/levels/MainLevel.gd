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
const WALK_SPEED := 3.0
const RECOVERY_FRACTION := 0.35

# moltiplicatore velocità dalle Impostazioni ("Velocità di Mochi")
var _speed_scale := 1.0
# il fattore del languore (lo segnala la Premura: pancia vuota, passo piccolo)
var _languore_scale := 1.0

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
	# il frutteto: il semino raro del passerotto diventa melo o pero
	add_child(_spawn_system("res://scenes/interact/Frutteto.gd", "Frutteto"))
	# le commissioni della lavagna: i vicini chiedono, la stagione risponde
	add_child(_spawn_system("res://scenes/npc/Commissioni.gd", "Commissioni"))
	# il nido della Casetta uccellini: in primavera arriva Briciola
	add_child(_spawn_system("res://scenes/interact/Nido.gd", "Nido"))
	var settings := get_node_or_null(^"/root/Settings")
	if settings:
		settings.apply_to_player(player)

	if OS.get_environment("CHIBI_SHOT") != "":
		_start_debug_harness("shot", OS.get_environment("CHIBI_SHOT"))
	elif OS.get_environment("CHIBI_LEGNA") != "":
		_start_debug_harness("legna", OS.get_environment("CHIBI_LEGNA"))
	elif OS.get_environment("CHIBI_LAVORI") != "":
		_start_debug_harness("lavori", OS.get_environment("CHIBI_LAVORI"))
	elif OS.get_environment("CHIBI_FESTA") != "":
		_start_debug_harness("festa", OS.get_environment("CHIBI_FESTA"))
	elif OS.get_environment("CHIBI_FILO") != "":
		_start_debug_harness("filo", OS.get_environment("CHIBI_FILO"))
	elif OS.get_environment("CHIBI_FRUTTETO") != "":
		_start_debug_harness("frutteto", OS.get_environment("CHIBI_FRUTTETO"))
	elif OS.get_environment("CHIBI_COMMISSIONI") != "":
		_start_debug_harness("commissioni", OS.get_environment("CHIBI_COMMISSIONI"))
	elif OS.get_environment("CHIBI_NIDO") != "":
		_start_debug_harness("nido", OS.get_environment("CHIBI_NIDO"))
	elif OS.get_environment("CHIBI_FACCE") != "":
		_start_debug_harness("facce", OS.get_environment("CHIBI_FACCE"))
	elif OS.get_environment("CHIBI_PORTE") != "":
		_start_debug_harness("porte", OS.get_environment("CHIBI_PORTE"))
	elif OS.get_environment("CHIBI_PIOGGIA") != "":
		_start_debug_harness("pioggia", OS.get_environment("CHIBI_PIOGGIA"))
	elif OS.get_environment("CHIBI_BUCATO") != "":
		_start_debug_harness("bucato", OS.get_environment("CHIBI_BUCATO"))
	elif OS.get_environment("CHIBI_SALUTI") != "":
		_start_debug_harness("saluti", OS.get_environment("CHIBI_SALUTI"))
	elif OS.get_environment("CHIBI_MAKESAVE") != "":
		_start_debug_harness("makesave")

func _on_stamina_changed(value: float, max_value: float):
	if value <= 0.5 and not _exhausted:
		_exhausted = true
		_refresh_speeds()
		_refresh_tired()
	elif _exhausted and value >= max_value * RECOVERY_FRACTION:
		_exhausted = false
		_refresh_speeds()
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


# LA velocità di Mochi ha UN padrone: questa funzione. Tre voci in
# capitolo — lo slider delle Impostazioni (_speed_scale), la stanchezza
# (_exhausted) e il languore della Premura (_languore_scale) — e nessuno
# scrive più walk/run_speed per conto suo. Prima erano tre scrittori
# indipendenti: la Premura fotografava la velocità all'avvio e la
# riscriveva assoluta, cancellando lo sfinimento (Mochi sfinita E languida
# CORREVA più che sfinita e basta) e lo slider cambiato in corsa.
# Un test in test_cablaggio tiene chiusa la porta.
func _refresh_speeds() -> void:
	player.walk_speed = WALK_SPEED * _speed_scale * _languore_scale
	player.run_speed = (EXHAUSTED_RUN_SPEED if _exhausted else NORMAL_RUN_SPEED) \
			* _speed_scale * _languore_scale


## Le Impostazioni cambiano la velocità di Mochi: riscala la corsa corrente.
func set_speed_scale(s: float) -> void:
	_speed_scale = maxf(0.1, s)
	_refresh_speeds()


## La Premura segnala il languore: il passo si accorcia del fattore dato
## (1.0 = pancia piena). Si COMPONE con slider e stanchezza, non li scavalca.
func set_languore(scale: float) -> void:
	_languore_scale = clampf(scale, 0.5, 1.0)
	_refresh_speeds()


func _spawn_system(path: String, node_name: String) -> Node:
	var n: Node = (load(path) as GDScript).new()
	n.name = node_name
	return n


# ------------------------------------------------------------------ debug CLI
# Istanzia l'harness di verifica (DebugHarness.gd) come nodo figlio e gli passa
# se stesso, così tutto il codice di test resta fuori dallo script di gioco.
#
# IL SALVATAGGIO VERO NON SI TOCCA. Le modalità "lavori", "festa" e "legna"
# fabbricano residenti finti, danno incarichi, saltano di stagione in stagione
# e simulano novanta giorni di lavoro forzato fino alla diserzione: se le
# scritture restassero accese, tutta quella roba finirebbe nel villaggio del
# giocatore (e i disertori se ne andrebbero per davvero, in modo permanente).
# Qui si spengono le SCRITTURE, non il caricamento: il villaggio si carica
# ancora, che è proprio ciò che serve alla fase 2 della prova sulla legna. Le
# eccezioni sono due, entrambe volute: CHIBI_LEGNA_SAVE (fase 1 della stessa
# prova: abbatte, salva ed esce) e "makesave", che il salvataggio lo crea
# apposta. "shot" si spegne da sé in BuildSystem._ready.
func _start_debug_harness(mode: String, arg: String = "") -> void:
	if mode in ["lavori", "festa", "filo", "frutteto", "commissioni", "nido", "facce",
			"porte", "pioggia", "bucato", "saluti"] \
			or (mode == "legna" and OS.get_environment("CHIBI_LEGNA_SAVE") == ""):
		build_system.set_persist_for_debug(false)
	var h = DEBUG_HARNESS.new()
	h.name = "DebugHarness"
	add_child(h)
	h.run(self, mode, arg)
