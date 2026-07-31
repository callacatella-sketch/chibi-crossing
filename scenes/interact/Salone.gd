extends Node

## IL SALONE DELL'ESTETISTA — il mestiere, e la scena che si guarda.
##
## Le pietre di prima hanno messo il possibile e il posto: il genoma
## estetico (ChibiDNA.ESTETICI), il corpo che si rifà da solo
## (Visitor.rifai_il_look) e il mobile (BuildCatalog._salone). Qui il
## salone APRE: chi ha il sogno «estetista» ci va a lavorare, si mette al
## suo posto accanto alla poltrona, e un vicino alla volta viene a
## sedersi e se ne va diverso.
##
## LE REGOLE, e perché sono queste:
##   · CI VA CHI CI CREDE. Il registro dei lavori assegna «Tenere il
##     salone» a chiunque, ma chi lo SOGNA lavora meglio (Lavori.resa lo
##     premia già di suo) e soprattutto è lui che il Gufo aspettava.
##   · UN CLIENTE ALLA VOLTA. Non è una catena di montaggio: uno si
##     siede, si guarda allo specchio, e finché non ha finito nessun
##     altro entra. La coda è la scena.
##   · IL RITOCCO È GENTILE. Cambia poco per volta — una tinta più
##     calda, le sopracciglia, le guanciotte, il vestitino — e MAI
##     l'identità: `rifai_il_look` scarta da sé tutto ciò che non è
##     estetica, ma qui non gliela si passa nemmeno.
##   · NIENTE SI ROMPE SE IL SALONE NON C'È. Senza il mobile piazzato
##     l'estetista fa il suo giro come tutti gli altri: il mestiere non
##     pretende un edificio per esistere.

const DNA_GEN := preload("res://scenes/npc/ChibiDNA.gd")

## Il mestiere e il sogno, dai vocabolari dell'animo (mai stringhe sparse).
const COMPITO := "abbellisce"
const SOGNO := "estetista"

## L'ora in cui il salone apre e quella in cui chiude: un mestiere ha i
## suoi orari, e vederli è metà del piacere.
const APRE := 0.34
const CHIUDE := 0.72

## Quanto dura una seduta, e quanto si aspetta prima del cliente dopo.
const DURATA_SEDUTA := 14.0
const PAUSA_FRA_CLIENTI := 26.0

## Le TINTE del manto che il salone sa dare: pastelli caldi e freddi, mai
## colori che un chibi non potrebbe avere.
const TINTE := ["f2d8c8", "e8b4a0", "d9c3a8", "cfc4bd", "c8d4dc",
		"e0cfe0", "d8d0b8", "f0dcc4"]
## I vestitini, e le loro fodere più chiare.
const VESTITI := ["b7c6ff", "9ec9e8", "f4b8c8", "bfe6c8", "ffe6a8",
		"cdbff0", "f2c9a0"]
## Gli stili di sopracciglio: gli stessi che il DNA sa disegnare.
const SOPRACCIGLIA := ["morbide", "arcuate", "dritte", "decise", "sottili", "folte"]

var _visitors: Node
var _build: Node3D
var _daynight: Node
var _lavori: Node
var _legami: Node

var _aperto := false
var _estetista := ""          # label di chi ci lavora oggi ("" = nessuno)
var _cliente := ""            # label di chi è in poltrona
var _t_seduta := 0.0
var _t_pausa := 0.0
var _tick := 0.0
## chi è già passato oggi: nessuno due volte nello stesso giorno
var _serviti := {}
## l'ultimo che il salone ha cambiato: lo legge il registro per la resa
var _ultimo_servito := ""


func _ready() -> void:
	add_to_group("salone")
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
	_serviti.clear()
	_ultimo_servito = ""
	_cliente = ""


# ============================================================ la logica pura

## IL RITOCCO: quali geni estetici cambiare, e di quanto. PURO e
## deterministico dato `seme` — la stessa seduta dà lo stesso risultato,
## e si prova headless.
##
## Cambia POCO per volta (uno o due tratti), perché un vicino che entra
## e esce irriconoscibile non è un salone: è un altro personaggio. E non
## tocca mai due volte la stessa cosa nello stesso giorno.
static func ritocco(dna: Dictionary, seme: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	var carte: Array = ["tinta", "sopracciglia", "guance", "vestito", "lentiggini"]
	var scelta := str(carte[rng.randi() % carte.size()])
	var out := {}
	match scelta:
		"tinta":
			var t := str(TINTE[rng.randi() % TINTE.size()])
			var c := Color(t)
			out["fur"] = t
			out["fur2"] = c.darkened(0.22).to_html(false)
			out["belly"] = c.lightened(0.18).to_html(false)
		"sopracciglia":
			out["brow"] = str(SOPRACCIGLIA[rng.randi() % SOPRACCIGLIA.size()])
			out["brow_folto"] = rng.randf_range(0.82, 1.22)
			out["brow_arco"] = rng.randf_range(0.8, 1.25)
		"guance":
			out["blush"] = rng.randf_range(0.35, 0.9)
		"vestito":
			var v := str(VESTITI[rng.randi() % VESTITI.size()])
			out["dress"] = v
			out["dress2"] = Color(v).lightened(0.25).to_html(false)
		"lentiggini":
			out["freckles"] = not bool(dna.get("freckles", false))
	# la guardia in più: qui NON deve passare niente che non sia estetica
	for g in out.keys():
		if not str(g) in DNA_GEN.ESTETICI:
			out.erase(g)
	return out


## Il salone è aperto a quest'ora? PURA.
static func ora_di_apertura(ora: float) -> bool:
	return ora >= APRE and ora < CHIUDE


# ============================================================ la giornata

func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.5:
		return
	var passo := _tick
	_tick = 0.0
	if _visitors == null or _build == null or _daynight == null:
		return

	var mobile := _il_salone()
	var ora := float(_daynight.get("time"))
	var deve_aprire := mobile != null and ora_di_apertura(ora) \
			and _chi_ci_lavora() != ""
	if deve_aprire != _aperto:
		_aperto = deve_aprire
		if _aperto:
			_apri(mobile)
		else:
			_chiudi()
	if not _aperto:
		return
	_tick_seduta(passo, mobile)


## Il mobile piazzato (il primo, se ce n'è più d'uno): null se non c'è.
func _il_salone() -> Node3D:
	if _build == null:
		return null
	for n in _build.get_placed_by_name("Salone"):
		if is_instance_valid(n):
			return n as Node3D
	return null


## Chi tiene il salone oggi: chi ha l'incarico «abbellisce». Se nessuno
## ce l'ha, il salone resta chiuso — un negozio senza chi ci sta dentro
## non apre da solo.
func _chi_ci_lavora() -> String:
	if _lavori == null:
		return ""
	var incarichi: Dictionary = _lavori.get("_incarichi")
	for label in incarichi:
		if str(incarichi[label]) == COMPITO:
			return str(label)
	# nessun ordine: ci va chi lo SOGNA, di sua iniziativa (le giornate
	# libere del registro — Animo.decide può sceglierlo da sé)
	var scelte: Dictionary = _lavori.get("_scelte")
	for label in scelte:
		if str(scelte[label]) == COMPITO:
			return str(label)
	return ""


func _apri(mobile: Node3D) -> void:
	_estetista = _chi_ci_lavora()
	_t_pausa = 2.0
	var nodo := _nodo_di(_estetista)
	if nodo == null or mobile == null:
		return
	# si mette al SUO posto: di fianco alla poltrona, rivolto a chi si
	# siede — non davanti allo specchio, che è del cliente
	var posto: Vector3 = mobile.global_position \
			+ mobile.global_transform.basis * Vector3(-0.55, 0, 0.18)
	if nodo.has_method("do_routine"):
		nodo.call("do_routine", "sniff", posto, mobile.global_position)
	if nodo.has_method("speak"):
		nodo.call("speak", ["ciao", "bello"], "felice")


func _chiudi() -> void:
	_congeda_cliente()
	_estetista = ""


func _tick_seduta(delta: float, mobile: Node3D) -> void:
	if mobile == null:
		return
	if _cliente != "":
		_t_seduta -= delta
		if _t_seduta <= 0.0:
			_finisci_seduta()
		return
	_t_pausa -= delta
	if _t_pausa > 0.0:
		return
	_t_pausa = PAUSA_FRA_CLIENTI
	_chiama_il_prossimo(mobile)


## UN CLIENTE ALLA VOLTA: si sceglie fra i residenti che oggi non sono
## ancora passati, escluso chi ci lavora.
func _chiama_il_prossimo(mobile: Node3D) -> void:
	var candidati: Array = []
	for r in (_visitors.get("_residents") as Array):
		var label := str(r.get("label", ""))
		if label == "" or label == _estetista or _serviti.has(label):
			continue
		var nodo := r.get("node") as Node3D
		if nodo == null or not is_instance_valid(nodo):
			continue
		if nodo.has_method("is_hidden") and bool(nodo.call("is_hidden")):
			continue
		candidati.append(r)
	if candidati.is_empty():
		return
	var scelto: Dictionary = candidati[randi() % candidati.size()]
	_cliente = str(scelto["label"])
	_t_seduta = DURATA_SEDUTA
	var nodo2 := scelto.get("node") as Node3D
	var seggiola := mobile.find_child("Seggiola", true, false) as Node3D
	var dove: Vector3 = seggiola.global_position if seggiola \
			else mobile.global_position
	if nodo2.has_method("do_routine"):
		# "bench": ci arriva camminando e si SIEDE, guardando lo specchio
		nodo2.call("do_routine", "bench", dove - Vector3(0, dove.y, 0),
				mobile.global_position + Vector3(0, 0.9, -0.34))


## La seduta finisce: il ritocco addosso, il cliente si specchia contento
## e se ne va. È il momento che il giocatore guarda.
func _finisci_seduta() -> void:
	var nodo := _nodo_di(_cliente)
	if nodo != null and not (nodo.get("dna") as Dictionary).is_empty():
		var dna: Dictionary = nodo.get("dna")
		var seme := hash(_cliente + str(_giorno()))
		var nuovo := ritocco(dna, seme)
		if nodo.call("rifai_il_look", nuovo):
			_ultimo_servito = _cliente
			_serviti[_cliente] = true
			if nodo.has_method("celebrate"):
				nodo.call("celebrate")
			if nodo.has_method("speak"):
				nodo.call("speak", ["bello", "grazie"], "felice")
			# il filo si annoda anche fra vicini: e' un momento vissuto
			var leg := _i_legami()
			if leg and _estetista != "":
				leg.call("momento", _nome_di(_cliente), "regalo", "")
			_vai_a_vantarsi(_cliente)
			_congeda_cliente()
			return
	_congeda_cliente()


## IL VANTO. Uscire cambiati e non dirlo a nessuno non e' un cambiamento:
## e' un dettaglio grafico. Chi esce dal salone va a cercare il vicino
## piu' vicino e glielo fa vedere — e quello si illumina.
##
## E' la parte che fa esistere la meccanica agli occhi del giocatore: se
## non ci fosse, un vicino cambierebbe colore mentre lui guarda da
## un'altra parte, e non se ne accorgerebbe mai.
func _vai_a_vantarsi(chi: String) -> void:
	var nodo := _nodo_di(chi)
	if nodo == null:
		return
	var pubblico := _il_piu_vicino(chi, nodo.global_position)
	if pubblico == null:
		# nessuno a cui farlo vedere: allora si guarda allo specchio,
		# e va bene lo stesso
		if nodo.has_method("speak"):
			nodo.call("speak", ["bello", "felice"], "felice")
		_toast(L10n.tf("%s non fa che girarsi a guardare il suo riflesso.", [chi]))
		return
	# ci va, glielo mostra, e l'altro si illumina
	var verso: Vector3 = pubblico.global_position
	if nodo.has_method("do_routine"):
		nodo.call("do_routine", "sniff",
				verso + (nodo.global_position - verso).normalized() * 1.1, verso)
	if nodo.has_method("speak"):
		nodo.call("speak", ["guarda", "bello"], "felice")
	get_tree().create_timer(2.2).timeout.connect(func() -> void:
		if not is_instance_valid(pubblico):
			return
		pubblico.set_meta("postura", "si_illumina")
		if pubblico.has_method("speak"):
			pubblico.call("speak", ["bello", "amico"], "felice")
		if pubblico.has_method("_spawn_heart"):
			pubblico.call("_spawn_heart"))
	_toast(L10n.tf("%s corre a farsi vedere: il villaggio se ne accorge.", [chi]))


## Il residente piu' vicino a un punto, escluso `tranne` e chi ci lavora.
func _il_piu_vicino(tranne: String, da: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := 14.0
	for r in (_visitors.get("_residents") as Array):
		var label := str(r.get("label", ""))
		if label == tranne:
			continue
		var n := r.get("node") as Node3D
		if n == null or not is_instance_valid(n):
			continue
		if n.has_method("is_hidden") and bool(n.call("is_hidden")):
			continue
		var d := da.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _toast(testo: String) -> void:
	var hud := get_tree().get_first_node_in_group("toast")
	if hud and hud.has_method("show_toast"):
		hud.call("show_toast", testo)
	elif _visitors and _visitors.has_method("_show_toast"):
		_visitors.call("_show_toast", testo)


func _congeda_cliente() -> void:
	var nodo := _nodo_di(_cliente)
	if nodo != null and nodo.has_method("do_routine"):
		nodo.call("do_routine", "wander", nodo.global_position)
	_cliente = ""
	_t_seduta = 0.0


## Chi il salone ha cambiato oggi ("" se nessuno): lo legge il registro
## dei lavori per la resa del mattino.
func servito_oggi() -> String:
	return _ultimo_servito


func aperto() -> bool:
	return _aperto


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
