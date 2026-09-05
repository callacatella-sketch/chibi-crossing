extends SceneTree
const ANIMO := preload("res://scenes/npc/Animo.gd")
const RIL := preload("res://scenes/npc/Rilettura.gd")

func _nuovo(cod := 0.5, lea := 0.5) -> RefCounted:
	var a: RefCounted = ANIMO.new()
	a.setup({"name": "Prova", "seed": 7,
		"tratti": {"orgoglio": 0.5, "lealta": lea, "grinta": 0.5,
			"codardia": cod, "ambizione": 0.5}, "sogno": "guerriero"})
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
	print("══ IL CASO PEGGIORE: un piatto E un lavoro odiato ogni giorno")
	for giorni in [40, 60, 80, 100, 140]:
		var a := _nuovo()
		for g in giorni:
			a.ricorda("piatto", "giocatore", 0.85, 0.9)
			a.esegue("taglia_legna", "giocatore")
			a.passa_giorno()
		var c: Dictionary = a.conto_verso("giocatore")
		var rd := _r(float(c["torti"]), float(c["prove"]))
		var rp := _r(float(c["torti"]), _prove_vive(a))
		print("   g.%-4d torti %.2f prove %.2f/%.2f  rancore %.4f/%.4f  GRADINO %s / %s%s"
				% [giorni, float(c["torti"]), float(c["prove"]), _prove_vive(a),
				rd, rp, _grad(a, rd), _grad(a, rp),
				"   ←── DIVERSO" if _grad(a, rd) != _grad(a, rp) else ""])

	print("")
	print("══ IL DIVARIO: quante volte in queste storie e' <= 0 ?")
	var zero := 0
	var tot := 0
	for giorni in [10, 25, 40, 60, 100]:
		for piatti in [0, 1, 3, 10, 25]:
			var a := _nuovo()
			for g in giorni:
				if g < piatti:
					a.ricorda("piatto", "giocatore", 0.85, 0.9)
				a.esegue("taglia_legna", "giocatore")
				if g == giorni / 2:
					a.lutto("Nocciola")
				a.passa_giorno()
			var c: Dictionary = a.conto_verso("giocatore")
			var d: float = a.limbico.divario("giocatore", float(c["media_prove"]))
			tot += 1
			if d <= 0.0:
				zero += 1
	print("   divario <= 0 in %d storie su %d" % [zero, tot])
	print("   (e quando e' 0 le prove sono 0, cioe' il rapporto lo boccia gia')")

	print("")
	print("══ IL CONTRATTO DI peso_prova")
	print("   peso_prova(55.44, 1.0, 1.0) = %.4f  ← un `peso` di sommario"
			% RIL.peso_prova(55.44, 1.0, 1.0))
	print("   se un domani qualcuno ci mettesse clampf(valenza,-1,1): %.4f"
			% RIL.peso_prova(clampf(55.44, -1.0, 1.0), 1.0, 1.0))

	print("")
	print("══ IL DOPPIO RICALCOLO (misurato sulla funzione vera)")
	var q := _nuovo()
	for g in 60:
		q.ricorda("piatto", "giocatore", 0.85, 0.9)
		q.esegue("taglia_legna", "giocatore")
		q.passa_giorno()
	print("   sommario %d chiavi · ricordi %d" % [q.sommario.size(), q.ricordi.size()])
	var t0 := Time.get_ticks_usec()
	for i in 200:
		q._deriva_giorno = -1
		q._ricalcola_deriva()
	var t1 := Time.get_ticks_usec()
	print("   _ricalcola_deriva(): %.1f µs → in _ensure_brain e nel giro giornaliero"
			% ((t1 - t0) / 200.0))
	print("   sono DUE per residente: 28 residenti = %.2f ms in UN frame"
			% (2.0 * 28.0 * (t1 - t0) / 200.0 / 1000.0))
	quit(0)
