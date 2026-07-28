class_name RichiesteFoto
extends Node
## LE RICHIESTE FOTOGRAFICHE — la Modalità Foto diventa un gioco con uno scopo.
##
## Ogni tanto un residente SOGNA una foto («io e te accanto al falò»,
## «l'arcobaleno dal ponte»): sopra la sua testa fiorisce una nuvoletta con
## una macchinetta fotografica, e da quel momento la Modalità Foto (P) ha
## una missione. Dentro la modalità, un HUD dedicato dice il sogno e giudica
## l'inquadratura DAL VIVO — chi manca nel quadro, se serve la notte o un
## arcobaleno — finché non si accende «✨ inquadratura perfetta»: allora lo
## scatto esaudisce il sogno. La foto — QUELLA vera, il PNG appena scattato —
## viene incorniciata in legno e appesa sopra il letto del residente, con lo
## spago e il chiodino, storta quel poco che basta a essere vera.
##
## Riusa ciò che c'è: PhotoMode (lo scatto arriva via gruppo
## "richieste_foto"), il sistema dei desideri (stessa festa: celebrate,
## grazie in Chibiese, cuoricino, lettera), l'amicizia (_bump_friend) e il
## Filo Rosso (momento "desiderio"). I sogni nascono solo con amicizia ≥ 1:
## non si chiede un ritratto a uno sconosciuto.
##
## Il sognatore fa la sua parte: ogni tanto passeggia fino al luogo del
## sogno e aspetta lì — il mondo collabora, non frustra.
##
## Persistenza per conto proprio (user://foto_ricordi.json + i PNG in
## user://foto_ricordi/): le cornici rinascono al riavvio, e restano anche
## se un giorno il residente parte — sono memoria, il tema del gioco.

const COZY := preload("res://scenes/world/CozyWorld.gd")
const MATH := preload("res://scenes/world/WorldMath.gd")
const ALBERO := preload("res://scenes/world/GrandTree.gd")
const GEO := preload("res://scenes/world/WorldGeo.gd")
const TOON := preload("res://shaders/toon.gdshader")

const FILE_RICORDI := "user://foto_ricordi.json"
const CARTELLA := "user://foto_ricordi"
const PROB_SOGNO_GIORNO := 0.45   # se nessun sogno è in corso
const AMICIZIA_MINIMA := 1
const MAX_CORNICI_PER_CASA := 2
const DIST_FOTO_MAX := 11.0       # da più lontano il soggetto si perde
const DIST_FOTO_MIN := 1.1        # da più vicino è dentro il naso
const LARGH_FOTO := 640           # la copia per la cornice (non il 4K intero)

## I sogni possibili. `peso` pesa la pesca; `con_te` vuole anche Mochi nel
## quadro; `notte`/`arcobaleno` sono le condizioni del cielo. Le POSIZIONI
## non vivono qui: le risolve _pos_luogo dalle fonti uniche (CozyWorld,
## GrandTree, WorldMath) — copiarle a mano qui divergerebbe in silenzio.
const RICHIESTE := [
	{"id": "falo", "peso": 3, "raggio": 5.0, "con_te": true,
			"notte": false, "arcobaleno": false,
			"testo": "io e te accanto al falò"},
	{"id": "stagno", "peso": 3, "raggio": 5.0, "con_te": true,
			"notte": false, "arcobaleno": false,
			"testo": "io e te in riva allo stagno"},
	{"id": "grande_albero", "peso": 3, "raggio": 5.5, "con_te": true,
			"notte": false, "arcobaleno": false,
			"testo": "io e te sotto il Grande Albero"},
	{"id": "stelle", "peso": 2, "raggio": 6.0, "con_te": true,
			"notte": true, "arcobaleno": false,
			"testo": "io e te sotto le stelle, davanti a casa mia"},
	{"id": "arcobaleno", "peso": 1, "raggio": 4.5, "con_te": false,
			"notte": false, "arcobaleno": true,
			"testo": "l'arcobaleno, visto dal ponte del fiume"},
]

var _file := FILE_RICORDI     # i test lo dirottano su un file usa-e-getta

# il sogno in corso: {nome, label, id, testo, cx, cz} (vuoto = nessuno)
var _richiesta := {}
# le foto appese: [{nome, label, png, cx, cz}] — i nodi vivi in _cornici
var _appese: Array = []
var _cornici := {}            # png -> Node3D della cornice appesa
var _da_appendere: Array = [] # righe caricate in attesa che il letto esista

var _icona: Node3D            # la nuvoletta-sogno sopra il sognatore
var _icona_t := 0.0

var _hud: CanvasLayer
var _hud_sogno: Label
var _hud_stato: Label
var _hud_sospeso := 0.0   # lo scatto in corso: l'HUD non deve finirci dentro

var _t_poll := 0.0
var _t_nudge := 18.0
var _t_case := 0.0


func _ready() -> void:
	add_to_group("richieste_foto")
	_fai_hud()
	(func() -> void:
		var dn := get_node_or_null("../../DayNight")
		if dn and dn.has_signal("day_changed"):
			dn.day_changed.connect(_nuovo_giorno)
		_carica()
	).call_deferred()


# ------------------------------------------------------------ il ciclo vivo

func _process(delta: float) -> void:
	# la nuvoletta respira: galleggia e ruota piano sopra il sognatore
	if _icona and is_instance_valid(_icona):
		_icona_t += delta
		_icona.position.y = 1.58 + sin(_icona_t * 2.1) * 0.05
		_icona.rotation.y += delta * 0.55

	_aggiorna_hud()

	_t_poll += delta
	if _t_poll >= 2.0:
		_t_poll = 0.0
		_riappendi_in_attesa()
		# `_trova_residente` è tipizzata `-> Dictionary`: quando il
		# sognatore non c'è più torna `{}`, MAI `null`. Il confronto con
		# null era quindi sempre falso e il sogno non si chiudeva mai:
		# restava appeso a un residente partito o disertato, e la
		# nuvoletta con la macchinetta non spariva più.
		if not _richiesta.is_empty() and _trova_residente().is_empty():
			# il sognatore non c'è più: il sogno se ne va con lui
			_chiudi_richiesta()

	_t_case += delta
	if _t_case >= 10.0:
		_t_case = 0.0
		_cornici_orfane()

	# il sognatore collabora: ogni tanto passeggia fino al luogo del sogno
	_t_nudge -= delta
	if _t_nudge <= 0.0:
		_t_nudge = randf_range(20.0, 32.0)
		_nudge_sognatore()


func _nuovo_giorno(_day: int) -> void:
	if _richiesta.is_empty() and randf() < PROB_SOGNO_GIORNO:
		_sogna()


# ------------------------------------------------------------ nasce un sogno

func _sogna() -> void:
	var visitors := get_node_or_null("../../Visitors")
	if visitors == null:
		return
	var idonei: Array = []
	for r in (visitors.get("_residents") as Array):
		var node := r.get("node") as Node3D
		if node and is_instance_valid(node) and not bool(node.call("is_hidden")) \
				and int(r.get("friend", 0)) >= AMICIZIA_MINIMA:
			idonei.append(r)
	if idonei.is_empty():
		return
	var r: Dictionary = idonei[randi() % idonei.size()]
	var scelta := pesca_richiesta(randf())
	_richiesta = {
		"nome": str((r.get("dna", {}) as Dictionary).get("name", "")),
		"label": str(r.get("label", L10n.t("un vicino"))),
		"id": str(scelta["id"]),
		"testo": str(scelta["testo"]),
		"cx": float((r["cell"] as Vector2i).x),
		"cz": float((r["cell"] as Vector2i).y),
	}
	var node := r.get("node") as Node3D
	_attacca_icona(node)
	if node.has_method("speak"):
		node.call("speak", ["amico"], "domanda")
	if node.has_method("chat_bubble"):
		node.call("chat_bubble", "?")
	_toast(L10n.tf("%s sogna una foto: «%s»  (P per la Modalità Foto)",
			[_richiesta["label"], L10n.t(str(_richiesta["testo"]))]))
	_salva()


## La pesca pesata fra le RICHIESTE, pura: entra un tiro 0..1, esce la voce.
static func pesca_richiesta(tiro: float) -> Dictionary:
	var totale := 0.0
	for e in RICHIESTE:
		totale += float(e["peso"])
	var soglia := tiro * totale
	var corsa := 0.0
	for e in RICHIESTE:
		corsa += float(e["peso"])
		if soglia <= corsa:
			return e
	return RICHIESTE[0]


## Dove vive ogni sogno: risolto dalle FONTI UNICHE del mondo.
func _pos_luogo(id: String) -> Vector3:
	match id:
		"falo":
			return COZY.CLEARING_CENTER
		"stagno":
			return COZY.POND_CENTER
		"grande_albero":
			return ALBERO.POS
		"stelle":
			return Vector3(float(_richiesta.get("cx", 0.0)), 0.0,
					float(_richiesta.get("cz", 0.0)))
		"arcobaleno":
			return Vector3(MATH.river_x(COZY.BRIDGE_Z), 0.0, COZY.BRIDGE_Z)
	return Vector3.ZERO


func _voce_richiesta(id: String) -> Dictionary:
	for e in RICHIESTE:
		if str(e["id"]) == id:
			return e
	return RICHIESTE[0]


# ------------------------------------------------------- l'inquadratura viva

## Il giudice dell'inquadratura, PURO e statico: ritorna "" se lo scatto
## esaudirebbe il sogno, altrimenti IL MOTIVO — che l'HUD mostra come guida
## («anche Mochi va nel quadro», «aspetta la notte»…). Un solo giudice per
## HUD e scatto: mai due verdetti diversi.
static func motivo_inquadratura(cam: Camera3D, pos_sognatore: Vector3,
		pos_mochi: Vector3, luogo: Vector3, raggio: float, con_te: bool,
		serve_notte: bool, e_notte: bool,
		serve_arco: bool, c_e_arco: bool) -> String:
	if serve_notte and not e_notte:
		return "aspetta la sera: il sogno vuole le stelle"
	if serve_arco and not c_e_arco:
		return "serve un arcobaleno nel cielo (dopo la pioggia)"
	if pos_sognatore.distance_to(luogo) > raggio:
		return "il sognatore non è ancora sul posto"
	var d := cam.global_position.distance_to(pos_sognatore)
	if d > DIST_FOTO_MAX:
		return "troppo lontano: avvicìnati col volo"
	if d < DIST_FOTO_MIN:
		return "troppo vicino: un passo indietro"
	if not cam.is_position_in_frustum(pos_sognatore + Vector3(0, 0.55, 0)):
		return "il sognatore è fuori dall'inquadratura"
	if not cam.is_position_in_frustum(luogo + Vector3(0, 0.5, 0)):
		return "inquadra anche il posto del sogno"
	if con_te:
		if pos_mochi.distance_to(luogo) > raggio + 2.0:
			return "mettiti in posa anche tu, lì vicino"
		if not cam.is_position_in_frustum(pos_mochi + Vector3(0, 0.6, 0)):
			return "anche Mochi va nel quadro"
	return ""


## Il verdetto sul MONDO VERO, adesso (o il motivo per cui ancora no).
func _motivo_live() -> String:
	if _richiesta.is_empty():
		return "nessun sogno in corso"
	var r := _trova_residente()
	if r.is_empty():
		return "il sognatore non c'è"
	var node := r["node"] as Node3D
	var player := get_node_or_null("../../Player") as Node3D
	var cam := get_viewport().get_camera_3d()
	if cam == null or player == null:
		return "niente camera"
	var voce := _voce_richiesta(str(_richiesta["id"]))
	var dn := get_node_or_null("../../DayNight")
	var e_notte: bool = dn != null and bool(dn.call("is_night"))
	var w := get_node_or_null("../../Weather")
	var arco: bool = w != null and str(w.get("_state")) == "rainbow"
	return motivo_inquadratura(cam, node.global_position,
			player.global_position, _pos_luogo(str(_richiesta["id"])),
			float(voce["raggio"]), bool(voce["con_te"]),
			bool(voce["notte"]), e_notte, bool(voce["arcobaleno"]), arco)


func _trova_residente() -> Dictionary:
	var visitors := get_node_or_null("../../Visitors")
	if visitors == null:
		return {}
	for r in (visitors.get("_residents") as Array):
		if str((r.get("dna", {}) as Dictionary).get("name", "")) == str(_richiesta.get("nome", "")):
			var node := r.get("node") as Node3D
			if node and is_instance_valid(node):
				return r
	return {}


## Il sognatore fa la sua parte: se il cielo è quello giusto e lui è
## lontano dal luogo del sogno, ci va a passeggio e aspetta lì.
func _nudge_sognatore() -> void:
	if _richiesta.is_empty():
		return
	var r := _trova_residente()
	if r.is_empty():
		return
	var voce := _voce_richiesta(str(_richiesta["id"]))
	var dn := get_node_or_null("../../DayNight")
	if bool(voce["notte"]) and (dn == null or not bool(dn.call("is_night"))):
		return
	var w := get_node_or_null("../../Weather")
	if bool(voce["arcobaleno"]) and (w == null or str(w.get("_state")) != "rainbow"):
		return
	var node := r["node"] as Node3D
	var luogo := _pos_luogo(str(_richiesta["id"]))
	if node.global_position.distance_to(luogo) <= float(voce["raggio"]) * 0.8:
		return
	var posto := luogo + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
	if node.has_method("do_routine"):
		# "sniff" e non "inspect": è l'unico verbo di do_routine che
		# cammina fino al punto e vi resta (inspect non esiste lì)
		node.call("do_routine", "sniff", posto, luogo)


# ------------------------------------------------------------------ lo scatto

## Chiamato da PhotoMode (gruppo "richieste_foto") con l'immagine appena
## scattata: se il sogno è a fuoco, si avvera.
func scatto(img: Image) -> void:
	if _richiesta.is_empty() or img == null or img.is_empty():
		return
	if _motivo_live() != "":
		return
	var r := _trova_residente()
	if r.is_empty():
		return

	# la copia per la cornice: la foto VERA, ridotta quanto basta
	var foto := img.duplicate() as Image
	if foto.get_width() > LARGH_FOTO:
		foto.resize(LARGH_FOTO,
				int(float(foto.get_height()) * LARGH_FOTO / float(foto.get_width())),
				Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(CARTELLA)
	var slug := str(_richiesta["nome"]).to_lower().validate_filename()
	var png := "%s/%s_%d.png" % [CARTELLA, slug, Time.get_ticks_msec()]
	foto.save_png(png)

	_appese.append({"nome": _richiesta["nome"], "label": _richiesta["label"],
			"png": png, "cx": _richiesta["cx"], "cz": _richiesta["cz"]})
	var riga: Dictionary = _appese.back()
	_pota_cornici(str(_richiesta["nome"]))
	if not _appendi_cornice(riga):
		_da_appendere.append(riga)

	# la festa: la stessa dei desideri esauditi — celebrate, grazie in
	# Chibiese, cuoricino, amicizia, filo rosso, lettera l'indomani
	# (has_method: mai fidarsi che un nodo sia un Visitor completo)
	var node := r["node"] as Node3D
	if node.has_method("celebrate"):
		node.call("celebrate")
	if node.has_method("speak"):
		node.call("speak", ["grazie", "amico"], "felice")
	if node.has_method("_spawn_heart"):
		node.call("_spawn_heart")
	var visitors := get_node_or_null("../../Visitors")
	if visitors:
		visitors.call("_bump_friend", r, 3)
	get_tree().call_group("legami", "momento", str(_richiesta["nome"]),
			"desiderio", "foto")
	var mail := get_node_or_null("../../Mail")
	if mail:
		mail.call("queue_letter", {
			"from": str(_richiesta["nome"]),
			"text": L10n.tf("La foto che sognavo — %s!\nL'ho appesa sopra il letto: la guardo ogni sera.\nGrazie, con tutto il cuore.", [L10n.t(str(_richiesta["testo"]))]),
			"gift": true,
		})
	_toast(L10n.tf("Il sogno di %s si è avverato: la foto è appesa in casa sua!",
			[str(_richiesta["label"])]))
	var sfx = get_node_or_null(^"/root/Sfx")
	if sfx:
		sfx.place_ok()

	_chiudi_richiesta()


func _chiudi_richiesta() -> void:
	if _icona and is_instance_valid(_icona):
		_icona.queue_free()
	_icona = null
	_richiesta = {}
	_salva()


# --------------------------------------------------------- la cornice appesa

## Appende la foto sopra il letto del residente. Falso se il letto non
## esiste (ancora): si riprova col poll.
func _appendi_cornice(riga: Dictionary) -> bool:
	if _cornici.has(riga["png"]):
		return true
	var build := get_node_or_null("../../BuildSystem")
	if build == null or not build.has_method("get_placed_by_name"):
		return false
	var cella := Vector2i(int(riga["cx"]), int(riga["cz"]))
	for bed in build.call("get_placed_by_name", "Letto"):
		var b := bed as Node3D
		if Vector2i(roundi(b.position.x), roundi(b.position.z)) != cella:
			continue
		var img := Image.load_from_file(str(riga["png"]))
		if img == null or img.is_empty():
			return true   # file perso: non riprovare per sempre
		var cornice := fai_cornice(img)
		add_child(cornice)
		# sopra la testata, girata come il letto, storta quel poco
		var quante := 0
		for a in _appese:
			if a["nome"] == riga["nome"] and _cornici.has(a["png"]):
				quante += 1
		cornice.global_position = b.global_position \
				+ Vector3(0, 1.30 + 0.06 * float(quante), 0) \
				+ b.global_transform.basis.z * -0.42 \
				+ b.global_transform.basis.x * (0.34 * float(quante))
		cornice.rotation.y = b.rotation.y
		cornice.rotation.z = randf_range(-0.045, 0.045)
		_cornici[riga["png"]] = cornice
		_scintille(cornice.global_position)
		return true
	return false


## La cornice: legno caldo, retro, la FOTO vera, chiodino e spago a
## triangolo. Un piccolo oggetto d'affetto, non un texture-quad nudo.
static func fai_cornice(img: Image) -> Node3D:
	var root := Node3D.new()
	var aspetto := float(img.get_width()) / float(maxi(1, img.get_height()))
	var w := 0.52
	var h := w / maxf(aspetto, 0.1)
	var bordo := 0.038
	var legno := ShaderMaterial.new()
	legno.shader = TOON
	legno.set_shader_parameter("albedo_color", Color("9a6b4f"))
	var legno_scuro := ShaderMaterial.new()
	legno_scuro.shader = TOON
	legno_scuro.set_shader_parameter("albedo_color", Color("7e563f"))

	var box := func(size: Vector3, mat: Material, pos: Vector3) -> void:
		var bm := BoxMesh.new()
		bm.size = size
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = mat
		mi.position = pos
		root.add_child(mi)

	# il retro e i quattro listelli della cornice. La faccia di mostra è
	# +Z (il quad guarda +Z): il retro sta DIETRO, a -Z — impilarlo a +Z
	# significava vedere il pannello e mai la foto
	box.call(Vector3(w + bordo * 2.0, h + bordo * 2.0, 0.016), legno_scuro,
			Vector3(0, 0, -0.010))
	box.call(Vector3(w + bordo * 2.0, bordo, 0.03), legno,
			Vector3(0, h * 0.5 + bordo * 0.5, 0))
	box.call(Vector3(w + bordo * 2.0, bordo, 0.03), legno,
			Vector3(0, -h * 0.5 - bordo * 0.5, 0))
	box.call(Vector3(bordo, h, 0.03), legno, Vector3(w * 0.5 + bordo * 0.5, 0, 0))
	box.call(Vector3(bordo, h, 0.03), legno, Vector3(-w * 0.5 - bordo * 0.5, 0, 0))

	# la foto vera (unshaded: si legge anche nella penombra di casa)
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_texture = ImageTexture.create_from_image(img)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = fmat
	mi.position = Vector3(0, 0, 0.002)
	root.add_child(mi)

	# il chiodino e lo spago a triangolo: la firma della cura
	var spago := ShaderMaterial.new()
	spago.shader = TOON
	spago.set_shader_parameter("albedo_color", Color("d8c6a2"))
	var chiodo := CylinderMesh.new()
	chiodo.top_radius = 0.012
	chiodo.bottom_radius = 0.012
	chiodo.height = 0.02
	var cn := MeshInstance3D.new()
	cn.mesh = chiodo
	cn.material_override = legno_scuro
	cn.rotation.x = PI * 0.5
	cn.position = Vector3(0, h * 0.5 + bordo + 0.075, 0.004)
	root.add_child(cn)
	for lato: float in [-1.0, 1.0]:
		var filo := CylinderMesh.new()
		filo.top_radius = 0.006
		filo.bottom_radius = 0.006
		var lung := Vector2(w * 0.5, 0.075 + bordo).length()
		filo.height = lung
		var fl := MeshInstance3D.new()
		fl.mesh = filo
		fl.material_override = spago
		fl.position = Vector3(lato * w * 0.25, h * 0.5 + bordo * 0.5 + 0.038, 0.002)
		fl.rotation.z = lato * atan2(w * 0.5, 0.075 + bordo)
		root.add_child(fl)
	return root


## Al massimo MAX_CORNICI_PER_CASA per residente: la più vecchia lascia
## il chiodo alla nuova (il PNG resta su disco: i ricordi non si buttano).
func _pota_cornici(nome: String) -> void:
	var mie: Array = []
	for a in _appese:
		if str(a["nome"]) == nome:
			mie.append(a)
	while mie.size() > MAX_CORNICI_PER_CASA:
		var vecchia: Dictionary = mie.pop_front()
		var nodo = _cornici.get(vecchia["png"])
		if nodo and is_instance_valid(nodo):
			(nodo as Node).queue_free()
		_cornici.erase(vecchia["png"])
		_appese.erase(vecchia)


## Se il letto sparisce (casa smontata, residente partito), la cornice
## non resta a galleggiare nel vuoto.
func _cornici_orfane() -> void:
	var build := get_node_or_null("../../BuildSystem")
	if build == null or not build.has_method("get_placed_by_name"):
		return
	var celle := {}
	for bed in build.call("get_placed_by_name", "Letto"):
		var b := bed as Node3D
		celle[Vector2i(roundi(b.position.x), roundi(b.position.z))] = true
	for i in range(_appese.size() - 1, -1, -1):
		var a: Dictionary = _appese[i]
		if celle.has(Vector2i(int(a["cx"]), int(a["cz"]))):
			continue
		var nodo = _cornici.get(a["png"])
		if nodo and is_instance_valid(nodo):
			(nodo as Node).queue_free()
		_cornici.erase(a["png"])
		_appese.remove_at(i)
		_salva()


func _riappendi_in_attesa() -> void:
	for i in range(_da_appendere.size() - 1, -1, -1):
		if _appendi_cornice(_da_appendere[i]):
			_da_appendere.remove_at(i)


# ------------------------------------------------------ la nuvoletta-sogno

## La nuvoletta di pensiero con dentro la macchinetta fotografica: il
## segno, leggibile da lontano, che qualcuno sta sognando una foto.
func _attacca_icona(node: Node3D) -> void:
	if _icona and is_instance_valid(_icona):
		_icona.queue_free()
	_icona = fai_icona_sogno()
	node.add_child(_icona)
	_icona.position = Vector3(0, 1.58, 0)


static func fai_icona_sogno() -> Node3D:
	var root := Node3D.new()
	var nuvola := StandardMaterial3D.new()
	nuvola.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nuvola.albedo_color = Color(1.0, 0.99, 0.96, 0.92)
	nuvola.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var palla := func(r: float, pos: Vector3, scl: Vector3) -> void:
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 16
		sm.rings = 10
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = nuvola
		mi.position = pos
		mi.scale = scl
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)

	# la nuvoletta: tre sbuffi + le due bollicine della coda di pensiero
	palla.call(0.16, Vector3(0, 0.02, 0), Vector3(1.15, 0.85, 0.7))
	palla.call(0.115, Vector3(-0.155, -0.01, 0), Vector3(1, 0.8, 0.65))
	palla.call(0.115, Vector3(0.155, -0.01, 0), Vector3(1, 0.8, 0.65))
	palla.call(0.045, Vector3(-0.1, -0.19, 0), Vector3.ONE)
	palla.call(0.026, Vector3(-0.16, -0.28, 0), Vector3.ONE)

	# la macchinetta: corpo, obiettivo verso chi guarda, flash e scatto
	var corpo := StandardMaterial3D.new()
	corpo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	corpo.albedo_color = Color("6b5b52")
	var body := BoxMesh.new()
	body.size = Vector3(0.15, 0.095, 0.055)
	var bm := MeshInstance3D.new()
	bm.mesh = body
	bm.material_override = corpo
	bm.position = Vector3(0, 0.02, -0.045)
	root.add_child(bm)
	var lente := CylinderMesh.new()
	lente.top_radius = 0.034
	lente.bottom_radius = 0.034
	lente.height = 0.028
	var lm := MeshInstance3D.new()
	lm.mesh = lente
	var vetro := StandardMaterial3D.new()
	vetro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vetro.albedo_color = Color("35404d")
	lm.material_override = vetro
	lm.rotation.x = PI * 0.5
	lm.position = Vector3(0, 0.02, -0.085)
	root.add_child(lm)
	var flash := BoxMesh.new()
	flash.size = Vector3(0.035, 0.022, 0.02)
	var fm := MeshInstance3D.new()
	fm.mesh = flash
	var giallo := StandardMaterial3D.new()
	giallo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	giallo.albedo_color = Color("ffd76e")
	giallo.emission_enabled = true
	giallo.emission = Color("ffd76e")
	giallo.emission_energy_multiplier = 0.6
	fm.material_override = giallo
	fm.position = Vector3(0.045, 0.075, -0.045)
	root.add_child(fm)
	return root


func _scintille(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.12
	pm.gravity = Vector3(0, -0.5, 0)
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.1
	pm.scale_min = 0.4
	pm.scale_max = 0.9
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = GEO.soft_circle(Color(1.0, 0.86, 0.5, 0.9), 0.4)
	quad.material = mat
	p.draw_pass_1 = quad
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())


# ------------------------------------------------------------------- l'HUD

func _fai_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 21
	_hud.visible = false
	add_child(_hud)

	_hud_sogno = Label.new()
	_hud_sogno.add_theme_font_size_override("font_size", 15)
	_hud_sogno.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_hud_sogno.add_theme_color_override("font_shadow_color", Color(0.2, 0.12, 0.1, 0.6))
	_hud_sogno.add_theme_constant_override("shadow_offset_y", 1)
	_hud_sogno.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hud_sogno.offset_top = 72.0
	_hud_sogno.offset_bottom = 96.0
	_hud_sogno.offset_left = -320.0
	_hud_sogno.offset_right = 320.0
	_hud_sogno.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_hud_sogno)

	_hud_stato = Label.new()
	_hud_stato.add_theme_font_size_override("font_size", 14)
	_hud_stato.add_theme_color_override("font_shadow_color", Color(0.2, 0.12, 0.1, 0.6))
	_hud_stato.add_theme_constant_override("shadow_offset_y", 1)
	_hud_stato.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hud_stato.offset_top = 98.0
	_hud_stato.offset_bottom = 122.0
	_hud_stato.offset_left = -320.0
	_hud_stato.offset_right = 320.0
	_hud_stato.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_hud_stato)


## PhotoMode la chiama un attimo prima di catturare: l'inquadratura è del
## giocatore, le scritte no.
func nascondi_hud() -> void:
	_hud_sospeso = 0.2
	_hud.visible = false


func _aggiorna_hud() -> void:
	if _hud_sospeso > 0.0:
		_hud_sospeso -= get_process_delta_time()
		_hud.visible = false
		return
	var pm := get_node_or_null("../../PhotoMode")
	var attiva: bool = pm != null and bool(pm.call("is_active")) \
			and not _richiesta.is_empty()
	_hud.visible = attiva
	if not attiva:
		return
	_hud_sogno.text = L10n.tf("Il sogno di %s: «%s»",
			[str(_richiesta["label"]), L10n.t(str(_richiesta["testo"]))])
	var motivo := _motivo_live()
	if motivo == "":
		_hud_stato.text = L10n.t("Inquadratura perfetta — scatta!")
		_hud_stato.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	else:
		_hud_stato.text = "· %s ·" % L10n.t(motivo)
		_hud_stato.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))


func _toast(testo: String) -> void:
	var visitors := get_node_or_null("../../Visitors")
	if visitors:
		visitors.call("_show_toast", testo)


# ------------------------------------------------------------- la memoria

func _salva() -> void:
	var f := FileAccess.open(_file, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"attiva": _richiesta, "appese": _appese}))


func _carica() -> void:
	if not FileAccess.file_exists(_file):
		return
	var dati = JSON.parse_string(FileAccess.get_file_as_string(_file))
	if dati is not Dictionary:
		return
	_richiesta = dati.get("attiva", {})
	for riga in (dati.get("appese", []) as Array):
		if riga is Dictionary and FileAccess.file_exists(str(riga.get("png", ""))):
			_appese.append(riga)
			_da_appendere.append(riga)
	# la nuvoletta torna sopra il sognatore (quando il residente rientra)
	if not _richiesta.is_empty():
		var r := _trova_residente()
		if not r.is_empty():
			_attacca_icona(r["node"] as Node3D)
