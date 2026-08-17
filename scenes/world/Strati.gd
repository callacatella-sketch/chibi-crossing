extends Node

## LA STRATIGRAFIA — il salvataggio come sito archeologico di se stesso.
##
## Tre sorgenti seppelliscono strati nella terra del prato: ciò che il
## GIOCATORE demolisce (la trave del primo ponte), chi PARTE per sempre
## (il gessetto del vicino che se n'è andato due inverni fa, vicino a
## casa sua), e le STAGIONI che di rado lasciano un segno (petalo
## pressato, foglia d'oro, fiocco). Il verbo che li riporta alla luce è
## quello che ESISTE GIÀ: i luccichii del mattino di Scavi.gd — ogni
## tanto uno nasce sopra uno strato, e quel giorno il trovamento È il
## reperto.
##
## Regole cozy NON negoziabili: niente rovine in superficie (il mondo
## visibile non cambia), niente annunci/contatori/pannelli (si scopre
## scavando, e il silenzio è il comportamento normale), e il reperto di
## un vicino partito è tenerezza, mai colpa.
##
## Questo nodo è il LEDGER e le sue funzioni pure; i cablaggi (chi
## chiama su_demolizione/su_partenza, e chi legge strato_del_giorno)
## vivono in BuildSystem, Visitors e Scavi.

const SCAVI := preload("res://scenes/interact/Scavi.gd")   # fonte unica: RECT, punto_libero
const DN := preload("res://scenes/world/DayNight.gd")      # fonte unica: SEASON_DAYS
# ⚠️ CICLO DI PRELOAD: Strati precarica Scavi; Scavi NON deve MAI
# precaricare Strati (lo trova a runtime nel gruppo "strati"), o il parse
# fallisce in modi silenziosi nei test headless.

const MAX_STRATI := 40         # la terra non è un magazzino: oltre, si lascia andare
const PROB_AFFIORA := 0.35     # «ogni tanto»: circa un mattino su tre, se c'è qualcosa
const PROB_SEGNO := 0.5        # il segno di stagione è raro apposta
const RAGGIO_SEPOLTURA := 4    # anelli Chebyshev attorno alla casa
const TENTATIVI_RIPIEGO := 40  # estrazioni seminate se gli anelli falliscono

# indice = la stagione FINITA (ordine di DayNight.SEASON_NAMES)
const SEGNI_STAGIONE := {0: "petalo_pressato", 1: "spiga_dorata",
		2: "foglia_d_oro", 3: "fiocco_intatto"}

# il carattere → l'oggetto: il quirk prima (è il gesto suo più suo), poi il
# MESTIERE (la storia che il giocatore gli ha dato), poi la prima indole.
const OGGETTI_QUIRK := {
	"colleziona_sassolini": "sassolino_lucido",
	"canta_alla_luna": "foglietto_di_note",
	"parla_ai_funghi": "funghetto_di_legno",
	"paura_farfalle": "farfallina_di_carta",   # ne ha piegata una che non fa paura
	"ballerino": "nastrino_da_ballo",
	"pisolini_ovunque": "cuscinetto_ricamato",
}
const OGGETTI_MESTIERE := {
	"taglia_legna": "truciolo_riccio",    "coltiva": "sacchettino_di_semi",
	"cucina": "cucchiaino_di_legno",      "guardia": "lanternina_spenta",
	"esplora": "mappina_piegata",         "abbellisce": "pennellino_consumato",
	"suona": "fischietto_di_canna",
}
const OGGETTI_INDOLE := {
	"goloso": "barattolino_di_briciole",  "dormiglione": "cuscinetto_ricamato",
	"mattiniero": "tazzina_sbeccata",     "chiacchierone": "campanellino",
	"timido": "guscio_di_nocciola",       "sognatore": "stellina_di_latta",
	"ordinato": "gomitolino",             "brontolone": "cuoricino_di_legno",
}
const OGGETTO_FALLBACK := "bottone_di_legno"

# La riga di strato è JSON-SAFE già in RAM (`cella` = [x, z] di int):
# niente doppia forma Vector2i/Array da convertire, niente classe di bug.
#   comune:              {"tipo": String, "cella": [x, z], "g": int}
#   tipo "demolizione":  + {"pezzo": String}                      # item_name del pezzo
#   tipo "ricordo":      + {"nome": String,     # chiave dei Legami (NOME del DNA, MAI la label)
#                           "label": String,    # solo display (il toast)
#                           "oggetto": String,  # id in Inventory.TREASURES
#                           "tinta": [r, g, b]} # il pelo del dna: tinge il modellino
#   tipo "stagione":     + {"segno": String}    # id in Inventory.TREASURES
# `g` = giorno di sepoltura. Contano solo gli strati con g < oggi: ciò che
# seppellisci oggi non può muovere i luccichii di oggi (determinismo).
var _strati: Array = []   # le righe, in ordine di sepoltura (append-only nel giorno)
var _g_aff := -1          # il giorno in cui il reperto affiorato è stato SCAVATO
var _g_pota := -1         # l'ultimo giorno in cui la potatura è girata
var _cozy: Node3D
var _daynight: Node3D
var _build: Node


# ------------------------------------------------- le funzioni pure, statiche
# Tutte provate headless in tests/cases/test_strati.gd. ⚠️ ORDINE DI
# CONSUMO RNG: in ognuna di queste, spostare un randf/randi o riformattare
# un seme cambia TUTTE le scelte — esattamente come in punti_del_giorno
# (Scavi). I test lo misurano punto per punto.

## Che oggetto lascia alla terra chi se ne va: quirk → mestiere →
## indole[0] → bottone. Nessun rng: il carattere basta.
static func oggetto_del_ricordo(dna: Dictionary, mestiere: String) -> String:
	var quirk := str(dna.get("quirk", ""))
	if OGGETTI_QUIRK.has(quirk):
		return str(OGGETTI_QUIRK[quirk])
	if OGGETTI_MESTIERE.has(mestiere):
		return str(OGGETTI_MESTIERE[mestiere])
	var indoli: Array = dna.get("indole", []) if dna.get("indole") is Array else []
	if indoli.size() > 0 and OGGETTI_INDOLE.has(str(indoli[0])):
		return str(OGGETTI_INDOLE[str(indoli[0])])
	return OGGETTO_FALLBACK


## Il pelo di chi è partito, come [r, g, b]: tinge il modellino del
## reperto (si riconosce CHI era dal colore, come nei sogni). "fur" può
## essere Color (RAM), String html (il DNA salvato: to_html senza #) o
## Array (un giro di JSON): si accettano tutti; fallback beige caldo.
static func tinta_da(dna: Dictionary) -> Array:
	var fur: Variant = dna.get("fur")
	if fur is Color:
		return [(fur as Color).r, (fur as Color).g, (fur as Color).b]
	if fur is String and Color.html_is_valid(str(fur)):
		var c := Color.html(str(fur))
		return [c.r, c.g, c.b]
	if fur is Array and (fur as Array).size() >= 3:
		var a := fur as Array
		return [float(a[0]), float(a[1]), float(a[2])]
	return [0.82, 0.72, 0.58]


static func riga_demolizione(cella: Array, pezzo: String, g: int) -> Dictionary:
	return {"tipo": "demolizione", "cella": [int(cella[0]), int(cella[1])],
			"g": g, "pezzo": pezzo}


static func riga_ricordo(cella: Array, nome: String, label: String,
		dna: Dictionary, mestiere: String, g: int) -> Dictionary:
	return {"tipo": "ricordo", "cella": [int(cella[0]), int(cella[1])], "g": g,
			"nome": nome, "label": label,
			"oggetto": oggetto_del_ricordo(dna, mestiere), "tinta": tinta_da(dna)}


## «La trave del PRIMO ponte»: un solo strato per pezzo — le demolizioni
## successive dello stesso item_name non seppelliscono doppioni (e dieci
## staccionate non riempiono la terra di schegge uguali).
static func gia_sepolto_pezzo(strati: Array, pezzo: String) -> bool:
	for r in strati:
		if r is Dictionary and str((r as Dictionary).get("tipo", "")) == "demolizione" \
				and str((r as Dictionary).get("pezzo", "")) == pezzo:
			return true
	return false


## Il segno che una stagione lascia andandosene: {} quasi sempre.
## Deposita SOLO il primo giorno di una stagione nuova ((giorno - 1) %
## SEASON_DAYS == 0, giorno > 1): il confine è DERIVATO dal giorno, così
## il season_changed ri-emesso al caricamento è innocuo PER COSTRUZIONE.
## UN rng seminato: 1° consumo il tiro di PROB_SEGNO, poi fino a
## TENTATIVI_RIPIEGO candidati dentro SCAVI.RECT scartati con valida_cella.
## NB: la cella si sceglie e si SALVA alla sepoltura (snapshot): gli
## obstacle_circles variano tra un avvio e l'altro (i massi); il
## determinismo vive sulle righe salvate, non sul mondo.
static func riga_stagionale(giorno: int, ostacoli: Array) -> Dictionary:
	if giorno <= 1 or (giorno - 1) % DN.SEASON_DAYS != 0:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("strato_stagione_%d" % giorno)
	if rng.randf() >= PROB_SEGNO:
		return {}   # il segno è raro apposta
	# il segno è della stagione FINITA, quella di ieri
	@warning_ignore("integer_division")
	var stagione := (int((giorno - 1) / DN.SEASON_DAYS) + 3) % 4
	for _i in TENTATIVI_RIPIEGO:
		var cella := [
			roundi(rng.randf_range(SCAVI.RECT.position.x, SCAVI.RECT.end.x)),
			roundi(rng.randf_range(SCAVI.RECT.position.y, SCAVI.RECT.end.y))]
		if valida_cella(cella, ostacoli):
			return {"tipo": "stagione", "cella": cella, "g": giorno,
					"segno": str(SEGNI_STAGIONE[stagione])}
	return {}


## Il cuore deterministico: lo strato che affiora oggi, {} quasi sempre.
## 1) eleggibili: solo righe con g < giorno; 2) STRATIGRAFIA: per ogni
## cella si tiene SOLO la riga con g massimo (a parità di g: la sepolta
## prima) — lo strato più in alto si scava per primo, e sotto la trave di
## ieri c'è il gessetto di due inverni fa, che riaffiorerà un altro
## giorno; 3) le celle si ORDINANO (sort lessicografico su [x, z]): la
## scelta non dipende dall'ordine dell'array, che cambia con la potatura;
## 4) il dado del giorno: 1° consumo il tiro di PROB_AFFIORA (il silenzio
## è il comportamento normale), 2° consumo la cella.
static func strato_affiorante(giorno: int, strati: Array) -> Dictionary:
	var per_cella := {}      # "x:z" -> la riga più in alto
	var celle: Array = []    # [x, z, "x:z"] da ordinare
	for r in strati:
		if not (r is Dictionary):
			continue
		var riga := r as Dictionary
		if int(riga.get("g", giorno)) >= giorno:
			continue
		var c: Array = riga.get("cella", []) if riga.get("cella") is Array else []
		if c.size() != 2:
			continue
		var k := "%d:%d" % [int(c[0]), int(c[1])]
		if not per_cella.has(k):
			per_cella[k] = riga
			celle.append([int(c[0]), int(c[1]), k])
		elif int(riga.get("g", 0)) > int((per_cella[k] as Dictionary).get("g", 0)):
			per_cella[k] = riga
	if celle.is_empty():
		return {}
	celle.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("affiora_%d" % giorno)
	if rng.randf() >= PROB_AFFIORA:
		return {}
	var scelta: Array = celle[rng.randi() % celle.size()]
	return (per_cella[scelta[2]] as Dictionary).duplicate(true)


## Una cella può custodire (e un giorno restituire) uno strato? Fuori dal
## prato non affiorerebbe MAI — quindi non ci si seppellisce proprio.
static func valida_cella(cella: Array, ostacoli: Array) -> bool:
	var p := Vector3(int(cella[0]), 0.0, int(cella[1]))
	if not SCAVI.RECT.has_point(Vector2(p.x, p.z)):
		return false
	return SCAVI.punto_libero(p, ostacoli)


## «Vicino a casa sua»: le celle attorno, anelli Chebyshev 1..RAGGIO_
## SEPOLTURA, l'anello più interno PRIMA, mescolate DENTRO l'anello con
## Fisher-Yates su un rng seminato (shuffle() userebbe il rng globale:
## irriproducibile). L'offset (0,0) è escluso per costruzione (gli anelli
## partono da 1: è il letto); (+1,+1) è escluso a mano: lì il Congedo
## pianta il fiore-memoriale (_spawn_fiore a cell+0.7, cell+0.9) e il
## reperto non va sotto i suoi petali. → Array di [x, z] ASSOLUTI.
static func celle_intorno(casa: Array, seme: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	var out: Array = []
	for anello in range(1, RAGGIO_SEPOLTURA + 1):
		var giro: Array = []
		for dx in range(-anello, anello + 1):
			for dz in range(-anello, anello + 1):
				if maxi(absi(dx), absi(dz)) != anello:
					continue
				if dx == 1 and dz == 1:
					continue   # il fiore-memoriale
				giro.append([int(casa[0]) + dx, int(casa[1]) + dz])
		for i in range(giro.size() - 1, 0, -1):
			var j := int(rng.randi() % (i + 1))
			var tmp: Array = giro[i]
			giro[i] = giro[j]
			giro[j] = tmp
		out.append_array(giro)
	return out


## Dove seppellire il ricordo di chi parte: la prima cella degli anelli
## che è nel prato, libera e non occupata; poi un ripiego seminato dentro
## il RECT (bounds DERIVATI da SCAVI.RECT, mai ricopiati); poi null — il
## silenzio è il comportamento normale. `e_occupata` è una Callable
## APPOSTA: il nodo ci mette has_cover del BuildSystem, il test headless
## uno stub.
static func cella_di_sepoltura(casa: Array, seme: int, giorno: int,
		ostacoli: Array, e_occupata: Callable) -> Variant:   # [x, z] | null
	for c in celle_intorno(casa, seme):
		if valida_cella(c, ostacoli) and not bool(e_occupata.call(c)):
			return c
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("sepoltura_%d_%d_%d" % [giorno, int(casa[0]), int(casa[1])])
	var x0 := int(ceilf(SCAVI.RECT.position.x))
	var x1 := int(floorf(SCAVI.RECT.end.x))
	var z0 := int(ceilf(SCAVI.RECT.position.y))
	var z1 := int(floorf(SCAVI.RECT.end.y))
	for _i in TENTATIVI_RIPIEGO:
		var c := [rng.randi_range(x0, x1), rng.randi_range(z0, z1)]
		if valida_cella(c, ostacoli) and not bool(e_occupata.call(c)):
			return c
	return null


## La potatura gentile. size <= MAX_STRATI → la lista com'è. Ordine di
## sacrificio: "stagione" prima, poi "demolizione", poi — per ULTIMI — i
## "ricordo"; a parità di tipo il g più vecchio, a parità di g l'indice
## più basso. Che i ricordi cadano per ultimi è ciò che porta il gessetto
## a «due inverni fa»: protezione STRUTTURALE, non un flag. L'ordine
## relativo dei sopravvissuti si conserva (si filtra, non si riordina).
static func pota(strati: Array) -> Array:
	if strati.size() <= MAX_STRATI:
		return strati
	var da_togliere := strati.size() - MAX_STRATI
	var prio := {"stagione": 0, "demolizione": 1, "ricordo": 2}
	var indici: Array = []
	for i in strati.size():
		indici.append(i)
	indici.sort_custom(func(a, b) -> bool:
		var ra: Dictionary = strati[a] if strati[a] is Dictionary else {}
		var rb: Dictionary = strati[b] if strati[b] is Dictionary else {}
		var pa := int(prio.get(str(ra.get("tipo", "")), 1))
		var pb := int(prio.get(str(rb.get("tipo", "")), 1))
		if pa != pb:
			return pa < pb
		var ga := int(ra.get("g", 0))
		var gb := int(rb.get("g", 0))
		if ga != gb:
			return ga < gb
		return a < b)
	var vittime := {}
	for i in mini(da_togliere, indici.size()):
		vittime[indici[i]] = true
	var out: Array = []
	for i in strati.size():
		if not vittime.has(i):
			out.append(strati[i])
	return out


# ---------------------------------------------------------------- cablaggio

func _ready() -> void:
	add_to_group("persistable")   # il giro save_extra/load_extra fa il resto
	add_to_group("strati")
	_cabla.call_deferred()


# I figli runtime nascono differiti (CozyWorld si costruisce su più
# frame): il cablaggio si RIPROVA ogni volta che manca un pezzo, finché
# non ha trovato tutto — la trappola del Taccuino, già pagata.
func _cabla() -> void:
	if not is_inside_tree():
		return
	if _cozy == null:
		_cozy = get_node_or_null("../CozyWorld")
	if _build == null:
		_build = get_tree().get_first_node_in_group("build_system")
	if _daynight == null:
		_daynight = get_node_or_null("../DayNight")
		if _daynight and _daynight.has_signal("season_changed"):
			_daynight.season_changed.connect(_su_stagione)


func _oggi() -> int:
	if _daynight == null:
		_cabla()
	return int(_daynight.get("day")) if _daynight else 0


func _ostacoli() -> Array:
	if _cozy == null:
		_cabla()
	return _cozy.call("obstacle_circles") if _cozy else []


# Si salva SOLO con l'API pubblica del BuildSystem (request_save,
# idempotente nel frame; muto sotto _loading, ed è giusto così): il
# writer privato è suo e di nessun altro.
func _salva() -> void:
	if not is_inside_tree():
		return   # fuori dall'albero (test headless): nessuno da avvisare
	if _build == null:
		_build = get_tree().get_first_node_in_group("build_system")
	if _build:
		_build.call("request_save")


# ---------------------------------------------------------------- scrittori

## SCRITTORE 1 — la demolizione del GIOCATORE (call_group da _try_remove:
## SOLO quel percorso; debug_clear/debug_remove_edge non seppelliscono).
## layer: int 0..3 oppure "edge" (chiave RADDOPPIATA); lvl: il piano.
func su_demolizione(layer: Variant, key: Vector2i, node: Node3D, lvl: int) -> void:
	if lvl != 0 or node == null or _oggi() <= 0:
		return                    # il piano di sopra non tocca la terra
	var pezzo := str(node.get_meta("item_name", ""))
	if pezzo == "" or gia_sepolto_pezzo(_strati, pezzo):
		return
	var cella: Array
	if layer is String:
		# bordo: chiave raddoppiata — la scheggia cade nella cella accanto
		cella = [roundi(float(key.x) * 0.5), roundi(float(key.y) * 0.5)]
	else:
		cella = [int(key.x), int(key.y)]
	if not valida_cella(cella, _ostacoli()):
		return                    # dove non può affiorare, non si seppellisce
	# has_cover NON si guarda QUI, ed è voluto: la trave sotto la casa
	# nuova ASPETTA che la casa se ne vada — è il punto della feature.
	_strati.append(riga_demolizione(cella, pezzo, _oggi()))
	_salva()


## SCRITTORE 2 — chi parte per sempre (diserzione E Grande Prato).
## nome = chiave del DNA (i Legami: le due anagrafi), label = solo
## display, casa = [x, z], mestiere = letto DAL CHIAMANTE prima che
## l'ultima riga di _congeda lo azzeri (r.3108) e passato qui: la
## trappola è disinnescata strutturalmente.
func su_partenza(nome: String, label: String, casa: Array,
		dna: Dictionary, mestiere: String) -> void:
	var oggi := _oggi()
	if nome == "" or casa.size() != 2 or oggi <= 0:
		return
	var occ := func(c: Array) -> bool:
		if _build and bool(_build.call("has_cover", Vector2i(int(c[0]), int(c[1])))):
			return true
		for r in _strati:   # niente doppioni sulla stessa cella lo stesso giorno
			if r is Dictionary and int((r as Dictionary).get("g", -1)) == oggi \
					and (r as Dictionary).get("cella", []) == [int(c[0]), int(c[1])]:
				return true
		return false
	var cella = cella_di_sepoltura(casa, hash("ricordo_" + nome), oggi,
			_ostacoli(), occ)     # var x = …: ritorna Variant
	if cella == null:
		return                    # nessuna cella buona: il silenzio è normale
	_strati.append(riga_ricordo(cella, nome, label, dna, mestiere, oggi))
	_salva()


## SCRITTORE 3 — le stagioni. Idempotente per costruzione: riga_stagionale
## risponde {} fuori dai giorni di confine, e il dedupe per g fa il resto
## (il season_changed ri-emesso al caricamento non deposita doppioni).
func _su_stagione(_stagione: int) -> void:
	var g := _oggi()
	if g <= 0:
		return
	for r in _strati:
		if r is Dictionary and str((r as Dictionary).get("tipo", "")) == "stagione" \
				and int((r as Dictionary).get("g", 0)) == g:
			return
	var riga := riga_stagionale(g, _ostacoli())
	if not riga.is_empty():
		_strati.append(riga)
		_salva()


# ------------------------------------------------------------------ lettore

## Lo strato che affiora oggi ({} quasi sempre) — per Scavi._rigenera.
## STABILE per tutto il giorno, su tre gambe: (a) la potatura gira UNA
## volta al giorno, QUI, prima della scelta; (b) le sepolture di oggi
## hanno g == oggi, appese in coda: non eleggibili; (c) l'unica rimozione
## intra-giorno è estratto(), dopo la quale _g_aff tappa la porta. E
## strato_affiorante ordina le celle: nemmeno l'ordine dell'array conta.
## ⚠️ Chiunque in futuro aggiunga una rimozione di righe a metà giornata
## (o «ottimizzi» spostando la potatura alla sepoltura) sposta il piano
## dei luccichii al reload: NON FARLO.
func strato_del_giorno(giorno: int) -> Dictionary:
	if giorno <= 0 or _g_aff == giorno:
		return {}
	_su_stagione(0)   # rete di sicurezza: se il season_changed del
	                  # caricamento è partito prima del nostro deferred,
	                  # il segno di oggi si recupera qui (dedupe per g)
	if _g_pota != giorno:
		_strati = pota(_strati)
		_g_pota = giorno
		_salva()
	return strato_affiorante(giorno, _strati)


## Il reperto è stato scavato: la riga esce dalla terra PER IDENTITÀ
## (g + tipo + cella, con int() su tutto), MAI per indice — gli indici
## non sopravvivono a potature e salvataggi. Poi _g_aff = giorno: oggi
## non affiora più niente («ogni tanto» resta vero). Va chiamata SUBITO,
## prima dell'animazione (la rete di sicurezza di _scavati.append):
## salvataggio a metà scavata → al reload niente doppione.
func estratto(riga: Dictionary, giorno: int) -> void:
	var g := int(riga.get("g", -1))
	var tipo := str(riga.get("tipo", ""))
	var c: Array = riga.get("cella", []) if riga.get("cella") is Array else []
	if c.size() == 2:
		for i in _strati.size():
			var r: Dictionary = _strati[i] if _strati[i] is Dictionary else {}
			var rc: Array = r.get("cella", []) if r.get("cella") is Array else []
			if int(r.get("g", -2)) == g and str(r.get("tipo", "")) == tipo \
					and rc.size() == 2 \
					and int(rc[0]) == int(c[0]) and int(rc[1]) == int(c[1]):
				_strati.remove_at(i)
				break
	_g_aff = giorno
	_salva()


# -------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	return {"strati": {"righe": _strati, "g_aff": _g_aff, "g_pota": _g_pota}}


## Accetta qualunque schifezza: righe malformate si saltano, mai crash.
## JSON: gli int tornano float (si rilegge TUTTO con int()), e la cella
## è già [x, z] perché la riga è JSON-safe fin dalla RAM.
func load_extra(data: Dictionary) -> void:
	var d: Variant = data.get("strati")
	if not (d is Dictionary):
		return
	_strati = []
	var righe: Array = (d as Dictionary).get("righe", []) \
			if (d as Dictionary).get("righe") is Array else []
	for r in righe:
		if not (r is Dictionary):
			continue
		var riga: Dictionary = (r as Dictionary).duplicate(true)
		var c: Array = riga.get("cella", []) if riga.get("cella") is Array else []
		if c.size() != 2:
			continue
		riga["g"] = int(riga.get("g", 0))
		riga["cella"] = [int(c[0]), int(c[1])]
		_strati.append(riga)
	_g_aff = int((d as Dictionary).get("g_aff", -1))
	_g_pota = int((d as Dictionary).get("g_pota", -1))
	# NIENTE _salva() qui (e request_save è comunque muto sotto _loading)


# ---------------------------------------------------------------- debug CLI

func debug_state() -> Dictionary:
	var ricordi := 0
	for r in _strati:
		if r is Dictionary and str((r as Dictionary).get("tipo", "")) == "ricordo":
			ricordi += 1
	return {"strati": _strati.size(), "ricordi": ricordi,
			"g_aff": _g_aff, "g_pota": _g_pota}
