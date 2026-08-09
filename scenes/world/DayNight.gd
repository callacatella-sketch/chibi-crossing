class_name DayNight
extends Node3D

## Il ciclo giorno/notte di Chibi Crossing.
##
## time: 0 = mezzanotte · 0.25 = alba · 0.5 = mezzogiorno · 0.75 = tramonto.
## Il sole attraversa il cielo da est a ovest (le ombre girano con lui),
## poi sorge la luna: il cielo scivola tra quattro palette, all'orizzonte
## brilla il bagliore dell'alba/tramonto, si accendono le stelle e le
## lucciole, e il mondo cambia abitanti (pollini e farfalle di giorno).
## I dischi di sole e luna nel cielo sono disegnati dal ProceduralSky.

signal day_changed(day: int)
## Emesso quando il calendario scivola in una nuova stagione (0 primavera,
## 1 estate, 2 autunno, 3 inverno). Il mondo intero lo ascolta per ridipingersi.
signal season_changed(season: int)

@export var cycle_seconds := 240.0
@export var time := 0.38

## Il calendario del villaggio: quante mattine sono sorte. Persistito nel
## JSON del villaggio insieme ai pezzi piazzati.
var day := 1

## 0..1, pilotato dal Weather: quanto il cielo è coperto dalla pioggia.
## Ammorbidisce luce e colori verso un grigio-lavanda, mai minaccioso.
var weather_gloom := 0.0

## L'ora a cui ci si sveglia dopo una notte di sonno: poco dopo l'alba,
## col sole basso e dorato.
const MORNING := 0.29

const DAY_TOP := Color(0.4, 0.62, 0.87)
const DAY_HORIZON := Color(0.9, 0.84, 0.72)
const NIGHT_TOP := Color(0.045, 0.065, 0.17)
const NIGHT_HORIZON := Color(0.1, 0.13, 0.27)
const DUSK_GLOW := Color(1.0, 0.55, 0.35)
const DAY_FOG := Color(0.93, 0.89, 0.79)
const NIGHT_FOG := Color(0.07, 0.1, 0.2)
const DAY_GROUND := Color(0.5, 0.58, 0.48)
const NIGHT_GROUND := Color(0.05, 0.06, 0.12)

## La LUCE D'OMBRA. Nei giochi cozy di riferimento l'ombra non è "meno
## verde": è di un altro colore. Qui l'ambiente è una luce dedicata —
## tutto ciò che il sole non tocca viene dipinto da questa: azzurro-
## lavanda di giorno, lilla alla golden hour, indaco profondo la notte.
const AMB_DAY := Color(0.60, 0.66, 0.86)
const AMB_DUSK := Color(0.76, 0.55, 0.72)
const AMB_NIGHT := Color(0.26, 0.32, 0.55)
const AMB_RAIN := Color(0.71, 0.72, 0.78)

## LE STAGIONI. Il calendario del villaggio è un mese di 28 giorni: quattro
## settimane, quattro stagioni. La stagione non è uno stato salvato a parte —
## si DERIVA dal giorno (che è già persistito), così un salvataggio riapre
## sempre nella stagione giusta. `season_cont()` dà la frazione continua
## 0..4; il colore del mondo sfuma da una stagione all'altra sugli ultimi
## giorni di ciascuna (season_blend), non con uno scatto a mezzanotte.
const YEAR_DAYS := 28
const SEASON_DAYS := 7
const SEASON_NAMES := ["primavera", "estate", "autunno", "inverno"]

# --- la regia del CIELO per stagione (bersagli verso cui il colore già
# calcolato di giorno/notte viene tirato: mai sostituito, solo intonato) ---
# saturazione globale del quadro: estate vivida, inverno smorto
const SEA_SAT := [1.18, 1.30, 1.24, 0.96]
# la temperatura del sole: neutro a primavera, oro d'autunno, azzurro d'inverno
const SEA_SUN := [Color(1.0, 0.99, 0.96), Color(1.0, 0.97, 0.90),
		Color(1.0, 0.92, 0.78), Color(0.90, 0.95, 1.06)]
const SEA_SUN_ENERGY := [1.0, 1.06, 0.98, 0.86]
# lo zenit e l'orizzonte del cielo di giorno
const SEA_SKYTOP := [Color(0.42, 0.63, 0.88), Color(0.31, 0.57, 0.90),
		Color(0.46, 0.62, 0.82), Color(0.63, 0.72, 0.83)]
const SEA_SKYHOR := [Color(0.92, 0.86, 0.74), Color(0.95, 0.89, 0.73),
		Color(0.97, 0.81, 0.60), Color(0.88, 0.90, 0.94)]
# la nebbia: ambrata e più densa d'autunno, bianco-fredda d'inverno
const SEA_FOG := [Color(0.93, 0.90, 0.82), Color(0.95, 0.92, 0.83),
		Color(0.94, 0.83, 0.66), Color(0.87, 0.91, 0.97)]
const SEA_FOG_ADD := [0.0, -0.0003, 0.0018, 0.0016]
# un soffio caldo/freddo sulla luce d'ombra (moltiplica l'ambiente)
const SEA_AMB := [Color(1.0, 1.0, 1.0), Color(1.02, 1.0, 0.97),
		Color(1.07, 1.0, 0.89), Color(0.92, 0.96, 1.06)]

# lo stato-stagione, ricalcolato a ogni nuovo giorno (non a ogni frame)
var _season := -99
var _snow := 0.0
# i fattori di grading fusi per OGGI, letti da _apply() ogni frame
var _g_sat := 1.2
var _g_sun := Color(1, 1, 1)
var _g_sun_energy := 1.0
var _g_skytop := Color(1, 1, 1)
var _g_skyhor := Color(1, 1, 1)
var _g_fog := Color(1, 1, 1)
var _g_fog_add := 0.0
var _g_amb := Color(1, 1, 1)

var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _env: Environment
var _sky: ShaderMaterial
var _cozy: Node3D
var _stars_mat: StandardMaterial3D
var _fireflies: GPUParticles3D
var _night := false

## Le direzioni delle 260 stelle della cupola (raggio 52): il cielo che
## le costellazioni di Mochi sanno leggere.
var star_dirs: PackedVector3Array = []


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("daynight")   # i riflessi negli occhi chiedono a noi la luce
	_sun = get_node("../Sun")
	var we: WorldEnvironment = get_node("../WorldEnvironment")
	_env = we.environment
	_sky = _env.sky.sky_material as ShaderMaterial
	_cozy = get_node_or_null("../CozyWorld")
	_build_moon()
	_build_stars()
	_build_fireflies()
	# la stagione di partenza: neve e grading pronti prima del primo frame,
	# così un salvataggio invernale riapre già innevato
	_update_season(false)
	_apply()
	# gli ascoltatori del mondo nascono differiti (CozyWorld costruisce su
	# più frame): a fine frame diamo comunque una spinta iniziale, e ognuno
	# si auto-inizializza quando la propria geometria esiste
	_broadcast_season.call_deferred(false)


## LA NOTTE SI DORME A OROLOGIO FERMO. Mentre lo schermo è nero (la tenda,
## il sogno, il «Buongiorno»: una dozzina di secondi reali) il mondo
## continuava a girare, e chi andava a letto negli ultimi istanti di notte
## pagava DUE giorni per una notte sola: `time` attraversava l'alba da solo
## (+1) e poi la sveglia `set_time(MORNING)` veniva letta come salto
## all'indietro (+1 di nuovo). Ci si addormentava al Giorno 2 e ci si
## svegliava al Giorno 4, con un'intera giornata di villaggio — orto,
## frutteto, posta, commissioni, promesse, i tick di Legami/Congedo/Nascite
## — consumata in un frame sul nero, e i ricordi che scrivevano due foto
## dallo stesso fotogramma. Finché l'orologio è sospeso il calendario non si
## muove: l'unico mattino è quello che dichiara la sveglia.
var _sospensioni := 0


## Ferma (`true`) o riprende (`false`) lo scorrere del tempo. Le chiamate si
## CONTANO: due sistemi che sospendono insieme non devono sbloccarsi a
## vicenda (il sogno vive DENTRO la dormita).
func sospendi_tempo(fermo: bool) -> void:
	_sospensioni = maxi(0, _sospensioni + (1 if fermo else -1))


## L'orologio del villaggio è fermo? (dormita, sogno…)
func tempo_sospeso() -> bool:
	return _sospensioni > 0


## Salta a un'ora precisa (0..1). Usato anche dalla verifica CLI.
func set_time(t: float) -> void:
	var nt := fposmod(t, 1.0)
	_check_new_day(time, nt)
	time = nt
	_apply()


# un nuovo mattino: attraversamento naturale dell'alba, oppure il salto
# all'indietro del sonno (la sveglia atterra nella finestra del mattino)
func _check_new_day(prev: float, t: float) -> void:
	var crossed := prev < MORNING and t >= MORNING and t - prev < 0.5
	var jumped := t < prev and t >= 0.25 and t <= 0.42
	if crossed or jumped:
		day += 1
		# la stagione può scivolare col nuovo giorno: aggiornala PRIMA di
		# annunciare il giorno, così chi ascolta day_changed legge già la
		# stagione giusta
		_update_season()
		day_changed.emit(day)
		var bs: Node = get_tree().get_first_node_in_group("build_system")
		if bs:
			bs.request_save()


func save_extra() -> Dictionary:
	return {"day": day}


func load_extra(data: Dictionary) -> void:
	day = maxi(1, int(data.get("day", day)))
	# il salvataggio non emette day_changed: la stagione va riallineata a
	# mano al giorno caricato, e il mondo ridipinto (differito: gli
	# ascoltatori potrebbero essere ancora in costruzione)
	_update_season(false)
	_broadcast_season.call_deferred(false)
	_apply()


# --- verifica CLI: salta a un giorno preciso e ridipingi la stagione ---
func debug_set_day(d: int) -> void:
	day = maxi(1, d)
	_update_season(false)
	_broadcast_season(false)
	day_changed.emit(day)
	_apply()


## Vero quando il mondo è in modalità notte (stelle, lucciole, finestre accese).
func is_night() -> bool:
	return _night


## La direzione VERSO la luce dominante del cielo, in coordinate mondo:
## il sole di giorno, la luna di notte. La chiedono i riflessi negli occhi
## (FaceController): una DirectionalLight illumina lungo -Z, quindi la
## sorgente sta dalla parte di +basis.z.
func luce_verso() -> Vector3:
	var luce := _moon if (_night and _moon != null) else _sun
	if luce == null:
		return Vector3(0.35, 0.85, -0.4).normalized()
	return luce.global_transform.basis.z.normalized()


# ---------------------------------------------------------------- stagioni

## La stagione come frazione continua 0..4 letta dal calendario:
## 0 primavera · 1 estate · 2 autunno · 3 inverno (e poi si richiude).
func season_cont() -> float:
	return float((day - 1) % YEAR_DAYS) / float(SEASON_DAYS)


## L'indice della stagione di oggi (0..3).
func get_season() -> int:
	return int(floor(season_cont())) % 4


## Il nome della stagione di oggi, per la lavagna e i toast.
func season_name() -> String:
	return SEASON_NAMES[get_season()]


## 0..1: quanto siamo avanti dentro la stagione corrente (0 = primo giorno).
func season_progress() -> float:
	var s := season_cont()
	return s - floor(s)


## Il primo giorno (assoluto) della PROSSIMA stagione — per il calendario.
func next_season_day() -> int:
	var into := (day - 1) % SEASON_DAYS
	return day + (SEASON_DAYS - into)


## 0..1: la neve accumulata. Cade sul finire dell'autunno, piena
## d'inverno, si scioglie negli ultimi giorni prima della primavera.
func snow_amount() -> float:
	var s := season_cont()
	var acc := smoothstep(2.8, 3.2, s)      # la prima nevicata, a fine autunno
	# il disgelo: completo entro l'ULTIMO giorno d'inverno (s arriva solo a
	# 27/7≈3.857 prima di richiudersi a primavera), così la neve svanisce
	# piano invece di sparire di colpo al cambio d'anno
	var melt := smoothstep(3.55, 3.87, s)
	return clampf(acc - melt, 0.0, 1.0)


# fonde quattro colori-ancora (uno per stagione) secondo il calendario:
# tiene la stagione piena nei primi giorni, poi sfuma nella successiva
func _blend_season_color(anchors: Array) -> Color:
	var s := season_cont()
	var a := int(floor(s)) % 4
	var t := smoothstep(0.6, 1.0, s - floor(s))
	return (anchors[a] as Color).lerp(anchors[(a + 1) % 4], t)


func _blend_season_float(anchors: Array) -> float:
	var s := season_cont()
	var a := int(floor(s)) % 4
	var t := smoothstep(0.6, 1.0, s - floor(s))
	return lerpf(anchors[a], anchors[(a + 1) % 4], t)


# ricalcola i fattori di grading di OGGI (una volta al giorno, non a frame)
func _grade_season() -> void:
	_g_sat = _blend_season_float(SEA_SAT)
	_g_sun = _blend_season_color(SEA_SUN)
	_g_sun_energy = _blend_season_float(SEA_SUN_ENERGY)
	_g_skytop = _blend_season_color(SEA_SKYTOP)
	_g_skyhor = _blend_season_color(SEA_SKYHOR)
	_g_fog = _blend_season_color(SEA_FOG)
	_g_fog_add = _blend_season_float(SEA_FOG_ADD)
	_g_amb = _blend_season_color(SEA_AMB)


## Ricalcola stagione, neve e grading dal giorno corrente. Se la stagione
## è cambiata, avvisa il mondo (`broadcast`) perché si ridipinga.
func _update_season(broadcast := true) -> void:
	_snow = snow_amount()
	RenderingServer.global_shader_parameter_set("snow_amount", _snow)
	_grade_season()
	var s := get_season()
	if s != _season:
		_season = s
		season_changed.emit(s)
		if broadcast:
			_broadcast_season(true)


# spinge la stagione a tutti gli ascoltatori (CozyWorld, GrandTree, Garden,
# Ecosystem…): ognuno ridipinge i propri materiali. `transition` fa sfumare
# il cambio con un tween, invece dello scatto secco al caricamento.
func _broadcast_season(transition: bool) -> void:
	for n in get_tree().get_nodes_in_group("season_listener"):
		if n.has_method("set_season"):
			n.set_season(_season, _snow, transition)


# --- IL MONDO IN LUTTO -------------------------------------------------
# Durante i giorni del lutto (Legami) il quadro si vela: un po' di
# saturazione in meno, la luce appena più fredda, la foschia un filo più
# alta. NIENTE di teatrale: il giocatore non deve notarlo, deve sentirlo.
# Il velo entra e esce PIANO (decine di secondi, mai a scatto): il lutto
# finisce all'alba, e la saturazione che torna col primo sole — lenta,
# mentre il mattino si apre — è la catarsi.
var _lutto_f := 0.0
var _legami: Node


func _lutto_vuole() -> float:
	if _legami == null or not is_instance_valid(_legami):
		_legami = get_tree().get_first_node_in_group("legami")
	if _legami and bool(_legami.call("lutto_attivo")):
		return 1.0
	return 0.0


## Il passo del velo: verso il lutto in ~45 secondi, verso la luce in ~75
## — la catarsi è più lenta dell'ombra, si apre col mattino. PURA.
static func passo_velo(attuale: float, vuole: float, delta: float) -> float:
	var k := 45.0 if vuole > attuale else 75.0
	return lerpf(attuale, vuole, 1.0 - exp(-delta / k * 3.0))


func _process(delta: float) -> void:
	# a orologio sospeso (dormita) il tempo NON scorre: il quadro si
	# continua comunque a dipingere, ma il calendario resta fermo
	if _sospensioni == 0:
		var nt := fposmod(time + delta / cycle_seconds, 1.0)
		_check_new_day(time, nt)
		time = nt
	_lutto_f = passo_velo(_lutto_f, _lutto_vuole(), delta)
	_apply()


func _build_moon() -> void:
	_moon = DirectionalLight3D.new()
	_moon.light_color = Color(0.66, 0.74, 0.92)
	_moon.light_energy = 0.0
	_moon.shadow_enabled = false
	_moon.shadow_blur = 2.5
	_moon.directional_shadow_max_distance = 40.0
	add_child(_moon)


# cupola di stelle: MultiMesh di sferette emissive, alpha animata di notte
func _build_stars() -> void:
	_stars_mat = StandardMaterial3D.new()
	_stars_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_stars_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_stars_mat.albedo_color = Color(1.0, 0.97, 0.9, 0.0)

	var star := SphereMesh.new()
	star.radius = 0.16
	star.height = 0.32
	star.radial_segments = 8
	star.rings = 4
	star.material = _stars_mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = star
	mm.instance_count = 260
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in mm.instance_count:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.12, 1.0), rng.randf_range(-1, 1)).normalized()
		# le direzioni restano leggibili: le costellazioni si disegnano qui
		star_dirs.append(dir)
		var star_basis := Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.5, 1.7))
		mm.set_instance_transform(i, Transform3D(star_basis, dir * 52.0))

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# lucciole: motes caldi che lampeggiano piano, solo di notte
func _build_fireflies() -> void:
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var cg := Gradient.new()
	cg.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	cg.colors = PackedColorArray([
		Color(0.92, 1.0, 0.66, 0.95), Color(0.92, 1.0, 0.66, 0.4), Color(0.92, 1.0, 0.66, 0.0)])
	tex.gradient = cg

	var quad := QuadMesh.new()
	quad.size = Vector2(0.075, 0.075)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(15.0, 1.0, 15.0)
	pm.direction = Vector3(0, 0, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.8
	pm.turbulence_noise_speed = Vector3(0.3, 0.2, 0.3)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	# lampeggio: l'alpha pulsa più volte nella vita della particella
	var blink := Gradient.new()
	blink.offsets = PackedFloat32Array([0.0, 0.12, 0.24, 0.4, 0.55, 0.7, 0.85, 1.0])
	blink.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.12),
		Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.15), Color(1, 1, 1, 1.0),
		Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.0)])
	var blink_tex := GradientTexture1D.new()
	blink_tex.gradient = blink
	pm.color_ramp = blink_tex

	# coprono prato e foresta: stessa quantità, area più ampia = più rade
	# nel prato, più fitte percepite nel bosco dove la vista è chiusa
	pm.emission_box_extents = Vector3(26.0, 1.2, 26.0)

	_fireflies = GPUParticles3D.new()
	_fireflies.amount = 46
	_fireflies.lifetime = 7.0
	_fireflies.preprocess = 4.0
	_fireflies.local_coords = false
	_fireflies.emitting = false
	_fireflies.process_material = pm
	_fireflies.draw_pass_1 = quad
	_fireflies.position = Vector3(0, 0.9, -14)
	_fireflies.visibility_aabb = AABB(Vector3(-28, -2, -28), Vector3(56, 8, 56))
	add_child(_fireflies)


func _apply() -> void:
	var a := (time - 0.25) * TAU
	var elev := sin(a)
	var day_f := smoothstep(-0.18, 0.22, elev)
	# campana del bagliore: massima quando il sole sfiora l'orizzonte
	var glow_bell := exp(-pow(elev * 3.6, 2.0))

	var g := weather_gloom

	# --- sole: elevazione + azimut che spazza da est a ovest.
	# Più forte e più CALDO di prima: il contrasto col blu dell'ombra
	# è quello che dà volume al giorno ---
	var day_prog := clampf((time - 0.25) / 0.5, 0.0, 1.0)
	_sun.rotation = Vector3(-(0.12 + 0.9 * maxf(elev, 0.0)), 1.5 - day_prog * 2.4, 0.0)
	# (all'orizzonte ARANCIO dorato, mai rosso: i marroni caldi del mondo
	# reggono l'arancio ma virano al rosso acceso con troppa poca G)
	_sun.light_energy = smoothstep(-0.04, 0.18, elev) * 1.55 * (1.0 - 0.55 * g) * _g_sun_energy
	_sun.light_color = Color(1.0, 0.70, 0.46).lerp(Color(1.0, 0.90, 0.72), clampf(elev * 2.2, 0.0, 1.0))
	# la stagione intona la temperatura del sole: oro d'autunno, cristallo
	# d'inverno — solo di giorno, per non spegnere l'arancio del tramonto
	_sun.light_color = _sun.light_color.lerp(_g_sun, 0.32 * day_f)
	# nel lutto il sole si raffredda appena (moltiplica: i rapporti restano)
	_sun.light_color = _sun.light_color.lerp(
			_sun.light_color * Color(0.93, 0.97, 1.04), _lutto_f)
	_sun.shadow_enabled = elev > 0.02

	# --- luna: sorge quando il sole tramonta ---
	var melev := -elev
	_moon.rotation = Vector3(-(0.2 + 0.7 * maxf(melev, 0.0)), -0.8, 0.0)
	_moon.light_energy = smoothstep(0.0, 0.25, melev) * 0.32 * (1.0 - 0.6 * g)
	_moon.shadow_enabled = melev > 0.12

	# --- cielo (con la pioggia scivola verso un grigio-lavanda gentile) ---
	var hor := NIGHT_HORIZON.lerp(DAY_HORIZON, day_f).lerp(DUSK_GLOW, glow_bell * 0.75)
	var top := NIGHT_TOP.lerp(DAY_TOP, day_f)
	# la stagione intona il cielo di GIORNO (di notte resta il suo blu di
	# sempre): azzurro alto d'estate, cielo pallido d'inverno
	top = top.lerp(_g_skytop, 0.55 * day_f)
	hor = hor.lerp(_g_skyhor, 0.5 * day_f)
	top = top.lerp(Color(0.52, 0.56, 0.66) * maxf(day_f, 0.12), g)
	hor = hor.lerp(Color(0.72, 0.73, 0.78) * maxf(day_f, 0.12), g)
	_sky.set_shader_parameter("top_color", top)
	_sky.set_shader_parameter("horizon_color", hor)
	_sky.set_shader_parameter("ground_color", NIGHT_GROUND.lerp(DAY_GROUND, day_f))
	# il cielo di ADESSO per gli specchi del mondo (le pozzanghere): due
	# globali, così ogni shader riflette lo stesso tramonto del giocatore
	RenderingServer.global_shader_parameter_set("cielo_alto", top)
	RenderingServer.global_shader_parameter_set("cielo_orizzonte", hor)

	# --- le nuvole: candide a mezzogiorno, rosa-pesca alla golden hour,
	# ardesia appena rischiarata dalla luna la notte; la pioggia le
	# gonfia (copertura su) e le ingrigisce ---
	var c_lit := Color(0.33, 0.36, 0.50).lerp(Color(1.0, 0.99, 0.95), day_f) \
			.lerp(Color(1.0, 0.80, 0.72), glow_bell * 0.85)
	var c_shade := Color(0.16, 0.19, 0.30).lerp(Color(0.74, 0.79, 0.90), day_f) \
			.lerp(Color(0.78, 0.58, 0.66), glow_bell * 0.7)
	c_lit = c_lit.lerp(Color(0.72, 0.73, 0.78), g * 0.75)
	c_shade = c_shade.lerp(Color(0.56, 0.58, 0.64), g * 0.75)
	_sky.set_shader_parameter("cloud_color", c_lit)
	_sky.set_shader_parameter("cloud_shade", c_shade)
	_sky.set_shader_parameter("cloud_cover", 0.48 + g * 0.38)

	# --- la luce d'ombra: è QUI che il giorno prende profondità.
	# Fredda quando il sole è caldo (complementari = volume); la pioggia
	# la ALZA e la ingrigisce: la luce piatta e senza ombre del nuvolo ---
	var amb := AMB_NIGHT.lerp(AMB_DAY, day_f).lerp(AMB_DUSK, glow_bell * 0.55)
	amb = amb.lerp(AMB_RAIN, g * 0.7)
	# un soffio di stagione sulla luce d'ombra: tiepida d'autunno, gelida
	# d'inverno (moltiplica, così i rapporti di colore restano quelli)
	amb *= _g_amb
	_env.ambient_light_color = amb
	_env.ambient_light_energy = (0.30 + 0.38 * day_f) * (1.0 + 0.4 * g)

	# --- nebbia e glow: alla golden hour la foschia si scalda davvero,
	# così il tramonto tinge il MONDO e non solo il cielo ---
	_env.fog_light_color = NIGHT_FOG.lerp(DAY_FOG, day_f) \
			.lerp(DUSK_GLOW, glow_bell * 0.38) \
			.lerp(_g_fog, 0.5 * day_f) \
			.lerp(Color(0.68, 0.7, 0.76) * maxf(day_f, 0.15), g * 0.8)
	# la foschia si addensa d'autunno (aria ambrata) e d'inverno (velo
	# bianco), si dirada d'estate — e nel lutto sale una nebbiolina bassa
	_env.fog_density = maxf(0.0005, 0.0012 + g * 0.0035 + _g_fog_add \
			+ 0.0024 * _lutto_f)
	_env.glow_intensity = 0.22 + (1.0 - day_f) * 0.25
	# il grado globale del quadro: estate vivida, inverno smorto e quieto.
	# Il lutto toglie il 13%: abbastanza da sentirlo, mai da notarlo
	_env.adjustment_saturation = _g_sat * (1.0 - 0.13 * _lutto_f)

	# --- stelle: si accendono quando il bagliore muore (e le nuvole coprono) ---
	_stars_mat.albedo_color.a = clampf((1.0 - day_f) - glow_bell * 0.5, 0.0, 1.0) * 0.9 * (1.0 - g)

	# --- il mondo cambia abitanti ---
	var night := day_f < 0.35
	if night != _night:
		_night = night
		_fireflies.emitting = night
		if _cozy and _cozy.has_method("set_night"):
			_cozy.set_night(night)
