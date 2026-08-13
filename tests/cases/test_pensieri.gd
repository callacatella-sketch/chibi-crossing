extends RefCounted
## IL CABLAGGIO IN PARTITA — il nodo che possiede il ritmo, e il giro chiuso.
##
## `Pensatoio` sa fare la fila e `Deduzioni` sa incassare: erano provati tutti
## e due, e non li chiamava nessuno. Questo file prova il pezzo che mancava —
## il nodo che sta in `MainLevel.tscn`, sceglie un vicino, monta il foglio,
## accoda, e porta l'esito fino al grafo.
##
## ────────────────────────────────────────────────────────────────────────
## LE DUE DOMANDE, e la prima vale più della seconda
## ────────────────────────────────────────────────────────────────────────
##
## 1. **SENZA MODELLO NON SUCCEDE NIENTE.** Non «quasi niente». Il nodo
##    dev'essere indistinguibile da un nodo vuoto: `_process` spento (che nel
##    motore vuol dire NON CHIAMATO, non «chiamato e torna subito»), nessun
##    ponte aperto, nessun Pensatoio allocato, nessuna riga stampata. È il
##    vincolo dell'autore, ed è l'unico che sta sopra tutti gli altri.
## 2. **E con il modello, il giro si chiude davvero**: dalle bozze grezze al
##    nodo nel grafo, passando dal Giudice.
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ QUI DENTRO C'È UN PONTE FINTO
## ────────────────────────────────────────────────────────────────────────
##
## La classe nativa che scrive **non esiste nel binario normale** (`llm=no`,
## quello che gira in CI e quello che gioca la gente). Un test che la
## pretendesse proverebbe l'unica configurazione che nessun giocatore ha, e
## sul binario di tutti resterebbe verde senza aver eseguito una riga. Perciò
## il nodo ha due giunture — `_si_accende()` e `_apri_ponte()` — che di serie
## rispondono `systems/Llm.gd` e qui rispondono il banco: **la stessa
## disciplina per cui il `Pensatoio` si fa iniettare il motore**, e per la
## stessa ragione già pagata tre volte in questo progetto (una guardia che
## nessun test può far diventare rossa è una guardia che non c'è).
##
## Il finto non semplifica: risponde alle stesse domande del vero
## (`apri_modello`/`stato`/`libero`/`accoda`/`raccogli`/`annulla`) con la
## stessa disciplina — biglietto crescente, 0 = rifiutato, `{}` = niente da
## ritirare, e `annulla()` che libera solo se il lavoro era ancora in coda.
## Tutto il resto è VERO: `EcsMondo` in C++, il grafo vero, il Suggeritore
## vero, il Giudice vero, `Deduzioni.incassa` vera.
##
## ⚠️ E LA PORTA VERA NON RESTA SCOPERTA: `_la_porta_e_llm_e_basta` pretende
## che il ripiego di `_si_accende()` sia esattamente `Llm.acceso()`, e prova
## le tre condizioni di quella porta una per una.

const PENSIERI := preload("res://scenes/npc/Pensieri.gd")
const LLM := preload("res://systems/Llm.gd")
const SUG := preload("res://scenes/npc/Suggeritore.gd")
const PIANI := preload("res://scenes/npc/Piani.gd")
const BRAIN := preload("res://scenes/npc/VillagerBrain.gd")

## ⚠️ OGNI CASO PULISCE IL SUO VILLAGGIO, e non è pignoleria: il runner
## libera i nodi messi in scena a fine FILE, non a fine caso. Due registri
## nello stesso gruppo «visitors» vorrebbero dire che il caso dopo si aggancia
## a quello del caso prima — col suo `EcsMondo` già liberato, che in GDScript
## è un errore a runtime, e **un errore a runtime non fa fallire un test: lo
## interrompe a metà lasciando la suite verde**.
var _sporco: Array = []

const CICLO := 240.0
## `Visitors.AMMIRA_SOGLIA`: sotto questo peso un ricordo non conta più.
const SOGLIA := 0.35


# =========================================================================
# IL BANCO
# =========================================================================

## IL PONTE FINTO — le sette domande che il nodo e il Pensatoio gli fanno.
class Ponte extends RefCounted:
	var stato_ := 2          # 0 SPENTO · 1 CARICA · 2 PRONTO · 3 PENSA · 4 GUASTO
	var accetta_modello := true
	var chiamate := 0        # quante volte gli è stato chiesto di aprire
	var aperto := ""
	var opzioni_modello := {}
	var occupato := false
	var preso := false
	var biglietto := 0
	var accodate: Array = []
	var annullamenti := 0
	var _pronti: Array = []

	func apri_modello(percorso: String, opz: Dictionary) -> bool:
		chiamate += 1
		aperto = percorso
		opzioni_modello = opz
		if not accetta_modello:
			stato_ = 4
			return false
		return true

	func stato() -> int:
		return stato_

	func misure() -> Dictionary:
		return {"diagnosi": "il finto ha detto di no"}

	func libero() -> bool:
		return stato_ == 2 and not occupato

	func accoda(chi: int, sistema: String, utente: String, gramm: String,
			opz: Dictionary) -> int:
		if not libero() or gramm == "" or utente == "":
			return 0
		biglietto += 1
		occupato = true
		preso = false
		accodate.append({"chi": chi, "sistema": sistema, "utente": utente,
				"gramm": gramm, "opz": opz, "biglietto": biglietto})
		return biglietto

	func raccogli() -> Dictionary:
		if _pronti.is_empty():
			return {}
		return _pronti.pop_front()

	func annulla() -> void:
		annullamenti += 1
		_pronti.clear()
		if not preso:
			occupato = false

	func finisci(b: int, bozze: PackedStringArray) -> void:
		occupato = false
		preso = false
		_pronti.append({"biglietto": b, "chi": 1, "bozze": bozze,
				"secondi_prompt": 0.4, "secondi_generazione": 3.0,
				"token_prompt": 650, "token_generati": 50, "errore": ""})


## IL REGISTRO FINTO — quel poco di `Visitors` che il foglio interroga.
## `Visitors.gd` non si istanzia in headless (il suo `_ready` vuole `%Player`
## e `../BuildSystem`), ed è la stessa ragione per cui `Percezione.puo_vedere`
## sta fuori da lui.
class Registro extends Node:
	var _residents: Array = []
	var cuore_: Object = null
	var fattibili: Array = []
	var _cervelli := {}

	func _ready() -> void:
		add_to_group("visitors")

	func cuore() -> Object:
		return cuore_

	func obiettivi_fattibili(_r: Dictionary) -> Array:
		return fattibili

	func _ensure_brain(r: Dictionary):
		var k := str(r.get("label", ""))
		if not _cervelli.has(k):
			var b = (load("res://scenes/npc/VillagerBrain.gd") as GDScript).new()
			b.indole = ["goloso"]
			b.quirk = ""
			_cervelli[k] = b
		return _cervelli[k]


## UN CORPO che sa rispondere alle domande della candidatura.
class Corpo extends Node3D:
	var nascosto := false

	func is_hidden() -> bool:
		return nascosto

	func dorme() -> bool:
		return false

	func in_scena() -> bool:
		return false


## IL NODO, con le due giunture in mano al banco. Tutto il resto — il
## cablaggio, l'apertura, il ritmo, la consegna — è il codice di produzione.
class Banco extends "res://scenes/npc/Pensieri.gd":
	var ponte: Ponte = null
	var accendi := true

	func _si_accende() -> bool:
		return accendi

	func _apri_ponte() -> Object:
		return ponte


func run(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return

	_senza_modello_non_succede_niente(t)
	_la_porta_e_llm_e_basta(t)
	_il_nodo_e_nel_livello(t)
	_il_cablaggio_si_riprova(t)
	_il_modello_si_apre_solo_se_c_e_qualcuno(t)
	_un_modello_che_non_si_apre_spegne_e_non_urla(t)
	_chi_e_dentro_casa_non_e_candidato(t)
	_il_giro_si_chiude(t)
	_gia_dedotto_si_riempie(t)
	_il_seme_non_si_ripete(t)
	_uscire_dall_albero_butta_il_volo(t)


# =========================================================================
# 1. SENZA MODELLO NON SUCCEDE NIENTE
# =========================================================================

## IL NODO VERO — non il `Banco` — messo in scena com'è nel livello.
##
## Le tre asserzioni sono tre cose diverse, e servono tutte e tre: `_process`
## spento vuol dire che il motore non lo chiama affatto (costo per fotogramma
## ZERO, non «piccolo»); nessun Pensatoio vuol dire che non è stato allocato
## niente; e lo stato "spento" è l'unico in cui questo file non tocca il
## mondo.
##
## FALSIFICATO in tre modi, uno per riga: togliendo `set_process(false)` dal
## `_ready` (la prima diventa rossa), togliendo il `return` dopo di lui (il
## nodo va in "attesa" e la terza diventa rossa), e portando la porta da
## `acceso()` a `disponibile()` — che sul binario con llama.cpp fa svegliare
## il nodo di TUTTI i giocatori che non hanno i pesi, e rende rosse la prima
## e la terza.
func _senza_modello_non_succede_niente(t) -> void:
	var vecchio := OS.get_environment("CHIBI_MODELLO")
	OS.set_environment("CHIBI_MODELLO", "")
	var n = _metti(t, PENSIERI.new())
	var m: Dictionary = n.misure()
	t.ok(not n.is_processing(), "senza modello il nodo non ha nemmeno un _process")
	t.eq(bool(m["acceso"]), false, "senza modello non c'è nessun ritmo allocato")
	t.eq(str(m["stato"]), "spento", "senza modello lo stato è «spento»")
	t.ok(not m.has("ritmo"), "senza modello il Pensatoio non è mai nato")
	# e un passo di _process, se qualcuno lo chiamasse a mano, non deve
	# comunque svegliare niente: la porta è nel `_ready`, ma il ramo di
	# `_process` senza Pensatoio non deve poter aprire un ponte da solo.
	n._process(1.0)
	t.eq(str((n.misure() as Dictionary)["stato"]), "spento",
			"nemmeno un _process forzato accende qualcosa")
	OS.set_environment("CHIBI_MODELLO", vecchio)
	_pulisci(null)


## LA PORTA HA UNA CASA SOLA, E LE SUE TRE CONDIZIONI SI PROVANO UNA PER UNA.
##
## Questa è la controprova del caso di sopra: là si guarda il nodo spento, qui
## si guarda **perché** è spento, sulla funzione vera. Senza, «senza modello
## non succede niente» sarebbe verde anche se `acceso()` rispondesse sempre
## no — cioè su un gioco in cui la Fase 5 non si accende mai.
##
## FALSIFICATO: togliendo `percorso_modello() != ""` da `Llm.acceso()` (la
## seconda riga diventa rossa), togliendo `spento_da_chi_gioca()` (la terza),
## e togliendo la giuntura `_si_accende()` dal nodo (l'ultima).
func _la_porta_e_llm_e_basta(t) -> void:
	var vecchio := OS.get_environment("CHIBI_MODELLO")
	var finto := "user://finto_pensieri.gguf"
	var f := FileAccess.open(finto, FileAccess.WRITE)
	f.store_string("non è un modello, è un file che esiste")
	f.close()
	var vero := ProjectSettings.globalize_path(finto)

	OS.set_environment("CHIBI_MODELLO", "")
	t.eq(LLM.acceso(), false, "senza un modello la porta è chiusa")

	OS.set_environment("CHIBI_MODELLO", vero)
	t.eq(LLM.percorso_modello(), vero, "il percorso del modello arriva da Llm.gd")
	# ⚠️ SUL BINARIO SENZA llama.cpp la porta resta chiusa comunque, ed è
	# giusto: `disponibile()` è la prima delle tre condizioni. Le due
	# configurazioni pretendono due cose diverse, e tutte e due sono vere.
	t.eq(LLM.acceso(), LLM.disponibile(),
			"col modello, la porta è aperta esattamente quando il binario sa scrivere")

	# LA LEVA DEL GIOCATORE, dove vivono le sue preferenze.
	var s: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/Settings")
	t.ok(s != null, "l'autoload delle impostazioni c'è")
	if s != null:
		var prima: bool = bool(s.get("llm_spento"))
		s.set("llm_spento", true)
		t.eq(LLM.acceso(), false, "la leva del giocatore chiude la porta col modello presente")
		s.set("llm_spento", prima)

	# E IL RIPIEGO DELLA GIUNTURA È LA PORTA VERA, non un sì scritto a mano.
	var n = _metti(t, PENSIERI.new())
	t.eq(n._si_accende(), LLM.acceso(),
			"la giuntura del nodo risponde esattamente quello che risponde Llm.acceso()")

	OS.set_environment("CHIBI_MODELLO", vecchio)
	DirAccess.remove_absolute(vero)
	_pulisci(null)


## IL NODO STA NEL LIVELLO VERO, accanto a Percezione. Un cablaggio perfetto
## dentro un file che nessuna scena istanzia è esattamente lo stato in cui
## questa fase si trovava prima: tutto provato, niente collegato.
##
## FALSIFICATO togliendo il nodo da `MainLevel.tscn`.
func _il_nodo_e_nel_livello(t) -> void:
	var testo := FileAccess.get_file_as_string("res://scenes/levels/MainLevel.tscn")
	t.ok(testo.contains("res://scenes/npc/Pensieri.gd"),
			"MainLevel carica lo script dei Pensieri")
	t.ok(testo.contains("[node name=\"Pensieri\""),
			"MainLevel ha il nodo Pensieri in scena")


# =========================================================================
# 2. L'ACCENSIONE
# =========================================================================

## Mette in scena e se lo segna. `t.stage` continua a essere il proprietario
## ufficiale (libera quel che resta a fine file): questo aggiunge solo il
## giro di pulizia a fine caso, e `is_instance_valid` fa da rete a tutti e due.
func _metti(t, n: Node) -> Node:
	_sporco.append(t.stage(n))
	return n


func _pulisci(cuore: Object) -> void:
	for n in _sporco:
		if is_instance_valid(n):
			n.free()
	_sporco.clear()
	if cuore != null and is_instance_valid(cuore):
		cuore.free()


func _cuore_vero() -> Object:
	var m = ClassDB.instantiate("EcsMondo")
	m.imposta_ritmo(CICLO)
	return m


## Un villaggio finto con dentro un vicino che ha VISTO qualcosa: i tre gesti
## sono quelli veri (`osserva`), perché è da loro che nasce tutto quello che
## il modello può citare.
func _villaggio(t, cuore: Object, quanti := 1) -> Node:
	var reg := Registro.new()
	reg.cuore_ = cuore
	reg.fattibili = []
	for act in PIANI.OBIETTIVO:
		reg.fattibili.append(str(PIANI.OBIETTIVO[act]))
	_metti(t, reg)
	for k in quanti:
		var id := int(cuore.registra(PackedStringArray(["goloso"]), ""))
		var corpo := Corpo.new()
		corpo.position = Vector3(float(k) * 4.0, 0.0, 0.0)
		_metti(t, corpo)
		# TRE GESTI VERI in tre posti diversi: senza ricordi il foglio è
		# vuoto, e il nodo non accoderebbe niente — cioè il banco proverebbe
		# il silenzio invece del giro.
		cuore.osserva(id, cuore.indice_verbo("annaffia"), Vector3(2, 0, -6), -1)
		cuore.osserva(id, cuore.indice_verbo("costruisce"), Vector3(-5, 0, 3), -1)
		cuore.osserva(id, cuore.indice_verbo("dona"), Vector3(7, 0, 1), -1)
		reg._residents.append({"ecs": id, "node": corpo, "label": "vicino%d" % k,
				"cell": Vector2i(k, 0), "dna": {},
				"luoghi": _luoghi(), "fatti": _fatti(cuore)})
	return reg


func _luoghi() -> Array:
	var out := []
	for i in PIANI.LUOGHI.size():
		out.append({"ok": true, "metri": 3.0, "pos": Vector3(0, 0, -12)})
	return out


func _fatti(cuore: Object) -> int:
	return int(cuore.maschera_fatti(PackedStringArray([
			"spuntino_vicino", "aiuola_da_annaffiare", "amico_in_giro",
			"spuntino_raggiungibile", "aiuola_raggiungibile",
			"seduta_libera_vicina", "meraviglia_raggiungibile", "lavagna_pronta",
			"meraviglia_posto"])))


## IL NODO ACCESO E GIÀ AGGANCIATO: qualche giro di `_process` perché il
## cablaggio trovi il registro e il ponte apra il modello. Non è una scorciatoia
## del banco — è quello che succede in partita nei primi secondi.
func _acceso(t, cuore: Object, quanti := 1) -> Array:
	var reg := _villaggio(t, cuore, quanti)
	var n = Banco.new()
	n.ponte = Ponte.new()
	_metti(t, n)
	for i in 4:
		n._process(1.0)
	return [n, reg, n.ponte]


## IL CABLAGGIO SI RIPROVA. Senza registro non si trova niente, e il nodo non
## deve né arrendersi né esplodere: al giro in cui il villaggio compare, si
## aggancia.
##
## FALSIFICATO facendo cablare `_cabla()` una volta sola (memorizzando un
## `_gia_provato`): il nodo non trova mai il registro e il ponte non riceve
## nessun `apri_modello`, esattamente com'è morto il taccuino del Gufo.
func _il_cablaggio_si_riprova(t) -> void:
	var n = Banco.new()
	n.ponte = Ponte.new()
	_metti(t, n)
	# nessun registro in scena: dieci secondi di tentativi non devono aprire
	# niente e non devono lasciare errori
	for i in 10:
		n._process(1.0)
	t.eq(n.ponte.chiamate, 0, "senza registro non si chiede nessun modello")
	t.eq(str((n.misure() as Dictionary)["stato"]), "attesa",
			"senza registro il nodo aspetta")
	# ...e adesso il villaggio arriva TARDI, come arriva sempre
	var cuore := _cuore_vero()
	_villaggio(t, cuore, 1)
	for i in 4:
		n._process(1.0)
	t.eq(n.ponte.chiamate, 1, "quando il villaggio compare, il nodo si aggancia")
	_pulisci(cuore)


## IL MODELLO SI APRE SOLO SE C'È QUALCUNO CHE PUÒ PENSARE. Due gigabyte e
## mezzo mappati in un villaggio senza abitanti sono due gigabyte e mezzo che
## il giocatore paga per una funzione senza soggetto.
##
## FALSIFICATO spostando `_llm.call("apri_modello", …)` PRIMA del controllo
## `_candidati().is_empty()`: la prima riga diventa rossa.
func _il_modello_si_apre_solo_se_c_e_qualcuno(t) -> void:
	var cuore := _cuore_vero()
	var reg := _villaggio(t, cuore, 0)   # registro vivo, villaggio vuoto
	var n = Banco.new()
	n.ponte = Ponte.new()
	# ⚠️ `CHIBI_RISERVA` acceso APPOSTA, e per un motivo di misura. Più sotto
	# si pretende che le opzioni con cui il modello si apre siano ESATTAMENTE
	# quelle che il nodo dichiara (`opzioni_modello`): in un banco senza
	# modello, però, un dizionario scritto a mano dentro `_avvia` avrebbe gli
	# stessi due campi e l'uguaglianza sarebbe vera per caso. Con la riserva
	# accesa i due dizionari si separano, e l'uguaglianza torna a dire
	# qualcosa. (MISURATO: senza questa riga, un `_avvia` che si costruisce le
	# opzioni da sé — cioè che butta via l'IMPRONTA del modello spedito —
	# lasciava la suite verde.)
	var riserva_prima := OS.get_environment("CHIBI_RISERVA")
	OS.set_environment("CHIBI_RISERVA", "12345")
	_metti(t, n)
	for i in 6:
		n._process(1.0)
	t.eq(n.ponte.chiamate, 0, "senza nessun abitante il modello non si apre")
	# arriva il primo residente
	var id := int(cuore.registra(PackedStringArray(["goloso"]), ""))
	var corpo := Corpo.new()
	_metti(t, corpo)
	reg._residents.append({"ecs": id, "node": corpo, "label": "primo",
			"cell": Vector2i.ZERO, "dna": {}, "luoghi": _luoghi(), "fatti": _fatti(cuore)})
	for i in 4:
		n._process(1.0)
	t.eq(n.ponte.chiamate, 1, "col primo abitante il modello si apre")
	t.eq(int((n.ponte.opzioni_modello as Dictionary).get("n_ctx", 0)), PENSIERI.FINESTRA,
			"si apre con la finestra su cui sono state fatte le misure")
	# E LE OPZIONI SONO QUELLE CHE IL NODO DICHIARA, non un dizionario scritto
	# a mano lì per lì: `opzioni_modello()` porta anche l'IMPRONTA del modello
	# spedito, che è la sola difesa contro un bit girato dentro i pesi. Un
	# `_avvia` che se ne costruisse uno per conto suo la lascerebbe fuori — e
	# la funzione girerebbe senza la sua rete, in silenzio.
	t.eq(n.ponte.opzioni_modello, n.opzioni_modello(str(n.ponte.aperto)),
			"il modello si apre con le opzioni che il nodo stesso dichiara")
	OS.set_environment("CHIBI_RISERVA", riserva_prima)
	_pulisci(cuore)


## UN MODELLO CHE NON SI APRE SPEGNE IL NODO, e non urla. I quattro modi in
## cui un modello può non aprirsi (non c'è, non è sano, sfonda il tetto di
## RAM, la macchina non ha memoria libera) sono tutti e quattro NORMALI: da
## lì in poi il gioco è quello con i testi scritti a mano.
##
## FALSIFICATO togliendo `set_process(false)` da `_ferma()`: il nodo continua
## a girare per sempre riprovando, cioè paga un costo a chi non ha niente da
## guadagnarci.
func _un_modello_che_non_si_apre_spegne_e_non_urla(t) -> void:
	var cuore := _cuore_vero()
	_villaggio(t, cuore, 1)
	var n = Banco.new()
	n.ponte = Ponte.new()
	n.ponte.accetta_modello = false
	_metti(t, n)
	var p: Ponte = n.ponte
	for i in 6:
		n._process(1.0)
	var m: Dictionary = n.misure()
	t.eq(str(m["stato"]), "guasto", "il modello rifiutato spegne il nodo")
	t.ok(not n.is_processing(), "e il nodo smette di costare qualcosa")
	t.eq(bool(m["acceso"]), false, "nessun ritmo è stato acceso")
	_pulisci(cuore)


## CHI È DENTRO CASA NON È CANDIDATO: la sua ricevuta non si potrebbe pagare
## a nessuno (`Percezione.puo_vedere` esclude chi è nascosto), quindi
## spendere su di lui l'unico slot che c'è vuol dire buttarlo.
##
## FALSIFICATO togliendo il controllo `is_hidden()` da `_candidati()`: il
## nodo apre il modello anche in un villaggio in cui sono tutti a letto.
func _chi_e_dentro_casa_non_e_candidato(t) -> void:
	var cuore := _cuore_vero()
	var reg := _villaggio(t, cuore, 2)
	for r in reg._residents:
		(r["node"] as Corpo).nascosto = true
	var n = Banco.new()
	n.ponte = Ponte.new()
	_metti(t, n)
	for i in 6:
		n._process(1.0)
	t.eq(n.ponte.chiamate, 0, "col villaggio tutto dentro casa non si pensa a nessuno")
	(reg._residents[0]["node"] as Corpo).nascosto = false
	for i in 4:
		n._process(1.0)
	t.eq(n.ponte.chiamate, 1, "appena uno esce, torna candidato")
	_pulisci(cuore)


# =========================================================================
# 3. IL GIRO CHIUSO
# =========================================================================

## Fa girare il nodo finché non accoda qualcosa, e restituisce il biglietto.
func _fino_all_accodata(n, p: Ponte, giri := 40) -> int:
	for i in giri:
		n._process(0.6)
		if not p.accodate.is_empty():
			return int((p.accodate[-1] as Dictionary)["biglietto"])
	return 0


## Una bozza JSON come la scriverebbe il modello, con la grammatica vera in
## mano: l'obiettivo è uno dei quattro, i `perche` sono righe vive.
func _bozza(obiettivo: String, righe: Array) -> String:
	return JSON.stringify({"obiettivo": obiettivo, "perche": righe})


## Gli obiettivi che la grammatica di QUEL foglio ha davvero offerto: si
## leggono dalla grammatica vera invece di sceglierne uno a memoria, o il
## banco proverebbe una domanda che il modello non avrebbe mai potuto fare.
func _offerti(gram: String) -> Array:
	var out := []
	# la grammatica GBNF cita i letterali fra virgolette ESCAPED (`\"nome\"`):
	# si cerca il nome e basta, che è quello che serve al banco
	for k in SUG.OBIETTIVI_DETTI:
		if gram.contains(str(k)):
			out.append(str(k))
	return out


## IL GIRO CHIUSO: un vicino → un foglio → un'accodata → delle bozze → un
## nodo nel grafo. È la cosa che nessun pezzo della Fase 5, da solo, poteva
## dimostrare.
##
## FALSIFICATO in due modi: togliendo `DEDUZIONI.incassa(...)` da `_consegna`
## (il grafo resta vuoto), e passando alla `incassa` un ritratto ricostruito
## adesso invece di quello arrivato col foglio (`foglio["ritratto"]`) — che è
## la scorciatoia più naturale del mondo e collauderebbe contro un villaggio
## di qualche secondo dopo.
func _il_giro_si_chiude(t) -> void:
	var cuore := _cuore_vero()
	var b := _acceso(t, cuore, 1)
	var n = b[0]
	var reg: Registro = b[1]
	var p: Ponte = b[2]
	var id := int((reg._residents[0] as Dictionary)["ecs"])

	var bg := _fino_all_accodata(n, p)
	t.ok(bg != 0, "il nodo ha montato un foglio e l'ha accodato")
	if bg == 0:
		_pulisci(cuore)
		return
	var acc: Dictionary = p.accodate[-1]
	t.eq(int(acc["chi"]), id, "il pensiero parte per il vicino giusto")
	t.ok(str(acc["gramm"]).length() > 0, "col foglio è partita anche la grammatica")

	var scelti := _offerti(str(acc["gramm"]))
	t.ok(not scelti.is_empty(), "la grammatica offre almeno un obiettivo")
	if scelti.is_empty():
		_pulisci(cuore)
		return
	t.eq((cuore.debug_deduzioni(id) as Dictionary).get("deduzioni", []).size(), 0,
			"prima della consegna il grafo delle deduzioni è vuoto")

	p.finisci(bg, PackedStringArray([_bozza(str(scelti[0]), [0])]))
	n._process(0.6)

	var d: Array = (cuore.debug_deduzioni(id) as Dictionary).get("deduzioni", [])
	t.eq(d.size(), 1, "la deduzione è entrata nel grafo")
	t.eq(int((n.misure() as Dictionary)["dedotte"]), 1, "e il nodo l'ha contata")
	if d.size() == 1:
		# NASCE MUTA: la ricevuta non l'ha ancora pagata nessuno, e finché non
		# la paga la deduzione non produce niente. Il nodo non deve poterla
		# scavalcare.
		t.eq(bool((d[0] as Dictionary)["ricevuta"]), false,
				"la deduzione entrata dal nodo nasce MUTA")
	_pulisci(cuore)


## `gia_dedotto` SI RIEMPIE, e non è decorativo: il ponte rifiuta una gemella
## di una deduzione ancora viva, e il Giudice non ha modo di saperlo da solo.
## Lasciandolo vuoto la bozza viene promossa e poi buttata dal ponte — **e la
## seconda bocciatura è muta**.
##
## L'oracolo è il MOTIVO, non il conteggio: le due strade finiscono tutte e
## due con zero deduzioni nuove, e solo la frase dice quale porta ha parlato.
##
## FALSIFICATO togliendo la chiave `gia_dedotto` dal `mondo` di `_consegna`:
## il motivo diventa «il ponte l'ha rifiutata» e la riga qui sotto è rossa.
func _gia_dedotto_si_riempie(t) -> void:
	var cuore := _cuore_vero()
	var b := _acceso(t, cuore, 1)
	var n = b[0]
	var reg: Registro = b[1]
	var p: Ponte = b[2]
	var id := int((reg._residents[0] as Dictionary)["ecs"])

	var bg := _fino_all_accodata(n, p)
	if bg == 0:
		t.ok(false, "il banco non è riuscito ad accodare il primo pensiero")
		_pulisci(cuore)
		return
	var scelti := _offerti(str((p.accodate[-1] as Dictionary)["gramm"]))
	if scelti.is_empty():
		t.ok(false, "la grammatica del secondo banco non offre nessun obiettivo")
		_pulisci(cuore)
		return
	var obiettivo := str(scelti[0])
	p.finisci(bg, PackedStringArray([_bozza(obiettivo, [0])]))
	n._process(0.6)
	t.eq(int((n.misure() as Dictionary)["dedotte"]), 1, "la prima entra")

	# LA SECONDA, IDENTICA. Il riposo del Pensatoio tiene fermo quel vicino
	# per cinque minuti: qui si consegna a mano, che è esattamente quello che
	# succederebbe in partita fra un pensiero e l'altro.
	var f: Dictionary = n._foglio({"chi": id, "id": "vicino0",
			"r": reg._residents[0]})
	t.ok(not f.is_empty(), "il foglio del secondo pensiero si monta")
	n._consegna({"chi": id, "id": "vicino0"},
			PackedStringArray([_bozza(obiettivo, [0])]), f)
	var m: Dictionary = n.misure()
	t.eq(int(m["dedotte"]), 1, "la gemella non entra")
	var porte: Dictionary = m["porte"]
	var motivi := ""
	for k in porte:
		motivi += str(k)
	# ⚠️ L'ORACOLO È **QUALE PORTA HA PARLATO**, non il conteggio: le due
	# strade finiscono tutte e due con zero deduzioni nuove, e solo il motivo
	# dice se a dire di no è stato il Giudice (che sa il perché) o il ponte
	# (che è muto). Col `gia_dedotto` riempito la bozza non è nemmeno
	# azionabile; senza, il Giudice la promuove e il ponte la butta.
	t.ok(not motivi.contains("ponte"),
			"la gemella la ferma il GIUDICE, non il ponte in silenzio (motivi: %s)" % motivi)
	t.ok(motivi.contains("azionabile"),
			"e la ferma perché non c'era niente di azionabile (motivi: %s)" % motivi)
	# e la fonte di quel «già dedotto» è il ponte, letto adesso
	t.eq(n._gia_dedotto(id), [obiettivo],
			"gli obiettivi già dedotti si leggono dal grafo vero")
	_pulisci(cuore)


## IL SEME È DERIVATO, MAI TIRATO — e non si ripete: due pensieri dello
## stesso vicino non devono chiedere al modello la stessa identica cosa, o la
## seconda deduzione sarebbe la prima con un altro nome.
##
## FALSIFICATO togliendo `_semi` dal seme (resta `hash(id)`): i due semi
## diventano uguali.
func _il_seme_non_si_ripete(t) -> void:
	var cuore := _cuore_vero()
	var b := _acceso(t, cuore, 1)
	var n = b[0]
	var reg: Registro = b[1]
	var c := {"chi": int((reg._residents[0] as Dictionary)["ecs"]), "id": "vicino0",
			"r": reg._residents[0]}
	var a: Dictionary = n._foglio(c)
	var d: Dictionary = n._foglio(c)
	t.ok(not a.is_empty() and not d.is_empty(), "i due fogli si montano")
	t.ok(int(a.get("seme", 0)) != int(d.get("seme", 0)),
			"due pensieri dello stesso vicino non chiedono la stessa cosa")
	_pulisci(cuore)


## USCIRE DALL'ALBERO BUTTA IL VOLO. È l'uscita che solo un NODO può avere:
## il Pensatoio è un `RefCounted` e `_exit_tree` non gli arriva mai — era la
## prima uscita che la documentazione dava per esistente e non esisteva.
## Senza, un cambio di scena lascia un thread che scrive per quaranta secondi
## un pensiero che non ha più nessun destinatario.
##
## FALSIFICATO togliendo `_exit_tree()` dal nodo: gli annullamenti restano
## zero. (E la seconda riga è la controprova che serve davvero: un pensiero
## in volo dev'esserci, o «zero annullamenti» sarebbe vero comunque.)
func _uscire_dall_albero_butta_il_volo(t) -> void:
	var cuore := _cuore_vero()
	var b := _acceso(t, cuore, 1)
	var n = b[0]
	var p: Ponte = b[2]
	var bg := _fino_all_accodata(n, p)
	t.ok(bg != 0, "c'è un pensiero in volo da buttare")
	t.eq(p.annullamenti, 0, "e nessuno l'ha ancora buttato")
	var padre: Node = n.get_parent()
	padre.remove_child(n)
	t.ok(p.annullamenti >= 1, "uscendo dall'albero il nodo butta il volo")
	t.ok(p.libero(), "e il motore torna libero (era ancora in coda)")
	padre.add_child(n)   # torna dov'era: lo libera la pulizia del caso
	_pulisci(cuore)
