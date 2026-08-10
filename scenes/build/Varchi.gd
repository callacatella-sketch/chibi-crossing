extends RefCounted
## I VARCHI: dove si passa, e dove no.
##
## La Fase 3 chiede al mondo una domanda sola, ed è la sua tesi: **ci
## arrivo?**. Questo file è l'oracolo che risponde, e non ha bisogno di un
## navmesh — la topologia giusta è **già nel salvataggio**, ed è migliore
## di quella che un navmesh ricostruirebbe: i muri di questo gioco non
## stanno dentro le celle, stanno **sui bordi**, con la chiave raddoppiata
## (`BuildSystem.passo_bordo`). Un bordo è letteralmente un arco del grafo,
## e mettere una staccionata è letteralmente tagliarlo. Non c'è niente da
## ricavare: c'è da leggere.
##
## ## Cosa blocca, e perché NON è una tabella
##
## La tentazione era un elenco: «Muro blocca, Porta no». Sarebbe la
## quattordicesima tabella parallela di questo progetto, e le tabelle
## parallele qui hanno già divorziato in silenzio una volta (la scala della
## ribellione). Invece la risposta **si deriva** dall'unico posto in cui
## quella verità vive davvero: le `cols` del catalogo, cioè le scatole di
## collisione che il pezzo pianta per terra.
##
## La regola è una frase: **si passa se resta una luce larga almeno mezzo
## metro, nella fascia in cui un chibi cammina.** Le conseguenze le decide
## la geometria, non io, e sono tutte giuste:
##
## - la Porta e il Portale hanno due stipiti a ±0.42 e in mezzo 0.68 m di
##   niente → **si passa** (ed è per questo che una casa con la porta non
##   diventa una prigione);
## - la Staccionata è una lastra da 0.95 alta 0.95 → **non si passa**, ed è
##   il pezzo con cui il giocatore chiude il recinto;
## - l'Insegna guardia è un palo da 0.14 su un lato → **si passa**, perché
##   un cartello appeso non è un muro;
## - il Casco appeso e la Tenda bar non hanno `cols` affatto → **si passa**,
##   senza che nessuno debba ricordarsi di scriverlo da qualche parte.
##
## Aggiungere domani un pezzo di bordo non richiede di aggiornare questo
## file: se ha una collisione che sbarra la strada, sbarra la strada.
##
## ## L'onestà su cosa questo NON fa
##
## I vicini si muovono con `position += dir * _speed` su un `Node3D`: non
## hanno collisioni, e non le avevano prima di questa fase. Quindi qui NON
## si sta rendendo il muro solido — si sta rendendo il muro **conosciuto**.
## Il vicino che sa di non poter arrivare al cespuglio non ci prova: cambia
## piano. E i viaggi che il piano decide seguono la ROTTA (`rotta` +
## `tira_filo`), quindi girano attorno al recinto invece di attraversarlo.
## Il vagabondaggio d'ambiente resta com'era.

## La fascia in cui cammina un chibi. Sotto `BANDA_BASSA` c'è la soglia di
## una vetrina, che si scavalca; sopra `BANDA_ALTA` c'è la tenda del bar,
## che passa sopra la testa.
const BANDA_BASSA := 0.20
const BANDA_ALTA := 0.80

## Mezzo metro: sotto questo, due stipiti non sono una porta, sono una
## fessura. (La Porta vera ne lascia 0.68.)
const VARCO_MIN := 0.50

## Il tetto del flood fill. Oltre, si smette di rispondere e si dichiara
## tutto raggiungibile: **il degrado va sempre verso «nessuno è in
## trappola»**, perché il guasto opposto — un vicino che si crede murato
## in mezzo al prato — è quello che si vede.
const MAX_CELLE := 32768
const MARGINE := 2


# ------------------------------------------------------------ il bordo

## La LUCE di un bordo: quanti metri di passaggio restano liberi, dentro la
## fascia di cammino. Pura: legge le `cols` del catalogo e basta.
##
## Il bordo è largo 1 m e le scatole sono in coordinate locali del pezzo
## (x lungo il bordo, y in alto, z attraverso). Il ribaltamento (`flip`) è
## uno specchio su x e non cambia la luce più larga: la funzione è perciò
## invariante al verso, come deve essere.
static func luce(cols: Array) -> float:
	var occupati: Array[Vector2] = []
	for c in cols:
		if c.size() < 2:
			continue
		var mis: Vector3 = c[0]
		var pos: Vector3 = c[1]
		# una scatola inclinata (terzo elemento: rotazione su X) alza il
		# proprio ingombro verticale: si tiene il caso peggiore
		var mezza_y := mis.y * 0.5
		if c.size() > 2 and absf(float(c[2])) > 1e-6:
			var rx := float(c[2])
			mezza_y = absf(cos(rx)) * mis.y * 0.5 + absf(sin(rx)) * mis.z * 0.5
		if pos.y + mezza_y <= BANDA_BASSA or pos.y - mezza_y >= BANDA_ALTA:
			continue  # tutta sotto la soglia, o tutta sopra la testa
		var a := clampf(pos.x - mis.x * 0.5, -0.5, 0.5)
		var b := clampf(pos.x + mis.x * 0.5, -0.5, 0.5)
		if b > a:
			occupati.append(Vector2(a, b))
	if occupati.is_empty():
		return 1.0
	occupati.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var piu_larga := 0.0
	var x := -0.5
	for iv in occupati:
		if iv.x > x:
			piu_larga = maxf(piu_larga, iv.x - x)
		x = maxf(x, iv.y)
	return maxf(piu_larga, 0.5 - x)


## Si passa?
static func e_varco(cols: Array) -> bool:
	return luce(cols) >= VARCO_MIN


## Il bordo (chiave raddoppiata) fra due celle adiacenti. Simmetrica:
## `bordo_fra(a, b) == bordo_fra(b, a)`.
static func bordo_fra(a: Vector2i, b: Vector2i) -> Vector2i:
	return a * 2 + (b - a)


static func passa(muri: Dictionary, a: Vector2i, b: Vector2i) -> bool:
	return not muri.has(bordo_fra(a, b))


const INTORNO: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]


# ------------------------------------------------------- le componenti

## Etichetta ogni cella con la sua **isola**. Zero è IL FUORI: il prato
## grande, che non ha muri e in cui tutto si tocca. Un'isola con etichetta
## ≥ 1 è un posto chiuso — un cortile, una stanza, un recinto.
##
## Si etichetta una volta sola per ogni cambio del villaggio, non una volta
## per domanda: il fill parte da un anello **fuori** dalla scatola dei muri,
## e tutto quello che l'anello raggiunge è il fuori. Quello che resta
## dentro e non è stato toccato è chiuso, e prende un'etichetta sua.
##
## Ritorna `{"celle": {Vector2i: int}, "isole": int, "troncato": bool}`, e
## in `celle` ci sono **soltanto i posti chiusi**: le celle assenti valgono
## zero, cioè il fuori è il default. Non è un'ottimizzazione furba, è la
## forma giusta — il prato è quasi tutto, e ricordarselo cella per cella
## vorrebbe dire tenere in memoria un villaggio intero per descrivere il
## niente. Un mondo senza recinti produce un dizionario vuoto.
static func componenti(muri: Dictionary) -> Dictionary:
	var vuoto := {"celle": {}, "isole": 0, "troncato": false}
	if muri.is_empty():
		return vuoto
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for k: Vector2i in muri:
		for cell in _celle_del_bordo(k):
			lo.x = mini(lo.x, cell.x)
			lo.y = mini(lo.y, cell.y)
			hi.x = maxi(hi.x, cell.x)
			hi.y = maxi(hi.y, cell.y)
	lo -= Vector2i(MARGINE, MARGINE)
	hi += Vector2i(MARGINE, MARGINE)
	var larghezza := hi.x - lo.x + 1
	var altezza := hi.y - lo.y + 1
	if larghezza * altezza > MAX_CELLE:
		# villaggio enorme: si rinuncia, e si rinuncia DICHIARANDO che tutto
		# è raggiungibile (vedi MAX_CELLE)
		vuoto["troncato"] = true
		return vuoto

	var visti := {}
	var celle := {}
	# 1) IL FUORI. Si semina da tutto il bordo della scatola: quell'anello è
	#    per costruzione oltre l'ultimo muro, quindi è prato aperto.
	var coda: Array[Vector2i] = []
	for x in range(lo.x, hi.x + 1):
		coda.append(Vector2i(x, lo.y))
		coda.append(Vector2i(x, hi.y))
	for y in range(lo.y + 1, hi.y):
		coda.append(Vector2i(lo.x, y))
		coda.append(Vector2i(hi.x, y))
	for c in coda:
		visti[c] = true
	_espandi(muri, visti, celle, coda, 0, lo, hi)

	# 2) LE ISOLE. Quel che il fuori non ha toccato è chiuso, e SOLO questo
	#    si ricorda.
	var isole := 0
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var c := Vector2i(x, y)
			if visti.has(c):
				continue
			isole += 1
			visti[c] = true
			celle[c] = isole
			var semi: Array[Vector2i] = [c]
			_espandi(muri, visti, celle, semi, isole, lo, hi)
	return {"celle": celle, "isole": isole, "troncato": false}


static func _espandi(muri: Dictionary, visti: Dictionary, celle: Dictionary,
		coda: Array[Vector2i], etichetta_: int, lo: Vector2i, hi: Vector2i) -> void:
	var i := 0
	while i < coda.size():
		var c: Vector2i = coda[i]
		i += 1
		for d in INTORNO:
			var n: Vector2i = c + d
			if n.x < lo.x or n.x > hi.x or n.y < lo.y or n.y > hi.y:
				continue
			if visti.has(n):
				continue
			if not passa(muri, c, n):
				continue
			visti[n] = true
			if etichetta_ != 0:
				celle[n] = etichetta_
			coda.append(n)


static func _celle_del_bordo(key: Vector2i) -> Array[Vector2i]:
	if posmod(key.y, 2) == 1:
		@warning_ignore("integer_division")
		var cy := (key.y - 1) / 2
		@warning_ignore("integer_division")
		return [Vector2i(key.x / 2, cy), Vector2i(key.x / 2, cy + 1)]
	@warning_ignore("integer_division")
	var cx := (key.x - 1) / 2
	@warning_ignore("integer_division")
	return [Vector2i(cx, key.y / 2), Vector2i(cx + 1, key.y / 2)]


## L'isola di una cella. Fuori dalla scatola dei muri è sempre il fuori.
static func isola(mappa: Dictionary, cell: Vector2i) -> int:
	return int((mappa.get("celle", {}) as Dictionary).get(cell, 0))


## LA DOMANDA DELLA FASE 3. Due punti si toccano se stanno sulla stessa
## isola. Niente ricerca, niente costo: un confronto fra due interi.
static func raggiungibile(mappa: Dictionary, da: Vector2i, a: Vector2i) -> bool:
	return isola(mappa, da) == isola(mappa, a)


# ------------------------------------------------------------ la rotta

## La strada vera fra due celle, che gira attorno ai muri. BFS a quattro
## vicini: un chibi non sguscia per lo spigolo fra due staccionate che si
## toccano, e infilarlo lì sarebbe l'unico modo di attraversare un recinto
## chiuso. Ritorna le celle da percorrere, estremi compresi; vuota se non
## c'è strada.
static func rotta(muri: Dictionary, da: Vector2i, a: Vector2i,
		tetto := MAX_CELLE) -> Array[Vector2i]:
	var vuota: Array[Vector2i] = []
	if da == a:
		return [da] as Array[Vector2i]
	var padre := {da: da}
	var coda: Array[Vector2i] = [da]
	var i := 0
	while i < coda.size() and coda.size() < tetto:
		var c: Vector2i = coda[i]
		i += 1
		for d in INTORNO:
			var n: Vector2i = c + d
			if padre.has(n) or not passa(muri, c, n):
				continue
			padre[n] = c
			if n == a:
				var giu: Array[Vector2i] = [a]
				var cur := a
				while cur != da:
					cur = padre[cur]
					giu.append(cur)
				giu.reverse()
				return giu
			coda.append(n)
	return vuota


## TIRA IL FILO. Una rotta a quattro vicini è una scaletta, e un vicino che
## cammina a scaletta sembra un carrello elevatore. Si tiene una tappa solo
## quando toglierla farebbe passare il filo dentro un muro.
static func tira_filo(muri: Dictionary, celle: Array[Vector2i]) -> Array[Vector2i]:
	if celle.size() <= 2:
		return celle.duplicate()
	var fuori: Array[Vector2i] = [celle[0]]
	var ancora := 0
	var i := 1
	while i < celle.size():
		if not _in_vista(muri, celle[ancora], celle[i]):
			fuori.append(celle[i - 1])
			ancora = i - 1
		i += 1
	fuori.append(celle[celle.size() - 1])
	return fuori


## Filo teso fra due celle: si campiona il segmento e si pretende che ogni
## passaggio di cella sia un passaggio LECITO.
##
## Il passaggio in DIAGONALE è il punto delicato, e vale la pena dire come
## si decide, perché la scelta ovvia sbaglia da tutt'e due i lati:
## rifiutarlo sempre lascia i vicini a camminare a scaletta come carrelli
## elevatori; accettarlo sempre li fa sgusciare per lo spigolo fra due
## staccionate — cioè attraverso il recinto chiuso. Quindi: si accetta la
## diagonale **solo se almeno uno dei due giri è aperto**. Alla fine di una
## staccionata (un giro solo sbarrato) si passa accanto al palo, com'è
## giusto; nell'angolo interno di una L (tutti e due sbarrati) no.
static func _in_vista(muri: Dictionary, da: Vector2i, a: Vector2i) -> bool:
	var p0 := Vector2(da)
	var p1 := Vector2(a)
	var passi := maxi(2, int(ceil(p0.distance_to(p1) / 0.05)))
	var cur := da
	for s in range(1, passi + 1):
		var p := p0.lerp(p1, float(s) / float(passi))
		var n := Vector2i(roundi(p.x), roundi(p.y))
		if n == cur:
			continue
		var d := n - cur
		if absi(d.x) + absi(d.y) == 1:
			if not passa(muri, cur, n):
				return false
		elif absi(d.x) == 1 and absi(d.y) == 1:
			var b := cur + Vector2i(d.x, 0)
			var c := cur + Vector2i(0, d.y)
			var giro_b := passa(muri, cur, b) and passa(muri, b, n)
			var giro_c := passa(muri, cur, c) and passa(muri, c, n)
			if not (giro_b or giro_c):
				return false
		else:
			return false  # un salto di più di una cella: campionamento rotto
		cur = n
	return true


## La lunghezza in metri di una rotta (le celle sono un metro).
static func lunghezza(celle: Array[Vector2i]) -> float:
	var d := 0.0
	for i in range(1, celle.size()):
		d += Vector2(celle[i] - celle[i - 1]).length()
	return d
