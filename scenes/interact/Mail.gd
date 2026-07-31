extends Node

## La posta del mattino. Ogni volta che sorge un nuovo giorno — che tu
## l'abbia dormito nel letto o vissuto sotto le stelle — un piccolo amico
## del bosco lascia una letterina nella cassetta: la bandierina si alza
## con uno scampanellio d'ali, e avvicinandosi lo sportello si apre da
## solo mostrando la busta col sigillo a cuoricino. E per leggerla, e
## qualche volta dentro c'è anche un regalino.
##
## E da quando il Filo Rosso annoda i momenti, metà delle lettere non
## escono più dal cassetto delle otto frasi fisse: le scrivono i VICINI,
## ripensando a un momento vero vissuto con te — la posta racconta la
## TUA storia, non una qualsiasi.

const MORNING_T := 0.27
const UI_BROWN := Color("6a4a3a")

## La larghezza del foglio: la dicono le ancore della card E il testo che
## ci va a capo dentro. Un numero solo, o le due cose divergono.
const CARD_LARGHEZZA := 380.0

const LETTERS := [
	{"from_key": "Passerotto", "text_key": "Ho visto il tuo giardino dall'alto:\nle aiuole sono le più belle del prato!", "gift": true},
	{"from_key": "Riccio", "text_key": "Stanotte ho dormito sotto la tua panchina.\nGrazie per l'erba alta: era morbidissima.", "gift": false},
	{"from_key": "Volpe del bosco", "text_key": "Il sentiero profuma di funghi nuovi.\nSe vedi una coda rossa tra le felci, ti sto salutando.", "gift": false},
	{"from_key": "Gufo", "text_key": "Le tue lucciole tengono compagnia alle mie veglie.\nStanotte ho contato dodici stelle cadenti su casa tua.", "gift": false},
	{"from_key": "Scoiattolo", "text_key": "Ho nascosto una ghianda vicino al falò...\nanzi no: tienila tu, è il mio regalo!", "gift": true},
	{"from_key": "Farfalla", "text_key": "I tuoi fiori sono i più dolci che conosca.\nDomani torno con le mie sorelle: prepara il tè!", "gift": false},
	# …e la lettera che INSEGNA il Fiato Sospeso, senza un tutorial e senza
	# una freccia lampeggiante: te lo racconta chi ha paura di te.
	{"from_key": "Farfalla", "text_key": "Oggi ti ho vista arrivare di corsa e mi sono spostata.\nNon te la prendere: sei molto grande.\nSe però ti abbassi nell'erba e stai ferma (tieni premuto C),\ndopo un po' mi dimentico di te. E allora vengo a vedere chi sei.", "gift": false},
	{"from_key": "Talpa", "text_key": "Scavando sono sbucata nel tuo giardino, scusa il buchetto.\nTi lascio un sassolino brillante per farmi perdonare.", "gift": true},
	{"from_key": "Merlo", "text_key": "La tua musichetta si sente fino al ciliegio.\nAscolta bene domattina: la fischietto anch'io.", "gift": false},
]

## Le lettere nate dai momenti: un template per OGNI tipo del Filo Rosso
## (Legami.TIPI — un test tiene le due tabelle allineate). Il %d è il
## giorno del momento: la data rende il ricordo vero.
const MOMENTI_TESTO := {
	"benvenuto": "Ripenso spesso al giorno %d:\nil tuo benvenuto sulla soglia.\nNessuno mi aveva mai aspettato così.",
	"trasloco": "La valigia è ancora sotto il letto.\nOgni tanto la guardo e sorrido:\ndal giorno %d questa è casa mia.",
	"primo_saluto": "Ti ricordi il giorno %d?\nLa prima zampina alzata, da lontano.\nIo l'ho contata come un inizio.",
	"piatto": "Ho ancora in mente il profumo\ndi quel piatto del giorno %d.\nUn giorno cucino io, promesso.",
	"regalo": "Il regalo del giorno %d\nce l'ho sulla mensola, al posto d'onore.\nGrazie di avermi pensato.",
	"festa": "La festa del giorno %d!\nHo ritrovato un coriandolo nel pelo\ne mi è tornata tutta l'allegria.",
	"onsen": "L'acqua calda del giorno %d,\nfianco a fianco, senza dire niente.\nEra tutto quello che serviva.",
	"desiderio": "Non ho dimenticato il giorno %d,\nquando hai esaudito il mio desiderio.\nIl filo tra noi da lì si è colorato.",
	"promessa": "Il giorno %d ti ho dato appuntamento\ne tu sei venuto davvero.\nDi tutte le cose che abbiamo visto insieme,\nquella me la ricordo dall'inizio.",
	"nascondino": "Il giorno %d, dietro quel tronco,\nmi scappava da ridere e tu lo sapevi.\nGiochiamo ancora, promesso?",
	"posto": "C'e' un posto dove finivo sempre\nverso quell'ora, senza averlo deciso.\nIl giorno %d ci sei arrivato anche tu,\ne non ci siamo detti niente.",
	"oro": "Quel desiderio del giorno %d,\nl'ultimo, vissuto insieme:\nlo tengo tra i momenti d'oro.",
	"addio": "Del giorno %d non parlo volentieri,\nma il filo non si è spezzato:\nha solo cambiato forma.",
	"partenza": "Dal Grande Prato si vede il villaggio.\nIl giorno %d avevo la valigia piccola\ne il cuore pieno. Grazie di tutto.",
	# la lettera che hai scritto TU: quando il momento riaffiora, lui si
	# ricorda della busta, non del giorno che ci hai messo dentro
	"risposta": "La tua lettera del giorno %d\nla tengo piegata nella tasca buona.\nLa rileggo quando fuori piove.",
	"musica": "La sera del giorno %d eravamo tutti seduti al buio,\ne nessuno diceva niente.\nNon me ne intendo di musica.\nMi è rimasta lo stesso.",
	# LE NUOVE LEVE: la nascita la ricorda il genitore, il nome e la
	# prima parola le ricorda chi è nato — da grande, guardandosi indietro
	"nascita": "Il giorno %d è la mattina più lunga\nche io ricordi, e la più corta.\nSei venuto a vederlo che era ancora\npiù piccolo delle mie due zampe.",
	"battesimo": "Il nome che porto me l'hai dato tu,\nil giorno %d, quando ero grande così.\nNon me lo ricordo. Me l'hanno raccontato\nabbastanza volte da ricordarmelo lo stesso.",
	"prima_parola": "Dicono che la prima parola\nl'ho detta il giorno %d, tutta storta,\ne che tu eri lì e hai riso.\nPoi l'ho imparata bene, ma quella era mia.",
	"coraggio": "Di quel posto avevo paura, e non lo dicevo.\nIl giorno %d ci siamo andati insieme\ne non è successo niente — proprio niente.\nAdesso ci passo anche da solo, e non ci penso.",
}


## Compone una lettera dal filo di un residente: PURA e deterministica
## dato `pick` (il caso lo mette il chiamante). {} se il filo è vuoto.
## Restituisce CHIAVI, non parole: vedi `rendi()` qui sotto.
static func componi_lettera(label: String, momenti: Array, pick: int) -> Dictionary:
	if momenti.is_empty():
		return {}
	var m: Dictionary = momenti[absi(pick) % momenti.size()]
	var tipo := str(m.get("t", ""))
	var template := str(MOMENTI_TESTO.get(tipo, ""))
	if template == "":
		return {}
	var testo: Array = [{"k": template, "args": [int(m.get("d", 1))]}]
	# una lettera lunga una storia: se il filo è ricco, lo dice. È un
	# capoverso a sé — si accosta al primo, non lo interrompe.
	if momenti.size() >= 6:
		testo.append({"k": "\n(E ho contato: i nostri momenti sono già %d!)",
				"args": [momenti.size()]})
	return {"from_key": label, "text_key": testo, "gift": absi(pick) % 6 == 0}


## IL PUNTO UNICO IN CUI UNA LETTERA DIVENTA PAROLE.
##
## Prende la lettera com'è in coda — chiavi italiane e argomenti — e la
## restituisce nella lingua di ADESSO: `{"from": …, "text": …, "gift": …}`.
## Pura, così la si prova headless (tests/cases/test_posta_lingua.gd).
##
## Il mittente passa anch'esso per la tabella, ma di norma è un DATO (il
## nome di un vicino) e la tabella non lo conosce: esce tale e quale. In
## tabella ci stanno solo i mittenti che sono un ruolo e non un nome
## proprio — «Il Gufo», «Volpe del bosco».
static func rendi(letter: Dictionary) -> Dictionary:
	return {
		"from": L10n.rendi(letter.get("from_key", letter.get("from", ""))),
		"text": _testo_di(letter),
		"gift": bool(letter.get("gift", false)),
	}


static func _testo_di(letter: Dictionary) -> String:
	if letter.has("text_key"):
		var chiave: Variant = letter["text_key"]
		# la scorciatoia del caso normale: una frase sola e i suoi
		# argomenti in cima alla lettera, senza incartarli in un `{"k": …}`
		if chiave is String and letter.has("args"):
			return L10n.rendi({"k": chiave, "args": letter["args"]})
		return L10n.rendi(chiave)
	# LE LETTERE VECCHIE. Nei salvataggi fatti prima di questo cambio la
	# coda contiene il testo GIÀ COMPOSTO: la sua chiave non esiste più da
	# nessuna parte e non c'è modo di ricostruirla. Si mostra com'è —
	# `t()` non la trova e la lascia passare intatta, tranne le poche che
	# erano finite in coda ancora in italiano puro, che così vengono
	# salvate. È l'unico pezzo di passato che questo file si porta dietro:
	# nuove lettere di questa forma non se ne scrivono più.
	return L10n.t(str(letter.get("text", "")))

var _player: Node3D
var _build: Node3D
var _daynight: Node3D
var _sfx

# nodo cassetta -> {lid, flag, letter, open}
var _boxes := {}
var _has_mail := false
var _current := {}
var _reading := false
var _near_box: Node3D
var _prev_time := -1.0
var _rng := RandomNumberGenerator.new()

var _prompt: PanelContainer
var _prompt_label: Label
var _card: PanelContainer
var _card_from: Label
var _card_text: Label
var _card_gift: Label

# la letterina 3D tra le zampine di Mochi mentre legge
var _paper: Node3D
var _read_tw: Tween


var _letter_queue: Array = []


var _boxes_dirty := true


func _ready() -> void:
	add_to_group("persistable")
	_rng.randomize()
	_player = get_node("%Player")
	_build = get_node("../BuildSystem")
	_daynight = get_node_or_null("../DayNight")
	_sfx = get_node_or_null(^"/root/Sfx")
	if _build.has_signal("placed_changed"):
		_build.connect("placed_changed", func(): _boxes_dirty = true)
	_build_ui()


## Una letterina su misura (ringraziamenti dei residenti…): salta la fila
## e arriva col prossimo mattino.
##
## SI METTE IN CODA LA CHIAVE, MAI IL TESTO TRADOTTO. Questa coda finisce
## su disco e ci resta anche giorni: chi cambia lingua nel frattempo si
## ritroverebbe per sempre le lettere di ieri nella lingua di ieri. La
## traduzione è UNA SOLA e sta in `rendi()`, al momento di aprire la busta.
##
##     queue_letter({"from_key": "Il Gufo",
##             "text_key": "Ho contato %d stelle su casa tua.",
##             "args": [dodici], "gift": false})
##
## `from_key`/`text_key` sono frasi rimandate (vedi `L10n.rendi`): una
## stringa per il caso normale, `{"k": …, "args": […]}` per una frase con
## i suoi argomenti, un Array per più capoversi in fila. Gli argomenti
## nudi sono dati e passano intatti (un nome, un giorno, un conto); quelli
## da tradurre si scrivono `{"k": …}`.
func queue_letter(letter: Dictionary) -> void:
	_letter_queue.append(letter)
	if _build:
		_build.request_save()  # la coda su disco riflette sempre lo stato reale


func save_extra() -> Dictionary:
	var d := {}
	if not _letter_queue.is_empty():
		d["mail_queue"] = _letter_queue
	# LA BUSTA GIA' CONSEGNATA E NON ANCORA APERTA. `_deliver()` la toglie
	# dalla coda con un `pop_front()` e SUBITO DOPO chiede il salvataggio:
	# senza questa riga la lettera usciva dal disco e non entrava da nessuna
	# parte. Al riavvio era sparita — e con lei il REGALO, che si materializza
	# solo aprendo la busta. Colpiva l'addio di chi e' partito, le
	# lettere-stagione del Gufo, il taccuino, le Promesse. E la finestra non
	# e' esotica: la consegna scatta anche al risveglio, e «dormo e poi
	# chiudo» e' il modo normale di finire una sessione.
	if _has_mail and not _current.is_empty():
		d["mail_current"] = _current
	return d


func load_extra(data: Dictionary) -> void:
	_letter_queue = data.get("mail_queue", [])
	var busta: Variant = data.get("mail_current")
	if busta is Dictionary and not (busta as Dictionary).is_empty():
		_current = busta
		_has_mail = true
		# la bandierina si rialza da sola: `_refresh_boxes` gira nel
		# `_process` e legge `_has_mail`, ma le cassette non sono ancora
		# in scena adesso — se ne occupa lui al primo giro utile


# ---------------------------------------------------------------- ciclo

func _process(delta: float) -> void:
	# la cache si ricostruisce solo quando il villaggio cambia
	if _boxes_dirty:
		_boxes_dirty = false
		_refresh_boxes()
	_check_delivery()
	_update_boxes(delta)
	_update_prompt()


# tiene la cache allineata alle cassette piazzate/rimosse/ricaricate
func _refresh_boxes() -> void:
	var current: Array[Node3D] = _build.get_placed_by_name("Cassetta posta")
	for node in _boxes.keys():
		if not is_instance_valid(node) or node not in current:
			_boxes.erase(node)
	for node in current:
		if not _boxes.has(node):
			_boxes[node] = {
				"lid": node.find_child("Lid", true, false),
				"flag": node.find_child("Flag", true, false),
				"letter": node.find_child("Letter", true, false),
				"open": false,
			}
			if _has_mail:
				_raise_flag(_boxes[node], true)


# un nuovo mattino è sorto? (avanzamento naturale o salto del sonno)
func _check_delivery() -> void:
	if _daynight == null:
		return
	var t: float = _daynight.time
	if _prev_time >= 0.0 and not _has_mail and not _boxes.is_empty():
		var crossed := _prev_time < MORNING_T and t >= MORNING_T
		var jumped := t < _prev_time and t >= 0.25 and t <= 0.42
		if crossed or jumped:
			_deliver()
	_prev_time = t


func _deliver() -> void:
	_has_mail = true
	if not _letter_queue.is_empty():
		_current = _letter_queue.pop_front()
		if _build:
			# senza salvare, la lettera su misura verrebbe riconsegnata
			# (col regalo!) a ogni riavvio
			_build.request_save()
	else:
		# metà delle volte scrive un vicino, ripensando a un momento vero
		var dai_momenti := _lettera_dai_momenti()
		if not dai_momenti.is_empty() and _rng.randf() < 0.55:
			_current = dai_momenti
		else:
			_current = LETTERS[_rng.randi() % LETTERS.size()]
	for node in _boxes:
		_raise_flag(_boxes[node], true)
		_sparkle((node as Node3D).global_position + Vector3(0, 1.25, 0), Color(1.0, 0.9, 0.55))
	if _sfx:
		_sfx.play("chirp" + str(1 + _rng.randi() % 3), -14.0, 1.05)


# Un vicino a caso, un momento a caso dal suo filo: la lettera racconta
# la storia di QUESTO villaggio. {} se non c'è ancora materiale.
func _lettera_dai_momenti() -> Dictionary:
	var legami := get_tree().get_first_node_in_group("legami")
	var visitors := get_node_or_null("../Visitors")
	if legami == null or visitors == null:
		return {}
	var mittenti := []
	for r in visitors.get("_residents"):
		var nome := str((r.get("dna", {}) as Dictionary).get("name", ""))
		var label := str(r.get("label", ""))
		if nome == "" or label == "":
			continue
		var momenti: Array = legami.call("momenti_di", nome)
		if not momenti.is_empty():
			mittenti.append([label, momenti])
	# e anche chi è partito, ogni tanto, scrive dal Grande Prato
	for riga in legami.call("partiti"):
		var filo: Dictionary = riga[1]
		var momenti_p: Array = filo.get("momenti", [])
		if not momenti_p.is_empty():
			mittenti.append([str(riga[0]), momenti_p])
	# …e chi se n'è andato per conto suo scrive lo stesso, ogni tanto:
	# non ha un fiore né un posto nel memoriale, e questa lettera è
	# l'unica traccia che gli resta. Senza, il momento "addio" — il più
	# importante che un filo possa avere — non arriverebbe MAI a schermo:
	# il disertore non è né un residente né un partito, e il template
	# MOMENTI_TESTO["addio"] restava codice morto.
	for riga_v in legami.call("andati_via"):
		var filo_v: Dictionary = riga_v[1]
		var momenti_v: Array = filo_v.get("momenti", [])
		if not momenti_v.is_empty():
			mittenti.append([str(riga_v[0]), momenti_v])
	if mittenti.is_empty():
		return {}
	var scelto: Array = mittenti[_rng.randi() % mittenti.size()]
	return componi_lettera(str(scelto[0]), scelto[1], _rng.randi())


func _raise_flag(b: Dictionary, up: bool) -> void:
	var flag := b["flag"] as Node3D
	if flag == null:
		return
	var tw := create_tween()
	tw.tween_property(flag, "rotation:x", 0.0 if up else -1.35, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- sportello

func _update_boxes(_delta: float) -> void:
	_near_box = null
	for node in _boxes:
		if not is_instance_valid(node):
			continue
		var b: Dictionary = _boxes[node]
		var dist: float = _player.global_position.distance_to((node as Node3D).global_position)
		var want_open := dist < 1.35
		if want_open != b["open"]:
			b["open"] = want_open
			_animate_lid(b, want_open)
		# LA CASSETTA NON È PIÙ SOLO UNA BOCCA CHE DÀ. Prima `_near_box` si
		# accendeva solo `_has_mail`: senza posta la cassetta era inerte,
		# e il canale più intimo del gioco restava a senso unico. Adesso
		# ci si può stare davanti anche per IMBUCARE (vedi Rispondere.gd).
		if want_open and not _reading:
			_near_box = node


# lo sportello si spalanca con un rimbalzino elastico; se c'è posta la
# busta fa capolino inclinandosi verso di te
func _animate_lid(b: Dictionary, open: bool) -> void:
	var lid := b["lid"] as Node3D
	var letter := b["letter"] as Node3D
	if lid == null:
		return
	var tw := create_tween()
	if open:
		tw.tween_property(lid, "rotation:x", -1.9, 0.42) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if _sfx:
			_sfx.play("tick", -16.0, 0.7)
		if letter and _has_mail:
			letter.visible = true
			letter.position.z = -0.1
			letter.rotation.x = -0.15
			var lt := create_tween().set_parallel(true)
			lt.tween_property(letter, "position:z", -0.19, 0.5) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)
			lt.tween_property(letter, "rotation:x", -0.55, 0.5) \
					.set_trans(Tween.TRANS_SINE).set_delay(0.15)
	else:
		tw.tween_property(lid, "rotation:x", 0.0, 0.3) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		if letter:
			var lt := create_tween()
			lt.tween_property(letter, "position:z", -0.1, 0.2)
			lt.tween_callback(func(): letter.visible = false)
		if _sfx:
			_sfx.play("tick", -18.0, 0.6)


# ---------------------------------------------------------------- lettura

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if _reading:
		_close_letter()
		get_viewport().set_input_as_handled()
	elif _near_box:
		if _has_mail:
			_open_letter()
		else:
			# niente da leggere: allora si scrive. È l'altro senso del
			# canale, quello che mancava (scenes/interact/Rispondere.gd)
			var risp := get_tree().get_first_node_in_group("rispondere")
			if risp == null:
				return
			risp.call("apri")
		get_viewport().set_input_as_handled()


func _open_letter() -> void:
	_reading = true
	# è QUI che la lettera diventa parole, e in nessun altro posto
	var vista := rendi(_current)
	_card_from.text = "~ %s ~" % vista["from"]
	_card_text.text = vista["text"]
	_card_gift.visible = vista["gift"]
	_card.visible = true
	_card.reset_size()
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2.ONE * 0.7
	_card.modulate.a = 0.0
	_card.rotation = -0.06
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate:a", 1.0, 0.25)
	tw.tween_property(_card, "rotation", 0.02, 0.4).set_trans(Tween.TRANS_SINE)
	if _sfx:
		_sfx.build_open()
	_mochi_read(true)
	if vista["gift"] and _near_box:
		_spawn_gift(_near_box)


func _close_letter() -> void:
	_reading = false
	_has_mail = false
	_mochi_read(false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_card, "modulate:a", 0.0, 0.2)
	tw.tween_property(_card, "scale", Vector2.ONE * 0.85, 0.2)
	tw.chain().tween_callback(func(): _card.visible = false)
	for b in _boxes.values():
		_raise_flag(b, false)
		var letter := b["letter"] as Node3D
		if letter:
			letter.visible = false
	if _sfx:
		_sfx.build_close()


# ------------------------------------------------- la letterina in zampa
# Mentre la card è aperta, Mochi legge DAVVERO: il foglio di carta crema
# tra le zampine, la testolina che segue le righe a piccoli scatti, e
# alla firma il sorrisino con la testa inclinata.

func _mochi_read(on: bool) -> void:
	var mochi := _player.get_node_or_null("Mochi")
	if mochi == null:
		return
	if _read_tw and _read_tw.is_valid():
		_read_tw.kill()
	if on:
		mochi.call("hold_letter", true)
		_paper = _make_paper()
		mochi.add_child(_paper)
		_paper.position = Vector3(0, 0.6, -0.28)
		_paper.rotation.x = 0.5
		_paper.scale = Vector3.ONE * 0.05
		# il foglio sboccia tra le zampine…
		_read_tw = create_tween()
		_read_tw.tween_property(_paper, "scale", Vector3.ONE, 0.3) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# …e la lettura scorre con calma: tre righe, poi la firma
		_read_tw.parallel().tween_property(mochi, "pour", 1.0, 6.0) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT) \
				.set_delay(0.25)
		# alla firma, il saltello di contentezza
		_read_tw.chain().tween_property(mochi, "joy", 1.0, 0.42) \
				.set_trans(Tween.TRANS_SINE)
		_read_tw.tween_callback(func():
			if is_instance_valid(mochi):
				mochi.set("joy", 0.0))
		# il dondolio della carta (legato al foglio: muore con lui)
		var sway := _paper.create_tween().set_loops()
		sway.tween_property(_paper, "rotation:z", 0.035, 1.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sway.tween_property(_paper, "rotation:z", -0.035, 1.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		mochi.call("hold_letter", false)
		if _paper and is_instance_valid(_paper):
			var old := _paper
			var tw := create_tween()
			tw.tween_property(old, "scale", Vector3.ONE * 0.03, 0.22) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_callback(old.queue_free)
		_paper = null


# Il foglio: carta crema, tre righe di scrittura (l'ultima più corta) e
# il cuoricino della firma. Righe su ENTRAMBE le facce: la letterina si
# legge da ogni angolo di camera.
func _make_paper() -> Node3D:
	var paper := Node3D.new()
	var sheet := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.24, 0.006)
	sheet.mesh = bm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("fdf6e3")
	sheet.material_override = pm
	paper.add_child(sheet)
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color("b89a74")
	var rosa := StandardMaterial3D.new()
	rosa.albedo_color = Color("e88aa0")
	for lato: float in [-0.005, 0.005]:
		for i in 3:
			var line := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.2 - (0.07 if i == 2 else 0.0), 0.014, 0.004)
			line.mesh = lm
			line.material_override = ink
			line.position = Vector3(-0.035 if i == 2 else 0.0, 0.055 - i * 0.052, lato)
			paper.add_child(line)
		# il cuoricino: due lobi e la puntina, in basso a destra
		var punta := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.017
		cm.height = 0.026
		cm.radial_segments = 8
		punta.mesh = cm
		punta.material_override = rosa
		punta.rotation.z = PI
		punta.position = Vector3(0.095, -0.082, lato)
		paper.add_child(punta)
		for s: float in [-1.0, 1.0]:
			var lobo := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.011
			sm.height = 0.022
			lobo.mesh = sm
			lobo.material_override = rosa
			lobo.position = Vector3(0.095 + s * 0.0095, -0.072, lato)
			paper.add_child(lobo)
	return paper


# il regalino: un pacchettino che sboccia dalla cassetta, fluttua e svanisce
func _spawn_gift(box: Node3D) -> void:
	var gift := Node3D.new()
	var carta := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.14, 0.12, 0.14)
	carta.mesh = bm
	var carta_mat := StandardMaterial3D.new()
	carta_mat.albedo_color = Color("f4b8c8")
	carta.material_override = carta_mat
	gift.add_child(carta)
	for rot in [0.0, PI * 0.5]:
		var ribbon := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.03, 0.13, 0.145)
		ribbon.mesh = rm
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color("fff3e0")
		ribbon.material_override = rmat
		ribbon.rotation.y = rot
		gift.add_child(ribbon)
	gift.position = box.global_position + Vector3(0, 1.28, 0)
	gift.scale = Vector3.ONE * 0.05
	add_child(gift)
	_sparkle(gift.position, Color(1.0, 0.8, 0.9))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(gift, "scale", Vector3.ONE, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.35)
	tw.tween_property(gift, "position:y", gift.position.y + 0.45, 2.2) \
			.set_trans(Tween.TRANS_SINE).set_delay(0.35)
	tw.tween_property(gift, "rotation:y", TAU * 1.5, 2.2).set_delay(0.35)
	tw.chain().tween_property(gift, "scale", Vector3.ONE * 0.02, 0.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(gift.queue_free)
	if _sfx:
		get_tree().create_timer(0.45).timeout.connect(func():
			if _sfx: _sfx.place_ok())


func _sparkle(pos: Vector3, color: Color) -> void:
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
	quad.size = Vector2(0.14, 0.14)
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
	pm.emission_sphere_radius = 0.12
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, -2.6, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var poof := GPUParticles3D.new()
	poof.amount = 14
	poof.lifetime = 0.6
	poof.one_shot = true
	poof.explosiveness = 1.0
	poof.local_coords = false
	poof.process_material = pm
	poof.draw_pass_1 = quad
	poof.position = pos
	add_child(poof)
	poof.emitting = true
	get_tree().create_timer(1.3).timeout.connect(poof.queue_free)


# ---------------------------------------------------------------- UI

func _update_prompt() -> void:
	var cam := get_viewport().get_camera_3d()
	if _reading or _near_box == null or cam == null:
		_prompt.visible = false
		return
	var wp: Vector3 = _near_box.global_position + Vector3(0, 1.5, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = L10n.t("E — leggi la posta") if _has_mail \
			else L10n.t("E — rispondi")
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	_prompt = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.95, 0.88, 0.92)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(0.62, 0.46, 0.34, 0.5)
	sb.set_border_width_all(2)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	_prompt.add_theme_stylebox_override("panel", sb)
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_prompt)
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 13)
	_prompt_label.add_theme_color_override("font_color", UI_BROWN)
	_prompt.add_child(_prompt_label)

	# la card della lettera: un foglio di carta color crema, appena storto
	_card = PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color("fdf6e3")
	cs.set_corner_radius_all(14)
	cs.border_color = Color(0.72, 0.58, 0.44, 0.6)
	cs.set_border_width_all(2)
	cs.shadow_color = Color(0.25, 0.15, 0.1, 0.3)
	cs.shadow_size = 12
	cs.content_margin_left = 26.0
	cs.content_margin_right = 26.0
	cs.content_margin_top = 18.0
	cs.content_margin_bottom = 16.0
	_card.add_theme_stylebox_override("panel", cs)
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_card)
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.offset_left = -CARD_LARGHEZZA * 0.5
	_card.offset_right = CARD_LARGHEZZA * 0.5
	_card.offset_top = -110.0

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_card.add_child(vbox)

	_card_from = Label.new()
	_card_from.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_from.add_theme_font_size_override("font_size", 16)
	_card_from.add_theme_color_override("font_color", Color("8a5a3a"))
	vbox.add_child(_card_from)

	_card_text = Label.new()
	_card_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_text.add_theme_font_size_override("font_size", 14)
	_card_text.add_theme_color_override("font_color", UI_BROWN)
	# IL FOGLIO HA UNA LARGHEZZA, e le righe ci vanno a capo dentro. Quasi
	# tutte le lettere sono scritte con gli a capo a mano — sono la loro
	# impaginazione, e vanno rispettati — ma una riga arriva lunga: lo
	# sfogo di chi se ne va, che si compone a runtime coi torti contati e
	# non sa quanto verrà. Senza questo, `reset_size()` allargava il foglio
	# fino a 1100 pixel e la lettera d'addio — la più importante che il
	# gioco scriva — usciva dal bordo destro dello schermo come uno
	# striscione. La larghezza è quella che il pannello dichiara da sempre
	# nelle sue ancore (380), meno i due margini.
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.custom_minimum_size.x = CARD_LARGHEZZA - 52.0
	vbox.add_child(_card_text)

	_card_gift = Label.new()
	_card_gift.text = L10n.t("… e c'è anche un regalino!")
	_card_gift.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_gift.add_theme_font_size_override("font_size", 13)
	_card_gift.add_theme_color_override("font_color", Color("c25a7a"))
	vbox.add_child(_card_gift)

	var hint := Label.new()
	hint.text = L10n.t("E — chiudi")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(UI_BROWN, 0.55))
	vbox.add_child(hint)


# ---------------------------------------------------------------- debug CLI

func debug_deliver() -> void:
	_has_mail = false
	_deliver()


func debug_force_gift() -> void:
	for l in LETTERS:
		if l["gift"]:
			_current = l
			return


func debug_read() -> void:
	if _near_box == null and not _boxes.is_empty():
		_near_box = _boxes.keys()[0]
	if _near_box:
		_open_letter()
