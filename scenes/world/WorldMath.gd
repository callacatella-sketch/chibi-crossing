extends RefCounted
## Matematica pura del mondo di Chibi Crossing: il corso del fiume, la parete
## di scogliera, il rumore dei ciuffi d'erba e le spline dei sentieri.
##
## Tutte funzioni `static`, senza stato e senza albero della scena: si usano
## come `WorldMath.river_x(z)` previo `const MATH := preload(...)`.
## Estratte da CozyWorld.gd per alleggerirlo — vedi tests/cases/test_cozy_math.gd.


## Quota z della cascata: lì il canyon si pinza sul fiume. Fonte di verità
## (CozyWorld ne tiene un alias per non toccare le sue decine di usi).
const FALL_Z := -4.0


## Il corso del fiume: x del centro alla quota z data. La stessa curva vive nel
## vertex di ground.gdshader (seni di argomenti piccoli: niente divergenze di
## precisione tra GDScript e shader).
static func river_x(z: float) -> float:
	return 18.6 + sin(z * 0.061) * 1.35 + sin(z * 0.023 + 2.0) * 0.85


## La x della parete di scogliera alla quota z. La scogliera NON costeggia il
## fiume: si tiene indietro e lascia una riva est larga e percorribile (il ponte
## porta LÌ, mica contro un muro) — e si stringe fino a baciare l'acqua solo
## alla cascata, dove il canyon si pinza.
static func cliff_x(z: float) -> float:
	return river_x(z) + 2.9 + 9.0 * smoothstep(1.6, 9.0, absf(z - FALL_Z))


## Interpolazione di Catmull-Rom fra p1 e p2 (p0 e p3 danno la tangente):
## è la curva morbida dei sentieri del bosco.
static func catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t \
			+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 \
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## Hash intero deterministico -> [0,1): identico su ogni CPU, niente
## trigonometria che diverge in precisione.
static func tuft_hash(ix: int, iz: int) -> float:
	var n := ix * 374761393 + iz * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xfffff) / 1048575.0


## Value noise bilineare (smoothstep sui pesi) costruito sull'hash.
static func tuft_vnoise(x: float, z: float) -> float:
	var ix := floori(x)
	var iz := floori(z)
	var fx := x - float(ix)
	var fz := z - float(iz)
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uz := fz * fz * (3.0 - 2.0 * fz)
	return lerpf(
			lerpf(tuft_hash(ix, iz), tuft_hash(ix + 1, iz), ux),
			lerpf(tuft_hash(ix, iz + 1), tuft_hash(ix + 1, iz + 1), ux), uz)


## Il campo dei ciuffi: due ottave di value noise. Decide dove l'erba
## infoltisce e dove il manto si scurisce alle radici.
static func tuft_field(x: float, z: float) -> float:
	return tuft_vnoise(x * 0.30, z * 0.30) * 0.65 \
			+ tuft_vnoise(x * 0.85 + 37.0, z * 0.85 + 11.0) * 0.35
