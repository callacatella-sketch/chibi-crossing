extends SceneTree
## IL PETTEGOLEZZO CHE ARRIVA AL CORPO — la sola prova che conta.
##
##   CHIBI_GOSSIP=/dove ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##       --script res://tools/prova_pettegolezzo.gd
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ ESISTE, VISTO CHE C'È GIÀ `test_pettegolezzo.gd`
## ────────────────────────────────────────────────────────────────────────
##
## La suite prova che dopo `racconta()` la riga compare nel grafo dell'altro
## con la bandiera giusta, l'intensità smorzata e il luogo intatto. Tutto
## vero, e tutto **dentro un dizionario**. Un pettegolezzo che vive solo lì
## non è un pettegolezzo: è un campo che cambia valore.
##
## Questa prova chiede l'unica cosa che il giocatore può vedere: **un vicino
## che NON C'ERA fa una cosa che poteva sapere solo per sentito dire.**
## Mochi annaffia un'aiuola all'altro capo dell'orto mentre lui è dall'altra
## parte del villaggio; nessuno gli dice niente, nessun toast, nessuna
## lettera; poi incontra chi c'era, si scambiano una nuvoletta, e il giorno
## dopo va ad annaffiare **quella** aiuola — che non ha mai visto.
##
## E prova anche il suo contrario, che è la metà che tiene in piedi l'altra:
## **una notizia non è un broadcast.** Chi l'ha sentita dire non la ripassa,
## quindi il terzo vicino resta senza. Senza questa metà, in un villaggio da
## ventotto abitanti in mezz'ora saprebbero tutti tutto, e «l'ha saputo da
## qualcuno» smetterebbe di voler dire qualcosa.
##
## ────────────────────────────────────────────────────────────────────────
## LA COSA DA SAPERE PRIMA DI DIRE «NON FUNZIONA»
## ────────────────────────────────────────────────────────────────────────
##
## **La conseguenza del passaparola è LOCALE per costruzione.** L'ancora di
## un ricordo si sposta al massimo di `Visitors.SPOSTA_MAX` (6 m) da casa
## propria, e da lì si cerca un'aiuola dentro `RAGGIO_AIUOLA` (14 m): un
## fatto raccontato a chi abita dall'altra parte del villaggio NON lo fa
## attraversare il villaggio, e non deve — sarebbe il guinzaglio che la
## regola 5 vieta, con l'aggravante di essere telecomandato da un terzo.
## Perciò qui chi non c'era **abita vicino all'orto** ma in quel momento era
## altrove: è la situazione che il gioco produce da solo venti volte al
## giorno, non un caso costruito.

const BANCO := preload("res://tools/banco.gd")
const VISITOR := preload("res://scenes/npc/Visitor.gd")

# ---------------------------------------------------------------- il villaggio
const CASA_A := Vector2i(4, 6)      # chi c'era
const CASA_B := Vector2i(9, 4)      # chi NON c'era (ma abita vicino all'orto)
const CASA_C := Vector2i(-6, 10)    # il terzo, quello che non deve sapere niente

const AIUOLA_VISTA := Vector2i(12, 9)    # quella che Mochi annaffia
const AIUOLA_DI_B := Vector2i(6, 2)      # 3.6 m da casa B: la sua scelta naturale
const AIUOLA_DI_A := Vector2i(2, 4)      # 2.8 m da casa A

const MOCHI_ORTO := Vector3(12.9, 0, 9.9)
const MOCHI_VIA := Vector3(-22, 0, -16)

## Dove sta chi c'era, mentre il gesto accade: 6 m dall'aiuola.
const TESTIMONE := Vector3(15.0, 0, 3.8)
## E dove stanno gli altri due: fuori dai nove metri, di parecchio.
const ALTROVE_B := Vector3(-16.0, 0, 22.0)
const ALTROVE_C := Vector3(-20.0, 0, 6.0)

## Dove si incontrano. Sotto casa di B, sul lato aperto.
const INCONTRO := Vector3(9.0, 0, 1.0)

## Il quadro che contiene TUTTE E DUE le aiuole e la casa di B: la stessa
## inquadratura prima e dopo, o il confronto non vale niente.
const QUADRO := Vector3(9.0, 0, 5.5)

var b


func _init() -> void:
	_go()


func _m(c: Vector2i) -> Vector3:
	return Vector3(c.x, 0, c.y)


func _ricordi(r: Dictionary) -> Array:
	var g: Dictionary = b.cuore.call("debug_grafo", int(r["ecs"]))
	return g.get("ricordi", [])


func _sentiti(r: Dictionary) -> int:
	var n := 0
	for riga in _ricordi(r):
		if (int((riga as Dictionary)["bandiere"]) & int(b.cuore.R_SENTITO)) != 0:
			n += 1
	return n


func _riassetta_le_aiuole() -> void:
	for a in [AIUOLA_VISTA, AIUOLA_DI_B, AIUOLA_DI_A]:
		b.garden.call("debug_set_stage", a, 1, false)


func _posa_villaggio() -> bool:
	for c in [CASA_A, CASA_B, CASA_C]:
		b.build.call("place_cell", c, "Letto", 0, false)
		b.build.call("place_cell", c, "Tetto", 0, false)
	for a in [AIUOLA_VISTA, AIUOLA_DI_B, AIUOLA_DI_A]:
		b.build.call("place_cell", a, "Aiuola", 0, false)
	b.build.call("aggiorna_varchi_ora")
	await create_timer(1.0).timeout
	# assetate SENZA seminarle: `Garden._plant` emette a sua volta sul bus
	# della percezione, e la semina finirebbe nella memoria di tutti
	_riassetta_le_aiuole()
	b.dico((b.build.call("get_placed_by_name", "Aiuola") as Array).size() == 3,
			"le tre aiuole ci sono")

	b.visitors.call("debug_reset")
	b.visitors.call("debug_settle", 4242, CASA_A)
	b.visitors.call("debug_settle", 7171, CASA_B)
	b.visitors.call("debug_settle", 9393, CASA_C)
	await create_timer(1.5).timeout
	var residenti: Array = b.visitors.get("_residents")
	if residenti.size() != 3:
		print("GUASTO: servono tre residenti, ce ne sono %d" % residenti.size())
		return false
	b.cuore = b.visitors.call("cuore")
	if b.cuore == null:
		print("GUASTO: il cuore ECS non c'è (GDExtension non caricata?)")
		return false
	for r in residenti:
		if not (r as Dictionary).has("ecs"):
			print("GUASTO: un residente non è stato censito nell'ECS")
			return false
	return true


## Il chiacchiericcio d'ambiente si zittisce a mano ogni volta che due corpi
## stanno per avvicinarsi. Non è per comodità: `_chats` accoppia da solo
## chiunque stia sotto 1,9 m, una coppia ogni 3,5 s, e la notizia
## passerebbe LÌ — un istante prima della chiacchierata che stiamo per
## guardare, e nella nuvoletta uscirebbe un tema qualunque. (È successo:
## la prima stesura della prova sorella si dichiarava rotta per questo.)
func _zitti() -> void:
	b.visitors.set("_chat_acc", 99.0)


## Chiacchierata fra DUE PRECISI. `debug_force_activity` ha l'indice,
## `debug_force_chat` no: prende sempre i primi due del registro, e qui
## servono due coppie diverse (chi c'era → chi non c'era, e poi chi non
## c'era → il terzo, che è la prova che la notizia NON riparte).
func _chiacchierata(a: Node3D, c: Node3D) -> void:
	_zitti()
	b.visitors.call("_run_chat", a, c)


func _dove_va(r: Dictionary) -> Vector3:
	return b.meta((r as Dictionary)["node"] as Node3D)


func _go() -> void:
	b = BANCO.new(self, OS.get_environment("CHIBI_GOSSIP"))
	if not await b.apri():
		quit(1)
		return
	if not await _posa_villaggio():
		quit(1)
		return
	var rr: Array = []
	for r in (b.visitors.get("_residents") as Array):
		rr.append(r)
	var ra := rr[0] as Dictionary      # c'era
	var rb := rr[1] as Dictionary      # NON c'era
	var rc := rr[2] as Dictionary      # il terzo
	var na := ra["node"] as Node3D
	var nb := rb["node"] as Node3D
	var nc := rc["node"] as Node3D
	print("=== c'era: %s · non c'era: %s · il terzo: %s ==="
			% [ra["label"], rb["label"], rc["label"]])
	_zitti()

	# ============================================ 1) prima: ognuno la sua aiuola
	print("\n--- 1) prima di tutto: chi non c'era annaffia l'aiuola di casa sua ---")
	b.player.global_position = MOCHI_VIA
	await b.porta(0, _m(CASA_A))
	await b.porta(2, ALTROVE_C)
	_riassetta_le_aiuole()
	await b.porta(1, _m(CASA_B))
	b.visitors.call("debug_force_activity", 1, "cura_giardino")
	await create_timer(0.6).timeout
	var meta_prima := _dove_va(rb)
	print("       va verso %s (la sua di casa %s a %.1f m · quella dell'orto %s a %.1f m)"
			% [meta_prima, _m(AIUOLA_DI_B),
			_m(CASA_B).distance_to(_m(AIUOLA_DI_B)), _m(AIUOLA_VISTA),
			_m(CASA_B).distance_to(_m(AIUOLA_VISTA))])
	b.dico(meta_prima.distance_to(_m(AIUOLA_DI_B)) < 1.6,
			"senza sapere niente, sceglie l'aiuola più vicina a casa sua")
	await b.aspetta(nb, "tk_water")
	# «a destra» e non «a sinistra»: la camera guarda verso +Z, e una lente
	# che guarda in quel verso RIBALTA l'asse X sullo schermo (il destro
	# della camera diventa −X). Le didascalie si scrivono guardando
	# l'immagine, non ragionando sulle coordinate.
	b.targa("PRIMA — chi non c'era annaffia l'aiuola sotto casa (in basso a destra)")
	await b.scatta(QUADRO + Vector3(0, 0.4, 0), QUADRO + Vector3(0, 4.6, -7.6),
			"1a-prima-aiuola-di-casa")
	b.targa("")

	# ================================================= 2) il gesto, e chi lo vede
	print("\n--- 2) Mochi annaffia l'aiuola dell'orto: uno c'è, gli altri due no ---")
	_riassetta_le_aiuole()
	await b.porta(0, TESTIMONE)
	await b.porta(1, ALTROVE_B)
	await b.porta(2, ALTROVE_C)
	b.player.global_position = MOCHI_ORTO
	await create_timer(0.6).timeout
	var bersaglio := _m(AIUOLA_VISTA)
	print("       distanze dal gesto: c'era %.1f m · non c'era %.1f m · il terzo %.1f m"
			% [bersaglio.distance_to(na.global_position),
			bersaglio.distance_to(nb.global_position),
			bersaglio.distance_to(nc.global_position)])
	var aiuola: Node3D = b.garden.call("bed_needing_water", bersaglio, 0.9)
	if aiuola == null:
		b.dico(false, "l'aiuola da annaffiare esiste")
		quit(b.verdetto("PETTEGOLEZZO"))
		return
	b.garden.call("_water", aiuola)
	await create_timer(1.2).timeout
	b.targa("il gesto: uno solo lo vede, e gira la testa")
	await b.scatta_come_in_gioco("2a-il-gesto")
	b.targa("")
	print("       ricordi: c'era %d · non c'era %d · il terzo %d"
			% [_ricordi(ra).size(), _ricordi(rb).size(), _ricordi(rc).size()])
	b.dico(_ricordi(ra).size() == 1, "chi c'era se lo ricorda")
	b.dico(_ricordi(rb).size() == 0, "chi non c'era non sa niente")
	b.dico(_ricordi(rc).size() == 0, "e il terzo nemmeno")

	# ================================================= 3) la chiacchierata
	print("\n--- 3) si incontrano, e uno racconta ---")
	var a_pos := INCONTRO + Vector3(-0.6, 0, 0.6)
	var c_pos := INCONTRO + Vector3(0.6, 0, -0.6)
	var verso := (c_pos - a_pos).normalized()
	b.inchioda(ra, a_pos, atan2(-verso.x, -verso.z))
	b.inchioda(rb, c_pos, atan2(verso.x, verso.z))
	# il terzo va inchiodato lontano: lasciato libero cammina, entra in
	# quadro e ci porta la SUA nuvoletta — in una prova sul passaparola è la
	# cosa che la rende illeggibile
	b.inchioda(rc, ALTROVE_C, 0.0)
	await create_timer(0.6).timeout
	_chiacchierata(na, nb)
	await create_timer(0.45).timeout
	# camera all'ALTEZZA DELLE TESTE e vicina: le nuvolette stanno appena
	# sopra il testone, e da un punto più alto finiscono contro il prato
	# (bianco su giallo). Da qui si stagliano sul cielo.
	var perp := verso.rotated(Vector3.UP, PI * 0.5)
	var centro := INCONTRO + Vector3(0, 1.0, 0)
	var occhio := INCONTRO + perp * 2.6 + Vector3(0, 1.05, 0)
	b.targa("chi c'era racconta: nella nuvoletta il fiore")
	await b.scatta(centro, occhio, "3a-chiacchierata")
	await create_timer(0.95).timeout   # la risposta arriva a 1,1 s
	b.targa("…e chi non c'era risponde")
	await b.scatta(centro, occhio, "3b-chiacchierata-risposta")
	b.targa("")
	b.affianca(["3a-chiacchierata", "3b-chiacchierata-risposta"], "3-provino-chiacchierata")

	var righe: Array = _ricordi(rb)
	var sentito := {}
	for riga in righe:
		if (int((riga as Dictionary)["bandiere"]) & int(b.cuore.R_SENTITO)) != 0:
			sentito = riga
	print("       adesso chi non c'era ha %d ricordi, di cui sentiti %d"
			% [righe.size(), _sentiti(rb)])
	b.dico(righe.size() == 1 and not sentito.is_empty(),
			"si porta via UNA notizia, e per sentito dire")
	if not sentito.is_empty():
		var nome := str(b.cuore.call("nome_cosa", int(sentito["cosa"])))
		print("       la cosa è «%s», il simbolo «%s», il posto (%.1f, %.1f)"
				% [nome, str(VISITOR.LP_SIMBOLI.get(nome, "?")),
				float(sentito["px"]), float(sentito["pz"])])
		b.dico(nome == "fiore", "e la cosa è il fiore, cioè quel che è successo")
		# la SOGLIA arriva dal chiamante, come in partita
		# (`Visitors._ancora_ricordo`): senza, questa riga chiamava `dove()`
		# con tre argomenti e il banco moriva a metà — cioè restava appeso
		# per sempre, perché `quit()` non veniva mai chiamato.
		var dove_sa: Vector3 = b.cuore.call("dove", int(rb["ecs"]),
				b.cuore.C_FIORE, float(b.visitors.get("AMMIRA_SOGLIA")),
				Vector3.ZERO)
		b.dico(dove_sa.distance_to(bersaglio) < 0.6,
				"e il POSTO attraversa il passaparola intatto")

	# =========================== 4) e adesso il corpo: va dove non è mai stato
	print("\n--- 4) …e va ad annaffiare l'aiuola che non ha mai visto ---")
	b.sfila()
	b.player.global_position = MOCHI_VIA     # nessuna ammirazione in ballo:
	_riassetta_le_aiuole()                   # quel che segue può venire solo dal racconto
	await b.porta(0, _m(CASA_A))
	await b.porta(2, ALTROVE_C)
	await b.porta(1, _m(CASA_B))
	b.visitors.call("debug_force_activity", 1, "cura_giardino")
	await create_timer(0.6).timeout
	var meta_dopo := _dove_va(rb)
	print("       va verso %s (prima andava verso %s)" % [meta_dopo, meta_prima])
	b.dico(meta_dopo.distance_to(_m(AIUOLA_VISTA)) < 1.6,
			"chi non c'era va all'aiuola di cui gli hanno parlato")
	b.dico(meta_dopo.distance_to(meta_prima) > 3.0,
			"cioè un'ALTRA rispetto a quella di prima")
	var t = await b.aspetta(nb, "tk_water")
	print("       ci è arrivato dopo %.2f s, in %s" % [t, nb.global_position])
	b.dico(str(nb.get("_state")) == "tk_water",
			"e ci si mette davvero ad annaffiare — senza esserci mai stato")
	b.targa("DOPO — la stessa inquadratura: adesso è all'aiuola dell'orto, in alto a sinistra")
	await b.scatta(QUADRO + Vector3(0, 0.4, 0), QUADRO + Vector3(0, 4.6, -7.6),
			"4a-dopo-aiuola-raccontata")
	b.targa("")
	b.affianca(["1a-prima-aiuola-di-casa", "4a-dopo-aiuola-raccontata"],
			"4-provino-il-corpo-cambia-orto")

	# ============================ 5) e il terzo non lo viene a sapere da lui
	print("\n--- 5) il terzo: una notizia non è un broadcast ---")
	var terzo_prima := _ricordi(rc).size()
	b.inchioda(rb, INCONTRO + Vector3(-0.6, 0, 0.6), atan2(-verso.x, -verso.z))
	b.inchioda(rc, INCONTRO + Vector3(0.6, 0, -0.6), atan2(verso.x, verso.z))
	await create_timer(0.6).timeout
	_chiacchierata(nb, nc)
	await create_timer(1.2).timeout
	print("       il terzo aveva %d ricordi, adesso ne ha %d"
			% [terzo_prima, _ricordi(rc).size()])
	b.dico(_ricordi(rc).size() == 0,
			"chi l'ha saputo per sentito dire NON lo ripassa: il terzo resta senza")
	b.sfila()

	quit(b.verdetto("PETTEGOLEZZO"))
