extends SceneTree
## IL METRO DELLE CORDE VIVE — e si prende SOLO con la finestra aperta.
##
## `CordeVive._forza_vento()` chiedeva il vento a
## `RenderingServer.global_shader_parameter_get("vento_forza")`. Fuori
## dall'editor quella funzione FALLISCE: torna null (quindi le corde non
## sentono mai il meteo del cielo) e stampa un ERROR a ogni frame. In
## headless non si vede — il renderer fittizio non ha quel guardrail —
## quindi nessun banco della suite poteva accorgersene: e' un difetto che
## si misura solo dove il giocatore lo paga.
##
## Questo non e' un test: e' il metro. Apre il MainLevel VERO, ci pianta
## quindici corde vere col BuildSystem vero, accende il temporale, e
## campiona OGNI FRAME.
##
##   CHIBI_CORDE_MODO=frame CHIBI_CORDE_SEC=30 \
##       Godot --path . --script res://tools/misura_corde_vento.gd
##
## I due modi, e servono tutti e due:
##
##   frame  il villaggio vivo, 60 fps come in partita. Campiona DUE cose:
##          il tempo di frame a orologio (che su una macchina carica e in
##          una finestra vera e' rumoroso: la GPU e' condivisa con
##          l'editor aperto e con gli altri agenti) e il monitor
##          `TIME_PROCESS`, che e' il tempo speso nel `_process` degli
##          script — cioe' esattamente dove sta il guasto, e l'unico
##          canale che non risente delle stalle del disegno.
##   micro  la misura pulita del SINGOLO gesto: N chiamate alla vecchia
##          strada e N alla nuova, cronometrate. E' la sola che risponde
##          «quanto costa, di preciso» senza doverlo sperare da una media
##          rumorosa. Va in un processo suo: stampa N righe di ERROR e
##          falserebbe il conto dell'altra misura.
##
## CHIBI_CORDE_SPENTE=1 spegne il gestore delle corde: e' il CONTROLLO,
## il costo del villaggio senza di lui.
##
## Le righe di ERROR non si contano qui dentro: si contano sullo stderr
## del processo (`grep -c` sul log), che e' dove le paga chi gioca. Il
## metro stampa i frame disegnati, cosi' il rapporto righe/frame si fa.

## Quanti secondi si buttano prima di contare: il villaggio si costruisce
## su piu' frame e i primi disegni sono tutti fuori scala.
const RISCALDAMENTO := 4.0
## Le corde che si piantano: un villaggio addobbato, non un caso limite.
const ADDOBBO := [
	{"pezzo": "Lucine", "celle": [Vector2i(8, 8), Vector2i(11, 8), Vector2i(14, 8),
			Vector2i(8, 11), Vector2i(11, 11), Vector2i(14, 11)]},
	{"pezzo": "Stendino", "celle": [Vector2i(9, 14), Vector2i(12, 14), Vector2i(15, 14)]},
	{"pezzo": "Altalena", "celle": [Vector2i(9, 17), Vector2i(12, 17), Vector2i(15, 17)]},
]
## Quante chiamate cronometra il modo `micro`. Duemila bastano a uscire
## dal rumore dell'orologio e non seppelliscono il log sotto gli ERROR.
const MICRO_GIRI := 2000


class Sonda extends Node:
	## L'ordine del frame in Godot: `process_frame` -> `_process` dei nodi
	## -> tween. Ci si aggancia al SEGNALE, che vede il frame com'e' stato
	## disegnato: una sonda dentro un `_process` cade in mezzo e somma due
	## mezzi frame (lezione gia' pagata in prova_seduta_troncata).
	var ms: Array = []           # tempo di frame a orologio
	var proc: Array = []         # TIME_PROCESS: il lavoro degli script
	var attiva := false
	var _ultimo := 0

	func _ready() -> void:
		get_tree().process_frame.connect(_campiona)

	func _campiona() -> void:
		var ora := Time.get_ticks_usec()
		if attiva and _ultimo > 0:
			ms.append(float(ora - _ultimo) / 1000.0)
			proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_ultimo = ora


func _init() -> void:
	_go()


func _trova(gruppo: String) -> Node:
	for n in get_nodes_in_group(gruppo):
		return n
	return null


static func _percentile(ordinati: Array, q: float) -> float:
	if ordinati.is_empty():
		return 0.0
	var i := clampi(int(round(q * float(ordinati.size() - 1))), 0, ordinati.size() - 1)
	return float(ordinati[i])


static func _media(v: Array) -> float:
	var s := 0.0
	for x in v:
		s += float(x)
	return s / maxf(float(v.size()), 1.0)


func _riga(nome: String, v: Array) -> void:
	var o: Array = v.duplicate()
	o.sort()
	print("%-10s media %7.3f   p50 %7.3f   p90 %7.3f   p99 %7.3f   max %8.3f"
			% [nome, _media(o), _percentile(o, 0.5), _percentile(o, 0.9),
				_percentile(o, 0.99), _percentile(o, 1.0)])


func _go() -> void:
	var modo := OS.get_environment("CHIBI_CORDE_MODO")
	if modo == "":
		modo = "frame"
	var durata := float(OS.get_environment("CHIBI_CORDE_SEC"))
	if durata <= 0.0:
		durata = 30.0

	if change_scene_to_file("res://scenes/levels/MainLevel.tscn") != OK:
		push_error("MainLevel non si apre")
		quit(1)
		return
	for _i in 30:
		await process_frame

	var build := _trova("build_system")
	if build == null:
		push_error("BuildSystem non trovato")
		quit(1)
		return
	build.set("_persist", false)

	# IL TEMPORALE. E' la condizione in cui il difetto costa di piu': il
	# cielo dice 1.8 e le corde sentono 1.0.
	var weather := _trova("weather")
	if weather != null:
		weather.set("_state", "rain")
		weather.set("_snowing", false)
		weather.set("_vento", 1.8)

	for gruppo in ADDOBBO:
		for c: Vector2i in gruppo["celle"]:
			build.call("place_cell", c, str(gruppo["pezzo"]), 0, false, 0, "")
	for _i in 10:
		await process_frame

	var corde := get_root().get_node_or_null("MainLevel/CordeVive")
	var quante := get_nodes_in_group("corda_viva").size()
	if corde != null and OS.get_environment("CHIBI_CORDE_SPENTE") == "1":
		corde.process_mode = Node.PROCESS_MODE_DISABLED

	if modo == "micro":
		_micro(corde)
		quit(0)
		return
	if modo == "sondaggio":
		await _sondaggio(durata)
		quit(0)
		return

	# Niente vsync: l'attesa del monitor e' tempo in cui il processo dorme,
	# e sommata al lavoro nasconde la misura. Il tetto resta a 60 come in
	# partita, cosi' le righe di ERROR al minuto sono quelle vere.
	# E la finestra si rimpicciolisce: il progetto parte a schermo intero in
	# 1920x1080 con MSAA, e li' il tempo di frame e' quasi tutto GPU divisa
	# con l'editor aperto e con gli altri agenti — rumore che seppellisce
	# un millisecondo di CPU. La misura che conta (`TIME_PROCESS`) non
	# cambia con la finestra: cambia solo quanto rumore le sta intorno.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	Engine.max_fps = 60

	var sonda := Sonda.new()
	get_root().add_child(sonda)
	var scalda := Time.get_ticks_usec() + int(RISCALDAMENTO * 1000000.0)
	while Time.get_ticks_usec() < scalda:
		await process_frame
	sonda.attiva = true
	var partenza := Time.get_ticks_usec()
	var fine := partenza + int(durata * 1000000.0)
	while Time.get_ticks_usec() < fine:
		await process_frame
	sonda.attiva = false
	var secondi := float(Time.get_ticks_usec() - partenza) / 1000000.0

	var forza := 1.0
	if corde != null:
		forza = float(corde.call("_forza_vento"))

	print("=== MISURA CORDE (frame) ===")
	print("corde vive: %d   gestore: %s   secondi: %.2f   frame misurati: %d   fps: %.1f"
			% [quante, "SPENTO" if OS.get_environment("CHIBI_CORDE_SPENTE") == "1" else "acceso",
				secondi, sonda.ms.size(), float(sonda.ms.size()) / maxf(secondi, 0.001)])
	print("vento che arriva alle corde: %.3f   (il cielo ne ha %.3f)"
			% [forza, float(weather.get("_vento")) if weather else -1.0])
	_riga("frame ms", sonda.ms)
	_riga("process ms", sonda.proc)
	var o: Array = sonda.ms.duplicate(); o.sort()
	var op: Array = sonda.proc.duplicate(); op.sort()
	print("RIGA_CSV,frame,%d,%.3f,%d,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f"
			% [quante, secondi, sonda.ms.size(), Engine.get_frames_drawn(),
				_media(o), _percentile(o, 0.99), _percentile(o, 1.0),
				_media(op), _percentile(op, 0.9), _percentile(op, 0.99), forza])
	quit(0)


## LA MISURA CHE CONTA: le due strade, UNA VOLTA PER FRAME, dentro il
## villaggio vivo. Il micro-banco le chiama duemila volte di fila e le
## trova tutte e due in cache: e' la misura di un caso che nel gioco non
## esiste mai. Il gioco ne fa UNA per frame, a sedici millisecondi di
## distanza, con tutto il resto del villaggio passato in mezzo a
## sfrattare le cache. Qui si misura quella — e appaiata, nello stesso
## frame, cosi' nessuna raffica di carico della macchina puo' toccarne
## una e non l'altra.
class Sondaggio extends Node:
	var vecchia: Array = []
	var nuova: Array = []
	var attiva := false

	func _process(_d: float) -> void:
		if not attiva:
			return
		# l'ordine si alterna a frame alterni: chi va per primo paga la
		# cache fredda del frame, e misurarne sempre uno per primo
		# regalerebbe all'altro un vantaggio sistematico
		if (Engine.get_frames_drawn() & 1) == 0:
			vecchia.append(_vecchia())
			nuova.append(_nuova())
		else:
			nuova.append(_nuova())
			vecchia.append(_vecchia())

	var sacco := 0.0    # tiene in vita i risultati: niente da ottimizzare via

	func _vecchia() -> float:
		var t := Time.get_ticks_usec()
		var v: Variant = RenderingServer.global_shader_parameter_get("vento_forza")
		var d := float(Time.get_ticks_usec() - t)
		sacco += 1.0 if v == null else float(v)
		return d

	func _nuova() -> float:
		var t := Time.get_ticks_usec()
		var w := get_tree().get_first_node_in_group("weather")
		var f := 1.0
		if w != null and w.has_method("forza_del_vento"):
			f = float(w.get("_vento"))
		var d := float(Time.get_ticks_usec() - t)
		sacco += f
		return d


func _sondaggio(durata: float) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	Engine.max_fps = 60
	var s := Sondaggio.new()
	get_root().add_child(s)
	var scalda := Time.get_ticks_usec() + int(RISCALDAMENTO * 1000000.0)
	while Time.get_ticks_usec() < scalda:
		await process_frame
	s.attiva = true
	var fine := Time.get_ticks_usec() + int(durata * 1000000.0)
	while Time.get_ticks_usec() < fine:
		await process_frame
	s.attiva = false
	print("=== SONDAGGIO (una chiamata per frame, %d frame) ===" % s.vecchia.size())
	_riga("vecchia us", s.vecchia)
	_riga("nuova us", s.nuova)
	var ov: Array = s.vecchia.duplicate(); ov.sort()
	var on: Array = s.nuova.duplicate(); on.sort()
	print("RIGA_CSV,sondaggio,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f"
			% [s.vecchia.size(), _media(ov), _percentile(ov, 0.5), _percentile(ov, 0.99),
				_media(on), _percentile(on, 0.5), _percentile(on, 0.99)])


## LA MISURA PULITA. Le due strade, cronometrate una accanto all'altra
## nello stesso processo e nello stesso secondo: e' l'unica forma di
## misura appaiata che una macchina carica non puo' falsare.
func _micro(corde: Node) -> void:
	# a vuoto: quanto costa il giro del ciclo da solo
	var t0 := Time.get_ticks_usec()
	var sacco := 0.0
	for _i in MICRO_GIRI:
		sacco += 1.0
	var vuoto := float(Time.get_ticks_usec() - t0)

	t0 = Time.get_ticks_usec()
	for _i in MICRO_GIRI:
		var v: Variant = RenderingServer.global_shader_parameter_get("vento_forza")
		sacco += 1.0 if v == null else 2.0
	var vecchia := float(Time.get_ticks_usec() - t0)

	var cielo := _trova("weather")
	t0 = Time.get_ticks_usec()
	for _i in MICRO_GIRI:
		var w := get_first_node_in_group("weather")
		if w != null and w.has_method("forza_del_vento"):
			sacco += float(w.get("_vento"))
	var nuova := float(Time.get_ticks_usec() - t0)

	# e la strada nuova COME LA CHIAMA IL GIOCO: dal metodo vero del
	# gestore, cache compresa. E' questo il numero che conta.
	var vera := 0.0
	if corde != null:
		t0 = Time.get_ticks_usec()
		for _i in MICRO_GIRI:
			sacco += float(corde.call("_forza_vento"))
		vera = float(Time.get_ticks_usec() - t0)

	print("=== MISURA CORDE (micro, %d giri) ===" % MICRO_GIRI)
	print("cielo trovato: %s   (sacco %.0f)" % [str(cielo != null), sacco])
	print("ciclo a vuoto                       %8.3f us/chiamata" % (vuoto / MICRO_GIRI))
	print("VECCHIA  global_shader_parameter_get %8.3f us/chiamata -> %.3f ms/frame a 60 fps"
			% [(vecchia - vuoto) / MICRO_GIRI, (vecchia - vuoto) / MICRO_GIRI / 1000.0])
	print("NUOVA    gruppo weather + _vento     %8.3f us/chiamata -> %.3f ms/frame a 60 fps"
			% [(nuova - vuoto) / MICRO_GIRI, (nuova - vuoto) / MICRO_GIRI / 1000.0])
	print("VERA     CordeVive._forza_vento()    %8.3f us/chiamata (call() incluso)"
			% ((vera - vuoto) / MICRO_GIRI))
	print("RIGA_CSV,micro,%d,%.4f,%.4f,%.4f,%.4f"
			% [MICRO_GIRI, vuoto / MICRO_GIRI, (vecchia - vuoto) / MICRO_GIRI,
				(nuova - vuoto) / MICRO_GIRI, (vera - vuoto) / MICRO_GIRI])
