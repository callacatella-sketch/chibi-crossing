extends SceneTree
## IL FOTOGRAMMA MENTRE IL MODELLO ARRIVA — misurato APPAIATO, nella stessa
## corsa, col MainLevel vero e la rete vera.
##
##   CHIBI_BLOCCHI=6 CHIBI_DURATA=12 ~/Downloads/Godot.app/Contents/MacOS/Godot \
##       --path . --resolution 1280x720 --script res://tools/misura_scarico_fps.gd
##
## La promessa della schermata è scritta a lettere grandi: «Puoi chiudere
## questa pagina e tornare a giocare: va avanti per conto suo». Venti minuti
## di download mentre si gioca sono una promessa che si mantiene o non si
## mantiene, e l'unico modo di saperlo è **contare i fotogrammi mentre il
## file arriva davvero**.
##
## ⚠️ **NIENTE `--headless`.** Senza rendering non c'è niente da contare, ed è
## proprio il modo in cui una stalla del server di rendering resta invisibile
## (la regola sta in fondo a CLAUDE.md). E il vsync si spegne, o si misura il
## monitor: a 60 Hz ogni fotogramma dura 16.6 ms anche se il gioco ne
## avanzasse dieci.
##
## ⚠️ **BLOCCHI ALTERNATI, NON DUE CORSE.** Due processi diversi non sono
## confrontabili — compilazione degli shader, cache, e soprattutto le altre
## sessioni di agente che vanno e vengono. Alternando *scarica · fermo ·
## scarica · fermo* dentro la stessa corsa, la deriva della macchina cade su
## tutti e due i bracci.
##
## ⚠️ **E SI SCARICA DAVVERO**, dalla sorgente vera, in una cartella sua
## (`user://misura_scarico/`) che NON è quella del gioco: il banco non deve
## installare un modello a nessuno. Alla fine il parziale si butta.
##
## Il braccio «fermo» non è «scarico finito»: è `annulla()`, cioè il thread
## che molla e il socket che si chiude. Riprendendo si riparte dal pezzo, che
## è esattamente quello che fa chi mette in pausa e riprende.

const SCARICO := preload("res://systems/Scarico.gd")
const MACCHINA := preload("res://systems/ScaricoMacchina.gd")

var _blocchi := 4
var _durata := 12.0
var _caldo := 8.0

var _campioni := PackedFloat64Array()
var _misura := false
var _t_ultimo := 0
var _s: Scarico = null
var _dove := "user://misura_scarico/pezzo.bin"


func _init() -> void:
	_go()


func _process(_d: float) -> bool:
	var ora := Time.get_ticks_usec()
	if _misura and _t_ultimo > 0:
		_campioni.append(float(ora - _t_ultimo) / 1000.0)
	_t_ultimo = ora
	return false


func _via() -> void:
	_campioni = PackedFloat64Array()
	_t_ultimo = 0
	_misura = true


func _stop() -> Dictionary:
	_misura = false
	var v := Array(_campioni)
	v.sort()
	if v.is_empty():
		return {"n": 0}
	var somma := 0.0
	for x in v:
		somma += float(x)
	var p50 := float(v[int(v.size() * 0.50)])
	var doppi := 0
	for x in v:
		if float(x) > p50 * 2.0:
			doppi += 1
	return {
		"n": v.size(), "medio": somma / float(v.size()), "p50": p50,
		"p99": float(v[mini(int(v.size() * 0.99), v.size() - 1)]),
		"max": float(v[v.size() - 1]), "doppi": doppi,
	}


func _riga(nome: String, d: Dictionary) -> String:
	if int(d.get("n", 0)) == 0:
		return "  %-22s (nessun campione)" % nome
	return "  %-22s n=%5d  medio %6.2f  p50 %6.2f  p99 %6.2f  MAX %7.2f  >2×p50: %d" \
			% [nome, int(d["n"]), float(d["medio"]), float(d["p50"]),
			float(d["p99"]), float(d["max"]), int(d["doppi"])]


func _aspetta(secondi: float) -> void:
	var fino := Time.get_ticks_msec() + int(secondi * 1000.0)
	while Time.get_ticks_msec() < fino:
		await process_frame


func _carico() -> String:
	var o := []
	OS.execute("/bin/sh", ["-c", "uptime | sed 's/.*averages*: //'"], o)
	return String(o[0]).strip_edges() if o.size() > 0 else "?"


func _parziale() -> int:
	var p := _dove + ".parte"
	if not FileAccess.file_exists(p):
		return 0
	var f := FileAccess.open(p, FileAccess.READ)
	return 0 if f == null else f.get_length()


func _go() -> void:
	if OS.get_environment("CHIBI_BLOCCHI") != "":
		_blocchi = int(OS.get_environment("CHIBI_BLOCCHI"))
	if OS.get_environment("CHIBI_DURATA") != "":
		_durata = float(OS.get_environment("CHIBI_DURATA"))

	print("=== IL FOTOGRAMMA MENTRE IL MODELLO ARRIVA ===")
	print("  carico della macchina PRIMA: %s" % _carico())
	print("  blocchi: %d per parte, %.0f s l'uno" % [_blocchi, _durata])

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await process_frame
	if change_scene_to_file("res://scenes/levels/MainLevel.tscn") != OK:
		push_error("MainLevel non si apre")
		quit(1)
		return
	for _i in 20:
		await process_frame
	print("  MainLevel aperto. riscaldamento %.0f s…" % _caldo)
	await _aspetta(_caldo)

	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(_dove.get_base_dir()))
	_s = SCARICO.new()
	_s.name = SCARICO.NODO
	root.add_child(_s)
	# LA SORGENTE VERA, ma la destinazione è del banco: non si installa
	# niente a nessuno. L'impronta è quella vera, così se per caso il file
	# arrivasse intero il corriere farebbe comunque la cosa giusta.
	_s.usa_questi_estremi(SCARICO.url(), _dove, SCARICO.DIMENSIONE,
			Llm.IMPRONTA_SPEDITO)

	var giu := []
	var fermi := []
	for b in _blocchi:
		# ── braccio A: SCARICA ────────────────────────────────────────────
		_s.comincia()
		await _aspetta(1.0)              # la connessione si apre
		_via()
		await _aspetta(_durata)
		var a := _stop()
		var byte_a := _parziale()
		giu.append(a)
		print(_riga("scarica  [%d]" % (b + 1), a)
				+ "   %.1f MB sul disco · %.1f Mbit/s"
				% [byte_a / 1048576.0, _s.al_secondo() * 8.0 / 1000000.0])

		# ── braccio B: FERMO ──────────────────────────────────────────────
		_s.annulla()
		await _aspetta(1.0)              # il thread molla
		_via()
		await _aspetta(_durata)
		var f := _stop()
		fermi.append(f)
		print(_riga("fermo    [%d]" % (b + 1), f))

	# ── il conto ─────────────────────────────────────────────────────────
	var ma := 0.0
	var mf := 0.0
	var na := 0
	var nf := 0
	var maxa := 0.0
	var massf := 0.0
	var da := 0
	var df := 0
	for d in giu:
		ma += float(d["medio"]) * int(d["n"])
		na += int(d["n"])
		maxa = maxf(maxa, float(d["max"]))
		da += int(d["doppi"])
	for d in fermi:
		mf += float(d["medio"]) * int(d["n"])
		nf += int(d["n"])
		massf = maxf(massf, float(d["max"]))
		df += int(d["doppi"])
	ma /= maxf(float(na), 1.0)
	mf /= maxf(float(nf), 1.0)

	print("")
	print("--- LA MISURA APPAIATA ---")
	print("  mentre SCARICA : medio %6.2f ms  (n=%d, MAX %.2f, >2×p50 %d)"
			% [ma, na, maxa, da])
	print("  a motore FERMO : medio %6.2f ms  (n=%d, MAX %.2f, >2×p50 %d)"
			% [mf, nf, massf, df])
	if mf > 0.0:
		print("  SCARTO         : %+.2f ms  (%+.1f%%)"
				% [ma - mf, (ma - mf) / mf * 100.0])
	print("  fotogrammi al secondo: %.1f mentre scarica · %.1f fermo"
			% [1000.0 / maxf(ma, 0.001), 1000.0 / maxf(mf, 0.001)])
	print("  scaricati in tutto: %.1f MB" % (_parziale() / 1048576.0))
	print("  carico della macchina DOPO: %s" % _carico())

	# IL BANCO NON LASCIA NIENTE.
	_s.annulla()
	await _aspetta(1.0)
	for p in [_dove, _dove + ".parte"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	print("  (il pezzo scaricato dal banco è stato buttato)")
	quit(0)
