extends RefCounted
## Test degli Ordini del Gufo (scenes/npc/GufoOrders.gd). Copre il cuore
## PURO — satisfied() — e le invarianti della catena CHAIN (copertura del
## catalogo, nessun riferimento in avanti, primo Ordine e finale). Nessun
## SceneTree: si legge tutto da const e static.

const G := preload("res://scenes/npc/GufoOrders.gd")


func run(t) -> void:
    _test_predicati(t)
    _test_copertura_catena(t)
    _test_nessun_riferimento_in_avanti(t)
    _test_primo_e_finale(t)


func _snap(counts: Dictionary, bed := false, residents := 0) -> Dictionary:
    return {"counts": counts, "bed_under_roof": bed, "residents": residents}


func _test_predicati(t) -> void:
    # has
    t.ok(G.satisfied({"type": "has", "name": "Letto"}, _snap({"Letto": 1})), "has: 1 letto soddisfa")
    t.ok(not G.satisfied({"type": "has", "name": "Letto"}, _snap({})), "has: nessun letto non soddisfa")
    # count
    t.ok(G.satisfied({"type": "count", "name": "Aiuola", "n": 2}, _snap({"Aiuola": 2})), "count>=2 con 2")
    t.ok(not G.satisfied({"type": "count", "name": "Aiuola", "n": 2}, _snap({"Aiuola": 1})), "count>=2 con 1 no")
    # any_count
    t.ok(G.satisfied({"type": "any_count", "names": ["Camino", "Lampada"], "n": 2}, _snap({"Camino": 1, "Lampada": 1})), "any_count somma")
    t.ok(not G.satisfied({"type": "any_count", "names": ["Camino", "Lampada"], "n": 2}, _snap({"Camino": 1})), "any_count insufficiente")
    # bed_under_roof
    t.ok(G.satisfied({"type": "bed_under_roof"}, _snap({}, true)), "bed_under_roof vero")
    t.ok(not G.satisfied({"type": "bed_under_roof"}, _snap({"Letto": 3}, false)), "letto senza tetto no")
    # table_with_chairs
    t.ok(G.satisfied({"type": "table_with_chairs", "chairs": 2}, _snap({"Tavolino": 1, "Sedia": 2})), "tavolo + 2 sedie")
    t.ok(not G.satisfied({"type": "table_with_chairs", "chairs": 2}, _snap({"Sedia": 4})), "sedie senza tavolo no")
    t.ok(not G.satisfied({"type": "table_with_chairs", "chairs": 2}, _snap({"Tavolino": 1, "Sedia": 1})), "1 sola sedia no")
    # has_room
    t.ok(G.satisfied({"type": "has_room"}, _snap({"Muro": 2, "Porta": 1})), "3 pareti con porta")
    t.ok(not G.satisfied({"type": "has_room"}, _snap({"Muro": 3})), "3 muri senza porta no")
    t.ok(not G.satisfied({"type": "has_room"}, _snap({"Muro": 1, "Porta": 1})), "2 pareti totali no")
    # has_upper_floor
    t.ok(G.satisfied({"type": "has_upper_floor"}, _snap({"Solaio": 1})), "solaio -> piano di sopra")
    t.ok(not G.satisfied({"type": "has_upper_floor"}, _snap({"Scala": 2})), "scala senza solaio no")
    # resident_moved_in
    t.ok(G.satisfied({"type": "resident_moved_in", "n": 1}, _snap({}, false, 1)), "1 residente soddisfa")
    t.ok(not G.satisfied({"type": "resident_moved_in", "n": 1}, _snap({}, false, 0)), "0 residenti no")
    # predicato sconosciuto: false, niente crash
    t.ok(not G.satisfied({"type": "boh"}, _snap({})), "predicato sconosciuto -> false")


func _test_copertura_catena(t) -> void:
    var starter := {}
    for n in G.STARTER:
        starter[str(n)] = true
    var catalog := {}
    for n in G.all_piece_names():
        catalog[str(n)] = true
    var seen := {}
    var dups := 0
    var starter_in_unlocks := 0
    var unknown := 0
    for o in G.CHAIN:
        for u in o["unlocks"]:
            var pname := str(u)
            if seen.has(pname):
                dups += 1
            seen[pname] = true
            if starter.has(pname):
                starter_in_unlocks += 1
            if not catalog.has(pname):
                unknown += 1
    t.eq(dups, 0, "nessun pezzo sbloccato due volte")
    t.eq(starter_in_unlocks, 0, "nessun pezzo iniziale tra gli sblocchi")
    t.eq(unknown, 0, "tutti i pezzi sbloccati esistono nel catalogo")
    var covered := starter.duplicate()
    for pname in seen:
        covered[pname] = true
    t.eq(covered.size(), catalog.size(), "starter + Ordini coprono tutto il catalogo")
    t.eq(seen.size(), catalog.size() - starter.size(), "gli Ordini aprono esattamente i non-starter")


func _test_nessun_riferimento_in_avanti(t) -> void:
    var unlocked := {}
    for n in G.STARTER:
        unlocked[str(n)] = true
    var violations := 0
    for o in G.CHAIN:
        for need in G.referenced_pieces(o["predicate"]):
            if not unlocked.has(str(need)):
                violations += 1
        for u in o["unlocks"]:
            unlocked[str(u)] = true
    t.eq(violations, 0, "nessun Ordine chiede un pezzo ancora bloccato")


func _test_primo_e_finale(t) -> void:
    t.ok(G.CHAIN.size() >= 9 and G.CHAIN.size() <= 12, "da 9 a 12 Ordini")
    var starter := {}
    for n in G.STARTER:
        starter[str(n)] = true
    var first_ok := true
    for need in G.referenced_pieces(G.CHAIN[0]["predicate"]):
        if not starter.has(str(need)):
            first_ok = false
    t.ok(first_ok, "il primo Ordine si completa col catalogo iniziale")
    var last: Dictionary = G.CHAIN[G.CHAIN.size() - 1]
    t.ok("Casa albero" in last["unlocks"], "l'ultimo Ordine sblocca la Casa albero")
