class_name BuildSystem
extends Node3D

## Modalità costruzione stile Animal Crossing.
##
## B entra/esce · rotella o 1-9 scegli · R ruota il pezzo · F ruota un
## oggetto già piazzato · clic piazza · X rimuovi. La griglia è del
## GridManager C++ (1 cella = 1 metro, celle centrate sugli interi).
##
## I pezzi "cell" occupano una cella su 3 layer sovrapponibili
## (pavimento / tappeto / oggetto). I pezzi "edge" (muri, staccionate,
## porte, finestre) stanno sui BORDI tra le celle, come in AC: il cursore
## aggancia il bordo più vicino e l'orientamento segue il bordo.
## Ogni pezzo piazzato riceve le sue collisioni (StaticBody3D).
##
## Il villaggio si salva da solo (user://village.json) a ogni piazzamento,
## rimozione o rotazione, e riappare al prossimo avvio.

signal mode_changed(active: bool)
## Il villaggio è cambiato (pezzo piazzato/rimosso, o caricamento finito):
## i sistemi che tengono cache di pezzi (Garden, Mail, Calendar…) si
## rinfrescano qui invece di riscandire tutto a ogni frame.
signal placed_changed

# preload esplicito: non dipende dalla cache globale delle class_name
const CATALOG := preload("res://scenes/build/BuildCatalog.gd")
const GRID_SHADER := preload("res://shaders/grid.gdshader")
const VARCHI := preload("res://scenes/build/Varchi.gd")
## L'Atelier: lo studio che ritrae i pezzi, e il taccuino che ragiona.
const MINIATURE := preload("res://scenes/build/Miniature.gd")
const CONSIGLI := preload("res://scenes/build/Consigli.gd")

const VALID_TINT := Color(0.45, 0.9, 0.5, 0.38)
const INVALID_TINT := Color(0.95, 0.35, 0.3, 0.42)
const UI_BROWN := Color("6a4a3a")
const CAT_NAMES := ["Struttura", "Arredo", "Giardino", "Palestra", "Chiesa",
		"Boutique"]

var _grid: GridManager
var _items: Array[Dictionary] = []
var _index := 0
var _rot := 0
var _active := false
var _valid := false

# cursore corrente
var _cursor_key := Vector2i.ZERO      # celle: coordinate cella · bordi: coordinate raddoppiate
var _cursor_pos := Vector3.ZERO
var _cursor_yaw := 0.0
var _hover_cell := Vector2i.ZERO
var _mouse_world := Vector3.ZERO

var _ghost: Node3D
var _overlay: StandardMaterial3D
var _grid_plane: MeshInstance3D
var _placed_root: Node3D
# celle per layer (3 = tetti) + bordi, chiave -> StaticBody3D/Node3D
var _placed := {0: {}, 1: {}, 2: {}, 3: {}, "edge": {}}

# il piano di sopra: stesse chiavi, quota +FLOOR_H. Il tasto V alterna
# il piano attivo in modalità costruzione.
const FLOOR_H := 2.15
const UP_AUTO := ["Solaio", "Ponticello"]
var _level := 0
var _placed_up := {0: {}, 1: {}, 2: {}, 3: {}, "edge": {}}

# offset locali della Casa albero (base scala, cima, trespolo ospiti)
const TH_BASE := Vector3(0, 0, 2.35)
const TH_TOP := Vector3(0, 2.62, 0.85)
const TH_PERCH := Vector3(-0.72, 2.62, 0.72)

# porte animate, tetti e muri (nodo -> mesh per le dissolvenze), demolizione
var _player: Node3D
var _doors: Array[Dictionary] = []
var _roofs := {}
var _roof_fade := 0.0
var _walls := {}
# pezzi del piano di sopra (solai, ponticelli, arredo): dissolvono
# quando Mochi è al piano terra, sotto di loro
var _ups := {}
var _up_fade := 0.0
# le lanterne che dondolano (Casa albero)
var _lanterns: Array[Node3D] = []
var _sway_t := 0.0

const WALL_ITEMS := ["Muro", "Finestra", "Porta"]
var _demolish := false
var _demo_btn: Button
var _demo_target: Node3D
var _demo_overlay: StandardMaterial3D

const INTERACTABLE := ["Sedia", "Sgabello", "Panchina", "Letto"]

# L'autoload viene registrato a metà della prima scansione del filesystem,
# quindi al primo avvio non è ancora visibile al parser: lo risolviamo a
# runtime (var non tipizzata = chiamate dinamiche, nessun errore di parse).
var _sfx
# il CozyWorld: sa dove scorre il fiume (lì non si costruisce)
var _cozy: Node3D

var _ui: CanvasLayer
var _panel: PanelContainer
var _idle_hint: Label
var _items_row: GridContainer
var _items_scroll: ScrollContainer
var _cat_buttons: Array[Button] = []
var _item_buttons: Array[Button] = []
var _cat := 0

# ============================================================ IL BANCO DEI PEZZI
# Il catalogo è passato da una manciata di pezzi a CENTOTRENTASETTE, e la
# riga sola che li conteneva è diventata illeggibile: trentotto bottoni
# schiacciati in una fascia larga quanto lo schermo non sono un menù, sono
# un righello. Peggio: i tasti 1-9 coprivano i primi nove e basta, e la
# rotella scorreva l'intero catalogo un pezzo alla volta.
#
# Il banco nuovo ha tre idee, e ognuna toglie un modo di perdersi:
#
#  1. LA GRIGLIA. I pezzi stanno in righe da CO​LONNE bottoni a larghezza
#     FISSA, dentro una finestra che scorre: un bottone è largo uguale che
#     ce ne siano tre o quaranta, quindi il nome si legge SEMPRE. La
#     finestra ha un'altezza fissa: il pannello non salta più cambiando
#     categoria.
#  2. LA RICERCA. Con centotrentasette pezzi, ricordarsi in che categoria
#     sta la Fioriera è un lavoro. Si preme «/» e si scrive: la griglia
#     mostra i pezzi di TUTTE le categorie che contengono quelle lettere,
#     nel nome tradotto e in quello italiano (il salvataggio parla
#     italiano: chi gioca in inglese trova «planter» E «fioriera»).
#  3. I RECENTI. Chi costruisce una casa usa cinque pezzi in cerchio per
#     dieci minuti. La prima scheda è la loro: gli ultimi pezzi POSATI, in
#     ordine di quando li hai usati. Non è una preferenza da configurare —
#     è il gioco che guarda cosa stai facendo.
#
# E i pezzi sotto chiave non stanno più mescolati ai tuoi: la griglia li
# raccoglie in fondo, sotto la loro intestazione, così la prima cosa che
# vedi è SEMPRE quello che puoi posare adesso.

## Quanti pezzi ricorda la scheda dei recenti.
const RECENTI_MAX := 12
## L'indice della scheda «recenti» fra i bottoni delle categorie.
const CAT_RECENTI := -1

var _ricerca := ""                  # il testo cercato ("" = nessuna ricerca)
var _ricerca_attiva := false        # si sta scrivendo adesso?
var _ricerca_label: Label
var _conta_label: Label
var _recenti: Array[String] = []    # nomi dei pezzi posati, dal più recente
var _cat_recenti_btn: Button
var _visibili: Array[int] = []      # gli indici mostrati adesso, in ordine

# --- recinto degli "Ordini del Gufo" ---------------------------------------
# Il catalogo si apre a poco a poco: è GufoOrders che, sbloccando gli Ordini,
# passa qui l'insieme dei pezzi disponibili (apply_unlocks). Di DEFAULT il
# recinto è spento (_locks_active = false) e tutto è libero: così i test, la
# CLI degli screenshot e i salvataggi antecedenti agli Ordini restano a
# catalogo pieno, senza sapere niente di questa meccanica.
var _unlocked := {}
var _locks_active := false
var _order_banner: Label
var _order_pill: PanelContainer

# --- economia: varianti di colore comprate dal mercante (vedi Economy.gd) ---
# _variant è il colore scelto per il PROSSIMO pezzo da piazzare ("" = originale)
var _variant := ""
var _eco: Node
var _variant_bar: PanelContainer
var _variant_dock: CenterContainer
var _variant_row: HBoxContainer

## Per gli screenshot da CLI: se impostato, il fantasma usa questa
## posizione invece del mouse.
var debug_ghost_pos := Vector3.INF

# persistenza: il villaggio si risalva da solo a ogni modifica
# (var e non const: la verifica CLI lo punta a un file di prova)
var save_path := "user://village.json"
var _persist := true
var _loading := false


func _ready() -> void:
	add_to_group("build_system")
	_sfx = get_node_or_null(^"/root/Sfx")
	_player = get_node_or_null("%Player")
	_cozy = get_node_or_null("../CozyWorld")

	_demo_overlay = StandardMaterial3D.new()
	_demo_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_demo_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_demo_overlay.albedo_color = Color(0.95, 0.3, 0.25, 0.45)
	_demo_overlay.render_priority = 10

	_grid = GridManager.new()
	_grid.grid_size = 1.0
	add_child(_grid)

	_placed_root = Node3D.new()
	_placed_root.name = "Placed"
	add_child(_placed_root)

	_items = CATALOG.items()

	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = VALID_TINT
	_overlay.render_priority = 10

	_build_grid_plane()
	_build_ui()
	_build_variant_bar()
	_refresh_ghost()

	# IL TACCUINO SI SPORCA, NON SI RIFÀ. Caricare un villaggio posa
	# cinquecento pezzi uno per uno: rileggere i fatti a ogni `placed_changed`
	# vorrebbe dire cinquecento passate sul villaggio intero dentro lo
	# stesso frame. Si alza una bandiera, e a fine frame si legge una
	# volta sola — l'idioma di `request_save`.
	placed_changed.connect(func(): _taccuino_sporco = true)

	# in modalità screenshot CLI la demo costruisce una casetta di prova:
	# niente caricamento né salvataggio, il villaggio vero resta intatto
	_persist = OS.get_environment("CHIBI_SHOT") == ""
	if _persist:
		# i persistable che nascono dopo il load (mondo differito) si servono
		# da soli via node_added: vedi _on_node_added
		get_tree().node_added.connect(_on_node_added)
		_load_village.call_deferred()
	_hook_economy.call_deferred()


func is_active() -> bool:
	return _active


func item_index(piece: String) -> int:
	for i in _items.size():
		if _items[i]["name"] == piece:
			return i
	return -1  # nome sconosciuto: mai trasformarlo in silenzio nel pezzo 0


# --------------------------------------------------- Ordini del Gufo: API
# GufoOrders guida il recinto e interroga il villaggio da qui. Tutto ciò
# che serve alla progressione passa per questi metodi: BuildSystem non sa
# nulla del contenuto degli Ordini (zero accoppiamento col loro testo).

## True se il pezzo è disponibile — o se il recinto è spento (catalogo pieno).
func is_unlocked(piece: String) -> bool:
	# i pezzi del NEGOZIO si sbloccano SOLO comprandoli (a parte dagli Ordini)
	var eco := _economy()
	if eco and eco.has_method("is_shop_piece") and eco.is_shop_piece(piece):
		return eco.is_piece_unlocked(piece)
	# I COMPAGNI DI CORREDO. Un corredo si paga in blocco (240-700
	# noccioline) e `Economy.unlock_piece` sblocca il capo INSIEME ai suoi
	# compagni — ma qui l'economia veniva interrogata solo per i 24 nomi di
	# `SHOP_PIECES`, e i compagni non ci sono. Restavano sotto chiave con la
	# promessa di un Ordine del Gufo che per loro non arriva MAI
	# (l'intersezione fra i compagni e i pezzi della campagna è VUOTA):
	# pagavi la caserma e ricevevi l'autopompa da sola, il bar e ti arrivava
	# il bancone in una stanza vuota.
	# Si INTERROGA l'economia, non si sostituisce il recinto: se il corredo
	# non è stato comprato si ricade sulla regola normale, così a recinto
	# spento (catalogo pieno: veterani, CLI, provini, catalogo visivo) i
	# compagni restano liberi esattamente come prima.
	if eco and eco.has_method("is_piece_unlocked") and _padrone_corredo(piece) != "" \
			and eco.is_piece_unlocked(piece):
		return true
	return not _locks_active or _unlocked.has(piece)


## GufoOrders passa qui l'insieme dei pezzi sbloccati. active=false spegne il
## recinto (catalogo pieno: veterani, CLI, test). Ricostruisce la UI e, se il
## pezzo selezionato è finito sotto chiave, scivola al primo libero.
func apply_unlocks(names: Array, active: bool) -> void:
	_locks_active = active
	_unlocked.clear()
	for n in names:
		_unlocked[str(n)] = true
	if _items.is_empty():
		return  # UI/catalogo non ancora pronti: si riapplica da _build_ui
	if _locks_active and not is_unlocked(str(_items[_index]["name"])):
		var first := _first_unlocked_index()
		if first >= 0:
			_index = first
			_cat = int(_items[_index]["cat"])
			_refresh_ghost()
	if not _item_buttons.is_empty():
		_rifai_sinistra()
		_rebuild_item_row()
		_sync_ui_selection()
	_taccuino_sporco = true


func _first_unlocked_index() -> int:
	for i in _items.size():
		if is_unlocked(str(_items[i]["name"])):
			return i
	return -1


# il vicino sbloccato nella direzione data (per la rotella), saltando i pezzi
# ancora sotto chiave; se non ce n'è, resta dov'è
## Il pezzo posabile dopo (o prima) DENTRO quello che si sta guardando.
## Prima girava su tutto il catalogo: con centotrentasette pezzi la
## rotella era un viaggio, e ti portava fuori dalla categoria senza che
## l'avessi chiesto. Se la vista corrente non ha nulla di posabile si
## ripiega sul catalogo intero, perché una rotella che non fa niente
## sembra rotta.
func _next_unlocked(dir: int) -> int:
	var lista := _visibili if not _visibili.is_empty() else _pezzi_visibili()
	var posabili: Array[int] = []
	for i in lista:
		if is_unlocked(str(_items[i]["name"])):
			posabili.append(i)
	if posabili.is_empty():
		var n := _items.size()
		for step in range(1, n + 1):
			var i2 := posmod(_index + dir * step, n)
			if is_unlocked(str(_items[i2]["name"])):
				return i2
		return _index
	var dove := posabili.find(_index)
	if dove < 0:
		return posabili[0] if dir > 0 else posabili[posabili.size() - 1]
	return posabili[posmod(dove + dir, posabili.size())]


## Conteggio dei pezzi piazzati per nome (tutti i piani e i layer): il
## vocabolario con cui GufoOrders valuta gli Ordini.
func piece_counts() -> Dictionary:
	var out := {}
	for dicts in [_placed, _placed_up]:
		for layer in [0, 1, 2, 3, "edge"]:
			for node in (dicts[layer] as Dictionary).values():
				var nm: String = (node as Node3D).get_meta("item_name", "")
				out[nm] = int(out.get(nm, 0)) + 1
	return out


## C'è un Letto con un tetto/solaio sopra la sua cella? (Ordine "una stanza
## per un ospite" — è la stessa condizione del trasloco dei Visitatori.)
func has_bed_under_roof() -> bool:
	for bed in get_placed_by_name("Letto"):
		var cell := Vector2i(roundi(bed.position.x), roundi(bed.position.z))
		if has_cover(cell):
			return true
	return false


## Il testo dell'Ordine in corso, in cima al pannello di costruzione (o "" per
## nasconderlo). Lo aggiorna GufoOrders.
func set_order_banner(text: String) -> void:
	if _order_banner == null:
		return
	_order_banner.text = text
	_order_banner.visible = text != ""
	if _order_pill != null:
		_order_pill.visible = text != ""


# i dizionari del piano richiesto (0 = terra, 1 = sopra)
func _dicts(lvl: int) -> Dictionary:
	return _placed_up if lvl == 1 else _placed


## C'è qualcosa sopra la testa in questa cella? Tetto a terra, solaio o
## tetto del piano di sopra. Usato dal trasloco ("un letto col tetto").
func has_cover(cell: Vector2i) -> bool:
	return (_placed[3] as Dictionary).has(cell) \
			or (_placed_up[0] as Dictionary).has(cell) \
			or (_placed_up[3] as Dictionary).has(cell)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	# LA RICERCA PRIMA DI TUTTO. Mentre si scrive, «R» è una erre e non una
	# rotazione: se il builder leggesse i suoi tasti prima, cercare
	# «brandina» farebbe ruotare il fantasma cinque volte e cambiare piano.
	if _active and _ricerca_attiva and event is InputEventKey \
			and event.pressed and not event.echo:
		if _ricerca_tasto(event as InputEventKey):
			get_viewport().set_input_as_handled()
			return
	if _active and event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_SLASH:
		_ricerca_accendi()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("build_toggle"):
		_set_active(not _active)
		get_viewport().set_input_as_handled()
		return
	if not _active:
		return

	# TAB PIEGA L'ATELIER, non lo chiude. Si legge prima delle altre
	# scorciatoie perché è l'unica che parla del pannello e non del
	# villaggio, e perché in Godot il Tab girerebbe altrimenti al giro
	# del fuoco (che qui non esiste: tutti i controlli sono FOCUS_NONE).
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_TAB \
			and event.pressed and not event.echo:
		_piega(not _aperto)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("build_level"):
		_set_level(1 - _level)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("build_rotate"):
		if not _demolish:
			_rot = (_rot + 1) % 4
			_bounce(_ghost)
			if _sfx: _sfx.rotate_tick()
	elif event.is_action_pressed("build_rotate_placed"):
		_rotate_placed()
	elif event.is_action_pressed("build_place"):
		if _demolish:
			_try_remove()
		else:
			_try_place()
	elif event.is_action_pressed("build_remove"):
		_try_remove()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select(_next_unlocked(-1))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select(_next_unlocked(1))
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			# il numero conta i pezzi POSABILI di quello che stai
			# guardando, nello stesso ordine in cui la griglia li stampa
			# sui bottoni: il «3» del cartellino e il «3» della tastiera
			# devono essere lo stesso pezzo, sempre
			var quale: int = event.keycode - KEY_1
			var posabili: Array[int] = []
			for i2 in _visibili:
				if is_unlocked(str(_items[i2]["name"])):
					posabili.append(i2)
			if quale < posabili.size():
				_select(posabili[quale])
			elif _sfx:
				_sfx.place_deny()


func _set_active(active: bool) -> void:
	_active = active
	if not active:
		_set_demolish(false)
	_ghost.visible = active and not _demolish
	_grid_plane.visible = active
	_panel.visible = active
	_idle_hint.visible = not active
	_update_variant_bar()
	if active:
		# APRIRE È IL MOMENTO IN CUI SI GUARDA: il taccuino si rilegge (il
		# villaggio è cambiato mentre l'Atelier era chiuso) e i ritratti
		# delle carte in vista si mettono in coda. Chiuso non si chiede
		# niente e non si conta niente: un pannello invisibile non costa.
		_taccuino_sporco = true
		_rifai_sinistra()
		_sync_ui_selection()
		_chiedi_visibili.call_deferred()
		CozyUI.appear(_panel, 0.26)
	if _sfx:
		if active:
			_sfx.build_open()
		else:
			_sfx.build_close()
	mode_changed.emit(active)


## Attiva la modalità build con fantasma in una posizione fissa (per debug/CLI).
func set_active_for_debug(active: bool, ghost_world_pos: Vector3, item_name := "") -> void:
	debug_ghost_pos = ghost_world_pos
	if item_name != "" and item_index(item_name) >= 0:
		_select(item_index(item_name))
	_set_active(active)


# ---------------------------------------------------------------- selezione

## COSA SI VEDE ADESSO, in ordine. Una funzione sola, e la usano tutti:
## la griglia per disegnarsi, i tasti 1-9 per sapere chi è il terzo, la
## rotella per sapere chi viene dopo. Se le tre cose avessero tre liste
## diverse, il «3» del cartellino e il «3» della tastiera finirebbero su
## due pezzi diversi — ed è il genere di bugia che non dà nessun errore.
##
## L'ordine è: prima quello che puoi posare ADESSO, poi la merce del
## mercante (col prezzo: sai per cosa stai risparmiando), poi quello che
## arriva da sé. Dentro ogni gruppo resta l'ordine del catalogo, che è
## quello con cui il villaggio è stato pensato.
func _pezzi_visibili() -> Array[int]:
	var liberi: Array[int] = []
	var vetrina: Array[int] = []
	var attesa: Array[int] = []
	var candidati: Array[int] = []
	if _ricerca != "":
		candidati = _cerca_indici(_ricerca)
	elif _cat == CAT_RECENTI:
		# i recenti NON si riordinano per stato: l'ordine è quello con cui
		# li hai usati, ed è tutto il valore della scheda
		var out: Array[int] = []
		for nome in _recenti:
			var i := item_index(nome)
			if i >= 0:
				out.append(i)
		return out
	elif _cat == CAT_TUTTO:
		for i2 in _items.size():
			candidati.append(i2)
	elif _cat <= CAT_SET:
		# UN CORREDO NON È UNA CATEGORIA, è un posto: il bar, la caserma,
		# la boutique. I suoi pezzi vivono sparsi in tre categorie diverse
		# e non si vedevano mai insieme. L'elenco si legge da
		# `Economy.CORREDO` (fonte unica), col capo per primo.
		candidati = _indici_corredo(CAT_SET - _cat)
	else:
		candidati = _cat_item_indices(_cat)
	for i in candidati:
		var nome := str(_items[i]["name"])
		if is_unlocked(nome):
			liberi.append(i)
		elif not _shop_offer(nome).is_empty():
			vetrina.append(i)
		else:
			attesa.append(i)
	var tutti: Array[int] = []
	tutti.append_array(liberi)
	tutti.append_array(vetrina)
	tutti.append_array(attesa)
	return tutti


## La ricerca guarda il nome TRADOTTO e quello italiano. Il nome italiano
## è la chiave del salvataggio e non cambia mai: chi gioca in inglese e
## legge una guida italiana trova il pezzo lo stesso, e viceversa.
func _cerca_indici(testo: String) -> Array[int]:
	var q := testo.strip_edges().to_lower()
	var out: Array[int] = []
	if q == "":
		return out
	for i in _items.size():
		var nome := str(_items[i]["name"])
		if nome.to_lower().contains(q) or L10n.t(nome).to_lower().contains(q):
			out.append(i)
	return out


## Un pezzo POSATO entra nei recenti (in testa, senza doppioni). Si segna
## quando si posa, non quando si seleziona: sfogliare il catalogo non è
## usare un pezzo, e una scheda «recenti» che si riempie sfogliando
## diventa la copia della categoria che stavi guardando.
func _segna_recente(piece: String) -> void:
	if piece == "":
		return
	_recenti.erase(piece)
	_recenti.push_front(piece)
	while _recenti.size() > RECENTI_MAX:
		_recenti.pop_back()
	if _cat_recenti_btn and is_instance_valid(_cat_recenti_btn):
		_spegni_riga(_cat_recenti_btn, _recenti.is_empty())
	if _cat == CAT_RECENTI and _panel and _panel.visible:
		_rebuild_item_row()
	elif not _aperto:
		_rifai_striscia()


## Gli indici del corredo numero k, nell'ordine in cui il corredo è
## scritto (il capo per primo): è l'ordine con cui quel posto è stato
## pensato, e vale più di un riordino alfabetico.
func _indici_corredo(k: int) -> Array[int]:
	var out: Array[int] = []
	var corr := _corredi()
	var capi := corr.keys()
	if k < 0 or k >= capi.size():
		return out
	var nomi: Array = [capi[k]]
	nomi.append_array(corr[capi[k]])
	for n in nomi:
		var i := item_index(str(n))
		if i >= 0:
			out.append(i)
	return out


func _cat_item_indices(cat: int) -> Array[int]:
	var out: Array[int] = []
	for i in _items.size():
		if _items[i]["cat"] == cat:
			out.append(i)
	return out


func _select(i: int) -> void:
	# un pezzo ancora sotto chiave non si seleziona: piccolo diniego
	if _locks_active and not is_unlocked(str(_items[i]["name"])):
		if _sfx: _sfx.place_deny()
		return
	_set_demolish(false)
	_index = i
	# le VISTE (ricerca, recenti, «tutto», un corredo) non sono categorie:
	# saltare alla categoria del pezzo scelto cancellerebbe la lista che
	# stavi guardando proprio nell'istante in cui l'hai usata
	if _ricerca == "" and _cat >= 0 and _items[i]["cat"] != _cat:
		_cat = _items[i]["cat"]
		_rebuild_item_row()
	# i pezzi del piano di sopra portano il cursore su da soli
	if bool(_items[i].get("up", false)) and _level == 0:
		_set_level(1)
	_refresh_ghost()
	_sync_ui_selection()
	# «vicino ai tuoi X c'è quasi sempre Y» parla del pezzo IN MANO: se il
	# taccuino non si rileggesse qui, resterebbe a raccontare il pezzo
	# di prima — cioè una cosa vera detta della cosa sbagliata
	_taccuino_sporco = true
	if _sfx: _sfx.ui_select()


# alterna il piano di costruzione: la griglia sale a quota solaio
func _set_level(lvl: int) -> void:
	if _level == lvl:
		return
	_level = lvl
	if _ghost:
		_bounce(_ghost)
	if _sfx:
		_sfx.rotate_tick()


func _refresh_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
	var builder: Callable = _items[_index]["builder"]
	_ghost = builder.call()
	_ghost.visible = _active
	add_child(_ghost)
	for mi in _ghost.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).transparency = 0.45
		(mi as MeshInstance3D).material_overlay = _overlay
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for light in _ghost.find_children("*", "Light3D", true, false):
		(light as Light3D).visible = false
	for part in _ghost.find_children("*", "GPUParticles3D", true, false):
		(part as GPUParticles3D).emitting = false
	# il ghost del Tetto non deve fermare la pioggia a mezz'aria
	for pc in _ghost.find_children("*", "GPUParticlesCollision3D", true, false):
		(pc as GPUParticlesCollision3D).cull_mask = 0
	# tinge il fantasma col colore scelto e aggiorna la barra dei colori
	_apply_ghost_variant()
	_update_variant_bar()


# ---------------------------------------------------------------- cursore

func _process(delta: float) -> void:
	_update_doors()
	_update_roof_fade(delta)
	_update_up_fade(delta)
	_update_wall_fade(delta)

	# le lanterne delle case sull'albero dondolano piano nel vento
	_sway_t += delta
	for pivot in _lanterns:
		if is_instance_valid(pivot):
			pivot.rotation.z = sin(_sway_t * 1.35) * 0.15
			pivot.rotation.x = sin(_sway_t * 0.9 + 1.3) * 0.09

	# il taccuino si rilegge al massimo una volta per fotogramma, e SOLO
	# se qualcuno lo sta guardando
	if _taccuino_sporco and _active and _aperto and _panel and _panel.visible:
		_rifai_taccuino()

	if not _active or _ghost == null:
		return

	# un pezzo del piano di sopra (Solaio, Ponticello…) vive sempre al
	# piano 1: cursore e validazione lo seguono anche col piano attivo a 0
	var eff := _level
	if not _demolish and bool(_items[_index].get("up", false)):
		eff = 1
	var lvl_y := FLOOR_H * float(eff)
	var world_pos: Vector3
	if debug_ghost_pos != Vector3.INF:
		world_pos = debug_ghost_pos
	else:
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var mouse := get_viewport().get_mouse_position()
		var from := cam.project_ray_origin(mouse)
		var dir := cam.project_ray_normal(mouse)
		if absf(dir.y) < 0.0001 or (lvl_y - from.y) / dir.y < 0.0:
			return
		world_pos = from + dir * ((lvl_y - from.y) / dir.y)

	_mouse_world = world_pos
	# lo snap alla cella lo fa il GridManager (C++)
	var cell_pos: Vector3 = _grid.snap_to_grid(world_pos)
	_hover_cell = Vector2i(roundi(cell_pos.x), roundi(cell_pos.z))
	_grid_plane.position = Vector3(_hover_cell.x, 0.015 + lvl_y, _hover_cell.y)

	# modalità demolizione: evidenzia in rosso il pezzo sotto il cursore
	if _demolish:
		_update_demolish_target()
		return

	var item := _items[_index]
	if item["type"] == "edge":
		_update_edge_cursor(world_pos)
	else:
		_cursor_key = _hover_cell
		_cursor_pos = Vector3(_hover_cell.x, lvl_y, _hover_cell.y)
		_cursor_yaw = -_rot * PI * 0.5
		_valid = not (_dicts(eff)[item["layer"]] as Dictionary).has(_cursor_key)
		if eff == 1:
			_valid = _valid and _up_supported(item, _cursor_key)
		# sul fiume non si costruisce (i ponti ci sono già, e sono belli)
		if _valid and _cozy \
				and bool(_cozy.call("is_river", Vector3(_cursor_key.x, 0, _cursor_key.y))):
			_valid = false

	_ghost.position = _ghost.position.lerp(_cursor_pos, 1.0 - exp(-22.0 * delta))
	_ghost.rotation.y = lerp_angle(_ghost.rotation.y, _cursor_yaw, 1.0 - exp(-18.0 * delta))
	_overlay.albedo_color = VALID_TINT if _valid else INVALID_TINT


# bordo più vicino al cursore: orizzontale (lungo X) o verticale (lungo Z)
func _update_edge_cursor(p: Vector3) -> void:
	var lvl_y := FLOOR_H * float(_level)
	var hz := floorf(p.z) + 0.5
	var h_center := Vector3(roundf(p.x), lvl_y, hz)
	var vx := floorf(p.x) + 0.5
	var v_center := Vector3(vx, lvl_y, roundf(p.z))
	var flip := PI if _rot % 2 == 1 else 0.0
	if absf(p.z - hz) <= absf(p.x - vx):
		_cursor_pos = h_center
		_cursor_yaw = 0.0 + flip
	else:
		_cursor_pos = v_center
		_cursor_yaw = PI * 0.5 + flip
	_cursor_key = Vector2i(roundi(_cursor_pos.x * 2.0), roundi(_cursor_pos.z * 2.0))
	_valid = not (_dicts(_level)["edge"] as Dictionary).has(_cursor_key)
	# di sopra, un muro vuole un solaio in una delle due celle che separa
	if _valid and _level == 1:
		var ok := false
		for cell in _edge_neighbor_cells(_cursor_key):
			if (_placed_up[0] as Dictionary).has(cell):
				ok = true
		_valid = ok


# le due celle separate da un bordo (chiave raddoppiata)
func _edge_neighbor_cells(key: Vector2i) -> Array[Vector2i]:
	if posmod(key.y, 2) == 1:
		# bordo orizzontale: celle a nord e sud
		@warning_ignore("integer_division")
		var cy := (key.y - 1) / 2
		@warning_ignore("integer_division")
		return [Vector2i(key.x / 2, cy), Vector2i(key.x / 2, cy + 1)]
	@warning_ignore("integer_division")
	var cx := (key.x - 1) / 2
	@warning_ignore("integer_division")
	return [Vector2i(cx, key.y / 2), Vector2i(cx + 1, key.y / 2)]


# regola di sostegno del piano di sopra: un solaio vuole un appoggio
# (muro a terra sul perimetro, solaio/ponticello vicino, o una Scala o
# Casa albero in una cella adiacente); tutto il resto vuole un solaio.
func _up_supported(item: Dictionary, cell: Vector2i) -> bool:
	if not str(item["name"]) in UP_AUTO:
		return (_placed_up[0] as Dictionary).has(cell)
	# muri a terra sul perimetro della cella
	var edges := [
		Vector2i(cell.x * 2, cell.y * 2 - 1), Vector2i(cell.x * 2, cell.y * 2 + 1),
		Vector2i(cell.x * 2 - 1, cell.y * 2), Vector2i(cell.x * 2 + 1, cell.y * 2),
	]
	for e in edges:
		var wall = (_placed["edge"] as Dictionary).get(e)
		if wall and str((wall as Node3D).get_meta("item_name", "")) in WALL_ITEMS:
			return true
	for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var near := cell + off
		if (_placed_up[0] as Dictionary).has(near):
			return true
		var ground = (_placed[2] as Dictionary).get(near)
		if ground == null:
			ground = (_placed[2] as Dictionary).get(cell)
		if ground and str((ground as Node3D).get_meta("item_name", "")) in ["Scala", "Casa albero"]:
			return true
	return false


func _edge_key_to_transform(key: Vector2i) -> Array:
	var pos := Vector3(key.x * 0.5, 0, key.y * 0.5)
	var yaw := 0.0 if posmod(key.y, 2) == 1 else PI * 0.5
	return [pos, yaw]


# ------------------------------------------------------- porte e tetti

# Da che parte si apre l'anta: una porta VERA si spinge, quindi ruota
# VIA da chi la sta attraversando. z_locale è la posizione del passante
# nello spazio della porta (l'anta chiusa vive sul piano z=0).
static func verso_porta(z_locale: float) -> float:
	return 1.95 if z_locale > 0.0 else -1.95


# Le porte si aprono da sole al passaggio — di Mochi E dei residenti
# (gruppo "passanti"): prima gli abitanti le attraversavano da fantasmi.
# L'anta recita da anta: spinta con un piccolo overshoot che si assesta
# (il legno ha peso), richiusa più lenta che accelera come per gravità
# e AGGANCIA col chiavistello sull'ultimo grado. Cigolio in apertura,
# cigolio corto + tonfo e scatto in chiusura, ogni volta a pitch diverso.
func _update_doors() -> void:
	if _doors.is_empty():
		return
	var passanti := get_tree().get_nodes_in_group("passanti")
	for d in _doors:
		var hinge := d["hinge"] as Node3D
		if hinge == null or not is_instance_valid(hinge):
			continue
		# il più vicino tra Mochi e i passanti (la soglia è sul CARDINE,
		# non sulla base del nodo: la porta della casa sull'albero sta in quota)
		var qui := hinge.global_position
		var vicino: Node3D = null
		var best := 1.35
		if _player != null:
			var dp := _player.global_position.distance_to(qui)
			if dp < best:
				best = dp
				vicino = _player
		for w in passanti:
			if w is Node3D and is_instance_valid(w):
				var dw := (w as Node3D).global_position.distance_to(qui)
				if dw < best:
					best = dw
					vicino = w
		var open := vicino != null
		if open == bool(d["open"]):
			continue
		d["open"] = open
		if d.has("tw") and d["tw"] != null and (d["tw"] as Tween).is_valid():
			(d["tw"] as Tween).kill()
		var tw := create_tween()
		d["tw"] = tw
		if open:
			# via da chi spinge: il lato lo dice la posizione locale
			# rispetto al PIANO dell'anta (nella casa sull'albero il
			# varco non sta sull'origine del nodo)
			var girata := verso_porta((d["node"] as Node3D).to_local(
					vicino.global_position).z - float(d.get("piano_z", 0.0)))
			d["girata"] = girata
			# la spinta: oltre il segno di un soffio, poi si assesta
			tw.tween_property(hinge, "rotation:y", girata * 1.07, 0.34) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(hinge, "rotation:y", girata, 0.28) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			if _sfx:
				_sfx.play("cigolio", -12.0, randf_range(0.9, 1.14))
				_sfx.play("door_open", -20.0)   # il fiato d'aria sotto il cigolio
		else:
			var girata := float(d.get("girata", -1.95))
			# ricade come per gravità fin quasi al telaio...
			tw.tween_property(hinge, "rotation:y", girata * 0.05, 0.5) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			# ...e il chiavistello la tira dentro con lo scatto
			if _sfx:
				tw.tween_callback(_sfx.play.bind("door_close", -14.0))
			tw.tween_property(hinge, "rotation:y", 0.0, 0.1) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			if _sfx:
				_sfx.play("cigolio", -19.0, 1.35)   # il lamento corto del rientro


# quando Mochi è sotto un tetto (a terra o in quota), i tetti dissolvono
var _roof_fade_applied := -1.0
var _up_fade_applied := -1.0


func _update_roof_fade(delta: float) -> void:
	if _roofs.is_empty():
		return
	var target := 0.0
	if _player:
		var cell := Vector2i(roundi(_player.global_position.x), roundi(_player.global_position.z))
		if (_placed[3] as Dictionary).has(cell) or (_placed_up[3] as Dictionary).has(cell):
			target = 0.85
	_roof_fade = lerpf(_roof_fade, target, 1.0 - exp(-9.0 * delta))
	if absf(_roof_fade - target) < 0.001:
		_roof_fade = target  # converso: da qui in poi niente riscritture
	if is_equal_approx(_roof_fade, _roof_fade_applied):
		return
	_roof_fade_applied = _roof_fade
	for meshes in _roofs.values():
		for mi in meshes:
			mi.transparency = _roof_fade


# quando Mochi è al piano terra sotto un solaio, il piano di sopra
# intero (solai, ponticelli, arredo) si dissolve per lasciarla vedere
func _update_up_fade(delta: float) -> void:
	if _ups.is_empty():
		return
	var target := 0.0
	if _player and _player.global_position.y < FLOOR_H - 0.7:
		var cell := Vector2i(roundi(_player.global_position.x), roundi(_player.global_position.z))
		if (_placed_up[0] as Dictionary).has(cell):
			target = 0.85
	_up_fade = lerpf(_up_fade, target, 1.0 - exp(-9.0 * delta))
	if absf(_up_fade - target) < 0.001:
		_up_fade = target
	if is_equal_approx(_up_fade, _up_fade_applied):
		return
	_up_fade_applied = _up_fade
	for meshes in _ups.values():
		for mi in meshes:
			mi.transparency = _up_fade


func _register_special(item_name: String, node: Node3D) -> void:
	node.set_meta("item_name", item_name)
	var lvl := int(node.get_meta("lvl", 0))
	if item_name == "Porta":
		var hinge := node.find_child("Hinge", true, false)
		if hinge:
			_doors.append({"node": node, "hinge": hinge, "open": false})
	if item_name == "Casa albero":
		var pivot := node.find_child("LanternaPivot", true, false)
		if pivot:
			_lanterns.append(pivot)
		# anche la casetta lassù ha la sua anta col cardine (il piano
		# dell'anta sta a z=0.32 nello spazio del nodo, non sull'origine)
		var anta := node.find_child("Hinge", true, false)
		if anta:
			_doors.append({"node": node, "hinge": anta, "open": false,
					"piano_z": 0.32})
		# una casa sull'albero nuova di zecca merita gli anelli
		if not _loading:
			var gtree := get_tree().get_first_node_in_group("grande_albero")
			if gtree:
				gtree.engrave_once("casa_albero", "★", "è nata una casa sull'albero")
	if item_name == "Tetto":
		var meshes: Array[MeshInstance3D] = []
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			meshes.append(mi)
			(mi as MeshInstance3D).transparency = _roof_fade
		_roofs[node] = meshes
	elif item_name in WALL_ITEMS:
		var meshes: Array[MeshInstance3D] = []
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			meshes.append(mi)
		_walls[node] = {"meshes": meshes, "fade": 0.0}
	elif lvl == 1:
		# solai, ponticelli e arredo del piano di sopra: dissolvono
		# quando Mochi sta sotto di loro
		var meshes: Array[MeshInstance3D] = []
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			meshes.append(mi)
			(mi as MeshInstance3D).transparency = _up_fade
		_ups[node] = meshes


func _unregister_special(node: Node3D) -> void:
	var item_name: String = node.get_meta("item_name", "")
	if item_name == "Porta":
		_doors = _doors.filter(func(d): return d["node"] != node)
	if item_name == "Casa albero":
		var pivot := node.find_child("LanternaPivot", true, false)
		_lanterns.erase(pivot)
	if item_name == "Tetto":
		_roofs.erase(node)
	elif item_name in WALL_ITEMS:
		_walls.erase(node)
	else:
		_ups.erase(node)


# muri "cutaway" alla The Sims: quando un muro sta tra la camera e Mochi
# (cioè quando lei è dietro o dentro casa), si dissolve per lasciarti vedere
func _update_wall_fade(delta: float) -> void:
	if _walls.is_empty() or _player == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var pp := _player.global_position
	pp.y = 0.0
	var cp := cam.global_position
	cp.y = 0.0
	var seg := pp - cp
	var seg_len2 := seg.length_squared()
	var k := 1.0 - exp(-10.0 * delta)
	for node in _walls:
		var w: Dictionary = _walls[node]
		var wp: Vector3 = (node as Node3D).global_position
		wp.y = 0.0
		var target := 0.0
		if seg_len2 > 0.01:
			var t := (wp - cp).dot(seg) / seg_len2
			if t > 0.15 and t < 0.97 and wp.distance_to(cp + seg * t) < 1.15:
				target = 0.82
		var f := lerpf(w["fade"], target, k)
		w["fade"] = f
		# i muri del piano di sopra seguono anche la dissolvenza dei solai
		if int((node as Node3D).get_meta("lvl", 0)) == 1:
			f = maxf(f, _up_fade)
		if absf(f - float(w.get("shown", -1.0))) > 0.0004:
			w["shown"] = f
			for mi in w["meshes"]:
				(mi as MeshInstance3D).transparency = f
				(mi as MeshInstance3D).cast_shadow = \
						GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if f > 0.4 \
						else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Superficie sotto una posizione: "wood" sul pavimento, "stone" sul
## sentiero, altrimenti "grass". Usata per i suoni dei passi.
func surface_at(pos: Vector3) -> String:
	var cell := Vector2i(roundi(pos.x), roundi(pos.z))
	# al piano di sopra si cammina sull'assito
	if pos.y > 1.2 and (_placed_up[0] as Dictionary).has(cell):
		return "wood"
	var floor_node = (_placed[0] as Dictionary).get(cell)
	if floor_node:
		var n: String = (floor_node as Node3D).get_meta("item_name", "")
		return "stone" if n == "Sentiero" else "wood"
	return "grass"


## Tutti i pezzi piazzati con un certo nome (es. "Cassetta posta"),
## su qualunque layer e piano.
func get_placed_by_name(item_name: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for dicts in [_placed, _placed_up]:
		for layer in [0, 1, 2, 3, "edge"]:
			for node in (dicts[layer] as Dictionary).values():
				if (node as Node3D).get_meta("item_name", "") == item_name:
					out.append(node)
	return out


## I pezzi su cui ci si può sedere o dormire (per il sistema di interazione).
func get_interactables() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for dicts in [_placed, _placed_up]:
		for node in (dicts[2] as Dictionary).values():
			var n: String = (node as Node3D).get_meta("item_name", "")
			if n in INTERACTABLE:
				out.append({"node": node, "name": n})
				continue
			# I POSTI DICHIARATI. Un pezzo grande non e' una seduta sola nel
			# suo centro: il gazebo e la serra dichiarano DOVE ci si siede,
			# col nodo «Posto*» e il meta «seduta» (l'ancoraggio E' il
			# posto). Prima li trovavano solo i vicini — il giocatore
			# poteva guardare due sedie da giardino e non sedersi.
			for posto in (node as Node3D).find_children("Posto*", "Node3D", true, false):
				if (posto as Node3D).has_meta("seduta"):
					out.append({"node": posto, "name": "Posto"})
	return out


# ---------------------------------------------------------------- azioni

func _try_place() -> void:
	# rete di sicurezza: il pezzo selezionato dev'essere sbloccato
	if _locks_active and not is_unlocked(str(_items[_index]["name"])):
		_shake(_ghost)
		if _sfx: _sfx.place_deny()
		return
	if not _valid:
		_shake(_ghost)
		if _sfx: _sfx.place_deny()
		return
	var item := _items[_index]
	# i pezzi di legno si pagano in legna tagliata (se il boschetto c'è)
	var wc := get_tree().get_first_node_in_group("woodcutting")
	if wc and not wc.can_afford_piece(str(item["name"])):
		_shake(_ghost)
		if _sfx: _sfx.place_deny()
		wc.deny_toast(str(item["name"]))   # dice QUANTA legna manca
		return
	var v := _variant_for_current()
	if item["type"] == "edge":
		place_edge(_cursor_key, item["name"], _rot % 2 == 1, true, _level, v)
	else:
		place_cell(_cursor_key, item["name"], _rot, true, _level, v)
	if wc:
		wc.pay_for_piece(str(item["name"]))
	# il pezzo appena POSATO entra nei recenti: è il gesto vero, non lo
	# sfogliare il catalogo
	_segna_recente(str(item["name"]))
	if _sfx: _sfx.place_ok()
	get_tree().call_group("regista", "note", "costruzione")
	# il posto del pezzo, non quello di Mochi: `_cursor_pos` è il punto in
	# metri di mondo del cursore — il centro della cella per i pezzi, il
	# centro del bordo per le staccionate — ed è dove il vicino guarda.
	get_tree().call_group("percezione", "accaduto", "costruisce", _cursor_pos)


## LA FILA CONTINUA. Piu' gradinate affiancate nella stessa direzione
## sono UNA platea: il bracciolo di pietra vive solo sui fianchi liberi.
## Qui, a ogni piazzamento o rimozione, la cella toccata e le sue vicine
## si guardano intorno: chi ha una gradinata di pari rotazione sul fianco
## spegne il bracciolo da quel lato, chi resta capofila lo tiene.
## Statica e senza stato (lavora sul dizionario cella->nodo di un layer):
## i test la fanno girare su un dizionario finto, senza scena.
static func rinfresca_braccioli(dict: Dictionary, cell: Vector2i) -> void:
	for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, 1), Vector2i(0, -1)]:
		var nodo := dict.get(cell + d) as Node3D
		if nodo == null or str(nodo.get_meta("item_name", "")) != "Gradinata":
			continue
		var rot := posmod(int(nodo.get_meta("rot", 0)), 4)
		var passo := passo_fila(rot)
		_bracciolo_acceso(nodo, "BraccioloDx",
				not _fila_continua(dict, cell + d + passo, rot))
		_bracciolo_acceso(nodo, "BraccioloSx",
				not _fila_continua(dict, cell + d - passo, rot))


## IL SENTIERO CHE SI RICONOSCE: quando si posa (o si toglie) un
## Sentiero, la sua cella e le quattro vicine si RICOSTRUISCONO le pietre
## chiedendo al catalogo la posa giusta per i vicini che hanno adesso —
## e due celle affiancate diventano UNA passata continua. Stesso patto
## della Gradinata coi braccioli: statico e guidato dal dizionario, così
## si prova a occhi chiusi.
static func rinfresca_sentieri(dict: Dictionary, cell: Vector2i) -> void:
	for d: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, 1), Vector2i(0, -1)]:
		var c := cell + d
		var nodo := dict.get(c) as Node3D
		if nodo == null or str(nodo.get_meta("item_name", "")) != "Sentiero":
			continue
		var vicini := {
			"e": _e_sentiero(dict, c + Vector2i(1, 0)),
			"o": _e_sentiero(dict, c + Vector2i(-1, 0)),
			"s": _e_sentiero(dict, c + Vector2i(0, 1)),
			"n": _e_sentiero(dict, c + Vector2i(0, -1)),
		}
		# il seme è della CELLA: la stessa cella rifà sempre le stesse
		# pietre, e i salvataggi non ballano da un caricamento all'altro
		var nuovo: Node3D = BuildCatalog.sentiero_cella(vicini,
				int(hash(c)) & 0x7fffffff)
		var vecchie := nodo.get_node_or_null("Pietre")
		if vecchie:
			vecchie.name = "PietreVecchie"
			vecchie.queue_free()
		var pietre: Node3D = nuovo.get_node("Pietre")
		nuovo.remove_child(pietre)
		nodo.add_child(pietre)
		# i vicini sono in coordinate MONDO, ma il nodo può essere stato
		# posato ruotato (R): il wrapper annulla la rotazione del pezzo
		pietre.rotation.y = -nodo.rotation.y
		nuovo.free()


static func _e_sentiero(dict: Dictionary, c: Vector2i) -> bool:
	var nodo := dict.get(c) as Node3D
	return nodo != null and str(nodo.get_meta("item_name", "")) == "Sentiero"


## L'AIUOLA CHE SI UNISCE: posata (o tolta) un'Aiuola, la sua cella e le
## quattro vicine si RIFANNO la terra chiedendo al catalogo la forma
## giusta per i vicini che hanno adesso — e due aiuole affiancate
## diventano UNA striscia di terra continua. Stesso patto del Sentiero:
## statico e guidato dal dizionario, si prova a occhi chiusi. Si scambia
## solo il figlio «Terra»: il velo d'acqua e i germogli del Garden
## stanno appesi alla radice del pezzo e non si toccano.
static func rinfresca_aiuole(dict: Dictionary, cell: Vector2i) -> void:
	for d: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, 1), Vector2i(0, -1)]:
		var c := cell + d
		var nodo := dict.get(c) as Node3D
		if nodo == null or str(nodo.get_meta("item_name", "")) != "Aiuola":
			continue
		var vicini := {
			"e": _e_aiuola(dict, c + Vector2i(1, 0)),
			"o": _e_aiuola(dict, c + Vector2i(-1, 0)),
			"s": _e_aiuola(dict, c + Vector2i(0, 1)),
			"n": _e_aiuola(dict, c + Vector2i(0, -1)),
		}
		# il seme è della CELLA: la stessa cella rifà sempre le stesse
		# zolle, e i salvataggi non ballano da un caricamento all'altro
		var nuovo: Node3D = BuildCatalog.aiuola_cella(vicini,
				int(hash(c)) & 0x7fffffff)
		var vecchia := nodo.get_node_or_null("Terra")
		if vecchia:
			vecchia.name = "TerraVecchia"
			vecchia.queue_free()
		var terra: Node3D = nuovo.get_node("Terra")
		nuovo.remove_child(terra)
		nodo.add_child(terra)
		# i vicini sono in coordinate MONDO, ma il nodo può essere stato
		# posato ruotato (R): il wrapper annulla la rotazione del pezzo
		terra.rotation.y = -nodo.rotation.y
		nuovo.free()


## LE SERRE CHE SI FONDONO. Due serre vicine non sono due serre: sono una
## serra piu' grande. Il gruppo e' 8-CONNESSO (due che si toccano d'angolo
## sono un edificio solo: i loro gusci si compenetrerebbero comunque), e da
## quello escono la pianta e la geometria di ogni campata — BuildCatalog fa
## il disegno, qui si decide solo CHI va rifatto.
##
## Non si tocca MAI: la chiave nel dizionario, l'identita' del nodo, i meta
## item_name/rot/variant/lvl. Percio' il salvataggio non cambia di un byte e
## get_placed_by_name("Serra") continua a contare N celle per N serre.
static func e_serra(dict: Dictionary, c: Vector2i) -> bool:
	var nodo := dict.get(c) as Node3D
	return nodo != null and str(nodo.get_meta("item_name", "")) == "Serra"


## Il gruppo di serre attaccate a `c` (flood fill 8-connesso). `viste` e'
## condiviso fra piu' chiamate cosi' una cella non finisce in due giri.
static func gruppo_serra(dict: Dictionary, c: Vector2i, viste := {}) -> Array:
	if not e_serra(dict, c) or viste.has(c):
		return []
	var fuori: Array = []
	var coda: Array = [c]
	viste[c] = true
	while not coda.is_empty():
		var q: Vector2i = coda.pop_back()
		fuori.append(q)
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var v := q + Vector2i(dx, dz)
				if not viste.has(v) and e_serra(dict, v):
					viste[v] = true
					coda.append(v)
	return fuori


## Rifa' la geometria e le collisioni di un gruppo intero. Il figlio
## «Vetreria» si RINOMINA prima di liberarlo: un nodo in coda tiene occupato
## il nome fino a fine frame, e il nuovo diventerebbe «Vetreria2» — al
## rinfresco dopo non lo troveresti piu'.
static func ricostruisci_serra(dict: Dictionary, celle: Array) -> void:
	if celle.is_empty():
		return
	var pianta := BuildCatalog.serra_pianta(celle)
	for c: Vector2i in celle:
		var nodo := dict.get(c) as Node3D
		if nodo == null:
			continue
		var vecchia := nodo.find_child("Vetreria", true, false)
		var ospite: Node3D = nodo
		if vecchia != null:
			ospite = vecchia.get_parent() as Node3D
			vecchia.name = "VetreriaVecchia"
			ospite.remove_child(vecchia)
			vecchia.queue_free()
		var radice: Node3D = BuildCatalog.serra_cella(pianta, c)
		var campata: Node3D = radice.get_node("Vetreria")
		radice.remove_child(campata)
		ospite.add_child(campata)
		# la pianta e' in coordinate MONDO: si annulla la rotazione con cui
		# il giocatore ha posato il pezzo (F), come fa l'aiuola
		campata.rotation.y -= nodo.rotation.y
		radice.free()
		_riscrivi_scatole(nodo, campata)


## Le collisioni si rifanno SEMPRE a parte: le CollisionShape3D sono figlie
## dirette dello StaticBody3D, e una shape dentro un contenitore non viene
## registrata affatto (senza errori). Si tolgono con remove_child, che
## sparisce NEL FRAME: con queue_free resterebbero attive un frame di piu' e
## il varco della porta sarebbe tappato proprio mentre la serra si fonde.
static func _riscrivi_scatole(corpo: Node3D, campata: Node3D) -> void:
	if corpo is not StaticBody3D:
		return
	for f in corpo.get_children():
		if f is CollisionShape3D:
			corpo.remove_child(f)
			f.queue_free()
	var scatole: Array = campata.get_meta("scatole", [])
	var giro := campata.rotation.y
	var base := Basis(Vector3.UP, giro)
	for sc: Array in scatole:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = sc[0]
		shape.shape = box
		shape.position = base * (sc[1] as Vector3)
		shape.rotation.y = giro
		corpo.add_child(shape)


# --- I FESTONI: i pali si passano il filo -------------------------------
# Stessa filosofia delle serre: il collegamento è DERIVATO dalle celle
# occupate, non salvato. Il salvataggio resta una riga per palo, non c'è
# niente da migrare, e un filo non può restare appeso a un palo che non
# c'è più — perché non è mai esistito come dato.
# Qui si decide solo CHI si vede con CHI: il disegno lo fa BuildCatalog.

## Le otto direzioni in cui un palo cerca un compagno.
const FESTONE_DIR: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1),
		Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
		Vector2i(0, -1), Vector2i(1, -1)]


## Che veste porta il palo in `c` — e insieme la domanda «è un palo?»
## (-1 = no). L'elenco dei nomi sta in BuildCatalog: fonte unica.
static func veste_palo(dict: Dictionary, c: Vector2i) -> int:
	var nodo := dict.get(c) as Node3D
	if nodo == null:
		return -1
	return BuildCatalog.FESTONE_PALI.find(str(nodo.get_meta("item_name", "")))


## Chi ha in carico il filo fra due pali: il minore in ordine
## lessicografico. È la stessa regola del montante condiviso fra due
## serre, e serve alla stessa cosa: che il filo lo disegni UNO solo.
static func _prima_di(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)


## Il seme di una campata: dipende SOLO dalle due celle, quindi lo stesso
## filo esce identico a ogni ricostruzione e a ogni ricaricamento (le
## lampadine non si rimescolano sotto gli occhi del giocatore).
static func _seme_festone(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x * 73_856_093 + a.y * 19_349_663
			+ b.x * 83_492_791 + b.y * 2_971_215 + 7)


## Il PRIMO palo incontrato in ognuna delle otto direzioni, entro
## FESTONE_PORTATA celle. Il primo e non tutti: senza questa regola una
## fila di sei pali diventa un ventaglio di quindici fili sovrapposti
## invece di una collana.
static func vicini_festone(dict: Dictionary, c: Vector2i) -> Array:
	var fuori: Array = []
	if veste_palo(dict, c) < 0:
		return fuori
	for d: Vector2i in FESTONE_DIR:
		for k in range(1, BuildCatalog.FESTONE_PASSI + 1):
			var v: Vector2i = c + d * k
			if veste_palo(dict, v) < 0:
				continue
			# il PRIMO palo su quella retta, e poi si smette di guardare:
			# se è troppo lontano il filo non c'è, ma nemmeno si cerca
			# oltre — quel palo fa comunque da tappo alla vista
			if Vector2(v - c).length() <= BuildCatalog.FESTONE_PORTATA:
				fuori.append(v)
			break
	return fuori


## I pali che una modifica in `cell` può aver cambiato: quello nella
## cella e il primo incontrato nelle otto direzioni. Sono esattamente
## quelli per cui «il primo palo in quella direzione» adesso è un altro —
## o non c'è più.
static func pali_toccati(dict: Dictionary, cell: Vector2i) -> Array:
	var fuori: Array = []
	if veste_palo(dict, cell) >= 0:
		fuori.append(cell)
	for d: Vector2i in FESTONE_DIR:
		for k in range(1, BuildCatalog.FESTONE_PASSI + 1):
			var v: Vector2i = cell + d * k
			if veste_palo(dict, v) >= 0:
				# QUI non si filtra sulla distanza: un palo appena fuori
				# portata va rifatto lo stesso, perché quello che gli è
				# comparso davanti può avergli tolto la vista di un altro
				fuori.append(v)
				break
	return fuori


## Rifà i fili che partono dal palo in `c`. Il figlio «Festoni» si
## RINOMINA prima di liberarlo: un nodo in coda tiene occupato il nome
## fino a fine frame, e il nuovo diventerebbe «Festoni2» — al rinfresco
## dopo non lo troveresti più (è la trappola già pagata con la Vetreria).
static func ricostruisci_festoni(dict: Dictionary, c: Vector2i) -> void:
	var nodo := dict.get(c) as Node3D
	var veste := veste_palo(dict, c)
	if nodo == null or veste < 0:
		return
	var vecchio := nodo.find_child("Festoni", false, false)
	if vecchio != null:
		vecchio.name = "FestoniVecchi"
		nodo.remove_child(vecchio)
		vecchio.queue_free()
	var casa := Node3D.new()
	casa.name = "Festoni"
	# le campate si calcolano in coordinate MONDO: si annulla la
	# rotazione con cui il giocatore ha posato il palo, come fa l'aiuola
	casa.rotation.y = -nodo.rotation.y
	nodo.add_child(casa)
	var cima := Vector3(0, BuildCatalog.FESTONE_CIMA, 0)
	for v: Vector2i in vicini_festone(dict, c):
		if not _prima_di(c, v):
			continue
		var b := Vector3(float(v.x - c.x), BuildCatalog.FESTONE_CIMA,
				float(v.y - c.y))
		casa.add_child(BuildCatalog.festone(cima, b, veste, _seme_festone(c, v)))


## LE RASTRELLIERE IN FILA. Una accanto all'altra non sono due mobili: sono
## una scaffalatura piu' lunga. La fila si riconosce come quella della
## Gradinata — celle adiacenti lungo l'asse X del pezzo, con la STESSA
## rotazione — e le tre varianti si uniscono fra loro: cambia il contenuto,
## non il mobile.
static func e_rastrelliera(dict: Dictionary, c: Vector2i, rot := -1) -> bool:
	var nodo := dict.get(c) as Node3D
	if nodo == null:
		return false
	if not (str(nodo.get_meta("item_name", "")) in BuildPalestra.RASTRELLIERE):
		return false
	return rot < 0 or int(nodo.get_meta("rot", 0)) == rot


## La fila intera che passa per `c`, in ordine da sinistra a destra.
static func fila_rastrelliera(dict: Dictionary, c: Vector2i, viste := {}) -> Array:
	if not e_rastrelliera(dict, c) or viste.has(c):
		return []
	var rot := int((dict[c] as Node3D).get_meta("rot", 0))
	var passo := passo_fila(rot)
	var fuori: Array = [c]
	viste[c] = true
	var q := c - passo
	while e_rastrelliera(dict, q, rot) and not viste.has(q):
		viste[q] = true
		fuori.push_front(q)
		q -= passo
	q = c + passo
	while e_rastrelliera(dict, q, rot) and not viste.has(q):
		viste[q] = true
		fuori.append(q)
		q += passo
	return fuori


## Rifa' una fila: ogni campata sa se di fianco continua, e il montante
## condiviso lo disegna una sola volta (quella di sinistra).
static func ricostruisci_rastrelliera(dict: Dictionary, celle: Array) -> void:
	for i in celle.size():
		var c: Vector2i = celle[i]
		var nodo := dict.get(c) as Node3D
		if nodo == null:
			continue
		var vecchia := nodo.find_child("Rastrelliera", true, false)
		var ospite: Node3D = nodo
		if vecchia != null:
			ospite = vecchia.get_parent() as Node3D
			vecchia.name = "RastrellieraVecchia"
			ospite.remove_child(vecchia)
			vecchia.queue_free()
		var variante := BuildPalestra.variante_rastrelliera(
				str(nodo.get_meta("item_name", "")))
		var radice: Node3D = BuildPalestra.rastrelliera_cella(
				{"sx": i > 0, "dx": i < celle.size() - 1}, variante,
				int(hash(c)) & 0x7fffffff)
		var campata: Node3D = radice.get_node("Rastrelliera")
		radice.remove_child(campata)
		ospite.add_child(campata)
		radice.free()


static func _e_aiuola(dict: Dictionary, c: Vector2i) -> bool:
	var nodo := dict.get(c) as Node3D
	return nodo != null and str(nodo.get_meta("item_name", "")) == "Aiuola"


## Il passo di una cella lungo la fila: l'asse X locale del pezzo,
## ruotato come lo ruota place_cell (rotation.y = -rot * PI/2).
static func passo_fila(rot: int) -> Vector2i:
	match posmod(rot, 4):
		0: return Vector2i(1, 0)
		1: return Vector2i(0, 1)
		2: return Vector2i(-1, 0)
		_: return Vector2i(0, -1)


static func _fila_continua(dict: Dictionary, c: Vector2i, rot: int) -> bool:
	var nodo := dict.get(c) as Node3D
	if nodo == null or str(nodo.get_meta("item_name", "")) != "Gradinata":
		return false
	# stessa rotazione o niente: due file che si voltano le spalle
	# (o si incrociano) non sono una platea
	return posmod(int(nodo.get_meta("rot", 0)), 4) == rot


static func _bracciolo_acceso(nodo: Node3D, nome: String, on: bool) -> void:
	var br := nodo.find_child(nome, true, false) as Node3D
	if br:
		br.visible = on


## LA STACCIONATA CONTINUA. Stessa regola della gradinata, portata sui
## BORDI: i segmenti in fila sulla stessa retta fanno UN recinto, e il
## palo vive solo ai capi. Il verso del pezzo (rotazione + flip) si
## legge dal nodo: il palo da spegnere e' quello che GUARDA il vicino.
## Statica e senza stato: i test la fanno girare su un dizionario finto.
static func rinfresca_pali(dict: Dictionary, key: Vector2i) -> void:
	var passo := passo_bordo(key)
	for d in [Vector2i.ZERO, passo, -passo]:
		var k: Vector2i = key + d
		var nodo := dict.get(k) as Node3D
		if nodo == null or str(nodo.get_meta("item_name", "")) != "Staccionata":
			continue
		# l'asse X locale del pezzo, nel mondo (il flip e' gia' nel yaw)
		var avanti := Vector3(cos(nodo.rotation.y), 0, -sin(nodo.rotation.y))
		var verso := Vector3(float(passo.x), 0, float(passo.y)).normalized()
		var continua_piu := _stessa_stecca(dict, k + passo)
		var continua_meno := _stessa_stecca(dict, k - passo)
		if avanti.dot(verso) > 0.0:
			_bracciolo_acceso(nodo, "PaloDx", not continua_piu)
			_bracciolo_acceso(nodo, "PaloSx", not continua_meno)
		else:
			_bracciolo_acceso(nodo, "PaloDx", not continua_meno)
			_bracciolo_acceso(nodo, "PaloSx", not continua_piu)


## Il passo fra due bordi COLLINEARI: le chiavi dei bordi sono raddoppiate,
## e un bordo con la y dispari corre lungo X (sta fra una cella e la sua
## vicina in z), uno con la x dispari corre lungo Z.
static func passo_bordo(key: Vector2i) -> Vector2i:
	return Vector2i(2, 0) if posmod(key.y, 2) == 1 else Vector2i(0, 2)


static func _stessa_stecca(dict: Dictionary, k: Vector2i) -> bool:
	var nodo := dict.get(k) as Node3D
	return nodo != null and str(nodo.get_meta("item_name", "")) == "Staccionata"


## Piazza un pezzo "cell" nella cella data (lvl 1 = piano di sopra).
## Usato anche dalla demo CLI.
func place_cell(cell: Vector2i, piece: String, rot := 0, animate := true, lvl := 0, variant := "") -> void:
	var index := item_index(piece)
	if index < 0:
		push_warning("BuildSystem: pezzo sconosciuto nel salvataggio: %s" % piece)
		return
	var item := _items[index]
	if bool(item.get("up", false)):
		lvl = 1
	var dict := _dicts(lvl)[item["layer"]] as Dictionary
	if dict.has(cell):
		return
	if _cozy and bool(_cozy.call("is_river", Vector3(cell.x, 0, cell.y))):
		return  # il letto del fiume resta del fiume
	var node := _build_placed(index, variant)
	node.position = Vector3(cell.x, FLOOR_H * lvl, cell.y)
	node.rotation.y = -rot * PI * 0.5
	_placed_root.add_child(node)
	dict[cell] = node
	node.set_meta("lvl", lvl)
	_register_special(piece, node)
	node.set_meta("rot", rot)
	node.set_meta("variant", variant)
	# la fila continua: la gradinata nuova e le sue vicine si accordano
	# su chi tiene il bracciolo (vedi rinfresca_braccioli)
	rinfresca_braccioli(dict, cell)
	# e il sentiero nuovo tende le pietre verso i sentieri vicini
	rinfresca_sentieri(dict, cell)
	# e l'aiuola nuova si unisce alle aiuole accanto in una striscia sola
	rinfresca_aiuole(dict, cell)
	# e le serre vicine diventano UN edificio (a fine frame, una volta sola)
	_segna_serre(dict, cell)
	# e i pali del festone si passano il filo (idem: a fine frame)
	_segna_festoni(dict, cell)
	# pavimenti, sentieri e tappeti a terra schiacciano l'erba sotto di sé
	if lvl == 0 and int(item["layer"]) <= 1:
		get_tree().call_group("cozy_world", "flatten_cell", cell)
	if animate:
		_pop_in(node)
	if not _loading:
		placed_changed.emit()
	request_save()


## Piazza un pezzo "edge" sul bordo con chiave raddoppiata data.
func place_edge(key: Vector2i, piece: String, flip := false, animate := true, lvl := 0, variant := "") -> void:
	var index := item_index(piece)
	if index < 0:
		push_warning("BuildSystem: pezzo sconosciuto nel salvataggio: %s" % piece)
		return
	var dict := _dicts(lvl)["edge"] as Dictionary
	if dict.has(key):
		return
	var tf := _edge_key_to_transform(key)
	var node := _build_placed(index, variant)
	node.position = tf[0] + Vector3(0, FLOOR_H * lvl, 0)
	# micro-sfalsamento verticale deterministico (±3 mm): le modanature di
	# pezzi adiacenti non condividono mai lo stesso piano -> niente z-fighting
	node.position.y += 0.0015 * float(posmod(key.x * 7 + key.y * 13, 5) - 2)
	node.rotation.y = tf[1] + (PI if flip else 0.0)
	_placed_root.add_child(node)
	dict[key] = node
	# un bordo nuovo può aver chiuso un recinto: il grafo si rifà pigro
	_varchi_sporchi = true
	node.set_meta("lvl", lvl)
	_register_special(piece, node)
	node.set_meta("flip", flip)
	node.set_meta("variant", variant)
	# il recinto continuo: il segmento nuovo e i collineari si accordano
	# su chi tiene il palo (vedi rinfresca_pali)
	rinfresca_pali(dict, key)
	if animate:
		_pop_in(node)
	if not _loading:
		placed_changed.emit()
	request_save()


# visual del catalogo + StaticBody3D con le collisioni del pezzo
# (il terzo elemento opzionale di una collisione è la rotazione X: rampe)
func _build_placed(index: int, variant := "") -> Node3D:
	var item := _items[index]
	var builder: Callable = item["builder"]
	var visual: Node3D = builder.call()
	if variant != "":
		var eco := _economy()
		if eco and eco.piece_takes_variant(str(item["name"])):
			eco.apply_variant(visual, variant)
	var cols: Array = item["cols"]
	if cols.is_empty():
		return visual
	var body := StaticBody3D.new()
	body.add_child(visual)
	for c in cols:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = c[0]
		shape.shape = box
		shape.position = c[1]
		if c.size() > 2:
			shape.rotation.x = float(c[2])
		body.add_child(shape)
	return body


func _pop_in(node: Node3D) -> void:
	node.scale = Vector3.ONE * 0.55
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3.ONE, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_poof(node.position + Vector3(0, 0.35, 0), Color(1.0, 0.9, 0.55))


# cerca il pezzo rimovibile sotto il cursore, per priorità:
# tetto, poi oggetti, poi bordi, poi tappeti e pavimenti — sul piano attivo
func _find_removable() -> Array:
	for layer in [3, 2, "edge", 1, 0]:
		var key: Vector2i = _hover_cell
		if layer is String:
			var near := _nearest_edge_key()
			if near == Vector2i.MAX:
				continue
			key = near
		var dict := _dicts(_level)[layer] as Dictionary
		if dict.has(key):
			return [layer, key, dict[key]]
	return []


func _try_remove() -> void:
	var found := _find_removable()
	if found.is_empty():
		return
	# LA STRATIGRAFIA (scenes/world/Strati.gd): solo il gesto del GIOCATORE
	# seppellisce un reperto nella cella. L'harness e i caricamenti
	# (debug_clear, debug_remove_edge, _load_village) passano da _remove_at
	# diretto e NON devono lasciare strati: l'hook vive QUI e non là — e la
	# guardia _loading è la cintura oltre le bretelle, per il giorno in cui
	# qualcuno chiamasse questo gesto in mezzo a un caricamento.
	# found = [layer, key, node]: la cella è la CHIAVE del dizionario e i
	# meta del nodo sono ancora leggibili. La chiamata resta SINCRONA e
	# PRIMA di _remove_at: il pezzo muore col tween della rimozione, e una
	# chiamata rimandata giocherebbe con un nodo in via di sparizione.
	if not _loading:
		var strati := get_tree().get_first_node_in_group("strati")
		if strati != null:
			strati.call("su_demolizione", found[0], found[1], found[2], _level)
	_remove_at(found[0], found[1], _level)


func _remove_at(layer, key, lvl := 0) -> void:
	var dict := _dicts(lvl)[layer] as Dictionary
	if not dict.has(key):
		return
	var node := dict[key] as Node3D
	dict.erase(key)
	if layer is String:
		_varchi_sporchi = true  # tolto un muro, il recinto si riapre
	# se in mezzo alla fila c'era una gradinata, i vicini si riprendono
	# il bracciolo sul fianco tornato libero — e i sentieri accanto
	# ritirano le pietre dal varco
	if key is Vector2i:
		rinfresca_braccioli(dict, key)
		rinfresca_pali(dict, key)
		rinfresca_sentieri(dict, key)
		rinfresca_aiuole(dict, key)
		# tolta una campata, il gruppo si richiude — o si spezza in due
		_segna_serre(dict, key)
		# tolto un palo, i fili che ci arrivavano spariscono da soli: non
		# erano salvati, erano DERIVATI (ma i vicini vanno rifatti, perché
		# per loro il primo palo in quella direzione adesso è un altro)
		_segna_festoni(dict, key)
	_unregister_special(node)
	if node == _demo_target:
		_demo_target = null
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * 0.02, 0.16) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(node.queue_free)
	_spawn_poof(node.position + Vector3(0, 0.3, 0), Color(0.9, 0.85, 0.8))
	if _sfx: _sfx.remove_item()
	# se la cella a terra è tornata libera (né pavimento né tappeto),
	# l'erba rinasce
	if lvl == 0 and layer is int and int(layer) <= 1 and key is Vector2i:
		if not (_placed[0] as Dictionary).has(key) and not (_placed[1] as Dictionary).has(key):
			get_tree().call_group("cozy_world", "unflatten_cell", key)
	placed_changed.emit()
	request_save()


# ------------------------------------------------------- salvataggio

# Il villaggio vive in user://village.json: una riga per pezzo, celle come
# [layer, x, z, nome, rot] e bordi come [kx, ky, nome, flip]. Il file è
# minuscolo, quindi si riscrive per intero: niente "vuoi salvare?", il
# villaggio c'è e basta.

# --- API PUBBLICA: chiedere un salvataggio --------------------------------
# Chi cambia stato persistente (economia, collezione, giardino, Ordini…)
# chiama `request_save()`. NON chiamare `_save_village()` da fuori: è il
# writer interno, e usarlo da mezzo progetto è ciò che aveva reso il
# salvataggio un dettaglio implementativo pubblico — con l'effetto che ogni
# singola nocciolina scriveva il file INTERO due volte (una l'economia, una
# chi l'aveva fatta guadagnare).
#
# `request_save()` è idempotente dentro il frame: quante che siano le
# richieste, il file si scrive UNA volta sola, a fine frame. Chi sta per
# uscire (pausa → titolo, quit, CLI) usa `save_now()`, che scrive subito:
# un salvataggio differito, a scena morta, non verrebbe mai eseguito.
var _save_pending := false

# lo stato extra parsato dal salvataggio (per servire i persistable tardivi)
# e chi è già stato servito (instance_id -> true): mai servire due volte
var _loaded_extra := {}
var _served_extra := {}

## Le chiavi che il salvataggio SCRIVE DA SÉ (il villaggio costruito): si
## ricalcolano dalla griglia viva a ogni scrittura e non vanno mai conservate
## dal file precedente.
const CHIAVI_PROPRIE := ["cells", "edges", "up_cells", "up_edges", "variants"]

## LE CHIAVI ORFANE: quelle lette dal salvataggio di cui, in questo momento,
## NESSUN nodo in scena risponde.
##
## Perché esistono: il mondo nasce differito (CozyWorld crea GrandTree,
## Memories, Coop, Stargazing, Legami, Regista… tre frame dopo l'avvio). Il
## payload si ricostruisce DA ZERO e ci si fondono solo i persistable già
## nati: la chiave di un sistema non ancora sveglio spariva dal file. In
## sessione non si vede (la scrittura dopo la rimette), ma se il giocatore
## chiude subito, quel file mutilato È il salvataggio — e il .bak buono se
## l'è già mangiato la rotazione. Andavano perduti Filo Rosso, lutto,
## congedo, contatori del Regista, guardaroba, costellazioni, compleanni,
## ecosistema.
##
## Perché NON si conservano tutte le chiavi vecchie: alcune DEVONO poter
## sparire, ed è il loro sparire a essere lo stato. `mail_current` quando la
## busta è stata aperta (e dentro c'è il REGALO: conservarla lo
## rimaterializzerebbe a ogni avvio), `inv_dishes`/`inv_treasures` quando la
## dispensa si svuota, `home` quando la casa si disfa. Quelle hanno un
## proprietario VIVO in scena, e il censimento le toglie da qui: si conserva
## solo ciò di cui, adesso, nessuno risponde.
var _chiavi_orfane := {}


## Un persistable entrato in scena DOPO il load (generazione differita del
## mondo) reclama qui la sua fetta di salvataggio, una volta sola.
func _on_node_added(node: Node) -> void:
	if _loaded_extra.is_empty():
		return
	if not node.has_method("load_extra") or not node.has_method("save_extra"):
		return
	if _served_extra.has(node.get_instance_id()):
		return
	# il suo load_extra può toccare @onready/figli: aspetta il suo _ready
	if node.is_node_ready():
		_serve_late(node)
	else:
		node.ready.connect(_serve_late.bind(node), CONNECT_ONE_SHOT)


func _serve_late(node: Node) -> void:
	if not is_instance_valid(node) or _served_extra.has(node.get_instance_id()):
		return
	_served_extra[node.get_instance_id()] = true
	node.load_extra(_loaded_extra)


## Chi è in scena si prende la RESPONSABILITÀ delle chiavi che emette: da qui
## in poi quelle possono anche sparire dal file (è il giocatore che le ha
## svuotate), e non vanno più conservate dal salvataggio precedente.
func _rivendica(emesse: Dictionary) -> void:
	for k in emesse:
		_chiavi_orfane.erase(k)


## Il censimento dopo il caricamento: tutti i persistable già svegli
## dichiarano le loro chiavi, e ciò che resta orfano appartiene a un sistema
## che deve ancora nascere. Gira su uno stack SUO (call_deferred da
## _finish_load): un errore dentro un save_extra non deve poter srotolare la
## fine del caricamento e lasciare `_loading` incastrato a true — cioè il
## salvataggio spento in silenzio per sempre.
func _censimento_orfane() -> void:
	for node in get_tree().get_nodes_in_group("persistable"):
		if node.has_method("save_extra"):
			_rivendica(node.save_extra())


## Chiede un salvataggio: si scrive una volta sola a fine frame.
func request_save() -> void:
	if not _persist or _loading or _save_pending:
		return
	_save_pending = true
	_flush_save.call_deferred()


## Scrive SUBITO, in modo sincrono (uscita dal gioco, CLI, cambio scena).
func save_now() -> void:
	_save_pending = false
	_save_village()


## Spegne (o riaccende) le SCRITTURE per l'harness di verifica da riga di
## comando. Il caricamento non passa di qui: `_load_village` è già stato messo
## in coda da `_ready` e non guarda `_persist`, quindi il villaggio del
## giocatore si carica ancora — si blocca solo la riscrittura del file.
func set_persist_for_debug(on: bool) -> void:
	_persist = on
	if not on:
		_save_pending = false


func _flush_save() -> void:
	if not _save_pending:
		return
	_save_pending = false
	_save_village()


# la finestra si chiude col salvataggio ancora in coda: scrivilo adesso o
# il differito muore con la scena
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _save_pending:
		save_now()


# --- LE SERRE: una ricostruzione a fine frame, non una per pezzo posato ---
# Il caricamento piazza le celle una per una: un rinfresco ingenuo rifarebbe
# il gruppo 1+2+3+4 volte, le prime tre di forma SBAGLIATA e buttate via
# subito. Si accoda e si rifa' una volta sola, con l'idioma gia' in casa
# (_save_pending + _flush_save.call_deferred).
var _serre_da_rifare: Array = []
var _serre_pending := false


func _segna_serre(dict: Dictionary, cell: Vector2i) -> void:
	# GUARDIA OBBLIGATORIA: i rinfresca ricevono il dizionario del LAYER, non
	# del nome. Senza questa uscita, posare una Sedia accanto a una serra (o
	# a una rastrelliera) ricostruirebbe un edificio intero.
	var tocca := false
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var v := cell + Vector2i(dx, dz)
			if e_serra(dict, v) or e_rastrelliera(dict, v):
				tocca = true
	if not tocca:
		return
	_serre_da_rifare.append([dict, cell])
	if _serre_pending:
		return
	_serre_pending = true
	_flush_serre.call_deferred()


func _flush_serre() -> void:
	_serre_pending = false
	var lavoro := _serre_da_rifare
	_serre_da_rifare = []
	var viste := {}
	var viste_r := {}
	for voce: Array in lavoro:
		var dict: Dictionary = voce[0]
		var cell: Vector2i = voce[1]
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var vic := cell + Vector2i(dx, dz)
				var gruppo := gruppo_serra(dict, vic, viste)
				if not gruppo.is_empty():
					ricostruisci_serra(dict, gruppo)
				var fila := fila_rastrelliera(dict, vic, viste_r)
				if not fila.is_empty():
					ricostruisci_rastrelliera(dict, fila)


## Il flush SINCRONO: per chi costruisce e guarda nello stesso frame
## (l'harness, i fotografi del catalogo, la CLI). Un differito, a scena
## gia' fotografata, non servirebbe a niente.
func aggiorna_serre_ora() -> void:
	if _serre_pending or not _serre_da_rifare.is_empty():
		_flush_serre()


# --- I FESTONI: stesso idioma differito delle serre ---------------------
var _festoni_da_rifare: Array = []
var _festoni_pending := false


func _segna_festoni(dict: Dictionary, cell: Vector2i) -> void:
	# GUARDIA OBBLIGATORIA, come per le serre: i rinfresca ricevono il
	# dizionario del LAYER, non del nome. Senza questa uscita, posare una
	# Sedia in mezzo al prato metterebbe in coda un lavoro per niente.
	if pali_toccati(dict, cell).is_empty():
		return
	_festoni_da_rifare.append([dict, cell])
	if _festoni_pending:
		return
	_festoni_pending = true
	_flush_festoni.call_deferred()


func _flush_festoni() -> void:
	_festoni_pending = false
	var lavoro := _festoni_da_rifare
	_festoni_da_rifare = []
	# il caricamento pianta i pali uno per uno: senza il differito, una
	# fila di sei pali si rifarebbe 1+2+3+4+5+6 volte, le prime cinque
	# di forma sbagliata
	var fatti := {}
	for voce: Array in lavoro:
		var dict: Dictionary = voce[0]
		var cell: Vector2i = voce[1]
		for c: Vector2i in pali_toccati(dict, cell):
			if fatti.has(c):
				continue
			fatti[c] = true
			ricostruisci_festoni(dict, c)


## Il flush SINCRONO dei festoni (vedi aggiorna_serre_ora).
func aggiorna_festoni_ora() -> void:
	if _festoni_pending or not _festoni_da_rifare.is_empty():
		_flush_festoni()


# --- I VARCHI: dove si passa ------------------------------------------
#
# Il villaggio come GRAFO. Non si ricalcola per domanda — si ricalcola
# quando cambia un bordo, e poi la risposta è un confronto fra due
# interi (vedi Varchi.componenti). È lo stesso patto delle serre e dei
# festoni: dato DERIVATO, niente da salvare, niente da migrare.
var _muri_cache := {}
var _isole_cache := {}
var _varchi_sporchi := true
var _suolo_cache = null


## L'insieme dei bordi che sbarrano la strada, a terra. La decisione di
## cosa sbarri NON è scritta qui: si deriva dalle `cols` del catalogo.
func muri() -> Dictionary:
	_aggiorna_varchi()
	return _muri_cache


# --- IL TURNO DELLE ROTTE: chi cerca una strada, e quando ------------
#
# LA SERA DEL FALÒ, ventotto vicini si alzano insieme. `Visitors._routine`
# li sfalsa di un lease casuale fra 0,4 e 1,8 secondi, che a 60 Hz vuol
# dire ottantaquattro frame per ventotto partenze: quasi sempre uno per
# frame, ogni tanto tre o quattro nello stesso. Con una staccionata
# piantata di traverso sul tragitto — l'unico caso in cui una strada
# serve davvero — ogni domanda costa un millisecondo e mezzo, e quattro
# insieme fanno **sei millisecondi in un frame solo**: un singhiozzo,
# nella scena più guardata della giornata.
#
# Il turno è la risposta, e ha una regola sola: **nessuno perde la sua
# strada, la riceve un frame dopo.** Chi trova il turno occupato cammina
# dritto per un frame (quattro centimetri) e ripropone la domanda al
# prossimo (`Visitor._rotta_attesa`). Il fuoco è a cinquanta metri: la
# strada arriva molto prima della staccionata.
#
# La spesa si misura in MICROSECONDI VERI, non in numero di domande, e
# per un motivo che conta: le domande a buon mercato — quelle che escono
# dai primi cancelli — non consumano niente, quindi in un villaggio
# normale il turno è sempre aperto e questo codice non esiste. Si accorge
# di sé stesso solo quando qualcuno sta davvero cercando.
const BUDGET_ROTTE_US := 1500
var _turno_frame := -1
var _turno_speso := 0
var _turno_attivo := true


## C'è ancora tempo, in questo frame, per cercare una strada? Chi la chiede
## deve domandarlo PRIMA (`Visitor._deviazione`): un «no» non è un rifiuto,
## è un «fra un frame».
func turno_rotte_libero() -> bool:
	if not _turno_attivo:
		return true
	_turno_rinfresca()
	return _turno_speso < BUDGET_ROTTE_US


func _turno_rinfresca() -> void:
	var f := int(Engine.get_process_frames())
	if f != _turno_frame:
		_turno_frame = f
		_turno_speso = 0


## Spegne il turno: serve ai banchi di prova che fanno mille viaggi dentro
## UN frame del motore (`tools/misura_cammino.gd`), dove il contatore dei
## frame non avanza mai e il turno resterebbe chiuso per sempre. In partita
## non si tocca.
func set_turno_rotte_for_debug(on: bool) -> void:
	_turno_attivo = on


## IL SUOLO: dove il mondo non ha messo un pavimento (il fiume, lo stagno,
## la parete). La verità è di `CozyWorld.terreno_vietato`; questo è solo il
## quaderno su cui non si riscrive due volte la stessa risposta.
##
## Non si invalida MAI, e il motivo è che il terreno non si muove: il fiume
## di stasera è quello di stamattina — è semmai il giocatore che non ci
## può costruire. Fuori dal villaggio (il bosco, il prologo, il diorama del
## menù) `_cozy` non c'è: il suolo resta senza oracolo e non vieta niente,
## cioè si cammina come si è sempre camminato.
## Un quaderno SENZA oracolo si rifà, appena il mondo compare: `_cozy` si
## trova in `_ready`, e chi chiedesse una strada un istante prima si
## porterebbe dietro per sempre un suolo che non vieta niente — cioè il
## fiume tornerebbe corridoio, in silenzio e senza un errore. Un quaderno
## già scritto invece non si butta mai: il terreno non cambia.
func suolo():
	if _suolo_cache != null and _suolo_cache.sa_qualcosa():
		return _suolo_cache
	var chiedi := Callable()
	if _cozy != null and is_instance_valid(_cozy) \
			and _cozy.has_method("terreno_vietato"):
		chiedi = Callable(_cozy, "terreno_vietato")
	if _suolo_cache == null or chiedi.is_valid():
		_suolo_cache = VARCHI.Suolo.new(chiedi)
	return _suolo_cache


## Le isole del villaggio: zero è il fuori, ≥ 1 è un posto chiuso.
func isole() -> Dictionary:
	_aggiorna_varchi()
	return _isole_cache


## Da questa cella si arriva a quella? La domanda della Fase 3.
func raggiungibile(da: Vector2i, a: Vector2i) -> bool:
	return VARCHI.raggiungibile(isole(), da, a)


## La cella di un punto del mondo. La REGOLA vive in `Varchi.cella` — la
## stessa che usa il filo continuo per sapere da che cella parte — e questa
## è solo la porta in tre dimensioni: se le due divergessero, il corpo e il
## giudice si racconterebbero due griglie diverse.
func cella_di(p: Vector3) -> Vector2i:
	return VARCHI.cella(Vector2(p.x, p.z))


## La strada vera, in metri di mondo, già tirata a filo. Vuota se non c'è
## strada — e chi la chiede DEVE distinguere «vuota» da «dritto per di
## là», perché sono la stessa cosa solo quando la partenza è l'arrivo.
##
## ## Gli estremi sono quelli VERI, ed è tutto il punto
##
## La BFS ragiona in celle e restituisce centri; il corpo però parte da
## dov'è e va dove gli hanno detto, che sono due punti qualunque dentro le
## loro celle. Finché il filo si tirava sui soli centri, il villaggio
## giudicava una spezzata e il corpo ne camminava un'altra — e siccome un
## filo teso rasenta gli spigoli **per costruzione**, mezzo metro di
## scarto agli estremi bastava a mandare una gamba intera dall'altra parte
## del muro (misurato: 32 viaggi su mille, 25 nella prima tratta).
##
## La SPINA DORSALE qui sotto risolve la cosa alla radice, e si dimostra
## invece di sperare:
##
##   punto vero di partenza → centro della sua cella → centri delle celle
##   della rotta → centro dell'ultima cella → punto vero d'arrivo
##
## Ogni coppia consecutiva è libera **per costruzione**: le prime due (e le
## ultime due) stanno dentro la stessa cella, quindi non attraversano
## nessun confine; le altre sono centri di celle adiacenti con il bordo
## aperto e con il pavimento sotto, perché è la ricerca ad averle scelte
## (`Varchi.passa` chiede tutt'e due le cose). Il filo tirato può solo
## togliere tappe, e toglie solo quelle la cui scorciatoia ha superato la
## stessa domanda che si farà il corpo — **compresa quella sull'acqua**:
## senza il suolo qui, una scorciatoia poteva rientrare nel fiume che la
## rotta aveva appena schivato.
func rotta_mondo(da: Vector3, a: Vector3, tetto := VARCHI.MAX_CELLE) -> Array[Vector3]:
	var m := muri()
	var terra = suolo()
	var celle := VARCHI.rotta(m, cella_di(da), cella_di(a), tetto, terra)
	var fuori: Array[Vector3] = []
	if celle.is_empty():
		return fuori
	var spina: Array[Vector2] = []
	_accoda(spina, Vector2(da.x, da.z))
	for c in celle:
		_accoda(spina, Vector2(c))
	_accoda(spina, Vector2(a.x, a.z))
	for p in VARCHI.tira_filo_mondo(m, spina, terra):
		fuori.append(Vector3(p.x, 0.0, p.y))
	return fuori


## Accoda un punto alla spina, saltandolo se è quello di prima. Serve nei
## due casi in cui il corpo è già ESATTAMENTE sul centro della sua cella
## (e capita: le tappe di ieri sono centri di cella): un punto doppio
## darebbe al filo una gamba lunga zero, cioè una direzione indefinita.
func _accoda(spina: Array[Vector2], p: Vector2) -> void:
	if spina.is_empty() or spina[spina.size() - 1].distance_squared_to(p) > 1e-12:
		spina.append(p)


## LA DEVIAZIONE: le tappe da fare per arrivare ad `a` senza attraversare un
## muro — **vuota quando la retta basta**, che è il caso normale.
##
## È la porta da cui passa il corpo dei vicini (`Visitor._walk_to`), e la
## differenza con `rotta_mondo` non è tecnica, è di contratto: lì «vuota»
## vuol dire «non c'è strada», qui vuol dire «non c'è niente da fare, vai
## dritto come hai sempre fatto». Un solo significato, e va sempre verso
## «si cammina»: nessuna risposta di questa funzione può piantare un vicino.
##
## La partenza si TOGLIE, e si toglie perché c'è: `rotta_mondo` comincia
## dal punto vero da cui si parte, cioè da dove il corpo è già. Toglierla
## non è una scorciatoia — è la prova che la prima gamba che il corpo
## cammina è ESATTAMENTE la prima gamba che il villaggio ha giudicato. Con
## la vecchia stesura, che cominciava dal centro della cella, le due erano
## quasi la stessa cosa, e «quasi» valeva 25 viaggi su mille attraverso un
## muro.
##
## ## L'INVARIANTE, che è l'unica cosa da non rompere
##
## **Il corpo o cammina la retta di sempre, oppure una spezzata che non
## tocca né un muro né l'acqua.** Non esiste una terza risposta. Ne
## discende la regola che decide l'ordine dei cancelli qui sotto: *la
## deviazione non può mettere il corpo in un posto peggiore di quello in
## cui lo metterebbe la retta.*
##
## Per questo il cancello della retta guarda **soltanto i muri**, non il
## suolo. Se la retta è libera da muri, si va dritti — anche se rasenta lo
## stagno, esattamente come faceva prima che tutto questo esistesse.
## Chiedere una strada anche per schivare l'acqua sembra più bello e non lo
## è: le mete di questo gioco sono spesso in riva (il posto da cui si
## guardano le rane, la sponda, il ponte), e la ricerca finirebbe per
## esaurire il tetto senza trovare niente — cioè per pagare millisecondi e
## ridare comunque la retta. Il fiume è entrato per **togliere dalla rotta
## una scorciatoia che non c'era mai stata**, non per riscrivere il
## cammino di tutti.
##
## I QUATTRO CANCELLI, in ordine di prezzo crescente — una rotta costa fra
## il mezzo millisecondo e i due, quindi si paga solo quando serve davvero
## (i numeri, tutti misurati, stanno in `Varchi`):
##
##   1. non ci sono muri nel villaggio     → niente da schivare (O(1))
##   2. si parte e si arriva nella stessa cella → niente da tirare (O(1))
##   3. **la retta non ha muri davanti**   → decine di µs, ed è il caso comune
##   4. **la meta è nell'acqua**           → non c'è strada che ci arrivi
##
## e solo dopo, la ricerca col suo tetto. Il terzo cancello interroga il
## segmento VERO (punto di partenza → punto d'arrivo), non i centri delle
## due celle: chiedere di una retta diversa da quella che si percorrerà è
## il modo più economico di dichiarare libero un muro.
##
## Il quarto è quello che tiene basso il conto: una meta dentro il letto
## del fiume (capita — un pezzo sulla riva, un posto arrotondato di
## mezzo metro) non è raggiungibile per costruzione, e senza questo
## cancello ogni singolo viaggio verso di lei pagherebbe una ricerca
## esaurita fino al tetto per sentirsi dire di no.
##
## **Ce n'era un quinto, ed è stato tolto**: «più lontano di
## `ROTTA_RAGGIO`». Escludeva il falò per costruzione (cinquantasei celle
## contro ventiquattro) e non proteggeva da niente — il prezzo di una
## ricerca non dipende dalla distanza. La storia intera sta in `Varchi`.
func deviazione(da: Vector3, a: Vector3) -> Array[Vector3]:
	var niente: Array[Vector3] = []
	var m := muri()
	if m.is_empty():
		return niente
	var c0 := cella_di(da)
	var c1 := cella_di(a)
	if c0 == c1:
		return niente   # dentro una cella non si attraversa nessun confine
	if VARCHI.filo_libero(m, Vector2(da.x, da.z), Vector2(a.x, a.z)):
		return niente
	var terra = suolo()
	if terra.vietata(c1):
		return niente   # la meta è nell'acqua: nessuna strada ci arriva
	# da qui in giù si SPENDE: il tempo speso va sul conto del frame, ed è
	# quello che tiene la sera del falò dentro un frame (vedi il turno)
	var orologio := Time.get_ticks_usec()
	var tappe := rotta_mondo(da, a, VARCHI.ROTTA_TETTO)
	_turno_rinfresca()
	_turno_speso += Time.get_ticks_usec() - orologio
	if tappe.size() < 2:
		return niente   # murato, o troppo caro: si va dritto, come prima
	tappe.remove_at(0)   # la prima è dove si è già
	return tappe


func _aggiorna_varchi() -> void:
	if not _varchi_sporchi:
		return
	_varchi_sporchi = false
	_muri_cache = {}
	for key: Vector2i in (_placed["edge"] as Dictionary):
		var nodo := (_placed["edge"] as Dictionary)[key] as Node3D
		if nodo == null or not is_instance_valid(nodo):
			continue
		var idx := item_index(str(nodo.get_meta("item_name", "")))
		if idx < 0:
			continue
		if not VARCHI.e_varco(_items[idx]["cols"] as Array):
			_muri_cache[key] = true
	_isole_cache = VARCHI.componenti(_muri_cache)


## Toglie un pezzo di bordo (per la verifica CLI: è il gesto con cui il
## giocatore riapre un recinto).
func debug_remove_edge(key: Vector2i, lvl := 0) -> void:
	_remove_at("edge", key, lvl)


## Il ricalcolo SINCRONO (vedi aggiorna_serre_ora): serve a chi costruisce
## e interroga nello stesso frame.
func aggiorna_varchi_ora() -> void:
	_varchi_sporchi = true
	_aggiorna_varchi()


func _save_village() -> void:
	if not _persist or _loading:
		return
	var cells := []
	var up_cells := []
	for layer in [0, 1, 2, 3]:
		for lvl in 2:
			var dict := _dicts(lvl)[layer] as Dictionary
			var rows := cells if lvl == 0 else up_cells
			for cell: Vector2i in dict:
				var node := dict[cell] as Node3D
				rows.append([layer, cell.x, cell.y,
						node.get_meta("item_name", ""), int(node.get_meta("rot", 0))])
	var edges := []
	var up_edges := []
	for lvl in 2:
		var edict := _dicts(lvl)["edge"] as Dictionary
		var rows := edges if lvl == 0 else up_edges
		for key: Vector2i in edict:
			var node := edict[key] as Node3D
			rows.append([key.x, key.y,
					node.get_meta("item_name", ""), bool(node.get_meta("flip", false))])
	# SI PARTE DA CIÒ DI CUI NESSUNO RISPONDE. Le chiavi orfane (vedi
	# _chiavi_orfane) sono di sistemi che il mondo differito non ha ancora
	# creato: se non le riportassimo qui, un salvataggio nei primissimi frame
	# le cancellerebbe dal file. Ordine di precedenza, dal più debole al più
	# forte: orfane del file < ciò che i persistable vivi dichiarano adesso <
	# le chiavi del villaggio costruito.
	var payload := {}
	for k in _chiavi_orfane:
		if _loaded_extra.has(k):
			payload[k] = _loaded_extra[k]
	# stato extra (giorno del calendario, giardino…) dai nodi "persistable".
	# Cintura di sicurezza: un ritardatario non ancora servito viene servito
	# ADESSO, prima del merge — il suo stato vergine non deve mai
	# sovrascrivere quello salvato.
	for node in get_tree().get_nodes_in_group("persistable"):
		if not _loaded_extra.is_empty() and not _served_extra.has(node.get_instance_id()):
			_serve_late(node)
		var extra: Dictionary = node.save_extra()
		# il proprietario è arrivato: la sua chiave smette di essere orfana
		_rivendica(extra)
		# `true`: chi è in scena ADESSO batte sempre la copia vecchia del file
		payload.merge(extra, true)
	payload.merge({"cells": cells, "edges": edges,
			"up_cells": up_cells, "up_edges": up_edges,
			"variants": _collect_variants()}, true)
	# SCRITTURA BLINDATA: prima su un file temporaneo, poi la versione
	# precedente diventa .bak e il temporaneo prende il suo posto. Un crash
	# a metà scrittura (o il disco pieno) non può mai lasciare mezzo
	# villaggio su disco, e c'è sempre la copia di un attimo fa da cui
	# rialzarsi (_load_village la usa da solo se il .json è rotto).
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		printerr("BuildSystem: salvataggio fallito (%s)" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(payload))
	f.close()
	if FileAccess.file_exists(save_path):
		DirAccess.rename_absolute(save_path, save_path + ".bak")
	DirAccess.rename_absolute(tmp, save_path)


## Legge e interpreta un salvataggio: null se manca o non è JSON valido.
func _leggi_salvataggio(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


func _load_village() -> void:
	var data: Variant = _leggi_salvataggio(save_path)
	if data is not Dictionary:
		# ATTENZIONE alla differenza fra "manca" e "è rotto".
		# Il file che MANCA è un villaggio NUOVO: si comincia da zero.
		# Il ripiego sulla copia vale SOLO se il file c'è ma è illeggibile.
		# Prima non distingueva i due casi, e siccome «Nuovo villaggio»
		# archivia il .json lasciando il .bak, il villaggio nuovo
		# RESUSCITAVA quello vecchio: case, residenti, noccioline,
		# collezione, Ordini del Gufo — tutto tornava, con l'unico
		# avviso in una riga di console che il giocatore non vede mai.
		if not FileAccess.file_exists(save_path):
			return
		data = _leggi_salvataggio(save_path + ".bak")
		if data is Dictionary:
			printerr("BuildSystem: village.json illeggibile — ripristinato dalla copia .bak")
		else:
			return
	_loading = true
	var vmap: Dictionary = data.get("variants", {})
	for c in data.get("cells", []):
		if c is Array and c.size() == 5:
			var cell := Vector2i(int(c[1]), int(c[2]))
			place_cell(cell, str(c[3]), int(c[4]), false, 0, str(vmap.get(_pkey(0, int(c[0]), cell), "")))
	for e in data.get("edges", []):
		if e is Array and e.size() == 4:
			var key := Vector2i(int(e[0]), int(e[1]))
			place_edge(key, str(e[2]), bool(e[3]), false, 0, str(vmap.get(_pkey(0, "edge", key), "")))
	for c in data.get("up_cells", []):
		if c is Array and c.size() == 5:
			var ucell := Vector2i(int(c[1]), int(c[2]))
			place_cell(ucell, str(c[3]), int(c[4]), false, 1, str(vmap.get(_pkey(1, int(c[0]), ucell), "")))
	for e in data.get("up_edges", []):
		if e is Array and e.size() == 4:
			var ukey := Vector2i(int(e[0]), int(e[1]))
			place_edge(ukey, str(e[2]), bool(e[3]), false, 1, str(vmap.get(_pkey(1, "edge", ukey), "")))
	# Lo stato extra resta in _loaded_extra per i persistable RITARDATARI:
	# la generazione differita di CozyWorld aggiunge Calendar, Wardrobe,
	# Legami, Ecosystem… qualche frame DOPO questo dispatch. Senza il modello
	# "pull" (vedi _on_node_added) non riceverebbero mai load_extra e il loro
	# stato vergine cancellerebbe il salvataggio alla prima scrittura.
	_loaded_extra = data
	# All'inizio è orfano TUTTO ciò che non è del villaggio costruito: il
	# censimento (dopo i load_extra) toglie da qui le chiavi di chi è già in
	# scena. Partire dal massimo è la posizione prudente — fra il
	# caricamento e il censimento nessuno ha ancora avuto modo di svuotare
	# niente, quindi conservare tutto è esattamente ciò che serve.
	_chiavi_orfane.clear()
	for k in data:
		if not CHIAVI_PROPRIE.has(k):
			_chiavi_orfane[str(k)] = true
	# ogni load_extra su uno stack separato (call_deferred): un errore di
	# runtime in UN sistema non deve srotolare il load e lasciare _loading
	# incastrato a true (= salvataggio disattivato in silenzio per sempre)
	for node in get_tree().get_nodes_in_group("persistable"):
		_served_extra[node.get_instance_id()] = true
		node.load_extra.call_deferred(data)
	_finish_load.call_deferred()


func _finish_load() -> void:
	_loading = false
	placed_changed.emit()
	# il censimento su uno stack a parte: vedi _censimento_orfane
	_censimento_orfane.call_deferred()


## Dove il villaggio occupa il terreno: [Vector3(x, raggio, z)] per ogni
## pezzo piazzato. La usa il taglio della legna: un albero non deve rinascere
## dentro casa, sul pavimento o in mezzo all'orto.
func occupied_spots() -> Array:
	var out := []
	for lvl in 2:
		for layer in [0, 1, 2, 3, "edge"]:
			for key in (_dicts(lvl)[layer] as Dictionary).keys():
				var k: Vector2i = key
				out.append(Vector3(k.x * 0.5, 1.1, k.y * 0.5))
	return out


## Per la verifica CLI: quanti pezzi ci sono nel villaggio (tutti i piani).
func piece_count() -> int:
	var n := 0
	for lvl in 2:
		for layer in [0, 1, 2, 3, "edge"]:
			n += (_dicts(lvl)[layer] as Dictionary).size()
	return n


## Per la verifica CLI: rimuove tutti i pezzi piazzati.
func debug_clear() -> void:
	for lvl in 2:
		for layer in [0, 1, 2, 3, "edge"]:
			for key in (_dicts(lvl)[layer] as Dictionary).keys():
				_remove_at(layer, key, lvl)


# ------------------------------------------------------- demolizione

func _set_demolish(on: bool) -> void:
	if _demolish == on:
		return
	_demolish = on
	if _demo_btn:
		_demo_btn.set_pressed_no_signal(on)
	if _ghost:
		_ghost.visible = _active and not on
	if not on:
		_clear_demolish_target()


func _clear_demolish_target() -> void:
	if _demo_target and is_instance_valid(_demo_target):
		for mi in _demo_target.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = null
	_demo_target = null


func _update_demolish_target() -> void:
	var found := _find_removable()
	var node: Node3D = found[2] if not found.is_empty() else null
	if node == _demo_target:
		return
	_clear_demolish_target()
	_demo_target = node
	if node:
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = _demo_overlay


func _nearest_edge_key() -> Vector2i:
	var p := _mouse_world
	var hz := floorf(p.z) + 0.5
	var vx := floorf(p.x) + 0.5
	var h_d := absf(p.z - hz)
	var v_d := absf(p.x - vx)
	if minf(h_d, v_d) > 0.45:
		return Vector2i.MAX
	if h_d <= v_d:
		return Vector2i(roundi(roundf(p.x) * 2.0), roundi(hz * 2.0))
	return Vector2i(roundi(vx * 2.0), roundi(roundf(p.z) * 2.0))


# F: ruota di 90° l'oggetto già piazzato sotto il cursore (del piano attivo)
func _rotate_placed() -> void:
	var dict := _dicts(_level)[2] as Dictionary
	if not dict.has(_hover_cell):
		return
	var node := dict[_hover_cell] as Node3D
	node.set_meta("rot", posmod(int(node.get_meta("rot", 0)) + 1, 4))
	# pressioni ravvicinate: si mira sempre al bersaglio assoluto accumulato,
	# uccidendo il tween in volo (niente derive di 90° persi per strada)
	var target := float(node.get_meta("rot_target", node.rotation.y)) - PI * 0.5
	node.set_meta("rot_target", target)
	var old_tw = node.get_meta("rot_tw", null)
	if old_tw is Tween and (old_tw as Tween).is_valid():
		(old_tw as Tween).kill()
	var tween := create_tween()
	node.set_meta("rot_tw", tween)
	tween.tween_property(node, "rotation:y", target, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bounce(node)
	if _sfx: _sfx.rotate_tick()
	request_save()


func _spawn_poof(pos: Vector3, color: Color) -> void:
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([color, Color(color, 0.6), Color(color, 0.0)])
	tex.gradient = grad

	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.15
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, -3.2, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex

	var poof := GPUParticles3D.new()
	poof.amount = 16
	poof.lifetime = 0.55
	poof.one_shot = true
	poof.explosiveness = 1.0
	poof.local_coords = false
	poof.process_material = pm
	poof.draw_pass_1 = quad
	poof.position = pos
	add_child(poof)
	poof.emitting = true
	get_tree().create_timer(1.2).timeout.connect(poof.queue_free)


func _bounce(node: Node3D) -> void:
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * 1.12, 0.07)
	tween.tween_property(node, "scale", Vector3.ONE, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shake(node: Node3D) -> void:
	var origin := node.position
	var tween := create_tween()
	tween.tween_property(node, "position:x", origin.x + 0.06, 0.04)
	tween.tween_property(node, "position:x", origin.x - 0.06, 0.05)
	tween.tween_property(node, "position:x", origin.x, 0.05)


# ---------------------------------------------------------------- griglia

func _build_grid_plane() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = GRID_SHADER
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	_grid_plane = MeshInstance3D.new()
	_grid_plane.mesh = plane
	_grid_plane.material_override = mat
	_grid_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid_plane.visible = false
	add_child(_grid_plane)


# ---------------------------------------------------------------- UI
# ============================================================ L'ATELIER
#
# Il banco dei pezzi era una griglia di bottoni di SOLO TESTO: sei colonne
# per tre righe, centotrentasette nomi in fila indiana. In un gioco dove
# ogni pezzo è un oggetto costruito con amore — la fioriera che il prato si
# è ripreso, il biliardino del bar, la conchiglia acustica — il catalogo
# non mostrava un solo pezzo. Era un indice analitico.
#
# L'Atelier ha tre zone, e ognuna risponde a una domanda diversa:
#
#   A SINISTRA · «dove sta?»   — le categorie col loro conto (21/28) e i
#     CORREDI come collezioni: il bar, la caserma, la boutique. Un corredo
#     non è una categoria, è un posto — e finché non lo si poteva vedere
#     intero, era solo un mucchio di quattordici voci quasi uguali.
#   AL CENTRO · «com'è fatto?» — i RITRATTI. Ogni carta è il pezzo vero,
#     fotografato dal suo builder in uno studio in miniatura
#     ([`Miniature.gd`](Miniature.gd)): niente da disegnare a mano, niente
#     da aggiornare quando ne arriva uno nuovo.
#   A DESTRA · «e adesso?»     — IL TACCUINO ([`Consigli.gd`](Consigli.gd)):
#     quello che il villaggio ha visto. Un letto senza tetto, un corredo
#     che si sta popolando, i due pezzi che metti sempre vicini, quanto
#     manca per il Cesto fiorito. Ogni riga viene da un dato che il gioco
#     ha già, e ognuna è un bottone.
#
# E NON RUBA IL MONDO: **Tab** piega l'Atelier in una striscia alta un
# quarto, che tiene il pezzo in mano e i ritratti dei recenti — si continua
# a costruire guardando il villaggio, che è il motivo per cui si costruisce.
#
# Le scorciatoie di prima sono tutte al loro posto (B, R, V, F, X, clic,
# rotella, 1-9, «/»), e la rotella dentro la griglia scorre invece di
# cambiare pezzo: è la griglia a mangiarsi l'evento, non una riga in più.

## La geometria dell'Atelier, a schermo intero (il gioco disegna sempre su
## 1920x1080: `display/window/stretch/mode = "viewport"`).
const ATE_MARGINE := 26.0
const ATE_SOTTO := 16.0
## La barra dei colori: quanto è alta e quanta aria la stacca dal pannello.
const VAR_ALTA := 34.0
const VAR_ARIA := 10.0
const ATE_ALTA := 406.0     # aperto
## ⚠️ QUESTO NUMERO NON SI SCEGLIE: È IL MINIMO MISURATO. Da piegati il
## pannello deve contenere l'intestazione più la striscia, e il conto è
## 24 (i margini di `_stile_pannello`, 12+12) + 34 (`_testata`) + 1
## (`_filo`) + 74 (il bollo del pezzo in mano) + 20 (due separazioni del
## vbox) = **153**. Sotto questo numero il pannello NON si restringe:
## `Control._size_changed` alza il rect al minimo combinato e lo fa
## crescere verso il BASSO, cioè fuori dallo schermo — e `clip_contents`
## non salva niente, perché ritaglia sul rect già cresciuto.
## A 104 (la prima stesura) il bollo del pezzo in mano perdeva 21 px su 74
## — il 28% del ritratto — più il bordo e l'ombra del pannello. A 148 (la
## prima cura, fatta a occhio su un provino) sforava ancora di CINQUE
## pixel: misurato `panel.get_global_rect()` = 916..1069 dentro un dock
## 916..1064. Chi rimpicciolisce la striscia abbassi anche questo; chi lo
## abbassa da solo sega i bolli.
const ATE_BASSA := 153.0    # piegato
const ATE_SINISTRA := 236.0
const ATE_DESTRA := 336.0
## La carta di un pezzo, e il suo ritratto dentro.
## LE TRE SOGLIE DELLA CARTA «QUELLO CHE METTI VICINO», e nessuna delle
## tre e arbitraria: dicono quando un accostamento smette di essere un caso.
## Sotto le tre copie non c'e nessun «quasi sempre» da dire (una volta e un
## aneddoto, due sono una coincidenza); la FORZA e quanto quel vicino ricorre
## in piu di quanto ricorra attorno a qualunque cosa, e mezzo punto vuol dire
## «lo trovo accanto a questo pezzo nella meta dei casi in piu del normale»;
## lo STACCO impedisce la carta quando due o tre pezzi sono a pari merito,
## cioe quando la risposta onesta e «attorno c'e di tutto».
const VICINO_COPIE_MIN := 3
const VICINO_FORZA_MIN := 0.5
const VICINO_STACCO := 0.15

const CARTA := Vector2(106.0, 124.0)
const CARTA_SEP := 8
const MINIA_H := 74.0

## Le due VISTE che non sono categorie (i recenti c'erano già).
const CAT_TUTTO := -2
## I corredi partono da qui e scendono: -100 è il primo, -101 il secondo…
const CAT_SET := -100

var _mini: Node                     # lo studio dei ritratti (Miniature.gd)
var _dock: Control
var _zone: HBoxContainer            # le tre colonne: lo stato aperto
var _striscia: HBoxContainer        # lo stato piegato
var _striscia_row: HBoxContainer
var _sx_col: VBoxContainer
var _taccuino: VBoxContainer
var _ricerca_pill: Button
var _piega_btn: Button
var _aperto := true
var _cat_btn := {}                  # id di vista -> Button (anche i negativi)
var _carte_attesa := {}             # nome del pezzo -> Array[TextureRect]
var _taccuino_sporco := true
var _corredi_cache := {}
var _corredi_letti := false


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 3
	add_child(_ui)

	# LO STUDIO DEI RITRATTI, prima di tutto: le carte glieli chiedono
	# mentre si costruiscono. In headless nasce spento e non alloca niente.
	_mini = MINIATURE.new()
	_mini.name = "Miniature"
	add_child(_mini)
	_mini.pronta.connect(_su_miniatura)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	_dock = Control.new()
	_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dock.offset_left = ATE_MARGINE
	_dock.offset_right = -ATE_MARGINE
	_dock.offset_top = -(ATE_ALTA + ATE_SOTTO)
	_dock.offset_bottom = -ATE_SOTTO
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dock)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_theme_stylebox_override("panel", _stile_pannello())
	_panel.clip_contents = true
	_panel.visible = false
	_dock.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	vbox.add_child(_testata())
	vbox.add_child(_filo(true))

	# ---- lo stato APERTO: tre colonne
	_zone = HBoxContainer.new()
	_zone.add_theme_constant_override("separation", 14)
	_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_zone)
	_zone.add_child(_colonna_sinistra())
	_zone.add_child(_filo(false))
	_zone.add_child(_colonna_centro())
	_zone.add_child(_filo(false))
	_zone.add_child(_colonna_destra())

	# ---- lo stato PIEGATO: il pezzo in mano e i ritratti dei recenti
	_striscia = HBoxContainer.new()
	_striscia.add_theme_constant_override("separation", 12)
	_striscia.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_striscia.visible = false
	vbox.add_child(_striscia)
	_striscia_row = HBoxContainer.new()
	_striscia_row.add_theme_constant_override("separation", 8)
	_striscia_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_striscia.add_child(_striscia_row)

	_rebuild_item_row()
	_sync_ui_selection()

	_idle_hint = Label.new()
	_idle_hint.text = L10n.t("B — modalità costruzione")
	_idle_hint.add_theme_font_size_override("font_size", 13)
	_idle_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_idle_hint.add_theme_color_override("font_shadow_color", Color(0.3, 0.2, 0.15, 0.5))
	_idle_hint.add_theme_constant_override("shadow_offset_y", 1)
	_idle_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_idle_hint)
	_idle_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_idle_hint.offset_left = -260.0
	_idle_hint.offset_right = -16.0
	_idle_hint.offset_top = -36.0
	_idle_hint.offset_bottom = -12.0


func _stile_pannello() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(CozyUI.PAPER, 0.972)
	sb.set_corner_radius_all(22)
	sb.border_color = Color(0.62, 0.46, 0.34, 0.5)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0.26, 0.16, 0.11, 0.34)
	sb.shadow_size = 22
	sb.shadow_offset = Vector2(0, 8)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb


## Il filo che separa due zone: un capello di inchiostro annacquato. Un
## bordo vero farebbe scatole dentro scatole, e questo è un banco di
## legno, non un modulo da compilare.
func _filo(orizzontale: bool) -> Control:
	var r := ColorRect.new()
	r.color = Color(0.62, 0.46, 0.34, 0.22)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if orizzontale:
		r.custom_minimum_size = Vector2(0, 1)
	else:
		r.custom_minimum_size = Vector2(1, 0)
		r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return r


# --------------------------------------------------------------- testata

func _testata() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.custom_minimum_size = Vector2(0, 34)

	var tit := Label.new()
	tit.text = L10n.t("L'Atelier")
	tit.add_theme_font_size_override("font_size", 21)
	tit.add_theme_color_override("font_color", CozyUI.TITLE)
	tit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(tit)

	# la voce del Gufo: l'Ordine in corso, in un bigliettino appuntato
	# accanto al titolo ("" = niente bigliettino)
	_order_banner = Label.new()
	_order_banner.add_theme_font_size_override("font_size", 13)
	_order_banner.add_theme_color_override("font_color", Color("8a5a3a"))
	_order_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_order_banner.clip_text = true
	_order_banner.custom_minimum_size = Vector2(0, 26)
	_order_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_order_banner.visible = false
	var bigl := PanelContainer.new()
	bigl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bigl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bsb := CozyUI.pill(Color(CozyUI.HONEY, 0.30), 13)
	bsb.content_margin_left = 12.0
	bsb.content_margin_right = 12.0
	bsb.content_margin_top = 2.0
	bsb.content_margin_bottom = 2.0
	bigl.add_theme_stylebox_override("panel", bsb)
	bigl.add_child(_order_banner)
	h.add_child(bigl)
	# ⚠️ È IL CONTENITORE CHE SI NASCONDE, non la Label. Nella vecchia
	# testata `_order_banner` era figlio diretto del VBox e nasconderlo lo
	# faceva sparire; qui la Label sta dentro una pillola color miele, e
	# spegnere solo lei lasciava a schermo una striscia gialla alta 4 px e
	# larga mezza intestazione, vuota — che è quello che vede chi ha finito
	# la campagna del Gufo, o chi ha un salvataggio anteriore agli Ordini.
	_order_pill = bigl
	bigl.visible = false

	# LA RICERCA. Resta guidata dalla tastiera («/»), perché in un gioco
	# che si costruisce con le lettere un cursore sempre acceso ruberebbe
	# R, V, F e X — ma adesso SEMBRA quello che è, e si accende anche
	# cliccandola.
	_ricerca_pill = Button.new()
	_ricerca_pill.focus_mode = Control.FOCUS_NONE
	_ricerca_pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_ricerca_pill.custom_minimum_size = Vector2(258, 30)
	_ricerca_pill.clip_text = true
	_ricerca_pill.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_ricerca_pill.add_theme_font_size_override("font_size", 13)
	_ricerca_pill.add_theme_color_override("font_color", UI_BROWN)
	_ricerca_pill.add_theme_color_override("font_hover_color", UI_BROWN)
	var rsb := CozyUI.pill(Color(1, 1, 1, 0.62), 15)
	rsb.border_color = Color(0.62, 0.46, 0.34, 0.30)
	rsb.set_border_width_all(1)
	rsb.content_margin_left = 12.0
	rsb.content_margin_right = 12.0
	var rho := rsb.duplicate() as StyleBoxFlat
	rho.bg_color = Color(1, 1, 1, 0.85)
	_ricerca_pill.add_theme_stylebox_override("normal", rsb)
	_ricerca_pill.add_theme_stylebox_override("hover", rho)
	_ricerca_pill.add_theme_stylebox_override("pressed", rho)
	_ricerca_pill.pressed.connect(_ricerca_accendi)
	h.add_child(_ricerca_pill)
	_ricerca_label = null   # la pillola È l'etichetta della ricerca

	_conta_label = Label.new()
	_conta_label.add_theme_font_size_override("font_size", 13)
	_conta_label.add_theme_color_override("font_color", Color(UI_BROWN, 0.62))
	_conta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_conta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_conta_label.custom_minimum_size = Vector2(94, 0)
	h.add_child(_conta_label)

	_demo_btn = _pillola(L10n.t("✕ Demolisci"), CozyUI.DANGER, 13)
	_demo_btn.toggle_mode = true
	_demo_btn.add_theme_color_override("font_color", Color("a83a3a"))
	_demo_btn.add_theme_color_override("font_hover_color", Color("a83a3a"))
	_demo_btn.toggled.connect(func(on: bool): _set_demolish(on))
	h.add_child(_demo_btn)

	_piega_btn = _pillola(L10n.t("Tab — richiudi"), CozyUI.SKY, 13)
	_piega_btn.pressed.connect(func(): _piega(not _aperto))
	h.add_child(_piega_btn)
	return h


## Una pillola: il bottone piccolo della casa (categoria, strumento,
## suggerimento). Non usa `CozyUI.cozy_button` perché quello è alto 52 e
## qui la riga è alta 30 — ma ne tiene la grammatica: bianco latte a
## riposo, la tinta al passaggio, l'inchiostro sempre leggibile.
func _pillola(testo: String, tinta: Color, corpo := 13) -> Button:
	var b := Button.new()
	b.text = testo
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(0, 30)
	# ⚠️ NIENTE clip_text qui: toglie il testo dalla dimensione minima, e una
	# pillola in un contenitore che si restringe collassa sui soli margini —
	# ne uscivano tre cerchietti bianchi VUOTI (i due strumenti in alto e il
	# pezzo consigliato dal taccuino). Chi ha un testo lungo lo clippa da sé.
	b.add_theme_font_size_override("font_size", corpo)
	b.add_theme_color_override("font_color", UI_BROWN)
	b.add_theme_color_override("font_hover_color", UI_BROWN)
	b.add_theme_color_override("font_pressed_color", UI_BROWN)
	b.add_theme_color_override("font_disabled_color", Color(UI_BROWN, 0.38))
	var n := CozyUI.pill(Color(1, 1, 1, 0.5), 15)
	n.content_margin_left = 13.0
	n.content_margin_right = 13.0
	var ho := CozyUI.pill(Color(tinta, 0.70), 15)
	ho.content_margin_left = 13.0
	ho.content_margin_right = 13.0
	var pr := CozyUI.pill(Color(tinta, 0.95), 15)
	pr.content_margin_left = 13.0
	pr.content_margin_right = 13.0
	var di := CozyUI.pill(Color(0.82, 0.78, 0.72, 0.28), 15)
	di.content_margin_left = 13.0
	di.content_margin_right = 13.0
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", ho)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("hover_pressed", pr)
	b.add_theme_stylebox_override("disabled", di)
	return b


# ------------------------------------------------------- colonna sinistra

func _colonna_sinistra() -> Control:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(ATE_SINISTRA, 0)
	v.add_theme_constant_override("separation", 6)
	v.add_child(_sezione(L10n.t("Il catalogo")))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_sx_col = VBoxContainer.new()
	_sx_col.add_theme_constant_override("separation", 3)
	_sx_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_sx_col)
	_rifai_sinistra()
	return v


func _sezione(testo: String) -> Label:
	var l := Label.new()
	l.text = testo
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(UI_BROWN, 0.52))
	return l


## Le righe di sinistra si RIFANNO, non si aggiornano a pezzi: i conti
## («21 di 28») cambiano quando compri, quando il Gufo sblocca e quando
## posi, e tre strade che scrivono la stessa etichetta divergono.
func _rifai_sinistra() -> void:
	if _sx_col == null:
		return
	for c in _sx_col.get_children():
		_sx_col.remove_child(c)
		c.queue_free()
	_cat_btn.clear()
	_cat_buttons.clear()

	_cat_recenti_btn = _riga_vista(L10n.t("★ Recenti"), CAT_RECENTI, "", CozyUI.GOLD)
	_spegni_riga(_cat_recenti_btn, _recenti.is_empty())
	if _recenti.is_empty():
		_cat_recenti_btn.tooltip_text = L10n.t("Qui finiscono i pezzi che posi")
	_sx_col.add_child(_cat_recenti_btn)
	_sx_col.add_child(_riga_vista(L10n.t("Tutto il catalogo"), CAT_TUTTO,
			str(_items.size()), CozyUI.PEACH))

	_sx_col.add_child(_spazio(6))
	for c in CAT_NAMES.size():
		var liberi := 0
		var tot := 0
		for i in _items.size():
			if int(_items[i]["cat"]) == c:
				tot += 1
				if is_unlocked(str(_items[i]["name"])):
					liberi += 1
		var conto := str(tot) if liberi == tot else "%d/%d" % [liberi, tot]
		var b := _riga_vista(L10n.t(CAT_NAMES[c]), c, conto, CozyUI.PINK)
		_sx_col.add_child(b)
		_cat_buttons.append(b)

	# I CORREDI. Un corredo non è una categoria: è un POSTO — il bar, la
	# caserma, la boutique — e i suoi quattordici pezzi, sparsi in tre
	# categorie diverse, non si vedevano mai insieme. Il conto è di pezzi
	# POSATI su totali: una collezione che si riempie costruendo, non una
	# lista di cose da fare.
	var corr := _corredi()
	if not corr.is_empty():
		_sx_col.add_child(_spazio(8))
		# ⚠️ L'INTESTAZIONE DICE LA GRANDEZZA, perché è diversa da quella di
		# sopra. Le categorie contano quel che POSSIEDI, i corredi quel che
		# hai POSATO — e nella stessa colonna, nella stessa pillola bianca,
		# con la stessa frazione, si leggono come la stessa cosa. Non è
		# teorico: Boutique e «Vetrina moda» sono ESATTAMENTE gli stessi
		# quindici pezzi, e a tre righe di distanza mostravano due numeri
		# diversi senza che niente spiegasse perché. E il conto dei posati
		# può SCENDERE (demolisci e cala), cosa che il possesso non fa mai.
		var t_cor := _sezione(L10n.t("I corredi — quanti ne hai posati"))
		t_cor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sx_col.add_child(t_cor)
		var conteggi := piece_counts()
		var k := 0
		for capo in corr:
			var nomi: Array = [capo]
			nomi.append_array(corr[capo])
			var messi := 0
			for n in nomi:
				if int(conteggi.get(str(n), 0)) > 0:
					messi += 1
			# e la FORMA è diversa da quella delle categorie («21/28»):
			# due grandezze diverse non indossano la stessa grammatica
			var b2 := _riga_vista(L10n.t(str(capo)), CAT_SET - k,
					L10n.tf("%d di %d", [messi, nomi.size()]), CozyUI.LAVENDER)
			if not is_unlocked(str(capo)):
				# non è tuo: resta leggibile ma spento, col suo prezzo
				var off := _shop_offer(str(capo))
				b2.modulate = Color(1, 1, 1, 0.62)
				if not off.is_empty():
					b2.tooltip_text = _shop_tooltip(off)
			_sx_col.add_child(b2)
			k += 1


func _spazio(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Una riga della colonna: il nome a sinistra, il conto a destra. È un
## bottone con dentro due etichette (che non intercettano il mouse, o il
## bottone smetterebbe di essere premibile in mezzo).
## Una riga della colonna che NON si può premere deve dirlo. ⚠️ Non basta
## `b.disabled`: `_riga_vista` mette le parole in due `Label` FIGLIE (il
## bottone ha il testo vuoto), e `font_disabled_color` non tocca i figli —
## quindi «★ Recenti» spenta aveva lo stesso inchiostro di tutte le altre,
## il cursore a manina, e al clic non succedeva niente. E capita a OGNI
## avvio, non solo in partita nuova: `_recenti` non è persistita.
func _spegni_riga(b: Button, spenta: bool) -> void:
	b.disabled = spenta
	b.modulate = Color(1, 1, 1, 0.45) if spenta else Color(1, 1, 1, 1)
	b.mouse_default_cursor_shape = Control.CURSOR_ARROW if spenta \
			else Control.CURSOR_POINTING_HAND


func _riga_vista(testo: String, vista: int, conto: String, tinta: Color) -> Button:
	var b := _pillola("", tinta, 14)
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 30)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 13.0
	h.offset_right = -13.0
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = testo
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", UI_BROWN)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	var c := Label.new()
	c.text = conto
	c.add_theme_font_size_override("font_size", 12)
	c.add_theme_color_override("font_color", Color(UI_BROWN, 0.5))
	c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(c)
	b.add_child(h)
	b.pressed.connect(_on_cat_pressed.bind(vista))
	_cat_btn[vista] = b
	return b


## I corredi, letti dalla loro fonte unica (`Economy.CORREDO`). Si legge
## dalla mappa delle costanti dello script perché l'economia è un `Node`
## non tipizzato: la costante non è raggiungibile per nome.
func _corredi() -> Dictionary:
	if _corredi_letti:
		return _corredi_cache
	var eco := _economy()
	if eco == null:
		return {}          # economia non ancora in scena: si riproverà
	var sc := eco.get_script() as GDScript
	if sc == null:
		return {}
	var tab: Variant = sc.get_script_constant_map().get("CORREDO")
	if tab is Dictionary:
		_corredi_cache = tab as Dictionary
	_corredi_letti = true
	return _corredi_cache


# --------------------------------------------------------- colonna centro

func _colonna_centro() -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	_items_scroll = ScrollContainer.new()
	_items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_items_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_items_scroll.follow_focus = true
	v.add_child(_items_scroll)
	# SI CHIEDE SOLO CIÒ CHE SI GUARDA: scorrendo, le carte che entrano in
	# vista si mettono in coda per il ritratto. Senza, aprire il Giardino
	# vorrebbe dire ordinare trentotto ritratti di cui se ne vedono venti.
	_items_scroll.get_v_scroll_bar().value_changed.connect(
			func(_v): _chiedi_visibili())
	_items_row = GridContainer.new()
	_items_row.columns = _colonne()
	_items_row.add_theme_constant_override("h_separation", CARTA_SEP)
	_items_row.add_theme_constant_override("v_separation", CARTA_SEP)
	_items_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_scroll.add_child(_items_row)

	var hint := Label.new()
	hint.text = L10n.t("clic posa  ·  R gira  ·  V piano  ·  F gira un pezzo posato  ·  X toglie  ·  rotella e 1-9 scelgono  ·  / cerca  ·  Tab richiude  ·  B esce")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(UI_BROWN, 0.55))
	hint.clip_text = true
	v.add_child(hint)
	return v


## Quante colonne ci stanno DAVVERO. Si calcola sulla larghezza vera dello
## schermo invece di scriverla a mano: chi gioca in finestra piccola non
## deve trovare la griglia tagliata a metà.
func _colonne() -> int:
	var largo := 1920.0
	var vp := get_viewport()
	if vp:
		largo = vp.get_visible_rect().size.x
	var utile := largo - 2.0 * ATE_MARGINE - 36.0 - ATE_SINISTRA - ATE_DESTRA \
			- 2.0 * 14.0 - 2.0 - 16.0
	return clampi(int(floor((utile + CARTA_SEP) / (CARTA.x + CARTA_SEP))), 3, 14)


# --------------------------------------------------------- colonna destra

func _colonna_destra() -> Control:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(ATE_DESTRA, 0)
	v.add_theme_constant_override("separation", 6)
	v.add_child(_sezione(L10n.t("Il taccuino")))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_taccuino = VBoxContainer.new()
	_taccuino.add_theme_constant_override("separation", 7)
	_taccuino.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_taccuino)
	return v


## I FATTI, letti dalle loro fonti — mai inventati, mai ricopiati.
func _fatti_atelier() -> Dictionary:
	var f := {}
	var conteggi := piece_counts()
	var posati := 0
	for n in conteggi:
		posati += int(conteggi[n])
	f["posati"] = posati

	# i letti senza niente sopra: la stessa domanda del trasloco
	var scoperti := 0
	for letto in get_placed_by_name("Letto"):
		if not has_cover(Vector2i(roundi(letto.position.x), roundi(letto.position.z))):
			scoperti += 1
	f["letti_scoperti"] = scoperti

	# CHI STA VICINO A CHI — e ⚠️ LA GRANDEZZA CONTATA È LA VOLTA, NON LA
	# CELLA. La prima stesura sommava una unità per ogni cella vicina, e
	# così un Sentiero che passa davanti a UNA panchina valeva venti: la
	# carta diceva «quasi sempre» su un campione di uno, e quasi sempre
	# nominava il pavimento. È l'inferenza smentibile che il taccuino del
	# Gufo ha per regola di non fare — e una carta smentibile non attenua
	# la fiducia nel taccuino, la INVERTE.
	#
	# Adesso si conta, per ogni COPIA del pezzo che hai in mano, l'insieme
	# DISTINTO di quel che le sta attorno; e si sottrae quanto quel vicino
	# starebbe lì per caso, cioè quanto sta vicino a QUALUNQUE cosa (un
	# pavimento è vicino a tutto: la sua frazione di fondo è alta e non
	# emerge). Nessuna lista di esclusioni da tenere allineata a mano.
	var perno := str(_items[_index]["name"]) if _index < _items.size() else ""
	var mappa := _mappa_celle()
	if perno != "" and mappa.size() > 1:
		var conto := {}       # nome -> a quante COPIE del perno sta accanto
		var fondo := {}       # nome -> a quante celle occupate sta accanto
		var n_perni := 0
		for cella in mappa:
			var e_perno: bool = (mappa[cella] as Array).has(perno)
			if e_perno:
				n_perni += 1
			var visti := {}
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					var altra: Variant = mappa.get(cella + Vector2i(dx, dz), null)
					if altra == null:
						continue
					for nome in (altra as Array):
						if str(nome) == perno:
							continue
						visti[nome] = true
			for nome in visti:
				fondo[nome] = int(fondo.get(nome, 0)) + 1
				if e_perno:
					conto[nome] = int(conto.get(nome, 0)) + 1
		# «quasi sempre» non si dice su meno di tre volte: sotto, quello
		# che si vede non è un'abitudine, è dove c'era posto
		if n_perni >= VICINO_COPIE_MIN:
			var mgl := ""
			var mgl_n := 0
			var mgl_forza := 0.0
			var secondo := 0.0
			for nome in conto:
				var q := int(conto[nome])
				var forza := float(q) / float(n_perni) \
						- float(fondo.get(nome, 0)) / float(mappa.size())
				if forza > mgl_forza:
					secondo = mgl_forza
					mgl_forza = forza
					mgl_n = q
					mgl = str(nome)
				elif forza > secondo:
					secondo = forza
			# e deve STACCARE il secondo, o non è «quello che metti
			# vicino»: è «attorno c'è di tutto», che non dice niente
			if mgl_n >= VICINO_COPIE_MIN and mgl_forza >= VICINO_FORZA_MIN \
					and mgl_forza >= secondo + VICINO_STACCO and is_unlocked(mgl):
				f["vicino"] = {"perno": perno, "nome": mgl,
						"quante": mgl_n, "su": n_perni}

	# IL CORREDO CHE SI STA POPOLANDO: fra quelli tuoi, quello a cui manca
	# meno (e che hai già cominciato).
	var meglio := {}
	for capo in _corredi():
		if not is_unlocked(str(capo)):
			continue
		var nomi: Array = [capo]
		nomi.append_array(_corredi()[capo])
		var messi := 0
		var prossimo := ""
		for n in nomi:
			if int(conteggi.get(str(n), 0)) > 0:
				messi += 1
			elif prossimo == "":
				prossimo = str(n)
		if messi == 0 or prossimo == "":
			continue
		if meglio.is_empty() or messi > int(meglio.get("messi", 0)):
			meglio = {"capo": str(capo), "messi": messi, "totale": nomi.size(),
					"prossimo": prossimo}
	f["corredo"] = meglio

	# I RISPARMI: la cosa del carretto più vicina alle tue tasche.
	#
	# ⚠️ FRA QUELLE CHE IL CARRETTO HA IN BANCO OGGI, non fra tutto il
	# listino. `Economy.rotate_stock` pesca 3-4 nomi per visita e il Shop
	# mostra solo quelli: scorrendo `SHOP_PIECES` il taccuino prometteva un
	# pezzo che quel giorno non era in vendita — il giocatore metteva da
	# parte le noccioline, aspettava la visita, apriva il carretto e
	# trovava altre tre voci. È una promessa che il gioco non può
	# mantenere, cioè la stessa famiglia dell'inferenza smentibile: la
	# carta successiva non la crederà più.
	#
	# Se il banco è vuoto (nessuna visita ancora, o comprato tutto) non si
	# dice niente — il silenzio è un esito.
	var eco := _economy()
	if eco != null and eco.has_method("piece_offer"):
		var borsa_n := int(eco.get("nuts"))
		var borsa_s := int(eco.get("stars"))
		var scelto := {}
		var scarto := 1 << 30
		var in_banco: Array = []
		if eco.has_method("stock_offers"):
			for o in eco.call("stock_offers"):
				in_banco.append(str((o as Dictionary).get("name", "")))
		for i in _items.size():
			var nome := str(_items[i]["name"])
			if is_unlocked(nome) or not in_banco.has(nome):
				continue
			var off := _shop_offer(nome)
			if off.is_empty():
				continue
			var cur := str(off.get("cur", "nut"))
			var costo := int(off.get("cost", 0))
			var ho := borsa_n if cur == "nut" else borsa_s
			# le stelline sono rare: il loro scarto si pesa di più, o un
			# pezzo da 4 stelline sembrerebbe sempre il più vicino
			var d: int = maxi(costo - ho, 0) * (1 if cur == "nut" else 18)
			if d < scarto:
				scarto = d
				scelto = {"nome": nome, "costo": costo, "cur": cur,
						"manca": maxi(costo - ho, 0), "puoi": ho >= costo}
		f["affare"] = scelto

	# IL PEZZO CHE NON HAI MAI PROVATO: tuo, e mai posato. Si scorre dal
	# fondo del catalogo, dove stanno le cose arrivate per ultime.
	var mai := ""
	for i in range(_items.size() - 1, -1, -1):
		var nome := str(_items[i]["name"])
		if is_unlocked(nome) and int(conteggi.get(nome, 0)) == 0:
			mai = nome
			break
	f["mai_usato"] = mai
	return f


## Tutti i pezzi posati, per cella. I bordi hanno la chiave RADDOPPIATA
## (un muro sta SUL confine): si riporta alla cella dividendo per due, o
## il muro di casa risulterebbe a dieci metri dal letto che chiude.
func _mappa_celle() -> Dictionary:
	var out := {}
	for lvl in 2:
		for layer in [0, 1, 2, 3, "edge"]:
			var d := _dicts(lvl)[layer] as Dictionary
			for key in d:
				var k: Vector2i = key
				# `layer` gira su [0, 1, 2, 3, "edge"] e GDScript lo tipizza
				# INT: confrontarlo con una stringa è un errore a runtime, e
				# questa funzione sta in `_process` — un errore per fotogramma,
				# che non fa fallire nessun test e sporca ogni log del gioco
				var cella := Vector2i(k.x / 2, k.y / 2) if str(layer) == "edge" else k
				var nome: String = (d[key] as Node3D).get_meta("item_name", "")
				if nome == "":
					continue
				if not out.has(cella):
					out[cella] = []
				if not (out[cella] as Array).has(nome):
					(out[cella] as Array).append(nome)
	return out


func _rifai_taccuino() -> void:
	if _taccuino == null:
		return
	_taccuino_sporco = false
	for c in _taccuino.get_children():
		_taccuino.remove_child(c)
		c.queue_free()
	for carta in CONSIGLI.consiglia(_fatti_atelier()):
		_taccuino.add_child(_carta_consiglio(carta as Dictionary))


func _carta_consiglio(c: Dictionary) -> Control:
	var tinta: Color = c.get("tinta", CozyUI.HONEY)
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tinta, 0.16)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(tinta, 0.55)
	sb.set_border_width_all(1)
	# la costola colorata a sinistra: si riconosce la famiglia del
	# consiglio prima di averlo letto
	sb.border_width_left = 4
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 9.0
	sb.content_margin_bottom = 9.0
	p.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	p.add_child(v)
	var l := Label.new()
	l.text = str(c.get("testo", ""))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", CozyUI.INK)
	v.add_child(l)

	var pezzo := str(c.get("pezzo", ""))
	var idx := item_index(pezzo)
	if pezzo != "" and idx >= 0:
		var b := _pillola(L10n.t(pezzo), tinta, 13)
		b.custom_minimum_size = Vector2(0, 27)
		# ⚠️ la pillola NON si restringe sul testo: _pillola ha clip_text, che
		# toglie il testo dalla dimensione minima — con SHRINK_BEGIN il bottone
		# collassava sui soli margini e usciva un cerchietto bianco VUOTO
		b.size_flags_horizontal = Control.SIZE_FILL
		# un consiglio è un BOTTONE: se il pezzo è tuo lo prende in mano,
		# se non lo è ancora te lo fa VEDERE (nessun diniego in faccia a
		# chi ha appena letto che gli piacerebbe averlo)
		if is_unlocked(pezzo):
			b.pressed.connect(_select.bind(idx))
		else:
			b.pressed.connect(_mostra_pezzo.bind(pezzo))
		v.add_child(b)
	return p


## Portare in vista un pezzo che non è (ancora) tuo: si apre la sua
## categoria e lo si cerca per nome, così compare al centro con la sua
## promessa addosso. Non si SELEZIONA — selezionarlo sarebbe un diniego.
func _mostra_pezzo(pezzo: String) -> void:
	var i := item_index(pezzo)
	if i < 0:
		return
	# ⚠️ NELLA BARRA VA IL NOME TRADOTTO. `pezzo` è la chiave di catalogo,
	# che è la frase ITALIANA (la regola della lingua: la chiave È la
	# frase): scrivendola così, chi gioca in inglese vedeva comparire una
	# parola italiana in un campo che ha appena scritto lui. La ricerca
	# trova comunque (`_cerca_indici` guarda il nome E la traduzione), e in
	# italiano `L10n.t` è l'identità — quindi non cambia un bit.
	_ricerca = L10n.t(pezzo)
	_ricerca_attiva = false
	_rebuild_item_row()
	_sync_ui_selection()
	if _sfx: _sfx.ui_select()


# ------------------------------------------------------------- le carte

func _on_cat_pressed(cat: int) -> void:
	if cat == _cat and _ricerca == "":
		_sync_ui_selection()
		return
	_set_demolish(false)  # cambiare vista esce dalla demolizione
	# toccare una scheda chiude la ricerca: sono due modi di guardare lo
	# stesso banco, e tenerli accesi insieme lascia il giocatore a
	# chiedersi perché la categoria che ha appena scelto è mezza vuota
	_ricerca = ""
	_ricerca_attiva = false
	_cat = cat
	_rebuild_item_row()
	# seleziona il primo pezzo POSABILE della scheda (se ce n'è)
	var pick := -1
	for i in _visibili:
		if is_unlocked(str(_items[i]["name"])):
			pick = i
			break
	if pick >= 0:
		_select(pick)
	else:
		_sync_ui_selection()


func _rebuild_item_row() -> void:
	if _items_row == null:
		return
	_item_buttons.clear()
	_carte_attesa.clear()
	for f in _items_row.get_children():
		_items_row.remove_child(f)
		f.queue_free()
	if _mini: _mini.svuota_coda()
	_items_row.columns = _colonne()
	var group := ButtonGroup.new()
	_visibili = _pezzi_visibili()
	var n_libero := 0          # i numeri 1-9 contano SOLO i posabili
	for j in _visibili.size():
		var i := _visibili[j]
		var numero := 0
		if is_unlocked(str(_items[i]["name"])):
			n_libero += 1
			# il numero è una SCORCIATOIA, e le scorciatoie sono nove:
			# stamparlo sulla decima carta sarebbe un tasto che non esiste
			if n_libero <= 9:
				numero = n_libero
		var carta := _carta_pezzo(i, numero, group)
		_items_row.add_child(carta)
		_item_buttons.append(carta)
	if _visibili.is_empty():
		var vuoto := Label.new()
		vuoto.text = L10n.t("Niente da queste parti.") if _ricerca == "" \
				else L10n.t("Nessun pezzo con questo nome.")
		vuoto.add_theme_font_size_override("font_size", 13)
		vuoto.add_theme_color_override("font_color", Color(UI_BROWN, 0.6))
		_items_row.add_child(vuoto)
	_aggiorna_barra()
	if _items_scroll:
		_items_scroll.scroll_vertical = 0
	_chiedi_visibili.call_deferred()


## La carta di un pezzo: il suo RITRATTO, il nome, e — se non è ancora
## tuo — la promessa giusta. Tre promesse diverse, perché tre sono i modi
## in cui un pezzo arriva: si compra al carretto (prezzo), viene col
## corredo di un altro (il nome del capo), o lo porta un Ordine del Gufo —
## e quello resta un «?», perché la rivelazione È il premio.
func _carta_pezzo(i: int, numero: int, group: ButtonGroup) -> Button:
	var piece := str(_items[i]["name"])
	var locked := not is_unlocked(piece)
	var offer := _shop_offer(piece) if locked else {}
	var padrone := _padrone_corredo(piece) if locked and offer.is_empty() else ""
	var segreto := locked and offer.is_empty() and padrone == ""

	var b := Button.new()
	b.toggle_mode = true
	b.button_group = group
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CARTA
	b.tooltip_text = L10n.t(piece)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_veste_carta(b, segreto)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6.0
	v.offset_right = -6.0
	v.offset_top = 6.0
	v.offset_bottom = -6.0
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)

	if segreto:
		var q := Label.new()
		q.text = "?"
		q.add_theme_font_size_override("font_size", 34)
		q.add_theme_color_override("font_color", Color(UI_BROWN, 0.34))
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.custom_minimum_size = Vector2(0, MINIA_H)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(q)
		b.tooltip_text = L10n.t("Un Ordine del Gufo lo porterà")
	else:
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(0, MINIA_H)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.modulate = Color(1, 1, 1, 1) if not locked else Color(1, 1, 1, 0.55)
		v.add_child(tr)
		var gia: Texture2D = _mini.presa(piece) if _mini else null
		if gia != null:
			tr.texture = gia
		else:
			# il ritratto non c'è ancora: la carta lo aspetta, e quando
			# arriva entra in dissolvenza invece di comparire di scatto
			if not _carte_attesa.has(piece):
				_carte_attesa[piece] = []
			(_carte_attesa[piece] as Array).append(tr)

	var l := Label.new()
	l.text = L10n.t("un giorno") if segreto else L10n.t(piece)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color",
			Color(UI_BROWN, 0.42) if locked else CozyUI.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# due righe, e i puntini invece del taglio a metà parola: i nomi lunghi
	# ("Lampada semplice", "Campana caserma") uscivano mozzati da tutte e due
	# le parti, perché il testo è centrato e clip_text taglia dove capita
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 2
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(0, 30)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)

	if numero > 0:
		b.add_child(_gettone(str(numero), Color(1, 1, 1, 0.72),
				Color(UI_BROWN, 0.75)))
	if not offer.is_empty():
		b.add_child(_prezzo(int(offer.get("cost", 0)), str(offer.get("cur", "nut"))))
		b.tooltip_text = _shop_tooltip(offer)
		b.set_meta("shop_offer", offer)
	elif padrone != "":
		b.add_child(_nastro(L10n.t("corredo"), CozyUI.LAVENDER))
		b.tooltip_text = L10n.tf("Arriva col corredo di %s", [L10n.t(padrone)])

	if locked:
		b.disabled = true
	else:
		b.pressed.connect(_select.bind(i))
	return b


func _veste_carta(b: Button, segreto: bool) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(1, 1, 1, 0.42) if not segreto else Color(1, 1, 1, 0.14)
	n.set_corner_radius_all(14)
	n.border_color = Color(0.62, 0.46, 0.34, 0.20)
	n.set_border_width_all(1)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(1, 1, 1, 0.86)
	h.border_color = Color(CozyUI.PINK_DEEP, 0.75)
	h.set_border_width_all(2)
	h.shadow_color = Color(0.4, 0.25, 0.3, 0.22)
	h.shadow_size = 8
	h.shadow_offset = Vector2(0, 3)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = Color(CozyUI.PINK, 0.55)
	p.border_color = CozyUI.PINK_TEXT
	p.set_border_width_all(2)
	p.shadow_color = Color(0.5, 0.3, 0.35, 0.28)
	p.shadow_size = 10
	p.shadow_offset = Vector2(0, 4)
	var d := n.duplicate() as StyleBoxFlat
	# ⚠️ ANCHE IL «disabled» DEVE SAPERE DEL SEGRETO. Una carta segreta è
	# per costruzione `b.disabled = true`, quindi Godot disegna QUESTO
	# stilo e non `normal`: scrivendo qui un colore fisso, il ramo segreto
	# di `n` non veniva mai disegnato e in una partita nuova la griglia era
	# un muro di carte tutte dello stesso peso — i pochi pezzi già tuoi non
	# spiccavano più di quelli che il Gufo deve ancora portare.
	d.bg_color = Color(1, 1, 1, 0.20 if not segreto else 0.09)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", CozyUI.pill(Color(1, 1, 1, 0.0), 14))


## Il numerino della scorciatoia, in alto a sinistra sulla carta.
func _gettone(testo: String, sfondo: Color, inchiostro: Color) -> Control:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_TOP_LEFT)
	p.offset_left = 5.0
	p.offset_top = 4.0
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := CozyUI.pill(sfondo, 8)
	sb.content_margin_left = 5.0
	sb.content_margin_right = 5.0
	sb.content_margin_top = 0.0
	sb.content_margin_bottom = 0.0
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = testo
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", inchiostro)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


## Il cartellino del prezzo, in basso a destra: la moneta disegnata a mano
## (`CozyUI.nut/star`) e il numero. È la stessa moneta del borsellino in
## alto a destra, ed è per quello che si legge senza spiegazioni.
func _prezzo(costo: int, cur: String) -> Control:
	var p := PanelContainer.new()
	# ⚠️ IL CARTELLINO STA SUL BORDO DELLA MINIATURA, NON SUL NOME. A
	# -48/-28 cadeva sulla fascia y 76..96 e il nome comincia a 82: sulle
	# carte a pagamento — cioè su TUTTE quelle del carretto, in una partita
	# vera — il prezzo copriva il nome del pezzo. Qui sotto c'e solo il
	# disco d'ombra del ritratto, e restano quattro pixel d'aria.
	p.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	p.offset_left = -62.0
	p.offset_right = -5.0
	p.offset_top = -66.0
	p.offset_bottom = -46.0
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := CozyUI.pill(Color(CozyUI.CREAM, 0.93), 9)
	sb.border_color = Color(CozyUI.NUT if cur == "nut" else CozyUI.GOLD, 0.75)
	sb.set_border_width_all(1)
	sb.content_margin_left = 5.0
	sb.content_margin_right = 5.0
	sb.content_margin_top = 0.0
	sb.content_margin_bottom = 0.0
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var ic: Control = CozyUI.nut(13) if cur == "nut" else CozyUI.star(13)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var l := Label.new()
	l.text = str(costo)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", CozyUI.INK)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	return p


## Il nastrino del corredo: una parola sola, perché il nome del capo può
## essere lungo il doppio della carta. Chi vuole sapere con cosa arriva
## legge la didascalia.
func _nastro(testo: String, tinta: Color) -> Control:
	var p := PanelContainer.new()
	# ⚠️ IL CARTELLINO STA SUL BORDO DELLA MINIATURA, NON SUL NOME. A
	# -48/-28 cadeva sulla fascia y 76..96 e il nome comincia a 82: sulle
	# carte a pagamento — cioè su TUTTE quelle del carretto, in una partita
	# vera — il prezzo copriva il nome del pezzo. Qui sotto c'e solo il
	# disco d'ombra del ritratto, e restano quattro pixel d'aria.
	p.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	p.offset_left = -66.0
	p.offset_right = -5.0
	p.offset_top = -66.0
	p.offset_bottom = -46.0
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := CozyUI.pill(Color(tinta, 0.9), 9)
	sb.content_margin_left = 5.0
	sb.content_margin_right = 5.0
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = testo
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", CozyUI.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


# ------------------------------------------------------------- i ritratti

## Le carte che si vedono ADESSO chiedono il loro ritratto — e in ordine
## di schermo, così il primo che arriva è il primo che si guarda.
func _chiedi_visibili() -> void:
	if _mini == null or _mini.spento() or _items_scroll == null:
		return
	if not (_panel and _panel.visible):
		return
	# ⚠️ DA PIEGATI SI CHIEDONO LO STESSO — i bolli della striscia hanno un
	# ritratto come le carte. Il `return` stava sopra il blocco dei recenti
	# (che il commento in fondo dichiara servire «anche da piegati»): chi
	# apriva il builder già piegato non vedeva vestirsi un solo bollo, mai.
	if not _aperto:
		_chiedi_recenti()
		return
	var alto := _items_scroll.size.y
	var da := _items_scroll.scroll_vertical
	for j in _item_buttons.size():
		if j >= _visibili.size():
			break
		var b := _item_buttons[j]
		if not is_instance_valid(b):
			continue
		var y := b.position.y
		# una riga di margine sopra e sotto: chi sta per entrare in vista
		# è già in coda quando ci entra
		if y + CARTA.y < da - CARTA.y or y > da + alto + CARTA.y:
			continue
		var piece := str(_items[_visibili[j]]["name"])
		if _carte_attesa.has(piece):
			_mini.chiedi(piece, _items[_visibili[j]]["builder"])
	_chiedi_recenti()


## Il pezzo in mano e i recenti: si vedono in tutti e due gli stati, e da
## piegati sono gli UNICI che si vedono.
func _chiedi_recenti() -> void:
	if _mini == null or _mini.spento():
		return
	var ordine: Array[String] = []
	if _index < _items.size():
		ordine.append(str(_items[_index]["name"]))
	for n in _recenti:
		if not ordine.has(n):
			ordine.append(n)
	for nome in ordine:
		var i := item_index(nome)
		if i >= 0 and _mini.presa(nome) == null:
			_mini.chiedi(nome, _items[i]["builder"])


func _su_miniatura(nome: String, tex: Texture2D) -> void:
	var attesa: Variant = _carte_attesa.get(nome, null)
	if attesa != null:
		for tr in (attesa as Array):
			if not is_instance_valid(tr):
				continue
			var t := tr as TextureRect
			t.texture = tex
			# LA DISSOLVENZA NON È UN VEZZO: i ritratti arrivano uno per
			# fotogramma, e venti carte che sbattono dentro una dopo
			# l'altra sono uno sfarfallio. Così sembra che si sviluppino.
			#
			# ⚠️ E SI TORNA ALL'ALPHA CHE LA CARTA AVEVA GIÀ. Prima si
			# leggeva `t.get_meta("spento")` — un meta che NESSUNO in tutto
			# il progetto scriveva, quindi il ramo della penombra era morto
			# e la dissolvenza portava a 1.0 anche i pezzi non ancora tuoi,
			# cancellando lo 0.55 che `_carta_pezzo` gli aveva messo: al
			# carretto un pezzo da comprare aveva il ritratto luminoso come
			# i tuoi. Chi crea la carta ha già detto quanto dev'essere
			# acceso — lo si rilegge, invece di chiederlo una seconda volta.
			var acceso := t.modulate.a
			t.modulate.a = 0.0
			t.create_tween().tween_property(t, "modulate:a", acceso, 0.22)
		_carte_attesa.erase(nome)
	# LA CODA SI RIALIMENTA. `_chiedi_visibili` gira all'apertura, allo
	# scroll e al cambio di vista — e all'apertura il layout della griglia
	# NON è ancora calcolato, quindi vede la finestra sbagliata e mette in
	# coda solo la prima riga. Misurato: dieci ritratti, coda a zero, e
	# metà catalogo bianco per sempre. Chiedendo di nuovo a ogni ritratto
	# che arriva, la coda si riempie da sé finché resta una carta vuota, e
	# si ferma da sé quando non ne resta nessuna (`_carte_attesa` vuoto).
	if not _carte_attesa.is_empty():
		_chiedi_visibili.call_deferred()
	_rifai_striscia_se_serve(nome)


# ------------------------------------------------------- aperto / piegato

## Tab piega l'Atelier. Non lo chiude: resta il pezzo in mano, restano i
## ritratti dei recenti, resta la riga dei tasti. Si continua a costruire
## GUARDANDO il villaggio, che è la ragione per cui si costruisce.
func _piega(aperto: bool) -> void:
	if _aperto == aperto:
		return
	_aperto = aperto
	_zone.visible = aperto
	_striscia.visible = not aperto
	_piega_btn.text = L10n.t("Tab — richiudi") if aperto else L10n.t("Tab — apri")
	if not aperto:
		_rifai_striscia()
	else:
		_taccuino_sporco = true
		_chiedi_visibili.call_deferred()
	if _sfx: _sfx.ui_select()
	var meta := -((ATE_ALTA if aperto else ATE_BASSA) + ATE_SOTTO)
	var s := get_node_or_null(^"/root/Settings")
	if s != null and bool(s.get("reduce_motion")):
		_dock.offset_top = meta
		_posa_variant_bar(aperto, false)
		return
	_posa_variant_bar(aperto, true)
	var t := _dock.create_tween()
	t.tween_property(_dock, "offset_top", meta, 0.24) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _rifai_striscia() -> void:
	if _striscia_row == null:
		return
	for c in _striscia_row.get_children():
		_striscia_row.remove_child(c)
		c.queue_free()
	# il pezzo in mano, grande; poi i recenti, piccoli
	var ordine: Array[String] = []
	if _index < _items.size():
		ordine.append(str(_items[_index]["name"]))
	for n in _recenti:
		if not ordine.has(n) and ordine.size() < 9:
			ordine.append(n)
	for k in ordine.size():
		var nome := ordine[k]
		var i := item_index(nome)
		if i < 0:
			continue
		_striscia_row.add_child(_bollo(i, k == 0))
	var l := Label.new()
	l.text = L10n.t("Tab — apri l'Atelier")
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(UI_BROWN, 0.55))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_striscia_row.add_child(l)
	# ⚠️ E CHI HA APPESO LE CARTE DEVE ANCHE ORDINARE I RITRATTI. `_bollo`
	# si mette in `_carte_attesa`, ma mettersi in attesa non è chiedere: il
	# solo che chiede è `_chiedi_recenti`, e da piegati lo chiamava soltanto
	# `_chiedi_visibili` — che gira all'APERTURA. Girando la rotella da
	# piegati (cioè facendo esattamente la cosa per cui lo stato piegato
	# esiste) i bolli nuovi restavano bianchi per sempre.
	_chiedi_recenti()


func _rifai_striscia_se_serve(nome: String) -> void:
	if _aperto or _striscia_row == null:
		return
	for c in _striscia_row.get_children():
		if c.has_meta("pezzo") and str(c.get_meta("pezzo")) == nome:
			_rifai_striscia()
			return


## Il bollo dello stato piegato: solo il ritratto e, per il pezzo in mano,
## il nome accanto.
func _bollo(i: int, grande: bool) -> Control:
	var nome := str(_items[i]["name"])
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(76, 74) if grande else Vector2(62, 62)
	b.tooltip_text = L10n.t(nome)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.set_meta("pezzo", nome)
	_veste_carta(b, false)
	if grande:
		b.set_pressed_no_signal(true)
		b.add_theme_stylebox_override("normal",
				b.get_theme_stylebox("pressed"))
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = 5.0
	tr.offset_right = -5.0
	tr.offset_top = 5.0
	tr.offset_bottom = -5.0
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: Texture2D = _mini.presa(nome) if _mini else null
	if t != null:
		tr.texture = t
	elif _mini != null:
		# ⚠️ E SE NON C'È ANCORA, IL BOLLO SI METTE IN ATTESA. Senza questa
		# riga il ritratto arrivava (la coda gira lo stesso) e non lo
		# raccoglieva nessuno: il bollo restava bianco fino a che non si
		# riapriva il pannello. È lo stesso appiglio di `_carta_pezzo`.
		if not _carte_attesa.has(nome):
			_carte_attesa[nome] = []
		(_carte_attesa[nome] as Array).append(tr)
	b.add_child(tr)
	b.pressed.connect(_select.bind(i))
	if grande:
		var l := Label.new()
		l.text = L10n.t(nome)
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", CozyUI.INK)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.add_child(b)
		h.add_child(l)
		return h
	return b


# ------------------------------------------------------------- la barra

## Il conto e la pillola della ricerca: due righe che dicono se stai
## guardando tutto o una fetta, e cosa stai cercando.
func _aggiorna_barra() -> void:
	if _ricerca_pill:
		if _ricerca_attiva or _ricerca != "":
			_ricerca_pill.text = "🔍  " + _ricerca + ("▏" if _ricerca_attiva else "")
			_ricerca_pill.modulate = Color(1, 1, 1, 1.0)
		else:
			_ricerca_pill.text = "🔍  " + L10n.t("cerca un pezzo…")
			_ricerca_pill.modulate = Color(1, 1, 1, 0.62)
	if _conta_label:
		var posabili := 0
		for i in _visibili:
			if is_unlocked(str(_items[i]["name"])):
				posabili += 1
		_conta_label.text = L10n.tf("%d di %d", [posabili, _visibili.size()]) \
				if posabili != _visibili.size() \
				else L10n.tf("%d pezzi", [_visibili.size()])


func _sync_ui_selection() -> void:
	for vista in _cat_btn:
		var b := _cat_btn[vista] as Button
		if is_instance_valid(b):
			b.set_pressed_no_signal(int(vista) == _cat and _ricerca == "")
	# le carte stanno in parallelo a `_visibili`: se le due liste si
	# sfasassero, la carta accesa sarebbe quella sbagliata
	for j in _item_buttons.size():
		if j < _visibili.size():
			_item_buttons[j].set_pressed_no_signal(_visibili[j] == _index)
	if not _aperto:
		_rifai_striscia()


## La ricerca si accende con «/» (o cliccando la pillola) e si spegne con
## Esc. Mentre è accesa i tasti del builder (R, V, F, X…) diventano
## lettere: è per questo che serve una modalità e non un campo sempre
## attivo — in un gioco dove si costruisce con le lettere, un cursore che
## ruba i tasti è una trappola.
func _ricerca_accendi() -> void:
	if not _aperto:
		_piega(true)
	_ricerca_attiva = true
	_aggiorna_barra()
	if _sfx: _sfx.ui_select()


func _ricerca_spegni(pulisci: bool) -> void:
	_ricerca_attiva = false
	if pulisci and _ricerca != "":
		_ricerca = ""
		_rebuild_item_row()
		_sync_ui_selection()
	else:
		_aggiorna_barra()


func _ricerca_tasto(event: InputEventKey) -> bool:
	if event.keycode == KEY_ESCAPE:
		_ricerca_spegni(true)
		return true
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_ricerca_spegni(false)
		# Invio prende il primo pezzo posabile fra i risultati: cercare e
		# poi doverlo anche cliccare sarebbe metà lavoro
		for i in _visibili:
			if is_unlocked(str(_items[i]["name"])):
				_select(i)
				break
		return true
	if event.keycode == KEY_BACKSPACE:
		if _ricerca != "":
			_ricerca = _ricerca.substr(0, _ricerca.length() - 1)
			_rebuild_item_row()
			_sync_ui_selection()
		return true
	var ch := char(event.unicode)
	if event.unicode >= 32 and ch != "":
		_ricerca += ch
		_rebuild_item_row()
		_sync_ui_selection()
		return true
	return false


# ============================================================ economia colori
# Le varianti di colore comprate al mercante: qui si tinge il fantasma e il
# pezzo piazzato, si sceglie il colore con una barra di campioni, e la tinta
# per-pezzo viaggia nel salvataggio (chiave "variants", additiva: i vecchi
# salvataggi e l'altra progressione non ne sanno nulla).

func _economy() -> Node:
	if _eco == null or not is_instance_valid(_eco):
		_eco = get_tree().get_first_node_in_group("economy")
	return _eco


## Il pezzo da negozio che porta con sé questo compagno di corredo ("" se il
## pezzo non fa parte di nessun corredo). La tabella è UNA sola —
## `Economy.CORREDO` — e qui si LEGGE dalla sua fonte, non si ricopia: un
## corredo nuovo (o un compagno in più) funziona da solo, senza toccare
## niente qui dentro. Si legge dalla mappa delle costanti dello script
## perché `_eco` è un `Node` non tipizzato (l'autoload dell'economia si
## risolve a runtime) e la costante non è raggiungibile per nome.
var _compagni_corredo := {}
var _corredo_letto := false


func _padrone_corredo(piece: String) -> String:
	if not _corredo_letto:
		var eco := _economy()
		if eco == null:
			return ""      # economia non ancora in scena: si riproverà
		var sc := eco.get_script() as GDScript
		if sc == null:
			return ""
		var tabella: Variant = sc.get_script_constant_map().get("CORREDO")
		if tabella is Dictionary:
			for capo in (tabella as Dictionary):
				for compagno in (tabella as Dictionary)[capo]:
					_compagni_corredo[str(compagno)] = str(capo)
		_corredo_letto = true
	return str(_compagni_corredo.get(piece, ""))


## L'offerta del mercante per un pezzo, o {} se non è merce da negozio.
## Serve al catalogo per distinguere «lo porterà il Gufo» da «si compra».
func _shop_offer(piece: String) -> Dictionary:
	var eco := _economy()
	if eco == null or not eco.has_method("piece_offer"):
		return {}
	return eco.piece_offer(piece)


## La didascalia della vetrina: dove si compra, quanto costa, cos'è — e se
## oggi te lo puoi permettere (il borsellino lo sa già).
func _shop_tooltip(offer: Dictionary) -> String:
	var cur := str(offer.get("cur", "nut"))
	var soldi := L10n.t("noccioline") if cur == "nut" else L10n.t("stelline")
	var cost := int(offer.get("cost", 0))
	var txt := L10n.tf("Dal carretto del mercante · %d %s", [cost, soldi])
	var desc := str(offer.get("desc", ""))
	if desc != "":
		txt += "\n%s" % L10n.t(desc)
	var eco := _economy()
	if eco and eco.has_method("can_afford"):
		txt += "\n%s" % (L10n.t("Puoi permettertelo!") if eco.can_afford(cost, cur) \
				else L10n.t("Mettine da parte ancora un po'."))
	return txt


func _hook_economy() -> void:
	var eco := _economy()
	if eco and eco.has_signal("shop_changed") and not eco.shop_changed.is_connected(_on_shop_changed):
		eco.shop_changed.connect(_on_shop_changed)
	# il borsellino cambia -> le didascalie della vetrina si riallineano:
	# «puoi permettertelo» non deve mai restare a mentire
	if eco:
		for sig in ["nuts_changed", "stars_changed"]:
			if eco.has_signal(sig) and not eco.is_connected(sig, _on_wallet_changed):
				eco.connect(sig, _on_wallet_changed)
	# recupera lo stato caricato dopo _load_village: i pezzi già comprati
	# devono comparire nel catalogo (la riga era stata costruita con eco vuota)
	_on_shop_changed()


# il gruzzolo è cambiato: solo le didascalie, niente ricostruzioni
func _on_wallet_changed(_total: int) -> void:
	for btn in _item_buttons:
		if is_instance_valid(btn) and btn.has_meta("shop_offer"):
			btn.tooltip_text = _shop_tooltip(btn.get_meta("shop_offer"))
	# ⚠️ E IL TACCUINO PURE: da quando c'è la carta dei risparmi, il
	# borsellino ha DUE lettori, e questo ne rinfrescava uno solo. Le
	# noccioline salgono anche senza che il giocatore tocchi niente (un
	# vicino compra dalla tua Bancarella, arriva il premio di una
	# Commissione): l'Atelier restava aperto a dire «ancora 45» mentre in
	# alto il contatore diceva che ce n'erano abbastanza.
	_taccuino_sporco = true


# comprato qualcosa: rinfresca la fila dei pezzi (nuovi sblocchi) e i colori
func _on_shop_changed() -> void:
	if not _item_buttons.is_empty():
		_rifai_sinistra()
		_rebuild_item_row()
		_sync_ui_selection()
	_taccuino_sporco = true
	_update_variant_bar()


func _apply_ghost_variant() -> void:
	if _ghost == null or _variant == "":
		return
	var eco := _economy()
	if eco and eco.piece_takes_variant(str(_items[_index]["name"])):
		eco.apply_variant(_ghost, _variant)


# la variante valida per il pezzo corrente ("" se non è tingibile)
func _variant_for_current() -> String:
	var eco := _economy()
	if eco and eco.piece_takes_variant(str(_items[_index]["name"])):
		return _variant
	return ""


# ------------------------------------------------------- barra dei colori
func _build_variant_bar() -> void:
	if _ui == null:
		return
	# ⚠️ LA BARRA STA SOPRA IL PANNELLO, E LO SEGUE. Questi due offset erano
	# rimasti a -214/-180, com'erano quando il builder era alto 272: il dock
	# dell'Atelier occupa -422..-16, quindi la fascia dei colori cadeva
	# DENTRO la griglia e copriva tre carte (misurato: la pillola a y 866
	# dentro un pannello che va da 658 a 1064). Adesso la posizione si
	# calcola dalle stesse costanti del dock — una fonte sola — e cambia
	# quando si piega.
	_variant_dock = CenterContainer.new()
	_variant_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_variant_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_variant_dock)
	_posa_variant_bar(_aperto, false)
	var dock := _variant_dock
	_variant_bar = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.95, 0.88, 0.94)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(0.62, 0.46, 0.34, 0.5)
	sb.set_border_width_all(2)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	_variant_bar.add_theme_stylebox_override("panel", sb)
	_variant_bar.visible = false
	dock.add_child(_variant_bar)
	_variant_row = HBoxContainer.new()
	_variant_row.add_theme_constant_override("separation", 6)
	_variant_bar.add_child(_variant_row)


func _update_variant_bar() -> void:
	if _variant_bar == null or _variant_row == null:
		return
	var eco := _economy()
	var piece: String = str(_items[_index]["name"]) if _index < _items.size() else ""
	var takes: bool = eco != null and eco.piece_takes_variant(piece)
	var owned: Array = eco.owned_variants() if eco else []
	if not (_active and takes and not owned.is_empty()):
		_variant_bar.visible = false
		return
	# se il colore scelto non è (più) posseduto, torna all'originale
	if _variant != "" and not owned.has(_variant):
		_variant = ""
	for c in _variant_row.get_children():
		c.queue_free()
	_variant_row.add_child(_variant_swatch("", Color("efe0c6"), L10n.t("Originale")))
	for vid in owned:
		var def: Dictionary = eco.variant_def(vid)
		_variant_row.add_child(_variant_swatch(str(vid), def.get("tint", Color.WHITE), L10n.t(str(def.get("label", vid)))))
	_variant_bar.visible = true


## Dove sta la barra dei colori: appoggiata SOPRA il pannello, con la sua
## aria. Il numero non è suo — è quello del dock dell'Atelier, letto dalle
## stesse costanti: due geometrie che si inseguono a mano divergono al
## primo che ritocca l'altezza del pannello.
func _posa_variant_bar(aperto: bool, anima: bool) -> void:
	if _variant_dock == null:
		return
	var sotto := -((ATE_ALTA if aperto else ATE_BASSA) + ATE_SOTTO) - VAR_ARIA
	if not anima:
		_variant_dock.offset_top = sotto - VAR_ALTA
		_variant_dock.offset_bottom = sotto
		return
	var t := _variant_dock.create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_variant_dock, "offset_top", sotto - VAR_ALTA, 0.24)
	t.parallel().tween_property(_variant_dock, "offset_bottom", sotto, 0.24)


func _variant_swatch(vid: String, color: Color, label: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(30, 30)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = label
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(15)
	var on := _variant == vid
	sb.border_color = Color("6a4a3a") if on else Color(0.62, 0.46, 0.34, 0.35)
	sb.set_border_width_all(3 if on else 1)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.pressed.connect(_pick_variant.bind(vid))
	return b


func _pick_variant(vid: String) -> void:
	_variant = vid
	if _sfx: _sfx.ui_select()
	_refresh_ghost()


# ------------------------------------------------------- persistenza colori
func _pkey(lvl, layer, key: Vector2i) -> String:
	return "%d:%s:%d:%d" % [int(lvl), str(layer), key.x, key.y]


func _collect_variants() -> Dictionary:
	var out := {}
	for lvl in 2:
		for layer in [0, 1, 2, 3, "edge"]:
			var dict := _dicts(lvl)[layer] as Dictionary
			for key in dict:
				var node := dict[key] as Node3D
				var v := str(node.get_meta("variant", ""))
				if v != "":
					out[_pkey(lvl, layer, key)] = v
	return out
