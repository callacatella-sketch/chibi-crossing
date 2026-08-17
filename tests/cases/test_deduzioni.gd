extends RefCounted
## L'INJECTION — quello che un modello ha concluso diventa una cosa che il
## mondo contiene. (Fase 5, il terzo passo.)
##
## Qui non si cerca una stringa nei sorgenti: si interroga il BINARIO, si
## fanno girare i passi veri, e si guarda cosa succede al grafo e al corpo.
## Un `source-check` su questa materia sarebbe la peggiore delle guardie —
## resterebbe verde svuotando la funzione che sorveglia, ed è già successo
## tre volte in questo progetto.
##
## LE TRE COSE CHE QUESTO FILE ESISTE PER TENERE CHIUSE, e sono le tre in cui
## un'injection fatta male distrugge il gioco invece di arricchirlo:
##
##  1. **una deduzione non è un ricordo.** Non entra nell'anello dei
##     ventiquattro, non si racconta, non si promuove, e soprattutto **non
##     scaccia niente**: la macchina non può cancellare quello che il
##     giocatore ha fatto davvero per far posto a quello che si è
##     immaginata. Qui non è una regola tarata bene — è un altro array — ma
##     un test che non lo verifica è un test che non se ne accorgerebbe se
##     qualcuno li unisse;
##  2. **la ricevuta viene prima.** Finché la testa non si è girata, la
##     deduzione non produce NIENTE. Una conseguenza che il giocatore non sa
##     attribuire non attenua l'effetto: lo inverte;
##  3. **si spende una volta sola, e scade.** Una priorità permanente è un
##     vicino inchiodato; una che arriva tre minuti dopo la sua premessa è
##     una conseguenza slegata, cioè la stessa cosa vista da lontano.
##
## E una quarta che non è un guasto ma una promessa: **senza modello non
## cambia un bit**. L'ultimo caso lo pretende su tutte e tre le porte.

const DED := preload("res://scenes/npc/Deduzioni.gd")
const SUG := preload("res://scenes/npc/Suggeritore.gd")
const GIU := preload("res://scenes/npc/Giudice.gd")
const PIANI := preload("res://scenes/npc/Piani.gd")
const PERCEZIONE := preload("res://scenes/npc/Percezione.gd")
const VISITOR := preload("res://scenes/npc/Visitor.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")

## Il ciclo del giorno con cui si tara tutto: `imposta_ritmo` ne fa la mezza
## vita (ciclo/2 = 120 s), che è il numero con cui il villaggio vero gira.
const CICLO := 240.0

## La soglia con cui il villaggio decide che un ricordo non conta più. È
## `Visitors.AMMIRA_SOGLIA`, e sta qui come letterale per la stessa ragione
## per cui ce l'ha `Suggeritore`: `Visitors.gd` non si istanzia in headless.
## Il caso `_le_soglie_sono_quelle_del_villaggio` la lega alla vera.
const SOGLIA := 0.35


# =========================================================================
# IL CORPO — ed è un VICINO VERO, col suo rig
# =========================================================================

## ⚠️ **QUESTO CORPO ERA UN DOPPIO, E IL DOPPIO MENTIVA.**
##
## Fino al 2026-08-12 era un `Node3D` che RI-IMPLEMENTAVA `collo_ci_arriva`
## (un `angle_to` fra il −Z del corpo e la direzione del posto). Il conto
## tornava, e proprio per questo era il guasto peggiore che questo file
## potesse avere: **la valvola vera non aveva nessun lettore.** MISURATO,
## guastando `Visitor.collo_ci_arriva` nel sorgente e rifacendo la suite:
##
##   · `return true` sempre  → ricevute pagate col posto a 180°: 63942/0/0
##   · `return false` sempre → nessuna ricevuta, MAI, in tutto il gioco:
##                             63942/0/0
##
## Cioè la riga che decide se una ricevuta si paga nel villaggio vero poteva
## diventare una costante, in tutte e due le direzioni, senza che una sola
## asserzione se ne accorgesse. È la stessa classe di guasto del
## `MotoreFinto` che «annullava e liberava sempre» (vedi `test_pensatoio`):
## **un doppio che mente è peggio di nessun doppio — nessun doppio ti fa
## scrivere un test vero, uno che mente ti fa credere di averlo già
## scritto.**
##
## Adesso il corpo È un `Visitor`, con il rig montato da `ChibiBuilder` come
## quello dei residenti: `collo_ci_arriva`, `is_hidden`, `dorme` e `in_scena`
## sono le funzioni di produzione, e `Percezione.puo_vedere` interroga
## proprio loro. Di finto resta una cosa sola, ed è quella che un test deve
## avere: **`guarda_gesto` REGISTRA quello che gli si chiede** — e poi chiama
## `super()`, così il canale dello sguardo gira davvero.
##
## MISURATO che il cambio non sposta la geometria: la testa di un chibi sta
## ESATTAMENTE sopra l'origine del corpo (scarto orizzontale 0.0000 m su tre
## genomi), che è la stessa posizione da cui misurava il doppio.
class Corpo extends "res://scenes/npc/Visitor.gd":
	const DNA := preload("res://scenes/npc/ChibiDNA.gd")

	var guardato := []  # [pos, durata] di ogni sguardo chiesto

	## Il genoma si dà QUI, prima che l'albero chiami `_ready`: senza, il
	## `Visitor` monta un riccio invece di un chibi — un corpo che nel
	## villaggio non fa mai da residente, e che ha la testa in un altro posto.
	func _init() -> void:
		dna = DNA.generate(4507)
		species = "chibi"
		mode = "resident"

	func guarda_gesto(pos: Vector3, dur: float, gesto := -1, finestra := 0.0) -> bool:
		guardato.append([pos, dur])
		return super(pos, dur, gesto, finestra)


## LE TRE VALVOLE DELLA PERCEZIONE, accese sui campi VERI del `Visitor`.
##
## Il doppio aveva tre booleani suoi (`nascosto`, `addormentato`,
## `in_una_scena`) e tre funzioni che li restituivano: un'altra
## reimplementazione, con lo stesso difetto in piccolo. Qui si scrive lo
## stato vero e rispondono `is_hidden()`, `dorme()` e `in_scena()` di
## produzione — quelle che `Percezione.puo_vedere` chiama davvero.
const GUASTI := {
	"nascosto": ["_hidden", true],
	"addormentato": ["_state", "tk_nap"],
	"in_una_scena": ["_scena_t", 5.0],
}


## Gira il corpo, come si gira un corpo in questo gioco: `_yaw` E la
## rotazione. Scrivere solo `rotation.y` è la trappola già pagata da
## `tools/prova_pensieri.gd` — `Visitor._process` finisce con
## `rotation.y = _yaw` per ogni stato, e un'imbardata scritta da fuori vive
## un frame solo.
func _gira(corpo: Node3D, rad: float) -> void:
	corpo.set("_yaw", rad)
	corpo.rotation.y = rad


func run(t) -> void:
	# GUARDIA DURA: senza GDExtension questo test è ROSSO. Un `return`
	# silenzioso direbbe «tutto bene» di un'injection che non esiste.
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return

	_l_api_c_e_nel_binario(t)
	_le_costanti_non_si_scrivono_a_mano(t)
	_le_soglie_sono_quelle_del_villaggio(t)

	# --- 1. IL NODO NEL GRAFO
	_una_deduzione_non_entra_nell_anello(t)
	_una_deduzione_non_scaccia_un_ricordo_vero(t)
	_una_deduzione_non_si_racconta_e_non_si_promuove(t)
	_il_soggetto_non_passa(t)
	_la_catena_pesa_quanto_il_suo_anello_piu_debole(t)
	_le_gemelle_si_rifiutano(t)
	_un_obiettivo_che_non_e_dei_quattro_non_entra(t)
	_una_riga_che_non_esiste_non_regge_niente(t)
	_la_piu_debole_non_scaccia_la_piu_forte(t)
	_una_deduzione_muore_col_ricordo(t)

	# --- 2. LA RICEVUTA
	_una_deduzione_nasce_muta(t)
	_senza_ricevuta_nessun_obiettivo_mai(t)
	_la_ricevuta_gira_la_testa(t)
	_a_chi_non_puo_guardare_non_si_paga_niente(t)
	_senza_il_giocatore_non_si_paga_niente(t)
	_il_raggio_e_quello_a_cui_una_testa_si_legge(t)
	_il_collo_deve_arrivarci(t)
	_la_promessa_del_collo_la_mantiene_il_rig(t)
	_l_ancora_si_sceglie_fra_i_perche_veri(t)
	_un_ancora_che_punta_altrove_non_si_mostra(t)
	_l_apertura_ammette_quel_che_il_villaggio_produce(t)
	_senza_una_meta_non_si_paga_niente(t)
	_il_registro_passa_dove_sta_mochi(t)
	_la_ricevuta_deve_avere_il_suo_tempo(t)
	_la_ricevuta_scade(t)

	# --- 3. IL DIROTTAMENTO
	_le_due_traduzioni_sono_derivate(t)
	_una_deduzione_pronta_cambia_l_azione(t)
	_si_spende_una_volta_sola(t)
	_senza_una_strada_non_si_dirotta(t)
	_quello_che_l_agenda_voleva_gia_non_e_un_dirottamento(t)

	# --- 4. LA GRAMMATICA, e il giro chiuso
	_la_grammatica_viene_dalle_enum(t)
	_tutto_cio_che_la_grammatica_produce_il_gioco_lo_incassa(t)
	_la_grammatica_non_ha_un_posto_per_una_frase(t)
	_niente_doppioni_e_niente_permutazioni(t)
	_senza_ricordi_non_c_e_grammatica(t)

	# --- 5. IL VETO, e la promessa
	_una_deduzione_non_ha_campi_liberi(t)
	_senza_modello_non_cambia_un_bit(t)


# =========================================================================
# IL BANCO
# =========================================================================

## Un registro con dentro un vicino, l'orologio a zero e il ritmo del
## villaggio vero.
func _mondo() -> Object:
	var m = ClassDB.instantiate("EcsMondo")
	m.imposta_ritmo(CICLO)
	return m


func _uno(m) -> int:
	return int(m.registra(PackedStringArray(["goloso"]), ""))


## Fa passare `sec` secondi di orologio della memoria. `avanza` è il passo
## vero del registro: si usa quello e non un timbro finto, perché il tempo
## dei ricordi lo tiene lui e un test che se lo ricostruisse terrebbe una
## seconda contabilità.
func _passano(m, sec: float) -> void:
	# a passi di mezzo secondo: `avanza` è anche il passo del sonno e
	# dell'agenda, e saltare un minuto in un frame solo le farebbe girare in
	# un modo che in partita non capita mai.
	var fatto := 0.0
	while fatto < sec - 1e-6:
		var dt: float = minf(0.5, sec - fatto)
		m.avanza(dt, 0.5)
		fatto += dt


func _ob(m, nome: String) -> int:
	return int(m.maschera_obiettivo(nome))


## I cinque luoghi «tutti raggiungibili e vicini», nella forma che
## `Piani.cammino` si aspetta, e tutti nel punto `dove`.
##
## Il `pos` non serve al piano (`Piani.cammino` guarda `metri` e `ok`): serve
## alla RICEVUTA, che da lì ricava dove andrà il corpo e quindi in che
## direzione ha senso girare la testa. Metterli tutti e cinque nello stesso
## punto vuol dire «qualunque cosa deduca, va lì», che è la forma più
## semplice in cui un caso può dichiarare la sua geometria.
func _luoghi_verso(dove: Vector3) -> Array:
	var out := []
	for i in PIANI.LUOGHI.size():
		out.append({"ok": true, "metri": 3.0, "pos": dove})
	return out


func _luoghi_pieni() -> Array:
	return _luoghi_verso(Vector3.ZERO)


## LA RICEVUTA, chiesta come la chiede il villaggio. I casi che provano una
## valvola cambiano UNA cosa sola rispetto a questa chiamata:
##  · `occhio` — dove sta Mochi. Addosso al vicino, se non si dice altro;
##  · `meta`   — dove il corpo andrà. Nel posto del ricordo, se non si dice
##               altro: la geometria in cui la scena si legge.
func _paga(m, id: int, corpo: Node3D, i: int, occhio: Vector3,
		meta := Vector3(0, 0, -12)) -> bool:
	return DED.consegna(m, id, corpo, i, occhio, _luoghi_verso(meta), _fatti_pieni(m))


func _luoghi_vuoti() -> Array:
	var out := []
	for i in PIANI.LUOGHI.size():
		out.append({"ok": false, "metri": 0.0, "pos": Vector3.ZERO})
	return out


## I fatti del mondo con tutto disponibile: si chiedono per NOME, mai con un
## numero scritto a mano.
func _fatti_pieni(m) -> int:
	return int(m.maschera_fatti(PackedStringArray([
			"spuntino_vicino", "aiuola_da_annaffiare", "amico_in_giro",
			"spuntino_raggiungibile", "aiuola_raggiungibile",
			"seduta_libera_vicina", "meraviglia_raggiungibile", "lavagna_pronta",
			"meraviglia_posto"])))


func _deduzioni(m, id: int) -> Array:
	return (m.debug_deduzioni(id) as Dictionary).get("deduzioni", []) as Array


# =========================================================================
# L'API E LE COSTANTI
# =========================================================================

## `has_method` interroga l'oggetto VIVO. Un controllo sul sorgente
## resterebbe verde anche svuotando la funzione.
func _l_api_c_e_nel_binario(t) -> void:
	var m = _mondo()
	for nome in ["deduci", "deduzione_muta", "deduzione_pronta", "deduzione_dove",
			"deduzione_obiettivo", "deduzione_ricevuta", "deduzione_spendi",
			"debug_deduzioni", "debug_deduzioni_costanti"]:
		t.ok(m.has_method(nome), "EcsMondo espone «%s» nel binario" % nome)
	m.free()


func _le_costanti_non_si_scrivono_a_mano(t) -> void:
	var m = _mondo()
	var k: Dictionary = m.debug_deduzioni_costanti()
	t.eq(int(k["max_perche"]), SUG.PERCHE_MAX,
			"il tetto dei perché del Suggeritore è quello del ponte")
	t.ok(int(k["max_deduzioni"]) >= 1, "un vicino può portarsi dietro almeno una deduzione")
	t.ok(int(k["d_ricevuta"]) != 0 and int(k["d_spesa"]) != 0,
			"le due bandiere della deduzione esistono")
	t.ok(int(k["d_ricevuta"]) != int(k["d_spesa"]),
			"ricevuta e spesa sono due bit diversi")
	# I QUATTRO OBIETTIVI hanno tutti una maschera vera, e ognuna è UN bit
	# dentro la maschera dei provvedimenti: è la condizione che
	# `obiettivo_solo()` pretende, e se un domani se ne aggiungesse uno senza
	# maschera la grammatica lo offrirebbe e il ponte lo rifiuterebbe in
	# silenzio.
	var provv := int(k["maschera_provvedimenti"])
	for act in PIANI.OBIETTIVO:
		var ob := _ob(m, str(PIANI.OBIETTIVO[act]))
		t.ok(ob != 0, "«%s» ha una maschera nel ponte" % str(PIANI.OBIETTIVO[act]))
		t.eq(ob & provv, ob, "«%s» è dentro i provvedimenti" % str(PIANI.OBIETTIVO[act]))
		t.eq(ob & (ob - 1), 0, "«%s» è UN bit solo" % str(PIANI.OBIETTIVO[act]))
	m.free()


## LA SOGLIA E I DUE TEMPI vengono da dove già vivono. Se un domani qualcuno
## sposta la durata dello sguardo, l'attesa della ricevuta deve muoversi con
## lei: sono la stessa cosa detta due volte, e due numeri per la stessa cosa
## divergono.
func _le_soglie_sono_quelle_del_villaggio(t) -> void:
	t.almost(DED.ATTESA, PERCEZIONE.DURATA_SGUARDO,
			"l'attesa della ricevuta È la durata di uno sguardo", 1e-9)
	var m = _mondo()
	var k: Dictionary = m.debug_costanti_agenda()
	t.almost(DED.finestra(m), float(k["tetto_impegno"]),
			"la finestra della ricevuta È il tetto d'impegno dell'agenda", 1e-9)
	t.ok(DED.ATTESA < DED.finestra(m),
			"si aspetta meno di quanto si scade, o non arriverebbe mai niente")
	t.almost(DED.finestra(null), 0.0,
			"senza cuore la finestra è zero, cioè «nessuna scadenza»", 1e-9)
	m.free()


# =========================================================================
# 1. IL NODO NEL GRAFO
# =========================================================================

## UNA DEDUZIONE NON ENTRA NELL'ANELLO DEI RICORDI. Si fotografa il grafo
## prima e dopo, riga per riga: se un domani qualcuno la infilasse lì dentro
## con una bandiera in più, questa fotografia cambia.
func _una_deduzione_non_entra_nell_anello(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	m.osserva(id, m.V_ANNAFFIA, Vector3(5, 0, 7), -1)
	m.osserva(id, m.V_COSTRUISCE, Vector3(9, 0, 2), -1)
	var prima := str(m.debug_grafo(id))
	var i := int(m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA))
	t.ok(i >= 0, "la deduzione è entrata (indice %d)" % i)
	t.eq(str(m.debug_grafo(id)), prima,
			"il grafo dei ricordi è identico prima e dopo la deduzione")
	t.eq(_deduzioni(m, id).size(), 1, "e la deduzione sta nel suo elenco")
	m.free()


## E NON SCACCIA UN RICORDO VERO. L'anello si riempie fino all'orlo (il
## `MAX_FATTI` lo dice il binario), poi si deduce: nessuna riga si muove.
##
## È la domanda esplicita dell'autore, ed è quella per cui le deduzioni
## stanno in un array loro: qui non c'è una potatura che si comporta bene,
## c'è una potatura che non le vede proprio.
func _una_deduzione_non_scaccia_un_ricordo_vero(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	var quanti := int((m.debug_grafo_costanti() as Dictionary)["max_fatti"])
	# ricordi tutti diversi (verbo × posto) e fuori dalla finestra di fusione,
	# così l'anello si riempie davvero invece di fondere
	for k in quanti:
		m.osserva(id, k % int(m.N_VERBI), Vector3(k, 0, k * 2), -1)
		_passano(m, 9.0)
	var grafo: Dictionary = m.debug_grafo(id)
	t.eq((grafo["ricordi"] as Array).size(), quanti, "l'anello dei ricordi è pieno")
	var prima := str(grafo)
	# le righe FRESCHE (le ultime osservate), o la deduzione sarebbe rifiutata
	# per debolezza e questo caso non proverebbe niente
	var entrate := 0
	for _giro in 4:
		if int(m.deduci(id, _ob(m, "provvedi_pancino"),
				PackedInt32Array([quanti - 1, quanti - 2]), SOGLIA)) >= 0:
			entrate += 1
		if int(m.deduci(id, _ob(m, "provvedi_energia"),
				PackedInt32Array([quanti - 3]), SOGLIA)) >= 0:
			entrate += 1
		m.deduzione_spendi(id, 0)
		m.deduzione_spendi(id, 1)
	t.ok(entrate >= 4, "le deduzioni sono davvero entrate (%d)" % entrate)
	t.eq(str(m.debug_grafo(id)), prima,
			"un anello pieno non perde una riga per far posto a una deduzione")
	m.free()


## E NON SI RACCONTA, E NON SI PROMUOVE. Sono i due consumatori del grafo che
## portano un ricordo FUORI dal grafo — uno nella testa di un altro vicino,
## l'altro dentro il salvataggio. Una deduzione che passasse di lì sarebbe
## un'allucinazione propagata dal sistema che serve a propagare i fatti veri.
func _una_deduzione_non_si_racconta_e_non_si_promuove(t) -> void:
	var m = _mondo()
	var a := _uno(m)
	var b := _uno(m)
	m.osserva(a, m.V_ANNAFFIA, Vector3(5, 0, 7), -1)
	m.deduci(a, _ob(m, "provvedi_energia"), PackedInt32Array([0]), SOGLIA)

	# quello che A racconta a B è ancora e solo il suo unico ricordo VERO
	var cosa := int(m.racconta(a, b, 1.0))
	t.eq(cosa, int(m.C_FIORE), "si racconta il ricordo vero, non la deduzione")
	t.eq((m.debug_grafo(b)["ricordi"] as Array).size(), 1,
			"e a B arriva una riga sola")
	# e quello che merita di attraversare un riavvio è quello, non l'altra
	t.eq(int(m.cosa_da_ricordare(a, 0.0)), int(m.C_FIORE),
			"si promuove il ricordo vero, non la deduzione")
	m.free()


## IL SOGGETTO NON PASSA. Un dono ricevuto porta dentro l'handle di chi
## l'ha fatto; la copia dentro la deduzione no. Non è una taratura: è
## l'unico campo con cui una deduzione potrebbe diventare un'opinione su
## una persona, e non c'è più.
##
## E il PESO non cambia di un bit — `peso()` guarda le bandiere, non il
## soggetto — quindi togliendolo non si è tarato niente.
func _il_soggetto_non_passa(t) -> void:
	var m = _mondo()
	var a := _uno(m)
	var b := _uno(m)
	m.osserva(a, m.V_DONA, Vector3(4, 0, 6), b)  # b ha fatto un dono ad a
	var riga: Dictionary = (m.debug_grafo(a)["ricordi"] as Array)[0]
	t.ok(int(riga["soggetto"]) != int((m.debug_grafo_costanti() as Dictionary)["sogg_nessuno"]),
			"il ricordo vero porta dentro chi c'era")

	m.deduci(a, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
	var ded: Dictionary = _deduzioni(m, a)[0]
	var copia: Dictionary = (ded["perche"] as Array)[0]
	t.eq(int(copia["soggetto"]),
			int((m.debug_grafo_costanti() as Dictionary)["sogg_nessuno"]),
			"la copia dentro la deduzione non nomina nessuno")
	t.eq(int(copia["bandiere"]), int(riga["bandiere"]),
			"ma le bandiere restano: il peso non è cambiato")
	t.almost(float(ded["peso"]),
			float(m.debug_grafo_peso(riga, float((m.debug_ritmo() as Dictionary)["tempo"]),
					float((m.debug_ritmo() as Dictionary)["mezza_vita"]))),
			"e infatti la deduzione pesa quanto il suo ricordo", 1e-9)
	m.free()


## LA CATENA VALE QUANTO IL SUO ANELLO PIÙ DEBOLE, e vale così **nel tempo**
## — non solo nell'istante in cui il Giudice la sceglie. Si costruisce una
## deduzione su due ricordi di età diversa e si controlla che il suo peso sia
## il minimo dei due, misurato con la stessa funzione del ponte.
##
## E il posto che si guarda è quello dell'anello più FORTE: le due domande
## sono diverse apposta, e un file che le confondesse manderebbe il vicino a
## fissare la cosa che ricorda peggio.
func _la_catena_pesa_quanto_il_suo_anello_piu_debole(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	m.osserva(id, m.V_COSTRUISCE, Vector3(20, 0, 20), -1)  # il vecchio
	_passano(m, 100.0)
	m.osserva(id, m.V_ANNAFFIA, Vector3(3, 0, 4), -1)      # il fresco
	m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0, 1]), SOGLIA)

	var ritmo: Dictionary = m.debug_ritmo()
	var righe: Array = m.debug_grafo(id)["ricordi"]
	var p0 := float(m.debug_grafo_peso(righe[0], ritmo["tempo"], ritmo["mezza_vita"]))
	var p1 := float(m.debug_grafo_peso(righe[1], ritmo["tempo"], ritmo["mezza_vita"]))
	t.ok(p0 < p1, "il ricordo vecchio pesa meno del fresco (%.4f < %.4f)" % [p0, p1])
	t.almost(float(_deduzioni(m, id)[0]["peso"]), minf(p0, p1),
			"la deduzione pesa quanto il suo anello più debole", 1e-9)

	# apertura ZERO = «non filtrare», cioè la domanda pura: fra i due, quale
	# si guarda? (Il filtro ha un caso suo, `_l_ancora_si_sceglie_fra_i_perche_veri`.)
	var dove: Vector3 = m.deduzione_dove(id, 0, Vector3(-99, 0, -99), Vector3.ZERO, 0.0)
	t.almost(dove.x, 3.0, "e si guarda il posto del ricordo più FORTE (x)", 1e-4)
	t.almost(dove.z, 4.0, "e si guarda il posto del ricordo più FORTE (z)", 1e-4)
	m.free()


## LE GEMELLE SI RIFIUTANO: non si fondono. Concludere due volte la stessa
## cosa non è concluderla più forte — e se fondesse, un modello che si
## ripete (che è il difetto naturale dei modelli piccoli: due incipit su
## quindici, misurati) si costruirebbe da solo un obiettivo inarrestabile.
func _le_gemelle_si_rifiutano(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	m.osserva(id, m.V_ANNAFFIA, Vector3(5, 0, 7), -1)
	var uno := int(m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA))
	t.ok(uno >= 0, "la prima entra")
	t.eq(int(m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)), -1,
			"la gemella con lo stesso obiettivo NON entra")
	t.ok(int(m.deduci(id, _ob(m, "provvedi_energia"), PackedInt32Array([0]), SOGLIA)) >= 0,
			"ma un altro obiettivo sì")
	t.eq(_deduzioni(m, id).size(), 2, "e sono due, non tre")
	m.free()


func _un_obiettivo_che_non_e_dei_quattro_non_entra(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	m.osserva(id, m.V_ANNAFFIA, Vector3(5, 0, 7), -1)
	var a := _ob(m, "provvedi_cura")
	var b := _ob(m, "provvedi_energia")
	t.eq(int(m.deduci(id, 0, PackedInt32Array([0]), SOGLIA)), -1,
			"maschera vuota: niente")
	t.eq(int(m.deduci(id, a | b, PackedInt32Array([0]), SOGLIA)), -1,
			"due provvedimenti insieme: niente (il risolutore non li sa servire)")
	t.eq(int(m.deduci(id, 1, PackedInt32Array([0]), SOGLIA)), -1,
			"un bit che non è un provvedimento: niente")
	t.eq(int(m.deduci(id, a | 1, PackedInt32Array([0]), SOGLIA)), -1,
			"un provvedimento più della sporcizia: niente")
	t.eq(_deduzioni(m, id).size(), 0, "e non è entrato niente davvero")
	m.free()


func _una_riga_che_non_esiste_non_regge_niente(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	# UN RICORDO IN PIÙ DEL TETTO DELLA CATENA, e tutti DIVERSI. La prima
	# stesura ne metteva due e provava il tetto con `[0,1,0,1]`: troncando a
	# tre sarebbe uscito `[0,1,0]`, che cade sul doppione — cioè la guardia
	# del tetto era coperta da un'altra, e la falsificazione l'ha detto
	# (mutazione «tronca invece di rifiutare»: verde).
	var quante := SUG.PERCHE_MAX + 1
	for k in quante:
		m.osserva(id, k % int(m.N_VERBI), Vector3(k, 0, k * 2), -1)
		_passano(m, 9.0)
	var ob := _ob(m, "provvedi_cura")
	t.eq(int(m.deduci(id, ob, PackedInt32Array([]), SOGLIA)), -1,
			"senza perché non è una deduzione")
	t.eq(int(m.deduci(id, ob, PackedInt32Array([quante + 3]), SOGLIA)), -1,
			"una riga oltre il grafo: niente")
	t.eq(int(m.deduci(id, ob, PackedInt32Array([-1]), SOGLIA)), -1,
			"una riga negativa: niente")
	t.eq(int(m.deduci(id, ob, PackedInt32Array([0, 0]), SOGLIA)), -1,
			"lo stesso ricordo citato due volte: niente")
	var troppe := PackedInt32Array()
	for k in quante:
		troppe.append(k)
	t.eq(int(m.deduci(id, ob, troppe, SOGLIA)), -1,
			"più perché di quanti una catena ne porti: niente — e si RIFIUTA")
	# la controprova, che è quella che rende la riga di sopra una guardia:
	# gli stessi indici meno l'ultimo entrano, quindi il no di prima non è
	# arrivato per debolezza o per un'altra regola
	var giuste := PackedInt32Array()
	for k in SUG.PERCHE_MAX:
		giuste.append(k)
	t.eq(_deduzioni(m, id).size(), 0, "e finora non è entrato niente davvero")
	t.ok(int(m.deduci(id, ob, giuste, SOGLIA)) >= 0,
			"mentre gli stessi indici meno l'ultimo entrano")
	m.free()


## L'ANELLO DELLE DEDUZIONI SI POTA PER PESO, come quello dei ricordi: si
## tengono le più forti, non le ultime. E una SPESA esce per prima, per
## quanto forte fosse: uno slot occupato da una deduzione che non può più
## produrre niente è uno slot perso.
func _la_piu_debole_non_scaccia_la_piu_forte(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	var quante := int((m.debug_deduzioni_costanti() as Dictionary)["max_deduzioni"])
	m.osserva(id, m.V_ANNAFFIA, Vector3(5, 0, 7), -1)      # riga 0, forte
	_passano(m, 150.0)
	m.osserva(id, m.V_PESCA, Vector3(1, 0, 1), -1)         # riga 1, fresca
	# si riempie con le forti (riga 1)
	var nomi := []
	for act in PIANI.OBIETTIVO:
		nomi.append(str(PIANI.OBIETTIVO[act]))
	for k in quante:
		t.ok(int(m.deduci(id, _ob(m, str(nomi[k])), PackedInt32Array([1]), SOGLIA)) >= 0,
				"la deduzione forte %d entra" % k)
	var prima := str(_deduzioni(m, id))
	# la debole (riga 0, vecchia) non deve entrare
	t.eq(int(m.deduci(id, _ob(m, str(nomi[quante])), PackedInt32Array([0]), SOGLIA)), -1,
			"la più debole non scaccia una più forte")
	t.eq(str(_deduzioni(m, id)), prima, "e l'elenco non si è mosso")
	# ma se una si spende, il suo slot si libera
	m.deduzione_spendi(id, 0)
	t.ok(int(m.deduci(id, _ob(m, str(nomi[quante])), PackedInt32Array([0]), SOGLIA)) >= 0,
			"una deduzione spesa lascia il posto anche a una più debole")
	m.free()


## E MUORE COL RICORDO. Non c'è un contatore che scende: c'è la stessa
## formula del grafo, letta adesso. Sotto la soglia del villaggio la
## deduzione smette di esistere per tutti e tre i suoi lettori.
func _una_deduzione_muore_col_ricordo(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	m.osserva(id, m.V_ANNAFFIA, Vector3(5, 0, 7), -1)
	m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
	t.ok(int(m.deduzione_muta(id, SOGLIA)) >= 0, "appena nata, è da mostrare")
	# 1.0 · 2^(-dt/120) scende sotto 0.35 dopo ~182 s
	_passano(m, 200.0)
	t.ok(float(_deduzioni(m, id)[0]["peso"]) < SOGLIA,
			"dopo tre minuti pesa meno di un'occhiata e mezza")
	t.eq(int(m.deduzione_muta(id, SOGLIA)), -1, "e non c'è più niente da mostrare")
	m.free()


# =========================================================================
# 2. LA RICEVUTA
# =========================================================================

## UNA DEDUZIONE NASCE MUTA, e nemmeno un chiamante sbagliato può fabbricarne
## una con la ricevuta già in tasca: le bandiere le scrive il ponte.
func _una_deduzione_nasce_muta(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	m.osserva(id, m.V_ANNAFFIA, Vector3(5, 0, 7), -1)
	m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
	t.eq(int(_deduzioni(m, id)[0]["bandiere"]), 0, "nasce senza nessuna bandiera")
	t.ok(int(m.deduzione_muta(id, SOGLIA)) >= 0, "quindi aspetta la sua ricevuta")
	t.eq(int(m.deduzione_pronta(id, SOGLIA, 0.0, 0.0)), -1,
			"e non è pronta, nemmeno senza attesa e senza scadenza")
	m.free()


## E SENZA RICEVUTA NON PRODUCE NIENTE, MAI. Si aspetta tutta la vita utile
## della deduzione: non diventa pronta in nessun momento.
func _senza_ricevuta_nessun_obiettivo_mai(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	m.osserva(id, m.V_ANNAFFIA, Vector3(5, 0, 7), -1)
	m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
	var visto := 0
	for _giro in 40:
		_passano(m, 4.0)
		if int(m.deduzione_pronta(id, SOGLIA, DED.ATTESA, 0.0)) >= 0:
			visto += 1
	t.eq(visto, 0, "in centosessanta secondi non è MAI diventata pronta")
	# e il dirottamento infatti non tocca l'azione
	t.eq(str(DED.dirotta(m, id, "spuntino", _luoghi_pieni(), _fatti_pieni(m), SOGLIA)),
			"spuntino", "e nessuno cambia mestiere")
	m.free()


## LE DUE RIGHE: la testa si gira VERSO IL POSTO GIUSTO, e solo dopo il
## motore sa che il giocatore ha visto. Si guarda cosa è stato chiesto al
## collo, non se una funzione è stata chiamata.
func _la_ricevuta_gira_la_testa(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	var corpo: Corpo = t.stage(Corpo.new())
	m.osserva(id, m.V_ANNAFFIA, Vector3(0, 0, -12), -1)
	m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)

	var i := int(m.deduzione_muta(id, SOGLIA))
	t.ok(_paga(m, id, corpo, i, corpo.global_position), "la ricevuta si paga")
	t.eq(corpo.guardato.size(), 1, "la testa si è girata una volta")
	var g: Array = corpo.guardato[0]
	t.almost((g[0] as Vector3).x, 0.0, "verso il posto del ricordo (x)", 1e-4)
	t.almost((g[0] as Vector3).z, -12.0, "verso il posto del ricordo (z)", 1e-4)
	t.almost(float(g[1]), PERCEZIONE.DURATA_SGUARDO,
			"e per quanto dura uno sguardo in questo gioco", 1e-9)
	t.eq(int(_deduzioni(m, id)[0]["bandiere"]),
			int((m.debug_deduzioni_costanti() as Dictionary)["d_ricevuta"]),
			"e il motore adesso sa che il giocatore ha visto")
	t.eq(int(m.deduzione_muta(id, SOGLIA)), -1, "non c'è più niente da mostrare")

	# ripagarla non riazzera l'orologio: una ricevuta che si rinnova è una
	# conseguenza che non arriva mai
	var quando := float(_deduzioni(m, id)[0]["ricevuta"])
	_passano(m, 5.0)
	_paga(m, id, corpo, 0, corpo.global_position)
	t.almost(float(_deduzioni(m, id)[0]["ricevuta"]), quando,
			"la ricevuta si paga una volta sola", 1e-6)
	m.free()


## A CHI NON PUÒ GUARDARE NON SI PAGA NIENTE — e le tre valvole sono quelle
## della percezione, chieste a lei. Ognuna si guasta da sola: si accende una
## per volta e si pretende che la ricevuta NON venga pagata.
func _a_chi_non_puo_guardare_non_si_paga_niente(t) -> void:
	for guasto in GUASTI:
		var m = _mondo()
		var id := _uno(m)
		var corpo: Corpo = t.stage(Corpo.new())
		# lo stato VERO del vicino, non un booleano del banco: risponde
		# `is_hidden()` / `dorme()` / `in_scena()` di produzione
		corpo.set(str((GUASTI[guasto] as Array)[0]), (GUASTI[guasto] as Array)[1])
		m.osserva(id, m.V_ANNAFFIA, Vector3(0, 0, -12), -1)
		m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
		var i := int(m.deduzione_muta(id, SOGLIA))
		t.ok(not _paga(m, id, corpo, i, corpo.global_position),
				"a un vicino «%s» la ricevuta non si paga" % guasto)
		t.eq(corpo.guardato.size(), 0, "e la testa non si è girata (%s)" % guasto)
		t.eq(int(_deduzioni(m, id)[0]["bandiere"]), 0,
				"e la deduzione è ancora muta (%s)" % guasto)
		m.free()

	# e senza un posto da guardare nemmeno: il ripiego tornato tale e quale
	# vuol dire «i ricordi non indicano più niente»
	var m2 = _mondo()
	var id2 := _uno(m2)
	var c2: Corpo = t.stage(Corpo.new())
	c2.position = Vector3(5, 0, 7)
	m2.osserva(id2, m2.V_ANNAFFIA, Vector3(5, 0, 7), -1)
	m2.deduci(id2, _ob(m2, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
	t.ok(not _paga(m2, id2, c2, 0, c2.global_position, Vector3(5, 0, -5)),
			"non si gira la testa verso i propri piedi")
	m2.free()


## ⚠️ **E IL GIOCATORE DEVE ESSERCI.** È la quarta valvola, ed è quella che
## dà il nome a tutto il meccanismo: una ricevuta è una testa che si gira, e
## una testa che si gira mentre Mochi è dall'altra parte del villaggio non
## l'ha vista nessuno. Restava solo la conseguenza — cioè il guasto che
## questa fase esiste per rendere impossibile, non per tararlo bene.
##
## MISURATO prima della cura, nel villaggio vero: **sei ricevute su sei**
## pagate con Mochi parcheggiata a cinquanta metri.
##
## La valvola morde ESATTAMENTE sul raggio del rig (`Visitor.FACCIA_AL_GIOCATORE`,
## la distanza sotto la quale il gioco ha già deciso che una testa è una cosa
## che si guarda), e si misura spostando l'occhio di un pelo di qua e di là:
## stesso vicino, stesso posto, e la risposta cambia.
##
## E la deduzione NON muore per questo: resta muta e aspetta che il giocatore
## passi di lì. È la stessa disciplina del collo.
func _senza_il_giocatore_non_si_paga_niente(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	var corpo: Corpo = t.stage(Corpo.new())
	m.osserva(id, m.V_ANNAFFIA, Vector3(0, 0, -12), -1)
	m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
	var i := int(m.deduzione_muta(id, SOGLIA))
	t.ok(i >= 0, "la deduzione c'è ed è muta")

	# Mochi dall'altra parte del prato: il vicino gira la testa e non la vede
	# nessuno — quindi non la gira affatto
	var lontano := Vector3(0, 0, DED.RAGGIO + 40.0)
	t.ok(not _paga(m, id, corpo, i, lontano),
			"con Mochi a %.0f m la ricevuta NON si paga" % lontano.length())
	t.eq(corpo.guardato.size(), 0, "e la testa non si gira a vuoto")
	t.ok(int(m.deduzione_muta(id, SOGLIA)) >= 0, "la deduzione aspetta il suo momento")

	# passa un minuto di villaggio: continua ad aspettare
	_passano(m, 60.0)
	t.ok(not _paga(m, id, corpo, 0, lontano), "e continua a non pagarsi")

	# LA VALVOLA MORDE SUL RAGGIO, e il numero non è di questo file
	t.ok(DED.RAGGIO > 0.0, "il raggio della ricevuta è un numero vero (%.2f m)" % DED.RAGGIO)
	t.eq(DED.RAGGIO, VISITOR.FACCIA_AL_GIOCATORE,
			"ed è quello sotto cui il volto insegue già il giocatore")
	for prova in [[DED.RAGGIO + 0.1, false], [DED.RAGGIO - 0.1, true]]:
		var m2 = _mondo()
		var id2 := _uno(m2)
		var c2: Corpo = t.stage(Corpo.new())
		m2.osserva(id2, m2.V_ANNAFFIA, Vector3(0, 0, -12), -1)
		m2.deduci(id2, _ob(m2, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
		# di FIANCO, non davanti: Mochi non deve finire sulla linea di sguardo
		t.eq(_paga(m2, id2, c2, 0, Vector3(float(prova[0]), 0, 0)), bool(prova[1]),
				"Mochi a %.2f m (raggio %.2f): la ricevuta %s"
						% [float(prova[0]), DED.RAGGIO,
						"si paga" if bool(prova[1]) else "aspetta"])
		m2.free()
	m.free()


## ⚠️ **IL RAGGIO GIUDICATO CON NUMERI CHE NON SONO IL RAGGIO.**
##
## Le due sonde qui sopra stanno a `RAGGIO ± 0.1`: dicono che la valvola
## MORDE, non che morde nel posto giusto. Portando `FACCIA_AL_GIOCATORE` a
## cento metri resterebbero verdi tutte e due — e il gioco tornerebbe a
## pagare ricevute con Mochi dall'altra parte del villaggio, che è il difetto
## MISURATO (sei ricevute su sei, mediana 20 m) da cui è nata tutta questa
## valvola.
##
## Perciò due numeri che vengono da fuori, tutti e due PROVINATI guardando
## (`tools/provino_ricevuta.gd`, la camera vera del gioco, cinque distanze):
##
##  · **due metri** — la distanza a cui in questo gioco ci si parla, e a cui
##    una testa che si gira riempie lo schermo: lì la ricevuta DEVE pagarsi,
##    o il canale è spento;
##  · **nove metri** — dove il provino ha visto «la testa è venti pixel e la
##    ricevuta non esiste». È anche, per pura coincidenza utile,
##    `Percezione.RAGGIO`: fin dove un vicino si accorge di un gesto. Le due
##    domande sono diverse (vedi il blocco in cima a `Deduzioni.gd`) e questa
##    riga pretende che restino diverse — se un domani qualcuno le fondesse,
##    diventa rossa.
func _il_raggio_e_quello_a_cui_una_testa_si_legge(t) -> void:
	t.ok(DED.RAGGIO < PERCEZIONE.RAGGIO,
			"la ricevuta ha il raggio CORTO: si legge una testa da più vicino di quanto "
					+ "un vicino si accorga di un gesto (%.1f m contro %.1f m)"
					% [DED.RAGGIO, PERCEZIONE.RAGGIO])
	for prova in [[2.0, true], [9.0, false]]:
		var m = _mondo()
		var id := _uno(m)
		var corpo: Corpo = t.stage(Corpo.new())
		m.osserva(id, m.V_ANNAFFIA, Vector3(0, 0, -12), -1)
		m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
		# di FIANCO: Mochi non deve finire sulla linea di sguardo
		t.eq(_paga(m, id, corpo, 0, Vector3(float(prova[0]), 0, 0)), bool(prova[1]),
				"con Mochi a %.0f m la ricevuta %s"
						% [float(prova[0]),
						"si paga: la testa riempie lo schermo" if bool(prova[1])
								else "tace: il provino lì ha visto venti pixel"])
		m.free()


## IL COLLO DEVE ARRIVARCI, o non si paga niente — e la deduzione ASPETTA.
##
## È il difetto che la suite non poteva vedere e che ha trovato la prova viva
## (`tools/prova_deduzione.gd`): col posto a 148° dal muso, la testa si ferma
## al tetto del rig a 45° e restano **102° di scarto**. Nella Fase 4 quella
## mezza girata bastava (il gesto vero è già davanti al giocatore); qui la
## testa È tutta la scena, e una testa che punta altrove non è una premessa.
##
## E la prova che ASPETTA invece di rinunciare: girato il corpo, la stessa
## deduzione riceve la sua ricevuta.
func _il_collo_deve_arrivarci(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	var corpo: Corpo = t.stage(Corpo.new())
	# il posto è dietro le spalle: il rig guarda −Z, quindi +Z è alle spalle
	m.osserva(id, m.V_ANNAFFIA, Vector3(0, 0, 12), -1)
	m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
	var i := int(m.deduzione_muta(id, SOGLIA))
	t.ok(i >= 0, "la deduzione c'è ed è muta")
	t.ok(not _paga(m, id, corpo, i, corpo.global_position, Vector3(0, 0, 12)),
			"col posto alle spalle la ricevuta NON si paga")
	t.eq(corpo.guardato.size(), 0, "e la testa non si gira a vuoto")
	t.ok(int(m.deduzione_muta(id, SOGLIA)) >= 0,
			"la deduzione però resta lì: aspetta il suo momento")

	# passa un minuto di villaggio: continua ad aspettare, non muore per questo
	_passano(m, 60.0)
	t.ok(not _paga(m, id, corpo, 0, corpo.global_position, Vector3(0, 0, 12)),
			"e continua a non pagarsi")

	# poi il vicino si gira (cammina, cambia mestiere: succede da solo)
	_gira(corpo, PI)
	t.ok(_paga(m, id, corpo, 0, corpo.global_position, Vector3(0, 0, 12)),
			"e appena si gira, la ricevuta si paga")
	t.eq(corpo.guardato.size(), 1, "e la testa si gira UNA volta, quella giusta")

	# LA VALVOLA MORDE ESATTAMENTE SUL TETTO DEL RIG, e si misura girando il
	# corpo di un pelo più in là: lo stesso posto, lo stesso vicino, e la
	# risposta cambia. Il numero non è di questo file — è
	# `Visitor.tetto_ricevuta()`, e se un domani si ritara il collo questa
	# misura lo segue invece di mentire.
	var tetto := float(VISITOR.tetto_ricevuta())
	t.ok(tetto > 0.0 and tetto < VISITOR.TESTA_MAX,
			"il tetto della ricevuta sta sotto TESTA_MAX (%.3f < %.2f)"
					% [tetto, VISITOR.TESTA_MAX])
	for prova in [[tetto - 0.05, true], [tetto + 0.05, false]]:
		var m2 = _mondo()
		var id2 := _uno(m2)
		var c2: Corpo = t.stage(Corpo.new())
		_gira(c2, float(prova[0]))
		m2.osserva(id2, m2.V_ANNAFFIA, Vector3(0, 0, -12), -1)
		m2.deduci(id2, _ob(m2, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
		t.eq(_paga(m2, id2, c2, 0, c2.global_position), bool(prova[1]),
				"girato di %.3f rad (tetto %.3f): la ricevuta %s"
						% [float(prova[0]), tetto, "si paga" if bool(prova[1]) else "aspetta"])
		m2.free()
	m.free()


## ⚠️ **E LA PROMESSA DEL COLLO LA MANTIENE IL RIG — o il tetto è un numero
## che non vuol dire niente.**
##
## `collo_ci_arriva()` promette una cosa sola: *se gli si chiedesse di
## guardare lì, la testa ci arriverebbe davvero*. Le sonde qui sopra la
## giudicano contro `tetto_ricevuta()`, cioè contro sé stessa: portando il
## tetto a π resterebbero tutte verdi, e il gioco tornerebbe a pagare
## ricevute su posti che il collo non raggiunge — che è ESATTAMENTE il
## difetto che la prova viva aveva trovato (`tools/prova_deduzione.gd`: col
## posto a 148° la testa si ferma a 45°, e restano 102° di scarto).
##
## Qui invece la promessa si VERIFICA, facendo girare il rig vero: si chiede
## al collo, poi si gira la testa per davvero (`guarda_gesto` + tre quarti di
## secondo di `_process`) e si misura quanto le manca. È la stessa misura
## della prova viva, ridotta a due righe che girano in CI.
##
## MISURATO su questo banco, tre corse identiche (è deterministico):
##   · posto a 34°, il collo dice SÌ  → gliene manca **0.0057 rad (0.3°)**
##   · posto a 148°, il collo dice NO → gliene mancano **1.8128 rad (103.9°)**
## E i 103.9° sono gli stessi 102° che aveva misurato la prova viva nel
## MainLevel: due banchi diversi, lo stesso numero.
##
## Le tolleranze stanno sul residuo MISURATO, non a occhio. 0.20 rad perché
## il residuo vero è 0.006 e quello che può crescere onestamente è il vagare
## della mira (`VAGA_AMPIEZZA + MIRA_PERSONALE` = 0.125): sotto quella soglia
## ci sta il vagare, sopra ci sta solo una testa ferma. 1.00 rad è poco più
## di metà dello scarto vero — e la distanza fra i due casi è di due ordini
## di grandezza, quindi non c'è nessuna banda grigia da tarare.
##
## ⚠️ E questa è la sola asserzione del file che legge `collo_ci_arriva`
## DIRETTAMENTE: tutte le altre ci passano attraverso `Deduzioni.consegna`.
## Le due cose sono diverse — quella dice «la valvola è cablata», questa dice
## «la valvola dice il vero».
func _la_promessa_del_collo_la_mantiene_il_rig(t) -> void:
	# due posti alla STESSA distanza: uno davanti, uno a 148° (l'angolo
	# misurato nel MainLevel vero, che è come si è scoperta questa valvola)
	# ⚠️ IL POSTO RAGGIUNGIBILE NON STA DAVANTI, e non è un dettaglio: davanti
	# la testa è GIÀ puntata, e il residuo resterebbe minuscolo anche se
	# `guarda_gesto` non facesse niente — cioè l'asserzione non proverebbe
	# nulla. Sta a 34°, dentro il tetto (0.775 rad) ma abbastanza fuori da
	# pretendere che il collo si muova per davvero.
	var casi := [
		[Vector3(0, 0, -12.0).rotated(Vector3.UP, 0.60), true,
				"a 34°, dentro il tetto del collo", 0.20],
		[Vector3(6.4, 0, 10.2), false, "a 148°, dietro la spalla", 1.00],
	]
	for caso in casi:
		var corpo: Corpo = t.stage(Corpo.new())
		_gira(corpo, 0.0)
		corpo._enter_state("r_idle")
		corpo._timer = 9999.0
		var posto: Vector3 = caso[0]
		var arriva: bool = bool(corpo.collo_ci_arriva(posto))
		t.eq(arriva, bool(caso[1]), "il collo %s a un posto %s"
				% ["ci arriva" if bool(caso[1]) else "NON ci arriva", str(caso[2])])
		# e adesso glielo si chiede davvero
		corpo.guarda_gesto(posto, 6.0)
		for _i in 45:
			corpo._process(1.0 / 60.0)
		var manca := _scarto_del_collo(corpo, posto)
		if bool(caso[1]):
			t.ok(manca <= float(caso[3]),
					"…e infatti la testa ci arriva: le mancano %.3f rad (%.1f°)"
							% [manca, rad_to_deg(manca)])
		else:
			t.ok(manca >= float(caso[3]),
					"…e infatti la testa resta al tetto: le mancano %.3f rad (%.1f°)"
							% [manca, rad_to_deg(manca)])


## QUANTO MANCA ALLA TESTA per puntare quel posto, adesso. Lo stesso `look_at`
## di `Visitor._sguardo_testimone` — mai un `atan2`, che è il segno che questo
## progetto ha già sbagliato una volta (il fantasma del congedo di spalle a
## Mochi per mesi).
func _scarto_del_collo(corpo: Node3D, posto: Vector3) -> float:
	var h: Node3D = corpo.get("_head")
	if h == null:
		return TAU
	var b := posto
	b.y = h.global_position.y
	var adesso: float = h.rotation.y
	var prima := h.transform.basis
	h.look_at(b, Vector3.UP)
	var voluto := wrapf(h.rotation.y, -PI, PI)
	h.transform.basis = prima
	return absf(wrapf(voluto - adesso, -PI, PI))


## ⚠️ **L'ANCORA SI SCEGLIE FRA I PERCHÉ VERI: si mostra quello che si LEGGE.**
##
## Uno sguardo è una DIREZIONE, non un punto, e il giocatore la giudica dallo
## stesso vertice da cui la vede: il corpo del vicino. Se la testa punta di
## qua e le gambe vanno di là, quello che si vede sono due cose senza
## rapporto — cioè la conseguenza inattribuibile che questa fase esiste per
## rendere impossibile.
##
## Qui il vicino ha due ricordi veri: uno FRESCO alle sue spalle e uno più
## vecchio nella direzione in cui andrà. La regola («il più pesante») non
## cambia: cambia il campo su cui si applica, e il campo sono i perché che
## stanno nella direzione giusta. Tutti e due sono veri, quindi non si sta
## ammorbidendo niente — si sta indicando quello che il gesto sa indicare.
##
## E la controprova che il filtro NON è decorativo: la stessa deduzione, la
## stessa geometria, apertura zero («non filtrare») → si torna a guardare il
## fresco alle spalle.
func _l_ancora_si_sceglie_fra_i_perche_veri(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	var corpo: Corpo = t.stage(Corpo.new())
	var meta := Vector3(0, 0, -14)          # dove andrà: davanti a lui
	m.osserva(id, m.V_COSTRUISCE, Vector3(0.5, 0, -12), -1)  # il vecchio, DAVANTI
	_passano(m, 60.0)
	m.osserva(id, m.V_ANNAFFIA, Vector3(0, 0, 11), -1)       # il fresco, DIETRO
	m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0, 1]), SOGLIA)

	var ritmo: Dictionary = m.debug_ritmo()
	var righe: Array = m.debug_grafo(id)["ricordi"]
	t.ok(float(m.debug_grafo_peso(righe[1], ritmo["tempo"], ritmo["mezza_vita"]))
			> float(m.debug_grafo_peso(righe[0], ritmo["tempo"], ritmo["mezza_vita"])),
			"il ricordo dietro le spalle è il più pesante dei due")

	var senza: Vector3 = m.deduzione_dove(id, 0, corpo.global_position, meta, 0.0)
	t.almost(senza.z, 11.0, "senza filtro si guarda il più pesante: quello dietro", 1e-4)
	var con: Vector3 = m.deduzione_dove(id, 0, corpo.global_position, meta, DED.APERTURA)
	t.almost(con.z, -12.0, "col filtro si guarda l'altro, che è vero uguale", 1e-4)
	t.almost(con.x, 0.5, "e ci si guarda per intero, non a metà strada", 1e-4)

	# E LA RICEVUTA SI PAGA su quello: il collo ci arriva, perché è davanti.
	t.ok(_paga(m, id, corpo, 0, corpo.global_position, meta),
			"la ricevuta si paga sull'ancora che si legge")
	t.almost(((corpo.guardato[0] as Array)[0] as Vector3).z, -12.0,
			"e la testa si gira PROPRIO lì", 1e-4)
	m.free()

	# ── E UN PERCHÉ SOTTO I PROPRI PIEDI NON SI MOSTRA MAI, nemmeno senza
	# filtro: un collo non guarda dove sta. Prima era una rinuncia (se il più
	# pesante era lì, la ricevuta non si pagava affatto); adesso è una scelta,
	# e si mostra il perché dopo — che è vero uguale.
	var m3 = _mondo()
	var id3 := _uno(m3)
	var c3: Corpo = t.stage(Corpo.new())
	c3.position = Vector3(4, 0, 4)
	m3.osserva(id3, m3.V_COSTRUISCE, Vector3(4, 0, -8), -1)  # il vecchio, lontano
	_passano(m3, 60.0)
	m3.osserva(id3, m3.V_ANNAFFIA, Vector3(4, 0, 4), -1)     # il fresco, SOTTO I PIEDI
	m3.deduci(id3, _ob(m3, "provvedi_cura"), PackedInt32Array([0, 1]), SOGLIA)
	var senza_filtro: Vector3 = m3.deduzione_dove(id3, 0, c3.global_position,
			Vector3.ZERO, 0.0)
	t.almost(senza_filtro.z, -8.0,
			"il perché sotto i piedi si salta, e si mostra l'altro", 1e-4)
	t.ok(_paga(m3, id3, c3, 0, c3.global_position, Vector3(4, 0, -10)),
			"e così la ricevuta si paga invece di morire")
	m3.free()


## ⚠️ **E SE NESSUN PERCHÉ STA DALLA PARTE GIUSTA, SI TACE.** È il degrado di
## questo progetto — meglio nessuna conseguenza che una inattribuibile — e
## non è una rinuncia: la deduzione resta muta e il vicino, che si gira di
## continuo e cambia posto, avrà un'altra occasione.
##
## LA VALVOLA MORDE SULL'APERTURA, e si misura mettendo la meta un pelo di
## qua e un pelo di là dello stesso cono: stessa deduzione, stesso ricordo,
## e la risposta cambia. Il numero non è di questo file.
func _un_ancora_che_punta_altrove_non_si_mostra(t) -> void:
	t.ok(DED.APERTURA > 0.0 and DED.APERTURA < PI * 0.5,
			"l'apertura della ricevuta è un cono vero (%.1f°)" % rad_to_deg(DED.APERTURA))
	var ancora := Vector3(0, 0, -12)
	for prova in [[DED.APERTURA - 0.06, true], [DED.APERTURA + 0.06, false]]:
		var m = _mondo()
		var id := _uno(m)
		var corpo: Corpo = t.stage(Corpo.new())
		m.osserva(id, m.V_ANNAFFIA, ancora, -1)
		m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
		# la meta alla stessa distanza, ruotata attorno al corpo
		var meta: Vector3 = ancora.rotated(Vector3.UP, float(prova[0]))
		t.eq(_paga(m, id, corpo, 0, corpo.global_position, meta), bool(prova[1]),
				"meta a %.1f° dall'ancora (apertura %.1f°): la ricevuta %s"
						% [rad_to_deg(float(prova[0])), rad_to_deg(DED.APERTURA),
						"si paga" if bool(prova[1]) else "tace"])
		t.eq(int(_deduzioni(m, id)[0]["bandiere"]) == 0, not bool(prova[1]),
				"e la deduzione %s" % ("è spesa a metà" if bool(prova[1]) else "aspetta ancora"))
		m.free()


## ⚠️ **L'APERTURA GIUDICATA CON NUMERI CHE NON SONO L'APERTURA.**
##
## Stessa storia del raggio: le sonde a `APERTURA ± 0.06` dicono che il cono
## esiste, non che è largo quanto serve. E qui sbagliare costa da tutte e due
## le parti, perché questo numero ha già avuto una versione sbagliata: la
## prima idea era chiedere che i due POSTI coincidessero, e con due metri di
## tolleranza sopravvivevano **8 deduzioni su 100** — cioè il canale spento,
## con la suite verde.
##
## I due numeri di fuori:
##
##  · **20°** è il MASSIMO che il villaggio vero produce fra il posto
##    guardato e la meta (`tools/misura_attribuzione.gd`, su tutto ciò che la
##    grammatica può generare: mediana 0–12°, massimo 20°). Un cono che non
##    ammette il suo stesso massimo è un cono che spegne il canale;
##  · **45°** è il gradino a cui il provino ha visto il corpo «uscire
##    dall'inquadratura da un'altra parte» (`tools/provino_ricevuta.gd`,
##    provino 2, la camera vera). Lì la ricevuta non deve pagarsi, o si torna
##    a mostrare un'occhiata di qua e un viaggio di là.
func _l_apertura_ammette_quel_che_il_villaggio_produce(t) -> void:
	var ancora := Vector3(0, 0, -12)
	for prova in [[20.0, true], [45.0, false]]:
		var m = _mondo()
		var id := _uno(m)
		var corpo: Corpo = t.stage(Corpo.new())
		m.osserva(id, m.V_ANNAFFIA, ancora, -1)
		m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
		var meta: Vector3 = ancora.rotated(Vector3.UP, deg_to_rad(float(prova[0])))
		t.eq(_paga(m, id, corpo, 0, corpo.global_position, meta), bool(prova[1]),
				"meta a %.0f° dall'ancora: la ricevuta %s" % [float(prova[0]),
						"si paga (è il massimo che il villaggio produce)" if bool(prova[1])
								else "tace (lì il provino ha visto due cose diverse)"])
		m.free()


## ⚠️ **E SENZA UNA META NON SI PAGA NIENTE.** La ricevuta prefigura una
## conseguenza: se il mondo non ha una strada per quell'obiettivo non c'è
## nessuna conseguenza da prefigurare, e nemmeno nessuna direzione a cui
## legare lo sguardo. Si tace, e si riprova quando il mondo si riapre — il
## degrado va verso il silenzio, che qui è l'esito buono.
func _senza_una_meta_non_si_paga_niente(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	var corpo: Corpo = t.stage(Corpo.new())
	m.osserva(id, m.V_ANNAFFIA, Vector3(0, 0, -12), -1)
	m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)

	# col mondo chiuso il risolutore non ha nessuna catena: niente meta
	t.ok(DED.meta_del_gesto(m, id, 0, _luoghi_vuoti(), _fatti_pieni(m)).is_empty(),
			"col mondo chiuso non c'è nessuna meta")
	t.ok(not DED.consegna(m, id, corpo, 0, corpo.global_position,
			_luoghi_vuoti(), _fatti_pieni(m)),
			"e quindi la ricevuta non si paga")
	t.eq(corpo.guardato.size(), 0, "la testa non si gira a vuoto")
	t.ok(int(m.deduzione_muta(id, SOGLIA)) >= 0, "la deduzione aspetta")

	# e senza i cinque luoghi (il villaggio non ha ancora i fatti) nemmeno
	t.ok(DED.meta_del_gesto(m, id, 0, [], _fatti_pieni(m)).is_empty(),
			"e senza i cinque luoghi non c'è meta")

	# LA META NON È UNA TABELLA SCRITTA A MANO: la dice il risolutore, e
	# ognuno dei quattro obiettivi finisce nel SUO luogo.
	var atteso := {"provvedi_pancino": "cibo", "provvedi_cura": "aiuola",
			"provvedi_energia": "seduta", "provvedi_meraviglia": "bello"}
	for ob in atteso:
		var m2 = _mondo()
		var id2 := _uno(m2)
		m2.osserva(id2, m2.V_ANNAFFIA, Vector3(0, 0, -12), -1)
		m2.deduci(id2, _ob(m2, str(ob)), PackedInt32Array([0]), SOGLIA)
		var meta: Dictionary = DED.meta_del_gesto(m2, id2, 0, _luoghi_pieni(), _fatti_pieni(m2))
		t.eq(str(meta.get("luogo", "")), str(atteso[ob]),
				"«%s» porta al luogo «%s»" % [ob, atteso[ob]])
		m2.free()
	m.free()


## ⚠️ **E IL FILO DEVE ESSERE ATTACCATO A MOCHI, non al vicino.**
##
## Il difetto di partenza NON era dentro `consegna`: era la riga che la
## chiama. Un `consegna` perfetto a cui il registro passa la posizione del
## vicino invece di quella del giocatore rimette il gioco esattamente
## com'era, **con tutti i casi qui sopra verdi** — la falsificazione l'ha
## misurato: sostituendo l'argomento, nessuna asserzione si accorgeva di
## niente.
##
## Perciò questo caso non guarda `Deduzioni`: guarda **il registro**. Si
## istanzia `Visitors` senza albero (l'idioma di `test_cablaggio`: il suo
## `_ready` non parte, e `_cuore_di` è una funzione come le altre), gli si
## dà un cuore vero e un finto Mochi, e si sposta SOLO Mochi. Se il filo è
## attaccato a lei, la risposta cambia; se è attaccato al vicino, no.
func _il_registro_passa_dove_sta_mochi(t) -> void:
	for lontana in [true, false]:
		var m = _mondo()
		var id := _uno(m)
		var corpo: Corpo = t.stage(Corpo.new())
		m.osserva(id, m.V_ANNAFFIA, Vector3(0, 0, -12), -1)
		m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)

		var v = VISITORS.new()
		var mochi: Node3D = t.stage(Node3D.new())
		mochi.position = Vector3(0, 0, DED.RAGGIO + 30.0) if lontana \
				else Vector3(DED.RAGGIO * 0.5, 0, 0)
		v._ecs = m
		v._player = mochi
		var r := {"ecs": id, "label": "Prova", "cell": Vector2i(0, 0),
				"dna": {"name": "Prova"}, "brain": {},
				"luoghi": _luoghi_verso(Vector3(0, 0, -12)),
				"fatti": _fatti_pieni(m),
				# il contatore sfalsato: senza, il primo giro esce subito
				"cuore_scad": 0.0, "promosso_oggi": true}
		v._cuore_di(r, corpo)
		t.eq(corpo.guardato.size(), 0 if lontana else 1,
				"con Mochi %s il registro %s la ricevuta"
						% ["lontana" if lontana else "vicina",
						"non paga" if lontana else "paga"])
		t.eq(int(_deduzioni(m, id)[0]["bandiere"]) == 0, lontana,
				"e la deduzione %s" % ("aspetta ancora" if lontana else "ha il suo bit"))
		v.free()
		m.free()

	# ── E SENZA NESSUN GIOCATORE non si paga niente. È il caso dei banchi di
	# prova e del diorama del titolo, ed è l'unico posto della classe in cui
	# il degrado va verso il SILENZIO invece che verso «come si è sempre
	# fatto»: `_dove_sta_mochi` ripiega su `home` perché di là un'ancora che
	# non si sposta è il comportamento di sempre; qui ripiegare vorrebbe dire
	# pagare una ricevuta a nessuno.
	var m2 = _mondo()
	var id2 := _uno(m2)
	var c2: Corpo = t.stage(Corpo.new())
	m2.osserva(id2, m2.V_ANNAFFIA, Vector3(0, 0, -12), -1)
	m2.deduci(id2, _ob(m2, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
	var v2 = VISITORS.new()
	v2._ecs = m2
	v2._player = null
	v2._cuore_di({"ecs": id2, "label": "Prova", "cell": Vector2i(0, 0),
			"dna": {"name": "Prova"}, "brain": {},
			"luoghi": _luoghi_verso(Vector3(0, 0, -12)), "fatti": _fatti_pieni(m2),
			"cuore_scad": 0.0, "promosso_oggi": true}, c2)
	t.eq(c2.guardato.size(), 0, "senza nessun giocatore la testa non si gira")
	t.eq(int(_deduzioni(m2, id2)[0]["bandiere"]), 0, "e la deduzione resta muta")
	v2.free()
	m2.free()


## LA RICEVUTA DEVE AVERE IL SUO TEMPO. Una testa che si gira e un corpo che
## parte nello stesso frame non sono una premessa e una conseguenza: sono
## un'unica cosa illeggibile.
func _la_ricevuta_deve_avere_il_suo_tempo(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	var corpo: Corpo = t.stage(Corpo.new())
	m.osserva(id, m.V_ANNAFFIA, Vector3(0, 0, -12), -1)
	m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
	_paga(m, id, corpo, int(m.deduzione_muta(id, SOGLIA)), corpo.global_position)

	t.eq(int(m.deduzione_pronta(id, SOGLIA, DED.ATTESA, 0.0)), -1,
			"nell'istante della ricevuta non è ancora pronta")
	_passano(m, DED.ATTESA * 0.5)
	t.eq(int(m.deduzione_pronta(id, SOGLIA, DED.ATTESA, 0.0)), -1,
			"a metà sguardo nemmeno")
	_passano(m, DED.ATTESA)
	t.ok(int(m.deduzione_pronta(id, SOGLIA, DED.ATTESA, 0.0)) >= 0,
			"passato lo sguardo, sì")
	m.free()


## E SCADE. Passata la finestra, la premessa non è più in mente a nessuno:
## una conseguenza che arriva dopo è una conseguenza slegata.
func _la_ricevuta_scade(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	var corpo: Corpo = t.stage(Corpo.new())
	var fin := DED.finestra(m)
	m.osserva(id, m.V_ANNAFFIA, Vector3(0, 0, -12), -1)
	m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
	_paga(m, id, corpo, int(m.deduzione_muta(id, SOGLIA)), corpo.global_position)

	_passano(m, fin * 0.5)
	t.ok(int(m.deduzione_pronta(id, SOGLIA, DED.ATTESA, fin)) >= 0,
			"dentro la finestra è pronta")
	_passano(m, fin)
	t.eq(int(m.deduzione_pronta(id, SOGLIA, DED.ATTESA, fin)), -1,
			"oltre la finestra è scaduta")
	t.ok(float(_deduzioni(m, id)[0]["peso"]) > SOGLIA,
			"e non perché il ricordo si è spento: pesa ancora")
	t.ok(int(m.deduzione_pronta(id, SOGLIA, DED.ATTESA, 0.0)) >= 0,
			"tant'è che senza scadenza sarebbe ancora pronta")
	m.free()


# =========================================================================
# 3. IL DIROTTAMENTO
# =========================================================================

## LE DUE TRADUZIONI SONO DERIVATE da `Piani.OBIETTIVO`, non ricopiate: si
## fa il giro completo su tutte e quattro le coppie.
func _le_due_traduzioni_sono_derivate(t) -> void:
	var m = _mondo()
	for act in PIANI.OBIETTIVO:
		var ob := str(PIANI.OBIETTIVO[act])
		t.eq(DED.azione_di(ob), str(act), "«%s» torna all'azione «%s»" % [ob, act])
		t.eq(DED.nome_obiettivo(m, _ob(m, ob)), ob, "e la maschera di «%s» torna al nome" % ob)
	t.eq(DED.azione_di("provvedi_niente"), "", "un obiettivo che non esiste non ha azione")
	t.eq(DED.nome_obiettivo(m, 0), "", "e la maschera vuota non ha nome")
	m.free()


## UNA DEDUZIONE PRONTA CAMBIA L'AZIONE — e la cambia in quella che
## l'obiettivo dedotto serve, non in una a caso.
func _una_deduzione_pronta_cambia_l_azione(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	var corpo: Corpo = t.stage(Corpo.new())
	m.osserva(id, m.V_ANNAFFIA, Vector3(0, 0, -12), -1)
	m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
	_paga(m, id, corpo, int(m.deduzione_muta(id, SOGLIA)), corpo.global_position)
	_passano(m, DED.ATTESA + 1.0)

	var act := str(DED.dirotta(m, id, "spuntino", _luoghi_pieni(), _fatti_pieni(m), SOGLIA))
	t.eq(act, "cura_giardino",
			"chi ha dedotto «provvedi_cura» va a curare, non a sgranocchiare")
	m.free()


## E SI SPENDE UNA VOLTA SOLA: senza questo bit sarebbe la priorità di quel
## vicino per sempre, cioè un vicino inchiodato a una cosa che si è
## immaginata.
func _si_spende_una_volta_sola(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	var corpo: Corpo = t.stage(Corpo.new())
	m.osserva(id, m.V_ANNAFFIA, Vector3(0, 0, -12), -1)
	m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
	_paga(m, id, corpo, int(m.deduzione_muta(id, SOGLIA)), corpo.global_position)
	_passano(m, DED.ATTESA + 1.0)

	t.eq(str(DED.dirotta(m, id, "spuntino", _luoghi_pieni(), _fatti_pieni(m), SOGLIA)),
			"cura_giardino", "la prima volta dirotta")
	t.eq(str(DED.dirotta(m, id, "spuntino", _luoghi_pieni(), _fatti_pieni(m), SOGLIA)),
			"spuntino", "la seconda no")
	t.eq(int(m.deduzione_pronta(id, SOGLIA, DED.ATTESA, 0.0)), -1,
			"ed è spesa per sempre")
	m.free()


## SE IL MONDO NON HA UNA STRADA NON SI DIROTTA NIENTE — mai un piano a
## metà. E la deduzione si spende lo stesso: la sua occasione era quella.
func _senza_una_strada_non_si_dirotta(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	var corpo: Corpo = t.stage(Corpo.new())
	m.osserva(id, m.V_ANNAFFIA, Vector3(0, 0, -12), -1)
	m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
	_paga(m, id, corpo, int(m.deduzione_muta(id, SOGLIA)), corpo.global_position)
	_passano(m, DED.ATTESA + 1.0)

	# controprova: con i luoghi pieni dirotterebbe (è lo stesso banco)
	t.ok(not (m.pianifica(_fatti_pieni(m), _ob(m, "provvedi_cura"),
			PIANI.cammino(_luoghi_pieni())) as PackedInt32Array).is_empty(),
			"col mondo aperto una strada c'è")
	t.ok((m.pianifica(_fatti_pieni(m), _ob(m, "provvedi_cura"),
			PIANI.cammino(_luoghi_vuoti())) as PackedInt32Array).is_empty(),
			"col mondo chiuso no")

	t.eq(str(DED.dirotta(m, id, "spuntino", _luoghi_vuoti(), _fatti_pieni(m), SOGLIA)),
			"spuntino", "senza strada l'azione non cambia")
	t.eq(int(m.deduzione_pronta(id, SOGLIA, DED.ATTESA, 0.0)), -1,
			"ma l'occasione è stata spesa: non si riprova fra un minuto")
	# e senza abbastanza luoghi (il villaggio non ha ancora i fatti) nemmeno
	m.free()


## E QUELLO CHE L'AGENDA VOLEVA GIÀ NON È UN DIROTTAMENTO: nessuna ricevuta
## da riscuotere, niente da vedere, e la deduzione si spegne senza rumore.
func _quello_che_l_agenda_voleva_gia_non_e_un_dirottamento(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	var corpo: Corpo = t.stage(Corpo.new())
	m.osserva(id, m.V_ANNAFFIA, Vector3(0, 0, -12), -1)
	m.deduci(id, _ob(m, "provvedi_cura"), PackedInt32Array([0]), SOGLIA)
	_paga(m, id, corpo, int(m.deduzione_muta(id, SOGLIA)), corpo.global_position)
	_passano(m, DED.ATTESA + 1.0)
	t.eq(str(DED.dirotta(m, id, "cura_giardino", _luoghi_pieni(), _fatti_pieni(m), SOGLIA)),
			"cura_giardino", "l'azione resta quella che era")
	t.eq(int(m.deduzione_pronta(id, SOGLIA, DED.ATTESA, 0.0)), -1, "e si spende")
	m.free()


# =========================================================================
# 4. LA GRAMMATICA, e il giro chiuso
# =========================================================================

## Il ritratto di prova: tre ricordi vivi e un obiettivo già in corso.
func _rit(m) -> Dictionary:
	var costanti: Dictionary = m.debug_grafo_costanti()
	var verbi := []
	for i in int(costanti["n_verbi"]):
		verbi.append(str(m.nome_verbo(i)))
	var cose := []
	for i in int(costanti["n_cose"]):
		cose.append(str(m.nome_cosa(i)))
	return {
		"nome": "la volpina Papavero", "eta": "giovane",
		"indole": ["goloso"], "quirk": "",
		"azione": "riposo", "obiettivo": "provvedi_energia",
		"protagonista": "Mochi", "compito": "pensiero",
		"stagione": "autunno", "momento": "pomeriggio",
		"nomi": {}, "verbi": verbi, "cose": cose,
		"gusto": PackedFloat64Array([1, 1, 1, 1, 1, 1]),
		"tinte": {"ammirazione": 1.4, "gratitudine": 0.0,
				"interesse": PackedFloat64Array([0, 0, 0, 0, 0, 0])},
		"ora": 900.0, "mezza_vita": 120.0,
		"pesi": PackedFloat64Array([2.4, 1.2, 0.6]),
		"bandiere": {"sentito": int(costanti["r_sentito"]),
				"su_di_me": int(costanti["r_su_di_me"]),
				"detto": int(costanti["r_detto"]),
				"nessuno": int(costanti["sogg_nessuno"])},
		"ricordi": [
			{"verbo": 0, "bandiere": 0, "quante": 1, "px": 5.0, "pz": 7.0,
					"quando": 880.0, "soggetto": int(costanti["sogg_nessuno"])},
			{"verbo": 3, "bandiere": 0, "quante": 1, "px": 9.0, "pz": 2.0,
					"quando": 860.0, "soggetto": int(costanti["sogg_nessuno"])},
			{"verbo": 5, "bandiere": 0, "quante": 1, "px": 1.0, "pz": 1.0,
					"quando": 300.0, "soggetto": int(costanti["sogg_nessuno"])},
		],
	}


## Nessun letterale scritto a mano: gli obiettivi vengono da `Piani`, le
## righe da `fatti()`. E quello che il vicino sta già facendo esce.
func _la_grammatica_viene_dalle_enum(t) -> void:
	var m = _mondo()
	var rit := _rit(m)
	var g := str(SUG.grammatica_deduzione(rit))
	t.ok(g != "", "con tre ricordi vivi una grammatica c'è")

	var offerti := SUG.obiettivi_deducibili(rit)
	t.ok(not offerti.has("provvedi_energia"),
			"quello che sta già facendo non è deducibile")
	for o in offerti:
		t.ok(_ob(m, str(o)) != 0, "«%s» ha una maschera vera nel ponte" % str(o))
		t.ok(g.contains("\\\"%s\\\"" % str(o)), "«%s» è nella grammatica" % str(o))
	for act in PIANI.OBIETTIVO:
		var nome := str(PIANI.OBIETTIVO[act])
		if not offerti.has(nome):
			t.ok(not g.contains("\\\"%s\\\"" % nome),
					"«%s» NON è nella grammatica" % nome)

	# e il filtro della fattibilità toglie davvero
	var stretto := rit.duplicate()
	stretto["fattibili"] = ["provvedi_cura"]
	t.eq(SUG.obiettivi_deducibili(stretto), ["provvedi_cura"],
			"col mondo che serve una cosa sola, se ne offre una sola")
	stretto["fattibili"] = ["provvedi_energia"]
	t.eq(SUG.obiettivi_deducibili(stretto).size(), 0,
			"e se l'unico fattibile è quello che sta già facendo, si tace")
	t.eq(str(SUG.grammatica_deduzione(stretto)), "",
			"senza obiettivi non c'è grammatica")
	m.free()


## IL GIRO CHIUSO, ed è la guardia vera di tutta la grammatica: **tutto ciò
## che questa grammatica può produrre, il gioco lo sa incassare**. Le
## alternative sono finite e si enumerano, quindi non è un campione: è
## l'insieme.
##
## Se un domani qualcuno allargasse la grammatica (un obiettivo in più, una
## riga in più, uno spazio in più) e il collaudo non lo seguisse, il modello
## camperebbe bozze che il gioco butta — cioè lettere che non arrivano mai,
## in silenzio. Qui invece diventa rosso.
func _tutto_cio_che_la_grammatica_produce_il_gioco_lo_incassa(t) -> void:
	var m = _mondo()
	var rit := _rit(m)
	var quante := 0
	for testo in _tutte_le_uscite(rit):
		var d := DED.da_json(str(testo))
		t.ok(not d.is_empty(), "«%s» si apre" % testo)
		var esito: Dictionary = GIU.utile(d, rit,
				{"fattibili": SUG.obiettivi_deducibili(rit)})
		t.ok(bool(esito["ok"]), "«%s» è azionabile (%s)" % [testo, str(esito["motivo"])])
		quante += 1
	t.ok(quante >= 12, "le uscite possibili sono parecchie (%d)" % quante)
	m.free()


## Le stringhe che la grammatica generata può produrre. Si ricostruiscono
## dalle stesse due liste da cui è fatta — se la FORMA della `root` cambia,
## il caso di sopra smette di provare la grammatica vera, e questo confronto
## col testo generato lo dice.
func _tutte_le_uscite(rit: Dictionary) -> Array:
	var g := str(SUG.grammatica_deduzione(rit))
	var out := []
	for o in SUG.obiettivi_deducibili(rit):
		for combo in SUG._sottoinsiemi(SUG.righe_vive(rit), SUG.PERCHE_MAX):
			var pezzi := []
			for i in combo:
				pezzi.append(str(int(i)))
			out.append("{\"obiettivo\":\"%s\",\"perche\":[%s]}" % [str(o), ",".join(pezzi)])
	# e la forma è davvero quella scritta nella grammatica
	if not g.contains("\"{\\\"obiettivo\\\":\" obiettivo \",\\\"perche\\\":[\" righe \"]}\""):
		return []
	return out


## NON C'È UN POSTO PER UNA FRASE. La grammatica delle lettere ha una classe
## di caratteri (`lettera ::= [...]`) perché le righe libere sono libere;
## questa non deve averne nessuna, o il modello potrebbe infilare del testo
## dentro un JSON che muove un corpo.
func _la_grammatica_non_ha_un_posto_per_una_frase(t) -> void:
	var m = _mondo()
	var g := str(SUG.grammatica_deduzione(_rit(m)))
	var quante := 0
	for riga in g.split("\n"):
		var s := str(riga).strip_edges()
		if s.begins_with("#") or s == "":
			continue
		# SI GUARDA FUORI DAI LETTERALI, e la distinzione è tutto il caso: la
		# parentesi quadra DENTRO le virgolette è il JSON («"perche":[»), che
		# è testo fisso; fuori è una classe di caratteri, cioè un posto in cui
		# il modello scrive quello che vuole.
		var nudo := _fuori_dai_letterali(s)
		t.ok(not nudo.contains("["), "nessuna classe di caratteri: «%s»" % s)
		t.ok(not nudo.contains("*") and not nudo.contains("+")
				and not nudo.contains("{"), "nessuna ripetizione aperta: «%s»" % s)
		quante += 1
	t.ok(quante >= 3, "e le regole guardate sono davvero tutte (%d)" % quante)

	# E PER CONFRONTO: quella delle LETTERE una classe ce l'ha, quindi il
	# controllo qui sopra sa distinguere le due cose invece di essere sempre
	# vero — che è il modo in cui una guardia diventa un ritratto.
	var lettera := _rit(m)
	lettera["compito"] = "lettera"
	var trovata := false
	for riga in str(SUG.grammatica(lettera)).split("\n"):
		if _fuori_dai_letterali(str(riga)).contains("["):
			trovata = true
	t.ok(trovata, "la grammatica delle lettere, invece, una classe ce l'ha")
	m.free()


## Quello che resta di una riga GBNF togliendone i letterali fra virgolette.
func _fuori_dai_letterali(riga: String) -> String:
	var out := ""
	var dentro := false
	var i := 0
	while i < riga.length():
		var c := riga.substr(i, 1)
		if dentro and c == "\\":
			i += 2
			continue
		if c == "\"":
			dentro = not dentro
			i += 1
			continue
		if not dentro:
			out += c
		i += 1
	return out


## NIENTE DOPPIONI E NIENTE PERMUTAZIONI: le combinazioni sono crescenti.
## Una regola ricorsiva le lascerebbe passare tutte e due — il doppione
## gonfia una catena senza renderla più solida, la permutazione è la stessa
## deduzione che il Giudice conterebbe come due bozze diverse.
func _niente_doppioni_e_niente_permutazioni(t) -> void:
	var righe := PackedInt32Array([2, 5, 9])
	var combo := SUG._sottoinsiemi(righe, SUG.PERCHE_MAX)
	t.eq(combo.size(), 7, "tre righe fanno sette sottoinsiemi (3 + 3 + 1)")
	var visti := {}
	for c in combo:
		var lista: Array = c
		t.ok(lista.size() >= 1 and lista.size() <= SUG.PERCHE_MAX,
				"ogni combinazione sta nel tetto")
		for k in range(1, lista.size()):
			t.ok(int(lista[k]) > int(lista[k - 1]), "gli indici crescono: %s" % str(lista))
		var chiave := str(lista)
		t.ok(not visti.has(chiave), "nessuna combinazione ripetuta: %s" % chiave)
		visti[chiave] = true
	# e il tetto morde
	t.eq(SUG._sottoinsiemi(righe, 1).size(), 3, "col tetto a uno restano i singoli")


func _senza_ricordi_non_c_e_grammatica(t) -> void:
	var m = _mondo()
	var vuoto := _rit(m)
	vuoto["ricordi"] = []
	vuoto["pesi"] = PackedFloat64Array()
	t.eq(SUG.righe_vive(vuoto).size(), 0, "senza ricordi non ci sono righe vive")
	t.eq(str(SUG.grammatica_deduzione(vuoto)), "", "e quindi nessuna grammatica")
	t.ok((SUG.parti_deduzione(vuoto) as Dictionary).is_empty(),
			"e nemmeno un prompt: si tace")
	# i ricordi SPENTI non contano: è la stessa potatura della lettera
	var spento := _rit(m)
	spento["pesi"] = PackedFloat64Array([0.0, 0.0, 0.0])
	t.eq(SUG.righe_vive(spento).size(), 0, "un ricordo spento non regge niente")
	m.free()


# =========================================================================
# 5. IL VETO, e la promessa
# =========================================================================

## UNA DEDUZIONE NON HA CAMPI LIBERI, e non ce li ha in nessuna delle due
## metà: né la grammatica sa scriverli (sopra), né il collaudo li accetta.
func _una_deduzione_non_ha_campi_liberi(t) -> void:
	var m = _mondo()
	var rit := _rit(m)
	var mondo := {"fattibili": SUG.obiettivi_deducibili(rit)}
	var buona := {"obiettivo": "provvedi_cura", "perche": [0]}
	t.ok(bool(GIU.utile(buona, rit, mondo)["ok"]), "la deduzione nuda passa")
	for campo in ["perche_dettagliato", "testo", "nota", "chi"]:
		var sporca := buona.duplicate()
		sporca[campo] = "perché mi ha fatto pensare a te"
		t.ok(not bool(GIU.utile(sporca, rit, mondo)["ok"]),
				"un campo libero «%s» la boccia" % campo)
	# e i due limiti del Giudice sulle catene
	var doppia := {"obiettivo": "provvedi_cura", "perche": [0, 0]}
	t.ok(not bool(GIU.utile(doppia, rit, mondo)["ok"]),
			"citare due volte lo stesso ricordo la boccia")
	# IL TETTO DELLA CATENA vuole un ritratto con abbastanza ricordi VIVI, o
	# la boccerebbe la regola di prima («si appoggia a un ricordo che non
	# c'è») e questa non proverebbe niente — che è esattamente com'era la
	# prima stesura di questo caso, e l'ha detto la falsificazione.
	var largo := _rit_largo(m, SUG.PERCHE_MAX + 1)
	var mondo_largo := {"fattibili": SUG.obiettivi_deducibili(largo)}
	var vive := SUG.righe_vive(largo)
	t.ok(vive.size() > SUG.PERCHE_MAX,
			"il banco largo ha più ricordi vivi del tetto (%d)" % vive.size())
	var corta := {"obiettivo": "provvedi_cura", "perche": []}
	for k in SUG.PERCHE_MAX:
		(corta["perche"] as Array).append(int(vive[k]))
	t.ok(bool(GIU.utile(corta, largo, mondo_largo)["ok"]),
			"una catena lunga esattamente quanto il tetto passa")
	var lunga := {"obiettivo": "provvedi_cura", "perche": (corta["perche"] as Array).duplicate()}
	(lunga["perche"] as Array).append(int(vive[SUG.PERCHE_MAX]))
	t.ok(not bool(GIU.utile(lunga, largo, mondo_largo)["ok"]),
			"una catena più lunga del tetto del ponte la boccia")
	m.free()


## Un ritratto con `quanti` ricordi tutti vivi e tutti diversi.
func _rit_largo(m, quanti: int) -> Dictionary:
	var rit := _rit(m)
	var nessuno := int((m.debug_grafo_costanti() as Dictionary)["sogg_nessuno"])
	var righe := []
	var pesi := PackedFloat64Array()
	for k in quanti:
		righe.append({"verbo": k % int(m.N_VERBI), "bandiere": 0, "quante": 1,
				"px": float(k), "pz": float(k * 2), "quando": 900.0 - k,
				"soggetto": nessuno})
		pesi.append(2.0 - 0.1 * k)
	rit["ricordi"] = righe
	rit["pesi"] = pesi
	return rit


## E SENZA MODELLO NON CAMBIA UN BIT. Nessuno chiama `incassa`, il
## componente resta vuoto, e le tre porte rispondono come se questa fase non
## esistesse. È la promessa dell'autore, e vale per la stragrande
## maggioranza dei giocatori.
func _senza_modello_non_cambia_un_bit(t) -> void:
	var m = _mondo()
	var id := _uno(m)
	var corpo: Corpo = t.stage(Corpo.new())
	m.osserva(id, m.V_ANNAFFIA, Vector3(5, 0, 7), -1)
	m.osserva(id, m.V_PESCA, Vector3(1, 0, 1), -1)

	t.eq(_deduzioni(m, id).size(), 0, "un vicino nasce senza deduzioni")
	t.eq(int(m.deduzione_muta(id, SOGLIA)), -1, "non c'è niente da mostrare")
	t.eq(int(m.deduzione_pronta(id, SOGLIA, 0.0, 0.0)), -1, "niente di pronto")
	t.ok(not _paga(m, id, corpo, 0, corpo.global_position), "e niente da consegnare")
	t.eq(corpo.guardato.size(), 0, "nessuna testa si gira")
	for act in ["spuntino", "riposo", "quattro_chiacchiere", "gironzola"]:
		t.eq(str(DED.dirotta(m, id, act, _luoghi_pieni(), _fatti_pieni(m), SOGLIA)), act,
				"«%s» resta «%s»" % [act, act])

	# e con un cuore che non c'è, tutte e tre le porte degradano verso il
	# silenzio invece che verso un errore (è il clone appena scaricato, dove
	# la GDExtension non è nemmeno compilata)
	t.eq(str(DED.dirotta(null, 0, "spuntino", _luoghi_pieni(), 0, SOGLIA)), "spuntino",
			"senza cuore non si dirotta")
	t.ok(not DED.consegna(null, 0, corpo, 0, corpo.global_position, _luoghi_pieni(), 0),
			"senza cuore non si consegna")
	t.eq(int((DED.incassa(null, 0, [{"obiettivo": "provvedi_cura", "perche": [0]}],
			{}) as Dictionary)["indice"]), -1, "senza cuore non si incassa")
	m.free()
