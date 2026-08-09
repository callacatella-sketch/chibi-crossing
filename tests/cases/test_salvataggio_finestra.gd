extends RefCounted
## LA FINESTRA DEI PRIMISSIMI FRAME — quella in cui il salvataggio mutila.
##
## Il mondo di CozyWorld nasce DIFFERITO: GrandTree, Memories, Coop,
## Stargazing, Legami, il Regista e mezzo villaggio arrivano tre frame dopo
## l'avvio. Se in quella finestra si salva (una nocciolina raccolta, un
## pezzo posato, la finestra chiusa), il payload si ricostruisce da zero e
## ci si fondono SOLO i persistable già nati: la chiave di chi non è ancora
## sveglio spariva dal file. In sessione non si nota — la scrittura dopo la
## rimette — ma se il giocatore chiude subito, quel file mutilato È il
## salvataggio, e il `.bak` buono se l'è già mangiato la rotazione.
##
## Questo caso NON cerca stringhe nel sorgente: costruisce un BuildSystem
## VERO su un file di prova, gli fa caricare un salvataggio, e poi LEGGE
## DAL DISCO quello che ha riscritto. Le tre cose che deve provare:
##
##  1. la chiave di un sistema ASSENTE sopravvive alla scrittura;
##  2. la chiave di un sistema PRESENTE che si è svuotato deve invece
##     SPARIRE (la busta aperta, la dispensa finita, la casa disfatta): se
##     conservassimo tutto, il regalo dentro la busta si rimaterializzerebbe
##     a ogni avvio;
##  3. quando il ritardatario arriva, è LUI a comandare la sua chiave —
##     prima riprendendo lo stato salvato, poi potendolo anche cancellare.
##
## Più il bosco: `Woodcutting.save_extra()` nella stessa finestra scriveva
## liste vuote (lo stato aspetta in `_pending_rows` finché gli alberi non
## esistono) e al lancio dopo ogni albero abbattuto era di nuovo in piedi.

const SYS := preload("res://scenes/build/BuildSystem.gd")
const WOOD := preload("res://scenes/interact/Woodcutting.gd")

## Il villaggio del giocatore non si tocca mai: si scrive su un file nostro.
const PERCORSO := "user://prova_finestra_salvataggio.json"


## Un sistema qualunque che sa salvarsi. `valore == null` vuol dire «non ho
## più niente da dire»: è il caso della busta aperta, ed è lì che una chiave
## DEVE poter sparire dal file.
class FintoSistema extends Node:
	var chiave := ""
	var valore: Variant = null
	var letture := 0

	func _ready() -> void:
		add_to_group("persistable")

	func save_extra() -> Dictionary:
		if valore == null:
			return {}
		return {chiave: valore}

	func load_extra(data: Dictionary) -> void:
		letture += 1
		if data.has(chiave):
			valore = data[chiave]


func run(t) -> void:
	_test_le_chiavi_di_chi_non_e_ancora_nato(t)
	_test_una_chiave_svuotata_deve_sparire(t)
	_test_il_ritardatario_comanda_la_sua_chiave(t)
	_test_il_bosco_che_aspetta_gli_alberi(t)
	_test_il_corredo_arriva_col_suo_capo(t)
	_pulisci()


# --------------------------------------------------------------- gli attrezzi

func _scrivi_salvataggio(d: Dictionary) -> void:
	var f := FileAccess.open(PERCORSO, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()


func _rileggi() -> Dictionary:
	var f := FileAccess.open(PERCORSO, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


func _pulisci() -> void:
	for p in [PERCORSO, PERCORSO + ".bak", PERCORSO + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## Un salvataggio di prova: le chiavi del villaggio costruito (vuoto) più
## quelle di quattro sistemi. `posta_corrente` ha il suo proprietario già in
## scena; le altre tre appartengono a sistemi che il mondo differito non ha
## ancora creato.
func _salvataggio_di_prova() -> Dictionary:
	return {
		"cells": [], "edges": [], "up_cells": [], "up_edges": [], "variants": {},
		"legami": {"Pippo": ["un pomeriggio"]},
		"lutto": 3,
		"gufo_ordine": "il-fuoco-e-la-luce",
		"posta_corrente": {"regalo": "una stella"},
	}


## Apparecchia la finestra: il file sul disco, i sistemi GIÀ svegli in scena,
## e un BuildSystem vero che lo carica.
##
## Dentro un caso di test non gira nessun frame, quindi le chiamate che il
## gioco accoda con `call_deferred` (i `load_extra`, la fine del caricamento,
## il censimento delle chiavi orfane) si eseguono qui a mano, nello STESSO
## ordine in cui le esegue il motore.
func _apparecchia(t, presenti: Array):
	_scrivi_salvataggio(_salvataggio_di_prova())
	for n in presenti:
		t.stage(n)
	var bs = SYS.new()
	bs.save_path = PERCORSO
	t.stage(bs)
	bs._load_village()
	for n in presenti:
		n.load_extra(bs._loaded_extra)
	bs._finish_load()
	bs._censimento_orfane()
	return bs


func _posta() -> FintoSistema:
	var p := FintoSistema.new()
	p.chiave = "posta_corrente"
	return p


## Smonta il banco di prova SUBITO, senza aspettare la pulizia di fine caso.
## Obbligatorio: qui i tre scenari girano nello stesso frame, e un
## BuildSystem lasciato in scena resterebbe agganciato a `node_added` (e i
## finti sistemi resterebbero nel gruppo `persistable`) contaminando lo
## scenario successivo — il finto della posta di prima riscriveva la busta
## che stavamo verificando essere sparita.
func _smonta(nodi: Array) -> void:
	for n in nodi:
		if is_instance_valid(n):
			(n as Node).free()


# ------------------------------------------------------------------- i casi

func _test_le_chiavi_di_chi_non_e_ancora_nato(t) -> void:
	var posta := _posta()
	var bs = _apparecchia(t, [posta])
	bs.save_now()
	var f := _rileggi()
	t.ok(f.has("legami"), "il Filo Rosso sopravvive a un salvataggio nei primi frame")
	t.ok(f.has("lutto"), "il lutto sopravvive a un salvataggio nei primi frame")
	t.ok(f.has("gufo_ordine"), "l'Ordine del Gufo in corso sopravvive")
	t.eq(int(f.get("lutto", -1)), 3, "e sopravvive col suo VALORE, non svuotato")
	t.eq(str((f.get("legami", {}) as Dictionary).get("Pippo", [])),
			str(["un pomeriggio"]), "il filo di Pippo è ancora il suo")
	# e le chiavi del villaggio costruito si ricalcolano comunque
	t.ok(f.has("cells") and f.has("variants"), "il villaggio costruito resta scritto")
	# chi era in scena scrive il suo, come sempre
	t.ok(f.has("posta_corrente"), "la busta ancora chiusa resta nel file")
	_smonta([bs, posta])


func _test_una_chiave_svuotata_deve_sparire(t) -> void:
	var posta := _posta()
	var bs = _apparecchia(t, [posta])
	# la busta si apre: il regalo è stato consegnato, quello stato NON deve
	# più tornare. Conservarlo dal file vecchio lo duplicherebbe a ogni avvio.
	posta.valore = null
	bs.save_now()
	var f := _rileggi()
	t.ok(not f.has("posta_corrente"), "la busta aperta sparisce davvero dal file")
	t.ok(f.has("legami"), "e intanto le chiavi orfane restano al loro posto")
	_smonta([bs, posta])


func _test_il_ritardatario_comanda_la_sua_chiave(t) -> void:
	var posta := _posta()
	var bs = _apparecchia(t, [posta])
	# il mondo differito partorisce Legami DOPO il caricamento: entra in
	# scena e reclama la sua fetta di salvataggio (_on_node_added).
	var legami := FintoSistema.new()
	legami.chiave = "legami"
	t.stage(legami)
	t.eq(legami.letture, 1, "il ritardatario riceve lo stato salvato appena nasce")
	t.eq(str((legami.valore as Dictionary).get("Pippo", [])), str(["un pomeriggio"]),
			"e lo riceve intero")
	# ora è LUI la fonte: quello che scrive batte la copia vecchia del file
	legami.valore = {"Pippo": ["un pomeriggio", "una sera"]}
	bs.save_now()
	var f := _rileggi()
	t.eq(str((f.get("legami", {}) as Dictionary).get("Pippo", [])),
			str(["un pomeriggio", "una sera"]),
			"chi è in scena riscrive la sua chiave, non la ritrova congelata")
	# e da adesso può anche cancellarla: il proprietario è arrivato
	legami.valore = null
	bs.save_now()
	t.ok(not _rileggi().has("legami"),
			"il proprietario arrivato può anche svuotare la sua chiave")
	_smonta([bs, posta, legami])


func _test_il_bosco_che_aspetta_gli_alberi(t) -> void:
	# Woodcutting non ha bisogno dell'albero della scena per questo: si
	# carica lo stato quando gli alberi non esistono ancora (è la finestra
	# vera: BuildSystem carica dentro il suo _ready, gli alberi si adottano
	# a `world_built`) e si guarda cosa scriverebbe.
	var w = WOOD.new()
	w.load_extra({"legna": 5, "tagliati": [[3.0, 4.0]],
			"piantati": [[1.0, 2.0]], "ceppi": [[7.0, 8.0]]})
	var d: Dictionary = w.save_extra()
	t.eq((d.get("tagliati", []) as Array).size(), 1,
			"l'albero abbattuto resta abbattuto anche se non è ancora nato nessuno")
	# niente indici: un accesso fuori range interromperebbe la funzione e le
	# asserzioni dopo non girerebbero (con la suite verde a coprire il buco)
	t.eq(str(d.get("tagliati", [])), str([[3.0, 4.0]]),
			"e resta abbattuto DOV'ERA")
	t.eq((d.get("piantati", []) as Array).size(), 1,
			"l'albero piantato non sparisce dal salvataggio")
	t.eq((d.get("ceppi", []) as Array).size(), 1,
			"il ceppo lasciato nel prato non sparisce dal salvataggio")
	t.eq(int(d.get("legna", 0)), 5, "e la catasta resta quella che era")
	# adozione a metà: la riga è già stata applicata E aspetta ancora nella
	# custodia. Non deve uscire due volte (il file la rileggerebbe doppia).
	w._felled = [Vector2(3.0, 4.0)]
	var d2: Dictionary = w.save_extra()
	t.eq((d2.get("tagliati", []) as Array).size(), 1,
			"nessun doppione fra ciò che è vivo e ciò che aspetta")
	# adozione finita: si torna a scrivere solo le liste vive
	w._pending_rows = []
	var d3: Dictionary = w.save_extra()
	t.eq((d3.get("tagliati", []) as Array).size(), 1,
			"dopo l'adozione comandano le liste vive")
	t.eq((d3.get("piantati", []) as Array).size(), 0,
			"e ciò che è stato applicato non si ripete dalla custodia vuota")
	w.free()


## IL CORREDO PAGATO E MAI CONSEGNATO. Un corredo costa 240-700 noccioline e
## `Economy.unlock_piece` sblocca il capo INSIEME ai suoi compagni — ma il
## catalogo interrogava l'economia solo per i nomi di `SHOP_PIECES`, e i
## compagni non ci sono: restavano sotto chiave finché non finiva la
## campagna del Gufo (che per loro non ha nessun Ordine). Pagavi la boutique
## e potevi posare solo la vetrina.
func _test_il_corredo_arriva_col_suo_capo(t) -> void:
	var eco = load("res://scenes/ui/Economy.gd").new()
	t.stage(eco)
	var bs = SYS.new()
	bs.save_path = PERCORSO
	t.stage(bs)
	# il recinto degli Ordini acceso, com'è durante tutta la campagna
	bs.apply_unlocks(["Pavimento", "Muro", "Cassetta posta"], true)
	t.ok(not bs.is_unlocked("Manichino"), "prima di comprarla, la boutique è chiusa")
	eco.unlock_piece("Vetrina moda")
	t.ok(bs.is_unlocked("Vetrina moda"), "la vetrina comprata si può posare")
	t.ok(bs.is_unlocked("Manichino"),
			"e col capo arriva il corredo, non un pezzo solo")
	t.ok(bs.is_unlocked("Camerino") and bs.is_unlocked("Cassa boutique"),
			"tutto il corredo, fino all'ultimo pezzo")
	t.ok(not bs.is_unlocked("Tappetino"),
			"ma gli altri corredi restano da comprare")
	t.eq(bs._padrone_corredo("Manichino"), "Vetrina moda",
			"e il cartellino sa chi lo porta (niente promesse del Gufo a vuoto)")
	t.eq(bs._padrone_corredo("Muro"), "",
			"un pezzo qualunque non appartiene a nessun corredo")
	_smonta([bs, eco])
