extends Node

## L'ANFITEATRO — il mestiere dell'artista, e la sera in cui il villaggio
## si siede tutto insieme.
##
## Il sogno «artista» esisteva dal primo giorno in `Animo.SOGNI` e non
## portava da nessuna parte: chi lo sognava faceva la guardia come tutti
## gli altri. Ora ha un posto (il palco, la conchiglia, il pianoforte),
## un compito nel registro dei lavori (`suona`) e una scena.
##
## LE REGOLE, e perché sono queste:
##   · SI SUONA DI SERA. Il salone apre di giorno; il concerto no. Alle
##     lanterne accese la scena è un'altra cosa, e i due mestieri non si
##     pestano i piedi nella stessa mezza giornata.
##   · SERVE UN PUBBLICO. Un concerto senza nessuno che ascolta non è un
##     concerto: se non si siede nessuno, l'artista prova e basta, e il
##     registro del mattino non racconta niente.
##   · LA MUSICA È QUELLA VERA. Il brano lo compone `Concertino.componi`,
##     lo stesso compositore pentatonico del coro — una sola fonte per
##     "una melodia bella". Qui cambia il TIMBRO: martelletti e corde al
##     posto della cassettina.
##   · NIENTE SI ROMPE SE L'ANFITEATRO NON C'È. Senza pianoforte piazzato
##     l'artista fa il suo giro come tutti: il mestiere non pretende un
##     edificio per esistere.

const CONCERTINO := preload("res://scenes/interact/Concertino.gd")
const CHIBIESE := preload("res://audio/Chibiese.gd")

## Il mestiere e il sogno, dai vocabolari dell'animo (mai stringhe sparse).
const COMPITO := "suona"
const SOGNO := "artista"

## L'ora in cui si accordano gli strumenti e quella in cui si spengono le
## lanterne. È SERA: il salone tiene il giorno, il palco tiene il buio.
const APRE := 0.72
const CHIUDE := 0.92

## Da quanto lontano si sente e si accorre.
const RAGGIO_RICHIAMO := 22.0
## Quanti vicini al massimo si siedono (oltre, restano in piedi dietro).
const MAX_PUBBLICO := 8
## Quanto si aspetta prima che cominci, e quanto dura il silenzio fra un
## brano e l'altro.
const ATTESA_PUBBLICO := 9.0
const PAUSA_FRA_BRANI := 42.0

const RATE := 22050

## I titoli dei brani: due metà che si incastrano. Non sono decorazione —
## un brano con un nome è un brano che il giocatore può ricordare.
const TITOLO_A := ["Notturno", "Ninnananna", "Valzer", "Preludio", "Canzone",
		"Studio", "Serenata", "Berceuse"]
const TITOLO_B := ["delle lucciole", "per la pioggia lenta", "del ponte di legno",
		"per chi non dorme", "della prima neve", "dei tetti bagnati",
		"per una finestra accesa", "del vento fra i panni stesi",
		"della luna bassa", "per chi è partito"]

var _visitors: Node
var _build: Node3D
var _daynight: Node
var _lavori: Node
var _legami: Node
var _sfx

var _aperto := false
var _artista := ""              # label di chi suona stasera ("" = nessuno)
var _pubblico: Array[String] = []
var _t_attesa := 0.0
var _t_pausa := 0.0
var _t_brano := 0.0
var _tick := 0.0
var _player: AudioStreamPlayer3D
## quanti si sono seduti all'ultimo concerto: lo legge il registro
var _ascoltatori := 0
## le due metà ITALIANE del titolo di stasera: sono chiavi, e restano
## chiavi finché non si mostrano (vedi `programma`)
var _titolo_a := ""
var _titolo_b := ""


func _ready() -> void:
	add_to_group("concerto")
	# SFX SI PRENDE PER PERCORSO, non per gruppo: `Sfx` e' un AUTOLOAD e
	# NESSUN nodo del progetto entra mai nel gruppo "sfx" — quindi
	# `get_first_node_in_group("sfx")` tornava null PER SEMPRE, la riga che
	# assegna il bus non girava mai, e il pianoforte suonava su `Master`:
	# il cursore «Musica» delle impostazioni non lo governava. E' lo stesso
	# idioma di tutti gli altri trenta file (Concertino, HUD, Calendar…).
	_sfx = get_node_or_null(^"/root/Sfx")
	(func() -> void:
		_visitors = get_node_or_null("../Visitors")
		_build = get_tree().get_first_node_in_group("build_system")
		_daynight = get_node_or_null("../DayNight")
		_lavori = get_node_or_null("../Lavori")
		_legami = get_tree().get_first_node_in_group("legami")
		if _daynight and _daynight.has_signal("day_changed"):
			_daynight.day_changed.connect(_nuovo_giorno)).call_deferred()


## IL FILO ROSSO, CHIESTO PIGRAMENTE. `Legami` NON sta nella scena: lo crea
## `CozyWorld._ready()` dopo tre `await get_tree().process_frame`, e un
## `call_deferred` del nostro `_ready` si svuota a fine frame 0 — quindi lo
## trova `null` PER SEMPRE. Il consumatore e' protetto da un `if _legami:`
## e il fallimento e' MUTO: nessun errore, suite verde, e il momento non si
## annoda mai. E' lo stesso idioma gia' scritto in
## `PostoDiSempre._filo_rosso()`, col suo commento che racconta la stessa
## lezione: qui si riprova finche' non c'e'.
func _i_legami() -> Node:
	if _legami == null or not is_instance_valid(_legami):
		_legami = get_tree().get_first_node_in_group("legami")
	return _legami


func _nuovo_giorno(_g: int) -> void:
	_ascoltatori = 0
	_titolo_a = ""
	_titolo_b = ""


# ============================================================ la logica pura

## È l'ora del concerto? PURA.
static func ora_di_concerto(ora: float) -> bool:
	return ora >= APRE and ora < CHIUDE


## IL PROGRAMMA DELLA SERA: il titolo del brano e la musica, dallo stesso
## seme. PURO e deterministico — la stessa sera dà lo stesso concerto, e
## si prova headless senza far suonare niente.
static func programma(seme: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("concerto|%d" % seme)
	# LE DUE META' ESCONO SEPARATE, e in ITALIANO: sono CHIAVI, non testo.
	# Comporle qui e tradurre dopo era il difetto — `L10n.tf("«%s»", [x])`
	# traduce solo le virgolette, e in inglese uscivano ottanta titoli
	# italiani. Peggio: il titolo si annoda anche sul Filo Rosso, quindi
	# l'italiano finiva dentro il SALVATAGGIO.
	# `titolo` resta la composizione italiana perche' e' la chiave di
	# identita' del brano (deterministica, e ci si appoggia il test
	# dell'anfiteatro): il testo che il giocatore legge lo compone
	# `titolo_reso()`, traducendo PRIMA di unire.
	var a := str(TITOLO_A[rng.randi() % TITOLO_A.size()])
	var b := str(TITOLO_B[rng.randi() % TITOLO_B.size()])
	return {"titolo": "%s %s" % [a, b], "a": a, "b": b,
			"canzone": CONCERTINO.componi(seme)}


## Il titolo COME SI LEGGE, nella lingua di chi gioca: si traducono le due
## metà e solo dopo si uniscono. PURA — non tocca lo stato, e si prova
## headless cambiando lingua.
static func titolo_reso(a: String, b: String) -> String:
	if a == "" and b == "":
		return ""
	return "%s %s" % [L10n.t(a), L10n.t(b)]


## Quanti posti a sedere offre una fila di N gradinate: tre cuscini
## ciascuna, e mai più di quanti se ne possono guardare. PURA.
## Quanti posti offre UNA gradinata: e' il contratto col builder
## (BuildCatalog._gradinata crea altrettanti nodi "Posto*"), e il test
## dell'anfiteatro tiene allineate le due cose. A runtime fanno fede i
## nodi veri (posti.size() qui sotto): questa stima serve alla platea
## prevista prima che la serata cominci.
const POSTI_PER_GRADINATA := 4


static func posti_per(gradinate: int) -> int:
	return mini(maxi(gradinate, 0) * POSTI_PER_GRADINATA, MAX_PUBBLICO)


# ============================================================ la serata

func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.5:
		return
	var passo := _tick
	_tick = 0.0
	if _visitors == null or _build == null or _daynight == null:
		return

	var piano := _il_pianoforte()
	var ora := float(_daynight.get("time"))
	var deve_aprire := piano != null and ora_di_concerto(ora) \
			and _chi_ci_suona() != ""
	if deve_aprire != _aperto:
		_aperto = deve_aprire
		if _aperto:
			_apri(piano)
		else:
			_chiudi()
	if not _aperto:
		return
	_tick_serata(passo, piano)


## Il pianoforte piazzato (il primo, se ce n'è più d'uno): null se non c'è.
## È LUI il palco, non il tavolato: si può suonare su un prato, non si può
## suonare senza strumento.
func _il_pianoforte() -> Node3D:
	if _build == null:
		return null
	for n in _build.get_placed_by_name("Pianoforte"):
		if is_instance_valid(n):
			return n as Node3D
	return null


## Chi suona stasera: chi ha l'incarico «suona». Se nessuno ce l'ha, ci va
## chi lo sceglie di sua iniziativa nelle giornate libere.
func _chi_ci_suona() -> String:
	if _lavori == null:
		return ""
	var incarichi: Dictionary = _lavori.get("_incarichi")
	for label in incarichi:
		if str(incarichi[label]) == COMPITO:
			return str(label)
	var scelte: Dictionary = _lavori.get("_scelte")
	for label in scelte:
		if str(scelte[label]) == COMPITO:
			return str(label)
	return ""


func _apri(piano: Node3D) -> void:
	_artista = _chi_ci_suona()
	_pubblico.clear()
	_t_attesa = ATTESA_PUBBLICO
	_t_pausa = 0.0
	var nodo := _nodo_di(_artista)
	if nodo == null or piano == null:
		return
	# si siede alla PANCHETTA, rivolto alla tastiera: è il posto del
	# pianista, e non è lo stesso posto di chi ascolta
	var panca := piano.find_child("Panchetta", true, false) as Node3D
	var dove: Vector3 = panca.global_position if panca \
			else piano.global_position + piano.global_transform.basis * Vector3(0, 0, 0.55)
	if nodo.has_method("do_routine"):
		# la panchetta come mobile: senza, il pianista si accovacciava
		# sull'erba con la tavola che gli passava attraverso — e senza
		# `aux` non riusciva nemmeno ad ALZARSI, restando seduto fino alla
		# routine del mattino.
		# IL PUNTO D'ARRIVO NON PUO' ESSERE UN OFFSET IN COORDINATE MONDO:
		# `place_cell` ruota i pezzi, e `+Z mondo` a rotazione 2 finiva
		# DENTRO la cassa del pianoforte. Si prende la direzione OPPOSTA
		# allo strumento, che è il lato aperto qualunque sia l'orientamento.
		var verso_piano := piano.global_position - dove
		var largo: Vector3 = (dove - verso_piano.normalized() * 0.35) \
				if verso_piano.length() > 0.01 else dove
		nodo.call("do_routine", "bench", largo - Vector3(0, largo.y, 0),
				piano.global_position + Vector3(0, 0.5, 0), panca, _quanto_resta())
	# STASERA HA UN APPUNTAMENTO, E NON È COL GIOCATORE. Senza questa riga
	# `in_scena()` resta falsa per tutta la serata: chi suona non saluta più
	# nessuno, ma la testa la gira lo stesso — e un pianista che segue col
	# collo il cursore della costruzione mentre suona è il concerto rovinato.
	if nodo.has_method("apri_scena"):
		nodo.call("apri_scena", _quanto_resta())
	_chiama_il_pubblico(piano)
	_toast(L10n.tf("%s si siede al pianoforte. Le lanterne del palco si accendono.",
			[_artista]))


## Quanti secondi reali mancano alla fine della serata: è per tanto che si
## resta seduti. Senza, il timer di `r_bench` (14-22 s) scadeva a metà
## concerto e il palco si svuotava mentre la musica andava avanti da sola.
func _quanto_resta() -> float:
	if _daynight == null:
		return 40.0
	var ora := float(_daynight.get("time"))
	var cicli := float(_daynight.get("cycle_seconds")) if \
			_daynight.get("cycle_seconds") != null else 240.0
	return maxf(6.0, (CHIUDE - ora) * cicli)


func _chiudi() -> void:
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
	_player = null
	for chi in _pubblico:
		var n := _nodo_di(chi)
		if n != null and n.has_method("do_routine"):
			n.call("do_routine", "wander", n.global_position)
		# e la serata si CHIUDE anche nel corpo: `apri_scena` era stata aperta
		# fino a `CHIUDE`, e una serata che finisce prima lascerebbe il vicino
		# sordo al villaggio per tutti i secondi che avanzano
		if n != null and n.has_method("chiudi_scena"):
			n.call("chiudi_scena")
	_pubblico.clear()
	# ANCHE L'ARTISTA. Questo ramo liberava il pubblico e non toccava mai
	# chi suonava: era LUI a restare incollato alla panchetta fino alla
	# routine del mattino, ed è qui che andava sciolto.
	var suonatore := _nodo_di(_artista)
	if suonatore != null and suonatore.has_method("do_routine"):
		suonatore.call("do_routine", "wander", suonatore.global_position)
	if suonatore != null and suonatore.has_method("chiudi_scena"):
		suonatore.call("chiudi_scena")
	_artista = ""
	_t_brano = 0.0


func _tick_serata(delta: float, piano: Node3D) -> void:
	if _t_brano > 0.0:
		_t_brano -= delta
		if _t_brano <= 0.0:
			_applausi()
		return
	if _t_attesa > 0.0:
		_t_attesa -= delta
		return
	_t_pausa -= delta
	if _t_pausa > 0.0:
		return
	_t_pausa = PAUSA_FRA_BRANI
	# UN CONCERTO SENZA PUBBLICO NON È UN CONCERTO: se non si è seduto
	# nessuno, l'artista prova e basta — e il mattino non lo racconta.
	if _pubblico.is_empty():
		_chiama_il_pubblico(piano)
		return
	_suona(piano)


## IL PUBBLICO. I vicini che sono in giro nel raggio del richiamo si
## siedono sulle gradinate, uno per cuscino, dal più vicino al palco.
func _chiama_il_pubblico(piano: Node3D) -> void:
	var posti := _i_posti()
	if posti.is_empty():
		return
	var qui := piano.global_position
	var candidati: Array = []
	for r in (_visitors.get("_residents") as Array):
		var label := str(r.get("label", ""))
		if label == "" or label == _artista or label in _pubblico:
			continue
		var nodo := r.get("node") as Node3D
		if nodo == null or not is_instance_valid(nodo):
			continue
		if nodo.has_method("is_hidden") and bool(nodo.call("is_hidden")):
			continue
		if qui.distance_to(nodo.global_position) > RAGGIO_RICHIAMO:
			continue
		candidati.append({"label": label, "nodo": nodo,
				"d": qui.distance_to(nodo.global_position)})
	candidati.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
	for c in candidati:
		if _pubblico.size() >= mini(posti.size(), MAX_PUBBLICO):
			break
		var posto: Node3D = posti[_pubblico.size()]
		var p: Vector3 = posto.global_position
		var nodo2: Node3D = c["nodo"]
		if nodo2.has_method("do_routine"):
			# IL QUARTO ARGOMENTO E' IL POSTO. Senza, `r_bench` non solleva
			# nessuno: il vicino si accovacciava a terra, conficcato
			# nell'alzata di pietra del primo scalino, tagliato ai fianchi
			# col cuscino all'altezza della vita. E il terzo argomento e' il
			# palco: adesso `r_bench` lo legge, e chi ascolta guarda avanti.
			nodo2.call("do_routine", "bench",
					p - Vector3(0, p.y, 0) + (qui - p).normalized() * 0.5,
					qui, posto, _quanto_resta())
		# CHI ASCOLTA GUARDA IL PALCO, per tutta la serata: `in_scena()` lo
		# toglie ai gesti del giocatore (vedi `Percezione.puo_vedere`). Una
		# platea che si volta tutta insieme verso una staccionata appena posata
		# è la fine dell'unica scena in cui il villaggio sta fermo a guardare
		# qualcosa che non è Mochi.
		if nodo2.has_method("apri_scena"):
			nodo2.call("apri_scena", _quanto_resta())
		_pubblico.append(str(c["label"]))


## Tutti i cuscini di tutte le gradinate piazzate, ordinati per vicinanza
## al pianoforte: si riempie la prima fila prima dell'ultima.
func _i_posti() -> Array:
	var piano := _il_pianoforte()
	if piano == null or _build == null:
		return []
	var qui := piano.global_position
	var out: Array = []
	for g in _build.get_placed_by_name("Gradinata"):
		if not is_instance_valid(g):
			continue
		for c in (g as Node3D).find_children("Posto*", "Node3D", true, false):
			out.append(c)
	out.sort_custom(func(a, b):
		return qui.distance_to((a as Node3D).global_position) \
				< qui.distance_to((b as Node3D).global_position))
	return out


## SI SUONA. Il brano della sera esce dal pianoforte (non dalla testa
## dell'artista: la sorgente è lo strumento, e si sente da dove sta).
func _suona(piano: Node3D) -> void:
	var prog := programma(_giorno() * 31 + int(_t_pausa))
	var canzone: Dictionary = prog["canzone"]
	_titolo_a = str(prog["a"])
	_titolo_b = str(prog["b"])
	var durata := float(canzone["beats"]) * 60.0 / float(canzone["bpm"])
	_t_brano = durata + 1.2

	if _player != null and is_instance_valid(_player):
		_player.queue_free()
	_player = AudioStreamPlayer3D.new()
	_player.stream = _rendi_piano(canzone)
	_player.unit_size = 9.0
	_player.max_distance = 34.0
	# è MUSICA suonata da qualcuno: sta sul bus della musica, non su
	# quello degli effetti — o il cursore del volume mente al giocatore
	if _sfx and _sfx.has_method("bus_musica"):
		_player.bus = _sfx.call("bus_musica")
	piano.add_child(_player)
	_player.position = Vector3(0, 0.45, 0)
	_player.play()

	# chi ascolta guarda il palco e sta zitto — ma solo chi c'è ancora:
	# scrivere "attento" addosso a chi nel frattempo è andato a dormire
	# gli sfascia la posa del sonno (stessa lezione degli applausi)
	for chi in _pubblico:
		var n := _nodo_di(chi)
		if n != null and not (n.has_method("is_hidden") and bool(n.call("is_hidden"))):
			n.set_meta("postura", "attento")
	_toast(L10n.tf("«%s»", [titolo_reso(_titolo_a, _titolo_b)]))


## GLI APPLAUSI. Il brano finisce e il pubblico esplode: è il pagamento
## dell'artista, ed è l'unica cosa che questo mestiere produce.
func _applausi() -> void:
	var artista := _nodo_di(_artista)
	if artista != null:
		if artista.has_method("celebrate"):
			artista.call("celebrate")
		if artista.has_method("speak"):
			artista.call("speak", ["grazie", "felice"], "felice")
	var quanti := 0
	# CHI SE N'E' ANDATO NON APPLAUDE. La finestra del concerto (0.72-0.92)
	# scavalca quella del sonno, che si apre a 0.80, e `r_bench` e' fra gli
	# stati interrompibili: a meta' brano meta' platea e' a letto. Il
	# richiamo del pubblico gia' saltava chi e' `is_hidden()`; qui no, e
	# cosi' si distribuivano gesti d'affetto e momenti del Filo Rosso a chi
	# stava dormendo — una sera passata insieme che non e' mai successa.
	# Si toglie anche da `_pubblico`: restare in lista voleva dire un posto
	# occupato da un fantasma per tutta la serata.
	var restano: Array[String] = []
	for chi in _pubblico:
		var n := _nodo_di(chi)
		if n == null:
			continue
		if n.has_method("is_hidden") and bool(n.call("is_hidden")):
			continue
		restano.append(chi)
		quanti += 1
		n.set_meta("postura", "si_illumina")
		if n.has_method("_spawn_heart"):
			n.call("_spawn_heart")
		if n.has_method("speak"):
			n.call("speak", ["bello", "grazie"], "felice")
		# e fra chi suonava e chi ascoltava: una sera al buio insieme
		get_tree().call_group("affetti", "gesto",
				_nome_di(_artista), _nome_di(chi), "musica")
		get_tree().call_group("affetti", "gesto",
				_nome_di(chi), _nome_di(_artista), "musica")
		# il filo si annoda: aver ascoltato insieme è un momento vissuto
		var leg := _i_legami()
		if leg:
			# sul filo va la CHIAVE, non la frase composta: il momento
			# finisce nel salvataggio, e un salvataggio non ha una lingua
			leg.call("momento", _nome_di(chi), "musica", titolo_chiave())
	_pubblico = restano
	_ascoltatori = maxi(_ascoltatori, quanti)
	if quanti > 0:
		_toast(L10n.tf("%d vicini applaudono nel buio.", [quanti]) if quanti > 1 \
				else L10n.t("Un solo applauso, ma sincero."))


# ------------------------------------------------------- il timbro del piano

## IL PIANOFORTE. Un martelletto colpisce una corda: attacco durissimo,
## coda lunga, e le armoniche alte che muoiono PRIMA delle basse — è
## quello che distingue un pianoforte da un organo. Le corde vere sono
## anche un filo stonate verso l'acuto (inarmonicità): senza, il timbro
## suona di plastica.
static func _rendi_piano(canzone: Dictionary) -> AudioStreamWAV:
	var spb: float = 60.0 / float(canzone["bpm"])
	var totale := int((float(canzone["beats"]) + 2.0) * spb * RATE)
	var buf := PackedFloat32Array()
	buf.resize(totale)
	var voci := [
		{"note": canzone["melodia"], "vol": 0.30, "coda": 2.6},
		{"note": canzone["armonia"], "vol": 0.17, "coda": 2.4},
		{"note": canzone["basso"], "vol": 0.26, "coda": 3.4},
		{"note": canzone["arpeggio"], "vol": 0.10, "coda": 1.6},
	]
	for voce in voci:
		for nota in (voce["note"] as Array):
			_martelletto(buf, totale, spb,
					CHIBIESE.mtof(float(nota["midi"])),
					float(nota["b"]), float(nota["beats"]),
					float(voce["vol"]), float(voce["coda"]))
	var peak := 0.001
	for s in buf:
		peak = maxf(peak, absf(s))
	var gain := 0.78 / peak
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	return wav


static func _martelletto(buf: PackedFloat32Array, totale: int, spb: float,
		freq: float, beat: float, beats: float, vol: float, coda: float) -> void:
	var da := int(beat * spb * RATE)
	var n := int(minf(beats * spb + coda, 3.6) * RATE)
	# le corde gravi suonano più a lungo e più cupe: è il pianoforte, non
	# un sintetizzatore che tratta tutti i tasti allo stesso modo
	var grave := clampf((520.0 - freq) / 480.0, 0.0, 1.0)
	var decadi := lerpf(2.4, 0.75, grave)
	var inarm := 0.00042
	for i in n:
		var j := da + i
		if j >= totale:
			break
		var t := float(i) / RATE
		var s := 0.0
		for h in 6:
			var arm := float(h + 1)
			# inarmonicità: l'armonica h-esima è più alta del multiplo esatto
			var f := freq * arm * sqrt(1.0 + inarm * arm * arm)
			if f > float(RATE) * 0.45:
				break
			var peso := pow(0.52, float(h)) * (1.0 + grave * 0.5 * float(h > 0))
			s += peso * sin(TAU * f * t) * exp(-t * decadi * (1.0 + float(h) * 0.55))
		# il TONFO del martelletto: un soffio brevissimo che dà il colpo
		if t < 0.012:
			s += (randf() * 2.0 - 1.0) * 0.22 * (1.0 - t / 0.012)
		buf[j] += s * vol * minf(t / 0.0015, 1.0)


# ------------------------------------------------------- il resto

## Quanti si sono seduti ad ascoltare oggi: lo legge il registro dei
## lavori per la resa del mattino.
func ascoltatori_di_oggi() -> int:
	return _ascoltatori


## Il titolo di stasera, GIÀ TRADOTTO: lo legge il registro dei lavori e
## finisce dritto nella riga del mattino, quindi qui è testo, non chiave.
func titolo_di_oggi() -> String:
	return titolo_reso(_titolo_a, _titolo_b)


## Le due metà italiane, per chi deve CONSERVARE il titolo invece di
## mostrarlo (il Filo Rosso): "" se stasera non si è ancora suonato.
func titolo_chiave() -> String:
	return "%s|%s" % [_titolo_a, _titolo_b] if _titolo_a != "" else ""


func in_scena() -> bool:
	return _aperto


## IL CARTELLINO. Qui c'era prima un ramo su `get_first_node_in_group("toast")`
## + `show_toast`: un gruppo che NESSUN nodo del progetto popola e un metodo
## che non esiste da nessuna parte. Non era un ripiego, era un ramo morto —
## e teneva in piedi l'illusione che il cartellino avesse due strade.
## La strada è una sola, ed è quella che il villaggio usa davvero.
func _toast(testo: String) -> void:
	if _visitors and _visitors.has_method("_show_toast"):
		_visitors.call("_show_toast", testo)


func _giorno() -> int:
	return int(_daynight.get("day")) if _daynight else 1


func _nodo_di(label: String) -> Node3D:
	if label == "" or _visitors == null:
		return null
	for r in (_visitors.get("_residents") as Array):
		if str(r.get("label", "")) == label:
			var n := r.get("node") as Node3D
			return n if (n != null and is_instance_valid(n)) else null
	return null


func _nome_di(label: String) -> String:
	if _visitors == null:
		return label
	for r in (_visitors.get("_residents") as Array):
		if str(r.get("label", "")) == label:
			return str((r.get("dna", {}) as Dictionary).get("name", label))
	return label
