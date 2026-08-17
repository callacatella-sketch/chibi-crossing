extends SceneTree

## VENTI MINUTI DI PARTITA, COL MODELLO NEL PACCHETTO E LA MACCHINA CHE NON
## CE LA FA — cioè il gioco che riceve la maggioranza di chi comprerà.
##
##     CHIBI_MINUTI=20 CHIBI_TRACCIA=/tmp/t.txt CHIBI_FOTO=/tmp/foto \
##       <Gioco>.app/Contents/MacOS/Godot --path . --resolution 1280x720 \
##       --script res://tools/prova_partita_spedita.gd
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ NON BASTAVA NESSUNO DEI CINQUE BANCHI CHE C'ERANO
## ────────────────────────────────────────────────────────────────────────
##
## Dal 2026-08-13 il gioco spedisce il modello dentro il pacchetto, e questo
## crea un caso che **prima non esisteva**: `Llm.acceso()` è VERO per tutti
## (il file c'è) ma il modello **non si apre** (la rete della RAM lo rifiuta).
## Su una macchina da 8 GB è il caso NORMALE, non quello raro.
##
## MISURATO: `tools/prova_fase5_finale.gd` in questa configurazione si ferma
## dopo 29 secondi con «il modello non si è aperto — questo braccio non
## misura niente», e `prova_villaggio_pensa` fa lo stesso. È giusto per loro
## (misurano il villaggio che PENSA), ma vuol dire che **la partita della
## maggioranza non la guardava nessuno**. `prova_rete_ram` la guarda per
## nove secondi; qui si guarda per venti minuti.
##
## Le quattro domande, e nessuna è una dichiarazione:
##
##  1. **il giocatore si accorge di qualcosa?** Ogni dieci secondi si
##     scandaglia TUTTO l'albero della UI: le parole delle diagnosi del C++,
##     la diagnosi VERA di questa corsa parola per parola, e le finestre di
##     dialogo. Una sola comparsa, in venti minuti, è un fallimento.
##  2. **il fotogramma?** Si campiona OGNI fotogramma agganciandosi a
##     `process_frame`, e si stampa un minuto per riga. Più i venti
##     fotogrammi ATTORNO all'istante del rifiuto, che è l'unico momento in
##     cui il cuore che scrive tocca questo processo (apre un file, ne legge
##     l'intestazione, chiede la memoria alla macchina) — se un singhiozzo
##     c'è, è lì.
##  3. **il gioco si salva e se ne va?** `save_now()` VERO, sul file vero,
##     riletto e riaperto come JSON: un salvataggio che scrive spazzatura
##     scrive lo stesso.
##  4. **e il villaggio è lo STESSO?** Traccia del comportamento (stato,
##     azione dell'agenda, posizione al centimetro) ogni due secondi, da
##     confrontare con la stessa corsa sul binario `llm=no`.
##
## ⚠️ **GIRA IDENTICO NEI DUE BRACCI, ED È IL PUNTO.** Niente `quit(1)` se il
## modello non si apre: quel ramo È l'oggetto della misura. Sul binario
## `llm=no` lo stesso file fa la stessa identica partita — e quello è
## l'altro braccio.
##
## ⚠️ **NIENTE `--headless`**: la domanda 1 vuole un albero di UI costruito e
## la 2 vuole dei fotogrammi da contare. Headless non ha né l'uno né gli
## altri. L'orologio del giorno NON si ferma: un giocatore vero, in venti
## minuti, vede cinque albe — e quindi il sonno, le case, il buio.

const LLM := preload("res://systems/Llm.gd")
const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")

const MINUTI_DEF := 20.0
const QUANTI_DEF := 28
const SEME_DEF := 4242
const PASSO := 0.1                  # il battito del banco
const MOCHI_PASSO := 3.0

## Le parole che NON devono comparire a schermo. Sono i pezzi letterali delle
## diagnosi di `Traduttore::_carica` più il gergo che in un gioco cozy non
## esiste. (Stessa lista di `prova_rete_ram.gd`: se una diagnosi cambia, si
## cambiano tutte e due — ed è per questo che c'è ANCHE la rete a maglie
## strette sulla diagnosi vera di oggi, che non si può eludere riscrivendo
## un messaggio.)
const FRASI_DEL_GUASTO := [
	"MB liberi", "l'impronta non combacia", "non è un modello sano",
	"il modello chiede circa", "il contesto non si è creato",
	"il modello non si è aperto", "il gioco continua con i testi scritti a mano",
	"llm", "gguf", "llama", "sha-256", "sha256", "thread",
]

var _minuti := MINUTI_DEF
var _quanti := QUANTI_DEF
var _seme := SEME_DEF
var _traccia_fuori := ""
var _dove_foto := ""

var _vis: Node = null
var _dn: Node = null
var _build: Node = null
var _player: Node3D = null
var _pensieri: Node = null
var _residenti: Array = []

# il fotogramma
var _t_ultimo := 0
var _campioni := PackedFloat64Array()
var _avvio := PackedFloat64Array()
var _minuto := PackedFloat64Array()
var _attorno := PackedFloat64Array()
## I fotogrammi DURANTE l'attesa dell'esito: col modello che si apre davvero
## sono i sessantacinque secondi in cui il thread legge 2,4 GB e mappa i pesi.
## È lì che «il giocatore se ne accorge?» ha una risposta o non ce l'ha.
var _durante := PackedFloat64Array()
var _prendi_attorno := 0

# quello che il giocatore vede
var _viste: Array[String] = []
var _popup_max := 0
var _scansioni := 0

# il rifiuto
var _t_zero := 0
var _t_esito := -1
var _stato_finale := ""
var _diagnosi := ""

var _righe := PackedStringArray()
var _scatti := 0


func _init() -> void:
	_go()


func _process(_d: float) -> bool:
	return false


# ---------------------------------------------------------------- fotogramma

func _frame() -> void:
	var ora := Time.get_ticks_usec()
	if _t_ultimo != 0:
		var ms := float(ora - _t_ultimo) / 1000.0
		_campioni.append(ms)
		_minuto.append(ms)
		if _t_esito < 0:
			_durante.append(ms)
		if _prendi_attorno > 0:
			_prendi_attorno -= 1
			_attorno.append(ms)
	_t_ultimo = ora


func _stat(v: Array) -> String:
	if v.is_empty():
		return "(nessun campione)"
	var s := v.duplicate()
	s.sort()
	var somma := 0.0
	for x in s:
		somma += float(x)
	var p50 := float(s[int(s.size() * 0.5)])
	var doppi := 0
	for x in s:
		if float(x) > p50 * 2.0:
			doppi += 1
	return "n=%5d  medio %6.2f  p50 %6.2f  p99 %6.2f  MAX %7.2f  >2×p50: %d" % [
			s.size(), somma / float(s.size()), p50,
			float(s[mini(int(s.size() * 0.99), s.size() - 1)]),
			float(s[s.size() - 1]), doppi]


func _carico() -> String:
	var out := []
	OS.execute("/usr/sbin/sysctl", ["-n", "vm.loadavg"], out)
	var a := str(out[0]).strip_edges() if not out.is_empty() else "?"
	var out2 := []
	OS.execute("/usr/sbin/sysctl", ["-n", "vm.swapusage"], out2)
	return "loadavg %s · swap %s" % [a, str(out2[0]).strip_edges() if not out2.is_empty() else "?"]


# ---------------------------------------------------------------- il mondo

func _go() -> void:
	if OS.get_environment("CHIBI_MINUTI") != "":
		_minuti = float(OS.get_environment("CHIBI_MINUTI"))
	if OS.get_environment("CHIBI_QUANTI") != "":
		_quanti = int(OS.get_environment("CHIBI_QUANTI"))
	if OS.get_environment("CHIBI_SEME") != "":
		_seme = int(OS.get_environment("CHIBI_SEME"))
	_traccia_fuori = OS.get_environment("CHIBI_TRACCIA")
	_dove_foto = OS.get_environment("CHIBI_FOTO")
	if _dove_foto != "":
		DirAccess.make_dir_recursive_absolute(_dove_foto)

	print("")
	print("════════ VENTI MINUTI, COL MODELLO NEL PACCHETTO ════════")
	print("  %s" % LLM.riga_di_stato())
	print("  modello:  %s" % (LLM.percorso_modello() if LLM.percorso_modello() != "" else "(nessuno)"))
	print("  impronta: %s" % ("armata" if LLM.impronta_attesa(LLM.percorso_modello()) != "" else "no"))
	print("  porta:    disponibile()=%s · acceso()=%s"
			% [str(LLM.disponibile()), str(LLM.acceso())])
	print("  riserva forzata: %s"
			% (OS.get_environment("CHIBI_RISERVA") if OS.get_environment("CHIBI_RISERVA") != ""
			else "NESSUNA (è il gioco vero)"))
	print("  %.0f minuti · %d residenti · seme %d" % [_minuti, _quanti, _seme])
	print("  macchina: %s" % _carico())

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	seed(_seme)
	process_frame.connect(_frame)

	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 10:
		await process_frame
	var livello := current_scene
	if livello == null:
		print("GUASTO: il MainLevel non si è caricato")
		quit(1)
		return
	_vis = livello.get_node_or_null("Visitors")
	_build = livello.get_node_or_null("BuildSystem")
	_dn = livello.get_node_or_null("DayNight")
	_player = livello.get_node_or_null("Player") as Node3D
	_pensieri = livello.get_node_or_null("Pensieri")
	if _vis == null or _player == null or _pensieri == null:
		print("GUASTO: Visitors=%s Player=%s Pensieri=%s" % [_vis, _player, _pensieri])
		quit(1)
		return
	# ⚠️ LA PERSISTENZA RESTA SPENTA finché non si arriva al salvataggio: un
	# banco che scrivesse il `village.json` vero a ogni cella posata
	# riscriverebbe la partita di chi gioca. Si riaccende alla fine, che è
	# quando la domanda 3 comincia.
	if _build != null:
		_build.call("set_persist_for_debug", false)
	await create_timer(1.0).timeout

	_costruisci()
	await _insedia()
	_t_zero = Time.get_ticks_msec()
	print("  nodo «Pensieri» in scena: sì · nel gruppo: %s"
			% ("sì" if get_first_node_in_group("pensieri") == _pensieri else "no (porta chiusa)"))
	await _la_partita()
	_il_referto()
	await _il_salvataggio()
	print("")
	print("  %s" % _carico())
	quit(0)


func _cella(k: int) -> Vector2i:
	return Vector2i(-6 + (k % 7) * 2, 3 + (k / 7) * 2)


func _costruisci() -> void:
	if _build == null:
		return
	for k in 4:
		var z := 3 + k * 2
		for x in [-9, 9]:
			_build.call("place_cell", Vector2i(x, z), "Cespuglio", 0, false)
		for x in [-3, 3]:
			_build.call("place_cell", Vector2i(x, z), "Panchina", 0, false)
	_build.call("aggiorna_varchi_ora")


func _insedia() -> void:
	var residenti: Array = _vis.get("_residents")
	for k in _quanti:
		var c := _cella(k)
		var v = VS.new()
		v.dna = DNAG.generate(_seme + k * 37)
		_vis.add_child(v)
		v.mode = "resident"
		v.position = Vector3(float(c.x), 0.0, float(c.y))
		v._enter_state("r_idle")
		var r := {"node": v, "label": "Vicino%02d" % k, "dna": v.dna,
				"cell": c, "species": "chibi"}
		residenti.append(r)
		_vis.call("_ensure_brain", r)
	for _i in 8:
		await process_frame
	_residenti = residenti
	print("  residenti: %d · cuore ECS: %s"
			% [_residenti.size(), "sì" if _vis.call("cuore") != null else "NO"])


# ---------------------------------------------------------------- la partita

func _la_partita() -> void:
	print("")
	print("  ── LA PARTITA (l'orologio del giorno gira: cinque albe in venti minuti) ──")
	print("     minuto  %s" % "fotogrammi")
	# ⚠️ L'AVVIO SI CONTA A PARTE, o il MAX della partita è sempre il
	# caricamento del MainLevel (misurato: 2.2 s, e c'è in tutti e due i
	# bracci). «Nessun fotogramma perso all'avvio» è una domanda sua, e la
	# risposta è il confronto fra i due bracci di questa riga.
	_avvio = _campioni
	_campioni = PackedFloat64Array()
	_durante = PackedFloat64Array()
	_minuto = PackedFloat64Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = _seme
	var mete := []
	for r in _residenti:
		var n := (r as Dictionary).get("node") as Node3D
		if n != null and is_instance_valid(n):
			mete.append(n.global_position)
	if mete.is_empty():
		mete.append(Vector3.ZERO)
	var meta: Vector3 = mete[rng.randi() % mete.size()]
	var sosta := 0.0
	var verbi := ["annaffia", "costruisce", "raccoglie", "semina"]

	var t := 0.0
	var fine := _minuti * 60.0
	var pross_gesto := 8.0
	var pross_scan := 10.0
	var pross_minuto := 60.0
	var pross_foto := 30.0
	var pross_traccia := 2.0
	while t < fine:
		var p := _player.global_position
		if sosta > 0.0:
			sosta -= PASSO
		elif p.distance_to(Vector3(meta.x, p.y, meta.z)) < 0.6:
			sosta = rng.randf_range(2.0, 6.0)
			meta = mete[rng.randi() % mete.size()]
		else:
			var d := (Vector3(meta.x, p.y, meta.z) - p).normalized()
			_player.global_position = p + d * MOCHI_PASSO * PASSO
		pross_gesto -= PASSO
		if pross_gesto <= 0.0:
			pross_gesto = rng.randf_range(6.0, 14.0)
			call_group("percezione", "accaduto",
					str(verbi[rng.randi() % verbi.size()]),
					_player.global_position, "")
		# L'ESITO DEL MODELLO: si guarda a ogni battito, perché i venti
		# fotogrammi da fotografare sono quelli SUBITO DOPO.
		if _t_esito < 0:
			var m: Dictionary = _pensieri.call("misure")
			var st := str(m.get("stato", ""))
			if st == "guasto" or st == "pensa":
				_t_esito = Time.get_ticks_msec() - _t_zero
				_stato_finale = st
				_diagnosi = str(m.get("diagnosi", ""))
				_prendi_attorno = 20
				print("     t=%6.1f s  esito del modello: «%s» dopo %.2f s%s"
						% [t, st, float(_t_esito) / 1000.0,
						"" if _diagnosi == "" else " — " + _diagnosi])
		pross_scan -= PASSO
		if pross_scan <= 0.0:
			pross_scan = 10.0
			_scandaglia()
		pross_traccia -= PASSO
		if pross_traccia <= 0.0:
			pross_traccia = 2.0
			_campiona_traccia(t)
		pross_foto -= PASSO
		if pross_foto <= 0.0 and _dove_foto != "" and _scatti < 6:
			pross_foto = maxf(fine / 6.0, 30.0)
			await _scatta("t%04d" % int(t))
		pross_minuto -= PASSO
		if pross_minuto <= 0.0:
			pross_minuto = 60.0
			print("     %6.0f  %s" % [t / 60.0 + 1.0, _stat(Array(_minuto))])
			_minuto = PackedFloat64Array()
		await create_timer(PASSO).timeout
		t += PASSO


## ⚠️ `is_visible_in_tree()`, NON `visible`: il menu di pausa costruisce il
## pannello impostazioni all'avvio e lo tiene nascosto, e con `visible` questa
## rete «vedrebbe» a schermo tutto il pannello — cioè misurerebbe un albero,
## non uno schermo.
func _scandaglia() -> void:
	_scansioni += 1
	for c in root.find_children("*", "Label", true, false):
		_guarda(str((c as Label).text), (c as Label).is_visible_in_tree(), "Label")
	for c in root.find_children("*", "RichTextLabel", true, false):
		_guarda(str((c as RichTextLabel).text), (c as RichTextLabel).is_visible_in_tree(), "RichTextLabel")
	for c in root.find_children("*", "Button", true, false):
		_guarda(str((c as Button).text), (c as Button).is_visible_in_tree(), "Button")
	var popup := 0
	for n in root.find_children("*", "Window", true, false):
		if n != root and (n as Window).visible:
			popup += 1
	for n in root.find_children("*", "AcceptDialog", true, false):
		popup += 1
	_popup_max = maxi(_popup_max, popup)


func _guarda(testo: String, visibile: bool, che: String) -> void:
	if not visibile or testo.strip_edges() == "":
		return
	var basso := testo.to_lower()
	for p in FRASI_DEL_GUASTO:
		if basso.contains(str(p).to_lower()):
			_viste.append("%s «%s» (parola: %s)" % [che, testo, p])
			return
	if _diagnosi != "" and testo.contains(_diagnosi):
		_viste.append("%s «%s» (È LA DIAGNOSI DI OGGI)" % [che, testo])


func _campiona_traccia(t: float) -> void:
	if _traccia_fuori == "":
		return
	for r in _residenti:
		var rr: Dictionary = r
		var n := rr.get("node") as Node3D
		if n == null or not is_instance_valid(n):
			_righe.append("%7.1f %-10s SPARITO" % [t, str(rr.get("label", "?"))])
			continue
		_righe.append("%7.1f %-10s %-12s %7.2f %7.2f"
				% [t, str(rr.get("label", "?")), str(n.get("_state")),
				n.global_position.x, n.global_position.z])


func _scatta(nome: String) -> void:
	_scatti += 1
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_dove_foto, nome])


# ---------------------------------------------------------------- il referto

func _il_referto() -> void:
	print("")
	print("  ── 1. QUELLO CHE IL GIOCATORE VEDE ──")
	print("     scansioni dell'albero della UI: %d (una ogni 10 s)" % _scansioni)
	if _viste.is_empty():
		print("     frasi del guasto a schermo: 0 su %d cercate" % FRASI_DEL_GUASTO.size())
	else:
		print("     ⚠️ A SCHERMO C'È:")
		for v in _viste:
			print("        %s" % v)
	print("     finestre di dialogo aperte (massimo visto): %d" % _popup_max)
	print("     la diagnosi di questa corsa: «%s»" % _diagnosi)

	print("")
	print("  ── 2. IL FOTOGRAMMA ──")
	print("     l'AVVIO (mondo + villaggio, prima del via)  %s" % _stat(Array(_avvio)))
	print("     la partita intera   %s" % _stat(Array(_campioni)))
	print("     durante l'attesa    %s" % _stat(Array(_durante)))
	print("     i 20 dopo l'esito   %s" % _stat(Array(_attorno)))
	var m: Dictionary = _pensieri.call("misure")
	print("     stato del nodo: «%s» · _process acceso: %s · ritmo acceso: %s · pensieri: %d"
			% [str(m.get("stato", "")), str(_pensieri.is_processing()),
			str(m.get("acceso", false)), int(m.get("pensieri", 0))])
	print("     misure del nodo: %s" % str(m))
	if _t_esito >= 0:
		print("     l'esito è arrivato dopo %.2f s dall'insediamento" % (float(_t_esito) / 1000.0))
	else:
		print("     nessun esito: il nodo non ha mai chiesto niente (porta chiusa)")


func _il_salvataggio() -> void:
	print("")
	print("  ── 3. SI SALVA, E SE NE VA ──")
	if _build == null:
		print("     (nessun BuildSystem)")
		return
	_build.call("set_persist_for_debug", true)
	var dove := "user://village.json"
	var vero := ProjectSettings.globalize_path(dove)
	var prima := FileAccess.get_modified_time(vero)
	await create_timer(1.1).timeout
	_build.call("place_cell", Vector2i(-4, 6), "Panchina", 0, false)
	var t0 := Time.get_ticks_usec()
	_build.call("save_now")
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	await process_frame
	var f := FileAccess.open(dove, FileAccess.READ)
	var byte := 0
	var testo := ""
	if f != null:
		testo = f.get_as_text()
		byte = testo.length()
		f.close()
	# ⚠️ NON BASTA CHE IL FILE CI SIA: un salvataggio che scrive spazzatura
	# scrive lo stesso, e il giocatore lo scopre al riavvio.
	var apribile := JSON.parse_string(testo) != null
	print("     save_now(): %.2f ms · %d byte · scritto adesso: %s · riapribile come JSON: %s"
			% [ms, byte, "sì" if FileAccess.get_modified_time(vero) != prima or prima == 0 else "NO",
			"sì" if apribile else "NO"])
	if _traccia_fuori != "":
		var ft := FileAccess.open(_traccia_fuori, FileAccess.WRITE)
		if ft != null:
			for riga in _righe:
				ft.store_line(riga)
			ft.close()
		print("     traccia: %s (%d righe)" % [_traccia_fuori, _righe.size()])
