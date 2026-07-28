extends RefCounted

## IL PASTO — il rituale del mangiare, scritto una volta sola.
##
## Mochi ha sempre avuto il suo (il pentolino, la ciotola tra le zampine,
## il soffio a occhi socchiusi, tre morsetti con le briciole): è uno dei
## momenti più belli del gioco. I vicini invece ringraziavano da fermi
## mentre il piatto regalato **svaniva a mezz'aria** — il dono non
## arrivava mai a destinazione.
##
## Qui c'è la coreografia condivisa. Non è una macchina a stati e non è un
## nodo: è una TABELLA DI TEMPI più le fabbriche di ciò che si vede
## (briciole, vapore, sbuffo del soffio). Chi recita — oggi Visitor.gd —
## chiede «a che punto sono?» e muove il proprio corpo di conseguenza.
##
## Perché così:
##   · il RITMO del pasto è la cosa che va indovinata (troppo veloce e
##     sembra un bug, troppo lento e annoia): tenerlo in un posto solo
##     vuol dire poterlo tarare senza rileggere l'animazione;
##   · è tutto PURO — nessun nodo, nessun tempo di gioco — quindi le
##     tappe, i morsi e il livello del cibo si provano headless
##     (tests/cases/test_pasto.gd) invece che a occhio, sperando di
##     beccare il fotogramma giusto.
##
## LE SETTE BATTUTE (nell'ordine in cui il giocatore le legge):
##   prende   le zampine salgono ad accogliere la ciotola, la testa scende
##   annusa   si sporge sul piatto, occhi socchiusi: il calore si SENTE
##   soffia   solo se il piatto è caldo — palpebre basse e sbuffi
##   morsi    tre morsetti: la ciotola sale, la testa scende a incontrarla
##   sospiro  la beatitudine, il cuoricino, il grazie in Chibiese
##   posa     la ciotola si inclina (vuota!) e svanisce, le zampine tornano
##
## Il pasto FREDDO salta il soffio: non si soffia su un tè freddo.

# nome della battuta -> quanto dura, in secondi. L'ordine è quello vero.
const TAPPE_CALDO := [
	["prende", 0.50],
	["annusa", 0.70],
	["soffia", 0.90],
	["morsi", 1.40],
	["sospiro", 0.90],
	["posa", 0.50],
]

## Quanti morsetti. Tre come Mochi: due sembrano pochi, quattro sembrano fame.
const MORSI := 3

## Quanto dura il singolo morso "dentro" la battuta dei morsi (il resto è
## la masticazione, che è la parte che dà peso al gesto).
const MORSO_SU := 0.16
const MORSO_GIU := 0.14


## Le tappe di questo pasto: senza il soffio se il piatto è freddo.
static func tappe(caldo: bool) -> Array:
	if caldo:
		return TAPPE_CALDO
	var out := []
	for t in TAPPE_CALDO:
		if str(t[0]) != "soffia":
			out.append(t)
	return out


## Quanto dura tutto il rituale.
static func durata(caldo: bool) -> float:
	var tot := 0.0
	for t in tappe(caldo):
		tot += float(t[1])
	return tot


## In che battuta siamo al tempo `t` (secondi dall'inizio). Fuori dal
## rituale: "" prima di cominciare, "fine" quando è finito.
static func fase(t: float, caldo: bool) -> String:
	if t < 0.0:
		return ""
	var acc := 0.0
	for tappa in tappe(caldo):
		acc += float(tappa[1])
		if t < acc:
			return str(tappa[0])
	return "fine"


## Quanto siamo avanti DENTRO la battuta corrente, da 0 a 1. È il numero
## con cui si interpolano le pose: 0 = appena entrati, 1 = sul punto di
## uscire.
static func avanzamento(t: float, caldo: bool) -> float:
	if t < 0.0:
		return 0.0
	var acc := 0.0
	for tappa in tappe(caldo):
		var d := float(tappa[1])
		if t < acc + d:
			return clampf((t - acc) / maxf(d, 0.0001), 0.0, 1.0)
		acc += d
	return 1.0


## Quando comincia una battuta (secondi dall'inizio). -1 se non c'è.
static func inizio_di(nome: String, caldo: bool) -> float:
	var acc := 0.0
	for tappa in tappe(caldo):
		if str(tappa[0]) == nome:
			return acc
		acc += float(tappa[1])
	return -1.0


## L'istante del morso i-esimo (0..MORSI-1): i morsi sono spaziati dentro
## la battuta "morsi", col primo che non parte all'istante zero (serve un
## respiro dopo il soffio) e l'ultimo che non finisce sul filo.
static func momento_morso(i: int, caldo: bool) -> float:
	var da := inizio_di("morsi", caldo)
	if da < 0.0:
		return -1.0
	var durata_morsi := 0.0
	for tappa in tappe(caldo):
		if str(tappa[0]) == "morsi":
			durata_morsi = float(tappa[1])
	var passo := durata_morsi / float(MORSI)
	return da + passo * (float(i) + 0.5)


## Quanto cibo resta nella ciotola al tempo `t`, da 1 (piena) a 0 (vuota).
## Scende A SCATTI, un terzo per morso: il cibo che cala di continuo
## sembra evaporare, quello che cala col morso sembra mangiato.
static func cibo(t: float, caldo: bool) -> float:
	var mangiati := 0
	for i in MORSI:
		if t >= momento_morso(i, caldo):
			mangiati += 1
	return clampf(1.0 - float(mangiati) / float(MORSI), 0.0, 1.0)


## Quanto è ALZATA la ciotola al tempo `t`, da 0 (in grembo, a riposo) a 1
## (contro il musetto). È una curva NORMALIZZATA: quanti centimetri siano
## davvero lo decide il corpo che la recita, perché ogni chibi ha la sua
## statura (il DNA cambia testa e gambe). Qui c'è solo la FORMA del gesto:
## sale ad annusare, ci resta per soffiare, e sbalza a ogni morso.
## Un solo posto per la curva, così la ciotola non "salta" mai tra una
## battuta e l'altra.
const ALZATA_ANNUSA := 0.45


static func alzata(t: float, caldo: bool) -> float:
	match fase(t, caldo):
		"prende":
			return 0.0
		"annusa":
			return lerpf(0.0, ALZATA_ANNUSA, avanzamento(t, caldo))
		"soffia":
			return ALZATA_ANNUSA
		"morsi":
			# la base è già alta; sopra ci va lo scatto del morso, che
			# porta la ciotola fino al musetto
			return ALZATA_ANNUSA + _scatto_morso(t, caldo) * (1.0 - ALZATA_ANNUSA)
		"sospiro":
			return lerpf(ALZATA_ANNUSA, 0.0, avanzamento(t, caldo))
		_:
			return 0.0


## 0..1: quanto è "dentro" un morso il tempo dato (1 = ciotola al musetto).
## Serve anche alla testa, che scende a incontrarla: sono due movimenti che
## si vengono incontro, ed è quello che dà il peso al gesto.
static func _scatto_morso(t: float, caldo: bool) -> float:
	for i in MORSI:
		var m := momento_morso(i, caldo)
		var da := m - MORSO_SU
		if t >= da and t < m:
			return clampf((t - da) / MORSO_SU, 0.0, 1.0)
		if t >= m and t < m + MORSO_GIU:
			return 1.0 - clampf((t - m) / MORSO_GIU, 0.0, 1.0)
	return 0.0


## Come sopra ma pubblica: la usa chi anima testa e corpo.
static func scatto_morso(t: float, caldo: bool) -> float:
	return _scatto_morso(t, caldo)


# ============================================================ le cose che si vedono
# Fabbriche pure di nodi (l'idioma di WorldGeo): entrano dei numeri, esce
# geometria già pronta. Nessuno stato, nessun riferimento alla scena.

## Le briciole che cadono dalla ciotola a ogni morso.
static func briciole(colore: Color) -> GPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.022, 0.022)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colore.darkened(0.15)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.035
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 35.0
	pm.initial_velocity_min = 0.12
	pm.initial_velocity_max = 0.35
	pm.gravity = Vector3(0, -2.4, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.0

	var fx := GPUParticles3D.new()
	fx.amount = 6
	fx.lifetime = 0.55
	fx.one_shot = true
	fx.explosiveness = 1.0
	fx.local_coords = false
	fx.process_material = pm
	fx.draw_pass_1 = quad
	fx.visibility_aabb = AABB(Vector3(-0.4, -0.6, -0.4), Vector3(0.8, 0.9, 0.8))
	return fx


## Il vapore che sale dal piatto caldo: dice «è appena stato cucinato»
## meglio di qualunque scritta.
static func vapore() -> GPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.2), Color(1, 1, 1, 0.0)])
	tex.gradient = grad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.03
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.12
	pm.initial_velocity_max = 0.22
	pm.gravity = Vector3(0, 0.05, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex

	var fx := GPUParticles3D.new()
	fx.amount = 10
	fx.lifetime = 1.4
	fx.local_coords = false
	fx.process_material = pm
	fx.draw_pass_1 = quad
	fx.visibility_aabb = AABB(Vector3(-0.4, -0.2, -0.4), Vector3(0.8, 1.2, 0.8))
	return fx


## Lo sbuffo del soffio: due nuvolette che partono dal musetto verso la
## ciotola e si perdono subito.
static func sbuffo() -> GPUParticles3D:
	var fx := vapore()
	fx.amount = 5
	fx.lifetime = 0.6
	fx.one_shot = true
	fx.explosiveness = 0.9
	var pm := fx.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0, -0.35, -1)
	pm.spread = 18.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3.ZERO
	return fx
