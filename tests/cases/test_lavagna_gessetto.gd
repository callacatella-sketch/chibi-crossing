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
	_test_dentro_la_cornice(t, cal, cat, lastra)


## E IL GESSETTO STA DENTRO LA CORNICE, non davanti.
##
## `_test_ancorata` chiede solo che il piano scritto sia più avanti della
## SUPERFICIE della lastra: un pavimento, senza soffitto. Con la Lavagna
## rifatta — che ha una cornice in rilievo — il vecchio -0.045 portava la
## Label3D 14 mm DAVANTI al legno: il testo si disegnava sopra il telaio
## (niente lo occludeva più) e, girandoci intorno, l'intero blocco
## scivolava di 22 mm rispetto all'ardesia a 45 gradi. In una piazza, dove
## la lavagna la si guarda da ogni parte, si vede.
##
## Il soffitto non è un numero scritto qui: si MISURA sul pezzo vero. La
## fascia di margine fra la larghezza utile e il bordo della lastra è
## esattamente dove vive il montante della cornice; il punto più avanti
## di quel che sta lì è il piano del legno.
##
## SI GUARDA SOLO CHI VIVE NEL PIANO DELLA LASTRA (i figli del perno che
## ha la stessa inclinazione del quadro). Prima questa misura girava su
## TUTTE le mesh del pezzo, e l'AABB dei montanti — che sono alti tutta
## la lavagna — una volta ruotato di 0.05 rad dava uno z fittizio di
## -0.072: un soffitto finto, dieci volte più avanti del vero, sotto cui
## qualunque valore passava. La guardia era verde e non guardava niente.
func _test_dentro_la_cornice(t, cal: GDScript, cat: GDScript, lastra: Dictionary) -> void:
	var nodo := _costruisci(cat, "Lavagna")
	t.ok(nodo != null, "la Lavagna si costruisce per misurarne la cornice")
	if nodo == null:
		return
	var centro: Vector3 = lastra["centro"]
	var pend: float = lastra["pend"]
	var meta_l: float = float(cal.ARDESIA_L) * 0.5
	var meta_lastra: float = float(lastra["l"]) * 0.5
	var alto: float = float(cal.ARDESIA_ALTA) - centro.y
	var basso: float = float(cal.ARDESIA_BASSA) - centro.y
	# il perno del telaio: stesso centro e stessa inclinazione del quadro
	var telaio: Node3D = null
	for figlio in nodo.get_children():
		var nd := figlio as Node3D
		if nd == null or nd is MeshInstance3D:
			continue
		if absf(nd.rotation.x - pend) < 1e-4 and nd.position.distance_to(centro) < 1e-4:
			telaio = nd
			break
	t.ok(telaio != null, "la cornice vive nel piano della lastra (stesso perno)")
	if telaio == null:
		nodo.free()
		return
	var davanti := 9.0
	for mi in telaio.find_children("*", "MeshInstance3D", true, false):
		var t_rel := _relativa(telaio, mi)
		var ab: AABB = (mi as MeshInstance3D).mesh.get_aabb()
		var mn := Vector3(9, 9, 9)
		var mx := Vector3(-9, -9, -9)
		for k in 8:
			var q: Vector3 = t_rel * ab.get_endpoint(k)
			mn = mn.min(q)
			mx = mx.max(q)
		# tocca la fascia di margine di fianco alla scrittura?
		var di_lato: bool = mx.x > meta_l and mn.x < meta_lastra
		var di_lato2: bool = mn.x < -meta_l and mx.x > -meta_lastra
		if (di_lato or di_lato2) and mx.y > basso and mn.y < alto:
			davanti = minf(davanti, mn.z)
	nodo.free()
	t.ok(davanti < 9.0, "c'è del legno di fianco alla scrittura da cui misurare")
	if davanti >= 9.0:
		return
	t.ok(float(cal.ARDESIA_FUORI) >= davanti,
			"il gessetto non passa DAVANTI alla cornice (%.4f ≥ %.4f)"
			% [float(cal.ARDESIA_FUORI), davanti])
	t.ok(float(cal.ARDESIA_FUORI) < -float(lastra.get("sp", 0.045)) * 0.5 - 0.002,
			"…e resta comunque davanti alla lastra e alla sua velatura")


## Il pezzo del catalogo, costruito davvero.
func _costruisci(cat: GDScript, nome: String) -> Node3D:
	for it in cat.items():
		if str((it as Dictionary).get("name", "")) == nome:
			return ((it as Dictionary)["builder"] as Callable).call()
	return null


## La trasformazione di una mesh rispetto alla radice del pezzo, senza
## bisogno di appenderlo all'albero della scena.
func _relativa(root: Node, n: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c := n
	while c != null and c != root:
		t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


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
