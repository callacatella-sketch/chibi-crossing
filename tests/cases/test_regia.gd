extends RefCounted
## LA REGIA — quando i gesti succedono, e soprattutto quando NO.
##
## `test_gesti.gd` prova che i gesti sono fatti bene; questo prova che
## **escono al momento giusto e quasi mai**. Sono due domande diverse, e la
## seconda è quella che decide se il villaggio sembra abitato o sembra un
## carillon di pupazzi.
##
## Il banco è fatto di roba VERA: un `Visitor` col rig di `ChibiBuilder`, il
## registro `Visitors` di produzione col solo `_ready` scavalcato (quello di
## produzione vuole `%Player` e `../BuildSystem`, cioè il villaggio intero),
## il nodo `Percezione` vero e un `EcsMondo` vero. Niente doppio che
## ri-implementa una decisione: in `test_deduzioni` il `Corpo` ri-scriveva
## `collo_ci_arriva` e la valvola vera poteva diventare `return true` **e**
## `return false` senza che una sola asserzione su 63942 se ne accorgesse.
##
## LE TRENTA MUTAZIONI, una riga di produzione per volta, rifatte
## girare — col numero di asserzioni diventate rosse (MISURATE, non stimate):
##
##   `palco_libero` che torna `residuo <= 0` (il gettone di prima) ......  5
##   il controllo di `_gesto_chi` tolto (due gesti insieme) .............  3
##   `occasione_dello_sguardo` che ignora `ricordo_nuovo` ...............  3
##   `guarda_gesto` che torna sempre `true` .............................  2
##   la precondizione del buio tolta da `gesto()` .......................  5
##   l'eccezione al riflesso allargata a QUALUNQUE transitorio ..........  1
##   `apri_scena` senza `gesto_spegni()` ................................  1
##   `in_scena()` tolto da `sospeso` in `_gesto_passo` ..................  2
##   la coda somatica che NON invecchia da sospesi ......................  2
##   `capo_pensa` con la sola `regolazione` (il cruscotto) ..............  2
##   il riposo della persona NON ordinato (com'era prima della misura) ..  1
##   la sala d'attesa che non scade mai .................................  1
##   la promozione che non aspetta il passo .............................  2
##   `ancora_valida` che accetta casa propria ...........................  3
##   `_se_lo_tiene` che non chiama l'ancora .............................  2
##   `_se_lo_tiene` che non gira la testa ...............................  2
##   la promozione scollegata dal corpo (`_cuore_di`) ...................  6
##
## …e le UNDICI del CAPO, che è il livello con due padroni (casi 12–12d):
##
##   il tetto tolto da `_tick_capo` (tre teste storte insieme) ..........  1
##   `capi_storti()` che conta i corpi in scena invece dei residenti .... 16
##   `frase()` che non chiede il permesso al villaggio ..................  2
##   `capo_permesso()` che dice sempre di sì ............................  2
##   il permesso NEGATO dove non c'è nessun registro ....................  1
##   la RETE del capo tolta da `_gesto_passo` ...........................  3
##   la rete che guarda `_gs_nome` invece di `gesto_in_corso()` .........  1
##   il bit derivato che dimentica la frase .............................  9
##   `ce_l_ha` che legge la TESTA invece del livello ....................  2
##   il tetto senza l'esenzione di chi ce l'ha già storto ...............  2
##   `capo_pende(false)` che spegne anche il rollio della frase ..........  1
##   la frase che rinuncia al suo bit se la testa pende già (com'era) ....  1
##
## ⚠️ **CINQUE DI QUESTE ALLA PRIMA STESURA NON MORDEVANO**, e trovarlo è
## stato metà del lavoro di questo file:
##  · «uno per volta» lasciava il periodo appena riarmato, quindi respingeva
##    tutto per «palco caldo»: cancellando il controllo del CORPO restava
##    UNA asserzione rossa, e il caso misurava il periodo invece della
##    simultaneità. Adesso l'accumulatore si azzera a mano prima di provare;
##  · «la promozione scollegata dal corpo» era a **ZERO rosse**, perché il
##    caso chiamava `_se_lo_tiene` direttamente. Un test che chiama il pezzo
##    che ha appena scritto prova il pezzo, non il gioco: adesso si passa da
##    `_cuore_di`, cioè dal giro vero dei fatti;
##  · idem «la promozione non aspetta il passo», che chiamava
##    `_rimanda_gesto` a mano: la sala d'attesa va RAGGIUNTA, non chiamata;
##  · `Regia.ancora_valida` era provata solo pura — una guardia senza
##    LETTORE è una guardia che non c'è, e togliere la riga che la chiama
##    dentro `_se_lo_tiene` lasciava tutto verde;
##  · e `CAPO_MAX` era a **ZERO rosse** perché il caso aveva due vicini e il
##    tetto è due: un caso che non può violare la regola che sorveglia non
##    la sorveglia. Adesso ne ha tre.
##
## ⚠️ **E LA GUARDIA DEL CAPO SORVEGLIAVA LA COSA SBAGLIATA.** Le sue due
## asserzioni erano su `_gesto_capi.size()`, cioè sul REGISTRO del villaggio,
## mentre l'invariante scritta parla di TESTE («tre teste inclinate insieme
## sono una posa di gruppo, non tre pensieri»). Sono due cose diverse appena
## qualcosa accende il rollio senza passare dal registro — ed è quello che
## faceva `Visitor.frase("pensiero")`: MISURATO nel MainLevel vero
## (`tools/misura_capi.gd`) **tre teste storte insieme per il 5,4% del
## tempo**, e il registro ne dichiarava due. Un test che guarda il registro
## invece del mondo è verde mentre il mondo è rotto: adesso `_teste()` conta
## il rig di ogni corpo del villaggio, uno per uno.
##
## ⚠️ E DUE MUTAZIONI FACEVANO **ESPLODERE** il banco invece di renderlo
## rosso (un `Dictionary` letto per indice su una chiave che quella
## mutazione non crea più): in questo runner un errore a runtime non fa
## fallire il test — lo INTERROMPE a metà, e la suite resta verde. Si legge
## col `get`, sempre. Adesso ne ha tre.

const VISITOR := preload("res://scenes/npc/Visitor.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")
const GESTI := preload("res://scenes/npc/Gesti.gd")
const REGIA := preload("res://scenes/npc/Regia.gd")
const PERC := preload("res://scenes/npc/Percezione.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")

const DT := 1.0 / 60.0


## Il registro dei vicini VERO, con solo il `_ready` scavalcato — la stessa
## forma di `test_percezione.RegistroVicini`, e per la stessa ragione.
class Registro extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		add_to_group("visitors")


func run(t) -> void:
	_la_tavola_e_intera(t)
	_il_palco_si_concede_per_merito(t)
	_l_usciere_non_serve_chi_bussa_per_primo(t)
	_uno_per_volta_e_senza_eccezioni(t)
	_l_ancora_o_silenzio(t)
	_il_capo_ha_tre_cause(t)
	_il_sollievo_vuole_il_buio(t)
	_l_eccezione_al_riflesso_e_stretta(t)
	_la_scena_rara_zittisce_il_gesto(t)
	_la_scena_rara_zittisce_i_livelli(t)
	_la_coda_invecchia_anche_da_sospesi(t)
	_il_tetto_conta_le_teste(t)
	_la_frase_chiede_il_permesso(t)
	_il_capo_della_frase_non_resta_orfano(t)
	_il_registro_non_ruba_la_testa_alla_frase(t)
	_il_riposo_ha_lo_stesso_ordine(t)
	_la_sala_d_attesa(t)
	_l_inquadratura_o_silenzio(t)
	_l_occlusione_o_silenzio(t)
	_l_ordine_dei_cancelli(t)
	_l_occhio_dentro_un_solido(t)
	_la_leva_dell_occlusione_e_dei_banchi(t)
	_l_affondo_del_capo(t)
	if ClassDB.class_exists("EcsMondo"):
		_la_raffica_non_ferma_il_corpo(t)
		_se_lo_tiene_ha_bisogno_di_un_posto(t)
	else:
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")


# --------------------------------------------------------------- il banco

func _corpo(t, seme := 7717):
	var v = VISITOR.new()
	v.species = "chibi"
	v.mode = "resident"
	v.dna = DNA.generate(seme)
	t.stage(v)
	v.set_process(false)     # il `_process` lo facciamo girare NOI
	return v


func _gira(v, secondi: float, passo := DT) -> void:
	for _i in int(secondi / passo):
		v._process(passo)


## Il corpo in cammino, col ciclo del passo a regime: è la precondizione del
## Punto, e senza di essa il gesto si rifiuta (giustamente).
func _in_cammino(v, meta := Vector3(0, 0, -30)) -> void:
	v._enter_state("r_idle")
	v._walk_to(meta, "r_idle")
	_gira(v, 0.7)


## Un villaggio minimo: il registro vero, N corpi con la loro riga, e un
## giocatore addosso (il raggio dell'usciere è nove metri).
func _villaggio(t, quanti := 2) -> Dictionary:
	for vecchio in t.tree().get_nodes_in_group("visitors"):
		(vecchio as Node).remove_from_group("visitors")
	var vis = t.stage(Registro.new())
	var player := Node3D.new()
	t.stage(player)
	player.global_position = Vector3.ZERO
	vis.set("_player", player)
	var corpi: Array = []
	for i in quanti:
		var c = _corpo(t, 7717 + i * 131)
		c.global_position = Vector3(float(i) * 0.5, 0, 0)
		_in_cammino(c)
		vis._residents.append({"node": c, "label": "V%d" % i, "dna": c.dna,
				"cell": Vector2i(i, 0), "species": "chibi"})
		corpi.append(c)
	return {"vis": vis, "player": player, "corpi": corpi}


# =========================================================================
# 1 · LA TAVOLA — pura, e INTERA nei due versi
# =========================================================================

func _la_tavola_e_intera(t) -> void:
	# ogni occasione nomina una frase che esiste: una scritta storta non
	# fallisce, **smette di parlare in silenzio** (il guasto della tabella
	# delle parole del cielo, e quello del verbo fuori tabella).
	t.ok(REGIA.frasi_coerenti(), "ogni occasione nomina una frase vera")
	# …E NEL VERSO OPPOSTO, che è quello che nessuno guarda mai: ogni frase
	# del vocabolario dev'essere raggiungibile da almeno un'occasione. Una
	# frase senza occasione è codice morto in partita con la suite verde —
	# esattamente il guasto per cui la Fase 5 è stata per un giorno un
	# laboratorio completo e non collegato.
	for f in GESTI.FRASI:
		var trovata := false
		for o in REGIA.OCCASIONI:
			if REGIA.frase_di(str(o)) == str(f):
				trovata = true
				break
		t.ok(trovata, "la frase «%s» ha almeno un'occasione che la chiede" % f)


# =========================================================================
# 2 · IL PALCO SI CONCEDE PER MERITO
# =========================================================================

func _il_palco_si_concede_per_merito(t) -> void:
	var passo: float = VISITORS.GESTO_PASSO
	# L'OCCASIONE PIÙ FREQUENTE PAGA IL PERIODO INTERO. È la sola che il
	# giocatore produce da solo, a ripetizione, semplicemente lavorando.
	t.almost(REGIA.attesa_di("ha_visto"), 1.0,
			"«ha visto» aspetta tutto il giro del villaggio")
	for o in REGIA.OCCASIONI:
		if str(o) == "ha_visto":
			continue
		t.ok(REGIA.attesa_di(str(o)) < 1.0,
				"«%s» è più rara di «ha visto» e aspetta meno" % o)
	# L'ORDINE È UN ORDINE VERO, e si giudica con un numero che non è suo:
	# `ah_sei_tu` è l'occasione in cui il giocatore è a meno di 3,2 m e ha
	# appena fatto saltare qualcuno — dev'essere la più svelta di tutte.
	for o in REGIA.OCCASIONI:
		if str(o) == "ah_sei_tu":
			continue
		t.ok(REGIA.attesa_di("ah_sei_tu") <= REGIA.attesa_di(str(o)),
				"«ah… sei tu» non aspetta più di «%s»" % o)
	# E IL CONTO. A metà periodo (sei secondi di residuo su dodici):
	t.ok(not REGIA.palco_libero("ha_visto", passo * 0.5, passo),
			"a metà periodo «ha visto» non prende il palco")
	t.ok(REGIA.palco_libero("ha_dedotto", passo * 0.5, passo),
			"…e una deduzione sì: la conseguenza vera non perde la sua premessa")
	# a palco freddo passano tutte
	for o in REGIA.OCCASIONI:
		t.ok(REGIA.palco_libero(str(o), 0.0, passo),
				"a palco freddo «%s» passa" % o)
	# un'occasione che non esiste non passa MAI: il degrado va al silenzio
	t.ok(not REGIA.palco_libero("qualunque_cosa", 0.0, passo),
			"un'occasione che non esiste non prende il palco nemmeno da freddo")


# =========================================================================
# 3 · L'USCIERE NON SERVE CHI BUSSA PER PRIMO
# =========================================================================
#
# È il cuore della regia, e con l'usciere di prima («il gettone è occupato,
# torna dopo») questo caso è ROSSO: `ha_visto` capita a ogni gesto del
# giocatore che qualcuno veda, e con un solo gettone senza ordine si prende
# il palco sempre.

func _l_usciere_non_serve_chi_bussa_per_primo(t) -> void:
	var v := _villaggio(t, 2)
	var vis = v["vis"]
	# il primo gesto passa e scalda il palco
	t.ok(vis.chiedi_gesto("V0", "ha_visto"), "il primo «ha visto» passa")
	t.eq(str(vis.get("_gesto_chi")), "V0", "…e il palco è suo")
	# il corpo finisce (lo si spegne come farebbe il mondo) e si lascia
	# passare metà periodo
	(v["corpi"][0] as Node).call("gesto_spegni", true)
	vis.set("_gesto_chi", "")
	vis.set("_gesto_acc", VISITORS.GESTO_PASSO * 0.5)
	t.ok(not vis.chiedi_gesto("V1", "ha_visto"),
			"a metà periodo un altro «ha visto» resta fuori")
	t.ok(vis.chiedi_gesto("V1", "ha_dedotto"),
			"…ma la ricevuta di una deduzione entra: non perde la sua premessa")
	var no: Dictionary = vis.debug_gesti_contatori()
	t.eq(int(no.get("palco caldo", 0)), 1,
			"e il no ha un nome, uno solo, ed è «palco caldo»")
	t.eq(int(no.get("✓ ha_dedotto", 0)), 1, "il sì si conta per occasione")


# =========================================================================
# 4 · UNO PER VOLTA, E SENZA ECCEZIONI
# =========================================================================

func _uno_per_volta_e_senza_eccezioni(t) -> void:
	var v := _villaggio(t, 2)
	var vis = v["vis"]
	t.ok(vis.chiedi_gesto("V0", "ha_visto"), "il primo passa")
	# ⚠️ **E IL PALCO SI RAFFREDDA DEL TUTTO**, o questo caso non prova
	# quello che dice. La prima stesura lasciava il periodo appena riarmato:
	# tutte le sette occasioni venivano respinte da «palco caldo», e
	# cancellando il controllo del CORPO restava una sola asserzione rossa —
	# cioè il caso si chiamava «uno per volta» e misurava il periodo. Con
	# l'accumulatore a zero l'unica cosa che può ancora dire di no è che
	# qualcuno sta ancora parlando.
	vis.set("_gesto_acc", 0.0)
	for o in REGIA.OCCASIONI:
		t.ok(not vis.chiedi_gesto("V1", str(o)),
				"«%s» non entra sopra un corpo che sta ancora parlando" % o)
	t.eq(int(vis.debug_gesti_contatori().get("un altro sta parlando", 0)),
			REGIA.OCCASIONI.size(),
			"e tutti i no si chiamano «un altro sta parlando»")
	# e quando quel corpo ha finito, il palco torna libero da sé: il gettone
	# non si rilascia a mano da nessuna parte
	(v["corpi"][0] as Node).call("gesto_spegni", true)
	vis.call("_tick_gesti", DT)
	t.eq(str(vis.get("_gesto_chi")), "",
			"finito il gesto, il palco si libera da solo")


# =========================================================================
# 5 · L'ANCORA, O SILENZIO
# =========================================================================

func _l_ancora_o_silenzio(t) -> void:
	var casa := Vector3(4, 0, 4)
	t.ok(not REGIA.ancora_valida(Vector3.ZERO, casa),
			"«non lo so» (Vector3.ZERO) non è un'ancora")
	# ⚠️ il ripiego di `EcsMondo.dove()` è CASA PROPRIA, ed è il caso che
	# conta: vuol dire «di quella cosa non mi resta abbastanza». Un vicino
	# che guarda la porta di casa sua e poi si ferma a pensare non racconta
	# niente a nessuno.
	t.ok(not REGIA.ancora_valida(casa, casa),
			"casa propria non è un'ancora: è il ripiego di chi non ricorda più")
	t.ok(REGIA.ancora_valida(casa + Vector3(3, 0, 0), casa),
			"un posto vero sì")


# =========================================================================
# 6 · IL CAPO HA TRE CAUSE (e non è un cruscotto)
# =========================================================================

func _il_capo_ha_tre_cause(t) -> void:
	# a corpo sereno, niente
	t.ok(not REGIA.capo_pensa(1.0, 0.0, false),
			"chi sta bene non tiene il capo storto")
	# ognuna delle tre da SOLA lo accende: se una smettesse, il gesto
	# diventerebbe la spia di una variabile — cioè un cruscotto, e un
	# giocatore attento dopo tre ore legge la legenda invece del villaggio
	t.ok(REGIA.capo_pensa(0.2, 0.0, false),
			"…chi non ha più forza di trattenersi sì")
	t.ok(REGIA.capo_pensa(1.0, -0.6, false),
			"…chi è di malumore da giorni sì")
	t.ok(REGIA.capo_pensa(1.0, 0.0, true),
			"…e chi ha una cosa in testa che non ha ancora detto sì")
	# LE SOGLIE NON SONO NUOVE: sono quelle con cui `Limbico.stato_corpo()`
	# dice «di malumore» e «a corto di pazienza» da sempre. Si giudicano con
	# numeri che non sono loro — appena sotto e appena sopra.
	t.ok(not REGIA.capo_pensa(REGIA.CAPO_REGOLAZIONE + 0.01, 0.0, false),
			"appena sopra la soglia della pazienza, tace")
	t.ok(not REGIA.capo_pensa(1.0, REGIA.CAPO_UMORE + 0.01, false),
			"appena sopra la soglia dell'umore, tace")
	t.almost(REGIA.CAPO_UMORE, -0.35,
			"la soglia dell'umore è quella di `Limbico.stato_corpo()`")


# =========================================================================
# 7 · IL SOLLIEVO VUOLE IL BUIO — e il buio è sul CORPO
# =========================================================================

func _il_sollievo_vuole_il_buio(t) -> void:
	var v = _corpo(t, 3311)
	v._enter_state("r_idle")
	v._timer = 9999.0
	_gira(v, 0.2)
	# NIENTE SUSSULTO, NIENTE SOLLIEVO. Il Rialzo non si recita da solo, e
	# non è una regola scritta in un commento: è una precondizione che legge
	# il corpo, non un parametro di chi chiama.
	t.ok(not v.frase("sollievo"),
			"senza il buio prima, il sollievo non parte")
	t.eq(str(v.gesto_in_corso()), "", "…e non resta niente a metà")
	# IL SUSSULTO. È lo stesso canale che `Visitors._tick_sussulti` usa
	# davvero, con la forza vera del Limbico.
	v.somatico(0.8)
	_gira(v, 0.4)          # `ATTESA_RICONOSCIMENTO`: la strada lenta
	t.ok(v.frase("sollievo"), "dopo un sussulto vero il sollievo parte")
	t.eq(str(v.gesto_in_corso()), "rialzo", "…ed è un Rialzo")
	# IL CORPO SALE DAVVERO: non è una posa, è 46 cm/s nel primo decimo.
	var y0: float = (v.get("_vis") as Node3D).position.y
	_gira(v, 0.12)
	t.ok((v.get("_vis") as Node3D).position.y - y0 > 0.03,
			"il corpo sale di quattro centimetri nel primo decimo (%.3f m)"
					% ((v.get("_vis") as Node3D).position.y - y0))
	# …E IL BUIO INVECCHIA. Il sollievo è la seconda metà di un sussulto,
	# non il ricordo di uno spavento di sei secondi fa: passata la finestra
	# il gesto si rifiuta, anche se la coda somatica è ancora viva.
	var w = _corpo(t, 3312)
	w._enter_state("r_idle")
	w._timer = 9999.0
	w.somatico(0.8)
	_gira(w, VISITOR.SOLLIEVO_FINESTRA + 0.3)
	t.ok(GESTI.coda_ampiezza(0.8, VISITOR.SOLLIEVO_FINESTRA + 0.3) > 0.0,
			"(la coda somatica è ancora viva: la finestra non è la sua)")
	t.ok(not w.frase("sollievo"),
			"passata la finestra, il sollievo non è più la seconda metà di niente")


# =========================================================================
# 8 · L'ECCEZIONE AL RIFLESSO È STRETTA
# =========================================================================
#
# `trasalisce` dura 1,3 s e il riconoscimento arriva dopo 0,4: il sollievo
# cade SEMPRE dentro il transitorio del sussulto. Senza un'eccezione non
# sarebbe mai partito — e con un'eccezione larga il vocabolario comincerebbe
# a recitare sopra i riflessi, che è quello che quella valvola impedisce.

func _l_eccezione_al_riflesso_e_stretta(t) -> void:
	var v = _corpo(t, 3313)
	v._enter_state("r_idle")
	v._timer = 9999.0
	v.somatico(0.8)
	_gira(v, 0.1)
	v.set("_rc_trans", "trasalisce")
	v.set("_rc_trans_t", 0.4)
	t.ok(v.frase("sollievo"),
			"il sollievo scioglie il riflesso che lo ha preceduto")
	v.gesto_spegni(true)
	# …e nient'altro ci passa sopra
	v.set("_rc_trans", "trasalisce")
	v.set("_rc_trans_t", 0.4)
	_in_cammino(v)
	v.set("_rc_trans", "trasalisce")
	v.set("_rc_trans_t", 0.4)
	t.ok(not v.frase("premessa"),
			"…ma una premessa no: chi sta trasalendo non si mette a pensare")
	# e nemmeno il sollievo passa sopra un transitorio che non è il suo
	v.gesto_spegni(true)
	v._enter_state("r_idle")
	v._timer = 9999.0
	v.somatico(0.8)
	_gira(v, 0.1)
	v.set("_rc_trans", "esita")
	v.set("_rc_trans_t", 0.4)
	t.ok(not v.frase("sollievo"),
			"il sollievo scioglie il SUSSULTO, non qualunque transitorio")


# =========================================================================
# 9 · LE SCENE RARE — il corpo è di chi ha scritto la scena
# =========================================================================
#
# Il concerto, il congedo, il nascondino, il concertino, la prima parola di
# un cucciolo, l'appuntamento delle Promesse. Sono le poche scene scritte a
# mano perché una volta ogni tanto succeda qualcosa di preciso: un vicino
# che si ferma a pensare in mezzo al coro del carillon le rovina.

func _la_scena_rara_zittisce_il_gesto(t) -> void:
	var v = _corpo(t, 3314)
	_in_cammino(v)
	t.ok(v.frase("premessa"), "il gesto parte")
	_gira(v, 0.3)
	t.eq(str(v.gesto_in_corso()), "punto", "…ed è in corso")
	# LA SCENA SI APRE SU UN VILLAGGIO CHE STAVA VIVENDO: è esattamente così
	# che si aprono, e `gesto_libero()` non poteva niente contro un gesto
	# già cominciato.
	v.call("apri_scena", 30.0)
	t.eq(str(v.gesto_in_corso()), "",
			"appena la scena si apre, il gesto in corso finisce")
	# …e RIENTRA con la rampa, non di netto: un taglio secco è un salto del
	# rig, cioè la firma dell'adesivo staccato male.
	_gira(v, GESTI.SPEGNI + 0.2)
	t.almost(float(v.get("_gs_r")), 1.0, "il ritmo è tornato pieno", 0.002)
	for c in ["vy", "vz", "px", "hz", "hpy"]:
		t.almost(float((v.get("_gs_cur") as Dictionary).get(c, 0.0)), 0.0,
				"il canale «%s» è rientrato" % c, 0.002)
	# e durante la scena non ne parte nessun altro
	_in_cammino(v)
	v.call("apri_scena", 30.0)
	t.ok(not v.frase("premessa"), "durante la scena non parte niente")


func _la_scena_rara_zittisce_i_livelli(t) -> void:
	# IL RALLENTANDO MOLTIPLICA `_move_gait`, cioè cambierebbe i tempi di una
	# coreografia scritta a mano. Si misura in METRI, contro un gemello: è la
	# lezione di `test_gesti` — guardare `_gs_r` è guardare il numero PRIMA
	# di essere usato.
	var libero = _corpo(t, 3315)
	var in_scena = _corpo(t, 3315)
	_in_cammino(libero)
	_in_cammino(in_scena)
	libero.somatico(1.0)
	in_scena.somatico(1.0)
	in_scena.call("apri_scena", 30.0)
	var da_l: Vector3 = libero.global_position
	var da_s: Vector3 = in_scena.global_position
	_gira(libero, 1.5)
	_gira(in_scena, 1.5)
	var m_l := da_l.distance_to(libero.global_position)
	var m_s := da_s.distance_to(in_scena.global_position)
	t.ok(m_s > m_l * 1.05,
			"chi è in scena cammina col suo passo (%.2f m contro %.2f di chi è guardingo)"
					% [m_s, m_l])
	# e il capo non pende: durante il coro del carillon un capo storto è un
	# attore che non guarda il direttore
	in_scena.call("capo_pende", true)
	_gira(in_scena, 1.0)
	t.almost(float((in_scena.get("_gs_cur") as Dictionary).get("hz", 0.0)), 0.0,
			"in scena il capo non pende", 0.0005)


func _la_coda_invecchia_anche_da_sospesi(t) -> void:
	# ⚠️ UN LIVELLO SOSPESO CHE NON INVECCHIA NON È SOSPESO: è IN PAUSA, e
	# riemerge intatto dall'altra parte. La coda somatica vive otto secondi;
	# una notte di sonno o un concerto di dieci minuti la ritrovavano viva —
	# cioè un vicino che riprende a essere guardingo per uno spavento di
	# dieci minuti prima, senza nessuna premessa che il giocatore possa
	# ancora avere in mente.
	var v = _corpo(t, 3316)
	_in_cammino(v)
	v.somatico(1.0)
	v.call("apri_scena", 120.0)
	_gira(v, GESTI.CODA_VITA + 2.0)
	t.ok(float(v.get("_gs_soma_t")) > GESTI.CODA_VITA,
			"l'orologio della coda gira anche a scena aperta (%.1f s)"
					% float(v.get("_gs_soma_t")))
	# LA PROVA CHE DISCRIMINA: quando la scena finisce, le spalle NON si
	# richiudono. Col livello messo in pausa invece che invecchiato, qui la
	# coda ripartiva a piena ampiezza — un vicino che ricomincia a essere
	# guardingo per uno spavento di dieci minuti prima.
	v.call("chiudi_scena")
	_gira(v, 2.0 * DT)
	t.almost(float((v.get("_gs_cur") as Dictionary).get("ear", 0.0)), 0.0,
			"uscendo dalla scena le spalle non si richiudono", 0.001)
	# e alla fine muore del tutto: lo strato lento (il rallentando) vive
	# ottanta secondi, ed è giusto che li viva — ma li vive UNA volta
	_gira(v, 95.0, 1.0 / 30.0)
	t.almost(float(v.get("_gs_soma")), 0.0, "…e la coda si spegne del tutto")
	t.almost(float(v.get("_gs_r")), 1.0,
			"…e il passo torna quello di sempre", 0.002)


# =========================================================================
# 10 · LA RAFFICA NON FERMA IL CORPO
# =========================================================================
#
# L'unità è il RICORDO, non il gesto: nel grafo, gesti uguali e ravvicinati
# fondono in uno solo che si rinfresca. Il ventesimo pezzo di un sentiero non
# è una cosa vista in più — è la stessa cosa, ancora.
#
# Questo caso passa dal bus VERO (`Percezione.accaduto`), che è quello che
# chiamano Garden, il BuildSystem e la pesca: se il cablaggio non ci fosse,
# qui non succederebbe niente.

func _la_raffica_non_ferma_il_corpo(t) -> void:
	for vecchio in t.tree().get_nodes_in_group("visitors"):
		(vecchio as Node).remove_from_group("visitors")
	var vis = t.stage(Registro.new())
	var cuore: Object = ClassDB.instantiate("EcsMondo")
	(cuore as Node).name = "CuoreSonno"
	vis.add_child(cuore)
	vis.set("_ecs", cuore)
	var player := Node3D.new()
	t.stage(player)
	vis.set("_player", player)
	var c = _corpo(t, 3317)
	c.global_position = Vector3(1.0, 0, 0)
	var id: int = cuore.call("registra", PackedStringArray([]), "")
	vis._residents.append({"node": c, "label": "V0", "dna": c.dna,
			"cell": Vector2i(0, 0), "species": "chibi", "ecs": id})
	var perc = t.stage(PERC.new())

	# VENTI PIETRE DI SENTIERO, una dopo l'altra dentro la finestra di
	# fusione: il grafo ne fa UN ricordo.
	for _i in 20:
		perc.call("accaduto", "costruisce", Vector3(1.0, 0, 0))
	var no: Dictionary = vis.debug_gesti_contatori()
	t.eq(int(no.get("? ha_visto", 0)), 1,
			"venti pietre di sentiero chiedono UN solo corpo che si ferma")
	# la testa invece si è girata (la ricevuta non cambia: è la sua
	# grammatica, e questo caso non deve poterla rompere)
	t.ok(float(c.get("_tst_t")) > 0.0, "…e la testa si è girata lo stesso")
	# UN GESTO DIVERSO È UN RICORDO DIVERSO, e allora sì
	perc.call("accaduto", "annaffia", Vector3(1.0, 0, 0))
	no = vis.debug_gesti_contatori()
	t.eq(int(no.get("? ha_visto", 0)), 2,
			"un gesto DIVERSO è un ricordo nuovo, e chiede il suo")
	# e il conto della regia pura combacia con quello del mondo
	t.eq(REGIA.occasione_dello_sguardo(false, false), "",
			"un ricordo che si rinfresca non è un'occasione")
	t.eq(REGIA.occasione_dello_sguardo(true, false), "ha_visto",
			"un ricordo nuovo sì")
	t.eq(REGIA.occasione_dello_sguardo(true, true), "era_per_me",
			"…e se era per me è un'altra occasione, che aspetta meno")
	t.ok(REGIA.attesa_di("era_per_me") < REGIA.attesa_di("ha_visto"),
			"«era per me» aspetta meno di «ha visto»")


# =========================================================================
# 11 · «SE LO TIENE» — l'occasione che funziona SENZA il modello
# =========================================================================
#
# La promozione di un ricordo (`EcsMondo.cosa_da_ricordare` →
# `VillagerBrain.remember`) era **completamente invisibile**: il ricordo
# passava dal grafo che vive in RAM a un canale che attraversa un riavvio, e
# sullo schermo non succedeva niente. Il giocatore avrebbe visto la
# conseguenza — quella parola che scappa in una nuvoletta, giorni dopo —
# senza mai aver visto il momento.
#
# ⚠️ E QUI SI PROVA IL CABLAGGIO, non la funzione pura. `Regia.ancora_valida`
# ha già il suo caso qui sopra, ma una guardia pura senza LETTORE è una
# guardia che non c'è: togliendo la riga che la chiama dentro `_se_lo_tiene`,
# nessuna asserzione di quel caso si accorgeva di niente.

func _se_lo_tiene_ha_bisogno_di_un_posto(t) -> void:
	for vecchio in t.tree().get_nodes_in_group("visitors"):
		(vecchio as Node).remove_from_group("visitors")
	var vis = t.stage(Registro.new())
	var cuore: Object = ClassDB.instantiate("EcsMondo")
	(cuore as Node).name = "CuoreSonno"
	vis.add_child(cuore)
	vis.set("_ecs", cuore)
	var player := Node3D.new()
	t.stage(player)
	vis.set("_player", player)

	# CHI HA VISTO. Il posto è a cinque metri da casa sua: è «l'aiuola che
	# ti ho vista annaffiare», e si può guardare.
	var casa := Vector2i(0, 0)
	var posto := Vector3(5.0, 0, 0)
	var c = _corpo(t, 3319)
	c.global_position = Vector3.ZERO
	var id: int = cuore.call("registra", PackedStringArray([]), "")
	var r := {"node": c, "label": "V0", "dna": c.dna, "cell": casa,
			"species": "chibi", "ecs": id}
	vis._residents.append(r)
	var v_ann: int = int(cuore.call("indice_verbo", "annaffia"))
	var c_fiore: int = int(cuore.call("indice_cosa", "fiore"))
	t.ok(v_ann >= 0 and c_fiore >= 0, "il ponte conosce «annaffia» e «fiore»")
	for _i in 4:
		cuore.call("osserva", id, v_ann, posto, -1)
	t.ok(int(cuore.call("cosa_da_ricordare", id, VISITORS.RICORDO_SOGLIA)) >= 0,
			"quattro annaffiate sotto il naso valgono un ricordo permanente")

	# ⚠️ E SI PASSA DA `_cuore_di`, NON DA `_se_lo_tiene`. La prima stesura
	# chiamava direttamente la funzione nuova: la mutazione «togli la
	# chiamata da `_cuore_di`» — cioè scollegare del tutto la promozione dal
	# corpo — restava a **zero asserzioni rosse**. Un test che chiama il
	# pezzo che ha appena scritto prova il pezzo, non il gioco.
	r["cuore_scad"] = 0.0
	vis.call("_cuore_di", r, c)
	t.ok(bool(r.get("promosso_oggi", false)),
			"il giro dei fatti promuove il ricordo (ed è una al giorno)")
	t.eq(int(vis.debug_gesti_contatori().get("? se_lo_tiene", 0)), 1,
			"la promozione chiede il corpo")
	# LA RICEVUTA: la testa va sul posto di QUEL ricordo, e si paga sempre —
	# anche quando il palco è occupato (la regola della Fase 5).
	t.ok(float(c.get("_tst_t")) > 0.0, "…e la testa si gira")
	t.ok((c.get("_tst_pos") as Vector3).distance_to(posto) < 0.5,
			"…verso il posto di quel ricordo (%s)" % str(c.get("_tst_pos")))
	# E IL CORPO ASPETTA. Questo vicino è fermo — una promozione cade dove
	# capita, e il Punto vuole un passo da spezzare: l'occasione entra in
	# sala d'attesa e vive quanto la testa resta girata, non un istante di
	# più. (MISURATO nel villaggio vero: dei no, 284 erano «non cammina».)
	# ⚠️ e si legge col `get`, non con l'indice: una mutazione che toglie la
	# sala d'attesa farebbe ESPLODERE questa riga invece di renderla rossa —
	# e un errore a runtime non fa fallire un test, lo INTERROMPE a metà
	# lasciando la suite verde (misurato: 1 rossa + 1 SCRIPT ERROR).
	var sala: Dictionary = vis.get("_gesto_evita")
	t.ok(sala.has("V0"),
			"…e il corpo, che è fermo, mette l'occasione in sala d'attesa")
	t.almost(float((sala.get("V0", {}) as Dictionary).get("scade", -1.0)),
			PERC.DURATA_SGUARDO,
			"…per esattamente quanto dura la testa girata, che è la premessa")

	# CHI NON HA VISTO NIENTE. `EcsMondo.dove()` ripiega su CASA PROPRIA, e
	# guardarsi la porta di casa non racconta niente a nessuno: si tace.
	var c2 = _corpo(t, 3320)
	c2.global_position = Vector3(1, 0, 1)
	var id2: int = cuore.call("registra", PackedStringArray([]), "")
	var r2 := {"node": c2, "label": "V1", "dna": c2.dna, "cell": Vector2i(1, 1),
			"species": "chibi", "ecs": id2}
	vis._residents.append(r2)
	for _i in 4:
		cuore.call("osserva", id2, v_ann, Vector3(1, 0, 1), -1)
	r2["cuore_scad"] = 0.0
	vis.call("_cuore_di", r2, c2)
	t.eq(int(vis.debug_gesti_contatori().get("? se_lo_tiene", 0)), 1,
			"senza un posto da guardare, la promozione tace")
	t.almost(float(c2.get("_tst_t")), 0.0, "…e la testa non si gira")


# =========================================================================
# 12 · IL TETTO CONTA LE TESTE, non le righe di un registro
# =========================================================================
#
# In tutto il villaggio non si vedono più di `CAPO_MAX` teste inclinate
# insieme: tre sono una posa di gruppo, non tre pensieri (PROVINATO
# guardando, `tools/provino_capi.gd`).
#
# ⚠️ **E QUESTA GUARDIA SORVEGLIAVA LA COSA SBAGLIATA.** Asseriva su
# `_gesto_capi.size()`, cioè sul REGISTRO — un dizionario di label che il
# villaggio teneva a mano — mentre l'invariante scritta parla di TESTE. Sono
# due cose diverse appena qualcosa accende il rollio senza passare dal
# registro, ed è esattamente quello che faceva `Visitor.frase("pensiero")`:
# MISURATO nel MainLevel vero (`tools/misura_capi.gd`, dodici residenti, tre
# minuti) **tre teste storte insieme per il 5,4% del tempo, con il registro
# che ne dichiarava due** e 282 fotogrammi di divergenza. La suite era verde.
#
# Adesso il conto è DERIVATO dal mondo (`Visitors.capi_storti()`) e qui si
# contano le teste vere, una per una.

## L'ORACOLO DELLE TESTE, ed è del test: si guarda il rig di ogni corpo che
## sta ancora nel villaggio. Chiedere a `Visitors.capi_storti()` quante teste
## pendono sarebbe chiedere al giudice se è d'accordo con sé stesso — è
## l'errore che `tools/misura_cammino.gd` esiste per non commettere, ed è
## quello che la guardia di prima commetteva contando le righe del registro.
func _teste(vis) -> int:
	var n := 0
	for r in vis._residents:
		var nodo := (r as Dictionary).get("node") as Node3D
		if nodo != null and is_instance_valid(nodo) and bool(nodo.get("_gs_capo")):
			n += 1
	return n


func _pensa_davvero(vis, r: Dictionary) -> void:
	vis.call("_ensure_brain", r)
	var animo: RefCounted = (vis.get("_animi") as Dictionary)[str(r["label"])]
	animo.limbico.regolazione = 0.1


func _il_tetto_conta_le_teste(t) -> void:
	# ⚠️ TRE VICINI, non due: col villaggio grande quanto il tetto, `CAPO_MAX`
	# non morde e lo si può cancellare senza che una sola asserzione se ne
	# accorga (misurato: zero rosse). Un caso che non può violare la regola
	# che sorveglia non la sorveglia.
	var v := _villaggio(t, 3)
	var vis = v["vis"]
	# tutti e tre pensano davvero: si passa dalla porta vera (`Limbico`), non
	# scrivendo il registro a mano
	for r in vis._residents:
		_pensa_davvero(vis, r)
	vis.call("_tick_capi", 10.0)
	t.eq(_teste(vis), VISITORS.CAPO_MAX,
			"tre vicini ci pensano e le teste inclinate insieme sono due")
	# UNO SE NE VA: la riga sparisce da `_residents`, ed è l'unico posto da
	# cui il villaggio può accorgersene. Col conto derivato non c'è niente da
	# potare — il suo posto si libera nello stesso istante — ma il
	# COMPORTAMENTO dev'essere quello di prima, e questa è la sua guardia:
	# chi contasse le teste di TUTTI i corpi in scena (il gruppo «passanti»,
	# che è l'altro modo di scrivere `capi_storti`) troverebbe ancora quella
	# di chi se n'è andato, e il terzo non avrebbe mai il suo posto.
	var terzo := (vis._residents[2] as Dictionary).get("node") as Node3D
	vis._residents.remove_at(0)
	vis.call("_tick_capi", 10.0)
	t.eq(_teste(vis), VISITORS.CAPO_MAX,
			"…e chi resta si divide di nuovo i due posti")
	t.ok(bool(terzo.get("_gs_capo")),
			"…e il terzo, che pensava e aspettava, ha preso quello che si è liberato")


# =========================================================================
# 12b · LA FRASE CHIEDE IL PERMESSO AL VILLAGGIO
# =========================================================================
#
# Il rollio del capo ha due padroni: il registro (un LIVELLO che dura minuti)
# e `frase("pensiero")` (che dura quanto il gesto). Il secondo non guardava
# il primo — `Visitor.frase` accendeva il capo per conto suo — e il tetto era
# quindi «due, più quante frasi capitano».

func _la_frase_chiede_il_permesso(t) -> void:
	var v := _villaggio(t, 3)
	var vis = v["vis"]
	# DUE ci pensano e riempiono il tetto; il terzo no
	_pensa_davvero(vis, vis._residents[0])
	_pensa_davvero(vis, vis._residents[1])
	vis.call("_ensure_brain", vis._residents[2])
	vis.call("_tick_capi", 10.0)
	t.eq(_teste(vis), VISITORS.CAPO_MAX, "il registro ha riempito il tetto")
	var terzo = v["corpi"][2]
	_in_cammino(terzo)
	# LA FRASE PARTE LO STESSO, e non è un ripiego: il Punto è quello che il
	# giocatore stava aspettando (una promozione, la ricevuta di una
	# deduzione), e il gettone del villaggio l'ha già pagato. A cadere è
	# l'ACCENTO — il rollio — che è la cosa di cui non se ne possono vedere
	# tre insieme. Il degrado va verso «si recita», mai verso il silenzio.
	t.ok(terzo.frase("pensiero"), "la frase parte lo stesso: il gesto si vede")
	t.ok(not bool(terzo.get("_gs_capo")),
			"…ma la testa non si inclina: quel posto in villaggio non c'è")
	t.eq(_teste(vis), VISITORS.CAPO_MAX,
			"e le teste inclinate insieme restano due, non tre")
	# LIBERATO UN POSTO… MA NON SUBITO. La molla rientra da sé e ci mette
	# qualche decimo di secondo: finché quella testa è ancora inclinata, il
	# posto è suo. Un tetto che contasse i bit invece del rig darebbe la
	# terza testa proprio mentre la prima sta tornando su — MISURATO nel
	# villaggio vero: 8,3 s con tre teste insieme, la terza a 4,7° di media.
	# (la molla si muove solo se il corpo fa girare il suo `_process`: qui la
	# manovella la giriamo noi, un corpo per volta)
	var primo = v["corpi"][0]
	_gira(primo, 1.0)
	t.ok(bool(primo.call("capo_storto")), "(la prima testa pende davvero)")
	primo.call("capo_pende", false)
	terzo.gesto_spegni(true)
	_gira(terzo, 0.1)
	_in_cammino(terzo)
	t.ok(terzo.frase("pensiero"), "(la frase riparte)")
	t.ok(not bool(terzo.get("_gs_capo")),
			"…e la testa ancora no: il primo tiene il posto finché la sua molla non rientra")
	terzo.gesto_spegni(true)
	_gira(primo, 0.8)                  # …e adesso è rientrata davvero
	t.ok(not bool(primo.call("capo_storto")), "(la prima testa è tornata dritta)")
	_gira(terzo, 0.1)
	_in_cammino(terzo)
	t.ok(terzo.frase("pensiero"), "(la stessa frase, un attimo dopo)")
	t.ok(bool(terzo.get("_gs_capo")),
			"…col posto libero la testa si inclina: il tetto è una scarsità, non un divieto")
	# E DOVE NON C'È VILLAGGIO SI PASSA. Un corpo in un provino, nel diorama
	# del titolo o nel Prologo non ha nessun registro a cui chiedere: il
	# degrado va verso quello che c'era — è la stessa regola con cui
	# `_nell_inquadratura` lascia passare chi non ha una camera, e con cui il
	# portiere del cuore che scrive tratta una RAM che non sa leggere.
	for vecchio in t.tree().get_nodes_in_group("visitors"):
		(vecchio as Node).remove_from_group("visitors")
	var solo = _corpo(t, 3399)
	_in_cammino(solo)
	t.ok(solo.frase("pensiero"), "senza registro la frase parte")
	t.ok(bool(solo.get("_gs_capo")),
			"…e la testa si inclina lo stesso: dove non c'è villaggio non c'è folla")


# =========================================================================
# 12c · LA RETE DEL CAPO — una frase che sparisce non lascia la testa storta
# =========================================================================
#
# Il rollio acceso da una frase è di QUELLA frase. A spegnerlo c'erano due
# `capo_pende(false)` scritti a mano, e coprivano due strade su sei: il ramo
# `subito` di `gesto_spegni` usciva prima di arrivarci, ed è quello da cui
# passano le due porte VERE del gioco — il Salone di bellezza
# (`rifai_il_look` → `_monta_corpo`) e ogni gradino di crescita di un
# cucciolo (`set_cucciolo`). MISURATO col Salone vero nel MainLevel
# (`tools/misura_capi.gd`, atto II): trentacinque secondi dopo la seduta la
# testa era ancora a 5,9° e continuava a rollare, **per sempre**, e siccome
# il registro non gliel'aveva mai concessa non la contava nessuno.

func _il_capo_della_frase_non_resta_orfano(t) -> void:
	# in un villaggio con UN residente: la frase deve poter chiedere il suo
	# permesso a qualcuno (senza registro passerebbe comunque, e allora
	# questo caso proverebbe il ramo che il gioco non usa)
	var v := _villaggio(t, 1)
	var c = v["corpi"][0]
	_in_cammino(c)
	t.ok(c.frase("pensiero"), "la frase del pensiero parte")
	t.ok(bool(c.get("_gs_capo")), "…e la testa comincia a inclinarsi")
	_gira(c, 0.9)
	t.ok(absf(float(c.get("_gs_capo_x"))) > 0.02,
			"…e pende davvero (%.3f rad)" % float(c.get("_gs_capo_x")))
	# IL SALONE DI BELLEZZA: rimonta il corpo, e per farlo taglia il gesto di
	# netto. È una porta vera, e non la chiama nessuno che sappia del capo.
	t.ok(c.rifai_il_look({"fur": "e8b4a0", "belly": "f6d8cc"}),
			"(il salone rimonta il corpo: `gesto_spegni(true)`)")
	_gira(c, 0.1)
	t.ok(not bool(c.get("_gs_capo")),
			"col gesto se ne va il rollio: la rete lo spegne per QUALUNQUE stato")
	_gira(c, 2.0)
	t.almost(float(c.get("_gs_capo_x")), 0.0,
			"…e la testa torna dritta da sé, senza salti", 0.002)
	# L'ALTRA PORTA: un cucciolo che cresce passa di qui a ogni gradino.
	var v2 := _villaggio(t, 1)
	var cu = v2["corpi"][0]
	_in_cammino(cu)
	t.ok(cu.frase("pensiero"), "(un cucciolo che ci sta pensando)")
	t.ok(bool(cu.get("_gs_capo")), "(…con la testa inclinata)")
	cu.set_cucciolo(0.5)
	_gira(cu, 0.1)
	t.ok(not bool(cu.get("_gs_capo")),
			"…e nemmeno la crescita lascia una testa storta dietro di sé")
	# E SU UN ANZIANO, che è il caso in cui la rete si sbaglia più facilmente:
	# il Punto aspetta il suo FIATO, quindi per qualche decimo di secondo la
	# frase è partita e nessun gesto è acceso. Una rete che guardi `_gs_nome`
	# invece di `gesto_in_corso()` gli spegne il capo un fotogramma dopo
	# averlo acceso — in silenzio, e solo ai vecchi.
	var v3 := _villaggio(t, 1)
	var vecchio = v3["corpi"][0]
	vecchio.set_eta(0.8)
	_in_cammino(vecchio)
	vecchio.set("_t", 4.0)          # dentro il periodo, fuori dal fiato
	t.ok(vecchio.frase("pensiero"), "sull'anziano la frase viene accettata")
	t.eq(str(vecchio.gesto_in_corso()), "punto", "…e aspetta il suo fiato")
	_gira(vecchio, 0.5)
	t.ok(bool(vecchio.get("_gs_capo")),
			"…e intanto il capo gli resta: la frase c'è, anche se il gesto non è ancora partito")


# =========================================================================
# 12d · IL REGISTRO NON RUBA LA TESTA ALLA FRASE
# =========================================================================
#
# Le due sorgenti si scrivono da sole e il bit che il rig legge è DERIVATO
# (`_gs_capo_liv or _gs_capo_frase`). Con un bit solo, la fine di una frase
# spegneva il livello del villaggio — e il registro continuava a credere che
# quel vicino ce l'avesse, tenendogli occupato un posto per sempre.

func _il_registro_non_ruba_la_testa_alla_frase(t) -> void:
	# DUE vicini, e il tetto è due: il primo ha il livello dal registro, il
	# secondo la frase. Così `capi_storti()` è già al tetto quando il
	# registro arriva sul secondo — che è l'unico modo di provare che a
	# quel punto non gli si chiede di pagare un posto che occupa già.
	var v := _villaggio(t, 2)
	var vis = v["vis"]
	var altro = v["corpi"][0]
	var c = v["corpi"][1]
	_pensa_davvero(vis, vis._residents[0])
	vis.call("_tick_capi", 10.0)
	t.ok(bool(altro.get("_gs_capo")), "(il primo ci pensa, e il registro glielo concede)")
	_pensa_davvero(vis, vis._residents[1])
	_in_cammino(c)
	t.ok(c.frase("pensiero"), "la frase parte")
	t.ok(bool(c.get("_gs_capo")), "…e la testa si inclina")
	t.ok(not bool(c.call("capo_livello")),
			"…ma il livello del villaggio è spento: quel rollio è della frase")
	t.eq(_teste(vis), VISITORS.CAPO_MAX, "(e adesso il tetto è pieno)")
	vis.call("_tick_capi", 10.0)
	t.ok(bool(c.call("capo_livello")),
			"il registro riconosce il pensiero che era già lì invece di ignorarlo,"
			+ " e non gli fa pagare un posto che occupa già")
	# e quando il gesto finisce la testa NON si raddrizza: il pensiero che la
	# frase ha mostrato continua, ed è il caso bello
	_gira(c, 8.0)
	t.eq(str(c.gesto_in_corso()), "", "(il gesto è finito)")
	t.ok(bool(c.get("_gs_capo")),
			"…e il pensiero resta: la frase l'ha mostrato, il villaggio lo tiene")
	# ROVESCIATO: su chi NON ci pensa, il registro non deve spegnere il
	# rollio di una frase che non è sua.
	var v2 := _villaggio(t, 1)
	var vis2 = v2["vis"]
	var c2 = v2["corpi"][0]
	vis2.call("_ensure_brain", vis2._residents[0])
	_in_cammino(c2)
	t.ok(c2.frase("pensiero"), "(un altro, che sta benissimo)")
	vis2.call("_tick_capi", 10.0)
	t.ok(bool(c2.get("_gs_capo")),
			"il registro non spegne il rollio di una frase che non ha acceso lui")
	# E IL ROVESCIO PIÙ SOTTILE, che è quello per cui i due bit sono due: se
	# il villaggio TOGLIE il livello mentre una frase sta mostrando proprio
	# quel pensiero, la frase non si tronca a metà. Con un bit solo — cioè
	# facendo spegnere a `capo_pende(false)` anche il rollio della frase — la
	# testa si raddrizzerebbe in mezzo al gesto: l'adesivo staccato male.
	var v3 := _villaggio(t, 1)
	var vis3 = v3["vis"]
	var c3 = v3["corpi"][0]
	_pensa_davvero(vis3, vis3._residents[0])
	vis3.call("_tick_capi", 10.0)
	t.ok(bool(c3.call("capo_livello")), "(uno che ci pensa, col livello del villaggio)")
	_in_cammino(c3)
	t.ok(c3.frase("pensiero"), "(…e una frase che mostra proprio quel pensiero)")
	var animo3: RefCounted = (vis3.get("_animi") as Dictionary)["V0"]
	animo3.limbico.regolazione = 1.0     # gli è tornata la forza di trattenersi
	animo3.limbico.umore = 0.0
	vis3.call("_tick_capi", 10.0)
	t.ok(not bool(c3.call("capo_livello")), "(il villaggio gli toglie il livello)")
	t.ok(bool(c3.get("_gs_capo")),
			"…ma il gesto in corso non si tronca: quella testa è della frase fino alla fine")


# =========================================================================
# 13 · IL RIPOSO DELLA PERSONA HA LO STESSO ORDINE DEL PALCO
# =========================================================================
#
# ⚠️ Questo caso viene da una MISURA, non da un'idea. Col palco ordinato e il
# riposo no, nel villaggio vero (28 residenti, 10 minuti, un giocatore che
# lavora) i **439 no più numerosi erano del riposo**: `ha_visto` bussa 1105
# volte, brucia il riposo di chiunque passi, e le occasioni rare — la
# promozione di un ricordo, il dono — trovavano sempre gente che «ha appena
# parlato». Tredici gesti su tredici erano `ha_visto`, cioè l'unica
# occasione che il vocabolario non era stato fatto per mostrare. Un ordine
# applicato a metà non è un ordine.

func _il_riposo_ha_lo_stesso_ordine(t) -> void:
	var v := _villaggio(t, 1)
	var vis = v["vis"]
	t.ok(vis.chiedi_gesto("V0", "ha_visto"), "il primo passa")
	(v["corpi"][0] as Node).call("gesto_spegni", true)
	vis.set("_gesto_chi", "")
	vis.set("_gesto_acc", 0.0)          # il palco è freddo: resta il riposo
	# METÀ DEL RIPOSO CONSUMATA
	vis.set("_gesto_riposo", {"V0": VISITORS.GESTO_RIPOSO * 0.5})
	_in_cammino(v["corpi"][0])
	t.ok(not vis.chiedi_gesto("V0", "ha_visto"),
			"a metà riposo, «ha visto» lascia stare quella persona")
	t.eq(int(vis.debug_gesti_contatori().get("riposo", 0)), 1,
			"…e il no si chiama «riposo»")
	t.ok(vis.chiedi_gesto("V0", "ha_dedotto"),
			"…ma una deduzione la disturba: capita una volta ogni cinque minuti")
	# e la scala è quella GIUSTA: il riposo è cinque minuti, il palco dodici
	# secondi, e la stessa funzione li governa tutti e due
	t.ok(VISITORS.GESTO_RIPOSO > VISITORS.GESTO_PASSO * 10.0,
			"il riposo della persona è di un altro ordine di grandezza")


# =========================================================================
# 14 · LA SALA D'ATTESA — un gesto rimandato vive quanto la sua premessa
# =========================================================================

func _la_sala_d_attesa(t) -> void:
	var v := _villaggio(t, 1)
	var vis = v["vis"]
	var c = v["corpi"][0]
	# IL CORPO È FERMO: il Punto è un contrasto di MOTO e si rifiuta.
	c._enter_state("r_idle")
	c._timer = 9999.0
	_gira(c, 0.5)
	t.ok(not vis.chiedi_gesto("V0", "se_lo_tiene"),
			"su un corpo fermo il Punto non parte")
	vis.call("_rimanda_gesto", "V0", "se_lo_tiene", 3.2)
	# …e appena il corpo si mette in cammino, la sala d'attesa lo serve
	_in_cammino(c)
	vis.call("_tick_evita", DT)
	t.eq(str(c.gesto_in_corso()), "punto",
			"appena il corpo cammina, l'occasione rimandata parte")
	t.eq(int(vis.debug_gesti_contatori().get("↻ se_lo_tiene", 0)), 1,
			"…e la riprova si conta a parte: una rimandata non è la più insistente")

	# LA SCADENZA. Passata la premessa — la testa che si è girata — si tace,
	# e nessuno lo sa.
	var v2 := _villaggio(t, 1)
	var vis2 = v2["vis"]
	var c2 = v2["corpi"][0]
	c2._enter_state("r_idle")
	c2._timer = 9999.0
	_gira(c2, 0.5)
	vis2.call("_rimanda_gesto", "V0", "se_lo_tiene", 3.2)
	for _i in 4:
		vis2.call("_tick_evita", 1.0)
	_in_cammino(c2)
	vis2.call("_tick_evita", DT)
	t.eq(str(c2.gesto_in_corso()), "",
			"scaduta la premessa, il corpo tace anche se adesso potrebbe")
	t.ok((vis2.get("_gesto_evita") as Dictionary).is_empty(),
			"…e la sala d'attesa si è svuotata da sé")


# =========================================================================
# 16 · L'INQUADRATURA — «vicino» non vuol dire «lo vedi»
# =========================================================================
#
# La camera di questo gioco NON SI GIRA (`Player.tscn`: guarda −Z, 2,70 m
# sopra Mochi e 3,70 dietro, e il giocatore non ha modo di ruotarla): buona
# parte del cerchio dei nove metri sta **dietro la macchina da presa**. Il
# raggio era un'approssimazione della visibilità, e qui approssima male.
#
# MISURATO in partita prima di scrivere questa riga
# (`tools/provino_vocabolario.gd`, parte V — venti residenti, otto minuti,
# un giocatore che cammina e lavora): **12 gesti concessi, 8 fuori
# dall'inquadratura, il 67%**. Due terzi del vocabolario si spendevano dove
# l'occhio non arriva, e il gettone del villaggio che li aveva pagati
# restava caldo dodici secondi lo stesso — cioè quei gesti non erano
# neutri: **rubavano il palco a quelli che si sarebbero visti**.
#
# ⚠️ E IL DEGRADO VA VERSO QUELLO CHE C'ERA: **senza camera si passa.**
# Questa suite, i banchi headless, il diorama del titolo non hanno un
# `Camera3D` corrente, e non devono cambiare comportamento. Spegnere una
# funzione per una domanda a cui non sappiamo rispondere è il degrado dalla
# parte sbagliata: è la stessa regola con cui il portiere del cuore che
# scrive legge la RAM della macchina — zero vuol dire «non lo so», e «non
# lo so» non è mai un no.
func _l_inquadratura_o_silenzio(t) -> void:
	var w = _villaggio(t, 1)
	var vis = w["vis"]
	var c = (w["corpi"] as Array)[0]

	# 1) SENZA CAMERA SI PASSA — è il ramo su cui gira tutto il resto della
	#    suite, e va provato per primo o non si saprebbe se il no di dopo è
	#    dell'inquadratura o di qualcos'altro.
	c.global_position = Vector3(0, 0, -3.0)
	_in_cammino(c, Vector3(0, 0, -40))
	vis.set("_gesto_acc", 0.0)
	vis.set("_gesto_chi", "")
	vis.set("_gesto_riposo", {})
	t.ok(vis.chiedi_gesto("V0", "ha_visto"),
			"senza camera in scena il gesto esce come è sempre uscito")

	# la camera VERA del gioco: dietro e sopra il giocatore, e guarda −Z
	var cam := t.stage(Camera3D.new()) as Camera3D
	cam.fov = 50.0
	cam.global_position = Vector3(0, 2.7, 3.7)
	cam.current = true

	# 2) DAVANTI ALLA MACCHINA SI RECITA
	c.call("gesto_spegni", true)
	c.global_position = Vector3(0, 0, -3.0)
	_in_cammino(c, Vector3(0, 0, -40))
	vis.set("_gesto_acc", 0.0)
	vis.set("_gesto_chi", "")
	vis.set("_gesto_riposo", {})
	t.ok(vis.chiedi_gesto("V0", "ha_visto"),
			"col corpo davanti alla camera il gesto esce")

	# 3) DIETRO LA MACCHINA, SILENZIO — ed è a cinque metri, cioè DENTRO il
	#    raggio: è proprio il caso che il raggio da solo lasciava passare.
	c.call("gesto_spegni", true)
	c.global_position = Vector3(0, 0, 5.0)
	_in_cammino(c, Vector3(0, 0, 40))
	vis.set("_gesto_acc", 0.0)
	vis.set("_gesto_chi", "")
	vis.set("_gesto_riposo", {})
	var prima: Dictionary = vis.call("debug_gesti_contatori")
	t.ok(not vis.chiedi_gesto("V0", "ha_visto"),
			"dietro la camera (a 5 m, dentro il raggio) NON si recita")
	var dopo: Dictionary = vis.call("debug_gesti_contatori")
	t.eq(int(dopo.get("fuori dall'inquadratura", 0))
			- int(prima.get("fuori dall'inquadratura", 0)), 1,
			"e il no ha il suo nome, non quello di un altro")
	# …e il gettone NON si è consumato: un gesto rifiutato non costa il palco
	t.almost(float(vis.get("_gesto_acc")), 0.0,
			"un gesto fuori inquadratura non brucia il gettone del villaggio",
			0.001)

	# 4) E IL RAGGIO RESTA: dentro l'inquadratura ma a venti metri, silenzio.
	#    Le due regole sono diverse e servono tutte e due.
	c.call("gesto_spegni", true)
	c.global_position = Vector3(0, 0, -20.0)
	_in_cammino(c, Vector3(0, 0, -60))
	vis.set("_gesto_acc", 0.0)
	vis.set("_gesto_chi", "")
	vis.set("_gesto_riposo", {})
	t.ok(not vis.chiedi_gesto("V0", "ha_visto"),
			"dentro l'inquadratura ma fuori raggio: sempre silenzio")
	cam.current = false


# =========================================================================
# 17 · L'OCCLUSIONE — «dentro l'inquadratura» non vuol dire «lo vedi»
# =========================================================================
#
# Il cancello di prima provava il FRUSTUM, cioè dove sta un corpo. Ma il
# villaggio è pieno di roba che sta nell'inquadratura esattamente come lui:
# muri, tronchi, schienali, il Grande Albero. Un gesto concesso a chi è
# dietro qualcosa costa dodici secondi di gettone e cinque minuti di riposo
# **tolti a un vicino che si sarebbe visto** — è il gemello esatto del
# guasto dell'inquadratura, un passo più in là.
#
# MISURATO nel villaggio vero contro l'oracolo dei PIXEL (spegnere il corpo
# per un fotogramma e contare di quanto cambia il quadro:
# `tools/misura_occlusione.gd`, 124 campioni). La maschera dei tre raggi è
# quasi sempre TUTTA O NIENTE — 74 a zero, 47 a tre, **tre soli in mezzo** —
# quindi fra «due» e «tre» la misura non decide: ballano tre campioni su
# centoventiquattro. `GESTO_COPERTO_MIN` è TRE per la ragione di sempre,
# **nel dubbio il gesto esce**: un palo, uno stipite, uno schienale coprono
# un pezzo di corpo e non coprono una persona. Quello che il cancello compra
# si vede sull'esito — sui gesti veri, a cancello acceso, gli invisibili
# sono ZERO (erano il 17% a cancello spento, misurato appaiato a blocchi
# alternati nella stessa corsa).
func _l_occlusione_o_silenzio(t) -> void:
	var w = _villaggio(t, 1)
	var vis = w["vis"]
	var c = (w["corpi"] as Array)[0]
	# ⚠️ **VIA LE CAMERE DEL CASO DI PRIMA.** I nodi messi in scena vivono
	# fino a FINE FOTOGRAMMA, e un `current = false` non basta: il viewport
	# promuove da sé la prossima `Camera3D` che trova nell'albero. Il caso
	# dell'inquadratura ne lascia una, e con quella addosso il ramo «senza
	# camera» misurerebbe la macchina di un altro.
	_niente_camere(t)
	var cam := t.stage(Camera3D.new()) as Camera3D
	cam.fov = 50.0
	cam.global_position = Vector3(0, 2.7, 3.7)
	cam.current = true

	# 1) CAMPO LIBERO: il gesto esce. È la controprova, e va per prima o non
	#    si saprebbe se il no di dopo è del muro o di qualcos'altro.
	t.ok(_riprova(vis, c), "a campo libero il gesto esce")
	t.eq(int(vis.call("debug_quote_coperte", c.global_position)), 0,
			"…e nessuna delle tre quote ha qualcosa davanti")

	# 2) UN MURO IN MEZZO: silenzio, e il no ha il suo nome.
	var muro := _muro(t, 4.0)
	t.eq(int(vis.call("debug_quote_coperte", c.global_position)), 7,
			"col muro davanti sono coperte tutte e tre le quote")
	var prima: Dictionary = vis.call("debug_gesti_contatori")
	t.ok(not _riprova(vis, c), "dietro un muro non si recita")
	var dopo: Dictionary = vis.call("debug_gesti_contatori")
	t.eq(int(dopo.get("coperto", 0)) - int(prima.get("coperto", 0)), 1,
			"e il no si chiama «coperto», non «fuori dall'inquadratura»")
	# …e il gettone NON si consuma: un gesto rifiutato non costa il palco
	t.almost(float(vis.get("_gesto_acc")), 0.0,
			"un gesto coperto non brucia il gettone del villaggio", 0.001)

	# 3) MEZZO CORPO SI VEDE, E TANTO BASTA. Questo è il caso che il numero
	#    tre compra, ed è quello che una regola «prudente» butterebbe via:
	#    una staccionata copre le gambe, uno stipite copre gambe e petto, e
	#    di quel vicino se ne vede ancora abbastanza per leggerci un gesto.
	# ⚠️ **`free()` E NON `queue_free()`**: dentro un caso non passa nessun
	# fotogramma, e un nodo in coda resterebbe con le sue collisioni ATTIVE
	# per tutto il resto del caso — è la trappola della Vetreria, dove un
	# `queue_free` lasciava il varco tappato per un frame.
	muro.free()
	var basso := _muro(t, 1.42)
	t.eq(int(vis.call("debug_quote_coperte", c.global_position)), 4,
			"una staccionata copre SOLO le gambe")
	t.ok(_riprova(vis, c), "…e di lì sopra il gesto si vede ancora: esce")

	# …e nemmeno DUE quote bastano. È il caso che `GESTO_COPERTO_MIN = 3`
	# compra, e quello che una regola «prudente» butterebbe via: uno stipite
	# copre gambe e petto, e di quel vicino se ne vede ancora la testa —
	# misurato coi pixel, fra il 6,9% e il 32% della sagoma, contro lo 0,0%
	# di chi è coperto davvero.
	basso.free()
	_muro(t, 1.58)
	t.eq(int(vis.call("debug_quote_coperte", c.global_position)), 6,
			"uno stipite copre gambe e petto, e non la testa")
	t.ok(_riprova(vis, c), "…e due quote su tre non bastano a zittire")

	# 4) IL DEGRADO VA VERSO QUELLO CHE C'ERA: senza camera si passa, muro o
	#    non muro. È la stessa regola dell'inquadratura, e vale per i banchi
	#    headless, il diorama del titolo e chiunque non abbia una macchina.
	_muro(t, 4.0)
	t.eq(int(vis.call("debug_quote_coperte", c.global_position)), 7,
			"col muro alto tornano coperte tutte e tre")
	t.ok(not _riprova(vis, c), "…e infatti si tace")
	_niente_camere(t)
	t.eq(int(vis.call("debug_quote_coperte", c.global_position)), 0,
			"senza camera non si sa rispondere, e «non lo so» non è mai un no")
	t.ok(_riprova(vis, c), "senza camera il gesto esce come è sempre uscito")


# =========================================================================
# 17b · L'ORDINE DEI CANCELLI — il caro sta per ultimo
# =========================================================================
#
# Tre raggi contro la fisica costano molto più di un confronto di frustum, e
# di richieste ne arrivano centinaia al minuto. L'ordine non è estetica: è la
# stessa regola dei quattro cancelli di `BuildSystem.deviazione` — in ordine
# di prezzo, e il caso comune non paga il caso raro.
#
# Si prova col NOME DEL NO, che è l'unica cosa osservabile da fuori: un
# corpo che è insieme fuori raggio, fuori inquadratura E coperto dev'essere
# respinto dal più economico dei tre.
func _l_ordine_dei_cancelli(t) -> void:
	var w = _villaggio(t, 1)
	var vis = w["vis"]
	var c = (w["corpi"] as Array)[0]
	_niente_camere(t)
	var cam := t.stage(Camera3D.new()) as Camera3D
	cam.fov = 50.0
	cam.global_position = Vector3(0, 2.7, 3.7)
	cam.current = true
	_muro(t, 4.0)

	# ⚠️ **E UN MURO ANCHE DIETRO LA MACCHINA.** La prima stesura di questo
	# caso metteva il corpo dietro la camera e il muro davanti: fra l'occhio
	# e quel corpo non c'era niente, quindi i tre raggi dicevano «scoperto»
	# comunque, e **spostare il cancello caro in cima restava verde**
	# (misurato). Perché la domanda sull'ordine abbia una risposta, quel
	# corpo dev'essere fuori inquadratura E coperto insieme.
	_muro(t, 4.0, 4.5)

	# dietro la macchina (e dietro un muro): deve vincere l'inquadratura
	c.call("gesto_spegni", true)
	c.global_position = Vector3(0, 0, 5.0)
	_in_cammino(c, Vector3(0, 0, 40))
	c.global_position = Vector3(0, 0, 5.0)
	_sgombra(vis)
	t.eq(int(vis.call("debug_quote_coperte", c.global_position)), 7,
			"il corpo dietro la macchina è ANCHE coperto: la domanda ha senso")
	var p1: Dictionary = vis.call("debug_gesti_contatori")
	t.ok(not vis.chiedi_gesto("V0", "ha_visto"), "silenzio")
	var d1: Dictionary = vis.call("debug_gesti_contatori")
	t.eq(int(d1.get("fuori dall'inquadratura", 0))
			- int(p1.get("fuori dall'inquadratura", 0)), 1,
			"chi è dietro la macchina lo respinge il frustum, che è gratis")
	t.eq(int(d1.get("coperto", 0)) - int(p1.get("coperto", 0)), 0,
			"…e i tre raggi non si tirano nemmeno")

	# a venticinque metri, dentro l'inquadratura e dietro il muro: deve
	# vincere il raggio, che è ancora più economico del frustum
	c.call("gesto_spegni", true)
	c.global_position = Vector3(0, 0, -25.0)
	_in_cammino(c, Vector3(0, 0, -60))
	c.global_position = Vector3(0, 0, -25.0)
	_sgombra(vis)
	t.eq(int(vis.call("debug_quote_coperte", c.global_position)), 7,
			"e il corpo lontano è coperto pure lui")
	var p2: Dictionary = vis.call("debug_gesti_contatori")
	t.ok(not vis.chiedi_gesto("V0", "ha_visto"), "silenzio")
	var d2: Dictionary = vis.call("debug_gesti_contatori")
	t.eq(int(d2.get("fuori raggio", 0)) - int(p2.get("fuori raggio", 0)), 1,
			"chi è lontano lo respinge il raggio, prima di tutto il resto")
	t.eq(int(d2.get("coperto", 0)) - int(p2.get("coperto", 0)), 0,
			"…e nemmeno lì si paga la fisica")
	cam.current = false


## Un muro largo fra la camera e il corpo, alto fin dove si vuole. Le
## `CollisionShape3D` sono figlie DIRETTE dello `StaticBody3D`: una shape
## dentro un contenitore non viene registrata affatto, e senza errori (è la
## trappola della Vetreria).
func _muro(t, cima: float, z := 0.0) -> Node3D:
	var body := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, cima + 1.0, 0.4)
	forma.shape = box
	forma.position = Vector3(0, (cima - 1.0) * 0.5, 0)
	body.add_child(forma)
	t.stage(body)
	body.global_position = Vector3(0, 0, z)
	# ⚠️ **E LO SI FORZA.** Le notifiche di trasformazione dei `Node3D` sono
	# BATCHED: la fisica riceve la posizione nuova a fine fotogramma, e
	# dentro un caso di test quel momento non arriva mai. Il muro messo a
	# z = 4,5 restava a z = 0 per il server, e i tre raggi lo attraversavano
	# come se non ci fosse — con la suite verde (misurato: un muro
	# perfettamente in mezzo dava maschera 0).
	body.force_update_transform()
	return body


## Via ogni `Camera3D` e ogni muro dall'albero, SUBITO. Per le camere,
## `current = false` non basta: il viewport ne promuove un'altra da sé. E
## tutti i casi di questo file girano nello stesso FOTOGRAMMA — il runner ne
## fa uno per file — quindi la scenografia di un caso resta addosso al
## successivo se non la si toglie a mano.
func _niente_camere(t) -> void:
	for tipo in ["Camera3D", "StaticBody3D"]:
		for n in t.tree().root.find_children("*", tipo, true, false):
			var nodo := n as Node
			if nodo.get_parent() != null:
				nodo.get_parent().remove_child(nodo)
			nodo.free()


## Il palco sgombro: il gettone freddo, nessuno che parla, nessun riposo.
func _sgombra(vis) -> void:
	vis.set("_gesto_acc", 0.0)
	vis.set("_gesto_chi", "")
	vis.set("_gesto_riposo", {})


## Rimette il corpo davanti alla macchina, in cammino, col palco sgombro, e
## richiede il gesto. Tutto quello che serve per fare la stessa domanda due
## volte di seguito e confrontare le risposte.
func _riprova(vis, c) -> bool:
	c.call("gesto_spegni", true)
	c.global_position = Vector3(0, 0, -3.0)
	_in_cammino(c, Vector3(0, 0, -40))
	# ⚠️ **E LO SI RIMETTE DOV'ERA.** `_in_cammino` fa girare sette decimi di
	# secondi di `_process`: il corpo cammina davvero, e si sposta di un
	# metro buono. Senza questa riga la domanda si fa su un punto e la
	# risposta arriva da un altro — e il muretto tarato per le gambe a tre
	# metri non copriva più niente a quattro. Il ciclo del passo resta a
	# regime: quello che si rimette a posto è la posizione, non l'andatura.
	c.global_position = Vector3(0, 0, -3.0)
	_sgombra(vis)
	return bool(vis.chiedi_gesto("V0", "ha_visto"))


# =========================================================================
# 17c · LA LEVA È DEI BANCHI, E NEL GIOCO NON LA TOCCA NESSUNO
# =========================================================================
#
# `Visitors.debug_occlusione` esiste per una ragione sola: avere il «prima»
# e il «dopo» sulla STESSA corsa, sugli stessi corpi, negli stessi istanti
# (`tools/misura_occlusione.gd` la alterna a blocchi). È la stessa disciplina
# del banco della concorrenza del cuore che scrive: un banco può togliere di
# mezzo una cosa, il gioco no.
#
# Se un giorno qualcuno la spegnesse in partita — anche solo «per provare» —
# il cancello sparirebbe **senza che una sola asserzione se ne accorga**,
# perché tutti i casi qui sopra la lasciano accesa. Perciò si scandaglia il
# sorgente, saltando i commenti: questa lezione la leva la NOMINA apposta.
func _la_leva_dell_occlusione_e_dei_banchi(t) -> void:
	var vis = Registro.new()
	t.ok(bool(vis.get("debug_occlusione")),
			"di serie il cancello è ACCESO: il gioco vero non ha una leva")
	vis.free()
	# si cerca la SCRITTURA, non la parola: `Visitors` la dichiara e la
	# legge, ed è casa sua. La dichiarazione è `debug_occlusione :=`, che
	# nessuno di questi due telai prende.
	var colpevoli: Array = []
	for f in _script_sotto("res://scenes") + _script_sotto("res://systems"):
		var src := _codice(f)
		if src.contains("debug_occlusione = ") \
				or src.contains("\"debug_occlusione\""):
			colpevoli.append(f)
	t.ok(colpevoli.is_empty(),
			"nel gioco nessuno la spegne %s" % str(colpevoli))


static func _script_sotto(radice: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(radice)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		var p := radice.path_join(f)
		if dir.current_is_dir():
			out.append_array(_script_sotto(p))
		elif f.ends_with(".gd"):
			out.append(p)
		f = dir.get_next()
	dir.list_dir_end()
	return out


## Il sorgente SENZA le righe di commento: la lezione di questa leva è
## scritta apposta nei commenti di `Visitors`, e un guardiano ingenuo la
## scambierebbe per un suo uso — dichiarando colpevole proprio il file che
## la definisce.
static func _codice(percorso: String) -> String:
	var righe := PackedStringArray()
	for r in FileAccess.get_file_as_string(percorso).split("\n"):
		var s := (r as String).strip_edges()
		if s.begins_with("#"):
			continue
		righe.append(r)
	return "\n".join(righe)


# =========================================================================
# 18 · L'AFFONDO — il Capo che arriva anche a nove metri
# =========================================================================
#
# Il rollio del capo è il livello che dice «ci sto pensando», e il suo
# difetto dichiarato era la distanza: sei gradi su una testona sono
# quattrocento pixel a due metri e SEDICI a nove — l'antialiasing.
#
# ⚠️ **LA CURA OVVIA È SBAGLIATA, ED È MISURATA.** Ingrandire il rollio
# compra rilevabilità e perde LEGGIBILITÀ: `tools/provino_verso.gd`, sul rig
# vero e dalla camera vera, dà verso **1,60 a 6° · 1,27 a 10° · 1,11 a 14°**
# — sotto il cancello, cioè un gesto che si nota e non si legge. La strada
# giusta è un'altra grandezza: la SAGOMA. Con l'affondo, alla stessa
# rilevabilità, il verso NON si muove (1,60 contro 1,60 nella colonna
# peggiore), e sul PROFILO — dove un rollio attorno all'asse ottico è visto
# di taglio e non fa quasi niente — i pixel passano da 115 a 376, **tre volte
# e mezzo**.
#
# Qui non si contano pixel (in headless non ce ne sono): si prova che il
# canale c'è, che segue il rollio, che **non porta un secondo significato**,
# e che non resta orfano.
func _l_affondo_del_capo(t) -> void:
	# 1) È SIMMETRICO, e non è un dettaglio: il rollio ha già un verso, e un
	#    canale che ne portasse un secondo direbbe due cose insieme. La testa
	#    scende uguale da tutte e due le parti.
	t.almost(GESTI.capo_affondo(0.09), GESTI.capo_affondo(-0.09),
			"l'affondo è lo stesso da una parte e dall'altra")
	t.almost(GESTI.capo_affondo(0.0), 0.0,
			"a capo dritto la testa sta dov'era")
	t.ok(GESTI.capo_affondo(GESTI.CAPO_AMP_MAX) < GESTI.capo_affondo(GESTI.CAPO_AMP_MIN),
			"più il capo pende, più la testa scende")
	t.ok(GESTI.capo_affondo(GESTI.CAPO_AMP_MAX) < -0.03,
			"e al colmo scende abbastanza da cambiare la sagoma")

	# 2) SUL RIG VERO: il livello acceso porta la testa giù.
	var v = _corpo(t, 4242)
	v.call("_enter_state", "r_idle")
	v.set("_timer", 999999.0)
	v.call("capo_pende", true)
	_gira(v, 2.0)
	var giu := float((v.get("_gs_cur") as Dictionary).get("hpy", 0.0))
	t.ok(giu < -0.01, "col capo storto la testa è affondata (%.4f)" % giu)

	# 3) IL TUFFO. Passando da una parte all'altra la molla attraversa il
	#    dritto, e la testa RISALE prima di riscendere: a nove metri il
	#    rollio non si vede più e quel tuffo sì — è l'unica cosa che
	#    distingue «sta pensando» da «sta lì».
	#
	#    ⚠️ E si guarda il MASSIMO lungo il tragitto, non il valore alla
	#    fine: alla fine la testa è di nuovo giù dall'altra parte, e un
	#    affondo COSTANTE — cioè il canale senza il tuffo — darebbe
	#    esattamente lo stesso numero.
	v.set("_gs_capo_next", 0.0)
	var risalita := -9.0
	var passi := 0
	while passi < 90:
		passi += 1
		v._process(DT)
		risalita = maxf(risalita,
				float((v.get("_gs_cur") as Dictionary).get("hpy", 0.0)))
	t.ok(risalita > giu * 0.35,
			"nel trasferimento la testa risale (%.4f contro %.4f)"
			% [risalita, giu])
	var dopo := float((v.get("_gs_cur") as Dictionary).get("hpy", 0.0))
	t.ok(dopo < -0.01, "…e dall'altra parte riscende (%.4f)" % dopo)

	# 4) NON È UN CANALE ORFANO. Spento il livello, la molla rientra da sé e
	#    la testa torna al suo posto: nessuna rete da ricordarsi altrove.
	v.call("capo_pende", false)
	_gira(v, 3.0)
	t.almost(float((v.get("_gs_cur") as Dictionary).get("hpy", 0.0)), 0.0,
			"spento il capo, la testa torna al suo posto", 0.001)


# =========================================================================
# 17d · L'OCCHIO DENTRO UN SOLIDO — il caso che le foto hanno trovato
# =========================================================================
#
# La camera di questo gioco segue Mochi a scorrimento fisso e **non schiva
# niente**: le capita di finire dentro il tronco del Grande Albero. Lì lo
# schermo è tutto corteccia e del vicino non arriva un pixel — ed è proprio
# lì che i tre raggi dicevano «scoperto», perché di serie un raggio che
# PARTE dentro una forma non la vede affatto.
#
# MISURATO nel villaggio vero, e trovato GUARDANDO: il banco
# (`tools/misura_occlusione.gd`) fotografa i casi in cui la regola e i pixel
# non vanno d'accordo, e due di quelle foto sono uno schermo pieno di
# corteccia con il riquadro del vicino vuoto in mezzo. Nessun numero da solo
# lo avrebbe detto: dicevano «la regola ha sbagliato», non PERCHÉ.
func _l_occhio_dentro_un_solido(t) -> void:
	var w = _villaggio(t, 1)
	var vis = w["vis"]
	var c = (w["corpi"] as Array)[0]
	_niente_camere(t)
	var muro := _muro(t, 4.0)
	var cam := t.stage(Camera3D.new()) as Camera3D
	cam.fov = 50.0
	# dentro il muro, che è la corteccia del Grande Albero in piccolo
	cam.global_position = Vector3(0, 1.5, 0)
	cam.current = true
	c.global_position = Vector3(0, 0, -3.0)
	t.eq(int(vis.call("debug_quote_coperte", c.global_position)), 7,
			"con l'occhio DENTRO un solido è coperto tutto")
	t.ok(not _riprova(vis, c), "…e non si recita per nessuno")

	# …e uscendone di mezzo metro il mondo torna quello di prima
	muro.free()
	t.eq(int(vis.call("debug_quote_coperte", c.global_position)), 0,
			"tolto il solido, l'occhio ci vede di nuovo")
	t.ok(_riprova(vis, c), "…e il gesto esce")
	_niente_camere(t)
