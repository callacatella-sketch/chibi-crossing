extends RefCounted
## LA PERCEZIONE — la prova che il villaggio guarda, e che non INVENTA.
##
## Questo sistema ha una modalità di guasto sola, ed è catastrofica: un
## vicino che si comporta come se avesse visto una cosa che non ha potuto
## vedere. Non attenua l'effetto — **lo inverte**: insegna al giocatore che
## i vicini reagiscono a caso, e da quel momento non riconosce più nessuna
## delle conseguenze vere, comprese quelle che gli sono costate mesi. È
## esattamente il guasto del taccuino del Gufo, portato dal testo al corpo,
## e questo file è scritto con la stessa disciplina di `test_taccuino`:
##
##  · si prende una FINESTRA BUONA (testimone sveglio, a sei metri, non
##    nascosto, non in scena) e si **guasta una valvola per volta**,
##    pretendendo SILENZIO. Se il sistema parla comunque, quella valvola era
##    decorativa e il falso positivo è già in casa;
##  · l'invariante che conta — **ogni ricordo scritto è preceduto da una
##    `guarda_gesto` sullo stesso nodo** — non si legge nel sorgente: si
##    CONTA, mettendo un testimone vero che a ogni sguardo si segna quanti
##    ricordi esistevano in quell'istante in tutto il villaggio;
##  · e la testa che si gira si misura DAL SEGNO, perché il rig guarda −Z e
##    un segno sbagliato ha già tenuto il fantasma del congedo di spalle a
##    Mochi per mesi, sotto un commento che giurava il contrario.
##
## Niente è finto se non i DATI: il predicato è quello di produzione, i
## corpi sono `Visitor` veri, il registro è l'`EcsMondo` in C++, e
## `Visitors.testimoni` è la funzione vera (che si può far girare fuori
## dall'albero, perché tocca solo `_residents`).

const PERC := preload("res://scenes/npc/Percezione.gd")
const VISITOR := preload("res://scenes/npc/Visitor.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")

const DT := 1.0 / 60.0
## La finestra buona: sei metri, come il vicino seduto della prima scena.
const VICINO := 6.0


## IL BANCO: sa contare quanti ricordi esistono in tutto il villaggio in un
## dato istante. Serve all'invariante dell'ordine — non a fabbricare dati.
class Banco extends RefCounted:
	var cuore: Object = null
	var ids: Array = []
	func conta() -> int:
		var n := 0
		for id in ids:
			var g: Dictionary = cuore.call("debug_grafo", int(id))
			n += (g.get("ricordi", []) as Array).size()
		return n


## UN TESTIMONE VERO — il `Visitor` del gioco, con addosso un taccuino che
## registra OGNI sguardo ricevuto e quanti ricordi c'erano nel villaggio in
## quel momento. Non sostituisce niente: `super()` lascia girare il codice
## di produzione, che è quello che gira la testa.
class Testimone extends "res://scenes/npc/Visitor.gd":
	var sguardi: Array = []
	var banco = null
	## OGNI CHIAMATA si segna, anche quella che non alza la testa: è
	## `_tst_t` a dire se la testa si è alzata davvero, e il conto delle due
	## cose (chiamate ricevute vs occhiate vere) è proprio quello che serve
	## a misurare la raffica.
	func guarda_gesto(pos: Vector3, dur: float, gesto := -1, finestra := 0.0) -> void:
		var prima_t := _tst_t
		super(pos, dur, gesto, finestra)
		sguardi.append({"pos": pos, "dur": dur, "gesto": gesto,
				"alzata": _tst_t > prima_t,
				"prima": (banco.conta() if banco != null else -1)})


## Il registro dei vicini, VERO, con solo il `_ready` scavalcato: quello di
## produzione vuole `%Player` e `../BuildSystem`, cioè il villaggio intero.
## `testimoni()` e `cuore()` restano le funzioni di produzione.
class RegistroVicini extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		# il `_process` vero cerca il giocatore, il BuildSystem e la UI: qui
		# non c'è niente di tutto questo, e non serve — quello che si prova
		# è `testimoni()`, che tocca solo `_residents`.
		set_process(false)
		set_physics_process(false)
		add_to_group("visitors")


func run(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	_le_valvole(t)
	_la_ricevuta_precede_il_ricordo(t)
	_un_gesto_un_ricordo(t)
	_il_dono_e_su_di_me(t)
	_le_cose_si_sanno_dire(t)
	_il_nodo_e_nel_mondo(t)
	_la_testa_si_gira_dalla_parte_giusta(t)
	_lo_sguardo_batte_gli_altri(t)
	_la_testa_torna_sempre(t)
	_una_raffica_e_una_ricevuta(t)
	_il_tetto_del_collo(t)
	_la_tenuta_e_viva(t)
	_la_ricevuta_e_asimmetrica(t)
	_la_scena_rara_e_intoccabile(t)
	_le_tre_guardie(t)


# --------------------------------------------------------------- il banco

## Un corpo vero, sveglio, fermo, in mano a nessuno.
func _corpo(t, seme: int, pos: Vector3, spia := false) -> Node3D:
	var v = (Testimone.new() if spia else VISITOR.new())
	v.dna = DNA.generate(seme)
	# «chibi» come i residenti veri (`Visitors._spawn_resident`), e non è un
	# dettaglio: `set_eta()` esce SUBITO su qualunque altra specie, quindi un
	# banco che lascia il default («riccio») non riesce a invecchiare nessuno —
	# e ogni prova sull'età resterebbe verde misurando due giovani.
	v.species = "chibi"
	v.mode = "resident"
	t.stage(v)
	v.global_position = pos
	# `r_idle` è lo stato fermo del residente: `_anim_sit` è deterministico
	# (nessun dado) e tiene la testa dentro ±0.3 rad, che è la banda su cui
	# si misura più sotto. Il timer si allunga perché non parta a zonzo a
	# metà misura.
	v._enter_state("r_idle")
	v._timer = 9999.0
	return v


## Il villaggio: un registro vero, un cuore vero, e una riga per corpo.
## Torna {"vis":…, "cuore":…, "perc":…, "righe":[{node,label,ecs}], "banco":…}
func _villaggio(t, corpi: Array) -> Dictionary:
	# UN SOLO REGISTRO PER VOLTA nel gruppo. `Percezione._cabla` prende il
	# PRIMO nodo del gruppo «visitors», e un villaggio rimasto dal caso
	# precedente se lo prenderebbe lui — con i suoi residenti, che non sono
	# quelli di questa prova. (Ci è già cascato questo test, e i ricordi
	# finivano nel villaggio sbagliato: zero di qua, sei di là.)
	for vecchio in t.tree().get_nodes_in_group("visitors"):
		(vecchio as Node).remove_from_group("visitors")
	var vis = t.stage(RegistroVicini.new())
	var cuore: Object = ClassDB.instantiate("EcsMondo")
	(cuore as Node).name = "CuoreSonno"
	vis.add_child(cuore)
	vis.set("_ecs", cuore)
	var banco := Banco.new()
	banco.cuore = cuore
	var righe: Array = []
	for i in corpi.size():
		var node: Node3D = corpi[i]
		var id: int = cuore.call("registra", PackedStringArray([]), "")
		var r := {"node": node, "label": "V%d" % i, "dna": node.dna,
				"cell": Vector2i(i, 0), "species": "chibi", "ecs": id}
		vis._residents.append(r)
		righe.append(r)
		banco.ids.append(id)
		if node is Testimone:
			(node as Testimone).banco = banco
	var perc = t.stage(PERC.new())
	return {"vis": vis, "cuore": cuore, "perc": perc, "righe": righe, "banco": banco}


func _ricordi(v: Dictionary, i: int) -> Array:
	var g: Dictionary = (v["cuore"] as Object).call("debug_grafo",
			int((v["righe"][i] as Dictionary)["ecs"]))
	return g.get("ricordi", []) as Array


# ====================================================== 1. LE VALVOLE
#
# Una per volta, su una finestra che senza guasti dice SÌ. Se una di queste
# smettesse di chiudere, il villaggio comincerebbe a reagire a gesti che
# nessuno ha potuto vedere.

func _le_valvole(t) -> void:
	# LE DUE COSTANTI SI GIUDICANO CON NUMERI CHE NON SONO LORO. La prima
	# stesura di questo file misurava le distanze in multipli di `RAGGIO` e
	# la durata contro `DURATA_SGUARDO`: portando il raggio a 90 metri e la
	# durata a un secondo il test restava VERDE, perché si portava dietro la
	# costante che stava sorvegliando. È lo stesso difetto che la Fase 4
	# aveva già pagato con `PASSO_EMO`, e si chiude allo stesso modo: una
	# relazione fra numeri INDIPENDENTI.
	#
	# Il raggio deve stare SOPRA i 4,5 m con cui un vicino insegue con gli
	# occhi il giocatore che gli passa accanto (`Visitor._process`): sotto
	# quella soglia la testa girata non si distinguerebbe da «ti sto
	# guardando perché sei vicino», e la ricevuta non proverebbe più niente.
	# E SOTTO i ~12 m: la camera sta a 4,6 m d'altezza, e un testimone più
	# lontano è fuori inquadratura — cioè una conseguenza la cui premessa il
	# giocatore non ha potuto vedere, che è il guasto peggiore di tutti.
	t.ok(PERC.RAGGIO > 4.5,
			"il raggio è più largo dello sguardo di cortesia (4,5 m): la ricevuta si distingue")
	t.ok(PERC.RAGGIO <= 12.0,
			"…e sta dentro l'inquadratura: nessuna conseguenza da una premessa fuori campo")
	# La durata deve coprire il gesto più lungo dell'orto — 2,3 s, il
	# `_busy` di `Garden._water` — più il secondo dopo di cui parla la scena:
	# una testa che torna a posto mentre Mochi sta ancora annaffiando è una
	# ricevuta che sparisce a metà.
	t.ok(PERC.DURATA_SGUARDO >= 2.8,
			"lo sguardo copre il gesto più lungo dell'orto (2,3 s) e il secondo dopo")
	t.ok(PERC.DURATA_SGUARDO <= 6.0,
			"…e non diventa fissare: dopo qualche secondo si torna ai fatti propri")

	var gesto := Vector3(0, 0, 0)
	var buono := _corpo(t, 4101, Vector3(VICINO, 0, 0))
	t.ok(PERC.puo_vedere(buono, gesto, PERC.RAGGIO),
			"LA FINESTRA BUONA: sveglio, a sei metri, fuori casa, non in scena — ha visto")

	# (a) È DENTRO CASA. La notte i residenti rientrano e il corpo resta
	# nell'albero rimpicciolito: senza questa valvola tutto il villaggio
	# «vedrebbe» attraverso i muri di casa propria, e la mattina dopo si
	# comporterebbe di conseguenza.
	var dentro := _corpo(t, 4102, Vector3(VICINO, 0, 0))
	dentro.resident_sleep()
	t.ok(dentro.is_hidden(), "…(il corpo è davvero rientrato)")
	t.ok(not PERC.puo_vedere(dentro, gesto, PERC.RAGGIO),
			"TACE per chi è in casa: da lì non si vede il prato")

	# (b) DORME. Il pisolino: il corpo è nel mondo, a due passi, e a occhi
	# chiusi non ha visto niente.
	var pisolino := _corpo(t, 4103, Vector3(VICINO, 0, 0))
	pisolino._enter_state("tk_nap")
	t.ok(pisolino.dorme(), "…(sta davvero facendo il pisolino)")
	t.ok(not PERC.puo_vedere(pisolino, gesto, PERC.RAGGIO),
			"TACE per chi dorme: chi dorme non guarda niente")

	# (c) È A UN APPUNTAMENTO SUO. Le scene rare del gioco (il concerto, il
	# congedo, il nascondino) sono scritte a mano perché una volta ogni
	# tanto succeda qualcosa di preciso: un gesto qualunque del giocatore
	# non deve poterle interrompere né prendersene il merito.
	var in_scena := _corpo(t, 4104, Vector3(VICINO, 0, 0))
	in_scena.apri_scena(30.0)
	t.ok(in_scena.in_scena(), "…(la scena è davvero aperta)")
	t.ok(not PERC.puo_vedere(in_scena, gesto, PERC.RAGGIO),
			"TACE per chi è in scena: ha un appuntamento, e non è con te")

	# (d) È LONTANO. E il bordo si prova da tutti e due i lati, perché una
	# disuguaglianza girata al contrario passa metà dei test.
	var lontano := _corpo(t, 4105, Vector3(PERC.RAGGIO + 3.0, 0, 0))
	t.ok(not PERC.puo_vedere(lontano, gesto, PERC.RAGGIO),
			"TACE per chi è lontano: dodici metri sono fuori dall'inquadratura")
	t.ok(PERC.puo_vedere(lontano, gesto, PERC.RAGGIO + 4.0),
			"…ed è proprio la distanza a fermarlo (col raggio largo lo vede)")

	# (e) NON C'È PIÙ. Un corpo liberato a metà frame (un congedo, una
	# partenza) non deve far esplodere niente.
	#
	# E SI CONFRONTA CON `false`, NON CON «non vero»: senza la guardia il
	# predicato va in errore a runtime e torna `null` — e `not null` è
	# `true`, cioè l'asserzione RESTA VERDE mentre il gioco stampa un errore
	# che nessuno legge. È la trappola scritta in CLAUDE.md, in miniatura.
	# (Un corpo GIÀ LIBERATO non si prova qui: Godot rifiuta la chiamata
	# prima di entrare — un'istanza liberata non è più un `Node3D` — e la
	# prova non farebbe che sporcare il registro degli errori con un errore
	# del test. Che sia irraggiungibile è, di per sé, la garanzia.)
	t.eq(PERC.puo_vedere(null, gesto, PERC.RAGGIO), false,
			"un corpo che non c'è più non ha visto niente, e la risposta è un `false` VERO")


# ============================== 2. L'INVARIANTE: PRIMA LA TESTA, POI IL RICORDO
#
# Si CONTA, non si legge il sorgente. Ogni testimone si segna, nell'istante
# in cui riceve lo sguardo, quanti ricordi esistevano in tutto il villaggio:
# se le due righe sono nell'ordine giusto e intrecciate (guarda→incidi,
# guarda→incidi…), i tre numeri sono 0, 1 e 2. Se il codice incidesse prima
# di far girare la testa uscirebbero 1, 2, 3; se scrivesse tutto in blocco
# alla fine, 0, 0, 0; se ne saltasse uno, i conti non tornerebbero.

func _la_ricevuta_precede_il_ricordo(t) -> void:
	var gesto := Vector3(0, 0, 0)
	var corpi: Array = [
		_corpo(t, 4201, Vector3(2.0, 0, 0), true),          # testimone
		_corpo(t, 4202, Vector3(0, 0, VICINO), true),        # testimone
		_corpo(t, 4203, Vector3(0, 0, -8.5), true),          # testimone (al limite)
		_corpo(t, 4204, Vector3(PERC.RAGGIO + 3.0, 0, 0), true),  # troppo lontano
		_corpo(t, 4205, Vector3(1.5, 0, 1.5), true),         # a due passi, ma dorme
	]
	(corpi[4] as Node3D)._enter_state("tk_nap")
	var v := _villaggio(t, corpi)

	(v["perc"] as Node).call("accaduto", "annaffia", gesto)

	var visti := [0, 1, 2]
	var assenti := [3, 4]
	var ordini: Array = []
	for i in visti:
		var spia: Testimone = corpi[i]
		t.eq(spia.sguardi.size(), 1,
				"il testimone %d ha girato la testa UNA volta" % i)
		var rr := _ricordi(v, i)
		t.eq(rr.size(), 1, "…e ha UN ricordo del gesto")
		if rr.size() == 1:
			var r: Dictionary = rr[0]
			t.eq(int(r["verbo"]), int((v["cuore"] as Object).get("V_ANNAFFIA")),
					"…ed è il verbo giusto")
			t.almost(float(r["px"]), gesto.x, "…nel punto giusto (x)", 0.001)
			t.almost(float(r["pz"]), gesto.z, "…nel punto giusto (z)", 0.001)
			t.eq(int(r["quante"]), 1, "…una volta sola, non una per testimone")
		if spia.sguardi.size() == 1:
			var s: Dictionary = spia.sguardi[0]
			t.almost((s["pos"] as Vector3).distance_to(gesto), 0.0,
					"…e ha guardato PROPRIO lì", 0.001)
			t.almost(float(s["dur"]), PERC.DURATA_SGUARDO,
					"…per la durata dichiarata", 0.001)
			ordini.append(int(s["prima"]))
	for i in assenti:
		var spia: Testimone = corpi[i]
		t.eq(spia.sguardi.size(), 0,
				"chi non poteva vedere (%d) non ha girato la testa" % i)
		t.eq(_ricordi(v, i).size(), 0, "…e non si ricorda niente")

	ordini.sort()
	t.eq(ordini, [0, 1, 2],
			"OGNI RICORDO È PRECEDUTO DALLA SUA TESTA GIRATA: al k-esimo sguardo "
			+ "esistevano esattamente k ricordi (visto: %s)" % str(ordini))


# ====================================== 3. UN GESTO, UN RICORDO PER TESTIMONE
#
# Il guasto che questa prova chiude è il più facile da introdurre di tutti:
# un `accaduto()` chiamato DENTRO un ciclo sui vicini. Con tre testimoni
# scriverebbe nove ricordi, che la fusione unirebbe in tre da `quante = 3` —
# cioè il villaggio racconterebbe che Mochi ha annaffiato tre volte.

func _un_gesto_un_ricordo(t) -> void:
	var gesto := Vector3(3.0, 0, -2.0)
	var corpi: Array = [
		_corpo(t, 4301, Vector3(3.0, 0, 0)),
		_corpo(t, 4302, Vector3(4.0, 0, -3.0)),
		_corpo(t, 4303, Vector3(1.0, 0, -1.0)),
	]
	var v := _villaggio(t, corpi)
	(v["perc"] as Node).call("accaduto", "costruisce", gesto)

	t.eq((v["banco"] as Banco).conta(), corpi.size(),
			"un gesto e tre testimoni fanno TRE ricordi, non nove")
	for i in corpi.size():
		var rr := _ricordi(v, i)
		t.eq(rr.size(), 1, "il testimone %d ne ha uno solo" % i)
		if rr.size() == 1:
			t.eq(int((rr[0] as Dictionary)["quante"]), 1,
					"…ed è successo una volta, non tre")

	# e chi non c'era non impara niente stando lì fermo
	var tardo := _corpo(t, 4304, Vector3(3.0, 0, -2.0))
	t.eq(tardo.get("_tst_t"), 0.0,
			"chi è arrivato dopo non ha nessuno sguardo addosso")

	# UN VERBO CHE IL PONTE NON CONOSCE non è un gesto: nessuno gira la testa
	# e nessuno si ricorda niente. Il guasto opposto — la testa che si gira su
	# un errore di cablaggio — è una ricevuta per una cosa che non è mai stata
	# incisa, cioè la promessa che il sistema non mantiene.
	var corpi2: Array = [_corpo(t, 4305, Vector3(1.0, 0, 0), true)]
	var v2 := _villaggio(t, corpi2)
	(v2["perc"] as Node).call("accaduto", "volteggia", Vector3.ZERO)
	t.eq((corpi2[0] as Testimone).sguardi.size(), 0,
			"un verbo che il ponte non conosce non fa girare nessuna testa")
	t.eq(_ricordi(v2, 0).size(), 0, "…e non incide niente")

	# DUE GESTI RAVVICINATI NON ACCORCIANO LO SGUARDO: si tiene il più lungo.
	var doppio := _corpo(t, 4306, Vector3.ZERO)
	doppio.call("guarda_gesto", Vector3(1, 0, 0), 5.0)
	doppio.call("guarda_gesto", Vector3(1, 0, 0), 0.5)
	t.almost(float(doppio.get("_tst_t")), 5.0,
			"un secondo gesto più corto non spegne lo sguardo del primo", 0.001)


# ============================================ 4. IL DONO: «l'ha fatto A ME»
#
# `R_SU_DI_ME` è l'unica asimmetria fra persone che il grafo conosce, e non
# è un giudizio: chi riceve un dono se lo ricorda il doppio. Si DERIVA dal
# destinatario, e un vicino che si prendesse la gratitudine di un regalo
# fatto a un altro sarebbe un guasto che nessuno vedrebbe mai.

func _il_dono_e_su_di_me(t) -> void:
	var gesto := Vector3(0, 0, 2.0)
	var corpi: Array = [
		_corpo(t, 4401, Vector3(0, 0, 2.4)),   # il destinatario
		_corpo(t, 4402, Vector3(0, 0, VICINO)), # chi guardava da lontano
	]
	var v := _villaggio(t, corpi)
	var su_di_me := int((v["cuore"] as Object).get("R_SU_DI_ME"))
	var atteso := int((v["righe"][0] as Dictionary)["ecs"])
	(v["perc"] as Node).call("accaduto", "dona", gesto, "V0")

	var suo := _ricordi(v, 0)
	var altrui := _ricordi(v, 1)
	t.eq(suo.size(), 1, "il destinatario ha il suo ricordo")
	t.eq(altrui.size(), 1, "e chi guardava pure: un dono lo vedono tutti")
	if suo.size() == 1 and altrui.size() == 1:
		t.ok(int((suo[0] as Dictionary)["bandiere"]) & su_di_me != 0,
				"CHI L'HA RICEVUTO se lo ricorda come fatto A LUI")
		t.ok(int((altrui[0] as Dictionary)["bandiere"]) & su_di_me == 0,
				"…e chi guardava NO: la gratitudine non si prende per sbaglio")
		t.eq(int((altrui[0] as Dictionary)["soggetto"]), atteso,
				"ma sa a chi è stato fatto (è il soggetto del ricordo)")

	# LA VALVOLA DEL DESTINATARIO: senza `a_chi`, nessuno se la prende.
	var corpi2: Array = [_corpo(t, 4403, Vector3(0, 0, 2.4))]
	var v2 := _villaggio(t, corpi2)
	(v2["perc"] as Node).call("accaduto", "dona", gesto)
	var r2 := _ricordi(v2, 0)
	t.eq(r2.size(), 1, "un gesto senza destinatario si vede lo stesso")
	if r2.size() == 1:
		t.ok(int((r2[0] as Dictionary)["bandiere"]) & su_di_me == 0,
				"…ma non è di nessuno: senza destinatario nessun «l'ha fatto a me»")

	# e un destinatario che NON POTEVA VEDERE non se lo prende comunque
	var corpi3: Array = [
		_corpo(t, 4404, Vector3(0, 0, 2.4)),
		_corpo(t, 4405, Vector3(0, 0, PERC.RAGGIO + 6.0)),
	]
	var v3 := _villaggio(t, corpi3)
	(v3["perc"] as Node).call("accaduto", "dona", gesto, "V1")
	var r3 := _ricordi(v3, 0)
	if r3.size() == 1:
		t.ok(int((r3[0] as Dictionary)["bandiere"]) & su_di_me == 0,
				"un destinatario troppo lontano non è un destinatario")


# ================================== 5. LE COSE SI SANNO DIRE (Cosa ⊂ LP_SIMBOLI)
#
# Nel grafo entra solo ciò che un chibi sa DIRE. Il guasto opposto è un dato
# che vive nel motore e non arriva mai allo schermo — il TransformComponent
# di nuovo, ma peggio, perché *sembra* funzionare.

func _le_cose_si_sanno_dire(t) -> void:
	var cuore: Object = ClassDB.instantiate("EcsMondo")
	var n := int(cuore.get("N_COSE"))
	t.ok(n > 0, "il ponte dichiara delle cose ricordabili (%d)" % n)
	for i in n:
		var nome := str(cuore.call("nome_cosa", i))
		t.ok(nome != "", "la cosa %d ha un nome" % i)
		t.ok(VISITOR.LP_SIMBOLI.has(nome),
				"«%s» è una cosa che un chibi sa dire (esiste in LP_SIMBOLI)" % nome)
	(cuore as Node).free()


# =========================== 6. I VERBI DEL CABLAGGIO — TRASLOCATO
#
# Il censimento dei siti di emissione vive adesso in
# `tests/cases/test_siti_gesto.gd`, accanto alle prove COMPORTAMENTALI degli
# stessi siti (che cosa emettono davvero: il verbo, il posto, il
# destinatario). Qui era una sola scansione del sorgente con un OTTO scritto
# a mano — e con nove siti e un verbo emesso due volte, un sito poteva
# sparire senza far cadere niente. Di là il numero si DERIVA dalla tabella
# del ponte, e le due porte del dono hanno ciascuna la sua prova viva.
#
# Non se ne tiene una seconda copia qui: due censimenti in due file sono
# esattamente il modo in cui, in questo progetto, due tabelle gemelle hanno
# già preso strade diverse.


# ============================== 6-bis. IL NODO C'È DAVVERO, NEL MONDO VERO
#
# Tutto il resto di questo file può essere verde con il sistema SPENTO in
# partita: il gruppo «percezione» lo popola `Percezione._ready`, e un test
# che mette in scena il nodo da sé non si accorge mai che nel livello vero
# quel nodo non c'è. Senza di lui gli otto `call_group` parlano al vuoto —
# in silenzio, per sempre.

func _il_nodo_e_nel_mondo(t) -> void:
	var f := FileAccess.open("res://scenes/levels/MainLevel.tscn", FileAccess.READ)
	t.ok(f != null, "il livello vero si legge")
	if f == null:
		return
	var txt := f.get_as_text()
	# NON BASTA CHE IL PERCORSO COMPAIA: una `ext_resource` senza un nodo che
	# la porti è uno script caricato e mai messo in scena. (La prima stesura
	# cercava solo il percorso e restava verde cancellando il nodo.)
	var re := RegEx.new()
	re.compile('ext_resource type="Script" path="res://scenes/npc/Percezione\\.gd" id="([^"]+)"')
	var m := re.search(txt)
	t.ok(m != null, "il MainLevel conosce lo script della Percezione")
	if m == null:
		return
	t.ok(txt.contains('script = ExtResource("%s")' % m.get_string(1)),
			"…e c'è un NODO che lo porta: senza, gli otto siti parlano al vuoto per sempre")


# ================================= 7. LA TESTA SI GIRA DALLA PARTE GIUSTA
#
# IL RIG GUARDA −Z. Un `atan2` col segno sbagliato ha tenuto il fantasma del
# congedo di spalle a Mochi per mesi, sotto un commento che giurava il
# contrario, e due secondi fra le lucine non lo mostravano. Qui il segno si
# MISURA: corpo fermo con `_yaw = 0` (muso verso −Z), gesto alla sua destra
# (+X) ⇒ la testa deve girare in NEGATIVO; a sinistra, in positivo; davanti,
# quasi niente. Con la formula girata al contrario tutte e tre falliscono.

func _gira(v: Node3D, quanti: int) -> void:
	for _i in quanti:
		v._process(DT)


func _la_testa_si_gira_dalla_parte_giusta(t) -> void:
	# la banda del tetto, giudicata da fuori: sotto 0,55 rad (31°) una testa
	# girata non si distingue dall'oscillazione dell'idle, sopra 1,20 (69°)
	# il musetto esce dalla sagoma della testona e il collo si strappa
	t.ok(VISITOR.TESTA_MAX >= 0.55,
			"la testa si gira abbastanza da leggersi (più dell'oscillazione dell'idle)")
	t.ok(VISITOR.TESTA_MAX <= 1.20,
			"…e non tanto da rompere il collo")
	# I QUATTRO QUADRANTI, e i due DIETRO non sono un di più: sono il caso
	# comune (un vicino non ti sta quasi mai di fronte) ed è lì che una
	# decomposizione di Eulero può ribaltare il segno mentre i due casi a
	# novanta gradi restano verdi. Misurato con la sonda: 135° a destra dà
	# −0.900, a sinistra +0.900, cioè il collo gira dalla parte giusta e si
	# ferma al suo tetto — l'occhiata sopra la spalla.
	var casi := [
		[Vector3(6.0, 0, 0), -1.0, "alla sua destra"],
		[Vector3(-6.0, 0, 0), 1.0, "alla sua sinistra"],
		[Vector3(4.2, 0, 4.3), -1.0, "dietro, sopra la spalla destra"],
		[Vector3(-4.2, 0, 4.3), 1.0, "dietro, sopra la spalla sinistra"],
	]
	for caso in casi:
		var v := _corpo(t, 4501, Vector3.ZERO)
		v.set("_yaw", 0.0)     # muso verso −Z, la convenzione di tutto il rig
		v.call("guarda_gesto", caso[0], 6.0)
		_gira(v, 45)           # tre quarti di secondo: la molla è arrivata
		var y: float = (v.get("_head") as Node3D).rotation.y
		var verso: float = caso[1]
		t.ok(y * verso > 0.5,
				"la testa si gira %s (rotation.y = %.3f, atteso segno %s)"
						% [caso[2], y, ("−" if verso < 0.0 else "+")])
		# IL TETTO SI GIUDICA CON UN NUMERO CHE NON È IL TETTO: 1,35 rad sono
		# 77°, cioè oltre il limite anatomico di un collo — e verso quel
		# gesto il rig ne vorrebbe 90°, quindi senza clamp qui si arriva a
		# 1,57. (Misurato contro `TESTA_MAX` la prova restava verde anche
		# portando il tetto a 3 radianti.)
		t.ok(absf(y) <= 1.35,
				"…e non si strappa il collo: la testa resta dentro un'anatomia (%.3f)" % y)

	# davanti: la testa resta quasi dritta — e questa è la prova che non si
	# sta misurando semplicemente «una testa storta»
	var dritto := _corpo(t, 4502, Vector3.ZERO)
	dritto.set("_yaw", 0.0)
	dritto.call("guarda_gesto", Vector3(0, 0, -6.0), 6.0)
	_gira(dritto, 45)
	t.ok(absf((dritto.get("_head") as Node3D).rotation.y) < 0.35,
			"a un gesto che ha già davanti, la testa non si gira")

	# e IL CORPO NON SI MUOVE: la ricevuta è uno sguardo, non un guinzaglio.
	var fermo := _corpo(t, 4503, Vector3(2.0, 0, 2.0))
	var dove := fermo.global_position
	var stato := str(fermo.get("_state"))
	fermo.call("guarda_gesto", Vector3(-6.0, 0, 0), 6.0)
	_gira(fermo, 45)
	t.almost(fermo.global_position.distance_to(dove), 0.0,
			"chi ha visto NON si avvicina: il corpo resta dov'era", 0.02)
	t.eq(str(fermo.get("_state")), stato,
			"…e non cambia nemmeno quello che stava facendo")


# ============== 7-bis. LA RICEVUTA BATTE GLI ALTRI SGUARDI (e non il sonno)
#
# Il ramo della ricevuta sta in un punto preciso del blocco dello sguardo:
# SOTTO chi dorme e SOPRA `LOOK_STATES` e il giocatore vicino. Più in basso,
# quei due riscriverebbero la gaze il frame dopo e non si vedrebbe NIENTE —
# e il sistema sembrerebbe reagire a caso, che è il guasto peggiore di tutti.

func _lo_sguardo_batte_gli_altri(t) -> void:
	var gesto := Vector3(5.0, 0, 1.0)
	var v := _corpo(t, 4701, Vector3.ZERO)
	# `r_sniff` è uno degli stati che posano lo sguardo sull'oggetto esaminato
	v._enter_state("r_sniff")
	v._timer = 9999.0
	v.set("_target", Vector3(0, 0, -3.0))
	v.call("guarda_gesto", gesto, 5.0)
	_gira(v, 1)
	var face = v.get("_face")
	t.ok(face != null, "il chibi ha il volto vivo")
	if face != null:
		t.ok(bool(face.get("_gaze_has_point")), "…e gli occhi hanno un bersaglio")
		var p: Vector3 = face.get("_gaze_point")
		t.almost(p.distance_to(gesto + Vector3(0, 0.35, 0)), 0.0,
				"GLI OCCHI VANNO SUL GESTO, non sull'oggetto che stava annusando", 0.001)

	# ma chi dorme non guarda niente: quel ramo sta SOPRA il nostro, e deve
	# restarci — una ricevuta a occhi chiusi è una ricevuta falsa
	var dorme := _corpo(t, 4702, Vector3.ZERO)
	dorme._enter_state("tk_nap")
	dorme.call("guarda_gesto", gesto, 5.0)
	_gira(dorme, 1)
	var f2 = dorme.get("_face")
	if f2 != null:
		t.ok(not bool(f2.get("_gaze_has_point")),
				"chi dorme non guarda niente: il pisolino batte la ricevuta")


# ================================= 8. IL CANALE NON RESTA MAI FUORI POSA
#
# Se solo uno stato scrivesse questo canale, un'interruzione lo lascerebbe
# fuori posa per SEMPRE — una testa girata all'infinito verso un'aiuola. La
# rete è che l'orologio scende in cima al `_process` (per ogni stato) e che
# lo scostamento si SOMMA e torna a zero da solo.

func _la_testa_torna_sempre(t) -> void:
	var v := _corpo(t, 4601, Vector3.ZERO)
	v.set("_yaw", 0.0)
	v.call("guarda_gesto", Vector3(6.0, 0, 0), 1.0)
	_gira(v, 30)
	t.ok(absf((v.get("_head") as Node3D).rotation.y) > 0.5,
			"(intanto la testa è girata davvero)")
	# lo stato CAMBIA a metà sguardo: è il modo in cui un canale orfano si
	# incastra (il pasto, il concerto, il congedo — undici sistemi lo fanno)
	v._enter_state("r_sniff")
	v._timer = 9999.0
	_gira(v, 180)      # tre secondi: lo sguardo è scaduto da un pezzo
	t.almost(float(v.get("_tst_t")), 0.0, "l'orologio dello sguardo è sceso a zero", 0.001)
	t.almost(float(v.get("_tst_off")), 0.0,
			"…e lo scostamento della testa è tornato a zero DA SOLO", 0.01)
	t.ok(absf((v.get("_head") as Node3D).rotation.y) < 0.4,
			"la testa è tornata dentro la banda del suo stato, senza che nessuno la rimettesse a posto")

	# e chi si addormenta mentre guardava smette di guardare all'istante
	var addormentato := _corpo(t, 4602, Vector3.ZERO)
	addormentato.set("_yaw", 0.0)
	addormentato.call("guarda_gesto", Vector3(6.0, 0, 0), 6.0)
	_gira(addormentato, 30)
	addormentato._enter_state("tk_nap")
	_gira(addormentato, 120)     # due secondi: la molla del ritorno ha finito
	t.almost(float(addormentato.get("_tst_off")), 0.0,
			"chi si addormenta smette di guardare (e la testa torna)", 0.02)


# ================================ 9. UNA RAFFICA DI GESTI È UNA RICEVUTA
#
# La costruzione non ha lucchetto (`_try_place` sta su `is_action_pressed`) ed
# emette un gesto per PEZZO. Se ogni pezzo riarmasse la ricevuta, stendere un
# sentiero di quaranta pietre terrebbe i vicini entro nove metri con la testa
# girata verso il cursore per quaranta secondi filati — e la ricevuta
# smetterebbe di dire «ti ho vista» per dire «mi stanno fissando», sull'attività
# più ripetuta del gioco.
#
# La cura NON è abbassare `DURATA_SGUARDO` (un gesto solo deve restare
# leggibile): è che la testa si giri una volta per RICORDO, come il grafo fonde
# le ripetizioni. Qui si misura la FRAZIONE DI TEMPO a testa girata, che è
# esattamente quello che il giocatore vede — e si pretende che non dipenda da
# quanto in fretta si costruisce.

## Fa passare `sec` secondi di gioco su un corpo, sparando un gesto ogni `ogni`
## secondi **dal bus vero** (non da `guarda_gesto`: quel che si prova è la
## catena intera, cablaggio compreso). Torna quanto tempo la testa è stata
## girata di più di 0,45 rad e quante volte si è alzata.
func _raffica(perc: Node, corpo: Node3D, verbo: String, pos: Vector3,
		sec: float, ogni: float) -> Dictionary:
	var frames := int(sec / DT)
	var passo := maxi(1, int(round(ogni / DT)))
	var girata := 0.0
	var alzate := 0
	var su := false
	for i in frames:
		if i % passo == 0:
			perc.call("accaduto", verbo, pos)
		corpo._process(DT)
		var ora: bool = absf(float(corpo.get("_tst_off"))) > 0.45
		if ora and not su:
			alzate += 1
		su = ora
		if ora:
			girata += DT
	return {"girata": girata, "alzate": alzate, "tot": float(frames) * DT,
			"quota": girata / maxf(float(frames) * DT, 0.001)}


func _una_raffica_e_una_ricevuta(t) -> void:
	var gesto := Vector3(6.1, 0, 0)     # di traverso: la testa deve girarsi
	# UN GESTO SOLO resta pieno. È la prova che la cura non è stata «abbassare
	# la costante»: il gesto singolo — l'annaffiata, la pesca, il dono — è
	# quello che la ricevuta esiste per far leggere.
	var solo := _corpo(t, 4901, Vector3.ZERO)
	solo.set("_yaw", 0.0)
	var v1 := _villaggio(t, [solo])
	var m_solo := _raffica(v1["perc"] as Node, solo, "costruisce", gesto, 6.0, 99.0)
	t.eq(int(m_solo["alzate"]), 1, "un gesto solo alza la testa una volta")
	t.ok(float(m_solo["girata"]) > 2.5,
			"…e la tiene su per il gesto intero (%.2f s)" % float(m_solo["girata"]))

	# QUARANTA PEZZI, UNO AL SECONDO: il sentiero in piazza.
	var lento := _corpo(t, 4902, Vector3.ZERO)
	lento.set("_yaw", 0.0)
	var v2 := _villaggio(t, [lento])
	var m_lento := _raffica(v2["perc"] as Node, lento, "costruisce", gesto, 40.0, 1.0)
	# la soglia è indipendente dalle costanti che sorveglia: è una FRAZIONE DEL
	# TEMPO DI GIOCO, cioè la cosa che si vede. Prima della cura era 0.76.
	t.ok(float(m_lento["quota"]) < 0.35,
			"quaranta pezzi non fanno quaranta ricevute: testa girata il %.0f%% del tempo"
					% (float(m_lento["quota"]) * 100.0))
	# …e nemmeno il guasto opposto: se la seconda occhiata non arrivasse mai
	# più, costruire per dieci minuti non produrrebbe nessuna ricevuta.
	t.ok(int(m_lento["alzate"]) >= 2,
			"…ma la testa si rialza (%d volte in 40 s): la raffica non zittisce il vicino"
					% int(m_lento["alzate"]))

	# TRE PEZZI AL SECONDO: la stessa scena, costruita in fretta. La ricevuta
	# non deve dipendere da quanto svelto si tiene premuto — se dipendesse, il
	# gioco punirebbe chi costruisce di più.
	var svelto := _corpo(t, 4903, Vector3.ZERO)
	svelto.set("_yaw", 0.0)
	var v3 := _villaggio(t, [svelto])
	var m_svelto := _raffica(v3["perc"] as Node, svelto, "costruisce", gesto, 40.0, 0.33)
	t.ok(absf(float(m_svelto["quota"]) - float(m_lento["quota"])) < 0.10,
			"e va uguale a tre pezzi al secondo (%.0f%% contro %.0f%%)"
					% [float(m_svelto["quota"]) * 100.0, float(m_lento["quota"]) * 100.0])

	# DIECI MINUTI DI CANTIERE: il vicino continua a guardare ogni tanto.
	var lungo := _corpo(t, 4904, Vector3.ZERO)
	lungo.set("_yaw", 0.0)
	var v4 := _villaggio(t, [lungo])
	var m_lungo := _raffica(v4["perc"] as Node, lungo, "costruisce", gesto, 300.0, 1.0)
	t.ok(int(m_lungo["alzate"]) >= 10,
			"cinque minuti di cantiere: alza la testa %d volte, non una sola"
					% int(m_lungo["alzate"]))
	t.ok(float(m_lungo["quota"]) < 0.35,
			"…e resta un'occhiata, non uno sguardo fisso (%.0f%%)"
					% (float(m_lungo["quota"]) * 100.0))

	# UN GESTO DIVERSO IN MEZZO ALLA RAFFICA È UN GESTO NUOVO — nel grafo fa un
	# ricordo nuovo (la fusione vuole lo STESSO verbo), e quindi qui fa una
	# testa girata piena. Senza, chi costruisce potrebbe annaffiare accanto a un
	# vicino senza che quello se ne accorga mai.
	var misto := _corpo(t, 4905, Vector3.ZERO)
	misto.set("_yaw", 0.0)
	var v5 := _villaggio(t, [misto])
	_raffica(v5["perc"] as Node, misto, "costruisce", gesto, 20.0, 1.0)
	(v5["perc"] as Node).call("accaduto", "annaffia", gesto)
	t.almost(float(misto.get("_tst_t")), PERC.DURATA_SGUARDO,
			"un gesto DIVERSO in mezzo alla raffica riarma la ricevuta piena", 0.001)

	# E LA FINESTRA È QUELLA DEL GRAFO, non un numero di questo file: si legge
	# dal ponte e si prova dai due lati. Con una pausa più corta della finestra
	# il gesto è ancora la stessa cosa (nel grafo: `quante++`); con una più
	# lunga è una cosa nuova, e la testa si gira di nuovo. Se un domani
	# qualcuno cambia `FINESTRA_FUSIONE` in C++, questa prova segue da sola.
	var cost: Dictionary = (v5["cuore"] as Object).call("debug_grafo_costanti")
	var finestra := float(cost.get("finestra_fusione", 0.0))
	t.ok(finestra > 0.0, "il ponte dichiara la finestra di fusione (%.1f s)" % finestra)
	for caso in [[finestra * 0.5, false], [finestra + 2.0, true]]:
		var pausa := float(caso[0])
		var corpo := _corpo(t, 4906 + int(pausa * 10.0), Vector3.ZERO)
		corpo.set("_yaw", 0.0)
		var vv := _villaggio(t, [corpo])
		(vv["perc"] as Node).call("accaduto", "costruisce", gesto)
		# si aspetta che lo sguardo sia SCADUTO, poi la pausa vera
		for _i in int((PERC.DURATA_SGUARDO + pausa) / DT):
			corpo._process(DT)
		(vv["perc"] as Node).call("accaduto", "costruisce", gesto)
		var pieno: bool = absf(float(corpo.get("_tst_t")) - PERC.DURATA_SGUARDO) < 0.001
		t.eq(pieno, bool(caso[1]),
				("dopo una pausa più LUNGA della finestra la testa si rigira piena"
				if bool(caso[1]) else
				"dentro la finestra il gesto ripetuto non riarma la ricevuta piena"))


# ================================ 10. IL TETTO DEL COLLO (la somma, non i pezzi)
#
# Su `_head.rotation.y` scrivono TRE cose che si sommano: lo stato (fino a 0.30
# nell'idle), la ricevuta (`TESTA_MAX` 0.90) e la recita del corpo (`hy_amp`:
# «sguardo sfuggente» 0.55). Nessuna delle tre da sola esce dall'anatomia; la
# loro somma sì — misurata a 1.40 rad, cioè 80°, e a quell'angolo la faccia non
# c'è più: una palla di pelo con un nasino che sporge dal bordo. È la trappola
# della «bocca in volo davanti al muso», sullo stesso rig.
#
# Il numero si giudica con una soglia che NON è la costante: 1.25 rad viene dal
# provino (`tools/provino_collo.gd`), dove a 1.20 la faccia si legge ancora e a
# 1.35 è sparita.

func _il_tetto_del_collo(t) -> void:
	t.ok(VISITOR.COLLO_MAX >= VISITOR.TESTA_MAX,
			"il tetto del collo non stringe più della ricevuta stessa")
	t.ok(VISITOR.COLLO_MAX <= 1.25,
			"…e resta dentro l'anatomia misurata col provino")

	# IL CASO PEGGIORE, e non è di laboratorio: un vicino col telegrafo del
	# corpo addosso (`sguardo_sfuggente`, la posa della ribellione) che riceve
	# una ricevuta di traverso.
	var v := _corpo(t, 5001, Vector3.ZERO)
	v.set("_yaw", 0.0)
	v.set_meta("postura", "sguardo_sfuggente")
	v.call("guarda_gesto", Vector3(6.0, 0, 0), 40.0)
	var picco := 0.0
	var picco_ric := 0.0
	for _i in 1200:                    # venti secondi: le due onde si allineano
		v._process(DT)
		picco = maxf(picco, absf((v.get("_head") as Node3D).rotation.y))
		picco_ric = maxf(picco_ric, absf(float(v.get("_tst_off"))))
	t.ok(picco <= 1.25,
			"col telegrafo addosso il collo resta dentro l'anatomia (%.3f rad, %.0f°)"
					% [picco, rad_to_deg(picco)])
	# …E LA PROVA STA MISURANDO IL CASO VERO: senza questa riga il test
	# resterebbe verde anche con una ricevuta che non gira più la testa.
	t.ok(picco > 0.9,
			"…(e la somma ci arriva davvero, al tetto: %.3f rad)" % picco)

	# IL TETTO NON RUBA NIENTE A CHI NON CI ARRIVA. Un vicino sereno, stessa
	# ricevuta, resta com'era: il tetto è una rete, non una manopola.
	var sereno := _corpo(t, 5002, Vector3.ZERO)
	sereno.set("_yaw", 0.0)
	sereno.call("guarda_gesto", Vector3(6.0, 0, 0), 40.0)
	_gira(sereno, 60)
	var y := absf((sereno.get("_head") as Node3D).rotation.y)
	t.ok(y > 0.5 and y < VISITOR.COLLO_MAX,
			"chi non ci arriva non lo tocca nessuno (%.3f rad)" % y)

	# E QUANDO LO SGUARDO SCADE IL TETTO NON LASCIA RESIDUI: è una correzione
	# additiva come le altre due, e si toglie il frame dopo. Se restasse
	# addosso, il vicino resterebbe con la testa storta per sempre — il guasto
	# del canale orfano, un piano più in alto.
	#
	# SI MISURA SUL BANCO DELLA TENUTA (`r_sniff`), e la prima stesura di
	# questa prova non lo faceva: nella seduta lo stato riscrive l'imbardata IN
	# ASSOLUTO a ogni frame, quindi cancella il residuo prima che si possa
	# vedere. Smontando la riga che toglie il tetto, il test restava verde.
	var v2 := _banco_tenuta(t, 5003, Vector3.ZERO)
	v2.set_meta("postura", "sguardo_sfuggente")
	v2.call("guarda_gesto", Vector3(6.0, 0, 0), 30.0)
	var tagliato := 0.0
	for _i in 1800:                    # trenta secondi: le due onde si allineano
		v2._process(DT)
		tagliato = maxf(tagliato, absf(float(v2.get("_capp_appl"))))
	t.ok(tagliato > 0.05,
			"…(e intanto il tetto ha tagliato davvero: %.3f rad)" % tagliato)
	v2.set_meta("postura", "sereno")
	_gira(v2, 2400)                    # quaranta secondi: tutto è rientrato
	t.almost(float(v2.get("_capp_appl")), 0.0,
			"scaduto lo sguardo, il tetto non tiene più niente", 0.0001)
	t.almost((v2.get("_head") as Node3D).rotation.y, 0.0,
			"…e la testa è tornata a posto DA SOLA, senza residui del tetto", 0.02)


# ============================== 11. LA TENUTA È VIVA (nessun adesivo)
#
# «Mai posa + adesivo»: la differenza fra vivo e spento è il micro-movimento, e
# un sin() puro si smaschera in due cicli. Qui si misura la TENUTA — i secondi
# in cui la testa è ferma sul bersaglio — perché è lì che un'animazione muore.
#
# La prima stesura sottraeva per intero la posa dello stato, cioè cancellava
# esattamente il dondolio di cui il suo stesso commento si vantava: due
# testimoni affiancati davano lo stesso angolo al quinto decimale.

## IL BANCO DELLA TENUTA: un corpo in `r_sniff`, l'unico stato che NON scrive
## l'imbardata (`_anim_inspect` posa x e z e lascia stare y).
##
## Non è una comodità, è la differenza fra misurare e credere di misurare.
## Nella seduta il «guardarsi intorno» dell'idle vale ±0,3 rad con un periodo
## di 12,6 s e riscrive il canale IN ASSOLUTO a ogni frame: ci si legge sopra
## qualunque cosa. Misurando lì, TRE guasti su cinque restavano verdi — il
## tetto che non si toglie, l'orologio unico al posto dei due, lo scarto
## personale spento — perché il test guardava il respiro del corpo credendo di
## guardare lo sguardo.
func _banco_tenuta(t, seme: int, pos: Vector3) -> Node3D:
	var v := _corpo(t, seme, pos)
	v.set("_yaw", 0.0)
	v._enter_state("r_sniff")
	v.set("_timer", 9999.0)
	return v


## Campiona l'imbardata della testa per `quanti` frame, dopo averla lasciata
## arrivare. Torna la serie.
func _serie_testa(v: Node3D, quanti: int) -> Array:
	var out: Array = []
	for _i in quanti:
		v._process(DT)
		out.append((v.get("_head") as Node3D).rotation.y)
	return out


func _escursione(s: Array) -> float:
	var lo := 99.0
	var hi := -99.0
	for x in s:
		lo = minf(lo, float(x))
		hi = maxf(hi, float(x))
	return hi - lo


## Quante volte la serie CAMBIA VERSO: la misura della velocità che
## l'escursione non sa dare.
func _inversioni(s: Array) -> int:
	var n := 0
	var segno := 0
	for i in range(1, s.size()):
		var d := float(s[i]) - float(s[i - 1])
		if d == 0.0:
			continue
		var sg := 1 if d > 0.0 else -1
		if segno != 0 and sg != segno:
			n += 1
		segno = sg
	return n


func _media(s: Array) -> float:
	var tot := 0.0
	for x in s:
		tot += float(x)
	return tot / maxf(float(s.size()), 1.0)


func _la_tenuta_e_viva(t) -> void:
	var gesto := Vector3(6.0, 0, 0)
	# DUE TESTIMONI, stesso posto, stesso verso, stesso bersaglio: tutto uguale
	# tranne il genoma. **Lo stesso posto è voluto**: scostandoli anche solo di
	# un metro, una parte della differenza sarebbe geometria — e la prova non
	# saprebbe più dire se i due sono diversi o se sono solo altrove.
	var a := _banco_tenuta(t, 5101, Vector3.ZERO)
	var b := _banco_tenuta(t, 5102, Vector3.ZERO)
	for c in [a, b]:
		c.call("guarda_gesto", gesto, 240.0)
	_gira(a, 60)
	_gira(b, 60)
	var sa := _serie_testa(a, 240)      # quattro secondi di TENUTA
	var sb := _serie_testa(b, 240)
	var scarto := 0.0
	for i in sa.size():
		scarto = maxf(scarto, absf(float(sa[i]) - float(sb[i])))
	t.ok(scarto > 0.02,
			"due testimoni non hanno la stessa identica testa (%.3f rad di scarto)"
					% scarto)

	# …E NON È SOLO QUESTIONE DI FASE. Su un minuto intero il vagare si media
	# via e resta lo SCARTO DELLA MIRA: chi guarda le zampe, chi la faccia, chi
	# la cosa. Senza questa misura, `MIRA_PERSONALE` poteva andare a zero senza
	# che nessuno se ne accorgesse (le fasi diverse coprivano tutto).
	var la := _serie_testa(a, 3600)
	var lb := _serie_testa(b, 3600)
	t.ok(absf(_media(la) - _media(lb)) > 0.01,
			"…e su un minuto mirano a due punti diversi (%.4f rad)"
					% absf(_media(la) - _media(lb)))

	# LA TENUTA NON È FERMA. Con un bersaglio fisso e nessun micro-movimento
	# qui uscirebbe zero: è la firma dell'adesivo.
	t.ok(_escursione(sa) > 0.03,
			"la testa si muove mentre guarda (%.3f rad di escursione in 4 s)"
					% _escursione(sa))

	# E NON SI RICHIUDE MAI. Due orologi incommensurabili: confrontando la
	# tenuta con sé stessa un periodo dopo (quello dell'onda lenta, 7,57 s) le
	# due finestre devono essere DIVERSE. Con un sin() solo sarebbero identiche.
	var c := _banco_tenuta(t, 5103, Vector3.ZERO)
	c.call("guarda_gesto", gesto, 90.0)
	_gira(c, 120)
	var periodo := int((TAU / 0.83) / DT)
	var f1 := _serie_testa(c, periodo)
	var f2 := _serie_testa(c, periodo)
	var diff := 0.0
	for i in mini(f1.size(), f2.size()):
		diff = maxf(diff, absf(float(f1[i]) - float(f2[i])))
	t.ok(diff > 0.01,
			"l'imbardata non si richiude su sé stessa (%.3f rad fra un periodo e l'altro)"
					% diff)

	# IL CORPO CONTINUA A RESPIRARE SOTTO LO SGUARDO. Due corpi identici, stessa
	# ricevuta: uno seduto (dove lo stato si guarda intorno) e uno sul banco
	# (dove nessuno scrive l'imbardata). Se la posa dello stato venisse
	# cancellata per intero — com'era, e come il commento giurava di NON fare —
	# i due si muoverebbero uguali, e la testa sarebbe un adesivo sul collo.
	#
	# ⚠️ L'ASSESTAMENTO SI AVANZA A MANO, e non è pignoleria: `_anim_sit`
	# accumula `_sit_t` con `get_process_delta_time()` — l'orologio VERO del
	# motore, non il `delta` che il test passa — e finché l'assestamento non è
	# finito il «guardarsi intorno» vale ZERO (`calo` moltiplica l'ampiezza).
	# In una suite lenta i frame veri sono lunghi, l'assestamento finisce
	# comunque e la prova passa; su una macchina svelta (o eseguendo questo
	# caso da solo) `_sit_t` resta a zero, le due escursioni sono IDENTICHE e
	# l'asserzione diventa rossa senza che niente si sia rotto. Era un test
	# che misurava il carico della macchina.
	var seduto := _corpo(t, 5106, Vector3.ZERO)
	seduto.set("_yaw", 0.0)
	seduto.set("_sit_t", 6.0)          # accomodato da un pezzo: `calo` ≈ 0
	var banco := _banco_tenuta(t, 5106, Vector3.ZERO)
	for c3 in [seduto, banco]:
		c3.call("guarda_gesto", gesto, 90.0)
		_gira(c3, 120)                 # due secondi: la molla è arrivata
	var e_seduto := _escursione(_serie_testa(seduto, 480))
	var e_banco := _escursione(_serie_testa(banco, 480))
	t.ok(e_seduto > e_banco * 1.6,
			"sotto lo sguardo il corpo continua a respirare (%.3f rad da seduto contro %.3f)"
					% [e_seduto, e_banco])

	# L'ETÀ SI SENTE, e le ORECCHIE NON SCATTANO. Un anziano guarda più lento e
	# più corto; e questo canale è solo l'imbardata della testa — se toccasse le
	# orecchie, a un anziano scatterebbero (la lezione già pagata).
	#
	# MEZZO MINUTO, non quattro secondi: su una finestra corta la differenza è
	# tutta nella VELOCITÀ (l'anziano non fa in tempo a percorrere la sua
	# escursione) e l'AMPIEZZA può andare a zero senza che il test se ne
	# accorga. Su trenta secondi tutti e due percorrono tutto, e resta
	# l'ampiezza — che è la cosa che si voleva provare.
	var giovane := _banco_tenuta(t, 5104, Vector3.ZERO)
	var vecchio := _banco_tenuta(t, 5104, Vector3.ZERO)  # STESSO genoma
	vecchio.call("set_eta", 1.0)
	for c1 in [giovane, vecchio]:
		c1.call("guarda_gesto", gesto, 90.0)
		_gira(c1, 60)
	var s_g := _serie_testa(giovane, 1800)
	var s_v := _serie_testa(vecchio, 1800)
	t.ok(_escursione(s_v) < _escursione(s_g) * 0.85,
			"chi ha vissuto guarda più CORTO dei giovani (%.4f contro %.4f rad)"
					% [_escursione(s_v), _escursione(s_g)])
	# …e più LENTO, che è l'altra metà e ha bisogno di una misura sua: la
	# lentezza non si vede nell'escursione (su una finestra lunga anche il
	# lento la percorre tutta), si vede in quante volte la testa CAMBIA VERSO.
	t.ok(_inversioni(s_v) < _inversioni(s_g),
			"…e più LENTO: cambia verso %d volte in mezzo minuto, il giovane %d"
					% [_inversioni(s_v), _inversioni(s_g)])

	# le orecchie: due corpi identici, uno con la ricevuta addosso e uno senza.
	# Devono avere le stesse orecchie, frame per frame.
	var con_ric := _corpo(t, 5105, Vector3.ZERO)
	var senza := _corpo(t, 5105, Vector3.ZERO)
	for c2 in [con_ric, senza]:
		c2.set("_yaw", 0.0)
		c2.call("set_eta", 1.0)
	con_ric.call("guarda_gesto", gesto, 60.0)
	var scarto_or := 0.0
	for _i in 180:
		con_ric._process(DT)
		senza._process(DT)
		var o1: Array = con_ric.get("_c_ears")
		var o2: Array = senza.get("_c_ears")
		if o1.size() > 0 and o2.size() > 0:
			scarto_or = maxf(scarto_or,
					absf((o1[0] as Node3D).rotation.x - (o2[0] as Node3D).rotation.x))
	t.almost(scarto_or, 0.0,
			"la ricevuta non tocca le orecchie: a un anziano non scattano", 0.0001)


# ============ 11-bis. LA FORMA NEL TEMPO: scatta e torna via PIANO
#
# «Mai posa + adesivo»: la differenza fra vivo e spento è il micro-movimento,
# e la prima cosa che si vede di uno sguardo non è l'angolo — è la SVEGLIA.
# Una testa che parte e torna alla stessa velocità è una molla, ed è la cosa
# che smaschera un'animazione in due cicli.
#
# `TESTA_VAI` (9.0) e `TESTA_TORNA` (4.0) sono le due metà di
# quell'asimmetria, e nessuna delle due era sorvegliata: portarle allo stesso
# valore — o addirittura invertirle, col ritorno a scatto — lasciava la suite
# VERDE. Qui si misurano i due tempi VERI sul rig, e il giudizio è sul loro
# RAPPORTO, che non dipende da nessuna delle due costanti presa da sola.
#
# Si misura sul banco della tenuta (`r_sniff`): nella seduta lo stato
# riscrive l'imbardata in assoluto e ci si legge sopra qualunque cosa.

## Il primo istante in cui la serie soddisfa il predicato, in secondi (o −1).
func _quando(serie: Array, soglia: float, sotto: bool) -> float:
	for i in serie.size():
		var x := float(serie[i])
		if (x <= soglia) if sotto else (x >= soglia):
			return float(i + 1) * DT
	return -1.0


func _campiona_off(v: Node3D, quanti: int) -> Array:
	var out: Array = []
	for _i in quanti:
		v._process(DT)
		out.append(absf(float(v.get("_tst_off"))))
	return out


func _la_ricevuta_e_asimmetrica(t) -> void:
	var v := _banco_tenuta(t, 5301, Vector3.ZERO)
	var tenuta := 2.0
	v.call("guarda_gesto", Vector3(6.0, 0, 0), tenuta)
	var su := _campiona_off(v, int(tenuta / DT))
	# IL RIFERIMENTO È LA TENUTA ASSESTATA, non il picco: la mira VAGA
	# (`_vaga`, due orologi incommensurabili), e il massimo di quattro
	# secondi capita quando le due onde si allineano — cioè a un istante che
	# non ha niente a che vedere con la molla che si sta misurando.
	var meta: Array = su.slice(su.size() / 2)
	var quota := _media(meta)
	t.ok(quota > 0.5, "(la testa si è girata davvero: %.3f rad di tenuta)" % quota)
	# lo sguardo è scaduto esattamente adesso: da qui la molla torna
	var giu := _campiona_off(v, int(3.0 / DT))

	# I DUE TEMPI SI PRENDONO A 63/37%, cioè al tempo caratteristico della
	# molla, e non al 90/10 del traguardo. Vicino al traguardo la mira che
	# vaga fa oscillare il bersaglio attorno allo scostamento già raggiunto,
	# e la molla continua a cambiare verso: l'ultimo decimo di strada misura
	# il vagare, non la velocità. (MISURATO: al 90% la salita usciva 0,417 s
	# contro i 0,256 della molla pura, e il rapporto scendeva a 1,44 — cioè
	# il test avrebbe raccontato un'asimmetria più tiepida del vero.)
	var salita := _quando(su, quota * 0.63, false)
	var discesa := _quando(giu, quota * 0.37, true)
	t.ok(salita > 0.0 and discesa > 0.0,
			"i due tempi si misurano (salita %.3f s, ritorno %.3f s)" % [salita, discesa])
	if salita <= 0.0 or discesa <= 0.0:
		return

	# LE DUE SOGLIE ASSOLUTE. Vengono dal comportamento, non dalle costanti:
	# una testa che ci mette più di due decimi a partire non SCATTA più —
	# sotto quel tempo si legge come una reazione, sopra come uno spostarsi;
	# e un rientro più svelto di due decimi è uno scatto all'indietro, cioè
	# due scatti, che è precisamente la molla che questo file esiste per non
	# avere.
	t.ok(salita < 0.20,
			"la testa SCATTA verso il gesto (il tempo della molla è %.3f s)" % salita)
	t.ok(discesa > 0.20,
			"…e ci torna via PIANO (%.3f s)" % discesa)
	# E IL RAPPORTO, che è la misura vera dell'asimmetria: non dipende
	# dall'ampiezza, non dipende dal bersaglio, e cade sia portando le due
	# costanti allo stesso valore sia invertendole. Misurato: 2,25.
	t.ok(discesa / salita > 1.6,
			"il ritorno è %.2f volte più lungo dell'andata: l'attenzione è asimmetrica"
					% (discesa / salita))
	# …e non è una lentezza qualunque: un ritorno dieci volte più lungo
	# sarebbe una testa che resta appesa, cioè l'adesivo con un'altra faccia.
	t.ok(discesa / salita < 4.0,
			"…ma la testa TORNA, non resta appesa (%.2f volte)" % (discesa / salita))


# ========================= 12. LA SCENA RARA È INTOCCABILE (dal bus vero)
#
# Le scene rare sono la cosa più preziosa del gioco perché sono rare: il
# concerto, il coro attorno al carillon, il nascondino, il raduno al Grande
# Albero la sera del lutto, la prima parola di un cucciolo. Basta un pezzo posato
# a nove metri e tutte quelle teste si girano verso il cursore.
#
# `puo_vedere` lo prova sul predicato; qui si prova sulla CATENA INTERA — e
# soprattutto si prova che la valvola si RIAPRE, cioè che `chiudi_scena` esiste
# ed è la controparte di `apri_scena` (senza, un concerto finito presto
# lascerebbe il vicino sordo per tutti i secondi che avanzano).

func _la_scena_rara_e_intoccabile(t) -> void:
	var gesto := Vector3(6.0, 0, 0)
	var chi := _corpo(t, 5201, Vector3.ZERO, true)
	chi.set("_yaw", 0.0)
	var v := _villaggio(t, [chi])
	chi.call("apri_scena", 30.0)
	(v["perc"] as Node).call("accaduto", "costruisce", gesto)
	_gira(chi, 45)
	t.eq((chi as Testimone).sguardi.size(), 0,
			"chi vive una scena rara non riceve nemmeno la chiamata")
	t.eq(_ricordi(v, 0).size(), 0, "…e il gesto non entra nella sua memoria")
	t.almost(absf((chi.get("_head") as Node3D).rotation.y), 0.0,
			"…e la testa resta dov'era: la scena non si rompe", 0.35)

	# LA SCENA FINISCE, E IL MONDO TORNA. È la metà che mancava: senza
	# `chiudi_scena` una scena aperta «fino a stasera» e sciolta dopo cinque
	# secondi lascerebbe quel vicino cieco per tutto il resto.
	chi.call("chiudi_scena")
	t.ok(not chi.call("in_scena"), "…e a scena chiusa il vicino è di nuovo nel mondo")
	(v["perc"] as Node).call("accaduto", "costruisce", gesto)
	_gira(chi, 45)
	t.eq((chi as Testimone).sguardi.size(), 1,
			"lo stesso gesto, a scena chiusa, adesso lo vede")
	t.eq(_ricordi(v, 0).size(), 1, "…e se lo ricorda")


# ================= 13. LE TRE GUARDIE: un guasto non ne fa altri cinque
#
# Tre righe difensive che nessun test toccava, e tutte e tre hanno la stessa
# forma: una riga del registro può essere INCOMPLETA — un corpo liberato a
# metà frame, un residente non ancora censito, un cuore che non c'è ancora
# perché nessuno è stato censito — e il sistema deve degradare verso il
# silenzio, mai verso il rumore.
#
# Il guasto che chiudono NON è «esplode»: è che dopo l'esplosione **gli
# altri testimoni della stessa lista non ricevono più niente**. Un errore a
# runtime in GDScript interrompe la funzione, e il ciclo di `accaduto` si
# ferma lì. Perciò qui non si guarda l'errore: si guarda CHI VIENE DOPO, e
# soprattutto CHI NON DEVE MUOVERSI.
#
# ⚠️ **UNA DELLE TRE NON È FALSIFICABILE DA UN'ASSERZIONE, ed è dichiarato.**
# Il caso (c) — `_cabla` che risponde «sì» senza cuore — è MISURATO
# equivalente: senza la guardia la funzione va in errore alla riga dopo,
# quindi `accaduto` esce lo stesso e `testimoni` risponde lo stesso una lista
# vuota. L'unica firma che resta è un `SCRIPT ERROR`, e un errore a runtime
# non fa fallire un test in questo runner. Quel che il caso (c) fa — ed è la
# ragione per cui c'è — è **percorrere quella strada**: prima di lui nessun
# test chiamava mai la percezione su un villaggio senza cuore, quindi la
# guardia poteva sparire senza produrre nemmeno un errore. Adesso ne produce
# due, e il conto degli errori (che in questo progetto fa parte della
# consegna: deve dare ZERO) li vede.

## Un registro che restituisce le righe che gli si mettono in bocca: serve a
## far arrivare a `_testimonia` una riga guasta, che è precisamente ciò
## contro cui quella guardia esiste (un corpo liberato fra la costruzione
## della lista e il ciclo che la consuma).
class RegistroStorto extends "res://scenes/npc/Visitors.gd":
	var righe_finte: Array = []
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		add_to_group("visitors")
	func testimoni(_pos: Vector3, _raggio: float) -> Array:
		return righe_finte


## Un registro senza cuore: è il villaggio appena aperto, prima che qualcuno
## sia stato censito (`Visitors._ensure_ecs` gira al primo ciclo del sonno).
class RegistroSenzaCuore extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		add_to_group("visitors")
	func cuore() -> Object:
		return null


func _le_tre_guardie(t) -> void:
	var gesto := Vector3(0, 0, 0)

	# (a) LA RIGA GUASTA NON ZITTISCE CHI VIENE DOPO. La lista arriva con un
	# corpo che non c'è più al primo posto e un testimone vero al secondo.
	for vecchio in t.tree().get_nodes_in_group("visitors"):
		(vecchio as Node).remove_from_group("visitors")
	var buono := _corpo(t, 5301, Vector3(2.0, 0, 0), true)
	var storto = t.stage(RegistroStorto.new())
	var cuore: Object = ClassDB.instantiate("EcsMondo")
	(cuore as Node).name = "CuoreSonno"
	(storto as Node).add_child(cuore)
	storto.set("_ecs", cuore)
	var id_buono: int = cuore.call("registra", PackedStringArray([]), "")
	var id_perso: int = cuore.call("registra", PackedStringArray([]), "")
	# la riga SENZA MEMORIA: il corpo c'è, l'entità no. È l'altra metà della
	# stessa guardia, ed è quella che si VEDE — una testa che si gira per un
	# gesto che nessuno inciderà è la ricevuta senza la conseguenza, cioè
	# esattamente l'inversione che tutto questo file esiste per impedire.
	var senza_memoria := _corpo(t, 5305, Vector3(2.5, 0, 0), true)
	storto.righe_finte = [
		{"node": null, "ecs": id_perso, "label": "sparito"},
		{"node": senza_memoria, "ecs": -1, "label": "non censito"},
		{"node": buono, "ecs": id_buono, "label": "V0"},
	]
	var perc = t.stage(PERC.new())
	perc.call("accaduto", "annaffia", gesto)
	t.eq((buono as Testimone).sguardi.size(), 1,
			"una riga guasta in cima alla lista non zittisce il testimone che viene dopo")
	t.eq((cuore.call("debug_grafo", id_buono) as Dictionary).get("ricordi", []).size(), 1,
			"…e il suo ricordo si incide lo stesso")
	t.eq((cuore.call("debug_grafo", id_perso) as Dictionary).get("ricordi", []).size(), 0,
			"mentre la riga senza corpo non incide niente: si scarta INTERA")
	t.eq((senza_memoria as Testimone).sguardi.size(), 0,
			"e chi non ha una memoria NON gira la testa: mai una ricevuta senza il suo ricordo")

	# (b) IL RESIDENTE NON ANCORA CENSITO si salta, e non porta via gli
	# altri. `testimoni()` è la funzione di PRODUZIONE: la riga senza «ecs»
	# è quella di chi è appena nato o appena arrivato, nella finestra prima
	# che il ciclo del sonno gli dia un'entità.
	for vecchio in t.tree().get_nodes_in_group("visitors"):
		(vecchio as Node).remove_from_group("visitors")
	var nuovo := _corpo(t, 5302, Vector3(1.0, 0, 0))
	var censito := _corpo(t, 5303, Vector3(1.5, 0, 0))
	var v2 := _villaggio(t, [censito])
	var righe: Array = (v2["vis"] as Node).get("_residents")
	# la riga di chi non ha ancora una memoria: NIENTE chiave «ecs», in TESTA
	righe.insert(0, {"node": nuovo, "label": "V9", "dna": nuovo.dna,
			"cell": Vector2i(9, 0), "species": "chibi"})
	var visti: Array = (v2["vis"] as Node).call("testimoni", gesto, PERC.RAGGIO)
	t.eq(visti.size(), 1,
			"chi non ha ancora una memoria non è un testimone (e non fa cadere la lista)")
	if visti.size() == 1:
		t.eq(str((visti[0] as Dictionary)["label"]), "V0",
				"…e quello censito c'è, anche stando DOPO la riga incompleta")

	# (c) SENZA CUORE SI TACE, e si RIPROVA. Il villaggio appena aperto non ha
	# ancora un registro ECS: un gesto lì non deve incidere niente e non deve
	# far girare nessuna testa — ma appena il cuore arriva, tutto riparte.
	for vecchio in t.tree().get_nodes_in_group("visitors"):
		(vecchio as Node).remove_from_group("visitors")
	var solo := _corpo(t, 5304, Vector3(2.0, 0, 0), true)
	var senza = t.stage(RegistroSenzaCuore.new())
	var righe2: Array[Dictionary] = [{"node": solo, "label": "V0", "dna": solo.dna,
			"cell": Vector2i(0, 0), "species": "chibi", "ecs": 0}]
	senza.set("_residents", righe2)
	var perc2 = t.stage(PERC.new())
	t.eq(perc2.call("testimoni", gesto, PERC.RAGGIO), [],
			"senza cuore la percezione non sa dire chi c'era, e risponde una lista VUOTA")
	perc2.call("accaduto", "annaffia", gesto)
	t.eq((solo as Testimone).sguardi.size(), 0,
			"…e nessuno gira la testa per un gesto che non si potrà ricordare")

