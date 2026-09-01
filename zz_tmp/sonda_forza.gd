extends SceneTree
## sonda usa-e-getta: l'aritmetica della strada veloce, senza villaggio.
const LIMBICO := preload("res://scenes/npc/Limbico.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")

func _init() -> void:
	print("=== L'AMICO (sei incontri felici, arrivo TRANQUILLO) ===")
	var a = LIMBICO.new()
	a.setup({})
	for i in 6:
		# è la porta vera: `_tick_riconoscimenti` chiama rivaluta("incontro","giocatore", 0.55)
		a.rivaluta("incontro", "giocatore", 0.55)
		print("  dopo %d: carica=%.3f arousal=%.3f umore=%.3f corpo=%s"
			% [i + 1, a.carica_di("", "giocatore"), a.arousal, a.umore, a.stato_corpo()])
	var s: Dictionary = a.percepisci("giocatore", "", 0.0)
	print("  PERCEPISCI (grezzo 0.0) -> %s forza=%.3f carica=%.3f"
		% [str(s["reazione"]), float(s["forza"]), float(s["carica"])])
	print("  arousal DOPO il percetto = %.3f  corpo=%s" % [a.arousal, a.stato_corpo()])
	print("  corpo_ha_da_dire (il saluto T) = %s" % str(VISITORS.corpo_ha_da_dire(a.stato_corpo())))

	print("")
	print("=== LO SCONOSCIUTO, caricato DI CORSA (6 m/s, giorno, addosso) ===")
	var b = LIMBICO.new()
	b.setup({})
	var grezzo := VISITORS.indizio_grezzo(6.0, 0.0, 1.0)
	var s2: Dictionary = b.percepisci("giocatore", "", grezzo)
	print("  grezzo=%.3f -> %s forza=%.3f" % [grezzo, str(s2["reazione"]), float(s2["forza"])])

	print("")
	print("=== LO SCONOSCIUTO, a passo di CAMMINATA (3 m/s, giorno, addosso) ===")
	for cod in [0.2, 0.5, 0.9]:
		var c = LIMBICO.new()
		c.setup({"codardia": cod, "grinta": 0.5})
		var g := VISITORS.indizio_grezzo(3.0, 0.0, 1.0)
		var s3: Dictionary = c.percepisci("giocatore", "", g)
		print("  codardia %.1f (react %.2f) grezzo=%.3f -> %-12s forza=%.3f  [carica 0!]"
			% [cod, c.reattivita, g, str(s3["reazione"]), float(s3["forza"])])

	print("")
	print("=== UN REGALO, e poi il saluto (la strada LENTA) ===")
	var d = LIMBICO.new()
	d.setup({})
	var e: Dictionary = d.rivaluta("regalo", "giocatore", 0.9)
	print("  sentito=%.3f arousal=%.3f -> corpo=«%s»  saluto scosso? %s"
		% [float(e["sentito"]), d.arousal, d.stato_corpo(),
		str(VISITORS.corpo_ha_da_dire(d.stato_corpo()))])

	print("")
	print("=== LA CODA SOMATICA a forza 0.726 (Gesti) ===")
	var G := load("res://scenes/npc/Gesti.gd")
	for t: float in [0.0, 0.17, 1.0, 3.0, 9.0, 20.0, 60.0, 74.0]:
		var amp: float = G.coda_ampiezza(0.726, t)
		var can: Dictionary = G.coda_canali(amp, t, 0.0)
		print("  t=%5.1f  amp=%.3f  ear=%+.3f  ax=%+.3f  tail=%+.3f  ritmo=%.3f"
			% [t, amp, float(can["ear"]), float(can["ax0"]), float(can["tail"]),
			G.soma_ritmo(0.726, t)])
	quit(0)
