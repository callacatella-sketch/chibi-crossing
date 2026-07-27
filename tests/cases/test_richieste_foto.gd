extends RefCounted
## Le richieste fotografiche: la Modalità Foto con uno scopo. Headless:
##  • la pesca pesata dei sogni è pura e copre tutte le voci;
##  • le POSIZIONI dei sogni vengono dalle fonti uniche del mondo
##    (CozyWorld/GrandTree/WorldMath): mai coordinate ricopiate a mano;
##  • il giudice dell'inquadratura (motivo_inquadratura) è UNO solo per
##    HUD e scatto: ogni condizione ha il suo motivo, e il quadro giusto
##    dà via libera;
##  • la cornice porta la foto VERA (texture della PNG scattata),
##    proporzioni giuste, legno+chiodo+spago; la nuvoletta-sogno esiste;
##  • al massimo 2 cornici per casa (la più vecchia lascia il chiodo);
##  • persistenza round-trip su file usa-e-getta, MAI sul salvataggio vero;
##  • uno scatto senza sogno in corso non fa nulla (e non esplode);
##  • i contratti: PhotoMode chiama il gruppo, CozyWorld monta il sistema.

const FOTO := "res://scenes/interact/RichiesteFoto.gd"
const PHOTOMODE := "res://scenes/interact/PhotoMode.gd"
const COZY := "res://scenes/world/CozyWorld.gd"
const FILE_PROVA := "user://test_foto_tmp.json"


func run(t) -> void:
	var s: GDScript = load(FOTO)
	t.ok(s != null and s.can_instantiate(), "RichiesteFoto.gd compila")
	if s == null or not s.can_instantiate():
		return

	_test_pesca(t, s)
	_test_luoghi(t, s)
	_test_giudice(t, s)
	_test_cornice(t, s)
	_test_pota(t, s)
	_test_persistenza(t, s)
	_test_scatto_a_vuoto(t, s)
	_test_contratti(t)


func _test_pesca(t, s: GDScript) -> void:
	var ids := {}
	for e in s.RICHIESTE:
		t.ok(float(e["peso"]) > 0.0 and float(e["raggio"]) > 0.0,
				"%s: peso e raggio sensati" % e["id"])
		t.ok(str(e["testo"]).length() > 8, "%s: il sogno ha parole" % e["id"])
		ids[e["id"]] = true
	t.eq(ids.size(), s.RICHIESTE.size(), "gli id dei sogni sono unici")
	t.eq(str(s.pesca_richiesta(0.0)["id"]), str(s.RICHIESTE[0]["id"]),
			"tiro 0 → primo sogno")
	t.eq(str(s.pesca_richiesta(0.9999)["id"]),
			str(s.RICHIESTE[s.RICHIESTE.size() - 1]["id"]), "tiro 1 → ultimo sogno")
	t.ok(int(s.AMICIZIA_MINIMA) >= 1,
			"i sogni nascono solo con un filo d'amicizia")


func _test_luoghi(t, s: GDScript) -> void:
	var cozy: GDScript = load(COZY)
	var albero: GDScript = load("res://scenes/world/GrandTree.gd")
	var math: GDScript = load("res://scenes/world/WorldMath.gd")
	var sent = t.stage(s.new())
	sent._richiesta = {"cx": 3.0, "cz": 4.0}
	t.eq(sent._pos_luogo("falo"), cozy.CLEARING_CENTER,
			"il falò è QUELLO di CozyWorld (fonte unica)")
	t.eq(sent._pos_luogo("stagno"), cozy.POND_CENTER,
			"lo stagno è QUELLO di CozyWorld")
	t.eq(sent._pos_luogo("grande_albero"), albero.POS,
			"il Grande Albero è QUELLO di GrandTree")
	var ponte: Vector3 = sent._pos_luogo("arcobaleno")
	t.almost(ponte.x, math.river_x(cozy.BRIDGE_Z),
			"il ponte sta sul fiume vero (river_x)", 0.001)
	t.almost(ponte.z, float(cozy.BRIDGE_Z), "…alla Z del ponte vero", 0.001)
	t.eq(sent._pos_luogo("stelle"), Vector3(3, 0, 4),
			"le stelle si guardano da casa del sognatore")


func _test_giudice(t, s: GDScript) -> void:
	var cam := t.stage(Camera3D.new()) as Camera3D
	cam.global_position = Vector3(0, 1.2, 5)
	cam.look_at(Vector3.ZERO)
	var luogo := Vector3.ZERO
	var sogn := Vector3(0, 0, 0.5)
	var mochi := Vector3(0.5, 0, 0)

	t.eq(s.motivo_inquadratura(cam, sogn, mochi, luogo, 5.0, true,
			false, false, false, false), "",
			"quadro giusto → via libera allo scatto")
	t.ok(str(s.motivo_inquadratura(cam, sogn, mochi, luogo, 5.0, true,
			true, false, false, false)).contains("sera"),
			"serve la notte → lo dice")
	t.ok(str(s.motivo_inquadratura(cam, sogn, mochi, luogo, 5.0, true,
			false, false, true, false)).contains("arcobaleno"),
			"serve l'arcobaleno → lo dice")
	t.ok(str(s.motivo_inquadratura(cam, Vector3(20, 0, 20), mochi, luogo,
			5.0, true, false, false, false, false)).contains("posto"),
			"sognatore lontano dal luogo → lo dice")
	t.ok(str(s.motivo_inquadratura(cam, Vector3(0, 0, 10), mochi,
			Vector3(0, 0, 10), 5.0, false, false, false, false, false)) \
			.contains("inquadratura"),
			"sognatore alle spalle della camera → fuori quadro")
	t.ok(str(s.motivo_inquadratura(cam, sogn, Vector3(30, 0, 0), luogo,
			5.0, true, false, false, false, false)).contains("posa"),
			"Mochi lontana → chiede la posa")
	cam.global_position = Vector3(0, 1.2, 20)
	t.ok(str(s.motivo_inquadratura(cam, sogn, mochi, luogo, 5.0, false,
			false, false, false, false)).contains("lontano"),
			"camera a 20 metri → troppo lontano")


func _test_cornice(t, s: GDScript) -> void:
	var img := Image.create_empty(320, 180, false, Image.FORMAT_RGB8)
	img.fill(Color(0.6, 0.7, 0.5))
	var cornice: Node3D = s.fai_cornice(img)
	t.stage(cornice)
	var mesh_n := 0
	var foto: MeshInstance3D = null
	for c in cornice.get_children():
		var mi := c as MeshInstance3D
		if mi == null:
			continue
		mesh_n += 1
		if mi.mesh is QuadMesh:
			foto = mi
	t.ok(mesh_n >= 8, "la cornice è un oggetto vero (%d pezzi: legno, chiodo, spago)" % mesh_n)
	t.ok(foto != null, "dentro c'è la foto (quad)")
	if foto:
		var tex := (foto.material_override as StandardMaterial3D).albedo_texture
		t.ok(tex is ImageTexture and tex.get_width() == 320,
				"la texture è la PNG scattata, non un segnaposto")
		var q := foto.mesh as QuadMesh
		t.almost(q.size.y, q.size.x * 180.0 / 320.0,
				"le proporzioni della cornice sono quelle della foto", 0.002)

	var icona: Node3D = s.fai_icona_sogno()
	t.stage(icona)
	var pezzi := 0
	for c in icona.get_children():
		if c is MeshInstance3D:
			pezzi += 1
	t.ok(pezzi >= 8, "la nuvoletta-sogno ha nuvola E macchinetta (%d pezzi)" % pezzi)


func _test_pota(t, s: GDScript) -> void:
	var sent = t.stage(s.new())
	sent._appese = [
		{"nome": "Miele", "png": "a.png", "cx": 0, "cz": 0},
		{"nome": "Miele", "png": "b.png", "cx": 0, "cz": 0},
		{"nome": "Nocciola", "png": "c.png", "cx": 1, "cz": 1},
		{"nome": "Miele", "png": "d.png", "cx": 0, "cz": 0},
	]
	sent._pota_cornici("Miele")
	var mie := 0
	var ha_a := false
	for a in sent._appese:
		if a["nome"] == "Miele":
			mie += 1
			if a["png"] == "a.png":
				ha_a = true
	t.eq(mie, 2, "al massimo 2 cornici per casa")
	t.ok(not ha_a, "la più vecchia lascia il chiodo alla nuova")
	t.eq(sent._appese.size(), 3, "le cornici degli altri non si toccano")


func _test_persistenza(t, s: GDScript) -> void:
	var a = t.stage(s.new())
	a._file = FILE_PROVA
	a._richiesta = {"nome": "Miele", "label": "l'orsetto Miele", "id": "falo",
			"testo": "io e te accanto al falò", "cx": 2.0, "cz": 3.0}
	a._appese = [{"nome": "Miele", "label": "l'orsetto Miele",
			"png": "user://foto_ricordi/inesistente.png", "cx": 2, "cz": 3}]
	a._salva()

	var b = t.stage(s.new())
	b._file = FILE_PROVA
	b._carica()
	t.eq(str(b._richiesta.get("nome", "")), "Miele", "il sogno attivo rinasce")
	t.eq(str(b._richiesta.get("id", "")), "falo", "…con il suo luogo")
	t.eq(b._appese.size(), 0,
			"una cornice senza PNG su disco non rinasce (niente quadri vuoti)")
	DirAccess.remove_absolute(FILE_PROVA)


func _test_scatto_a_vuoto(t, s: GDScript) -> void:
	var sent = t.stage(s.new())
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGB8)
	sent.scatto(img)     # nessun sogno in corso
	sent.scatto(null)    # nemmeno un'immagine
	t.ok(true, "scatti senza sogno non fanno danni")


func _test_contratti(t) -> void:
	var pm := FileAccess.get_file_as_string(PHOTOMODE)
	t.ok(pm.contains("richieste_foto") and pm.contains("scatto"),
			"PhotoMode consegna lo scatto al gruppo richieste_foto")
	var cozy := FileAccess.get_file_as_string(COZY)
	t.ok(cozy.contains("RichiesteFoto.gd"), "CozyWorld monta le richieste foto")
