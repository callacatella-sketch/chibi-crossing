extends RefCounted
## IL SALUTO DELL'INDOLE: la stessa gioia, filtrata dal carattere — il
## timido applaude piccolo (zampine giunte, battiti minuti), il
## brontolone prima dice mezzo no con la testa e POI si concede il
## saltello riluttante (e un secondo, piccolissimo: cuore di panna).
## Le prove misurano le onde-firma di recita_bersagli, la mappa
## indole->stile con le sue priorità, e il cablaggio cervello->corpo.

const VIS := preload("res://scenes/npc/Visitor.gd")


class FintoCervello:
	var indoli: Array = []
	func _init(lista: Array) -> void:
		indoli = lista
	func has_indole(id: String) -> bool:
		return id in indoli


func run(t) -> void:
	_test_mappa(t)
	_test_repertorio(t)
	_test_onde_firma(t)
	_test_cablaggio(t)


func _test_mappa(t) -> void:
	t.eq(VIS.saluto_di(FintoCervello.new(["timido"])), "saluto_timido",
			"il timido ha il suo applauso piccolo")
	t.eq(VIS.saluto_di(FintoCervello.new(["brontolone"])), "saluto_brontolone",
			"il brontolone il suo mezzo saltello")
	t.eq(VIS.saluto_di(FintoCervello.new(["sognatore"])), "saluto_sognante",
			"il sognatore la sua onda lenta")
	t.eq(VIS.saluto_di(FintoCervello.new(["goloso"])), "saluto_pancino",
			"il goloso il tamburello sul pancino")
	t.eq(VIS.saluto_di(FintoCervello.new([])), "saluto_festoso",
			"senza indoli marcate: il festoso di default")
	t.eq(VIS.saluto_di(null), "saluto_festoso",
			"senza cervello: nessun crash, festoso")
	# le priorità: l'indole più caratteriale vince sulle altre
	t.eq(VIS.saluto_di(FintoCervello.new(["chiacchierone", "timido"])),
			"saluto_timido", "timido vince su chiacchierone")
	t.eq(VIS.saluto_di(FintoCervello.new(["mattiniero", "brontolone"])),
			"saluto_brontolone", "brontolone vince su mattiniero")


func _test_repertorio(t) -> void:
	var quanti := 0
	for stile in VIS.RECITA_TRANS:
		if not str(stile).begins_with("saluto"):
			continue
		quanti += 1
		var d: float = float((VIS.RECITA_TRANS[stile] as Dictionary)["dur"])
		t.ok(d >= 1.0 and d <= 2.5,
				"%s: dura quanto un saluto (%.1f s), non un monologo" % [stile, d])
		# ogni stile MUOVE il corpo: a metà transitorio almeno un canale è vivo
		var b: Dictionary = VIS.recita_bersagli("sereno", str(stile), d * 0.45, 1.0)
		var vivo := 0.0
		for c in b:
			vivo = maxf(vivo, absf(float(b[c])))
		t.ok(vivo > 0.05, "%s: il corpo si muove davvero (%.3f)" % [stile, vivo])
	t.eq(quanti, 8, "otto saluti nel repertorio: uno per indole")


func _test_onde_firma(t) -> void:
	# il timido: le zampine vanno VERSO IL PETTO, insieme (l'applauso).
	# az0 positivo = sinistra al petto, az1 negativo = destra al petto.
	var applauso := false
	for i in 20:
		var b: Dictionary = VIS.recita_bersagli("sereno", "saluto_timido",
				0.3 + 0.05 * float(i), 1.0)
		if float(b["az0"]) > 0.55 and float(b["az1"]) < -0.55:
			applauso = true
	t.ok(applauso, "timido: le zampine si giungono e battono (applauso piccolo)")
	# il brontolone: PRIMA il no della testa (hy vivo, niente salto)...
	var presto: Dictionary = VIS.recita_bersagli("sereno", "saluto_brontolone", 0.2, 1.0)
	t.ok(absf(float(presto["hy"])) > 0.02 and float(presto["vy"]) < 0.005,
			"brontolone: prima il mezzo no della testa, il salto aspetta")
	# ...POI il saltello riluttante...
	var poi: Dictionary = VIS.recita_bersagli("sereno", "saluto_brontolone", 0.76, 1.0)
	t.ok(float(poi["vy"]) > 0.02, "brontolone: il saltello arriva, trattenuto")
	# ...e in coda il secondo, piccolissimo (il cuore di panna)
	var coda: Dictionary = VIS.recita_bersagli("sereno", "saluto_brontolone", 1.42, 1.0)
	t.ok(float(coda["vy"]) > 0.01 and float(coda["vy"]) < float(poi["vy"]),
			"brontolone: il secondo saltello c'è, ed è più piccolo del primo")
	# il festoso salta più in alto del pancino: le ampiezze raccontano
	var festa: Dictionary = VIS.recita_bersagli("sereno", "saluto_festoso", 0.6, 1.0)
	var pancia: Dictionary = VIS.recita_bersagli("sereno", "saluto_pancino", 0.6, 1.0)
	t.ok(float(festa["vy"]) > float(pancia["vy"]),
			"il chiacchierone saltella più in alto del goloso che tamburella")


func _test_cablaggio(t) -> void:
	var visitor := _sorgente("res://scenes/npc/Visitor.gd")
	var visitors := _sorgente("res://scenes/npc/Visitors.gd")
	t.ok(visitor.contains("set_meta(\"postura\","),
			"saluto e festa passano dalla recita (si sommano a ogni stato)")
	var greet := visitor.substr(visitor.find("func _resident_greet"))
	t.ok(greet.contains("saluto_stile") and greet.contains("saluto_timido"),
			"il saluto al passaggio usa lo stile dell'indole (e la voce giusta)")
	var cel := visitor.substr(visitor.find("func celebrate"))
	t.ok(cel.contains("saluto_stile") and cel.contains("doppio rimbalzo"),
			"celebrate recita l'indole, col rimbalzo di ripiego per gli ospiti")
	t.ok(visitors.contains("saluto_di(_brains[key])"),
			"Visitors cabla lo stile dal cervello appena esiste")


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""
