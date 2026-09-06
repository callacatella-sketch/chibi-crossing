extends RefCounted
## TRE MOTORI CHE GIRAVANO A VUOTO.
##
## Il difetto peggiore di un progetto grande non è il codice rotto: è il
## codice GIUSTO che non chiama nessuno. Passa i test, sembra vivo nel
## salvataggio, e non tocca il gioco di una virgola. Qui stanno le
## guardie dei tre che erano staccati:
##
##  1. `Animo.decide()` — la scelta pesata (softmax) con cui un vicino
##     decide da sé cosa fare. Zero chiamanti: i residenti senza
##     incarico non facevano niente di loro iniziativa.
##  2. `Limbico.visita_serena()` — la porta per guarire un trauma. Zero
##     chiamanti, e per costruzione irraggiungibile: chi evita un posto
##     non ci torna mai, quindi la paura non si spegneva più.
##  3. Le manopole della vignetta — quattro uniform che nessuno scriveva:
##     la carta restava congelata sui valori di fabbrica.
##
## E un QUARTO caso, che è il rovescio degli altri tre: un motore ACCESO di
## cui però nessuno sorvegliava il cavo — il marchio del luogo di lavoro
## (`_test_marchio_del_luogo`). Un cablaggio senza guardia non è più sicuro
## di un motore staccato: è solo più difficile accorgersi del giorno in cui
## si stacca.

const ANIMO := preload("res://scenes/npc/Animo.gd")
const CARTA := preload("res://scenes/world/Carta.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")
const LIMBICO := preload("res://scenes/npc/Limbico.gd")


func run(t) -> void:
	_test_decide_e_acceso(t)
	_test_guarigione_raggiungibile(t)
	_test_carta_respira(t)
	_test_marchio_del_luogo(t)


# ------------------------------------------------- 1. la scelta libera

func _test_decide_e_acceso(t) -> void:
	var lav := _sorgente("res://scenes/npc/Lavori.gd")
	t.ok(lav.contains("animo.decide("),
			"il registro fa DECIDERE chi non ha un incarico")
	var corpo := _corpo(lav, "_scelte_di_giornata")
	t.ok(corpo.contains("_incarichi.has(label)"),
			"decide solo chi è LIBERO: gli ordini del giocatore vincono")
	# ⚠️ **QUESTA GUARDIA MATCHAVA IL PROPRIO COMMENTO.** Cercava la stringa
	# `"se_stesso"` nel sorgente — e c'era, dentro `decide()` — mentre la riga
	# finiva poi in `Visitors.assegna_compito`, che la incideva contro il
	# GIOCATORE. MISURATO nel salvataggio vero: tutte e settantotto le righe
	# di compito intestate a lui, con il registro degli incarichi vuoto.
	# Adesso si guarda il RICORDO, non il sorgente.
	var chi = ANIMO.new()
	chi.setup(DNA.generate(4242))
	chi.esegue("taglia_legna", "se_stesso")
	t.eq(chi.quante_volte("taglia_legna", "se_stesso"), 1,
			"una giornata scelta da se' resta scritta come SUA")
	t.eq(chi.quante_volte("taglia_legna", "giocatore"), 0,
			"…e non come una richiesta di chi comanda il villaggio")

	# ⚠️ **E IL CABLAGGIO VA ATTRAVERSATO, o si prova solo l'API.** La prima
	# stesura di questa guardia chiamava `Animo.esegue` diretto: le due
	# mutazioni che rimettono il difetto — l'ordinante cablato dentro
	# `assegna_compito`, e `Lavori` che smette di passarlo — la lasciavano
	# **verde tutte e due**. Qui si passa dalle funzioni vere.
	var vis = RegistroCompiti.new()
	t.stage(vis)
	var libero = ANIMO.new()
	libero.setup(DNA.generate(77))
	(vis.get("_animi") as Dictionary)["L"] = libero
	vis.assegna_compito("L", "taglia_legna", "se_stesso")
	t.eq(libero.quante_volte("taglia_legna", "se_stesso"), 1,
			"`assegna_compito` incide l'ordinante che gli si passa")
	vis.assegna_compito("L", "taglia_legna")
	t.eq(libero.quante_volte("taglia_legna", "giocatore"), 1,
			"…e di serie resta il giocatore, come una richiesta vera")

	# …e il registro dei lavori lo passa DAVVERO, per chi non ha un incarico
	var reg_lav = RegistroLavori.new()
	t.stage(reg_lav)
	reg_lav.set("_visitors", vis)
	(vis.get("_residents") as Array).append({"label": "L"})
	vis.ordinanti.clear()
	reg_lav._scelte_di_giornata()
	t.ok(vis.ordinanti.has("se_stesso"),
			"e chi non ha un incarico si sceglie la giornata da se': "
			+ "nel suo ricordo resta cosi' (%s)" % str(vis.ordinanti))
	t.ok(not vis.ordinanti.has("giocatore"),
			"…e non come una richiesta che nessuno gli ha fatto")


	t.ok(_corpo(lav, "_on_nuovo_giorno").contains("_scelte_di_giornata"),
			"e succede ogni mattina")
	t.ok(_sorgente("res://scenes/npc/Visitors.gd").contains("func animo_oggetto_di"),
			"Visitors passa l'animo vivo a chi lo deve far decidere")

	# il motore in sé: la scelta è pesata, non un sorteggio, e resta
	# dentro il vocabolario dei compiti
	var a = ANIMO.new()
	a.setup({"name": "Prova", "seed": 7,
			"sogno": "boscaiolo", "tratti": {}, "weights": {}})
	var azioni: Array = ANIMO.COMPITI.keys()
	var conteggio := {}
	for i in 200:
		var s := str(a.decide(azioni, "se_stesso"))
		t.ok(s in azioni, "decide() resta nel vocabolario dei compiti")
		conteggio[s] = int(conteggio.get(s, 0)) + 1
	t.ok(conteggio.size() >= 2,
			"la scelta è PESATA, non fissa: %d compiti diversi su 200 giri"
			% conteggio.size())
	t.ok(conteggio.size() <= azioni.size(),
			"…e nemmeno un sorteggio piatto su tutto")
	t.eq(str(a.decide([], "se_stesso")), "",
			"senza azioni non inventa nulla")


# --------------------------------------------- 2. la porta della cura

func _test_guarigione_raggiungibile(t) -> void:
	var vis := _sorgente("res://scenes/npc/Visitors.gd")
	t.ok(vis.contains("visita_serena"),
			"la porta per guarire un trauma ha finalmente un chiamante")
	var filtro := _corpo(vis, "_filtra_luogo")
	t.ok(filtro.contains("_player") and filtro.contains("distance_to"),
			"si apre quando il giocatore è ACCANTO: è lui la cura")
	var i_guardia := filtro.find("distance_to")
	var i_ripiego := filtro.find("return RIPIEGO")
	t.ok(i_guardia >= 0 and i_ripiego > i_guardia,
			"…e la cura viene PRIMA del ripiego, o non si raggiungerebbe mai")

	# il motore: una visita serena dimezza la carica, e bastano poche
	# volte perché il posto torni un posto qualunque
	var LIMB := load("res://scenes/npc/Limbico.gd")
	var l = LIMB.new()
	for i in 6:
		# `senti()` NON ESISTE in Limbico: il metodo vero è `rivaluta`. La
		# chiamata sbagliata sollevava un errore che INTERROMPEVA il resto
		# di questa funzione — cioè proprio la prova che la guarigione di un
		# trauma è raggiungibile — e la suite restava verde, perché un
		# errore a runtime non fa fallire niente.
		l.rivaluta("morso", "", -0.9, "orto")
	var evitava: bool = l.evita("orto")
	t.ok(evitava, "sei brutte esperienze e il posto diventa insopportabile")
	var giri := 0
	while l.evita("orto") and giri < 30:
		l.visita_serena("orto")
		giri += 1
	t.ok(not l.evita("orto"),
			"tornarci in compagnia lo guarisce (in %d visite)" % giri)
	t.ok(giri <= 8, "e non serve una vita: %d visite" % giri)
	# su un posto mai marchiato non fa nulla e non esplode
	l.visita_serena("posto_mai_visto")
	t.ok(true, "una visita a un posto senza marchio non rompe niente")


# ------------------------------------------------- 3. la carta viva

func _test_carta_respira(t) -> void:
	# il cablaggio: prima le manopole non le scriveva NESSUNO
	t.ok(_sorgente("res://scenes/levels/MainLevel.gd").contains("Carta.gd"),
			"il regista della carta vive nella scena principale")
	var c := _sorgente("res://scenes/world/Carta.gd")
	for manopola in ["strength", "calore", "grana", "tint"]:
		t.ok(c.contains("set_shader_parameter(\"%s\"" % manopola),
				"la manopola '%s' viene scritta davvero" % manopola)

	# i default dichiarati qui devono COMBACIARE con quelli dello shader,
	# o alla prima scrittura l'immagine salterebbe
	var sh := _sorgente("res://shaders/vignette.gdshader")
	t.ok(sh.contains("strength : hint_range(0.0, 1.0) = 0.24"),
			"strength: stesso valore di fabbrica di qua e di là")
	t.ok(sh.contains("grana : hint_range(0.0, 0.2) = 0.045"),
			"grana: idem")
	t.ok(sh.contains("calore : hint_range(0.0, 1.0) = 0.5"),
			"calore: idem")

	# LA MATEMATICA, pura: si prova a ogni ora e in ogni stato
	var sereno := {"ora": 0.5, "notte": false, "pioggia": false,
			"nebbia": false, "lutto": false, "festa": false}
	var m: Dictionary = CARTA.manopole(sereno)
	t.almost(float(m["strength"]), 0.24, "mezzogiorno sereno: la carta di sempre", 0.02)

	# l'oro delle sei: al tramonto si scalda e chiude un filo
	var tramonto := sereno.duplicate()
	tramonto["ora"] = 0.75
	var mt: Dictionary = CARTA.manopole(tramonto)
	t.ok(float(mt["calore"]) > float(m["calore"]) + 0.2,
			"al tramonto la carta si SCALDA (%.2f contro %.2f)"
			% [mt["calore"], m["calore"]])
	t.ok(float(mt["strength"]) > float(m["strength"]),
			"…e chiude un filo di più, come un'illustrazione")
	# e all'alba lo stesso: sono due campane, non una
	var alba := sereno.duplicate()
	alba["ora"] = 0.26
	t.ok(float((CARTA.manopole(alba) as Dictionary)["calore"])
			> float(m["calore"]) + 0.2, "e all'alba pure")

	# la notte stringe e raffredda
	var notte := sereno.duplicate()
	notte["ora"] = 0.95
	var mn: Dictionary = CARTA.manopole(notte)
	t.ok(float(mn["strength"]) > float(m["strength"]),
			"di notte il buio stringe l'inquadratura")
	t.ok(float(mn["calore"]) < float(m["calore"]),
			"…e il bruno si raffredda")

	# IL LUTTO: il gradino che conta. Si sente, non si annuncia.
	var lutto := sereno.duplicate()
	lutto["lutto"] = true
	var ml: Dictionary = CARTA.manopole(lutto)
	t.ok(float(ml["strength"]) > float(m["strength"]) + 0.1,
			"nel lutto l'inquadratura si CHIUDE (%.2f contro %.2f)"
			% [ml["strength"], m["strength"]])
	t.ok(float(ml["calore"]) < float(m["calore"]) - 0.2,
			"…e si spegne il calore")
	t.ok(float(ml["grana"]) > float(m["grana"]),
			"…e la grana della carta affiora")

	# LA FESTA fa l'opposto esatto: la carta si apre
	var festa := sereno.duplicate()
	festa["festa"] = true
	var mf: Dictionary = CARTA.manopole(festa)
	t.ok(float(mf["strength"]) < float(m["strength"]),
			"a festa la carta si APRE")
	t.ok(float(mf["calore"]) > float(m["calore"]), "…e si scalda")

	# la pioggia inumidisce
	var pioggia := sereno.duplicate()
	pioggia["pioggia"] = true
	var mp: Dictionary = CARTA.manopole(pioggia)
	t.ok(float(mp["grana"]) > float(m["grana"]) and float(mp["calore"]) < float(m["calore"]),
			"sotto la pioggia la carta si inumidisce")

	# NIENTE ESCE DAI BINARI, in nessuna combinazione: fuori dagli
	# hint_range Godot taglierebbe in silenzio e la manopola mentirebbe
	var fuori := 0
	for i in 25:
		for lu in [false, true]:
			for fe in [false, true]:
				for pi in [false, true]:
					var ctx := {"ora": float(i) / 24.0, "notte": i > 18,
							"pioggia": pi, "nebbia": false, "lutto": lu, "festa": fe}
					var v: Dictionary = CARTA.manopole(ctx)
					if float(v["strength"]) < 0.0 or float(v["strength"]) > 1.0 \
							or float(v["calore"]) < 0.0 or float(v["calore"]) > 1.0 \
							or float(v["grana"]) < 0.0 or float(v["grana"]) > 0.2:
						fuori += 1
	t.eq(fuori, 0, "in 200 combinazioni nessuna manopola esce dal suo hint_range")


# -------------------------------- 4. il marchio del luogo di lavoro

## ⚠️ **IL CAVO CHE NESSUNO SORVEGLIAVA.**
##
## `Visitors.assegna_compito` prende il `sentito` che `Animo.esegue` gli
## TORNA e, se quel lavoro ha lasciato il segno (`absf(sentito) > 0.25`),
## carica il LUOGO di quel compito
## (`Limbico._marchia("luogo|" + LUOGO_DEL_LAVORO[compito], sentito)`):
## dopo abbastanza volte quel posto diventa qualcosa da evitare, e da lì
## nasce l'occasione `quel_posto_no` del vocabolario del corpo — l'unica
## delle sette che parla di un POSTO invece che di una persona.
##
## Il cablaggio c'era; la guardia no. E due mutazioni plausibili restavano
## **verdi tutte e due**. MISURATE una per una, rifacendo il corpo di
## `assegna_compito` con la riga guasta sopra lo stesso banco:
##
## | | sentito · carica dopo due giornate | rosse |
## |---|---|---|
## | sana | −0.798 → −0.4389, poi −0.899 → **−0.8015** | — |
## | (a) `Animo.ricorda()` torna `0.0` invece del sentito | 0.0000 → **nessun marchio** | **7** |
## | (b) si rilegge `animo.ricordi[size - 1]` | +0.800 → **+0.4400**, poi +0.7480 | **3** |
##
##  (a) la firma resta `-> float`, quindi non se ne accorge nemmeno il
##      parser: nessun luogo riceve più un marchio, `Limbico.evita()` non
##      si accende mai, e `quel_posto_no` è irraggiungibile in partita;
##  (b) è il difetto che la cura ha chiuso, rimesso identico. La chiude la
##      CONTROPROVA in fondo a questa funzione, perché nel caso comune
##      `ricordi.back()` **è** la riga appena incisa e la mutazione dà lo
##      stesso identico numero — verde su tutta la linea. Con la memoria
##      piena, invece, la catasta si carica **+0.44**: il posto diventa un
##      bel posto perché il giocatore gli aveva fatto un regalo.
func _test_marchio_del_luogo(t) -> void:
	var vis = RegistroCompiti.new()
	t.stage(vis)
	# il posto lo dice la tabella di `Visitors`, non una stringa ricopiata
	# qui: se un domani la catasta cambia nome, questo caso deve seguirla
	var luogo := str(VISITORS.LUOGO_DEL_LAVORO["taglia_legna"])
	var altrove := str(VISITORS.LUOGO_DEL_LAVORO["coltiva"])

	# ── il cablaggio nudo ────────────────────────────────────────────────
	# spaccare legna a chi sognava di combattere: `COMPITI` dice che
	# `taglia_legna` TRADISCE il sogno «guerriero», ed è il moltiplicatore
	# `CONTRO_SOGNO` a portare il sentito ben oltre la soglia dei 0.25.
	var g = _guerriero("G")
	(vis.get("_animi") as Dictionary)["G"] = g
	vis.assegna_compito("G", "taglia_legna")
	var c1: float = g.limbico.carica_di(luogo)
	t.ok(c1 < 0.0, ("il posto del lavoro si CARICA di com'è andata (%.3f): "
			+ "il marchio non lo scrive nessuno, lo lascia il lavoro") % c1)
	t.ok(not g.limbico.evita(altrove),
			"…e si carica solo QUEL posto: l'orto non c'entra niente")

	vis.assegna_compito("G", "taglia_legna")
	var c2: float = g.limbico.carica_di(luogo)
	t.ok(c2 < c1, ("…e la seconda volta pesa di più (%.3f contro %.3f)"
			% [c2, c1]))
	# l'aritmetica di `_marchia` (0.7 · quel che c'era + 0.55 · sentito)
	# porta un tradimento del sogno oltre la soglia alla SECONDA volta:
	# «bastano due spaventi nello stesso posto per non volerci più andare».
	# MISURATO con questo carattere: −0.4389 la prima, −0.8015 la seconda,
	# contro una soglia di 0.45 — e il margine non è tarato qui, viene da
	# `CONTRO_SOGNO` che è già tarato altrove.
	t.ok(c2 <= -LIMBICO.SOGLIA_EVITAMENTO,
			("due giornate così e la carica supera la soglia "
			+ "dell'evitamento (%.3f contro %.3f)")
			% [c2, -LIMBICO.SOGLIA_EVITAMENTO])
	t.ok(g.limbico.evita(luogo),
			"e il posto diventa da evitare: è di qui che nasce «quel_posto_no»")

	# ── e una giornata QUALUNQUE non marchia niente ──────────────────────
	# `esplora` ha un luogo (il bosco) ma non tradisce nessun sogno: il
	# sentito resta sotto 0.25 e il posto non si carica. Senza questa
	# guardia il cancello `absf(sentito) > 0.25` potrebbe sparire, e allora
	# ogni mestiere di ogni giornata marchierebbe il suo posto — cioè un
	# villaggio in cui alla fine non si può più andare da nessuna parte.
	var chi_esplora = _guerriero("E")
	(vis.get("_animi") as Dictionary)["E"] = chi_esplora
	vis.assegna_compito("E", "esplora")
	t.ok(not (chi_esplora.limbico.marchi as Dictionary).has(
					"luogo|" + str(VISITORS.LUOGO_DEL_LAVORO["esplora"])),
			"una giornata che non toglie niente a nessuno non marchia il bosco")

	# ── LA CONTROPROVA: la riga appena incisa può NON essere l'ultima ────
	# ⚠️ Nel caso comune `ricordi.back()` è proprio la riga appena scritta,
	# quindi la mutazione (b) darebbe lo stesso numero e questa funzione
	# resterebbe verde: un test che sceglie l'unico caso in cui il codice
	# sbagliato è giusto non è un test, è un ritratto.
	#
	# Qui la memoria è PIENA di righe dello stesso tipo e dello stesso
	# giorno, e allora la potatura per schema del sé sacrifica proprio la
	# riga nuova: `recente` vale 1.0 per tutte e la congruenza divisa per
	# `quanti` è identica, quindi a decidere resta `PESO_FORZA * forza` —
	# e la forza della riga appena incisa (|sentito| × 0.975, che è
	# l'intensità con cui `esegue` incide un tradimento del sogno) sta per
	# COSTRUZIONE sotto quella dei riempitivi, che vale 1.0 tondo. In coda ai ricordi vivi resta allora
	# un REGALO del giocatore, cioè una valenza dell'ALTRO SEGNO: con la
	# mutazione la catasta diventerebbe un bel posto perché gli hai fatto
	# un regalo (misurato: +0.4400 invece di −0.4389).
	#
	# ⚠️ E il margine è una garanzia, non una taratura: il sentito è
	# clampato a 1 e l'intensità sta sotto, quindi la forza della riga
	# nuova non può arrivare a 1.0 nemmeno al limite. Se
	# un domani la potatura cambiasse idea, a dirlo è l'asserzione sulla
	# CODA qui sotto — che è il pezzo del banco che sorveglia il banco.
	var p = _guerriero("P")
	(vis.get("_animi") as Dictionary)["P"] = p
	for i in ANIMO.RICORDI_VIVI - 1:
		(p.ricordi as Array).append({"tipo": "taglia_legna",
				"attore": "giocatore", "quando": p.oggi,
				"valenza": -1.0, "intensita": 1.0, "come": ""})
	(p.ricordi as Array).append({"tipo": "regalo", "attore": "giocatore",
			"quando": p.oggi, "valenza": 0.8, "intensita": 0.9, "come": ""})

	vis.assegna_compito("P", "taglia_legna")
	t.eq((p.ricordi as Array).size(), ANIMO.RICORDI_VIVI,
			"la memoria era piena: la potatura ha girato per davvero")
	var coda: Dictionary = (p.ricordi as Array)[ANIMO.RICORDI_VIVI - 1]
	t.eq(str(coda.get("tipo", "")), "regalo",
			"IL BANCO È AFFILATO: la riga del lavoro è stata potata, e in "
			+ "coda ai ricordi vivi ne resta un'ALTRA")
	t.ok(float(coda.get("valenza", 0.0)) > 0.0,
			"…e di segno opposto, o la mutazione passerebbe lo stesso")
	var d1: float = p.limbico.carica_di(luogo)
	t.ok(d1 < 0.0, ("il marchio porta il sentito che `esegue` ha TORNATO "
			+ "(%.3f), non la valenza dell'ultima riga rimasta nell'array")
			% d1)

	vis.assegna_compito("P", "taglia_legna")
	var d2: float = p.limbico.carica_di(luogo)
	t.ok(d2 <= -LIMBICO.SOGLIA_EVITAMENTO,
			("…e due volte bastano anche con la memoria piena (%.3f)") % d2)
	t.ok(p.limbico.evita(luogo),
			"il posto è da evitare, e per il lavoro: non per un regalo")


## Un animo DETERMINISTICO che sognava di combattere: tratti tutti scritti
## (niente dado), sogno esplicito. È il caso del brief — «mi hai mandato a
## spaccare legna e io volevo fare il guerriero».
func _guerriero(nome: String):
	var a = ANIMO.new()
	a.setup({"name": nome, "seed": 4242, "sogno": "guerriero",
			"tratti": {"orgoglio": 0.5, "lealta": 0.5, "grinta": 0.5,
					"codardia": 0.5, "ambizione": 0.4}})
	return a


func _corpo(src: String, nome: String) -> String:
	var da := src.find("func " + nome)
	if da < 0:
		return ""
	var fine := src.find("\nfunc ", da + 1)
	return src.substr(da, (fine - da) if fine > da else -1)


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""


## Un registro che REGISTRA. `assegna_compito` resta quella del gioco.
class RegistroCompiti extends "res://scenes/npc/Visitors.gd":
	var ordinanti: Array = []

	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

	func _process(_d: float) -> void:
		pass

	func assegna_compito(label: String, compito: String, ordinante := "giocatore") -> void:
		ordinanti.append(ordinante)
		super(label, compito, ordinante)

	func e_cucciolo(_l: String) -> bool:
		return false

	func animo_oggetto_di(label: String):
		return (get("_animi") as Dictionary).get(label)




## Il registro dei lavori VERO, col solo `_ready` scavalcato.
class RegistroLavori extends "res://scenes/npc/Lavori.gd":
	func _ready() -> void:
		set_process(false)
