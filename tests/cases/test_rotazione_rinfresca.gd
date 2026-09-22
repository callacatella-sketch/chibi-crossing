extends RefCounted
## ⚠️ **F RUOTAVA UN PEZZO E NON RINFRESCAVA NIENTE.**
##
## Due delle tre famiglie che si fondono guardano la ROTAZIONE per decidere
## chi sta in fila con chi — la Gradinata (`_fila_continua`: *«stessa
## rotazione o niente: due file che si voltano le spalle non sono una
## platea»*) e le Rastrelliere, che hanno la stessa regola e passano dallo
## stesso flush differito delle serre.
##
## `place_cell` e `_remove_at` chiamano **tutti e cinque** i rinfresca.
## `_rotate_placed` — che cambia proprio quel `rot` — non ne chiamava
## **nessuno**: due rastrelliere restavano unite dopo che una era stata
## girata di novanta gradi, col montante condiviso e i ripiani che
## proseguono in una fila che non esiste più; una gradinata restava senza
## bracciolo sul fianco che adesso è un capo.
##
## Questo caso ha DUE metà, e servono tutte e due:
##  1. che la rotazione CAMBI l'esito del rinfresco (comportamentale, sulla
##     funzione statica vera, senza villaggio);
##  2. che `_rotate_placed` lo chiami davvero (il cablaggio: senza, la
##     prima metà resta verde su un gioco rotto).

const BUILD := preload("res://scenes/build/BuildSystem.gd")

## I cinque che `place_cell` chiama, e che una rotazione deve richiamare.
const I_CINQUE := ["rinfresca_braccioli", "rinfresca_sentieri",
		"rinfresca_aiuole", "_segna_serre", "_segna_festoni"]


func run(t) -> void:
	_la_rotazione_cambia_la_fila(t)
	_e_la_rotazione_li_chiama(t)


func _gradinata(t, rot: int) -> Node3D:
	var n := Node3D.new()
	n.set_meta("item_name", "Gradinata")
	n.set_meta("rot", rot)
	var dx := Node3D.new()
	dx.name = "BraccioloDx"
	n.add_child(dx)
	var sx := Node3D.new()
	sx.name = "BraccioloSx"
	n.add_child(sx)
	t.stage(n)
	return n


## Due gradinate affiancate sulla stessa retta sono UNA platea: il bracciolo
## in mezzo si spegne. Girane una, e quella fila non esiste più.
func _la_rotazione_cambia_la_fila(t) -> void:
	var a := _gradinata(t, 0)
	var b := _gradinata(t, 0)
	var dict := {Vector2i(0, 0): a, Vector2i(1, 0): b}

	BUILD.rinfresca_braccioli(dict, Vector2i(0, 0))
	var mezzo_a: Node3D = a.find_child("BraccioloDx", true, false)
	t.ok(not mezzo_a.visible,
			"due gradinate in fila: il bracciolo IN MEZZO si spegne")

	# …e adesso B si gira di novanta gradi: la fila non c'è più
	b.set_meta("rot", 1)
	BUILD.rinfresca_braccioli(dict, Vector2i(0, 0))
	t.ok(mezzo_a.visible,
			"girata una, la fila non esiste più e il bracciolo torna")


## ⚠️ IL CABLAGGIO. `_rotate_placed` è l'unico posto del gioco che cambia
## `rot` su un pezzo già posato: se non rinfresca, la prima metà di questo
## caso resta verde su un villaggio che mostra file che non esistono.
## Si legge il sorgente SPOGLIATO dei commenti — la cura NOMINA i cinque
## rinfresca nella propria spiegazione, e un guardiano ingenuo matcherebbe
## quella invece del codice.
func _e_la_rotazione_li_chiama(t) -> void:
	var util := load("res://tests/test_util.gd")
	var src: String = util.codice("res://scenes/build/BuildSystem.gd")
	t.ok(src.length() > 10000, "BuildSystem.gd si legge (%d byte)" % src.length())
	var i := src.find("func _rotate_placed()")
	t.ok(i >= 0, "la funzione della F si trova")
	if i < 0:
		return
	var j := src.find("\nfunc ", i + 10)
	var corpo: String = src.substr(i, (j - i) if j > i else -1)
	for nome in I_CINQUE:
		t.ok(corpo.contains(nome + "("),
				"ruotare chiama %s, come fa posare un pezzo" % nome)
