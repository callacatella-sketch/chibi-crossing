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
	"piange": {  # IL PIANTO. Non un urlo: il singhiozzo di chi si trattiene.
		# Gli occhi restano GRANDI e tondi — «occhi tristi mentre piange» —
		# solo con le palpebre pesanti e le pupille dilatate dal pianto: un
		# occhio stretto a fessura fa una smorfia, e la smorfia fa ridere.
		# Le guance accese non sono allegria: si piange rossi.
		"brow_ang": -0.24, "brow_h": 0.035, "eye_open": 0.62,
		"pupil": 1.3, "mouth": "sad", "mouth_open": 0.2,
		"blush": 0.34, "tilt": -0.15,
	},
}

# gli umori del Chibiese (neutro | felice | domanda | triste) mappati sul
# vocabolario ricco delle espressioni
const MOOD_TO_EXPR := {
	"neutro": "neutro", "felice": "felice",
	"domanda": "curioso", "triste": "triste",
}

## La RECITA delle sopracciglia: ogni espressione ha la sua coreografia nel
## tempo, non solo una posa. Gli stili sono i verbi del mestiere d'animazione:
##   scatto    su di colpo e restano alte, calando piano (sorpresa)
##   tremito   vibrazione fine che si spegne (paura)
##   flick     un sopracciglio su e l'altro giù, e piano si scambiano (dubbio)
##   rimbalzo  saltelli felici che si acquietano (gioia)
##   fremito   l'interno alzato che trema a folate (tristezza)
##   morsa     la stretta che pulsa col fiato (sforzo, concentrazione)
##   sciolto   onda pigra, tutto si ammorbidisce (amore, beatitudine)
##   pesante   cadono piano, con risalite di lotta contro il sonno
##   quiete    quasi ferme (dorme)
## `amp` scala l'ampiezza dello stile per quella espressione.
const BROW_PLAY := {
	"sorpresa": {"stile": "scatto", "amp": 1.0},
	"meraviglia": {"stile": "scatto", "amp": 0.7},
	"spavento": {"stile": "tremito", "amp": 1.0},
	"curioso": {"stile": "flick", "amp": 1.0},
	"gioia": {"stile": "rimbalzo", "amp": 1.0},
	"felice": {"stile": "rimbalzo", "amp": 0.45},
	"raggiante": {"stile": "sciolto", "amp": 0.8},
	"triste": {"stile": "fremito", "amp": 1.0},
	"piange": {"stile": "fremito", "amp": 1.5},
	"concentrato": {"stile": "morsa", "amp": 0.8},
	"sforzo": {"stile": "morsa", "amp": 1.3},
	"imbronciato": {"stile": "morsa", "amp": 1.0},
	"amore": {"stile": "sciolto", "amp": 1.0},
	"beato": {"stile": "sciolto", "amp": 0.7},
	"assonnato": {"stile": "pesante", "amp": 1.0},
	"dorme": {"stile": "quiete", "amp": 1.0},
	"soffio": {"stile": "quiete", "amp": 1.0},
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

# il catchlight VIVO: il disco di luce grande di ogni occhio è un riflesso,
# e scivola verso la fonte vera — il sole di giorno, la luna di notte, una
# lanterna calda a due passi — con la pendenza verso la camera dei riflessi
# veri. È il "quasi niente" che dà l'anima: gli occhi smettono di essere
# adesivi e cominciano a specchiare il mondo.
var _glints: Array[Node3D] = []
var _glint_base: Array[Vector3] = []
var _glint_base_scale: Array[Vector3] = []
var _glint_r := 0.02          # quanto il riflesso può correre sull'occhio
var _glint_cur := Vector2.ZERO
var _glint_tgt := Vector2.ZERO
var _glint_gain := 0.0        # quanta luce arriva (0 = sorgente alle spalle)
var _glint_gain_cur := 0.0
var _luce_cd := 0.0           # la sorgente si rilegge ogni ~0.3 s, sfasata

# stati di riposo memorizzati al setup, per animare in RELATIVO
var _eye_base_scale := Vector3(1, 1.18, 0.55)
var _eye_base_pos: Array[Vector3] = []
var _iris_base_scales: Array[Vector3] = []   # scala di riposo per lato (dilatazione)
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
var _blink_frozen := 0.0 # finestra di congelamento (scatti ravvicinati)

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

# la dinamica della recita: una MOLLA sottosmorzata per sopracciglio (overshoot
# e assestamento veri), un lato che parte prima dell'altro (i volti veri non
# sono mai simmetrici), e l'età dell'espressione per far decadere gli attacchi
var _brow_h_cur: Array[float] = [0.0, 0.0]
var _brow_h_vel: Array[float] = [0.0, 0.0]
var _brow_ang_cur: Array[float] = [0.0, 0.0]
var _brow_ang_vel: Array[float] = [0.0, 0.0]
var _expr_age := 10.0     # da quanto l'espressione corrente è in scena
var _brow_lead := 0       # quale sopracciglio attacca per primo
var _blink_close_cur := 0.0   # chiusura d'ammicco corrente (le sopracciglia si tuffano con lui)

# impulso transitorio (un'espressione che rimbalza e poi rientra)
var _pulse_t := -1.0
var _pulse_dur := 0.0
var _pulse_prev := "neutro"
var _pulse_prev_int := 1.0   # l'intensità di SFONDO da ripristinare al rientro


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
	_face_side = rig.get("face_side", 0.36)
	_glints.assign(rig.get("glints", []))
	_glint_r = float(rig.get("glint_r", 0.02))
	_costruisci_lacrime(Vector3(rig.get("tear_off", Vector3(0, -0.105, -0.05))))
	for g in _glints:
		_glint_base.append(g.position)
		_glint_base_scale.append(g.scale)

	_rng.randomize()
	# ogni volto interroga la luce in un istante suo: mai tutti nello
	# stesso frame (con 28 vicini si sentirebbe)
	_luce_cd = _rng.randf_range(0.0, 0.3)
	for eye in _eyes:
		_eye_base_pos.append(eye.position)
	for iris in _irises:
		_iris_base_scales.append(iris.scale)
	for h in _happy:
		_happy_base_scale.append(h.scale)
	for sq in _squint:
		_squint_base_scale.append(sq.scale)
	for b in _brows:
		_brow_base_pos.append(b.position)
		_brow_base_rot.append(b.rotation)
	# una molla per sopracciglio, quante che siano
	while _brow_h_cur.size() < _brows.size():
		_brow_h_cur.append(0.0)
		_brow_h_vel.append(0.0)
		_brow_ang_cur.append(0.0)
		_brow_ang_vel.append(0.0)
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
## I proprietari la chiamano OGNI frame: se nulla è cambiato esce subito,
## così non si ricalcolano gli obiettivi identici 60 volte al secondo.
func set_expression(name: String, intensity := 1.0, speed := 9.0) -> void:
	if not EXPRESSIONS.has(name):
		name = "neutro"
	if name == _expr and is_equal_approx(intensity, _intensity) \
			and is_equal_approx(speed, _blend):
		return
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
	# l'intensità di sfondo va catturata ORA, prima che set_expression la
	# sovrascriva con quella del lampo (il rientro tornava a intensità piena)
	_pulse_prev_int = _intensity
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
	# rispetta il congelamento: nessun battito mentre siamo "in posa"
	if _blink_t < 0.0 and _blink_frozen <= 0.0:
		_blink_t = 0.0


## Congela l'ammicco per [param sec] secondi (per gli scatti ravvicinati
## del DebugHarness: niente palpebre a metà nella foto). È AUTORITATIVO:
## nemmeno un ammicco accoppiato alla saccade può filtrare.
func freeze_blink(sec: float) -> void:
	_blink_frozen = maxf(_blink_frozen, sec)
	_next_blink = maxf(_next_blink, sec)
	_blink_t = -1.0


## Il suggerimento di inclinazione del capo dell'espressione corrente:
## il proprietario può SOMMARLO alla rotazione della testa, se vuole.
func head_tilt() -> float:
	return _c_tilt


# ------------------------------------------------------------ il motore

# ------------------------------------------------------------- le lacrime
#
# Fanno parte del VOLTO, non della scena che le chiede: così piange chiunque
# abbia una faccia — Mochi nel prologo, un vicino il giorno di un congedo — e
# non c'è una seconda implementazione del pianto da tenere allineata.
#
# Due gocce, una per occhio, ognuna col SUO orologio. I periodi non sono
# multipli l'uno dell'altro: due lacrime che cadono in coppia sono un
# rubinetto, sfasate sono un pianto. Nascono ferme e gonfie sulla palpebra,
# poi scivolano ACCELERANDO lungo la guancia e si staccano.

const LACRIMA_PERIODI := [2.9, 3.7]

var _lacrime: Array[Node3D] = []
var _lacrima_base: Array[Vector3] = []
var _pianto := 0.0


func _costruisci_lacrime(giu: Vector3) -> void:
	if _head == null or _eyes.is_empty():
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.80, 0.92, 1.0, 0.85)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in _eyes.size():
		var nodo := Node3D.new()
		nodo.name = "Lacrima%d" % i
		nodo.position = (_eyes[i] as Node3D).position + giu
		nodo.scale = Vector3.ZERO
		_head.add_child(nodo)
		var m := MeshInstance3D.new()
		var sf := SphereMesh.new()
		sf.radius = 0.022
		sf.height = 0.044
		sf.radial_segments = 12
		sf.rings = 7
		m.mesh = sf
		m.material_override = mat
		# una lacrima non è una biglia: allungata in giù e schiacciata
		# contro la guancia, o sembra una perlina appiccicata
		m.scale = Vector3(0.85, 1.35, 0.55)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nodo.add_child(m)
		_lacrime.append(nodo)
		_lacrima_base.append(nodo.position)


func _apply_lacrime(delta: float) -> void:
	if _lacrime.is_empty():
		return
	# si piange solo quando l'espressione è quella, e il pianto ARRIVA e VA
	# via piano: comparire di colpo è la differenza fra un pianto e uno
	# sticker
	var voglio := _c_pianto()
	_pianto = lerpf(_pianto, voglio, 1.0 - exp(-3.2 * delta))
	for i in _lacrime.size():
		if _pianto < 0.02:
			_lacrime[i].scale = Vector3.ZERO
			continue
		var periodo: float = LACRIMA_PERIODI[i % LACRIMA_PERIODI.size()]
		var fase := fposmod((_t + float(i) * 1.3) / periodo, 1.0)
		var gonfia := smoothstep(0.0, 0.34, fase)
		var scende := smoothstep(0.34, 1.0, fase)
		var corsa := scende * scende      # parte piano e poi corre
		var base: Vector3 = _lacrima_base[i]
		_lacrime[i].position = base + Vector3(0, -corsa * 0.26, corsa * 0.05)
		var viva := gonfia * (1.0 - smoothstep(0.86, 1.0, fase)) * _pianto
		_lacrime[i].scale = Vector3.ONE * maxf(0.0, viva)


## Quanto sta piangendo adesso: 1 quando l'espressione corrente è «piange»,
## scalata dalla sua intensità.
func _c_pianto() -> float:
	if _expr == "piange":
		return clampf(_intensity, 0.0, 1.0)
	return 0.0


func update(delta: float) -> void:
	if _eyes.is_empty() and _brows.is_empty() and _mouths.is_empty():
		return
	_t += delta
	_expr_age += delta
	if _blink_frozen > 0.0:
		_blink_frozen -= delta

	# impulso transitorio: allo scadere, torna all'espressione di sfondo
	if _pulse_t >= 0.0:
		_pulse_t += delta
		if _pulse_t >= _pulse_dur:
			_pulse_t = -1.0
			set_expression(_pulse_prev, _pulse_prev_int, 8.0)

	_blend_channels(delta)
	_apply_brows(delta)
	_apply_eyes(delta)
	_apply_glints(delta)
	_apply_mouth(delta)
	_apply_blush()
	_apply_lacrime(delta)


# --------------------------------------------------- il catchlight vivo

func _apply_glints(delta: float) -> void:
	if _glints.is_empty() or _head == null or not _head.is_inside_tree():
		return
	_luce_cd -= delta
	if _luce_cd <= 0.0:
		_luce_cd = 0.3
		_aggiorna_luce()
	# il riflesso INSEGUE la luce, non ci scatta sopra: la scivolata morbida
	# è ciò che l'occhio umano legge come "lucido", non "appiccicato"
	var k := 1.0 - exp(-6.0 * delta)
	_glint_cur = _glint_cur.lerp(_glint_tgt, k)
	_glint_gain_cur = lerpf(_glint_gain_cur, _glint_gain, k)
	var vivo := 0.88 + 0.28 * _glint_gain_cur
	for i in _glints.size():
		var g := _glints[i]
		if g == null or not is_instance_valid(g):
			continue
		# lo stesso spostamento su entrambi gli occhi (è così che fanno i
		# riflessi veri), e il disco si accende un filo quando la luce è piena
		g.position = _glint_base[i] + Vector3(_glint_cur.x, _glint_cur.y, 0.0)
		g.scale = _glint_base_scale[i] * Vector3(vivo, vivo, 1.0)


# Da dove arriva la luce, ADESSO: una lanterna calda a due passi vince su
# tutto (gruppo "luce_calda": le lanterne del congedo, la finestra accesa
# del lutto); altrimenti il cielo (sole o luna, li dà il DayNight). Il
# risultato pende verso la camera, come ogni riflesso su una superficie
# curva. Costa una query ogni 0.3 s, sfasata per volto.
func _aggiorna_luce() -> void:
	var tree := _head.get_tree()
	if tree == null:
		return
	var pos := _head.global_position
	var dir := Vector3(0.35, 0.85, -0.4).normalized()   # ripiego: un cielo qualunque
	var calda: Node3D = null
	var calda_d := 5.5
	for n in tree.get_nodes_in_group("luce_calda"):
		if n is Node3D and is_instance_valid(n):
			var d: float = pos.distance_to((n as Node3D).global_position)
			if d < calda_d:
				calda_d = d
				calda = n
	if calda != null:
		dir = (calda.global_position - pos).normalized()
	else:
		var dn := tree.get_first_node_in_group("daynight")
		if dn and dn.has_method("luce_verso"):
			dir = dn.call("luce_verso")
	var cam := _head.get_viewport().get_camera_3d() if _head.get_viewport() else null
	if cam:
		dir = (dir * 0.62 + (cam.global_position - pos).normalized() * 0.38).normalized()
	# nel riferimento della testa (il viso guarda -Z): se la sorgente è alle
	# spalle il riflesso non esiste — il disco torna a casa, al suo posto
	var l: Vector3 = _head.global_transform.basis.orthonormalized().inverse() * dir
	_glint_gain = clampf(-l.z, 0.0, 1.0)
	var xy := Vector2(l.x, l.y)
	if xy.length() > 1.0:
		xy = xy.normalized()
	_glint_tgt = xy * _glint_r * _glint_gain


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
	# una nuova scena per le sopracciglia: l'attacco riparte, e il lato che
	# si muove per primo viene ritirato a sorte (mai la stessa faccia due volte)
	_expr_age = 0.0
	_brow_lead = _rng.randi_range(0, 1)
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
		# nascondi lo scambio di forma dietro un ammicco: molto più pulito
		# che vedere l'occhio-palla sparire e l'arco comparire a occhi aperti
		blink_now()
	# forma bocca (crossfade)
	var m := str(e.get("mouth", "neutral"))
	if not _mouths.has(m):
		m = "neutral" if _mouths.has("neutral") else _mouth
	if m != _mouth:
		_mouth_prev = _mouth
		_mouth = m
		_mouth_mix = 0.0


## LE SOPRACCIGLIA SI RIFANNO (il salone cambia lo stile a Mochi): il
## volto ne riprende il possesso e rimisura le pose di riposo. Senza,
## la recita continuerebbe a muovere due nodi liberati.
func aggiorna_sopracciglia(nuove: Array) -> void:
	_brows.assign(nuove)
	_brow_base_pos.clear()
	_brow_base_rot.clear()
	for b in _brows:
		_brow_base_pos.append(b.position)
		_brow_base_rot.append(b.rotation)
	while _brow_h_cur.size() < _brows.size():
		_brow_h_cur.append(0.0)
		_brow_h_vel.append(0.0)
		_brow_ang_cur.append(0.0)
		_brow_ang_vel.append(0.0)


func _has_shape(shape: String) -> bool:
	match shape:
		"happy": return not _happy.is_empty()
		"squint": return not _squint.is_empty()
		_: return true


# ------------------------------------------------------------ sopracciglia
# Tre strati, come si anima un volto vero:
#   1. la MOLLA per lato verso il bersaglio dell'espressione — sottosmorzata,
#      quindi supera il segno e si assesta (l'overshoot è ciò che l'occhio
#      legge come "muscolo", non "interruttore"); il lato in ritardo parte
#      più morbido per il primo terzo di secondo
#   2. la COREOGRAFIA dell'espressione (BROW_PLAY): il tremito, il flick,
#      la morsa che pulsa col fiato...
#   3. la VITA di fondo: respiro lento, guizzo dei saluti, e il tuffo
#      insieme all'ammicco (le sopracciglia veri seguono la palpebra)
func _apply_brows(delta: float) -> void:
	if _brows.is_empty():
		return
	var gioco: Dictionary = BROW_PLAY.get(_expr, {})
	var stile := str(gioco.get("stile", ""))
	var amp := float(gioco.get("amp", 1.0)) * clampf(_intensity, 0.0, 1.2)
	var idle := sin(_t * 0.9) * 0.004
	var flash := _brow_flash * 0.05
	var tuffo := _blink_close_cur * 0.006
	var dt := minf(delta, 0.05)

	for i in _brows.size():
		var b := _brows[i]
		var side := -1.0 if i == 0 else 1.0
		var base_p: Vector3 = _brow_base_pos[i]
		var base_r: Vector3 = _brow_base_rot[i]

		# 1 · la molla (semi-implicita: stabile anche a 20 fps)
		var ritardo := i != _brow_lead and _expr_age < 0.3
		var k_h := 90.0 if ritardo else 170.0
		var c_h := 8.0 if ritardo else 10.0
		_brow_h_vel[i] += (k_h * (_t_brow_h - _brow_h_cur[i]) - c_h * _brow_h_vel[i]) * dt
		_brow_h_cur[i] += _brow_h_vel[i] * dt
		_brow_ang_vel[i] += (150.0 * (_t_brow_ang - _brow_ang_cur[i]) \
				- 14.0 * _brow_ang_vel[i]) * dt
		_brow_ang_cur[i] += _brow_ang_vel[i] * dt

		# 2 · la coreografia (offset nel tempo, per lato)
		var fase := float(i) * 0.9
		var h_rec := 0.0
		var ang_rec := 0.0
		var sq_rec := 0.0
		match stile:
			"scatto":
				# restano alte sull'attimo, poi calano piano (l'overshoot
				# vero lo ha già fatto la molla)
				h_rec = amp * 0.012 * exp(-_expr_age * 0.8)
			"tremito":
				var spegni := exp(-_expr_age * 2.0)
				h_rec = amp * 0.009 * sin(_t * 26.0 + fase * 4.0) * spegni
				ang_rec = amp * 0.022 * sin(_t * 31.0 + fase * 3.0) * spegni
			"flick":
				# il sopracciglio del dubbio: uno su, l'altro giù, e si
				# scambiano con calma — la domanda che si ripensa
				var chi := 1.0 if i == _brow_lead else -1.0
				var alt := sin(_t * 1.7)
				h_rec = amp * 0.013 * alt * chi
				ang_rec = amp * -0.045 * alt * chi
			"rimbalzo":
				h_rec = amp * (0.010 * absf(sin(_t * 6.4 + fase)) * exp(-_expr_age * 1.1) \
						+ 0.003 * sin(_t * 2.6 + fase))
			"fremito":
				# folate: quasi fermo, poi l'interno freme — il pianto trattenuto
				var folata := maxf(0.0, sin(_t * 0.9 + fase) - 0.82) / 0.18
				ang_rec = amp * -0.028 * folata * sin(_t * 9.0)
				h_rec = amp * 0.004 * sin(_t * 1.2 + fase * 2.0)
			"morsa":
				var fiato := 0.5 + 0.5 * sin(_t * 2.6 + fase * 0.4)
				sq_rec = amp * 0.010 * fiato
				h_rec = amp * -0.004 * fiato
			"sciolto":
				h_rec = amp * 0.006 * sin(_t * 1.1 + fase)
				ang_rec = amp * -0.01 * (0.5 + 0.5 * sin(_t * 0.8 + fase))
			"pesante":
				var lotta := maxf(0.0, sin(_t * 0.42 + fase * 0.3) - 0.86) / 0.14
				h_rec = amp * (-0.006 + 0.018 * lotta)
			"quiete":
				h_rec = amp * 0.002 * sin(_t * 0.7 + fase)
			_:
				pass

		# 3 · tutto insieme: alzata (+y), corrugamento (x), angolo interno (z)
		b.position.y = base_p.y + _brow_h_cur[i] + h_rec + idle + flash - tuffo
		b.position.x = base_p.x - side * (_c_brow_sq + sq_rec)
		# l'angolo interno: arrabbiato abbassa l'interno, triste lo alza.
		# lo z locale ruota il sopracciglio; il segno dipende dal lato.
		b.rotation.z = base_r.z + side * (_brow_ang_cur[i] + ang_rec)


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
	_blink_close_cur = blink_close   # le sopracciglia si tuffano col battito
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

		# iride/luci: dilatazione + inseguimento dello sguardo dentro
		# l'occhio. E la PALPEBRA: le luci vivono SULLA superficie — quando
		# l'occhio si socchiude si schiacciano con lei (la Y segue
		# l'apertura, come l'ellissoide scuro) e si stringono un filo;
		# sotto la soglia del quasi-chiuso si spengono del tutto, perché un
		# riflesso su un occhio chiuso non esiste. Vale per beato, soffio,
		# assonnato — e per i fotogrammi centrali di ogni ammicco.
		if i < _irises.size() and _irises[i] != null:
			var iris := _irises[i]
			var luce_viva := smoothstep(0.12, 0.55, aperture)
			iris.visible = iris.visible and aperture > 0.12
			iris.scale = Vector3(
					_iris_base_scales[i].x * _c_pupil * (0.6 + 0.4 * luce_viva),
					_iris_base_scales[i].y * _c_pupil * minf(aperture, 1.15),
					_iris_base_scales[i].z * _c_pupil)
			iris.position.x = _gaze_cur.x * 0.02
			# lo sguardo verticale si comprime con la palpebra: le luci non
			# sbucano mai fuori dalla fessura
			iris.position.y = _gaze_cur.y * 0.016 * minf(aperture, 1.0)

	# vita degli occhi "chiusi" (^^ o >.<): l'occhio-palla è nascosto, quindi
	# l'ammicco non si vedrebbe — così faccio BATTERE e respirare l'arco, che
	# altrimenti resterebbe un adesivo immobile proprio nei momenti più teneri
	if _shape_mix >= 1.0 and _eye_shape != "open":
		var arcs := _happy if _eye_shape == "happy" else _squint
		var bases := _happy_base_scale if _eye_shape == "happy" else _squint_base_scale
		var life := (1.0 - blink_close * 0.5) * (1.0 + sin(_t * 2.0) * 0.03)
		for j in arcs.size():
			if j < bases.size() and arcs[j] and arcs[j].visible:
				arcs[j].scale.y = bases[j].y * life


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
	# nessun ammicco se congelato (scatti), disattivato, o se l'espressione
	# tiene già gli occhi quasi chiusi (dorme, raggiante): sarebbe un doppione
	var eyes_shut := _t_eye_open < 0.18
	if _blink_frozen > 0.0 or not _blink_enabled or eyes_shut:
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
# le forme che portano già con sé cavo scuro e linguetta (bocche intere)
const BOCCHE_INTERE := ["grin", "o", "O"]


func _apply_mouth(delta: float) -> void:
	if _mouths.is_empty():
		return
	# crossfade tra forme: la vecchia si RITRAE fin quasi a un puntino, poi
	# si scambia con la nuova che ricresce — così il cambio di geometria si
	# nasconde in uno "squash" invece di fare "pop" a mezza scala
	if _mouth_mix < 1.0:
		_mouth_mix = minf(1.0, _mouth_mix + delta * 10.0)
	var on_new := _mouth_mix >= 0.5
	var show: String = _mouth if on_new else _mouth_prev
	var pop := 0.18 + 0.82 * absf(_mouth_mix - 0.5) * 2.0
	for mn in _mouths:
		var node: Node3D = _mouths[mn]
		var vis: bool = mn == show
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
	# le bocche INTERE (grin, o, O) hanno già cavo e linguetta incorporati:
	# la cavità esterna resta spenta (sovrapposta sembrava una seconda bocca)
	# e a respirare con l'apertura è il loro nodo "apertura"
	var intera := show in BOCCHE_INTERE
	if _mouth_open_node != null:
		_mouth_open_node.visible = (not intera) and open > 0.02
		var s := 0.2 + open
		_mouth_open_node.scale = Vector3(s, open * 1.1 + 0.1, 1.0)
	if intera:
		var ap := (_mouths[show] as Node3D).get_node_or_null("apertura")
		if ap != null:
			ap.scale = Vector3(0.82 + 0.3 * open, 0.72 + 0.45 * open, 1.0)


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

## Gli stili di sopracciglio — la fonte unica di verità delle varianti che
## il DNA può pescare: ChibiDNA tira a sorte il NOME, ChibiBuilder e Mochi
## costruiscono la forma da qui. Ogni stile è una ricetta:
##   arco   quanto s'inarca il corpo (frazione della lunghezza)
##   picco  dove sta il colmo dell'arco (0..1 dalla radice alla coda)
##   coda   quanto la coda ricade a fine corsa (frazione della lunghezza)
##   spess  moltiplicatore dello spessore di base
##   punta  spessore residuo in punta (0.08 = affilata, 0.34 = mozza)
##   testa  pienezza della radice interna (frazione dello spessore pieno)
## Valori DOLCI, mai ripidi: colmi alti e code a picco facevano
## sopracciglia "a gabbiano" dall'aria arrabbiata su musetti teneri.
const BROW_STYLES := {
	"morbide": {"arco": 0.17, "picco": 0.60, "coda": 0.05,
			"spess": 1.00, "punta": 0.22, "testa": 0.72},
	"arcuate": {"arco": 0.30, "picco": 0.55, "coda": 0.10,
			"spess": 0.85, "punta": 0.16, "testa": 0.66},
	"dritte": {"arco": 0.07, "picco": 0.50, "coda": 0.01,
			"spess": 1.00, "punta": 0.26, "testa": 0.80},
	"decise": {"arco": 0.22, "picco": 0.66, "coda": 0.13,
			"spess": 1.18, "punta": 0.18, "testa": 0.62},
	"folte": {"arco": 0.13, "picco": 0.55, "coda": 0.04,
			"spess": 1.45, "punta": 0.34, "testa": 0.85},
	"sottili": {"arco": 0.22, "picco": 0.60, "coda": 0.07,
			"spess": 0.66, "punta": 0.12, "testa": 0.60},
}


## Un sopracciglio VERO: non più una fila di palline ma una ciglia unica —
## un fuso a sezione ellittica spazzato lungo la curva radice→colmo→coda,
## pieno e tondo alla radice, affilato in punta. Appeso a un pivot alla
## radice interna (così il FaceController lo alza/inclina/corruga ruotando
## bene). [param style] è un nome di BROW_STYLES; [param vari] sovrascrive
## singole voci della ricetta (le micro-variazioni del DNA).
## Ritorna il pivot. [param side] -1 = sinistro, +1 = destro.
static func build_brow(parent: Node3D, mat: Material, side: float,
		pos: Vector3, length := 0.12, thick := 0.016,
		style := "morbide", vari := {}) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	# un filo di inclinazione a riposo, verso l'esterno: sguardo dolce
	# (poca: sommata alla coda dello stile diventava un'aria severa)
	pivot.rotation.z = side * 0.04
	parent.add_child(pivot)

	var ricetta: Dictionary = BROW_STYLES.get(style, BROW_STYLES["morbide"]).duplicate()
	for k in vari:
		ricetta[k] = vari[k]

	var mi := MeshInstance3D.new()
	mi.mesh = _brow_mesh(side, length, thick, ricetta)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(mi)
	return pivot


## La mesh del sopracciglio: la stessa spazzata a frame paralleli dei tubi
## di ChibiBuilder (winding e tappi identici), ma a sezione ellittica —
## schiacciata verso il viso — e con lo spessore che segue la ricetta.
static func _brow_mesh(side: float, length: float, thick: float,
		ricetta: Dictionary) -> ArrayMesh:
	var arco := float(ricetta.get("arco", 0.3))
	var picco := clampf(float(ricetta.get("picco", 0.6)), 0.2, 0.85)
	var coda := float(ricetta.get("coda", 0.1))
	var spess := float(ricetta.get("spess", 1.0))
	var punta := clampf(float(ricetta.get("punta", 0.16)), 0.02, 0.9)
	var testa := float(ricetta.get("testa", 0.72))

	# l'esponente che porta il colmo di sin(PI·f^p) esattamente su "picco"
	var p := log(0.5) / log(picco)
	var rings := 14
	var sides_n := 10
	var centers: Array[Vector3] = []
	var rads: Array[float] = []
	for i in rings + 1:
		var f := float(i) / float(rings)
		# il corpo sale fino al colmo, poi la coda ricade; la lieve bombatura
		# in avanti al centro fa abbracciare la fronte al fuso
		var y := (arco * sin(PI * pow(f, p)) - coda * f) * length
		var z := -0.25 * thick * sin(PI * f)
		centers.append(Vector3(side * f * length, y, z))
		# radice piena e tonda, corpo pieno, coda che si affila in punta
		var base := lerpf(testa, 1.0, smoothstep(0.0, 0.3, f))
		var fine := lerpf(1.0, punta, smoothstep(0.3, 1.0, f))
		rads.append(thick * spess * base * fine)

	return _sweep_mesh(centers, rads, 0.62)


## La spazzata generica dei fusi facciali (sopracciglia, labbra): un tubo
## a sezione ellittica — [param squash] schiaccia la profondità contro il
## viso — spazzato lungo [param centers] col raggio per campione in
## [param rads]. Frame trasportati in parallelo e winding identici ai tubi
## di ChibiBuilder, tappi alle estremità, normali morbide.
static func _sweep_mesh(centers: Array[Vector3], rads: Array[float],
		squash: float) -> ArrayMesh:
	var sides_n := 10
	var count := centers.size()
	var tans: Array[Vector3] = []
	for i in count:
		tans.append((centers[mini(i + 1, count - 1)] \
				- centers[maxi(i - 1, 0)]).normalized())
	var nrm := Vector3.RIGHT
	if absf(tans[0].dot(nrm)) > 0.9:
		nrm = Vector3.UP
	nrm = (nrm - tans[0] * nrm.dot(tans[0])).normalized()

	var verts := []
	var norms := []
	for i in count:
		if i > 0:
			var axis := tans[i - 1].cross(tans[i])
			var l := axis.length()
			if l > 0.0001:
				nrm = nrm.rotated(axis / l, tans[i - 1].angle_to(tans[i]))
		var bin := tans[i].cross(nrm).normalized()
		var prev_i := maxi(i - 1, 0)
		var next_i := mini(i + 1, count - 1)
		var ds := centers[next_i].distance_to(centers[prev_i])
		var slope := 0.0 if ds < 0.0001 else (rads[next_i] - rads[prev_i]) / ds
		var ring_v: Array[Vector3] = []
		var ring_n: Array[Vector3] = []
		for j in sides_n:
			var a := float(j) / float(sides_n) * TAU
			ring_v.append(centers[i] + nrm * (cos(a) * rads[i]) \
					+ bin * (sin(a) * rads[i] * squash))
			# normale dell'ellisse (il gradiente), piegata dalla rastremazione
			var dirn := (nrm * cos(a) + bin * (sin(a) / squash)).normalized()
			ring_n.append((dirn - tans[i] * slope).normalized())
		verts.append(ring_v)
		norms.append(ring_n)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count - 1:
		for j in sides_n:
			var j2 := (j + 1) % sides_n
			st.set_normal(norms[i][j])
			st.add_vertex(verts[i][j])
			st.set_normal(norms[i + 1][j])
			st.add_vertex(verts[i + 1][j])
			st.set_normal(norms[i + 1][j2])
			st.add_vertex(verts[i + 1][j2])
			st.set_normal(norms[i][j])
			st.add_vertex(verts[i][j])
			st.set_normal(norms[i + 1][j2])
			st.add_vertex(verts[i + 1][j2])
			st.set_normal(norms[i][j2])
			st.add_vertex(verts[i][j2])
	# tappi
	for j in sides_n:
		var j2 := (j + 1) % sides_n
		st.set_normal(-tans[0])
		st.add_vertex(centers[0])
		st.set_normal(-tans[0])
		st.add_vertex(verts[0][j])
		st.set_normal(-tans[0])
		st.add_vertex(verts[0][j2])
		st.set_normal(tans[count - 1])
		st.add_vertex(centers[count - 1])
		st.set_normal(tans[count - 1])
		st.add_vertex(verts[count - 1][j2])
		st.set_normal(tans[count - 1])
		st.add_vertex(verts[count - 1][j])
	return st.commit()


## Gli stili di bocca — la fonte unica delle varianti che il DNA può
## pescare (come BROW_STYLES per le sopracciglia). Ogni stile scala le
## STESSE forme espressive, non ne cambia il repertorio:
##   larg   larghezza della bocca
##   curva  ampiezza delle curve (sorrisi più profondi o più accennati)
##   spess  spessore del labbro-fuso
const MOUTH_STYLES := {
	"morbida": {"larg": 1.00, "curva": 1.00, "spess": 1.00},
	"minuta": {"larg": 0.80, "curva": 0.85, "spess": 0.90},
	"larga": {"larg": 1.22, "curva": 1.15, "spess": 1.00},
	"piena": {"larg": 1.00, "curva": 0.95, "spess": 1.40},
}


## Il set completo di bocche morbide, tutte figlie di un nodo al centro
## bocca (così si scalano/nascondono insieme). Ritorna {nome -> Node3D}.
## Le forme: neutral (la "w" da gattino), smile, grin (sorriso aperto),
## o / O (stupori), frown, sad, line (bocca seria). [param mz] è la Z locale
## su cui appoggiarle sul musetto. Niente più palline: ogni bocca è un
## labbro-fuso continuo, pieno al centro e affilato agli angoli.
## [param style] è un nome di MOUTH_STYLES; [param vari] sovrascrive
## singole voci della ricetta (le micro-variazioni del DNA).
static func build_mouth_set(parent: Node3D, mat: Material, center: Vector3,
		scale := 1.0, style := "morbida", vari := {}) -> Dictionary:
	var ricetta: Dictionary = MOUTH_STYLES.get(style, MOUTH_STYLES["morbida"]).duplicate()
	for k in vari:
		ricetta[k] = vari[k]
	var larg := float(ricetta.get("larg", 1.0))
	var curva := float(ricetta.get("curva", 1.0))
	var spess := float(ricetta.get("spess", 1.0))

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

	# un labbro: un fuso continuo spazzato lungo i campioni, pieno al
	# centro e affilato agli angoli ([param agli] = spessore residuo agli
	# estremi, in frazione dello spessore pieno)
	var lip := func(host: Node3D, pts: Array, r: float, agli := 0.35) -> void:
		var centers: Array[Vector3] = []
		var rads: Array[float] = []
		var n := pts.size()
		for i in n:
			var f := float(i) / float(n - 1)
			centers.append((pts[i] as Vector3) * scale)
			rads.append(r * spess * scale * lerpf(agli, 1.0, sin(PI * f)))
		var mi := MeshInstance3D.new()
		mi.mesh = _sweep_mesh(centers, rads, 0.6)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(mi)

	# neutral: la "w" da micio — due archetti-fuso che si toccano nel
	# mezzo. Due spazzate, non una: al cuspide i tangenti si ribaltano e
	# una spazzata unica vi si attorciglierebbe; così invece resta netto.
	var wnode: Node3D = mk.call("neutral")
	for s: float in [-1.0, 1.0]:
		var arc := []
		for i in 11:
			var f := float(i) / 10.0
			var a := PI + f * PI
			arc.append(Vector3((s * 0.024 + cos(a) * 0.024) * larg,
					sin(a) * 0.024 * curva, mz))
		lip.call(wnode, arc, 0.0085, 0.55)

	# smile: un arco dolce all'INSÙ (una ∪): gli angoli si alzano, il centro
	# scende — quindi y = base - sin(a)*amp (con +sin avremmo un broncio!)
	var sm_node: Node3D = mk.call("smile")
	var sm_pts := []
	for i in 15:
		var f := float(i) / 14.0
		var a := PI * (1.0 - f)                # da PI a 0
		sm_pts.append(Vector3(cos(a) * 0.05 * larg,
				0.012 - sin(a) * 0.036 * curva, mz))
	lip.call(sm_node, sm_pts, 0.009)

	# grin: il sorriso APERTO della gioia — una bocca INTERA, non due grafiche:
	# labbro superiore quasi dritto, labbro inferiore a ∪ profonda, il cavo
	# scuro che li riempie, il dentino sotto il labbro e la linguetta sul
	# fondo. (Prima il grin era un arco chiuso e la cavità esterna di
	# mouth_open gli fluttuava sopra: da vicino sembravano due bocche.)
	var gr_node: Node3D = mk.call("grin")
	var gr_giu := []
	var gr_su := []
	for i in 15:
		var f := float(i) / 14.0
		var a := PI * (1.0 - f)
		gr_giu.append(Vector3(cos(a) * 0.058 * larg,
				0.008 - sin(a) * 0.034 * curva, mz))
		gr_su.append(Vector3(cos(a) * 0.058 * larg,
				0.008 + sin(a) * 0.005 * curva, mz))
	_apertura_bocca(gr_node, Vector3(0, -0.005, mz + 0.004) * scale,
			0.030 * scale, Vector3(1.75 * larg, 0.62 * curva, 0.4),
			0.015 * scale, Vector3(0, -0.019 * curva, -0.012) * scale)
	# il dentino: il tocco chibi sotto il labbro superiore (fisso, non
	# respira con l'apertura — i denti non si gonfiano)
	var dent := MeshInstance3D.new()
	dent.name = "dentino"
	var dent_m := SphereMesh.new()
	dent_m.radius = 0.0095 * scale
	dent_m.height = 0.019 * scale
	dent_m.radial_segments = 12
	dent_m.rings = 6
	dent.mesh = dent_m
	var dent_mat := StandardMaterial3D.new()
	dent_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dent_mat.albedo_color = Color("fff6ee")
	dent.material_override = dent_mat
	dent.position = Vector3(0.017 * larg, 0.004, mz + 0.002) * scale
	dent.scale = Vector3(1.25, 0.62, 0.45)
	dent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gr_node.add_child(dent)
	# le labbra stanno un soffio più AVANTI (z minore) di cavo e dentino:
	# è la profondità a tenerle davanti, il contorno resta netto
	lip.call(gr_node, gr_giu, 0.0092)
	lip.call(gr_node, gr_su, 0.0072, 0.5)

	# frown: arco all'ingiù (concavo in basso)
	var fr_node: Node3D = mk.call("frown")
	var fr_pts := []
	for i in 13:
		var f := float(i) / 12.0
		var a := PI * f                        # da 0 a PI
		fr_pts.append(Vector3(cos(a) * 0.05 * -1.0 * larg,
				-0.03 + sin(a) * 0.03 * curva, mz))
	lip.call(fr_node, fr_pts, 0.009)

	# sad: come frown ma più stretto e cadente ai lati
	var sad_node: Node3D = mk.call("sad")
	var sad_pts := []
	for i in 13:
		var f := float(i) / 12.0
		var a := PI * f
		sad_pts.append(Vector3(cos(a) * -0.04 * larg,
				-0.028 + sin(a) * 0.026 * curva, mz))
	lip.call(sad_node, sad_pts, 0.0088)

	# line: una bocca seria, quasi dritta
	var ln_node: Node3D = mk.call("line")
	var ln_pts := []
	for i in 9:
		var f := float(i) / 8.0
		ln_pts.append(Vector3((f - 0.5) * 0.075 * larg, 0.0, mz))
	lip.call(ln_node, ln_pts, 0.008, 0.5)

	# o e O: gli anellini di stupore — bocche INTERE: dentro l'anello vive
	# già il cavo scuro con la linguetta adagiata sul fondo. Prima il cavo
	# era il nodo esterno di mouth_open e si sovrapponeva all'anello: da
	# vicino sembravano due bocche (curioso, soffio).
	for tri: Array in [["o", 0.013, 0.026, 0.009], ["O", 0.02, 0.04, 0.014]]:
		var node: Node3D = mk.call(str(tri[0]))
		var r_buco := float(tri[1])
		var tm := TorusMesh.new()
		tm.inner_radius = r_buco * scale
		tm.outer_radius = float(tri[2]) * scale
		tm.rings = 24
		tm.ring_segments = 16
		var o := MeshInstance3D.new()
		o.mesh = tm
		o.material_override = mat
		o.position = Vector3(0, -0.004, mz) * scale
		o.rotation.x = PI * 0.5
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(o)
		# il cavo riempie il buco dell'anello (fino a metà labbro), la
		# linguetta spunta dal bordo basso interno
		_apertura_bocca(node, Vector3(0, -0.004, mz + 0.004) * scale,
				(r_buco + float(tri[2])) * 0.5 * scale, Vector3(1.0, 1.0, 0.4),
				float(tri[3]) * scale,
				Vector3(0, -r_buco * 0.6, -r_buco * 0.45) * scale)

	out["neutral"].visible = true
	return out


# Il cuore scuro di una bocca aperta: il cavo (sfera schiacciata contro il
# viso) e la linguetta rosa sul fondo, raccolti in un nodo chiamato
# "apertura" che _apply_mouth fa respirare con mouth_open/il parlato.
static func _apertura_bocca(host: Node3D, pos: Vector3, r_cavo: float,
		forma: Vector3, r_lingua: float, pos_lingua: Vector3) -> Node3D:
	var ap := Node3D.new()
	ap.name = "apertura"
	ap.position = pos
	host.add_child(ap)
	var cavo_m := SphereMesh.new()
	cavo_m.radius = r_cavo
	cavo_m.height = r_cavo * 2.0
	cavo_m.radial_segments = 20
	cavo_m.rings = 12
	var cavo := MeshInstance3D.new()
	cavo.mesh = cavo_m
	var cavo_mat := StandardMaterial3D.new()
	cavo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cavo_mat.albedo_color = Color("3a1f1f")
	cavo.material_override = cavo_mat
	cavo.scale = forma
	cavo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ap.add_child(cavo)
	var lin_m := SphereMesh.new()
	lin_m.radius = r_lingua
	lin_m.height = r_lingua * 2.0
	lin_m.radial_segments = 14
	lin_m.rings = 8
	var lingua := MeshInstance3D.new()
	lingua.mesh = lin_m
	var lingua_mat := StandardMaterial3D.new()
	lingua_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lingua_mat.albedo_color = Color("e07a8c")
	lingua.material_override = lingua_mat
	lingua.position = pos_lingua
	lingua.scale = Vector3(1.2, 0.55, 0.75)
	lingua.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ap.add_child(lingua)
	return ap


## La bocca aperta (parlare/ridere/stupore): non più la sola palla scura —
## la cavità morbida E la linguetta rosa adagiata sul fondo, che si scopre
## quando la bocca si spalanca. Il controller scala il NODO con mouth_open,
## quindi cavità e linguetta si aprono insieme. Ritorna il nodo.
static func build_mouth_open(parent: Node3D, mat: Material, center: Vector3,
		scale := 1.0) -> Node3D:
	var node := Node3D.new()
	node.position = center + Vector3(0, -0.006, 0.004) * scale
	node.visible = false
	parent.add_child(node)

	var sm := SphereMesh.new()
	sm.radius = 0.03 * scale
	sm.height = 0.06 * scale
	sm.radial_segments = 20
	sm.rings = 12
	var cav := MeshInstance3D.new()
	cav.mesh = sm
	cav.material_override = mat
	cav.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(cav)

	var tm := SphereMesh.new()
	tm.radius = 0.017 * scale
	tm.height = 0.034 * scale
	tm.radial_segments = 14
	tm.rings = 8
	var tongue_mat := StandardMaterial3D.new()
	tongue_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tongue_mat.albedo_color = Color("e07a8c")
	var tongue := MeshInstance3D.new()
	tongue.mesh = tm
	tongue.material_override = tongue_mat
	# spinta in avanti quanto basta a spuntare dalla superficie della
	# cavità (raggio 0.03): sepolta anche di poco, sparirebbe del tutto
	tongue.position = Vector3(0, -0.013, -0.019) * scale
	tongue.scale = Vector3(1.15, 0.5, 0.8)
	tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(tongue)
	return node


## Gli occhi ad arco "^^" della felicità piena: un archetto all'insù per lato,
## nascosto a riposo. [param side] -1/-+1, [param center] posizione locale.
## Una PENNELLATA: un tubo liscio e rastremato lungo una linea di punti
## (coordinate locali di [param parent]). Un solo mesh, punte affilate come un
## tratto d'inchiostro: niente più perline staccate che si vedono da vicino.
static func build_stroke(parent: Node3D, mat: Material, punti: Array,
		r_mid: float) -> MeshInstance3D:
	var n := punti.size()
	var lati := 8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# cornice trasportata lungo la linea (niente torsioni fra un anello e l'altro)
	var t := ((punti[1] as Vector3) - (punti[0] as Vector3)).normalized()
	var su_ := Vector3.FORWARD if absf(t.dot(Vector3.FORWARD)) < 0.9 else Vector3.UP
	var bx := su_.cross(t).normalized()
	var anelli: Array = []   # per punto: [centro, base_x, base_y, raggio]
	for i in n:
		var seg := (punti[mini(i + 1, n - 1)] as Vector3) \
				- (punti[maxi(i - 1, 0)] as Vector3)
		if seg.length() > 0.0001:
			t = seg.normalized()
		bx = (bx - t * bx.dot(t)).normalized()
		var by := t.cross(bx).normalized()
		var f := float(i) / float(n - 1)
		# rastrematura calligrafica: piena al centro, punte sottili
		var r := r_mid * (0.2 + 0.8 * pow(sin(PI * f), 0.6))
		anelli.append([punti[i], bx, by, r])
	var vert := func(i: int, j: int) -> void:
		var an: Array = anelli[i]
		var ang := TAU * float(j % lati) / float(lati)
		var nrm: Vector3 = (an[1] as Vector3) * cos(ang) + (an[2] as Vector3) * sin(ang)
		st.set_normal(nrm)
		st.add_vertex((an[0] as Vector3) + nrm * float(an[3]))
	for i in n - 1:
		for j in lati:
			vert.call(i, j); vert.call(i + 1, j); vert.call(i + 1, j + 1)
			vert.call(i, j); vert.call(i + 1, j + 1); vert.call(i, j + 1)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## L'arco "^^" della felicità piena: una pennellata continua. Se [param su]
## è valida (punto della testa -> punto sulla superficie), l'arco viene
## APPOGGIATO sulla testa vera: senza, resta sul piano di ripiego storico —
## che da vicino e di profilo mostrava le estremità galleggiare.
static func build_happy_arc(parent: Node3D, mat: Material, center: Vector3,
		side: float, r := 0.085, su := Callable()) -> Node3D:
	var node := Node3D.new()
	node.position = (su.call(center) as Vector3) if su.is_valid() else center
	node.visible = false
	parent.add_child(node)
	var n := 17
	var punti: Array = []
	for i in n:
		var f := float(i) / float(n - 1)
		var a := PI * (1.0 - f)                # arco all'insù
		if su.is_valid():
			var q := center + Vector3(cos(a) * r, sin(a) * r * 0.5, 0.0)
			punti.append((su.call(q) as Vector3) - node.position)
		else:
			punti.append(Vector3(cos(a) * r, sin(a) * r * 0.5, -r * 0.5))
	build_stroke(node, mat, punti, maxf(0.012, r * 0.15))
	return node
