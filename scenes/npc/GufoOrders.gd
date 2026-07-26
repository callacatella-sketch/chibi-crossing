extends Node

## Gli Ordini del Gufo — la progressione narrativa del villaggio.
##
## Il Gufo (la voce in-fiction del Regista, vedi Director.gd) guida il
## giocatore con piccoli desideri: "un letto sotto un tetto... arrivera'
## qualcuno". Esaudito un Ordine, si apre una manciata di pezzi nuovi del
## catalogo. La sabbiera diventa un viaggio. Regola d'oro, come per il
## Regista: mai una meccanica nuda — il Gufo sussurra, non da' "missioni".
##
## Il recinto vero (quali pezzi sono disponibili) vive nel BuildSystem;
## qui si decide QUANDO aprirlo. La valutazione di un Ordine e' una
## funzione PURA su un'istantanea del villaggio (satisfied), cosi' e'
## testabile senza SceneTree (vedi tests/cases/test_gufo.gd).
##
## Nodo fratello nella scena (come Mail/Visitors), NON figlio runtime di
## CozyWorld: cosi' e' gia' nel gruppo "persistable" quando BuildSystem
## carica il villaggio (load_extra) all'avvio, e la progressione non si
## azzera a ogni lancio.

const CAT := preload("res://scenes/build/BuildCatalog.gd")

# I pezzi disponibili fin dal primo minuto: il minimo per dare forma a un
# lotto e — soprattutto — la cassetta, senza la quale il Gufo non potrebbe
# scriverti. Tutti gli altri 25 pezzi li aprono gli Ordini, uno scaglione
# alla volta.
const STARTER := ["Pavimento", "Sentiero", "Muro", "Cassetta posta"]

# La campagna: catena di Ordini, ognuno con la sua lettera in-fiction, il
# predicato che lo esaudisce e i pezzi che regala. Progettata e validata a
# parte (copertura dei 25 pezzi, nessun riferimento in avanti, finale =
# Casa albero). Vedi test_gufo.gd per le invarianti verificate in CI.
const CHAIN := [
    {"id": "la-prima-lettera", "title": "La prima lettera", "letter_text": "Ho una cosa da dirti, e nessun posto dove posarla.\nMetti una cassetta accanto al sentiero:\nsarà lì che lascerò le mie parole, all'alba.", "hint": "posa la Cassetta posta", "done_text": "Ecco. Ora ho un posto dove scriverti. Comincia il nostro carteggio.", "predicate": {"type": "has", "name": "Cassetta posta"}, "unlocks": ["Pianta", "Alberello", "Cespuglio", "Fungo"], "celebrate_letter": "Stamattina ho lasciato la prima lettera dentro la tua cassetta. Profumava già di legno e di attesa. Ora tocca a te far crescere qualcosa di verde intorno."},
    {"id": "qualcosa-di-verde", "title": "Qualcosa di verde", "letter_text": "La terra qui è nuda e un po' timida.\nPianta qualcosa di verde, una cosa sola:\nbasta un germoglio perché il resto prenda coraggio.", "hint": "pianta almeno una Pianta", "done_text": "Guarda: una foglia sola, e già l'aria sembra più gentile.", "predicate": {"type": "has", "name": "Pianta"}, "unlocks": ["Aiuola", "Orto"], "celebrate_letter": ""},
    {"id": "il-piccolo-orto", "title": "Il piccolo orto", "letter_text": "Chi mette radici, mette anche un pensiero al domani.\nApri un orto in un angolo di sole:\nvoglio vedere cosa deciderai di far crescere.", "hint": "un Orto in un angolo soleggiato", "done_text": "Un orto! Verrò a rubarti un pomodoro, di notte. Sarà il nostro segreto.", "predicate": {"type": "has", "name": "Orto"}, "unlocks": ["Finestra", "Porta", "Staccionata"], "celebrate_letter": ""},
    {"id": "quattro-mura-e-una-porta", "title": "Quattro mura e una porta", "letter_text": "Il vento gira e non trova dove fermarsi.\nAlza dei muri e apri una porta:\nfai una stanza, anche piccola, dove il freddo bussi prima di entrare.", "hint": "una stanza chiusa, con almeno una porta", "done_text": "Una stanza! Ho sentito il primo silenzio caldo del villaggio.", "predicate": {"type": "has_room"}, "unlocks": ["Tetto", "Tappeto"], "celebrate_letter": "Stamattina ho sbirciato dalla soglia: dentro c'era già profumo di casa."},
    {"id": "un-tetto-sopra-la-testa", "title": "Un tetto sopra la testa", "letter_text": "Le stelle sono belle, ma bagnano.\nPosa un tetto sopra la tua stanza:\nsotto un tetto anche la pioggia diventa una ninnananna.", "hint": "un Tetto sopra la stanza", "done_text": "Ora hai un dentro e un fuori. Il villaggio ha imparato a proteggere.", "predicate": {"type": "has", "name": "Tetto"}, "unlocks": ["Tavolino", "Sedia", "Sgabello", "Panchina"], "celebrate_letter": ""},
    {"id": "un-posto-per-due", "title": "Un posto per due", "letter_text": "Un tavolo apparecchiato per uno fa un po' di malinconia.\nMetti un tavolino e due sedie:\nprima o poi qualcuno verrà a sedersi di fronte a te.", "hint": "un tavolino e almeno 2 sedie", "done_text": "Due sedie una di fronte all'altra. Ho già in mente chi potrebbe riempirne una.", "predicate": {"type": "table_with_chairs", "chairs": 2}, "unlocks": ["Camino", "Lampada"], "celebrate_letter": ""},
    {"id": "il-fuoco-e-la-luce", "title": "Il fuoco e la luce", "letter_text": "Quando cala il buio, un villaggio si riconosce da come si illumina.\nAccendi un camino e appendi una lampada:\ndue piccole luci bastano a dire «qui c'è vita».", "hint": "due piccole luci accese", "done_text": "Da quassù vedo le tue luci: sembrano un piccolo faro tra gli alberi.", "predicate": {"type": "any_count", "names": ["Camino", "Lampada"], "n": 2}, "unlocks": ["Letto", "Libreria"], "celebrate_letter": ""},
    {"id": "una-stanza-per-un-ospite", "title": "Una stanza per un ospite", "letter_text": "Prepara un letto e mettilo al riparo di un tetto.\nQualcuno, con una valigia e tanta timidezza,\nsta cercando proprio un posto così per fermarsi.", "hint": "un letto sotto un tetto", "done_text": "C'è un letto pronto, all'asciutto. Ora aspettiamo: qualcuno arriverà.", "predicate": {"type": "bed_under_roof"}, "unlocks": ["Comodino"], "celebrate_letter": "All'alba ho visto una valigia posata sulla soglia. Il tuo primo ospite ha annusato l'aria, ha guardato il letto sotto il tetto, e ha deciso di restare."},
    {"id": "il-primo-abitante", "title": "Il primo abitante", "letter_text": "Presto, col sereno del giorno, busserà un ospite\ncon la valigia in zampa. Preparagli un letto tutto suo,\nsotto un tetto — non quello di casa tua — e aspetta:\nsceglierà di restare.", "hint": "un letto per l'ospite (non quello di casa) sotto un tetto, poi aspetta", "done_text": "Un abitante! Il villaggio ha smesso di essere un'idea: adesso respira.", "predicate": {"type": "resident_moved_in", "n": 1}, "unlocks": ["Scala", "Solaio", "Lavagna"], "celebrate_letter": "Il tuo nuovo vicino stamattina ha spazzato la soglia canticchiando, e mi ha chiesto dove potrà segnare i giorni di festa. Gli ho promesso che gli avresti dato una lavagna tutta sua. Una casa che accoglie, prima o poi, ha voglia di crescere anche verso l'alto."},
    {"id": "verso-l-alto", "title": "Verso l'alto", "letter_text": "Il villaggio ha preso coraggio e vuole guardare più lontano.\nCostruisci un piano di sopra, un solaio:\nda lassù anche i tetti sembrano un piccolo mare ondulato.", "hint": "un piano di sopra (un Solaio)", "done_text": "Un piano nuovo, più vicino ai rami. Comincio a sentirti quasi alla mia altezza.", "predicate": {"type": "has_upper_floor"}, "unlocks": ["Ponticello"], "celebrate_letter": ""},
    {"id": "la-casa-sull-albero", "title": "La casa sull'albero", "letter_text": "Ci siamo arrivati in cima, tu ed io.\nLancia un ponticello di corda tra i tetti più alti:\nè l'ultimo ponte prima del ramo dove ti aspetto.", "hint": "un ponticello tra i tetti alti", "done_text": "Il ponte regge. Il villaggio adesso tocca i rami: puoi costruire la casa sull'albero.", "predicate": {"type": "has", "name": "Ponticello"}, "unlocks": ["Casa albero"], "celebrate_letter": "Stanotte mi trasferisco nella casa sull'albero che hai immaginato per me. Dal ramo più alto conto i tetti nuovi, le luci, gli orti, l'ospite che ora ha un nome: hai costruito un mondo intero, e io ho avuto il posto in prima fila. Grazie, piccolo Regista. — Il Gufo"},
]

# --- stato della progressione (persistito sotto la chiave "gufo") ---
var _build: Node
var _mail: Node
var _visitors: Node
var _sfx
var _dormant := false            # CLI screenshot / makesave: recinto spento
var _current := 0                # indice dell'Ordine in corso in CHAIN
var _done := {}                  # id Ordine -> true
var _unlocked := {}              # nome pezzo -> true
var _announced := {}             # id Ordine -> true (gia' mostrato al giocatore)
var _veteran := false            # salvataggio precedente agli Ordini: catalogo pieno
var _arrivals := 0               # residenti traslocati (per resident_moved_in)
var _settled := false            # il caricamento ha gia' sistemato lo stato?

# --- UI ---
var _layer: CanvasLayer
var _toast: PanelContainer
var _toast_title: Label
var _toast_text: Label
var _toast_tw: Tween
var _toast_queue: Array = []
var _toast_busy := false
var _journal: PanelContainer
var _journal_box: VBoxContainer
var _journal_open := false


func _ready() -> void:
    add_to_group("gufo")
    add_to_group("persistable")
    # in modalita' screenshot/makesave da CLI il recinto resta spento: la
    # demo costruisce liberamente e non tocca la progressione vera
    if OS.get_environment("CHIBI_SHOT") != "" or OS.get_environment("CHIBI_MAKESAVE") != "":
        _dormant = true
        return
    for n in STARTER:
        _unlocked[str(n)] = true
    _sfx = get_node_or_null(^"/root/Sfx")
    # BuildSystem e' un fratello nel .tscn e viene _ready() prima di noi
    # (siamo piu' in basso nell'albero): il gruppo e' gia' popolato.
    _build = get_tree().get_first_node_in_group("build_system")
    _mail = get_node_or_null("../Mail")
    _visitors = get_node_or_null("../Visitors")
    _build_ui()
    if _build and _build.has_signal("placed_changed"):
        _build.connect("placed_changed", _on_placed_changed)
    _apply_to_build()
    # Se un salvataggio esiste, il caricamento differito del villaggio
    # chiamera' load_extra (impostando _settled) prima di questo timer. Se
    # non arriva nessuno, e' un villaggio nuovo: riveliamo il primo Ordine.
    get_tree().create_timer(0.25).timeout.connect(func() -> void:
        if not _settled:
            _settled = true
            _reveal_current())


# ---------------------------------------------------------------- catalogo

## Tutti i nomi del catalogo (per sbloccare tutto ai veterani). Statico:
## usa solo BuildCatalog.items(), niente SceneTree — cosi' e' testabile.
static func all_piece_names() -> Array:
    var out := []
    for it in CAT.items():
        out.append(str(it["name"]))
    return out


func _apply_to_build() -> void:
    if _build == null:
        return
    if _veteran:
        # catalogo pieno, nessun blocco: non togliamo i mobili a chi ha gia'
        # un villaggio
        _build.call("apply_unlocks", all_piece_names(), false)
        _build.call("set_order_banner", "")
        return
    # campagna finita: apri tutto il catalogo — anche i pezzi aggiunti dopo,
    # non previsti dagli Ordini, restano raggiungibili (mai persi). La tela e' tua.
    if _active_order().is_empty():
        for nm in all_piece_names():
            _unlocked[str(nm)] = true
    _build.call("apply_unlocks", _unlocked.keys(), true)
    _update_banner()


func _update_banner() -> void:
    if _build == null:
        return
    if _veteran:
        _build.call("set_order_banner", "")
        return
    var o := _active_order()
    if o.is_empty():
        _build.call("set_order_banner", "Il villaggio e' completo — la tela e' tua.")
        return
    _build.call("set_order_banner", "Il Gufo sussurra:  %s" % _banner_hint(o))


# di norma il banner mostra l'hint statico; ma l'Ordine "arriva un ospite"
# e' un'attesa passiva (col sereno, di giorno) con un caso scomodo: se il
# solo letto coperto e' quello di casa, nessun ospite puo' prenderlo. Qui la
# guida diventa esplicita, cosi' non ci si blocca senza capire perche'.
func _banner_hint(o: Dictionary) -> String:
    var pred: Dictionary = o.get("predicate", {})
    if str(pred.get("type", "")) == "resident_moved_in":
        if not bool(_build.call("has_bed_under_roof")):
            return "prepara un letto sotto un tetto per l'ospite in arrivo"
        if _visitors != null and not bool(_visitors.call("has_free_house")):
            return "l'ospite vuole un letto tutto suo (non quello di casa), sotto un tetto"
        return "col sereno, di giorno, qualcuno arrivera' con la valigia — tieni il letto pronto"
    return str(o.get("hint", ""))


# ---------------------------------------------------------------- Ordini

func _active_order() -> Dictionary:
    if _veteran or _current < 0 or _current >= CHAIN.size():
        return {}
    return CHAIN[_current]


# L'istantanea del villaggio con cui si valutano gli Ordini. Solo dati
# semplici (conteggi + qualche bool): satisfied() ne deriva il resto.
func world_snapshot() -> Dictionary:
    var counts := {}
    var bed := false
    if _build:
        counts = _build.call("piece_counts")
        bed = _build.call("has_bed_under_roof")
    return {"counts": counts, "bed_under_roof": bed, "residents": _arrivals}


## Un Ordine e' esaudito? Funzione PURA sull'istantanea: nessuno stato, nessun
## nodo — il cuore testabile della progressione.
static func satisfied(pred: Dictionary, snap: Dictionary) -> bool:
    var counts: Dictionary = snap.get("counts", {})
    var t := str(pred.get("type", ""))
    if t == "has":
        return int(counts.get(str(pred.get("name", "")), 0)) >= 1
    elif t == "count":
        return int(counts.get(str(pred.get("name", "")), 0)) >= int(pred.get("n", 1))
    elif t == "any_count":
        var tot := 0
        for nm in pred.get("names", []):
            tot += int(counts.get(str(nm), 0))
        return tot >= int(pred.get("n", 1))
    elif t == "bed_under_roof":
        return bool(snap.get("bed_under_roof", false))
    elif t == "table_with_chairs":
        return int(counts.get("Tavolino", 0)) >= 1 \
                and int(counts.get("Sedia", 0)) >= int(pred.get("chairs", 2))
    elif t == "has_room":
        var walls := int(counts.get("Muro", 0)) + int(counts.get("Finestra", 0)) \
                + int(counts.get("Porta", 0))
        return walls >= 3 and int(counts.get("Porta", 0)) >= 1
    elif t == "has_upper_floor":
        return int(counts.get("Solaio", 0)) >= 1
    elif t == "resident_moved_in":
        return int(snap.get("residents", 0)) >= int(pred.get("n", 1))
    push_warning("GufoOrders: predicato sconosciuto '%s'" % t)
    return false


## I pezzi che un predicato richiede (per validare che nessun Ordine chieda
## un pezzo ancora sotto chiave). Statico: lo usa anche il test.
static func referenced_pieces(pred: Dictionary) -> Array:
    var t := str(pred.get("type", ""))
    if t == "has" or t == "count":
        return [str(pred.get("name", ""))]
    if t == "any_count":
        var a := []
        for nm in pred.get("names", []):
            a.append(str(nm))
        return a
    if t == "table_with_chairs":
        return ["Tavolino", "Sedia"]
    if t == "has_room":
        return ["Muro", "Finestra", "Porta"]
    if t == "bed_under_roof":
        return ["Letto", "Tetto"]
    if t == "has_upper_floor":
        return ["Solaio"]
    return []  # resident_moved_in non dipende da un pezzo


func _on_placed_changed() -> void:
    if _dormant or _veteran:
        return
    _check_current()
    _update_banner()  # la guida dell'Ordine "arriva un ospite" resta viva


## Un residente ha traslocato: lo segnala Visitors. Fa avanzare gli Ordini
## che aspettano un abitante.
func note_arrival() -> void:
    if _dormant:
        return
    _arrivals += 1
    _check_current()
    _save()


func _check_current() -> void:
    var o := _active_order()
    if o.is_empty():
        return
    if satisfied(o["predicate"], world_snapshot()):
        _complete(o)


func _complete(o: Dictionary) -> void:
    # difesa: un Ordine gia' esaudito non si ricompleta (niente doppioni di
    # lettera/regalo se un placed_changed lo rivaluta dopo un reload)
    if _done.has(str(o["id"])):
        return
    _done[str(o["id"])] = true
    for name in o.get("unlocks", []):
        _unlocked[str(name)] = true
    # il Gufo si congratula, subito
    _owl_toast(str(o["title"]), str(o.get("done_text", "")), true)
    # e col mattino arriva la letterina di ringraziamento (se c'e' la cassetta)
    var cel := str(o.get("celebrate_letter", ""))
    if cel != "" and _mail:
        _mail.call("queue_letter", {"from": "Il Gufo", "text": cel, "gift": true})
    _advance()
    _reveal_current()  # applica il recinto, aggiorna il diario, annuncia il nuovo Ordine
    _save()


func _advance() -> void:
    _current += 1
    # robustezza: salta Ordini gia' segnati fatti (catene ricaricate)
    while _current < CHAIN.size() and _done.has(str(CHAIN[_current]["id"])):
        _current += 1


# applica il recinto, aggiorna il diario e — la prima volta — annuncia
# l'Ordine corrente col sussurro del Gufo
func _reveal_current() -> void:
    _apply_to_build()
    _update_journal()
    var o := _active_order()
    if o.is_empty():
        return
    var id := str(o["id"])
    if not _announced.has(id):
        _announced[id] = true
        _owl_toast(str(o["title"]), str(o["letter_text"]))


func _save() -> void:
    if _build:
        _build.call("request_save")


# ---------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
    if _dormant:
        return {}
    return {"gufo": {
        "current": _current,
        "done": _done.keys(),
        "unlocked": _unlocked.keys(),
        "announced": _announced.keys(),
        "veteran": _veteran,
        "arrivals": _arrivals,
    }}


func load_extra(data: Dictionary) -> void:
    if _dormant:
        return
    _settled = true  # il caricamento ha voce in capitolo: niente reveal dal timer
    var d: Variant = data.get("gufo")
    if d is Dictionary:
        _current = int(d.get("current", 0))
        _veteran = bool(d.get("veteran", false))
        _arrivals = int(d.get("arrivals", 0))
        _unlocked = {}
        for n in STARTER:
            _unlocked[str(n)] = true
        for n in d.get("unlocked", []):
            _unlocked[str(n)] = true
        _done = {}
        for oid in d.get("done", []):
            _done[str(oid)] = true
        _announced = {}
        for oid in d.get("announced", []):
            _announced[str(oid)] = true
        # riconciliazione: _current non deve puntare a un Ordine gia' fatto
        # (es. se un crash ha salvato tra la marcatura e l'avanzamento)
        while _current < CHAIN.size() and _done.has(str(CHAIN[_current]["id"])):
            _current += 1
        _reveal_current()
        return
    # --- migrazione: salvataggio precedente agli Ordini ---
    # se il villaggio ha gia' dei pezzi, e' un veterano: catalogo pieno,
    # nessun blocco a posteriori. Un villaggio vuoto riparte dal viaggio.
    var has_village := _build != null and int(_build.call("piece_count")) > 0
    if has_village:
        _veteran = true
        _current = CHAIN.size()
        for it in all_piece_names():
            _unlocked[str(it)] = true
        for o in CHAIN:
            _done[str(o["id"])] = true
        _apply_to_build()
        _update_journal()
    else:
        _reveal_current()


# ---------------------------------------------------------------- UI: toast

func _owl_toast(title: String, body: String, celebratory := false) -> void:
    if body == "" and title == "":
        return
    _toast_queue.append({"title": title, "body": body, "cel": celebratory})
    if not _toast_busy:
        _show_next_toast()


func _show_next_toast() -> void:
    if _toast_queue.is_empty():
        _toast_busy = false
        _toast.visible = false
        return
    _toast_busy = true
    var item: Dictionary = _toast_queue.pop_front()
    _toast_title.text = str(item["title"])
    _toast_text.text = str(item["body"])
    _toast.visible = true
    _toast.modulate.a = 0.0
    if _toast_tw and _toast_tw.is_valid():
        _toast_tw.kill()
    # tempo di lettura proporzionale al testo, tra 3.2 e 6.5 secondi
    var hold := clampf(float(str(item["body"]).length()) / 20.0, 3.2, 6.5)
    _toast_tw = create_tween()
    _toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.35)
    _toast_tw.tween_interval(hold)
    _toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
    _toast_tw.tween_callback(_show_next_toast)
    if _sfx:
        _sfx.call("place_ok" if bool(item.get("cel", false)) else "ui_select")


# ---------------------------------------------------------------- UI: diario

func _unhandled_input(event: InputEvent) -> void:
    if _dormant:
        return
    if event.is_action_pressed("gufo_journal"):
        _journal_open = not _journal_open
        _journal.visible = _journal_open
        if _journal_open:
            _update_journal()
        if _sfx:
            _sfx.call("build_open" if _journal_open else "build_close")
        get_viewport().set_input_as_handled()


func _add_journal_label(text: String, size: int, color: Color,
        align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.horizontal_alignment = align
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.custom_minimum_size = Vector2(452, 0)
    _journal_box.add_child(l)


func _update_journal() -> void:
    if _journal_box == null or not _journal_open:
        return
    for c in _journal_box.get_children():
        c.queue_free()
    _add_journal_label("~  Gli Ordini del Gufo  ~", 17, Color("8a5a3a"), HORIZONTAL_ALIGNMENT_CENTER)
    if _veteran:
        _add_journal_label("Il tuo villaggio era gia' cresciuto prima di me.\nLa tela e' tua: costruisci come il cuore ti detta.",
                13, Color("6a4a3a"))
        _add_journal_label("O — chiudi", 11, Color(0.42, 0.29, 0.23), HORIZONTAL_ALIGNMENT_CENTER)
        return
    for i in CHAIN.size():
        var o: Dictionary = CHAIN[i]
        if _done.has(str(o["id"])):
            _add_journal_label("✿   %s" % str(o["title"]), 13, Color("b98a4a"))
        elif i == _current:
            _add_journal_label("»   %s" % str(o["title"]), 14, Color("a83a5c"))
            _add_journal_label("       «%s»" % str(o["letter_text"]).replace("\n", " "),
                    12, Color("6a4a3a"))
            _add_journal_label("       obiettivo:  %s" % str(o["hint"]), 12, Color("7a6a54"))
            break  # gli Ordini a venire restano un segreto
    if _current < CHAIN.size() - 1 and not _veteran:
        _add_journal_label("·   gli Ordini a venire restano un segreto del ramo...",
                12, Color(0.5, 0.42, 0.34))
    elif _current >= CHAIN.size():
        _add_journal_label("Il villaggio e' completo. Grazie, piccolo Regista. — Il Gufo",
                13, Color("b98a4a"), HORIZONTAL_ALIGNMENT_CENTER)
    _add_journal_label("O — chiudi", 11, Color(0.42, 0.29, 0.23), HORIZONTAL_ALIGNMENT_CENTER)


func _build_ui() -> void:
    _layer = CanvasLayer.new()
    _layer.layer = 6
    add_child(_layer)

    # il sussurro del Gufo: un cartiglio scuro in alto al centro
    var top := VBoxContainer.new()
    top.set_anchors_preset(Control.PRESET_TOP_WIDE)
    top.offset_top = 18.0
    top.alignment = BoxContainer.ALIGNMENT_BEGIN
    top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _layer.add_child(top)

    _toast = PanelContainer.new()
    _toast.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var ts := StyleBoxFlat.new()
    ts.bg_color = Color(0.20, 0.16, 0.13, 0.93)
    ts.set_corner_radius_all(14)
    ts.border_color = Color(0.95, 0.85, 0.6, 0.5)
    ts.set_border_width_all(2)
    ts.content_margin_left = 22.0
    ts.content_margin_right = 22.0
    ts.content_margin_top = 12.0
    ts.content_margin_bottom = 12.0
    ts.shadow_color = Color(0, 0, 0, 0.35)
    ts.shadow_size = 10
    _toast.add_theme_stylebox_override("panel", ts)
    _toast.visible = false
    top.add_child(_toast)

    var tv := VBoxContainer.new()
    tv.add_theme_constant_override("separation", 3)
    _toast.add_child(tv)
    _toast_title = Label.new()
    _toast_title.add_theme_font_size_override("font_size", 15)
    _toast_title.add_theme_color_override("font_color", Color("ffe0a3"))
    _toast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tv.add_child(_toast_title)
    _toast_text = Label.new()
    _toast_text.add_theme_font_size_override("font_size", 13)
    _toast_text.add_theme_color_override("font_color", Color("fbf1dd"))
    _toast_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _toast_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _toast_text.custom_minimum_size = Vector2(440, 0)
    tv.add_child(_toast_text)

    # il diario degli Ordini: una pergamena al centro (tasto O)
    _journal = PanelContainer.new()
    var js := StyleBoxFlat.new()
    js.bg_color = Color(0.99, 0.96, 0.89, 0.97)
    js.set_corner_radius_all(16)
    js.border_color = Color(0.62, 0.46, 0.34, 0.6)
    js.set_border_width_all(2)
    js.content_margin_left = 26.0
    js.content_margin_right = 26.0
    js.content_margin_top = 18.0
    js.content_margin_bottom = 16.0
    js.shadow_color = Color(0.25, 0.15, 0.1, 0.3)
    js.shadow_size = 14
    _journal.add_theme_stylebox_override("panel", js)
    _journal.visible = false
    _journal.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _layer.add_child(_journal)
    _journal.set_anchors_preset(Control.PRESET_CENTER)
    _journal.offset_left = -246.0
    _journal.offset_right = 246.0
    _journal.offset_top = -220.0
    _journal_box = VBoxContainer.new()
    _journal_box.add_theme_constant_override("separation", 6)
    _journal.add_child(_journal_box)


# ---------------------------------------------------------------- debug CLI

func debug_state() -> Dictionary:
    return {"current": _current, "unlocked": _unlocked.size(),
            "done": _done.size(), "veteran": _veteran, "arrivals": _arrivals}


func debug_force_check() -> void:
    _check_current()
