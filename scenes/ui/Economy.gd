extends Node

## L'economia gentile di Chibi Crossing 🌰⭐
##
## Due valute:
##   Noccioline 🌰  — la valuta di tutti i giorni. Si guadagnano VENDENDO al
##                    mercante le farfalle, i pesci e i raccolti raccolti; si
##                    spendono per varianti di colore dei mobili e pezzi nuovi.
##   Stelline   ⭐  — la valuta rara. Cadono solo quando acchiappi una creatura
##                    RARA (farfalla dorata, lucciola, carpa rosina). Sbloccano
##                    i pezzi speciali del catalogo.
##
## Nessuna fretta, nessuna penale: si accumula piano, vivendo il villaggio.
## Lo stato viaggia dentro user://village.json (gruppo "persistable"), quindi
## un "Nuovo villaggio" (file cancellato + scena ricaricata) riparte da zero.

signal nuts_changed(total: int)
signal stars_changed(total: int)
signal shop_changed          # sblocchi cambiati: la UI di costruzione si rinfresca

# Nomi, colori, valore di vendita e rarità di ogni specie vivono in UN posto
# solo: il bestiario. Qui restano soltanto le regole dell'economia.
const CRIT := preload("res://scenes/world/Critters.gd")

# quante stelline vale una cattura rara
const STAR_PER_RARE := 1

## Pezzi NUOVI del catalogo, in vendita (partono bloccati). I nomi combaciano
## con i builder aggiunti in BuildCatalog.gd, marcati "shop": true.
const SHOP_PIECES := [
	{"name": "Casetta uccellini", "cost": 45, "cur": "nut", "cat": 2,
		"desc": "Un nido dipinto su un palo: i passeri ci passano a salutare."},
	{"name": "Lampione", "cost": 65, "cur": "nut", "cat": 2,
		"desc": "Un lampione da giardino: la sera si accende di miele."},
	{"name": "Amaca", "cost": 80, "cur": "nut", "cat": 1,
		"desc": "Un'amaca a righe tra due paletti. Per i pomeriggi lenti."},
	{"name": "Altalena", "cost": 95, "cur": "nut", "cat": 2,
		"desc": "Un'altalena di corda e legno che dondola nel vento."},
	# LE TRE SORELLE DELLA FIORIERA. La Fioriera arriva col bar (sta nel
	# CORREDO del bancone); queste si comprano a parte, perche' un
	# villaggio si arreda anche fuori dal dehors — e perche' tre
	# silhouette diverse valgono piu' di tre copie della stessa.
	{"name": "Cesto fiorito", "cost": 70, "cur": "nut", "cat": 2,
		"desc": "Un cesto di vimini intrecciato a mano, colmo di fiori di campo:\nmargherite, campanule che pendono e achillea."},
	{"name": "Fioriera bistrot", "cost": 85, "cur": "nut", "cat": 2,
		"desc": "Avorio laccato e verde salvia, coi gerani in mazzo:\nquella dei caffè coi tavolini fuori."},
	{"name": "Fioriera selvatica", "cost": 60, "cur": "nut", "cat": 2,
		"desc": "Una cassa rustica che il prato si è ripreso:\nerba alta, fiori misti e l'edera che scende."},
	{"name": "Fontana", "cost": 150, "cur": "nut", "cat": 2,
		"desc": "Una fontanella tonda con lo zampillo che canta."},
	{"name": "Gazebo", "cost": 240, "cur": "nut", "cat": 0,
		"desc": "Un gazebo esagonale col tetto a pagoda: il salotto all'aperto."},
	{"name": "Bancarella", "cost": 120, "cur": "nut", "cat": 2,
		"desc": "Il banchetto di Mochi: esponi tre tesori col tuo\nprezzo, e chi passa compra ciò che il cuore gli dice."},
	# IL SALONE non si compra e basta: la sua RICETTA la manda il Gufo
	# quando in paese arriva qualcuno che sogna di fare l'estetista
	# (vedi GufoOrders, desiderio "il-salone-di-chi-lo-sogna"). Sta qui
	# perche' i pezzi del negozio nascono BLOCCATI: senza, il salone
	# sarebbe nel catalogo dal primo minuto, prima ancora che esista
	# qualcuno capace di tenerlo.
	{"name": "Salone", "cost": 280, "cur": "nut", "cat": 1,
		"desc": "Specchio ovale, poltrona col pistone e carrello dei\ncolori: chi ci si siede se ne va diverso."},
	{"name": "Palco", "cost": 60, "cur": "nut", "cat": 0,
		"desc": "Un tavolato d'assi chiare. Posane quanti ne vuoi:\nil palco e' grande quanto lo fai tu."},
	{"name": "Fondale", "cost": 260, "cur": "nut", "cat": 0,
		"desc": "La conchiglia acustica: rimanda la voce a chi\nascolta, e di sera si accende ai due lati."},
	{"name": "Gradinata", "cost": 90, "cur": "nut", "cat": 0,
		"desc": "Due file di pietra per sedersi davanti al palco.\nAffiancane quante ne servono: e' la platea."},
	{"name": "Pianoforte", "cost": 420, "cur": "nut", "cat": 1,
		"desc": "A coda, col coperchio aperto. Chi sogna di fare\nl'artista non aspetta altro."},
	{"name": "Stendino", "cost": 85, "cur": "nut", "cat": 2,
		"desc": "Due pali, una corda e le mollette: il bucato che\nondeggia al sole è il respiro del villaggio."},
	{"name": "Giostrina", "cost": 6, "cur": "star", "cat": 2,
		"desc": "Una piccola giostra a cavallucci. Gira piano, come un carillon."},
	{"name": "Braciere stellato", "cost": 4, "cur": "star", "cat": 1,
		"desc": "Un braciere che sputa scintille dorate nella notte."},
	# i SOGNI: pezzi da risparmio lungo, perché le noccioline restino
	# desiderabili anche quando il carretto di tutti i giorni è già tuo
	{"name": "Carillon", "cost": 500, "cur": "nut", "cat": 1,
		"desc": "Una scatola di ciliegio con la manovella: caricala\ne cambia la musica di tutto il villaggio."},
	{"name": "Guardiola", "cost": 300, "cur": "nut", "cat": 0,
		"desc": "Il posto di guardia: una casina col lume azzurro sempre\nacceso, e l'armadio dove le cose perse aspettano\nchi le ha perse. Arriva con tutto il suo corredo."},
	{"name": "Sacco", "cost": 240, "cur": "nut", "cat": 3,
		"desc": "Un sacco da farina rattoppato, appeso a un braccio di legno.\nCol sacco arriva tutta la palestra del villaggio: il\ntappetino, la panca, la sbarra, e la botte dell'acqua."},
	{"name": "Autopompa", "cost": 460, "cur": "nut", "cat": 0,
		"desc": "La caserma dei pompieri, tutta intera: l'autopompa\nlucidata, la campana che chiama in piazza e gli\nstivali in fila. Qui non brucia niente: si tiene pronto."},
	{"name": "Campanile", "cost": 700, "cur": "nut", "cat": 4,
		"desc": "La chiesa del paese, tutta intera: la torre che si vede\nda ogni prato, le vetrate che accendono il pavimento, e\nil lume che si accende per chi è partito."},
	{"name": "Bancone bar", "cost": 380, "cur": "nut", "cat": 0,
		"desc": "Il bar del paese, tutto intero: il bancone di zinco, la\nmacchina del caffè che sbuffa, i tavolini sotto\nl'ombrellone e il biliardino. Il posto dove ci si trova."},
	{"name": "Vetrina moda", "cost": 540, "cur": "nut", "cat": 5,
		"desc": "La boutique del paese, tutta intera: la vetrina che di\nsera illumina la strada, gli stender, i camerini con la\ntenda pesante e lo specchio a tre ante."},
	{"name": "Serra", "cost": 520, "cur": "nut", "cat": 2,
		"desc": "Un giardino di vetro: col suo tepore, orto e fiori\ncrescono anche sotto la neve."},
	{"name": "Palo lucine", "cost": 210, "cur": "nut", "cat": 2,
		"desc": "Paletti da piantare dove vuoi. Fra due che si vedono\nil filo si tende da solo: più lontani li metti, più\nlampadine ci stanno. Il disegno lo fai tu."},
	{"name": "Mongolfiera", "cost": 650, "cur": "nut", "cat": 2,
		"desc": "Una mongolfiera a strisce, ormeggiata in giardino.\nDondola nel vento e non parte mai senza di te."},
]

## Varianti di colore GLOBALI: comprarne una la rende disponibile per TUTTI i
## mobili tintabili. In costruzione si scorre tra i colori posseduti.
const VARIANTS := [
	{"id": "menta", "label": "Menta", "tint": Color("a8ddc0"), "cost": 35, "cur": "nut"},
	{"id": "lavanda", "label": "Lavanda", "tint": Color("cdbff0"), "cost": 35, "cur": "nut"},
	{"id": "cielo", "label": "Cielo", "tint": Color("aed4f2"), "cost": 40, "cur": "nut"},
	{"id": "pesca", "label": "Pesca", "tint": Color("f6c39c"), "cost": 40, "cur": "nut"},
	{"id": "rosa", "label": "Rosa confetto", "tint": Color("f6b6cc"), "cost": 45, "cur": "nut"},
	{"id": "miele", "label": "Miele", "tint": Color("f2cf7e"), "cost": 50, "cur": "nut"},
	{"id": "aurora", "label": "Aurora", "tint": Color("cbb4f0"), "cost": 3, "cur": "star", "rainbow": true},
]

## I mobili che accettano una tinta (il resto tiene i suoi colori).
const VARIANT_PIECES := [
	"Sedia", "Sgabello", "Tavolino", "Letto", "Panchina", "Comodino",
	"Libreria", "Lampada", "Lampada semplice", "Tappeto", "Pianta", "Cespuglio", "Amaca",
]

## Da questo prezzo in su (o se costa stelline) un pezzo è "raro": può
## diventare il raro del giorno sul carretto.
const RARO_SOGLIA := 150

var nuts := 0
var stars := 0
var _unlocked_pieces := {}     # {piece_name: true}
var _unlocked_variants := {}   # {variant_id: true}

## Il banco del mercante di OGGI: nomi di pezzi, il primo è il raro del
## giorno. Si rifà a ogni visita (rotate_stock), persiste col villaggio.
var stock: Array = []
var stock_day := -1


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("economy")


# ---------------------------------------------------------------- valute
func add_nuts(n: int) -> void:
	if n == 0:
		return
	nuts = maxi(0, nuts + n)
	nuts_changed.emit(nuts)
	_save()


func add_stars(n: int) -> void:
	if n == 0:
		return
	stars = maxi(0, stars + n)
	stars_changed.emit(stars)
	_save()


func can_afford(cost: int, cur: String) -> bool:
	return (stars if cur == "star" else nuts) >= cost


func spend(cost: int, cur: String) -> bool:
	if not can_afford(cost, cur):
		return false
	if cur == "star":
		add_stars(-cost)
	else:
		add_nuts(-cost)
	return true


# ---------------------------------------------------------------- catture
func sell_value(kind: String) -> int:
	return CRIT.vendita(kind)


## Il nome col maiuscolo, per il bancone ("Farfalla dorata").
func label_for(kind: String) -> String:
	return CRIT.etichetta(kind)


## Il colore-spia del pallino nel negozio: è IL colore della creatura, solo
## reso più leggibile su carta crema (vedi Critters.colore_pallino).
func kind_color(kind: String) -> Color:
	return CRIT.colore_pallino(kind)


func is_rare(kind: String) -> bool:
	return CRIT.rara(kind)


## Chiamata da Collection.add_catch: premia le stelline sulle catture rare.
## Ritorna quante stelline ha assegnato (0 = cattura comune).
func award_catch(kind: String) -> int:
	if not CRIT.rara(kind):
		return 0
	add_stars(STAR_PER_RARE)
	return STAR_PER_RARE


# ---------------------------------------------------------------- negozio
func is_piece_unlocked(name: String) -> bool:
	return _unlocked_pieces.has(name)


## I pezzi che arrivano INSIEME a un altro. Un posto di guardia non si
## compra a pezzi come si compra una panchina: la guardiola arriva col suo
## corredo — il bancone, l'armadio degli smarriti, la bacheca, il berretto
## appeso — perché è così che arrivano i posti. E il banco del mercante
## resta leggibile invece di riempirsi di tredici voci quasi uguali.
## Le chiavi sono NOMI DI PEZZO: id del catalogo, mai tradurli.
const CORREDO := {
	"Guardiola": ["Insegna guardia", "Sbarra", "Bancone guardia",
			"Armadio smarriti", "Bacheca avvisi", "Attaccapanni", "Brandina",
			"Lanterna blu", "Cono", "Transenna", "Bicicletta",
			"Cassetta smarriti"],
	# IL BAR: si compra il bancone e arriva il bar intero — la macchina del
	# caffè, i tavolini, l'ombrellone, il biliardino. Un punto di ritrovo
	# non si mette su un pezzo alla volta: o c'è, o è una stanza vuota.
	"Bancone bar": ["Tenda bar", "Insegna bar", "Macchina caffè",
			"Vetrina dolci", "Sgabello alto", "Mensola bottiglie",
			"Tavolino bar", "Sedia vimini", "Lavagnetta", "Biliardino",
			"Ombrellone", "Fioriera", "Lucine", "Frigo gelati"],
	# LA PALESTRA: si compra il sacco e arrivano gli attrezzi tutti insieme.
	# Otto voci quasi uguali sul banco del mercante sarebbero un catalogo,
	# non un negozio — e una palestra si mette su tutta in una volta.
	"Sacco": ["Tappetino", "Panca dei pesi", "Cyclette", "Sbarra da trazione",
			"Specchio", "Fontanella", "Rastrelliera",
			"Rastrelliera dischi", "Rastrelliera pietre"],
	"Autopompa": ["Portone rimessa", "Torretta", "Palo pompieri",
			"Scala a pioli", "Insegna caserma", "Campana caserma",
			"Casco appeso", "Stivali", "Secchi", "Idrante", "Manichetta",
			"Faro caserma", "Cuccia", "Pennone"],
	"Campanile": ["Muro di pietra", "Lastricato", "Vetrata", "Banco", "Volta",
			"Sagrato", "Arcata", "Portale", "Frontone", "Abside", "Altare",
			"Candeliere", "Fonte dei nomi", "Armonium"],
	# LA BOUTIQUE: si compra la vetrina e arriva il negozio intero. Un
	# negozio di vestiti con lo stender e senza camerino non è mezzo
	# negozio: è un magazzino.
	# I PALI DEL FESTONE: si compra il palo delle lampadine e arrivano
	# anche quello dei lampioncini e quello delle bandierine. Con una
	# veste sola non si comporrebbe niente: il bello è alternarle.
	"Palo lucine": ["Palo lanterne", "Palo bandierine"],
	"Vetrina moda": ["Insegna boutique", "Manichino", "Busto sartoriale",
			"Stender", "Tavolo piegati", "Scaffale a giorno", "Camerino",
			"Specchiera", "Cassa boutique", "Poltroncina", "Cesto saldi",
			"Faretti", "Passatoia", "Sacchetti"],
}


func unlock_piece(name: String) -> void:
	_unlocked_pieces[name] = true
	for compagno in CORREDO.get(name, []):
		_unlocked_pieces[str(compagno)] = true
	shop_changed.emit()
	_save()


func piece_offer(name: String) -> Dictionary:
	for p in SHOP_PIECES:
		if p["name"] == name:
			return p
	return {}


## Un pezzo di catalogo è "da negozio" (bloccato finché non comprato)?
func is_shop_piece(name: String) -> bool:
	return not piece_offer(name).is_empty()


# ------------------------------------------------- il banco a rotazione

## Pesca il banco di un giorno di visita: 3-4 offerte dal listino, di cui
## una rara e costosa (il "raro del giorno", primo dell'elenco). PURA e
## deterministica dato il seme: testabile a freddo, stabile nel giorno.
static func pesca_stock(disponibili: Array, seed_v: int) -> Array:
	if disponibili.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var rari: Array = []
	var comuni: Array = []
	for p in disponibili:
		if str(p.get("cur", "nut")) == "star" or int(p["cost"]) >= RARO_SOGLIA:
			rari.append(p)
		else:
			comuni.append(p)
	var scelti: Array = []
	if not rari.is_empty():
		scelti.append(rari.pop_at(rng.randi() % rari.size()))
	# 2-3 pezzi di giornata; se i comuni scarseggiano si attinge dai rari
	for i in 2 + int(rng.randi() % 2):
		var pool := comuni if not comuni.is_empty() else rari
		if pool.is_empty():
			break
		scelti.append(pool.pop_at(rng.randi() % pool.size()))
	var nomi: Array = []
	for p in scelti:
		nomi.append(str(p["name"]))
	return nomi


## Il mercante rifà il banco per il giorno di visita: al più una volta per
## giorno (una ricarica nello stesso giorno ritrova lo stesso banco).
func rotate_stock(day: int) -> void:
	if day == stock_day:
		return
	stock_day = day
	var disponibili: Array = []
	for p in SHOP_PIECES:
		if not is_piece_unlocked(str(p["name"])):
			disponibili.append(p)
	stock = pesca_stock(disponibili, day * 2654435761 + 7)
	shop_changed.emit()
	_save()


## Le offerte di oggi ancora da comprare, raro del giorno per primo.
func stock_offers() -> Array:
	var out: Array = []
	for n in stock:
		if is_piece_unlocked(str(n)):
			continue
		var p := piece_offer(str(n))
		if not p.is_empty():
			out.append(p)
	return out


func is_variant_unlocked(vid: String) -> bool:
	return vid == "" or _unlocked_variants.has(vid)


func unlock_variant(vid: String) -> void:
	_unlocked_variants[vid] = true
	shop_changed.emit()
	_save()


## Gli id delle varianti possedute (senza l'originale ""), nell'ordine del catalogo.
func owned_variants() -> Array:
	var out := []
	for v in VARIANTS:
		if _unlocked_variants.has(v["id"]):
			out.append(v["id"])
	return out


static func variant_def(vid: String) -> Dictionary:
	for v in VARIANTS:
		if v["id"] == vid:
			return v
	return {}


static func piece_takes_variant(name: String) -> bool:
	return name in VARIANT_PIECES


## Tinge un mobile (Node3D) con la variante scelta. Tocca SOLO i materiali
## "handpaint" (quelli con color_a/color_b): lampade, vetri, fuoco e braci
## restano intatti. Duplica il materiale, così tinge solo QUESTA istanza.
func apply_variant(root: Node3D, vid: String) -> void:
	if vid == "" or root == null:
		return
	var def := variant_def(vid)
	if def.is_empty():
		return
	var tint: Color = def["tint"]
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mat = (mi as MeshInstance3D).material_override
		if mat is ShaderMaterial:
			var sm := mat as ShaderMaterial
			var a = sm.get_shader_parameter("color_a")
			var b = sm.get_shader_parameter("color_b")
			if a is Color and b is Color:
				var nm := sm.duplicate() as ShaderMaterial
				nm.set_shader_parameter("color_a", (a as Color).lerp(tint, 0.6))
				nm.set_shader_parameter("color_b", (b as Color).lerp(tint.darkened(0.15), 0.62))
				(mi as MeshInstance3D).material_override = nm


# ---------------------------------------------------------------- persistenza
func save_extra() -> Dictionary:
	return {
		"nuts": nuts,
		"stars": stars,
		"shop_pieces": _unlocked_pieces.keys(),
		"shop_variants": _unlocked_variants.keys(),
		"shop_stock": stock.duplicate(),
		"shop_stock_day": stock_day,
	}


func load_extra(data: Dictionary) -> void:
	nuts = int(data.get("nuts", 0))
	stars = int(data.get("stars", 0))
	stock = (data.get("shop_stock", []) as Array).duplicate()
	stock_day = int(data.get("shop_stock_day", -1))
	_unlocked_pieces.clear()
	for n in data.get("shop_pieces", []):
		_unlocked_pieces[str(n)] = true
	_unlocked_variants.clear()
	for v in data.get("shop_variants", []):
		_unlocked_variants[str(v)] = true
	nuts_changed.emit(nuts)
	stars_changed.emit(stars)
	shop_changed.emit()


func _save() -> void:
	# fuori dall'albero (test puri) non c'è niente da salvare — e chiedere
	# get_tree() da fuori stampa un errore d'engine a vuoto
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var bs := tree.get_first_node_in_group("build_system")
	if bs and bs.has_method("request_save"):
		bs.request_save()
