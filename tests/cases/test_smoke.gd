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
	# IL CANARINO dell'ECS: se questa è rossa, la .dylib non ha la classe —
	# e ogni altro test sull'ECS mentirebbe dicendo «saltato».
	t.ok(ClassDB.class_exists("EcsMondo"), "EcsMondo registrata")
