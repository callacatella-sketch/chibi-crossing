extends SceneTree
## IL GRADINO DELLA RIBELLIONE, dopo che il perdono ha cambiato peso.
##
##   Godot --headless --path . --script res://tools/misura_gradino.gd
##   CHIBI_GIORNI=120 CHIBI_INTENSITA=0.8 …
##
## `Animo.conto_verso` adesso legge il SOMMARIO anche per le PROVE, non solo
## per i torti. Era una regressione da riparare — con la potatura per schema
## del sé le gentilezze del giocatore, che sono le righe RIPETUTE, sparivano
## nel sommario e da lì non le contava più nessuno — ma la riparazione
## **cambia `rancore()`**, e `rancore()` non è un numero da diario: alimenta
## `aggiorna_scala()`, cioè il gradino, il telegrafo, il confronto, la
## diserzione (`Visitors._congeda`) e l'ammutinamento.
##
## ⚠️ **E LA SEZIONE DI CLAUDE.md CHIUDEVA ARGOMENTANDO, NON MISURANDO** («il
## che rende `rancore()` più mite nelle partite lunghe»). Su una funzione che
## decide chi se ne va dal villaggio, argomentare non basta. Questo banco fa
## la domanda che mancava.
##
## ────────────────────────────────────────────────────────────────────────
## IL CANCELLO D'ARRESTO, dichiarato PRIMA di misurare
## ────────────────────────────────────────────────────────────────────────
##
## Lo scenario è quello canonico del brief: **quaranta giorni a spaccare
## legna per uno che sognava di combattere**, cioè un torto d'identità che
## `Limbico.rivaluta` SENSIBILIZZA invece di attutire. Sopra ci si mette una
## gentilezza ripetuta, a ritmi diversi.
##
## (a) **Il giocatore che NON dà niente deve ancora arrivare al confronto**,
##     e più o meno quando ci arrivava prima. Se non ci arriva più, la
##     riparazione ha rotto la ribellione per tutti.
## (b) **Il giocatore GENEROSO deve poterci arrivare lo stesso**, se
##     continua a tradire il sogno di quella persona. Un perdono che rende
##     il gradino IRRAGGIUNGIBILE non è mitezza: è il vicino che non ti dice
##     più niente — e la promessa scritta in `aggiorna_scala` («ogni gradino
##     deve poter essere visto e corretto») diventa «non c'è mai niente da
##     correggere».
## (c) **E il ritmo deve contare**: fra «nessuna gentilezza» e «una al
##     giorno» ci dev'essere una differenza LEGGIBILE, o il gesto del
##     giocatore non pesa niente.
##
## Se (b) fallisce, la leva onesta NON è il moltiplicatore 1.4: è che le
## prove del sommario portino la recenza dei PROPRI eventi invece di quella
## dell'ultimo (oggi `sommario[k]["ultimo"]` è la data dell'ultimo, quindi
## un giocatore che continua tiene tutto il mucchio a recenza ≈ 1).
##
## ⚠️ **NON si passa da `Villaggio.simula_giorno`**: quello vuole il
## villaggio in scena. Si chiamano le porte vere di `Animo` nell'ordine vero
## — `esegue` → `ricorda` → `passa_giorno` → `aggiorna_scala` — che è la
## catena che `Villaggio.gd` esegue per ogni animo.

const ANIMO := preload("res://scenes/npc/Animo.gd")

## Il sogno tradito: `taglia_legna` per uno che sognava di fare il GUERRIERO.
## È lo scenario del brief, e la ragione per cui pesa è in `Limbico.rivaluta`:
## ciò che nega CHI SEI non si attutisce, si SENSIBILIZZA.
##
## ⚠️ **E IL NOME VA PRESO DA `Animo.COMPITI`, non inventato.** La prima
## stesura scriveva «combattere», che non compare in nessun `tradisce`:
## `e_tradito` era falso, la valenza usciva −0.08 invece di −0.28×2, e il
## banco misurava un compito QUALUNQUE credendo di misurare un tradimento
## d'identità. Il cancello (a) falliva, e per un decimo di secondo è
## sembrato un difetto del gioco. Un banco che sbaglia una costante non
## misura una cosa un po' diversa: ne misura un'altra.
const SOGNO := "guerriero"
const COMPITO := "taglia_legna"


func _init() -> void:
	_go()


func _animo(seme: int) -> RefCounted:
	var a = ANIMO.new()
	a.setup({"name": "P%d" % seme, "sogno": SOGNO,
			"tratti": {"codardia": 0.50, "grinta": 0.50, "lealta": 0.50,
					"ambizione": 0.50, "orgoglio": 0.50}})
	return a


## Una vita: ogni giorno il compito che tradisce il sogno, più `doni` regali
## ogni `ogni` giorni. Torna il giorno in cui il gradino tocca ogni scalino,
## −1 se non ci arriva mai.
## ⚠️ **IL CONTROFATTUALE SI OTTIENE TOGLIENDO IL DATO, NON RISCRIVENDO LA
## FUNZIONE.** «Come sarebbe con le prove solo dalle righe vive» si misura
## togliendo dal `sommario` le voci POSITIVE attorno alla domanda vera e
## rimettendole subito dopo: `aggiorna_scala` e `rancore` sono quelli del
## gioco, riga per riga. Reimplementare la scala nel banco sarebbe il doppio
## che mente — la lezione del `MotoreFinto`.
func _vita(seme: int, giorni: int, doni_ogni: int, intensita: float,
		solo_vive := false) -> Dictionary:
	var a := _animo(seme)
	var tocca := {}
	var rancori: Array = []
	for g in giorni:
		a.esegue(COMPITO, "giocatore")
		if doni_ogni > 0 and g % doni_ogni == 0:
			a.ricorda("piatto", "giocatore", 0.7, intensita)
		a.passa_giorno()
		if solo_vive:
			var tolte := {}
			for k in a.sommario:
				if float((a.sommario[k] as Dictionary)["peso"]) > 0.0:
					tolte[k] = a.sommario[k]
			for k in tolte:
				a.sommario.erase(k)
			a.aggiorna_scala("giocatore")
			for k in tolte:
				a.sommario[k] = tolte[k]
		else:
			a.aggiorna_scala("giocatore")
		var scalino := str(ANIMO.SCALA[int(a.gradino)])
		if not tocca.has(scalino):
			tocca[scalino] = g + 1
		if g == giorni - 1 or g % 10 == 9:
			rancori.append(a.rancore("giocatore"))
	var c: Dictionary = a.conto_verso("giocatore")
	# E LE PROVE COME SAREBBERO SOLO DALLE RIGHE VIVE: serve a sapere se il
	# sommario alla RILETTURA serva davvero, o se il rapporto stia sopra
	# `RAPPORTO_MIN` comunque.
	var vive := 0.0
	for r2 in a.ricordi:
		if r2["attore"] == "giocatore" and float(r2["valenza"]) > 0.0:
			vive += float(r2["valenza"]) * float(r2["intensita"]) \
					* pow(0.5, float(int(a.oggi) - int(r2["quando"])) / ANIMO.MEZZA_VITA)
	return {"prove_vive": vive, "tocca": tocca, "gradino": int(a.gradino),
			"rancore": a.rancore("giocatore"),
			"torti": float(c["torti"]), "prove": float(c["prove"]),
			"vivi": (a.ricordi as Array).size(),
			"som": (a.sommario as Dictionary).size(),
			"rancori": rancori}


## UN BRACCIO: la tabella dei ritmi, e i suoi esiti.
func _braccio(giorni: int, intensita: float, solo_vive: bool) -> Dictionary:
	var ritmi := [0, 7, 3, 2, 1]      # 0 = mai
	var esiti := {}
	print("")
	print("  %s" % ("─── IL CONTROFATTUALE: le prove del sommario NON contano ───"
			if solo_vive else "─── IL GIOCO DI ADESSO ───"))
	print("  un piatto     gradino     → svogliato  → rifiuto  → confronto   → diserzione")
	print("  ─────────     ─────────   ──────────   ─────────  ───────────   ───────────")
	for r in ritmi:
		# tre semi, perché `Animo` ha un dado suo: un solo individuo non è
		# una misura
		var somma_conf := 0.0
		var quanti_conf := 0
		var ultimo := {}
		for sm in 3:
			var v := _vita(4200 + sm * 17, giorni, r, intensita, solo_vive)
			ultimo = v
			var t: Dictionary = v["tocca"]
			if t.has("confronto"):
				somma_conf += float(t["confronto"])
				quanti_conf += 1
		var t2: Dictionary = ultimo["tocca"]
		var etichetta := "mai" if r == 0 else ("ogni %d gg" % r if r > 1 else "ogni gg")
		print("  %-12s  %-10s  %-11s  %-9s  %-12s  %s"
				% [etichetta, str(ANIMO.SCALA[int(ultimo["gradino"])]),
				str(t2.get("svogliato", "—")), str(t2.get("rifiuto", "—")),
				("%d (%d su 3)" % [int(t2.get("confronto", -1)), quanti_conf]
						if t2.has("confronto") else "MAI"),
				str(t2.get("diserzione", "—"))])
		esiti[r] = {"gradino": int(ultimo["gradino"]), "tocca": t2,
				"conf_medio": (somma_conf / float(quanti_conf)) if quanti_conf > 0 else -1.0,
				"quanti_conf": quanti_conf, "rancore": float(ultimo["rancore"]),
				"torti": float(ultimo["torti"]), "prove": float(ultimo["prove"]),
				"vivi": int(ultimo["vivi"]), "som": int(ultimo["som"]),
				"prove_vive": float(ultimo["prove_vive"]),
				"rancori": ultimo["rancori"]}
	print("")
	print("  il libro mastro a fine corsa, e il RAPPORTO che la rilettura guarda:")
	print("  un piatto      torti    prove   solo vive   rancore   rapp.tot  rapp.vive")
	for r in ritmi:
		var e: Dictionary = esiti[r]
		var etichetta := "mai" if r == 0 else ("ogni %d gg" % r if r > 1 else "ogni gg")
		var tt: float = maxf(float(e["torti"]), 0.0001)
		print("  %-12s  %7.3f  %7.3f  %9.3f  %8.4f  %8.3f  %9.3f"
				% [etichetta, float(e["torti"]), float(e["prove"]),
				float(e["prove_vive"]), float(e["rancore"]),
				float(e["prove"]) / tt, float(e["prove_vive"]) / tt])
	print("  (la rilettura serve un rapporto ≥ %.2f)" % 0.50)
	return esiti


func _go() -> void:
	var giorni := 120
	if OS.get_environment("CHIBI_GIORNI") != "":
		giorni = int(OS.get_environment("CHIBI_GIORNI"))
	var intensita := 0.8
	if OS.get_environment("CHIBI_INTENSITA") != "":
		intensita = float(OS.get_environment("CHIBI_INTENSITA"))

	print("")
	print("█".repeat(78))
	print("IL GRADINO DELLA RIBELLIONE — «%s» per chi sognava di fare il %s, %d giornate"
			% [COMPITO, SOGNO, giorni])
	print("  con addosso una gentilezza ripetuta a ritmi diversi (intensità %.2f)"
			% intensita)
	print("█".repeat(78))

	var adesso := _braccio(giorni, intensita, false)
	var prima := _braccio(giorni, intensita, true)

	var senza: Dictionary = adesso[0]
	var generoso: Dictionary = adesso[1]
	var p_senza: Dictionary = prima[0]
	var p_generoso: Dictionary = prima[1]
	var a_ok: bool = (senza["tocca"] as Dictionary).has("confronto")
	var b_ok: bool = (generoso["tocca"] as Dictionary).has("confronto")
	var scarto := -1.0
	if a_ok and b_ok:
		scarto = float(generoso["conf_medio"]) - float(senza["conf_medio"])
	var c_ok: bool = scarto > 3.0 or (a_ok and not b_ok)

	print("")
	print("█".repeat(78))
	print("I CANCELLI, dichiarati prima di misurare")
	print("█".repeat(78))
	print("(a) chi non dà NIENTE arriva ancora al confronto: %s%s"
			% ["sì" if a_ok else "NO",
			("  (giorno %.0f · prima: %s)" % [float(senza["conf_medio"]),
					("%.0f" % float(p_senza["conf_medio"]))
					if float(p_senza["conf_medio"]) > 0.0 else "MAI"]) if a_ok else ""])
	print("(b) chi è GENEROSO ci arriva lo stesso, se continua a tradire: %s%s"
			% ["sì" if b_ok else "NO",
			("  (prima ci arrivava al giorno %.0f)" % float(p_generoso["conf_medio"]))
			if float(p_generoso["conf_medio"]) > 0.0 else "  (e prima nemmeno)"])
	print("(c) e il ritmo del piatto CONTA (≥ 3 giornate di scarto): %s%s"
			% ["sì" if c_ok else "NO",
			("  (%+.0f giornate)" % scarto) if scarto >= 0.0 else ""])
	print("")
	if a_ok and b_ok and c_ok:
		print("⇒ il perdono è più mite e la ribellione resta RAGGIUNGIBILE:")
		print("  essere generosi la RIMANDA, non la cancella.")
	elif a_ok and not b_ok:
		print("⇒ ⚠️ IL GRADINO È IRRAGGIUNGIBILE PER IL GIOCATORE GENEROSO.")
		print("  Non è mitezza: è un vicino che non ti dice più niente mentre")
		print("  ogni giorno gli rubi la vita, e la promessa di `aggiorna_scala`")
		print("  — «ogni gradino deve poter essere visto e corretto» — diventa")
		print("  «non c'è mai niente da correggere». Un villaggio che si placa")
		print("  col cibo non è la promessa che questo gioco fa.")
	elif not a_ok:
		print("⇒ ⚠️ NEMMENO CHI NON DÀ NIENTE ARRIVA AL CONFRONTO: il banco è")
		print("  rotto, o lo scenario non è quello del brief. Non si legge")
		print("  nient'altro finché (a) non passa.")
	else:
		print("⇒ ⚠️ IL RITMO NON CONTA: il gesto del giocatore non pesa niente.")
	quit(0)
