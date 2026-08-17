extends RefCounted
## IL CICLO DEL SONNO, DA CAPO A FONDO: la prima decisione del villaggio
## che vive in C++, e il corpo che la esegue.
##
## `test_ecs_mondo.gd` prova il REGISTRO (la regola pura); qui si prova il
## CABLAGGIO, che è la parte che può rompere il gioco: `Visitors._ciclo_sonno`
## raccoglie i fatti da Visitor VERI, fa avanzare il registro, e poi muove
## i corpi. E si guarda IL CORPO — `is_hidden()`, `_state`, il meta della
## postura — non il componente: se guardassimo il componente proveremmo che
## il C++ è d'accordo con se stesso.
##
## COSA QUESTO FILE NON COPRE, detto qui e non nascosto: il ramo della
## PORTA CHIUSA end-to-end. `Visitors._puo_entrare` interroga il gruppo
## «affetti» dell'albero, e `Visitors` non si può mettere in scena (il suo
## `_ready` vuole il villaggio intero). Quel ramo resta coperto da due
## parti: la decisione in `test_ecs_mondo._porta_chiusa`, e il gesto in
## `test_postura_ritorno` (che chiama `_aggiorna_posa_fuori` vero).

const VISITOR := "res://scenes/npc/Visitor.gd"
const VISITORS := "res://scenes/npc/Visitors.gd"
const DNA := preload("res://scenes/npc/ChibiDNA.gd")

const DT := 1.0 / 60.0


## UN VILLAGGIO IN CUI LA PORTA NON SI APRE. `_puo_entrare` interroga il
## gruppo «affetti» dell'albero, e `Visitors` non si può mettere in scena
## (il suo `_ready` vuole il villaggio intero): l'unico modo onesto di
## esercitare il ramo «resta fuori» del cablaggio VERO è sostituire quella
## sola risposta e lasciare tutto il resto — fatti, passo, gesti — identico.
class VisitorsPortaChiusa extends "res://scenes/npc/Visitors.gd":
	func _puo_entrare(_r: Dictionary) -> bool:
		return false


func run(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	var vs: GDScript = load(VISITOR)
	if vs == null or not vs.can_instantiate():
		t.ok(false, "Visitor.gd non compila")
		return
	_dorme_e_si_sveglia(t, vs)
	_la_promessa_vince(t, vs)
	_il_dna_non_porta_geni_mutabili(t, vs)
	_il_salvataggio_non_si_muove(t, vs)
	_anagrafe_allineata(t, vs)
	_chi_resta_fuori(t, vs)


## Un residente vero, senza quirk (così `_quirk_tick` non cerca funghi in un
## villaggio che qui non esiste) e senza indole (finestra 0.80 → 0.295).
func _residente(t, vs: GDScript, seme: int, etichetta: String) -> Dictionary:
	var v = vs.new()
	v.dna = DNA.generate(seme)
	v.mode = "resident"
	t.stage(v)
	# `species` serve a save_extra: una riga di residente vera ce l'ha
	var r := {"node": v, "label": etichetta, "dna": v.dna,
			"cell": Vector2i(seme % 40, 0), "species": "chibi"}
	# e il CORPO va messo in un mestiere da RESIDENTE fermo. Appena nato è
	# in «idle» (da visitatore), e `do_routine("wander")` lo fa partire a
	# camminare: né l'uno né l'altro sono stati interrompibili, e infatti il
	# registro si rifiuta di mandarlo a letto — comportamento giusto, e la
	# prima volta l'ho scoperto qui. Si apparecchia la scena, non si aggira
	# la regola: lo si mette in «r_idle» dalla porta ufficiale degli stati.
	v._enter_state("r_idle")
	return r


func _villaggio(t, vs: GDScript, quanti: int) -> Array:
	var vis = load(VISITORS).new()   # non in scena: `_ready` vuole il villaggio
	var righe: Array = []
	for i in quanti:
		var r := _residente(t, vs, 3000 + i * 17, "Prova%d" % i)
		righe.append(r)
		vis._residents.append(r)
	# Niente quirk (qui non c'è un mondo in cui andarli a fare) e NESSUNA
	# INDOLE, così la finestra è quella base 0.80 → 0.295. Non è pigrizia:
	# il seme 3000 dà un «sognatore», che è NOTTAMBULO e va a letto alle
	# 0.92 — il test falliva e aveva ragione il codice. La finestra per
	# indole è provata a parte, su tutte le mille ore della giornata
	# (test_ecs_mondo._equivalenza); qui si prova il cablaggio.
	for r in righe:
		var b: RefCounted = vis._ensure_brain(r)
		b.quirk = ""
		b.indole = []
	return [vis, righe]


func _gira(vis, ore: float, quanti: int) -> void:
	for _i in quanti:
		vis._ciclo_sonno(DT, ore)


## LA MARIONETTA MUOVE IL CORPO. È la tesi della fase: la decisione sta in
## C++, il gesto in GDScript, e il risultato si vede addosso al vicino.
func _dorme_e_si_sveglia(t, vs: GDScript) -> void:
	var mondo := _villaggio(t, vs, 2)
	var vis = mondo[0]
	var righe: Array = mondo[1]
	var v = righe[0]["node"]

	t.ok(not v.is_hidden(), "di pomeriggio è fuori")
	_gira(vis, 0.85, 30)
	t.ok(v.is_hidden(), "alla sera RIENTRA: il corpo obbedisce alla decisione C++")
	t.eq(str(v.get("_state")), "hidden", "ed è davvero nello stato del sonno")
	# TUTTI i corpi, non solo il primo: l'asserzione di prima guardava il
	# vicino da SVEGLIO, ed è passata anche mettendo un `break` in fondo al
	# ciclo dei gesti. Si guarda mentre DEVONO dormire.
	t.ok(righe[1]["node"].is_hidden(),
			"e il vicino di casa pure: il ciclo li muove TUTTI, non solo il primo")
	# e ci resta: nessun lampeggio dentro/fuori
	_gira(vis, 0.85, 60)
	t.ok(v.is_hidden(), "e ci resta, senza lampeggiare")

	_gira(vis, 0.50, 30)
	t.ok(not v.is_hidden(), "a giorno fatto SI SVEGLIA")
	t.ok(str(v.get("_state")) != "hidden", "e il corpo è tornato in circolazione")

	vis.free()


## IL CASO DELLE PROMESSE, che è la prova della tesi al contrario.
## Undici sistemi del villaggio muovono i corpi a evento. Se l'autorità C++
## li calpestasse, un vicino che ha promesso di trovarsi al pontile a
## mezzanotte verrebbe rispedito a letto un frame dopo — e nessuno vedrebbe
## un errore. Il registro deve ACCETTARE il corpo, non combatterlo.
func _la_promessa_vince(t, vs: GDScript) -> void:
	var mondo := _villaggio(t, vs, 1)
	var vis = mondo[0]
	var r: Dictionary = mondo[1][0]
	var v = r["node"]

	_gira(vis, 0.85, 30)
	t.ok(v.is_hidden(), "dorme")

	# esattamente quel che fa Promesse.gd quando l'appuntamento è vicino
	v.resident_wake()
	v.do_routine("attesa", Vector3(2, 0, 2))
	_gira(vis, 0.85, 10)
	t.ok(not v.is_hidden(),
			"la promessa VINCE: il registro accetta chi è stato svegliato")
	t.ok(str(v.get("_state")) != "hidden",
			"e non lo rimette a dormire alle spalle di chi l'ha svegliato")
	vis.free()


## IL DnaComponent PORTA SOLO GENI IMMUTABILI. Il salone di bellezza
## riscrive i geni estetici DENTRO il Dictionary del DNA, che è lo stesso
## oggetto della riga del salvataggio: una copia C++ di un gene estetico
## diventerebbe stale al primo cambio di look, con la suite verde.
func _il_dna_non_porta_geni_mutabili(t, vs: GDScript) -> void:
	var mondo := _villaggio(t, vs, 1)
	var vis = mondo[0]
	var r: Dictionary = mondo[1][0]
	# LA FIXTURE AZZERA indole e quirk (serve alle altre prove: tiene la
	# finestra base). Qui li rimettiamo VERI, e PRIMA della registrazione:
	# con zero e nessun quirk la proiezione varrebbe `indole=0, quirk=-1`
	# prima E dopo il salone, e le due asserzioni sotto confronterebbero 0
	# con 0 — verdi anche se `registra` buttasse via i suoi argomenti.
	# È esattamente il difetto che questa funzione doveva impedire, e ce
	# l'aveva dentro: l'ha trovato una revisione avversariale.
	var b: RefCounted = vis._ensure_brain(r)
	b.indole = ["sognatore", "goloso"]
	b.quirk = "canta_alla_luna"
	_gira(vis, 0.50, 1)
	var id: int = int(r["ecs"])
	var prima: Dictionary = vis._ecs.debug_entita(id)
	t.eq(int(prima["indole"]),
			vis._ecs.maschera_indole(PackedStringArray(["sognatore", "goloso"])),
			"la proiezione porta DAVVERO l'indole del cervello, non zero")
	t.eq(int(prima["quirk"]), vis._ecs.indice_quirk("canta_alla_luna"),
			"e DAVVERO la stravaganza, non -1")

	# il salone passa e cambia TUTTI i geni che può cambiare
	for gene in DNA.ESTETICI:
		if r["dna"].has(gene) and typeof(r["dna"][gene]) == TYPE_FLOAT:
			r["dna"][gene] = float(r["dna"][gene]) * 0.5 + 0.11
	_gira(vis, 0.50, 5)
	var dopo: Dictionary = vis._ecs.debug_entita(id)
	t.eq(int(dopo["indole"]), int(prima["indole"]),
			"cambiato il look, l'indole nel registro non si muove")
	t.eq(int(dopo["quirk"]), int(prima["quirk"]),
			"e nemmeno il quirk")

	# E SE IL QUIRK CAMBIA DAVVERO? `Visitors.debug_quirk` lo scrive su un
	# cervello vivo (è così che DebugHarness fabbrica un nottambulo): la
	# proiezione deve SEGUIRLO, se no uno che è appena diventato nottambulo
	# va a letto alle 0.80 come gli altri.
	b.quirk = "ballerino"
	_gira(vis, 0.50, 2)
	t.eq(int(vis._ecs.debug_entita(id)["quirk"]), vis._ecs.indice_quirk("ballerino"),
			"cambiato il quirk sul cervello, il registro si aggiorna")
	b.indole = ["mattiniero"]
	_gira(vis, 0.50, 2)
	t.eq(int(vis._ecs.debug_entita(id)["indole"]),
			vis._ecs.maschera_indole(PackedStringArray(["mattiniero"])),
			"e lo stesso per l'indole")

	# e la regola che lo tiene onesto in futuro
	t.ok(not "indole" in DNA.ESTETICI,
			"«indole» non è un gene estetico: il registro può tenerne una copia")
	t.ok(not "quirk" in DNA.ESTETICI,
			"«quirk» nemmeno")
	vis.free()


## LO STATO ECS È VOLATILE. Nessuna chiave nuova su disco, nessuna
## migrazione, nessun salvataggio da riparare: è la garanzia che questa
## fase non poteva rompere una partita in corso.
func _il_salvataggio_non_si_muove(t, vs: GDScript) -> void:
	var mondo := _villaggio(t, vs, 1)
	var vis = mondo[0]
	var r: Dictionary = mondo[1][0]
	_gira(vis, 0.85, 5)
	t.ok(r.has("ecs"), "l'handle esiste, in RAM, dentro la riga del residente")

	var extra = vis.save_extra()
	t.ok(not extra.has("ecs"), "ma NON è una chiave di radice del salvataggio")
	var righe: Array = extra.get("residents", [])
	t.ok(righe.size() >= 1, "il salvataggio ha la sua riga")
	if righe.size() >= 1:
		t.ok(not (righe[0] as Dictionary).has("ecs"),
				"e la riga del residente non porta l'handle su disco")
	vis.free()


## DOVE MUORE IL CERVELLO, MUORE L'ENTITÀ. Senza, un'entità decide per un
## vicino che non c'è più — e oggi non si vedrebbe, ma alla Fase 2 sì.
func _anagrafe_allineata(t, vs: GDScript) -> void:
	var mondo := _villaggio(t, vs, 3)
	var vis = mondo[0]
	var righe: Array = mondo[1]
	_gira(vis, 0.85, 3)
	t.eq(vis._ecs.quanti(), vis._brains.size(),
			"un'entità per cervello, dopo il primo giro")

	# se ne va uno: la riga sparisce, e l'entità con lei
	var via: Dictionary = righe[1]
	vis._dimentica_ecs(via)
	vis._brains.erase(str(via["label"]))
	vis._residents.erase(via)
	t.eq(vis._ecs.quanti(), vis._brains.size(),
			"e dopo una partenza restano allineati")
	t.ok(not via.has("ecs"), "chi è partito non si porta dietro l'handle")

	# e il debug_reset azzera tutto
	vis._residents.clear()
	vis._brains.clear()
	vis._ecs.dimentica_tutti()
	t.eq(vis._ecs.quanti(), 0, "azzerato il villaggio, il registro è vuoto")
	vis.free()


## IL RAMO «FUORI» DEL CABLAGGIO. Nessuna asserzione lo raggiungeva: si
## poteva scrivere `st == _ST_DORME` al posto di `st == _ST_FUORI` e la
## suite restava verde, mentre in partita ogni vicino usciva di casa curvo
## la mattina dopo — il telegrafo più silenzioso del gioco, rotto.
##
## `_puo_entrare` non è pilotabile senza mezzo villaggio (interroga il gruppo
## «affetti» dell'albero), quindi si prende il ramo dall'altro capo: si porta
## l'entità a FUORI parlando al registro, e si guarda che il GESTO arrivi
## addosso al corpo.
func _chi_resta_fuori(t, vs: GDScript) -> void:
	var vis = VisitorsPortaChiusa.new()
	var r := _residente(t, vs, 4242, "Fuori")
	vis._residents.append(r)
	var b: RefCounted = vis._ensure_brain(r)
	b.indole = []
	b.quirk = ""
	var v = r["node"]

	# sera: la porta non si apre. Passa tutto dal ciclo VERO.
	for _i in 30:
		vis._ciclo_sonno(DT, 0.85)
	t.ok(not v.is_hidden(), "chi resta fuori NON sparisce dentro")
	t.eq(str(v.get_meta("postura", "")), "spalle_basse",
			"e lo dice col CORPO: spalle basse, senza un toast a spiegarlo")

	# la notte passa: la posa se ne va — nessuno resta curvo per sempre
	for _i in 30:
		vis._ciclo_sonno(DT, 0.50)
	t.ok(not v.has_meta("postura"),
			"passata la notte la posa se ne va, e la posa era NOSTRA")
	t.ok(not v.is_hidden(), "e di giorno resta fuori, sveglio")
	vis.free()
