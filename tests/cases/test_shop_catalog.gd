extends RefCounted
## Il collegamento negozio <-> catalogo di costruzione.
##
## Nel villaggio ci sono DUE lucchetti diversi, e non vanno confusi:
##   · gli Ordini del Gufo regalano pezzi vivendo la storia (restano un "?"
##     finché non arrivano: la rivelazione è il premio);
##   · il mercante VENDE i suoi otto pezzi, e quelli non arrivano mai da un
##     Ordine.
## Il catalogo mostrava "?" con la didascalia «Un Ordine del Gufo lo porterà»
## anche per la merce: una promessa che per quei pezzi non si sarebbe mai
## avverata. Qui si blocca l'invariante che rendeva possibile quella bugia.
##
## Tutto puro: const, static e istanze fuori dall'albero. Nessun SceneTree.

const ECO := preload("res://scenes/ui/Economy.gd")
const G := preload("res://scenes/npc/GufoOrders.gd")


func run(t) -> void:
	_test_offerte_sane(t)
	_test_pezzi_esistono(t)
	_test_lucchetti_disgiunti(t)
	_test_riconoscimento(t)


func _test_offerte_sane(t) -> void:
	t.ok(ECO.SHOP_PIECES.size() > 0, "il mercante ha qualcosa in vendita")
	for p in ECO.SHOP_PIECES:
		var n := str(p.get("name", ""))
		t.ok(n != "", "ogni offerta ha un nome")
		t.ok(int(p.get("cost", 0)) > 0, "%s: costa qualcosa" % n)
		t.ok(str(p.get("cur", "")) in ["nut", "star"], "%s: valuta nota (nut/star)" % n)
		# la vetrina del catalogo ci scrive la didascalia: senza, il tooltip
		# resterebbe monco proprio dove prima mentiva
		t.ok(str(p.get("desc", "")) != "", "%s: ha una descrizione da mostrare" % n)


func _test_pezzi_esistono(t) -> void:
	var catalog := {}
	for n in G.all_piece_names():
		catalog[str(n)] = true
	for p in ECO.SHOP_PIECES:
		var n := str(p["name"])
		t.ok(catalog.has(n), "%s esiste davvero nel catalogo di costruzione" % n)


func _test_lucchetti_disgiunti(t) -> void:
	# L'INVARIANTE: un pezzo da negozio non può essere né iniziale né promesso
	# da un Ordine. Se lo fosse, il Gufo prometterebbe qualcosa che resta
	# comunque dietro al lucchetto del mercante (is_unlocked lo tiene chiuso
	# finché non è comprato) — e il giocatore aspetterebbe per sempre.
	var shop := {}
	for p in ECO.SHOP_PIECES:
		shop[str(p["name"])] = true

	var in_starter := 0
	for n in G.STARTER:
		if shop.has(str(n)):
			in_starter += 1
	t.eq(in_starter, 0, "nessun pezzo da negozio tra quelli iniziali")

	var in_orders := 0
	for o in G.CHAIN:
		for u in o["unlocks"]:
			if shop.has(str(u)):
				in_orders += 1
	t.eq(in_orders, 0, "nessun pezzo da negozio promesso da un Ordine del Gufo")


func _test_riconoscimento(t) -> void:
	# Economy è un Node: si crea fuori dall'albero (niente _ready) e si libera.
	var eco = ECO.new()
	for p in ECO.SHOP_PIECES:
		var n := str(p["name"])
		t.ok(eco.is_shop_piece(n), "%s è riconosciuto come merce del mercante" % n)
		t.eq(int(eco.piece_offer(n).get("cost", -1)), int(p["cost"]),
				"%s: l'offerta si ritrova col suo prezzo" % n)
		t.ok(not eco.is_piece_unlocked(n), "%s parte bloccato: si compra" % n)
	# un pezzo normale non è merce (e il catalogo non gli mette il prezzo)
	t.ok(not eco.is_shop_piece("Panchina"), "un pezzo da Ordine non è merce")
	t.ok(eco.piece_offer("Panchina").is_empty(), "nessuna offerta per un pezzo da Ordine")
	eco.free()
