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
## (c) **E il ritmo deve contare — MA SOLO DOVE DEVE.** La prima stesura lo
##     chiedeva sullo scenario del brief, ed era mal posta: lì il torto è un
##     tradimento d'identità RIPETUTO OGNI GIORNO, e il perdono *deve*
##     essere inerte — non ti compri il silenzio di uno a cui rubi la vita
##     tutti i giorni. Misurato, infatti: da 70 a 73 giornate qualunque sia
##     il ritmo del piatto. Il cancello giusto ha due metà:
##       c1) nello scenario DURO il ritmo NON deve cambiare quasi niente;
##       c2) in uno scenario MITE (un torto qualunque, non l'identità) deve
##           cambiare parecchio, o il perdono è decorativo.
##
## ⚠️⚠️ **E (c2) NON POTEVA PASSARE COM'ERA SCRITTO: nello scenario mite
## NESSUNO arrivava mai al confronto.** Un torto qualunque a −0,5 si ABITUA
## (`Limbico.rivaluta`), quindi dopo pochi giorni vale ~`letto × 0,25`, e un
## solo torto al giorno non porta il rancore da nessuna parte vicino alla
## soglia del confronto. (c2) chiedeva quindi «di quanto il piatto sposta una
## cosa che non succede», cioè non discriminava niente: era verde-o-rosso per
## una ragione che col perdono non c'entra.
##
## **E IL NUMERO NON SI INDOVINA: SI CERCA.** `_taratura_mite()` fa scorrere
## una scala di severità — quanti torti al giorno, con che valenza e che
## intensità — e per ognuna guarda **se il confronto si raggiunge senza un
## solo piatto**. Prende la PIÙ MITE che ci arriva ancora, perché è quella
## che lascia più spazio al perdono; poi (c2) si chiede su quella.
##
## ⚠️ **La scansione non è un cancello che si tara finché passa.** Garantisce
## solo la PRECONDIZIONE di (c2) — che il gradino sia raggiungibile senza
## doni — e non dice niente su quanto il ritmo lo sposti: (c2) può fallire
## lo stesso, ed è quello il risultato interessante. Se poi non esiste
## NESSUNA taratura in cui il confronto si raggiunga, il referto lo dice:
## sarebbe la scoperta che su un torto qualunque il gradino non arriva mai
## alla ribellione, e va detta invece che tarata via.
##
## ⚠️ **E c'è una ragione strutturale per cui (c2) può non passare in nessun
## caso, e il referto la stampa insieme al verdetto.** `rancore()` sottrae
## `prove × 1,4`, e `prove` conta **solo le righe VIVE** — che la potatura
## tiene sotto `RICORDI_VIVI` e sacrifica per prime proprio perché sono
## RIPETUTE. I torti invece, una volta potati, si accumulano nel `sommario`
## con `peso` che non decade e `ultimo` sempre di oggi, cioè a recenza ≈ 1.
## Le due grandezze non crescono nello stesso modo: una ha un tetto e
## l'altra no. Il numero che lo mostra è la colonna «sconto» del libro
## mastro (`prove × 1,4 / torti`).
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
## ⚠️ la soglia della rilettura si LEGGE, non si ricopia: qui c'era un `0.50`
## scritto a mano, cioè una costante gemella che diverge in silenzio il
## giorno che qualcuno tara `RAPPORTO_MIN`.
const RIL := preload("res://scenes/npc/Rilettura.gd")

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

## LA SCALA DELLE SEVERITÀ DELLO SCENARIO MITE, dalla più mite alla più dura.
##
## Non è una taratura scelta: è il campo che la scansione percorre, e a
## sceglierne una è `_taratura_mite()` guardando **se il confronto si
## raggiunge senza un solo piatto**. La prima della lista che ci arriva vince,
## perché la più mite è quella che lascia più spazio al perdono.
##
## ⚠️ **Le tre manopole non sono intercambiabili**, ed è il motivo per cui la
## scala le muove insieme invece che una sola: `valenza` e `intensita`
## saturano (l'abitudine porta il sentito a ~`letto × 0,25`, e `letto` è
## clampato a −1), mentre **il numero di torti al giorno no** — è l'unica che
## scala senza tetto. Una scala che muovesse solo la valenza si fermerebbe
## prima di arrivare da nessuna parte.
const MITE_CANDIDATI := [
	{"torti": 1, "valenza": -0.5, "intensita": 0.7},
	{"torti": 1, "valenza": -0.9, "intensita": 0.9},
	{"torti": 2, "valenza": -0.7, "intensita": 0.8},
	{"torti": 3, "valenza": -0.8, "intensita": 0.9},
	{"torti": 4, "valenza": -0.9, "intensita": 1.0},
	{"torti": 6, "valenza": -1.0, "intensita": 1.0},
	{"torti": 9, "valenza": -1.0, "intensita": 1.0},
]


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
## [param mite] vuoto = lo scenario DURO del brief (il compito che tradisce
## il sogno). Altrimenti è la taratura scelta da `_taratura_mite()`:
## `{"torti", "valenza", "intensita"}`.
func _vita(seme: int, giorni: int, doni_ogni: int, intensita: float,
		solo_vive := false, mite := {}) -> Dictionary:
	var a := _animo(seme)
	var tocca := {}
	var rancori: Array = []
	for g in giorni:
		if mite.is_empty():
			a.esegue(COMPITO, "giocatore")
		else:
			# un torto QUALUNQUE, non un tradimento d'identità — e quanto
			# pesa lo dice la TARATURA che la scansione ha trovato, non un
			# numero scritto qui a occhio.
			for _t in maxi(1, int(mite["torti"])):
				a.ricorda("ignorato", "giocatore", float(mite["valenza"]),
						float(mite["intensita"]))
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
func _braccio(giorni: int, intensita: float, solo_vive: bool,
		mite := {}) -> Dictionary:
	var ritmi := [0, 7, 3, 2, 1]      # 0 = mai
	var esiti := {}
	print("")
	print("  %s" % (("─── SCENARIO MITE (taratura trovata: %d torti/gg a %.2f × %.2f) ───"
			% [int(mite["torti"]), float(mite["valenza"]), float(mite["intensita"])])
			if not mite.is_empty()
			else ("─── IL CONTROFATTUALE: le prove del sommario NON contano ───"
			if solo_vive else "─── IL GIOCO DI ADESSO (il tradimento del sogno) ───")))
	print("  un piatto     gradino     → svogliato  → rifiuto  → confronto   → diserzione")
	print("  ─────────     ─────────   ──────────   ─────────  ───────────   ───────────")
	for r in ritmi:
		# tre semi, perché `Animo` ha un dado suo: un solo individuo non è
		# una misura
		var somma_conf := 0.0
		var quanti_conf := 0
		var ultimo := {}
		for sm in 3:
			var v := _vita(4200 + sm * 17, giorni, r, intensita, solo_vive, mite)
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
	print("  un piatto      torti    prove   solo vive   rancore   rapp.tot  rapp.vive   sconto")
	for r in ritmi:
		var e: Dictionary = esiti[r]
		var etichetta := "mai" if r == 0 else ("ogni %d gg" % r if r > 1 else "ogni gg")
		var tt: float = maxf(float(e["torti"]), 0.0001)
		print("  %-12s  %7.3f  %7.3f  %9.3f  %8.4f  %8.3f  %9.3f  %7.1f%%"
				% [etichetta, float(e["torti"]), float(e["prove"]),
				float(e["prove_vive"]), float(e["rancore"]),
				float(e["prove"]) / tt, float(e["prove_vive"]) / tt,
				100.0 * float(e["prove"]) * 1.4 / tt])
	print("  (la rilettura serve un rapporto ≥ %.2f)" % RIL.RAPPORTO_MIN)
	# ⚠️ **LO «SCONTO» È LA COLONNA CHE SPIEGA UN «NO» DI (c2).** È
	# letteralmente quello che `rancore()` sottrae — `prove × 1,4 / torti` —
	# e `prove` sono le sole righe VIVE, che la potatura tiene sotto
	# `RICORDI_VIVI` e sacrifica per prime perché sono ripetute. I torti
	# potati invece si accumulano nel `sommario`, dove `peso` non decade e
	# `ultimo` è sempre di oggi. Se questa colonna resta di pochi punti
	# qualunque sia il ritmo, il perdono non può spostare il gradino: non è
	# una taratura da alzare, è un'asimmetria di struttura.
	print("  (lo «sconto» è la quota di torto che `rancore()` toglie: `prove`")
	print("   sono le sole righe VIVE, i torti si accumulano anche nel sommario)")
	return esiti


## ⚠️ **LA SCANSIONE — il numero non si indovina, si cerca.**
##
## Percorre `MITE_CANDIDATI` dalla più mite alla più dura e per ognuna chiede
## una cosa sola: **senza un solo piatto, il confronto si raggiunge?** Torna
## la prima che ci arriva, o il dizionario vuoto se non ci arriva nessuna.
##
## ⚠️ **UN SEME SOLO, ed è voluto.** Questa non è una misura: è una sonda di
## raggiungibilità, e serve a scegliere il campo su cui (c2) poi misura con
## tre semi. Metterne tre qui triplicherebbe il costo per raffinare un numero
## che (c2) non legge.
func _taratura_mite(giorni: int, intensita: float) -> Dictionary:
	print("")
	print("  ─── LA SCANSIONE DELLO SCENARIO MITE ───")
	print("  (c2) chiede se il RITMO del piatto conta; per poterlo chiedere")
	print("  serve prima uno scenario mite in cui il confronto si raggiunga")
	print("  SENZA nessun piatto. La più mite che ci arriva è quella che")
	print("  lascia più spazio al perdono, ed è quella che vince.")
	print("  torti/gg  valenza  intens.  →  confronto senza doni   (gradino · rancore)")
	var scelta := {}
	for cand in MITE_CANDIDATI:
		var v: Dictionary = _vita(4200, giorni, 0, intensita, false, cand)
		var t: Dictionary = v["tocca"]
		var quando := int(t["confronto"]) if t.has("confronto") else -1
		print("  %8d  %7.2f  %7.2f  →  %-20s  (%s · %.4f)"
				% [int(cand["torti"]), float(cand["valenza"]),
				float(cand["intensita"]),
				("giorno %d" % quando) if quando > 0 else "MAI",
				str(ANIMO.SCALA[int(v["gradino"])]), float(v["rancore"])])
		if quando > 0 and scelta.is_empty():
			scelta = cand
	if scelta.is_empty():
		print("  ⇒ ⚠️ NESSUNA taratura arriva al confronto in %d giornate."
				% giorni)
	else:
		print("  ⇒ scelta la più mite che ci arriva: %d torti/gg a %.2f × %.2f"
				% [int(scelta["torti"]), float(scelta["valenza"]),
				float(scelta["intensita"])])
	return scelta


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
	# ⚠️ la taratura mite si CERCA prima di misurarci sopra: vedi
	# `_taratura_mite`. Se non ne esiste una, il braccio non si corre
	# affatto — misurare «di quanto il piatto sposta una cosa che non
	# succede» è il difetto che questa cura è venuta a chiudere.
	var taratura := _taratura_mite(giorni, intensita)
	var mite := {}
	if not taratura.is_empty():
		mite = _braccio(giorni, intensita, false, taratura)

	var senza: Dictionary = adesso[0]
	var generoso: Dictionary = adesso[1]
	var p_senza: Dictionary = prima[0]
	var p_generoso: Dictionary = prima[1]
	var a_ok: bool = (senza["tocca"] as Dictionary).has("confronto")
	var b_ok: bool = (generoso["tocca"] as Dictionary).has("confronto")
	var scarto := -1.0
	if a_ok and b_ok:
		scarto = float(generoso["conf_medio"]) - float(senza["conf_medio"])
	# c1: nello scenario DURO il ritmo non deve cambiare quasi niente
	var c1_ok: bool = a_ok and b_ok and absf(scarto) <= 6.0
	# c2: in quello MITE deve cambiare parecchio — e i due modi di NON
	# passare sono diversissimi, quindi si tengono separati: «lo scenario
	# non arriva mai al confronto» e «ci arriva, e il piatto non lo sposta».
	var m_s := -1.0
	var m_g := -1.0
	var m_sconto := 0.0
	if not mite.is_empty():
		var m_senza: Dictionary = mite[0]
		var m_gen: Dictionary = mite[1]
		m_s = float(m_senza["conf_medio"])
		m_g = float(m_gen["conf_medio"])
		m_sconto = 100.0 * float(m_gen["prove"]) * 1.4 \
				/ maxf(float(m_gen["torti"]), 0.0001)
	var c2_ok: bool = (m_s > 0.0) and (m_g < 0.0 or m_g - m_s > 10.0)
	var c_ok: bool = c1_ok and c2_ok

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
	print("(c1) nel DURO il ritmo NON sposta quasi niente (≤ 6 giornate): %s  (%+.0f)"
			% ["sì" if c1_ok else "NO", scarto])
	if taratura.is_empty():
		print("(c2) nel MITE invece sposta parecchio: NON SI PUÒ CHIEDERE")
		print("     ⚠️ nessuna delle %d tarature della scala arriva al confronto"
				% MITE_CANDIDATI.size())
		print("     in %d giornate senza un solo piatto. La domanda «di quanto"
				% giorni)
		print("     il piatto lo sposta» non ha un soggetto — ed è un RISULTATO:")
		print("     su un torto qualunque, che si ABITUA, il rancore satura")
		print("     lontano dalla ribellione. Ci arriva solo il tradimento")
		print("     d'identità, che si SENSIBILIZZA. Alzare la scala oltre")
		print("     `MITE_CANDIDATI` vorrebbe dire chiamare «mite» nove torti")
		print("     al giorno a valenza piena, che mite non è.")
	else:
		print("(c2) nel MITE invece sposta parecchio: %s  (senza: %s · ogni giorno: %s)"
				% ["sì" if c2_ok else "NO",
				("giorno %.0f" % m_s) if m_s > 0.0 else "MAI",
				("giorno %.0f" % m_g) if m_g > 0.0 else "MAI"])
		print("     lo sconto che le prove fanno sul rancore, col piatto ogni")
		print("     giorno: %.1f%% del torto accumulato" % m_sconto)
	print("")
	if a_ok and b_ok and c_ok:
		print("⇒ la ribellione resta RAGGIUNGIBILE, e il perdono pesa dove deve:")
		print("  su un torto qualunque la generosità la rimanda o la cancella,")
		print("  su un tradimento d'identità ripetuto ogni giorno non la tocca.")
		print("  Non ti compri il silenzio di uno a cui rubi la vita.")
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
	elif not c1_ok:
		print("⇒ ⚠️ NEL DURO IL RITMO SPOSTA IL CONFRONTO DI %+.0f GIORNATE." % scarto)
		print("  È il verso sbagliato: un tradimento d'identità ripetuto ogni")
		print("  giorno non si compra col cibo, e sopra le sei giornate il")
		print("  piatto sta comprando qualcosa. Non si legge (c2) finché la")
		print("  prima metà del cancello dice di no.")
	elif taratura.is_empty():
		print("⇒ ⚠️ IL PERDONO NON HA UN POSTO IN CUI CONTARE, SUL GRADINO.")
		print("  (a) e (b) passano — la ribellione resta raggiungibile — ma")
		print("  nessuno scenario MITE arriva al confronto, quindi la seconda")
		print("  metà di (c) non ha un soggetto. Detto senza girarci intorno:")
		print("  sul gradino il perdono pesa solo dove il torto è già così")
		print("  grave da portarti alla ribellione, e lì DEVE essere inerte.")
		print("  Va scritto, non tarato via.")
	else:
		print("⇒ ⚠️ IL RITMO NON CONTA NEMMENO NEL MITE: il gesto del giocatore")
		print("  non sposta il gradino. E il numero che lo spiega è lo sconto —")
		print("  %.1f%% del torto accumulato col piatto TUTTI I GIORNI: `rancore()`"
				% m_sconto)
		print("  sottrae `prove × 1.4`, e `prove` sono le sole righe VIVE, che la")
		print("  potatura tiene sotto `RICORDI_VIVI` e sacrifica per prime perché")
		print("  sono ripetute; i torti potati invece si accumulano nel sommario,")
		print("  dove il peso non decade. Una grandezza ha un tetto e l'altra no:")
		print("  non è una taratura da alzare, è un'asimmetria di struttura, e la")
		print("  leva onesta è quella dichiarata in testa a questo file (la")
		print("  recenza dei PROPRI eventi nel sommario), non il moltiplicatore.")
	quit(0)
