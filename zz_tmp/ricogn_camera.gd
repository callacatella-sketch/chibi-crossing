extends SceneTree
## ═══════════════════════════════════════════════════════════════════════
## LA RICOGNIZIONE DELLA CAMERA — cosa vede DAVVERO chi gioca.
##
##   CHIBI_RIC=/dove/le/foto ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --script res://zz_tmp/ricogn_camera.gd      # SENZA --headless
##
## Non deduce niente: apre il MainLevel VERO, usa la camera VERA del gioco
## (Player.tscn: CameraPivot + Camera3D a 2,7 m e 3,7 m dietro, fov 50,
## nessuna imbardata) e MISURA in pixel del fotogramma vero (1920×1080: il
## gioco ha `stretch/mode=viewport`, quindi quella è la sua risoluzione
## interna a QUALUNQUE dimensione di finestra).
##
## Fasi:
##   1. la camera, letta dalla scena
##   2. il metro: pixel/metro, e dove cade un vicino sullo schermo
##   3. il corpo in pixel, parte per parte, a cinque distanze e quattro viste
##   4. quanto si sposta un GESTO sullo schermo (px), canale per canale
##   5. la testona tonda: quali rotazioni si vedono e quali no
##   6. le FOTO (scala di riferimento + prima/dopo dei gesti)

const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")

## Le distanze sono da MOCHI (il giocatore), non dalla camera: è la domanda
## che si fa chi progetta («un vicino a sei metri»). La camera sta 4,58 m
## più indietro e più in alto, e quella differenza è metà di questo studio.
const DISTANZE := [2.0, 4.0, 6.0, 9.0, 15.0]
## L'imbardata del rig (guarda −Z): 180° = muso verso la camera.
const VISTE := [["fronte", 180.0], ["trequarti", 135.0], ["profilo", 90.0], ["spalle", 0.0]]

## Il seme del chibi di prova: lo stesso in tutte le misure e in tutte le foto.
const SEME := 7331

var _dove := ""
var _liv: Node = null
var _player: Node3D = null
var _v: Node3D = null          # il vicino di prova (un Visitor vero)
var _scatti := 0
var _testa_px_6m := 0.0


func _init() -> void:
	_go()


# ═══════════════════════════════════════════════════════════════════════
# strumenti
# ═══════════════════════════════════════════════════════════════════════

func _cam() -> Camera3D:
	return get_root().get_camera_3d()


func _dietro(p: Vector3) -> bool:
	return _cam().is_position_behind(p)


func _proj(p: Vector3) -> Vector2:
	return _cam().unproject_position(p)


## Il rettangolo sullo schermo di una mesh: gli otto spigoli del suo AABB,
## proiettati. ⚠️ Sovrastima un po' le forme tonde (l'AABB di una sfera è il
## suo cubo circoscritto): dove il numero conta — il diametro della testa —
## c'è anche la misura ESATTA, presa sull'asse trasverso della camera.
func _bbox(m: MeshInstance3D) -> Rect2:
	var ab := m.get_aabb()
	var xf := m.global_transform
	var r := Rect2()
	var primo := true
	for i in 8:
		var q: Vector3 = xf * (ab.position + Vector3(
				ab.size.x * float(i & 1),
				ab.size.y * float((i >> 1) & 1),
				ab.size.z * float((i >> 2) & 1)))
		if _dietro(q):
			continue
		var s := _proj(q)
		if primo:
			r = Rect2(s, Vector2.ZERO)
			primo = false
		else:
			r = r.expand(s)
	return r


func _unione(a: Rect2, b: Rect2) -> Rect2:
	if a.size == Vector2.ZERO and a.position == Vector2.ZERO:
		return b
	if b.size == Vector2.ZERO and b.position == Vector2.ZERO:
		return a
	return a.merge(b)


## Tutte le mesh sotto un nodo.
func _mesh(n: Node, fuori: Array = []) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		if c in fuori:
			continue
		out.append_array(_mesh(c, fuori))
	return out


## I punti-campione del corpo: gli spigoli dell'AABB di ogni mesh più il suo
## centro. È la nuvola su cui si misura «di quanto si è spostato».
func _nuvola(n: Node) -> PackedVector3Array:
	var out := PackedVector3Array()
	for m in _mesh(n):
		var mi: MeshInstance3D = m
		var ab := mi.get_aabb()
		var xf := mi.global_transform
		out.append(xf * ab.get_center())
		for i in 8:
			out.append(xf * (ab.position + Vector3(
					ab.size.x * float(i & 1),
					ab.size.y * float((i >> 1) & 1),
					ab.size.z * float((i >> 2) & 1))))
	return out


func _scatta(nome: String) -> void:
	if _dove == "":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png(_dove.rstrip("/") + "/" + nome + ".png")
	_scatti += 1


## Uno scatto RITAGLIATO sullo stesso rettangolo per tutta una serie: due
## foto da confrontare devono inquadrare la stessa fetta di schermo, o la
## differenza fra loro è il ritaglio.
func _scatta_ritaglio(nome: String, r: Rect2i) -> void:
	if _dove == "":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	var big := Rect2i(Vector2i.ZERO, img.get_size())
	var rr := r.intersection(big)
	if rr.size.x <= 2 or rr.size.y <= 2:
		return
	img.get_region(rr).save_png(_dove.rstrip("/") + "/" + nome + ".png")
	_scatti += 1


func _metti_yaw(y: float) -> void:
	_v.set("_yaw", y)
	_v.rotation.y = y


## Dove sta il vicino e dove sta Mochi, per una distanza e una vista.
func _posa(d: float, gradi: float) -> void:
	_v.global_position = Vector3.ZERO
	_player.global_position = Vector3(0.0, _player.global_position.y, d)
	_metti_yaw(deg_to_rad(gradi))


func _riga_sep(c := "─") -> String:
	return c.repeat(74)


# ═══════════════════════════════════════════════════════════════════════
# I GRUPPI DEL CORPO — chi è cosa, preso dal rig vero
# ═══════════════════════════════════════════════════════════════════════

## Ritorna nome-del-gruppo → Array[MeshInstance3D]. La classificazione è per
## SOTTOALBERO (i pivot veri del rig: `_head`, `_c_ears`, `_c_arms`,
## `_c_legs`, `_tail_p`, e i nodi del volto dentro il FaceController), non
## per nome di nodo: Godot i nomi li assegna da solo.
func _gruppi() -> Dictionary:
	var testa := _v.get("_head") as Node3D
	var orecchie: Array = _v.get("_c_ears")
	var braccia: Array = _v.get("_c_arms")
	var gambe: Array = _v.get("_c_legs")
	var coda = _v.get("_tail_p")
	var coda_p = _v.get("_tail_tip")
	var faccia = _v.get("_face")

	var occhi_n := []
	var brow_n := []
	var bocca_n := []
	if faccia != null:
		for e in (faccia.get("_eyes") as Array):
			occhi_n.append(e)
		for b in (faccia.get("_brows") as Array):
			brow_n.append(b)
		var mm = faccia.get("_mouths")
		if mm is Dictionary:
			for k in (mm as Dictionary):
				bocca_n.append((mm as Dictionary)[k])
		var mo = faccia.get("_mouth_open_node")
		if mo != null:
			bocca_n.append(mo)

	var g := {"testona": [], "orecchie": [], "occhi": [], "sopracciglia": [],
			"bocca": [], "muso e dettagli": [], "braccia": [], "mani": [],
			"gambe": [], "coda": [], "corpo (vestito)": []}

	var radice := _v.get("_corpo") as Node3D
	if radice == null:
		radice = (_v.get("_vis") as Node3D)
	for m in _mesh(radice):
		var mi: MeshInstance3D = m
		var chi := "corpo (vestito)"
		var n: Node = mi
		var testa_dentro := false
		while n != null and n != radice.get_parent():
			if n in occhi_n:
				chi = "occhi"; break
			if n in brow_n:
				chi = "sopracciglia"; break
			if n in bocca_n:
				chi = "bocca"; break
			if n in orecchie:
				chi = "orecchie"; break
			if n in braccia:
				chi = "braccia"; break
			if n in gambe:
				chi = "gambe"; break
			if n == coda or (coda_p != null and n == coda_p):
				chi = "coda"; break
			if n == testa:
				testa_dentro = true
				break
			n = n.get_parent()
		if chi == "corpo (vestito)" and testa_dentro:
			chi = "muso e dettagli"
		g[chi].append(mi)

	# LA TESTONA è la mesh più grossa fra i dettagli della testa: si prende
	# per VOLUME, non per nome (l'ellissoide _ball(0.4) è dieci volte tutto
	# il resto), e le MANI sono la palla più in basso di ogni braccio.
	var testa_meshes: Array = g["muso e dettagli"]
	var big: MeshInstance3D = null
	var bigv := -1.0
	for m in testa_meshes:
		var ab: AABB = (m as MeshInstance3D).get_aabb()
		var vol := ab.size.x * ab.size.y * ab.size.z
		if vol > bigv:
			bigv = vol
			big = m
	if big != null:
		testa_meshes.erase(big)
		g["testona"] = [big]
	for br in braccia:
		var giu: MeshInstance3D = null
		var giuy := 9999.0
		for m in _mesh(br as Node):
			var c: Vector3 = (m as MeshInstance3D).global_transform \
					* (m as MeshInstance3D).get_aabb().get_center()
			if c.y < giuy:
				giuy = c.y
				giu = m
		if giu != null:
			(g["braccia"] as Array).erase(giu)
			(g["mani"] as Array).append(giu)
	return g


func _bbox_gruppo(ms: Array) -> Rect2:
	var r := Rect2()
	for m in ms:
		r = _unione(r, _bbox(m))
	return r


## Il rettangolo di TUTTO il chibi.
func _bbox_tutto() -> Rect2:
	var radice := _v.get("_corpo") as Node3D
	var r := Rect2()
	for m in _mesh(radice):
		r = _unione(r, _bbox(m))
	return r


# ═══════════════════════════════════════════════════════════════════════
# I CANALI DEL CORPO — un gesto per volta, sul rig congelato
# ═══════════════════════════════════════════════════════════════════════

var _istantanea := {}

func _congela_istantanea() -> void:
	_istantanea.clear()
	var nodi := [_v, _v.get("_vis"), _v.get("_corpo"), _v.get("_head"),
			_v.get("_tail_p"), _v.get("_tail_tip")]
	for a in (_v.get("_c_ears") as Array):
		nodi.append(a)
	for a in (_v.get("_c_arms") as Array):
		nodi.append(a)
	for a in (_v.get("_c_legs") as Array):
		nodi.append(a)
	for n in nodi:
		if n != null and is_instance_valid(n):
			_istantanea[n] = (n as Node3D).transform


func _rimetti() -> void:
	for n in _istantanea:
		if is_instance_valid(n):
			(n as Node3D).transform = _istantanea[n]


## I canali. Ognuno è [nome, ampiezza dichiarata, Callable].
func _canali() -> Array:
	var testa := _v.get("_head") as Node3D
	var vis := _v.get("_vis") as Node3D
	var corpo := _v.get("_corpo") as Node3D
	var orecchie: Array = _v.get("_c_ears")
	var braccia: Array = _v.get("_c_arms")
	var coda = _v.get("_tail_p")
	return [
	["testa · IMBARDATA 44° (la ricevuta di OGGI)", func():
		testa.rotation.y += 0.775],
	["testa · imbardata 90° (il massimo anatomico)", func():
		testa.rotation.y += 1.5708],
	["testa · CENNO (beccheggio) 20°", func():
		testa.rotation.x += 0.349],
	["testa · CAPO INCLINATO (rollio) 20°", func():
		testa.rotation.z += 0.349],
	["orecchie · giù di 25°", func():
		for o in orecchie:
			(o as Node3D).rotation.x += 0.436],
	["braccio · alzato avanti 60°", func():
		(braccia[0] as Node3D).rotation.x -= 1.047],
	["braccia · alzate DI LATO 70° (tutte e due)", func():
		(braccia[0] as Node3D).rotation.z += 1.222
		(braccia[1] as Node3D).rotation.z -= 1.222],
	["busto · piegato avanti 15°", func():
		corpo.rotation.x += 0.262],
	["busto · torsione (imbardata) 25°", func():
		corpo.rotation.y += 0.436],
	["CORPO INTERO · girato di 44°", func():
		vis.rotation.y += 0.775],
	["corpo · un passo di lato (0,40 m)", func():
		_v.global_position += _cam().global_transform.basis.x * 0.40],
	["corpo · saltello (0,15 m in su)", func():
		_v.global_position += Vector3(0, 0.15, 0)],
	["corpo · accovacciato (−15% in altezza)", func():
		corpo.scale.y *= 0.85],
	["coda · colpo di frusta 40°", func():
		if coda != null:
			(coda as Node3D).rotation.y += 0.698],
	]


## Di quanto si sposta il corpo sullo schermo fra la posa di riposo e la
## posa del canale: massimo e mediana della nuvola di punti, in PIXEL del
## fotogramma vero. Torna anche il gruppo che si è mosso di più.
func _spostamento(applica: Callable) -> Dictionary:
	var radice := _v.get("_corpo") as Node3D
	var prima := _nuvola(radice)
	var sp := PackedVector2Array()
	for p in prima:
		sp.append(Vector2(-99999, -99999) if _dietro(p) else _proj(p))
	applica.call()
	_v.force_update_transform()
	var dopo := _nuvola(radice)
	var d := PackedFloat32Array()
	var massimo := 0.0
	for i in mini(sp.size(), dopo.size()):
		if sp[i].x < -90000 or _dietro(dopo[i]):
			continue
		var q := _proj(dopo[i]).distance_to(sp[i])
		d.append(q)
		massimo = maxf(massimo, q)
	_rimetti()
	_v.force_update_transform()
	var arr := Array(d)
	arr.sort()
	var p50 := 0.0 if arr.is_empty() else float(arr[arr.size() / 2])
	var p90 := 0.0 if arr.is_empty() else float(arr[mini(int(arr.size() * 0.9), arr.size() - 1)])
	return {"max": massimo, "p50": p50, "p90": p90}


# ═══════════════════════════════════════════════════════════════════════
# IL GIRO
# ═══════════════════════════════════════════════════════════════════════

func _go() -> void:
	_dove = OS.get_environment("CHIBI_RIC")
	if _dove != "":
		DirAccess.make_dir_recursive_absolute(_dove)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 10:
		await process_frame
	_liv = current_scene
	_player = _liv.get_node_or_null("Player") as Node3D
	var build := _liv.get_node_or_null("BuildSystem")
	var dn := _liv.get_node_or_null("DayNight")
	var visitors := _liv.get_node_or_null("Visitors")
	if _player == null or visitors == null:
		print("GUASTO: MainLevel incompleto")
		quit(1)
		return
	if build != null:
		build.call("set_persist_for_debug", false)
	if dn != null:
		# L'OROLOGIO SI FERMA a metà pomeriggio: fra una foto e l'altra non
		# deve cambiare la luce, o si sta confrontando l'ora.
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	await create_timer(1.5).timeout

	# IL VICINO DI PROVA: un Visitor VERO, ma NON iscritto a `Visitors` —
	# così nessuna routine gli cambia mestiere sotto le foto. Figlio di
	# `Visitors` perché è da lì che `_player_ref` si risolve («../../Player»).
	_v = VS.new()
	_v.species = "chibi"
	_v.dna = DNAG.generate(SEME)
	visitors.add_child(_v)
	_v.set("greet_enabled", false)
	await create_timer(1.2).timeout
	_v.call("_enter_state", "r_idle")
	_v.set("_timer", 99999.0)
	_v.global_position = Vector3.ZERO
	await create_timer(0.6).timeout

	print("")
	print("█".repeat(74))
	print("  LA RICOGNIZIONE DELLA CAMERA — cosa vede DAVVERO chi gioca")
	print("█".repeat(74))
	_f1_camera()
	_f2_metro()
	await _f3_corpo()
	await _f4_gesti()
	await _f5_testona()
	await _f6_foto()
	print("")
	print("  foto: %d%s" % [_scatti, "" if _dove == "" else "  in " + _dove])
	quit(0)


# ── 1 ────────────────────────────────────────────────────────────────────

func _f1_camera() -> void:
	var c := _cam()
	var vp := get_root().get_visible_rect().size
	var f := (vp.y * 0.5) / tan(deg_to_rad(c.fov) * 0.5)
	var av := -c.global_transform.basis.z
	print("")
	print("╔═ 1. LA CAMERA VERA (letta da Player.tscn, non inventata) " + "═".repeat(15))
	print("  nodo:            %s" % c.get_path())
	print("  fotogramma:      %d × %d px  (stretch=viewport: il gioco rende SEMPRE" % [vp.x, vp.y])
	print("                   a questa risoluzione, finestra %s a parte)"
			% str(get_root().size))
	print("  fov:             %.1f° VERTICALI (keep_aspect=KEEP_HEIGHT)" % c.fov)
	print("                   → %.1f° orizzontali" % rad_to_deg(2.0 * atan((vp.x * 0.5) / f)))
	print("  distanza focale: %.1f px  (un metro trasverso a Z metri = %.1f/Z px)" % [f, f])
	print("  posizione:       %.2f m sopra Mochi, %.2f m dietro → %.2f m di distanza"
			% [c.position.y, c.position.z, c.position.length()])
	print("  inclinazione:    %.2f° verso il basso   (avanti = %.3f, %.3f, %.3f)"
			% [rad_to_deg(asin(-av.y)), av.x, av.y, av.z])
	print("  imbardata:       NESSUNA — la camera non si gira mai (CameraPivot fermo)")
	print("  l'unica leva:    FiatoSospeso porta il fov da 50 a 44 tenendo premuto C")
	print("")
	print("  ⚠️  «un vicino a SEI METRI» sono sei metri da MOCHI, ma la camera sta")
	print("     4,58 m più indietro: quel vicino è a ~10,2 m dall'OBIETTIVO. È il")
	print("     +70% di profondità, e su una scala 1/Z è un corpo che rimpicciolisce.")


# ── 2 ────────────────────────────────────────────────────────────────────

func _f2_metro() -> void:
	var c := _cam()
	var vp := get_root().get_visible_rect().size
	var f := (vp.y * 0.5) / tan(deg_to_rad(c.fov) * 0.5)
	print("")
	print("╔═ 2. IL METRO — quanto è lontano, quanto è grande, dove cade " + "═".repeat(12))
	print("  (il vicino è a terra davanti a Mochi; la testa a ~0,64 m dal suolo)")
	print("")
	print("  d da   dist. dalla   profondità   px per metro   il vicino cade a   inclinaz.")
	print("  Mochi    camera      (asse ott.)   (trasversi)     y=… del frame     visuale")
	print("  " + "─".repeat(70))
	for dv in DISTANZE:
		var d := float(dv)
		_posa(d, 180.0)
		await_nulla()
		var piedi := Vector3(0, 0.0, 0)
		var testa := Vector3(0, 0.64, 0)
		var vp_c := c.global_position
		var dist := vp_c.distance_to(testa)
		var prof := (testa - vp_c).dot(-c.global_transform.basis.z)
		var sp := _proj(piedi)
		var st := _proj(testa)
		print("  %5.1f m   %6.2f m     %6.2f m      %6.1f px/m     piedi %4.0f, testa %4.0f   %+5.1f°"
				% [d, dist, prof, f / prof, sp.y, st.y,
				rad_to_deg(atan2(540.0 - st.y, f))])
	print("")
	print("  Nota: il fotogramma è alto 1080 px e il centro è y=540. Il vicino sta")
	print("  SEMPRE nella metà bassa-centrale: la camera è inclinata di 28°, non")
	print("  guarda l'orizzonte.")


func await_nulla() -> void:
	pass


# ── 3 ────────────────────────────────────────────────────────────────────

## Il diametro apparente ESATTO della testa: si proiettano i due punti sul
## bordo, presi sull'asse TRASVERSO della camera (l'AABB sovrastimerebbe).
func _diametro_testa() -> Vector2:
	var g := _gruppi()
	if (g["testona"] as Array).is_empty():
		return Vector2.ZERO
	var m: MeshInstance3D = (g["testona"] as Array)[0]
	var ab := m.get_aabb()
	var xf := m.global_transform
	var centro: Vector3 = xf * ab.get_center()
	var rx := (xf.basis * Vector3(ab.size.x * 0.5, 0, 0)).length()
	var ry := (xf.basis * Vector3(0, ab.size.y * 0.5, 0)).length()
	var c := _cam()
	var dx := _proj(centro + c.global_transform.basis.x * rx) \
			.distance_to(_proj(centro - c.global_transform.basis.x * rx))
	var dy := _proj(centro + c.global_transform.basis.y * ry) \
			.distance_to(_proj(centro - c.global_transform.basis.y * ry))
	return Vector2(dx, dy)


func _f3_corpo() -> void:
	print("")
	print("╔═ 3. IL CORPO IN PIXEL — parte per parte " + "═".repeat(32))
	print("  larghezza × altezza del rettangolo sullo schermo (px del frame 1920×1080)")
	var ordine := ["testona", "orecchie", "occhi", "sopracciglia", "bocca",
			"muso e dettagli", "braccia", "mani", "gambe", "coda", "corpo (vestito)"]
	for vista in VISTE:
		var nome: String = vista[0]
		var gradi: float = vista[1]
		print("")
		print("  ── vista: %s (imbardata %.0f°) ──" % [nome.to_upper(), gradi])
		var intest := "  %-18s" % "parte"
		for d in DISTANZE:
			intest += "%12s" % ("%.0f m" % float(d))
		print(intest)
		print("  " + "─".repeat(72))
		var righe := {}
		var tot := []
		var teste := []
		for dv in DISTANZE:
			_posa(float(dv), gradi)
			await process_frame
			var g := _gruppi()
			for k in ordine:
				if not righe.has(k):
					righe[k] = []
				var r := _bbox_gruppo(g[k])
				(righe[k] as Array).append(r)
			tot.append(_bbox_tutto())
			teste.append(_diametro_testa())
		for k in ordine:
			var riga := "  %-18s" % k
			for r in (righe[k] as Array):
				var rr: Rect2 = r
				if rr.size.x < 0.05 and rr.size.y < 0.05:
					riga += "%12s" % "—"
				else:
					riga += "%12s" % ("%.0f×%.0f" % [rr.size.x, rr.size.y])
			print(riga)
		var riga2 := "  %-18s" % "TUTTO IL CHIBI"
		for r in tot:
			riga2 += "%12s" % ("%.0f×%.0f" % [(r as Rect2).size.x, (r as Rect2).size.y])
		print("  " + "─".repeat(72))
		print(riga2)
		var riga3 := "  %-18s" % "testa (Ø esatto)"
		for t in teste:
			riga3 += "%12s" % ("%.0f×%.0f" % [(t as Vector2).x, (t as Vector2).y])
		print(riga3)
		if nome == "fronte":
			_testa_px_6m = (teste[2] as Vector2).x


# ── 4 ────────────────────────────────────────────────────────────────────

func _f4_gesti() -> void:
	print("")
	print("╔═ 4. QUANTO SI SPOSTA UN GESTO SULLO SCHERMO " + "═".repeat(28))
	print("  Massimo spostamento, in PIXEL, di un punto del corpo fra la posa di")
	print("  riposo e la posa del gesto. Il rig è CONGELATO: un canale per volta.")
	print("  (fra parentesi: quanto vale in % dell'ALTEZZA del chibi sullo schermo")
	print("   — è l'unità che si trasporta da una distanza all'altra)")
	_v.set_process(false)
	await process_frame
	_congela_istantanea()

	for vista in VISTE:
		var nome: String = vista[0]
		var gradi: float = vista[1]
		_posa(6.0, gradi)
		await process_frame
		_congela_istantanea()
		var h := _bbox_tutto().size.y
		print("")
		print("  ── a SEI METRI da Mochi, vista %s (il chibi è alto %.0f px) ──"
				% [nome.to_upper(), h])
		for cc in _canali():
			var d: Dictionary = _spostamento(cc[1] as Callable)
			print("     %-42s  max %6.1f px  (%4.1f%%)   p90 %5.1f px"
					% [str(cc[0]), float(d["max"]),
					100.0 * float(d["max"]) / maxf(h, 1.0), float(d["p90"])])

	print("")
	print("  ── LA STESSA COSA A OGNI DISTANZA (vista FRONTE) ──")
	var intest := "  %-42s" % "canale"
	for d in DISTANZE:
		intest += "%10s" % ("%.0f m" % float(d))
	print(intest)
	print("  " + "─".repeat(72))
	var righe := {}
	var alt := []
	for dv in DISTANZE:
		_posa(float(dv), 180.0)
		await process_frame
		_congela_istantanea()
		alt.append(_bbox_tutto().size.y)
		for cc in _canali():
			var k := str(cc[0])
			if not righe.has(k):
				righe[k] = []
			var d: Dictionary = _spostamento(cc[1] as Callable)
			(righe[k] as Array).append(float(d["max"]))
	for k in righe:
		var riga := "  %-42s" % k
		for x in (righe[k] as Array):
			riga += "%10s" % ("%.1f" % float(x))
		print(riga)
	var riga2 := "  %-42s" % "(altezza del chibi sullo schermo, px)"
	for x in alt:
		riga2 += "%10s" % ("%.0f" % float(x))
	print("  " + "─".repeat(72))
	print(riga2)
	_v.set_process(true)


# ── 5 ────────────────────────────────────────────────────────────────────

func _nuvola_ms(ms: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for m in ms:
		var mi: MeshInstance3D = m
		var ab := mi.get_aabb()
		var xf := mi.global_transform
		out.append(xf * ab.get_center())
		for i in 8:
			out.append(xf * (ab.position + Vector3(
					ab.size.x * float(i & 1),
					ab.size.y * float((i >> 1) & 1),
					ab.size.z * float((i >> 2) & 1))))
	return out


func _max_sp(prima: PackedVector2Array, dopo: PackedVector3Array) -> float:
	var mx := 0.0
	for i in mini(prima.size(), dopo.size()):
		if prima[i].x < -90000 or _dietro(dopo[i]):
			continue
		mx = maxf(mx, _proj(dopo[i]).distance_to(prima[i]))
	return mx


## LA DOMANDA DELLA TESTONA TONDA: di una rotazione della testa, quanto
## arriva allo schermo? Si separa quello che il giocatore vede da lontano
## (la SAGOMA: il contorno di testa+orecchie) da quello che vede solo da
## vicino (i DETTAGLI INTERNI: occhi, sopracciglia, muso, bocca).
func _studio_testa(applica: Callable) -> Dictionary:
	var g := _gruppi()
	var tutte := []
	for k in ["testona", "orecchie", "occhi", "sopracciglia", "bocca", "muso e dettagli"]:
		tutte.append_array(g[k] as Array)
	var interne := []
	for k in ["occhi", "sopracciglia", "bocca", "muso e dettagli"]:
		interne.append_array(g[k] as Array)
	var orecchie: Array = g["orecchie"]
	var sagoma_ms := (g["testona"] as Array).duplicate()
	sagoma_ms.append_array(orecchie)

	var n_tutte := _nuvola_ms(tutte)
	var n_int := _nuvola_ms(interne)
	var n_or := _nuvola_ms(orecchie)
	var p_tutte := PackedVector2Array()
	for p in n_tutte:
		p_tutte.append(Vector2(-99999, -99999) if _dietro(p) else _proj(p))
	var p_int := PackedVector2Array()
	for p in n_int:
		p_int.append(Vector2(-99999, -99999) if _dietro(p) else _proj(p))
	var p_or := PackedVector2Array()
	for p in n_or:
		p_or.append(Vector2(-99999, -99999) if _dietro(p) else _proj(p))
	var sag0 := _bbox_gruppo(sagoma_ms)

	applica.call()
	_v.force_update_transform()
	var out := {
		"tutta": _max_sp(p_tutte, _nuvola_ms(tutte)),
		"interne": _max_sp(p_int, _nuvola_ms(interne)),
		"orecchie": _max_sp(p_or, _nuvola_ms(orecchie)),
	}
	var sag1 := _bbox_gruppo(sagoma_ms)
	out["sagoma"] = absf(sag1.position.x - sag0.position.x) \
			+ absf(sag1.end.x - sag0.end.x) \
			+ absf(sag1.position.y - sag0.position.y) \
			+ absf(sag1.end.y - sag0.end.y)
	out["sag_w"] = sag1.size.x - sag0.size.x
	out["sag_h"] = sag1.size.y - sag0.size.y
	_rimetti()
	_v.force_update_transform()
	return out


func _f5_testona() -> void:
	print("")
	print("╔═ 5. LA TESTONA TONDA — quali rotazioni si vedono " + "═".repeat(23))
	print("  Una sfera che ruota su sé stessa non cambia contorno: quello che")
	print("  arriva allo schermo sono i DETTAGLI che porta addosso, e le")
	print("  ORECCHIE, che sono l'unica parte della testa fuori dall'asse.")
	print("")
	print("  A SEI METRI da Mochi. Tutti i numeri in px del frame 1920×1080.")
	var testa := _v.get("_head") as Node3D
	var rot := [
		["IMBARDATA  20°", func(): testa.rotation.y += 0.349],
		["IMBARDATA  44° (la ricevuta)", func(): testa.rotation.y += 0.775],
		["IMBARDATA  90°", func(): testa.rotation.y += 1.571],
		["BECCHEGGIO 20° (cenno)", func(): testa.rotation.x += 0.349],
		["BECCHEGGIO 44°", func(): testa.rotation.x += 0.775],
		["ROLLIO     20° (capo inclinato)", func(): testa.rotation.z += 0.349],
		["ROLLIO     44°", func(): testa.rotation.z += 0.775],
	]
	_v.set_process(false)
	await process_frame
	for vista in VISTE:
		var nome: String = vista[0]
		_posa(6.0, float(vista[1]))
		await process_frame
		_congela_istantanea()
		print("")
		print("  ── vista %s ──" % nome.to_upper())
		print("     rotazione                       SAGOMA   orecchie   dettagli   tutta")
		print("                                   (contorno)   (punte)   interni    la testa")
		for r in rot:
			var d: Dictionary = _studio_testa(r[1] as Callable)
			print("     %-30s  %6.1f    %6.1f     %6.1f    %6.1f"
					% [str(r[0]), float(d["sagoma"]), float(d["orecchie"]),
					float(d["interne"]), float(d["tutta"])])
	_v.set_process(true)


# ── 6 ────────────────────────────────────────────────────────────────────

func _rett_chibi(margine: float) -> Rect2i:
	var r := _bbox_tutto()
	r = r.grow(margine)
	return Rect2i(Vector2i(floori(r.position.x), floori(r.position.y)),
			Vector2i(ceili(r.size.x), ceili(r.size.y)))


func _f6_foto() -> void:
	print("")
	print("╔═ 6. LE FOTO + il GESTO VERO, misurato frame per frame " + "═".repeat(18))
	_v.set_process(true)
	_v.set("_timer", 99999.0)

	# ── A. LA SCALA DI RIFERIMENTO ──
	for vista in VISTE:
		var nome: String = vista[0]
		for dv in DISTANZE:
			var d := float(dv)
			_posa(d, float(vista[1]))
			_v.call("_enter_state", "r_idle")
			_v.set("_timer", 99999.0)
			await create_timer(0.5).timeout
			await _scatta("scala_%s_%02.0fm" % [nome, d])
			var rr := _rett_chibi(28.0)
			await _scatta_ritaglio("crop_%s_%02.0fm" % [nome, d], rr)

	# ── B. IL GESTO VERO (guarda_gesto), prima/dopo, stesso ritaglio ──
	print("")
	print("  ── il gesto di OGGI (guarda_gesto: la testa si gira per 3,2 s) ──")
	print("     misurato dal vivo: quanto si sposta la testa sullo schermo,")
	print("     in totale e nel fotogramma PEGGIORE (cioè quanto è veloce)")
	print("")
	print("     vista        d      spostamento    px nel frame   px cambiati")
	print("                        totale (px)     più veloce     (dal render)")
	print("     " + "─".repeat(64))
	for vista in VISTE:
		var nome: String = vista[0]
		for dv in [2.0, 6.0, 15.0]:
			var d := float(dv)
			_posa(d, float(vista[1]))
			_v.call("_enter_state", "r_idle")
			_v.set("_timer", 99999.0)
			_v.set("_tst_t", 0.0)
			_v.set("_tst_off", 0.0)
			await create_timer(1.0).timeout
			var rr := _rett_chibi(34.0)
			await _scatta_ritaglio("gesto_%s_%02.0fm_a_prima" % [nome, d], rr)

			# il bersaglio a 90° sulla sinistra del vicino: la testa ci va
			# fino al suo tetto (44°) — è il massimo che il gioco produce
			# IL BERSAGLIO STA A 90° DALLA PARTE DEL CORPO, non in una
			# direzione del mondo: così il gesto è LO STESSO in tutte le
			# viste (la testa gira di 44° rispetto alle spalle) e l'unica
			# cosa che cambia è da dove lo si guarda. Con una direzione
			# fissa del mondo si starebbe confrontando quattro gesti diversi.
			var bers: Vector3 = _v.global_position \
					- _v.global_transform.basis.x * 9.0
			var g := _gruppi()
			var testa_ms := []
			for k in ["testona", "orecchie", "occhi", "sopracciglia", "bocca", "muso e dettagli"]:
				testa_ms.append_array(g[k] as Array)
			var p0 := PackedVector2Array()
			for p in _nuvola_ms(testa_ms):
				p0.append(_proj(p))
			var prec := p0.duplicate()
			var tot := 0.0
			var picco := 0.0
			_v.call("guarda_gesto", bers, 6.0)
			for _i in 130:
				await process_frame
				var ora := PackedVector2Array()
				for p in _nuvola_ms(testa_ms):
					ora.append(_proj(p))
				var mx_tot := 0.0
				var mx_fr := 0.0
				for j in mini(ora.size(), p0.size()):
					mx_tot = maxf(mx_tot, ora[j].distance_to(p0[j]))
					mx_fr = maxf(mx_fr, ora[j].distance_to(prec[j]))
				tot = maxf(tot, mx_tot)
				picco = maxf(picco, mx_fr)
				prec = ora
			await _scatta_ritaglio("gesto_%s_%02.0fm_b_dopo" % [nome, d], rr)
			print("     %-10s %4.0f m    %7.1f        %7.2f          (vedi diff)"
					% [nome, d, tot, picco])
			_v.set("_tst_t", 0.0)
			_v.set("_tst_off", 0.0)
			await create_timer(0.6).timeout
