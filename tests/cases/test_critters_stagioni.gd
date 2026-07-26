extends RefCounted
## Il CALENDARIO delle specie (Critters: cond/contesto/disponibile/estrai).
##
## Le specie stagionali si provano qui, headless, invece che aspettando
## l'inverno a occhio: la farfalla di neve esiste solo sotto la nevicata,
## la lumachina solo con la pioggia, la libellula solo al crepuscolo — e
## lo stagno non deve MAI restare senza pesci, con qualsiasi tempo.

const CRIT := preload("res://scenes/world/Critters.gd")


func run(t) -> void:
    _test_contesto(t)
    _test_semantica_ora(t)
    _test_stagioni_e_meteo(t)
    _test_pool_mai_vuote(t)
    _test_estrazione(t)
    _test_pesi_e_tetti(t)


# --------------------------------------------------------------- contesto

func _test_contesto(t) -> void:
    # l'orologio di DayNight: 0.25 alba, 0.5 mezzogiorno, 0.75 tramonto
    var c: Dictionary = CRIT.contesto(0, 0.5, false, "sereno")
    t.eq(str(c["ora"]), "giorno", "mezzogiorno -> giorno")
    c = CRIT.contesto(0, 0.05, true, "sereno")
    t.eq(str(c["ora"]), "notte", "notte fonda -> notte")
    c = CRIT.contesto(0, 0.25, false, "sereno")
    t.eq(str(c["ora"]), "crepuscolo", "l'alba e' crepuscolo")
    c = CRIT.contesto(0, 0.75, true, "sereno")
    t.eq(str(c["ora"]), "crepuscolo", "il tramonto e' crepuscolo (anche se DayNight dice gia' notte)")
    c = CRIT.contesto(2, 0.5, false, "pioggia")
    t.eq(int(c["stagione"]), 2, "la stagione passa intatta")
    t.eq(str(c["meteo"]), "pioggia", "il meteo passa intatto")


# --------------------------------------------------- la semantica dell'ora

func _test_semantica_ora(t) -> void:
    var giorno: Dictionary = CRIT.contesto(1, 0.5, false, "sereno")
    var notte: Dictionary = CRIT.contesto(1, 0.05, true, "sereno")
    var alba: Dictionary = CRIT.contesto(1, 0.25, false, "sereno")
    # chi vive di giorno c'e' anche al crepuscolo (la frontiera, non un buco)
    t.ok(CRIT.disponibile("rosa", giorno), "farfalla rosa: di giorno c'e'")
    t.ok(CRIT.disponibile("rosa", alba), "farfalla rosa: al crepuscolo pure")
    t.ok(not CRIT.disponibile("rosa", notte), "farfalla rosa: di notte no")
    # chi vive di notte c'e' anche al crepuscolo
    t.ok(CRIT.disponibile("lucciola", notte), "lucciola: di notte c'e'")
    t.ok(CRIT.disponibile("lucciola", alba), "lucciola: al crepuscolo pure")
    t.ok(not CRIT.disponibile("lucciola", giorno), "lucciola: di giorno no")
    # chi chiede il crepuscolo ha la finestra ESCLUSIVA
    t.ok(CRIT.disponibile("libellula", alba), "libellula: al crepuscolo c'e'")
    t.ok(not CRIT.disponibile("libellula", giorno), "libellula: di giorno no")
    t.ok(not CRIT.disponibile("libellula", notte), "libellula: di notte no")
    t.ok(CRIT.disponibile("alba", alba), "pesce dell'alba: solo al crepuscolo")
    t.ok(not CRIT.disponibile("alba", giorno), "pesce dell'alba: a mezzogiorno no")


# ------------------------------------------------------- stagioni e meteo

func _test_stagioni_e_meteo(t) -> void:
    # la farfalla di neve: SOLO inverno, SOLO mentre nevica
    t.ok(CRIT.disponibile("neve", CRIT.contesto(3, 0.5, false, "neve")),
            "farfalla di neve: inverno + nevicata -> c'e'")
    t.ok(not CRIT.disponibile("neve", CRIT.contesto(3, 0.5, false, "sereno")),
            "farfalla di neve: inverno sereno -> no")
    t.ok(not CRIT.disponibile("neve", CRIT.contesto(0, 0.5, false, "neve")),
            "farfalla di neve: mai fuori dall'inverno")
    # la lumachina e la rana: solo con la PIOGGIA (la neve non conta)
    t.ok(CRIT.disponibile("lumachina", CRIT.contesto(1, 0.5, false, "pioggia")),
            "lumachina: con la pioggia c'e'")
    t.ok(not CRIT.disponibile("lumachina", CRIT.contesto(1, 0.5, false, "sereno")),
            "lumachina: col sereno no")
    t.ok(not CRIT.disponibile("rana", CRIT.contesto(3, 0.5, false, "neve")),
            "rana blu: sotto la neve no (vuole la pioggia)")
    # la falena: solo nelle notti d'autunno
    t.ok(CRIT.disponibile("falena", CRIT.contesto(2, 0.05, true, "sereno")),
            "falena: notte d'autunno -> c'e'")
    t.ok(not CRIT.disponibile("falena", CRIT.contesto(2, 0.5, false, "sereno")),
            "falena: di giorno no")
    t.ok(not CRIT.disponibile("falena", CRIT.contesto(1, 0.05, true, "sereno")),
            "falena: d'estate no")
    # cicala e scarabeo: l'estate divisa a meta' tra giorno e notte
    t.ok(CRIT.disponibile("cicala", CRIT.contesto(1, 0.5, false, "sereno")),
            "cicala: giorno d'estate")
    t.ok(not CRIT.disponibile("cicala", CRIT.contesto(1, 0.05, true, "sereno")),
            "cicala: di notte tace")
    t.ok(CRIT.disponibile("scarabeo", CRIT.contesto(1, 0.05, true, "sereno")),
            "scarabeo: notte d'estate")
    # i pesci di stagione
    t.ok(CRIT.disponibile("girino", CRIT.contesto(0, 0.5, false, "sereno")),
            "girino: primavera")
    t.ok(not CRIT.disponibile("girino", CRIT.contesto(1, 0.5, false, "sereno")),
            "girino: d'estate e' gia' rana (non abbocca piu')")
    t.ok(CRIT.disponibile("ghiaccio", CRIT.contesto(3, 0.5, false, "sereno")),
            "pesce ghiaccio: inverno")
    t.ok(CRIT.disponibile("foglia", CRIT.contesto(2, 0.5, false, "sereno")),
            "carpa foglia d'oro: autunno")
    # il porcino: solo d'autunno
    t.ok(CRIT.disponibile("porcino", CRIT.contesto(2, 0.5, false, "sereno")),
            "porcino: autunno")
    t.ok(not CRIT.disponibile("porcino", CRIT.contesto(0, 0.5, false, "sereno")),
            "porcino: in primavera no")
    # una specie senza cond c'e' sempre; una sconosciuta mai
    t.ok(CRIT.disponibile("carpetta", CRIT.contesto(3, 0.05, true, "neve")),
            "carpetta: sempre, anche nelle notti d'inverno")
    t.ok(not CRIT.disponibile("inesistente", CRIT.contesto(0, 0.5, false, "sereno")),
            "specie sconosciuta -> mai disponibile")


# --------------------------------------------------- le pool non si svuotano

func _test_pool_mai_vuote(t) -> void:
    # lo stagno non deve MAI restare senza pesci: con qualsiasi stagione,
    # ora e meteo la canna deve avere qualcuno da far abboccare
    for stagione in 4:
        for tempo in [0.05, 0.25, 0.5, 0.75]:
            for meteo in ["sereno", "pioggia", "neve"]:
                var ctx: Dictionary = CRIT.contesto(stagione, float(tempo),
                        float(tempo) < 0.2, str(meteo))
                var pool: Array = CRIT.disponibili("pesce", ctx)
                t.ok(not pool.is_empty(),
                        "pesci disponibili (stagione %d, t=%.2f, %s)"
                        % [stagione, tempo, meteo])
    # il prato: farfalle di giorno in tre stagioni; d'inverno solo la neve
    for stagione in 3:
        var ctx_g: Dictionary = CRIT.contesto(stagione, 0.5, false, "sereno")
        t.ok(not CRIT.disponibili("farfalla", ctx_g).is_empty(),
                "farfalle di giorno nella stagione %d" % stagione)
    t.ok(CRIT.disponibili("farfalla", CRIT.contesto(3, 0.5, false, "sereno")).is_empty(),
            "inverno sereno: il prato riposa (nessuna farfalla)")
    t.ok(not CRIT.disponibili("farfalla", CRIT.contesto(3, 0.5, false, "neve")).is_empty(),
            "inverno con la nevicata: la farfalla di neve esiste")
    # le notti d'autunno hanno la falena: la notte non e' piu' vuota
    var ctx_n: Dictionary = CRIT.contesto(2, 0.05, true, "sereno")
    t.ok("falena" in CRIT.disponibili("farfalla", ctx_n),
            "la falena vola nelle notti d'autunno")


# ------------------------------------------------------------- estrazione

func _test_estrazione(t) -> void:
    t.eq(CRIT.estrai([], 0.5), "", "estrazione da lista vuota -> stringa vuota")
    t.eq(CRIT.estrai(["carpetta"], 0.99), "carpetta", "un solo id -> quello")
    # con caso 0 esce il primo, con caso ~1 l'ultimo: i pesi sono cumulativi
    t.eq(CRIT.estrai(["carpetta", "rosina"], 0.0), "carpetta", "caso 0 -> il primo")
    t.eq(CRIT.estrai(["carpetta", "rosina"], 0.999), "rosina", "caso ~1 -> l'ultimo")
    # il confine: carpetta pesa 5.8, rosina 1.2 -> sotto 5.8/7 esce carpetta
    t.eq(CRIT.estrai(["carpetta", "rosina"], 0.8), "carpetta", "0.8*7=5.6 < 5.8 -> carpetta")
    t.eq(CRIT.estrai(["carpetta", "rosina"], 0.85), "rosina", "0.85*7=5.95 > 5.8 -> rosina")


# ---------------------------------------------------------- pesi e tetti

func _test_pesi_e_tetti(t) -> void:
    t.almost(CRIT.peso("carota"), 3.0, "senza campo peso: comune -> 3.0")
    t.almost(CRIT.peso("gialla"), 1.2, "il peso dichiarato vince")
    t.almost(CRIT.peso("inesistente"), 0.0, "specie sconosciuta -> peso 0")
    t.eq(CRIT.max_vivi("rosa"), 5, "senza campo max -> 5")
    t.eq(CRIT.max_vivi("regale"), 1, "la lucciola regale e' una sola")
    t.eq(CRIT.luogo("rosa"), "prato", "senza campo luogo -> prato")
    t.eq(CRIT.luogo("cicala"), "bosco", "la cicala vive nel bosco")
    t.eq(CRIT.luogo("rana"), "stagno", "la rana vive allo stagno")
    t.ok(CRIT.indizio("inesistente") != "", "indizio di ripiego mai vuoto")
