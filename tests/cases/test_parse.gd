extends RefCounted
## Verifica di sola COMPILAZIONE dei file caldi del progetto: quelli che gli
## altri test istanziano (volto vivo, chibi, calendario) e che, rompendosi,
## farebbero cadere il gioco all'avvio senza che nessuno se ne accorga.
## Un errore di parse qui è il primo campanello: costa pochi millisecondi.
## (Era tests/parse_check.gd, script sciolto fuori dalla suite.)


const FILES := [
	"res://scenes/characters/FaceController.gd",
	"res://scenes/characters/Mochi.gd",
	"res://scenes/npc/ChibiBuilder.gd",
	"res://scenes/npc/Visitor.gd",
	"res://scenes/characters/Coop.gd",
	"res://scenes/world/Calendar.gd",
	"res://scenes/levels/DebugHarness.gd",
]


func run(t) -> void:
	for f in FILES:
		var s = load(f)
		t.ok(s != null and s is GDScript and (s as GDScript).can_instantiate(),
				"compila: %s" % f)
