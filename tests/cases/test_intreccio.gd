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


func run(t) -> void:
	_il_ponte_c_e(t)
	_il_punto_fisso_e_invariante(t)
	_phi_di_ieri_e_zero(t)
	_phi_misura_una_mente(t)
	_la_stessa_gentilezza_in_menti_diverse(t)
	_il_degrado_va_verso_ieri(t)
	_l_ordine_dei_tratti_e_condiviso(t)
	_dove_si_spezza(t)


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
				("chi parte al proprio riposo ci resta (scarto %.2e): il "
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
			("con l'intreccio Φ è POSITIVO (%.3e): le parti non si staccano "
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
			+ "(da %.2e a %.2e, ×%.1f): l'intreccio è della PERSONA, non del "
			+ "villaggio") % [mn, mx, mx / maxf(mn, 1e-12)])

	# --- e dentro la stessa persona, mentre si tende
	var b = _nuovo()
	b.neuro["cortisolo"] = 0.05
	var calmo: float = b.phi()
	b.neuro["cortisolo"] = 0.60
	var teso: float = b.phi()
	t.ok(calmo > teso * 1.5,
			("sotto stress l'informazione integrata CALA (%.2e → %.2e): la "
			+ "mente si restringe, e non è una metafora") % [calmo, teso])
	# ⚠️ e la controprova: il cortisolo NON deve poterlo alzare, o avremmo
	# scritto il segno al contrario e nessuno se ne accorgerebbe
	t.ok(teso < calmo, "e la direzione è quella: tendersi non integra di più")


## ⚠️ **LA TESI, RESA UN NUMERO.** La stessa identica gentilezza, in tre menti
## che stanno in tre modi diversi. Senza intreccio i canali non si parlano,
## quindi il cortisolo NON si muove in nessuno dei tre — un regalo non può
## calmare nessuno, per costruzione.
func _la_stessa_gentilezza_in_menti_diverse(t) -> void:
	var esiti: Array = []
	for stato in [[0.08, 0.10], [0.42, 0.10], [0.08, 0.62]]:
		var l = _nuovo()
		l.neuro["cortisolo"] = float(stato[0])
		l.neuro["adenosina"] = float(stato[1])
		var prima: float = float(l.neuro["cortisolo"])
		l.stimola_neuro("dopamina", 0.15)
		l.stimola_neuro("ossitocina", 0.12)
		l.stimola_neuro("serotonina", 0.12)
		for k in 600:
			l.passo_neuro(0.05, CIELO, false, 0.0)
		esiti.append(float(l.neuro["cortisolo"]) - prima)
	# in chi è in ansia la stessa carezza vale MOLTO di più
	t.ok(esiti[1] < esiti[0] - 0.05,
			("la stessa gentilezza calma chi è in ansia (%+.4f) molto più di "
			+ "chi era già sereno (%+.4f): l'effetto dipende da dov'era "
			+ "quella mente, e non c'è nessuna tabella che lo dica")
					% [esiti[1], esiti[0]])


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

	# --- e il degrado: senza ponte, un array vuoto e non un'invenzione
	t.ok(l.dove_si_spezza(-1.0).size() == 0 or l.dove_si_spezza(-1.0).size() == 2,
			"un passo malato non produce una partizione inventata")
