extends RefCounted
## LE POZZANGHERE-SPECCHIO: dopo la pioggia il prato raccoglie il cielo.
## Guardie:
##  1. la curva acqua-raccolta è PURA: niente pozze sotto un quarto di
##     zuppo, specchio pieno da zuppo fradicio, sempre monotona;
##  2. lo shader del terreno parsa e ha le sue manopole (pozzanghere,
##     pioggia_cade) più i due globali del cielo;
##  3. i globali esistono nel progetto e il DayNight li scrive ogni frame
##     (le pozzanghere riflettono LO STESSO tramonto del giocatore);
##  4. il Weather pilota specchi e increspature, e la roughness crolla
##     dentro la pozza (è così che il radiance della cupola si riflette,
##     come nello stagno).

const WEA := preload("res://scenes/world/Weather.gd")


func run(t) -> void:
	_test_curva_pura(t)
	_test_shader(t)
	_test_fili_attaccati(t)


func _test_curva_pura(t) -> void:
	t.eq(WEA.pozzanghere_da_bagnato(0.0), 0.0, "prato asciutto: niente pozze")
	t.eq(WEA.pozzanghere_da_bagnato(0.2), 0.0, "umido appena: ancora niente")
	t.ok(WEA.pozzanghere_da_bagnato(0.55) > 0.2, "a metà zuppo l'acqua si raccoglie")
	t.almost(WEA.pozzanghere_da_bagnato(0.95), 1.0, "fradicio: specchi pieni", 0.01)
	var prima := 0.0
	var monotona := true
	for i in 21:
		var v: float = WEA.pozzanghere_da_bagnato(float(i) / 20.0)
		if v < prima - 0.0001:
			monotona = false
		prima = v
	t.ok(monotona, "più zuppo, mai meno pozze (monotona)")


func _test_shader(t) -> void:
	var shader: Shader = load("res://shaders/ground.gdshader")
	t.ok(shader != null, "lo shader del terreno si carica")
	var nomi := {}
	for u in shader.get_shader_uniform_list():
		nomi[str(u.get("name", ""))] = true
	for manopola in ["pozzanghere", "pioggia_cade", "wetness"]:
		t.ok(nomi.has(manopola), "lo shader espone '%s'" % manopola)
	var src := _sorgente("res://shaders/ground.gdshader")
	t.ok(src.contains("global uniform vec4 cielo_alto")
			and src.contains("global uniform vec4 cielo_orizzonte"),
			"lo specchio legge il cielo dai globali")
	t.ok(src.contains("ROUGHNESS = mix(") and src.contains("0.045, pozza"),
			"dentro la pozza la roughness crolla: il radiance si riflette davvero")
	t.ok(src.contains("pioggia_cade") and src.contains("anello"),
			"mentre piove l'acqua si increspa ad anelli")


func _test_fili_attaccati(t) -> void:
	t.ok(_sorgente("res://project.godot").contains("cielo_alto")
			and _sorgente("res://project.godot").contains("cielo_orizzonte"),
			"i globali del cielo sono dichiarati nel progetto")
	var apply := _body("res://scenes/world/DayNight.gd", "_apply")
	t.ok(apply.contains("cielo_alto") and apply.contains("cielo_orizzonte"),
			"il DayNight scrive il cielo di ADESSO negli specchi")
	var proc := _body("res://scenes/world/Weather.gd", "_process")
	t.ok(proc.contains("pozzanghere_da_bagnato"),
			"il Weather riempie e ritira le pozze col bagnato vero")
	t.ok(proc.contains("pioggia_cade"),
			"e dice all'acqua quando incresparsi e quando fare specchio")


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""


func _body(path: String, fn: String) -> String:
	var src := _sorgente(path)
	var start := src.find("func %s(" % fn)
	if start < 0:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end - start) if end > start else -1)
