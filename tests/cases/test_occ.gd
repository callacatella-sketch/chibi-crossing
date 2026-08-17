extends RefCounted
## LE TINTE — cosa prova un vicino per quello che ti ha visto fare.
##
## Il motore è puro (src/sistema_occ.cpp) e non è raggiungibile direttamente
## dal GDScript: lo si interroga da `debug_occ`, che chiama le stesse due
## funzioni che chiamerà il gioco (`chibi::valuta`, `chibi::modulatori`). Un
## test che passasse da una scorciatoia proverebbe una funzione che il gioco
## non usa — è il difetto che la revisione della Fase 1 ha trovato, e non si
## ripete.
##
## LE DUE ASSERZIONI CHE CONTANO PIÙ DI TUTTE, e sono qui per due lezioni già
## pagate da questo progetto:
##
##  1. **LA NEUTRALITÀ ESATTA.** Con il grafo vuoto gli otto modulatori
##     devono valere `1.0` **bit per bit**, non «circa 1». Su quella
##     uguaglianza poggia la prova di equivalenza dell'agenda (67.200
##     confronti esatti sui double): un `1.0000000000000002` la farebbe
##     cadere, o peggio la farebbe passare per un pelo oggi e cadere fra sei
##     mesi, quando nessuno saprà più perché.
##
##  2. **L'ABLAZIONE.** Il gusto è l'unico canale da cui il CARATTERE entra in
##     questo sistema, e lo si prova a tre gradini: spento (nessuna tinta,
##     nessun modulatore mosso), appiattito (il sistema vive ma non distingue
##     più nessuno), vero (quattrocento caratteri, quattrocento risposte
##     diverse — canale per canale). È la lezione delle `REAZIONI` di `Animo`,
##     che per un vicino che sta bene valevano `0.000000` per TUTTI i
##     caratteri: il sistema c'era, girava, aveva i suoi test verdi, e non
##     discriminava niente — cioè era un dado con addosso il nome di una
##     teoria. Il gradino «appiattito» è quello che smaschera una colonna
##     morta dentro un vettore che nel complesso sembra variare.

const DNA := preload("res://scenes/npc/ChibiDNA.gd")
const GUSTO := preload("res://scenes/npc/Gusto.gd")
const BRAIN := preload("res://scenes/npc/VillagerBrain.gd")

## I NOMI DEGLI OTTO VERBI, nell'ordine di `chibi::Verbo` (src/grafo_ricordi.h),
## e la cosa di cui ciascuno parla. È una SECONDA STESURA del contratto,
## scritta a mano apposta: è così che in questo progetto si tengono legate due
## tabelle gemelle (i fatti, le azioni, i bisogni, gli operatori hanno tutti il
## loro confronto uno-a-uno). Se qualcuno riordina l'enum di là, `_la_tabella`
## diventa rossa invece di lasciar divergere in silenzio due elenchi.
const VERBI := ["annaffia", "semina", "raccoglie", "costruisce",
		"taglia", "pesca", "cucina", "dona"]
const COSA_ATTESA := {
	"annaffia": "fiore", "semina": "fiore", "raccoglie": "cibo",
	"costruisce": "casa", "taglia": "fuoco", "pesca": "pesce",
	"cucina": "cibo", "dona": "amico",
}

## I tre indici dell'agenda che questo file nomina (chibi::Azione)
const AZ_CHIACCHIERE := 2
const AZ_CURA_GIARDINO := 3
const AZ_STELLA := 5

## `var` e non `const`: un PackedFloat64Array costruito da un Array non è
## un'espressione costante per il parser di GDScript.
var NEUTRO := PackedFloat64Array([1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
var ZERO := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])

var _caratteri: Array = [] # i 400 gusti veri, calcolati una volta sola
# le tre bandiere arrivano dal C++, mai scritte a mano: un test che scrive «2»
# per R_SU_DI_ME resta verde il giorno che le bandiere cambiano valore
var _sentito := 0
var _a_me := 0
var _detto := 0


func run(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	var m = ClassDB.instantiate("EcsMondo")
	if not m.has_method("debug_occ"):
		t.ok(false, "EcsMondo non espone «debug_occ»: sistema_occ non è nel binario")
		m.free()
		return
	var d0: Dictionary = m.debug_occ(PackedFloat64Array(), NEUTRO, 0.0, {})
	_sentito = int(d0["sentito"])
	_a_me = int(d0["su_di_me"])
	_detto = int(d0["detto"])
	for s in range(1000, 1400):
		_caratteri.append(GUSTO.da_dna(DNA.generate(s)))

	_la_tabella(t, m)
	_il_gusto_pesca_da_dove_il_dato_vive(t)
	_il_tetto_del_gusto_pinza(t)
	_ogni_cosa_ha_i_suoi_geni(t)
	_il_gusto_porta_il_carattere(t, m)
	_il_grafo_vuoto_e_neutro(t, m)
	_solo_due_si_muovono(t, m)
	_l_ablazione(t, m)
	_nessuna_tinta_negativa(t, m)
	_lo_specchio_ostile(t, m)
	_una_voce_non_pesa_piu_di_un_occhio(t, m)
	_il_regalo_pesa_e_ringrazia(t, m)
	_la_gratitudine_vale_il_doppio_nelle_chiacchiere(t, m)
	_il_tempo_passa_in_lettura(t, m)
	_l_interesse_e_di_una_cosa_sola(t, m)
	_la_saturazione_frena(t, m)
	_l_ammirazione_e_la_somma(t, m)
	_niente_fuori_scala(t, m)
	_le_tarature_assurde(t, m)
	_e_deterministico(t, m)
	m.free()


# ---------------------------------------------------------------- utilità

## Un grafo dai ricordi: ognuno è [verbo, bandiere, quante, intensita, quando].
func _grafo(lista: Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for r in lista:
		for v in r:
			out.append(float(v))
	return out


## Un ricordo solo, appena successo, forte quanto può.
func _fresco(verbo: int, bandiere := 0) -> PackedFloat64Array:
	return _grafo([[verbo, bandiere, 1, 255, 0.0]])


# ---------------------------------------------------------------- i casi

## LA TABELLA VERBO→COSA, e l'ordine delle sei cose.
## `Gusto.COSE` (GDScript) indicizza l'array che attraversa il ponte e finisce
## dentro `Gusto.per_cosa[C_FIORE]` di là: se i due ordini divergono, ogni
## vicino del villaggio comincia ad appassionarsi alla cosa sbagliata — e
## nient'altro se ne accorge, perché i numeri restano tutti plausibili.
func _la_tabella(t, m) -> void:
	var d: Dictionary = m.debug_occ(PackedFloat64Array(), NEUTRO, 0.0, {})
	t.eq(int(d["n_verbi"]), VERBI.size(), "gli otto verbi ci sono tutti")
	t.eq(int(d["n_cose"]), GUSTO.COSE.size(), "e le sei cose pure")
	t.eq(int(d["max_fatti"]), 24, "il grafo tiene ventiquattro ricordi")
	var cdv: PackedInt32Array = d["cosa_del_verbo"]
	t.eq(cdv.size(), VERBI.size(), "la tabella verbo→cosa copre ogni verbo")
	for i in VERBI.size():
		var verbo := str(VERBI[i])
		var atteso := int(GUSTO.COSE.find(str(COSA_ATTESA[verbo])))
		t.eq(int(cdv[i]), atteso,
				"«%s» parla di «%s»" % [verbo, COSA_ATTESA[verbo]])
	# ogni cosa dev'essere raggiungibile da almeno un verbo, se no è una voce
	# che vive nel motore e non arriva mai allo schermo
	for c in GUSTO.COSE.size():
		t.ok(Array(cdv).has(c), "qualche verbo parla di «%s»" % GUSTO.COSE[c])
	# le tre bandiere sono potenze di due DIVERSE: se due coincidessero,
	# «me l'hanno detto» accenderebbe «l'ha fatto per me» e il pettegolezzo
	# diventerebbe un regalo
	for x in [_sentito, _a_me, _detto]:
		t.ok(x > 0 and (x & (x - 1)) == 0, "la bandiera %d è una potenza di due" % x)
	t.eq(_sentito | _a_me | _detto, _sentito + _a_me + _detto,
			"e le tre non si sovrappongono")


## IL GUSTO PESCA DA DOVE IL DATO VIVE DAVVERO.
##
## `Gusto.gd` non tiene una tabella sua di «a cosa tiene questa creatura»: la
## legge da dove c'è già — i pesi del genoma (`ChibiDNA.generate`) e i bisogni
## che le indoli accelerano (`VillagerBrain.INDOLI`). Sono nomi scritti a mano
## in un file che sta lontano dai due proprietari, e questo è precisamente il
## posto in cui, in questo progetto, due tabelle gemelle hanno già preso
## strade diverse (le specie, la scala della ribellione).
##
## LA MODALITÀ DI GUASTO, ed è muta: un nome scritto storto non solleva
## niente. `pesi.get("gardn", 1.0)` torna 1.0 — cioè NEUTRO — per ogni vicino
## del villaggio, e quel canale del carattere smette di esistere restando
## plausibile: nessun errore, nessun valore assurdo, e la suite verde. È
## esattamente la forma delle `REAZIONI` di `Animo`, che per un vicino che sta
## bene valevano `0.000000` per TUTTI i caratteri mentre il sistema girava.
## Perciò i nomi non si controllano a occhio: si chiedono ai proprietari.
func _il_gusto_pesca_da_dove_il_dato_vive(t) -> void:
	# --- i PESI: ogni chiave di DA_PESO deve esistere in un genoma vero
	var dna: Dictionary = DNA.generate(4242)
	var pesi: Dictionary = dna.get("weights", {})
	t.ok(not pesi.is_empty(), "un genoma vero ha dei pesi da cui pescare")
	for cosa in GUSTO.DA_PESO:
		t.ok(GUSTO.COSE.has(str(cosa)),
				"«%s» ha un peso, ed è una delle sei cose" % cosa)
		var chiavi: Array = GUSTO.DA_PESO[cosa]
		t.ok(not chiavi.is_empty(), "…e almeno un peso da cui nascere (%s)" % cosa)
		for k in chiavi:
			t.ok(pesi.has(str(k)),
					"«%s» nasce dal peso «%s», che nel genoma esiste davvero" % [cosa, k])
	# e nessuna delle sei resta senza radice: una cosa sempre neutra è una
	# voce che vive nel motore e non dice niente a nessuno
	for cosa in GUSTO.COSE:
		t.ok(GUSTO.DA_PESO.has(str(cosa)),
				"la cosa «%s» ha da dove nascere" % cosa)

	# --- le INDOLI: il ponte con i bisogni deve coprirle tutte
	var brain = BRAIN.new()
	for k in GUSTO.COSA_DEL_BISOGNO:
		t.ok((brain.needs as Dictionary).has(str(k)),
				"«%s» è un bisogno vero del cervello" % k)
		t.ok(GUSTO.COSE.has(str(GUSTO.COSA_DEL_BISOGNO[k])),
				"…e punta a una cosa vera («%s»)" % GUSTO.COSA_DEL_BISOGNO[k])
	for nome in BRAIN.INDOLI:
		var voce: Array = BRAIN.INDOLI[nome]
		t.ok(voce.size() >= 3, "l'indole «%s» ha bisogno e moltiplicatore" % nome)
		t.ok(GUSTO.COSA_DEL_BISOGNO.has(str(voce[1])),
				"l'indole «%s» accelera «%s», e quel bisogno arriva fino al gusto"
						% [nome, voce[1]])


## IL TETTO DEL GUSTO PINZA DAVVERO — e senza di lui il ponte riceve numeri
## fuori dalla scala che dichiara.
##
## `TETTO = 4.0` non è una taratura del carattere: è la sbarra che tiene i
## sei numeri in un intervallo raccontabile anche il giorno che qualcuno alza
## un moltiplicatore in `VillagerBrain.INDOLI` — cioè esiste esattamente per
## il cambiamento che nessun altro test vedrebbe. Toglierlo lasciava la suite
## VERDE: su quattrocento caratteri veri il massimo passava da 4,0000 a
## 4,7941 e nessuno se ne accorgeva, perché `chibi::valuta` accetta qualunque
## numero positivo e i modulatori restano plausibili.
##
## Due misure, e la seconda non dipende dalla distribuzione di `ChibiDNA`:
## quattrocento caratteri veri (dodici valori arrivano al tetto oggi) e la
## combinazione PIÙ CALDA che le due tabelle permettono, costruita dalle
## tabelle stesse invece che scritta a mano.
func _il_tetto_del_gusto_pinza(t) -> void:
	var oltre := 0
	var al_tetto := 0
	var massimo := 0.0
	for gusto in _caratteri:
		for i in gusto.size():
			massimo = maxf(massimo, float(gusto[i]))
			if float(gusto[i]) > GUSTO.TETTO:
				oltre += 1
			elif float(gusto[i]) >= GUSTO.TETTO:
				al_tetto += 1
	t.eq(oltre, 0,
			"su %d letture di caratteri veri nessun gusto esce dalla scala dichiarata"
					% (_caratteri.size() * GUSTO.COSE.size()))
	t.ok(massimo <= GUSTO.TETTO,
			"e il massimo resta il tetto (%.4f)" % massimo)
	# …E IL TETTO MORDE: senza questa riga la precedente sarebbe vera anche
	# per un gusto che al tetto non ci arriva mai, cioè proverebbe il
	# silenzio invece della sbarra.
	t.ok(al_tetto > 0,
			"…e ci arriva davvero: %d valori sono esattamente al tetto" % al_tetto)

	# LA COMBINAZIONE PIÙ CALDA, letta dalle tabelle: il bisogno su cui due
	# indoli si moltiplicano di più, e il peso più alto che un genoma vero
	# scrive per la cosa che quel bisogno serve.
	var per_bisogno := {}
	for nome in BRAIN.INDOLI:
		var voce: Array = BRAIN.INDOLI[nome]
		if voce.size() < 3:
			continue
		var b := str(voce[1])
		var lista: Array = per_bisogno.get(b, [])
		lista.append([float(voce[2]), str(nome)])
		per_bisogno[b] = lista
	var migliore := 0.0
	var due: Array = []
	var cosa_calda := ""
	for b in per_bisogno:
		var lista: Array = per_bisogno[b]
		lista.sort_custom(func(x, y): return float(x[0]) > float(y[0]))
		if lista.size() < 2:
			continue
		var prod := float(lista[0][0]) * float(lista[1][0])
		if prod > migliore:
			migliore = prod
			due = [str(lista[0][1]), str(lista[1][1])]
			cosa_calda = str(GUSTO.COSA_DEL_BISOGNO.get(str(b), ""))
	t.ok(cosa_calda != "" and due.size() == 2,
			"due indoli spingono la stessa cosa (%s: %s ×%.2f)" % [cosa_calda, str(due), migliore])
	if cosa_calda == "" or due.size() != 2:
		return
	# il peso più alto che un genoma vero scrive per quella cosa: niente
	# numeri inventati, si guarda il campione già calcolato
	var chiavi: Array = GUSTO.DA_PESO.get(cosa_calda, [])
	var peso_vero := 0.0
	for s in range(1000, 1400):
		var pesi: Dictionary = (DNA.generate(s).get("weights", {}) as Dictionary)
		var somma := 0.0
		for k in chiavi:
			somma += float(pesi.get(str(k), 1.0))
		peso_vero = maxf(peso_vero, somma / float(maxi(1, chiavi.size())))
	t.ok(peso_vero * migliore > GUSTO.TETTO,
			"PREMESSA: senza tetto questo carattere uscirebbe a %.4f" % (peso_vero * migliore))
	var caldo: Dictionary = {"weights": {}, "indole": due}
	for k in chiavi:
		(caldo["weights"] as Dictionary)[str(k)] = peso_vero
	var gusto_caldo: PackedFloat64Array = GUSTO.da_dna(caldo)
	var i_caldo := int(GUSTO.COSE.find(cosa_calda))
	t.ok(float(gusto_caldo[i_caldo]) == GUSTO.TETTO,
			"e il tetto lo ferma ESATTAMENTE lì (%.10f)" % gusto_caldo[i_caldo])


## OGNI COSA HA I SUOI GENI — e sono TANTI quanti la tabella dichiara.
##
## «La casa È il tetto, i muri, la porta e la finestra»: quattro pesi, e la
## media fra loro. Sostituire quella riga con `["roof","roof","roof","roof"]`
## lasciava la suite VERDE — la tabella continuava a dichiarare quattro voci,
## ogni voce esisteva davvero nel genoma, e tre quarti del carattere di quella
## persona smettevano di contare in silenzio.
##
## Il conto qui NON legge la tabella per sapere QUALI geni cercare: prende
## tutti i pesi di un genoma vero, li muove UNO PER VOLTA, e conta quanti
## fanno cambiare ciascuna cosa. Quel numero deve combaciare con la lunghezza
## che la tabella dichiara — ed è proprio lì che la mutazione si spezza:
## quattro voci dichiarate, un solo gene che muove.
func _ogni_cosa_ha_i_suoi_geni(t) -> void:
	# un genoma PIATTO e senza indoli: nessun valore è al tetto, quindi una
	# spinta si vede sempre (su un gusto già pinzato non si muoverebbe niente
	# e il conto direbbe zero per il motivo sbagliato)
	var chiavi: Array = (DNA.generate(4242).get("weights", {}) as Dictionary).keys()
	var base := {"weights": {}, "indole": []}
	for k in chiavi:
		(base["weights"] as Dictionary)[str(k)] = 0.5
	var partenza: PackedFloat64Array = GUSTO.da_dna(base)

	var muovono := {}          # cosa -> {gene: true}
	for k in chiavi:
		var spinto := {"weights": (base["weights"] as Dictionary).duplicate(), "indole": []}
		(spinto["weights"] as Dictionary)[str(k)] = 1.5
		var dopo: PackedFloat64Array = GUSTO.da_dna(spinto)
		for i in dopo.size():
			if dopo[i] != partenza[i]:
				var cosa := str(GUSTO.COSE[i])
				var set: Dictionary = muovono.get(cosa, {})
				set[str(k)] = true
				muovono[cosa] = set

	for cosa in GUSTO.COSE:
		var attesi: int = (GUSTO.DA_PESO.get(str(cosa), []) as Array).size()
		var visti: int = (muovono.get(str(cosa), {}) as Dictionary).size()
		t.eq(visti, attesi,
				"«%s» si compone di %d geni DIVERSI, ed è quanti ne dichiara" % [cosa, attesi])

	# E QUALI. Il conto qui sopra prende una casa fatta di quattro tetti; non
	# prenderebbe due cose che si SCAMBIANO i geni — «il fiore nasce dal peso
	# del comfort, il cibo da quello del giardino» — perché i conti tornano
	# tutti. Quel legame non ha nessun'altra casa nel progetto da cui
	# derivarlo: è una frase in italiano («la casa È il tetto, i muri, la
	# porta e la finestra»), quindi si scrive una SECONDA STESURA del
	# contratto, a mano e apposta, esattamente come `COSA_ATTESA` fa per i
	# verbi del ponte. La differenza è che questa non si confronta con la
	# tabella: si verifica MUOVENDO il gene e guardando cosa si sposta.
	var geni_attesi := {
		"garden": "fiore", "comfort": "cibo",
		"roof": "casa", "walls": "casa", "door": "casa", "window": "casa",
		"warmth": "fuoco", "sunny": "pesce", "welcome": "amico",
	}
	for gene in geni_attesi:
		var cosa_attesa := str(geni_attesi[gene])
		var mosse: Array = []
		for cosa in muovono:
			if (muovono[cosa] as Dictionary).has(str(gene)):
				mosse.append(str(cosa))
		t.eq(mosse, [cosa_attesa],
				"muovere «%s» sposta il gusto per «%s», e nient'altro" % [gene, cosa_attesa])
	# …e nessun peso del genoma resta a muovere qualcosa senza essere
	# dichiarato qui: un gene che entra di soppiatto in una cosa è un pezzo di
	# carattere che nessuno ha deciso.
	for k in chiavi:
		if geni_attesi.has(str(k)):
			continue
		var tocca := false
		for cosa in muovono:
			if (muovono[cosa] as Dictionary).has(str(k)):
				tocca = true
		t.ok(not tocca, "il peso «%s» non entra in nessuna delle sei cose" % k)
	# E LE SEI COSE SONO SEI. Due cose che nascono dagli stessi identici geni
	# sarebbero una colonna sola con due nomi: il ponte ne riceverebbe sei,
	# il villaggio ne distinguerebbe cinque, e nessuno vedrebbe la differenza.
	var firme := {}
	for cosa in muovono:
		var geni: Array = (muovono[cosa] as Dictionary).keys()
		geni.sort()
		firme[str(geni)] = true
	t.eq(firme.size(), muovono.size(),
			"e nessuna coppia di cose nasce dagli stessi geni (%d firme per %d cose)"
					% [firme.size(), muovono.size()])


## IL GUSTO PORTA IL CARATTERE FIN QUI — e questa è la scena, non un numero.
##
## `Gusto.da_dna` è lo specchio: se non portasse l'indole, le tinte
## varierebbero comunque (i pesi del DNA sono già tutti diversi) e l'ablazione
## resterebbe verde — ma il villaggio perderebbe la cosa che si VEDE, cioè
## che a raccogliere il tuo gesto è l'ORDINATO. Perciò qui non si misura la
## varietà: si misura che chi ha un'indole della cura tenga ai fiori più
## degli altri, e che la differenza arrivi fino al modulatore.
##
## Le due distribuzioni si SOVRAPPONGONO, ed è giusto così: l'indole inclina,
## non decide (misurato: il più tiepido degli ordinati sta sotto il più caldo
## degli altri). Se un giorno non si sovrapponessero più, il carattere avrebbe
## smesso di essere una sfumatura e sarebbe diventato una casta.
func _il_gusto_porta_il_carattere(t, m) -> void:
	var g := _grafo([[0, 0, 1, 255, 0.0], [2, 0, 1, 255, 0.0]])
	var con := 0.0
	var nc := 0
	var senza := 0.0
	var ns := 0
	var min_con := 9.9
	var max_senza := -9.9
	var storte := 0
	for s in range(1000, 1400):
		var dna: Dictionary = DNA.generate(s)
		var gusto: PackedFloat64Array = GUSTO.da_dna(dna)
		if gusto.size() != GUSTO.COSE.size():
			storte += 1
		var d: Dictionary = m.debug_occ(g, gusto, 0.0, {})
		var v := float(d["mod"][AZ_CURA_GIARDINO])
		var ind: Array = dna.get("indole", [])
		if ind.has("ordinato") or ind.has("mattiniero"):
			con += v
			nc += 1
			min_con = minf(min_con, v)
		else:
			senza += v
			ns += 1
			max_senza = maxf(max_senza, v)
	t.eq(storte, 0, "ogni gusto ha una voce per cosa")
	t.ok(nc > 50 and ns > 50,
			"il campione ha abbastanza caratteri di tutti e due i tipi (%d/%d)" % [nc, ns])
	# misurato: 1.24292 contro 1.18660, scarto 0.056
	t.ok(con / nc - senza / ns > 0.03,
			"chi ha un'indole della cura raccoglie il gesto più degli altri (%.5f contro %.5f)"
			% [con / nc, senza / ns])
	t.ok(min_con < max_senza,
			"ma le due distribuzioni si sovrappongono: l'indole inclina, non decide")
	# lo specchio regge un genoma malmesso, come `da_salvataggio()` regge un
	# salvataggio andato storto: un vicino senza gusti è neutro, mai rotto
	var vuoto: PackedFloat64Array = GUSTO.da_dna({})
	t.eq(vuoto.size(), GUSTO.COSE.size(), "un genoma vuoto dà comunque sei gusti")
	for i in vuoto.size():
		t.ok(vuoto[i] == 1.0, "e sono tutti neutri (%d)" % i)
	var storto: PackedFloat64Array = GUSTO.da_dna(
			{"weights": {"garden": -5.0}, "indole": ["boh", 42]})
	for i in storto.size():
		t.ok(storto[i] >= 0.0, "e un genoma spazzatura non produce gusti negativi (%d)" % i)


## LA NEUTRALITÀ ESATTA. Vedi la nota 1 in cima al file: qui si confronta con
## `==` apposta, mai con una tolleranza.
func _il_grafo_vuoto_e_neutro(t, m) -> void:
	var d: Dictionary = m.debug_occ(PackedFloat64Array(), NEUTRO, 0.0, {})
	var mod: PackedFloat64Array = d["mod"]
	t.eq(mod.size(), 8, "un modulatore per azione")
	for a in mod.size():
		t.ok(mod[a] == 1.0, "senza ricordi il modulatore %d è 1.0 ESATTO (%.20f)" % [a, mod[a]])
	t.ok(float(d["ammirazione"]) == 0.0, "e non si ammira niente")
	t.ok(float(d["gratitudine"]) == 0.0, "e non si ringrazia nessuno")
	var inter: PackedFloat64Array = d["interesse"]
	for c in inter.size():
		t.ok(inter[c] == 0.0, "nessun interesse per la cosa %d" % c)
	# e resta neutro anche col gusto acceso al massimo e a qualunque ora: è il
	# grafo che manca, non il carattere
	var caldo := PackedFloat64Array([4.0, 4.0, 4.0, 4.0, 4.0, 4.0])
	var d2: Dictionary = m.debug_occ(PackedFloat64Array(), caldo, 900.0, {})
	var mod2: PackedFloat64Array = d2["mod"]
	for a in mod2.size():
		t.ok(mod2[a] == 1.0, "chi non ha visto niente non ha voglie nuove (%d)" % a)


## SE NE MUOVONO DUE, E SONO SEMPRE QUELLE DUE. `AZ_STELLA` è pinnata: il
## cielo notturno non è una faccenda di simpatie. Le altre cinque restano
## ferme perché la memoria INCLINA, non decide.
func _solo_due_si_muovono(t, m) -> void:
	# il grafo più pesante che si possa avere: ventiquattro ricordi freschi,
	# forti, di ogni specie, metà dei quali fatti per me
	var lista := []
	for i in 24:
		lista.append([i % 8, (_a_me if i % 2 == 0 else 0), 255, 255, 0.0])
	var caldo := PackedFloat64Array([4.0, 4.0, 4.0, 4.0, 4.0, 4.0])
	var d: Dictionary = m.debug_occ(_grafo(lista), caldo, 0.0, {})
	var mod: PackedFloat64Array = d["mod"]
	var mossi := []
	for a in mod.size():
		if mod[a] != 1.0:
			mossi.append(a)
	t.eq(mossi, [AZ_CHIACCHIERE, AZ_CURA_GIARDINO],
			"a tinte a fondo scala si muovono SOLO chiacchiere e giardino")
	t.ok(mod[AZ_STELLA] == 1.0, "e la stella resta 1.0 ESATTO anche a fondo scala")
	t.ok(mod[AZ_CHIACCHIERE] > 1.0 and mod[AZ_CHIACCHIERE] <= 1.5,
			"le chiacchiere salgono, ma dentro il +50%% (%.4f)" % mod[AZ_CHIACCHIERE])


## L'ABLAZIONE, a tre gradini — vedi la nota 2 in cima al file.
func _l_ablazione(t, m) -> void:
	# il caso TIPICO, non quello estremo: due ricordi, nessun regalo. Un
	# fixture che satura sarebbe una prova compiacente — a fondo scala si
	# assomigliano tutti, e una colonna morta passerebbe inosservata.
	var g := _grafo([[0, 0, 1, 255, 0.0], [2, 0, 1, 255, 0.0]])

	# GRADINO 1 — il gusto SPENTO. Non è una tautologia: se un domani
	# l'ammirazione smettesse di passare dal gusto (una somma dei pesi nudi,
	# che è la stesura più naturale che si possa sbagliare), qui le tinte
	# sarebbero > 0 e il modulatore delle chiacchiere si muoverebbe lo stesso.
	var spento: Dictionary = m.debug_occ(g, ZERO, 0.0, {})
	t.ok(float(spento["ammirazione"]) == 0.0, "col gusto spento non resta ammirazione")
	t.ok(float(spento["gratitudine"]) == 0.0, "né gratitudine")
	var mod0: PackedFloat64Array = spento["mod"]
	for a in mod0.size():
		t.ok(mod0[a] == 1.0, "e nessun modulatore si muove (%d)" % a)

	# GRADINO 2 — il gusto APPIATTITO: il sistema vive, ma è cieco a chi ha
	# davanti. È lo stato in cui `Animo.REAZIONI` è rimasta per mesi: acceso,
	# girante, con i suoi test verdi, e uguale per tutti. Il valore di questo
	# gradino sta nel CONFRONTO col terzo — stesso grafo, stessa ora, stessa
	# taratura, cambia solo il gusto: se il terzo varia e questo no, la
	# varietà viene da lì e da nient'altro.
	var piatto: Dictionary = m.debug_occ(g, NEUTRO, 0.0, {})
	t.ok(float(piatto["ammirazione"]) > 0.0, "col gusto appiattito le tinte ci sono ancora")
	t.ok(float(piatto["mod"][AZ_CURA_GIARDINO]) > 1.0, "e la voglia di giardino si muove")

	# GRADINO 3 — il gusto VERO, su quattrocento caratteri di ChibiDNA.
	var vettori := {}
	var per_chiacchiere := {}
	var per_giardino := {}
	for gusto in _caratteri:
		var d: Dictionary = m.debug_occ(g, gusto, 0.0, {})
		var mod: PackedFloat64Array = d["mod"]
		vettori[str(mod)] = true
		per_chiacchiere[str(mod[AZ_CHIACCHIERE])] = true
		per_giardino[str(mod[AZ_CURA_GIARDINO])] = true
	# misurato: 400/400 su tutti e tre i conteggi. La soglia a 398 lascia il
	# margine di una taratura futura del DNA, non quello di un canale morto.
	t.ok(vettori.size() >= 398,
			"COL GUSTO VERO, quattrocento caratteri danno %d vettori distinti" % vettori.size())
	t.ok(per_chiacchiere.size() >= 398,
			"e il canale delle chiacchiere ne distingue %d DA SOLO" % per_chiacchiere.size())
	t.ok(per_giardino.size() >= 398,
			"e quello del giardino %d" % per_giardino.size())


## NESSUNA TINTA NEGATIVA, MAI — otto verbi × quattrocento caratteri × le
## quattro combinazioni di bandiere. È la guardia della regola 4: senza
## contenuto negativo su una persona, la gogna non è tarata male, è
## impossibile. Se un giorno qualcuno aggiungesse un verbo con un segno, o un
## gusto che sottrae, questo test lo dice prima che arrivi a schermo.
func _nessuna_tinta_negativa(t, m) -> void:
	var grafi := []
	for v in VERBI.size():
		for b in [0, _sentito, _a_me, _sentito | _a_me | _detto]:
			grafi.append(_fresco(v, b))
	var guai := 0
	var sotto := 0
	for gusto in _caratteri:
		for g in grafi:
			var d: Dictionary = m.debug_occ(g, gusto, 12.0, {})
			if float(d["ammirazione"]) < 0.0 or float(d["gratitudine"]) < 0.0:
				guai += 1
			var inter: PackedFloat64Array = d["interesse"]
			for c in inter.size():
				if inter[c] < 0.0:
					guai += 1
			var mod: PackedFloat64Array = d["mod"]
			for a in mod.size():
				if mod[a] < 1.0:
					sotto += 1
	t.eq(guai, 0, "su %d letture (8 verbi × 400 caratteri × 4 bandiere) nessuna tinta è negativa"
			% (_caratteri.size() * grafi.size()))
	t.eq(sotto, 0, "e nessun modulatore scende sotto 1.0: la memoria non toglie mai voglia")


## LO SPECCHIO OSTILE. Il gusto arriva dal GDScript, cioè da fuori: se un
## giorno qualcuno ci spingesse dentro un numero negativo — per una divisione
## andata male, per una taratura «sperimentale» — il villaggio comincerebbe a
## guardare storto chi annaffia. Il segno non si tiene per disciplina, si
## tiene in codice.
func _lo_specchio_ostile(t, m) -> void:
	var cattivo := PackedFloat64Array([-3.0, -1.0, -0.5, -10.0, -0.0, -2.0])
	var d: Dictionary = m.debug_occ(_fresco(0), cattivo, 0.0, {})
	t.ok(float(d["ammirazione"]) == 0.0, "un gusto negativo vale zero, non meno di zero")
	var mod: PackedFloat64Array = d["mod"]
	for a in mod.size():
		t.ok(mod[a] == 1.0, "e nessun modulatore scende sotto la neutralità (%d)" % a)
	# e la stessa cosa per la manopola dell'ampiezza
	var d2: Dictionary = m.debug_occ(_fresco(0), NEUTRO, 0.0, {"k_ammirazione": -2.0})
	var mod2: PackedFloat64Array = d2["mod"]
	for a in mod2.size():
		t.ok(mod2[a] == 1.0, "né con un'ampiezza negativa (%d)" % a)


## UNA VOCE NON PESA PIÙ DI UN OCCHIO. Il rapporto è esattamente lo
## smorzamento, e nessuna taratura può capovolgerlo.
func _una_voce_non_pesa_piu_di_un_occhio(t, m) -> void:
	var visto: Dictionary = m.debug_occ(_fresco(0), NEUTRO, 0.0, {})
	var voce: Dictionary = m.debug_occ(_fresco(0, _sentito), NEUTRO, 0.0, {})
	t.almost(float(voce["ammirazione"]), float(visto["ammirazione"]) * 0.55,
			"un ricordo sentito pesa lo 0.55 di uno visto", 1e-15)
	# la manopola si muove davvero…
	var meta: Dictionary = m.debug_occ(_fresco(0, _sentito), NEUTRO, 0.0, {"peso_sentito": 0.25})
	t.almost(float(meta["ammirazione"]), float(visto["ammirazione"]) * 0.25,
			"e segue lo smorzamento che gli si passa", 1e-15)
	# …ma non oltre l'occhio: una voce che pesasse più del vederlo con i
	# propri occhi farebbe del pettegolezzo un megafono
	var assurdo: Dictionary = m.debug_occ(_fresco(0, _sentito), NEUTRO, 0.0, {"peso_sentito": 5.0})
	t.almost(float(assurdo["ammirazione"]), float(visto["ammirazione"]),
			"con uno smorzamento assurdo la voce arriva al massimo a pari", 1e-15)
	var negativo: Dictionary = m.debug_occ(_fresco(0, _sentito), NEUTRO, 0.0, {"peso_sentito": -1.0})
	t.ok(float(negativo["ammirazione"]) == 0.0, "e uno negativo la spegne, non la capovolge")
	# lo smorzamento è dello STRUMENTO, non del contenuto: sentito o visto, la
	# cosa di cui si parla resta la stessa
	var i_fiore := int(GUSTO.COSE.find("fiore"))
	t.ok(float(voce["interesse"][i_fiore]) > 0.0,
			"una voce racconta comunque DI CHE COSA si parlava")


## IL REGALO. Pesa il doppio (glielo dà `peso()`), e la sua parte si vede
## isolata nella gratitudine — che è una fetta dell'ammirazione, non un
## secondo conto.
func _il_regalo_pesa_e_ringrazia(t, m) -> void:
	var normale: Dictionary = m.debug_occ(_fresco(7), NEUTRO, 0.0, {})
	var regalo: Dictionary = m.debug_occ(_fresco(7, _a_me), NEUTRO, 0.0, {})
	t.ok(float(normale["gratitudine"]) == 0.0,
			"un gesto che non era per me non produce gratitudine")
	t.almost(float(regalo["ammirazione"]), float(normale["ammirazione"]) * 2.0,
			"un gesto fatto per me pesa il doppio", 1e-15)
	t.almost(float(regalo["gratitudine"]), float(regalo["ammirazione"]),
			"e con un ricordo solo la gratitudine è tutta l'ammirazione", 1e-15)
	# e la gratitudine conta DOPPIO nelle chiacchiere: è la scena del piatto
	# regalato che torna indietro attraverso una nuvoletta
	t.ok(float(regalo["mod"][AZ_CHIACCHIERE]) > float(normale["mod"][AZ_CHIACCHIERE]),
			"chi ha ricevuto qualcosa ha più voglia di raccontarlo")
	# la gratitudine però NON è un'altra voglia di giardino: le due tinte
	# muovono due canali diversi, e un regalo non fa venir voglia di annaffiare
	var reg_fiore: Dictionary = m.debug_occ(_fresco(0, _a_me), NEUTRO, 0.0, {})
	var vis_fiore: Dictionary = m.debug_occ(_fresco(0), NEUTRO, 0.0, {})
	t.ok(float(reg_fiore["mod"][AZ_CURA_GIARDINO]) > float(vis_fiore["mod"][AZ_CURA_GIARDINO]),
			"un'annaffiata fatta per me lascia più traccia di una qualunque")


## LA GRATITUDINE VALE IL DOPPIO NELLE CHIACCHIERE — e il DOPPIO si misura,
## non si legge.
##
## `modulatori()` compone la voglia di raccontare con `ammirazione + 2·
## gratitudine`: non è «ti voglio più bene», è che chi ha ricevuto qualcosa
## ha una cosa da raccontare, e quella cosa pesa più di una qualunque che ha
## solo visto. Portare quel coefficiente da 2.0 a 1.0 lasciava la suite
## VERDE: il caso che sembrava coprirlo (`_il_regalo_pesa_e_ringrazia`)
## verifica che la gratitudine ESISTA e che muova le chiacchiere più di un
## gesto qualunque — cosa che resta vera anche con 1.0, perché il regalo pesa
## già il doppio per conto suo (`peso()`, R_SU_DI_ME).
##
## LA MISURA NON RICOPIA LA FORMULA: si conta in GESTI VISTI. Un dono fatto a
## me vale 2 di ammirazione e 2 di gratitudine, cioè 2 + 2·2 = SEI gesti
## visti; col coefficiente a 1.0 ne varrebbe quattro. Bastano quindi tre
## letture e nessuna aritmetica di là.
func _la_gratitudine_vale_il_doppio_nelle_chiacchiere(t, m) -> void:
	var dono := _fresco(7, _a_me)
	var d_dono: Dictionary = m.debug_occ(dono, NEUTRO, 0.0, {})
	# PREMESSA: il dono vale due gesti di ammirazione, ed è tutta gratitudine
	var visto: Dictionary = m.debug_occ(_fresco(7), NEUTRO, 0.0, {})
	var u := float(visto["ammirazione"])
	t.ok(u > 0.0, "un gesto visto vale qualcosa (%.6f)" % u)
	t.almost(float(d_dono["ammirazione"]), u * 2.0, "un dono a me ne vale due", 1e-15)
	t.almost(float(d_dono["gratitudine"]), u * 2.0, "…e sono tutti gratitudine", 1e-15)

	var quanti := func(n: int) -> float:
		var lista := []
		for _i in n:
			lista.append([7, 0, 1, 255, 0.0])
		var d: Dictionary = m.debug_occ(_grafo(lista), NEUTRO, 0.0, {})
		return float(d["mod"][AZ_CHIACCHIERE])

	var mio := float(d_dono["mod"][AZ_CHIACCHIERE])
	t.almost(mio, quanti.call(6),
			"da raccontare, UN dono fatto a me vale SEI gesti visti", 1e-15)
	# …e non quattro, che è quanto varrebbe col coefficiente a 1.0. Senza
	# questa riga la precedente non distinguerebbe le due tarature: la prova
	# sta proprio nel non combaciare con l'altro numero.
	t.ok(absf(mio - quanti.call(4)) > 1e-9,
			"e NON quattro: la gratitudine entra col suo doppio (%.9f contro %.9f)"
					% [mio, quanti.call(4)])
	# la stessa cosa detta da fuori: due gesti visti e uno ricevuto pesano
	# uguale sull'ammirazione, ma non uguale sulla voglia di raccontarlo
	var due_visti: Dictionary = m.debug_occ(
			_grafo([[7, 0, 1, 255, 0.0], [7, 0, 1, 255, 0.0]]), NEUTRO, 0.0, {})
	t.almost(float(due_visti["ammirazione"]), float(d_dono["ammirazione"]),
			"due gesti visti pesano quanto un dono ricevuto (stessa ammirazione)", 1e-15)
	t.ok(mio > float(due_visti["mod"][AZ_CHIACCHIERE]),
			"…ma il dono si racconta di più (%.6f contro %.6f)"
					% [mio, float(due_visti["mod"][AZ_CHIACCHIERE])])


## IL TEMPO PASSA IN LETTURA, e passa di mezze vite. Nel dato non c'è nessun
## intero che decade: un `int16 × 0.999994` torna a sé stesso, e il grafo
## diventerebbe eterno con la suite verde.
func _il_tempo_passa_in_lettura(t, m) -> void:
	var g := _fresco(0)
	var adesso: Dictionary = m.debug_occ(g, NEUTRO, 0.0, {})
	var mezza: Dictionary = m.debug_occ(g, NEUTRO, 120.0, {})
	var due: Dictionary = m.debug_occ(g, NEUTRO, 240.0, {})
	var otto: Dictionary = m.debug_occ(g, NEUTRO, 960.0, {})
	t.almost(float(mezza["ammirazione"]), float(adesso["ammirazione"]) * 0.5,
			"dopo una mezza vita un ricordo pesa la metà", 1e-15)
	t.almost(float(due["ammirazione"]), float(adesso["ammirazione"]) * 0.25,
			"dopo due, un quarto", 1e-15)
	t.ok(float(otto["ammirazione"]) < 0.01,
			"e dopo otto non tinge quasi più niente (%.5f)" % otto["ammirazione"])
	t.ok(float(otto["mod"][AZ_CURA_GIARDINO]) < 1.01,
			"tanto che la voglia è tornata quasi a com'era")
	# la mezza vita è una manopola vera: un villaggio con le giornate lunghe
	# ha ricordi lunghi, e la si DERIVA dal ciclo del giorno, non si riscrive
	var lenta: Dictionary = m.debug_occ(g, NEUTRO, 120.0, {"mezza_vita": 240.0})
	t.ok(float(lenta["ammirazione"]) > float(mezza["ammirazione"]),
			"con le giornate lunghe lo stesso ricordo pesa di più")


## L'INTERESSE È DI UNA COSA SOLA. Il giardino lo muovono i FIORI: se lo
## muovesse l'ammirazione in blocco, la scena 4 (Mochi torna all'orto e trova
## il proprio gesto rifatto da un altro) diventerebbe «un vicino annaffia
## perché ti ha visto pescare», che non significa niente.
func _l_interesse_e_di_una_cosa_sola(t, m) -> void:
	var i_fiore := int(GUSTO.COSE.find("fiore"))
	var i_pesce := int(GUSTO.COSE.find("pesce"))
	var pesca: Dictionary = m.debug_occ(_fresco(5), NEUTRO, 0.0, {})
	var inter: PackedFloat64Array = pesca["interesse"]
	t.ok(inter[i_pesce] > 0.0, "aver visto pescare accende l'interesse per il pesce")
	t.ok(inter[i_fiore] == 0.0, "e non tocca quello per i fiori")
	t.ok(float(pesca["mod"][AZ_CURA_GIARDINO]) == 1.0,
			"quindi la voglia di giardino resta 1.0 ESATTO")
	t.ok(float(pesca["mod"][AZ_CHIACCHIERE]) > 1.0,
			"mentre da raccontare c'è comunque qualcosa")
	var annaffia: Dictionary = m.debug_occ(_fresco(0), NEUTRO, 0.0, {})
	t.ok(float(annaffia["mod"][AZ_CURA_GIARDINO]) > 1.0,
			"averti vista annaffiare, invece, la voglia di giardino la muove")
	# annaffiare e seminare parlano dello stesso fiore: sono otto verbi e sei
	# cose apposta — quel che resta in mente è DI CHE COSA ti stavi occupando
	var semina: Dictionary = m.debug_occ(_fresco(1), NEUTRO, 0.0, {})
	t.almost(float(semina["mod"][AZ_CURA_GIARDINO]), float(annaffia["mod"][AZ_CURA_GIARDINO]),
			"seminare e annaffiare lasciano la stessa traccia", 1e-15)
	# e il gusto sposta SOLO la sua colonna: chi ama i fiori non diventa per
	# questo un tipo con più voglia di parlare di pesca
	var solo_fiori := PackedFloat64Array([3.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var p2: Dictionary = m.debug_occ(_fresco(5), solo_fiori, 0.0, {})
	t.ok(float(p2["ammirazione"]) == 0.0,
			"a chi importa solo dei fiori, averti vista pescare non dice niente")


## LA SATURAZIONE FRENA. Il ventesimo gesto conta meno del secondo: senza,
## «fatti guardare mentre annaffi in cerchio» diventerebbe un modo di
## caricare i vicini, cioè il gesto gentile diventerebbe una moneta.
func _la_saturazione_frena(t, m) -> void:
	var v := []
	for n in [1, 2, 3, 6, 12, 24]:
		var lista := []
		for i in n:
			lista.append([0, 0, 1, 255, 0.0])
		var d: Dictionary = m.debug_occ(_grafo(lista), NEUTRO, 0.0, {})
		v.append(float(d["mod"][AZ_CURA_GIARDINO]))
	for i in range(1, v.size()):
		t.ok(v[i] > v[i - 1], "più ricordi, più voglia (%d)" % i)
	# il secondo ricordo vale più del doppio dell'ultimo raddoppio:
	# misurato, +0.0833 contro +0.0330
	var primo: float = v[1] - v[0]
	var ultimo: float = v[5] - v[4]
	t.ok(primo > ultimo * 2.0,
			"il secondo ricordo vale più del doppio dell'ultimo raddoppio (%.4f vs %.4f)"
			% [primo, ultimo])
	t.ok(v[5] < 1.5, "e ventiquattro ricordi non arrivano MAI al +50%% (%.5f)" % v[5])
	# «quante» è la stessa storia: sei aiuole annaffiate in un gesto solo non
	# valgono sei volte una
	var una: Dictionary = m.debug_occ(_grafo([[0, 0, 1, 255, 0.0]]), NEUTRO, 0.0, {})
	var sei: Dictionary = m.debug_occ(_grafo([[0, 0, 6, 255, 0.0]]), NEUTRO, 0.0, {})
	t.ok(float(sei["ammirazione"]) > float(una["ammirazione"]),
			"sei aiuole pesano più di una")
	t.ok(float(sei["ammirazione"]) < float(una["ammirazione"]) * 6.0,
			"ma molto meno di sei volte tanto")


## L'AMMIRAZIONE È UNA RIDUZIONE, non un terzo accumulatore: è la somma
## esatta delle sei, e si confronta con `==`. Se un giorno la si sommasse per
## conto suo dentro il ciclo, nascerebbe la seconda verità sullo stesso
## numero — e sarebbe «quasi uguale», cioè invisibile a una tolleranza.
func _l_ammirazione_e_la_somma(t, m) -> void:
	var lista := []
	for i in 24:
		lista.append([i % 8, (_a_me if i % 3 == 0 else 0), 1 + i, 40 + i * 9, -float(i) * 7.0])
	var gusto := PackedFloat64Array([0.3, 1.7, 0.9, 2.4, 0.15, 3.1])
	var d: Dictionary = m.debug_occ(_grafo(lista), gusto, 300.0, {})
	var inter: PackedFloat64Array = d["interesse"]
	var somma := 0.0
	for c in inter.size():
		somma += inter[c]
	t.ok(float(d["ammirazione"]) == somma,
			"l'ammirazione è la somma ESATTA delle sei tinte (%.20f vs %.20f)"
			% [d["ammirazione"], somma])
	t.ok(float(d["gratitudine"]) > 0.0 and float(d["gratitudine"]) < float(d["ammirazione"]),
			"e la gratitudine è una fetta di quella somma, non un secondo conto")


## NIENTE FUORI SCALA. Diecimila combinazioni di grafi e caratteri a caso —
## tempi dal futuro compresi — e nessun modulatore esce da [1.0, 1.5].
## Misurato: il massimo raggiunto è 1.49973.
func _niente_fuori_scala(t, m) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260811
	var lo := 9.9
	var hi := -9.9
	var storti := 0
	for it in 10000:
		var n := rng.randi_range(0, 24)
		var lista := []
		for i in n:
			lista.append([rng.randi_range(0, 7), rng.randi_range(0, 7),
					rng.randi_range(0, 255), rng.randi_range(0, 255),
					rng.randf_range(-600.0, 600.0)])
		var gusto := PackedFloat64Array()
		gusto.resize(6)
		for i in 6:
			gusto[i] = rng.randf_range(0.0, 4.0)
		var d: Dictionary = m.debug_occ(_grafo(lista), gusto, rng.randf_range(0.0, 600.0), {})
		var mod: PackedFloat64Array = d["mod"]
		for a in mod.size():
			lo = minf(lo, mod[a])
			hi = maxf(hi, mod[a])
			if is_nan(mod[a]):
				storti += 1
		if is_nan(float(d["ammirazione"])) or float(d["ammirazione"]) < 0.0:
			storti += 1
	t.eq(storti, 0, "su diecimila letture a caso nessun NaN e nessuna tinta negativa")
	t.ok(lo == 1.0, "il pavimento resta 1.0 ESATTO (%.20f)" % lo)
	t.ok(hi <= 1.5, "e il soffitto non supera mai il +50%% (%.10f)" % hi)


## LE TARATURE ASSURDE NON PRODUCONO NaN. Un NaN in un modulatore non fa
## fallire niente: fa fallire ogni CONFRONTO, quindi l'argmax dell'agenda
## sceglierebbe sempre la stessa azione e nessuno saprebbe perché.
func _le_tarature_assurde(t, m) -> void:
	var g := _grafo([[0, 0, 12, 255, 0.0], [7, _a_me, 3, 255, 0.0]])
	var casi := [
		{"k_satura": 0.0},
		{"k_satura": -5.0},
		{"mezza_vita": 0.0},
		{"mezza_vita": -1.0},
		{"k_ammirazione": 0.0},
		{"k_satura": 0.0, "mezza_vita": 0.0, "peso_sentito": 0.0, "k_ammirazione": 0.0},
	]
	for caso in casi:
		var d: Dictionary = m.debug_occ(g, NEUTRO, 60.0, caso)
		t.ok(not is_nan(float(d["ammirazione"])), "niente NaN nell'ammirazione con %s" % str(caso))
		var mod: PackedFloat64Array = d["mod"]
		for a in mod.size():
			t.ok(not is_nan(mod[a]) and mod[a] >= 1.0 and mod[a] <= 1.5,
					"e il modulatore %d resta in scala con %s (%s)" % [a, str(caso), str(mod[a])])
	# un ricordo spento e un ricordo dal futuro: due degradi che il mondo può
	# davvero produrre (un'intensità azzerata, un orologio riavvolto)
	var spento: Dictionary = m.debug_occ(_grafo([[0, 0, 0, 0, 0.0]]), NEUTRO, 0.0, {})
	t.ok(float(spento["ammirazione"]) == 0.0, "un ricordo a intensità zero non tinge niente")
	var futuro: Dictionary = m.debug_occ(_grafo([[0, 0, 1, 255, 900.0]]), NEUTRO, 0.0, {})
	var oggi: Dictionary = m.debug_occ(_fresco(0), NEUTRO, 0.0, {})
	t.almost(float(futuro["ammirazione"]), float(oggi["ammirazione"]),
			"e uno dal futuro vale come uno di adesso, non di più", 1e-15)
	# UN RICORDO GUASTO NON NE GUASTA ALTRI CINQUE. Un `quando` corrotto manda
	# un NaN dentro l'esponenziale, e un NaN sommato a una tinta la rende NaN
	# per sempre: da lì in poi ogni confronto sui punteggi di quel vicino
	# sarebbe falso e nessuno vedrebbe un errore. Il ricordo malato si salta,
	# gli altri restano.
	var malato: Dictionary = m.debug_occ(
			_grafo([[0, 0, 1, 255, NAN], [0, 0, 1, 255, 0.0]]), NEUTRO, 0.0, {})
	t.ok(not is_nan(float(malato["ammirazione"])),
			"un ricordo col tempo corrotto non manda in NaN tutte le tinte")
	t.almost(float(malato["ammirazione"]), float(oggi["ammirazione"]),
			"e quello sano accanto continua a valere quanto vale", 1e-15)
	var mod_malato: PackedFloat64Array = malato["mod"]
	for a in mod_malato.size():
		t.ok(not is_nan(mod_malato[a]) and mod_malato[a] >= 1.0 and mod_malato[a] <= 1.5,
				"e i modulatori restano numeri in scala (%d)" % a)


## DETERMINISTICO: nessun dado, nessuno stato nascosto, nessuna dipendenza
## dall'ordine delle chiamate. Due letture identiche sono lo stesso double.
func _e_deterministico(t, m) -> void:
	var g := _grafo([[3, 0, 2, 200, -30.0], [6, _sentito, 1, 90, -5.0], [7, _a_me, 4, 255, -70.0]])
	var gusto := PackedFloat64Array([1.3, 0.7, 2.2, 0.0, 1.9, 0.4])
	var a: Dictionary = m.debug_occ(g, gusto, 55.0, {})
	# in mezzo si chiede tutt'altro: se restasse uno stato appeso, si vedrebbe
	m.debug_occ(_fresco(0), NEUTRO, 999.0, {"k_satura": 0.01})
	var b: Dictionary = m.debug_occ(g, gusto, 55.0, {})
	t.ok(float(a["ammirazione"]) == float(b["ammirazione"]), "la stessa lettura dà lo stesso double")
	t.ok(str(a["mod"]) == str(b["mod"]), "e gli stessi otto modulatori")
	t.ok(str(a["interesse"]) == str(b["interesse"]), "e le stesse sei tinte")
