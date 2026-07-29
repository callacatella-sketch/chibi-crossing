extends Node

## IL REGISTRO DEI LAVORI — dare ordini, e guardare in faccia le conseguenze.
##
## Senza questa schermata il sistema dell'animo (scenes/npc/Animo.gd) sarebbe
## invisibile: nessuno potrebbe dare un ordine, quindi nessun rancore potrebbe
## nascere, e soprattutto nessuno potrebbe LEGGERE il perché. Un apparato che
## simula benissimo e non si lascia leggere non è profondo: è rotto.
##
## Perciò il registro fa due cose sole, ed entrambe contano uguale:
##   1. assegnare un lavoro quotidiano a un residente (è il rubinetto da cui
##      scende il risentimento, giorno dopo giorno);
##   2. mostrare, accanto a ogni nome, COME STA e PERCHÉ — con le parole del
##      sistema, non con parole scritte a mano che potrebbero mentire.
##
## La riga «perché» viene da Animo.racconta(): se un domani i numeri cambiano,
## cambia da sola anche la spiegazione. È l'unico modo di non mentire al
## giocatore mentre si bilancia.
##
## Si apre col tasto N (L appartiene al secondo giocatore, vedi
## test_input_map.gd). Niente scelte a scomparsa: tutto quello che serve per
## capire una ribellione è su una schermata sola.

const ANIMO := preload("res://scenes/npc/Animo.gd")
const UI_BROWN := Color("6a4a3a")
const CREMA := Color(1, 0.98, 0.94, 0.96)

## I lavori assegnabili e come si chiamano davanti al giocatore. Le chiavi
## sono quelle che Animo.COMPITI conosce: se qui si scrive un nome che di là
## non esiste, il residente riceverebbe un compito muto — perciò all'apertura
## il registro lo verifica e lo dice, invece di far finta di niente.
const LAVORI := {
	"": "— riposo —",
	"taglia_legna": "Tagliare la legna",
	"coltiva": "Curare l'orto",
	"cucina": "Cucinare",
	"guardia": "Fare la guardia",
	"esplora": "Esplorare il bosco",
	"abbellisce": "Tenere il salone",
	"suona": "Suonare all'anfiteatro",
}
const ORDINE := ["", "taglia_legna", "coltiva", "cucina", "guardia", "esplora",
		"abbellisce", "suona"]

var _visitors: Node
var _player: Node3D
var _daynight: Node
var _sfx
var _layer: CanvasLayer
var _pannello: PanelContainer
var _lista: VBoxContainer
var _titolo: Label
var _aperto := false
var _sel := 0
## label del residente -> lavoro assegnato
var _incarichi := {}
## Le giornate SCELTE: label -> compito che il residente si è dato da sé,
## il mattino, perché nessuno gliene aveva dato uno. Non si salvano: sono
## la giornata di oggi, e domani decide di nuovo.
var _scelte := {}


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("lavori")
	_sfx = get_node_or_null(^"/root/Sfx")
	_costruisci_ui()
	(func() -> void:
		_visitors = get_node_or_null("../Visitors")
		_player = get_node_or_null("../Player")
		_daynight = get_node_or_null("../DayNight")
		if _daynight and _daynight.has_signal("day_changed"):
			_daynight.day_changed.connect(_on_nuovo_giorno)
	).call_deferred()


# ---------------------------------------------------------------- la giornata

## Ogni mattina i residenti fanno il lavoro che gli hai dato. È QUI che il
## rancore scende goccia a goccia: nessun evento drammatico, solo il
## quarantesimo giorno uguale al primo.
func _on_nuovo_giorno(_giorno: int) -> void:
	if _visitors == null or not _visitors.has_method("assegna_compito"):
		return
	for label in _incarichi:
		var lavoro := str(_incarichi[label])
		if lavoro == "":
			continue
		_visitors.assegna_compito(label, lavoro)
	_scelte_di_giornata()
	_produzione_del_giorno()
	if _aperto:
		_riempi()


## LE GIORNATE LIBERE. Chi non ha un incarico non sta con le zampe in
## mano: sceglie da sé cosa fare, e lo sceglie col suo animo —
## `Animo.decide` pesa quanto un compito allevia ciò che gli sta
## pesando ADESSO, quanto lo avvicina al sogno che ha, quante volte
## quella cosa lo ha già stancato. (Il motore c'era da sempre, con la
## sua scelta pesata e il suo test; non lo chiamava nessuno, e i vicini
## senza incarico non facevano nulla di loro iniziativa.)
##
## La differenza che conta: una giornata SCELTA non fa scendere il
## rancore. Non ci si ribella al proprio lavoro — ci si ribella a
## quello che ti hanno imposto.
func _scelte_di_giornata() -> void:
	_scelte.clear()
	for r in (_visitors.get("_residents") as Array):
		var label := str(r.get("label", ""))
		if label == "" or _incarichi.has(label):
			continue
		# chi sta ancora crescendo non sceglie un mestiere: non è un
		# lavoratore svogliato, è un bambino (vedi Nascite.gd)
		if bool(_visitors.call("e_cucciolo", label)):
			continue
		var animo: RefCounted = _visitors.call("animo_oggetto_di", label)
		if animo == null:
			continue
		# "se_stesso" e non "giocatore": è una scelta sua, e nel ricordo
		# resterà così — non gliel'ha chiesta nessuno
		var scelta := str(animo.decide(ANIMO.COMPITI.keys(), "se_stesso"))
		if scelta == "":
			continue
		_scelte[label] = scelta
		_visitors.assegna_compito(label, scelta)


# ------------------------------------------------------- la produzione

## La resa di una giornata di lavoro, da 0 (niente) a oltre 1 (il bonus di
## chi fa il lavoro che SOGNAVA: x1.5). È la faccia economica della scala
## della ribellione: il rancore non è più solo un costo morale, è
## produzione che cala — svogliato lavora a metà, chi "perde gli attrezzi"
## combina un terzo, dal rifiuto in poi non si produce nulla. PURA e
## statica: la scala si interroga per NOME (mai indici a mano).
static func resa(gradino: String, sogno := "", lavoro := "") -> float:
	if ANIMO.almeno(ANIMO.indice(gradino), "rifiuto"):
		return 0.0
	var base := 1.0
	match gradino:
		"svogliato":
			base = 0.55
		"attrezzi":
			base = 0.35
	var serve := str((ANIMO.COMPITI.get(lavoro, {}) as Dictionary).get("serve", ""))
	if serve != "" and serve == sogno:
		base *= 1.5
	return base


## Quanti pezzi escono da una giornata a resa `r`, su una base piena di
## `n_pieno` (es. 2 legna): 3 col sogno giusto, 2 sereno, 1 svogliato o
## distratto, 0 in rivolta.
static func quanti(n_pieno: int, r: float) -> int:
	return roundi(float(n_pieno) * r)


## I lavori PRODUCONO: legna in catasta, aiuole annaffiate, un piatto in
## tavola, ogni tanto un tesoro dal bosco. Senza questo, dare ordini era
## solo un rubinetto di rancore senza guadagno — la scala più bella del
## gioco puniva un comportamento privo di incentivo. Ora sfruttare i
## residenti RENDE, ed è proprio per questo che costa: «lo faccio lavorare
## o lo lascio sognare?» è un conto che si fa guardando il registro.
func _produzione_del_giorno() -> void:
	var woodcutting := get_node_or_null("../Woodcutting")
	var garden := get_node_or_null("../Garden")
	var cooking := get_node_or_null("../Cooking")
	var inventory := get_node_or_null("../Inventory")
	var veglia := get_tree().get_first_node_in_group("veglia")
	var salone := get_tree().get_first_node_in_group("salone")
	var concerto := get_tree().get_first_node_in_group("concerto")
	var legna := 0
	var lanterne := 0
	var al_buio := 0
	var annaffiate := 0
	var piatti: Array[String] = []
	var tesori := 0
	var abbelliti: Array[String] = []
	var applausi := 0
	var brano := ""
	for label in _incarichi:
		var lavoro := str(_incarichi[label])
		var gradino := str(_visitors.animo_di(label))
		if lavoro == "" or gradino == "":
			continue   # assente, o già andato via: non produce
		var r := resa(gradino, str(_visitors.sogno_di(label)), lavoro)
		if r <= 0.0:
			continue
		match lavoro:
			"taglia_legna":
				if woodcutting:
					var n := quanti(2, r)
					woodcutting.add_wood(n)
					legna += n
			"coltiva":
				if garden:
					for i in quanti(2, r):
						var bed = garden.bed_needing_water(Vector3.ZERO, 999.0)
						if bed == null:
							break
						garden.villager_water(bed)
						annaffiate += 1
			"cucina":
				# sotto mezza resa il mestolo resta appeso (niente piatto)
				if cooking and r >= 0.5:
					var piatto := str(cooking.cook_by_villager())
					if piatto != "":
						piatti.append(piatto)
			"guardia":
				# LA GUARDIA NON PRODUCE COSE: produce il sonno degli altri.
				# La ronda della sera ha gia' acceso le sue lanterne (una per
				# tappa, quante lo decide questa stessa `resa`); qui si
				# raccoglie cio' che la notte ha lasciato — la sicurezza
				# donata a chi ha dormito, il credito verso chi ha vegliato.
				# Il conto lo fa la Veglia, che sa dov'erano le luci.
				if veglia:
					var esito: Dictionary = veglia.call("rendiconto_del_mattino")
					lanterne += int(esito.get("lanterne", 0))
					al_buio += int(esito.get("al_buio", 0))
			"abbellisce":
				# IL SALONE NON PRODUCE COSE: produce FACCE NUOVE. Chi lo
				# tiene passa la giornata a cambiare l'aspetto dei vicini,
				# uno al giorno, e la resa dice solo se ci e' riuscito —
				# il lavoro vero (la seduta, la poltrona, lo specchio) lo
				# recita Salone.gd, che e' anche l'unico a sapere COSA e'
				# cambiato. Sotto mezza resa il salone resta chiuso.
				if salone and r >= 0.5:
					var chi := str(salone.call("servito_oggi"))
					if chi != "":
						abbelliti.append(chi)
			"suona":
				# IL PALCO NON PRODUCE COSE: produce una sera che il
				# villaggio ha passato insieme. La resa dice solo se il
				# concerto c'e' stato — chi si e' seduto, che brano era e
				# quanto e' durato lo sa Concerto.gd, che e' la scena.
				# Sotto mezza resa non si sale sul palco: si prova e basta.
				if concerto and r >= 0.5:
					var quanti := int(concerto.call("ascoltatori_di_oggi"))
					if quanti > applausi:
						applausi = quanti
						brano = str(concerto.call("titolo_di_oggi"))
			"esplora":
				if inventory and randf() < 0.45 * r:
					var ids: Array = inventory.TREASURES.keys()
					var scheda: Dictionary = inventory.add_treasure(str(ids[randi() % ids.size()]))
					if not scheda.is_empty():
						tesori += 1
	_racconta_produzione(legna, annaffiate, piatti, tesori, lanterne, al_buio,
			abbelliti, applausi, brano)


# Una riga sola al mattino, e solo se c'è davvero qualcosa da dire: il
# guadagno deve essere VISIBILE, o il dilemma non esiste.
func _racconta_produzione(legna: int, annaffiate: int, piatti: Array[String],
		tesori: int, lanterne := 0, al_buio := 0,
		abbelliti: Array[String] = [], applausi := 0, brano := "") -> void:
	var parti: Array[String] = []
	if legna > 0:
		parti.append(L10n.tf("+%d legna in catasta", [legna]))
	if annaffiate > 0:
		parti.append(L10n.tf("%d aiuole annaffiate", [annaffiate]) if annaffiate > 1 \
				else L10n.t("un'aiuola annaffiata"))
	for p in piatti:
		parti.append(L10n.tf("in tavola: %s", [p.to_lower()]))
	if tesori > 0:
		parti.append(L10n.tf("%d tesori dal bosco", [tesori]) if tesori > 1 \
				else L10n.t("un tesoro dal bosco"))
	# la resa del salone si dice col NOME di chi e' cambiato: e' l'unico
	# guadagno del villaggio che si vede addosso a qualcuno
	for chi in abbelliti:
		parti.append(L10n.tf("%s esce dal salone tutto nuovo", [chi]))
	# la resa del palco si dice col TITOLO: un concerto senza nome sarebbe
	# stato solo rumore
	if applausi > 0:
		if brano != "":
			parti.append(L10n.tf("ieri sera «%s», e %d ad applaudire",
					[brano, applausi]))
		else:
			parti.append(L10n.tf("%d vicini hanno ascoltato il concerto", [applausi]))
	if lanterne > 0:
		parti.append(L10n.tf("%d lanterne accese sulla ronda", [lanterne]) if lanterne > 1 \
				else L10n.t("una lanterna accesa sulla ronda"))
	# il buio non e' una punizione e non si scrive in rosso: e' una riga
	# sola, detta come la direbbe un vicino che ha dormito male
	if al_buio > 0 and lanterne == 0:
		parti.append(L10n.tf("che buio, stanotte, dalle parti di %d case", [al_buio]) \
				if al_buio > 1 else L10n.t("che buio, stanotte"))
	if parti.is_empty():
		return
	if _visitors and _visitors.has_method("_show_toast"):
		_visitors.call("_show_toast",
				L10n.tf("Il lavoro del mattino: %s", [" · ".join(parti)]))
	var bs := get_tree().get_first_node_in_group("build_system")
	if bs and bs.has_method("request_save"):
		bs.request_save()


## Chi ha oggi questo incarico (la sua LABEL), o "" se nessuno.
## La usa la Veglia per sapere se stanotte c'è qualcuno che fa la ronda.
func chi_fa(lavoro: String) -> String:
	for label in _incarichi:
		if str(_incarichi[label]) == lavoro:
			return str(label)
	return ""


## Assegna (o toglie) un lavoro. Chiamabile anche dai test e dalla CLI.
func assegna(label: String, lavoro: String) -> void:
	if lavoro != "" and not LAVORI.has(lavoro):
		push_warning("Lavori: lavoro sconosciuto '%s'" % lavoro)
		return
	if lavoro == "":
		_incarichi.erase(label)
	else:
		_incarichi[label] = lavoro
	# l'incarico va su disco appena dato: lo stato su disco riflette sempre
	# quello reale. request_save() e' l'API pubblica (accorpa a una scrittura
	# per frame); la guardia serve ai test puri, dove il registro vive fuori
	# dall'albero di scena.
	if is_inside_tree():
		var bs := get_tree().get_first_node_in_group("build_system")
		if bs and bs.has_method("request_save"):
			bs.request_save()


func incarico(label: String) -> String:
	return str(_incarichi.get(label, ""))


# ---------------------------------------------------------------- la finestra

func _costruisci_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 12
	add_child(_layer)

	_pannello = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREMA
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(20)
	sb.shadow_color = Color(0.3, 0.2, 0.15, 0.3)
	sb.shadow_size = 18
	_pannello.add_theme_stylebox_override("panel", sb)
	_pannello.visible = false
	_pannello.set_anchors_preset(Control.PRESET_CENTER)
	_pannello.anchor_left = 0.5
	_pannello.anchor_right = 0.5
	_pannello.anchor_top = 0.5
	_pannello.anchor_bottom = 0.5
	_pannello.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pannello.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pannello.custom_minimum_size = Vector2(720, 0)
	_pannello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_pannello)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_pannello.add_child(box)

	_titolo = Label.new()
	_titolo.text = L10n.t("Il registro dei lavori")
	_titolo.add_theme_font_size_override("font_size", 26)
	_titolo.add_theme_color_override("font_color", UI_BROWN)
	box.add_child(_titolo)

	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 14)
	box.add_child(_lista)

	var aiuto := Label.new()
	aiuto.text = L10n.t("↑↓ scegli il residente   ←→ cambia il suo lavoro   ·   N chiude")
	aiuto.add_theme_font_size_override("font_size", 14)
	aiuto.add_theme_color_override("font_color", Color(UI_BROWN, 0.7))
	box.add_child(aiuto)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("lavori"):
		_toggle()
		get_viewport().set_input_as_handled()
		return
	if not _aperto:
		return
	var righe: Array = _residenti()
	if righe.is_empty():
		return
	# un residente può partire col registro aperto (il mondo gira, congela
	# solo Mochi): senza clamp, righe[_sel] andrebbe fuori range
	_sel = clampi(_sel, 0, righe.size() - 1)
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		var passo := 1 if event.is_action_pressed("ui_down") else -1
		_sel = posmod(_sel + passo, righe.size())
		if _sfx:
			_sfx.ui_select()
		_riempi()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_left"):
		var passo2 := 1 if event.is_action_pressed("ui_right") else -1
		var label := str(righe[_sel].get("label", ""))
		var i: int = ORDINE.find(incarico(label))
		assegna(label, str(ORDINE[posmod(i + passo2, ORDINE.size())]))
		if _sfx:
			_sfx.rotate_tick()
		_riempi()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	if not _aperto:
		# come tutti gli altri pannelli: non rubare la scena a un menu già
		# aperto, e CONGELA Mochi. La navigazione usa ui_up/down/left/right,
		# che includono WASD, e il PlayerController legge l'input in polling:
		# senza congelamento sfogliare il registro faceva camminare Mochi.
		if _player == null or not _player.is_physics_processing():
			return
		_aperto = true
		_player.set_physics_process(false)
		_player.velocity = Vector3.ZERO
		_pannello.visible = true
		_sel = 0
		_riempi()
		if _sfx:
			_sfx.build_open()
	else:
		_aperto = false
		_pannello.visible = false
		if _player and not _player.is_physics_processing():
			_player.set_physics_process(true)
		if _sfx:
			_sfx.build_close()


func is_open() -> bool:
	return _aperto


func _residenti() -> Array:
	if _visitors == null:
		return []
	var out: Array = []
	for r in (_visitors.get("_residents") as Array):
		if r is not Dictionary or str(r.get("label", "")) == "":
			continue
		# nel registro dei lavori i cuccioli non compaiono affatto:
		# nessuno deve poter assegnare la catasta a un bambino
		if bool(_visitors.call("e_cucciolo", str(r.get("label", "")))):
			continue
		out.append(r)
	return out


# Riempie il registro. Ogni riga è: chi è, che sogno ha, cosa gli hai dato da
# fare, come sta — e PERCHÉ sta così. La riga del perché è la sola ragione
# per cui questa schermata esiste.
func _riempi() -> void:
	for c in _lista.get_children():
		c.queue_free()
	var righe: Array = _residenti()
	if righe.is_empty():
		var vuoto := Label.new()
		vuoto.text = L10n.t("Non c'è ancora nessuno in paese.")
		vuoto.add_theme_color_override("font_color", UI_BROWN)
		_lista.add_child(vuoto)
		return
	_sel = clampi(_sel, 0, righe.size() - 1)

	for i in righe.size():
		var label := str(righe[i].get("label", ""))
		var riga := VBoxContainer.new()
		riga.add_theme_constant_override("separation", 2)
		_lista.add_child(riga)

		var testa := Label.new()
		var stato := ""
		if _visitors.has_method("animo_di"):
			stato = str(_visitors.animo_di(label))
		var freccia := "▸ " if i == _sel else "   "
		var corpo := ""
		if _visitors.has_method("corpo_di"):
			corpo = str(_visitors.corpo_di(label))
		# il corpo si scrive solo quando ha qualcosa da dire: «tranquillo» a
		# fianco di ogni nome sarebbe rumore
		var coda := "" if corpo == "" or corpo == "tranquillo" \
				else "   ·   %s" % L10n.t(corpo)
		testa.text = "%s%s   —   %s   ·   %s%s" % [
				freccia, label, L10n.t(str(LAVORI.get(incarico(label), "—"))),
				L10n.t(_stato_umano(stato)), coda]
		testa.add_theme_font_size_override("font_size", 18)
		testa.add_theme_color_override("font_color",
				_colore_stato(stato) if i == _sel else Color(UI_BROWN, 0.75))
		riga.add_child(testa)

		# il PERCHÉ, con le parole del sistema: solo per chi è selezionato,
		# o la schermata diventa un muro di testo che nessuno legge
		if i == _sel and _visitors.has_method("perche"):
			var perche := Label.new()
			var testo_perche := "     " + str(_visitors.perche(label))
			if _visitors.has_method("luoghi_evitati"):
				var evitati: Array = _visitors.luoghi_evitati(label)
				if not evitati.is_empty():
					# una deviazione senza spiegazione sembra un difetto di
					# percorso: qui il giocatore scopre che è una ferita
					var nomi := PackedStringArray()
					for e in evitati:
						nomi.append(L10n.t(str(e)))
					testo_perche += "  ·  " + L10n.tf("gira al largo da: %s",
							[", ".join(nomi)])
			perche.text = testo_perche
			perche.add_theme_font_size_override("font_size", 14)
			perche.add_theme_color_override("font_color", Color(UI_BROWN, 0.85))
			perche.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			perche.custom_minimum_size = Vector2(660, 0)
			riga.add_child(perche)


# La scala in parole che il giocatore capisce al volo, senza dover imparare
# il vocabolario interno del sistema.
## Tabella (non `match`) indicizzata per NOME del gradino: così un test può
## verificare che copra tutta ANIMO.SCALA. Col `match` un gradino nuovo
## cadeva sul fallback "sereno" senza che nulla se ne accorgesse — e il
## pannello etichettava "sereno" un chibi che il colore mostrava già in
## rivolta (vedi test_fonti_uniche).
const STATO_UMANO := {
	"lavoro": "sereno",
	"svogliato": "svogliato",
	"attrezzi": "distratto, perde gli attrezzi",
	"rifiuto": "si rifiuta",
	"sabotaggio": "qualcosa non torna…",
	"confronto": "vuole parlarti",
	"diserzione": "sta per andarsene",
	"ammutinamento": "non ti ascolta più",
}


func _stato_umano(gradino: String) -> String:
	return str(STATO_UMANO.get(gradino, "sereno"))


func _colore_stato(gradino: String) -> Color:
	# l'indice del gradino lo dice Animo: qui non si riscrive la scala
	var i := ANIMO.indice(gradino)
	if i <= 0:
		return UI_BROWN
	# dal marrone al corallo man mano che si scende la scala
	return UI_BROWN.lerp(Color("c2452f"), ANIMO.frazione(i))


# ---------------------------------------------------------------- salvataggio

func save_extra() -> Dictionary:
	return {"incarichi": _incarichi.duplicate()}


func load_extra(data: Dictionary) -> void:
	_incarichi = (data.get("incarichi", {}) as Dictionary).duplicate()
