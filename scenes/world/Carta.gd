extends Node
## LA CARTA CHE RESPIRA — il regista del velo di vignetta.
##
## Lo shader `vignette.gdshader` esiste dal primo giorno e fa sembrare ogni
## fotogramma dipinto sulla carta crema delle lettere. Aveva quattro
## manopole — quanto chiude (`strength`), di che bruno (`tint`), quanta
## grana, quanto calore — e NESSUNO le scriveva mai: restava congelata sui
## valori di fabbrica. Una carta che non cambia mai è carta da stampante,
## non è la carta di un'illustrazione.
##
## Qui la carta impara le ore e gli stati d'animo del villaggio:
##
##   ORO DELLE SEI      all'alba e al tramonto la carta si SCALDA e chiude
##                      un filo di più: è l'ora in cui le illustrazioni si
##                      ingialliscono ai bordi.
##   NOTTE              il calore cala, il bruno si raffredda verso il blu
##                      e il bordo chiude: il buio stringe l'inquadratura.
##   PIOGGIA E NEBBIA   la carta si inumidisce: meno calore, più grana,
##                      il bordo chiude ancora un po'.
##   LUTTO              è il gradino che conta. Quando il villaggio ha
##                      appena perso qualcuno, l'inquadratura si CHIUDE:
##                      più vignetta, meno calore, la grana affiora. Non
##                      si annuncia — si sente, come una stanza in cui si
##                      abbassa la voce.
##   FESTA              il contrario esatto: la carta si apre e si scalda.
##
## Tutto passa da UNA funzione pura (`manopole`), quindi si prova headless
## a ogni ora e in ogni stato; il nodo si limita a raccogliere il contesto
## e a fondere i valori piano (mai uno scatto: la carta non sbatte).

## I valori di fabbrica: la carta a mezzogiorno d'un giorno sereno. Sono
## gli stessi default dichiarati nello shader — se lì cambiano, cambiano
## qui (un test tiene allineate le due dichiarazioni).
const BASE := {
	"strength": 0.24,
	"calore": 0.5,
	"grana": 0.045,
	"tint": Color(0.6, 0.46, 0.36),
}
## Il bruno freddo verso cui vira la notte, e quello caldo dell'oro.
const BRUNO_NOTTE := Color(0.42, 0.44, 0.56)
const BRUNO_ORO := Color(0.72, 0.48, 0.30)
## Quanto è lenta la fusione (al secondo): la carta cambia come cambia la
## luce del giorno, non come cambia una schermata.
const LENTEZZA := 0.9

var _rect: ColorRect
var _mat: ShaderMaterial
var _daynight: Node
var _weather: Node
var _cur := {}
var _tick := 0.0


func _ready() -> void:
	add_to_group("carta")
	(func() -> void:
		var vign := get_parent().get_node_or_null("Vignette")
		if vign:
			_rect = vign.get_node_or_null("ColorRect") as ColorRect
		if _rect and _rect.material is ShaderMaterial:
			_mat = _rect.material as ShaderMaterial
		_daynight = get_parent().get_node_or_null("DayNight")
		_weather = get_parent().get_node_or_null("Weather")
		_cur = manopole(contesto())
		_scrivi(_cur)).call_deferred()


func _process(delta: float) -> void:
	if _mat == null:
		return
	# quattro battiti al secondo bastano: la luce del giorno non corre
	_tick += delta
	if _tick < 0.25:
		return
	var passo := _tick
	_tick = 0.0
	var meta := manopole(contesto())
	var k := 1.0 - exp(-LENTEZZA * passo)
	_cur["strength"] = lerpf(float(_cur.get("strength", 0.24)), float(meta["strength"]), k)
	_cur["calore"] = lerpf(float(_cur.get("calore", 0.5)), float(meta["calore"]), k)
	_cur["grana"] = lerpf(float(_cur.get("grana", 0.045)), float(meta["grana"]), k)
	_cur["tint"] = (_cur.get("tint", BASE["tint"]) as Color).lerp(meta["tint"], k)
	_scrivi(_cur)


func _scrivi(v: Dictionary) -> void:
	_mat.set_shader_parameter("strength", float(v["strength"]))
	_mat.set_shader_parameter("calore", float(v["calore"]))
	_mat.set_shader_parameter("grana", float(v["grana"]))
	_mat.set_shader_parameter("tint", v["tint"])


## Il contesto di ADESSO, raccolto dal mondo. Separato da `manopole` di
## proposito: la matematica si prova senza albero della scena.
func contesto() -> Dictionary:
	var ora := float(_daynight.get("time")) if _daynight else 0.5
	var notte: bool = _daynight != null and bool(_daynight.call("is_night"))
	var pioggia: bool = _weather != null and bool(_weather.call("is_raining"))
	var nebbia: bool = _weather != null and bool(_weather.call("is_misty"))
	var legami := get_tree().get_first_node_in_group("legami")
	var lutto: bool = legami != null and bool(legami.call("lutto_attivo"))
	var cal := get_tree().get_first_node_in_group("calendario")
	var giorno := int(_daynight.get("day")) if _daynight else 1
	var festa := false
	if cal:
		festa = not (cal.festa_del_giorno(giorno) as Dictionary).is_empty()
	return {"ora": ora, "notte": notte, "pioggia": pioggia, "nebbia": nebbia,
			"lutto": lutto, "festa": festa}


## LA MATEMATICA DELLA CARTA — pura, deterministica, provata headless.
## Prende il contesto del mondo e restituisce le quattro manopole.
static func manopole(ctx: Dictionary) -> Dictionary:
	var ora := float(ctx.get("ora", 0.5))
	var strength := float(BASE["strength"])
	var calore := float(BASE["calore"])
	var grana := float(BASE["grana"])
	var tint: Color = BASE["tint"]

	# L'ORO DELLE SEI: due campane strette attorno all'alba e al tramonto.
	# Non è un effetto "meteo", è l'ora in cui la luce entra di taglio e
	# la carta di un'illustrazione ingiallisce ai bordi.
	var alba := 1.0 - clampf(absf(ora - 0.26) / 0.10, 0.0, 1.0)
	var sera := 1.0 - clampf(absf(ora - 0.75) / 0.11, 0.0, 1.0)
	var oro := maxf(alba, sera)
	oro = oro * oro * (3.0 - 2.0 * oro)      # smoothstep: entra e esce morbido
	calore += 0.38 * oro
	strength += 0.06 * oro
	tint = tint.lerp(BRUNO_ORO, 0.55 * oro)

	# LA NOTTE: il buio stringe l'inquadratura e il bruno si raffredda.
	# Si misura sull'ORA, non sul flag: così l'imbrunire arriva scivolando
	# invece di scattare quando DayNight decide che è notte.
	var buio := clampf(smoothstep(0.80, 0.94, ora) + smoothstep(0.22, 0.10, ora),
			0.0, 1.0)
	strength += 0.11 * buio
	calore -= 0.30 * buio
	tint = tint.lerp(BRUNO_NOTTE, 0.5 * buio)

	# PIOGGIA E NEBBIA: la carta si inumidisce — la grana affiora, il
	# calore cala, il bordo chiude.
	var umido := 0.0
	if bool(ctx.get("pioggia", false)):
		umido = 1.0
	elif bool(ctx.get("nebbia", false)):
		umido = 0.7
	strength += 0.07 * umido
	calore -= 0.22 * umido
	grana += 0.012 * umido

	# IL LUTTO: il gradino che conta davvero. Il villaggio ha appena perso
	# qualcuno e l'inquadratura si chiude — non si annuncia, si sente.
	if bool(ctx.get("lutto", false)):
		strength += 0.15
		calore -= 0.26
		grana += 0.020
		tint = tint.lerp(BRUNO_NOTTE, 0.28)

	# LA FESTA: il contrario esatto. La carta si apre e si scalda.
	if bool(ctx.get("festa", false)):
		strength -= 0.06
		calore += 0.16
		tint = tint.lerp(BRUNO_ORO, 0.25)

	return {
		# i limiti sono quelli degli hint_range dello shader: fuori di lì
		# Godot taglierebbe in silenzio e la manopola mentirebbe
		"strength": clampf(strength, 0.0, 1.0),
		"calore": clampf(calore, 0.0, 1.0),
		"grana": clampf(grana, 0.0, 0.2),
		"tint": tint,
	}
