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


func run(t) -> void:
    _test_bestiario_coerente(t)
    _test_nomi_derivati(t)
    _test_elenchi(t)
    _test_scala_unica(t)
    _test_tabelle_parallele_della_scala(t)


# ------------------------------------------------------------- bestiario

func _test_bestiario_coerente(t) -> void:
    t.ok(CRIT.SPECIE.size() >= 11, "il bestiario ha tutte le specie")
    var classi_valide := ["farfalla", "lucciola", "pesce", "raccolto"]
    for id in CRIT.SPECIE:
        var v: Dictionary = CRIT.SPECIE[id]
        # ogni voce è COMPLETA: un campo mancante è un dato che diverge
        for campo in ["nome", "articolo", "classe", "colore", "vendita", "rara"]:
            t.ok(v.has(campo), "%s ha il campo %s" % [id, campo])
        t.ok(str(v.get("classe", "")) in classi_valide, "%s ha una classe valida" % id)
        t.ok(str(v.get("articolo", "")) in ["un", "una"], "%s ha un articolo valido" % id)
        t.ok(int(v.get("vendita", 0)) > 0, "%s ha un valore di vendita > 0" % id)
        # il nome è minuscolo e senza articolo: le due forme si derivano
        var nome := str(v.get("nome", ""))
        t.ok(nome != "" and nome == nome.to_lower(), "%s: nome minuscolo e non vuoto" % id)
        t.ok(not nome.begins_with("un "), "%s: il nome non include l'articolo" % id)


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
    t.eq(farfalle.size(), 3, "tre farfalle nel prato")
    t.eq(pesci.size(), 3, "tre pesci nello stagno")
    # i barattoli raccolgono farfalle, lucciole e pesci — non i raccolti
    t.eq(coll.size(), farfalle.size() + pesci.size() + 1, "collezionabili = farfalle + pesci + lucciola")
    for id in coll:
        t.ok(CRIT.classe(id) != "raccolto", "%s in collezione non è un raccolto" % id)
    for id in pesci:
        t.eq(CRIT.classe(id), "pesce", "%s è classificato pesce" % id)
    # le rare sono esattamente quelle marcate
    var rare: Array = CRIT.rare()
    for id in rare:
        t.ok(CRIT.rara(id), "%s risulta rara" % id)
    t.eq(rare.size(), 3, "tre specie rare (una stellina ciascuna)")
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
    t.eq(ANIMO.SOGLIA.size(), ANIMO.SCALA.size(), "SOGLIA non ha gradini fantasma")
    t.eq(ANIMO.TELEGRAFO.size(), ANIMO.SCALA.size(), "TELEGRAFO non ha gradini fantasma")
    # le soglie salgono monotone lungo la scala: una scala che torna indietro
    # farebbe scattare due gradini insieme
    var prev := -1.0
    for g in ANIMO.SCALA:
        var s := float(ANIMO.SOGLIA[g])
        t.ok(s >= prev, "la soglia di '%s' non scende" % g)
        prev = s
