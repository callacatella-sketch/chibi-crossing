extends SceneTree
## IL PROVINO DELLA SOSTA — una seduta durava trenta millisecondi, adesso ne
## dura quindici secondi. **Quindici secondi si guardano.**
##
## La suite non dice niente sulla resa, e questo cambiamento e' di resa prima
## che di meccanica: prima il corpo toccava la panchina e rimbalzava via in
## due fotogrammi (un difetto che nessuno vedeva perche' durava meno di un
## battito di ciglia), adesso ci sta. Tre cose da guardare, e solo la terza
## e' nuova:
##
##  1. **LA PELLICOLA DELLA SOSTA** — arrivo, assestamento, quindici secondi
##     di posa, discesa. Di profilo e di tre quarti, perche' e' li' che si
##     smascherano i trucchi (una posa che sta in piedi solo di fronte).
##  2. **DUE ACCANTO** — che e' la scena che l'insieme esiste per produrre:
##     due chibi sui due sgabelli di un Gazebo, a 95 cm. Si guarda che non si
##     compenetrino e che si leggano come due persone, non come un mucchio.
##  3. **IL SALUTO DA SEDUTI** — la riga in dubbio. Diverse recite del saluto
##     aggiungono un `vy` (il saltello): su un corpo IN PIEDI e' gioia, su un
##     corpo SEDUTO potrebbe essere un corpo che rimbalza dentro il legno.
##     Si guarda affiancato: fermo / che saluta.
##
##   CHIBI_SOSTA=<cartella>  dove mettere le foto (senza, non si scatta)
##   Godot --path . --resolution 1280x720 --script res://tools/provino_sosta.gd
##
## ⚠️ **SENZA `--headless`**: non c'e' niente da guardare in un rendering che
## non avviene.

const VISITOR := preload("res://scenes/npc/Visitor.gd")
const CATALOGO := preload("res://scenes/build/BuildCatalog.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")


## IL PEZZO VERO, costruito dal suo builder di catalogo — non un cubo con
## l'altezza indovinata. Un provino su una geometria finta risponde a una
## domanda che nessuno si fa.
static func _pezzo(nome: String) -> Node3D:
	for it in CATALOGO.items():
		if str(it.get("name", "")) == nome:
			return (it["builder"] as Callable).call() as Node3D
	return null

var _dove := ""
var _n := 0


func _init() -> void:
	_go()


func _scatta(nome: String) -> void:
	if _dove == "":
		return
	await process_frame
	await process_frame
	var img := get_root().get_texture().get_image()
	_n += 1
	img.save_png("%s/%02d_%s.png" % [_dove, _n, nome])
	print("   → %02d_%s.png" % [_n, nome])


func _corpo(radice: Node3D, seme: int, dove: Vector3) -> Node3D:
	var v = VISITOR.new()
	v.species = "chibi"
	v.mode = "resident"
	v.dna = DNA.generate(seme)
	radice.add_child(v)
	v.position = dove
	return v


func _go() -> void:
	_dove = OS.get_environment("CHIBI_SOSTA")
	if _dove != "":
		DirAccess.make_dir_recursive_absolute(_dove)

	var radice := Node3D.new()
	get_root().add_child(radice)

	# la luce del villaggio, in piccolo: una direzionale calda e un ambiente
	var luce := DirectionalLight3D.new()
	luce.rotation_degrees = Vector3(-42, -35, 0)
	luce.light_energy = 1.5
	luce.light_color = Color(1.0, 0.96, 0.9)
	radice.add_child(luce)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.76, 0.58)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.78, 0.85)
	e.ambient_light_energy = 0.9
	env.environment = e
	radice.add_child(env)
	var suolo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	suolo.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.62, 0.36)
	suolo.material_override = mat
	radice.add_child(suolo)

	var cam := Camera3D.new()
	radice.add_child(cam)
	cam.current = true

	# IL PEZZO VERO, non un cubo: la panchina del catalogo, con la sua altezza
	var panca: Node3D = _pezzo("Panchina")
	radice.add_child(panca)
	panca.position = Vector3.ZERO

	var v := _corpo(radice, 7717, Vector3(0, 0, 2.6))
	await process_frame
	await process_frame

	# ---------- 1) LA PELLICOLA ----------
	print("1 · la pellicola della sosta")
	v.call("do_routine", "bench", Vector3(0, 0, 0.8), Vector3.ZERO, panca)
	var tappe := {0.0: "arrivo", 1.2: "in_cammino", 2.6: "si_siede",
			3.4: "assestamento", 8.0: "posa_meta", 15.0: "posa_lunga"}
	var t := 0.0
	# ⚠️ **DA VICINO.** La prima stesura guardava da tre metri e mezzo: il
	# chibi era alto duecento pixel e la posa non si giudicava — un provino
	# che non fa vedere non e' un provino. Di profilo si guarda se il corpo
	# STA sul legno o ci galleggia sopra, ed e' l'unica vista che lo dice.
	var viste := [[Vector3(0, 0.95, 1.45), "fronte"], [Vector3(1.5, 0.85, 0.1), "profilo"],
			[Vector3(1.15, 1.0, 1.15), "tre_quarti"]]
	var fatte := {}
	while t < 16.0:
		await process_frame
		t += 1.0 / 60.0
		for k in tappe:
			if t >= float(k) and not fatte.has(k):
				fatte[k] = true
				for vista in viste:
					cam.position = vista[0]
					cam.look_at(Vector3(0, 0.75, 0))
					await _scatta("%s_%s" % [str(tappe[k]), str(vista[1])])

	# ---------- 2) DUE ACCANTO ----------
	print("2 · due accanto, a 95 cm — la scena che l'insieme produce")
	var gaz: Node3D = _pezzo("Gazebo")
	radice.add_child(gaz)
	gaz.position = Vector3(0, 0, -8.0)
	await process_frame
	var posti: Array = gaz.find_children("Posto*", "Node3D", true, false)
	print("   sgabelli trovati: %d" % posti.size())
	var corpi: Array = []
	for i in mini(3, posti.size()):
		var c := _corpo(radice, 5150 + i * 311, Vector3(0, 0, -8.0))
		corpi.append(c)
		c.call("do_routine", "bench",
				(posti[i] as Node3D).global_position, Vector3.ZERO, posti[i])
	for _f in 300:
		await process_frame
	for vista2 in [[Vector3(0, 1.6, -3.6), "fronte"], [Vector3(4.2, 1.6, -8.0), "profilo"],
			[Vector3(3.0, 2.0, -5.0), "tre_quarti"], [Vector3(0, 5.5, -8.01), "alto"]]:
		cam.position = vista2[0]
		cam.look_at(Vector3(0, 0.9, -8.0))
		await _scatta("due_accanto_%s" % str(vista2[1]))

	# ---------- 2b) ACCANTO, O AGLI ESTREMI? ----------
	#
	# ⚠️ **E' LA DOMANDA PIU' IMPORTANTE DI TUTTA QUESTA FASE, e non e' di
	# taratura: sono due FRASI diverse.** Un mobile a tre sedute con due
	# occupate si legge in due modi opposti a seconda di QUALI due:
	#
	#   · le due accanto, col vuoto di lato  → «stanno insieme»
	#   · le due agli estremi, col vuoto in mezzo → «si evitano»
	#
	# E la seconda e' quella che capitava, perche' `_free_bench` ordinava per
	# distanza dall'ANCORA — che e' la risposta a un'altra domanda: l'ancora
	# sta fuori dal Gazebo, quindi due arrivi finivano ai due estremi. Nessun
	# conteggio se ne accorge: in tutte e due le scene ci sono due persone
	# sedute vicine, e il registro delle cricche incassa la stessa riga.
	# Se ne accorge solo l'occhio, e questa e' la lastra in cui guardarlo.
	#
	# Il vuoto NON e' generico, ed e' la ragione per cui la scena regge: i
	# tre cuscini del Gazebo sono di tre colori diversi e sul tavolino ci
	# sono le tazze degli ospiti. La sedia libera e' **quella azzurra, con la
	# sua tazza davanti** — un vuoto specifico si legge come un invito; uno
	# generico non si legge affatto.
	print("2b · ACCANTO o AGLI ESTREMI — la lastra che decide l'ordinamento")
	for corpo_vecchio in corpi:
		(corpo_vecchio as Node3D).queue_free()
	corpi.clear()
	await process_frame
	if posti.size() >= 3:
		var scene := {"ACCANTO_vuoto_di_lato": [0, 1],
				"ESTREMI_vuoto_in_mezzo": [0, 2]}
		for etichetta in scene:
			var quali: Array = scene[etichetta]
			var due: Array = []
			for i in quali:
				# lo STESSO seme nelle due scene, o si finirebbe per
				# giudicare due chibi diversi invece di due disposizioni
				var c2 := _corpo(radice, 5150 + int(i) * 311, Vector3(0, 0, -8.0))
				due.append(c2)
				c2.call("do_routine", "bench",
						(posti[i] as Node3D).global_position, Vector3.ZERO, posti[i])
			for _f2 in 300:
				await process_frame
			for vista3 in [[Vector3(0, 1.6, -3.6), "fronte"],
					[Vector3(3.0, 2.0, -5.0), "tre_quarti"],
					[Vector3(0, 5.5, -8.01), "alto"]]:
				cam.position = vista3[0]
				cam.look_at(Vector3(0, 0.9, -8.0))
				await _scatta("%s_%s" % [etichetta, str(vista3[1])])
			for c3 in due:
				(c3 as Node3D).queue_free()
			await process_frame

	# ---------- 3) IL SALUTO DA SEDUTI ----------
	# La riga in dubbio: il saluto aggiunge un saltello (`vy`) pensato per un
	# corpo in piedi. Su un corpo seduto e' un tremolio dentro il legno, o e'
	# un vicino contento che ti ha visto? Si guarda affiancato.
	print("3 · il saluto DA SEDUTI (fermo contro salutante)")
	# ⚠️ **IL SALUTO SI SCEGLIE A MANO, e la prima stesura non lo faceva.**
	# `saluto_stile` lo assegna il cervello, e un corpo di banco non ce l'ha:
	# restava `""`, `set_meta("postura", "")` non accendeva nessuna recita, e
	# le sette foto erano SETTE VOLTE LA STESSA POSA. Un provino che non
	# muove niente non dice «va bene»: non dice niente, ed e' peggio, perche'
	# ha l'aria di aver risposto.
	# E si sceglie il caso PEGGIORE: `saluto_festoso` e' quello col saltello
	# piu' alto (`vy += 0.09`), cioe' quello che, se un saltello da seduti e'
	# sbagliato, lo mostra per primo.
	cam.position = Vector3(1.1, 0.95, 1.25)
	cam.look_at(Vector3(0, 0.66, 0))
	await _scatta("saluto_00_fermo")
	v.set("saluto_stile", "saluto_festoso")
	v.set_meta("postura", "saluto_festoso")
	var passi := [6, 12, 18, 24, 36, 54, 78]
	var visto := 0
	for p in passi:
		while visto < p:
			await process_frame
			visto += 1
		await _scatta("saluto_%02d_frame" % p)

	print("\nfatto. Le foto: %s" % (_dove if _dove != "" else "(nessuna: CHIBI_SOSTA non impostata)"))
	quit()
