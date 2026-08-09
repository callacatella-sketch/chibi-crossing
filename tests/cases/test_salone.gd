extends RefCounted
## IL SALONE — il posto dell'estetista.
##
## La pietra 1 (il genoma estetico) ha reso possibile cambiare un
## aspetto; questa e' la pietra 2: il LUOGO. Viene prima del mestiere e
## prima del pannello, perche' una meccanica senza un posto dove accade
## e' un menu'.
##
## La guardia che conta davvero e' LA SCALA. Alla prima stesura il
## salone era bello e sbagliato: la poltrona arrivava alla testa di chi
## doveva sedercisi e lo specchio sembrava un portale. Un chibi e' alto
## ~0.70 e si siede a ~0.29: qui si misura che il mobile resti a misura
## di lui, sui VERTICI veri delle mesh — non a occhio.

const CATALOGO := preload("res://scenes/build/BuildCatalog.gd")

## Un chibi sta fra 0.60 e 0.78 di taglia: il salone non deve mai
## sembrare arredamento per giganti.
const ALTEZZA_CHIBI := 0.78


func run(t) -> void:
	_test_nel_catalogo(t)
	_test_la_scala(t)
	_test_i_pezzi(t)
	_test_collisioni(t)
	_test_il_pubblico_del_vanto(t)


func _voce() -> Dictionary:
	for it in CATALOGO.items():
		if str(it["name"]) == "Salone":
			return it
	return {}


func _test_nel_catalogo(t) -> void:
	var v := _voce()
	t.ok(not v.is_empty(), "il Salone e' nel catalogo del builder")
	t.eq(int(v.get("cat", -1)), 1, "sta fra gli Arredi")
	t.eq(str(v.get("type", "")), "cell", "occupa una cella")
	t.eq(int(v.get("layer", -1)), 2, "sul livello degli oggetti")


## LA SCALA, misurata sui vertici veri.
func _test_la_scala(t) -> void:
	var n: Node3D = t.stage(CATALOGO._salone())
	var alto := -INF
	var minx := INF
	var maxx := -INF
	var minz := INF
	var maxz := -INF
	var quanti := 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		quanti += 1
		var aabb := m.mesh.get_aabb()
		# dal locale della mesh al locale del salone (scale comprese)
		var tr := n.global_transform.affine_inverse() * m.global_transform
		for i in 8:
			var p: Vector3 = tr * aabb.get_endpoint(i)
			alto = maxf(alto, p.y)
			minx = minf(minx, p.x)
			maxx = maxf(maxx, p.x)
			minz = minf(minz, p.z)
			maxz = maxf(maxz, p.z)
	t.ok(quanti >= 60,
			"il salone e' fatto di pezzi veri, non di quattro scatole (%d mesh)" % quanti)
	t.ok(alto < ALTEZZA_CHIBI * 2.0,
			"NON e' arredamento per giganti: alto %.2f, meno del doppio di un chibi" % alto)
	t.ok(alto > ALTEZZA_CHIBI * 0.9,
			"…ma nemmeno un giocattolo: alto %.2f" % alto)
	t.ok(maxx - minx < 1.6 and maxz - minz < 1.6,
			"sta ragionevolmente nella sua cella (%.2f x %.2f)" % [maxx - minx, maxz - minz])

	# LA SEGGIOLA all'altezza giusta: e' l'ancoraggio su cui un giorno
	# si sedra' qualcuno, e se e' sbagliata il vicino galleggia
	var seggiola := n.find_child("Seggiola", true, false) as Node3D
	t.ok(seggiola != null, "c'e' l'ancoraggio della seduta")
	t.ok(seggiola.position.y > 0.2 and seggiola.position.y < 0.42,
			"…all'altezza di una seduta per chibi (%.2f)" % seggiola.position.y)
	t.ok(absf(seggiola.position.x) < 0.1,
			"…in mezzo alla poltrona, non di fianco")


## I PEZZI che fanno leggere «salone» e non «sedia»: lo specchio col suo
## vetro, la ghiera del pistone, i barattoli di colori DIVERSI.
func _test_i_pezzi(t) -> void:
	var n: Node3D = t.stage(CATALOGO._salone())
	var tori := 0
	var vetri := 0
	var lame := 0
	var tinte := {}
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh is TorusMesh:
			tori += 1
		var mat := m.material_override
		if mat is StandardMaterial3D:
			var sm := mat as StandardMaterial3D
			if sm.blend_mode == BaseMaterial3D.BLEND_MODE_ADD:
				lame += 1        # la lama di luce sul vetro
			elif sm.roughness < 0.2 and sm.metallic > 0.1:
				vetri += 1       # lo specchio
		elif mat is ShaderMaterial:
			var col = (mat as ShaderMaterial).get_shader_parameter("color_a")
			if col is Color:
				tinte[(col as Color).to_html(false)] = true
	t.ok(tori >= 3,
			"la cornice ovale, il poggiapiedi e gli anelli delle forbici sono tori (%d)" % tori)
	t.ok(vetri >= 1, "lo specchio ha un vetro vero (liscio e riflettente)")
	t.ok(lame >= 2,
			"…con la LAMA di luce in diagonale: e' quella che l'occhio legge come vetro")
	t.ok(tinte.size() >= 10,
			"il salone ha una tavolozza vera: %d tinte diverse" % tinte.size())


## LE COLLISIONI lasciano libero il DAVANTI: da li' ci si entra, e un
## giorno da li' ci si siede.
func _test_collisioni(t) -> void:
	var cols: Array = _voce().get("cols", [])
	t.ok(cols.size() >= 2, "il salone ferma i passi (%d volumi)" % cols.size())
	var davanti_libero := true
	for c in cols:
		var size: Vector3 = c[0]
		var pos: Vector3 = c[1]
		t.ok(size.y < 1.4,
				"nessun volume da grattacielo (alto %.2f)" % size.y)
		# il bordo davanti della cella e' z = +0.5
		if pos.z + size.z * 0.5 > 0.34:
			davanti_libero = false
	t.ok(davanti_libero,
			"il davanti resta libero: e' da li' che ci si avvicina alla poltrona")


## IL PUBBLICO DEL VANTO. Chi esce dal salone corre a farsi vedere dal
## vicino piu' vicino — ma l'ESTETISTA non puo' essere quel vicino: gli ha
## appena fatto la messa in piega, e correre a mostrargliela non e' una
## scena, e' un cortocircuito. Il commento su `_il_piu_vicino` diceva
## «escluso `tranne` e chi ci lavora» da sempre; il codice escludeva solo
## il cliente, e siccome durante la seduta l'estetista e' proprio quella
## li' accanto, era anche la piu' probabile a vincere.
##
## Comportamentale sul serio: si costruisce un finto Visitors con tre
## residenti veri in scena, si mette l'estetista IN MEZZO (la piu' vicina
## di tutte) e si guarda chi viene scelto.
func _test_il_pubblico_del_vanto(t) -> void:
	var SAL := load("res://scenes/interact/Salone.gd")
	var salone = t.stage(SAL.new())

	# un Visitors finto: serve solo che esponga `_residents`
	var src := GDScript.new()
	src.source_code = "extends Node\nvar _residents: Array = []\n"
	src.reload()
	var finto = t.stage(Node.new())
	finto.set_script(src)

	var posti := {"cliente": Vector3(0, 0, 0), "estetista": Vector3(1.0, 0, 0),
			"lontana": Vector3(4.0, 0, 0)}
	var residenti: Array = []
	for label in posti:
		var n := Node3D.new()
		n.name = str(label)
		t.stage(n)
		n.global_position = posti[label]
		residenti.append({"label": str(label), "node": n})
	finto.set("_residents", residenti)
	salone.set("_visitors", finto)
	salone.set("_estetista", "estetista")

	var scelto = salone.call("_il_piu_vicino", "cliente", Vector3.ZERO)
	t.ok(scelto != null, "qualcuno a cui farlo vedere c'e'")
	if scelto != null:
		t.eq(str(scelto.name), "lontana",
				"il vanto va a chi NON c'era: l'estetista e' piu' vicina (1 m"
				+ " contro 4) ma e' quella che gli ha appena fatto i capelli")

	# e senza estetista di turno, la piu' vicina torna a essere valida
	salone.set("_estetista", "")
	var scelto2 = salone.call("_il_piu_vicino", "cliente", Vector3.ZERO)
	t.eq(str(scelto2.name) if scelto2 != null else "", "estetista",
			"a salone chiuso nessuno e' escluso: vince davvero la piu' vicina")
