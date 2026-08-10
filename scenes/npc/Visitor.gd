extends Node3D

## Un visitatore del bosco. Entra nel villaggio trotterellando (o a
## saltelli), curiosa tra i mobili con un "?" sopra la testa, si riposa
## sulla panchina — il passerotto si appollaia sullo schienale — lascia
## un regalino con un cuoricino e se ne torna nel bosco. Non chiede
## niente: dà vita e basta.
##
## Specie: "riccio" (trotterella dondolando, nasino che annusa) e
## "passerotto" (saltelli parabolici con squash & stretch e ali).

signal wants_gift(pos: Vector3, species_name: String)
signal finished

const TOON := preload("res://shaders/toon.gdshader")
const BUILDER := preload("res://scenes/npc/ChibiBuilder.gd")
const ANDATURA := preload("res://scenes/npc/Andatura.gd")
const DNA_GEN := preload("res://scenes/npc/ChibiDNA.gd")
const CHIBIESE := preload("res://audio/Chibiese.gd")
const FACE := preload("res://scenes/characters/FaceController.gd")

# gli stati in cui lo sguardo si posa su ciò che il villager esamina (_target).
# Dizionario-come-insieme, const: nessuna allocazione per-frame nel _process.
const LOOK_STATES := {
	"inspect": true, "c_inspect": true, "sniff": true, "annusa": true, "r_sniff": true,
}

var species := "riccio"

## Se presente, il corpo viene costruito dal genoma (villager generato).
var dna := {}
var _c_arms: Array[Node3D] = []
var _c_ears: Array[Node3D] = []
var _c_legs: Array[Node3D] = []

# ---------------------------------------------------- LA RECITA DEL CORPO
# Le posture della ribellione, finalmente ADDOSSO al chibi. Visitors le
# scrive da sempre in set_meta("postura", …) — telegrafo della scala,
# sussulti, esitazioni — ma nessuno le leggeva: il sistema più bello del
# gioco era invisibile a occhio nudo. Questo blocco le legge e le recita:
# offset di posa (braccia, orecchie, testa, schiena) fusi coi muscoli e
# stesi SOPRA l'animazione dello stato, mai al suo posto.
#
# Ogni canale: ax braccia (x, ax_dx per il destro da solo) · az braccia
# incrociate (specchiato sui lati) · ear orecchie (+ giù, − su) · hx mento
# (+ giù, − su) · hy_amp sguardo che vaga · vx schiena (+ curva, − in
# fuori) · fagotto: il sacchetto del trasloco sulla spalla.
const RECITA := {
	"sereno": {},
	"spalle_basse": {"ax": 0.35, "ear": 0.8, "hx": 0.2, "vx": 0.15},
	"distratto": {"hy_amp": 0.45, "ear": 0.18, "hx": 0.04},
	"braccia_conserte": {"ax": 1.15, "az": 1.0, "hx": -0.07, "ear": 0.25,
			"vx": -0.03},
	"sguardo_sfuggente": {"hy_amp": 0.55, "hy_scatti": 1.0, "ear": 0.32,
			"hx": 0.1, "ax": 0.15, "vx": 0.05},
	"petto_in_fuori": {"ax": -0.25, "az": -0.3, "ear": -0.3, "hx": -0.15,
			"vx": -0.14},
	"fagotto_in_spalla": {"ax": 0.3, "ax_dx": -2.3, "ear": 0.45, "hx": 0.1,
			"vx": 0.1, "fagotto": true},
	"testa_alta": {"ax": 0.1, "ear": -0.35, "hx": -0.3, "vx": -0.1},
	# CHI ASCOLTA. Il pubblico del concerto la chiedeva gia' (Concerto.gd)
	# e non esisteva in nessuna delle due tabelle: `_recita_applica` cadeva
	# fuori da entrambi i rami e non consumava nemmeno il meta. Orecchie
	# avanti, mento appena su, spalle ferme: e' il corpo di chi sta stando
	# attento, non di chi finge.
	"attento": {"ear": -0.42, "hx": -0.12, "ax": 0.08, "vx": -0.04},
}
# i transitori: reazioni del corpo che si consumano da sole
const RECITA_TRANS := {
	"esita": {"dur": 2.4, "vx": 0.1, "hx": 0.14, "hy_amp": 0.3},
	"trasalisce": {"dur": 1.3, "ear": -0.75, "ax": -0.6, "hx": -0.12},
	"si_illumina": {"dur": 1.8, "ear": -0.6, "ax": -0.35, "hx": -0.08},
	# --- il REPERTORIO DEL SALUTO: la stessa gioia, filtrata dall'indole.
	# Qui vivono le pose base; le onde-firma (l'applauso piccolo, il mezzo
	# saltello riluttante…) stanno in recita_bersagli, caso per caso.
	"saluto_festoso": {"dur": 1.5, "ax": -1.7, "ear": -0.5, "hx": -0.08},
	"saluto_timido": {"dur": 1.7, "ax": 0.7, "az": 0.8, "ear": 0.4, "hx": 0.2},
	"saluto_brontolone": {"dur": 1.9, "ax": 0.1, "ear": 0.25, "hx": 0.06},
	"saluto_sognante": {"dur": 2.3, "ax_dx": -2.5, "ear": -0.3, "hx": -0.24},
	"saluto_pancino": {"dur": 1.6, "ax": 0.95, "az": 0.55, "ear": -0.2, "hx": -0.04},
	"saluto_stiracchio": {"dur": 2.1, "ax": -2.3, "ear": 0.35, "hx": -0.18},
	"saluto_scattante": {"dur": 1.1, "ax_dx": -2.0, "ear": -0.6, "hx": -0.1},
	"saluto_inchino": {"dur": 1.6, "ax": 0.3, "vx": 0.34, "hx": 0.3, "ear": 0.12},
}

## Il saluto di ciascuno, dall'indole del cervello (VillagerBrain): il
## timido applaude piccolo, il brontolone si concede un mezzo saltello,
## il sognatore ondeggia lento… Priorità alle indoli più caratteriali.
static func saluto_di(brain) -> String:
	if brain == null:
		return "saluto_festoso"
	for coppia: Array in [
			["timido", "saluto_timido"],
			["brontolone", "saluto_brontolone"],
			["sognatore", "saluto_sognante"],
			["goloso", "saluto_pancino"],
			["dormiglione", "saluto_stiracchio"],
			["mattiniero", "saluto_scattante"],
			["ordinato", "saluto_inchino"],
			["chiacchierone", "saluto_festoso"]]:
		if brain.has_indole(str(coppia[0])):
			return str(coppia[1])
	return "saluto_festoso"

var _rc_stabile := "sereno"
var _rc_trans := ""
var _rc_trans_t := 0.0
var _rc_cur := {}    # canale -> valore corrente (fuso coi muscoli)
var _rc_appl := {}   # ciò che è stato sommato al rig l'ultimo frame

# LA PIOGGIA ADDOSSO: lo alza Visitors per chi è fuori senza un tetto.
# Non è una postura (quelle le detta l'animo): è un livello che si SOMMA
# a qualunque recita — zampina a visiera, orecchie basse, passetto svelto.
var riparo_pioggia := false
var _riparo := 0.0

# il saluto della SUA indole (saluto_di, lo cabla Visitors col cervello):
# "" finché il cervello non è nato — allora vale il festoso di default
var saluto_stile := ""

# ---- IL CICLO DI CAMMINATA CONDIVISO (la stessa specie di Mochi) ----
# La fase avanza dalla VELOCITA' VERA misurata (mai moonwalk), il blend
# accende e SPEGNE il passo da solo, le braccia oscillano con la torsione
# di Mochi, il corpo si PIEGA dentro le curve, e il passo suona
# nell'istante dell'appoggio.
# Il ciclo vero vive in scenes/npc/Andatura.gd — una casa sola, così i
# vicini camminano allo stesso modo nel villaggio e nel diorama del menù.
var _andatura: RefCounted
var _fagotto: Node3D

# la voce Chibiese: nasce dal DNA, parla dal proprio corpo (audio 3D)
var _voice := {}
var _voice_player: AudioStreamPlayer3D
var _speak_cd := 0.0

## "visit" = ospite di passaggio · "candidate" = aspirante residente con
## la valigia · "resident" = ormai vive qui
var mode := "visit"
var _house := {}
var _suitcase: Node3D
var _greet_cd := 0.0
# Quanto dura ancora la SCENA in corso. Mentre c'è, il chiacchiericcio
# ordinario tace: un appuntamento mantenuto non va coperto dal desiderio
# della panchina, che può aspettare dieci secondi.
var _scena_t := 0.0
var _hidden := false
var _player_ref: Node3D

# routine da residente: annusare aiuole, panchine, il falò della sera
var _routine_aux: Node3D
## quanto si resta seduti, se chi ci manda lo sa meglio di noi (0 = a caso)
var _routine_durata := 0.0
## Dove ci si siede quando il mobile non lo dichiara: è la misura della
## PANCHINA, il pezzo per cui `r_bench` è stato scritto. Vive qui e in
## nessun altro posto.
const SEDUTA_PREDEFINITA := Vector3(0, 0.52, 0.02)
## E dove si appollaia chi vola, se il mobile non lo dichiara. Stessa
## regola della seduta, e per lo stesso motivo: era una costante scritta
## a mano qui dentro, tarata sulla panchina VECCHIA.
const POSATOIO_PREDEFINITO := Vector3(0, 0.86, -0.18)
var _fire_look := Vector3.ZERO

# la gita alla casa sull'albero: base scala, cima, trespolo
var _th := {}

# la lavagna (dove scrivere il compleanno) e il cappellino da festa
var _write_look := Vector3.ZERO
var _party_hat: Node3D

# l'onsen: accappatoio, asciugamanino e il posto a mollo
var _onsen := {}
var _robe: Node3D

var _state := "idle"
var _next_state := ""
var _target := Vector3.ZERO
var _timer := 0.0
var _t := 0.0
var _yaw := 0.0
var _speed := 1.3
var _sfx

var _bench: Node3D
var _pois: Array[Vector3] = []
var _poi_i := 0
var _exit_a := Vector3(0, 0, -10)
var _exit_b := Vector3(-2, 0, -15)
var _gift_pos := Vector3.ZERO

# parti animate
var _vis: Node3D
var _head: Node3D
# il volto vivo del villager (solo per i chibi generati da DNA): sopracciglia,
# sguardo, ammicco, espressioni. I visitatori "riccio/passerotto" ne sono privi.
var _face
var _mood := "neutro"
var _wings: Array[Node3D] = []
var _tail_p: Node3D
var _tail_tip: Node3D
var _step_acc := 0.0
var _sit_t := 0.0     # da quanto è seduto/coricato: l'assestamento vive qui
# il sonno: la fase del respiro (per la zeta) e il fremito del sogno
var _sonno_r_prev := 1.0
var _sonno_fremito := 4.0
var _sonno_fremito_t := 0.0
var _sonno_fremito_i := 0
var _emote_cd := 0.0

# il piano Lua composto dal Regista: lista di passi da recitare
const LP_SIMBOLI := {"fiore": "✿", "cibo": "!", "amico": "♥", "dormire": "z",
		"fuoco": "~", "pioggia": "…", "felice": "!", "casa": "♥",
		"sole": "!", "pesce": "!", "ciao": "♥"}
var _plan: Array = []
var _plan_i := 0

# i compiti del cervello (spuntini, annaffiature, meraviglie…):
# il VillagerBrain decide, questi stati recitano
var greet_enabled := true      # il timido saluta solo gli amici veri
var _task_cb := Callable()
var _task_acc := 0.0
var _can: Node3D               # il bricco in zampa mentre annaffia

# --- il pasto (scenes/npc/Pasto.gd): la ciotola regalata, mangiata davvero ---
const PASTO := preload("res://scenes/npc/Pasto.gd")
var _pasto_ciotola: Node3D     # la ciotola in mano, mentre dura
var _pasto_cibo: Node3D        # il disco di cibo dentro: cala a ogni morso
var _pasto_vapore: GPUParticles3D
var _pasto_caldo := true
var _pasto_adorato := false
var _pasto_col := Color("e8944a")
var _pasto_t := 0.0            # da quanto dura il rituale
var _pasto_morsi := 0          # quanti morsi già dati (per i suoni e le briciole)
var _pasto_sbuffi := 0
var _pasto_grazie := false
var _pasto_ritorno := ""       # lo stato a cui tornare quando ha finito
var _pasto_in_corso := false   # il recinto: mentre è acceso, il corpo è del pasto
var _pasto_zampe := 0.0        # la quota delle zampine di QUESTO chibi (misurata una volta)


func setup(p_species: String, entry: Vector3, plaza: Vector3, pois: Array[Vector3],
		bench: Node3D, exit_a: Vector3, exit_b: Vector3) -> void:
	species = p_species
	position = entry
	_pois = pois
	_bench = bench
	_exit_a = exit_a
	_exit_b = exit_b
	_gift_pos = plaza
	_walk_to(plaza, "browse")


## Arriva con la valigia: prima tappa, la casa da visitare.
func setup_candidate(house: Dictionary, entry: Vector3, exit_a: Vector3, exit_b: Vector3) -> void:
	mode = "candidate"
	_house = house
	position = entry
	_exit_a = exit_a
	_exit_b = exit_b
	_build_suitcase()
	_walk_to(house["front"], "c_inspect")


## Vive già qui: si aggira attorno a casa sua.
func setup_resident(house: Dictionary) -> void:
	mode = "resident"
	_house = house
	position = house["front"]
	_enter_state("r_idle")


func _ready() -> void:
	# le porte del villaggio si aprono anche per loro (BuildSystem
	# interroga il gruppo): niente più residenti-fantasma attraverso l'anta
	add_to_group("passanti")
	_sfx = get_node_or_null(^"/root/Sfx")
	# nodo runtime: i unique name non risolvono, serve il path relativo
	(func(): _player_ref = get_node_or_null("../../Player")).call_deferred()
	_vis = Node3D.new()
	add_child(_vis)
	if not dna.is_empty():
		# villager generato: il corpo nasce dal DNA, e con lui la voce
		_monta_corpo()
		_speed = 1.45
		_voice = CHIBIESE.voice(dna)
		_voice_player = AudioStreamPlayer3D.new()
		_voice_player.position = Vector3(0, 0.8, 0)
		_voice_player.max_distance = 16.0
		_voice_player.volume_db = -7.0
		# il bus lo dice Sfx: senza, la voce finisce sul Master e nessun
		# cursore la governa tranne il generale
		if _sfx:
			_voice_player.bus = _sfx.bus_voci()
		add_child(_voice_player)
	elif species == "passerotto":
		_build_bird()
		_speed = 1.7
	else:
		_build_hedgehog()
		_speed = 1.25
	# entra in scena sbocciando dall'erba alta
	_vis.scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(_vis, "scale", Vector3.ONE, 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _sfx and species == "passerotto":
		_sfx.play("chirp1", -16.0, 1.1)


# ---------------------------------------------------------------- corpi

func _mat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo_color", color)
	return m


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m


func _ball(parent: Node3D, r: float, mat: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 18
	sm.rings = 10
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _cone(parent: Node3D, r: float, h: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_hedgehog() -> void:
	var cream := _mat(Color("e8d5b8"))
	var brown := _mat(Color("8a6a4a"))
	var dark := _flat(Color("2a1d1d"))

	# corpo tondo, pancino chiaro
	_ball(_vis, 0.22, cream, Vector3(0, 0.2, 0), Vector3(1, 0.82, 1.1))
	# il mantello di aculei: coroncina di coni morbidi sulla schiena
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 16:
		var a := float(i) / 16.0 * TAU
		var ring := 0.13 if i % 2 == 0 else 0.08
		var spike := _cone(_vis, 0.045, 0.14, brown,
				Vector3(cos(a) * ring, 0.3 + (0.04 if i % 2 == 0 else 0.09), sin(a) * ring * 1.15 + 0.03))
		spike.rotation.x = cos(a) * -0.5
		spike.rotation.z = sin(a) * 0.5 * signf(cos(a) + 0.01)
		spike.rotation.y = rng.randf() * 0.4

	# testolina che sporge davanti
	_head = Node3D.new()
	_head.position = Vector3(0, 0.22, -0.2)
	_vis.add_child(_head)
	_ball(_head, 0.12, cream, Vector3.ZERO, Vector3(1, 0.9, 1.1))
	# musetto a punta col nasino
	_cone(_head, 0.07, 0.14, cream, Vector3(0, -0.02, -0.1)).rotation.x = -PI * 0.5
	_ball(_head, 0.025, dark, Vector3(0, -0.02, -0.18))
	# occhietti
	for side: float in [-1.0, 1.0]:
		_ball(_head, 0.022, dark, Vector3(side * 0.055, 0.04, -0.09))
		_ball(_head, 0.008, _flat(Color.WHITE), Vector3(side * 0.05, 0.05, -0.105))
	# orecchiette
	for side: float in [-1.0, 1.0]:
		_ball(_head, 0.03, brown, Vector3(side * 0.075, 0.1, -0.02), Vector3(1, 1, 0.5))
	# zampette
	for side: float in [-1.0, 1.0]:
		for fz in [-0.08, 0.1]:
			_ball(_vis, 0.035, brown, Vector3(side * 0.1, 0.035, fz), Vector3(1, 0.7, 1.2))


func _build_bird() -> void:
	var feather := _mat(Color("b08858"))
	var breast := _mat(Color("f3e2c8"))
	var dark := _flat(Color("2a1d1d"))
	var beak := _mat(Color("e8a04a"))

	# corpicino paffuto col pancino chiaro
	_ball(_vis, 0.15, feather, Vector3(0, 0.2, 0), Vector3(1, 0.95, 1.15))
	_ball(_vis, 0.115, breast, Vector3(0, 0.16, -0.06), Vector3(1, 0.85, 0.9))
	# testolina
	_head = Node3D.new()
	_head.position = Vector3(0, 0.35, -0.06)
	_vis.add_child(_head)
	_ball(_head, 0.1, feather, Vector3.ZERO)
	_cone(_head, 0.035, 0.08, beak, Vector3(0, -0.01, -0.11)).rotation.x = -PI * 0.5
	for side: float in [-1.0, 1.0]:
		_ball(_head, 0.02, dark, Vector3(side * 0.05, 0.02, -0.075))
		_ball(_head, 0.007, _flat(Color.WHITE), Vector3(side * 0.046, 0.028, -0.088))
	# alette (pivot alla spalla per il battito)
	for side: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(side * 0.12, 0.24, 0.02)
		_vis.add_child(wing)
		_ball(wing, 0.085, feather, Vector3(side * 0.035, -0.02, 0.02), Vector3(0.45, 0.75, 1.25))
		_wings.append(wing)
	# codina
	_tail_p = Node3D.new()
	_tail_p.position = Vector3(0, 0.22, 0.13)
	_vis.add_child(_tail_p)
	var tail := _ball(_tail_p, 0.07, feather, Vector3(0, 0.02, 0.05), Vector3(0.6, 0.25, 1.3))
	tail.rotation.x = 0.5
	# zampine
	for side: float in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.008
		cm.bottom_radius = 0.008
		cm.height = 0.07
		leg.mesh = cm
		leg.material_override = beak
		leg.position = Vector3(side * 0.05, 0.05, 0)
		_vis.add_child(leg)


# valigetta da trasloco: marrone, adesivi pastello, manico
static func make_suitcase() -> Node3D:
	var s := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, 0.14, 0.07)
	body.mesh = bm
	var brown := StandardMaterial3D.new()
	brown.albedo_color = Color("a8794f")
	body.material_override = brown
	s.add_child(body)
	var strip := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.205, 0.03, 0.075)
	strip.mesh = sm
	var cream := StandardMaterial3D.new()
	cream.albedo_color = Color("e8d5b8")
	strip.material_override = cream
	s.add_child(strip)
	var handle := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.02
	tm.outer_radius = 0.042
	handle.mesh = tm
	handle.material_override = cream
	handle.position = Vector3(0, 0.09, 0)
	s.add_child(handle)
	for st in [[Vector3(0.05, 0.03, 0.038), Color("f4b8c8")], [Vector3(-0.055, -0.03, 0.038), Color("8fc0c8")]]:
		var sticker := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.026
		cm.bottom_radius = 0.026
		cm.height = 0.008
		sticker.mesh = cm
		var smat := StandardMaterial3D.new()
		smat.albedo_color = st[1]
		sticker.material_override = smat
		sticker.position = st[0]
		sticker.rotation.x = PI * 0.5
		s.add_child(sticker)
	return s


func _build_suitcase() -> void:
	_suitcase = make_suitcase()
	_suitcase.position = Vector3(0.28, 0.18, 0.1)
	_suitcase.rotation.y = 0.25
	_vis.add_child(_suitcase)


# ---------------------------------------------------------------- stati

## IL RECINTO DEL PASTO. Finché mangia, il corpo è suo: nessuno gli cambia
## stato e nessuno lo manda a spasso. Senza questo, la routine dei residenti
## (o il cervello, o un piano del Regista) chiama `_enter_state` a metà
## morso e il vicino se ne va a passeggio con la ciotola incollata al petto
## — è successo davvero, alla prima prova in scena. Il pasto dura cinque
## secondi: aspettare che finisca non toglie niente a nessuno.
func _pasto_occupa(nuovo: String) -> bool:
	return _pasto_in_corso and nuovo != "r_pasto"


func _walk_to(pos: Vector3, next: String) -> void:
	if _pasto_in_corso:
		return
	position.y = 0.0  # rinormalizza: chi arriva da panchina/onsen/scala torna a terra
	_target = Vector3(pos.x, 0, pos.z)
	_next_state = next
	_state = "walk"


func _enter_state(s: String) -> void:
	if _pasto_occupa(s):
		return
	_state = s
	# ogni seduta ricomincia dall'ASSESTAMENTO (plop, fianchi, sospiro)
	_sit_t = 0.0
	match s:
		"browse":
			if _poi_i < _pois.size():
				_walk_to(_pois[_poi_i], "inspect")
			else:
				_go_bench_or_gift()
		"inspect":
			_timer = randf_range(3.0, 4.5)
			_emote("?", Color(0.55, 0.45, 0.75))
		"sit":
			_timer = randf_range(8.0, 12.0)
			_mount_bench()
		"gift":
			_timer = 1.4
			_drop_gift()
		"leave":
			_walk_to(_exit_a, "leave2")
		"leave2":
			_walk_to(_exit_b, "despawn")
		"despawn":
			var tw := create_tween()
			tw.tween_property(_vis, "scale", Vector3.ONE * 0.03, 0.5) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				finished.emit()
				queue_free())
		"on_dip":
			_timer = 0.0
		"on_soak":
			# il sospiro di chi si scioglie nell'acqua calda
			_timer = randf_range(12.0, 16.0)
			speak(["~", "~"], "triste")
			_spawn_heart()
		"on_out":
			_timer = 0.0
		"write":
			# davanti alla lavagna, gessetto alla zampa
			_timer = 3.4
		"th_up", "th_down":
			_timer = 0.0
		"th_perch":
			# «ya-ho!» dal trespolo, con un cuoricino
			_timer = randf_range(6.0, 9.0)
			speak(["ciao", "felice"], "felice")
			_spawn_heart()
		"c_inspect":
			# gira intorno alla casa col naso in su
			_timer = 5.0
			_emote("?", Color(0.55, 0.45, 0.75))
		"c_wait":
			# aspetta sull'uscio: c'è qualcuno che mi dà il benvenuto?
			_timer = 26.0
		"c_decide":
			# tocca al Visitors leggere la mente e dare il verdetto
			pass
		"r_settle":
			_timer = 2.2
			_spawn_heart()
			if _suitcase and is_instance_valid(_suitcase):
				_suitcase.queue_free()
				_suitcase = null
		"r_idle":
			_timer = randf_range(4.0, 8.0)
		"r_wander":
			# `_house` PUÒ ESSERE VUOTO, e questo stato è il ripiego
			# universale: `Visitors._recita()` ci manda chiunque non abbia
			# una scena da recitare («nessuna scena disponibile: due passi
			# intorno a casa»). Con `_house["front"]` la funzione di stato
			# si INTERROMPE a metà, `_walk_to` non viene mai chiamato, e
			# quel vicino resta piantato lì per sempre — senza un errore
			# che qualcuno guardi. Si vede facendo girare CHIBI_ESTETISTA.
			# La forma giusta era già scritta più sotto (riga ~1692):
			# `.get("front", position)`, cioè «se non hai una casa, gira
			# intorno a dove sei».
			var front: Vector3 = _house.get("front", position)
			var a := randf() * TAU
			_walk_to(front + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, 3.2), "r_idle")
		"r_sniff":
			_timer = randf_range(3.5, 5.5)
			_emote("?", Color(0.55, 0.45, 0.75))
		"r_bench":
			if _routine_aux and is_instance_valid(_routine_aux):
				# DOVE CI SI SIEDE. Di norma 52 cm sopra l'origine del
				# mobile — la misura della Panchina, l'unico pezzo per cui
				# questo stato era stato scritto. Ma un pezzo puo'
				# dichiarare il SUO punto col meta "seduta": le gradinate,
				# la poltrona del salone e la panchetta del pianoforte
				# hanno ancoraggi che SONO gia' il posto, e sollevarli di
				# mezzo metro metterebbe il vicino a mezz'aria.
				# (Chi chiamava questo stato senza `aux` non sollevava
				# niente: il corpo si accovacciava a terra DENTRO il
				# mobile — il cliente del salone dentro la poltrona, il
				# pubblico conficcato nell'alzata di pietra.)
				var off: Vector3 = _routine_aux.get_meta("seduta", SEDUTA_PREDEFINITA)
				var seat: Vector3 = _routine_aux.global_transform * off
				# E SI GUARDA QUELLO CHE SI E' VENUTI A GUARDARE. `_fire_look`
				# e' il terzo argomento di `do_routine` e questo stato non lo
				# leggeva: il pubblico del concerto restava girato come
				# l'aveva lasciato l'ultimo passo, e il cliente del salone
				# non guardava lo specchio.
				if _fire_look != Vector3.ZERO:
					var verso := (_fire_look - seat) * Vector3(1, 0, 1)
					if verso.length() > 0.01:
						_yaw = atan2(-verso.x, -verso.z)
				else:
					_yaw = _routine_aux.rotation.y + PI
				var tw := create_tween()
				tw.tween_property(self, "position", seat, 0.4) \
						.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_timer = _routine_durata if _routine_durata > 0.0 else randf_range(14.0, 22.0)
		"r_attesa":
			# arrivato al posto dell'appuntamento: si volta verso il
			# fenomeno e aspetta. Il timer e' lunghissimo di proposito —
			# a decidere quando finisce e' chi ha fissato l'appuntamento
			# (le Promesse), non un cronometro qui dentro.
			_timer = 9999.0
			var to_att := _fire_look - position
			to_att.y = 0.0
			if to_att.length() > 0.05:
				_yaw = atan2(-to_att.x, -to_att.z)
		"r_confronto":
			# arrivato: si volta verso di te e resta IN PIEDI. Niente sedia,
			# niente sorriso — è venuto a dirti una cosa, e la posa lo dice
			# prima della battuta. L'uscita dipende SOLO dal timer: nessun
			# nodo ausiliario da aspettare, nessun modo di restare bloccati.
			var to_conf := _fire_look - position
			if to_conf.length() > 0.01:
				_yaw = atan2(-to_conf.x, -to_conf.z)
			_timer = randf_range(7.0, 10.0)
		"r_fire":
			# si accomoda e guarda il fuoco: la serata è questa
			var to_fire := _fire_look - position
			_yaw = atan2(-to_fire.x, -to_fire.z)
			_timer = 9999.0
		"lp_next":
			# il passo del piano Lua è compiuto: si passa al prossimo
			_next_plan_step()
		"tk_nibble":
			# spuntino: musetto tra le foglie, briciole di felicità
			_timer = 3.2
		"tk_water":
			# annaffia lui: bricco in zampa, il Garden fa piovere sull'aiuola
			_timer = 2.6
			_make_hand_can()
			if _task_cb.is_valid():
				_task_cb.call()
			_task_cb = Callable()
		"tk_wonder":
			# resta incantato: lo stagno, i fiori, il mondo
			_timer = 4.5
			_emote("!", Color(0.55, 0.7, 0.9))
		"tk_chat_fungo":
			# le confidenze al fungo: prima la domanda, poi il cuoricino
			_timer = 4.2
			chat_bubble("?")
			speak(["~", "~"], "domanda")
		"tk_sing":
			# la serenata alla luna, ognuno con la sua voce — e con le
			# parole VERE: «nu-la, ki-li, la-lo» (luna, stelle, cantare)
			_timer = 5.5
			_emote("♪", Color(0.75, 0.65, 0.95))
			speak(["luna", "stelle", "cantare", "~"], "felice")
		"tk_twirl":
			_timer = 1.1
			var tw := create_tween()
			tw.tween_property(_vis, "rotation:y", TAU, 0.9) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_callback(func(): _vis.rotation.y = 0.0)
		"tk_startle":
			# lo spavento buffo: saltello all'indietro, "!" sopra la testa
			# — e la parola giusta: «hu-du!» (paura)
			_timer = 1.3
			_emote("!", Color(0.95, 0.6, 0.4))
			speak(["paura"], "domanda")
			var back := global_transform.basis.z.normalized()
			var tw2 := create_tween()
			tw2.tween_property(self, "position", position + back * 0.7, 0.35) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"tk_nap":
			# il pisolino dura quanto serve alle sue tre fasi: accovacciarsi
			# (1.1), dormire davvero (qualche respiro pieno), stiracchiarsi
			# (1.6). In sei secondi non ci starebbero.
			_timer = NAP_DUR
			_sonno_r_prev = 1.0
			# la frase gia' in canna va zittita, o ci si addormenta
			# parlando (il parlato vince sull'espressione "dorme")
			if _voice_player and _voice_player.playing:
				_voice_player.stop()
		"tk_stella":
			# naso all'insù: le stelle sono uno spettacolo che basta
			_timer = 8.0
		"tk_sasso":
			_timer = 2.6
			_emote("♦", Color(0.65, 0.6, 0.75))


func _go_bench_or_gift() -> void:
	if _bench and is_instance_valid(_bench):
		var approach: Vector3 = _bench.global_transform * Vector3(0, 0, 0.7)
		_walk_to(approach, "sit")
	else:
		_walk_to(_gift_pos, "gift")


func _mount_bench() -> void:
	if _bench == null or not is_instance_valid(_bench):
		_walk_to(_gift_pos, "gift")  # panchina demolita mentre ci camminava verso
		return
	# il riccio si accoccola sul sedile, il passerotto si appollaia in cima.
	# ADESSO LO DICHIARA IL MOBILE, tutti e due: la seconda copia della
	# costante era tarata sulla panchina VECCHIA, e il giorno in cui la
	# doga alta è scesa a 0.8245 il passerotto è rimasto appollaiato 3,5 cm
	# sopra il legno e 2 cm dietro — appeso al vento, senza che niente lo
	# segnalasse (nessun test guarda dove finisce un uccello).
	var offset: Vector3 = _bench.get_meta("seduta", SEDUTA_PREDEFINITA)
	if species == "passerotto":
		offset = _bench.get_meta("posatoio", POSATOIO_PREDEFINITO)
	var dest: Vector3 = _bench.global_transform * offset
	_yaw = _bench.rotation.y + PI
	var tw := create_tween()
	tw.tween_property(self, "position", dest, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _sfx:
		_sfx.play("step_grass2", -20.0, 1.4)


func _drop_gift() -> void:
	wants_gift.emit(global_position + Vector3(0, 0, 0), species)
	_spawn_heart()
	if _sfx and species == "passerotto":
		_sfx.play("chirp2", -16.0, 1.15)


func _process(delta: float) -> void:
	_t += delta
	# via la recita del frame scorso: gli stati ripartono da un rig pulito
	# (chi scrive in assoluto sovrascrive comunque; chi non scrive — idle —
	# ritrova il valore base, senza accumuli)
	_recita_togli()
	rotation.y = _yaw
	# il metro del passo: velocita' vera, blend, curva (per ogni stato)
	_gait_misura(delta)
	_emote_cd -= delta
	_speak_cd -= delta
	_scena_t = maxf(0.0, _scena_t - delta)
	# mentre parla, la testolina annuisce a tempo con la voce
	# (scalato su delta e clampato: niente derive a framerate alti)
	if _voice_player and _voice_player.playing and _head:
		_head.rotation.x = clampf(_head.rotation.x + sin(_t * 14.0) * 3.0 * delta, -0.35, 0.35)
		_head.rotation.z = clampf(_head.rotation.z + sin(_t * 9.0) * 1.8 * delta, -0.25, 0.25)
	elif _head:
		# a fine frase la testolina torna dritta (gli stati che la posano
		# in assoluto sovrascrivono comunque dopo, nel match)
		_head.rotation.x = move_toward(_head.rotation.x, 0.0, delta * 1.5)
		_head.rotation.z = move_toward(_head.rotation.z, 0.0, delta * 1.5)

	# il tremolio dell'età: un fremito appena percettibile del collo,
	# sommato alla contro-rotazione della gobba (il collo è nostro:
	# nessuno stato lo tocca, il musetto continua a recitare intatto)
	if _collo and _eta > 0.55:
		var tr := smoothstep(0.55, 1.0, _eta) * 0.012
		# nel sonno il tremolio si acquieta (non si spegne: un vecchio che
		# dorme trema ancora un po', ed è giusto così)
		if _state == "tk_nap":
			tr *= 0.25
		_collo.rotation.z = sin(_t * 16.0) * tr
		_collo.rotation.x = 0.26 * _eta + sin(_t * 12.3) * tr

	match _state:
		"walk":
			var to := _target - position
			to.y = 0.0
			var dist := to.length()
			if dist < 0.12:
				_enter_state(_next_state)
			else:
				var dir := to / dist
				_yaw = lerp_angle(_yaw, atan2(-dir.x, -dir.z), 1.0 - exp(-7.0 * delta))
				position += dir * _speed * _move_gait(delta)
			_anim_move(delta)
		"inspect":
			_timer -= delta
			_anim_inspect()
			if _timer <= 0.0:
				_poi_i += 1
				_enter_state("browse")
		"sit":
			_timer -= delta
			_anim_sit()
			if _timer <= 0.0 and _bench and is_instance_valid(_bench):
				var down: Vector3 = _bench.global_transform * Vector3(0, 0, 0.85)
				_gift_pos = down
				var tw := create_tween()
				tw.tween_property(self, "position", Vector3(down.x, 0, down.z), 0.4) \
						.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				tw.tween_callback(func(): _enter_state("gift"))
				_state = "dismount"
			elif _timer <= 0.0:
				_enter_state("gift")
		"gift":
			_timer -= delta
			_anim_idle()
			if _timer <= 0.0:
				_enter_state("leave")
		"dismount":
			pass
		"c_inspect":
			_timer -= delta
			_anim_inspect()
			# guarda la casa, non il vuoto
			if _house.has("bed") and is_instance_valid(_house["bed"]):
				var to_bed: Vector3 = (_house["bed"] as Node3D).global_position - position
				_yaw = lerp_angle(_yaw, atan2(-to_bed.x, -to_bed.z), 1.0 - exp(-4.0 * delta))
			if _timer <= 0.0:
				_enter_state("c_wait")
		"c_wait":
			_timer -= delta
			_anim_idle()
			if _timer <= 0.0:
				_enter_state("c_decide")
		"c_decide":
			_anim_idle()
		"r_settle":
			_timer -= delta
			_anim_idle()
			if _timer <= 0.0:
				mode = "resident"
				_enter_state("r_idle")
		"r_idle":
			_timer -= delta
			_anim_sit()
			_resident_greet(delta)
			if _timer <= 0.0:
				_enter_state("r_wander")
		"r_sniff":
			_timer -= delta
			_anim_inspect()
			_resident_greet(delta)
			if _timer <= 0.0:
				_spawn_heart()
				_enter_state("r_idle")
		"r_bench":
			_timer -= delta
			_anim_sit()
			if _timer <= 0.0:
				# SENZA `aux` NON SI SCENDEVA. Il ramo pretendeva il mobile
				# per calcolare dove rimettere i piedi, e chi era stato
				# fatto sedere senza (il pianista del concerto) restava
				# seduto FINO ALLA ROUTINE DEL MATTINO. Adesso, se il
				# mobile non c'e' o e' sparito, ci si alza dov'e'.
				var down := position
				if _routine_aux and is_instance_valid(_routine_aux):
					down = _routine_aux.global_transform * Vector3(0, 0, 0.8)
				var tw := create_tween()
				tw.tween_property(self, "position", Vector3(down.x, 0, down.z), 0.4) \
						.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				tw.tween_callback(func(): _enter_state("r_idle"))
				_state = "dismount"
		"r_attesa":
			# in piedi, che respira, rivolto al fenomeno — e se arrivi ti
			# saluta come sa fare lui (il saluto della sua indole)
			_anim_idle()
			_resident_greet(delta)
		"r_confronto":
			_timer -= delta
			_anim_idle()
			if _timer <= 0.0:
				_enter_state("r_idle")
		"r_pasto":
			# il pasto si prende il corpo per tutta la sua durata: nessun
			# altro stato ci scrive sopra, o la ciotola resterebbe a mezz'aria
			_timer -= delta
			_pasto_recita(delta)
			if _timer <= 0.0:
				_pasto_via()
				_enter_state(_pasto_ritorno if _pasto_ritorno != "" else "r_idle")
		"r_fire":
			_anim_sit()
			_resident_greet(delta)
		"lp_wait":
			_timer -= delta
			_anim_idle()
			_resident_greet(delta)
			if _timer <= 0.0:
				_next_plan_step()
		"lp_sniff":
			_timer -= delta
			_anim_inspect()
			if _timer <= 0.0:
				_next_plan_step()
		"tk_nibble":
			_timer -= delta
			_anim_inspect()
			_task_acc -= delta
			if _task_acc <= 0.0:
				_task_acc = 1.0
				if _sfx:
					_sfx.munch()
			if _timer <= 0.0:
				_spawn_heart()
				_finish_task()
		"tk_water":
			# versata a due zampine, col bricco che ondeggia appena
			_timer -= delta
			_anim_idle()
			if _c_arms.size() == 2:
				_c_arms[0].rotation.x = 0.5 + sin(_t * 2.2) * 0.03
				_c_arms[1].rotation.x = 0.62 + sin(_t * 2.2) * 0.03
			if _timer <= 0.0:
				_clear_can()
				_finish_task()
		"tk_chat_fungo", "tk_sasso":
			_timer -= delta
			_anim_inspect()
			if _timer <= 0.0:
				if _state == "tk_chat_fungo":
					chat_bubble("♥")
				_finish_task()
		"tk_wonder":
			_timer -= delta
			_anim_idle()
			_head.rotation.x = -0.2 + sin(_t * 0.7) * 0.06
			if _timer <= 0.0:
				_spawn_heart()
				_finish_task()
		"tk_sing":
			_timer -= delta
			_anim_idle()
			_head.rotation.x = -0.3 + sin(_t * 0.9) * 0.05
			_vis.rotation.z = sin(_t * 2.2) * 0.05
			_task_acc -= delta
			if _task_acc <= 0.0:
				_task_acc = 1.7
				_emote("♪", Color(0.75, 0.65, 0.95))
			if _timer <= 0.0:
				_finish_task()
		"tk_twirl", "tk_startle":
			# IL RESPIRO PRIMA DI TUTTO. Senza, il corpo resta esattamente
			# come l'ha lasciato l'ultimo passo — gamba in avanti, sollevata,
			# nessun assestamento — e la posa GIRA SU SE' STESSA o scivola
			# indietro col tween. Un corpo fermo a meta' falcata non e' una
			# posa: e' un fermo immagine.
			_anim_idle()
			_timer -= delta
			if _timer <= 0.0:
				_finish_task()
		"tk_nap":
			_timer -= delta
			# il sonno vero: si accovaccia, RESPIRA (profondo e asimmetrico),
			# sogna, e si stiracchia al risveglio. La zeta esce sull'espiro,
			# dentro _anim_dorme: il suo ritmo è quello del petto
			_anim_dorme(NAP_DUR, delta)
			if _timer <= 0.0:
				_finish_task()
		"tk_stella":
			_timer -= delta
			_anim_idle()
			_head.rotation.x = -0.42 + sin(_t * 0.5) * 0.04
			if _timer <= 0.0:
				_spawn_heart()
				_finish_task()
		"write":
			# scrive il compleanno: zampina che scarabocchia, testa che segue.
			# `_anim_idle()` PRIMA: senza, gambe e corpo restavano inchiodati
			# a meta' passo per tutti i 3,4 secondi — mentre il toast del
			# compleanno invita a guardare. (Misurato eseguendo: dopo il
			# cammino e dopo tre secondi di «write», i canali erano identici
			# al terzo decimale.)
			_anim_idle()
			var to_board := _write_look - position
			_yaw = lerp_angle(_yaw, atan2(-to_board.x, -to_board.z), 1.0 - exp(-7.0 * delta))
			if _c_arms.size() == 2:
				(_c_arms[1] as Node3D).rotation.x = -1.3 + sin(_t * 9.0) * 0.3
			_head.rotation.x = 0.12 + sin(_t * 9.0) * 0.05
			_head.rotation.y = sin(_t * 2.2) * 0.1
			_timer -= delta
			if _timer <= 0.0:
				if _c_arms.size() == 2:
					(_c_arms[1] as Node3D).rotation.x = 0.0
				_spawn_heart()
				speak(["si", "felice"], "felice")
				_finish_task()
		"on_dip":
			# scivola nell'acqua, piano piano
			_timer += delta / 1.4
			var t := minf(_timer, 1.0)
			position = (_onsen["edge"] as Vector3).lerp(_onsen["soak"], t)
			position.y = -0.34 * smoothstep(0.0, 1.0, t)
			if _timer >= 1.0:
				_enter_state("on_soak")
		"on_soak":
			# a mollo: dondolio d'acqua, testa all'indietro, beatitudine
			_timer -= delta
			position.y = -0.34 + sin(_t * 1.1) * 0.02
			_head.rotation.x = -0.12 + sin(_t * 0.6) * 0.04
			_head.rotation.y = sin(_t * 0.35) * 0.15
			if _c_arms.size() == 2:
				(_c_arms[0] as Node3D).rotation.x = 0.3
				(_c_arms[1] as Node3D).rotation.x = 0.3
			if _timer <= 0.0:
				_enter_state("on_out")
		"on_out":
			_timer += delta / 1.2
			var t := minf(_timer, 1.0)
			position = (_onsen["soak"] as Vector3).lerp(_onsen["edge"], t)
			position.y = -0.34 * (1.0 - smoothstep(0.0, 1.0, t))
			if _timer >= 1.0:
				position.y = 0.0
				_wear_robe(false)
				_spawn_heart()
				_enter_state("r_idle")
		"th_up":
			# su per i pioli, un saltello per piolo
			_timer += delta / 2.3
			var t := minf(_timer, 1.0)
			position = (_th["base"] as Vector3).lerp(_th["top"], t)
			position.y += absf(sin(t * PI * 7.0)) * 0.06
			var up_dir: Vector3 = _th["top"] - _th["base"]
			_yaw = lerp_angle(_yaw, atan2(-up_dir.x, -up_dir.z), 1.0 - exp(-8.0 * delta))
			_anim_move(delta)
			if _timer >= 1.0:
				position = _th["perch"]
				_enter_state("th_perch")
		"th_perch":
			_timer -= delta
			_anim_sit()
			if _player_ref:
				var to_p := _player_ref.global_position - position
				_yaw = lerp_angle(_yaw, atan2(-to_p.x, -to_p.z), 1.0 - exp(-4.0 * delta))
			if _timer <= 0.0:
				_enter_state("th_down")
		"th_down":
			_timer += delta / 2.0
			var t := minf(_timer, 1.0)
			position = (_th["top"] as Vector3).lerp(_th["base"], t)
			position.y += absf(sin(t * PI * 6.0)) * 0.05
			_anim_move(delta)
			if _timer >= 1.0:
				position.y = 0.0
				_enter_state("r_idle")

	# --- il volto vivo, IN CODA (dopo che il match ha posato la testa, così
	# lo sguardo legge la testa già inclinata): espressione dallo stato o
	# dall'umore mentre parla, sguardo sul mobile o sul giocatore vicino ---
	if _face:
		if _voice_player and _voice_player.playing:
			_face.set_talking(true)
			_face.set_mood(_mood)
		else:
			_face.set_talking(false)
			_face.set_expression(_expr_for_state(_state))
		if _state == "tk_nap":
			# a occhi chiusi non si insegue nessuno: chi dorme, dorme
			_face.clear_gaze()
		elif LOOK_STATES.has(_state) and _target != Vector3.ZERO:
			_face.look_at_world(_target + Vector3(0, 0.35, 0))
		elif _player_ref and is_instance_valid(_player_ref) \
				and global_position.distance_to(_player_ref.global_position) < 4.5:
			_face.look_at_node(_player_ref)
		else:
			_face.clear_gaze()
		_face.update(delta)

	# --- LA RECITA DEL CORPO, ultimissima: le posture della ribellione si
	# stendono SOPRA ciò che stati e volto hanno già posato ---
	_recita_applica(delta)


# passo del corpo: il passerotto avanza a scatti (solo mentre è in aria)
func _move_gait(delta: float) -> float:
	if species == "passerotto":
		var hop := fposmod(_t * 2.4, 1.0)
		return delta * (1.7 if hop < 0.55 else 0.15)
	# l'età si sente nel fiato: ogni tanto l'anziano si ferma un attimo
	# a metà strada, e poi riparte piano
	if _eta > 0.55:
		var ciclo := fposmod(_t, 7.5)
		if ciclo < 1.3:
			return delta * 0.12
	return delta


# ---------------------------------------------------------------- anims

func _anim_move(delta: float) -> void:
	if not dna.is_empty():
		# il ciclo condiviso: la stessa specie di Mochi (fase dalla
		# velocita' vera, blend, torsione, banco in curva, appoggi sonori)
		_gait_chibi()
		return
	if species == "passerotto":
		var hop := fposmod(_t * 2.4, 1.0)
		var air := sin(PI * minf(hop / 0.55, 1.0))
		_vis.position.y = air * 0.16
		# squash a terra, stretch in volo
		_vis.scale.y = lerpf(_vis.scale.y, 0.86 + air * 0.24, 1.0 - exp(-18.0 * delta))
		for i in _wings.size():
			_wings[i].rotation.z = (1.0 if i == 0 else -1.0) * air * -0.9
		_tail_p.rotation.x = -air * 0.3
		_head.rotation.x = air * 0.15
		_step_acc += delta
		if hop > 0.9 and _step_acc > 0.3:
			_step_acc = 0.0
			if _sfx:
				_sfx.play("step_grass" + str(1 + randi() % 3), -24.0, 1.5)
	else:
		# trotterello: dondolio laterale + zampettio fitto
		_vis.position.y = absf(sin(_t * 9.0)) * 0.03
		_vis.rotation.z = sin(_t * 9.0) * 0.07
		_head.rotation.x = 0.1 + sin(_t * 3.2) * 0.14
		_head.rotation.y = sin(_t * 1.1) * 0.12
		_step_acc += delta
		if _step_acc > 0.3:
			_step_acc = 0.0
			if _sfx:
				_sfx.play("step_grass" + str(1 + randi() % 3), -25.0, 1.2)


# da fermi i piedini tornano a posto con dolcezza (mai congelati a mezz'aria)
func _relax_legs() -> void:
	for gamba in _c_legs:
		gamba.rotation.x = lerpf(gamba.rotation.x, 0.0, 0.18)
		gamba.position.y = lerpf(gamba.position.y, 0.16, 0.18)


# --------------------------------------------- il passo condiviso chibi

## Misura ogni frame cio' che serve al ciclo: la velocita' VERA (mai
## moonwalk: la fase avanza coi metri percorsi), il blend che accende e
## spegne il passo da solo, l'inclinazione in curva e l'orologio della
## coda. Gira per OGNI stato: fermarsi a meta' passo sfuma, non scatta.
func _gait_misura(delta: float) -> void:
	if dna.is_empty() or _vis == null:
		return
	_andatura_pronta()
	_andatura.eta = _eta
	_andatura.riparo = _riparo
	_andatura.misura(delta, global_position, _yaw)
	# lo stato che l'andatura non conosce: mentre dorme la coda arrotolata
	# e le spalle chiuse le scrive `_anim_dorme`, e non vanno rilassate
	if _state != "tk_nap":
		_andatura.rilassa(delta)


## Il corpo del passo, fuso col blend: la STESSA specie di Mochi.
## Chiamato sia in cammino sia da fermo — e' il blend a decidere quanto
## ciclo si vede, mai lo stato.
func _gait_chibi() -> void:
	_andatura_pronta()
	_andatura.applica()


## L'andatura si aggancia al corpo la prima volta, e ogni volta che il
## corpo viene rifatto (l'estetista lo rimonta da capo: senza questo
## controllo il passo continuerebbe a muovere le braccia di un cadavere).
func _andatura_pronta() -> void:
	if _andatura != null and _andatura.vis == _vis and _andatura.testa == _head:
		return
	_andatura = ANDATURA.new()
	_andatura.parti({"head": _head, "arms": _c_arms, "legs": _c_legs,
			"ears": _c_ears, "tail": _tail_p, "tail_tip": _tail_tip}, _vis)
	_andatura.sfx = _sfx


func _anim_inspect() -> void:
	# si sporge incuriosito verso l'oggetto, la testa fa su e giù
	_relax_legs()
	_vis.position.y = absf(sin(_t * 5.0)) * 0.02
	_vis.rotation.x = -0.12 + sin(_t * 2.2) * 0.06
	_head.rotation.x = 0.25 + sin(_t * 4.0) * 0.18
	_head.rotation.z = sin(_t * 1.3) * 0.15
	if species == "passerotto" and _tail_p:
		_tail_p.rotation.x = sin(_t * 6.0) * 0.2
	if not dna.is_empty() and _c_arms.size() == 2:
		# zampine giunte davanti, come chi guarda una vetrina
		_c_arms[0].rotation.x = 0.5
		_c_arms[1].rotation.x = 0.5


## L'ASSESTAMENTO della seduta, PURO: a [param s] secondi dal sedersi,
## quanto plop (il tonfo col rimbalzo che muore), quanto sistemarsi dei
## fianchi, quanto sospiro (il petto che si alza a ~1.3s e le spalle che
## ricadono), quanto colpo di coda che si accomoda. A s≈3 è tutto zero:
## resta solo il respiro. Il test lo percorre punto a punto.
static func assesto_seduta(s: float) -> Dictionary:
	var calo := exp(-s * 1.6)
	return {
		"plop": -0.035 * exp(-s * 3.0) * cos(s * 9.0),
		"fianchi": sin(s * 7.0) * 0.06 * calo,
		"sospiro": exp(-pow((s - 1.3) / 0.35, 2.0)),
		"coda": sin(s * 8.0) * 0.5 * calo,
		"calo": calo,
	}


# ------------------------------------------------------------- il sonno
# Il pisolino era `_anim_sit()` + una "z" a timer: la posa da SEDUTO e un
# adesivo sopra. Un corpo che dorme però RESPIRA — ed è il respiro (non la
# posa, non la zetta) la differenza fra dormire ed essere spenti.
#
# Il ciclo ha tre tempi, tutti in una curva pura:
#   SETTLE (0 → 1.1 s)  si accovaccia: le anche scendono, le zampine si
#                       raccolgono sotto il musetto, il peso trova terra
#                       con un plop smorzato;
#   SONNO               il respiro lento e PROFONDO: T = 5 s (12 atti al
#                       minuto, contro i ~15 da sveglio) e soprattutto
#                       ASIMMETRICO — inspiro 38%, espiro 62%, come i
#                       polmoni veri. Un sin() puro si sente subito come
#                       una macchina; l'asimmetria è ciò che rende il
#                       petto vivo. Testa china, guancia che cede di
#                       lato, orecchie mosce, coda arrotolata contro il
#                       fianco (e MAI scodinzolante: smentirebbe tutto);
#   WAKE (ultimi 1.6 s) lo stiracchio: le zampine al cielo, il musetto
#                       in su, e il corpo che si ridistende.
# La "z" non esce a timer: esce sull'ESPIRO — il ritmo delle zeta È il
# ritmo del petto.

## Il periodo del respiro nel sonno (secondi) e i tempi delle tre fasi.
const SONNO_T := 5.0
const SONNO_SETTLE := 1.1
const SONNO_WAKE := 1.6
const SONNO_INSPIRO := 0.38   # la frazione di periodo che sale
const NAP_DUR := 14.0         # settle + ALMENO DUE respiri pieni + stiracchio


## La fase del respiro 0..1 — 0 = fondo dell'espiro, 1 = colmo
## dell'inspiro. ASIMMETRICA: sale in fretta (38% del ciclo) e scende
## piano (62%), come un torace vero. PURA.
static func respiro_fase(t: float) -> float:
	var p := fposmod(t / SONNO_T, 1.0)
	if p < SONNO_INSPIRO:
		# l'inspiro: sale morbido fino al colmo
		return 0.5 - 0.5 * cos(PI * p / SONNO_INSPIRO)
	# l'espiro: scende, più lungo e più dolce
	return 0.5 + 0.5 * cos(PI * (p - SONNO_INSPIRO) / (1.0 - SONNO_INSPIRO))


## Il corpo che dorme, PURO: a [param s] secondi dall'essersi coricato,
## con l'orologio [param t] e una durata totale [param dur], quanto vale
## ogni canale. Segni: + = giù/curva, − = su/in fuori.
## Canali: vy (il petto che si alza: il respiro) · vx (busto accasciato) ·
## hx/hy/hz (testa china, deriva del sogno, guancia appoggiata) ·
## ax/az (zampine raccolte) · lx/ly (gambe piegate, anche a terra) ·
## ear (orecchie mosce) · tx (coda arrotolata) · respiro (0..1) ·
## sveglio (0..1: 1 = fuori dal sonno).
static func assesto_sonno(s: float, t: float, dur: float) -> Dictionary:
	var settle := smoothstep(0.0, 1.0, clampf(s / SONNO_SETTLE, 0.0, 1.0))
	var w := clampf((s - maxf(dur - SONNO_WAKE, SONNO_SETTLE)) / SONNO_WAKE, 0.0, 1.0)
	var dorme := settle * (1.0 - smoothstep(0.0, 0.45, w))
	var r := respiro_fase(t)
	# la campana dello stiracchio: parte, culmina, si scioglie
	var stira := smoothstep(0.0, 0.28, w) * (1.0 - smoothstep(0.62, 1.0, w))
	# il peso che trova terra: un plop smorzato, come per la seduta
	# il peso che trova terra: parte da ZERO (un cos() darebbe -3 cm nel
	# primo fotogramma: un salto), scende e rimbalza smorzato
	var plop := -exp(-s * 3.4) * sin(s * 11.0) * 0.05 * (1.0 - w)

	return {
		# IL RESPIRO: il torace si alza — e il corpo SPROFONDA nel sonno.
		# Il respiro e' profondo (2x quello da sveglio) e lento, ed e' il
		# canale che dice "e' vivo, sta dormendo".
		"vy": plop - dorme * 0.20 + dorme * (0.026 * (r - 0.5) * 2.0)
				+ stira * 0.05,
		# il busto si raccoglie in avanti (a occhio: sotto i 0.5 rad il
		# chibi sembra solo accovacciato, mai addormentato) e il respiro
		# lo fa oscillare appena — cosi' si legge su DUE canali, non uno
		"vx": dorme * (0.62 - 0.022 * (r - 0.5) * 2.0) - stira * 0.10,
		"hx": dorme * (0.50 + 0.03 * r) - stira * 0.42,
		"hy": dorme * 0.05 * sin(t * 0.28),         # la deriva del sogno
		"hz": dorme * 0.10,                          # la guancia che cede
		"ax": dorme * (0.62 + 0.022 * r) - stira * 2.1,
		"az": dorme * 0.14,
		"lx": dorme * 1.50 * (1.0 - w),
		"ly": dorme * -0.07,
		"ear": dorme * 0.55 - stira * 0.35,
		"tx": dorme * 0.45,
		"respiro": r,
		"sveglio": w,
	}


func _anim_dorme(dur: float, delta: float) -> void:
	_sit_t += delta
	var a := assesto_sonno(_sit_t, _t, dur)
	var dorme: float = 1.0 - float(a["sveglio"])

	# il corpo. Si SOMMA alla gobba dell'età (non la si butta via: un
	# anziano dorme più curvo, ed è caratterizzazione gratuita)
	_vis.position.y = float(a["vy"])
	_vis.rotation.x = float(a["vx"]) - 0.28 * _eta
	_vis.rotation.z = 0.0
	_head.rotation.x = float(a["hx"])
	_head.rotation.y = float(a["hy"])
	_head.rotation.z = float(a["hz"])

	if not dna.is_empty():
		if _c_arms.size() == 2:
			# le zampine raccolte sotto il musetto, mai identiche fra loro
			_c_arms[0].rotation.x = float(a["ax"])
			_c_arms[1].rotation.x = float(a["ax"]) + 0.05 * dorme
			# verso il petto, non in fuori: la base del builder e' +-0.32
			# di apertura, e il sonno la RICHIUDE (segno opposto)
			_c_arms[0].rotation.z = -0.32 + float(a["az"])
			_c_arms[1].rotation.z = 0.32 - float(a["az"])
		for gamba in _c_legs:
			gamba.rotation.x = float(a["lx"])
			gamba.position.y = 0.16 + float(a["ly"])
		# il fremito del sogno: ogni tanto un orecchio scatta e si riposa
		_sonno_fremito -= delta
		if _sonno_fremito <= 0.0:
			_sonno_fremito = randf_range(3.5, 8.0)
			_sonno_fremito_t = 0.35
			_sonno_fremito_i = randi() % maxi(_c_ears.size(), 1)
		var fr := 0.0
		if _sonno_fremito_t > 0.0:
			_sonno_fremito_t -= delta
			var pf := clampf(1.0 - _sonno_fremito_t / 0.35, 0.0, 1.0)
			fr = sin(pf * PI * 3.0) * (1.0 - pf) * 0.30 * dorme
		for i in _c_ears.size():
			# + l'eta': senza, a un anziano le orecchie SCATTEREBBERO SU
			# nell'istante in cui si corica (la base sua e' 0.38 * _eta)
			_c_ears[i].rotation.x = float(a["ear"]) + 0.38 * _eta \
					+ (fr if i == _sonno_fremito_i else 0.0)
		if _tail_p:
			# arrotolata contro il fianco: una coda che scodinzola
			# smentirebbe il sonno in un istante
			_tail_p.rotation.x = float(a["tx"])
			_tail_p.rotation.y = 0.12 * sin(_t * 0.5) * dorme
		if _tail_tip:
			_tail_tip.rotation.x = float(a["tx"]) * 0.5
			_tail_tip.rotation.y = 0.09 * sin(_t * 0.5 - 0.8) * dorme

	# LA ZETA SULL'ESPIRO: non un timer, il respiro stesso. Esce quando
	# la fase scende sotto il colmo — una ogni 5 s, il ritmo del petto
	var r: float = a["respiro"]
	if dorme > 0.9 and _sit_t > SONNO_SETTLE \
			and r < 0.45 and _sonno_r_prev >= 0.45:
		_emote("z", Color(0.62, 0.5, 0.78))
	_sonno_r_prev = r


func _anim_sit() -> void:
	# riposo beato — ma PRIMA l'assestamento: il plop con un rimbalzo,
	# i fianchi che si sistemano, il sospiro, la coda che si accomoda
	# con due colpi. Gli anziani fanno tutto con più calma. Solo dopo
	# arriva il respiro lento di sempre (e il guardarsi intorno).
	_relax_legs()
	_sit_t += get_process_delta_time()
	var a := assesto_seduta(_sit_t / (1.0 + 0.6 * _eta))
	var calo: float = a["calo"]
	_vis.rotation.x = 0.0
	_vis.position.y = sin(_t * 1.6) * 0.012 + float(a["plop"]) \
			+ float(a["sospiro"]) * 0.02
	_vis.rotation.z = sin(_t * 0.8) * 0.04 + float(a["fianchi"])
	_head.rotation.x = sin(_t * 1.6) * 0.06 - float(a["sospiro"]) * 0.12
	# ci si guarda intorno solo DOPO essersi accomodati
	_head.rotation.y = sin(_t * 0.5) * 0.3 * (1.0 - calo)
	if not dna.is_empty():
		if _c_arms.size() == 2:
			# le spalle: su col sospiro, giù quando si lascia andare
			var braccio: float = 0.2 - float(a["sospiro"]) * 0.22 + calo * 0.12
			_c_arms[0].rotation.x = braccio
			_c_arms[1].rotation.x = braccio
		if _tail_p:
			# la coda si SISTEMA con due colpi, poi ondeggia placida
			_tail_p.rotation.y = sin(_t * 1.2) * 0.25 * (1.0 - 0.55 * _eta) \
					* (1.0 - calo) + float(a["coda"])
		if _tail_tip:
			_tail_tip.rotation.y = sin(_t * 1.2 - 0.7) * 0.2 * (1.0 - 0.55 * _eta) \
					* (1.0 - calo) + sin(_sit_t * 8.0 - 0.8) * 0.4 * calo
		return
	if species == "passerotto":
		_tail_p.rotation.x = sin(_t * 2.2) * 0.15
		if _emote_cd <= 0.0:
			_emote_cd = 4.0
			if _sfx:
				_sfx.play("chirp" + str(1 + randi() % 3), -20.0, 1.2)
	elif _emote_cd <= 0.0:
		_emote_cd = 5.0
		_spawn_heart()


func _anim_idle() -> void:
	if not dna.is_empty():
		# stesso ciclo del cammino: da fermo il blend lo SPEGNE da solo,
		# senza mai uno scatto tra i due mondi
		_gait_chibi()
		return
	_relax_legs()
	_vis.position.y = absf(sin(_t * 3.0)) * 0.015
	_head.rotation.y = sin(_t * 0.8) * 0.25


# ============================================================ IL PASTO
# Il piatto regalato non svanisce più a mezz'aria: il vicino lo PRENDE, ci
# si sporge sopra, ci soffia se scotta, lo mangia in tre morsetti e alla
# fine ringrazia — lo stesso rituale di Mochi al camino, visto da fuori.
# I tempi stanno tutti in Pasto.gd; qui c'è solo il corpo che li recita.

## Gli si consegna la ciotola: da questo momento è sua. `caldo` decide se
## ci soffia sopra, `adorato` se è il piatto che il suo DNA sogna (allora
## il pasto è più esuberante: il saltello, gli occhi che brillano).
## La ciotola passa di proprietà: la libera lui, a rituale finito.
func mangia(ciotola: Node3D, colore: Color, caldo := true, adorato := false) -> void:
	if ciotola == null or not is_instance_valid(ciotola) or _vis == null:
		return
	# un pasto alla volta: se ne stava già facendo uno, quello vecchio si
	# chiude subito invece di lasciare due ciotole appese al petto
	if _state == "r_pasto":
		_pasto_via(true)
	_pasto_ritorno = "r_idle" if mode == "resident" else "browse"
	_pasto_caldo = caldo
	_pasto_adorato = adorato
	_pasto_col = colore
	_pasto_t = 0.0
	_pasto_morsi = 0
	_pasto_sbuffi = 0
	_pasto_grazie = false
	_pasto_ciotola = ciotola
	# la ciotola entra nel corpo (conservando dov'è nel mondo, così non
	# "salta" nel frame del passaggio di mano) e poi si accomoda al petto
	if ciotola.get_parent() != null:
		ciotola.reparent(_vis)
	else:
		_vis.add_child(ciotola)
	# la scala si RIMETTE a uno a mano: `reparent` la calcola per conservare
	# la dimensione nel mondo, e se il corpo del chibi sta ancora nascendo
	# (o è mid-tween) quel conto lascia una ciotola gigante o invisibile
	ciotola.scale = Vector3.ONE
	ciotola.rotation = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(ciotola, "position", _pasto_posa(0.0), 0.32) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# il disco di cibo dentro la ciotola: è quello che cala a ogni morso
	_pasto_cibo = null
	for c in ciotola.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is CylinderMesh \
				and (c as MeshInstance3D).position.y > 0.0:
			_pasto_cibo = c
	if caldo:
		_pasto_vapore = PASTO.vapore()
		ciotola.add_child(_pasto_vapore)
		_pasto_vapore.position = Vector3(0, 0.08, 0)
	_pasto_in_corso = true
	_state = "r_pasto"
	_timer = PASTO.durata(caldo)
	# LA RETE DI SICUREZZA. Il recinto si apre quando scade `_timer`, che
	# scorre in _process: se questo vicino smettesse di processare a metà
	# pasto (una scena messa in pausa, un nodo nascosto), il recinto
	# resterebbe chiuso PER SEMPRE e lui non camminerebbe mai più. Questo
	# timer dell'albero non dipende dal suo _process: alla peggio chiude
	# tutto lui, qualche secondo dopo.
	get_tree().create_timer(PASTO.durata(caldo) + 4.0).timeout.connect(
			func() -> void:
				if is_instance_valid(self) and _pasto_in_corso:
					_pasto_via(true)
					_enter_state(_pasto_ritorno if _pasto_ritorno != "" else "r_idle"))


## Dove sta la ciotola al tempo dato: davanti al petto, e su verso il
## musetto per annusare e a ogni morso. La FORMA del gesto la dà
## Pasto.alzata (0..1); qui si traduce nella statura di QUESTO chibi —
## il DNA cambia testa e gambe, e una quota fissa lascerebbe i piccoli a
## mangiare sopra la testa e i grandi a mangiarsi le zampe.
func _pasto_posa(t: float) -> Vector3:
	# la quota della BOCCA, non della testa: la testona dei chibi è grande e
	# mezza spanna di differenza porta la ciotola davanti agli occhi invece
	# che alle labbra (è successo alla seconda prova in scena). La bocca la
	# si chiede al rig facciale vero; se questo chibi non ce l'ha (riccio,
	# passerotto) si ripiega su una frazione della testa.
	# I CHIBI NON PORTANO LA CIOTOLA ALLA BOCCA: le braccia sono corte e la
	# testa è enorme, e alzarla fino al musetto la ficca dentro la faccia
	# (due prove in scena buttate). Il gesto vero è l'opposto — la ciotola
	# sta TRA LE ZAMPINE, dove le zampine arrivano davvero, e a ogni morso è
	# la TESTONA a scendere. Perciò la quota non si stima dalla testa: si
	# misura sulla zampa di QUESTO chibi (il DNA cambia braccia e statura).
	var zampe := _pasto_zampe_y()
	var su := PASTO.alzata(t, _pasto_caldo)
	return Vector3(0, zampe + lerpf(0.03, 0.12, su), -0.17 - su * 0.02)


## La quota delle zampine a riposo, nello spazio del corpo. Si misura una
## volta sola, all'inizio del pasto: dopo, le braccia si muovono e la
## misura cambierebbe sotto i piedi al gesto.
func _pasto_zampe_y() -> float:
	if _pasto_zampe > 0.0:
		return _pasto_zampe
	_pasto_zampe = 0.38
	if _c_arms.size() == 2 and _vis:
		var nodo := _c_arms[0] as Node3D
		while nodo.get_child_count() > 0 and nodo.get_child(0) is Node3D:
			nodo = nodo.get_child(0)
		_pasto_zampe = (_vis.global_transform.affine_inverse()
				* nodo.global_position).y
	return _pasto_zampe


func _pasto_recita(delta: float) -> void:
	_pasto_t += delta
	var t := _pasto_t
	var fase := PASTO.fase(t, _pasto_caldo)
	var avanti := PASTO.avanzamento(t, _pasto_caldo)
	var morso := PASTO.scatto_morso(t, _pasto_caldo)

	_relax_legs()
	# il respiro sotto tutto: il corpo non è mai fermo del tutto
	_vis.position.y = absf(sin(_t * 3.0)) * 0.012

	# --- le zampine: salgono ad accogliere la ciotola e ci restano ---
	if _c_arms.size() == 2:
		var stretta := 1.0 if fase != "prende" else ease(avanti, 0.4)
		if fase == "posa":
			stretta = 1.0 - ease(avanti, 0.6)   # e tornano giù, a rituale finito
		for i in 2:
			var braccio := _c_arms[i] as Node3D
			# le zampine si chiudono in avanti ATTORNO alla ciotola: su
			# (rotation.x), e verso il centro (rotation.z) — a braccia
			# parallele la ciotola sembrerebbe appoggiata al vuoto
			braccio.rotation.x = lerpf(0.0, 1.15 + morso * 0.12, stretta)
			braccio.rotation.z = lerpf(0.0, (0.55 if i == 0 else -0.55), stretta)

	# --- la ciotola: la posa la dà Pasto, così non salta mai tra le battute ---
	if is_instance_valid(_pasto_ciotola) and fase != "" and _pasto_t > 0.34:
		_pasto_ciotola.position = _pasto_posa(t)
	if is_instance_valid(_pasto_cibo):
		# il cibo cala a scatti (un terzo per morso) con un piccolo
		# assestamento: sembra mangiato, non evaporato
		var quanto := PASTO.cibo(t, _pasto_caldo)
		_pasto_cibo.scale = Vector3(1.0, maxf(quanto, 0.02), 1.0)
		_pasto_cibo.position.y = 0.045 - (1.0 - quanto) * 0.012

	match fase:
		"prende":
			# la testa scende a guardare cosa gli hanno messo tra le zampe
			_head.rotation.x = lerpf(0.0, 0.34, ease(avanti, 0.4))
			_head.rotation.y = lerpf(_head.rotation.y, 0.0, 0.2)
			if avanti < 0.06:
				_faccia("gioia" if _pasto_adorato else "felice")
				# chi adora quel piatto non riesce a stare fermo
				if _pasto_adorato:
					var salto := create_tween()
					salto.tween_property(_vis, "position:y", 0.16, 0.16) \
							.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
					salto.tween_property(_vis, "position:y", 0.0, 0.14) \
							.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		"annusa":
			# si sporge sul piatto: il calore si SENTE prima di assaggiarlo
			_head.rotation.x = 0.34 + sin(avanti * PI) * 0.1
			_vis.rotation.x = sin(avanti * PI) * 0.07
			if avanti < 0.06:
				_faccia("beato")
			# le orecchie si drizzano piano (il buon odore le sveglia) — MA
			# SOPRA LA LORO BASE. Scritta in assoluto, questa riga faceva
			# SCATTARE SU di 22 gradi le orecchie di un anziano (la sua base
			# e' 0.38 * _eta) al primo frame di «annusa», e ce le teneva per
			# tutto il pasto piu' i quattro-otto secondi di r_idle: tornavano
			# giu' solo al primo passo. E' l'esempio scritto in CLAUDE.md,
			# nel gesto piu' tenero del gioco. Stesso rimedio di _anim_dorme.
			for orecchio in _c_ears:
				(orecchio as Node3D).rotation.x = 0.38 * _eta \
						- 0.28 * sin(avanti * PI) * (1.0 - 0.5 * _eta)
		"soffia":
			_head.rotation.x = 0.30
			_vis.rotation.x = 0.04
			if avanti < 0.06:
				_faccia("soffio")
			# due sbuffi, come Mochi: uno all'inizio e uno a metà
			var quanti := 1 if avanti < 0.5 else 2
			if quanti > _pasto_sbuffi:
				_pasto_sbuffi = quanti
				_pasto_sbuffo()
		"morsi":
			# LA TESTONA SCENDE nella ciotola che le viene incontro: è il
			# movimento grande, quello che si legge da lontano. La ciotola
			# fa il tratto piccolo — insieme danno il peso del gesto
			_head.rotation.x = 0.30 + morso * 0.46
			# lo schiacciamento del morso (squash), tenuto piccolo
			_vis.scale = Vector3(1.0 + morso * 0.035, 1.0 - morso * 0.045,
					1.0 + morso * 0.035)
			if avanti < 0.06:
				_faccia("gioia" if _pasto_adorato else "felice")
			# la masticazione tra un morso e l'altro: la testolina lavora
			if morso <= 0.01:
				_head.rotation.z = sin(_t * 16.0) * 0.045
			var dovuti := 0
			for i in PASTO.MORSI:
				if t >= PASTO.momento_morso(i, _pasto_caldo):
					dovuti += 1
			if dovuti > _pasto_morsi:
				_pasto_morsi = dovuti
				_pasto_morso_dato()
		"sospiro":
			# la beatitudine: testa che si alza, occhi socchiusi, il grazie
			_head.rotation.x = lerpf(0.30, -0.16, ease(avanti, 0.4))
			_head.rotation.z = 0.0
			_vis.rotation.x = 0.0
			_vis.scale = Vector3.ONE
			if not _pasto_grazie:
				_pasto_grazie = true
				_faccia("beato")
				_spawn_heart()
				# «ta-ki! wa-wi!» — grazie, che felicità. Il ringraziamento
				# arriva DOPO l'assaggio: è il boccone a parlare, non l'educazione
				speak(["grazie", "felice"] if _pasto_adorato else ["grazie"],
						"felice")
				if _pasto_adorato:
					get_tree().create_timer(0.45).timeout.connect(func() -> void:
						if is_instance_valid(self):
							_spawn_heart())
		"posa":
			# la ciotola si inclina: si vede che è VUOTA, e solo allora se ne va
			_head.rotation.x = lerpf(-0.16, 0.0, avanti)
			if is_instance_valid(_pasto_ciotola):
				_pasto_ciotola.rotation.z = ease(avanti, 0.5) * 0.9
			if avanti > 0.5 and is_instance_valid(_pasto_ciotola) \
					and _pasto_ciotola.scale.x > 0.9:
				var via := create_tween()
				via.tween_property(_pasto_ciotola, "scale", Vector3.ONE * 0.03, 0.22) \
						.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


# il morso: briciole, "gnam" e un guizzo di coda
func _pasto_morso_dato() -> void:
	if _sfx:
		_sfx.munch()
	var briciole := PASTO.briciole(_pasto_col)
	add_child(briciole)
	if is_instance_valid(_pasto_ciotola):
		briciole.global_position = _pasto_ciotola.global_position + Vector3(0, -0.02, 0)
	briciole.emitting = true
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(briciole):
			briciole.queue_free())


func _pasto_sbuffo() -> void:
	var sbuffo := PASTO.sbuffo()
	add_child(sbuffo)
	# parte dal musetto e va verso la ciotola
	sbuffo.global_position = _head.global_position + Vector3(0, -0.02, 0)
	sbuffo.emitting = true
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(sbuffo):
			sbuffo.queue_free())


# fine del rituale (o interruzione): via la ciotola, il corpo si scioglie
func _pasto_via(subito := false) -> void:
	_pasto_in_corso = false   # il recinto si apre: il vicino torna alla sua vita
	if is_instance_valid(_pasto_vapore):
		_pasto_vapore.emitting = false
	if is_instance_valid(_pasto_ciotola):
		var c := _pasto_ciotola
		if subito:
			c.queue_free()
		else:
			var tw := create_tween()
			tw.tween_property(c, "scale", Vector3.ONE * 0.02, 0.2) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_callback(c.queue_free)
	_pasto_ciotola = null
	_pasto_cibo = null
	_pasto_vapore = null
	if _vis:
		_vis.scale = Vector3.ONE
		_vis.rotation.x = 0.0
	if _head:
		_head.rotation.x = 0.0
		_head.rotation.z = 0.0
	_faccia("neutro")


# l'espressione, solo se questo chibi ha un volto vivo (i visitatori
# riccio/passerotto ne sono privi: per loro il pasto resta corpo e voce)
func _faccia(nome: String) -> void:
	if _face:
		_face.set_expression(nome)


## Recita un piano composto dal Regista (lista di passi Lua validati).
## Il piano è un ospite gentile: qualunque routine "vera" (falò, sonno,
## onsen) lo interrompe senza complimenti.
func run_plan(steps: Array) -> void:
	if _hidden or mode != "resident" or _state.begins_with("th") \
			or _state.begins_with("on_") or _state == "write":
		return
	if _robe != null:
		_wear_robe(false)  # se l'onsen è stato interrotto, via l'accappatoio
	_plan = steps.duplicate()
	_plan_i = 0
	_next_plan_step()


func _next_plan_step() -> void:
	if _plan_i >= _plan.size():
		_plan = []
		_enter_state("r_idle")
		return
	var passo: Array = _plan[_plan_i]
	_plan_i += 1
	match str(passo[0]):
		"vai_a":
			_walk_to(Vector3(float(passo[1]), 0, float(passo[2])), "lp_next")
		"verso_casa":
			var front: Vector3 = _house.get("front", position)
			_walk_to(front + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5)), "lp_next")
		"aspetta":
			_timer = float(passo[1])
			_state = "lp_wait"
		"annusa":
			_timer = float(passo[1])
			_emote("?", Color(0.55, 0.45, 0.75))
			_state = "lp_sniff"
		"parla_di":
			speak([str(passo[1]), "~"], str(passo[2]))
			chat_bubble(LP_SIMBOLI.get(str(passo[1]), "!"))
			_timer = 1.6
			_state = "lp_wait"
		"cuoricino":
			_spawn_heart()
			_next_plan_step()
		_:
			_next_plan_step()


## Un compito deciso dal VillagerBrain. I compiti "in cammino" (nibble,
## water, wonder, chat_fungo) raggiungono pos e poi recitano; quelli sul
## posto (sing, twirl, startle, nap, stella, sasso) partono subito.
## on_done viene chiamata a compito finito (per "water" all'ARRIVO, così
## il Garden può far piovere sull'aiuola mentre il villager è lì).
func do_task(kind: String, pos: Vector3, on_done := Callable()) -> void:
	if _hidden or mode != "resident" or _state.begins_with("th") \
			or _state.begins_with("on_") or _state == "write":
		return
	_plan = []
	_task_cb = on_done
	_task_acc = 0.0
	if kind in ["nibble", "water", "wonder", "chat_fungo"]:
		_walk_to(pos, "tk_" + kind)
	else:
		# chi si corica SUL POSTO lo fa a terra: senza questa riga, un
		# residente seduto in panchina (y = 0.52) si stendeva a mezz'aria
		position.y = 0.0
		_enter_state("tk_" + kind)


func _finish_task(call_cb := true) -> void:
	if call_cb and _task_cb.is_valid():
		_task_cb.call()
	_task_cb = Callable()
	_enter_state("r_idle")


# il bricco teal in miniatura, nella zampa destra, beccuccio in avanti
func _make_hand_can() -> void:
	_clear_can()
	if _c_arms.size() < 2:
		return
	_can = Node3D.new()
	var teal := _mat(Color("8fc0c8"))
	var body := CylinderMesh.new()
	body.top_radius = 0.06
	body.bottom_radius = 0.075
	body.height = 0.11
	var bmi := MeshInstance3D.new()
	bmi.mesh = body
	bmi.material_override = teal
	_can.add_child(bmi)
	var spout := CylinderMesh.new()
	spout.top_radius = 0.014
	spout.bottom_radius = 0.022
	spout.height = 0.12
	var smi := MeshInstance3D.new()
	smi.mesh = spout
	smi.material_override = teal
	smi.position = Vector3(0.09, 0.025, 0)
	smi.rotation.z = -1.0
	_can.add_child(smi)
	(_c_arms[1] as Node3D).add_child(_can)
	_can.position = Vector3(0, -0.3, -0.05)
	_can.rotation.y = PI * 0.5
	_can.scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(_can, "scale", Vector3.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_can, "rotation:x", -0.8, 0.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _clear_can() -> void:
	if _can and is_instance_valid(_can):
		_can.queue_free()
	_can = null


## La regia delle giornate: il Visitors smista i residenti tra aiuole,
## panchine e il falò della sera.
## ====================================================== IL CORPO SI RIFÀ
##
## Il corpo nasceva dal DNA una volta sola e restava. Perché un aspetto si
## possa CAMBIARE — l'estetista, un giorno — il montaggio deve essere una
## funzione richiamabile, non venti righe dentro `_ready`.
##
## Monta (o rimonta) il corpo dal genoma corrente. Chi lo richiama deve
## aver già smontato il vecchio: ci pensa `rifai_il_look`.
func _monta_corpo() -> void:
	var parts: Dictionary = BUILDER.build(dna)
	_corpo = parts["root"]
	# la taglia del genoma è già dentro root.scale (ChibiBuilder): la si
	# ricorda qui perché la crescita di un cucciolo la MOLTIPLICA invece
	# di sostituirla — scriverci sopra farebbe crescere tutti fino alla
	# stessa statura, cancellando il gene della corporatura
	_corpo_base = _corpo.scale
	_testa_base = Vector3.ZERO
	_vis.add_child(parts["root"])
	_head = parts["head"]
	_c_arms = parts["arms"]
	_c_ears = parts["ears"]
	_c_legs = parts.get("legs", [] as Array[Node3D])
	_tail_p = parts["tail"]
	_tail_tip = parts.get("tail_tip")
	if parts.has("face"):
		var rig: Dictionary = parts["face"]
		rig["head"] = _head
		_face = FACE.new()
		_face.setup(rig)
	# un corpo appena rimontato torna della taglia da adulto: se chi lo
	# porta è ancora un cucciolo, la crescita va riapplicata subito o
	# ricomparirebbe grande (l'estetista non fa crescere nessuno)
	if _cresc < 1.0:
		var c := _cresc
		_cresc = -1.0     # forza il ricalcolo: set_cucciolo ignora i no-op
		set_cucciolo(c)


## IL CAMBIO DI LOOK. Applica dei geni ESTETICI e rifà il corpo sul posto.
##
## Cosa NON deve cambiare, ed è tutto il punto:
##   · la VOCE — nasce da `voce_seed`, che non è un gene estetico. Una
##     tinta non ti cambia il timbro (prima sì: la voce si ricavava dal
##     colore del pelo, e cambiare colore cambiava chi eri a orecchio);
##   · CHI SEI — nome, sogno, tratti, indole: `ChibiDNA.con_estetica`
##     scarta in silenzio qualunque gene non estetico gli si passi;
##   · DOVE SEI e COSA STAI FACENDO — posizione, stato, piano, amicizia,
##     il filo dei momenti: vivono tutti fuori dal corpo.
##
## Torna false se non c'era niente da cambiare, così chi chiama non
## racconta una trasformazione che non è successa.
func rifai_il_look(nuovi: Dictionary) -> bool:
	if dna.is_empty() or _vis == null:
		return false
	# SI SCRIVE DENTRO IL GENOMA, non se ne mette uno nuovo al suo posto.
	# `dna` e' LO STESSO dizionario della riga del residente in Visitors,
	# ed e' quella riga che finisce nel salvataggio: riassegnando la
	# variabile il corpo cambiava e il genoma salvato no — al riavvio il
	# vicino tornava com'era, e la seduta dall'estetista non era mai
	# successa. (Trovato facendo girare la giornata vera del salone.)
	var puliti := {}
	for g in nuovi:
		if not str(g) in DNA_GEN.ESTETICI:
			continue          # l'identita' non si tocca: la scarta qui
		if str(dna.get(g, "")) != str(nuovi[g]):
			puliti[str(g)] = nuovi[g]
	if puliti.is_empty():
		return false
	for g in puliti:
		dna[g] = puliti[g]

	# via ciò che pendeva dal corpo vecchio: il bricco dell'acqua
	# resterebbe appeso a un braccio che non esiste più
	_clear_can()
	for c in _vis.get_children():
		_vis.remove_child(c)
		c.queue_free()
	_face = null
	_monta_corpo()
	# la VOCE non si ricalcola: `_voice` è già quella giusta, e rifarla
	# sarebbe l'occasione buona per sbagliare
	return true


## `durata` > 0 fissa quanto si resta seduti. Senza, `r_bench` sceglie da sé
## fra 14 e 22 secondi — che va bene per una panchina, e NON va bene per chi
## sta suonando: il concerto dura 48 secondi reali, e il pianista si alzava a
## metà del suo stesso pezzo con la musica che andava avanti da sola.
func do_routine(kind: String, pos: Vector3, look := Vector3.ZERO,
		aux: Node3D = null, durata := 0.0) -> void:
	if _hidden or mode != "resident" or _state.begins_with("th") or _state.begins_with("on_"):
		return
	if _robe != null:
		_wear_robe(false)
	_plan = []
	_task_cb = Callable()
	_clear_can()
	_routine_aux = aux
	_routine_durata = durata
	_fire_look = look
	match kind:
		"sniff":
			_walk_to(pos, "r_sniff")
		"bench":
			_walk_to(pos, "r_bench")
		"fire":
			_walk_to(pos, "r_fire")
		"wander":
			_enter_state("r_wander")
		"attesa":
			# l'ATTESA di un appuntamento: ci va e ci RESTA, in piedi,
			# rivolto alla cosa per cui vi siete dati appuntamento.
			# Diverso da "wonder", che dura quattro secondi e finisce:
			# qui si aspetta una persona, e si aspetta finche' serve.
			_walk_to(pos, "r_attesa")
		"confronto":
			# ti raggiunge per dirtelo in faccia. Stato SUO, non r_bench:
			# riusando la panchina si accovacciava nell'erba e — peggio —
			# l'uscita pretendeva _routine_aux (che qui è sempre null),
			# quindi restava seduto lì per sempre. Il punto da guardare
			# viaggia in _fire_look, già valorizzato qui sopra.
			_walk_to(pos, "r_confronto")


func face_towards(p: Vector3) -> void:
	var to := p - position
	_yaw = atan2(-to.x, -to.z)


## Va alla lavagna a scrivere col gessetto: il suo compleanno, oppure —
## dalla Fase 3 — la richiesta che ha deciso di appendere. `on_done` scatta
## quando il gessetto si ferma, non quando parte: il biglietto compare
## sulla lavagna nel momento in cui l'ha scritto.
func go_write(pos: Vector3, look: Vector3, on_done := Callable()) -> void:
	if _hidden or mode != "resident" or _state.begins_with("th") \
			or _state.begins_with("on_") or _state == "write":
		return
	_write_look = look
	_task_cb = on_done
	_walk_to(pos, "write")


## Il cappellino a cono dei compleanni (con tanto di ponpon).
func set_party_hat(on: bool) -> void:
	if on and _party_hat == null and _head:
		_party_hat = Node3D.new()
		_party_hat.position = Vector3(0.08, 0.3, 0)
		_party_hat.rotation.z = -0.25
		_head.add_child(_party_hat)
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.11
		cm.height = 0.26
		cone.mesh = cm
		cone.material_override = BUILDER._mat(Color(dna.get("dress", "f4b8c8")))
		cone.position = Vector3(0, 0.13, 0)
		_party_hat.add_child(cone)
		var pom := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = 0.04
		pm.height = 0.08
		pom.mesh = pm
		pom.material_override = BUILDER._mat(Color("ffd76e"))
		pom.position = Vector3(0, 0.28, 0)
		_party_hat.add_child(pom)
	elif not on and _party_hat:
		_party_hat.queue_free()
		_party_hat = null


## La visita all'onsen: arriva in accappatoio con l'asciugamanino
## piegato in testa, si immerge accanto a Mochi e sospira in Chibiese.
func onsen_visit(edge: Vector3, soak: Vector3) -> bool:
	if mode != "resident" or _hidden or _state.begins_with("on_") or _state.begins_with("th"):
		return false
	_onsen = {"edge": edge, "soak": soak}
	_wear_robe(true)
	_walk_to(edge, "on_dip")
	return true


func _wear_robe(on: bool) -> void:
	if on and _robe == null:
		_robe = Node3D.new()
		_vis.add_child(_robe)
		var terry := BUILDER._mat(Color("fdf3e6"))
		# l'accappatoio: mantellina di spugna con la cintura
		var cape := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.19
		cm.bottom_radius = 0.38
		cm.height = 0.5
		cape.mesh = cm
		cape.material_override = terry
		cape.position = Vector3(0, 0.38, 0)
		_robe.add_child(cape)
		var belt := MeshInstance3D.new()
		var bm := TorusMesh.new()
		bm.inner_radius = 0.24
		bm.outer_radius = 0.29
		belt.mesh = bm
		belt.material_override = BUILDER._mat(Color("e8cfae"))
		belt.position = Vector3(0, 0.34, 0)
		belt.scale = Vector3(1, 0.5, 1)
		_robe.add_child(belt)
		# l'asciugamanino piegato in testa
		if _head:
			var towel := MeshInstance3D.new()
			var tm := BoxMesh.new()
			tm.size = Vector3(0.26, 0.07, 0.2)
			towel.mesh = tm
			towel.material_override = terry
			towel.name = "Asciugamanino"
			towel.position = Vector3(0, 0.34, 0.02)
			towel.rotation.z = 0.06
			_head.add_child(towel)
	elif not on:
		if _robe:
			_robe.queue_free()
			_robe = null
		if _head:
			var towel := _head.find_child("Asciugamanino", false, false)
			if towel:
				towel.queue_free()


## La gita alla casa sull'albero: cammina fino alla base della scala,
## si arrampica su per i pioli, saluta dal trespolo e poi ridiscende.
func treehouse_visit(base: Vector3, top: Vector3, perch: Vector3) -> void:
	if mode != "resident" or _hidden or _state.begins_with("th") \
			or _state.begins_with("on_") or _state == "write":
		return
	_th = {"base": base, "top": top, "perch": perch}
	_walk_to(base, "th_up")


## Parla in Chibiese: una lista di concetti del vocabolario (o "~" per
## il chiacchiericcio) con lo stato d'animo. La voce è la SUA: stessa
## parola, timbro diverso per ogni villager.
# l'espressione facciale che si addice a ciò che il villager sta facendo:
# curiosa quando ispeziona/annusa, raggiante quando gioca o dona, in soggezione
# davanti al cielo, assonnata nel pisolino… il resto è un sereno "neutro".
func _expr_for_state(s: String) -> String:
	match s:
		"browse", "inspect", "c_inspect", "sniff", "annusa", "r_sniff", \
		"lp_sniff", "write", "tk_chat_fungo", "tk_sasso", "tk_nibble":
			return "curioso"
		"gift", "cuoricino", "tk_twirl", "tk_sing":
			return "gioia"
		"sole", "tk_stella", "tk_wonder", "th_perch", "r_attesa":
			return "meraviglia"
		"tk_startle":
			return "spavento"
		"tk_nap":
			return "dorme"
		"on_soak", "on_dip":
			return "beato"
		"sit", "bench", "r_bench", "r_idle", "r_settle", "fire", "r_fire", \
		"fuoco", "tk_water":
			return "felice"
		_:
			return "neutro"


func speak(concepts: Array, mood := "neutro") -> void:
	if _voice.is_empty() or _voice_player == null or _speak_cd > 0.0 \
			or _voice_player.playing or _hidden:
		return
	# chi dorme non parla: una frase aprirebbe la bocca e cancellerebbe
	# l'espressione "dorme" (il volto recita l'umore mentre la voce parla)
	if _state == "tk_nap":
		return
	_speak_cd = 2.5
	_mood = mood   # il volto recita l'umore mentre la voce parla
	_voice_player.stream = CHIBIESE.say(_voice, concepts, mood)
	_voice_player.play()


# ------------------------------------------- le stagioni della vita
# (Il Filo Rosso, Fase 2) L'età attraversa il corpo e la voce.

var _eta := 0.0
var _eta_dressed := false
var _autunno: Array[Node3D] = []
var _orig_cols := {}

# --- l'altro capo della vita: chi è NATO qui (vedi Nascite.gd) ---
# Il corpo costruito dal DNA, tenuto a parte: la crescita agisce su
# QUESTO nodo e non su `_vis`, che è già la tela su cui recitano il
# saltello del passo, lo schiacciamento del morso e la fioritura
# d'ingresso. Due scale sullo stesso nodo si sovrascrivono a vicenda, e
# vince l'ultima ad aver parlato.
var _corpo: Node3D
var _corpo_base := Vector3.ONE
var _testa_base := Vector3.ZERO
var _cresc := 1.0            # 0 = appena nato, 1 = cresciuto

## Quanto è piccolo appena nato, e quanto gli resta grande la testa.
## Fuori dalle funzioni perché li leggono anche i test.
const TAGLIA_CUCCIOLO := 0.44
const TESTA_CUCCIOLO := 1.34


## f: 0 = giovane, 1 = pieno autunno. Il passo rallenta, la schiena
## si china un filo, la coda ondeggia pigra, la voce si abbassa e si
## incrina (Chibiese). Oltre la soglia dell'autunno (0.5) arrivano i
## segni d'argento: baffetti, sopracciglia, e il bastoncino di ciliegio.
func set_eta(f: float) -> void:
	f = clampf(f, 0.0, 1.0)
	if species != "chibi" or absf(f - _eta) < 0.005:
		return
	_eta = f
	_speed = 1.45 * (1.0 - 0.38 * f) * _passo_da_cucciolo()
	_aggiorna_voce()
	_gobba(f)
	_rughe_viso(f)
	_silver(f)
	for ear in _c_ears:
		ear.rotation.x = 0.38 * f  # da fermi, le orecchie si afflosciano
	if f >= 0.5 and not _eta_dressed:
		_vesti_autunno()
	elif f < 0.5 and _eta_dressed:
		_spoglia_autunno()


## La crescita di chi è nato qui. c: 0 = appena nato, 1 = cresciuto.
##
## Un cucciolo chibi non è un adulto rimpicciolito: è un adulto con le
## proporzioni sbagliate, ed è lì che sta tutta la tenerezza. Il corpo si
## riduce quasi a metà, ma la testa MOLTO meno — resta una testona su un
## corpicino, come nei cuccioli veri (e come in ogni personaggio che
## qualcuno abbia mai voluto prendere in braccio).
##
## Chi NON è nato qui non passa mai di qui: arriva col trolley e con la
## sua statura, e non deve mai ritrovarsi bambino per sbaglio.
func set_cucciolo(c: float) -> void:
	c = clampf(c, 0.0, 1.0)
	if species != "chibi" or _corpo == null or absf(c - _cresc) < 0.004:
		return
	_cresc = c
	# i primi giorni restano piccolissimi più a lungo, poi la crescita
	# accelera: è la forma vera di una crescita, non una retta
	var e := c * c * (3.0 - 2.0 * c)
	_corpo.scale = _corpo_base * lerpf(TAGLIA_CUCCIOLO, 1.0, e)
	if _head:
		if _testa_base == Vector3.ZERO:
			_testa_base = _head.position
		var k := lerpf(TESTA_CUCCIOLO, 1.0, e)
		_head.scale = Vector3.ONE * k
		# e si alza di quel tanto che serve a non affondare nel corpo: la
		# palla della testa cresce attorno al proprio centro, quindi senza
		# questa riga il collo se la mangia
		_head.position = _testa_base + Vector3(0, 0.30 * (k - 1.0), 0)
	_speed = 1.45 * (1.0 - 0.38 * _eta) * _passo_da_cucciolo()
	_aggiorna_voce()


## Il passo corto del cucciolo: copre meno strada e per questo, a parità
## di ciclo, sembra svelto e trotterellante.
func _passo_da_cucciolo() -> float:
	return lerpf(0.52, 1.0, _cresc * _cresc * (3.0 - 2.0 * _cresc))


## La voce è UNA e nasce da due cose insieme: quanti anni ha e quanto
## deve ancora crescere. Tenerle in due assegnazioni separate faceva
## vincere l'ultima che parlava — e chi cresceva perdeva la vocina al
## primo ricalcolo dell'età.
func _aggiorna_voce() -> void:
	if dna.is_empty():
		return
	_voice = CHIBIESE.bimbo(
			CHIBIESE.invecchia(CHIBIESE.voice(dna), _eta), 1.0 - _cresc)


# La gobba VERA, non un'inclinazione: la schiena si curva in avanti,
# i piedini restano sotto il baricentro, e un nodo-collo (inserito a
# runtime sopra la testa) CONTRO-RUOTA il musetto perché resti rivolto
# avanti mentre il corpo si piega — la silhouette di chi ha vissuto.
# Le animazioni della testa continuano a funzionare intatte: recitano
# dentro il collo, che è mio e di nessun altro.
var _collo: Node3D
var _collo_base := Vector3.ZERO


func _gobba(f: float) -> void:
	_vis.rotation.x = -0.28 * f
	_vis.position.z = 0.10 * f
	if _collo == null and _head:
		_collo = Node3D.new()
		var neck_parent := _head.get_parent()
		_collo.transform = _head.transform
		neck_parent.add_child(_collo)
		_head.reparent(_collo)
		_head.transform = Transform3D.IDENTITY
		_collo_base = _collo.position
	if _collo:
		_collo.rotation.x = 0.26 * f
		# il collo sprofonda un poco tra le spalle
		_collo.position = _collo_base + Vector3(0, -0.06 * f, -0.02 * f)


# le rughe scavate nel modello: il cranio riceve un clone del suo
# materiale toon col parametro "age" — fronte, zampe di gallina e
# guance si incidono nel campo di luce (vedi toon.gdshader)
var _skull_mat: ShaderMaterial


func _rughe_viso(f: float) -> void:
	if _head == null:
		return
	if _skull_mat == null:
		for c in _head.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh is SphereMesh \
					and ((c as MeshInstance3D).mesh as SphereMesh).radius > 0.3 \
					and (c as MeshInstance3D).material_override is ShaderMaterial:
				_skull_mat = ((c as MeshInstance3D).material_override as ShaderMaterial).duplicate()
				(c as MeshInstance3D).material_override = _skull_mat
				break
	if _skull_mat:
		_skull_mat.set_shader_parameter("age", f)


# il pelo (e il vestitino) sbiadiscono piano verso l'argento —
# sempre a partire dai colori ORIGINALI: mai derive cumulative
func _silver(f: float) -> void:
	for mi in _vis.find_children("*", "MeshInstance3D", true, false):
		var mat: Material = (mi as MeshInstance3D).material_override
		if mat is not ShaderMaterial:
			continue
		for p in ["albedo_color", "color_a", "color_b"]:
			var c: Variant = (mat as ShaderMaterial).get_shader_parameter(p)
			if c is Color:
				var k := "%d|%s" % [mat.get_instance_id(), p]
				if not _orig_cols.has(k):
					_orig_cols[k] = c
				(mat as ShaderMaterial).set_shader_parameter(p,
						(_orig_cols[k] as Color).lerp(Color(0.84, 0.82, 0.80), f * 0.16))


# i segni dell'autunno: asset nuovi, costruiti col kit dei chibi
func _vesti_autunno() -> void:
	_eta_dressed = true
	var hs: float = dna.get("head_scale", 1.0)
	var front := -0.34 * hs
	var argento := BUILDER._mat(Color("f2efe8"), 0.35)
	if _head:
		# baffetti brizzolati sulle guance, all'ingiù, ben presenti
		for side: float in [-1.0, 1.0]:
			_autunno.append(BUILDER.tuft(_head, argento,
					Vector3(side * 0.29 * hs, -0.14 * hs, front + 0.10),
					Vector3(-2.6, 0, side * 0.55), 0.075, 4, 0.6))
		# sopracciglia d'argento, folte, sopra gli occhioni
		var brow_y := (0.10 + float(dna.get("eye_h", 0.02))) * hs
		for side: float in [-1.0, 1.0]:
			_autunno.append(BUILDER.tuft(_head, argento,
					Vector3(side * float(dna.get("eye_gap", 0.15)) * hs, brow_y, front + 0.03),
					Vector3(-0.5, 0, -side * 0.35), 0.055, 3, 0.5))
		# la barbetta sul mento
		_autunno.append(BUILDER.tuft(_head, argento,
				Vector3(0, -0.25 * hs, front + 0.06), Vector3(-2.9, 0, 0), 0.06, 3, 0.5))
	# il bastoncino di ciliegio: fusto dolcemente arcuato, pomello
	# lucido, puntale d'ottone — piantato accanto alla zampina destra
	var cane := Node3D.new()
	_vis.add_child(cane)
	var ciliegio := BUILDER._mat(Color("9a5a44"))
	BUILDER.tube(cane, [Vector3(0.27, 0.44, -0.13), Vector3(0.30, 0.22, -0.15),
			Vector3(0.28, 0.01, -0.13)], [0.019, 0.023, 0.025], ciliegio, 10, 8)
	_ball(cane, 0.045, BUILDER._mat(Color("c9a06a")), Vector3(0.27, 0.46, -0.13))
	_ball(cane, 0.028, BUILDER._mat(Color("8a7f72")), Vector3(0.28, 0.015, -0.13),
			Vector3(1, 0.5, 1))
	_autunno.append(cane)


func _spoglia_autunno() -> void:
	_eta_dressed = false
	for n in _autunno:
		if is_instance_valid(n):
			n.queue_free()
	_autunno.clear()


## Nuvoletta di chiacchiera: un simbolo dentro un tondo bianco.
func chat_bubble(sym: String) -> void:
	var bubble := Node3D.new()
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.72, 0.82, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.95),
		Color(0.85, 0.75, 0.68, 0.9), Color(1, 1, 1, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.render_priority = 1
	quad.material = mat
	var disc := MeshInstance3D.new()
	disc.mesh = quad
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bubble.add_child(disc)
	var lbl := Label3D.new()
	lbl.text = sym
	lbl.font_size = 44
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(0.45, 0.32, 0.28)
	lbl.render_priority = 2
	lbl.position = Vector3(0, 0, 0.01)
	bubble.add_child(lbl)
	bubble.position = Vector3(0.12, 0.78, 0)
	add_child(bubble)
	# sopra la TESTA, non dentro: i residenti chibi hanno il testone alto
	# e l'altezza fissa finiva sepolta nella nuca (la nuvoletta c'era, ma
	# non la vedeva nessuno). Con la testa vera funziona per tutti — chibi,
	# passerotto, riccio — perché la misura viene dal corpo, non da un numero.
	if _head and is_instance_valid(_head):
		bubble.global_position = _head.global_position + Vector3(0.12, 0.34, 0)
	bubble.scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(bubble, "scale", Vector3.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.tween_property(bubble, "scale", Vector3.ONE * 0.05, 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(bubble.queue_free)


## Festa grande: doppio salto e cuoricini.
func celebrate() -> void:
	# la festa col corpo della SUA indole: il timido applaude piccolo, il
	# brontolone si concede il mezzo saltello riluttante… La recita si
	# somma a qualunque stato, quindi funziona anche in cammino.
	if not dna.is_empty() and saluto_stile != "" \
			and RECITA_TRANS.has(saluto_stile):
		set_meta("postura", saluto_stile)
		for i in 3:
			get_tree().create_timer(0.2 * i).timeout.connect(_spawn_heart)
		return
	# ospiti senza il rig chibi (o senza cervello): il doppio rimbalzo
	var tw := create_tween()
	for i in 2:
		tw.tween_property(_vis, "position:y", 0.24, 0.18) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(_vis, "position:y", 0.0, 0.16) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for i in 3:
		get_tree().create_timer(0.2 * i).timeout.connect(_spawn_heart)


# il verdetto della mente, comunicato dal Visitors
func candidate_result(ok: bool, bed_pos: Vector3) -> void:
	if ok:
		_spawn_heart()
		# «ha! po-mo!» — sì, casa: la parola più bella del Chibiese
		speak(["si", "casa"], "felice")
		_walk_to(bed_pos, "r_settle")
	else:
		_emote("…", Color(0.55, 0.5, 0.6))
		speak(["no"], "triste")
		_enter_state("leave")


## Vero mentre una scena rara è in corso: chi lo chiede (il pannello dei
## desideri, il saluto) si fa da parte e la lascia finire.
func in_scena() -> bool:
	return _scena_t > 0.0


## Apre una scena lunga «dur»: per quel tempo il vicino non saluta e non
## chiede nulla — sta al suo appuntamento.
func apri_scena(dur: float) -> void:
	_scena_t = maxf(_scena_t, dur)
	_greet_cd = maxf(_greet_cd, dur)


# i residenti salutano chi passa a trovarli
func _resident_greet(delta: float) -> void:
	_greet_cd -= delta
	if _greet_cd > 0.0 or _player_ref == null or not greet_enabled:
		return
	if _player_ref.global_position.distance_to(global_position) < 1.4:
		_greet_cd = 8.0
		_spawn_heart()
		# il saluto col CORPO, filtrato dall'indole: l'applauso piccolo
		# del timido, il mezzo saltello del brontolone, l'onda lenta del
		# sognatore… (recita: si somma a qualunque stato)
		if not dna.is_empty():
			set_meta("postura",
					saluto_stile if RECITA_TRANS.has(saluto_stile) else "saluto_festoso")
		# «ya-ho!» — il saluto Chibiese, ognuno con la sua voce e la sua
		# indole: il timido un filo di voce, il chiacchierone attacca bottone
		match saluto_stile:
			"saluto_timido":
				speak(["ciao"], "neutro")
			"saluto_festoso":
				speak(["ciao", "amico", "felice"], "felice")
			"saluto_brontolone":
				speak(["ciao", "~"], "neutro")
			_:
				speak(["ciao"], "felice")
		if _sfx and species == "passerotto":
			_sfx.play("chirp" + str(1 + randi() % 3), -18.0, 1.2)
		# e Mochi risponde con la zampina, dopo un attimo di reazione
		get_tree().create_timer(0.35).timeout.connect(func():
			if _player_ref:
				var m := _player_ref.get_node_or_null("Mochi")
				if m:
					m.call("wave"))


## Di notte il residente rientra a dormire (svanisce dentro casa).
func resident_sleep() -> void:
	if _hidden:
		return
	_hidden = true
	_plan = []
	_task_cb = Callable()
	_clear_can()
	_state = "hidden"
	var tw := create_tween()
	tw.tween_property(_vis, "scale", Vector3.ONE * 0.03, 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Al mattino riappare sull'uscio, sbocciando.
func resident_wake() -> void:
	if not _hidden:
		return
	_hidden = false
	# stessa ragione: chi non ha più una casa si sveglia dov'è, non
	# scompare in un errore
	position = _house.get("front", position)
	var tw := create_tween()
	tw.tween_property(_vis, "scale", Vector3.ONE, 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_enter_state("r_idle")


func is_hidden() -> bool:
	return _hidden


## La zampina destra nel mondo: è il capo del Filo Rosso quando un
## momento si annoda (stessa firma di Mochi.paw_world).
func paw_world() -> Vector3:
	if _c_arms.size() == 2 and is_instance_valid(_c_arms[1]):
		return _c_arms[1].to_global(Vector3(0, -0.28, -0.05))
	return global_position + Vector3(0, 0.42, 0)


# ---------------------------------------------------------------- emotes

func _emote(txt: String, color: Color) -> void:
	var z := Label3D.new()
	z.text = txt
	z.font_size = 52
	z.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	z.modulate = Color(color, 0.95)
	z.outline_size = 10
	z.outline_modulate = Color(1, 1, 1, 0.85)
	z.no_depth_test = true
	z.position = Vector3(0.08, 0.62, 0)
	add_child(z)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(z, "position:y", 1.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(z, "modulate:a", 0.0, 1.6).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(z.queue_free)


# cuoricino 3D: due sferette e una punta, sale e svanisce
func _spawn_heart() -> void:
	var heart := Node3D.new()
	var pink := _flat(Color(1.0, 0.55, 0.68))
	_ball(heart, 0.035, pink, Vector3(-0.026, 0.02, 0))
	_ball(heart, 0.035, pink, Vector3(0.026, 0.02, 0))
	_cone(heart, 0.052, 0.07, pink, Vector3(0, -0.025, 0)).rotation.x = PI
	heart.position = Vector3(0.06, 0.6, 0)
	add_child(heart)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(heart, "position:y", 1.05, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(heart, "scale", Vector3.ONE * 0.25, 1.7).set_ease(Tween.EASE_IN)
	tw.tween_property(heart, "rotation:y", 2.5, 1.7)
	tw.chain().tween_callback(heart.queue_free)


# ---------------------------------------------------------------- debug CLI

func debug_goto_sit() -> void:
	if _bench and is_instance_valid(_bench):
		position = _bench.global_transform * Vector3(0, 0, 0.7)
		_enter_state("sit")
		_timer = 60.0


func debug_goto_gift() -> void:
	# azzera il riposo: il ramo "sit" gestirà discesa e regalino
	_timer = 0.0


# ================================================== la recita del corpo

## I bersagli di posa per una postura stabile + un transitorio in corso.
## PURA e statica: il test la ascolta senza costruire un villager.
## Canali d'uscita: ax0/ax1 (braccia x), az0/az1 (incrocio, specchiato),
## ear (orecchie), hx/hy (testa), vx (schiena), vy (saltello).
static func recita_bersagli(stabile: String, trans: String, trans_t: float,
		t: float) -> Dictionary:
	# `vz` e `tail` sono i due canali che mancavano al sussulto. `vx` è
	# un'INCLINAZIONE del busto, non uno spostamento: con quello solo, un
	# chibi che trasalisce si piega indietro restando inchiodato dov'è —
	# e mezzo passo indietro è metà dello spavento. `tail` irrigidisce la
	# coda, che è la prima cosa che si muove in un animale che si allarma.
	var out := {"ax0": 0.0, "ax1": 0.0, "az0": 0.0, "az1": 0.0, "ear": 0.0,
			"hx": 0.0, "hy": 0.0, "vx": 0.0, "vy": 0.0, "vz": 0.0, "tail": 0.0}
	_recita_somma(out, RECITA.get(stabile, {}), 1.0, t)
	if trans != "" and RECITA_TRANS.has(trans):
		var tp: Dictionary = RECITA_TRANS[trans]
		var x := clampf(trans_t / float(tp["dur"]), 0.0, 1.0)
		var env: float
		if trans == "trasalisce":
			env = exp(-3.2 * trans_t)      # attacco ISTANTANEO, poi si spegne
		else:
			env = smoothstep(0.0, 0.22, x) * (1.0 - smoothstep(0.68, 1.0, x))
		_recita_somma(out, tp, env, t)
		if trans == "trasalisce":
			# il sobbalzo: due colpetti che muoiono in fretta
			out["vy"] += 0.14 * exp(-4.0 * trans_t) * absf(sin(trans_t * 10.0))
			# IL MEZZO PASSO INDIETRO. Scatta con lo spavento e rientra
			# piano, come si rientra da uno spavento: il corpo torna dove
			# era un attimo dopo che la testa ha capito.
			out["vz"] += 0.16 * exp(-2.1 * trans_t)
			# e la coda si irrigidisce di colpo, poi si riabbassa
			out["tail"] += -0.9 * exp(-2.6 * trans_t)
		elif trans == "si_illumina":
			# il saltello di gioia: rimbalza morbido finché dura la luce
			out["vy"] += 0.09 * env * absf(sin(trans_t * 8.5))
		elif trans == "saluto_festoso":
			# le braccine sventolano insieme e il corpo saltella: la
			# gioia senza filtri del chiacchierone
			out["az0"] += 0.3 * sin(t * 11.0) * env
			out["az1"] += 0.3 * sin(t * 11.0) * env
			out["vy"] += 0.09 * absf(sin(trans_t * 6.3)) * env
		elif trans == "saluto_timido":
			# l'applauso PICCOLO: le zampine giunte si toccano appena,
			# battiti minuti (mai un plauso pieno: si vergogna un po')
			var battito := 0.09 * maxf(0.0, sin(trans_t * 14.0))
			out["az0"] += battito * env
			out["az1"] -= battito * env
		elif trans == "saluto_brontolone":
			# prima un mezzo no della testa che si spegne... poi il
			# saltello RILUTTANTE, uno solo e trattenuto — e in coda un
			# secondo, piccolissimo: il cuore di panna vince sempre
			out["hy"] += 0.14 * sin(trans_t * 8.0) * exp(-trans_t * 2.6)
			if trans_t > 0.55 and trans_t < 0.97:
				out["vy"] += 0.07 * maxf(0.0, sin((trans_t - 0.55) * 7.5))
			if trans_t > 1.25 and trans_t < 1.6:
				out["vy"] += 0.045 * maxf(0.0, sin((trans_t - 1.25) * 9.0))
		elif trans == "saluto_sognante":
			# la zampa alta ondeggia LENTA (la testolina è già al cielo)
			out["az1"] += 0.3 * sin(t * 2.3) * env
		elif trans == "saluto_pancino":
			# le zampine tamburellano contente sul pancino
			var pat := 0.08 * sin(trans_t * 13.0)
			out["az0"] += pat * env
			out["az1"] -= pat * env
			out["vy"] += 0.02 * absf(sin(trans_t * 6.5)) * env
		elif trans == "saluto_stiracchio":
			# lo stiracchiamento-saluto: le braccine su piano piano e il
			# corpo che si allunga — è ancora mezzo addormentato
			out["vy"] += 0.05 * smoothstep(0.2, 0.9, trans_t / 2.1) * env
		elif trans == "saluto_scattante":
			# lo sventolio SECCO del mattiniero: due colpi rapidi e via
			out["az1"] += 0.42 * sin(t * 15.0) * env
			out["vy"] += 0.08 * absf(sin(trans_t * 9.0)) * exp(-trans_t * 1.6)
		# (saluto_inchino: l'inviluppo fa tutto — giù morbido, su preciso)
	return out


static func _recita_somma(out: Dictionary, p: Dictionary, peso: float,
		t: float) -> void:
	out["ax0"] += float(p.get("ax", 0.0)) * peso
	out["ax1"] += float(p.get("ax_dx", p.get("ax", 0.0))) * peso
	out["az0"] += float(p.get("az", 0.0)) * peso     # sinistro verso il petto
	out["az1"] += -float(p.get("az", 0.0)) * peso    # destro, specchiato
	out["ear"] += float(p.get("ear", 0.0)) * peso
	out["hx"] += float(p.get("hx", 0.0)) * peso
	out["vx"] += float(p.get("vx", 0.0)) * peso
	out["vz"] += float(p.get("vz", 0.0)) * peso
	out["tail"] += float(p.get("tail", 0.0)) * peso
	var amp := float(p.get("hy_amp", 0.0))
	if amp > 0.0:
		var onda := sin(t * 0.75)
		if p.has("hy_scatti"):
			# lo sguardo sfuggente non vaga: SALTA via e torna
			onda = sin(t * 0.9) * 0.7 + sin(t * 5.3) * 0.3
		out["hy"] += amp * onda * peso


## Toglie dal rig gli offset del frame scorso (chiamata a INIZIO _process).
func _recita_togli() -> void:
	if _rc_appl.is_empty():
		return
	if _c_arms.size() == 2:
		_c_arms[0].rotation.x -= _rc_appl["ax0"]
		_c_arms[0].rotation.z -= _rc_appl["az0"]
		_c_arms[1].rotation.x -= _rc_appl["ax1"]
		_c_arms[1].rotation.z -= _rc_appl["az1"]
	for ear in _c_ears:
		ear.rotation.x -= _rc_appl["ear"]
	if _head:
		_head.rotation.x -= _rc_appl["hx"]
		_head.rotation.y -= _rc_appl["hy"]
	if _vis:
		_vis.rotation.x -= _rc_appl["vx"]
		_vis.position.y -= _rc_appl["vy"]
		_vis.position.z -= _rc_appl.get("vz", 0.0)
	if _tail_p:
		_tail_p.rotation.x -= _rc_appl.get("tail", 0.0)
	_rc_appl = {}


## LA POSTURA STABILE DI ADESSO ("sereno" = corpo neutro, nessuno l'ha
## posata). La chiede chi deve decidere se può posare la sua.
##
## Serve perché `has_meta("postura")` NON risponde a quella domanda: quando
## un transitorio si consuma il meta viene RISCRITTO con la stabile
## sottostante, quindi dal primo saluto in poi (bastava passare a 1,4 m) il
## meta esiste per sempre — e ogni ramo che chiedeva `has_meta(...) == false`
## era morto da quel momento, in silenzio.
func postura_stabile() -> String:
	# il meta posato in questo frame vale già: `_recita_applica` lo legge
	# solo al `_process` successivo, e in mezzo la risposta sarebbe vecchia
	var m := str(get_meta("postura", ""))
	if m != "" and RECITA.has(m):
		return m
	return _rc_stabile


## Vero se il corpo è libero: nessuna posa stabile addosso.
func postura_libera() -> bool:
	return postura_stabile() == "sereno"


## Legge il meta "postura", fonde coi muscoli, applica (FINE _process).
func _recita_applica(delta: float) -> void:
	var meta := str(get_meta("postura", ""))
	if meta != "":
		if RECITA_TRANS.has(meta):
			# un transitorio si CONSUMA: lo recitiamo ora, e il meta torna
			# alla postura stabile sottostante
			_rc_trans = meta
			_rc_trans_t = 0.0
			set_meta("postura", _rc_stabile)
		elif RECITA.has(meta) and meta != _rc_stabile:
			_rc_stabile = meta
	elif _rc_stabile != "sereno":
		# IL RITORNO. Chi TOGLIE il meta (la ferita degli Affetti che si
		# richiude, il concerto che finisce, il telegrafo che si spegne) non
		# entrava in nessun ramo: `_rc_stabile` restava quello di prima PER
		# SEMPRE. Il vicino che il giocatore ha consolato per giorni
		# rimaneva curvo con le spalle basse per il resto della partita — il
		# gesto più delicato del gioco senza nessun riscontro nel corpo — e
		# il pubblico del concerto restava «attento» a palco vuoto.
		# «sereno» è la posa neutra e nessuno la scriveva mai: la scriviamo
		# qui, dove si torna. (I TRANSITORI non passano di qui: quando ne
		# arriva uno il meta viene riscritto con la stabile sottostante,
		# quindi non è mai vuoto mentre un sussulto è in corso.)
		_rc_stabile = "sereno"
	if _rc_trans != "":
		_rc_trans_t += delta
		if _rc_trans_t >= float(RECITA_TRANS[_rc_trans]["dur"]):
			_rc_trans = ""

	# solo i corpi chibi hanno il rig completo (non passerotti né ricci)
	if dna.is_empty() or _vis == null:
		return
	# chi DORME non recita posture — ma la sua postura non si CANCELLA:
	# si sospende. (Scrivere "sereno" nel meta agganciava _rc_stabile e il
	# telegrafo della ribellione restava spento fino al gradino dopo.)
	var stab := "sereno" if _state == "tk_nap" else _rc_stabile
	# …e nemmeno i TRANSITORI: chi dorme non trasalisce ne' si illumina
	# quando ti avvicini (bastavano 3.2 m per far sobbalzare un dormiente)
	var trans := "" if _state == "tk_nap" else _rc_trans
	var bersagli := recita_bersagli(stab, trans, _rc_trans_t, _t)
	# la pioggia si somma a QUALUNQUE postura: chiunque sia — fiero,
	# imbronciato, in partenza — sotto l'acqua si ripara comunque.
	# Tranne chi DORME: la zampina a visiera sopra un dormiente sarebbe
	# la posa di due corpi diversi nello stesso chibi
	_riparo = lerpf(_riparo, 1.0 if (riparo_pioggia and _state != "tk_nap") else 0.0,
			1.0 - exp(-4.0 * delta))
	if _riparo > 0.01:
		# la destra quasi verticale e un filo VERSO FUORI: davanti alla
		# testona sparirebbe (lezione del saluto), di fianco si legge
		bersagli["ax1"] += -2.75 * _riparo   # negativo = su, come il fagotto
		bersagli["az1"] += 0.45 * _riparo    # fuori dal bordo della testona
		bersagli["ax0"] += 0.3 * _riparo     # la sinistra stretta al corpo
		bersagli["ear"] += 0.85 * _riparo    # orecchie appiattite
		bersagli["hx"] += 0.15 * _riparo     # la testolina nelle spalle
		bersagli["vx"] += 0.12 * _riparo     # il corpo si raggomitola
		# se un'altra recita ha già alzato la destra (il fagotto della
		# partenza), non si gira oltre: la spalla è una spalla, non un mozzo
		bersagli["ax1"] = maxf(bersagli["ax1"], -2.9)
	# fusione coi muscoli: il corpo cambia idea in mezzo secondo, mai a scatto
	var k := 1.0 - exp(-6.0 * delta)
	for c in bersagli:
		_rc_cur[c] = lerpf(float(_rc_cur.get(c, 0.0)), float(bersagli[c]), k)

	_mostra_fagotto(bool((RECITA.get(stab, {}) as Dictionary) \
			.get("fagotto", false)))

	if _c_arms.size() == 2:
		_c_arms[0].rotation.x += _rc_cur["ax0"]
		_c_arms[0].rotation.z += _rc_cur["az0"]
		_c_arms[1].rotation.x += _rc_cur["ax1"]
		_c_arms[1].rotation.z += _rc_cur["az1"]
	for ear in _c_ears:
		ear.rotation.x += _rc_cur["ear"]
	if _head:
		_head.rotation.x += _rc_cur["hx"]
		_head.rotation.y += _rc_cur["hy"]
	_vis.rotation.x += _rc_cur["vx"]
	_vis.position.y += _rc_cur["vy"]
	# il mezzo passo indietro: uno spostamento VERO, non un'inclinazione
	_vis.position.z += _rc_cur["vz"]
	if _tail_p:
		_tail_p.rotation.x += _rc_cur["tail"]
	_rc_appl = _rc_cur.duplicate()


## Il fagottino del trasloco: bastone sulla spalla, sacchetto annodato.
## È il segno della diserzione che si vede da lontano — e per questo è
## un oggetto VERO, non un'icona.
static func fai_fagotto() -> Node3D:
	var n := Node3D.new()
	var legno := BUILDER._mat(Color("8a6444"))
	var stoffa := BUILDER._mat(Color("d9b3c2"))
	var nodo_m := BUILDER._mat(Color("b98499"))

	var cm := CylinderMesh.new()
	cm.top_radius = 0.022
	cm.bottom_radius = 0.022
	cm.height = 0.62
	var bastone := MeshInstance3D.new()
	bastone.mesh = cm
	bastone.material_override = legno
	bastone.position = Vector3(0.27, 0.66, 0.14)
	bastone.rotation.x = -0.95
	bastone.rotation.z = -0.22
	n.add_child(bastone)

	var sm := SphereMesh.new()
	sm.radius = 0.115
	sm.height = 0.23
	sm.radial_segments = 14
	sm.rings = 8
	var sacco := MeshInstance3D.new()
	sacco.mesh = sm
	sacco.material_override = stoffa
	sacco.position = Vector3(0.33, 0.8, 0.46)
	sacco.scale = Vector3(1.0, 0.92, 1.0)
	n.add_child(sacco)

	var nm := SphereMesh.new()
	nm.radius = 0.038
	nm.height = 0.076
	nm.radial_segments = 10
	nm.rings = 6
	var nodo := MeshInstance3D.new()
	nodo.mesh = nm
	nodo.material_override = nodo_m
	nodo.position = Vector3(0.33, 0.9, 0.41)
	n.add_child(nodo)
	# le due orecchiette del fiocco, sopra il nodo
	for lato: float in [-1.0, 1.0]:
		var om := SphereMesh.new()
		om.radius = 0.032
		om.height = 0.064
		om.radial_segments = 8
		om.rings = 5
		var orecchia := MeshInstance3D.new()
		orecchia.mesh = om
		orecchia.material_override = stoffa
		orecchia.position = Vector3(0.33 + lato * 0.045, 0.94, 0.39)
		orecchia.scale = Vector3(0.8, 1.3, 0.5)
		orecchia.rotation.z = lato * -0.5
		n.add_child(orecchia)
	return n


func _mostra_fagotto(serve: bool) -> void:
	if serve and (_fagotto == null or not is_instance_valid(_fagotto)):
		if _vis.get_child_count() == 0:
			return
		_fagotto = fai_fagotto()
		_vis.get_child(0).add_child(_fagotto)
		_fagotto.scale = Vector3.ONE * 0.05
		create_tween().tween_property(_fagotto, "scale", Vector3.ONE, 0.45) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif not serve and _fagotto != null and is_instance_valid(_fagotto):
		var f := _fagotto
		_fagotto = null
		var tw := create_tween()
		tw.tween_property(f, "scale", Vector3.ONE * 0.05, 0.3)
		tw.tween_callback(f.queue_free)
