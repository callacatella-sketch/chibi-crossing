extends RefCounted
## Smoke test: verifica che il framework e la GDExtension (classi C++) ci siano.


func run(t) -> void:
	t.eq(1 + 1, 2, "aritmetica di base")
	t.ok(true, "il framework esegue run()")
	# la GDExtension C++ ("il cuore") deve essere caricata
	t.ok(ClassDB.class_exists("SurvivalComponent"), "SurvivalComponent registrata")
	t.ok(ClassDB.class_exists("PlayerController"), "PlayerController registrata")
	t.ok(ClassDB.class_exists("GridManager"), "GridManager registrata")
	t.ok(ClassDB.class_exists("EcosystemManager"), "EcosystemManager registrata")
