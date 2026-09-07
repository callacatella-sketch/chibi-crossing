extends Node

## ACCOMPAGNARE — il verbo che disinnesca una paura appresa.
##
## Il Limbico sa già fare la cosa più difficile: un residente mandato
## novanta giorni alla catasta si prende un MARCHIO su quel posto, e da
## allora ci gira al largo (`Limbico.evita`). E sa già dire il perché
## (`perche_evita`), e sa già guarire (`visita_serena`): tornarci senza
## che accada nulla spegne la paura. Era tutto scritto, testato — e senza
## un verbo, quindi invisibile.
##
## La trappola della paura appresa è che si autoalimenta: chi evita un
## posto non ci torna mai, e non tornandoci non scopre mai che adesso non
## succede niente. Da solo, quel marchio non si spegne più. Serve
## qualcuno che ci vada insieme.
##
## COME SI GIOCA:
##  1. ti avvicini a un vicino che gira al largo da qualche parte. Il
##     prompt te lo dice, e lui — se glielo chiedi — ti dice anche PERCHÉ;
##  2. E, e ci andate insieme. Lui cammina, ma sulla soglia si ferma:
##     postura «esita», una nuvoletta con tre punti. Aspetta te;
##  3. gli resti accanto. E NON SUCCEDE NIENTE. È tutto qui, e non è poco:
##     l'estinzione è esattamente questo — il tempo passato in un posto
##     temuto senza che il male torni;
##  4. il marchio si dimezza. Bastano poche volte perché quel posto torni
##     un posto qualunque, e il giorno in cui non lo evita più si annoda
##     un momento sul Filo Rosso.
##
## Non c'è nessuna barra e nessun timer a schermo: l'unico segnale è il
## corpo di chi hai accanto. Se ti allontani, la scena si scioglie in
## silenzio — nessun fallimento, nessun rimprovero.

const LEGAMI_TIPO := "coraggio"

## Quanto si resta insieme nel posto perché conti come visita serena.
## Abbastanza da sentire il vuoto, non tanto da annoiarsi.
const SECONDI_INSIEME := 4.5

## Oltre questa distanza dal vicino la scena si scioglie: accompagnare
## vuol dire stare accanto, non mandarlo avanti.
const DISTANZA_MASSIMA := 5.0

## Quanto vicino al posto deve arrivare perché valga come «ci siamo».
const RAGGIO_LUOGO := 3.0

## Il vicino va rimandato ogni tanto: `Visitors.manda` lo trattiene solo
## 45 secondi, poi la sua agenda si riprende lo stato e la scena si
## scioglierebbe da sola mentre il giocatore è ancora lì.
const RINNOVO := 9.0

## Sotto questa profondità del marchio si entra SEMPRE. È il pavimento del
## canale, e non è una taratura prudente: `Limbico.SOGLIA_EVITAMENTO` è la
## soglia sotto cui un posto non viene nemmeno evitato, quindi una paura che
## sta lì sotto non ha niente da vincere. Sopra, il no diventa possibile.
const PAURA_CHE_FERMA := 0.55

## Quanto il corpo in allarme ADESSO pesa sulla decisione. Piccolo apposta: è
## un modificatore del momento, non una seconda paura — e la sua chiave è
## stare fermi e richiedere, che si legge nell'istante in cui succede.
const PESO_ALLARME := 0.25

## Quanto la fiducia in chi ti ci ha portato aiuta a entrare. ⚠️ Il tetto è
## `PESO_ALLARME`: la fiducia non può MAI valere più di come stai adesso —
## altrimenti diventerebbe una valuta che compra il coraggio, e il giocatore
## imparerebbe a coltivare i vicini invece che a volergli bene.
const PESO_FIDUCIA := 0.25

var _visitors: Node
var _build: Node3D
var _cozy: Node3D
var _player: Node3D
var _legami: Node

# la scena in corso: {label, luogo, fase, t, rinnovo}
var _scena := {}
var _prompt: PanelContainer
var _prompt_label: Label
var _detto_perche := {}     # label|luogo -> true (il perché si dice una volta)


func _ready() -> void:
	add_to_group("accompagna")
	_visitors = get_tree().get_first_node_in_group("visitors")
	_legami = get_tree().get_first_node_in_group("legami")
	_build = get_tree().get_first_node_in_group("build_system")
	_costruisci_prompt()
	(func():
		_player = get_node_or_null("../../Player") as Node3D
		_cozy = get_parent() as Node3D
	).call_deferred()


# ============================================================ le regole pure

## Fra i posti che teme, quello da cui si comincia: il primo che il mondo
## sappia mostrare. PURA: entra la lista dei temuti e quella dei posti che
## hanno una posizione vera, esce il nome del posto (o "").
static func luogo_da_affrontare(temuti: Array, localizzabili: Array) -> String:
	for l in temuti:
		if str(l) in localizzabili:
			return str(l)
	return ""


## Si può contare la visita come serena? Serve che il vicino sia ARRIVATO,
## che il giocatore gli sia ACCANTO, e che sia passato abbastanza tempo
## senza che succeda niente. PURA, e per questo provabile senza aspettare.
static func visita_compiuta(dist_luogo: float, dist_giocatore: float,
		secondi: float) -> bool:
	return dist_luogo <= RAGGIO_LUOGO and dist_giocatore <= DISTANZA_MASSIMA \
			and secondi >= SECONDI_INSIEME


## La scena si scioglie? Solo se il giocatore si è allontanato. Non è un
## fallimento: è che accompagnare qualcuno vuol dire restare.
## ⚠️ **CE LA FA A ENTRARE? — il canale che mancava a tutto il gioco.**
##
## Fino a ieri, alla soglia si entrava SEMPRE: bastava restargli accanto un
## secondo e mezzo. Cioè il giocatore non chiedeva — **ordinava**, e nel
## villaggio non esisteva un solo momento in cui un vicino potesse dire di no.
## (Lo stesso vale per la Lavagna, ma quella è una meccanica del gioco e non
## può costare: il no doveva nascere dove chiedere è già facoltativo.)
##
## ⚠️ **È UNA LETTURA, MAI UNA TRANSAZIONE.** Non chiama `trattieni()`, non
## scala la regolazione, non alza il cortisolo, non scrive niente: chiedere
## non deve poter lasciare il vicino peggio di come stava. Sono tre numeri che
## il gioco calcola già, guardati e basta.
##
## [param carica] quanto è ancora profonda quella paura — `absf(carica_di)`.
##   È anche il contatore delle visite riuscite, gratis: `visita_serena`
##   moltiplica per 0.62, quindi al secondo giro il numero è già più basso e
##   non serve nessun campo nuovo.
## [param allarme] com'è il suo corpo ADESSO (`arousal`). È la premessa che il
##   giocatore ha appena visto — le orecchie indietro, il sussulto di quando
##   gli sei corso incontro — e la chiave che la ripara è immediata e cozy:
##   **stare fermi un momento e richiedere**, la stessa grammatica di
##   `FiatoSospeso.calma()`.
## [param fiducia] `Animo.fiducia(giocatore, "accompagnato")`.
##
## ⚠️ **E LA FIDUCIA ESCLUDE «accompagnato», o si conta due volte lo stesso
## gesto.** Un accompagnamento riuscito rende la volta dopo più facile **già
## adesso**, e per una strada che il giocatore vede: il marchio scende a 0.62
## e lui esita meno. Ma `_guarisci` scrive anche `gesto_gentile(label,
## "accompagnato", 0.5)`, cioè una riga positiva che `fiducia()` conterebbe —
## e sarebbe la stessa carezza pesata due volte dentro una sola decisione. Il
## `tranne` non è una lista bianca: è non guardare due volte la riga che il
## chiamante ha già in mano. Quello che resta — i piatti, i regali, le feste —
## è un canale DIVERSO, e quello sì che deve contare.
##
## IL PAVIMENTO È STRUTTURALE: sotto `PAURA_CHE_FERMA` si entra sempre, cioè
## per la stragrande maggioranza dei vicini il gioco è **bit per bit quello di
## ieri**.
static func ce_la_fa(carica: float, allarme: float, fiducia := 0.0) -> bool:
	var c := absf(carica) if is_finite(carica) else 0.0
	if c < PAURA_CHE_FERMA:
		return true
	var a := clampf(allarme, 0.0, 1.0) if is_finite(allarme) else 0.0
	var f := clampf(fiducia, 0.0, 1.0) if is_finite(fiducia) else 0.0
	# la paura di quel posto, più quanto il corpo è in allarme adesso, meno
	# quanto si fida di chi ce l'ha portato. Nessuna soglia nascosta: il
	# confronto è con la paura che ferma.
	return c + a * PESO_ALLARME - f * PESO_FIDUCIA < PAURA_CHE_FERMA


static func scena_persa(dist_giocatore: float) -> bool:
	return dist_giocatore > DISTANZA_MASSIMA * 1.6


# ============================================================ i posti veri

## Dove sta, nel mondo, un posto che il Limbico conosce solo per nome.
## {} se non si sa: e allora Accompagnare non lo propone — meglio non
## offrire un verbo che non si può mantenere.
func posizione_del_luogo(luogo: String) -> Dictionary:
	match luogo:
		"orto":
			return _primo_pezzo(["Orto", "Aiuola"])
		"cucina":
			return _primo_pezzo(["Camino"])
		"catasta":
			# la catasta non è un pezzo: è dove si taglia la legna, cioè
			# dove stanno gli alberi. Chi si è spaventato spaccando legna
			# si è spaventato lì.
			var vicino: Node3D = null
			var best := INF
			var rif: Vector3 = _player.global_position if _player else Vector3.ZERO
			for a in get_tree().get_nodes_in_group("albero"):
				var n3 := a as Node3D
				if n3 == null or not is_instance_valid(n3):
					continue
				var d: float = rif.distance_to(n3.global_position)
				if d < best:
					best = d
					vicino = n3
			if vicino != null:
				return {"pos": vicino.global_position}
		"bosco":
			if _cozy != null and "CLEARING_CENTER" in _cozy:
				return {"pos": _cozy.get("CLEARING_CENTER")}
			return {"pos": Vector3(-1.0, 0.0, -46.0)}
	return {}


func _primo_pezzo(nomi: Array) -> Dictionary:
	if _build == null:
		return {}
	var rif: Vector3 = _player.global_position if _player else Vector3.ZERO
	var best := INF
	var out := {}
	for nome in nomi:
		for p in _build.call("get_placed_by_name", str(nome)):
			var n3 := p as Node3D
			if n3 == null or not is_instance_valid(n3):
				continue
			var d: float = rif.distance_to(n3.global_position)
			if d < best:
				best = d
				out = {"pos": n3.global_position}
	return out


func _localizzabili() -> Array:
	var out: Array = []
	for l in ["catasta", "orto", "cucina", "bosco"]:
		if not posizione_del_luogo(l).is_empty():
			out.append(l)
	return out


# ============================================================ il prompt

## Il vicino più vicino che gira al largo da qualche posto: [label, luogo].
func _candidato() -> Array:
	if _visitors == null or _player == null:
		return []
	var pp: Vector3 = _player.global_position
	var loc := _localizzabili()
	var best := 2.6
	var out: Array = []
	for r in (_visitors.get("_residents") as Array):
		var label := str(r.get("label", ""))
		if label == "":
			continue
		var nodo := r.get("node") as Node3D
		if nodo == null or not is_instance_valid(nodo):
			continue
		var d: float = pp.distance_to(nodo.global_position)
		if d > best:
			continue
		var temuti: Array = _visitors.call("luoghi_evitati", label)
		var luogo := luogo_da_affrontare(temuti, loc)
		if luogo == "":
			continue
		if not _vale_la_pena(label, luogo):
			continue
		best = d
		out = [label, luogo]
	return out


## ⚠️ **NON SI OFFRE UN VERBO CHE NON SI PUÒ MANTENERE — e la regola non è
## nuova: è quella scritta sopra `posizione_del_luogo`, applicata alla paura
## invece che alla mappa.**
##
## `evita` apre il prompt a 0,45 di marchio, ma sulla soglia si entra solo se
## `ce_la_fa`. In mezzo c'era una fascia in cui il gioco offriva
## l'Accompagnare, il giocatore attraversava il villaggio, e il no era
## **certo** — nessun gesto, nessuna fiducia, nessuna calma poteva cambiarlo.
## Un verbo offerto e mai concesso non è profondità: insegna a non usarlo.
##
## MISURATO (`Limbico.rivaluta` con spaventi pieni): il marchio sale a 0,882
## al terzo spavento, poi l'abitudine lo riporta a **0,7196** a regime; il
## tetto con la fiducia vera di questo progetto (0,623 di media) è **0,706**.
## La fascia esiste, ed è proprio dove stanno le paure appena fatte.
##
## LA DOMANDA È SUL CASO MIGLIORE — corpo calmo, la fiducia di oggi — non su
## adesso: **l'offerta dev'essere onesta, l'esito resta vivo.** Se al suo più
## calmo ce la farebbe, il prompt c'è; e poi sulla soglia decide come sta
## davvero. Così un no vuol dire «non come stiamo oggi», che è una cosa a cui
## il giocatore può rimediare — invece di «mai», che è una porta murata.
##
## E la paura troppo profonda non resta senza cura: l'estinzione la consuma di
## 0,12 al giorno, e `Visitors._filtra_luogo` la DIMEZZA ogni volta che il
## vicino ci si avvicina da solo con Mochi a due passi. Il verbo torna a
## offrirsi da sé, quando è di nuovo una cosa che si può fare insieme.
func _vale_la_pena(label: String, luogo: String) -> bool:
	if _visitors == null:
		return true
	var animo: RefCounted = _visitors.call("animo_oggetto_di", label)
	if animo == null or animo.limbico == null:
		# il degrado va verso il gioco di ieri: nel dubbio si offre
		return true
	return ce_la_fa(float(animo.limbico.carica_di(luogo)), 0.0,
			float(animo.fiducia("giocatore", "accompagnato")))


func _process(delta: float) -> void:
	if not _scena.is_empty():
		_avanza(delta)
		_aggiorna_prompt(_scena_prompt())
		return
	var c := _candidato()
	if c.is_empty():
		_aggiorna_prompt("")
		return
	_aggiorna_prompt(L10n.tf("E — accompagna %s (%s)",
			[str(c[0]), L10n.t(str(c[1]))]))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not _scena.is_empty():
		return
	var c := _candidato()
	if c.is_empty():
		return
	get_viewport().set_input_as_handled()
	_comincia(str(c[0]), str(c[1]))


# ============================================================ la scena

func _comincia(label: String, luogo: String) -> void:
	var p := posizione_del_luogo(luogo)
	if p.is_empty():
		return
	_scena = {"label": label, "luogo": luogo, "pos": p["pos"],
			"fase": "cammino", "t": 0.0, "rinnovo": 0.0}
	# IL PERCHÉ, la prima volta: senza questa frase il giocatore vede un
	# vicino che fa un giro strano e pensa a un difetto di percorso
	var chiave := "%s|%s" % [label, luogo]
	if not _detto_perche.has(chiave):
		_detto_perche[chiave] = true
		var animo: RefCounted = _visitors.call("animo_oggetto_di", label)
		if animo != null:
			# il TEMPLATE e il numero separati: la frase si riempie DOPO
			# essere stata tradotta, o in inglese non si troverebbe mai
			var d: Dictionary = animo.limbico.perche_evita_dati(luogo)
			if not d.is_empty():
				_toast("%s: %s." % [label,
						L10n.tf(str(d["testo"]), [int(d["n"])])])
	_manda()
	var nodo := _nodo()
	if nodo != null and nodo.has_method("chat_bubble"):
		nodo.call("chat_bubble", "?")


func _avanza(delta: float) -> void:
	var nodo := _nodo()
	if nodo == null or _player == null:
		_scena = {}
		return
	var dg: float = _player.global_position.distance_to(nodo.global_position)
	if scena_persa(dg):
		# si scioglie in silenzio: nessun rimprovero, nessun fallimento
		if nodo.has_method("chat_bubble"):
			nodo.call("chat_bubble", "…")
		_scena = {}
		return
	var meta: Vector3 = _scena["pos"]
	var dl: float = nodo.global_position.distance_to(meta)
	_scena["rinnovo"] = float(_scena["rinnovo"]) - delta
	# ⚠️ **MAI RIMANDARLO SE HA DETTO DI NO.** Questo blocco gira PRIMA del
	# `match`, quindi nel fotogramma in cui la fase è già «no» ma la scena non
	# è ancora chiusa un rinnovo scaduto rispedirebbe il corpo alla catasta
	# con un lease di 45 secondi — riaprendo da sola la cura qui sopra.
	if str(_scena["fase"]) != "no" and float(_scena["rinnovo"]) <= 0.0:
		_manda()

	match str(_scena["fase"]):
		"cammino":
			if dl <= RAGGIO_LUOGO + 1.2:
				# LA SOGLIA: qui si ferma. È il momento in cui il giocatore
				# deve resistere alla tentazione di tirarlo dentro.
				_scena["fase"] = "soglia"
				_scena["t"] = 0.0
				nodo.set_meta("postura", "esita")
				if nodo.has_method("chat_bubble"):
					nodo.call("chat_bubble", "…")
		"soglia":
			_scena["t"] = float(_scena["t"]) + delta
			# se gli sei accanto, dopo un attimo di esitazione DECIDE
			if dg <= DISTANZA_MASSIMA and float(_scena["t"]) > 1.6:
				if _ce_la_fa_ora():
					_scena["fase"] = "insieme"
					_scena["t"] = 0.0
					_manda()
				else:
					_non_oggi()
		"no":
			# il corpo se ne sta andando: la scena è finita, e non c'è niente
			# da aspettare. La si chiude qui invece che con un timer, o al
			# frame dopo il cartellino tornerebbe identico.
			_scena = {}
		"insieme":
			_scena["t"] = float(_scena["t"]) + delta
			if visita_compiuta(dl, dg, float(_scena["t"])):
				_guarisci()


## ⚠️ **IL «NON OGGI» — e il soggetto è il POSTO, mai il giocatore.**
##
## Lui ha detto di sì, ha camminato con te attraverso mezzo villaggio, è
## arrivato fin lì. Poi la paura ha vinto **sulla soglia**: si scosta, fa un
## largo attorno al posto e se ne va. Nessuna parola, nessun toast, nessuna
## faccia verso di te — chi guarda vede un corpo che gira al largo da una
## catasta, che è esattamente quello che è successo.
##
## ⚠️ **E NON SI SCRIVE NIENTE.** Nessuna riga nel libro mastro, nessun
## marchio nuovo, nessun rancore: un no non è un torto. Il giocatore non ha
## niente da riparare, perché non ha rotto niente — e la chiave per la volta
## dopo è quella che ha appena visto addosso al corpo.
func _non_oggi() -> void:
	var nodo := _nodo()
	_scena["fase"] = "no"
	if nodo == null or not is_instance_valid(nodo):
		_scena = {}
		return
	# ⚠️ **IL LEASE VA ROTTO, o il corpo resta piantato sulla soglia.**
	# `manda()` scrive `next_act = 45 s`: senza restituirgli la sua giornata,
	# il gesto non parte e quello che si vede non è un rifiuto — è un fermo
	# immagine. È la stessa cosa che fa `Visitors._filtra_luogo` quando un
	# posto è murato: si torna alla routine.
	if _visitors != null and _visitors.has_method("libera"):
		_visitors.call("libera", str(_scena["label"]))
	# ⚠️ **MA IL LEASE È META' DEL LUCCHETTO: il CAMMINO va dirottato.**
	# `manda()` aveva fatto `do_task("wonder", pos)`, cioè `_walk_to` verso
	# il posto con `tk_wonder` in coda. `libera()` scrive solo `next_act` sulla
	# riga del residente: non tocca `_target`, non cambia stato. MISURATO nel
	# MainLevel vero (`tools/prova_non_oggi.gd`): al verdetto mancano ancora
	# ~1,9 m, e il corpo li **camminava** — entrava nella catasta che aveva
	# appena rifiutato, con l'«!» di `tk_wonder` sopra la testa e il
	# **cuoricino** di `_spawn_heart` all'uscita. Il rifiuto reso identico a
	# un successo, meno il toast e più un cuore.
	#
	# E l'agenda non poteva salvarlo: si riprende il corpo solo dagli stati di
	# `Visitors.STATI_A_RIPOSO`, dove né «walk» né «tk_wonder» stanno.
	# «wander» è il ripiego universale del gioco (due passi intorno a casa) e
	# finisce in `r_idle`, che a riposo ci sta.
	if nodo.has_method("do_routine"):
		nodo.call("do_routine", "wander", nodo.global_position)
	# il Largo: il corpo si scosta dal posto e se ne va. È il gesto
	# dell'evitamento, e lo chiede all'usciere come tutti gli altri — se il
	# palco è occupato non parte, e va bene: il corpo se ne va lo stesso.
	# ⚠️ E IL LARGO SI CHIEDE **DOPO** il dirottamento, con il POSTO. Due
	# ragioni, tutte e due misurate: `_enter_state` chiama `gesto_spegni()`,
	# quindi un Largo chiesto prima morirebbe nel fotogramma in cui nasce; e
	# senza `posto` il corpo non sa da che parte scostarsi (`via` resta il
	# default +1, cioè sempre a destra — metà delle volte VERSO la catasta).
	# Da che parte girare al largo è una domanda nel frame del corpo, e la sa
	# solo lui.
	if nodo.has_method("frase"):
		nodo.call("frase", "evitamento", {"posto": _scena["pos"]})
	# ⚠️ **E NON SI POSA NIENTE ADDOSSO AL CORPO.** Qui c'era un
	# `set_meta("postura", "spalle_basse")`, e MISURATO nel MainLevel vero
	# (`tools/prova_non_oggi.gd`) era ancora addosso **sei secondi dopo, e
	# nella scena successiva**: `spalle_basse` sta in `Visitor.RECITA`, cioè
	# è una posa STABILE, e una posa stabile resta finché qualcuno non toglie
	# il meta. Qui non c'è nessuno che lo tolga — la scena si chiude nel
	# frame dopo. Sarebbe un vicino curvo per il resto della partita, che è
	# esattamente il guasto che il commento di `Visitor._recita_applica`
	# racconta come già pagato una volta.
	#
	# E sarebbe anche una bugia: «un no non scrive niente» non vale solo per
	# il libro mastro, vale per il CORPO. Il rifiuto ha già la sua parola, ed
	# è il Largo qui sopra — un gesto, che ha una fine sua. In questo
	# vocabolario `spalle_basse` è la mestizia che DURA (la ferita degli
	# Affetti, chi è rimasto fuori tutta la notte): darla a un momento di due
	# secondi sovraccarica una parola che pesa di più.


func _guarisci() -> void:
	var label := str(_scena["label"])
	var luogo := str(_scena["luogo"])
	var nodo := _nodo()
	_scena = {}
	var animo: RefCounted = _visitors.call("animo_oggetto_di", label)
	if animo == null:
		return
	var prima: float = float(animo.limbico.carica_di(luogo))
	animo.limbico.visita_serena(luogo)
	var ancora: bool = bool(animo.limbico.evita(luogo))
	if nodo != null and is_instance_valid(nodo):
		nodo.set_meta("postura", "si_illumina")
		if nodo.has_method("speak"):
			nodo.call("speak", ["coraggio", "insieme"], "felice")
		if nodo.has_method("celebrate"):
			nodo.call("celebrate")
	if ancora:
		# non è finita: la paura si è dimezzata, non spenta
		_toast(L10n.tf("Siete stati lì, e non è successo niente. %s respira.",
				[label]))
	else:
		_toast(L10n.tf("%s non gira più al largo. Ci siete tornati insieme, e tanto è bastato.",
				[label]))
		# il giorno in cui una paura si spegne resta sul filo per sempre
		var nome := str(_visitors.call("nome_di_label", label)) if \
				_visitors.has_method("nome_di_label") else ""
		if nome == "":
			nome = _nome_da_label(label)
		if nome != "" and _legami != null:
			_legami.call("momento", nome, LEGAMI_TIPO, luogo)
	var sfx := get_node_or_null(^"/root/Sfx")
	if sfx:
		sfx.call("place_ok")
	# quel gesto vale come gentilezza: scioglie un po' di rancore
	_visitors.call("gesto_gentile", label, "accompagnato", 0.5)
	get_tree().call_group("regista", "note", "socievole")


# ============================================================ utilità

func _nodo() -> Node3D:
	if _scena.is_empty() or _visitors == null:
		return null
	return _visitors.call("node_di", str(_scena["label"])) as Node3D


func _manda() -> void:
	if _scena.is_empty() or _visitors == null:
		return
	_scena["rinnovo"] = RINNOVO
	_visitors.call("manda", str(_scena["label"]), _scena["pos"])


## I tre numeri di adesso, letti dove vivono. Nessuno viene scritto.
func _ce_la_fa_ora() -> bool:
	if _visitors == null or _scena.is_empty():
		return true
	var animo: RefCounted = _visitors.call("animo_oggetto_di",
			str(_scena["label"]))
	if animo == null or animo.limbico == null:
		# ⚠️ il degrado va verso il gioco di ieri: senza l'animo si entra,
		# come si è sempre fatto.
		return true
	var luogo := str(_scena["luogo"])
	return ce_la_fa(float(animo.limbico.carica_di(luogo)),
			float(animo.limbico.arousal),
			float(animo.fiducia("giocatore", "accompagnato")))


## Il nome dal dna, passando dalla label: le due anagrafi del progetto.
func _nome_da_label(label: String) -> String:
	if _visitors == null:
		return ""
	var dna: Dictionary = _visitors.call("dna_di", label)
	return str(dna.get("name", ""))


func _scena_prompt() -> String:
	match str(_scena.get("fase", "")):
		"cammino":
			return L10n.tf("state andando %s…", [L10n.t(str(_scena["luogo"]))])
		"soglia":
			return L10n.t("si è fermato. Restagli accanto.")
		"insieme":
			return L10n.t("non succede niente. È esattamente il punto.")
	return ""


func _toast(testo: String) -> void:
	if _visitors and _visitors.has_method("_show_toast"):
		_visitors.call("_show_toast", testo)


func _aggiorna_prompt(testo: String) -> void:
	if _prompt == null:
		return
	var nodo: Node3D = null
	if not _scena.is_empty():
		nodo = _nodo()
	else:
		var c := _candidato()
		if not c.is_empty() and _visitors != null:
			nodo = _visitors.call("node_di", str(c[0])) as Node3D
	var cam := get_viewport().get_camera_3d()
	if testo == "" or nodo == null or not is_instance_valid(nodo) or cam == null:
		_prompt.visible = false
		return
	var wp: Vector3 = nodo.global_position + Vector3(0, 1.35, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = testo
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _costruisci_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	_prompt = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.95, 0.88, 0.92)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(0.62, 0.46, 0.34, 0.5)
	sb.set_border_width_all(2)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	_prompt.add_theme_stylebox_override("panel", sb)
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_prompt)
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 13)
	_prompt_label.add_theme_color_override("font_color", Color("6b4a33"))
	_prompt.add_child(_prompt_label)


# ============================================================ debug CLI

func debug_marchia(label: String, luogo := "catasta", quante := 3) -> void:
	var animo: RefCounted = _visitors.call("animo_oggetto_di", label)
	if animo == null:
		print("[accompagna] nessun animo per ", label)
		return
	for i in quante:
		animo.limbico.rivaluta("spavento", "qualcuno", -0.9, luogo)
	print("[accompagna] %s ora evita %s: %s (carica %.2f)"
			% [label, luogo, animo.limbico.evita(luogo),
			animo.limbico.carica_di(luogo)])
