extends RefCounted
## LE POSTURE DEVONO TORNARE INDIETRO — e il pareggio non deve eleggere
## nessuno. Tre guasti veri, tutti misurati sul codice vero:
##
##  • «sereno» esisteva nella tabella `Visitor.RECITA` e NESSUNO la
##    scriveva mai: togliere il meta "postura" non entrava in nessun ramo
##    di `_recita_applica`, e la posa restava addosso per il resto della
##    partita. Il vicino che il giocatore consola per giorni restava curvo
##    con le spalle basse — il gesto più delicato del gioco senza nessun
##    riscontro nel corpo di chi lo riceve.
##  • `has_meta("postura")` non risponde a «il corpo è libero?»: quando un
##    transitorio si consuma il meta viene RISCRITTO con la stabile
##    sottostante, quindi dal primo saluto in poi (bastava passare a 1,4 m)
##    esiste per sempre. Il ramo di `Visitors` che fa restare fuori con le
##    spalle basse chi ha trovato la porta chiusa era morto da lì in avanti.
##  • `Affetti.il_piu_caro` rompeva i pareggi con un `>` stretto, cioè con
##    l'ORDINE dell'array dei residenti. I gesti «a tutti» (la guardia che
##    veglia, il cuoco che divide) danno conti identici al centesimo verso
##    tutti: la coppia si sarebbe spostata su un'altra persona il giorno in
##    cui qualcuno arriva o parte. È la classifica invisibile che questo
##    sistema si è ripromesso di non scrivere.
##
## Le prove ENTRANO nello stato vero: un Visitor costruito dal DNA che fa
## girare il suo `_process`, un Affetti con la sua ferita aperta, e le
## funzioni pure chiamate con le righe nella forma esatta che
## `Lavori._gesto_verso_tutti` produce.

const VISITOR := "res://scenes/npc/Visitor.gd"
const AFFETTI := "res://scenes/npc/Affetti.gd"
const ANIMO := "res://scenes/npc/Animo.gd"
const VISITORS := "res://scenes/npc/Visitors.gd"
const DNA := "res://scenes/npc/ChibiDNA.gd"
const AFF := preload("res://scenes/npc/Affetti.gd")

const DT := 1.0 / 60.0


## Il minimo indispensabile perché Affetti trovi il suo vicino: `_nodo_di`
## legge `_residents` da Visitors, e `_giorno()` legge `day` da DayNight.
class FintoVisitors extends Node:
	var _residents: Array = []
	var _animi := {}


class FintoGiorno extends Node3D:
	var day := 10


func run(t) -> void:
	var vs: GDScript = load(VISITOR)
	t.ok(vs != null and vs.can_instantiate(), "Visitor.gd compila")
	if vs == null or not vs.can_instantiate():
		return
	_test_il_corpo_torna_neutro(t, vs)
	_test_i_transitori_restano_vivi(t, vs)
	_test_il_meta_non_dice_se_il_corpo_e_libero(t, vs)
	_test_chi_resta_fuori_lo_dice_col_corpo(t, vs)
	_test_la_ferita_si_richiude_anche_nel_corpo(t, vs)
	_test_il_pareggio_non_elegge_nessuno(t)
	_test_il_pareggio_non_separa(t)


func _nuovo_villager(t, vs: GDScript, seme: int):
	var dna_s: GDScript = load(DNA)
	var v = vs.new()
	v.dna = dna_s.generate(seme)
	t.stage(v)
	return v


func _gira(v, quanti: int) -> void:
	for f in quanti:
		v._process(DT)


# ---------------------------------------------------------------- il ritorno

## IL CUORE DEL GUASTO: si posa una postura stabile, si TOGLIE il meta, e il
## corpo deve tornare neutro. Prima restava curvo per sempre.
func _test_il_corpo_torna_neutro(t, vs: GDScript) -> void:
	var v = _nuovo_villager(t, vs, 4242)
	if (v._c_ears as Array).size() < 2:
		t.ok(false, "il villager di prova non ha il rig chibi")
		return
	var ear_base: float = (v._c_ears[0] as Node3D).rotation.x

	v.set_meta("postura", "spalle_basse")
	_gira(v, 120)
	var ear_giu: float = (v._c_ears[0] as Node3D).rotation.x
	t.ok(ear_giu > ear_base + 0.3,
			"la posa è ADDOSSO: le orecchie sono giù (%.2f → %.2f)"
			% [ear_base, ear_giu])

	# …e adesso qualcuno la toglie (la ferita che si richiude, il concerto
	# che finisce): il meta sparisce e nessuno scrive niente al suo posto.
	v.remove_meta("postura")
	_gira(v, 240)
	t.eq(str(v.postura_stabile()), "sereno",
			"tolto il meta, la postura stabile TORNA neutra")
	t.almost(float((v._rc_appl as Dictionary).get("ear", 9.9)), 0.0,
			"…e l'offset che la recita somma al rig si è spento", 0.01)
	t.almost((v._c_ears[0] as Node3D).rotation.x, ear_base,
			"…le orecchie sono tornate dov'erano: il corpo si è raddrizzato",
			0.03)


## LA VALVOLA: il ritorno a «sereno» NON deve spegnere i sussulti. Un
## transitorio arriva sempre su un meta che poi viene riscritto con la
## stabile sottostante: se il ramo del ritorno gli passasse davanti, il
## corpo smetterebbe di trasalire.
func _test_i_transitori_restano_vivi(t, vs: GDScript) -> void:
	var v = _nuovo_villager(t, vs, 909)
	var ear_base: float = (v._c_ears[0] as Node3D).rotation.x
	# nessuna postura stabile addosso: solo lo spavento
	v.set_meta("postura", "trasalisce")
	_gira(v, 6)
	t.ok((v._c_ears[0] as Node3D).rotation.x < ear_base - 0.15,
			"il sussulto recita comunque: le orecchie schizzano su (%.2f)"
			% (v._c_ears[0] as Node3D).rotation.x)
	t.eq(str(v.postura_stabile()), "sereno",
			"…e sotto resta il corpo neutro, non una posa stabile inventata")
	_gira(v, 200)
	t.almost((v._c_ears[0] as Node3D).rotation.x, ear_base,
			"…e lo spavento si consuma da solo, senza lasciare residui", 0.03)


# ------------------------------------------- il meta non è la postura

## LA DOMANDA GIUSTA. Dopo un saluto — un transitorio consumato — il meta
## ESISTE anche se il corpo è neutro: ogni ramo scritto su
## `has_meta("postura") == false` è morto da quel momento in poi.
func _test_il_meta_non_dice_se_il_corpo_e_libero(t, vs: GDScript) -> void:
	var v = _nuovo_villager(t, vs, 31415)
	t.ok(not v.has_meta("postura"), "appena nato, nessun meta addosso")
	t.ok(v.postura_libera(), "…e il corpo è libero")

	# il giocatore gli passa accanto: saluto (transitorio), che si consuma
	v.set_meta("postura", "saluto_festoso")
	_gira(v, 2)
	t.ok(v.has_meta("postura"),
			"consumato il saluto, il meta ESISTE ancora: è la trappola che"
			+ " ha ucciso il ramo di Visitors")
	t.ok(v.postura_libera(),
			"…ma il corpo è libero lo stesso, e ora il gioco lo sa chiedere")

	# con una posa vera addosso, invece, il corpo NON è libero
	v.set_meta("postura", "petto_in_fuori")
	_gira(v, 2)
	t.ok(not v.postura_libera(),
			"con una posa stabile addosso il corpo non è libero")
	t.eq(str(v.postura_stabile()), "petto_in_fuori",
			"…e dice quale posa ha")


# --------------------------------------------------- la porta che non si apre

## IL TELEGRAFO PIÙ SILENZIOSO DEL GIOCO: chi ha trovato la porta chiusa non
## sparisce dentro, resta fuori con le spalle basse — e non c'è nessun toast
## a spiegarlo. Girava sul codice VERO di Visitors (`_aggiorna_posa_fuori`),
## con un Visitor vero: il ramo era morto dal primo saluto in poi.
func _test_chi_resta_fuori_lo_dice_col_corpo(t, vs: GDScript) -> void:
	var v = _nuovo_villager(t, vs, 2024)
	var vis = load(VISITORS).new()   # non in scena: `_ready` vuole il villaggio

	# il giocatore le è passato accanto durante il giorno: saluto consumato
	v.set_meta("postura", "saluto_festoso")
	_gira(v, 2)
	t.ok(v.has_meta("postura"), "dopo il saluto il meta esiste (la trappola)")

	# sera: la porta non si apre
	vis._aggiorna_posa_fuori("Anna", v, true)
	t.eq(str(v.get_meta("postura", "")), "spalle_basse",
			"CHI RESTA FUORI LO DICE COL CORPO, anche dopo un saluto")
	_gira(v, 120)

	# la notte passa (o la porta si riapre): la posa se ne va
	vis._aggiorna_posa_fuori("Anna", v, false)
	t.ok(not v.has_meta("postura"),
			"…e la mattina dopo non è più curvo: la posa era NOSTRA e si toglie")

	# …ma se nel frattempo l'ha coperta un altro sistema, non la si spegne
	vis._aggiorna_posa_fuori("Anna", v, true)
	v.set_meta("postura", "fagotto_in_spalla")
	vis._aggiorna_posa_fuori("Anna", v, false)
	t.eq(str(v.get_meta("postura", "")), "fagotto_in_spalla",
			"la posa di un altro sistema resta dov'è")

	# e su un corpo già occupato non si posa niente: la ferita degli Affetti
	# vale più della porta chiusa, e non si sovrascrive
	var w = _nuovo_villager(t, vs, 2025)
	w.set_meta("postura", "petto_in_fuori")
	_gira(w, 2)
	vis._aggiorna_posa_fuori("Bruno", w, true)
	t.eq(str(w.get_meta("postura", "")), "petto_in_fuori",
			"su un corpo già occupato la porta chiusa non scrive")
	vis.free()


# ---------------------------------------------------- la ferita e il corpo

## END-TO-END: la ferita degli Affetti si richiude (il giocatore ha annodato
## abbastanza momenti) e il CORPO di quella persona si raddrizza davvero.
func _test_la_ferita_si_richiude_anche_nel_corpo(t, vs: GDScript) -> void:
	var v = _nuovo_villager(t, vs, 777)
	var ear_base: float = (v._c_ears[0] as Node3D).rotation.x

	var animo_s: GDScript = load(ANIMO)
	var anna = animo_s.new()
	anna.setup({"name": "Anna", "seed": 5, "tratti": {"orgoglio": 0.6,
			"lealta": 0.5, "grinta": 0.5, "codardia": 0.3, "ambizione": 0.4}})
	var bruno = animo_s.new()
	bruno.setup({"name": "Bruno", "seed": 6, "tratti": {"orgoglio": 0.4,
			"lealta": 0.5, "grinta": 0.5, "codardia": 0.5, "ambizione": 0.4}})

	var fv := FintoVisitors.new()
	fv._animi = {"Anna": anna, "Bruno": bruno}
	# Bruno non ha un corpo in questa prova: qui guardiamo quello di Anna
	fv._residents = [
		{"dna": {"name": "Anna"}, "label": "Anna", "node": v},
		{"dna": {"name": "Bruno"}, "label": "Bruno", "node": null},
	]
	t.stage(fv)
	var fg := FintoGiorno.new()
	t.stage(fg)
	var aff = load(AFFETTI).new()
	t.stage(aff)
	aff._visitors = fv
	aff._daynight = fg
	aff._cablato = true

	# LA ROTTURA VERA: ognuno dei due sceglie da sé, e il corpo lo dice
	aff._si_sono_lasciati("Anna", "Bruno", 3)
	t.ok(aff._ferite.has("Anna"), "la rottura ha aperto la sua ferita")
	t.eq(str(v.get_meta("postura", "")), "spalle_basse",
			"…e la posa è addosso dal primo giorno")
	_gira(v, 120)
	t.ok((v._c_ears[0] as Node3D).rotation.x > ear_base + 0.3,
			"la rottura si vede nel corpo: orecchie e spalle giù")

	# il giocatore le è stato accanto abbastanza: la ferita ha la sua chiave
	var reazione := str((aff._ferite["Anna"] as Dictionary).get("reazione", ""))
	var serve: int = int(AFF.MOMENTI_CHIAVE.get(reazione, 2))
	for m in serve:
		aff.momento_del_giocatore("Anna")
	aff._le_ferite_si_richiudono(10)
	t.ok(not aff._ferite.has("Anna"),
			"con i momenti del giocatore la ferita («%s») si richiude" % reazione)
	t.ok(not v.has_meta("postura"),
			"…e la posa della rottura è stata TOLTA (prima restava per sempre)")
	_gira(v, 240)
	t.almost((v._c_ears[0] as Node3D).rotation.x, ear_base,
			"IL CORPO SI RADDRIZZA: è l'unico riscontro al gesto del giocatore",
			0.03)

	# …ma non si spegne la posa di un ALTRO sistema. Se nel frattempo la
	# partenza le ha messo il fagotto in spalla, chi guarisce da una
	# rottura non glielo toglie: quel sistema non se ne accorgerebbe.
	aff._posa("Anna", "spalle_basse")
	v.set_meta("postura", "fagotto_in_spalla")
	aff._ferite["Anna"] = {"reazione": reazione, "ex": "Bruno",
			"dal": 3, "momenti": serve}
	aff._le_ferite_si_richiudono(10)
	t.eq(str(v.get_meta("postura", "")), "fagotto_in_spalla",
			"la posa di un altro sistema resta dov'è: si toglie solo la propria")


# ------------------------------------------------------------- il pareggio

## I GESTI «A TUTTI» (Lavori._gesto_verso_tutti) scrivono lo stesso tipo di
## gesto, lo stesso giorno, verso OGNI residente. Il conto è identico al
## centesimo: chi vinceva era il primo dell'array.
func _test_il_pareggio_non_elegge_nessuno(t) -> void:
	var righe: Array = []
	for g in 3:
		for chi in ["Anna", "Bruno", "Carla"]:
			righe.append({"a": "Guardia", "b": chi, "t": "veglia", "d": g})

	var ordini := [
		["Anna", "Bruno", "Carla"], ["Bruno", "Carla", "Anna"],
		["Carla", "Anna", "Bruno"], ["Carla", "Bruno", "Anna"],
	]
	var verdetti := {}
	for o in ordini:
		var caro := AFF.il_piu_caro(righe, "Guardia", o, 3)
		verdetti[str(caro[0])] = true
	t.eq(verdetti.size(), 1,
			"IL VERDETTO NON DIPENDE DALL'ORDINE dell'array dei residenti")
	t.ok(verdetti.has(""),
			"…e a pari merito non elegge nessuno: la classifica invisibile"
			+ " non si scrive")

	# la valvola non è un tappo: una differenza VERA elegge ancora
	var con_un_gesto: Array = righe.duplicate(true)
	con_un_gesto.append({"a": "Guardia", "b": "Bruno", "t": "coraggio", "d": 3})
	for o2 in ordini:
		var caro2 := AFF.il_piu_caro(con_un_gesto, "Guardia", o2, 3)
		t.eq(str(caro2[0]), "Bruno",
				"un gesto vero in più elegge, in qualunque ordine stia l'array")

	# e un pareggio non forma nessuna coppia
	var pari: Array = []
	for g2 in 4:
		pari.append({"a": "Anna", "b": "Bruno", "t": "consolazione", "d": g2})
		pari.append({"a": "Bruno", "b": "Anna", "t": "consolazione", "d": g2})
		pari.append({"a": "Anna", "b": "Carla", "t": "consolazione", "d": g2})
		pari.append({"a": "Carla", "b": "Anna", "t": "consolazione", "d": g2})
	t.ok(not AFF.coppia(pari, "Anna", "Bruno", ["Anna", "Bruno", "Carla"], 4),
			"con due persone che contano UGUALE non nasce nessuna coppia")


## L'ISTERESI REGGE: il margine serve a ELEGGERE, non a restare insieme. Un
## terzo che pareggia non separa due che stanno insieme — se lo facesse, i
## gesti «a tutti» sarebbero diventati una macchina del divorzio.
func _test_il_pareggio_non_separa(t) -> void:
	var tutti := ["Anna", "Bruno", "Carla"]
	var righe: Array = []
	for i in AFF.GESTI_VERI_MIN:
		righe.append({"a": "Anna", "b": "Bruno", "t": "veglia", "d": 0})
		righe.append({"a": "Bruno", "b": "Anna", "t": "veglia", "d": 0})
	t.ok(AFF.coppia(righe, "Anna", "Bruno", ["Anna", "Bruno"], 0),
			"al giorno zero sono una coppia")
	# poi Carla arriva a contare per Anna esattamente quanto Bruno
	var pareggio: Array = righe.duplicate(true)
	for i2 in AFF.GESTI_VERI_MIN:
		pareggio.append({"a": "Anna", "b": "Carla", "t": "veglia", "d": 0})
		pareggio.append({"a": "Carla", "b": "Anna", "t": "veglia", "d": 0})
	t.ok(AFF.ancora_coppia(pareggio, "Anna", "Bruno", tutti, 0),
			"UN PAREGGIO NON SEPARA: per prendere il posto bisogna superare")
	# per separarli serve superarli davvero
	var supera: Array = pareggio.duplicate(true)
	for i3 in 3:
		supera.append({"a": "Carla", "b": "Anna", "t": "coraggio", "d": 0})
	t.ok(not AFF.ancora_coppia(supera, "Anna", "Bruno", tutti, 0),
			"…e con qualcuno che li supera davvero, sì")
