## Test per le Tasche (scenes/ui/Inventory.gd): impilamento dei piatti,
## tesori, etichette di gusto, affinità (adora vs gradisce) e round-trip di
## salvataggio. I preload in testa fanno anche da parse-gate: se Inventory,
## Pockets o PocketIcon non compilano, questo caso non si istanzia e il runner
## lo segnala.
##
## Inventory è un Node: lo si crea con .new() SENZA aggiungerlo all'albero
## (così _ready non parte) e si chiama .free() alla fine.

const INV := preload("res://scenes/ui/Inventory.gd")
const POCKETS := preload("res://scenes/ui/Pockets.gd")
const POCKET_ICON := preload("res://scenes/ui/PocketIcon.gd")


func run(t) -> void:
	_test_parse_gate(t)
	_test_dish_tags(t)
	_test_dish_stacking(t)
	_test_treasures(t)
	_test_random_gift(t)
	_test_affinity(t)
	_test_save_roundtrip(t)


func _test_parse_gate(t) -> void:
	# se siamo qui, i tre script hanno compilato. Un'icona è un Control vero.
	var ic = POCKET_ICON.new()
	t.ok(ic is Control, "PocketIcon è un Control")
	ic.free()
	t.ok(POCKETS != null, "Pockets.gd compila")


func _test_dish_tags(t) -> void:
	t.eq(INV.dish_tags(true, {}), ["caldo"], "piatto caldo senza ingredienti -> [caldo]")
	t.eq(INV.dish_tags(false, {}), ["fresco"], "piatto freddo senza ingredienti -> [fresco]")
	var berry := INV.dish_tags(true, {"bacca": 3})
	t.ok("caldo" in berry and "dolce" in berry, "caldo + bacca -> caldo, dolce")
	var risotto := INV.dish_tags(false, {"fungo": 2})
	t.ok("fresco" in risotto and "terroso" in risotto, "freddo + fungo -> fresco, terroso")


func _test_dish_stacking(t) -> void:
	var inv = INV.new()
	t.ok(not inv.has_dish(), "nuova dispensa: nessun piatto")
	var zuppa := {"id": "zuppa", "name": "Zuppa", "art": "la", "warm": true,
			"tags": ["caldo"], "icon": "zuppa"}
	inv.add_dish(zuppa)
	inv.add_dish(zuppa)
	inv.add_dish({"id": "te", "name": "Tè", "art": "il", "warm": false,
			"tags": ["fresco"], "icon": "te"})
	t.ok(inv.has_dish(), "dopo add_dish: has_dish")
	var grouped: Array = inv.dishes_grouped()
	t.eq(grouped.size(), 2, "due id distinti -> due voci raggruppate")
	var zc := 0
	for g in grouped:
		if g["id"] == "zuppa":
			zc = int(g["count"])
	t.eq(zc, 2, "la zuppa si impila a quota 2")
	var taken: Dictionary = inv.take_dish("zuppa")
	t.eq(str(taken.get("id", "")), "zuppa", "take_dish restituisce la voce giusta")
	t.eq(str(taken.get("kind", "")), "dish", "take_dish marca kind=dish (offer_item se ne serve)")
	t.eq(inv.dishes.size(), 2, "dopo take_dish restano 2 piatti (1 zuppa + 1 tè)")
	t.ok(inv.take_dish("inesistente").is_empty(), "take_dish di id assente -> {}")
	inv.free()


func _test_treasures(t) -> void:
	var inv = INV.new()
	t.ok(inv.add_treasure("piuma", 2).size() > 0, "add_treasure noto -> scheda")
	t.ok(inv.add_treasure("id_ignoto").is_empty(), "add_treasure ignoto -> {}")
	t.eq(int(inv.treasures.get("piuma", 0)), 2, "quantità piuma == 2")
	var lst: Array = inv.treasure_list()
	t.eq(lst.size(), 1, "un solo tesoro posseduto")
	t.eq(str(lst[0]["kind"]), "treasure", "voce tesoro etichettata kind=treasure")
	# take_gift (via la voce di vetrina) consuma e conserva il kind del tesoro
	var got: Dictionary = inv.take_gift(lst[0])
	t.eq(str(got.get("kind", "")), "treasure", "take_gift conserva kind=treasure (niente ciotola per un dono)")
	t.eq(int(inv.treasures.get("piuma", 0)), 1, "take_treasure scala a 1")
	inv.take_treasure("piuma")
	t.ok(not inv.treasures.has("piuma"), "a 0 il tesoro si rimuove")
	t.ok(inv.take_treasure("piuma").is_empty(), "take_treasure vuoto -> {}")
	inv.free()


func _test_random_gift(t) -> void:
	var inv = INV.new()
	var s: Dictionary = inv.add_random_gift("riccio", 0)
	t.ok(str(s.get("id", "")) in INV.RICCIO_GIFTS, "dono del riccio è dei suoi")
	t.eq(int(inv.treasures.get(s["id"], 0)), 1, "il dono entra tra i tesori")
	t.ok(inv.add_random_gift("gatto", 0).is_empty(), "specie senza doni -> {}")
	inv.free()


func _test_affinity(t) -> void:
	var inv = INV.new()
	var cozy_lover := {"warmth": 1.6, "garden": 0.6, "comfort": 1.0}
	var green_lover := {"warmth": 0.5, "garden": 1.8, "comfort": 0.5}
	t.eq(inv.affinity(["caldo"], cozy_lover), INV.REACT_LOVES, "amante del caldo adora il caldo")
	t.eq(inv.affinity(["fresco", "orto"], cozy_lover), INV.REACT_LIKES, "amante del caldo gradisce il fresco")
	t.eq(inv.affinity(["fresco"], green_lover), INV.REACT_LOVES, "amante dell'orto adora il fresco")
	t.eq(inv.affinity(["caldo"], green_lover), INV.REACT_LIKES, "amante dell'orto gradisce il caldo")
	t.eq(inv.affinity([], cozy_lover), INV.REACT_LOVES, "un dono senza profilo piace a tutti")
	t.eq(inv.affinity(["caldo", "fresco"], green_lover), INV.REACT_LOVES, "un dono in equilibrio piace a tutti")
	inv.free()


func _test_save_roundtrip(t) -> void:
	var a = INV.new()
	t.ok(a.save_extra().is_empty(), "dispensa vuota -> save_extra {}")
	a.add_dish({"id": "zuppa", "name": "Zuppa", "art": "la", "warm": true,
			"tags": ["caldo"], "icon": "zuppa"})
	a.add_treasure("fiocco_lana", 3)
	var data: Dictionary = a.save_extra()
	var b = INV.new()
	b.load_extra(data)
	t.eq(b.dishes.size(), 1, "load: un piatto ripristinato")
	t.eq(int(b.treasures.get("fiocco_lana", 0)), 3, "load: 3 fiocchi ripristinati")
	# id di tesoro sconosciuto ignorato in load (robustezza)
	b.load_extra({"inv_treasures": {"non_esiste": 5}})
	t.ok(not b.treasures.has("non_esiste"), "load ignora tesori sconosciuti")
	a.free()
	b.free()
