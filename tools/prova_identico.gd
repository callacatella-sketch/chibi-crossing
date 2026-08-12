extends SceneTree
## «IL GIOCO FUNZIONA IDENTICO SENZA» — il banco che lo mette alla prova.
##
##   CHIBI_ARM=senza  Godot --headless --path . --script res://tools/prova_identico.gd
##
## La Fase 5 ha UN vincolo che sta sopra tutti gli altri, ed è dell'autore:
## chi non ha il modello ha un gioco **meno sorprendente, non un gioco a cui
## manca un pezzo**. Non «degrada con grazia»: IDENTICO. Questo file è
## l'unico posto in cui quella frase diventa un numero.
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ NON BASTA UNA SUITE VERDE (e nemmeno dieci)
## ────────────────────────────────────────────────────────────────────────
##
## Una suite dice che le funzioni rispondono. Non dice che il villaggio VIVE
## uguale: che quel vicino, in quel minuto, ha fatto la stessa cosa. E la
## Fase 5 può romperlo in modi che nessuna asserzione vede — un thread che
## ruba un core e sposta di un frame la decisione dell'agenda, un modello che
## si carica e sposta la memoria sotto i piedi al gioco, un `annulla()` che
## lascia una bandiera alzata. Perciò qui si fa una cosa sola, e si fa bene:
## **si fa vivere il villaggio VERO e si scrive quello che i vicini hanno
## fatto, campione per campione.** Poi si confrontano due vite.
##
## L'ORACOLO È IL CONFRONTO, non un'asserzione scritta da me: due bracci
## dello stesso banco devono dare la STESSA traccia, byte per byte. Se
## cambia un solo carattere, il villaggio non è identico — e il file dice
## dove.
##
## ────────────────────────────────────────────────────────────────────────
## I BRACCI
## ────────────────────────────────────────────────────────────────────────
##
##  · `senza`    — nessun motore. Sul binario `llm=no` è il gioco di chi non
##                 ha mai sentito parlare della Fase 5.
##  · `assente`  — il motore c'è (binario `llm=yes`), il MODELLO no: si apre
##                 un percorso che non esiste. **È il caso del giocatore
##                 normale**, quello che scarica il gioco e basta.
##  · `corrotto` — il modello c'è ma è guasto (troncato, byte sporchi). Qui
##                 la domanda non è solo «il gioco continua»: è «il processo
##                 è ancora vivo», perché `GGML_ABORT` non è un'eccezione.
##  · `vero`     — il modello c'è, funziona, e il villaggio pensa davvero.
##  · `lento`    — il modello c'è ma è al guinzaglio (un thread solo,
##                 priorità di fondo, molte copie): una generazione costa
##                 dieci volte il previsto.
##  · `mai`      — il modello c'è e la generazione NON TORNA dentro la durata
##                 della prova. È il caso peggiore di tutti, ed è quello in
##                 cui un'attesa scritta male fa ammutolire il villaggio per
##                 sempre.
##  · `sordo`    — un motore FINTO, di quindici righe, che accetta e non
##                 risponde MAI. Serve a provare la stessa cosa di `mai`
##                 senza pagarne il rumore: siccome non consuma un core, la
##                 sua traccia si può confrontare **byte per byte** con
##                 quella di `senza`. È l'unico modo di dimostrare che un
##                 pensiero che non torna non cambia il gioco, invece di
##                 osservare che «sembra uguale».
##
## `senza`, `assente`, `corrotto` e `sordo` non producono NIENTE: le loro
## tracce devono essere IDENTICHE, ed è l'unica forma in cui «identico» si
## dimostra invece di dichiararlo. `vero`, `lento` e `mai` producono, e lì il
## metro cambia: si guarda che non sia PEGGIORATO niente.
##
## ────────────────────────────────────────────────────────────────────────
## LE TRAPPOLE DI MISURA, tutte pagate scrivendo questo file
## ────────────────────────────────────────────────────────────────────────
##
## 1. **`--headless` FORZA il passo fisso** (lo dice `--help`: «--fixed-fps
##    is forced when enabled»). È la ragione per cui questo banco è headless:
##    il `delta` che arriva ai `_process` è lo stesso identico numero a ogni
##    corsa, e senza quello due vite non sarebbero confrontabili nemmeno se
##    il codice fosse lo stesso.
## 2. **I DADI SI SEMINANO A MANO, TUTTI.** `Visitors._ready` fa
##    `_chat_rng.randomize()` (in partita è giusto: le chiacchiere non si
##    ripetono uguali), e il dado globale di Godot parte da un seme casuale.
##    Qui si rimettono a un numero fisso DOPO che la scena è in piedi.
## 3. **L'OROLOGIO DA POLSO RESTA.** `Visitors._chats` misura il riposo
##    delle coppie con `Time.get_ticks_msec()`, cioè col tempo VERO, non col
##    tempo del gioco. Su un banco che gira più veloce del tempo reale (qui
##    un secondo di gioco costa molto meno di un secondo) quel riposo non
##    scade mai, e le chiacchiere spariscono dal confronto. **Non è un
##    guasto di questo banco: è del gioco**, ed è dichiarato in fondo alla
##    stampa perché chi legge sappia cosa la traccia NON copre.
## 4. **UN CAMPIONE NON È UNA POSA.** Si scrive lo stato del corpo, l'azione
##    scelta dall'agenda, la posizione al millimetro E i cinque bisogni: i
##    bisogni sono l'unica cosa che scorre di continuo, e sono perciò il
##    rivelatore più sensibile che ci sia. Un frame perso da qualche parte
##    li sposta di 1e-4 e la traccia se ne accorge.
## 5. **LA TRACCIA NON HA DENTRO NÉ IL TEMPO VERO NÉ UN INDIRIZZO.** Niente
##    `get_ticks`, niente `get_instance_id`: due corse identiche devono dare
##    lo stesso file, e un puntatore stampato lo impedirebbe per sempre.

const FOGLIO := preload("res://scenes/npc/FoglioDelVicino.gd")
const PENSATOIO := preload("res://scenes/npc/Pensatoio.gd")
const DEDUZIONI := preload("res://scenes/npc/Deduzioni.gd")
const GIUDICE := preload("res://scenes/npc/Giudice.gd")
const LLM := preload("res://systems/Llm.gd")
const BRAIN := preload("res://scenes/npc/VillagerBrain.gd")

## Quanti vicini. Non ventotto: dodici bastano a far succedere tutto
## (chiacchiere, falò, mestieri, sonno) e lasciano al banco un passo
## abbastanza veloce da poterlo ripetere sei volte.
const VICINI := 12
## Ogni quanti frame si scrive un campione. Quattro al secondo: più fitto
## non aggiunge niente (i cambi di stato durano secondi), più rado
## perderebbe le transizioni brevi.
const OGNI := 15
## ⚠️ IL CUSCINETTO DEL CARICO, in FRAME, ed è il pezzo di banco che ho
## capito per ultimo. Aprire un modello costa tempo, e ogni modello ne costa
## uno suo: 0 ms per un percorso che non esiste, 22 ms per un file che il
## portiere rifiuta, 1508 ms per il modello vero. In quel tempo il gioco
## continua a girare — ed è giusto così, è la promessa della fase — ma vuol
## dire che i bracci arrivano al via dopo un numero DIVERSO di frame di
## mondo, e quindi con un villaggio in un momento diverso della sua giornata.
##
## Misurato: le sedici copie guaste davano cinque impronte diverse, e le
## copie che ci mettevano lo stesso tempo davano la stessa impronta. Non era
## il guasto a cambiare il gioco: era l'orologio.
##
## Perciò dopo il tentativo di carico si aspetta fino a un numero FISSO di
## frame. Chi ci mette meno aspetta; chi ci mette di più lo dichiara, e il
## suo confronto vale solo per quello che succede dopo.
## (Misurato: il modello vero se ne prende 2226-2230, il portiere che rifiuta
## un file guasto 31, un percorso che non esiste 0.)
const PAD_CARICO := 4000

## Il villaggio, in celle. È lo stesso per tutti i bracci — la prima regola
## di un confronto appaiato — e ha dentro tutto quello che i piani sanno
## nominare: letti coperti (una casa non è un letto), un cespuglio, una
## panchina, un orto, la lavagna.
const CASE := [
	Vector2i(6, 6), Vector2i(9, 6), Vector2i(12, 6), Vector2i(15, 6),
	Vector2i(6, 9), Vector2i(9, 9), Vector2i(12, 9), Vector2i(15, 9),
	Vector2i(6, 12), Vector2i(9, 12), Vector2i(12, 12), Vector2i(15, 12),
]
const ARREDO := [
	[Vector2i(3, 8), "Cespuglio"], [Vector2i(3, 10), "Cespuglio"],
	[Vector2i(18, 8), "Panchina"], [Vector2i(18, 10), "Panchina"],
	[Vector2i(10, 3), "Lavagna"], [Vector2i(4, 4), "Orto"],
	[Vector2i(13, 3), "Panchina"], [Vector2i(2, 6), "Cespuglio"],
]

var _arm := "senza"
var _minuti := 3.0
var _seme := 4242
var _modello := ""
var _fuori := ""

var _vis: Node = null
var _build: Node = null
var _dn: Node = null
var _cuore: Object = null
var _llm: Object = null
var _pens: RefCounted = null
var _residenti: Array = []
var _righe := PackedStringArray()
var _gia_dette: Array = []
var _consegne := 0
var _deduzioni_incassate := 0
var _dedu_muti := 0
var _delta_visti := {}
var _t_frame := PackedFloat64Array()
var _t_ultimo := 0


func _init() -> void:
	_go()


func _leggi_ambiente() -> void:
	if OS.get_environment("CHIBI_ARM") != "":
		_arm = OS.get_environment("CHIBI_ARM")
	if OS.get_environment("CHIBI_MINUTI") != "":
		_minuti = float(OS.get_environment("CHIBI_MINUTI"))
	if OS.get_environment("CHIBI_SEME") != "":
		_seme = int(OS.get_environment("CHIBI_SEME"))
	_modello = OS.get_environment("CHIBI_MODELLO")
	_fuori = OS.get_environment("CHIBI_TRACCIA")


func _go() -> void:
	_leggi_ambiente()
	print("=== BRACCIO «%s» · %d vicini · %.1f minuti di gioco · seme %d ==="
			% [_arm, VICINI, _minuti, _seme])
	print("    cuore che scrive nel binario: %s" % str(LLM.disponibile()))

	# ⚠️ IL DADO GLOBALE SI SEMINA PRIMA CHE IL MONDO NASCA, e questa riga da
	# sola vale metà del banco. Godot mescola il dado globale a ogni avvio;
	# `CozyWorld` costruisce il villaggio con dadi SUOI (tutti seminati: 77,
	# 4242, 88, 7, 99, 33, 505, 71…) ma qua e là chiede anche al globale, e
	# lì il mondo cambia da un avvio all'altro. Si vede contando i nodi: 2194,
	# 2196, 2197, 2198… ed è la variabilità che CLAUDE.md dichiara da sempre
	# («la generazione del mondo NON è deterministica nel numero di nodi»).
	# Con questa riga il conto è lo stesso a ogni corsa, e il palcoscenico dei
	# due bracci è davvero lo stesso palcoscenico.
	seed(_seme)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 10:
		await process_frame
	var livello := current_scene
	if livello == null:
		print("GUASTO: il MainLevel non si è caricato")
		quit(1)
		return
	_build = livello.get_node_or_null("BuildSystem")
	_vis = livello.get_node_or_null("Visitors")
	_dn = livello.get_node_or_null("DayNight")
	if _build == null or _vis == null:
		print("GUASTO: BuildSystem=%s Visitors=%s" % [_build, _vis])
		quit(1)
		return
	# ⚠️ LA PERSISTENZA SI SPEGNE PRIMA DI TOCCARE UNA CELLA: senza, questo
	# banco scriverebbe il `village.json` VERO di chi sta giocando.
	_build.call("set_persist_for_debug", false)
	for _i in 40:
		await process_frame

	print("  NODI dopo il mondo: %d" % get_root().get_tree().get_node_count())
	_costruisci_villaggio()
	print("  NODI dopo il villaggio: %d" % get_root().get_tree().get_node_count())

	# ⚠️ L'ORDINE DI QUESTE QUATTRO RIGHE È IL BANCO, e ognuna è costata una
	# corsa buttata.
	#
	# 1. **IL MOTORE SI ACCENDE PRIMA CHE NASCANO I VICINI.** Aprire un
	#    modello vuol dire secondi di frame che girano mentre un thread mappa
	#    due gigabyte, e quei secondi non durano uguali due volte. Se in mezzo
	#    ci fosse anche un solo vicino, la sua vita in quei secondi sarebbe
	#    diversa nei due bracci — e la differenza si leggerebbe come «effetto
	#    dell'LLM» quando è soltanto il disco. Prima del carico, in scena,
	#    c'è solo il mondo.
	# 2. **I DADI SI SEMINANO PRIMA DELL'INSEDIAMENTO**, perché insediarsi
	#    tira dadi (la casa, la valigia, la prima andatura).
	# 3. **L'INSEDIAMENTO CREA LE ENTITÀ ECS**, e un'entità appena nata ha i
	#    contatori a zero: è la sola forma di stato dell'agenda che non si
	#    può azzerare da fuori. La prima stesura insediava e POI aspettava
	#    trenta frame di risveglio: i contatori dell'agenda arrivavano al via
	#    già sfasati, e due corse partivano con due decisioni diverse in mano.
	# 4. **LA CANONIZZAZIONE** rimette corpi, attese e bisogni dove il banco
	#    dichiara che stanno.
	var f0 := Engine.get_process_frames()
	if not await _accendi_il_cuore():
		return
	var spesi := Engine.get_process_frames() - f0
	while Engine.get_process_frames() - f0 < PAD_CARICO:
		await process_frame
	print("    cuscinetto del carico: %d frame spesi su %d%s"
			% [spesi, PAD_CARICO,
			"" if spesi <= PAD_CARICO else "  ⚠️ SFORATO: braccio non allineato"])

	_semina_i_dadi()
	await _insedia()
	_semina_i_dadi()
	_canonicalizza()
	_dai_ricordi()
	_sonda_di_partenza()
	await _vivi()
	_chiudi()


## LA SONDA DELLA PARTENZA — serve solo a chi ripara questo banco: dice se
## due corse sono partite dallo stesso identico villaggio. Il dado globale si
## legge consumandone uno (uguale in tutte e due le corse, quindi non sposta
## il confronto), il resto è quello che l'agenda guarda per decidere.
func _sonda_di_partenza() -> void:
	if OS.get_environment("CHIBI_SONDA") == "":
		return
	print("  SONDA dado globale: %.9f" % randf())
	print("  SONDA nodi in scena: %d" % get_root().get_tree().get_node_count())
	print("  SONDA orologio del mondo: %.9f" % float(_dn.get("time")) if _dn != null else "")
	for r in _residenti:
		var node := r.get("node") as Node3D
		var b: RefCounted = _vis.call("_ensure_brain", r)
		print("  SONDA %-10s stato=%-10s next_act=%.3f fase=%s az=%d fatti=%d pos=%.3f,%.3f dado=%s %s"
				% [str(r.get("label", "")), str(node.get("_state")),
				float(r.get("next_act", -1.0)), str(r.get("phase", "")),
				int(_cuore.call("azione", int(r["ecs"]))),
				int(_vis.call("_fatti_di", r, node)),
				node.global_position.x, node.global_position.z,
				str((b.get("_rng")).state), _bisogni(b.needs)])


# ------------------------------------------------------------- il villaggio

func _costruisci_villaggio() -> void:
	_vis.call("debug_reset")
	for c in CASE:
		_build.call("place_cell", c, "Letto", 0, false)
		_build.call("place_cell", c, "Tetto", 0, false)
	for a in ARREDO:
		_build.call("place_cell", a[0], a[1], 0, false)
	_build.call("aggiorna_varchi_ora")
	# I MURI: quanti bordi bloccati ha questo villaggio. Serve a leggere il
	# residuo di rumore — `BuildSystem.deviazione` chiede una rotta solo se
	# c'è un muro davanti, e il turno che la concede si misura in microsecondi
	# VERI (`BUDGET_ROTTE_US`). Con zero muri quella valvola non si apre mai e
	# il residuo va cercato altrove.
	print("  MURI nel villaggio: %d bordi bloccati" % int((_build.call("muri") as Dictionary).size()))


func _insedia() -> void:
	for k in VICINI:
		# IL SEME DEL VICINO È FUNZIONE DEL SEME DEL BANCO: cambiando
		# `CHIBI_SEME` cambia il villaggio INTERO, non un vicino solo, e due
		# bracci con lo stesso seme hanno le stesse dodici persone.
		_vis.call("debug_settle", _seme + k * 37, CASE[k])
		# ⚠️ IL DADO DEL CERVELLO SI FISSA QUI, NELLO STESSO FRAME IN CUI IL
		# CERVELLO NASCE, e non dopo. `VillagerBrain.setup` lo semina con
		# l'orologio da polso: se si aspetta anche un solo frame, quel dado ha
		# già tirato — ha già scelto il primo mestiere della giornata — e i
		# due bracci partono con due vicini che hanno fatto due cose diverse.
		# È l'ultima delle cinque sorgenti di rumore che questo banco ha
		# dovuto chiudere, ed è stata anche la più difficile da vedere: si
		# manifestava come otto millimetri di scarto al primo campione.
		_residenti = _vis.get("_residents")
		_semina_cervelli()
		await process_frame
	_residenti = _vis.get("_residents")
	_cuore = _vis.call("cuore")
	print("    insediati %d/%d · cuore ECS: %s"
			% [_residenti.size(), VICINI, "sì" if _cuore != null else "NO"])
	if _cuore == null:
		print("GUASTO: nessun cuore ECS (GDExtension non caricata?)")
		quit(1)


## I DADI, E SONO TRE, non uno. Trovarli è stato metà del lavoro di questo
## banco: la prima stesura ne seminava uno solo e due corse dello stesso
## braccio davano due villaggi diversi — cioè un confronto che non voleva
## dire niente, con la stampa tutta verde.
##
## 1. **il dado GLOBALE** (`randf()` dentro Visitor e Visitors: 52 usi);
## 2. **il dado delle chiacchiere**, che `Visitors._ready` mescola apposta
##    («in partita le chiacchiere non si ripetono uguali»);
## 3. ⚠️ **il dado del CERVELLO, che nasce dall'orologio da polso.**
##    [VillagerBrain.gd:105](../scenes/npc/VillagerBrain.gd) fa
##    `_rng.seed = hash(nome) + Time.get_ticks_msec() % 1000`, e da quel dado
##    esce `jitter()` — cioè il **dado congelato dell'agenda**, quello che in
##    Fase 2 decide fra due azioni quasi pari. In partita è una scelta giusta
##    (due sessioni non si somigliano); su un banco appaiato vuol dire che
##    ogni corsa gioca una partita diversa, e che l'unico modo di far
##    coincidere due tracce sarebbe la fortuna. Qui si rimette al nome, e da
##    lì in poi due corse sono la stessa vita.
func _semina_i_dadi() -> void:
	seed(_seme)
	var cr = _vis.get("_chat_rng")
	if cr != null:
		cr.seed = _seme
		cr.state = _seme
	_semina_cervelli()


## I DADI DEI CERVELLI, una volta sola per cervello: riseminarne uno che ha
## già tirato lo rimanderebbe indietro nel tempo, e sarebbe ripetibile ma
## falso. Il registro `_seminati` è la memoria di chi è già passato di qui.
var _seminati := {}

func _semina_cervelli() -> void:
	for r in (_residenti if _residenti != null else []):
		var etichetta := str(r.get("label", ""))
		if _seminati.has(etichetta):
			continue
		var b: RefCounted = _vis.call("_ensure_brain", r)
		var d = b.get("_rng")
		if d == null:
			continue
		d.seed = hash(etichetta + str(_seme))
		d.state = d.seed
		_seminati[etichetta] = true


## LA PARTENZA CANONICA. Fra l'insediamento e il primo campione passano una
## cinquantina di frame in cui il villaggio si sveglia: qualcuno è già in
## cammino verso un posto scelto a caso, qualcun altro ha un'attesa a metà.
## Quel mezzo secondo NON è ripetibile (il mondo intorno tira i suoi dadi e
## ne tira un numero diverso ogni volta), e senza questa funzione due corse
## partono da due villaggi leggermente diversi — che è esattamente il modo
## in cui un confronto appaiato smette di voler dire qualcosa.
##
## Si rimettono i corpi davanti a casa, si azzera l'attesa dell'agenda, e si
## torna in `r_idle`. Da qui in poi tutto quello che succede dipende solo dai
## dadi appena seminati e dai bisogni, che sono già identici.
func _canonicalizza() -> void:
	for i in _residenti.size():
		var r: Dictionary = _residenti[i]
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var c: Vector2i = r.get("cell", Vector2i.ZERO)
		node.position = Vector3(float(c.x), 0.0, float(c.y) + 1.0)
		node.call("_enter_state", "r_idle")
		r["next_act"] = 0.0
		r["saziato"] = false
		r.erase("fatti")
		r.erase("fatti_scad")
		# ⚠️ E LA FINESTRA DELLE CHIACCHIERE, che è un premio in sospeso:
		# [Visitors.gd:424](../scenes/npc/Visitors.gd) regala due decimi di
		# compagnia a chi aveva provato a chiacchierare quando il lease
		# scade. Chi arriva al via con quella bandiera alzata incassa un
		# premio che l'altro braccio non incassa — e da lì in poi ha un
		# bisogno diverso, cioè un'altra vita.
		r["chiacchiere_in_corso"] = false
		r["phase"] = str(_vis.call("_phase"))
		# ⚠️ ANCHE I BISOGNI, e la ragione è una CHIACCHIERATA. Nei frame di
		# risveglio due vicini possono incontrarsi, e una chiacchierata alza
		# la compagnia di due decimi: da lì in poi quel vicino ha un'altra
		# vita. Succedeva in UNA corsa su due — perché `Visitors._chats`
		# misura il riposo delle coppie con `Time.get_ticks_msec()`, cioè
		# **col tempo vero**, che su un banco che corre più veloce del reale
		# non ha niente a che fare col tempo del gioco (vedi la trappola 3).
		# I bisogni si dichiarano qui, sparsi ma ripetibili.
		var b: RefCounted = _vis.call("_ensure_brain", r)
		var h := absi(hash(str(r.get("label", "")) + str(_seme)))
		b.needs = {
			"pancino": 0.45 + float(h % 41) / 100.0,
			"energia": 0.50 + float((h / 41) % 46) / 100.0,
			"compagnia": 0.35 + float((h / 1681) % 51) / 100.0,
			"meraviglia": 0.30 + float((h / 68921) % 56) / 100.0,
			"cura": 0.40 + float((h / 2825761) % 51) / 100.0,
		}
		# ⚠️ E L'ENTITÀ ECS SI RIFÀ, che è la riga più importante di tutte.
		# La decisione dell'agenda è già stata presa durante l'insediamento,
		# e presa col dado del cervello — che nasce dall'orologio da polso
		# ([VillagerBrain.gd:105](../scenes/npc/VillagerBrain.gd)). Rimettere
		# a posto i bisogni non la cancella: il registro tiene la sua scelta
		# per almeno `T_MIN`, quindi due corse partivano con due azioni
		# diverse in mano **con tutto il resto identico** (bisogni, fatti,
		# dado, posizione, orologio del mondo: verificato campo per campo
		# con `CHIBI_SONDA=1`). Si dimentica e si registra di nuovo, con la
		# stessa coppia di chiamate del villaggio vero: l'entità nasce senza
		# azione e la sceglie al primo frame, coi dadi appena seminati.
		_vis.call("_dimentica_ecs", r)
		_vis.call("_ecs_id", r)
	# e il riposo delle coppie riparte da zero, così la prima chiacchierata
	# non dipende da quanto ci ha messo la macchina ad arrivare fin qui
	var cd = _vis.get("_pair_cd")
	if cd != null:
		cd.clear()
	_vis.set("_chat_acc", 3.5)


## SI DÀ LORO QUALCOSA DA RACCONTARE, e si fa **in tutti i bracci**, anche in
## quelli che non hanno nessun modello. Due ragioni, e la seconda è la più
## importante:
##
## 1. senza ricordi il ritratto è vuoto, il foglio è vuoto, e il Pensatoio
##    mette tutti a riposo per cinque minuti: il braccio col modello non
##    genererebbe MAI e la prova sarebbe una recita;
## 2. il grafo dei ricordi cambia il gioco anche da solo (una promozione al
##    giorno diventa un ricordo del cervello, e i ricordi finiscono nelle
##    chiacchiere): se lo si desse solo al braccio col modello, la
##    differenza fra i due bracci sarebbe **questa**, e la si leggerebbe
##    come colpa dell'LLM.
##
## Si incide con la stessa chiamata del gioco (`EcsMondo.osserva`), mai
## scrivendo nel grafo da fuori: un banco che si costruisce lo stato a mano
## prova il banco.
func _dai_ricordi() -> void:
	var verbi := ["annaffia", "semina", "raccoglie", "costruisce", "taglia", "pesca", "cucina"]
	for k in _residenti.size():
		# un terzo del villaggio non ha visto niente, e tacerà: il caso in
		# cui il Pensatoio fa un giro a vuoto è il caso NORMALE, e un banco
		# in cui tutti hanno sempre qualcosa da dire misura il caso facile
		if k % 3 == 2:
			continue
		var r: Dictionary = _residenti[k]
		if not r.has("ecs"):
			continue
		var id := int(r["ecs"])
		for j in (1 + k % 4):
			var v := str(verbi[(k + j) % verbi.size()])
			_cuore.call("osserva", id, _cuore.call("indice_verbo", v),
					Vector3(float(k) - 12.0, 0.0, float(j) * 4.0), -1)


# ------------------------------------------------------------- il cuore che scrive

## IL MOTORE SORDO: accetta e non risponde mai. Quindici righe, nessun
## thread, nessun core mangiato — quel che resta è ESATTAMENTE il
## comportamento del gioco quando un pensiero non torna.
class MotoreSordo extends RefCounted:
	var _b := 0
	var accodati := 0
	func libero() -> bool:
		return true
	func accoda(_chi: int, _sistema: String, _utente: String, _gram: String,
			_opz: Dictionary) -> int:
		accodati += 1
		_b += 1
		return _b
	func raccogli() -> Dictionary:
		return {}
	func annulla() -> void:
		pass
	func chiudi() -> void:
		pass


func _accendi_il_cuore() -> bool:
	if _arm == "senza":
		return true
	if _arm == "sordo":
		# ⚠️ IL MOTORE SORDO DICE SEMPRE `libero()`, e non è una svista: è il
		# caso peggiore per il Pensatoio, quello in cui a ogni giro si
		# costruisce un foglio VERO (il costo che il gioco paga sul frame
		# principale) e non torna mai niente.
		var finto := MotoreSordo.new()
		_pens = PENSATOIO.new()
		_pens.collega(finto, _fonte, _foglio, _consegna)
		return true
	_llm = LLM.apri()
	if _llm == null:
		print("GUASTO: il braccio «%s» vuole un binario con llama.cpp (scons llm=yes)" % _arm)
		quit(1)
		return false
	# LE OPZIONI DEL GUINZAGLIO. `lento` e `mai` non usano un modello
	# diverso: usano lo STESSO modello messo nelle condizioni peggiori che il
	# ponte permette di chiedere — un thread solo, la priorità di fondo, e
	# tante copie. Un banco che simulasse la lentezza con un `sleep` finto
	# proverebbe il `sleep`.
	var opz := {"n_ctx": 1024}
	match _arm:
		"lento", "mai":
			opz["n_thread"] = 1
			opz["priorita"] = 2
	var percorso := _modello
	if _arm == "assente":
		percorso = "/percorso/che/non/esiste/mai.gguf"
	if percorso == "":
		print("GUASTO: il braccio «%s» vuole CHIBI_MODELLO" % _arm)
		quit(1)
		return false
	var t0 := Time.get_ticks_msec()
	var ammesso := bool(_llm.call("apri_modello", percorso, opz))
	print("    apri_modello(%s) → %s" % [percorso.get_file(), str(ammesso)])
	# SI ASPETTA CHE IL CARICAMENTO FINISCA, ma il gioco NO: durante l'attesa
	# i frame girano, ed è esattamente quello che succede in partita.
	while int(_llm.call("stato")) == 1:
		await process_frame
	var st := int(_llm.call("stato"))
	print("    stato dopo %d ms: %s · %s" % [Time.get_ticks_msec() - t0,
			["SPENTO", "CARICA", "PRONTO", "PENSA", "GUASTO"][st],
			str((_llm.call("misure") as Dictionary).get("diagnosi", ""))])
	if _llm.has_method("memoria"):
		var mm: Dictionary = _llm.call("memoria")
		print("    memoria del processo: impronta %.0f MB · residente %.0f MB"
				% [float(mm.get("impronta", 0)) / 1048576.0,
				float(mm.get("residente", 0)) / 1048576.0])
	# ⚠️ E ADESSO LA COSA CHE CONTA: il Pensatoio si collega COMUNQUE, anche
	# se il modello non si è aperto. È il cablaggio che avrà il gioco vero, e
	# provarlo solo nel caso buono vorrebbe dire non provare mai il caso del
	# giocatore normale — che è quello senza modello.
	_pens = PENSATOIO.new()
	_pens.collega(_llm, _fonte, _foglio, _consegna)
	return true


## LA FONTE — chi può ricevere un pensiero adesso. Nel gioco vero sarà
## `Visitors`; qui è la stessa lista, letta dallo stesso posto.
func _fonte() -> Array:
	var out := []
	for r in _residenti:
		if (r as Dictionary).has("ecs"):
			out.append({"chi": int(r["ecs"]), "id": str(r.get("label", "")), "r": r})
	return out


## IL FOGLIO — metà lettera e metà deduzione, alternate. Le lettere sono
## quello che il giocatore LEGGE, le deduzioni quello che il villaggio FA:
## un banco che provasse solo le prime lascerebbe fuori l'unica metà che può
## muovere un corpo.
func _foglio(c) -> Dictionary:
	var r: Dictionary = (c as Dictionary)["r"]
	var seme := hash(str(c.get("id", ""))) & 0x7FFFFFFF
	if _consegne % 2 == 0:
		return FOGLIO.foglio_deduzione(_vis, _dn, _cuore, r, "Mochi", seme)
	return FOGLIO.foglio(_vis, _dn, _cuore, r, "lettera", "Mochi", seme)


## LA CONSEGNA — la catena intera: bozze → Giudice → (lettera | deduzione).
## Le bozze arrivano GREZZE (è la regola del Pensatoio), e nessuna arriva a
## schermo senza essere passata da qui.
func _consegna(c, bozze: PackedStringArray, foglio: Dictionary) -> void:
	_consegne += 1
	var rit: Dictionary = foglio.get("ritratto", {})
	if rit.is_empty():
		return
	if str(rit.get("compito", "")) == "pensiero":
		# ⚠️ LE BOZZE DELLA DEDUZIONE SONO JSON, e vanno APERTE prima di
		# giudicarle: il Giudice vuole Dictionary. Passargli le stringhe
		# grezze non dà un errore — dà zero deduzioni per sempre, cioè la
		# forma di guasto che questa fase teme di più.
		var mondo := {"fattibili": rit.get("fattibili", [])}
		var esito: Dictionary = DEDUZIONI.incassa(_cuore, int(c.get("chi", -1)),
				DEDUZIONI.bozze_da(Array(bozze)), rit, mondo, 0.35)
		if int(esito.get("indice", -1)) >= 0:
			_deduzioni_incassate += 1
		else:
			_dedu_muti += 1
		return
	var v: Dictionary = GIUDICE.scegli(Array(bozze), rit, {"sue": _gia_dette})
	if int(v["scelta"]) >= 0:
		_gia_dette.append(str(v["testo"]))


# ------------------------------------------------------------------ la vita

func _vivi() -> void:
	var frame_totali := int(_minuti * 60.0 * 60.0)
	var t_muro := Time.get_ticks_msec()
	_t_ultimo = Time.get_ticks_usec()
	for f in frame_totali:
		await process_frame
		var ora := Time.get_ticks_usec()
		_t_frame.append(float(ora - _t_ultimo) / 1000.0)
		_t_ultimo = ora
		# IL PASSO DEL PENSATOIO col delta VERO del gioco (in headless è
		# fisso: è la ragione per cui questo banco è headless).
		var d := get_root().get_process_delta_time()
		_delta_visti[d] = int(_delta_visti.get(d, 0)) + 1
		if _pens != null:
			_pens.passo(d)
		if f % OGNI == 0:
			_campiona(float(f) / 60.0)
	print("    %d frame in %.1f s di tempo vero" % [frame_totali,
			float(Time.get_ticks_msec() - t_muro) / 1000.0])


## UN CAMPIONE. Una riga per vicino, e dentro c'è tutto quello che «cosa ha
## fatto» può voler dire: dove sta il corpo, in che stato è, quale azione gli
## ha scelto l'agenda, e i cinque bisogni che scorrono sotto tutto il resto.
func _campiona(t: float) -> void:
	for i in _residenti.size():
		var r: Dictionary = _residenti[i]
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			_righe.append("%7.2f %-10s SPARITO" % [t, str(r.get("label", "?"))])
			continue
		var az := -1
		if _cuore != null and r.has("ecs"):
			az = int(_cuore.call("azione", int(r["ecs"])))
		var p: Vector3 = node.global_position
		var b: RefCounted = _vis.call("_ensure_brain", r)
		var n: Dictionary = b.needs
		_righe.append("%7.2f %-10s %-12s az=%2d %8.3f %8.3f %8.3f  %s"
				% [t, str(r.get("label", "?")), str(node.get("_state")), az,
				p.x, p.y, p.z, _bisogni(n)])


func _bisogni(n: Dictionary) -> String:
	var chiavi := n.keys()
	chiavi.sort()
	var out := []
	for k in chiavi:
		out.append("%s=%.5f" % [str(k), float(n[k])])
	return " ".join(out)


# ---------------------------------------------------------------- la chiusura

func _chiudi() -> void:
	# ⚠️ IL SALVATAGGIO, e va fatto QUI: «il gioco parte, gioca, SALVA». Un
	# motore che tenesse il gioco in ostaggio si vedrebbe proprio in questa
	# riga — è l'unica che scrive su disco. (La persistenza vera è spenta:
	# si chiede il salvataggio su un file di prova.)
	var t0 := Time.get_ticks_usec()
	var extra: Dictionary = _vis.call("save_extra")
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	# ⚠️ IL SALVATAGGIO SI CONFRONTA, non si guarda soltanto. La Fase 5 ha una
	# regola dichiarata — «il grafo dei ricordi non si salva, l'emozione dura
	# minuti e non lascia traccia» — e una deduzione che finisse dentro
	# `village.json` la romperebbe **in silenzio**: nessun errore, nessun
	# test rosso, e i salvataggi di chi ha il modello diversi da quelli di
	# chi non ce l'ha. L'impronta del salvataggio è la guardia.
	var salva := JSON.stringify(extra, "\t", true, true)
	var imp_save := salva.sha256_text()
	if _fuori != "":
		var fs := FileAccess.open(_fuori + ".salvataggio.json", FileAccess.WRITE)
		if fs != null:
			fs.store_string(salva)
			fs.close()
	print("    save_extra(): %d residenti · %d byte · impronta %s · %.2f ms" % [
			int((extra.get("residents", []) as Array).size()), salva.length(),
			imp_save.substr(0, 16), ms])
	# e il salvataggio VERO, quello che scrive su disco: con la persistenza
	# spenta non scrive niente, ma il cammino si percorre lo stesso — è la
	# riga in cui un motore che tenesse il gioco in ostaggio si vedrebbe.
	var t_save := Time.get_ticks_usec()
	if _build.has_method("save_now"):
		_build.call("save_now")
	var ms_save := float(Time.get_ticks_usec() - t_save) / 1000.0

	# LO SPEGNIMENTO col pensiero in volo: è il cambio di scena, ed è il
	# posto in cui un `annulla()` scritto male costa un secondo di gelo.
	var t1 := Time.get_ticks_usec()
	if _pens != null:
		_pens.svuota()
	var ms_annulla := float(Time.get_ticks_usec() - t1) / 1000.0

	var t2 := Time.get_ticks_usec()
	if _llm != null:
		_llm.call("chiudi")
	var ms_chiudi := float(Time.get_ticks_usec() - t2) / 1000.0

	# --- la traccia
	var testo := "\n".join(_righe) + "\n"
	var impronta := testo.sha256_text()
	if _fuori != "":
		var f := FileAccess.open(_fuori, FileAccess.WRITE)
		if f != null:
			f.store_string(testo)
			f.close()
	print("\n--- ESITO del braccio «%s» ---" % _arm)
	print("  traccia: %d righe · impronta %s" % [_righe.size(), impronta])
	# ⚠️ IL PASSO DEL TEMPO, e va STAMPATO: `--headless` NON basta a fissarlo
	# (quella riga dell'aiuto parla di `--write-movie`), serve `--fixed-fps
	# 60`. Senza, i delta sono quelli veri — decine di valori diversi — e due
	# corse dello stesso braccio non possono essere identiche nemmeno se il
	# codice è lo stesso. Se questa riga dice più di UN delta, il confronto
	# fra bracci non vale niente e va rifatto.
	var passi := _delta_visti.keys()
	passi.sort()
	print("  passo del tempo: %d valore/i distinto/i %s" % [passi.size(),
			str(passi.slice(0, 4)) + ("…" if passi.size() > 4 else "")])
	print("  frame: %s" % _statistica())
	if _pens != null:
		var m: Dictionary = _pens.misure()
		print("  pensatoio: consegnati %d · buttati %d · muti %d · persi %d · in volo %s"
				% [int(m["consegnati"]), int(m["buttati"]), int(m["muti"]),
				int(m["persi"]), str(m["in_volo"])])
		print("             foglio %.2f ms (peggiore %.2f) · ultimo errore: «%s»"
				% [float(m["foglio_ms"]), float(m["foglio_ms_peggio"]), str(m["errore"])])
		print("             ultimo esito: %s" % str(m["ultimo"]))
	print("  consegne %d · deduzioni incassate %d · deduzioni mute %d · lettere scelte %d"
			% [_consegne, _deduzioni_incassate, _dedu_muti, _gia_dette.size()])
	print("  save_now() %.2f ms · annulla() %.3f ms · chiudi() %.1f ms"
			% [ms_save, ms_annulla, ms_chiudi])
	print("IMPRONTA %s" % impronta)
	print("IMPRONTA_SALVATAGGIO %s" % imp_save)
	quit(0)


func _statistica() -> String:
	var v := Array(_t_frame)
	v.sort()
	if v.is_empty():
		return "(nessun campione)"
	var somma := 0.0
	for x in v:
		somma += float(x)
	var p50 := float(v[int(v.size() * 0.5)])
	var doppi := 0
	for x in v:
		if float(x) > p50 * 2.0:
			doppi += 1
	return "n=%d medio %.2f p50 %.2f p99 %.2f MAX %.2f >2×p50: %d" % [
			v.size(), somma / float(v.size()), p50,
			float(v[mini(int(v.size() * 0.99), v.size() - 1)]),
			float(v[v.size() - 1]), doppi]
