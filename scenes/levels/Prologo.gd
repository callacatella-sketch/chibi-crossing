extends Node3D

## IL PROLOGO — la piccola Mochi sotto la tempesta.
##
## È la prima cosa che il giocatore vede. Il piano completo sta in
## docs/PROLOGO.md; qui c'è la messa in scena.
##
## LA REGOLA DI QUESTO FILE: **la Mochi del prologo è LA MOCHI VERA.** Si
## istanzia `scenes/characters/Mochi.tscn`, si scala, e si usa quello che lei
## sa già fare. Ricostruire una cucciola da zero è già stato provato una volta
## ed era peggio: le proporzioni scritte a mano non reggono il confronto con un
## rig che è stato limato per mesi. Qui non si modella niente — si RECITA.
##
## Cosa mette in scena, e con che cosa (tutto già in casa):
##  · la piccolezza  → `scale` sul contenitore. Nient'altro.
##  · gli occhietti stanchi e le orecchie basse → `Mochi.set_tired(true)`,
##    che abbassa le orecchie (`_droop`) e socchiude gli occhi;
##  · il musetto triste → `Mochi.forza_espressione("triste")`, che mette
##    sopracciglia in fremito, boccuccia in giù, pupille dilatate — e come
##    effetto collaterale meraviglioso **la fa guardare in camera**: la
##    quarta parete si rompe con una riga (vedi Mochi._update_face);
##  · la camminata → Mochi anima da sé il passo, le braccine, la coda e le
##    orecchie SE il suo genitore è un CharacterBody3D di cui legge la
##    `velocity`. Quindi il prologo la mette dentro un corpo e muove quello:
##    zero animazioni nuove.
##  · il PIANTO → l'espressione «piange» non esisteva e ora c'è, nel motore
##    del volto (FaceController): occhi grandi e tristi con le palpebre
##    pesanti, boccuccia in giù, guance accese, e due lacrime che scendono
##    ognuna col suo tempo. Sta lì e non qui, così piange chiunque.
##  · le proporzioni da cucciola → le STESSE dei bambini che nascono nel
##    villaggio (Visitor.TAGLIA_CUCCIOLO e TESTA_CUCCIOLO): testone e
##    corpicino, non una Mochi rimpicciolita.
##
## PERCHÉ È UNA SCENA A SÉ: il prologo non ha villaggio, non ha vicini, non ha
## HUD e non ha salvataggio. Nel MainLevel bisognerebbe spegnere venti sistemi;
## qui non c'è niente da spegnere. Quando finisce, passa al MainLevel.

signal prologo_finito

const MOCHI := preload("res://scenes/characters/Mochi.tscn")
## Da qui arrivano le proporzioni del cucciolo: TAGLIA_CUCCIOLO e
## TESTA_CUCCIOLO sono le stesse che il gioco usa per i bambini che NASCONO
## nel villaggio. Ricopiarle qui vorrebbe dire avere due infanzie diverse.
const VISITOR := preload("res://scenes/npc/Visitor.gd")

## Le battute, nell'ordine. `paura` è quanto è ancora spaventata quando la
## dice: scende lungo la scena, ed è lei a raccontare la storia.
const BATTUTE := [
	{"testo": "dov'è mamma?... dov'è papà?...", "espr": "piange", "attesa": 3.4},
	{"testo": "ho paura... mi sento sola...", "espr": "piange", "attesa": 3.2},
	{"testo": "cosa? mi vuoi aiutare? perché?", "espr": "curioso", "attesa": 3.6},
	{"testo": "forse con te... Mochi non si sentirà mai più sola?",
		"espr": "meraviglia", "attesa": 4.2},
]

const CREMA := Color("fff6e6")
const INCHIOSTRO := Color("4a3328")

var _corpo: CharacterBody3D
var _mochi: Node3D
var _cam: Camera3D
var _pioggia: GPUParticles3D
var _lampo: DirectionalLight3D
var _sole: DirectionalLight3D
var _riempi: OmniLight3D
var _amb: Environment
var _pannello: PanelContainer
var _riga: Label
var _sereno := 0.0        # 0 = tempesta, 1 = cielo aperto
var _avanti := 0.0        # quanto sta camminando adesso
var _t := 0.0


func _ready() -> void:
	_costruisci_cielo()
	_costruisci_prato()
	_costruisci_pioggia()
	_costruisci_ui()
	_costruisci_piccola()

	_cam = Camera3D.new()
	_cam.fov = 38.0
	add_child(_cam)
	_cam.current = true
	_inquadra(0.0)

	_recita()


# ------------------------------------------------------------- la piccola

func _costruisci_piccola() -> void:
	# il corpo serve SOLO perché Mochi legga la sua velocity e animi il passo
	# da sola: è il patto scritto in cima a Mochi.gd. Nessuna gravità, nessuna
	# collisione: la muoviamo noi a mano.
	_corpo = CharacterBody3D.new()
	_corpo.position = Vector3(-1.9, 0, 0)
	# TESTONE E CORPICINO: non una Mochi rimpicciolita di un fattore solo, ma
	# la STESSA trasformazione che il gioco applica ai cuccioli che nascono
	# nel villaggio (Visitor.set_cucciolo) — il corpo scende a 0.44, e sopra
	# quello la testa RISALE a 1.34. È il rapporto che fa leggere «bambino»:
	# scalare tutto insieme dà solo una Mochi lontana.
	_corpo.scale = Vector3.ONE * VISITOR.TAGLIA_CUCCIOLO
	add_child(_corpo)

	_mochi = MOCHI.instantiate()
	_corpo.add_child(_mochi)
	_testone()

	# gli occhietti stanchi e le orecchie basse: due chiamate, zero modelli
	_mochi.call("set_tired", true)
	_via_la_goccia_di_sudore()
	_mochi.call("forza_espressione", "piange", 1.0)



## La testona da cucciola. La palla della testa cresce attorno al proprio
## centro, quindi va anche ALZATA: senza, il collo se la mangia e resta un
## musetto appoggiato sul colletto (è la stessa riga che Visitor.set_cucciolo
## ha dovuto scrivere per i cuccioli del villaggio).
func _testone() -> void:
	var testa: Node3D = _mochi.call("get_attach_point", "testa")
	if testa == null:
		return
	var k := VISITOR.TESTA_CUCCIOLO
	testa.scale = Vector3.ONE * k
	testa.position += Vector3(0, 0.30 * (k - 1.0), 0)


## `set_tired` accende anche la goccia di sudore della stanchezza. Sotto la
## pioggia una goccia di sudore non vuol dire niente — e con le lacrime
## accanto è perfino confusa. La si spegne da fuori, senza toccare Mochi:
## è la sfera di raggio 0.042 appesa alla testa (Mochi.gd:733).
func _via_la_goccia_di_sudore() -> void:
	var testa: Node3D = _mochi.call("get_attach_point", "testa")
	if testa == null:
		return
	for f in testa.get_children():
		var mi := f as MeshInstance3D
		if mi == null:
			continue
		var sfera := mi.mesh as SphereMesh
		if sfera != null and absf(sfera.radius - 0.042) < 0.0005:
			mi.visible = false


# ------------------------------------------------------------------ la regia

func _recita() -> void:
	# 1. cammina sotto la pioggia, senza dire niente. Prima si guarda.
	#    L'espressione forzata la fa già guardare in camera, e va bene: sta
	#    cercando qualcuno.
	_avanti = 1.0
	await _aspetta(3.4)
	_avanti = 0.0
	await _aspetta(0.8)

	# 2. il lampo, e poi SI VOLTA VERSO IL GIOCATORE. È il gesto della scena:
	#    senza, resta girata dalla parte in cui camminava — Mochi si orienta
	#    da sé verso la direzione di marcia, e quando si ferma ci resta.
	await _saetta()
	await _aspetta(0.35)
	await _girati()
	await _aspetta(0.6)

	# 3-5. le battute
	for i in BATTUTE.size():
		var b: Dictionary = BATTUTE[i]
		_mochi.call("forza_espressione", str(b["espr"]), 1.0)
		if i == 2:
			# «mi vuoi aiutare?»: le orecchie si tirano su. È il primo
			# movimento verso l'alto di tutta la scena.
			_mochi.call("set_tired", false)
		if i == 3:
			_apri_il_cielo()
		await _dì(str(b["testo"]), float(b["attesa"]))

	await _aspetta(1.6)
	prologo_finito.emit()


## Si volta verso la camera. Piano, non di scatto: chi ha sentito qualcosa e
## non sa ancora se avere paura si gira così.
##
## SI RUOTA IL CONTENITORE, non Mochi. Mochi possiede il proprio yaw — scrive
## `rotation.y = _yaw` a ogni frame e lo cambia solo mentre si muove
## (Mochi.gd:965-975) — quindi qualunque cosa le si scriva addosso viene
## cancellata al frame dopo. Ruotando il corpo che la contiene, il suo yaw
## resta suo e la sua faccia va dove serve: si compensa quello che tiene lei.
func _girati() -> void:
	var suo: float = _mochi.rotation.y
	var v := _cam.global_position - _corpo.global_position
	var globale := atan2(-v.x, -v.z)     # il muso guarda -Z
	var da: float = _corpo.rotation.y
	var a := globale - suo
	var d := 0.0
	while d < 1.0:
		d = minf(1.0, d + get_process_delta_time() / 1.15)
		_corpo.rotation.y = lerp_angle(da, a, smoothstep(0.0, 1.0, d))
		await get_tree().process_frame


func _saetta() -> void:
	# il lampo sbatte DUE volte, e il secondo sbattito è più corto: un lampo
	# a dissolvenza è un lampo di cartone
	for durata: float in [0.06, 0.035]:
		_lampo.light_energy = 3.4
		await _aspetta(durata)
		_lampo.light_energy = 0.0
		await _aspetta(0.08)


func _apri_il_cielo() -> void:
	# la catarsi: non un taglio, un'apertura lenta. Dodici secondi, così il
	# giocatore la sente arrivare mentre lei sta ancora parlando.
	var d := 0.0
	while d < 1.0:
		d = minf(1.0, d + get_process_delta_time() / 12.0)
		_sereno = smoothstep(0.0, 1.0, d)
		await get_tree().process_frame


# ------------------------------------------------------------------ la voce

## Mostra una battuta e aspetta che sia letta. Si scrive a macchina: il ritmo
## della lettura diventa il ritmo del respiro di chi parla. I puntini di
## sospensione vanno LENTI — sono recitazione, non punteggiatura.
func _dì(testo: String, attesa: float) -> void:
	var t := L10n.t(testo)
	_riga.text = ""
	_pannello.modulate.a = 0.0
	_pannello.visible = true
	var apri := 0.0
	while apri < 1.0:
		apri = minf(1.0, apri + get_process_delta_time() / 0.35)
		_pannello.modulate.a = apri
		await get_tree().process_frame
	for i in t.length():
		_riga.text = t.substr(0, i + 1)
		await _aspetta(0.085 if t[i] == "." else 0.038)
	await _aspetta(attesa)
	var chiudi := 0.0
	while chiudi < 1.0:
		chiudi = minf(1.0, chiudi + get_process_delta_time() / 0.5)
		_pannello.modulate.a = 1.0 - chiudi
		await get_tree().process_frame
	_pannello.visible = false


func _aspetta(s: float) -> void:
	await get_tree().create_timer(s).timeout


# ------------------------------------------------------------------ il mondo

func _costruisci_cielo() -> void:
	var we := WorldEnvironment.new()
	_amb = Environment.new()
	_amb.background_mode = Environment.BG_COLOR
	_amb.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_amb.fog_enabled = true
	we.environment = _amb
	add_child(we)

	_sole = DirectionalLight3D.new()
	_sole.rotation_degrees = Vector3(-26, 34, 0)
	add_child(_sole)

	# il lampo: una luce a parte, spenta, che sbatte
	_lampo = DirectionalLight3D.new()
	_lampo.rotation_degrees = Vector3(-46, -62, 0)
	_lampo.light_color = Color(0.86, 0.90, 1.0)
	_lampo.light_energy = 0.0
	add_child(_lampo)

	# la luce di riempimento dalla parte della camera: senza, nella tempesta
	# la piccola diventa una sagoma nera e la faccia — che è tutto — non si
	# legge. È il mestiere del direttore della fotografia, non un trucco.
	_riempi = OmniLight3D.new()
	_riempi.light_color = Color(0.82, 0.88, 1.0)
	_riempi.omni_range = 6.0
	_riempi.light_energy = 1.15
	_riempi.shadow_enabled = false
	add_child(_riempi)
	_clima(0.0)


## Tutto il tempo del prologo in una funzione sola: cielo, nebbia, luce e
## pioggia si muovono INSIEME. Tenerli separati è il modo sicuro di ritrovarsi
## un cielo azzurro con la luce ancora livida.
func _clima(s: float) -> void:
	_amb.background_color = Color("2f3648").lerp(Color("bfe0ef"), s)
	_amb.ambient_light_color = Color("55647f").lerp(Color("cfe4f2"), s)
	_amb.ambient_light_energy = lerpf(0.85, 1.1, s)
	_amb.fog_light_color = Color("3d4a62").lerp(Color("dfeef7"), s)
	_amb.fog_density = lerpf(0.035, 0.004, s)
	_sole.light_color = Color("8b99b5").lerp(Color("ffe9c6"), s)
	_sole.light_energy = lerpf(0.5, 1.2, s)
	if _riempi:
		_riempi.light_energy = lerpf(1.15, 0.35, s)
	if _pioggia:
		_pioggia.amount_ratio = lerpf(1.0, 0.0, smoothstep(0.12, 0.8, s))


func _costruisci_prato() -> void:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	m.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/handpaint.gdshader")
	mat.set_shader_parameter("color_a", Color("6f8a5c"))
	mat.set_shader_parameter("color_b", Color("55704a"))
	mat.set_shader_parameter("noise_scale", 14.0)
	mat.set_shader_parameter("noise_amount", 0.5)
	m.material_override = mat
	add_child(m)


func _costruisci_pioggia() -> void:
	_pioggia = GPUParticles3D.new()
	_pioggia.amount = 1100
	_pioggia.lifetime = 1.1
	_pioggia.position = Vector3(0, 4.2, 1.6)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(7, 0.2, 5)
	pm.direction = Vector3(0.2, -1, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 9.0
	pm.initial_velocity_max = 11.5
	pm.gravity = Vector3(0, -6, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color = Color(0.80, 0.88, 0.98, 0.5)
	_pioggia.process_material = pm
	var goccia := CylinderMesh.new()
	goccia.top_radius = 0.004
	goccia.bottom_radius = 0.004
	goccia.height = 0.24
	goccia.radial_segments = 4
	goccia.rings = 1
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(0.84, 0.90, 0.98, 0.45)
	goccia.material = gm
	_pioggia.draw_pass_1 = goccia
	add_child(_pioggia)


func _costruisci_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var centro := MarginContainer.new()
	centro.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	centro.offset_top = -200
	centro.offset_bottom = -64
	centro.add_theme_constant_override("margin_left", 240)
	centro.add_theme_constant_override("margin_right", 240)
	layer.add_child(centro)

	_pannello = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(CREMA.r, CREMA.g, CREMA.b, 0.94)
	sb.set_corner_radius_all(24)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 22
	sb.content_margin_bottom = 24
	sb.shadow_color = Color(0, 0, 0, 0.22)
	sb.shadow_size = 12
	_pannello.add_theme_stylebox_override("panel", sb)
	_pannello.visible = false
	_pannello.size_flags_vertical = Control.SIZE_SHRINK_END
	centro.add_child(_pannello)

	_riga = Label.new()
	_riga.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_riga.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_riga.add_theme_font_size_override("font_size", 30)
	_riga.add_theme_color_override("font_color", INCHIOSTRO)
	_pannello.add_child(_riga)


# ------------------------------------------------------------------ il tempo

func _process(delta: float) -> void:
	_t += delta
	_clima(_sereno)

	if _corpo:
		# la velocity NON serve a muoverla: serve a farle animare il passo.
		# Mochi legge la velocity del genitore e ci mette il saltello, le
		# braccine, la coda e le orecchie. Noi spostiamo il corpo a mano.
		var v := 0.62 * _avanti
		# la velocity NON la muove: e' solo il segnale con cui Mochi decide
		# passo, braccine, coda e orecchie. E' un vettore GLOBALE, quindi
		# resta (v,0,0) anche quando il contenitore e' ruotato.
		_corpo.velocity = Vector3(v, 0, 0)
		_corpo.global_position.x += delta * v

	_inquadra(delta)


## La camera. Bassa e alla SUA altezza: messa a quella di un adulto, la piccola
## diventa una cosa che si guarda dall'alto, e la scena cambia di significato.
func _inquadra(delta: float) -> void:
	if not _corpo or not _cam:
		return
	# l'altezza degli occhi la si CHIEDE alla testa, non si ricalcola: con la
	# testona che si alza e il corpo che si rimpicciolisce, il conto a mano
	# sbaglia — e inquadrare dieci centimetri sopra gli occhi basta a far
	# sembrare la scena mal puntata.
	var testa: Node3D = _mochi.call("get_attach_point", "testa")
	var occhi: Vector3 = testa.global_position if testa != null \
			else _corpo.global_position + Vector3(0, 0.5, 0)
	# di tre quarti mentre cammina, in faccia quando parla
	var frontale := 1.0 if _avanti <= 0.0 else 0.0
	var offset := Vector3(1.05, 0.16, -2.05).lerp(Vector3(0.0, 0.12, -1.72),
			frontale)
	var voluta := occhi + offset
	if delta <= 0.0:
		_cam.global_position = voluta
	else:
		# la camera INSEGUE con un ritardo: rigida sembra una telecamera di
		# sorveglianza, e in una scena così si sente
		_cam.global_position = _cam.global_position.lerp(voluta,
				minf(1.0, delta * 2.0))
	_cam.look_at(occhi + Vector3(0, 0.02, 0), Vector3.UP)
	if _riempi:
		# la luce di riempimento viaggia con la camera
		_riempi.global_position = _cam.global_position + Vector3(0, 0.5, 0)
