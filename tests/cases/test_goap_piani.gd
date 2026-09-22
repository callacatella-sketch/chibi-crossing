extends RefCounted

const PIANI := preload("res://scenes/npc/Piani.gd")
## IL PIANIFICATORE (GOAP): dall'obiettivo alla catena di gesti.
##
## La Fase 2 dice cosa un vicino VUOLE; qui si prova COME ci arriva — e
## soprattutto che, quando il mondo cambia, la risposta cambia con lui.
##
## LA SCENA CHE QUESTO FILE DIFENDE: un vicino affamato va al cespuglio;
## il giocatore chiude l'ultimo pannello di staccionata; il cespuglio è
## ancora lì (F_CIBO acceso) ma non ci si arriva più (F_CIBO_RAGG spento);
## e il piano che ne nasce non è «arrenditi», è «vai alla Lavagna e chiedi
## da mangiare a Mochi». Se questo file diventa verde per caso, quella
## scena non succede più e nessuno se ne accorge: per questo ogni catena è
## verificata passo per passo, coi nomi.

const OPS := ["vai_al_cibo", "sgranocchia", "vai_all_aiuola", "annaffia",
		"vai_alla_seduta", "siedi", "pisolino", "vai_al_bello", "incantati",
		"vai_alla_lavagna", "chiedi_cibo", "chiedi_cura"]

# cinque luoghi: cibo, aiuola, seduta, bello, lavagna
var VICINI := PackedFloat64Array([2.0, 2.0, 2.0, 2.0, 2.0])


func run(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	var m = ClassDB.instantiate("EcsMondo")
	_api(t, m)
	_tabelle(t, m)
	_la_catena_semplice(t, m)
	_il_recinto(t, m)
	_niente_strada(t, m)
	_gia_fatto(t, m)
	_preferisce_la_panchina(t, m)
	_il_piu_economico(t, m)
	_deterministico(t, m)
	_mai_un_piano_a_meta(t, m)
	_il_budget_misura_il_CORPO(t, m)
	_un_solo_operatore_scatta_senza_luogo(t, m)
	m.free()


func _api(t, m) -> void:
	for n in ["pianifica", "indice_operatore", "maschera_obiettivo",
			"debug_piano", "debug_operatore", "debug_tara_piani"]:
		t.ok(m.has_method(n), "EcsMondo espone «%s» nel binario" % n)


func _nomi(m, passi) -> Array:
	var out: Array = []
	for p in passi:
		out.append(OPS[int(p)] if int(p) >= 0 and int(p) < OPS.size() else "?")
	return out


## Le due tabelle (nomi ↔ indici) legate come tutte le altre del progetto.
func _tabelle(t, m) -> void:
	for i in OPS.size():
		t.eq(m.indice_operatore(OPS[i]), i,
				"«%s» è l'operatore numero %d anche in C++" % [OPS[i], i])
	t.eq(m.indice_operatore("operatore_inventato"), -1, "un operatore ignoto vale -1")
	for n in ["provvedi_pancino", "provvedi_cura", "provvedi_energia",
			"provvedi_meraviglia"]:
		t.ok(m.maschera_obiettivo(n) != 0, "l'obiettivo «%s» ha la sua maschera" % n)
	t.eq(m.maschera_obiettivo("provvedi_niente"), 0, "un obiettivo ignoto vale 0")
	# ogni obiettivo ha un bit SUO
	var viste := {}
	for n in ["provvedi_pancino", "provvedi_cura", "provvedi_energia",
			"provvedi_meraviglia"]:
		var b: int = m.maschera_obiettivo(n)
		t.ok(not viste.has(b), "e non lo condivide con nessuno (%s)" % n)
		viste[b] = true


## LA CATENA CHE L'UTENTE HA CHIESTO: cammina → prendi → mangia. Qui il
## verbo di mezzo non esiste (i vicini non hanno tasche, e non è un limite
## ma una scelta: vedi sistema_piani.h), quindi la catena vera è
## «vai al cespuglio → sgranocchia». Due passi, generati — non scritti.
func _la_catena_semplice(t, m) -> void:
	var mondo: int = m.maschera_fatti(PackedStringArray(
			["spuntino_vicino", "spuntino_raggiungibile"]))
	var d: Dictionary = m.debug_piano(mondo, m.maschera_obiettivo("provvedi_pancino"), VICINI)
	var nomi := _nomi(m, d["passi"])
	t.eq(nomi.size(), 2, "il piano ha due passi")
	t.eq(str(nomi[0] if nomi.size() > 0 else "-"), "vai_al_cibo", "prima ci si va")
	t.eq(str(nomi[1] if nomi.size() > 1 else "-"), "sgranocchia", "e poi si mangia")
	t.eq(int(d["esito"]), 0, "ed è un piano riuscito")
	t.ok(float(d["costo"]) > 0.0, "che costa qualcosa (%.1f s)" % float(d["costo"]))
	t.ok(int(d["nodi"]) < 40,
			"trovato in poche espansioni (%d): il dominio è piccolo apposta" % int(d["nodi"]))


## IL RECINTO — è questa la fase. Il cespuglio c'è ancora, ma non ci si
## arriva più: il piano NON è «arrenditi», è «chiedi a Mochi».
func _il_recinto(t, m) -> void:
	# prima: si arriva
	var aperto: int = m.maschera_fatti(PackedStringArray(
			["spuntino_vicino", "spuntino_raggiungibile", "lavagna_pronta"]))
	var d1: Dictionary = m.debug_piano(aperto, m.maschera_obiettivo("provvedi_pancino"), VICINI)
	t.eq(str(_nomi(m, d1["passi"])[0]), "vai_al_cibo",
			"col cespuglio raggiungibile ci si va, e non si disturba nessuno")

	# il giocatore chiude l'ultimo pannello: il cespuglio C'È ANCORA
	var chiuso: int = m.maschera_fatti(PackedStringArray(
			["spuntino_vicino", "lavagna_pronta"]))
	var d2: Dictionary = m.debug_piano(chiuso, m.maschera_obiettivo("provvedi_pancino"), VICINI)
	var nomi := _nomi(m, d2["passi"])
	t.eq(int(d2["esito"]), 0, "un piano nuovo esiste")
	t.eq(nomi.size(), 2, "ed è lungo due passi")
	t.eq(str(nomi[0] if nomi.size() > 0 else "-"), "vai_alla_lavagna",
			"si va alla Lavagna…")
	t.eq(str(nomi[1] if nomi.size() > 1 else "-"), "chiedi_cibo",
			"…e si chiede da mangiare a Mochi: È LA SCENA DELLA FASE 3")
	t.ok(float(d2["costo"]) > float(d1["costo"]),
			"e costa di più che andarselo a prendere (%.1f contro %.1f s)"
					% [float(d2["costo"]), float(d1["costo"])])


## SENZA LAVAGNA E SENZA STRADA non si inventa niente: il pianificatore si
## ARRENDE, e dirlo è metà del lavoro. Un piano che non esiste deve tornare
## vuoto, non un mezzo piano che porta il corpo a metà strada.
func _niente_strada(t, m) -> void:
	var solo_cibo: int = m.maschera_fatti(PackedStringArray(["spuntino_vicino"]))
	var d: Dictionary = m.debug_piano(solo_cibo, m.maschera_obiettivo("provvedi_pancino"), VICINI)
	t.eq(int(d["passi"].size()), 0, "niente strada, niente piano")
	t.eq(int(d["esito"]), 2, "e lo si DICE (PIANO_NIENTE), invece di fingere")


## L'obiettivo già soddisfatto non è un piano vuoto: è una domanda che non
## andava fatta, e chi chiama deve poterla distinguere.
func _gia_fatto(t, m) -> void:
	var ob: int = m.maschera_obiettivo("provvedi_pancino")
	var d: Dictionary = m.debug_piano(ob, ob, VICINI)
	t.eq(int(d["esito"]), 1, "l'obiettivo già vero si chiama PIANO_GIA_VERO")
	t.eq(int(d["passi"].size()), 0, "e non produce passi")


## LA PREFERENZA ESPRESSA COME DIVIETO: col pisolino per terra si può
## sempre, ma se c'è una panchina libera si va sulla panchina. Non è una
## precondizione mancante — chi non ha panchina deve poter comunque
## riposare, se no non recupererebbe energia MAI.
func _preferisce_la_panchina(t, m) -> void:
	var con_panca: int = m.maschera_fatti(PackedStringArray(["seduta_libera_vicina"]))
	var d1: Dictionary = m.debug_piano(con_panca, m.maschera_obiettivo("provvedi_energia"), VICINI)
	var n1 := _nomi(m, d1["passi"])
	t.ok("siedi" in n1, "con una panchina libera ci si siede (%s)" % str(n1))
	t.ok(not "pisolino" in n1, "e non ci si butta per terra")

	var d2: Dictionary = m.debug_piano(0, m.maschera_obiettivo("provvedi_energia"), VICINI)
	var n2 := _nomi(m, d2["passi"])
	t.eq(n2.size(), 1, "senza panchina il piano è di un passo solo")
	t.eq(str(n2[0] if n2.size() > 0 else "-"), "pisolino",
			"e si dorme per terra: nessuno resta senza riposo")


## IL COSTO CONTA: fra due strade si prende la più corta, e la distanza la
## misura GDScript sulla ROTTA, non sulla retta — così il giro largo per
## passare dal cancello costa davvero di più.
func _il_piu_economico(t, m) -> void:
	var mondo: int = m.maschera_fatti(PackedStringArray(
			["spuntino_vicino", "spuntino_raggiungibile", "lavagna_pronta"]))
	var ob: int = m.maschera_obiettivo("provvedi_pancino")
	# cespuglio VICINO: ci si va
	var vicino := PackedFloat64Array([1.0, 2.0, 2.0, 2.0, 2.0])
	t.eq(str(_nomi(m, m.debug_piano(mondo, ob, vicino)["passi"])[0]), "vai_al_cibo",
			"il cespuglio a un passo vince")
	# cespuglio LONTANISSIMO: conviene chiedere
	var lontano := PackedFloat64Array([120.0, 2.0, 2.0, 2.0, 1.0])
	var n := _nomi(m, m.debug_piano(mondo, ob, lontano)["passi"])
	t.ok(n.size() == 0 or str(n[0]) != "vai_al_cibo",
			"e un cespuglio a due minuti di cammino no (%s)" % str(n))
	# e un luogo dichiarato NON disponibile (tempo negativo) non si usa mai
	var vietato := PackedFloat64Array([-1.0, 2.0, 2.0, 2.0, 2.0])
	var nv := _nomi(m, m.debug_piano(mondo, ob, vietato)["passi"])
	t.ok(not "vai_al_cibo" in nv,
			"un luogo dichiarato indisponibile non entra in nessun piano")


## DETERMINISMO: stesso mondo, stesso piano. Sempre. Un pianificatore che
## pesca dall'ordine di una hash map dà villaggi diversi a ogni avvio, e
## nessun test lo direbbe.
func _deterministico(t, m) -> void:
	var mondo: int = m.maschera_fatti(PackedStringArray(
			["spuntino_vicino", "spuntino_raggiungibile", "aiuola_da_annaffiare",
			"aiuola_raggiungibile", "seduta_libera_vicina", "lavagna_pronta"]))
	var atteso: Array = []
	var uguali := true
	for k in 50:
		var d: Dictionary = m.debug_piano(mondo, m.maschera_obiettivo("provvedi_cura"), VICINI)
		var n := _nomi(m, d["passi"])
		if k == 0:
			atteso = n
		elif str(n) != str(atteso):
			uguali = false
	t.ok(uguali, "cinquanta pianificazioni identiche danno lo stesso piano (%s)" % str(atteso))
	t.ok(atteso.size() == 2 and str(atteso[1]) == "annaffia",
			"e il piano dell'aiuola è «vai → annaffia»")


## MAI UN PIANO A METÀ. Con l'arena ridotta a due nodi il pianificatore
## deve arrendersi, non consegnare mezza catena: portare il corpo a metà
## strada e piantarcelo è il guasto che questa fase esiste per rendere
## impossibile.
func _mai_un_piano_a_meta(t, m) -> void:
	var mondo: int = m.maschera_fatti(PackedStringArray(
			["spuntino_vicino", "spuntino_raggiungibile", "lavagna_pronta"]))
	m.debug_tara_piani(40.0, 2, 6)
	var d: Dictionary = m.debug_piano(mondo, m.maschera_obiettivo("provvedi_pancino"), VICINI)
	t.eq(int(d["passi"].size()), 0, "a budget esaurito non esce mezzo piano")
	t.eq(int(d["esito"]), 3, "e lo si dice (PIANO_BUDGET)")
	# e col budget di secondi: un piano più lungo del tetto d'impegno
	# dell'agenda verrebbe strappato via a metà, quindi non si comincia
	m.debug_tara_piani(1.0, 256, 6)
	var d2: Dictionary = m.debug_piano(mondo, m.maschera_obiettivo("provvedi_pancino"), VICINI)
	t.eq(int(d2["passi"].size()), 0,
			"e un piano più lungo del tetto d'impegno non si comincia nemmeno")
	m.debug_tara_piani(40.0, 256, 6)   # si rimette com'era


## ⚠️ **IL BUDGET MISURA IL CORPO, NON L'ATTESA — e per un pezzo non era vero.**
##
## `budget_secondi` (40 s) è «il tetto d'impegno dell'agenda»: per quanto tempo
## quel corpo resta occupato. Ma veniva confrontato col COSTO cumulativo, e
## `chiedi_cibo`/`chiedi_cura` costano **26,6 s** — che non sono tempo di
## corpo: il vicino scrive il biglietto e se ne va, e `_piano_dirotta` gli dà
## `next_act = 9.0`. La mela arriva quando il giocatore la porta.
##
## Restavano quindi **13,4 s di cammino, cioè 18,09 m**, mentre
## `Visitors._luoghi_del_piano` cerca la Lavagna fino a **60 m**: in mezzo
## c'erano quarantadue metri in cui `lavagna_pronta` si accendeva, il piano
## veniva scartato dal budget, `pianifica` tornava vuoto e la scena della
## Fase 3 non succedeva **senza una traccia**.
##
## MISURATO col risolutore vero, prima: piano a 18,0 m, `esito 2` a 18,5 m.
## Dopo: piano fino a 40 m, e oltre a fallire è il CAMMINO (59 m sono 43,7 s
## di corpo occupato, cioè più del tetto) — che è il budget che fa il suo
## mestiere invece di misurare l'attesa di qualcun altro.
##
## ⚠️ **Residuo dichiarato:** il tetto vero adesso è `40 s × 1,35 = 54 m`, e il
## villaggio cerca la Lavagna a 60. Restano sei metri in cui il fatto si
## accende e il piano viene rifiutato — ma adesso è il rifiuto GIUSTO (quel
## cammino è davvero più lungo del tetto d'impegno), non un artefatto. Non si
## scrive 54 a mano: sarebbe la gemella del budget, che vive in C++.
func _il_budget_misura_il_CORPO(t, m) -> void:
	var chiuso: int = m.maschera_fatti(PackedStringArray(
			["spuntino_vicino", "lavagna_pronta"]))
	var ob: int = m.maschera_obiettivo("provvedi_pancino")

	# una Lavagna a VENTI METRI: una distanza ordinaria in questo villaggio
	var venti := PackedFloat64Array([-1.0, -1.0, -1.0, -1.0, PIANI.secondi(20.0)])
	var d: Dictionary = m.debug_piano(chiuso, ob, venti)
	var nomi := _nomi(m, d["passi"])
	t.eq(nomi.size(), 2,
			"con la Lavagna a venti metri la scena della Fase 3 succede")
	if nomi.size() == 2:
		t.eq(str(nomi[0]), "vai_alla_lavagna", "si va alla Lavagna…")
		t.eq(str(nomi[1]), "chiedi_cibo", "…e si chiede a Mochi")

	# ...e a QUARANTA, che prima era fuori di ventidue metri
	var quaranta := PackedFloat64Array([-1.0, -1.0, -1.0, -1.0, PIANI.secondi(40.0)])
	t.eq(_nomi(m, (m.debug_piano(chiuso, ob, quaranta) as Dictionary)["passi"]).size(), 2,
			"e anche a quaranta metri: i 26,6 s dell'attesa non li paga il corpo")

	# ⚠️ LA CONTROPROVA: il budget deve ancora MORDERE sul cammino vero, o
	# «non conta l'attesa» sarebbe diventato «non conta niente».
	var lontanissima := PackedFloat64Array([-1.0, -1.0, -1.0, -1.0, PIANI.secondi(200.0)])
	t.eq(_nomi(m, (m.debug_piano(chiuso, ob, lontanissima) as Dictionary)["passi"]).size(), 0,
			"ma duecento metri di cammino restano più del tetto d'impegno")

	# e il COSTO non è cambiato: chiedere deve costare più che andarselo a
	# prendere, o il pianificatore comincerebbe a preferire la Lavagna
	var aperto: int = m.maschera_fatti(PackedStringArray(
			["spuntino_vicino", "spuntino_raggiungibile", "lavagna_pronta"]))
	var vicino := PackedFloat64Array([PIANI.secondi(5.0), -1.0, -1.0, -1.0,
			PIANI.secondi(5.0)])
	var da_solo: Dictionary = m.debug_piano(aperto, ob, vicino)
	var chiedendo: Dictionary = m.debug_piano(chiuso, ob, vicino)
	t.ok(float(chiedendo["costo"]) > float(da_solo["costo"]),
			("chiedere costa ancora più che andarselo a prendere (%.1f contro "
			+ "%.1f s): il COSTO non è stato toccato, solo l'IMPEGNO")
					% [float(chiedendo["costo"]), float(da_solo["costo"])])
	t.eq(str(_nomi(m, da_solo["passi"])[0]), "vai_al_cibo",
			"…e col cespuglio raggiungibile non si disturba nessuno")


## ⚠️ «IL PRIMO PASSO DI OGNI PIANO E' SEMPRE UN TRASFERIMENTO» E' FALSO.
##
## `sistema_piani.h` lo prometteva, e tutto il canale della ricevuta della
## Fase 5 ci si appoggia: `Deduzioni.meta_del_gesto` legge il `luogo` di
## `passi[0]` per sapere DOVE il corpo andra', ed e' quello che la testa
## guarda mentre la deduzione si fa vedere.
##
## L'eccezione e' UNA, `OP_PISOLINO`: l'unico operatore con
## `luogo = L_NESSUNO` **e** `richiede = 0`, cioe' l'unico che puo' scattare
## dalla RADICE. Quando non c'e' una panchina libera soddisfa
## `A_PROV_ENERGIA` da solo. MISURATO: `pianifica(provvedi_energia)` senza
## `seduta_libera_vicina` torna un piano di UN passo col luogo a −1, mentre
## con la panchina ne torna due e il primo ha luogo 2.
##
## La guardia e' STRUTTURALE, non su quel caso: scandaglia TUTTI gli
## operatori e pretende che chi non ha un luogo chieda una posa — che solo un
## trasferimento accende. Cosi' il giorno che qualcuno aggiunge un secondo
## operatore da radice senza luogo, questo caso lo dice invece di lasciarlo
## scoprire a `meta_del_gesto`, che tacerebbe in silenzio.
func _un_solo_operatore_scatta_senza_luogo(t, m) -> void:
	# le pose stanno nei bit 16-20 (`MASCHERA_POSE` in sistema_piani.h): un
	# operatore che ne CHIEDE una si fa per forza precedere da un
	# trasferimento, perche' solo un trasferimento le accende.
	const MASCHERA_POSE := 0x001F0000
	var senza_luogo_dalla_radice := []
	var quanti := 0
	for i in 64:
		var op: Dictionary = m.debug_operatore(i)
		if op.is_empty():
			break
		quanti += 1
		if int(op.get("luogo", -1)) >= 0:
			continue
		if (int(op.get("richiede", 0)) & MASCHERA_POSE) != 0:
			continue
		senza_luogo_dalla_radice.append(i)
	t.ok(quanti >= 10, "la tabella degli operatori si legge (%d righe)" % quanti)
	t.eq(senza_luogo_dalla_radice.size(), 1,
			"UN solo operatore scatta dalla radice senza luogo (indici: %s)"
					% str(senza_luogo_dalla_radice))
	if senza_luogo_dalla_radice.size() == 1:
		t.eq(int(senza_luogo_dalla_radice[0]), int(m.indice_operatore("pisolino")),
				"ed e' il pisolino — l'eccezione ha un nome")

	# E LA CONSEGUENZA, misurata sul risolutore vero: senza panchina il piano
	# e' di un passo e non ha una meta da mostrare.
	var vicini := PackedFloat64Array([1.0, 1.0, 1.0, 1.0, 1.0])
	var ob := int(m.maschera_obiettivo("provvedi_energia"))
	var con_panchina: Dictionary = m.debug_piano(
			int(m.maschera_fatti(PackedStringArray(["seduta_libera_vicina"]))),
			ob, vicini)
	var senza: Dictionary = m.debug_piano(
			int(m.maschera_fatti(PackedStringArray([]))), ob, vicini)
	var pc: PackedInt32Array = con_panchina["passi"]
	var ps: PackedInt32Array = senza["passi"]
	t.ok(pc.size() >= 2 and int((m.debug_operatore(int(pc[0])) as Dictionary)["luogo"]) >= 0,
			"con la panchina il primo passo E' un trasferimento (%d passi)" % pc.size())
	t.eq(ps.size(), 1, "senza panchina il piano e' di UN passo")
	if ps.size() == 1:
		t.ok(int((m.debug_operatore(int(ps[0])) as Dictionary)["luogo"]) < 0,
				"…e quel passo non ha nessun luogo: e' li' che l'invariante cade")
