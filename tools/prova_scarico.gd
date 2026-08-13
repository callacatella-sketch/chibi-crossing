extends SceneTree

## LA PROVA VERA DEL CORRIERE — due gigabyte e mezzo, dalla rete vera, mentre
## il villaggio gira.
##
## `tests/cases/test_scarico.gd` prova il VIAGGIO senza rete: la ripresa, il
## server che ignora il `Range`, i byte rovinati, l'annullamento. Questo banco
## prova le tre cose che quel file non può nemmeno sfiorare:
##
##  1. **che funzioni davvero**, contro Hugging Face, con la sua CDN firmata,
##     i suoi rimbalzi e la linea di casa;
##  2. **che il fotogramma non se ne accorga**, misurato APPAIATO — blocchi
##     alternati «scarica» / «fermo» nella STESSA corsa, che è l'unico modo
##     di misurare qualcosa su una macchina con altri lavori addosso;
##  3. **che annullare e riprendere funzionino sulla rete vera**, non solo
##     davanti a un tubo finto: ogni passaggio da «scarica» a «fermo» è un
##     annullamento vero, e ogni ritorno è una ripresa vera con `Range` —
##     quindici volte in una corsa.
##
## ⚠️ **SI APRE UNA FINESTRA** (niente `--headless`) quando si misura il
## fotogramma: senza rendering non c'è niente da contare, ed è proprio il modo
## in cui una stalla diventa invisibile (vedi CLAUDE.md, «le prestazioni non si
## misurano headless»).
##
## ⚠️ **E ASPETTA UN FOTOGRAMMA PRIMA DI TOCCARE LA RETE.** MISURATO su 4.7.1:
## dentro `_init()` di uno script `SceneTree` la cifratura non si accende
## («SSL module failed to initialize!», stato `CANT_CONNECT`), e dopo un solo
## `await process_frame` la stessa identica chiamata si connette in 190 ms.
## Un banco che chiedesse in `_init` diagnosticherebbe «rete morta» con la rete
## viva.
##
##     # il giro completo, col villaggio acceso e il fotogramma misurato
##     ~/Downloads/Godot.app/Contents/MacOS/Godot --path . --resolution 1280x720 \
##         --script res://tools/prova_scarico.gd
##
##     CHIBI_SOLO_PREFLIGHT=1   # dieci secondi: c'è ancora, ed è quello?
##     CHIBI_GIOCO=0            # senza MainLevel (misura solo il viaggio)
##     CHIBI_ACCESO=30          # secondi di blocco «scarica»
##     CHIBI_SPENTO=10          # secondi di blocco «fermo»
##     CHIBI_DOVE=<cartella>    # dove posare il file (di serie: quella vera)

const SCARICO := preload("res://systems/Scarico.gd")
const MACCHINA := preload("res://systems/ScaricoMacchina.gd")
const RETE := preload("res://systems/ScaricoRete.gd")
const LLM := preload("res://systems/Llm.gd")

var _s: Scarico = null
var _frame := 0
var _t_ultimo := 0
var _campioni: Array[float] = []
var _blocchi: Array[Dictionary] = []
var _acceso := true
var _fine_blocco := 0.0
var _misure_annulla: Array[float] = []
var _misure_ripresa := 0


func _init() -> void:
	_go()


func _process(_d: float) -> bool:
	return false


func _conta() -> void:
	var ora := Time.get_ticks_usec()
	if _t_ultimo > 0:
		_campioni.append((ora - _t_ultimo) / 1000.0)
	_t_ultimo = ora
	_frame += 1


func _go() -> void:
	# ⚠️ il fotogramma PRIMA di qualunque cosa tocchi la rete
	await process_frame

	print("")
	print("════════ IL CORRIERE — %s ════════" % Time.get_datetime_string_from_system())
	print("  da:      %s" % SCARICO.url())
	print("  a:       %s" % _destinazione())
	print("  pesa:    %s (%d byte)" % [SCARICO.misura_umana(SCARICO.DIMENSIONE), SCARICO.DIMENSIONE])
	print("  impronta attesa: %s" % LLM.IMPRONTA_SPEDITO)
	print("  disco:   %d MiB liberi" % (_spazio() >> 20))
	print("  carico:  %s" % _carico())

	if not await _preflight():
		quit(1)
		return
	if OS.get_environment("CHIBI_SOLO_PREFLIGHT") == "1":
		quit(0)
		return

	if OS.get_environment("CHIBI_GIOCO") != "0":
		print("\n── il villaggio si accende (il fotogramma si misura con lui) ──")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		change_scene_to_file("res://scenes/levels/MainLevel.tscn")
		for _i in 30:
			await process_frame
		print("   MainLevel: %s" % ("acceso" if current_scene != null else "NON caricato"))

	# LA RETE PRIMA DI CHIEDERLA: il villaggio è acceso e gira, e non deve
	# avere NESSUNA connessione aperta. È il vincolo della Fase 5 misurato dal
	# vivo, non dedotto da una passata sui sorgenti.
	_sonda_rete("col villaggio acceso, prima di chiedere niente")

	process_frame.connect(_conta)
	await _il_viaggio()
	_racconta()
	quit(0)


## Chi ha aperto un socket, in questo processo, adesso. Si chiede a `lsof` su
## sé stessi — la stessa sonda con cui si è verificato che llama.cpp non tocca
## la rete. Costa ~50 ms: si chiama ai CONFINI dei blocchi, mai in mezzo, o si
## misurerebbe la sonda invece del gioco.
func _sonda_rete(quando: String) -> int:
	var fuori := []
	OS.execute("/usr/sbin/lsof", ["-nP", "-i", "-a", "-p", str(OS.get_process_id())], fuori, true)
	var righe := str(fuori[0] if fuori.size() > 0 else "").split("\n")
	var vive: Array[String] = []
	for r in righe:
		if r.contains("TCP") or r.contains("UDP"):
			vive.append(r.strip_edges())
	# ⚠️ niente parentesi quadra in testa alla riga: i filtri con cui si
	# leggono questi log («grep -v "^ *\["») mangiano le righe che cominciano
	# così, e la sonda sparisce senza che nessuno se ne accorga (successo).
	print("   rete · %s: %d connessioni" % [quando, vive.size()])
	for v in vive:
		print("          %s" % v.substr(v.find("TCP") if v.contains("TCP") else 0, 90))
	return vive.size()


# ---------------------------------------------------------------- preflight
## Dieci secondi, zero byte di modello: a monte c'è ancora QUEL file? È la
## stessa domanda che fa `release.yml` prima di quaranta minuti di CI, e la
## stessa che fa la macchina prima di due gigabyte e mezzo di rete.
func _preflight() -> bool:
	print("\n── il preflight (una HEAD, nessun byte di modello) ──")
	var rete := ScaricoRete.new()
	var t0 := Time.get_ticks_msec()
	var err := rete.chiedi(SCARICO.url(), MACCHINA.teste_di(-1), true)
	if err != OK:
		print("   NON PARTE: errore %d" % err)
		return false
	while true:
		var stato := rete.avanza()
		if stato == RETE.TESTE:
			break
		if stato == RETE.GUASTO:
			print("   GUASTO: la richiesta non è arrivata a destinazione")
			return false
		await process_frame
	var etag := MACCHINA.etag_pulito(rete.testa("x-linked-etag"))
	var dim := int(rete.testa("x-linked-size"))
	print("   codice %d in %d ms" % [rete.codice(), Time.get_ticks_msec() - t0])
	print("   x-linked-etag: %s" % (etag if etag != "" else "(non mandato)"))
	print("   x-linked-size: %d" % dim)
	print("   combacia con quello che il gioco pretende: impronta %s · peso %s"
			% ["SÌ" if etag == LLM.IMPRONTA_SPEDITO else "NO",
			"SÌ" if dim == SCARICO.DIMENSIONE else "NO"])
	rete.chiudi()
	return etag == "" or etag == LLM.IMPRONTA_SPEDITO


# ------------------------------------------------------------- il viaggio
func _il_viaggio() -> void:
	var quanto_acceso := float(OS.get_environment("CHIBI_ACCESO")) if OS.get_environment("CHIBI_ACCESO") != "" else 30.0
	var quanto_spento := float(OS.get_environment("CHIBI_SPENTO")) if OS.get_environment("CHIBI_SPENTO") != "" else 10.0
	print("\n── il viaggio: blocchi di %.0f s che scaricano e %.0f s fermi ──"
			% [quanto_acceso, quanto_spento])
	print("   (ogni «fermo» è un annullamento VERO, ogni ritorno una ripresa VERA)")

	_s = SCARICO.new()
	_s.name = "ScaricoBanco"
	root.add_child(_s)
	if _destinazione() != SCARICO.destinazione():
		_s.usa_questi_estremi(SCARICO.url(), _destinazione(), SCARICO.DIMENSIONE,
				LLM.IMPRONTA_SPEDITO)
	_s.comincia()
	_acceso = true
	_apri_blocco(true)
	_fine_blocco = _ora() + quanto_acceso

	var ultimo_racconto := 0.0
	while true:
		await process_frame
		var ora := _ora()
		# ⚠️ «è finita» si guarda SOLO nei blocchi accesi: nei blocchi fermi
		# l'esito è `annullato` perché l'ha chiesto questo banco, e leggerlo
		# come la fine del viaggio faceva chiudere tutto al primo blocco (una
		# corsa intera buttata per una riga di banco, non di corriere).
		if _acceso and _s.esito() != MACCHINA.ESITO_NIENTE:
			_chiudi_blocco()
			break
		if ora - ultimo_racconto > 5.0:
			ultimo_racconto = ora
			print("   %s · %s · %s"
					% [_s.frase_fase(), _fase_nome(_s.fase()),
					"%.2f MB/s" % (_s.al_secondo() / 1048576.0)])
		if ora >= _fine_blocco:
			# l'ultimo pezzo di strada (impronta e posa) non si interrompe: è
			# un lavoro di disco che non c'entra con la rete, e annullarlo
			# vorrebbe dire rileggere due gigabyte e mezzo un'altra volta
			# ⚠️ `_acceso` NON è decorativo qui: dopo un annullamento la fase
			# È già `fine`, che è «>= impronta» — senza quella condizione il
			# banco non riprende mai più e resta a girare in silenzio (mi è
			# costato una corsa da dieci minuti, ferma a 334 MiB).
			if _acceso and _s.fase() >= MACCHINA.FASE_IMPRONTA:
				continue
			_chiudi_blocco()
			if _acceso:
				# la rete MENTRE si scarica: dev'esserci UNA connessione, e
				# una sola. (Al confine del blocco: `lsof` costa 50 ms.)
				if _misure_annulla.is_empty():
					_sonda_rete("mentre scarica")
				# ANNULLAMENTO VERO, cronometrato: quanto ci mette il thread a
				# mollare una connessione aperta che sta ricevendo?
				var t0 := Time.get_ticks_usec()
				_s.annulla()
				while _s.esito() == MACCHINA.ESITO_NIENTE:
					await process_frame
				_misure_annulla.append((Time.get_ticks_usec() - t0) / 1000.0)
				if _s.esito() != MACCHINA.ESITO_ANNULLATO:
					break
				_acceso = false
				_fine_blocco = ora + quanto_spento
				# e SUBITO DOPO: annullare non è «smettere di aggiornare la
				# barra», è chiudere il socket. Qui si vede.
				if _misure_annulla.size() == 1:
					_sonda_rete("subito dopo l'annullamento")
			else:
				# RIPRESA VERA: il file c'è a metà, si riparte da lì
				_misure_ripresa += 1
				_s.comincia()
				_acceso = true
				_fine_blocco = ora + quanto_acceso
			_apri_blocco(_acceso)


func _apri_blocco(acceso: bool) -> void:
	_campioni.clear()
	_t_ultimo = 0
	# ⚠️ il byte d'inizio si legge dal FILE e non da `fatti()`: subito dopo un
	# `comincia()` il contatore vale zero per un istante, e un blocco che
	# comincia lì dentro «cresce» di un gigabyte e mezzo in trenta secondi —
	# la prima stesura dichiarava 35 MB/s su una linea da 7,4.
	_blocchi.append({"acceso": acceso, "t": _ora(), "campioni": null,
			"byte": _peso(_destinazione() + ".parte")})


func _chiudi_blocco() -> void:
	if _blocchi.is_empty():
		return
	var b: Dictionary = _blocchi[_blocchi.size() - 1]
	b["campioni"] = _campioni.duplicate()
	b["durata"] = _ora() - float(b["t"])
	b["byte_fine"] = _peso(_destinazione() + ".parte")


# ------------------------------------------------------------- il racconto
func _racconta() -> void:
	print("\n════════ COM'È ANDATA ════════")
	print("  esito:    %s" % _esito_nome(_s.esito()))
	print("  diagnosi: %s" % (_s.diagnosi() if _s.diagnosi() != "" else "(nessuna)"))
	print("  frase per chi gioca: «%s»" % SCARICO.frase(_s.esito()))
	print("  sul disco: %s" % _peso_umano(_destinazione()))
	print("  pezzo rimasto: %s" % _peso_umano(_destinazione() + ".parte"))
	print("\n  IL DIARIO DEL VIAGGIO")
	for riga in _s.diario():
		print("    · %s" % riga)

	print("\n  ANNULLAMENTI (quanto ci mette il thread a mollare la rete vera)")
	if _misure_annulla.is_empty():
		print("    nessuno")
	else:
		var somma := 0.0
		var peggio := 0.0
		for m in _misure_annulla:
			somma += m
			peggio = maxf(peggio, m)
		print("    %d annullamenti · medio %.1f ms · peggiore %.1f ms"
				% [_misure_annulla.size(), somma / _misure_annulla.size(), peggio])
	print("  RIPRESE: %d (ognuna con un `Range` vero sulla CDN firmata)" % _misure_ripresa)

	print("\n  IL FOTOGRAMMA, MISURA APPAIATA (blocchi alternati nella stessa corsa)")
	var acceso := _unisci(true)
	var spento := _unisci(false)
	_riga_fotogrammi("scarica", acceso)
	_riga_fotogrammi("fermo  ", spento)
	if not acceso.is_empty() and not spento.is_empty():
		var ma := _medio(acceso)
		var ms := _medio(spento)
		print("    scarto: %+.2f ms (%+.1f%%) sul fotogramma medio" % [ma - ms, (ma - ms) / ms * 100.0])

	# SE IL BANCO HA LAVORATO IN CASA SUA, il modello si porta dove il gioco lo
	# cerca. Non è cosmetica: la cartella vera è quella che `_pulisci()` dei
	# test cancella, e MISURATO il 2026-08-13 — una corsa della suite fatta da
	# un'altra sessione ha portato via 211 MiB di scarico a metà, in silenzio.
	# Un banco che dura dieci minuti non può tenere il suo lavoro lì.
	# ⚠️ **E SOLO SE GLIELO SI CHIEDE** (`CHIBI_POSA=1`). MISURATO il
	# 2026-08-13, e fa male: appena il file è atterrato in `user://modelli/`,
	# una corsa della suite fatta da un'altra sessione l'ha **cancellato** —
	# `test_offerta_modello.gd::_pulisci()` toglie `Scarico.destinazione()` e
	# il suo `.parte` per rimettere la schermata al punto di partenza. Due
	# gigabyte e mezzo e sei minuti, in silenzio, due volte di fila. Finché
	# quella pulizia lavora sulla cartella VERA, un banco che dura dieci
	# minuti tiene il suo lavoro in casa propria e lo consegna a mano.
	if OS.get_environment("CHIBI_POSA") == "1" \
			and _s.esito() == MACCHINA.ESITO_FATTO and _destinazione() != SCARICO.destinazione():
		if FileAccess.file_exists(SCARICO.destinazione()):
			print("\n  (il modello c'era già al suo posto: lascio il mio dov'è)")
		else:
			DirAccess.make_dir_recursive_absolute(SCARICO.destinazione().get_base_dir())
			var e := DirAccess.rename_absolute(_destinazione(), SCARICO.destinazione())
			print("\n  portato al suo posto (%s): %s"
					% [SCARICO.destinazione(), "fatto" if e == OK else "errore %d" % e])

	print("\n  LA VELOCITÀ DEL VIAGGIO")
	var byte_veri := 0
	var tempo_vero := 0.0
	for b in _blocchi:
		# ⚠️ si saltano i blocchi in cui il `.parte` è sparito sotto i piedi
		# (l'ultimo: il file ha preso il suo nome vero), o il conto va a
		# numeri negativi — la prima stesura dichiarava «-0.00 MB/s».
		if bool(b["acceso"]) and b.has("byte_fine") and int(b["byte_fine"]) > int(b["byte"]):
			byte_veri += int(b["byte_fine"]) - int(b["byte"])
			tempo_vero += float(b.get("durata", 0.0))
	if tempo_vero > 0.0:
		print("    %.1f MiB in %.1f s di blocchi accesi = %.2f MB/s"
				% [byte_veri / 1048576.0, tempo_vero, byte_veri / 1048576.0 / tempo_vero])
	print("    carico della macchina alla fine: %s" % _carico())


func _unisci(acceso: bool) -> Array[float]:
	var fuori: Array[float] = []
	for b in _blocchi:
		if bool(b["acceso"]) == acceso and b["campioni"] != null:
			fuori.append_array(b["campioni"] as Array[float])
	return fuori


func _riga_fotogrammi(nome: String, c: Array[float]) -> void:
	if c.is_empty():
		print("    %s: nessun campione" % nome)
		return
	var ord := c.duplicate()
	ord.sort()
	print("    %s: n=%d · medio %.2f ms · p50 %.2f · p99 %.2f · MAX %.2f"
			% [nome, c.size(), _medio(c), ord[ord.size() / 2],
			ord[mini(ord.size() - 1, int(ord.size() * 0.99))], ord[ord.size() - 1]])


func _medio(c: Array[float]) -> float:
	var s := 0.0
	for v in c:
		s += v
	return s / c.size()


# ---------------------------------------------------------------- i ferri
func _destinazione() -> String:
	var dove := OS.get_environment("CHIBI_DOVE")
	if dove == "":
		return SCARICO.destinazione()
	DirAccess.make_dir_recursive_absolute(dove)
	return dove.path_join(LLM.NOME_MODELLO)


func _spazio() -> int:
	var cartella := _destinazione().get_base_dir()
	DirAccess.make_dir_recursive_absolute(cartella)
	var d := DirAccess.open(cartella)
	return 0 if d == null else d.get_space_left()


func _ora() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _peso(p: String) -> int:
	if not FileAccess.file_exists(p):
		return 0
	var f := FileAccess.open(p, FileAccess.READ)
	return 0 if f == null else f.get_length()


func _peso_umano(p: String) -> String:
	if not FileAccess.file_exists(p):
		return "(non c'è)"
	var f := FileAccess.open(p, FileAccess.READ)
	return "%s (%d byte)" % [SCARICO.misura_umana(f.get_length()), f.get_length()]


func _fase_nome(f: int) -> String:
	return ["spazio", "preflight", "connette", "corpo", "impronta", "posa", "fine"][f]


func _esito_nome(e: int) -> String:
	return ["niente", "FATTO", "annullato", "spazio", "rete", "impronta",
			"sorgente", "chiuso", "disco", "senza impronta"][e]


func _carico() -> String:
	var out := []
	OS.execute("/usr/sbin/sysctl", ["-n", "vm.loadavg"], out)
	var carico := str(out[0] if out.size() > 0 else "").strip_edges()
	var out2 := []
	OS.execute("/usr/sbin/sysctl", ["-n", "vm.swapusage"], out2)
	return "%s · %s" % [carico, str(out2[0] if out2.size() > 0 else "").strip_edges()]
