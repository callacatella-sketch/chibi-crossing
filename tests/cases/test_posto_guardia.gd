extends RefCounted
## IL POSTO DI GUARDIA: i tredici pezzi e il loro corredo.
##
## In un gioco che non punisce nessuno la stazione non è autorità: è il
## posto dove le cose perse tornano da chi le ha perse. Questi test
## tengono insieme le tre cose che si romperebbero in silenzio: che ogni
## pezzo si costruisca davvero (un builder che esplode si scopre solo
## piazzandolo), che il corredo non prometta pezzi inesistenti, e che i
## nomi restino ITALIANI — sono chiavi di village.json, non testo.

const CAT = preload("res://scenes/build/BuildCatalog.gd")
const ECONOMY = preload("res://scenes/ui/Economy.gd")
const VEGLIA = preload("res://scenes/npc/Veglia.gd")

const PEZZI := ["Guardiola", "Insegna guardia", "Sbarra", "Bancone guardia",
		"Armadio smarriti", "Bacheca avvisi", "Attaccapanni", "Brandina",
		"Lanterna blu", "Cono", "Transenna", "Bicicletta", "Cassetta smarriti"]


func run(t) -> void:
	_test_i_pezzi_esistono(t)
	_test_si_costruiscono_davvero(t)
	_test_il_corredo(t)
	_test_nomi_e_collisioni(t)
	_test_la_garitta_si_abita(t)
	_test_il_turno_di_giorno(t)


func _test_i_pezzi_esistono(t) -> void:
	var per_nome := _catalogo()
	for n in PEZZI:
		t.ok(per_nome.has(n), "«%s» è nel catalogo" % n)
	t.eq(PEZZI.size(), 13, "tredici pezzi: un posto di guardia intero")


## Un builder si rompe solo quando qualcuno lo piazza — cioè in mano al
## giocatore. Qui si costruiscono TUTTI davvero, e si controlla che
## producano geometria vera invece di un nodo vuoto.
func _test_si_costruiscono_davvero(t) -> void:
	var per_nome := _catalogo()
	for n in PEZZI:
		var voce: Dictionary = per_nome.get(n, {})
		if voce.is_empty():
			continue
		var nodo = (voce["builder"] as Callable).call()
		t.ok(nodo != null, "«%s» costruisce un nodo" % n)
		if nodo == null:
			continue
		var mesh := _conta_mesh(nodo)
		t.ok(mesh >= 3, "«%s» ha geometria vera (%d mesh)" % [n, mesh])
		# niente pezzi che sprofondano o galleggiano: l'aabb deve toccare
		# terra e restare dentro una cella e mezza
		var aabb := _ingombro(nodo)
		t.ok(aabb.position.y > -0.35,
				"«%s» non sprofonda sottoterra (y=%.2f)" % [n, aabb.position.y])
		t.ok(aabb.size.x < 2.2 and aabb.size.z < 2.2,
				"«%s» sta nel villaggio (%.1f x %.1f)" % [n, aabb.size.x, aabb.size.z])
		nodo.free()


## Il corredo: comprare la guardiola porta con sé le sue cose. Se una
## voce del corredo non esiste nel catalogo, il giocatore paga e sblocca
## un pezzo fantasma — e non se ne accorge nessuno.
func _test_il_corredo(t) -> void:
	var per_nome := _catalogo()
	t.ok(ECONOMY.CORREDO.has("Guardiola"),
			"la guardiola ha un corredo: un posto arriva con le sue cose")
	var corredo: Array = ECONOMY.CORREDO["Guardiola"]
	for n in corredo:
		t.ok(per_nome.has(str(n)),
				"il corredo promette «%s», e il catalogo ce l'ha" % n)
	t.eq(corredo.size(), PEZZI.size() - 1,
			"tutto il posto tranne la guardiola stessa (%d pezzi)" % corredo.size())
	t.ok(not "Guardiola" in corredo,
			"la guardiola non è nel proprio corredo (si sbloccherebbe da sola)")
	# e la guardiola dev'essere comprabile, o il corredo non arriva mai
	var in_negozio := false
	for p in ECONOMY.SHOP_PIECES:
		if str(p["name"]) == "Guardiola":
			in_negozio = true
			t.ok(int(p["cost"]) > 0, "la guardiola ha un prezzo")
	t.ok(in_negozio, "la guardiola sta sul banco del mercante")


## I nomi dei pezzi sono ID: finiscono in village.json e nelle chiavi del
## corredo. Restano italiani per sempre — si traduce solo il display.
func _test_nomi_e_collisioni(t) -> void:
	var visti := {}
	var doppioni: Array = []
	for v in CAT.items():
		var n := str(v["name"])
		if visti.has(n):
			doppioni.append(n)
		visti[n] = true
	t.eq(doppioni.size(), 0,
			"nessun nome di pezzo doppio nel catalogo (%s)" % str(doppioni))
	for n in PEZZI:
		t.ok(n == n.strip_edges() and not n.contains("  "),
				"«%s» è un id pulito" % n)


## LA GARITTA SI ABITA. La guardiola non è un soprammobile: chi fa la
## guardia ci ENTRA (il varco sul retro dev'essere libero dalle
## collisioni) e ci sta di turno (il nodo "PostoGuardia" è dove la
## Veglia lo manda). Questi controlli si rompono se qualcuno richiude
## la garitta in una scatola piena — e se ne accorgerebbe solo chi
## vede la guardia sbattere il muso contro il proprio posto di lavoro.
func _test_la_garitta_si_abita(t) -> void:
	var per_nome := _catalogo()
	var voce: Dictionary = per_nome.get("Guardiola", {})
	if voce.is_empty():
		return
	var nodo = (voce["builder"] as Callable).call()
	var posto = nodo.find_child("PostoGuardia", true, false)
	t.ok(posto != null, "la guardiola ha il suo PostoGuardia")
	if posto != null:
		var p: Vector3 = (posto as Node3D).position
		t.ok(absf(p.x) < 0.3 and absf(p.z) < 0.3,
				"il posto sta DENTRO la garitta (%.2f, %.2f)" % [p.x, p.z])
		t.ok(p.y >= 0.0 and p.y < 0.4, "…e a terra, non per aria (y=%.2f)" % p.y)
	# i nomi che altri sistemi cercano devono sopravvivere ai restyling
	t.ok(nodo.find_child("Lume", true, false) != null, "il lume azzurro c'è ancora")
	t.ok(nodo.find_child("Targa", true, false) != null, "la targa c'è ancora")
	nodo.free()
	# le collisioni: cave. Il varco sul retro LIBERO (tre punti lungo la
	# strada d'ingresso), il fronte e i fianchi solidi.
	var cols: Array = voce.get("cols", [])
	t.ok(cols.size() >= 4, "la garitta cava ha più scatole di collisione (%d)" % cols.size())
	for punto in [Vector3(0, 0.5, 0.6), Vector3(0, 0.5, 0.3), Vector3(0, 0.5, 0.0)]:
		t.ok(not _dentro_una_scatola(punto, cols),
				"la strada d'ingresso è libera a z=%.1f" % punto.z)
	t.ok(_dentro_una_scatola(Vector3(0, 0.9, -0.44), cols), "il fronte è solido")
	t.ok(_dentro_una_scatola(Vector3(-0.44, 0.9, 0), cols), "i fianchi sono solidi")


## IL TURNO DI GIORNO. La finestra oraria è una funzione pura della
## Veglia: dentro l'orario la guardia sta in garitta, fuori no — e il
## turno deve FINIRE prima che cominci la ronda, o i due richiami se
## la strattonano a vicenda.
func _test_il_turno_di_giorno(t) -> void:
	t.ok(not VEGLIA.in_orario_di_turno(0.2), "all'alba non si è ancora di turno")
	t.ok(VEGLIA.in_orario_di_turno(0.5), "a metà giornata sì")
	t.ok(not VEGLIA.in_orario_di_turno(0.8),
			"alla sera il turno ha già lasciato il posto alla ronda")
	t.ok(VEGLIA.ORA_TURNO_A <= VEGLIA.ORA_RONDA,
			"il turno finisce prima che la ronda cominci")


func _dentro_una_scatola(p: Vector3, cols: Array) -> bool:
	for c in cols:
		var size: Vector3 = c[0]
		var centro: Vector3 = c[1]
		var d := p - centro
		if absf(d.x) <= size.x * 0.5 and absf(d.y) <= size.y * 0.5 \
				and absf(d.z) <= size.z * 0.5:
			return true
	return false


func _catalogo() -> Dictionary:
	var out := {}
	for v in CAT.items():
		out[str(v["name"])] = v
	return out


func _conta_mesh(n: Node) -> int:
	var c := 0
	if n is MeshInstance3D:
		c += 1
	for f in n.get_children():
		c += _conta_mesh(f)
	return c


## L'ingombro reale del pezzo, unendo gli aabb di tutte le sue mesh nello
## spazio del pezzo (le trasformate dei figli comprese).
func _ingombro(n: Node3D) -> AABB:
	var out := AABB()
	var primo := true
	for mi in _tutte_le_mesh(n):
		var a: AABB = (mi as MeshInstance3D).mesh.get_aabb()
		var t := _trasformata_relativa(mi, n)
		var mondo := t * a
		if primo:
			out = mondo
			primo = false
		else:
			out = out.merge(mondo)
	return out


func _tutte_le_mesh(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for f in n.get_children():
		out.append_array(_tutte_le_mesh(f))
	return out


func _trasformata_relativa(nodo: Node3D, radice: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur := nodo
	while cur != null and cur != radice:
		t = cur.transform * t
		cur = cur.get_parent() as Node3D
	return t
