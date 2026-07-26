extends RefCounted
## Test delle FONTI UNICHE di verità (allocazione dei dati).
##
## Questi test non provano un comportamento: proteggono un'ALLOCAZIONE. Prima
## le tabelle delle specie vivevano in tre file e la scala della ribellione in
## quattro, e avevano già cominciato a divergere in silenzio (la stessa
## farfalla con due nomi e due rosa diversi). Se qualcuno reintroduce una
## copia, o aggiunge una specie/un gradino dimenticando una tabella parallela,
## questi test lo dicono subito.

const CRIT := preload("res://scenes/world/Critters.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")
const LAVORI := preload("res://scenes/npc/Lavori.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")


func run(t) -> void:
    _test_bestiario_coerente(t)
    _test_nomi_derivati(t)
    _test_elenchi(t)
    _test_scala_unica(t)
    _test_tabelle_parallele_della_scala(t)
    _test_dna_usa_i_vocabolari_dell_animo(t)


# ------------------------------------------------------------- bestiario

func _test_bestiario_coerente(t) -> void:
    t.ok(CRIT.SPECIE.size() >= 25, "il bestiario ha tutte le specie")
    var classi_valide := ["farfalla", "lucciola", "pesce", "bestiola", "raccolto"]
    var ore_valide := ["giorno", "notte", "crepuscolo"]
    var meteo_validi := ["pioggia", "neve"]
    var luoghi_validi := ["prato", "bosco", "stagno"]
    for id in CRIT.SPECIE:
        var v: Dictionary = CRIT.SPECIE[id]
        # ogni voce è COMPLETA: un campo mancante è un dato che diverge
        for campo in ["nome", "articolo", "classe", "colore", "vendita", "rara"]:
            t.ok(v.has(campo), "%s ha il campo %s" % [id, campo])
        t.ok(str(v.get("classe", "")) in classi_valide, "%s ha una classe valida" % id)
        t.ok(str(v.get("articolo", "")) in ["un", "una", "uno"], "%s ha un articolo valido" % id)
        t.ok(int(v.get("vendita", 0)) > 0, "%s ha un valore di vendita > 0" % id)
        # il nome è minuscolo e senza articolo: le due forme si derivano
        var nome := str(v.get("nome", ""))
        t.ok(nome != "" and nome == nome.to_lower(), "%s: nome minuscolo e non vuoto" % id)
        t.ok(not nome.begins_with("un "), "%s: il nome non include l'articolo" % id)
        # i campi FACOLTATIVI, se ci sono, usano i vocabolari giusti: una
        # stagione 4 o un'ora "sera" non darebbero errore, solo una specie
        # che non nasce mai (o nasce sempre) — in silenzio
        if v.has("cond"):
            var cond: Dictionary = v["cond"]
            t.ok(not cond.is_empty(), "%s: cond presente ma vuota" % id)
            for chiave in cond:
                t.ok(str(chiave) in ["stagioni", "ora", "meteo"],
                        "%s: chiave cond '%s' conosciuta" % [id, chiave])
            if cond.has("stagioni"):
                for s in cond["stagioni"]:
                    t.ok(int(s) >= 0 and int(s) <= 3, "%s: stagione %s valida" % [id, s])
            if cond.has("ora"):
                t.ok(str(cond["ora"]) in ore_valide, "%s: ora valida" % id)
            if cond.has("meteo"):
                t.ok(str(cond["meteo"]) in meteo_validi, "%s: meteo valido" % id)
        if v.has("luogo"):
            t.ok(str(v["luogo"]) in luoghi_validi, "%s: luogo valido" % id)
        if v.has("peso"):
            t.ok(float(v["peso"]) > 0.0, "%s: peso positivo" % id)
        if v.has("max"):
            t.ok(int(v["max"]) >= 1, "%s: max almeno 1" % id)
        # ogni specie della collezione ha il suo indizio: la sagoma grigia
        # dell'enciclopedia deve sempre saper dire dove cercare
        if str(v.get("classe", "")) in CRIT.CLASSI_COLLEZIONE:
            t.ok(str(v.get("indizio", "")) != "", "%s ha l'indizio per l'enciclopedia" % id)


func _test_nomi_derivati(t) -> void:
    # LA divergenza che ha motivato il bestiario: negozio e collezione devono
    # parlare della stessa farfalla con lo stesso nome.
    t.eq(CRIT.etichetta("gialla"), "Farfalla dorata", "etichetta da bancone")
    t.eq(CRIT.con_articolo("gialla"), "una farfalla dorata", "etichetta dentro una frase")
    t.eq(CRIT.etichetta("azzurrino"), "Pesciolino azzurro", "maiuscola solo sulla prima lettera")
    t.eq(CRIT.con_articolo("azzurrino"), "un pesciolino azzurro", "articolo maschile rispettato")
    # le due forme dicono LO STESSO nome, per costruzione
    for id in CRIT.SPECIE:
        var n := CRIT.nome(id)
        t.ok(CRIT.etichetta(id).to_lower() == n, "%s: etichetta e nome coincidono" % id)
        t.ok(CRIT.con_articolo(id).ends_with(n), "%s: con_articolo contiene il nome" % id)
    # id sconosciuto: nessun crash, si degrada sull'id
    t.eq(CRIT.etichetta("inesistente"), "inesistente", "id sconosciuto -> nessun crash")
    t.ok(not CRIT.rara("inesistente"), "id sconosciuto non è raro")
    t.eq(CRIT.vendita("inesistente"), 1, "id sconosciuto -> valore di ripiego")


func _test_elenchi(t) -> void:
    var coll: Array = CRIT.collezionabili()
    var pesci: Array = CRIT.pesci()
    var farfalle: Array = CRIT.farfalle()
    var lucciole: Array = CRIT.lucciole()
    var bestiole: Array = CRIT.bestiole()
    t.eq(farfalle.size(), 7, "sette farfalle nel prato (tre di sempre + quattro stagionali)")
    t.eq(pesci.size(), 7, "sette pesci nello stagno (tre di sempre + quattro stagionali)")
    t.eq(lucciole.size(), 2, "due lucciole (quella di sempre e la regale)")
    t.eq(bestiole.size(), 4, "quattro bestiole (cicala, scarabeo, lumachina, rana)")
    # i barattoli raccolgono farfalle, lucciole, pesci e bestiole — non i raccolti
    t.eq(coll.size(), farfalle.size() + pesci.size() + lucciole.size() + bestiole.size(),
            "collezionabili = farfalle + pesci + lucciole + bestiole")
    for id in coll:
        t.ok(CRIT.classe(id) != "raccolto", "%s in collezione non è un raccolto" % id)
    for id in pesci:
        t.eq(CRIT.classe(id), "pesce", "%s è classificato pesce" % id)
    # le rare sono esattamente quelle marcate
    var rare: Array = CRIT.rare()
    for id in rare:
        t.ok(CRIT.rara(id), "%s risulta rara" % id)
    t.eq(rare.size(), 9, "nove specie rare (una stellina ciascuna)")
    # il pallino del negozio è LO STESSO colore, solo più carico
    for id in CRIT.SPECIE:
        var c: Color = CRIT.colore(id)
        var d: Color = CRIT.colore_pallino(id)
        t.almost(d.h, c.h, "%s: il pallino conserva la tinta" % id, 0.02)
        t.ok(d.s >= c.s - 0.001, "%s: il pallino non è meno saturo" % id)


# ---------------------------------------------------------------- la scala

func _test_scala_unica(t) -> void:
    t.eq(ANIMO.SCALA.size(), 8, "la scala ha otto gradini")
    t.eq(ANIMO.indice("lavoro"), 0, "il primo gradino è 'lavoro'")
    t.eq(ANIMO.indice("ammutinamento"), ANIMO.SCALA.size() - 1, "l'ultimo è l'ammutinamento")
    t.eq(ANIMO.indice("inesistente"), -1, "gradino sconosciuto -> -1")
    # `almeno` è il modo per interrogare le soglie PER NOME (prima erano 5 e 6
    # scritti a mano in Visitors: inserire un gradino li spostava in silenzio)
    var i_conf: int = ANIMO.indice("confronto")
    var i_dis: int = ANIMO.indice("diserzione")
    t.ok(i_conf < i_dis, "il confronto viene prima della diserzione")
    t.ok(ANIMO.almeno(i_dis, "confronto"), "chi diserta ha già superato il confronto")
    t.ok(not ANIMO.almeno(i_conf, "diserzione"), "chi si confronta non sta ancora disertando")
    t.ok(ANIMO.almeno(i_conf, "confronto"), "almeno() è inclusivo sul gradino stesso")
    t.ok(not ANIMO.almeno(0, "inesistente"), "soglia inesistente -> mai soddisfatta")
    # frazione: 0 al primo gradino, 1 all'ultimo, sempre in [0,1]
    t.almost(ANIMO.frazione(0), 0.0, "frazione del primo gradino")
    t.almost(ANIMO.frazione(ANIMO.SCALA.size() - 1), 1.0, "frazione dell'ultimo gradino")
    t.almost(ANIMO.frazione(999), 1.0, "frazione clampata in alto")
    t.almost(ANIMO.frazione(-5), 0.0, "frazione clampata in basso")


func _test_tabelle_parallele_della_scala(t) -> void:
    # SOGLIA e TELEGRAFO sono indicizzate per NOME: se si aggiunge un gradino
    # alla scala senza aggiornarle, il gioco degraderebbe in silenzio (soglia
    # 0, telegrafo "sereno"). Qui invece si accorge subito.
    for g in ANIMO.SCALA:
        t.ok(ANIMO.SOGLIA.has(g), "SOGLIA copre il gradino '%s'" % g)
        t.ok(ANIMO.TELEGRAFO.has(g), "TELEGRAFO copre il gradino '%s'" % g)
        # e la tabella che il pannello dei lavori mostra al giocatore: senza
        # questo controllo un gradino nuovo veniva etichettato "sereno" mentre
        # il colore lo mostrava già in rivolta, e i test restavano verdi
        t.ok(LAVORI.STATO_UMANO.has(g), "STATO_UMANO copre il gradino '%s'" % g)
    t.eq(ANIMO.SOGLIA.size(), ANIMO.SCALA.size(), "SOGLIA non ha gradini fantasma")
    t.eq(ANIMO.TELEGRAFO.size(), ANIMO.SCALA.size(), "TELEGRAFO non ha gradini fantasma")
    t.eq(LAVORI.STATO_UMANO.size(), ANIMO.SCALA.size(), "STATO_UMANO non ha gradini fantasma")
    # le soglie salgono monotone lungo la scala: una scala che torna indietro
    # farebbe scattare due gradini insieme
    var prev := -1.0
    for g in ANIMO.SCALA:
        var s := float(ANIMO.SOGLIA[g])
        t.ok(s >= prev, "la soglia di '%s' non scende" % g)
        prev = s


# ---------------------------------------------------------------- il genoma

func _test_dna_usa_i_vocabolari_dell_animo(t) -> void:
    # il DNA tira a sorte sogno e tratti dai vocabolari di Animo (SOGNI,
    # TRATTI): se qualcuno reintroduce le liste inline com'erano, un sogno
    # aggiunto ad Animo.SOGNI non nascerebbe mai in nessun chibi — o peggio,
    # nascerebbe un sogno che l'animo non sa interpretare
    for seed_v in [3, 44, 512]:
        var dna: Dictionary = DNA.generate(seed_v)
        t.ok(str(dna.get("sogno", "")) in ANIMO.SOGNI,
                "seed %d: il sogno '%s' esiste nel vocabolario dell'animo"
                % [seed_v, dna.get("sogno")])
        var tratti: Dictionary = dna.get("tratti", {})
        t.eq(tratti.keys().size(), ANIMO.TRATTI.size(),
                "seed %d: tanti tratti quanti ne conosce l'animo" % seed_v)
        for tr in ANIMO.TRATTI:
            t.ok(tratti.has(tr), "seed %d: il tratto '%s' c'è" % [seed_v, tr])
