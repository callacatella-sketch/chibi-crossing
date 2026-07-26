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
	{"name": "Fontana", "cost": 150, "cur": "nut", "cat": 2,
		"desc": "Una fontanella tonda con lo zampillo che canta."},
	{"name": "Gazebo", "cost": 240, "cur": "nut", "cat": 0,
		"desc": "Un gazebo esagonale col tetto a pagoda: il salotto all'aperto."},
	{"name": "Giostrina", "cost": 6, "cur": "star", "cat": 2,
		"desc": "Una piccola giostra a cavallucci. Gira piano, come un carillon."},
	{"name": "Braciere stellato", "cost": 4, "cur": "star", "cat": 1,
		"desc": "Un braciere che sputa scintille dorate nella notte."},
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
	"Libreria", "Lampada", "Tappeto", "Pianta", "Cespuglio", "Amaca",
]

var nuts := 0
var stars := 0
var _unlocked_pieces := {}     # {piece_name: true}
var _unlocked_variants := {}   # {variant_id: true}


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


func unlock_piece(name: String) -> void:
	_unlocked_pieces[name] = true
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
	}


func load_extra(data: Dictionary) -> void:
	nuts = int(data.get("nuts", 0))
	stars = int(data.get("stars", 0))
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
	var tree := get_tree()
	if tree == null:
		return
	var bs := tree.get_first_node_in_group("build_system")
	if bs and bs.has_method("request_save"):
		bs.request_save()
