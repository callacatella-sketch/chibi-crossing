extends RefCounted
## L'INSIEME — la nozione che l'utility AI non aveva.
##
## Ventotto vicini risolvevano ventotto argmax separati: la co-presenza era
## una COINCIDENZA, le coincidenze sono rare, e le triadi non nascevano
## (misurato: 22 giornate, sei coppie che si ritrovano, **zero cricche**).
## Qui entra la meta' che mancava — un fatto del mondo, e un fattore che lo
## legge.
##
## ⚠️ **E LA PRIMA COSA MISURATA E' STATA CHE NON POTEVA FUNZIONARE.** Nel
## villaggio com'era, tre giornate di gioco: il fatto acceso **0 volte su
## 169.286 campioni**, su zero residenti — perche' una seduta in panchina
## durava **0,01 s** (nove sedute, il 100% sotto il secondo). Non c'era
## nessuna finestra dentro cui un secondo potesse arrivare. Con la sosta:
## p50 **16,20 s**, e il fatto si accende **1501 volte su 169.260** (0,89%),
## su due residenti. Il termine senza la sosta sarebbe stato codice morto in
## partita con la suite verde — il guasto che questo progetto ha gia' pagato
## tre volte.
##
## ============================================================
## COSA CERCA DI ROMPERE, QUESTO FILE
## ============================================================
##
## 1. **CHE IL TERMINE NON SIA NEUTRO QUANDO NON C'E' NESSUNO.** E' la
##    condizione su cui poggia la prova di equivalenza bit-esatta
##    dell'agenda (67.200 confronti) — ma quella prova **e' CIECA a questo
##    fattore per costruzione**: la sua spazzata accende solo i sei fatti
##    storici, quindi il bit 13 non puo' mai accendersi e resterebbe verde
##    anche se il fattore fosse sbagliato in ogni altro modo. La sua
##    neutralita' va quindi provata da un caso NOMINATO, ed e'
##    `_neutro_quando_non_c_e_nessuno`.
##
## 2. **CHE APRA LA CORSIA D'URGENZA DI NASCOSTO.** Un fattore di TABELLA
##    non passa da `DELTA_MAX` (quel tetto pinza `p_mod`, cioe' l'emozione):
##    la sua rete e' un `static_assert` in `sistema_agenda.h`, e qui c'e' la
##    stessa relazione a runtime, coi numeri letti **dal binario** e mai
##    riscritti di qua. L'insieme INCLINA, non accelera.
##
## 3. **CHE IL FATTO DIVENTI UN'INTENZIONE.** «Chi e' SEDUTO adesso», mai
##    «chi sta arrivando»: due intenzioni che si aspettano a vicenda sono lo
##    stallo (nessuno va per primo, il fatto non e' mai vero, la funzione e'
##    codice morto in partita con la suite verde).
##
## 4. **CHE DIVENTI UN REQUISITO.** Uno stanco e SOLO deve poter fare un
##    pisolino sempre. Il bit in `richiede` sarebbe l'esclusione scritta nel
##    motore — e per giunta farebbe crollare i 67.200 confronti in blocco.
##
## 5. **CHE IL PUNTEGGIO E IL CORPO GUARDINO DUE POSTI DIVERSI.** E' la
##    regola dell'aiuola detta sulla panchina: il fatto si deriva dal posto
##    che `_panchina_per` HA SCELTO, non da una domanda sua. Con due domande
##    separate i due numeri sarebbero entrambi giusti, ognuno per conto suo,
##    e il vicino andrebbe a sedersi da solo per una ragione che non esiste.
##
## 6. **CHE TREMI.** I corpi si muovono a sessanta hertz, e un termine
##    continuo reinietterebbe il rumore che il dado congelato ha tolto (in
##    Fase 2: da 0,2 a 922 cambi d'idea al minuto). Il fatto vive dentro il
##    rinfresco dei fatti, cioe' **a gradini** — la stessa disciplina di
##    `PASSO_EMO`. MISURATO nel villaggio vero, tre giornate di gioco con i
##    tredici residenti del salvataggio (`tools/misura_insieme.gd`): **0,09
##    cambi al minuto** per residente contro **1,64 cambi d'azione** — cioe'
##    diciotto volte piu' fermo della decisione che alimenta. Il booleano
##    NUDO («un vicino entro tre metri»), che e' la forma sbagliata della
##    stessa idea, ne fa **3,79**: piu' del DOPPIO della decisione.
##
## ============================================================
## IL BANCO — corpi VERI, usciere VERO
## ============================================================
## La stessa forma di `test_cricche_corpo`: il `Visitors` del gioco col solo
## `_ready` scavalcato, i `Visitor` col rig di `ChibiBuilder`, e un
## `EcsMondo` vero. Di finto c'e' il MONDO — il BuildSystem che dice dove
## sono i pezzi e l'orologio — perche' sono DATI, non comportamenti: un
## doppio che ri-implementasse `_free_bench` o `_accanto_a_qualcuno`
## lascerebbe la funzione vera senza nessun lettore, ed e' la lezione del
## `Corpo` di `test_deduzioni` (una valvola che si poteva sostituire con una
## costante in TUTTE E DUE le direzioni, con 63.942 asserzioni verdi).

const VISITOR := preload("res://scenes/npc/Visitor.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")
const ORACOLO := preload("res://tests/oracolo_agenda.gd")

const CARATTERI := [
	[], ["goloso"], ["dormiglione"], ["chiacchierone"], ["timido"],
	["sognatore"], ["ordinato"], ["chiacchierone", "timido"],
	["sognatore", "dormiglione"],
]
const LIVELLI := [0.0, 0.17, 0.5, 0.83, 1.0]
## I sei fatti STORICI, quelli che l'oracolo congelato conosce. Non si
## allarga: l'oracolo e' la copia del passato, e il passato questo fattore
## non ce l'aveva.
const FATTI_STORICI := ["mattina", "sera_stellata", "aiuola_da_annaffiare",
		"spuntino_vicino", "amico_in_giro", "regia"]


func run(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non e' caricata")
		return
	var m = ClassDB.instantiate("EcsMondo")
	# --- il TERMINE
	_il_nome_accende_il_suo_bit(t, m)
	_neutro_quando_non_c_e_nessuno(t, m)
	_inclina_del_suo_K(t, m)
	_il_tetto_non_apre_l_urgenza(t, m)
	_tocca_solo_il_riposo(t, m)
	_uno_stanco_e_solo_riposa_lo_stesso(t, m)
	m.free()
	# --- il FATTO
	_conta_chi_e_seduto_non_chi_arriva(t)
	_il_proprio_posto_non_e_compagnia(t)
	_accanto_vuol_dire_accanto(t)
	_mochi_seduta_e_un_corpo_seduto(t)
	_il_fatto_esce_dal_POSTO_SCELTO(t)
	_la_sosta_dura_quanto_la_posa(t)
	_il_lease_della_sosta_esiste_davvero(t)
	_e_un_gradino_non_un_filo(t)
	_la_sosta_non_sfonda_il_registro(t)
	_la_sosta_e_incondizionata(t)
	# --- il DOVE
	_il_filtro_puo_solo_togliere(t)
	_lo_spareggio_non_allunga_il_guinzaglio(t)
	_ci_si_siede_accanto_non_in_fondo(t)
	_il_filtro_rispetta_la_prenotazione(t)
	_la_compagnia_piu_vicina_prima(t)
	_un_seduto_non_fa_compagnia_a_se_stesso(t)
	_chi_e_in_scena_non_fa_compagnia(t)
	_il_letto_non_e_una_seduta(t)
	_il_fatto_segue_l_ancora_SPOSTATA(t)
	_accanto_e_il_piu_vicino_non_il_primo(t)
	_mochi_resta_il_primo_anello(t)
	_il_tetto_del_lease_sta_sopra_la_posa(t)


# ======================================================================
#  IL TERMINE
# ======================================================================

## Il nome che il GDScript produce accende un bit, ed e' solo suo.
##
## Una stringa scritta storta non fallisce: **smette di accendere il bit**, e
## il termine diventa codice morto in partita con la suite verde.
func _il_nome_accende_il_suo_bit(t, m) -> void:
	var bit: int = m.maschera_fatti(PackedStringArray([VISITORS.FATTO_INSIEME]))
	t.ok(bit != 0, "«%s» accende un bit anche per il C++" % VISITORS.FATTO_INSIEME)
	# UN SOLO BIT, non due: il fatto e' un BOOLEANO, non un conteggio. «C'e'
	# qualcuno» e «ce ne sono cinque» devono valere lo stesso, o un posto che
	# si riempie diventa piu' forte invece che PIENO — cioe' preferential
	# attachment, cioe' il villaggio-grumo in poche giornate.
	var acc := 0
	for i in 32:
		if bit & (1 << i):
			acc += 1
	t.eq(acc, 1, "e ne accende UNO SOLO (il fatto e' un booleano, mai un conteggio)")
	for altro in FATTI_STORICI + ["meraviglia_posto", "regia_pronta",
			"spuntino_raggiungibile", "aiuola_raggiungibile",
			"seduta_libera_vicina", "meraviglia_raggiungibile", "lavagna_pronta"]:
		t.eq(m.maschera_fatti(PackedStringArray([str(altro)])) & bit, 0,
				"e non e' il bit di «%s»" % altro)


## LA NEUTRALITA', E SI PROVA INVECE DI DICHIARARLA.
##
## Col bit spento i punteggi devono essere gli STESSI DOUBLE dell'oracolo
## congelato — non «circa»: `x * 1.0` e' lo stesso double bit per bit, ed e'
## esattamente su questo che poggia la prova di equivalenza dell'agenda.
##
## ⚠️ Questo caso esiste perche' quella prova **non puo' vedere questo
## fattore**: la sua spazzata accende solo i sei fatti storici, quindi il bit
## 13 e' sempre spento e resterebbe verde anche se il fattore moltiplicasse
## per zero quando e' acceso. Una prova cieca per costruzione non e' la
## guardia di cio' a cui e' cieca.
func _neutro_quando_non_c_e_nessuno(t, m) -> void:
	var confronti := 0
	var divergenze := 0
	var peggiore := ""
	for c in CARATTERI:
		var ind: int = m.maschera_indole(PackedStringArray(c))
		for combo in 8:
			var nomi: Array = []
			var ctx := {}
			for k in 3:
				if combo & (1 << k):
					nomi.append(FATTI_STORICI[k])
					ctx[FATTI_STORICI[k]] = true
			var f: int = m.maschera_fatti(PackedStringArray(nomi))
			for e in LIVELLI:
				for p in LIVELLI:
					var needs := {"pancino": p, "energia": e, "compagnia": 0.4,
							"meraviglia": 0.6, "cura": 0.3}
					var b := PackedFloat64Array([p, e, 0.4, 0.6, 0.3])
					var vivi: PackedFloat64Array = m.debug_punteggi(b, f, ind, -1)
					var atteso: Dictionary = ORACOLO.punteggi(needs, ctx, c, "")
					confronti += 1
					if vivi[1] != float(atteso["riposo"]):
						divergenze += 1
						peggiore = "riposo %.17g contro %.17g (energia %.2f)" \
								% [vivi[1], float(atteso["riposo"]), e]
	t.eq(divergenze, 0,
			("col bit spento il riposo e' lo STESSO DOUBLE di prima del fattore, "
			+ "su %d contesti (%s)") % [confronti, peggiore if peggiore != "" else "nessuna divergenza"])


## E QUANDO C'E' QUALCUNO, INCLINA DEL SUO K — e di nient'altro.
##
## Il confronto e' con `==`, non con `almost`: l'associazione e' la stessa
## da tutte e due le parti (`v * K`), quindi il risultato e' bit-esatto. Un
## `almost` qui lascerebbe passare un fattore applicato nel posto sbagliato
## della catena — per esempio dopo il pavimento — che sposta il numero di un
## nulla nel caso comune e di tutto nel caso raro.
##
## K si legge DAL BINARIO. Riscritto di qua sarebbe una tabella gemella: il
## giorno che qualcuno lo tara, questo caso resterebbe verde raccontando una
## taratura che non esiste piu'.
func _inclina_del_suo_K(t, m) -> void:
	var cost: Dictionary = m.debug_costanti_agenda()
	t.ok(cost.has("k_insieme"), "il C++ dice qual e' il suo K (%s)" % str(cost.get("k_insieme")))
	var k := float(cost["k_insieme"])
	t.ok(k > 1.0, "e inclina verso il posto abitato, non contro (K = %.4f)" % k)
	var bit: int = m.maschera_fatti(PackedStringArray([VISITORS.FATTO_INSIEME]))
	var esatti := 0
	var storti := 0
	for c in CARATTERI:
		var ind: int = m.maschera_indole(PackedStringArray(c))
		for e in LIVELLI:
			var b := PackedFloat64Array([0.5, e, 0.4, 0.6, 0.3])
			var senza: PackedFloat64Array = m.debug_punteggi(b, 0, ind, -1)
			var con: PackedFloat64Array = m.debug_punteggi(b, bit, ind, -1)
			if con[1] == senza[1] * k:
				esatti += 1
			else:
				storti += 1
	t.eq(storti, 0,
			"il riposo vale ESATTAMENTE il suo K in piu' (%d contesti bit-esatti)" % esatti)


## IL TETTO, a runtime, coi numeri letti dal binario.
##
## `sistema_agenda.h` ha un `static_assert` che non fa partire la build se
## qualcuno alza K o il peso del riposo. Qui c'e' la stessa relazione detta
## in un altro modo, e serve per una ragione precisa: il `static_assert`
## legge le COSTANTI, questo legge il PUNTEGGIO — cioe' prende anche il
## giorno in cui il massimo del riposo cambia per una strada che quelle tre
## costanti non descrivono (una curva diversa, un pavimento, un compensation
## factor acceso).
##
## `max(riposo)` si MISURA — energia a zero, dormiglione — invece di
## ricopiare 2.24: un tetto derivato dalla costante che sorveglia non
## sorveglia niente (la lezione di `PASSO_EMO` in `test_ritmo_emozioni`).
func _il_tetto_non_apre_l_urgenza(t, m) -> void:
	var cost: Dictionary = m.debug_costanti_agenda()
	var k := float(cost["k_insieme"])
	var margine := float(cost["margine"])
	var i_dorm: int = m.maschera_indole(PackedStringArray(["dormiglione"]))
	var massimo := 0.0
	for c in CARATTERI:
		var ind: int = m.maschera_indole(PackedStringArray(c))
		var p: PackedFloat64Array = m.debug_punteggi(
				PackedFloat64Array([1.0, 0.0, 1.0, 1.0, 1.0]), 0, ind, -1)
		massimo = maxf(massimo, p[1])
	t.ok(massimo > 0.0, "il riposo puo' valere qualcosa (max misurato %.4f)" % massimo)
	t.ok(massimo * (k - 1.0) < margine,
			("lo scarto piu' grande che l'insieme puo' produrre (%.4f) sta sotto il "
			+ "margine d'urgenza (%.4f): INCLINA, non accelera") % [massimo * (k - 1.0), margine])
	# ⚠️ **E LO SCARTO SI MISURA, non si ricostruisce dal K DICHIARATO.** La
	# riga qui sopra moltiplica per `k` letto da `debug_costanti_agenda`,
	# cioe' per la COSTANTE — non per il numero che sta davvero nella riga
	# della tabella. MISURATO: mettendo `f_fatto(F_INSIEME, 1.35, 1.0)` con
	# `K_INSIEME` ancora a 1.20 la corsia d'urgenza si apre sul serio
	# (2.24 × 0.35 = 0.784 contro un margine di 0.60), e questo caso restava
	# VERDE — e con lui il `static_assert`, che legge la costante uguale.
	# Qui si chiedono al binario i due punteggi, col bit e senza, e la
	# differenza e' quella vera: un letterale storto nella riga non ha piu'
	# dove nascondersi.
	var scarto := 0.0
	for c2 in CARATTERI:
		var ind2: int = m.maschera_indole(PackedStringArray(c2))
		var b2 := PackedFloat64Array([1.0, 0.0, 1.0, 1.0, 1.0])
		var con: PackedFloat64Array = m.debug_punteggi(b2, m.maschera_fatti(
				PackedStringArray([VISITORS.FATTO_INSIEME])), ind2, -1)
		var senza: PackedFloat64Array = m.debug_punteggi(b2, 0, ind2, -1)
		scarto = maxf(scarto, con[1] - senza[1])
	t.ok(scarto > 0.0, "il termine sposta davvero il punteggio (%.4f)" % scarto)
	t.ok(scarto < margine,
			("lo scarto MISURATO dal binario (%.4f) sta sotto il margine (%.4f) — "
			+ "e questo non passa dal K dichiarato") % [scarto, margine])
	# e il massimo lo fa il dormiglione, che e' chi il fattore moltiplica di piu'
	var p_dorm: PackedFloat64Array = m.debug_punteggi(
			PackedFloat64Array([1.0, 0.0, 1.0, 1.0, 1.0]), 0, i_dorm, -1)
	t.almost(p_dorm[1], massimo,
			"e il caso peggiore e' il dormiglione a energia zero", 1e-12)


## IL FATTORE TOCCA UNA RIGA SOLA DELLA TABELLA.
##
## Se finisse anche su «quattro_chiacchiere» o su «spuntino», il termine
## smetterebbe di essere una nozione di insieme e diventerebbe una
## CONCENTRAZIONE: tutto quello che si fa lo si farebbe dove c'e' gia'
## qualcuno, e il villaggio si ammucchierebbe da solo.
func _tocca_solo_il_riposo(t, m) -> void:
	var bit: int = m.maschera_fatti(PackedStringArray([VISITORS.FATTO_INSIEME]))
	var mossi := {}
	for c in CARATTERI:
		var ind: int = m.maschera_indole(PackedStringArray(c))
		for combo in 8:
			var nomi: Array = []
			for k in 3:
				if combo & (1 << k):
					nomi.append(FATTI_STORICI[k])
			# il mondo pieno: cibo, amico, posto bello e regia, cosi' nessuna
			# azione e' infattibile per caso e ognuna ha un numero da muovere
			nomi.append_array(["spuntino_vicino", "amico_in_giro",
					"meraviglia_posto", "regia", "regia_pronta"])
			var f: int = m.maschera_fatti(PackedStringArray(nomi))
			for e in LIVELLI:
				var b := PackedFloat64Array([0.3, e, 0.35, 0.45, 0.25])
				var senza: PackedFloat64Array = m.debug_punteggi(b, f, ind, -1)
				var con: PackedFloat64Array = m.debug_punteggi(b, f | bit, ind, -1)
				for i in 8:
					if senza[i] != con[i]:
						mossi[i] = int(mossi.get(i, 0)) + 1
	t.ok(mossi.has(1), "il fattore muove il riposo (%d volte)" % int(mossi.get(1, 0)))
	mossi.erase(1)
	t.eq(mossi.size(), 0,
			"e NESSUN'ALTRA azione: un termine su «chiacchiere» o «spuntino» sarebbe una concentrazione, non un insieme (mosse: %s)"
					% str(mossi))


## UNO STANCO E SOLO RIPOSA LO STESSO — la regola dell'esclusione, scritta
## dove non si puo' dimenticare.
##
## Il bit **non e' in `richiede`**, e le due ragioni sono indipendenti: chi
## non ha nessuno accanto deve poter fare un pisolino sempre, e nella
## spazzata dell'equivalenza il bit e' sempre spento (quindi `riposo`
## varrebbe zero dappertutto e i 67.200 confronti crollerebbero insieme).
## Qui si guarda la prima, che e' quella che il giocatore vedrebbe.
func _uno_stanco_e_solo_riposa_lo_stesso(t, m) -> void:
	# nessun fatto acceso: nessun cibo, nessun amico, nessun posto bello, e
	# soprattutto NESSUNO ACCANTO. Tutti i bisogni pieni tranne l'energia.
	var b := PackedFloat64Array([1.0, 0.0, 1.0, 1.0, 1.0])
	for c in CARATTERI:
		var ind: int = m.maschera_indole(PackedStringArray(c))
		var p: PackedFloat64Array = m.debug_punteggi(b, 0, ind, -1)
		var best := 0
		for i in 8:
			if p[i] > p[best]:
				best = i
		t.eq(best, 1,
				"stanco e solo, «%s» vuole comunque riposare (riposo %.3f)"
						% ["nessun tratto" if c.is_empty() else ",".join(c), p[1]])
		t.ok(p[1] > 0.0, "e il riposo non e' spento dalla solitudine (%.3f)" % p[1])


# ======================================================================
#  IL FATTO
# ======================================================================

class FintoGiorno extends Node3D:
	var day := 3
	var time := 0.5
	## `_ensure_ecs` lo legge per derivare il ritmo della memoria: senza,
	## l'accesso esplode e la funzione si INTERROMPE a meta' — cioe' il
	## registro resta senza ritmo e nessuna asserzione lo dice.
	var cycle_seconds := 240.0


## Il registro dei vicini VERO, col solo `_ready` scavalcato: il suo vuole
## `%Player` e `../BuildSystem`, cioe' il villaggio intero.
class Registro extends "res://scenes/npc/Visitors.gd":
	## Quanto quel vicino ti ammira. E' un DATO — lo produce l'ECS a partire
	## dal grafo dei ricordi — e qui lo si detta, come `FintoBuild` detta
	## dove sono i pezzi: `ancora_riposo` e l'ordine dei quattro anelli
	## restano quelli veri, ed e' quello che si sta provando.
	var finta_ammirazione := 0.0

	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		add_to_group("visitors")

	func _ammirazione_di(_r: Dictionary) -> float:
		return finta_ammirazione


## IL MONDO, non il comportamento. Dice DOVE sono i pezzi e se ci si arriva,
## che sono DATI; non decide niente, e soprattutto non ri-implementa nulla di
## quel che si sta provando (`_free_bench`, `_accanto_a_qualcuno` e
## `_panchina_per` restano quelli del gioco).
## ⚠️ `Node3D` e non `Node`: `Visitors._build` e' TIPIZZATO, e un `set()` con
## il tipo sbagliato **non assegna e non dice niente** — il campo resta
## `null` e ogni chiamata al mondo esplode a runtime, cioe' interrompe il
## caso lasciando la suite verde.
class FintoBuild extends Node3D:
	var pezzi := {}   # nome -> Array[Node3D]

	func get_placed_by_name(nome: String) -> Array:
		return pezzi.get(nome, [])

	func raggiungibile(_a: Vector2i, _b: Vector2i) -> bool:
		return true


## Un finto pannello delle interazioni: dice solo su cosa e' seduta Mochi.
class FintaInterazione extends Node:
	var seduta: Node3D = null

	func sedile_attuale() -> Node3D:
		return seduta


func _corpo(t, seme := 4242) -> Node3D:
	var v = VISITOR.new()
	v.species = "chibi"
	v.mode = "resident"
	v.dna = DNA.generate(seme)
	t.stage(v)
	v.set_process(false)
	return v


## Una panchina finta: un `Node3D` con un posto. Non serve il pezzo vero —
## quello che `_accanto_a_qualcuno` guarda e' la POSIZIONE di un nodo.
func _seduta(dove: Vector3, casa: Node) -> Node3D:
	var s := Node3D.new()
	casa.add_child(s)
	s.global_position = dove
	return s


func _villaggio(t, quanti := 2) -> Dictionary:
	for vecchio in t.tree().get_nodes_in_group("visitors"):
		(vecchio as Node).remove_from_group("visitors")
	for vecchio2 in t.tree().get_nodes_in_group("interactions"):
		(vecchio2 as Node).remove_from_group("interactions")
	var casa := Node3D.new()
	casa.name = "Villaggio"
	t.stage(casa)
	var giorno := FintoGiorno.new()
	giorno.name = "DayNight"
	casa.add_child(giorno)
	var vis = Registro.new()
	vis.name = "Visitors"
	casa.add_child(vis)
	var build = FintoBuild.new()
	build.name = "BuildSystem"
	casa.add_child(build)
	vis.set("_build", build)
	vis.set("_daynight", giorno)
	var inter = FintaInterazione.new()
	inter.name = "Interactions"
	casa.add_child(inter)
	inter.add_to_group("interactions")
	var corpi: Array = []
	for i in quanti:
		var c := _corpo(t, 4242 + i * 97)
		c.global_position = Vector3(float(i) * 30.0, 0, 0)
		c.dna["name"] = "Vicino%d" % i
		vis._residents.append({"node": c, "label": "V%d" % i, "dna": c.dna,
				"cell": Vector2i(i * 30, 0), "species": "chibi",
				"next_act": 0.0, "phase": "day"})
		corpi.append(c)
	return {"casa": casa, "vis": vis, "build": build, "inter": inter,
			"corpi": corpi}


## Mette il corpo nello stato di seduta su quel posto, come lo mette il gioco.
func _siedi(corpo: Node3D, posto: Node3D, dove: Vector3) -> void:
	corpo.set("_routine_aux", posto)
	corpo.set("_state", "r_bench")
	corpo.global_position = dove


## ⚠️ **SEDUTO ADESSO, MAI IN ARRIVO.**
##
## La mutazione INGENUA — togliere il controllo dello stato — e' un accesso
## a un campo che non c'e', cioe' un errore a runtime: **non fa fallire un
## test, lo INTERROMPE** lasciando la suite verde. Quella plausibile e'
## «accetta anche chi sta camminando verso il posto», ed e' anche quella che
## uno scriverebbe in buona fede pensando di anticipare l'incontro. Con
## quella il fatto smette di essere una proprieta' del mondo e diventa
## un'intenzione: due che si aspettano a vicenda non partono mai.
func _conta_chi_e_seduto_non_chi_arriva(t) -> void:
	var v := _villaggio(t, 2)
	var casa: Node = v["casa"]
	var vis = v["vis"]
	var corpi: Array = v["corpi"]
	var mio := _seduta(Vector3(0, 0, 0), casa)
	var suo := _seduta(Vector3(1.0, 0, 0), casa)

	# 1) l'altro CAMMINA verso il posto accanto, ed e' gia' li' col corpo
	(corpi[1] as Node3D).set("_routine_aux", suo)
	(corpi[1] as Node3D).set("_state", "walk")
	(corpi[1] as Node3D).global_position = Vector3(1.0, 0, 0)
	t.ok(not vis._accanto_a_qualcuno(mio),
			"chi sta ARRIVANDO non fa compagnia: il fatto e' del mondo, non un'intenzione")

	# 2) lo stesso corpo, nello stesso punto, SEDUTO
	_siedi(corpi[1] as Node3D, suo, Vector3(1.0, 0, 0))
	t.ok(vis._accanto_a_qualcuno(mio),
			"…e appena si siede, il posto accanto chiama")

	# 3) e la controprova: se si alza, smette
	(corpi[1] as Node3D).set("_state", "r_idle")
	t.ok(not vis._accanto_a_qualcuno(mio),
			"e quando si alza smette di chiamare (senza questa riga il fatto resterebbe acceso per sempre)")


## IL PROPRIO POSTO NON E' COMPAGNIA.
##
## Senza questa riga un vicino seduto si darebbe la compagnia da solo — il
## suo stesso posto lo chiamerebbe — e resterebbe incollato li'.
func _il_proprio_posto_non_e_compagnia(t) -> void:
	var v := _villaggio(t, 1)
	var casa: Node = v["casa"]
	var vis = v["vis"]
	var corpi: Array = v["corpi"]
	var posto := _seduta(Vector3(0, 0, 0), casa)
	_siedi(corpi[0] as Node3D, posto, Vector3(0, 0, 0))
	t.ok(not vis._accanto_a_qualcuno(posto),
			"chi ha gia' prenotato quel posto e' se stesso visto da un'altra parte")


## ACCANTO VUOL DIRE ACCANTO, e la soglia non e' giudicata contro se' stessa.
##
## I due numeri di prova non sono `VICINI`: sono la larghezza di un Gazebo
## (i tre sgabelli stanno a 0,92-1,01 m: due che ci si siedono SONO insieme)
## e la larghezza di un capannello (tre metri: due persone distinte, ed e'
## la scala a cui si guarda il grumo). Cosi' portare `VICINI` a cento metri
## fa arrossire, invece di spostare anche il metro.
func _accanto_vuol_dire_accanto(t) -> void:
	var v := _villaggio(t, 2)
	var casa: Node = v["casa"]
	var vis = v["vis"]
	var corpi: Array = v["corpi"]
	var mio := _seduta(Vector3(0, 0, 0), casa)
	var suo := _seduta(Vector3(0.95, 0, 0), casa)
	_siedi(corpi[1] as Node3D, suo, Vector3(0.95, 0, 0))
	t.ok(vis._accanto_a_qualcuno(mio),
			"a 0,95 m — due sgabelli del Gazebo — si e' accanto")
	(corpi[1] as Node3D).global_position = Vector3(3.0, 0, 0)
	t.ok(not vis._accanto_a_qualcuno(mio),
			"a tre metri no: quella e' la scala del capannello, non della panchina")


## MOCHI SEDUTA E' UN CORPO SEDUTO COME GLI ALTRI.
##
## E' l'unica chiave a forma di GIOCATORE che questo sistema abbia: ti siedi
## su uno sgabello del Gazebo e i due accanto cominciano a chiamare. Non e'
## gatata sull'ammirazione apposta — farlo escluderebbe dalla vita sociale
## nuova proprio chi non si e' ancora fatto ammirare.
func _mochi_seduta_e_un_corpo_seduto(t) -> void:
	var v := _villaggio(t, 1)
	var casa: Node = v["casa"]
	var vis = v["vis"]
	var inter = v["inter"]
	var mio := _seduta(Vector3(0, 0, 0), casa)
	var suo := _seduta(Vector3(0.95, 0, 0), casa)
	t.ok(not vis._accanto_a_qualcuno(mio), "con Mochi in piedi, il posto tace")
	inter.seduta = suo
	t.ok(vis._accanto_a_qualcuno(mio),
			"e appena si siede accanto, il posto chiama (la chiave a forma di giocatore)")
	# …e il posto su cui e' seduta LEI non fa compagnia a se stesso
	t.ok(not vis._accanto_a_qualcuno(suo),
			"ma il posto di Mochi non chiama se stesso")
	# …e `_free_bench` non ci manda nessuno addosso
	var build = v["build"]
	build.pezzi["Panchina"] = [mio, suo]
	var scelta = vis._free_bench(Vector3(0.9, 0, 0))
	t.ok(scelta == mio,
			"e nessun vicino si siede DENTRO Mochi: il suo posto e' occupato")


## ⚠️ **IL PUNTEGGIO E IL CORPO GUARDANO LO STESSO POSTO.**
##
## Il fatto si deriva dal posto che `_panchina_per` HA SCELTO, dentro
## `_luoghi_del_piano` — non da una domanda sua. La mutazione plausibile e'
## proprio quella che sembra piu' naturale scrivere: «c'e' qualcuno seduto
## vicino a casa mia?». Con quella, un vicino che ha qualcuno seduto in
## fondo al giardino ma la cui panchina piu' vicina sta dall'altra parte
## andrebbe a sedersi DA SOLO col termine acceso — due numeri entrambi
## giusti, ognuno per conto suo, e nessun modo di accorgersene.
func _il_fatto_esce_dal_POSTO_SCELTO(t) -> void:
	var v := _villaggio(t, 2)
	var casa: Node = v["casa"]
	var vis = v["vis"]
	var build = v["build"]
	var corpi: Array = v["corpi"]
	# casa mia e' l'origine. La panchina PIU' VICINA e' a due metri; l'altra
	# coppia di panchine sta FUORI DAL RAGGIO, ed e' li' che qualcuno e'
	# seduto.
	#
	# ⚠️ Le due lontane stavano a quindici metri, cioe' DENTRO i sedici del
	# raggio, e da quando esiste il filtro quella e' una scena diversa: il
	# corpo ci andrebbe davvero, perche' fra i posti che avrebbe usato
	# comunque quello ha compagnia. Giusto cosi' — ma allora il caso non
	# sorvegliava piu' la sua invariante (il fatto viene dal posto SCELTO),
	# la sorvegliava per caso. Portandole a venticinque metri la compagnia
	# torna a essere irraggiungibile, e l'invariante si vede di nuovo da sola.
	var vicina := _seduta(Vector3(2.0, 0, 0), casa)
	var lontana := _seduta(Vector3(25.0, 0, 0), casa)
	var lontana2 := _seduta(Vector3(25.9, 0, 0), casa)
	build.pezzi["Panchina"] = [vicina, lontana, lontana2]
	_siedi(corpi[1] as Node3D, lontana2, Vector3(25.9, 0, 0))
	var r: Dictionary = vis._residents[0]
	var home := Vector3(0, 0, 0)
	r["cell"] = Vector2i(0, 0)

	var scelta = vis._panchina_per(r, home)
	t.ok(scelta == vicina, "il corpo andrebbe alla panchina vicina")
	vis._luoghi_del_piano(r, home)
	t.ok(not bool(r.get(VISITORS.FATTO_INSIEME, true)),
			"e allora il fatto e' SPENTO: la compagnia sta su un posto in cui non andra'")

	# adesso l'occupato e' proprio accanto a quella che sceglierebbe
	(corpi[1] as Node3D).set("_routine_aux", lontana)
	(corpi[1] as Node3D).global_position = Vector3(2.9, 0, 0)
	vis._luoghi_del_piano(r, home)
	t.ok(bool(r.get(VISITORS.FATTO_INSIEME, false)),
			"e quando l'occupato e' accanto AL POSTO SCELTO, il fatto si accende")


## LA SOSTA DURA QUANTO LA POSA — e prima durava trenta millisecondi.
##
## Il corpo si e' sempre dato 14-22 secondi (`Visitor._enter_state`), e si
## rialzava nel fotogramma dopo: il gesto pagava la sazieta' all'arrivo,
## `r_bench` sta fra gli stati a riposo (lucchetto APERTO), energia 1.0 vuol
## dire riposo a zero, e qualunque altra cosa vinceva. Senza una sosta vera
## non esiste nessuna finestra dentro cui un secondo possa arrivare, e tutto
## il resto di questo file e' codice morto in partita.
##
## Il numero non si ricopia di qua: `resta_in_posa()` lo chiede al corpo.
func _la_sosta_dura_quanto_la_posa(t) -> void:
	var c := _corpo(t, 9191)
	c.global_position = Vector3.ZERO
	c._enter_state("r_bench")
	var quanto: float = c.resta_in_posa()
	t.ok(quanto >= 14.0 and quanto <= 22.0,
			"una seduta spontanea dura fra 14 e 22 secondi (%.2f)" % quanto)
	# e il corpo la consuma davvero
	for _i in 60:
		c._process(1.0 / 60.0)
	t.ok(c.resta_in_posa() < quanto - 0.9,
			"e il tempo scorre: dopo un secondo ne resta uno di meno (%.2f)" % c.resta_in_posa())
	# e quando la posa e' finita non resta niente da aspettare: e' il conto
	# alla rovescia dello stato in cui si e', e a zero il corpo si alza
	c._timer = 0.0
	t.almost(c.resta_in_posa(), 0.0,
			"a posa finita non resta niente da aspettare", 0.001)
	c._timer = -3.0
	t.almost(c.resta_in_posa(), 0.0,
			"e non va mai sotto zero: un lease negativo sarebbe un'agenda zittita al contrario", 0.001)


## ⚠️ **E NON SFONDA IL REGISTRO DELLE CRICCHE.**
##
## `_segna_incontro` ha un quarto cancello: sopra `LEASE_SPONTANEO` legge
## «ce l'hanno MESSO li'» e SMETTE di registrare. Da quando una sosta si
## allunga il lease da sola, quel cancello e' la cosa che la sosta puo'
## rompere **senza un errore**: si formerebbero cricche che il registro non
## vede mai, con la suite verde. La mutazione plausibile e' allungare la
## sosta (che e' una cosa che uno fa per una ragione di resa, senza pensare
## al registro), e il `minf` e' cio' che la rende innocua.
func _la_sosta_non_sfonda_il_registro(t) -> void:
	var c := _corpo(t, 3131)
	# una posa lunga come quella di un concerto: 48 secondi
	c.do_routine("bench", Vector3.ZERO, Vector3.ZERO, null, 48.0)
	c._enter_state("r_bench")
	t.ok(c.resta_in_posa() > VISITORS.LEASE_SPONTANEO,
			"un corpo puo' avere una posa piu' lunga del tetto (%.1f s)" % c.resta_in_posa())
	var lease: float = minf(c.resta_in_posa(), VISITORS.LEASE_SPONTANEO)
	t.ok(lease <= VISITORS.LEASE_SPONTANEO,
			"ma il lease che la sosta si da' resta sotto il tetto (%.1f s)" % lease)
	# il tetto e' quello che `_segna_incontro` legge: le due meta' non
	# possono divergere, ed e' questo che rende il numero una fonte unica
	var sorgente := FileAccess.get_file_as_string("res://scenes/npc/Visitors.gd")
	t.ok(sorgente.count("LEASE_SPONTANEO") >= 3,
			"e lo leggono tutti e due (la sosta e i due cancelli di `_segna_incontro`)")


## LA SOSTA E' INCONDIZIONATA — chi e' solo si siede come tutti.
##
## Nessun ramo di questo sistema si accende sul VUOTO: ogni condizione e' un
## fatto positivo («quel posto ha qualcuno accanto»). Una sosta che durasse
## solo in compagnia sarebbe l'esclusione scritta nel motore, e il solitario
## si leggerebbe come rifiutato invece che come uno che sta bene da solo.
func _la_sosta_e_incondizionata(t) -> void:
	var c := _corpo(t, 5757)
	c.global_position = Vector3(0, 0, 0)
	c._enter_state("r_bench")
	var da_solo: float = c.resta_in_posa()
	t.ok(da_solo >= 14.0,
			"da solo, in mezzo al prato, ci si siede lo stesso (%.2f s)" % da_solo)
	# ⚠️ **E IL LEASE SI SCRIVE CON IL FATTO SPENTO.** L'asserzione qui sopra
	# duplica `_la_sosta_dura_quanto_la_posa` e non ha nessun rapporto con la
	# compagnia: il nome del caso e cio' su cui puo' fallire non coincidevano.
	# Questa invece e' la proprieta' NOMINATA — una sosta che durasse solo in
	# compagnia sarebbe l'esclusione scritta nel motore — e si prova sul
	# villaggio, col registro vero e nessuno seduto nei paraggi.
	var v := _villaggio(t, 1)
	var vis = v["vis"]
	var casa: Node = v["casa"]
	var build = v["build"]
	var panca := _seduta(Vector3(2, 0, 0), casa)
	build.pezzi["Panchina"] = [panca]
	var solo: Node3D = v["corpi"][0]
	solo.global_position = Vector3(0, 0, 0)
	vis._ensure_ecs()
	var r0: Dictionary = vis._residents[0]
	r0["cell"] = Vector2i(0, 0)
	vis._ecs_id(r0)
	vis._ensure_brain(r0)
	vis._luoghi_del_piano(r0, Vector3(0, 0, 0))
	t.ok(not bool(r0.get(VISITORS.FATTO_INSIEME, true)),
			"PREMESSA: non c'e' nessuno seduto, quindi il fatto e' SPENTO")
	solo.set("_routine_aux", panca)
	solo._enter_state("r_bench")
	var posa: float = solo.resta_in_posa()
	r0["saziato"] = false
	r0["next_act"] = 0.0
	vis._gesti_agenda()
	t.almost(float(r0.get("next_act", 0.0)), minf(posa, VISITORS.LEASE_SPONTANEO),
			("e il lease si scrive lo stesso, col fatto SPENTO: la sosta non "
			+ "chiede compagnia (%.2f s)") % posa, 0.001)
	# e nel sorgente non esiste nessuna funzione che chieda «chi e' solo»:
	# niente partizione, quindi niente complemento
	for f in ["scenes/npc/Visitors.gd", "scenes/npc/Visitor.gd"]:
		var s := FileAccess.get_file_as_string("res://" + f)
		for vietata in ["func _chi_e_solo", "func _e_solo", "func _solitari",
				"func _senza_nessuno", "giorni_da_solo"]:
			t.ok(not s.contains(str(vietata)),
					"«%s» non esiste in %s: non c'e' nessuna lista di chi sta da solo"
							% [vietata, f])


## ⚠️ **IL LEASE DELLA SOSTA ESISTE DAVVERO**, e non e' un commento.
##
## `resta_in_posa()` dice quanto dura la posa; questo caso guarda l'altra
## meta', cioe' che qualcuno lo CHIEDA. Togliere la riga dal latch di
## `_gesti_agenda` non produce nessun errore: produce un villaggio in cui
## nessuno resta seduto, e tutte le altre asserzioni di questo file
## resterebbero verdi — il fatto sarebbe giusto e non si accenderebbe mai.
##
## E il lease **si legge dal corpo**: si pretende che stia dentro la
## finestra che il corpo si e' dato, non un numero scritto qui.
func _il_lease_della_sosta_esiste_davvero(t) -> void:
	var v := _villaggio(t, 1)
	var casa: Node = v["casa"]
	var vis = v["vis"]
	var corpi: Array = v["corpi"]
	vis._ensure_ecs()
	var posto := _seduta(Vector3(0, 0, 0), casa)
	var c := corpi[0] as Node3D
	var r: Dictionary = vis._residents[0]
	vis._ecs_id(r)
	var brain: RefCounted = vis._ensure_brain(r)
	brain.needs["energia"] = 0.1

	# 1) IN PIEDI: nessun lease, e nessuna sazieta'
	c.set("_state", "r_idle")
	r["saziato"] = false
	r["next_act"] = 0.0
	vis._gesti_agenda()
	t.almost(float(r["next_act"]), 0.0,
			"in piedi non si allunga nessun guinzaglio", 0.001)
	t.almost(float(brain.needs["energia"]), 0.1,
			"e non ci si riposa stando in piedi", 0.001)

	# 2) SEDUTO: la sosta si scrive il suo lease, e vale quanto la posa
	c.set("_routine_aux", posto)
	c._enter_state("r_bench")
	var posa: float = c.resta_in_posa()
	r["saziato"] = false
	r["next_act"] = 0.0
	vis._gesti_agenda()
	t.almost(float(r["next_act"]), minf(posa, VISITORS.LEASE_SPONTANEO),
			("seduto, l'agenda aspetta esattamente quanto dura la posa "
			+ "(%.2f s) — non un numero scritto altrove") % posa, 0.001)
	t.ok(float(r["next_act"]) > 1.0,
			"cioe' molto piu' del fotogramma che durava prima (%.2f s)" % float(r["next_act"]))
	t.almost(float(brain.needs["energia"]), 1.0,
			"e il riposo si paga all'arrivo, come prima", 0.001)

	# 3) e il lease si puo' solo ALZARE: un sistema a evento non si scavalca
	r["saziato"] = false
	r["next_act"] = 9999.0
	vis._gesti_agenda()
	t.almost(float(r["next_act"]), 9999.0,
			"e un lease piu' lungo (il concerto, il congedo) non viene abbassato", 0.001)

	# 4) ⚠️ E IL TETTO MORDE. Una posa lunga — il pianista del concerto,
	#    quarantotto secondi — non deve poter portare il lease sopra
	#    `LEASE_SPONTANEO`: sopra quello `_segna_incontro` smette di
	#    registrare, IN SILENZIO, e si formerebbero cricche che il registro
	#    non vede mai. Questa e' la riga che il `minf` esiste per tenere, ed
	#    e' anche l'unica che diventa rossa togliendolo.
	c.set("_routine_aux", null)
	c.do_routine("bench", Vector3.ZERO, Vector3.ZERO, null, 48.0)
	c._enter_state("r_bench")
	t.almost(c.resta_in_posa(), 48.0, "la posa imposta dura quarantotto secondi", 0.01)
	r["saziato"] = false
	r["next_act"] = 0.0
	vis._gesti_agenda()
	t.almost(float(r["next_act"]), VISITORS.LEASE_SPONTANEO,
			("ma il lease che la sosta si da' si ferma al tetto (%.1f s invece di 48): "
			+ "sopra quello il registro delle cricche smette di guardare")
					% VISITORS.LEASE_SPONTANEO, 0.001)


## ⚠️ **E' UN GRADINO, NON UN FILO** — la garanzia che il termine non tremi.
##
## I corpi si muovono a sessanta hertz. Se il fatto li seguisse, il
## punteggio del riposo cambierebbe a ogni fotogramma e reinietterebbe
## esattamente il rumore che il dado congelato ha tolto (misurato in Fase 2:
## da 0,2 a 922 cambi d'idea al minuto). Non tremare non e' una proprieta'
## del fattore: e' una proprieta' di DOVE vive il fatto — dentro il
## rinfresco dei fatti, che e' a gradini di `FATTI_OGNI` fotogrammi. E' la
## stessa disciplina di `PASSO_EMO` per il modulatore emotivo.
##
## Qui il mondo cambia SOTTO a ogni chiamata (uno si siede e si alza in
## continuazione) e si conta quante volte la maschera che arriva al C++ se
## ne accorge. La mutazione plausibile — togliere la cache, o calcolare il
## fatto fuori da `_fatti_di` — porterebbe questo numero a novanta.
##
## Le DUE soglie non sono ridondanti: il tetto prende «segue i corpi», il
## pavimento prende «congelato per sempre» — che passerebbe il tetto a
## occhi chiusi e sarebbe altrettanto rotto, perche' il fatto smetterebbe
## di dire qualcosa sul mondo.
func _e_un_gradino_non_un_filo(t) -> void:
	var v := _villaggio(t, 2)
	var casa: Node = v["casa"]
	var vis = v["vis"]
	var build = v["build"]
	var corpi: Array = v["corpi"]
	vis._ensure_ecs()
	var mio := _seduta(Vector3(0, 0, 0), casa)
	var suo := _seduta(Vector3(0.95, 0, 0), casa)
	build.pezzi["Panchina"] = [mio, suo]
	var r: Dictionary = vis._residents[0]
	r["cell"] = Vector2i(0, 0)
	(corpi[0] as Node3D).global_position = Vector3.ZERO
	vis._ecs_id(r)

	var giri := 90
	var cambi := 0
	var prec := -12345
	var acceso := 0
	for i in giri:
		# il mondo si muove sotto: uno si siede e si alza a ogni fotogramma
		if i % 2 == 0:
			_siedi(corpi[1] as Node3D, suo, Vector3(0.95, 0, 0))
		else:
			(corpi[1] as Node3D).set("_state", "r_idle")
		var m: int = vis._fatti_di(r, corpi[0] as Node3D)
		if m != prec:
			cambi += 1
			prec = m
		if bool(r.get(VISITORS.FATTO_INSIEME, false)):
			acceso += 1
	var tetto := int(float(giri) / float(VISITORS.FATTI_OGNI)) + 2
	t.ok(cambi <= tetto,
			("con un mondo che cambia a ogni fotogramma, la maschera che arriva al C++ "
			+ "cambia %d volte su %d — non piu' di %d (un gradino ogni %d fotogrammi)")
					% [cambi, giri, tetto, VISITORS.FATTI_OGNI])
	t.ok(cambi >= 2,
			("…ma il mondo conta ancora: un fatto congelato per sempre passerebbe "
			+ "il tetto a occhi chiusi (%d cambi)") % cambi)
	t.ok(acceso > 0 and acceso < giri,
			"e il fatto si e' davvero acceso e spento (%d fotogrammi su %d)" % [acceso, giri])
	# ⚠️ **RESIDUO DICHIARATO: questo caso sorveglia il CODICE del gradino,
	# non la sua COSTANTE.** Il tetto qui sopra si muove insieme a
	# `FATTI_OGNI`, quindi portandola a 1 — cioe' facendo seguire al fatto i
	# corpi a sessanta hertz, che e' il guasto che il caso esiste per
	# impedire — la suite resta verde di qua.
	#
	# Ci ho provato a metterci un tetto ASSOLUTO, e non funziona: MISURATO,
	# i cambi sono **3 con il gradino a 30 e 2 con il gradino a 1**. Il
	# mondo qui alterna a ogni fotogramma, cioe' con periodo due, e la
	# cadenza del rinfresco ci si ALLINEA: a ogni rinfresco il mondo si
	# trova sempre nella stessa fase, e il fatto risulta costante in tutte e
	# due le tarature. Un numero assoluto scritto qui sopra sembrerebbe una
	# guardia e sarebbe un'altra asserzione che non sa fallire — cioe'
	# esattamente la cosa che questo file esiste per non avere.
	#
	# La costante e' sorvegliata altrove, e davvero: `test_cuore_vicini`
	# tiene lo SFALSAMENTO (due asserzioni rosse a `FATTI_OGNI = 1`), che e'
	# la proprieta' per cui quel numero e' stato scelto. Chi vorra' chiudere
	# anche il tremolio da qui deve prima togliere l'allineamento — un mondo
	# che cambia con un periodo che non divide il gradino — e MISURARE che i
	# due numeri si separino, invece di sperarlo.


# ======================================================================
#  IL DOVE — si RIORDINA, mai si AGGIUNGE
# ======================================================================

## IL FILTRO PUO' SOLO TOGLIERE, e quando toglie tutto si ripiega.
##
## `_free_bench(from, true)` non e' una ricerca nuova: e' la stessa, con un
## `continue` in piu'. E `_seduta_da` e' lo spareggio: se la compagnia non
## c'e', si prende il posto che si sarebbe preso comunque — **mai niente**.
## La mutazione plausibile e' proprio quella che uno scriverebbe pensando di
## semplificare: `_seduta_da` che restituisce direttamente il filtrato. Con
## quella, un vicino che non ha nessuno seduto in giro — cioe' il caso
## COMUNE, e per definizione chi e' solo — smette di trovare una panchina e
## si addormenta per terra. L'invito diventerebbe una tassa sulla solitudine.
func _il_filtro_puo_solo_togliere(t) -> void:
	var v := _villaggio(t, 1)
	var casa: Node = v["casa"]
	var vis = v["vis"]
	var build = v["build"]
	var sola := _seduta(Vector3(2, 0, 0), casa)
	var occupata := _seduta(Vector3(6, 0, 0), casa)
	var accanto := _seduta(Vector3(6.95, 0, 0), casa)
	build.pezzi["Panchina"] = [sola, occupata, accanto]

	# nessuno seduto da nessuna parte: il filtro non trova NIENTE...
	var niente = vis._free_bench(Vector3.ZERO, true)
	t.ok(niente == null, "senza nessuno seduto, il filtro non trova niente")
	# ...ma lo spareggio si ripiega su quella che si sarebbe presa comunque
	var ripiego = vis._seduta_da(Vector3.ZERO)
	t.ok(ripiego == sola,
			"e chi e' solo si siede lo stesso, sulla piu' vicina (mai per terra)")

	# adesso qualcuno si siede
	_siedi(v["corpi"][0], occupata, Vector3(6, 0, 0))
	var trovata = vis._free_bench(Vector3.ZERO, true)
	t.ok(trovata == accanto, "col filtro si va dove c'e' compagnia")
	var senza = vis._free_bench(Vector3.ZERO)
	t.ok(senza == sola, "e senza filtro si va sulla piu' vicina, come sempre")
	# ⚠️ e lo spareggio preferisce la compagnia FRA I CANDIDATI DI PRIMA:
	# la piu' vicina esisteva ed e' stata scartata, non e' stata ignorata
	t.ok(vis._seduta_da(Vector3.ZERO) == accanto,
			"lo spareggio sceglie la compagnia fra i posti che c'erano gia'")


## ⚠️ **ZERO RAGGIO NUOVO: si RIORDINA, mai si AGGIUNGE.**
##
## E' la regola su cui poggia tutto il resto — la ragione strutturale per cui
## questo meccanismo non puo' fare un mucchio, qualunque sia K: non puo'
## portare nessuno dove non sarebbe gia' potuto andare per conto suo.
##
## La mutazione plausibile e' la piu' tentatrice di tutta la fase: «la
## compagnia vale qualche metro in piu'». Con quella, un vicino attraversa
## mezzo villaggio per una panchina che non avrebbe mai considerato — e i
## corpi cominciano a convergere verso un punto solo, che e' il grumo. Qui
## la seduta accompagnata sta a trenta metri: deve restare invisibile.
func _lo_spareggio_non_allunga_il_guinzaglio(t) -> void:
	var v := _villaggio(t, 1)
	var casa: Node = v["casa"]
	var vis = v["vis"]
	var build = v["build"]
	# ⚠️ **LA GEOMETRIA E' STRETTA APPOSTA**, e la prima stesura non lo era:
	# con la coppia a trenta metri la mutazione «alza il raggio» restava
	# VERDE, perche' a bocciarla era il valore iniziale della chiave e non il
	# cancello. Qui la seduta libera sta a diciassette metri — appena FUORI —
	# e il suo compagno a quindici e mezzo, cioe' appena DENTRO: e' l'unica
	# geometria in cui si vede quale delle due righe sta facendo il lavoro.
	var vicina := _seduta(Vector3(2, 0, 0), casa)
	var lontana_occupata := _seduta(Vector3(15.5, 0, 0), casa)
	var lontana_libera := _seduta(Vector3(17.0, 0, 0), casa)
	build.pezzi["Panchina"] = [vicina, lontana_occupata, lontana_libera]
	_siedi(v["corpi"][0], lontana_occupata, Vector3(15.5, 0, 0))

	t.ok(vis._free_bench(Vector3.ZERO, true) == null,
			"la compagnia oltre i sedici metri NON entra fra i candidati")
	# …e la controprova: il compagno E' dentro il raggio, quindi non e' lui
	# a essere fuori portata — e' la SEDUTA. Senza, il caso non distingue.
	t.ok(vis._free_bench(Vector3(1.5, 0, 0), true) == lontana_libera,
			"spostando l'ancora di un metro e mezzo, la stessa seduta rientra")
	t.ok(vis._seduta_da(Vector3.ZERO) == vicina,
			"e si va dove si sarebbe andati comunque: il raggio non cresce mai")


## QUALE DEI DUE SGABELLI LIBERI — «accanto», mai «all'altro capo».
##
## ⚠️ Non e' una sottigliezza di taratura: sono due FRASI diverse. Due seduti
## accanto con la sedia vuota di lato si legge «stanno insieme»; due seduti
## agli estremi con la sedia vuota in mezzo si legge «si evitano». E la
## seconda e' quella che capitava, perche' `_free_bench` ordinava per
## distanza dall'ANCORA — che e' la risposta a un'altra domanda.
##
## La mutazione plausibile e' lasciare la chiave com'era (`k = d` anche col
## filtro): la scena resta «due persone sedute», e nessun conteggio se ne
## accorge. Se ne accorge solo l'occhio — e questo caso, che fissa quel che
## l'occhio ha scelto (`tools/provino_sosta.gd`, scena 2b).
func _ci_si_siede_accanto_non_in_fondo(t) -> void:
	var v := _villaggio(t, 1)
	var casa: Node = v["casa"]
	var vis = v["vis"]
	var build = v["build"]
	# tre sedute fratelle, come i tre sgabelli del Gazebo
	var uno := _seduta(Vector3(0, 0, 0), casa)
	var due := _seduta(Vector3(0.95, 0, 0), casa)
	var tre := _seduta(Vector3(1.80, 0, 0), casa)
	build.pezzi["Panchina"] = [uno, due, tre]
	_siedi(v["corpi"][0], uno, Vector3(0, 0, 0))

	# l'ancora sta DALL'ALTRA PARTE: ordinando su di lei vincerebbe `tre`,
	# cioe' l'estremo opposto a chi e' seduto — il buco in mezzo.
	var ancora := Vector3(10, 0, 0)
	t.ok(vis._free_bench(ancora) == tre,
			"senza filtro vince il piu' vicino all'ancora, come sempre")
	t.ok(vis._free_bench(ancora, true) == due,
			"col filtro ci si siede ACCANTO a chi c'e', non all'altro capo")


## IL FILTRO NON PUO' SCAVALCARE LA PRENOTAZIONE — o due corpi finiscono
## sullo stesso sgabello.
##
## ⚠️ La mutazione INGENUA (togliere il controllo dello stato) e' un errore a
## runtime, che **non fa fallire un test: lo interrompe**, lasciando la suite
## verde. Quella plausibile e' guardare `r_bench` e dimenticare `walk` — cioe'
## «e' occupato solo se ci sta gia' qualcuno sopra» — che non esplode, e' anche
## ragionevole a leggerla, e mette due chibi uno dentro l'altro appena il
## secondo arriva.
func _il_filtro_rispetta_la_prenotazione(t) -> void:
	var v := _villaggio(t, 3)
	var casa: Node = v["casa"]
	var vis = v["vis"]
	var build = v["build"]
	var occupata := _seduta(Vector3(6, 0, 0), casa)
	var accanto := _seduta(Vector3(6.95, 0, 0), casa)
	var sola := _seduta(Vector3(2, 0, 0), casa)
	build.pezzi["Panchina"] = [sola, occupata, accanto]
	_siedi(v["corpi"][0], occupata, Vector3(6, 0, 0))
	# il secondo ha GIA' prenotato il posto accanto, e ci sta camminando
	var in_arrivo: Node3D = v["corpi"][1]
	in_arrivo.set("_routine_aux", accanto)
	in_arrivo.set("_state", "walk")
	in_arrivo.global_position = Vector3(4, 0, 0)

	t.ok(vis._free_bench(Vector3.ZERO, true) == null,
			"il posto accanto e' gia' prenotato: il filtro non lo offre a un terzo")
	t.ok(vis._seduta_da(Vector3.ZERO) == sola,
			"e il terzo va a sedersi altrove — non addosso a chi sta arrivando")


## PRIMA QUALE COMPAGNIA, POI QUALE SEDIA — e l'ordine dei due confronti si
## vede solo con due gruppi in scena.
##
## La mutazione plausibile e' la stesura di ieri: ordinare **solo** per
## distanza da chi e' seduto. E' ragionevole a leggerla (e risolve la
## domanda per cui era nata, quale sgabello dello stesso mobile), ma fra due
## mobili diversi confronta due numeri che non parlano di distanza da casa:
## vince il gruppo i cui seduti stanno piu' accosti fra loro. Qui il gruppo
## lontano e' piu' accosto di quattro centimetri, e con quella chiave il
## corpo attraversa dodici metri in piu' per una differenza che nessuno puo'
## vedere.
func _la_compagnia_piu_vicina_prima(t) -> void:
	var v := _villaggio(t, 2)
	var casa: Node = v["casa"]
	var vis = v["vis"]
	var build = v["build"]
	# il gruppo VICINO: seduto a 3 m, sedia libera a 90 cm da lui
	var qui_occupata := _seduta(Vector3(3.0, 0, 0), casa)
	var qui_libera := _seduta(Vector3(3.90, 0, 0), casa)
	# il gruppo LONTANO: seduto a 15 m, sedia libera a 86 cm — piu' accosta
	var la_occupata := _seduta(Vector3(15.0, 0, 0), casa)
	var la_libera := _seduta(Vector3(15.86, 0, 0), casa)
	build.pezzi["Panchina"] = [qui_occupata, qui_libera, la_occupata, la_libera]
	_siedi(v["corpi"][0], qui_occupata, Vector3(3.0, 0, 0))
	_siedi(v["corpi"][1], la_occupata, Vector3(15.0, 0, 0))

	t.ok(vis._free_bench(Vector3.ZERO, true) == qui_libera,
			"fra due compagnie si sceglie la piu' VICINA, non la piu' accosta")


## ⚠️ **CHI CHIEDE NON FA COMPAGNIA A SE' STESSO**, e per un pezzo l'ha fatto.
##
## La guardia c'era — `if n.get("_routine_aux") == seat: continue` — e non
## serviva a niente: morde solo quando il posto interrogato e' ESATTAMENTE
## quello che quel corpo ha prenotato, e quel posto `_free_bench` non lo
## restituisce mai (e' gia' «taken»). I posti che arrivano a
## `_seduto_accanto` sono per costruzione DIVERSI dal proprio.
##
## Il caso vero e' questo: un vicino SOLO si siede su uno sgabello del
## Gazebo, e lo sgabello di fianco — a novantacinque centimetri, cioe' dentro
## `VICINI` **da lui stesso** — risultava «accompagnato». Il fatto si
## accendeva per un vicino solo, il riposo prendeva il suo ×1.20, e
## `_panchina_per` gli proponeva il posto accanto a se stesso: restava
## incollato li'. Il commento sopra `_seduto_accanto` dichiarava chiuso
## proprio quel guasto.
##
## ⚠️ E la seconda meta' del caso e' quella che rende il difetto invisibile:
## per CHIUNQUE ALTRO quel posto e' davvero accompagnato, e deve restarlo.
## Un test che chiedesse solo «e' falso» passerebbe anche cancellando la
## compagnia del tutto.
func _un_seduto_non_fa_compagnia_a_se_stesso(t) -> void:
	var v := _villaggio(t, 2)
	var casa: Node = v["casa"]
	var vis = v["vis"]
	var build = v["build"]
	var suo := _seduta(Vector3(0, 0, 0), casa)
	var accanto := _seduta(Vector3(0.95, 0, 0), casa)
	var lontana := _seduta(Vector3(6, 0, 0), casa)
	build.pezzi["Panchina"] = [suo, accanto, lontana]
	var chi: Node3D = v["corpi"][0]
	_siedi(chi, suo, Vector3(0, 0, 0))

	t.ok(not vis._accanto_a_qualcuno(accanto, chi),
			"chi e' seduto non fa compagnia a SE' STESSO sul posto di fianco")
	t.ok(vis._accanto_a_qualcuno(accanto),
			"…ma per chiunque altro quel posto E' accompagnato")
	# e la conseguenza vera: il suo `_panchina_per` non deve trovare
	# compagnia da nessuna parte, quindi ripiega sulla piu' vicina
	var r: Dictionary = vis._residents[0]
	r["cell"] = Vector2i(6, 0)
	t.ok(vis._free_bench(Vector3(6, 0, 0), true, chi) == null,
			"e il filtro, chiesto da lui, non trova nessuna compagnia")
	t.ok(vis._seduta_da(Vector3(6, 0, 0), chi) == lontana,
			"quindi si siede dove si sarebbe seduto comunque")


## ⚠️ **CHI E' DENTRO UNA SCENA NON FA COMPAGNIA A NESSUNO.**
##
## Il pubblico del Concerto resta seduto fino a quarantotto secondi — tre
## volte la sosta — quindi domina il segnale della compagnia. Ma
## `_segna_incontro` rifiuta per costruzione ogni co-presenza in cui uno dei
## due sia `in_scena()`: senza questa riga l'invito spende il gettone e una
## camminata per portare due vicini esattamente dove il registro delle
## cricche non li vede. E' la trappola gia' scritta sopra `VICINI`, un piano
## piu' in la'.
func _chi_e_in_scena_non_fa_compagnia(t) -> void:
	var v := _villaggio(t, 2)
	var casa: Node = v["casa"]
	var vis = v["vis"]
	var build = v["build"]
	var occupata := _seduta(Vector3(0, 0, 0), casa)
	var accanto := _seduta(Vector3(0.95, 0, 0), casa)
	build.pezzi["Panchina"] = [occupata, accanto]
	var attore: Node3D = v["corpi"][0]
	_siedi(attore, occupata, Vector3(0, 0, 0))
	t.ok(vis._accanto_a_qualcuno(accanto), "da fermo, il posto accanto chiama")

	# adesso quel corpo entra in una scena scritta a mano (il Concerto)
	attore.call("apri_scena", 60.0)
	t.ok(bool(attore.call("in_scena")), "il corpo e' dentro una scena")
	t.ok(not vis._accanto_a_qualcuno(accanto),
			"e allora il posto accanto TACE: quella co-presenza il registro "
			+ "delle cricche non la incasserebbe comunque")


## ⚠️ **DORMIRE NON E' SEDERSI.**
##
## `Interactions._sit_down` scrive `_seat_node` per OGNI `kind`, letto
## compreso, e `_sleep_until_morning` non lo azzera: senza la guardia, per
## tutta la notte il letto di Mochi risultava «un corpo seduto» e ogni seduta
## entro `VICINI` da li' chiamava qualcuno — verso un corpo che sta dietro
## una tenda nera.
##
## ⚠️ E si prova la funzione VERA, non una gemella: la classe e' quella di
## produzione col solo `_ready` scavalcato (il suo vuole `%Player` e mezzo
## livello). Una finta che ri-implementasse `sedile_attuale` lascerebbe
## quella vera senza nessun lettore.
func _il_letto_non_e_una_seduta(t) -> void:
	var pannello = PannelloVero.new()
	t.stage(pannello)
	var letto := Node3D.new()
	t.stage(letto)
	pannello.set("_seated", true)
	pannello.set("_seat_node", letto)
	pannello.set("_sleeping", false)
	t.ok(pannello.call("sedile_attuale") == letto,
			"da sveglia e seduta, il sedile c'e'")
	pannello.set("_sleeping", true)
	t.ok(pannello.call("sedile_attuale") == null,
			"ma mentre dorme non c'e' nessun corpo seduto da nessuna parte")


## Il pannello VERO, col solo `_ready` scavalcato: il suo vuole `%Player`,
## `../BuildSystem` e mezzo livello.
class PannelloVero extends "res://scenes/interact/Interactions.gd":
	func _ready() -> void:
		pass

	func _process(_d: float) -> void:
		pass


## ⚠️ **IL FATTO SEGUE IL POSTO SCELTO — e per vederlo l'ancora dev'essere
## SPOSTATA.**
##
## Il caso che sorvegliava questa invariante era muto contro la mutazione che
## il suo stesso commento nomina («c'e' qualcuno seduto vicino a casa mia?»),
## e la ragione e' di banco, non di codice: senza giocatore, senza grafo dei
## ricordi e senza cricche, tutti e quattro gli anelli di `_panchina_per`
## degenerano in `_seduta_da(home)`. «Il posto scelto» e «la panchina piu'
## vicina a casa» erano LO STESSO NODO, quindi non c'era niente da separare.
##
## Qui l'ancora si sposta davvero (Mochi vicina, ammirazione sopra soglia), e
## la geometria e' scelta perche' le due domande diano risposte DIVERSE: la
## seduta accompagnata sta a diciassette metri da casa — fuori dal raggio, se
## la si cerca da li' — e a undici dall'ancora, cioe' dentro.
func _il_fatto_segue_l_ancora_SPOSTATA(t) -> void:
	var v := _villaggio(t, 2)
	var casa: Node = v["casa"]
	var vis = v["vis"]
	var build = v["build"]
	# il giocatore, e un vicino che lo ammira: l'ancora si sposta di
	# `SPOSTA_MAX` verso di lui
	var mochi := Node3D.new()
	casa.add_child(mochi)
	mochi.global_position = Vector3(10, 0, 0)
	vis.set("_player", mochi)
	vis.finta_ammirazione = 0.5

	var di_casa := _seduta(Vector3(1, 0, 0), casa)
	var accompagnata := _seduta(Vector3(17, 0, 0), casa)
	build.pezzi["Panchina"] = [di_casa, accompagnata]
	_siedi(v["corpi"][1], _seduta(Vector3(17.9, 0, 0), casa), Vector3(17.9, 0, 0))

	var r: Dictionary = vis._residents[0]
	r["cell"] = Vector2i(0, 0)
	var home := Vector3(0, 0, 0)
	(v["corpi"][0] as Node3D).global_position = home

	# PREMESSA: e' qui che le due domande si separano. Senza queste due
	# righe il caso tornerebbe muto come prima.
	t.ok(vis._free_bench(home) == di_casa,
			"PREMESSA: la panchina piu' vicina a CASA e' quella di casa")
	t.ok(vis._free_bench(home, true) == null,
			"PREMESSA: e cercando la compagnia DA CASA non si trova niente "
			+ "(la seduta accompagnata e' fuori raggio)")

	var scelta = vis._panchina_per(r, home)
	t.ok(scelta == accompagnata,
			"ma l'ancora e' spostata, e da li' il posto scelto e' quello accompagnato")
	vis._luoghi_del_piano(r, home)
	t.ok(bool(r.get(VISITORS.FATTO_INSIEME, false)),
			"e il fatto segue il posto SCELTO, non una domanda sua")


## ⚠️ **«ACCANTO» E' IL PIU' VICINO, NON IL PRIMO DELL'ELENCO.**
##
## Non e' cosmetica: `_free_bench` ordina per distanza fra l'ancora e IL
## COMPAGNO, quindi un compagno sbagliato da' la chiave sbagliata e manda il
## corpo sul mobile sbagliato. La mutazione plausibile e' fermarsi al primo
## che rientra nel raggio (`if d <= VICINI: chi = n; break`), che sembra un
## risparmio e non produce nessun errore.
func _accanto_e_il_piu_vicino_non_il_primo(t) -> void:
	var v := _villaggio(t, 2)
	var casa: Node = v["casa"]
	var vis = v["vis"]
	var libera := _seduta(Vector3(0, 0, 0), casa)
	# il PRIMO dell'elenco e' il piu' LONTANO dei due (dentro `VICINI`)
	var lontano: Node3D = v["corpi"][0]
	var vicino: Node3D = v["corpi"][1]
	_siedi(lontano, _seduta(Vector3(1.7, 0, 0), casa), Vector3(1.7, 0, 0))
	_siedi(vicino, _seduta(Vector3(0.5, 0, 0), casa), Vector3(0.5, 0, 0))
	t.ok(vis._seduto_accanto(libera) == vicino,
			"accanto e' il piu' VICINO, non il primo che capita nell'elenco")


## ⚠️ **MOCHI RESTA IL PRIMO ANELLO** — e nessun test lo teneva.
##
## E' la terza domanda della REGOLA SACRA: se la compagnia salisse sopra
## `ancora_riposo`, il villaggio si raggrupperebbe altrove **proprio nel
## momento in cui arrivi**. La mutazione plausibile e' una riga sola
## (provare `_free_bench(home, true)` prima dei quattro anelli), non produce
## nessun errore, e rende il gioco meno cozy senza che niente lo dica.
##
## La geometria separa le due risposte: la seduta accompagnata sta a undici
## metri da casa — dentro il raggio se la si cerca da CASA — e a diciassette
## dall'ancora spostata, cioe' fuori.
func _mochi_resta_il_primo_anello(t) -> void:
	var v := _villaggio(t, 2)
	var casa: Node = v["casa"]
	var vis = v["vis"]
	var build = v["build"]
	var mochi := Node3D.new()
	casa.add_child(mochi)
	mochi.global_position = Vector3(10, 0, 0)
	vis.set("_player", mochi)
	vis.finta_ammirazione = 0.5

	var dalla_tua_parte := _seduta(Vector3(6, 0, 0), casa)
	var accompagnata := _seduta(Vector3(-11, 0, 0), casa)
	build.pezzi["Panchina"] = [dalla_tua_parte, accompagnata]
	_siedi(v["corpi"][1], _seduta(Vector3(-11.9, 0, 0), casa), Vector3(-11.9, 0, 0))

	var r: Dictionary = vis._residents[0]
	r["cell"] = Vector2i(0, 0)
	var home := Vector3(0, 0, 0)
	(v["corpi"][0] as Node3D).global_position = home

	t.ok(vis._free_bench(home, true) == accompagnata,
			"PREMESSA: cercando la compagnia da CASA la si trova")
	t.ok(vis._panchina_per(r, home) == dalla_tua_parte,
			"ma l'invito non scavalca il giocatore: ci si siede dove sei TU")


## ⚠️ **IL TETTO DEL LEASE STA SOPRA LA POSA PIU' LUNGA — misurata dal corpo.**
##
## `LEASE_SPONTANEO` era giudicato solo contro se stesso: tutti e tre i punti
## che lo nominano lo confrontano con `VISITORS.LEASE_SPONTANEO`. MISURATO:
## portandolo da 30 a **5** ogni sosta spontanea viene troncata in silenzio —
## cioe' sparisce la finestra da p50 16,2 s su cui poggia tutto il
## meccanismo — e la suite resta completamente VERDE.
##
## Il numero che lo sorveglia non e' lui: e' la finestra che il corpo si da'
## da se' in `_enter_state("r_bench")`, e la si MISURA su duecento corpi
## diversi invece di ricopiarla di qua.
func _il_tetto_del_lease_sta_sopra_la_posa(t) -> void:
	var piu_lunga := 0.0
	for i in 200:
		var c := _corpo(t, 91000 + i * 37)
		c._enter_state("r_bench")
		piu_lunga = maxf(piu_lunga, float(c.resta_in_posa()))
	t.ok(piu_lunga > 0.0, "il corpo si da' una posa (la piu' lunga misurata: %.2f s)" % piu_lunga)
	t.ok(VISITORS.LEASE_SPONTANEO > piu_lunga,
			("il tetto (%.1f s) sta SOPRA la posa piu' lunga (%.2f s): un tetto piu' "
			+ "basso troncherebbe proprio la finestra che il fatto esiste per abitare")
					% [VISITORS.LEASE_SPONTANEO, piu_lunga])
