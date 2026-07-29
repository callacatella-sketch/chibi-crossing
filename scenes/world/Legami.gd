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

# ============================================================ COME SI DIMENTICA
# Un filo tiene al più MAX_MOMENTI momenti. Prima, quando sforava, faceva
# `pop_front()`: buttava il PIÙ VECCHIO — cioè, in quest'ordine, "il primo
# benvenuto sulla soglia" e "il giorno della valigia". Esattamente i due che
# il congedo vuole citare cento giorni dopo: `Congedo._riaffiora()` campiona
# i momenti a intervalli lungo TUTTO l'arco della vita, per raccontarla dal
# principio; con la coda tagliata, il "principio" diventava il trentesimo
# momento dal fondo, e la storia cominciava a metà.
#
# Adesso il filo dimentica come dimentica una persona: non l'inizio — le
# REPLICHE. Quando sfora si sacrifica il momento che costa meno perderlo, e
# il costo si misura su due cose:
#   · il BUCO che lascia: togliere un momento in mezzo a due vicini di
#     giornata non toglie niente alla forma della storia; toglierne uno
#     isolato apre un vuoto di settimane;
#   · la RARITÀ del suo tipo: la quarantesima chiacchierata vale meno
#     dell'unica festa.
# E certi momenti non si toccano MAI (INTOCCABILI, sotto).

## I tipi che non si potano mai: i capi della storia. Il primo benvenuto e
## il giorno della valigia sono l'inizio; l'oro sono gli ultimi desideri
## della settimana del congedo; addio e partenza sono la fine.
const INTOCCABILI := ["benvenuto", "trasloco", "oro", "addio", "partenza"]

## Quanti momenti in testa e in coda sono comunque salvi: i capi del filo
## si tengono anche se il tipo non è fra gli intoccabili (i primi giorni
## sono i primi giorni, e l'ultima settimana è quella che si sta vivendo).
const CAPI_TESTA := 3
const CAPI_CODA := 3

## tipo -> [racconto, parole Chibiese del ricordo]
const DNA_GEN := preload("res://scenes/npc/ChibiDNA.gd")

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

## Da una LABEL ("la volpina Pepita") al NOME ("Pepita"). PURA.
## Le chiavi dei fili sono il nome del DNA; ma le label girano per tutto
## il gioco (toast, lettere, `_animi` di Visitors e' indicizzato COSI'),
## e un chiamante distratto ne passa una: il momento finiva in un filo
## separato che nessuno leggeva piu' — ed e' successo davvero all'ADDIO
## della diserzione, il momento piu' importante che un filo possa avere.
## Il prefisso si toglie dalla FONTE UNICA (ChibiDNA.DESCR), non da una
## lista di articoli ricopiata a mano.
static func nome_da_chiave(chiave: String) -> String:
	if not chiave.contains(" "):
		return chiave
	for descr in DNA_GEN.DESCR.values():
		var pre := str(descr) + " "
		if chiave.begins_with(pre):
			return chiave.substr(pre.length())
	return chiave


func _filo(nome: String) -> Dictionary:
	# la chiave e' SEMPRE il nome: se arriva una label la si riporta a
	# nome, cosi' il filo resta uno solo qualunque cosa passi il chiamante
	var chiave := nome_da_chiave(nome)
	if not _fili.has(chiave):
		_fili[chiave] = {"momenti": [], "giorno_arrivo": _day()}
	return _fili[chiave]


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
	# IL CONTO NON SI POTA MAI. I momenti vissuti sono una cosa, quelli che
	# il filo riesce a portare con sé un'altra: la lettera d'addio dice
	# «porto con me N momenti del nostro filo», e quel numero deve essere
	# la vita vera, non la capienza della borsa. Si incrementa QUI, dopo il
	# `return` del doppione di giornata, o «una festa non vale doppio»
	# varrebbe per i momenti e non per il conto.
	filo["n"] = int(filo.get("n", momenti.size() - 1)) + 1
	if momenti.size() > MAX_MOMENTI:
		# si muta l'array VIVO: momenti_di() lo restituisce così com'è e i
		# chiamanti se lo tengono (Congedo, Mail). Sostituirlo con una copia
		# potata slegherebbe i riferimenti già in giro, in silenzio.
		var vittima := indice_da_potare(momenti)
		if vittima >= 0:
			momenti.remove_at(vittima)
		# vittima < 0 = è tutto intoccabile: si tiene un momento in più.
		# Meglio un filo di 31 che un ricordo insostituibile buttato via.
	if nome != "__prova":
		if primo:
			_toast(L10n.tf("❀ Il filo con %s si colora: %s",
					[nome, L10n.t(str(TIPI[tipo][0]))]))
			# il momento che si annoda SI VEDE: il filo rosso tra le zampe
			mostra_filo(nome, tipo == "oro")
		elif tipo == "oro":
			# ogni desiderio d'oro della settimana del congedo merita il filo
			mostra_filo(nome, true)
	_salva()


# ============================================================ la potatura gentile
# Tutto quello che segue è PURO: entra una lista di momenti, esce un indice.
# Nessun nodo, nessun tempo di gioco — così la memoria di una vita intera si
# prova headless (tests/cases/test_potatura.gd) invece che giocando per
# quattrocento giorni e sperando.

## Questo momento non si può sacrificare? Lo sono i tipi capo (INTOCCABILI),
## il PRIMO di ogni tipo (il primo bagno alle terme è un primato, il
## quindicesimo no) e i momenti ai due capi del filo.
static func intoccabile(momenti: Array, i: int) -> bool:
	if i < 0 or i >= momenti.size():
		return true
	if i < CAPI_TESTA or i >= momenti.size() - CAPI_CODA:
		return true
	var tipo := str((momenti[i] as Dictionary).get("t", ""))
	if tipo in INTOCCABILI:
		return true
	# il primo della sua specie: cerca se ne esiste uno uguale più indietro
	for j in i:
		if str((momenti[j] as Dictionary).get("t", "")) == tipo:
			return false
	return true


## Il BUCO che si aprirebbe togliendo il momento i: la distanza in giorni
## fra i suoi due vicini. Un momento fra due giornate contigue non lascia
## traccia; uno isolato porta via settimane di storia.
static func buco(momenti: Array, i: int) -> int:
	if i <= 0 or i >= momenti.size() - 1:
		return 0
	var prima := int((momenti[i - 1] as Dictionary).get("d", 0))
	var dopo := int((momenti[i + 1] as Dictionary).get("d", 0))
	# maxi: un salvataggio con le date in disordine non deve produrre un
	# costo negativo, che si mangerebbe un intoccabile
	return maxi(0, dopo - prima)


## Quanto costa perdere il momento i. Più basso = più sacrificabile.
## Due voci: il buco che lascia, e quanto è RARO il suo tipo (l'unica
## festa vale più della quarantesima chiacchierata).
static func costo(momenti: Array, i: int) -> float:
	var tipo := str((momenti[i] as Dictionary).get("t", ""))
	var quanti := 0
	for m in momenti:
		if str((m as Dictionary).get("t", "")) == tipo:
			quanti += 1
	# la rarità pesa quanto un buco di quattro giorni per un tipo unico, e
	# svanisce sulle repliche: 1 volta -> 4.0, 2 -> 2.0, 8 -> 0.5
	var rarita := 4.0 / float(maxi(quanti, 1))
	return float(buco(momenti, i)) + rarita


## Chi si sacrifica: l'indice del momento che costa meno perdere.
## -1 se è tutto intoccabile (e allora il filo tiene un momento in più:
## meglio sforare che buttare un ricordo insostituibile).
static func indice_da_potare(momenti: Array) -> int:
	var scelto := -1
	var minimo := INF
	for i in momenti.size():
		if intoccabile(momenti, i):
			continue
		var c := costo(momenti, i)
		if c < minimo:
			minimo = c
			scelto = i
	return scelto


## Pota una lista fino alla capienza data. COPIA: non tocca l'originale —
## la usano la migrazione e i test. Dentro `momento()` invece si muta
## l'array vivo, perché i chiamanti se lo tengono.
static func pota(momenti: Array, tetto := MAX_MOMENTI) -> Array:
	var out := momenti.duplicate()
	while out.size() > tetto:
		var vittima := indice_da_potare(out)
		if vittima < 0:
			break
		out.remove_at(vittima)
	return out


## Il ricordo che riaffiora: chiamato dal saluto (T). Il vicino ripensa
## a un momento del filo — pensierino a schermo e parole in Chibiese.
## Con un contegno: non più di uno ogni mezzo minuto.
func ricorda(nome_o_label: String, node: Node3D) -> void:
	var nome := nome_da_chiave(nome_o_label)
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
	_toast(L10n.tf("💭 %s ripensa: %s (giorno %d)",
			[nome, L10n.t(str(TIPI[tipo][0])), int(m["d"])]))
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
func registra_arrivo(nome_o_label: String) -> void:
	if nome_o_label != "":
		_filo(nome_o_label)   # _filo normalizza: mai un filo per la label


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
		if bool(filo.get("partito", false)) or bool(filo.get("andato_via", false)):
			continue  # chi non c'è più non invecchia: resta com'era
		var prima := str(filo.get("s", "giovane"))
		var adesso := eta_di(str(nome))
		if adesso == prima:
			continue
		filo["s"] = adesso
		if adesso == "anziano":
			_toast(L10n.tf("🍂 Sul musetto di %s brillano i primi peli d'argento", [nome]))
			var gtree: Node = get_tree().get_first_node_in_group("grande_albero")
			if gtree:
				gtree.call("engrave_once", "argento_" + str(nome), "🍂",
						L10n.tf("l'autunno di %s è cominciato", [nome]))
			var mail: Node = get_node_or_null("../../Mail")
			if mail:
				mail.call("queue_letter", {
					"from": L10n.t("Il Gufo"),
					"text": L10n.tf("Ho visto i primi peli d'argento\nsul musetto di %s.\nLe stagioni passano anche per noi.\nStagli vicino.", [nome]),
					"gift": false,
				})
	_salva()


# ---------------------------------------------------------------- letture

func momenti_di(nome_o_label: String) -> Array:
	return _fili.get(nome_da_chiave(nome_o_label), {}).get("momenti", [])


## Quanti momenti si sono VISSUTI in tutto — non quanti il filo ne porta
## ancora con sé. È il numero della lettera d'addio («porto con me N
## momenti del nostro filo»): dopo cento giorni il filo ne conserva trenta,
## ma la vita insieme è stata più lunga, e dire trenta sarebbe una bugia.
## Per i fili nati prima della potatura gentile il conto riparte da quelli
## che ci sono: un pavimento onesto, non un passato inventato.
func momenti_vissuti(nome_o_label: String) -> int:
	var filo: Dictionary = _fili.get(nome_da_chiave(nome_o_label), {})
	if filo.is_empty():
		return 0
	# int(): il salvataggio passa da JSON e gli interi tornano float
	return maxi(int(filo.get("n", 0)), (filo.get("momenti", []) as Array).size())


func giorni_di_amicizia(nome_o_label: String) -> int:
	var nome := nome_da_chiave(nome_o_label)
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
func dna_ricordo(nome_o_label: String) -> Dictionary:
	return _fili.get(nome_da_chiave(nome_o_label), {}).get("dna_ricordo", {})


## La scheda del fiore di chi è partito (i colori del ricordo).
func fiore_di(nome_o_label: String) -> Dictionary:
	return _fili.get(nome_da_chiave(nome_o_label), {}).get("fiore", {})


## Se n'e' andato DA SE' (la diserzione), che e' un'altra cosa dal
## partire per il Grande Prato: niente memoriale, niente fiore-ricordo
## dorato (Congedo li nega apposta a chi se n'e' andato arrabbiato) — ma
## il suo filo smette di invecchiare, o quaranta giorni dopo aver
## sbattuto la porta il villaggio annuncerebbe i primi peli d'argento di
## chi non c'e' piu'. La LABEL si salva qui perche' al caricamento il
## suo DNA non esiste piu' da nessuna parte, e le lettere la vogliono.
func segna_andato_via(nome_o_label: String, label := "") -> void:
	var filo := _filo(nome_o_label)
	filo["andato_via"] = true
	filo["giorno_partenza"] = _day()
	if label != "":
		filo["label"] = label
	_salva()


## Chi se n'e' andato da se': [[label, filo], …]. Le sue lettere sono
## l'UNICA traccia che resta di lui (niente fiore, niente memoriale).
func andati_via() -> Array:
	var out: Array = []
	for k in _fili:
		var filo: Dictionary = _fili[k]
		if bool(filo.get("andato_via", false)):
			out.append([str(filo.get("label", k)), filo])
	return out


func e_partito(nome_o_label: String) -> bool:
	return bool(_fili.get(nome_da_chiave(nome_o_label), {}).get("partito", false))


## [[nome, filo], …] di chi è partito: il Congedo ci ricostruisce i fiori.
func partiti() -> Array:
	var out := []
	for nome in _fili:
		if bool((_fili[nome] as Dictionary).get("partito", false)):
			out.append([str(nome), _fili[nome]])
	return out


## Apre il lutto del villaggio. `giorni` è proporzionale al filo: una
## storia lunga lascia un vuoto lungo (3..8 giorni).
func inizia_lutto(nome_o_label: String, da_consolare: Array) -> void:
	# la chiave si normalizza; `da_consolare` NO: quella e' una lista di
	# LABEL per progetto (Congedo la riempie cosi' e consola() la
	# interroga cosi'). Aggiustarla romperebbe le consolazioni.
	var nome := nome_da_chiave(nome_o_label)
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


## I fili salvati PRIMA della correzione: chi ha gia' visto una
## diserzione ha sul disco un filo fantasma con la chiave-label, e dentro
## c'e' il suo addio. Non si butta via un ricordo in un gioco che parla di
## memoria: al caricamento i fantasmi si RIVERSANO nel filo vero — momenti
## uniti (senza duplicati: stesso giorno + stesso tipo = lo stesso
## momento), e giorno_arrivo il piu' antico dei due. PURA e testabile.
static func migra_fili(salvati: Dictionary) -> Dictionary:
	var out := {}
	# prima i fili gia' sani, poi i fantasmi vi si fondono dentro (mai il
	# contrario: un fantasma non deve diventare il filo "principale")
	var chiavi: Array = []
	for k in salvati:
		if nome_da_chiave(str(k)) == str(k):
			chiavi.append(k)
	for k in salvati:
		if nome_da_chiave(str(k)) != str(k):
			chiavi.append(k)
	for k in chiavi:
		var filo: Variant = salvati[k]
		if filo is not Dictionary:
			continue
		var nome := nome_da_chiave(str(k))
		if not out.has(nome):
			out[nome] = filo
			continue
		# il fantasma si riversa nel filo vero
		var vero: Dictionary = out[nome]
		var suoi: Array = vero.get("momenti", [])
		for m in (filo.get("momenti", []) as Array):
			var doppio := false
			for gia in suoi:
				if str(gia.get("t", "")) == str(m.get("t", "")) \
						and int(gia.get("d", -1)) == int(m.get("d", -2)):
					doppio = true
					break
			if not doppio:
				suoi.append(m)
		suoi.sort_custom(func(a, b): return int(a.get("d", 0)) < int(b.get("d", 0)))
		vero["momenti"] = suoi
		vero["giorno_arrivo"] = mini(int(vero.get("giorno_arrivo", 99999)),
				int(filo.get("giorno_arrivo", 99999)))
		# i due conti si sommano: il fantasma era la stessa amicizia
		vero["n"] = int(vero.get("n", 0)) + int(filo.get("n", 0))
		# il ricordo del DNA (chi e' partito) non si perde
		if not vero.has("dna_ricordo") and filo.has("dna_ricordo"):
			vero["dna_ricordo"] = filo["dna_ricordo"]
	# --- la rifinitura, per TUTTI i fili (non solo per quelli fusi) ---
	for nome in out:
		var filo: Dictionary = out[nome]
		var momenti: Array = filo.get("momenti", [])
		# 1. l'ordine per giornata è la PRECONDIZIONE di buco(): un
		#    salvataggio storto darebbe distanze negative
		momenti.sort_custom(func(a, b): return int(a.get("d", 0)) < int(b.get("d", 0)))
		# 2. il conto di chi non l'ha mai avuto parte dal pavimento onesto:
		#    i momenti superstiti. Quello che il vecchio pop_front() ha già
		#    buttato è perso — e in un gioco che parla di memoria, inventare
		#    un passato mai vissuto sarebbe peggio che ammettere il vuoto
		if not filo.has("n"):
			filo["n"] = momenti.size()
		# 3. la fusione di un fantasma poteva portare l'array ben oltre il
		#    tetto e lasciarcelo finché non arrivava un momento nuovo: era
		#    un difetto già in produzione, si chiude qui
		if momenti.size() > MAX_MOMENTI:
			filo["momenti"] = pota(momenti)
	return out


func load_extra(data: Dictionary) -> void:
	var d: Variant = data.get("legami")
	if d is Dictionary:
		_fili = migra_fili(d)
	var l: Variant = data.get("lutto")
	if l is Dictionary:
		_lutto = l
	_ultimo_gioco = int(data.get("ultimo_gioco", 0))
	if _ultimo_gioco > 0:
		_assenza_reale = maxf(0.0,
				(Time.get_unix_time_from_system() - _ultimo_gioco) / 86400.0)
