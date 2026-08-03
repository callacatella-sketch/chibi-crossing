extends Node3D

## LE CORDE VIVE — il gestore che fa muovere ogni corda del villaggio.
##
## La fisica sta in CordaFisica.gd (pura, testata a occhi chiusi); qui
## c'è il mondo: il vento di Weather, il fianco di Mochi che sfiora una
## corda passando, le lampadine che seguono il filo, il seggiolino
## dell'altalena appeso alle sue due corde. UN posto solo: le corde non
## hanno script proprio (i pezzi piazzati restano nodi nudi) — si
## dichiarano col meta «corda» e il gruppo «corda_viva», e questo nodo
## le trova e le fa respirare.
##
## COME SI DICHIARA UNA CORDA (vedi BuildCatalog._corda_viva):
##   il nodo è una MeshInstance3D a trasformata identità sotto la radice
##   del pezzo (i punti vivono nello spazio del pezzo), nel gruppo
##   "corda_viva", con meta "corda" = {
##     a, b: Vector3        gli ancoraggi (b ignorato se libera=true)
##     molle: float         abbondanza di corda (0.15 = +15%)
##     raggio: float        raggio del tubo
##     punti: int           quanti nodi di simulazione
##     vento: float         quanto questa corda sente il vento (1 = filo leggero)
##     libera: bool         true = pende da un capo solo (la campana)
##     appesi: Array        [{path, t, giu}] — nodi che seguono la corda
##     tiranti: Array       [{path, t, fondo, resto}] — cilindri tesi fra
##                          la corda (a t) e un punto fisso, riorientati
##     gemella: NodePath    la corda sorella (altalena)
##     solidale: NodePath   il nodo rigido appeso alle DUE corde
##     larghezza: float     distanza fra i fondi delle due sorelle
##     peso_fondo: float    massa extra sull'ultimo punto (il sedile)
##   }
##
## La posa da ferma resta scolpita dal builder: in foto, nei test senza
## albero e con «Riduci animazioni» la corda è comunque giusta — qui si
## AGGIUNGE il movimento, non si ripara l'assenza.

const FISICA := preload("res://scenes/world/CordaFisica.gd")

## Sotto questo movimento la mesh non si riscrive: nessun occhio lo vede
## e la ImmediateMesh è l'unico costo vero del sistema.
const SOGLIA_SONNO := 0.0004
## Il fianco di Mochi: quanto «ingombra» passando fra le corde.
const RAGGIO_MOCHI := 0.42
## Ogni quanto si torna a cercare corde nuove (i pezzi si piazzano e si
## tolgono): il segnale placed_changed fa da campanello, questo è la rete.
const RICENSIMENTO := 4.0

var _corde: Array = []          # stati vivi, uno per corda
var _censite := {}              # instance_id -> true
var _player: Node3D
var _weather: Node3D
var _clock := 0.0
var _dir_vento := 0.0
var _ricenso := 0.0
## Nei test: forza del vento imposta a mano (-1 = leggi dal mondo).
var vento_forzato := -1.0


func _ready() -> void:
	# i vicini di MainLevel arrivano dopo: si aggancia in differita, e il
	# censimento riprova comunque a ogni giro (lezione del Taccuino)
	(func() -> void:
		_player = get_node_or_null("../Player")
		_weather = get_node_or_null("../Weather")
		var build := get_tree().get_first_node_in_group("build_system")
		if build and build.has_signal("placed_changed"):
			build.connect("placed_changed", func() -> void: _ricenso = RICENSIMENTO)
		_censisci()).call_deferred()


func _process(delta: float) -> void:
	if _riduci_animazioni():
		return
	_ricenso += delta
	if _ricenso >= RICENSIMENTO:
		_ricenso = 0.0
		_censisci()
	passo(minf(delta, 1.0 / 30.0))


func _riduci_animazioni() -> bool:
	if not is_inside_tree():
		return false
	var s := get_node_or_null("/root/Settings")
	return s != null and bool(s.get("reduce_motion"))


## Il censimento: ogni nodo nuovo del gruppo diventa uno stato vivo.
func _censisci() -> void:
	if not is_inside_tree():
		return
	for nodo in get_tree().get_nodes_in_group("corda_viva"):
		registra(nodo)


## Prepara lo stato di una corda dichiarata. Pubblica per i test (che
## non hanno l'albero e passano i nodi a mano).
func registra(nodo: Node) -> void:
	if not (nodo is MeshInstance3D) or _censite.has(nodo.get_instance_id()):
		return
	var m: Dictionary = nodo.get_meta("corda", {})
	if m.is_empty():
		return
	_censite[nodo.get_instance_id()] = true
	var a: Vector3 = m["a"]
	var b: Vector3 = m.get("b", a)
	var n_punti: int = int(m.get("punti", 10))
	var libera: bool = bool(m.get("libera", false))
	var punti: Array
	if libera:
		punti = FISICA.riposo_libera(a,
				FISICA.lunghezza(a, b, float(m.get("molle", 0.1))), n_punti)
	else:
		punti = FISICA.riposo(a, b, float(m.get("molle", 0.1)), n_punti)
	var seg: float = FISICA.lunghezza(a, b, float(m.get("molle", 0.1))) / float(n_punti - 1)
	var ancore := {0: a}
	if not libera:
		ancore[n_punti - 1] = b
	_corde.append({
		"nodo": nodo, "punti": punti, "prev": punti.duplicate(),
		"seg": seg, "ancore": ancore,
		"raggio": float(m.get("raggio", 0.01)), "lati": int(m.get("lati", 6)),
		"vento": float(m.get("vento", 1.0)),
		"fase": fmod(float(nodo.get_instance_id()) * 0.618, TAU),
		"peso_fondo": float(m.get("peso_fondo", 0.0)),
		"id": nodo.get_instance_id(),
		"appesi": _risolvi(nodo, m.get("appesi", [])),
		"tiranti": _risolvi(nodo, m.get("tiranti", [])),
		"gemella": nodo.get_node_or_null(str(m["gemella"])) if m.has("gemella") else null,
		"solidale": nodo.get_node_or_null(str(m["solidale"])) if m.has("solidale") else null,
		"larghezza": float(m.get("larghezza", 0.0)),
		"sveglia": true,
	})


func _risolvi(nodo: Node, voci: Array) -> Array:
	var fuori: Array = []
	for v in voci:
		var d: Dictionary = (v as Dictionary).duplicate()
		d["nodo"] = nodo.get_node_or_null(str(d["path"]))
		if d["nodo"] != null:
			fuori.append(d)
	return fuori


## Un passo del mondo. Separato da _process per i test headless.
func passo(delta: float) -> void:
	_clock += delta
	_dir_vento += delta * 0.07
	var forza := _forza_vento()
	var vento_mondo := Vector3(cos(_dir_vento), 0.06, sin(_dir_vento)) \
			* (1.1 * forza * forza)
	var mochi := _player.global_position if is_instance_valid(_player) else Vector3.INF

	var vivi: Array = []
	for c in _corde:
		var nodo: MeshInstance3D = c["nodo"]
		if not is_instance_valid(nodo):
			_censite.erase(c["id"])   # il pezzo è stato tolto: si dimentica
			continue
		vivi.append(c)
		var inv: Basis = nodo.global_transform.basis.inverse()
		var punti: Array = c["punti"]
		var prev: Array = c["prev"]
		# la gravità e il vento, portati nello spazio del pezzo
		FISICA.soffia(punti, prev, delta, inv * (vento_mondo * c["vento"]),
				_clock, c["fase"])
		FISICA.passo(punti, prev, delta, inv * Vector3(0, -9.8, 0))
		if c["peso_fondo"] > 0.0:
			punti[punti.size() - 1] += inv * Vector3(0, -9.8, 0) \
					* (c["peso_fondo"] * delta * delta)
		FISICA.vincola(punti, c["seg"], c["ancore"])
		# la spinta di Mochi, se il mondo ce l'ha
		if mochi != Vector3.INF:
			var vicino: Vector3 = nodo.to_local(mochi)
			FISICA.spingi(punti, vicino + Vector3(0, 0.45, 0), RAGGIO_MOCHI)
			FISICA.vincola(punti, c["seg"], c["ancore"], 1)
	_corde = vivi

	# le coppie (l'altalena): il sedile lega i fondi DOPO i vincoli propri
	for c2 in _corde:
		if c2["gemella"] == null:
			continue
		var sorella: Dictionary = _stato_di(c2["gemella"])
		if sorella.is_empty():
			continue
		var pa: Array = c2["punti"]
		var pb: Array = sorella["punti"]
		var stretta: Array = FISICA.lega(pa[pa.size() - 1], pb[pb.size() - 1],
				c2["larghezza"])
		pa[pa.size() - 1] = stretta[0]
		pb[pb.size() - 1] = stretta[1]
		FISICA.vincola(pa, c2["seg"], c2["ancore"], 1)
		FISICA.vincola(pb, sorella["seg"], sorella["ancore"], 1)
		_siedi(c2, sorella)

	# i tubi e gli appesi, solo per chi si è mosso davvero
	for c3 in _corde:
		var mosso: float = FISICA.agitazione(c3["punti"], c3["prev"])
		if mosso < SOGLIA_SONNO and not c3["sveglia"]:
			continue
		c3["sveglia"] = mosso >= SOGLIA_SONNO
		_ridisegna(c3)


func _forza_vento() -> float:
	if vento_forzato >= 0.0:
		return vento_forzato
	var v: Variant = RenderingServer.global_shader_parameter_get("vento_forza")
	return float(v) if v != null else 1.0


func _stato_di(nodo: Node) -> Dictionary:
	for c in _corde:
		if c["nodo"] == nodo:
			return c
	return {}


## Il sedile dell'altalena: appeso ai fondi delle due corde, orientato
## come le corde lo tengono — non il contrario.
func _siedi(ca: Dictionary, cb: Dictionary) -> void:
	var sedile: Node3D = ca["solidale"]
	if sedile == null or not is_instance_valid(sedile):
		return
	var pa: Array = ca["punti"]
	var pb: Array = cb["punti"]
	var fa: Vector3 = pa[pa.size() - 1]
	var fb: Vector3 = pb[pb.size() - 1]
	var su: Vector3 = ((pa[pa.size() - 2] - fa) + (pb[pb.size() - 2] - fb)).normalized()
	var lato: Vector3 = (fb - fa).normalized()
	lato = (lato - su * lato.dot(su)).normalized()
	var avanti: Vector3 = lato.cross(su)
	sedile.position = (fa + fb) * 0.5 + su * -0.01
	sedile.basis = Basis(lato, su, avanti)


func _ridisegna(c: Dictionary) -> void:
	var nodo: MeshInstance3D = c["nodo"]
	if not (nodo.mesh is ImmediateMesh):
		nodo.mesh = ImmediateMesh.new()
	FISICA.scrivi_tubo(nodo.mesh, c["punti"], c["raggio"], c["lati"])
	var punti: Array = c["punti"]
	for ap in c["appesi"]:
		var seguace: Node3D = ap["nodo"]
		if not is_instance_valid(seguace):
			continue
		seguace.position = FISICA.campiona(punti, float(ap["t"])) \
				+ Vector3(0, -float(ap.get("giu", 0.0)), 0)
	for ti in c["tiranti"]:
		var cil: Node3D = ti["nodo"]
		if not is_instance_valid(cil):
			continue
		var cima: Vector3 = FISICA.campiona(punti, float(ti["t"]))
		var fondo: Vector3 = ti["fondo"]
		var asse: Vector3 = cima - fondo
		var lungo := asse.length()
		if lungo < 0.001:
			continue
		cil.position = (cima + fondo) * 0.5
		cil.quaternion = Quaternion(Vector3.UP, asse / lungo)
		cil.scale = Vector3(1, lungo / float(ti["resto"]), 1)
		if ti.has("nodino"):
			var palla: Node3D = nodo.get_node_or_null(str(ti["nodino"]))
			if palla != null:
				palla.position = cima
