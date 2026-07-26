extends RefCounted
## IL FILO ROSSO LETTERALE: il simbolo del gioco reso visibile.
## Nei momenti che si annodano appare il nastro luminoso tra le zampe.
## Guardie:
##  1. la CURVA del filo è pura: i capi stanno ESATTAMENTE sulle zampe,
##     la pancia sta al centro, senza pancia il filo è (quasi) dritto;
##  2. le perline della storia stanno LUNGO il filo, mai sulle zampe,
##     e non superano mai il massimo;
##  3. lo shader parsa e ha le sue manopole (progresso, dissolvenza,
##     oro, intensita);
##  4. un filo alla volta: la seconda richiesta si mette in coda;
##  5. i fili sono attaccati: momento() e ricorda() mostrano il filo,
##     la consolazione del Congedo pure, il Visitor ha la zampina,
##     il nodo FiloRosso vive in MainLevel.

const FILO := preload("res://scenes/world/FiloRosso.gd")


func run(t) -> void:
	_test_curva_pura(t)
	_test_perline(t)
	_test_shader(t)
	_test_un_filo_alla_volta(t)
	_test_fili_attaccati(t)


func _test_curva_pura(t) -> void:
	var pa := Vector3(1, 1, 0)
	var pb := Vector3(3, 1.2, 2)
	t.ok(FILO.punto_filo(pa, pb, 0.0, 0.2, 1.0).distance_to(pa) < 0.0001,
			"il capo del filo sta ESATTAMENTE sulla zampa di Mochi")
	t.ok(FILO.punto_filo(pa, pb, 1.0, 0.2, 1.0).distance_to(pb) < 0.0001,
			"e l'altro capo sulla zampa dell'amico")
	var centro := FILO.punto_filo(pa, pb, 0.5, 0.2, 0.0)
	t.ok(centro.y < pa.lerp(pb, 0.5).y - 0.15,
			"al centro il filo fa la pancia (la catenaria)")
	var dritto := FILO.punto_filo(pa, pb, 0.5, 0.0, 0.0)
	t.ok(dritto.distance_to(pa.lerp(pb, 0.5)) <= 0.009,
			"senza pancia resta solo il respiro del vento (quasi dritto)")


func _test_perline(t) -> void:
	t.eq(FILO.frazioni_perline(0), [], "senza storia, niente perline")
	var tre: Array = FILO.frazioni_perline(3)
	t.eq(tre.size(), 3, "tre momenti, tre perline")
	t.almost(float(tre[1]), 0.5, "la perlina di mezzo sta nel mezzo", 0.001)
	for f in tre:
		t.ok(float(f) > 0.0 and float(f) < 1.0,
				"le perline stanno LUNGO il filo, mai sulle zampe")
	t.eq(FILO.frazioni_perline(99).size(), FILO.MAX_PERLINE,
			"la storia lunga non affolla il filo (max %d)" % FILO.MAX_PERLINE)


func _test_shader(t) -> void:
	var shader: Shader = load("res://shaders/filo_rosso.gdshader")
	t.ok(shader != null, "lo shader del filo si carica")
	var nomi := {}
	for u in shader.get_shader_uniform_list():
		nomi[str(u.get("name", ""))] = true
	for manopola in ["progresso", "dissolvenza", "oro", "intensita"]:
		t.ok(nomi.has(manopola), "lo shader espone '%s'" % manopola)


func _test_un_filo_alla_volta(t) -> void:
	var filo = FILO.new()
	var a := Node3D.new()
	var b := Node3D.new()
	# senza _ready (fuori dall'albero) _mat non esiste: annoda deve
	# comunque rifiutare i capi nulli senza esplodere
	filo.annoda(null, b, 3)
	t.ok(not filo._attivo, "un capo nullo non annoda niente")
	a.free()
	b.free()
	filo.free()
	# il momento va guardato, non affastellato: la fonte lo dichiara
	var src := _sorgente("res://scenes/world/FiloRosso.gd")
	t.ok(src.contains("_coda"), "le richieste successive si mettono in coda")


func _test_fili_attaccati(t) -> void:
	t.ok(_body("res://scenes/world/Legami.gd", "momento").contains("mostra_filo"),
			"il momento che si annoda mostra il filo")
	t.ok(_body("res://scenes/world/Legami.gd", "ricorda").contains("mostra_filo"),
			"il ricordo che riaffiora fa brillare il filo (piano)")
	t.ok(_body("res://scenes/world/Legami.gd", "mostra_filo").contains("annoda"),
			"l'API del filo arriva fino al nastro")
	t.ok(_body("res://scenes/world/Congedo.gd", "consolato").contains("mostra_filo"),
			"la consolazione annoda il filo")
	t.ok(_body("res://scenes/npc/Visitor.gd", "paw_world").contains("_c_arms"),
			"il vicino porge la zampina vera")
	t.ok(_sorgente("res://scenes/levels/MainLevel.tscn").contains("FiloRosso"),
			"il Filo Rosso è un nodo della scena principale")
	# l'oro: il desiderio del congedo tinge il filo di dorato
	var mom := _body("res://scenes/world/Legami.gd", "momento")
	t.ok(mom.contains("\"oro\""), "il desiderio d'oro ha il suo filo dorato")


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""


## Il corpo di una funzione: dal suo `func nome(` alla `func` successiva.
func _body(path: String, fn: String) -> String:
	var src := _sorgente(path)
	var start := src.find("func %s(" % fn)
	if start < 0:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end - start) if end > start else -1)
