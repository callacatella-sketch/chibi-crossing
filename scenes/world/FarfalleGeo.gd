extends RefCounted
## LA SAGOMA DI UNA FARFALLA: una fonte sola, due montaggi.
##
## Nel villaggio vivono DUE popolazioni di farfalle che non si parlano:
##  · le CINQUE NOMINATE di CozyWorld — un `Node3D` ciascuna, con due
##    perni che battono le ali. Sono quelle che il retino cattura, che il
##    taccuino del Gufo nomina, e che si posano sul naso di Mochi durante
##    il Fiato Sospeso: l'unica inquadratura del gioco in cui un'ala si
##    vede a due centimetri;
##  · le NOVANTA del MultiMesh dell'ecosistema, dove il battito lo fa il
##    vertex shader e la mesh dev'essere UNA superficie piatta nel piano
##    XZ (`shaders/butterfly.gdshader` piega la geometria su `|VERTEX.x|`).
##
## Le due hanno bisogno di due MONTAGGI diversi, ma la SAGOMA dev'essere
## una sola: `assembla_nodo` e `assembla_piatta` chiamano gli stessi
## profili. Se divergessero, la farfalla che catturi nel retino non
## sarebbe quella che hai visto volare.
##
## ⚠️ QUELLO CHE C'ERA. Le novanta erano DUE QUADRILATERI — quattro
## triangoli in tutto, con `set_normal(Vector3.UP)` su ogni vertice: la
## luce ci cadeva sopra costante, in piena battuta l'ala si illuminava
## come una lastra orizzontale. Le cinque avevano un corpo a `CapsuleMesh`
## **senza `radial_segments`**, cioè il default 64×8 — millesessanta
## triangoli per un corpo di dodici millimetri, e per giunta con l'ombra
## accesa — contro quattro triangoli d'ala fatti di un cerchio sfumato
## tagliato ad `alpha_scissor 0.4` e UNSHADED: un pallino a bordo duro
## che il ciclo del giorno non tocca mai.
##
## LA LEGGE DELL'ALA è quella di casa, `Collection._ala_di_velo`, e il
## suo commento dice già perché: «con un quad squadrato la damigella
## sembrava un modellino di aliante». Qui è sdoppiata in ANTERIORE e
## POSTERIORE, perché è l'INTAGLIO fra le due a far leggere «farfalla»
## invece di «fogliolina»: una farfalla non ha due ali, ne ha quattro.
##
## L'ORIENTAMENTO NON È NEGOZIABILE: x = apertura (il battito piega su
## `|x|`), z = corda (+z è la testa), y ≈ 0. Una mesh bellissima
## modellata in un altro verso si ripiega al contrario o si appiattisce.
##
## IL COLOR DEI VERTICI è il contratto con lo shader:
##   a = 1 ala · 0 corpo     (il torace non si piega e non si tinge d'ala)
##   g = 0 anteriore · 1 posteriore   (la posteriore batte IN RITARDO)
##   r = quanto si è lontani dalla cerniera, 0..1 — è l'ORLO: le ali di
##       una farfalla hanno il margine scuro, ed è quello che a sei metri
##       la fa leggere come una farfalla invece che come un coriandolo

## Il torace: dentro questo raggio la geometria NON è ala, e il battito
## non la tocca. Lo legge anche il vertex shader delle novanta.
const RAGGIO_TORACE := 0.014


## I due profili, in frazioni dell'apertura e della corda. `s` va da 0
## (attacco al torace) a 1 (punta), e per ogni `s` si dà il bordo
## d'ATTACCO (avanti, +z) e la CORDA locale.
static func _profilo_anteriore(s: float) -> Vector2:
	# ⚠️ L'APICE STA FUORI **E AVANTI**, ed è tutta la sagoma. Se il
	# punto più esterno dell'ala anteriore cade a metà corda, l'ala si
	# chiude tonda e quello che esce è una FALENA — o, peggio, un paio di
	# baffi. In una farfalla il bordo d'attacco avanza fino a tre quarti
	# d'apertura, poi l'apice torna indietro di poco: il triangolo che ne
	# esce è il segno della specie.
	var davanti := 0.28 + 0.15 * sin(PI * s * 0.62) - 0.16 * pow(s, 6.0)
	# la corda: larga all'attacco, massima appena oltre la metà, e ZERO
	# in punta — l'apice è un punto, non un bordo
	var corda := 0.30 * (1.0 - s) \
			+ 0.62 * sqrt(s) * pow(maxf(1.0 - pow(s, 2.6), 0.0), 0.62)
	return Vector2(davanti, corda)


static func _profilo_posteriore(s: float) -> Vector2:
	# la posteriore è il LOBO: attacca dietro, si stende all'indietro e
	# fuori, e la sua punta guarda la coda. Fra il suo bordo d'attacco e
	# il bordo d'uscita dell'anteriore resta il seno che si legge come
	# INTAGLIO — ed è l'intaglio a far leggere «farfalla» invece di
	# «fogliolina».
	var davanti := -0.02 - 0.09 * s - 0.17 * pow(s, 2.2)
	var corda := 0.34 * (1.0 - s) \
			+ 0.52 * sqrt(s) * pow(maxf(1.0 - pow(s, 2.4), 0.0), 0.55)
	return Vector2(davanti, corda)


## Una lamella d'ala dentro un SurfaceTool aperto. Due fogli con normali
## opposte, come i petali: un'ala è una membrana con un dorso e un
## ventre, non un adesivo — ed è quello che fa vedere il controluce.
static func _ala_su(st: SurfaceTool, lato: float, dietro: bool,
		apertura: float, corda: float, passi: int, camber: float,
		radice: float, colore: Color) -> void:
	var g: Array = []
	for i in passi + 1:
		var s := float(i) / float(passi)
		var pr: Vector2 = _profilo_posteriore(s) if dietro else _profilo_anteriore(s)
		var x := lato * (radice + (apertura * 0.5 - radice) * s)
		# la punta cade un poco: un'ala tesa come un righello è di latta
		# l'anteriore sta MEZZO MILLIMETRO sopra la posteriore: alla
		# radice si sfiorano, e due lamelle complanari sfarfallano
		var y := -camber * corda * s * s + (0.0 if dietro else 0.0006)
		var zf := pr.x * corda
		var zb := zf - pr.y * corda
		g.append([Vector3(x, y, zf), Vector3(x, y * 1.35, zb)])
	# le normali: la lamella è quasi piana, la normale vera viene dalla
	# tangente lungo l'apertura per quella lungo la corda
	var nrm: Array = []
	for i in g.size():
		var prima: Array = g[maxi(i - 1, 0)]
		var dopo: Array = g[mini(i + 1, g.size() - 1)]
		var t_s: Vector3 = (dopo[0] as Vector3) - (prima[0] as Vector3)
		var t_c: Vector3 = (g[i][1] as Vector3) - (g[i][0] as Vector3)
		var n := t_c.cross(t_s)
		if lato < 0.0:
			n = -n
		if n.length_squared() < 1e-12:
			n = Vector3.UP
		nrm.append(n.normalized() * (1.0 if n.y >= 0.0 else -1.0))
	for faccia in 2:
		var segno := 1.0 if faccia == 0 else -1.0
		for i in passi:
			var quad: Array = [[i, 0], [i, 1], [i + 1, 0],
					[i + 1, 0], [i, 1], [i + 1, 1]]
			if (faccia == 1) != (lato < 0.0):
				quad.reverse()
			for idx: Array in quad:
				var c := colore
				c.r = float(idx[0]) / float(passi)
				st.set_color(c)
				st.set_normal((nrm[idx[0]] as Vector3) * segno)
				st.add_vertex(g[idx[0]][idx[1]])


## Il corpo: testa, torace, addome affusolato. Un tubo a sei lati, non
## una capsula col default di Godot — e sta TUTTO entro `RAGGIO_TORACE`,
## o il battito lo piegherebbe come un'ala.
static func _corpo_su(st: SurfaceTool, lung: float, colore: Color) -> void:
	# [z in frazioni di lung (da +testa a −coda), raggio in metri]
	var anelli: Array = [
			[0.50, 0.0018], [0.44, 0.0068], [0.34, 0.0092],
			[0.16, 0.0126], [-0.06, 0.0102], [-0.28, 0.0064],
			[-0.44, 0.0034], [-0.50, 0.0008]]
	var lati := 6
	var g: Array = []
	for a: Array in anelli:
		var z: float = float(a[0]) * lung
		var r: float = float(a[1])
		var riga: Array[Vector3] = []
		for j in lati:
			var t := TAU * float(j) / float(lati)
			# schiacciato: un addome di farfalla è più alto che largo
			riga.append(Vector3(cos(t) * r * 0.82, sin(t) * r, z))
		g.append(riga)
	for k in g.size() - 1:
		for j in lati:
			var j2 := (j + 1) % lati
			for idx: Array in [[k, j], [k, j2], [k + 1, j],
					[k + 1, j], [k, j2], [k + 1, j2]]:
				var p: Vector3 = g[idx[0]][idx[1]]
				var asse := Vector3(0, 0, p.z)
				st.set_color(colore)
				st.set_normal((p - asse).normalized())
				st.add_vertex(p)


## LE ANTENNE, con la clava in punta. Sono la cosa che si vede solo nel
## Fiato Sospeso, a due centimetri dal naso di Mochi — e sono anche la
## sola parte di una farfalla che nessuno disegnerebbe di sua iniziativa.
static func _antenne_su(st: SurfaceTool, lung: float, colore: Color) -> void:
	for lato: float in [-1.0, 1.0]:
		var punti: Array[Vector3] = [
				Vector3(lato * 0.0016, 0.0012, lung * 0.46),
				Vector3(lato * 0.0060, 0.0090, lung * 0.62),
				Vector3(lato * 0.0105, 0.0158, lung * 0.70),
				Vector3(lato * 0.0128, 0.0182, lung * 0.72)]
		var raggi: Array[float] = [0.0009, 0.0007, 0.0007, 0.0016]
		for k in punti.size() - 1:
			var a: Vector3 = punti[k]
			var b: Vector3 = punti[k + 1]
			var avanti := (b - a).normalized()
			var destra := avanti.cross(Vector3.UP)
			if destra.length_squared() < 1e-6:
				destra = avanti.cross(Vector3.RIGHT)
			destra = destra.normalized()
			var su := destra.cross(avanti).normalized()
			for j in 3:
				var t1 := TAU * float(j) / 3.0
				var t2 := TAU * float(j + 1) / 3.0
				var d1 := destra * cos(t1) + su * sin(t1)
				var d2 := destra * cos(t2) + su * sin(t2)
				for v: Array in [[a, d1, raggi[k]], [b, d1, raggi[k + 1]],
						[b, d2, raggi[k + 1]], [a, d1, raggi[k]],
						[b, d2, raggi[k + 1]], [a, d2, raggi[k]]]:
					st.set_color(colore)
					st.set_normal(v[1])
					st.add_vertex((v[0] as Vector3) + (v[1] as Vector3) * float(v[2]))


## LA FARFALLA PIATTA: tutto in UNA superficie nel piano XZ, per il
## MultiMesh dell'ecosistema. ⚠️ Una superficie sola non è un vezzo:
## `Ecosystem._butterfly_mat` cattura il materiale della SUPERFICIE 0, e
## con due superfici il ritinto stagionale si spegne in silenzio.
static func piatta(apertura: float, corda: float, passi := 8,
		camber := 0.14) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ala_ant := Color(0.0, 0.0, 0.0, 1.0)
	var ala_post := Color(0.0, 1.0, 0.0, 1.0)
	var corpo := Color(0.0, 0.0, 0.0, 0.0)
	for lato: float in [-1.0, 1.0]:
		_ala_su(st, lato, false, apertura, corda, passi, camber,
				RAGGIO_TORACE * 0.6, ala_ant)
		_ala_su(st, lato, true, apertura * 0.72, corda, passi - 2, camber * 0.7,
				RAGGIO_TORACE * 0.5, ala_post)
	_corpo_su(st, corda * 0.92, corpo)
	_antenne_su(st, corda * 0.92, corpo)
	st.index()
	return st.commit()


## LE ALI DI UN LATO, per i cinque rig nominati: nascono con l'attacco
## nell'ORIGINE, così il perno le fa ruotare dal punto giusto — ed è il
## contratto che `_farfalla_fidata` si aspetta per posarla sul naso di
## Mochi (`node.rotation.x = -0.95` presume ali ORIZZONTALI a riposo).
static func ali_lato(lato: float, apertura: float, corda: float,
		passi := 9, camber := 0.14) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ala_su(st, lato, false, apertura, corda, passi, camber,
			RAGGIO_TORACE * 0.6, Color(0.0, 0.0, 0.0, 1.0))
	_ala_su(st, lato, true, apertura * 0.72, corda, passi - 2, camber * 0.7,
			RAGGIO_TORACE * 0.5, Color(0.0, 1.0, 0.0, 1.0))
	st.index()
	return st.commit()


## IL CORPO dei cinque rig: testa, torace, addome e antenne.
static func corpo(lung: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Color(0.0, 0.0, 0.0, 0.0)
	_corpo_su(st, lung, c)
	_antenne_su(st, lung, c)
	st.index()
	return st.commit()


## LA BATTUTA, e ce n'è UNA SOLA in tutto il gioco.
##
## `sin()` puro ha salita e discesa identiche e nessuna pausa in cima:
## è il carillon che la REGOLA ZERO vieta — «un sin() puro si smaschera
## in due cicli». Una farfalla vera scende in fretta (è la battuta che
## porta), risale piano, e in cima si FERMA un istante. `pow` sul seno
## fa i fronti ripidi e il colmo piatto, senza un secondo orologio.
##
## La trascrive anche il vertex shader delle novanta: se qui si cambia,
## là si cambia — è la stessa legge in due lingue, come `nottambulo()`.
static func battito(theta: float) -> float:
	var s := sin(theta)
	return signf(s) * pow(absf(s), 0.62)
