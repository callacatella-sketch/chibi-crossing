extends SceneTree
## **IL «NON OGGI», nel MainLevel VERO.**
##
##   Godot --headless --path . --script res://tools/prova_non_oggi.gd
##
## La suite prova le regole; questo prova **la scena**. Un vicino con una
## paura vera accetta di essere accompagnato, cammina fin lì, si ferma sulla
## soglia — e poi decide. Le tre domande sono quelle che nessuna asserzione
## booleana sa fare, e ognuna ha un ORACOLO INDIPENDENTE: non si chiede ad
## `Accompagna` se è andata bene, si guarda il MONDO.
##
##  1. **il no si vede?** Si misura dove va il corpo nei secondi DOPO il
##     rifiuto. `manda()` scrive un lease di 45 s: se `_non_oggi` non lo
##     rompe, quello che il giocatore vede non è un rifiuto — è un fermo
##     immagine. Il metro sono i METRI percorsi, non una bandiera.
##  2. **il no scrive qualcosa?** Si contano le righe del libro mastro e i
##     marchi PRIMA e DOPO. Devono essere identici: un no non è un torto, e
##     il giocatore non deve avere niente da riparare.
##  3. **e il sì continua a funzionare?** La controprova, con la stessa
##     identica scena e una paura sotto il pavimento: si entra, come si è
##     sempre fatto. Un banco che prova solo il ramo nuovo non dice se ha
##     rotto quello vecchio.
##
## ⚠️ **E NON SI CHIAMA `ce_la_fa` A MANO.** Tutto passa dalla scena vera:
## `_comincia`, il cammino, la soglia, `_avanza`. Se il cablaggio non ci
## fosse, questo banco misurerebbe un corpo che entra sempre — che è
## esattamente il gioco di ieri, e non se ne accorgerebbe nessuno.

const CASA := Vector2i(6, 6)
const ALBERO_VICINO := Vector2i(10, 6)


func _initialize() -> void:
	_go()


func _riga(ok: bool, testo: String) -> void:
	print(("  ok      " if ok else "  GUASTO  ") + testo)


func _go() -> void:
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 8:
		await process_frame
	var livello := current_scene
	if livello == null:
		print("GUASTO: il MainLevel non si è caricato")
		quit(1)
		return
	var build := livello.get_node_or_null("BuildSystem")
	var visitors := livello.get_node_or_null("Visitors")
	# ⚠️ `Accompagna` è figlio RUNTIME di CozyWorld, che costruisce il mondo su
	# più frame: non sta sotto il livello e non c'è al primo frame. È la stessa
	# trappola del taccuino del Gufo e del Regista — si CERCA, e si riprova.
	var accompagna: Node = null
	for _t in 20:
		accompagna = _cerca_script(livello, "Accompagna.gd")
		if accompagna != null:
			break
		await create_timer(0.25).timeout
	if build == null or visitors == null or accompagna == null:
		print("GUASTO: build=%s visitors=%s accompagna=%s"
				% [build, visitors, accompagna])
		quit(1)
		return
	# ⚠️ il banco non tocca il salvataggio dell'autore: un banco altrui si è
	# già portato via due gigabyte.
	build.call("set_persist_for_debug", false)
	await create_timer(1.2).timeout

	visitors.call("debug_reset")
	build.call("place_cell", CASA, "Letto", 0, false)
	build.call("place_cell", CASA, "Tetto", 0, false)
	build.call("aggiorna_varchi_ora")
	visitors.call("debug_settle", 4242, CASA)
	await create_timer(1.0).timeout

	var residenti: Array = visitors.get("_residents")
	if residenti.is_empty():
		print("GUASTO: nessun residente insediato")
		quit(1)
		return
	var r: Dictionary = residenti[0]
	var label := str(r["label"])
	var corpo: Node3D = r["node"]
	var animo: RefCounted = visitors.call("animo_oggetto_di", label)
	if animo == null or corpo == null:
		print("GUASTO: animo o corpo assenti")
		quit(1)
		return

	print("\n=== IL «NON OGGI» — %s, nel MainLevel vero ===" % label)

	var esito_no := await _scena(livello, visitors, accompagna, animo, corpo,
			label, 6, "IL NO")
	var esito_si := await _scena(livello, visitors, accompagna, animo, corpo,
			label, 0, "IL SÌ (controprova)")

	print("\n=== VERDETTO ===")
	_riga(not esito_no["entrato"],
			"con una paura profonda, non entra: la soglia DECIDE")
	_riga(esito_no["metri_dopo"] > 0.5,
			("e il corpo si MUOVE: %.2f m nei %.1f s dopo il rifiuto (il "
			+ "lease è rotto — senza, sarebbe un fermo immagine)")
					% [esito_no["metri_dopo"], esito_no["attesa"]])
	_riga(esito_no["d_dopo"] > esito_no["d_prima"] + 0.05,
			("e se ne va NELLA DIREZIONE GIUSTA: %.2f → %.2f m dal posto "
			+ "(i metri da soli non dicono niente — si possono fare anche "
			+ "entrando nella catasta)")
					% [esito_no["d_prima"], esito_no["d_dopo"]])
	_riga(esito_no["incanto"] == "",
			("e non entra nell'incanto: un «%s» dopo un rifiuto mette l'«!» "
			+ "sopra la testa e un cuoricino all'uscita — cioè rende il no "
			+ "identico a un sì") % esito_no["incanto"])
	_riga(esito_no["righe_prima"] == esito_no["righe_dopo"],
			("e non scrive NIENTE nel libro mastro: %d righe prima, %d dopo"
			% [esito_no["righe_prima"], esito_no["righe_dopo"]]))
	_riga(abs(esito_no["carica_prima"] - esito_no["carica_dopo"]) < 0.001,
			("e non tocca il marchio del posto: %.4f prima, %.4f dopo — la "
			+ "paura resta esattamente quella che era")
					% [esito_no["carica_prima"], esito_no["carica_dopo"]])
	_riga(esito_no["posa_dopo"] == "sereno",
			("e non lascia NESSUNA posa addosso al corpo: «%s» sei secondi "
			+ "dopo (una posa stabile non se ne va da sola — resterebbe per "
			+ "il resto della partita)") % esito_no["posa_dopo"])
	_riga(esito_si["entrato"],
			"e sotto il pavimento si entra come sempre: il gioco di ieri è intatto")

	var tutto: bool = (not esito_no["entrato"]) and esito_no["metri_dopo"] > 0.5 \
			and esito_no["righe_prima"] == esito_no["righe_dopo"] \
			and abs(esito_no["carica_prima"] - esito_no["carica_dopo"]) < 0.001 \
			and esito_no["posa_dopo"] == "sereno" \
			and esito_no["d_dopo"] > esito_no["d_prima"] + 0.05 \
			and esito_no["incanto"] == "" \
			and esito_si["entrato"]
	print("")
	quit(0 if tutto else 1)


## Una scena intera, dal marchio alla soglia. `quanti` spaventi: 6 fa una
## paura profonda, 0 la lascia sotto il pavimento.
func _scena(livello: Node, visitors: Node, accompagna: Node,
		animo: RefCounted, corpo: Node3D, label: String,
		quanti: int, titolo: String) -> Dictionary:
	print("\n--- %s ---" % titolo)
	# si riparte puliti: la paura di prima è stata curata o no, e in ogni
	# caso il banco non deve ereditarla
	animo.limbico.visita_serena("catasta")
	animo.limbico.visita_serena("catasta")
	animo.limbico.visita_serena("catasta")
	for _i in quanti:
		animo.limbico.rivaluta("spavento", "qualcuno", -0.9, "catasta")
	var carica_prima: float = float(animo.limbico.carica_di("catasta"))
	var righe_prima: int = (animo.get("ricordi") as Array).size()
	print("  paura di «catasta»: %.3f   (soglia che ferma: %.2f)"
			% [absf(carica_prima), accompagna.get_script().PAURA_CHE_FERMA])
	print("  righe nel libro mastro: %d" % righe_prima)

	# ⚠️ **E SI RIPORTA IL CORPO INDIETRO.** Senza, la controprova parte con
	# il vicino gia' sul posto (distanza 0), passa dritta a "soglia" e non
	# cammina: proverebbe che si entra, non che si ARRIVA. Due scene che non
	# fanno la stessa strada non si confrontano.
	corpo.global_position = _casa_mondo(livello, corpo)
	await create_timer(0.4).timeout

	# ⚠️ IL GIOCATORE SI PRENDE DA DOVE LO PRENDE LA SCENA (`Accompagna._player`),
	# non da un gruppo: il gruppo «player» **non esiste** in questo gioco, e
	# cercarlo faceva arrossire il guardiano dei cablaggi in
	# `test_scena_cablaggi` — giustamente, perché un banco che interroga un
	# gruppo vuoto misura sempre `null` e non se ne accorge.
	var giocatore: Node3D = accompagna.get("_player") as Node3D
	# Mochi accanto a lui: la soglia chiede che il giocatore sia lì
	if giocatore != null:
		giocatore.global_position = corpo.global_position + Vector3(1.2, 0, 0)

	accompagna.call("_comincia", label, "catasta")
	var scena: Dictionary = accompagna.get("_scena")
	if scena.is_empty():
		print("  GUASTO: la scena non è partita (posizione del luogo ignota?)")
		return {"entrato": false, "metri_dopo": 0.0, "attesa": 0.0,
				"posa_dopo": "sereno", "d_prima": 0.0, "d_dopo": 0.0,
				"incanto": "",
				"righe_prima": righe_prima, "righe_dopo": righe_prima,
				"carica_prima": carica_prima, "carica_dopo": carica_prima}

	# --- si cammina, e il giocatore resta accanto (come farebbe lui)
	var fase := ""
	var t := 0.0
	while t < 40.0:
		await process_frame
		t += get_root().get_process_delta_time()
		var s: Dictionary = accompagna.get("_scena")
		if s.is_empty():
			break
		if giocatore != null:
			giocatore.global_position = corpo.global_position + Vector3(1.2, 0, 0)
		var f := str(s.get("fase", ""))
		if f != fase:
			fase = f
			print("  %5.1f s   fase → %s   (a %.1f m dal posto)"
					% [t, f, corpo.global_position.distance_to(s["pos"])])
		if f == "insieme" or f == "no":
			break

	var s2: Dictionary = accompagna.get("_scena")
	var entrato := (not s2.is_empty()) and str(s2.get("fase", "")) == "insieme"
	# il posto temuto, in coordinate del mondo: l'oracolo della direzione
	var meta_posto: Vector3 = scena["pos"]
	print("  esito: %s" % ("ENTRA" if entrato else "NON OGGI"))

	# --- ⚠️ **L'ORACOLO È LA DIREZIONE, NON I METRI — e la prima stesura di
	#     questo banco misurava i metri, cioè mi ha dato il verde su un
	#     guasto grosso.** `libera()` restituisce la giornata ma non tocca il
	#     CAMMINO: `manda()` aveva fatto `do_task("wonder", pos)`, e al
	#     verdetto mancano ancora due metri di strada verso il posto. Il
	#     corpo li percorreva — cioè entrava nella catasta che aveva appena
	#     rifiutato — e «1,88 m percorsi» passava l'oracolo come «se n'è
	#     andato». Si guarda se la distanza dal posto CRESCE.
	var partenza: Vector3 = corpo.global_position
	var d_prima: float = corpo.global_position.distance_to(meta_posto)
	var stato_visto := ""
	var attesa := 6.0
	var u := 0.0
	while u < attesa:
		await process_frame
		u += get_root().get_process_delta_time()
		var st := str(corpo.get("_state"))
		if st == "tk_wonder":
			stato_visto = st
	var metri: float = partenza.distance_to(corpo.global_position)
	var d_dopo: float = corpo.global_position.distance_to(meta_posto)
	print("  il corpo ha fatto %.2f m nei %.1f s dopo" % [metri, attesa])
	print("  distanza DAL POSTO: %.2f m → %.2f m   (%s)"
			% [d_prima, d_dopo,
			"si ALLONTANA" if d_dopo > d_prima + 0.05 else "SI AVVICINA"])
	if stato_visto != "":
		print("  ⚠️ ed è entrato in «%s» — lo stato dell'incanto, con l'«!» "
				% stato_visto + "sopra la testa e il cuoricino all'uscita")

	# --- ⚠️ **IL CANCELLO CHE MANCAVA: cos'ha ADDOSSO il corpo, dopo.**
	#     «Un no non scrive niente» non vale solo per il libro mastro: vale
	#     per il CORPO. Una posa STABILE (quelle di `Visitor.RECITA` che non
	#     sono transitorie) resta finche' qualcuno non toglie il meta — e sei
	#     secondi dopo un rifiuto non c'e' nessuno che lo tolga. Sarebbe un
	#     vicino curvo per il resto della partita, cioe' il guasto che il
	#     commento di `_recita_applica` racconta gia' come gia' pagato.
	var posa := ""
	if corpo.has_method("postura_stabile"):
		posa = str(corpo.call("postura_stabile"))
	print("  posa stabile addosso al corpo: «%s»" % posa)

	return {
		"entrato": entrato, "metri_dopo": metri, "attesa": attesa,
		"posa_dopo": posa, "d_prima": d_prima, "d_dopo": d_dopo,
		"incanto": stato_visto,
		"righe_prima": righe_prima,
		"righe_dopo": (animo.get("ricordi") as Array).size(),
		"carica_prima": carica_prima,
		"carica_dopo": float(animo.limbico.carica_di("catasta")),
	}


## Cerca in TUTTO l'albero un nodo il cui script finisce così: i collaboratori
## di questo gioco nascono su più frame e in posti diversi.
func _cerca_script(radice: Node, coda: String) -> Node:
	if radice.get_script() != null and \
			str(radice.get_script().resource_path).ends_with(coda):
		return radice
	for f in radice.get_children():
		var t := _cerca_script(f, coda)
		if t != null:
			return t
	return null


## La cella di casa in coordinate del mondo. La griglia di questo gioco e'
## l'identita' — `Vector3(cella.x, 0, cella.y)`, che e' esattamente quello che
## scrive `Visitors` quando calcola `home`. Non e' una costante ricopiata: e'
## la stessa riga.
func _casa_mondo(_livello: Node, _corpo: Node3D) -> Vector3:
	return Vector3(CASA.x, 0, CASA.y)
