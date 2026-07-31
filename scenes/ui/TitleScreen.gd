extends Node3D

## La schermata del titolo: IL TUO VILLAGGIO, non una cartolina.
##
## Il menù legge `village.json` (senza caricare la partita: bastano poche
## righe, vedi RiassuntoSalvataggio) e mostra quello che c'è davvero —
##   · il GRANDE ALBERO alla taglia che ha raggiunto in questa partita
##     (la stessa geometria del villaggio, AlberoGeo: al giorno quaranta è
##     un gigante, il primo giorno è un alberello);
##   · i VICINI VERI, quelli con cui hai legato di più, che nel diorama
##     FANNO qualcosa: due si rincorrono attorno al tronco, uno dondola
##     sull'altalena, uno dorme, uno annusa un fiore, uno saluta te;
##   · e un CLIMA emotivo che comanda tutto il resto — cielo, luce,
##     saturazione, petali, quanti fiori, la posa e la faccia di Mochi,
##     perfino la velocità con cui respira la camera.
##
## Il clima è la ragione di tutto questo. Un menù che è sempre la stessa
## bella immagine dice al giocatore che quello che ha vissuto sta di là, in
## un altro posto. Se invece la sera dopo un lutto il prato è grigio e i
## vicini stanno seduti vicini senza fare niente — senza una scritta, senza
## una notifica — allora il gioco si ricorda, e lo si sente prima ancora di
## premere Continua.
##
## Nessuna dipendenza dal mondo di gioco: il diorama si costruisce in
## codice e carica sempre pulito, anche con un salvataggio rotto.

const MAIN_SCENE := "res://scenes/levels/MainLevel.tscn"
## Un villaggio nuovo non comincia dal villaggio: comincia dalla notte in
## cui sei arrivata (scenes/prologo/Prologo.gd). Tre minuti, poi si entra
## nel villaggio da soli. «Continua» ci passa sopra: il temporale è già
## successo, e non si rivive.
const PROLOGO_SCENE := "res://scenes/prologo/Prologo.tscn"
const SAVE_PATH := "user://village.json"
const PROLOGO_APPUNTI := "user://prologo.json"

const RIASSUNTO := preload("res://scenes/ui/RiassuntoSalvataggio.gd")
const ALBERO := preload("res://scenes/world/AlberoGeo.gd")
const ATTORE := preload("res://scenes/ui/AttoreTitolo.gd")
const ORA := preload("res://scenes/ui/OraDelGiorno.gd")
const REGIA := preload("res://scenes/ui/RegiaDiorama.gd")

## Dove sta l'albero nel diorama. Tutto il resto gli gira intorno.
const ALBERO_POS := Vector3(-1.3, 0.0, -1.6)
## Quanti vicini al massimo entrano nel diorama. Ventotto residenti tutti
## insieme davanti a un menù sono una folla, non un villaggio: se ne
## prendono i più cari (l'amicizia decide), e gli altri «sono altrove».
const MAX_ATTORI := 7

var _cam: Camera3D
var _cam_base := Vector3(1.4, 1.9, 4.6)
var _look := Vector3(-0.6, 1.1, -0.4)
var _t := 0.0

var _save: RefCounted            # il ritratto del salvataggio
var _clima := "attesa"
var _mochi: Node3D
var _attori: Array[Node3D] = []
var _altalena: Node3D
var _albero_h := 3.0
var _albero_cr := 1.5
var _sole: DirectionalLight3D
var _env: Environment
var _palette := {}
var _rng := RandomNumberGenerator.new()
var _prossima_prova := REGIA.PROVA_OGNI
var _scena := {}                 # la scenetta in corso, se c'è
var _ospite: Node3D              # la farfalla / la stella di passaggio
var _ospite_t := 0.0

var _ui: CanvasLayer
var _menu: Control
var _settings: CozySettingsPanel
var _confirm: Control
var _sfx


func _ready() -> void:
	# Le verifiche da riga di comando entrano dritte nel villaggio: da quando
	# il gioco parte dal titolo, un menù che aspetta un clic bloccherebbe
	# CHIBI_SHOT (gli screenshot documentati nel README), CHIBI_LEGNA e
	# CHIBI_MAKESAVE — che girano senza nessuno alla tastiera.
	for v in ["CHIBI_SHOT", "CHIBI_LEGNA", "CHIBI_LAVORI", "CHIBI_FESTA", "CHIBI_FILO", "CHIBI_FRUTTETO", "CHIBI_COMMISSIONI", "CHIBI_NIDO", "CHIBI_FACCE", "CHIBI_PORTE", "CHIBI_PIOGGIA", "CHIBI_BUCATO", "CHIBI_SALUTI", "CHIBI_STAGNO", "CHIBI_CARTA", "CHIBI_ESTETICA", "CHIBI_SALONE", "CHIBI_ESTETISTA", "CHIBI_ANFITEATRO", "CHIBI_TACCUINO", "CHIBI_SOGNI", "CHIBI_PROVINO", "CHIBI_PROVLUCE", "CHIBI_MAKESAVE"]:
		if OS.get_environment(v) != "":
			_enter.call_deferred()
			return
	_sfx = get_node_or_null(^"/root/Sfx")
	# il ritratto del salvataggio PRIMA di costruire: albero, luce, fiori,
	# vicini e perfino il sottotitolo dipendono da com'è messo il villaggio
	_save = RIASSUNTO.dal_disco(SAVE_PATH)
	_clima = _save.clima()
	_build_world()
	_build_ui()


func _process(delta: float) -> void:
	_t += delta
	if _cam:
		# ANCHE LA CAMERA SENTE. Nei giorni tristi respira più piano e si
		# muove di meno: non è un effetto, è la differenza fra guardare e
		# stare a guardare. (Il moto non si ferma mai del tutto — un menù
		# immobile sembra bloccato, non commosso.)
		var lento: float = 0.55 if _clima in ["lutto", "commiato"] else 1.0
		var q := _t * lento
		_cam.position = _cam_base + Vector3(sin(q * 0.13) * 0.7 * lento,
				sin(q * 0.19) * 0.18, 0.0)
		_cam.look_at(_look + Vector3(sin(q * 0.11) * 0.15, 0, 0), Vector3.UP)
	# i vicini non passano MAI davanti ai pulsanti: chi finisce nel terzo
	# sinistro dello schermo viene ricondotto dall'altra parte dell'albero
	for a in _attori:
		if is_instance_valid(a) and a.global_position.x < ALBERO_POS.x - 1.2:
			a.global_position.x = ALBERO_POS.x - 1.2
	_regia(delta)


# ======================================================== la regia continua

## La scena non è un loop: EVOLVE. Ogni tanto la regia guarda chi ha
## finito quello che stava facendo, gli dà altro da fare, e ogni tanto
## mette in scena qualcosa a due.
func _regia(delta: float) -> void:
	if _attori.is_empty():
		return
	_avanza_scena(delta)
	_avanza_ospite(delta)
	# i mestieri scaduti: uno alla volta, così non cambiano tutti insieme
	for a in _attori:
		if not is_instance_valid(a) or not a.vuole_cambiare():
			continue
		var liberi := 0
		for b in _attori:
			if b != a and is_instance_valid(b) and not b._in_scena:
				liberi += 1
		var nuovo: String = REGIA.mestiere_nuovo(_clima, str(a.mestiere), liberi, _rng)
		a.cambia_mestiere(nuovo)
		if nuovo == "rincorre":
			_accoppia_rincorsa(a)
		if nuovo == "altalena" and _altalena:
			a.usa_altalena(_altalena)
		break

	_prossima_prova -= delta
	if _prossima_prova <= 0.0:
		_prossima_prova = REGIA.PROVA_OGNI
		if _scena.is_empty():
			_prova_scenetta()
		if _ospite == null:
			var chi: String = REGIA.ospite(ORA.e_notte(_palette), _clima, _rng)
			if chi != "":
				_fai_entrare(chi)


## LE LUCCIOLE. Solo di notte, e solo se il villaggio non è in lutto: la
## notte del menù, senza, è un prato blu e basta. Con loro è il posto in
## cui uno vorrebbe tornare — ed è lo stesso prato.
func _lucciole() -> void:
	var notte := float(ORA.e_notte(_palette))
	if notte < 0.45 or _clima == "lutto":
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(0.075, 0.075)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.94, 0.55, 0.9)
	mat.albedo_texture = _alone()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(7.0, 0.7, 5.0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.22
	pm.gravity = Vector3.ZERO
	pm.damping_min = 0.1
	pm.damping_max = 0.4
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	# l'ALONE che si accende e si spegne: una lucciola sempre accesa è una
	# lampadina. La curva sale in fretta e cala piano, e ognuna ha la sua
	# fase perché la vita non è la stessa per tutte.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0),
			Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	var p := GPUParticles3D.new()
	p.amount = int(lerpf(14.0, 44.0, float(_save.vivacita())) * notte)
	p.lifetime = 4.5
	p.randomness = 1.0
	p.preprocess = 3.0
	p.process_material = pm
	p.draw_pass_1 = quad
	p.position = ALBERO_POS + Vector3(0.8, 0.85, 1.4)
	add_child(p)


func _alone() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45),
			Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.width = 48
	t.height = 48
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.gradient = g
	return t


# -------------------------------------------------------- le scenette

## Prova a mettere in scena qualcosa fra due (o tre) vicini liberi.
func _prova_scenetta() -> void:
	var liberi: Array = []
	for a in _attori:
		if is_instance_valid(a) and not a._in_scena \
				and str(a.mestiere) not in ["altalena", "dorme"]:
			liberi.append(a)
	if liberi.size() < 2:
		return
	var quale: String = REGIA.scenetta(_clima, liberi.size(), _rng)
	if quale == "":
		return
	liberi.shuffle()
	var quanti: int = int(REGIA.SCENETTE[quale]["attori"])
	var cast: Array = liberi.slice(0, quanti)
	for a in cast:
		a.entra_in_scena()
	_scena = {"nome": quale, "cast": cast, "t": 0.0, "battuta": 0}


## LA SCENETTA, battuta per battuta. Ognuna ha lo stesso scheletro —
## avvicinarsi, il gesto, il congedo — e cambia in mezzo. Il tempo non è
## uguale per tutte: la consolazione è lenta, la risata è veloce.
func _avanza_scena(delta: float) -> void:
	if _scena.is_empty():
		return
	var cast: Array = _scena["cast"]
	for a in cast:
		if not is_instance_valid(a):
			_chiudi_scena()
			return
	_scena["t"] = float(_scena["t"]) + delta
	var t: float = _scena["t"]
	var a0: Node3D = cast[0]
	var a1: Node3D = cast[1]

	match str(_scena["nome"]):
		"incontro":
			# si vanno incontro, si guardano, si salutano e ognuno per sé
			if t < 4.5:
				a0.raggiungi(a1, 1.0, delta)
				a1.rivolgiti(a0, delta)
			elif _battuta(0):
				a0.nuvoletta("♪")
				a1.saltella(0.7)
			elif t > 6.6:
				_chiudi_scena()
		"fiore":
			# uno raccoglie qualcosa e lo porge; l'altro fa un saltello
			if t < 4.2:
				a0.raggiungi(a1, 0.9, delta)
				a1.rivolgiti(a0, delta)
			elif _battuta(0):
				a0.nuvoletta("✿")
			elif t > 5.6 and _battuta(1):
				a1.nuvoletta("♥")
				a1.saltella(1.0)
			elif t > 7.4:
				_chiudi_scena()
		"risata":
			if t < 3.4:
				a0.raggiungi(a1, 1.05, delta)
				a1.rivolgiti(a0, delta)
			elif _battuta(0):
				a0.nuvoletta("!")
			elif t > 4.4 and _battuta(1):
				a0.saltella(0.9)
				a1.saltella(1.1)
				a1.nuvoletta("♪")
			elif t > 6.2:
				_chiudi_scena()
		"consolazione":
			# LA SCENETTA DEI GIORNI STORTI. Nessuna nuvoletta, nessun
			# saltello: uno arriva, si siede accanto all'altro, e restano
			# lì. È il gesto che il gioco ha imparato dal lutto — accanto,
			# e basta.
			if t < 6.0:
				a0.raggiungi(a1, 0.72, delta)
			else:
				a0.rivolgiti(a1, delta)
				a1.rivolgiti(a0, delta)
			if t > 11.0:
				_chiudi_scena()
		"girotondo":
			# tre che girano piano attorno all'albero, vicini
			var centro: Vector3 = ALBERO_POS
			for i in cast.size():
				var ang := t * 0.75 + TAU * float(i) / float(cast.size())
				var d := _albero_cr * 0.55 + 1.15
				var attore: Node3D = cast[i]
				attore._vai_verso(centro + Vector3(cos(ang) * d, 0, sin(ang) * d),
						1.35, delta)
			if _battuta(0):
				for a in cast:
					a.nuvoletta("♪")
			if t > 12.0:
				_chiudi_scena()
		_:
			_chiudi_scena()


## Una battuta scatta UNA volta sola: `_scena["battuta"]` è il contatore.
func _battuta(indice: int) -> bool:
	if int(_scena.get("battuta", 0)) != indice:
		return false
	_scena["battuta"] = indice + 1
	return true


func _chiudi_scena() -> void:
	for a in (_scena.get("cast", []) as Array):
		if is_instance_valid(a):
			a.esci_di_scena()
	_scena = {}


# --------------------------------------------------------- gli ospiti

## Qualcosa attraversa la scena, e tutti la seguono con gli occhi.
func _fai_entrare(chi: String) -> void:
	_ospite_t = 0.0
	_ospite = Node3D.new()
	add_child(_ospite)
	var corpo := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	if chi == "stella":
		var q := QuadMesh.new()
		q.size = Vector2(0.5, 0.06)
		corpo.mesh = q
		mat.albedo_color = Color(1.0, 0.97, 0.86, 0.95)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.95, 0.8)
		mat.emission_energy_multiplier = 3.0
	else:
		var q2 := QuadMesh.new()
		q2.size = Vector2(0.16, 0.13)
		corpo.mesh = q2
		mat.albedo_color = Color(1.0, 0.85, 0.35, 0.95)
	corpo.material_override = mat
	_ospite.add_child(corpo)
	_ospite.set_meta("chi", chi)


func _avanza_ospite(delta: float) -> void:
	if _ospite == null or not is_instance_valid(_ospite):
		return
	_ospite_t += delta
	var chi := str(_ospite.get_meta("chi", "farfalla"))
	var durata := 3.2 if chi == "stella" else 11.0
	var q: float = _ospite_t / durata
	if q >= 1.0:
		_ospite.queue_free()
		_ospite = null
		return
	if chi == "stella":
		# una cadente: entra alta a destra ed esce bassa a sinistra
		_ospite.global_position = ALBERO_POS + Vector3(9.0, 11.0, -6.0).lerp(
				Vector3(-7.0, 4.5, -3.0), q)
		_ospite.look_at(_cam_base, Vector3.UP)
		_ospite.rotate_object_local(Vector3.FORWARD, -0.5)
	else:
		# una farfalla: attraversa a zig-zag, all'altezza degli occhi
		var x := lerpf(6.5, -4.5, q)
		_ospite.global_position = ALBERO_POS + Vector3(x,
				1.05 + sin(_ospite_t * 2.3) * 0.35 + sin(_ospite_t * 0.7) * 0.2,
				1.2 + cos(_ospite_t * 1.1) * 0.9)
	# E TUTTI LA GUARDANO. È il gesto che fa più «vivo» per meno lavoro:
	# la testa segue, il corpo no.
	for a in _attori:
		if is_instance_valid(a) and str(a.mestiere) != "dorme":
			a.segui_con_lo_sguardo(_ospite.global_position, delta)


## A chi si mette a rincorrere serve qualcuno che scappi.
func _accoppia_rincorsa(chi: Node3D) -> void:
	for b in _attori:
		if b == chi or not is_instance_valid(b) or b._in_scena:
			continue
		if str(b.mestiere) in ["rincorre", "scappa"]:
			continue
		b.cambia_mestiere("scappa")
		b.compagno = chi
		chi.compagno = b
		return
	chi.cambia_mestiere("gioca")   # nessuno disponibile: si gioca da soli


# ================================================================ diorama
func _build_world() -> void:
	# --- cielo e luce da golden hour ---
	# LA LUCE VIENE DALL'ORA VERA di chi gioca, e il clima ci si posa
	# sopra: sei momenti per sette climi fanno quarantadue mattine
	# diverse, e nessuna è stata disegnata a mano.
	_rng.seed = REGIA.semina()
	var c := ORA.con_clima(ORA.palette(ORA.momento_ora()), _clima)
	_palette = c
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = c["top"]
	sky_mat.sky_horizon_color = c["orizz"]
	sky_mat.ground_horizon_color = (c["orizz"] as Color).darkened(0.22)
	sky_mat.ground_bottom_color = c["terra"]
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = c["amb"]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.14
	env.glow_bloom = 0.15
	env.fog_enabled = true
	env.fog_light_color = (c["orizz"] as Color).lerp(Color(1, 1, 1), 0.15)
	env.fog_density = c["nebbia"]
	env.adjustment_enabled = true
	# LA SATURAZIONE È IL LUTTO. Non si spegne la luce (un menù al buio è
	# rotto, non triste): si toglie il COLORE al mondo. È quello che fa
	# davvero una giornata in cui è successo qualcosa — le cose ci sono
	# tutte, e nessuna ha più il suo colore.
	env.adjustment_saturation = c["sat"]
	env.adjustment_contrast = 1.10
	var we := WorldEnvironment.new()
	we.environment = env
	_env = env
	add_child(we)

	_sole = DirectionalLight3D.new()
	_sole.rotation = Vector3(deg_to_rad(float(c["angolo"])), deg_to_rad(float(c["yaw"])), 0.0)
	_sole.light_color = c["sole"]
	_sole.light_energy = c["energia"]
	_sole.light_angular_distance = 1.5
	_sole.shadow_enabled = true
	_sole.shadow_blur = 1.2
	add_child(_sole)

	# --- prato ---
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.53, 0.67, 0.42)
	gmat.roughness = 1.0
	ground.material_override = gmat
	add_child(ground)

	# --- IL GRANDE ALBERO VERO, alla taglia di QUESTO salvataggio ---
	# Non un albero decorativo: la stessa geometria del villaggio
	# (AlberoGeo), cresciuta ai giorni che hai giocato. Chi apre il menù al
	# giorno 40 lo trova gigante; chi ha appena cominciato trova un
	# alberello. È la prima cosa che dice «questo è il TUO villaggio».
	var tree := Node3D.new()
	tree.position = ALBERO_POS
	add_child(tree)
	var fatto: Dictionary = ALBERO.costruisci(tree, float(_save.stage_albero()),
			ALBERO.materiali(int(_save.stagione)), 7)
	_altalena = fatto["swing"]
	_albero_h = float(fatto["h"])
	_albero_cr = float(fatto["cr"])

	# LO STACCO DELLA CAMERA si calcola QUI, prima di popolare: i vicini
	# devono sapere dove sta chi guarda per girarsi da quella parte.
	# `var` e non `:=`: _save non e' tipizzato, l'inferenza fallirebbe
	var st: float = _save.stage_albero()
	_cam_base = ALBERO_POS + Vector3(3.1 + 1.6 * st, 1.35 + 0.85 * st, 4.6 + 4.0 * st)
	_look = ALBERO_POS + Vector3(0.75 + 0.55 * st, 0.70 + 0.62 * st, 0.5)


	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# i fiori del prato: tanti quanto è vivo il villaggio (nel lutto ne
	# restano pochi, e non è che appassiscono — è che non li guarda nessuno)
	var quanti_fiori := int(lerpf(7.0, 26.0, float(_save.vivacita())))
	for i in quanti_fiori:
		var a := rng.randf() * TAU
		var d := rng.randf_range(1.2, 6.0)
		var f := _make_flower([Color("ff9ec0"), Color("ffe6a8"), Color("cdbff0"), Color("bfe6c8")][rng.randi() % 4])
		f.position = ALBERO_POS + Vector3(cos(a) * d, 0, sin(a) * d)
		f.rotation.y = rng.randf() * TAU
		add_child(f)

	# --- Mochi, sotto l'albero ---
	var mochi_scene: PackedScene = load("res://scenes/characters/Mochi.tscn")
	if mochi_scene:
		_mochi = mochi_scene.instantiate() as Node3D
		_mochi.position = ALBERO_POS + Vector3(1.15, 0.0, 1.55)
		# VERSO CHI GUARDA. La faccia di Mochi punta a -Z (è la convenzione
		# del suo modello, diversa da quella dei chibi di ChibiBuilder che
		# guardano a +Z): girarla come loro la lasciava di spalle, ed era
		# la protagonista del menù ripresa da dietro.
		var d := _cam_base - _mochi.position
		_mochi.rotation.y = atan2(d.x, d.z) + PI
		_mochi.scale = Vector3(0.95, 0.95, 0.95)
		add_child(_mochi)
		_posa_mochi.call_deferred()

	# --- di notte, le lucciole ---
	_lucciole()

	# --- e i vicini: quelli VERI del salvataggio ---
	_popola_diorama()

	# --- camera ---
	# L'INQUADRATURA SEGUE L'ALBERO. Prima era fissa, tarata su un
	# alberello decorativo alto tre metri: col Grande Albero vero, che al
	# giorno quaranta ne fa quasi sette, la camera finiva DENTRO il tronco
	# e il menù era una parete di corteccia.
	#
	# Adesso lo stacco cresce con l'albero, ma meno di lui: un albero
	# grande deve SEMBRARE grande (esce un po' dall'inquadratura, e va
	# bene), un alberello ci sta tutto. E il tronco sta sulla destra: il
	# terzo sinistro dello schermo è dei pulsanti, e lì non ci va niente.
	_cam = Camera3D.new()
	_cam.position = _cam_base
	_cam.fov = 46.0
	_cam.attributes = _dof()
	add_child(_cam)
	_cam.look_at(_look, Vector3.UP)


# ======================================================= il diorama vivo

## I VICINI VERI, e cosa stanno facendo.
##
## Si prendono dal salvataggio quelli con cui hai legato di più, e a
## ognuno si dà un MESTIERE secondo il clima. La distribuzione non è
## casuale: è una piccola regia. Nei giorni buoni ci vuole una coppia che
## si rincorre (è quella a dire «vivo» in mezzo secondo di sguardo), uno
## seduto, e il resto sparso; nel lutto NON si rincorre nessuno — si
## siedono vicini, e basta.
func _popola_diorama() -> void:
	var scelti: Array = _vicini_da_mostrare()
	if scelti.is_empty():
		return
	var mestieri := _mestieri_per(_clima, scelti.size())
	# …e poi si mescola quel che si può: la regia garantisce la coppia
	# della rincorsa, ma CHI la fa cambia a ogni avvio
	mestieri = _rimescola(mestieri, _rng)
	# OGNI AVVIO E' DIVERSO: la semina viene dal tempo vero, quindi chi
	# fa cosa e dove cambia a ogni apertura. (L'ALBERO no: quello ha la
	# sua semina fissa — e' IL tuo albero, non deve rifarsi la chioma
	# ogni volta che apri il gioco.)
	var rng := _rng
	var rincorsa: Array[Node3D] = []
	for i in scelti.size():
		var riga: Dictionary = scelti[i]
		var a := ATTORE.new()
		a.name = "Vicino%d" % i
		a.perno = ALBERO_POS
		a.vivacita = float(_save.vivacita())
		a.verso_camera = _cam_base
		a.mestiere = str(mestieri[i])
		# gli anziani si portano gli anni addosso anche qui: gobba,
		# orecchie basse, passo posato (lo stesso canale del villaggio)
		a.eta = clampf(float(riga.get("eta", 0.0)), 0.0, 1.0)
		add_child(a)
		a.costruisci(riga["dna"], 900 + i * 37)
		a.raggio = _raggio_per(str(mestieri[i]), i, rng)
		a.global_position = _posto_per(str(mestieri[i]), i, a.raggio, rng)
		if str(mestieri[i]) == "altalena" and _altalena:
			a.usa_altalena(_altalena)
		if str(mestieri[i]) in ["rincorre", "scappa"]:
			rincorsa.append(a)
		# ognuno parte col suo orologio: i mestieri non scadono in coro
		a.cambia_mestiere(str(mestieri[i]))
		_attori.append(a)
	# la coppia si guarda: chi insegue ha bisogno di sapere chi scappa
	if rincorsa.size() == 2:
		rincorsa[0].compagno = rincorsa[1]
		rincorsa[1].compagno = rincorsa[0]


## Chi entra in scena: i più cari per primi. Con più di MAX_ATTORI
## residenti gli altri restano fuori — non è una perdita, è
## un'inquadratura (e chi manca lo ritrovi premendo Continua).
func _vicini_da_mostrare() -> Array:
	var tutti: Array = (_save.residenti as Array).duplicate()
	tutti.sort_custom(func(a, b):
		return int(a.get("amicizia", 0)) > int(b.get("amicizia", 0)))
	return tutti.slice(0, MAX_ATTORI)


## LA REGIA DEI MESTIERI. Quali, e in che ordine, per ogni clima.
## PURA e testabile: è la funzione che decide che faccia ha il menù.
static func _mestieri_per(clima: String, quanti: int) -> Array:
	if quanti <= 0:
		return []
	var ordine: Array = []
	match clima:
		"lutto":
			# nessuno gioca. Si sta insieme e si sta zitti — e uno,
			# ogni tanto, guarda in su.
			ordine = ["veglia", "veglia", "veglia", "guarda_in_su",
					"veglia", "veglia", "veglia"]
		"commiato":
			ordine = ["guarda_in_su", "seduto", "veglia", "annusa",
					"seduto", "guarda_in_su", "seduto"]
		"malinconia":
			ordine = ["seduto", "annusa", "guarda_in_su", "dorme",
					"seduto", "gioca", "seduto"]
		"attesa":
			ordine = ["seduto", "annusa", "gioca", "dorme",
					"seduto", "gioca", "annusa"]
		"armonia":
			# il villaggio pieno: si rincorrono, c'è chi dondola,
			# c'è chi saluta te
			ordine = ["rincorre", "scappa", "altalena", "gioca",
					"saluta", "annusa", "seduto"]
		"allegria":
			ordine = ["rincorre", "scappa", "gioca", "seduto",
					"altalena", "annusa", "dorme"]
		_:
			ordine = ["gioca", "seduto", "annusa", "altalena",
					"dorme", "gioca", "seduto"]
	var out: Array = []
	for i in quanti:
		out.append(ordine[i % ordine.size()])
	# UNA RINCORSA SI FA IN DUE. Con un solo vicino, «rincorre» sarebbe
	# uno che gira intorno all'albero da solo — che è tutta un'altra
	# faccenda, e neanche allegra.
	if out.count("rincorre") != out.count("scappa"):
		for i in out.size():
			if out[i] in ["rincorre", "scappa"]:
				out[i] = "gioca"
	return out


## Rimescola l'assegnazione tenendo insieme la coppia della rincorsa: chi
## insegue e chi scappa devono restare due, ma non devono essere sempre
## gli stessi due (né sempre i primi della lista).
static func _rimescola(mestieri: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = mestieri.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp: Variant = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


func _raggio_per(mestiere: String, i: int, rng: RandomNumberGenerator) -> float:
	match mestiere:
		"rincorre", "scappa":
			return _albero_cr * 0.9 + 0.6
		"gioca":
			return _albero_cr * 0.7 + rng.randf_range(0.3, 1.0)
		_:
			return _albero_cr * 0.55 + 0.8 + float(i) * 0.22


## Dove si mette ognuno. Nel lutto si stringono: il cerchio è più piccolo
## e più fitto, e stanno tutti sullo stesso lato — vicini per davvero.
func _posto_per(mestiere: String, i: int, raggio: float,
		rng: RandomNumberGenerator) -> Vector3:
	if _clima == "lutto" or mestiere == "veglia":
		var ang := -0.55 + float(i) * 0.30
		var d := _albero_cr * 0.5 + 0.9 + rng.randf_range(-0.15, 0.15)
		return ALBERO_POS + Vector3(cos(ang) * d, 0, sin(ang) * d + 0.6)
	var a := rng.randf() * TAU
	return ALBERO_POS + Vector3(cos(a) * raggio, 0, sin(a) * raggio)


## LA POSA DI MOCHI. È lei il centro del menù, e deve essere lei la prima
## cosa che tradisce come sta il villaggio: seduta e contenta nei giorni
## normali, in piedi e allegra quando c'è festa, raggomitolata e con lo
## sguardo basso nel lutto.
func _posa_mochi() -> void:
	if _mochi == null or not is_instance_valid(_mochi):
		return
	match _clima:
		"lutto":
			_mochi.call("set_pose", "sit")
			_mochi.call("forza_espressione", "triste", 0.85)
			_mochi.call("set_tired", true)
		"commiato", "malinconia":
			_mochi.call("set_pose", "sit")
			_mochi.call("forza_espressione", "triste", 0.45)
		"armonia":
			_mochi.call("set_pose", "stand")
			_mochi.call("forza_espressione", "raggiante", 1.0)
		"allegria":
			_mochi.call("set_pose", "stand")
			_mochi.call("forza_espressione", "felice", 0.9)
		_:
			_mochi.call("set_pose", "sit")
			_mochi.call("forza_espressione", "felice", 0.6)


## IL CIELO CHE SENTE. Colori, luce e nebbia del clima. La golden hour
## resta la casa del gioco: gli altri climi la piegano, non la sostituiscono
## (un menù che diventa un altro gioco quando sei triste è un menù che ti
## sta dicendo «adesso sei nella modalità triste»).
static func clima_cielo(clima: String) -> Dictionary:
	match clima:
		"lutto":
			return {"top": Color(0.40, 0.44, 0.54), "orizz": Color(0.72, 0.71, 0.74),
					"terra": Color(0.50, 0.50, 0.52), "sole": Color(0.80, 0.80, 0.86),
					"energia": 0.70, "amb": 0.34, "sat": 0.55, "nebbia": 0.020,
					"petali": 0}
		"commiato":
			return {"top": Color(0.46, 0.50, 0.68), "orizz": Color(0.93, 0.67, 0.55),
					"terra": Color(0.66, 0.56, 0.52), "sole": Color(1.0, 0.72, 0.55),
					"energia": 1.00, "amb": 0.38, "sat": 0.88, "nebbia": 0.011,
					"petali": 10}
		"malinconia":
			return {"top": Color(0.44, 0.53, 0.72), "orizz": Color(0.86, 0.72, 0.64),
					"terra": Color(0.60, 0.55, 0.50), "sole": Color(0.98, 0.80, 0.68),
					"energia": 1.05, "amb": 0.40, "sat": 0.82, "nebbia": 0.009,
					"petali": 16}
		"armonia":
			return {"top": Color(0.33, 0.52, 0.84), "orizz": Color(0.97, 0.74, 0.50),
					"terra": Color(0.66, 0.54, 0.46), "sole": Color(1.0, 0.84, 0.62),
					"energia": 1.30, "amb": 0.46, "sat": 1.22, "nebbia": 0.005,
					"petali": 46}
		"allegria":
			return {"top": Color(0.35, 0.51, 0.82), "orizz": Color(0.96, 0.73, 0.50),
					"terra": Color(0.64, 0.52, 0.45), "sole": Color(1.0, 0.83, 0.61),
					"energia": 1.26, "amb": 0.45, "sat": 1.18, "nebbia": 0.006,
					"petali": 36}
		_:
			return {"top": Color(0.35, 0.50, 0.80), "orizz": Color(0.95, 0.72, 0.49),
					"terra": Color(0.62, 0.50, 0.44), "sole": Color(1.0, 0.82, 0.60),
					"energia": 1.22, "amb": 0.44, "sat": 1.15, "nebbia": 0.006,
					"petali": 26}


func _dof() -> CameraAttributesPractical:
	var a := CameraAttributesPractical.new()
	a.dof_blur_far_enabled = true
	a.dof_blur_far_distance = 9.0
	a.dof_blur_far_transition = 5.0
	a.dof_blur_amount = 0.08
	return a


# un albero decorativo: tronco svasato, chioma a grappoli, due fioriture rosa
func _make_tree() -> Node3D:
	var n := Node3D.new()
	var bark := _sm(Color("9a6b4f"))
	var leaf := _sm(Color("7fbc62"))
	var leaf_d := _sm(Color("5f9c48"))
	var blossom := _sm(Color("f6b8ce"))

	var trunk := _cyl(0.42, 0.68, 3.4, bark)
	trunk.position = Vector3(0, 1.7, 0)
	n.add_child(trunk)
	for i in 5:
		var ang := float(i) / 5.0 * TAU + 0.3
		var root := _cyl(0.1, 0.22, 0.9, bark)
		root.position = Vector3(cos(ang) * 0.55, 0.2, sin(ang) * 0.55)
		root.rotation = Vector3(cos(ang) * 0.6, 0, sin(ang) * 0.6)
		n.add_child(root)
	for i in 3:
		var ang := float(i) / 3.0 * TAU
		var branch := _cyl(0.1, 0.18, 1.6, bark)
		branch.position = Vector3(cos(ang) * 0.5, 3.2, sin(ang) * 0.5)
		branch.rotation = Vector3(0, -ang, 0.9)
		n.add_child(branch)

	# chioma: grappolo di sfere
	var canopy := [
		[Vector3(0, 4.3, 0), 2.1, leaf], [Vector3(1.6, 3.9, 0.4), 1.5, leaf_d],
		[Vector3(-1.5, 4.0, -0.5), 1.6, leaf], [Vector3(0.2, 4.2, -1.6), 1.4, leaf_d],
		[Vector3(-0.3, 5.1, 0.6), 1.5, leaf], [Vector3(1.0, 4.6, 1.2), 1.2, leaf_d],
	]
	for c in canopy:
		var s := _ball((c[1] as float), c[2])
		s.position = c[0]
		n.add_child(s)
	for bp in [Vector3(1.2, 4.4, 0.9), Vector3(-1.0, 4.5, -0.2), Vector3(0.1, 5.3, 0.3)]:
		var b := _ball(0.7, blossom)
		b.position = bp
		n.add_child(b)
	return n


func _make_flower(col: Color) -> Node3D:
	var n := Node3D.new()
	var stem := _cyl(0.015, 0.015, 0.22, _sm(Color("6fae52")))
	stem.position = Vector3(0, 0.11, 0)
	n.add_child(stem)
	for i in 5:
		var a := float(i) / 5.0 * TAU
		var petal := _ball(0.05, _sm(col))
		petal.position = Vector3(cos(a) * 0.06, 0.24, sin(a) * 0.06)
		petal.scale = Vector3(1, 0.5, 1)
		n.add_child(petal)
	var heart := _ball(0.04, _sm(Color("ffe08a")))
	heart.position = Vector3(0, 0.25, 0)
	n.add_child(heart)
	return n


func _sm(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _cyl(top: float, bottom: float, h: float, mat: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	return mi


func _ball(r: float, mat: Material) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	return mi


# ================================================================ UI
func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	# i petali contano il clima: quaranta nei giorni pieni, zero nel lutto
	var quanti := int(_palette.get("petali", 26))
	if quanti > 0:
		_ui.add_child(CozyUI.petals(quanti, false))

	_menu = _build_menu()
	_ui.add_child(_menu)

	_settings = CozySettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(_close_settings)
	var scenter := CozyUI.center_root()
	scenter.name = "SettingsCenter"
	scenter.visible = false
	scenter.add_child(_settings)
	_ui.add_child(scenter)

	CozyUI.appear(_menu, 0.6)


func _build_menu() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = 90.0
	box.offset_top = -170.0
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(box)

	var title := Label.new()
	title.text = "Chibi Crossing"
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_color_override("font_color", Color("fff3e0"))
	title.add_theme_color_override("font_shadow_color", Color(0.35, 0.2, 0.15, 0.55))
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_constant_override("shadow_offset_x", 2)
	box.add_child(title)

	var sub := Label.new()
	sub.text = L10n.t(str(_save.sottotitolo()))
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color("fff3e0"))
	sub.add_theme_color_override("font_shadow_color", Color(0.35, 0.2, 0.15, 0.5))
	sub.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 22)
	box.add_child(gap)

	if FileAccess.file_exists(SAVE_PATH):
		box.add_child(_title_button(L10n.t("Continua"), CozyUI.MINT, _continue))
		box.add_child(_title_button(L10n.t("Nuovo villaggio"), CozyUI.PINK, _ask_new))
	else:
		box.add_child(_title_button(L10n.t("Nuovo villaggio"), CozyUI.MINT, _start_new))
	box.add_child(_title_button(L10n.t("Impostazioni"), CozyUI.SKY, _open_settings))
	box.add_child(_title_button(L10n.t("Esci"), CozyUI.HONEY, func(): get_tree().quit()))
	return root


func _title_button(text: String, accent: Color, cb: Callable) -> Button:
	var b := CozyUI.cozy_button(text, accent, 22)
	b.custom_minimum_size = Vector2(340, 60)
	b.pressed.connect(cb)
	return b


# ---------------------------------------------------------------- azioni
func _continue() -> void:
	_enter()


func _start_new() -> void:
	# il vecchio villaggio NON si cancella: si archivia con data e ora.
	# Con l'investimento emotivo del Filo Rosso, un "Nuovo villaggio" per
	# sbaglio non deve costare una storia intera — per tornare indietro
	# basta rinominare l'archivio in village.json.
	# SI ARCHIVIA ANCHE LA COPIA .bak, e non per pignoleria: lasciata lì,
	# il villaggio nuovo la ripescava e resuscitava il vecchio (il
	# caricamento non distingueva "manca" da "è rotto"). Adesso la
	# distinzione c'è in BuildSystem, e questa è la seconda cintura.
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.rename_absolute(SAVE_PATH, "user://village_%s.json" % stamp)
	if FileAccess.file_exists(SAVE_PATH + ".bak"):
		DirAccess.rename_absolute(SAVE_PATH + ".bak",
				"user://village_%s.json.bak" % stamp)
	# GLI ALTRI DEPOSITI. Il villaggio non vive tutto dentro village.json:
	# tre cose si salvano per conto loro, e restavano in piedi nel
	# villaggio nuovo — le cornici sopra letti che non esistono più e i
	# sentieri consumati dai passi di un'altra storia.
	# Si ARCHIVIANO con lo stesso timbro del villaggio (mai cancellati:
	# «una storia non si butta» — e chi rinomina l'archivio indietro se
	# li ritrova tutti insieme, coerenti fra loro).
	for deposito: String in ["user://foto_ricordi.json",
			"user://sentieri_consumati.png"]:
		if FileAccess.file_exists(deposito):
			var pezzi := deposito.trim_prefix("user://").split(".")
			DirAccess.rename_absolute(deposito,
					"user://%s_%s.%s" % [pezzi[0], stamp, pezzi[1]])
	# anche il rullino del timelapse riparte: senza, il "film" del villaggio
	# nuovo proietterebbe le foto del vecchio (e capture() salta i giorni
	# i cui PNG esistono già). L'album personale user://photos resta.
	var dir := DirAccess.open("user://ricordi")
	if dir:
		for f in dir.get_files():
			dir.remove(f)
	# gli appunti del vecchio Prologo se ne vanno con lui: il villaggio
	# nuovo avrà la SUA notte, e non deve ereditare le lettere di un'altra
	if FileAccess.file_exists(PROLOGO_APPUNTI):
		DirAccess.rename_absolute(PROLOGO_APPUNTI, "user://prologo_%s.json" % stamp)
	get_tree().change_scene_to_file(PROLOGO_SCENE)


func _enter() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)


func _ask_new() -> void:
	if _confirm and is_instance_valid(_confirm):
		return
	_confirm = _build_confirm()
	_ui.add_child(_confirm)
	CozyUI.fade_to(_confirm, 0.5, 0.25)   # dopo l'add_child: il tween ha l'albero
	CozyUI.appear(_confirm, 0.3)


func _build_confirm() -> Control:
	var dim := CozyUI.backdrop()
	var center := CozyUI.center_root()
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CozyUI.paper_panel(26))
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	col.add_child(CozyUI.title_label(L10n.t("Ricominciare da capo?"), 26))
	col.add_child(CozyUI.hint_label(L10n.t(
		"Il villaggio attuale sarà sostituito da uno nuovo.\nQuesta scelta non si può annullare."), 15))
	var rowc := HBoxContainer.new()
	rowc.add_theme_constant_override("separation", 12)
	rowc.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(rowc)
	var no := CozyUI.cozy_button(L10n.t("Annulla"), CozyUI.MINT, 18)
	no.custom_minimum_size = Vector2(180, 52)
	no.pressed.connect(_close_confirm)
	rowc.add_child(no)
	var yes := CozyUI.cozy_button(L10n.t("Nuovo villaggio"), CozyUI.DANGER, 18)
	yes.custom_minimum_size = Vector2(200, 52)
	yes.pressed.connect(_start_new)
	rowc.add_child(yes)
	return dim


func _close_confirm() -> void:
	if _confirm and is_instance_valid(_confirm):
		_confirm.queue_free()
		_confirm = null
	if _sfx: _sfx.build_close()


func _open_settings() -> void:
	_menu.visible = false
	var sc := _ui.get_node_or_null("SettingsCenter")
	if sc:
		sc.visible = true
	CozyUI.appear(_settings, 0.34)


func _close_settings() -> void:
	var sc := _ui.get_node_or_null("SettingsCenter")
	if sc:
		sc.visible = false
	_menu.visible = true
	CozyUI.appear(_menu, 0.34)
