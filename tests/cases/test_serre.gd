extends RefCounted
## LE SERRE CHE SI FONDONO.
##
## Due serre vicine diventano un edificio solo. Questo test non guarda la
## bellezza (quella si guarda, col provino `tools/provino_serre.gd`): guarda
## le tre cose che si romperebbero in silenzio lasciando la suite verde.
##
##  1. CI SI CAMMINA DENTRO. Il muro fra due campate deve sparire DALLE
##     COLLISIONI, non solo dalla geometria: una vetreria bellissima e
##     attraversabile — o peggio, con un muro invisibile in mezzo — passa
##     qualunque test scritto sui vetri. Le scatole si leggono dal meta che
##     le genera, che è la stessa fonte dei vetri.
##  2. IL GUSCIO RESTA CHIUSO E LA PORTA APERTA. Sono la stessa proprietà
##     vista dai due lati, e insieme dicono «è un edificio», non «è un
##     recinto» né «è una scatola».
##  3. LA FUSIONE VA E TORNA. Togliere una campata deve richiudere il
##     guscio: se andasse solo in avanti, un villaggio ricaricato dopo una
##     demolizione avrebbe pareti mancanti per sempre.
##
## Più il determinismo — l'ordine delle righe nel salvataggio è arbitrario,
## e la stessa disposizione deve ridare lo stesso edificio — e la disciplina
## degli interni: a ogni salto di taglia l'arredo deve TOGLIERE qualcosa,
## o «cambia radicalmente» diventa «più vasi».

const CAT := preload("res://scenes/build/BuildCatalog.gd")
const SYS := preload("res://scenes/build/BuildSystem.gd")

## L'altezza a cui cammina un chibi: le prove di passaggio si fanno lì.
const QUOTA := 0.45


func run(t) -> void:
	_test_la_serra_sola_non_e_cambiata(t)
	_test_il_gruppo_si_riconosce(t)
	_test_si_passa_da_una_campata_all_altra(t)
	_test_il_guscio_e_chiuso_e_la_porta_aperta(t)
	_test_la_fusione_va_e_torna(t)
	_test_il_determinismo(t)
	_test_niente_doppioni_sul_confine(t)
	_test_il_salto_toglie(t)
	_test_una_porta_sola(t)
	_test_dentro_ci_si_siede(t)
	_test_gli_angoli_sono_chiusi(t)


# ------------------------------------------------------------- gli attrezzi

## Le scatole di collisione di una campata, portate in coordinate MONDO.
## È la STESSA lista da cui BuildSystem scrive le CollisionShape3D: se un
## giorno divergesse dai vetri, divergerebbe anche qui.
func _scatole_mondo(pianta: Dictionary, c: Vector2i) -> Array:
	var radice: Node3D = CAT.serra_cella(pianta, c)
	var campata := radice.get_node("Vetreria") as Node3D
	var giro: float = campata.rotation.y
	var base := Basis(Vector3.UP, giro)
	var out: Array = []
	for sc: Array in campata.get_meta("scatole", []):
		var size: Vector3 = sc[0]
		var pos: Vector3 = base * (sc[1] as Vector3)
		# la rotazione è multipla di 90°: ruotare la scatola vuol dire
		# scambiare i lati, e così il test può restare in AABB
		var s2 := size
		if absf(sin(giro)) > 0.5:
			s2 = Vector3(size.z, size.y, size.x)
		out.append([s2, pos + Vector3(float(c.x), 0.0, float(c.y))])
	radice.free()
	return out


func _tutte_le_scatole(celle: Array) -> Array:
	var pianta: Dictionary = CAT.serra_pianta(celle)
	var out: Array = []
	for c: Vector2i in celle:
		out.append_array(_scatole_mondo(pianta, c))
	return out


func _dentro(p: Vector3, scatole: Array) -> bool:
	for sc: Array in scatole:
		var size: Vector3 = sc[0]
		var pos: Vector3 = sc[1]
		var d := p - pos
		if absf(d.x) <= size.x * 0.5 and absf(d.y) <= size.y * 0.5 \
				and absf(d.z) <= size.z * 0.5:
			return true
	return false


## Un dizionario di celle come quello di BuildSystem, con nodi veri che
## portano il meta «item_name»: è quello che legge gruppo_serra.
func _dizionario(celle: Array) -> Dictionary:
	var dict := {}
	for c: Vector2i in celle:
		var nodo := Node3D.new()
		nodo.set_meta("item_name", "Serra")
		dict[c] = nodo
	return dict


func _libera(dict: Dictionary) -> void:
	for c in dict:
		(dict[c] as Node3D).free()


func _conta_classi(pianta: Dictionary, celle: Array) -> Dictionary:
	# le CLASSI d'arredo di un edificio: si riconoscono dalle misure e dalle
	# quote, che è come le riconosce l'occhio
	var classi := {}
	for c: Vector2i in celle:
		var radice: Node3D = CAT.serra_cella(pianta, c)
		for sc: Array in (radice.get_node("Vetreria") as Node3D).get_meta("scatole", []):
			var size: Vector3 = sc[0]
			var pos: Vector3 = sc[1]
			var lungo: float = maxf(size.x, size.z)
			var corto: float = minf(size.x, size.z)
			if absf(size.y - 1.90) < 0.01 or absf(size.y - 0.42) < 0.01:
				continue  # le pareti non sono arredo
			var nome := "?"
			if absf(size.y - 0.62) < 0.02 and lungo > 1.2:
				nome = "aiuola"
			elif absf(size.y - 1.00) < 0.02:
				nome = "bancone"
			elif absf(size.y - 0.80) < 0.02:
				nome = "gradoni"
			elif absf(size.y - 0.62) < 0.02 and corto < 0.45:
				nome = "stufa"
			elif absf(size.y - 0.45) < 0.02 and absf(pos.y - 0.22) < 0.05:
				nome = "cuore"
			elif absf(size.y - 0.35) < 0.02:
				nome = "vasca"
			elif absf(size.y - 0.32) < 0.02:
				nome = "palma"
			classi[nome] = true
		radice.free()
	return classi


# ------------------------------------------------------------------- i test

## LA SERRA SOLA NON È CAMBIATA. È il pezzo che i giocatori hanno già in
## giardino: la fusione non deve toccarlo. Le quote sono quelle di sempre.
func _test_la_serra_sola_non_e_cambiata(t) -> void:
	var pianta: Dictionary = CAT.serra_pianta([Vector2i.ZERO])
	t.eq(int(pianta["asse"]), 0, "la serra sola tiene il colmo lungo X, come sempre")
	t.eq(str(pianta["taglia"]), "sola", "…ed è della taglia «sola»")
	var radice: Node3D = CAT.serra_cella(pianta, Vector2i.ZERO)
	var campata := radice.get_node("Vetreria") as Node3D
	t.almost(campata.rotation.y, 0.0, "…e non è girata", 0.001)
	var box := _ingombro(campata)
	t.almost(box.position.y + box.size.y, 2.55,
			"il colmo col pomolo sta dove stava (2.55)", 0.06)
	t.ok(box.size.x > 1.9 and box.size.x < 2.2,
			"…e il guscio è largo quello di prima (%.2f)" % box.size.x)
	radice.free()
	# e l'aiuola rialzata, che è il segno della serra piccola, c'è
	var classi := _conta_classi(pianta, [Vector2i.ZERO])
	t.ok(classi.has("aiuola"), "la serra sola ha la sua aiuola rialzata")


## IL GRUPPO SI RICONOSCE, e si riconosce a OTTO vicini: due serre che si
## toccano d'angolo hanno i gusci compenetrati, quindi o si fondono o
## restano due scatole conficcate l'una nell'altra.
func _test_il_gruppo_si_riconosce(t) -> void:
	var dict := _dizionario([Vector2i(0, 0), Vector2i(1, 0), Vector2i(5, 5)])
	var g: Array = SYS.gruppo_serra(dict, Vector2i(0, 0))
	t.eq(g.size(), 2, "due celle attaccate fanno un gruppo da due")
	var lontana: Array = SYS.gruppo_serra(dict, Vector2i(5, 5))
	t.eq(lontana.size(), 1, "…e quella lontana resta sola")
	_libera(dict)
	var diag := _dizionario([Vector2i(0, 0), Vector2i(1, 1)])
	t.eq(SYS.gruppo_serra(diag, Vector2i(0, 0)).size(), 2,
			"anche due che si toccano SOLO d'angolo sono un edificio: i loro"
			+ " gusci si compenetrerebbero comunque")
	_libera(diag)
	# e una cella che non è una serra non fa gruppo
	var misto := _dizionario([Vector2i(0, 0)])
	var altro := Node3D.new()
	altro.set_meta("item_name", "Panchina")
	misto[Vector2i(1, 0)] = altro
	t.eq(SYS.gruppo_serra(misto, Vector2i(0, 0)).size(), 1,
			"una panchina accanto non entra nell'edificio")
	_libera(misto)


## SI PASSA DA UNA CAMPATA ALL'ALTRA. È il vincolo non negoziabile, ed è
## anche la definizione stessa della fusione: sul confine condiviso non
## deve esserci NESSUNA scatola.
func _test_si_passa_da_una_campata_all_altra(t) -> void:
	for forma: Array in [
			[Vector2i(0, 0), Vector2i(1, 0)],
			[Vector2i(0, 0), Vector2i(0, 1)],
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]]:
		var scatole := _tutte_le_scatole(forma)
		for c: Vector2i in forma:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				if not (c + d) in forma:
					continue
				var mezzo := Vector3(float(c.x) + float(d.x) * 0.5, QUOTA,
						float(c.y) + float(d.y) * 0.5)
				t.ok(not _dentro(mezzo, scatole),
						"si passa fra %s e %s (gruppo da %d)"
						% [c, c + d, forma.size()])


## IL GUSCIO È CHIUSO E LA PORTA È APERTA. Il perimetro deve fermare chi
## sta fuori — altrimenti non è un edificio, è una scenografia.
func _test_il_guscio_e_chiuso_e_la_porta_aperta(t) -> void:
	for forma: Array in [
			[Vector2i(0, 0)],
			[Vector2i(0, 0), Vector2i(1, 0)],
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]]:
		var pianta: Dictionary = CAT.serra_pianta(forma)
		var scatole := _tutte_le_scatole(forma)
		var porta: Vector2i = pianta["porta"]
		for c: Vector2i in forma:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
					Vector2i(0, 1), Vector2i(0, -1)]:
				if (c + d) in forma:
					continue
				# il muro di questo lato: il punto di mezzo, sul filo 0.95
				var p := Vector3(float(c.x) + float(d.x) * 0.95, QUOTA,
						float(c.y) + float(d.y) * 0.95)
				if c == porta and d == Vector2i(0, -1):
					t.ok(not _dentro(p, scatole),
							"dalla porta si entra (gruppo da %d)" % forma.size())
				else:
					t.ok(_dentro(p, scatole),
							"il muro %s di %s ferma chi sta fuori (gruppo da %d)"
							% [d, c, forma.size()])


## LA FUSIONE VA E TORNA. Tolta la vicina, il muro condiviso deve
## RITORNARE: un rinfresco che va solo in avanti lascia un villaggio con le
## pareti mancanti dopo ogni demolizione.
func _test_la_fusione_va_e_torna(t) -> void:
	var fusa := _tutte_le_scatole([Vector2i(0, 0), Vector2i(1, 0)])
	var mezzo := Vector3(0.5, QUOTA, 0.0)
	t.ok(not _dentro(mezzo, fusa), "fuse: in mezzo ci si passa")
	var sola := _tutte_le_scatole([Vector2i(0, 0)])
	t.ok(_dentro(Vector3(0.95, QUOTA, 0.0), sola),
			"tolta la vicina, il muro di destra è tornato")
	# e la fila di tre spezzata in mezzo fa DUE edifici
	var dict := _dizionario([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	t.eq(SYS.gruppo_serra(dict, Vector2i(0, 0)).size(), 3, "tre in fila: un edificio")
	(dict[Vector2i(1, 0)] as Node3D).free()
	dict.erase(Vector2i(1, 0))
	var viste := {}
	var a: Array = SYS.gruppo_serra(dict, Vector2i(0, 0), viste)
	var b: Array = SYS.gruppo_serra(dict, Vector2i(2, 0), viste)
	t.eq(a.size(), 1, "tolta quella di mezzo, la prima resta sola")
	t.eq(b.size(), 1, "…e anche l'ultima")
	_libera(dict)


## IL DETERMINISMO. L'ordine delle righe nel salvataggio è l'ordine storico
## di costruzione: due serre dello stesso gruppo possono essere separate da
## centinaia di righe. La pianta non deve dipendere da chi arriva prima.
func _test_il_determinismo(t) -> void:
	var celle := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]
	var a: Dictionary = CAT.serra_pianta(celle)
	var b: Dictionary = CAT.serra_pianta([Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 0)])
	t.eq(int(a["asse"]), int(b["asse"]), "l'asse non dipende dall'ordine")
	t.eq(str(a["porta"]), str(b["porta"]), "la porta non dipende dall'ordine")
	t.eq(str(a["fondo"]), str(b["fondo"]), "il fondo non dipende dall'ordine")
	# e la geometria è identica, nodo per nodo
	var uno: Node3D = CAT.serra_cella(a, Vector2i(1, 0))
	var due: Node3D = CAT.serra_cella(b, Vector2i(1, 0))
	t.eq(_impronta(uno), _impronta(due),
			"la stessa campata, costruita due volte, è identica")
	uno.free()
	due.free()


## NIENTE DOPPIONI SUL CONFINE. Un montante può essere toccato da due
## campate (confine) o da QUATTRO (la crociera di un 2x2): se lo disegnano
## tutte, sul confine c'è due volte lo stesso legno — e si vede in
## controluce, che è come si guarda una serra.
func _test_niente_doppioni_sul_confine(t) -> void:
	var celle := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var pianta: Dictionary = CAT.serra_pianta(celle)
	var punti: Array = []
	for c: Vector2i in celle:
		var radice: Node3D = CAT.serra_cella(pianta, c)
		var campata := radice.get_node("Vetreria") as Node3D
		for mi in campata.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh is not BoxMesh:
				continue
			var bm := m.mesh as BoxMesh
			# solo i montanti verticali: alti più di un metro e sottili
			if bm.size.y < 1.0 or bm.size.x > 0.12 or bm.size.z > 0.12:
				continue
			punti.append(_posa(m, campata) + Vector3(float(c.x), 0, float(c.y)))
		radice.free()
	var doppi := 0
	for i in punti.size():
		for j in range(i + 1, punti.size()):
			if (punti[i] as Vector3).distance_to(punti[j] as Vector3) < 0.01:
				doppi += 1
	t.eq(doppi, 0, "nessun montante disegnato due volte (%d montanti)" % punti.size())


## IL SALTO TOGLIE. È la disciplina che separa «cambia radicalmente» da
## «più vasi»: a ogni scalino di taglia l'arredo deve perdere una classe,
## non solo guadagnarne.
func _test_il_salto_toglie(t) -> void:
	var sola := _conta_classi(CAT.serra_pianta([Vector2i.ZERO]), [Vector2i.ZERO])
	var due_celle := [Vector2i(0, 0), Vector2i(1, 0)]
	var due := _conta_classi(CAT.serra_pianta(due_celle), due_celle)
	t.ok(sola.has("aiuola"), "a una cella c'è l'aiuola rialzata")
	t.ok(not due.has("aiuola"),
			"a due celle l'aiuola SPARISCE: una serra grande coltiva in vaso")
	t.ok(due.has("gradoni"),
			"…e in fondo alla navata compare la scalinata dei vasi")
	var nove: Array = []
	for x in 3:
		for z in 3:
			nove.append(Vector2i(x, z))
	var tanti := _conta_classi(CAT.serra_pianta(nove), nove)
	t.ok(tanti.has("cuore"),
			"a nove celle il cuore ha l'agrume in mastello con la panca")
	t.ok(tanti.has("palma"), "…e la palmeria ha le sue palme")


## UNA PORTA SOLA. Se ogni campata tenesse la sua, un edificio da nove
## celle avrebbe nove porte: sarebbe un chiostro, non una serra.
func _test_una_porta_sola(t) -> void:
	var celle: Array = []
	for x in 3:
		for z in 3:
			celle.append(Vector2i(x, z))
	var pianta: Dictionary = CAT.serra_pianta(celle)
	var quante := 0
	for c: Vector2i in celle:
		if c == pianta["porta"]:
			quante += 1
	t.eq(quante, 1, "l'edificio ha una porta sola")
	var porta: Vector2i = pianta["porta"]
	t.ok(not (porta + Vector2i(0, -1)) in celle,
			"…e sta su un fianco LIBERO, o si aprirebbe dentro un'altra campata")


## DENTRO CI SI SIEDE. Un interno che non si puo' usare e' una vetrina: a
## OGNI taglia deve esserci un posto, e deve trovarlo sia il giocatore
## (BuildSystem.get_interactables) sia i vicini (Visitors._free_bench) —
## che cercano tutti e due i nodi «Posto*» col meta «seduta».
func _test_dentro_ci_si_siede(t) -> void:
	var forme := {
		"sola": [Vector2i.ZERO],
		"galleria": [Vector2i(0, 0), Vector2i(1, 0)],
		"cuore": [Vector2i(1, 1), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 0),
				Vector2i(1, 2)],
	}
	for nome: String in forme:
		var celle: Array = forme[nome]
		var pianta: Dictionary = CAT.serra_pianta(celle)
		var posti := 0
		for c: Vector2i in celle:
			var radice: Node3D = CAT.serra_cella(pianta, c)
			var campata := radice.get_node("Vetreria") as Node3D
			for a in campata.find_children("Posto*", "Node3D", true, false):
				var anc := a as Node3D
				posti += 1
				t.ok(anc.has_meta("seduta"),
						"%s: il posto DICHIARA dov'e' la seduta (senza, chi si"
						% nome + " siede resta a mezz'aria)")
				t.ok(anc.has_meta("tavolo"),
						"%s: …e cosa si guarda da seduti" % nome)
				t.ok(anc.position.y > 0.2 and anc.position.y < 0.6,
						"%s: si siede all'altezza di una seduta (%.2f)"
						% [nome, anc.position.y])
				# il verso: da seduti si guarda il tavolo, non le spalle
				var guarda: Vector3 = anc.get_meta("tavolo")
				var d := (guarda - anc.position) * Vector3(1, 0, 1)
				if d.length() > 0.05:
					var avanti := Vector3(-sin(anc.rotation.y), 0.0, -cos(anc.rotation.y))
					t.ok(avanti.dot(d.normalized()) > 0.9,
							"%s: seduto, guarda quello che è venuto a guardare"
							% nome + " (allineamento %.2f)" % avanti.dot(d.normalized()))
			radice.free()
		t.ok(posti >= 1, "«%s» ha almeno un posto dove sedersi (%d)" % [nome, posti])


## GLI ANGOLI SONO CHIUSI. Due fili di muro che si incontrano fanno un
## angolo, e un angolo senza montante è una fessura: in controluce — che è
## come si guarda una serra — si vede il cielo passare. Vale anche per gli
## angoli CONCAVI del pizzico diagonale, dove i fili si fermano a 0.05.
func _test_gli_angoli_sono_chiusi(t) -> void:
	for forma: Array in [
			[Vector2i.ZERO],
			[Vector2i(0, 0), Vector2i(1, 0)],
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
			[Vector2i(0, 0), Vector2i(1, 1)]]:
		var pianta: Dictionary = CAT.serra_pianta(forma)
		var montanti: Array = []
		for c: Vector2i in forma:
			var radice: Node3D = CAT.serra_cella(pianta, c)
			var campata := radice.get_node("Vetreria") as Node3D
			for mi in campata.find_children("*", "MeshInstance3D", true, false):
				var m := mi as MeshInstance3D
				if m.mesh is not BoxMesh:
					continue
				var bm := m.mesh as BoxMesh
				if bm.size.y < 1.5 or bm.size.x > 0.12 or bm.size.z > 0.12:
					continue
				montanti.append(_posa(m, campata) + Vector3(float(c.x), 0, float(c.y)))
			radice.free()
		# ogni angolo del perimetro deve avere il suo montante
		for c: Vector2i in forma:
			for su: int in [-1, 1]:
				for sv: int in [-1, 1]:
					if (c + Vector2i(su, 0)) in forma or (c + Vector2i(0, sv)) in forma:
						continue
					# AL PIZZICO (la diagonale occupata) l'angolo non esiste:
					# il punto (0.95, 0.95) sta DENTRO il rettangolo della
					# vicina, e i due fili si fermano prima, a 0.05. Gli
					# spigoli veri sono due, e sono lì.
					var attesi: Array = [Vector2(0.95, 0.95)]
					if (c + Vector2i(su, sv)) in forma:
						attesi = [Vector2(0.95, 0.05), Vector2(0.05, 0.95)]
					for att: Vector2 in attesi:
						var spigolo := Vector3(float(c.x) + float(su) * att.x, 0.0,
								float(c.y) + float(sv) * att.y)
						var chiuso := false
						for m: Vector3 in montanti:
							if Vector2(m.x - spigolo.x, m.z - spigolo.z).length() < 0.08:
								chiuso = true
						t.ok(chiuso, "l'angolo (%d,%d)·%s di %s ha il suo montante"
								% [su, sv, att, c] + " (gruppo da %d)" % forma.size())


# --------------------------------------------------------------- misuratori

func _ingombro(n: Node3D) -> AABB:
	var box := AABB()
	var primo := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var a: AABB = _trasformata(m, n) * m.mesh.get_aabb()
		if primo:
			box = a
			primo = false
		else:
			box = box.merge(a)
	return box


func _trasformata(nodo: Node3D, radice: Node3D) -> Transform3D:
	var tr := Transform3D.IDENTITY
	var cur := nodo
	while cur != null and cur != radice:
		tr = cur.transform * tr
		cur = cur.get_parent() as Node3D
	return tr


func _posa(nodo: Node3D, radice: Node3D) -> Vector3:
	return _trasformata(nodo, radice).origin


## L'impronta di una campata: classe e posizione al millimetro, in ordine.
func _impronta(n: Node3D) -> String:
	var righe: Array = []
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var p := _posa(m, n)
		righe.append("%s|%.3f,%.3f,%.3f" % [m.mesh.get_class(), p.x, p.y, p.z])
	righe.sort()
	return "\n".join(righe)
