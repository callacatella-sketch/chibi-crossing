extends RefCounted
## LE SEDUTE: chi si siede deve dare le spalle allo schienale.
##
## Non è una finezza: girare lo schienale di un pezzo (è successo alla
## Sedia e al Letto, che ce l'avevano davanti e nella foto del catalogo
## mostravano un pannello cieco) NON fa fallire niente — il pezzo si
## costruisce, si piazza, la suite resta verde — e in partita Mochi si
## siede col muso dentro le doghe, o dorme coi piedi sul cuscino.
##
## Perciò qui lo schienale non è dichiarato: si MISURA, costruendo il
## pezzo vero e guardando dove sta la massa in alto.

const CAT = preload("res://scenes/build/BuildCatalog.gd")
const INT = preload("res://scenes/interact/Interactions.gd")


func _costruisci(nome: String) -> Node3D:
	for v in CAT.items():
		if str(v["name"]) == nome:
			return (v["builder"] as Callable).call()
	return null


# la trasformazione di una mesh rispetto alla radice, senza albero
func _rel(root: Node, n: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c := n
	while c != null and c != root:
		t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


## Dove sta lo schienale: la z media della roba che sta in alto. 0 se non
## c'è (lo Sgabello non ha schienale, e va bene così).
func _schienale_z(root: Node3D) -> float:
	var somma := 0.0
	var quanti := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var p := _rel(root, mi).origin
		if p.y > 0.60:
			somma += p.z
			quanti += 1
	return 0.0 if quanti < 3 else somma / float(quanti)


func run(t) -> void:
	for kind in INT.SEATS.keys():
		# DUE FAMIGLIE DI SEDUTE, e si controllano in modo diverso.
		# «Posto» non è un pezzo: è l'ANCORAGGIO DICHIARATO che i pezzi
		# grandi (Gazebo, Serra) mettono dove ci si siede davvero — il
		# punto è già quello giusto e il verso ce l'ha addosso l'ancoraggio,
		# perché solo chi costruisce il pezzo sa dov'è il tavolo. Cercarlo
		# nel catalogo non avrebbe senso: qui si controlla il suo patto.
		if kind == "Posto":
			t.ok((INT.SEATS[kind] as Vector3).length() < 0.001,
					"il posto dichiarato non sposta nessuno: l'ancoraggio È il posto")
			t.almost(INT.yaw_seduta(kind, 1.3), 1.3,
					"…e il suo verso non si gira di mezzo giro: chi si siede"
					+ " guarda il tavolo, non gli dà le spalle", 1e-6)
			continue
		var root := _costruisci(kind)
		t.ok(root != null, "il pezzo %s esiste nel catalogo" % kind)
		if root == null:
			continue
		var schiena := _schienale_z(root)
		var posto: Vector3 = INT.SEATS[kind]
		if absf(schiena) > 0.05:
			# il posto sta dalla parte opposta allo schienale
			t.ok(schiena * posto.z < 0.0,
					"%s: il posto (z=%+.2f) è dalla parte opposta allo schienale (z=%+.2f)"
					% [kind, posto.z, schiena])
			# e chi si siede GUARDA dalla parte opposta allo schienale:
			# il rig di Mochi guarda -Z, quindi a yaw 0 la direzione è -Z
			var yaw: float = INT.yaw_seduta(kind, 0.0)
			var sguardo := Vector3(-sin(yaw), 0, -cos(yaw))
			t.ok(sguardo.z * schiena < 0.0,
					"%s: seduta, guarda via dallo schienale (yaw %.2f)" % [kind, yaw])
			# e la rotazione del pezzo si porta dietro lo sguardo
			t.almost(INT.yaw_seduta(kind, 1.3), yaw + 1.3,
					"%s: il verso ruota col pezzo" % kind, 1e-6)
		else:
			t.ok(absf(posto.z) < 0.05,
					"%s: senza schienale, il posto sta in mezzo" % kind)
		root.free()
