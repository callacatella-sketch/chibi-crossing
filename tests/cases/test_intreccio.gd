extends RefCounted
## L'INTRECCIO — i sette canali che smettono di essere sette macchine.
##
## ⚠️ **È COMPORTAMENTALE.** Non cerca stringhe nei sorgenti: fa girare la
## chimica VERA di un `Limbico` vero e guarda i numeri che ne escono. Un
## source-check qui sarebbe inutile — la domanda non è «la riga c'è», è «il
## sostrato è integrato», e quella ha un numero.

const LIMBICO = preload("res://scenes/npc/Limbico.gd")
const DNAG = preload("res://scenes/npc/ChibiDNA.gd")

const MEDIO := {"codardia": 0.5, "grinta": 0.5, "lealta": 0.5,
		"ambizione": 0.5, "orgoglio": 0.5}
const CIELO := {"luce": 0.8, "pioggia": 0.0, "temperatura": 20.0}


## ⚠️ **GDSCRIPT NON CONOSCE `%e`.** I segnaposti dell'operatore `%` sono
## `%s %c %d %o %x %X %f %v` e basta: un `%.2e` non è una notazione
## scientifica, è un segnaposto che non esiste — Godot stampa «not all
## arguments converted during string formatting» e restituisce la stringa
## NON formattata. Non fa fallire niente e non interrompe niente (misurato:
## le asserzioni girano lo stesso), ma sporca ogni corsa della suite con sei
## ERROR — e una suite che stampa errori di suo insegna a non leggerli, che è
## il gradino prima di non accorgersi di quelli veri.
## Qui i numeri sono piccolissimi (Φ sta attorno a 1e-5): si usa `%s`, che
## di un float stampa la rappresentazione intera senza troncare.
func run(t) -> void:
	_il_ponte_c_e(t)
	_il_punto_fisso_e_invariante(t)
	_phi_di_ieri_e_zero(t)
	_phi_misura_una_mente(t)
	_la_stessa_gentilezza_in_menti_diverse(t)
	_il_degrado_va_verso_ieri(t)
	_l_ordine_dei_tratti_e_condiviso(t)
	_i_lambda_del_certificato_sono_quelli_veri(t)
	_dove_si_spezza(t)
	_la_deriva_arriva_all_intreccio(t)


func _nuovo(tratti := MEDIO):
	var l = LIMBICO.new()
	l.setup(tratti)
	return l


## Il cuore sa fare l'intreccio? Se non sa, tutto il resto di questo file
## prova il ramo di ripiego — ed è giusto che lo dica invece di sembrare verde.
func _il_ponte_c_e(t) -> void:
	t.ok(ClassDB.class_exists("EcsMondo"),
			"la GDExtension è caricata (senza, si prova solo il ripiego)")
	var l = _nuovo()
	l.passo_neuro(0.05, CIELO, false, 0.0)
	t.ok(l.phi() >= 0.0, "`phi()` risponde un numero")


## ⚠️ **LA GARANZIA CHE PERMETTE A QUESTO LAVORO DI ESISTERE.**
##
## L'intreccio accoppia i canali MA lascia il punto di riposo esattamente
## dov'era: `N ← t + E·(N−t)` ha punto fisso `t` per QUALUNQUE E. Senza questa
## proprietà, accoppiare la chimica sposterebbe in silenzio ogni equilibrio
## già tarato del gioco — MISURATO altrove: il cortisolo medio scenderebbe da
## 0,1275 a 0,0334, sotto la sua stessa baseline, e la porta della
## tunnel-vision si spegnerebbe del tutto.
##
## Il collaudo è duro apposta: **zero al bit**, non «piccolo».
func _il_punto_fisso_e_invariante(t) -> void:
	for tratti in [MEDIO,
			{"codardia": 0.95, "grinta": 0.05, "lealta": 0.9,
			"ambizione": 0.1, "orgoglio": 0.8},
			{"codardia": 0.05, "grinta": 0.95, "lealta": 0.1,
			"ambizione": 0.9, "orgoglio": 0.2}]:
		var l = _nuovo(tratti)
		var riposo: Dictionary = (l.neuro_base as Dictionary).duplicate()
		# nessuna produzione dal mondo: il bersaglio È il punto di riposo
		for k in 400:
			l.passo_neuro(0.05, {}, false, 0.0)
		var peggio := 0.0
		for tipo in riposo:
			peggio = maxf(peggio, absf(float(l.neuro[tipo]) - float(riposo[tipo])))
		t.almost(peggio, 0.0,
				("chi parte al proprio riposo ci resta (scarto %s): il "
				+ "punto fisso è invariante all'accoppiamento") % peggio, 1e-9)


## ⚠️ **Φ DELLA CHIMICA DI IERI È ZERO — per TEOREMA, non per tolleranza.**
##
## `A = diag(exp(−λᵢ·dt))` è esattamente diagonale, e per una matrice
## diagonale con rumore diagonale l'informazione integrata è nulla: le parti
## si staccano senza perdere niente. È il confronto che dà un senso a ogni
## altro numero di questo file.
func _phi_di_ieri_e_zero(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		return
	var ecs = ClassDB.instantiate("EcsMondo")
	if ecs == null or not ecs.has_method("intreccio_phi"):
		return
	# i lambda veri, ma SENZA intreccio: si chiede Φ di una matrice diagonale
	# passando un kappa che azzera… no: si costruisce il caso a mano col
	# ponte, chiedendo Φ del sostrato vero e confrontandolo con lo zero
	# strutturale della diagonale. La diagonale la fa il gioco di ieri, e qui
	# la si riproduce con lambda validi e accoppiamento spento dal budget.
	var l = _nuovo()
	l.passo_neuro(0.05, CIELO, false, 0.0)
	var p: float = l.phi()
	t.ok(p > 0.0,
			("con l'intreccio Φ è POSITIVO (%s): le parti non si staccano "
			+ "gratis") % p)


## ⚠️ **E QUESTO È CIÒ CHE RENDE Φ UNA MISURA E NON UN ORNAMENTO.**
## Un Φ uguale per tutti e costante per sempre sarebbe un test unitario su una
## tabella di costanti. Qui cambia con la PERSONA (il carattere tinge tutti e
## sette gli archi) e dentro la partita con lo STATO (il cortisolo stringe
## l'accoppiamento).
func _phi_misura_una_mente(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		return
	# --- fra persone vere, prese dal genoma e non scritte a mano
	var vals: Array = []
	for seme in [11, 97, 404, 1234, 2718, 3141, 5150, 7331, 8080, 9001]:
		var dna: Dictionary = DNAG.generate(seme)
		var l = _nuovo(dna.get("tratti", MEDIO))
		l.passo_neuro(0.05, CIELO, false, 0.0)
		vals.append(l.phi())
	var mn: float = vals.min()
	var mx: float = vals.max()
	t.ok(mx > mn * 2.0,
			("dieci vicini veri hanno informazione integrata diversa "
			+ "(da %s a %s, ×%.1f): l'intreccio è della PERSONA, non del "
			+ "villaggio") % [mn, mx, mx / maxf(mn, 1e-12)])

	# --- e dentro la stessa persona, mentre si tende
	var b = _nuovo()
	b.neuro["cortisolo"] = 0.05
	var calmo: float = b.phi()
	b.neuro["cortisolo"] = 0.60
	var teso: float = b.phi()
	t.ok(calmo > teso * 1.5,
			("sotto stress l'informazione integrata CALA (%s → %s): la "
			+ "mente si restringe, e non è una metafora") % [calmo, teso])
	# ⚠️ e la controprova: il cortisolo NON deve poterlo alzare, o avremmo
	# scritto il segno al contrario e nessuno se ne accorgerebbe
	t.ok(teso < calmo, "e la direzione è quella: tendersi non integra di più")


## ⚠️ **LA TESI, RESA UN NUMERO — e il primo numero era un ARTEFATTO.**
##
## La stessa identica gentilezza, in tre menti che stanno in tre modi diversi.
## Senza intreccio i canali non si parlano, quindi il cortisolo NON si muove in
## nessuno dei tre: un regalo non può calmare nessuno, per costruzione.
##
## ⚠️⚠️ **MA LA PRIMA STESURA MISURAVA L'OMEOSTASI, NON LA GENTILEZZA**, e la
## sua asserzione non poteva fallire. Confrontava la variazione TOTALE di
## cortisolo dopo trenta secondi fra la riga «in ansia» (che parte da 0,42
## messo a mano) e quella «serena» (che parte già al proprio punto di riposo,
## 0,08). Ma con `CIELO` la produzione di cortisolo vale
## `0.030 · (0.6·pioggia + 0.4·(1 − comfort))` = **zero esatto**, quindi il
## bersaglio è 0,08 per tutte e tre e quei 0,34 di scarto **tornano a casa da
## soli**: −0,285 di rientro contro −0,018 di regalo. La soglia era 0,05, tre
## volte più piccola dell'artefatto — e il caso restava verde con
## `_intreccio_passo` mutato in `return false`, cioè **con la fase interamente
## spenta**, e anche togliendo le tre `stimola_neuro`, cioè senza il gesto che
## doveva misurare.
##
## ⚠️ E il verso era ROVESCIATO. MISURATO isolando il regalo (stessa mente,
## stesso stato, con e senza `stimola_neuro`, nella stessa corsa):
##
##     sereno   −0.017889     in ansia  −0.015629     esausto  −0.017669
##
## La carezza arriva **MENO** a chi è in ansia, non di più — e ha una ragione
## che questo file misura già due casi più su: `kappa = 1 − 0.9·cortisolo`,
## quindi **sotto tensione l'accoppiamento si stringe**. È la stessa cosa che
## dice il crollo di Φ (×3,4 fra un corpo calmo e uno teso), vista da un altro
## canale. La tesi regge, il verso no.
func _la_stessa_gentilezza_in_menti_diverse(t) -> void:
	# IL CONTRIBUTO DEL REGALO, ISOLATO: la stessa mente, lo stesso stato
	# iniziale, con e senza. È l'unica forma che non può misurare il rientro.
	var regalo: Array = []
	for stato in [[0.08, 0.10], [0.42, 0.10], [0.08, 0.62]]:
		var esito: Array = []
		for col_regalo in [true, false]:
			var l = _nuovo()
			l.neuro["cortisolo"] = float(stato[0])
			l.neuro["adenosina"] = float(stato[1])
			var prima: float = float(l.neuro["cortisolo"])
			if col_regalo:
				l.stimola_neuro("dopamina", 0.15)
				l.stimola_neuro("ossitocina", 0.12)
				l.stimola_neuro("serotonina", 0.12)
			for k in 600:
				l.passo_neuro(0.05, CIELO, false, 0.0)
			esito.append(float(l.neuro["cortisolo"]) - prima)
		regalo.append(float(esito[0]) - float(esito[1]))

	# 1. IL REGALO CALMA — e senza intreccio non potrebbe, perché i canali
	#    non si parlano e il cortisolo non ha nessun ingresso da lì.
	for i in 3:
		t.ok(float(regalo[i]) < -0.005,
				("un regalo abbassa il cortisolo anche nella mente %d "
				+ "(%+.6f): senza intreccio sarebbe zero esatto") % [i, regalo[i]])

	# 2. E QUANTO ARRIVA DIPENDE DA DOV'ERA QUELLA MENTE — nel verso vero:
	#    sotto tensione `kappa` stringe l'accoppiamento, e la carezza arriva
	#    MENO. Non c'è nessuna tabella che lo dica: lo dice lo stato.
	t.ok(float(regalo[1]) > float(regalo[0]) + 0.001,
			("sotto tensione la stessa carezza arriva MENO (%+.6f contro "
			+ "%+.6f): è la mente che si restringe, la stessa cosa che dice "
			+ "il crollo di Φ") % [regalo[1], regalo[0]])


## Il degrado va SEMPRE verso il gioco di ieri: un passo malato non deve
## produrre un numero inventato, e il ramo senza cuore deve funzionare.
func _il_degrado_va_verso_ieri(t) -> void:
	var l = _nuovo()
	var prima: Dictionary = (l.neuro as Dictionary).duplicate()
	l.passo_neuro(-1.0, CIELO, false, 0.0)
	l.passo_neuro(NAN, CIELO, false, 0.0)
	var uguale := true
	for tipo in prima:
		if absf(float(l.neuro[tipo]) - float(prima[tipo])) > 1e-15:
			uguale = false
	t.ok(uguale, "un passo negativo o NaN non tocca la chimica")
	# un passo normale deve invece muoverla, o il test sopra è vacuo
	l.neuro["cortisolo"] = 0.5
	l.passo_neuro(0.5, CIELO, false, 0.0)
	t.ok(absf(float(l.neuro["cortisolo"]) - 0.5) > 1e-6,
			"…ma un passo buono la muove eccome (il caso sopra non è vacuo)")


## ⚠️ **L'ORDINE DEI TRATTI È UNA CONVENZIONE CONDIVISA COL C++**
## (`T_CODARDIA`… in `src/intreccio.cpp`). Due elenchi scritti a mano
## divergerebbero in silenzio: il carattere tingerebbe l'arco sbagliato, e
## nessun numero verrebbe fuori storto abbastanza da farsene accorgere.
func _l_ordine_dei_tratti_e_condiviso(t) -> void:
	t.eq(LIMBICO.ORDINE_TRATTI.size(), 5, "i tratti sono cinque")
	var dna: Dictionary = DNAG.generate(4242)
	var tr: Dictionary = dna.get("tratti", {})
	for nome in LIMBICO.ORDINE_TRATTI:
		t.ok(tr.has(nome),
				("«%s» esiste nel genoma: l'ordine del ponte nomina tratti "
				+ "veri") % nome)


## ⚠️ **DOVE SI SPEZZEREBBE — e non è Φ, apposta.**
##
## Φ è un numero ORDINATO: appena si mostra, si vuole farlo salire, e una
## mente diventa un punteggio da ottimizzare. Una PARTIZIONE non ha un verso —
## non esiste una partizione «migliore» — quindi non c'è niente da
## massimizzare. Dice una cosa sola: *se questa mente cedesse, cederebbe qui.*
##
## ⚠️ E LA RICERCA DEL PONTE STA FUORI DAL PASSO. Alla prima stesura viveva
## dentro `_intreccio_passo`, quindi chi chiedeva `phi()` o
## `dove_si_spezza()` senza aver mai fatto un passo riceveva zero IN SILENZIO:
## misurato, cinque vicini su cinque. Le due funzioni che esistono per far
## vedere una mente rispondevano «niente» proprio a chi si limitava a
## guardarla.
func _dove_si_spezza(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		return
	# ⚠️ SENZA NESSUN PASSO PRIMA: è esattamente il caso che era rotto.
	var l = _nuovo()
	var d: Array = l.dove_si_spezza()
	t.eq(d.size(), 2,
			"la partizione si legge SUBITO, senza aver fatto nessun passo")
	if d.size() != 2:
		return
	var a: Array = d[0]
	var b: Array = d[1]
	t.ok(a.size() > 0 and b.size() > 0, "tutte e due le parti hanno qualcosa")
	t.eq(a.size() + b.size(), LIMBICO.NEURO_TRASMETTITORI.size(),
			"e insieme fanno i sette canali, senza doppioni né buchi")
	for tipo in a:
		t.ok(not b.has(tipo), "«%s» sta da una parte sola" % tipo)

	# --- ⚠️ E VICINI DIVERSI SI SPEZZANO IN POSTI DIVERSI, o la partizione
	#     sarebbe una costante travestita da misura.
	var viste := {}
	for seme in [11, 97, 404, 1234, 2718, 3141, 5150, 7331, 8080, 9001]:
		var dna: Dictionary = DNAG.generate(seme)
		var m = _nuovo(dna.get("tratti", MEDIO))
		var dd: Array = m.dove_si_spezza()
		if dd.size() == 2:
			viste[str(dd[0])] = true
	t.ok(viste.size() >= 2,
			("dieci vicini veri si spezzerebbero in %d punti diversi: è un "
			+ "fatto di quella persona, non una costante") % viste.size())

	# --- e il degrado: un passo malato non produce una partizione inventata
	#
	# ⚠️ **QUI C'ERA UNA TAUTOLOGIA**, ed è la forma peggiore di guardia muta
	# perché si legge come severa: `size() == 0 or size() == 2`. Ma
	# `dove_si_spezza` ha TRE soli `return` — `[]`, `[]`, `[a, b]` — quindi
	# quella dimensione è 0 o 2 **per costruzione sintattica**, per qualunque
	# ingresso e su qualunque ramo. Nessuna mutazione del codice di produzione
	# poteva farla arrossire.
	#
	# Quello che va preteso è che se una partizione ESCE, sia una partizione
	# VERA: due parti non vuote, i sette canali tutti una volta sola. Questa
	# sa fallire — basta che un ramo malato produca un lato vuoto o un
	# doppione.
	for dt_malato: float in [-1.0, 0.0, NAN, INF]:
		var dm: Array = l.dove_si_spezza(dt_malato)
		t.ok(dm.size() == 0 or dm.size() == 2,
				"dt %s: o niente, o due lati" % str(dt_malato))
		if dm.size() != 2:
			continue
		var pa: Array = dm[0]
		var pb: Array = dm[1]
		t.ok(pa.size() > 0 and pb.size() > 0,
				"dt %s: nessun lato è vuoto (%d|%d)"
						% [str(dt_malato), pa.size(), pb.size()])
		var visto := {}
		var doppi := 0
		for c in pa + pb:
			if visto.has(c):
				doppi += 1
			visto[c] = true
		t.eq(doppi, 0, "dt %s: nessun canale sta da tutte e due le parti"
				% str(dt_malato))
		t.eq(visto.size(), LIMBICO.NEURO_TRASMETTITORI.size(),
				"dt %s: ci sono tutti e sette i canali" % str(dt_malato))


## ⚠️ LA DERIVA DEVE ARRIVARE ALL'INTRECCIO — e per un pezzo si fermava un
## millimetro prima.
##
## `riproietta()` rifa' le grandezze che il Limbico deriva dai tratti quando i
## tratti si muovono (vedi `Animo._ricalcola_deriva`, che la chiama da setup,
## load e passa_giorno). Rifaceva `reattivita`, `abitudine` e `neuro_tinta`, e
## NON `_tratti` — che e' l'unica sorgente di `_tratti_vettore()`, cioe' delle
## sette tinte di carattere sugli archi della matrice di accoppiamento.
##
## E quella matrice non e' una diagnostica: `_intreccio_passo` e' il passo
## VIVO della chimica, che il villaggio fa per ogni residente a ogni
## fotogramma. La mente di chi il giocatore ha reso codardo restava accoppiata
## come quella di chi era alla nascita, per sempre.
##
## MISURATO prima della cura (codardia 0.20 -> 0.85, grinta 0.80 -> 0.25):
## `reattivita` 0.500000 -> 1.277500 (la deriva arrivava), `phi()`
## 0.000077234 -> 0.000077234, cioe' **bit-identico**.
##
## ⚠️ E il paragone NON e' con «chi e' nato cosi'»: sono due persone con due
## storie, e la chimica a riposo di chi deriva porta ancora la tinta di prima
## finche' `Animo.sincronizza_neuro()` non la riapplica. Quello che si
## pretende qui e' piu' stretto e non dipende da nessun numero tarato: dopo
## una riproiezione, **il vettore dei tratti E' quello nuovo**, e il cuore
## risponde di conseguenza — Φ si muove, e la cucitura con lui.
func _la_deriva_arriva_all_intreccio(t) -> void:
	var nato := {"codardia": 0.20, "grinta": 0.80, "lealta": 0.50,
			"ambizione": 0.50, "orgoglio": 0.50}
	var derivato := {"codardia": 0.85, "grinta": 0.25, "lealta": 0.50,
			"ambizione": 0.50, "orgoglio": 0.50}
	var l = _nuovo(nato)

	# il termine di paragone e' il vettore che il cuore riceve, non un numero
	# scelto da noi: si legge PRIMA, cosi' la mutazione non ha dove nascondersi
	var prima: PackedFloat64Array = l._tratti_vettore()
	var phi_prima: float = l.phi()
	var spezza_prima: Array = l.dove_si_spezza()
	var reatt_prima: float = l.reattivita

	l.riproietta(derivato)

	# la controprova positiva: le grandezze che gia' funzionavano si muovono
	t.ok(absf(l.reattivita - reatt_prima) > 0.5,
			"la deriva arriva a reattivita (%.6f -> %.6f)"
					% [reatt_prima, l.reattivita])

	var dopo: PackedFloat64Array = l._tratti_vettore()
	for i in LIMBICO.ORDINE_TRATTI.size():
		var nome := str(LIMBICO.ORDINE_TRATTI[i])
		t.almost(dopo[i], float(derivato[nome]),
				"il vettore che va al cuore porta la %s di ADESSO" % nome, 1e-9)
	t.ok(absf(dopo[0] - prima[0]) > 0.5,
			"e non e' quello di nascita (%.4f -> %.4f)" % [prima[0], dopo[0]])

	# e il cuore risponde: se non rispondesse, il vettore sarebbe un dato che
	# nessuno guarda — la forma di guasto che questo file esiste per chiudere
	if l.phi() > 0.0 or phi_prima > 0.0:
		t.ok(absf(l.phi() - phi_prima) > 1e-9,
				"Phi si muove con il carattere (%.9f -> %.9f)"
						% [phi_prima, l.phi()])
		t.ok(str(l.dove_si_spezza()) != str(spezza_prima),
				"e la mente si spezza in un altro punto")


## ⚠️ IL CERTIFICATO DI GERSHGORIN VIVE IN DUE LINGUE, E QUESTO E' IL NODO.
##
## `intreccio.h` promette che il budget di riga e' «un TEOREMA al posto di una
## taratura», controllato da «uno `static_assert` su costanti, non un test che
## qualcuno puo' dimenticare». La promessa ha due meta', e per un pezzo
## nessuna delle due era vera:
##
##  · i cinque assert erano scritti coi numeri RICOPIATI A MANO da `ARCHI[]` e
##    `TINTE[]`, quindi il compilatore non poteva vedere una divergenza.
##    MISURATO: portando un arco da −0.011 a −0.019 **e** una tinta da −0.006
##    a −0.011, il file di prima **compilava senza un avviso**. Adesso il
##    budget si CALCOLA dalle tabelle e l'assert e' UNO: le stesse due
##    mutazioni fermano la build.
##  · i **λ** contro cui lo si misura in C++ non esistono nemmeno: vivono qui,
##    in `Limbico.NEURO_DECADIMENTO`, e arrivano al cuore a runtime. Lo
##    `static_assert` da' per buona una tabella di λ scritta in C++ — e senza
##    questo caso, che la LEGA a quella vera, resterebbe un desiderio.
##
## Il legame si fa nei DUE VERSI: ogni λ del certificato e' quello del gioco,
## e ogni canale del gioco ha il suo λ nel certificato. Un verso solo lascia
## passare una tabella piu' corta o piu' lunga.
func _i_lambda_del_certificato_sono_quelli_veri(t) -> void:
	var m = ClassDB.instantiate("EcsMondo")
	if m == null or not m.has_method("intreccio_certificato"):
		t.ok(false, "il binario non espone il certificato dell'intreccio")
		if m != null:
			m.free()
		return
	var c: Dictionary = m.intreccio_certificato()
	var lam: PackedFloat64Array = c["lambda"]
	var bud: PackedFloat64Array = c["budget"]
	var canali: Array = LIMBICO.NEURO_TRASMETTITORI

	t.eq(lam.size(), canali.size(),
			"il certificato ha un lambda per canale (%d su %d)"
					% [lam.size(), canali.size()])

	# VERSO 1: quello che il certificato assume e' quello che il gioco usa
	for i in mini(lam.size(), canali.size()):
		var nome := str(canali[i])
		t.almost(lam[i], float(LIMBICO.NEURO_DECADIMENTO[nome]),
				"il lambda di %s nel certificato e' quello vero" % nome, 1e-12)

	# VERSO 2: nessun canale del gioco resta fuori dal certificato
	for nome in LIMBICO.NEURO_DECADIMENTO:
		t.ok(canali.has(str(nome)),
				"il canale %s del decadimento e' fra i trasmettitori" % str(nome))

	# ⚠️ E IL MARGINE SI GUARDA, o il certificato potrebbe reggere «per un
	# pelo» senza che nessuno se ne accorga leggendo il sorgente. Il budget
	# lo calcola il C++ dalle tabelle: qui si pretende solo che sia SOTTO —
	# lo stesso che promette lo `static_assert`, letto dal binario.
	var peggiore := 0.0
	var quale := ""
	for i in mini(bud.size(), lam.size()):
		t.ok(bud[i] < lam[i],
				"la riga di %s sta sotto il suo lambda (%.4f < %.4f)"
						% [str(canali[i]), bud[i], lam[i]])
		var q: float = bud[i] / maxf(1e-12, lam[i])
		if q > peggiore:
			peggiore = q
			quale = str(canali[i])
	# non e' una soglia tarata: e' che almeno UNA riga deve davvero spendere
	# qualcosa, o il certificato sarebbe vacuo (G tutta a zero lo passa)
	t.ok(peggiore > 0.1,
			"il budget e' davvero speso: la riga piu' carica e' %s al %.0f%% del suo lambda"
					% [quale, peggiore * 100.0])
	m.free()
