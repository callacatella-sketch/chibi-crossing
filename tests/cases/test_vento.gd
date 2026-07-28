extends RefCounted
## L'ARIA DEL MONDO (shaders/vento.gdshaderinc + le chiome nel vento).
##
## Un vento non si prova con un'asserzione: è movimento, e si guarda. Qui
## si difende quello che a occhio NON si vede — che la folata sia una
## sola per erba e chiome (se qualcuno rimette un numero a mano da una
## parte, il mondo torna ad avere due arie), che ogni famiglia di fronde
## abbia il suo piegamento, e che l'attaccatura al ramo resti inchiodata.

const WEATHER := preload("res://scenes/world/Weather.gd")
const COZY := preload("res://scenes/world/CozyWorld.gd")
const GEO := preload("res://scenes/world/WorldGeo.gd")

const INCLUDE := "res://shaders/vento.gdshaderinc"


func run(t) -> void:
    _test_una_sola_aria(t)
    _test_le_chiome_hanno_il_vento(t)
    _test_ogni_fronda_il_suo_piegamento(t)
    _test_il_vento_segue_il_cielo(t)
    _test_il_globale_esiste(t)


# ------------------------------------------------------- una sola aria

func _test_una_sola_aria(t) -> void:
    var inc := _sorgente(INCLUDE)
    t.ok(inc != "", "il file dell'aria condivisa esiste")
    for pezzo in ["VENTO_DIR", "VENTO_SPAZIO", "VENTO_TEMPO",
            "vento_folata", "vento_direzione", "vento_fase"]:
        t.ok(inc.contains(pezzo), "l'aria condivisa offre '%s'" % pezzo)

    # ENTRAMBI gli shader devono pescare di lì: è tutto il punto
    var erba := _sorgente("res://shaders/grass_blade.gdshader")
    var dipinto := _sorgente("res://shaders/handpaint.gdshader")
    t.ok(erba.contains('#include "%s"' % INCLUDE), "l'erba usa l'aria condivisa")
    t.ok(dipinto.contains('#include "%s"' % INCLUDE), "le chiome usano l'aria condivisa")
    t.ok(erba.contains("vento_folata("), "l'erba si piega sulla folata comune")
    t.ok(dipinto.contains("vento_folata("), "le chiome si piegano sulla stessa folata")
    # e nessuno dei due deve ricalcolarsela per conto suo: la vecchia
    # formula inline (smoothstep sull'onda) non deve tornare
    t.ok(not erba.contains("smoothstep(0.10, 0.95"),
            "l'erba non tiene più una copia sua della folata")
    t.ok(erba.count("vento_direzione()") >= 1, "e nemmeno una direzione sua")


# --------------------------------------------------- le chiome si muovono

func _test_le_chiome_hanno_il_vento(t) -> void:
    var dipinto := _sorgente("res://shaders/handpaint.gdshader")
    for pezzo in ["uniform float chioma", "uniform float chioma_base",
            "uniform float chioma_span"]:
        t.ok(dipinto.contains(pezzo), "il materiale dipinto conosce '%s'" % pezzo)
    # l'ATTACCATURA AL RAMO: sotto chioma_base non ci si muove, o le foglie
    # si staccano dal tronco (il difetto classico del vento a vertici)
    t.ok(dipinto.contains("(VERTEX.y - chioma_base)"),
            "il piegamento parte dall'attaccatura, non da terra")
    # i lobi esterni ballano più del cuore, o la chioma sembra un palloncino
    t.ok(dipinto.contains("length(VERTEX.xz)"),
            "i lobi esterni si piegano più del cuore della chioma")
    # la fase viene da DOVE è piantato: due alberi vicini non all'unisono
    t.ok(dipinto.contains("vento_fase(MODEL_MATRIX[3].xz)"),
            "ogni albero ha la sua fase, dal punto in cui è piantato")
    # piegandosi la chioma scende: è una rotazione, non una traslazione
    t.ok(dipinto.contains("VERTEX.y -= abs(piega)"),
            "la chioma che si piega scende un poco (ruota, non scivola)")
    # e il vecchio vento locale di erbette e bucato resta intatto
    t.ok(dipinto.contains("wind_strength > 0.0"),
            "l'ondina locale di erbette e bucato non è stata toccata")


func _test_ogni_fronda_il_suo_piegamento(t) -> void:
    # una conifera piegata come un salice sembra di gomma: le famiglie di
    # fronde hanno ampiezze diverse, ed è una scelta, non un caso
    var tab: Dictionary = COZY.VENTO_CHIOMA
    for klass in ["green", "cherry", "needle", "bush"]:
        t.ok(tab.has(klass), "il vento conosce le fronde '%s'" % klass)
        t.ok(float(tab[klass]) > 0.0, "le fronde '%s' si muovono davvero" % klass)
        t.ok(float(tab[klass]) < 0.3, "le fronde '%s' non impazziscono" % klass)
    t.ok(float(tab["cherry"]) > float(tab["needle"]),
            "il ciliegio è più leggero di una conifera")
    t.ok(float(tab["needle"]) > float(tab["bush"]),
            "e un cespuglio freme meno di una conifera")

    # il cablaggio: TUTTO il fogliame passa da _register_leaf, ed è lì che
    # riceve il vento. Se qualcuno registra una fronda nuova, la riceve
    # anche lei — ma se qualcuno toglie quella riga, il mondo torna immobile
    var fonte := _sorgente("res://scenes/world/CozyWorld.gd")
    t.ok(fonte.contains("mat.set_shader_parameter(\"chioma\", VENTO_CHIOMA"),
            "ogni fronda registrata riceve il suo vento")
    # e i richiami passano l'attaccatura giusta (le mesh sono fatte diverse)
    t.ok(fonte.contains("\"needle\", 1.4, 2.8"), "le conifere hanno la loro attaccatura")
    t.ok(fonte.contains("\"green\", 2.7, 1.6"), "le latifoglie del bosco la loro")
    t.ok(fonte.contains("leaf_klass, 0.0, 1.15"), "le chiome del prato la loro")


# ---------------------------------------------------- il vento e il cielo

func _test_il_vento_segue_il_cielo(t) -> void:
    var sereno: float = WEATHER.forza_del_vento("clear", false, false)
    var pioggia: float = WEATHER.forza_del_vento("rain", false, false)
    var neve: float = WEATHER.forza_del_vento("rain", true, false)
    var nebbia: float = WEATHER.forza_del_vento("clear", false, true)
    var dopo: float = WEATHER.forza_del_vento("rainbow", false, false)

    t.almost(sereno, 1.0, "il sereno è la brezza di riferimento")
    t.ok(pioggia > sereno, "col temporale in arrivo il mondo si muove di più")
    t.ok(neve < pioggia, "ma la neve scende piano: meno vento della pioggia")
    t.ok(nebbia < sereno, "nella nebbia l'aria si ferma")
    t.ok(nebbia > 0.0, "…ferma, non morta: un filo resta sempre")
    t.ok(dopo < sereno, "dopo l'acquazzone il mondo tira il fiato")
    # la nebbia vince su tutto: è lei a decidere quando l'aria è ferma
    t.almost(WEATHER.forza_del_vento("rain", false, true), nebbia,
            "con la nebbia il vento è quello della nebbia, comunque")

    # il filo col mondo: il numero deve arrivare al globale, o resta teoria
    var fonte := _sorgente("res://scenes/world/Weather.gd")
    t.ok(fonte.contains("global_shader_parameter_set(\"vento_forza\""),
            "il vento del momento arriva davvero agli shader")
    t.ok(fonte.contains("lerpf(_vento"), "e ci arriva per gradi (un vento che scatta si vede)")


func _test_il_globale_esiste(t) -> void:
    # senza la dichiarazione in project.godot, `global uniform float
    # vento_forza` non compila e TUTTO il mondo dipinto resta grigio
    var proj := _sorgente("res://project.godot")
    t.ok(proj.contains("vento_forza="), "il globale del vento è dichiarato nel progetto")
    var valore: Variant = ProjectSettings.get_setting("shader_globals/vento_forza")
    t.ok(valore != null, "e il progetto lo espone davvero")
    if valore is Dictionary:
        t.eq(str((valore as Dictionary).get("type", "")), "float", "è un numero")

    # e il materiale dipinto nasce SENZA vento: una chioma è tale solo se
    # qualcuno lo dichiara (i sassi e i tetti non devono ondeggiare)
    var mat: ShaderMaterial = GEO.paint_mat(Color.WHITE, Color.BLACK)
    var ch: Variant = mat.get_shader_parameter("chioma")
    t.ok(ch == null or float(ch) == 0.0, "un materiale qualunque non è una chioma")


static func _sorgente(percorso: String) -> String:
    return FileAccess.get_file_as_string(percorso)
