extends SceneTree
## LENTE DELLA CORRETTEZZA — misure temporanee, file NON tracciato.
const ANIMO := preload("res://scenes/npc/Animo.gd")
const RIL := preload("res://scenes/npc/Rilettura.gd")

func _nuovo(sogno: String, cod := 0.5) -> RefCounted:
	var a: RefCounted = ANIMO.new()
	a.setup({"name": "Prova", "seed": 7,
		"tratti": {"orgoglio": 0.5, "lealta": 0.5, "grinta": 0.5,
			"codardia": cod, "ambizione": 0.5},
		"sogno": sogno})
	return a

func _prove_vive(a: RefCounted) -> float:
	# il ramo di PRIMA della cura (a): solo le righe vive
	var p := 0.0
	for r in a.ricordi:
		if str(r["attore"]) != "giocatore" or float(r["valenza"]) <= 0.0:
			continue
		p += RIL.peso_prova(float(r["valenza"]), float(r["intensita"]),
				pow(0.5, float(a.oggi - int(r["quando"])) / 18.0))
	return p

func _rancore_da(torti: float, prove: float) -> float:
	return 1.0 - exp(-maxf(0.0, torti - prove * 1.4) / 55.0 * 3.0)

func _gradino_da(a: RefCounted, r: float) -> int:
	var spinta: float = r + minf(a.disagio() * 0.18, 0.14)
	if r < 0.30:
		spinta = minf(spinta, float(ANIMO.SOGLIA["rifiuto"]) - 0.01)
	var s: Dictionary = a.soglie()
	var target := 0
	for i in ANIMO.SCALA.size():
		if spinta >= float(s[ANIMO.SCALA[i]]):
			target = i
	return target

func _storia(piatti: int, giorni: int, cod := 0.5) -> RefCounted:
	var a := _nuovo("guerriero", cod)
	for g in giorni:
		if g < piatti:
			a.ricorda("piatto", "giocatore", 0.85, 0.9)
		a.esegue("taglia_legna", "giocatore")
		if g == 20:
			a.lutto("Nocciola")          # nessun consolatore
		a.passa_giorno()
	return a

func _initialize() -> void:
	print("══════ 1 · IL RANCORE E IL GRADINO, prima e dopo la cura (a)")
	print("   sogno guerriero, taglia_legna ogni giorno, lutto ignorato al g.20")
	print("  %-8s %-7s %-9s %-9s %-9s %-8s %-8s %-6s %-6s" % ["piatti",
			"giorni", "torti", "prove_ora", "prove_pri", "ranc_ora",
			"ranc_pri", "gr_ora", "gr_pri"])
	for giorni in [25, 40, 60]:
		for piatti in [0, 5, 10, 20]:
			var a := _storia(piatti, giorni)
			var c: Dictionary = a.conto_verso("giocatore")
			var torti: float = float(c["torti"])
			var pd: float = float(c["prove"])
			var pp: float = _prove_vive(a)
			var rd := _rancore_da(torti, pd)
			var rp := _rancore_da(torti, pp)
			print("  %-8d %-7d %-9.3f %-9.3f %-9.3f %-8.3f %-8.3f %-6s %-6s" % [
					piatti, giorni, torti, pd, pp, rd, rp,
					ANIMO.SCALA[_gradino_da(a, rd)],
					ANIMO.SCALA[_gradino_da(a, rp)]])

	print("")
	print("══════ 2 · LA RECENZA RESUSCITATA dal sommario")
	var b := _nuovo("guerriero")
	for g in 30:
		b.ricorda("piatto", "giocatore", 0.85, 0.9)
		b.esegue("taglia_legna", "giocatore")
		b.passa_giorno()
	for g in 100:
		b.esegue("taglia_legna", "giocatore")
		b.passa_giorno()
	var c1: Dictionary = b.conto_verso("giocatore")
	print("   dopo 100 giornate SENZA gentilezze: prove = %.4f (vive %.4f)"
			% [float(c1["prove"]), _prove_vive(b)])
	b.ricorda("piatto", "giocatore", 0.85, 0.9)
	var c2: Dictionary = b.conto_verso("giocatore")
	print("   UN SOLO piatto oggi, e le prove diventano: %.4f (vive %.4f)"
			% [float(c2["prove"]), _prove_vive(b)])
	print("   → un gesto solo ha rimesso in vita %.4f di prove"
			% (float(c2["prove"]) - float(c1["prove"])))
	print("   n_prove = %d, media_prove = %.4f" % [int(c2["n_prove"]),
			float(c2["media_prove"])])

	print("")
	print("══════ 3 · IL DIVARIO morde mai?")
	for piatti in [0, 5, 20]:
		var a := _storia(piatti, 40)
		var c: Dictionary = a.conto_verso("giocatore")
		var d: float = a.limbico.divario("giocatore", float(c["media_prove"]))
		var sch: Dictionary = RIL.scheda(float(c["torti"]), float(c["prove"]), d)
		var quante := 0
		for k in a.limbico.attese:
			if str(k).ends_with("|giocatore"):
				quante += 1
		print("   piatti %-3d divario %.4f (chiavi %d) rapporto %.3f riletto %s"
				% [piatti, d, quante, float(sch["rapporto"]),
				str(sch["riletto"])])
		print("      attese: %s" % str(a.limbico.attese))

	print("")
	print("══════ 4 · media_prove: scala e limiti")
	var m := _nuovo("guerriero")
	for g in 200:
		m.ricorda("piatto", "giocatore", 1.0, 1.0)
		m.passa_giorno()
	var cm: Dictionary = m.conto_verso("giocatore")
	print("   200 piatti a valenza 1: prove %.3f  n %d  media %.4f"
			% [float(cm["prove"]), int(cm["n_prove"]), float(cm["media_prove"])])
	print("   sommario: %s" % str(m.sommario))

	print("")
	print("══════ 5 · regola() con limbico == null")
	var z := _nuovo("guerriero")
	z.limbico = null
	var rr: Dictionary = z.regola("giocatore")
	print("   %s" % str(rr))
	var z2 := _storia(10, 40)
	print("   normale: %s" % str(z2.regola("giocatore")))

	print("")
	print("══════ 6 · COSTO di regola() (µs), sommario grande")
	var q := _storia(20, 120)
	print("   ricordi vivi %d · sommario %d · attese %d"
			% [q.ricordi.size(), q.sommario.size(), q.limbico.attese.size()])
	var t0 := Time.get_ticks_usec()
	for i in 200:
		q.regola("giocatore")
	var t1 := Time.get_ticks_usec()
	print("   regola(): %.1f µs a chiamata" % ((t1 - t0) / 200.0))
	t0 = Time.get_ticks_usec()
	for i in 200:
		q.conto_verso("giocatore")
	t1 = Time.get_ticks_usec()
	print("   conto_verso(): %.1f µs" % ((t1 - t0) / 200.0))

	print("")
	print("══════ 7 · regola() ha effetti collaterali? (morso)")
	var w := _storia(0, 40)
	var reg0: float = w.limbico.regolazione
	var r1: Dictionary = w.regola("giocatore")
	print("   modo %s · regolazione %.4f → %.4f"
			% [str(r1["modo"]), reg0, w.limbico.regolazione])
	var w2 := _storia(20, 40)
	var reg2: float = w2.limbico.regolazione
	var r2: Dictionary = w2.regola("giocatore")
	print("   modo %s · regolazione %.4f → %.4f"
			% [str(r2["modo"]), reg2, w2.limbico.regolazione])
	quit(0)
