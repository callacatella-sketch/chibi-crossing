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
	func guarda_gesto(pos: Vector3, dur: float) -> void:
		sguardi.append({"pos": pos, "dur": dur,
				"prima": (banco.conta() if banco != null else -1)})
		super(pos, dur)


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
	_i_verbi_del_cablaggio(t)
	_il_nodo_e_nel_mondo(t)
	_la_testa_si_gira_dalla_parte_giusta(t)
	_lo_sguardo_batte_gli_altri(t)
	_la_testa_torna_sempre(t)


# --------------------------------------------------------------- il banco

## Un corpo vero, sveglio, fermo, in mano a nessuno.
func _corpo(t, seme: int, pos: Vector3, spia := false) -> Node3D:
	var v = (Testimone.new() if spia else VISITOR.new())
	v.dna = DNA.generate(seme)
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


# =========================== 6. I VERBI DEL CABLAGGIO ESISTONO DAVVERO
#
# Gli otto siti di emissione scrivono il verbo come PAROLA, e la parola la
# traduce il ponte. Una parola sbagliata non diventa un errore rumoroso: il
# gesto semplicemente non lo vede mai nessuno, per sempre, con la suite
# verde. Qui il cablaggio È testo, quindi si legge il testo — ed è la stessa
# eccezione dichiarata di `test_scena_cablaggi._test_nessun_gruppo_fantasma`,
# per lo stesso motivo: non c'è un altro modo di sapere cosa emettono
# davvero i siti veri senza istanziare mezzo gioco.

func _i_verbi_del_cablaggio(t) -> void:
	var re := RegEx.new()
	re.compile('call_group\\(\\s*"percezione",\\s*"accaduto",\\s*"([a-z_]+)"')
	var trovati := {}
	var siti := 0
	for path in _tutti("res://scenes", ".gd"):
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		for m in re.search_all(f.get_as_text()):
			siti += 1
			trovati[m.get_string(1)] = true

	var cuore: Object = ClassDB.instantiate("EcsMondo")
	t.ok(siti >= 8, "il gioco ha almeno otto siti che emettono un gesto (%d)" % siti)
	for verbo in trovati:
		t.ok(int(cuore.call("indice_verbo", str(verbo))) >= 0,
				"il verbo «%s» che il gioco emette esiste nel ponte" % verbo)
	# E NESSUN VERBO MORTO: se il ponte ne conosce uno che nessun sito
	# emette, quel verbo è una riga di tabella che non succede mai.
	for i in int(cuore.get("N_VERBI")):
		var nome := str(cuore.call("nome_verbo", i))
		t.ok(trovati.has(nome),
				"il verbo «%s» lo emette qualcuno: nessuna riga morta nella tabella" % nome)
	(cuore as Node).free()


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
