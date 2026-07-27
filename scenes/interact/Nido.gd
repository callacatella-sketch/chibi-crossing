extends Node

## Il NIDO della Casetta uccellini — il pet del villaggio.
##
## La Casetta uccellini era puro arredo: ora, in PRIMAVERA, sul suo tetto
## compare un nido con tre uova. Due giorni di covata, poi la schiusa:
## due passerotti volano via, ma uno resta — BRICIOLA. Da pulcino ti
## segue saltellando (imprinting: sei la prima cosa che ha visto), cresce
## coi giorni (pulcino → giovincello → adulto), SI SPAVENTA sotto la
## pioggia (trema e pigola: corri a portarla al riparo!) e da adulta è
## libera nel cielo — ma OGNI MATTINA torna a salutarti, e ogni tanto
## porta nel becco un semino raro (sì: quello del frutteto).
##
## CURA SENZA FALLIMENTO, nello spirito del gioco: se non la ripari,
## dopo un po' corre da sola al nido — nessuna morte, nessuna penalità.
## Solo che ripararla TU annoda la cura (e un momento, e il cuoricino).
##
## Il ciclo di vita è logica PURA (stadio_uccello/covata_pronta),
## testata senza SceneTree. Tutto procedurale, tutto persistito.

const GEO := preload("res://scenes/world/WorldGeo.gd")
const UI_BROWN := Color("6a4a3a")

const NOME := "Briciola"
## Giorni di covata prima della schiusa.
const GIORNI_COVA := 2
## Dopo quanto tempo sotto la pioggia Briciola si ripara da sola (il
## non-fallimento: la premura è un dono, non un obbligo).
const RIPARO_DA_SOLA := 60.0

# lo stato del nido: "attesa" (niente casetta o non è primavera),
# "covata" (nido + uova sul tetto), "nata" (Briciola vive)
var _stato := "attesa"
var _giorno_covata := -1
var _giorno_nascita := -1
var _curato := 0          # quante volte l'hai riparata / salutata: la cura

var _player: Node3D
var _build: Node3D
var _daynight: Node3D
var _weather: Node
var _visitors: Node
var _inventory: Node
var _sfx

# i nodi vivi
var _nido_node: Node3D           # nido + uova, sul tetto della casetta
var _uccello: Node3D             # Briciola
var _ali: Array[Node3D] = []
var _spaventata := false
var _riparata := false           # già al riparo durante QUESTA pioggia
var _paura_t := 0.0
var _saluto_fatto := -1          # il giorno dell'ultimo saluto mattutino
# il salto in corso: {da, a, t, dur} (vuoto = ferma)
var _hop := {}
var _becca_cd := 2.0
var _trema_t := 0.0


func _ready() -> void:
	add_to_group("nido")
	add_to_group("persistable")
	_sfx = get_node_or_null(^"/root/Sfx")
	(func():
		_player = get_node_or_null("../Player")
		_build = get_node_or_null("../BuildSystem")
		_daynight = get_node_or_null("../DayNight")
		_weather = get_node_or_null("../Weather")
		_visitors = get_node_or_null("../Visitors")
		_inventory = get_node_or_null("../Inventory")
		if _daynight and _daynight.has_signal("day_changed"):
			_daynight.day_changed.connect(_nuovo_giorno)
		_riallinea.call_deferred()).call_deferred()


func _day() -> int:
	return int(_daynight.get("day")) if _daynight else 1


func _primavera() -> bool:
	return _daynight != null and _daynight.has_method("get_season") \
			and int(_daynight.call("get_season")) == 0


# ------------------------------------------------------------ il cuore puro
# (testato senza SceneTree in tests/cases/test_nido.gd)

## Lo stadio di Briciola a `giorni` dalla schiusa.
static func stadio_uccello(giorni: int) -> String:
	if giorni >= 7:
		return "adulto"
	if giorni >= 4:
		return "giovincello"
	return "pulcino"


## La covata è pronta a schiudersi?
static func covata_pronta(giorni_di_cova: int) -> bool:
	return giorni_di_cova >= GIORNI_COVA


# ------------------------------------------------------------- il calendario

func _nuovo_giorno(_d: int) -> void:
	_riallinea(true)


## Porta il mondo allo stato giusto per OGGI (chiamata al load e a ogni
## mattina). `festeggia` accende toast e coreografie dei passaggi.
func _riallinea(festeggia := false) -> void:
	match _stato:
		"attesa":
			# in primavera, con una casetta piazzata, la vita comincia
			if _primavera() and _casetta() != null:
				_stato = "covata"
				_giorno_covata = _day()
				_monta_nido()
				if festeggia:
					_toast("🪺 Nella Casetta uccellini è comparso un nido, con tre uova!")
					if _sfx:
						_sfx.play("chirp1", -16.0, 1.3)
				_salva()
		"covata":
			if _casetta() == null:
				# la casetta non c'è più: il nido aspetta tempi migliori
				_smonta_nido()
				_stato = "attesa"
				_salva()
				return
			if _nido_node == null:
				_monta_nido()
			if covata_pronta(_day() - _giorno_covata):
				_schiusa(festeggia)
		"nata":
			if _uccello == null or not is_instance_valid(_uccello):
				_monta_uccello()
			else:
				_aggiorna_stadio(festeggia)
			# l'adulta torna OGNI mattina a salutare
			if stadio_uccello(_day() - _giorno_nascita) == "adulto" \
					and _saluto_fatto != _day():
				_saluto_mattutino()


func _casetta() -> Node3D:
	if _build == null:
		return null
	var lista: Array = _build.call("get_placed_by_name", "Casetta uccellini")
	return lista[0] if not lista.is_empty() else null


# --------------------------------------------------------------- la covata

func _monta_nido() -> void:
	_smonta_nido()
	var casetta := _casetta()
	if casetta == null:
		return
	_nido_node = Node3D.new()
	_nido_node.position = casetta.global_position + Vector3(0, 1.47, 0)
	add_child(_nido_node)
	# il nido: la ciambella di rametti intrecciati, con le pagliuzze
	var rametto := GEO.paint_mat(Color("8a6a48"), Color("6e5138"), 6.0, 0.55)
	var paglia := GEO.paint_mat(Color("d9c08a"), Color("c2a86e"), 7.0, 0.5)
	var anello := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.055
	tm.outer_radius = 0.115
	anello.mesh = tm
	anello.material_override = rametto
	anello.scale = Vector3(1, 0.62, 1)
	_nido_node.add_child(anello)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 8:
		var stecco := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.006
		cm.bottom_radius = 0.008
		cm.height = rng.randf_range(0.1, 0.16)
		stecco.mesh = cm
		stecco.material_override = paglia if i % 2 == 0 else rametto
		var a := rng.randf() * TAU
		stecco.position = Vector3(cos(a) * 0.1, 0.02, sin(a) * 0.1)
		stecco.rotation = Vector3(rng.randf_range(1.2, 1.8), a, 0)
		_nido_node.add_child(stecco)
	# le tre uova, crema puntinato, strette nel nido
	var guscio := GEO.paint_mat(Color("f6ecd8"), Color("d9c9a8"), 12.0, 0.6)
	for i in 3:
		var a := TAU * float(i) / 3.0
		var uovo := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.038
		sm.height = 0.076
		uovo.mesh = sm
		uovo.material_override = guscio
		uovo.scale = Vector3(1, 1.22, 1)
		uovo.position = Vector3(cos(a) * 0.042, 0.045, sin(a) * 0.042)
		uovo.rotation = Vector3(0.15 * cos(a), 0, 0.15 * sin(a))
		_nido_node.add_child(uovo)


func _smonta_nido() -> void:
	if _nido_node and is_instance_valid(_nido_node):
		_nido_node.queue_free()
	_nido_node = null


## La SCHIUSA: due passerotti volano via in archi diversi, il terzo resta
## nel nido — è Briciola, e la prima cosa che vede sei tu.
func _schiusa(festeggia: bool) -> void:
	_stato = "nata"
	_giorno_nascita = _day()
	var base: Vector3 = _nido_node.global_position if _nido_node else Vector3.ZERO
	_smonta_nido()
	if festeggia:
		_sparkle(base, Color(1.0, 0.95, 0.7))
		# i due fratellini prendono il volo, ognuno dal suo verso
		for lato: float in [-1.0, 1.0]:
			var fratello := _mini_uccello(Color("c8a26e"))
			fratello.position = base
			add_child(fratello)
			var meta := base + Vector3(lato * 6.0, 5.0, -3.0)
			var tw := create_tween().set_parallel(true)
			tw.tween_property(fratello, "position", meta, 2.6) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_property(fratello, "scale", Vector3.ONE * 0.05, 2.6) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.chain().tween_callback(fratello.queue_free)
		_toast("🐣 Cip! Due passerotti prendono il volo… ma uno resta.\nÈ %s — e la prima cosa che ha visto sei TU." % NOME)
		if _sfx:
			_sfx.play("chirp2", -13.0, 1.25)
			get_tree().create_timer(0.4).timeout.connect(func():
				if _sfx: _sfx.play("chirp1", -14.0, 1.4))
	_monta_uccello()
	_salva()


# ---------------------------------------------------------------- Briciola

func _aggiorna_stadio(festeggia: bool) -> void:
	var st := stadio_uccello(_day() - _giorno_nascita)
	if _uccello and str(_uccello.get_meta("stadio", "")) == st:
		return
	var pos: Vector3 = _uccello.position if _uccello else Vector3.ZERO
	_monta_uccello()
	if pos != Vector3.ZERO:
		_uccello.position = pos
	if festeggia:
		_sparkle(_uccello.position + Vector3(0, 0.3, 0), Color(1.0, 0.9, 0.6))
		match st:
			"giovincello":
				_toast("%s sta crescendo: spuntano le penne della coda!" % NOME)
			"adulto":
				_toast("🕊 %s è adulta: il cielo è suo. Ma ogni mattina, vedrai, torna." % NOME)


## Costruisce Briciola per lo stadio di oggi: la palletta di piume gialle
## che diventa passerotto — corpo, testona, becco, occhi con la LUCE,
## alette che sbattono, ciuffetto, coda da grande. Con l'ombra a terra.
func _monta_uccello() -> void:
	if _uccello and is_instance_valid(_uccello):
		_uccello.queue_free()
	_ali.clear()
	var st := stadio_uccello(_day() - _giorno_nascita)
	var casetta := _casetta()
	_uccello = Node3D.new()
	_uccello.set_meta("stadio", st)
	var base: Vector3 = casetta.global_position + Vector3(0.5, 0, 0.4) \
			if casetta else (_player.global_position + Vector3(1.0, 0, 0.5)
			if _player else Vector3.ZERO)
	_uccello.position = base * Vector3(1, 0, 1)
	add_child(_uccello)

	var taglia := 1.0
	var piuma: ShaderMaterial
	var pancia: ShaderMaterial
	match st:
		"pulcino":
			taglia = 0.75
			piuma = GEO.paint_mat(Color("ffd98a"), Color("edbe62"), 6.0, 0.55)
			pancia = GEO.paint_mat(Color("fff2cc"), Color("f0dCa8"), 6.0, 0.5)
		"giovincello":
			taglia = 0.9
			piuma = GEO.paint_mat(Color("e8c07a"), Color("cfa058"), 6.0, 0.55)
			pancia = GEO.paint_mat(Color("fdf0d4"), Color("ecd8b0"), 6.0, 0.5)
		_:
			piuma = GEO.paint_mat(Color("b98d62"), Color("9a734e"), 6.0, 0.55)
			pancia = GEO.paint_mat(Color("f2e4c8"), Color("ddc9a4"), 6.0, 0.5)
	var becco_mat := GEO.paint_mat(Color("f0a24a"), Color("d68838"), 4.0, 0.4)
	var scuro := StandardMaterial3D.new()
	scuro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	scuro.albedo_color = Color("2c2620")
	var luce := StandardMaterial3D.new()
	luce.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	luce.albedo_color = Color.WHITE

	var corpo := Node3D.new()
	corpo.name = "Corpo"
	corpo.scale = Vector3.ONE * taglia
	_uccello.add_child(corpo)
	# corpo a goccia e testona (la faccia guarda -Z)
	_palla(corpo, 0.095, piuma, Vector3(0, 0.1, 0.01), Vector3(1, 0.95, 1.15))
	_palla(corpo, 0.062, pancia, Vector3(0, 0.085, -0.045), Vector3(1, 0.85, 0.6))
	_palla(corpo, 0.075, piuma, Vector3(0, 0.205, -0.03))
	# il becco: due coni piccoli, sopra e sotto
	var becco := _cono(corpo, 0.02, 0.05, becco_mat, Vector3(0, 0.195, -0.105))
	becco.rotation.x = -PI * 0.5
	# occhi tondi con la LUCE dentro: vivi anche da lontano
	for lato: float in [-1.0, 1.0]:
		_palla(corpo, 0.016, scuro, Vector3(lato * 0.038, 0.225, -0.085),
				Vector3(1, 1.2, 0.6))
		_palla(corpo, 0.006, luce, Vector3(lato * 0.033, 0.232, -0.094),
				Vector3(1, 1, 0.6))
	# le alette che sbattono
	for lato: float in [-1.0, 1.0]:
		var ala := Node3D.new()
		ala.position = Vector3(lato * 0.085, 0.13, 0.01)
		corpo.add_child(ala)
		_palla(ala, 0.055, piuma, Vector3(lato * 0.02, 0, 0), Vector3(0.5, 0.8, 1.15))
		_ali.append(ala)
	# il ciuffetto in testa (da pulcino: tre piumette sbarazzine)
	if st == "pulcino":
		for i in 3:
			var piumetta := _cono(corpo, 0.008, 0.045, piuma,
					Vector3(-0.015 + 0.015 * i, 0.285, -0.02))
			piumetta.rotation.z = -0.35 + 0.35 * i
	# la coda, da giovincello in su
	if st != "pulcino":
		var coda := _palla(corpo, 0.05, piuma, Vector3(0, 0.12, 0.115),
				Vector3(0.55, 0.4, 1.5))
		coda.rotation.x = -0.5
	# zampette
	for lato: float in [-1.0, 1.0]:
		_cono(corpo, 0.008, 0.035, becco_mat, Vector3(lato * 0.03, 0.012, 0))
	# l'ombra morbida che la incolla al prato
	var ombra := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.22, 0.22)
	var om := StandardMaterial3D.new()
	om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	om.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	om.albedo_texture = GEO.soft_circle(Color(0.1, 0.12, 0.08, 0.32), 0.8)
	qm.material = om
	ombra.mesh = qm
	ombra.rotation.x = -PI * 0.5
	ombra.position.y = 0.015
	ombra.name = "Ombra"
	_uccello.add_child(ombra)


func _mini_uccello(col: Color) -> Node3D:
	var n := Node3D.new()
	var mat := GEO.paint_mat(col, col.darkened(0.2), 6.0, 0.5)
	_palla(n, 0.06, mat, Vector3(0, 0.05, 0), Vector3(1, 0.9, 1.2))
	_palla(n, 0.045, mat, Vector3(0, 0.12, -0.03))
	for lato: float in [-1.0, 1.0]:
		_palla(n, 0.04, mat, Vector3(lato * 0.06, 0.07, 0), Vector3(0.4, 0.7, 1.1))
	return n


func _palla(parent: Node3D, r: float, mat: Material, pos: Vector3,
		scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cono(parent: Node3D, r: float, h: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ------------------------------------------------------------ la vita mossa

func _process(delta: float) -> void:
	if _stato != "nata" or _uccello == null or not is_instance_valid(_uccello):
		return
	var st := str(_uccello.get_meta("stadio", "pulcino"))
	var piove: bool = _weather != null and bool(_weather.call("is_raining"))

	# la PAURA della pioggia (solo da piccola: l'adulta se la ride)
	if piove and st != "adulto" and not _riparata:
		if not _spaventata:
			_spaventata = true
			_paura_t = 0.0
			_toast("🌧 %s trema sotto la pioggia: portala al riparo!" % NOME)
			if _sfx:
				_sfx.play("chirp3", -14.0, 0.7)
		_paura_t += delta
		# il riparo: un tetto sopra la testa, o la sua casetta
		var cell := Vector2i(roundi(_uccello.position.x), roundi(_uccello.position.z))
		var casetta := _casetta()
		var al_riparo: bool = (_build != null and bool(_build.call("has_cover", cell))) \
				or (casetta != null and _uccello.position.distance_to(
				casetta.global_position * Vector3(1, 0, 1)) < 0.9)
		if al_riparo:
			_riparata = true
			_spaventata = false
			_curato += 1
			_toast("💛 %s si scrolla le piume, al riparo. Ti si strofina contro: grazie." % NOME)
			_sparkle(_uccello.position + Vector3(0, 0.3, 0), Color(1.0, 0.85, 0.5))
			if _sfx:
				_sfx.play("chirp1", -13.0, 1.35)
			get_tree().call_group("regista", "note", "socievole")
			_salva()
		elif _paura_t > RIPARO_DA_SOLA:
			# il non-fallimento: se nessuno arriva, corre da sola al nido
			_spaventata = false
			_riparata = true
			var casetta2 := _casetta()
			if casetta2:
				_hop = {"da": _uccello.position,
						"a": casetta2.global_position * Vector3(1, 0, 1),
						"t": 0.0, "dur": 0.8}
			_toast("%s è corsa a ripararsi da sola. (Un ombrello, la prossima volta?)" % NOME)
	elif not piove:
		_spaventata = false
		_riparata = false

	# il TREMITO della paura: piccoli brividi, ali strette
	if _spaventata:
		_trema_t += delta
		var corpo := _uccello.get_node_or_null("Corpo") as Node3D
		if corpo:
			corpo.position.x = sin(_trema_t * 34.0) * 0.008
			corpo.rotation.z = sin(_trema_t * 27.0) * 0.05
		# ma se Mochi si avvicina, la paura si fa coraggio: la segue
		if _player and _uccello.position.distance_to(_player.global_position) < 1.4:
			_segui(delta, 3.2)
		_sbatti_ali(delta, 14.0)
		return

	# la notte, da piccola, si dorme al nido (sparita nel buio della casetta)
	if _daynight and bool(_daynight.call("is_night")) and st != "adulto":
		var casetta3 := _casetta()
		if casetta3 and _uccello.position.distance_to(
				casetta3.global_position * Vector3(1, 0, 1)) > 0.6:
			_segui_verso(casetta3.global_position * Vector3(1, 0, 1), delta, 1.6)
		return

	# di giorno: l'IMPRINTING — saltella dietro a Mochi; se Mochi è ferma
	# o lontana, becchetta l'erba vicino a casa
	_segui(delta, 1.0)


# il saltello verso Mochi (l'imprinting) o il becchettare
func _segui(delta: float, fretta: float) -> void:
	if _player == null:
		return
	var pp: Vector3 = _player.global_position * Vector3(1, 0, 1)
	var d: float = _uccello.position.distance_to(pp)
	if d > 8.0:
		# troppo lontana: torna a becchettare vicino alla casetta
		var casetta := _casetta()
		if casetta:
			_segui_verso(casetta.global_position * Vector3(1, 0, 1), delta, 1.0)
		return
	if d > 1.1:
		_segui_verso(pp + (pp - _uccello.position).normalized() * -0.75, delta, fretta)
	else:
		_avanza_hop(delta)
		# vicina e tranquilla: ogni tanto becchetta, la testolina che tuffa
		_becca_cd -= delta
		if _becca_cd <= 0.0 and _hop.is_empty():
			_becca_cd = randf_range(1.6, 3.4)
			var corpo := _uccello.get_node_or_null("Corpo") as Node3D
			if corpo:
				var tw := create_tween()
				tw.tween_property(corpo, "rotation:x", 0.55, 0.16) \
						.set_trans(Tween.TRANS_SINE)
				tw.tween_property(corpo, "rotation:x", 0.0, 0.22) \
						.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _segui_verso(meta: Vector3, delta: float, fretta: float) -> void:
	_avanza_hop(delta)
	if not _hop.is_empty():
		return
	var d: float = _uccello.position.distance_to(meta)
	if d < 0.25:
		return
	var passo: Vector3 = _uccello.position + (meta - _uccello.position).limit_length(
			minf(0.55, d))
	_hop = {"da": _uccello.position, "a": passo, "t": 0.0,
			"dur": 0.32 / maxf(fretta, 0.5)}
	# si volta dove salta
	var dir: Vector3 = passo - _uccello.position
	if dir.length() > 0.01:
		_uccello.rotation.y = atan2(-dir.x, -dir.z)


## Il SALTELLO: parabola con squash all'atterraggio, alette che sbattono.
func _avanza_hop(delta: float) -> void:
	if _hop.is_empty():
		return
	_hop["t"] = float(_hop["t"]) + delta
	var k := clampf(float(_hop["t"]) / float(_hop["dur"]), 0.0, 1.0)
	var da: Vector3 = _hop["da"]
	var a: Vector3 = _hop["a"]
	var pos := da.lerp(a, k)
	pos.y = 4.0 * 0.14 * k * (1.0 - k)   # l'arco del saltello
	_uccello.position = pos
	_sbatti_ali(delta, 22.0)
	var corpo := _uccello.get_node_or_null("Corpo") as Node3D
	if k >= 1.0:
		_hop = {}
		# lo squash dell'atterraggio: la palletta si schiaccia e si rialza
		if corpo:
			corpo.scale.y = 0.82
			var tw := create_tween()
			tw.tween_property(corpo, "scale:y", 1.0, 0.16) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _sbatti_ali(delta: float, rate: float) -> void:
	_trema_t += delta
	for i in _ali.size():
		var lato := -1.0 if i == 0 else 1.0
		_ali[i].rotation.z = lato * (0.4 + sin(_trema_t * rate) * 0.5)


# ---------------------------------------------------- il saluto del mattino

## L'adulta torna OGNI mattina: plana in un arco, atterra accanto a te,
## due saltelli, il cinguettio del buongiorno — e ogni tanto, nel becco,
## un semino raro (il cerchio si chiude: è quello del frutteto).
func _saluto_mattutino(con_regalo := false) -> void:
	_saluto_fatto = _day()
	if _uccello == null or not is_instance_valid(_uccello) or _player == null:
		return
	var meta: Vector3 = _player.global_position * Vector3(1, 0, 1) \
			+ Vector3(0.9, 0, 0.7)
	var da: Vector3 = meta + Vector3(-5.0, 4.5, -3.0)
	_uccello.position = da
	_hop = {}
	var tw := create_tween()
	tw.tween_method(func(k: float):
		if is_instance_valid(_uccello):
			var pos := da.lerp(meta, k)
			pos.y = lerpf(da.y, 0.0, k * k)   # la planata: scende in curva
			_uccello.position = pos
			_sbatti_ali(0.016, 26.0), 0.0, 1.0, 1.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if not is_instance_valid(_uccello):
			return
		_sparkle(_uccello.position + Vector3(0, 0.3, 0), Color(1.0, 0.92, 0.6))
		if _sfx:
			_sfx.play("chirp2", -12.0, 1.2)
			get_tree().create_timer(0.35).timeout.connect(func():
				if _sfx: _sfx.play("chirp1", -13.0, 1.45))
		var regalo := con_regalo or randf() < 0.25
		if regalo and _inventory:
			_inventory.call("add_treasure", "semino", 1)
			_toast("🕊 %s è tornata a salutarti — e nel becco ha un semino raro!" % NOME)
		else:
			_toast("🕊 %s è tornata a salutarti: due saltelli e un cinguettio, come ogni mattina." % NOME)
		_curato += 1
		_salva())


# ---------------------------------------------------------------- servizi

func _sparkle(pos: Vector3, color: Color) -> void:
	var mail := get_node_or_null("../Mail")
	if mail and mail.has_method("_sparkle"):
		mail.call("_sparkle", pos, color)


func _toast(text: String) -> void:
	if _visitors:
		_visitors.call("_show_toast", text)


func _salva() -> void:
	if _build:
		_build.call("request_save")


# ---------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	return {"nido": [_stato, _giorno_covata, _giorno_nascita, _curato]}


func load_extra(data: Dictionary) -> void:
	var r: Variant = data.get("nido")
	if r is Array and (r as Array).size() == 4:
		_stato = str(r[0])
		_giorno_covata = int(r[1])
		_giorno_nascita = int(r[2])
		_curato = int(r[3])
	_riallinea.call_deferred()


# ---------------------------------------------------------------- debug CLI

func debug_stato() -> String:
	var giorni := _day() - _giorno_nascita if _giorno_nascita >= 0 else -1
	return "stato=%s, cova=%d, eta=%d (%s), cura=%d, spaventata=%s" % [_stato,
			_giorno_covata, giorni,
			stadio_uccello(giorni) if giorni >= 0 else "-", _curato, _spaventata]


func debug_saluto(con_regalo := true) -> void:
	_saluto_fatto = -1
	_saluto_mattutino(con_regalo)


func debug_posizione() -> Vector3:
	return _uccello.position if _uccello and is_instance_valid(_uccello) else Vector3.ZERO
