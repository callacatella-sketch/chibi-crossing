extends RefCounted
## I SITI DEL GESTO — quello che ogni sito EMETTE davvero, misurato dal sito.
##
## `test_percezione.gd` prova la porta (`Percezione.accaduto`): chi poteva
## vedere, chi gira la testa, cosa finisce in memoria. Ma nessuna di quelle
## asserzioni tocca i NOVE punti del gioco in cui un gesto nasce — e quelli
## sono l'unico posto in cui i tre argomenti vengono decisi.
##
## Una campagna di mutazioni ha misurato quanto quel confine costava: NOVE
## guasti diversi ai siti lasciavano la suite **verde**.
##
##  · il terzo argomento dei due siti del dono (`a_chi`) — cioè `R_SU_DI_ME`,
##    l'unica asimmetria fra persone che il grafo conosce, e l'unico
##    moltiplicatore che porta UN gesto sopra `RICORDO_SOGLIA`. Toglierlo
##    vuol dire che portare la zuppa a Nino non lascia più niente addosso a
##    Nino, per sempre, e non si vede;
##  · il LUOGO di tutti e cinque i siti che ne hanno uno proprio —
##    sostituito con la posizione di Mochi, verde ovunque. È la quarta scena
##    («l'aiuola che ha visto»): il posto sbagliato manda il vicino ad
##    annaffiare da un'altra parte, e per il cantiere lo scarto non è nemmeno
##    limitato (il cursore è un raycast dalla camera, senza nessun cancello
##    di prossimità);
##  · il cancello `is_fish` sulla pesca — senza, una farfalla presa col
##    retino verrebbe incisa come PESCE e raccontata col simbolo del pesce;
##  · la sparizione di un sito il cui verbo è emesso anche da un altro: il
##    vecchio censimento chiedeva «almeno OTTO siti» con l'otto scritto a
##    mano, e con nove siti e `dona` emesso due volte una delle due porte del
##    regalo poteva sparire senza far cadere niente.
##
## PERCIÒ QUI NON SI LEGGE NESSUN SORGENTE: si mette una SPIA nel gruppo
## «percezione» — che è l'API vera, quella che i siti conoscono — e si fanno
## girare le funzioni di produzione con Mochi messa APPOSTA lontano
## dall'oggetto del gesto. Se il sito emette il posto di Mochi invece di
## quello della cosa, la spia se ne accorge.
##
## L'unica eccezione dichiarata è la CATTURA: il pesce arriva da un
## galleggiante già ritirato, e il posto del gesto è quello di Mochi per
## scelta (`Collection.add_catch`). Anche quella si misura — perché una
## scelta non sorvegliata è indistinguibile da una dimenticanza.

const CRIT := preload("res://scenes/world/Critters.gd")
const PERC := preload("res://scenes/npc/Percezione.gd")
const VISITOR := preload("res://scenes/npc/Visitor.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")

## Quanto Mochi sta LONTANA dall'oggetto del gesto in tutti i banchi. Non è
## una distanza di gioco: è la lente. Sotto il metro e mezzo un posto
## sbagliato si confonderebbe con quello giusto, e la prova non saprebbe più
## dire quale dei due ha emesso il sito.
const LONTANO := 20.0


## LA SPIA. Sta nel gruppo «percezione» — che è tutta l'API che i siti
## conoscono (`call_group`) — e non fa nient'altro che segnarsi cosa le è
## arrivato. Non sostituisce la `Percezione` vera: la affianca, perché quel
## che si prova qui è il MITTENTE.
class Spia extends Node:
	var visti: Array = []
	func _ready() -> void:
		add_to_group("percezione")
	func accaduto(verbo: String, pos: Vector3, a_chi := "") -> void:
		visti.append({"verbo": verbo, "pos": pos, "a_chi": a_chi})
	func ultimo() -> Dictionary:
		return visti[visti.size() - 1] if not visti.is_empty() else {}
	func di(verbo: String) -> Array:
		var out: Array = []
		for v in visti:
			if str((v as Dictionary)["verbo"]) == verbo:
				out.append(v)
		return out


## Il BuildSystem che i siti chiamano per salvare: qui non salva niente (un
## test non deve poter riscrivere il villaggio del giocatore) e conta.
class FintoBuild extends Node3D:
	var salvataggi := 0
	func request_save() -> void:
		salvataggi += 1
	func get_placed_by_name(_n: String) -> Array[Node3D]:
		return [] as Array[Node3D]


## Mochi ridotta all'osso: le tre cose che la coreografia dell'orto le
## chiede. Non serve altro — quel che si misura sta PRIMA della coreografia.
class FintaMochi extends Node3D:
	var _yaw := 0.0
	var pour := 0.0
	var crouch := 0.0
	var joy := 0.0
	func attach_to_paw(n: Node3D, _destra := true) -> void:
		add_child(n)
	func hold_pour(_on: bool) -> void:
		pass
	func hold_sow(_on: bool) -> void:
		pass
	func hold_offer(_on: bool) -> void:
		pass
	func paw_world() -> Vector3:
		return global_position


func run(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	_il_censimento_dei_siti(t)
	_l_orto_emette_l_aiuola(t)
	_il_bosco_emette_l_albero(t)
	_il_cantiere_emette_il_cursore(t)
	_la_cattura_e_solo_il_pesce(t)
	_il_dono_dice_a_chi(t)


# --------------------------------------------------------------- il banco

## Un giocatore fermo LONTANO da tutto: qualunque sito che emetta «il posto
## di Mochi» invece del posto della cosa finisce a venti metri di distanza.
func _giocatore(t) -> Node3D:
	var p := Node3D.new()
	p.name = "Player"
	t.stage(p)
	p.global_position = Vector3(LONTANO, 0, LONTANO)
	var m := FintaMochi.new()
	m.name = "Mochi"
	p.add_child(m)
	return p


func _spia(t) -> Spia:
	# UNA SPIA PER VOLTA nel gruppo: una rimasta dal caso precedente
	# raccoglierebbe i gesti di questo, e i conti non tornerebbero più.
	for vecchia in t.tree().get_nodes_in_group("percezione"):
		(vecchia as Node).remove_from_group("percezione")
	return t.stage(Spia.new()) as Spia


# ============================================ 1. IL CENSIMENTO DEI SITI
#
# Quanti sono, e che verbi dicono. La vecchia stesura chiedeva «almeno otto»
# con un OTTO scritto a mano: con nove siti e un verbo emesso due volte, un
# sito poteva sparire senza far cadere niente (l'altro `dona` soddisfaceva
# da solo il controllo «nessun verbo morto»). Adesso il numero si DERIVA
# dalla tabella del ponte, e i due siti del dono hanno la loro prova
# comportamentale più sotto.
#
# QUI IL CABLAGGIO È TESTO, quindi si legge il testo: è la stessa eccezione
# dichiarata di `test_scena_cablaggi._test_nessun_gruppo_fantasma`, e per lo
# stesso motivo — non c'è un altro modo di sapere QUANTI siti esistono senza
# istanziare mezzo gioco. Tutto il resto di questo file, invece, guarda cosa
# i siti fanno.

func _il_censimento_dei_siti(t) -> void:
	var re := RegEx.new()
	re.compile('call_group\\(\\s*"percezione",\\s*"accaduto",\\s*"([a-z_]+)"')
	var per_verbo := {}
	var siti := 0
	for path in _tutti("res://scenes", ".gd"):
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		for m in re.search_all(f.get_as_text()):
			siti += 1
			var v := m.get_string(1)
			per_verbo[v] = int(per_verbo.get(v, 0)) + 1

	var cuore: Object = ClassDB.instantiate("EcsMondo")
	var n_verbi := int(cuore.get("N_VERBI"))
	# IL NUMERO NON SI SCRIVE A MANO: un sito per verbo è il minimo che la
	# tabella del ponte impone, e se un domani nascesse un nono verbo questa
	# riga lo pretenderebbe da sola.
	t.ok(siti >= n_verbi,
			"c'è almeno un sito per ciascuno degli %d verbi del ponte (%d siti)"
					% [n_verbi, siti])
	for verbo in per_verbo:
		t.ok(int(cuore.call("indice_verbo", str(verbo))) >= 0,
				"il verbo «%s» che il gioco emette esiste nel ponte" % verbo)
	for i in n_verbi:
		var nome := str(cuore.call("nome_verbo", i))
		t.ok(per_verbo.has(nome),
				"il verbo «%s» lo emette qualcuno: nessuna riga morta nella tabella" % nome)
	# IL DONO HA DUE PORTE, e sono due gesti diversi del giocatore: la
	# zuppetta cucinata (`_give_dish`) e il regalo dalle Tasche
	# (`offer_item`). Con una sola riga «almeno un sito per verbo» una delle
	# due poteva sparire in silenzio — ed è la strada da cui passa mezza
	# economia degli affetti.
	t.ok(int(per_verbo.get("dona", 0)) >= 2,
			"il dono ha le sue DUE porte (la zuppetta e il regalo): %d siti"
					% int(per_verbo.get("dona", 0)))
	# ⚠️ QUEL CHE QUESTO CONTO NON PUÒ DIRE, ed è dichiarato: una porta che
	# non è MAI esistita. `Commissioni.consegna()` — esaudire un desiderio, il
	# regalo più pesante del gioco: emette il momento sul Filo Rosso e la nota
	# al Regista, e verso la percezione non dice niente. Nessuna asserzione
	# scritta a partire dai siti che ci sono può accorgersi di un sito che
	# manca, perché non c'è niente da cui derivarne l'attesa. Sta qui perché
	# chi legge lo sappia, e perché la scelta («si vede o non si vede?») è
	# dell'autore, non di un test.
	(cuore as Node).free()


# ============================================ 2. L'ORTO EMETTE L'AIUOLA
#
# La scena 4 promette «lo stesso punto»: Mochi torna all'orto e ritrova il
# proprio gesto, nella stessa aiuola, fatto da un altro. Il posto che ci
# arriva è quello che il sito ha emesso — e l'ancora del vicino sceglie
# l'aiuola PIÙ VICINA a quel punto, quindi due metri di scarto bastano a
# farla passare a quella accanto.

## Il Garden vero, col `_ready` scavalcato (il suo vuole `%Player` e
## `../BuildSystem`, cioè il villaggio intero) e le aiuole messe a mano nel
## suo dizionario: la stessa disciplina di `test_cuore_vicini._orto`.
## Il `_process` resta SPENTO in tutti i banchi di questo file: quello di
## produzione cerca il cartellino della E, le lucciole, il ghost del cursore —
## roba di un villaggio intero — e girerebbe a fine caso su mezzo mondo,
## sporcando il conto degli errori a runtime con guasti che non sono del
## sistema in prova.
class Orto extends "res://scenes/interact/Garden.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)


func _aiuola(t, orto: Node, pos: Vector3, cell: Vector2i) -> Node3D:
	var n := Node3D.new()
	t.stage(n)
	n.global_position = pos
	var velo := MeshInstance3D.new()
	velo.mesh = QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.15, 0.1, 0.0)
	velo.material_override = mat
	n.add_child(velo)
	(orto.get("_beds") as Dictionary)[n] = {
		"stage": 1, "watered": false, "vis": null, "cell": cell,
		"crop": "", "wet": velo}
	return n


func _l_orto_emette_l_aiuola(t) -> void:
	var spia := _spia(t)
	var player := _giocatore(t)
	var orto := Orto.new()
	t.stage(orto)
	orto.set("_player", player)
	orto.set("_build", t.stage(FintoBuild.new()))

	var qua := _aiuola(t, orto, Vector3(0, 0, 0), Vector2i(0, 0))
	var la := _aiuola(t, orto, Vector3(4.0, 0, -3.0), Vector2i(4, -3))
	# le tre azioni dell'orto, ognuna sulla propria aiuola: se il sito
	# emettesse «dove sta Mochi» tutte e tre finirebbero nello stesso punto
	(orto.get("_beds") as Dictionary)[qua]["stage"] = -1
	orto.call("_plant", qua, false)
	orto.call("_water", la)
	(orto.get("_beds") as Dictionary)[la]["stage"] = 3
	orto.call("_harvest", la, false)

	var atteso := {"semina": qua, "annaffia": la, "raccoglie": la}
	for verbo in atteso:
		var righe: Array = spia.di(str(verbo))
		t.eq(righe.size(), 1, "l'orto emette «%s» una volta sola" % verbo)
		if righe.size() != 1:
			continue
		var dove: Vector3 = (righe[0] as Dictionary)["pos"]
		var bed: Node3D = atteso[verbo]
		t.almost(dove.distance_to(bed.global_position), 0.0,
				"«%s» dice il posto dell'AIUOLA (%s), non quello di Mochi" % [verbo, str(dove)],
				0.001)
		# …e la prova sta davvero guardando due punti diversi: senza questa
		# riga basterebbe mettere Mochi sull'aiuola per farla passare
		t.ok(dove.distance_to(player.global_position) > 5.0,
				"…(e Mochi era a %.1f m: i due posti non si confondono)"
						% dove.distance_to(player.global_position))
	# LE DUE AIUOLE SI DISTINGUONO. È la misura che dice se il sito porta il
	# posto della COSA o un posto qualunque: seminare qua e annaffiare là
	# devono dare due punti diversi.
	var s: Array = spia.di("semina")
	var a: Array = spia.di("annaffia")
	if s.size() == 1 and a.size() == 1:
		var d: float = ((s[0] as Dictionary)["pos"] as Vector3).distance_to(
				(a[0] as Dictionary)["pos"] as Vector3)
		t.almost(d, qua.global_position.distance_to(la.global_position),
				"due aiuole diverse fanno due posti diversi (%.2f m)" % d, 0.001)


# ============================================ 3. IL BOSCO EMETTE L'ALBERO
#
# «La cosa che è successa è il posto che si è aperto nel bosco»: il vicino
# guarda il piede dell'albero appena caduto, non la schiena di Mochi che si
# allontana con la legna in spalla.

class Boscaiolo extends "res://scenes/interact/Woodcutting.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)


func _il_bosco_emette_l_albero(t) -> void:
	var spia := _spia(t)
	var player := _giocatore(t)
	var bosco := Boscaiolo.new()
	t.stage(bosco)
	bosco.set("_player", player)

	# un albero finto ma completo quanto basta a `_give_wood`: il piede, il
	# perno che cade, il ceppo che resta
	var radice := Node3D.new()
	t.stage(radice)
	radice.global_position = Vector3(-7.0, 0, 2.0)
	var perno := Node3D.new()
	radice.add_child(perno)
	var ceppo := Node3D.new()
	radice.add_child(ceppo)
	var albero := {"root": radice, "pivot": perno, "stump": ceppo,
			"spec": [3.0, 0.5, 1.0], "bark": null, "fall_dir": 1.0}
	(bosco.get("_trees") as Array).append(albero)

	bosco.call("_give_wood", albero)

	var righe: Array = spia.di("taglia")
	t.eq(righe.size(), 1, "l'albero caduto emette «taglia» una volta")
	if righe.size() == 1:
		var dove: Vector3 = (righe[0] as Dictionary)["pos"]
		t.almost(dove.distance_to(radice.global_position), 0.0,
				"…nel punto del PIEDE dell'albero (%s), non addosso a Mochi" % str(dove),
				0.001)
		t.ok(dove.distance_to(player.global_position) > 5.0,
				"…(e Mochi era a %.1f m)" % dove.distance_to(player.global_position))


# ======================================== 4. IL CANTIERE EMETTE IL CURSORE
#
# È il sito in cui lo scarto NON è limitato da niente: `_cursor_pos` è un
# raycast dalla camera sul piano di terra, senza nessun cancello di
# prossimità — Mochi può posare un pezzo a dieci metri da sé. Emettere la
# sua posizione manderebbe il vicino a guardare (e domani a sedersi) da
# tutt'altra parte rispetto a quello che ha visto nascere.

## Il BuildSystem vero, con UNA sola cosa spenta: il caricamento del
## villaggio del giocatore. `_ready` lo accoda differito e non guarda
## `_persist` (vedi `set_persist_for_debug`), quindi la porta si chiude qui —
## e le SCRITTURE le spegne `set_persist_for_debug(false)` appena montato.
class Cantiere extends "res://scenes/build/BuildSystem.gd":
	func _ready() -> void:
		super()
		set_process(false)
		set_physics_process(false)
	func _load_village() -> void:
		pass


func _il_cantiere_emette_il_cursore(t) -> void:
	var spia := _spia(t)
	var player := _giocatore(t)
	var cantiere := Cantiere.new()
	t.stage(cantiere)
	cantiere.call("set_persist_for_debug", false)
	cantiere.set("_player", player)

	# il pezzo più semplice del catalogo, e il cursore lontano da Mochi
	var items: Array = cantiere.get("_items")
	var indice := -1
	for i in items.size():
		if str((items[i] as Dictionary)["name"]) == "Sentiero":
			indice = i
			break
	t.ok(indice >= 0, "il catalogo ha il Sentiero (il pezzo del banco)")
	if indice < 0:
		return
	var cella := Vector2i(3, -5)
	var cursore := Vector3(float(cella.x), 0.0, float(cella.y))
	cantiere.set("_index", indice)
	cantiere.set("_locks_active", false)
	cantiere.set("_valid", true)
	cantiere.set("_rot", 0)
	cantiere.set("_level", 0)
	cantiere.set("_cursor_key", cella)
	cantiere.set("_cursor_pos", cursore)
	cantiere.call("_try_place")

	var righe: Array = spia.di("costruisce")
	t.eq(righe.size(), 1, "posare un pezzo emette «costruisce» una volta")
	if righe.size() == 1:
		var dove: Vector3 = (righe[0] as Dictionary)["pos"]
		t.almost(dove.distance_to(cursore), 0.0,
				"…nel punto del CURSORE (%s), che è dove il pezzo è nato" % str(dove), 0.001)
		t.ok(dove.distance_to(player.global_position) > 5.0,
				"…e non addosso a Mochi, che stava a %.1f m"
						% dove.distance_to(player.global_position))
	# PREMESSA: il pezzo è nato davvero lì (se `_try_place` fosse uscito
	# presto, la riga sopra proverebbe il silenzio invece del posto)
	t.eq(cantiere.call("get_placed_by_name", "Sentiero").size(), 1,
			"…(e il pezzo è stato posato davvero)")


# ==================================== 5. LA CATTURA È SOLO IL PESCE
#
# Degli otto verbi che il ponte conosce nessuno dice «ha preso una farfalla
# col retino»: inventarlo vorrebbe dire una `Cosa` nuova, la sua parola in
# Chibiese e il suo simbolo in `Visitor.LP_SIMBOLI` — tre cose, non una riga.
# Senza il cancello, una farfalla verrebbe incisa come PESCE e raccontata in
# una nuvoletta col simbolo del pesce: una cosa che non è mai successa.

class Barattoli extends "res://scenes/interact/Collection.gd":
	func _ready() -> void:
		# la UI serve sul serio: `add_catch` fa passare il toast della cattura
		_build_ui()
		set_process(false)
		set_physics_process(false)


func _la_cattura_e_solo_il_pesce(t) -> void:
	var spia := _spia(t)
	var player := _giocatore(t)
	var coll := Barattoli.new()
	t.stage(coll)
	coll.set("_player", player)
	coll.set("_build", t.stage(FintoBuild.new()))

	# due specie VERE, prese dalla fonte unica: una di classe «pesce» e una
	# che non lo è. I nomi non si scrivono a mano — la tabella è di Critters.
	var pesce := ""
	var altro := ""
	for id in CRIT.SPECIE:
		var c := str(CRIT.classe(str(id)))
		if c == "pesce" and pesce == "":
			pesce = str(id)
		elif c != "pesce" and altro == "":
			altro = str(id)
	t.ok(pesce != "" and altro != "",
			"il bestiario ha un pesce (%s) e qualcosa che non lo è (%s)" % [pesce, altro])
	if pesce == "" or altro == "":
		return

	coll.call("add_catch", altro)
	t.eq(spia.di("pesca").size(), 0,
			"prendere «%s» col retino non emette nessun gesto di pesca" % altro)
	coll.call("add_catch", pesce)
	var righe: Array = spia.di("pesca")
	t.eq(righe.size(), 1, "prendere «%s» invece sì" % pesce)
	if righe.size() == 1:
		# L'ECCEZIONE DICHIARATA, e si misura apposta: la cattura non ha un
		# luogo suo (il galleggiante è già stato ritirato, il retino era in
		# zampa) e il posto del gesto è quello di MOCHI. Non è una
		# dimenticanza: è l'unico sito che lo fa, e una scelta non
		# sorvegliata è indistinguibile da una svista.
		var dove: Vector3 = (righe[0] as Dictionary)["pos"]
		t.almost(dove.distance_to(player.global_position), 0.0,
				"…e il posto è quello di MOCHI: il gesto è suo, non del pesce", 0.001)


# ==================================== 6. IL DONO DICE A CHI
#
# `R_SU_DI_ME` è l'unica asimmetria fra persone che il grafo conosce, e non
# è un giudizio: chi riceve un dono se lo ricorda il doppio. È anche l'unico
# moltiplicatore che porta UN gesto solo sopra `RICORDO_SOGLIA` — cioè la
# differenza fra «domani Nino se la porta ancora addosso» e «non succede
# niente, mai».
#
# Qui non si chiama il bus: si chiamano le DUE funzioni di produzione da cui
# passa un regalo (`_give_dish`, la zuppetta cucinata, e `offer_item`, il
# regalo dalle Tasche), e si legge il ricordo VERO nell'`EcsMondo`.

## Il registro dei vicini vero, col solo `_ready` scavalcato (il suo vuole
## `%Player` e `../BuildSystem`): `testimoni()`, `cuore()`, `_give_dish` e
## `offer_item` restano quelli di produzione.
class RegistroVicini extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		add_to_group("visitors")


## La cucina ridotta alla sola cosa che `_give_dish` le chiede.
class FintaCucina extends Node:
	func has_dish() -> bool:
		return true
	func take_dish() -> Dictionary:
		return {"name": "zuppetta", "art": "la", "warm": true, "cuoco": ""}


func _corpo(t, seme: int, pos: Vector3) -> Node3D:
	var v = VISITOR.new()
	v.dna = DNA.generate(seme)
	v.species = "chibi"
	v.mode = "resident"
	t.stage(v)
	v.global_position = pos
	v._enter_state("r_idle")
	v._timer = 9999.0
	return v


func _il_dono_dice_a_chi(t) -> void:
	for porta in ["piatto", "regalo"]:
		var spia := _spia(t)
		# il registro vero deve essere l'UNICO nel gruppo, o la Percezione
		# vera pescherebbe i residenti di un altro villaggio
		for vecchio in t.tree().get_nodes_in_group("visitors"):
			(vecchio as Node).remove_from_group("visitors")
		var player := _giocatore(t)
		var vis = t.stage(RegistroVicini.new())
		vis.set("_player", player)
		vis.set("_build", t.stage(FintoBuild.new()))
		vis.set("_cooking", t.stage(FintaCucina.new()))

		var cuore: Object = ClassDB.instantiate("EcsMondo")
		(cuore as Node).name = "CuoreSonno"
		(vis as Node).add_child(cuore)
		vis.set("_ecs", cuore)

		# due vicini vicini vicini: il destinatario e chi guardava
		var chi_riceve := _corpo(t, 6101, Vector3(0, 0, 0))
		var chi_guarda := _corpo(t, 6102, Vector3(0, 0, 4.0))
		var righe: Array[Dictionary] = []
		var corpi := [chi_riceve, chi_guarda]
		for i in corpi.size():
			var id: int = cuore.call("registra", PackedStringArray([]), "")
			righe.append({"node": corpi[i], "label": "V%d" % i,
					"dna": corpi[i].dna, "cell": Vector2i(i, 0),
					"species": "chibi", "friend": 0, "ecs": id})
		vis.set("_residents", righe)
		# la Percezione VERA: senza, il gesto non arriverebbe a nessuna memoria
		t.stage(PERC.new())

		if porta == "piatto":
			vis.call("_give_dish", righe[0])
		else:
			vis.call("offer_item", righe[0],
					{"name": "conchiglia", "art": "la", "kind": "treasure", "warm": false})

		# --- la spia: il sito ha detto A CHI
		var visti: Array = spia.di("dona")
		t.eq(visti.size(), 1, "[%s] il dono emette un gesto solo" % porta)
		if visti.size() == 1:
			t.eq(str((visti[0] as Dictionary)["a_chi"]), "V0",
					"[%s] …e porta la LABEL del destinatario, non una stringa vuota" % porta)
			var dove: Vector3 = (visti[0] as Dictionary)["pos"]
			t.almost(dove.distance_to(chi_riceve.global_position), 0.0,
					"[%s] …nel punto di chi lo riceve" % porta, 0.001)

		# --- e il ricordo VERO: la bandiera nel grafo del C++
		var su_di_me := int(cuore.get("R_SU_DI_ME"))
		var suo: Array = (cuore.call("debug_grafo", int(righe[0]["ecs"]))
				as Dictionary).get("ricordi", []) as Array
		var altrui: Array = (cuore.call("debug_grafo", int(righe[1]["ecs"]))
				as Dictionary).get("ricordi", []) as Array
		t.eq(suo.size(), 1, "[%s] il destinatario ha il suo ricordo" % porta)
		t.eq(altrui.size(), 1, "[%s] e chi guardava pure" % porta)
		if suo.size() == 1 and altrui.size() == 1:
			t.ok(int((suo[0] as Dictionary)["bandiere"]) & su_di_me != 0,
					"[%s] CHI L'HA RICEVUTO se lo ricorda come fatto A LUI" % porta)
			t.ok(int((altrui[0] as Dictionary)["bandiere"]) & su_di_me == 0,
					"[%s] …e chi guardava no: la gratitudine non si prende per sbaglio" % porta)
			# LA CONSEGUENZA, che è il motivo per cui la bandiera esiste: è
			# l'unico moltiplicatore che porta UN gesto solo sopra la soglia
			# del ricordo. Senza `a_chi` questo numero torna −1, cioè «non è
			# successo niente che valga la pena di portarsi dietro».
			var soglia := 1.0
			t.ok(int(cuore.call("cosa_da_ricordare", int(righe[0]["ecs"]), soglia)) >= 0,
					"[%s] …e un dono solo BASTA a lasciargli qualcosa addosso" % porta)
			t.eq(int(cuore.call("cosa_da_ricordare", int(righe[1]["ecs"]), soglia)), -1,
					"[%s] mentre averlo solo visto no: la soglia è la stessa" % porta)


# ------------------------------------------------------------------ utili

func _tutti(dir_path: String, ext: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var p := dir_path.path_join(n)
		if d.current_is_dir():
			if not n.begins_with(".") and n != "addons":
				out.append_array(_tutti(p, ext))
		elif n.ends_with(ext):
			out.append(p)
		n = d.get_next()
	d.list_dir_end()
	return out
