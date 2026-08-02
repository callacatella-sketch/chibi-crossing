extends RefCounted
## SEDERSI — dove ci si siede, e cosa si guarda.
##
## `r_bench` era nato per la Panchina, e sollevava di 52 cm fissi. Chi lo
## chiamava per un altro mobile senza passargli il mobile (tre argomenti
## invece di quattro) non veniva sollevato affatto: il cliente del salone si
## accovacciava DENTRO la poltrona, il pubblico del concerto dentro l'alzata
## di pietra del primo scalino.
##
## Ora il mobile DICHIARA il suo punto col meta «seduta», e lo stato legge
## `_fire_look` per orientare chi si siede. Questo test tiene tre cose:
##  1. il punto dichiarato coincide con la SUPERFICIE VERA della mesh — è la
##     prova che ha stanato un errore mio (avevo copiato il centro della
##     scatola del feltro dimenticando il mezzo spessore);
##  2. chi si siede GUARDA quello che è venuto a guardare;
##  3. la Panchina, che il meta non ce l'ha, continua a funzionare col
##     vecchio sollevamento — o la correzione avrebbe rotto il pezzo per cui
##     lo stato era stato scritto.
##
## Senza queste prove il blocco si poteva cancellare tutto e la suite
## restava verde: era la critica del verificatore, ed era giusta.

const CAT := preload("res://scenes/build/BuildCatalog.gd")
const VIS := preload("res://scenes/npc/Visitor.gd")

## I posti a sedere del catalogo: pezzo → nome dell'ancoraggio.
const POSTI := {
	"Salone": "Seggiola",
	"Pianoforte": "Panchetta",
	"Gradinata": "Posto0",
}


func run(t) -> void:
	_test_il_punto_dichiarato_e_la_superficie_vera(t)
	_test_chi_si_siede_guarda(t)
	_test_la_panchina_non_si_rompe(t)


## IL PUNTO DICHIARATO È LA SUPERFICIE VERA. Un ancoraggio che sbaglia di
## un centimetro e mezzo fa affondare il corpo nel legno, e non si vede
## leggendo il codice: si misura dalle mesh.
func _test_il_punto_dichiarato_e_la_superficie_vera(t) -> void:
	var per_nome := {}
	for v in CAT.items():
		per_nome[str(v["name"])] = v
	for pezzo in POSTI:
		t.ok(per_nome.has(str(pezzo)), "il pezzo '%s' esiste" % pezzo)
		if not per_nome.has(str(pezzo)):
			continue
		var n: Node3D = t.stage((per_nome[str(pezzo)]["builder"] as Callable).call())
		var anc := n.find_child(str(POSTI[pezzo]), true, false) as Node3D
		t.ok(anc != null, "'%s' ha l'ancoraggio '%s'" % [pezzo, POSTI[pezzo]])
		if anc == null:
			n.free()
			continue
		t.ok(anc.has_meta("seduta"),
				"…e DICHIARA dove ci si siede: senza, `r_bench` solleva di 52 cm"
				+ " (la misura della Panchina) e il corpo finisce a mezz'aria")
		var seduta: Vector3 = anc.global_position + anc.get_meta("seduta", Vector3.ZERO)
		# la superficie vera: il punto più alto delle mesh sotto l'ancoraggio,
		# cercate in un raggio stretto attorno a lui
		var cima := -99.0
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null:
				continue
			var a: AABB = m.global_transform * m.mesh.get_aabb()
			var c := a.get_center()
			# STRETTO attorno all'ancoraggio: con un raggio generoso si
			# prende il bracciolo o lo schienale invece del sedile
			if absf(c.x - seduta.x) > 0.10 or absf(c.z - seduta.z) > 0.10:
				continue
			if a.position.y + a.size.y <= seduta.y + 0.02:
				cima = maxf(cima, a.position.y + a.size.y)
		if cima > -90.0:
			t.ok(absf(seduta.y - cima) < 0.03,
					"'%s': si siede a %.3f e la superficie è a %.3f (scarto %.3f)"
					% [pezzo, seduta.y, cima, absf(seduta.y - cima)])
		n.free()


## CHI SI SIEDE GUARDA QUELLO CHE È VENUTO A GUARDARE. `_fire_look` è il
## terzo argomento di `do_routine` e lo stato non lo leggeva: il pubblico
## del concerto restava girato come l'aveva lasciato l'ultimo passo, e il
## cliente del salone non guardava lo specchio.
func _test_chi_si_siede_guarda(t) -> void:
	var v: Node3D = t.stage(VIS.new())
	v.set("species", "chibi")
	v.set("mode", "resident")
	v._ready()
	var mobile := Node3D.new()
	v.add_child(mobile)
	mobile.position = Vector3(3.0, 0.0, 1.0)
	mobile.set_meta("seduta", Vector3(0, 0.31, 0))

	# si guarda un punto preciso: il corpo deve voltarsi verso quello
	var bersaglio := Vector3(3.0, 0.9, 5.0)
	v.set("_routine_aux", mobile)
	v.set("_fire_look", bersaglio)
	v.call("_enter_state", "r_bench")
	var yaw: float = v.get("_yaw")
	# il rig guarda −Z: l'avanti è (−sin yaw, 0, −cos yaw)
	var avanti := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var voluto := (bersaglio - mobile.global_position) * Vector3(1, 0, 1)
	t.ok(avanti.dot(voluto.normalized()) > 0.98,
			"seduto, guarda il punto che gli è stato dato (allineamento %.3f)"
			% avanti.dot(voluto.normalized()))

	# SENZA un punto da guardare si torna al vecchio comportamento: chi
	# passa Vector3.ZERO (la Panchina) conserva l'orientamento del mobile
	mobile.rotation.y = 0.7
	v.set("_fire_look", Vector3.ZERO)
	v.call("_enter_state", "r_bench")
	t.almost(float(v.get("_yaw")), 0.7 + PI,
			"…e senza, si mette come il mobile: la Panchina non cambia abitudini",
			0.001)


## LA PANCHINA NON SI ROMPE. È il pezzo per cui `r_bench` è stato scritto, e
## il meta non ce l'ha: deve continuare col sollevamento di sempre.
func _test_la_panchina_non_si_rompe(t) -> void:
	var per_nome := {}
	for v in CAT.items():
		per_nome[str(v["name"])] = v
	if not per_nome.has("Panchina"):
		t.ok(true, "(niente Panchina nel catalogo: niente da difendere)")
		return
	var n: Node3D = t.stage((per_nome["Panchina"]["builder"] as Callable).call())
	var trovato := false
	for c in n.find_children("*", "Node3D", true, false):
		if (c as Node3D).has_meta("seduta"):
			trovato = true
	t.ok(not trovato,
			"la Panchina NON dichiara un punto: usa il sollevamento di sempre")
	n.free()
	# e il valore di sempre è ancora scritto una volta sola, nello stato
	var src := _sorgente("res://scenes/npc/Visitor.gd")
	t.eq(src.count("Vector3(0, 0.52, 0.02)"), 1,
			"…e quel numero vive in UN posto solo — la costante. La seconda"
			+ " copia era in `_mount_bench`, ed è quella che il meta doveva"
			+ " abolire: adesso anche lui chiede al mobile.")
	t.ok(src.contains("SEDUTA_PREDEFINITA"),
			"e si chiama per nome, non si ricopia")


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""
