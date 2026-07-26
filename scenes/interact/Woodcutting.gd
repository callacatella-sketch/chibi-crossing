extends Node

## Il taglio della legna — l'ascia, la tacca e la ricrescita.
##
## Si tagliano GLI ALBERI VERI del mondo: quelli che CozyWorld pianta con
## _make_tree si iscrivono al gruppo "albero" e questo sistema li adotta tutti.
## Il Grande Albero non passa da lì e resta intoccabile, com'è giusto.
##
## Il rituale (mai violento — l'albero DONA il suo legno e poi rinasce):
##   1. ti avvicini a un albero qualsiasi: "E — taglia la legna"
##   2. ogni colpo SCAVA una tacca vera nel tronco: la mesh del tronco viene
##      rigenerata con un cuneo sottratto, sempre più profondo, e dentro si
##      vede il legno chiaro appena esposto
##   3. al terzo colpo l'albero scricchiola e si abbatte con la fisica vera,
##      la chioma che frusta in ritardo
##   4. il tronco caduto si dissolve in ceppetti di legna; resta il ceppo,
##      tagliato di netto alla quota esatta della tacca
##   5. dal taglio, giorno dopo giorno: germoglio → alberello → albero
##
## LA TACCA NON È UN OGGETTO APPICCICATO AL TRONCO: è geometria sottratta.
## Il tronco viene ricostruito con lo stesso identico profilo di
## CozyWorld._trunk_mesh (rastremazione, svasatura delle radici, gobbe della
## corteccia: stesso seme, stessa forma) e a quel profilo si toglie un cuneo.
## Le facce nate dal taglio prendono il materiale del legno vivo, il resto
## resta corteccia — per questo si legge come un taglio e non come una toppa.
##
## Il tremito del tronco e il penzolio della chioma NON sono tween ma MOLLE
## smorzate integrate a mano in _process: ogni colpo somma il suo impulso a
## quello che sta ancora oscillando.
##
## Il sistema è autonomo: si registra da sé nel gruppo "persistable" (lo stato
## viaggia in user://village.json senza toccare BuildSystem) e nel gruppo
## "woodcutting" (così BuildSystem gli chiede il legno per costruire).

const CATALOG := preload("res://scenes/build/BuildCatalog.gd")

# --- estetica ---
const BARK := Color("9a6b4f")
const BARK_DARK := Color("7e563f")
const CUT := Color("e8cfa8")        # il legno vivo del taglio, chiaro
const CUT_DARK := Color("cfae82")
const ROPE := Color("d9c08a")

# --- regole del gioco ---
const HITS_TO_FELL := 3             # colpi per abbattere un albero
const WOOD_PER_TREE := 3            # ceppetti di legna donati
const CHOP_RANGE := 2.4             # da quanto lontano si può colpire
## Dopo quanti giorni dal taglio il bosco si rimargina ALTROVE. Non dove hai
## tagliato: quel terreno è tuo, ci puoi costruire.
const REGROW_DAYS := 2

# --- la tacca (in frazioni dell'altezza del tronco) ---
const NOTCH_T := 0.42               # quota del taglio: all'altezza della spalla di
                                    # Mochi. Più in basso sarebbe realistico ma finirebbe
                                    # SEPOLTO NELL'ERBA, e il giocatore non vedrebbe nulla
const NOTCH_HALF := 0.19            # semi-altezza del cuneo: la "bocca" dev'essere GRANDE
const NOTCH_ARC := 1.15             # semi-apertura angolare: un MORSO ben visibile
## quanto affonda ogni colpo, in frazione del raggio del tronco
const NOTCH_DEPTH := [0.45, 0.72, 0.92]
const TRUNK_SEGS := 22              # risoluzione angolare del tronco intagliato

## La catasta con cui si comincia: senza, il primo giorno non si potrebbe
## posare nemmeno un'asse, e il gioco direbbe "no" prima ancora di spiegarsi.
const START_WOOD := 8

## Quanta legna costa ogni pezzo di legno del catalogo. I pezzi non elencati
## sono gratis (fiori, aiuole, tappeti: non si fanno con le assi).
const PIECE_COST := {
	"Pavimento": 2, "Muro": 3, "Finestra": 3, "Porta": 3, "Staccionata": 1,
	"Solaio": 3, "Scala": 3, "Ponticello": 4, "Casa albero": 8, "Tetto": 2,
	"Tavolino": 2, "Sedia": 2, "Sgabello": 1, "Letto": 4, "Libreria": 3,
	"Comodino": 2,
}

## La legna in tasca.
var wood := START_WOOD

var _player: Node3D
var _mochi: Node
var _cozy: Node
var _daynight: Node
var _sfx
var _trees: Array[Dictionary] = []
var _busy := false
var _t := 0.0
var _near := -1
var _prompt: PanelContainer
var _prompt_label: Label
var _cam_shake := 0.0
var _cam_pivot: Node3D
var _shake_seed := 0.0
# lo stato letto dal salvataggio prima che gli alberi siano adottati
var _pending_rows: Array = []
var _cut_mat: ShaderMaterial
const SPOTS := preload("res://scenes/world/TreeSpots.gd")
## Il debito col bosco: per ogni albero abbattuto, il giorno in cui ne
## rinascerà uno altrove. [[giorno, x, z], ...] — x,z = dov'era quello vecchio,
## così il bosco si rimargina lì attorno e non dall'altra parte della valle.
var _debt: Array = []
## Dove sono stati abbattuti alberi (per non farli tornare al riavvio) e
## dove ne sono nati di nuovi (per ritrovarli).
var _felled: Array = []           # Vector2
var _planted: Array = []          # Vector2


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("woodcutting")
	_sfx = get_node_or_null(^"/root/Sfx")
	_cut_mat = CATALOG._mat(CUT, CUT_DARK, 9.0, 0.5)
	_build_prompt()
	# %Player non si risolve dai nodi creati a runtime (owner null): gruppo,
	# e a fine frame, quando tutto il livello è in piedi
	(func() -> void:
		_player = get_tree().get_first_node_in_group("player_controller")
		_cozy = get_tree().get_first_node_in_group("cozy_world")
		_daynight = get_node_or_null("../DayNight")
		if _player:
			_mochi = _player.get_node_or_null("Mochi")
			_cam_pivot = _player.get_node_or_null("CameraPivot")
		if _daynight and _daynight.has_signal("day_changed"):
			_daynight.day_changed.connect(_on_day_changed)
		# CozyWorld genera il mondo DIFFERITO su più frame (per non far
		# singhiozzare l'avvio): all'inizio gli alberi non ci sono ancora.
		# Ci si aggancia al segnale che annuncia la geometria finita — e si
		# tenta comunque subito, per i casi in cui il mondo è già in piedi.
		if _cozy and _cozy.has_signal("world_built"):
			_cozy.world_built.connect(_adopt_trees)
		_adopt_trees()
	).call_deferred()


# ================================================================ adozione

# Prende in carico ogni albero del mondo (gruppo "albero"). Il Grande Albero
# non è in quel gruppo: non si tocca.
func _adopt_trees() -> void:
	var nodes := get_tree().get_nodes_in_group("albero")
	# idempotente: si può chiamare a ogni pezzo di mondo che nasce, e prende
	# in carico solo gli alberi che non ha già
	var gia := {}
	for t in _trees:
		gia[t["root"]] = true
	nodes = nodes.filter(func(n: Node) -> bool: return not gia.has(n))
	if nodes.is_empty():
		return
	for n in nodes:
		var t := _adopt(n as Node3D)
		if not t.is_empty():
			_trees.append(t)
	# ordine deterministico su TUTTO l'elenco: il salvataggio indicizza per
	# posizione, non per ordine di nascita (il mondo si costruisce a pezzi,
	# su più frame, e l'ordine di arrivo non è garantito)
	_trees.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: Vector3 = (a["root"] as Node3D).global_position
		var pb: Vector3 = (b["root"] as Node3D).global_position
		if absf(pa.x - pb.x) > 0.01:
			return pa.x < pb.x
		return pa.z < pb.z)
	# ora che gli alberi ci sono, si applica lo stato che il salvataggio
	# aveva consegnato prima dell'adozione
	if not _pending_rows.is_empty():
		_apply_rows(_pending_rows)
		_pending_rows = []


func _adopt(root: Node3D) -> Dictionary:
	var trunk := root.get_node_or_null(^"Tronco") as MeshInstance3D
	var deco := root.get_node_or_null(^"Rami") as MeshInstance3D
	var canopy := root.get_node_or_null(^"Chioma") as Node3D
	var spec: Array = root.get_meta("trunk", [])
	if trunk == null or canopy == null or spec.size() < 4:
		return {}     # non è un albero come ce lo aspettiamo: lascialo stare

	# Il PERNO: l'albero del mondo ha già una rotazione.y sua (ogni albero
	# guarda da una parte diversa). Se piegassimo quello, la caduta partirebbe
	# storta. Perciò infiliamo un perno pulito alla base e ci trasferiamo
	# dentro tronco, rami e chioma: da lì l'albero si piega dritto.
	var pivot := Node3D.new()
	pivot.name = "Perno"
	root.add_child(pivot)
	for child in [trunk, deco, canopy]:
		if child != null:
			root.remove_child(child)
			pivot.add_child(child)

	var stump := _make_stump(spec, root.get_meta("bark_mat", null))
	stump.visible = false
	root.add_child(stump)

	return {
		"root": root, "pivot": pivot, "trunk": trunk, "deco": deco,
		"canopy": canopy, "stump": stump,
		"spec": spec, "bark": root.get_meta("bark_mat", null),
		"leaf": root.get_meta("leaf_color", Color("8cc873")),
		"hp": HITS_TO_FELL,
		"shake_a": 0.0, "shake_v": 0.0, "can_a": 0.0, "can_v": 0.0,
		"falling": false, "fall_a": 0.0, "fall_v": 0.0, "fall_dir": 1.0,
		"carved": false, "pivot_yaw": 0.0, "notch_dir": PI,
	}


# ================================================================ il tronco intagliato

# Rigenera il tronco con un CUNEO SOTTRATTO alla geometria.
#
# Il profilo è quello identico di CozyWorld._trunk_mesh (stesso seme, stessa
# sequenza di numeri casuali: la stessa forma), così l'albero non "cambia" nel
# momento in cui lo si colpisce. Poi, dentro la zona della tacca, il raggio
# viene ridotto: la superficie rientra e nasce l'incavo. Le facce che ne
# escono prendono il materiale del legno vivo.
#
# [param depth01] 0 = intatto, 1 = tacca profonda quanto il raggio.
func _carved_trunk_mesh(spec: Array, notch_dir: float, depth01: float) -> ArrayMesh:
	var h: float = spec[0]
	var rb: float = spec[1]
	var rt: float = spec[2]
	var seed_v: int = int(spec[3])
	var bend := 0.07

	# --- stessa sequenza casuale di CozyWorld._trunk_mesh: stessa forma ---
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var ph := rng.randf() * TAU
	var kink := rng.randf_range(2.0, 3.4)
	var lean := Vector2(cos(ph), sin(ph)) * bend * h

	# gli anelli: quelli originali più una batteria fitta attorno alla tacca
	# (i bordi del cuneo cadono ESATTAMENTE su un anello, così il taglio ha
	# uno spigolo netto e non una sfumatura)
	var ts := [0.0, 0.05, 0.14, 0.32, 0.58, 0.82, 1.0]
	if depth01 > 0.0:
		for k in [-1.0, -0.66, -0.33, 0.0, 0.33, 0.66, 1.0]:
			ts.append(clampf(NOTCH_T + NOTCH_HALF * k, 0.0, 1.0))
		# due anelli appena fuori: lo spigolo vivo del taglio
		ts.append(clampf(NOTCH_T - NOTCH_HALF - 0.008, 0.0, 1.0))
		ts.append(clampf(NOTCH_T + NOTCH_HALF * 0.5 + 0.008, 0.0, 1.0))
	ts.sort()

	var depth: float = depth01 * rb

	var grid: Array = []          # anelli di posizioni
	var cuts: Array = []          # quanto è stato tolto a ciascun vertice
	for t: float in ts:
		var prow: Array[Vector3] = []
		var crow: Array[float] = []
		for j in TRUNK_SEGS:
			var lon := float(j) / float(TRUNK_SEGS) * TAU
			var r := lerpf(rb, rt, pow(t, 0.85)) * (1.0 + 1.1 * pow(1.0 - t, 7.0))
			r *= 1.0 + 0.055 * sin(lon * 3.0 + t * kink + ph) \
					+ 0.03 * sin(lon * 7.0 - t * 2.0)
			var cut := 0.0
			if depth > 0.0:
				cut = _notch_cut(t, lon, notch_dir, depth)
				r = maxf(r * 0.16, r - cut)
			var c := Vector3(lean.x * t * t, t * h, lean.y * t * t)
			prow.append(c + Vector3(cos(lon) * r, 0, -sin(lon) * r))
			crow.append(cut)
		grid.append(prow)
		cuts.append(crow)

	var normals := _grid_normals(grid)
	var bark_st := SurfaceTool.new()
	bark_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cut_st := SurfaceTool.new()
	cut_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# la soglia decide quanto legno chiaro si vede: troppo alta e la tacca si
	# riduce a due facce invisibili, troppo bassa e il tronco sembra scolorito
	var soglia: float = maxf(0.002, depth * 0.06)
	var bark_faces := 0
	var cut_faces := 0

	for i in grid.size() - 1:
		for j in TRUNK_SEGS:
			var j2 := (j + 1) % TRUNK_SEGS
			var quad := [[i, j], [i, j2], [i + 1, j2], [i + 1, j]]
			var carved := false
			for q in quad:
				if float(cuts[q[0]][q[1]]) > soglia:
					carved = true
					break
			if carved:
				# Le facce del taglio usano le stesse normali (verso l'esterno)
				# del resto del tronco: calcolarle "piatte" dal prodotto
				# vettoriale le rovesciava verso l'interno, e il legno esposto
				# veniva illuminato da dietro — di qui l'arancione innaturale.
				# Lo spigolo netto lo dà comunque il cambio di materiale.
				_add_quad_smooth(cut_st, grid, normals, quad)
				cut_faces += 1
			else:
				_add_quad_smooth(bark_st, grid, normals, quad)
				bark_faces += 1

	# una SurfaceTool vuota non si può committare: finché non c'è un taglio,
	# la superficie del legno vivo non esiste proprio
	var mesh := ArrayMesh.new()
	if bark_faces > 0:
		bark_st.index()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bark_st.commit_to_arrays())
	if cut_faces > 0:
		cut_st.index()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cut_st.commit_to_arrays())
	return mesh


# Quanto affonda la lama nel punto (quota t, longitudine lon).
# La forma è quella di una vera tacca da boscaiolo: il taglio ALTO è netto e
# quasi orizzontale, quello BASSO scende in pendenza — insieme fanno la
# "bocca" che si apre nel tronco.
func _notch_cut(t: float, lon: float, notch_dir: float, depth: float) -> float:
	var dt := t - NOTCH_T
	var vf := 0.0
	if dt >= 0.0:
		vf = 1.0 - dt / (NOTCH_HALF * 0.5)     # sopra: parete corta e ripida
	else:
		vf = 1.0 - (-dt) / NOTCH_HALF          # sotto: piano inclinato
	if vf <= 0.0:
		return 0.0
	var dang: float = absf(wrapf(lon - notch_dir, -PI, PI)) / NOTCH_ARC
	if dang >= 1.0:
		return 0.0
	# fondo largo e piatto, poi le due guance che risalgono: così la tacca ha
	# dei fianchi veri invece di sfumare nel nulla
	var af: float = 1.0 - smoothstep(0.45, 1.0, dang)
	return depth * vf * af


# normali morbide da una griglia di anelli (media delle differenze coi vicini)
func _grid_normals(grid: Array) -> Array:
	var out: Array = []
	var rings: int = grid.size()
	for i in rings:
		var row: Array[Vector3] = []
		for j in TRUNK_SEGS:
			var p: Vector3 = grid[i][j]
			var du: Vector3 = (grid[i][(j + 1) % TRUNK_SEGS] as Vector3) \
					- (grid[i][(j - 1 + TRUNK_SEGS) % TRUNK_SEGS] as Vector3)
			var i_up: int = mini(i + 1, rings - 1)
			var i_dn: int = maxi(i - 1, 0)
			var dv: Vector3 = (grid[i_up][j] as Vector3) - (grid[i_dn][j] as Vector3)
			var n := dv.cross(du)
			if n.length_squared() < 0.0000001:
				n = Vector3(p.x, 0, p.z)
			n = n.normalized()
			# verso l'esterno, sempre
			if n.dot(Vector3(p.x, 0.0, p.z)) < 0.0:
				n = -n
			row.append(n)
		out.append(row)
	return out


func _add_quad_smooth(st: SurfaceTool, grid: Array, normals: Array, quad: Array) -> void:
	for tri in [[0, 1, 2], [0, 2, 3]]:
		for k in tri:
			var q: Array = quad[k]
			st.set_normal(normals[q[0]][q[1]])
			st.add_vertex(grid[q[0]][q[1]])


# applica al tronco la mesh con la tacca del colpo dato (1..3)
func _carve(t: Dictionary, hit_no: int) -> void:
	var trunk: MeshInstance3D = t["trunk"]
	if trunk == null or not is_instance_valid(trunk):
		return
	var depth: float = NOTCH_DEPTH[clampi(hit_no - 1, 0, NOTCH_DEPTH.size() - 1)]
	trunk.mesh = _carved_trunk_mesh(t["spec"], float(t["notch_dir"]), depth)
	# superficie 0 = corteccia (materiale originale), superficie 1 = legno vivo
	trunk.material_override = null
	trunk.set_surface_override_material(0, t["bark"])
	if trunk.mesh.get_surface_count() > 1:
		trunk.set_surface_override_material(1, _cut_mat)
	t["carved"] = true


# rimette il tronco intatto (ricrescita)
func _uncarve(t: Dictionary) -> void:
	var trunk: MeshInstance3D = t["trunk"]
	if trunk == null or not is_instance_valid(trunk):
		return
	trunk.mesh = _carved_trunk_mesh(t["spec"], 0.0, 0.0)
	trunk.set_surface_override_material(0, t["bark"])
	t["carved"] = false


# ================================================================ il ceppo

# Il ceppo è il tronco vero troncato ALLA QUOTA DELLA TACCA, con il disco
# chiaro del taglio in cima: non un cilindro qualunque, ma proprio quel pezzo
# di quell'albero, radici comprese.
func _make_stump(spec: Array, bark: Variant) -> Node3D:
	var h: float = spec[0]
	var rb: float = spec[1]
	var rt: float = spec[2]
	var seed_v: int = int(spec[3])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var ph := rng.randf() * TAU
	var kink := rng.randf_range(2.0, 3.4)
	var lean := Vector2(cos(ph), sin(ph)) * 0.07 * h
	var top_t: float = NOTCH_T + NOTCH_HALF * 0.35

	var ts := [0.0, 0.05, 0.14, top_t * 0.6, top_t]
	var grid: Array = []
	for t: float in ts:
		var prow: Array[Vector3] = []
		for j in TRUNK_SEGS:
			var lon := float(j) / float(TRUNK_SEGS) * TAU
			var r := lerpf(rb, rt, pow(t, 0.85)) * (1.0 + 1.1 * pow(1.0 - t, 7.0))
			r *= 1.0 + 0.055 * sin(lon * 3.0 + t * kink + ph) \
					+ 0.03 * sin(lon * 7.0 - t * 2.0)
			var c := Vector3(lean.x * t * t, t * h, lean.y * t * t)
			prow.append(c + Vector3(cos(lon) * r, 0, -sin(lon) * r))
		grid.append(prow)

	var normals := _grid_normals(grid)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in grid.size() - 1:
		for j in TRUNK_SEGS:
			var j2 := (j + 1) % TRUNK_SEGS
			_add_quad_smooth(st, grid, normals, [[i, j], [i, j2], [i + 1, j2], [i + 1, j]])
	st.index()

	var stump := Node3D.new()
	var body := MeshInstance3D.new()
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	body.mesh = m
	if bark != null:
		body.material_override = bark
	else:
		body.material_override = CATALOG._mat(BARK, BARK_DARK, 2.5, 0.55)
	stump.add_child(body)

	# il disco del taglio: legno vivo, con gli anelli appena accennati
	var cap_st := SurfaceTool.new()
	cap_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array = grid[grid.size() - 1]
	var centro := Vector3(lean.x * top_t * top_t, top_t * h + 0.004, lean.y * top_t * top_t)
	for j in TRUNK_SEGS:
		var j2 := (j + 1) % TRUNK_SEGS
		for p: Vector3 in [centro, Vector3(ring[j2]) + Vector3(0, 0.004, 0),
				Vector3(ring[j]) + Vector3(0, 0.004, 0)]:
			cap_st.set_normal(Vector3.UP)
			cap_st.add_vertex(p)
	cap_st.index()
	var cap := MeshInstance3D.new()
	var cm := ArrayMesh.new()
	cm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cap_st.commit_to_arrays())
	cap.mesh = cm
	cap.material_override = _cut_mat
	stump.add_child(cap)
	return stump


func _stump_top_y(spec: Array) -> float:
	return float(spec[0]) * (NOTCH_T + NOTCH_HALF * 0.35)


# ================================================================ ciclo

func _process(delta: float) -> void:
	_t += delta
	_update_springs(delta)
	_update_falls(delta)
	_update_camera_shake(delta)
	_materialize_forest()
	_update_prompt()


# Le MOLLE: tronco e chioma oscillano per conto loro. È questo (non i tween)
# a dare il peso: se colpisci mentre l'albero vibra ancora, gli impulsi si
# sommano e l'oscillazione cresce, come nella legna vera.
func _update_springs(delta: float) -> void:
	var d: float = minf(delta, 0.05)   # niente esplosioni se un frame va lungo
	for t in _trees:
		if t["falling"]:
			continue
		if absf(t["shake_a"]) < 0.0002 and absf(t["shake_v"]) < 0.0002 \
				and absf(t["can_a"]) < 0.0002 and absf(t["can_v"]) < 0.0002:
			continue          # albero fermo: non costa nulla
		# tronco: molla dura e ben smorzata (tremito secco)
		var a: float = t["shake_a"]
		var v: float = t["shake_v"]
		v += (-90.0 * a - 7.5 * v) * d
		a += v * d
		t["shake_a"] = a
		t["shake_v"] = v
		# chioma: molla morbida che insegue IL CONTRARIO del tronco (la frusta)
		var ca: float = t["can_a"]
		var cv: float = t["can_v"]
		cv += (-42.0 * (ca + a * 0.55) - 5.0 * cv) * d
		ca += cv * d
		t["can_a"] = ca
		t["can_v"] = cv
		_set_tilt(t, a)
		(t["canopy"] as Node3D).rotation.z = ca


# La CADUTA: integrata come un vero pendolo (accelerazione ∝ sin dell'angolo).
# Parte lentissima, accelera, e arriva a terra pesante.
func _update_falls(delta: float) -> void:
	var d: float = minf(delta, 0.05)
	for t in _trees:
		if not t["falling"]:
			continue
		var a: float = t["fall_a"]
		var v: float = t["fall_v"]
		# gravità del pendolo + una spinta costante: da soli i primi gradi
		# ci metterebbero un'eternità (è il vero motivo per cui gli alberi
		# dei film "scattano": la fibra che cede dà il calcio iniziale)
		v += (6.8 * sin(a) + 0.45) * d
		a += v * d
		var landed: bool = a >= 1.47        # ~84°: il tronco tocca terra
		if landed:
			a = 1.47
			t["falling"] = false
			_on_tree_landed(t)
		t["fall_a"] = a
		t["fall_v"] = v
		_set_tilt(t, a)
		# la chioma frusta in ritardo sulla caduta: molla morbida trascinata
		var cv: float = t["can_v"] + (-30.0 * (t["can_a"] + a * 0.32) - 4.2 * t["can_v"]) * d
		t["can_v"] = cv
		t["can_a"] = t["can_a"] + cv * d
		(t["canopy"] as Node3D).rotation.z = t["can_a"]


# Piega l'albero di [param tilt] radianti mantenendo l'orientamento del perno:
# l'ordine YXZ applica prima l'inclinazione (z) e poi l'imbardata (y), così
# l'albero cade sempre dalla parte che abbiamo deciso.
func _set_tilt(t: Dictionary, tilt: float) -> void:
	var pivot: Node3D = t["pivot"]
	pivot.rotation = Vector3(0.0, float(t["pivot_yaw"]), tilt * float(t["fall_dir"]))


func _update_camera_shake(delta: float) -> void:
	if _cam_pivot == null or _cam_shake <= 0.0:
		return
	_cam_shake = maxf(0.0, _cam_shake - delta * 3.4)
	var k := _cam_shake * _cam_shake      # decadimento morbido, mai brusco
	_shake_seed += delta * 47.0
	_cam_pivot.rotation.x = sin(_shake_seed) * 0.018 * k
	_cam_pivot.rotation.z = sin(_shake_seed * 1.37) * 0.014 * k
	if _cam_shake <= 0.001:
		_cam_pivot.rotation.x = 0.0
		_cam_pivot.rotation.z = 0.0


func _kick_camera(force: float) -> void:
	_cam_shake = minf(1.35, _cam_shake + force)


# Il bosco è disegnato con un MultiMesh: centinaia di alberi in un nodo solo,
# velocissimi da mostrare ma impossibili da animare uno per uno. Quando Mochi
# si avvicina a uno di loro, quell'istanza si spegne e al suo posto nasce un
# albero VERO — con tronco, chioma e collisioni — che si può tagliare come
# tutti gli altri. È lo stesso trucco degli impostori: il costo lo paghi solo
# per l'albero che stai guardando davvero.
const FOREST_GRAB := 5.0

func _materialize_forest() -> void:
	if _player == null or _cozy == null or _busy:
		return
	if not _cozy.has_method("nearest_forest_tree"):
		return
	var got: Dictionary = _cozy.nearest_forest_tree(_player.global_position, FOREST_GRAB)
	if got.is_empty():
		return
	# lo scambio avviene a 5 metri, ben oltre la portata dell'ascia (2.4):
	# quando Mochi arriva a colpire, l'albero vero è lì da un pezzo
	if not _cozy.take_forest_tree(got["key"], got["index"]):
		return
	var pos: Vector3 = got["pos"]
	var node: Node3D = _cozy.plant_tree(pos, float(got["scale"]) * 0.9, int(pos.x * 31.0 + pos.z * 17.0))
	if node == null:
		return
	var t := _adopt(node)
	if not t.is_empty():
		_trees.append(t)


# ================================================================ prompt

func _build_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_prompt = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.98, 0.94, 0.9)
	sb.set_corner_radius_all(9)
	sb.set_content_margin_all(7)
	sb.shadow_color = Color(0.3, 0.2, 0.15, 0.22)
	sb.shadow_size = 5
	_prompt.add_theme_stylebox_override("panel", sb)
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_prompt)
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 13)
	_prompt_label.add_theme_color_override("font_color", Color("6a4a3a"))
	_prompt.add_child(_prompt_label)


func _update_prompt() -> void:
	if _prompt == null:
		return
	if _busy or _player == null:
		_prompt.visible = false
		return
	_near = nearest_tree(_player.global_position, CHOP_RANGE)
	var cam := get_viewport().get_camera_3d()
	if _near < 0 or cam == null:
		_prompt.visible = false
		return
	var t: Dictionary = _trees[_near]
	# mentre sta cadendo (o ha già dato tutto) non si invita a colpire ancora
	if bool(t["falling"]) or int(t["hp"]) <= 0:
		_prompt.visible = false
		return
	var left: int = int(t["hp"])
	# la scorta è scritta qui: è l'unico momento in cui interessa
	var text := "E — taglia la legna (%d colp%s)   ·   hai %d legna" \
			% [left, "o" if left == 1 else "i", wood]
	_prompt_label.text = text
	_prompt.reset_size()
	var world: Vector3 = (t["root"] as Node3D).global_position + Vector3(0, 1.7, 0)
	if cam.is_position_behind(world):
		_prompt.visible = false
		return
	var p := cam.unproject_position(world)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


## L'albero più vicino entro max_d (indice, o -1).
func nearest_tree(pos: Vector3, max_d: float) -> int:
	var best := -1
	var best_d := max_d
	for i in _trees.size():
		var d: float = pos.distance_to((_trees[i]["root"] as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = i
	return best


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or _busy or _player == null:
		return
	var i := nearest_tree(_player.global_position, CHOP_RANGE)
	if i < 0:
		return
	chop(i)
	get_viewport().set_input_as_handled()


# ================================================================ il colpo

## Un colpo d'ascia sull'albero i. Al terzo, l'albero si abbatte.
func chop(i: int) -> void:
	if _busy or i < 0 or i >= _trees.size():
		return
	var t: Dictionary = _trees[i]
	# solo un albero in piedi e non già condannato
	if bool(t["falling"]) or int(t["hp"]) <= 0:
		return
	_busy = true

	var root: Node3D = t["root"]
	var hit_no: int = HITS_TO_FELL - int(t["hp"]) + 1   # 1, 2, 3

	# al PRIMO colpo si decide da che parte cadrà: lontano da Mochi. Il perno
	# viene imbardato perché la caduta vada proprio lì, e la tacca viene
	# scavata su quel fianco — come fa un boscaiolo vero.
	if hit_no == 1:
		_aim_fall(t)
	if _mochi:
		var to_tree := (root.global_position - _player.global_position) * Vector3(1, 0, 1)
		if to_tree.length() > 0.01:
			var dir := to_tree.normalized()
			_mochi.set("_yaw", atan2(-dir.x, -dir.z))

	# l'ascia sboccia nella zampa mentre il braccio CARICA all'indietro:
	# l'anticipazione è ciò che vende il colpo
	var axe := _make_axe()
	if _mochi:
		_mochi.call("attach_to_paw", axe)
		_mochi.call("hold_swing", true)
		_mochi.set("pour", 0.0)
	# ANATOMIA CHIBI: la testona (0.92 di diametro) si mangia qualunque cosa
	# passi sopra la testa — è la stessa ragione per cui il saluto sventola
	# davanti al petto. Perciò l'ascia è girata VERSO L'ESTERNO.
	axe.rotation.z = PI
	axe.rotation.x = -0.5
	axe.rotation.y = 0.75
	axe.scale = Vector3.ONE * 0.05

	var tw := create_tween()
	# 1) l'ascia appare con un piccolo scatto (1.25: un'ascia da chibi è
	#    tozza e grossa, o a distanza di gioco non si legge)
	tw.tween_property(axe, "scale", Vector3.ONE * 1.25, 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 2) il respiro prima del colpo: più lungo al colpo decisivo
	tw.tween_interval(0.14 if hit_no < HITS_TO_FELL else 0.26)
	# 3) LA FRUSTATA: rapida, con overshoot
	tw.tween_callback(func() -> void:
		if _sfx:
			_sfx.play("swish", -13.0, 0.82))
	tw.tween_property(_mochi, "pour", 1.0, 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(axe, "rotation:x", 0.7, 0.16) \
			.set_trans(Tween.TRANS_SINE)
	# 4) L'IMPATTO
	tw.tween_callback(func() -> void: _impact(t, hit_no))
	# 5) il recupero: l'ascia si stacca dal legno e riposa
	tw.tween_interval(0.34)
	tw.tween_callback(func() -> void:
		if _mochi:
			_mochi.set("pour", 0.35))
	tw.tween_interval(0.16)
	tw.tween_callback(func() -> void:
		if _mochi:
			_mochi.call("hold_swing", false)
		var at := create_tween()
		at.tween_property(axe, "scale", Vector3.ONE * 0.03, 0.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		at.tween_callback(axe.queue_free)
		_busy = false)


# Decide da che parte cadrà l'albero (lontano da Mochi) e prepara il perno e
# la tacca perché tutto guardi da quella parte.
func _aim_fall(t: Dictionary) -> void:
	var root: Node3D = t["root"]
	var away := Vector3(1, 0, 0)
	if _player:
		var v := (root.global_position - _player.global_position) * Vector3(1, 0, 1)
		if v.length() > 0.05:
			away = v.normalized()
	# VERIFICATO A SCHERMO (non sulla fiducia nella matematica): con
	# fall_dir -1 la cima va verso il +x locale del perno, e imbardando il
	# perno quel +x guarda dove vogliamo — cioè lontano da Mochi.
	var want := atan2(-away.z, away.x)
	t["pivot_yaw"] = want - root.global_rotation.y
	t["fall_dir"] = -1.0
	# LA TACCA GUARDA MOCHI. L'albero cade dalla parte opposta (verso -x
	# locale), e nel taglio vero la tacca starebbe da quel lato — ma allora il
	# giocatore non vedrebbe MAI il proprio lavoro, perché resta sempre da
	# questa parte. Il segno del proprio colpo vale più della didattica
	# forestale: longitudine PI = -x locale = il fianco rivolto a Mochi.
	t["notch_dir"] = PI
	_set_tilt(t, float(t["shake_a"]))


func _impact(t: Dictionary, hit_no: int) -> void:
	var root: Node3D = t["root"]
	var spec: Array = t["spec"]
	var size: float = root.scale.x
	# il punto esatto dove morde la lama, sul fianco della tacca
	# le schegge saltano dalla tacca, che sta dal lato di Mochi (+x locale)
	var local_hit := Vector3(-float(spec[1]) * 0.9, float(spec[0]) * NOTCH_T, 0.0)
	var hit_pos: Vector3 = (t["pivot"] as Node3D).to_global(local_hit)

	# il suono morde più a fondo a ogni colpo (tono che scende, corpo che cresce)
	if _sfx:
		_sfx.play("chop", -6.0 + hit_no * 0.8, 1.12 - hit_no * 0.07)

	# LA TACCA: il tronco viene RIGENERATO con il cuneo più profondo
	_carve(t, hit_no)

	# la molla riceve l'impulso: se l'albero vibrava ancora, si SOMMA.
	# Impulsi piccoli: con k=90 anche 1.5 dà già ~9° di scarto, e un albero
	# che sbanda di più sembra di gomma, non di legno
	t["shake_v"] = float(t["shake_v"]) + (0.95 + hit_no * 0.28)
	t["can_v"] = float(t["can_v"]) - (0.5 + hit_no * 0.16)

	_spawn_chips(hit_pos, 8 + hit_no * 3, size)
	_shed_leaves(t, 3 + hit_no * 2)
	_kick_camera(0.32 + 0.1 * hit_no)

	t["hp"] = int(t["hp"]) - 1
	if int(t["hp"]) <= 0:
		# un attimo di sospensione, poi lo scricchiolio e la caduta
		get_tree().create_timer(0.26).timeout.connect(func() -> void: _fell(t))


# ================================================================ la caduta

func _fell(t: Dictionary) -> void:
	if _sfx:
		_sfx.play("creak", -8.0, 1.0)
	t["falling"] = true
	# lo strappo della fibra: l'albero parte già inclinato e con una spinta,
	# poi ci pensa la gravità
	t["fall_a"] = 0.10
	t["fall_v"] = 0.40
	# la chioma perde foglie per tutta la discesa
	_shed_leaves(t, 10)
	get_tree().create_timer(0.5).timeout.connect(func() -> void: _shed_leaves(t, 8))


func _on_tree_landed(t: Dictionary) -> void:
	var root: Node3D = t["root"]
	var size: float = root.scale.x
	var ground: Vector3 = root.global_position

	if _sfx:
		_sfx.play("crash", -3.0, 1.0)
	_kick_camera(1.2)
	_spawn_chips(ground + Vector3(0, 0.16, 0), 16, size)
	_shed_leaves(t, 16)

	# un piccolo rimbalzo del tronco a terra, poi il riposo
	var pivot: Node3D = t["pivot"]
	var bt := create_tween()
	bt.tween_property(pivot, "rotation:z", (1.47 - 0.06) * float(t["fall_dir"]), 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bt.tween_property(pivot, "rotation:z", 1.47 * float(t["fall_dir"]), 0.22) \
			.set_trans(Tween.TRANS_SINE)

	# il ceppo compare, col taglio chiaro e fresco
	var stump: Node3D = t["stump"]
	stump.visible = true
	stump.scale = Vector3(1.1, 0.7, 1.1)
	var st := create_tween()
	st.tween_property(stump, "scale", Vector3.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# poi il tronco caduto si congeda e DONA la legna
	get_tree().create_timer(0.75).timeout.connect(func() -> void: _give_wood(t))


func _give_wood(t: Dictionary) -> void:
	var pivot: Node3D = t["pivot"]
	var root: Node3D = t["root"]

	# il tronco caduto sfuma e si ritira nella terra
	var ft := create_tween()
	ft.tween_property(pivot, "scale", Vector3(0.85, 0.05, 0.85), 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	ft.tween_callback(func() -> void: pivot.visible = false)

	# ...e ne nascono i ceppetti, che volano in un arco verso Mochi
	for k in WOOD_PER_TREE:
		var log_node := _make_log(t["bark"])
		var from: Vector3 = root.global_position \
				+ Vector3(randf_range(-0.5, 0.5), 0.35, randf_range(-0.5, 0.5))
		log_node.position = from
		log_node.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.3, 0.3))
		add_sibling_safe(log_node)
		log_node.scale = Vector3.ONE * 0.2
		var target: Vector3 = from + Vector3(0, 0.9, 0)
		if _player:
			target = _player.global_position + Vector3(0, 1.0, 0)
		var lt := create_tween()
		lt.tween_interval(0.1 * float(k))
		lt.tween_property(log_node, "scale", Vector3.ONE, 0.2) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# l'arco: prima sale, poi scivola nelle Tasche
		lt.tween_property(log_node, "position", from + Vector3(0, 1.1, 0), 0.26) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		lt.parallel().tween_property(log_node, "rotation:x", log_node.rotation.x + TAU, 0.5)
		lt.tween_property(log_node, "position", target, 0.34) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		lt.parallel().tween_property(log_node, "scale", Vector3.ONE * 0.1, 0.34) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		lt.tween_callback(func() -> void:
			log_node.queue_free()
			add_wood(1)
			if _sfx:
				_sfx.play("select", -13.0, 0.9 + 0.06 * float(k)))

	# IL TERRENO TORNA LIBERO. Il ceppo saluta e sprofonda, il nodo se ne va
	# con le sue collisioni: da domani ci si può costruire sopra. Il bosco non
	# ricresce qui — si rimargina altrove (vedi _pay_debt).
	var pos: Vector3 = root.global_position
	_debt.append([_today() + REGROW_DAYS, pos.x, pos.z])
	_felled.append(Vector2(pos.x, pos.z))
	_trees.erase(t)
	var stump: Node3D = t["stump"]
	var qt := create_tween()
	qt.tween_interval(1.6)
	qt.tween_property(stump, "scale", Vector3(0.9, 0.02, 0.9), 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	qt.tween_callback(func() -> void:
		if is_instance_valid(root):
			root.queue_free())
	get_tree().call_group("regista", "note", "legna")
	get_tree().create_timer(1.1).timeout.connect(func() -> void:
		_toast(root.global_position + Vector3(0, 1.0, 0),
				"+%d legna" % WOOD_PER_TREE))


# ================================================================ ricrescita

func _today() -> int:
	if _daynight:
		return int(_daynight.day)
	return 0


func _on_day_changed(_day: int) -> void:
	_pay_debt()


## Il bosco si rimargina: per ogni albero dovuto e scaduto, ne nasce uno
## ALTROVE — mai dove hai tagliato, perché quel terreno ora è tuo.
func _pay_debt() -> void:
	if _debt.is_empty():
		return
	var oggi := _today()
	var restanti := []
	var spots = _build_spots()
	for voce in _debt:
		if int(voce[0]) > oggi:
			restanti.append(voce)
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = oggi * 7919 + int(voce[1] * 13.0) + int(voce[2] * 31.0)
		var p: Vector2 = spots.find_spot(rng, Vector2(float(voce[1]), float(voce[2])))
		if p == Vector2.INF:
			# il mondo è pieno: il debito NON si perde, si riprova domani.
			# Meglio un bosco che aspetta di un pino dentro il salotto.
			restanti.append([oggi + 1, voce[1], voce[2]])
			continue
		_sprout_tree(p)
		# l'albero appena nato conta subito come ostacolo per i prossimi
		spots.trees.append(p)
	_debt = restanti


## Fa nascere un albero nuovo nel punto dato, con lo sboccio elastico.
func _sprout_tree(p: Vector2, animate := true) -> void:
	if _cozy == null or not _cozy.has_method("plant_tree"):
		return
	var size := randf_range(0.85, 1.1)
	var node: Node3D = _cozy.plant_tree(Vector3(p.x, 0.0, p.y), size, randi())
	if node == null:
		return
	var t := _adopt(node)
	if t.is_empty():
		return
	_trees.append(t)
	_planted.append(p)
	if not animate:
		return          # in caricamento gli alberi ci sono e basta
	# lo SBOCCIO: sbuca dalla terra e si assesta con un fremito nella chioma
	var pivot: Node3D = t["pivot"]
	pivot.scale = Vector3(0.25, 0.06, 0.25)
	var gt := create_tween()
	gt.tween_property(pivot, "scale", Vector3.ONE, 0.9) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t["can_v"] = 0.9
	if _sfx:
		_sfx.play("wake", -14.0, 1.15)
	_sparkle(node.global_position + Vector3(0, 1.2, 0), t["leaf"], 10)


## Costruisce il cercatore di posto con TUTTO ciò che oggi occupa il terreno:
## acqua, rilievi, massi, sentiero, radura, costruzioni, abitanti e alberi.
func _build_spots():
	var s = SPOTS.new()
	if _cozy:
		if _cozy.has_method("river_x_at") and _cozy.has_method("cliff_x_at"):
			s.sample_terrain(Callable(_cozy, "river_x_at"), Callable(_cozy, "cliff_x_at"))
		if _cozy.has_method("obstacle_circles"):
			for c in _cozy.obstacle_circles():
				s.block(c.x, c.z, c.y)
		if _cozy.has_method("path_points"):
			s.path = _cozy.path_points()
	# le costruzioni del villaggio: dove c'è un pezzo, non cresce niente
	var build := get_tree().get_first_node_in_group("build_system")
	if build and build.has_method("occupied_spots"):
		for c in build.occupied_spots():
			s.block(c.x, c.z, c.y)
	# gli abitanti (e il giocatore): nessuno si ritrova un tronco in faccia
	for grp in ["villager", "player_controller"]:
		for n in get_tree().get_nodes_in_group(grp):
			if n is Node3D:
				var gp: Vector3 = (n as Node3D).global_position
				s.block(gp.x, gp.z, 2.2)
	# gli alberi che ci sono già
	for t in _trees:
		var tp: Vector3 = (t["root"] as Node3D).global_position
		s.trees.append(Vector2(tp.x, tp.z))
	# e quelli del bosco ancora in piedi
	if _cozy and _cozy.has_method("forest_positions"):
		for fp in _cozy.forest_positions():
			s.trees.append(Vector2(fp.x, fp.z))
	return s


# ================================================================ la legna

## Aggiunge legna alle Tasche.
func add_wood(n: int) -> void:
	wood = maxi(0, wood + n)


## Spende n legna, se c'è. True se il pagamento è andato a buon fine.
func spend_wood(n: int) -> bool:
	if n <= 0:
		return true
	if wood < n:
		return false
	wood -= n
	return true


## Quanta legna costa un pezzo del catalogo (0 = gratis).
func cost_for(piece: String) -> int:
	return int(PIECE_COST.get(piece, 0))


## True se c'è legna a sufficienza per quel pezzo.
func can_afford_piece(piece: String) -> bool:
	return wood >= cost_for(piece)


## Paga il pezzo in legna (chiamata da BuildSystem al piazzamento).
func pay_for_piece(piece: String) -> bool:
	return spend_wood(cost_for(piece))


## Il "no" gentile quando manca la legna: senza una parola, il giocatore
## vede solo il fantasma che trema e non capisce di che cosa ha bisogno.
func deny_toast(piece: String) -> void:
	if _player == null:
		return
	var manca: int = maxi(0, cost_for(piece) - wood)
	_toast(_player.global_position + Vector3(0, 1.9, 0),
			"serve %d legna in più" % manca)


# ================================================================ effetti

# gli oggetti volanti vivono accanto ai sistemi, nel livello
func add_sibling_safe(node: Node3D) -> void:
	var host: Node = get_parent()
	if host == null:
		host = self
	host.add_child(node)


# le schegge: piccoli parallelepipedi chiari che schizzano e cadono
func _spawn_chips(pos: Vector3, n: int, size: float) -> void:
	for i in n:
		var chip := MeshInstance3D.new()
		var m := BoxMesh.new()
		var s: float = randf_range(0.02, 0.055) * size
		m.size = Vector3(s, s * 0.5, s * randf_range(1.0, 2.2))
		chip.mesh = m
		chip.material_override = _cut_mat
		chip.position = pos + Vector3(randf_range(-0.1, 0.1), randf_range(-0.05, 0.12), randf_range(-0.1, 0.1))
		chip.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		add_sibling_safe(chip)
		var away := Vector3(randf_range(-0.8, 0.8), randf_range(0.45, 0.95), randf_range(-0.8, 0.8))
		var apex: Vector3 = chip.position + away
		var down := Vector3(apex.x, 0.03, apex.z)
		var dur := randf_range(0.3, 0.45)
		var tw := create_tween()
		tw.tween_property(chip, "position", apex, dur * 0.45) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(chip, "rotation",
				chip.rotation + Vector3(randf_range(-6, 6), randf_range(-4, 4), randf_range(-6, 6)), dur)
		tw.tween_property(chip, "position", down, dur * 0.55) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_interval(randf_range(0.5, 1.4))
		tw.tween_property(chip, "scale", Vector3.ONE * 0.01, 0.3)
		tw.tween_callback(chip.queue_free)


# le foglie che si staccano: scendono ondeggiando come foglie vere
func _shed_leaves(t: Dictionary, n: int) -> void:
	var canopy: Node3D = t["canopy"]
	if canopy == null or not is_instance_valid(canopy):
		return
	var origin: Vector3 = canopy.global_position
	var col: Color = t["leaf"]
	var mat: ShaderMaterial = CATALOG._mat(col, col.darkened(0.2), 3.0, 0.5, 0.5)
	for i in n:
		var leaf := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = randf_range(0.035, 0.06)
		m.height = m.radius * 2.0
		m.radial_segments = 6
		m.rings = 3
		leaf.mesh = m
		leaf.scale = Vector3(1.5, 0.25, 1.0)
		leaf.material_override = mat
		leaf.position = origin + Vector3(randf_range(-0.7, 0.7), randf_range(-0.35, 0.45), randf_range(-0.7, 0.7))
		leaf.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		add_sibling_safe(leaf)
		# la discesa a zig-zag: due sbandate opposte, come una foglia vera
		var fall_t := randf_range(1.5, 2.6)
		var drift := randf_range(0.5, 1.2) * (1.0 if randf() < 0.5 else -1.0)
		var mid: Vector3 = leaf.position + Vector3(drift, -(leaf.position.y - 0.9), drift * 0.4)
		var end := Vector3(mid.x - drift * 1.3, 0.04, mid.z + drift * 0.5)
		var tw := create_tween()
		tw.tween_property(leaf, "position", mid, fall_t * 0.5).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(leaf, "rotation:z", leaf.rotation.z + drift * 3.0, fall_t * 0.5) \
				.set_trans(Tween.TRANS_SINE)
		tw.tween_property(leaf, "position", end, fall_t * 0.5).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(leaf, "rotation:z", leaf.rotation.z - drift * 2.0, fall_t * 0.5) \
				.set_trans(Tween.TRANS_SINE)
		tw.tween_interval(randf_range(1.0, 2.5))
		tw.tween_property(leaf, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
		tw.tween_callback(leaf.queue_free)


# il ceppetto di legna: due dischi chiari alle estremità di un rullo scuro
func _make_log(bark: Variant) -> Node3D:
	var n := Node3D.new()
	var bark_mat: Material = bark if bark != null else CATALOG._mat(BARK, BARK_DARK, 2.5, 0.55)
	var body := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.075
	m.bottom_radius = 0.075
	m.height = 0.3
	m.radial_segments = 9
	body.mesh = m
	body.material_override = bark_mat
	body.rotation.z = PI * 0.5
	n.add_child(body)
	for side: float in [-1.0, 1.0]:
		var disc := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = 0.073
		dm.bottom_radius = 0.073
		dm.height = 0.02
		dm.radial_segments = 9
		disc.mesh = dm
		disc.material_override = _cut_mat
		disc.rotation.z = PI * 0.5
		disc.position = Vector3(side * 0.155, 0, 0)
		n.add_child(disc)
	return n


# scintille di gioia (ricrescita, doni)
func _sparkle(pos: Vector3, col: Color, n := 8) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in n:
		var s := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = randf_range(0.02, 0.045)
		m.height = m.radius * 2.0
		m.radial_segments = 6
		m.rings = 3
		s.mesh = m
		s.material_override = mat.duplicate()
		s.position = pos
		add_sibling_safe(s)
		var a := TAU * float(i) / float(n) + randf_range(-0.2, 0.2)
		var r := randf_range(0.35, 0.75)
		var to := pos + Vector3(cos(a) * r, randf_range(0.25, 0.7), sin(a) * r)
		var tw := create_tween()
		tw.tween_property(s, "position", to, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "scale", Vector3.ONE * 0.1, 0.6)
		tw.parallel().tween_property(s.material_override, "albedo_color:a", 0.0, 0.6)
		tw.tween_callback(s.queue_free)


# la scritta che sale: "+3 legna"
func _toast(pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 44
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color("6a4a3a")
	l.outline_size = 12
	l.outline_modulate = Color(1, 0.99, 0.95, 0.95)
	l.no_depth_test = true
	l.position = pos
	add_sibling_safe(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 0.85, 1.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)


# ================================================================ l'ascia

# L'ascia di Mochi: manico di legno chiaro, ghiera di corda, testa di ferro
# con il filo lucido. Piccola e tonda, come tutto in questo mondo.
func _make_axe() -> Node3D:
	var axe := Node3D.new()
	var wood_mat: ShaderMaterial = CATALOG._mat(Color("c89a6b"), Color("a87c50"), 5.0, 0.5)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("8f97a3")
	iron.metallic = 0.55
	iron.roughness = 0.35
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color("dfe6ee")
	edge.metallic = 0.7
	edge.roughness = 0.18

	# il manico
	var h1 := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.016
	hm.bottom_radius = 0.019
	hm.height = 0.46
	hm.radial_segments = 8
	h1.mesh = hm
	h1.material_override = wood_mat
	h1.position = Vector3(0, 0.23, 0)
	axe.add_child(h1)
	# il pomello in fondo, perché la zampina non scivoli
	var knob := MeshInstance3D.new()
	var km := SphereMesh.new()
	km.radius = 0.028
	km.height = 0.056
	km.radial_segments = 8
	km.rings = 4
	knob.mesh = km
	knob.material_override = wood_mat
	knob.position = Vector3(0, 0.015, 0)
	axe.add_child(knob)
	# la ghiera di corda sotto la testa
	var ring := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.023
	rm.bottom_radius = 0.023
	rm.height = 0.045
	rm.radial_segments = 8
	ring.mesh = rm
	ring.material_override = CATALOG._mat(ROPE, ROPE.darkened(0.25), 12.0, 0.45)
	ring.position = Vector3(0, 0.4, 0)
	axe.add_child(ring)

	# la testa: un cuneo che si allarga verso il filo
	var head := MeshInstance3D.new()
	var hd := BoxMesh.new()
	hd.size = Vector3(0.055, 0.13, 0.1)
	head.mesh = hd
	head.material_override = iron
	head.position = Vector3(0, 0.47, -0.02)
	axe.add_child(head)
	var blade := MeshInstance3D.new()
	var bl := CylinderMesh.new()   # mezzaluna: un cilindro schiacciato
	bl.top_radius = 0.085
	bl.bottom_radius = 0.085
	bl.height = 0.035
	bl.radial_segments = 12
	blade.mesh = bl
	blade.material_override = edge
	blade.rotation.x = PI * 0.5
	blade.scale = Vector3(1.0, 1.0, 0.62)
	blade.position = Vector3(0, 0.48, -0.09)
	axe.add_child(blade)
	return axe


# ================================================================ salvataggio

func save_extra() -> Dictionary:
	var tagliati := []
	for p in _felled:
		tagliati.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
	var piantati := []
	for p in _planted:
		piantati.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
	return {"legna": wood, "tagliati": tagliati, "debito": _debt.duplicate(true),
			"piantati": piantati}


func load_extra(data: Dictionary) -> void:
	# i salvataggi vecchi (senza la chiave) ricevono la catasta iniziale:
	# non è colpa loro se il boschetto non esisteva ancora
	wood = int(data.get("legna", START_WOOD))
	_debt = (data.get("debito", []) as Array).duplicate(true)
	# ATTENZIONE ALL'ORDINE: BuildSystem carica il villaggio dentro il suo
	# _ready, mentre gli alberi si adottano più tardi (il mondo si costruisce
	# differito su più frame). Senza questa custodia gli alberi abbattuti
	# tornerebbero in piedi a ogni riavvio.
	_pending_rows = [data.get("tagliati", []), data.get("piantati", [])]
	if not _trees.is_empty():
		_apply_rows(_pending_rows)
		_pending_rows = []


func _apply_rows(rows: Array) -> void:
	if rows.size() < 2:
		return
	# 1) gli alberi che erano stati abbattuti non devono ricomparire
	var tagliati: Array = rows[0]
	for riga in tagliati:
		if riga is Array and riga.size() >= 2:
			var p := Vector2(float(riga[0]), float(riga[1]))
			_felled.append(p)
			var i := _tree_at(p)
			if i >= 0:
				var t: Dictionary = _trees[i]
				_trees.remove_at(i)
				(t["root"] as Node3D).queue_free()
	# 2) e quelli nati altrove devono tornare dov'erano
	var piantati: Array = rows[1]
	for riga in piantati:
		if riga is Array and riga.size() >= 2:
			var p := Vector2(float(riga[0]), float(riga[1]))
			if _tree_at(p) < 0:
				_sprout_tree(p, false)


# l'indice dell'albero che sta (quasi) in quel punto, o -1
func _tree_at(p: Vector2) -> int:
	for i in _trees.size():
		var tp: Vector3 = (_trees[i]["root"] as Node3D).global_position
		if Vector2(tp.x - p.x, tp.z - p.y).length() < 0.6:
			return i
	return -1


# ================================================================ verifica CLI

## Quanti alberi tagliabili ci sono nel mondo.
func tree_count() -> int:
	return _trees.size()


## Dove sta l'albero i (per inquadrarlo dalla verifica CLI).
func tree_position(i: int) -> Vector3:
	if i < 0 or i >= _trees.size():
		return Vector3.ZERO
	return (_trees[i]["root"] as Node3D).global_position


## Dove sta la tacca dell'albero i, nel mondo (per inquadrarla dalla verifica
## CLI e per capire subito se guarda dalla parte giusta).
func notch_world_pos(i: int) -> Vector3:
	if i < 0 or i >= _trees.size():
		return Vector3.ZERO
	var t: Dictionary = _trees[i]
	var spec: Array = t["spec"]
	var lon: float = float(t["notch_dir"])
	var r: float = float(spec[1]) * 0.85
	return (t["pivot"] as Node3D).to_global(
			Vector3(cos(lon) * r, float(spec[0]) * NOTCH_T, -sin(lon) * r))


## Radiografia del tronco vivo (verifica CLI): quante superfici ha, che
## materiali, e quanto rientra davvero il raggio nella zona della tacca.
func trunk_debug(i: int) -> String:
	if i < 0 or i >= _trees.size():
		return "albero inesistente"
	var t: Dictionary = _trees[i]
	var trunk: MeshInstance3D = t["trunk"]
	if trunk == null or trunk.mesh == null:
		return "tronco senza mesh"
	var out := "sup=%d visibile=%s scala=%.2f" % [
			trunk.mesh.get_surface_count(), trunk.visible, (t["root"] as Node3D).scale.x]
	out += " mat0=%s mat1=%s" % [
			trunk.get_surface_override_material(0) != null,
			trunk.get_surface_override_material(1) != null]
	out += " override=%s" % (trunk.material_override != null)
	# il raggio minimo alla quota della tacca: se il cuneo c'è, deve rientrare
	var spec: Array = t["spec"]
	var y_notch: float = float(spec[0]) * NOTCH_T
	var rmin := 999.0
	var rmax := 0.0
	for s in trunk.mesh.get_surface_count():
		var vs: PackedVector3Array = trunk.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in vs:
			if absf(v.y - y_notch) < 0.02:
				var r := Vector2(v.x, v.z).length()
				rmin = minf(rmin, r)
				rmax = maxf(rmax, r)
	out += " | alla quota della tacca r=[%.3f..%.3f]" % [rmin, rmax]
	return out


## Quanti alberi devono ancora rinascere altrove (il debito col bosco).
func debt_count() -> int:
	return _debt.size()


## Per i test: paga subito il debito arretrato, senza aspettare i giorni.
func debug_regrow_now() -> void:
	for i in _debt.size():
		_debt[i][0] = _today()
	_pay_debt()


## Colpi ancora necessari per abbattere l'albero i.
func hp_of(i: int) -> int:
	return int(_trees[i]["hp"]) if i >= 0 and i < _trees.size() else -1


## Quante superfici ha il tronco dell'albero i (2 = corteccia + legno del
## taglio: la prova che la tacca è geometria vera e non una toppa).
func trunk_surfaces(i: int) -> int:
	if i < 0 or i >= _trees.size():
		return -1
	var trunk: MeshInstance3D = _trees[i]["trunk"]
	if trunk == null or trunk.mesh == null:
		return -1
	return trunk.mesh.get_surface_count()


## Per i test: abbatte l'albero i all'istante (senza la coreografia).
func debug_fell(i: int) -> void:
	if i < 0 or i >= _trees.size():
		return
	var t: Dictionary = _trees[i]
	t["hp"] = 0
	t["falling"] = false
	_aim_fall(t)
	_set_tilt(t, 1.47)
	_give_wood(t)


## Per i test: finge che siano passati n giorni e paga il debito col bosco.
func debug_advance_days(n: int) -> void:
	for i in _debt.size():
		_debt[i][0] = int(_debt[i][0]) - n
	_pay_debt()
