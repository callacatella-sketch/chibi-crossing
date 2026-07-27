extends Node

## Il Filo Rosso — Fase 1: il Filo dei Momenti.
##
## Il cuore del sistema emozionale (docs/SISTEMA_EMOZIONALE.md).
## Ogni gesto condiviso tra Mochi e un vicino diventa un MOMENTO:
## datato, raccontabile, persistito. Non punti: storia. Il primo
## momento di ogni tipo "colora il filo" (toast poetico), e salutando
## un amico (T) a volte lui RICORDA — un pensiero riaffiora, con le
## parole giuste in Chibiese. È la base su cui cresceranno le età
## della vita, il congedo, il lutto e i ricordi che restano: la
## perdita potrà fare male solo se c'è una storia da perdere.
##
## Gli altri sistemi non ci conoscono: chiamano
##   call_group("legami", "momento", nome, tipo, extra)
## e il filo si annoda da solo.

const MAX_MOMENTI := 30

## tipo -> [racconto, parole Chibiese del ricordo]
const TIPI := {
	"benvenuto": ["il primo benvenuto sulla soglia", ["ciao", "amico"]],
	"trasloco": ["il giorno della valigia sulla soglia", ["casa", "felice"]],
	"primo_saluto": ["la prima zampina alzata", ["ciao", "ciao"]],
	"piatto": ["quel piatto fumante diviso in due", ["cibo", "grazie"]],
	"regalo": ["un dono scelto con cura, zampa a zampa", ["grazie", "regalo"]],
	"festa": ["la festa a sorpresa coi coriandoli", ["felice", "regalo"]],
	"onsen": ["il bagno caldo alle terme, fianco a fianco", ["felice", "amico"]],
	"desiderio": ["il desiderio esaudito vicino a casa", ["grazie", "casa"]],
	"nascondino": ["la partita a nascondino nel bosco", ["risata", "amico"]],
	# gli ultimi desideri della settimana del congedo: i momenti d'ORO,
	# quelli che valgono il doppio quando riaffiorano
	"oro": ["quell'ultimo desiderio, vissuto insieme", ["grazie", "amico"]],
	# il congedo: chi se n'è andato non si cancella dal Filo Rosso. È
	# l'ultimo momento che si può incidere, e vale quanto il primo.
	"addio": ["il giorno in cui ha fatto il fagotto", ["addio", "triste"]],
	# la partenza gentile per il Grande Prato (tono Spiritfarer, mai Grim
	# Reaper): la valigia piccola e il cappello in zampa
	"partenza": ["il giorno della piccola valigia e del cappello in zampa", ["addio", "amico"]],
}

# nome residente -> {"momenti": [{d, t, x}], "giorno_arrivo": int}
# (e per chi è partito: "partito", "giorno_partenza", "fiore")
var _fili := {}
# il lutto del villaggio (Fase 4), uno alla volta: chi lo orchestra è il
# Congedo, ma i DATI vivono qui col resto del filo —
# {nome, giorno_inizio, giorni, da_consolare: [label…]}
var _lutto := {}
# l'ultima volta che il gioco è stato acceso (ora reale): al ritorno dopo
# un'assenza vera, i vicini se ne accorgono (Fase 6)
var _ultimo_gioco := 0
var _assenza_reale := 0.0
var _daynight: Node3D
var _visitors: Node
var _ricordo_cd := 0.0


func _ready() -> void:
	add_to_group("legami")
	add_to_group("persistable")
	(func():
		_daynight = get_node_or_null("../../DayNight")
		_visitors = get_node_or_null("../../Visitors")
		if _daynight and _daynight.has_signal("day_changed"):
			_daynight.day_changed.connect(_nuovo_giorno)
		# auto-verifica per la CLI: il filo si annoda e si legge
		if OS.get_environment("CHIBI_SHOT") != "":
			momento("__prova", "onsen")
			momento("__prova", "festa")
			print("LEGAMI: ok, %d momenti sul filo di prova" % momenti_di("__prova").size())
			_fili.erase("__prova")).call_deferred()


func _process(delta: float) -> void:
	_ricordo_cd = maxf(0.0, _ricordo_cd - delta)


func _day() -> int:
	return int(_daynight.get("day")) if _daynight else 1


# ---------------------------------------------------------------- il filo

func _filo(nome: String) -> Dictionary:
	if not _fili.has(nome):
		_fili[nome] = {"momenti": [], "giorno_arrivo": _day()}
	return _fili[nome]


## Annoda un momento al filo. Un momento per tipo al giorno (una festa
## non vale doppio); il PRIMO di ogni tipo colora il filo con un toast.
func momento(nome: String, tipo: String, extra := "") -> void:
	if nome == "" or not TIPI.has(tipo):
		return
	var filo := _filo(nome)
	var momenti: Array = filo["momenti"]
	var oggi := _day()
	var primo := true
	for m in momenti:
		if str(m["t"]) == tipo:
			primo = false
			if int(m["d"]) == oggi:
				return  # già annodato oggi
	momenti.append({"d": oggi, "t": tipo, "x": extra})
	if momenti.size() > MAX_MOMENTI:
		momenti.pop_front()
	if nome != "__prova":
		if primo:
			_toast("❀ Il filo con %s si colora: %s" % [nome, str(TIPI[tipo][0])])
			# il momento che si annoda SI VEDE: il filo rosso tra le zampe
			mostra_filo(nome, tipo == "oro")
		elif tipo == "oro":
			# ogni desiderio d'oro della settimana del congedo merita il filo
			mostra_filo(nome, true)
	_salva()


## Il ricordo che riaffiora: chiamato dal saluto (T). Il vicino ripensa
## a un momento del filo — pensierino a schermo e parole in Chibiese.
## Con un contegno: non più di uno ogni mezzo minuto.
func ricorda(nome: String, node: Node3D) -> void:
	if _ricordo_cd > 0.0 or not _fili.has(nome):
		return
	var momenti: Array = _fili[nome]["momenti"]
	# gli anziani raccontano: ricordano più spesso, e più volentieri
	var f := eta_f(nome)
	if momenti.is_empty() or randf() > 0.45 + 0.35 * f:
		return
	_ricordo_cd = 30.0 - 14.0 * f
	var m: Dictionary = momenti[randi() % momenti.size()]
	var tipo := str(m["t"])
	_toast("💭 %s ripensa: %s (giorno %d)" % [nome, str(TIPI[tipo][0]), int(m["d"])])
	if node and is_instance_valid(node):
		var parole: Array = TIPI[tipo][1]
		node.call("speak", parole, "felice")
		node.call("_spawn_heart")
	# il ricordo fa brillare il filo, ma piano: appena accennato
	mostra_filo(nome, false, 0.55)


## IL FILO ROSSO LETTERALE — l'API del simbolo. Nei momenti che si
## annodano, il nastro luminoso appare tra la zampa di Mochi e quella del
## vicino (nome O label): le perline lungo il filo sono i momenti già
## vissuti insieme. `oro` per il desiderio d'oro, `intensita` < 1 per il
## filo appena accennato di un ricordo. Il disegno vive in FiloRosso.gd.
func mostra_filo(nome: String, oro := false, intensita := 1.0) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var filo_rosso := tree.get_first_node_in_group("filo_rosso")
	if _visitors == null:
		_visitors = get_node_or_null("../../Visitors")
	var player := tree.get_first_node_in_group("player_controller")
	if filo_rosso == null or _visitors == null or player == null:
		return
	var mochi := player.get_node_or_null("Mochi")
	if mochi == null:
		return
	for r in (_visitors.get("_residents") as Array):
		var dna: Dictionary = r.get("dna", {})
		var vero_nome := str(dna.get("name", ""))
		if vero_nome != nome and str(r.get("label", "")) != nome:
			continue
		var node := r.get("node") as Node3D
		if node and is_instance_valid(node) and not bool(node.call("is_hidden")):
			filo_rosso.call("annoda", mochi, node,
					momenti_di(vero_nome).size(), oro, intensita)
		return


# ------------------------------------------------- le stagioni della vita
# (Fase 2) Il tempo passa per tutti: dopo ~un ciclo di calendario si è
# adulti, dopo tre arriva l'autunno — e si vede, e si SENTE.

const GIORNI_ADULTO := 14
const GIORNI_ANZIANO := 40


## Registra l'arrivo di un residente (idempotente): il filo nasce qui
## anche per chi arriva da salvataggi precedenti al Filo Rosso.
func registra_arrivo(nome: String) -> void:
	if nome != "":
		_filo(nome)


## Il fattore d'età continuo: 0 = giovane, 0.5 = soglia dell'autunno,
## 1 = pieno autunno. Guida voce, passo, postura e brizzolatura.
func eta_f(nome: String) -> float:
	var g := giorni_di_amicizia(nome)
	return 0.5 * clampf(float(g - GIORNI_ADULTO) / 26.0, 0.0, 1.0) \
			+ 0.5 * clampf(float(g - GIORNI_ANZIANO) / 20.0, 0.0, 1.0)


func eta_di(nome: String) -> String:
	var g := giorni_di_amicizia(nome)
	if g >= GIORNI_ANZIANO:
		return "anziano"
	return "adulto" if g >= GIORNI_ADULTO else "giovane"


# ogni mattina le stagioni avanzano: quando qualcuno entra nell'autunno
# il villaggio lo sa — il toast, l'anello del Grande Albero, il Gufo
func _nuovo_giorno(_d: int) -> void:
	for nome in _fili:
		var filo: Dictionary = _fili[nome]
		if bool(filo.get("partito", false)):
			continue  # chi è partito non invecchia più: resta com'era
		var prima := str(filo.get("s", "giovane"))
		var adesso := eta_di(str(nome))
		if adesso == prima:
			continue
		filo["s"] = adesso
		if adesso == "anziano":
			_toast("🍂 Sul musetto di %s brillano i primi peli d'argento" % nome)
			var gtree: Node = get_tree().get_first_node_in_group("grande_albero")
			if gtree:
				gtree.call("engrave_once", "argento_" + str(nome), "🍂",
						"l'autunno di %s è cominciato" % nome)
			var mail: Node = get_node_or_null("../../Mail")
			if mail:
				mail.call("queue_letter", {
					"from": "Il Gufo",
					"text": "Ho visto i primi peli d'argento\nsul musetto di %s.\nLe stagioni passano anche per noi.\nStagli vicino." % nome,
					"gift": false,
				})
	_salva()


# ---------------------------------------------------------------- letture

func momenti_di(nome: String) -> Array:
	return _fili.get(nome, {}).get("momenti", [])


func giorni_di_amicizia(nome: String) -> int:
	if not _fili.has(nome):
		return 0
	return maxi(0, _day() - int(_fili[nome]["giorno_arrivo"]))


# ------------------------------------------- la partenza e il lutto (dati)
# La perdita trasforma, non cancella: il filo di chi parte resta, cambia
# solo forma. L'orchestrazione (settimana del congedo, echi, consolazioni)
# sta in Congedo.gd; qui vivono e si persistono i FATTI.

## Segna la partenza per il Grande Prato. `fiore` è la scheda del
## fiore-ricordo ({x, z, dress, fur, petali}): coi colori salvati qui, il
## fiore rinasce identico anche quando il DNA del residente non c'è più.
## `dna` è il CORPO com'era: serve agli echi del lutto per far sedere la
## sua presenza dove i momenti accaddero (Congedo._eco_presenza).
func segna_partito(nome: String, fiore: Dictionary, dna := {}) -> void:
	var filo := _filo(nome)
	filo["partito"] = true
	filo["giorno_partenza"] = _day()
	filo["fiore"] = fiore
	if not dna.is_empty():
		filo["dna_ricordo"] = dna
	_salva()


## Il corpo del ricordo: il DNA di chi è partito ({} per i salvataggi
## precedenti agli echi-presenza — il fantasma si rigenera dal nome).
func dna_ricordo(nome: String) -> Dictionary:
	return _fili.get(nome, {}).get("dna_ricordo", {})


## La scheda del fiore di chi è partito (i colori del ricordo).
func fiore_di(nome: String) -> Dictionary:
	return _fili.get(nome, {}).get("fiore", {})


func e_partito(nome: String) -> bool:
	return bool(_fili.get(nome, {}).get("partito", false))


## [[nome, filo], …] di chi è partito: il Congedo ci ricostruisce i fiori.
func partiti() -> Array:
	var out := []
	for nome in _fili:
		if bool((_fili[nome] as Dictionary).get("partito", false)):
			out.append([str(nome), _fili[nome]])
	return out


## Apre il lutto del villaggio. `giorni` è proporzionale al filo: una
## storia lunga lascia un vuoto lungo (3..8 giorni).
func inizia_lutto(nome: String, da_consolare: Array) -> void:
	var n := momenti_di(nome).size()
	_lutto = {"nome": nome, "giorno_inizio": _day(),
			"giorni": clampi(3 + n / 6, 3, 8), "da_consolare": da_consolare}
	_salva()


func lutto() -> Dictionary:
	return _lutto


func lutto_attivo() -> bool:
	return not _lutto.is_empty()


## Mochi ha consolato qualcuno (la zampina alzata durante il lutto):
## true se era tra chi aspettava un pensiero.
func consola(label: String) -> bool:
	if _lutto.is_empty():
		return false
	var resto: Array = _lutto.get("da_consolare", [])
	if label in resto:
		resto.erase(label)
		_salva()
		return true
	return false


## Chiude il lutto e ritorna chi NON è mai stato consolato (è
## l'indifferenza a ferire, non la perdita: vedi Animo.lutto).
func fine_lutto() -> Array:
	var resto: Array = _lutto.get("da_consolare", [])
	_lutto = {}
	_salva()
	return resto


## Giorni REALI passati dall'ultima sessione di gioco (Fase 6: il ritorno).
func assenza_reale_giorni() -> float:
	return _assenza_reale


# ---------------------------------------------------------------- servizi

func _toast(text: String) -> void:
	if _visitors == null:
		_visitors = get_node_or_null("../../Visitors")
	if _visitors:
		_visitors.call("_show_toast", text)


func _salva() -> void:
	var tree := get_tree()
	if tree == null:
		return  # fuori dall'albero (test): niente da salvare
	var bs: Node = tree.get_first_node_in_group("build_system")
	if bs:
		bs.request_save()


# ---------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	return {"legami": _fili, "lutto": _lutto,
			"ultimo_gioco": int(Time.get_unix_time_from_system())}


func load_extra(data: Dictionary) -> void:
	var d: Variant = data.get("legami")
	if d is Dictionary:
		_fili = d
	var l: Variant = data.get("lutto")
	if l is Dictionary:
		_lutto = l
	_ultimo_gioco = int(data.get("ultimo_gioco", 0))
	if _ultimo_gioco > 0:
		_assenza_reale = maxf(0.0,
				(Time.get_unix_time_from_system() - _ultimo_gioco) / 86400.0)
