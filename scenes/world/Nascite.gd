extends Node

## LE NUOVE LEVE — nel villaggio, finalmente, nasce qualcuno.
##
## Il Filo Rosso sapeva invecchiare e sapeva salutare, ma il villaggio
## non si rinnovava mai: ogni partenza era una sottrazione, e l'unico
## modo di riempire un vuoto era che bussasse uno sconosciuto. Da qui in
## poi il cerchio si chiude — e si chiude nel modo che conta: il gene di
## chi è partito può tornare addosso a chi arriva. «Ha gli occhi di
## Timo» non è una frase scritta a mano: sono `eye_r`, `eye_gap` e
## `eye_h` copiati dal genoma di Timo dentro quello di un cucciolo che
## Timo non vedrà mai. Il giocatore lo scopre da solo, guardandolo.
##
## COME VA, dal punto di vista di chi gioca:
##  1. una mattina di primavera il Gufo scrive: in casa di due vicini
##     che si vogliono bene c'è una vocina nuova;
##  2. vai a vedere. Sulla soglia c'è il prompt, e i genitori aspettano
##     TE: il nome lo scegli tu, e da quel momento quel nome esiste;
##  3. il cucciolo entra nel mondo lì, davanti a te — piccolissimo,
##     testona, passo corto, e una vocina che storpia le parole;
##  4. cresce per GIORNI_ADULTO giorni. Un giorno dice la sua prima
##     parola, e se sei lì il filo se lo ricorda per sempre.
##
## Il nome si sceglie PRIMA che il cucciolo entri fra i residenti, e non
## per pigrizia: rinominare un residente dopo vorrebbe dire inseguire la
## stessa stringa dentro `_residents`, i cervelli, gli animi, il
## calendario dei compleanni e la chiave del filo — cinque posti che
## sarebbero divergiti al primo che ne dimenticavo uno.
##
## LE REGOLE COZY (non negoziabili, come quelle della mortalità in
## docs/SISTEMA_EMOZIONALE.md):
##  · Si nasce SOLO in primavera, e mai più di una volta all'anno.
##  · I genitori sono due adulti — un lui e una lei — che si frequentano
##    davvero (l'affinità del cervello, non un sorteggio).
##  · Nessuno nasce durante un congedo o nel lutto: il villaggio fa una
##    cosa per volta, e quella cosa la si vive intera.
##  · Serve un LETTINO libero. È lo stesso cancello del trasloco, e qui
##    diventa la cosa più tenera del gioco: perché nasca qualcuno,
##    qualcuno deve avergli preparato il letto.
##  · Una coppia arriva al massimo a MAX_FIGLI: nessuna famiglia diventa
##    una colonia, e ogni cucciolo resta un evento.
##  · Mai mentre non ci sei: l'annuncio aspetta il mattino di un giorno
##    giocato, e il cucciolo aspetta che tu vada a conoscerlo.
##
## Tutta la parte che DECIDE è pura e statica (quando, coppia_migliore,
## eredita_possibile): si prova headless in tests/cases/test_nascite.gd,
## senza far passare quattro stagioni con le mani sulla tastiera.

const DNA := preload("res://scenes/npc/ChibiDNA.gd")

## Quanti cuccioli al massimo per coppia. Tre è già una famiglia numerosa
## in un paese di ventotto anime.
const MAX_FIGLI := 3

## Quanto devono essersi frequentati per arrivarci: l'affinità sale di 1
## a ogni chiacchierata vera, quindi otto sono settimane di vicinanza.
const AFFINITA_MINIMA := 8

## La primavera è la stagione 0 (DayNight: 4 stagioni da 7 giorni).
const STAGIONE_NASCITE := 0

## Quanti giorni dura un anno: una nascita per primavera, non una a
## settimana. Lo stesso numero di DayNight.YEAR_DAYS, chiesto a lui.
const GIORNI_ANNO := 28

## L'ora del mattino in cui il villaggio si sveglia con una novità.
const ORA_ANNUNCIO := 0.30

## Quanto deve aspettare, un cucciolo, prima di dire la prima parola.
const GIORNI_PRIMA_PAROLA := 3

var _visitors: Node
var _legami: Node
var _daynight: Node3D
var _congedo: Node
var _build: Node3D
var _player: Node3D

# lo stato salvato
var _ultima_nascita := -999
# il cucciolo che è nato stanotte e che nessuno ha ancora visto:
# {padre, madre, seme, giorno} — diventa un residente quando ci vai
var _in_arrivo := {}
# nome -> giorno a partire dal quale può dire la prima parola
var _prime_parole := {}
var _annunciato_oggi := false

# il pannello del nome (lo stesso rito con cui si battezza una
# costellazione: il giocatore scrive, e da quel momento quel nome esiste)
var _pannello: PanelContainer
var _campo: LineEdit
var _titolo: Label
var _prompt: PanelContainer
var _prompt_label: Label


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("nascite")
	_visitors = get_tree().get_first_node_in_group("visitors")
	_legami = get_tree().get_first_node_in_group("legami")
	_congedo = get_tree().get_first_node_in_group("congedo")
	_daynight = get_tree().get_first_node_in_group("daynight") as Node3D
	_build = get_tree().get_first_node_in_group("build_system")
	if _daynight and _daynight.has_signal("day_changed"):
		_daynight.connect("day_changed", _on_day_changed)
	_costruisci_pannello()
	# il giocatore si trova per PERCORSO, non per gruppo: il gruppo
	# "player" non esiste in questo progetto, e cercarlo lì dava sempre
	# null — cioè un prompt che non compariva mai e un cucciolo che
	# nessuno poteva andare a conoscere. Siamo figli di CozyWorld,
	# quindi il Player è due livelli sopra (come Onsen e Nascondino).
	(func(): _player = get_node_or_null("../../Player") as Node3D).call_deferred()


# ============================================================ le regole pure

## Può nascere qualcuno oggi? Tutte le condizioni del calendario e del
## villaggio in una riga sola, senza toccare l'albero della scena.
##  giorno: il giorno assoluto · stagione: 0..3 · ultima: -999 = mai
static func quando(giorno: int, stagione: int, ultima: int,
		in_congedo: bool, in_lutto: bool, posti_liberi: bool,
		gia_in_arrivo: bool) -> bool:
	if stagione != STAGIONE_NASCITE:
		return false
	if in_congedo or in_lutto or gia_in_arrivo:
		return false
	if not posti_liberi:
		return false
	return giorno - ultima >= GIORNI_ANNO


## La coppia migliore fra tutte le possibili: un lui e una lei, adulti,
## che si frequentano più di chiunque altro e che non hanno già una
## famiglia numerosa. Ritorna [nome_padre, nome_madre] oppure [].
##
## `adulti`: [[nome, label, dna]] · `affinita`: Callable(label_a, label_b) -> int
## `figli`: Callable(nome_a, nome_b) -> int
## I due Callable sono le uniche finestre sul mondo: nei test si passano
## due dizionari finti e la regola si prova per intero.
static func coppia_migliore(adulti: Array, affinita: Callable,
		figli: Callable) -> Array:
	var best: Array = []
	var best_v := AFFINITA_MINIMA - 1
	for i in adulti.size():
		for j in range(i + 1, adulti.size()):
			var a: Array = adulti[i]
			var b: Array = adulti[j]
			var sa := DNA.sesso(a[2])
			var sb := DNA.sesso(b[2])
			if sa == sb:
				continue
			if int(figli.call(str(a[0]), str(b[0]))) >= MAX_FIGLI:
				continue
			# l'affetto si guarda dai DUE lati: uno che chiacchiera molto
			# con chi non lo ricambia non è una coppia, è un'infatuazione
			var v: int = mini(int(affinita.call(str(a[1]), str(b[1]))),
					int(affinita.call(str(b[1]), str(a[1]))))
			if v > best_v:
				best_v = v
				# il padre per primo: serve solo a scrivere le due chiavi
				# nel filo sempre nello stesso ordine
				best = [str(a[0]), str(b[0])] if sa == "m" else [str(b[0]), str(a[0])]
	return best


## Il gene che torna. Fra chi è partito sceglie, con un peso, chi ha
## lasciato il filo più lungo — chi è stato più presente lascia più
## traccia — e uno dei quattro caratteri che si riconoscono a occhio.
## `partiti`: [[nome, filo]] come li dà Legami.partiti().
## Ritorna {"da", "cosa", "dna"} oppure {}.
static func eredita_possibile(partiti: Array, seme: int) -> Dictionary:
	var candidati: Array = []
	for riga in partiti:
		if riga is not Array or riga.size() < 2:
			continue
		var filo: Dictionary = riga[1]
		var d: Dictionary = filo.get("dna_ricordo", {})
		if d.is_empty():
			continue
		var peso := int(filo.get("n", (filo.get("momenti", []) as Array).size()))
		candidati.append([str(riga[0]), d, peso])
	if candidati.is_empty():
		return {}
	candidati.sort_custom(func(x, y): return int(x[2]) > int(y[2]))
	# fra i tre più presenti, uno a sorte: non è sempre lo stesso, ma è
	# sempre qualcuno che il giocatore ricorda
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	var scelto: Array = candidati[rng.randi() % mini(3, candidati.size())]
	var chiavi: Array = DNA.EREDITABILI.keys()
	return {"da": str(scelto[0]), "cosa": str(chiavi[rng.randi() % chiavi.size()]),
			"dna": scelto[1]}


## Il gene torna solo qualche volta: se tornasse sempre, in tre
## generazioni il villaggio sarebbe un museo di chi non c'è più.
static func eredita_stavolta(seme: int) -> bool:
	return absi(seme) % 100 < 55


## «Ha gli occhi di Timo». La frase con cui il villaggio riconosce,
## addosso a un cucciolo, qualcosa di chi non c'è più.
static func frase_eredita(cosa: String, da: String) -> String:
	match cosa:
		"occhi":
			return L10n.tf("ha gli occhi di %s", [da])
		"manto":
			return L10n.tf("ha lo stesso pelo di %s", [da])
		"orecchie":
			return L10n.tf("ha le orecchie di %s", [da])
		"sguardo":
			return L10n.tf("quando guarda storto, è %s tale e quale", [da])
	return ""


# ============================================================ il mattino

func _on_day_changed(_giorno: int) -> void:
	_annunciato_oggi = false


func _process(_delta: float) -> void:
	_aggiorna_prompt()
	if _annunciato_oggi or _daynight == null or _visitors == null or _legami == null:
		return
	if float(_daynight.get("time")) < ORA_ANNUNCIO:
		return
	_annunciato_oggi = true
	_prova_una_nascita()
	_prova_prima_parola()


func _prova_una_nascita() -> void:
	var giorno := int(_daynight.get("day"))
	if not quando(giorno, int(_daynight.call("get_season")), _ultima_nascita,
			_congedo != null and bool(_congedo.call("in_corso")),
			bool(_legami.call("lutto_attivo")),
			bool(_visitors.call("has_free_house")),
			not _in_arrivo.is_empty()):
		return
	var adulti: Array = _visitors.call("adulti_del_villaggio")
	if adulti.size() < 2:
		return
	var coppia := coppia_migliore(adulti,
			# IL LIBRO MASTRO, non il contatore delle chiacchiere: una nascita
			# viene da gesti veri, e adesso si può dire quali
			func(a, b): return _visitors.call("affetto_fra", a, b),
			func(a, b): return int(_legami.call("figli_della_coppia", a, b)))
	if coppia.is_empty():
		return
	_in_arrivo = {"padre": str(coppia[0]), "madre": str(coppia[1]),
			"seme": hash("%s+%s+%d" % [coppia[0], coppia[1], giorno]),
			"giorno": giorno}
	_ultima_nascita = giorno
	_annuncia()
	_salva()


func _annuncia() -> void:
	var padre := str(_in_arrivo.get("padre", ""))
	var madre := str(_in_arrivo.get("madre", ""))
	_toast(L10n.tf("In casa di %s e %s, stanotte, è arrivata una vocina nuova.",
			[padre, madre]))
	# `../Mail` da qui vuol dire `CozyWorld/Mail`, che non esiste: Nascite e'
	# una figlia RUNTIME di CozyWorld, e i suoi fratelli veri stanno DUE
	# livelli sopra — lo stesso file lo sa gia' (usa `../../Player`). Il
	# ripiego sul gruppo era morto: nessuno popola il gruppo "mail".
	# Risultato: la lettera del Gufo per la nascita non e' mai partita, ed
	# e' scritta e gia' tradotta.
	var mail := get_node_or_null("../../Mail")
	if mail and mail.has_method("queue_letter"):
		mail.call("queue_letter", {
			"from_key": "il Gufo",
			"text_key": "Stanotte non ho chiuso occhio, e per una buona ragione.\nIn casa di %s e %s è arrivato qualcuno\npiù piccolo delle mie due ali messe insieme.\n\nVai a conoscerlo, quando puoi.\nUn nome non ce l'ha: hanno detto che lo sceglierai tu.",
			"args": [padre, madre],
			"gift": false,
		})
	var sfx := get_node_or_null(^"/root/Sfx")
	if sfx:
		sfx.call("place_ok")


# ============================================================ conoscerlo

## Dove aspetta il cucciolo: sulla soglia di casa della madre.
func _soglia() -> Vector3:
	if _in_arrivo.is_empty() or _visitors == null:
		return Vector3.ZERO
	for chi in ["madre", "padre"]:
		var nodo: Node3D = _visitors.call("node_di",
				_label_di(str(_in_arrivo.get(chi, ""))))
		if nodo != null and is_instance_valid(nodo):
			return nodo.global_position
	return Vector3.ZERO


## Sei abbastanza vicino da poterlo conoscere?
func _a_portata() -> bool:
	if _in_arrivo.is_empty() or _player == null:
		return false
	if _pannello != null and _pannello.visible:
		return false
	var p := _soglia()
	return p != Vector3.ZERO and p.distance_to(_player.global_position) < 2.6


func _aggiorna_prompt() -> void:
	if _prompt == null:
		return
	var cam := get_viewport().get_camera_3d()
	# IL CARTELLINO STA AL LIVELLO 12, cioè SOPRA il velo nero del sonno
	# (livello 10): con un letto vicino alla soglia giusta, «E — conosci il
	# cucciolo» compariva sullo schermo nero — e in un sogno, che ha come
	# regola prima di non avere parole, sarebbe una didascalia in mezzo
	# alla scena. E seguirebbe pure la camera del sogno.
	# stesso motivo: due livelli sopra. Con `../` la guardia non si eseguiva
	# MAI (`has_method()` su null non solleva), e il cartellino restava
	# acceso sopra il velo nero del sonno — e dentro il sogno, che ha come
	# regola prima di non avere parole.
	var inter := get_node_or_null("../../Interactions")
	if inter and inter.has_method("is_sleeping") and bool(inter.call("is_sleeping")):
		_prompt.visible = false
		return
	if cam == null or not _a_portata():
		_prompt.visible = false
		return
	var wp := _soglia() + Vector3(0, 1.15, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = L10n.t("E — conosci il cucciolo")
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if _pannello != null and _pannello.visible:
		return
	if not event.is_action_pressed("interact"):
		return
	if not _a_portata():
		return
	get_viewport().set_input_as_handled()
	_apri_pannello()


func _apri_pannello() -> void:
	var proposto := _nome_libero(int(_in_arrivo.get("seme", 0)))
	_pannello.visible = true
	_campo.text = ""
	_campo.placeholder_text = proposto
	_titolo.text = L10n.tf("%s e %s aspettano te.\nCome si chiama?",
			[str(_in_arrivo.get("padre", "")), str(_in_arrivo.get("madre", ""))])
	_campo.grab_focus()


func _conferma_nome() -> void:
	if _in_arrivo.is_empty():
		_pannello.visible = false
		return
	var nome := _campo.text.strip_edges()
	if nome == "":
		nome = _campo.placeholder_text
	_pannello.visible = false
	var padre := str(_in_arrivo.get("padre", ""))
	var madre := str(_in_arrivo.get("madre", ""))
	var seme := int(_in_arrivo.get("seme", 0))
	var dna_p: Dictionary = _visitors.call("dna_di", _label_di(padre))
	var dna_m: Dictionary = _visitors.call("dna_di", _label_di(madre))
	if dna_p.is_empty() or dna_m.is_empty():
		_in_arrivo = {}       # un genitore è partito nel frattempo
		return
	var eredita := {}
	if eredita_stavolta(seme):
		eredita = eredita_possibile(_legami.call("partiti"), seme)
	var figlio := DNA.incrocia(dna_p, dna_m, seme, nome, eredita)
	# NASCE IN CASA DELLA MADRE, non in una casa sua: è così che al mattino
	# escono dalla stessa porta in tre. Se quella soglia non c'è più (la
	# casa demolita fra l'annuncio e adesso), `accogli_nato` ripiega su un
	# lettino libero e il cucciolo non sparisce.
	var label: String = _visitors.call("accogli_nato", figlio,
			str(_in_arrivo.get("madre", "")))
	if label == "":
		# il lettino è stato smontato fra l'annuncio e adesso: il
		# cucciolo aspetta ancora, non sparisce
		_toast(L10n.t("Non c'è un lettino libero dove metterlo. Aspettano."))
		return
	_legami.call("nascita", nome, padre, madre, figlio.get("eredita", {}))
	# il primo nodo del SUO filo: il nome gliel'hai dato tu
	_legami.call("momento", nome, "battesimo", "%s e %s" % [padre, madre])
	# e sul filo dei genitori il mattino più lungo della loro vita —
	# da vecchi potranno chiedere di rivederlo (Congedo.LUOGHI)
	for g in [padre, madre]:
		_legami.call("momento", g, "nascita", nome)
	_prime_parole[nome] = int(_in_arrivo.get("giorno", 0)) + GIORNI_PRIMA_PAROLA
	_in_arrivo = {}
	_festeggia(figlio, nome)
	_salva()


func _festeggia(figlio: Dictionary, nome: String) -> void:
	var maschio := DNA.sesso(figlio) == "m"
	_toast(L10n.tf("%s Si chiama %s. E da oggi c'è.",
			[L10n.t("È un maschietto.") if maschio else L10n.t("È una femminuccia."),
			nome]))
	var er: Dictionary = figlio.get("eredita", {})
	if not er.is_empty():
		var frase := frase_eredita(str(er.get("cosa", "")), str(er.get("da", "")))
		if frase != "":
			# non subito: prima lo guardi, poi te ne accorgi
			get_tree().create_timer(3.2).timeout.connect(func():
				if is_instance_valid(self):
					_toast(L10n.tf("Poi te ne accorgi, e ti si stringe qualcosa: %s.",
							[frase])))
	var gtree := get_tree().get_first_node_in_group("grande_albero")
	if gtree:
		gtree.call("engrave", "❀", "è nato %s", [nome])
	get_tree().call_group("regista", "note", "socievole")
	var sfx := get_node_or_null(^"/root/Sfx")
	if sfx:
		sfx.call("place_ok")


# ============================================================ la prima parola

func _prova_prima_parola() -> void:
	if _player == null or _prime_parole.is_empty() or _daynight == null:
		return
	var giorno := int(_daynight.get("day"))
	for nome in _prime_parole.keys():
		if giorno < int(_prime_parole[nome]):
			continue
		var nodo: Node3D = _visitors.call("node_di", _label_di(str(nome)))
		if nodo == null or not is_instance_valid(nodo):
			continue
		# deve succedere DAVANTI a te: una prima parola detta a nessuno
		# non è una prima parola
		if nodo.global_position.distance_to(_player.global_position) > 5.0:
			continue
		_prime_parole.erase(nome)
		nodo.call("speak", ["ciao", "amico"], "felice")
		_legami.call("momento", str(nome), "prima_parola", "")
		_toast(L10n.tf("%s ha detto la sua prima parola. Storta, ma sua.", [nome]))
		_salva()
		return


# ============================================================ il pannello

func _costruisci_pannello() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	# il cartellino sulla soglia, come tutti gli altri del gioco
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
	_prompt_label.add_theme_color_override("font_color", Color("6b4a33"))
	_prompt.add_child(_prompt_label)

	_pannello = PanelContainer.new()
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color(0.99, 0.96, 0.9, 0.97)
	ms.border_color = Color(0.85, 0.66, 0.5, 0.9)
	ms.set_corner_radius_all(14)
	ms.set_border_width_all(2)
	ms.content_margin_left = 22.0
	ms.content_margin_right = 22.0
	ms.content_margin_top = 14.0
	ms.content_margin_bottom = 14.0
	_pannello.add_theme_stylebox_override("panel", ms)
	_pannello.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	center.add_child(_pannello)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_pannello.add_child(vbox)
	_titolo = Label.new()
	_titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titolo.add_theme_font_size_override("font_size", 15)
	_titolo.add_theme_color_override("font_color", Color("8a5a3a"))
	vbox.add_child(_titolo)
	_campo = LineEdit.new()
	_campo.custom_minimum_size = Vector2(300, 0)
	_campo.max_length = 18
	_campo.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_campo.text_submitted.connect(func(_t): _conferma_nome())
	vbox.add_child(_campo)
	var hint := Label.new()
	hint.text = L10n.t("Invio — e da quel momento è il suo nome")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.54, 0.35, 0.23, 0.55))
	vbox.add_child(hint)


# ============================================================ utilità

func _label_di(nome: String) -> String:
	if _visitors == null or nome == "":
		return ""
	return str(_visitors.call("label_di_nome", nome))


## Un nome che nel villaggio non c'è già — né fra i vivi né fra chi è
## partito: l'unicità delle label è un'invariante di Visitors (due «la
## volpina Pepita» si ruberebbero cervello, animo e compleanno).
func _nome_libero(seme: int) -> String:
	var presi := {}
	if _visitors:
		for riga in _visitors.call("adulti_del_villaggio"):
			presi[str(riga[0])] = true
	if _legami:
		for riga in _legami.call("partiti"):
			presi[str(riga[0])] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seme)
	var pool: Array = DNA.NAMES_NATI.duplicate()
	for k in pool.size():
		var n := str(pool[(int(rng.randi()) + k) % pool.size()])
		if not presi.has(n):
			return n
	return str(pool[rng.randi() % pool.size()])


func _toast(testo: String) -> void:
	if _visitors and _visitors.has_method("_show_toast"):
		_visitors.call("_show_toast", testo)


func _salva() -> void:
	if _build and _build.has_method("request_save"):
		_build.call("request_save")


# ============================================================ persistenza

func save_extra() -> Dictionary:
	return {"nascite": {"ultima": _ultima_nascita, "in_arrivo": _in_arrivo,
			"prime_parole": _prime_parole}}


func load_extra(data: Dictionary) -> void:
	var d: Dictionary = data.get("nascite", {})
	if d.is_empty():
		return
	_ultima_nascita = int(d.get("ultima", -999))
	_in_arrivo = d.get("in_arrivo", {})
	_prime_parole = d.get("prime_parole", {})


# ============================================================ debug CLI

func debug_forza_nascita() -> void:
	var adulti: Array = _visitors.call("adulti_del_villaggio")
	if adulti.size() < 2:
		print("[nascite] servono almeno due adulti")
		return
	var coppia := coppia_migliore(adulti,
			# IL LIBRO MASTRO, non il contatore delle chiacchiere: una nascita
			# viene da gesti veri, e adesso si può dire quali
			func(a, b): return _visitors.call("affetto_fra", a, b),
			func(a, b): return int(_legami.call("figli_della_coppia", a, b)))
	if coppia.is_empty():
		# in debug si forza la prima coppia mista che si trova
		for i in adulti.size():
			for j in range(i + 1, adulti.size()):
				if DNA.sesso(adulti[i][2]) != DNA.sesso(adulti[j][2]):
					coppia = [str(adulti[i][0]), str(adulti[j][0])]
					break
			if not coppia.is_empty():
				break
	if coppia.is_empty():
		print("[nascite] nessuna coppia possibile (tutti dello stesso sesso)")
		return
	var giorno := int(_daynight.get("day"))
	_in_arrivo = {"padre": str(coppia[0]), "madre": str(coppia[1]),
			"seme": hash("%s+%s+%d" % [coppia[0], coppia[1], giorno]),
			"giorno": giorno}
	_annuncia()
	print("[nascite] in arrivo da %s e %s" % [coppia[0], coppia[1]])
