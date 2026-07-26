extends RefCounted
## I sentieri consumati: il terreno che ricorda i passi. Verifica headless
## (il viewport non renderizza qui, ma tutta la matematica dei passi è
## pura e statica, e il cablaggio si può esercitare):
##  • mappa mondo→tela: centro, angoli, fuori area;
##  • passi_fra: l'idle non lascia orme, il teletrasporto nemmeno, il
##    tragitto vero lascia una pesta continua (interpasso rispettato);
##  • il campionamento accumula orme per un camminatore vero e ignora chi
##    sta fermo o vola;
##  • il contratto con ground.gdshader: gli uniform sentieri_* esistono
##    nel sorgente e Sentieri li scrive con lo stesso nome;
##  • la tela copre il villaggio (almeno l'area dei ciuffi) e la memoria
##    va in user://;
##  • in headless NON si salva mai (il renderer dummy leggerebbe nero e
##    cancellerebbe la memoria vera del giocatore);
##  • CozyWorld monta il sistema (il cablaggio non si può perdere).

const SENTIERI := "res://scenes/world/Sentieri.gd"
const SHADER := "res://shaders/ground.gdshader"
const COZY := "res://scenes/world/CozyWorld.gd"


func run(t) -> void:
	var s: GDScript = load(SENTIERI)
	t.ok(s != null and s.can_instantiate(), "Sentieri.gd compila")
	if s == null or not s.can_instantiate():
		return

	_test_mappa(t, s)
	_test_passi(t, s)
	_test_campionamento(t, s)
	_test_contratto_shader(t, s)
	_test_copertura(t, s)
	_test_cablaggio(t)


func _test_mappa(t, s: GDScript) -> void:
	var area: Rect2 = s.AREA
	var centro := Vector3(area.position.x + area.size.x * 0.5, 0,
			area.position.y + area.size.y * 0.5)
	var uv: Vector2 = s.uv_di(centro)
	t.almost(uv.x, 0.5, "il centro dell'area mappa su u=0.5")
	t.almost(uv.y, 0.5, "il centro dell'area mappa su v=0.5")
	var px: Vector2 = s.px_di(centro)
	t.almost(px.x, s.RISOLUZIONE * 0.5, "…e sul pixel centrale", 0.5)
	var fuori: Vector2 = s.uv_di(Vector3(area.position.x - 1.0, 0, 0))
	t.ok(fuori.x < 0.0, "fuori area → sentinella negativa (niente orme)")
	var angolo: Vector2 = s.uv_di(Vector3(area.position.x + 0.01, 0,
			area.position.y + 0.01))
	t.ok(angolo.x >= 0.0 and angolo.x < 0.01, "l'angolo dell'area sta sulla tela")


func _test_passi(t, s: GDScript) -> void:
	var fermo: Array = s.passi_fra(Vector3.ZERO, Vector3(0.05, 0, 0.05))
	t.eq(fermo.size(), 0, "l'idle (sotto PASSO_MIN) non lascia orme")
	var teleport: Array = s.passi_fra(Vector3.ZERO, Vector3(8, 0, 0))
	t.eq(teleport.size(), 0, "il teletrasporto non disegna un tragitto")
	var da := Vector3(1, 0, 1)
	var a := Vector3(2.0, 0, 1)
	var passi: Array = s.passi_fra(da, a)
	t.ok(passi.size() >= 5, "un metro di cammino lascia una pesta fitta (%d)" % passi.size())
	# equidistanti e MAI più radi dell'interpasso; l'ultimo arriva a destinazione
	var prev := da
	var ok_spacing := true
	for p in passi:
		if Vector2(p.x - prev.x, p.z - prev.z).length() > float(s.INTERPASSO) + 0.001:
			ok_spacing = false
		prev = p
	t.ok(ok_spacing, "le orme sono fitte almeno quanto l'interpasso")
	t.almost((passi.back() as Vector3).x, a.x, "l'ultima orma tocca la destinazione")


func _test_campionamento(t, s: GDScript) -> void:
	var sent = t.stage(s.new())
	var walker := t.stage(Node3D.new()) as Node3D

	sent.registra(walker, 0.5)
	walker.global_position = Vector3(0, 0, 0)
	sent._campiona()          # prima vista: memorizza, nessuna orma
	t.eq(sent._orme.size(), 0, "il primo campione non lascia orme (non è un passo)")

	walker.global_position = Vector3(1.0, 0, 0)
	sent._campiona()
	var n: int = sent._orme.size()
	t.ok(n >= 5, "un metro di cammino accumula orme (%d)" % n)

	sent._campiona()          # fermo: nessuna orma nuova
	t.eq(sent._orme.size(), n, "da fermo non si consuma il prato")

	walker.global_position = Vector3(1.0, 5.0, 0)   # in cielo/piani alti
	sent._campiona()
	walker.global_position = Vector3(2.0, 5.0, 0)
	sent._campiona()
	t.eq(sent._orme.size(), n, "sopra QUOTA_TERRA i passi non toccano il prato")

	# il camminatore doppio non si registra due volte
	sent.registra(walker, 0.5)
	var conti := 0
	for w in sent._camminatori:
		if w["node"] == walker:
			conti += 1
	t.eq(conti, 1, "registra() non duplica un camminatore")


func _test_contratto_shader(t, s: GDScript) -> void:
	var testo := FileAccess.get_file_as_string(SHADER)
	for u in ["sentieri_tex", "sentieri_origin", "sentieri_size"]:
		t.ok(testo.contains("uniform") and testo.contains(u),
				"ground.gdshader dichiara l'uniform %s" % u)
	# e Sentieri scrive ESATTAMENTE quei nomi (il patto non può divergere)
	var sorgente := FileAccess.get_file_as_string(SENTIERI)
	for u in ["\"sentieri_tex\"", "\"sentieri_origin\"", "\"sentieri_size\""]:
		t.ok(sorgente.contains(u), "Sentieri.gd imposta l'uniform %s" % u)
	# la sgranatura del bordo e la terra battuta esistono davvero
	t.ok(testo.contains("terra_battuta"), "lo shader ha il colore della terra battuta")


func _test_copertura(t, s: GDScript) -> void:
	var cozy: GDScript = load(COZY)
	if cozy != null:
		var tuft: Rect2 = cozy.TUFT_RECT
		t.ok((s.AREA as Rect2).encloses(tuft),
				"la tela dei sentieri copre tutto il prato dei ciuffi")
	t.ok(str(s.FILE_MEMORIA).begins_with("user://"),
			"la memoria dei sentieri vive in user://")
	t.ok(float(s.GUARIGIONE_GIORNO) > 0.0 and float(s.GUARIGIONE_GIORNO) < 0.2,
			"la guarigione è un soffio al giorno: i sentieri vissuti restano")

	# in headless salva() non deve MAI scrivere (leggerebbe una tela nera
	# e cancellerebbe la memoria vera): la guardia è nel codice, qui si
	# esercita il percorso senza effetti
	var sent = t.stage(s.new())
	sent._sporca = true
	sent.salva()
	t.ok(sent._sporca, "in headless la tela resta 'sporca': nessun salvataggio nero")


func _test_cablaggio(t) -> void:
	# CozyWorld deve montare i Sentieri: senza, il prato non ricorda nulla
	var testo := FileAccess.get_file_as_string(COZY)
	t.ok(testo.contains("Sentieri.gd"), "CozyWorld monta il sistema dei sentieri")
