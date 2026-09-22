extends RefCounted
## DUE RESIDENTI NON POSSONO STARE SULLA STESSA CELLA.
##
## In questo villaggio **la cella è la chiave di unicità del letto**:
## `Visitors.load_extra` scarta ogni riga la cui cella è già presa. Due righe
## con la stessa cella quindi non fanno un guasto che si vede subito — fanno
## un residente che SPARISCE al caricamento dopo, senza un errore.
##
## ⚠️ **E c'era una finestra in cui succedeva.** `is_bed_claimed` scorreva
## solo `_residents`, ma fra `_spawn_candidate` (che assegna una casa) e
## `_decide` (che mette il candidato in `_residents`) passano secondi veri: in
## quella finestra il letto risultava LIBERO. `accogli_nato()` — la NASCITA —
## chiama `_free_house()` senza guardare nessuno, e poteva prendersi proprio
## quel letto; poi `_decide` accodava comunque, perché prima di accodare
## controllava solo che il letto ESISTESSE ancora.
##
## È la stessa catastrofe che il commento sopra `accogli_nato` racconta di
## aver già pagato, entrata da un'altra porta.
const DNA := preload("res://scenes/npc/ChibiDNA.gd")

const LETTO_A := Vector2i(3, 3)
const LETTO_B := Vector2i(9, 3)


class Registro extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)


## Il MONDO, non il comportamento: dice dove sono i letti e se hanno un
## tetto. `_free_house` resta quella del gioco.
class FintoBuild extends Node3D:
	var letti: Array[Node3D] = []
	func get_placed_by_name(nome: String) -> Array:
		return letti if nome == "Letto" else []
	func has_cover(_c: Vector2i) -> bool:
		return true


## Il candidato sull'uscio: ha già la sua casa e NON è ancora in `_residents`.
class FintoCandidato extends Node3D:
	var mode := "candidate"
	var _house := {}


func run(t) -> void:
	_test_il_letto_promesso_non_e_libero(t)


func _villaggio(t) -> Dictionary:
	var casa := Node3D.new()
	casa.name = "VillaggioLetti"
	t.stage(casa)
	var build := FintoBuild.new()
	build.name = "BuildSystem"
	casa.add_child(build)
	for cella: Vector2i in [LETTO_A, LETTO_B]:
		var letto := Node3D.new()
		build.add_child(letto)
		letto.position = Vector3(cella.x, 0, cella.y)
		build.letti.append(letto)
	var vis = Registro.new()
	vis.name = "Visitors"
	casa.add_child(vis)
	vis.set("_build", build)
	return {"casa": casa, "vis": vis, "build": build}


func _test_il_letto_promesso_non_e_libero(t) -> void:
	var v := _villaggio(t)
	var vis = v["vis"]

	t.ok(not bool(vis.call("is_bed_claimed", LETTO_A)),
			"a villaggio vuoto nessun letto è preso")

	# arriva un candidato: gli viene promesso LETTO_A, e sta sull'uscio
	var cand := FintoCandidato.new()
	cand._house = {"cell": LETTO_A, "bed": (v["build"] as Node3D).get_child(0)}
	(v["casa"] as Node).add_child(cand)
	vis.set("_active", cand)

	t.ok(bool(vis.call("is_bed_claimed", LETTO_A)),
			"il letto promesso al candidato NON è libero")
	var libera: Dictionary = vis.call("_free_house")
	t.ok(not libera.is_empty(), "una casa libera c'è ancora")
	t.eq(libera.get("cell"), LETTO_B,
			"…ed è l'ALTRA: la nascita non si porta via il letto del candidato")

	# ⚠️ e la domanda di `_decide` è un'altra: «me l'ha preso qualcun ALTRO?»
	t.ok(not bool(vis.call("is_bed_claimed", LETTO_A, false)),
			"il candidato non si vede rifiutare il proprio letto")

	# un residente vero lo prende in tutti e due i modi di chiedere
	(vis.get("_residents") as Array).append({
		"species": "chibi", "label": "il gattino Uno", "cell": LETTO_B,
		"dna": {"name": "Uno"}, "node": null})
	t.ok(bool(vis.call("is_bed_claimed", LETTO_B)),
			"il letto di un residente è preso")
	t.ok(bool(vis.call("is_bed_claimed", LETTO_B, false)),
			"…e lo è anche per chi sta decidendo")
	t.ok((vis.call("_free_house") as Dictionary).is_empty(),
			"e adesso non c'è più nessuna casa libera")
