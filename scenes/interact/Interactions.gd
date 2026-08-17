extends Node

## Interazioni cozy: avvicinati a una sedia, sgabello o panchina e premi E
## per sederti; sul letto, E per dormire (con tanto di "zzz"). Un altro E
## per alzarti. Mentre Mochi è seduta il PlayerController C++ è in pausa.
##
## Di notte il letto fa di più: Mochi si addormenta, lo schermo sfuma nel
## buio, un "Buongiorno!" e il sole è di nuovo alto — la notte è saltata,
## la stamina è piena e lei si rialza da sola pronta per un altro giorno.

# offset locale del punto in cui va la RADICE di Mochi: più basso del piano
# di seduta, così il vestitino affonda sul cuscino invece di starci in piedi.
# Nel letto la radice va verso i piedi del materasso: la posa "sleep" la
# reclina all'indietro col capo sul cuscino.
const SEATS := {
	# lo schienale della Sedia sta a +Z (come il letto): chi si siede va
	# verso il DAVANTI, cioè a -Z, o si ritroverebbe seduto nello schienale
	"Sedia": Vector3(0, 0.36, -0.08),
	"Sgabello": Vector3(0, 0.33, 0.0),
	"Panchina": Vector3(0, 0.35, 0.08),
	# il letto ha la testiera a +Z (si appoggia al muro dietro): la radice
	# va ai PIEDI, cioè a -Z, e la posa «sleep» reclinando all'indietro
	# porta il capo sul cuscino. Col segno di prima — quando la testiera
	# stava a -Z — Mochi si sarebbe coricata con la testa oltre la
	# pediera e i piedi sul guanciale, senza che niente lo segnalasse.
	"Letto": Vector3(0, 0.3, -0.26),
	# IL POSTO DICHIARATO: l'ancoraggio «Posto*» sta gia' sulla superficie
	# della seduta e guarda gia' dalla parte giusta (lo mette chi costruisce
	# il pezzo, che e' l'unico a sapere dov'e' il tavolo). Scostamento zero,
	# e il verso NON si gira di mezzo giro: vedi yaw_seduta.
	"Posto": Vector3.ZERO,
}

## Il Carillon comprato dal mercante: E lo carica e cambia la musica del
## villaggio, un tema alla volta. Il tema scelto persiste col villaggio.
const CARILLON_CICLO := ["villaggio", "ninnananna", "valzer"]
const CARILLON_LABEL := {
	"villaggio": "la musichetta di sempre",
	"ninnananna": "la ninnananna",
	"valzer": "il valzer",
}

var _player: Node3D
var _mochi: Node3D
var _build: Node3D
var _sfx

var _prompt: PanelContainer
var _prompt_label: Label
var _target: Node3D
var _target_name := ""
var _seated := false
## SU COSA e' seduta, non solo SE. Serve a chi deve sapere che quel posto e'
## occupato — `Visitors._free_bench`, che cicla solo `_residents` e quindi un
## vicino si sedeva DENTRO Mochi, e il fatto dell'insieme, per cui Mochi
## seduta e' un corpo seduto come gli altri.
var _seat_node: Node3D = null
var _return_pos := Vector3.ZERO

# il carillon a portata di zampa (se nessuna seduta è più vicina); la
# lista dei piazzati è in cache: si rifà solo quando il villaggio cambia
var _carillon: Node3D
var _carillons: Array[Node3D] = []
var _carillons_dirty := true
var _tema_scelto := "villaggio"

# il sonno notturno: velo di dissolvenza, saluto del mattino, stato
var _daynight: Node3D
var _fade: ColorRect
var _wake_label: Label
var _sleeping := false


func _ready() -> void:
	add_to_group("persistable")
	# …e si fa trovare per GRUPPO, come tutti gli altri sistemi del livello.
	# I due che la cercavano per percorso relativo (`../Interactions`) sono
	# figli del livello; `Visitors` no, e un percorso indovinato da la' e' il
	# modo esatto in cui una domanda comincia a rispondere `null` per sempre.
	add_to_group("interactions")
	_player = get_node("%Player")
	_mochi = _player.get_node("Mochi")
	_build = get_node("../BuildSystem")
	_daynight = get_node_or_null("../DayNight")
	_sfx = get_node_or_null(^"/root/Sfx")
	if _build.has_signal("placed_changed"):
		_build.connect("placed_changed", func(): _carillons_dirty = true)
	_build_prompt()
	_build_fade()


## Mochi sta dormendo? Lo chiedono i sistemi che hanno un pannello sopra
## la tenda del sonno (la modalità foto, il prompt del cucciolo): senza
## questa domanda, una scritta italiana comparirebbe in mezzo a un sogno
## che ha come regola prima di non avere parole.
func is_sleeping() -> bool:
	return _sleeping


## Il letto che si sta usando è casa propria? È la porta del sogno.
func _e_il_mio_letto() -> bool:
	if _target == null or not is_instance_valid(_target) or _target_name != "Letto":
		return false
	var home := get_node_or_null("../Home")
	if home == null:
		return false
	return bool(home.call("is_home",
			Vector2i(roundi(_target.position.x), roundi(_target.position.z))))


## Il verso di chi si siede su un pezzo ruotato di `yaw_pezzo`: si guarda
## dalla parte OPPOSTA allo schienale. Pura apposta — è la sola cosa che
## lega la geometria del pezzo alla posa, e va potuta provare senza scena
## (vedi tests/cases/test_sedute.gd, che misura DOVE sta lo schienale
## costruendo il pezzo vero).
static func yaw_seduta(kind: String, yaw_pezzo: float) -> float:
	# il posto dichiarato porta gia' il suo verso: girarlo di mezzo giro
	# metterebbe le spalle al tavolo che e' venuto a guardare
	if kind == "Posto":
		return yaw_pezzo
	var verso: float = (SEATS.get(kind, Vector3.ZERO) as Vector3).z
	return yaw_pezzo + (0.0 if verso < 0.0 else PI)


func is_seated() -> bool:
	return _seated


## SU COSA E' SEDUTA MOCHI ADESSO, o `null` se e' in piedi.
##
## Un accessore da una riga, e ha due lettori che chiedono cose diverse:
## `_free_bench` («quel posto e' occupato»: non ci si siede addosso a
## nessuno) e il fatto dell'insieme («li' c'e' qualcuno»: il posto accanto
## chiama). E' l'unica chiave a forma di GIOCATORE che le cricche abbiano —
## siediti al Gazebo, e i due sgabelli di fianco cominciano a chiamare.
func sedile_attuale() -> Node3D:
	if not _seated or _seat_node == null or not is_instance_valid(_seat_node):
		return null
	# ⚠️ **DORMIRE NON E' SEDERSI.** `_sit_down` scrive `_seat_node` per ogni
	# `kind`, LETTO compreso, e `_sleep_until_morning` non lo azzera: senza
	# questa riga, per tutta la notte il letto di Mochi risulta «un corpo
	# seduto» e ogni seduta entro `VICINI` da li' chiama qualcuno — verso un
	# corpo che sta dietro una tenda nera. Non e' un corpo seduto come gli
	# altri, e la chiave a forma di giocatore dev'essere un GESTO, non una
	# dormita.
	if _sleeping:
		return null
	return _seat_node


func _build_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
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
	_prompt_label.add_theme_color_override("font_color", Color("6a4a3a"))
	_prompt.add_child(_prompt_label)


# il sipario della notte: un velo blu-notte sopra a tutto, con al centro
# il saluto del mattino che appare solo a schermo buio
func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.02, 0.06, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)

	_wake_label = Label.new()
	_wake_label.text = L10n.t("Buongiorno!")
	_wake_label.add_theme_font_size_override("font_size", 30)
	_wake_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.8))
	_wake_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wake_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wake_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wake_label.modulate.a = 0.0
	_fade.add_child(_wake_label)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _sleeping:
		_prompt.visible = false
		return

	if _seated:
		_show_prompt(L10n.t("E — alzati"), _player.global_position + Vector3(0, 1.4, 0), cam)
		return

	# il pezzo interagibile più vicino, entro un passetto
	_target = null
	var best := 1.45
	for it in _build.get_interactables():
		var node := it["node"] as Node3D
		var d: float = _player.global_position.distance_to(node.global_position)
		if d < best:
			best = d
			_target = node
			_target_name = it["name"]

	if _target:
		var text := L10n.t("E — siediti")
		if _target_name == "Letto":
			# IL VERBO CAMBIA SE IL LETTO È IL TUO. «Dormi» è una funzione;
			# «vai a dormire» è una cosa che si fa la sera, a casa propria —
			# ed è l'unico letto in cui si sogna.
			text = L10n.t("E — dormi fino al mattino") if _is_night() else L10n.t("E — dormi")
			var home := get_node_or_null("../Home")
			if home:
				var cell := Vector2i(roundi(_target.position.x), roundi(_target.position.z))
				if home.call("is_home", cell):
					text = L10n.t("E — vai a dormire")
				else:
					text += "  ·  " + L10n.t("H — imposta casa")
		_show_prompt(text, _target.global_position + Vector3(0, 1.25, 0), cam)
		_carillon = null
	else:
		# nessuna seduta a tiro: magari c'è il carillon da caricare
		if _carillons_dirty:
			_carillons_dirty = false
			_carillons.clear()
			for node in _build.get_placed_by_name("Carillon"):
				_carillons.append(node)
		_carillon = null
		var best_c := 1.45
		for node in _carillons:
			if not is_instance_valid(node):
				continue
			var d: float = _player.global_position.distance_to(node.global_position)
			if d < best_c:
				best_c = d
				_carillon = node
		if _carillon:
			_show_prompt(L10n.t("E — carica il carillon (cambia musica)"),
					_carillon.global_position + Vector3(0, 1.0, 0), cam)
		else:
			_prompt.visible = false


func _is_night() -> bool:
	return _daynight != null and _daynight.is_night()


func _show_prompt(text: String, world_pos: Vector3, cam: Camera3D) -> void:
	if cam.is_position_behind(world_pos):
		_prompt.visible = false
		return
	_prompt_label.text = text
	_prompt.reset_size()
	var p := cam.unproject_position(world_pos)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or _sleeping:
		return
	if _seated:
		# la seduta è NOSTRA: alzarsi funziona anche a fisica congelata
		_stand_up()
		get_viewport().set_input_as_handled()
	elif _target and is_instance_valid(_target):
		# ma non ci si siede sopra il congelamento di un altro sistema
		# (onsen, lavagna, cucina…): scongelarlo dopo sarebbe un furto
		if not _player.is_physics_processing():
			return
		_sit_down(_target, _target_name)
		get_viewport().set_input_as_handled()
	elif _carillon and is_instance_valid(_carillon):
		if not _player.is_physics_processing():
			return
		_gira_carillon()
		get_viewport().set_input_as_handled()


## Un giro di manovella: il tema successivo del ciclo, con tanto di annuncio.
func _gira_carillon() -> void:
	var i := CARILLON_CICLO.find(_tema_scelto)
	_tema_scelto = str(CARILLON_CICLO[posmod(i + 1, CARILLON_CICLO.size())])
	if _sfx:
		_sfx.rotate_tick()
		_sfx.set_music_theme(_tema_scelto)
	var visitors := get_node_or_null("../Visitors")
	if visitors:
		visitors.call("_show_toast", L10n.tf("Il carillon gira piano: %s…",
				[L10n.t(str(CARILLON_LABEL.get(_tema_scelto, _tema_scelto)))]))
	var bs := get_tree().get_first_node_in_group("build_system")
	if bs and bs.has_method("request_save"):
		bs.request_save()
	# il concertino: se qualche vicino è a portata d'orecchio, il giro
	# di manovella diventa un coro in Chibiese attorno alla cassettina
	get_tree().call_group("concertino", "avvia", _carillon)


# ------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	return {"carillon_tema": _tema_scelto}


func load_extra(data: Dictionary) -> void:
	_tema_scelto = str(data.get("carillon_tema", "villaggio"))
	if _sfx:
		_sfx.set_music_theme(_tema_scelto)


# il tween sit/stand corrente: uno solo alla volta, o il callback
# ritardato di _stand_up riattiva la fisica mentre Mochi si è già riseduta
var _move_tw: Tween


func _sit_down(seat: Node3D, kind: String) -> void:
	_seated = true
	_seat_node = seat
	_return_pos = _player.global_position
	_player.set_physics_process(false)
	_player.velocity = Vector3.ZERO

	var dest: Vector3 = seat.global_transform * (SEATS[kind] as Vector3)
	if _move_tw and _move_tw.is_valid():
		_move_tw.kill()
	_move_tw = create_tween()
	_move_tw.tween_property(_player, "global_position", dest, 0.32) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Mochi si gira dando le spalle allo schienale e si raccoglie.
	# IL VERSO SI RICAVA DAL POSTO, non è più un `+ PI` fisso: lo
	# scostamento di SEATS punta sempre dalla parte OPPOSTA allo
	# schienale (è lì che finisce il corpo di chi si siede), quindi è
	# anche la direzione dello sguardo. Col mezzo giro sempre uguale, la
	# Sedia — che ora ha lo schienale dietro, a +Z come il Letto — faceva
	# sedere Mochi col muso dentro le doghe: il catalogo non lo mostra,
	# perché nel catalogo non c'è nessuno seduto.
	_mochi.set("_yaw", yaw_seduta(kind, seat.rotation.y))
	_mochi.call("set_pose", "sleep" if kind == "Letto" else "sit")
	if _sfx:
		_sfx.play("step_wood2", -16.0, 0.7)

	# a letto di notte non è un pisolino: si dorme fino al mattino
	if kind == "Letto" and _is_night():
		_sleep_until_morning()


func _stand_up() -> void:
	_seated = false
	_seat_node = null
	_mochi.call("set_pose", "stand")
	if _move_tw and _move_tw.is_valid():
		_move_tw.kill()
	_move_tw = create_tween()
	_move_tw.tween_property(_player, "global_position", _return_pos, 0.28) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_move_tw.tween_callback(func():
		if not _seated:
			_player.set_physics_process(true))
	if _sfx:
		_sfx.play("step_wood1", -16.0, 0.8)


## La notte scivola via: qualche "z", il sipario cala, il sole torna al
## mattino con la stamina piena, e Mochi si rialza da sola.
func _sleep_until_morning() -> void:
	_sleeping = true
	# L'OROLOGIO DEL VILLAGGIO SI FERMA PER TUTTA LA DORMITA. Fra la tenda,
	# il sogno e il «Buongiorno» passano una dozzina di secondi reali: chi
	# andava a letto negli ultimi istanti di notte li vedeva bastare a far
	# attraversare l'alba a `time` da solo (+1 giorno), e poi il salto al
	# mattino qui sotto veniva letto come salto all'indietro (+1 di nuovo).
	# Ci si addormentava al Giorno 2 e ci si svegliava al Giorno 4. A
	# orologio fermo il nuovo mattino lo dichiara solo la sveglia.
	# (Nel commento non si nomina la chiamata della sveglia: test_sogni
	# cerca QUEL nome nel sorgente per controllare che il sogno stia nel
	# buio, e lo troverebbe qui — cioè prima della tenda.)
	_daynight.call("sospendi_tempo", true)
	get_tree().call_group("regista", "note", "dormita")
	await get_tree().create_timer(2.1).timeout

	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)
	await tw.finished

	# ---- IL SOGNO. Sta QUI: nel nero, fra la tenda che si è chiusa e il
	# «Buongiorno». Non c'è nessuno stacco perché non serve — lo schermo è
	# già nero, e il sogno è il nero che si apre appena.
	#
	# Si sogna SOLO nel proprio letto. Un pisolino su un letto qualunque
	# resta un pisolino: è la differenza fra dormire e andare a dormire.
	if _e_il_mio_letto():
		var sogni := get_tree().get_first_node_in_group("sogni")
		if sogni and sogni.has_method("sogna"):
			await sogni.call("sogna", _fade)

	# l'orologio riparte PRIMA della sveglia: il mattino (uno solo) lo deve
	# contare il salto qui sotto, non i frame passati sullo schermo nero
	_daynight.call("sospendi_tempo", false)
	_daynight.set_time(_daynight.MORNING)
	var sc: Node = _player.get_node_or_null("SurvivalComponent")
	if sc:
		sc.set_stamina(sc.get_max_stamina())
	_wake_label.text = L10n.tf("Buongiorno!\nGiorno %d", [_daynight.day])
	if _sfx:
		_sfx.wake_up()

	# "Buongiorno!" sul buio, poi il sipario si riapre sul nuovo giorno
	var lt := create_tween()
	lt.tween_property(_wake_label, "modulate:a", 1.0, 0.5)
	lt.tween_interval(1.1)
	lt.tween_property(_wake_label, "modulate:a", 0.0, 0.5)
	await lt.finished

	var ft := create_tween()
	ft.tween_property(_fade, "color:a", 0.0, 1.6).set_trans(Tween.TRANS_SINE)
	await ft.finished

	_sleeping = false
	_stand_up()


## Per la verifica CLI: teletrasporta il player vicino al primo pezzo
## del tipo dato e lo fa sedere/dormire.
func debug_sit(kind: String) -> void:
	if _seated:
		_seated = false
		_seat_node = null
		_mochi.call("set_pose", "stand")
	for it in _build.get_interactables():
		if it["name"] == kind:
			var node := it["node"] as Node3D
			_player.global_position = node.global_position + Vector3(0, 0, 0.8)
			_sit_down(node, kind)
			return
