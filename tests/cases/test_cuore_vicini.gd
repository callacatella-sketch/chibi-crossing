extends RefCounted
## IL CUORE DEI VICINI — quello che hanno visto, e cosa se ne fa.
##
## `test_percezione` prova l'INGRESSO (chi ha girato la testa, e che il
## ricordo non si incide se non l'ha girata); `test_pettegolezzo` e
## `test_ritmo_emozioni` provano il MOTORE in C++. Questo file prova l'unica
## cosa che resta, ed è quella che il giocatore vede: **le uscite**. Sono
## quattro, e nessuna è una parola.
##
##  1. **DOVE UNO SI METTE** — la panchina, che per chi ti ammira si sceglie
##     da un punto un po' spostato verso di te (scena 3).
##  2. **QUALE AIUOLA** — fra quelle che hanno sete, quella che ti ha vista
##     annaffiare (scena 4).
##  3. **QUALE SIMBOLO** esce in una chiacchiera fra due di LORO — il
##     pettegolezzo, che è l'unica cosa di tutta la Fase 4 che si legge a
##     schermo, e si legge di sbieco (scena 2).
##  4. **COSA GLI RESTA** dopo un riavvio — una promozione al giorno, al
##     massimo, e solo per quel che ha visto coi propri occhi.
##
## LA REGOLA CHE QUESTO FILE ESISTE PER TENERE CHIUSA, e che non produrrebbe
## nessun errore il giorno che si rompe: **l'ammirazione non deve diventare
## un guinzaglio.** Non è un bug che si nota: sono ventotto vicini che ti
## orbitano intorno, con la suite verde e tutti i test comportamentali
## soddisfatti, e ci si arriva TARANDO BENE un sistema progettato male. Un
## gioco cozy in cui non si può stare da soli è rovinato. Perciò qui non si
## misura solo che l'ancora si SPOSTI: si misura, su una spazzata di
## configurazioni a caso, che **non possa mai allontanarsi da casa più di
## `SPOSTA_MAX`** — che è la garanzia, non la taratura.
##
## E LA SECONDA REGOLA, che è la stessa di sempre in questo progetto: una
## conseguenza deve AGGIUNGERE, mai togliere. Due casi qui sotto (`_ripiega`)
## servono solo a questo — se l'ancora spostata non trova niente si torna a
## casa, perché un vicino che per averti visto si addormenta per terra
## invece che sulla panchina non insegna «mi ha notato», insegna «i vicini
## fanno cose a caso».
##
## Niente è finto se non due tabelle di lettura (i pezzi posati, che è un
## elenco senza regole dentro). Il registro dei vicini è quello di
## produzione col solo `_ready` scavalcato, i corpi sono `Visitor` veri, il
## Garden è quello vero (con le aiuole messe a mano nel suo dizionario:
## `bed_needing_water` resta la sua funzione), il cuore è l'`EcsMondo` in C++.

const VIS := preload("res://scenes/npc/Visitors.gd")
const VISITOR := preload("res://scenes/npc/Visitor.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")
const GUSTO := preload("res://scenes/npc/Gusto.gd")
const PERC := preload("res://scenes/npc/Percezione.gd")
const VILLAGGIO := preload("res://scenes/npc/Villaggio.gd")
const GARDEN := preload("res://scenes/interact/Garden.gd")

const DT := 1.0 / 60.0


## Il registro dei vicini VERO, col solo `_ready` scavalcato: quello di
## produzione vuole `%Player` e `../BuildSystem`, cioè il villaggio intero.
## Tutto il resto — `_ciclo_sonno`, `_cuore_di`, `_recita`, `_run_chat` — è
## il codice che gira in partita.
class Registro extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		# la UI serve davvero: `_recita` racconta l'annaffiatura con un toast,
		# e senza pannello quella riga esplode a metà funzione lasciando la
		# suite verde (è il guasto che il conteggio degli SCRIPT ERROR esiste
		# per prendere)
		_build_ui()


## L'orologio del mondo, con la sola cosa che il cuore gli chiede: quanto
## dura un giorno. Le mezze vite dei ricordi si DERIVANO da lì.
class Orologio extends Node3D:
	var cycle_seconds := 600.0
	var time := 0.5
	var day := 1


## L'elenco dei pezzi posati. **Non è un BuildSystem finto**: non ha una
## regola dentro. Le due domande che risponde («che pezzi ci sono», «ci si
## arriva») sono lookup, e la regola che questo file sta provando (quale
## panchina si sceglie) vive in `_free_bench`, che è quella vera.
class Magazzino extends Node3D:
	var pezzi := {}
	func get_placed_by_name(n: String) -> Array:
		return pezzi.get(n, [])
	func raggiungibile(_a: Vector2i, _b: Vector2i) -> bool:
		return true


## Un corpo che si segna cosa gli esce di bocca e dalla nuvoletta. `super()`
## lascia girare il codice di produzione: qui non si sostituisce niente, si
## ascolta.
class Chiacchierone extends "res://scenes/npc/Visitor.gd":
	var bolle: Array = []
	var dette: Array = []
	func chat_bubble(sym: String) -> void:
		bolle.append(sym)
		super(sym)
	func speak(concetti: Array, mood := "neutro") -> void:
		dette.append((concetti as Array).duplicate())
		super(concetti, mood)


func run(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	var m = ClassDB.instantiate("EcsMondo")
	if not m.has_method("cosa_da_ricordare"):
		t.ok(false, "EcsMondo non espone «cosa_da_ricordare»: il passo 6 non è nel binario")
		m.free()
		return
	# --- le tre letture vive (C++)
	_le_tre_letture_esistono(t, m)
	_ammirazione_e_la_stessa_lettura(t, m)
	_dove_e_il_posto_del_ricordo_piu_forte(t, m)
	_dove_segue_anche_il_sentito_dire(t, m)
	_cosa_da_ricordare_solo_i_visti(t, m)
	_cosa_da_ricordare_vuole_piu_di_un_occhiata(t, m)
	# --- l'ancora (pura)
	_l_ancora_non_e_un_guinzaglio(t)
	_le_soglie_si_leggono_in_occhiate(t, m)
	m.free()
	# --- il cablaggio, sul registro vero
	_la_panchina_si_sposta(t)
	_la_panchina_ripiega_su_casa(t)
	_la_panchina_che_hai_costruito(t)
	_la_panchina_mette_prima_chi_c_e(t)
	_la_panchina_dell_opera_non_e_un_guinzaglio(t)
	_l_ancora_del_ricordo_e_una_sola(t)
	_l_aiuola_che_ha_visto(t)
	_l_aiuola_ripiega_su_casa(t)
	_la_fattibilita_guarda_la_stessa_aiuola(t)
	_il_piano_guarda_gli_stessi_posti(t)
	_il_gusto_arriva_di_la(t)
	_il_gusto_porta_l_indole_del_cervello(t)
	_il_gusto_non_si_rifa_a_ogni_frame(t)
	_una_passata_non_diventa_un_ricordo(t)
	_una_promozione_al_giorno(t)
	_la_notizia_diventa_il_tema(t)
	_e_poi_non_se_ne_parla_piu(t)
	_le_mezze_vite_vengono_dal_giorno(t)


# ============================================== 1. LE TRE LETTURE VIVE
#
# Non sono oracoli, e la differenza non è il nome: `debug_emozioni` alloca un
# Dictionary e tre array per rispondere, e il gioco non deve chiamarlo. Prima
# di queste tre, il cuore di un vicino era leggibile SOLO da lì — cioè non
# era leggibile affatto, e l'emozione non poteva uscire dall'agenda.

func _le_tre_letture_esistono(t, m) -> void:
	for nome in ["ammirazione", "dove", "cosa_da_ricordare"]:
		t.ok(m.has_method(nome), "EcsMondo espone «%s» nel binario" % nome)


## L'AMMIRAZIONE È LA STESSA LETTURA, non una seconda formula.
##
## L'asserzione che conta è l'ultima: `ammirazione(id)` deve dare lo STESSO
## DOUBLE di `debug_emozioni(id)["ammirazione"]`. Con «circa» questo caso
## resterebbe verde su una reimplementazione che somma le tinte in un altro
## ordine — e due verità sullo stesso numero è precisamente come, in questo
## progetto, sono nate tutte le divergenze silenziose.
func _ammirazione_e_la_stessa_lettura(t, m) -> void:
	var id: int = m.registra(PackedStringArray([]), "")
	t.ok(float(m.ammirazione(id)) == 0.0,
			"chi non ha visto niente non ammira niente, e vale ZERO esatto")

	m.osserva(id, m.indice_verbo("annaffia"), Vector3(3.0, 0.0, 4.0), -1)
	var a := float(m.ammirazione(id))
	t.ok(a > 0.0, "dopo aver visto annaffiare, qualcosa da ammirare c'è (%s)" % str(a))
	var d: Dictionary = m.debug_emozioni(id)
	t.ok(a == float(d["ammirazione"]),
			"…ed è LO STESSO DOUBLE della lettura di prova: una sola formula, non due")

	# E PASSA DAL GUSTO. Un'ammirazione uguale per tutti sarebbe un canale che
	# non discrimina, cioè indistinguibile da un dado: è la lezione delle
	# REAZIONI di Animo, che valevano 0.000000 per ogni carattere.
	m.riferisci_gusto(id, PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0]))
	t.ok(float(m.ammirazione(id)) == 0.0,
			"a chi non importa di niente, lo stesso gesto non dice niente")
	m.riferisci_gusto(id, PackedFloat64Array([3.0, 1.0, 1.0, 1.0, 1.0, 1.0]))
	t.ok(float(m.ammirazione(id)) > a,
			"e a chi tiene ai fiori il triplo, dice il triplo")
	m.dimentica(id)


## DOVE L'HA VISTO — ed è la scena 4. Il ripiego è un PARAMETRO apposta: così
## «non ricordo niente» e «ricordo casa mia» sono lo stesso identico Vector3,
## e nessun chiamante può dimenticarsi di controllare un sentinella.
func _dove_e_il_posto_del_ricordo_piu_forte(t, m) -> void:
	var casa := Vector3(-2.0, 1.5, 7.0)
	var id: int = m.registra(PackedStringArray([]), "")
	t.ok(m.dove(id, m.C_FIORE, casa) == casa,
			"chi non ricorda niente indica il punto di ripiego, ESATTO")

	# UN solo ricordo: si indica quello.
	m.osserva(id, m.indice_verbo("annaffia"), Vector3(5.0, 0.0, -3.0), -1)
	var p1: Vector3 = m.dove(id, m.C_FIORE, casa)
	t.almost(p1.x, 5.0, "il posto del ricordo è quello inciso (x)", 1e-5)
	t.almost(p1.z, -3.0, "…e (z)", 1e-5)
	t.almost(p1.y, casa.y,
			"…mentre la quota è quella del ripiego: il ricordo non ne porta una, e inventare uno zero manderebbe sottoterra chi ragiona su una casa sull'albero",
			1e-9)

	# UN'ALTRA COSA non si confonde con questa.
	t.ok(m.dove(id, m.C_PESCE, casa) == casa,
			"e un ricordo di fiori non risponde alla domanda sui pesci")

	m.dimentica(id)

	# IL PIÙ PESANTE, NON IL PIÙ RECENTE — e l'ordine di questo banco è
	# scelto apposta: il ricordo forte si incide PRIMA e quello debole DOPO.
	# Al contrario («forte per ultimo») un `dove` che prendesse semplicemente
	# l'ultima riga darebbe la stessa risposta, e questa asserzione sarebbe
	# un ritratto invece che un test — l'ho verificato guastando la riga.
	# «semina» è un altro verbo (quindi non si fonde con «annaffia») ma la
	# stessa cosa: quattro volte pesa 1.75 contro 1.00.
	var id2: int = m.registra(PackedStringArray([]), "")
	for _k in 4:
		m.osserva(id2, m.indice_verbo("semina"), Vector3(-9.0, 0.0, 1.0), -1)
	m.osserva(id2, m.indice_verbo("annaffia"), Vector3(5.0, 0.0, -3.0), -1)
	var g: Dictionary = m.debug_grafo(id2)
	var pesi: Array = []
	for riga in (g["ricordi"] as Array):
		pesi.append(m.debug_grafo_peso(riga, float(m.debug_ritmo()["tempo"]),
				float(m.debug_ritmo()["mezza_vita"])))
	t.ok(pesi.size() == 2 and float(pesi[0]) > float(pesi[1]),
			"PREMESSA: il ricordo inciso per PRIMO è il più pesante (%s)" % str(pesi))
	var p2: Vector3 = m.dove(id2, m.C_FIORE, casa)
	t.almost(p2.x, -9.0,
			"fra due ricordi della stessa cosa indica il PIÙ PESANTE, non il più recente", 1e-5)
	m.dimentica(id2)


## IL POSTO ATTRAVERSA IL PASSAPAROLA. È la sola prova che un pettegolezzo ha
## una conseguenza nel MONDO e non solo in un dizionario: un terzo che non
## c'era va comunque all'aiuola giusta. Il soggetto si perde nel passaggio (una
## cosa fuori posto, mai due), il LUOGO no.
func _dove_segue_anche_il_sentito_dire(t, m) -> void:
	var casa := Vector3(0.0, 0.0, 0.0)
	var a: int = m.registra(PackedStringArray([]), "")
	var b: int = m.registra(PackedStringArray([]), "")
	m.osserva(a, m.indice_verbo("annaffia"), Vector3(11.0, 0.0, -4.0), -1)
	t.eq(int(m.racconta(a, b, VILLAGGIO.SMORZAMENTO)), int(m.C_FIORE),
			"A racconta a B di un'annaffiatura")
	var p: Vector3 = m.dove(b, m.C_FIORE, casa)
	t.almost(p.x, 11.0, "e B, che non c'era, sa comunque DOVE (x)", 1e-5)
	t.almost(p.z, -4.0, "…e (z)", 1e-5)
	m.dimentica(a)
	m.dimentica(b)


## LA PROMOZIONE GUARDA SOLO QUEL CHE HO VISTO IO.
##
## Il caso è costruito perché la differenza si veda: il ricordo SENTITO pesa
## più di quello VISTO (1.23 contro 1.00), quindi senza il filtro vincerebbe.
## Perché conta: `cosa_da_ricordare` è l'unica cosa della Fase 4 che
## attraversa un riavvio, e una diceria che sopravvive alla propria fonte è la
## via più corta perché una storia diventi una gogna (`Animo.senti_dire` lo
## dice già a proposito delle voci sulle persone).
func _cosa_da_ricordare_solo_i_visti(t, m) -> void:
	var a: int = m.registra(PackedStringArray([]), "")
	var b: int = m.registra(PackedStringArray([]), "")
	# A riceve sei regali: è forte (fatto a me = doppio, sei volte = +125%)
	for _k in 6:
		m.osserva(a, m.indice_verbo("dona"), Vector3(1.0, 0.0, 1.0), a)
	# B vede un'annaffiatura sola, e poi si sente raccontare i regali
	m.osserva(b, m.indice_verbo("annaffia"), Vector3(2.0, 0.0, 2.0), -1)
	t.eq(int(m.racconta(a, b, VILLAGGIO.SMORZAMENTO)), int(m.C_AMICO),
			"…e la notizia dei regali arriva a B")

	# la premessa del caso, misurata e non supposta
	var ora := float(m.debug_ritmo()["tempo"])
	var mv := float(m.debug_ritmo()["mezza_vita"])
	var visto := 0.0
	var sentito := 0.0
	for riga in (m.debug_grafo(b)["ricordi"] as Array):
		var w := float(m.debug_grafo_peso(riga, ora, mv))
		if (int((riga as Dictionary)["bandiere"]) & int(m.R_SENTITO)) != 0:
			sentito = w
		else:
			visto = w
	t.ok(sentito > visto,
			"PREMESSA: nel grafo di B il sentito dire pesa più del visto (%.4f contro %.4f)"
					% [sentito, visto])
	t.eq(int(m.cosa_da_ricordare(b, 0.0)), int(m.C_FIORE),
			"e a B resta comunque quello che ha visto coi propri occhi, non quello che gli hanno detto")

	# E SE HA SOLO SENTITO DIRE, non gli resta niente — nemmeno a soglia zero.
	# Serve un altro che racconti: A la sua notizia l'ha già data, e una
	# notizia si racconta una volta sola.
	var d: int = m.registra(PackedStringArray([]), "")
	var c: int = m.registra(PackedStringArray([]), "")
	for _k in 6:
		m.osserva(d, m.indice_verbo("dona"), Vector3(1.0, 0.0, 1.0), d)
	m.racconta(d, c, VILLAGGIO.SMORZAMENTO)
	t.ok((m.debug_grafo(c)["ricordi"] as Array).size() > 0,
			"(a C la notizia è arrivata davvero)")
	t.eq(int(m.cosa_da_ricordare(c, 0.0)), -1,
			"chi ha solo sentito dire non porta via niente, nemmeno a soglia zero")
	m.dimentica(a)
	m.dimentica(b)
	m.dimentica(c)
	m.dimentica(d)


## PIÙ DI UN'OCCHIATA. La soglia è in unità di «un ricordo fresco, visto una
## volta, non fatto a me» — che pesa esattamente 1.0. Le due strade per
## superarla sono le due che vale la pena ricordarsi, e non è una
## coincidenza: sono i due moltiplicatori che `chibi::peso` conosce.
func _cosa_da_ricordare_vuole_piu_di_un_occhiata(t, m) -> void:
	var soglia := float(VIS.RICORDO_SOGLIA)
	var id: int = m.registra(PackedStringArray([]), "")
	t.eq(int(m.cosa_da_ricordare(id, soglia)), -1, "a testa vuota non resta niente")

	m.osserva(id, m.indice_verbo("annaffia"), Vector3.ZERO, -1)
	t.eq(int(m.cosa_da_ricordare(id, soglia)), -1,
			"un'occhiata sola non diventa il ricordo di una vita")
	t.eq(int(m.cosa_da_ricordare(id, 0.0)), int(m.C_FIORE),
			"…ma c'è, e a soglia zero si vede: è la SOGLIA a tenerlo fuori, non un filtro")
	m.dimentica(id)

	# (a) L'HA FATTO A ME — il regalo raddoppia
	var b: int = m.registra(PackedStringArray([]), "")
	m.osserva(b, m.indice_verbo("dona"), Vector3.ZERO, b)
	t.eq(int(m.cosa_da_ricordare(b, soglia)), int(m.C_AMICO),
			"un gesto fatto A ME sì: resta")
	m.dimentica(b)

	# (b) TI HO VISTA FARLO A LUNGO — sei aiuole nello stesso pomeriggio
	var c: int = m.registra(PackedStringArray([]), "")
	for _k in 6:
		m.osserva(c, m.indice_verbo("annaffia"), Vector3.ZERO, -1)
	t.eq(int(m.cosa_da_ricordare(c, soglia)), int(m.C_FIORE),
			"e un gesto lungo sì: resta anche quello")

	# IL PIÙ PESANTE, NON L'ULTIMO — e anche qui il forte si incide PRIMA e
	# il debole DOPO, se no una riga che prendesse semplicemente l'ultimo
	# ricordo darebbe la stessa risposta e questa asserzione non
	# sorveglierebbe niente.
	var e: int = m.registra(PackedStringArray([]), "")
	for _k in 6:
		m.osserva(e, m.indice_verbo("dona"), Vector3.ZERO, e)
	m.osserva(e, m.indice_verbo("annaffia"), Vector3.ZERO, -1)
	t.eq(int(m.cosa_da_ricordare(e, 0.0)), int(m.C_AMICO),
			"e quel che resta è la cosa che ha PESATO di più, non l'ultima capitata")
	m.dimentica(e)

	# (c) E SBIADISCE. Passate due mezze vite, quel che restava non resta più:
	# la promozione è per i ricordi VIVI, non per l'archivio.
	var mv := float(m.debug_ritmo()["mezza_vita"])
	for _k in int(2.0 * mv / DT):
		m.avanza(DT, 0.5)
	t.eq(int(m.cosa_da_ricordare(c, soglia)), -1,
			"…ma due mezze vite dopo no: si promuove quel che è ancora vivo")
	m.dimentica(c)


# ================================================= 2. L'ANCORA (PURA)

## L'ANCORA NON È UN GUINZAGLIO, e questa è la garanzia — non la taratura.
##
## Le tre valvole si guastano una per volta su una finestra che senza guasti
## dice sì; poi la spazzata: seicento configurazioni a caso, e in NESSUNA
## l'ancora può allontanarsi da casa più di `SPOSTA_MAX`. È l'unica riga di
## questo file che protegge dal guasto che non si vede — ventotto vicini che
## orbitano attorno al giocatore, con tutto il resto verde.
func _l_ancora_non_e_un_guinzaglio(t) -> void:
	var casa := Vector3.ZERO
	var mochi := Vector3(10.0, 0.0, 0.0)

	# LA FINESTRA BUONA: ti ammira, e sei a dieci metri da casa sua.
	var buona := VIS.ancora_riposo(casa, mochi, 1.0)
	t.almost(buona.distance_to(casa), VIS.SPOSTA_MAX,
			"LA FINESTRA BUONA: l'ancora si sposta verso Mochi, di SPOSTA_MAX metri", 1e-5)
	t.almost(buona.x, VIS.SPOSTA_MAX, "…e si sposta VERSO di lei, non a caso", 1e-5)

	# (a) NON TI AMMIRA. Senza questa valvola l'ancora si sposterebbe per
	# chiunque, e «mi ha notato» smetterebbe di voler dire qualcosa.
	t.ok(VIS.ancora_riposo(casa, mochi, 0.0) == casa,
			"chi non ti ha visto resta a casa sua, ESATTAMENTE")
	t.ok(VIS.ancora_riposo(casa, mochi, VIS.AMMIRA_SOGLIA) == casa,
			"…e sulla soglia esatta non si muove: si chiede di superarla, non di pareggiarla")

	# (b) SEI LONTANO. È la valvola che tiene separato «mi fa piacere che tu
	# sia qui» da «ti sto seguendo»: oltre venti metri, spostarsi verso Mochi
	# vorrebbe dire abbandonare il proprio angolo perché il giocatore è
	# passato dall'altra parte del villaggio.
	t.ok(VIS.ancora_riposo(casa, Vector3(VIS.MOCHI_VICINA, 0, 0), 1.0) == casa,
			"se sei lontano l'ancora non si muove")
	t.ok(VIS.ancora_riposo(casa, Vector3(80.0, 0, 0), 1.0) == casa,
			"…e a maggior ragione se sei dall'altra parte del villaggio")

	# (c) SEI GIÀ LÌ: l'ancora arriva su di te e si ferma, non ti supera.
	var vicino := VIS.ancora_riposo(casa, Vector3(2.0, 0, 0), 1.0)
	t.almost(vicino.x, 2.0, "se sei a due metri l'ancora arriva lì e si ferma", 1e-5)

	# LA SPAZZATA: il guinzaglio non esiste, per NESSUNA configurazione.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260811
	var fuori := 0
	var mossi := 0
	for _k in 600:
		var h := Vector3(rng.randf_range(-40.0, 40.0), 0.0, rng.randf_range(-40.0, 40.0))
		var p := Vector3(rng.randf_range(-40.0, 40.0), 0.0, rng.randf_range(-40.0, 40.0))
		var am := rng.randf_range(0.0, 6.0)
		var an := VIS.ancora_riposo(h, p, am)
		if an.distance_to(h) > VIS.SPOSTA_MAX + 1e-5:
			fuori += 1
		if an != h:
			mossi += 1
	t.eq(fuori, 0,
			"su seicento configurazioni a caso l'ancora non esce MAI da SPOSTA_MAX metri da casa")
	t.ok(mossi > 60,
			"…e si è mossa davvero (%d volte su 600): una garanzia rispettata da un canale spento non prova niente"
					% mossi)


## LE SOGLIE SI LEGGONO IN «OCCHIATE», e l'occhiata la misura il C++.
##
## È la lezione che questa fase ha già pagato due volte (con `PASSO_EMO` e
## con `RAGGIO`): una soglia giudicata contro sé stessa non è sorvegliata da
## nessuno. Qui l'unità è il peso di un ricordo fresco visto una volta — un
## numero che nasce in `chibi::peso` — e le due soglie si leggono così:
## spostare un'ancora costa MENO di un'occhiata, portarsi via un ricordo per
## sempre costa DI PIÙ.
func _le_soglie_si_leggono_in_occhiate(t, m) -> void:
	var mv := float(m.debug_ritmo()["mezza_vita"])
	var occhiata := float(m.debug_grafo_peso({}, 0.0, mv))
	t.almost(occhiata, 1.0,
			"PREMESSA: un ricordo fresco, visto una volta, non fatto a me, pesa uno", 1e-9)

	t.ok(VIS.AMMIRA_SOGLIA < occhiata,
			"una sola occhiata BASTA a spostare un'ancora: se non bastasse, la scena 3 non succederebbe a nessuno")
	t.ok(VIS.RICORDO_SOGLIA >= occhiata,
			"…e NON basta a portarsi via un ricordo per sempre: quello costa più di una passata di sfuggita")
	t.ok(VIS.AMMIRA_SOGLIA < VIS.RICORDO_SOGLIA,
			"far piacere è più facile che restare in mente, ed è giusto che sia in quest'ordine")

	# E LE DUE DISTANZE si giudicano col raggio della percezione, che vive in
	# un altro file e non è mio: un'ancora non può spostarsi più lontano di
	# quanto si possa essere stati per vedere il gesto, e «sei vicino» deve
	# comprendere tutti quelli che potevano vederti — se no la scena 3
	# sarebbe morta proprio per i testimoni.
	t.ok(VIS.SPOSTA_MAX < PERC.RAGGIO,
			"l'ancora si sposta meno del raggio da cui si può aver visto (%.1f < %.1f)"
					% [VIS.SPOSTA_MAX, PERC.RAGGIO])
	t.ok(VIS.MOCHI_VICINA > PERC.RAGGIO,
			"e «Mochi è vicina» comprende tutti quelli che potevano vederla (%.1f > %.1f)"
					% [VIS.MOCHI_VICINA, PERC.RAGGIO])


# ============================== 3. LA PANCHINA CHE SI SPOSTA (scena 3)

## Il villaggio minimo per le due scene: registro vero in scena, N corpi
## veri, un magazzino di pezzi. Torna {"vis", "righe", "build"}.
func _villaggio(t, quanti: int, con_build := true) -> Dictionary:
	var vis = t.stage(Registro.new())
	var righe: Array = []
	for i in quanti:
		var v = VISITOR.new()
		v.dna = DNA.generate(7100 + i * 31)
		v.mode = "resident"
		t.stage(v)
		v._enter_state("r_idle")
		v._timer = 9999.0
		var r := {"node": v, "label": "Cuore%d" % i, "dna": v.dna,
				"cell": Vector2i(0, 0), "species": "chibi"}
		vis._residents.append(r)
		righe.append(r)
		# niente quirk: `_quirk_tick` andrebbe a cercare funghi in un
		# villaggio che qui non c'è
		var b: RefCounted = vis._ensure_brain(r)
		b.quirk = ""
	var build = null
	if con_build:
		build = t.stage(Magazzino.new())
		vis._build = build
	return {"vis": vis, "righe": righe, "build": build}


func _panchina(t, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	t.stage(n)
	n.global_position = pos
	return n


## LA SCENA 3, sulla funzione vera e col corpo vero: chi ti ammira sceglie
## un'altra panchina — quella dalla tua parte — e ci va. Non ti raggiunge,
## non ti parla: si siede e si fa gli affari suoi.
##
## Le due panchine stanno a 8 e a 9 metri da casa, in direzioni opposte: da
## casa vince la più vicina (A), e non c'è pareggio da interpretare. Con
## l'ancora spostata di sei metri verso Mochi, B è a tre metri e A a
## quattordici.
func _la_panchina_si_sposta(t) -> void:
	var mondo := _villaggio(t, 1)
	var vis = mondo["vis"]
	var r: Dictionary = mondo["righe"][0]
	var node: Node3D = r["node"]
	var casa := Vector3(0, 0, 0)
	var a := _panchina(t, Vector3(0, 0, -8.0))
	var b := _panchina(t, Vector3(0, 0, 9.0))
	(mondo["build"] as Node).set("pezzi", {"Panchina": [a, b]})

	# il giocatore, dalla parte di B
	var mochi := t.stage(Node3D.new()) as Node3D
	mochi.global_position = Vector3(0, 0, 12.0)
	vis._player = mochi

	# (a) NON TI HA VISTO: la panchina è quella di sempre, la più vicina a casa
	vis._ciclo_sonno(DT, 0.5)   # nasce l'entità
	t.eq(vis._panchina_per(r, casa), a,
			"chi non ti ha visto sceglie la panchina più vicina a casa sua")

	# (b) TI HA VISTO. Una sola annaffiatura basta a spostare l'ancora.
	var id: int = int(r["ecs"])
	vis._ecs.osserva(id, vis._ecs.indice_verbo("annaffia"), Vector3(1, 0, 1), -1)
	t.ok(float(vis._ecs.ammirazione(id)) > VIS.AMMIRA_SOGLIA,
			"(l'ammirazione ha davvero superato la soglia: %.3f)"
					% float(vis._ecs.ammirazione(id)))
	t.eq(vis._panchina_per(r, casa), b,
			"chi ti ha vista sceglie quella dalla TUA parte: l'ancora si è spostata, il corpo no")

	# (c) E IL CORPO CI VA DAVVERO, passando dalla recita di produzione — non
	# dalla funzione che ho appena provato. Senza questa riga, `_recita`
	# potrebbe essere rimasta a `_free_bench(home)` e tutto il resto sarebbe
	# verde.
	vis._recita(r, node, vis._ensure_brain(r), "riposo", "day")
	t.eq(node.get("_routine_aux"), b,
			"e il corpo si incammina PROPRIO verso quella: la scena 3 esiste in partita")

	# (d) SE MOCHI SE NE VA, il vicino non la insegue: l'ancora torna a casa.
	mochi.global_position = Vector3(0, 0, 60.0)
	t.eq(vis._panchina_per(r, casa), a,
			"e se il giocatore se ne va dall'altra parte, si torna alla panchina di casa: nessuno insegue nessuno")


## SE DALL'ANCORA SPOSTATA NON SI VEDE NESSUNA PANCHINA, SI RIPIEGA SU CASA.
## Senza questa riga l'unica panchina del villaggio, se sta dalla parte
## opposta, uscirebbe dal raggio e il vicino si addormenterebbe per terra:
## starebbe PEGGIO per averti visto, che è il modo più veloce per rendere
## illeggibile un sistema che non parla.
func _la_panchina_ripiega_su_casa(t) -> void:
	var mondo := _villaggio(t, 1)
	var vis = mondo["vis"]
	var r: Dictionary = mondo["righe"][0]
	var casa := Vector3(0, 0, 0)
	# una sola panchina, a tredici metri da casa e dalla parte SBAGLIATA:
	# dall'ancora spostata (a +6) sarebbe a diciannove, fuori dal raggio di
	# ricerca
	var sola := _panchina(t, Vector3(0, 0, -13.0))
	(mondo["build"] as Node).set("pezzi", {"Panchina": [sola]})
	var mochi := t.stage(Node3D.new()) as Node3D
	mochi.global_position = Vector3(0, 0, 12.0)
	vis._player = mochi

	vis._ciclo_sonno(DT, 0.5)
	var id: int = int(r["ecs"])
	vis._ecs.osserva(id, vis._ecs.indice_verbo("annaffia"), Vector3(1, 0, 1), -1)
	# la premessa: dall'ancora spostata quella panchina NON si vede
	t.eq(vis._free_bench(VIS.ancora_riposo(casa, mochi.global_position, 9.9)), null,
			"PREMESSA: dall'ancora spostata quella panchina è fuori portata")
	t.eq(vis._panchina_per(r, casa), sola,
			"e allora si ripiega su casa: chi ti ha visto non finisce a dormire per terra")


# ================= 3-bis. LA PANCHINA CHE TI HA VISTA COSTRUIRE
#
# Posa una panchina in un angolo del villaggio mentre qualcuno ti guarda, e
# quando a quel qualcuno verrà voglia di sedersi ci andrà — proprio lui,
# proprio lì. È la scena 4 («l'aiuola che ha visto») detta sull'altra cosa
# che il giocatore lascia nel mondo, e passa dalla STESSA funzione
# (`_ancora_ricordo`): niente macchina nuova, la lettura `dove()` che c'era
# già agganciata a `_free_bench`, che c'è da sempre.
#
# LE TRE ASSERZIONI CHE CONTANO, e ognuna chiude un modo di sbagliare:
#  1. l'ordine (chi è qui ADESSO batte quel che è successo ieri);
#  2. il guinzaglio (l'ancora salta SPOSTA_MAX metri, non ottanta);
#  3. il ripiego (l'emozione AGGIUNGE, mai toglie: nessuno finisce per terra
#     per averti visto).
#
# LA VALVOLA DI TUTTO IL CASO è `_player = null` dove serve: senza Mochi in
# scena l'ancora della scena 3 non si sposta mai, quindi quel che si misura
# può venire SOLO dal ricordo del gesto.

func _la_panchina_che_hai_costruito(t) -> void:
	var mondo := _villaggio(t, 1)
	var vis = mondo["vis"]
	var r: Dictionary = mondo["righe"][0]
	var node: Node3D = r["node"]
	var casa := Vector3(0, 0, 0)
	# la panchina di sempre a otto metri da una parte, quella appena posata a
	# nove dall'altra: da casa vince la vecchia, e non c'è pareggio da
	# interpretare
	var vecchia := _panchina(t, Vector3(0, 0, -8.0))
	var nuova := _panchina(t, Vector3(0, 0, 9.0))
	(mondo["build"] as Node).set("pezzi", {"Panchina": [vecchia, nuova]})
	vis._player = null

	vis._ciclo_sonno(DT, 0.5)
	t.eq(vis._panchina_per(r, casa), vecchia,
			"chi non ti ha vista posare niente si siede dove si è sempre seduto")

	var id: int = int(r["ecs"])
	vis._ecs.osserva(id, vis._ecs.indice_verbo("costruisce"), nuova.global_position, -1)
	t.eq(vis._panchina_per(r, casa), nuova,
			"e chi ti ha vista posarla, quando ha voglia di sedersi, va a sedersi LÌ")

	# E IL CORPO CI VA DAVVERO, dalla recita di produzione — non dalla
	# funzione che ho appena provato. Senza questa riga `_recita` potrebbe
	# essere rimasta indietro e tutto il resto sarebbe verde lo stesso.
	vis._recita(r, node, vis._ensure_brain(r), "riposo", "day")
	t.eq(node.get("_routine_aux"), nuova,
			"e il corpo si incammina proprio verso quella: la scena esiste in partita")


## L'ORDINE: chi è qui ADESSO batte quel che è successo ieri.
##
## Le tre panchine sono messe perché le tre ancore diano tre risposte
## diverse: da casa vince R (a 8 m), dall'ancora spostata verso Mochi vince
## P, dall'ancora del ricordo vince Q. Se un giorno qualcuno invertisse i due
## rami di `_panchina_per`, il vicino andrebbe a sedersi accanto alla cosa
## che hai costruito ieri mentre oggi gli sei accanto — cioè la scena 3, che
## è la più leggibile delle due, sparirebbe senza che nessuno se ne accorga.
func _la_panchina_mette_prima_chi_c_e(t) -> void:
	var mondo := _villaggio(t, 1)
	var vis = mondo["vis"]
	var r: Dictionary = mondo["righe"][0]
	var casa := Vector3(0, 0, 0)
	var p := _panchina(t, Vector3(0, 0, 9.0))     # dalla parte di Mochi
	var q := _panchina(t, Vector3(12.0, 0, 0))    # dalla parte dell'opera
	var rr := _panchina(t, Vector3(0, 0, -8.0))   # la più vicina a casa
	(mondo["build"] as Node).set("pezzi", {"Panchina": [p, q, rr]})
	vis._player = null

	vis._ciclo_sonno(DT, 0.5)
	var id: int = int(r["ecs"])
	vis._ecs.osserva(id, vis._ecs.indice_verbo("costruisce"), Vector3(16.0, 0, 0), -1)
	t.eq(vis._panchina_per(r, casa), q,
			"PREMESSA: senza Mochi in giro, vince la panchina vicino a quel che ti ha vista posare")

	var mochi := t.stage(Node3D.new()) as Node3D
	mochi.global_position = Vector3(0, 0, 12.0)
	vis._player = mochi
	t.eq(vis._panchina_per(r, casa), p,
			"ma se adesso sei qui, vince la tua parte: l'oggi batte lo ieri")


## L'ANCORA RESTA CORTA, e il ripiego resta casa. Due garanzie in un banco
## solo, perché sono le due che rendono questa scena innocua: nessuno
## attraversa il villaggio per una cosa che ha visto, e nessuno sta PEGGIO
## per averti visto.
func _la_panchina_dell_opera_non_e_un_guinzaglio(t) -> void:
	var casa := Vector3(0, 0, 0)

	# (a) IL GUINZAGLIO. Una panchina posata a ottantasei metri non chiama
	#     nessuno: l'ancora salta SPOSTA_MAX e da lì quella è ancora a ottanta.
	var mondo := _villaggio(t, 1)
	var vis = mondo["vis"]
	var r: Dictionary = mondo["righe"][0]
	var sotto_casa := _panchina(t, Vector3(0, 0, -8.0))
	var laggiu := _panchina(t, Vector3(0, 0, 86.0))
	(mondo["build"] as Node).set("pezzi", {"Panchina": [sotto_casa, laggiu]})
	vis._player = null
	vis._ciclo_sonno(DT, 0.5)
	vis._ecs.osserva(int(r["ecs"]), vis._ecs.indice_verbo("costruisce"),
			Vector3(0, 0, 86.0), -1)
	t.eq(vis._free_bench(Vector3(0, 0, 86.0)), laggiu,
			"PREMESSA: con l'ancora libera vincerebbe la panchina di laggiù")
	t.eq(vis._panchina_per(r, casa), sotto_casa,
			"e invece resta quella di casa: l'ancora si sposta di sei metri, non di ottantasei")

	# (b) IL RIPIEGO. L'unica panchina del villaggio sta dalla parte opposta
	#     all'opera: dall'ancora spostata è fuori portata, e senza il ripiego
	#     il vicino si addormenterebbe per terra — cioè starebbe peggio per
	#     averti visto.
	var mondo2 := _villaggio(t, 1)
	var vis2 = mondo2["vis"]
	var r2: Dictionary = mondo2["righe"][0]
	var sola := _panchina(t, Vector3(0, 0, -13.0))
	(mondo2["build"] as Node).set("pezzi", {"Panchina": [sola]})
	vis2._player = null
	vis2._ciclo_sonno(DT, 0.5)
	vis2._ecs.osserva(int(r2["ecs"]), vis2._ecs.indice_verbo("costruisce"),
			Vector3(0, 0, 20.0), -1)
	t.eq(vis2._free_bench(Vector3(0, 0, VIS.SPOSTA_MAX)), null,
			"PREMESSA: dall'ancora dell'opera quella panchina è fuori portata")
	t.eq(vis2._panchina_per(r2, casa), sola,
			"e allora si ripiega su casa: l'emozione aggiunge, non toglie")


## L'ANCORA DEL RICORDO È UNA SOLA FUNZIONE, e serve tutte e due le scene.
##
## Non è un controllo di stile: la panchina e l'aiuola devono spostarsi con
## LA STESSA regola, o il giorno che qualcuno tara `SPOSTA_MAX` ne sposterà
## una sola. Qui si chiede lo stesso spostamento per due cose diverse e si
## pretende che i due punti abbiano la stessa distanza da casa — e che una
## cosa che non si è mai vista non sposti niente, bit per bit.
func _l_ancora_del_ricordo_e_una_sola(t) -> void:
	var mondo := _villaggio(t, 1)
	var vis = mondo["vis"]
	var r: Dictionary = mondo["righe"][0]
	var casa := Vector3(0, 0, 0)
	vis._ciclo_sonno(DT, 0.5)
	var id: int = int(r["ecs"])

	t.ok(vis._ancora_ricordo(r, casa, "fiore") == casa,
			"chi non ricorda niente resta a casa, ESATTO (fiore)")
	t.ok(vis._ancora_ricordo(r, casa, "casa") == casa,
			"chi non ricorda niente resta a casa, ESATTO (casa)")

	vis._ecs.osserva(id, vis._ecs.indice_verbo("annaffia"), Vector3(40.0, 0, 0), -1)
	vis._ecs.osserva(id, vis._ecs.indice_verbo("costruisce"), Vector3(0, 0, -40.0), -1)
	var a: Vector3 = vis._ancora_ricordo(r, casa, "fiore")
	var b: Vector3 = vis._ancora_ricordo(r, casa, "casa")
	t.ok(a != casa and b != casa, "due ricordi diversi spostano tutte e due le ancore")
	# …e le spostano IN DUE POSTI DIVERSI. Senza questa riga, una
	# `_ancora_ricordo` che ignorasse il proprio argomento e guardasse sempre
	# i fiori resterebbe verde su tutto il resto di questo caso.
	t.ok(a != b, "e le spostano da due parti diverse: la cosa che si chiede conta")
	t.almost(a.distance_to(casa), b.distance_to(casa),
			"e le spostano dello STESSO tanto: una regola sola, non due", 1e-6)
	t.almost(a.distance_to(casa), VIS.SPOSTA_MAX,
			"cioè di SPOSTA_MAX, che è il guinzaglio che non c'è", 1e-6)

	# una cosa che non esiste non sposta niente, e lo dice
	t.ok(vis._ancora_ricordo(r, casa, "spaghetti") == casa,
			"una cosa fuori tabella non sposta niente (e si lamenta)")


# ================================ 4. L'AIUOLA CHE HA VISTO (scena 4)

## Il Garden VERO, fuori dall'albero (il suo `_ready` vuole il villaggio
## intero) con le aiuole messe a mano nel suo dizionario. `bed_needing_water`
## resta la SUA funzione: la regola «quali aiuole hanno sete» non si copia.
func _orto(t, posti: Array) -> Array:
	var g = GARDEN.new()
	var nodi: Array = []
	for p in posti:
		var n := Node3D.new()
		t.stage(n)
		n.global_position = p
		g._beds[n] = {"stage": 1, "watered": false}
		nodi.append(n)
	return [g, nodi]


## LA SCENA 4. Le due aiuole hanno sete tutte e due: da casa vince quella a
## cinque metri; per chi ha visto Mochi annaffiare l'altra, vince l'altra —
## e Mochi torna all'orto e ritrova il proprio gesto, nello stesso punto,
## fatto da un altro.
func _l_aiuola_che_ha_visto(t) -> void:
	var mondo := _villaggio(t, 1)
	var vis = mondo["vis"]
	var r: Dictionary = mondo["righe"][0]
	var node: Node3D = r["node"]
	var casa := Vector3(0, 0, 0)
	var orto := _orto(t, [Vector3(0, 0, -5.0), Vector3(0, 0, 7.0)])
	vis._garden = orto[0]
	var vicina: Node3D = (orto[1] as Array)[0]
	var lontana: Node3D = (orto[1] as Array)[1]

	vis._ciclo_sonno(DT, 0.5)
	t.eq(vis._aiuola_da_curare(r, casa), vicina,
			"chi non ha visto niente annaffia l'aiuola più vicina a casa sua")

	var id: int = int(r["ecs"])
	vis._ecs.osserva(id, vis._ecs.indice_verbo("annaffia"),
			lontana.global_position, -1)
	t.eq(vis._aiuola_da_curare(r, casa), lontana,
			"chi ti ha vista annaffiare QUELLA, fra le assetate sceglie quella")

	# e il corpo ci va davvero, dalla recita di produzione
	vis._recita(r, node, vis._ensure_brain(r), "cura_giardino", "day")
	var meta: Vector3 = node.call("meta_cammino")
	t.ok(meta.distance_to(lontana.global_position) < 1.2,
			"e il corpo si incammina proprio lì (%s contro %s)"
					% [str(meta), str(lontana.global_position)])

	# L'ANCORA RESTA CORTA anche per un ricordo lontanissimo: sposta di
	# SPOSTA_MAX e non un metro di più. Un vicino che attraversa il villaggio
	# perché ti ha vista annaffiare dall'altra parte è un guinzaglio con un
	# altro nome — e con l'ancora libera ci si arriva senza scrivere una riga
	# in più, il che è precisamente il modo in cui questi guasti nascono.
	#
	# Il banco è costruito perché la differenza si veda: c'è un'aiuola
	# assetata a UN METRO dal ricordo lontano. Con l'ancora libera vincerebbe
	# lei (distanza 1) e il corpo camminerebbe ottantanove metri; col limite,
	# resta fuori portata e vince quella di casa.
	var mondo2 := _villaggio(t, 1)
	var vis2 = mondo2["vis"]
	var r2: Dictionary = mondo2["righe"][0]
	var orto2 := _orto(t, [Vector3(0, 0, -5.0), Vector3(0, 0, 89.0)])
	vis2._garden = orto2[0]
	var sotto_casa: Node3D = (orto2[1] as Array)[0]
	var laggiu: Node3D = (orto2[1] as Array)[1]
	vis2._ciclo_sonno(DT, 0.5)
	var id2: int = int(r2["ecs"])
	for _k in 4:
		vis2._ecs.osserva(id2, vis2._ecs.indice_verbo("semina"), Vector3(0, 0, 90.0), -1)
	t.eq((vis2._garden as Node).call("bed_needing_water", Vector3(0, 0, 90.0), 14.0), laggiu,
			"PREMESSA: con l'ancora libera vincerebbe l'aiuola di laggiù")
	t.eq(vis2._aiuola_da_curare(r2, casa), sotto_casa,
			"e invece resta quella di casa: l'ancora si sposta di sei metri, non di novanta")


## ANCHE QUI SI RIPIEGA SU CASA: se dall'ancora spostata non si vede
## nessun'aiuola, si torna a guardare da casa. Una conseguenza deve
## AGGIUNGERE, mai togliere — un vicino che per averti visto smette di
## annaffiare sarebbe il contrario esatto della scena.
func _l_aiuola_ripiega_su_casa(t) -> void:
	var mondo := _villaggio(t, 1)
	var vis = mondo["vis"]
	var r: Dictionary = mondo["righe"][0]
	var casa := Vector3(0, 0, 0)
	# una sola aiuola, a tredici metri e dalla parte sbagliata
	var orto := _orto(t, [Vector3(0, 0, -13.0)])
	vis._garden = orto[0]
	var sola: Node3D = (orto[1] as Array)[0]

	vis._ciclo_sonno(DT, 0.5)
	var id: int = int(r["ecs"])
	for _k in 4:
		vis._ecs.osserva(id, vis._ecs.indice_verbo("annaffia"), Vector3(0, 0, 20.0), -1)
	t.eq((vis._garden as Node).call("bed_needing_water", Vector3(0, 0, VIS.SPOSTA_MAX), 14.0), null,
			"PREMESSA: dall'ancora spostata quell'aiuola è fuori portata")
	t.eq(vis._aiuola_da_curare(r, casa), sola,
			"e allora si ripiega su casa: chi ti ha visto non smette di annaffiare")


## LA FATTIBILITÀ E LA RECITA GUARDANO LA STESSA AIUOLA.
##
## `_brain_ctx` decide se «cura_giardino» è un'azione POSSIBILE, `_recita`
## decide dove si va: se le due si facessero la domanda da punti diversi,
## esisterebbero aiuole che il motore dichiara raggiungibili e nessuno va ad
## annaffiare — o peggio, il contrario. Qui l'aiuola sta a diciannove metri
## da casa (fuori portata dalla porta di casa) ma a tredici dall'ancora
## spostata: la fattibilità DEVE dire sì.
func _la_fattibilita_guarda_la_stessa_aiuola(t) -> void:
	var mondo := _villaggio(t, 1)
	var vis = mondo["vis"]
	var r: Dictionary = mondo["righe"][0]
	var casa := Vector3(0, 0, 0)
	var orto := _orto(t, [Vector3(0, 0, 19.0)])
	vis._garden = orto[0]

	vis._ciclo_sonno(DT, 0.5)
	var id: int = int(r["ecs"])
	for _k in 4:
		vis._ecs.osserva(id, vis._ecs.indice_verbo("annaffia"), Vector3(0, 0, 25.0), -1)
	t.eq((vis._garden as Node).call("bed_needing_water", casa, 14.0), null,
			"PREMESSA: da casa quell'aiuola non si vede")
	t.ok(vis._aiuola_da_curare(r, casa) != null,
			"ma dall'ancora del ricordo sì")
	var ctx: Dictionary = vis._brain_ctx(r, "day")
	t.ok(bool(ctx.get("aiuola_da_annaffiare", false)),
			"e la FATTIBILITÀ lo sa: il motore non dichiara impossibile un gesto che il corpo saprebbe fare")


## IL PIANO GUARDA GLI STESSI POSTI CHE IL CORPO ANDRÀ A CAMMINARE.
##
## È la regola del cammino («il filo giudicato è il filo camminato») portata
## sui LUOGHI: il pianificatore decide se un gesto è ancora possibile — e se
## non lo è, manda quel vicino ad appendere un biglietto per Mochi. Se
## giudicasse un'aiuola e la recita ne raggiungesse un'altra, esisterebbe un
## vicino che va alla Lavagna a chiedere aiuto per un'aiuola che avrebbe
## saputo annaffiare da solo — e, peggio, il contrario: uno che si incammina
## verso un posto che il piano non ha mai controllato.
##
## Qui sono i posti a essere due, e il ricordo indica il secondo di
## entrambi: il piano deve indicare gli stessi.
func _il_piano_guarda_gli_stessi_posti(t) -> void:
	var mondo := _villaggio(t, 1)
	var vis = mondo["vis"]
	var r: Dictionary = mondo["righe"][0]
	var casa := Vector3(0, 0, 0)
	var a := _panchina(t, Vector3(0, 0, -8.0))
	var b := _panchina(t, Vector3(0, 0, 9.0))
	(mondo["build"] as Node).set("pezzi", {"Panchina": [a, b]})
	var orto := _orto(t, [Vector3(0, 0, -5.0), Vector3(0, 0, 7.0)])
	vis._garden = orto[0]
	var lontana: Node3D = (orto[1] as Array)[1]
	var mochi := t.stage(Node3D.new()) as Node3D
	mochi.global_position = Vector3(0, 0, 12.0)
	vis._player = mochi

	vis._ciclo_sonno(DT, 0.5)
	var id: int = int(r["ecs"])
	vis._ecs.osserva(id, vis._ecs.indice_verbo("annaffia"),
			lontana.global_position, -1)

	var luoghi: Array = vis._luoghi_del_piano(r, casa)
	var i_aiuola: int = (vis.PIANI.LUOGHI as Array).find("aiuola")
	var i_seduta: int = (vis.PIANI.LUOGHI as Array).find("seduta")
	var p_aiuola: Vector3 = (luoghi[i_aiuola] as Dictionary)["pos"]
	var p_seduta: Vector3 = (luoghi[i_seduta] as Dictionary)["pos"]
	t.ok(p_aiuola.distance_to(lontana.global_position) < 0.01,
			"il piano giudica PROPRIO l'aiuola che il corpo andrà ad annaffiare")
	t.ok(p_seduta.distance_to(b.global_position) < 0.01,
			"e PROPRIO la panchina su cui il corpo andrà a sedersi")
	# la controprova: senza il ricordo il piano guarda gli altri due, cioè
	# questo caso sa distinguere le due risposte
	var vergine := _villaggio(t, 1)
	var v2 = vergine["vis"]
	var r2: Dictionary = vergine["righe"][0]
	(vergine["build"] as Node).set("pezzi", {"Panchina": [a, b]})
	v2._garden = orto[0]
	v2._player = mochi
	v2._ciclo_sonno(DT, 0.5)
	var luoghi2: Array = v2._luoghi_del_piano(r2, casa)
	t.ok((luoghi2[i_aiuola] as Dictionary)["pos"].distance_to(lontana.global_position) > 1.0,
			"(e chi non ha visto niente ne guarda un'altra: le due risposte sono distinguibili)")


# ============================= 5. IL CUORE: IL GUSTO E LA PROMOZIONE

func _gira(vis, quanti: int, ore := 0.5) -> void:
	for _i in quanti:
		vis._ciclo_sonno(DT, ore)


## IL GUSTO ARRIVA DI LÀ. Senza questa riga tutto il motore delle tinte
## girerebbe su un gusto neutro — cioè il carattere non entrerebbe mai in
## quello che i vicini provano, e il sistema sarebbe indistinguibile da un
## dado (la lezione delle REAZIONI di Animo, che valevano 0.000000 per
## tutti).
func _il_gusto_arriva_di_la(t) -> void:
	var mondo := _villaggio(t, 1, false)
	var vis = mondo["vis"]
	var r: Dictionary = mondo["righe"][0]
	_gira(vis, VIS.FATTI_OGNI + 2)
	var atteso: PackedFloat64Array = GUSTO.da_dna(r["dna"], vis._ensure_brain(r).indole)
	var d: Dictionary = vis._ecs.debug_emozioni(int(r["ecs"]))
	var visto: PackedFloat64Array = d["gusto"]
	t.ok(visto == atteso,
			"il gusto del carattere arriva nel registro, tale e quale (%s contro %s)"
					% [str(visto), str(atteso)])
	var neutro := 0
	for i in visto.size():
		if visto[i] == 1.0:
			neutro += 1
	t.ok(neutro < visto.size(),
			"…e non è il neutro travestito: un gusto tutto a uno passerebbe la riga di sopra senza dire niente")


## L'INDOLE VIENE DAL CERVELLO, non dal genoma. A runtime il proprietario
## dell'indole è `VillagerBrain` — la deriva per i villaggi salvati prima che
## le indoli entrassero nel genoma, e `debug_quirk` scrive su un cervello
## vivo. Se lo specchio del gusto guardasse il genoma, una persona avrebbe
## due caratteri: uno per andare a letto e uno per commuoversi.
func _il_gusto_porta_l_indole_del_cervello(t) -> void:
	var mondo := _villaggio(t, 1, false)
	var vis = mondo["vis"]
	var r: Dictionary = mondo["righe"][0]
	var brain: RefCounted = vis._ensure_brain(r)
	# un genoma SENZA indole (i salvataggi vecchi) e un cervello che ce l'ha
	(r["dna"] as Dictionary).erase("indole")
	brain.indole = ["ordinato"]
	_gira(vis, VIS.FATTI_OGNI + 2)
	var d: Dictionary = vis._ecs.debug_emozioni(int(r["ecs"]))
	var vivo: PackedFloat64Array = d["gusto"]
	t.ok(vivo == GUSTO.da_dna(r["dna"], ["ordinato"]),
			"il gusto porta l'indole del CERVELLO")
	t.ok(vivo != GUSTO.da_dna(r["dna"]),
			"…e non quella (assente) del genoma: se le due combaciassero questo caso non proverebbe niente")


## NON SI RIFÀ A OGNI FRAME, E NON SI RIFÀ TUTTO INSIEME.
##
## Si misura sul comportamento, non sul contatore: si cambia il carattere di
## OTTO vicini nello stesso istante e si guarda a quale frame arriva di là il
## gusto nuovo di ciascuno.
##  · se si riproiettasse a ogni frame, arriverebbero tutti al primo;
##  · se non si riproiettasse mai, non arriverebbe nessuno;
##  · e se la cadenza non fosse SFALSATA, arriverebbero tutti nello stesso
##    frame — la spesa media sarebbe identica e il picco venti volte più
##    alto, cioè uno scatto ogni mezzo secondo nel villaggio più pieno, che è
##    l'unico posto in cui si nota.
func _il_gusto_non_si_rifa_a_ogni_frame(t) -> void:
	var mondo := _villaggio(t, 8, false)
	var vis = mondo["vis"]
	var righe: Array = mondo["righe"]
	_gira(vis, VIS.FATTI_OGNI + 2)   # il primo giro, così tutti hanno il loro

	# il salone di bellezza passa su tutti nello stesso istante
	for i in righe.size():
		var pesi: Dictionary = (righe[i]["dna"] as Dictionary).get("weights", {})
		pesi["garden"] = 0.21 + 0.07 * float(i)
	var arrivi: Array = []
	arrivi.resize(righe.size())
	arrivi.fill(-1)
	for k in VIS.FATTI_OGNI * 2:
		vis._ciclo_sonno(DT, 0.5)
		for i in righe.size():
			if int(arrivi[i]) >= 0:
				continue
			var r: Dictionary = righe[i]
			var atteso: PackedFloat64Array = GUSTO.da_dna(r["dna"],
					vis._ensure_brain(r).indole)
			var visto: PackedFloat64Array = vis._ecs.debug_emozioni(int(r["ecs"]))["gusto"]
			if visto == atteso:
				arrivi[i] = k
	var mancanti := 0
	var subito := 0
	var quando := {}
	var tardi := 0
	for i in arrivi.size():
		var q := int(arrivi[i])
		if q < 0:
			mancanti += 1
			continue
		quando[q] = int(quando.get(q, 0)) + 1
		if q == 0:
			subito += 1
		tardi = maxi(tardi, q)
	t.eq(mancanti, 0,
			"il carattere cambiato arriva di là per TUTTI entro due giri di fatti")
	t.ok(subito < righe.size(),
			"…ma non per tutti nel frame stesso: la riproiezione non gira a sessanta hertz (%d su %d)"
					% [subito, righe.size()])
	t.ok(quando.size() >= 3,
			"…e non arrivano nemmeno tutti insieme: la cadenza è SFALSATA (%d frame diversi su %d vicini)"
					% [quando.size(), righe.size()])
	var picco := 0
	for q in quando:
		picco = maxi(picco, int(quando[q]))
	t.ok(picco <= 3,
			"nel frame più affollato si riproiettano al massimo tre vicini su otto (%d)" % picco)
	t.ok(tardi <= VIS.FATTI_OGNI,
			"e l'ultimo non aspetta più di un giro di fatti (%d frame, tetto %d)"
					% [tardi, VIS.FATTI_OGNI])


## UNA PASSATA DI SFUGGITA NON DIVENTA UN RICORDO. È la regola per cui
## annaffiare in cerchio davanti a un vicino non serve a niente: il gesto
## gentile non è una moneta, e la moneta dei legami in questo gioco è
## un'altra.
func _una_passata_non_diventa_un_ricordo(t) -> void:
	var mondo := _villaggio(t, 1, false)
	var vis = mondo["vis"]
	var r: Dictionary = mondo["righe"][0]
	var brain: RefCounted = vis._ensure_brain(r)
	brain.memoria = []
	_gira(vis, 2)
	vis._ecs.osserva(int(r["ecs"]), vis._ecs.indice_verbo("annaffia"),
			Vector3(1, 0, 1), -1)
	_gira(vis, VIS.FATTI_OGNI * 2)
	t.eq((brain.memoria as Array).size(), 0,
			"un'occhiata sola non lascia niente: non si «carica» un vicino facendosi guardare")


## UNA PROMOZIONE AL GIORNO, e il contatore si azzera COL GIORNO.
##
## È l'unica cosa di tutta la Fase 4 che attraversa un riavvio, e passa da un
## canale che esiste già (`VillagerBrain.remember`, persistito, limitato a
## sei, con un consumatore che lo mette in scena senza parole). Senza il
## tetto giornaliero, un pomeriggio passato accanto a Mochi riempirebbe la
## memoria di sei righe uguali e cancellerebbe tutto quello che quel vicino
## si ricordava della propria vita.
func _una_promozione_al_giorno(t) -> void:
	var mondo := _villaggio(t, 1, false)
	var vis = mondo["vis"]
	var r: Dictionary = mondo["righe"][0]
	var brain: RefCounted = vis._ensure_brain(r)
	brain.memoria = []
	_gira(vis, 2)
	var id: int = int(r["ecs"])
	# un regalo: fatto a me, quindi pesa il doppio di un'occhiata
	vis._ecs.osserva(id, vis._ecs.indice_verbo("dona"), Vector3(2, 0, 2), id)
	_gira(vis, VIS.FATTI_OGNI + 2)
	t.eq((brain.memoria as Array).size(), 1,
			"quel che ti ha visto fare PER LUI gli resta addosso")
	t.eq(str((brain.memoria as Array)[0][0]), "amico",
			"…col nome della cosa, non con un numero")
	# ed è una parola che quel corpo sa davvero mostrare e dire: se fosse un
	# indice, o il nome di un VERBO, la nuvoletta uscirebbe col ripiego e la
	# voce balbetterebbe
	t.ok(VISITOR.LP_SIMBOLI.has(str((brain.memoria as Array)[0][0])),
			"ed è un simbolo che il corpo sa mostrare")
	t.ok(Chibiese.VOCAB.has(str((brain.memoria as Array)[0][0])),
			"e una parola che la voce sa dire")

	# altri gesti, tutto il resto della giornata: non se ne aggiunge nemmeno uno
	for k in 6:
		vis._ecs.osserva(id, vis._ecs.indice_verbo("cucina"),
				Vector3(float(k), 0, 3), id)
		_gira(vis, VIS.FATTI_OGNI + 2)
	t.eq((brain.memoria as Array).size(), 1,
			"e per tutto il resto della giornata resta UNA: la memoria di una persona non è un registratore")

	# domattina, un'altra
	vis._on_new_day(2)
	_gira(vis, VIS.FATTI_OGNI + 2)
	t.eq((brain.memoria as Array).size(), 2,
			"domattina però sì: il contatore si azzera col giorno")
	t.eq(str((brain.memoria as Array)[1][0]), "cibo",
			"…e stavolta è la cosa nuova")


# ================================ 6. IL PETTEGOLEZZO, IN SCENA (scena 2)

## Due corpi che si ascoltano, in un registro vero e in scena (`_run_chat`
## chiama `get_tree()`).
func _due_che_chiacchierano(t) -> Dictionary:
	var vis = t.stage(Registro.new())
	var righe: Array = []
	var corpi: Array = []
	for i in 2:
		var v = Chiacchierone.new()
		v.dna = DNA.generate(8800 + i * 53)
		v.mode = "resident"
		t.stage(v)
		v._enter_state("r_idle")
		v._timer = 9999.0
		v.global_position = Vector3(float(i) * 1.2, 0, 0)
		var r := {"node": v, "label": "Voce%d" % i, "dna": v.dna,
				"cell": Vector2i(i, 0), "species": "chibi"}
		vis._residents.append(r)
		righe.append(r)
		corpi.append(v)
		var b: RefCounted = vis._ensure_brain(r)
		b.quirk = ""
		b.memoria = []
	_gira(vis, 2)
	return {"vis": vis, "righe": righe, "corpi": corpi}


## LA NOTIZIA DIVENTA IL TEMA — ed è l'unica cosa della Fase 4 che si legge a
## schermo.
##
## La sonda è «pesce», e non è una scelta di comodo: fra i temi che il
## momento può dettare («pioggia», «fuoco», «dormire», «cibo», «amico»,
## «fiore», «felice») quel concetto **non compare**. Se esce dalla bocca di
## un vicino, ci può essere arrivato in un modo solo. E questo caso è anche
## il guardiano della fonte unica dei simboli: la tabella che c'era prima
## (`CHAT_TOPICS`) aveva sette chiavi e «pesce» non era una di quelle —
## chiunque la reintroducesse vedrebbe il tema cadere sul ripiego «amico», e
## questa riga diventare rossa.
func _la_notizia_diventa_il_tema(t) -> void:
	var scena := _due_che_chiacchierano(t)
	var vis = scena["vis"]
	var righe: Array = scena["righe"]
	var a: Node3D = (scena["corpi"] as Array)[0]
	var b: Node3D = (scena["corpi"] as Array)[1]
	var ida: int = int((righe[0] as Dictionary)["ecs"])
	var idb: int = int((righe[1] as Dictionary)["ecs"])

	vis._ecs.osserva(ida, vis._ecs.indice_verbo("pesca"), Vector3(4, 0, -6), -1)
	vis._run_chat(a, b)

	var dette: Array = a.get("dette")
	t.ok(dette.size() >= 1, "chi ha visto qualcosa dice qualcosa")
	t.eq(str((dette[0] as Array)[0]), "pesce",
			"e dice PROPRIO quello che ha visto: la notizia detta il tema")
	var bolle: Array = a.get("bolle")
	t.ok(bolle.size() >= 1 and str(bolle[0]) == str(VISITOR.LP_SIMBOLI["pesce"]),
			"e nella nuvoletta esce il simbolo di quel concetto, preso dalla tabella del CORPO")

	# LA NOTIZIA È ARRIVATA DAVVERO. Il simbolo non è un ornamento: nel grafo
	# dell'altro adesso c'è la stessa cosa, marchiata «me l'hanno detto».
	var suoi: Array = vis._ecs.debug_grafo(idb)["ricordi"]
	var sentiti := 0
	var forza := -1
	for riga in suoi:
		if int((riga as Dictionary)["cosa"]) == int(vis._ecs.C_PESCE) \
				and (int((riga as Dictionary)["bandiere"]) & int(vis._ecs.R_SENTITO)) != 0:
			sentiti += 1
			forza = int((riga as Dictionary)["intensita"])
	t.eq(sentiti, 1,
			"e all'altro la cosa è arrivata davvero, marchiata come sentita dire")

	# …E SMORZATA CON LA COSTANTE DEL VILLAGGIO, non con una sua.
	#
	# `test_pettegolezzo` prova che `racconta` smorza; questa è l'unica
	# asserzione di tutta la suite che prova che **il gioco le passa
	# `Villaggio.SMORZAMENTO`**. Senza, `_run_chat` potrebbe passare 1.0 (una
	# voce che pesa quanto averlo visto) o un numero inventato, e resterebbe
	# tutto verde: la fonte unica sarebbe dichiarata in un commento e in
	# nessun altro posto.
	t.eq(forza, int(255.0 * VILLAGGIO.SMORZAMENTO + 0.5),
			"e arriva smorzata con la costante del villaggio (%d), non con una inventata qui" % forza)


## E POI NON SE NE PARLA PIÙ. Una notizia si racconta una volta: se la stessa
## coppia continuasse a ripassarsela, il pettegolezzo sarebbe un disco rotto
## invece che una cosa colta al volo.
func _e_poi_non_se_ne_parla_piu(t) -> void:
	var scena := _due_che_chiacchierano(t)
	var vis = scena["vis"]
	var righe: Array = scena["righe"]
	var a: Node3D = (scena["corpi"] as Array)[0]
	var b: Node3D = (scena["corpi"] as Array)[1]
	var ida: int = int((righe[0] as Dictionary)["ecs"])

	vis._ecs.osserva(ida, vis._ecs.indice_verbo("pesca"), Vector3(4, 0, -6), -1)
	vis._run_chat(a, b)
	vis._run_chat(a, b)
	vis._run_chat(a, b)
	var dette: Array = a.get("dette")
	var quante_volte := 0
	for d in dette:
		if str((d as Array)[0]) == "pesce":
			quante_volte += 1
	t.eq(quante_volte, 1,
			"la stessa notizia si racconta UNA volta sola, non a ogni incontro (%d chiacchiere)"
					% dette.size())
	t.ok(dette.size() >= 2,
			"…e le chiacchiere dopo ci sono state comunque: il silenzio è il comportamento normale, non l'assenza di chiacchiere")


# ========================================= 7. IL RITMO VIENE DAL GIORNO

## LE MEZZE VITE SI DERIVANO DAL CICLO DEL GIORNO. Il C++ ha un valore di
## partenza che vale lo stesso conto — mezza giornata — e un default che
## combacia per caso è il modo esatto in cui due numeri divorziano: qui il
## giorno dura dieci minuti, e i ricordi devono durarne cinque senza che
## nessuno vada a cercare un 120 nascosto in un header.
func _le_mezze_vite_vengono_dal_giorno(t) -> void:
	var mondo := _villaggio(t, 1, false)
	var vis = mondo["vis"]
	var orologio = t.stage(Orologio.new())
	orologio.set("cycle_seconds", 600.0)
	vis._daynight = orologio
	_gira(vis, 2)
	t.almost(float(vis._ecs.debug_ritmo()["mezza_vita"]), 300.0,
			"col giorno da dieci minuti, i ricordi ne durano cinque", 1e-9)
