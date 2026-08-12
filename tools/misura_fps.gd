extends SceneTree
## QUANTI FOTOGRAMMI FA IL VILLAGGIO (contati, non stimati).
##
## Una prova di prestazioni headless non esiste: senza rendering non c'è
## niente da contare, e `--headless` è proprio il modo in cui una stalla
## del server di rendering diventa invisibile. Qui si apre `MainLevel` con
## la finestra vera, si posano i pezzi che hanno le corde vive, si spegne
## il vsync (o si misura il monitor, non il gioco) e si contano i
## fotogrammi a orologio in finestre ALTERNATE: gestore delle corde acceso,
## spento, acceso, spento. La differenza è il costo del sistema, misurato
## nella STESSA corsa — due processi diversi non sono confrontabili.
##
##   ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##       --resolution 1280x720 --script res://tools/misura_fps.gd
##
##   CHIBI_FPS_SEC       secondi di ogni finestra di misura (default 12)
##   CHIBI_FPS_CALDO     secondi di riscaldamento prima di misurare (default 6)
##   CHIBI_FPS_GIRI      quante volte si alternano le finestre (default 2)
##   CHIBI_FPS_SONDA=1   aggiunge la SONDA (vedi sotto)
##   CHIBI_FPS_DIAGNOSI=1  chi si mangia il fotogramma: pixel o codice, e
##                       quanto costa il _process di ogni figlio del livello
##
## ⚠️ GUARDA IL CARICO DELLA MACCHINA PRIMA DI CREDERE A UN NUMERO
## (`uptime`, e quanti Godot stanno girando). Con le altre sessioni di
## agente addosso, il gioco può prendere il 25% di UN core: a quel punto un
## fotogramma balla di ±10 ms e le differenze piccole sono rumore — il
## 2026-08-12 questo strumento ha attribuito 14.6 ms a una chiamata che ne
## costa 0.28, e ha dato «+10 ms» perfino a nodi che in `_process` non
## fanno niente. Quando la differenza che cerchi è dell'ordine del rumore,
## non contare i fotogrammi: CRONOMETRA LA RIGA (è quello che fa la sonda).

## I pezzi da posare: tutti e tre hanno corde vive (le lucine ne hanno una
## lunga con dieci appesi, l'altalena due sorelle legate dal sedile, lo
## stendino il filo del bucato).
const PEZZI := [
	{"nome": "Lucine", "c": Vector2i(9, 9)},
	{"nome": "Altalena", "c": Vector2i(12, 9)},
	{"nome": "Stendino", "c": Vector2i(9, 12)},
]

## LA SONDA: un nodo che a ogni fotogramma fa SOLO la lettura da editor che
## si è tolta dalle corde vive, e nient'altro. È il difetto in provetta: la
## differenza fra la finestra con la sonda e quella senza è il prezzo di
## quella singola chiamata, senza la fisica delle corde in mezzo. Si accende
## apposta (CHIBI_FPS_SONDA=1) e riempie il log dei suoi errori: sono suoi.
## Si CRONOMETRA da sola, oltre a farsi contare dai fotogrammi: con la
## macchina carica (più agenti, più Godot) un fotogramma balla di decine di
## millisecondi, e una differenza di fps non riesce a vedere una chiamata
## che ne costa pochi. I microsecondi presi attorno alla riga, invece, sono
## quella riga e nient'altro.
class Sonda extends Node:
	var usec := 0.0
	var chiamate := 0
	var risposta: Variant = null

	func _process(_d: float) -> void:
		var t0 := Time.get_ticks_usec()
		risposta = RenderingServer.global_shader_parameter_get("vento_forza")
		usec += float(Time.get_ticks_usec() - t0)
		chiamate += 1


var _sec := 12.0
var _caldo := 6.0
var _corde: Node = null
var _sonda_usec: Array = []
var _sonda_risposta: Variant = null


func _init() -> void:
	_go()


func _numero(chiave: String, dfl: float) -> float:
	var v := OS.get_environment(chiave)
	return float(v) if v != "" else dfl


func _trova(gruppo: String) -> Node:
	for n in get_nodes_in_group(gruppo):
		return n
	return null


func _attendi(sec: float) -> void:
	var fine := Time.get_ticks_usec() + int(sec * 1e6)
	while Time.get_ticks_usec() < fine:
		await process_frame


## Conta i fotogrammi VERI in una finestra a orologio: `get_frames_per_second()`
## è una media smorzata del motore e nasconde le impuntate, che sono
## esattamente la cosa che si sente giocando.
func _misura(sec: float) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var fine := t0 + int(sec * 1e6)
	var prec := t0
	var n := 0
	var peggio := 0.0
	while Time.get_ticks_usec() < fine:
		await process_frame
		var ora := Time.get_ticks_usec()
		peggio = maxf(peggio, float(ora - prec) / 1000.0)
		prec = ora
		n += 1
	var durata := float(Time.get_ticks_usec() - t0) / 1e6
	return {
		"fps": float(n) / durata,
		"ms": durata * 1000.0 / maxf(float(n), 1.0),
		"peggio": peggio,
		"frame": n,
	}


func _media(finestre: Array, chiave: String) -> float:
	if finestre.is_empty():
		return 0.0
	var s := 0.0
	for m in finestre:
		s += float((m as Dictionary)[chiave])
	return s / float(finestre.size())


func _riga(titolo: String, m: Dictionary) -> String:
	return "%-26s %7.1f fps · %7.2f ms/frame · peggiore %7.2f ms (%d frame)" % [
		titolo, m["fps"], m["ms"], m["peggio"], m["frame"]]


## Il punto di mezzo della prima corda viva: serve a dire se le corde si
## MUOVONO ancora (una misura di prestazioni che spegne il vento andrebbe
## veloce e sarebbe una bugia).
func _pancia() -> Vector3:
	for n in get_nodes_in_group("corda_viva"):
		var stato: Dictionary = _corde.call("_stato_di", n)
		if stato.is_empty():
			continue
		var punti: Array = stato["punti"]
		return punti[punti.size() / 2]
	return Vector3.INF


func _quanto_si_muove(sec: float) -> float:
	var p0 := _pancia()
	if p0 == Vector3.INF:
		return -1.0
	var massimo := 0.0
	var fine := Time.get_ticks_usec() + int(sec * 1e6)
	while Time.get_ticks_usec() < fine:
		await process_frame
		massimo = maxf(massimo, _pancia().distance_to(p0))
	return massimo


func _go() -> void:
	_sec = _numero("CHIBI_FPS_SEC", 12.0)
	_caldo = _numero("CHIBI_FPS_CALDO", 6.0)

	# il vsync misurerebbe il monitor; il tappo dei fps pure
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	AudioServer.set_bus_mute(0, true)   # una misura non deve cantare

	var ok: int = change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	if ok != OK:
		push_error("MainLevel non si apre")
		quit(1)
		return
	# il villaggio nasce su più frame: si aspetta il BuildSystem, non un
	# numero di frame indovinato
	var build: Node = null
	for _k in 600:
		build = _trova("build_system")
		if build != null:
			break
		await process_frame
	if build == null:
		push_error("BuildSystem non trovato nel gruppo build_system")
		quit(1)
		return
	await _attendi(1.0)
	build.set("_persist", false)        # una misura non è una partita

	# «Riduci animazioni» spegne le corde in blocco: se fosse acceso si
	# misurerebbe zero e si festeggerebbe per niente
	var imp := root.get_node_or_null("Settings")
	if imp != null and bool(imp.get("reduce_motion")):
		imp.set("reduce_motion", false)
		print("(«Riduci animazioni» era acceso: spento per la misura)")

	for p in PEZZI:
		build.call("place_cell", p["c"], str(p["nome"]), 0, false, 0, "")
	await process_frame

	_corde = current_scene.get_node_or_null("CordeVive")
	if _corde == null:
		push_error("CordeVive non è nel MainLevel")
		quit(1)
		return
	_corde.call("_censisci")            # le corde appena posate, subito vive
	var quante := get_nodes_in_group("corda_viva").size()
	print("corde vive nel mondo: %d" % quante)

	print("… riscaldamento %.0f s (shader, particelle, mondo differito)" % _caldo)
	await _attendi(_caldo)

	# LE FINESTRE SI ALTERNANO (acceso, spento, acceso, spento…) invece di
	# fare due blocchi lunghi: se la macchina rallenta a metà misura — e con
	# più agenti che compilano e girano test succede — un blocco solo si
	# prende tutto il rallentamento e la differenza fra i due diventa una
	# proprietà del carico, non del codice. Alternando, la deriva si spalma
	# su entrambi.
	var giri := maxi(int(_numero("CHIBI_FPS_GIRI", 2.0)), 1)
	var sonda_accesa := OS.get_environment("CHIBI_FPS_SONDA") == "1"
	var con: Array = []
	var senza: Array = []
	var con_sonda: Array = []
	for _g in giri:
		_corde.set_process(true)
		await _attendi(1.0)
		var a: Dictionary = await _misura(_sec)
		con.append(a)
		# stesso mondo, stessa camera, stesso minuto di macchina: cambia SOLO
		# il gestore delle corde
		_corde.set_process(false)
		await _attendi(1.0)
		var b: Dictionary = await _misura(_sec)
		senza.append(b)
		# LA SONDA: la sola lettura da editor, un fotogramma per volta
		if sonda_accesa:
			var s := Sonda.new()
			current_scene.add_child(s)
			await _attendi(1.0)
			var c: Dictionary = await _misura(_sec)
			con_sonda.append(c)
			if s.chiamate > 0:
				_sonda_usec.append(s.usec / float(s.chiamate))
				_sonda_risposta = s.risposta
			s.free()
	_corde.set_process(true)
	await _attendi(1.0)

	print("")
	print("======================= MISURA (MainLevel vero) =======================")
	for i in giri:
		print(_riga("giro %d · corde ACCESE" % (i + 1), con[i]))
		print(_riga("giro %d · corde spente" % (i + 1), senza[i]))
		if sonda_accesa:
			print(_riga("giro %d · corde spente + SONDA" % (i + 1), con_sonda[i]))
	var ms_con := _media(con, "ms")
	var ms_senza := _media(senza, "ms")
	print("-----------------------------------------------------------------------")
	print("media: corde ACCESE %.2f ms/frame (%.1f fps) · spente %.2f ms/frame (%.1f fps)"
			% [ms_con, _media(con, "fps"), ms_senza, _media(senza, "fps")])
	print("costo del gestore delle corde: %.2f ms per fotogramma" % (ms_con - ms_senza))
	if sonda_accesa:
		var ms_sonda := _media(con_sonda, "ms")
		print("costo della SOLA lettura da editor: %.2f ms per fotogramma (%.2f ms/frame)"
				% [ms_sonda - ms_senza, ms_sonda])
		var usec := 0.0
		for u in _sonda_usec:
			usec += float(u)
		if not _sonda_usec.is_empty():
			usec /= float(_sonda_usec.size())
		# la stessa cosa cronometrata SULLA riga, che con la macchina carica
		# è l'unica delle due misure che regge
		print("cronometrata sulla riga: %.1f µs a chiamata (%.3f ms di fotogramma)"
				% [usec, usec / 1000.0])
		print("e quello che il server di rendering RISPONDE: %s (%s)"
				% [str(_sonda_risposta), type_string(typeof(_sonda_risposta))])
	print("=======================================================================")

	# IL VENTO ARRIVA ANCORA? (una misura veloce con le corde ferme sarebbe
	# una bugia, e il vento è proprio il canale che si sta cambiando)
	var meteo := _trova("weather")
	var mosso: float = await _quanto_si_muove(3.0)
	print("")
	print("vento letto dalle corde : %.3f" % float(_corde.call("_forza_vento")))
	if meteo != null:
		print("vento di Weather (_vento): %.3f" % float(meteo.get("_vento")))
	print("la pancia della corda si muove di %.4f m in 3 s" % mosso)

	# …e SEGUE il cielo: si fa piovere e si guarda salire verso 1.8
	if meteo != null:
		meteo.call("debug_rain", true)
		await _attendi(8.0)
		print("con la pioggia → corde %.3f · Weather %.3f (atteso ~1.8)" % [
			float(_corde.call("_forza_vento")), float(meteo.get("_vento"))])
		# LA PROVA DEL NOVE, col cielo a 1.8: la vecchia fonte, richiesta
		# adesso, che cosa risponde? (è la riga che le corde avevano in
		# pancia fino a ieri — qui la si interroga di proposito)
		var v: Variant = RenderingServer.global_shader_parameter_get("vento_forza")
		print("il server di rendering, richiesto ORA, risponde: %s (%s)"
				% [str(v), type_string(typeof(v))])
		meteo.call("debug_rain", false)
		await _attendi(1.0)

	if OS.get_environment("CHIBI_FPS_DIAGNOSI") == "1":
		await _diagnosi()

	quit(0)


## CHI SI MANGIA IL FOTOGRAMMA. Prima la domanda grossa — pixel o codice? —
## rimpicciolendo la finestra: se i fotogrammi volano, il collo di
## bottiglia è nel disegno; se non cambia niente, è nel codice. Poi, uno
## per uno, si spegne il `_process` di ogni figlio del livello e si guarda
## quanto si guadagna.
func _diagnosi() -> void:
	print("")
	print("------------------- chi si mangia il fotogramma -------------------")
	var grande := DisplayServer.window_get_size()
	var m_grande: Dictionary = await _misura(4.0)
	DisplayServer.window_set_size(Vector2i(320, 180))
	await _attendi(2.0)
	var m_piccola: Dictionary = await _misura(4.0)
	DisplayServer.window_set_size(grande)
	await _attendi(2.0)
	print(_riga("finestra %dx%d" % [grande.x, grande.y], m_grande))
	print(_riga("finestra 320x180", m_piccola))
	if float(m_piccola["fps"]) > float(m_grande["fps"]) * 1.6:
		print("→ il collo di bottiglia è nei PIXEL (GPU)")
	else:
		print("→ i pixel non c'entrano: il costo sta nel CODICE (CPU)")

	var base: Dictionary = await _misura(4.0)
	var classifica: Array = []
	for f in current_scene.get_children():
		if not f.is_processing():
			continue
		f.set_process(false)
		await _attendi(0.6)
		var senza: Dictionary = await _misura(2.5)
		f.set_process(true)
		classifica.append({"nome": str(f.name), "ms": float(base["ms"]) - float(senza["ms"])})
	classifica.sort_custom(func(a, b): return float(a["ms"]) > float(b["ms"]))
	print("(base: %.2f ms/frame) — quanto si guadagna spegnendo il _process di:" % base["ms"])
	for v in classifica:
		if absf(float(v["ms"])) < 0.5:
			continue
		print("  %-24s %+7.2f ms" % [v["nome"], v["ms"]])
	print("-------------------------------------------------------------------")
