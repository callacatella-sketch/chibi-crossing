class_name FaceController
extends RefCounted

## Il "volto vivo" dei chibi: un rig facciale parametrico e un motore di
## espressioni di qualità da gioco AAA cozy (stile Animal Crossing / Cozy
## Grove), costruito tutto in modo procedurale come il resto del gioco.
##
## Il proprietario (Mochi, un villager, il negoziante…) costruisce le parti
## animabili — sopracciglia, occhioni con iride/luci mobili, palpebre a
## scatto, un set di bocche morbide, guanciotte — le consegna con [method
## setup] e poi chiama [method update] ogni frame DOPO aver posato testa e
## corpo. Il controller NON tocca la testa: recita solo dentro di essa, così
## non litiga con le animazioni del collo/della posa del proprietario.
##
## Cosa lo rende "vivo" e non una maschera fissa:
##   • espressioni fuse dolcemente (molla esponenziale), mai a scatti;
##   • ammicco naturale — intervallo variabile, doppi battiti, accoppiato ai
##     cambi di sguardo e d'umore, mai meccanico;
##   • sguardo con saccadi (i piccoli scatti dell'occhio) e inseguimento
##     morbido di un punto d'interesse, con micro-derive e sbirciate altrove;
##   • sopracciglia che è dove vive l'80% dell'emozione: si alzano, si
##     aggrottano, si inclinano tristi o arrabbiate;
##   • pupille/luci che si dilatano con la tenerezza e si stringono con la
##     tensione;
##   • micro-movimenti di riposo (respiro, guizzi del sopracciglio) perché
##     un viso fermo è un viso morto.
##
## Convenzione: la faccia guarda verso -Z (come tutto il resto).

# ---------------------------------------------------------------- espressioni
#
# Ogni espressione è un set di canali-obiettivo. Tutti sono relativi al
# riposo (neutro), così l'intensità li scala con naturalezza:
#   brow_h   sollevamento sopracciglia (+ su)
#   brow_ang inclinazione interna: + = arrabbiato (interno giù),
#            - = triste/preoccupato (interno su)
#   brow_sq  corrugamento verso il centro (concentrazione, sforzo)
#   eye_open apertura palpebre (1 = normale, <1 socchiuso, >1 spalancato)
#   eye_shape "open" | "happy" (occhi ad arco ^^) | "squint" (>.<)
#   pupil    dilatazione di iride e luci (>1 occhioni teneri, <1 tesi)
#   mouth    forma della bocca (vedi il set costruito dai builder)
#   mouth_open apertura della bocca (0..1: parlare, ridere, stupore)
#   blush    intensità extra delle guanciotte (0..1)
#   tilt     suggerimento di inclinazione del capo (il proprietario può leggerlo)
const EXPRESSIONS := {
	"neutro": {},
	"felice": {
		"brow_h": 0.018, "eye_open": 0.9, "eye_shape": "open",
		"pupil": 1.06, "mouth": "smile", "blush": 0.12, "tilt": 0.02,
	},
	"gioia": {
		"brow_h": 0.05, "eye_open": 0.6, "eye_shape": "happy",
		"pupil": 1.1, "mouth": "grin", "mouth_open": 0.45, "blush": 0.28, "tilt": 0.03,
	},
	"raggiante": {  # il sorriso pieno a occhi chiusi, la posa "cozy" per eccellenza
		"brow_h": 0.04, "eye_open": 0.2, "eye_shape": "happy",
		"pupil": 1.1, "mouth": "smile", "blush": 0.32,
	},
	"beato": {  # onsen, coccole: palpebre pesanti di piacere, sorrisino
		"brow_h": 0.01, "eye_open": 0.42, "eye_shape": "open",
		"pupil": 1.0, "mouth": "smile", "blush": 0.24, "tilt": 0.02,
	},
	"curioso": {
		"brow_h": 0.06, "eye_open": 1.12, "pupil": 1.12,
		"mouth": "o", "mouth_open": 0.2, "tilt": 0.12,
	},
	"meraviglia": {  # lo stupore dolce: occhioni spalancati pieni di stelle
		"brow_h": 0.06, "eye_open": 1.16, "pupil": 1.24,
		"mouth": "smile", "blush": 0.16, "tilt": 0.04,
	},
	"soffio": {  # soffiare sulla tazza: palpebre socchiuse, bocca a "o"
		"brow_h": 0.01, "eye_open": 0.5, "pupil": 1.0,
		"mouth": "o", "mouth_open": 0.15, "blush": 0.15,
	},
	"sorpresa": {
		"brow_h": 0.09, "eye_open": 1.32, "pupil": 1.22,
		"mouth": "O", "mouth_open": 0.6,
	},
	"triste": {
		"brow_ang": -0.1, "brow_h": 0.02, "eye_open": 0.8,
		"pupil": 1.14, "mouth": "sad", "blush": -0.1, "tilt": -0.08,
	},
	"assonnato": {
		"brow_h": -0.02, "eye_open": 0.34, "pupil": 0.96,
		"mouth": "neutral", "mouth_open": 0.05,
	},
	"dorme": {
		"brow_h": 0.0, "eye_open": 0.05, "eye_shape": "happy",
		"mouth": "neutral", "blush": 0.1,
	},
	"amore": {
		"brow_h": 0.03, "eye_open": 0.86, "pupil": 1.34,
		"mouth": "smile", "blush": 0.38, "tilt": 0.05,
	},
	"concentrato": {
		"brow_sq": 0.05, "brow_h": -0.012, "eye_open": 0.9,
		"pupil": 0.94, "mouth": "line",
	},
	"sforzo": {  # corsa, arrampicata: occhi a >.< e denti stretti
		"brow_sq": 0.06, "brow_h": 0.01, "eye_open": 0.5, "eye_shape": "squint",
		"pupil": 1.0, "mouth": "grin", "mouth_open": 0.22,
	},
	"spavento": {
		"brow_ang": -0.06, "brow_h": 0.06, "eye_open": 1.24,
		"pupil": 0.78, "mouth": "O", "mouth_open": 0.5,
	},
	"imbronciato": {
		"brow_ang": 0.09, "brow_sq": 0.06, "eye_open": 0.82,
		"pupil": 0.92, "mouth": "frown", "tilt": -0.03,
	},
}

# gli umori del Chibiese (neutro | felice | domanda | triste) mappati sul
# vocabolario ricco delle espressioni
const MOOD_TO_EXPR := {
	"neutro": "neutro", "felice": "felice",
	"domanda": "curioso", "triste": "triste",
}

# ---------------------------------------------------------------- il rig
var _head: Node3D
var _eyes: Array[Node3D] = []            # i pivot occhio (uno per lato)
var _eyeballs: Array[MeshInstance3D] = []  # l'ellissoide scuro (apertura via scale.y)
var _irises: Array[Node3D] = []          # il gruppo iride+luci (sguardo + dilatazione)
var _happy: Array[Node3D] = []           # l'arco ^^ (opzionale)
var _happy_base_scale: Array[Vector3] = []
var _squint: Array[Node3D] = []          # il >.< dello sforzo (opzionale)
var _squint_base_scale: Array[Vector3] = []
var _brows: Array[Node3D] = []           # i pivot sopracciglio (opzionali)
var _blush: Array[MeshInstance3D] = []   # le guanciotte (opzionali)
var _mouths := {}                        # nome -> Node3D (tutte le forme)
var _mouth_open_node: Node3D             # la cavità scura che si apre (parlare/ridere)

# stati di riposo memorizzati al setup, per animare in RELATIVO
var _eye_base_scale := Vector3(1, 1.18, 0.55)
var _eye_base_pos: Array[Vector3] = []
var _iris_base_scale := Vector3.ONE
var _brow_base_pos: Array[Vector3] = []
var _brow_base_rot: Array[Vector3] = []
var _blush_base_scale: Array[Vector3] = []
var _blush_base_alpha: Array[float] = []
var _face_side := 0.36    # semiapertura occhi (per normalizzare lo sguardo)

# ---------------------------------------------------------------- canali fusi
# valori correnti (fusi) e obiettivi
var _c_brow_h := 0.0
var _c_brow_ang := 0.0
var _c_brow_sq := 0.0
var _c_eye_open := 1.0
var _c_pupil := 1.0
var _c_mouth_open := 0.0
var _c_blush := 0.0
var _c_tilt := 0.0

var _t_brow_h := 0.0
var _t_brow_ang := 0.0
var _t_brow_sq := 0.0
var _t_eye_open := 1.0
var _t_pupil := 1.0
var _t_mouth_open := 0.0
var _t_blush := 0.0
var _t_tilt := 0.0

var _blend := 9.0        # velocità di fusione corrente (1-exp(-k*dt))
var _intensity := 1.0
var _expr := "neutro"

# forma occhi con crossfade morbido tra open/happy/squint
var _eye_shape := "open"
var _eye_shape_prev := "open"
var _shape_mix := 1.0    # 1 = del tutto sulla forma corrente

# forma bocca con crossfade
var _mouth := "neutral"
var _mouth_prev := "neutral"
var _mouth_mix := 1.0

# ---------------------------------------------------------------- vita propria
var _t := 0.0
var _rng := RandomNumberGenerator.new()

# ammicco
var _blink_enabled := true
var _next_blink := 2.0
var _blink_t := -1.0
var _blink_dur := 0.13
var _blink_queue := 0    # battiti extra in coda (doppio ammicco)

# sguardo
var _gaze_node: Node3D
var _gaze_point := Vector3.ZERO
var _gaze_has_point := false
var _gaze_cur := Vector2.ZERO      # offset applicato (occhio locale, normalizzato)
var _gaze_tgt := Vector2.ZERO      # bersaglio della saccade
var _gaze_drift := Vector2.ZERO
var _next_saccade := 0.8

# accento del sopracciglio (il "guizzo" dei saluti/sorprese) e riposo
var _brow_flash := 0.0
var _blush_boost := 0.0
var _talking := false
var _mouth_talk := 0.0

# impulso transitorio (un'espressione che rimbalza e poi rientra)
var _pulse_t := -1.0
var _pulse_dur := 0.0
var _pulse_prev := "neutro"


func setup(rig: Dictionary) -> void:
	_head = rig.get("head")
	_eyes.assign(rig.get("eyes", []))
	_eyeballs.assign(rig.get("eyeballs", []))
	_irises.assign(rig.get("irises", []))
	_happy.assign(rig.get("happy", []))
	_squint.assign(rig.get("squint", []))
	_brows.assign(rig.get("brows", []))
	_blush.assign(rig.get("blush", []))
	_mouths = rig.get("mouths", {})
	_mouth_open_node = rig.get("mouth_open")
	_eye_base_scale = rig.get("eye_base_scale", _eye_base_scale)
	_iris_base_scale = rig.get("iris_base_scale", Vector3.ONE)
	_face_side = rig.get("face_side", 0.36)

	_rng.randomize()
	for eye in _eyes:
		_eye_base_pos.append(eye.position)
	for iris in _irises:
		_iris_base_scale = iris.scale
	for h in _happy:
		_happy_base_scale.append(h.scale)
	for sq in _squint:
		_squint_base_scale.append(sq.scale)
	for b in _brows:
		_brow_base_pos.append(b.position)
		_brow_base_rot.append(b.rotation)
	for bl in _blush:
		_blush_base_scale.append(bl.scale)
		var a := 1.0
		var m := bl.material_override
		if m is StandardMaterial3D:
			a = (m as StandardMaterial3D).albedo_color.a
		_blush_base_alpha.append(a)

	_next_blink = _rng.randf_range(1.5, 4.0)
	_next_saccade = _rng.randf_range(0.5, 1.6)
	# la bocca di partenza è quella già visibile (neutra)
	for mn in _mouths:
		(_mouths[mn] as Node3D).visible = (str(mn) == "neutral")
	_apply_shape_visibility()


# ------------------------------------------------------------ API pubblica

## Imposta l'espressione bersaglio. [param intensity] la scala (0..1+),
## [param speed] quanto è rapida la fusione (più alto = più svelto).
func set_expression(name: String, intensity := 1.0, speed := 9.0) -> void:
	if not EXPRESSIONS.has(name):
		name = "neutro"
	_expr = name
	_intensity = intensity
	_blend = speed
	_load_targets(name, intensity)


func expression() -> String:
	return _expr


## Traduce un umore del Chibiese in espressione.
func set_mood(mood: String, intensity := 1.0) -> void:
	set_expression(MOOD_TO_EXPR.get(mood, "neutro"), intensity)


## Un'espressione lampo che poi rientra da sola in [param back] (usata per
## il guizzo di sorpresa/gioia di un saluto, un regalo, uno spavento).
func pulse(name: String, duration := 0.9, intensity := 1.0, back := "") -> void:
	_pulse_prev = back if back != "" else _expr
	_pulse_dur = duration
	_pulse_t = 0.0
	set_expression(name, intensity, 13.0)


## Aggancia lo sguardo a un nodo che si muove (il giocatore, un amico…).
func look_at_node(n: Node3D) -> void:
	_gaze_node = n
	_gaze_has_point = n != null


## Aggancia lo sguardo a un punto fisso del mondo.
func look_at_world(p: Vector3) -> void:
	_gaze_node = null
	_gaze_point = p
	_gaze_has_point = true


## Lascia vagare lo sguardo (riposo).
func clear_gaze() -> void:
	_gaze_node = null
	_gaze_has_point = false


## Mentre parla, la bocca si apre e chiude a ritmo e il sopracciglio accenta.
func set_talking(on: bool) -> void:
	_talking = on


## Un guizzo del sopracciglio (l'accento dei saluti, delle sorprese liete):
## si alza di scatto e rientra da solo. Compone SOPRA l'espressione, così si
## può usare anche quando l'espressione la sceglie qualcun altro ogni frame.
func brow_flash(amount := 1.0) -> void:
	_brow_flash = amount


## Un rossore extra sovrapposto (l'onsen, un abbraccio): si somma alle
## guanciotte dell'espressione senza esserne sovrascritto.
func set_blush_boost(x: float) -> void:
	_blush_boost = x


func set_blink_enabled(on: bool) -> void:
	_blink_enabled = on
	if not on:
		_blink_t = -1.0


func blink_now() -> void:
	if _blink_t < 0.0:
		_blink_t = 0.0


## Congela l'ammicco per [param sec] secondi (per gli scatti ravvicinati
## del DebugHarness: niente palpebre a metà nella foto).
func freeze_blink(sec: float) -> void:
	_next_blink = maxf(_next_blink, sec)
	_blink_t = -1.0


## Il suggerimento di inclinazione del capo dell'espressione corrente:
## il proprietario può SOMMARLO alla rotazione della testa, se vuole.
func head_tilt() -> float:
	return _c_tilt


# ------------------------------------------------------------ il motore

func update(delta: float) -> void:
	if _eyes.is_empty() and _brows.is_empty() and _mouths.is_empty():
		return
	_t += delta

	# impulso transitorio: allo scadere, torna all'espressione di sfondo
	if _pulse_t >= 0.0:
		_pulse_t += delta
		if _pulse_t >= _pulse_dur:
			_pulse_t = -1.0
			set_expression(_pulse_prev, _intensity, 8.0)

	_blend_channels(delta)
	_apply_brows(delta)
	_apply_eyes(delta)
	_apply_mouth(delta)
	_apply_blush()


# fusione esponenziale dei canali continui verso gli obiettivi
func _blend_channels(delta: float) -> void:
	var k := 1.0 - exp(-_blend * delta)
	_c_brow_h = lerpf(_c_brow_h, _t_brow_h, k)
	_c_brow_ang = lerpf(_c_brow_ang, _t_brow_ang, k)
	_c_brow_sq = lerpf(_c_brow_sq, _t_brow_sq, k)
	_c_eye_open = lerpf(_c_eye_open, _t_eye_open, k)
	_c_pupil = lerpf(_c_pupil, _t_pupil, k)
	_c_mouth_open = lerpf(_c_mouth_open, _t_mouth_open, k)
	_c_blush = lerpf(_c_blush, _t_blush, k)
	_c_tilt = lerpf(_c_tilt, _t_tilt, k)
	# guizzo del sopracciglio che si spegne
	_brow_flash = lerpf(_brow_flash, 0.0, 1.0 - exp(-6.0 * delta))


func _load_targets(name: String, intensity: float) -> void:
	var e: Dictionary = EXPRESSIONS[name]
	_t_brow_h = float(e.get("brow_h", 0.0)) * intensity
	_t_brow_ang = float(e.get("brow_ang", 0.0)) * intensity
	_t_brow_sq = float(e.get("brow_sq", 0.0)) * intensity
	_t_eye_open = lerpf(1.0, float(e.get("eye_open", 1.0)), intensity)
	_t_pupil = lerpf(1.0, float(e.get("pupil", 1.0)), intensity)
	_t_mouth_open = float(e.get("mouth_open", 0.0)) * intensity
	_t_blush = float(e.get("blush", 0.0)) * intensity
	_t_tilt = float(e.get("tilt", 0.0)) * intensity
	# forma occhi (crossfade)
	var shape := str(e.get("eye_shape", "open"))
	if not _has_shape(shape):
		shape = "open"
	if shape != _eye_shape:
		_eye_shape_prev = _eye_shape
		_eye_shape = shape
		_shape_mix = 0.0
	# forma bocca (crossfade)
	var m := str(e.get("mouth", "neutral"))
	if not _mouths.has(m):
		m = "neutral" if _mouths.has("neutral") else _mouth
	if m != _mouth:
		_mouth_prev = _mouth
		_mouth = m
		_mouth_mix = 0.0


func _has_shape(shape: String) -> bool:
	match shape:
		"happy": return not _happy.is_empty()
		"squint": return not _squint.is_empty()
		_: return true


# ------------------------------------------------------------ sopracciglia
func _apply_brows(delta: float) -> void:
	if _brows.is_empty():
		return
	# riposo vivo: un respiro lentissimo del sopracciglio + il guizzo
	var idle := sin(_t * 0.9) * 0.004
	var flash := _brow_flash * 0.05
	for i in _brows.size():
		var b := _brows[i]
		var side := -1.0 if i == 0 else 1.0
		var base_p: Vector3 = _brow_base_pos[i]
		var base_r: Vector3 = _brow_base_rot[i]
		# alzata (+y), corrugamento verso il centro (x), inclinazione interna (z)
		b.position.y = base_p.y + _c_brow_h + idle + flash
		b.position.x = base_p.x - side * _c_brow_sq
		# l'angolo interno: arrabbiato abbassa l'interno, triste lo alza.
		# lo z locale ruota il sopracciglio; il segno dipende dal lato.
		b.rotation.z = base_r.z + side * _c_brow_ang


# ------------------------------------------------------------ occhi + sguardo
func _apply_eyes(delta: float) -> void:
	if _eyes.is_empty():
		return
	_update_blink(delta)
	_update_gaze(delta)

	# apertura effettiva = espressione × ammicco
	var blink_close := 0.0
	if _blink_t >= 0.0:
		blink_close = sin(clampf(_blink_t / _blink_dur, 0.0, 1.0) * PI)
	# respiro: un filo di apertura che pulsa
	var breath := 1.0 + sin(_t * 2.1) * 0.015
	var aperture := clampf(_c_eye_open * breath * (1.0 - blink_close * 0.94), 0.02, 1.6)

	# crossfade tra forme d'occhio (open / happy / squint)
	if _shape_mix < 1.0:
		_shape_mix = minf(1.0, _shape_mix + delta * 8.0)
	_apply_shape_visibility()

	var wide := clampf(_c_eye_open - 1.0, 0.0, 0.6)
	for i in _eyes.size():
		# lo sguardo sposta appena il pivot dell'occhio (la sbirciata)
		var eye := _eyes[i]
		var gx := _gaze_cur.x * 0.018
		var gy := _gaze_cur.y * 0.014
		eye.position = _eye_base_pos[i] + Vector3(gx, gy, 0.0)

		if i < _eyeballs.size() and _eyeballs[i] != null:
			var ball := _eyeballs[i]
			# apertura sull'asse Y, un filo di allargamento X quando spalanca
			ball.scale.y = _eye_base_scale.y * aperture
			ball.scale.x = _eye_base_scale.x * (1.0 + wide * 0.2)
			ball.scale.z = _eye_base_scale.z

		# iride/luci: dilatazione + inseguimento dello sguardo dentro l'occhio
		if i < _irises.size() and _irises[i] != null:
			var iris := _irises[i]
			iris.scale = _iris_base_scale * _c_pupil
			iris.position.x = _gaze_cur.x * 0.02
			iris.position.y = _gaze_cur.y * 0.016


func _apply_shape_visibility() -> void:
	# la forma corrente entra, la precedente esce; sotto 0.5 mostro ancora la
	# vecchia, sopra la nuova — con un piccolo "pop" di scala
	var on_cur := _shape_mix >= 0.5
	var cur := _eye_shape if on_cur else _eye_shape_prev
	var pop := 0.7 + 0.3 * _shape_mix if on_cur else 0.7 + 0.3 * (1.0 - _shape_mix)
	for i in _eyes.size():
		var show_open := cur == "open"
		var show_happy := cur == "happy"
		var show_squint := cur == "squint"
		if i < _eyeballs.size() and _eyeballs[i]:
			_eyeballs[i].visible = show_open
		if i < _irises.size() and _irises[i]:
			_irises[i].visible = show_open
		if i < _happy.size() and _happy[i]:
			_happy[i].visible = show_happy
			if show_happy:
				_happy[i].scale = _happy_base_scale[i] * pop
		if i < _squint.size() and _squint[i]:
			_squint[i].visible = show_squint
			if show_squint:
				# il >.< può avere uno scale.x con segno (specchiatura): il
				# "pop" moltiplica la scala di riposo preservandone il segno
				_squint[i].scale = _squint_base_scale[i] * pop


func _update_blink(delta: float) -> void:
	# nessun ammicco se disattivato o se l'espressione tiene già gli occhi
	# quasi chiusi (dorme, raggiante): sarebbe un doppione innaturale
	var eyes_shut := _t_eye_open < 0.18
	if not _blink_enabled or eyes_shut:
		if _blink_t >= 0.0:
			_blink_t = -1.0
		return
	if _blink_t >= 0.0:
		_blink_t += delta
		if _blink_t >= _blink_dur:
			_blink_t = -1.0
			if _blink_queue > 0:
				# doppio ammicco: un secondo battito subito dopo
				_blink_queue -= 1
				_blink_t = 0.0
		return
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink_t = 0.0
		_blink_dur = _rng.randf_range(0.1, 0.16)
		_next_blink = _rng.randf_range(2.2, 6.0)
		if _rng.randf() < 0.14:
			_blink_queue = 1   # ogni tanto un doppio battito


func _update_gaze(delta: float) -> void:
	# bersaglio dello sguardo: verso il punto/nodo agganciato, proiettato
	# nello spazio locale della testa e normalizzato in [-1,1]
	var want := Vector2.ZERO
	if _gaze_has_point and _head != null and is_instance_valid(_head) and _head.is_inside_tree():
		var p := _gaze_point
		if _gaze_node != null and is_instance_valid(_gaze_node) and _gaze_node.is_inside_tree():
			p = _gaze_node.global_position
		var loc := _head.to_local(p)
		# davanti = -Z: x a destra/sinistra, y su/giù; normalizza sulla scala
		# del viso e clampa perché l'occhio ha una corsa limitata
		want.x = clampf(loc.x / maxf(_face_side, 0.001), -1.0, 1.0)
		want.y = clampf(loc.y / 0.35, -0.7, 0.9)

	# saccadi: lo sguardo non scivola, SALTA. ogni tanto un nuovo bersaglio
	# (o una sbirciata altrove se vaga a riposo)
	_next_saccade -= delta
	if _next_saccade <= 0.0:
		_next_saccade = _rng.randf_range(0.7, 2.4)
		if _gaze_has_point:
			# micro-scarto attorno al bersaglio: l'occhio non è un laser
			_gaze_tgt = want + Vector2(_rng.randf_range(-0.12, 0.12),
					_rng.randf_range(-0.1, 0.1))
			# ogni tanto una breve sbirciata via, poi torna
			if _rng.randf() < 0.2:
				_gaze_tgt += Vector2(_rng.randf_range(-0.6, 0.6),
						_rng.randf_range(-0.3, 0.3))
			# un cambio di sguardo spesso accompagna un ammicco
			if _rng.randf() < 0.35 and _blink_t < 0.0:
				blink_now()
		else:
			# a riposo: vaga piano, sguardo sognante
			_gaze_tgt = Vector2(_rng.randf_range(-0.5, 0.5),
					_rng.randf_range(-0.35, 0.45))
	elif _gaze_has_point:
		# tra una saccade e l'altra insegue morbido il bersaglio che si muove
		_gaze_tgt = _gaze_tgt.lerp(want, 1.0 - exp(-4.0 * delta))

	# micro-deriva continua (l'occhio non sta mai perfettamente fermo)
	_gaze_drift = _gaze_drift.lerp(Vector2(sin(_t * 1.7) * 0.05,
			sin(_t * 2.3 + 1.0) * 0.04), 1.0 - exp(-3.0 * delta))
	# lo scatto della saccade è rapido, poi si assesta
	_gaze_cur = _gaze_cur.lerp(_gaze_tgt + _gaze_drift, 1.0 - exp(-22.0 * delta))


# ------------------------------------------------------------ bocca
func _apply_mouth(delta: float) -> void:
	if _mouths.is_empty():
		return
	# crossfade tra forme: la nuova cresce, la vecchia rimpicciolisce
	if _mouth_mix < 1.0:
		_mouth_mix = minf(1.0, _mouth_mix + delta * 10.0)
	var on_new := _mouth_mix >= 0.5
	var show: String = _mouth if on_new else _mouth_prev
	var pop := 0.6 + 0.4 * (_mouth_mix if on_new else 1.0 - _mouth_mix)
	for mn in _mouths:
		var node: Node3D = _mouths[mn]
		var vis: bool = str(mn) == show
		node.visible = vis
		if vis:
			node.scale = Vector3.ONE * pop

	# apertura (parlare / ridere / stupore): la cavità scura cresce e la
	# bocca "pulsa" col parlato
	if _talking:
		_mouth_talk = lerpf(_mouth_talk, 0.5 + sin(_t * 15.0) * 0.5, 1.0 - exp(-18.0 * delta))
	else:
		_mouth_talk = lerpf(_mouth_talk, 0.0, 1.0 - exp(-12.0 * delta))
	var open := clampf(maxf(_c_mouth_open, _mouth_talk * 0.6), 0.0, 1.0)
	if _mouth_open_node != null:
		_mouth_open_node.visible = open > 0.02
		var s := 0.2 + open
		_mouth_open_node.scale = Vector3(s, open * 1.1 + 0.1, 1.0)


# ------------------------------------------------------------ guanciotte
func _apply_blush() -> void:
	if _blush.is_empty():
		return
	for i in _blush.size():
		var bl := _blush[i]
		var extra := clampf(_c_blush + _blush_boost, -0.5, 0.9)
		bl.scale = _blush_base_scale[i] * (1.0 + extra * 0.5)
		var m := bl.material_override
		if m is StandardMaterial3D:
			(m as StandardMaterial3D).albedo_color.a = clampf(
					_blush_base_alpha[i] * (1.0 + extra), 0.0, 1.0)


# ================================================================ costruzione
# Helper statici condivisi: Mochi e ChibiBuilder li usano per costruire le
# stesse parti facciali, così il rig è identico per il giocatore e i vicini.

## Un sopracciglio: una barretta morbida leggermente arcuata, appesa a un
## pivot alla sua radice interna (così alzarlo/inclinarlo ruota bene).
## Ritorna il pivot. [param side] -1 = sinistro, +1 = destro.
static func build_brow(parent: Node3D, mat: Material, side: float,
		pos: Vector3, length := 0.12, thick := 0.016) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	# un filo di inclinazione a riposo, verso l'esterno: sguardo dolce
	pivot.rotation.z = side * 0.06
	parent.add_child(pivot)
	# tre perline che digradano verso l'esterno danno l'arco morbido
	var n := 4
	for i in n:
		var f := float(i) / float(n - 1)          # 0 = interno, 1 = esterno
		var r := thick * (1.0 - f * 0.45)
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 10
		sm.rings = 6
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = mat
		# cresce verso l'esterno (side) e si incurva appena in su a metà
		mi.position = Vector3(side * f * length, sin(f * PI) * 0.012, 0.0)
		mi.scale = Vector3(1.25, 0.7, 0.6)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mi)
	return pivot


## Il set completo di bocche morbide, tutte figlie di un nodo al centro
## bocca (così si scalano/nascondono insieme). Ritorna {nome -> Node3D}.
## Le forme: neutral (la "w" da gattino), smile, grin (sorriso aperto),
## o / O (stupori), frown, sad, line (bocca seria). [param mz] è la Z locale
## su cui appoggiarle sul musetto.
static func build_mouth_set(parent: Node3D, mat: Material, center: Vector3,
		scale := 1.0) -> Dictionary:
	var out := {}
	var mz := 0.0
	# nodo genitore per ciascuna forma, tutte allo stesso centro
	var mk := func(shape_name: String) -> Node3D:
		var n := Node3D.new()
		n.position = center
		n.visible = false
		parent.add_child(n)
		out[shape_name] = n
		return n

	var dot := func(host: Node3D, p: Vector3, r: float) -> void:
		var sm := SphereMesh.new()
		sm.radius = r * scale
		sm.height = r * 2.0 * scale
		sm.radial_segments = 8
		sm.rings = 5
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = mat
		mi.position = p * scale
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(mi)

	# neutral: la "w" da micio (due archetti)
	var wnode: Node3D = mk.call("neutral")
	for s: float in [-1.0, 1.0]:
		for i in 7:
			var a := PI + (float(i) / 6.0) * PI
			dot.call(wnode, Vector3(s * 0.024 + cos(a) * 0.024, sin(a) * 0.024, mz), 0.0085)

	# smile: un arco dolce all'insù (concavo in alto)
	var sm_node: Node3D = mk.call("smile")
	for i in 11:
		var f := float(i) / 10.0
		var a := PI * (1.0 - f)                # da PI a 0
		dot.call(sm_node, Vector3(cos(a) * 0.05, -0.006 + sin(a) * 0.03, mz), 0.009)

	# grin: sorriso più largo e aperto (la cavità la aggiunge mouth_open)
	var gr_node: Node3D = mk.call("grin")
	for i in 13:
		var f := float(i) / 12.0
		var a := PI * (1.0 - f)
		dot.call(gr_node, Vector3(cos(a) * 0.062, -0.004 + sin(a) * 0.026, mz), 0.0092)

	# frown: arco all'ingiù (concavo in basso)
	var fr_node: Node3D = mk.call("frown")
	for i in 11:
		var f := float(i) / 10.0
		var a := PI * f                        # da 0 a PI
		dot.call(fr_node, Vector3(cos(a) * 0.05 * -1.0, -0.03 + sin(a) * 0.03, mz), 0.009)

	# sad: come frown ma più stretto e cadente ai lati
	var sad_node: Node3D = mk.call("sad")
	for i in 9:
		var f := float(i) / 8.0
		var a := PI * f
		dot.call(sad_node, Vector3(cos(a) * -0.04, -0.028 + sin(a) * 0.026, mz), 0.0088)

	# line: una bocca seria, quasi dritta
	var ln_node: Node3D = mk.call("line")
	for i in 7:
		var f := float(i) / 6.0
		dot.call(ln_node, Vector3((f - 0.5) * 0.075, 0.0, mz), 0.008)

	# o e O: due anellini di stupore
	for pair: Array in [["o", 0.013, 0.026], ["O", 0.02, 0.04]]:
		var node: Node3D = mk.call(str(pair[0]))
		var tm := TorusMesh.new()
		tm.inner_radius = float(pair[1]) * scale
		tm.outer_radius = float(pair[2]) * scale
		tm.rings = 12
		tm.ring_segments = 10
		var o := MeshInstance3D.new()
		o.mesh = tm
		o.material_override = mat
		o.position = Vector3(0, -0.004, mz) * scale
		o.rotation.x = PI * 0.5
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(o)

	out["neutral"].visible = true
	return out


## La cavità scura della bocca aperta (parlare/ridere/stupore): un piccolo
## ellissoide dietro le labbra, che il controller scala con mouth_open.
static func build_mouth_open(parent: Node3D, mat: Material, center: Vector3,
		scale := 1.0) -> Node3D:
	var sm := SphereMesh.new()
	sm.radius = 0.03 * scale
	sm.height = 0.06 * scale
	sm.radial_segments = 14
	sm.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = mat
	mi.position = center + Vector3(0, -0.006, 0.004) * scale
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	parent.add_child(mi)
	return mi


## Gli occhi ad arco "^^" della felicità piena: un archetto all'insù per lato,
## nascosto a riposo. [param side] -1/-+1, [param center] posizione locale.
static func build_happy_arc(parent: Node3D, mat: Material, center: Vector3,
		side: float, r := 0.085) -> Node3D:
	var node := Node3D.new()
	node.position = center
	node.visible = false
	parent.add_child(node)
	var n := 7
	for i in n:
		var f := float(i) / float(n - 1)
		var a := PI * (1.0 - f)                # arco all'insù
		var sm := SphereMesh.new()
		sm.radius = 0.011
		sm.height = 0.022
		sm.radial_segments = 8
		sm.rings = 5
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = mat
		mi.position = Vector3(cos(a) * r, sin(a) * r * 0.5, -r * 0.5)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
	return node
