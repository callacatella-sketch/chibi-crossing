class_name CozySettingsPanel
extends PanelContainer

## Il pannello Impostazioni, condiviso tra il menu di pausa e la schermata del
## titolo. Legge e scrive l'autoload Settings; ogni modifica si applica e si
## salva all'istante. Emette `closed` quando si torna indietro.

signal closed

var _settings: Node
var _col: VBoxContainer
var _note: NoteLegali
var _offerta: OffertaModello
## Questo pannello si è già condannato a essere rifatto a fine frame? Vedi
## `_ricostruisci()`: è la bandiera che rende visibile alla suite una
## `call_deferred` che, dentro un caso di test, non si esegue mai.
var _rifacimento_in_coda := false


func _ready() -> void:
	_settings = get_node_or_null(^"/root/Settings")
	add_theme_stylebox_override("panel", CozyUI.paper_panel(28))
	custom_minimum_size = Vector2(520, 0)
	_build()


func _build() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	_col = col

	col.add_child(CozyUI.title_label(L10n.t("Impostazioni"), 30))
	col.add_child(_sep())

	# la lingua per prima: chi apre le impostazioni perché il gioco parla
	# una lingua che non capisce deve trovarla subito, in cima
	col.add_child(_language_row())
	col.add_child(_sep())

	col.add_child(_slider_row("Volume generale", "master_volume", 0.0, 1.0, 0.05,
			CozyUI.HONEY, func(v): _settings.set_master_volume(v)))
	col.add_child(_slider_row("Musica", "music_volume", 0.0, 1.0, 0.05,
			CozyUI.SKY, func(v): _settings.set_music_volume(v)))
	col.add_child(_slider_row("Effetti", "sfx_volume", 0.0, 1.0, 0.05,
			CozyUI.MINT, func(v): _settings.set_sfx_volume(v)))
	# le VOCI stanno sotto «Effetti» (il loro bus è figlio di quello), ma
	# hanno il cursore loro: il villaggio parla di continuo, e c'è chi
	# vuole il chiacchiericcio più discreto senza perdere passi e porte
	col.add_child(_slider_row("Voci", "voci_volume", 0.0, 1.0, 0.05,
			CozyUI.GOLD, func(v): _settings.set_voci_volume(v)))
	col.add_child(_sep())
	col.add_child(_slider_row("Velocità di Mochi", "move_speed", 0.6, 1.5, 0.05,
			CozyUI.PINK, func(v): _settings.set_move_speed(v)))
	col.add_child(_toggle_row("Schermo intero", "fullscreen",
			func(on): _settings.set_fullscreen(on)))
	col.add_child(_toggle_row("Riduci animazioni", "reduce_motion",
			func(on): _settings.set_reduce_motion(on)))
	# «Prato Eterno»: nessun vicino parte mai per il Grande Prato — il
	# gioco resta intero anche senza (regola cozy del Filo Rosso)
	col.add_child(_toggle_row("Prato Eterno (nessuna partenza)", "prato_eterno",
			func(on): _settings.set_prato_eterno(on)))
	# «Il villaggio pensa»: la leva del cuore che scrive. La riga c'è SOLO se
	# c'è qualcosa da spegnere — vedi `Llm.leva_visibile()`.
	if _llm_row_visibile():
		col.add_child(_llm_row())
	if _settings and _settings.quality_available():
		col.add_child(_quality_row())

	col.add_child(_sep())
	# «NOTE LEGALI» — l'ultima riga prima di Indietro, e non e' burocrazia:
	# le licenze dei componenti di terze parti CHIEDONO che i loro avvisi
	# viaggino col gioco, e i Gemma Terms of Use (Sezione 3.1) chiedono che
	# chi riceve il gioco sia informato dei vincoli d'uso. I file stanno
	# accanto all'eseguibile — ma li' non li apre nessuno, e su macOS sono
	# dentro il bundle. Questa e' la porta che li rende leggibili davvero.
	col.add_child(_note_legali_row())

	var back := CozyUI.cozy_button(L10n.t("Indietro"), CozyUI.PINK, 18)
	back.custom_minimum_size = Vector2(200, 52)
	back.pressed.connect(func(): closed.emit())
	# «wrap» e' una funzione del linguaggio: chiamarci una variabile la
	# nasconde dentro tutto il blocco
	var centro := CenterContainer.new()
	centro.add_child(back)
	col.add_child(centro)


# ------------------------------------------------------------ note legali
## Il bottone, e la pagina che apre. La pagina si costruisce **la prima volta
## che serve**: e' un ScrollContainer con dentro il testo di quattro licenze,
## e chi apre le impostazioni per alzare il volume non deve pagarla.
func _note_legali_row() -> Control:
	var b := CozyUI.cozy_button(L10n.t("Note legali"), CozyUI.LAVENDER, 15)
	b.custom_minimum_size = Vector2(200, 42)
	b.pressed.connect(_apri_note)
	var centro := CenterContainer.new()
	centro.add_child(b)
	return centro


func _apri_note() -> void:
	if _note == null:
		_note = NoteLegali.new()
		add_child(_note)
		_note.incorpora()
		_note.closed.connect(_chiudi_note)
	_note.riparti()
	_note.visible = true
	_col.visible = false


func _chiudi_note() -> void:
	if _note:
		_note.visible = false
	_col.visible = true


# ---------------------------------------------------------------- righe
func _slider_row(label: String, key: String, lo: float, hi: float, step: float,
		accent: Color, setter: Callable) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	# le etichette passano da L10n QUI, in un punto solo: sui sette punti
	# di chiamata era già successo di dimenticarsene, e il pannello
	# restava in italiano dentro un gioco che parlava inglese
	var l := CozyUI.body_label(L10n.t(label), 17)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var val := CozyUI.body_label("", 15, CozyUI.INK_SOFT)
	head.add_child(val)
	row.add_child(head)

	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(_settings.get(key)) if _settings else hi
	s.custom_minimum_size = Vector2(0, 26)
	_style_slider(s, accent)
	var pct := func(v: float) -> String:
		return "%d%%" % roundi((v - lo) / (hi - lo) * 100.0)
	val.text = pct.call(s.value)
	s.value_changed.connect(func(v):
		val.text = pct.call(v)
		if _settings: setter.call(v))
	row.add_child(s)
	return row


func _toggle_row(label: String, key: String, setter: Callable) -> Control:
	return _toggle_riga(label, bool(_settings.get(key)) if _settings else false, setter)


## La riga vera, con lo stato iniziale PASSATO invece che letto da una chiave.
## Serve a «Il villaggio pensa», il cui bit salvato è il contrario di quello
## che la casella mostra (`llm_spento`): il verso si gira in un posto solo,
## dentro `Settings.set_llm_acceso()`, e qui arriva già dritto.
func _toggle_riga(label: String, acceso: bool, setter: Callable) -> Control:
	var row := HBoxContainer.new()
	var l := CozyUI.body_label(L10n.t(label), 17)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var cb := CheckButton.new()
	cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = acceso
	cb.add_theme_color_override("font_color", CozyUI.INK)
	cb.toggled.connect(func(on):
		if _settings: setter.call(on))
	row.add_child(cb)
	return row


## ────────────────────────────────────────────────────────────────────────
## «IL VILLAGGIO PENSA» — l'unica riga del pannello che a volte non c'è
## ────────────────────────────────────────────────────────────────────────
##
## La condizione è `Llm.disponibile()`: **questo binario sa scrivere.** La
## riga c'è quando c'è qualcosa da scegliere, e da quando il modello non
## viaggia più dentro il pacchetto (2026-08-13) c'è qualcosa da scegliere per
## tutti loro — chi ha i pesi può spegnerli, chi non li ha può averli.
##
## ⚠️ **NON È PIÙ `Llm.leva_visibile()`, e la differenza è tutto il senso di
## questa riga.** Quella domanda («c'è qualcosa da SPEGNERE?») è vera solo col
## file già sul disco: con lei, adesso, la riga non comparirebbe a nessuno —
## e la funzione sarebbe irraggiungibile per chiunque, per sempre, con la
## suite verde. Prima il ragionamento era l'opposto (mostrarla a chi non ha i
## pesi gli racconta che gli manca un pezzo), ed era giusto **finché non c'era
## modo di averli**: una porta chiusa a chiave è una mancanza, una porta che
## si apre è una scelta.
##
## Per lo stesso motivo qui non c'è nessuna casella ingrigita: **o la riga
## c'è, o non esiste.**
##
## E non nomina nessuna macchina. Chi gioca non deve sapere cos'è un modello
## linguistico per decidere se vuole che i suoi vicini abbiano idee loro; gli
## serve sapere tre cose, e sono quelle scritte sotto la casella: cosa fa,
## cosa costa, e da quando vale.
func _llm_row_visibile() -> bool:
	return Llm.disponibile()


## LA CASELLA MOSTRA LA VERITÀ, NON IL BIT. Quello che dice è «il villaggio
## pensa?», e la risposta è `Llm.acceso()` — che è falsa anche quando il bit
## è acceso ma i pesi non ci sono. Mostrare il bit vorrebbe dire una casella
## spuntata sopra un villaggio che non pensa: il valore di serie di
## `llm_spento` è `false`, quindi la casella nascerebbe **accesa** per
## chiunque non abbia mai scaricato niente.
func _llm_row() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var in_casa := Llm.modello_in_casa()
	col.add_child(_toggle_riga("Il villaggio pensa", Llm.acceso(), _llm_toggled))
	var nota := CozyUI.body_label(L10n.t(
			"Ogni tanto un vicino ha un'idea tutta sua. Chiede memoria al computer, e cambia dal prossimo avvio."
			if in_casa else
			"Ogni tanto un vicino ha un'idea tutta sua. Per farlo il gioco ha bisogno di scaricare una cosa, una volta sola: prima te lo chiede."),
			13, CozyUI.INK_SOFT)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(nota)
	return col


## Il gesto sulla casella. Con i pesi in casa è la leva di sempre; senza, è
## una **domanda**, e la domanda la fa `OffertaModello`.
##
## ⚠️ **ACCENDERE SENZA I PESI NON SCRIVE IL BIT.** Se lo scrivesse, chi apre
## la pagina e dice «non adesso» si porterebbe a casa una preferenza che non
## ha espresso — e la casella resterebbe spuntata sopra un villaggio che non
## pensa, che è la bugia che questa riga esiste per non dire. Il bit lo
## accende `OffertaModello`, quando il file è arrivato davvero.
func _llm_toggled(on: bool) -> void:
	if Llm.modello_in_casa():
		if _settings:
			_settings.set_llm_acceso(on)
		return
	# ⚠️ **SI APRE, OPPURE SI RICOSTRUISCE: MAI TUTTE E DUE.** `_ricostruisci()`
	# butta TUTTI i figli del pannello a fine frame, e da quando la pagina
	# dello scaricamento è uno di quei figli, chiamarla dopo `_apri_offerta()`
	# vuol dire crearla, mostrarla e liberarla nello stesso gesto: la pagina
	# compariva e spariva un fotogramma dopo, e **la funzione era
	# irraggiungibile dall'interfaccia per chiunque** — con la suite verde,
	# perché i casi di `test_offerta_modello` costruiscono `OffertaModello`
	# per conto loro e non passano mai di qui. MISURATO col pannello vero:
	# `_offerta` è un `PanelContainer` vivo e visibile nel frame del gesto, e
	# `<null>` al frame successivo.
	#
	# Il ritorno non salta nessun rinfresco: la casella la rimette a posto
	# `_chiudi_offerta`, che ricostruisce quando la pagina si chiude — cioè
	# quando c'è di nuovo un pannello da guardare.
	if on:
		_apri_offerta()
		return
	_ricostruisci()


func _apri_offerta() -> void:
	if _offerta == null:
		_offerta = OffertaModello.new()
		add_child(_offerta)
		_offerta.incorpora()
		_offerta.closed.connect(_chiudi_offerta)
	_offerta.riparti()
	_offerta.visible = true
	_col.visible = false


func _chiudi_offerta() -> void:
	if _offerta:
		_offerta.visible = false
	_col.visible = true
	_ricostruisci()


## La riga della lingua. I nomi delle lingue NON si traducono mai
## ("Italiano" si scrive così anche in inglese): chi cerca la propria
## lingua la deve riconoscere anche senza capire il resto della schermata.
## Scelta la lingua, il pannello si RICOSTRUISCE all'istante: il giocatore
## vede subito l'effetto, senza dover riaprire nulla.
func _language_row() -> Control:
	var row := HBoxContainer.new()
	var l := CozyUI.body_label(L10n.t("Lingua"), 17)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var g := ButtonGroup.new()
	var cur := str(_settings.language_code()) if _settings else L10n.SORGENTE
	for codice in L10n.LINGUE:
		var b := CozyUI.tab_button(str(L10n.LINGUE[codice]), g, CozyUI.MINT)
		b.custom_minimum_size = Vector2(110, 40)
		if codice == cur:
			b.set_pressed_no_signal(true)
		b.pressed.connect(func() -> void:
			if _settings == null:
				return
			_settings.set_language(codice)
			_ricostruisci())
		row.add_child(b)
	return row


# rifà il pannello (una sola volta, a fine frame: si sta ricostruendo
# l'albero da dentro il segnale di un bottone che gli appartiene)
#
# ⚠️ **LE DUE PAGINE FIGLIE SI DIMENTICANO**, o restano due riferimenti a
# nodi liberati: `_note` e `_offerta` sono figli come gli altri e vengono
# buttati qui dentro, ma `_apri_note`/`_apri_offerta` li riusano se «non sono
# null» — e un'istanza liberata assegnata a una variabile TIPIZZATA non è
# null, è un errore che scatta prima di qualunque guardia (è la lezione dei
# festoni). Prima del 2026-08-13 si arrivava qui solo cambiando lingua, e il
# guasto era una porta stretta: cambia lingua, apri le Note legali, crolla.
# Adesso si ricostruisce a ogni chiusura della pagina dello scaricamento.
#
# ⚠️ **E IL RIFACIMENTO SI VEDE PRIMA DI ACCADERE** (`_rifacimento_in_coda`).
# Non è una comodità: è l'UNICO modo in cui la suite può accorgersi di un
# rifacimento chiesto per sbaglio. Il runner fa girare un caso per
# fotogramma, dentro un caso non passa nessun frame, e una `call_deferred`
# perciò non si esegue MAI mentre le asserzioni guardano: un pannello che si
# è appena condannato da solo è indistinguibile da uno sano. È così che «la
# pagina dello scaricamento si apre e sparisce un frame dopo» è vissuto con
# 66322 asserzioni verdi. La bandiera rende la condanna un fatto osservabile
# nell'istante in cui viene chiesta — e la spegne solo chi il rifacimento lo
# esegue davvero.
func _ricostruisci() -> void:
	_rifacimento_in_coda = true
	_rifai_adesso.call_deferred()


## Il corpo del rifacimento, con un nome suo perché abbia un chiamante che
## non sia soltanto la coda differita (è l'idioma di `_apparecchia` in
## `test_salvataggio_finestra`: quello che il motore farebbe a fine frame, un
## banco lo fa a mano e nello stesso ordine).
func _rifai_adesso() -> void:
	_rifacimento_in_coda = false
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_note = null
	_offerta = null
	_build()


func _quality_row() -> Control:
	var row := HBoxContainer.new()
	var l := CozyUI.body_label(L10n.t("Qualità grafica"), 17)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var g := ButtonGroup.new()
	var cur := int(_settings.get_quality()) if _settings else 0
	for i in 2:
		var b := CozyUI.tab_button(L10n.t("Basso" if i == 0 else "Alto"), g, CozyUI.SKY)
		b.custom_minimum_size = Vector2(96, 40)
		if i == cur:
			b.set_pressed_no_signal(true)
		b.pressed.connect(func():
			if _settings: _settings.set_quality(i))
		row.add_child(b)
	return row


func _style_slider(s: HSlider, accent: Color) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.84, 0.79, 0.7, 0.7)
	track.set_corner_radius_all(6)
	track.content_margin_top = 5.0
	track.content_margin_bottom = 5.0
	s.add_theme_stylebox_override("slider", track)
	var area := StyleBoxFlat.new()
	area.bg_color = accent
	area.set_corner_radius_all(6)
	s.add_theme_stylebox_override("grabber_area", area)
	s.add_theme_stylebox_override("grabber_area_highlight", area)


func _sep() -> Control:
	var s := HSeparator.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(CozyUI.PAPER_EDGE, 0.25)
	sb.content_margin_top = 1.0
	sb.content_margin_bottom = 1.0
	s.add_theme_stylebox_override("separator", sb)
	return s
