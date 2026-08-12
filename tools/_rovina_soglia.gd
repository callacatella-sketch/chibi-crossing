extends SceneTree

## BANCO TEMPORANEO (lente «rovina») — LA SOGLIA CHE NON COMBACIA.
##
## Senza modello, senza villaggio: un `EcsMondo` nudo, un ricordo che
## invecchia, e le quattro porte della deduzione interrogate una per una.
##
##   Godot --headless --path . --script res://tools/_rovina_soglia.gd

const SUG := preload("res://scenes/npc/Suggeritore.gd")
const GIU := preload("res://scenes/npc/Giudice.gd")

const SOGLIA := 0.35   # Visitors.AMMIRA_SOGLIA


func _init() -> void:
	if not ClassDB.class_exists("EcsMondo"):
		print("serve la GDExtension")
		quit(1)
		return
	print("un ricordo solo, che invecchia. soglia del villaggio = %.2f\n" % SOGLIA)
	print("%7s %8s %10s %13s %16s %s" % ["eta(s)", "peso", "in fatti?", "grammatica?",
			"Giudice.utile?", "deduci()"])
	for eta in [5, 60, 120, 180, 240, 300, 420, 600]:
		var m = ClassDB.instantiate("EcsMondo")
		var id = m.call("registra", PackedStringArray(["curioso"]), "canta_alla_luna")
		var v = m.call("indice_verbo", "annaffia")
		var nessuno = int((m.call("debug_grafo_costanti") as Dictionary).get("nessuno",
				4294967295))
		m.call("osserva", id, v, Vector3(5, 0, 7), nessuno)
		# il tempo avanza come nel gioco: `avanza(delta, ora)`, 60 Hz
		for _k in int(eta * 60):
			m.call("avanza", 1.0 / 60.0, 0.42)
		var rit: Dictionary = SUG.ritratto(m, id, {
			"nome": "la volpina Papavero", "eta": "giovane",
			"indole": ["curioso"], "quirk": "canta_alla_luna",
			"casa": Vector3(4, 0, 6), "azione": "gironzola", "obiettivo": "",
		}, {"protagonista": "Mochi", "nomi": {}, "compito": "pensiero",
			"stagione": "primavera", "momento": "pomeriggio", "ciclo": 240.0})
		var f: Array = SUG.fatti(rit)
		var pesi = rit.get("pesi", [])
		var peso: float = float(pesi[0]) if pesi.size() > 0 else -1.0
		var nei_fatti := false
		for x in f:
			if int((x as Dictionary)["riga"]) == 0:
				nei_fatti = true
		var gram := SUG.grammatica_deduzione(rit)
		var offerta := gram.contains("\"0\"")
		var utile: Dictionary = GIU.utile({"obiettivo": "provvedi_cura", "perche": [0]},
				rit, {})
		var i := -1
		if nei_fatti:
			i = int(m.call("deduci", id, int(m.call("maschera_obiettivo", "provvedi_cura")),
					PackedInt32Array([0]), SOGLIA))
		print("%7d %8.3f %10s %13s %16s %s" % [eta, peso,
				("sì" if nei_fatti else "no"), ("sì" if offerta else "no"),
				("sì" if bool(utile["ok"]) else "NO"),
				("entra (i=%d)" % i) if i >= 0 else "RIFIUTATA (sotto soglia)"])
		m.free()
	quit(0)
