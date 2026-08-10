extends RefCounted
## LA VEGLIA — quello che produce «fare la guardia» (scenes/npc/Veglia.gd).
##
## Il difetto che questo test difende: nel registro dei lavori la guardia
## costava rancore come tutti gli altri (fatica, noia, e tradisce i sogni
## di artisti e giardinieri) ma NON PRODUCEVA NIENTE — il suo ramo nel
## match di `Lavori._produzione_del_giorno()` non c'era. Era l'unico
## lavoro che si poteva solo perderci.
##
## E c'era un difetto sotto il difetto: `sicurezza` era l'unico drive che
## nessuno consumava. Il rientro passivo (+0.09/giorno) la teneva
## inchiodata a 1 per tutti, quindi anche il `-0.05` della guardia era
## invisibile. Un dono di sicurezza senza un buio che la consumi sarebbe
## stato un `clampf()` a vuoto: qui si controlla che il rubinetto e il
## dono esistano ENTRAMBI, e che il buio non possa mai, da solo, portare
## qualcuno alla ribellione.

const VEGLIA := preload("res://scenes/npc/Veglia.gd")
const LAVORI := preload("res://scenes/npc/Lavori.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")
## Il villaggio finto ma vivo, in un posto solo (vedi test_gesti_veri.gd).
const GESTI := preload("res://tests/cases/test_gesti_veri.gd")

# ⚠️ QUESTO FILE È INDENTATO A SPAZI, non a tab: GDScript non tollera le due
# cose insieme nello stesso file, e chi aggiunge una prova qui deve stare al
# passo di quelle che ci sono già.


func run(t) -> void:
    _test_chi_e_al_buio(t)
    _test_la_ronda(t)
    _test_su_chi_ha_vegliato(t)
    _test_le_luci_si_contano_giuste(t)
    _test_il_dono(t)
    _test_il_buio_non_punisce(t)
    _test_il_ramo_che_mancava(t)
    _test_i_fili(t)


# ------------------------------------------------------------ chi è al buio

func _test_chi_e_al_buio(t) -> void:
    var luci := [Vector3(0, 0, 0), Vector3(20, 0, 20)]
    t.ok(not VEGLIA.al_buio(Vector3(1, 0, 1), luci), "sotto la lanterna non è buio")
    t.ok(not VEGLIA.al_buio(Vector3(0, 0, VEGLIA.RAGGIO_LUCE - 0.1), luci),
            "dentro il raggio nemmeno")
    t.ok(VEGLIA.al_buio(Vector3(0, 0, VEGLIA.RAGGIO_LUCE + 1.0), luci),
            "appena fuori dal raggio, è buio")
    t.ok(VEGLIA.al_buio(Vector3(50, 0, 50), luci), "lontano da tutto è buio")
    t.ok(VEGLIA.al_buio(Vector3(0, 0, 0), []), "senza nessuna luce è sempre buio")
    # la quota non conta: una lanterna a terra illumina anche il primo piano
    t.ok(not VEGLIA.al_buio(Vector3(1, 3.0, 1), luci),
            "la luce sale: conta la distanza sul piano, non l'altezza")


# ------------------------------------------------------------------ la ronda

func _test_la_ronda(t) -> void:
    var case := [Vector3(1, 0, 1), Vector3(2, 0, 2), Vector3(3, 0, 3)]
    var ritrovi := [Vector3(9, 0, 9), Vector3(8, 0, 8)]

    # LE CASE VENGONO PRIMA: è per chi ci dorme che si veglia
    var mezza: Array = VEGLIA.tappe_della_ronda(case, ritrovi, 2)
    t.eq(mezza.size(), 2, "una ronda a metà si ferma dopo due tappe")
    t.eq(mezza[0], case[0], "e comincia dalle case")
    t.eq(mezza[1], case[1], "…una dopo l'altra")

    var piena: Array = VEGLIA.tappe_della_ronda(case, ritrovi, 99)
    t.eq(piena.size(), case.size() + ritrovi.size(),
            "il giro pieno tocca case e ritrovi")
    t.eq(piena[3], ritrovi[0], "i ritrovi vengono dopo le case")

    t.eq(VEGLIA.tappe_della_ronda(case, ritrovi, 0).size(), 0,
            "zero tappe: nessuna lanterna")
    t.eq(VEGLIA.tappe_della_ronda([], [], 5).size(), 0,
            "un villaggio vuoto non ha tappe (nessun crash)")

    # IL FILO CON LA SCALA DELLA RIBELLIONE: quante lanterne si accendono lo
    # decide la stessa resa che regola legna e piatti. È il motivo per cui il
    # villaggio illuminato racconta come sta il guardiano, senza pannelli.
    var tappe_tot := 6
    var sereno: int = LAVORI.quanti(tappe_tot, LAVORI.resa("lavoro"))
    var svogliato: int = LAVORI.quanti(tappe_tot, LAVORI.resa("svogliato"))
    var attrezzi: int = LAVORI.quanti(tappe_tot, LAVORI.resa("attrezzi"))
    var rifiuto: float = LAVORI.resa("rifiuto")
    t.eq(sereno, tappe_tot, "sereno: il villaggio è tutto illuminato")
    t.ok(svogliato < sereno and svogliato > 0, "svogliato: metà villaggio al buio")
    t.ok(attrezzi < svogliato, "distratto: solo tre lucine")
    t.almost(rifiuto, 0.0, "dal rifiuto in poi non esce proprio: buio pesto")
    # e chi SOGNAVA di fare il guerriero spinge il giro oltre
    var sognatore: float = LAVORI.resa("lavoro", "guerriero", "guardia")
    t.ok(sognatore > LAVORI.resa("lavoro", "cuoco", "guardia"),
            "chi sognava di fare la guardia rende di più")


# -------------------------------------------------------- su chi ha vegliato

## SU CHI HA VEGLIATO STANOTTE: una porta sola, e la sceglie la geografia.
##
## Prima, il registro dei lavori scriveva nel libro mastro degli affetti una
## riga IDENTICA da chi era di guardia verso OGNI residente. Misurato su 240
## giorni: il conto fra la guardia e il cuoco cresceva 2,6 volte più in
## fretta che verso chiunque altro, la prima coppia nasceva al giorno 3 ed
## era sempre quella, e in tutta la partita non se ne formava nessun'altra —
## un solo incarico assegnato sterilizzava gli affetti dell'INTERO villaggio.
##
## Ora la riga è una, e va all'ULTIMA porta raggiunta che senza quella
## lanterna sarebbe rimasta al buio. Funzione pura: entrano le porte e le
## luci, esce un nome. (Scriverla a tutti i «salvati» era la scorciatoia
## ovvia, ed è stata simulata: rifà lo stesso pareggio un piano sotto, e a
## 28 residenti non si forma nessuna coppia in 5 corse su 6.)
func _test_su_chi_ha_vegliato(t) -> void:
    var porte := [
        {"nome": "Anice", "label": "Anice", "pos": Vector3(0, 0, 0), "cell": Vector2i(0, 0)},
        {"nome": "Basilio", "label": "Basilio", "pos": Vector3(20, 0, 0), "cell": Vector2i(20, 0)},
        {"nome": "Cedro", "label": "Cedro", "pos": Vector3(40, 0, 0), "cell": Vector2i(40, 0)},
    ]
    t.eq(VEGLIA.chi_ha_vegliato(porte, 3, []), "Cedro",
            "col villaggio al buio la riga va all'ULTIMA porta del giro")
    t.eq(VEGLIA.chi_ha_vegliato(porte, 2, []), "Basilio",
            "una ronda a metà: l'ultima RAGGIUNTA, non l'ultima della lista")
    t.eq(VEGLIA.chi_ha_vegliato(porte, 0, []), "",
            "nessuna tappa fatta: nessuno")
    t.eq(VEGLIA.chi_ha_vegliato([], 5, []), "",
            "un villaggio senza porte non fa vegliare nessuno (nessun crash)")
    t.eq(VEGLIA.chi_ha_vegliato(porte, 99, []), "Cedro",
            "…e più tappe che porte non sfora la lista (i ritrovi vengono dopo)")

    # LA LEVA DEL GIOCATORE: una luce costruita davanti a quella porta
    var lampione := [Vector3(40, 0, 0)]
    t.eq(VEGLIA.chi_ha_vegliato(porte, 3, lampione), "Basilio",
            "un lampione davanti all'ultima porta sposta la riga su quella prima")
    var tutto_acceso := [Vector3(0, 0, 0), Vector3(20, 0, 0), Vector3(40, 0, 0)]
    t.eq(VEGLIA.chi_ha_vegliato(porte, 3, tutto_acceso), "",
            "IL SILENZIO: col villaggio già illuminato dal giocatore la"
            + " guardia non ha vegliato su nessuno che ne avesse bisogno")
    # stessa regola di al_buio: conta la distanza sul piano, non la quota
    t.eq(VEGLIA.chi_ha_vegliato(porte, 3, [Vector3(40, 6, 0)]), "Basilio",
            "…e la luce sale: la quota non conta")


## LE LUCI SI CONTANO GIUSTE — e la ronda NON si legge dalle lanterne.
##
## `DayNight.MORNING` e `Veglia.ORA_ALBA` sono lo stesso numero (0.29): le
## lanterne sopravvivono al rendiconto del mattino solo perché DayNight sta
## PRIMA di Veglia fra i fratelli e `_spegni()` chiede `ora > ORA_ALBA`
## stretto. Far dipendere dall'ordine dei nodi un dato che finisce nei drive
## (e quindi nel salvataggio) è un guasto che aspetta solo che qualcuno
## trascini un nodo. Perciò le lanterne della ronda si contano da `_tappe`,
## che è un dato puro — e questa prova lo dimostra spegnendole prima.
func _test_le_luci_si_contano_giuste(t) -> void:
    var b := GESTI.banco(t)
    var veg = b["veg"]
    var dn = b["dn"]
    dn.time = VEGLIA.ORA_RONDA
    for i in 12:
        veg.call("_process", 10.0)
    var accese: int = (veg.get("_lanterne") as Array).size()
    t.ok(accese > 0, "la ronda ha acceso le sue lanterne")
    t.eq((veg.call("luci_della_ronda") as Array).size(), accese,
            "le luci della ronda sono le tappe percorse")
    t.eq((veg.call("luci_costruite") as Array).size(), 0,
            "e nessuna luce è COSTRUITA: il giocatore non ne ha posate")

    # il giocatore posa un lampione: entra fra le costruite, non fra la ronda
    GESTI.accendi_lampione(b, Vector3(0, 0, 0))
    t.eq((veg.call("luci_costruite") as Array).size(), 1,
            "un Lampione posato conta come luce costruita")
    t.eq((veg.call("luci_del_villaggio") as Array).size(), accese + 1,
            "e il totale è la somma delle due: nessuna luce contata due volte")

    # ALL'ALBA le lanterne si congedano — ma il conto della notte resta
    veg.call("_spegni")
    t.eq((veg.get("_lanterne") as Array).size(), 0, "all'alba le lanterne si spengono")
    t.eq((veg.call("luci_della_ronda") as Array).size(), accese,
            "…e la ronda si racconta lo stesso: si legge da `_tappe`, non"
            + " dalle lanterne vive — o basterebbe spostare un nodo per"
            + " cambiare quello che finisce nei drive")


func _test_il_dono(t) -> void:
    t.ok(VEGLIA.dono_di_sicurezza(1.0) > 0.0, "una notte vegliata dona sicurezza")
    t.ok(VEGLIA.dono_di_sicurezza(0.55) < VEGLIA.dono_di_sicurezza(1.0),
            "meno resa, meno dono")
    t.almost(VEGLIA.dono_di_sicurezza(0.0), 0.0, "resa zero, nessun dono")
    # IL PUNTO DELLA TARATURA: il dono deve poter COPRIRE il buio, o vegliare
    # non servirebbe a niente; e deve battere il rientro passivo, o non si
    # distinguerebbe dal semplice passare del tempo
    t.ok(VEGLIA.dono_di_sicurezza(1.0) > VEGLIA.BUIO_SICUREZZA,
            "una notte vegliata ripaga più di quanto costi una notte al buio")
    var rientro: float = float(ANIMO.RIENTRO["sicurezza"]) * 0.5
    t.ok(VEGLIA.dono_di_sicurezza(1.0) > rientro,
            "…e più del rientro passivo di una giornata qualunque")


# ------------------------------------------------- il buio non è una punizione

func _test_il_buio_non_punisce(t) -> void:
    # la regola cozy: il buio pesa un poco, ma da solo non deve MAI portare
    # nessuno alla ribellione. Il pavimento è la garanzia.
    t.ok(VEGLIA.SICUREZZA_MINIMA > 0.0, "il buio ha un pavimento")
    t.ok(VEGLIA.BUIO_SICUREZZA <= 0.15, "e pesa poco per volta")

    # la prova vera: un chibi lasciato al buio per un mese non si ribella
    var animo = ANIMO.new()
    animo.setup({"sogno": "cuoco", "tratti": {"orgoglio": 0.5, "lealta": 0.5,
            "grinta": 0.5, "codardia": 0.5, "ambizione": 0.5}})
    for giorno in 30:
        var d: Dictionary = animo.get("drive")
        d["sicurezza"] = maxf(float(d["sicurezza"]) - VEGLIA.BUIO_SICUREZZA,
                VEGLIA.SICUREZZA_MINIMA)
        animo.passa_giorno()
        animo.aggiorna_scala()
    t.ok(float((animo.get("drive") as Dictionary)["sicurezza"]) >= VEGLIA.SICUREZZA_MINIMA,
            "trenta notti al buio non portano la sicurezza sotto il pavimento")
    t.eq(str(animo.stato()), "lavoro",
            "…e non fanno salire di un gradino la scala della ribellione")


# -------------------------------------------------- il ramo che mancava

func _test_il_ramo_che_mancava(t) -> void:
    var fonte := FileAccess.get_file_as_string("res://scenes/npc/Lavori.gd")
    # il difetto originale: nel match della produzione mancava "guardia".
    # Qui si controlla che ci sia, e che chiami la Veglia.
    t.ok(fonte.contains('"guardia":'), "il registro ha il ramo della guardia")
    t.ok(fonte.contains("rendiconto_del_mattino"),
            "…e al mattino raccoglie quello che la notte ha lasciato")
    t.ok(fonte.contains("func chi_fa("),
            "il registro sa dire chi ha l'incarico stanotte")
    # TUTTI i lavori assegnabili producono qualcosa: se qualcuno ne aggiunge
    # uno e si dimentica il ramo, ricasca nello stesso difetto
    var produzione := fonte.substr(fonte.find("func _produzione_del_giorno"),
            fonte.find("func _racconta_produzione") - fonte.find("func _produzione_del_giorno"))
    for lavoro in LAVORI.ORDINE:
        if str(lavoro) == "":
            continue
        t.ok(produzione.contains('"%s"' % lavoro),
                "il lavoro '%s' ha il suo ramo nella produzione" % lavoro)


func _test_i_fili(t) -> void:
    # i canali che la veglia usa devono esistere davvero su Visitors, o il
    # dono cadrebbe nel vuoto senza un errore
    var vis := FileAccess.get_file_as_string("res://scenes/npc/Visitors.gd")
    for metodo in ["func dona_drive(", "func ricorda_per(", "func lega_vicini("]:
        t.ok(vis.contains(metodo), "Visitors offre '%s'" % metodo.replace("func ", ""))
    # il ricordo va intestato alla GUARDIA, mai al giocatore: in Animo i
    # ricordi buoni scontano i cattivi, e col nome sbagliato una notte di
    # veglia comprerebbe il perdono dell'intero villaggio
    var veg := FileAccess.get_file_as_string("res://scenes/npc/Veglia.gd")
    t.ok(veg.contains('"ricorda_per", label, "vegliato", _guardia'),
            "il ricordo della veglia è intestato alla guardia, non al giocatore")
    t.ok(not veg.contains('"giocatore"'),
            "…e il giocatore non c'entra nulla con questo credito")
    # le lanterne sono EFFIMERE: mai salvate, mai persistabili. (Si cerca
    # il GESTO, non la parola: "persistable" compare nel commento che
    # spiega perché NON si fa — ed è il tipo di falso allarme che rende
    # inutile un controllo sul sorgente.)
    t.ok(not veg.contains('add_to_group("persistable")'),
            "la veglia non entra fra i nodi che si salvano")
    t.ok(not veg.contains("func save_extra"),
            "…e non scrive niente nel villaggio salvato")
    t.ok(veg.contains("func _spegni"), "…e all'alba si spengono")
    # la Veglia è in scena (senza, il ramo del registro non trova nessuno)
    var scena := FileAccess.get_file_as_string("res://scenes/levels/MainLevel.tscn")
    t.ok(scena.contains("Veglia.gd"), "la Veglia è cablata nel livello")
