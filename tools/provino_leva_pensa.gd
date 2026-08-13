extends SceneTree

## IL PROVINO DELLA LEVA — «Il villaggio pensa», la riga che a volte non c'è.
##
##     CHIBI_LEVA=/tmp/leva ~/Downloads/Godot.app/Contents/MacOS/Godot \
##         --path . --resolution 1280x800 --script res://tools/provino_leva_pensa.gd
##
## `test_llm_spedito.gd` prova che la riga compaia quando deve. Non può dire
## come si LEGGE: se la nota sotto la casella sta dentro il pannello, se
## l'inglese — che è più lungo dell'italiano — la fa uscire, se la riga si
## confonde con «Prato Eterno» che le sta sopra. Questa roba si guarda.
##
## Tre scene, e la terza è quella che il provino esiste per fotografare:
##  1. la leva ACCESA (com'è di serie per chi ha il modello);
##  2. la leva SPENTA (com'è dopo che il giocatore l'ha tolta);
##  3. la stessa pagina in INGLESE, dove la nota è più lunga di due parole.
##
## ⚠️ **LA QUARTA SCENA NON SI PUÒ FARE IN QUESTA CORSA**, e non è una
## dimenticanza: la riga c'è se `Llm.leva_visibile()` — cioè se il BINARIO sa
## scrivere e un modello c'è — e nessuna delle due cose si finge da dentro il
## processo. Il pannello di chi non ha niente si fotografa rifacendo questo
## provino sul binario `llm=no`, ed è il confronto che conta: **o la riga c'è,
## o non esiste**, e nessuna casella ingrigita insegna a chi gioca che gli
## manca un pezzo.
##
## ⚠️ **NIENTE `--headless`**: senza rendering non c'è niente da guardare.

const LLM := preload("res://systems/Llm.gd")

var _dove := ""
var _passo := 0
var _atteso := 0
var _radice: CenterContainer
var _pannello: CozySettingsPanel


func _init() -> void:
	_dove = OS.get_environment("CHIBI_LEVA")
	if _dove == "":
		_dove = "/tmp/leva_pensa"
	DirAccess.make_dir_recursive_absolute(_dove)
	print("[provino] le foto vanno in ", _dove)
	print("[provino] %s" % LLM.riga_di_stato())
	print("[provino] modello: %s"
			% (LLM.percorso_modello() if LLM.percorso_modello() != "" else "(nessuno)"))
	print("[provino] Llm.leva_visibile() = %s" % str(LLM.leva_visibile()))

	var sfondo := ColorRect.new()
	sfondo.color = Color("cfe4d0")
	sfondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(sfondo)
	_radice = CenterContainer.new()
	_radice.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_radice)


func _process(_d: float) -> bool:
	_passo += 1
	# due fotogrammi per scena: il primo costruisce, il secondo ha i Container
	# già disposti. Fotografare al primo dà pannelli a dimensione zero.
	if _passo < _atteso:
		return false
	match _passo:
		1:
			_scena("it", false)
			_atteso = 6
		6:
			_misura("1-accesa")
			_scatta("1-accesa")
			_scena("it", true)
			_atteso = 12
		12:
			_misura("2-spenta")
			_scatta("2-spenta")
			_scena("en", false)
			_atteso = 18
		18:
			_misura("3-inglese")
			_scatta("3-inglese")
			# ⚠️ LA QUARTA SCENA È UN CONFRONTO, non una variante: la casella
			# ACCESA di «Il villaggio pensa» va guardata ACCANTO a un'altra
			# casella accesa del gioco («Prato Eterno»). Da sola, un pallino
			# scuro su fondo chiaro sembra un difetto di stile; accanto alla
			# sua gemella si vede che è il tema del gioco, non la riga nuova.
			_scena("it", false, true)
			_atteso = 24
		24:
			_misura("4-due-caselle-accese")
			_scatta("4-due-caselle-accese")
			print("[provino] fatto.")
			return true
	return false


func _scena(lingua: String, spento: bool, prato := false) -> void:
	L10n.imposta(lingua)
	var st := root.get_node_or_null(^"/root/Settings")
	if st != null:
		st.set("llm_spento", spento)
		st.set("prato_eterno", prato)
	for c in _radice.get_children():
		_radice.remove_child(c)
		c.queue_free()
	_pannello = CozySettingsPanel.new()
	_radice.add_child(_pannello)


## COSA SI MISURA, oltre a guardarla: che la riga ci sia, e che la nota
## STIA DENTRO. Un testo che esce dal pannello non lo dice nessun test — e in
## inglese la nota è di due parole più lunga.
func _misura(nome: String) -> void:
	var righe := 0
	var trovata := ""
	var nota := ""
	var fuori := 0.0
	var largo := _pannello.size.x
	for c in _pannello.find_children("*", "Label", true, false):
		var l := c as Label
		var t := str(l.text)
		if t.begins_with("Il villaggio pensa") or t.begins_with("The village thinks"):
			trovata = t
		if t.begins_with("Ogni tanto") or t.begins_with("Now and then"):
			nota = t
			var quanto := l.get_theme_font(&"font").get_multiline_string_size(
					t, HORIZONTAL_ALIGNMENT_LEFT, l.size.x,
					l.get_theme_font_size(&"font_size")).y
			fuori = quanto - l.size.y
		righe += 1
	var casella := ""
	for c in _pannello.find_children("*", "CheckButton", true, false):
		var b := c as CheckButton
		var padre := b.get_parent()
		if padre != null and padre.get_parent() == _pannello.get_node_or_null("."):
			pass
		casella += ("acceso " if b.button_pressed else "spento ")
	print("[provino] %s: pannello %.0f×%.0f · riga «%s» · caselle: %s"
			% [nome, largo, _pannello.size.y, trovata, casella])
	print("           nota: «%s»" % nota)
	print("           la nota sfora di %.1f px (deve essere ≤ 0)" % fuori)


func _scatta(nome: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var p := "%s/%s.png" % [_dove, nome]
	img.save_png(p)
	print("[provino] ", p)
