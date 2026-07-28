extends RefCounted
## Il corpo vivo del mercante: prima era vivo solo dal collo in su (il
## volto recitava, il corpo era una statua). Verifica:
##  • il RESPIRO di fondo: da fermo il corpo non è mai congelato (i
##    canali oscillano nel tempo), ma resta un respiro (valori piccoli);
##  • MOSTRA LA MERCE: a metà gesto le zampe sono APERTE a ventaglio e
##    alzate in offerta, le orecchie su per l'entusiasmo — e a fine
##    gesto tutto rientra nel respiro;
##  • L'INCHINO del congedo: raccoglimento, il busto GIÙ profondo a metà
##    corsa, il capo che segue, e la risalita dolce fino al respiro;
##  • le durate dei gesti sono quelle promesse;
##  • i contratti nel sorgente: lo spawn CATTURA braccia/orecchie con la
##    posa di riposo del builder (mai cancellarla: base + offset), il
##    _process anima il corpo ogni frame, la partenza fa PRIMA l'inchino
##    e poi richiude il carretto, l'apertura del banco mostra la merce.

const CAL := "res://scenes/world/Calendar.gd"


func run(t) -> void:
	var s: GDScript = load(CAL)
	t.ok(s != null and s.can_instantiate(), "Calendar.gd compila")
	if s == null or not s.can_instantiate():
		return

	_test_respiro(t, s)
	_test_mostra(t, s)
	_test_inchino(t, s)
	_test_contratti(t)


func _test_respiro(t, s: GDScript) -> void:
	var a: Dictionary = s.gesto_bersagli("", 0.0, 0.4)
	var b: Dictionary = s.gesto_bersagli("", 0.0, 1.7)
	var vivo := false
	for c in a:
		if absf(float(a[c]) - float(b[c])) > 0.005:
			vivo = true
	t.ok(vivo, "da fermo il corpo RESPIRA (i canali si muovono nel tempo)")
	for c in a:
		t.ok(absf(float(a[c])) < 0.12,
				"…ma è un respiro, non un gesto (%s=%.3f)" % [c, a[c]])
	t.almost(float(s.DUR_MOSTRA), 1.8, "la mostra dura 1.8 s")
	t.almost(float(s.DUR_INCHINO), 2.3, "l'inchino dura 2.3 s")


func _test_mostra(t, s: GDScript) -> void:
	var picco: Dictionary = s.gesto_bersagli("mostra", 0.45, 0.0)
	t.ok(float(picco["apri"]) > 0.6,
			"a metà gesto le zampe sono APERTE a ventaglio (%.2f)" % picco["apri"])
	t.ok(float(picco["alza"]) < -0.35,
			"…e alzate in offerta verso la merce (%.2f)" % picco["alza"])
	t.ok(float(picco["orecchie"]) < 0.0, "le orecchie su: l'entusiasmo")
	t.ok(float(picco["rx"]) > 0.03, "il busto si porge verso il cliente")
	var fine: Dictionary = s.gesto_bersagli("mostra", 1.0, 0.0)
	t.ok(absf(float(fine["apri"]) - float(s.gesto_bersagli("", 0.0, 0.0)["apri"])) < 0.05,
			"a fine gesto le zampe tornano al respiro")


func _test_inchino(t, s: GDScript) -> void:
	var giu: Dictionary = s.gesto_bersagli("inchino", 0.5, 0.0)
	t.ok(float(giu["rx"]) > 0.45,
			"a metà corsa il busto è GIÙ, inchino profondo (%.2f)" % giu["rx"])
	t.ok(float(giu["hx"]) > 0.1, "il capo segue oltre: il rispetto")
	t.ok(float(giu["dip"]) < 0.0, "il peso scende con l'inchino")
	var risalita: Dictionary = s.gesto_bersagli("inchino", 1.0, 0.0)
	t.ok(absf(float(risalita["rx"])) < 0.05,
			"e la risalita riporta il busto dritto (%.3f)" % risalita["rx"])
	# l'inchino nel MEZZO del hold (t01=0.55): ancora profondo (un attimo
	# di rispetto, non un molleggio)
	var hold: Dictionary = s.gesto_bersagli("inchino", 0.55, 0.0)
	t.ok(float(hold["rx"]) > 0.45, "l'attimo di rispetto: si RESTA giù (%.2f)" % hold["rx"])


func _test_contratti(t) -> void:
	var src := FileAccess.get_file_as_string(CAL)
	t.ok(src.contains("_merchant_arm_base.append"),
			"lo spawn cattura la POSA di riposo delle braccia")
	t.ok(src.contains("base.x + float(_corpo[\"alza\"])"),
			"le braccia si animano SOPRA la posa del builder, mai al suo posto")
	t.ok(src.contains("_merchant_corpo(delta)"),
			"il _process anima il corpo ogni frame")
	var despawn := src.substr(src.find("func _despawn_merchant()"))
	despawn = despawn.substr(0, despawn.find("func _despawn_merchant_ora"))
	t.ok(despawn.contains("\"inchino\""),
			"la partenza fa PRIMA l'inchino, poi richiude il carretto")
	var trade := src.substr(src.find("func _merchant_trade"))
	trade = trade.substr(0, trade.find("\n\n\nfunc "))
	t.ok(trade.contains("_mostra_la_merce"),
			"aprire il banco mostra la merce a zampe aperte")