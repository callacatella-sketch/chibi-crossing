extends RefCounted
## IL RIMBALZELLO — il punteggio detto all'orecchio (Rimbalzello.gd).
##
## Qui si difende la cosa che a occhio non si vede: che la scala dei plop
## SALGA davvero (è il punteggio: se due rimbalzi suonassero uguali, il
## gioco non direbbe più niente), che non si fallisca mai — il minimo è
## due salti, come promette la filosofia cozy — e che l'unica bravura
## richiesta, leggere il cielo, abbia un effetto vero: con l'aria ferma il
## sasso corre, col temporale in arrivo si pianta.

const RIMB := preload("res://scenes/interact/Rimbalzello.gd")
const CONC := preload("res://scenes/interact/Concertino.gd")
const INV := preload("res://scenes/ui/Inventory.gd")


func run(t) -> void:
    _test_non_si_fallisce_mai(t)
    _test_il_vento_e_la_bravura(t)
    _test_la_scala_sale(t)
    _test_il_volo(t)
    _test_il_sasso_e_un_tesoro(t)
    _test_i_fili(t)


# ------------------------------------------------------ non si fallisce mai

func _test_non_si_fallisce_mai(t) -> void:
    # qualunque tiro, con qualunque vento e qualunque fortuna, rimbalza
    # almeno due volte: qui non si sbaglia, al massimo il sasso è pigro
    for caso in [0.0, 0.25, 0.5, 0.75, 1.0]:
        for vento in [0.0, 0.45, 1.0, 1.8, 2.0]:
            var n: int = RIMB.rimbalzi(caso, vento)
            t.ok(n >= RIMB.RIMBALZI_MINIMO,
                    "caso %.2f vento %.2f: almeno %d rimbalzi (%d)"
                    % [caso, vento, RIMB.RIMBALZI_MINIMO, n])
            t.ok(n <= RIMB.RIMBALZI_MASSIMO,
                    "caso %.2f vento %.2f: mai oltre il tetto (%d)" % [caso, vento, n])
    # e valori fuori scala non rompono niente (un globale storto capita)
    t.ok(RIMB.rimbalzi(-5.0, -3.0) >= RIMB.RIMBALZI_MINIMO, "caso negativo: regge")
    t.ok(RIMB.rimbalzi(9.0, 99.0) >= RIMB.RIMBALZI_MINIMO, "vento assurdo: regge")


func _test_il_vento_e_la_bravura(t) -> void:
    # L'UNICA ABILITÀ È LEGGERE IL CIELO: a parità di fortuna, l'aria
    # ferma della nebbiolina fa correre il sasso più della brezza, e il
    # temporale lo pianta. Se questo non fosse vero, il gioco sarebbe un
    # dado e non varrebbe la pena di aspettare il momento giusto.
    for caso in [0.2, 0.5, 0.8]:
        var nebbia: int = RIMB.rimbalzi(caso, 0.45)
        var sereno: int = RIMB.rimbalzi(caso, 1.0)
        var temporale: int = RIMB.rimbalzi(caso, 1.8)
        t.ok(nebbia > sereno, "caso %.1f: con l'aria ferma il sasso corre" % caso)
        t.ok(temporale < sereno, "caso %.1f: col vento si pianta" % caso)
    # e la differenza è LEGGIBILE: fra la nebbia e il temporale ci deve
    # essere almeno un paio di salti, o nessuno se ne accorgerebbe
    t.ok(RIMB.rimbalzi(0.5, 0.45) - RIMB.rimbalzi(0.5, 1.8) >= 2,
            "fra l'aria ferma e la burrasca ci sono almeno due salti")


# ---------------------------------------------------------- la scala sale

func _test_la_scala_sale(t) -> void:
    # IL PUNTEGGIO È IL SUONO: ogni rimbalzo suona più su del precedente.
    # Due plop uguali di fila e il giocatore non capisce più come sta
    # andando — è l'unico "numero" che questo gioco mostra.
    var prima := 0.0
    for i in RIMB.RIMBALZI_MASSIMO:
        var p: float = RIMB.tono(i)
        t.ok(p > prima, "il rimbalzo %d suona più su del precedente (%.3f)" % [i, p])
        t.ok(p >= 1.0 and p < 6.0, "…e resta un pitch sensato (%.3f)" % p)
        prima = p
    # ed è la scala PENTATONICA del villaggio, non una scala qualunque:
    # la stessa dove il coro non stona mai
    t.almost(RIMB.tono(0), 1.0, "si parte dalla tonica")
    t.almost(RIMB.tono(5), 2.0, "e dopo cinque gradini si è saliti di un'ottava")
    for i in 8:
        t.eq(RIMB.tono(i), pow(2.0, float(CONC.gradino(i)) / 12.0),
                "il gradino %d è quello del Concertino (una scala sola)" % i)


func _test_il_volo(t) -> void:
    var quanti := 6
    # i salti si ACCORCIANO: il sasso perde forza, e quel ritmo che si
    # stringe è ciò che lo fa sembrare vero invece che un metronomo
    var prima: float = RIMB.passo(0, quanti)
    for i in range(1, quanti):
        var p: float = RIMB.passo(i, quanti)
        t.ok(p < prima, "il salto %d è più corto del precedente" % i)
        t.ok(p > 0.0, "…ma è ancora un salto")
        prima = p
    # e si ABBASSANO, fino a strisciare sull'acqua
    var alta: float = RIMB.altezza(0, quanti)
    var bassa: float = RIMB.altezza(quanti - 1, quanti)
    t.ok(alta > bassa, "l'ultimo rimbalzo è più raso del primo")
    t.ok(bassa > 0.0, "…ma il sasso tocca ancora, non affonda prima")
    # un tiro da due salti non deve dividere per zero
    t.ok(RIMB.passo(0, 1) > 0.0, "un tiro cortissimo non rompe il conto")
    t.ok(RIMB.altezza(0, 1) > 0.0, "…nemmeno l'altezza")


func _test_il_sasso_e_un_tesoro(t) -> void:
    # la munizione è un tesoro vero delle Tasche, non un contatore a parte
    t.ok(INV.TREASURES.has(RIMB.SASSO), "il sasso piatto è un tesoro delle Tasche")
    var scheda: Dictionary = INV.TREASURES[RIMB.SASSO]
    t.eq(str(scheda.get("icon", "")), "sasso", "…con la sua icona disegnata")
    t.ok(str(scheda.get("desc", "")).contains("rimbalz"),
            "…e la scheda dice a cosa serve")
    # e l'icona esiste davvero nel disegnatore, o resterebbe una bacca
    var icone := FileAccess.get_file_as_string("res://scenes/ui/PocketIcon.gd")
    t.ok(icone.contains('"sasso": _sasso()'), "PocketIcon sa disegnare il sasso")


func _test_i_fili(t) -> void:
    # IL CERCHIO COL VICINO: l'indole che colleziona sassolini esisteva da
    # sempre e non serviva a niente. Se qualcuno stacca questo filo, il
    # Rimbalzello resta senza munizioni e non se ne accorge nessuno.
    var vis := FileAccess.get_file_as_string("res://scenes/npc/Visitors.gd")
    t.ok(vis.contains("_dona_sasso"), "il collezionista di sassolini te li porta")
    t.ok(vis.contains('"sasso_piatto"'), "…e il dono è il sasso vero")
    var brain := FileAccess.get_file_as_string("res://scenes/npc/VillagerBrain.gd")
    t.ok(brain.contains("colleziona_sassolini"), "l'indole esiste ancora")
    # il tiro legge il vento VERO, quello condiviso con erba e chiome
    var fonte := FileAccess.get_file_as_string("res://scenes/interact/Rimbalzello.gd")
    t.ok(fonte.contains("_vento()"), "il tiro guarda il cielo")
    t.ok(fonte.contains("forza_del_vento") or fonte.contains("weather"),
            "…e il cielo è quello del Weather, non un numero suo")
    var scena := FileAccess.get_file_as_string("res://scenes/levels/MainLevel.tscn")
    t.ok(scena.contains("Rimbalzello.gd"), "il Rimbalzello è in scena")
