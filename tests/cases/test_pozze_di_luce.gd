extends RefCounted
## Le pozze di luce dalle finestre. Verifica headless:
##  • il censimento veste ogni finestra di due pozze (una per lato del
##    muro), trova il vetro emissivo e monta le falene;
##  • la finestra rimossa si porta via la sua pozza;
##  • il crepuscolo scivola: notte → intensita sale verso 1 e il vetro
##    si scalda; giorno → tutto rientra;
##  • la direzione del lutto: su una tela sintetica con un sentiero a
##    est, la candela punta a est; su tela vergine punta a sud (zero);
##  • il contratto con lo shader: gli uniform che PozzeDiLuce scrive
##    esistono davvero in pozza_finestra.gdshader;
##  • CozyWorld monta il sistema.

const POZZE := "res://scenes/world/PozzeDiLuce.gd"
const SHADER := "res://shaders/pozza_finestra.gdshader"
const COZY := "res://scenes/world/CozyWorld.gd"


func run(t) -> void:
	var s: GDScript = load(POZZE)
	t.ok(s != null and s.can_instantiate(), "PozzeDiLuce.gd compila")
	if s == null or not s.can_instantiate():
		return

	_test_censimento(t, s)
	_test_crepuscolo(t, s)
	_test_direzione_lutto(t, s)
	_test_contratto_shader(t)
	_test_cablaggio(t)


# una finta "Finestra" del catalogo: muro + vetro emissivo
func _finestra_finta(t) -> Node3D:
	var w := t.stage(Node3D.new()) as Node3D
	var vetro := MeshInstance3D.new()
	vetro.mesh = BoxMesh.new()
	var sm := StandardMaterial3D.new()
	sm.emission_enabled = true
	sm.emission = Color("bfe0f2")
	vetro.material_override = sm
	w.add_child(vetro)
	return w


func _test_censimento(t, s: GDScript) -> void:
	var poz = t.stage(s.new())
	var w1 := _finestra_finta(t)
	var w2 := _finestra_finta(t)
	poz.censisci_finestre([w1, w2])
	t.eq(poz._pozze.size(), 2, "due finestre → due corredi di pozze")

	var voce: Dictionary = poz._pozze[w1.get_instance_id()]
	t.eq((voce["mats"] as Array).size(), 2, "ogni finestra versa su DUE lati")
	t.ok(voce["vetro"] != null, "il vetro emissivo è stato trovato")
	t.ok(voce["falene"] is GPUParticles3D, "le falene sono montate")
	t.ok(not (voce["falene"] as GPUParticles3D).emitting,
			"di giorno le falene riposano")

	# i due quad guardano lati opposti del muro
	var root: Node3D = voce["root"]
	var quads: Array = []
	for c in root.get_children():
		if c is MeshInstance3D:
			quads.append(c)
	t.eq(quads.size(), 2, "due quad-pozza sotto la finestra")
	if quads.size() == 2:
		var za: float = (quads[0] as Node3D).position.z
		var zb: float = (quads[1] as Node3D).position.z
		t.ok(za * zb < 0.0, "le pozze stanno su lati opposti (z %+.2f / %+.2f)"
				% [za, zb])

	# la finestra tolta si porta via la pozza
	poz.censisci_finestre([w1])
	t.eq(poz._pozze.size(), 1, "finestra rimossa → pozza rimossa")
	t.ok(poz._pozze.has(w1.get_instance_id()), "l'altra pozza resta")


func _test_crepuscolo(t, s: GDScript) -> void:
	var poz = t.stage(s.new())
	var w := _finestra_finta(t)
	poz.censisci_finestre([w])
	var voce: Dictionary = poz._pozze[w.get_instance_id()]
	var mat: ShaderMaterial = voce["mats"][0]

	poz.imposta_notte(true)
	for i in 60:
		poz._process(0.25)      # ~15 s di crepuscolo simulato
	var acceso: float = mat.get_shader_parameter("intensita")
	t.ok(acceso > 0.95, "la notte accende le pozze (intensita %.2f)" % acceso)
	var vetro: StandardMaterial3D = voce["vetro"]
	t.ok(vetro.emission.r > vetro.emission.b,
			"la sera il vetro si scalda (ambra, non azzurro)")
	t.ok((voce["falene"] as GPUParticles3D).emitting, "le falene escono la sera")

	poz.imposta_notte(false)
	for i in 60:
		poz._process(0.25)
	var spento: float = mat.get_shader_parameter("intensita")
	t.ok(spento < 0.05, "il giorno spegne le pozze (intensita %.2f)" % spento)
	t.ok(vetro.emission.b > vetro.emission.r,
			"di giorno il vetro torna azzurrino")


func _test_direzione_lutto(t, s: GDScript) -> void:
	# una tela sintetica: sentiero luminoso a EST del centro
	var img := Image.create_empty(64, 64, false, Image.FORMAT_L8)
	for x in range(36, 60):
		for y in range(30, 34):
			img.set_pixel(x, y, Color.WHITE)
	var dir: Vector2 = s.direzione_piu_consumata(img, Vector2(32, 32), 8.0)
	t.ok(dir.x > 0.8 and absf(dir.y) < 0.5,
			"la candela punta verso il sentiero a est (%.2f, %.2f)" % [dir.x, dir.y])

	var vergine := Image.create_empty(64, 64, false, Image.FORMAT_L8)
	var zero: Vector2 = s.direzione_piu_consumata(vergine, Vector2(32, 32), 8.0)
	t.eq(zero, Vector2.ZERO, "tela vergine → nessun sentiero → si va a sud")


func _test_contratto_shader(t) -> void:
	var testo := FileAccess.get_file_as_string(SHADER)
	for u in ["intensita", "lutto", "fase", "calore", "calore_lutto"]:
		t.ok(testo.contains("uniform") and testo.contains(u),
				"pozza_finestra.gdshader dichiara '%s'" % u)
	var sorgente := FileAccess.get_file_as_string(POZZE)
	for u in ["\"intensita\"", "\"lutto\"", "\"fase\""]:
		t.ok(sorgente.contains(u), "PozzeDiLuce scrive l'uniform %s" % u)


func _test_cablaggio(t) -> void:
	var testo := FileAccess.get_file_as_string(COZY)
	t.ok(testo.contains("PozzeDiLuce.gd"), "CozyWorld monta le pozze di luce")
