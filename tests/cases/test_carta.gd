extends RefCounted
## LA CARTA DELL'INQUADRATURA: il post-process che fa sembrare ogni frame
## dipinto sulla stessa carta delle lettere e della lavagna (2026-07-26).
## Guardie:
##  1. lo shader della vignetta PARSA e ha le sue manopole (strength, tint,
##     grana, calore) — il parse-gate vero, non un confronto di stringhe;
##  2. è un post-process autentico (legge lo schermo) e parla la lingua del
##     handpaint (stessa fbm);
##  3. la grana è FERMA: niente TIME nello shader (una grana animata è
##     pellicola, non carta — e striscia sotto il dipinto);
##  4. resta cablato in MainLevel (ColorRect a tutto schermo, layer basso,
##     sotto la UI) e PhotoMode lo tiene nelle foto.

const PERCORSO := "res://shaders/vignette.gdshader"


func run(t) -> void:
	_test_parse_e_manopole(t)
	_test_linguaggio_della_carta(t)
	_test_cablaggio(t)


func _test_parse_e_manopole(t) -> void:
	var shader: Shader = load(PERCORSO)
	t.ok(shader != null, "lo shader della carta si carica")
	var nomi := {}
	for u in shader.get_shader_uniform_list():
		nomi[str(u.get("name", ""))] = true
	for manopola in ["strength", "tint", "grana", "grana_scala", "calore"]:
		t.ok(nomi.has(manopola), "lo shader espone la manopola '%s'" % manopola)


func _test_linguaggio_della_carta(t) -> void:
	var src := _sorgente(PERCORSO)
	t.ok(src.contains("hint_screen_texture"),
			"è un post-process vero: legge lo schermo, non ci disegna sopra")
	t.ok(src.contains("func fbm") or src.contains("float fbm"),
			"parla la lingua del handpaint: lo stesso lavaggio fbm")
	t.ok(src.contains("SCREEN_UV"), "la grana vive in spazio-schermo")
	t.ok(not src.contains("TIME"),
			"la grana è FERMA: la carta non striscia sotto il dipinto")


func _test_cablaggio(t) -> void:
	var tscn := _sorgente("res://scenes/levels/MainLevel.tscn")
	t.ok(tscn.contains("vignette.gdshader"), "MainLevel importa lo shader")
	t.ok(tscn.contains("ShaderMaterial_vign1"), "il materiale esiste in scena")
	t.ok(tscn.contains("name=\"Vignette\""), "il velo di carta è un nodo della scena")
	# PhotoMode nasconde la UI ma TIENE la carta: le foto restano dipinte
	var photo := _sorgente("res://scenes/interact/PhotoMode.gd")
	t.ok(photo.contains("Vignette"), "le foto della modalità foto restano su carta")


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""
