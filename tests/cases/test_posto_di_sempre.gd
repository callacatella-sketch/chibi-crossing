extends RefCounted
## IL POSTO DI SEMPRE — l'abitudine che nessuno ha deciso.
##
## È il sistema più delicato da verificare, perché la sua qualità sta in
## quello che NON fa: non deve accorgersi di un passaggio, non deve
## scambiare tre ore di un pomeriggio per tre pomeriggi, non deve
## annunciare la scoperta con un toast (dirtelo la rovinerebbe), e non
## deve mandare al posto un vicino a caso — ci va chi ti conosce meglio.
##
## Le decisioni sono pure e si provano qui; il silenzio si difende
## guardando che nessuno lo rompa.

const POSTO := preload("res://scenes/world/PostoDiSempre.gd")
const LEG := preload("res://scenes/world/Legami.gd")


func run(t) -> void:
    _test_passare_non_e_fermarsi(t)
    _test_il_posto_si_sposta(t)
    _test_la_chiave(t)
    _test_le_fasce(t)
    _test_abitudine_non_e_insistenza(t)
    _test_la_piu_forte(t)
    _test_il_silenzio(t)
    _test_i_fili(t)


# ------------------------------------------- passare non e' fermarsi
# LA PROVA CHE MANCAVA, e che avrebbe preso il difetto: qui si attraversa
# `_process` davvero, con Mochi ferma nel punto e nell'ora che decidiamo
# noi. Il contatore dei secondi era CUMULATIVO A VITA: superati i nove
# secondi una volta sola, da li' in poi bastava passare un istante per
# timbrare la giornata — e il "posto di sempre" si eleggeva sull'uscio di
# casa entro la prima settimana. Le funzioni pure erano tutte verdi.

class FintoPlayer extends Node3D:
    var velocity := Vector3.ZERO


class FintoGiorno extends Node3D:
    var time := 0.5
    var day := 1


func _monta(t):
    var p = t.stage(POSTO.new())
    var pl = t.stage(FintoPlayer.new())
    var dn = t.stage(FintoGiorno.new())
    p.set("_player", pl)
    p.set("_daynight", dn)
    p.set("_build", null)
    p.set("_visitors", null)
    return {"posto": p, "player": pl, "giorno": dn}


## Ferma nel punto dato per `secondi`, campionando come fa il gioco.
func _stai_fermo(m, pos: Vector3, secondi: float) -> void:
    m["player"].global_position = pos
    m["player"].velocity = Vector3.ZERO
    var passi := int(secondi / POSTO.CAMPIONE)
    for i in passi:
        m["posto"]._process(POSTO.CAMPIONE)


func _test_passare_non_e_fermarsi(t) -> void:
    var m = _monta(t)
    var qui := Vector3(12.0, 0, 12.0)
    m["giorno"].time = 0.5

    # giorno 1: una sosta VERA (dieci secondi fermi li')
    m["giorno"].day = 1
    _stai_fermo(m, qui, 10.0)
    t.eq((m["posto"].get("_posto") as Dictionary).is_empty(), true,
            "una sola giornata non fa un posto")

    # giorni 2 e 3: ci si passa e basta, un istante per volta
    for g in [2, 3]:
        m["giorno"].day = g
        _stai_fermo(m, qui, POSTO.CAMPIONE)
    t.ok((m["posto"].get("_posto") as Dictionary).is_empty(),
            "REGRESSIONE: passare un istante non timbra la giornata")

    # e ora tre soste VERE: quello si' che e' un'abitudine
    for g in [4, 5, 6]:
        m["giorno"].day = g
        _stai_fermo(m, qui, 10.0)
    t.ok(not (m["posto"].get("_posto") as Dictionary).is_empty(),
            "tre soste vere in tre giornate fanno il posto di sempre")

    # camminare azzera la sosta in corso: nove secondi spezzati in tre
    # passaggi non valgono una sosta
    var m2 = _monta(t)
    var la := Vector3(-20.0, 0, -20.0)
    m2["giorno"].time = 0.2
    for g in [1, 2, 3]:
        m2["giorno"].day = g
        for volta in 3:
            _stai_fermo(m2, la, 4.0)
            m2["player"].velocity = Vector3(2.0, 0, 0)   # si rialza e cammina
            m2["posto"]._process(POSTO.CAMPIONE)
    t.ok((m2["posto"].get("_posto") as Dictionary).is_empty(),
            "una sosta spezzata dal camminare non conta come sosta")


func _test_il_posto_si_sposta(t) -> void:
    # LA PRIMA ELEZIONE NON E' DEFINITIVA: un'abitudine si sposta, e il
    # posto la segue. Prima il primo posto trovato restava per sempre.
    var m = _monta(t)
    var vecchio := Vector3(3.0, 0, 3.0)
    var nuovo := Vector3(30.0, 0, 30.0)
    m["giorno"].time = 0.5
    for g in [1, 2, 3]:
        m["giorno"].day = g
        _stai_fermo(m, vecchio, 10.0)
    var primo := str((m["posto"].get("_posto") as Dictionary).get("chiave", ""))
    t.ok(primo != "", "il primo posto si elegge")
    # poi per cinque giorni l'abitudine e' un'altra
    for g in [4, 5, 6, 7, 8]:
        m["giorno"].day = g
        _stai_fermo(m, nuovo, 10.0)
    var dopo := str((m["posto"].get("_posto") as Dictionary).get("chiave", ""))
    t.ok(dopo != primo, "l'abitudine piu' forte si porta dietro il posto")
    t.eq(dopo, POSTO.chiave(nuovo, 0.5), "…ed e' quella nuova")


# --------------------------------------------------------------- la chiave

func _test_la_chiave(t) -> void:
    var ora := 0.5
    # due soste vicine sono LO STESSO posto: l'abitudine non è precisa al
    # centimetro, e chiedere la precisione la renderebbe impossibile
    var a := POSTO.chiave(Vector3(4.0, 0, 4.0), ora)
    var b := POSTO.chiave(Vector3(4.9, 0, 4.4), ora)
    t.eq(a, b, "due passi più in là è ancora lo stesso posto")
    # due soste lontane no
    var c := POSTO.chiave(Vector3(30.0, 0, 4.0), ora)
    t.ok(a != c, "dall'altra parte del prato è un altro posto")
    # e la quota non conta: il posto è sul piano
    t.eq(POSTO.chiave(Vector3(4.0, 3.0, 4.0), ora), a,
            "il piano di sopra non fa un posto nuovo")
    # il centro di una chiave torna dentro la cella da cui è nata
    var centro: Vector3 = POSTO.centro_di(a)
    t.ok(absf(centro.x - 4.0) <= POSTO.CELLA, "il centro è vicino al punto vero")
    t.ok(absf(centro.z - 4.0) <= POSTO.CELLA, "…su entrambi gli assi")
    t.eq(POSTO.centro_di("storta"), Vector3.ZERO, "una chiave storta non esplode")


func _test_le_fasce(t) -> void:
    # la giornata è divisa in fasce: la stessa ora "circa" è la stessa ora
    t.eq(POSTO.fetta_di(0.0), 0, "la mezzanotte è la prima fascia")
    t.eq(POSTO.fetta_di(0.999), POSTO.FETTE - 1, "e la fine del giorno l'ultima")
    t.ok(POSTO.fetta_di(0.0) >= 0 and POSTO.fetta_di(1.0) < POSTO.FETTE,
            "le fasce restano dentro il conto, anche al limite")
    # stessa fascia = stesso appuntamento; fasce diverse = posti diversi
    t.eq(POSTO.chiave(Vector3.ZERO, 0.51), POSTO.chiave(Vector3.ZERO, 0.56),
            "mezz'ora dopo è ancora 'quell'ora lì'")
    t.ok(POSTO.chiave(Vector3.ZERO, 0.2) != POSTO.chiave(Vector3.ZERO, 0.8),
            "mattina e sera non sono la stessa abitudine")
    # e la fascia si rilegge dalla chiave (serve all'appuntamento)
    t.eq(POSTO.fetta_di_chiave(POSTO.chiave(Vector3(9, 0, 9), 0.63)),
            POSTO.fetta_di(0.63), "la fascia si rilegge dalla chiave")


# --------------------------------------- l'abitudine non è l'insistenza

func _test_abitudine_non_e_insistenza(t) -> void:
    # TRE VOLTE NELLO STESSO GIORNO NON SONO UN'ABITUDINE: è stare fermi
    # un pomeriggio. Serve che torni in giornate DIVERSE.
    t.ok(not POSTO.e_abitudine([7, 7, 7, 7, 7]),
            "cinque soste nello stesso giorno non fanno un'abitudine")
    t.ok(not POSTO.e_abitudine([]), "nessuna sosta, nessuna abitudine")
    t.ok(not POSTO.e_abitudine([1, 2]), "due giornate non bastano")
    t.ok(POSTO.e_abitudine([1, 2, 3]), "tre giornate diverse sì")
    t.ok(POSTO.e_abitudine([4, 9, 30, 31]), "…anche non consecutive")
    t.eq(POSTO.GIORNI_ABITUDINE, 3, "la soglia è tre giornate")
    # e la sosta minima esiste: passare non è fermarsi
    t.ok(POSTO.SOSTA_MINIMA > 0.0, "una sosta deve durare per contare")


func _test_la_piu_forte(t) -> void:
    var soste := {
        "0:0:4": {"giorni": [1, 2], "secondi": 90.0},          # non ancora abitudine
        "5:5:6": {"giorni": [1, 2, 3], "secondi": 30.0},       # abitudine
        "9:9:2": {"giorni": [1, 2, 3, 4, 5], "secondi": 20.0}, # abitudine più forte
    }
    t.eq(POSTO.abitudine_piu_forte(soste), "9:9:2",
            "vince chi è tornato in più giornate, non chi è stato più a lungo")
    t.eq(POSTO.abitudine_piu_forte({}), "", "senza soste non c'è nessun posto")
    t.eq(POSTO.abitudine_piu_forte({"1:1:1": {"giorni": [3], "secondi": 999.0}}), "",
            "un pomeriggio lunghissimo, da solo, non fa un posto")
    # a parità di giornate decide il tempo passato lì
    var pari := {
        "1:1:1": {"giorni": [1, 2, 3], "secondi": 10.0},
        "2:2:1": {"giorni": [1, 2, 3], "secondi": 80.0},
    }
    t.eq(POSTO.abitudine_piu_forte(pari), "2:2:1",
            "a parità di giornate vince il posto dove ci si è fermati di più")


# ------------------------------------------------------------- il silenzio
# La qualità di questo sistema sta in quello che NON fa.

func _test_il_silenzio(t) -> void:
    var fonte := FileAccess.get_file_as_string("res://scenes/world/PostoDiSempre.gd")
    # NESSUN ANNUNCIO quando il posto viene scoperto: il gioco si è
    # accorto di una cosa tua, e dirtelo la rovinerebbe. Lo sai la prima
    # volta che arrivi e trovi qualcuno.
    t.ok(not fonte.contains("_show_toast"),
            "il posto di sempre non si annuncia mai con un toast")
    t.ok(not fonte.contains("_toast("), "…né in nessun altro modo")
    # e chi arriva NON PARLA: niente Chibiese, niente nuvolette
    t.ok(not fonte.contains('"speak"'), "chi ti trova lì non dice niente")
    t.ok(not fonte.contains("chat_bubble"), "…e non apre nemmeno una nuvoletta")
    # l'unica cosa che si vede è un cuoricino, dal suo lato
    t.ok(fonte.contains("_spawn_heart"), "l'unica cosa che si vede è un cuoricino")
    # e non tutti i giorni: l'attesa fa parte del dono
    t.ok(POSTO.PROB_APPUNTAMENTO < 1.0, "non ci si trova ogni singolo giorno")
    t.ok(POSTO.PROB_APPUNTAMENTO > 0.2, "…ma abbastanza da succedere davvero")


func _test_i_fili(t) -> void:
    var fonte := FileAccess.get_file_as_string("res://scenes/world/PostoDiSempre.gd")
    # il momento si annoda al Filo: cento giorni dopo, davanti al fiore,
    # «il posto di sempre» riaffiora insieme al resto della storia
    t.ok(LEG.TIPI.has("posto"), "il Filo Rosso conosce il momento del posto")
    t.ok(fonte.contains('"momento", nome, "posto"'),
            "…e il posto lo annoda davvero, col NOME (mai la label)")
    # ci va chi ti conosce meglio, non uno a caso
    t.ok(fonte.contains("_chi_ti_conosce_meglio"),
            "al posto di sempre ci va chi ha più momenti con te")
    t.ok(fonte.contains("momenti_vissuti"),
            "…e 'meglio' si misura sul Filo, non su un contatore a parte")
    # solo all'aperto: dentro casa non è «il posto», è casa
    t.ok(fonte.contains("has_cover"), "dentro casa non conta come posto")
    # il salvataggio non cresce all'infinito
    t.ok(fonte.contains("func save_extra"), "il posto si ricorda fra una partita e l'altra")
    var scena := FileAccess.get_file_as_string("res://scenes/levels/MainLevel.tscn")
    t.ok(scena.contains("PostoDiSempre.gd"), "il sistema è in scena")
