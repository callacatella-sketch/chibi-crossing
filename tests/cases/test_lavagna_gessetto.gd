extends RefCounted
## IL GESSETTO STA DENTRO L'ARDESIA.
##
## La Lavagna è uno dei due posti fisici dove vive un appuntamento (l'altro
## è il bigliettino nella cassetta), ed è la prima cosa che si legge la
## mattina. Per molto tempo le righe uscivano dalla lastra: i nomi lunghi
## sbordavano sull'erba e le ultime righe finivano SOTTO il quadro, sepolte
## dietro la vaschetta dei gessetti. Si vedeva da lontano.
##
## Il test non guarda i numeri scritti a mano: COSTRUISCE la Lavagna vera
## dal catalogo, misura la lastra che ne esce, e verifica che
## l'impaginazione del gessetto ci stia dentro — con le stringhe vere,
## misurate col font vero. Se un domani la lavagna cambia forma (o
## qualcuno rialza il corpo del carattere), qui si accende una luce.

const CAL := "res://scenes/world/Calendar.gd"
const CATALOGO := "res://scenes/build/BuildCatalog.gd"

# righe realmente possibili sull'ardesia, dalle più corte alle peggiori
const RIGHE := [
	"· il calendario ·",
	"~ autunno ~",
	"Ciliegia · la bruma",
	"mercante · G143",
	"richieste appese · 1",
	"sagra del raccolto · G18",
	"Mirtillina · la prima neve",
	"…e altri 12",
]


func run(t) -> void:
	var cal: GDScript = load(CAL)
	var cat: GDScript = load(CATALOGO)
	t.ok(cal != null and cat != null, "Calendar e BuildCatalog si caricano")
	if cal == null or cat == null:
		return

	var lastra := _lastra(cat)
	t.ok(not lastra.is_empty(), "la Lavagna del catalogo ha una lastra da scrivere")
	if lastra.is_empty():
		return

	_test_ancorata(t, cal, lastra)
	_test_righe_dentro(t, cal, lastra)
	_test_niente_sbordi(t, cal, lastra)


## Costruisce la Lavagna VERA e ne estrae la lastra: centro, larghezza,
## altezza. Il quadro è il pezzo più largo e alto fra i box del pezzo.
func _lastra(cat: GDScript) -> Dictionary:
	var voce := {}
	for it in cat.items():
		if str((it as Dictionary).get("name", "")) == "Lavagna":
			voce = it
			break
	if voce.is_empty():
		return {}
	var nodo: Node3D = (voce["builder"] as Callable).call()
	if nodo == null:
		return {}
	var migliore := {}
	var area := 0.0
	for figlio in nodo.get_children():
		var mi := figlio as MeshInstance3D
		if mi == null or not (mi.mesh is BoxMesh):
			continue
		var s: Vector3 = (mi.mesh as BoxMesh).size
		if s.x * s.y > area:
			area = s.x * s.y
			migliore = {"centro": mi.position, "l": s.x, "h": s.y, "sp": s.z,
					"pend": mi.rotation.x}
	nodo.free()
	return migliore


## Il quaderno del gessetto è ancorato alla lastra: stesso centro, stessa
## inclinazione. Non due numeri che si somigliano — gli stessi.
func _test_ancorata(t, cal: GDScript, lastra: Dictionary) -> void:
	var c: Vector3 = lastra["centro"]
	t.almost(float(cal.ARDESIA_CENTRO.y), c.y,
			"il gessetto è centrato sulla lastra (y)", 0.001)
	t.almost(float(cal.ARDESIA_CENTRO.z), c.z,
			"…e sul suo piano (z): scrivere sul telaio non è scrivere", 0.001)
	t.almost(float(cal.ARDESIA_PEND), float(lastra["pend"]),
			"…e pende come lei: dritte, le righe basse finivano DENTRO il quadro", 0.001)
	t.ok(float(cal.ARDESIA_FUORI) < 0.0,
			"il gessetto sta davanti alla lastra (il fronte della Lavagna è -Z)")
	t.ok(absf(float(cal.ARDESIA_FUORI)) > float(lastra.get("sp", 0.025)) * 0.5,
			"…abbastanza avanti da non litigare con la superficie")


## Comunque vada, nessuna riga esce dai bordi alti o bassi della lastra.
func _test_righe_dentro(t, cal: GDScript, lastra: Dictionary) -> void:
	var c: Vector3 = lastra["centro"]
	var alto: float = c.y + float(lastra["h"]) * 0.5
	var basso: float = c.y - float(lastra["h"]) * 0.5
	# la vaschetta dei gessetti mangia gli ultimi centimetri in basso
	var utile_basso := basso + 0.06
	for n in range(1, 15):
		var imp: Vector2 = cal.impaginazione(n)
		var mezza: float = cal.corpo(imp.y) * 40.0 * 0.5   # mezza riga di testo
		var prima: float = imp.x + mezza
		var ultima: float = imp.x - float(n - 1) * imp.y - mezza
		t.ok(prima <= alto, "%d righe: la prima resta sotto il bordo alto (%.3f ≤ %.3f)"
				% [n, prima, alto])
		t.ok(ultima >= utile_basso,
				"%d righe: l'ultima resta sopra la vaschetta (%.3f ≥ %.3f)"
				% [n, ultima, utile_basso])
		# e due righe vicine non si sovrappongono mai
		t.ok(imp.y > cal.corpo(imp.y) * 40.0 * 0.85,
				"%d righe: fra una riga e l'altra ci passa l'aria" % n)


## E nessuna riga esce dai fianchi: le stringhe VERE, col font VERO.
func _test_niente_sbordi(t, cal: GDScript, lastra: Dictionary) -> void:
	var largh: float = lastra["l"]
	t.ok(float(cal.ARDESIA_L) < largh,
			"la larghezza utile sta dentro la lastra (%.2f < %.2f)"
			% [float(cal.ARDESIA_L), largh])
	var font := ThemeDB.fallback_font
	t.ok(font != null, "c'è un font per misurare il gessetto")
	if font == null:
		return
	# il caso peggiore: tante righe (gessetto piccolo) e poche (gessetto grande)
	for n in [3, 6, 10]:
		var imp: Vector2 = cal.impaginazione(n)
		var px: float = cal.corpo(imp.y)
		for riga in RIGHE:
			var w: float = font.get_string_size(riga,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x * px
			var finale: float = w * cal.stretta(w)
			t.ok(finale <= largh,
					"«%s» con %d righe sta nella lastra (%.3f ≤ %.3f)"
					% [riga, n, finale, largh])
	# la guardia sa fallire: una riga assurda DEVE essere stretta
	t.ok(cal.stretta(3.0) < 1.0, "una riga larga tre metri viene stretta")
	t.eq(cal.stretta(0.2), 1.0, "…e una corta viene lasciata in pace")
