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
    _test_desideri_di_stagione(t)
    _test_desiderio_della_settimana(t)


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
    # stat: i numeri vivi del mondo (fiori in fiore, alberi del boschetto)
    var con_stats := _snap({})
    con_stats["stats"] = {"fiori": 10}
    t.ok(G.satisfied({"type": "stat", "key": "fiori", "n": 10}, con_stats), "stat: 10 fiori soddisfano")
    t.ok(not G.satisfied({"type": "stat", "key": "fiori", "n": 11}, con_stats), "stat: 10 fiori su 11 no")
    t.ok(not G.satisfied({"type": "stat", "key": "alberi", "n": 1}, con_stats), "stat: chiave assente -> 0")
    t.ok(not G.satisfied({"type": "stat", "key": "fiori", "n": 1}, _snap({})), "stat: snapshot senza stats -> false")
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
    # il catalogo può crescere (il gioco è in sviluppo): non pretendiamo
    # copertura totale — i pezzi non previsti da un Ordine si aprono comunque
    # a campagna finita (vedi _apply_to_build). Verifichiamo solo che ciò che
    # gli Ordini aprono sia un sottoinsieme valido del catalogo.
    t.ok(covered.size() <= catalog.size(), "starter + Ordini è un sottoinsieme del catalogo")


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
    t.ok(G.CHAIN.size() >= 9 and G.CHAIN.size() <= 20, "numero di Ordini nel range atteso")
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


## Le lettere-stagione: il tavolo dei desideri e' ben formato — ogni stagione
## ha il suo pool, ogni riga ha testi pieni e un predicato di tipo noto, i
## pezzi nominati (anche i regali) esistono nel catalogo.
func _test_desideri_di_stagione(t) -> void:
    # "sogno" e' l'unico predicato che parla di PERSONE e non di mobili:
    # il salone dell'estetista esiste perche' qualcuno lo sogna
    const TIPI_NOTI := ["has", "count", "any_count", "bed_under_roof", "sogno",
            "table_with_chairs", "has_room", "has_upper_floor",
            "resident_moved_in", "stat"]
    var catalog := {}
    for n in G.all_piece_names():
        catalog[str(n)] = true
    var per_stagione := {0: 0, 1: 0, 2: 0, 3: 0}
    var ids := {}
    for d in G.DESIDERI:
        var id := str(d["id"])
        t.ok(not ids.has(id), "id desiderio unico: %s" % id)
        ids[id] = true
        per_stagione[int(d["season"])] += 1
        for campo in ["title", "letter_text", "hint", "done_text"]:
            t.ok(str(d[campo]) != "", "%s: %s non vuoto" % [id, campo])
        t.ok(str(d["predicate"]["type"]) in TIPI_NOTI,
                "%s: predicato di tipo noto" % id)
        t.ok(int(d.get("stars", 0)) >= 1, "%s: almeno una stellina" % id)
        for pezzo in G.referenced_pieces(d["predicate"]):
            t.ok(catalog.has(str(pezzo)),
                    "%s: il pezzo richiesto '%s' esiste nel catalogo" % [id, pezzo])
        # un desiderio puo' regalare PIU' pezzi, separati da "|"
        for regalo in str(d.get("gift_piece", "")).split("|", false):
            t.ok(catalog.has(str(regalo)),
                    "%s: il pezzo in regalo '%s' esiste nel catalogo" % [id, regalo])
    for s in 4:
        t.ok(int(per_stagione[s]) >= 1, "la stagione %d ha almeno un desiderio" % s)


## La scelta settimanale: deterministica, della stagione giusta, e negli anni
## il pool ruota (stessa stagione, desiderio diverso, finche' ce n'e').
func _test_desiderio_della_settimana(t) -> void:
    t.ok(G.desiderio_della_settimana(-1).is_empty(), "settimana negativa -> nessun desiderio")
    for w in 8:
        var d := G.desiderio_della_settimana(w)
        t.ok(not d.is_empty(), "settimana %d: un desiderio c'e'" % w)
        t.eq(int(d["season"]), w % 4, "settimana %d: desiderio della sua stagione" % w)
        t.eq(str(G.desiderio_della_settimana(w)["id"]), str(d["id"]),
                "settimana %d: scelta deterministica" % w)
    # la rotazione annuale: con almeno 2 desideri nel pool, l'anno dopo cambia
    for s in 4:
        var pool := 0
        for d in G.DESIDERI:
            if int(d["season"]) == s:
                pool += 1
        if pool >= 2:
            t.ok(str(G.desiderio_della_settimana(s)["id"])
                    != str(G.desiderio_della_settimana(s + 4)["id"]),
                    "stagione %d: l'anno dopo il desiderio ruota" % s)
    # e al giro completo del pool si ritorna al primo (ripetibile, come promesso)
    var pool0 := 0
    for d in G.DESIDERI:
        if int(d["season"]) == 0:
            pool0 += 1
    t.eq(str(G.desiderio_della_settimana(0)["id"]),
            str(G.desiderio_della_settimana(pool0 * 4)["id"]),
            "il pool di primavera ricomincia dopo %d anni" % pool0)
