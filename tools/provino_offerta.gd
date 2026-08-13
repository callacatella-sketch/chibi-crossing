extends SceneTree

## IL PROVINO DELLA SCHERMATA CHE CHIEDE — perché una suite verde non dice
## niente su come si legge una pagina.
##
## `test_offerta_modello.gd` prova che le pagine ci siano e che dicano la cosa
## giusta. Non può dire se la pagina è LEGGIBILE: se il paragrafo esce dal
## pannello, se la scheda dei fatti si accavalla, se i due bottoni hanno
## davvero la stessa misura (che è una regola, non un vezzo: un «no» piccolo
## accanto a un «sì» grande è la forma grafica dell'insistenza), se la
## casella del consenso si perde sotto la piega.
##
##     CHIBI_OFFERTA=/tmp/offerta ~/Downloads/Godot.app/Contents/MacOS/Godot \
##         --path . --resolution 1100x1040 --script res://tools/provino_offerta.gd
##
## ⚠️ **LA FINESTRA DEVE STARCI DENTRO.** La pagina è alta quanto quello che
## dice (`OffertaModello._adatta_altezza`), e l'offerta INGLESE è la più alta
## di tutte: con una finestra da 900 punti il pannello viene tagliato dal
## bordo e la foto racconta un guasto che non c'è. Mille e quaranta bastano.
##
## ⚠️ **NIENTE `--headless`**: senza rendering non c'è niente da guardare, ed
## è esattamente il modo in cui un guasto di impaginazione resta invisibile.
##
## ⚠️ **E L'INGLESE NON È UN VEZZO.** Le righe inglesi sono più lunghe delle
## italiane e le parole non si spezzano allo stesso punto: un pannello a
## larghezza fissa si rompe lì, non in italiano.

const OFFERTA := preload("res://scenes/ui/OffertaModello.gd")
const SCARICO := preload("res://systems/Scarico.gd")

## Quanto è grande il finto pezzo già scaricato. Il file si crea **sparso**
## (si salta in fondo e si scrive un byte): su APFS e su NTFS costa zero
## byte veri e un istante, e `byte_del_pezzo` legge comunque la lunghezza
## giusta — che è l'unica cosa che la pagina guarda.
const PEZZO_FINTO := 1_240_000_000

var _dove := ""
var _passo := 0
var _atteso := 0
var _radice: Control
var _pagina
var _scarico


func _init() -> void:
	_dove = OS.get_environment("CHIBI_OFFERTA")
	if _dove == "":
		_dove = "/tmp/offerta_modello"
	DirAccess.make_dir_recursive_absolute(_dove)
	print("[provino] le foto vanno in ", _dove)

	var sfondo := ColorRect.new()
	sfondo.color = Color("cfe4d0") # il verde del prato, per contrasto
	sfondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(sfondo)

	_radice = CenterContainer.new()
	_radice.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_radice)


func _process(_d: float) -> bool:
	_passo += 1
	# Due fotogrammi per scena: il primo costruisce, il secondo ha i
	# Container già disposti. Fotografare al primo dà pannelli a dimensione
	# zero — il classico «la schermata è vuota» che non lo è.
	if _passo < _atteso:
		return false
	match _passo:
		1:
			_scena("it", {"totale": 16 << 30, "libera": 12 << 30})
			_atteso = 5
		5:
			_scatta("1-offerta-it")
			_spunta()
			_atteso = 8
		8:
			_scatta("2-offerta-accettata-it")
			_scena("en", {"totale": 16 << 30, "libera": 12 << 30})
			_atteso = 12
		12:
			_scatta("3-offerta-en")
			# LA MACCHINA OCCUPATA: tanta RAM, poca libera adesso.
			_scena("it", {"totale": 16 << 30, "libera": 2 << 30})
			_atteso = 16
		16:
			_scatta("4-adesso-no-it")
			# LA MACCHINA PICCOLA: non basterebbe nemmeno vuota.
			_scena("it", {"totale": 3 << 30, "libera": 3 << 30})
			_atteso = 20
		20:
			_scatta("5-mai-it")
			_scena("it", {"totale": 16 << 30, "libera": 12 << 30})
			_scarico_finto(ScaricoMacchina.FASE_CORPO, 1_240_000_000, 1_500_000.0)
			_atteso = 24
		24:
			_scatta("6-scarico-it")
			_scena("en", {"totale": 16 << 30, "libera": 12 << 30})
			_scarico_finto(ScaricoMacchina.FASE_CORPO, 1_240_000_000, 1_500_000.0)
			_atteso = 28
		28:
			_scatta("7-scarico-en")
			_scena("it", {"totale": 16 << 30, "libera": 12 << 30})
			_scarico_finto(ScaricoMacchina.FASE_IMPRONTA, Llm.BYTE_MODELLO, 0.0)
			_atteso = 32
		32:
			_scatta("8-controllo-it")
			_guasto(ScaricoMacchina.ESITO_RETE)
			_atteso = 36
		36:
			_scatta("9-guasto-rete-it")
			_guasto(ScaricoMacchina.ESITO_IMPRONTA)
			_atteso = 40
		40:
			_scatta("10-guasto-impronta-it")
			_guasto(ScaricoMacchina.ESITO_SPAZIO)
			_atteso = 44
		44:
			_scatta("11-guasto-disco-it")
			_pezzo_a_meta()
			_atteso = 48
		48:
			_scatta("12-pezzo-it")
			_pulisci_pezzo()
			_arrivato()
			_atteso = 52
		52:
			_scatta("13-arrivato-it")
			_documento()
			_atteso = 58
		58:
			_scatta("14-terms-of-use")
			_pulisci_pezzo()
			print("[provino] fatto.")
			return true
	return false


## Rimette in piedi la pagina da zero. La macchina si dichiara PRIMA di
## entrare nell'albero: `riparti()` gira dentro `_ready`, e dei numeri
## arrivati dopo non se ne accorgerebbe — il provino fotograferebbe due volte
## la stessa pagina credendo di averne fotografate due.
func _scena(lingua: String, macchina: Dictionary) -> void:
	L10n.imposta(lingua)
	for c in _radice.get_children():
		_radice.remove_child(c)
		c.queue_free()
	_pagina = OFFERTA.new()
	var m := macchina.duplicate()
	m["riserva"] = 1024 * 1024 * 1024
	m["tetto"] = 3 * 1024 * 1024 * 1024
	_pagina.forza_macchina = m
	var cornice := PanelContainer.new()
	cornice.add_theme_stylebox_override("panel", CozyUI.paper_panel(28))
	# Solo la LARGHEZZA: l'altezza la decide la pagina, ed è quello che il
	# provino deve fotografare (una cornice alta a forza mostrerebbe sei
	# pagine tutte uguali con del vuoto sotto).
	cornice.custom_minimum_size = Vector2(600, 0)
	cornice.add_child(_pagina)
	_radice.add_child(cornice)
	# ⚠️ `incorpora()` **DOPO** essere entrati nell'albero. Il `_ready` della
	# pagina si rimette il suo fondo di carta, e chiamarla prima vuol dire
	# fotografare due pannelli sovrapposti — un bordo doppio e un'ombra dentro
	# l'altra. Visto nella prima foto, non nel codice.
	_pagina.incorpora()


## Spunta la casella del consenso come la spunterebbe una persona: si cerca
## la CheckBox vera e si preme. Scrivere `_accetto = true` a mano
## fotograferebbe uno stato che nessun gesto può produrre.
func _spunta() -> void:
	for n in _pagina.find_children("*", "CheckBox", true, false):
		(n as CheckBox).button_pressed = true
		return


## L'avanzamento SENZA la rete: si accende un `Scarico` e gli si scrivono a
## mano i numeri che il thread scriverebbe. Non è un doppio — è il nodo vero,
## col suo `frase_fase()` vero: quello che manca è solo il socket.
func _scarico_finto(fase: int, fatti: int, bps: float) -> void:
	_scarico = SCARICO.new()
	_scarico.name = "ScaricoFinto"
	root.add_child(_scarico)
	_scarico.set("_fase", fase)
	_scarico.set("_fatti", fatti)
	_scarico.set("_al_secondo", bps)
	_pagina.set("_scarico", _scarico)
	_pagina.call("_vai", "scarico")


func _guasto(esito: int) -> void:
	_pagina.set("_esito", esito)
	_pagina.call("_vai", "guasto")


func _arrivato() -> void:
	_pagina.call("_vai", "arrivato")


## Il pezzo a metà: un file sparso lungo quanto serve, più la ricevuta del
## consenso — senza la quale la pagina, giustamente, rifà la domanda.
func _pezzo_a_meta() -> void:
	var parte := SCARICO.destinazione() + ".parte"
	DirAccess.make_dir_recursive_absolute(parte.get_base_dir())
	var f := FileAccess.open(parte, FileAccess.WRITE)
	if f != null:
		f.seek(PEZZO_FINTO - 1)
		f.store_8(0)
		f.close()
	var r := FileAccess.open(OFFERTA.RICEVUTA, FileAccess.WRITE)
	if r != null:
		r.store_string("{\"quando\": \"provino\"}")
		r.close()
	_pagina.call("riparti")


func _pulisci_pezzo() -> void:
	for p in [SCARICO.destinazione() + ".parte", OFFERTA.RICEVUTA]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Il lettore delle licenze aperto da qui: è il requisito «i due documenti si
## devono poter leggere PRIMA del primo byte», e si guarda che si leggano
## davvero invece di fidarsi che il bottone esista.
func _documento() -> void:
	_pagina.call("_apri_documento", "Gemma-Terms-of-Use.txt")


func _scatta(nome: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var p := "%s/%s.png" % [_dove, nome]
	img.save_png(p)
	print("[provino] ", p)
