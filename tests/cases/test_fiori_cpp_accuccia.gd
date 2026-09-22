extends RefCounted
## ⚠️ **I 380 FIORI SELVATICI DEL C++ SI ACCUCCIANO ANCHE LORO.**
##
## `CozyWorld.flatten_cell` accuccia l'erba (`_grass_cells`) e i fiori del
## PRATO (`_flower_cells`) — è il difetto già pagato una volta, quello delle
## «margherite alte 22 cm che spuntano dal parquet, dentro le case, sotto i
## tappeti». Ma le popolazioni di fiori sono **TRE**, non due: ci sono anche i
## 380 selvatici di `EcosystemManager`, alti fino a **23,5 cm**, sparsi
## esattamente nell'area costruibile (il prato del manager va da (−13, −13,5)
## a (13, 12)), e di quelli nessuno sapeva niente: in tutto il C++ e in
## `Ecosystem.gd` la parola «accuccia» non compariva.
##
## ⚠️ **E LA GUARDIA NON RILEGGE IL MULTIMESH.** In `--headless`
## `MultiMesh.get_instance_transform()` torna l'IDENTITÀ (il renderer fittizio
## non conserva il buffer): un banco che leggesse di lì misurerebbe la propria
## cecità, ed è la trappola che questo progetto ha già pagato una volta.
## `debug_trasf_fiore` chiama `trasf_fiore`, cioè **la stessa funzione che
## scrive nel MultiMesh** — un secondo chiamante, non una ri-implementazione.


func run(t) -> void:
	if not ClassDB.class_exists("EcosystemManager"):
		t.ok(false, "EcosystemManager non registrata: la GDExtension non è caricata")
		return
	var m = ClassDB.instantiate("EcosystemManager")
	if not m.has_method("accuccia_cella"):
		t.ok(false, "EcosystemManager non espone «accuccia_cella»: i fiori del C++ non si accucciano")
		m.free()
		return
	_i_fiori_si_schiacciano(t, m)
	m.free()


func _i_fiori_si_schiacciano(t, m) -> void:
	# il prato vero del gioco (`Ecosystem.gd:45`), e i fiori si POSANO invece
	# di aspettare che il prato li semini: la semina passa dal
	# `_physics_process`, che qui non gira, e un banco che aspettasse
	# misurerebbe il proprio prato vuoto. `load_state` è la porta vera del
	# salvataggio — gli stessi byte che rientrano quando si riapre la partita.
	m.set_meadow(Vector3(-13, 0, -13.5), Vector3(13, 0, 12))
	m.set_pond(Vector3(9.5, 0.0, -10.5), 3.6)
	var wf: Array = []
	for c in [[4, 5], [4, 5], [4, 5], [-2, 7], [8, -3]]:
		wf.append([float(c[0]) + 0.1, float(c[1]) - 0.1, 1.0, 0])
	m.load_state({"wf": wf})
	var n: int = int(m.debug_quanti_fiori())
	t.ok(n > 0, "il prato ha seminato dei fiori selvatici (%d)" % n)
	if n == 0:
		return

	# si prende la cella con più fiori dentro, e si misura PRIMA
	var per_cella := {}
	for i in n:
		var d: Dictionary = m.debug_trasf_fiore(i)
		var p: Vector3 = d["pos"]
		var c := Vector2i(roundi(p.x), roundi(p.z))
		if not per_cella.has(c):
			per_cella[c] = []
		(per_cella[c] as Array).append(i)
	var scelta := Vector2i(0, 0)
	var quanti := 0
	for c in per_cella:
		if (per_cella[c] as Array).size() > quanti:
			quanti = (per_cella[c] as Array).size()
			scelta = c
	t.ok(quanti > 0, "c'è almeno una cella con dei fiori (%s, %d)" % [scelta, quanti])

	var prima: Array = []
	for i in (per_cella[scelta] as Array):
		prima.append(float((m.debug_trasf_fiore(int(i)) as Dictionary)["alto"]))
	for h in prima:
		t.ok(float(h) > 0.2, "PREMESSA: il fiore sta in piedi (%.4f)" % float(h))

	# il giocatore posa un pavimento su quella cella
	m.accuccia_cella(scelta.x, scelta.y)

	for k in (per_cella[scelta] as Array).size():
		var i: int = int((per_cella[scelta] as Array)[k])
		var d: Dictionary = m.debug_trasf_fiore(i)
		t.ok(bool(d["accucciato"]), "il fiore %d sa di essere sotto qualcosa" % i)
		t.ok(float(d["alto"]) < float(prima[k]) * 0.1,
				("…e si è schiacciato: %.4f → %.4f")
						% [float(prima[k]), float(d["alto"])])

	# ⚠️ LA CONTROPROVA: i fiori delle ALTRE celle non si muovono di un bit,
	# o «si accuccia» sarebbe «si accuccia tutto il prato».
	var toccati := 0
	for c in per_cella:
		if c == scelta:
			continue
		for i in (per_cella[c] as Array):
			var d: Dictionary = m.debug_trasf_fiore(int(i))
			if bool(d["accucciato"]) or float(d["alto"]) < 0.2:
				toccati += 1
	t.eq(toccati, 0,
			"e nessun fiore delle altre celle si è mosso (%d celle intatte)"
					% (per_cella.size() - 1))
