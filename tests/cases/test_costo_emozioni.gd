extends RefCounted
## QUANTO COSTA AVERE UN CUORE — la misura, non l'impressione.
##
## `avanza()` gira una volta per frame per TUTTO il villaggio, e adesso
## dentro ci sta anche la lettura del grafo dei ricordi. Ventotto vicini con
## ventiquattro ricordi a testa fanno 672 righe da pesare, e ogni riga costa
## un `exp2`. Farlo a ogni frame sarebbe un motore acceso a vuoto — e
## nessuno se ne accorgerebbe leggendo il codice, perché il codice ha
## esattamente lo stesso aspetto.
##
## LE DUE MISURE, e la seconda è quella che conta.
##
##  1. **IL TETTO ASSOLUTO** è la rete contro la catastrofe (un'allocazione
##     per frame, una vista che degenera). Il numero è generoso apposta:
##     questo file gira anche su un runner di CI condiviso, e un test di
##     prestazione che diventa rosso quando la macchina è occupata smette di
##     essere letto — è il modo esatto in cui una misura muore.
##
##  2. **IL RAPPORTO col villaggio smemorato** è lo strumento affilato, ed è
##     indipendente dalla macchina: si fa girare lo STESSO banco due volte,
##     una con i grafi pieni e una con i grafi vuoti, e si guarda quanto è
##     costata la Fase 4. Misurato su questa macchina: **1.01** (21,6 ms
##     contro 21,3 ms su 6.000 passi) — cioè il gradino rende la memoria
##     praticamente gratis. Togliendo il gradino (`PASSO_EMO = 0`, cioè
##     rileggere il cuore a ogni frame) lo stesso rapporto diventa **2.74**
##     (61,6 ms contro 22,5). La soglia sta in mezzo, a 1.60, e non è di
##     gusto: è il punto medio fra un sistema che lavora a gradini e uno che
##     lavora a frame.
##
## Si prende il MIGLIORE di tre corse per lato, non la media: il tempo di
## esecuzione ha una coda lunga verso l'alto (uno scheduler, una pagina che
## manca) e nessuna verso il basso, quindi il minimo è la stima meno rumorosa
## di quanto costa DAVVERO il lavoro.

const DT := 1.0 / 60.0
const VICINI := 28
const PASSI := 6000

## Il tetto assoluto, in millisecondi, per 6.000 passi con 28 vicini. Vale
## 0,067 ms per frame per l'INTERO villaggio, cioè lo 0,4% di un frame a
## 60 Hz: sopra di lì la memoria smetterebbe di essere trascurabile.
const TETTO_MS := 400.0

## Quanto può costare la memoria rispetto allo stesso villaggio senza
## ricordi. Vedi la misura in cima al file.
const RAPPORTO_MAX := 1.60


func run(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	var sonda = ClassDB.instantiate("EcsMondo")
	# `var … =` e non `:=`: `sonda` non è tipizzata, e l'inferenza fallisce
	# al PARSE — cioè il file non gira affatto e la suite lo salta.
	var ha = sonda.has_method("debug_emozioni")
	sonda.free()
	if not ha:
		t.ok(false, "EcsMondo non espone «debug_emozioni»: la Fase 4 non è nel binario")
		return

	var pieno := _migliore_di_tre(t, true)
	var vuoto := _migliore_di_tre(t, false)

	# ANTI-TAUTOLOGIA. Un banco che misura zero lavoro passa qualunque
	# soglia: qui si pretende che i grafi siano DAVVERO pieni e che il
	# modulatore sia DAVVERO mosso, se no si starebbe cronometrando due
	# volte lo stesso villaggio smemorato.
	t.eq(int(pieno["ricordi"]), 24,
			"il banco misura un villaggio con i grafi PIENI (%d ricordi a testa)"
					% int(pieno["ricordi"]))
	t.ok(float(pieno["mod_cura"]) > 1.0,
			"…e con le emozioni accese davvero (mod cura = %s)" % str(pieno["mod_cura"]))
	t.eq(int(vuoto["ricordi"]), 0, "e il banco di confronto è lo stesso villaggio senza ricordi")
	t.ok(float(pieno["ms"]) > 0.5,
			"la corsa dura abbastanza da poterla cronometrare (%.2f ms)" % float(pieno["ms"]))

	var ms := float(pieno["ms"])
	var per_frame_us := ms * 1000.0 / float(PASSI)
	t.ok(ms <= TETTO_MS,
			("%d passi con %d vicini e i grafi pieni: %.2f ms (tetto %.0f) — "
			+ "%.2f µs per frame per tutto il villaggio, cioè %.3f%% di un frame a 60 Hz")
					% [PASSI, VICINI, ms, TETTO_MS, per_frame_us,
							100.0 * per_frame_us / 16666.0])

	var rapporto := ms / maxf(float(vuoto["ms"]), 0.001)
	t.ok(rapporto <= RAPPORTO_MAX,
			("avere una memoria costa %.2f volte non averla (%.2f ms contro %.2f): "
			+ "il tetto è %.2f, e rileggere il cuore a ogni frame invece che a "
			+ "gradini lo porterebbe a 2.7")
					% [rapporto, ms, float(vuoto["ms"]), RAPPORTO_MAX])

	# E LE DUE PORTE. `osserva` gira una volta per testimone per gesto e
	# `racconta` al più una volta ogni 3,5 s in tutto il villaggio: non sono
	# nel bilancio del frame, ma un numero misurato vale più di una
	# rassicurazione.
	_le_due_porte(t)


## Il banco: `VICINI` residenti veri, bisogni riferiti, corpo libero, e —
## se `con_ricordi` — ventiquattro ricordi a testa. Ventiquattro e non
## «tanti»: è MAX_FATTI, cioè il caso peggiore che il gioco possa produrre.
func _corri(con_ricordi: bool) -> Dictionary:
	var m = ClassDB.instantiate("EcsMondo")
	m.imposta_ritmo(240.0)
	var ids: Array = []
	for i in VICINI:
		ids.append(m.registra(PackedStringArray(["goloso"]), ""))
	var fatti: int = m.maschera_fatti(PackedStringArray(["spuntino_vicino",
			"amico_in_giro", "aiuola_da_annaffiare", "meraviglia_posto"]))
	for i in VICINI:
		if con_ricordi:
			# otto verbi × tre soggetti diversi = ventiquattro righe: la
			# fusione unirebbe i gemelli, e un grafo «pieno» di sei ricordi
			# misurerebbe un quarto del lavoro vero
			for s in 3:
				for v in 8:
					m.osserva(ids[i], v, Vector3(float(v), 0.0, float(s)),
							ids[(i + s + 1) % VICINI])
		m.riferisci_bisogni(ids[i], PackedFloat64Array([0.4, 0.5, 0.6, 0.3, 0.7]))
		m.riferisci_agenda(ids[i], fatti, true, false)

	var t0 := Time.get_ticks_usec()
	for k in PASSI:
		m.avanza(DT, 0.5)
	var t1 := Time.get_ticks_usec()

	var g: Dictionary = m.debug_grafo(ids[0])
	var e: Dictionary = m.debug_emozioni(ids[0])
	var mod: PackedFloat64Array = e["mod"]
	var out := {
		"ms": float(t1 - t0) / 1000.0,
		"ricordi": (g["ricordi"] as Array).size(),
		"mod_cura": float(mod[m.indice_azione("cura_giardino")]),
	}
	m.free()
	return out


## Il MIGLIORE di tre: il tempo ha una coda lunga verso l'alto e nessuna
## verso il basso, quindi il minimo è la stima meno rumorosa del lavoro vero.
func _migliore_di_tre(t, con_ricordi: bool) -> Dictionary:
	var migliore := {}
	for k in 3:
		var r := _corri(con_ricordi)
		if migliore.is_empty() or float(r["ms"]) < float(migliore["ms"]):
			migliore = r
	return migliore


## Le due porte della memoria, misurate a grafo PIENO — che è il caso in cui
## costano di più: `inserisci` scandisce ventiquattro righe per la fusione e
## altrettante per trovare la più debole, `racconta` ne scandisce
## ventiquattro in chi ascolta e ventiquattro in chi parla.
func _le_due_porte(t) -> void:
	var m = ClassDB.instantiate("EcsMondo")
	m.imposta_ritmo(240.0)
	var a: int = m.registra(PackedStringArray([]), "")
	var b: int = m.registra(PackedStringArray([]), "")
	# TRE SOGGETTI DIVERSI, e non «uno e poi due volte nessuno»: la fusione
	# guarda la terna (verbo, cosa, soggetto), quindi due gesti «per nessuno»
	# collassano in uno e il grafo si ferma a sedici righe — cioè si
	# misurerebbe un banco meno pieno di quanto dice il suo nome.
	var soggetti := [a, b, -1]
	for s in 3:
		for v in 8:
			m.osserva(a, v, Vector3(float(v), 0.0, float(s)), soggetti[s])
	t.eq((m.debug_grafo(a)["ricordi"] as Array).size(), 24,
			"le due porte si misurano a grafo pieno, che è dove costano di più")

	var t0 := Time.get_ticks_usec()
	for k in 10000:
		m.osserva(a, k % 8, Vector3(float(k), 0.0, 7.0), -1)
	var t1 := Time.get_ticks_usec()
	var us_osserva := float(t1 - t0) / 10000.0

	var t2 := Time.get_ticks_usec()
	for k in 10000:
		m.racconta(a, b, 0.55)
	var t3 := Time.get_ticks_usec()
	var us_racconta := float(t3 - t2) / 10000.0

	# le soglie sono larghe apposta: qui non si tara niente, si tiene la
	# porta chiusa a un'allocazione o a una scansione quadratica che entrasse
	# di soppiatto. In partita `osserva` gira una volta per testimone per
	# gesto e `racconta` al più una volta ogni 3,5 s in tutto il villaggio.
	# (Il campione di `racconta` comprende le prime otto chiamate, che
	# scrivono davvero in chi ascolta, e poi il silenzio — che è comunque il
	# termine dominante: due scansioni da ventiquattro righe l'una.)
	t.ok(us_osserva < 20.0,
			"vedere qualcosa costa %.3f µs a grafo pieno (attraverso il ponte Variant)" % us_osserva)
	t.ok(us_racconta < 20.0,
			"raccontarlo costa %.3f µs, e in partita succede al più ogni 3,5 s" % us_racconta)
	m.free()
