extends RefCounted
## Test del volto dei VILLAGER: genera qualche DNA, costruisce il chibi con
## ChibiBuilder (che restituisce anche il rig facciale), monta il
## FaceController e lo esercita su ogni espressione. Verifica che il rig arrivi
## completo per ogni archetipo generato — è il contratto fra ChibiBuilder e
## FaceController, quello che rompendosi lascia i vicini senza faccia.
## (Era tests/npc_face_smoke.gd, script sciolto fuori dalla suite.)

const CHIBI := 5   # quanti vicini generare


func run(t) -> void:
	var dna: GDScript = load("res://scenes/npc/ChibiDNA.gd")
	var builder: GDScript = load("res://scenes/npc/ChibiBuilder.gd")
	var fc: GDScript = load("res://scenes/characters/FaceController.gd")
	var visitor: GDScript = load("res://scenes/npc/Visitor.gd")
	for pair in [["ChibiDNA", dna], ["ChibiBuilder", builder],
			["FaceController", fc], ["Visitor", visitor]]:
		var s: GDScript = pair[1]
		t.ok(s != null and s.can_instantiate(), "%s compila" % pair[0])
		if s == null or not s.can_instantiate():
			return

	var costruiti := 0
	for seed_v in range(CHIBI):
		if _test_un_vicino(t, dna, builder, fc, seed_v):
			costruiti += 1
	t.eq(costruiti, CHIBI, "tutti i %d vicini hanno un volto completo" % CHIBI)


func _test_un_vicino(t, dna: GDScript, builder: GDScript, fc: GDScript, seed_v: int) -> bool:
	var gene: Dictionary = dna.generate(seed_v * 131 + 7)
	var parts: Dictionary = builder.build(gene)
	t.stage(parts["root"])
	if not parts.has("face"):
		t.ok(false, "seme %d: build() non restituisce il rig 'face'" % seed_v)
		return false

	var rig: Dictionary = parts["face"]
	rig["head"] = parts["head"]
	var eyes: Array = rig["eyes"]
	var brows: Array = rig["brows"]
	var mouths: Dictionary = rig["mouths"]
	t.eq(eyes.size(), 2, "seme %d: due occhi" % seed_v)
	t.eq(brows.size(), 2, "seme %d: due sopracciglia" % seed_v)
	t.ok(mouths.size() >= 6, "seme %d: almeno 6 bocche (%d)" % [seed_v, mouths.size()])
	if eyes.size() != 2 or brows.size() != 2 or mouths.size() < 6:
		return false

	var face = fc.new()
	face.setup(rig)
	var target := t.stage(Node3D.new()) as Node3D
	target.position = Vector3(0.6, 1.0, -1.5)
	face.look_at_node(target)
	# esercita ogni espressione, col parlato acceso
	for e in fc.EXPRESSIONS.keys():
		face.set_expression(e)
		face.set_talking(true)
		for f in 8:
			face.update(0.016)
	face.set_mood("felice")
	face.set_talking(false)
	for f in 20:
		face.update(0.016)
	return true
