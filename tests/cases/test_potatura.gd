extends RefCounted
## LA POTATURA GENTILE del Filo Rosso (Legami: intoccabile/buco/costo/pota).
##
## Il difetto che questo test difende è di quelli che non si vedono mai
## giocando: il filo teneva 30 momenti e quando sforava faceva pop_front(),
## cioè buttava il PIÙ VECCHIO — «il primo benvenuto sulla soglia» e «il
## giorno della valigia». Esattamente i due che, cento giorni dopo, il
## congedo vuole citare: `Congedo._riaffiora()` campiona i momenti lungo
## TUTTO l'arco della vita per raccontarla dal principio. Con la coda
## tagliata, il principio diventava il trentesimo momento dal fondo.
##
## Qui si vive una vita intera in mezzo secondo, headless, e si controlla
## che alla fine la storia abbia ancora un inizio.

const LEG := preload("res://scenes/world/Legami.gd")


func run(t) -> void:
    _test_gli_intoccabili(t)
    _test_il_buco(t)
    _test_il_costo(t)
    _test_chi_si_sacrifica(t)
    _test_una_vita_intera(t)
    _test_i_casi_limite(t)
    _test_il_conto_non_si_pota(t)


# --------------------------------------------------------- gli intoccabili

func _test_gli_intoccabili(t) -> void:
    var m := _filo([
        [1, "benvenuto"], [2, "trasloco"], [3, "primo_saluto"],
        [10, "piatto"], [11, "piatto"], [12, "piatto"], [13, "piatto"],
        [40, "onsen"], [41, "piatto"], [42, "festa"],
    ])
    # i capi del filo non si toccano mai
    for i in LEG.CAPI_TESTA:
        t.ok(LEG.intoccabile(m, i), "il momento %d è in testa: intoccabile" % i)
    for i in range(m.size() - LEG.CAPI_CODA, m.size()):
        t.ok(LEG.intoccabile(m, i), "il momento %d è in coda: intoccabile" % i)
    # il PRIMO piatto (indice 3) è un primato: si tiene
    t.ok(LEG.intoccabile(m, 3), "il primo piatto è un primato")
    # le repliche in mezzo (4, 5) si possono sacrificare
    t.ok(not LEG.intoccabile(m, 4), "il secondo piatto è una replica")
    t.ok(not LEG.intoccabile(m, 5), "e il terzo pure")
    # fuori dai bordi: mai toccare
    t.ok(LEG.intoccabile(m, -1), "indice negativo: intoccabile")
    t.ok(LEG.intoccabile(m, 999), "indice oltre la fine: intoccabile")

    # e i TIPI capo restano salvi anche in mezzo a un filo lunghissimo
    var lungo := _filo_lungo(200)
    lungo[80] = {"d": 300, "t": "oro", "x": ""}
    lungo[81] = {"d": 301, "t": "addio", "x": ""}
    lungo[82] = {"d": 302, "t": "partenza", "x": ""}
    for i in [80, 81, 82]:
        t.ok(LEG.intoccabile(lungo, i),
                "'%s' non si pota mai" % str(lungo[i]["t"]))
    for tipo in LEG.INTOCCABILI:
        t.ok(LEG.TIPI.has(tipo), "l'intoccabile '%s' è un tipo vero" % tipo)


# ------------------------------------------------------------------ il buco

func _test_il_buco(t) -> void:
    var m := _filo([[1, "a"], [10, "a"], [11, "a"], [40, "a"]])
    # togliere il momento 1 (giorno 10) apre un buco di 10 giorni (1 -> 11)
    t.eq(LEG.buco(m, 1), 10, "il buco è la distanza fra i due vicini")
    # togliere il momento 2 (giorno 11) apre un buco di 30 (10 -> 40)
    t.eq(LEG.buco(m, 2), 30, "un momento isolato porta via più storia")
    # ai capi non c'è buco da misurare
    t.eq(LEG.buco(m, 0), 0, "in testa nessun buco")
    t.eq(LEG.buco(m, m.size() - 1), 0, "in coda nessun buco")
    # date in disordine (un salvataggio storto): mai un costo negativo, o
    # si mangerebbe un intoccabile
    var storto := _filo([[50, "a"], [10, "a"], [20, "a"]])
    t.ok(LEG.buco(storto, 1) >= 0, "date in disordine: il buco non va sotto zero")


func _test_il_costo(t) -> void:
    # a parità di buco, il tipo RARO costa di più: la rarità è il secondo
    # peso, e vale quanto un buco di 4 giorni per un tipo unico
    var m := _filo([[1, "x"], [2, "raro"], [3, "comune"], [4, "comune"],
            [5, "comune"], [6, "comune"], [7, "x"]])
    t.ok(LEG.costo(m, 1) > LEG.costo(m, 2),
            "fra due momenti contigui, il tipo unico costa più della replica")
    # e il costo cresce col buco
    var largo := _filo([[1, "a"], [2, "b"], [30, "a"]])
    var stretto := _filo([[1, "a"], [2, "b"], [3, "a"]])
    t.ok(LEG.costo(largo, 1) > LEG.costo(stretto, 1),
            "chi lascia un buco più largo costa di più")


# ------------------------------------------------------- chi si sacrifica

func _test_chi_si_sacrifica(t) -> void:
    # un filo con una fitta serie di repliche in mezzo: la vittima esce
    # da lì, mai dai capi
    var m := _filo([[1, "benvenuto"], [2, "trasloco"], [3, "primo_saluto"],
            [20, "piatto"], [21, "piatto"], [22, "piatto"], [23, "piatto"],
            [24, "piatto"], [60, "festa"], [61, "onsen"], [62, "piatto"]])
    var v: int = LEG.indice_da_potare(m)
    t.ok(v >= LEG.CAPI_TESTA and v < m.size() - LEG.CAPI_CODA,
            "la vittima sta in mezzo, mai ai capi (indice %d)" % v)
    t.eq(str((m[v] as Dictionary)["t"]), "piatto",
            "e viene dalla serie fitta di repliche")
    t.ok(not LEG.intoccabile(m, v), "la vittima non è mai un intoccabile")

    # se è TUTTO intoccabile la funzione lo dice, invece di inventarsi
    # una vittima: il filo terrà un momento in più, e va benissimo
    var tutti_capi := _filo([[1, "benvenuto"], [2, "trasloco"], [3, "oro"],
            [4, "oro"], [5, "addio"], [6, "partenza"]])
    t.eq(LEG.indice_da_potare(tutti_capi), -1,
            "tutto intoccabile -> nessuna vittima (-1)")
    var potato: Array = LEG.pota(tutti_capi, 3)
    t.eq(potato.size(), tutti_capi.size(),
            "…e potare non butta niente lo stesso")


# -------------------------------------------------------- una vita intera

func _test_una_vita_intera(t) -> void:
    # QUATTROCENTO GIORNI di amicizia, un momento ogni tanto, esattamente
    # come li annoderebbe il gioco: si parte col benvenuto e la valigia, poi
    # la vita di tutti i giorni.
    var momenti: Array = [
        {"d": 1, "t": "benvenuto", "x": ""},
        {"d": 2, "t": "trasloco", "x": ""},
        {"d": 3, "t": "primo_saluto", "x": ""},
    ]
    var ordinari := ["piatto", "regalo", "onsen", "desiderio", "nascondino", "festa"]
    var giorno := 4
    while giorno <= 400:
        momenti.append({"d": giorno, "t": ordinari[giorno % ordinari.size()], "x": ""})
        momenti = LEG.pota(momenti)
        giorno += 3

    t.ok(momenti.size() <= LEG.MAX_MOMENTI,
            "dopo 400 giorni il filo sta nella sua capienza (%d)" % momenti.size())

    # LA PROVA CHE CONTA: la storia ha ancora un inizio
    var tipi: Array = []
    for m in momenti:
        tipi.append(str(m["t"]))
    t.ok("benvenuto" in tipi, "dopo 400 giorni c'è ancora il primo benvenuto")
    t.ok("trasloco" in tipi, "…e il giorno della valigia")
    t.eq(int((momenti[0] as Dictionary)["d"]), 1, "e il filo comincia dal giorno 1")

    # l'arco resta leggibile: il congedo campiona 5 momenti lungo la vita e
    # devono raccontarla, non ammucchiarsi sull'ultima settimana
    var campioni: Array = []
    for i in 5:
        @warning_ignore("integer_division")
        var m: Dictionary = momenti[mini(i * momenti.size() / 5, momenti.size() - 1)]
        campioni.append(int(m["d"]))
    t.eq(campioni[0], 1, "il primo ricordo che riaffiora è il giorno 1")
    t.ok(campioni[4] > 300, "e l'ultimo è di poco fa (giorno %d)" % campioni[4])
    for i in range(1, campioni.size()):
        t.ok(campioni[i] > campioni[i - 1], "i cinque ricordi sono in ordine")

    # nessun buco mostruoso: la vita non deve avere voragini di mesi
    var peggiore := 0
    for i in range(1, momenti.size()):
        peggiore = maxi(peggiore, int(momenti[i]["d"]) - int(momenti[i - 1]["d"]))
    t.ok(peggiore <= 120,
            "nessun vuoto mostruoso nel racconto (il peggiore è %d giorni)" % peggiore)

    # e la varietà: il filo non si riduce a un tipo solo
    var visti := {}
    for tipo in tipi:
        visti[tipo] = true
    t.ok(visti.size() >= 4, "restano almeno quattro tipi diversi di ricordo")


func _test_i_casi_limite(t) -> void:
    # tutti momenti dello stesso tipo: si dirada lo stesso, e i capi restano
    var uguali: Array = []
    for i in 60:
        uguali.append({"d": i + 1, "t": "piatto", "x": ""})
    var potato: Array = LEG.pota(uguali)
    t.ok(potato.size() <= LEG.MAX_MOMENTI, "un filo monotono si pota lo stesso")
    t.eq(int((potato[0] as Dictionary)["d"]), 1, "e conserva il primo")
    t.eq(int((potato[potato.size() - 1] as Dictionary)["d"]), 60, "e l'ultimo")

    # filo vuoto o cortissimo: nessun crash, niente da potare
    t.eq(LEG.pota([]).size(), 0, "un filo vuoto resta vuoto")
    t.eq(LEG.indice_da_potare([]), -1, "…e non ha vittime")
    var corto := _filo([[1, "benvenuto"], [2, "piatto"]])
    t.eq(LEG.pota(corto).size(), 2, "un filo corto non si tocca")

    # pota() NON muta l'originale (la usano migrazione e test)
    var prima := _filo_lungo(50)
    var quanti_prima := prima.size()
    LEG.pota(prima)
    t.eq(prima.size(), quanti_prima, "pota() lavora su una copia")


# --------------------------------------------------- il conto non si pota

func _test_il_conto_non_si_pota(t) -> void:
    # la lettera d'addio dice «porto con me N momenti»: N è la VITA, non la
    # capienza della borsa. Il campo si chiama "n" e la migrazione lo mette
    # a un pavimento onesto per i fili vecchi.
    var vecchio := {"Miele": {"giorno_arrivo": 1,
            "momenti": [{"d": 1, "t": "benvenuto", "x": ""},
                    {"d": 2, "t": "trasloco", "x": ""}]}}
    var migrato: Dictionary = LEG.migra_fili(vecchio)
    t.eq(int((migrato["Miele"] as Dictionary).get("n", -1)), 2,
            "un filo senza conto riparte dai momenti che ha (pavimento onesto)")

    # e la migrazione pota i fili sforati (il difetto che restava dopo la
    # fusione di un filo-fantasma: l'array poteva restare sopra il tetto)
    var gonfio := {"Pepita": {"giorno_arrivo": 1, "momenti": _filo_lungo(48)}}
    var sgonfio: Dictionary = LEG.migra_fili(gonfio)
    t.ok((sgonfio["Pepita"] as Dictionary)["momenti"].size() <= LEG.MAX_MOMENTI,
            "la migrazione riporta nella capienza anche i fili gonfi")

    # e rimette in ordine le date (è la precondizione di buco())
    var storto := {"Nocciola": {"giorno_arrivo": 1, "momenti": [
            {"d": 9, "t": "piatto", "x": ""}, {"d": 2, "t": "benvenuto", "x": ""},
            {"d": 5, "t": "onsen", "x": ""}]}}
    var dritto: Array = (LEG.migra_fili(storto)["Nocciola"] as Dictionary)["momenti"]
    t.eq(int((dritto[0] as Dictionary)["d"]), 2, "la migrazione ordina per giornata")
    t.eq(int((dritto[2] as Dictionary)["d"]), 9, "…dalla più vecchia alla più nuova")


# ------------------------------------------------------------------ utili

static func _filo(coppie: Array) -> Array:
    var out: Array = []
    for c in coppie:
        out.append({"d": int(c[0]), "t": str(c[1]), "x": ""})
    return out


static func _filo_lungo(quanti: int) -> Array:
    var tipi := ["piatto", "regalo", "onsen", "desiderio"]
    var out: Array = []
    for i in quanti:
        out.append({"d": i + 1, "t": tipi[i % tipi.size()], "x": ""})
    return out
