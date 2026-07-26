extends RefCounted
## I luccichii del mattino (Scavi: punti del giorno e trovamenti).
##
## I punti sono deterministici nel giorno (il salvataggio ricorda solo
## cosa è già stato scavato) e devono nascere nel prato, fuori dagli
## ostacoli e distanziati. I trovamenti sono deterministici anche loro:
## ricaricare il salvataggio non cambia il tesoro sotto terra.

const SCAVI := preload("res://scenes/interact/Scavi.gd")
const CRIT := preload("res://scenes/world/Critters.gd")
const INV := preload("res://scenes/ui/Inventory.gd")

# gli ostacoli finti per le prove: lo stagno e un masso, come li darebbe
# CozyWorld.obstacle_circles() — [Vector3(x, raggio, z)]
const OSTACOLI := [Vector3(9.5, 5.2, -10.5), Vector3(-4.0, 2.0, -2.0)]


func run(t) -> void:
    _test_punti(t)
    _test_determinismo(t)
    _test_trovamenti(t)


func _test_punti(t) -> void:
    for giorno in [1, 7, 23, 100]:
        var punti: Array = SCAVI.punti_del_giorno(giorno, OSTACOLI)
        t.ok(punti.size() >= 2 and punti.size() <= 3,
                "giorno %d: due o tre luccichii" % giorno)
        for i in punti.size():
            var p: Vector3 = punti[i]
            t.ok(SCAVI.RECT.has_point(Vector2(p.x, p.z)),
                    "giorno %d punto %d: dentro il prato" % [giorno, i])
            t.ok(SCAVI.punto_libero(p, OSTACOLI),
                    "giorno %d punto %d: fuori dagli ostacoli" % [giorno, i])
            for j in range(i + 1, punti.size()):
                t.ok(p.distance_to(punti[j]) >= SCAVI.DIST_MIN,
                        "giorno %d: i punti %d e %d non si ammucchiano" % [giorno, i, j])


func _test_determinismo(t) -> void:
    # stesso giorno -> stessi punti (il salvataggio può essere leggero)
    var a: Array = SCAVI.punti_del_giorno(42, OSTACOLI)
    var b: Array = SCAVI.punti_del_giorno(42, OSTACOLI)
    t.eq(a.size(), b.size(), "stesso giorno: stesso numero di punti")
    for i in a.size():
        t.almost((a[i] as Vector3).distance_to(b[i] as Vector3), 0.0,
                "stesso giorno: il punto %d non si muove" % i)
    # giorni diversi -> punti diversi (il prato non si ripete)
    var c: Array = SCAVI.punti_del_giorno(43, OSTACOLI)
    var uguali := true
    for i in mini(a.size(), c.size()):
        if (a[i] as Vector3).distance_to(c[i] as Vector3) > 0.01:
            uguali = false
    t.ok(not uguali, "giorno nuovo: luccichii altrove")
    # punto_libero: dentro lo stagno è occupato, in mezzo al prato no
    t.ok(not SCAVI.punto_libero(Vector3(9.5, 0, -10.5), OSTACOLI), "lo stagno è occupato")
    t.ok(SCAVI.punto_libero(Vector3(-10.0, 0, 5.0), OSTACOLI), "il prato aperto è libero")


func _test_trovamenti(t) -> void:
    var tipi_validi := ["noccioline", "ingrediente", "tesoro", "stellina"]
    var visti := {}
    for giorno in range(1, 30):
        for indice in 3:
            var dono: Dictionary = SCAVI.trovamento(giorno, indice)
            var tipo := str(dono.get("tipo", ""))
            t.ok(tipo in tipi_validi, "g%d i%d: tipo valido" % [giorno, indice])
            visti[tipo] = true
            if tipo == "noccioline":
                t.ok(int(dono["n"]) >= 8 and int(dono["n"]) <= 20,
                        "g%d i%d: noccioline nel range" % [giorno, indice])
            elif tipo == "ingrediente":
                t.ok(CRIT.esiste(str(dono["id"])),
                        "g%d i%d: l'ingrediente esiste nel bestiario" % [giorno, indice])
            elif tipo == "tesoro":
                t.ok(INV.TREASURES.has(str(dono["id"])),
                        "g%d i%d: il tesoro esiste nella tabella" % [giorno, indice])
    # su 87 scavi la fortuna gira: devono uscire tutti i tipi
    for tipo in tipi_validi:
        t.ok(visti.has(tipo), "in un mese di scavi esce anche: %s" % tipo)
    # deterministico: ricaricare non cambia il tesoro
    var x: Dictionary = SCAVI.trovamento(9, 1)
    var y: Dictionary = SCAVI.trovamento(9, 1)
    t.eq(str(x["tipo"]), str(y["tipo"]), "stesso giorno e punto: stesso trovamento")
