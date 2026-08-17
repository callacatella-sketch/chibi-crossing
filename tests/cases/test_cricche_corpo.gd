extends RefCounted
## LE CRICCHE SI VEDONO — la prova che il predicato è arrivato sullo schermo.
##
## `test_cricche.gd` prova che il gruppo è OSSERVATO e non deciso. Questo file
## prova l'altra metà, e cioè che quella osservazione **produce qualcosa che
## un giocatore può vedere** — senza che il gioco gliela dica.
##
## ============================================================
## COSA CERCA DI ROMPERE, QUESTO FILE
## ============================================================
## Tre guasti, e sono in ordine di gravità crescente.
##
## 1. **IL DUETTO CHE ESCE A METÀ.** Un Punto solitario in mezzo al prato il
##    giocatore lo attribuisce a tutt'altro — a quello che stava facendo lui,
##    che è precisamente ciò che il vocabolario del corpo gli ha insegnato a
##    fare. Un duetto troncato non attenua l'effetto: **lo inverte**, e ha
##    già speso il gettone di tutti. Qui l'indivisibilità si rompe con la
##    mutazione PLAUSIBILE (accendere prima chi apre e poi scoprire che
##    l'altro non può), non con quella impossibile.
##
## 2. **IL SOLITARIO CHE SEMBRA RIFIUTATO.** È il guasto peggiore che questa
##    meccanica possa produrre, e non lo direbbe nessuna asserzione sulle
##    cricche: si vede solo guardando **chi è fuori**. Il caso
##    `_chi_sta_da_solo_non_cambia_di_un_bit` mette un terzo residente in
##    mezzo a una coppia che si ritrova e pretende che per lui non cambi
##    NIENTE — non un gesto, non un lease, non un metro d'ancora.
##
## 3. **IL GIOCATORE LASCIATO FUORI.** Se l'ancora del ritrovo salisse sopra
##    quella di Mochi, il villaggio si raggrupperebbe altrove **proprio nel
##    momento in cui arrivi**: il giocatore imparerebbe senza una parola di
##    essere quello di troppo. L'ordine delle quattro ancore è quindi una
##    prova, non un commento.
##
## ============================================================
## IL BANCO — corpi VERI, usciere VERO
## ============================================================
## Niente doppi che ri-implementano quello che si sta provando: la lezione
## del `Corpo` di `test_deduzioni` (un `Node3D` che rifaceva `collo_ci_arriva`
## col conto giusto, e teneva verde una valvola che si poteva sostituire con
## una costante **in tutte e due le direzioni**) e quella del `MotoreFinto`
## della Fase 5. Qui il `Visitors` è quello del gioco col solo `_ready`
## scavalcato — la forma di `test_regia.Registro` — e i corpi sono `Visitor`
## col rig di `ChibiBuilder`. Di finto c'è **l'orologio** (che è un dato, non
## un comportamento) e il giocatore (un `Node3D`: all'usciere serve solo la
## sua posizione).

const VISITOR := preload("res://scenes/npc/Visitor.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")
const CRICCHE := preload("res://scenes/npc/Cricche.gd")
const GESTI := preload("res://scenes/npc/Gesti.gd")
const REGIA := preload("res://scenes/npc/Regia.gd")
const POSTO := preload("res://scenes/world/PostoDiSempre.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")

const DT := 1.0 / 60.0


func run(t) -> void:
	# 1 · la fonte unica delle precondizioni
	_una_fonte_e_tre_lettori(t)
	_il_referto_dice_la_parola_del_corpo(t)
	# 2 · il fiato, che è l'orologio che non controlliamo
	_il_fiato_si_guarda_in_avanti(t)
	# 3 · il duetto
	_la_battuta_si_misura(t)
	_o_tutti_e_due_o_nessuno(t)
	_un_gettone_in_due_e_il_riposo_a_testa(t)
	_oltre_il_raggio_della_chiacchiera(t)
	_l_anziano_apre(t)
	_senza_fiato_nella_battuta_si_tace(t)
	# 4 · il momento
	_l_ora_e_circolare(t)
	_ci_si_trova_solo_avvicinandosi(t)
	_ci_devono_stare_TORNANDO(t)
	_uno_al_giorno_e_non_due_volte_sugli_stessi(t)
	_non_due_volte_sugli_stessi(t)
	_fuori_dall_ora_silenzio(t)
	_la_radura_non_fabbrica_abitudini(t)
	# 5 · il giocatore
	_ci_sei_anche_tu_batte_il_duetto(t)
	_mochi_conta_come_qualcuno(t)
	_l_ancora_di_mochi_viene_prima(t)
	# 6 · chi sta da solo
	_chi_sta_da_solo_non_cambia_di_un_bit(t)
	# 7 · il lease
	_i_sei_secondi_alzano_e_non_abbassano(t)
	_i_sei_secondi_hanno_tre_valvole(t)
	# 8 · le giunture
	_la_tavola_e_intera(t)
	_la_leva_e_dei_banchi(t)


# ============================================================== il banco

class FintoGiorno extends Node3D:
	var day := 3
	var time := 0.5


## Il registro dei vicini VERO, col solo `_ready` scavalcato — la stessa
## forma di `test_regia.Registro`, e per la stessa ragione: il suo `_ready`
## vuole `%Player` e `../BuildSystem`, cioè il villaggio intero.
class Registro extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		add_to_group("visitors")


func _corpo(t, seme := 7717):
	var v = VISITOR.new()
	v.species = "chibi"
	v.mode = "resident"
	v.dna = DNA.generate(seme)
	t.stage(v)
	v.set_process(false)     # il `_process` lo facciamo girare NOI
	return v


func _gira(v, secondi: float, passo := DT) -> void:
	for _i in int(round(secondi / passo)):
		v._process(passo)


## Il corpo in cammino verso `meta`, col ciclo del passo a regime: è la
## precondizione del Punto, e senza di essa il gesto si rifiuta.
func _in_cammino(v, meta: Vector3) -> void:
	v._enter_state("r_idle")
	v._walk_to(meta, "r_idle")
	_gira(v, 0.7)


## UN VILLAGGIO MINIMO: `DayNight` finto, il registro vero, `Cricche` vero,
## N corpi con la loro riga, e un giocatore. I tre nodi sono FRATELLI perché
## è così che `Cricche._cabla` li cerca (`../Visitors`, `../DayNight`): un
## banco che glieli infilasse a mano proverebbe un cablaggio che non esiste.
func _villaggio(t, quanti := 2, seme0 := 7717) -> Dictionary:
	for vecchio in t.tree().get_nodes_in_group("visitors"):
		(vecchio as Node).remove_from_group("visitors")
	for vecchio2 in t.tree().get_nodes_in_group("cricche"):
		(vecchio2 as Node).remove_from_group("cricche")
	var casa := Node3D.new()
	casa.name = "Villaggio"
	t.stage(casa)
	var giorno := FintoGiorno.new()
	giorno.name = "DayNight"
	casa.add_child(giorno)
	var vis = Registro.new()
	vis.name = "Visitors"
	casa.add_child(vis)
	var cric = CRICCHE.new()
	cric.name = "Cricche"
	casa.add_child(cric)
	cric.set_process(false)
	var player := Node3D.new()
	player.name = "Mochi"
	casa.add_child(player)
	# lontano da tutto: chi vuole Mochi vicina ce la mette
	player.global_position = Vector3(0, 0, 500)
	vis.set("_player", player)
	vis.set("_daynight", giorno)
	var corpi: Array = []
	var nomi := PackedStringArray()
	for i in quanti:
		var c = _corpo(t, seme0 + i * 131)
		c.global_position = Vector3(float(i) * 4.0, 0, 0)
		var nome := "Vicino%d" % i
		c.dna["name"] = nome
		nomi.append(nome)
		vis._residents.append({"node": c, "label": "V%d" % i, "dna": c.dna,
				"cell": Vector2i(i * 4, 0), "species": "chibi",
				"next_act": 0.0, "phase": "day"})
		corpi.append(c)
	return {"casa": casa, "vis": vis, "cric": cric, "giorno": giorno,
			"player": player, "corpi": corpi, "nomi": nomi}


## SEMINA UN'ABITUDINE fra due nomi: `giornate` incontri, uno per giorno,
## alla stessa ora e nello stesso punto. Passa dalla funzione VERA
## (`Cricche.registra`), non da un array scritto a mano: un registro
## fabbricato a mano proverebbe un formato invece che un predicato.
func _semina(cric, a: String, b: String, oggi: int, dove: Vector3,
		ora := 0.5, giornate := 4) -> void:
	var inc: Array = cric.get("_incontri")
	for g in giornate:
		CRICCHE.registra(inc, a, b, oggi - giornate + g, ora, dove)
	cric.set("_incontri", inc)


## …e poi si fa il giro del giorno VERO, che è quello che riempie `_coppie`.
func _giro(v: Dictionary) -> void:
	v["cric"].set("_ultimo_giorno", -1)
	v["cric"].call("giro_del_giorno", int(v["giorno"].day))


# =========================================================================
# 1 · UNA FONTE, TRE LETTORI
# =========================================================================

## L'INVARIANTE DELLA FONTE UNICA, e si prova come si provano gli invarianti:
## su una griglia di stati, non su un caso.
##
## `punto_impedimento() == ""` deve valere **se e solo se** `gesto("punto")`
## riesce. Finché le due risposte erano scritte in due posti diversi, la «se e
## solo se» era una speranza: le due copie si erano già staccate su `blend`
## (`<` contro `<=`) e sull'ordine di `_gs_viaggio`.
func _una_fonte_e_tre_lettori(t) -> void:
	var casi := [
		["fermo", func(v): v._enter_state("r_idle")],
		["in cammino lungo", func(v): _in_cammino(v, Vector3(0, 0, -30))],
		["in cammino corto", func(v): _in_cammino(v, Vector3(0, 0, -1.2))],
		["gia' un Punto", func(v):
			_in_cammino(v, Vector3(0, 0, -30))
			v.set("_gs_viaggio", true)],
	]
	for caso in casi:
		var v = _corpo(t, 4211)
		(caso[1] as Callable).call(v)
		var imp := str(v.call("punto_impedimento"))
		var ok: bool = bool(v.call("gesto", "punto", {}))
		t.eq(imp == "", ok,
				"«%s»: il permesso e il gesto dicono la stessa cosa" % caso[0])
		if not ok:
			t.ok(imp != "",
					"«%s»: e quando è no, il no ha un NOME" % caso[0])
	# LA SOGLIA DEL PASSO, presa sul filo. L'invariante qui sopra non la
	# tocca — con sette decimi di cammino il ciclo è a regime da un pezzo — e
	# una divergenza di cinque centesimi su `GESTO_BLEND_MIN` è ESATTAMENTE
	# la forma che aveva la copia sbagliata del referto. Si prova dove il
	# numero decide: appena sopra e appena sotto.
	for prova in [[VISITOR.GESTO_BLEND_MIN + 0.01, ""],
			[VISITOR.GESTO_BLEND_MIN - 0.01, "passo non a regime"]]:
		var w = _corpo(t, 4211)
		_in_cammino(w, Vector3(0, 0, -30))
		w._andatura.blend = float(prova[0])
		t.eq(str(w.call("punto_impedimento")), str(prova[1]),
				"col ciclo del passo a %.2f il Punto %s"
				% [float(prova[0]),
					"passa" if str(prova[1]) == "" else "aspetta"])


## IL REFERTO DELL'USCIERE È LA PAROLA DEL CORPO, non una supposizione.
func _il_referto_dice_la_parola_del_corpo(t) -> void:
	var v := _villaggio(t, 1)
	var c = v["corpi"][0]
	c.global_position = Vector3(0, 0, 0)
	v["player"].global_position = Vector3(1, 0, 0)
	# fermo: il corpo dice «non cammina», e l'usciere deve dire quella parola
	c._enter_state("r_idle")
	t.eq(str(c.call("punto_impedimento")), "non cammina",
			"il corpo fermo lo dice con la sua parola")
	v["vis"].set("_gesto_no", {})
	v["vis"].set("_gesto_si", {})
	t.ok(not bool(v["vis"].call("chiedi_gesto", "V0", "ci_sei_anche_tu")),
			"…e l'usciere lo rifiuta")
	var ref: Dictionary = v["vis"].call("debug_gesti_contatori")
	t.eq(int(ref.get("non cammina", 0)), 1,
			"…e nel referto c'è ESATTAMENTE quella parola, non un'ipotesi")


# =========================================================================
# 2 · IL FIATO — l'orologio che non controlliamo
# =========================================================================

## `fiato_fra` guarda IN AVANTI lo stesso ciclo che `_in_fiato` guarda adesso,
## e la prova non è aritmetica: **si porta il corpo a quell'istante e gli si
## chiede se ci è**.
func _il_fiato_si_guarda_in_avanti(t) -> void:
	# chi non ha l'età del fiato risponde sempre «adesso, o quando vuoi tu»
	var giovane = _corpo(t, 4211)
	giovane.set("_eta", 0.0)
	t.almost(float(giovane.call("fiato_fra", 0.40, 0.90)), 0.40,
			"il giovane frena quando gli si chiede", 0.0001)
	t.almost(float(giovane.call("fiato_fra", 0.0, 0.0)), 0.0,
			"…e può aprire adesso", 0.0001)
	# l'anziano no: il suo fermo lo detta il respiro
	var vecchio = _corpo(t, 4211)
	vecchio.set("_eta", 0.9)
	var trovati := 0
	var vuoti := 0
	for k in 40:
		vecchio.set("_t", float(k) * 0.2)
		var q := float(vecchio.call("fiato_fra", 0.40, 0.90))
		if q < 0.0:
			vuoti += 1
			continue
		trovati += 1
		t.ok(q >= 0.40 - 0.0001 and q <= 0.90 + 0.0001,
				"la battuta slittata resta dentro la finestra")
		# …e a quell'istante il corpo CI È davvero
		vecchio.set("_t", float(k) * 0.2 + q)
		t.ok(bool(vecchio.call("_in_fiato")),
				"e a quell'istante l'anziano è nel suo fiato")
	t.ok(trovati > 0 and vuoti > 0,
			"su un giro intero di respiro ci sono istanti buoni e istanti no")
	# la finestra rovesciata non esiste: il degrado va al silenzio
	t.almost(float(vecchio.call("fiato_fra", 0.9, 0.4)), -1.0,
			"una finestra rovesciata è un no", 0.0001)


# =========================================================================
# 3 · IL DUETTO
# =========================================================================

## Mette due corpi in convergenza sullo stesso punto, alla distanza chiesta,
## coi requisiti del Punto soddisfatti (strada davanti, passo a regime).
func _in_duetto(v: Dictionary, distanza := 4.0) -> void:
	var a = v["corpi"][0]
	var b = v["corpi"][1]
	a.global_position = Vector3(-distanza * 0.5, 0, 0)
	b.global_position = Vector3(distanza * 0.5, 0, 0)
	_in_cammino(a, Vector3(-distanza * 0.5, 0, -30))
	_in_cammino(b, Vector3(distanza * 0.5, 0, -30))
	# i corpi camminano davvero: li si riporta dove li vogliamo
	a.global_position = Vector3(-distanza * 0.5, 0, 0)
	b.global_position = Vector3(distanza * 0.5, 0, 0)
	v["player"].global_position = Vector3(0, 0, 3)
	for c in [a, b]:
		c.set("_eta", 0.0)      # nessuno dei due aspetta un respiro


## LA BATTUTA SI MISURA, e si misura sul CORPO: chi apre ha il gesto acceso
## **adesso**, chi risponde ce l'ha in canna e lo accende quattro decimi dopo.
##
## ⚠️ È la riga che rende falsificabile tutto il meccanismo della sala
## d'attesa a due versi. Con `_gs_attesa_fiato` sempre a `true`, chi risponde
## non accende MAI (aspetta un fiato che, senza l'età, non arriverà); con
## `fra` ignorato accende nello stesso fotogramma di chi apre, e allora quel
## che si vede non è una frase — è un singhiozzo del motore.
func _la_battuta_si_misura(t) -> void:
	var v := _villaggio(t, 2)
	_in_duetto(v)
	t.ok(bool(v["vis"].call("chiedi_duetto", "V0", "V1", "ci_si_trova")),
			"due che convergono si trovano")
	var ult: Dictionary = v["vis"].call("debug_duetto_ultimo")
	var apre = v["vis"].call("node_di", str(ult["apre"]))
	var risp = v["vis"].call("node_di", str(ult["risponde"]))
	t.eq(str(apre.call("gesto_in_corso")), "punto",
			"chi apre si ferma ADESSO")
	t.eq(str(apre.get("_gs_nome")), "punto",
			"…e il suo gesto è già acceso")
	t.ok(bool(risp.call("attesa_in_corso")),
			"chi risponde ha la battuta in canna")
	t.eq(str(risp.get("_gs_nome")), "",
			"…e il suo corpo non si è ancora mosso")
	t.almost(float(ult["battuta"]), VISITORS.DUETTO_RITARDO,
			"e la battuta è quella scritta", 0.0001)
	# ora si misura il ritardo VERO, facendo girare i due corpi
	var quando := -1.0
	for k in 90:
		risp._process(DT)
		apre._process(DT)
		if quando < 0.0 and str(risp.get("_gs_nome")) == "punto":
			quando = float(k + 1) * DT
	t.ok(quando > 0.0, "chi risponde accende da sé, senza che nessuno lo tocchi")
	t.almost(quando, VISITORS.DUETTO_RITARDO,
			"e il ritardo MISURATO è quello della frase", 0.05)


## O TUTTI E DUE, O NESSUNO — e si rompe con la mutazione PLAUSIBILE.
##
## La mutazione impossibile («togli il controllo su chi risponde») è un
## accesso a un nodo nullo, cioè un errore a runtime, che **non fa fallire un
## test**: lo interrompe e lascia la suite verde. Quella plausibile è
## *accendere prima chi apre e poi scoprire che l'altro non può* — ed è
## esattamente l'ordine che verrebbe naturale scrivere.
func _o_tutti_e_due_o_nessuno(t) -> void:
	var v := _villaggio(t, 2)
	_in_duetto(v)
	# uno dei due ha già speso il suo Punto in questo viaggio
	(v["corpi"][1] as Node3D).set("_gs_viaggio", true)
	t.ok(not bool(v["vis"].call("chiedi_duetto", "V0", "V1", "ci_si_trova")),
			"se uno dei due non può, il duetto non si recita")
	for c in v["corpi"]:
		t.eq(str(c.call("gesto_in_corso")), "",
				"…e NESSUNO dei due corpi si è mosso")
		t.ok(not bool(c.call("attesa_in_corso")),
				"…e nessuno è rimasto con una battuta in canna")
	# e il villaggio non ha pagato niente: il gettone è ancora libero
	t.eq(str(v["vis"].get("_gesto_chi")), "",
			"il gettone del villaggio non è stato speso")
	t.almost(float(v["vis"].get("_gesto_acc")), 0.0,
			"…e nemmeno il palco si è scaldato", 0.0001)


## UN GETTONE IN DUE, IL RIPOSO A TESTA.
##
## ⚠️ Il riposo a testa è un CANCELLO, non una simmetria: senza, i due che si
## ritrovano diventerebbero i due che si vedono di più — cioè la classifica,
## dalla porta di servizio. **Stare in una cricca non compra palco.**
func _un_gettone_in_due_e_il_riposo_a_testa(t) -> void:
	var v := _villaggio(t, 3)
	_in_duetto(v)
	# il terzo sta camminando anche lui, e con la strada davanti: se il
	# gettone si liberasse, il suo gesto partirebbe
	var terzo = v["corpi"][2]
	terzo.global_position = Vector3(0, 0, 2.0)
	_in_cammino(terzo, Vector3(0, 0, -30))
	terzo.global_position = Vector3(0, 0, 2.0)
	terzo.set("_eta", 0.0)
	t.ok(bool(v["vis"].call("chiedi_duetto", "V0", "V1", "ci_si_trova")),
			"il duetto parte")
	var riposo: Dictionary = v["vis"].get("_gesto_riposo")
	t.ok(riposo.has("V0") and riposo.has("V1"),
			"il riposo lo pagano TUTTI E DUE")
	t.ok(not riposo.has("V2"),
			"…e chi non c'entra non paga niente")
	t.almost(float(v["vis"].get("_gesto_acc")), VISITORS.GESTO_PASSO,
			"il gettone del villaggio è UNO", 0.0001)
	# il gettone lo tiene chi risponde, cioè chi finisce per ultimo
	var ult: Dictionary = v["vis"].call("debug_duetto_ultimo")
	t.eq(str(v["vis"].get("_gesto_chi")), str(ult["risponde"]),
			"e lo tiene chi finisce per ultimo, non chi comincia per primo")
	# ⚠️ **E LO TIENE ANCHE MENTRE LA BATTUTA È IN CANNA**, cioè nei quattro
	# decimi in cui uno dei due corpi non si è ancora mosso. Se il gettone si
	# liberasse lì, un terzo vicino comincerebbe a parlare SOPRA il duetto —
	# ed è proprio il quarto di secondo in cui il giocatore sta guardando i
	# primi due.
	for _k in 12:
		v["vis"].call("_tick_gesti", DT)
	t.eq(str(v["vis"].get("_gesto_chi")), str(ult["risponde"]),
			"e non lo molla nei decimi in cui la risposta non si vede ancora")
	t.ok(not bool(v["vis"].call("chiedi_gesto", "V2", "ci_sei_anche_tu")),
			"…quindi nessun terzo può parlarci sopra")


## OLTRE IL RAGGIO DELLA CHIACCHIERA, o non si distingue da una chiacchierata.
func _oltre_il_raggio_della_chiacchiera(t) -> void:
	# 1,5 m: dentro gli 1,9 di `_chats`, dove una chiacchierata è possibile
	var vicino := _villaggio(t, 2)
	_in_duetto(vicino, 1.5)
	t.ok(not bool(vicino["vis"].call("chiedi_duetto", "V0", "V1", "ci_si_trova")),
			"a un metro e mezzo sembrerebbe una chiacchierata: silenzio")
	var ref: Dictionary = vicino["vis"].call("debug_gesti_contatori")
	t.ok(int(ref.get("duetto: troppo vicini (sembra una chiacchierata)", 0)) == 1,
			"…e il no ha il suo nome")
	# 2,5 m: oltre gli 1,9, dove una chiacchierata è impossibile
	var giusto := _villaggio(t, 2)
	_in_duetto(giusto, 2.5)
	t.ok(bool(giusto["vis"].call("chiedi_duetto", "V0", "V1", "ci_si_trova")),
			"…e appena oltre il raggio della chiacchiera, sì")
	# 8 m: due fatti, non uno
	var lontano := _villaggio(t, 2)
	_in_duetto(lontano, 8.0)
	t.ok(not bool(lontano["vis"].call("chiedi_duetto", "V0", "V1", "ci_si_trova")),
			"a otto metri sono due fatti, non un momento")


## L'ANZIANO APRE, perché il suo fermo è già in calendario.
##
## Il caso è costruito perché la preferenza DEBBA capovolgere l'ordine
## naturale: l'anziano è il secondo, quindi senza la regola aprirebbe il
## giovane e la prova diventa rossa.
func _l_anziano_apre(t) -> void:
	var v := _villaggio(t, 2)
	_in_duetto(v)
	var vecchio = v["corpi"][1]
	vecchio.set("_eta", 0.9)
	vecchio.set("_t", 0.1)          # dentro il suo fiato adesso
	t.ok(bool(vecchio.call("del_fiato")), "il secondo ha l'età del fiato")
	t.ok(bool(v["vis"].call("chiedi_duetto", "V0", "V1", "ci_si_trova")),
			"il duetto parte")
	var ult: Dictionary = v["vis"].call("debug_duetto_ultimo")
	t.eq(str(ult["apre"]), "V1",
			"apre l'anziano, anche se non è il primo che gli hanno nominato")


## SE IL FIATO DI CHI RISPONDE NON CADE NELLA BATTUTA, SI TACE — e nessuno
## dei due si muove. Un duetto slittato di secondi non è una frase.
func _senza_fiato_nella_battuta_si_tace(t) -> void:
	var v := _villaggio(t, 2)
	_in_duetto(v)
	for c in v["corpi"]:
		c.set("_eta", 0.9)
	# tutti e due appena FUORI dal fiato, e il prossimo è a ~6 s: né chi apre
	# può aprire, né chi risponde arriverebbe in tempo
	(v["corpi"][0] as Node3D).set("_t", VISITOR.FIATO_DUR + 0.2)
	(v["corpi"][1] as Node3D).set("_t", VISITOR.FIATO_DUR + 0.2)
	t.ok(not bool(v["vis"].call("chiedi_duetto", "V0", "V1", "ci_si_trova")),
			"senza il respiro giusto si tace")
	for c2 in v["corpi"]:
		t.eq(str(c2.call("gesto_in_corso")), "", "…e nessuno si è mosso")
	# ⚠️ **E LA VALVOLA DI CHI APRE HA UN CASO SUO.** Sopra sono fuori fiato
	# tutti e due, quindi a fermare il duetto basta la valvola di chi
	# risponde: la prova non distingue le due. Qui l'anziano è UNO SOLO, ed è
	# lui che dovrebbe aprire (il suo fermo è già in calendario) — ma il suo
	# respiro adesso non c'è. Il duetto deve tacere lo stesso: un anziano che
	# si ferma fuori dal suo fiato è una posa sopra un corpo che cammina,
	# cioè l'adesivo che questo vocabolario esiste per non essere.
	var w := _villaggio(t, 2)
	_in_duetto(w)
	var vecchio = w["corpi"][0]
	vecchio.set("_eta", 0.9)
	vecchio.set("_t", VISITOR.FIATO_DUR + 0.2)      # appena FUORI dal fiato
	t.almost(float(vecchio.call("fiato_fra", 0.0, 0.0)), -1.0,
			"l'anziano adesso non può aprire", 0.0001)
	t.ok(not bool(w["vis"].call("chiedi_duetto", "V0", "V1", "ci_si_trova")),
			"e allora non apre nessuno: si tace")
	for c3 in w["corpi"]:
		t.eq(str(c3.call("gesto_in_corso")), "",
				"…e nemmeno il giovane si muove (o resterebbe una frase a metà)")
	# LA CONTROPROVA: rimesso l'anziano dentro il suo fiato, e nient'altro
	vecchio.set("_t", 0.1)
	t.ok(bool(w["vis"].call("chiedi_duetto", "V0", "V1", "ci_si_trova")),
			"…e col respiro al posto giusto, sì")


# =========================================================================
# 4 · IL MOMENTO
# =========================================================================

## LO SCARTO FRA DUE ORE È CIRCOLARE: mezzanotte e le 23:59 distano un
## minuto, non un giorno. È lo stesso errore che `Cricche` aveva già chiuso
## sulla media dell'ora, e che qui tornerebbe a spegnere ogni ritrovo
## notturno — in silenzio, e solo di notte.
func _l_ora_e_circolare(t) -> void:
	t.almost(CRICCHE._scarto_ora(0.99, 0.01), 0.02,
			"attorno a mezzanotte lo scarto è di due centesimi", 0.0001)
	t.almost(CRICCHE._scarto_ora(0.01, 0.99), 0.02,
			"…e non dipende dall'ordine", 0.0001)
	t.almost(CRICCHE._scarto_ora(0.20, 0.24), 0.04,
			"e in mezzo alla giornata è la differenza di sempre", 0.0001)
	t.ok(CRICCHE._scarto_ora(0.0, 0.5) <= 0.5 + 0.0001,
			"non supera mai mezza giornata")


## SI CHIEDE SOLO SE SI STANNO AVVICINANDO, e la controprova è nello stesso
## caso: gli stessi due corpi, la stessa ora, lo stesso posto — allontanandosi
## non succede niente.
##
## ⚠️ Senza questa valvola due che si allontanano dallo stesso posto verso
## mete diverse passerebbero tutto il resto, e il giocatore vedrebbe due corpi
## fermarsi insieme **voltandosi le spalle**: la lettura esattamente
## sbagliata.
func _ci_si_trova_solo_avvicinandosi(t) -> void:
	# --- si avvicinano
	var v := _villaggio(t, 2)
	var dove := Vector3(0, 0, -6)
	_semina(v["cric"], "Vicino0", "Vicino1", int(v["giorno"].day), dove)
	_giro(v)
	t.eq(int((v["cric"].get("_coppie") as Array).size()), 1,
			"i due si ritrovano")
	_avvicina(v, dove, true)
	t.ok(bool(v["cric"].get("_duetto_giorno") == int(v["giorno"].day)),
			"chi ci sta tornando avvicinandosi si trova")
	# --- si allontanano: stesso registro, stessa ora, stesso posto
	var w := _villaggio(t, 2)
	_semina(w["cric"], "Vicino0", "Vicino1", int(w["giorno"].day), dove)
	_giro(w)
	_avvicina(w, dove, false)
	t.ok(int(w["cric"].get("_duetto_giorno")) < 0,
			"…e chi si allontana no, con tutto il resto identico")
	var m: Dictionary = w["cric"].call("debug_momenti")
	t.ok(int(m.get("e' la loro ora", 0)) > 0,
			"e non è che il banco non li abbia guardati: l'ora era la loro")


## LA GEOMETRIA DELLA CONVERGENZA, e non è arbitraria: è l'unica che
## soddisfa insieme le tre condizioni del momento.
##
##  · ognuno dev'essere a più di `GESTO_STRADA_MIN` (3 m) dalla propria meta,
##    o il Punto si rifiuta — è un contrasto di MOTO, e senza strada davanti
##    non c'è moto da spezzare;
##  · la meta di ognuno dev'essere entro `META_VICINA` (4 m) dal loro posto;
##  · e i due corpi devono stare fra `DUETTO_MIN` e `DUETTO_MAX` FRA LORO.
##
## Due che arrivassero da parti opposte disterebbero per forza più di sei
## metri (due volte tre). Ci si arriva quindi **dallo stesso quadrante**: due
## punti su un arco di sessanta gradi attorno al posto, che è la corda uguale
## al raggio. Chi cambia una di quelle tre costanti si troverà questo banco
## rosso, ed è giusto: sarebbe cambiata la scena.
const ARCO := PI / 3.0


func _sul_cerchio(dove: Vector3, raggio: float, ang: float) -> Vector3:
	return dove + Vector3(cos(ang), 0.0, sin(ang)) * raggio


## Due giri del momento con i corpi che si avvicinano (o si allontanano). Il
## primo giro semina la distanza precedente — senza un «prima» non esiste un
## «si avvicinano», ed è giusto che il primo giro taccia.
func _avvicina(v: Dictionary, dove: Vector3, verso: bool) -> void:
	var lontano := 4.6
	var vicino := 3.4
	var r0: float = lontano if verso else vicino
	var r1: float = vicino if verso else lontano
	for raggio in [r0, r1]:
		_posa_e_guarda(v, dove, [
			[v["corpi"][0], float(raggio), 0.0],
			[v["corpi"][1], float(raggio), ARCO]])


## Mette i corpi sul cerchio, li manda VERSO il posto, li rimette dove li
## vogliamo (`_in_cammino` fa girare sette decimi veri e il corpo cammina
## davvero), sgombra il palco e fa il giro del momento.
func _posa_e_guarda(v: Dictionary, dove: Vector3, chi: Array,
		mochi := Vector3(0, 0, 7.5)) -> void:
	for riga in chi:
		var c = riga[0]
		var p := _sul_cerchio(dove, float(riga[1]), float(riga[2]))
		c.global_position = p
		_in_cammino(c, dove)
		c.global_position = p
		c.set("_eta", 0.0)
		c.set("_gs_viaggio", false)
	v["player"].global_position = dove + mochi
	v["vis"].set("_gesto_acc", 0.0)
	v["vis"].set("_gesto_chi", "")
	v["vis"].set("_gesto_riposo", {})
	v["cric"].call("debug_guarda_ora")


## CI DEVONO STARE TORNANDO — non basta che si incrocino.
##
## ⚠️ **È la condizione che rende il momento LORO invece che casuale.** Due
## che si avvicinano per caso, alla loro ora, mentre vanno tutti e due da
## un'altra parte, sono un incrocio: fermarsi lì racconterebbe una cosa che
## non sta succedendo — e il giocatore, che di quei due sa dove si trovano,
## la leggerebbe come una promessa che il gioco non mantiene.
##
## Il caso è costruito perché TUTTO il resto sia identico: stessa ora, stesso
## posto, stessa distanza, stessa convergenza. Cambia solo dove stanno
## andando.
func _ci_devono_stare_TORNANDO(t) -> void:
	var v := _villaggio(t, 2)
	var dove := Vector3(0, 0, -6)
	_semina(v["cric"], "Vicino0", "Vicino1", int(v["giorno"].day), dove)
	_giro(v)
	# si avvicinano davvero — ma la loro meta è dall'altra parte del villaggio
	var altrove := dove + Vector3(0, 0, -40)
	for raggio in [4.6, 3.4]:
		for i in 2:
			var c = v["corpi"][i]
			var p := _sul_cerchio(dove, float(raggio), ARCO * float(i))
			c.global_position = p
			_in_cammino(c, altrove)
			c.global_position = p
			c.set("_eta", 0.0)
			c.set("_gs_viaggio", false)
		v["player"].global_position = dove + Vector3(0, 0, 7.5)
		v["vis"].set("_gesto_acc", 0.0)
		v["vis"].set("_gesto_chi", "")
		v["vis"].set("_gesto_riposo", {})
		v["cric"].call("debug_guarda_ora")
	var m: Dictionary = v["cric"].call("debug_momenti")
	t.ok(int(m.get("e' la loro ora", 0)) > 0,
			"l'ora è la loro, e il banco li ha guardati")
	t.eq(int(m.get("✓ ci si trova", 0)), 0,
			"…ma stanno andando da un'altra parte: nessun momento")
	t.eq(int(v["cric"].get("_duetto_giorno")), -1,
			"…e nessuno si è fermato")
	# LA CONTROPROVA, stessa corsa: cambiata SOLO la meta, quei due si trovano.
	# (Due giri anche qui: senza un «prima» più lontano non esiste un «si
	# avvicinano», e si misurerebbe la valvola sbagliata.)
	_azzera(v)
	_avvicina(v, dove, true)
	t.eq(int(v["cric"].get("_duetto_giorno")), int(v["giorno"].day),
			"e cambiata solo la meta — nient'altro — si trovano")


## UNO AL GIORNO IN TUTTO IL VILLAGGIO, E MAI DUE VOLTE SUGLI STESSI DENTRO
## LA SETTIMANA. I due tetti sono la meccanica: un momento che capita due
## volte in un minuto smette di essere un momento, e la stessa coppia che si
## ferma l'una per l'altra ogni giorno disegna la mappa di chi sta con chi.
func _uno_al_giorno_e_non_due_volte_sugli_stessi(t) -> void:
	var v := _villaggio(t, 4)
	var dove := Vector3(0, 0, -6)
	var oggi := int(v["giorno"].day)
	_semina(v["cric"], "Vicino0", "Vicino1", oggi, dove)
	_semina(v["cric"], "Vicino2", "Vicino3", oggi, dove)
	_giro(v)
	t.eq(int((v["cric"].get("_coppie") as Array).size()), 2,
			"due coppie si ritrovano")
	# tutte e quattro convergono: ne esce UN duetto solo
	_quattro_convergono(v, dove)
	var m: Dictionary = v["cric"].call("debug_momenti")
	t.eq(int(m.get("✓ ci si trova", 0)), 1,
			"un duetto al giorno, in tutto il villaggio")
	# ⚠️ **E IL TETTO SI ISOLA DAL GETTONE.** Fin qui a fermare il secondo
	# duetto poteva essere bastato il gettone del villaggio (ne parla uno per
	# volta), e una prova che non distingue le due cose lascia vivere la
	# mutazione che toglie il tetto. Adesso si sgombra il palco per intero e
	# si torna a chiedere: **l'unica cosa rimasta a dire di no è il tetto.**
	_azzera(v)
	_quattro_convergono(v, dove)
	var m2: Dictionary = v["cric"].call("debug_momenti")
	t.eq(int(m2.get("✓ ci si trova", 0)), 0,
			"col palco sgombro e un'altra coppia pronta, il tetto tiene lo stesso")
	var visti: Dictionary = v["cric"].get("_duetto_visti")
	t.eq(visti.size(), 1, "e di quella coppia resta traccia")
	if visti.size() == 1:
		t.eq(int(visti[str(visti.keys()[0])]), oggi,
				"…col giorno in cui è successo")


## MAI DUE VOLTE SUGLI STESSI DENTRO LA SETTIMANA.
##
## ⚠️ **È il tetto che impedisce alla mappa di formarsi.** La stessa coppia
## che si ferma l'una per l'altra ogni giorno, sotto gli occhi del giocatore,
## in una settimana gli avrebbe disegnato chi sta con chi — cioè la
## classifica, dalla porta di servizio. E il rovescio conta quanto il dritto:
## siccome ogni giorno tocca a una coppia DIVERSA, un vicino che non si
## ritrova con nessuno è indistinguibile da uno il cui turno non è ancora
## arrivato.
##
## Il banco ha DUE soli residenti, apposta: con quattro, a tacere poteva
## essere il tetto giornaliero, e una prova che non distingue due tetti non
## ne prova nessuno.
func _non_due_volte_sugli_stessi(t) -> void:
	var v := _villaggio(t, 2)
	var dove := Vector3(0, 0, -6)
	var oggi := int(v["giorno"].day)
	_semina(v["cric"], "Vicino0", "Vicino1", oggi, dove)
	_giro(v)
	_avvicina(v, dove, true)
	t.eq(int(v["cric"].get("_duetto_giorno")), oggi,
			"il primo giorno si trovano")
	# il giorno dopo: palco sgombro, tetto del giorno azzerato a mano.
	# L'unica cosa rimasta a dire di no è «di questi due l'ho già fatto
	# vedere questa settimana».
	for salto in [1, CRICCHE.FINESTRA]:
		var quando := oggi + int(salto)
		v["giorno"].day = quando
		# l'abitudine si ri-semina fino al giorno nuovo: se no a tacere
		# sarebbe il PREDICATO (quei due non si ritrovano più), e si
		# misurerebbe la valvola sbagliata
		_semina(v["cric"], "Vicino0", "Vicino1", quando, dove)
		_giro(v)
		t.eq(int((v["cric"].get("_coppie") as Array).size()), 1,
				"al giorno +%d quei due si ritrovano ancora" % salto)
		_azzera(v)
		v["cric"].set("_duetto_giorno", -1)
		_avvicina(v, dove, true)
		var atteso: int = -1 if int(salto) < CRICCHE.FINESTRA else quando
		t.eq(int(v["cric"].get("_duetto_giorno")), atteso,
				("al giorno +%d quei due NON si rifanno vedere" % salto)
				if atteso < 0
				else ("…e passata la settimana quel momento può tornare"))


## Due coppie che convergono sullo stesso posto, ognuna dal suo quadrante:
## la prima a 0° e 60°, la seconda a 180° e 240°. Dentro ogni coppia la corda
## è il raggio (dentro la finestra del duetto); fra una coppia e l'altra è il
## diametro (fuori, e giustamente: sono due fatti).
##
## ⚠️ **E MOCHI STA IN MEZZO, a cinque metri e non a sette e mezzo.** Con
## l'inquadratura più indietro il quarto corpo finiva a 9,3 m — **fuori da
## `GESTO_RAGGIO`** — quindi la seconda coppia non poteva parlare in nessun
## caso, e a fermarla non era il tetto di uno al giorno: era il raggio. La
## mutazione che toglie il tetto **sopravviveva**, e il caso sembrava
## verde. Un banco che mette il soggetto fuori campo non prova la regola che
## crede di provare.
func _quattro_convergono(v: Dictionary, dove: Vector3) -> void:
	for raggio in [4.6, 3.4]:
		_posa_e_guarda(v, dove, [
			[v["corpi"][0], raggio, 0.0],
			[v["corpi"][1], raggio, ARCO],
			[v["corpi"][2], raggio, PI],
			[v["corpi"][3], raggio, PI + ARCO]],
			Vector3(0, 0, 5.0))


## FUORI DALLA LORO ORA NON SI GUARDA NEMMENO. È la condizione che rende
## l'ora una cosa che il giocatore può imparare: se il duetto uscisse a
## qualunque ora, «alla stessa ora» non sarebbe più una proprietà osservabile.
func _fuori_dall_ora_silenzio(t) -> void:
	var v := _villaggio(t, 2)
	var dove := Vector3(0, 0, -6)
	_semina(v["cric"], "Vicino0", "Vicino1", int(v["giorno"].day), dove, 0.5)
	_giro(v)
	v["giorno"].time = 0.9            # un'altra ora del tutto
	_avvicina(v, dove, true)
	var m: Dictionary = v["cric"].call("debug_momenti")
	t.eq(int(m.get("e' la loro ora", 0)), 0,
			"a un'altra ora non si guarda nemmeno")
	t.eq(int(m.get("✓ ci si trova", 0)), 0, "…e non succede niente")
	# controprova: rimessa la loro ora, lo stesso identico banco parla
	v["giorno"].time = 0.5
	_avvicina(v, dove, true)
	var m2: Dictionary = v["cric"].call("debug_momenti")
	t.ok(int(m2.get("✓ ci si trova", 0)) > 0,
			"…e alla loro ora sì: non era il banco a essere rotto")


# =========================================================================
# 5 · IL GIOCATORE
# =========================================================================

## CI SEI ANCHE TU BATTE IL DUETTO, e l'ordine è una decisione: fra «due
## vicini si sono accorti l'uno dell'altro» e «un vicino si è accorto di TE
## nel suo posto», la seconda è quella che il giocatore può ricondurre a sé.
func _ci_sei_anche_tu_batte_il_duetto(t) -> void:
	var v := _villaggio(t, 2)
	var dove := Vector3(0, 0, -6)
	_semina(v["cric"], "Vicino0", "Vicino1", int(v["giorno"].day), dove)
	_giro(v)
	# il primo giro semina il «prima» delle distanze, e basta: Mochi è lontana
	_posa_e_guarda(v, dove, [
		[v["corpi"][0], 4.6, 0.0], [v["corpi"][1], 4.6, ARCO]])
	# …e adesso il duetto sarebbe DAVVERO disponibile — nessuna traccia, nessun
	# tetto speso — ma nel loro posto ci sei tu
	_azzera(v)
	v["cric"].set("_duetto_giorno", -1)
	v["cric"].set("_duetto_visti", {})
	_posa_e_guarda(v, dove, [
		[v["corpi"][0], 3.4, 0.0], [v["corpi"][1], 3.4, ARCO]],
		Vector3(0.6, 0, 0))
	var m: Dictionary = v["cric"].call("debug_momenti")
	t.ok(int(m.get("✓ ci sei anche tu", 0)) > 0,
			"chi arriva nel suo posto e ci trova TE si ferma")
	t.eq(int(v["cric"].get("_duetto_giorno")), -1,
			"…e il duetto, pur potendo, lascia il palco a quel momento")
	# LA CONTROPROVA, nello stesso caso: tolta Mochi di mezzo, e con tutto il
	# resto identico, quei due si trovano. Non era il banco a essere fermo.
	_azzera(v)
	_posa_e_guarda(v, dove, [
		[v["corpi"][0], 3.4, 0.0], [v["corpi"][1], 3.4, ARCO]])
	t.eq(int(v["cric"].get("_duetto_giorno")), int(v["giorno"].day),
			"…e senza di te, sì")


## Rimette il villaggio come se non fosse successo niente: il gettone, il
## palco, il riposo, i corpi, il conto dei momenti.
func _azzera(v: Dictionary) -> void:
	v["vis"].set("_gesto_no", {})
	v["vis"].set("_gesto_si", {})
	v["vis"].set("_gesto_acc", 0.0)
	v["vis"].set("_gesto_chi", "")
	v["vis"].set("_gesto_riposo", {})
	v["cric"].set("_momenti", {})
	for c in v["corpi"]:
		c.call("gesto_spegni", true)
		c.set("_gs_viaggio", false)


## MOCHI CONTA COME QUALCUNO. I sei secondi non chiedono «c'è l'altro?»:
## chiedono «c'è qualcuno?», e il giocatore è qualcuno per la stessa riga di
## codice che vale per i vicini.
##
## ⚠️ È la riga che rende impossibile la frase «il villaggio ha un posto in
## cui io non sono». Se qui ci fosse solo il compagno, il giocatore che si
## piazza nel loro angolo vedrebbe la gente alzarsi e andarsene.
func _mochi_conta_come_qualcuno(t) -> void:
	var v := _villaggio(t, 2)
	var dove := Vector3(0, 0, -6)
	_semina(v["cric"], "Vicino0", "Vicino1", int(v["giorno"].day), dove)
	_giro(v)
	# uno solo dei due è sul posto; l'altro è dall'altra parte del villaggio
	var solo = v["corpi"][0]
	solo.global_position = dove
	solo._enter_state("r_idle")
	(v["corpi"][1] as Node3D).global_position = Vector3(80, 0, 80)
	(v["corpi"][1] as Node3D)._enter_state("r_idle")
	# nessuno accanto: il lease resta quello che era
	v["player"].global_position = Vector3(0, 0, 500)
	v["vis"]._residents[0]["next_act"] = 0.0
	v["cric"].call("debug_guarda_ora")
	t.almost(float(v["vis"]._residents[0].get("next_act", -1.0)), 0.0,
			"da solo nel suo posto, l'agenda non aspetta", 0.0001)
	# …e adesso ci sei tu
	v["player"].global_position = dove + Vector3(1.0, 0, 0)
	v["cric"].call("debug_guarda_ora")
	t.almost(float(v["vis"]._residents[0].get("next_act", -1.0)),
			POSTO.INSIEME_MINIMO,
			"con TE accanto, non ci si alza per primi", 0.0001)


## L'ANCORA DI MOCHI VIENE PRIMA, SEMPRE.
##
## ⚠️ **È la terza domanda della regola del cozy scritta in un ordine.** Se
## l'ancora del ritrovo salisse sopra quella di Mochi, un giocatore che
## arriva vedrebbe i vicini radunarsi da un'altra parte proprio nel momento
## in cui entra in scena — e avrebbe imparato, senza una parola, di essere
## quello di troppo.
func _l_ancora_di_mochi_viene_prima(t) -> void:
	var v := _villaggio(t, 2)
	var dove := Vector3(0, 0, -6)
	_semina(v["cric"], "Vicino0", "Vicino1", int(v["giorno"].day), dove)
	_giro(v)
	t.eq("+".join(v["cric"].call("compagni", "Vicino0")), "Vicino1",
			"i due si ritrovano")
	var casa := Vector3(0, 0, 0)
	var r: Dictionary = v["vis"]._residents[0]
	# la casa del compagno sta a est; senza Mochi, l'ancora ci si sposta
	v["vis"]._residents[1]["cell"] = Vector2i(40, 0)
	var senza_te: Vector3 = v["vis"].call("_ancora_ritrovo", r, casa)
	t.ok(senza_te.x > casa.x + 0.1,
			"senza di te l'ancora si sposta verso chi si ritrova con lui")
	t.ok(senza_te.distance_to(casa) <= VISITORS.SPOSTA_MAX + 0.001,
			"…e mai più di quanto si sposta qualunque altra ancora")
	# con Mochi a ovest (e dentro `MOCHI_VICINA`) l'ancora tira dall'altra
	# parte rispetto a quella del ritrovo: le due si contendono davvero
	var verso_te: Vector3 = VISITORS.ancora_riposo(casa,
			Vector3(-12, 0, 0), 1.0)
	t.ok(verso_te.x < casa.x - 0.1,
			"l'ancora di Mochi tira dalla parte opposta")
	# la cascata: la prima ancora che dà una panchina vince, e la prima è
	# quella di Mochi
	var ordine := _ordine_delle_ancore()
	t.ok(ordine.find("ancora_riposo") >= 0
			and ordine.find("_ancora_ritrovo") >= 0,
			"la cascata contiene tutte e due le ancore")
	t.ok(ordine.find("ancora_riposo") < ordine.find("_ancora_ritrovo"),
			"e quella di MOCHI viene prima di quella del ritrovo")
	t.ok(ordine.find("_ancora_ricordo") < ordine.find("_ancora_ritrovo"),
			"…e prima viene anche quella delle sue opere")


## L'ordine in cui `_panchina_per` prova le ancore, letto dal sorgente VERO.
##
## ⚠️ È l'unico controllo di questo file che guarda il testo invece del
## comportamento, e c'è una ragione: la conseguenza dell'ordine sbagliato
## («il villaggio si raggruppa altrove quando arrivi») si vede in una partita
## di ore, non in un caso di test — e un banco che la riproducesse avrebbe
## bisogno di panchine, di un Garden e di un `EcsMondo`, cioè di tre sistemi
## che con questa domanda non c'entrano. Quello che si può provare qui è che
## **l'ordine è quello**, e le due ancore vere sono provate a parte.
func _ordine_delle_ancore() -> Array:
	var testo := FileAccess.get_file_as_string("res://scenes/npc/Visitors.gd")
	var da := testo.find("func _panchina_per(")
	var a := testo.find("\nfunc ", da + 10)
	var corpo := testo.substr(da, a - da)
	var out: Array = []
	for chiave in ["ancora_riposo", "_ancora_ricordo", "_ancora_ritrovo"]:
		out.append(corpo.find(str(chiave)))
	# le posizioni diventano un ordine leggibile
	var nomi := ["ancora_riposo", "_ancora_ricordo", "_ancora_ritrovo"]
	var coppie: Array = []
	for i in 3:
		coppie.append([out[i], nomi[i]])
	coppie.sort_custom(func(x, y): return int(x[0]) < int(y[0]))
	var res: Array = []
	for c in coppie:
		res.append(str(c[1]))
	return res


# =========================================================================
# 6 · CHI STA DA SOLO
# =========================================================================

## CHI STA DA SOLO NON CAMBIA DI UN BIT.
##
## ⚠️ **È IL CASO PIÙ IMPORTANTE DI QUESTO FILE**, e non lo direbbe nessuna
## asserzione sulle cricche: si vede solo guardando chi è fuori. La differenza
## fra «sta bene da solo» e «nessuno lo vuole» non sta nel corpo di chi è
## solo — sta in quello che il gioco fa attorno a lui. Qui si pretende che
## attorno a lui non faccia **niente**: non un gesto, non un lease, non un
## metro d'ancora. E lo si pretende col caso più ostile possibile: il
## solitario è **in mezzo** a due che si ritrovano, alla loro ora, nel loro
## posto.
func _chi_sta_da_solo_non_cambia_di_un_bit(t) -> void:
	var v := _villaggio(t, 3)
	var dove := Vector3(0, 0, -6)
	_semina(v["cric"], "Vicino0", "Vicino1", int(v["giorno"].day), dove)
	_giro(v)
	# il terzo non si ritrova con nessuno
	t.eq(int(v["cric"].call("compagni", "Vicino2").size()), 0,
			"il terzo non si ritrova con nessuno")
	t.ok(v["cric"].call("cricca", "Vicino2").is_empty(),
			"…e non è in nessuna cricca")
	# NESSUN ELENCO DI CHI È FUORI: `compagni` risponde solo «questi qui», e
	# la risposta vuota non è una categoria — è l'assenza di una risposta
	var solo: Dictionary = v["vis"]._residents[2]
	var casa := Vector3(9, 0, 9)
	var ancora: Vector3 = v["vis"].call("_ancora_ritrovo", solo, casa)
	t.eq(ancora, casa,
			"la sua ancora è casa sua, ESATTA: nemmeno un centimetro di scarto")
	# e adesso lo si mette in mezzo ai due, alla loro ora, nel loro posto
	var c2 = v["corpi"][2]
	c2.global_position = dove
	c2._enter_state("r_idle")
	solo["next_act"] = 0.0
	v["player"].global_position = dove + Vector3(0.5, 0, 0)
	v["vis"].set("_gesto_no", {})
	v["vis"].set("_gesto_si", {})
	_avvicina(v, dove, true)
	t.almost(float(solo.get("next_act", -1.0)), 0.0,
			"l'agenda non lo tocca: nessun lease, né in più né in meno", 0.0001)
	t.eq(str(c2.call("gesto_in_corso")), "",
			"…e il suo corpo non recita niente")
	t.ok(not bool(c2.call("attesa_in_corso")),
			"…e non ha nemmeno una battuta in canna")
	# LA CONTROPROVA, ed è la riga che rende il caso non-vacuo: nello stesso
	# istante, nello stesso posto, i DUE il loro momento ce l'hanno avuto. Non
	# è che il banco fosse spento — è che per lui non è successo niente.
	var m: Dictionary = v["cric"].call("debug_momenti")
	t.ok(int(m.get("e' la loro ora", 0)) > 0,
			"e non è che il banco fosse spento: per i due era la loro ora")
	t.eq(int(v["cric"].get("_duetto_giorno")), int(v["giorno"].day),
			"…e i due, lì accanto a lui, si sono trovati davvero")
	var chi_parla := str(v["vis"].get("_gesto_chi"))
	t.ok(chi_parla == "V0" or chi_parla == "V1",
			"a parlare è uno dei due, mai il terzo (parla «%s»)" % chi_parla)


# =========================================================================
# 7 · I SEI SECONDI
# =========================================================================

## SI ALZA IL LEASE, NON SI ABBASSA MAI. Abbassarlo vorrebbe dire scavalcare
## un sistema a evento — il concerto, il congedo — con una regola di gruppo.
func _i_sei_secondi_alzano_e_non_abbassano(t) -> void:
	var v := _villaggio(t, 1)
	var r: Dictionary = v["vis"]._residents[0]
	(v["corpi"][0] as Node3D)._enter_state("r_idle")
	# un lease lungo, come quello che mette una scena scritta
	r["next_act"] = 9999.0
	t.ok(bool(v["vis"].call("trattieni_insieme", "V0")),
			"la richiesta viene accolta")
	t.almost(float(r["next_act"]), 9999.0,
			"…ma un lease più lungo non si accorcia MAI", 0.0001)
	# e una seconda volta nello stesso giorno non tocca
	r["next_act"] = 0.0
	t.ok(not bool(v["vis"].call("trattieni_insieme", "V0")),
			"una volta per persona per giornata")
	t.almost(float(r["next_act"]), 0.0,
			"…e la seconda volta non alza niente", 0.0001)
	# il giorno dopo, di nuovo
	v["giorno"].day = int(v["giorno"].day) + 1
	t.ok(bool(v["vis"].call("trattieni_insieme", "V0")),
			"e il giorno dopo si ricomincia")
	t.almost(float(r["next_act"]), POSTO.INSIEME_MINIMO,
			"…coi sei secondi di `PostoDiSempre`, non con un numero nuovo",
			0.0001)


## LE TRE VALVOLE, una guastata per volta.
func _i_sei_secondi_hanno_tre_valvole(t) -> void:
	# 1) al falò si sta insieme comunque: non è una notizia
	var falo := _villaggio(t, 1)
	falo["giorno"].time = 0.70          # la fase «fire»
	(falo["corpi"][0] as Node3D)._enter_state("r_idle")
	t.ok(not bool(falo["vis"].call("trattieni_insieme", "V0")),
			"al falò non si trattiene nessuno")
	falo["giorno"].time = 0.5
	t.ok(bool(falo["vis"].call("trattieni_insieme", "V0")),
			"…e fuori dal falò sì: non era il banco")
	# 2) chi non è a riposo sta già andando da qualche parte
	var cammina := _villaggio(t, 1)
	_in_cammino(cammina["corpi"][0], Vector3(0, 0, -30))
	t.ok(not bool(cammina["vis"].call("trattieni_insieme", "V0")),
			"chi cammina non si «trattiene»: si inciampa")
	# 3) un bisogno che urla passa sopra alla compagnia
	var fame := _villaggio(t, 1)
	(fame["corpi"][0] as Node3D)._enter_state("r_idle")
	var brain = fame["vis"].call("_ensure_brain", fame["vis"]._residents[0])
	brain.needs["pancino"] = 0.01
	t.ok(not bool(fame["vis"].call("trattieni_insieme", "V0")),
			"la compagnia non passa mai sopra al pancino")
	brain.needs["pancino"] = 0.9
	t.ok(bool(fame["vis"].call("trattieni_insieme", "V0")),
			"…e con la pancia piena sì")


# =========================================================================
# 8 · LE GIUNTURE
# =========================================================================

## Ogni occasione nomina una frase che esiste, e ogni frase nuova ha
## un'occasione che la chiede. Una frase scritta storta non fallisce —
## **smette di parlare, in silenzio, per sempre**.
func _la_tavola_e_intera(t) -> void:
	t.ok(REGIA.frasi_coerenti(),
			"ogni occasione nomina una frase che esiste davvero")
	for occ in ["ci_si_trova", "ci_sei_anche_tu"]:
		t.ok(REGIA.OCCASIONI.has(occ),
				"l'occasione «%s» è in tabella" % occ)
		t.ok(GESTI.FRASI.has(REGIA.frase_di(occ)),
				"…e la sua frase esiste in `Gesti.FRASI`")
	# il duetto è un PUNTO: se non lo fosse, il referto tornerebbe a tirare
	# a indovinare proprio sulla frase nuova
	t.eq(str((GESTI.FRASI["incontro"] as Dictionary)["g"]), "punto",
			"«incontro» è un Punto, non un gesto nuovo")
	t.ok(bool((GESTI.FRASI["incontro"] as Dictionary)["d"].get("decisa", false)),
			"…e deciso: il Rialzo innestato nella ripartenza")
	t.ok(not bool((GESTI.FRASI["incontro"] as Dictionary)["d"].get("capo", false)),
			"…e senza il Capo: trovarsi non è pensare")
	# l'ordine del palco resta un ordine
	t.ok(REGIA.attesa_di("ci_si_trova") <= REGIA.attesa_di("ci_sei_anche_tu"),
			"il momento a due, che non ricapita, non aspetta più dell'altro")
	# la finestra del duetto esiste davvero: sopra il raggio della chiacchiera
	t.ok(VISITORS.DUETTO_MIN > 1.9,
			"il duetto sta oltre il raggio della chiacchierata (1,9 m)")
	t.ok(VISITORS.DUETTO_MAX > VISITORS.DUETTO_MIN,
			"…e la finestra non è vuota")
	t.ok(VISITORS.DUETTO_RITARDO_MAX > VISITORS.DUETTO_RITARDO,
			"la battuta può slittare per il fiato di un anziano")
	# e l'ora del momento è la stessa dispersione con cui una coppia RESTA
	t.almost(CRICCHE.FINESTRA_ORA, CRICCHE.ORA_LARGA,
			"la finestra dell'ora non è un numero nuovo", 0.000001)


## LA LEVA DEI BANCHI È DEI BANCHI. `debug_guarda_ora` salta l'accumulatore
## da un secondo: nel gioco non la chiama nessuno, e se un giorno qualcuno la
## chiamasse il giro del momento girerebbe a 60 Hz.
func _la_leva_e_dei_banchi(t) -> void:
	var trovati: Array = []
	for cartella in ["res://scenes", "res://systems"]:
		_scandaglia(cartella, trovati)
	t.eq(trovati.size(), 0,
			"nel gioco non chiama nessuno `debug_guarda_ora` (trovato in %s)"
			% ", ".join(PackedStringArray(trovati)))


func _scandaglia(dir_path: String, fuori: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var p := dir_path + "/" + f
		if d.current_is_dir():
			if not f.begins_with("."):
				_scandaglia(p, fuori)
		elif f.ends_with(".gd"):
			var testo := FileAccess.get_file_as_string(p)
			for riga in testo.split("\n"):
				var pulita := str(riga).strip_edges()
				# i commenti no (questa lezione la nomina apposta), e nemmeno
				# la RIGA CHE LA DEFINISCE: una funzione di debug deve poter
				# esistere, e quello che si cerca è chi la CHIAMA
				if pulita.begins_with("#") or pulita.begins_with("func "):
					continue
				if pulita.find("debug_guarda_ora") >= 0:
					fuori.append(p)
					break
		f = d.get_next()
	d.list_dir_end()


## LA RADURA NON FABBRICA ABITUDINI — il cancello del POSTO.
##
## La regola dice «al falò la vicinanza non la sceglie nessuno»: i posti sono
## `_posto_al_falo(i)`, cioè l'ORDINE DI TRASLOCO, e l'anello mette gli
## stessi vicini a portata ogni sera — con 13 residenti 27 coppie e 16
## triangoli, con 28 addirittura 86 coppie e 83 triangoli. È la «cricca per
## costruzione (i, i+1, i+2)» che quella regola esiste per impedire.
##
## I due cancelli che c'erano guardavano l'OROLOGIO e lo STATO, e non
## bastavano: i corpi non si smaterializzano quando la campanella suona.
## MISURATO su 22 giornate di gioco: il 19-21% delle righe del registro
## nasceva DENTRO la radura, con l'ora fra 0.858 e 0.902 — cioè dopo la fase —
## e fabbricava metà delle abitudini. Il nuovo arrivato entrava in tre
## giornate tutte e due le volte CON LA STESSA PERSONA, perché il suo posto al
## fuoco le capitava a 1,36 m.
##
## ⚠️ E la misura che diceva «zero righe dal falò» non mentiva: il suo oracolo
## classificava per fase NEL MOMENTO DEL CAMPIONE, quindi le righe di dopo
## finivano nel secchio «fuori dal falò». Verificava il cancello contro sé
## stesso — ed è il modo in cui questo difetto è sopravvissuto a una misura.
func _la_radura_non_fabbrica_abitudini(t) -> void:
	var v := _villaggio(t, 2)
	var vis = v["vis"]
	var cric = v["cric"]
	var corpi: Array = v["corpi"]
	# il mondo, con la sua radura: la fonte del raggio è UNA, in CozyWorld
	var cozy := Node3D.new()
	cozy.name = "CozyWorld"
	cozy.set_script(load("res://scenes/world/CozyWorld.gd"))
	# non si aggiunge all'albero (costruirebbe il villaggio intero): al
	# cancello servono solo le due costanti, e le legge dallo script
	vis.set("_cozy", cozy)
	var centro: Vector3 = cozy.get("CLEARING_CENTER")
	var raggio: float = float(cozy.get("CLEARING_R"))
	t.ok(raggio > 0.0, "il raggio della radura viene da CozyWorld (%.1f m)" % raggio)

	# 1) DENTRO la radura, e a un'ora qualunque che NON è quella del falò:
	#    l'incontro non si registra. È il caso vero — i corpi restano lì
	#    dopo la campanella.
	(corpi[0] as Node3D).global_position = centro + Vector3(0.4, 0, 0)
	(corpi[1] as Node3D).global_position = centro - Vector3(0.4, 0, 0)
	var prima: int = int((cric.get("_incontri") as Array).size())
	vis._segna_incontro(0, 1, corpi[0], corpi[1])
	var dopo: int = int((cric.get("_incontri") as Array).size())
	t.eq(dopo, prima,
			"due corpi vicini DENTRO la radura non scrivono un incontro")

	# 2) e a un passo FUORI, tutto il resto uguale, si registra: il cancello
	#    non è un «no» generico, è un no al POSTO
	var fuori := centro + Vector3(raggio + 3.0, 0, 0)
	(corpi[0] as Node3D).global_position = fuori + Vector3(0.4, 0, 0)
	(corpi[1] as Node3D).global_position = fuori - Vector3(0.4, 0, 0)
	vis._segna_incontro(0, 1, corpi[0], corpi[1])
	var fine: int = int((cric.get("_incontri") as Array).size())
	t.eq(fine, prima + 1,
			"e a un passo fuori dalla radura lo stesso incontro si scrive")

	# 3) IL DEGRADO: senza mondo (i banchi, il diorama, il prologo) si
	#    registra come si è sempre fatto. Il cancello non deve poter
	#    ammutolire un villaggio che non ha una radura.
	#
	# ⚠️ Il giorno si AVANZA, e non è un dettaglio del banco: `incontro()` ne
	# scrive uno solo al giorno per coppia, quindi senza questa riga il terzo
	# caso cadeva su QUELLA regola e il banco misurava la cosa sbagliata —
	# verde o rosso, non avrebbe parlato del cancello. L'ha trovato il test
	# stesso, fallendo.
	(v["giorno"] as Node3D).set("day", int((v["giorno"] as Node3D).get("day")) + 1)
	vis.set("_cozy", null)
	(corpi[0] as Node3D).global_position = centro + Vector3(0.4, 0, 0)
	(corpi[1] as Node3D).global_position = centro - Vector3(0.4, 0, 0)
	vis._segna_incontro(0, 1, corpi[0], corpi[1])
	var senza: int = int((cric.get("_incontri") as Array).size())
	t.eq(senza, prima + 2,
			"senza mondo il cancello si fa da parte: il degrado va verso «si registra»")
	cozy.free()
