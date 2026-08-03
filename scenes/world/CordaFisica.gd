extends RefCounted

## LA FISICA DELLA CORDA — il motore, puro e senza albero.
##
## Una corda vera non è una curva disegnata: è una catena di punti con
## inerzia, tenuti insieme da una regola sola («ogni tratto resta lungo
## uguale») e tirati da tutto il resto — la gravità, il vento, una mano.
## Qui c'è esattamente questo, nel modo classico (Verlet + rilassamento
## dei vincoli), perché è il modo che NON esplode: niente velocità da
## integrare, niente molle da tarare — la posizione di ieri È l'inerzia.
##
## Tutto statico e puro: entra lo stato, esce lo stato. Chi la fa vivere
## nel mondo è CordeVive.gd; chi la prova a occhi chiusi è
## tests/cases/test_corde.gd. Le funzioni lavorano su Array di Vector3
## (NON PackedVector3Array: i Packed passano per copia, e una fisica che
## muove la copia lascia il mondo fermo senza nessun errore).
##
## Le corde vivono nello SPAZIO LOCALE del loro pezzo: un pezzo si piazza
## ruotato (R), e simulare in locale con le forze portate dentro dal
## gestore è l'unico modo per cui la stessa corda penda giusta in ogni
## orientamento.

## Quanto l'inerzia sopravvive da un passo all'altro. A 1.0 la corda
## oscilla per sempre (nessuna corda lo fa), sotto 0.95 sembra immersa
## nel miele. Il valore è tarato guardando il ritorno: 3-4 oscillazioni
## che muoiono in un paio di secondi, come una corda di canapa.
const SMORZAMENTO := 0.976
## I giri di rilassamento dei vincoli per passo (ogni giro è andata e
## ritorno). Sei tengono l'allungo sotto l'1,5% anche sulla corda appesa
## per intero — la canapa vera cede circa l'1%, un budino il 6. Il costo
## è nulla: dodici spazzate su una dozzina di punti.
const GIRI_VINCOLI := 6


## La posa di partenza: i punti lungo la corda ferma fra `a` e `b`, con
## `molle` di abbondanza (0.15 = la corda è lunga il 115% della distanza).
## La pancia è una parabola: non è la catenaria esatta, ma è solo il
## punto di partenza — a mettere la verità ci pensa la simulazione, che
## qui viene fatta ASSESTARE prima di consegnare (è la stessa posa che
## finisce nelle foto del catalogo: la corda fotografata È la corda
## simulata, ferma).
static func riposo(a: Vector3, b: Vector3, molle: float, n: int,
		assesta := 90) -> Array:
	var punti: Array = []
	var corda := a.distance_to(b)
	# la freccia di una parabola con quell'abbondanza di corda
	var freccia := corda * sqrt(maxf(molle, 0.0) * 0.375)
	for i in n:
		var t := float(i) / float(n - 1)
		var p := a.lerp(b, t)
		p.y -= freccia * 4.0 * t * (1.0 - t)
		punti.append(p)
	var seg := lunghezza(a, b, molle) / float(n - 1)
	var prev := punti.duplicate()
	var ancore := {0: a, n - 1: b}
	for _i in assesta:
		passo(punti, prev, 1.0 / 60.0, Vector3(0, -9.8, 0))
		vincola(punti, seg, ancore, 10)
	# ferma del tutto: la posa di riposo non deve portarsi dietro velocità
	for i in n:
		prev[i] = punti[i]
	return punti


## La lunghezza vera della corda (non della corda tesa).
static func lunghezza(a: Vector3, b: Vector3, molle: float) -> float:
	return a.distance_to(b) * (1.0 + maxf(molle, 0.0))


## Un passo di Verlet: ogni punto prosegue per inerzia e cade sotto la
## forza. `forza` è per unità di massa (un'accelerazione), uguale per
## tutti i punti; le differenze locali (turbolenza) le somma il gestore
## chiamando `soffia` prima del passo.
static func passo(punti: Array, prev: Array, dt: float, forza: Vector3) -> void:
	var dt2 := dt * dt
	for i in punti.size():
		var p: Vector3 = punti[i]
		var v: Vector3 = (p - prev[i]) * SMORZAMENTO
		prev[i] = p
		punti[i] = p + v + forza * dt2


## La turbolenza: una spinta in più, diversa punto per punto, che è ciò
## che distingue una corda al vento da una corda che trasla. `fase` è
## della corda (due corde vicine non ondeggiano in sincrono: orologi
## incommensurabili, come sempre), `t` è l'orologio del mondo.
static func soffia(punti: Array, prev: Array, dt: float, vento: Vector3,
		t: float, fase: float) -> void:
	if vento.is_zero_approx():
		return
	var dt2 := dt * dt
	for i in punti.size():
		var onda := 0.6 + 0.4 * sin(t * 2.3 + fase + float(i) * 0.7) \
				+ 0.25 * sin(t * 5.1 + fase * 1.7 + float(i) * 1.3)
		punti[i] += vento * (onda * dt2)


## I vincoli: ogni tratto torna lungo `seg`, e le ancore tornano al loro
## posto. Ogni giro fa DUE spazzate, andata e ritorno: una sola direzione
## propaga l'errore sempre dallo stesso capo e una corda appesa si
## allungava del 6% sotto il proprio peso — non è una corda, è un
## elastico. Con l'andata e ritorno il residuo scende sotto l'1%.
static func vincola(punti: Array, seg: float, ancore: Dictionary,
		giri := GIRI_VINCOLI) -> void:
	var n := punti.size()
	for _g in giri:
		for k in ancore:
			punti[int(k)] = ancore[k]
		for i in n - 1:
			_tendi(punti, i, seg)
		for k2 in ancore:
			punti[int(k2)] = ancore[k2]
		for i2 in range(n - 2, -1, -1):
			_tendi(punti, i2, seg)
	for k in ancore:
		punti[int(k)] = ancore[k]


static func _tendi(punti: Array, i: int, seg: float) -> void:
	var a: Vector3 = punti[i]
	var b: Vector3 = punti[i + 1]
	var d := a.distance_to(b)
	if d < 0.0001:
		return
	var correzione := (d - seg) / d * 0.5
	var delta := (b - a) * correzione
	punti[i] = a + delta
	punti[i + 1] = b - delta


## Il vincolo FRA DUE CORDE: i due punti restano a distanza `dist` (è il
## seggiolino dell'altalena, appeso a tutte e due). Torna la coppia
## corretta; chi chiama la riscrive nelle due corde.
static func lega(pa: Vector3, pb: Vector3, dist: float) -> Array:
	var d := pa.distance_to(pb)
	if d < 0.0001:
		return [pa, pb]
	var correzione := (d - dist) / d * 0.5
	var delta := (pb - pa) * correzione
	return [pa + delta, pb - delta]


## La mano (o il fianco di Mochi): i punti dentro la sfera vengono
## spinti fuori, in orizzontale — una corda si scosta, non si solleva.
static func spingi(punti: Array, centro: Vector3, raggio: float) -> void:
	var r2 := raggio * raggio
	for i in punti.size():
		var p: Vector3 = punti[i]
		var scarto := Vector3(p.x - centro.x, 0.0, p.z - centro.z)
		var d2 := scarto.length_squared() + (p.y - centro.y) * (p.y - centro.y)
		if d2 < r2 and scarto.length_squared() > 0.000001:
			punti[i] = p + scarto.normalized() * (raggio - sqrt(d2)) * 0.6


## Quanto si è mossa la corda nell'ultimo passo: serve al gestore per
## far DORMIRE il tubo (non si ricostruisce una mesh per un movimento
## che nessun occhio vede).
static func agitazione(punti: Array, prev: Array) -> float:
	var massimo := 0.0
	for i in punti.size():
		massimo = maxf(massimo, punti[i].distance_squared_to(prev[i]))
	return sqrt(massimo)


## Il punto della corda alla frazione t (0 = capo `a`, 1 = capo `b`): lo
## usano il gestore per gli appesi E i builder per posare le lampadine
## sulla posa di riposo — la stessa lettura, mai due formule.
static func campiona(punti: Array, t: float) -> Vector3:
	var u := clampf(t, 0.0, 1.0) * float(punti.size() - 1)
	var i := clampi(int(u), 0, punti.size() - 2)
	return (punti[i] as Vector3).lerp(punti[i + 1], u - float(i))


## La posa di riposo di una corda che pende da UN capo solo: dritta in
## giù, con tutta la sua lunghezza.
static func riposo_libera(a: Vector3, lung: float, n: int) -> Array:
	var punti: Array = []
	for i in n:
		punti.append(a + Vector3(0, -lung * float(i) / float(n - 1), 0))
	return punti


## Il tubo: la corda scritta dentro una ImmediateMesh, con i frame
## trasportati lungo la curva (il mestiere di ChibiBuilder.tube, in
## versione da rifare ogni frame: niente allocazioni oltre la mesh).
static func scrivi_tubo(mesh: ImmediateMesh, punti: Array, raggio: float,
		lati := 6) -> void:
	mesh.clear_surfaces()
	var n := punti.size()
	if n < 2:
		return
	# tangenti e un frame trasportato in parallelo
	var su := Vector3.UP
	var t0: Vector3 = (punti[1] - punti[0]).normalized()
	if absf(t0.dot(su)) > 0.9:
		su = Vector3.RIGHT
	var lato := t0.cross(su).normalized()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var anello_prec: Array = []
	for i in n:
		var tang: Vector3
		if i == 0:
			tang = (punti[1] - punti[0]).normalized()
		elif i == n - 1:
			tang = (punti[n - 1] - punti[n - 2]).normalized()
		else:
			tang = (punti[i + 1] - punti[i - 1]).normalized()
		lato = (lato - tang * lato.dot(tang)).normalized()
		var alto := tang.cross(lato).normalized()
		var anello: Array = []
		for j in lati:
			var ang := TAU * float(j) / float(lati)
			var norm := lato * cos(ang) + alto * sin(ang)
			anello.append([punti[i] + norm * raggio, norm])
		if i > 0:
			for j in lati:
				var j2 := (j + 1) % lati
				var a0: Array = anello_prec[j]
				var a1: Array = anello[j]
				var b0: Array = anello_prec[j2]
				var b1: Array = anello[j2]
				mesh.surface_set_normal(a0[1]); mesh.surface_add_vertex(a0[0])
				mesh.surface_set_normal(a1[1]); mesh.surface_add_vertex(a1[0])
				mesh.surface_set_normal(b1[1]); mesh.surface_add_vertex(b1[0])
				mesh.surface_set_normal(a0[1]); mesh.surface_add_vertex(a0[0])
				mesh.surface_set_normal(b1[1]); mesh.surface_add_vertex(b1[0])
				mesh.surface_set_normal(b0[1]); mesh.surface_add_vertex(b0[0])
		anello_prec = anello
	mesh.surface_end()
