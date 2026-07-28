extends Node3D

## Il guardaroba di Mochi. Ogni capo è un RICORDO indossabile: si
## sblocca vivendo, non comprando — il cappello di petali con la prima
## fioritura, la lanterna-lucciola da polso con la prima lucciola in
## collezione, la sciarpina di lana coi regali del passerotto,
## l'impermeabilino giallo con la prima pioggia (e indossarlo sotto la
## pioggia la rende FELICE: scintille dorate ai piedi). G apre il
## guardaroba; i residenti vicini commentano il vestito nuovo in
## Chibiese («wa-wi!»). Tutto persistito nel JSON.

const HANDPAINT := preload("res://shaders/handpaint.gdshader")
const UI_BROWN := Color("6a4a3a")

# id -> {nome, slot, sblocco (racconto), icona}
const CAPI := {
	"cappello_petali": {"nome": "il cappello di petali", "slot": "testa",
		"sblocco": "la prima fioritura del giardino", "icona": "✿"},
	"lanterna_lucciola": {"nome": "la lanterna-lucciola da polso", "slot": "polso",
		"sblocco": "una lucciola in collezione", "icona": "●"},
	"sciarpina_lana": {"nome": "la sciarpina di lana", "slot": "collo",
		"sblocco": "un regalino del passerotto", "icona": "~"},
	"impermeabilino": {"nome": "l'impermeabilino giallo", "slot": "corpo",
		"sblocco": "la prima pioggerella vissuta", "icona": "☂"},
	# le stagioni vissute: ogni alba in una stagione nuova lascia un capo
	"fiocco_ciliegio": {"nome": "il fiocco di ciliegio", "slot": "testa",
		"sblocco": "vivere un'alba di primavera", "icona": "❀"},
	"occhialini_sole": {"nome": "gli occhialini da sole", "slot": "testa",
		"sblocco": "vivere un'alba d'estate", "icona": "◐"},
	"mantellina_foglie": {"nome": "la mantellina di foglie", "slot": "corpo",
		"sblocco": "vivere un'alba d'autunno", "icona": "❦"},
	"cuffietta_neve": {"nome": "la cuffietta di neve", "slot": "testa",
		"sblocco": "vivere un'alba d'inverno", "icona": "❄"},
	# i momenti grandi
	"cerchietto_stelle": {"nome": "il cerchietto di stelle", "slot": "testa",
		"sblocco": "battezzare la prima costellazione", "icona": "✦"},
	"cappellino_festa": {"nome": "il cappellino di festa", "slot": "testa",
		"sblocco": "la prima festa a sorpresa", "icona": "▲"},
	# le amicizie piene, una per ogni archetipo del villaggio
	"campanellino_gatto": {"nome": "il campanellino d'argento", "slot": "collo",
		"sblocco": "l'amicizia piena con un gattino", "icona": "○"},
	"portafortuna_carota": {"nome": "la carotina portafortuna", "slot": "polso",
		"sblocco": "l'amicizia piena con una coniglietta", "icona": "▼"},
	"vasetto_miele": {"nome": "il vasetto di miele", "slot": "corpo",
		"sblocco": "l'amicizia piena con un orsetto", "icona": "◆"},
	"coda_sciarpa": {"nome": "la coda-sciarpa fulva", "slot": "collo",
		"sblocco": "l'amicizia piena con una volpina", "icona": "∿"},
	"berretto_orecchie": {"nome": "il berretto con le orecchie", "slot": "testa",
		"sblocco": "l'amicizia piena con un topolino", "icona": "◉"},
}
const ORDER := ["cappello_petali", "lanterna_lucciola", "sciarpina_lana",
	"impermeabilino", "fiocco_ciliegio", "occhialini_sole", "mantellina_foglie",
	"cuffietta_neve", "cerchietto_stelle", "cappellino_festa",
	"campanellino_gatto", "portafortuna_carota", "vasetto_miele",
	"coda_sciarpa", "berretto_orecchie"]

## Il capo di ogni stagione (indice = stagione di DayNight, 0..3).
const STAGIONE_CAPO := ["fiocco_ciliegio", "occhialini_sole",
	"mantellina_foglie", "cuffietta_neve"]

## Il capo di ogni archetipo di residente (le chiavi COMBACIANO con
## ChibiDNA.ARCHETYPES: un test fa la guardia).
const ARCHETIPO_CAPO := {
	"gatto": "campanellino_gatto", "coniglio": "portafortuna_carota",
	"orsetto": "vasetto_miele", "volpina": "coda_sciarpa",
	"topolino": "berretto_orecchie",
}

## Da quanti cuoricini l'amicizia è "piena" (la soglia del ricordo).
const AMICIZIA_MASSIMA := 5

var _player: Node3D
var _mochi: Node3D
var _weather: Node
var _build: Node3D
var _sfx

var _unlocked := {}
var _worn := {}          # id -> nodo indossato
# i RICORDINI di chi è partito per il Grande Prato (Fase 5 del Filo
# Rosso): capi dinamici, uno per partenza, tinti col SUO colore.
# id "ricordo_<nome>" -> {"nome": testo, "colore": html}
var _ricordi := {}
var _was_raining := false
var _rain_joy := 0.0
var _lantern_light: OmniLight3D
var _daynight: Node3D

var _open := false
var _panel: PanelContainer
var _rows: VBoxContainer


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("guardaroba")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_ui()
	(func():
		# i nodi creati a runtime non risolvono %Player: percorso esplicito
		_player = get_node_or_null("../../Player")
		_mochi = _player.get_node_or_null("Mochi") if _player else null
		_weather = get_node_or_null("../../Weather")
		_daynight = get_node_or_null("../../DayNight")
		_build = get_tree().get_first_node_in_group("build_system")
		# ogni alba in una stagione nuova lascia il suo capo nel baule
		if _daynight and _daynight.has_signal("day_changed"):
			_daynight.day_changed.connect(_on_alba)).call_deferred()


## L'alba: vivere una stagione (esserci al suo mattino) è già il ricordo.
func _on_alba(_giorno: int) -> void:
	if _daynight and _daynight.has_method("get_season"):
		unlock(str(STAGIONE_CAPO[clampi(int(_daynight.get_season()), 0, 3)]))


## L'amicizia piena con un residente: il suo archetipo lascia il ricordo.
## La chiama Visitors a ogni cuoricino: la soglia la decide il guardaroba.
func unlock_amicizia(archetipo: String, cuoricini: int) -> void:
	if cuoricini >= AMICIZIA_MASSIMA and ARCHETIPO_CAPO.has(archetipo):
		unlock(str(ARCHETIPO_CAPO[archetipo]))


## La scheda di un capo: dal catalogo fisso o dai ricordini dinamici.
func _capo_info(id: String) -> Dictionary:
	if CAPI.has(id):
		return CAPI[id]
	if _ricordi.has(id):
		# il `nome` salvato resta italiano (viaggia nel villaggio): a schermo
		# la frase si ricompone tradotta attorno al nome del vicino
		return {"nome": L10n.tf("il ricordino di %s", [id.trim_prefix("ricordo_")]),
				"slot": "collo", "icona": "❀", "sblocco": ""}
	return {}


## Tutti i capi nell'ordine del pannello: prima il catalogo, poi i
## ricordini (in ordine stabile).
func _ordine() -> Array:
	var out: Array = ORDER.duplicate()
	var ricordi: Array = _ricordi.keys()
	ricordi.sort()
	out.append_array(ricordi)
	return out


## Il ricordino di chi è partito: entra nel guardaroba già sbloccato,
## col suo colore. Quando Mochi lo indossa, i vicini si fermano: «mi-ka…».
func unlock_ricordo(nome: String, colore: Color) -> void:
	var id := "ricordo_" + nome
	if _unlocked.has(id):
		return
	_ricordi[id] = {"nome": "il ricordino di %s" % nome,
			"colore": colore.to_html(false)}
	_unlocked[id] = true
	_toast(L10n.tf("Nel guardaroba c'è il ricordino di %s, piegato con cura. (G)", [nome]))
	if _sfx:
		_sfx.build_open()
	if _build:
		_build.request_save()


## Sblocca un capo (se è nuovo): toast, scintille, campanellino.
func unlock(id: String) -> void:
	if _unlocked.has(id) or not CAPI.has(id):
		return
	_unlocked[id] = true
	var capo: Dictionary = CAPI[id]
	_toast(L10n.tf("Nuovo capo nel guardaroba: %s! (G per indossarlo)",
			[L10n.t(str(capo["nome"]))]))
	if _mochi:
		var gtree := get_tree().get_first_node_in_group("grande_albero")
		if gtree:
			gtree.call("_sparkle", _player.global_position + Vector3(0, 1.2, 0), 14)
	if _sfx:
		_sfx.build_open()
	if _build:
		_build.request_save()


func _toggle_wear(id: String) -> void:
	if not _unlocked.has(id):
		return
	if _worn.has(id):
		_unwear(id)
	else:
		# un capo per slot: il nuovo scalza il vecchio
		for other in _worn.keys():
			if _capo_info(other)["slot"] == _capo_info(id)["slot"]:
				_unwear(other)
		_wear(id)
		if id.begins_with("ricordo_"):
			_compliments_ricordo()
		else:
			_compliments()
	if _sfx:
		_sfx.ui_select()
	if _build:
		_build.request_save()
	_refresh_panel()


func _wear(id: String) -> void:
	if _mochi == null or _worn.has(id) or _capo_info(id).is_empty():
		return
	var node := _build_capo(id)
	var mount: Node3D = _mochi.call("get_attach_point", _capo_info(id)["slot"])
	mount.add_child(node)
	_worn[id] = node
	node.scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _unwear(id: String) -> void:
	var node: Node3D = _worn.get(id)
	if node and is_instance_valid(node):
		node.queue_free()
	_worn.erase(id)
	if id == "lanterna_lucciola":
		_lantern_light = null


# il ricordino addosso: i vicini si fermano, sottovoce — «mi-ka…» (amico)
func _compliments_ricordo() -> void:
	var visitors := get_node_or_null("../../Visitors")
	if visitors == null or _player == null:
		return
	for r in visitors.get("_residents"):
		var node := r.get("node") as Node3D
		if node and is_instance_valid(node) and not node.call("is_hidden") \
				and node.global_position.distance_to(_player.global_position) < 6.0:
			node.call("face_towards", _player.global_position)
			node.call("speak", ["amico"], "triste")
			node.call("chat_bubble", "…")


# i residenti vicini si voltano e commentano: «wa-wi!»
func _compliments() -> void:
	var visitors := get_node_or_null("../../Visitors")
	if visitors == null or _player == null:
		return
	for r in visitors.get("_residents"):
		var node := r.get("node") as Node3D
		if node and is_instance_valid(node) and not node.call("is_hidden") \
				and node.global_position.distance_to(_player.global_position) < 6.0:
			node.call("face_towards", _player.global_position)
			node.call("speak", ["felice", "~"], "felice")
			node.call("_spawn_heart")


# ---------------------------------------------------------------- i capi

func _pm(a: Color, b: Color, grain := 5.0, amount := 0.5) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = HANDPAINT
	mat.set_shader_parameter("color_a", a)
	mat.set_shader_parameter("color_b", b)
	mat.set_shader_parameter("noise_scale", grain)
	mat.set_shader_parameter("noise_amount", amount)
	# gli accessori indossati non si coprono di neve d'inverno (i vestiti
	# di Mochi restano suoi: la neve è del mondo, non dei personaggi)
	mat.set_shader_parameter("no_snow", true)
	return mat


func _ball(parent: Node3D, r: float, mat: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 9
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, top: float, bottom: float, h: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = 14
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _build_capo(id: String) -> Node3D:
	var n := Node3D.new()
	match id:
		"cappello_petali":
			# coroncina di petali sulla testolina, col cuoricino giallo
			n.position = Vector3(0, 0.36, 0.0)
			n.rotation.z = -0.08
			var petal := _pm(Color("f7bcd2"), Color("eba4be"), 6.0, 0.45)
			var petal2 := _pm(Color("fff2f7"), Color("f2dce8"), 6.0, 0.45)
			for i in 8:
				var a := float(i) / 8.0 * TAU
				var p := _ball(n, 0.088, petal if i % 2 == 0 else petal2,
						Vector3(cos(a) * 0.27, sin(a * 3.0) * 0.015, sin(a) * 0.27),
						Vector3(1.2, 0.5, 0.85))
				p.rotation.y = -a
				p.rotation.x = 0.2
			_ball(n, 0.055, _pm(Color("ffd76e"), Color("eec254")), Vector3(0, 0.1, -0.24))
		"lanterna_lucciola":
			# il barattolino da polso: dentro, una lucciola vera che pulsa
			# (segue il polso delle braccine accorciate)
			n.position = Vector3(0, -0.32, -0.06)
			var metal := _pm(Color("8a7f72"), Color("6f665b"), 4.0, 0.4)
			var ring := TorusMesh.new()
			ring.inner_radius = 0.075
			ring.outer_radius = 0.095
			var rmi := MeshInstance3D.new()
			rmi.mesh = ring
			rmi.material_override = metal
			rmi.rotation.x = PI * 0.5
			n.add_child(rmi)
			var glass := StandardMaterial3D.new()
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.albedo_color = Color(0.85, 0.95, 0.9, 0.3)
			_ball(n, 0.058, glass, Vector3(0, -0.095, 0), Vector3(1, 1.25, 1))
			var glow := StandardMaterial3D.new()
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.albedo_color = Color("d8ffa0")
			glow.emission_enabled = true
			glow.emission = Color(0.75, 1.0, 0.45)
			glow.emission_energy_multiplier = 1.4
			_ball(n, 0.02, glow, Vector3(0, -0.095, 0))
			_ball(n, 0.028, metal, Vector3(0, -0.02, 0), Vector3(1, 0.5, 1))
			_lantern_light = OmniLight3D.new()
			_lantern_light.light_color = Color(0.8, 1.0, 0.55)
			_lantern_light.omni_range = 3.0
			_lantern_light.light_energy = 0.0
			_lantern_light.shadow_enabled = false
			_lantern_light.position = Vector3(0, -0.095, 0)
			n.add_child(_lantern_light)
		"sciarpina_lana":
			# lana calda a girocollo, coi lembi che ricadono e le frange
			n.position = Vector3(0, 0.6, 0)
			var wool := _pm(Color("d97a6a"), Color("c26454"), 7.0, 0.6)
			var wrap_mesh := TorusMesh.new()
			wrap_mesh.inner_radius = 0.19
			wrap_mesh.outer_radius = 0.31
			var wmi := MeshInstance3D.new()
			wmi.mesh = wrap_mesh
			wmi.material_override = wool
			wmi.scale = Vector3(1, 0.8, 1)
			n.add_child(wmi)
			var tail := _ball(n, 0.08, wool, Vector3(0.12, -0.13, -0.26), Vector3(0.8, 1.7, 0.45))
			tail.rotation.z = 0.15
			var tail2 := _ball(n, 0.065, wool, Vector3(-0.05, -0.07, -0.27), Vector3(0.75, 1.2, 0.42))
			tail2.rotation.z = -0.12
			for i in 3:
				_ball(n, 0.02, wool, Vector3(0.08 + i * 0.032, -0.27, -0.26), Vector3(0.6, 1.6, 0.6))
		"impermeabilino":
			# mantellina gialla col cappuccio ripiegato e i bottoni
			var rain_mat := _pm(Color("ffd35c"), Color("f0bc42"), 4.0, 0.4)
			var cape := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.21
			cm.bottom_radius = 0.43
			cm.height = 0.56
			cape.mesh = cm
			cape.material_override = rain_mat
			cape.position = Vector3(0, 0.42, 0)
			n.add_child(cape)
			# cappuccio ripiegato dietro le spalle
			_ball(n, 0.15, rain_mat, Vector3(0, 0.64, 0.22), Vector3(1.25, 0.7, 0.85))
			var btn := _pm(Color("fff3e0"), Color("efe2cc"), 5.0, 0.3)
			for i in 3:
				_ball(n, 0.024, btn, Vector3(0, 0.58 - i * 0.12, -0.31 + i * 0.05))
		"fiocco_ciliegio":
			# il fiocco rosa di lato, con le due asole e i nastrini che ricadono
			n.position = Vector3(0.24, 0.3, -0.05)
			n.rotation.z = -0.25
			var rosa := _pm(Color("f7a8c4"), Color("e88aae"), 5.0, 0.45)
			_ball(n, 0.085, rosa, Vector3(-0.07, 0.04, 0), Vector3(1.35, 0.75, 0.55))
			_ball(n, 0.085, rosa, Vector3(0.07, 0.04, 0), Vector3(1.35, 0.75, 0.55))
			_ball(n, 0.045, _pm(Color("ffd6e6"), Color("f2b8ce")), Vector3(0, 0.04, 0))
			for lato: float in [-1.0, 1.0]:
				var nastro := _ball(n, 0.03, rosa, Vector3(lato * 0.05, -0.09, 0),
						Vector3(0.7, 2.2, 0.5))
				nastro.rotation.z = lato * 0.35
		"occhialini_sole":
			# due lenti tonde scure sul musetto, con la stanghetta dorata
			n.position = Vector3(0, 0.12, -0.3)
			var lente := StandardMaterial3D.new()
			lente.albedo_color = Color(0.16, 0.13, 0.2, 0.82)
			lente.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			lente.roughness = 0.15
			var oro := _pm(Color("e8c46a"), Color("c49c48"), 4.0, 0.35)
			for lato: float in [-1.0, 1.0]:
				_ball(n, 0.075, lente, Vector3(lato * 0.11, 0, 0), Vector3(1, 1, 0.3))
			_ball(n, 0.02, oro, Vector3(0, 0.015, 0), Vector3(1.6, 0.5, 0.5))
		"mantellina_foglie":
			# foglie d'autunno cucite a mantellina, dal rame all'oro
			var toni := [_pm(Color("e0885a"), Color("c96a42"), 5.0, 0.5),
					_pm(Color("e8b04a"), Color("cf9438"), 5.0, 0.5),
					_pm(Color("c9603a"), Color("a84e30"), 5.0, 0.5)]
			for i in 9:
				var a := -PI * 0.78 + float(i) / 8.0 * PI * 1.56
				var foglia = _ball(n, 0.11, toni[i % 3],
						Vector3(sin(a) * 0.3, 0.5 - absf(sin(a * 0.5)) * 0.06, -cos(a) * 0.3),
						Vector3(0.85, 1.5, 0.4))
				foglia.rotation.y = -a
				foglia.rotation.x = 0.35
			_ball(n, 0.035, _pm(Color("8a5a3a"), Color("6f4830")), Vector3(0, 0.62, -0.3))
		"cuffietta_neve":
			# cuffietta bianca calcata sulla testolina, col ponpon che dondola
			n.position = Vector3(0, 0.3, 0)
			var lana := _pm(Color("f7f4ee"), Color("e6e0d4"), 7.0, 0.55)
			_ball(n, 0.3, lana, Vector3(0, 0.05, 0), Vector3(1.05, 0.75, 1.05))
			var bordo := _cyl(n, 0.305, 0.305, 0.07, _pm(Color("efe8dc"), Color("ddd4c4"), 8.0, 0.6),
					Vector3(0, -0.09, 0))
			bordo.scale = Vector3(1, 1, 1)
			_ball(n, 0.07, lana, Vector3(0, 0.3, 0.06))
		"cerchietto_stelle":
			# un cerchietto sottile con tre stelline che brillano di sera
			n.position = Vector3(0, 0.3, 0)
			var oro := _pm(Color("e8c46a"), Color("c49c48"), 4.0, 0.35)
			var fascia := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.29
			tm.outer_radius = 0.315
			fascia.mesh = tm
			fascia.material_override = oro
			fascia.rotation.x = 0.12
			fascia.scale = Vector3(1, 0.5, 1)
			n.add_child(fascia)
			var stella := StandardMaterial3D.new()
			stella.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			stella.albedo_color = Color("fff2b8")
			stella.emission_enabled = true
			stella.emission = Color(1.0, 0.9, 0.55)
			stella.emission_energy_multiplier = 1.1
			for i in 3:
				var a := PI * 0.5 + (float(i) - 1.0) * 0.55
				_ball(n, 0.035 if i == 1 else 0.026, stella,
						Vector3(cos(a) * 0.3, 0.1 + (0.04 if i == 1 else 0.0), -sin(a) * 0.3))
		"cappellino_festa":
			# il cono di festa a strisce, in equilibrio allegro di sbieco
			n.position = Vector3(0.12, 0.4, 0)
			n.rotation.z = -0.3
			var cono := _cyl(n, 0.01, 0.16, 0.3, _pm(Color("9fd8cf"), Color("86c2b8"), 5.0, 0.45),
					Vector3(0, 0.08, 0))
			cono.scale = Vector3.ONE
			_cyl(n, 0.125, 0.145, 0.055, _pm(Color("f4b8c8"), Color("eba4b8"), 5.0, 0.45),
					Vector3(0, -0.015, 0))
			_ball(n, 0.045, _pm(Color("ffd76e"), Color("eec254")), Vector3(0, 0.25, 0))
		"campanellino_gatto":
			# il collarino sottile col campanellino d'argento che tintinna
			n.position = Vector3(0, 0.56, 0)
			var nastro := _pm(Color("c25a7a"), Color("a84a66"), 5.0, 0.45)
			var giro := MeshInstance3D.new()
			var gm := TorusMesh.new()
			gm.inner_radius = 0.21
			gm.outer_radius = 0.25
			giro.mesh = gm
			giro.material_override = nastro
			giro.scale = Vector3(1, 0.6, 1)
			n.add_child(giro)
			var argento := _pm(Color("d8d8e0"), Color("b0b0bc"), 4.0, 0.3)
			_ball(n, 0.05, argento, Vector3(0, -0.06, -0.24))
			_ball(n, 0.018, _pm(Color("8a8a94"), Color("6f6f78")), Vector3(0, -0.09, -0.26))
		"portafortuna_carota":
			# la carotina di stoffa appesa al polso, col ciuffetto verde
			n.position = Vector3(0, -0.3, -0.05)
			var arancio := _pm(Color("f0913c"), Color("d67a2e"), 5.0, 0.5)
			var carota := _cyl(n, 0.012, 0.045, 0.14, arancio, Vector3(0, -0.1, 0))
			carota.rotation.z = 0.15
			for i in 3:
				var ciuffo := _ball(n, 0.02, _pm(Color("7fbc62"), Color("5f9c48")),
						Vector3(-0.01 + i * 0.012, -0.02, 0), Vector3(0.5, 1.6, 0.5))
				ciuffo.rotation.z = -0.3 + i * 0.3
			_cyl(n, 0.006, 0.006, 0.08, _pm(Color("d9c4a8"), Color("c4ae90")), Vector3(0, 0.0, 0))
		"vasetto_miele":
			# il vasetto di miele legato in vita, con l'etichetta e il coperchio
			n.position = Vector3(0.26, 0.42, 0.12)
			n.rotation.z = -0.1
			var vetro := _pm(Color("e8b04a"), Color("cf9438"), 4.0, 0.4)
			_cyl(n, 0.07, 0.08, 0.13, vetro, Vector3(0, 0, 0))
			_cyl(n, 0.075, 0.075, 0.03, _pm(Color("a87c50"), Color("8a6440")), Vector3(0, 0.08, 0))
			_ball(n, 0.035, _pm(Color("fff3e0"), Color("f0e2cc")), Vector3(0, 0, -0.075),
					Vector3(1.2, 1.2, 0.3))
		"coda_sciarpa":
			# la coda-sciarpa fulva con la punta bianca, morbida sul collo
			n.position = Vector3(0, 0.6, 0)
			var fulvo := _pm(Color("e0885a"), Color("c96a42"), 6.0, 0.55)
			var giro2 := MeshInstance3D.new()
			var g2 := TorusMesh.new()
			g2.inner_radius = 0.19
			g2.outer_radius = 0.3
			giro2.mesh = g2
			giro2.material_override = fulvo
			giro2.scale = Vector3(1, 0.75, 1)
			n.add_child(giro2)
			var coda := _ball(n, 0.09, fulvo, Vector3(0.14, -0.16, -0.24), Vector3(0.9, 1.9, 0.55))
			coda.rotation.z = 0.2
			_ball(n, 0.055, _pm(Color("fff6ee"), Color("efe4d6")), Vector3(0.19, -0.32, -0.24),
					Vector3(0.8, 1.0, 0.5))
		"berretto_orecchie":
			# il berrettino grigio con le orecchie tonde da topolino
			n.position = Vector3(0, 0.3, 0)
			var grigio := _pm(Color("b8b2c0"), Color("948e9e"), 5.0, 0.5)
			_ball(n, 0.3, grigio, Vector3(0, 0.04, 0), Vector3(1.04, 0.7, 1.04))
			for lato: float in [-1.0, 1.0]:
				_ball(n, 0.1, grigio, Vector3(lato * 0.24, 0.2, 0), Vector3(1, 1, 0.45))
				_ball(n, 0.055, _pm(Color("f2c8d4"), Color("e0aebc")),
						Vector3(lato * 0.24, 0.2, -0.02), Vector3(1, 1, 0.3))
		_:
			if id.begins_with("ricordo_") and _ricordi.has(id):
				# il ricordino di chi è partito per il Grande Prato: un
				# fiocchetto col campanellino, al collo, tinto col colore
				# del SUO vestitino (Fase 5 del Filo Rosso)
				n.position = Vector3(0, 0.58, -0.26)
				var c := Color(str((_ricordi[id] as Dictionary)["colore"]))
				var nastro := _pm(c, c.darkened(0.2), 6.0, 0.45)
				for lato: float in [-1.0, 1.0]:
					var ala := _ball(n, 0.055, nastro,
							Vector3(lato * 0.055, 0.01, 0), Vector3(1.5, 0.75, 0.5))
					ala.rotation.z = lato * 0.35
				_ball(n, 0.028, nastro, Vector3.ZERO, Vector3(0.9, 0.9, 0.7))
				var oro := _pm(Color("ffd76e"), Color("eec254"), 4.0, 0.35)
				_ball(n, 0.022, oro, Vector3(0, -0.055, 0))
	return n


# ---------------------------------------------------------------- vita

func _process(delta: float) -> void:
	# la lanterna-lucciola si accende col buio
	if _lantern_light and _daynight:
		var target := 1.1 if _daynight.is_night() else 0.0
		_lantern_light.light_energy = lerpf(_lantern_light.light_energy, target,
				1.0 - exp(-3.0 * delta))

	# la prima pioggia sblocca l'impermeabilino; indossarlo la fa felice
	var raining: bool = _weather != null and _weather.is_raining()
	if raining and not _was_raining:
		unlock("impermeabilino")
	_was_raining = raining
	if raining and _worn.has("impermeabilino") and _player:
		_rain_joy -= delta
		if _rain_joy <= 0.0:
			_rain_joy = randf_range(2.5, 4.5)
			var gtree := get_tree().get_first_node_in_group("grande_albero")
			if gtree:
				gtree.call("_sparkle", _player.global_position + Vector3(0, 0.3, 0), 8)


var _sel := 0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("guardaroba"):
		_open = not _open
		_panel.visible = _open
		if _player:
			_player.set_physics_process(not _open)
			if _open:
				_player.velocity = Vector3.ZERO
		if _open:
			_refresh_panel()
		if _sfx:
			if _open:
				_sfx.build_open()
			else:
				_sfx.build_close()
		get_viewport().set_input_as_handled()
		return
	if not _open:
		return
	# il baule è cresciuto oltre i tasti numerici: si sfoglia con ↑↓ e si
	# indossa con E (1-9 restano scorciatoie per i primi capi). L'ordine
	# comprende anche i ricordini di chi è partito (_ordine, Filo Rosso).
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		var passo := 1 if event.is_action_pressed("ui_down") else -1
		_sel = posmod(_sel + passo, _ordine().size())
		if _sfx:
			_sfx.ui_select()
		_refresh_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_toggle_wear(str(_ordine()[_sel]))
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.is_echo():
		var idx: int = (event as InputEventKey).keycode - KEY_1
		# 1-9 sulle prime righe (compresi i ricordini, se il baule è corto)
		var ordine := _ordine()
		if idx >= 0 and idx < mini(9, ordine.size()):
			_sel = idx
			_toggle_wear(str(ordine[idx]))
			get_viewport().set_input_as_handled()


func _refresh_panel() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var ordine := _ordine()
	_sel = clampi(_sel, 0, ordine.size() - 1)
	for i in ordine.size():
		var id := str(ordine[i])
		var capo := _capo_info(id)
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 13)
		var freccia := "▸ " if i == _sel else "   "
		if _unlocked.has(id):
			var stato := L10n.t("indossato ♥") if _worn.has(id) else L10n.t("nel baule")
			row.text = "%s%s  %s   —   %s" % [freccia, capo["icona"],
					L10n.t(str(capo["nome"])), stato]
			row.add_theme_color_override("font_color",
					Color("a83a5c") if _worn.has(id) else
					(UI_BROWN if i == _sel else Color(UI_BROWN, 0.75)))
		else:
			row.text = L10n.tf("%s?  un ricordo da vivere: %s",
					[freccia, L10n.t(str(capo["sblocco"]))])
			row.add_theme_color_override("font_color", Color(UI_BROWN, 0.4))
		_rows.add_child(row)


func _toast(text: String) -> void:
	var visitors := get_node_or_null("../../Visitors")
	if visitors:
		visitors.call("_show_toast", text)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_panel = PanelContainer.new()
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color("fdf6e3")
	ms.set_corner_radius_all(16)
	ms.border_color = Color(0.62, 0.46, 0.34, 0.55)
	ms.set_border_width_all(2)
	ms.shadow_color = Color(0.25, 0.15, 0.1, 0.3)
	ms.shadow_size = 12
	ms.content_margin_left = 26.0
	ms.content_margin_right = 26.0
	ms.content_margin_top = 16.0
	ms.content_margin_bottom = 16.0
	_panel.add_theme_stylebox_override("panel", ms)
	_panel.custom_minimum_size = Vector2(430, 0)
	_panel.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	center.add_child(_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)
	var title := Label.new()
	title.text = L10n.t("~ Il guardaroba di Mochi ~")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("8a5a3a"))
	vbox.add_child(title)
	var sub := Label.new()
	sub.text = L10n.t("ogni capo è un ricordo indossabile")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color("c25a7a"))
	vbox.add_child(sub)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	vbox.add_child(_rows)
	var hint := Label.new()
	hint.text = L10n.t("↑↓ — scegli  ·  E — indossa/togli  ·  G — chiudi")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(UI_BROWN, 0.55))
	vbox.add_child(hint)


# ---------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	return {"wardrobe": {"unlocked": _unlocked.keys(), "worn": _worn.keys(),
			"ricordi": _ricordi}}


func load_extra(data: Dictionary) -> void:
	var w: Dictionary = data.get("wardrobe", {})
	if w.is_empty():
		return
	# i ricordini PRIMA degli sblocchi: gli id "ricordo_*" esistono solo
	# se la loro scheda (nome, colore) è tornata dal salvataggio
	var ric: Variant = w.get("ricordi")
	if ric is Dictionary:
		_ricordi = ric
	# solo id che esistono nel catalogo (o tra i ricordini): un salvataggio
	# di un'altra versione non fa saltare il ripristino
	for id in w.get("unlocked", []):
		if CAPI.has(str(id)) or _ricordi.has(str(id)):
			_unlocked[str(id)] = true
	(func():
		for id in w.get("worn", []):
			if _unlocked.has(str(id)) and not _capo_info(str(id)).is_empty():
				_wear(str(id))).call_deferred()


# ---------------------------------------------------------------- debug CLI

func debug_unlock_all() -> void:
	for id in ORDER:
		_unlocked[id] = true


func debug_wear(id: String) -> void:
	_unlocked[id] = true
	_wear(id)


func debug_strip() -> void:
	for id in _worn.keys():
		_unwear(id)


func debug_open_panel() -> void:
	_open = true
	_refresh_panel()
	_panel.visible = true


func debug_close_panel() -> void:
	_open = false
	_panel.visible = false
	if _player:
		_player.set_physics_process(true)
