extends RefCounted
## I GESTI VERI — la prova che il libro mastro degli affetti riceve gesti
## di gente, non broadcast.
##
## ============================================================
## IL DIFETTO CHE QUESTO FILE TIENE CHIUSO (misurato, non temuto)
## ============================================================
## `Lavori._gesto_verso_tutti(chi, tipo)` scriveva UNA RIGA IDENTICA da una
## persona verso OGNI altro residente: stesso tipo, stesso giorno, stesso
## peso. Lo facevano la guardia («veglia», 0,80) e il cuoco («piatto»,
## 0,70). Rifatto il conto su 240 giorni x 6 semi:
##
##  · `conto(guardia, cuoco)` cresceva di 1,14 al giorno contro 0,44 verso
##    chiunque altro. Non era un pareggio: era un DOMINIO, 2,6 a 1.
##  · prima coppia al giorno 3, sempre guardia+cuoco, a 3/6/12/28 residenti;
##  · UNA SOLA coppia in tutta la partita: per tutti gli altri il massimo
##    era la guardia, che non ricambiava nessuno. **Un solo incarico
##    assegnato sterilizzava gli affetti dell'intero villaggio.**
##
## `MARGINE_ELEZIONE` non poteva fermarlo: è una guardia contro i PAREGGI,
## e contro un dominio un margine non serve.
##
## ============================================================
## PERCHÉ QUESTE PROVE SONO VIVE E NON UN CONTROLLO SUL SORGENTE
## ============================================================
## Il test che c'era prima cercava il letterale `"veglia"` dentro
## `Lavori.gd`: sarebbe rimasto verde anche con quel nome citato solo in un
## commento, e verde è rimasto per tutto il tempo in cui il broadcast
## sterilizzava il villaggio. Qui invece si monta un villaggio finto ma
## VIVO — case vere in posizioni vere, la `Veglia` vera, l'`Affetti` vero
## nel suo gruppo — si fanno passare le notti facendo girare il codice del
## gioco, e si LEGGE il libro mastro che ne esce.
##
## L'unica cosa che il banco salta è l'animazione della ronda (il giro di
## `_process` che accende una lanterna ogni nove secondi): `_tappa_i` lo si
## porta a mano fino a `_tappe.size()`, che è dove `_process` lo porta ogni
## notte. Ma `_test_una_notte_col_process` fa girare anche quello, almeno
## una volta, così nessuno può spostare quel conteggio senza accorgersene.

const AFF := preload("res://scenes/npc/Affetti.gd")
const VEGLIA := preload("res://scenes/npc/Veglia.gd")
const LAVORI := preload("res://scenes/npc/Lavori.gd")
const COOKING := preload("res://scenes/interact/Cooking.gd")
const INVENTORY := preload("res://scenes/ui/Inventory.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")


func run(t) -> void:
	_test_una_notte_col_process(t)
	_test_due_destinatari_due_conti(t)
	_test_le_date_sono_disgiunte(t)
	_test_l_ordine_non_decide(t)
	_test_la_geografia_decide(t)
	_test_la_resa_decide(t)
	_test_il_piatto_porta_il_nome(t)
	_test_il_villaggio_e_vivo(t)


# ============================================================ le finte parti
# Stanno qui e non in un file a parte perché sono il BANCO, non il gioco: la
# regola del progetto è che i test non ricopino mai la logica: infatti qui
# non c'è nessuna decisione. `FintiLavori` inoltra a `Lavori.resa/quanti`
# VERE (la resa è una leva del giocatore e dev'essere quella del gioco),
# `FintiVicini` è solo l'anagrafe, `FintoBuild` solo l'elenco delle luci.


class FintoGiorno extends Node3D:
	var day := 1
	var time := 0.0


class FintoCorpo extends Node3D:
	## la casa che `Veglia._porte_dei_vicini` interroga: chiavi vere
	## (`bed`/`cell`/`front`), come le scrive `Visitors._make_house`
	var _house := {}
	var mangiato := 0
	func face_towards(_p: Vector3) -> void:
		pass
	func mangia(prop: Node3D, _c: Color, _w: bool, _l: bool) -> void:
		mangiato += 1
		if is_instance_valid(prop):
			prop.queue_free()
	func speak(_frasi: Array, _faccia: String) -> void:
		pass
	func celebrate() -> void:
		pass
	func _spawn_heart() -> void:
		pass
	func is_hidden() -> bool:
		return false


## I canali che la coreografia dell'offerta scrive su Mochi. `pour` e `joy`
## sono BERSAGLI DI TWEEN: senza la proprietà il tween muore in partenza e
## il callback col gesto — che sta in fondo alla catena — non scatta mai.
class FintaMochi extends Node3D:
	var _yaw := 0.0
	var pour := 0.0
	var joy := 0.0
	func hold_offer(_acceso: bool) -> void:
		pass


class FintiVicini extends Node:
	var _residents: Array = []
	var _animi := {}
	var gradino := "lavoro"
	var cuccioli := {}
	func e_cucciolo(label: String) -> bool:
		return bool(cuccioli.get(label, false))
	func _nome_da_label(label: String) -> String:
		for r in _residents:
			if str((r as Dictionary).get("label", "")) == label:
				return str(((r as Dictionary).get("dna", {}) as Dictionary).get("name", ""))
		return label
	func animo_di(_label: String) -> String:
		return gradino
	func sogno_di(_label: String) -> String:
		return ""
	func dona_drive(_l: String, _d: String, _q: float, _pav := 0.0) -> void:
		pass
	func ricorda_per(_l: String, _t: String, _a: String, _q: float) -> void:
		pass
	func lega_vicini(_a: String, _b: String, _f: float) -> void:
		pass


class FintoBuild extends Node3D:
	var luci: Array = []          # i Lampioni che il giocatore ha posato
	func get_placed_by_name(nome: String) -> Array:
		return luci if nome == "Lampione" else []
	func request_save() -> void:
		pass


class FintiLavori extends Node:
	const L := preload("res://scenes/npc/Lavori.gd")
	var guardia := ""
	func chi_fa(lavoro: String) -> String:
		return guardia if lavoro == "guardia" else ""
	## la resa È quella del gioco: è la leva della scala della ribellione,
	## e un numero ricopiato qui renderebbe il test cieco a una taratura
	func resa(gradino: String, sogno := "", lavoro := "") -> float:
		return L.resa(gradino, sogno, lavoro)
	func quanti(n_pieno: int, r: float) -> int:
		return L.quanti(n_pieno, r)


class FintiLegami extends Node:
	var crescite := {}
	func _ready() -> void:
		add_to_group("legami")
	func crescita(nome: String) -> float:
		return float(crescite.get(nome, 1.0))


# ============================================================ il banco
# Statico apposta: anche `test_affetti` monta questo villaggio, e due copie
# dello stesso banco si scollano in silenzio come due copie di una tabella.

## Le case, distanziate PIÙ di `RAGGIO_LUCE`: su una fila più fitta un solo
## lampione ne spegnerebbe due, e la prova della geografia direbbe una cosa
## per l'altra senza fallire.
const NOMI := ["Anice", "Basilio", "Cedro", "Dalia", "Elmo"]
const PASSO := 8.0


## Un villaggio finto ma vivo: cinque case in fila, la guardia in fondo alla
## fila (la prima porta del giro è la sua). Ritorna i pezzi da pilotare.
static func banco(t, quanti_vicini := 5) -> Dictionary:
	var cont := Node.new()
	cont.name = "Villaggio"
	t.stage(cont)

	var dn := FintoGiorno.new()
	dn.name = "DayNight"
	cont.add_child(dn)
	var vis := FintiVicini.new()
	vis.name = "Visitors"
	cont.add_child(vis)
	var bld := FintoBuild.new()
	bld.name = "BuildSystem"
	cont.add_child(bld)
	var lav := FintiLavori.new()
	lav.name = "Lavori"
	cont.add_child(lav)

	for i in quanti_vicini:
		var corpo := FintoCorpo.new()
		corpo.name = "Corpo%d" % i
		cont.add_child(corpo)
		var p := Vector3(PASSO * float(i), 0.0, 0.0)
		corpo.global_position = p
		corpo._house = {"cell": Vector2i(int(p.x), int(p.z)), "front": p}
		vis._residents.append({"label": str(NOMI[i]), "node": corpo,
				"dna": {"name": str(NOMI[i])}, "friend": 0})
	lav.guardia = str(NOMI[0])

	var aff := Node.new()
	aff.set_script(AFF)
	aff.name = "Affetti"
	cont.add_child(aff)
	var veg := Node3D.new()
	veg.set_script(VEGLIA)
	veg.name = "Veglia"
	cont.add_child(veg)
	# il cablaggio vero di `Veglia` è differito (call_deferred nel _ready):
	# in un test sincrono non scatterebbe mai, quindi si posa a mano
	veg.set("_daynight", dn)
	veg.set("_visitors", vis)
	veg.set("_build", bld)
	veg.set("_lavori", lav)
	return {"cont": cont, "dn": dn, "vis": vis, "bld": bld, "lav": lav,
			"aff": aff, "veg": veg}


## Una notte intera: la ronda parte davvero (chi ha l'incarico, il suo
## gradino, la resa vera, le porte ordinate) e al mattino il rendiconto
## scrive nel libro mastro. Ritorna il nome di chi ha ricevuto la riga.
static func notte(b: Dictionary) -> String:
	var veg = b["veg"]
	veg.call("debug_ronda")
	# dove `_process` porta `_tappa_i` ogni notte: in fondo al giro
	veg.set("_tappa_i", (veg.get("_tappe") as Array).size())
	var chi: String = veg.call("chi_ha_vegliato", veg.get("_porte"),
			veg.get("_tappa_i"), veg.call("luci_costruite"))
	veg.call("rendiconto_del_mattino")
	return chi


static func domani(b: Dictionary) -> void:
	var dn = b["dn"]
	dn.day = int(dn.day) + 1


## Un Lampione posato dal giocatore davanti a una porta.
static func accendi_lampione(b: Dictionary, dove: Vector3) -> Node3D:
	var l := Node3D.new()
	l.name = "Lampione"
	(b["cont"] as Node).add_child(l)
	l.global_position = dove
	(b["bld"] as Node).luci.append(l)
	return l


static func righe_di(b: Dictionary) -> Array:
	return (b["aff"] as Node).get("_righe") as Array


# ==================================================== 0. la notte col _process

## LA NOTTE VERA, dall'ora della ronda al rendiconto, facendo girare
## `_process`. È l'unica prova che `_tappa_i` avanza davvero e che le
## lanterne si accendono: tutte le altre lo danno per buono e portano
## `_tappa_i` a mano, per non costruire mille lanterne di carta.
func _test_una_notte_col_process(t) -> void:
	var b := banco(t)
	var veg = b["veg"]
	var dn = b["dn"]
	dn.time = VEGLIA.ORA_RONDA
	# il primo giro fa partire la ronda; poi una tappa per chiamata (il
	# passo è di nove secondi, il delta qui è più lungo apposta)
	for i in 12:
		veg.call("_process", 10.0)
	t.ok(int(veg.get("_tappa_i")) > 0, "la ronda cammina davvero: le tappe avanzano")
	t.eq(int(veg.get("_tappa_i")), (veg.get("_tappe") as Array).size(),
			"…e in una notte intera arriva in fondo al giro")
	t.ok((veg.get("_lanterne") as Array).size() > 0,
			"…accendendo lanterne vere, una per tappa")
	t.eq((veg.get("_porte") as Array).size(), NOMI.size(),
			"le porte sono quelle dei vicini, una per casa")

	var esito = veg.call("rendiconto_del_mattino")
	t.ok(not (esito as Dictionary).is_empty(), "il mattino porta il suo rendiconto")
	var righe := righe_di(b)
	t.eq(righe.size(), 1,
			"UNA riga sola nel libro mastro per una notte di veglia"
			+ " (col broadcast erano %d, una per residente)" % (NOMI.size() - 1))
	t.eq(str((righe[0] as Dictionary).get("t", "")), "veglia",
			"…ed è del tipo giusto")
	t.eq(str((righe[0] as Dictionary).get("a", "")), NOMI[0],
			"…intestata a chi ha l'incarico, col NOME (non la label)")
	t.eq(str((righe[0] as Dictionary).get("b", "")), NOMI[NOMI.size() - 1],
			"…e verso l'ULTIMA porta raggiunta, quella che sarebbe rimasta al buio")


# ============================================ 1. due destinatari, due conti

## IL CUORE DELLA RIPARAZIONE. Prima, `conto(guardia, X)` era identico al
## centesimo per ogni X, e `il_piu_caro` tornava ["", 0.0]: nessun eletto,
## nessuna coppia, per sempre. Ora la luce che il giocatore posa sposta la
## riga su un'altra porta, i conti si separano, e qualcuno viene eletto.
func _test_due_destinatari_due_conti(t) -> void:
	var b := banco(t)
	var ricevuti := {}
	for giorno in 60:
		if giorno == 30:
			# a metà partita il giocatore illumina la casa in fondo alla fila
			accendi_lampione(b, Vector3(PASSO * float(NOMI.size() - 1), 0, 0))
		var chi := notte(b)
		if chi != "":
			ricevuti[chi] = int(ricevuti.get(chi, 0)) + 1
		domani(b)

	var righe := righe_di(b)
	var destinatari := {}
	for r in righe:
		destinatari[str((r as Dictionary).get("b", ""))] = true
	t.ok(destinatari.size() >= 2,
			"la guardia ha vegliato su PIÙ DI UNA persona in due mesi (%d)"
			% destinatari.size())

	# nessuna coppia di destinatari pareggia: il pareggio era la malattia
	var oggi := int((b["dn"] as Node3D).get("day"))
	var elenco: Array = destinatari.keys()
	for i in elenco.size():
		for j in range(i + 1, elenco.size()):
			var ca := AFF.conto(righe, NOMI[0], str(elenco[i]), oggi)
			var cb := AFF.conto(righe, NOMI[0], str(elenco[j]), oggi)
			t.ok(absf(ca - cb) > 0.01,
					"per la guardia, %s e %s NON contano uguale (%.3f contro %.3f)"
					% [elenco[i], elenco[j], ca, cb])

	var caro := AFF.il_piu_caro(righe, NOMI[0], NOMI, oggi)
	t.ok(str(caro[0]) != "",
			"…e qualcuno viene ELETTO davvero (col broadcast: nessuno, mai)")
	t.ok(float(caro[1]) > 0.0, "…con un conto vero addosso")


# ============================================ 2. le date sono disgiunte

## L'INVARIANTE CHE RENDE IMPOSSIBILI I PAREGGI, e la trappola che prende
## un broadcast reintrodotto IL PRIMO GIORNO: un autore, in un giorno, non
## può scrivere lo stesso gesto pesante verso due persone diverse. Se
## qualcuno rimette un giro «verso tutti», due date coincidono e questa
## prova diventa rossa prima ancora che il villaggio abbia una coppia.
func _test_le_date_sono_disgiunte(t) -> void:
	var b := banco(t)
	for giorno in 40:
		if giorno == 12:
			accendi_lampione(b, Vector3(PASSO * float(NOMI.size() - 1), 0, 0))
		if giorno == 26:
			accendi_lampione(b, Vector3(PASSO * float(NOMI.size() - 2), 0, 0))
		notte(b)
		domani(b)

	var righe := righe_di(b)
	t.ok(righe.size() >= 3, "in quaranta notti il libro mastro si è riempito (%d righe)"
			% righe.size())
	# per ogni (autore, tipo pesante): le date verso destinatari diversi
	# non si toccano mai
	var per_autore := {}
	for r in righe:
		var riga := r as Dictionary
		if absf(float(AFF.GESTI.get(str(riga.get("t", "")), 0.0))) < AFF.PESO_VERO:
			continue
		var k := "%s|%s" % [riga.get("a", ""), riga.get("t", "")]
		if not per_autore.has(k):
			per_autore[k] = {}
		var per_giorno: Dictionary = per_autore[k]
		var g := int(riga.get("d", 0))
		if per_giorno.has(g):
			t.ok(false, "%s ha scritto DUE righe '%s' lo stesso giorno (%d): verso %s e %s"
					% [riga.get("a", ""), riga.get("t", ""), g,
					per_giorno[g], riga.get("b", "")])
		per_giorno[g] = str(riga.get("b", ""))
	t.ok(true, "nessun autore ha scritto lo stesso gesto pesante a due"
			+ " persone nello stesso giorno")


# ============================================ 3. l'ordine non decide

## L'ORDINE DELL'ARRAY NON DECIDE NIENTE. `_residents` è ordinato per
## arrivo: se fosse lui a scegliere il destinatario, il libro mastro
## registrerebbe l'anzianità di residenza travestita da affetto — ed è
## esattamente ciò che faceva il `>` stretto di `il_piu_caro` sui conti in
## pareggio del broadcast.
func _test_l_ordine_non_decide(t) -> void:
	var righe_per_ordine: Array = []
	for prova in 2:
		var b := banco(t)
		if prova == 1:
			# stessa notte, stesso villaggio, anagrafe rovesciata
			var vis = b["vis"]
			var giu: Array = (vis.get("_residents") as Array).duplicate()
			giu.reverse()
			vis.set("_residents", giu)
		accendi_lampione(b, Vector3(PASSO * float(NOMI.size() - 1), 0, 0))
		notte(b)
		var uscite: Array = []
		for r in righe_di(b):
			uscite.append("%s>%s:%s" % [(r as Dictionary).get("a", ""),
					(r as Dictionary).get("b", ""), (r as Dictionary).get("t", "")])
		uscite.sort()
		righe_per_ordine.append(uscite)
	t.eq(str(righe_per_ordine[0]), str(righe_per_ordine[1]),
			"rovesciando l'anagrafe la notte scrive le STESSE righe:"
			+ " a decidere è la geografia, non chi è arrivato prima")
	t.ok((righe_per_ordine[0] as Array).size() == 1,
			"…ed è sempre una riga sola")


# ============================================ 4a. la geografia decide

## LA PRIMA LEVA DEL GIOCATORE: un lampione. Illuminare la casa che
## riceveva la riga sposta il gesto su un'altra porta — e se il villaggio è
## tutto illuminato, la guardia non ha vegliato su nessuno che ne avesse
## bisogno e il libro mastro TACE. Il silenzio è il comportamento normale.
func _test_la_geografia_decide(t) -> void:
	var b := banco(t)
	var senza := notte(b)
	t.eq(senza, NOMI[NOMI.size() - 1],
			"al buio la riga va all'ultima porta del giro")

	domani(b)
	accendi_lampione(b, Vector3(PASSO * float(NOMI.size() - 1), 0, 0))
	var con_luce := notte(b)
	t.ok(con_luce != senza,
			"un lampione davanti a quella porta sposta la riga su un'altra (%s -> %s)"
			% [senza, con_luce])
	t.eq(con_luce, NOMI[NOMI.size() - 2], "…quella prima nel giro")

	# il giocatore illumina TUTTO: nessuno era al buio, quindi silenzio
	for i in NOMI.size():
		accendi_lampione(b, Vector3(PASSO * float(i), 0, 0))
	domani(b)
	var quante_prima := righe_di(b).size()
	var muto := notte(b)
	t.eq(muto, "", "col villaggio tutto illuminato la veglia non elegge nessuno")
	t.eq(righe_di(b).size(), quante_prima,
			"…e non scrive nessuna riga: il silenzio è il comportamento normale")


# ============================================ 4b. la resa decide

## LA SECONDA LEVA: quanto rancore ha addosso chi veglia. Un guardiano
## svogliato si ferma a metà giro, e la riga la riceve chi sta a metà fila.
## È la stessa `Lavori.resa` che regola legna e piatti — qui non è
## ricopiata, è chiamata.
func _test_la_resa_decide(t) -> void:
	var b := banco(t)
	var sereno := notte(b)
	domani(b)
	(b["vis"] as Node).set("gradino", "svogliato")
	var svogliato := notte(b)
	t.ok(svogliato != "", "un guardiano svogliato veglia comunque su qualcuno")
	t.ok(svogliato != sereno,
			"…ma su un'altra porta: il giro si ferma prima (%s invece di %s)"
			% [svogliato, sereno])

	domani(b)
	(b["vis"] as Node).set("gradino", "rifiuto")
	var quante := righe_di(b).size()
	var in_rivolta := notte(b)
	t.eq(in_rivolta, "", "dal rifiuto in poi non esce proprio: nessuna ronda")
	t.eq(righe_di(b).size(), quante, "…e nessuna riga nel libro mastro")


# ============================================ 6. il piatto

## IL PIATTO PORTA IL NOME DI CHI L'HA CUCINATO, e la riga nasce al MORSO —
## non in cucina. Qui girano il ricettario vero, le Tasche vere e la
## consegna vera di `Visitors.offer_item`, tween compreso (la riga sta
## DENTRO il callback della ciotola che arriva: senza farlo scattare si
## proverebbe un pezzo di codice che in partita non è mai quello che gira).
func _test_il_piatto_porta_il_nome(t) -> void:
	var b := _banco_cucina(t)
	if b.is_empty():
		return
	var cooking = b["cooking"]
	var inv = b["inv"]
	var vis = b["vis"]
	var aff = b["aff"]

	# --- 1. il cuoco del registro cucina, e firma la ciotola
	cooking.set("pantry", {"carota": 8, "bacca": 6})
	var piatto := str(cooking.call("cook_by_villager", "Anice"))
	t.ok(piatto != "", "il cuoco di turno prepara qualcosa (%s)" % piatto)
	var scorta: Array = inv.get("dishes")
	t.eq(scorta.size(), 1, "…e la porzione finisce nelle Tasche")
	if scorta.is_empty():
		return
	t.eq(str((scorta[0] as Dictionary).get("cuoco", "")), "Anice",
			"…col nome di chi l'ha cucinata dentro")

	# --- 2. il salvataggio: la firma sopravvive al giro dal disco
	var salvato: Dictionary = inv.call("save_extra")
	var testo := JSON.stringify(salvato)
	var riletto: Dictionary = JSON.parse_string(testo)
	inv.call("load_extra", riletto)
	var dopo: Array = inv.get("dishes")
	t.eq(dopo.size(), 1, "…e la porzione c'è ancora dopo il giro dal disco")
	var primo: Dictionary = dopo[0] if not dopo.is_empty() else {}
	t.eq(str(primo.get("cuoco", "")), "Anice",
			"la firma del cuoco sopravvive a salva-e-ricarica (inv_dishes)")

	# --- 3. la consegna VERA: Tasche -> take_gift -> offer_item -> morso
	var quante_prima := (aff.get("_righe") as Array).size()
	_consegna(t, b, 2)                      # a Cedro
	var righe: Array = aff.get("_righe")
	t.eq(righe.size(), quante_prima + 1, "il morso scrive UNA riga")
	# ⚠️ UNA PROVA ROSSA NON DEVE ANDARE IN ERRORE. Senza questa guardia, il
	# giorno in cui la riga non arriva l'indice `-1` manda la funzione in
	# `SCRIPT ERROR` e le asserzioni che seguono NON GIRANO — le più
	# interessanti, per giunta: il progetto ha già pagato una volta il fatto
	# che un errore a runtime interrompe un test in silenzio.
	var ultima: Dictionary = righe[righe.size() - 1] if not righe.is_empty() else {}
	t.eq(str(ultima.get("a", "")), "Anice", "…dal cuoco che l'ha preparata")
	t.eq(str(ultima.get("b", "")), "Cedro", "…a chi il GIOCATORE ha servito")
	t.eq(str(ultima.get("t", "")), "piatto", "…ed è un piatto")
	t.eq(int((b["corpi"] as Array)[2].mangiato), 1, "…e il vicino l'ha mangiato davvero")

	# --- 4. i quattro silenzi
	cooking.set("pantry", {"carota": 8, "bacca": 6})
	cooking.call("cook_by_villager", "")     # il piatto del GIOCATORE
	quante_prima = (aff.get("_righe") as Array).size()
	_consegna(t, b, 3)
	t.eq((aff.get("_righe") as Array).size(), quante_prima,
			"il piatto cucinato dal giocatore non scrive nulla:"
			+ " non si comprano le amicizie degli altri")

	cooking.set("pantry", {"carota": 8, "bacca": 6})
	cooking.call("cook_by_villager", "Anice")
	quante_prima = (aff.get("_righe") as Array).size()
	_consegna(t, b, 0)                       # ad Anice, cioè al cuoco stesso
	t.eq((aff.get("_righe") as Array).size(), quante_prima,
			"il cuoco che si mangia il proprio piatto non lega nessuno")

	cooking.set("pantry", {"carota": 8, "bacca": 6})
	cooking.call("cook_by_villager", "Anice")
	(b["leg"] as Node).set("crescite", {"Dalia": 0.4})   # Dalia è un cucciolo
	quante_prima = (aff.get("_righe") as Array).size()
	_consegna(t, b, 3)
	t.eq((aff.get("_righe") as Array).size(), quante_prima,
			"un cucciolo non riceve righe d'affetto: non è uno strumento")
	(b["leg"] as Node).set("crescite", {})

	# un TESORO non si cucina e non lega nessuno. Dalle Tasche passa anche
	# roba che non è cibo, e il campo `kind` è l'unica cosa che li distingue
	var id_tesoro := str(INVENTORY.TREASURES.keys()[0])
	inv.call("add_treasure", id_tesoro, 1)
	quante_prima = (aff.get("_righe") as Array).size()
	var regalo: Dictionary = inv.call("take_gift",
			{"id": id_tesoro, "kind": "treasure"})
	t.ok(not regalo.is_empty(), "il tesoro esce dalle Tasche")
	t.eq(str(regalo.get("kind", "")), "treasure", "…e si dichiara tesoro")
	vis.call("offer_item", (vis.get("_residents") as Array)[1], regalo)
	_scatta_i_tween(t)
	t.eq((aff.get("_righe") as Array).size(), quante_prima,
			"un tesoro non lega nessuno: una conchiglia non si cucina")


## La consegna come la fa il giocatore dalle Tasche: la voce RAGGRUPPATA
## della vetrina -> `take_gift` (che restituisce la porzione VERA, firma
## compresa) -> `offer_item`. Sono le due righe di `Pockets._give`.
func _consegna(t, b: Dictionary, indice: int) -> void:
	var inv = b["inv"]
	var vis = b["vis"]
	var vetrina: Array = inv.call("dishes_grouped")
	if vetrina.is_empty():
		t.ok(false, "le Tasche sono vuote: non c'è niente da consegnare")
		return
	var item: Dictionary = inv.call("take_gift", vetrina[0])
	vis.call("offer_item", (vis.get("_residents") as Array)[indice], item)
	_scatta_i_tween(t)


## LA RIGA STA DENTRO UN TWEEN. `offer_item` scrive nel libro mastro nel
## callback della ciotola che arriva (dopo ~1,05 s di coreografia): in un
## test sincrono quel callback non scatterebbe MAI, e la prova sarebbe
## verde su codice che non è girato. `custom_step` fa correre la
## coreografia fino in fondo senza aspettare un secondo vero.
func _scatta_i_tween(t) -> void:
	var st := t.tree() as SceneTree
	for tw in st.get_processed_tweens():
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).custom_step(4.0)


func _banco_cucina(t) -> Dictionary:
	# ⚠️ IL VILLAGGIO SI MONTA STACCATO, E SI APPENDE ALLA FINE. `_ready`
	# scatta nell'istante dell'`add_child`, mentre `%Player` si risolve
	# attraverso l'OWNER di chi lo chiede: montando dentro l'albero, il
	# `_ready` di Visitors e Cooking girerebbe PRIMA che l'owner esista e si
	# spezzerebbe a metà (`get_node("%Player")` secco) — con mezzo banco non
	# montato e nessuna asserzione a dirlo.
	var cont := Node.new()
	cont.name = "Villaggio"

	var player := Node3D.new()
	player.name = "Player"
	cont.add_child(player)
	player.owner = cont
	player.set_unique_name_in_owner(true)
	var mochi := FintaMochi.new()
	mochi.name = "Mochi"
	player.add_child(mochi)

	var bld := FintoBuild.new()
	bld.name = "BuildSystem"
	cont.add_child(bld)
	var leg := FintiLegami.new()
	leg.name = "Legami"
	cont.add_child(leg)
	var inv := Node.new()
	inv.set_script(INVENTORY)
	inv.name = "Inventory"
	cont.add_child(inv)

	var corpi: Array = []
	# ⚠️ TIPIZZATO. `Visitors._residents` è `Array[Dictionary]`: passargli un
	# `Array` nudo con `set()` non fallisce — viene SCARTATO in silenzio, e
	# l'anagrafe resta vuota. (Trovato così: «indice 2 fuori dai limiti» su
	# un array che il test credeva di aver appena riempito con cinque case.)
	var residenti: Array[Dictionary] = []
	for i in NOMI.size():
		var corpo := FintoCorpo.new()
		corpo.name = "Corpo%d" % i
		cont.add_child(corpo)
		# `position` e non `global_position`: qui il villaggio è ancora
		# staccato dall'albero, e la globale su un nodo fuori scena non
		# scrive niente (il padre è comunque all'origine)
		corpo.position = Vector3(PASSO * float(i), 0, 0)
		corpi.append(corpo)
		residenti.append({"label": str(NOMI[i]), "node": corpo, "friend": 0,
				"dna": {"name": str(NOMI[i]), "sogno": "cuoco",
					"weights": {"warmth": 0.7, "garden": 0.3, "comfort": 0.5},
					"tratti": {"orgoglio": 0.5, "lealta": 0.5, "grinta": 0.5,
						"codardia": 0.5, "ambizione": 0.5}}})

	var vis := Node.new()
	vis.set_script(VISITORS)
	vis.name = "Visitors"
	cont.add_child(vis)
	vis.owner = cont

	var cook := Node.new()
	cook.set_script(COOKING)
	cook.name = "Cooking"
	cont.add_child(cook)
	cook.owner = cont

	var aff := Node.new()
	aff.set_script(AFF)
	aff.name = "Affetti"
	cont.add_child(aff)

	# ora che gli owner ci sono, il villaggio entra in scena e i _ready girano
	t.stage(cont)
	# il test chiama le funzioni a mano: il `_process` di questi due nodi
	# girerebbe a fine frame su un villaggio finto, cercando pezzi che non
	# ci sono, e sporcherebbe il conto degli errori a runtime
	vis.set_process(false)
	vis.set_physics_process(false)
	cook.set_process(false)
	vis.set("_residents", residenti)
	vis.set("_inventory", inv)
	return {"cont": cont, "inv": inv, "cooking": cook, "vis": vis, "aff": aff,
			"leg": leg, "corpi": corpi}


# ============================================ 7. il villaggio è vivo

## LA PROVA DI SISTEMA, la sola che dice se il gioco è ancora vivo.
##
## Togliere il broadcast poteva benissimo spegnere gli affetti invece di
## liberarli: è già successo una volta in questo progetto — dei tredici
## tipi di gesto il gioco ne emetteva tre, tutti leggeri, e `coppia()` era
## FALSA PER COSTRUZIONE con la suite verde su un villaggio che non
## esiste. Qui si fanno passare tre mesi di notti vere e si pretende che
## qualcuno si metta insieme.
##
## E soprattutto: **non sempre gli stessi due**. Due partite identiche
## tranne che per dove il giocatore ha posato una luce devono dare due
## coppie diverse — se il villaggio si innamorasse sempre delle stesse
## persone saremmo tornati al broadcast con un'altra faccia.
func _test_il_villaggio_e_vivo(t) -> void:
	var coppie_viste := {}
	for variante in 2:
		var b := banco(t)
		if variante == 1:
			# l'unica differenza fra le due partite: una lampada in fondo
			accendi_lampione(b, Vector3(PASSO * float(NOMI.size() - 1), 0, 0))
		for giorno in 90:
			notte(b)
			domani(b)
		var righe := righe_di(b)
		var oggi := int((b["dn"] as Node3D).get("day"))
		var coppie := AFF.coppie(righe, NOMI, oggi)
		t.ok(coppie.size() >= 1,
				"partita %d: dopo tre mesi qualcuno si è messo insieme (%d coppie)"
				% [variante + 1, coppie.size()])
		for c in coppie:
			var due: Array = (c as Array).duplicate()
			due.sort()
			coppie_viste[str(due)] = true
	t.ok(coppie_viste.size() >= 2,
			"e non sempre gli stessi due: spostando UNA luce il villaggio si"
			+ " innamora di qualcun altro (%d coppie diverse)" % coppie_viste.size())
