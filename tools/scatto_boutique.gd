extends SceneTree
## USA E GETTA: la vetrina dei pezzi della boutique, più il negozio
## ALLESTITO — che è la domanda vera: messi insieme si legge un negozio di
## vestiti, o un magazzino con dentro dei bastoni?
##
##   CHIBI_SCATTI=/tmp Godot --path . --resolution 1600x900 \
##       --script res://tools/scatto_boutique.gd

const CAT = preload("res://scenes/build/BuildCatalog.gd")

const FILA_A := ["Vetrina moda", "Insegna boutique", "Camerino", "Scaffale a giorno"]
const FILA_B := ["Stender", "Tavolo piegati", "Manichino", "Busto sartoriale",
		"Specchiera"]
const FILA_C := ["Cassa boutique", "Poltroncina", "Cesto saldi", "Faretti",
		"Passatoia", "Sacchetti"]

var _per_nome := {}


static func _dir() -> String:
	var d := OS.get_environment("CHIBI_SCATTI")
	return (d.rstrip("/") + "/") if d != "" else OS.get_user_data_dir() + "/"


func _init() -> void:
	_go()


func _pezzo(nome: String) -> Node3D:
	return (_per_nome[nome]["builder"] as Callable).call()


func _metti(dove: Node3D, nome: String, pos: Vector3, giro := 0.0) -> Node3D:
	var p := _pezzo(nome)
	p.position = pos
	p.rotation.y = giro
	dove.add_child(p)
	return p


func _scatta(cam: Camera3D, da: Vector3, a: Vector3, file: String) -> void:
	cam.global_position = da
	cam.look_at(a, Vector3.UP)
	# ASPETTARE `frame_post_draw`, NON i process_frame. La texture della
	# finestra è quella dell'ULTIMO frame disegnato: con i soli
	# process_frame due scatti di fila salvavano due volte la stessa
	# immagine — quella della camera PRECEDENTE. Si guardava una foto
	# credendo fosse un'altra inquadratura, ed è il modo più veloce di
	# «verificare» una cosa senza averla vista.
	for _i in 3:
		await process_frame
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_dir() + file)
	print("SHOT ", file)


func _go() -> void:
	await process_frame
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.90, 0.93, 0.96)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.84, 0.87, 0.93)
	e.ambient_light_energy = 0.8
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -36, 0)
	sun.light_energy = 1.05
	root.add_child(sun)
	var suolo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	suolo.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.80, 0.83, 0.72)
	suolo.material_override = sm
	root.add_child(suolo)

	for v in CAT.items():
		_per_nome[str(v["name"])] = v

	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true

	# --- 1. le tre file dei pezzi, uno accanto all'altro ---
	for coppia in [[FILA_A, 1.9, 1.5, "boutique_a.png"],
			[FILA_B, 1.5, 1.2, "boutique_b.png"],
			[FILA_C, 1.3, 1.0, "boutique_c.png"]]:
		var fila := Node3D.new()
		root.add_child(fila)
		var lista: Array = coppia[0]
		var passo: float = coppia[1]
		var x := 0.0
		for nome in lista:
			_metti(fila, str(nome), Vector3(x, 0, 0), 0.0)
			x += passo
		await create_timer(0.6).timeout
		var cx := (x - passo) * 0.5
		await _scatta(cam, Vector3(cx, float(coppia[2]), -5.4),
				Vector3(cx, float(coppia[2]) * 0.6, 0), str(coppia[3]))
		fila.queue_free()
		await process_frame

	# --- 2. IL NEGOZIO ALLESTITO ---
	var neg := Node3D.new()
	root.add_child(neg)
	# il pavimento di assi
	for ix in range(-2, 3):
		for iz in range(-2, 3):
			_metti(neg, "Pavimento", Vector3(float(ix), 0, float(iz)))
	# la strada davanti: le vetrine e l'insegna sopra l'ingresso
	_metti(neg, "Vetrina moda", Vector3(-1.5, 0, -2.5))
	_metti(neg, "Vetrina moda", Vector3(-0.5, 0, -2.5))
	_metti(neg, "Vetrina moda", Vector3(1.5, 0, -2.5))
	_metti(neg, "Porta", Vector3(0.5, 0, -2.5))
	_metti(neg, "Insegna boutique", Vector3(0.5, 0, -2.5))
	# i muri di fianco e lo scaffale in fondo
	for iz2 in [-1.5, -0.5, 0.5, 1.5]:
		_metti(neg, "Muro", Vector3(-2.5, 0, float(iz2)), PI * 0.5)
		_metti(neg, "Muro", Vector3(2.5, 0, float(iz2)), PI * 0.5)
	# lo scaffale guarda DENTRO il negozio: il fronte dei pezzi è -Z, e
	# girarlo di PI mette la merce contro il muro
	for ix2 in [-1.0, 0.0, 1.0]:
		_metti(neg, "Scaffale a giorno", Vector3(float(ix2), 0, 2.5), 0.0)
	# l'arredo
	_metti(neg, "Camerino", Vector3(-1.9, 0, 1.6))
	_metti(neg, "Specchiera", Vector3(-0.7, 0, 1.5))
	_metti(neg, "Poltroncina", Vector3(-1.9, 0, 0.3), 0.5)
	_metti(neg, "Stender", Vector3(0.1, 0, 0.4))
	_metti(neg, "Manichino", Vector3(-1.2, 0, -1.0))
	_metti(neg, "Tavolo piegati", Vector3(1.4, 0, -0.5))
	_metti(neg, "Cesto saldi", Vector3(0.9, 0, -1.5))
	_metti(neg, "Cassa boutique", Vector3(1.9, 0, 1.1), -PI * 0.5)
	_metti(neg, "Busto sartoriale", Vector3(1.9, 0, 2.1))
	_metti(neg, "Faretti", Vector3(-1.9, 0, -1.6))
	_metti(neg, "Passatoia", Vector3(0.5, 0, -1.6))
	_metti(neg, "Passatoia", Vector3(0.5, 0, -0.6))
	_metti(neg, "Sacchetti", Vector3(0.2, 0, -1.9), 0.6)
	await create_timer(0.9).timeout

	await _scatta(cam, Vector3(0.3, 1.7, -6.4), Vector3(0.3, 1.1, -2.2),
			"negozio_fronte.png")
	await _scatta(cam, Vector3(-4.6, 2.4, -5.6), Vector3(0.2, 1.0, -1.4),
			"negozio_trequarti.png")
	await _scatta(cam, Vector3(-5.6, 1.3, 0.4), Vector3(0.2, 0.9, -0.2),
			"negozio_profilo.png")
	await _scatta(cam, Vector3(0.4, 1.25, -1.9), Vector3(0.0, 0.95, 1.6),
			"negozio_dentro.png")
	await _scatta(cam, Vector3(-1.5, 1.15, -3.35), Vector3(-1.5, 1.0, -2.5),
			"negozio_vetrina.png")
	neg.queue_free()
	await process_frame

	# --- 3. i primi piani: il capo appeso, la pila, l'insegna ---
	var det := Node3D.new()
	root.add_child(det)
	_metti(det, "Stender", Vector3(0, 0, 0))
	_metti(det, "Tavolo piegati", Vector3(1.6, 0, 0))
	_metti(det, "Manichino", Vector3(-1.5, 0, 0))
	await create_timer(0.6).timeout
	await _scatta(cam, Vector3(0.0, 0.95, -1.05), Vector3(0.0, 0.85, 0),
			"dettaglio_capi.png")
	await _scatta(cam, Vector3(-1.5, 0.95, -1.0), Vector3(-1.5, 0.75, 0),
			"dettaglio_manichino.png")
	await _scatta(cam, Vector3(-2.55, 0.85, 0.0), Vector3(-1.5, 0.72, 0.0),
			"dettaglio_profilo.png")
	await _scatta(cam, Vector3(1.55, 0.95, -0.85), Vector3(1.6, 0.66, 0),
			"dettaglio_pila.png")
	det.queue_free()
	await process_frame

	var ins := Node3D.new()
	root.add_child(ins)
	_metti(ins, "Insegna boutique", Vector3(0, 0, 0))
	_metti(ins, "Cassa boutique", Vector3(1.7, 0, 0))
	_metti(ins, "Cesto saldi", Vector3(2.8, 0, 0))
	await create_timer(0.5).timeout
	await _scatta(cam, Vector3(0, 1.86, -1.5), Vector3(0, 1.86, 0), "dettaglio_insegna.png")
	await _scatta(cam, Vector3(1.7, 1.05, -1.5), Vector3(1.7, 0.62, 0),
			"dettaglio_cassa.png")
	await _scatta(cam, Vector3(2.8, 0.95, -1.3), Vector3(2.8, 0.45, 0),
			"dettaglio_cesto.png")
	quit()
