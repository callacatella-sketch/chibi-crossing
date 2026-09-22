extends RefCounted
## ⚠️ **IL FRONTE DI FASE NON SCIPPA IL CORPO A UNA SCENA.**
##
## Gli undici sistemi a evento di questo villaggio zittiscono l'agenda in un
## modo solo: scrivendo un lease lungo in `next_act` (9999 per il Concerto, il
## Congedo, le Promesse, la Veglia; 45 s per l'Accompagnare). `_routine`
## però, sul FRONTE di fase, riassegnava quel campo con un `=` nudo —
## `randf_range(0.4, 1.8)` — cioè **riportava a un secondo e mezzo un lease
## che valeva diecimila**, e l'agenda si riprendeva il corpo in mezzo alla
## scena.
##
## E non è raro: `_phase()` cambia a `t = 0,28 · 0,42 · 0,66 · 0,82`, quattro
## volte per giornata di gioco — una ogni minuto reale — mentre un concerto
## dura 48 secondi e un accompagnamento 45.
##
## La regola sta scritta nel progetto e vale da anni: *«si alza il lease,
## prima che il motore decida, e solo con `maxf`»*. Qui il rimedio è stretto a
## chi è **in scena**: per tutti gli altri il lease resta quello di ieri, al
## bit, e le misure già prese su quel numero restano valide.
const DNA := preload("res://scenes/npc/ChibiDNA.gd")


class Registro extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

	func _process(_d: float) -> void:
		pass


## Un cielo che si può spostare a mano da una fase all'altra.
## ⚠️ `Node3D` e non `Node`: `Visitors._daynight` è TIPIZZATO, e un `set()`
## col tipo sbagliato **non assegna e non dice niente** — il banco misurerebbe
## un villaggio senza cielo credendo di avergliene dato uno. È la trappola già
## scritta per il finto BuildSystem di `test_insieme`.
class FintoGiorno extends Node3D:
	var time := 0.35          # «morning»
	func is_night() -> bool:
		return false


func run(t) -> void:
	_il_fronte_non_scippa_una_scena(t)


func _villaggio(t) -> Dictionary:
	var casa := Node3D.new()
	casa.name = "VillaggioFasi"
	t.stage(casa)
	var giorno := FintoGiorno.new()
	giorno.name = "DayNight"
	casa.add_child(giorno)
	var vis = Registro.new()
	vis.name = "Visitors"
	casa.add_child(vis)
	vis.set("_daynight", giorno)
	return {"casa": casa, "vis": vis, "giorno": giorno}


func _corpo(t, seme: int, casa: Node) -> Node3D:
	var v := Node3D.new()
	v.set_script(preload("res://scenes/npc/Visitor.gd"))
	casa.add_child(v)
	v.set("dna", DNA.generate(seme))
	v.set("mode", "resident")
	v.set_process(false)
	return v


func _il_fronte_non_scippa_una_scena(t) -> void:
	var w := _villaggio(t)
	var vis = w["vis"]
	var giorno = w["giorno"]

	var in_scena := _corpo(t, 101, w["casa"])
	var libero := _corpo(t, 202, w["casa"])
	# la scena prende il corpo, con l'idioma vero dei sistemi a evento
	in_scena.call("apri_scena", 30.0)
	t.ok(bool(in_scena.call("in_scena")), "il primo è dentro una scena")
	t.ok(not bool(libero.call("in_scena")), "il secondo no")

	for c in [["S", in_scena], ["L", libero]]:
		(vis.get("_residents") as Array).append({
			"label": str(c[0]), "cell": Vector2i(0, 0), "species": "chibi",
			"node": c[1], "dna": (c[1] as Node3D).get("dna"),
			"phase": "day", "next_act": 9999.0})

	# il confine di fase: da «day» a «morning»
	giorno.time = 0.35
	vis.call("_routine", 1.0 / 60.0)

	var res: Array = vis.get("_residents")
	t.ok(float(res[0]["next_act"]) > 100.0,
			("chi è in scena tiene il suo lease attraverso il fronte (%.1f)")
					% float(res[0]["next_act"]))
	# ⚠️ LA CONTROPROVA: per chi NON è in scena il fronte deve continuare a
	# rimescolare il lease come ha sempre fatto — se no la cura avrebbe
	# congelato l'agenda di tutto il villaggio invece di proteggere una scena.
	t.ok(float(res[1]["next_act"]) < 2.0,
			("e chi è libero se lo vede rimescolare come sempre (%.2f)")
					% float(res[1]["next_act"]))
	t.eq(str(res[0]["phase"]), "morning", "la fase avanza per tutti e due")
	t.eq(str(res[1]["phase"]), "morning", "…anche per chi è in scena")
