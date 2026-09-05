extends SceneTree
const ANIMO := preload("res://scenes/npc/Animo.gd")
const RIL := preload("res://scenes/npc/Rilettura.gd")

func _nuovo() -> RefCounted:
	var a: RefCounted = ANIMO.new()
	a.setup({"name": "Prova", "seed": 7,
		"tratti": {"orgoglio": 0.5, "lealta": 0.5, "grinta": 0.5,
			"codardia": 0.5, "ambizione": 0.5}, "sogno": "guerriero"})
	return a

func _prove_vive(a: RefCounted) -> float:
	var p := 0.0
	for r in a.ricordi:
		if str(r["attore"]) != "giocatore" or float(r["valenza"]) <= 0.0:
			continue
		p += RIL.peso_prova(float(r["valenza"]), float(r["intensita"]),
				pow(0.5, float(a.oggi - int(r["quando"])) / 18.0))
	return p

func _r(t: float, p: float) -> float:
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
	print("══ UN PIATTO OGNI N GIORNI, legna che tradisce il sogno tutti i giorni")
	print("   (200 giornate)")
	print("  %-8s %-9s %-9s %-9s %-9s %-9s %-11s %-11s" % ["ogni",
			"piatti", "torti", "prove_ora", "prove_pri", "r_ora", "r_pri", "gradino ora/prima"])
	for ogni in [3, 5, 10, 20, 40]:
		var a := _nuovo()
		var n := 0
		for g in 200:
			if g % ogni == 0:
				a.ricorda("piatto", "giocatore", 0.85, 0.9)
				n += 1
			a.esegue("taglia_legna", "giocatore")
			a.passa_giorno()
		var c: Dictionary = a.conto_verso("giocatore")
		var pd: float = float(c["prove"])
		var pp: float = _prove_vive(a)
		var rd := _r(float(c["torti"]), pd)
		var rp := _r(float(c["torti"]), pp)
		print("  %-8d %-9d %-9.3f %-9.3f %-9.3f %-9.4f %-9.4f %s / %s"
				% [ogni, n, float(c["torti"]), pd, pp, rd, rp,
				_grad(a, rd), _grad(a, rp)])
		print("        sommario piatto: %s" % str(a.sommario.get("piatto|giocatore", {})))
		var sch: Dictionary = RIL.scheda(float(c["torti"]), pd,
				a.limbico.divario("giocatore", float(c["media_prove"])))
		print("        rilettura: rapporto %.3f  divario %.3f  riletto %s"
				% [float(sch["rapporto"]), float(sch["divario"]), str(sch["riletto"])])

	print("")
	print("══ E SE IL GIOCATORE SMETTE? (100 gentilezze, poi solo torti)")
	var b := _nuovo()
	for g in 100:
		b.ricorda("piatto", "giocatore", 0.85, 0.9)
		b.esegue("taglia_legna", "giocatore")
		b.passa_giorno()
	for extra in [0, 30, 60, 120, 240]:
		var c2 := _nuovo()
		c2.load(b.save())
		for g in extra:
			c2.esegue("taglia_legna", "giocatore")
			c2.passa_giorno()
		var cc: Dictionary = c2.conto_verso("giocatore")
		print("   +%-4d giornate di soli torti: torti %.3f prove %.3f (vive %.3f) → rancore %.4f (prima %.4f)"
				% [extra, float(cc["torti"]), float(cc["prove"]), _prove_vive(c2),
				_r(float(cc["torti"]), float(cc["prove"])),
				_r(float(cc["torti"]), _prove_vive(c2))])
	quit(0)
