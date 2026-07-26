extends RefCounted
## I messaggi in bottiglia (Bottiglie: cadenza, rotazione lettere, doni).
##
## Le decisioni sono funzioni pure: qui si prova che la cadenza rispetti
## i due giorni di distanza, che le lettere non si ripetano finché il giro
## non si chiude, e che ogni dono sia di un tipo che il gioco sa consegnare
## (inclusa la conchiglia: se sparisse dalla tabella dei tesori, il dono
## diventerebbe un nulla silenzioso).

const BOTT := preload("res://scenes/interact/Bottiglie.gd")
const INV := preload("res://scenes/ui/Inventory.gd")


func run(t) -> void:
    _test_lettere(t)
    _test_cadenza(t)
    _test_rotazione(t)
    _test_doni(t)
    _test_geografia(t)


func _test_lettere(t) -> void:
    t.ok(BOTT.LETTERE.size() >= 8, "almeno otto mittenti di là dalla cascata")
    for i in BOTT.LETTERE.size():
        var l: Dictionary = BOTT.LETTERE[i]
        t.ok(str(l.get("da", "")) != "", "lettera %d: ha il mittente" % i)
        t.ok(str(l.get("testo", "")).length() > 20, "lettera %d: ha un testo vero" % i)


func _test_cadenza(t) -> void:
    # mai con una bottiglia già in acqua
    t.ok(not BOTT.decide_spawn(10, 5, true, 0.0), "bottiglia attiva -> mai una seconda")
    # mai prima di due giorni dall'ultima
    t.ok(not BOTT.decide_spawn(10, 9, false, 0.0), "ieri una bottiglia -> oggi no")
    t.ok(BOTT.decide_spawn(10, 8, false, 0.0), "due giorni dopo -> si può")
    # e comunque non è garantita: la sorte decide
    t.ok(not BOTT.decide_spawn(10, 1, false, 0.99), "sorte avversa -> niente bottiglia")
    t.ok(BOTT.decide_spawn(10, 1, false, 0.1), "sorte amica -> bottiglia")


func _test_rotazione(t) -> void:
    # mai due volte la stessa lettera finché il giro non si chiude
    var lette: Array = []
    for giro in BOTT.LETTERE.size():
        var i: int = BOTT.scegli_lettera(lette, 0.37)
        t.ok(not (i in lette), "estrazione %d: lettera mai letta" % giro)
        t.ok(i >= 0 and i < BOTT.LETTERE.size(), "estrazione %d: indice valido" % giro)
        lette.append(i)
    # giro chiuso: si ricomincia senza incastrarsi
    var dopo: int = BOTT.scegli_lettera(lette, 0.5)
    t.ok(dopo >= 0 and dopo < BOTT.LETTERE.size(), "giro chiuso -> si riparte")
    # il caso agli estremi non sfora mai
    t.ok(BOTT.scegli_lettera([], 0.0) == 0, "caso 0 -> la prima")
    var ultimo: int = BOTT.scegli_lettera([], 0.999999)
    t.eq(ultimo, BOTT.LETTERE.size() - 1, "caso ~1 -> l'ultima")


func _test_doni(t) -> void:
    var tipi_validi := ["noccioline", "ingredienti", "tesoro", "stellina"]
    for k in 40:
        var dono: Dictionary = BOTT.contenuto(float(k) / 40.0)
        t.ok(str(dono.get("tipo", "")) in tipi_validi, "caso %d: tipo di dono valido" % k)
        if str(dono["tipo"]) == "noccioline":
            var n := int(dono["n"])
            t.ok(n >= 10 and n <= 24, "caso %d: noccioline nel range" % k)
        elif str(dono["tipo"]) == "tesoro":
            # il filo col vero inventario: l'id deve esistere nella tabella
            t.ok(INV.TREASURES.has(str(dono["id"])),
                    "caso %d: il tesoro esiste nella tabella dei tesori" % k)
    # gli estremi della distribuzione
    t.eq(str(BOTT.contenuto(0.0)["tipo"]), "noccioline", "caso 0 -> noccioline")
    t.eq(str(BOTT.contenuto(0.95)["tipo"]), "stellina", "caso alto -> stellina")


func _test_geografia(t) -> void:
    # la deriva parte a valle della cascata e finisce prima del bordo del
    # mondo (il fiume vive tra z -56 e +56, vedi CozyWorld)
    t.ok(BOTT.SPAWN_Z > -4.0, "si entra in scena a valle della cascata")
    t.ok(BOTT.FINE_Z < 56.0, "si esce prima del bordo del mondo")
    t.ok(BOTT.VELOCITA > 0.0, "la corrente porta a valle (verso sud)")
    # la finestra per accorgersene è generosa: piu' di un minuto e mezzo
    t.ok((BOTT.FINE_Z - BOTT.SPAWN_Z) / BOTT.VELOCITA > 90.0,
            "almeno un minuto e mezzo per notarla")
