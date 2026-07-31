extends RefCounted
## LA GUARDIA DELLA TRADUZIONE (systems/L10n.gd + locale/en/*.gd).
##
## Tradurre un gioco a mano rompe cose in silenzio: un `%s` perso fa
## crashare la frase la prima volta che qualcuno pesca un pesce, una
## traduzione dimenticata mostra italiano in mezzo all'inglese, e — la più
## grave — tradurre un DATO invece di un testo rende illeggibili i
## salvataggi. Qui si controllano tutte e tre le cose, a ogni commit.
##
## Vedi docs/TRADUZIONE.md per il glossario vincolante.

const L := preload("res://systems/L10n.gd")
const CRIT := preload("res://scenes/world/Critters.gd")
const CAT := preload("res://scenes/build/BuildCatalog.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")
const GUFO := preload("res://scenes/npc/GufoOrders.gd")
const ECO := preload("res://scenes/ui/Economy.gd")

# le grafie americane che nel villaggio non si usano (inglese britannico)
const AMERICANISMI := ["color", "colors", "colored", "colorful", "neighbor",
        "neighbors", "favorite", "favorites", "gray", "grayish", "meters",
        "theater", "jewelry"]

# le parole che il glossario vieta: traduzione -> perché
const VIETATE := {
    "nuts": "le noccioline sono 'acorns' (in inglese 'nuts' dice altro)",
    "merchant": "il mercante col carretto è 'the pedlar'",
}


func run(t) -> void:
    _test_forma_delle_tabelle(t)
    _test_segnaposto(t)
    _test_a_capo(t)
    _test_inglese_britannico(t)
    _test_glossario(t)
    _test_il_motore(t)
    _test_i_dati_non_si_traducono(t)
    _test_ogni_frase_avvolta_e_tradotta(t)
    _test_copertura(t)
    _test_le_tabelle_dati(t)


# ------------------------------------------ la guardia della REGOLA
# «Testo nuovo = traduzione nuova, subito» (vedi CLAUDE.md). Qui il
# controllo si fa da solo: si spulciano i sorgenti, si raccoglie ogni
# frase letterale passata a L10n.t()/L10n.tf(), e si pretende che stia
# in tabella. Chi aggiunge un dialogo e si dimentica l'inglese trova
# rosso PRIMA di chiudere, col nome del file e la frase.

const CARTELLE := ["res://scenes", "res://systems", "res://audio"]
# i file che parlano di traduzione ma non sono gioco (le loro stringhe
# d'esempio non vanno in tabella)
const ESENTI := ["res://systems/L10n.gd"]


func _test_ogni_frase_avvolta_e_tradotta(t) -> void:
    var tabella := {}
    for parte in L.TABELLE.get("en", []):
        for chiave in parte.tabella():
            tabella[chiave] = true

    var re := RegEx.new()
    re.compile('L10n\\.tf?\\(\\s*"((?:[^"\\\\]|\\\\.)*)"')
    # LE FRASI RIMANDATE (vedi L10n.rendi). La posta non può tradurre
    # quando scrive — la coda finisce su disco e si legge domani, magari in
    # un'altra lingua — quindi mette da parte la CHIAVE: `"text_key": "…"`,
    # `"from_key": "…"`, `{"k": "…"}`. Sono letterali che il giocatore
    # vedrà esattamente come quelli avvolti in L10n.t(), e senza questa
    # seconda rete uscirebbero dal controllo in silenzio: la copertura
    # scenderebbe da sola, senza che nessun test diventi rosso.
    var re_rimandate := RegEx.new()
    re_rimandate.compile('"(?:text_key|from_key|k)"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"')
    # LA CRONACA DEL GRANDE ALBERO. `engrave("★", "…")` conserva la CHIAVE
    # italiana e la traduce solo dove si mostra: sono letterali che il
    # giocatore vede, e senza questa terza rete uscivano dal controllo —
    # quattro erano gia' scivolate fuori.
    var re_cronaca := RegEx.new()
    re_cronaca.compile('engrave(?:_once)?\\((?:[^,]+,\\s*)?[^,]+,\\s*"((?:[^"\\\\]|\\\\.)*)"')

    var mancanti: Array[String] = []
    var trovate := 0
    for cartella in CARTELLE:
        for percorso in _script_di(cartella):
            if percorso in ESENTI:
                continue
            var testo := _senza_commenti(FileAccess.get_file_as_string(percorso))
            if testo.is_empty():
                continue
            for re_i in [re, re_rimandate]:
                for m in (re_i as RegEx).search_all(testo):
                    # `L10n.t("%s %s" % [...])`: qui la chiave non è il letterale
                    # ma la frase già COMPOSTA (è il caso legittimo di
                    # Critters.con_articolo, dove l'articolo va incollato al nome
                    # prima di cercare la riga). Il letterale è solo uno stampo:
                    # saltalo, o il controllo chiederebbe di tradurre "%s %s".
                    if _formatta_dopo(testo, m.get_end()):
                        continue
                    var frase := _spoglia(m.get_string(1))
                    if frase.strip_edges().is_empty():
                        continue
                    # una chiave senza NEMMENO UNA LETTERA non è una frase:
                    # è l'impalcatura che tiene insieme due frasi vere
                    # ("%s × %d", "%s (%s)"). Non c'è niente da tradurre, e
                    # metterla in tabella vorrebbe dire scriverci accanto
                    # una copia identica — cosa che un altro controllo qui
                    # sotto giustamente vieta.
                    if not _ha_lettere(frase):
                        continue
                    trovate += 1
                    if not tabella.has(frase):
                        mancanti.append("%s: «%s»" % [percorso.get_file(), _corto(frase)])

    t.ok(trovate > 0, "il controllo trova davvero le frasi avvolte (%d)" % trovate)
    # una riga di errore per frase: il rapporto dice SUBITO cosa tradurre
    for m in mancanti:
        t.ok(false, "traduzione inglese mancante -> %s" % m)
    t.eq(mancanti.size(), 0,
            "ogni frase avvolta in L10n.t() ha la sua traduzione (%d/%d)"
            % [trovate - mancanti.size(), trovate])


## C'è almeno una PAROLA, o è solo impalcatura? I segnaposto si tolgono
## prima di guardare: dentro `%s` e `%d` ci sono due lettere che non sono
## parole di nessuna lingua, e senza toglierle «%s (%s)» passerebbe per
## una frase da tradurre.
static func _ha_lettere(s: String) -> bool:
    var nuda := _RE_SEGNAPOSTO.sub(s, " ", true)
    return _RE_LETTERA.search(nuda) != null


static var _RE_SEGNAPOSTO := RegEx.create_from_string("%[-+ 0-9.*]*[sdfxvc%]")
static var _RE_LETTERA := RegEx.create_from_string("\\p{L}")


## Dopo la stringa chiusa c'è un `%` (cioè la si sta formattando prima di
## tradurla)? Allora il letterale è uno stampo, non una chiave.
static func _formatta_dopo(testo: String, da: int) -> bool:
    var i := da
    while i < testo.length() and testo[i] in [" ", "\t"]:
        i += 1
    return i < testo.length() and testo[i] == "%"


## Il sorgente senza le righe di commento. Una frase d'ESEMPIO scritta in
## un `##` che spiega come si usa una API (`"text_key": "Ho contato %d
## stelle su casa tua."`) non è testo che il giocatore vedrà: chiederne la
## traduzione manderebbe in tabella frasi che nessuno dirà mai. Si tolgono
## solo le righe che COMINCIANO con `#`, così una stringa vera con dentro
## un cancelletto resta al suo posto.
static func _senza_commenti(sorgente: String) -> String:
    var righe := sorgente.split("\n")
    for i in righe.size():
        if righe[i].strip_edges().begins_with("#"):
            righe[i] = ""
    return "\n".join(righe)


## Gli script .gd sotto una cartella, ricorsivamente.
static func _script_di(cartella: String) -> Array[String]:
    var out: Array[String] = []
    var dir := DirAccess.open(cartella)
    if dir == null:
        return out
    dir.list_dir_begin()
    var nome := dir.get_next()
    while nome != "":
        var percorso := cartella.path_join(nome)
        if dir.current_is_dir():
            if not nome.begins_with("."):
                out.append_array(_script_di(percorso))
        elif nome.ends_with(".gd"):
            out.append(percorso)
        nome = dir.get_next()
    dir.list_dir_end()
    return out


## Da come la frase è SCRITTA nel sorgente a com'è in MEMORIA: nel file
## "\n" sono due caratteri, a runtime (e quindi come chiave della tabella)
## è un a capo solo. Senza questo passaggio ogni lettera del Gufo
## risulterebbe non tradotta.
static func _spoglia(letterale: String) -> String:
    return letterale.replace("\\n", "\n").replace("\\t", "\t") \
            .replace("\\\"", "\"").replace("\\'", "'").replace("\\\\", "\\")


# --------------------------------------------------------- forma delle voci

func _test_forma_delle_tabelle(t) -> void:
    for codice in L.TABELLE:
        for parte in L.TABELLE[codice]:
            var tab: Dictionary = parte.tabella()
            for chiave in tab:
                var valore := str(tab[chiave])
                t.ok(str(chiave) != "", "%s: nessuna chiave vuota" % codice)
                t.ok(valore != "", "%s: '%s' ha una traduzione" % [codice, chiave])
                # chiave == valore vuol dire «non tradotta»: meglio toglierla
                # dalla tabella che lasciarla lì a fingere
                t.ok(valore != str(chiave),
                        "%s: '%s' è davvero tradotta (non ricopiata)" % [codice, chiave])
                t.ok(not valore.begins_with(" ") and not valore.ends_with(" "),
                        "%s: '%s' senza spazi in testa o in coda" % [codice, chiave])


# ------------------------------------------------------------- i segnaposto
# Il difetto che crasha: "Hai preso %s! (n. %d)" tradotto senza il %d fa
# saltare il format alla prima cattura. Qui si contano uno per uno.

func _test_segnaposto(t) -> void:
    for codice in L.TABELLE:
        for parte in L.TABELLE[codice]:
            var tab: Dictionary = parte.tabella()
            for chiave in tab:
                var a := _segnaposto(str(chiave))
                var b := _segnaposto(str(tab[chiave]))
                t.eq(b, a, "%s: i segnaposto di '%s' combaciano" % [codice, chiave])


## I segnaposto di una frase, in ordine: ["%s", "%d"].
static func _segnaposto(s: String) -> Array:
    var out := []
    var i := 0
    while i < s.length() - 1:
        if s[i] == "%":
            var j := i + 1
            if s[j] == "%":      # "%%" è un per-cento letterale, non un buco
                i += 2
                continue
            var spec := "%"
            while j < s.length() and not s[j] in ["s", "d", "f", "x", "v"]:
                spec += s[j]
                j += 1
            if j < s.length():
                spec += s[j]
                out.append(spec)
            i = j + 1
        else:
            i += 1
    return out


# ----------------------------------------------------------------- gli a capo
# Negli Ordini del Gufo e nelle lettere gli a capo sono l'IMPAGINAZIONE:
# sono i respiri della poesia. Una traduzione che li perde consegna un
# muro di testo dentro un cartiglio disegnato per tre righe.

func _test_a_capo(t) -> void:
    for codice in L.TABELLE:
        for parte in L.TABELLE[codice]:
            var tab: Dictionary = parte.tabella()
            for chiave in tab:
                var a := str(chiave).count("\n")
                var b := str(tab[chiave]).count("\n")
                t.eq(b, a, "%s: '%s' conserva gli a capo" % [codice, _corto(str(chiave))])


static func _corto(s: String) -> String:
    var una_riga := s.replace("\n", " ")
    return una_riga if una_riga.length() <= 42 else una_riga.substr(0, 39) + "..."


# ------------------------------------------------------- inglese britannico

func _test_inglese_britannico(t) -> void:
    if not L.TABELLE.has("en"):
        return
    for parte in L.TABELLE["en"]:
        var tab: Dictionary = parte.tabella()
        for chiave in tab:
            var parole := _parole(str(tab[chiave]))
            for americanismo in AMERICANISMI:
                t.ok(not (americanismo in parole),
                        "en: '%s' evita la grafia americana '%s'"
                        % [_corto(str(chiave)), americanismo])


func _test_glossario(t) -> void:
    if not L.TABELLE.has("en"):
        return
    for parte in L.TABELLE["en"]:
        var tab: Dictionary = parte.tabella()
        for chiave in tab:
            var parole := _parole(str(tab[chiave]))
            for vietata in VIETATE:
                t.ok(not (vietata in parole),
                        "en: '%s' — %s" % [_corto(str(chiave)), VIETATE[vietata]])


## Le parole di una frase, minuscole e senza punteggiatura.
static func _parole(s: String) -> Array:
    var pulita := ""
    for c in s.to_lower():
        pulita += c if (c >= "a" and c <= "z") or c == "'" else " "
    return pulita.split(" ", false)


# ------------------------------------------------------------- il motore

func _test_il_motore(t) -> void:
    var prima := L.lingua_corrente()

    # in italiano la frase torna com'è: nessuna tabella, nessun costo
    L.imposta("it")
    t.eq(L.lingua_corrente(), "it", "la lingua sorgente si imposta")
    t.eq(L.t("Buongiorno!"), "Buongiorno!", "in italiano la frase resta la frase")
    t.eq(L.t(""), "", "la stringa vuota resta vuota")

    # in inglese arriva la traduzione, e ciò che manca NON diventa una sigla
    L.imposta("en")
    t.eq(L.lingua_corrente(), "en", "l'inglese si imposta")
    t.eq(L.t("una frase che non tradurremo mai"), "una frase che non tradurremo mai",
            "traduzione mancante -> resta l'italiano (mai una chiave nuda)")

    # una lingua che non conosciamo ricade sulla sorgente invece di rompersi
    L.imposta("klingon")
    t.eq(L.lingua_corrente(), "it", "lingua sconosciuta -> italiano")

    # "auto" non deve mai lasciare il gioco senza lingua
    L.imposta("auto")
    t.ok(L.LINGUE.has(L.lingua_corrente()), "auto sceglie sempre una lingua vera")

    # tf(): prima traduce, poi formatta (l'ordine sbagliato non troverebbe
    # mai la frase in tabella, perché avrebbe già i valori dentro)
    L.imposta("it")
    t.eq(L.tf("Giorno %d", [7]), "Giorno 7", "tf formatta dopo aver tradotto")

    L.imposta(prima)


# ------------------------------------------ i dati NON si traducono mai
# La regola dura di docs/TRADUZIONE.md: i nomi dei pezzi, gli id delle
# specie e i gradini della scala viaggiano nei salvataggi. Se qualcuno
# traducesse la TABELLA invece della vista, un villaggio salvato in
# inglese non si riaprirebbe in italiano (e viceversa).

func _test_i_dati_non_si_traducono(t) -> void:
    var prima := L.lingua_corrente()
    L.imposta("en")

    # il catalogo: i nomi-chiave restano italiani anche col gioco in inglese
    var nomi := []
    for it in CAT.items():
        nomi.append(str(it["name"]))
    for atteso in ["Cassetta posta", "Letto", "Tetto", "Muro", "Panchina"]:
        t.ok(atteso in nomi, "il catalogo conserva l'id italiano '%s'" % atteso)

    # il bestiario: gli id e il campo `nome` restano la sorgente italiana
    t.ok(CRIT.esiste("gialla"), "l'id della specie resta 'gialla'")
    t.eq(CRIT.nome("gialla"), "farfalla dorata", "il dato `nome` resta italiano")
    # ...ma ciò che si MOSTRA è inglese
    t.eq(CRIT.etichetta("gialla"), "Golden butterfly", "l'etichetta è tradotta")
    t.eq(CRIT.con_articolo("gialla"), "a golden butterfly",
            "l'articolo inglese giusto (a/an) viene dalla tabella")

    # la scala della ribellione: i gradini restano gli id italiani
    t.ok("diserzione" in ANIMO.SCALA, "i gradini della scala restano italiani")
    t.eq(ANIMO.SCALA.size(), 8, "la scala non è stata riscritta dalla traduzione")

    L.imposta(prima)


# ------------------------------------------------------------- copertura

func _test_copertura(t) -> void:
    var quante := L.quante("en")
    # la soglia sale quando la traduzione cresce: se qualcuno svuota una
    # parte per sbaglio (o la rinomina), qui diventa rosso subito
    t.ok(quante >= 700, "la traduzione inglese copre almeno 700 frasi (ora: %d)" % quante)
    t.eq(L.TABELLE["en"].size(), 4, "le quattro parti della tabella ci sono tutte")

    # le frasi che il giocatore vede nei PRIMI DIECI SECONDI: se mancano
    # queste, la vetrina del gioco è in italiano comunque
    var prima := L.lingua_corrente()
    L.imposta("en")
    for frase in ["Nuovo villaggio", "Continua", "Impostazioni", "Esci", "Lingua"]:
        t.ok(L.t(frase) != frase, "la schermata del titolo è tradotta: '%s'" % frase)
    L.imposta(prima)


# ---------------------------------------- il buco delle TABELLE DATI
## IL GUARDIANO DI SOPRA CERCA I LETTERALI dentro `L10n.t("…")` e le chiavi
## rimandate. Tutto il testo che arriva da una TABELLA DATI gli è invisibile:
## `L10n.t(str(d["title"]))` non ha nessun letterale da trovare, e la suite
## resta verde per costruzione.
##
## È già costato due lettere-stagione intere del Gufo (il Salone e
## l'Anfiteatro) e undici voci del negozio uscite in ITALIANO dentro la
## versione inglese — fra cui le descrizioni dei pezzi da 60 a 420
## noccioline, cioè le righe su cui un giocatore decide la spesa di mezza
## stagione. Qui le tabelle si spulciano una per una, per nome.
## Le parole che in inglese si scrivono UGUALI. Non vanno in tabella: la
## guardia di `_test_forma_delle_tabelle` considera «chiave = valore» un
## segno di traduzione finta, e ha ragione — una voce ricopiata nasconde
## una dimenticanza. L'eccezione sta scritta qui, dove si vede, invece che
## dentro la tabella dove si confonderebbe con le altre.
const UGUALI_IN_INGLESE := ["Gazebo"]


func _test_le_tabelle_dati(t) -> void:
    var tabella := {}
    for parte in L.TABELLE.get("en", []):
        for chiave in parte.tabella():
            tabella[chiave] = true

    var mancanti: Array[String] = []
    var quante := 0
    # i desideri del Gufo: tutto ciò che finisce in un toast, in un banner,
    # nel diario o dentro una busta
    for elenco in [GUFO.CHAIN, GUFO.DESIDERI]:
        for d in elenco:
            for campo in ["title", "letter_text", "hint", "done_text", "celebrate_letter"]:
                var v := str((d as Dictionary).get(campo, ""))
                if v == "":
                    continue
                quante += 1
                if not tabella.has(v):
                    mancanti.append("GufoOrders[%s].%s" % [str(d.get("id", "?")), campo])
    # il negozio: il NOME si vede sul bancone e nel pannello di costruzione,
    # la DESCRIZIONE è quella che convince a spendere
    for pezzo in ECO.SHOP_PIECES:
        for campo2 in ["name", "desc"]:
            var v2 := str((pezzo as Dictionary).get(campo2, ""))
            if v2 == "":
                continue
            if str(v2) in UGUALI_IN_INGLESE:
                continue
            quante += 1
            if not tabella.has(v2):
                mancanti.append("Economy.SHOP_PIECES[%s].%s" % [str(pezzo.get("name", "?")), campo2])

    for m in mancanti:
        t.ok(false, "tabella dati senza traduzione inglese -> %s" % m)
    t.eq(mancanti.size(), 0,
            "ogni voce delle tabelle dati ha la sua traduzione (%d/%d)"
            % [quante - mancanti.size(), quante])
