extends RefCounted
## Fabbriche di geometria di Chibi Crossing: mesh procedurali (tronchi, chiome,
## fiori, fili d'erba), materiali dipinti a mano, texture morbide ed emettitori
## di particelle alla deriva.
##
## Tutte funzioni `static`, senza stato e senza albero della scena: si usano come
## `WorldGeo.cone_mesh(...)` previo `const GEO := preload(...)`.
## Estratte da CozyWorld.gd per alleggerirlo.

const HANDPAINT := preload("res://shaders/handpaint.gdshader")
## Gli organi di un fiore (petalo, lamina, stelo, capolino): la casa
## unica delle leggi di forma. FioriGeo non carica nessuno, quindi non
## c'è nessun anello.
const FIO := preload("res://scenes/world/FioriGeo.gd")


static func paint_mat(a: Color, b: Color, grain := 4.0, amount := 0.45, wind := 0.0,
		world_noise := false, trans := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = HANDPAINT
	mat.set_shader_parameter("color_a", a)
	mat.set_shader_parameter("color_b", b)
	mat.set_shader_parameter("noise_scale", grain)
	mat.set_shader_parameter("noise_amount", amount)
	mat.set_shader_parameter("wind_strength", wind)
	mat.set_shader_parameter("use_world_noise", world_noise)
	if trans > 0.0:
		mat.set_shader_parameter("translucency", trans)
	return mat

# il filo d'erba vero: un nastro affusolato che si incurva in avanti,
# UV.y = altezza (lo shader ci appende gradienti, vento e spinte)
static func blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# livelli: [altezza, mezza larghezza, curva in avanti]
	var lv := [[0.0, 0.017, 0.0], [0.12, 0.013, 0.012],
			[0.22, 0.008, 0.038], [0.30, 0.0, 0.085]]
	for s in 3:
		var a: Array = lv[s]
		var b: Array = lv[s + 1]
		var auv := float(a[0]) / 0.30
		var buv := float(b[0]) / 0.30
		var al := Vector3(-a[1], a[0], a[2])
		var ar := Vector3(a[1], a[0], a[2])
		if float(b[1]) > 0.0:
			var bl := Vector3(-b[1], b[0], b[2])
			var br := Vector3(b[1], b[0], b[2])
			for v: Array in [[al, auv], [bl, buv], [ar, auv],
					[ar, auv], [bl, buv], [br, buv]]:
				st.set_uv(Vector2(0.0, v[1]))
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
		else:
			var tip := Vector3(0, b[0], b[2])
			for v: Array in [[al, auv], [tip, 1.0], [ar, auv]]:
				st.set_uv(Vector2(0.0, v[1]))
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
	return st.commit()

## ---------------------------------------------------------------------
## I FIORI DEL PRATO
##
## Ogni fiore è UNA superficie sola e i suoi organi si distinguono dal
## COLOR dei vertici ([FioriGeo]: r petalo · g cuore · b verde, `a` la
## fase personale del petalo). Tre superfici erano tre draw call per un
## oggetto grande otto centimetri.
##
## ⚠️ E LA PROPORZIONE VIENE PRIMA DEL POLIGONO. La margherita di prima
## aveva la corolla di **ø 0.229 su uno stelo di 0.20**: larga quanto
## alta, in un prato dove il filo d'erba fa 0.30. Era QUELLA — non gli
## otto meridiani della sfera — a farla leggere come una girandola di
## confetti. Adesso la testa fa ø 0.075 su 0.22 di altezza, e costa un
## terzo dei triangoli di prima (1464 → ~430) perché una sfera scalata
## spende quasi tutto in meridiani che nessuno vede.
## ---------------------------------------------------------------------

## Il materiale di un fiore: una superficie, tre organi, il vento del
## mondo. `chioma` è l'ampiezza con cui la folata lo piega — la STESSA
## folata che un istante prima ha piegato l'erba di là — e `testa_base`
## la quota sopra la quale la corolla arriva IN RITARDO sullo stelo, che
## è tutto il peso del fiore.
static func fiore_mat(pet_a: Color, pet_b: Color, cuore: Color, verde: Color,
		chioma := 0.05, span := 0.22, testa_base := 0.0,
		fremito := 0.0035, trans := 0.55) -> ShaderMaterial:
	var mat := paint_mat(pet_a, pet_b, 3.0, 0.42, 0.0, true, trans)
	mat.set_shader_parameter("usa_organi", true)
	mat.set_shader_parameter("organo_cuore", cuore)
	mat.set_shader_parameter("organo_verde", verde)
	# IL COLLETTO: le radici in ombra e le punte accese. È il trucco con
	# cui il filo d'erba si fonde col suolo, e senza di lui un fiore
	# sembra appoggiato sul prato invece che piantato dentro.
	mat.set_shader_parameter("colletto", 0.42)
	mat.set_shader_parameter("chioma", chioma)
	mat.set_shader_parameter("chioma_base", 0.0)
	mat.set_shader_parameter("chioma_span", span)
	if testa_base > 0.0:
		mat.set_shader_parameter("testa", 1.0)
		mat.set_shader_parameter("testa_base", testa_base)
	mat.set_shader_parameter("fremito", fremito)
	mat.set_shader_parameter("varia_tinta", 1.0)
	return mat


## Il gambo comune: UNO stelo su una curva vera (prima erano due cilindri
## accostati con 0.12 rad di piega, e a ottanta centimetri lo spigolo del
## gomito si vedeva) più le foglie basali, che sono lamine con la
## nervatura e la punta che ricade — non due lame esagonali.
##
## `attacco` è dove finisce lo stelo: è lì che ogni specie appoggia la
## sua corolla, e la restituisce perché nessuno debba ricalcolarla.
static func stelo_fiore(st: SurfaceTool, h: float, leaf_s := 1.0,
		piega := 0.055, seme := 0) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	var giro := rng.randf() * TAU
	var dir := Vector3(cos(giro), 0.0, sin(giro))
	# la curva: dritto alla base, e si china verso la cima. Tre controlli
	# bastano, la Catmull-Rom fa il resto
	var cima := Vector3(0, h, 0) + dir * (h * piega)
	var punti: Array = [Vector3.ZERO, Vector3(0, h * 0.45, 0)
			+ dir * (h * piega * 0.16), cima]
	# ⚠️ IL RAGGIO, E IN FRAZIONE DELL'ALTEZZA. Prima lo stelo era 7.5 mm
	# — quindici millimetri di cannuccia sotto una testa che ne fa
	# settantacinque. Poi 3.4 mm, ma SCRITTI IN METRI: la stessa mina
	# delle farfalle, un piano più in là. Le piante che passano di qui
	# vanno da 10.5 cm (il non-ti-scordar-di-me) a 29 (il papavero):
	# col numero assoluto la piccola aveva un gambo grosso il 3.2% della
	# propria altezza e il papavero l'1.2%. Adesso è l'1.7% per tutte.
	FIO.stelo_su(st, Transform3D.IDENTITY, punti,
			[h * 0.017, h * 0.0130, h * 0.0105], 5, 5)
	# LA ROSETTA BASALE: tre foglie, non due. Due opposte fanno un'elica
	# — da qualunque parte la guardi ne vedi una di taglio, e sparisce.
	# Sono anche più larghe e più corte di prima: una lancia sottile a
	# ottanta centimetri è uno stecco.
	for i in 3:
		var a := giro + float(i) * TAU / 3.0 + rng.randf_range(-0.28, 0.28)
		var su := 0.34 + rng.randf_range(-0.10, 0.14)
		var base := Transform3D(
				Basis(Vector3.UP, -a) * Basis(Vector3.BACK, su),
				Vector3(cos(a) * 0.004, h * 0.045, sin(a) * 0.004))
		FIO.lamina_su(st, base,
				FIO.contorno_lancia(0.044 * leaf_s, 0.0155 * leaf_s, 4, 0.06),
				1.9, 0.16)
	return cima


## LA MARGHERITA: due corone di petali VERI attorno al capolino dorato.
## I petali della corona bassa sono reclinati e quelli della corona alta
## sfalsati fra loro — e larghi apposta perché si SOVRAPPONGANO alla
## base: tredici petali con gli spazi in mezzo fanno una stella marina.
static func daisy_mesh(petal_color: Color, center_color: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cima := stelo_fiore(st, 0.200, 1.0, 0.060, 11)
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	# ⚠️ LA LARGHEZZA È IL PETALO. Con `ventre 0.20 · apertura 0.62 ·
	# punta 0.45` il seno diventa un PLATEAU — la mezza larghezza andava
	# 0.79 → 1.00 → 0.75, cioè un rettangolo con la punta intaccata: dei
	# NASTRI bianchi, che è esattamente il difetto di partenza sotto
	# un'altra forma. Con 0.10 · 0.72 · 0.75 va 0.41 → 1.00 → 0.63:
	# base stretta, massimo oltre la metà, punta arrotondata. Obovata.
	var opz := {"incisione": 0.12, "arco": 0.26, "caduta": 0.20,
			"conca": 0.62, "torsione": 0.13, "ventre": 0.10,
			"apertura": 0.72, "punta": 0.75, "spessore": 0.00042}
	# DUE CORONE, e nessun petalo uguale a un altro. Una corona di petali
	# identici a passo regolare è un'ombrellina: quello che fa la
	# margherita è che ogni ligula ha la sua inclinazione, la sua
	# lunghezza e il suo scarto di passo.
	for corona in 2:
		var quanti := 10 if corona == 0 else 6
		var raggio := 0.0065 if corona == 0 else 0.0052
		var quota := 0.0018 if corona == 0 else 0.0038
		var incl := -0.13 if corona == 0 else -0.33
		var lung := 0.0300 if corona == 0 else 0.0258
		for i in quanti:
			var a := float(i) / float(quanti) * TAU \
					+ (0.0 if corona == 0 else 0.52) \
					+ rng.randf_range(-0.10, 0.10)
			var o2 := opz.duplicate()
			o2["caduta"] = 0.20 + rng.randf_range(-0.09, 0.09)
			o2["torsione"] = rng.randf_range(-0.20, 0.20)
			FIO.petalo_su(st, Transform3D(
					Basis(Vector3.UP, -a)
					* Basis(Vector3.BACK, incl + rng.randf_range(-0.13, 0.13)),
					cima + Vector3(cos(a) * raggio, quota, sin(a) * raggio)),
					lung * rng.randf_range(0.90, 1.09),
					0.0072 * rng.randf_range(0.90, 1.10), 3, 2, o2,
					rng.randf())
	# il capolino: un disco bombato di flosculi con la conca in mezzo,
	# non una sfera schiacciata
	FIO.cupola_su(st, Transform3D(Basis.IDENTITY, cima + Vector3(0, 0.0020, 0)),
			0.0136, 0.0072, 9, 3, 0.13, 0.26)
	st.index()
	st.set_material(fiore_mat(petal_color,
			petal_color.lerp(Color("c3cfe2"), 0.34),
			center_color, Color("6f9c58"), 0.055, 0.22, 0.160, 0.0035, 0.42))
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	return mesh


## IL TULIPANO: sei petali a coppa, chiusi in cima. Il segno della specie
## è la CONCA forte — un petalo di tulipano è un cucchiaio — e la punta
## NON incisa: si arrotonda, non si divide.
static func tulip_mesh(cup_color: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cima := stelo_fiore(st, 0.250, 1.45, 0.045, 23)
	var rng := RandomNumberGenerator.new()
	rng.seed = 233
	# ⚠️ IL VERSO DELLA CONCA. Un petalo in piedi ha il proprio «su»
	# rivolto DENTRO il fiore (lo porta lì `Basis(BACK, PI/2)`): quindi
	# `conca` POSITIVA arriccia i bordi verso l'asse — la coppa — e
	# negativa li apre. Con il segno sbagliato il tulipano usciva a
	# imbuto, aperto in cima e cavo dentro: un cappello di carta.
	# E per la stessa ragione `caduta` NEGATIVA fa cadere la punta
	# all'INTERNO, che è come si chiude un tulipano.
	# ⚠️ E LA LARGHEZZA È ARITMETICA, non gusto. A raggio 13 mm la
	# circonferenza è 83 mm: sei petali larghi 34 la riempiono due volte
	# e mezzo, e quello che esce non è una coppa — è un TUBO PIENO, un
	# sacchetto di carta giallo. Con 21 mm l'una si sovrappongono di una
	# volta e mezzo, che è quanto basta perché non si vedano fessure.
	# E la punta deve STRINGERSI: `ventre + apertura = 0.94` porta il
	# lembo a un quinto della sua larghezza sull'ultima riga, e senza
	# quello il tulipano ha il coperchio piatto.
	var opz := {"incisione": 0.0, "arco": -0.12, "caduta": -0.13,
			"conca": 0.55, "torsione": 0.04, "ventre": 0.12,
			"apertura": 0.80, "punta": 1.0, "spessore": 0.00055}
	for i in 6:
		var a := float(i) / 6.0 * TAU + rng.randf_range(-0.06, 0.06)
		# i tre esterni si aprono un filo più dei tre interni: è così che
		# si vede che sono due giri e non un bicchiere
		var incl := PI * 0.5 + (0.01 if i % 2 == 0 else 0.10)
		var o2 := opz.duplicate()
		o2["caduta"] = -0.13 + rng.randf_range(-0.022, 0.022)
		FIO.petalo_su(st, Transform3D(
				Basis(Vector3.UP, -a) * Basis(Vector3.BACK, incl),
				cima + Vector3(cos(a) * 0.0130, -0.003, sin(a) * 0.0130)),
				0.062 * rng.randf_range(0.95, 1.05), 0.0125, 4, 2, o2,
				float(i) / 6.0)
	# il cuore scuro in FONDO alla coppa: si intravede solo da sopra, e
	# sta basso apposta — sporgendo diventava una scheggia arancione fra
	# i petali
	FIO.cupola_su(st, Transform3D(Basis.IDENTITY, cima + Vector3(0, 0.001, 0)),
			0.0088, 0.0055, 7, 2, 0.0, 0.05)
	st.index()
	st.set_material(fiore_mat(cup_color, cup_color.lerp(Color("d98a3e"), 0.42),
			cup_color.darkened(0.45), Color("6f9c58"), 0.048, 0.28, 0.222,
			0.0030, 0.48))
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	return mesh


## LA LAVANDA: una spiga di campanelle vere in verticilli sfalsati, non
## otto palline infilate su un filo. Le campanelle hanno la bocca a
## quattro lobi: è quella, in controluce, a fare la spiga soffice.
static func lavender_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cima := stelo_fiore(st, 0.235, 0.70, 0.070, 37)
	var rng := RandomNumberGenerator.new()
	rng.seed = 37
	# ⚠️ LA SPIGA È FATTA DI DENSITÀ, non di sagoma. Sei campanelle su un
	# bastone si leggono come sei frecce infilzate; quello che fa una
	# lavanda è un cilindro SOFFICE — quindi verticilli fitti, che si
	# sovrappongono, su un terzo dell'altezza della pianta.
	var verticilli := 8
	for k in verticilli:
		var t := float(k) / float(verticilli - 1)
		var y := t * 0.100
		var r := 0.0115 * (1.0 - t * 0.46)
		var lung := 0.0165 * (1.0 - t * 0.30)
		for j in 3:
			var a := TAU * float(j) / 3.0 + float(k) * 0.82 \
					+ rng.randf_range(-0.12, 0.12)
			FIO.campanella_su(st, Transform3D(
					Basis(Vector3.UP, -a)
					* Basis(Vector3.BACK, 0.82 + rng.randf_range(-0.16, 0.16)),
					cima + Vector3(cos(a) * r, y, sin(a) * r)),
					lung, 0.0062 * (1.0 - t * 0.22),
					FIO.PETALO, rng.randf())
	# la punta: due bocci ancora chiusi, che è ciò che rende una spiga
	# una spiga e non un pennello tagliato di netto
	for k in 2:
		FIO.campanella_su(st, Transform3D(
				Basis(Vector3.UP, float(k) * 2.1) * Basis(Vector3.BACK, 0.34),
				cima + Vector3(0, 0.104 + float(k) * 0.009, 0)),
				0.0105, 0.0040, FIO.PETALO, 0.7 + float(k) * 0.15)
	st.index()
	st.set_material(fiore_mat(Color("a98fd8"), Color("8f6fc4"),
			Color("6f57a4"), Color("7d9a66"), 0.042, 0.32, 0.226))
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	return mesh


## IL TRIFOGLIO: il TAPPETO. Alto nove centimetri, cioè sotto la linea
## dell'erba (che ne fa trenta), e non compete con nessuno — serve a
## rompere il verde uniforme del prato là dove i fiori grandi sarebbero
## troppi. Tre foglioline e un capolino di flosculi, settanta triangoli.
##
## ⚠️ È la specie che risponde alla domanda vera: a otto metri — che è
## l'inquadratura normale del gioco — di un fiore alto ventidue
## centimetri si vedono trenta pixel e di un petalo otto. Lì non conta
## la corolla, contano la CLASSE DI SAGOMA e la massa. Quattro specie
## tutte alte fra 0.20 e 0.36 sono un plotone; il tappeto è l'altra
## classe.
static func clover_mesh(fiore: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cima := Vector3(0, 0.070, 0)
	FIO.stelo_su(st, Transform3D.IDENTITY,
			[Vector3.ZERO, Vector3(0.002, 0.034, -0.003), cima],
			[0.0022, 0.0018, 0.0015], 3, 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 131
	# le tre foglioline: basse, aperte a stella, con la punta che ricade
	for i in 3:
		var a := float(i) * TAU / 3.0 + 0.4
		FIO.lamina_su(st, Transform3D(
				Basis(Vector3.UP, -a) * Basis(Vector3.BACK, 0.30),
				Vector3(cos(a) * 0.003, 0.018, sin(a) * 0.003)),
				FIO.contorno_lancia(0.021, 0.0092, 3, 0.10), 2.2, 0.20)
	# ⚠️ IL CAPOLINO È UNA PALLA DI FLOSCULI, e con una cupola liscia
	# quello che esce è un FUNGO: la `grana`, che modula l'ALTEZZA, su un
	# disco alto nove millimetri non si vede. Sono i LOBI — che modulano
	# il RAGGIO — a fare i fiorellini, ed è la stessa leva con cui il
	# non-ti-scordar-di-me smette di essere un pentagono.
	# ⚠️ DUE COSE, e la seconda è quella che conta.
	# (a) i LOBI vanno campionati: con nove segmenti e sette lobi il
	#     giro non li vede — è aliasing puro, e la testa resta liscia.
	#     Ci vogliono almeno due segmenti per lobo, e qui ce ne sono tre.
	# (b) UN FUNGO È UNA CALOTTA A FONDO PIATTO, e un trifoglio è una
	#     PALLA. Era la SAGOMA a leggere fungo, non la superficie: si
	#     chiude sotto con una seconda cupola ad `alt` NEGATIVA (che
	#     specchia il profilo e gira le normali da sola), e la silhouette
	#     diventa tonda.
	var testa := Transform3D(Basis.IDENTITY, cima + Vector3(0, 0.0016, 0))
	FIO.cupola_su(st, testa, 0.0104, 0.0130, 12, 2, 0.10, -0.06,
			FIO.PETALO, 6, 0.22, 1.0)
	FIO.cupola_su(st, testa, 0.0104, -0.0082, 12, 1, 0.10, -0.06,
			FIO.PETALO, 6, 0.22, 1.0)
	st.index()
	st.set_material(fiore_mat(fiore, fiore.lerp(Color("c8ccd6"), 0.30),
			fiore.darkened(0.16), Color("6b9a54"), 0.020, 0.08, 0.0,
			0.0018, 0.36))
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	return mesh


## IL PAPAVERO: l'ALTO, e la sua testa sta FUORI ASSE di cinque
## centimetri — è la rottura di sagoma che a otto metri si legge quando
## la forma della corolla non esiste più. Quattro petali larghi, cupolati
## e appena sfalsati, sul gambo che si china sotto il loro peso.
static func poppy_mesh(petalo: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# `piega` alta: il gambo di un papavero si china davvero
	var cima := stelo_fiore(st, 0.290, 0.85, 0.185, 71)
	var rng := RandomNumberGenerator.new()
	rng.seed = 717
	# ⚠️ UN PAPAVERO È UNA COPPA, e la coppa la fa `caduta` NEGATIVA: la
	# punta del petalo finisce PIÙ IN ALTO dell'attacco. Con la caduta
	# positiva e l'inclinazione a −0.62 rad i quattro petali si aprivano
	# piatti come le ali di una farfalla rossa.
	# e un petalo di papavero è più LARGO che lungo: con la mezza
	# larghezza a metà della lunghezza restavano quattro spicchi
	# appuntiti con gli spazi in mezzo, cioè una stella marina rossa
	var opz := {"incisione": 0.0, "arco": 0.10, "caduta": -0.34,
			"conca": 0.72, "torsione": 0.14, "ventre": 0.14,
			"apertura": 0.72, "punta": 0.42, "spessore": 0.00060}
	for i in 4:
		var a := float(i) / 4.0 * TAU + rng.randf_range(-0.14, 0.14)
		var o2 := opz.duplicate()
		o2["caduta"] = -0.34 + rng.randf_range(-0.08, 0.08)
		o2["torsione"] = rng.randf_range(-0.16, 0.16)
		FIO.petalo_su(st, Transform3D(
				Basis(Vector3.UP, -a)
				* Basis(Vector3.BACK, -0.16 + rng.randf_range(-0.13, 0.13)),
				cima + Vector3(cos(a) * 0.0075, -0.001, sin(a) * 0.0075)),
				0.041 * rng.randf_range(0.92, 1.08), 0.0335, 3, 3, o2,
				rng.randf())
	# la capsula scura: bassa e larga, in FONDO alla coppa. Alta e con la
	# conca rovesciata veniva un cono nero che spuntava sopra il fiore
	FIO.cupola_su(st, Transform3D(Basis.IDENTITY, cima + Vector3(0, 0.0005, 0)),
			0.0082, 0.0046, 8, 2, 0.10, 0.20, FIO.CUORE)
	st.index()
	st.set_material(fiore_mat(petalo, petalo.lerp(Color("8e2f3a"), 0.40),
			Color("3a3140"), Color("7ba05f"), 0.075, 0.30, 0.245,
			0.0048, 0.62))
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	return mesh


## IL NON-TI-SCORDAR-DI-ME: il piccolo AZZURRO. Cinque corolline in cima
## a una cima che si arriccia — l'azzurro è la tinta che manca al prato,
## e a due metri il suo occhio giallo è la cosa più graziosa che ci sia.
static func forgetmenot_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cima := stelo_fiore(st, 0.105, 0.72, 0.090, 53)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5353
	# ⚠️ E LE COROLLE HANNO UN FONDO. Alte 2.6 mm su un raggio di 9, e
	# infilate su una spirale VERTICALE, di tre quarti si vedevano di
	# taglio: cinque lenti azzurre impilate su uno stecco. Adesso la cima
	# si apre più in orizzontale (i cinque fiori stanno quasi in un
	# piano, come in una cima vera) e ogni corolla è una CIOTOLA — poco,
	# ma abbastanza perché la luce la trovi anche da sotto l'orizzonte.
	for i in 5:
		var t := float(i) / 4.0
		# la cima SCORPIOIDE: le corolle si arricciano verso l'esterno,
		# non stanno su un ombrello — è il segno della specie
		var a := t * 3.4 + 0.5
		var r := 0.0165 * (0.24 + 0.76 * t)
		var p := cima + Vector3(cos(a) * r, t * 0.0105, sin(a) * r)
		var base := Transform3D(
				Basis(Vector3.UP, -a) * Basis(Vector3.BACK, 0.46 * t + 0.10),
				p)
		# ⚠️ dieci segmenti e DUE anelli: con tre, cinque corolle
		# sfondavano il tetto di triangoli dichiarato — e un tetto che si
		# alza quando morde non è un tetto. Due anelli bastano: i lobi
		# stanno sul giro, non sulla colonna.
		FIO.cupola_su(st, base, 0.0098 * (0.70 + 0.30 * t), 0.0044,
				10, 2, 0.0, 0.62, FIO.PETALO, 5, 0.28)
		FIO.cupola_su(st, Transform3D(base.basis,
				p + base.basis * Vector3(0, 0.0022, 0)),
				0.0028, 0.0014, 6, 1, 0.0, 0.0, FIO.CUORE)
	st.index()
	st.set_material(fiore_mat(Color("9ec4f0"), Color("6d95cc"),
			Color("f7d572"), Color("7ba46a"), 0.026, 0.11, 0.0,
			0.0022, 0.44))
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	return mesh


## Il gambo comune, per chi lo vuole ancora come mesh a sé (il Prologo e
## i vasi): resta l'API di prima, che ora passa dagli organi.
static func flower_base(mesh: ArrayMesh, h: float, leaf_s := 1.0) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	stelo_fiore(st, h, leaf_s, 0.055, int(h * 1000.0))
	st.index()
	st.set_material(fiore_mat(Color("7fae6a"), Color("5f9050"),
			Color("7fae6a"), Color("7fae6a"), 0.04, h))
	st.commit(mesh)


static func soft_circle(color: Color, edge := 0.6) -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, edge, 1.0])
	grad.colors = PackedColorArray([color, Color(color, color.a * 0.55), Color(color, 0.0)])
	tex.gradient = grad
	return tex

static func merge(parts: Array) -> ArrayMesh:
	# [[Mesh, Transform3D, Material], ...] -> ArrayMesh con una superficie
	# per materiale
	var groups := {}
	for p in parts:
		var mat: Material = p[2]
		if not groups.has(mat):
			groups[mat] = []
		(groups[mat] as Array).append(p)
	var mesh := ArrayMesh.new()
	for mat in groups:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in groups[mat]:
			st.append_from(p[0], 0, p[1])
		st.set_material(mat)
		st.commit(mesh)
	return mesh

static func cone_mesh(radius: float, height: float, segments := 10) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = segments
	return m

static func cyl_mesh(top: float, bottom: float, height: float, segments := 8) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	return m

static func sphere_mesh(radius: float, segments := 12) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = int(segments * 0.5)
	return m

# normali morbide di una griglia di anelli chiusi: tangente lungo
# l'anello × tangente lungo la colonna (differenze centrali; ai bordi
# one-sided). Le righe degenerate (poli, punte) ricadono sulla verticale.
static func grid_normals(pos: Array, segs: int) -> Array:
	var rows := pos.size()
	var out: Array = []
	for i in rows:
		var nrow: Array[Vector3] = []
		var below: Array = pos[maxi(i - 1, 0)]
		var above: Array = pos[mini(i + 1, rows - 1)]
		for j in segs:
			var t_lon: Vector3 = pos[i][(j + 1) % segs] - pos[i][(j - 1 + segs) % segs]
			var t_lat: Vector3 = above[j] - below[j]
			var n := t_lon.cross(t_lat)
			if n.length_squared() < 0.0000001:
				# riga degenere (polo in basso, polo/punta in alto)
				nrow.append(Vector3.DOWN if i == 0 else Vector3.UP)
				continue
			nrow.append(n.normalized())
		out.append(nrow)
	return out

# griglia + normali -> mesh (due triangoli per quad, facce esterne)
static func grid_commit(pos: Array, nrm: Array, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pos.size() - 1:
		for j in segs:
			var j2 := (j + 1) % segs
			for idx: Array in [[i, j], [i + 1, j], [i + 1, j2],
					[i, j], [i + 1, j2], [i, j2]]:
				st.set_normal(nrm[idx[0]][idx[1]])
				st.add_vertex(pos[idx[0]][idx[1]])
	return st.commit()

# nuvola soffice: sfera schiacciata con gonfiori pseudo-noise coerenti.
# Le normali vere dei gonfiori vengono ammorbidite verso quelle
# dell'ellissoide liscio (il trucco dello stylized foliage): i lobi si
# leggono, ma l'ombra resta rotonda come un cuscino — mai accartocciata.
static func puff_mesh(r: float, seed_v: int, squash := 0.82, lump := 0.09,
		segs := 12, rings := 7, detail := 0.5) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var v1 := Vector3(rng.randf_range(1.6, 3.0), rng.randf_range(1.6, 3.0),
			rng.randf_range(1.6, 3.0))
	var v2 := Vector3(rng.randf_range(2.2, 4.2), rng.randf_range(2.2, 4.2),
			rng.randf_range(2.2, 4.2))
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU

	var pos: Array = []
	var soft: Array = []  # la normale dell'ellissoide liscio, per il blend
	for i in rings + 1:
		var lat := float(i) / float(rings) * PI - PI * 0.5  # -90° (sotto) -> +90°
		var prow: Array[Vector3] = []
		var srow: Array[Vector3] = []
		for j in segs:
			var lon := float(j) / float(segs) * TAU
			var d := Vector3(cos(lat) * cos(lon), sin(lat), -cos(lat) * sin(lon))
			var k := 1.0 + lump * sin(d.dot(v1) * 2.2 + ph1) \
					* cos(d.dot(v2) * 1.7 + ph2)
			prow.append(Vector3(d.x, d.y * squash, d.z) * r * k)
			# normale esatta dell'ellissoide (1, squash, 1): scala inversa
			srow.append(Vector3(d.x, d.y / squash, d.z).normalized())
		pos.append(prow)
		soft.append(srow)

	var nrm := grid_normals(pos, segs)
	for i in nrm.size():
		for j in segs:
			nrm[i][j] = (soft[i][j].lerp(nrm[i][j], detail)).normalized()
	return grid_commit(pos, nrm, segs)

# tronco vero: svasato alla base, affusolato in cima, corteccia
# irregolare e una lieve inclinazione — con le normali che seguono
# davvero gobbe e svasatura (la luce radente rivela la corteccia)
## LA SVASATURA DELLE RADICI, IN UN POSTO SOLO. Il moltiplicatore del
## raggio alla quota `t` (0 = terra, 1 = cima).
## ⚠️ Non e' un dettaglio da ricopiare: questa curva vive in TRE posti — qui,
## e le due ricostruzioni del tronco intagliato in `Woodcutting` — e finche'
## era scritta a mano in tutti e tre bastava ritoccarla di qua perche' il
## tronco tagliato nascesse con un profilo diverso da quello intero. C'e' un
## test che lo prende (`test_woodcutting`, l'ordine dei vertici), e l'ha
## preso davvero il giorno in cui questa curva e' stata addolcita.
##
## Si allarga di poco piu' della meta' e si consuma in mezzo metro, non in
## sette centimetri. Con 1.1 ed esponente 7 il primo anello era inclinato di
## 47,3 gradi VERSO IL CIELO (misurato sulle normali vere della mesh:
## n.y = +0.735, contro +0.047 del fusto): prendeva il sole — e la neve,
## perche' `v_up` nasce da questa normale — come un tetto, mentre il fusto
## sopra e' quasi radente. Quaranta gradi di salto in pochi centimetri, cioe'
## la linea esatta su cui scattava il gradino del toon, e da cui nasceva la
## gonna vermiglia al piede di ogni albero del gioco.
## 0.55 / 3.5 e' scelto su una tabella di pendenze MISURATE (1.1/7.0 = 47.4
## gradi · 0.8/5.0 = 33.0 · 0.55/3.5 = 20.9 · 0.45/3.0 = 16.8): il piede
## resta largo 2.56 volte la cima — la radice si vede ancora, non e' un palo
## — ma non guarda piu' in su. Sotto 0.45 la svasatura sparisce come lettura.
static func svaso_radici(t: float) -> float:
	return 1.0 + 0.55 * pow(1.0 - t, 3.5)


static func trunk_mesh(h: float, rb: float, rt: float, seed_v: int,
		bend := 0.07, segs := 10) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var ph := rng.randf() * TAU
	var kink := rng.randf_range(2.0, 3.4)
	var lean := Vector2(cos(ph), sin(ph)) * bend * h

	var ts := [0.0, 0.05, 0.14, 0.32, 0.58, 0.82, 1.0]
	var pos: Array = []
	for i in ts.size():
		var t: float = ts[i]
		var prow: Array[Vector3] = []
		for j in segs:
			var lon := float(j) / float(segs) * TAU
			# affusolamento + svasatura (la curva sta in `svaso_radici`)
			var r := lerpf(rb, rt, pow(t, 0.85)) * svaso_radici(t)
			# corteccia: gobbe radiali che ruotano piano salendo
			r *= 1.0 + 0.055 * sin(lon * 3.0 + t * kink + ph) \
					+ 0.03 * sin(lon * 7.0 - t * 2.0)
			var c := Vector3(lean.x * t * t, t * h, lean.y * t * t)
			prow.append(c + Vector3(cos(lon) * r, 0, -sin(lon) * r))
		pos.append(prow)
	return grid_commit(pos, grid_normals(pos, segs), segs)

# la gonna di un pino: cono con l'orlo smerlato che ricade. Le normali
# vere fanno prendere luce a ogni smerlo: la fronda si accende onda
# per onda invece di essere un cono uniforme.
static func skirt_mesh(r: float, h: float, seed_v: int, droop := 0.14,
		waves := 7, segs := 16) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var ph := rng.randf() * TAU
	# profili bottom→top: [frazione raggio, quota]
	var prof := [[1.0, 0.0], [0.72, h * 0.2], [0.38, h * 0.55], [0.0, h]]
	var pos: Array = []
	for i in prof.size():
		var prow: Array[Vector3] = []
		for j in segs:
			var lon := float(j) / float(segs) * TAU
			var rr: float = r * float(prof[i][0])
			var y: float = prof[i][1]
			if i == 0:
				# l'orlo: onde che scendono e rientrano appena
				var w := sin(lon * waves + ph)
				y -= droop * r * (0.55 + 0.45 * w)
				rr *= 1.0 + 0.05 * sin(lon * waves + ph + 1.3)
			prow.append(Vector3(cos(lon) * rr, y, -sin(lon) * rr))
		pos.append(prow)
	return grid_commit(pos, grid_normals(pos, segs), segs)

static func capsule_mesh(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	return m

static func strip_normals(pos: Array) -> Array:
	var rows := pos.size()
	var cols: int = (pos[0] as Array).size()
	var out: Array = []
	for i in rows:
		var nrow: Array[Vector3] = []
		for j in cols:
			var t_row: Vector3 = pos[mini(i + 1, rows - 1)][j] - pos[maxi(i - 1, 0)][j]
			var t_col: Vector3 = pos[i][mini(j + 1, cols - 1)] - pos[i][maxi(j - 1, 0)]
			var n := t_row.cross(t_col)
			nrow.append(n.normalized() if n.length_squared() > 0.000001 else Vector3.UP)
		out.append(nrow)
	return out

# il colore-bersaglio di una chioma, data la sua tinta di primavera e la
# stagione. Il valore (luminosità) si conserva quasi sempre: così i tre
# strati scuro/medio/chiaro della nuvola restano leggibili anche d'autunno
static func leaf_target(c: Color, klass: String, season: int) -> Color:
	match season:
		0:  # primavera: il colore di nascita
			return c
		1:  # estate: verdi più profondi e ricchi (il ciliegio rinverdisce)
			if klass == "cherry":
				return Color.from_hsv(0.28, 0.52, clampf(c.v * 0.9, 0.22, 0.95))
			if klass == "needle":
				return Color.from_hsv(c.h, minf(c.s * 1.06, 1.0), c.v * 0.96)
			return Color.from_hsv(c.h, minf(c.s * 1.12, 1.0), c.v * 0.93)
		2:  # autunno: oro, rame, cremisi — ma le conifere restano verdi
			if klass == "needle":
				return Color.from_hsv(fposmod(c.h - 0.01, 1.0), c.s * 0.95, c.v * 0.97)
			if klass == "cherry":
				# ⚠️ LA TINTA E' UN CERCHIO, E QUI SI FACEVA IL GIRO LUNGO.
				# L'intento e' scritto due righe sopra — «oro, rame,
				# cremisi» — cioe' cremisi (0.98) per gli strati scuri e
				# oro (0.07) per quelli chiari: sono NOVE CENTESIMI di
				# ruota passando per lo zero. Interpolando da 0.98 a 0.07
				# in linea retta se ne percorrono NOVANTUNO, dalla parte
				# sbagliata: si attraversa il blu (0.6), il ciano (0.5) e
				# il VERDE (0.3). MISURATO sul ciliegio vero: lo strato
				# scuro (v = 0.749) usciva a tinta 0.298, cioe' `#6ec257`
				# — un ciliegio d'autunno con la gonna d'ombra VERDE
				# addosso, sotto due strati arancioni.
				# Il file lo sapeva gia': le conifere, qui sotto, girano
				# con `fposmod`. Questa riga se l'era dimenticato.
				return Color.from_hsv(fposmod(lerpf(-0.02, 0.07,
						clampf(c.v, 0.0, 1.0)), 1.0), 0.55,
						clampf(c.v * 0.95 + 0.05, 0.0, 1.0))
			return Color.from_hsv(lerpf(0.03, 0.10, clampf(c.v, 0.0, 1.0)), 0.72,
					clampf(c.v * 1.02 + 0.05, 0.0, 1.0))
		_:  # inverno: brina e dormienza (la neve globale imbianca il resto)
			if klass == "needle":
				return Color.from_hsv(fposmod(c.h + 0.01, 1.0), c.s * 0.9, c.v * 0.82)
			return Color.from_hsv(0.09, 0.14, clampf(c.v * 0.72 + 0.14, 0.0, 1.0))

# fabbrica di emettitori "che scendono dal cielo": neve o foglie
static func drift_emitter(tex: Texture2D, count: int, sz: float, box: Vector3,
		grav: Vector3, life: float, spin_slow: bool) -> GPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(sz, sz)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = Vector3(0.2, -1, 0.1)
	pm.spread = 14.0
	pm.initial_velocity_min = 0.15
	pm.initial_velocity_max = 0.55
	pm.gravity = grav
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.7 if spin_slow else 0.4
	pm.turbulence_noise_speed = Vector3(0.25, 0.15, 0.25)
	pm.scale_min = 0.6
	pm.scale_max = 1.25
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -40.0 if spin_slow else -140.0
	pm.angular_velocity_max = 40.0 if spin_slow else 140.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.88, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var fx := GPUParticles3D.new()
	fx.amount = count
	fx.lifetime = life
	fx.preprocess = life * 0.7
	fx.local_coords = false
	fx.emitting = false
	fx.process_material = pm
	fx.draw_pass_1 = quad
	fx.visibility_aabb = AABB(Vector3(-16, -12, -16), Vector3(32, 18, 32))
	return fx


## IL DISCO D'ACQUA: una griglia POLARE (anelli × spicchi) invece del
## cappello a ventaglio del CylinderMesh — che ha un solo vertice al
## centro e nessuna suddivisione radiale, quindi qualunque onda sui
## vertici gli faceva fare solo il cono. Qui i vertici ci sono davvero:
## le onde capillari hanno dove vivere.
##
## Gli anelli si INFITTISCONO verso la riva (dove l'occhio guarda di
## striscio e le increspature contano di più): il raggio va come
## `t^stretta` con **stretta < 1**, quindi i passi si accorciano verso
## il bordo. Con un esponente > 1 succederebbe l'esatto contrario.
##
## UV: x = raggio normalizzato (0 centro, 1 riva), y = angolo/TAU —
## così lo shader sa sempre quanto è vicino alla sponda. L'angolo NON
## è preso modulo: l'ultimo spicchio va da 63/64 a 1.0, che è lo stesso
## punto di 0.0 per cos/sin ma non fa tornare indietro la UV (sarebbe
## una cucitura visibile in ogni funzione periodica dell'angolo).
static func disco_acqua(raggio: float, anelli := 14, spicchi := 64,
		stretta := 0.75) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var punto := func(ia: int, isp: int) -> void:
		var fr := pow(float(ia) / float(anelli), stretta)
		var giro := float(isp) / float(spicchi)
		var ang := TAU * giro
		st.set_uv(Vector2(fr, giro))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(cos(ang) * fr * raggio, 0.0, sin(ang) * fr * raggio))
	for ia in anelli:
		for isp in spicchi:
			if ia == 0:
				# il cuore: un ventaglio di triangoli sul centro
				punto.call(0, 0)
				punto.call(1, isp)
				punto.call(1, isp + 1)
			else:
				punto.call(ia, isp)
				punto.call(ia + 1, isp)
				punto.call(ia + 1, isp + 1)
				punto.call(ia, isp)
				punto.call(ia + 1, isp + 1)
				punto.call(ia, isp + 1)
	return st.commit()
