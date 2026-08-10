extends RefCounted
## IL TERRENO VIETATO: dove un corpo non ci può camminare, e chi lo dice.
##
## `CozyWorld.terreno_vietato(cella)` è la porta da cui il mondo entra nel
## grafo dei varchi. Prima non c'era, e il buco aveva la forma esatta del
## fiume: `BuildSystem.place_cell` **rifiuta** una cella nel letto, quindi
## lì un muro non ci può essere per costruzione — il letto era il corridoio
## più sgombro della mappa, e la ricerca ci si infilava dentro ogni volta
## che doveva aggirare un recinto vicino alla riva. Misurato nel MainLevel
## vero: tre metri di strada diventavano nove, di cui 2,54 dentro l'acqua,
## col corpo sospeso quarantacinque centimetri sopra il pelo, per due
## secondi.
##
## Qui si prova la GEOGRAFIA (il grafo ha il suo caso in `test_varchi.gd`,
## e la scena vera sta in `tools/prova_fiume.gd`). CozyWorld si crea con
## `.new()` e non si mette MAI in scena: senza albero non scatta `_ready`,
## quindi non si costruisce il villaggio — e queste risposte non ne hanno
## bisogno, perché vengono tutte da costanti e da `WorldMath`.

const CW := preload("res://scenes/world/CozyWorld.gd")
const MATH := preload("res://scenes/world/WorldMath.gd")


func run(t) -> void:
	var w = CW.new()
	_il_prato_si_cammina(t, w)
	_il_letto_del_fiume_no(t, w)
	_dove_non_si_pianta_un_palo_non_si_posa_una_zampa(t, w)
	_lo_spigolo_bagnato(t, w)
	_lo_stagno(t, w)
	_la_parete_e_la_riva_est(t, w)
	_i_posti_veri_del_gioco(t, w)
	w.free()


## IL PRATO SI CAMMINA. Sembra ovvio ed è la metà più importante della
## prova: un predicato troppo largo non si vede mai — il vicino continua a
## camminare, semplicemente smette di poter girare attorno alle cose — e
## nessuna scena lo denuncia.
##
## I due riquadri non sono scelti a caso: il primo è dove si costruisce il
## villaggio, il secondo è il corridoio che si percorre ogni sera per
## andare al fuoco. Nessuno dei due sfiora lo stagno, e la prima stesura di
## questo caso li aveva presi più larghi — con dentro l'acqua — e li ha
## visti diventare rossi. Bene così: era il caso a sbagliare mira, non il
## mondo.
func _il_prato_si_cammina(t, w) -> void:
	var vietate := 0
	for x in range(-14, 15):
		for z in range(0, 15):
			if bool(w.terreno_vietato(Vector2i(x, z))):
				vietate += 1
	t.eq(vietate, 0, "in tutto il villaggio non c'è una cella vietata")

	# il tragitto della sera: dalla piazza (2.5, 5.5) alla radura (−1, −46),
	# con quattro metri di scarto per parte — lo spazio in cui la rotta può
	# girare attorno a quel che il giocatore ha costruito
	var sul_tragitto := 0
	for z in range(-52, 8):
		for x in range(-4, 5):
			if bool(w.terreno_vietato(Vector2i(x, z))):
				sul_tragitto += 1
	t.eq(sul_tragitto, 0,
			"e nemmeno una lungo i cinquantasei metri che portano al falò")


## IL LETTO DEL FIUME NO. Il corso si sposta con la z (`WorldMath.river_x`),
## quindi non si guarda una colonna fissa: si guarda **il centro del fiume
## a quella quota**, che è dove l'acqua c'è per definizione.
func _il_letto_del_fiume_no(t, w) -> void:
	var asciutte := 0
	for z in range(-40, 40, 4):
		var cx := roundi(MATH.river_x(float(z)))
		if not bool(w.terreno_vietato(Vector2i(cx, z))):
			asciutte += 1
	t.eq(asciutte, 0, "in mezzo al fiume non si cammina, a nessuna quota")


## DOVE NON SI PIANTA UN PALO NON SI POSA UNA ZAMPA. È il legame con
## `BuildSystem.place_cell`, che rifiuta una cella se `is_river` dice sì:
## la stessa domanda, la stessa risposta. Se un giorno le due divergessero,
## esisterebbero celle su cui si può costruire un muro e non camminarci —
## o, peggio, il contrario.
func _dove_non_si_pianta_un_palo_non_si_posa_una_zampa(t, w) -> void:
	var scappate := 0
	var contate := 0
	for z in range(-50, 50):
		for x in range(10, 30):
			if not bool(w.is_river(Vector3(x, 0, z))):
				continue
			contate += 1
			if not bool(w.terreno_vietato(Vector2i(x, z))):
				scappate += 1
	t.ok(contate > 300, "ci sono celle di letto da controllare (%d)" % contate)
	t.eq(scappate, 0,
			"ogni cella in cui place_cell rifiuta un palo è anche vietata al passo")


## LO SPIGOLO BAGNATO, ed è il motivo per cui non basta il centro. Una
## cella è larga un metro e un corpo la attraversa tutta: esistono celle il
## cui CENTRO è fuori dal letto e il cui spigolo è già dentro, dove il prato
## è scavato di quaranta centimetri. Quelle devono essere vietate lo stesso.
func _lo_spigolo_bagnato(t, w) -> void:
	var trovate := 0
	var sbagliate := 0
	for z in range(-50, 50):
		for x in range(10, 30):
			var centro_asciutto := not bool(w.is_river(Vector3(x, 0, z)))
			var spigolo_bagnato := bool(w.is_river(Vector3(x - 0.5, 0, z))) \
					or bool(w.is_river(Vector3(x + 0.5, 0, z)))
			if not (centro_asciutto and spigolo_bagnato):
				continue
			trovate += 1
			if not bool(w.terreno_vietato(Vector2i(x, z))):
				sbagliate += 1
	t.ok(trovate > 50,
			"esistono celle col centro asciutto e lo spigolo nel letto (%d)" % trovate)
	t.eq(sbagliate, 0, "e sono vietate tutte: mezza cella conta come tutta")


## LO STAGNO. Il fiume è un nastro, lo stagno un'ellisse (il disco d'acqua
## è costruito con scale.x = 1.15): chi lo misurasse tondo lascerebbe
## camminare sull'acqua a est e a ovest. La forma la conosce
## `distanza_dall_acqua`, e qui si verifica che chi la interroga la usi.
func _lo_stagno(t, w) -> void:
	var c: Vector3 = w.POND_CENTER
	var r: float = w.POND_R
	t.ok(bool(w.terreno_vietato(Vector2i(roundi(c.x), roundi(c.z)))),
			"in mezzo allo stagno non si cammina")
	# il bordo dell'ellisse, dove è più larga (x) e dove è più stretta (z)
	t.ok(bool(w.terreno_vietato(Vector2i(roundi(c.x + r * 1.05), roundi(c.z)))),
			"e nemmeno sul bordo lungo, dove l'ellisse arriva più in là")
	t.ok(bool(w.terreno_vietato(Vector2i(roundi(c.x), roundi(c.z + r * 0.9)))),
			"né su quello corto")
	# ma la riva sì: a tre metri buoni dall'acqua c'è prato
	t.ok(not bool(w.terreno_vietato(Vector2i(roundi(c.x), roundi(c.z + r + 3.0)))),
			"la riva a tre metri, invece, è prato e si cammina")


## LA PARETE E LA RIVA EST. Oltre il piede della scogliera il terreno sale
## di due metri e mezzo. Ma la riva fra il fiume e la parete dev'essere
## CAMMINABILE: è la passeggiata dove porta il ponte, e dichiararla vietata
## vorrebbe dire che il ponte non porta da nessuna parte.
func _la_parete_e_la_riva_est(t, w) -> void:
	var dentro_la_roccia := 0
	var riva_buona := 0
	var riva_contata := 0
	for z in range(-40, 40, 3):
		var wx: float = w.cliff_x_at(float(z))
		# due metri OLTRE il ciglio: lì c'è il pianoro, non il prato
		if not bool(w.terreno_vietato(Vector2i(roundi(wx + 2.0), z))):
			dentro_la_roccia += 1
		# e la riva, a metà strada fra il letto e la parete
		var meta := (MATH.river_x(float(z)) + 2.9 + wx) * 0.5
		if wx - (MATH.river_x(float(z)) + 2.9) < 3.0:
			continue      # alla cascata il canyon si pinza: lì riva non c'è
		riva_contata += 1
		if not bool(w.terreno_vietato(Vector2i(roundi(meta), z))):
			riva_buona += 1
	t.eq(dentro_la_roccia, 0, "oltre il ciglio della scogliera non si cammina")
	t.ok(riva_contata > 15, "ci sono quote in cui la riva est è larga (%d)" % riva_contata)
	t.eq(riva_buona, riva_contata,
			"e lì si cammina eccome: è la passeggiata dove porta il ponte")


## I POSTI VERI DEL GIOCO. Un predicato del terreno che vieti una cella in
## cui il gioco MANDA qualcuno non si vede subito — la rotta si limita a
## non trovarsi mai — ma è un guasto: quel vicino non potrà mai girare
## attorno a niente per arrivarci. Qui si fissano i due posti che stanno
## più vicini all'acqua di tutti.
func _i_posti_veri_del_gioco(t, w) -> void:
	# il posto da cui si guardano le rane (Visitors: POND_CENTER + POND_R + 0.9)
	var rane: Vector3 = w.POND_CENTER + Vector3(0, 0, w.POND_R + 0.9)
	t.ok(not bool(w.terreno_vietato(Vector2i(roundi(rane.x), roundi(rane.z)))),
			"il posto da cui si guardano le rane è terra buona")
	# e la radura del falò, che è la meta della sera
	var falo: Vector3 = w.CLEARING_CENTER
	t.ok(not bool(w.terreno_vietato(Vector2i(roundi(falo.x), roundi(falo.z)))),
			"e la radura del falò pure")
