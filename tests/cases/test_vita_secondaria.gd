extends RefCounted
## LA VITA SECONDARIA: fumo dei camini, foglie d'autunno, bucato steso.
## Il villaggio deve respirare anche quando nessuno fa niente — e questi
## test tengono il respiro regolare:
##  1. le finestre orarie sono PURE e coerenti (il fumo è della sera, il
##     bucato del giorno pieno: mai insieme);
##  2. la proprietà di uno stendino la decide la casa più vicina;
##  3. il bucato di Mochi parla il guardaroba (ogni capo ha il suo colore
##     di telo — tabella allineata a Wardrobe.CAPI);
##  4. il telo usa IL TRUCCO DEL VENTO: mesh capovolta (rotation.z = PI)
##     e wind_strength del handpaint — l'orlo sventola, la corda tiene;
##  5. gli asset nuovi si costruiscono (Stendino, comignolo del Camino)
##     e i fili sono attaccati (fumo sopra i tetti, turbolenza, foglie
##     che si fermano sui tetti).

const VS := preload("res://scenes/world/VitaSecondaria.gd")
const CAT := preload("res://scenes/build/BuildCatalog.gd")
const WAR := preload("res://scenes/characters/Wardrobe.gd")
const ECO := preload("res://scenes/ui/Economy.gd")


func run(t) -> void:
	_test_finestre_orarie(t)
	_test_proprieta(t)
	_test_colori_del_bucato(t)
	_test_il_telo_e_il_vento(t)
	_test_asset_nuovi(t)
	_test_fili_attaccati(t)


func _test_finestre_orarie(t) -> void:
	t.ok(VS.ora_del_fumo(0.7, false), "al tramonto il camino fuma")
	t.ok(VS.ora_del_fumo(0.2, true), "e fuma per tutta la notte")
	t.ok(not VS.ora_del_fumo(0.45, false), "a mezzogiorno il comignolo tace")
	t.ok(VS.ora_del_bucato(0.45, false), "di giorno pieno il bucato è steso")
	t.ok(not VS.ora_del_bucato(0.29, false), "all'alba non è ancora steso")
	t.ok(not VS.ora_del_bucato(0.7, false), "prima di sera è già ritirato")
	t.ok(not VS.ora_del_bucato(0.45, true), "mai panni fuori col buio")
	# l'invariante: fumo e bucato dei residenti non convivono mai
	var insieme := false
	for i in 101:
		var tempo := float(i) / 100.0
		if VS.ora_del_fumo(tempo, false) and VS.ora_del_bucato(tempo, false):
			insieme = true
	t.ok(not insieme, "il fumo è della sera, il bucato del giorno: mai insieme")


func _test_proprieta(t) -> void:
	var case := [{"label": "la coniglietta Nocciola", "pos": Vector2(3, 3)},
			{"label": "l'orsetto Miele", "pos": Vector2(-6, 1)}]
	t.eq(VS.di_chi(Vector2(4, 3), case), "la coniglietta Nocciola",
			"lo stendino accanto a una casa è del suo residente")
	t.eq(VS.di_chi(Vector2(-5, 1), case), "l'orsetto Miele",
			"e vince la casa più vicina")
	t.eq(VS.di_chi(Vector2(30, 30), case), "",
			"lontano da tutti, lo stendino è di Mochi")
	t.eq(VS.di_chi(Vector2.ZERO, []), "", "senza residenti è sempre di Mochi")


func _test_colori_del_bucato(t) -> void:
	# ogni capo del guardaroba ha il suo colore di telo: se nasce un capo
	# nuovo senza colore, il bucato non saprebbe raccontarlo
	for id in WAR.CAPI:
		t.ok(VS.COLORE_CAPO.has(id),
				"il capo '%s' ha il suo colore sul filo" % id)
	var tre: Array = VS.colori_bucato(["cappello_petali", "impermeabilino",
			"sciarpina_lana", "cuffietta_neve"])
	t.eq(tre.size(), 3, "al massimo tre teli per volta")
	t.ok(tre[0] == VS.COLORE_CAPO["cappello_petali"],
			"il primo telo è il primo ricordo")
	t.eq(VS.colori_bucato([]).size(), (VS.LINO as Array).size(),
			"guardaroba vuoto: si stende la biancheria di lino")
	t.eq(VS.colori_bucato(["id_inventato"]).size(), (VS.LINO as Array).size(),
			"un id sconosciuto non produce teli fantasma")


func _test_il_telo_e_il_vento(t) -> void:
	var v = VS.new()
	var telo: Node3D = v._telo(Color("d97a6a"), 0.22, 0.4)
	t.ok(telo.get_child_count() >= 3, "il telo ha la stoffa e le due mollette")
	var mi := telo.get_child(0) as MeshInstance3D
	t.ok(mi != null and mi.mesh != null, "la stoffa è una mesh vera")
	# IL TRUCCO: la mesh cresce dalla corda in su e il nodo è capovolto —
	# così è l'orlo a sventolare (il vento del handpaint cresce con y²)
	t.almost(mi.rotation.z, PI, "la stoffa è appesa capovolta (l'orlo sventola)", 0.001)
	var mat := mi.material_override as ShaderMaterial
	t.ok(mat != null and float(mat.get_shader_parameter("wind_strength")) > 0.0,
			"la stoffa ondeggia con lo STESSO vento dell'erba (wind_strength)")
	t.ok(bool(mat.get_shader_parameter("no_snow")),
			"il bucato non si copre di neve: è dei personaggi, non del mondo")
	telo.free()
	v.set_season(2, 0.0, false)
	t.ok(v._autunno, "l'autunno accende le foglie")
	v.set_season(3, 1.0, false)
	t.ok(not v._autunno, "l'inverno le spegne")
	v.free()


func _test_asset_nuovi(t) -> void:
	var stendino: Node3D = CAT._clothesline()
	t.ok(stendino.get_child_count() >= 8,
			"lo stendino ha pali, corda e cestello (%d pezzi)" % stendino.get_child_count())
	stendino.free()
	var camino: Node3D = CAT._fireplace()
	t.ok(camino.get_child_count() > 0, "il camino si costruisce ancora")
	camino.free()
	# il comignolo è nel sorgente del camino (l'attracco del fumo)
	t.ok(_body("res://scenes/build/BuildCatalog.gd", "_fireplace")
			.contains("COMIGNOLO"), "il camino ha il suo comignolo")
	# lo Stendino è merce del mercante (entra nella rotazione del banco)
	var trovato := false
	for p in ECO.SHOP_PIECES:
		if str(p["name"]) == "Stendino":
			trovato = true
	t.ok(trovato, "lo Stendino è sul carretto del mercante")


func _test_fili_attaccati(t) -> void:
	var tscn := _sorgente("res://scenes/levels/MainLevel.tscn")
	t.ok(tscn.contains("VitaSecondaria"),
			"la vita secondaria è un nodo della scena principale")
	t.ok(_body("res://scenes/world/VitaSecondaria.gd", "_rebuild")
			.contains("has_cover"),
			"sotto un tetto il fumo esce SOPRA la casa")
	t.ok(_body("res://scenes/world/VitaSecondaria.gd", "_make_fumo")
			.contains("turbulence_enabled"),
			"il fumo ha il ricciolo vero (turbolenza), non la colonna")
	t.ok(_body("res://scenes/world/VitaSecondaria.gd", "_make_foglie")
			.contains("COLLISION_HIDE"),
			"le foglie si fermano sui tetti, come la pioggia")
	t.ok(_body("res://scenes/world/VitaSecondaria.gd", "_unhandled_input")
			.contains("request_save"),
			"il bucato di Mochi si salva appena steso")


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""


## Il corpo di una funzione: dal suo `func nome(` alla `func` successiva.
func _body(path: String, fn: String) -> String:
	var src := _sorgente(path)
	var start := src.find("func %s(" % fn)
	if start < 0:
		return ""
	var end := src.find("\nfunc ", start + 1)
	return src.substr(start, (end - start) if end > start else -1)
