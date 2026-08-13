extends Node

## Impostazioni di gioco (autoload "Settings"): audio, schermo, movimento,
## accessibilità. Tutto persistito in user://settings.cfg (lo stesso file di
## Quality, ma in sezioni separate, così i due convivono senza pestarsi).
##
## - Audio: crea a runtime i bus e ne pilota il volume. La catena è ad
##   ALBERO, non piatta:
##       Voci ─→ Sfx ─→ Master
##       Music ───────→ Master
##   così il cursore «Effetti» governa anche le voci (chi abbassa gli
##   effetti si aspetta che il villaggio intero abbassi la voce), e chi
##   vuole può calare solo il Chibiese col suo cursore — che in questo
##   gioco parla di continuo, con 28 vicini.
##   Sfx.gd instrada i suoi player; le VOCI chiedono il bus a
##   `Sfx.bus_voci()`: prima ognuna se lo creava a mano senza `.bus` e
##   finivano tutte sul Master, sorde a ogni cursore tranne il generale.
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
## Le voci del Chibiese: un bus figlio di "Sfx", perché il villaggio
## parla di continuo e c'è chi vuole il chiacchiericcio più discreto
## senza perdere i passi e le porte.
var voci_volume := 1.0
var fullscreen := true
var reduce_motion := false
## Moltiplicatore velocità Mochi (0.7 tranquilla · 1.0 normale · 1.4 svelta).
var move_speed := 1.0
## «Prato Eterno»: nessun vicino parte mai per il Grande Prato (il congedo
## del Filo Rosso resta spento). Il gioco resta intero anche senza partenze.
var prato_eterno := false
## La lingua: "auto" (quella del sistema, se la conosciamo) · "it" · "en".
## L'italiano è la lingua sorgente — vedi systems/L10n.gd e docs/TRADUZIONE.md.
var language := "auto"
## LA LEVA DEL CUORE CHE SCRIVE (Fase 5): quando è vera, il villaggio NON
## pensa — nessun modello si apre, nessun pensiero parte, il gioco è quello
## di sempre con i testi scritti a mano.
##
## ⚠️ **LA CASELLA SI VEDE SOLO A CHI HA UN MODELLO** (`Llm.leva_visibile()`,
## e la ragione per esteso sta in `Llm.acceso()`): mostrata a chi non ne ha
## nessuno racconterebbe che gli manca un pezzo, e non gli manca niente.
## Il bit vive qui perché qui vivono le preferenze persistite del giocatore —
## la DOMANDA («il villaggio può pensare?») invece ha una casa sola, ed è
## `systems/Llm.gd`. Come `prato_eterno`: il bit di qua, il predicato di là.
##
## ⚠️ E IL VERSO È «SPENTO», non «acceso»: il valore di serie di un `bool` è
## `false`, e il valore di serie di questa funzione dev'essere ACCESA. Un
## `llm_acceso` girerebbe la funzione a chiunque non abbia mai aperto il
## pannello — cioè quasi tutti — e la stessa riga che difende chi non l'ha
## voluta spegnerebbe il villaggio a chi non ha detto niente.
var llm_spento := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	fullscreen = _boot_fullscreen()
	_load()
	_apply_all()


# ---------------------------------------------------------------- bus audio
## L'albero dei bus: nome -> dove manda. L'ORDINE conta — un bus non può
## mandare a un bus che non esiste ancora, quindi "Voci" viene dopo "Sfx".
const BUS_ALBERO := [["Music", "Master"], ["Sfx", "Master"], ["Voci", "Sfx"]]


func _ensure_buses() -> void:
	for coppia in BUS_ALBERO:
		var nome := str(coppia[0])
		var verso := str(coppia[1])
		if AudioServer.get_bus_index(nome) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, nome)
		# il send si (ri)assegna sempre: un layout salvato con l'albero
		# vecchio lascerebbe "Voci" appeso al Master, e il cursore
		# «Effetti» tornerebbe a non governare le voci — in silenzio
		var mio := AudioServer.get_bus_index(nome)
		if mio != -1 and AudioServer.get_bus_index(verso) != -1:
			AudioServer.set_bus_send(mio, verso)


func _boot_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


# ---------------------------------------------------------------- applica
func _apply_all() -> void:
	_apply_bus("Master", master_volume)
	_apply_bus("Music", music_volume)
	_apply_bus("Sfx", sfx_volume)
	_apply_bus("Voci", voci_volume)
	_apply_fullscreen()
	# la lingua PRIMA di tutto il resto: il titolo si costruisce subito dopo
	L10n.imposta(language)
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
	# walk E run le governa MainLevel._refresh_speeds (un padrone solo, che
	# compone slider + stanchezza + languore): qui si passa solo il fattore
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


func set_voci_volume(v: float) -> void:
	voci_volume = clampf(v, 0.0, 1.0)
	_apply_bus("Voci", voci_volume)
	_save(); changed.emit()
	# l'anteprima udibile: una voce vera del villaggio, non un campanello
	var vis := get_tree().get_first_node_in_group("visitors")
	if vis and vis.has_method("assaggio_di_voce"):
		vis.call("assaggio_di_voce")


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


func set_prato_eterno(on: bool) -> void:
	prato_eterno = on
	_save(); changed.emit()


## LA LEVA DEL CUORE CHE SCRIVE. L'argomento è «il villaggio pensa» — cioè
## quello che legge chi guarda la casella — e il bit salvato è il suo
## contrario: qui si gira una volta sola, in un posto solo.
##
## ⚠️ SI APPLICA AL PROSSIMO AVVIO, e il pannello lo dice a chi gioca. Il
## modello lo apre `scenes/npc/Pensieri.gd` una volta per vita del livello
## (`_chiesto`), e riaprire due gigabyte e mezzo — o chiuderli — mentre
## qualcuno sta pensando è la cura peggiore della malattia: una generazione
## in volo, un thread da fermare, e trentasette secondi di impronta da
## rifare. Spegnere una funzione non deve costare più che tenerla.
func set_llm_acceso(on: bool) -> void:
	llm_spento = not on
	_save(); changed.emit()


# ---------------------------------------------------------------- lingua
func set_language(codice: String) -> void:
	language = codice
	L10n.imposta(language)
	_save(); changed.emit()


## Il codice della lingua VERA di adesso ("it"/"en"), risolvendo "auto".
func language_code() -> String:
	return L10n.lingua_corrente()


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
	voci_volume = float(cfg.get_value("audio", "voci", voci_volume))
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	reduce_motion = bool(cfg.get_value("gameplay", "reduce_motion", reduce_motion))
	move_speed = float(cfg.get_value("gameplay", "move_speed", move_speed))
	prato_eterno = bool(cfg.get_value("gameplay", "prato_eterno", prato_eterno))
	language = str(cfg.get_value("gameplay", "language", language))
	llm_spento = bool(cfg.get_value("gameplay", "llm_spento", llm_spento))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # preserva le sezioni di Quality ([video])
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "voci", voci_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("gameplay", "reduce_motion", reduce_motion)
	cfg.set_value("gameplay", "move_speed", move_speed)
	cfg.set_value("gameplay", "prato_eterno", prato_eterno)
	cfg.set_value("gameplay", "language", language)
	cfg.set_value("gameplay", "llm_spento", llm_spento)
	cfg.save(PATH)
