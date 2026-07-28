extends Node3D

## LA BARCHETTA DI MOCHI — il verbo "navigare".
##
## Il fiume aveva corrente, pesci e ponti, ma non si toccava. Dal MOLO
## (assi di legno sull'acqua, a valle del ponte) parte una barchetta a
## remi: si rema CONTROCORRENTE verso monte, si passa sotto il ponte ad
## arco, si pesca dal fiume le specie SUE (la trota del salto presso la
## cascata, l'anguilla della notte col buio) — e appena smetti di remare
## la corrente ti riporta a valle, piano, come è giusto.
##
## La fisica è volutamente da barca a remi (mai da motoscafo): forze e
## attrito con velocità terminali PURE (passo_navigazione, testata) —
## la corrente da sola fa ~0.7 m/s a valle, coi remi si risale a ~1.5.
## Le sponde sono i binari: la barca ci rimbalza gentile, mai incastrata.
## Mentre navighi il PlayerController è in pausa e Mochi siede a bordo
## (la camera, figlia sua, viene in barca da sola); i remi leggono gli
## STESSI input del passo (WASD/frecce): nessun tasto nuovo da imparare.

const MATH := preload("res://scenes/world/WorldMath.gd")
const CATALOG := preload("res://scenes/build/BuildCatalog.gd")

## La quota dell'acqua del fiume (la stessa di CozyWorld.RIVER_WATER_Y).
const ACQUA_Y := -0.45
## Dove sta il molo, lungo il corso (a valle del ponte, che è a z=3.2).
const MOLO_Z := 12.0
## Il tratto navigabile (il fiume esiste da -56 a 56: un margine gentile).
const Z_MIN := -50.0
const Z_MAX := 50.0
## Mezzo alveo navigabile (l'acqua è larga 2.35 per lato).
const SPONDA := 1.5

## Le forze della barca. Con l'attrito esponenziale la velocità terminale
## è forza/ATTRITO: corrente sola ~0.7 a valle, remi ~2.2, e remando
## controcorrente si risale a (REMATA-CORRENTE)/ATTRITO ~ 1.5.
const CORRENTE := 0.6          # la spinta del fiume, sempre verso valle (+z)
const REMATA := 1.9            # i remi, in avanti
const RETRO := 0.9             # la sciabordata all'indietro
const ATTRITO := 0.85
const GIRO := 1.6              # virata, in radianti al secondo
const CADENZA := 0.85          # colpi di remo al secondo

var _cozy: Node3D
var _player: Node3D
var _mochi: Node3D
var _sfx

var _molo: Node3D
var _barca: Node3D
var _remi: Array[Node3D] = []
var _aste: Array[Node3D] = []
var _pale: Array[Node3D] = []
var _gocce_remi: Array[GPUParticles3D] = []
var _naviga := false
var _vel := Vector3.ZERO
var _yaw := PI                 # in avanti = verso monte (-z), come si salpa
var _rem_t := 0.0              # la fase della vogata (giri interi = colpi)
var _t := 0.0
var _primo_imbarco := true
var _costruita := false
# i valori di voga APPLICATI, ammorbiditi verso il bersaglio: partire e
# fermarsi non scatta mai (il remo si posa, non si teletrasporta)
var _voga := {"sweep": 0.0, "alza": 0.5, "piuma": 1.2, "braccia": 0.3, "corpo": 0.0}

var _prompt: PanelContainer
var _prompt_label: Label

# ---- IMBARCO/SBARCO COL CORPO: niente teletrasporti ----
# il saltello in corso: {t, dur, da, a, tipo "imbarco"|"sbarco"}
var _salto := {}
# la molla del peso: la barca ACCUSA chi sale e si alleggerisce di chi
# scende — mezzo affondo e un rollio smorzato che si spegne in due onde
var _dip := 0.0
var _dip_v := 0.0
var _rollio := 0.0
var _rollio_v := 0.0


func _ready() -> void:
	add_to_group("barchetta")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_prompt()
	(func() -> void:
		_player = get_tree().get_first_node_in_group("player_controller")
		_mochi = _player.get_node_or_null("Mochi") if _player else null
		_cozy = get_tree().get_first_node_in_group("cozy_world")
		# il mondo si costruisce differito: il molo aspetta la geometria
		if _cozy and _cozy.has_signal("world_built"):
			_cozy.world_built.connect(_costruisci)
		_costruisci()
	).call_deferred()


# ------------------------------------------------------------ il cuore puro

## Un passo di navigazione: i remi spingono lungo la prua, la corrente
## spinge SEMPRE verso valle (+z), l'attrito riporta tutto a misura di
## barca a remi. PURA: le velocità terminali le verifica il test.
static func passo_navigazione(vel: Vector3, avanti: Vector3, spinta: float,
		delta: float) -> Vector3:
	var v := vel + avanti * spinta * delta
	v += Vector3(0, 0, CORRENTE) * delta
	return v.lerp(Vector3.ZERO, 1.0 - exp(-ATTRITO * delta))


## Dove la sponda rimanda la barca: la x resta nell'alveo attorno al
## corso vero del fiume. PURA (la usa anche il test coi valori di MATH).
static func dentro_l_alveo(x: float, rx: float) -> float:
	return clampf(x, rx - SPONDA, rx + SPONDA)


## L'arco del saltello d'imbarco: da → a con l'apice a campana in mezzo.
## PURA: agli estremi tocca ESATTAMENTE i due punti (mai un piede a
## mezz'aria), a metà corsa vola all'apice.
static func arco_salto(da: Vector3, a: Vector3, apice: float, t01: float) -> Vector3:
	var p := da.lerp(a, t01)
	p.y = lerpf(da.y, a.y, t01) + apice * 4.0 * t01 * (1.0 - t01)
	return p


## Un passo della molla smorzata del peso: (posizione, velocità) →
## (posizione, velocità). PURA: il test verifica che oscilli e si spenga.
static func passo_molla(x: float, v: float, k: float, smorzo: float,
		delta: float) -> Vector2:
	v += (-k * x - smorzo * v) * delta
	return Vector2(x + v * delta, v)


## UN COLPO DI REMO VERO, in quattro fasi su un giro di fase p (0..1):
##   ATTACCO   (p≈0.92→1): la pala scende e morde l'acqua;
##   PASSATA   (0→0.42):  la pala IN ACQUA spazza da prua a poppa — è
##                        qui che nasce la spinta (il picco a metà);
##   ESTRAZIONE(0.42→0.52): la pala esce e si PIUMA (di taglio all'aria,
##                        come i vogatori veri: meno vento, meno spruzzi);
##   RECUPERO  (0.52→0.92): torna verso prua FUORI dall'acqua, piumata,
##                        mentre il corpo si riporta avanti.
## Ritorna sweep (prua↔poppa), alza (pala su/giù), piuma (di taglio),
## braccia (il tirare di Mochi), corpo (il peso avanti/indietro) e
## spinta (quanto morde l'acqua ADESSO). PURA e continua sul giro:
## la verifica il test, fase per fase e sul punto di cucitura.
static func colpo_di_remo(p: float) -> Dictionary:
	p = fposmod(p, 1.0)
	var sweep: float
	var alza: float
	var piuma: float
	var braccia: float
	var corpo: float
	var spinta := 0.0
	if p < 0.42:
		var k := p / 0.42
		var e := k * k * (3.0 - 2.0 * k)
		sweep = lerpf(0.55, -0.5, e)
		alza = 0.02
		piuma = 0.0
		braccia = lerpf(0.78, 0.22, e)
		corpo = lerpf(-0.05, 0.06, e)
		spinta = sin(PI * k)
	elif p < 0.52:
		var k2 := (p - 0.42) / 0.10
		sweep = -0.5
		alza = lerpf(0.02, 0.42, k2)
		piuma = lerpf(0.0, 1.25, k2)
		braccia = 0.22
		corpo = 0.06
	elif p < 0.92:
		var k3 := (p - 0.52) / 0.40
		var e3 := k3 * k3 * (3.0 - 2.0 * k3)
		sweep = lerpf(-0.5, 0.55, e3)
		alza = 0.42
		piuma = 1.25
		braccia = lerpf(0.22, 0.78, e3)
		corpo = lerpf(0.06, -0.05, e3)
	else:
		var k4 := (p - 0.92) / 0.08
		sweep = 0.55
		alza = lerpf(0.42, 0.02, k4)
		piuma = lerpf(1.25, 0.0, k4)
		braccia = 0.78
		corpo = -0.05
	return {"sweep": sweep, "alza": alza, "piuma": piuma,
			"braccia": braccia, "corpo": corpo, "spinta": spinta}


## Vero mentre Mochi è a bordo (lo chiede la canna da pesca).
func naviga_attiva() -> bool:
	return _naviga


## Il punto in cui la canna ammara dalla barca: il centro del corso, un
## passo a valle — la lenza si distende con la corrente.
func punto_di_pesca(da: Vector3) -> Vector3:
	var z := da.z + 1.2
	return Vector3(MATH.river_x(z), ACQUA_Y, z)


# ------------------------------------------------------------ gli asset

func _costruisci() -> void:
	if _costruita:
		return
	_costruita = true
	var rx := MATH.river_x(MOLO_Z)
	_molo = _make_molo()
	_molo.position = Vector3(rx - 2.35, 0.0, MOLO_Z)
	add_child(_molo)
	_barca = _make_barca()
	_barca.position = Vector3(rx - 0.85, ACQUA_Y + 0.04, MOLO_Z + 0.9)
	_barca.rotation.y = _yaw
	add_child(_barca)


# il molo: assi di legno su pali piantati nell'acqua, con la bitta per
# la cima della barca e la lanterna che aspetta chi rientra col buio
func _make_molo() -> Node3D:
	var n := Node3D.new()
	var wood := CATALOG._mat(Color("c89a6b"), Color("a87c50"), 4.0, 0.5)
	var dark := CATALOG._mat(Color("a87c50"), Color("8a6440"), 4.0, 0.5)
	# le assi, dalla riva sull'acqua (verso est, dentro il fiume)
	for i in 5:
		var asse := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.44, 0.06, 0.66)
		asse.mesh = bm
		asse.material_override = wood
		asse.position = Vector3(0.28 + float(i) * 0.42, 0.14 - float(i) * 0.012, 0)
		asse.rotation.z = -0.015 * float(i)
		n.add_child(asse)
	# i pali che scendono nell'acqua
	for px: float in [0.5, 1.5, 2.3]:
		for pz: float in [-0.26, 0.26]:
			var palo := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.045
			cm.bottom_radius = 0.05
			cm.height = 0.9
			palo.mesh = cm
			palo.material_override = dark
			palo.position = Vector3(px, -0.3, pz)
			n.add_child(palo)
	# la bitta della cima
	var bitta := MeshInstance3D.new()
	var bm2 := CylinderMesh.new()
	bm2.top_radius = 0.05
	bm2.bottom_radius = 0.04
	bm2.height = 0.16
	bitta.mesh = bm2
	bitta.material_override = dark
	bitta.position = Vector3(2.2, 0.2, 0.24)
	n.add_child(bitta)
	return n


# la barchetta a remi: scafo di assi, prua e poppa rialzate, la panchetta
# di Mochi e i due remi sugli scalmi (animati remando)
func _make_barca() -> Node3D:
	var n := Node3D.new()
	var scafo_mat := CATALOG._mat(Color("b06a4a"), Color("8f5238"), 4.0, 0.5)
	var chiaro := CATALOG._mat(Color("e8cfa8"), Color("cfae82"), 5.0, 0.45)
	# il fondo e le fiancate (leggermente aperte verso l'alto)
	var fondo := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.52, 0.07, 1.2)
	fondo.mesh = fm
	fondo.material_override = scafo_mat
	fondo.position = Vector3(0, 0.03, 0)
	n.add_child(fondo)
	for sx: float in [-1.0, 1.0]:
		var fianco := MeshInstance3D.new()
		var im := BoxMesh.new()
		im.size = Vector3(0.06, 0.24, 1.24)
		fianco.mesh = im
		fianco.material_override = scafo_mat
		fianco.position = Vector3(sx * 0.28, 0.17, 0)
		fianco.rotation.z = -sx * 0.12
		n.add_child(fianco)
	# prua e poppa rialzate (la prua guarda -z locale: si salpa verso monte)
	for dz: float in [-1.0, 1.0]:
		var punta := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.5, 0.2, 0.28)
		punta.mesh = pm
		punta.material_override = scafo_mat
		punta.position = Vector3(0, 0.16, dz * 0.62)
		punta.rotation.x = -dz * 0.35
		n.add_child(punta)
	# la panchetta
	var panca := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.48, 0.05, 0.2)
	panca.mesh = bm
	panca.material_override = chiaro
	panca.position = Vector3(0, 0.2, 0.08)
	n.add_child(panca)
	# I REMI, com'è fatto un remo vero: il PERNO è lo scalmo sul falchetto;
	# l'asta è UN pezzo solo che lo attraversa — il MANICO in dentro e in
	# alto (nelle zampe di Mochi), la PALA in fuori e in acqua, FIGLIA
	# dell'asta (così non si stacca mai, qualunque cosa faccia la voga).
	# La prima stesura aveva il segno dell'asta invertito: cima in fuori
	# e pala orfana — i remi sembravano montati al contrario. Un test ora
	# fa la guardia all'orientamento.
	_remi.clear()
	_aste.clear()
	_pale.clear()
	for sx: float in [-1.0, 1.0]:
		var remo := Node3D.new()
		remo.name = "RemoDestro" if sx > 0.0 else "RemoSinistro"
		remo.position = Vector3(sx * 0.3, 0.26, 0.02)
		# lo scalmo: l'anellino di ferro in cui il remo lavora
		var scalmo := MeshInstance3D.new()
		var sm := TorusMesh.new()
		sm.inner_radius = 0.02
		sm.outer_radius = 0.036
		scalmo.mesh = sm
		scalmo.material_override = CATALOG._mat(Color("8a7f72"), Color("6f665b"), 5.0, 0.4)
		scalmo.rotation.x = PI * 0.5
		scalmo.rotation.z = sx * 0.85
		remo.add_child(scalmo)
		# l'asta: la cima (manico) piega IN DENTRO verso Mochi, il fondo
		# (pala) IN FUORI verso l'acqua
		var asta := Node3D.new()
		asta.rotation.z = sx * 0.85
		remo.add_child(asta)
		var legno := MeshInstance3D.new()
		var am := CylinderMesh.new()
		am.top_radius = 0.016
		am.bottom_radius = 0.02
		am.height = 1.05
		legno.mesh = am
		legno.material_override = chiaro
		asta.add_child(legno)
		# il pomello del manico (dove stringono le zampine)
		var manico := MeshInstance3D.new()
		var mm := SphereMesh.new()
		mm.radius = 0.028
		mm.height = 0.056
		manico.mesh = mm
		manico.material_override = chiaro
		manico.position = Vector3(0, 0.54, 0)
		asta.add_child(manico)
		# la pala, figlia dell'asta: piatta contro l'acqua nella passata,
		# di taglio (piumata) nel recupero
		var pala := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.025, 0.26, 0.12)
		pala.mesh = lm
		pala.material_override = scafo_mat
		pala.position = Vector3(0, -0.56, 0)
		asta.add_child(pala)
		# le goccioline dell'attacco: uno sbuffo d'acqua a ogni entrata
		var gocce := _make_gocce_remo()
		pala.add_child(gocce)
		n.add_child(remo)
		_remi.append(remo)
		_aste.append(asta)
		_pale.append(pala)
		_gocce_remi.append(gocce)
	return n


# lo sbuffo di goccioline quando la pala entra in acqua (one-shot)
func _make_gocce_remo() -> GPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.03, 0.045)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.78, 0.88, 0.95, 0.75)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 55.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0, -3.4, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.1
	var g := GPUParticles3D.new()
	g.amount = 9
	g.lifetime = 0.45
	g.one_shot = true
	g.explosiveness = 1.0
	g.local_coords = false
	g.emitting = false
	g.process_material = pm
	g.draw_pass_1 = quad
	g.position = Vector3(0, -0.13, 0)   # la punta della pala
	return g


# ------------------------------------------------------------ navigare

func _physics_process(delta: float) -> void:
	if not _naviga or _barca == null or _player == null:
		return
	_t += delta
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# la virata: dolce, un po' più viva quando la barca ha abbrivio
	_yaw -= input.x * GIRO * delta
	var avanti := Vector3(sin(_yaw), 0.0, cos(_yaw))
	var spinta := 0.0
	if input.y < -0.1:
		spinta = REMATA
	elif input.y > 0.1:
		spinta = -RETRO

	# --- LA VOGA: lo stesso ciclo muove remi, barca e corpo ---
	var voga := absf(spinta) > 0.01
	var p_prima := fposmod(_rem_t, 1.0)
	if voga:
		_rem_t += delta * CADENZA
	var p := fposmod(_rem_t, 1.0)
	var colpo := colpo_di_remo(p)
	# la spinta MORDE solo nella passata: la barca avanza a colpi, come
	# una barca a remi vera (la media resta quella delle velocità pure)
	var spinta_viva := spinta * (0.3 + 1.4 * float(colpo["spinta"])) if voga else 0.0
	_vel = passo_navigazione(_vel, avanti, spinta_viva, delta)

	# l'attacco: la pala morde l'acqua — sbuffo di gocce e il tuffo
	if voga and p < p_prima:
		for i in _gocce_remi.size():
			if is_instance_valid(_gocce_remi[i]):
				_gocce_remi[i].restart()
		if _sfx:
			_sfx.play("step_wet1", -18.0, randf_range(1.15, 1.35))

	# i bersagli della voga (a riposo i remi si posano piumati, fuori)
	var indietro := spinta < 0.0
	var bersaglio := {
		"sweep": (-float(colpo["sweep"]) if indietro else float(colpo["sweep"])) if voga else 0.0,
		"alza": float(colpo["alza"]) if voga else 0.5,
		"piuma": float(colpo["piuma"]) if voga else 1.2,
		"braccia": float(colpo["braccia"]) if voga else 0.3,
		"corpo": float(colpo["corpo"]) if voga else 0.0,
	}
	for k in _voga:
		_voga[k] = lerpf(float(_voga[k]), float(bersaglio[k]), 1.0 - exp(-10.0 * delta))

	var pos := _barca.position + _vel * delta
	# le sponde: la barca ci si appoggia e scivola, mai incastrata
	var rx := MATH.river_x(pos.z)
	var dentro := dentro_l_alveo(pos.x, rx)
	if absf(dentro - pos.x) > 0.001:
		pos.x = dentro
		_vel.x *= -0.25
	# i capolinea del corso
	var pz := clampf(pos.z, Z_MIN, Z_MAX)
	if absf(pz - pos.z) > 0.001:
		pos.z = pz
		_vel.z *= -0.25
	pos.y = ACQUA_Y + 0.04 + sin(_t * 2.1) * 0.018 + _dip
	_barca.position = pos
	# l'assetto: beccheggio con l'abbrivio, rollio con la virata — e la
	# molla del peso (imbarco/sbarco) sommata sopra
	_barca.rotation = Vector3(
			clampf(_vel.dot(avanti) * 0.05, -0.08, 0.08),
			_yaw,
			clampf(-input.x * 0.09, -0.09, 0.09) + sin(_t * 1.7) * 0.012 + _rollio)

	# i remi leggono la voga: lo scalmo spazza prua↔poppa (sweep, specchiato
	# per lato), alza la pala fuori dall'acqua (alza, specchiato) e la pala
	# si PIUMA nel recupero (di taglio, come i vogatori veri)
	for i in _remi.size():
		var sx := -1.0 if i == 0 else 1.0
		_remi[i].rotation = Vector3(0.0, float(_voga["sweep"]) * sx,
				sx * float(_voga["alza"]))
		if i < _pale.size() and is_instance_valid(_pale[i]):
			_pale[i].rotation.y = float(_voga["piuma"]) * sx

	# Mochi REMA col corpo: le braccia tirano nella passata e si distendono
	# nel recupero (pour), il busto si china sul colpo (crouch), e il peso
	# si sposta avanti/indietro sulla panchetta (l'offset lungo la prua).
	# seduta SULLA panchetta (che sta un passetto verso poppa), mai a
	# mezz'aria: il peso della voga scivola avanti e indietro da lì
	_player.global_position = _barca.position + Vector3(0, 0.27, 0) \
			- avanti * 0.08 + avanti * float(_voga["corpo"])
	if _mochi:
		_mochi.set("_yaw", atan2(-avanti.x, -avanti.z))
		_mochi.set("pour", float(_voga["braccia"]))
		_mochi.set("crouch", 0.05 + (0.42 - float(_voga["alza"])) * 0.28)


## L'IMBARCO: non un teletrasporto — Mochi spicca il saltello dall'assito
## alla panchetta, e all'atterraggio la barca ACCUSA il peso (affonda un
## soffio, rolla dal lato di salita, l'acqua si increspa allo scafo).
func _imbarca() -> void:
	if not _salto.is_empty():
		return
	_player.set_physics_process(false)
	_player.set("velocity", Vector3.ZERO)
	_salto = {"t": 0.0, "dur": 0.42, "da": _player.global_position,
			"a": _barca.position + Vector3(0, 0.27, 0), "tipo": "imbarco"}
	if _sfx:
		_sfx.play("step_wet2", -16.0, 1.25)   # lo stacco dall'assito umido


func _atterra_imbarco(da: Vector3) -> void:
	_naviga = true
	_vel = Vector3.ZERO
	_yaw = _barca.rotation.y
	if _mochi:
		_mochi.call("set_pose", "sit")
		_mochi.call("hold_rod", true)   # la presa a due zampe: i manici dei remi
	# il peso si fa sentire: mezzo affondo e il rollio DAL LATO di salita
	var locale: Vector3 = _barca.global_transform.basis.inverse() \
			* (da - _barca.global_position)
	_scossa(-0.55, -signf(locale.x + 0.001) * 0.7)
	_spruzzo_scafo(1.0)
	if _sfx:
		_sfx.play("step_wet2", -12.0, 0.9)
		_sfx.plop()
	if _primo_imbarco:
		_primo_imbarco = false
		_toast(L10n.t("I remi in zampa: su per il fiume! (si rema come si cammina, E per scendere)"))


## LO SBARCO: la spinta di gamba verso riva — la barca rincula e si
## alleggerisce, Mochi vola sull'erba della sponda più vicina.
func _sbarca() -> void:
	if not _salto.is_empty():
		return
	_naviga = false
	if _mochi:
		_mochi.call("set_pose", "stand")
		_mochi.call("hold_rod", false)
		_mochi.set("pour", 0.0)
		_mochi.set("crouch", 0.0)
	var pos: Vector3 = _barca.position
	var rx := MATH.river_x(pos.z)
	var lato: float = signf(pos.x - rx)
	if lato == 0.0:
		lato = -1.0
	_salto = {"t": 0.0, "dur": 0.5, "da": _player.global_position,
			"a": Vector3(rx + lato * (2.35 + 0.8), 0.0, pos.z), "tipo": "sbarco"}
	# la spinta di gamba: la barca la sente subito
	_scossa(0.4, -lato * 0.55)
	_spruzzo_scafo(0.6)
	if _sfx:
		_sfx.play("step_wet2", -12.0, 1.1)


func _atterra_sbarco() -> void:
	if _player:
		_player.set_physics_process(true)
	if _sfx:
		_sfx.play("step_grass1", -18.0, 1.0)   # i piedini sull'erba


# ------------------------------------------------ il saltello e il peso

## Il volo del saltello, frame a frame: arco puro, il muso di Mochi verso
## la meta, e all'ultimo istante l'atterraggio giusto.
func _passo_salto(delta: float) -> void:
	if _salto.is_empty() or _player == null:
		return
	_salto["t"] = float(_salto["t"]) + delta
	var t01 := clampf(float(_salto["t"]) / float(_salto["dur"]), 0.0, 1.0)
	var e := t01 * t01 * (3.0 - 2.0 * t01)   # stacco e atterraggio morbidi
	if str(_salto["tipo"]) == "imbarco":
		# la barca dondola sull'acqua: la panchetta va inseguita, o Mochi
		# atterra dove la barca ERA
		_salto["a"] = _barca.position + Vector3(0, 0.27, 0)
	_player.global_position = arco_salto(_salto["da"], _salto["a"], 0.42, e)
	if _mochi:
		var dir: Vector3 = (_salto["a"] as Vector3) - (_salto["da"] as Vector3)
		dir.y = 0.0
		if dir.length() > 0.01:
			_mochi.set("_yaw", atan2(-dir.x, -dir.z))
	if t01 >= 1.0:
		var tipo := str(_salto["tipo"])
		var da: Vector3 = _salto["da"]
		_salto = {}
		if tipo == "imbarco":
			_atterra_imbarco(da)
		else:
			_atterra_sbarco()


## La molla del peso, SEMPRE viva: integra il mezzo affondo e il rollio
## smorzati; da ferma li applica lei (e fa respirare la barca sull'acqua),
## in navigazione li somma il _physics_process alle sue formule.
func _passo_peso(delta: float) -> void:
	var md := passo_molla(_dip, _dip_v, 90.0, 9.0, delta)
	_dip = md.x
	_dip_v = md.y
	var mr := passo_molla(_rollio, _rollio_v, 70.0, 7.0, delta)
	_rollio = mr.x
	_rollio_v = mr.y
	if not _naviga and _barca:
		_t += delta
		_barca.position.y = ACQUA_Y + 0.04 + sin(_t * 1.3) * 0.008 + _dip
		_barca.rotation.z = _rollio + sin(_t * 1.1) * 0.006


## Il colpo che la barca accusa: velocità iniziali della molla (giù per
## chi sale, su per chi scende) — poi si spegne da sola in due onde.
func _scossa(dip_v: float, rollio_v: float) -> void:
	_dip_v += dip_v
	_rollio_v += rollio_v


## L'acqua allo scafo: l'anello d'increspatura vero del fiume.
func _spruzzo_scafo(forza: float) -> void:
	if _cozy and _cozy.has_method("water_ripple"):
		_cozy.call("water_ripple",
				_barca.global_position + Vector3(randf_range(-0.15, 0.15), 0,
				randf_range(-0.2, 0.2)), 0.65 * forza, 0.02)


# ------------------------------------------------------------ il prompt

func _process(_delta: float) -> void:
	_passo_salto(_delta)
	_passo_peso(_delta)
	if _prompt == null or _player == null or _barca == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_prompt.visible = false
		return
	var text := ""
	var wp := Vector3.ZERO
	if _naviga:
		text = L10n.t("E — scendi a riva")
		wp = _barca.global_position + Vector3(0, 1.3, 0)
	elif _player.is_physics_processing() \
			and _player.global_position.distance_to(_barca.global_position) < 2.0:
		text = L10n.t("E — sali sulla barchetta")
		wp = _barca.global_position + Vector3(0, 1.1, 0)
	if text == "" or cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = text
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or _barca == null or _player == null:
		return
	if not _salto.is_empty():
		return   # a mezz'aria non si cambia idea
	if _naviga:
		# la canna ha la precedenza: se sta pescando, la E è sua
		var fishing := get_node_or_null("../Fishing")
		if fishing and str(fishing.get("_state")) != "off":
			return
		_sbarca()
		get_viewport().set_input_as_handled()
	elif _player.is_physics_processing() \
			and _player.global_position.distance_to(_barca.global_position) < 2.0:
		_imbarca()
		get_viewport().set_input_as_handled()


func _toast(text: String) -> void:
	var visitors := get_node_or_null("../Visitors")
	if visitors:
		visitors.call("_show_toast", text)


func _build_prompt() -> void:
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
	_prompt_label.add_theme_color_override("font_color", Color("6a4a3a"))
	_prompt.add_child(_prompt_label)
