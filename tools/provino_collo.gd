extends SceneTree
## IL PROVINO DEL COLLO — fin dove può girarsi una testa prima di rompersi.
##
##   CHIBI_COLLO=/dove ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##       --script res://tools/provino_collo.gd
##
## `Visitor.TESTA_MAX` è il tetto della RICEVUTA, ma la ricevuta non è sola
## sul canale: la recita del corpo (`hy_amp`: distratto 0.45, sguardo
## sfuggente 0.55) e l'oscillazione dello stato scrivono lo STESSO
## `_head.rotation.y`, e si SOMMANO. Il tetto che conta è quello del COLLO,
## dopo tutti gli scrittori — e quello si sceglie guardando, non sommando.
##
## Sei tarature identiche in tutto tranne l'angolo, di fronte · di tre
## quarti · **di profilo, una per una** (in fila si coprono a vicenda, e un
## «profilo» di sei nuche non è un profilo) · e alla distanza vera della
## camera di gioco. Il profilo è la vista che smaschera i trucchi: è lì che
## si è visto il gruppo filtrino-bocca «in volo» davanti al muso.

const BANCO := preload("res://tools/banco.gd")
const VISITOR := preload("res://scenes/npc/Visitor.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")

## Le tarature in prova. Zero c'è apposta: è il metro.
##
## 1.41 non è una taratura come le altre: è l'angolo MISURATO che la somma dei
## tre scrittori raggiungeva prima che il tetto esistesse — ricevuta 0.90 +
## «sguardo sfuggente» 0.55 + il dondolio dello stato, 81 gradi. Sta qui
## perché il prima e il dopo si giudicano solo l'uno accanto all'altro.
const ANGOLI := [0.00, 0.90, 1.05, 1.20, 1.41, 1.50]
## Il prima e il dopo, in chiaro: gli indici di 1.41 e di 1.20 in `ANGOLI`.
const I_PRIMA := 4
const I_DOPO := 3
## Prato pulito, lontano dal villaggio: nessun filo d'erba alta sul muso.
const DOVE := Vector3(0, 0, 42)
## Il genoma: UNO per tutti. Sei chibi diversi confrontano sei musi.
const SEME := 4242

var b


func _init() -> void:
	_go()


func _go() -> void:
	b = BANCO.new(self, OS.get_environment("CHIBI_COLLO"))
	if not await b.apri():
		quit(1)
		return
	if b.dove == "":
		print("serve CHIBI_COLLO=<dir>: questo provino esiste per essere GUARDATO")
		quit(1)
		return

	var padre := Node3D.new()
	padre.position = DOVE
	root.add_child(padre)
	var corpi: Array = []
	for k in ANGOLI.size():
		var v = VISITOR.new()
		v.dna = DNA.generate(SEME)
		padre.add_child(v)
		v.position = Vector3(float(k) * 1.5 - 3.75, 0, 0)
		v.mode = "resident"
		v.call("_enter_state", "r_idle")
		v.set("_timer", 9999.0)
		v.set("_yaw", 0.0)          # muso verso −Z, cioè verso la camera
		corpi.append(v)
		var l := Label3D.new()
		l.text = "%.2f rad\n%.0f°" % [float(ANGOLI[k]), rad_to_deg(float(ANGOLI[k]))]
		l.font_size = 56
		l.pixel_size = 0.005
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.outline_size = 18
		l.outline_modulate = Color(0.12, 0.09, 0.14)
		l.position = Vector3(0, 1.62, 0)
		v.add_child(l)
	for _i in 40:
		await process_frame
	# POSA CONGELATA: `_process` spento e il canale scritto a mano, o lo
	# sguardo del testimone (che gira per ogni stato) ci rimette le mani.
	for k in corpi.size():
		var v: Node3D = corpi[k]
		v.set_process(false)
		var testa := v.get("_head") as Node3D
		if testa != null:
			testa.rotation.y = -float(ANGOLI[k])   # verso la sua destra
	for _i in 4:
		await process_frame

	var c := DOVE + Vector3(0, 0.72, 0)
	b.targa("il tetto del collo (rad) — la testa gira verso la SUA destra")
	await b.scatta(c, c + Vector3(0, 0.55, -6.0), "collo-a-fronte")
	await b.scatta(c, c + Vector3(3.9, 0.9, -5.2), "collo-b-trequarti")
	await b.scatta(c, c + Vector3(1.2, 8.0, -2.6), "collo-c-dallalto")
	b.targa("…alla distanza vera della camera di gioco")
	await b.scatta(c, c + Vector3(0, 2.7, -10.4), "collo-d-distanza-di-gioco")
	b.affianca(["collo-a-fronte", "collo-b-trequarti", "collo-c-dallalto",
			"collo-d-distanza-di-gioco"], "collo-0-panoramiche")

	# IL PROFILO, UNO PER UNO — e **GLI ALTRI CINQUE SPARISCONO**. La fila è
	# fitta 1,5 m e la lente di profilo sta a 1,9 m: senza nasconderli si
	# fotografa la nuca del VICINO da quaranta centimetri. (È successo al
	# primo giro di questo provino: cinque quadri di pelo giallo.)
	var nomi_f: Array = []
	var nomi_p: Array = []
	var nomi_q: Array = []
	for k in corpi.size():
		for j in corpi.size():
			(corpi[j] as Node3D).visible = (j == k)
		var v: Node3D = corpi[k]
		var p: Vector3 = v.global_position + Vector3(0, 0.72, 0)
		var eti := "%.2f rad (%.0f°)" % [float(ANGOLI[k]),
				rad_to_deg(float(ANGOLI[k]))]
		# a) DI FRONTE AL CORPO, primo piano: la testa girata si legge come
		#    scarto dalla linea delle spalle — ed è il quadro in cui si vede
		#    la faccia SPARIRE.
		b.targa("%s — di fronte al corpo" % eti)
		await b.scatta(p, p + Vector3(0, 0.10, -1.25), "collo-f%d" % k)
		nomi_f.append("collo-f%d" % k)
		# b) e c) LE DUE VISTE SI PRENDONO RISPETTO ALLA TESTA, non al corpo, e
		#    girano con lei. Una «vista di profilo» misurata sul busto dà, a
		#    ogni taratura, un'inquadratura diversa della faccia: si
		#    confronterebbero sei angoli di ripresa invece di sei angoli di
		#    collo. Così invece il profilo è sempre profilo — ed è LÌ che si
		#    smaschera il muso staccato dalla testona.
		var muso := Vector3(sin(float(ANGOLI[k])), 0, -cos(float(ANGOLI[k])))
		var lato := muso.rotated(Vector3.UP, PI * 0.5)
		b.targa("%s — di profilo (rispetto alla testa)" % eti)
		await b.scatta(p, p + lato * 1.35 + Vector3(0, 0.08, 0), "collo-p%d" % k)
		nomi_p.append("collo-p%d" % k)
		b.targa("%s — di tre quarti (rispetto alla testa)" % eti)
		await b.scatta(p, p + (muso + lato).normalized() * 1.4 + Vector3(0, 0.16, 0),
				"collo-q%d" % k)
		nomi_q.append("collo-q%d" % k)
	for j in corpi.size():
		(corpi[j] as Node3D).visible = true
	b.targa("")
	b.affianca(nomi_f, "collo-1-fronte-primo-piano", 620)
	b.affianca(nomi_p, "collo-2-profili", 620)
	b.affianca(nomi_q, "collo-3-trequarti", 620)

	# IL PRIMA E IL DOPO, gli unici due che contano, uno accanto all'altro e
	# in tutte e tre le viste. A 1.41 (com'era) la faccia non c'è più: l'occhio
	# è tagliato a metà dalla sagoma, il sopracciglio galleggia staccato e il
	# nasino sporge dal bordo di una palla di pelo. A 1.20 (il tetto) c'è
	# ancora tutto: un occhio intero, il muso attaccato, la guancia rosa.
	b.affianca(["collo-f%d" % I_PRIMA, "collo-f%d" % I_DOPO],
			"collo-4-prima-e-dopo-fronte", 780)
	b.affianca(["collo-q%d" % I_PRIMA, "collo-q%d" % I_DOPO],
			"collo-5-prima-e-dopo-trequarti", 780)
	b.affianca(["collo-p%d" % I_PRIMA, "collo-p%d" % I_DOPO],
			"collo-6-prima-e-dopo-profilo", 780)
	print("immagini in %s" % b.dove)
	quit(0)
