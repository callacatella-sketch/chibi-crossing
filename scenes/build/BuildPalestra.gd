class_name BuildPalestra
extends RefCounted

## LA PALESTRA DEL VILLAGGIO — gli attrezzi che il giocatore costruisce.
##
## Non un centro fitness: una palestra di paese, fatta con quello che c'è —
## legno, tela, corda e pietra di fiume. Niente acciaio, niente gomma nera,
## niente numeri stampati: i pesi sono sassi levigati, il sacco è un sacco
## da farina rattoppato, la cyclette ha la ruota di un carretto. Deve
## sembrare che l'abbiano tirata su i vicini in un pomeriggio, e che ci si
## stia bene.
##
## OGNI ATTREZZO HA IL SUO POSTO. Un nodo figlio chiamato "posto" segna
## dove ci si mette e da che parte si guarda (il suo -Z): è l'aggancio che
## serve quando i residenti verranno ad allenarsi, e va messo ADESSO —
## ricavarlo dopo, a occhio, dai numeri del builder, è il modo sicuro di
## ritrovarsi qualcuno che si allena mezzo metro dentro il muro.
##
## Vive in un file suo perché il catalogo è già lungo e ci lavorano in
## tanti: primitive e colori restano di casa in BuildCatalog (`CAT.`), qui
## ci sono solo le forme della palestra.

const CAT := preload("res://scenes/build/BuildCatalog.gd")
const BUILDER := preload("res://scenes/npc/ChibiBuilder.gd")

const CANVAS := Color("e8dcc0")
const CANVAS_DARK := Color("cdbe9c")
const CUOIO := Color("b5764a")
const CUOIO_DARK := Color("8d5733")
const SALVIA := Color("a8c8a0")
const SALVIA_DARK := Color("87ab80")
const CORDA := Color("d8c49a")
const RAME := Color("c98c5a")


## Il posto d'uso di un attrezzo: dove ci si mette e dove si guarda.
## `avanti` è la direzione verso cui è rivolto chi lo usa.
static func _posto(parent: Node3D, pos: Vector3, avanti := Vector3.FORWARD) -> Node3D:
	var p := Node3D.new()
	p.name = "posto"
	p.position = pos
	if avanti.length() > 0.001:
		p.rotation.y = atan2(-avanti.x, -avanti.z)
	parent.add_child(p)
	return p


## Una cucitura: il filo doppio che tiene insieme due pezzi di tela. Sono
## i punti come questo a fare la differenza fra un oggetto e un oggetto
## che qualcuno ha fatto a mano.
static func _cucitura(parent: Node3D, da: Vector3, a: Vector3, punti: int,
		mat: Material, spessore := 0.005) -> void:
	var dir := (a - da)
	var lungo := dir.length()
	if lungo < 0.001:
		return
	for i in punti:
		var u := (float(i) + 0.5) / float(punti)
		var p := da.lerp(a, u)
		# un punto di filo è LUNGO e piatto, non un chiodo piantato: sta
		# quasi dentro la stoffa, e si inclina appena a zig-zag
		var seg := CAT._box(parent,
				Vector3(spessore, spessore * 0.55, lungo / float(punti) * 0.55), mat, p)
		seg.rotation.y = atan2(dir.x, dir.z)
		seg.rotation.x = 0.34 if i % 2 == 0 else -0.34


# ---------------------------------------------------------- il tappetino

## Il primo attrezzo, quello che non costa niente: un tappetino di stoffa
## a righe, con un capo arrotolato. Ci si stende, ci si allunga, e quando
## non serve resta lì come un tappeto qualunque.
static func tappetino() -> Node3D:
	var n := Node3D.new()
	var tela := CAT._mat(SALVIA, SALVIA_DARK, 5.0, 0.45)
	var riga := CAT._mat(CANVAS, CANVAS_DARK, 6.0, 0.4)
	# il tappeto steso, coi capi arrotondati (mezzi cilindri, non spigoli)
	CAT._box(n, Vector3(0.62, 0.026, 0.92), tela, Vector3(0, 0.013, 0))
	for sz: float in [-0.46, 0.46]:
		var capo := CAT._cyl(n, 0.013, 0.013, 0.62, tela, Vector3(0, 0.013, sz))
		capo.rotation.z = PI * 0.5
	# tre righe chiare nel senso della lunghezza: si vede subito da che
	# parte ci si stende
	for sx: float in [-0.19, 0.0, 0.19]:
		CAT._box(n, Vector3(0.035, 0.004, 0.86), riga, Vector3(sx, 0.028, 0))
	# e il capo arrotolato in fondo, con la corda che lo tiene
	var rullo := Node3D.new()
	rullo.position = Vector3(0, 0.062, -0.42)
	n.add_child(rullo)
	var r := CAT._cyl(rullo, 0.062, 0.062, 0.6, tela, Vector3.ZERO)
	r.rotation.z = PI * 0.5
	for sx2: float in [-0.17, 0.17]:
		var laccio := CAT._cyl(rullo, 0.007, 0.007, 0.135, CAT._mat(CORDA, CUOIO, 7.0, 0.4),
				Vector3(sx2, 0, 0))
		laccio.rotation.x = PI * 0.5
	_posto(n, Vector3(0, 0.03, 0.1), Vector3.BACK)
	return n


# ------------------------------------------------------------- la panca

## La panca dei pesi: due cavalletti a X, un cuscino di cuoio cucito, e il
## bilanciere appoggiato sui montanti — un bastone di legno con due sassi
## di fiume infilati ai capi.
static func panca_pesi() -> Node3D:
	var n := Node3D.new()
	var legno := CAT._mat(CAT.WOOD, CAT.WOOD_DARK, 4.0, 0.5)
	var chiaro := CAT._mat(CAT.WOOD_PALE, CAT.WOOD, 3.5, 0.45)
	var cuoio := CAT._mat(CUOIO, CUOIO_DARK, 5.0, 0.5)
	var sasso := CAT._mat(CAT.STONE, CAT.STONE_DARK, 3.0, 0.5)

	# i due cavalletti: gambe incrociate, non pali dritti
	for sz: float in [-0.3, 0.3]:
		for sx: float in [-1.0, 1.0]:
			var gamba := CAT._box(n, Vector3(0.055, 0.5, 0.055), legno,
					Vector3(sx * 0.15, 0.24, sz))
			gamba.rotation.z = sx * 0.32
		CAT._box(n, Vector3(0.42, 0.04, 0.05), legno, Vector3(0, 0.3, sz))
	# la traversa che unisce i due cavalletti
	CAT._box(n, Vector3(0.05, 0.05, 0.66), legno, Vector3(0, 0.2, 0))

	# il cuscino: un parallelepipedo schiacciato coi bordi tondi, cucito
	CAT._box(n, Vector3(0.3, 0.09, 0.86), cuoio, Vector3(0, 0.52, 0))
	for sx3: float in [-0.15, 0.15]:
		var bordo := CAT._cyl(n, 0.045, 0.045, 0.86, cuoio, Vector3(sx3, 0.52, 0))
		bordo.rotation.x = PI * 0.5
	var filo := CAT._mat(CANVAS, CANVAS_DARK, 4.0, 0.3)
	_cucitura(n, Vector3(-0.13, 0.562, -0.4), Vector3(-0.13, 0.562, 0.4), 11, filo)
	_cucitura(n, Vector3(0.13, 0.562, -0.4), Vector3(0.13, 0.562, 0.4), 11, filo)

	# i due montanti col bilanciere in appoggio
	for sx4: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.06, 0.42, 0.06), chiaro, Vector3(sx4 * 0.26, 0.73, -0.36))
		# la forcella dove si appoggia il bastone
		var forc := CAT._box(n, Vector3(0.05, 0.1, 0.12), chiaro,
				Vector3(sx4 * 0.26, 0.96, -0.36))
		forc.rotation.x = 0.25
	var bilanciere := CAT._cyl(n, 0.028, 0.028, 0.92, chiaro, Vector3(0, 0.99, -0.36))
	bilanciere.rotation.z = PI * 0.5
	for sx5: float in [-1.0, 1.0]:
		# i sassi: due dischi di pietra, uno un po' più grosso dell'altro
		CAT._cyl(n, 0.12, 0.12, 0.05, sasso, Vector3(sx5 * 0.36, 0.99, -0.36)) \
				.rotation.z = PI * 0.5
		CAT._cyl(n, 0.09, 0.09, 0.045, sasso, Vector3(sx5 * 0.42, 0.99, -0.36)) \
				.rotation.z = PI * 0.5
	_posto(n, Vector3(0, 0.57, 0.06), Vector3.BACK)
	return n


# -------------------------------------------------------------- il sacco

## Il sacco: un sacco da farina rattoppato, appeso col cordino a un braccio
## di legno curvo. Il sacco è un nodo a sé, col pivot in alto: così il
## giorno che qualcuno lo colpisce, dondola davvero.
##
## Il corpo non è un cilindro rivestito: è UNA superficie di rivoluzione
## a profilo organico (collo stretto dove stringe la corda, pancia BASSA
## e piena — il peso vero sta in fondo, non al centro — e un fondo
## arrotondato a calotta: un sacco pesante non fa cono) più una lieve
## ellitticità, perché un sacco vero non è un cerchio perfetto. Le
## cuciture seguono il raggio VERO del profilo a ogni altezza — un raggio
## fisso galleggerebbe vicino al collo e affonderebbe nella pancia — e
## sopra la striscia corre il punto a zig-zag di `_cucitura` (lo stesso
## della panca pesi): è il "cucito a mano" che si legge da vicino. Le
## toppe sono ritagli rettangolari appena storti, cuciti sul bordo, non
## ellissi lisce appiccicate sopra.
static func sacco() -> Node3D:
	var n := Node3D.new()
	var legno := CAT._mat(CAT.WOOD, CAT.WOOD_DARK, 4.0, 0.5)
	var tela := CAT._mat(CANVAS, CANVAS_DARK, 5.0, 0.5)
	var tela_cucitura := CAT._mat(CANVAS_DARK.darkened(0.2), CANVAS_DARK.darkened(0.4), 4.0, 0.3)
	var toppa_verde := CAT._mat(SALVIA, SALVIA_DARK, 6.0, 0.45)
	var toppa_cuoio := CAT._mat(CUOIO, CUOIO_DARK, 6.0, 0.45)
	var indaco := Color("7c8bab")
	var indaco_scuro := Color("5c6a86")
	var toppa_indaco := CAT._mat(indaco, indaco_scuro, 6.0, 0.45)
	var corda := CAT._mat(CORDA, CUOIO, 7.0, 0.4)
	var filo := CAT._mat(CANVAS_DARK.darkened(0.35), CANVAS.darkened(0.15), 4.0, 0.3)

	# IL PALO STA DIETRO. Il fronte dei pezzi è -Z: col palo davanti, dal
	# lato da cui si guarda (e da cui si tira il pugno) il sacco spariva
	# dietro un pezzo di legno.
	CAT._box(n, Vector3(0.44, 0.07, 0.44), legno, Vector3(0, 0.035, 0.32))
	CAT._box(n, Vector3(0.11, 2.0, 0.11), legno, Vector3(0, 1.0, 0.32))
	# la mensola diagonale: un palo dritto sarebbe una sbarra, questa è
	# una spalla
	var puntone := CAT._box(n, Vector3(0.07, 0.52, 0.07), legno, Vector3(0, 1.5, 0.21))
	puntone.rotation.x = 0.8
	# il braccio curvo che porta il sacco (tubo su tre punti, non un box)
	BUILDER.tube(n, [Vector3(0, 1.94, 0.3), Vector3(0, 2.08, 0.14),
			Vector3(0, 2.06, -0.08)], [0.05, 0.045, 0.038], legno, 14, 10)

	# IL SACCO, appeso: pivot in alto, così dondola dal punto giusto
	var sacco := Node3D.new()
	sacco.name = "sacco"
	sacco.position = Vector3(0, 2.04, -0.08)
	n.add_child(sacco)
	# lieve ellitticità: un sacco vero non è un cerchio perfetto — si
	# gonfia un po' più da un verso che dall'altro
	sacco.scale = Vector3(1.05, 1.0, 0.91)

	# il profilo del corpo, dal collo (dove stringe la corda) al fondo:
	# spalla che si apre in fretta, pancia piena e BASSA, e un fondo che
	# segue un vero arco (gli ultimi quattro punti sono una calotta, non
	# un cono che si chiude di scatto)
	var profilo: Array[Vector2] = [
		Vector2(0.044, -0.15), Vector2(0.098, -0.225), Vector2(0.152, -0.31),
		Vector2(0.192, -0.415), Vector2(0.213, -0.52), Vector2(0.222, -0.6),
		Vector2(0.221, -0.68), Vector2(0.207, -0.79), Vector2(0.182, -0.895),
		Vector2(0.144, -0.985), Vector2(0.097, -1.06), Vector2(0.0896, -1.097),
		Vector2(0.0686, -1.129), Vector2(0.0371, -1.15), Vector2(0.0, -1.157),
	]
	# il raggio VERO del sacco a una data altezza: lo usano le cuciture
	# (che devono strusciare sulla pancia, non fluttuare a un raggio a
	# caso) e le toppe (che vi si appoggiano)
	var raggio_a_altezza := func(y: float) -> float:
		for i in range(profilo.size() - 1):
			var pa: Vector2 = profilo[i]
			var pb: Vector2 = profilo[i + 1]
			if (y <= pa.y and y >= pb.y) or (y >= pa.y and y <= pb.y):
				var campata: float = pb.y - pa.y
				var tt := 0.0 if absf(campata) < 0.0001 else (y - pa.y) / campata
				return lerpf(pa.x, pb.x, clampf(tt, 0.0, 1.0))
		return profilo[profilo.size() - 1].x

	# il cordino, appena rastremato, con un piccolo nodo dove si aggancia
	CAT._cyl(sacco, 0.009, 0.014, 0.2, corda, Vector3(0, -0.1, 0))
	CAT._ball(sacco, 0.02, corda, Vector3(0, -0.004, 0), Vector3(1.0, 0.65, 1.0))

	# IL CORPO: superficie di rivoluzione, molti più punti dell'originale
	# perché la curva si legga come un vero sacco, non un poligono
	BUILDER.lathe(sacco, profilo, tela, Vector3.ZERO, 28)

	# LA LEGATURA IN CIMA: non tre anelli impilati (farebbero una torta a
	# piani, vista da sopra) ma UNA corda che avvolge il collo a spirale,
	# un giro dopo l'altro scendendo — così si legge davvero come corda
	# attorcigliata, e segue il vero raggio del collo (appena più larga,
	# per stringerlo da fuori e non annegare dentro la tela)
	var punti_avvolgimento: Array[Vector3] = []
	var raggi_avvolgimento: Array[float] = []
	var passi_avvolgimento := 32
	var giri_avvolgimento := 3.2
	for i in range(passi_avvolgimento + 1):
		var t := float(i) / float(passi_avvolgimento)
		var y_avv := lerpf(-0.157, -0.285, t)
		var ang_avv := t * TAU * giri_avvolgimento
		var r_avv := raggio_a_altezza.call(y_avv) * 1.14
		punti_avvolgimento.append(Vector3(cos(ang_avv) * r_avv, y_avv, sin(ang_avv) * r_avv))
		raggi_avvolgimento.append(0.0115)
	BUILDER.tube(sacco, punti_avvolgimento, raggi_avvolgimento, corda, 44, 8)
	# e il capo della corda che avanza, mollemente, dopo l'ultimo giro
	var fine_avv: Vector3 = punti_avvolgimento[punti_avvolgimento.size() - 1]
	BUILDER.tube(sacco, [fine_avv, fine_avv + Vector3(0.04, -0.025, 0.015),
			fine_avv + Vector3(0.06, -0.085, 0.025)], [0.011, 0.009, 0.006], corda, 10, 7)
	CAT._ball(sacco, 0.012, corda, fine_avv + Vector3(0.062, -0.095, 0.027))

	# LE CUCITURE VERTICALI: quattro pannelli (gli angoli sono appena
	# irregolari — un sacco cucito a mano non è un poligono perfetto),
	# ognuna a TRE fasce di altezza, ogni fascia sul SUO raggio medio
	# (misurato dal profilo vero): così la striscia segue la pancia
	# invece di galleggiare vicino al collo o affondare nella pancia.
	# Sopra la striscia, il punto a zig-zag di `_cucitura`.
	var angoli_cuciture: Array[float] = [0.3, PI * 0.5 + 0.16, PI + 0.36, PI * 1.5 - 0.22]
	var fasce := [[-0.15, -0.415], [-0.415, -0.895], [-0.895, -1.157]]
	for ang in angoli_cuciture:
		var giro := Node3D.new()
		giro.rotation.y = ang
		sacco.add_child(giro)
		for fascia in fasce:
			var y_alto: float = fascia[0]
			var y_basso: float = fascia[1]
			var y_mezzo := (y_alto + y_basso) * 0.5
			var r: float = raggio_a_altezza.call(y_mezzo)
			var z := r - 0.0035
			CAT._box(giro, Vector3(0.011, absf(y_basso - y_alto) * 0.94, 0.006),
					tela_cucitura, Vector3(0, y_mezzo, z))
			# il punto a zig-zag, FITTO: pochi punti radi sembrano chiodi
			# piantati, non filo cucito — qui uno ogni 3-4 cm di striscia
			var n_punti := maxi(4, int(absf(y_basso - y_alto) / 0.035))
			_cucitura(giro, Vector3(0, y_alto - 0.015, z + 0.0015),
					Vector3(0, y_basso + 0.015, z + 0.0015), n_punti, filo, 0.0032)

	# LE TOPPE. Ritagli rettangolari, storti sul proprio asse (un
	# rattoppo vero non è mai un rettangolo perfetto), col bordo intero
	# cucito, appoggiati sulla pancia più piatta del sacco — dove un
	# rattoppo davvero si poserebbe — e uno con l'angolo smussato, come
	# se fosse stato ritagliato da uno scampolo più grande.
	_toppa(sacco, 0.9, -0.6, Vector2(0.135, 0.155), 0.26, toppa_verde, filo,
			raggio_a_altezza, true)
	_toppa(sacco, -2.35, -0.68, Vector2(0.1, 0.125), -0.34, toppa_cuoio, filo,
			raggio_a_altezza, false)
	_toppa(sacco, 3.55, -0.53, Vector2(0.075, 0.09), 0.18, toppa_indaco, filo,
			raggio_a_altezza, false)

	_posto(n, Vector3(0, 0.0, -0.64), Vector3.BACK)
	return n


## Una toppa cucita sul sacco: un ritaglio RETTANGOLARE (non un'ellisse
## liscia), appena storto sul proprio asse — un rattoppo vero è tagliato
## a mano da un pezzo di stoffa più grande, mai un rettangolo perfetto —
## col bordo intero cucito (il punto a zig-zag di `_cucitura`), e si
## appoggia alla pancia usando il raggio VERO del sacco a quell'altezza
## (`raggio_a_altezza`), non un numero fisso indovinato a occhio.
static func _toppa(sacco: Node3D, angolo: float, y: float, misura: Vector2,
		rot_z: float, mat: Material, filo: Material, raggio_a_altezza: Callable,
		taglio: bool) -> void:
	var giro := Node3D.new()
	giro.rotation.y = angolo
	sacco.add_child(giro)
	var r: float = raggio_a_altezza.call(y)
	var spessore := 0.014
	var telaio := Node3D.new()
	telaio.position = Vector3(0, y, r - spessore * 0.3)
	telaio.rotation.z = rot_z
	giro.add_child(telaio)
	var w := misura.x
	var h := misura.y
	CAT._box(telaio, Vector3(w, h, spessore), mat, Vector3.ZERO)
	if taglio:
		# l'angolo smussato: un cuneo dello stesso tessuto del sacco,
		# sovrapposto — finge il ritaglio mancante
		var cuneo := CAT._box(telaio, Vector3(w * 0.4, h * 0.4, spessore * 1.3),
				CAT._mat(CANVAS, CANVAS_DARK, 5.0, 0.5), Vector3(w * 0.42, h * 0.42, 0))
		cuneo.rotation.z = PI * 0.25
	# il bordo cucito, sui quattro lati — fitto, un punto ogni 2-3 cm,
	# altrimenti sembrano quattro chiodi e non un orlo cucito
	var hw := w * 0.5
	var hh := h * 0.5
	var zf := spessore * 0.5 + 0.0015
	var n_larghi := maxi(3, int(w / 0.025))
	var n_alti := maxi(3, int(h / 0.025))
	_cucitura(telaio, Vector3(-hw, hh, zf), Vector3(hw, hh, zf), n_larghi, filo, 0.0032)
	_cucitura(telaio, Vector3(-hw, -hh, zf), Vector3(hw, -hh, zf), n_larghi, filo, 0.0032)
	_cucitura(telaio, Vector3(-hw, hh, zf), Vector3(-hw, -hh, zf), n_alti, filo, 0.0032)
	_cucitura(telaio, Vector3(hw, hh, zf), Vector3(hw, -hh, zf), n_alti, filo, 0.0032)


# ----------------------------------------------------------- la cyclette

## La cyclette: il telaio di un carretto a cui hanno tolto tutto tranne una
## ruota, e ci hanno montato sopra una sella. La ruota sta DAVANTI (il
## fronte dei pezzi è -Z), la sella dietro, e in mezzo c'è un telaio che si
## tocca — una bicicletta fatta di bastoni sospesi non è una bicicletta.
static func cyclette() -> Node3D:
	var n := Node3D.new()
	var legno := CAT._mat(CAT.WOOD, CAT.WOOD_DARK, 4.0, 0.5)
	var chiaro := CAT._mat(CAT.WOOD_PALE, CAT.WOOD, 3.5, 0.45)
	var cuoio := CAT._mat(CUOIO, CUOIO_DARK, 5.0, 0.5)
	var ferro := CAT._mat(CAT.METAL, Color("6d6259"), 5.0, 0.4)

	# i due pattini a terra, uniti davanti e dietro: sta in piedi da sola
	for sx: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.07, 0.06, 0.86), legno, Vector3(sx * 0.2, 0.03, 0))
	for sz: float in [-0.38, 0.36]:
		CAT._box(n, Vector3(0.47, 0.05, 0.08), legno, Vector3(0, 0.03, sz))

	# LA RUOTA davanti, in piedi: cerchio, mozzo e dieci raggi
	var ruota := Node3D.new()
	ruota.position = Vector3(0, 0.4, -0.3)
	n.add_child(ruota)
	var cerchio := TorusMesh.new()
	cerchio.inner_radius = 0.28
	cerchio.outer_radius = 0.34
	cerchio.rings = 28
	cerchio.ring_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = cerchio
	mi.material_override = chiaro
	mi.rotation.x = PI * 0.5
	ruota.add_child(mi)
	CAT._cyl(ruota, 0.05, 0.05, 0.08, ferro, Vector3.ZERO).rotation.z = PI * 0.5
	for i in 10:
		var raggio := CAT._cyl(ruota, 0.007, 0.007, 0.58, ferro, Vector3.ZERO)
		raggio.rotation.x = float(i) / 10.0 * TAU

	# IL TELAIO, che si tocca: forcella sulla ruota, trave obliqua fino al
	# reggisella, e piantone del manubrio
	for sx2: float in [-1.0, 1.0]:
		var forc := CAT._box(n, Vector3(0.05, 0.46, 0.05), legno,
				Vector3(sx2 * 0.075, 0.6, -0.24))
		forc.rotation.x = -0.28
	var trave := CAT._box(n, Vector3(0.075, 0.78, 0.075), legno, Vector3(0, 0.5, -0.03))
	trave.rotation.x = 0.72
	var reggisella := CAT._box(n, Vector3(0.07, 0.62, 0.07), legno, Vector3(0, 0.6, 0.24))
	reggisella.rotation.x = -0.12
	var piantone := CAT._box(n, Vector3(0.06, 0.58, 0.06), legno, Vector3(0, 0.78, -0.21))
	piantone.rotation.x = 0.1

	# LA SELLA: una goccia di cuoio, larga dietro e a punta davanti
	var sella := Node3D.new()
	sella.position = Vector3(0, 0.92, 0.22)
	n.add_child(sella)
	# larga dietro, a punta davanti: una sella è un triangolo smussato,
	# non un cuscino tondo (che da sopra sembra un berretto)
	CAT._ball(sella, 0.105, cuoio, Vector3(0, 0, 0.05), Vector3(0.78, 0.34, 0.95))
	var punta := CAT._ball(sella, 0.085, cuoio, Vector3(0, -0.008, -0.11),
			Vector3(0.42, 0.3, 2.0))
	punta.rotation.x = -0.1
	CAT._cyl(sella, 0.02, 0.02, 0.06, ferro, Vector3(0, -0.05, 0.02))

	# IL MANUBRIO: un tubo curvo con le due impugnature di cuoio
	BUILDER.tube(n, [Vector3(-0.21, 0.98, -0.12), Vector3(-0.07, 1.04, -0.2),
			Vector3(0.07, 1.04, -0.2), Vector3(0.21, 0.98, -0.12)],
			[0.015, 0.018, 0.018, 0.015], chiaro, 16, 8)
	for sx3: float in [-1.0, 1.0]:
		CAT._cyl(n, 0.023, 0.023, 0.1, cuoio, Vector3(sx3 * 0.22, 0.975, -0.115)) \
				.rotation.z = PI * 0.5

	# LA PEDALIERA: manovella sul mozzo, due pedali in controfase
	for sx4: float in [-1.0, 1.0]:
		var manovella := Node3D.new()
		manovella.position = Vector3(sx4 * 0.075, 0.4, -0.3)
		manovella.rotation.x = 0.9 if sx4 > 0 else 0.9 + PI
		n.add_child(manovella)
		CAT._box(manovella, Vector3(0.022, 0.19, 0.022), ferro, Vector3(0, 0.085, 0))
		var pedale := CAT._box(manovella, Vector3(0.075, 0.02, 0.11), legno,
				Vector3(sx4 * 0.035, 0.175, 0))
		pedale.rotation.x = -manovella.rotation.x
	_posto(n, Vector3(0, 0.97, 0.22), Vector3.FORWARD)
	return n

# ------------------------------------------------------ la sbarra e gli anelli

## Due pali, una sbarra, e due anelli di legno appesi alle corde. È
## l'attrezzo più semplice della palestra ed è quello che riempie di più
## lo spazio: si vede da lontano che lì qualcuno si tira su.
static func sbarra_trazione() -> Node3D:
	var n := Node3D.new()
	var legno := CAT._mat(CAT.WOOD, CAT.WOOD_DARK, 4.0, 0.5)
	var chiaro := CAT._mat(CAT.WOOD_PALE, CAT.WOOD, 3.5, 0.45)
	var corda := CAT._mat(CORDA, CUOIO, 7.0, 0.4)

	for sx: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.3, 0.06, 0.3), legno, Vector3(sx * 0.4, 0.03, 0))
		CAT._box(n, Vector3(0.09, 2.16, 0.09), legno, Vector3(sx * 0.4, 1.08, 0))
		# le due gambette di controvento: senza, sembra un cancello
		var punt := CAT._box(n, Vector3(0.05, 0.44, 0.05), legno,
				Vector3(sx * 0.4, 0.34, 0.15))
		punt.rotation.x = 0.55
	# la traversa bassa che chiude il telaio: senza, due pali e una barra
	# in cima sono una forca, non un attrezzo
	CAT._box(n, Vector3(0.86, 0.05, 0.05), legno, Vector3(0, 0.52, 0))
	for sx3: float in [-1.0, 1.0]:
		var sost := CAT._box(n, Vector3(0.045, 0.3, 0.045), legno,
				Vector3(sx3 * 0.28, 0.66, 0))
		sost.rotation.z = sx3 * 0.42
	# la sbarra, un filo più chiara: è la parte che si tocca
	var barra := CAT._cyl(n, 0.032, 0.032, 0.94, chiaro, Vector3(0, 2.12, 0))
	barra.rotation.z = PI * 0.5
	# e le fasciature di corda ai due capi, dove ci si aggrappa
	for sx2: float in [-1.0, 1.0]:
		CAT._cyl(n, 0.038, 0.038, 0.14, corda, Vector3(sx2 * 0.3, 2.12, 0)) \
				.rotation.z = PI * 0.5

	# GLI ANELLI, appesi al centro: due nodi a sé, pivot in alto
	for sx3: float in [-1.0, 1.0]:
		var appeso := Node3D.new()
		appeso.name = "anello_%s" % ("sx" if sx3 < 0 else "dx")
		appeso.position = Vector3(sx3 * 0.13, 2.1, 0)
		n.add_child(appeso)
		CAT._cyl(appeso, 0.009, 0.009, 0.4, corda, Vector3(0, -0.2, 0))
		var anello := TorusMesh.new()
		anello.inner_radius = 0.055
		anello.outer_radius = 0.075
		anello.rings = 20
		anello.ring_segments = 7
		var am := MeshInstance3D.new()
		am.mesh = anello
		am.material_override = chiaro
		am.rotation.x = PI * 0.5
		am.position = Vector3(0, -0.46, 0)
		appeso.add_child(am)
	_posto(n, Vector3(0, 0.0, 0.34), Vector3.FORWARD)
	return n


# ------------------------------------------------------------- lo specchio

## Lo specchio della palestra: una lastra in una cornice di legno, appena
## inclinata all'indietro sul suo cavalletto. Non riflette davvero — sarebbe
## un secondo mondo da disegnare — ma fa quello che fa uno specchio in un
## disegno: prende la luce del cielo e ci mette sopra una lama di riflesso.
static func specchio() -> Node3D:
	var n := Node3D.new()
	var legno := CAT._mat(CAT.WOOD, CAT.WOOD_DARK, 4.0, 0.5)
	var chiaro := CAT._mat(CAT.WOOD_PALE, CAT.WOOD, 3.5, 0.45)

	# il cavalletto dietro, che lo tiene in piedi
	_zampe_a_cavalletto(n, legno)

	# la cornice, inclinata come uno specchio appoggiato al muro
	var quadro := Node3D.new()
	quadro.position = Vector3(0, 0.86, -0.06)
	quadro.rotation.x = 0.08
	n.add_child(quadro)
	for sx: float in [-1.0, 1.0]:
		CAT._box(quadro, Vector3(0.07, 1.62, 0.06), legno, Vector3(sx * 0.32, 0, 0))
	for sy: float in [-1.0, 1.0]:
		CAT._box(quadro, Vector3(0.71, 0.08, 0.06), legno, Vector3(0, sy * 0.77, 0))
	# il vetro: azzurro pallido appena luminoso, non bianco (uno specchio
	# bianco è una porta di frigorifero)
	var vetro := CAT._glow(Color(0.80, 0.88, 0.93), Color(0.62, 0.76, 0.88), 0.22)
	CAT._box(quadro, Vector3(0.6, 1.52, 0.02), vetro, Vector3(0, 0, 0.015))
	# e la lama di riflesso, obliqua: è QUESTA che dice «specchio»
	var lama := CAT._glow(Color(1, 1, 1, 0.5), Color(1, 1, 1), 0.5)
	lama.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# (corte: una lama lunga quanto il vetro, inclinata, esce dalla cornice
	# — e un riflesso che sborda dallo specchio non è un riflesso)
	var l1 := CAT._box(quadro, Vector3(0.085, 0.95, 0.006), lama, Vector3(-0.1, 0.14, 0.028))
	l1.rotation.z = 0.42
	var l2 := CAT._box(quadro, Vector3(0.035, 0.5, 0.006), lama, Vector3(0.1, -0.34, 0.028))
	l2.rotation.z = 0.42
	_posto(n, Vector3(0, 0.0, 0.75), Vector3.BACK)
	return n


## Due gambe a cavalletto dietro un pezzo verticale: le usano lo specchio
## e la rastrelliera, ed è il modo in cui in questo villaggio si tiene su
## una cosa alta senza inchiodarla al muro.
static func _zampe_a_cavalletto(n: Node3D, legno: Material) -> void:
	CAT._box(n, Vector3(0.78, 0.07, 0.34), legno, Vector3(0, 0.035, -0.02))
	for sx: float in [-1.0, 1.0]:
		var g := CAT._box(n, Vector3(0.06, 0.62, 0.06), legno,
				Vector3(sx * 0.3, 0.32, -0.16))
		g.rotation.x = -0.36


# ------------------------------------------------------------ la fontanella

## La fontanella: una botte d'acqua su un cavalletto, col rubinetto di rame
## e il truogolo sotto. In una palestra è il posto dove si sta fermi a
## riprendere fiato — che in questo gioco vuol dire che è il pezzo più
## importante di tutti.
##
## (La prima versione era una vasca di pietra chiara su una colonna: da
## qualunque parte la si guardasse era un LAVANDINO. Una botte no.)
static func fontanella() -> Node3D:
	var n := Node3D.new()
	var legno := CAT._mat(CAT.WOOD, CAT.WOOD_DARK, 4.0, 0.5)
	var doga := CAT._mat(CAT.WOOD_PALE, CAT.WOOD, 2.5, 0.55)
	var ferro := CAT._mat(CAT.METAL, Color("6d6259"), 5.0, 0.4)
	var rame := CAT._mat(RAME, RAME.darkened(0.3), 5.0, 0.4)

	# il cavalletto: due culle a V che tengono la botte per i fianchi
	for sz: float in [-0.24, 0.24]:
		for sx: float in [-1.0, 1.0]:
			var g := CAT._box(n, Vector3(0.06, 0.56, 0.06), legno,
					Vector3(sx * 0.24, 0.28, sz))
			g.rotation.z = sx * 0.2
		CAT._box(n, Vector3(0.5, 0.05, 0.06), legno, Vector3(0, 0.2, sz))

	# LA BOTTE, coricata: superficie di rivoluzione panciuta, poi girata
	var botte := Node3D.new()
	botte.position = Vector3(0, 0.66, 0)
	botte.rotation.z = PI * 0.5
	n.add_child(botte)
	BUILDER.lathe(botte, [
		Vector2(0.0, -0.33), Vector2(0.2, -0.33), Vector2(0.235, -0.22),
		Vector2(0.255, 0.0), Vector2(0.235, 0.22), Vector2(0.2, 0.33),
		Vector2(0.0, 0.33),
	], doga, Vector3.ZERO, 26)
	# i tre cerchi di ferro che la tengono insieme
	for y: float in [-0.24, 0.0, 0.24]:
		var r := 0.238 if absf(y) > 0.1 else 0.258
		var cerchio := TorusMesh.new()
		cerchio.inner_radius = r
		cerchio.outer_radius = r + 0.016
		cerchio.rings = 22
		cerchio.ring_segments = 6
		var cm := MeshInstance3D.new()
		cm.mesh = cerchio
		cm.material_override = ferro
		cm.position = Vector3(0, y, 0)
		botte.add_child(cm)

	# il rubinetto di rame sul fondo della botte, verso il fronte (-Z)
	BUILDER.tube(n, [Vector3(0, 0.56, -0.2), Vector3(0, 0.52, -0.27),
			Vector3(0, 0.46, -0.28)], [0.022, 0.019, 0.016], rame, 12, 8)
	CAT._cyl(n, 0.028, 0.028, 0.045, rame, Vector3(0, 0.6, -0.19))
	for a: float in [0.0, PI * 0.5]:
		CAT._box(n, Vector3(0.085, 0.012, 0.012), rame,
				Vector3(0, 0.625, -0.19)).rotation.y = a

	# il truogolo sotto, con dentro un dito d'acqua
	CAT._box(n, Vector3(0.42, 0.04, 0.28), legno, Vector3(0, 0.06, -0.3))
	for sx2: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.03, 0.14, 0.28), legno, Vector3(sx2 * 0.2, 0.13, -0.3))
	for sz2: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.42, 0.14, 0.03), legno, Vector3(0, 0.13, -0.3 + sz2 * 0.13))
	var acqua := CAT._glow(Color(0.55, 0.82, 0.95, 0.8), Color(0.4, 0.7, 0.9), 0.14)
	acqua.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	CAT._box(n, Vector3(0.37, 0.05, 0.23), acqua, Vector3(0, 0.115, -0.3))

	# il filo d'acqua che cade dal rubinetto, e gli spruzzi nel truogolo
	var getto := CAT._glow(Color(0.7, 0.88, 0.98, 0.55), Color(0.55, 0.8, 0.95), 0.25)
	getto.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	CAT._cyl(n, 0.008, 0.012, 0.31, getto, Vector3(0, 0.3, -0.285))
	CAT._emit_fx(n, Vector3(0, 0.15, -0.29), Color(0.75, 0.92, 1.0), 0.45, -1.6,
			12, 0.7, 0.045)

	# e la tazza di latta appesa al cavalletto: è il dettaglio che dice
	# «qui ci si ferma a bere»
	var tazza := Node3D.new()
	tazza.position = Vector3(0.3, 0.42, -0.16)
	tazza.rotation.z = 0.25
	n.add_child(tazza)
	CAT._cyl(tazza, 0.052, 0.042, 0.085, ferro, Vector3.ZERO)
	BUILDER.tube(tazza, [Vector3(0.05, 0.02, 0), Vector3(0.085, 0.0, 0),
			Vector3(0.05, -0.03, 0)], [0.008, 0.009, 0.008], ferro, 10, 6)
	_posto(n, Vector3(0, 0.0, -0.62), Vector3.BACK)
	return n

# ---------------------------------------------------- la rastrelliera dei pesi

## I pesi: sassi di fiume levigati, infilati sui bastoni, in ordine di
## grandezza su due ripiani. In fondo due pietre col manico di corda, che
## si prendono a due mani.
static func rastrelliera() -> Node3D:
	var n := Node3D.new()
	var legno := CAT._mat(CAT.WOOD, CAT.WOOD_DARK, 4.0, 0.5)
	var chiaro := CAT._mat(CAT.WOOD_PALE, CAT.WOOD, 3.5, 0.45)
	var sasso := CAT._mat(CAT.STONE, CAT.STONE_DARK, 3.0, 0.5)
	var sasso_scuro := CAT._mat(CAT.STONE_DARK, Color("8e857a"), 3.5, 0.5)
	var corda := CAT._mat(CORDA, CUOIO, 7.0, 0.4)

	# il telaio: due fianchi a A e due ripiani
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var g := CAT._box(n, Vector3(0.055, 0.78, 0.055), legno,
					Vector3(sx * 0.4, 0.38, sz * 0.16))
			g.rotation.x = sz * 0.12
		CAT._box(n, Vector3(0.06, 0.05, 0.42), legno, Vector3(sx * 0.4, 0.72, 0))
	for sy: float in [0.3, 0.68]:
		CAT._box(n, Vector3(0.92, 0.045, 0.3), chiaro, Vector3(0, sy, 0))

	# i manubri: bastone e due sassi, tre misure. Sul ripiano di sopra i
	# leggeri, sotto i pesanti — come li metterebbe chiunque
	# i ripiani stanno a 0.3 e 0.68, spessi 0.045: il piano d'appoggio è
	# quindi a 0.3225 e 0.7025 — un sasso ci si POSA sopra, tangente, e
	# affonda di un soffio come fa una cosa pesante su un'asse
	var misure := [[0.055, 0.7025, -0.3], [0.062, 0.7025, 0.0], [0.07, 0.7025, 0.3],
			[0.085, 0.3225, -0.26], [0.095, 0.3225, 0.08]]
	for m in misure:
		var r: float = m[0]
		var y: float = m[1] + r * 0.92
		var x: float = m[2]
		var manubrio := Node3D.new()
		manubrio.position = Vector3(x, y, 0)
		manubrio.rotation.y = 0.12 if int(x * 10) % 2 == 0 else -0.16
		n.add_child(manubrio)
		var asta := CAT._cyl(manubrio, 0.014, 0.014, 0.3, chiaro, Vector3.ZERO)
		asta.rotation.x = PI * 0.5
		for sz2: float in [-1.0, 1.0]:
			CAT._ball(manubrio, r, sasso if r < 0.08 else sasso_scuro,
					Vector3(0, 0, sz2 * 0.12), Vector3(0.85, 0.9, 1.0))

	# e le due pietre col manico di corda, a terra davanti
	for sx2: float in [-1.0, 1.0]:
		var pietra := Node3D.new()
		pietra.position = Vector3(sx2 * 0.26, 0.0, 0.34)
		pietra.rotation.y = sx2 * 0.5
		n.add_child(pietra)
		CAT._ball(pietra, 0.1, sasso_scuro, Vector3(0, 0.085, 0), Vector3(1.0, 0.8, 1.0))
		BUILDER.tube(pietra, [Vector3(-0.055, 0.13, 0), Vector3(0, 0.21, 0),
				Vector3(0.055, 0.13, 0)], [0.012, 0.014, 0.012], corda, 12, 7)
	_posto(n, Vector3(0, 0.0, 0.62), Vector3.BACK)
	return n
