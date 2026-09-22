extends RefCounted
## ⚠️ UN RESIDENTE IL CUI LETTO NON C'È PIÙ SPARIVA IN SILENZIO.
##
## `Visitors.load_extra` cercava il Letto sulla cella salvata con un
## `for … break` **senza `else`**: se nessun letto stava lì, la riga veniva
## saltata e basta. E siccome `save_extra` scrive soltanto `_residents`, al
## salvataggio successivo quella persona **non esisteva più** — con il suo
## animo, il suo libro mastro, i suoi ricordi e il suo Filo Rosso. Bastava
## demolire un letto per cancellare qualcuno, e il gioco non lo diceva a
## nessuno.
##
## Il commento di allora («il letto deve esistere ancora, altrimenti il
## villager è partito») dichiarava l'intento — ma «è partito», in questo
## gioco, è una SCENA: il congedo, la lettera, il filo che si accorcia. Non
## una riga che sparisce da un array.
##
## La cura è la domanda che il villaggio sa già fare (`_free_house`, lo
## stesso che usa chi arriva): **c'è un altro letto libero e coperto?** Se sì
## ci si trasloca e non si perde niente; se no si scarta, ma **lo si
## scrive**, col nome e con la cella.
##
## ⚠️ QUESTO BANCO NON APRE IL MAINLEVEL: fa girare `load_extra` VERA su un
## `Visitors` vero con un BuildSystem finto che dice solo DOVE sono i letti
## (un dato, non una decisione — la lezione del doppio che re-implementa
## quel che si prova).

const VISITORS := preload("res://scenes/npc/Visitors.gd")
## ⚠️ IL GENOMA DEVE ESSERE INTERO: `ChibiBuilder.build()` non si accontenta
## di `{"name": …}` e con un genoma parziale il corpo non si costruisce
## affatto — e un errore a runtime NON fa fallire un test, lo interrompe.
const DNA := preload("res://scenes/npc/ChibiDNA.gd")


class FintoBuild extends Node3D:
	var letti: Array = []
	var coperte := {}      # Vector2i -> bool

	func get_placed_by_name(nome: String) -> Array:
		return letti if nome == "Letto" else []

	func has_cover(cell: Vector2i) -> bool:
		return bool(coperte.get(cell, true))

	func raggiungibile(_a: Vector2i, _b: Vector2i) -> bool:
		return true

	## ⚠️ IL FINTO DEVE RISPONDERE A TUTTO QUELLO CHE IL CAMMINO VERO CHIEDE,
	## o l'errore a runtime interrompe `load_extra` a meta' e il banco misura
	## un caricamento troncato credendolo intero.
	func request_save() -> void:
		pass


func run(t) -> void:
	_si_trasloca_se_c_e_posto(t)
	_senza_nessun_letto_si_scarta(t)


func _letto(padre: Node, x: int, z: int) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(float(x), 0.0, float(z))
	padre.add_child(n)
	return n


## Il letto salvato non c'è più, ma un altro sì: la persona si TRASLOCA, e
## il suo dizionario (animo compreso) resta intero.
func _si_trasloca_se_c_e_posto(t) -> void:
	var albero := Node3D.new()
	var v = VISITORS.new()
	var b := FintoBuild.new()
	albero.add_child(b)
	albero.add_child(v)
	Engine.get_main_loop().root.add_child(albero)

	# un solo letto, e NON dove il residente era salvato
	b.letti = [_letto(b, 7, 7)]
	v.set("_build", b)
	v.load_extra({"residents": [{
		"sp": "chibi", "x": 2, "z": 3, "label": "L_prova",
		"dna": _genoma("Prova"), "animo": {"oggi": 9},
	}]})

	var res: Array = v.get("_residents")
	t.eq(res.size(), 1,
			"il residente non sparisce: si trasloca nel letto libero")
	if res.size() == 1:
		var r: Dictionary = res[0]
		t.eq(Vector2i(r["cell"]), Vector2i(7, 7),
				"e la sua cella è quella del letto nuovo")
		t.eq(str(r.get("label", "")), "L_prova", "la label se la porta dietro")
		t.eq(int((r.get("animo", {}) as Dictionary).get("oggi", -1)), 9,
				"e l'animo salvato NON si perde — è metà del motivo di questa cura")
	albero.queue_free()


## Nessun letto in tutto il villaggio: si scarta (è l'intento dichiarato),
## ma la controprova è che il ramo del trasloco non abbia inghiottito il
## caso — cioè che qui NON venga inventata una casa dal niente.
func _senza_nessun_letto_si_scarta(t) -> void:
	var albero := Node3D.new()
	var v = VISITORS.new()
	var b := FintoBuild.new()
	albero.add_child(b)
	albero.add_child(v)
	Engine.get_main_loop().root.add_child(albero)

	b.letti = []
	v.set("_build", b)
	v.load_extra({"residents": [{
		"sp": "chibi", "x": 2, "z": 3, "label": "L_prova",
		"dna": _genoma("Prova"),
	}]})
	t.eq((v.get("_residents") as Array).size(), 0,
			"senza nessun letto non si inventa una casa")
	albero.queue_free()


func _genoma(nome: String) -> Dictionary:
	var d: Dictionary = DNA.generate(abs(hash(nome))).duplicate()
	d["name"] = nome
	return d
