extends Node3D

## IL PROLOGO — la notte in cui sei arrivata.
##
## Tre minuti, una radura, un temporale. Sei una cucciola e non sai ancora
## dove sei. Non c'è una scritta che ti dice i comandi, non c'è un
## obiettivo, non c'è niente da raccogliere: c'è l'acqua che viene giù, una
## foglia grande abbastanza da starci sotto, e a un certo punto qualcosa
## che si muove nell'erba alta.
##
## QUELLO CHE IL GIOCO NON DICE. Mentre giochi, prende appunti (Taccuino):
## se ti sei riparata o sei rimasta sotto l'acqua, se sei andata a vedere
## cos'era quel rigonfiamento o hai fatto un passo indietro, se sei stata
## ferma a guardare. Nessuna di queste è una scelta annunciata — non c'è un
## bivio, non c'è un tasto, non c'è niente di evidenziato. E proprio per
## questo quello che fai è quello che faresti.
##
## Poi il temporale passa, e comincia il gioco vero. E la prima lettera che
## trovi nella cassetta te li recita, quei tre minuti. Nel frattempo hanno
## già fatto due cose che non ti ha detto nessuno: i contatori del Regista
## sono partiti inclinati (i vicini si comporteranno un po' di conseguenza
## fin dal primo giorno) e Mochi si porta dietro un marchio vero del
## Limbico su quel temporale — trasalirà alle prime gocce, per mesi, finché
## non ci sarai stata sotto abbastanza volte senza che succeda niente.
##
## Il Prologo NON usa il PlayerController C++: ha un suo corpo e una sua
## camera, venti righe in tutto. Sono tre minuti con altre regole (non si
## costruisce, non si salta, non c'è HUD), e tenerli separati vuol dire che
## il villaggio non deve sapere che esistono.

const GEO := preload("res://scenes/world/WorldGeo.gd")
const MOCHI := preload("res://scenes/characters/Mochi.tscn")
const TACCUINO := preload("res://scenes/prologo/Taccuino.gd")
const LIVELLO := "res://scenes/levels/MainLevel.tscn"

## Dove il Prologo lascia i suoi appunti perché il villaggio li trovi.
const APPUNTI := "user://prologo.json"

# --- la sceneggiatura, in secondi ---
## Il buio iniziale, prima che il primo lampo faccia vedere dove sei.
const T_BUIO := 2.6
## Quando le si restituisce il corpo (prima si sta solo rannicchiati).
const T_CONTROLLO := 5.2
## Quando l'erba si muove per la prima volta. Tardi apposta: la faccenda
## del riparo deve poter succedere PRIMA, o le due domande si accavallano
## e l'appunto non vale niente.
const T_ERBA := 34.0
## Quando il temporale comincia a mollare.
const T_CALA := 104.0
## Quando finisce.
const T_FINE := 128.0

## Dove sta la camera rispetto a lei, e dove guarda. Bassa e vicina: una
## cucciola alta un palmo ripresa da tre metri è un puntino in mezzo a un
## prato vuoto, e il prato vuoto non commuove nessuno.
const CAM_STACCO := Vector3(0, 1.28, 2.10)
const CAM_MIRA := Vector3(0, 0.30, 0)
## E come si mette quando è al riparo: un passo indietro e lo sguardo in
## su, per far entrare la volta di foglia dal bordo alto.
const CAM_STACCO_RIPARO := Vector3(0, 1.05, 2.75)
const CAM_MIRA_RIPARO := Vector3(0, 0.92, 0)

const RAGGIO := 7.4          # la radura
const FOGLIA := Vector3(-3.05, 0, -1.5)
const ERBA := Vector3(3.35, 0, 1.15)
const RIPARO_R := 1.55       # sotto la foglia si sta asciutti fin qui
## Dove sta il centro dell'asciutto: SPOSTATO rispetto al gambo, così ci
## si ripara sotto la sporgenza e non abbracciati al palo.
const RIPARO_OFF := Vector3(0.62, 0, 0.72)
## Quanto è alta la foglia. Sopra la camera (1.28) — se no, entrandoci
## sotto, il lembo riempie lo schermo come un muro nero — ma non tanto da
## uscire dall'inquadratura: a due metri e dieci l'orlo cade dentro il
## bordo alto e si vede di essere SOTTO qualcosa. È il punto in cui il
## riparo si legge senza che nessuno lo dica.
const FOGLIA_H := 2.10
const NASO_R := 1.05         # più vicino di così al rigonfiamento è «addosso»
## Quanto è grande chi sta sotto l'erba. PICCOLO: più piccolo di lei, che
## è già piccola. È metà del motivo per cui avvicinarsi commuove — a
## dimensione uguale sarebbe stato un incontro, così è qualcuno da cui
## non c'è niente da temere e che sta peggio di te.
const RICCIO_R := 0.155
const RICCIO_Y := 0.135      # a che quota gli sta il centro, camminando

# LA NOTTE NON È IL NERO. Un temporale reso «realisticamente buio» è una
# schermata nera con dentro dei puntini: non fa paura, non fa niente, non
# si vede. La notte di questo Prologo è BLU — cupa quanto serve a capire
# che è notte e che piove, e leggibile in ogni angolo. L'unica cosa calda
# dell'inquadratura è lei, ed è per quello che la si guarda.
const CIELO_BUIO := Color(0.085, 0.105, 0.175)
const ERBA_SCURA := Color(0.115, 0.185, 0.165)
const ERBA_BAGNATA := Color(0.175, 0.275, 0.225)

var _taccuino: RefCounted
var _corpo: CharacterBody3D
var _mochi: Node3D
var _cam: Camera3D
var _sfx

var _t := 0.0
var _giocabile := false
var _rannicchiata := false
var _finito := false

var _pioggia: GPUParticles3D
var _schizzi: GPUParticles3D
var _tenda: GPUParticles3D          # l'acqua che cola dal bordo della foglia
var _lampo: DirectionalLight3D
var _ambiente: WorldEnvironment
var _cielo: ProceduralSkyMaterial
var _velo: ColorRect                # il buio d'apertura e la dissolvenza finale

var _prossimo_lampo := 1.2
var _flash := 0.0
var _tuoni: Array = []              # [quando, vicino] — il tuono arriva DOPO
var _scossa := 0.0                  # la camera che sussulta
var _vento := 0.0
var _vento_ph := 0.0

var _dosso: Node3D                  # il rigonfiamento nell'erba
var _riccio: Node3D                 # chi c'è sotto
var _dosso_su := 0.0                # 0 = piatto, 1 = sollevato e visibile
var _scoperto := false
var _respiro := 0.0

var _cam_pos := Vector3.ZERO
var _riparo_vista := 0.0            # 0 = fuori, 1 = la camera guarda in su
var _fermo_t := 0.0
var _intensita := 1.0               # la forza del temporale adesso, 0..1


func _ready() -> void:
	_taccuino = TACCUINO.new()
	_sfx = get_node_or_null(^"/root/Sfx")
	_costruisci_cielo()
	_costruisci_radura()
	_costruisci_foglia()
	_costruisci_erba_alta()
	_costruisci_corpo()
	_costruisci_pioggia()
	_costruisci_velo()
	if _sfx:
		_sfx.set_rain(true)
		_sfx.play("tuono_lontano", -10.0, 0.9)


# ================================================================ il mondo

func _costruisci_cielo() -> void:
	_cielo = ProceduralSkyMaterial.new()
	_cielo.sky_top_color = CIELO_BUIO
	_cielo.sky_horizon_color = Color(0.155, 0.185, 0.27)
	_cielo.ground_bottom_color = CIELO_BUIO
	_cielo.ground_horizon_color = Color(0.12, 0.145, 0.215)
	_cielo.sun_angle_max = 1.0
	var sky := Sky.new()
	sky.sky_material = _cielo
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# l'ambiente viene da un colore SCELTO, non dal cielo: col cielo la
	# radura restava nera, e alzare il cielo per illuminarla avrebbe fatto
	# un temporale color pastello
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.52, 0.78)
	# 1.70/1.40/0.70: scelti col provino, non a mente (sei tarature
	# affiancate — sotto si perde il prato nel nero, sopra la radura
	# diventa una laguna di giorno e la notte se ne va)
	env.ambient_light_energy = 1.70
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.10
	env.adjustment_contrast = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.18, 0.22, 0.33)
	env.fog_density = 0.030
	env.fog_sky_affect = 0.5
	_ambiente = WorldEnvironment.new()
	_ambiente.environment = env
	add_child(_ambiente)

	# la luna dietro le nuvole: quel tanto che basta a vedere le sagome
	var luna := DirectionalLight3D.new()
	luna.light_color = Color(0.66, 0.76, 1.0)
	luna.light_energy = 1.40
	luna.rotation_degrees = Vector3(-62, 34, 0)
	luna.shadow_enabled = true
	add_child(luna)

	# IL CONTROLUCE. Una seconda luce fredda dal lato opposto, bassa: non
	# illumina niente, disegna il BORDO. È lei a staccare una gattina color
	# panna dal blu che ha dietro — senza, la sagoma si perde nel fondo e
	# l'inquadratura diventa una macchia.
	var bordo := DirectionalLight3D.new()
	bordo.light_color = Color(0.55, 0.70, 1.0)
	bordo.light_energy = 0.70
	bordo.rotation_degrees = Vector3(-14, -152, 0)
	bordo.shadow_enabled = false
	add_child(bordo)

	# il lampo: spento quasi sempre, e per due decimi di secondo è il sole
	_lampo = DirectionalLight3D.new()
	_lampo.light_color = Color(0.86, 0.92, 1.0)
	_lampo.light_energy = 0.0
	_lampo.rotation_degrees = Vector3(-28, -110, 0)
	_lampo.shadow_enabled = true
	add_child(_lampo)


func _costruisci_radura() -> void:
	# il prato: un disco leggermente bombato, scuro e lucido di pioggia
	var suolo := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = RAGGIO + 3.0
	disco.bottom_radius = RAGGIO + 3.0
	disco.height = 0.4
	disco.radial_segments = 48
	suolo.mesh = disco
	suolo.position.y = -0.2
	var mat := GEO.paint_mat(ERBA_SCURA, ERBA_BAGNATA, 7.0, 0.5, 0.0, true)
	# bagnato: l'erba di notte sotto l'acqua non è opaca, RIFLETTE
	suolo.material_override = mat
	add_child(suolo)

	var pavimento := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 0.4, 40)
	forma.shape = box
	forma.position.y = -0.2
	pavimento.add_child(forma)
	add_child(pavimento)

	# i fili d'erba: un MultiMesh fitto, tutti piegati dallo stesso vento
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = GEO.blade_mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260730
	# fitti: alla scala di una cucciola i fili sono alti quanto lei, e
	# radi sembrano paletti piantati in un campo. Il prato si fa col
	# numero (col provino, a 2600 si contavano uno per uno).
	var fili := 7200
	mm.instance_count = fili
	for i in fili:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (RAGGIO + 2.2)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var tr := Transform3D().rotated(Vector3.UP, rng.randf() * TAU)
		tr = tr.scaled(Vector3.ONE * rng.randf_range(0.55, 1.35))
		mm.set_instance_transform(i, tr.translated(p))
		var v := rng.randf_range(0.75, 1.15)
		mm.set_instance_color(i, Color(ERBA_BAGNATA.r * v, ERBA_BAGNATA.g * v,
				ERBA_BAGNATA.b * v))
	# I FILI vogliono la loro tinta, più chiara del suolo. Col provino si è
	# visto che alla luce giusta per il prato l'erba spariva, e alzare TUTTO
	# per farla tornare trasformava la radura in una laguna di giorno: la
	# luce era giusta, era il verde dei fili a essere quello del terreno.
	var prato := MultiMeshInstance3D.new()
	prato.multimesh = mm
	prato.material_override = GEO.paint_mat(
			ERBA_BAGNATA, ERBA_BAGNATA.lightened(0.22), 5.0, 0.35, 0.9, true)
	prato.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(prato)

	# il muro della radura: cespugli e tronchi tutt'intorno. Non c'è un
	# confine invisibile e non c'è un cartello: c'è del buio fitto, e non
	# viene voglia di andarci.
	for i in 26:
		var a := TAU * float(i) / 26.0 + rng.randf_range(-0.08, 0.08)
		var r := RAGGIO + rng.randf_range(0.9, 2.1)
		var cesp := MeshInstance3D.new()
		var s := rng.randf_range(1.15, 2.35)
		cesp.mesh = GEO.puff_mesh(s, i * 31 + 7, 0.74, 0.14)
		cesp.position = Vector3(cos(a) * r, s * 0.42, sin(a) * r)
		cesp.material_override = GEO.paint_mat(
				ERBA_SCURA.darkened(0.35), ERBA_SCURA, 3.0, 0.5, 0.35, true)
		add_child(cesp)
	for i in 7:
		var a := TAU * float(i) / 7.0 + 0.4
		var r := RAGGIO + rng.randf_range(2.2, 3.4)
		var h := rng.randf_range(4.5, 7.0)
		var albero := MeshInstance3D.new()
		albero.mesh = GEO.trunk_mesh(h, 0.42, 0.19, i * 17 + 3)
		albero.position = Vector3(cos(a) * r, 0, sin(a) * r)
		albero.material_override = GEO.paint_mat(
				Color(0.10, 0.085, 0.09), Color(0.14, 0.12, 0.115), 6.0, 0.5)
		add_child(albero)
		var chioma := MeshInstance3D.new()
		chioma.mesh = GEO.puff_mesh(2.3, i * 71 + 11, 0.7, 0.16)
		chioma.position = Vector3(cos(a) * r, h * 0.92, sin(a) * r)
		chioma.material_override = GEO.paint_mat(
				ERBA_SCURA.darkened(0.5), ERBA_SCURA.darkened(0.15), 3.0, 0.5, 0.5, true)
		add_child(chioma)


## LA FOGLIA. Non è segnata, non brilla, non ha un'icona sopra: è solo la
## cosa più grande della radura, e quando arriva un lampo la si vede tutta.
## Il modo in cui dice «qui sotto non piove» è l'acqua stessa: dal bordo
## cola una tenda continua, e dentro la tenda si sta asciutti. Nessun
## giocatore ha bisogno che glielo si spieghi.
func _costruisci_foglia() -> void:
	var nodo := Node3D.new()
	nodo.position = FOGLIA
	add_child(nodo)

	var gambo := MeshInstance3D.new()
	gambo.mesh = GEO.trunk_mesh(FOGLIA_H, 0.085, 0.05, 909)
	gambo.material_override = GEO.paint_mat(
			Color(0.16, 0.24, 0.15), Color(0.21, 0.32, 0.19), 8.0, 0.4)
	nodo.add_child(gambo)

	# il lembo: una calotta larga e schiacciata, un po' storta come una
	# foglia vera che ha preso vent'anni di pioggia
	# la calotta è SPOSTATA rispetto al gambo: si sta sotto la sporgenza,
	# non abbracciati al palo. Col gambo in mezzo, chi si riparava se lo
	# ritrovava piantato davanti alla faccia e l'inquadratura era tagliata
	# in due.
	var calotta := GEO.skirt_mesh(2.15, 0.52, 415, 0.26)
	var posa := RIPARO_OFF + Vector3(0, FOGLIA_H, 0)
	var verso := Vector3(0.16, 0.5, -0.10)

	var lembo := MeshInstance3D.new()
	lembo.mesh = calotta
	lembo.position = posa
	lembo.rotation = verso
	lembo.material_override = GEO.paint_mat(
			Color(0.145, 0.245, 0.155), Color(0.20, 0.335, 0.19), 3.2, 0.42, 0.5,
			true, 0.55)
	nodo.add_child(lembo)

	# LA PAGINA DI SOTTO. Da sotto la calotta era INVISIBILE: si vedevano
	# solo le nervature, appese al buio come lo scheletro di un ombrello.
	# La cosa che il giocatore deve vedere quando alza gli occhi — di
	# essere sotto qualcosa — non si vedeva proprio.
	#
	# Il motivo è che lo shader dipinto scarta le facce di dietro, e da
	# sotto la volta MOSTRA solo quelle. Quindi la pagina di sotto è un
	# pezzo suo, con la faccia opposta e il suo colore: le foglie grandi
	# ce l'hanno davvero, più chiara e quasi argentata, ed è quella che
	# prende la luce calda del riparo.
	var sotto := MeshInstance3D.new()
	sotto.mesh = calotta
	sotto.position = posa
	sotto.rotation = verso
	sotto.scale = Vector3.ONE * 0.985
	var mat_sotto := StandardMaterial3D.new()
	mat_sotto.cull_mode = BaseMaterial3D.CULL_FRONT
	mat_sotto.albedo_color = Color(0.42, 0.52, 0.36)
	mat_sotto.roughness = 0.92
	sotto.material_override = mat_sotto
	nodo.add_child(sotto)

	# le nervature, viste da sotto: sono il soffitto di questa stanza
	for i in 7:
		var nerv := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.04, 0.014, 1.95)
		nerv.mesh = bm
		nerv.position = RIPARO_OFF + Vector3(0, FOGLIA_H - 0.10, 0)
		nerv.rotation.y = TAU * float(i) / 7.0
		nerv.translate_object_local(Vector3(0, 0, 0.98))
		nerv.material_override = GEO.paint_mat(
				Color(0.22, 0.34, 0.19), Color(0.28, 0.42, 0.23), 6.0, 0.3)
		nodo.add_child(nerv)

	# sotto: la terra che è rimasta asciutta.
	var asciutto := MeshInstance3D.new()
	var d := CylinderMesh.new()
	d.top_radius = RIPARO_R
	d.bottom_radius = RIPARO_R
	d.height = 0.03
	d.radial_segments = 28
	asciutto.mesh = d
	asciutto.position = RIPARO_OFF + Vector3(0, 0.015, 0)
	asciutto.material_override = GEO.paint_mat(
			Color(0.20, 0.155, 0.11), Color(0.26, 0.20, 0.14), 5.0, 0.45, 0.0, true)
	nodo.add_child(asciutto)

	# IL PREMIO DEL RIPARO — e il pezzo di regia più importante di tutto il
	# Prologo. Sotto la foglia c'è una luce CALDA, debolissima, senza una
	# fonte che si possa indicare. Tutto il resto della radura è blu e
	# freddo; qui dentro no.
	#
	# Serve a una cosa sola: rendere il riparo una cosa che si SENTE invece
	# che una cosa che si capisce. Nessuno ha detto al giocatore che
	# ripararsi è meglio — se ci arriva, deve arrivarci perché sotto la
	# foglia si sta bene. E se non ci va, la lettera del Gufo dirà anche
	# quello, senza rimproverarlo.
	var tepore := OmniLight3D.new()
	tepore.light_color = Color(1.0, 0.82, 0.58)
	tepore.light_energy = 1.45
	tepore.omni_range = 3.6
	tepore.omni_attenuation = 1.6
	tepore.shadow_enabled = false
	tepore.position = RIPARO_OFF + Vector3(0, 0.95, 0)
	nodo.add_child(tepore)

	# E LA FOGLIA FERMA DAVVERO L'ACQUA. Senza questo la pioggia cadeva
	# dritta attraverso il lembo e ti bagnava sulla terra asciutta: il
	# riparo si vedeva ma non funzionava, ed era la bugia più grossa che
	# il Prologo potesse raccontare — proprio sulla cosa che sta
	# misurando. Le gocce che toccano il volume spariscono, e sotto
	# resta un cono d'asciutto con la sua forma.
	var scudo := GPUParticlesCollisionBox3D.new()
	scudo.size = Vector3(3.9, 0.30, 3.9)
	scudo.position = RIPARO_OFF + Vector3(0, FOGLIA_H - 0.16, 0)
	nodo.add_child(scudo)

	# LA TENDA: l'acqua che cola tutt'intorno al bordo. È lei a dire dove
	# finisce l'asciutto, e lo dice senza una parola.
	_tenda = _emettitore_pioggia(420, Vector3(3.5, 0.1, 3.5),
			RIPARO_OFF + Vector3(0, FOGLIA_H - 0.05, 0), 2.1, 0.015, 0.40)
	# la tenda NON si ferma contro la foglia: è l'acqua che ne è già
	# scesa. Senza questo sparirebbe appena nata, dentro lo scudo.
	_tenda.process_material.collision_mode = ParticleProcessMaterial.COLLISION_DISABLED
	_tenda.process_material.emission_shape = \
			ParticleProcessMaterial.EMISSION_SHAPE_RING
	_tenda.process_material.emission_ring_radius = 1.66
	_tenda.process_material.emission_ring_inner_radius = 1.52
	_tenda.process_material.emission_ring_height = 0.06
	_tenda.process_material.emission_ring_axis = Vector3.UP
	nodo.add_child(_tenda)


## IL RIGONFIAMENTO. Un ciuffo d'erba più alto degli altri, e sotto
## qualcosa che respira. Non succede subito (T_ERBA) e non fa rumore:
## l'erba si alza e si abbassa piano, e o te ne accorgi o non te ne accorgi.
func _costruisci_erba_alta() -> void:
	_dosso = Node3D.new()
	_dosso.position = ERBA
	add_child(_dosso)

	var gobba := MeshInstance3D.new()
	gobba.mesh = GEO.puff_mesh(0.62, 5150, 0.52, 0.10)
	gobba.material_override = GEO.paint_mat(
			ERBA_SCURA.lightened(0.04), ERBA_BAGNATA, 4.0, 0.42, 0.4, true)
	gobba.position.y = -0.16
	_dosso.add_child(gobba)

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = GEO.blade_mesh()
	mm.instance_count = 180
	for i in 180:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.72
		var p := Vector3(cos(a) * r, 0.10, sin(a) * r)
		var tr := Transform3D().rotated(Vector3.UP, rng.randf() * TAU)
		tr = tr.scaled(Vector3.ONE * rng.randf_range(1.7, 2.9))
		mm.set_instance_transform(i, tr.translated(p))
	var ciuffo := MultiMeshInstance3D.new()
	ciuffo.multimesh = mm
	ciuffo.material_override = GEO.paint_mat(
			ERBA_SCURA, ERBA_BAGNATA.lightened(0.05), 5.0, 0.35, 1.1, true)
	ciuffo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dosso.add_child(ciuffo)

	# il riccio è figlio della RADURA, non del ciuffo: dopo si stacca e
	# viene a stare vicino a lei, e un figlio del ciuffo se lo sarebbe
	# portato dietro insieme all'erba
	_riccio = _costruisci_riccio()
	_riccio.position = ERBA + Vector3(0, -0.42, 0)
	add_child(_riccio)
	_dosso.visible = false


## Chi c'è sotto: un riccio piccolissimo, bagnato, che trema. Non parla,
## non dà niente, non sblocca niente. Si limita a esserci — e a tremare
## esattamente come lei.
func _costruisci_riccio() -> Node3D:
	var r := Node3D.new()
	var corpo := MeshInstance3D.new()
	corpo.mesh = GEO.puff_mesh(RICCIO_R, 777, 0.82, 0.06)
	corpo.material_override = GEO.paint_mat(
			Color(0.40, 0.32, 0.26), Color(0.52, 0.43, 0.34), 6.0, 0.4)
	r.add_child(corpo)
	# GLI ACULEI. Tanti e corti: radi e lunghi facevano una barba, e il
	# riccio sembrava un sasso con dei peli. Il colore è chiaro quanto il
	# corpo — un riccio nero, di notte, è un buco nell'inquadratura.
	var rng := RandomNumberGenerator.new()
	rng.seed = 616
	var spine := GEO.cone_mesh(0.013, 0.075, 5)
	var mat_spine := GEO.paint_mat(
			Color(0.33, 0.27, 0.23), Color(0.58, 0.50, 0.40), 8.0, 0.5)
	for i in 130:
		# distribuzione uniforme sulla calotta, non sui poli
		var u := rng.randf_range(-0.15, 1.0)
		var a := rng.randf() * TAU
		var piano := sqrt(maxf(0.0, 1.0 - u * u))
		var d := Vector3(cos(a) * piano, u, sin(a) * piano)
		var s := MeshInstance3D.new()
		s.mesh = spine
		s.material_override = mat_spine
		s.position = Vector3(d.x, d.y * 0.82, d.z) * RICCIO_R * 0.92
		# il cono guarda in fuori: lo si orienta sulla normale della cupola
		var su := d.normalized()
		var lato := su.cross(Vector3.FORWARD)
		if lato.length() < 0.01:
			lato = su.cross(Vector3.RIGHT)
		lato = lato.normalized()
		s.basis = Basis(lato, su, lato.cross(su))
		r.add_child(s)
	# il musetto: appuntito, chiaro, e SENZA aculei (è la parte tenera)
	var muso := MeshInstance3D.new()
	muso.mesh = GEO.cone_mesh(0.062, 0.115, 10)
	muso.material_override = GEO.paint_mat(
			Color(0.50, 0.41, 0.34), Color(0.62, 0.52, 0.43), 8.0, 0.35)
	muso.position = Vector3(0, -0.018, -RICCIO_R * 0.92)
	muso.rotation.x = -PI * 0.5
	r.add_child(muso)
	var occhio_mat := StandardMaterial3D.new()
	occhio_mat.albedo_color = Color(0.04, 0.035, 0.05)
	occhio_mat.metallic = 0.6
	occhio_mat.roughness = 0.08
	for s: float in [-1.0, 1.0]:
		var o := MeshInstance3D.new()
		o.mesh = GEO.sphere_mesh(0.022, 8)
		o.material_override = occhio_mat
		o.position = Vector3(s * 0.048, 0.038, -RICCIO_R * 0.80)
		r.add_child(o)
	var naso := MeshInstance3D.new()
	naso.mesh = GEO.sphere_mesh(0.018, 8)
	naso.material_override = occhio_mat
	naso.position = Vector3(0, -0.018, -RICCIO_R * 0.92 - 0.10)
	r.add_child(naso)
	return r


# ============================================================== il corpo

func _costruisci_corpo() -> void:
	_corpo = CharacterBody3D.new()
	var forma := CollisionShape3D.new()
	var caps := CapsuleShape3D.new()
	caps.radius = 0.20
	caps.height = 0.62
	forma.shape = caps
	forma.position.y = 0.31
	_corpo.add_child(forma)
	_corpo.position = Vector3(0.4, 0, 3.1)
	add_child(_corpo)

	# LA CUCCIOLA: è Mochi, ma più piccola. Non un modello diverso — la
	# stessa gatta, vista quando era grande la metà. (Il Player del
	# villaggio la monta a 0.75; qui 0.46.)
	_mochi = MOCHI.instantiate()
	_mochi.scale = Vector3.ONE * 0.46
	_mochi.rotation.y = PI
	_corpo.add_child(_mochi)

	_cam = Camera3D.new()
	_cam.fov = 46.0
	_cam.current = true
	add_child(_cam)
	_cam_pos = _corpo.position + CAM_STACCO
	_cam.position = _cam_pos
	_cam.look_at(_corpo.position + CAM_MIRA)


func _costruisci_velo() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_velo = ColorRect.new()
	_velo.color = Color(0, 0, 0, 1)
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_velo)


# ============================================================== la pioggia

func _costruisci_pioggia() -> void:
	# SOTTILI E TANTE. Le gocce grosse, anche strette, passano a mezzo
	# metro dall'obiettivo e diventano sbarre bianche che coprono la
	# scena: la pioggia fitta si fa col NUMERO e con la trasparenza, mai
	# con lo spessore del singolo filo.
	_pioggia = _emettitore_pioggia(4400, Vector3(20, 0.4, 20),
			Vector3(0, 9.0, 0), 9.5, 0.016, 0.34)
	add_child(_pioggia)

	# gli schizzi a terra: è quello che rende l'acqua PESANTE
	# gli schizzi sono SCHEGGE, non bolle: tondi e grossi sembravano lucciole
	# di giorno (a schermo erano palline bianche che galleggiavano nell'aria)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.012, 0.055)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.76, 0.86, 1.0, 0.34)
	mat.albedo_texture = _texture_goccia()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# GLI SCHIZZI STANNO DOVE SEI TU. Prima piovevano su tutta la radura,
	# foglia compresa: sulla terra asciutta rimbalzavano gocce che dal
	# cielo non erano mai arrivate, e il riparo diventava una bugia
	# proprio nel punto che il Prologo sta misurando. Adesso l'emettitore
	# segue il corpo (dove si guarda) e si SPEGNE quando è al coperto.
	pm.emission_box_extents = Vector3(3.2, 0.02, 3.2)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 32.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.5
	pm.gravity = Vector3(0, -6.5, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	_schizzi = GPUParticles3D.new()
	_schizzi.amount = 260
	_schizzi.lifetime = 0.42
	_schizzi.process_material = pm
	_schizzi.draw_pass_1 = quad
	_schizzi.local_coords = false
	_schizzi.position.y = 0.02
	add_child(_schizzi)


## Il filo d'acqua: pieno in mezzo, sfumato alle due punte. Un gradiente
## verticale, non un cerchio — è la differenza fra pioggia e grandine.
func _texture_goccia() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.22, 0.78, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.95),
			Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.width = 8
	t.height = 64
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	return t


## Una cortina di gocce: quad allungati che cadono. [param vel] è la
## velocità di caduta, [param largo] la larghezza della goccia.
func _emettitore_pioggia(quante: int, scatola: Vector3, dove: Vector3,
		vel: float, largo: float, alpha: float) -> GPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(largo, largo * 16.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.80, 0.88, 1.0, alpha)
	# UNA GOCCIA NON È UN PALLINO. Senza billboard i quad guardavano ognuno
	# per conto suo e la pioggia sembrava neve; con la sfumatura tonda
	# sembrava grandine. Serve un billboard (il filo resta in piedi
	# rispetto a chi guarda) e una sfumatura ALLUNGATA sulla verticale.
	#
	# E NIENTE `billboard_keep_scale`: teneva la goccia grande uguale a
	# ogni distanza, così quelle che passavano a mezzo metro dalla camera
	# diventavano sbarre bianche larghe un dito e coprivano la scena. Le
	# gocce vicine DEVONO essere grandi in proporzione — ma sottili: la
	# pioggia fitta si fa col numero, non con lo spessore.
	mat.albedo_texture = _texture_goccia()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = scatola * 0.5
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 0.6
	pm.initial_velocity_min = vel
	pm.initial_velocity_max = vel * 1.25
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.25
	# le gocce muoiono contro quello che incontrano (il lembo della foglia)
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	var p := GPUParticles3D.new()
	p.amount = quante
	p.lifetime = 1.5
	p.preprocess = 1.2
	p.process_material = pm
	p.draw_pass_1 = quad
	p.position = dove
	p.local_coords = false
	return p


# ================================================================ il tempo

func _process(delta: float) -> void:
	_t += delta
	_apertura()
	_temporale(delta)
	_erba(delta)
	_appunti(delta)
	_camera(delta)
	if not _finito and _t >= T_FINE:
		_finito = true
		_chiudi()


## Il buio, il primo lampo, e il corpo che torna suo.
func _apertura() -> void:
	if _t < T_BUIO:
		_velo.color.a = 1.0
		return
	if not _giocabile:
		# si sveglia: prima raggomitolata, poi si tira su
		_velo.color.a = clampf(1.0 - (_t - T_BUIO) / 1.6, 0.0, 1.0)
		if not _rannicchiata:
			_rannicchiata = true
			_mochi.call("set_pose", "sleep")
		if _t >= T_CONTROLLO:
			_giocabile = true
			_mochi.call("set_pose", "stand")
			_mochi.call("forza_espressione", "spavento", 0.7)
	elif _t >= T_CALA:
		# il finale sfuma in un grigio d'alba, non in nero: il gioco che
		# comincia dopo è un gioco luminoso, e lo si deve capire da qui
		var q := clampf((_t - (T_FINE - 4.0)) / 4.0, 0.0, 1.0)
		_velo.color = Color(0.93, 0.94, 0.97, q)


func _temporale(delta: float) -> void:
	# l'intensità: piena fino a T_CALA, poi molla e se ne va
	_intensita = 1.0 if _t < T_CALA else clampf(1.0 - (_t - T_CALA) / (T_FINE - T_CALA), 0.0, 1.0)
	var forza := 0.18 + 0.82 * _intensita
	_pioggia.amount_ratio = forza
	_schizzi.amount_ratio = forza
	_tenda.amount_ratio = forza
	if _corpo:
		_schizzi.global_position = Vector3(_corpo.global_position.x, 0.02,
				_corpo.global_position.z)
		_schizzi.emitting = not _al_riparo() and _intensita > 0.05
	# la spallina piegata nella raffica: il vento si vede su di lei anche
	# se non la sposta di un centimetro
	if _mochi and _giocabile:
		_mochi.rotation.z = lerpf(_mochi.rotation.z,
				-0.10 * _vento * (0.0 if _al_riparo() else 1.0), delta * 3.0)
	if _sfx:
		# la pioggia si allontana insieme al temporale
		_sfx.set_rain_muffled(_al_riparo() or _intensita < 0.35)

	# IL VENTO: raffiche, non un soffio costante. Due seni incommensurabili
	# più una spinta lenta: non si richiude mai su sé stesso, e il prato non
	# sembra mai un'animazione in loop.
	_vento_ph += delta * (0.85 + 0.5 * _intensita)
	_vento = (0.55 + 0.45 * sin(_vento_ph * 0.77) * cos(_vento_ph * 0.31 + 0.9)) * _intensita
	var pm: ParticleProcessMaterial = _pioggia.process_material
	pm.gravity = Vector3(-2.6 * _vento, -9.0, 0.7 * _vento)

	# I LAMPI. Il tuono NON arriva insieme: si mette in coda con il suo
	# ritardo, perché la luce va più forte del suono. È la cosa che rende
	# un temporale un temporale — e più tardi arriva, più era lontano.
	_prossimo_lampo -= delta
	if _prossimo_lampo <= 0.0 and _intensita > 0.08:
		var vicino := randf() < 0.30 + 0.35 * _intensita
		_prossimo_lampo = randf_range(4.5, 11.0) / maxf(0.25, _intensita)
		_flash = 1.0 if vicino else 0.55
		_tuoni.append([_t + (randf_range(0.10, 0.4) if vicino
				else randf_range(1.8, 4.5)), vicino])
	if _flash > 0.0:
		# il lampo non è un interruttore: sfarfalla due volte e se ne va
		_flash = maxf(0.0, _flash - delta * 5.2)
		var sfarfallio := 0.55 + 0.45 * sin(_t * 47.0)
		_lampo.light_energy = _flash * _flash * 5.5 * sfarfallio
		_ambiente.environment.ambient_light_energy = 0.55 + _flash * 1.5
	for i in range(_tuoni.size() - 1, -1, -1):
		if _t >= float(_tuoni[i][0]):
			var vicino: bool = _tuoni[i][1]
			if _sfx:
				_sfx.call("tuono", vicino, -3.0 if vicino else -9.0)
			if vicino:
				_scossa = 1.0
				_spavento()
			_tuoni.remove_at(i)
	_scossa = maxf(0.0, _scossa - delta * 1.7)


## Il tuono vicino le fa paura. Non è una cutscene: sono due decimi di
## secondo di orecchie giù e occhi larghi, e poi torna a fare quello che
## stava facendo. È anche il primo posto in cui il giocatore capisce che
## questa gatta SENTE le cose.
func _spavento() -> void:
	if _mochi == null:
		return
	_mochi.call("forza_espressione", "spavento", 1.0)
	if _al_riparo():
		return
	# fuori, la scossa è anche nel corpo
	var tw := create_tween()
	tw.tween_property(_mochi, "position:y", 0.045, 0.07) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_mochi, "position:y", 0.0, 0.30) \
			.set_trans(Tween.TRANS_SINE)


func _erba(delta: float) -> void:
	if _t < T_ERBA:
		return
	if not _dosso.visible:
		_dosso.visible = true
	# il respiro di chi sta sotto: lento, e più corto in entrata che in
	# uscita — un respiro simmetrico è la firma di una macchina
	_respiro += delta * (1.35 if _dosso_su < 0.5 else 1.05)
	var insp := sin(_respiro)
	var soffio: float = (insp * 0.62 if insp > 0.0 else insp * 0.38)
	_dosso_su = move_toward(_dosso_su, 1.0, delta * 0.55)
	_dosso.position.y = ERBA.y + _dosso_su * (0.18 + soffio * 0.055)
	# e ogni tanto un brivido: sta prendendo acqua anche lui
	if randf() < delta * 0.35:
		var tw := create_tween()
		tw.tween_property(_dosso, "rotation:z", randf_range(-0.06, 0.06), 0.09)
		tw.tween_property(_dosso, "rotation:z", 0.0, 0.35) \
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# se le arriva col naso addosso, si scopre: l'erba si apre e lui c'è.
	# Non succede niente altro. È tutto quello che deve succedere.
	var d := _corpo.global_position.distance_to(_dosso.global_position)
	if not _scoperto and d < NASO_R:
		_scoperto = true
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_riccio, "position:y", RICCIO_Y, 1.1) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_dosso, "scale", Vector3(1.18, 0.62, 1.18), 0.9) \
				.set_trans(Tween.TRANS_SINE)
		if _mochi:
			_mochi.call("forza_espressione", "meraviglia", 1.0)
		if _sfx:
			_sfx.play("chirp2", -19.0, 1.5)
	if not _scoperto:
		return

	# E POI TI VIENE DIETRO. È la sola conseguenza di tutto il Prologo che
	# si vede mentre succede — e per un pezzo è anche l'unica compagnia
	# che c'è. Chi è andato a vedere cos'era, da qui in avanti la
	# tempesta non se la guarda più da solo; chi ha fatto un passo
	# indietro non saprà mai che si poteva.
	#
	# Sta di FIANCO, mai davanti e mai dietro: dietro alla camera non lo
	# vedresti mai, e davanti coprirebbe lei (all'inizio le finiva
	# esattamente sotto i piedi e si vedevano tre aculei spuntare da una
	# spalla).
	var fianco := _corpo.global_position \
			+ _corpo.global_basis.x.normalized() * -0.62 + Vector3(0, RICCIO_Y, 0)
	var lontano := _riccio.global_position.distance_to(fianco)
	if lontano > 0.30:
		_riccio.global_position = _riccio.global_position.lerp(
				fianco, clampf(delta * 1.5, 0.0, 1.0))
		# il passo: un dondolio corto, che un riccio bagnato fa più corto
		_riccio.position.y = RICCIO_Y + absf(sin(_t * 7.0)) * 0.03
	else:
		_riccio.position.y = RICCIO_Y
	# guarda lei, e trema
	_riccio.look_at(_corpo.global_position + Vector3(0, 0.12, 0), Vector3.UP, true)
	_riccio.rotate_object_local(Vector3.UP, sin(_t * 23.0) * 0.02)


# ============================================================== il taccuino
# Qui si scrive quello che il gioco ha visto — e questa è l'unica cosa che
# di questi tre minuti sopravvive.

func _appunti(delta: float) -> void:
	if not _giocabile or _t >= T_FINE:
		return
	_taccuino.durata += delta
	if _al_riparo():
		_taccuino.riparo += delta
	# ferma: non è «velocità zero», è «non sta andando da nessuna parte».
	# Un istante fermo mentre si cambia direzione non è stare a guardare.
	if _corpo.velocity.length() < 0.25:
		_fermo_t += delta
		if _fermo_t > 0.8:
			_taccuino.fermo += delta
	else:
		_fermo_t = 0.0
	if _dosso.visible:
		var d := _corpo.global_position.distance_to(_dosso.global_position)
		# 0 a tre metri, 1 col naso addosso
		var v := clampf(1.0 - (d - NASO_R) / (3.0 - NASO_R), 0.0, 1.0)
		_taccuino.vicinanza = maxf(_taccuino.vicinanza, v)


## Il centro dell'asciutto, in coordinate del mondo.
static func centro_riparo() -> Vector3:
	return FOGLIA + RIPARO_OFF


func _al_riparo() -> bool:
	if _corpo == null:
		return false
	var p := _corpo.global_position
	var c := centro_riparo()
	return Vector2(p.x - c.x, p.z - c.z).length() < RIPARO_R


# ================================================================ la camera

func _camera(delta: float) -> void:
	if _corpo == null:
		return
	# SOTTO LA FOGLIA LA CAMERA ALZA GLI OCCHI. È il pezzo di regia che fa
	# leggere il riparo: da fuori si guarda in giù, verso l'erba e i
	# piedi; entrando sotto il lembo la macchina indietreggia e alza la
	# mira, e la volta di foglia entra dal bordo alto. Senza, il tetto
	# restava fuori inquadratura e ripararsi voleva dire soltanto stare
	# su una macchia di terra scura — nessuno avrebbe capito di essere
	# arrivato da qualche parte.
	_riparo_vista = move_toward(_riparo_vista, 1.0 if _al_riparo() else 0.0,
			delta * 0.9)
	var q := smoothstep(0.0, 1.0, _riparo_vista)
	var voluta := _corpo.global_position + CAM_STACCO.lerp(CAM_STACCO_RIPARO, q)
	_cam_pos = _cam_pos.lerp(voluta, clampf(delta * 2.6, 0.0, 1.0))
	var scossa := Vector3.ZERO
	if _scossa > 0.0:
		var s := _scossa * _scossa * 0.16
		scossa = Vector3(randf_range(-s, s), randf_range(-s, s), 0)
	_cam.position = _cam_pos + scossa
	_cam.look_at(_corpo.global_position + CAM_MIRA.lerp(CAM_MIRA_RIPARO, q))


# ============================================================== il comando

func _physics_process(delta: float) -> void:
	if _corpo == null:
		return
	if not _giocabile or _finito:
		_corpo.velocity = Vector3.ZERO
		_corpo.move_and_slide()
		return
	# le STESSE azioni del villaggio (src/player_controller.cpp): il Prologo
	# insegna i comandi veri senza scriverli da nessuna parte, e chi ha
	# rimappato i tasti se li ritrova rimappati anche qui
	var asse := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var dir := Vector3(asse.x, 0, asse.y)
	# UNA CUCCIOLA SOTTO IL VENTO non cammina come un personaggio in un
	# menu: la raffica la porta di lato, e per andare controvento deve
	# insistere.
	#
	# Ma la spinta si somma solo A CHI SI STA MUOVENDO. Da ferma si
	# impunta, e resta dov'è. Prima il vento la spostava comunque, e due
	# cose che il Prologo deve poter misurare diventavano impossibili:
	# stare sotto la foglia (in venti secondi l'acqua te ne portava fuori)
	# e stare ferma a guardare (la velocità non era mai zero). Un vento che
	# combatte l'intenzione del giocatore non è atmosfera, è un bug —
	# l'atmosfera la fanno l'erba, la pioggia di traverso e la sua
	# spallina piegata nella raffica, che ci sono lo stesso.
	var spinta := Vector3(-0.55, 0, 0.16) * _vento * dir.length()
	if _al_riparo():
		spinta = Vector3.ZERO      # sotto la foglia non tira: è il premio
	var voluta := dir * 2.05 + spinta
	_corpo.velocity.x = move_toward(_corpo.velocity.x, voluta.x, delta * 9.0)
	_corpo.velocity.z = move_toward(_corpo.velocity.z, voluta.z, delta * 9.0)
	_corpo.velocity.y = 0.0
	_corpo.move_and_slide()
	# il recinto della radura, senza muri invisibili che sbattono: più
	# vai in là, più il vento contrario aumenta finché non ti riporta
	var p := _corpo.global_position
	var r := Vector2(p.x, p.z).length()
	if r > RAGGIO:
		var verso := Vector3(p.x, 0, p.z).normalized()
		_corpo.global_position -= verso * (r - RAGGIO)


# ================================================================ la fine

func _chiudi() -> void:
	_taccuino.durata = maxf(0.001, _taccuino.durata)
	var f := FileAccess.open(APPUNTI, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_taccuino.da_salvare()))
		f.close()
	else:
		# senza appunti il villaggio parte com'è sempre partito: il Prologo
		# è un regalo, non una dipendenza. Mai un errore a schermo per
		# questo, e mai un avvio bloccato.
		printerr("Prologo: appunti non salvati (%s)" % error_string(FileAccess.get_open_error()))
	if _sfx:
		_sfx.set_rain(false)
	get_tree().change_scene_to_file(LIVELLO)
