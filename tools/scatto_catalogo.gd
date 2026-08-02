extends SceneTree
## IL CATALOGO VISIVO: tre foto di ogni singolo pezzo costruibile del gioco.
##
## Per ogni asset — fronte, tre quarti, profilo — dentro una cartella sua:
##   docs/catalogo/<n-categoria>/<nome-pezzo>/1-fronte.png ecc.
##
##   CHIBI_CATALOGO=docs/catalogo Godot --path . \
##       --script res://tools/scatto_catalogo.gd
##
## Facoltativi: CHIBI_DA / CHIBI_A (indici, per lavorare a lotti se una
## sessione lunga si pianta), CHIBI_LATO (lato dell'immagine in pixel).
##
## DUE COSE CHE SEMBRANO DETTAGLI E NON LO SONO:
##
##  · SI RENDERIZZA IN UN SubViewport, non nella finestra. La finestra su
##    macOS non rispetta `--resolution` (chiede 1600x900 e ne dà 1920x1080,
##    o 2880x1800 su schermo retina): un catalogo con le immagini di
##    misure diverse non è un catalogo. Il SubViewport ha la misura che
##    gli dici, sempre, su qualunque macchina.
##  · L'INQUADRATURA SI CALCOLA, non si indovina. I pezzi vanno da un
##    fungo di dieci centimetri a un campanile di due metri e mezzo: una
##    camera fissa lascerebbe metà catalogo in un puntino e l'altra metà
##    fuori fuoco. Si misura l'ingombro vero delle mesh e si arretra
##    quanto basta perché il pezzo riempia sempre la stessa frazione di
##    inquadratura.

const CAT = preload("res://scenes/build/BuildCatalog.gd")
const DNA = preload("res://scenes/npc/ChibiDNA.gd")
const CHIBI = preload("res://scenes/npc/ChibiBuilder.gd")

## Le tre viste. L'azimut è misurato da -Z (il FRONTE dei pezzi in questo
## catalogo, vedi BuildBoutique) verso +X.
const VISTE := [
	{"file": "1-fronte.png", "az": 0.0},
	{"file": "2-tre-quarti.png", "az": 0.785398},
	{"file": "3-profilo.png", "az": 1.570796},
]
const FOV := 34.0
## ~23°. A 17° si vedeva solo la FACCIA di ogni pezzo: e i pezzi bassi e
## larghi — il letto, il tavolo, la panca — di faccia sono una tavola di
## legno e basta, indistinguibili l'uno dall'altro. Da qui si vede anche
## il piano di sopra (il piumone rosa del letto, i piatti sul tavolo) ed
## è quello che dice cos'è la cosa. È l'angolo delle foto dei cataloghi.
const ELEVAZIONE := 0.42
const NOMI_CAT := ["0-struttura", "1-arredo", "2-giardino", "3-palestra",
		"4-chiesa", "5-boutique"]

var _sv: SubViewport
var _cam: Camera3D
var _scena: Node3D
var _manifesto: Array = []


func _init() -> void:
	_go()


static func _radice() -> String:
	var d := OS.get_environment("CHIBI_CATALOGO")
	return (d.rstrip("/") + "/") if d != "" else "docs/catalogo/"


## Il nome di cartella: minuscolo, senza accenti, spazi in trattini. Le
## cartelle con gli accenti e gli spazi esistono, ma un catalogo si apre
## anche da riga di comando e si mette anche su una pagina web.
static func slug(nome: String) -> String:
	var s := nome.to_lower()
	for coppia in [["à", "a"], ["á", "a"], ["è", "e"], ["é", "e"], ["ì", "i"],
			["í", "i"], ["ò", "o"], ["ó", "o"], ["ù", "u"], ["ú", "u"]]:
		s = s.replace(str(coppia[0]), str(coppia[1]))
	var fuori := ""
	for i in s.length():
		var c := s[i]
		if c in "abcdefghijklmnopqrstuvwxyz0123456789":
			fuori += c
		elif c == " " or c == "-" or c == "_":
			fuori += "-"
	while fuori.contains("--"):
		fuori = fuori.replace("--", "-")
	return fuori.strip_edges().trim_prefix("-").trim_suffix("-")


## L'ingombro conta solo le mesh CHE SI VEDONO. Un chibi si porta dietro
## la nuvoletta del parlato e altra roba tenuta nascosta: contandola,
## l'inquadratura si allargava al doppio dell'altezza vera e il
## personaggio finiva piccolo in un angolo, con mezza foto di vuoto sopra.
func _mesh_aabb(n: Node, radice: Node3D) -> Array:
	var out: Array = []
	if n is Node3D and not (n as Node3D).visible:
		return out
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var tr := Transform3D.IDENTITY
		var cur := n as Node3D
		while cur != null and cur != radice:
			tr = cur.transform * tr
			cur = cur.get_parent() as Node3D
		out.append(tr * (n as MeshInstance3D).mesh.get_aabb())
	for f in n.get_children():
		out.append_array(_mesh_aabb(f, radice))
	return out


func _ingombro(n: Node3D) -> AABB:
	var tutti := _mesh_aabb(n, n)
	if tutti.is_empty():
		return AABB(Vector3(-0.3, 0, -0.3), Vector3(0.6, 0.6, 0.6))
	var out: AABB = tutti[0]
	for i in range(1, tutti.size()):
		out = out.merge(tutti[i])
	return out


func _studio() -> void:
	var lato := int(OS.get_environment("CHIBI_LATO")) if OS.get_environment("CHIBI_LATO") != "" else 900
	_sv = SubViewport.new()
	_sv.size = Vector2i(lato, lato)
	_sv.transparent_bg = false
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.msaa_3d = Viewport.MSAA_4X
	root.add_child(_sv)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.885, 0.895, 0.90)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.86, 0.88, 0.93)
	e.ambient_light_energy = 0.85
	env.environment = e
	_sv.add_child(env)

	# la chiave, con l'ombra: senza, ogni pezzo galleggia
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-42, -38, 0)
	sole.light_energy = 0.85
	sole.shadow_enabled = true
	_sv.add_child(sole)
	# e una schiarita da dietro, per staccare la sagoma dal fondo
	var contro := DirectionalLight3D.new()
	contro.rotation_degrees = Vector3(-16, 148, 0)
	contro.light_energy = 0.22
	_sv.add_child(contro)

	# il piano è ENORME di proposito: piccolo, il suo bordo entra
	# nell'inquadratura dei pezzi grossi e il fondo diventa una striscia di
	# cielo a metà foto — in un catalogo si vede subito
	var suolo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	suolo.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.74, 0.755, 0.735)
	sm.roughness = 0.96
	suolo.material_override = sm
	_sv.add_child(suolo)

	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.current = true
	_sv.add_child(_cam)


func _scatta(a: AABB, az: float, dove: String) -> void:
	var centro := a.position + a.size * 0.5
	var dir := Vector3(sin(az), ELEVAZIONE, -cos(az)).normalized()

	# ============================================================
	# L'INQUADRATURA SI CALCOLA SUGLI OTTO SPIGOLI, non sul centro
	# ============================================================
	# Misurare quanto è largo il pezzo e arretrare in proporzione sembra
	# giusto e non lo è: quella misura vale sul PIANO DEL CENTRO, mentre
	# la faccia davanti sta mezza profondità PIÙ VICINA — e in
	# prospettiva, più vicino vuol dire più grande. Il Letto (fondo un
	# metro) usciva così: una parete di legno da bordo a bordo, con la
	# camera che credeva di avere il dodici per cento d'aria.
	#
	# La regola esatta invece è semplice, perché arretrando lungo l'asse
	# le distanze LATERALI degli spigoli non cambiano: per ogni spigolo
	# serve profondità >= scostamento / tan(mezzo campo), e basta prendere
	# l'arretramento più grande che chiedono gli otto. Una passata sola, e
	# vale per qualunque forma e qualunque angolo.
	var t := tan(deg_to_rad(FOV * 0.5))
	var dist := maxf(a.size.length(), 0.2)         # una partenza qualunque
	var pos := centro + dir * dist
	var fwd := (centro - pos).normalized()
	var destra := fwd.cross(Vector3.UP).normalized()
	var su := destra.cross(fwd).normalized()
	var arretra := 0.0
	for ix in 2:
		for iy in 2:
			for iz in 2:
				var ang := a.position + Vector3(a.size.x * float(ix),
						a.size.y * float(iy), a.size.z * float(iz))
				var v := ang - pos
				var scarto: float = maxf(absf(v.dot(destra)), absf(v.dot(su)))
				arretra = maxf(arretra, scarto / t - v.dot(fwd))
	dist = (dist + arretra) * 1.06                 # un filo d'aria intorno
	_cam.position = centro + dir * dist
	_cam.look_at(centro, Vector3.UP)
	# DUE `frame_post_draw`, NON UNO. La texture di un SubViewport è quella
	# dell'ultimo frame COMPLETATO: con una attesa sola si salva
	# l'inquadratura PRECEDENTE. Il difetto è vigliacco perché quasi non si
	# vede — due pose vicine dello stesso pezzo si somigliano — e si
	# smaschera solo quando due pezzi di seguito sono di taglia diversa: il
	# Letto, fotografato con la distanza dello Sgabello, era un muro
	# marrone. Un catalogo di 399 foto sbagliate di un frame è un catalogo
	# che mente su ogni pagina.
	for _i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _sv.get_texture().get_image()
	img.save_png(dove)


func _go() -> void:
	await process_frame
	_studio()
	var radice := _radice()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://") + radice)

	var pezzi := CAT.items()
	var da := int(OS.get_environment("CHIBI_DA")) if OS.get_environment("CHIBI_DA") != "" else 0
	var a := int(OS.get_environment("CHIBI_A")) if OS.get_environment("CHIBI_A") != "" else pezzi.size()
	print("CATALOGO ", pezzi.size(), " pezzi, lotto ", da, "..", a)

	for i in range(da, mini(a, pezzi.size())):
		var voce: Dictionary = pezzi[i]
		var nome := str(voce["name"])
		var cat := int(voce.get("cat", 0))
		var cartella: String = radice \
				+ str(NOMI_CAT[clampi(cat, 0, NOMI_CAT.size() - 1)]) \
				+ "/" + slug(nome) + "/"
		DirAccess.make_dir_recursive_absolute(
				ProjectSettings.globalize_path("res://") + cartella)
		var nodo = (voce["builder"] as Callable).call()
		if nodo == null:
			print("VUOTO ", nome)
			continue
		_sv.add_child(nodo)
		await process_frame
		var ing := _ingombro(nodo)
		for v in VISTE:
			await _scatta(ing, float(v["az"]),
					ProjectSettings.globalize_path("res://") + cartella + str(v["file"]))
		print("FATTO [", i, "] ", nome, "  ->  ", cartella)
		_manifesto.append({"nome": nome, "cat": cat, "slug": slug(nome),
				"cartella": cartella, "tipo": str(voce.get("type", "cell")),
				"alto": snappedf(ing.size.y, 0.01), "largo": snappedf(ing.size.x, 0.01)})
		nodo.queue_free()
		await process_frame

	# --- i personaggi: i cinque archetipi dei chibi ---
	if a >= pezzi.size():
		for k in DNA.ARCHETYPES.size():
			var arche := str(DNA.ARCHETYPES[k])
			var dna: Dictionary = DNA.generate(4_000 + k * 37)
			dna["archetype"] = arche
			var costr: Dictionary = CHIBI.build(dna)
			var rig = costr.get("root")
			if rig == null:
				continue
			var cartella2 := radice + "6-personaggi/" + slug(arche) + "/"
			DirAccess.make_dir_recursive_absolute(
					ProjectSettings.globalize_path("res://") + cartella2)
			_sv.add_child(rig)
			await process_frame
			var ing2 := _ingombro(rig)
			for v2 in VISTE:
				await _scatta(ing2, float(v2["az"]),
						ProjectSettings.globalize_path("res://") + cartella2 + str(v2["file"]))
			print("FATTO [chibi] ", arche, "  ->  ", cartella2)
			_manifesto.append({"nome": arche.capitalize(), "cat": 6,
					"slug": slug(arche), "cartella": cartella2, "tipo": "chibi",
					"alto": snappedf(ing2.size.y, 0.01),
					"largo": snappedf(ing2.size.x, 0.01)})
			rig.queue_free()
			await process_frame

	# IL MANIFESTO SI FONDE, non si sovrascrive: il catalogo si fa a lotti
	# (una sessione lunga di rendering ogni tanto si chiude da sola a metà
	# strada), e un lotto che cancella le voci degli altri lascerebbe un
	# indice che elenca dieci pezzi su centotrenta.
	var vecchie: Array = []
	if FileAccess.file_exists("res://" + radice + "manifesto.json"):
		var testo := FileAccess.get_file_as_string("res://" + radice + "manifesto.json")
		var letto = JSON.parse_string(testo)
		if letto is Array:
			vecchie = letto
	var per_nome := {}
	for v in vecchie:
		per_nome[str((v as Dictionary).get("nome", ""))] = v
	for v in _manifesto:
		per_nome[str((v as Dictionary).get("nome", ""))] = v
	var fuse: Array = []
	for k in per_nome:
		fuse.append(per_nome[k])
	fuse.sort_custom(func(a, b): return int(a["cat"]) * 1000 + str(a["nome"]).length() \
			< int(b["cat"]) * 1000 + str(b["nome"]).length())
	var f := FileAccess.open("res://" + radice + "manifesto.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(fuse, "  "))
		f.close()
	print("MANIFESTO ", fuse.size(), " voci (", _manifesto.size(), " da questo lotto)")
	quit()
