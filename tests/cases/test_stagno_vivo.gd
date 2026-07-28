extends RefCounted
## LO STAGNO CHE VIVE. Prima era una lastra: increspato dalla pioggia,
## fermo col sereno. Adesso ha (1) una geometria dove le onde possono
## davvero vivere, (2) uno shader che riflette il MONDO e non solo il
## cielo, (3) la vita di superficie — i pesci che salgono all'alba e al
## tramonto, le libellule che sfiorano.
##
## Le guardie qui sono di tre tipi: la GEOMETRIA (misurata sui vertici
## veri), la LEVATA DEI PESCI (funzione pura, testata a tutte le ore) e
## il CABLAGGIO (che lo stagno usi la mesh nuova, che lo shader resti
## innocuo per le altre due superfici che lo vestono).

const GEO := preload("res://scenes/world/WorldGeo.gd")
const COZY := preload("res://scenes/world/CozyWorld.gd")


func run(t) -> void:
	_test_disco(t)
	_test_levata(t)
	_test_shader(t)
	_test_cablaggio(t)


# ------------------------------------------------------------ geometria

## Il disco d'acqua: una griglia POLARE, non il cappello a ventaglio del
## CylinderMesh (un solo vertice al centro, dove nessuna onda può vivere).
func _test_disco(t) -> void:
	var m: ArrayMesh = GEO.disco_acqua(3.6, 16, 72)
	t.ok(m.get_surface_count() == 1, "il disco è una superficie sola")
	var arr := m.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	t.ok(vs.size() > 3000,
			"la superficie è TASSELLATA: %d vertici (il ventaglio ne aveva 49)"
			% vs.size())

	# il raggio è esatto e nessun vertice esce dal bacino
	var rmax := 0.0
	for v in vs:
		rmax = maxf(rmax, Vector2(v.x, v.z).length())
		t.ok(absf(v.y) < 0.0001, "il disco nasce piatto (l'onda la mette lo shader)")
		if rmax > 3.6001:
			break
	t.almost(rmax, 3.6, "il disco arriva esattamente al raggio chiesto", 0.001)

	# UV.x È il raggio normalizzato: lo shader ci legge la vicinanza a riva
	var errore := 0.0
	for i in vs.size():
		errore = maxf(errore,
				absf(Vector2(vs[i].x, vs[i].z).length() / 3.6 - uvs[i].x))
	t.ok(errore < 0.001,
			"UV.x è il raggio normalizzato (scarto max %.5f)" % errore)

	# gli anelli si INFITTISCONO verso la riva: è lì che lo sguardo è
	# radente e le increspature contano. Con un esponente > 1 sarebbe
	# l'esatto contrario, e non se ne accorgerebbe nessuno.
	var raggi := {}
	for v in vs:
		raggi[snappedf(Vector2(v.x, v.z).length(), 0.0005)] = true
	var lista: Array = raggi.keys()
	lista.sort()
	t.ok(lista.size() >= 16, "ci sono tutti gli anelli (%d)" % lista.size())
	var passo_centro: float = float(lista[1]) - float(lista[0])
	var passo_riva: float = float(lista[-1]) - float(lista[-2])
	t.ok(passo_riva < passo_centro * 0.7,
			"gli anelli si infittiscono verso la riva (%.3f alla riva contro %.3f al centro)"
			% [passo_riva, passo_centro])


# --------------------------------------------------------- la levata

## I pesci salgono all'ALBA e al TRAMONTO, non a mezzogiorno: è vero, ed
## è il dettaglio che il giocatore che pesca impara senza che glielo si
## dica. La funzione è pura, quindi si prova a tutte le ore.
func _test_levata(t) -> void:
	for i in 25:
		var ora := float(i) / 24.0
		var l: float = COZY.levata_dei_pesci(ora)
		t.ok(l >= 0.0 and l <= 1.0, "ora %.2f: la levata resta in [0,1] (%.2f)" % [ora, l])
	var alba: float = COZY.levata_dei_pesci(0.26)
	var sera: float = COZY.levata_dei_pesci(0.74)
	var mezzodi: float = COZY.levata_dei_pesci(0.5)
	var notte: float = COZY.levata_dei_pesci(0.02)
	t.ok(alba > 0.9, "all'alba i pesci salgono (%.2f)" % alba)
	t.ok(sera > 0.9, "al tramonto pure (%.2f)" % sera)
	t.ok(mezzodi < 0.3, "a mezzogiorno stanno sul fondo (%.2f)" % mezzodi)
	t.ok(notte < 0.3, "e di notte fonda quasi (%.2f)" % notte)
	t.ok(mezzodi > 0.0 and notte > 0.0,
			"ma mai fermi del tutto: lo stagno non muore mai")
	# le due punte sono simmetriche di forma: nessuna delle due domina
	t.almost(alba, sera, "alba e tramonto valgono uguale", 0.06)


# ---------------------------------------------------------- lo shader

func _test_shader(t) -> void:
	var src := _sorgente("res://shaders/water.gdshader")
	t.ok(src != "", "water.gdshader si legge")

	# LE DUE NORMALI: il riflesso legge le onde LARGHE, le capillari
	# fanno il luccichio. Su una normale sola cielo e bosco si
	# scambiavano pixel per pixel e l'acqua diventava un mosaico.
	t.ok(src.contains("n_largo") and src.contains("reflect(-VIEW, n_largo)"),
			"il riflesso del mondo legge la normale LARGA, non le capillari")
	# il raggio riflesso distingue cielo e bosco: senza, a mezzogiorno
	# (cielo bianco) il bacino diventava una scodella di latte
	t.ok(src.contains("verso_alto") and src.contains("intorno_col"),
			"lo specchio riflette il cielo IN ALTO e il bosco scuro IN BASSO")
	# il LOD: le capillari si spengono con la distanza, o si impastano
	# in un velo lattiginoso (l'aliasing speculare)
	t.ok(src.contains("length(VERTEX)") and src.contains("vicino"),
			"le increspature fini hanno il LOD sulla distanza")
	# il glitter è riflessione, non vernice: esiste solo di striscio
	t.ok(src.contains("* (0.18 + 0.82 * fres)"),
			"le scintille pesano col fresnel: a piombo l'acqua non brilla")

	# CONVIVENZA: lo shader veste anche il taglio delle ninfee e l'onsen.
	# Ogni manopola nuova deve avere un default che li lascia com'erano.
	for u in ["increspatura", "specchio", "battigia"]:
		t.ok(src.contains("uniform float %s" % u),
				"la manopola '%s' esiste" % u)
	t.ok(src.contains("= 1.0;"), "le manopole nuove hanno un default innocuo")
	var onsen := _sorgente("res://scenes/world/Onsen.gd")
	t.ok(onsen.contains("shallow_col") and onsen.contains("deep_col"),
			"l'onsen riparametrizza ancora lo stesso shader (fonte unica)")


# --------------------------------------------------------- il cablaggio

func _test_cablaggio(t) -> void:
	var src := _sorgente("res://scenes/world/CozyWorld.gd")
	t.ok(src.contains("GEO.disco_acqua(POND_R"),
			"lo stagno monta il disco tassellato, non più il cilindro")
	t.ok(src.contains("var _pond_mat: ShaderMaterial"),
			"il materiale dell'acqua ha un handle (era una variabile locale)")
	t.ok(src.contains("_update_stagno(delta)"),
			"la vita di superficie gira nel _process")

	var vita := _corpo(src, "_update_stagno")
	t.ok(vita.contains("is_raining") and vita.contains("is_snowing"),
			"la vita di superficie è roba da SERENO: pioggia e ghiaccio la spengono")
	t.ok(vita.contains("levata_dei_pesci"),
			"le bolle seguono la levata (alba e tramonto)")
	t.ok(vita.contains("water_ripple"),
			"gli anelli sono quelli di sempre: rane, pesca e pesci parlano la stessa lingua")
	t.ok(vita.contains("_lilies"),
			"i pesci salgono dove mangiano: accanto alle ninfee")


func _corpo(src: String, nome: String) -> String:
	var da := src.find("func " + nome)
	if da < 0:
		return ""
	var fine := src.find("\nfunc ", da + 1)
	return src.substr(da, (fine - da) if fine > da else -1)


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""
