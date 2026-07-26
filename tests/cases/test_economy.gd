extends RefCounted
## Test dell'economia del villaggio (scenes/ui/Economy.gd): le due valute
## (noccioline 🌰 e stelline ⭐), le catture che fruttano stelle, gli sblocchi
## del negozio del mercante, il roundtrip di salvataggio e la tinta delle
## varianti sui materiali handpaint.
## Economy è un nodo: va messo in scena con t.stage() perché _ready scatti.
## (Era tests/eco_smoke.gd, script sciolto fuori dalla suite.)

const ECONOMY := "res://scenes/ui/Economy.gd"


func run(t) -> void:
	var eco: GDScript = load(ECONOMY)
	if eco == null or not eco.can_instantiate():
		t.ok(false, "Economy.gd non compilabile")
		return
	_test_valute(t, eco)
	_test_catture(t, eco)
	_test_sblocchi(t, eco)
	_test_roundtrip(t, eco)
	_test_varianti(t, eco)


# le due valute: entrate, spese e spese impossibili
func _test_valute(t, eco: GDScript) -> void:
	var e = t.stage(eco.new())
	e.add_nuts(50)
	e.add_stars(3)
	t.eq(e.nuts, 50, "add_nuts accredita le noccioline")
	t.eq(e.stars, 3, "add_stars accredita le stelline")
	t.ok(e.spend(20, "nut"), "spend: 20 noccioline su 50 riesce")
	t.eq(e.nuts, 30, "dopo la spesa restano 30 noccioline")
	t.ok(not e.spend(999, "star"), "spend: stelline insufficienti -> rifiutata")


# solo le catture RARE fruttano una stellina; le comuni no
func _test_catture(t, eco: GDScript) -> void:
	var e = t.stage(eco.new())
	var s0: int = e.stars
	e.award_catch("rosina")
	t.eq(e.stars, s0 + 1, "una cattura rara vale una stellina")
	e.award_catch("rosa")
	t.eq(e.stars, s0 + 1, "una cattura comune non dà stelline")
	t.eq(e.sell_value("gialla"), 14, "valore di vendita della gialla")


# il negozio: pezzi e varianti si sbloccano e restano sbloccati
func _test_sblocchi(t, eco: GDScript) -> void:
	var e = t.stage(eco.new())
	e.unlock_piece("Fontana")
	t.ok(e.is_piece_unlocked("Fontana"), "il pezzo comprato risulta sbloccato")
	t.ok(e.is_shop_piece("Fontana"), "la Fontana è merce da negozio")
	t.ok(not e.is_shop_piece("Sedia"), "la Sedia non è merce da negozio")
	e.unlock_variant("menta")
	t.ok(e.is_variant_unlocked("menta"), "la variante comprata è sbloccata")
	t.ok(e.is_variant_unlocked(""), "la tinta originale è sempre disponibile")
	t.ok(e.piece_takes_variant("Sedia"), "la Sedia accetta le varianti")
	t.ok(not e.piece_takes_variant("Muro"), "il Muro non accetta varianti")


# salvataggio e ricarica: valute e sblocchi sopravvivono al JSON
func _test_roundtrip(t, eco: GDScript) -> void:
	var e = t.stage(eco.new())
	e.add_nuts(50)
	e.add_stars(3)
	e.unlock_piece("Fontana")
	e.unlock_variant("menta")
	var data: Dictionary = e.save_extra()
	var e2 = t.stage(eco.new())
	e2.load_extra(data)
	t.eq(e2.nuts, e.nuts, "roundtrip: noccioline preservate")
	t.eq(e2.stars, e.stars, "roundtrip: stelline preservate")
	t.ok(e2.is_piece_unlocked("Fontana"), "roundtrip: pezzo ancora sbloccato")
	t.ok(e2.is_variant_unlocked("menta"), "roundtrip: variante ancora sbloccata")


# apply_variant deve davvero ritingere il materiale handpaint del pezzo
func _test_varianti(t, eco: GDScript) -> void:
	var e = t.stage(eco.new())
	var base := Color("c89a6b")
	var mi := MeshInstance3D.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/handpaint.gdshader")
	sm.set_shader_parameter("color_a", base)
	sm.set_shader_parameter("color_b", Color("a87c50"))
	mi.material_override = sm
	var root := Node3D.new()
	root.add_child(mi)
	e.apply_variant(root, "menta")
	var ca = (mi.material_override as ShaderMaterial).get_shader_parameter("color_a")
	t.ok(ca is Color and ca != base, "apply_variant tinge il materiale handpaint")
	root.free()
