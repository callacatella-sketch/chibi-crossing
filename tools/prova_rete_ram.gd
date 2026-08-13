extends SceneTree

## LA RETE DELLA RAM — cosa vede chi non ce la fa. (Cioè: quasi nessuno.)
##
## Il gioco spedisce un modello da 2,4 GB che ne chiede **2640** più il
## gigabyte che deve restare al gioco: su una macchina da 8 GB con qualcosa
## aperto, `Config::riserva_byte` lo rifiuta e la funzione si spegne da sola.
## Sulla macchina dell'AUTORE succede sempre. Non è un caso limite: è, con
## ogni probabilità, la maggioranza di chi giocherà.
##
## Perciò questo banco non prova che il villaggio pensi. Prova il contrario, e
## lo prova **nel MainLevel vero**, con la stessa riga che gira in partita
## (`CHIBI_RISERVA` NON si tocca — è la leva dei banchi, e qui si vuole
## esattamente il gioco che riceve chi compra):
##
##  1. il modello viene rifiutato, e in **quanto tempo** (il costo dell'ordine
##     dei cancelli: prima del 2026-08-13 erano trentasette secondi di lettura
##     di due gigabyte e mezzo per arrivare a un no che si sapeva già);
##  2. il nodo si spegne DAVVERO — `_process` fermo, nessun ritmo acceso: un
##     nodo che continua a riprovare è un costo pagato da chi non ne ha niente;
##  3. **il giocatore non vede niente.** Si scandaglia tutto l'albero della UI
##     — due reti: i pezzi letterali delle diagnosi del C++, e poi la diagnosi
##     VERA di questa corsa, parola per parola. Se una comparisse a schermo, il
##     gioco starebbe raccontando a chi gioca che gli manca un pezzo — che è la
##     cosa che la Fase 5 non ha il permesso di essere;
##  4. **il gioco continua**: i fotogrammi si contano prima e dopo il rifiuto,
##     e il villaggio si salva sul serio (`save_now()`), col file che cambia.
##
## ⚠️ SI APRE UNA FINESTRA VERA, senza `--headless`: il punto 3 vuole un albero
## di UI costruito, e il punto 4 vuole dei fotogrammi da contare. Headless non
## ha né l'uno né gli altri.
##
##     CHIBI_MODELLO=<file.gguf> ~/Downloads/Godot.app/Contents/MacOS/Godot \
##         --path . --resolution 1280x720 --script res://tools/prova_rete_ram.gd
##
## ⚠️ **E LA CONTROPROVA, che è quello che rende credibile il resto:** un banco
## che dicesse «rifiutato» comunque non misurerebbe niente. Si rifà con un
## modello PICCOLO (gemma-3-1b: 814 MB stimati, che su questa macchina ci
## stanno) e lo stato dev'essere «pensa». MISURATO il 2026-08-13: col 4B
## «guasto» in 1.35 s, col 1B «pensa» — stessa macchina, stessa corsa del
## banco, due esiti diversi.

const LLM := preload("res://systems/Llm.gd")
const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")

## LE FRASI DEL GUASTO — pezzi LETTERALI delle diagnosi di
## `Traduttore::_carica`, più le parole che in un gioco cozy non esistono.
##
## ⚠️ **LA PRIMA STESURA CERCAVA «memoria» E «modello», E SBAGLIAVA.** Il
## banco segnalava — giustamente, secondo la sua regola — la riga del pannello
## impostazioni: «Ogni tanto un vicino ha un'idea tutta sua. Chiede memoria al
## computer…», che è la DESCRIZIONE della leva, scritta apposta per chi gioca,
## e non ha niente a che vedere con un guasto. Una guardia che grida su una
## frase giusta è una guardia che si impara a ignorare.
##
## Quello che non deve comparire non è un argomento: è **una diagnosi**. Perciò
## si cercano i pezzi veri delle diagnosi, più il gergo che non appartiene a
## nessuna schermata di questo gioco.
const FRASI_DEL_GUASTO := [
	"MB liberi", "l'impronta non combacia", "non è un modello sano",
	"il modello chiede circa", "il contesto non si è creato",
	"il modello non si è aperto", "il gioco continua con i testi scritti a mano",
	"llm", "gguf", "llama", "sha-256", "sha256", "thread",
]

## Quanti residenti bastano perché il nodo si svegli. Non ventotto: qui non si
## misura il ritmo, si misura un rifiuto — e ne basta UNO perché
## `Pensieri._candidati()` smetta di essere vuoto (regola 2 del nodo).
const QUANTI := 3

var _pensieri: Node = null
var _vis: Node = null
var _build: Node = null
var _dn: Node = null
var _frame := 0
var _t_frame := 0


func _init() -> void:
	_go()


func _process(_d: float) -> bool:
	return false


func _conta() -> void:
	_frame += 1


func _go() -> void:
	print("")
	print("════════ LA RETE DELLA RAM — cosa vede chi non ce la fa ════════")
	print("  %s" % LLM.riga_di_stato())
	print("  modello: %s" % (LLM.percorso_modello() if LLM.percorso_modello() != "" else "(nessuno)"))
	print("  impronta armata: %s" % ("sì" if LLM.impronta_attesa(LLM.percorso_modello()) != "" else "no"))
	print("  porta:   Llm.acceso() = %s" % str(LLM.acceso()))
	print("  riserva forzata dal banco: %s"
			% (OS.get_environment("CHIBI_RISERVA") if OS.get_environment("CHIBI_RISERVA") != ""
			else "NESSUNA (è il gioco vero)"))
	var mem := _memoria()
	print("  macchina: %d MB in tutto · %d MB liberi · %s"
			% [int(mem.get("totale_sistema", 0)) / 1048576,
			int(mem.get("libera_sistema", 0)) / 1048576, _carico()])
	if not LLM.acceso():
		print("\n  La porta è chiusa: serve CHIBI_MODELLO su un binario `llm=yes`.")
		quit(1)
		return

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	process_frame.connect(_conta)

	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 8:
		await process_frame
	var livello := current_scene
	if livello == null:
		print("GUASTO: il MainLevel non si è caricato")
		quit(1)
		return
	_vis = livello.get_node_or_null("Visitors")
	_build = livello.get_node_or_null("BuildSystem")
	_dn = livello.get_node_or_null("DayNight")
	_pensieri = livello.get_node_or_null("Pensieri")
	if _pensieri == null or _vis == null:
		print("GUASTO: Pensieri=%s Visitors=%s" % [_pensieri, _vis])
		quit(1)
		return
	if _dn != null:
		_dn.set("cycle_seconds", 1000000.0)
		_dn.set("time", 0.42)
	await create_timer(1.0).timeout

	await _insedia()
	await _il_rifiuto()
	_il_nodo_si_spegne()
	_il_giocatore_non_vede_niente(livello)
	await _il_gioco_continua()
	print("")
	print("  %s" % _carico())
	print("")
	quit(0)


func _insedia() -> void:
	var residenti: Array = _vis.get("_residents")
	for k in QUANTI:
		var c := Vector2i(-6 + k * 2, 3)
		var v = VS.new()
		v.dna = DNAG.generate(4100 + k * 37)
		_vis.add_child(v)
		v.mode = "resident"
		v.position = Vector3(float(c.x), 0.0, float(c.y))
		v._enter_state("r_idle")
		var r := {"node": v, "label": "Rete%02d" % k, "dna": v.dna,
				"cell": c, "species": "chibi"}
		residenti.append(r)
		_vis.call("_ensure_brain", r)
	for _i in 8:
		await process_frame
	print("  residenti insediati: %d · cuore ECS: %s"
			% [QUANTI, "sì" if _vis.call("cuore") != null else "NO"])


# =========================================================================
# 1. IL RIFIUTO, e in quanto tempo
# =========================================================================

func _il_rifiuto() -> void:
	print("")
	print("  ── il nodo chiede il modello, e la macchina risponde ──")
	var t0 := Time.get_ticks_msec()
	var f0 := _frame
	# ⚠️ IL TETTO È GENEROSO APPOSTA (tre minuti). Con l'ordine dei cancelli
	# giusto il no arriva in meno di un secondo; con quello di prima ci
	# mettevano trentasette secondi. Un tetto stretto non distinguerebbe «è
	# lento» da «si è piantato», che sono due referti diversi.
	while Time.get_ticks_msec() - t0 < 180000:
		var m: Dictionary = _pensieri.call("misure")
		if str(m["stato"]) == "guasto" or str(m["stato"]) == "pensa":
			break
		await create_timer(0.05).timeout
	var dt := Time.get_ticks_msec() - t0
	var m: Dictionary = _pensieri.call("misure")
	print("  stato dopo %.2f s: «%s»" % [float(dt) / 1000.0, str(m["stato"])])
	print("  diagnosi: %s" % str(m.get("diagnosi", "(nessuna)")))
	print("  fotogrammi disegnati nel frattempo: %d (%.1f al secondo)"
			% [_frame - f0, float(_frame - f0) / maxf(float(dt) / 1000.0, 0.001)])
	if str(m["stato"]) == "pensa":
		print("  ⚠️ QUESTA MACCHINA CE LA FA (o CHIBI_RISERVA l'ha spenta):")
		print("     questo banco misura il ramo del rifiuto, e qui non c'è.")


# =========================================================================
# 2. IL NODO SI SPEGNE DAVVERO
# =========================================================================

func _il_nodo_si_spegne() -> void:
	print("")
	print("  ── e adesso non costa più niente ──")
	var m: Dictionary = _pensieri.call("misure")
	print("  _process acceso:  %s   (dev'essere false: un nodo spento non viene chiamato)"
			% str(_pensieri.is_processing()))
	print("  ritmo acceso:     %s   (dev'essere false: nessun Pensatoio allocato)"
			% str(m.get("acceso", false)))
	print("  pensieri partiti: %d" % int(m.get("pensieri", 0)))


# =========================================================================
# 3. IL GIOCATORE NON VEDE NIENTE
# =========================================================================

## Si scandaglia TUTTO l'albero della scena — non solo la UI che ci si
## aspetta — cercando le parole del guasto in ogni testo visibile. Un toast,
## una finestra di dialogo, un'etichetta d'angolo: qualunque cosa comparisse,
## il gioco starebbe dicendo a chi gioca che gli manca un pezzo.
func _il_giocatore_non_vede_niente(radice: Node) -> void:
	print("")
	print("  ── e non lo dice a nessuno ──")
	var visti: Array[String] = []
	_scandaglia(root, visti)
	if visti.is_empty():
		print("  nessuna frase del guasto a schermo: 0 su %d cercate"
				% FRASI_DEL_GUASTO.size())
	else:
		print("  ⚠️ A SCHERMO C'È:")
		for v in visti:
			print("     %s" % v)

	# E LA PROVA PIÙ DIRETTA: la diagnosi VERA, quella che il C++ ha scritto
	# in questa corsa, parola per parola. Le frasi qui sopra sono una rete a
	# maglie larghe che tiene anche per le diagnosi di domani; questa è la
	# rete a maglie strette per la diagnosi di oggi, e non si può eludere
	# riscrivendo un messaggio.
	var diagnosi := str((_pensieri.call("misure") as Dictionary).get("diagnosi", ""))
	var eco := 0
	if diagnosi != "":
		for c in root.find_children("*", "Label", true, false):
			var l := c as Label
			if l.is_visible_in_tree() and str(l.text).contains(diagnosi):
				eco += 1
	print("  la diagnosi di oggi, a schermo: %d volte (dev'essere 0)" % eco)
	print("     «%s»" % diagnosi)
	# E le finestre di dialogo: una popup vuol dire che il gioco si è fermato
	# per dire qualcosa, ed è il guasto peggiore di tutti.
	var popup := 0
	for n in root.find_children("*", "Window", true, false):
		if n != root and (n as Window).visible:
			popup += 1
	for n in root.find_children("*", "AcceptDialog", true, false):
		popup += 1
	print("  finestre di dialogo aperte: %d (dev'essere 0)" % popup)


## ⚠️ `is_visible_in_tree()`, NON `visible`. Il menu di pausa costruisce il
## pannello impostazioni all'avvio e lo tiene nascosto: le sue etichette hanno
## `visible = true` ognuna per conto suo, ed è un antenato a essere spento. Con
## `visible` il banco «vedeva» a schermo tutto il pannello — cioè misurava un
## albero, non uno schermo.
func _scandaglia(n: Node, dentro: Array[String]) -> void:
	for c in n.find_children("*", "Label", true, false):
		var l := c as Label
		_guarda(str(l.text), l.is_visible_in_tree(), "Label", dentro)
	for c in n.find_children("*", "RichTextLabel", true, false):
		var r := c as RichTextLabel
		_guarda(str(r.text), r.is_visible_in_tree(), "RichTextLabel", dentro)
	for c in n.find_children("*", "Button", true, false):
		var b := c as Button
		_guarda(str(b.text), b.is_visible_in_tree(), "Button", dentro)


func _guarda(testo: String, visibile: bool, che: String, dentro: Array[String]) -> void:
	if not visibile or testo.strip_edges() == "":
		return
	var basso := testo.to_lower()
	for p in FRASI_DEL_GUASTO:
		if basso.contains(str(p).to_lower()):
			dentro.append("%s «%s» (parola: %s)" % [che, testo, p])
			return


# =========================================================================
# 4. IL GIOCO CONTINUA — e si salva
# =========================================================================

func _il_gioco_continua() -> void:
	print("")
	print("  ── il gioco va avanti, e si salva ──")
	var f0 := _frame
	var t0 := Time.get_ticks_msec()
	await create_timer(4.0).timeout
	var fps := float(_frame - f0) / (float(Time.get_ticks_msec() - t0) / 1000.0)
	print("  %.1f fotogrammi al secondo dopo il rifiuto" % fps)

	if _build == null:
		print("  (nessun BuildSystem: il salvataggio non si può provare)")
		return
	# Il salvataggio VERO, con l'API pubblica (`save_now`, quella di chi sta
	# uscendo). Si guarda il file: un salvataggio che non scrive è un
	# salvataggio che non c'è.
	_build.call("set_persist_for_debug", true)
	var dove := "user://village.json"
	var prima := FileAccess.get_modified_time(ProjectSettings.globalize_path(dove))
	await create_timer(1.1).timeout
	_build.call("place_cell", Vector2i(-4, 6), "Panchina", 0, false)
	_build.call("save_now")
	await process_frame
	var dopo := FileAccess.get_modified_time(ProjectSettings.globalize_path(dove))
	var byte := 0
	var f := FileAccess.open(dove, FileAccess.READ)
	if f != null:
		byte = f.get_length()
		f.close()
	print("  village.json: %d byte · scritto adesso: %s"
			% [byte, "sì" if dopo != prima or prima == 0 else "no (stessa data)"])


# =========================================================================

func _memoria() -> Dictionary:
	var c := LLM.apri()
	if c == null:
		return {}
	return c.memoria()


func _carico() -> String:
	var out := []
	OS.execute("/usr/sbin/sysctl", ["-n", "vm.loadavg"], out)
	var out2 := []
	OS.execute("/usr/sbin/sysctl", ["-n", "vm.swapusage"], out2)
	return "loadavg %s · swap %s" % [
			str(out[0]).strip_edges() if not out.is_empty() else "?",
			str(out2[0]).strip_edges() if not out2.is_empty() else "?"]
