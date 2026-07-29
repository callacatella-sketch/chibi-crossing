class_name Promesse
extends Node
## LE PROMESSE — l'unica cosa che dà al gioco un ADESSO senza dargli ansia.
##
## Ogni tanto, alla sera, un vicino smette di chiederti una cosa e ti dà un
## APPUNTAMENTO: «Domattina, quando si alza la bruma, allo stagno». E
## domattina lui è lì davvero, in piedi nella nebbia, rivolto all'acqua.
##
## Tre regole di design, non negoziabili:
##
## 1. L'appuntamento non è MAI un orario astratto: è ancorato a un FENOMENO
##    che il mondo già calcola e che quasi nessuno vede. Solo fenomeni
##    CERTI, mai l'arcobaleno: l'incerto è un dono, non un appuntamento —
##    promettere una cosa che potrebbe non accadere è il modo più veloce
##    per trasformare un invito in un'ansia.
##
## 2. Vive in DUE POSTI FISICI — una riga di gessetto sulla Lavagna e un
##    bigliettino nella cassetta — e MAI in un HUD. Niente toast, niente
##    marcatore, niente contatore di promesse mantenute. Se cerchi di
##    ricordartelo, guardi la lavagna: è il gioco che ti chiede di alzare
##    gli occhi dallo schermo interiore.
##
## 3. Se non ci vai NON PERDI NIENTE. Nessuna nocciolina, nessun rancore,
##    nessun blocco: la mattina dopo arriva una lettera che ti racconta la
##    scena che ti sei perso. Non perdi punti: perdi una scena. Ed è la
##    lettera a restituirtela, come racconto.
##
## Ogni finestra del mattino CONTIENE l'ora del risveglio nel letto: chi
## dorme si sveglia già dentro l'appuntamento e non lo manca per
## costruzione. Una promessa alla volta nel mondo: due «adesso» sono ansia.

const COZY := preload("res://scenes/world/CozyWorld.gd")
const ALBERO := preload("res://scenes/world/GrandTree.gd")
const WEATHER := preload("res://scenes/world/Weather.gd")
const DN := preload("res://scenes/world/DayNight.gd")

## LA FONTE UNICA DEI FENOMENI. Nessun altro file deve chiedersi «è
## autunno?» o «a che ora sale la nebbia»: si chiede a questa tabella.
##   finestra    quando il fenomeno È (ora del mondo, 0..1)
##   fine_attesa fino a quando il vicino resta lì: sempre OLTRE la
##               finestra, perché trentun secondi di bruma non bastano ad
##               attraversare il villaggio
##   parole      cosa dice in Chibiese quando arrivi
##   corto       come si chiama sul gessetto (la lavagna ha poco spazio)
const FEN := {
	"bruma": {
		"finestra": Vector2(0.27, 0.40), "fine_attesa": 0.55,
		"parole": ["piano", "nebbia", "bello"], "corto": "la bruma",
	},
	"levata": {
		"finestra": Vector2(0.70, 0.80), "fine_attesa": 0.86,
		"parole": ["aspetta", "pesce", "piano"], "corto": "la levata",
	},
	"neve": {
		"finestra": Vector2(0.29, 0.55), "fine_attesa": 0.66,
		"parole": ["neve", "sorpresa", "insieme"], "corto": "la prima neve",
	},
}

## L'ora in cui ci si sveglia nel letto: OGNI finestra del mattino deve
## contenerla, o chi dorme mancherebbe l'appuntamento senza colpa.
const ORA_RISVEGLIO := 0.29
## La sera in cui ci si dà appuntamento (attraversando questa ora).
const ORA_SERA := 0.70
const PROB_SERA := 0.22          # quanto spesso nasce una promessa
const RIPOSO_GIORNI := 3         # mai due sere di fila
const AMICIZIA_MINIMA := 2
const VICINO_R := 3.2            # quanto vicino al punto sta il vicino
const INCONTRO_R := 2.6          # e quanto vicino a lui devi arrivare tu

var _attiva := {}                # {chi, nome, giorno, fen, esito, arrivato}
var _storico := {}               # "label|giorno" già usati: mai due uguali
var _ultima := -99               # il giorno dell'ultima promessa fissata

var _dn: Node3D
var _visitors: Node
var _mail: Node
var _weather: Node
var _build: Node
var _player: Node3D
var _t_prec := -1.0              # l'ora del frame scorso (per gli attraversamenti)
var _t_manda := 0.0


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("promesse")
	(func() -> void:
		_dn = get_node_or_null("../DayNight")
		_visitors = get_node_or_null("../Visitors")
		_mail = get_node_or_null("../Mail")
		_weather = get_node_or_null("../Weather")
		_player = get_node_or_null("../Player")
		_build = get_tree().get_first_node_in_group("build_system")
	).call_deferred()


# ------------------------------------------------------- il cuore puro

## Il prossimo giorno in cui [param fen] accadrà di sicuro, a partire da
## DOMANI. -1 se non è prevedibile (e allora non si promette).
## PURA: la verifica il test senza mondo.
static func prossimo_giorno(fen: String, oggi: int) -> int:
	match fen:
		"bruma":
			# le mattine d'autunno: il primo giorno d'autunno da domani
			for d in range(oggi + 1, oggi + 1 + DN.YEAR_DAYS):
				if stagione_di(d) == 2:
					return d
		"levata":
			# i pesci salgono ogni sera: domani va bene
			return oggi + 1
		"neve":
			# il primo giorno d'inverno: la PRIMA neve, quella che si
			# ricorda — non una qualunque nevicata di gennaio
			for d in range(oggi + 1, oggi + 1 + DN.YEAR_DAYS):
				if stagione_di(d) == 3 and stagione_di(d - 1) != 3:
					return d
	return -1


## La stagione del giorno assoluto (0 primavera … 3 inverno). PURA.
static func stagione_di(giorno: int) -> int:
	@warning_ignore("integer_division")
	return ((giorno - 1) % DN.YEAR_DAYS) / DN.SEASON_DAYS


## La finestra oraria di un fenomeno.
static func finestra(fen: String) -> Vector2:
	return (FEN.get(fen, {}) as Dictionary).get("finestra", Vector2(0.3, 0.4))


## Fino a quando il vicino aspetta (oltre la finestra: dà il tempo di
## arrivare da qualunque punto del villaggio).
static func fine_attesa(fen: String) -> float:
	return float((FEN.get(fen, {}) as Dictionary).get("fine_attesa", 0.6))


## Chi promette e cosa, per un dato giorno. PURA e DETERMINISTICA: lo
## stesso giorno con gli stessi candidati dà sempre la stessa promessa,
## così ricaricare la partita non riscrive un appuntamento già preso.
## [param candidati]: [{label, nome, indole}]. {} se nessuno può.
static func scegli(giorno: int, candidati: Array) -> Dictionary:
	if candidati.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("promessa_%d" % giorno)
	var chi: Dictionary = candidati[rng.randi() % candidati.size()]
	# il fenomeno lo colora l'INDOLE: il mattiniero conosce la bruma, il
	# sognatore aspetta la neve, gli altri i pesci che salgono la sera
	var fen := "levata"
	match str(chi.get("indole", "")):
		"mattiniero":
			fen = "bruma"
		"sognatore":
			fen = "neve"
	var giorno_fen := prossimo_giorno(fen, giorno)
	if giorno_fen < 0:
		return {}
	return {"chi": str(chi.get("label", "")), "nome": str(chi.get("nome", "")),
			"giorno": giorno_fen, "fen": fen, "esito": "attesa",
			"arrivato": false}


# ------------------------------------------------------- il mondo vero

## Il fenomeno sta accadendo ADESSO? È l'UNICO punto del sistema che
## interroga il meteo e il mondo: tutto il resto ragiona sulla tabella.
func in_corso(fen: String) -> bool:
	if _dn == null:
		return false
	var ora := float(_dn.get("time"))
	var f := finestra(fen)
	if ora < f.x or ora > f.y:
		return false
	match fen:
		"bruma":
			return _weather != null and bool(_weather.call("is_misty"))
		"levata":
			return COZY.levata_dei_pesci(ora) > 0.6 \
					and (_weather == null or not bool(_weather.call("is_raining")))
		"neve":
			return float(_dn.call("snow_amount")) > 0.03
	return false


## Dove ci si dà appuntamento. Ricalcolato ADESSO, mai salvato: il mondo
## può cambiare fra la sera e il mattino.
func luogo_di(fen: String) -> Vector3:
	match fen:
		"bruma", "levata":
			# la riva sud dello stagno: di là si vede l'acqua bianca
			return COZY.POND_CENTER + Vector3(0, 0, COZY.POND_R + 1.3)
		"neve":
			return ALBERO.POS + Vector3(1.6, 0, 1.2)
	return COZY.POND_CENTER


## Quante promesse ci sono adesso (0 o 1): il contratto della Lavagna.
func quante() -> int:
	return 0 if _attiva.is_empty() else 1


## Le righe per la Lavagna: [[gessetto_corto, riga_del_pannello]].
func per_lavagna() -> Array:
	if _attiva.is_empty():
		return []
	var fen := str(_attiva["fen"])
	var corto: String = str((FEN[fen] as Dictionary)["corto"])
	# il gessetto è solo un nome e un fenomeno: la formattazione non si
	# traduce, le due parole sì
	return [["%s · %s" % [_nome_breve(), L10n.t(corto)],
			L10n.tf("%s ti aspetta: %s", [str(_attiva["chi"]), L10n.t(corto)])]]


func _nome_breve() -> String:
	# sul gessetto ci sta poco: il nome nudo, non la label intera
	return str(_attiva.get("nome", "?"))


# ---------------------------------------------------------- il ciclo

func _process(delta: float) -> void:
	if _dn == null:
		return
	var ora := float(_dn.get("time"))
	# la sera in cui ci si dà appuntamento: si attraversa una volta sola
	if _t_prec >= 0.0 and _t_prec < ORA_SERA and ora >= ORA_SERA:
		_sera_tick()
	_t_prec = ora
	if not _attiva.is_empty():
		_tick_appuntamento(delta, ora)


## La sera: ogni tanto qualcuno ti dà appuntamento.
func _sera_tick() -> void:
	if not _attiva.is_empty() or _visitors == null or _dn == null:
		return
	var oggi := int(_dn.get("day"))
	if oggi - _ultima < RIPOSO_GIORNI:
		return
	if randf() > PROB_SERA:
		return
	var candidati := _candidati()
	if candidati.is_empty():
		return
	var p := scegli(oggi, candidati)
	if p.is_empty():
		return
	var chiave := "%s|%d" % [p["chi"], p["giorno"]]
	if _storico.has(chiave):
		return
	_storico[chiave] = true
	_attiva = p
	_ultima = oggi
	_consegna_bigliettino()
	# il gessetto sulla lavagna: l'altro posto fisico dove vive
	get_tree().call_group("calendario", "aggiorna_lavagna")
	if _build and _build.has_method("request_save"):
		_build.call("request_save")


## Chi può dare appuntamento: un po' d'amicizia, sveglio, e non in
## rotta col villaggio (chi ha già smesso di parlarti non ti invita).
func _candidati() -> Array:
	var out: Array = []
	for r in (_visitors.get("_residents") as Array):
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		if int(r.get("friend", 0)) < AMICIZIA_MINIMA:
			continue
		var indole := ""
		if _visitors.has_method("_ensure_brain"):
			var brain = _visitors.call("_ensure_brain", r)
			if brain and brain.has_method("has_indole"):
				for i in ["mattiniero", "sognatore"]:
					if brain.call("has_indole", i):
						indole = i
						break
		out.append({"label": str(r.get("label", "")),
				"nome": str((r.get("dna", {}) as Dictionary).get("name", "")),
				"indole": indole})
	return out


## Il giorno dell'appuntamento: il vicino ci va e ci resta, e se arrivi
## succede la scena. Al calare della sua ora, si chiude in un modo o
## nell'altro — nessuna promessa sopravvive alla sua notte.
func _tick_appuntamento(delta: float, ora: float) -> void:
	var oggi := int(_dn.get("day"))
	var giorno := int(_attiva["giorno"])
	if oggi > giorno:
		# ci si è addormentati sopra, o si è ricaricato dopo: la scena
		# è passata. Si chiude com'era giusto, mai in silenzio.
		_chiudi("mancata" if not bool(_attiva["arrivato"]) else "onorata")
		return
	if oggi < giorno:
		return
	var fen := str(_attiva["fen"])
	var f := finestra(fen)
	if ora < f.x:
		return
	if ora > fine_attesa(fen):
		_chiudi(_esito_finale())
		return

	# si annota se il fenomeno È accaduto davvero: serve a distinguere
	# «ti sei perso una scena» da «non c'era nessuna scena» — e non si
	# scrive mai una lettera di rimpianto per qualcosa che non è successo
	if not bool(_attiva.get("visto", false)) and in_corso(fen):
		_attiva["visto"] = true
	# il vicino è al suo posto (la routine evapora: si rinnova piano)
	_t_manda -= delta
	if _t_manda <= 0.0:
		_t_manda = 8.0
		_manda_il_vicino()
	if not bool(_attiva["arrivato"]):
		_prova_incontro()


func _manda_il_vicino() -> void:
	if _visitors == null:
		return
	var punto := luogo_di(str(_attiva["fen"]))
	for r in (_visitors.get("_residents") as Array):
		if str(r.get("label", "")) != str(_attiva["chi"]):
			continue
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			return
		# se sta ancora dormendo lo si sveglia: ha un appuntamento
		if node.has_method("is_hidden") and bool(node.call("is_hidden")):
			node.call("resident_wake")
		# la routine ordinaria non deve richiamarlo altrove finche' aspetta
		r["next_act"] = 9999.0
		if node.has_method("do_routine"):
			# "attesa": ci va e ci RESTA in piedi, rivolto al fenomeno
			node.call("do_routine", "attesa", punto, _verso_il_fenomeno())
		return


func _verso_il_fenomeno() -> Vector3:
	match str(_attiva["fen"]):
		"bruma", "levata":
			return COZY.POND_CENTER
		"neve":
			return ALBERO.POS + Vector3(0, 3.0, 0)
	return COZY.POND_CENTER


## L'incontro avviene per PROSSIMITÀ: basta esserci. Niente «E — parla»:
## la differenza fra un appuntamento e una missione è proprio questa.
func _prova_incontro() -> void:
	if _player == null or not is_instance_valid(_player) or _visitors == null:
		return
	var punto := luogo_di(str(_attiva["fen"]))
	for r in (_visitors.get("_residents") as Array):
		if str(r.get("label", "")) != str(_attiva["chi"]):
			continue
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			return
		if node.global_position.distance_to(punto) > VICINO_R:
			return
		if _player.global_position.distance_to(node.global_position) > INCONTRO_R:
			return
		_attiva["arrivato"] = true
		_scena(node)
		return


## LA SCENA. Il vicino si illumina, ti saluta, dice la sua in Chibiese e
## poi torna a guardare il fenomeno — perché è per quello che siete lì.
func _scena(node: Node3D) -> void:
	var fen := str(_attiva["fen"])
	var c_e := in_corso(fen)
	# la scena ha la precedenza sul chiacchiericcio: per dieci secondi il
	# vicino non saluta e non chiede la panchina — è qui per l'appuntamento
	if node.has_method("apri_scena"):
		node.call("apri_scena", 10.0)
	if node.has_method("face_towards"):
		node.call("face_towards", _player.global_position)
	node.set_meta("postura", "si_illumina")
	if node.has_method("speak"):
		if c_e:
			node.call("speak", (FEN[fen] as Dictionary)["parole"], "felice")
		else:
			# il fenomeno non è venuto, ma lui sì — e tu pure
			node.call("speak", ["nebbia", "no", "insieme"], "felice")
	if node.has_method("chat_bubble"):
		node.call("chat_bubble", "♥")
	if node.has_method("celebrate"):
		node.call("celebrate")
	# …e dopo un attimo torna a guardare la cosa per cui vi siete dati
	# appuntamento: è quello lo spettacolo, non lui
	get_tree().create_timer(2.2).timeout.connect(func() -> void:
		if is_instance_valid(node) and node.has_method("face_towards"):
			node.call("face_towards", _verso_il_fenomeno()))
	# il Filo Rosso: un momento che vale, e vale di più se il fenomeno
	# c'è stato davvero
	get_tree().call_group("legami", "momento", str(_attiva["nome"]),
			"promessa", str((FEN[fen] as Dictionary)["corto"]))
	get_tree().call_group("regista", "note", "socievole")


func _esito_finale() -> String:
	if bool(_attiva["arrivato"]):
		return "onorata"
	# se il fenomeno non è mai venuto non c'è nessuna scena da rimpiangere
	return "mancata" if bool(_attiva.get("visto", false)) else "sfumata"


## Si chiude. Il gessetto sparisce dalla lavagna e — se ti sei perso la
## scena — la mattina dopo arriva la lettera che te la racconta. Mai un
## rimprovero, mai un regalino di consolazione: non c'è niente da
## risarcire, c'è solo una cosa bella da raccontare.
func _chiudi(esito: String) -> void:
	var fen := str(_attiva["fen"])
	var chi := str(_attiva["chi"])
	if esito == "mancata" and _mail and _mail.has_method("queue_letter"):
		_mail.call("queue_letter", {"from_key": chi, "text_key": lettera_persa(fen),
				"gift": false})
	# e il vicino torna alla sua vita: l'attesa non dura oltre la sua sera
	if _visitors != null:
		for r in (_visitors.get("_residents") as Array):
			if str(r.get("label", "")) == chi:
				r["next_act"] = randf_range(0.4, 1.8)
				var node := r.get("node") as Node3D
				if node and is_instance_valid(node) and node.has_method("do_routine"):
					node.call("do_routine", "wander", Vector3.ZERO)
				break
	_attiva = {}
	get_tree().call_group("calendario", "aggiorna_lavagna")
	if _build and _build.has_method("request_save"):
		_build.call("request_save")


func _consegna_bigliettino() -> void:
	if _mail == null or not _mail.has_method("queue_letter"):
		return
	_mail.call("queue_letter", {"from_key": str(_attiva["chi"]),
			"text_key": bigliettino(str(_attiva["fen"])), "gift": false})


# ------------------------------------------------------------- i testi

## Il bigliettino nella cassetta: dice QUANDO senza dire un'ora.
##
## Torna una frase RIMANDATA (`{"k": …}`, vedi L10n.rendi), non parole: fra
## lo scriverlo e il leggerlo passa una notte e un salvataggio su disco, e
## in mezzo il giocatore può aver cambiato lingua. Chi lo vuole subito in
## parole lo passa a `L10n.rendi()`.
static func bigliettino(fen: String) -> Dictionary:
	match fen:
		"bruma":
			return {"k": "Domattina, quando si alza la bruma,\nallo stagno. Dura il tempo di un tè:\npoi il sole se la beve tutta.\nIo ci sono comunque, nell'acqua bianca."}
		"levata":
			return {"k": "Domani, quando il sole tocca l'acqua,\nallo stagno: i pesci salgono a respirare.\nSi sentono prima di vederli. Vieni piano."}
		"neve":
			return {"k": "L'autunno finisce e l'aria sa di ferro.\nIl primo fiocco cade prima che uno se l'aspetti:\nquel giorno, appena comincia, vieni al Grande Albero.\nVoglio vederlo insieme a qualcuno."}
	return {}


## La lettera del giorno dopo: ti racconta la scena che ti sei perso.
## Non ti rimprovera mai — ti fa vedere cosa c'era. Rimandata come il
## bigliettino, e per la stessa ragione.
static func lettera_persa(fen: String) -> Dictionary:
	match fen:
		"bruma":
			return {"k": "La bruma è venuta, alta fino alle orecchie.\nLo stagno non c'era più: c'era il fiato dell'acqua\ne i giunchi che spuntavano come dita.\nHo aspettato finché il sole non l'ha bevuta.\nIl posto accanto a me è rimasto libero e tiepido."}
		"levata":
			return {"k": "Ne sono saliti sette, forse otto.\nUno ha fatto un anello così largo\nche è arrivato fino alla mia zampa.\nPoi l'acqua si è richiusa e ha fatto buio."}
		"neve":
			return {"k": "È cominciata senza avvisare.\nAl Grande Albero c'ero solo io e i primi fiocchi,\nche a toccarli non erano freddi, erano lenti.\nQuest'inverno ne cadranno milioni.\nQuesto era il primo, e adesso lo so io soltanto."}
	return {}


# --------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	return {"promesse": {"attiva": _attiva, "storico": _storico,
			"ultima": _ultima}}


func load_extra(data: Dictionary) -> void:
	var d: Variant = data.get("promesse")
	if d is not Dictionary:
		return
	var a: Variant = d.get("attiva")
	if a is Dictionary:
		_attiva = a
	var st: Variant = d.get("storico")
	if st is Dictionary:
		_storico = st
	_ultima = int(d.get("ultima", -99))
	# un appuntamento nel passato non resta appeso: si chiude com'era
	# giusto (e la lettera parte), mai in silenzio
	(func() -> void:
		if _attiva.is_empty() or _dn == null:
			return
		if int(_dn.get("day")) > int(_attiva.get("giorno", 0)):
			_chiudi("mancata")
	).call_deferred()
