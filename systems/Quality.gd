extends Node
## Sistema di qualità grafica scalabile (autoload "Quality").
##
## Applica un preset di rendering a runtime, così ogni macchina sceglie il suo
## profilo senza toccare le altre impostazioni del progetto. Utile perché il
## progetto gira sia su GPU integrate (es. MacBook Air M1) sia su PC potenti.
##
## Uso da codice:  Quality.set_quality(Quality.Level.ALTO)
## Il preset viene salvato in user://settings.cfg e ricaricato all'avvio.

enum Level { BASSO, ALTO }

const SETTINGS_PATH := "user://settings.cfg"

var level: int = Level.BASSO


func _ready() -> void:
	level = _load_or_autodetect()
	apply(level)


## Carica il preset salvato; se non c'è, sceglie in automatico in base alla GPU.
func _load_or_autodetect() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.has_section_key("video", "quality"):
		return int(cfg.get_value("video", "quality"))
	# Default automatico: su GPU integrate/mobile parti "Basso" per i 60 fps.
	return Level.BASSO if _is_low_power_gpu() else Level.ALTO


func _is_low_power_gpu() -> bool:
	var n := OS.get_name()
	return n == "macOS" or n == "Android" or n == "iOS"


## Cambia preset a runtime e lo salva.
func set_quality(new_level: int) -> void:
	level = clampi(new_level, Level.BASSO, Level.ALTO)
	apply(level)
	_save()


## Applica le impostazioni di rendering del preset al viewport principale.
func apply(l: int) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	match l:
		Level.BASSO:
			# = "preset 60 fps" (MSAA 2x, ombre morbide basse): leggero ma pulito.
			vp.msaa_3d = Viewport.MSAA_2X
			vp.scaling_3d_scale = 1.0
			RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			RenderingServer.positional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		Level.ALTO:
			# Qualità piena per hardware capace (es. PC desktop).
			vp.msaa_3d = Viewport.MSAA_4X
			vp.scaling_3d_scale = 1.0
			RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
			RenderingServer.positional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_SOFT_HIGH)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # ignora l'errore se il file non esiste ancora
	cfg.set_value("video", "quality", level)
	cfg.save(SETTINGS_PATH)
