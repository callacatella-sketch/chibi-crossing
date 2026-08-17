class_name OffertaModello
extends PanelContainer

## LA SCHERMATA CHE CHIEDE — due gigabyte e mezzo sono una cosa che si
## domanda, non una che si prende.
##
## Dal 2026-08-13 il modello non viaggia più dentro il pacchetto: si scarica
## al primo uso. Questa è la pagina che lo chiede, e il giocatore la vede
## **una volta sola in tutta la partita**: è lei a decidere se userà mai la
## funzione, e quindi vale la pena scriverla bene.
##
## ────────────────────────────────────────────────────────────────────────
## LE REGOLE, e nessuna è di gusto
## ────────────────────────────────────────────────────────────────────────
##
## 1. **PRIMA SI CHIEDE ALLA MACCHINA, POI SI CHIEDE ALLA PERSONA.** Su un
##    computer che non ha la memoria per tenere aperto il modello, il
##    villaggio non penserebbe **comunque** — e chiedere mezz'ora di rete e
##    due gigabyte e mezzo di disco per arrivare a quel niente è la cosa
##    peggiore che questa fase possa fare a qualcuno, perché il guasto non è
##    collegabile alla causa: si vedrebbe solo un gioco che non fa quello che
##    ha promesso. Il verdetto è `Capienza.della_memoria()`, e se dice di no
##    **il download non viene nemmeno nominato**.
## 2. **NESSUNA INSISTENZA, MAI.** Niente punti esclamativi, niente
##    «sblocca», niente contatore di cose che ti perdi, niente bottone di
##    rifiuto scritto in grigio piccolo. Le due risposte hanno la stessa
##    misura e lo stesso peso visivo, e sotto c'è scritto — come un fatto,
##    non come una consolazione — che dicendo di no non cambia niente.
##    **Perché è vero**: il villaggio è già scritto a mano, e resta.
## 3. **DIRE DI NO NON SCRIVE NIENTE.** Non si tocca `Settings.llm_spento`,
##    non si lascia un file, non si segna da nessuna parte che «gliel'ho
##    chiesto e ha detto di no». La casella torna spenta perché il villaggio
##    non pensa, che è la verità, e la prossima volta la domanda è nuova.
## 4. **L'ACCETTAZIONE DELLA LICENZA È UN ATTO, NON UNA RIGA PICCOLA.**
##    Scaricando Gemma il giocatore si vincola ai Gemma Terms of Use (è il
##    preambolo dell'accordo: *reproducing*), e nessun altro glieli mostra —
##    il repository a monte non è più «gated». Quindi: i due documenti si
##    leggono **qui**, per intero, prima del primo byte; la casella è spenta
##    di serie e dice **cosa** si accetta; e porta la dichiarazione di
##    capacità della Sezione 2.1 (l'età), perché questo è un gioco cozy e fra
##    chi lo apre ci sono bambini. Il ragionamento completo, con le clausole,
##    sta in `docs/LICENZA_MODELLO.md`.
## 5. **I DOCUMENTI NON SI RICOPIANO QUI DENTRO.** Li mostra il lettore di
##    `NoteLegali` (`mostra_documento`), che è anche la pagina da cui
##    resteranno leggibili per sempre. Due modi di mostrare la stessa
##    licenza vuol dire che uno dei due invecchia.
## 6. **SI PUÒ CHIUDERE E CONTINUARE A GIOCARE.** Chi scarica è un nodo
##    appeso alla radice (`Scarico`), non un figlio di questa pagina:
##    venti minuti davanti a una barra sono venti minuti tolti al gioco.
##    Riaprendo, la pagina ritrova il download dov'era.
##
## ⚠️ **E NON SI FA VEDERE A CHI NON HA CHIESTO NIENTE.** Non al primo
## avvio, non nel Prologo, non fra «nuova avventura» e il temporale: solo
## dietro la casella «Il villaggio pensa», e solo perché qualcuno l'ha
## toccata.

## Chiusa: si torna al pannello, che si ridisegna. **È l'unico segnale**, e
## basta: finché questa pagina è aperta il pannello sta dietro, nascosto —
## un secondo segnale «qualcosa è cambiato» lo farebbe ricostruire proprio
## mentre il giocatore legge «è arrivato», cioè lo butterebbe fuori dalla
## pagina un istante prima della sua unica frase bella.
signal closed

## Dove si segna che i termini sono stati accettati, e cosa si era letto.
## Sta **accanto al modello** e non nelle impostazioni, ed è una scelta: se
## chi gioca cancella la cartella dei modelli, cancella anche il consenso —
## e la volta dopo il gioco glielo richiede, che è esattamente giusto perché
## quella volta scaricherà di nuovo.
const RICEVUTA := "user://modelli/accettazione.json"

## I due documenti che si devono poter leggere prima di accettare. I nomi
## dei file sono quelli di `NoteLegali.DOCUMENTI`: si citano, non si
## reinventano.
const TERMINI := "Gemma-Terms-of-Use.txt"
const DIVIETI := "Gemma-Prohibited-Use-Policy.txt"

## PER I PROVINI E PER I BANCHI: i numeri della macchina scritti a mano, così
## si possono fotografare tutte le pagine su un computer solo. Vuoto = si
## chiede alla macchina vera. **Non è un secondo interruttore: è l'assenza di
## uno** (la stessa convenzione di `NoteLegali.forza_modello`).
var forza_macchina := {}

var _pagina := ""
var _verdetto := ""
var _esito := ScaricoMacchina.ESITO_NIENTE
var _corpo: VBoxContainer
var _scorri: ScrollContainer
var _dentro: VBoxContainer
var _piede: VBoxContainer
var _titolo: Label
var _note: NoteLegali
var _accetto := false
var _bottone_scarica: Button
var _barra: ProgressBar
var _riga_barra: Label
var _riga_tempo: Label
var _scarico: Scarico


func _ready() -> void:
	add_theme_stylebox_override("panel", CozyUI.paper_panel(28))
	# Larghezza sì, altezza no: l'altezza la decide quello che c'è scritto
	# (vedi `_adatta_altezza`).
	custom_minimum_size = Vector2(560, 0)
	_impianto()
	riparti()


## L'OSSATURA, costruita una volta sola: titolo, corpo che scorre, piede che
## non scorre. Le pagine cambiano quello che sta in mezzo.
##
## ⚠️ **IL PIEDE STA FUORI DALLO SCORRIMENTO**, e non è impaginazione: le due
## risposte devono essere sotto gli occhi **senza dover scorrere**. Una
## schermata in cui «Non adesso» sta sotto la piega, e «Scaricalo» no, è una
## schermata che spinge — cioè la regola 2 rotta con la grafica invece che
## con le parole.
func _impianto() -> void:
	_corpo = VBoxContainer.new()
	_corpo.add_theme_constant_override("separation", 12)
	add_child(_corpo)

	_titolo = CozyUI.title_label("", 28)
	_corpo.add_child(_titolo)

	_scorri = ScrollContainer.new()
	_scorri.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scorri.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_corpo.add_child(_scorri)

	_dentro = VBoxContainer.new()
	_dentro.add_theme_constant_override("separation", 12)
	_dentro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# SHRINK_BEGIN e non FILL: dentro uno ScrollContainer un figlio che
	# «riempie» viene stirato all'altezza dello scorrimento, e la sua altezza
	# smette di dire quanto è alto il contenuto — che è esattamente il numero
	# che serve a `_adatta_altezza()`.
	_dentro.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scorri.add_child(_dentro)

	_piede = VBoxContainer.new()
	_piede.add_theme_constant_override("separation", 10)
	_corpo.add_child(_piede)

	# Il lettore delle licenze: vive accanto, spento, e si prende lo schermo
	# quando serve. Costruirlo adesso costa niente (la pagina si riempie da
	# sola al primo `_apri`) e toglie di mezzo il caso «l'ho chiesto e non
	# c'è ancora».
	_note = NoteLegali.new()
	add_child(_note)
	_note.incorpora()
	_note.visible = false
	_note.closed.connect(_chiudi_documento)


# =========================================================================
# QUALE PAGINA
# =========================================================================

## Riparte dalla pagina giusta. La chiama chi ospita ogni volta che apre: la
## risposta dipende dal mondo (c'è un download in corso? c'è un pezzo? questa
## macchina ce la fa?), e il mondo cambia fra un'apertura e l'altra.
func riparti() -> void:
	_chiudi_documento()
	_scarico = Scarico.vivo(get_tree())
	if _scarico != null and _scarico.esito() == ScaricoMacchina.ESITO_NIENTE:
		_collega_scarico()
		_vai("scarico")
		return
	if Llm.modello_in_casa():
		_vai("arrivato")
		return
	var verdetto := _verdetto_macchina()
	if not Capienza.si_puo_offrire(verdetto):
		_verdetto = verdetto
		_vai("macchina")
		return
	# Un pezzo già scaricato vale come domanda già fatta — ma **solo** se
	# anche il consenso c'è: un pezzo senza ricevuta vuol dire che qualcuno
	# ha rovistato nella cartella, e allora si ricomincia dalla domanda.
	if Scarico.parziale_byte() > 0 and _gia_accettato():
		_vai("pezzo")
		return
	_vai("offerta")


## IL VERDETTO SULLA MACCHINA. I numeri veri li dà il binario; il giudizio lo
## dà `Capienza`, che è puro e si può interrogare. Qui in mezzo non c'è
## nessuna regola: solo il trasporto.
func _verdetto_macchina() -> String:
	var n := _numeri_macchina()
	if n.is_empty():
		return "non_lo_so"
	return Capienza.della_memoria(int(n.get("totale", 0)), int(n.get("libera", 0)),
			Llm.RAM_MODELLO, int(n.get("riserva", 0)), int(n.get("tetto", 0)))


func _numeri_macchina() -> Dictionary:
	if not forza_macchina.is_empty():
		return forza_macchina
	var cuore := Llm.apri()
	if cuore == null:
		return {}
	var mem: Dictionary = cuore.call("memoria")
	var lim: Dictionary = cuore.call("limiti")
	return {"totale": int(mem.get("totale_sistema", 0)),
			"libera": int(mem.get("libera_sistema", 0)),
			"riserva": int(lim.get("riserva_byte", 0)),
			"tetto": int(lim.get("tetto_byte", 0))}


func _vai(pagina: String) -> void:
	_pagina = pagina
	set_process(pagina == "scarico")
	for c in _dentro.get_children():
		_dentro.remove_child(c)
		c.queue_free()
	for c in _piede.get_children():
		_piede.remove_child(c)
		c.queue_free()
	_scorri.scroll_vertical = 0
	match pagina:
		"offerta": _pagina_offerta()
		"pezzo": _pagina_pezzo()
		"macchina": _pagina_macchina()
		"scarico": _pagina_scarico()
		"guasto": _pagina_guasto()
		"arrivato": _pagina_arrivato()
	_adatta_altezza.call_deferred()


## LA PAGINA È ALTA QUANTO QUELLO CHE DICE. Le sei pagine hanno lunghezze
## molto diverse — l'offerta è un discorso, «è arrivato» sono due righe — e
## un'altezza fissa vuol dire o un'offerta che si taglia o un mezzo foglio
## vuoto sotto tre parole. MISURATO guardando: con l'altezza fissa a 560, la
## pagina dello scaricamento aveva **quattrocento pixel di niente** in mezzo.
##
## Il numero non è per pagina (sarebbero sei numeri da tenere allineati alle
## parole, e le parole cambiano): è **derivato** dal contenuto, con un solo
## tetto — oltre il quale si scorre, perché una pagina più alta dello schermo
## di chi gioca è una pagina rotta.
##
## Differito di un fotogramma perché prima di una passata di disposizione un
## `Label` che va a capo non sa quanto è alto: non conosce ancora la propria
## larghezza.
##
## ⚠️ **IL TETTO È TARATO SULL'INGLESE, non sull'italiano.** Le righe inglesi
## sono più lunghe e vanno a capo in altri punti: a 430 l'offerta italiana ci
## stava intera e quella inglese si tagliava **in mezzo a una riga** — un
## paragrafo mozzato sul filo della piega, che si legge come una schermata
## rotta anche se scorre benissimo. Visto nella foto del provino, non nel
## codice. A 560 ci stanno tutte e due, e la pagina più alta resta sotto gli
## 800 punti — cioè dentro lo schermo del gioco (1080) col suo pannello
## attorno.
const TETTO_SCORRIMENTO := 560


func _adatta_altezza() -> void:
	if _dentro == null or not is_inside_tree():
		return
	var alto := int(_dentro.get_combined_minimum_size().y)
	_scorri.custom_minimum_size.y = float(mini(alto, TETTO_SCORRIMENTO))


# =========================================================================
# LA DOMANDA
# =========================================================================

func _pagina_offerta() -> void:
	_titolo.text = L10n.t("Il villaggio pensa")
	_dentro.add_child(_prosa(L10n.t(
			"Ogni tanto un vicino si accorge di qualcosa, ci pensa su, e più tardi fa una cosa che nessuno gli ha chiesto di fare. A scrivere quei pensieri è un piccolo modello di linguaggio, che gira qui — sul tuo computer, mentre giochi.")))
	_dentro.add_child(_prosa(L10n.t(
			"Dentro il gioco non c'è: ne raddoppierebbe il peso, e se lo porterebbe appresso anche chi non lo vorrà mai. Se lo vuoi, si scarica una volta sola.")))

	# LA SCHEDA. La prosa racconta, la scheda **dichiara**: cosa si scarica,
	# quanto pesa, da dove viene, quante volte, quanto ci mette. Sono i cinque
	# fatti che una persona ha diritto di sapere prima di dire di sì, e stanno
	# insieme perché si leggano in un colpo d'occhio invece che a caccia
	# dentro un paragrafo.
	_dentro.add_child(_scheda([
		[L10n.t("Che cos'è"), "%s — %s" % [Llm.MODELLO_NOME, Llm.MODELLO_DI_CHI]],
		[L10n.t("Quanto pesa"), Capienza.in_giga(Llm.BYTE_MODELLO)],
		[L10n.t("Da dove"), Llm.SORGENTE_CASA],
		[L10n.t("Quante volte"), L10n.t("una sola: poi resta sul tuo disco")],
		[L10n.t("Quanto ci mette"), L10n.t("su una linea di casa, minuti — a volte una mezz'ora")],
	]))

	# LA RIGA CHE NESSUNO SI ASPETTA E CHE VA DETTA LO STESSO. Scaricare un
	# file mostra il proprio indirizzo a chi lo consegna: è vero per
	# qualunque cosa si scarichi, ma qui è il gioco a farlo fare, e allora
	# lo dice il gioco. E si dice **nella stessa frase** l'altra metà, che
	# è quella che conta davvero: da qui non parte niente, mai.
	_dentro.add_child(_nota(L10n.t(
			"Mentre arriva, il tuo indirizzo si vede da Hugging Face e dalla rete che consegna il file — come per qualunque cosa si scarichi. Dal gioco non parte niente, né adesso né dopo: quello che i vicini pensano nasce su questa macchina e resta qui.")))

	_dentro.add_child(_prosa(L10n.t(
			"Il modello è di Google, e viaggia con le sue condizioni: scaricandolo le accetti. Restano leggibili per sempre da Impostazioni → Note legali.")))

	# ⚠️ **I DUE DOCUMENTI E LA CASELLA STANNO NEL PIEDE, cioè fuori dallo
	# scorrimento.** Nella prima stesura stavano in fondo alla pagina, sotto la
	# piega: MISURATO guardando la foto del provino — si vedeva un bottone
	# «Scaricalo» spento e nient'altro, e niente diceva perché. Una casella di
	# consenso che bisogna cercare non è un consenso; un bottone spento senza
	# la sua ragione accanto è un gioco rotto.
	_piede.add_child(_riga_documenti())
	_piede.add_child(_casella_accetto())
	_piede.add_child(_nota_centrata(L10n.t(
			"Se dici di no non cambia niente: il villaggio è già scritto a mano, e resta come lo conosci.")))
	_bottone_scarica = _bottoni(
			L10n.t("Non adesso"), func(): closed.emit(),
			L10n.t("Scaricalo"), _comincia)
	_bottone_scarica.disabled = not _accetto


## I DUE DOCUMENTI, leggibili qui. Il bottone porta il **nome** del
## documento, non «Leggi le condizioni»: chi lo preme sa già cosa gli si
## aprirà, ed è la stessa regola dell'indice delle Note legali.
func _riga_documenti() -> Control:
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 10)
	riga.add_child(_bottone_documento("Gemma Terms of Use", TERMINI))
	riga.add_child(_bottone_documento("Gemma Prohibited Use Policy", DIVIETI))
	return riga


## ⚠️ **UN DOCUMENTO CHE NON C'È NON SI FINGE.** Se il testo manca dal
## pacchetto, il bottone si spegne e sotto compare dove trovarlo: fingere di
## poterlo leggere è peggio che dire che non c'è, perché chi accetta crede di
## aver avuto la possibilità di leggere.
func _bottone_documento(nome: String, file: String) -> Control:
	var b := CozyUI.cozy_button(nome, CozyUI.SKY, 13)
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not FileAccess.file_exists(NoteLegali.percorso(file))
	b.pressed.connect(func(): _apri_documento(file))
	return b


## L'ATTO. Spento di serie, e l'etichetta **nomina** quello che si accetta:
## i due documenti per nome, e la dichiarazione di capacità della Sezione
## 2.1. Un «Ho capito» sotto un bottone «Scarica» non è un consenso — è una
## riga di testo vicino a un bottone.
func _casella_accetto() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CozyUI.soft_card(CozyUI.CREAM))
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 8)
	card.add_child(riga)
	var cb := CheckBox.new()
	cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = _accetto
	cb.add_theme_color_override("font_color", CozyUI.INK)
	cb.toggled.connect(func(on):
		_accetto = on
		if _bottone_scarica:
			_bottone_scarica.disabled = not on)
	riga.add_child(cb)
	var l := CozyUI.body_label(L10n.t(
			"Accetto i Gemma Terms of Use e la Prohibited Use Policy, e ho l'età per farlo."), 13)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	riga.add_child(l)
	return card


# =========================================================================
# LE ALTRE PAGINE
# =========================================================================

## IL PEZZO GIÀ ARRIVATO. Chi aveva detto di sì e si era fermato non deve
## ridire di sì: ha già accettato, e il consenso è agli atti. Gli si dice
## dov'era rimasto e gli si danno tre strade — riprendere, lasciar stare, o
## liberare il disco.
func _pagina_pezzo() -> void:
	_titolo.text = L10n.t("Il villaggio pensa")
	var gia := Scarico.parziale_byte()
	_dentro.add_child(_prosa(L10n.tf(
			"Ne era già arrivato un pezzo: %s di %s. Posso riprendere da lì — non si ricomincia da capo.",
			[Capienza.in_giga(gia), Capienza.in_giga(Llm.BYTE_MODELLO)])))
	_dentro.add_child(_nota(L10n.t(
			"Oppure lo butto via, e il disco torna com'era.")))
	# ⚠️ PIÙ PICCOLO E CENTRATO, non largo quanto la pagina. La regola dei due
	# bottoni della stessa misura vale fra le due RISPOSTE («non adesso» e
	# «riprendi»); questa è una terza cosa, e per giunta quella che cancella
	# roba. Un bottone a tutta larghezza sopra i due lo fa sembrare la scelta
	# principale — e la scelta principale, qui, è riprendere.
	var b := CozyUI.cozy_button(L10n.t("Butta via il pezzo"), CozyUI.LAVENDER, 13)
	b.custom_minimum_size = Vector2(200, 36)
	b.pressed.connect(_butta)
	var centro := CenterContainer.new()
	centro.add_child(b)
	_dentro.add_child(centro)
	_bottoni(L10n.t("Non adesso"), func(): closed.emit(),
			L10n.t("Riprendi"), _comincia)


## LA MACCHINA CHE NON CE LA FA. Due frasi diverse per due cose diverse:
## «adesso no» si può rimediare chiudendo qualcosa, «mai» no — e dire
## «riprova più tardi» a chi non potrà mai è una presa in giro gentile.
##
## ⚠️ **NIENTE NUMERI, e la ragione non è il gusto**: «servono 3664 MB liberi
## e ne hai 3391» è una frase che chiede a chi legge di fare un conto per
## capire una cosa su cui non può fare niente, e per giunta con l'unità
## sbagliata (nessuno sa quanta memoria ha libera adesso). Quello che serve
## sapere è: non c'è niente da scaricare, e non è colpa tua.
func _pagina_macchina() -> void:
	_titolo.text = L10n.t("Il villaggio pensa")
	if _verdetto == "mai":
		_dentro.add_child(_prosa(L10n.t(
				"Questo computer non ha memoria da prestargli, e non è una cosa che si aggiusta chiudendo una finestra.")))
		_dentro.add_child(_prosa(L10n.t(
				"Non c'è niente da scaricare, allora — meglio così, sarebbe stata una lunga attesa per niente. Il villaggio resta quello che conosci: le lettere e i pensieri scritti a mano ci sono tutti, e sono la maggior parte.")))
		_un_bottone(L10n.t("Va bene così"), func(): closed.emit())
		return
	_dentro.add_child(_prosa(L10n.t(
			"Questo computer, in questo momento, non ha memoria da prestargli. Un villaggio che pensa a spese del villaggio che si muove non sarebbe un buon affare.")))
	_dentro.add_child(_prosa(L10n.t(
			"Non c'è niente da scaricare, allora. Se chiudi qualcos'altro e torni qui, riprovo volentieri.")))
	_bottoni(L10n.t("Va bene così"), func(): closed.emit(),
			L10n.t("Riprova"), riparti)


## MENTRE ARRIVA. La barra, i due numeri veri, e la cosa più importante che
## si possa dire a chi ha davanti venti minuti: **che può andarsene**.
func _pagina_scarico() -> void:
	_titolo.text = L10n.t("Sta arrivando")
	_barra = _fai_barra()
	_dentro.add_child(_barra)
	_riga_barra = CozyUI.body_label("", 15)
	_riga_barra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dentro.add_child(_riga_barra)
	_riga_tempo = CozyUI.hint_label("", 13)
	_dentro.add_child(_riga_tempo)
	# Nasce invisibile: durante il preflight non c'è nessun tempo da dire, e
	# una riga vuota che tiene il suo posto è un buco in mezzo alla pagina.
	_dentro.add_child(_prosa(L10n.t(
			"Puoi chiudere questa pagina e tornare a giocare: va avanti per conto suo. Il villaggio comincerà a pensare dal prossimo avvio.")))
	_piede.add_child(_nota_centrata(L10n.t(
			"Se lo fermi, quello che è già arrivato resta: si riprende da lì.")))
	_un_bottone(L10n.t("Ferma"), _ferma)
	_aggiorna_barra()


## QUANDO VA STORTO. **La frase la dice `Scarico`**, non questa pagina: è lui
## che sa com'è andata, e una seconda tabella di frasi qui dentro sarebbe la
## gemella che diverge — con il guasto peggiore possibile, cioè un errore
## raccontato in due modi diversi a seconda di chi lo mostra.
##
## Quello che sceglie la pagina sono **le risposte**, e non sono uguali per
## tutti: dove il pezzo resta sul disco si offre di riprendere, dove non c'è
## niente da riprendere non si offre e basta. Un bottone «Riprendi» dopo un
## file buttato prometterebbe una cosa che non può fare.
func _pagina_guasto() -> void:
	_titolo.text = L10n.t("Il villaggio pensa")
	_dentro.add_child(_prosa(Scarico.frase(_esito)))
	match _esito:
		ScaricoMacchina.ESITO_SPAZIO, ScaricoMacchina.ESITO_DISCO:
			_dentro.add_child(_nota(L10n.t(
					"Quello che era arrivato l'ho lasciato dov'era: se fai un po' di posto, si riprende da lì.")))
			_bottoni(L10n.t("Va bene così"), func(): closed.emit(),
					L10n.t("Riprova"), _comincia)
		ScaricoMacchina.ESITO_IMPRONTA:
			_bottoni(L10n.t("Non adesso"), func(): closed.emit(),
					L10n.t("Ricomincia"), _comincia)
		ScaricoMacchina.ESITO_SORGENTE, ScaricoMacchina.ESITO_CHIUSO, \
				ScaricoMacchina.ESITO_SENZA_IMPRONTA:
			_dentro.add_child(_nota(L10n.t(
					"Non dipende da te né da questo computer: se il posto è cambiato, lo sistemiamo noi.")))
			_un_bottone(L10n.t("Va bene così"), func(): closed.emit())
		_:
			_bottoni(L10n.t("Non adesso"), func(): closed.emit(),
					L10n.t("Riprendi"), _comincia)


func _pagina_arrivato() -> void:
	_titolo.text = L10n.t("È arrivato")
	_dentro.add_child(_prosa(L10n.t(
			"Da qui in avanti, ogni tanto, un vicino avrà un'idea tutta sua: si accorgerà di qualcosa, ci penserà su, e andrà a fare una cosa che nessuno gli ha chiesto.")))
	_dentro.add_child(_nota(L10n.t(
			"Comincia dal prossimo avvio del gioco. Se un giorno cambi idea, basta spegnere «Il villaggio pensa» qui nelle impostazioni.")))
	_un_bottone(L10n.t("Va bene"), func(): closed.emit())


# =========================================================================
# I GESTI
# =========================================================================

## SI COMINCIA. È l'unico posto del gioco che apre una connessione, ed è
## sempre dietro un bottone premuto da una persona.
##
## ⚠️ **QUI, E SOLO QUI, SI SCRIVE UNA PREFERENZA.** Il «sì» è una scelta
## espressa, e va segnata subito — non alla fine del viaggio: il viaggio dura
## venti minuti, e in venti minuti questa pagina può benissimo essere stata
## chiusa (è quello che le si dice di fare, «torna a giocare»). Segnandola
## alla consegna, chi aveva spento «Il villaggio pensa» in passato si
## ritroverebbe il modello sul disco e il villaggio ancora muto, senza niente
## che glielo spieghi. Dire di no, invece, non scrive niente (regola 3).
func _comincia() -> void:
	_segna_accettazione()
	var s := get_node_or_null(^"/root/Settings")
	if s != null:
		s.call("set_llm_acceso", true)
	_scarico = Scarico.avvia(get_tree())
	_collega_scarico()
	_vai("scarico")


func _ferma() -> void:
	if _scarico != null:
		_scarico.annulla()
	riparti()


## Butta il pezzo, e con lui la ricevuta del consenso: chi ricomincerà da
## zero rifarà anche la domanda, perché scaricherà di nuovo — e un consenso
## dato mesi fa a documenti che nel frattempo possono essere cambiati non
## vale per il viaggio di domani.
func _butta() -> void:
	if _scarico != null:
		_scarico.annulla()
	Scarico.butta_il_parziale()
	if FileAccess.file_exists(RICEVUTA):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RICEVUTA))
	_accetto = false
	riparti()


func _collega_scarico() -> void:
	if _scarico != null and not _scarico.finito.is_connected(_su_finito):
		_scarico.finito.connect(_su_finito)


func _su_finito(esito: int, _diagnosi: String) -> void:
	if esito == ScaricoMacchina.ESITO_FATTO:
		_vai("arrivato")
		return
	if esito == ScaricoMacchina.ESITO_ANNULLATO:
		# Non è un guasto: è una persona che ha premuto «Ferma». Si torna a
		# guardare il mondo, che adesso ha un pezzo sul disco.
		riparti()
		return
	_esito = esito
	_vai("guasto")


func _process(_d: float) -> void:
	_aggiorna_barra()


## La riga che si muove. Si aggiorna dal `_process` e non dal segnale
## `avanzato` apposta: quel segnale arriva quattro volte al secondo e va
## bene, ma la pagina deve essere giusta anche al primo fotogramma in cui si
## apre — cioè PRIMA che ne arrivi uno.
##
## ⚠️ **LE PAROLE SONO DI `Scarico`**, di nuovo: `frase_fase()` sa dire anche
## i due momenti che questa pagina non vedrebbe («mi collego…», «controllo che
## sia arrivato tutto…»), e sono proprio quelli in cui una barra ferma senza
## una parola sembra un gioco piantato.
func _aggiorna_barra() -> void:
	if _scarico == null or _barra == null:
		return
	var fatti := _scarico.fatti()
	var totali := maxi(_scarico.totali(), 1)
	_barra.value = clampf(float(fatti) / float(totali) * 100.0, 0.0, 100.0)
	_riga_barra.text = _scarico.frase_fase()
	# Il tempo che manca si dice SOLO mentre arrivano byte: durante il
	# preflight e durante l'impronta non c'è nessun tempo da stimare, e un
	# «circa 14 minuti» che resta lì fermo mentre la barra non si muove è una
	# bugia piccola detta proprio nel momento in cui chi guarda è più teso.
	var bps := _scarico.al_secondo()
	if _scarico.fase() == ScaricoMacchina.FASE_CORPO and bps > 0.0:
		_riga_tempo.text = "%s · %s" % [
				L10n.rendi(Capienza.quanto_manca(totali - fatti, bps)),
				Capienza.velocita(bps)]
	else:
		_riga_tempo.text = ""
	# Invisibile quando è vuota: un `Label` senza testo occupa comunque la sua
	# riga, e in mezzo a una pagina corta si legge come un buco. Visto nella
	# foto della pagina «controllo che sia arrivato tutto…», non nel codice.
	_riga_tempo.visible = _riga_tempo.text != ""


# =========================================================================
# LA RICEVUTA DEL CONSENSO
# =========================================================================

## Si segna che i due documenti sono stati mostrati e accettati, **e quali**.
##
## ⚠️ **L'IMPRONTA E NON SOLO LA DATA.** Un documento porta dentro di sé la
## sua data («Last modified: …»), ma quella riga è testo come tutto il resto:
## se un domani si aggiorna la copia nel pacchetto e ci si dimentica di
## toccare la data, la ricevuta racconterebbe una cosa per un'altra. Lo
## SHA-256 dei byte mostrati non può mentire — e la riga della data si segna
## lo stesso, perché è quella che una persona sa leggere.
func _segna_accettazione() -> void:
	if _gia_accettato():
		return
	var d := {
		"quando": Time.get_datetime_string_from_system(true),
		"modello": Scarico.FILE_A_MONTE,
		"impronta_modello": Llm.IMPRONTA_SPEDITO,
		"documenti": [_scheda_documento(TERMINI), _scheda_documento(DIVIETI)],
	}
	DirAccess.make_dir_recursive_absolute(RICEVUTA.get_base_dir())
	var f := FileAccess.open(RICEVUTA, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d, "\t"))
	f.close()


func _gia_accettato() -> bool:
	return FileAccess.file_exists(RICEVUTA)


func _scheda_documento(file: String) -> Dictionary:
	var via := NoteLegali.percorso(file)
	var d := {"file": file, "impronta": "", "modificato": ""}
	if not FileAccess.file_exists(via):
		return d
	d["impronta"] = FileAccess.get_sha256(via)
	var f := FileAccess.open(via, FileAccess.READ)
	if f == null:
		return d
	# La riga della data, se c'è. Si cerca in testa al documento e basta: più
	# giù, dentro l'accordo, «last modified» può comparire in una frase.
	for _i in 60:
		if f.eof_reached():
			break
		var riga := f.get_line().strip_edges()
		if riga.to_lower().begins_with("last modified"):
			d["modificato"] = riga
			break
	f.close()
	return d


# =========================================================================
# IL LETTORE DELLE LICENZE
# =========================================================================

func _apri_documento(file: String) -> void:
	if not _note.mostra_documento(file):
		return
	_note.visible = true
	_corpo.visible = false


func _chiudi_documento() -> void:
	if _note == null:
		return
	_note.visible = false
	_corpo.visible = true


# =========================================================================
# I PEZZI DI CARTA
# =========================================================================

func _prosa(testo: String) -> Control:
	var l := CozyUI.body_label(testo, 15, CozyUI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _nota(testo: String) -> Control:
	var l := CozyUI.body_label(testo, 12, CozyUI.INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _nota_centrata(testo: String) -> Control:
	var l := CozyUI.hint_label(testo, 12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## LA SCHEDA DEI FATTI: una riga per fatto, l'etichetta a sinistra e il
## valore a destra. Un elenco puntato dentro un paragrafo si legge come
## prosa; una tabella si legge in un colpo d'occhio, ed è quello che serve a
## chi sta decidendo.
func _scheda(righe: Array) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CozyUI.soft_card())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	card.add_child(col)
	for r in righe:
		var riga := HBoxContainer.new()
		riga.add_theme_constant_override("separation", 12)
		var a := CozyUI.body_label(str(r[0]), 13, CozyUI.INK_SOFT)
		a.custom_minimum_size = Vector2(120, 0)
		riga.add_child(a)
		var b := CozyUI.body_label(str(r[1]), 14, CozyUI.INK)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		riga.add_child(b)
		col.add_child(riga)
	return card


## I DUE BOTTONI, della stessa misura. Torna quello di destra, perché è
## l'unico che a volte va spento (finché la casella non è spuntata).
##
## ⚠️ **LA STESSA MISURA NON È UN VEZZO.** Un «no» piccolo accanto a un «sì»
## grande è la forma grafica dell'insistenza, e questa pagina non ha il
## permesso di insistere: chi non vuole scaricare due gigabyte e mezzo ha
## ragione, e il gioco che gli resta è intero.
func _bottoni(sinistra: String, su_sinistra: Callable,
		destra: String, su_destra: Callable) -> Button:
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 14)
	riga.alignment = BoxContainer.ALIGNMENT_CENTER
	var a := CozyUI.cozy_button(sinistra, CozyUI.PINK, 17)
	a.custom_minimum_size = Vector2(210, 52)
	a.pressed.connect(su_sinistra)
	riga.add_child(a)
	var b := CozyUI.cozy_button(destra, CozyUI.MINT, 17)
	b.custom_minimum_size = Vector2(210, 52)
	b.pressed.connect(su_destra)
	riga.add_child(b)
	_piede.add_child(riga)
	return b


func _un_bottone(testo: String, su: Callable) -> void:
	var b := CozyUI.cozy_button(testo, CozyUI.PINK, 17)
	b.custom_minimum_size = Vector2(210, 52)
	b.pressed.connect(su)
	var centro := CenterContainer.new()
	centro.add_child(b)
	_piede.add_child(centro)


func _fai_barra() -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.min_value = 0.0
	p.max_value = 100.0
	p.value = 0.0
	p.custom_minimum_size = Vector2(0, 22)
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.84, 0.79, 0.7, 0.7)
	fondo.set_corner_radius_all(11)
	var pieno := StyleBoxFlat.new()
	pieno.bg_color = CozyUI.MINT
	pieno.set_corner_radius_all(11)
	p.add_theme_stylebox_override("background", fondo)
	p.add_theme_stylebox_override("fill", pieno)
	return p


## Toglie il fondo di carta: la pagina vive dentro il pannello delle
## impostazioni, e due fondi sovrapposti fanno un bordo doppio. Stessa
## regola, stesso gesto di `NoteLegali.incorpora()`.
func incorpora() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	custom_minimum_size = Vector2.ZERO
