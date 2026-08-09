extends Node

## RISPONDERE — la cassetta che finalmente si può anche riempire.
##
## IL BUCO CHE CHIUDE. La posta era il canale più intimo del gioco ed era a
## SENSO UNICO: i vicini scrivevano, il Gufo scriveva, chi partiva lasciava
## la sua lettera sul letto — e tu non potevi rispondere mai. Peggio: il
## Filo Rosso, il sistema più profondo del progetto, teneva il conto di
## ogni momento vissuto insieme e non c'era UNA schermata dove guardarlo.
## Un ledger che nessuno legge è un ledger che non esiste.
##
## Rispondere è la stessa porta per tutte e due le cose, ed è per questo
## che funziona: per scegliere cosa dire devi SFOGLIARE la vostra storia.
## La pagina del filo non è un menù di statistiche — è il foglio su cui
## stai scrivendo.
##
## COME SI SCRIVE. Non si batte un testo: si sceglie.
##   1. A CHI — i vicini con cui hai un filo, e in fondo, staccati,
##      quelli che sono partiti per il Grande Prato.
##   2. QUALE MOMENTO — la vostra storia, riga per riga, col giorno.
##      Sceglierne uno vuol dire «mi ricordo di questo».
##   3. DUE PAROLE di Chibiese. Le prime due te le suggerisce il momento
##      stesso (Legami.TIPI ne porta due per tipo); puoi cambiarle.
## Non serve saper scrivere per dire una cosa vera.
##
## E LE RISPOSTE ARRIVANO. Se il destinatario c'è, la lettera gli arriva e
## lui risponde: il momento si riaccende sul filo (tipo "risposta"),
## l'amicizia sale, e il mattino dopo trovi la sua nella cassetta.
## Se è partito per il Grande Prato, no: nessuno risponde. Ma la lettera
## non si perde — la sera il suo FIORE-RICORDO si accende, una volta, e
## il Grande Albero se lo incide fra gli anelli. È tutto quello che il
## gioco può onestamente prometterti, ed è già molto.

const CHIBIESE := preload("res://audio/Chibiese.gd")
const LEGAMI := preload("res://scenes/world/Legami.gd")

## Le parole che si possono mettere in fondo a una lettera. Non tutto il
## vocabolario: quelle che hanno senso DETTE A QUALCUNO. (Il Chibiese ne
## conosce quasi cento, ma «pioggia» o «montagna» in calce a una lettera
## non vogliono dire niente.)
const PAROLE := ["grazie", "amico", "felice", "insieme", "ricordo",
		"nostalgia", "cuore", "abbraccio", "bello", "coraggio",
		"scusa", "aspetta", "ciao", "addio", "casa"]

## Quante parole si scelgono. Due: una sola è un'etichetta, tre è un tema.
const QUANTE_PAROLE := 2

var _legami: Node
var _visitors: Node
var _mail: Node
var _daynight: Node
var _sfx
var _player: Node3D

var _layer: CanvasLayer
var _pannello: PanelContainer
var _titolo: Label
var _corpo: VBoxContainer
var _pie: Label
var _aperto := false

# la lettera in composizione
var _passo := 0            # 0 a chi · 1 quale momento · 2 due parole
var _a_chi := ""
var _partito := false
var _momento := {}
var _parole: Array = []
var _sel := 0
# le lettere spedite: "nome|giorno" -> true (una risposta al giorno per
# ciascuno: rispondere non è una macchina per l'amicizia)
var _spedite := {}


func _ready() -> void:
	add_to_group("rispondere")
	add_to_group("persistable")
	_sfx = get_node_or_null(^"/root/Sfx")
	_costruisci_ui()
	(func() -> void:
		_legami = get_tree().get_first_node_in_group("legami")
		_visitors = get_node_or_null("../Visitors")
		_mail = get_node_or_null("../Mail")
		_daynight = get_node_or_null("../DayNight")
		_player = get_node_or_null("../Player")).call_deferred()


## IL FILO ROSSO, CHIESTO PIGRAMENTE. `Legami` NON sta nella scena: lo crea
## `CozyWorld._ready()` dopo tre `await get_tree().process_frame`, e un
## `call_deferred` del nostro `_ready` si svuota a fine frame 0 — quindi lo
## trova `null` PER SEMPRE. Il consumatore e' protetto da un `if _legami:`
## e il fallimento e' MUTO: nessun errore, suite verde, e il momento non si
## annoda mai. E' lo stesso idioma gia' scritto in
## `PostoDiSempre._filo_rosso()`, col suo commento che racconta la stessa
## lezione: qui si riprova finche' non c'e'.
func _i_legami() -> Node:
	if _legami == null or not is_instance_valid(_legami):
		_legami = get_tree().get_first_node_in_group("legami")
	return _legami


func _giorno() -> int:
	return int(_daynight.get("day")) if _daynight else 1


# ============================================================ la logica pura
# Tutto ciò che decide COSA si può scrivere sta qui: statico, senza albero
# della scena, provato headless.

## I destinatari possibili, dal filo. Ogni voce:
##   {nome, partito: bool, momenti: int, giorno: int}
## Ci vuole almeno UN momento: non si scrive a uno sconosciuto, e la
## pagina del filo sarebbe vuota. Chi è partito viene in fondo, sempre:
## non lo si incontra per caso mentre si scorre la lista dei vivi.
static func destinatari(fili: Dictionary) -> Array:
	var vivi: Array = []
	var andati: Array = []
	for nome in fili:
		var f: Dictionary = fili[nome]
		var momenti: Array = f.get("momenti", [])
		if momenti.is_empty():
			continue
		var voce := {"nome": str(nome), "partito": bool(f.get("partito", false)),
				"momenti": momenti.size(),
				"giorno": int(f.get("giorno_arrivo", 0))}
		if voce["partito"]:
			andati.append(voce)
		else:
			vivi.append(voce)
	vivi.sort_custom(func(a, b): return int(a["giorno"]) < int(b["giorno"]))
	andati.sort_custom(func(a, b): return int(a["giorno"]) < int(b["giorno"]))
	vivi.append_array(andati)
	return vivi


## La pagina del filo: i momenti in ordine di come sono stati vissuti,
## col loro racconto. È QUESTA la schermata che non c'era.
## Ogni voce: {t, d, racconto, parole}
static func pagina_del_filo(momenti: Array) -> Array:
	var out: Array = []
	for m in momenti:
		var tipo := str(m.get("t", ""))
		var riga: Array = LEGAMI.TIPI.get(tipo, ["un momento insieme", ["amico", "felice"]])
		out.append({"t": tipo, "d": int(m.get("d", 0)),
				"racconto": str(riga[0]), "parole": (riga[1] as Array).duplicate()})
	return out


## Le due parole che il momento SUGGERISCE. Sono quelle del suo tipo, ma
## solo se sono scrivibili in una lettera: se il tipo ne porta una che
## nella busta non ha senso, si ripiega su «grazie».
static func parole_suggerite(momento: Dictionary) -> Array:
	var out: Array = []
	for p in (momento.get("parole", []) as Array):
		if str(p) in PAROLE and not str(p) in out:
			out.append(str(p))
	while out.size() < QUANTE_PAROLE:
		for p in ["grazie", "amico", "felice"]:
			if not p in out:
				out.append(p)
				break
	return out.slice(0, QUANTE_PAROLE)


## «DI» PIÙ L'ARTICOLO. I racconti del filo cominciano col loro articolo
## («la partita a nascondino», «il primo benvenuto»), e in italiano «di la
## partita» non esiste: si dice «della». Le preposizioni articolate sono
## la stessa cura che il gioco mette nei plurali delle commissioni — senza,
## la lettera più intima del gioco sembra scritta da una macchina.
## E VALE SOLO IN ITALIANO. Il commento di prima diceva che su una lingua
## senza questi articoli «non trova nulla da fondere e restituisce la frase
## intatta»: era falso, perche' il ripiego finale anteponeva comunque
## «di ». In inglese usciva «I remember di the game of hide-and-seek»,
## visibile nell'anteprima della lettera a ogni partita non italiana. La
## fusione e' una regola della LINGUA, non del testo: fuori dall'italiano
## non si tocca niente.
const ARTICOLI := {"il ": "del ", "lo ": "dello ", "la ": "della ",
		"i ": "dei ", "gli ": "degli ", "le ": "delle ",
		"l'": "dell'", "un ": "di un ", "una ": "di una ",
		"uno ": "di uno ", "un'": "di un'"}


static func con_di(racconto: String) -> String:
	if L10n.lingua_corrente() != L10n.SORGENTE:
		return racconto
	for art in ARTICOLI:
		if racconto.begins_with(str(art)):
			return str(ARTICOLI[art]) + racconto.substr(str(art).length())
	return "di " + racconto


## Il testo della lettera che il destinatario riceverà: il momento
## raccontato, e sotto le due parole in Chibiese con la loro traduzione.
## PURA: la stessa lettera, dagli stessi ingredienti, per sempre.
static func testo_lettera(momento: Dictionary, parole: Array, da := "Mochi") -> String:
	var sillabe: Array = []
	for p in parole:
		var w: Array = CHIBIESE.VOCAB.get(str(p), [])
		sillabe.append("-".join(PackedStringArray(w)) if not w.is_empty() else str(p))
	var racconto := L10n.t(str(momento.get("racconto", "noi due")))
	return "%s\n\n«%s»\n(%s)\n— %s" % [
			L10n.tf("Mi ricordo %s.", [con_di(racconto)]),
			" ".join(PackedStringArray(sillabe)),
			", ".join(PackedStringArray(parole)), da]


## Si può ancora scrivere a `nome` oggi? Una al giorno per ciascuno: la
## posta del cuore non è un rubinetto da aprire venti volte di fila.
func puo_scrivere(nome: String) -> bool:
	return not _spedite.has("%s|%d" % [nome, _giorno()])


# ============================================================ la porta

## La chiama la cassetta quando non c'è posta da leggere.
func apri() -> void:
	if _aperto or _i_legami() == null:
		return
	var lista := destinatari(_legami.get("_fili"))
	if lista.is_empty():
		# `Mail.mostra_toast` NON ESISTE (mai esistito: le uniche due
		# occorrenze in tutto il repo erano queste righe). Dietro un
		# `has_method` il buco non dava errore — la cassetta si apriva, non
		# diceva niente e si richiudeva, e sembrava un tasto rotto.
		_toast(L10n.t("Non hai ancora una storia da raccontare a nessuno."))
		return
	_aperto = true
	_passo = 0
	_sel = 0
	_a_chi = ""
	_momento = {}
	_parole = []
	if _player:
		_player.set_physics_process(false)
	_layer.visible = true
	_riempi()
	CozyUI.appear(_pannello)
	if _sfx:
		_sfx.build_open()


func chiudi() -> void:
	if not _aperto:
		return
	_aperto = false
	if _player:
		_player.set_physics_process(true)
	CozyUI.dismiss(_pannello, func(): _layer.visible = false)
	if _sfx:
		_sfx.play("close", -12.0)


func e_aperto() -> bool:
	return _aperto


func _unhandled_input(event: InputEvent) -> void:
	if not _aperto:
		return
	if event.is_action_pressed("ui_cancel"):
		_indietro()
		get_viewport().set_input_as_handled()
		return
	var voci := _voci_del_passo()
	if event.is_action_pressed("ui_down"):
		_sel = (_sel + 1) % maxi(voci.size(), 1)
		_riempi()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_sel = (_sel - 1 + voci.size()) % maxi(voci.size(), 1)
		_riempi()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_avanti()
		get_viewport().set_input_as_handled()


func _indietro() -> void:
	if _passo == 0:
		chiudi()
		return
	_passo -= 1
	_sel = 0
	if _passo == 0:
		_momento = {}
	_parole = []
	_riempi()
	if _sfx:
		_sfx.play("tick", -16.0, 0.8)


func _avanti() -> void:
	var voci := _voci_del_passo()
	if voci.is_empty():
		return
	var v: Dictionary = voci[_sel % voci.size()]
	match _passo:
		0:
			_a_chi = str(v["nome"])
			_partito = bool(v["partito"])
			_passo = 1
			_sel = 0
		1:
			_momento = v
			_parole = parole_suggerite(v)
			_passo = 2
			_sel = 0
		2:
			# al terzo passo la lista è la tavolozza: si SCAMBIA la parola
			# selezionata nella coppia (la prima, poi la seconda)
			var quale := _parole.size() - QUANTE_PAROLE
			if _parole.size() < QUANTE_PAROLE:
				_parole.append(str(v["nome"]))
			else:
				_parole[0] = _parole[1]
				_parole[1] = str(v["nome"])
			if _sfx:
				_sfx.play("tick", -14.0, 1.2)
			_riempi()
			return
	if _sfx:
		_sfx.ui_select()
	_riempi()


# ============================================================ la spedizione

func spedisci() -> void:
	if _a_chi == "" or _momento.is_empty() or _parole.size() < QUANTE_PAROLE:
		return
	if not puo_scrivere(_a_chi):
		return
	_spedite["%s|%d" % [_a_chi, _giorno()]] = true
	var testo := testo_lettera(_momento, _parole)
	if _partito:
		_al_grande_prato(testo)
	else:
		_al_vicino(testo)
	chiudi()
	var bs := get_tree().get_first_node_in_group("build_system")
	if bs and bs.has_method("request_save"):
		bs.request_save()


## Al vicino che c'è: la lettera arriva, e lui RISPONDE. Il momento si
## riaccende sul filo, l'amicizia sale, e domattina trovi la sua nella
## cassetta. È il senso opposto del canale, quello che mancava.
func _al_vicino(_testo: String) -> void:
	if _legami:
		_i_legami().call("momento", _a_chi, "risposta", str(_momento.get("t", "")))
	if _visitors and _visitors.has_method("grazie_per_la_lettera"):
		_visitors.call("grazie_per_la_lettera", _a_chi)
	if _mail and _mail.has_method("queue_letter"):
		# il Chibiese resta Chibiese in ogni lingua (è la LORO lingua, non
		# la nostra); il racconto del momento invece viene da Legami.TIPI
		# ed è una chiave, quindi si rimanda anche lui
		var grazie := "-".join(PackedStringArray(CHIBIESE.VOCAB.get("grazie", ["ta", "ki"])))
		_mail.call("queue_letter", {
			"from_key": _a_chi,
			"text_key": "Ho letto e riletto la tua lettera.\nMe lo ricordo anch'io, %s.\n\n«%s»\n— %s",
			"args": [{"k": str(_momento.get("racconto", "quel giorno"))}, grazie, _a_chi],
			"gift": false,
		})
	_toast(L10n.tf("La lettera è nella cassetta: la troverà %s.", [_a_chi]))


## A chi è partito per il Grande Prato: NESSUNO risponde, e il gioco non
## finge il contrario. Ma la lettera non si perde — la sera il suo
## fiore-ricordo si accende, una volta sola, e il Grande Albero se lo
## incide fra gli anelli. È il tono giusto: non una consolazione, un
## riconoscimento.
func _al_grande_prato(_testo: String) -> void:
	var congedo := get_tree().get_first_node_in_group("congedo")
	if congedo and congedo.has_method("accendi_fiore"):
		congedo.call("accendi_fiore", _a_chi)
	var albero := get_tree().get_first_node_in_group("grande_albero")
	if albero and albero.has_method("engrave"):
		albero.call("engrave", "✉", "una lettera per %s, al Grande Prato", [_a_chi])
	_toast(L10n.tf("La lettera è partita per il Grande Prato. Stasera il fiore di %s sarà acceso.",
			[_a_chi]))


## IL CARTELLINO. C'era un ramo su `get_first_node_in_group("toast")` +
## `show_toast` — un gruppo che NESSUN nodo del progetto popola e un metodo
## che non esiste in tutto il repo — e sotto, come ripiego, un `print()`.
## Cioè: il giocatore imbucava la lettera più intima del gioco e a schermo
## non succedeva niente, mentre il messaggio finiva nella console.
## La strada vera è quella che usano già Salone e Concerto.
func _toast(testo: String) -> void:
	if _visitors and _visitors.has_method("_show_toast"):
		_visitors.call("_show_toast", testo)


# ============================================================ la schermata

func _voci_del_passo() -> Array:
	match _passo:
		0:
			return destinatari(_i_legami().get("_fili")) if _i_legami() else []
		1:
			return pagina_del_filo(_i_legami().call("momenti_di", _a_chi)) if _i_legami() else []
		2:
			var out: Array = []
			for p in PAROLE:
				out.append({"nome": p})
			return out
	return []


func _riempi() -> void:
	for c in _corpo.get_children():
		c.queue_free()
	var voci := _voci_del_passo()
	match _passo:
		0:
			_titolo.text = L10n.t("A chi vuoi rispondere?")
			_pie.text = L10n.t("↑↓ scegli   ·   E conferma   ·   ESC chiude")
			for i in voci.size():
				var v: Dictionary = voci[i]
				var riga := "%s%s   ·   %d momenti insieme" % [
						"✿ " if v["partito"] else "",
						str(v["nome"]), int(v["momenti"])]
				# la spaziatura sta QUI, non dentro la frase: le traduzioni
				# non portano spazi ai bordi (un test lo verifica)
				if v["partito"]:
					riga += "   " + L10n.t("(al Grande Prato)")
				elif not puo_scrivere(str(v["nome"])):
					riga += "   " + L10n.t("(gli hai già scritto oggi)")
				_corpo.add_child(_riga(riga, i == _sel % maxi(voci.size(), 1),
						v["partito"]))
		1:
			_titolo.text = L10n.tf("Di cosa ti ricordi, con %s?", [_a_chi])
			_pie.text = L10n.t("è la vostra storia   ·   E sceglie   ·   ESC torna")
			for i in voci.size():
				var m: Dictionary = voci[i]
				_corpo.add_child(_riga("giorno %d   ·   %s"
						% [int(m["d"]), L10n.t(str(m["racconto"]))],
						i == _sel % maxi(voci.size(), 1), false))
		2:
			_titolo.text = L10n.t("E due parole.")
			_pie.text = L10n.t("E cambia le parole   ·   INVIO spedisce   ·   ESC torna")
			var anteprima := Label.new()
			anteprima.text = testo_lettera(_momento, _parole)
			anteprima.add_theme_font_size_override("font_size", 17)
			anteprima.add_theme_color_override("font_color", CozyUI.INK)
			anteprima.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_corpo.add_child(anteprima)
			var tav := HFlowContainer.new()
			tav.add_theme_constant_override("h_separation", 6)
			for i in voci.size():
				var p := str(voci[i]["nome"])
				var l := CozyUI.body_label(L10n.t(p), 15,
						CozyUI.INK if i == _sel % voci.size() else CozyUI.INK_SOFT)
				tav.add_child(l)
			_corpo.add_child(tav)
			var inv := CozyUI.cozy_button(L10n.t("Imbuca la lettera"), CozyUI.PINK, 18)
			inv.pressed.connect(spedisci)
			_corpo.add_child(inv)
	_pannello.reset_size()


func _riga(testo: String, scelta: bool, partito: bool) -> Control:
	var p := PanelContainer.new()
	if scelta:
		p.add_theme_stylebox_override("panel",
				CozyUI.pill(CozyUI.MINT if not partito else CozyUI.SKY, 12.0))
	var l := CozyUI.body_label(testo, 17, CozyUI.INK if scelta else CozyUI.INK_SOFT)
	p.add_child(l)
	return p


func _costruisci_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 12
	_layer.visible = false
	add_child(_layer)
	var centro := CozyUI.center_root()
	_layer.add_child(centro)
	_pannello = PanelContainer.new()
	_pannello.add_theme_stylebox_override("panel", CozyUI.paper_panel())
	centro.add_child(_pannello)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_pannello.add_child(col)
	_titolo = CozyUI.title_label("", 28)
	col.add_child(_titolo)
	_corpo = VBoxContainer.new()
	_corpo.add_theme_constant_override("separation", 4)
	col.add_child(_corpo)
	_pie = CozyUI.hint_label("", 13)
	col.add_child(_pie)


# ============================================================ persistenza

func save_extra() -> Dictionary:
	return {"lettere_spedite": _spedite.keys()} if not _spedite.is_empty() else {}


func load_extra(data: Dictionary) -> void:
	_spedite.clear()
	for k in data.get("lettere_spedite", []):
		_spedite[str(k)] = true
