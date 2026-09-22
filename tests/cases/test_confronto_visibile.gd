extends RefCounted
## ⚠️ **IL CONFRONTO NON SI CONSUMA SU CHI NON SI VEDE.**
##
## Lo sfogo è il momento più drammatico della scala della ribellione: il vicino
## ti viene incontro, si ferma a due passi, ti guarda in faccia e te lo dice.
## Succede **una volta sola** — `r["sfogato"]` resta acceso finché non gli dai
## di nuovo il motivo.
##
## ⚠️ E `_tick_confronti` non guardava né `is_hidden()`, né `dorme()`, né
## `in_scena()`. Di notte `resident_sleep()` **non sposta il corpo**: lo
## rimpicciolisce a scala 0,03 e lo nasconde, ma la posizione resta sulla cella
## di casa. Passando accanto a una casa al buio partiva tutto — toast,
## nuvoletta, `petto_in_fuori` — addosso a un corpo invisibile, e il latch
## restava acceso: **la scena si spendeva su uno schermo nero e non tornava.**
const ANIMO := preload("res://scenes/npc/Animo.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")


class Registro extends "res://scenes/npc/Visitors.gd":
	var toast: Array = []
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _process(_d: float) -> void:
		pass
	func _show_toast(txt: String) -> void:
		toast.append(txt)


func run(t) -> void:
	_non_ci_si_sfoga_al_buio(t)


func _scena(t, nascosto: bool) -> Dictionary:
	var casa := Node3D.new()
	casa.name = "VillaggioConfronto"
	t.stage(casa)
	var mochi := Node3D.new()
	casa.add_child(mochi)
	mochi.global_position = Vector3.ZERO
	var vis = Registro.new()
	vis.name = "Visitors"
	casa.add_child(vis)
	vis.set("_player", mochi)

	var corpo := Node3D.new()
	corpo.set_script(preload("res://scenes/npc/Visitor.gd"))
	casa.add_child(corpo)
	corpo.set("dna", DNA.generate(5555))
	corpo.set("mode", "resident")
	corpo.set_process(false)
	corpo.global_position = Vector3(0, 0, 1.0)     # addosso: entro i 2,2 m
	if nascosto:
		corpo.set("_hidden", true)                 # è dentro casa, a dormire

	var animo = ANIMO.new()
	animo.setup({"name": "Furente", "tratti": {}, "sogno": "guerriero"})
	# lo si porta sopra il gradino del confronto, con la scala vera
	for g in 80:
		animo.esegue("taglia_legna")
		animo.aggiorna_scala()
		animo.passa_giorno()
	var r := {"label": "F", "cell": Vector2i(0, 0), "species": "chibi",
			"node": corpo, "dna": corpo.get("dna")}
	(vis.get("_residents") as Array).append(r)
	(vis.get("_animi") as Dictionary)["F"] = animo
	return {"vis": vis, "r": r, "animo": animo, "corpo": corpo}


func _non_ci_si_sfoga_al_buio(t) -> void:
	# --- 1) IN SCENA, di giorno: lo sfogo deve succedere (o il caso 2 non
	#        distinguerebbe «non si vede» da «non è arrabbiato abbastanza»)
	var v := _scena(t, false)
	t.ok(ANIMO.almeno(int((v["animo"] as RefCounted).gradino), "confronto"),
			"PREMESSA: è salito almeno fino al confronto")
	(v["vis"] as Node).call("_tick_confronti", 0.1)
	t.ok(bool((v["r"] as Dictionary).get("sfogato", false)),
			"alla luce del sole si sfoga")
	t.ok(((v["vis"] as Node).get("toast") as Array).size() > 0,
			"…e il giocatore lo legge")

	# --- 2) NASCOSTO dentro casa: niente, e il latch resta pulito
	var w := _scena(t, true)
	t.ok(bool((w["corpo"] as Node3D).call("is_hidden")), "PREMESSA: è nascosto")
	(w["vis"] as Node).call("_tick_confronti", 0.1)
	t.ok(not bool((w["r"] as Dictionary).get("sfogato", false)),
			"al buio lo sfogo NON si consuma: il latch resta pulito")
	t.eq(((w["vis"] as Node).get("toast") as Array).size(), 0,
			"e non arriva nessun toast da qualcuno che non c'è")

	# --- 3) e appena torna in scena, lo sfogo arriva: non è perso, è rimandato
	(w["corpo"] as Node3D).set("_hidden", false)
	(w["vis"] as Node).call("_tick_confronti", 0.1)
	t.ok(bool((w["r"] as Dictionary).get("sfogato", false)),
			"e quando torna fuori te lo dice: la scena è rimandata, non persa")
