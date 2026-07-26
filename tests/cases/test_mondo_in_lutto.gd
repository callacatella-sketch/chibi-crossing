extends RefCounted
## IL MONDO IN LUTTO: durante i giorni del lutto il quadro si vela —
## meno saturo, sole appena più freddo, una nebbiolina bassa — e al primo
## sole dopo la fine, la saturazione che torna è la catarsi.
## Guardie:
##  1. il passo del velo è PURO e asimmetrico: l'ombra scende più svelta
##     di quanto la luce non torni (la catarsi va gustata, non scattata);
##  2. il velo converge davvero e resta in [0, 1];
##  3. i fili sono attaccati: saturazione, sole e nebbia leggono il velo,
##     il velo legge il lutto dei Legami (per gruppo, mai per percorso).

const DN := preload("res://scenes/world/DayNight.gd")


func run(t) -> void:
	_test_passo_del_velo(t)
	_test_fili_attaccati(t)


func _test_passo_del_velo(t) -> void:
	# 45 secondi simulati verso il lutto: il velo è quasi tutto sceso
	var giu := 0.0
	for i in 450:
		giu = DN.passo_velo(giu, 1.0, 0.1)
	t.ok(giu > 0.9, "in ~45s il velo del lutto è sceso (%.2f)" % giu)
	# gli stessi 45 secondi verso la luce: la catarsi è ancora in cammino
	var su := 1.0
	for i in 450:
		su = DN.passo_velo(su, 0.0, 0.1)
	t.ok(su > 0.1, "la catarsi è più lenta dell'ombra (dopo 45s resta %.2f)" % su)
	t.ok(1.0 - giu < su, "asimmetria vera: scendere è più svelto che risalire")
	# convergenza e confini
	for i in 3000:
		su = DN.passo_velo(su, 0.0, 0.1)
	t.almost(su, 0.0, "prima o poi la luce torna tutta", 0.01)
	t.eq(DN.passo_velo(0.0, 0.0, 1.0), 0.0, "senza lutto il velo resta a zero")
	t.ok(DN.passo_velo(0.5, 1.0, 100.0) <= 1.0, "il velo non supera mai l'uno")


func _test_fili_attaccati(t) -> void:
	var src := _sorgente("res://scenes/world/DayNight.gd")
	t.ok(src.contains("adjustment_saturation = _g_sat * (1.0 - 0.13 * _lutto_f)"),
			"il lutto toglie il 13%% di saturazione: sentirlo, mai notarlo")
	t.ok(_body(src, "_apply").contains("0.0024 * _lutto_f"),
			"nel lutto sale una nebbiolina bassa")
	var sole := _body(src, "_apply")
	t.ok(sole.contains("Color(0.93, 0.97, 1.04), _lutto_f"),
			"il sole del lutto si raffredda appena (moltiplicando)")
	t.ok(_body(src, "_lutto_vuole").contains("lutto_attivo"),
			"il velo legge il lutto vero dei Legami")
	t.ok(_body(src, "_process").contains("passo_velo"),
			"il velo respira nel ciclo, col suo passo puro")


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""


func _body(src: String, fn: String) -> String:
	var start := src.find("func %s(" % fn)
	if start < 0:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end - start) if end > start else -1)
