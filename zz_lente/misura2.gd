extends SceneTree
const ANIMO := preload("res://scenes/npc/Animo.gd")
const RIL := preload("res://scenes/npc/Rilettura.gd")

func _nuovo(sogno: String) -> RefCounted:
	var a: RefCounted = ANIMO.new()
	a.setup({"name": "Prova", "seed": 7,
		"tratti": {"orgoglio": 0.5, "lealta": 0.5, "grinta": 0.5,
			"codardia": 0.5, "ambizione": 0.5}, "sogno": sogno})
	return a

func _prove_vive(a: RefCounted) -> float:
	var p := 0.0
	for r in a.ricordi:
		if str(r["attore"]) != "giocatore" or float(r["valenza"]) <= 0.0:
			continue
		p += RIL.peso_prova(float(r["valenza"]), float(r["intensita"]),
				pow(0.5, float(a.oggi - int(r["quando"])) / 18.0))
	return p

func _rancore_da(t: float, p: float) -> float:
	return 1.0 - exp(-maxf(0.0, t - p * 1.4) / 55.0 * 3.0)

func _grad(a: RefCounted, r: float) -> String:
	var spinta: float = r + minf(a.disagio() * 0.18, 0.14)
	if r < 0.30:
		spinta = minf(spinta, float(ANIMO.SOGLIA["rifiuto"]) - 0.01)
	var s: Dictionary = a.soglie()
	var target := 0
	for i in ANIMO.SCALA.size():
		if spinta >= float(s[ANIMO.SCALA[i]]):
			target = i
	return ANIMO.SCALA[target]

func _initialize() -> void:
	print("══════ A · dove il gradino si sposta (25 giornate di legna, lutto g.20)")
	for piatti in [14, 16, 18, 19, 20, 21, 22, 24, 26, 30]:
		var a := _nuovo("guerriero")
		for g in 25:
			if g < piatti:
				a.ricorda("piatto", "giocatore", 0.85, 0.9)
			a.esegue("taglia_legna", "giocatore")
			if g == 20:
				a.lutto("Nocciola")
			a.passa_giorno()
		var c: Dictionary = a.conto_verso("giocatore")
		var rd := _rancore_da(float(c["torti"]), float(c["prove"]))
		var rp := _rancore_da(float(c["torti"]), _prove_vive(a))
		var seg := "  ←── DIVERSO" if _grad(a, rd) != _grad(a, rp) else ""
		print("   piatti %-3d  ranc %.4f/%.4f  gradino %s / %s%s"
				% [piatti, rd, rp, _grad(a, rd), _grad(a, rp), seg])

	print("")
	print("══════ B · la RECENZA del sommario: le prove non invecchiano")
	var b := _nuovo("guerriero")
	for g in 30:
		b.ricorda("piatto", "giocatore", 0.85, 0.9)
		b.esegue("taglia_legna", "giocatore")
		b.passa_giorno()
	for g in 200:
		b.esegue("taglia_legna", "giocatore")
		b.passa_giorno()
	var ca: Dictionary = b.conto_verso("giocatore")
	print("   g.%d — 30 piatti fatti fra il g.0 e il g.29, mai piu' niente" % b.oggi)
	print("      sommario piatto: %s" % str(b.sommario.get("piatto|giocatore", {})))
	print("      prove = %.5f   (righe vive: %.5f)" % [float(ca["prove"]), _prove_vive(b)])
	# un solo piatto, e poi lo si lascia potare
	b.ricorda("piatto", "giocatore", 0.85, 0.9)
	var g_piatto: int = b.oggi
	for g in 60:
		b.esegue("taglia_legna", "giocatore")
		b.passa_giorno()
	var cb: Dictionary = b.conto_verso("giocatore")
	print("   UN piatto al g.%d, poi 60 giornate: `ultimo` diventa %d"
			% [g_piatto, int((b.sommario["piatto|giocatore"] as Dictionary)["ultimo"])])
	print("      prove = %.5f   (righe vive: %.5f)" % [float(cb["prove"]), _prove_vive(b)])
	# quanto varrebbero ONESTAMENTE: 30 piatti vecchi + 1 recente
	var onesto := 0.0
	var v0 := 0.85
	for g in 30:
		onesto += v0 * 0.9 * pow(0.5, float(b.oggi - g) / 18.0)
	onesto += v0 * 0.9 * pow(0.5, float(b.oggi - g_piatto) / 18.0)
	print("      con la recenza PER RIGA (stessa valenza nominale): ~%.5f" % onesto)
	print("      → il sommario ne conta %.1f volte tanto" % (float(cb["prove"]) / maxf(onesto, 1e-9)))

	print("")
	print("══════ C · costo di conto_verso con un sommario da villaggio vero")
	var q := _nuovo("guerriero")
	for g in 40:
		q.esegue("taglia_legna", "giocatore")
		q.passa_giorno()
	var attori := ["giocatore", "Nocciola", "Cannella", "Prugna", "Malva",
			"Timo", "Loto", "Cacao", "Brioche", "Ciliegia", "Biscotto",
			"Castagna", "Nuvola", "Amaretto", "se_stesso", "guardia"]
	var tipi := ["taglia_legna", "coltiva", "cucina", "guardia", "esplora",
			"riposa", "festa", "abbellisce", "suona", "piatto", "regalo",
			"lutto", "consolato", "vegliato", "benvenuto", "onsen",
			"promessa", "nascondino", "voce", "reperto"]
	for at in attori:
		for tp in tipi:
			var k := "%s|%s" % [tp, at]
			if not q.sommario.has(k):
				q.sommario[k] = {"n": 3, "peso": (0.4 if tp == "piatto" else -0.2),
						"ultimo": q.oggi - 5}
	print("   chiavi di sommario: %d" % q.sommario.size())
	var t0 := Time.get_ticks_usec()
	for i in 100:
		q.conto_verso("giocatore")
	var t1 := Time.get_ticks_usec()
	print("   conto_verso(): %.1f µs" % ((t1 - t0) / 100.0))
	t0 = Time.get_ticks_usec()
	for i in 100:
		q.rancore("giocatore")
	t1 = Time.get_ticks_usec()
	print("   rancore(): %.1f µs — e lo chiama aggiorna_scala una volta al giorno"
			% ((t1 - t0) / 100.0))
	t0 = Time.get_ticks_usec()
	for i in 100:
		q._ricalcola_deriva()
		q._deriva_giorno = -1
	t1 = Time.get_ticks_usec()
	print("   _ricalcola_deriva(): %.1f µs (in _ensure_brain viene chiamata DUE volte)"
			% ((t1 - t0) / 100.0))

	print("")
	print("══════ D · cause() dopo la potatura per schema (lo scenario del brief)")
	var d := _nuovo("guerriero")
	for g in 40:
		d.esegue("taglia_legna", "giocatore")
		if g == 20:
			d.lutto("Nocciola")
		d.passa_giorno()
	print("   %s" % str(d.cause("giocatore")))
	quit(0)
