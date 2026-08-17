extends Node

## IL RIMBALZELLO — un sasso piatto, la riva giusta, e il silenzio dopo.
##
## Non c'è un punteggio. Il punteggio È IL SUONO: ogni rimbalzo suona un
## gradino più su della scala pentatonica (la stessa di
## `Concertino.gradino()`, quella dove non esiste la nota storta), e più
## rimbalzi fai più la frasetta sale. Quando il sasso si stanca e affonda,
## resta l'ultimo plop grave — e i cerchi sull'acqua che si allargano.
## Chi gioca capisce come sta andando **con l'orecchio**, senza guardare
## un numero: è la stessa idea per cui il villaggio illuminato racconta la
## scala della ribellione senza aprire un pannello.
##
## LA BRAVURA NON È NEI RIFLESSI. Non c'è una barra da fermare al punto
## giusto: il rimbalzello viene bene quando **l'aria è ferma**. Nella
## nebbiolina del mattino l'acqua è uno specchio e il sasso corre; con la
## folata di un temporale in arrivo si pianta al secondo salto. Il vento
## è quello vero, condiviso con l'erba e le chiome
## (`shaders/vento.gdshaderinc`, globale `vento_forza`): imparare a
## leggere il cielo è tutta l'abilità che serve.
##
## IL SASSO NON SI COMPRA. Lo porta il vicino che **colleziona sassolini**
## (l'indole `colleziona_sassolini` di VillagerBrain, con la sua
## animazione `tk_sasso`): esisteva da sempre, faceva una cosa carina e
## non serviva a niente. Adesso quello che raccoglie te lo regala, e
## diventa il tuo tiro di domani.
##
## Le decisioni sono PURE (quanti rimbalzi, che nota) e si provano
## headless in tests/cases/test_rimbalzello.gd.

const CONCERTINO := preload("res://scenes/interact/Concertino.gd")
const UI_BROWN := Color("6a4a3a")

## L'id del tesoro-munizione (Inventory.TREASURES).
const SASSO := "sasso_piatto"

## IL SASSO SI TIRA DAL BORDO. La canna si lancia da tutta la fascia di
## riva (Fishing: da 0.4 dentro a 2.2 fuori); il rimbalzello no — per far
## strisciare un sasso bisogna stare PROPRIO sull'orlo dell'acqua. È una
## regola fisica, che si impara in un gesto e si legge nel cartiglio: fai
## un passo avanti e tiri il sasso, fai un passo indietro e peschi.
## (Senza, i due gesti si contendevano la stessa E su tutta la riva e
## vinceva la canna per l'ordine dei nodi nel .tscn: il sasso partiva in
## 19 cm su 279.)
const RIVA_DENTRO := 0.35
const RIVA_FUORI := 0.75

# --- i numeri del tiro ---
## I rimbalzi di un tiro qualunque, ad aria ferma.
const RIMBALZI_BASE := 4
## Il minimo assoluto: anche il tiro peggiore rimbalza due volte. Qui non
## si fallisce mai — al massimo il sasso è pigro.
const RIMBALZI_MINIMO := 2
## Il tetto: oltre, la frasetta non salirebbe più (e non ci si crederebbe).
const RIMBALZI_MASSIMO := 9
## Quanto pesa il vento: a `vento_forza` 1.8 (temporale) toglie tre salti.
const PESO_VENTO := 2.2

var _player: Node3D
var _mochi: Node3D
var _cozy: Node3D
var _inventory: Node
var _sfx
var _visitors: Node

var _busy := false
var _record := 0

var _prompt: PanelContainer
var _prompt_label: Label


func _ready() -> void:
	add_to_group("rimbalzello")
	add_to_group("persistable")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_ui()
	(func() -> void:
		_player = get_node_or_null("%Player")
		_mochi = _player.get_node_or_null("Mochi") if _player else null
		_cozy = get_node_or_null("../CozyWorld")
		_inventory = get_node_or_null("../Inventory")
		_visitors = get_node_or_null("../Visitors")
		_iscrivi_alla_e()
	).call_deferred()


# ============================================================ le decisioni (pure)

## Quanti rimbalzi fa questo tiro. `caso` è un randf() 0..1 passato da
## fuori (così la funzione resta pura), `vento` è il globale `vento_forza`
## (1 = brezza di un giorno sereno, 0.45 = nebbia, 1.8 = temporale).
## Non si fallisce mai: il minimo è due.
static func rimbalzi(caso: float, vento: float) -> int:
	# l'aria ferma è il vero talento: sotto la brezza si guadagna, sopra
	# si perde. Il sasso non sa niente dei tuoi riflessi, sa dell'acqua.
	var calma := (1.0 - clampf(vento, 0.0, 2.0)) * PESO_VENTO
	# e un pizzico di fortuna, che tiene vivo il gesto anche al centesimo tiro
	var fortuna := (clampf(caso, 0.0, 1.0) - 0.35) * 4.0
	# IL TIRO D'ORO. Senza questo, il tetto era irraggiungibile: col vento
	# più fermo possibile e la fortuna massima si arrivava a otto, e i nove
	# rimbalzi (con la loro frase) erano codice morto. Una volta ogni tanto,
	# e solo quando l'aria è già ferma, il sasso non si stanca: è la cosa
	# che fa raccontare la partita a chi c'era.
	var oro := 1.0 if (caso > 0.97 and vento < 0.8) else 0.0
	var n := roundi(float(RIMBALZI_BASE) + calma + fortuna + oro)
	return clampi(n, RIMBALZI_MINIMO, RIMBALZI_MASSIMO)


## Il pitch del rimbalzo i-esimo: un gradino pentatonico più su a ogni
## salto. È il punteggio, detto all'orecchio invece che agli occhi.
static func tono(i: int) -> float:
	return pow(2.0, float(CONCERTINO.gradino(i)) / 12.0)


## Quanto è distante il rimbalzo i-esimo dal precedente: i salti si
## accorciano man mano che il sasso perde forza (è quello che li rende
## un ritmo invece che un metronomo).
static func passo(i: int, quanti: int) -> float:
	var t := float(i) / float(maxi(quanti - 1, 1))
	return lerpf(1.5, 0.42, t * t)


## L'altezza del rimbalzo i-esimo: sempre più bassa, fino a strisciare.
static func altezza(i: int, quanti: int) -> float:
	var t := float(i) / float(maxi(quanti - 1, 1))
	return lerpf(0.30, 0.045, t)


# ============================================================ il gesto

func _sassi() -> int:
	if _inventory == null:
		return 0
	return int((_inventory.get("treasures") as Dictionary).get(SASSO, 0))


func _sulla_riva() -> bool:
	if _cozy == null or _player == null:
		return false
	var d: float = _player.global_position.distance_to(_cozy.POND_CENTER)
	return d > _cozy.POND_R - RIVA_DENTRO and d < _cozy.POND_R + RIVA_FUORI


func _vento() -> float:
	var w := get_tree().get_first_node_in_group("weather")
	if w and w.has_method("vento"):
		# lo stato vero del cielo, dallo stesso posto che lo dice all'erba
		# (l'API pubblica, non il campo privato: un rinomina e il tiro
		# tornava a essere sempre di brezza, in silenzio)
		return float(w.call("vento"))
	return 1.0


## SI PUÒ TIRARE, QUI E ORA? Una condizione sola, letta da tutti e tre
## quelli che devono saperlo: il tasto, il cartiglio e l'arbitro della E.
## Prima erano due copie che divergevano — e il cartiglio prometteva un
## tiro mentre la E faceva un'altra cosa.
func _posso_tirare() -> bool:
	if _busy or _player == null or not _player.is_physics_processing():
		return false
	if not _sulla_riva() or _sassi() <= 0:
		return false
	# una creatura a portata di retino ha la precedenza: passa e non ripassa
	var coll := get_node_or_null("../Collection")
	if coll and not (coll.call("_nearest_catch") as Dictionary).is_empty():
		return false
	# e una lenza già in acqua pure: prima si ritira la canna
	var pesca := get_node_or_null("../Fishing")
	if pesca and str(pesca.get("_state")) != "off":
		return false
	return true


# --- l'arbitro della E (systems/ArbitroE.gd) --------------------------
# Sulla riva la E è contesa con la canna, e senza arbitro vinceva la canna
# per un motivo che il giocatore non può nemmeno immaginare: l'ordine dei
# nodi nel .tscn. Su tutta la fascia di riva il sasso partiva in 19 cm su
# 279. Adesso a decidere è una regola scritta.

func distanza_e() -> float:
	if not _posso_tirare():
		return -1.0
	# quanto sei vicino all'acqua: sulla riva vera il gesto del sasso è più
	# "a portata" della canna, che si lancia anche da un passo indietro
	return absf(_player.global_position.distance_to(_cozy.POND_CENTER) - _cozy.POND_R)


func agisci_e() -> void:
	if _posso_tirare():
		_tira()


func _iscrivi_alla_e() -> void:
	var arb := get_tree().get_first_node_in_group("arbitro_e")
	if arb:
		arb.iscrivi(self, "rimbalzello", arb.GESTO,
				Callable(self, "distanza_e"), Callable(self, "agisci_e"))


func _unhandled_input(event: InputEvent) -> void:
	# rete di riserva per quando l'arbitro non c'è (test, harness): la
	# regola vera la applica l'arbitro, che intercetta la E prima di qui
	if not event.is_action_pressed("interact"):
		return
	if not _posso_tirare():
		return
	_tira()
	get_viewport().set_input_as_handled()


func _tira() -> void:
	_busy = true
	_inventory.take_treasure(SASSO)
	var quanti := rimbalzi(randf(), _vento())

	# Mochi si volta verso l'acqua e carica il braccio: l'anticipazione è
	# ciò che vende il colpo (la stessa di retino e canna)
	var centro: Vector3 = _cozy.POND_CENTER
	var dir := ((centro - _player.global_position) * Vector3(1, 0, 1)).normalized()
	_mochi.set("_yaw", atan2(-dir.x, -dir.z))
	var sasso := _fai_sasso()
	_mochi.call("attach_to_paw", sasso)
	# NIENTE position qui: l'offset della zampa lo mette attach_to_paw, e
	# azzerarlo faceva partire il sasso dalla SPALLA
	sasso.scale = Vector3.ONE * 0.05
	_mochi.call("hold_swing", true)

	var tw := create_tween()
	tw.tween_property(sasso, "scale", Vector3.ONE, 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.12)          # il respiro prima del lancio
	tw.tween_callback(func() -> void:
		if _sfx:
			_sfx.net_swish())
	# la frustata di polso, bassa e radente: il rimbalzello non si tira
	# dall'alto, si tira di taglio
	tw.tween_property(_mochi, "pour", 1.0, 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _vola(sasso, dir, quanti))


func _vola(sasso: Node3D, dir: Vector3, quanti: int) -> void:
	# il sasso lascia la zampa e diventa del mondo
	var partenza: Vector3 = sasso.global_position
	sasso.reparent(self)
	sasso.scale = Vector3.ONE
	sasso.global_position = partenza
	_mochi.call("hold_swing", false)

	var acqua := 0.06
	var pos := partenza
	# QUANTA ACQUA C'È DAVANTI. Un tiro fortunato correva più dello stagno
	# (i passi sommano fino a ~6 m, il diametro è 7.2 m ma si tira dalla
	# riva): gli ultimi rimbalzi cadevano sull'erba dall'altra parte, coi
	# cerchi che si allargavano sul prato. I salti si riscalano per stare
	# nell'acqua — il ritmo che si stringe resta identico, cambia il passo.
	var corsa := 0.0
	for i in quanti:
		corsa += passo(i, quanti)
	var disponibile := _acqua_davanti(partenza, dir)
	var fattore := 1.0 if corsa <= disponibile else (disponibile / maxf(corsa, 0.01))
	var tw := create_tween()
	for i in quanti:
		var salto := passo(i, quanti) * fattore
		var meta := pos + dir * salto
		meta.y = acqua
		var alto := altezza(i, quanti)
		# la parabola del salto: su e giù, sempre più rasente
		tw.tween_property(sasso, "global_position",
				(pos + meta) * 0.5 + Vector3(0, alto, 0), 0.09 + 0.02 * float(i)) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sasso, "rotation:z", float(i + 1) * TAU * 1.2, 0.18)
		tw.tween_property(sasso, "global_position", meta, 0.08 + 0.02 * float(i)) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		var qui := meta
		var n := i
		tw.tween_callback(func() -> void: _tocco(qui, n))
		pos = meta
	# l'ultimo tuffo: il sasso si stanca e affonda, con un plop grave
	tw.tween_property(sasso, "global_position", pos + dir * 0.25 * fattore - Vector3(0, 0.25, 0),
			0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if _cozy:
			_cozy.water_ripple(pos, 1.1)
		if _sfx:
			_sfx.play("plop", -9.0, 0.62)   # il grave della fine
		sasso.queue_free()
		_finito(quanti))


## Quanta acqua c'è davanti, lungo la direzione del tiro: dal punto di
## partenza fino alla riva opposta, meno un margine perché l'ultimo
## rimbalzo non finisca sulla sabbia. Geometria di un cerchio, niente
## raycast: lo stagno È un cerchio (POND_CENTER, POND_R).
func _acqua_davanti(da: Vector3, dir: Vector3) -> float:
	if _cozy == null:
		return 5.0
	var c: Vector3 = _cozy.POND_CENTER
	var r: float = _cozy.POND_R
	# la retta da->dir contro il cerchio, sul piano
	var o := Vector2(da.x - c.x, da.z - c.z)
	var d := Vector2(dir.x, dir.z).normalized()
	var b := o.dot(d)
	var disc := b * b - (o.length_squared() - r * r)
	if disc <= 0.0:
		return 1.2          # non punta all'acqua: un tiro cortissimo
	# la seconda intersezione è la riva opposta
	return maxf(0.8, (-b + sqrt(disc)) - 0.55)


# un tocco sull'acqua: il cerchio che si allarga e la nota che sale
func _tocco(dove: Vector3, i: int) -> void:
	if _cozy:
		_cozy.water_ripple(dove, 0.5 + 0.12 * float(i))
	if _sfx:
		# più il sasso va avanti più il plop è acuto e leggero: è il
		# punteggio, e lo si sente salire
		_sfx.play("plop", -13.0 + float(i) * 0.4, tono(i))


func _finito(quanti: int) -> void:
	_busy = false
	# nessun numero a schermo per un tiro qualunque: il suono l'ha già
	# detto. Si parla solo quando succede qualcosa che merita parole.
	if quanti > _record:
		_record = quanti
		_toast(L10n.tf("%d rimbalzi: non era mai andata così lontano.", [quanti]))
		var bs := get_tree().get_first_node_in_group("build_system")
		if bs:
			bs.call("request_save")
	elif quanti >= RIMBALZI_MASSIMO:
		_toast(L10n.t("Il sasso ha attraversato tutto lo stagno."))


## Il sasso piatto: un disco appena ovale, grigio di fiume, con la faccia
## superiore un filo più chiara (l'ha levigata l'acqua).
func _fai_sasso() -> Node3D:
	var node := Node3D.new()
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.055
	cm.bottom_radius = 0.055
	cm.height = 0.016
	cm.radial_segments = 10
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("8e9299")
	mat.roughness = 0.85
	mi.mesh = cm
	mi.material_override = mat
	mi.scale = Vector3(1.0, 1.0, 0.82)   # appena ovale: fatto dall'acqua
	mi.rotation.x = PI * 0.5             # coricato, come si tiene per tirare
	node.add_child(mi)
	return node


# ============================================================ UI

func _process(_delta: float) -> void:
	_aggiorna_prompt()


func _aggiorna_prompt() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not _posso_tirare():
		_prompt.visible = false
		return
	var quanti := _sassi()
	var wp: Vector3 = _player.global_position + Vector3(0, 1.35, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = L10n.tf("E — fai rimbalzare il sasso  (%d)", [quanti])
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _toast(testo: String) -> void:
	if _visitors and _visitors.has_method("_show_toast"):
		_visitors.call("_show_toast", testo)


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


# ---------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	return {"rimbalzello": {"record": _record}}


func load_extra(data: Dictionary) -> void:
	var d: Variant = data.get("rimbalzello")
	if d is Dictionary:
		_record = int((d as Dictionary).get("record", 0))


func record() -> int:
	return _record


# ---------------------------------------------------------------- debug CLI

func debug_tira() -> void:
	if not _busy and _inventory:
		_inventory.add_treasure(SASSO)
		_tira()
