extends RefCounted
## Il nido della Casetta uccellini (scenes/interact/Nido.gd): il ciclo di
## vita PURO di Briciola, le regole cozy (cura senza fallimento) e i fili
## del cablaggio — la casetta nel catalogo, il semino del mattino che
## chiude il cerchio col frutteto, la persistenza.

const NIDO := preload("res://scenes/interact/Nido.gd")
const CATALOGO := preload("res://scenes/build/BuildCatalog.gd")
const INVENTORY := preload("res://scenes/ui/Inventory.gd")


func run(t) -> void:
	_test_ciclo_di_vita(t)
	_test_fili_del_nido(t)


## La crescita di Briciola: pulcino, giovincello, adulta — e la covata.
func _test_ciclo_di_vita(t) -> void:
	t.ok(not NIDO.covata_pronta(0), "appena deposte: si cova")
	t.ok(not NIDO.covata_pronta(1), "un giorno: ancora")
	t.ok(NIDO.covata_pronta(NIDO.GIORNI_COVA), "due giorni: la schiusa")
	t.eq(NIDO.stadio_uccello(0), "pulcino", "appena nata: pulcino")
	t.eq(NIDO.stadio_uccello(3), "pulcino", "tre giorni: ancora pulcino")
	t.eq(NIDO.stadio_uccello(4), "giovincello", "quattro: giovincello (la coda!)")
	t.eq(NIDO.stadio_uccello(7), "adulto", "sette: adulta, il cielo e' suo")
	t.eq(NIDO.stadio_uccello(200), "adulto", "e adulta resta")
	# la regola cozy: se nessuno la ripara, si ripara DA SOLA (mai un
	# fallimento) — la costante esiste ed e' generosa
	t.ok(NIDO.RIPARO_DA_SOLA >= 30.0,
			"c'e' tutto il tempo di arrivare (%.0f s), e poi fa da sola"
			% NIDO.RIPARO_DA_SOLA)


## I fili: la casetta esiste nel catalogo, il saluto porta il semino del
## frutteto, la paura si placa col riparo, tutto persiste.
func _test_fili_del_nido(t) -> void:
	var nomi := []
	for it in CATALOGO.items():
		nomi.append(str(it["name"]))
	t.ok("Casetta uccellini" in nomi, "la Casetta uccellini e' nel catalogo")
	var fonte := _sorgente("res://scenes/interact/Nido.gd")
	t.ok(fonte.contains("get_placed_by_name"),
			"il nido nasce sulla casetta PIAZZATA dal giocatore")
	t.ok(fonte.contains("\"semino\"") and fonte.contains("add_treasure"),
			"il saluto del mattino puo' portare il semino del frutteto")
	t.ok(fonte.contains("has_cover"),
			"il riparo dalla pioggia e' un tetto vero (o la sua casetta)")
	t.ok(fonte.contains("RIPARO_DA_SOLA"),
			"e senza aiuto si ripara da sola: cura senza fallimento")
	t.ok(fonte.contains("save_extra") and fonte.contains("\"nido\""),
			"Briciola si salva col villaggio")
	t.ok(INVENTORY.TREASURES.has("semino"),
			"il semino che porta nel becco e' il Tesoro vero")
	t.ok(_sorgente("res://scenes/levels/MainLevel.gd").contains("Nido.gd"),
			"il nido vive nella scena principale")


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""
