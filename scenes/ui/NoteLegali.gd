class_name NoteLegali
extends PanelContainer

## LE NOTE LEGALI — la pagina che dice cosa c'è dentro il gioco che non è
## nostro, e sotto quali condizioni ci sta.
##
## Non è una cortesia e non è un vezzo. La licenza MIT chiede che il suo
## avviso di copyright viaggi «in all copies»: quello è un obbligo pieno, e
## riguarda il motore e le librerie. I documenti di **Gemma** stanno qui per
## una ragione diversa e più forte — **il gioco non spedisce nessun modello**,
## lo scarica il giocatore se accende la funzione, e in quel momento si
## vincola ai Gemma Terms of Use *per il fatto stesso di scaricarlo*
## (preambolo dell'accordo). Il repository da cui il file arriva non gli
## consegna niente: **questa pagina, e la schermata dello scaricamento, sono
## gli unici posti in cui quei termini gli vengono mostrati.**
## I file viaggiano anche **accanto al gioco** (cartella `Licenze/`, su macOS
## dentro `Contents/Resources/`) — ma un file accanto all'eseguibile lo apre
## una persona su mille, e su macOS sta dentro un bundle che quasi nessuno
## apre. Questa pagina è il modo in cui li può leggere chi non andrà mai a
## cercarli.
##
## ⚠️ **LE TRE REGOLE, e vengono tutte dalla stessa parte.**
##
## 1. **Si mostra solo quello che questo binario sa DAVVERO fare.** La sezione
##    del modello linguistico compare se e solo se il cuore è stato compilato
##    con llama.cpp dentro (`Llm.disponibile()`): allora la funzione esiste,
##    e i suoi documenti descrivono una cosa che il giocatore **può
##    scegliere**, l'abbia già scaricata o no. Chi ha una build senza legge una
##    pagina completa e vera per il **suo** gioco, senza una voce spenta che
##    gli racconta che gli manca un pezzo.
##    ⚠️ E la domanda **non** è `Llm.leva_visibile()` (che è vera solo col
##    file già sul disco): con quella, i termini si vedrebbero soltanto DOPO
##    aver scaricato — cioè dopo essersi vincolati. Sono due domande diverse,
##    ed è la ragione per cui qui non si riusa quella della casella.
## 2. **I testi non si ricopiano qui dentro.** Si leggono dai file veri
##    (`res://misc/licenze/`), che a loro volta sono generati o scaricati
##    dalle fonti: una licenza ricopiata in una costante GDScript invecchia in
##    silenzio, ed è esattamente il guasto che `tools/genera_licenze.py`
##    esiste per non avere.
## 3. **La pagina non si rompe MAI.** Se i file non ci sono — un `.pck` senza
##    `include_filter`, un pacchetto montato a mano — non compare nessun
##    errore: compare la riga che dice dove trovarli su disco. È la stessa
##    regola del menù principale, che deve restare l'ultima porta aperta.
##
## L'italiano è la lingua sorgente; l'inglese sta in `locale/en/ui.gd`. I
## NOMI dei file e i titoli delle licenze **non si traducono**: sono nomi
## propri, e chi cerca «Gemma Terms of Use» lo cerca così anche in italiano.

signal closed

## Dove vivono le copie destinate a chi gioca. Stessa cartella che
## `release.yml` mette accanto all'eseguibile: una fonte sola, due strade.
const CARTELLA := "res://misc/licenze"

## I documenti, nell'ordine in cui vanno letti. `solo_col_modello` marca
## quelli che riguardano il modello linguistico: si mostrano se questo binario
## sa farlo girare — l'abbia gia' scaricato o no (vedi `_col_modello`).
const DOCUMENTI := [
	{"file": "LICENZE-TERZE-PARTI.txt",
	 "titolo": "Licenze dei componenti di terze parti",
	 "solo_col_modello": false},
	{"file": "NOTICE-Gemma.txt",
	 "titolo": "Gemma — che cosa scarichi",
	 "solo_col_modello": true},
	{"file": "Gemma-Terms-of-Use.txt",
	 "titolo": "Gemma Terms of Use",
	 "solo_col_modello": true},
	{"file": "Gemma-Prohibited-Use-Policy.txt",
	 "titolo": "Gemma Prohibited Use Policy",
	 "solo_col_modello": true},
]

var _corpo: VBoxContainer
var _lettore: RichTextLabel
var _scorri: ScrollContainer
var _elenco: VBoxContainer
var _titolo_doc: Label
var _indietro: Button
var _aperto := ""


func _ready() -> void:
	add_theme_stylebox_override("panel", CozyUI.paper_panel(28))
	custom_minimum_size = Vector2(560, 460)
	_costruisci()


# =========================================================================
# LA PAGINA
# =========================================================================

func _costruisci() -> void:
	_corpo = VBoxContainer.new()
	_corpo.add_theme_constant_override("separation", 12)
	add_child(_corpo)

	_corpo.add_child(CozyUI.title_label(L10n.t("Note legali"), 28))

	_titolo_doc = CozyUI.body_label("", 15, CozyUI.TITLE)
	_titolo_doc.visible = false
	_corpo.add_child(_titolo_doc)

	# L'INDICE: cosa c'è dentro, in una frase per componente.
	_scorri = ScrollContainer.new()
	_scorri.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scorri.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_corpo.add_child(_scorri)

	_elenco = VBoxContainer.new()
	_elenco.add_theme_constant_override("separation", 10)
	_elenco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scorri.add_child(_elenco)

	# IL LETTORE: il testo intero di un documento. Vive accanto all'indice e
	# si scambiano il posto — un secondo pannello sopra il primo, in un
	# pannello che sta già dentro un altro pannello, è il modo in cui una
	# schermata semplice diventa illeggibile.
	_lettore = RichTextLabel.new()
	_lettore.bbcode_enabled = false
	_lettore.selection_enabled = true
	_lettore.scroll_active = true
	_lettore.fit_content = false
	_lettore.visible = false
	_lettore.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lettore.add_theme_color_override("default_color", CozyUI.INK)
	_lettore.add_theme_font_size_override("normal_font_size", 12)
	_corpo.add_child(_lettore)

	_indietro = CozyUI.cozy_button(L10n.t("Indietro"), CozyUI.PINK, 18)
	_indietro.custom_minimum_size = Vector2(200, 48)
	_indietro.pressed.connect(_su_indietro)
	var centro := CenterContainer.new()
	centro.add_child(_indietro)
	_corpo.add_child(centro)

	_riempi_indice()


func _riempi_indice() -> void:
	for c in _elenco.get_children():
		c.queue_free()

	_elenco.add_child(_paragrafo(L10n.t(
			"Chibi Crossing è un'opera protetta: il codice, i disegni, la musica e i testi sono di chi l'ha fatto. Quello che segue, invece, non è nostro — e viaggia con le sue condizioni.")))

	_elenco.add_child(_voce(
			L10n.t("Il motore e le librerie"),
			L10n.t("Godot Engine, godot-cpp, EnTT, lua-gdextension: licenza MIT."),
			"LICENZE-TERZE-PARTI.txt"))

	if _col_modello():
		# ⚠️ LA TAGLIA E IL POSTO NON SI SCRIVONO QUI. Vivono in `Llm`
		# (`BYTE_MODELLO`, `SORGENTE_CASA`), che è anche la casa di chi
		# scarica: due numeri gemelli in due schermate divergono in silenzio,
		# e qui divergerebbero proprio nella pagina che serve a dire il vero.
		# E si SCRIVONO come li scrive la schermata dello scaricamento
		# (`Capienza.in_giga`): «2,5 GB» con la virgola dell'italiano, non il
		# «2.31 GiB» di `humanize_size` — che è esatto, ed è la stessa cosa
		# detta a un'altra persona. Anche la presentazione ha una casa sola.
		_elenco.add_child(_paragrafo(L10n.tf(
				"Una parte dei testi che leggi — certe lettere, certi pensieri dei vicini — la può scrivere un modello linguistico che gira sul tuo computer, mentre giochi. Il modello non è dentro il gioco: se accendi «Il villaggio pensa», il gioco lo scarica una volta sola (%s, da %s). Dopo, non esce più niente da questa macchina: il testo nasce qui e resta qui. E se non lo accendi, il gioco non apre nessuna connessione per lui — il villaggio resta lo stesso, con i testi scritti a mano.",
				[Capienza.in_giga(Llm.BYTE_MODELLO), Llm.SORGENTE_CASA])))
		_elenco.add_child(_voce(
				L10n.t("Il motore che lo fa girare"),
				L10n.t("llama.cpp e ggml: licenza MIT."),
				"LICENZE-TERZE-PARTI.txt"))
		_elenco.add_child(_voce(
				"Gemma 3 4B IT — Google DeepMind",
				L10n.t("Il modello che il gioco può scaricare per te. Non è nostro e non è MIT: valgono i Gemma Terms of Use di Google, e i vincoli d'uso di quei termini valgono anche per te. Il gioco te li mostra, e ti chiede di accettarli, prima di scaricare qualunque cosa."),
				"NOTICE-Gemma.txt"))
		_elenco.add_child(_bottone_doc(L10n.t("Leggi i Gemma Terms of Use"),
				"Gemma-Terms-of-Use.txt"))
		_elenco.add_child(_bottone_doc(L10n.t("Leggi la Prohibited Use Policy"),
				"Gemma-Prohibited-Use-Policy.txt"))
		_elenco.add_child(CozyUI.hint_label(L10n.t(
				"Gemma e Google sono marchi di Google LLC. Chibi Crossing non è affiliato a Google, né approvato da Google."), 12))

	if not _qualcosa_da_leggere():
		_elenco.add_child(CozyUI.hint_label(L10n.tf(
				"I testi completi delle licenze sono nella cartella «%s», accanto al gioco.",
				["Licenze"]), 12))


## Una voce dell'indice: titolo, una riga di spiegazione, e il documento da
## aprire. Il bottone porta il nome del DOCUMENTO, non «Leggi»: così chi
## scorre la pagina sa già cosa gli si aprirà.
func _voce(titolo: String, riga: String, file: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CozyUI.soft_card())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	col.add_child(CozyUI.body_label(titolo, 16, CozyUI.TITLE))
	var l := CozyUI.body_label(riga, 13, CozyUI.INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(l)
	if _esiste(file):
		col.add_child(_bottone_doc(L10n.t("Leggi il testo"), file))
	return card


func _bottone_doc(etichetta: String, file: String) -> Control:
	var b := CozyUI.cozy_button(etichetta, CozyUI.SKY, 14)
	b.custom_minimum_size = Vector2(0, 38)
	b.disabled = not _esiste(file)
	b.pressed.connect(func(): _apri(file))
	return b


func _paragrafo(testo: String) -> Control:
	var l := CozyUI.body_label(testo, 14, CozyUI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# =========================================================================
# LEGGERE UN DOCUMENTO
# =========================================================================

func _apri(file: String) -> void:
	var testo := _leggi(file)
	if testo == "":
		return                      # il bottone è già spento: non si arriva qui
	_aperto = file
	# si traduce QUI, al momento di mostrare: nella tabella i titoli restano
	# in italiano, che e' la lingua sorgente (i due nomi propri — «Gemma Terms
	# of Use», «Gemma Prohibited Use Policy» — attraversano invariati, ed e'
	# giusto: si cercano cosi' anche in italiano).
	_titolo_doc.text = L10n.t(_titolo_di(file))
	_titolo_doc.visible = true
	_lettore.text = _per_schermo(testo)
	_lettore.visible = true
	_scorri.visible = false
	# si riparte dall'inizio: riaprire un documento a metà pagina è il modo
	# in cui chi legge crede che manchi un pezzo
	_lettore.scroll_to_line(0)


## IL TESTO COM'È FATTO PER LO SCHERMO, e la trasformazione è UNA sola: le
## righe che sono soltanto un filo di «====» o di «----» spariscono.
##
## ⚠️ **NON SI TOCCA UNA PAROLA**, ed è la ragione per cui questa funzione fa
## una cosa così poco: quei fili li ho messi io nell'intestazione dei file,
## servono a chi apre il .txt in un terminale a 78 colonne, e **non fanno
## parte di nessun accordo** (il corpo dei Gemma Terms of Use non ne ha
## neanche uno). A schermo però il carattere è proporzionale e la riga è
## larga meno di 78 colonne: il filo andava a capo e lasciava un «=======»
## orfano sotto ogni titolo — MISURATO guardando, con
## `tools/provino_note_legali.gd`, non leggendo il codice.
##
## Chi fosse tentato di allargare questa funzione — «già che ci siamo,
## rientriamo i paragrafi, accorciamo le righe» — si fermi: da lì in poi il
## gioco mostrerebbe un testo suo al posto della licenza, e la licenza è
## l'unico documento del gioco che deve arrivare come l'ha scritto chi l'ha
## scritto. Il file su disco resta la copia buona, ed è quello che il
## pacchetto spedisce.
func _per_schermo(testo: String) -> String:
	var fuori := PackedStringArray()
	for riga in testo.split("\n"):
		var pulita := riga.strip_edges()
		if pulita.length() >= 8 and (pulita.lstrip("=") == "" or pulita.lstrip("-") == ""):
			continue
		fuori.append(riga)
	return "\n".join(fuori)


func _su_indietro() -> void:
	if _lettore.visible:
		_lettore.visible = false
		_titolo_doc.visible = false
		_scorri.visible = true
		_aperto = ""
		return
	closed.emit()


## Chiude il documento aperto, se ce n'è uno. La chiama chi ospita la pagina
## quando la riapre: una pagina che si riapre sul testo di prima invece che
## sull'indice sembra rotta.
func riparti() -> void:
	if _lettore.visible:
		_su_indietro()


## APRE UN DOCUMENTO SUBITO, saltando l'indice. Torna falso — e non fa
## niente — se quel documento non è leggibile: chi chiama deve poter
## decidere cosa mostrare al posto suo, invece di trovarsi una pagina vuota.
##
## ⚠️ **ESISTE PER LA SCHERMATA DELLO SCARICAMENTO, e il motivo è una regola
## di `docs/LICENZA_MODELLO.md`**: prima del primo byte il giocatore deve
## poter leggere per intero i Gemma Terms of Use e la Prohibited Use Policy,
## perché scaricando si vincola (preambolo dell'accordo) e il repository a
## monte non glieli consegna. Il lettore che serve è **questo** — quello che
## toglie i fili di «====» dall'intestazione e non tocca una parola
## dell'accordo. Ricopiarne uno accanto vorrebbe dire due modi di mostrare la
## stessa licenza, e uno dei due invecchierebbe.
func mostra_documento(file: String) -> bool:
	if not _esiste(file):
		return false
	_apri(file)
	return true


## Toglie il proprio fondo di carta. Serve quando la pagina vive DENTRO un
## altro pannello (le impostazioni): due fondi di carta sovrapposti fanno un
## bordo doppio e un'ombra che non torna. Da sola — se un giorno qualcuno la
## aprisse dal titolo — il fondo se lo tiene.
func incorpora() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	custom_minimum_size = Vector2(0, 420)


# =========================================================================
# I FILE
# =========================================================================

## Il provino forza la risposta per fotografare tutte e due le pagine senza
## avere un cuore compilato con llama.cpp. In partita resta -1, cioè «chiedi a
## chi lo sa». Non è un secondo interruttore: è l'assenza di uno.
var forza_modello := -1


## Questo gioco può usare un modello linguistico, quindi ci sono i suoi
## documenti da leggere?
##
## ⚠️ **`disponibile()` e non `leva_visibile()`**, e la differenza è tutta la
## fase. `leva_visibile()` chiede «il binario sa scrivere **E il file c'è**»:
## è la domanda giusta per la casella nelle impostazioni (una casella deve
## avere qualcosa da spegnere), ed è la domanda sbagliata qui. I Gemma Terms
## of Use vincolano il giocatore **per il fatto stesso di scaricare** il
## modello: mostrargli i documenti solo quando il file è già sul disco vuol
## dire mostrarglieli **dopo** che si è vincolato. Qui la porta è la funzione,
## non il file.
func _col_modello() -> bool:
	if forza_modello >= 0:
		return forza_modello == 1
	return Llm.disponibile()


static func percorso(file: String) -> String:
	return CARTELLA.path_join(file)


static func _esiste(file: String) -> bool:
	return FileAccess.file_exists(percorso(file))


static func _leggi(file: String) -> String:
	var f := FileAccess.open(percorso(file), FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


func _titolo_di(file: String) -> String:
	for d in DOCUMENTI:
		if str(d["file"]) == file:
			return str(d["titolo"])
	return file


## C'è almeno un documento leggibile da qui? Se no, la pagina lo dice invece
## di mostrare bottoni spenti senza spiegazione.
func _qualcosa_da_leggere() -> bool:
	for d in DOCUMENTI:
		if bool(d["solo_col_modello"]) and not _col_modello():
			continue
		if _esiste(str(d["file"])):
			return true
	return false
