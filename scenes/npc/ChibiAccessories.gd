class_name ChibiAccessories
extends RefCounted

## Il modulo accessori dei villager: ogni capo è un piccolo costruttore
## procedurale con il suo slot (testa, collo, viso). apply() legge il
## DNA e veste il chibi; un accessorio nuovo si aggiunge qui, senza
## toccare il builder. Convenzione: la faccia guarda verso -Z.

const BUILDER := preload("res://scenes/npc/ChibiBuilder.gd")

## Il guardaroba, per la generazione del DNA (nessuno pesato doppio).
const POOL := ["nessuno", "nessuno", "fiore", "fiocco", "sciarpina",
		"cappellino", "papillon", "occhialini"]


static func apply(dna: Dictionary, root: Node3D, head: Node3D) -> void:
	var hs: float = dna["head_scale"]
	match str(dna.get("acc", "nessuno")):
		"fiore": _fiore(head, dna, hs)
		"fiocco": _fiocco(head, dna, hs)
		"sciarpina": _sciarpina(root, dna)
		"cappellino": _cappellino(head, dna, hs)
		"papillon": _papillon(root, dna)
		"occhialini": _occhialini(head, dna, hs)


# ---------------------------------------------------------------- testa

static func _fiore(head: Node3D, dna: Dictionary, hs: float) -> void:
	var petal := BUILDER._mat(Color(dna["dress2"]))
	var base := Vector3(0.18 * hs, 0.33 * hs, -0.12)
	for i in 5:
		var a := float(i) / 5.0 * TAU
		BUILDER._ball(head, 0.034, petal,
				base + Vector3(cos(a) * 0.048, sin(a) * 0.048 * 0.4, cos(a * 2.0) * 0.012),
				Vector3(1, 1, 0.5))
	BUILDER._ball(head, 0.027, BUILDER._mat(Color("ffd76e")),
			base + Vector3(0, 0, -0.018), Vector3(1, 1, 0.6))


static func _fiocco(head: Node3D, dna: Dictionary, hs: float) -> void:
	var acc := BUILDER._mat(Color(dna["dress"]))
	var acc2 := BUILDER._mat(Color(dna["dress2"]))
	var base := Vector3(-0.17 * hs, 0.335 * hs, 0)
	for side: float in [-1.0, 1.0]:
		var loop := BUILDER._ball(head, 0.058, acc,
				base + Vector3(side * 0.058, 0.012, 0), Vector3(1.3, 0.78, 0.5))
		loop.rotation.z = side * 0.5
		# le codine del nastro che ricadono
		var ribbon := BUILDER._ball(head, 0.036, acc,
				base + Vector3(side * 0.05, -0.065, 0.01), Vector3(0.55, 1.5, 0.35))
		ribbon.rotation.z = side * -0.35
	BUILDER._ball(head, 0.031, acc2, base)


static func _cappellino(head: Node3D, dna: Dictionary, hs: float) -> void:
	# berrettina a cuffia con l'orlo arrotolato e il ponpon, appena storta
	var acc := BUILDER._mat(Color(dna["dress"]))
	var acc2 := BUILDER._mat(Color(dna["dress2"]))
	var hat := Node3D.new()
	hat.position = Vector3(0, 0.235 * hs, -0.03)
	hat.rotation = Vector3(0.1, 0, -0.09)
	head.add_child(hat)
	BUILDER.lathe(hat, [Vector2(0.205, 0.0), Vector2(0.218, 0.03),
			Vector2(0.205, 0.065), Vector2(0.175, 0.115), Vector2(0.12, 0.16),
			Vector2(0.055, 0.19), Vector2(0.0, 0.2)], acc, Vector3.ZERO, 22, hs, hs)
	BUILDER._ball(hat, 0.05, acc2, Vector3(0, 0.21 * hs, 0))


# ---------------------------------------------------------------- collo

static func _sciarpina(root: Node3D, dna: Dictionary) -> void:
	# sul corpo, non sulla testa: il girocollo resta fermo quando guarda
	var acc := BUILDER._mat(Color(dna["dress"]))
	var girocollo := TorusMesh.new()
	girocollo.inner_radius = 0.125
	girocollo.outer_radius = 0.205
	var mi := MeshInstance3D.new()
	mi.mesh = girocollo
	mi.material_override = acc
	mi.position = Vector3(0, 0.60, 0)
	mi.scale = Vector3(1, 0.62, 1)
	root.add_child(mi)
	# i due lembi che pendono sul petto, uno lungo e uno corto
	var tail_a: MeshInstance3D = BUILDER.tube(root,
			[Vector3(0.055, 0.575, -0.17), Vector3(0.085, 0.46, -0.205), Vector3(0.06, 0.315, -0.235)],
			[0.042, 0.036, 0.026], acc, 12, 8)
	tail_a.scale.x = 0.7
	var tail_b: MeshInstance3D = BUILDER.tube(root,
			[Vector3(-0.02, 0.575, -0.175), Vector3(-0.045, 0.49, -0.21)],
			[0.04, 0.028], acc, 8, 8)
	tail_b.scale.x = 0.7


static func _papillon(root: Node3D, dna: Dictionary) -> void:
	var acc := BUILDER._mat(Color(dna["dress2"]))
	var knot := BUILDER._mat(Color(dna["dress"]))
	var base := Vector3(0, 0.60, -0.185)
	for side: float in [-1.0, 1.0]:
		var wing := BUILDER._ball(root, 0.052, acc,
				base + Vector3(side * 0.055, 0, -0.005), Vector3(1.35, 0.72, 0.4))
		wing.rotation.z = side * 0.32
		wing.rotation.x = -0.35
	BUILDER._ball(root, 0.028, knot, base + Vector3(0, 0, -0.012))


# ---------------------------------------------------------------- viso

static func _occhialini(head: Node3D, dna: Dictionary, hs: float) -> void:
	# occhiali tondi tondi, da topo di biblioteca
	var frame := BUILDER._flat(Color("7a5c46"))
	var eye_r: float = dna["eye_r"]
	var gap: float = dna["eye_gap"]
	var ey: float = 0.035 + float(dna["eye_h"])
	var front := -0.34 * hs
	var ring_r := eye_r + 0.022
	for side: float in [-1.0, 1.0]:
		var tm := TorusMesh.new()
		tm.inner_radius = ring_r - 0.009
		tm.outer_radius = ring_r + 0.009
		tm.rings = 24
		var ring := MeshInstance3D.new()
		ring.mesh = tm
		ring.material_override = frame
		ring.position = Vector3(side * gap * hs, ey, front - 0.058)
		ring.rotation.x = PI * 0.5
		ring.scale.y = 1.12
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head.add_child(ring)
	var bm := CapsuleMesh.new()
	bm.radius = 0.008
	bm.height = (gap * hs - ring_r) * 2.0 + 0.02
	var bridge := MeshInstance3D.new()
	bridge.mesh = bm
	bridge.material_override = frame
	bridge.position = Vector3(0, ey + 0.012, front - 0.058)
	bridge.rotation.z = PI * 0.5
	bridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.add_child(bridge)
