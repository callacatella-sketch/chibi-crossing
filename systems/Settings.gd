extends Node

## Impostazioni di gioco (autoload "Settings"): audio, schermo, movimento,
## accessibilità. Tutto persistito in user://settings.cfg (lo stesso file di
## Quality, ma in sezioni separate, così i due convivono senza pestarsi).
##
## - Audio: crea a runtime i bus "Music" e "Sfx" (se mancano) e ne pilota il
##   volume; il Master resta il volume generale. Sfx.gd instrada i suoi player
##   su questi bus.
## - Schermo: schermo intero on/off.
## - Movimento: un moltiplicatore alla velocità di Mochi ("sensibilità").
## - Riduci animazioni: accessibilità; CozyUI lo rispetta.
##
## Il pannello impostazioni (usato da titolo e pausa) chiama i setter qui;
## ogni setter applica e salva subito. Emette `changed` a ogni modifica.

signal changed

const PATH := "user://settings.cfg"

var master_volume := 0.9
var music_volume := 0.8
var sfx_volume := 0.9
var fullscreen := true
var reduce_motion := false
## Moltiplicatore velocità Mochi (0.7 tranquilla · 1.0 normale · 1.4 svelta).
var move_speed := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	fullscreen = _boot_fullscreen()
	_load()
	_apply_all()


# ---------------------------------------------------------------- bus audio
func _ensure_buses() -> void:
	for name in ["Music", "Sfx"]:
		if AudioServer.get_bus_index(name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, name)
			AudioServer.set_bus_send(idx, "Master")


func _boot_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


# ---------------------------------------------------------------- applica
func _apply_all() -> void:
	_apply_bus("Master", master_volume)
	_apply_bus("Music", music_volume)
	_apply_bus("Sfx", sfx_volume)
	_apply_fullscreen()
	apply_to_player(get_tree().get_first_node_in_group("player_controller"))


func _apply_bus(bus: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(v, 0.0001, 1.0)))


func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen \
		else DisplayServer.WINDOW_MODE_WINDOWED)


## Applica il moltiplicatore di velocità al PlayerController (C++), se presente.
## Chiamata all'avvio della scena di gioco e a ogni cambio impostazione.
func apply_to_player(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("set_walk_speed"):
		player.set("walk_speed", 3.0 * move_speed)
	# la run_speed la governa MainLevel (stanchezza): gli passiamo il fattore
	if player.get_parent() and player.get_parent().has_method("set_speed_scale"):
		player.get_parent().set_speed_scale(move_speed)


# ---------------------------------------------------------------- setter API
func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_bus("Master", master_volume)
	_save(); changed.emit()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus("Music", music_volume)
	_save(); changed.emit()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_bus("Sfx", sfx_volume)
	_save(); changed.emit()
	var sfx := get_node_or_null(^"/root/Sfx")
	if sfx: sfx.call("ui_select")   # anteprima udibile del nuovo volume


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_fullscreen()
	_save(); changed.emit()


func set_reduce_motion(on: bool) -> void:
	reduce_motion = on
	_save(); changed.emit()


func set_move_speed(v: float) -> void:
	move_speed = clampf(v, 0.6, 1.5)
	apply_to_player(get_tree().get_first_node_in_group("player_controller"))
	_save(); changed.emit()


# ---------------------------------------------------------------- qualità
## Delega all'autoload Quality (preset grafico Basso/Alto).
func get_quality() -> int:
	var q := get_node_or_null(^"/root/Quality")
	return int(q.level) if q else 0


func set_quality(level: int) -> void:
	var q := get_node_or_null(^"/root/Quality")
	if q:
		q.set_quality(level)
	changed.emit()


func quality_available() -> bool:
	return get_node_or_null(^"/root/Quality") != null


# ---------------------------------------------------------------- persistenza
func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master_volume = float(cfg.get_value("audio", "master", master_volume))
	music_volume = float(cfg.get_value("audio", "music", music_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	reduce_motion = bool(cfg.get_value("gameplay", "reduce_motion", reduce_motion))
	move_speed = float(cfg.get_value("gameplay", "move_speed", move_speed))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # preserva le sezioni di Quality ([video])
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("gameplay", "reduce_motion", reduce_motion)
	cfg.set_value("gameplay", "move_speed", move_speed)
	cfg.save(PATH)
