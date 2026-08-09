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
## imbottito quel poco che serve a sembrare un cuscino disteso per terra —
## non una lastra a spigoli vivi, ma uno spessore che si vede lungo TUTTO
## il perimetro, angoli compresi. Le righe sono cordoncini TESSUTI, in
## rilievo e appena ondulati (un telaio a mano non tira una riga
## perfettamente dritta). In fondo il capo è ancora arrotolato — non un
## cilindro liscio, ma un rotolo con le spire di taglio in testa, legato
## da uno spago che lo avvolge a spirale invece di infilarlo come uno
## spiedo. E non è mai perfettamente steso: un angolo si solleva un poco,
## e un filo è sfuggito a una cucitura.
static func tappetino() -> Node3D:
	var n := Node3D.new()
	var tela := CAT._mat(SALVIA, SALVIA_DARK, 5.0, 0.45)
	var tela_ombra := CAT._mat(SALVIA_DARK, SALVIA_DARK.darkened(0.25), 4.0, 0.4)
	var riga := CAT._mat(CANVAS, CANVAS_DARK, 6.0, 0.4)
	var filo := CAT._mat(CANVAS, CANVAS_DARK, 4.0, 0.3)
	var spago := CAT._mat(CORDA, CUOIO, 7.0, 0.4)

	# misure del cuscino: lo spessore (spessore) è anche il raggio dei
	# bordi arrotondati, così box, cilindri e sfere d'angolo si toccano
	# esattamente e la sagoma resta continua da qualunque lato la si guardi
	var mezza_x := 0.31
	var mezza_z := 0.46
	var spessore := 0.017
	var inset_x := mezza_x - spessore
	var inset_z := mezza_z - spessore
	var top := spessore * 2.0

	# il corpo: una lastra centrale...
	CAT._box(n, Vector3(inset_x * 2.0, top, inset_z * 2.0), tela, Vector3(0, spessore, 0))
	# ...i quattro bordi arrotondati (mezzi cilindri, non spigoli)...
	for sx: float in [-1.0, 1.0]:
		CAT._cyl(n, spessore, spessore, inset_z * 2.0, tela, Vector3(sx * inset_x, spessore, 0)) \
				.rotation.x = PI * 0.5
	for sz: float in [-1.0, 1.0]:
		CAT._cyl(n, spessore, spessore, inset_x * 2.0, tela, Vector3(0, spessore, sz * inset_z)) \
				.rotation.z = PI * 0.5
	# ...e i quattro angoli: senza, i mezzi cilindri lasciano un taglio
	# quadrato proprio dove si vede di più, di tre quarti
	for sx2: float in [-1.0, 1.0]:
		for sz2: float in [-1.0, 1.0]:
			CAT._ball(n, spessore, tela, Vector3(sx2 * inset_x, spessore, sz2 * inset_z))

	# tre righe TESSUTE nel senso della lunghezza: cordoncini in rilievo
	# (un tubo morbido, non un rettangolo piatto incollato sopra) e
	# leggermente ondulati — ognuno con la propria irregolarità, altrimenti
	# tre righe identiche tradiscono il plotter e non il telaio
	var ondulazioni := [
		[0.0, 0.007, -0.004, 0.006, 0.0],
		[0.0, -0.005, 0.004, -0.006, 0.0],
		[0.0, 0.005, -0.006, 0.003, 0.0],
	]
	for i in 3:
		var sx3 := float(i - 1) * 0.19
		var pts: Array[Vector3] = []
		var raggi: Array[float] = []
		for j in 5:
			var z := lerpf(-0.4, 0.4, float(j) / 4.0)
			var jit: float = ondulazioni[i][j]
			pts.append(Vector3(sx3 + jit, top + 0.004, z))
			raggi.append(0.006 if (j == 0 or j == 4) else 0.009)
		BUILDER.tube(n, pts, raggi, riga, 14, 8)

	# la cucitura che chiude il bordo sui due fianchi lunghi
	_cucitura(n, Vector3(-mezza_x + 0.004, spessore * 1.3, -inset_z),
			Vector3(-mezza_x + 0.004, spessore * 1.3, inset_z), 13, filo, 0.0035)
	_cucitura(n, Vector3(mezza_x - 0.004, spessore * 1.3, -inset_z),
			Vector3(mezza_x - 0.004, spessore * 1.3, inset_z), 13, filo, 0.0035)
	# un filo sfuggito alla cucitura, vicino a un angolo: giace quasi
	# orizzontale lungo il bordo (non appeso come un ghiacciolo), e si
	# assottiglia verso la punta come farebbe una fibra sfilacciata davvero
	var sfilacciato := CAT._cyl(n, 0.0015, 0.0032, 0.028, spago,
			Vector3(mezza_x + 0.008, spessore * 0.7, inset_z - 0.05))
	sfilacciato.rotation = Vector3(0.15, 0.3, -1.42)

	# un angolo non perfettamente steso: la cerniera è un semplice bordo
	# dritto (rotazione su un solo asse — niente diagonali, che spostano il
	# lembo fuori squadro e lo fanno sembrare un pezzo staccato), il lembo
	# CRESCE verso fuori dalla cerniera (niente coda all'indietro, altrimenti
	# si vede il vuoto sotto) e si alza di pochi centimetri, appena oltre il
	# bordo — il dettaglio che dice che qualcuno ci si è steso ieri, non che
	# è appena stato srotolato
	var piega := Node3D.new()
	piega.position = Vector3(inset_x - 0.006, top - 0.001, inset_z - 0.03)
	n.add_child(piega)
	piega.rotation.z = 0.3
	CAT._box(piega, Vector3(0.06, spessore * 0.6, 0.06), tela, Vector3(0.03, spessore * 0.3, 0.0))
	# l'ombra della piega: una sottile riga più scura, piatta sul
	# tappetino, proprio sulla cerniera — non un blocco ritto
	CAT._box(n, Vector3(0.012, 0.0025, 0.07), tela_ombra,
			Vector3(inset_x - 0.006, top - 0.0006, inset_z - 0.03))

	# il capo arrotolato in fondo: non un cilindro liscio, ma un rotolo con
	# le spire di taglio in testa e lo spago avvolto a spirale
	var rullo := Node3D.new()
	rullo.position = Vector3(0, 0.062, -0.4)
	n.add_child(rullo)
	var corpo_rotolo := CAT._cyl(rullo, 0.062, 0.062, 0.58, tela, Vector3.ZERO)
	corpo_rotolo.rotation.z = PI * 0.5
	# le spire viste di taglio: anelli concentrici alternati, come uno
	# strofinaccio arrotolato tagliato a metà — sugli stessi due colori
	# della tela e delle righe, per dire che è la stessa stoffa arrotolata
	var bande := [
		[0.013, 0.023, riga], [0.029, 0.039, tela],
		[0.045, 0.055, riga], [0.058, 0.062, tela],
	]
	for xx: float in [-0.292, 0.292]:
		for banda: Array in bande:
			var r_in: float = banda[0]
			var r_out: float = banda[1]
			var m: Material = banda[2]
			var torus := TorusMesh.new()
			torus.inner_radius = r_in
			torus.outer_radius = r_out
			torus.rings = 22
			torus.ring_segments = 6
			var tm := MeshInstance3D.new()
			tm.mesh = torus
			tm.material_override = m
			tm.position = Vector3(xx, 0, 0)
			tm.rotation.z = PI * 0.5
			rullo.add_child(tm)
	# lo spago avvolto a spirale attorno al rotolo (un giro e un quarto, con
	# un piccolo nodo alla fine): non due anelli infilati come uno spiedo
	var giro_pts: Array[Vector3] = []
	var giro_raggi: Array[float] = []
	var ultimo := Vector3.ZERO
	for k in 9:
		var t := float(k) / 8.0
		var a := t * TAU * 1.15 + 0.3
		var p := Vector3(lerpf(-0.2, 0.2, t), 0.073 * sin(a), 0.073 * cos(a))
		giro_pts.append(p)
		giro_raggi.append(0.008)
		ultimo = p
	BUILDER.tube(rullo, giro_pts, giro_raggi, spago, 18, 8)
	CAT._ball(rullo, 0.013, spago, ultimo)

	_posto(n, Vector3(0, top + 0.003, 0.1), Vector3.BACK)
	return n


# ------------------------------------------------------------- la panca

## La panca dei pesi: due cavalletti a X con le zampe legate da corda dove
## incrociano la traversa, un cuscino di cuoio imbottito che si incurva a
## sella proprio a metà campata — dove i due cavalletti (a ±0.3, non al
## centro) lasciano il cuoio scoperto, ed è lì che ha ceduto sotto chi ci
## si è seduto per anni — e il bilanciere appoggiato sui montanti: un
## bastone di legno con due sassi di fiume infilati ai capi, ognuno
## sfaccettato a mano, mai un disco tornito.
static func panca_pesi() -> Node3D:
	var n := Node3D.new()
	var legno := CAT._mat(CAT.WOOD, CAT.WOOD_DARK, 6.0, 0.52)
	var chiaro := CAT._mat(CAT.WOOD_PALE, CAT.WOOD, 5.0, 0.45)
	var cuoio := CAT._mat(CUOIO, CUOIO_DARK, 5.5, 0.5)
	var cuoio_bottone := CAT._mat(CUOIO_DARK, CUOIO_DARK.darkened(0.3), 5.0, 0.45)
	var corda := CAT._mat(CORDA, CUOIO, 7.0, 0.4)
	var filo := CAT._mat(CANVAS, CANVAS_DARK, 4.0, 0.3)
	var sasso_a := CAT._mat(CAT.STONE, CAT.STONE_DARK, 3.2, 0.55)
	var sasso_b := CAT._mat(CAT.STONE_DARK, Color("8e857a"), 3.6, 0.5)

	# Un sasso di fiume vero non è mai un disco tornito: due lenti sferiche
	# appiattite e sovrapposte, ognuna col suo verso — la faccia sfaccettata
	# che nessun tornio farebbe mai. `rzx` inclina il corpo principale
	# (un'asimmetria DECISA, non un rumore a runtime), `offset`/`r2`
	# piazzano la gobba più piccola che rompe la simmetria residua.
	var _sasso := func(pos: Vector3, r: float, mat: Material, rzx: Vector2,
			offset: Vector3, r2: float) -> void:
		var corpo := CAT._ball(n, r, mat, pos, Vector3(0.36, 0.95, 1.06))
		corpo.rotation.x = rzx.x
		corpo.rotation.z = rzx.y
		var gobba := CAT._ball(n, r * r2, mat, pos + offset, Vector3(0.42, 0.86, 0.8))
		gobba.rotation.x = -rzx.y
		gobba.rotation.z = rzx.x * 0.6

	# --- i due cavalletti a X ---------------------------------------------
	var zampa_h := 0.5
	var zampa_ang := 0.32
	for sz: float in [-0.3, 0.3]:
		for sx: float in [-1.0, 1.0]:
			var theta := sx * zampa_ang
			var gamba := CAT._box(n, Vector3(0.055, zampa_h, 0.055), legno,
					Vector3(sx * 0.15, 0.24, sz))
			gamba.rotation.z = theta
			# il piede: una base larga un soffio, la zampa non affonda nel prato
			var bottom_x: float = sx * 0.15 + zampa_h * 0.5 * sin(theta)
			var bottom_y: float = 0.24 - zampa_h * 0.5 * cos(theta)
			CAT._box(n, Vector3(0.1, 0.02, 0.085), legno, Vector3(bottom_x, 0.01, sz))
			# la legatura di corda, dove la zampa incrocia la traversa a 0.3:
			# non è decorazione, è quello che tiene insieme un cavalletto vero
			var top_x: float = sx * 0.15 - zampa_h * 0.5 * sin(theta)
			var top_y: float = 0.24 + zampa_h * 0.5 * cos(theta)
			var t3 := (0.3 - bottom_y) / (top_y - bottom_y)
			var legatura := TorusMesh.new()
			legatura.inner_radius = 0.026
			legatura.outer_radius = 0.05
			legatura.rings = 16
			legatura.ring_segments = 6
			var lm := MeshInstance3D.new()
			lm.mesh = legatura
			lm.material_override = corda
			lm.position = Vector3(lerp(bottom_x, top_x, t3),
					0.3 + (0.01 if sz < 0.0 else -0.008), sz)
			lm.rotation.z = theta
			n.add_child(lm)
		# la traversa che unisce le due zampe di questo cavalletto
		CAT._box(n, Vector3(0.42, 0.04, 0.05), legno, Vector3(0, 0.3, sz))
	# la traversa centrale che unisce i due cavalletti fra loro
	CAT._box(n, Vector3(0.05, 0.05, 0.66), legno, Vector3(0, 0.2, 0))

	# --- il cuscino ---------------------------------------------------------
	# Non più un box con due cilindri ai bordi (si vedeva la giuntura): un
	# tubo rastremato, chiuso a lozenga ai due capi, in un nodo a sé
	# SCHIACCIATO in altezza — e con un vero avvallamento a metà campata,
	# proprio dove i due cavalletti (a ±0.3) lasciano il cuoio scoperto.
	var cuscino := Node3D.new()
	cuscino.position = Vector3(0, 0.573, 0)
	cuscino.scale = Vector3(1.0, 0.62, 1.0)
	n.add_child(cuscino)
	BUILDER.tube(cuscino, [
		Vector3(0, 0.0, -0.44), Vector3(0, 0.0, -0.3), Vector3(0, -0.045, 0.0),
		Vector3(0, 0.0, 0.3), Vector3(0, 0.0, 0.44),
	], [0.02, 0.155, 0.148, 0.155, 0.02], cuoio, 26, 16)
	# tre bottoni di trapuntatura, incassati proprio dove il cuoio è più
	# basso: il segno di chi ci si siede sempre nello stesso punto
	for tz: float in [-0.18, 0.0, 0.18]:
		var top_l: float = lerpf(0.103, 0.155, absf(tz) / 0.3)
		CAT._ball(cuscino, 0.02, cuoio_bottone, Vector3(0, top_l - 0.015, tz),
				Vector3(1.0, 0.45, 1.0))
	# le due cuciture laterali, in coordinate VERE e non nel nodo schiacciato
	# (una cucitura già dritta, sotto uno scale non uniforme, taglierebbe
	# storta) — spezzate a metà per seguire l'avvallamento
	for sxc: float in [-0.135, 0.135]:
		_cucitura(n, Vector3(sxc, 0.573, -0.28), Vector3(sxc, 0.545, 0.0), 6, filo)
		_cucitura(n, Vector3(sxc, 0.545, 0.0), Vector3(sxc, 0.573, 0.28), 6, filo)

	# --- i due montanti col bilanciere in appoggio ---------------------------
	# I montanti erano due scatole SOSPESE: cominciavano a y=0.52 con mezzo
	# metro di NIENTE sotto. Nulla poteva reggerli — le zampe del cavalletto
	# convergono verso l'interno (in cima stanno a x≈0.07) e arrivano a
	# z=-0.328, la traversa si ferma a x=0.21, il cuscino a questa z è largo
	# 0.097 — così il bilanciere coi sassi restava appeso al vuoto. Ora il
	# montante parte DA TERRA, e la sua altezza non è più un numero per conto
	# suo: è la quota della forcella. Se un giorno il bilanciere si alza, il
	# palo si allunga da solo e non può tornare a galleggiare.
	var forcella_y := 0.96
	for sx4: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.06, forcella_y, 0.06), chiaro,
				Vector3(sx4 * 0.26, forcella_y * 0.5, -0.36))
		# la forcella dove si appoggia il bastone
		var forc := CAT._box(n, Vector3(0.05, 0.1, 0.12), chiaro,
				Vector3(sx4 * 0.26, forcella_y, -0.36))
		forc.rotation.x = 0.25
		# un cuscinetto di cuoio nella forcella: protegge il legno dal
		# bastone di pietra, e fa il paio col cuoio del cuscino sopra
		CAT._ball(n, 0.05, cuoio, Vector3(sx4 * 0.26, 0.975, -0.345),
				Vector3(1.25, 0.55, 1.0))
	var bilanciere := CAT._cyl(n, 0.028, 0.028, 0.92, chiaro, Vector3(0, 0.99, -0.36))
	bilanciere.rotation.z = PI * 0.5

	# i sassi di fiume infilati ai capi: due misure, ognuno con la sua gobba
	for sx5: float in [-1.0, 1.0]:
		_sasso.call(Vector3(sx5 * 0.36, 0.99, -0.36), 0.12, sasso_a,
				Vector2(0.16, sx5 * -0.1), Vector3(sx5 * -0.02, 0.045, -0.06), 0.55)
		_sasso.call(Vector3(sx5 * 0.44, 0.99, -0.36), 0.09, sasso_b,
				Vector2(-0.14, sx5 * 0.12), Vector3(sx5 * 0.018, -0.03, 0.05), 0.5)

	_posto(n, Vector3(0, 0.64, 0.06), Vector3.BACK)
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
## toppe sono cuscinetti a sfera schiacciata, allungati e storti sul
## proprio asse, col bordo cucito tutt'intorno — una sfera si posa bene
## su una pancia che curva anche in verticale, una tessera piatta no.
static func sacco() -> Node3D:
	var n := Node3D.new()
	var legno := CAT._mat(CAT.WOOD, CAT.WOOD_DARK, 4.0, 0.5)
	var tela := CAT._mat(CANVAS, CANVAS_DARK, 5.0, 0.5)
	var tela_cucitura := CAT._mat(CANVAS_DARK.darkened(0.08), CANVAS_DARK.darkened(0.22), 4.0, 0.35)
	var toppa_verde := CAT._mat(SALVIA, SALVIA_DARK, 6.0, 0.45)
	var toppa_cuoio := CAT._mat(CUOIO, CUOIO_DARK, 6.0, 0.45)
	var indaco := Color("7c8bab")
	var indaco_scuro := Color("5c6a86")
	var toppa_indaco := CAT._mat(indaco, indaco_scuro, 6.0, 0.45)
	var corda := CAT._mat(CORDA, CUOIO, 7.0, 0.4)
	var filo := CAT._mat(CANVAS_DARK.darkened(0.22), CANVAS.darkened(0.02), 4.0, 0.3)

	# IL PALO STA DIETRO. Il fronte dei pezzi è -Z: col palo davanti, dal
	# lato da cui si guarda (e da cui si tira il pugno) il sacco spariva
	# dietro un pezzo di legno.
	CAT._box(n, Vector3(0.44, 0.07, 0.44), legno, Vector3(0, 0.035, 0.32))
	CAT._box(n, Vector3(0.11, 2.0, 0.11), legno, Vector3(0, 1.0, 0.32))
	# la mensola diagonale: un palo dritto sarebbe una sbarra, questa è
	# una spalla
	# IL PUNTONE RESTA DIETRO AL SACCO. Lungo 0.52 e inclinato di 0.8, il suo
	# piede finiva a z 0.02: dentro il sacco, che a quell'altezza occupa da
	# −0.28 a +0.12. La traversa lo trapassava da parte a parte e riemergeva
	# davanti alla toppa verde, come un blocchetto sospeso. Adesso va dal
	# palo (z 0.32, y 1.40) su fino a 1.70 fermandosi a z 0.20, che è oltre
	# il fianco del sacco a quella quota.
	var puntone := CAT._box(n, Vector3(0.07, 0.33, 0.07), legno, Vector3(0, 1.55, 0.26))
	puntone.rotation.x = -0.38
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
	# segue un vero arco (gli ultimi cinque punti disegnano una calotta,
	# non un cono che si chiude di scatto)
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
		var r_avv: float = raggio_a_altezza.call(y_avv) * 1.14
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
			# la striscia va appoggiata FUORI dal tessuto (raggio vero +
			# margine), mai dentro: un box quasi tutto annegato nella
			# mesh del lathe fa z-fighting con la superficie e si vede
			# come un'asta grigia tremolante, non come una cucitura
			var z := r + 0.004
			CAT._box(giro, Vector3(0.011, absf(y_basso - y_alto) * 0.94, 0.006),
					tela_cucitura, Vector3(0, y_mezzo, z))
			# il punto a zig-zag: `_cucitura` orienta il filo per cuciture
			# ORIZZONTALI (usa atan2 su x/z), ma questa corre in VERTICALE —
			# usata così com'è, ogni punto resta con la lunghezza sull'asse
			# radiale e spunta come un ago piantato di traverso, non come
			# un punto steso sulla stoffa. Qui si scrive a mano: lunghezza
			# su Y (lungo la cucitura), leggero scarto alterno su Z, un
			# punto ogni 3 cm — il classico punto erba di chi cuce a mano.
			# (E anche questi punti stanno sopra la striscia, fuori dalla
			# mesh: stesso principio, stesso errore da non ripetere.)
			var n_punti := maxi(5, int(absf(y_basso - y_alto) / 0.032))
			var occhiello: float = (absf(y_basso - y_alto) - 0.03) / float(n_punti) * 0.62
			for i in range(n_punti):
				var u := (float(i) + 0.5) / float(n_punti)
				var y_i := lerpf(y_alto - 0.015, y_basso + 0.015, u)
				var punto := CAT._box(giro, Vector3(0.003, occhiello, 0.0032), filo,
						Vector3(0, y_i, z + 0.0046))
				punto.rotation.z = 0.3 if i % 2 == 0 else -0.3

	# LE TOPPE. Cuscinetti a sfera schiacciata (come una sfera si posa
	# bene su una pancia che curva sia in verticale sia in giro — una
	# tessera piatta no: su un raggio di ~0.2 m una toppa di 13-15 cm è
	# grande abbastanza da lasciare uno spiraglio visibile sotto i bordi),
	# allungati e storti sul proprio asse (un rattoppo vero non è mai un
	# ovale dritto), col bordo cucito tutt'intorno, e uno con l'angolo
	# smussato, come se fosse stato ritagliato da uno scampolo più grande.
	_toppa(sacco, 2.5, -0.6, 0.075, Vector3(1.0, 1.35, 0.42), 0.26, toppa_verde,
			filo, raggio_a_altezza, true)
	_toppa(sacco, -2.35, -0.68, 0.058, Vector3(1.0, 1.3, 0.4), -0.34, toppa_cuoio,
			filo, raggio_a_altezza, false)
	_toppa(sacco, 3.55, -0.53, 0.042, Vector3(1.0, 1.25, 0.38), 0.18, toppa_indaco,
			filo, raggio_a_altezza, false)

	_posto(n, Vector3(0, 0.0, -0.64), Vector3.BACK)
	return n


## Una toppa cucita sul sacco: una sfera schiacciata (allungata e appena
## storta sul proprio asse — un rattoppo vero non è mai un ovale dritto),
## non una tessera piatta: su una pancia che curva sia in verticale sia
## in giro, una sfera si "salda" alla curva anche se il centro è appena
## incassato, mentre una faccia piatta lascia uno spiraglio visibile sotto
## i bordi (l'ha dimostrato il primo tentativo, a tessere rettangolari).
## Appena incassata e per il resto ben fuori dal tessuto — non fluttua,
## non annega — e il bordo cucito segue punto per punto il raggio VERO
## del sacco (`raggio_a_altezza`), perché la pancia curva anche sotto una
## toppa non piccola.
static func _toppa(sacco: Node3D, angolo: float, y: float, raggio: float,
		scl: Vector3, rot_extra: float, mat: Material, filo: Material,
		raggio_a_altezza: Callable, taglio: bool) -> void:
	var giro := Node3D.new()
	giro.rotation.y = angolo
	sacco.add_child(giro)
	var r: float = raggio_a_altezza.call(y)
	var mezzo_z: float = raggio * scl.z
	# LA TOPPA È CUCITA SUL SACCO, quindi sta MEZZA DENTRO. Spinta fuori di
	# oltre metà del proprio spessore (0.55) diventava una bolla appoggiata
	# sopra il tessuto, e dove la superficie curva via — di tre quarti — si
	# staccava del tutto dalla sagoma. Un decimo basta a evitare lo
	# z-fighting senza farla galleggiare.
	var palla := CAT._ball(giro, raggio, mat, Vector3(0, y, r + mezzo_z * 0.10), scl)
	palla.rotation.z = rot_extra
	var cs := cos(rot_extra)
	var sn := sin(rot_extra)
	if taglio:
		# l'angolo smussato: un PICCOLO morso dello stesso tessuto del
		# sacco, vicino al bordo — un nibble, non mezza toppa mangiata:
		# troppo grande o troppo al centro (l'errore del primo tentativo)
		# copriva il cuscinetto e ci si mangiava anche la cucitura sotto
		var ex := raggio * scl.x * 0.55
		var ey := raggio * scl.y * 0.5
		var mx := ex * cs - ey * sn
		var my := ex * sn + ey * cs
		var morso := CAT._ball(giro, raggio * 0.34, CAT._mat(CANVAS, CANVAS_DARK, 5.0, 0.5),
				Vector3(mx, y + my, r + mezzo_z * 0.62), scl)
		morso.rotation.z = rot_extra
	# il bordo cucito: punti tutt'intorno all'ellisse vera della toppa,
	# appena oltre la sua sagoma (sulla tela nuda, non sulla toppa), ognuno
	# appoggiato sul SUO raggio — non un piano fisso, che vicino ai poli
	# della sfera schiacciata galleggerebbe o affonderebbe.
	var n_bordo := 16
	for i in range(n_bordo):
		var a := float(i) / float(n_bordo) * TAU
		var ex2 := cos(a) * raggio * scl.x * 1.08
		var ey2 := sin(a) * raggio * scl.y * 1.08
		var rpx := ex2 * cs - ey2 * sn
		var rpy := ex2 * sn + ey2 * cs
		var y_qui := y + rpy
		var r_qui: float = raggio_a_altezza.call(y_qui)
		CAT._box(giro, Vector3(0.011, 0.011, 0.0032), filo,
				Vector3(rpx, y_qui, r_qui + 0.0075))


# ----------------------------------------------------------- la cyclette

## La cyclette: il telaio di un carretto a cui hanno tolto tutto tranne una
## ruota, e ci hanno montato sopra una sella. La ruota sta DAVANTI (il
## fronte dei pezzi è -Z), la sella dietro, e in mezzo c'è un telaio che si
## tocca — una bicicletta fatta di bastoni sospesi non è una bicicletta.
##
## La ruota gira sul suo asse VERO: orizzontale, sinistra-destra — lo
## stesso della pedaliera che ci si innesta sopra (trasmissione diretta,
## come un vecchio velocipede: niente catena, i pedali girano il mozzo).
## Guardata di profilo mostra la faccia piena coi raggi; guardata di fronte
## mostra il bordo sottile, come una ruota di bicicletta vera — non una
## moneta piantata a faccia in avanti verso chi guarda.
static func cyclette() -> Node3D:
	var n := Node3D.new()
	var legno := CAT._mat(CAT.WOOD, CAT.WOOD_DARK, 4.0, 0.5)
	var chiaro := CAT._mat(CAT.WOOD_PALE, CAT.WOOD, 3.5, 0.45)
	var cuoio := CAT._mat(CUOIO, CUOIO_DARK, 5.0, 0.5)
	var ferro := CAT._mat(CAT.METAL, Color("6d6259"), 5.0, 0.4)
	var borchia := CAT._mat(Color("4a423a"), Color("2f2a24"), 3.5, 0.4)
	var corda := CAT._mat(CORDA, CUOIO, 7.0, 0.4)
	var ruggine := CAT._mat(Color("8a5a3e"), Color("5c3c28"), 4.0, 0.55)
	var filo := CAT._mat(CANVAS, CANVAS_DARK, 4.0, 0.3)

	# una legatura (corda o ferro) intorno a un bastone: un anello sottile
	# il cui asse combacia con la rotazione del bastone che stringe — così
	# lo abbraccia invece di infilzarlo di traverso
	var _legatura := func(pos: Vector3, ang: float, raggio_bastone: float,
			spessore: float, mat: Material) -> void:
		var t := TorusMesh.new()
		t.inner_radius = raggio_bastone
		t.outer_radius = raggio_bastone + spessore
		t.rings = 16
		t.ring_segments = 8
		var m := MeshInstance3D.new()
		m.mesh = t
		m.material_override = mat
		m.position = pos
		m.rotation.x = ang
		n.add_child(m)

	# i due pattini a terra, uniti davanti e dietro: sta in piedi da sola
	for sx: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.07, 0.06, 0.86), legno, Vector3(sx * 0.2, 0.03, 0))
	for sz: float in [-0.38, 0.36]:
		CAT._box(n, Vector3(0.47, 0.05, 0.08), legno, Vector3(0, 0.03, sz))

	# LA RUOTA davanti: mozzo con flange e borchie, cerchione di legno più
	# spesso, la cerchiatura di ferro (il "pneumatico" di un vero carretto)
	# calzata sul bordo, e dodici raggi rastremati — spessi al mozzo,
	# sottili al cerchio, come li taglierebbe un carraio e non come fili
	# di ferro dritti tutti uguali.
	var ruota := Node3D.new()
	ruota.position = Vector3(0, 0.4, -0.3)
	n.add_child(ruota)

	var hub_r := 0.062
	var felloe_in := 0.255
	var felloe_out := 0.335

	# il mozzo: un tamburo fra due flange coi bulloni in vista. L'asse è
	# orizzontale sinistra-destra (X), lo stesso della pedaliera: senza
	# catena, ruota e pedali girano insieme sullo stesso perno.
	CAT._cyl(ruota, 0.046, 0.046, 0.13, ferro, Vector3.ZERO).rotation.z = PI * 0.5
	for xf: float in [-0.062, 0.062]:
		CAT._cyl(ruota, 0.078, 0.078, 0.018, ferro, Vector3(xf, 0, 0)) \
				.rotation.z = PI * 0.5
		var bx: float = xf + (0.012 if xf > 0.0 else -0.012)
		for b in 5:
			var ang_b := float(b) / 5.0 * TAU
			CAT._cyl(ruota, 0.009, 0.009, 0.016, borchia,
					Vector3(bx, 0.058 * cos(ang_b), 0.058 * sin(ang_b))) \
					.rotation.z = PI * 0.5

	# il cerchione, liscio (molti anelli e segmenti) — e sullo stesso
	# piano del mozzo (rotation.z, non rotation.x: qui viveva il difetto,
	# invisibile di fronte e di tre quarti, smascherato solo di profilo,
	# dove i raggi vecchi finivano fuori dal bordo)
	var cerchio := TorusMesh.new()
	cerchio.inner_radius = felloe_in
	cerchio.outer_radius = felloe_out
	cerchio.rings = 44
	cerchio.ring_segments = 16
	var mi := MeshInstance3D.new()
	mi.mesh = cerchio
	mi.material_override = chiaro
	mi.rotation.z = PI * 0.5
	ruota.add_child(mi)
	# la cerchiatura di ferro, calzata a filo sul bordo esterno
	var cerchiatura := TorusMesh.new()
	cerchiatura.inner_radius = felloe_out - 0.01
	cerchiatura.outer_radius = felloe_out + 0.015
	cerchiatura.rings = 44
	cerchiatura.ring_segments = 8
	var mi2 := MeshInstance3D.new()
	mi2.mesh = cerchiatura
	mi2.material_override = ferro
	mi2.rotation.z = PI * 0.5
	ruota.add_child(mi2)

	# i raggi: dodici, dal mozzo al cerchio, rastremati — e nel PIANO
	# giusto (Y-Z, lo stesso del cerchione), non in un piano ortogonale
	# messo lì senza verificarlo di profilo
	var spoke_end := felloe_in + 0.02
	var spoke_len := spoke_end - hub_r
	var spoke_mid := (hub_r + spoke_end) * 0.5
	for i in 12:
		var ang := float(i) / 12.0 * TAU
		var dir := Vector3(0, cos(ang), sin(ang))
		CAT._cyl(ruota, 0.009, 0.017, spoke_len, legno, dir * spoke_mid) \
				.rotation.x = ang

	# IL TELAIO, che si tocca: forcella con la sua corona (non due gambe
	# sospese), trave obliqua fino al reggisella, e piantone del manubrio.
	# Alle giunture, le legature: corda dove i villici avrebbero legato il
	# legno, ferro dove serve una stretta vera (l'attacco del manubrio).
	for sx2: float in [-1.0, 1.0]:
		var forc := CAT._box(n, Vector3(0.05, 0.46, 0.05), legno,
				Vector3(sx2 * 0.075, 0.6, -0.24))
		forc.rotation.x = -0.28
		_legatura.call(Vector3(sx2 * 0.075, 0.379, -0.176), -0.28, 0.038, 0.014, corda)
	# la corona: chiude le due gambe della forcella in cima, come farebbe
	# una forcella vera — senza, sono due bastoni che finiscono nel vuoto
	var corona := CAT._box(n, Vector3(0.22, 0.05, 0.13), legno, Vector3(0, 0.815, -0.27))
	corona.rotation.x = -0.28
	var trave := CAT._box(n, Vector3(0.075, 0.78, 0.075), legno, Vector3(0, 0.5, -0.03))
	trave.rotation.x = 0.72
	var reggisella := CAT._box(n, Vector3(0.07, 0.62, 0.07), legno, Vector3(0, 0.6, 0.24))
	reggisella.rotation.x = -0.12
	_legatura.call(Vector3(0, 0.793, 0.222), 0.72, 0.05, 0.016, corda)
	var piantone := CAT._box(n, Vector3(0.06, 0.58, 0.06), legno, Vector3(0, 0.78, -0.21))
	piantone.rotation.x = 0.1
	_legatura.call(Vector3(0, 1.055, -0.192), 0.1, 0.045, 0.02, ferro)

	# IL GANCIO DI TRAINO, arrugginito e non più usato: il segno che questo
	# telaio era un carretto prima che qualcuno ci montasse sopra una sella
	BUILDER.tube(n, [Vector3(0, 0.09, 0.4), Vector3(0.025, 0.045, 0.45),
			Vector3(-0.015, 0.02, 0.43)], [0.013, 0.015, 0.009], ruggine, 12, 7)

	# LA SELLA: una goccia di cuoio, larga dietro e a punta davanti, con
	# l'attacco di ferro sotto, il rivetto al naso e la cucitura in cima —
	# calcolata sulla curva vera dei due ellissoidi (non a occhio: a occhio
	# la cucitura fluttuava sopra il cuoio invece di seguirlo)
	var sella := Node3D.new()
	sella.position = Vector3(0, 0.92, 0.22)
	n.add_child(sella)
	# larga dietro, a punta davanti: una sella è un triangolo smussato,
	# non un cuscino tondo (che da sopra sembra un berretto)
	CAT._ball(sella, 0.105, cuoio, Vector3(0, 0, 0.05), Vector3(0.78, 0.34, 0.95))
	var punta := CAT._ball(sella, 0.085, cuoio, Vector3(0, -0.008, -0.11),
			Vector3(0.42, 0.3, 2.0))
	punta.rotation.x = -0.1
	CAT._ball(sella, 0.012, ferro, Vector3(0, -0.018, -0.185))
	CAT._cyl(sella, 0.02, 0.02, 0.06, ferro, Vector3(0, -0.05, 0.02))
	# la cucitura centrale, in cima: due tratti che seguono il dorso dei
	# due ellissoidi (il cuscino dietro, la punta davanti), non una corda
	# tesa fra due punti a caso — punti presi sulla superficie vera,
	# altrimenti la cucitura fluttua sopra il cuoio invece di seguirlo
	_cucitura(sella, Vector3(0, 0.031, 0.10), Vector3(0, 0.035, 0.02), 5, filo)
	_cucitura(sella, Vector3(0, 0.017, -0.08), Vector3(0, 0.011, -0.22), 5, filo)

	# IL MANUBRIO: un tubo curvo con le due impugnature di cuoio, coi
	# tappi in fondo, e la staffa che lo stringe sul piantone
	BUILDER.tube(n, [Vector3(-0.21, 0.98, -0.12), Vector3(-0.07, 1.04, -0.2),
			Vector3(0.07, 1.04, -0.2), Vector3(0.21, 0.98, -0.12)],
			[0.015, 0.018, 0.018, 0.015], chiaro, 16, 8)
	for sx3: float in [-1.0, 1.0]:
		CAT._cyl(n, 0.023, 0.023, 0.1, cuoio, Vector3(sx3 * 0.22, 0.975, -0.115)) \
				.rotation.z = PI * 0.5
		CAT._ball(n, 0.02, cuoio, Vector3(sx3 * 0.27, 0.975, -0.115))

	# LA PEDALIERA: manovella cilindrica sul mozzo, perno passante, e due
	# pedali in controfase con la superficie zigrinata (i tacchetti)
	for sx4: float in [-1.0, 1.0]:
		var manovella := Node3D.new()
		manovella.position = Vector3(sx4 * 0.075, 0.4, -0.3)
		manovella.rotation.x = 0.9 if sx4 > 0 else 0.9 + PI
		n.add_child(manovella)
		CAT._cyl(manovella, 0.018, 0.018, 0.19, ferro, Vector3(0, 0.085, 0))
		CAT._cyl(manovella, 0.011, 0.011, 0.05, ferro, Vector3(sx4 * 0.035, 0.175, 0)) \
				.rotation.z = PI * 0.5
		var pedale := CAT._box(manovella, Vector3(0.075, 0.02, 0.11), legno,
				Vector3(sx4 * 0.035, 0.175, 0))
		pedale.rotation.x = -manovella.rotation.x
		for gx: float in [-0.02, 0.02]:
			for gz: float in [-0.03, 0.03]:
				CAT._cyl(pedale, 0.006, 0.006, 0.012, borchia, Vector3(gx, 0.016, gz))
	_posto(n, Vector3(0, 0.97, 0.22), Vector3.FORWARD)
	return n

# ------------------------------------------------------ la sbarra e gli anelli

## Due tronchi veri (rastremati come un palo tagliato, non due squadre di
## legno), una sbarra, e due anelli che il tempo ha levigato. È l'attrezzo
## più semplice della palestra — e il più alto — ed è quello che riempie
## di più lo spazio: si vede da lontano che lì qualcuno si tira su.
##
## Ogni giunzione ha il suo rinforzo VISIBILE: i vicini l'hanno legata con
## la corda, non inchiodata — un tassello di fune dove il puntone morde il
## palo, dove la traversa lo attraversa, dove la mensola arriva sotto la
## sbarra. E i puntoni non sono assi dritte: sono rami, spessi dove
## portano il carico (a terra e contro il palo) e sottili in mezzo, come
## fa davvero il legno quando lavora.
static func sbarra_trazione() -> Node3D:
	var n := Node3D.new()
	var legno := CAT._mat(CAT.WOOD, CAT.WOOD_DARK, 4.0, 0.5)
	var chiaro := CAT._mat(CAT.WOOD_PALE, CAT.WOOD, 3.5, 0.45)
	# gli anelli non condividono la tinta della sbarra: sono la parte che
	# centinaia di zampe hanno impugnato, e il legno impugnato si leviga e
	# si scalda — meno venatura, un pelo più chiaro
	var levigato := CAT._mat(CAT.WOOD_PALE.lightened(0.08), CAT.WOOD_PALE, 2.0, 0.22)
	var corda := CAT._mat(CORDA, CUOIO, 7.0, 0.4)
	var sasso := CAT._mat(CAT.STONE, CAT.STONE_DARK, 3.0, 0.5)

	var cima_palo := 2.16
	var raggio_base := 0.052
	var raggio_cima := 0.036
	# il raggio vero del tronco a una quota: serve a far combaciare le
	# fasciature e gli attacchi dei puntoni alla superficie reale, non a
	# un numero indovinato
	var raggio_palo := func(y: float) -> float:
		return lerpf(raggio_base, raggio_cima, clampf(y / cima_palo, 0.0, 1.0))

	# una fasciatura di corda: l'anello stretto che i vicini hanno legato
	# dove due pezzi si incontrano, invece di un chiodo a vista
	var lega := func(pos: Vector3, raggio: float) -> void:
		var t := TorusMesh.new()
		t.inner_radius = raggio
		t.outer_radius = raggio + 0.016
		t.rings = 16
		t.ring_segments = 6
		var mi := MeshInstance3D.new()
		mi.mesh = t
		mi.material_override = corda
		mi.position = pos
		n.add_child(mi)

	for sx: float in [-1.0, 1.0]:
		# LA PIETRA DI BASE: il tronco non nasce dal nulla, affonda in una
		# lastra di fiume — lo stesso sasso della panca e della rastrelliera
		CAT._cyl(n, 0.14, 0.17, 0.045, sasso, Vector3(sx * 0.4, 0.0225, 0))
		# e una piccola pietra dov'è piantato il puntone, davanti
		CAT._ball(n, 0.065, sasso, Vector3(sx * 0.4, 0.036, 0.27),
				Vector3(1.15, 0.55, 1.35))

		# IL TRONCO: rastremato verso l'alto come un vero palo tagliato,
		# non un parallelepipedo — è quello che si vede da un chilometro
		CAT._cyl(n, raggio_cima, raggio_base, cima_palo, legno,
				Vector3(sx * 0.4, cima_palo * 0.5, 0))
		# il cappello arrotondato in cima, a far scorrere via la pioggia
		# invece di lasciarla marcire nella fibra tagliata
		CAT._ball(n, 0.043, chiaro, Vector3(sx * 0.4, cima_palo + 0.016, 0),
				Vector3(1.0, 0.68, 1.0))

		# IL PUNTONE di terra: non un'asse dritta, un ramo vero — spesso
		# dove scarica il peso (a terra e contro il palo), sottile nel
		# tratto libero in mezzo, con un accenno di curva
		BUILDER.tube(n, [
			Vector3(sx * 0.4, 0.0, 0.27),
			Vector3(sx * 0.4, 0.27, 0.20),
			Vector3(sx * 0.4, 0.52, raggio_palo.call(0.52)),
		], [0.042, 0.024, 0.034], legno, 14, 8)
		lega.call(Vector3(sx * 0.4, 0.52, 0.0), raggio_palo.call(0.52))

		# LA MENSOLA sotto la sbarra: un puntello corto che chiude l'angolo
		# fra il palo e la sbarra, proprio dove si scarica la trazione
		BUILDER.tube(n, [
			Vector3(sx * 0.4, 1.86, 0.0),
			Vector3(sx * 0.4 * 0.78, 2.01, 0.025),
			Vector3(sx * 0.4 * 0.54, 2.10, 0.036),
		], [0.025, 0.015, 0.021], legno, 12, 8)
		lega.call(Vector3(sx * 0.4, 1.86, 0.0), raggio_palo.call(1.86))

	# LA TRAVERSA bassa che chiude il telaio: senza, due pali e una barra
	# in cima sono una forca, non un attrezzo — anche lei un tondino, non
	# uno spigolo vivo
	CAT._cyl(n, 0.028, 0.028, 0.85, legno, Vector3(0, 0.52, 0)).rotation.z = PI * 0.5

	# LA SBARRA, un filo più chiara: è la parte che si tocca
	var barra := CAT._cyl(n, 0.034, 0.034, 0.94, chiaro, Vector3(0, 2.12, 0))
	barra.rotation.z = PI * 0.5
	# e le fasciature di corda ai due capi, dove ci si aggrappa
	for sx2: float in [-1.0, 1.0]:
		CAT._cyl(n, 0.039, 0.039, 0.14, corda, Vector3(sx2 * 0.3, 2.12, 0)) \
				.rotation.z = PI * 0.5

	# GLI ANELLI, appesi al centro: due nodi a sé, pivot in alto — in cima
	# alla corda, non nel mezzo dell'anello, o oscillerebbero dall'ombelico
	for sx3: float in [-1.0, 1.0]:
		var appeso := Node3D.new()
		appeso.name = "anello_%s" % ("sx" if sx3 < 0 else "dx")
		appeso.position = Vector3(sx3 * 0.13, 2.1, 0)
		n.add_child(appeso)
		# il nodo in cima, dove la corda è legata alla sbarra
		var nodo := TorusMesh.new()
		nodo.inner_radius = 0.017
		nodo.outer_radius = 0.030
		nodo.rings = 14
		nodo.ring_segments = 6
		var nm := MeshInstance3D.new()
		nm.mesh = nodo
		nm.material_override = corda
		nm.rotation.z = PI * 0.5
		nm.position = Vector3(0, 0.015, 0)
		appeso.add_child(nm)
		# la corda: non un cilindro dritto, un filo che si assesta con un
		# accenno di torsione, più sottile dove incontra l'anello
		BUILDER.tube(appeso, [
			Vector3(0, 0.0, 0),
			Vector3(sx3 * 0.018, -0.19, 0.014),
			Vector3(sx3 * -0.012, -0.38, -0.01),
		], [0.0115, 0.0105, 0.0088], corda, 12, 7)
		# l'ANELLO: sezione leggermente ovale (un tornio a mano non è
		# perfetto) e legno levigato — mai due identici al millimetro
		var anello := TorusMesh.new()
		anello.inner_radius = 0.055
		anello.outer_radius = 0.076
		anello.rings = 22
		anello.ring_segments = 8
		var am := MeshInstance3D.new()
		am.mesh = anello
		am.material_override = levigato
		am.rotation.x = PI * 0.5
		am.position = Vector3(0, -0.46, 0)
		am.scale = Vector3(1.0 + sx3 * 0.01, 0.93 - sx3 * 0.015, 1.04)
		appeso.add_child(am)

	_posto(n, Vector3(0, 0.0, 0.34), Vector3.FORWARD)
	return n


# ------------------------------------------------------------- lo specchio

## Lo specchio della palestra: una cornice a più piani — modanatura scura,
## filetto chiaro incassato dove il vetro si incastra (la "battuta" delle
## cornici vere, con le sue bullette d'ottone agli angoli) — appena
## inclinata all'indietro sul suo cavalletto, con un anello appeso alla
## schiena che tradisce un muro che non ha più. Non riflette davvero —
## sarebbe un secondo mondo da disegnare — ma fa quello che fa uno
## specchio in un disegno: il vetro schiarisce verso il cielo e si scurisce
## verso il pavimento, e sopra ci stanno lame di riflesso di spessori e
## luminosità diversi, come càpita guardando un vetro vero — non una sola
## lama uguale a se stessa.
static func specchio() -> Node3D:
	var n := Node3D.new()
	var legno := CAT._mat(CAT.WOOD, CAT.WOOD_DARK, 4.0, 0.5)
	var chiaro := CAT._mat(CAT.WOOD_PALE, CAT.WOOD, 3.5, 0.45)
	var rame := CAT._mat(RAME, RAME.darkened(0.35), 5.0, 0.35)
	var consumo := CAT._mat(CAT.WOOD_DARK.darkened(0.12), CAT.WOOD_DARK.darkened(0.3), 2.0, 0.6)

	# il cavalletto dietro, che lo tiene in piedi (helper condiviso con la
	# rastrelliera: lasciato invariato)
	_zampe_a_cavalletto(n, legno)

	# la cornice, inclinata come uno specchio appoggiato al muro
	var quadro := Node3D.new()
	# IL PANNELLO STA DAVANTI ALLE ZAMPE. A z −0.06 il suo piede finiva
	# dentro le due zampe del cavalletto (che scendono fino a z −0.05), e di
	# profilo si vedeva il legno tagliare la tavola poco sopra il basamento.
	quadro.position = Vector3(0, 0.86, 0.02)
	quadro.rotation.x = 0.08
	n.add_child(quadro)

	# LA MODANATURA ESTERNA: il corpo scuro della cornice.
	for sx: float in [-1.0, 1.0]:
		CAT._box(quadro, Vector3(0.075, 1.66, 0.065), legno, Vector3(sx * 0.328, 0, 0))
	for sy: float in [-1.0, 1.0]:
		CAT._box(quadro, Vector3(0.731, 0.09, 0.065), legno, Vector3(0, sy * 0.80, 0))

	# IL FILETTO CHIARO, incassato un poco rispetto alla modanatura: è la
	# "battuta" dove il vetro si incastra, come nelle cornici vere — un
	# piano di profondità in più, non un secondo colore messo a caso. È
	# questo gradino (e l'ombra che si porta dietro) a dire "costruito",
	# non "disegnato piatto".
	for sx2: float in [-1.0, 1.0]:
		CAT._box(quadro, Vector3(0.04, 1.52, 0.02), chiaro, Vector3(sx2 * 0.266, 0, -0.02))
	for sy2: float in [-1.0, 1.0]:
		CAT._box(quadro, Vector3(0.575, 0.045, 0.02), chiaro, Vector3(0, sy2 * 0.735, -0.02))
	# le bullette d'ottone che "tengono" il filetto agli angoli: un
	# dettaglio che si vede solo di tre quarti o di profilo, ma è lì che
	# si vede se una cornice è stata costruita o solo disegnata
	for cx: float in [-1.0, 1.0]:
		for cy: float in [-1.0, 1.0]:
			CAT._ball(quadro, 0.013, rame, Vector3(cx * 0.266, cy * 0.735, -0.006),
					Vector3(1, 1, 0.55))
	# un poco di usura sul corrente in basso: nessuna cornice vera è
	# perfetta ovunque (le zampe del cavalletto coprono i montanti
	# laterali da quasi ogni vista, quindi il segno va sul corrente)
	var usura := CAT._box(quadro, Vector3(0.11, 0.028, 0.004), consumo,
			Vector3(0.18, -0.80, 0.034))
	usura.rotation.z = 0.12

	# IL VETRO, a tre fasce invece di una lastra unica: chiara e fredda in
	# alto (il cielo che ci si specchia), una fascia di passaggio, scura e
	# calda in basso (il pavimento) — un vetro vero non ha un colore solo.
	# Lucido come vetro davvero (metallic/roughness), non solo luminoso.
	var vetro_mat := func(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = albedo
		m.roughness = 0.07
		m.metallic = 0.32
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
		return m
	var cielo: StandardMaterial3D = vetro_mat.call(
			Color(0.82, 0.90, 0.95), Color(0.66, 0.80, 0.92), 0.26)
	var mezzo: StandardMaterial3D = vetro_mat.call(
			Color(0.72, 0.78, 0.80), Color(0.54, 0.62, 0.68), 0.18)
	var suolo: StandardMaterial3D = vetro_mat.call(
			Color(0.58, 0.58, 0.58), Color(0.40, 0.42, 0.46), 0.11)
	CAT._box(quadro, Vector3(0.49, 0.60, 0.018), cielo, Vector3(0, 0.4125, -0.035))
	CAT._box(quadro, Vector3(0.49, 0.25, 0.018), mezzo, Vector3(0, -0.0125, -0.035))
	CAT._box(quadro, Vector3(0.49, 0.575, 0.018), suolo, Vector3(0, -0.425, -0.035))

	# LE LAME DI RIFLESSO: non una sola, tre — larga e tenue, stretta e
	# brillante, e una minuscola scintilla di catch-light — additive e
	# senza ombreggiatura (si SOMMANO al vetro, non lo coprono: è così
	# che un riflesso vero si comporta, non come un adesivo lucido).
	var lama_mat := func(alpha: float) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(1, 1, 1, alpha)
		return m
	# (corte: le lame stanno dentro il vetro — un riflesso che sborda
	# dallo specchio non è un riflesso — e la cornice/il filetto davanti
	# le ritagliano da soli dove sconfinano, per come sono impilati in Z)
	var l1 := CAT._box(quadro, Vector3(0.10, 0.95, 0.006),
			lama_mat.call(0.14) as StandardMaterial3D, Vector3(-0.09, 0.12, -0.025))
	l1.rotation.z = 0.40
	var l2 := CAT._box(quadro, Vector3(0.03, 0.60, 0.006),
			lama_mat.call(0.55) as StandardMaterial3D, Vector3(0.10, -0.28, -0.025))
	l2.rotation.z = 0.40
	var l3 := CAT._box(quadro, Vector3(0.014, 0.15, 0.006),
			lama_mat.call(0.80) as StandardMaterial3D, Vector3(0.15, 0.34, -0.025))
	l3.rotation.z = 0.40

	# L'ANELLO alla schiena: un filo di storia — questo specchio è nato
	# per un muro, e adesso sta in piedi da solo. Da davanti la cornice lo
	# nasconde quasi del tutto; di profilo sporge appena, come un vero
	# gancio dimenticato dietro le spalle.
	var anello := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.018
	tm.outer_radius = 0.030
	tm.rings = 16
	tm.ring_segments = 8
	anello.mesh = tm
	anello.material_override = rame
	anello.position = Vector3(0, 0.80, -0.052)
	anello.rotation.x = PI * 0.5
	quadro.add_child(anello)

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
## LA FONTANELLA della palestra: dove ci si ferma a bere fra una serie e
## l'altra. Terza vita, e le prime due sono lezioni pagate.
##
## La PRIMA era una vasca di pietra su una colonna: da qualunque parte la
## si guardasse era un LAVANDINO. La SECONDA — una botte coricata su un
## cavalletto, con un truogolo di tavole per terra — e' finita dall'altra
## parte del bersaglio: l'autore, guardandola, ha chiesto se ci bevono i
## cavalli. Aveva ragione, ed e' colpa di UNA misura: il truogolo stava a
## 6 cm da terra. Qualunque recipiente d'acqua alla caviglia e' un
## abbeveratoio, per quanto bello sia il legno che gli sta sopra.
##
## Questa e' una fontanella da BERE IN PIEDI, e lo dice la quota: la
## botte sta DRITTA su uno zoccolo di sassi di fiume (gli stessi della
## rastrelliera: e' la stessa palestra), e a 66 cm — l'altezza del petto
## di un chibi — sporge sul davanti una CONCA di pietra scavata, piccola
## e personale, in cui cade il filo d'acqua dal collo di cigno di rame.
## Ci si sporge dentro e si beve; oppure si stacca la tazza di latta dal
## gancio. Ai cavalli non verrebbe in mente.
##
## Restano, perche' erano buoni: le doghe VERE lungo la pancia in tre
## tinte spaiate (lo spiraglio fra l'una e l'altra fa la giuntura da
## solo, senza dipingerla), i tre cerchi di ferro diversi fra loro con la
## colatura di ruggine sotto quello mangiato, e la tazza che DONDOLA —
## un oggetto appeso e fermo per sempre e' un oggetto incollato.
static func fontanella() -> Node3D:
	var n := Node3D.new()
	var legno := CAT._mat(CAT.WOOD, CAT.WOOD_DARK, 4.0, 0.5)
	var ferro := CAT._mat(CAT.METAL, Color("6d6259"), 5.0, 0.4)
	var rame := CAT._mat(RAME, RAME.darkened(0.3), 5.0, 0.4)
	var pietra := CAT._mat(CAT.STONE, CAT.STONE_DARK, 4.0, 0.55)
	var pietra_cupa := CAT._mat(CAT.STONE_DARK, Color("8d857a"), 4.5, 0.6)
	var muschio := CAT._mat(SALVIA, SALVIA_DARK, 5.0, 0.6)

	# ---- LO ZOCCOLO: sassi di fiume nella malta, come la rastrelliera ----
	# la malta sta INDIETRO rispetto ai sassi (raggio 0.235 contro 0.27):
	# a filo con loro li seppelliva, e lo zoccolo diventava un cono di
	# cemento con dentro dei puntini chiari
	BUILDER.lathe(n, [Vector2(0.0, 0.0), Vector2(0.250, 0.0),
			Vector2(0.256, 0.02), Vector2(0.238, 0.14),
			Vector2(0.228, 0.19), Vector2(0.212, 0.212),
			Vector2(0.0, 0.212)], pietra_cupa, Vector3.ZERO, 22)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20_260_809
	# due corsi sfalsati, come li poserebbe una mano
	for corso in 2:
		var quanti := 9 if corso == 0 else 7
		var alt := 0.055 + 0.098 * float(corso)
		var rr := 0.252 - alt * 0.13
		for i in quanti:
			var ang := TAU * float(i) / float(quanti) \
					+ (0.35 if corso == 1 else 0.0) + rng.randf_range(-0.10, 0.10)
			var gr := rng.randf_range(0.058, 0.079) * (1.0 - 0.14 * float(corso))
			var sasso := CAT._ball(n, gr, pietra,
					Vector3(cos(ang) * rr, alt, sin(ang) * rr),
					Vector3(1.0, rng.randf_range(0.62, 0.82), 0.74))
			sasso.rotation.y = ang
			sasso.rotation.z = rng.randf_range(-0.25, 0.25)
			# il secondo lobo: nessun sasso di fiume e' una sfera
			CAT._ball(n, gr * rng.randf_range(0.55, 0.72), pietra,
					Vector3(cos(ang + 0.10) * (rr + 0.010),
							alt + rng.randf_range(-0.022, 0.022),
							sin(ang + 0.10) * (rr + 0.010)),
					Vector3(1.0, 0.66, 0.74))
	# il muschio dalla parte in ombra, dove non batte il sole
	for m in 3:
		var am := 2.1 + 0.45 * float(m)
		CAT._ball(n, 0.045 + 0.012 * float(m), muschio,
				Vector3(cos(am) * 0.262, 0.03 + 0.02 * float(m), sin(am) * 0.262),
				Vector3(1.0, 0.35, 0.8))

	# ---- LA BOTTE, DRITTA: e' il serbatoio, e si legge come tale ----
	var y_base := 0.19
	var y_cima := 0.93
	var doga := CAT._mat(CAT.WOOD_PALE, CAT.WOOD, 2.5, 0.55)
	var profilo := [Vector2(0.0, 0.0), Vector2(0.205, 0.0), Vector2(0.232, 0.13),
			Vector2(0.248, 0.37), Vector2(0.232, 0.61), Vector2(0.205, 0.74),
			Vector2(0.0, 0.74)]
	BUILDER.lathe(n, profilo, doga, Vector3(0, y_base, 0), 26)
	# LE DOGHE: la rivoluzione e' liscia, una botte vera non lo e' mai.
	var doga_a := CAT._mat(CAT.WOOD_PALE, CAT.WOOD, 3.0, 0.5)
	var doga_b := CAT._mat(Color("e0b476"), Color("c2925a"), 3.0, 0.48)
	var doga_c := CAT._mat(Color("d9cca2"), Color("b9a878"), 3.2, 0.55)
	var tinte := [doga_a, doga_b, doga_c]
	var ordine := [0, 2, 1, 0, 1, 2, 1, 0, 2, 1, 2, 0]
	var prof_doga := [Vector2(0.205, 0.005), Vector2(0.250, 0.37), Vector2(0.205, 0.735)]
	for i2 in 12:
		var giro := Node3D.new()
		giro.position = Vector3(0, y_base, 0)
		giro.rotation.y = (float(i2) + 0.5) / 12.0 * TAU
		n.add_child(giro)
		var tinta: Material = tinte[ordine[i2]]
		for s2 in prof_doga.size() - 1:
			var p0: Vector2 = prof_doga[s2]
			var p1: Vector2 = prof_doga[s2 + 1]
			var lunga := p0.distance_to(p1)
			var listello := CAT._box(giro, Vector3(0.108, lunga * 1.04, 0.016), tinta,
					Vector3(0, (p0.y + p1.y) * 0.5, (p0.x + p1.x) * 0.5 + 0.004))
			listello.rotation.x = atan2(p1.x - p0.x, p1.y - p0.y)
	# i tre cerchi, spaiati — uno mangiato dalla ruggine
	var ferro_vecchio := CAT._mat(CAT.METAL.darkened(0.16), Color("564e46"), 4.5, 0.42)
	var ferro_rugine := CAT._mat(Color("c08a54"), Color("8f5c38"), 4.0, 0.4)
	var cerchi := [[0.10, 0.234, ferro], [0.37, 0.252, ferro_rugine],
			[0.655, 0.230, ferro_vecchio]]
	for c2: Array in cerchi:
		var tm := TorusMesh.new()
		tm.inner_radius = float(c2[1])
		tm.outer_radius = float(c2[1]) + 0.016
		tm.rings = 22
		tm.ring_segments = 6
		var cm := MeshInstance3D.new()
		cm.mesh = tm
		cm.material_override = c2[2]
		cm.position = Vector3(0, y_base + float(c2[0]), 0)
		n.add_child(cm)
	# la colatura sotto il cerchio arrugginito, sul fronte (-Z)
	var macchia := CAT._mat(Color("a85a34"), Color("7a3c1e"), 2.0, 0.6)
	for mm: Array in [[-0.16, 0.09], [0.20, 0.06]]:
		var am2: float = PI * 1.5 + float(mm[0])
		var lm: float = float(mm[1])
		CAT._box(n, Vector3(0.02, lm, 0.014), macchia,
				Vector3(cos(am2) * 0.256, y_base + 0.37 - 0.02 - lm * 0.5,
						sin(am2) * 0.256))

	# ---- IL COPERCHIO: tavole, cerchiatura e l'anello di rame ----
	for t2 in 3:
		CAT._box(n, Vector3(0.126, 0.026, 0.40 - 0.09 * absf(float(t2) - 1.0)),
				legno, Vector3((float(t2) - 1.0) * 0.132, y_cima + 0.012, 0))
	CAT._cordolo(n, CAT._super_anello(0.207, 0.207, 1.0, 0.0, 32), 0.012, ferro_vecchio,
			Vector3(0, y_cima + 0.014, 0))
	var anello := TorusMesh.new()
	anello.inner_radius = 0.034
	anello.outer_radius = 0.046
	anello.rings = 18
	anello.ring_segments = 6
	var am3 := MeshInstance3D.new()
	am3.mesh = anello
	am3.material_override = rame
	am3.position = Vector3(0, y_cima + 0.048, 0.0)
	am3.rotation.x = PI * 0.42
	n.add_child(am3)

	# ---- LA CONCA DI PIETRA: piccola, personale, all'altezza del petto ----
	# 66 cm: e' QUESTA quota a dire che qui beve una persona. Il truogolo
	# della stesura precedente stava a 6 cm da terra, ed era un
	# abbeveratoio per quanto bello fosse il legno sopra.
	var y_conca := 0.60
	var z_conca := -0.40
	var conca := Node3D.new()
	conca.position = Vector3(0, y_conca, z_conca)
	n.add_child(conca)
	# il profilo scava DAVVERO la vasca: su per il fianco, sopra il labbro
	# e giu' dentro fino allo scarico
	BUILDER.lathe(conca, [Vector2(0.0, 0.0), Vector2(0.115, 0.0),
			Vector2(0.158, 0.028), Vector2(0.176, 0.062),
			Vector2(0.180, 0.086), Vector2(0.170, 0.094),
			Vector2(0.152, 0.070), Vector2(0.120, 0.045),
			Vector2(0.062, 0.032), Vector2(0.026, 0.030),
			Vector2(0.0, 0.030)], pietra, Vector3.ZERO, 24)
	conca.scale = Vector3(1.04, 1.08, 0.90)
	# le due mensole di pietra che la reggono contro la botte
	for sx2: float in [-1.0, 1.0]:
		var mens := CAT._loft(n, [[-0.020, 0.030, -0.075, 0.010, 0.010],
				[0.020, 0.048, -0.030, 0.010, 0.012]], pietra_cupa,
				Vector3(sx2 * 0.115, y_conca + 0.010, -0.30))
		mens.rotation.y = PI * 0.5
	# l'acqua nella conca, e i due cerchi dell'onda che il getto ci fa
	var acqua := CAT._glow(Color(0.55, 0.82, 0.95, 0.8), Color(0.4, 0.7, 0.9), 0.14)
	acqua.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	CAT._cyl(conca, 0.150, 0.140, 0.030, acqua, Vector3(0, 0.049, 0))
	var onda := CAT._glow(Color(0.72, 0.9, 0.98, 0.5), Color(0.55, 0.82, 0.95), 0.2)
	onda.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for ondina: float in [0.052, 0.094]:
		CAT._cordolo(conca, CAT._super_anello(ondina, ondina, 1.0, 0.0, 28),
				0.005, onda, Vector3(0, 0.064, 0))

	# ---- IL COLLO DI CIGNO di rame, e il rubinetto ----
	# esce dalla botte, si curva in avanti e guarda in giu' dentro la conca
	BUILDER.tube(n, [Vector3(0, 0.775, -0.215), Vector3(0, 0.800, -0.285),
			Vector3(0, 0.792, -0.352), Vector3(0, 0.752, -0.392),
			Vector3(0, 0.716, -0.400)],
			[0.022, 0.020, 0.018, 0.016, 0.017], rame, 22, 10)
	CAT._cyl(n, 0.030, 0.030, 0.040, rame, Vector3(0, 0.775, -0.222)).rotation.x = PI * 0.5
	# la manopola a crociera, sopra la bocchetta
	CAT._cyl(n, 0.016, 0.020, 0.036, rame, Vector3(0, 0.845, -0.222))
	for a2: float in [0.0, PI * 0.5]:
		CAT._box(n, Vector3(0.078, 0.011, 0.011), rame,
				Vector3(0, 0.866, -0.222)).rotation.y = a2
	CAT._ball(n, 0.013, rame, Vector3(0, 0.874, -0.222), Vector3(1, 0.8, 1))

	# ---- IL FILO D'ACQUA: accelera cadendo, quindi si ASSOTTIGLIA ----
	var getto := CAT._glow(Color(0.7, 0.88, 0.98, 0.55), Color(0.55, 0.8, 0.95), 0.25)
	getto.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	BUILDER.tube(n, [Vector3(0, 0.700, -0.400), Vector3(0, 0.686, -0.400),
			Vector3(0, 0.670, -0.400), Vector3(0, 0.652, -0.400)],
			[0.013, 0.0085, 0.006, 0.010], getto, 14, 8)
	CAT._ball(n, 0.010, getto, Vector3(0.006, 0.672, -0.403), Vector3(1.0, 1.25, 1.0))
	CAT._ball(n, 0.0075, getto, Vector3(-0.007, 0.659, -0.396), Vector3(1.0, 1.15, 1.0))
	# e la goccia che si tiene ancora alla bocchetta, per tensione
	CAT._ball(n, 0.0085, getto, Vector3(0, 0.707, -0.400), Vector3(1.0, 1.3, 1.0))
	CAT._emit_fx(n, Vector3(0, 0.652, -0.400), Color(0.75, 0.92, 1.0), 0.30, -1.4,
			10, 0.5, 0.032)

	# LO SCARICO: solo la bocchetta di rame sotto la conca. La prima
	# stesura ci attaccava un tubo che scendeva fino allo zoccolo: dal
	# fronte correva DAVANTI alla botte per tutta l'altezza e la tagliava
	# in due — un tubo che si vede piu' della fontana non e' un dettaglio,
	# e' un intralcio.
	CAT._cyl(n, 0.019, 0.015, 0.032, rame, Vector3(0, 0.586, -0.400))
	CAT._cordolo(n, CAT._super_anello(0.021, 0.021, 1.0, 0.0, 20), 0.005,
			ferro_vecchio, Vector3(0, 0.578, -0.400))

	# ---- LA TAZZA DI LATTA, appesa al gancio e mai ferma ----
	CAT._ball(n, 0.014, ferro_vecchio, Vector3(0.238, 0.700, -0.150),
			Vector3(1, 0.8, 1))
	var tazza := Node3D.new()
	tazza.name = "Tazza"
	tazza.position = Vector3(0.262, 0.638, -0.150)
	tazza.rotation.z = 0.25
	n.add_child(tazza)
	# il corpo tornito col fondo stretto e il labbro arrotolato: il
	# cilindro nudo col tubo di fianco leggeva come una teiera di latta
	BUILDER.lathe(tazza, [Vector2(0.0, -0.042), Vector2(0.036, -0.042),
			Vector2(0.040, -0.034), Vector2(0.045, 0.010),
			Vector2(0.050, 0.038), Vector2(0.053, 0.043),
			Vector2(0.048, 0.046), Vector2(0.044, 0.040),
			Vector2(0.041, 0.010), Vector2(0.036, -0.030),
			Vector2(0.0, -0.030)], ferro, Vector3.ZERO, 20)
	# il manico a C, sul FIANCO e attaccato in due punti
	BUILDER.tube(tazza, [Vector3(0.044, 0.030, 0), Vector3(0.068, 0.018, 0),
			Vector3(0.072, -0.004, 0), Vector3(0.055, -0.020, 0),
			Vector3(0.036, -0.022, 0)], [0.006, 0.0065, 0.0065, 0.006, 0.005],
			ferro, 18, 8)
	# la toppa saldata: e' stata riparata, non comprata nuova
	CAT._ball(tazza, 0.013, ferro_vecchio, Vector3(-0.030, 0.006, 0.034),
			Vector3(1, 1, 0.5))
	var oscilla := Animation.new()
	oscilla.length = 4.2
	oscilla.loop_mode = Animation.LOOP_LINEAR
	var tr_tazza := oscilla.add_track(Animation.TYPE_VALUE)
	oscilla.track_set_path(tr_tazza, NodePath("Tazza:rotation:z"))
	oscilla.track_insert_key(tr_tazza, 0.0, 0.22)
	oscilla.track_insert_key(tr_tazza, 2.1, 0.29)
	oscilla.track_insert_key(tr_tazza, 4.2, 0.22)
	oscilla.track_set_interpolation_type(tr_tazza, Animation.INTERPOLATION_CUBIC)
	var lib_tazza := AnimationLibrary.new()
	lib_tazza.add_animation("dondola", oscilla)
	var player_tazza := AnimationPlayer.new()
	n.add_child(player_tazza)
	player_tazza.add_animation_library("", lib_tazza)
	player_tazza.autoplay = "dondola"

	# NIENTE ASCIUGAMANO. Ci ho provato tre volte — arrotolato sul piolo,
	# a due lembi di stoffa morbida, a lastre sottili ad angoli tondi — e
	# tutte e tre le volte, a questa scala e accanto a una botte larga
	# mezzo metro, leggeva come un cartone verde appeso al fianco. E' la
	# stessa lezione della copertina rosa nella cuccia e dei pioli sul
	# faro: un dettaglio che non si spiega da solo e' PEGGIO di nessun
	# dettaglio, perche' il giocatore si ferma a chiedersi cosa sia.
	# Che qui ci si fermi a bere lo dice gia' la tazza di latta.

	_posto(n, Vector3(0, 0.0, -0.68), Vector3.BACK)
	return n


# ---------------------------------------------------- la rastrelliera dei pesi

## I pesi: sassi di fiume levigati, infilati sui bastoni, in ordine di
## grandezza su due ripiani. In fondo due pietre col manico di corda, che
## si prendono a due mani. Il telaio poggia su uno zoccolo (non pali nudi
## piantati a terra) e i ripiani si vedono agganciati ai fianchi con
## cavicchi di legno: il giunto si GUARDA, non si intuisce soltanto. Ogni
## sasso è scolpito da 2-3 lobi di sfera sovrapposti — mai un pallone da
## rugby identico al vicino — e il bastone ha una fascetta di cuoio dove
## entra nella pietra, invece di sparire dentro di lei come per magia.
static func rastrelliera() -> Node3D:
	var n := Node3D.new()
	var legno := CAT._mat(CAT.WOOD, CAT.WOOD_DARK, 5.0, 0.5)
	var legno_scuro := CAT._mat(CAT.WOOD_DARK, CAT.WOOD_DARK.darkened(0.25), 3.0, 0.5)
	var chiaro := CAT._mat(CAT.WOOD_PALE, CAT.WOOD, 4.5, 0.45)
	var sasso := CAT._mat(CAT.STONE, CAT.STONE_DARK, 3.0, 0.5)
	var sasso_scuro := CAT._mat(CAT.STONE_DARK, Color("8e857a"), 3.5, 0.5)
	var corda := CAT._mat(CORDA, CUOIO, 7.0, 0.4)
	var legatura := CAT._mat(CUOIO, CUOIO_DARK, 6.0, 0.45)

	# UN SASSO DI FIUME COMPOSITO: 2-3 lobi di sfera leggermente sovrapposti
	# e ruotati fra loro. `ricetta` è un array di lobi [scarto (frazione di
	# r), scala, rotazione, raggio (frazione di r)]; il primo lobo è sempre
	# il corpo principale, gli altri sono le schegge/protuberanze che
	# rompono la sagoma perfetta di un'unica sfera schiacciata.
	var scolpisci_sasso := func(parent: Node3D, centro: Vector3, r: float,
			mat: Material, ricetta: Array) -> void:
		for lobo in ricetta:
			var off: Vector3 = lobo[0]
			var scl: Vector3 = lobo[1]
			var rot: Vector3 = lobo[2]
			var rf: float = lobo[3]
			var palla := CAT._ball(parent, r * rf, mat, centro + off * r, scl)
			if rot != Vector3.ZERO:
				palla.rotation = rot

	# CINQUE SAGOME, una per manubrio: `sz2` è il capo del bastone (-1/+1),
	# e specchia gli scarti perturbandoli — i due capi di uno stesso
	# manubrio sono imparentati (stessa famiglia di forma) ma non
	# identici, come due sassi veri raccolti insieme e infilati sullo
	# stesso bastone da chi non li ha scelti uguali.
	var sagoma_a := func(sz2: float) -> Array:
		return [
			[Vector3.ZERO, Vector3(0.86, 0.92, 1.0), Vector3.ZERO, 1.0],
			[Vector3(sz2 * 0.38, 0.5, -0.2), Vector3(0.42, 0.4, 0.48),
					Vector3(0.15, 0.0, sz2 * 0.3), 0.52],
		]
	var sagoma_b := func(sz2: float) -> Array:
		return [
			[Vector3.ZERO, Vector3(0.9, 0.85, 1.0), Vector3.ZERO, 1.0],
			[Vector3(sz2 * -0.5, 0.12, 0.3), Vector3(0.56, 0.5, 0.4),
					Vector3(0.0, sz2 * 0.4, -0.22), 0.6],
		]
	var sagoma_c := func(sz2: float) -> Array:
		return [
			[Vector3(sz2 * -0.28, 0.06, -0.05), Vector3(0.62, 0.72, 0.85),
					Vector3(0.0, 0.0, sz2 * 0.16), 0.74],
			[Vector3(sz2 * 0.3, -0.06, 0.1), Vector3(0.66, 0.7, 0.9),
					Vector3(0.0, 0.0, sz2 * -0.12), 0.78],
		]
	var sagoma_d := func(sz2: float) -> Array:
		return [
			[Vector3.ZERO, Vector3(0.95, 0.8, 1.0), Vector3.ZERO, 1.0],
			[Vector3(sz2 * 0.42, 0.5, -0.32), Vector3(0.3, 0.28, 0.34),
					Vector3(0.35, sz2 * 0.2, 0.0), 0.4],
		]
	var sagoma_e := func(sz2: float) -> Array:
		return [
			[Vector3.ZERO, Vector3(0.82, 0.95, 1.0), Vector3.ZERO, 1.0],
			[Vector3(sz2 * -0.4, -0.36, 0.22), Vector3(0.5, 0.46, 0.55),
					Vector3(0.0, sz2 * 0.3, 0.2), 0.58],
			[Vector3(sz2 * 0.3, 0.58, -0.26), Vector3(0.22, 0.2, 0.24),
					Vector3.ZERO, 0.3],
		]
	var sagome := [sagoma_a, sagoma_b, sagoma_c, sagoma_d, sagoma_e]

	# il telaio: due fianchi a A, uno zoccolo che li tiene posati bene (non
	# pali nudi piantati a terra) e i cavicchi che fissano i ripiani —
	# poi i due ripiani stessi
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var g := CAT._box(n, Vector3(0.055, 0.78, 0.055), legno,
					Vector3(sx * 0.4, 0.38, sz * 0.16))
			g.rotation.x = sz * 0.12
		CAT._box(n, Vector3(0.06, 0.05, 0.42), legno, Vector3(sx * 0.4, 0.72, 0))
		CAT._box(n, Vector3(0.12, 0.035, 0.4), legno_scuro, Vector3(sx * 0.4, 0.0175, 0))
		# i cavicchi che fissano i ripiani ai fianchi: il giunto si VEDE
		# (un piolo che sporge dalla faccia esterna), non è soltanto una
		# scatola che ne compenetra un'altra in silenzio
		for sy2: float in [0.3, 0.68]:
			for sz4: float in [-1.0, 1.0]:
				var cav := CAT._cyl(n, 0.013, 0.013, 0.045, legno_scuro,
						Vector3(sx * 0.44, sy2, sz4 * 0.16))
				cav.rotation.z = PI * 0.5
	for sy: float in [0.3, 0.68]:
		CAT._box(n, Vector3(0.92, 0.045, 0.3), chiaro, Vector3(0, sy, 0))
		# un piccolo bordo alzato sul filo davanti: senza, un sasso
		# tondo posato su un'asse liscia rotolerebbe giù
		CAT._box(n, Vector3(0.9, 0.018, 0.03), chiaro, Vector3(0, sy + 0.0315, -0.155))

	# i manubri: bastone e due sassi, tre misure. Sul ripiano di sopra i
	# leggeri, sotto i pesanti — come li metterebbe chiunque
	# i ripiani stanno a 0.3 e 0.68, spessi 0.045: il piano d'appoggio è
	# quindi a 0.3225 e 0.7025 — un sasso ci si POSA sopra, tangente, e
	# affonda di un soffio come fa una cosa pesante su un'asse
	var misure := [[0.055, 0.7025, -0.3], [0.062, 0.7025, 0.0], [0.07, 0.7025, 0.3],
			[0.085, 0.3225, -0.26], [0.095, 0.3225, 0.08]]
	for i in misure.size():
		var m = misure[i]
		var r: float = m[0]
		var y: float = m[1] + r * 0.92
		var x: float = m[2]
		var manubrio := Node3D.new()
		manubrio.position = Vector3(x, y, 0)
		manubrio.rotation.y = 0.12 if int(x * 10) % 2 == 0 else -0.16
		n.add_child(manubrio)
		var asta := CAT._cyl(manubrio, 0.014, 0.014, 0.3, chiaro, Vector3.ZERO)
		asta.rotation.x = PI * 0.5
		var mat_sasso := sasso if r < 0.08 else sasso_scuro
		for sz2: float in [-1.0, 1.0]:
			# la fascetta di cuoio dove il bastone entra nel sasso: senza,
			# il legno chiaro sparisce dentro la pietra come per magia.
			# Sta sul tratto di bastone ancora NUDO, appena prima che il
			# sasso lo avvolga — non sulla punta della sfera (lì la
			# sezione si annulla e la fascetta galleggerebbe da sola)
			var fascia := CAT._cyl(manubrio, 0.018, 0.021, 0.02, legatura,
					Vector3(0, 0, sz2 * (0.12 - r) * 0.72))
			fascia.rotation.x = PI * 0.5
			scolpisci_sasso.call(manubrio, Vector3(0, 0, sz2 * 0.12), r, mat_sasso,
					sagome[i].call(sz2))

	# e le due pietre col manico di corda, a terra davanti: base piatta
	# (poggiano su una faccia smussata, non su un pallone perfetto), una
	# cupola decentrata sopra, e una scheggiatura mai la stessa sulle due
	for sx2: float in [-1.0, 1.0]:
		var pietra := Node3D.new()
		pietra.position = Vector3(sx2 * 0.26, 0.0, 0.34)
		pietra.rotation.y = sx2 * 0.5
		n.add_child(pietra)
		CAT._ball(pietra, 0.108, sasso_scuro, Vector3(0, 0.052, 0), Vector3(1.05, 0.52, 1.0))
		var cupola := CAT._ball(pietra, 0.09, sasso_scuro,
				Vector3(sx2 * 0.012, 0.148, -0.01), Vector3(0.92, 0.82, 0.95))
		cupola.rotation = Vector3(0.05, sx2 * 0.2, sx2 * 0.08)
		CAT._ball(pietra, 0.045, sasso_scuro, Vector3(sx2 * -0.09, 0.09, 0.055),
				Vector3(0.55, 0.42, 0.5))
		# il manico si prende a due mani: un arco alto, ben sopra la
		# cupola, non un filo che spunta a malapena dal sasso
		BUILDER.tube(pietra, [Vector3(-0.058, 0.19, 0), Vector3(0, 0.34, 0),
				Vector3(0.058, 0.19, 0)], [0.014, 0.017, 0.014], corda, 14, 8)
		# i due nodi dove il manico di corda entra nella pietra: un tubo
		# che sparisce a filo della superficie è una corda che non regge
		for sxk: float in [-1.0, 1.0]:
			CAT._ball(pietra, 0.022, corda, Vector3(sxk * 0.058, 0.19, 0),
					Vector3(1.0, 0.9, 1.0))
	_posto(n, Vector3(0, 0.0, 0.62), Vector3.BACK)
	return n
