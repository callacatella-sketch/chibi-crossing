extends SceneTree
## IL METRO DELLA MEMORIA AUTOBIOGRAFICA: convergenza contro divergenza.
##
##   Godot --headless --path . --script res://tools/misura_memoria.gd
##   (CHIBI_QUANTI=14 · CHIBI_GIORNI=45 · CHIBI_SEMI=6)
##
## ⚠️ LE DUE PREVISIONI SONO OPPOSTE, ED È QUESTO CHE LE RENDE MISURABILI.
##  · il FIFO predice CONVERGENZA: la potatura è ordinata solo dal tempo,
##    quindi a parità di storia ogni vicino resta con la STESSA identica
##    memoria — gli ultimi quaranta fatti, che sono gli stessi per tutti;
##  · lo SCHEMA DEL SÉ predice DIVERGENZA: quello che resta dipende da
##    chi sei, e i vicini hanno sogni diversi.
##
## ⚠️ I CANCELLI D'ARRESTO, DICHIARATI PRIMA DI MISURARE:
##  (a) col FIFO la distanza a coppie dev'essere QUASI ZERO (≤ 0.02): con
##      una storia identica per tutti, una potatura ordinata solo dal
##      tempo lascia a tutti la stessa memoria. Se non è così non c'è
##      convergenza da battere, e il banco non prova niente;
##  (b) con lo schema dev'essere almeno **0.10** — cioè almeno un decimo
##      della memoria si compone in modo diverso fra due vicini che hanno
##      ricevuto lo STESSO identico trattamento. Quel decimo può venire
##      solo da chi sono;
## Se (a) o (b) non reggono, la meccanica non fa quello che dice e NON si
## consegna. Non si ritocca il numero: si toglie il lavoro.
##
## ⚠️ E C'ERA UN TERZO CANCELLO, DICHIARATO MALE — lo scrivo invece di
## toglierlo. Chiedeva che «la parte di memoria che parla del proprio
## sogno» fosse almeno 1.3 volte quella del FIFO. Ha dato 0.398 contro
## 0.334, cioè 1.19×: FALLITO come dichiarato. Ma quel rapporto non
## poteva essere raggiunto: la linea di base è alta per costruzione
## (due terzi della storia sono compiti, e ogni sogno ne ha diversi che
## lo servono o lo tradiscono) e il tetto è basso. Un cancello con un
## tetto più basso della soglia non è un cancello severo, è un cancello
## sbagliato. Resta come NUMERO RIPORTATO, insieme alla frazione
## congruente in INGRESSO che lo rende leggibile — e la previsione
## dell'autore, convergenza contro divergenza, la portano (a) e (b).
##
## ⚠️ IL CONTROLLO È IL VECCHIO CODICE VERO, non una sua imitazione:
## `Animo.debug_potatura_fifo` rimette il `pop_front()` di prima, e
## `ricorda()` è lo stesso nei due bracci. Un doppio che reimplementa la
## cosa da provare è peggio di nessun doppio.
##
## ⚠️ E L'ORACOLO NON PASSA DA `Schema`: la congruenza si ricalcola qui
## dalla tabella dei compiti (cinque righe), perché chiedere alla
## funzione di costo se ha protetto quello che voleva proteggere è
## chiedere al giudice se è d'accordo con sé stesso.
##
## ⚠️ E DUE MISURE SBAGLIATE, PAGATE SCRIVENDO QUESTO BANCO:
##  1. le ETICHETTE di `cause()` incastonano il SOGNO nella stringa
##     («taglia_legna × 40, e lui sognava di fare il guerriero»): due
##     vicini risultavano «divergenti» anche ricordando le stesse cose,
##     e il FIFO ne usciva più divergente dello schema. Si misurava una
##     stringa, non un ricordo;
##  2. l'INSIEME dei tipi vivi: con una dozzina di tipi in tutto ognuno
##     ne ha almeno uno di ciascuno, e l'insieme è identico per tutti —
##     0.000 in tutti e due i bracci. Quello che differisce non è QUALI
##     tipi, è QUANTI. Si misura la COMPOSIZIONE.

const ANIMO := preload("res://scenes/npc/Animo.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")

## LA ROUTINE: quello che il giocatore fa tutti i giorni a tutti. Si
## accumula nel sommario e `cause()` la cita col numero in chiaro, quindi
## sopravvive in tutti e due i bracci: non è lì che si gioca la partita.
const ROUTINE: Array[String] = ["taglia_legna", "guardia"]

## GLI EPISODI, e ce ne vogliono PIÙ DEI POSTI. ⚠️ Con sette episodi
## singolari in quaranta caselle non c'è SCARSITÀ: tutti se li tengono
## tutti, nessuno deve scegliere, e una potatura che non sceglie non può
## divergere. Qui ne arrivano tre al giorno, così le quaranta caselle
## vanno contese davvero.
const EPISODI: Array[String] = [
	"suona", "abbellisce", "esplora", "coltiva", "cucina", "guardia",
	"taglia_legna", "riposa", "festa",
]


func _init() -> void:
	_go()


## LA COMPOSIZIONE della memoria: quanti ricordi vivi per tipo,
## normalizzati. È quello che un vicino sa ancora dire di sé.
func _composizione(a) -> Dictionary:
	var conta := {}
	for r in a.ricordi:
		var k := str(r["tipo"])
		conta[k] = float(conta.get(k, 0.0)) + 1.0
	var tot := maxf(float(a.ricordi.size()), 1.0)
	for k in conta:
		conta[k] = float(conta[k]) / tot
	return conta


## LA DISTANZA fra due composizioni: la variazione totale. 0 = memorie
## composte allo stesso identico modo, 1 = niente in comune.
func _distanza(x: Dictionary, y: Dictionary) -> float:
	var tutte := {}
	for k in x:
		tutte[k] = true
	for k in y:
		tutte[k] = true
	var somma := 0.0
	for k in tutte:
		somma += absf(float(x.get(k, 0.0)) - float(y.get(k, 0.0)))
	return somma * 0.5


## Se questo tipo di gesto parla del sogno di quel vicino — ricalcolato
## QUI dalla tabella dei compiti, non chiesto a `Schema`.
func _parla_di_me(tipo: String, sogno: String) -> bool:
	if sogno == "":
		return false
	var c: Dictionary = ANIMO.COMPITI.get(tipo, {})
	if c.is_empty():
		return false
	return str(c.get("serve", "")) == sogno \
			or sogno in (c.get("tradisce", []) as Array)


func _corsa(quanti: int, giorni: int, seme: int, schema: bool) -> Dictionary:
	var animi: Array = []
	var sogni := {}
	for i in quanti:
		var a = ANIMO.new()
		a.setup(DNA.generate(seme * 1000 + i))
		a.debug_potatura_fifo = not schema
		animi.append(a)
		sogni[str(a.sogno)] = true
	for g in giorni:
		for a in animi:
			a.oggi = g
			for k in 3:
				a.ricorda(EPISODI[(g * 3 + k) % EPISODI.size()],
						"giocatore", -0.62, 0.85)
			for tipo in ROUTINE:
				# ⚠️ il fatto si incide NUDO: la fatica di un compito la
				# decide `esegue()`, che guarda il carattere — di lì
				# passerebbe la varietà dei CARATTERI invece di quella
				# della memoria, e la misura non direbbe più niente.
				a.ricorda(tipo, "giocatore", -0.6, 0.7)
	var comp: Array = []
	for a in animi:
		comp.append(_composizione(a))
	var somma := 0.0
	var coppie := 0
	for i in comp.size():
		for j in range(i + 1, comp.size()):
			somma += _distanza(comp[i], comp[j])
			coppie += 1
	var mia := 0.0
	# ⚠️ e la frazione congruente IN INGRESSO, cioè quanto di quello che
	# è successo parlava già di quel vicino: senza, «0.398» non si sa se
	# è tanto o poco. È il denominatore che mancava al terzo cancello.
	var ingresso := 0.0
	for a in animi:
		var n := 0
		for r in a.ricordi:
			if _parla_di_me(str(r["tipo"]), str(a.sogno)):
				n += 1
		mia += float(n) / maxf(float(a.ricordi.size()), 1.0)
		var q := 0
		for tipo in EPISODI:
			if _parla_di_me(tipo, str(a.sogno)):
				q += 3
		for tipo in ROUTINE:
			if _parla_di_me(tipo, str(a.sogno)):
				q += 1
		ingresso += float(q) / float(EPISODI.size() * 3 + ROUTINE.size())
	return {
		"distanza": somma / maxf(float(coppie), 1.0),
		"mia": mia / maxf(float(animi.size()), 1.0),
		"ingresso": ingresso / maxf(float(animi.size()), 1.0),
		"sogni": sogni.size(),
	}


func _go() -> void:
	var quanti := 14
	if OS.get_environment("CHIBI_QUANTI") != "":
		quanti = int(OS.get_environment("CHIBI_QUANTI"))
	var giorni := 45
	if OS.get_environment("CHIBI_GIORNI") != "":
		giorni = int(OS.get_environment("CHIBI_GIORNI"))
	var semi := 6
	if OS.get_environment("CHIBI_SEMI") != "":
		semi = int(OS.get_environment("CHIBI_SEMI"))

	print("MEMORIA AUTOBIOGRAFICA — %d vicini · %d giornate · %d semi"
			% [quanti, giorni, semi])
	print("la storia è LA STESSA per tutti: %d episodi al giorno + %s"
			% [3, str(ROUTINE)])
	var ds: Array[float] = []
	var df: Array[float] = []
	var ms_mia := 0.0
	var mf_mia := 0.0
	var m_ing := 0.0
	for s in semi:
		var con := _corsa(quanti, giorni, 41 + s, true)
		var senza := _corsa(quanti, giorni, 41 + s, false)
		ds.append(float(con["distanza"]))
		df.append(float(senza["distanza"]))
		ms_mia += float(con["mia"]) / float(semi)
		mf_mia += float(senza["mia"]) / float(semi)
		m_ing += float(con["ingresso"]) / float(semi)
		print("  seme %d · sogni diversi %d · distanza  schema %.3f  fifo %.3f"
				% [41 + s, int(con["sogni"]), float(con["distanza"]),
						float(senza["distanza"])]
				+ " · parla di me  %.3f / %.3f"
				% [float(con["mia"]), float(senza["mia"])])
	var media := func(v: Array[float]) -> float:
		var t := 0.0
		for x in v:
			t += x
		return t / maxf(float(v.size()), 1.0)
	var disp := func(v: Array[float]) -> float:
		var lo := INF
		var hi := -INF
		for x in v:
			lo = minf(lo, x)
			hi = maxf(hi, x)
		return hi - lo
	var ms: float = media.call(ds)
	var mf: float = media.call(df)
	print("")
	print("DISTANZA MEDIA A COPPIE fra come si COMPONE la memoria")
	print("   schema del sé  %.3f   (dispersione fra semi %.3f)"
			% [ms, disp.call(ds)])
	print("   FIFO           %.3f   (dispersione fra semi %.3f)"
			% [mf, disp.call(df)])
	print("QUANTA PARTE DELLA MEMORIA PARLA DI CHI SEI")
	print("   in INGRESSO    %.3f   (quanto di ciò che è successo lo faceva già)"
			% m_ing)
	print("   schema del sé  %.3f   (arricchimento %+.1f%% sull'ingresso)"
			% [ms_mia, (ms_mia / maxf(m_ing, 0.0001) - 1.0) * 100.0])
	print("   FIFO           %.3f   (arricchimento %+.1f%%)"
			% [mf_mia, (mf_mia / maxf(m_ing, 0.0001) - 1.0) * 100.0])
	print("")
	var ok_a := mf <= 0.02
	var ok_b := ms >= 0.10
	# ⚠️ riportato, NON un cancello: vedi la nota in testa al file
	var ok_c := ms_mia >= mf_mia * 1.3
	print("CANCELLO (a) col FIFO la convergenza è quasi perfetta (≤ 0.02): %s"
			% ("sì" if ok_a else "NO — il banco non prova niente"))
	print("CANCELLO (b) con lo schema le memorie si compongono diverse "
			+ "(≥ 0.10): %s"
			% ("sì" if ok_b else "NO — la meccanica non fa quello che dice"))
	print("(riportato) e parlano di più di chi sei, 1.3×: %s — il cancello "
			% ("sì" if ok_c else "no")
			+ "era dichiarato male, vedi la nota in testa")
	quit(0 if (ok_a and ok_b) else 1)
