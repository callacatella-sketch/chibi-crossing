extends RefCounted
## IL BANCO DELLE PROVE VIVE — l'apparecchiatura, e nient'altro.
##
## Le due prove della Fase 4 (`prova_percezione.gd` e `prova_pettegolezzo.gd`)
## fanno cose diverse ma stanno sullo **stesso banco**: aprono il MainLevel
## vero, spengono la persistenza, spengono l'interfaccia, si danno una camera
## propria, posano un villaggio e tengono i corpi fermi mentre scattano.
##
## Quella roba sta qui e non due volte. Non è per risparmiare righe: una
## prova viva è uno STRUMENTO DI MISURA, e due strumenti nominalmente uguali
## che divergono di un dettaglio (uno spegne l'interfaccia, l'altro no; uno
## aspetta due frame di render, l'altro uno) danno due risposte diverse alla
## stessa domanda — e la si crede, perché è una foto.
##
## ────────────────────────────────────────────────────────────────────────
## LE TRE COSE CHE QUESTO BANCO SA FARE E CHE SEMBRANO DETTAGLI
## ────────────────────────────────────────────────────────────────────────
##
## 1. **DUE `frame_post_draw` PRIMA DI CATTURARE.** Il viewport consegna il
##    fotogramma PRECEDENTE: con un'attesa sola si salva l'inquadratura di
##    prima, cioè si fotografa il passato credendo di fotografare il
##    presente. In questo progetto è già costato una serie intera di scatti
##    (la boutique).
## 2. **VIA L'INTERFACCIA.** I toast del villaggio («X sogna una panchina
##    vicino a casa…»), le barrette dei bisogni e il suggerimento della
##    modalità costruzione finiscono cotti dentro ogni fotogramma. Su una
##    prova che deve dire «questa testa è girata» sono rumore, e su una
##    prova che qualcuno guarderà fra sei mesi sono rumore che mente (quel
##    toast racconta una cosa che non c'entra niente con la scena).
## 3. **I CHIODI.** Un residente vero non sta fermo: l'agenda in C++ lo
##    rivaluta a ogni frame, `_routine` gli riassegna una fase, e fra uno
##    scatto e l'altro il corpo si gira e se ne va. La prima stesura della
##    prova della percezione ci è cascata: la foto «di tre quarti» ritraeva
##    un vicino **di spalle**, perché nei quattro frame fra un'inquadratura
##    e l'altra si era incamminato altrove. Un chiodo rimette posizione,
##    verso e stato a OGNI frame, e si toglie quando la scena deve muoversi.
##
## Chi aggiunge una terza prova viva parta da qui.

## Quanti fotogrammi di assestamento prima di catturare. Quattro: il tempo
## che una tenda in dissolvenza, una nuvoletta appena nata e il tween del
## bricco hanno per arrivare dove devono.
const FRAME_ASSESTAMENTO := 4

var tree: SceneTree
var livello: Node = null
var build: Node = null
var visitors: Node = null
var garden: Node = null
var daynight: Node = null
var weather: Node = null
var percezione: Node = null
var player: Node3D = null
var cuore: Object = null
var cam: Camera3D = null

## Dove finiscono le immagini ("" = nessuna immagine, prova solo numerica).
var dove := ""
var guasti := 0
## L'ora del villaggio, tenuta ferma per tutta la prova (vedi `_tieni_ora`).
var ora := 0.44

## I corpi inchiodati: `{node, riga, pos, yaw}`.
var _chiodi: Array = []
var _targa: Label3D = null


func _init(p_tree: SceneTree, p_dove: String) -> void:
	tree = p_tree
	dove = p_dove
	if dove != "":
		DirAccess.make_dir_recursive_absolute(dove)


# ------------------------------------------------------------- il verdetto

func dico(ok: bool, testo: String) -> void:
	if not ok:
		guasti += 1
	print(("  ok      " if ok else "  GUASTO  ") + testo)


func verdetto(titolo: String) -> int:
	print("\n==== %s: %s ====" % [titolo,
			"TUTTO A POSTO" if guasti == 0 else "%d GUASTI" % guasti])
	if dove != "":
		print("   immagini in %s" % dove)
	return 1 if guasti > 0 else 0


# ------------------------------------------------------------- il MainLevel

## Apre il mondo vero e trova tutto. Torna false se manca qualcosa: una prova
## che gira su mezzo villaggio non è una prova indulgente, è una prova falsa.
func apri(p_ora := 0.44) -> bool:
	ora = p_ora
	await tree.process_frame
	tree.change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 14:
		await tree.process_frame
	livello = tree.current_scene
	if livello == null:
		print("GUASTO: il MainLevel non si è caricato")
		return false
	build = livello.get_node_or_null("BuildSystem")
	visitors = livello.get_node_or_null("Visitors")
	garden = livello.get_node_or_null("Garden")
	daynight = livello.get_node_or_null("DayNight")
	weather = livello.get_node_or_null("Weather")
	percezione = livello.get_node_or_null("Percezione")
	player = livello.get_node_or_null("Player") as Node3D
	if build == null or visitors == null or garden == null or daynight == null \
			or weather == null or percezione == null or player == null:
		print("GUASTO: BuildSystem=%s Visitors=%s Garden=%s DayNight=%s Weather=%s Percezione=%s Player=%s"
				% [build, visitors, garden, daynight, weather, percezione, player])
		return false
	build.call("set_persist_for_debug", false)
	# L'OROLOGIO SI FERMA, e non è una comodità: **una giornata di questo
	# villaggio dura quattro minuti** (`DayNight.cycle_seconds = 240`), e una
	# prova viva ne dura tre o quattro. Senza questa riga la prima
	# inquadratura è di mattina e l'ultima è al tramonto: il confronto
	# «prima / dopo», che è il metodo di tutte e due queste prove, si
	# guarderebbe con due luci diverse — e la differenza che si nota per
	# prima sarebbe quella sbagliata. In più, di notte i residenti rientrano
	# in casa (`resident_sleep`) e spariscono dal mondo a metà misura.
	tree.process_frame.connect(_tieni_ora)
	_tieni_ora()
	# IL CIELO SGOMBRO, e non è vezzo fotografico: la nebbiolina del mattino
	# esiste davvero (autunno, cielo sereno, fra le 0.27 e le 0.40) e vela il
	# contrasto proprio dove serve — sul muso di un chibi a dieci metri. Una
	# prova che dipende dal meteo del giorno non è ripetibile.
	weather.call("debug_rain", false)
	weather.call("debug_mist", false)
	spegni_ui()
	if dove != "":
		cam = Camera3D.new()
		cam.fov = 50.0     # la lente del gioco (Player.tscn), non una scelta mia
		cam.current = true
		tree.root.add_child(cam)
		_targa = Label3D.new()
		_targa.font_size = 52
		_targa.pixel_size = 0.0012
		_targa.outline_size = 16
		_targa.modulate = Color(1, 1, 1)
		_targa.outline_modulate = Color(0.12, 0.09, 0.14)
		_targa.no_depth_test = true
		_targa.position = Vector3(0, -0.62, -2.2)   # in basso, davanti alla lente
		_targa.visible = false
		cam.add_child(_targa)
	await tree.create_timer(1.0).timeout
	cuore = visitors.call("cuore")
	return true


## Via ogni strato d'interfaccia. Lo stesso gesto della Modalità Foto
## (`PhotoMode._hide_ui`), qui però anche la vignetta: una prova si legge
## meglio senza il bordo scuro addosso.
##
## E via anche IL FILO ROSSO. Non è interfaccia — è un simbolo del gioco, ed
## è bellissimo dov'è — ma qui dentro i corpi si teletrasportano a venti
## metri per costruire una geometria, e un nastro teso fra la zampa di Mochi
## e un vicino spostato a mano attraversa il fotogramma come un raggio
## laser: chi guarda la prova fra sei mesi lo legge come un errore di resa e
## smette di fidarsi dell'immagine. Sparisce il segno, non il sistema.
func spegni_ui() -> void:
	for layer in tree.root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var filo := tree.get_first_node_in_group("filo_rosso") as Node3D
	if filo != null:
		filo.visible = false


# --------------------------------------------------------------- i chiodi

## Inchioda un corpo: da adesso posizione, verso e stato tornano al loro
## posto a OGNI frame, finché non si sfila il chiodo.
func inchioda(riga: Dictionary, pos: Vector3, yaw: float) -> void:
	var node := riga.get("node") as Node3D
	if node == null:
		return
	node.position = pos
	node.set("_yaw", yaw)
	node.call("_enter_state", "r_idle")
	_chiodi.append({"node": node, "riga": riga, "pos": pos, "yaw": yaw})
	if not tree.process_frame.is_connected(_ribatti):
		tree.process_frame.connect(_ribatti)


func sfila() -> void:
	_chiodi.clear()
	if tree.process_frame.is_connected(_ribatti):
		tree.process_frame.disconnect(_ribatti)


## Rimette l'orologio dove l'abbiamo lasciato. `set_time` NON fa scattare un
## giorno nuovo tornando indietro di un soffio (`_check_new_day` chiede un
## salto dentro la finestra del mattino, 0.25–0.42): con un'ora oltre quella
## finestra, come la nostra, è un'operazione muta.
func _tieni_ora() -> void:
	if daynight != null and is_instance_valid(daynight):
		daynight.call("set_time", ora)


func _ribatti() -> void:
	for c in _chiodi:
		var node := (c as Dictionary)["node"] as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var riga := (c as Dictionary)["riga"] as Dictionary
		node.position = (c as Dictionary)["pos"]
		node.set("_yaw", (c as Dictionary)["yaw"])
		node.set("_timer", 9999.0)
		riga["next_act"] = 9999.0
		# lo STATO va rimesso solo se se n'è andato: `_enter_state` a ogni
		# frame azzererebbe gli orologi della posa e il corpo smetterebbe di
		# respirare — un chibi perfettamente immobile è la firma dell'adesivo.
		if str(node.get("_state")) != "r_idle":
			node.call("_enter_state", "r_idle")


# ---------------------------------------------------------------- gli scatti

## La didascalia cotta dentro il fotogramma: senza, tre scatti della stessa
## inquadratura diventano tre file che non si sa più in che ordine leggere.
func targa(testo: String) -> void:
	if _targa == null:
		return
	_targa.text = testo
	_targa.visible = testo != ""


func scatta(centro: Vector3, occhio: Vector3, nome: String) -> void:
	if dove == "" or cam == null:
		return
	cam.position = occhio
	cam.look_at(centro, Vector3.UP)
	# di nuovo, e a ogni scatto: il villaggio riaccende i suoi strati da solo
	# (un toast che arriva riporta su l'HUD), e un fotogramma con mezza
	# interfaccia dentro è peggio di uno con tutta — sembra un errore di resa
	spegni_ui()
	for _k in FRAME_ASSESTAMENTO:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_jpg(percorso(nome), 0.94)


## L'INQUADRATURA DEL GIOCO: la lente, l'altezza e l'inclinazione vere di
## `Player.tscn` (camera a +2.7 di quota e +3.7 dietro, fov 50, muso a −Z).
## È l'unica inquadratura che dice qualcosa sulla PARTITA: un primo piano
## dimostra solo che un primo piano si legge.
func scatta_come_in_gioco(nome: String) -> void:
	if dove == "" or cam == null:
		return
	var p := player.global_position
	await scatta(p + Vector3(0, 0.72, 0), p + Vector3(0, 2.7, 3.7), nome)


func percorso(nome: String) -> String:
	return dove.rstrip("/") + "/" + nome + ".jpg"


## Mette in fila orizzontale le immagini già scattate. Un provino affiancato
## non è la stessa cosa di tre file guardati uno dopo l'altro: la differenza
## fra due tarature vicine si vede solo con le due cose nello stesso occhio.
func affianca(nomi: Array, uscita: String, larghezza := 760) -> void:
	if dove == "":
		return
	var pezzi: Array = []
	for n in nomi:
		var img := Image.load_from_file(percorso(str(n)))
		if img == null:
			print("  (provino: manca %s)" % n)
			return
		var h := int(round(float(img.get_height()) * larghezza / float(img.get_width())))
		img.resize(larghezza, h, Image.INTERPOLATE_LANCZOS)
		pezzi.append(img)
	if pezzi.is_empty():
		return
	var alt: int = (pezzi[0] as Image).get_height()
	var foglio := Image.create(larghezza * pezzi.size(), alt, false,
			(pezzi[0] as Image).get_format())
	for i in pezzi.size():
		var p := pezzi[i] as Image
		foglio.blit_rect(p, Rect2i(0, 0, larghezza, alt), Vector2i(larghezza * i, 0))
	foglio.save_jpg(percorso(uscita), 0.95)


# ------------------------------------------------------------- i corpi veri

## PORTA UN CORPO DOVE SERVE, E ASPETTA CHE CI SIA DAVVERO.
##
## Chi si alza da una panchina lo fa con un TWEEN sulla `position` (0,4 s di
## discesa), e un teletrasporto dato mentre quel tween è vivo viene riscritto
## il frame dopo: il corpo torna sulla panchina e la prova misura un vicino
## che credeva a casa. Succedeva a intermittenza — una corsa su due.
func porta(i: int, pos: Vector3) -> bool:
	var residenti: Array = visitors.get("_residents")
	if i < 0 or i >= residenti.size():
		return false
	var node := (residenti[i] as Dictionary)["node"] as Node3D
	for _k in 14:
		visitors.call("debug_stage_resident", i, pos)
		await tree.create_timer(0.4).timeout
		if node.global_position.distance_to(pos) < 0.8:
			return true
	return false


## Aspetta che il corpo sia ENTRATO in uno stato. Una foto scattata «dopo tot
## secondi» prende il corpo a mezza strada, e la scena era qualcuno SEDUTO.
func aspetta(node: Node3D, stato: String, tetto := 20.0) -> float:
	var t := 0.0
	while t < tetto and str(node.get("_state")) != stato:
		await tree.create_timer(0.25).timeout
		t += 0.25
	return t


## Dove sta andando il corpo: la meta, non la prossima tappa.
func meta(node: Node3D) -> Vector3:
	if node.has_method("meta_cammino"):
		return node.call("meta_cammino")
	return node.global_position


## Quanti gradi è girata la testa RISPETTO AL CORPO, e quanto di quello è
## farina della ricevuta. Due numeri e non uno: `_head.rotation.y` porta
## dentro anche l'oscillazione dell'idle, `_tst_off` è solo lo sguardo.
func testa_gradi(node: Node3D) -> Vector2:
	var testa := node.get("_head") as Node3D
	var tot := rad_to_deg(testa.rotation.y) if testa != null else 0.0
	return Vector2(tot, rad_to_deg(float(node.get("_tst_off"))))


## Di quanti gradi la testa MANCA il bersaglio: zero vuol dire che ci guarda
## dritto. È la misura che dice se la ricevuta è arrivata a destinazione o si
## è fermata al tetto del collo.
func scarto_dal_bersaglio(node: Node3D, bersaglio: Vector3) -> float:
	var testa := node.get("_head") as Node3D
	if testa == null:
		return 999.0
	var b := bersaglio
	b.y = testa.global_position.y
	var muso: Vector3 = -testa.global_transform.basis.z
	var verso: Vector3 = (b - testa.global_position)
	muso.y = 0.0
	verso.y = 0.0
	if muso.length() < 0.001 or verso.length() < 0.001:
		return 999.0
	return rad_to_deg(muso.normalized().angle_to(verso.normalized()))
