extends RefCounted
## ⚠️ **LA PLATEA NON SVANISCE A METÀ BRANO.**
##
## `corpo_libero` è l'UNICA protezione di `passo_sonno` contro il mandare a
## letto qualcuno che sta recitando una scena, e il cablaggio lo calcolava come
## «lo stato è fra gli interrompibili». Ma quella lista contiene proprio gli
## stati in cui gli undici sistemi a evento **parcheggiano** i corpi: `r_bench`
## (il pianista e la platea del Concerto, il cliente del Salone), `r_sniff` (il
## raduno del lutto, il Concertino, il Nascondino), `r_fire` (il falò).
##
## Il Concerto va da 0,72 a 0,92; la finestra di sonno di chi non è nottambulo
## apre a **0,80**. A quel punto `passo_sonno` diceva DORME — e
## `Visitor.resident_sleep()` **non manda nessuno a casa a piedi**: rimpicciolisce
## il corpo a scala 0,03 dov'è. La platea non se ne andava: **svaniva dalla
## gradinata**, per gli ultimi 28,8 secondi reali di una serata da 48.
##
## ⚠️ E la valvola guarda `in_scena()`, **non il lease**: `next_act` è positivo
## quasi sempre (la routine ne scrive 0,4–1,8 s a ogni fronte), quindi metterlo
## lì vorrebbe dire che non dorme più nessuno — la controprova qui sotto è
## esattamente quella.
const DNA := preload("res://scenes/npc/ChibiDNA.gd")


class Registro extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _process(_d: float) -> void:
		pass
	func _leggi_ambiente() -> Dictionary:
		return {"luce": 0.2, "pioggia": 0.0, "temperatura": 18.0}


func run(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	_chi_recita_non_va_a_letto(t)


func _villaggio(t) -> Dictionary:
	var casa := Node3D.new()
	casa.name = "VillaggioScene"
	t.stage(casa)
	var vis = Registro.new()
	vis.name = "Visitors"
	casa.add_child(vis)
	return {"casa": casa, "vis": vis}


func _abita(t, casa: Node, vis, label: String, seme: int) -> Node3D:
	var v := Node3D.new()
	v.set_script(preload("res://scenes/npc/Visitor.gd"))
	casa.add_child(v)
	v.set("dna", DNA.generate(seme))
	v.set("mode", "resident")
	v.set_process(false)
	v.set("_state", "r_bench")       # seduto: il pubblico del Concerto
	(vis.get("_residents") as Array).append({
		"label": label, "cell": Vector2i(0, 0), "species": "chibi",
		"node": v, "dna": v.get("dna")})
	return v


func _chi_recita_non_va_a_letto(t) -> void:
	var w := _villaggio(t)
	var vis = w["vis"]
	# due corpi identici, seduti allo stesso modo: uno dentro una scena
	# dichiarata, l'altro no. È l'unica forma che sa distinguere «non dorme
	# perché recita» da «non dorme e basta».
	var suona := _abita(t, w["casa"], vis, "S", 4141)
	var passa := _abita(t, w["casa"], vis, "P", 4242)
	suona.call("apri_scena", 60.0)
	t.ok(bool(suona.call("in_scena")), "PREMESSA: il primo è dentro una scena")
	t.ok(not bool(passa.call("in_scena")), "…e il secondo no")

	# l'ora è dentro la finestra di sonno di chiunque
	for _i in 8:
		vis.call("_ciclo_sonno", 0.5, 0.95)

	t.ok(not bool(suona.call("is_hidden")),
			"chi sta recitando NON svanisce dal palco a metà scena")
	t.ok(bool(passa.call("is_hidden")),
			"…e chi non recita va a dormire come sempre: la valvola è stretta")

	# ⚠️ **E LA VALVOLA NON È IL LEASE.** `next_act` è positivo quasi sempre —
	# la routine ne scrive 0,4–1,8 s a ogni fronte di fase — quindi una
	# valvola su di lui vorrebbe dire che **non dorme più nessuno**. Un terzo
	# corpo, col lease pieno e senza scena, deve andare a letto lo stesso:
	# senza questa riga, scambiare `in_scena()` con `next_act > 0` resterebbe
	# verde.
	var col_lease := _abita(t, w["casa"], vis, "L", 4343)
	for r in (vis.get("_residents") as Array):
		if str((r as Dictionary).get("label", "")) == "L":
			(r as Dictionary)["next_act"] = 9999.0
	for _i in 8:
		vis.call("_ciclo_sonno", 0.5, 0.95)
	t.ok(bool(col_lease.call("is_hidden")),
			"chi ha solo un lease lungo va a dormire: la valvola è la SCENA, "
			+ "non il lease")

	# ⚠️ e appena la scena finisce, la dormita arriva: è RIMANDATA, non abolita
	suona.call("chiudi_scena") if suona.has_method("chiudi_scena") else suona.call("apri_scena", 0.0)
	for _i in 8:
		vis.call("_ciclo_sonno", 0.5, 0.95)
	t.ok(bool(suona.call("is_hidden")),
			"e finita la serata va a dormire anche lui: rimandata, non abolita")
