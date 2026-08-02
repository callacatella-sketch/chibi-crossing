class_name BuildBoutique
extends RefCounted

## LA BOUTIQUE DEL PAESE — il negozio di vestiti, quindici pezzi.
##
## Il riferimento è dichiarato: un negozio di moda di quelli veri, con la
## vetrina illuminata sulla strada, gli stender in fila, i piegati sul
## tavolo e i camerini in fondo. Ma un negozio di catena, copiato di
## peso, in questo villaggio sarebbe un corpo estraneo: qui non esiste
## acciaio spazzolato, non esiste plastica, e soprattutto non esiste
## niente di stampato.
##
## LA SOLUZIONE È LA STESSA DELLA PALESTRA, ROVESCIATA. Là il problema
## era rendere di paese degli attrezzi da palestra; qui è rendere di
## paese un negozio di moda. Non si copiano i MATERIALI (che restano
## quelli di casa: calce, frassino, ottone, marmo di fiume) — si copia la
## GRAMMATICA DEL MERCHANDISING, che è la cosa che davvero rende un
## negozio un negozio:
##
##   · il VUOTO. Un negozio di moda è per metà spazio libero. Nessun
##     pezzo qui è affollato: sono oggetti bassi e larghi con l'aria
##     intorno, e il Tavolo dei piegati ha DUE pile su tre appoggi.
##   · il RITMO. Capi tutti alla stessa altezza, mensole equidistanti,
##     lettere staccate: la ripetizione regolare è il segnale di
##     «esposizione», e in questo villaggio storto è l'unica cosa dritta.
##   · la LUCE PUNTATA. Non luce d'ambiente: fasci caldi addosso alla
##     merce. La vetrina e i faretti hanno una luce vera, e di sera la
##     boutique è l'unica finestra del paese che illumina la strada
##     invece che sé stessa.
##
## DA LONTANO la comprano tre cose sole:
##   1. la VETRINA a tutta altezza col manichino dentro — nessun altro
##      edificio del villaggio ha un vetro da terra al tetto, e nessuno
##      ha una FIGURA in piedi ferma dentro una finestra;
##   2. l'INSEGNA in lettere sottili e staccate — la tipografia è il
##      marchio: le altre insegne del paese sono oggetti dipinti (la
##      tazzina del bar, l'elmo della caserma), questa è una PAROLA;
##   3. la LINEA ORIZZONTALE degli appesi: uno stender è una riga di
##      spalle tutte alla stessa quota, e non c'è niente altro di simile
##      in tutto il villaggio.
##
## DA VICINO le comprano i particolari che nessuno modella e che sono
## esattamente quelli che si riconoscono: la GRUCCIA che spunta sopra la
## spalla, la PIEGA arrotondata sul davanti della pila (una pila di
## piegati senza il tondo davanti è una pila di libri), le pieghe VERE
## della tenda del camerino, e i manici di corda dei sacchetti.
##
## I CAPI SONO L'OGGETTO PRINCIPALE e stanno in una funzione sola
## (`_capo`): silhouette a lathe schiacciata sull'asse Z — spalle strette,
## fianco che si allarga verso l'orlo — maniche staccate dal corpo con
## angoli diversi a destra e a sinistra, e due o tre pieghe verticali sul
## davanti. Sei scatole sovrapposte facevano un armadio di cartone; una
## superficie di rivoluzione schiacciata fa una stoffa.
##
## E i capi appesi allo stender NON guardano tutti avanti: quasi tutti
## sono di taglio, impilati sull'asta come nella realtà (si sfogliano),
## e solo gli ultimi due sono girati di fronte. È esattamente quello che
## fa un negozio vero — la maggior parte a taglio, i «frontali» in
## evidenza — ed è quello che salva la lettura: una fila di soli fronti
## sembra un armadio spalancato.
##
## Vive in un file suo, come la palestra e la chiesa: primitive e colori
## di casa restano in BuildCatalog (`CAT.`), qui ci sono solo le forme
## della boutique.

const CAT := preload("res://scenes/build/BuildCatalog.gd")
## I tubi spazzati lungo una curva: l'asta che si flette sotto il peso dei
## capi, i manici dei sacchetti, la sciarpa del manichino, il metro da sarta.
const BUILDER := preload("res://scenes/npc/ChibiBuilder.gd")


# ------------------------------------------------------------ la tavolozza
# Sta QUI e solo qui. Cinque pezzi che si ridichiarano il proprio bianco
# divergono entro due sessioni, e una boutique con due bianchi diversi non
# è una boutique: è una stanza tinteggiata due volte.

const CALCE := Color("f6f1e7")            # le pareti e i podi: calce, non bianco
const CALCE_OMBRA := Color("e3dbcb")
const GRAFITE := Color("3a3632")          # il nero CALDO dei telai e delle lettere
const GRAFITE_CHIARA := Color("4e4842")
const FRASSINO := Color("e2cfb0")         # il legno chiaro dei tavoli
const FRASSINO_CUPO := Color("c3a97f")
const ARGILLA := Color("c98f7a")          # il velluto pesante dei camerini
const ARGILLA_CUPA := Color("a4705c")
const CARTA := Color("e9ddc7")            # i sacchetti
const CARTA_CUPA := Color("cfbfa2")
const CORDA := Color("d6c39c")
const VELINA := Color("fbf6ee")           # la carta velina, quella che fruscia

## IL GUARDAROBA: la tavolozza dei capi. Otto colori spenti e adulti — è
## questa scelta a fare la differenza fra «negozio di moda» e «bancarella
## di palloncini»: niente primari, niente saturi. Ogni voce è [chiaro,
## scuro]; il chiaro è la stoffa, lo scuro è l'ombra nelle pieghe.
const GUARDAROBA := [
	[Color("d7ad74"), Color("b98d58")],   # cammello
	[Color("b5654a"), Color("934d36")],   # ruggine
	[Color("9db894"), Color("7e9a76")],   # salvia
	[Color("6b84a8"), Color("52698c")],   # denim
	[Color("f0e6d2"), Color("d7c9ae")],   # crema
	[Color("7c5a75"), Color("62455d")],   # prugna
	[Color("dfb648"), Color("bc9532")],   # senape
	[Color("4a4640"), Color("37342f")],   # grafite
]


# --------------------------------------------------------- gli helper base

## Il posto d'uso di un pezzo: dove ci si mette e dove si guarda (stessa
## convenzione della palestra — `avanti` è la direzione verso cui è
## rivolto chi lo usa). Va messo ADESSO: ricavarlo dopo, a occhio, dai
## numeri del builder è il modo sicuro di far provare una giacca a
## qualcuno mezzo metro dentro il muro.
static func _posto(parent: Node3D, pos: Vector3, avanti := Vector3.FORWARD) -> Node3D:
	var p := Node3D.new()
	p.name = "posto"
	p.position = pos
	if avanti.length() > 0.001:
		p.rotation.y = atan2(-avanti.x, -avanti.z)
	parent.add_child(p)
	return p


static func _stoffa(i: int, buio := 0.0) -> ShaderMaterial:
	var c: Array = GUARDAROBA[posmod(i, GUARDAROBA.size())]
	var a: Color = (c[0] as Color).darkened(buio)
	var b: Color = (c[1] as Color).darkened(buio)
	return CAT._mat(a, b, 5.5, 0.45)


static func _ottone() -> ShaderMaterial:
	return CAT._mat(CAT.OTTONE, CAT.OTTONE_SCURO, 5.0, 0.38)


static func _grafite() -> ShaderMaterial:
	return CAT._mat(GRAFITE, GRAFITE_CHIARA, 4.5, 0.35)


static func _calce() -> ShaderMaterial:
	return CAT._mat(CALCE, CALCE_OMBRA, 3.0, 0.45)


## Lo specchio del progetto: azzurro pallido appena luminoso (uno specchio
## BIANCO è una porta di frigorifero), più le lame oblique di riflesso —
## che sono quelle che dicono «specchio». Stessa ricetta dello specchio
## della palestra, tenuta identica di proposito: due specchi diversi nello
## stesso villaggio si notano subito.
static func _lastra_specchio(parent: Node3D, largo: float, alto: float,
		z: float, lame := true) -> void:
	var vetro := CAT._glow(Color(0.80, 0.88, 0.93), Color(0.62, 0.76, 0.88), 0.22)
	CAT._box(parent, Vector3(largo, alto, 0.014), vetro, Vector3(0, 0, z))
	if not lame:
		return
	var lama := CAT._glow(Color(1, 1, 1, 0.45), Color(1, 1, 1), 0.45)
	lama.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# corte, e dentro la cornice: un riflesso che sborda non è un riflesso
	var l1 := CAT._box(parent, Vector3(largo * 0.16, alto * 0.52, 0.005), lama,
			Vector3(-largo * 0.16, alto * 0.1, z - 0.009))
	l1.rotation.z = 0.42
	var l2 := CAT._box(parent, Vector3(largo * 0.07, alto * 0.26, 0.005), lama,
			Vector3(largo * 0.14, -alto * 0.2, z - 0.009))
	l2.rotation.z = 0.42


# ------------------------------------------------------------------ i capi

## LA GRUCCIA. Sporge SOPRA la spalla del capo: è il dettaglio che
## trasforma «una forma di stoffa che galleggia» in «una cosa appesa».
## Legno chiaro col gancio d'ottone, come le grucce buone.
## LA GRUCCIA — e il suo gancio DEVE ABBRACCIARE L'ASTA.
##
## Prima il gancio partiva dall'origine e saliva: appeso a un'asta, il
## risultato era una fila di ganci d'ottone che galleggiavano cinque
## centimetri SOPRA il tubo, e sotto una fila di barrette bianche
## scoperte fra il tubo e la stoffa. Sembrava un attaccapanni smontato.
## Adesso il gancio è un arco intorno all'origine (che è il centro
## dell'asta), le falde stanno appena sotto, e la traversa è più STRETTA
## delle spalle del capo — così la stoffa la copre, come nella realtà.
static func _gruccia(parent: Node3D, larga: float) -> void:
	var legno := CAT._mat(FRASSINO_CUPO, FRASSINO_CUPO.darkened(0.18), 4.0, 0.4)
	var ottone := _ottone()
	# il gancio: l'arco che scavalca l'asta e ridiscende dall'altra parte
	BUILDER.tube(parent, [
			Vector3(0.016, -0.026, 0), Vector3(0.017, 0.004, 0),
			Vector3(0.004, 0.021, 0), Vector3(-0.013, 0.014, 0),
			Vector3(-0.017, -0.002, 0)],
			[0.0045, 0.0045, 0.0045, 0.0042, 0.0038], ottone, 14, 6)
	# le due falde della spalla e la traversa (dentro la stoffa)
	for lato: float in [-1.0, 1.0]:
		var f := CAT._box(parent, Vector3(larga * 0.50, 0.014, 0.018), legno,
				Vector3(lato * larga * 0.23, -0.038, 0))
		f.rotation.z = -lato * 0.22
	CAT._box(parent, Vector3(larga * 0.86, 0.010, 0.014), legno,
			Vector3(0, -0.060, 0))


## UN CAPO APPESO. L'origine del nodo è il GANCIO: tutto pende sotto, così
## metterne dieci su un'asta è dire dieci volte la stessa quota.
##
## `lungo` è dal gancio all'orlo, `taglio` sceglie la silhouette
## (0 camicia · 1 giacca · 2 cappotto · 3 abito), `seme` fa sì che due
## capi accanto non siano lo stesso capo: cambia le pieghe, l'angolo delle
## maniche, l'orlo, e chi ha i bottoni o la cintura.
##
## `taglia` e `spessore` servono al capo INDOSSATO: un cappotto addosso a
## un manichino deve stare FUORI dal corpo, e un capo appeso è schiacciato
## (0.42) mentre uno indossato ha dentro qualcuno (0.72). Sbagliarli non
## dà nessun errore: il petto del manichino spunta fuori dal bavero, e da
## profilo la figura sembra tagliata a metà.
static func _capo(parent: Node3D, pos: Vector3, colore: int, lungo := 0.42,
		giro := 0.0, taglio := 0, seme := 1, con_gruccia := true,
		taglia := 1.0, spessore := 0.42) -> Node3D:
	var n := Node3D.new()
	# IL NOME PORTA IL SEME, e non è pignoleria: è l'unico appiglio dei
	# test per guardare dentro uno stender (che i capi pendano sotto
	# l'asta, che siano di lunghezze diverse). Chiamarli tutti «capo» non
	# funziona: `add_child` senza `force_readable_name` non numera il
	# doppione — BUTTA VIA il nome e mette «@Node3D@24». Il test ne
	# trovava uno solo su undici e dichiarava verde uno stender vuoto.
	n.name = "capo_%d" % seme
	n.position = pos
	n.rotation.y = giro
	parent.add_child(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91_000 + seme * 37
	var stoffa := _stoffa(colore)
	var ombra := _stoffa(colore, 0.14)

	# LA SILHOUETTE. Il profilo si allarga SEMPRE scendendo: con un tratto
	# quasi costante in mezzo (com'era) il capo usciva a tubo — dieci tubi
	# colorati in fila non sono un negozio, sono un cantiere. E la spalla
	# sta ALTA (-0.045): più in basso restava scoperta la gruccia.
	var sp := (0.078 + rng.randf_range(-0.004, 0.006)) * taglia   # mezza spalla
	var svaso := 1.30 if taglio == 0 else 1.42     # camicia più diritta
	if taglio == 3:
		svaso = 1.62                                # l'abito è quello che si apre
	var orlo := sp * svaso
	var y0 := -lungo
	var profilo := [
		Vector2(orlo * 0.97, y0),
		Vector2(orlo, y0 + lungo * 0.06),
		Vector2(orlo * 0.93, y0 + lungo * 0.26),
		Vector2(sp * 1.16, y0 + lungo * 0.56),
		Vector2(sp * 1.03, -0.075),
		Vector2(sp, -0.045),
		Vector2(sp * 0.58, -0.032),
		Vector2(sp * 0.26, -0.026),
	]
	var corpo := BUILDER.lathe(n, profilo, stoffa, Vector3.ZERO, 22)
	corpo.name = "stoffa"
	# schiacciato: un capo appeso è largo e sottile, non un tubo
	corpo.scale = Vector3(1.0, 1.0, spessore)

	# lo scollo: l'ombra dell'apertura, non un buco (un buco vero, a
	# questa scala, si legge come un difetto della mesh)
	CAT._ball(n, sp * 0.28, ombra, Vector3(0, -0.036, 0), Vector3(1.0, 0.5, 0.6))

	# le maniche: attaccate alla spalla (staccate lasciavano un dito di
	# vuoto fra manica e corpo, e sembravano due salsicce appuntate), e
	# con angoli DIVERSI a destra e a sinistra: simmetriche sono un
	# cartello stradale. La sferetta alla giuntura nasconde la cucitura.
	if taglio != 3:
		var lm := lungo * (0.60 if taglio == 2 else 0.54)
		var sm := sp * 0.28                          # raggio della manica
		for lato: float in [-1.0, 1.0]:
			var ang := 0.12 + rng.randf_range(0.0, 0.08)
			var x0 := lato * (sp * 0.74)
			# la giuntura va SOTTO il colmo della spalla: la spalla del
			# capo è tonda (è una superficie di rivoluzione), e a tre
			# quarti della sua larghezza è già scesa — una manica
			# attaccata alla quota del centro spunta fuori come un corno
			CAT._ball(n, sm * 1.05, stoffa, Vector3(x0, -0.082, 0.004),
					Vector3(1.0, 0.9, 0.95))
			var m := CAT._cyl(n, sm, sm * 1.2, lm, stoffa,
					Vector3(x0 + lato * sin(ang) * lm * 0.5,
							-0.082 - lm * 0.5 * cos(ang), 0.004))
			m.rotation.z = -lato * ang
			m.rotation.x = rng.randf_range(-0.05, 0.05)
			# il polsino, un filo più scuro
			CAT._cyl(n, sm * 1.05, sm * 1.05, 0.016, ombra,
					Vector3(x0 + lato * sin(ang) * lm,
							-0.082 - lm * cos(ang) + 0.008, 0.004)).rotation.z = -lato * ang

	# le pieghe verticali sul davanti (-Z): mai centrate, mai uguali
	var fronte := -orlo * spessore
	for i in rng.randi_range(2, 3):
		var px := rng.randf_range(-orlo * 0.55, orlo * 0.55)
		var h := lungo * rng.randf_range(0.28, 0.5)
		var p := CAT._box(n, Vector3(0.007, h, 0.005), ombra,
				Vector3(px, -lungo * rng.randf_range(0.45, 0.68), fronte))
		p.rotation.z = rng.randf_range(-0.07, 0.07)

	# e poi UNA cosa in più, diversa per ognuno: i bottoni, la cintura, o
	# niente. È quello che rende una fila di capi una fila di capi.
	match seme % 3:
		0:
			for i in 3:
				CAT._ball(n, 0.008, _ottone(),
						Vector3(0.012, -0.17 - 0.075 * float(i), fronte - 0.004),
						Vector3(1, 1, 0.55))
		1:
			# LA CINTURA VA LARGA QUANTO IL CAPO LÌ, non quanto l'orlo:
			# l'orlo è il punto più largo e sta in fondo, e una cintura
			# tagliata su quella misura sbordava di due dita da tutti e
			# due i lati — un cerchio da giocoliere, non una cintura
			# ed è un CILINDRO SCHIACCIATO, non una scatola: una scatola
			# attorno a un ovale lascia fuori i quattro spigoli, e di
			# profilo la cintura diventava una mensola
			var cy := -lungo * 0.42
			var rc := sp * 1.10
			var cint := CAT._cyl(n, rc, rc, 0.030, ombra, Vector3(0, cy, 0))
			cint.scale = Vector3(1.0, 1.0, spessore * 1.04)
			CAT._box(n, Vector3(0.032, 0.032, 0.012), _ottone(),
					Vector3(0, cy, -rc * spessore - 0.008))
		_:
			# il colletto rovesciato
			for lato: float in [-1.0, 1.0]:
				var c := CAT._box(n, Vector3(sp * 0.5, 0.05, 0.012), ombra,
						Vector3(lato * sp * 0.34, -0.055, fronte + 0.012))
				c.rotation.z = lato * 0.5

	if con_gruccia:
		_gruccia(n, sp * 2.0)
	return n


## UNA PILA DI PIEGATI. Il segreto è UNO: la PIEGA arrotondata sul davanti
## di ogni strato. Senza, sono scatole impilate — cioè libri. E la pila
## non è un prisma: ogni strato è largo un po' diverso, storto di un
## grado, e scivola di qualche millimetro.
static func _pila(parent: Node3D, pos: Vector3, quanti: int, primo: int,
		largo := 0.20, seme := 3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5_400 + seme * 91
	var y := pos.y
	for i in quanti:
		var col := primo + i
		var stoffa := _stoffa(col)
		var luce := _stoffa(col, -0.06)
		var w: float = largo * rng.randf_range(0.94, 1.03)
		var d: float = largo * 0.78 * rng.randf_range(0.95, 1.04)
		var alto := 0.030 + rng.randf_range(-0.004, 0.006)
		var s := Node3D.new()
		s.position = Vector3(pos.x + rng.randf_range(-0.008, 0.008), y + alto * 0.5,
				pos.z + rng.randf_range(-0.01, 0.01))
		s.rotation.y = rng.randf_range(-0.06, 0.06)
		s.rotation.z = rng.randf_range(-0.02, 0.02)
		parent.add_child(s)
		CAT._box(s, Vector3(w, alto, d), stoffa, Vector3.ZERO)
		# LA PIEGA: il tondo davanti, appena più chiaro perché prende luce
		CAT._cyl(s, alto * 0.5, alto * 0.5, w, luce,
				Vector3(0, 0, -d * 0.5)).rotation.z = PI * 0.5
		y += alto


## UN TELO A PIEGHE (la tenda del camerino, il fondale della vetrina).
## Le pieghe sono cilindri affiancati che si compenetrano: è il modo più
## economico di avere una stoffa pesante che non sia una tavola. Se
## `raccolta` > 0 le pieghe si addensano a sinistra — la tenda tirata.
static func _telo(parent: Node3D, pos: Vector3, largo: float, alto: float,
		mat: Material, pieghe := 9, raccolta := 0.0, seme := 7) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7_700 + seme * 13
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	for i in pieghe:
		var u := float(i) / float(maxi(pieghe - 1, 1))
		# addensamento: u^k porta le pieghe verso sinistra
		var uu: float = pow(u, 1.0 + raccolta * 1.8)
		var x := lerpf(-largo * 0.5, largo * 0.5, uu)
		var r: float = largo / float(pieghe) * (0.62 + rng.randf_range(-0.06, 0.1))
		# l'orlo non è mai in bolla: ogni piega finisce a una quota sua
		var h := alto + rng.randf_range(-0.012, 0.012)
		CAT._cyl(n, r, r * 1.06, h, mat,
				Vector3(x, -h * 0.5, rng.randf_range(-0.008, 0.008)))


## UN SACCHETTO DI CARTA col manico di corda: il segno che qualcuno ha
## comprato. Il manico è un tubo vero che scende ai due lati, non un
## archetto piatto.
static func _sacchetto(parent: Node3D, pos: Vector3, giro: float, seme := 1) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = giro
	parent.add_child(n)
	var carta := CAT._mat(CARTA, CARTA_CUPA, 4.0, 0.4)
	var carta_om := CAT._mat(CARTA_CUPA, CARTA_CUPA.darkened(0.12), 4.0, 0.4)
	var w := 0.13
	var h := 0.17
	var d := 0.068
	CAT._box(n, Vector3(w, h, d), carta, Vector3(0, h * 0.5, 0))
	# i soffietti laterali: due righe d'ombra, ed è un sacchetto e non un mattone
	for lato: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.008, h * 0.96, d * 1.02), carta_om,
				Vector3(lato * w * 0.5, h * 0.5, 0))
	CAT._box(n, Vector3(w * 1.03, 0.016, d * 1.03), carta_om, Vector3(0, h - 0.008, 0))
	# il marchio: una barra sottile e basta. Un logo disegnato, a questa
	# scala, è una macchia; una barra è tipografia.
	CAT._box(n, Vector3(w * 0.42, 0.012, 0.004), _grafite(),
			Vector3(0, h * 0.56, -d * 0.5 - 0.002))
	# i manici
	var corda := CAT._mat(CORDA, CORDA.darkened(0.18), 6.0, 0.3)
	for z: float in [-1.0, 1.0]:
		BUILDER.tube(n, [
				Vector3(-w * 0.3, h - 0.01, z * d * 0.42),
				Vector3(-w * 0.22, h + 0.045, z * d * 0.34),
				Vector3(w * 0.22, h + 0.045, z * d * 0.34),
				Vector3(w * 0.3, h - 0.01, z * d * 0.42)],
				[0.004, 0.005, 0.005, 0.004], corda, 12, 6)
	# la velina che spunta
	var velina := CAT._mat(VELINA, Color("ece2d2"), 7.0, 0.25)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3_100 + seme * 71
	for i in 2:
		var v := CAT._box(n, Vector3(w * 0.5, 0.055, 0.012), velina,
				Vector3(rng.randf_range(-0.02, 0.02), h + 0.018, rng.randf_range(-0.015, 0.015)))
		v.rotation.z = rng.randf_range(-0.35, 0.35)
		v.rotation.y = rng.randf_range(-0.4, 0.4)
	return n


## UN PAIO DI SCARPE. Mai parallele: due scarpe allineate al millimetro
## sono due scarpe in vetrina di un negozio che ha chiuso.
static func _scarpe(parent: Node3D, pos: Vector3, colore: int, giro := 0.0) -> void:
	var pelle := _stoffa(colore)
	var suola := _stoffa(colore, 0.25)
	for i in 2:
		var s := Node3D.new()
		s.position = pos + Vector3(-0.045 + 0.09 * float(i), 0, 0)
		s.rotation.y = giro + (0.14 if i == 0 else -0.09)
		parent.add_child(s)
		CAT._box(s, Vector3(0.062, 0.038, 0.135), pelle, Vector3(0, 0.03, 0))
		CAT._ball(s, 0.033, pelle, Vector3(0, 0.028, -0.062), Vector3(0.95, 0.85, 1.1))
		CAT._box(s, Vector3(0.066, 0.012, 0.14), suola, Vector3(0, 0.007, 0))
		# il collo del piede, che alza il davanti
		CAT._ball(s, 0.03, pelle, Vector3(0, 0.048, 0.03), Vector3(0.9, 0.8, 1.3))


## UN CAPPELLO a tesa: superficie di rivoluzione, più il nastro.
static func _cappello(parent: Node3D, pos: Vector3, colore: int) -> void:
	var feltro := _stoffa(colore)
	BUILDER.lathe(parent, [
			Vector2(0.105, 0.0), Vector2(0.104, 0.010), Vector2(0.066, 0.016),
			Vector2(0.063, 0.020), Vector2(0.060, 0.070), Vector2(0.050, 0.082),
			Vector2(0.028, 0.086)],
			feltro, pos, 20)
	CAT._cyl(parent, 0.064, 0.065, 0.016, _stoffa(colore, 0.22),
			pos + Vector3(0, 0.030, 0))


# ------------------------------------------------------------- le lettere
# L'INSEGNA È TIPOGRAFIA, non un oggetto dipinto. Le lettere si costruiscono
# con tratti: le aste sono scatole sottili, le curve sono archi di scatoline
# ruotate sulla TANGENTE (stesso mestiere dei conci d'arco della chiesa: col
# segno sbagliato la curva si sbriciola in una manciata di sassi per aria).
#
# ============================================================
# LA SCRITTA VA SPECCHIATA, E NON È UN DETTAGLIO
# ============================================================
# In questo catalogo il FRONTE di un pezzo guarda -Z (lo dice la
# lavagnetta del bar: l'anta inclinata porta il bordo basso «verso chi
# guarda», cioè verso -Z). Ma chi sta a -Z e guarda verso +Z ha la propria
# destra su -X: scrivendo le lettere a X crescenti, la parola gli arriva
# ROVESCIATA. La prima volta l'insegna diceva ADOM, con la D girata.
# Perciò tutto quello che è tipografia si costruisce in «spazio di
# lettura» (x cresce verso destra di chi legge) e si ribalta all'ultimo
# momento: le posizioni cambiano segno, e con loro gli angoli degli archi
# — specchiare un arco senza specchiarne la tangente lo fa esplodere.
const _LETTURA := -1.0


static func _arco_tratti(parent: Node3D, centro: Vector3, rx: float, ry: float,
		da: float, a: float, quanti: int, mat: Material, sp: float) -> void:
	var passo := (a - da) / float(quanti)
	for i in quanti:
		var ang := da + passo * (float(i) + 0.5)
		var p := centro + Vector3(_LETTURA * cos(ang) * rx, sin(ang) * ry, 0)
		# la lunghezza del tratto: l'arco locale, un filo abbondante così
		# i tratti si toccano invece di lasciare i puntini
		var lun := absf(passo) * (rx + ry) * 0.5 * 1.25 + sp * 0.5
		var t := CAT._box(parent, Vector3(sp, lun, sp * 0.9), mat, p)
		t.rotation.z = _LETTURA * ang
	# (una scatola alta `lun` ruotata di `ang` ha l'asse lungo sulla
	# tangente: la normale del raggio è a +PI/2, e la scatola è già alta
	# lungo Y — perciò l'angolo va usato nudo, non +PI/2)


static func _lettera(parent: Node3D, ch: String, pos: Vector3, h: float,
		mat: Material, sp: float) -> void:
	var w := h * 0.62
	var n := Node3D.new()
	n.name = "lettera_" + ch
	n.position = pos
	parent.add_child(n)
	match ch:
		"M":
			for lato: float in [-1.0, 1.0]:
				CAT._box(n, Vector3(sp, h, sp * 0.9), mat,
						Vector3(_LETTURA * lato * w * 0.5, h * 0.5, 0))
			# le due diagonali scendono DALLA CIMA DELLE ASTE VERSO IL
			# CENTRO: col segno opposto la lettera si rovescia in una W, e
			# una W dentro «MODA» non la nota nessuno finché non la nota
			# qualcuno
			for lato2: float in [-1.0, 1.0]:
				var d := CAT._box(n, Vector3(sp, h * 0.70, sp * 0.9), mat,
						Vector3(_LETTURA * lato2 * w * 0.26, h * 0.66, 0))
				d.rotation.z = _LETTURA * -lato2 * 0.34
		"O":
			_arco_tratti(n, Vector3(0, h * 0.5, 0), w * 0.5, h * 0.5,
					0.0, TAU, 16, mat, sp)
		"D":
			CAT._box(n, Vector3(sp, h, sp * 0.9), mat,
					Vector3(_LETTURA * -w * 0.42, h * 0.5, 0))
			_arco_tratti(n, Vector3(_LETTURA * -w * 0.42, h * 0.5, 0),
					w * 0.92, h * 0.5, -PI * 0.5, PI * 0.5, 9, mat, sp)
		"A":
			for lato3: float in [-1.0, 1.0]:
				var g := CAT._box(n, Vector3(sp, h, sp * 0.9), mat,
						Vector3(_LETTURA * lato3 * w * 0.24, h * 0.5, 0))
				g.rotation.z = _LETTURA * lato3 * 0.20
			CAT._box(n, Vector3(w * 0.52, sp * 0.85, sp * 0.9), mat,
					Vector3(0, h * 0.34, 0))
		_:
			CAT._box(n, Vector3(sp, h, sp * 0.9), mat, Vector3(0, h * 0.5, 0))


## Una parola, con la spaziatura LARGA: è la crenatura a dire «moda». Le
## stesse lettere strette diventano l'insegna di una ferramenta.
static func _scritta(parent: Node3D, testo: String, pos: Vector3, h: float,
		mat: Material, sp: float, passo: float) -> void:
	var n := testo.length()
	for i in n:
		var x := (float(i) - float(n - 1) * 0.5) * passo
		_lettera(parent, testo[i], pos + Vector3(_LETTURA * x, 0, 0), h, mat, sp)


# ------------------------------------------------------------- il manichino

## IL CORPO DEL MANICHINO, senza vestiti: busto a lathe, testa a uovo
## SENZA FACCIA, braccia morbide, e il palo d'ottone nella base tonda.
##
## Niente gambe e niente faccia, ed è una scelta: un pupazzo intero con la
## testona chibi e gli occhi, fermo dentro una vetrina, non è un
## manichino — è inquietante. Un busto liscio su un palo è quello che c'è
## davvero nelle vetrine, e si legge in mezzo secondo.
##
## LA POSA è metà del lavoro: fianchi spostati, una spalla più bassa,
## testa inclinata. Un manichino perfettamente diritto è un attaccapanni.
static func _manichino_corpo(parent: Node3D, y_base: float, scala := 1.0) -> Node3D:
	var gesso := CAT._mat(CAT.PLASTER, CAT.PLASTER_SHADE, 3.0, 0.42)
	var ottone := _ottone()
	# LA BASE E IL PALO IN GRAFITE, non in ottone. Visti da lontano
	# l'ottone e il gesso hanno lo stesso valore chiaro e la figura
	# diventava «un secchio su un bastone arancione»: il palo dev'essere
	# la cosa più scura del pezzo, così sparisce e resta la figura.
	CAT._cyl(parent, 0.19 * scala, 0.20 * scala, 0.022, _grafite(),
			Vector3(0, y_base + 0.011, 0))
	# il collarino d'ottone sta ALLA BASE DEL PALO, non sopra il disco: un
	# cilindro largo quanto la base non è un anello, è un altro disco — e
	# il piede tornava tutto arancione
	CAT._cyl(parent, 0.055 * scala, 0.062 * scala, 0.012, ottone,
			Vector3(0, y_base + 0.028, 0))
	CAT._cyl(parent, 0.019 * scala, 0.024 * scala, 0.40 * scala, _grafite(),
			Vector3(0, y_base + 0.026 + 0.20 * scala, 0))

	var corpo := Node3D.new()
	corpo.position = Vector3(0, y_base + 0.026 + 0.40 * scala, 0)
	corpo.rotation.y = 0.22          # tre quarti: mai di faccia al vetro
	corpo.rotation.z = 0.035         # il contrapposto
	parent.add_child(corpo)

	var busto := BUILDER.lathe(corpo, [
			Vector2(0.070, 0.00), Vector2(0.098, 0.055), Vector2(0.092, 0.135),
			Vector2(0.076, 0.215), Vector2(0.083, 0.290), Vector2(0.100, 0.360),
			Vector2(0.094, 0.410), Vector2(0.050, 0.442)],
			gesso, Vector3.ZERO, 24, scala, scala)
	busto.name = "busto"
	busto.scale = Vector3(1.0, 1.0, 0.66)

	# il collo e la testa a uovo, inclinata. Il collo è CORTO e grosso: col
	# collo sottile la testa sembrava staccata e appoggiata sopra il
	# bavero, come una pallina su un tee.
	CAT._cyl(corpo, 0.034 * scala, 0.040 * scala, 0.06 * scala, gesso,
			Vector3(0, 0.455 * scala, 0))
	var testa := CAT._ball(corpo, 0.078 * scala, gesso,
			Vector3(0.006 * scala, 0.566 * scala, 0),
			Vector3(0.92, 1.16, 0.95))
	testa.rotation.z = -0.09
	testa.rotation.y = 0.18

	# LE BRACCIA STANNO STRETTE AL CORPO. Aperte com'erano, di PROFILO
	# uscivano dalla manica del cappotto e correvano scoperte lungo il
	# davanti: un osso bianco attaccato a una figura vestita. Di fronte non
	# si vedeva niente — ed è per questo che si guarda anche di profilo.
	for lato: float in [-1.0, 1.0]:
		var fuori := 0.020 if lato < 0.0 else 0.013
		BUILDER.tube(corpo, [
				Vector3(lato * 0.082 * scala, 0.392 * scala, 0.004 * scala),
				Vector3(lato * (0.082 + fuori) * scala, 0.27 * scala, 0.012 * scala),
				Vector3(lato * (0.078 + fuori * 1.3) * scala, 0.13 * scala, 0.022 * scala),
				Vector3(lato * (0.068 + fuori) * scala, 0.045 * scala, 0.032 * scala)],
				[0.028 * scala, 0.024 * scala, 0.020 * scala, 0.017 * scala],
				gesso, 14, 10)
	return corpo


## La sciarpa attorno al collo, con i due capi che scendono davanti: è il
## pezzo che dà il MOVIMENTO a una figura ferma.
## La sciarpa attorno al collo, con i due capi che scendono davanti.
## Sta SOPRA il cappotto e i capi cadono DAVANTI a lui (z più negativo del
## petto): dentro il bavero non si vedeva, ed era esattamente il pezzo che
## doveva dare movimento a una figura ferma.
static func _sciarpa(corpo: Node3D, colore: int, scala := 1.0,
		z_petto := 0.10) -> void:
	var lana := _stoffa(colore)
	var y := 0.478 * scala
	BUILDER.tube(corpo, [
			Vector3(-0.058 * scala, y, 0.03 * scala),
			Vector3(0, y + 0.012 * scala, -0.055 * scala),
			Vector3(0.058 * scala, y, 0.03 * scala),
			Vector3(0.02 * scala, y - 0.02 * scala, 0.05 * scala)],
			[0.021, 0.025, 0.023, 0.018], lana, 16, 8)
	for i in 2:
		var x := (-0.032 + 0.066 * float(i)) * scala
		BUILDER.tube(corpo, [
				Vector3(x, y - 0.02 * scala, -z_petto * 0.55),
				Vector3(x + 0.012, y - 0.11 * scala, -z_petto),
				Vector3(x - 0.008, y - 0.21 * scala, -z_petto * 0.92)],
				[0.021, 0.018, 0.015], lana, 12, 8)


# ================================================================== i pezzi

## 1 · LA VETRINA. Il pezzo-àncora: comprarla porta con sé tutta la
## boutique (Economy.CORREDO), perché un negozio o c'è, o è una stanza
## con dentro un tavolo.
##
## È l'unica cosa del villaggio con un vetro DA TERRA AL TETTO, e questo
## è tutto il suo lavoro. Perché si legga come vetro e non come aria
## servono tre cose: il telaio sottile (un telaio grosso legge «finestra
## di casa»), il RIFLESSO obliquo — due lame chiarissime in diagonale,
## che sono il modo in cui si disegna il vetro da sempre — e la fascia
## SATINATA in basso, quella che nei negozi veri nasconde i piedi.
##
## Dietro il vetro: il podio, il manichino vestito, e i due faretti che
## gli buttano addosso una luce vera. Di sera è l'unica finestra del
## paese che illumina la strada invece di sé stessa.
static func vetrina() -> Node3D:
	var n := Node3D.new()
	var telaio := _grafite()
	var muro := _calce()

	# il telaio: montanti sottili, traversa alta, zoccolo basso
	for lato: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.055, 2.08, 0.13), telaio, Vector3(lato * 0.47, 1.04, 0))
	CAT._box(n, Vector3(1.0, 0.10, 0.14), telaio, Vector3(0, 2.03, 0))
	CAT._box(n, Vector3(1.0, 0.16, 0.15), muro, Vector3(0, 0.08, 0))
	CAT._box(n, Vector3(1.0, 0.022, 0.17), telaio, Vector3(0, 0.17, 0))

	# il vetro. Alpha bassa: da una vetrina si deve VEDERE DENTRO — è il
	# motivo per cui esiste. (E `_mat(..., trans)` non è trasparenza: la
	# translucency dell'handpaint è retro-illuminazione, e una vetrina
	# fatta così esce opaca. Il vetro del progetto è questo.)
	CAT._box(n, Vector3(0.88, 1.79, 0.018), CAT._vetro(0.20), Vector3(0, 1.08, 0))
	# la fascia satinata in basso
	var satinato := CAT._vetro(0.44)
	satinato.emission_energy_multiplier = 0.10
	CAT._box(n, Vector3(0.88, 0.20, 0.020), satinato, Vector3(0, 0.29, -0.002))
	# IL RIFLESSO: due lame oblique verso la strada (-Z)
	var lama := CAT._glow(Color(1, 1, 1, 0.20), Color(1, 1, 1), 0.35)
	lama.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lama.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var r1 := CAT._box(n, Vector3(0.13, 1.5, 0.004), lama, Vector3(-0.16, 1.16, -0.014))
	r1.rotation.z = 0.34
	var r2 := CAT._box(n, Vector3(0.05, 0.72, 0.004), lama, Vector3(0.14, 0.72, -0.014))
	r2.rotation.z = 0.34

	# --- dentro: il podio, il manichino vestito, il fondale ---
	var dentro := Node3D.new()
	dentro.name = "Vetrina"
	dentro.position = Vector3(0, 0, 0.22)
	n.add_child(dentro)
	# il podio: scuro sotto, chiaro sopra. Tutto chiaro spariva nel muro.
	CAT._box(dentro, Vector3(0.84, 0.12, 0.36), _grafite(), Vector3(0, 0.06, 0))
	CAT._box(dentro, Vector3(0.88, 0.022, 0.40), muro, Vector3(0, 0.131, 0))
	var corpo := _manichino_corpo(dentro, 0.142, 0.86)
	# stesso conto del manichino libero, con la scala della vetrina
	_capo(corpo, Vector3(0, 0.442 * 0.86 + 0.045, 0), 1, 0.56, 0.0, 2, 4,
			false, 1.40, 0.76)
	_sciarpa(corpo, 4, 0.86, 0.098)
	# IL FONDALE VA SCURO. Bianco su bianco si mangiava la figura: era la
	# cosa più luminosa della vetrina e il manichino, che è di gesso, ci
	# spariva dentro. Una vetrina funziona per CONTRASTO — il fondo sta
	# indietro e sotto, e la figura viene avanti.
	_telo(dentro, Vector3(0, 1.88, 0.185), 0.80, 1.70,
			CAT._mat(Color("8d8478"), Color("6f6860"), 3.5, 0.42), 8, 0.0, 5)

	# i due faretti in alto, puntati sul manichino, e la luce vera
	var lente := CAT._glow(Color("ffe9c2"), Color("ffd694"), 2.4)
	for dx: float in [-0.26, 0.26]:
		var braccio := Node3D.new()
		braccio.position = Vector3(dx, 1.93, 0.14)
		braccio.rotation.x = -0.72
		dentro.add_child(braccio)
		CAT._cyl(braccio, 0.028, 0.040, 0.10, _ottone(), Vector3(0, -0.05, 0))
		CAT._cyl(braccio, 0.036, 0.036, 0.012, lente, Vector3(0, -0.104, 0))
	var luce := OmniLight3D.new()
	luce.light_color = Color(1.0, 0.90, 0.72)
	luce.light_energy = 1.45
	luce.omni_range = 3.2
	luce.position = Vector3(0, 1.55, 0.28)
	n.add_child(luce)
	return n


## 2 · L'INSEGNA. Lettere sottili, staccate, in grafite su calce, con la
## riga d'ottone sotto e due lampadine a collo d'oca che le illuminano.
## Le altre insegne del paese sono OGGETTI (la tazzina, l'elmo): questa è
## una parola, ed è la differenza fra una bottega e un negozio.
static func insegna() -> Node3D:
	var n := Node3D.new()
	var pannello := CAT._mat(CALCE, CALCE_OMBRA, 2.5, 0.4)
	# L'INSEGNA STA DAVANTI AL MURO, non dentro. A z=0 finiva sepolta nel
	# muro della porta (che è spesso 0,14 e centrato lì): da fuori si
	# vedeva un pannello crema e basta, e la parola spariva.
	var zf := -0.075
	CAT._box(n, Vector3(1.0, 0.42, 0.06), pannello, Vector3(0, 1.86, zf))
	CAT._box(n, Vector3(1.0, 0.018, 0.075), _ottone(), Vector3(0, 1.645, zf))
	_scritta(n, "MODA", Vector3(0, 1.78, zf - 0.038), 0.17, _grafite(), 0.020, 0.185)
	# i due lumi a collo d'oca
	for dx: float in [-0.30, 0.30]:
		var b := Node3D.new()
		b.position = Vector3(dx, 2.09, zf + 0.02)
		n.add_child(b)
		BUILDER.tube(b, [Vector3(0, 0, 0), Vector3(0, 0.075, -0.01),
				Vector3(0, 0.10, -0.075), Vector3(0, 0.075, -0.12)],
				[0.010, 0.009, 0.009, 0.010], _ottone(), 12, 8)
		var cappa := CAT._cyl(b, 0.026, 0.055, 0.05, _ottone(), Vector3(0, 0.05, -0.135))
		cappa.rotation.x = -2.5
		CAT._cyl(b, 0.046, 0.046, 0.01, CAT._glow(Color("ffeccb"), Color("ffdba4"), 1.8),
				Vector3(0, 0.028, -0.146)).rotation.x = -2.5
	return n


## 3 · IL MANICHINO, libero. Vestito con un capo lungo e la sciarpa: da
## solo in mezzo al negozio è il pezzo che dice «qui si prova la roba».
static func manichino() -> Node3D:
	var n := Node3D.new()
	var corpo := _manichino_corpo(n, 0.0, 1.0)
	# IL CAPPOTTO DEV'ESSERE LUNGO E DEVE COPRIRE LA SPALLA. Corto dava un
	# barile (la silhouette di un cappotto sta nel rapporto fra larghezza
	# e lunghezza: qui ~1:2, con 0.44 era 1:1.5, cioè una botte); e
	# appeso troppo in basso lasciava fuori le spalle di gesso, che
	# facevano un bavaglino bianco sotto la testa.
	#
	# IL CONTO: la spalla del capo sta 0.045 sotto la sua origine, e la
	# base del collo del manichino è a 0.442*scala. Origine = somma.
	_capo(corpo, Vector3(0, 0.442 + 0.045, 0), 5, 0.62, 0.0, 2, 7, false, 1.45, 0.76)
	_sciarpa(corpo, 4, 1.0, 0.105)
	# la borsa appesa alla manica: il dettaglio che compone un LOOK. Sta
	# APPOGGIATA al fianco — staccata sembrava una valigetta a mezz'aria
	var pelle := _stoffa(7)
	var borsa := Node3D.new()
	borsa.position = Vector3(-0.132, 0.155, -0.012)
	borsa.rotation.z = 0.14
	borsa.rotation.y = 0.2
	corpo.add_child(borsa)
	CAT._box(borsa, Vector3(0.085, 0.075, 0.038), pelle, Vector3(0, -0.045, 0))
	CAT._box(borsa, Vector3(0.089, 0.012, 0.042), _stoffa(7, 0.2), Vector3(0, -0.010, 0))
	BUILDER.tube(borsa, [Vector3(-0.030, -0.010, 0), Vector3(-0.018, 0.034, 0),
			Vector3(0.018, 0.034, 0), Vector3(0.030, -0.010, 0)],
			[0.005, 0.005, 0.005, 0.005], _stoffa(7, 0.2), 10, 6)
	_posto(n, Vector3(0, 0, -0.62), Vector3.FORWARD)
	return n


## 4 · IL BUSTO SARTORIALE. L'altra faccia del mestiere: qui non si
## compra, si CUCE. Tela grezza, cucitura centrale, treppiede di legno,
## il metro da sarta buttato sulla spalla e tre spilli piantati.
static func busto() -> Node3D:
	var n := Node3D.new()
	var tela := CAT._mat(Color("e0d3b8"), Color("c4b394"), 4.5, 0.5)
	var legno := CAT._mat(CAT.WOOD, CAT.WOOD_DARK, 4.0, 0.5)

	# il treppiede: tre gambe svasate e il collare
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.4
		var g := CAT._box(n, Vector3(0.045, 0.56, 0.045), legno,
				Vector3(cos(a) * 0.10, 0.28, sin(a) * 0.10))
		g.rotation.x = -sin(a) * 0.24
		g.rotation.z = cos(a) * 0.24
	CAT._cyl(n, 0.045, 0.05, 0.05, legno, Vector3(0, 0.545, 0))
	CAT._cyl(n, 0.026, 0.026, 0.14, legno, Vector3(0, 0.62, 0))

	var b := Node3D.new()
	b.position = Vector3(0, 0.66, 0)
	b.rotation.y = 0.3
	n.add_child(b)
	var forma := BUILDER.lathe(b, [
			Vector2(0.052, 0.00), Vector2(0.090, 0.045), Vector2(0.100, 0.115),
			Vector2(0.081, 0.205), Vector2(0.089, 0.285), Vector2(0.104, 0.350),
			Vector2(0.092, 0.395), Vector2(0.043, 0.420)],
			tela, Vector3.ZERO, 24)
	forma.scale = Vector3(1.0, 1.0, 0.68)
	# la cucitura centrale e le due di fianco: è quello che rende una
	# forma di tela una forma DA SARTA
	var filo := CAT._mat(Color("b9a781"), Color("9d8b66"), 6.0, 0.3)
	CAT._box(b, Vector3(0.006, 0.40, 0.006), filo, Vector3(0, 0.21, -0.062))
	for lato: float in [-1.0, 1.0]:
		CAT._box(b, Vector3(0.005, 0.34, 0.005), filo, Vector3(lato * 0.062, 0.20, -0.03))
	# il pomello in cima
	CAT._ball(b, 0.028, legno, Vector3(0, 0.44, 0), Vector3(1, 0.8, 1))

	# il metro da sarta sulla spalla, coi trattini neri
	var metro := CAT._mat(Color("f0d886"), Color("d4b95f"), 6.0, 0.3)
	BUILDER.tube(b, [Vector3(-0.075, 0.36, -0.02), Vector3(-0.02, 0.395, -0.055),
			Vector3(0.06, 0.36, -0.03), Vector3(0.075, 0.20, -0.05),
			Vector3(0.055, 0.09, -0.06)],
			[0.008, 0.008, 0.008, 0.007, 0.007], metro, 20, 6)
	for i in 4:
		CAT._box(b, Vector3(0.003, 0.014, 0.010), _grafite(),
				Vector3(0.072 - 0.004 * float(i), 0.30 - 0.055 * float(i), -0.058))
	# tre spilli con la capocchia colorata
	for i in 3:
		var a2 := 0.6 + float(i) * 0.9
		var pos := Vector3(cos(a2) * 0.075, 0.24 + sin(a2) * 0.05, -0.05)
		CAT._cyl(b, 0.002, 0.002, 0.03, _grafite(), pos).rotation.x = 1.3
		CAT._ball(b, 0.008, _stoffa(1 + i), pos + Vector3(0, 0, -0.016))
	# lo scampolo piegato ai piedi
	_pila(n, Vector3(0.20, 0.0, 0.13), 2, 2, 0.15, 9)
	return n


## 5 · LO STENDER. Il pezzo che fa il negozio: la riga orizzontale di
## spalle tutte alla stessa quota.
##
## Due cose lo salvano dall'essere una rastrelliera: l'ASTA CHE SI FLETTE
## sotto il peso (un tubo curvo di un centimetro — le aste vere cedono
## sempre, e un'asta perfettamente dritta è il segno del disegno tecnico),
## e i capi di TAGLIO: quasi tutti impilati come si sfogliano davvero, e
## solo gli ultimi due girati di fronte, come i «frontali» in negozio.
## Più le due grucce VUOTE: qualcuno ha preso qualcosa ed è andato a
## provarselo.
static func stender() -> Node3D:
	var n := Node3D.new()
	var telaio := _grafite()
	var ottone := _ottone()
	# L'ASTA STA A 1,14, non a 1,28. Più in alto i capi (che sono capi da
	# chibi, corti) lasciavano sotto due terzi di aria: uno stender mezzo
	# vuoto non dice «negozio pieno di roba», dice «gruccia dimenticata».
	var y := 1.14

	# I MONTANTI STANNO LARGHI 0,46, NON 0,42. Con l'asta lunga quanto i
	# montanti, il capo all'estremità ci finiva DENTRO: la manica passava
	# da parte a parte e riemergeva sul lato esterno del palo, dove
	# restava una lama di stoffa incollata allo sfondo. La stanghetta
	# dev'essere più larga della roba che ci sta appesa.
	for lato: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.05, y, 0.05), telaio, Vector3(lato * 0.46, y * 0.5, 0))
		CAT._box(n, Vector3(0.09, 0.028, 0.42), telaio, Vector3(lato * 0.46, 0.014, 0))
		CAT._ball(n, 0.032, ottone, Vector3(lato * 0.46, y + 0.012, 0), Vector3(1, 0.7, 1))
	CAT._box(n, Vector3(0.88, 0.026, 0.026), telaio, Vector3(0, 0.20, 0))
	# L'ASTA CHE CEDE (si chiama così perché il test ci legge la quota
	# invece di riscriverla a mano: se un domani l'asta si alza, la prova
	# dei capi appesi si adegua da sola invece di mentire)
	var asta := BUILDER.tube(n, [Vector3(-0.46, y, 0), Vector3(-0.15, y - 0.012, 0),
			Vector3(0.15, y - 0.012, 0), Vector3(0.46, y, 0)],
			[0.014, 0.013, 0.013, 0.014], ottone, 18, 8)
	asta.name = "asta"

	# i capi: di taglio (giro = PI/2) e addensati, con i vuoti giusti
	var posti := [-0.335, -0.29, -0.252, -0.196, -0.155, -0.02, 0.022, 0.07, 0.115]
	var colori := [3, 0, 5, 3, 7, 2, 6, 1, 4]
	var lunghi := [0.56, 0.48, 0.66, 0.54, 0.60, 0.50, 0.63, 0.51, 0.57]
	var tagli := [1, 0, 2, 1, 0, 3, 2, 0, 1]
	for i in posti.size():
		_capo(n, Vector3(float(posti[i]), y - 0.011, 0.0), int(colori[i]),
				float(lunghi[i]), PI * 0.5 + (0.06 if i % 2 == 0 else -0.05),
				int(tagli[i]), i + 1)
	# i due frontali in fondo: quelli che il negozio vuole farti vedere
	_capo(n, Vector3(0.245, y - 0.011, 0.0), 0, 0.62, 0.0, 2, 21)
	_capo(n, Vector3(0.335, y - 0.011, 0.0), 5, 0.55, 0.0, 1, 22)
	# le due grucce vuote: qualcuno se n'è portato uno in camerino
	for x: float in [-0.385, 0.385]:
		var vuota := Node3D.new()
		vuota.position = Vector3(x, y - 0.011, 0)
		vuota.rotation.y = PI * 0.5 + (0.2 if x < 0.0 else -0.14)
		n.add_child(vuota)
		_gruccia(vuota, 0.156)
	_posto(n, Vector3(0, 0, -0.55), Vector3.FORWARD)
	return n


## 6 · IL TAVOLO DEI PIEGATI. Il tavolo basso di frassino con le pile.
## Regola del vuoto: TRE appoggi, DUE pile — e sul terzo un capo aperto
## a metà, quello che qualcuno ha srotolato e non ha rimesso a posto.
## È l'unico disordine del negozio, e serve: senza, è un catalogo.
static func tavolo_piegati() -> Node3D:
	var n := Node3D.new()
	var legno := CAT._mat(FRASSINO, FRASSINO_CUPO, 3.5, 0.45)
	var telaio := _grafite()
	# il piano e i quattro piedini sottili
	CAT._box(n, Vector3(0.92, 0.05, 0.62), legno, Vector3(0, 0.60, 0))
	CAT._box(n, Vector3(0.86, 0.02, 0.56), CAT._mat(FRASSINO_CUPO, FRASSINO_CUPO.darkened(0.1), 3.5, 0.4),
			Vector3(0, 0.573, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			CAT._box(n, Vector3(0.03, 0.58, 0.03), telaio,
					Vector3(sx * 0.40, 0.29, sz * 0.25))
	# il ripiano basso, con la scorta
	CAT._box(n, Vector3(0.80, 0.025, 0.50), legno, Vector3(0, 0.16, 0))
	_pila(n, Vector3(-0.16, 0.172, 0.0), 3, 4, 0.19, 11)

	# le due pile sopra, di altezza diversa
	_pila(n, Vector3(-0.24, 0.625, -0.02), 4, 0, 0.21, 13)
	_pila(n, Vector3(0.06, 0.625, 0.03), 3, 5, 0.20, 17)
	# il capo aperto a metà, buttato sull'angolo
	var aperto := Node3D.new()
	aperto.position = Vector3(0.30, 0.64, -0.04)
	aperto.rotation.y = 0.5
	aperto.rotation.z = 0.12
	n.add_child(aperto)
	var stoffa := _stoffa(2)
	CAT._box(aperto, Vector3(0.22, 0.022, 0.19), stoffa, Vector3.ZERO)
	CAT._box(aperto, Vector3(0.20, 0.018, 0.16), stoffa, Vector3(0.03, 0.019, 0.03)).rotation.y = 0.3
	CAT._cyl(aperto, 0.011, 0.011, 0.20, _stoffa(2, -0.06),
			Vector3(0.02, 0.012, -0.09)).rotation.z = PI * 0.5
	# una manica che pende oltre il bordo
	CAT._cyl(aperto, 0.018, 0.022, 0.16, stoffa, Vector3(0.10, -0.05, 0.10)).rotation.x = 0.5

	# il cartellino a leggio, col prezzo scritto a mano
	var carta := CAT._mat(VELINA, Color("e6dcc8"), 6.0, 0.25)
	var leggio := Node3D.new()
	leggio.position = Vector3(0.34, 0.63, 0.20)
	leggio.rotation.x = -0.34
	n.add_child(leggio)
	CAT._box(leggio, Vector3(0.115, 0.075, 0.004), carta, Vector3.ZERO)
	for i in 2:
		CAT._box(leggio, Vector3(0.06 - 0.022 * float(i), 0.007, 0.005), _grafite(),
				Vector3(-0.012 + 0.008 * float(i), 0.014 - 0.026 * float(i), -0.004))
	CAT._cyl(leggio, 0.004, 0.004, 0.05, _ottone(), Vector3(0, -0.05, 0.014)).rotation.x = 0.34
	_posto(n, Vector3(0, 0, -0.66), Vector3.FORWARD)
	return n


## 7 · LO SCAFFALE A GIORNO. La parete attrezzata: quattro ripiani a
## quota regolare (il RITMO), le pile, le scarpe, i cappelli, e sotto una
## barra corta con tre appesi. È il pezzo che riempie il muro di fondo.
static func scaffale() -> Node3D:
	var n := Node3D.new()
	var legno := CAT._mat(FRASSINO, FRASSINO_CUPO, 3.5, 0.45)
	var telaio := _grafite()
	# i due fianchi e lo schienale di calce
	CAT._box(n, Vector3(1.0, 2.0, 0.04), _calce(), Vector3(0, 1.0, 0.14))
	for lato: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.035, 2.0, 0.30), telaio, Vector3(lato * 0.48, 1.0, 0.0))
	# quattro ripiani, equidistanti: la ripetizione È l'esposizione
	var quote := [0.62, 1.02, 1.42, 1.80]
	for i in quote.size():
		var y: float = quote[i]
		CAT._box(n, Vector3(0.93, 0.036, 0.30), legno, Vector3(0, y, 0))
		for sx: float in [-0.34, 0.34]:
			CAT._box(n, Vector3(0.03, 0.05, 0.28), telaio, Vector3(sx, y - 0.04, 0.01))
	# la merce, diversa ripiano per ripiano
	_pila(n, Vector3(-0.26, 1.818, 0.0), 3, 0, 0.19, 23)
	_cappello(n, Vector3(0.19, 1.818, 0.0), 5)
	_pila(n, Vector3(-0.24, 1.438, 0.01), 4, 3, 0.20, 29)
	_pila(n, Vector3(0.16, 1.438, -0.01), 2, 6, 0.18, 31)
	_scarpe(n, Vector3(-0.26, 1.038, 0.0), 7, 0.2)
	_scarpe(n, Vector3(0.14, 1.038, 0.01), 1, -0.15)
	# il ripiano basso: le borse in piedi
	for i in 3:
		var b := Node3D.new()
		b.position = Vector3(-0.28 + 0.29 * float(i), 0.638, 0.0)
		b.rotation.y = -0.2 + 0.24 * float(i)
		n.add_child(b)
		var col := 2 + i * 2
		CAT._box(b, Vector3(0.13, 0.115, 0.055), _stoffa(col), Vector3(0, 0.058, 0))
		BUILDER.tube(b, [Vector3(-0.045, 0.112, 0), Vector3(-0.03, 0.168, 0),
				Vector3(0.03, 0.168, 0), Vector3(0.045, 0.112, 0)],
				[0.006, 0.006, 0.006, 0.006], _stoffa(col, 0.2), 10, 6)
	# la barra bassa con tre appesi
	BUILDER.tube(n, [Vector3(-0.44, 0.50, 0.0), Vector3(0, 0.492, 0.0),
			Vector3(0.44, 0.50, 0.0)], [0.011, 0.011, 0.011], _ottone(), 12, 8)
	for i in 3:
		_capo(n, Vector3(-0.22 + 0.22 * float(i), 0.489, 0.0), 1 + i * 2, 0.34,
				PI * 0.5 + 0.05 * float(i), i % 3, 40 + i)
	return n


## 8 · IL CAMERINO. La cabina con la tenda pesante mezza tirata: dentro
## si intravede lo specchio, il gancio con un capo già appeso e la
## panchetta. Il numero d'ottone sulla montante è quello che lo rende un
## CAMERINO e non un ripostiglio.
static func camerino() -> Node3D:
	var n := Node3D.new()
	var muro := _calce()
	var telaio := _grafite()
	# le due pareti laterali e il cielino
	for lato: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.06, 2.0, 0.72), muro, Vector3(lato * 0.45, 1.0, 0.10))
	CAT._box(n, Vector3(0.96, 0.04, 0.76), muro, Vector3(0, 2.0, 0.08))
	CAT._box(n, Vector3(0.96, 0.05, 0.06), telaio, Vector3(0, 1.98, -0.26))
	# lo schienale, e dentro lo specchio a tutta altezza
	CAT._box(n, Vector3(0.90, 1.98, 0.05), muro, Vector3(0, 0.99, 0.44))
	var dentro := Node3D.new()
	dentro.position = Vector3(0.10, 1.05, 0.41)
	dentro.rotation.y = PI
	n.add_child(dentro)
	_lastra_specchio(dentro, 0.40, 1.30, 0.0)
	for sx: float in [-1.0, 1.0]:
		CAT._box(dentro, Vector3(0.022, 1.36, 0.022), _ottone(), Vector3(sx * 0.21, 0, -0.004))
	for sy: float in [-1.0, 1.0]:
		CAT._box(dentro, Vector3(0.44, 0.022, 0.022), _ottone(), Vector3(0, sy * 0.68, -0.004))

	# LA TENDA, TIRATA PER DAVVERO. Coprendo tutta la luce non si vedeva
	# niente dentro, e un camerino chiuso è un armadio: è quello che si
	# INTRAVEDE (lo specchio, il capo appeso, la panchetta) a dire cosa
	# succede lì. Copre due terzi, e le pieghe sono tante e strette — con
	# poche pieghe larghe il velluto sembrava un pannello di legno.
	_telo(n, Vector3(-0.18, 1.95, -0.26), 0.56, 1.72,
			CAT._mat(ARGILLA, ARGILLA_CUPA, 4.5, 0.55), 13, 0.5, 3)
	# gli anelli sulla barra
	var barra := CAT._cyl(n, 0.012, 0.012, 0.88, _ottone(), Vector3(0, 1.95, -0.26))
	barra.rotation.z = PI * 0.5
	for i in 6:
		CAT._cyl(n, 0.022, 0.022, 0.006, _ottone(),
				Vector3(-0.40 + 0.075 * float(i), 1.95, -0.26)).rotation.z = PI * 0.5

	# il gancio col capo già dentro, e la panchetta
	CAT._cyl(n, 0.008, 0.008, 0.05, _ottone(), Vector3(-0.30, 1.62, 0.40)).rotation.x = PI * 0.5
	_capo(n, Vector3(-0.30, 1.60, 0.36), 6, 0.44, 0.15, 1, 51)
	var legno := CAT._mat(FRASSINO, FRASSINO_CUPO, 3.5, 0.45)
	CAT._box(n, Vector3(0.42, 0.05, 0.22), legno, Vector3(0.14, 0.34, 0.34))
	for sx2: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.03, 0.32, 0.03), telaio, Vector3(0.14 + sx2 * 0.17, 0.17, 0.34))
	# il numero d'ottone
	CAT._box(n, Vector3(0.07, 0.10, 0.012), _ottone(), Vector3(0.45, 1.62, -0.29))
	CAT._box(n, Vector3(0.012, 0.06, 0.006), _calce(), Vector3(0.455, 1.62, -0.298))
	# e il lume caldo dentro: è quello che, da fuori, fa capire che il
	# camerino è un posto e non un ripostiglio
	var luce := OmniLight3D.new()
	luce.light_color = Color(1.0, 0.88, 0.70)
	luce.light_energy = 0.85
	luce.omni_range = 1.9
	luce.position = Vector3(0.05, 1.72, 0.16)
	n.add_child(luce)
	_posto(n, Vector3(0.05, 0, 0.16), Vector3.BACK)
	return n


## 9 · LA SPECCHIERA a tre ante. Le due ante laterali chiuse a 25°: è
## quello che fa vedere il fianco e la schiena, ed è il motivo per cui in
## un negozio gli specchi sono tre e non uno. Cornici d'ottone sottili,
## base bassa: deve pesare poco alla vista.
static func specchiera() -> Node3D:
	var n := Node3D.new()
	var ottone := _ottone()
	var legno := CAT._mat(FRASSINO, FRASSINO_CUPO, 3.5, 0.45)
	CAT._box(n, Vector3(0.86, 0.06, 0.34), legno, Vector3(0, 0.03, 0.06))
	CAT._box(n, Vector3(0.88, 0.016, 0.36), ottone, Vector3(0, 0.066, 0.06))

	# LE ANTE LATERALI VANNO FUORI E GIRATE FORTE. A 25° e piazzate dentro
	# l'ingombro della centrale si sovrapponevano: tre lastre quasi
	# parallele leggono «box doccia», non «specchiera». Il senso delle tre
	# ante è vedersi di fianco: la piega si deve VEDERE.
	var ante := [[0.0, 0.0, 0.44, 1.62], [-0.31, 0.62, 0.30, 1.44],
			[0.31, -0.62, 0.30, 1.44]]
	for a in ante:
		var pannello := Node3D.new()
		pannello.position = Vector3(float(a[0]), 0.09 + float(a[3]) * 0.5, 0.14)
		pannello.rotation.y = float(a[1])
		n.add_child(pannello)
		var w: float = float(a[2])
		var h: float = float(a[3])
		_lastra_specchio(pannello, w, h, -0.01)
		# cornice SOTTILE: d'ottone grosso, a questa scala, la specchiera
		# diventava una gabbia arancione e lo specchio spariva
		for sx: float in [-1.0, 1.0]:
			CAT._box(pannello, Vector3(0.018, h + 0.036, 0.026), ottone,
					Vector3(sx * (w * 0.5 + 0.009), 0, -0.012))
		for sy: float in [-1.0, 1.0]:
			CAT._box(pannello, Vector3(w + 0.036, 0.018, 0.026), ottone,
					Vector3(0, sy * (h * 0.5 + 0.009), -0.012))
		# la cimasa: un tondino sopra ogni anta
		CAT._ball(pannello, 0.018, ottone, Vector3(0, h * 0.5 + 0.028, -0.012),
				Vector3(1, 0.75, 1))
	_posto(n, Vector3(0, 0, -0.62), Vector3.BACK)
	return n


## 10 · IL BANCONE DELLA CASSA. Marmo di fiume sopra, grafite sotto, il
## poggiapiedi d'ottone consumato — e sopra le cose che si usano davvero:
## il campanello, la pila dei sacchetti pronti, la velina, il rocchetto
## di nastro e la ciotola delle noccioline (perché qui si paga in
## noccioline, e un cassetto pieno di monete sarebbe un altro gioco).
static func cassa() -> Node3D:
	var n := Node3D.new()
	var marmo := CAT._mat(CAT.MARMO, Color("ded6c6"), 5.0, 0.3)
	var telaio := _grafite()
	var ottone := _ottone()
	CAT._box(n, Vector3(0.96, 0.92, 0.50), telaio, Vector3(0, 0.46, 0.02))
	# LE SPECCHIATURE VANNO CHIARE. Grigio su grigio il bancone era un
	# blocco nero: a un metro di distanza non si leggeva più il mobile, si
	# leggeva un buco. Due riquadri di calce dentro il telaio scuro, e
	# torna a essere un bancone.
	for dx: float in [-0.24, 0.24]:
		CAT._box(n, Vector3(0.36, 0.60, 0.02), _calce(), Vector3(dx, 0.48, -0.235))
		CAT._box(n, Vector3(0.40, 0.64, 0.014), CAT._mat(GRAFITE_CHIARA, GRAFITE, 4.0, 0.3),
				Vector3(dx, 0.48, -0.228))
	# il piano di marmo, spesso e sporgente: è la cosa che si vede da fuori
	CAT._box(n, Vector3(1.06, 0.085, 0.60), marmo, Vector3(0, 0.94, 0.0))
	CAT._box(n, Vector3(1.02, 0.014, 0.03), ottone, Vector3(0, 0.985, -0.29))
	var poggia := CAT._cyl(n, 0.018, 0.018, 0.86, ottone, Vector3(0, 0.13, -0.28))
	poggia.rotation.z = PI * 0.5
	for dx2: float in [-0.40, 0.40]:
		CAT._cyl(n, 0.015, 0.015, 0.13, ottone, Vector3(dx2, 0.065, -0.28))

	# il campanello a cupola
	CAT._cyl(n, 0.052, 0.058, 0.012, ottone, Vector3(-0.32, 0.984, 0.02))
	CAT._ball(n, 0.045, ottone, Vector3(-0.32, 0.998, 0.02), Vector3(1, 0.62, 1))
	CAT._ball(n, 0.011, ottone, Vector3(-0.32, 1.028, 0.02))
	# i sacchetti pronti, piatti in pila
	for i in 3:
		var s := CAT._box(n, Vector3(0.15, 0.012, 0.10),
				CAT._mat(CARTA, CARTA_CUPA, 4.0, 0.4),
				Vector3(0.30 + 0.006 * float(i), 0.987 + 0.013 * float(i), 0.13))
		s.rotation.y = -0.12 + 0.06 * float(i)
	# il rocchetto di nastro e la velina
	CAT._cyl(n, 0.038, 0.038, 0.055, _stoffa(1), Vector3(0.10, 1.008, 0.16)).rotation.z = PI * 0.5
	CAT._cyl(n, 0.012, 0.012, 0.062, _ottone(), Vector3(0.10, 1.008, 0.16)).rotation.z = PI * 0.5
	var velina := CAT._mat(VELINA, Color("ece2d2"), 7.0, 0.25)
	for i in 2:
		var v := CAT._box(n, Vector3(0.13, 0.008, 0.11), velina,
				Vector3(-0.06 + 0.02 * float(i), 0.985 + 0.008 * float(i), 0.16))
		v.rotation.y = 0.3 - 0.5 * float(i)
	# la ciotola delle noccioline
	CAT._cyl(n, 0.05, 0.036, 0.035, marmo, Vector3(-0.10, 0.997, -0.12))
	for i in 5:
		var a := TAU * float(i) / 5.0
		CAT._ball(n, 0.014, CAT._mat(Color("c4a06a"), Color("a8804c"), 5.0, 0.4),
				Vector3(-0.10 + cos(a) * 0.022, 1.016, -0.12 + sin(a) * 0.022),
				Vector3(1, 0.85, 1.15))
	_posto(n, Vector3(0, 0, -0.62), Vector3.FORWARD)
	var dietro := _posto(n, Vector3(0, 0, 0.48), Vector3.BACK)
	dietro.name = "posto_banco"
	return n


## 11 · LA POLTRONCINA. Quella davanti ai camerini, dove si aspetta chi
## sta provando. Tutta curve morbide (sfere schiacciate, niente spigoli)
## su quattro gambe d'ottone sottili: deve sembrare che ci si affondi.
static func poltroncina() -> Node3D:
	var n := Node3D.new()
	var boucle := CAT._mat(Color("efe4d0"), Color("d8c9ad"), 7.0, 0.55)
	var ottone := _ottone()
	# LE GAMBE DEVONO ARRIVARE SOTTO LA SEDUTA. La seduta è una sfera
	# schiacciata: al suo bordo la pancia è ALTA, e quattro gambe piantate
	# larghe finivano otto centimetri sotto il fondo — di profilo si
	# vedevano quattro bastoncini d'ottone sospesi sotto una nuvola. Più
	# strette e più lunghe, così la cima entra nell'imbottitura.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var g := CAT._cyl(n, 0.011, 0.014, 0.31, ottone,
					Vector3(sx * 0.155, 0.145, sz * 0.14))
			g.rotation.x = sz * 0.12
			g.rotation.z = -sx * 0.12
	# la seduta: una sfera schiacciata, non una scatola
	CAT._ball(n, 0.27, boucle, Vector3(0, 0.34, 0), Vector3(1.0, 0.42, 0.86))
	CAT._ball(n, 0.24, CAT._mat(Color("f5ecdb"), Color("ded0b6"), 7.0, 0.5),
			Vector3(0, 0.40, -0.01), Vector3(0.95, 0.20, 0.8))
	# lo schienale avvolgente e i braccioli, tutto dallo stesso stampo
	var sch := CAT._ball(n, 0.25, boucle, Vector3(0, 0.55, 0.20), Vector3(1.0, 0.85, 0.34))
	sch.rotation.x = -0.16
	for sx2: float in [-1.0, 1.0]:
		var br := CAT._ball(n, 0.17, boucle, Vector3(sx2 * 0.24, 0.47, 0.02),
				Vector3(0.34, 0.55, 1.05))
		br.rotation.z = sx2 * 0.10
	# il cuscino buttato di sbieco
	var c := CAT._ball(n, 0.13, _stoffa(3), Vector3(0.05, 0.44, 0.06),
			Vector3(1.0, 0.42, 0.9))
	c.rotation.y = 0.4
	c.rotation.z = 0.12
	_posto(n, Vector3(0, 0.36, -0.05), Vector3.FORWARD)
	return n


## 12 · IL CESTO DEI SALDI. L'anti-vetrina: il posto dove la roba è
## ammucchiata e ci si fruga dentro. Serve al negozio quanto la vetrina —
## un negozio tutto ordinato è uno showroom, e in uno showroom non si
## entra. Il cartello è d'ardesia col gesso, come la lavagnetta del bar.
static func cesto_saldi() -> Node3D:
	var n := Node3D.new()
	var vimini := CAT._mat(Color("cdb182"), Color("ab8f60"), 4.0, 0.5)
	# il cesto: BASSO e LARGO. Alto e stretto era un vaso da fiori — e in
	# un vaso da fiori non si fruga.
	BUILDER.lathe(n, [
			Vector2(0.26, 0.0), Vector2(0.275, 0.03), Vector2(0.325, 0.18),
			Vector2(0.355, 0.32), Vector2(0.365, 0.35)],
			vimini, Vector3.ZERO, 22)
	for i in 3:
		var y := 0.06 + 0.10 * float(i)
		var r := 0.284 + 0.026 * float(i)
		CAT._cyl(n, r, r, 0.016, CAT._mat(Color("b89a6c"), Color("9a7d52"), 4.0, 0.45),
				Vector3(0, y, 0))
	# IL BORDO È UN ANELLO, non un disco: un cilindro pieno appoggiato in
	# cima al cesto è un COPERCHIO, e sotto un coperchio i saldi non si
	# vedono. Sedici cubetti in cerchio, e resta aperto. Le tre quote
	# dell'orlo stanno QUI e basta: le maniche qui sotto ci si appendono.
	var r_orlo := 0.362
	var y_orlo := 0.352
	var sp_orlo := Vector3(0.05, 0.026, 0.15)
	for i in 16:
		var ab := TAU * float(i) / 16.0
		var b := CAT._box(n, sp_orlo, vimini,
				Vector3(cos(ab) * r_orlo, y_orlo, sin(ab) * r_orlo))
		b.rotation.y = -ab

	# LA ROBA DEVE TRABOCCARE. Con pochi mucchietti piccoli dentro un
	# cesto profondo sembrava un vaso da fiori: un cesto dei saldi si
	# riconosce perché è PIENO fino a sopra il bordo e non si capisce dove
	# finisce un capo e comincia l'altro.
	var rng := RandomNumberGenerator.new()
	rng.seed = 84_211
	# gli STRATI DI STOFFA: scatole piatte e ruotate, non palle. Le palle
	# davano un cesto di uova; quello che dice «stoffa buttata dentro» è
	# lo spigolo piatto di un capo piegato male, ripetuto storto.
	for i in 16:
		var a := TAU * float(i) / 16.0 * 1.7 + rng.randf_range(-0.4, 0.4)
		var r2 := rng.randf_range(0.02, 0.26)
		var s := Node3D.new()
		s.position = Vector3(cos(a) * r2, 0.345 + rng.randf_range(-0.05, 0.13),
				sin(a) * r2)
		s.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.0, TAU),
				rng.randf_range(-0.5, 0.5))
		n.add_child(s)
		var w: float = rng.randf_range(0.16, 0.25)
		var d: float = rng.randf_range(0.11, 0.18)
		CAT._box(s, Vector3(w, rng.randf_range(0.035, 0.06), d), _stoffa(i),
				Vector3.ZERO)
		CAT._cyl(s, 0.022, 0.022, w, _stoffa(i, -0.05),
				Vector3(0, 0.004, -d * 0.5)).rotation.z = PI * 0.5
	# tre maniche che pendono fuori dal bordo: è il segno che dentro c'è ROBA
	# UNA MANICA DRITTA NON SCAVALCA UN ORLO. Era un cilindro inclinato di
	# fianco: i suoi due capi si allargavano a 0.344 di raggio e quello basso
	# finiva a y=0.27, dove la parete è già rientrata a 0.345 — col suo raggio
	# di 3 cm la manica ne usciva 2,7 cm e spuntava sul vimini come una toppa,
	# in tutt'e tre le foto. Ora è un TUBO PIEGATO: parte dal mucchio, passa
	# SOPRA i cubetti dell'orlo (dove una manica si appoggia davvero) e ricade
	# lungo la parete senza toccarla. Le quote si contano dall'orlo, così
	# restano appese lì anche se il cesto cambia misura.
	var orlo_fuori := r_orlo + sp_orlo.x * 0.5
	var orlo_sopra := y_orlo + sp_orlo.y * 0.5
	for i in 3:
		var a2 := 0.7 + float(i) * 2.1
		var m := Node3D.new()
		m.rotation.y = -a2                     # la X locale guarda in fuori
		n.add_child(m)
		BUILDER.tube(m, [
				Vector3(0.19, orlo_sopra + 0.037 + 0.015 * float(i), 0.0),
				Vector3(r_orlo - 0.032, orlo_sopra + 0.027, 0.0),
				Vector3(orlo_fuori + 0.011, y_orlo, 0.010),
				Vector3(orlo_fuori + 0.017, 0.250 - 0.025 * float(i), 0.028)],
				[0.030, 0.031, 0.028, 0.021], _stoffa(1 + i * 3), 22, 12)

	# il cartello d'ardesia sul filo di ferro
	var ferro := CAT._mat(Color("4f4a45"), Color("3d3935"), 5.0, 0.4)
	CAT._cyl(n, 0.006, 0.006, 0.34, ferro, Vector3(-0.24, 0.52, -0.17))
	var card := Node3D.new()
	card.position = Vector3(-0.24, 0.72, -0.17)
	card.rotation.y = 0.3
	card.rotation.z = -0.06
	n.add_child(card)
	CAT._box(card, Vector3(0.24, 0.16, 0.014),
			CAT._mat(Color("2f3a33"), Color("26302a"), 5.5, 0.3), Vector3.ZERO)
	CAT._box(card, Vector3(0.26, 0.02, 0.02), CAT._mat(CAT.WOOD, CAT.WOOD_DARK, 4.0, 0.5),
			Vector3(0, 0.085, 0))
	CAT._box(card, Vector3(0.26, 0.02, 0.02), CAT._mat(CAT.WOOD, CAT.WOOD_DARK, 4.0, 0.5),
			Vector3(0, -0.085, 0))
	# «SALDI» a gesso: parole di lunghezze diverse, storte, come a mano
	var gesso := CAT._mat(Color("fdf6e8"), Color("ece2cf"), 6.0, 0.22)
	var x := -0.085
	for lung: float in [0.055, 0.032, 0.048]:
		var t := CAT._box(card, Vector3(lung, 0.014, 0.006), gesso,
				Vector3(x + lung * 0.5, 0.028, -0.010))
		t.rotation.z = 0.03 if int(x * 100.0) % 2 == 0 else -0.02
		x += lung + 0.012
	var sotto := CAT._box(card, Vector3(0.15, 0.008, 0.006), gesso,
			Vector3(-0.01, -0.006, -0.010))
	sotto.rotation.z = -0.025
	for i in 2:
		CAT._box(card, Vector3(0.03 + 0.014 * float(i), 0.011, 0.006), gesso,
				Vector3(-0.05 + 0.05 * float(i), -0.045, -0.010))
	return n


## 13 · I FARETTI. Il treppiede col braccio e tre coni d'ottone puntati
## in tre punti diversi — la luce di un negozio non è mai d'ambiente: è
## puntata addosso alla merce. Di sera è la lampada più calda del paese.
static func faretti() -> Node3D:
	var n := Node3D.new()
	var telaio := _grafite()
	var ottone := _ottone()
	# il treppiede
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.5
		var g := CAT._box(n, Vector3(0.032, 0.46, 0.032), telaio,
				Vector3(cos(a) * 0.09, 0.22, sin(a) * 0.09))
		g.rotation.x = -sin(a) * 0.30
		g.rotation.z = cos(a) * 0.30
		CAT._ball(n, 0.022, ottone, Vector3(cos(a) * 0.155, 0.012, sin(a) * 0.155),
				Vector3(1, 0.6, 1))
	CAT._cyl(n, 0.030, 0.036, 0.048, telaio, Vector3(0, 0.44, 0))
	CAT._cyl(n, 0.022, 0.026, 1.32, telaio, Vector3(0, 1.10, 0))
	CAT._ball(n, 0.034, ottone, Vector3(0, 1.76, 0), Vector3(1, 0.85, 1))
	# il braccio orizzontale
	var braccio := CAT._cyl(n, 0.016, 0.016, 0.62, telaio, Vector3(0, 1.72, 0))
	braccio.rotation.z = PI * 0.5
	var lente := CAT._glow(Color("ffe9c2"), Color("ffd694"), 2.6)
	# tre coni, tre direzioni diverse
	var pose := [[-0.26, -0.62, 0.30], [0.0, -0.95, -0.16], [0.26, -0.55, -0.44]]
	for p in pose:
		var testa := Node3D.new()
		testa.position = Vector3(float(p[0]), 1.72, 0)
		testa.rotation.x = float(p[1])
		testa.rotation.y = float(p[2])
		n.add_child(testa)
		CAT._cyl(testa, 0.030, 0.052, 0.13, ottone, Vector3(0, -0.075, 0))
		CAT._cyl(testa, 0.048, 0.048, 0.012, lente, Vector3(0, -0.143, 0))
		CAT._cyl(testa, 0.020, 0.020, 0.03, telaio, Vector3(0, 0.005, 0))
	var luce := OmniLight3D.new()
	luce.light_color = Color(1.0, 0.89, 0.70)
	luce.light_energy = 1.5
	luce.omni_range = 4.4
	luce.position = Vector3(0, 1.60, 0)
	n.add_child(luce)
	return n


## 14 · LA PASSATOIA. La striscia chiara che porta dalla porta ai
## camerini: costa poco e fa metà del lavoro, perché è la prima cosa che
## dice «questo pavimento è un percorso, non una stanza».
static func passatoia() -> Node3D:
	var n := Node3D.new()
	# COLORE, non bianco: su un pavimento chiaro una passatoia bianca è
	# invisibile, e una passatoia che non si vede non porta da nessuna
	# parte. Greige caldo, e i bordi in grafite ben visibili.
	var lana := CAT._mat(Color("d9cdb4"), Color("c2b498"), 3.0, 0.5)
	CAT._box(n, Vector3(0.66, 0.018, 1.0), lana, Vector3(0, 0.064, 0))
	for sx: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.028, 0.006, 1.0), _grafite(),
				Vector3(sx * 0.27, 0.074, 0))
	# le frange ai due capi, mai tutte uguali
	var rng := RandomNumberGenerator.new()
	rng.seed = 6_601
	for sz: float in [-1.0, 1.0]:
		for i in 13:
			var f := CAT._cyl(n, 0.0035, 0.0035, 0.05 + rng.randf_range(-0.012, 0.012),
					CAT._mat(Color("e6dcc6"), Color("cfc2a6"), 5.0, 0.4),
					Vector3(-0.30 + 0.05 * float(i), 0.062, sz * 0.523))
			f.rotation.x = PI * 0.5 + rng.randf_range(-0.12, 0.12)
	return n


## 15 · I SACCHETTI. Tre, appoggiati per terra: uno in piedi, uno
## appoggiato all'altro, uno rovesciato con la velina che esce. È il
## pezzo più piccolo del set ed è quello che racconta di più: qualcuno è
## stato qui, ha comprato, e ha posato la roba per un attimo.
static func sacchetti() -> Node3D:
	var n := Node3D.new()
	_sacchetto(n, Vector3(-0.13, 0.0, 0.04), 0.35, 1)
	var appoggiato := _sacchetto(n, Vector3(0.05, 0.0, -0.02), -0.5, 2)
	appoggiato.rotation.z = 0.13
	var caduto := _sacchetto(n, Vector3(0.22, 0.075, 0.16), 1.1, 3)
	caduto.rotation.z = PI * 0.5 - 0.14
	caduto.rotation.y = 1.1
	# la velina uscita e un capo che spunta
	var velina := CAT._mat(VELINA, Color("ece2d2"), 7.0, 0.25)
	for i in 3:
		var v := CAT._box(n, Vector3(0.09, 0.008, 0.07), velina,
				Vector3(0.31 + 0.03 * float(i), 0.012, 0.14 + 0.02 * float(i)))
		v.rotation.y = 0.4 * float(i)
		v.rotation.z = 0.1
	CAT._ball(n, 0.055, _stoffa(2), Vector3(0.33, 0.03, 0.13), Vector3(1.1, 0.35, 0.8))
	return n
