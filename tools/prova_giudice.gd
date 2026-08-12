extends SceneTree
## IL METRO DEL GIUDICE — quanto migliora, misurato sul mazzo VERO.
##
##   CHIBI_GIUDICE=<cartella del provino> ~/Downloads/Godot.app/Contents/MacOS/Godot \
##       --headless --path . --script res://tools/prova_giudice.gd
##
## La cartella è quella del provino dell'11 agosto: dentro ci sono
## `risultati_provino/*.json` (184 generazioni di quattro modelli piccoli, coi
## testi integrali) e `grammatica_esempio.gbnf`.
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ ESISTE, VISTO CHE C'È `test_giudice.gd`
## ────────────────────────────────────────────────────────────────────────
##
## La suite prova che il giudice fa quello che dice su bozze scritte a mano —
## cioè su bozze scritte da chi scriveva anche il giudice, che è il modo più
## comodo di dimostrare qualunque cosa. Qui invece le bozze vengono da quattro
## modelli veri che non sapevano di essere giudicati, e la domanda è una
## sola: **quanto salgono onestà e varietà rispetto a «prendi la prima»?**
## Se non salgono, il giudice è sbagliato — e questo file lo dice.
##
## Tre bracci, apposta separati, perché «migliora» non voglia dire due cose
## insieme:
##   A · PRENDI LA PRIMA   la prima bozza del mazzetto, mostrata così com'è.
##   B · SOLO LA PORTA     la prima bozza che passa il collaudo.
##   C · IL GIUDICE        porta + memoria + rarità.
## Fra A e B si legge quanto vale l'ancoraggio; fra B e C quanto vale la
## scelta.
##
## ⚠️ L'ONESTÀ NON LA MISURA IL GIUDICE. Chiedere al giudice quante bugie ha
## lasciato passare è chiedere al giudice se è d'accordo con sé stesso — lo
## stesso errore che la prima verifica del cammino faceva chiedendo a `Varchi`
## se il corpo avesse attraversato un muro. Questo file scrive le lettere
## scelte in `scelte_giudice.json`, e a contare le invenzioni ci pensa
## `analisi.py`, che stava già lì (l'ha scritto il provino, prima che il
## giudice esistesse, e non conosce nessuna delle sue regole).

const SUG := preload("res://scenes/npc/Suggeritore.gd")
const GIU := preload("res://scenes/npc/Giudice.gd")

## Quante bozze per lettera. Cinque è quello che una macchina da giocatore
## riesce a scrivere in una manciata di secondi (il provino ha misurato
## 3.4–17 s a generazione, secondo il modello); il mazzo ne ha quindici per
## modello, quindi ogni sera se ne pescano cinque diverse.
const MAZZETTO := 5
## LE SERE DI UN GIRO, e perché sono tre e non quaranta.
##
## ⚠️ QUESTA È LA TRAPPOLA DI MISURA DI QUESTO BANCO, e la prima stesura ci è
## cascata dentro. Il mazzo ha quindici bozze per modello; simulando quaranta
## sere si ripescano le STESSE bozze otto volte, e dalla terza sera in poi il
## giudice le boccia tutte perché «l'ha già detto» — verissimo, e senza
## nessun rapporto con la partita: in partita il modello ne scrive di nuove
## ogni sera. Misurava il mazzo, non il giudice (silenzio al 95%).
##
## Adesso un GIRO è una PARTIZIONE del mazzo: quindici bozze in tre mazzetti
## da cinque, nessuna bozza vista due volte. Dentro un giro, una bocciatura
## per memoria vuol dire davvero «questa somiglia a quella di ieri». I giri
## sono tanti, con partizioni diverse, e le misure si mediano sui giri.
const SERE := 3
const GIRI := 50
## Quante lettere indietro arriva la memoria del villaggio.
const MEMORIA := 6

const B_SENTITO := 1
const B_SU_DI_ME := 2
const B_NESSUNO := 4294967295

var _dove := ""


func _init() -> void:
	_dove = OS.get_environment("CHIBI_GIUDICE")
	if _dove == "":
		print("serve CHIBI_GIUDICE=<cartella del provino>")
		quit(1)
		return
	_go()
	quit(0)


# =========================================================================
# IL RITRATTO DEL PROVINO — e la prova che è QUELLO
# =========================================================================

## Il vicino su cui il provino ha generato tutto: la volpina Papavero, cinque
## ricordi, ventidue frasi ammesse. È ricostruito a mano perché questo banco
## non deve accendere né un villaggio né la GDExtension — e la prova che sia
## il ritratto giusto non è la fiducia: è che `citazioni()` dia esattamente
## le ventidue righe della grammatica con cui i modelli hanno scritto.
func _ritratto() -> Dictionary:
	return {
		"nome": "la volpina Papavero", "eta": "giovane",
		"indole": ["dormiglione"], "quirk": "canta_alla_luna",
		"casa": Vector3(4, 0, 6), "azione": "quattro_chiacchiere",
		"obiettivo": "", "stagione": "autunno", "momento": "pomeriggio",
		"ciclo": 240.0, "protagonista": "Mochi", "compito": "lettera",
		"nomi": {3: "la volpina Prugna"},
		"verbi": ["annaffia", "semina", "raccoglie", "costruisce",
				"taglia", "pesca", "cucina", "dona"],
		"cose": ["fiore", "cibo", "casa", "fuoco", "pesce", "amico"],
		"gusto": PackedFloat64Array([1.0, 1.0, 2.2, 0.0, 1.0, 1.0]),
		"tinte": {"ammirazione": 2.9, "gratitudine": 1.4,
				"interesse": PackedFloat64Array([0, 0, 2.2, 0, 0, 0])},
		"ora": 900.0, "mezza_vita": 120.0,
		"pesi": PackedFloat64Array([1.6, 1.4, 0.8, 0.6, 0.5]),
		"bandiere": {"sentito": B_SENTITO, "su_di_me": B_SU_DI_ME,
				"detto": 4, "nessuno": B_NESSUNO},
		"ricordi": [
			# ha ricevuto un dono dalle zampe di Mochi, poco fa, vicino a casa
			{"verbo": 7, "bandiere": B_SU_DI_ME, "quante": 1,
					"px": 5.0, "pz": 7.0, "quando": 895.0, "soggetto": B_NESSUNO},
			# l'ha vista annaffiare a lungo, poco fa, vicino a casa
			{"verbo": 0, "bandiere": 0, "quante": 6,
					"px": 5.0, "pz": 7.0, "quando": 895.0, "soggetto": B_NESSUNO},
			# costruire, poco fa, dall'altra parte del villaggio
			{"verbo": 3, "bandiere": 0, "quante": 1,
					"px": 34.0, "pz": 32.0, "quando": 895.0, "soggetto": B_NESSUNO},
			# regalare qualcosa alla volpina Prugna, poco fa, vicino
			{"verbo": 7, "bandiere": 0, "quante": 1,
					"px": 5.0, "pz": 7.0, "quando": 895.0, "soggetto": 3},
			# pescare: gliel'hanno raccontato, dall'altra parte
			{"verbo": 5, "bandiere": B_SENTITO, "quante": 1,
					"px": 34.0, "pz": 32.0, "quando": 895.0, "soggetto": B_NESSUNO},
		],
	}


## LE FRASI DELLA GRAMMATICA con cui i modelli hanno davvero scritto.
func _citazioni_del_provino() -> Array:
	var f := FileAccess.open(_dove + "/grammatica_esempio.gbnf", FileAccess.READ)
	if f == null:
		return []
	var out := []
	while not f.eof_reached():
		var r := f.get_line()
		if not r.begins_with("\t\""):
			continue
		out.append(r.strip_edges().trim_prefix("\"").trim_suffix("|").strip_edges()
				.trim_suffix("\""))
	return out


# =========================================================================
# IL BANCO
# =========================================================================

func _go() -> void:
	var rit := _ritratto()
	var mie: Array = SUG.citazioni(rit)
	var vere := _citazioni_del_provino()
	print("IL RITRATTO È QUELLO DEL PROVINO?")
	print("   frasi ricostruite: %d   frasi della grammatica: %d" % [mie.size(), vere.size()])
	var uguali := mie.size() == vere.size()
	if uguali:
		for i in mie.size():
			if str(mie[i]) != str(vere[i]):
				uguali = false
				print("   DIVERSA alla riga %d:\n     mia:  %s\n     vera: %s"
						% [i, str(mie[i]), str(vere[i])])
				break
	if not uguali:
		print("   ⚠️  NO: la misura sotto non varrebbe niente. Mi fermo.")
		return
	print("   sì: ventidue frasi identiche. Si può misurare.\n")

	_quanto_era_grande_il_buco(rit)

	var fuori := {"mazzetto": MAZZETTO, "sere": SERE, "memoria": MEMORIA, "bracci": {}}
	for cond in ["B_gram", "B_libero"]:
		print("=".repeat(74))
		print("MAZZO «%s» — %s" % [cond, "con la grammatica accesa (il caso vero)"
				if cond == "B_gram" else "SENZA grammatica (se un domani qualcuno se la scorda)"])
		print("=".repeat(74))
		# ⚠️ L'INCIPIT SI NORMALIZZA SULLE LETTERE MANDATE, non sulle sere. Chi
		# tace di più manda meno lettere, e meno lettere hanno per forza meno
		# inizi diversi: la prima stesura di questa colonna dava il giudice
		# PERDENTE su llama3.2 (2.94 -> 1.94) misurando in realtà che aveva
		# buttato un terzo delle bozze. La domanda giusta è: **fra le lettere
		# che arrivano, quante ricominciano come quella di ieri?**
		print("%-12s %-18s %8s %9s %10s %s" % ["modello", "braccio", "lettere",
				"silenzio", "inizi div.", "(inizi diversi / lettere, per giro di 3 sere)"])
		for f in _mazzi():
			var d: Dictionary = f
			var bozze: Array = d[cond]
			for braccio in ["A prendi la prima", "B solo la porta", "C il giudice"]:
				var esito := _simula(braccio, bozze, rit)
				var sere: int = max(1, int(esito["sere"]))
				var lettere: int = (esito["mandate"] as Array).size()
				var frazione := 0.0
				if lettere > 0:
					frazione = float(esito["incipit_per_giro"]) / (float(lettere) / float(GIRI))
				print("%-12s %-18s %8d %8.0f%% %9.2f    (%.2f inizi su %.2f lettere)"
						% [str(d["modello"]), braccio, lettere,
						100.0 * float(esito["silenzi"]) / float(sere), frazione,
						float(esito["incipit_per_giro"]), float(lettere) / float(GIRI)])
				var chiave := "%s|%s|%s" % [cond, str(d["modello"]), braccio]
				fuori["bracci"][chiave] = esito["mandate"]
		print("")

	_quanto_costa(rit)

	var f := FileAccess.open(_dove + "/scelte_giudice.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(fuori, "  "))
	f.close()
	print("scritte le lettere scelte in %s/scelte_giudice.json" % _dove)
	print("l'onestà la conta `analisi.py`, che non sa niente del giudice.")


## QUANTO ERA GRANDE IL BUCO. Il collaudo di prima guardava i CARATTERI delle
## righe libere: minuscole, niente cifre, quattro parole almeno. Quello di
## adesso guarda anche il senso — e la porta da cui esce una bozza dice
## esattamente a chi dei due si deve la bocciatura:
##   · `forma`      la bocciava anche prima;
##   · `parola` e `ancoraggio` sono le porte nuove: quelle bozze, prima,
##     arrivavano sullo schermo del giocatore.
func _quanto_era_grande_il_buco(rit: Dictionary) -> void:
	print("=".repeat(74))
	print("QUANTO ERA GRANDE IL BUCO — le 152 generazioni italiane del provino")
	print("=".repeat(74))
	## ⚠️ `EN_gram` NON entra: quelle otto generazioni per modello sono in
	## inglese, fatte con un ALTRO ritratto e un'altra grammatica. Col ritratto
	## italiano non citano niente di vero e cadono tutte sulla forma — che non
	## dice niente sul collaudo, e gonfierebbe una colonna con un artefatto.
	print("%-12s %-10s %5s %8s %8s %11s %s" % ["modello", "prova", "n",
			"passa", "forma", "parola", "ANCORAGGIO (prima passavano)"])
	var tot := {"n": 0, "ok": 0, "forma": 0, "parola": 0, "ancoraggio": 0}
	for f in _mazzi():
		var d: Dictionary = f
		for cond in ["A_gram", "B_gram", "B_libero"]:
			if not d.has(cond):
				continue
			var conta := {"n": 0, "ok": 0, "forma": 0, "parola": 0, "ancoraggio": 0}
			for b in (d[cond] as Array):
				var e: Dictionary = SUG.accetta(str(b), rit)
				conta["n"] += 1
				var k := "ok" if bool(e["ok"]) else str(e.get("porta", "forma"))
				conta[k] = int(conta.get(k, 0)) + 1
			print("%-12s %-10s %5d %8d %8d %8d %11d" % [str(d["modello"]), cond,
					conta["n"], conta["ok"], conta["forma"], conta["parola"],
					conta["ancoraggio"]])
			for k in conta:
				tot[k] = int(tot[k]) + int(conta[k])
	print("%-12s %-10s %5d %8d %8d %8d %11d" % ["TUTTI", "", int(tot["n"]),
			int(tot["ok"]), int(tot["forma"]), int(tot["parola"]), int(tot["ancoraggio"])])
	var nuove := int(tot["parola"]) + int(tot["ancoraggio"])
	print("Il collaudo di prima ne promuoveva %d; di quelle, %d (%.0f%%) uscivano rotte"
			% [int(tot["ok"]) + nuove, nuove,
			100.0 * float(nuove) / float(max(1, int(tot["ok"]) + nuove))])
	print("")


## QUANTO COSTA UNA SCELTA. Non sta in un frame caldo — si giudica quando una
## generazione finisce, cioè una volta ogni parecchi secondi (il provino ha
## misurato 3.4–17 s per bozza) — ma «non sta in un frame caldo» è una cosa
## che si dice, e un numero è un numero.
func _quanto_costa(rit: Dictionary) -> void:
	var bozze := []
	for g in (_mazzi()[0]["B_gram"] as Array):
		bozze.append(str(g))
	var mazzetto := bozze.slice(0, MAZZETTO)
	var memoria := {"sue": bozze.slice(5, 11)}
	# ⚠️ SI PRENDE IL TEMPO MIGLIORE, non la media. Su questa macchina girano
	# spesso altri banchi insieme a questo (il carico misurato durante la
	# stesura era 30–60), e una media racconta la macchina invece del codice:
	# gli stessi 200 giri hanno dato 7 ms e 22 ms a mezz'ora di distanza. Il
	# minimo è il giro in cui nessuno ha rubato la CPU, ed è l'unica cosa che
	# si può confrontare con la misura di domani.
	var meglio := INF
	for i in 200:
		var t0 := Time.get_ticks_usec()
		GIU.scegli(mazzetto, rit, memoria)
		meglio = min(meglio, float(Time.get_ticks_usec() - t0))
	print("UNA SCELTA fra %d bozze, con sei lettere in memoria: %.0f µs (il giro migliore su 200)"
			% [MAZZETTO, meglio])
	print("")


## I quattro mazzi del provino, in ordine di nome.
func _mazzi() -> Array:
	var out := []
	var dir := DirAccess.open(_dove + "/risultati_provino")
	if dir == null:
		return out
	var nomi := dir.get_files()
	nomi.sort()
	for n in nomi:
		if not str(n).ends_with(".json"):
			continue
		var f := FileAccess.open(_dove + "/risultati_provino/" + str(n), FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d == null:
			continue
		var voce := {"modello": str(d["modello"])}
		for cond in ["A_gram", "B_gram", "B_libero", "EN_gram"]:
			var testi := []
			for g in (d[cond] as Array):
				testi.append(str((g as Dictionary)["testo"]))
			voce[cond] = testi
		out.append(voce)
	return out


## TANTI GIRI DI TRE SERE. Ogni giro rimescola il mazzo e lo taglia in tre
## mazzetti da cinque; dentro un giro nessuna bozza torna due volte.
##
## Il dado sta QUI, nel banco, e non nel giudice: mescolare le bozze è il
## mestiere del modello (due generazioni non escono mai nello stesso ordine),
## e un giudice con un dado dentro non sarebbe riproducibile. Il seme è fisso,
## così due esecuzioni di questo file danno gli stessi numeri.
func _simula(braccio: String, bozze: Array, rit: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260811
	var cit: Array = SUG.citazioni(rit)
	var tutte := []
	var sere := 0
	var silenzi := 0
	var diversi := 0.0        # incipit diversi per giro, mediati sui giri
	for giro in GIRI:
		var ordine := _mescola(bozze, rng)
		var mandate := []
		for s in SERE:
			var mazzetto := ordine.slice(s * MAZZETTO, (s + 1) * MAZZETTO)
			if mazzetto.size() < MAZZETTO:
				break
			sere += 1
			var scelta := ""
			if braccio.begins_with("A"):
				scelta = str(mazzetto[0])
			elif braccio.begins_with("B"):
				for b in mazzetto:
					if bool(SUG.accetta(str(b), rit)["ok"]):
						scelta = str(b)
						break
			else:
				var memoria := {"sue": mandate.slice(max(0, mandate.size() - MEMORIA))}
				var e: Dictionary = GIU.scegli(mazzetto, rit, memoria)
				if int(e["scelta"]) >= 0:
					scelta = str(e["testo"])
			if scelta == "":
				silenzi += 1
			else:
				mandate.append(scelta)
		var incipit := {}
		for m in mandate:
			incipit[GIU.incipit(str(m), cit)] = true
		diversi += float(incipit.size())
		for m in mandate:
			tutte.append(str(m))
	return {"mandate": tutte, "sere": sere, "silenzi": silenzi,
			"incipit_per_giro": diversi / float(GIRI)}


func _mescola(bozze: Array, rng: RandomNumberGenerator) -> Array:
	var out := []
	for b in bozze:
		out.append(str(b))
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out
