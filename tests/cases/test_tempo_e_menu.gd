extends RefCounted
## IL TEMPO DEL VILLAGGIO, E QUELLO CHE IL GIOCO NE RACCONTA.
##
## Quattro guasti veri, tutti sul confine fra una misura continua (l'ora
## del giorno, la sbronza che si smaltisce) e un conto intero (il giorno,
## il bicchiere, la stagione). Sono i posti dove un `floor()` di troppo o
## una costante ricopiata costano una giornata di villaggio.
##
## Qui non si legge nessun sorgente per cercarci una stringa: si ISTANZIA
## il nodo vero, si fanno girare i suoi frame veri e si misura. L'unica
## eccezione è dichiarata dove sta, e serve solo a tenere il cablaggio
## della dormita attaccato al meccanismo che questo file prova davvero.

const DN := preload("res://scenes/world/DayNight.gd")
const RIASS := preload("res://scenes/ui/RiassuntoSalvataggio.gd")
const SBOR := preload("res://scenes/interact/Sbornia.gd")
const MAIL := preload("res://scenes/interact/Mail.gd")

## Quanto dura davvero una dormita, in secondi reali: 2.1 di "zzz" + 1.5
## di tenda che cala + ~8.5 di sogno (Interactions._sleep_until_morning).
const DORMITA := 12.1


func run(t) -> void:
	_test_dormita_un_giorno_solo(t)
	_test_orologio_fermo_e_poi_riparte(t)
	_test_la_notte_in_bianco_conta_ancora(t)
	_test_cablaggio_dormita(t)
	_test_stagione_del_menu(t)
	_test_battute_al_bicchiere_giusto(t)
	_test_posta_letta_chiede_di_salvare(t)


# ====================================================== il conto dei giorni

## Un DayNight VERO, coi due nodi che pretende dal livello (il sole e
## l'ambiente): così `_process`, `set_time` e `_apply` girano davvero.
## I frame glieli diamo noi uno per uno — `set_process(false)` — perché il
## bug vive nel NUMERO di frame passati sullo schermo nero.
func _daynight_vivo(t) -> Node3D:
	var radice := Node3D.new()
	radice.name = "LivelloDiProva"

	var sole := DirectionalLight3D.new()
	sole.name = "Sun"
	radice.add_child(sole)

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	var cielo := Sky.new()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/sky.gdshader")
	cielo.sky_material = mat
	env.sky = cielo
	we.environment = env
	radice.add_child(we)

	var dn = DN.new()
	dn.name = "DayNight"
	radice.add_child(dn)

	t.stage(radice)          # è qui che scattano i _ready
	dn.set_process(false)
	return dn


# fa girare `secondi` di gioco vero, un frame da 1/60 alla volta
func _frames(dn: Node3D, secondi: float) -> void:
	var passo := 1.0 / 60.0
	var quanti := int(ceil(secondi / passo))
	for _i in quanti:
		dn._process(passo)


# la dormita del letto, nell'ordine ESATTO di Interactions._sleep_until_morning
func _dormi(dn: Node3D) -> void:
	dn.call("sospendi_tempo", true)
	_frames(dn, DORMITA)
	dn.call("sospendi_tempo", false)
	dn.set_time(dn.MORNING)


## UNA NOTTE = UN GIORNO. Qualunque sia l'ora a cui Mochi si corica.
##
## La finestra fatale è stretta e per questo era invisibile: andando a
## letto negli ULTIMI istanti di notte (qui: time 0.2420 e 0.2450, cioè
## meno di due secondi reali prima dell'alba) i dodici secondi di tenda e
## sogno bastavano a far attraversare l'alba a `time` da solo — +1 giorno —
## e la sveglia `set_time(MORNING)` veniva poi letta come salto
## all'indietro: +1 di nuovo. Ci si addormentava al Giorno 2 e ci si
## svegliava al Giorno 4, con un'intera giornata di villaggio consumata in
## un frame sul nero.
func _test_dormita_un_giorno_solo(t) -> void:
	var dn := _daynight_vivo(t)
	# le ore in cui il letto offre «dormi fino al mattino» (is_night), dalle
	# prime stelle fino al filo dell'alba
	for ora in [0.80, 0.95, 0.02, 0.20, 0.2420, 0.2450]:
		dn.day = 2
		dn.time = float(ora)
		_dormi(dn)
		t.eq(dn.day, 3, "a letto alle %.4f: si sveglia UN giorno dopo" % ora)
		t.almost(dn.time, dn.MORNING, "la sveglia atterra al mattino", 0.0001)


## L'orologio è davvero fermo mentre si dorme — e riparte dopo.
## (Se non si fermasse, tutto il villaggio continuerebbe a girare sul nero:
## posta, orto, promesse, tick dei Legami.)
func _test_orologio_fermo_e_poi_riparte(t) -> void:
	var dn := _daynight_vivo(t)
	dn.day = 5
	dn.time = 0.2430
	dn.call("sospendi_tempo", true)
	t.ok(bool(dn.call("tempo_sospeso")), "durante la dormita l'orologio è sospeso")
	_frames(dn, DORMITA)
	t.almost(dn.time, 0.2430, "a orologio fermo l'ora non si muove", 0.00001)
	t.eq(dn.day, 5, "e nessun giorno passa da solo sullo schermo nero")
	dn.call("sospendi_tempo", false)
	t.ok(not bool(dn.call("tempo_sospeso")), "alla sveglia l'orologio riparte")
	_frames(dn, 1.0)
	t.ok(dn.time > 0.2430, "e il tempo ricomincia a scorrere")


## LA CONTROPROVA. Chi resta in piedi tutta la notte deve vedere il giorno
## cambiare da sé: la correzione non doveva spegnere l'alba naturale (era
## l'altro modo, sbagliato, di far tornare il conto).
func _test_la_notte_in_bianco_conta_ancora(t) -> void:
	var dn := _daynight_vivo(t)
	dn.day = 7
	dn.time = 0.27
	_frames(dn, 12.0)          # 12 s reali = 0.05 di ciclo: l'alba passa
	t.ok(dn.time > dn.MORNING, "il tempo ha attraversato il mattino")
	t.eq(dn.day, 8, "restando svegli, l'alba conta UN giorno")


## L'unico controllo di FACCIATA di questo file, ed è dichiarato: prova che
## la dormita del letto usi il meccanismo qui sopra, e nell'ordine giusto
## (l'orologio riparte PRIMA della sveglia, o il mattino non verrebbe
## contato da nessuno). Il percorso vero non è provabile headless: aspetta
## dodici secondi di timer e di tween, e vuole mezzo MainLevel in scena.
func _test_cablaggio_dormita(t) -> void:
	var corpo := _corpo("res://scenes/interact/Interactions.gd", "_sleep_until_morning")
	t.ok(corpo != "", "trovato il corpo di _sleep_until_morning")
	var ferma := corpo.find("sospendi_tempo\", true")
	var riparte := corpo.find("sospendi_tempo\", false")
	var sveglia := corpo.find("_daynight.set_time(")
	t.ok(ferma >= 0, "la dormita ferma l'orologio")
	t.ok(riparte > ferma, "e lo fa ripartire dopo averlo fermato")
	t.ok(riparte >= 0 and sveglia > riparte,
			"l'orologio riparte PRIMA della sveglia, che conta il mattino")


## Il corpo di una funzione SENZA I COMMENTI. La prima stesura li teneva e
## il controllo è nato rosso per il motivo sbagliato: il commento che spiega
## la trappola cita `set_time(MORNING)`, e la ricerca lo trovava prima della
## chiamata vera. È esattamente il modo in cui un controllo di facciata
## racconta bugie — qui almeno se n'è accorto subito.
func _corpo(percorso: String, funzione: String) -> String:
	var f := FileAccess.open(percorso, FileAccess.READ)
	if f == null:
		return ""
	var src := f.get_as_text()
	f.close()
	var i := src.find("func %s(" % funzione)
	if i < 0:
		return ""
	var fine := src.find("\nfunc ", i + 1)
	var corpo := src.substr(i, (fine - i) if fine > i else -1)
	var righe := []
	for riga in corpo.split("\n"):
		if not str(riga).strip_edges().begins_with("#"):
			righe.append(riga)
	return "\n".join(righe)


# ======================================================= il menù del titolo

## LA STAGIONE DEL MENÙ È QUELLA DEL GIOCO. Tutti i 28 giorni dell'anno,
## e il giro dopo: il riassunto ridichiarava 28 giorni a stagione (l'anno
## INTERO) e sbagliava due giorni su tre. Al giorno 22 — pieno inverno — il
## Grande Albero del diorama si apriva con la chioma di primavera, ed è la
## prima cosa che il giocatore vede riaprendo il gioco.
func _test_stagione_del_menu(t) -> void:
	var dn = DN.new()          # basta il calendario: nessun albero, nessun _ready
	var sbagliati := 0
	for giorno in range(1, DN.YEAR_DAYS * 2 + 1):
		dn.day = giorno
		var vera: int = dn.get_season()
		var r = RIASS.da_salvataggio({"day": giorno})
		if int(r.stagione) != vera:
			sbagliati += 1
			t.eq(int(r.stagione), vera,
					"giorno %d: il menù è nella stagione del villaggio" % giorno)
	t.eq(sbagliati, 0, "nessun giorno dell'anno con la stagione sbagliata")
	# il giorno che si vedeva a occhio: inverno, non primavera
	var inverno = RIASS.da_salvataggio({"day": 22})
	t.eq(int(inverno.stagione), 3, "al giorno 22 il menù è in inverno")
	# e le costanti non sono più una copia a mano
	t.eq(RIASS.GIORNI_STAGIONE, DN.SEASON_DAYS, "la stagione dura quanto dice DayNight")
	t.eq(RIASS.GIORNI_ANNO, DN.YEAR_DAYS, "e l'anno pure")
	dn.free()


# ============================================================== il bancone

## LA BATTUTA AL BICCHIERE GIUSTO. `_bicchieri` è la SBRONZA e si smaltisce
## di continuo (mezzo bicchiere al minuto): usarla come chiave con un
## `floor()` faceva uscire la battuta del primo bicchiere due volte, e
## quelle del terzo, del quinto e dell'ottavo mai — il gran finale arrivava
## al nono. Qui si beve come si beve davvero: un bicchiere ogni otto
## secondi, con lo smaltimento vero in mezzo.
func _test_battute_al_bicchiere_giusto(t) -> void:
	var s = t.stage(SBOR.new())
	s.set_process(false)
	for k in range(1, 10):
		s.bevi()
		var uscita := str(s._toast.text) if s._toast_t > 0.0 else ""
		t.eq(uscita, str(SBOR.BATTUTE.get(k, "")),
				"bicchiere %d: esce la battuta scritta per lui (o nessuna)" % k)
		_frames_nodo(s, 8.0)          # otto secondi di chiacchiere al bancone
	# tornati sobri, la serata ricomincia: la prima battuta è di nuovo la prima
	_frames_nodo(s, 1200.0)
	t.almost(float(s._bicchieri), 0.0, "dopo venti minuti si è sobri", 0.0001)
	s.bevi()
	t.eq(str(s._toast.text), str(SBOR.BATTUTE[1]),
			"da sobri, il bicchiere successivo è di nuovo il primo")


func _frames_nodo(n: Node, secondi: float) -> void:
	n._process(secondi)


# ================================================================ la posta

class BuildFinto extends Node3D:
	signal placed_changed
	var salvataggi := 0

	func request_save() -> void:
		salvataggi += 1

	func get_placed_by_name(_nome: String) -> Array[Node3D]:
		return []


## LETTA È LETTA. Chiudere la busta cambia lo stato da salvare (`mail_current`
## sparisce), ma nessuno chiedeva di scriverlo: chi usciva subito dopo aver
## letto ritrovava la stessa lettera nella cassetta, col SUO REGALO. La posta
## si leggeva una volta e si incassava all'infinito.
func _test_posta_letta_chiede_di_salvare(t) -> void:
	var radice := Node3D.new()
	radice.name = "LivelloPosta"
	var player := Node3D.new()
	player.name = "Player"
	radice.add_child(player)
	var build := BuildFinto.new()
	build.name = "BuildSystem"
	radice.add_child(build)
	var posta = MAIL.new()
	posta.name = "Mail"
	radice.add_child(posta)
	# `%Player`: il nome unico vive solo dentro una scena con un proprietario,
	# e Mail lo pretende nel suo _ready — quindi si registra PRIMA di mettere
	# in scena, o il _ready arriva e non lo trova.
	player.owner = radice
	build.owner = radice
	posta.owner = radice
	player.unique_name_in_owner = true
	t.stage(radice)
	posta.set_process(false)

	posta._has_mail = true
	posta._current = {"from_key": "Il Gufo", "text_key": "Ho contato le stelle.",
			"gift": true}
	var disco: Dictionary = posta.save_extra()
	t.ok(disco.has("mail_current"),
			"prima di leggerla, la busta consegnata sta su disco (col regalo)")

	var prima: int = build.salvataggi
	posta._reading = true
	posta._close_letter()
	t.ok(build.salvataggi > prima,
			"chiudere la busta chiede di salvare (API pubblica, non _save_village)")
	t.ok(not posta.save_extra().has("mail_current"),
			"e da salvare non c'è più nessuna lettera in attesa")

	# la controprova del danno: quel disco vecchio, ricaricato, rimette la
	# lettera (e il regalo) nella cassetta — è esattamente ciò che succedeva
	# a chi usciva dal gioco appena finito di leggere
	posta._has_mail = false
	posta._current = {}
	posta.load_extra(disco)
	t.ok(posta._has_mail, "una busta salvata e mai chiusa torna nella cassetta")
	t.eq(str(posta._current.get("text_key", "")), "Ho contato le stelle.",
			"ed è la STESSA lettera, col suo regalo")
