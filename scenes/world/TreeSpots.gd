extends RefCounted

## Il cercatore di posto per un albero nuovo.
##
## Quando si abbatte un albero il terreno resta LIBERO — ci si può costruire
## sopra — e il bosco si rifà altrove: da qualche parte, qualche giorno dopo,
## spunta un alberello. Questa classe decide quel "da qualche parte".
##
## È logica PURA: nessun nodo, nessun SceneTree, nessun accesso al mondo. Le
## riceve tutte da fuori (chi la costruisce le pesca da CozyWorld, BuildSystem
## e dai residenti) e risponde a una domanda sola: «in questo punto ci può
## crescere un albero?». Così la parte più delicata del sistema — quella che
## se sbaglia pianta un pino dentro lo stagno o in mezzo al salotto — si
## verifica headless, senza aprire il gioco (vedi tests/cases/test_treespots.gd).
##
## I controlli sono in ordine di COSTO: prima quelli che bastano due
## sottrazioni (confini, scogliera, fiume), poi i cerchi, poi il sentiero e
## infine la distanza dagli altri alberi. Il primo che dice no ferma tutto.

# --- il terreno su cui si può ragionare (prato + bosco) ---
var bounds_min := Vector2(-48.0, -50.0)
var bounds_max := Vector2(48.0, 12.0)

## Cerchi di terreno occupato: Vector3(x, raggio, z).
## Stagno, radura, massi, Grande Albero, case, orti, abitanti…
var circles: Array = []

## Il sentiero del bosco: nessun albero in mezzo alla strada.
var path: PackedVector3Array = PackedVector3Array()
var path_clear := 2.4

## Quanto sta largo un albero nuovo dagli alberi che ci sono già: sotto
## questa soglia le chiome si compenetrano e il bosco diventa una macchia.
var trees: Array = []          # Vector2(x, z)
var tree_clear := 3.6

## L'acqua corrente e la parete di roccia, campionate lungo z (il fiume
## serpeggia e la scogliera pure: un solo numero non basterebbe).
var _z0 := -56.0
var _step := 2.0
var _river := PackedFloat32Array()
var _cliff := PackedFloat32Array()
var river_half := 5.4          # mezza larghezza vietata attorno al fiume
var cliff_margin := 3.0        # quanto si sta lontani dal piede della parete


## Campiona fiume e scogliera da chi li sa disegnare (CozyWorld), una volta
## sola: da qui in poi la classe è autonoma e testabile.
func sample_terrain(river_at: Callable, cliff_at: Callable,
		z_from := -56.0, z_to := 56.0, step := 2.0) -> void:
	_z0 = z_from
	_step = step
	_river = PackedFloat32Array()
	_cliff = PackedFloat32Array()
	var z := z_from
	while z <= z_to:
		_river.append(float(river_at.call(z)))
		_cliff.append(float(cliff_at.call(z)))
		z += step


## Per i test: fiume e scogliera dritti, senza bisogno del mondo vero.
func flat_terrain(river_x := 999.0, cliff_x := 999.0) -> void:
	_river = PackedFloat32Array([river_x, river_x])
	_cliff = PackedFloat32Array([cliff_x, cliff_x])
	_z0 = -56.0
	_step = 112.0


func _sampled(arr: PackedFloat32Array, z: float) -> float:
	if arr.is_empty():
		return 9999.0
	var f := (z - _z0) / _step
	var i := int(floorf(f))
	if i < 0:
		return arr[0]
	if i >= arr.size() - 1:
		return arr[arr.size() - 1]
	return lerpf(arr[i], arr[i + 1], f - float(i))


## Dov'è il fiume alla quota z.
func river_at(z: float) -> float:
	return _sampled(_river, z)


## Dov'è il piede della scogliera alla quota z (oltre, il terreno sale).
func cliff_at(z: float) -> float:
	return _sampled(_cliff, z)


## Aggiunge un tondo di terreno occupato.
func block(x: float, z: float, radius: float) -> void:
	circles.append(Vector3(x, maxf(0.1, radius), z))


## Il motivo per cui in (x, z) NON può crescere un albero — stringa vuota se
## invece va bene. Serve al gioco (che vuole solo sì/no) ma soprattutto ai
## test e a chi un domani dovrà capire perché il bosco non ricresce.
func rejection(x: float, z: float) -> String:
	# 1) i confini del mondo calpestabile
	if x < bounds_min.x or x > bounds_max.x or z < bounds_min.y or z > bounds_max.y:
		return "fuori dal mondo"
	# 2) la scogliera e ciò che sta oltre: colline, montagne, roccia. Un
	#    albero non nasce su una parete verticale
	if x > cliff_at(z) - cliff_margin:
		return "scogliera o rilievo"
	# 3) l'acqua corrente
	if absf(x - river_at(z)) < river_half:
		return "fiume"
	# 4) i tondi occupati: stagno, radura, massi, case, orti, abitanti
	for c in circles:
		var dx: float = x - c.x
		var dz: float = z - c.z
		if dx * dx + dz * dz < c.y * c.y:
			return "terreno occupato"
	# 5) il sentiero del bosco
	if not path.is_empty():
		var pc := path_clear * path_clear
		for p in path:
			var px: float = x - p.x
			var pz: float = z - p.z
			if px * px + pz * pz < pc:
				return "sentiero"
	# 6) gli alberi che ci sono già
	var tc := tree_clear * tree_clear
	for t in trees:
		var tx: float = x - t.x
		var tz: float = z - t.y
		if tx * tx + tz * tz < tc:
			return "troppo vicino a un altro albero"
	return ""


## True se in (x, z) può crescere un albero.
func is_free(x: float, z: float) -> bool:
	return rejection(x, z) == ""


## Cerca un posto buono, preferendo quelli vicini a [param near] (il bosco si
## rimargina dov'è stato tagliato, non dall'altra parte della valle).
## Ritorna Vector2.INF se dopo [param tries] tentativi non ha trovato nulla:
## chi chiama deve gestire il caso «il mondo è pieno» invece di piantare a
## caso — è così che un albero finirebbe dentro una parete.
func find_spot(rng: RandomNumberGenerator, near := Vector2.ZERO, tries := 90) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	for i in tries:
		# si guarda prima vicino al ceppo, poi via via più lontano: se il
		# bosco lì è fitto, la ricerca si allarga da sola
		var raggio: float = lerpf(4.0, 30.0, float(i) / float(maxi(1, tries - 1)))
		var a := rng.randf() * TAU
		var d := rng.randf_range(3.0, raggio)
		var x := near.x + cos(a) * d
		var z := near.y + sin(a) * d
		if not is_free(x, z):
			continue
		var dist := Vector2(x - near.x, z - near.y).length()
		if dist < best_d:
			best_d = dist
			best = Vector2(x, z)
			# abbastanza vicino: non serve cercare il perfetto
			if dist < 8.0:
				return best
	return best


## Quanti posti buoni ci sono in giro (diagnostica e test): campiona una
## griglia e conta. Serve a dire «il mondo è pieno» con un numero in mano.
func free_count(step := 4.0) -> int:
	var n := 0
	var x := bounds_min.x
	while x <= bounds_max.x:
		var z := bounds_min.y
		while z <= bounds_max.y:
			if is_free(x, z):
				n += 1
			z += step
		x += step
	return n
