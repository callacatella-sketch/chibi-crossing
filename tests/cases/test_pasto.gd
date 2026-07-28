extends RefCounted
## IL RITUALE DEL PASTO (scenes/npc/Pasto.gd).
##
## Il ritmo di un'animazione è la cosa che non si verifica a occhio: per
## beccare il fotogramma sbagliato bisognerebbe regalare cento zuppe e
## guardare. Qui invece la coreografia è una tabella di tempi, e si
## interroga: le battute si toccano senza buchi, i morsi cadono dentro la
## battuta dei morsi, il cibo cala a scatti fino a zero, la ciotola non
## salta mai da un'altezza all'altra.

const PASTO := preload("res://scenes/npc/Pasto.gd")
const VISITOR := preload("res://scenes/npc/Visitor.gd")


func run(t) -> void:
    _test_tappe(t)
    _test_freddo_salta_il_soffio(t)
    _test_fase(t)
    _test_morsi(t)
    _test_cibo(t)
    _test_alzata_continua(t)
    _test_fabbriche(t)
    _test_il_filo_col_corpo(t)


# ------------------------------------------------------------- le battute

func _test_tappe(t) -> void:
    for caldo in [true, false]:
        var tappe: Array = PASTO.tappe(caldo)
        t.ok(tappe.size() >= 5, "caldo=%s: il rituale ha tutte le battute" % caldo)
        var somma := 0.0
        for tappa in tappe:
            t.ok(str(tappa[0]) != "", "ogni battuta ha un nome")
            t.ok(float(tappa[1]) > 0.0, "la battuta '%s' dura davvero" % tappa[0])
            somma += float(tappa[1])
        t.almost(PASTO.durata(caldo), somma, "caldo=%s: la durata è la somma" % caldo)
    # né troppo svelto (sembra un bug) né troppo lento (annoia)
    t.ok(PASTO.durata(true) > 3.0, "il pasto caldo non è sbrigativo")
    t.ok(PASTO.durata(true) < 7.0, "e non diventa un cortometraggio")
    # l'ordine racconta la storia giusta: prima si prende, poi si mangia,
    # e il grazie arriva DOPO l'assaggio
    t.ok(PASTO.inizio_di("prende", true) < PASTO.inizio_di("annusa", true),
            "prima si prende, poi si annusa")
    t.ok(PASTO.inizio_di("annusa", true) < PASTO.inizio_di("morsi", true),
            "si annusa prima di mordere")
    t.ok(PASTO.inizio_di("morsi", true) < PASTO.inizio_di("sospiro", true),
            "il sospiro (e il grazie) viene DOPO i morsi")
    t.ok(PASTO.inizio_di("sospiro", true) < PASTO.inizio_di("posa", true),
            "e la ciotola si posa per ultima")
    t.almost(PASTO.inizio_di("prende", true), 0.0, "si comincia dal principio")
    t.almost(PASTO.inizio_di("inesistente", true), -1.0, "battuta sconosciuta -> -1")


func _test_freddo_salta_il_soffio(t) -> void:
    # non si soffia su un tè freddo
    t.ok(PASTO.inizio_di("soffia", true) > 0.0, "sul caldo si soffia")
    t.almost(PASTO.inizio_di("soffia", false), -1.0, "sul freddo no")
    t.ok(PASTO.durata(false) < PASTO.durata(true), "il pasto freddo è più corto")
    for tappa in PASTO.tappe(false):
        t.ok(str(tappa[0]) != "soffia", "nessun soffio tra le battute fredde")
    # ma tutte le ALTRE battute restano: il freddo non è un pasto mutilato
    for nome in ["prende", "annusa", "morsi", "sospiro", "posa"]:
        t.ok(PASTO.inizio_di(nome, false) >= 0.0,
                "il pasto freddo conserva la battuta '%s'" % nome)


func _test_fase(t) -> void:
    for caldo in [true, false]:
        t.eq(PASTO.fase(-1.0, caldo), "", "prima di cominciare: nessuna battuta")
        t.eq(PASTO.fase(0.0, caldo), "prende", "al via si prende la ciotola")
        t.eq(PASTO.fase(PASTO.durata(caldo) + 0.1, caldo), "fine", "dopo la fine: 'fine'")
        # nessun BUCO: campionando fitto, ogni istante ha la sua battuta
        var passo := 0.02
        var tempo := 0.0
        while tempo < PASTO.durata(caldo) - 0.001:
            var f := PASTO.fase(tempo, caldo)
            t.ok(f != "" and f != "fine",
                    "caldo=%s: t=%.2f cade dentro una battuta (%s)" % [caldo, tempo, f])
            tempo += passo
        # l'avanzamento resta nel suo recinto
        tempo = 0.0
        while tempo < PASTO.durata(caldo):
            var a := PASTO.avanzamento(tempo, caldo)
            t.ok(a >= 0.0 and a <= 1.0, "avanzamento in [0,1] a t=%.2f" % tempo)
            tempo += 0.05


# ------------------------------------------------------------------ i morsi

func _test_morsi(t) -> void:
    t.eq(PASTO.MORSI, 3, "tre morsetti, come Mochi")
    for caldo in [true, false]:
        var da := PASTO.inizio_di("morsi", caldo)
        var fino := da
        for tappa in PASTO.tappe(caldo):
            if str(tappa[0]) == "morsi":
                fino = da + float(tappa[1])
        var prima := -1.0
        for i in PASTO.MORSI:
            var m: float = PASTO.momento_morso(i, caldo)
            t.ok(m > da and m < fino,
                    "caldo=%s: il morso %d cade dentro la sua battuta" % [caldo, i])
            t.ok(m > prima, "caldo=%s: i morsi sono in ordine (%d)" % [caldo, i])
            prima = m
        # il primo morso non parte sull'istante (serve un respiro dopo il soffio)
        t.ok(PASTO.momento_morso(0, caldo) - da > 0.1,
                "caldo=%s: il primo morso si fa attendere un attimo" % caldo)
    # lo scatto del morso è un picco: 0 lontano, 1 sull'istante del morso
    var mm: float = PASTO.momento_morso(1, true)
    t.almost(PASTO.scatto_morso(mm, true), 1.0, "sul morso lo scatto è pieno")
    t.almost(PASTO.scatto_morso(mm - 1.0, true), 0.0, "lontano dal morso: niente scatto")
    for i in PASTO.MORSI:
        t.almost(PASTO.momento_morso(i, true), PASTO.momento_morso(i, true),
                "il momento del morso è deterministico")


# ------------------------------------------------------------------ il cibo

func _test_cibo(t) -> void:
    for caldo in [true, false]:
        t.almost(PASTO.cibo(0.0, caldo), 1.0, "caldo=%s: si comincia con la ciotola piena" % caldo)
        t.almost(PASTO.cibo(PASTO.durata(caldo), caldo), 0.0,
                "caldo=%s: alla fine è vuota" % caldo)
        # cala e non risale MAI (una ciotola che si riempie da sola è un bug
        # che a occhio non si vede)
        var prima := 2.0
        var tempo := 0.0
        while tempo <= PASTO.durata(caldo):
            var q: float = PASTO.cibo(tempo, caldo)
            t.ok(q <= prima + 0.0001, "caldo=%s: il cibo non risale (t=%.2f)" % [caldo, tempo])
            t.ok(q >= 0.0 and q <= 1.0, "caldo=%s: il cibo resta in [0,1]" % caldo)
            prima = q
            tempo += 0.05
        # e cala A SCATTI: subito dopo ogni morso ne manca esattamente un terzo
        for i in PASTO.MORSI:
            var dopo: float = PASTO.cibo(PASTO.momento_morso(i, caldo) + 0.01, caldo)
            t.almost(dopo, 1.0 - float(i + 1) / float(PASTO.MORSI),
                    "caldo=%s: dopo il morso %d ne resta la parte giusta" % [caldo, i], 0.02)


func _test_alzata_continua(t) -> void:
    # LA CIOTOLA NON SALTA: tra un fotogramma e l'altro l'altezza cambia
    # poco. Un salto vorrebbe dire due battute che non si passano il
    # testimone — il difetto tipico delle animazioni a tabella.
    for caldo in [true, false]:
        var passo := 1.0 / 60.0
        var tempo := 0.0
        var prima: float = PASTO.alzata(0.0, caldo)
        while tempo <= PASTO.durata(caldo):
            var a: float = PASTO.alzata(tempo, caldo)
            # a 60 fotogrammi il gesto più rapido (lo scatto del morso) sposta
            # circa 0.06 per fotogramma: oltre 0.15 non è più un movimento,
            # è un TAGLIO tra due battute che non si passano il testimone
            t.ok(absf(a - prima) < 0.15,
                    "caldo=%s: la ciotola non salta a t=%.2f (%.3f -> %.3f)"
                    % [caldo, tempo, prima, a])
            t.ok(a >= 0.0 and a <= 1.0, "caldo=%s: l'alzata resta in [0,1]" % caldo)
            prima = a
            tempo += passo
        t.almost(PASTO.alzata(0.0, caldo), 0.0, "si parte dalla posa di riposo")
        t.almost(PASTO.alzata(PASTO.durata(caldo), caldo), 0.0, "e ci si torna")
        # e sul morso arriva DAVVERO al musetto, o il gesto non si legge
        t.almost(PASTO.alzata(PASTO.momento_morso(1, caldo), caldo), 1.0,
                "caldo=%s: sul morso la ciotola tocca il musetto" % caldo)


# --------------------------------------------------------------- le fabbriche

func _test_fabbriche(t) -> void:
    var briciole = PASTO.briciole(Color("e8944a"))
    t.ok(briciole is GPUParticles3D, "le briciole sono particelle")
    t.ok(briciole.one_shot, "le briciole sono uno sbuffo solo, non un rubinetto")
    t.ok(briciole.amount > 0, "e sono davvero delle briciole")
    briciole.free()
    var vapore = PASTO.vapore()
    t.ok(vapore is GPUParticles3D, "il vapore è particelle")
    t.ok(not vapore.one_shot, "il vapore sale finché il piatto è caldo")
    vapore.free()
    var sbuffo = PASTO.sbuffo()
    t.ok(sbuffo.one_shot, "lo sbuffo del soffio è un colpo solo")
    t.ok(sbuffo.lifetime < vapore.lifetime + 1.0, "e si perde subito")
    sbuffo.free()


# ----------------------------------------------------- il filo con il corpo
# Il rituale è inutile se il vicino non sa recitarlo: qui si controlla che
# il cablaggio esista ancora (i nomi cambiano, i fili si staccano in
# silenzio, e il piatto tornerebbe a svanire a mezz'aria).

func _test_il_filo_col_corpo(t) -> void:
    var visitor := VISITOR.new()
    t.ok(visitor.has_method("mangia"), "il vicino sa mangiare")
    visitor.free()
    var fonte := _sorgente("res://scenes/npc/Visitor.gd")
    t.ok(fonte.contains("\"r_pasto\""), "e ha lo stato che gli tiene il corpo")
    t.ok(fonte.contains("_pasto_recita"), "con la sua recita")
    t.ok(fonte.contains("Pasto.gd"), "che pesca i tempi dal rituale condiviso")
    # IL RECINTO. Alla prima prova in scena la routine dei residenti rubava
    # lo stato dopo un secondo e il vicino se ne andava a spasso con la
    # ciotola incollata al petto: senza queste due guardie ci ricasca.
    t.ok(fonte.contains("_pasto_occupa"), "il pasto ha il suo recinto")
    t.ok(fonte.contains("if _pasto_occupa(s):"),
            "nessuno gli cambia stato mentre mangia")
    t.ok(fonte.contains("if _pasto_in_corso:\n\t\treturn"),
            "e nessuno lo manda a passeggio mentre mangia")
    # e il recinto deve potersi aprire da solo, o un vicino nascosto a
    # metà morso non camminerebbe mai più
    t.ok(fonte.contains("create_timer(PASTO.durata(caldo) + 4.0)"),
            "il recinto ha la sua rete di sicurezza")
    # la ciotola sta alle ZAMPINE misurate (non a una quota indovinata:
    # il DNA cambia statura e la ciotola finirebbe in faccia ai piccoli)
    t.ok(fonte.contains("_pasto_zampe_y"), "la ciotola si posa sulle zampine vere")
    # e chi regala deve consegnargliela davvero, invece di farla sparire
    var doni := _sorgente("res://scenes/npc/Visitors.gd")
    t.ok(doni.contains("\"mangia\""), "il dono finisce tra le zampe di chi lo riceve")
    t.eq(doni.count("node.call(\"mangia\""), 2,
            "sia il piatto del camino sia la porzione delle Tasche")


static func _sorgente(percorso: String) -> String:
    return FileAccess.get_file_as_string(percorso)
