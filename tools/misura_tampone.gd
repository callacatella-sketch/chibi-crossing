extends SceneTree
## IL METRO DEL TAMPONE SOCIALE — quanto smorza, su chi, a che prezzo.
##
##   CHIBI_FORMA=420 CHIBI_VIVO=300 CHIBI_SEME=7 \
##       ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . \
##       --fixed-fps 60 --script res://tools/misura_tampone.gd
##
## La presenza della figura di attaccamento smorza l'allarme: `conforto`
## DIVIDE il guadagno di `Limbico.percepisci`. La suite non dice niente su
## questo — `percepisci` resta verde qualunque cosa il villaggio faccia con
## la sua risposta, e il conforto in partita dipende da tre cose che nessuna
## asserzione sa fabbricare insieme: due persone che sono una coppia, che si
## trovano entro `Visitors.VICINI`, e Mochi che arriva addosso in quel
## momento.
##
## Le sei domande, e nessuna ha una risposta booleana:
##
##  a) **LA MISURA APPAIATA**, sullo STESSO percetto. `percepisci` non è
##     pura (scrive `arousal`, `neuro` e `ultimo_sussulto`), quindi la gamba
##     controfattuale non si può prendere «più tardi»: si prende
##     un'ISTANTANEA dello stato di PRIMA — campo per campo, non con
##     `save()`/`load()`, che serializza e ricostruisce mezzo animo — e la si
##     rimette per rifare lo stesso identico percetto con `conforto = 0`.
##  b) **LA FIRMA 1** — lo smorzamento è più grande nei più REATTIVI: il
##     calo spezzato per terzili di `reattivita`.
##  c) **LA FIRMA 2** — la specificità: quanti percetti hanno un
##     NON-compagno visibile entro il raggio e nessun compagno, e quale
##     conforto hanno avuto. Dev'essere zero, e il numero che lo smentisce
##     è UNO.
##  d) **IL TETTO** — in quanti percetti l'allarme grezzo supera il divisore,
##     cioè dove il tamponamento non può fare niente perché il `clampf`
##     finale lo mangia. Va letto ACCANTO al calo medio, o il calo medio lo
##     nasconde.
##  e) **IL PREZZO** — quanti sussulti soppressi, e quindi quanti «ah… sei
##     tu» non succederanno (`_riconoscimenti` si scrive SOLO dentro il ramo
##     `trasalisce`, quindi un sussulto che non parte è anche una strada
##     lenta che non comincia).
##  f) **IL CANCELLO D'ARRESTO** — qui sotto, PRIMA dei numeri.
##
## ============================================================
## ⚠️ IL CANCELLO D'ARRESTO — sei righe, e ognuna sa dire di NO
## ============================================================
## Se una sola di queste esce storta, la meccanica va TOLTA qualunque cosa
## dicano gli altri numeri. Sono dichiarate qui, sopra il codice che le
## misura, perché una soglia scelta dopo aver visto il risultato non è un
## cancello: è una taratura.
##
##  1. **CHI STA DA SOLO NON CAMBIA DI UN BIT.** Ogni percetto senza nessun
##     corpo visibile entro il raggio deve avere `conforto` ESATTAMENTE 0.0
##     e la stessa `forza` della gamba senza conforto, con `==` e mai con una
##     tolleranza (`0.0 * K` è +0.0, `1.0 + 0.0` è 1.0 esatto, e `x / 1.0`
##     è esatto in IEEE-754: qui l'uguaglianza è una PROPRIETÀ, non una
##     speranza). **Il numero che lo smentisce è UNO.**
##  2. **IL PARAMETRO PUÒ SOLO ABBASSARE.** Zero percetti con la forza vera
##     sopra quella della gamba a conforto zero; zero reazioni che passano
##     da «nulla» a «trasalisce». Un tampone che alza è un malus travestito.
##  3. **IL CALORE NON SI TOCCA** (il quarto divieto): `calore` e la reazione
##     `si_illumina` devono essere identici nelle due gambe. Il cuoricino di
##     chi ti vuole bene non si spegne perché il suo compagno gli è accanto.
##  4. **IL RAFFREDDAMENTO NON DIVENTA UN MOLTIPLICATORE.** I percetti al
##     minuto di chi ha un compagno e di chi non ce l'ha devono essere gli
##     STESSI. Se chi sta in coppia ne riceve di più, il raffreddamento è
##     finito dentro il ramo `trasalisce` e la meccanica è diventata una
##     classifica sociale dalla porta di servizio.
##  5. **IL VILLAGGIO NON DIVENTA PIÙ RUMOROSO.** Le reazioni non-nulla
##     possono solo scendere: l'unica uscita del tampone è un sussulto che
##     non parte (il secondo divieto — non si nomina MAI). Se il conto delle
##     reazioni sale, qualcosa parla.
##  6. **IL PREZZO RESTA UNA MINORANZA.** I sussulti soppressi devono essere
##     una minoranza di TUTTI i sussulti del villaggio. Non è una soglia di
##     gusto: il tampone morde solo su chi ha un compagno visibile accanto
##     nell'istante in cui arrivi, che è per costruzione una minoranza dei
##     percetti. Se non lo è, il conforto lo sta prendendo qualcuno che non
##     dovrebbe.
##
## ============================================================
## ⚠️ L'ORACOLO È INDIPENDENTE
## ============================================================
## Non si chiede a `Visitors` se ha tamponato. Il conforto si legge dal
## LIMBICO (`ultimo_sussulto["conforto"]`) e la compagnia si conta dalle
## POSIZIONI dei corpi, con le valvole VERE (`Percezione.puo_vedere`, che è
## la fonte unica: ricopiarne i tre `if` qui dentro sarebbe la tabella
## gemella che diverge il giorno che qualcuno aggiunge la quarta valvola).
## Chiedere al giudice se è d'accordo con sé stesso è l'errore che
## `tools/misura_cammino.gd` esiste per non commettere.
##
## E il PERCETTO si rileva dal RAFFREDDAMENTO — `Visitors._sussulto_cd` che
## salta all'insù è esattamente l'istante in cui `percepisci` è stata
## chiamata, e non costa una riga di produzione. (`ultimo_sussulto` da solo
## non basta: lo riscrivono anche i percetti che tornano «nulla», e non
## porta un orologio.) È l'idioma di `tools/misura_sussulti.gd`.
##
## ============================================================
## ⚠️ LE DUE FASI, e sono due numeri diversi
## ============================================================
## **LA FORMA** (fase A) costruisce la scena: coppie fabbricate coi gesti
## veri, i due corpi incollati a poco più di un metro, Mochi che passa
## addosso a ripetizione. Dà tanti campioni per la firma 1, il tetto e la
## specificità — ed è un **TETTO, non una media**: qui il conforto capita
## quasi sempre perché l'ho costruito io.
##
## **IL VIVO** (fase B) toglie la colla, lascia camminare il villaggio e fa
## girare Mochi come gira un giocatore. Dà la FREQUENZA vera: quanti
## percetti hanno davvero un conforto, e quanti sussulti si perdono in
## partita. È il numero che conta per il prezzo; l'altro è il numero che
## conta per la forma.
##
## ⚠️ **E SUL SALVATAGGIO VERO LE COPPIE SONO ZERO** (1030 righe, tutte
## `chiacchiera`). Per questo il banco se le FABBRICA con la porta vera —
## `call_group("affetti", "gesto", …)` e poi `giro_del_giorno`, che è chi
## riempie la cache `_coppie_ieri` da cui il cablaggio legge. Se un giorno le
## coppie nasceranno da sole, questo banco misurerà quelle: basta non
## fabbricarne (`CHIBI_COPPIE=0`).
##
## ============================================================
## ⚠️ UNA CORSA SOLA NON È UNA MISURA — questo banco si REPLICA
## ============================================================
## Due corse di `misura_insieme` con gli stessi identici parametri hanno
## dato un fattore 5,7 sulla stessa grandezza, e da lì nasce tutto il
## capitolo «UNA GIORNATA SI PUÒ RIPETERE». Qui vale uguale, e anzi peggio:
## il conforto è per costruzione una COINCIDENZA — due persone precise entro
## `VICINI` **mentre** Mochi arriva addosso — e le coincidenze sono la cosa
## che balla di più fra due corse.
##
## Perciò il banco fa tre cose che lo rendono replicabile:
##  · **i dadi vengono da `Dadi`**, flusso `VILLAGGIO`, quindi `CHIBI_SEME`
##    tiene fermo il giro di Mochi (l'unica cosa che questo banco decide);
##  · **stampa righe `MISURA <nome> <valore>`**, cioè parla la lingua di
##    [`tools/banco_repliche.py`](banco_repliche.py): N semi, la
##    distribuzione invece di un numero, e il controllo che dice se il banco
##    è deterministico prima di credere a qualunque scarto;
##  · **il salvataggio da proteggere è `BuildSystem.save_path`**, non
##    `user://village.json` scritto a mano — così `CHIBI_VILLAGGIO` sposta il
##    mondo e il banco protegge il file GIUSTO, quello che si tocca.
##
##   python3 tools/banco_repliche.py tools/misura_tampone.gd --semi 6 \
##       --env CHIBI_FORMA=420 CHIBI_VIVO=300
##
## ⚠️ **E `--fixed-fps 60` non è opzionale** (lo mette il banco delle
## repliche): senza, il passo arriva dall'orologio vero e due corse dello
## stesso codice divergono più di quanto divergano due condizioni diverse.
##
## ⚠️ **NON C'È UNA LEVA `tampone` IN `Leve.MECCANISMI`, e non serve QUI.**
## L'ablazione di questo banco è più stretta di una leva: la gamba
## controfattuale si calcola sullo STESSO percetto, nello stesso istante,
## sullo stesso corpo — due corse sarebbero due villaggi. Una leva
## servirebbe per un'altra domanda, che questo banco NON risponde: l'effetto
## **a valle** di un sussulto soppresso (meno «ah… sei tu», quindi meno
## marchi positivi sul giocatore, quindi un villaggio diverso a settimane di
## distanza). Quella è una misura da repliche appaiate con la leva, ed è il
## residuo dichiarato di questo file.
##
## ⚠️ **E NON SI TOCCA IL `village.json` DELL'AUTORE**:
## `set_persist_for_debug(false)` prima di posare qualunque cosa, e
## l'impronta del file confrontata prima e dopo. Un banco altrui si è già
## portato via due gigabyte.
##
## ============================================================
## COSA DI QUESTO BANCO È GIÀ STATO PROVATO, e cosa no
## ============================================================
## Il banco è nato **prima** del cablaggio, quindi la prima cosa da dire è
## quanto è stato esercitato davvero. Con la sola patch di `Limbico.gd`
## applicata a mano (la costante, il quarto parametro, la chiave nel referto)
## e SENZA il cablaggio di `Visitors`, una corsa da 105 s su 18 residenti ha
## dato: **41 campioni, zero `SCRIPT ERROR`, salvataggio INTATTO**, e i tre
## conti della geometria pieni — 12 percetti col compagno visibile, 19 con
## un non-compagno, 9 con nessuno. Cioè: la scena si costruisce, le coppie
## si fabbricano, l'istantanea è FEDELE (0 scartate su 41) e la gamba
## controfattuale si calcola.
##
## E **il banco ha detto la cosa giusta**: «IL COMPAGNO C'ERA E IL CONFORTO
## NON È MAI ARRIVATO». Con la firma nuova e nessuno che la usi, il conforto
## è zero ovunque — ed è esattamente quello che il referto dichiara, invece
## di stampare degli zeri che sembrano una misura. **Questo banco sa
## fallire.**
##
## Quello che NON è stato provato, e va detto: **nessun ramo tamponato ha
## mai girato** (le sezioni b, d, g e i cancelli 2, 3, 6 hanno visto solo il
## caso `conforto == 0`). Chi consegna il cablaggio è il primo a leggere
## quei numeri, e la prima cosa da guardare è che `tamponati.frazione.vivo`
## non sia zero: finché lo è, tutto il resto del referto non dice niente.

const VISITORS := preload("res://scenes/npc/Visitors.gd")
const LIMBICO := preload("res://scenes/npc/Limbico.gd")
const PERCEZIONE := preload("res://scenes/npc/Percezione.gd")
const AFFETTI := preload("res://scenes/npc/Affetti.gd")
const DADI := preload("res://systems/Dadi.gd")

## Fin dove Mochi deve arrivare perché un percetto scatti: è la condizione
## di `Visitors._tick_sussulti`, e la si legge di là invece di riscriverla.
const RAGGIO_PERCETTO := 3.2

## ⚠️ IL MARGINE DELLA CLASSE «SOLO», in metri. Non è igiene: la geometria la
## campiono nel fotogramma PRIMA del percetto (è l'unico in cui posso, vedi
## `_istantanea`), e in un fotogramma un corpo fa un paio di centimetri. Un
## residente a 1,88 m sarebbe «solo» per me e «accompagnato» per il
## cablaggio, e il cancello 1 diventerebbe rosso per due centimetri invece
## che per un difetto. Chi sta fra `VICINI` e `VICINI + MARGINE_SOLO` non è
## né solo né accompagnato: sta SUL FILO, e si conta a parte.
const MARGINE_SOLO := 0.15

## Quanto dura una sosta di Mochi su un gruppo, in secondi. Il raffreddamento
## del sussulto è 9 s per residente: sotto i diciotto secondi ogni corpo del
## gruppo darebbe UN percetto per visita, e i terzili della firma 1 non
## avrebbero campioni.
const SOSTA := 20.0

## Quanto stanno lontani due gruppi. Otto metri: quattro volte `VICINI`, così
## nessun corpo di un gruppo può fare compagnia a quello di un altro nemmeno
## per sbaglio, e Mochi (che percepisce a 3,2 m) ne tocca uno per volta.
const PASSO_GRUPPO := 8.0

var _vis: Node = null
var _build: Node = null
var _dn: Node3D = null
var _aff: Node = null
var _player: Node3D = null

var _tampone := 1.0            # letto dal sorgente, mai riscritto qui
var _quante_coppie := 6
var _quanti_finti := 4         # vicini di banco che NON sono una coppia
var _quanti_soli := 4

## label -> {arousal, neuro, ultimo, cd, geo}: lo stato di PRIMA, preso ogni
## fotogramma **davanti** al `_process` dei nodi (l'ordine di Godot è
## `process_frame` → `_process` → tween, ed è per questo che il ciclo di
## questo banco vive dopo un `await process_frame` e non dentro un `_process`).
var _snap := {}
var _compagno := {}            # label -> label del compagno, per etichetta
var _in_coppia := {}           # label -> true
var _campioni: Array = []      # i percetti, con le due gambe
var _fase := "forma"
var _infedeli := 0             # istantanee che non hanno riprodotto il vero
var _senza_geo := 0            # percetti di cui non avevo la geometria
var _percetti_di := {}         # label -> quanti percetti (cancello 4)
var _secondi_di := {}          # label -> secondi in cui era misurabile
var _pose := {}                # posa -> quante volte è comparsa (cancello 5)
var _posa_prec := {}


func _init() -> void:
	_go()


func _trova(g: String) -> Node:
	for n in get_nodes_in_group(g):
		return n
	return null


func _impronta(p: String) -> String:
	if not FileAccess.file_exists(p):
		return "(assente)"
	var f := FileAccess.open(p, FileAccess.READ)
	var c := HashingContext.new()
	c.start(HashingContext.HASH_SHA256)
	c.update(f.get_buffer(f.get_length()))
	return c.finish().hex_encode()


# ======================================================== il preflight
# ⚠️ IL BANCO NASCE PRIMA DEL SUO SOGGETTO, e deve dirlo invece di
# schiantarsi. Il cablaggio del tampone vive in tre posti (la firma di
# `percepisci`, la costante, la chiave nel referto del percetto): se ne manca
# uno, un banco che parte lo stesso produce numeri che sembrano una misura e
# sono l'assenza della meccanica. L'arità si legge da `get_method_list()` e
# la costante da `get_script_constant_map()`, cioè senza CHIAMARE niente —
# un argomento di troppo in GDScript è un errore a runtime, e un errore a
# runtime in questo runner non fallisce: interrompe la funzione e basta.
func _preflight() -> bool:
	var ok := true
	var arita := -1
	for m in (LIMBICO as GDScript).get_script_method_list():
		if str(m.get("name", "")) == "percepisci":
			arita = (m.get("args", []) as Array).size()
	print("preflight · percepisci accetta %d argomenti (ne servono 4)" % arita)
	if arita < 4:
		print("  ⚠️ manca il parametro `conforto`: il cablaggio non c'è ancora")
		ok = false
	var costanti: Dictionary = (LIMBICO as GDScript).get_script_constant_map()
	if costanti.has("TAMPONE_SOCIALE"):
		_tampone = float(costanti["TAMPONE_SOCIALE"])
		print("preflight · TAMPONE_SOCIALE = %.4f" % _tampone)
	else:
		print("  ⚠️ manca la costante TAMPONE_SOCIALE in Limbico.gd")
		ok = false
	return ok


func _go() -> void:
	var t_forma := 420.0
	if OS.get_environment("CHIBI_FORMA") != "":
		t_forma = float(OS.get_environment("CHIBI_FORMA"))
	var t_vivo := 300.0
	if OS.get_environment("CHIBI_VIVO") != "":
		t_vivo = float(OS.get_environment("CHIBI_VIVO"))
	if OS.get_environment("CHIBI_COPPIE") != "":
		_quante_coppie = int(OS.get_environment("CHIBI_COPPIE"))

	print("")
	print("█".repeat(74))
	print("IL METRO DEL TAMPONE SOCIALE")
	print("█".repeat(74))
	if not _preflight():
		print("")
		print("Il banco si ferma: non c'è niente da misurare, e misurare")
		print("l'assenza di una meccanica stampando degli zeri sarebbe peggio")
		print("che non misurare. (Uscita 2: non è un guasto del gioco.)")
		quit(2)
		return

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	if change_scene_to_file("res://scenes/levels/MainLevel.tscn") != OK:
		push_error("MainLevel non si apre")
		quit(1)
		return
	for _i in 40:
		await process_frame
	_vis = _trova("visitors")
	_build = _trova("build_system")
	_dn = _trova("daynight") as Node3D
	_aff = _trova("affetti")
	_player = current_scene.get_node_or_null("Player") as Node3D
	if _player == null:
		_player = get_first_node_in_group("player") as Node3D
	if _vis == null or _build == null or _dn == null or _aff == null or _player == null:
		push_error("manca Visitors, BuildSystem, DayNight, Affetti o Player")
		quit(1)
		return
	# PRIMA DI TOCCARE QUALUNQUE COSA
	_build.call("set_persist_for_debug", false)
	# ⚠️ il file da proteggere è quello che il gioco USA, non un percorso
	# scritto a mano: con `CHIBI_VILLAGGIO` il mondo si sposta, e un banco
	# che impronta `user://village.json` a prescindere dichiarerebbe
	# «INTATTO» guardando un file che nessuno ha toccato.
	var salvataggio := str(_build.get("save_path"))
	var prima_sha := _impronta(salvataggio)
	print("il villaggio di questa corsa: %s" % salvataggio)
	print("il seme di radice: %d%s" % [DADI.radice(),
			"" if OS.get_environment("CHIBI_SEME") == "" else "  (da CHIBI_SEME)"])

	# L'OROLOGIO SI FERMA a metà pomeriggio. Un giorno dura quattro minuti, e
	# a metà prova i vicini andrebbero a dormire: `resident_sleep` li
	# rimpicciolisce a scala 0,03, `puo_vedere` risponde no a tutti, e il
	# banco misurerebbe un villaggio vuoto credendo di misurare la
	# specificità.
	_dn.set("cycle_seconds", 1000000.0)
	_dn.call("set_time", 0.42)

	# via i residenti veri: quelli del salvataggio hanno case sparse come le
	# ha posate il giocatore, e la scena che serve qui è geometrica
	_vis.call("debug_reset")
	await process_frame

	var residenti: Array = await _popola()
	if residenti.is_empty():
		print("GUASTO: nessun residente")
		quit(1)
		return
	_fabbrica_le_coppie(residenti)
	_leggi_le_coppie(residenti)

	print("")
	print("residenti %d · coppie fabbricate %d · vicini di banco %d · solitari %d"
			% [residenti.size(), _quante_coppie, _quanti_finti, _quanti_soli])
	var quanti_accoppiati := 0
	for l in _in_coppia:
		if bool(_in_coppia[l]):
			quanti_accoppiati += 1
	print("residenti che il libro mastro riconosce in coppia: %d" % quanti_accoppiati)
	if quanti_accoppiati == 0:
		print("")
		print("⚠️ NESSUNA COPPIA: `Affetti._coppie_ieri` è vuota, quindi il")
		print("   conforto non può essere diverso da zero da nessuna parte e")
		print("   ogni numero che segue direbbe «la meccanica non esiste»")
		print("   quando invece è la SCENA a non esistere. Il banco si ferma.")
		quit(1)
		return

	# ---------------------------------------------------------- FASE A
	print("")
	print("─".repeat(74))
	print("  FASE A — LA FORMA (la scena è costruita: è un TETTO, non una media)")
	print("─".repeat(74))
	_fase = "forma"
	await _gira_la_forma(t_forma, residenti)

	# ---------------------------------------------------------- FASE B
	print("")
	print("─".repeat(74))
	print("  FASE B — IL VIVO (la colla è tolta, Mochi gira come un giocatore)")
	print("─".repeat(74))
	_fase = "vivo"
	await _gira_il_vivo(t_vivo, residenti)

	_referto(residenti, t_forma, t_vivo)
	var dopo_sha := _impronta(salvataggio)
	print("\nil salvataggio dell'autore: %s"
			% ["INTATTO" if prima_sha == dopo_sha else "⚠️ TOCCATO ⚠️"])
	quit(0)


# ======================================================== la scena

## La posizione base del gruppo k: una griglia larga, `PASSO_GRUPPO` fra un
## gruppo e l'altro.
func _base(k: int) -> Vector3:
	@warning_ignore("integer_division")
	var riga := k / 4
	var col := k % 4
	return Vector3(-12.0 + float(col) * PASSO_GRUPPO, 0.0,
			-8.0 + float(riga) * PASSO_GRUPPO)


## Tre popolazioni, e ognuna risponde a una domanda diversa:
##  · le COPPIE, due corpi a 1,1 m — il tampone deve mordere;
##  · i VICINI DI BANCO, due corpi altrettanto accosti che NON sono una
##    coppia — è la firma 2, e senza di loro «specifico» è una parola;
##  · i SOLITARI, nessuno entro sei metri — è il cancello 1.
##
## ⚠️ E LE DUE ANAGRAFI. `Affetti` è indicizzato per NOME (`dna.name`),
## tutto il resto per ETICHETTA: le coppie si fabbricano coi nomi e si
## leggono per etichetta, e la traduzione la fa la mappa costruita da
## `_residents`, che ha tutte e due le colonne. Un nome o un'etichetta che
## tocchi a due residenti renderebbe la traduzione ambigua e il banco
## misurerebbe il corpo sbagliato, quindi i semi si scartano finché non sono
## unici — nel gioco l'omonimia è un residuo dichiarato, in un banco è un
## guasto di misura.
func _popola() -> Array:
	var VS := load("res://scenes/npc/Visitor.gd")
	var DNAG := load("res://scenes/npc/ChibiDNA.gd")
	var residenti: Array = _vis.get("_residents")
	var visti_nome := {}
	var visti_lab := {}
	var seme := 4100
	var k := 0
	var gruppo := 0
	var ricette: Array = []
	for _i in _quante_coppie:
		ricette.append("coppia")
	for _i2 in _quanti_finti:
		ricette.append("finto")
	for _i3 in _quanti_soli:
		ricette.append("solo")

	for ric in ricette:
		var base := _base(gruppo)
		gruppo += 1
		var quanti := 1 if str(ric) == "solo" else 2
		var nel_gruppo: Array = []
		for j in quanti:
			var dna: Dictionary = {}
			while true:
				dna = DNAG.generate(seme)
				seme += 37
				var nm := str(dna.get("name", ""))
				var lb := str(dna.get("label", ""))
				if nm != "" and lb != "" and not visti_nome.has(nm) and not visti_lab.has(lb):
					visti_nome[nm] = true
					visti_lab[lb] = true
					break
			var v = VS.new()
			v.species = "chibi"
			v.dna = dna
			_vis.add_child(v)
			v.mode = "resident"
			# i due del gruppo a 1,1 m: dentro `VICINI` (1,9) con margine, e
			# abbastanza lontani da non compenetrarsi
			var pos := base + Vector3(float(j) * 1.1, 0.0, 0.0)
			v.position = pos
			v.call("_enter_state", "r_idle")
			var cella := Vector2i(roundi(pos.x), roundi(pos.z))
			var r := {"species": "chibi", "cell": cella, "node": v, "dna": dna,
					"label": str(dna["label"]), "friend": 1, "wish": {},
					"ricetta": str(ric), "posa": pos}
			# ⚠️ `next_act` a 9999 e la fase corrente: senza, `_routine`
			# manda subito il corpo a fare qualcosa e la geometria che ho
			# costruito dura un fotogramma.
			r["phase"] = _vis.call("_phase")
			r["next_act"] = 9999.0
			residenti.append(r)
			_vis.call("_ensure_brain", r)
			nel_gruppo.append(r)
			_percetti_di[str(r["label"])] = 0
			_secondi_di[str(r["label"])] = 0.0
			_posa_prec[str(r["label"])] = ""
			k += 1
		if str(ric) == "coppia" and nel_gruppo.size() == 2:
			(nel_gruppo[0] as Dictionary)["sposa"] = str(
					((nel_gruppo[1] as Dictionary)["dna"] as Dictionary)["name"])
			(nel_gruppo[1] as Dictionary)["sposa"] = str(
					((nel_gruppo[0] as Dictionary)["dna"] as Dictionary)["name"])

	for _f in 10:
		await process_frame
	_marchia(residenti)
	return residenti


## IL VENTAGLIO DEGLI ALLARMI, e senza di lui la domanda (d) è degenere.
##
## Un terzo dei residenti porta un marchio NEGATIVO forte sul giocatore, un
## terzo uno leggero, un terzo niente. Serve perché il `clampf` finale morde
## solo in cima alla scala: se tutti fossero marchiati forte, ogni campione
## starebbe al tetto e il calo medio direbbe zero; se nessuno lo fosse, il
## tetto non si vedrebbe mai e il residuo dichiarato resterebbe una teoria.
##
## ⚠️ E IL MARCHIO SI SCRIVE SU `chi|giocatore`, non su un luogo.
## `percepisci("giocatore", "", …)` cerca `chi|giocatore` e `luogo|` (vuoto):
## un marchio posato su una cucina non conta niente qui — e in un banco
## precedente quel preparativo esisteva per un'altra ragione.
func _marchia(residenti: Array) -> void:
	var animi: Dictionary = _vis.get("_animi")
	var k := 0
	for r in residenti:
		var lab := str((r as Dictionary).get("label", ""))
		if not animi.has(lab):
			continue
		var animo = animi[lab]
		var lim = animo.limbico
		var quanti: int = [3, 1, 0][k % 3]
		for _i in quanti:
			lim.rivaluta("spavento", "giocatore", -0.9)
		(r as Dictionary)["marchio"] = quanti
		k += 1


## LE COPPIE SI FABBRICANO CON LA PORTA VERA. Sei righe di peso ≥ `PESO_VERO`
## in tutti e due i versi: `coppia()` chiede tre gesti veri, il minimo
## reciproco e `SOGLIA_COPPIA` da tutte e due le parti, e con questi sei il
## conto sta a 4,65 per ciascuno — largo, perché una coppia sul filo si
## scioglierebbe a metà banco e la misura cambierebbe soggetto in corsa.
##
## ⚠️ I TIPI SONO TRE E I VERSI DUE, mai lo stesso tipo due volte nello stesso
## verso: `gesto()` ha la valvola contro l'abitudine (`GIORNI_RIPETIZIONE`,
## sette giorni) e la seconda riga uguale verrebbe **rifiutata in silenzio**.
func _fabbrica_le_coppie(residenti: Array) -> void:
	if _quante_coppie <= 0:
		return
	for r in residenti:
		var a := str((r as Dictionary).get("dna", {}).get("name", ""))
		var b := str((r as Dictionary).get("sposa", ""))
		if a == "" or b == "" or a > b:
			continue    # una volta per coppia, non due
		for tipo in ["nascita", "consolazione", "coraggio"]:
			call_group("affetti", "gesto", a, b, tipo)
			call_group("affetti", "gesto", b, a, tipo)
	# LA CACHE GIORNALIERA si riempie SOLO in `giro_del_giorno`, ed è quella
	# che il cablaggio legge (`le_coppie()` costa 156 `conto()` e ~233 ms).
	# `_ultimo_giorno` si riporta indietro perché la funzione esce subito se
	# la giornata è già stata girata.
	_aff.set("_ultimo_giorno", -999)
	_aff.call("giro_del_giorno", int(_dn.get("day")))


## Chi è in coppia con chi, PER ETICHETTA, letto dalla cache che legge il
## cablaggio — non da `le_coppie()`, che ricalcolerebbe tutto e potrebbe
## dare una risposta diversa da quella che il gioco sta usando.
func _leggi_le_coppie(residenti: Array) -> void:
	var per_nome := {}
	var ambigui := {}
	for r in residenti:
		var nm := str((r as Dictionary).get("dna", {}).get("name", ""))
		var lb := str((r as Dictionary).get("label", ""))
		if nm == "":
			continue
		if per_nome.has(nm):
			ambigui[nm] = true
		per_nome[nm] = lb
	_compagno.clear()
	_in_coppia.clear()
	for c in (_aff.get("_coppie_ieri") as Array):
		var a := str((c as Array)[0])
		var b := str((c as Array)[1])
		if ambigui.has(a) or ambigui.has(b):
			continue    # un nome che tocca a due corpi non si traduce
		if not per_nome.has(a) or not per_nome.has(b):
			continue
		_compagno[str(per_nome[a])] = str(per_nome[b])
		_compagno[str(per_nome[b])] = str(per_nome[a])
		_in_coppia[str(per_nome[a])] = true
		_in_coppia[str(per_nome[b])] = true


# ======================================================== i due giri

## FASE A: i corpi restano dove li ho messi (li riposiziono ogni fotogramma,
## prima che il loro `_process` giri) e Mochi fa il giro dei gruppi. È colla,
## e va detto: quello che esce di qui è la FORMA dello smorzamento, non
## quanto capita.
func _gira_la_forma(secondi: float, residenti: Array) -> void:
	var t := 0.0
	var ms := Time.get_ticks_msec()
	var gruppo := 0
	var sosta := 0.0
	var oscilla := 0.0
	var avviso := 0.0
	var gruppi := _quante_coppie + _quanti_finti + _quanti_soli
	while t < secondi:
		await process_frame
		var ora := Time.get_ticks_msec()
		var dt := float(ora - ms) / 1000.0
		ms = ora
		if dt <= 0.0 or dt > 0.5:
			continue
		t += dt
		# 1) i percetti del fotogramma appena passato, contro l'istantanea
		_raccogli(residenti)
		# 2) la colla, PRIMA del `_process` dei corpi
		for r in residenti:
			var n := (r as Dictionary).get("node") as Node3D
			if n != null and is_instance_valid(n):
				n.global_position = (r as Dictionary)["posa"]
		# 3) l'istantanea di adesso, sempre prima del `_process`
		_istantanea(residenti, dt)
		# 4) Mochi: sosta su un gruppo, oscillando avanti e indietro
		sosta -= dt
		if sosta <= 0.0:
			gruppo = (gruppo + 1) % maxi(1, gruppi)
			sosta = SOSTA
		var centro := _base(gruppo) + Vector3(0.55, 0.0, 0.0)
		oscilla += dt
		# l'oscillazione fa la VELOCITÀ, che è ciò che `indizio_grezzo`
		# guarda: fermo, `grezzo` è zero e resta solo il marchio. Il periodo
		# è dispari rispetto al raffreddamento (9 s) apposta, così i percetti
		# non cadono sempre nello stesso punto dell'onda.
		var avanti := 1.4 + 0.9 * sin(oscilla * 1.7)
		var meta := centro + Vector3(0.0, 0.0, avanti)
		var p := _player.global_position
		var verso := meta - p
		verso.y = 0.0
		var lontano := verso.length() > 4.0
		var vel: float = float(_player.get("run_speed") if lontano
				else _player.get("walk_speed"))
		if vel <= 0.0:
			vel = 6.0 if lontano else 3.0
		if verso.length() > 0.02:
			_player.global_position = p + verso.normalized() \
					* minf(vel * dt, verso.length())
		if t - avviso > 60.0:
			avviso = t
			print("   … %.0f s · campioni %d (tamponati %d)"
					% [t, _campioni.size(), _quanti_tamponati()])


## FASE B: la colla via, i corpi tornano a vivere, Mochi gira come gira un
## giocatore. Qui il conforto capita o non capita, ed è quello il numero.
func _gira_il_vivo(secondi: float, residenti: Array) -> void:
	# il villaggio ha bisogno di posti dove andare, o la routine non muove
	# nessuno e la «frequenza vera» sarebbe quella di un prato vuoto
	for k in 6:
		_build.call("place_cell", Vector2i(-14 + k * 5, 12), "Cespuglio", 0, false)
		_build.call("place_cell", Vector2i(-14 + k * 5, -12), "Panchina", 0, false)
	_build.call("aggiorna_varchi_ora")
	for r in residenti:
		(r as Dictionary)["next_act"] = 0.5
	await process_frame

	# ⚠️ IL DADO VIENE DAL FLUSSO NOMINATO, non da una costante scritta qui:
	# il giro di Mochi è l'unica cosa che questo banco decide, e con
	# `Dadi.rng` la decide `CHIBI_SEME`. Un seme cablato renderebbe la corsa
	# ripetibile e le REPLICHE identiche fra loro — cioè una distribuzione
	# con dispersione zero, che è il modo più elegante di non misurare niente.
	var rng: RandomNumberGenerator = DADI.rng(DADI.VILLAGGIO, "misura_tampone/mochi")
	var meta := Vector3(rng.randf_range(-10, 10), 0.0, rng.randf_range(-10, 10))
	var sosta := 0.0
	var t := 0.0
	var ms := Time.get_ticks_msec()
	var avviso := 0.0
	while t < secondi:
		await process_frame
		var ora := Time.get_ticks_msec()
		var dt := float(ora - ms) / 1000.0
		ms = ora
		if dt <= 0.0 or dt > 0.5:
			continue
		t += dt
		_raccogli(residenti)
		_istantanea(residenti, dt)
		var p := _player.global_position
		if sosta > 0.0:
			sosta -= dt
		elif Vector2(p.x - meta.x, p.z - meta.z).length() < 1.0:
			# ⚠️ SI FERMA, e non è un dettaglio di comodità: il sussulto ha
			# nove secondi di raffreddamento, e passando accanto a sei metri
			# al secondo la finestra utile è mezzo secondo. Un giocatore
			# quando arriva da qualcuno si ferma.
			sosta = 2.5
			if rng.randf() < 0.5 and not residenti.is_empty():
				var q := (residenti[rng.randi() % residenti.size()] as Dictionary)
				var qn := q.get("node") as Node3D
				meta = qn.global_position if (qn != null and is_instance_valid(qn)) \
						else Vector3(rng.randf_range(-14, 14), 0, rng.randf_range(-14, 14))
			else:
				meta = Vector3(rng.randf_range(-14, 14), 0, rng.randf_range(-14, 14))
		var verso := meta - p
		verso.y = 0.0
		if sosta <= 0.0 and verso.length() > 0.02:
			var lontano := verso.length() > 8.0
			var vel: float = float(_player.get("run_speed") if lontano
					else _player.get("walk_speed"))
			if vel <= 0.0:
				vel = 6.0 if lontano else 3.0
			_player.global_position = p + verso.normalized() * vel * dt
		if t - avviso > 60.0:
			avviso = t
			print("   … %.0f s · campioni %d (tamponati %d)"
					% [t, _campioni.size(), _quanti_tamponati()])


# ======================================================== l'istantanea

## LO STATO DI PRIMA, campo per campo. `percepisci` scrive tre cose e solo
## tre — `arousal`, `neuro` (attraverso `stimola_neuro`) e `ultimo_sussulto`
## — quindi rimettere quelle tre riporta il Limbico esattamente dov'era.
##
## ⚠️ **NON con `save()`/`load()`**: `Limbico.load` non rilegge `reattivita`
## né `abitudine` (sono DERIVATE dai tratti, e c'è un commento apposta che
## dice perché), quindi un giro dal salvataggio non è l'identità — e la gamba
## controfattuale verrebbe calcolata su una persona leggermente diversa da
## quella che ha appena percepito.
##
## Si prende anche la GEOMETRIA, e solo per i corpi che Mochi può ancora
## raggiungere: la compagnia va misurata nell'istante del percetto, e questo
## è l'ultimo fotogramma in cui posso guardarla prima che avvenga.
func _istantanea(residenti: Array, dt: float) -> void:
	var animi: Dictionary = _vis.get("_animi")
	var cd: Dictionary = _vis.get("_sussulto_cd")
	var pp := _player.global_position
	for r in residenti:
		var lab := str((r as Dictionary).get("label", ""))
		var n := (r as Dictionary).get("node") as Node3D
		if lab == "" or n == null or not is_instance_valid(n) or not animi.has(lab):
			continue
		var animo = animi[lab]
		var lim = animo.limbico
		var vicino: bool = pp.distance_to(n.global_position) <= RAGGIO_PERCETTO + 0.2
		_snap[lab] = {
			"arousal": float(lim.arousal),
			"neuro": (lim.neuro as Dictionary).duplicate(),
			"ultimo": lim.ultimo_sussulto,
			"cd": float(cd.get(lab, 0.0)),
			"geo": _geometria(lab, n, residenti) if vicino else {},
		}
		if vicino:
			_secondi_di[lab] = float(_secondi_di.get(lab, 0.0)) + dt
		# IL CANCELLO 5, e non costa niente: le pose che il villaggio emette.
		var posa := str(n.get_meta("postura", ""))
		if posa != str(_posa_prec.get(lab, "")):
			_posa_prec[lab] = posa
			if posa != "":
				_pose[posa] = int(_pose.get(posa, 0)) + 1


## CHI GLI STA ACCANTO, e con le valvole VERE.
##
## ⚠️ Si passa la posizione di CHI PERCEPISCE, non quella del compagno:
## chiedendo `puo_vedere(compagno, compagno.position, …)` la distanza sarebbe
## zero per costruzione e delle quattro valvole ne vivrebbe una in meno — è
## il difetto già pagato per intero nel capitolo delle Deduzioni, dove otto
## ricevute su otto si pagavano con Mochi a venti metri.
##
## E `Percezione.puo_vedere` si chiama, non si riscrive: copre `is_hidden`,
## `dorme` e `in_scena` in un posto solo, e chi la usa eredita la quarta
## valvola il giorno che qualcuno la aggiunge.
func _geometria(lab: String, n: Node3D, residenti: Array) -> Dictionary:
	var pos := n.global_position
	var comp := str(_compagno.get(lab, ""))
	var out := {"compagno": comp, "d_comp": -1.0, "comp_visibile": false,
			"altri": 0, "d_altro": -1.0, "sul_filo": false}
	for q in residenti:
		var qlab := str((q as Dictionary).get("label", ""))
		if qlab == "" or qlab == lab:
			continue
		var qn := (q as Dictionary).get("node") as Node3D
		if qn == null or not is_instance_valid(qn):
			continue
		var d := pos.distance_to(qn.global_position)
		if d > VISITORS.VICINI + MARGINE_SOLO:
			continue
		if d > VISITORS.VICINI:
			# né dentro né fuori: sta sul filo, e si dichiara invece di
			# essere contato da una parte a caso
			out["sul_filo"] = true
			continue
		if not PERCEZIONE.puo_vedere(qn, pos, VISITORS.VICINI):
			continue
		if qlab == comp:
			out["comp_visibile"] = true
			out["d_comp"] = d
		else:
			out["altri"] = int(out["altri"]) + 1
			if float(out["d_altro"]) < 0.0 or d < float(out["d_altro"]):
				out["d_altro"] = d
	return out


# ======================================================== la raccolta

## UN PERCETTO È AVVENUTO nel fotogramma appena passato se il raffreddamento
## è SALTATO ALL'INSÙ: `_tick_sussulti` lo rimette a 9,0 esattamente quando
## chiama `percepisci`, e fuori di lì può solo scendere.
##
## Qui dentro si costruisce la MISURA APPAIATA, e sono tre chiamate:
##  1. si rimette lo stato di PRIMA e si rifà lo stesso percetto col conforto
##     VERO. Deve tornare lo STESSO numero, bit per bit: se non torna,
##     l'istantanea non era fedele (qualcuno ha toccato i marchi nel
##     frattempo) e il campione si butta invece di finire in una media.
##     È la controprova che rende questo banco capace di fallire.
##  2. si rimette di nuovo, e si rifà il percetto con `conforto = 0`: è la
##     GAMBA, l'unica cosa che si misura.
##  3. si rimette il mondo com'era DOPO il percetto vero — il banco non deve
##     lasciare traccia nel villaggio che sta misurando.
func _raccogli(residenti: Array) -> void:
	var animi: Dictionary = _vis.get("_animi")
	var cd: Dictionary = _vis.get("_sussulto_cd")
	for r in residenti:
		var lab := str((r as Dictionary).get("label", ""))
		if lab == "" or not animi.has(lab) or not _snap.has(lab):
			continue
		var snap: Dictionary = _snap[lab]
		var cd_ora := float(cd.get(lab, 0.0))
		if cd_ora <= float(snap["cd"]) + 0.0001:
			continue                      # nessun percetto in questo giro
		var animo = animi[lab]
		var lim = animo.limbico
		var s: Dictionary = lim.ultimo_sussulto
		_percetti_di[lab] = int(_percetti_di.get(lab, 0)) + 1
		var geo: Dictionary = snap["geo"]
		if geo.is_empty():
			_senza_geo += 1
			continue

		var grezzo := float(s.get("grezzo", 0.0))
		var conforto := float(s.get("conforto", 0.0))
		var forza := float(s.get("forza", 0.0))
		var calore := float(s.get("calore", 0.0))
		var reazione := str(s.get("reazione", "nulla"))

		# lo stato di ADESSO, da rimettere alla fine
		var post_a := float(lim.arousal)
		var post_n: Dictionary = (lim.neuro as Dictionary).duplicate()
		var post_u: Dictionary = lim.ultimo_sussulto

		_rimetti(lim, snap)
		var rep: Dictionary = lim.percepisci("giocatore", "", grezzo, conforto)
		# ⚠️ `==` e non una tolleranza: è la stessa funzione con gli stessi
		# ingressi, quindi l'uguaglianza è esatta o l'istantanea è sbagliata.
		var fedele: bool = float(rep.get("forza", -1.0)) == forza \
				and float(rep.get("calore", -1.0)) == calore

		_rimetti(lim, snap)
		var g0: Dictionary = lim.percepisci("giocatore", "", grezzo, 0.0)

		lim.arousal = post_a
		lim.neuro = post_n
		lim.ultimo_sussulto = post_u

		if not fedele:
			_infedeli += 1
			continue

		_campioni.append({
			"fase": _fase, "lab": lab,
			"reatt": float(lim.reattivita),
			"arousal_prima": float(snap["arousal"]),
			"marchio": int((r as Dictionary).get("marchio", 0)),
			"carica": float(s.get("carica", 0.0)), "grezzo": grezzo,
			"conforto": conforto,
			"forza": forza, "calore": calore, "reazione": reazione,
			"forza0": float(g0.get("forza", 0.0)),
			"calore0": float(g0.get("calore", 0.0)),
			"reazione0": str(g0.get("reazione", "nulla")),
			"comp_visibile": bool(geo["comp_visibile"]),
			"d_comp": float(geo["d_comp"]),
			"altri": int(geo["altri"]), "d_altro": float(geo["d_altro"]),
			"sul_filo": bool(geo["sul_filo"]),
			"in_coppia": bool(_in_coppia.get(lab, false)),
		})


func _rimetti(lim, snap: Dictionary) -> void:
	lim.arousal = float(snap["arousal"])
	lim.neuro = (snap["neuro"] as Dictionary).duplicate()
	lim.ultimo_sussulto = snap["ultimo"]


func _quanti_tamponati() -> int:
	var n := 0
	for c in _campioni:
		if float((c as Dictionary)["conforto"]) > 0.0:
			n += 1
	return n


# ======================================================== il referto

## UNA RIGA CHE IL BANCO DELLE REPLICHE SA LEGGERE. Il formato è quello di
## `banco_repliche.py` (`MISURA <nome> <valore>`), e non è una comodità: è la
## sola cosa che trasforma i numeri di UNA corsa in una distribuzione su N
## semi. Chi aggiunge un numero al referto e non lo emette qui lo condanna a
## restare un aneddoto.
func _misura(nome: String, valore: float) -> void:
	print("MISURA %s %.6f" % [nome, valore])


func _mediana(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


func _media(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for x in a:
		s += float(x)
	return s / float(a.size())


func _di_fase(fase: String) -> Array:
	var out: Array = []
	for c in _campioni:
		if str((c as Dictionary)["fase"]) == fase:
			out.append(c)
	return out


func _referto(residenti: Array, t_forma: float, t_vivo: float) -> void:
	print("")
	print("█".repeat(74))
	print("IL REFERTO — %d campioni (%d fase FORMA, %d fase VIVO)"
			% [_campioni.size(), _di_fase("forma").size(), _di_fase("vivo").size()])
	print("█".repeat(74))
	if _infedeli > 0 or _senza_geo > 0:
		print("  ⚠️ scartati: %d istantanee non fedeli · %d percetti senza geometria"
				% [_infedeli, _senza_geo])
		print("     (una istantanea non fedele vuol dire che fra il percetto e la")
		print("      replica qualcuno ha toccato i marchi: il campione non è")
		print("      appaiato e non entra in nessuna media)")

	_sezione_a()
	_sezione_b()
	_sezione_c()
	_sezione_d()
	_sezione_e()
	_sezione_g()
	_cancelli(residenti, t_forma + t_vivo)
	_righe_misura(residenti)


## (a) LA MISURA APPAIATA — quanto smorza, in totale, e la sua controprova.
func _sezione_a() -> void:
	print("")
	print("─".repeat(74))
	print("  (a) LA MISURA APPAIATA — lo stesso percetto, con e senza conforto")
	print("─".repeat(74))
	for fase in ["forma", "vivo"]:
		var tutti := _di_fase(fase)
		var tamp: Array = []
		var conf: Array = []
		var cali: Array = []
		var rel: Array = []
		var scarti: Array = []
		for c in tutti:
			var d := c as Dictionary
			if float(d["conforto"]) <= 0.0:
				continue
			tamp.append(d)
			conf.append(float(d["conforto"]))
			cali.append(float(d["forza0"]) - float(d["forza"]))
			if float(d["forza0"]) > 0.0:
				rel.append(1.0 - float(d["forza"]) / float(d["forza0"]))
			# la controprova geometrica: il conforto ricevuto contro quello
			# che la rampa lineare prevede da DOVE erano i due corpi
			if float(d["d_comp"]) >= 0.0:
				var atteso := clampf(1.0 - float(d["d_comp"]) / VISITORS.VICINI, 0.0, 1.0)
				scarti.append(absf(float(d["conforto"]) - atteso))
		print("  %s — %d percetti, di cui %d con conforto > 0 (%.0f%%)"
				% [fase.to_upper(), tutti.size(), tamp.size(),
				100.0 * float(tamp.size()) / maxf(1.0, float(tutti.size()))])
		if tamp.is_empty():
			print("      nessun campione tamponato: qui non c'è niente da dire")
			continue
		print("      conforto ricevuto ........ med %.3f · mediana %.3f · max %.3f"
				% [_media(conf), _mediana(conf), _massimo(conf)])
		print("      CALO assoluto dell'allarme  med %.4f · mediana %.4f · max %.4f"
				% [_media(cali), _mediana(cali), _massimo(cali)])
		print("      calo relativo ............ %.1f%% (mediana %.1f%%)"
				% [100.0 * _media(rel), 100.0 * _mediana(rel)])
		if not scarti.is_empty():
			print("      ⚠ scarto fra il conforto ricevuto e quello che la")
			print("        geometria prevede: med %.4f · max %.4f"
					% [_media(scarti), _massimo(scarti)])
			print("        (l'oracolo è la POSIZIONE dei corpi, non Visitors; uno")
			print("         scarto grosso vuol dire che il cablaggio guarda")
			print("         un'altra distanza o un'altra rampa)")


func _massimo(a: Array) -> float:
	var m := 0.0
	for x in a:
		m = maxf(m, float(x))
	return m


## (b) LA FIRMA 1 — lo smorzamento è più grande nei più REATTIVI.
##
## ⚠️ **LA GRANDEZZA CHE SI RIPORTA È IL CALO ASSOLUTO, e la ragione è che il
## calo RELATIVO è cieco per costruzione.** Con la forma decisa dall'autore —
## `conforto` divide il GUADAGNO — il rapporto fra le due gambe vale
## `1/(1+c·K)` e non contiene la reattività affatto: il calo relativo è lo
## STESSO per un codardo e per un temerario, e chi lo riportasse
## concluderebbe che la firma 1 non c'è. Il calo assoluto invece è
## proporzionale alla reattività, ed è lì che la firma vive.
##
## Il numero della firma è il **rapporto fra il calo del terzile alto e
## quello del basso**, letto accanto al rapporto delle loro reattività: se
## la forma è quella decisa, i due si somigliano.
func _sezione_b() -> void:
	print("")
	print("─".repeat(74))
	print("  (b) LA FIRMA 1 — il calo, spezzato per REATTIVITÀ")
	print("─".repeat(74))
	# ⚠️ solo i campioni che il tetto non tosa: mescolarli falsa le fasce,
	# perché al tetto il calo è tagliato e non è più proporzionale a niente
	var buoni: Array = []
	for c in _campioni:
		var d := c as Dictionary
		if float(d["conforto"]) > 0.0 and float(d["forza0"]) < 1.0:
			buoni.append(d)
	if buoni.size() < 9:
		print("  soltanto %d campioni sotto il tetto: i terzili non si leggono."
				% buoni.size())
		print("  (serve più tempo di FORMA, o più coppie: CHIBI_FORMA / CHIBI_COPPIE)")
		return
	buoni.sort_custom(func(x, y): return float(x["reatt"]) < float(y["reatt"]))
	@warning_ignore("integer_division")
	var n3 := buoni.size() / 3
	var fasce := [buoni.slice(0, n3), buoni.slice(n3, n3 * 2), buoni.slice(n3 * 2)]
	var nomi := ["reattività BASSA", "reattività MEDIA", "reattività ALTA"]
	var cali_fascia: Array = []
	var reatt_fascia: Array = []
	for i in 3:
		var f: Array = fasce[i]
		var re: Array = []
		var ca: Array = []
		var rl: Array = []
		var co: Array = []
		for d in f:
			re.append(float((d as Dictionary)["reatt"]))
			ca.append(float((d as Dictionary)["forza0"]) - float((d as Dictionary)["forza"]))
			co.append(float((d as Dictionary)["conforto"]))
			if float((d as Dictionary)["forza0"]) > 0.0:
				rl.append(1.0 - float((d as Dictionary)["forza"])
						/ float((d as Dictionary)["forza0"]))
		cali_fascia.append(_media(ca))
		reatt_fascia.append(_media(re))
		print("  %-18s n %3d · reatt %.3f · conforto %.3f · CALO %.4f · rel %.1f%%"
				% [nomi[i], f.size(), _media(re), _media(co), _media(ca), 100.0 * _media(rl)])
	var r_calo: float = float(cali_fascia[2]) / maxf(0.000001, float(cali_fascia[0]))
	var r_reatt: float = float(reatt_fascia[2]) / maxf(0.000001, float(reatt_fascia[0]))
	print("")
	print("  ⇒ il calo cresce di %.2f× dal terzile basso all'alto" % r_calo)
	print("    e la reattività cresce di %.2f×" % r_reatt)
	print("    LA FIRMA 1 C'È se i due si somigliano: il conforto entra sul")
	print("    GUADAGNO, quindi smorza in proporzione a quanto uno reagisce.")
	print("    (⚠️ il calo RELATIVO invece dev'essere COSTANTE fra le fasce —")
	print("     vale 1−1/(1+c·K) e non contiene la reattività: è la controprova")
	print("     che la forma è una divisione del guadagno e non una sottrazione)")


## (c) LA FIRMA 2 — la specificità. Il numero che la smentisce è UNO.
func _sezione_c() -> void:
	print("")
	print("─".repeat(74))
	print("  (c) LA FIRMA 2 — è SPECIFICA della figura di attaccamento?")
	print("─".repeat(74))
	var con_comp := 0
	var con_comp_tamp := 0
	var solo_altri := 0
	var solo_altri_tamp := 0
	var soli := 0
	var soli_tamp := 0
	var filo := 0
	var tradito: Array = []
	for c in _campioni:
		var d := c as Dictionary
		var t: bool = float(d["conforto"]) > 0.0
		if bool(d["comp_visibile"]):
			con_comp += 1
			if t:
				con_comp_tamp += 1
		elif int(d["altri"]) > 0:
			# ⚠️ È LA RIGA CHE PORTA LA FIRMA 2: qualcuno c'è, si vede, sta
			# dentro il raggio — e NON è il compagno.
			solo_altri += 1
			if t:
				solo_altri_tamp += 1
				tradito.append(d)
		elif bool(d["sul_filo"]):
			filo += 1
		else:
			soli += 1
			if t:
				soli_tamp += 1
				tradito.append(d)
	print("  percetti col COMPAGNO visibile entro %.1f m ...... %d, tamponati %d"
			% [VISITORS.VICINI, con_comp, con_comp_tamp])
	print("  percetti con un NON-compagno visibile e nessun")
	print("    compagno (LA FIRMA 2) ......................... %d, tamponati %d"
			% [solo_altri, solo_altri_tamp])
	print("  percetti con NESSUNO entro il raggio ............ %d, tamponati %d"
			% [soli, soli_tamp])
	print("  percetti con qualcuno SUL FILO (%.2f-%.2f m) ..... %d (non contati"
			% [VISITORS.VICINI, VISITORS.VICINI + MARGINE_SOLO, filo])
	print("    da nessuna delle due parti: la geometria è di un fotogramma prima)")
	if con_comp > 0 and con_comp_tamp == 0:
		print("  ⚠️ IL COMPAGNO C'ERA E IL CONFORTO NON È MAI ARRIVATO: o le")
		print("     valvole lo escludono sempre, o il cablaggio non legge la")
		print("     cache delle coppie. Nessun altro numero di questo referto")
		print("     dice niente finché questo non è diverso da zero.")
	if not tradito.is_empty():
		print("  ⚠️⚠️ LA SPECIFICITÀ È ROTTA — %d percetti tamponati senza un"
				% tradito.size())
		print("       compagno visibile. Ne bastava UNO. I primi:")
		for i in mini(5, tradito.size()):
			var d := tradito[i] as Dictionary
			print("        %-12s conforto %.3f · altri entro il raggio %d (a %.2f m)"
					% [d["lab"], d["conforto"], d["altri"], d["d_altro"]])


## (d) IL TETTO — dove il `clampf` finale mangia il tamponamento.
func _sezione_d() -> void:
	print("")
	print("─".repeat(74))
	print("  (d) IL TETTO — il residuo dichiarato, misurato invece che temuto")
	print("─".repeat(74))
	print("  Il `clampf` finale è PRE-ESISTENTE al tampone: quando l'allarme")
	print("  grezzo supera il divisore, le due gambe finiscono tutte e due a")
	print("  1,0 e lo smorzamento non può fare niente. Va letto ACCANTO al")
	print("  calo medio, o il calo medio lo nasconde.")
	var tamp := 0
	var libero := 0
	var parziale := 0
	var pieno := 0
	var cali_liberi: Array = []
	for c in _campioni:
		var d := c as Dictionary
		if float(d["conforto"]) <= 0.0:
			continue
		tamp += 1
		# l'oracolo non ricopia la formula: se la gamba SENZA conforto è
		# uscita esattamente 1,0, il clamp ha morso — e se anche quella CON
		# è a 1,0, non ha tamponato niente.
		if float(d["forza0"]) < 1.0:
			libero += 1
			cali_liberi.append(float(d["forza0"]) - float(d["forza"]))
		elif float(d["forza"]) < 1.0:
			parziale += 1
		else:
			pieno += 1
	if tamp == 0:
		print("  nessun campione tamponato: il tetto non si può misurare.")
		return
	print("")
	print("  percetti tamponati ............................ %d" % tamp)
	print("    sotto il tetto (lo smorzamento è pieno) ..... %d (%.0f%%)"
			% [libero, 100.0 * float(libero) / float(tamp)])
	print("    al tetto, ma il tampone lo scavalla ......... %d (%.0f%%)"
			% [parziale, 100.0 * float(parziale) / float(tamp)])
	print("    ⚠ al tetto da tutte e due le parti: NIENTE ... %d (%.0f%%)"
			% [pieno, 100.0 * float(pieno) / float(tamp)])
	print("  calo medio sui SOLI percetti sotto il tetto ... %.4f"
			% _media(cali_liberi))


## (e) IL PREZZO — i sussulti che non partono, e le strade lente che non
## cominciano.
func _sezione_e() -> void:
	print("")
	print("─".repeat(74))
	print("  (e) IL PREZZO — quanti «ah… sei tu» non succederanno")
	print("─".repeat(74))
	for fase in ["forma", "vivo"]:
		var tutti := _di_fase(fase)
		var tras_veri := 0
		var tras_senza := 0
		var soppressi := 0
		var aggiunti := 0
		for c in tutti:
			var d := c as Dictionary
			var a: bool = str(d["reazione"]) == "trasalisce"
			var b: bool = str(d["reazione0"]) == "trasalisce"
			if a:
				tras_veri += 1
			if b:
				tras_senza += 1
			if b and not a:
				soppressi += 1
			if a and not b:
				aggiunti += 1
		print("  %s — trasalimenti: %d adesso, %d senza il tampone"
				% [fase.to_upper(), tras_veri, tras_senza])
		print("      SOPPRESSI ................................. %d (%.0f%% di quelli)"
				% [soppressi, 100.0 * float(soppressi) / maxf(1.0, float(tras_senza))])
		print("      ⚠ AGGIUNTI (dev'essere ZERO) .............. %d" % aggiunti)
		print("      e altrettante strade lente che non cominciano: il")
		print("      raffreddamento del riconoscimento (`_riconoscimenti`) si")
		print("      scrive SOLO dentro il ramo `trasalisce`.")


## (g) LA FORMA IN VIGORE — dedotta dai numeri, non dal sorgente.
##
## Le tre forme che qualcuno potrebbe scrivere lasciano tre impronte diverse,
## e questo banco le distingue senza aprire `Limbico.gd`:
##  · **il guadagno diviso** (la specifica): calo relativo COSTANTE fra i
##    terzili, calo assoluto proporzionale alla reattività, e una classe di
##    campioni «al tetto da tutte e due le parti» NON vuota;
##  · **la sottrazione dal risultato**: calo assoluto costante, relativo che
##    esplode sui campioni piccoli;
##  · **la divisione DOPO il clamp** (`clampf(prodotto,0,1)/D`): nessun
##    campione «al tetto da tutte e due le parti» — perché lì il tampone
##    morderebbe anche a 1,0, che è esattamente la cosa che la forma decisa
##    non fa.
func _sezione_g() -> void:
	print("")
	print("─".repeat(74))
	print("  (g) QUALE FORMA È IN VIGORE — dedotta dai numeri")
	print("─".repeat(74))
	var rel: Array = []
	var ass: Array = []
	var al_tetto := 0
	var tetto_pieno := 0
	for c in _campioni:
		var d := c as Dictionary
		if float(d["conforto"]) <= 0.0:
			continue
		ass.append(float(d["forza0"]) - float(d["forza"]))
		if float(d["forza0"]) > 0.0:
			rel.append(1.0 - float(d["forza"]) / float(d["forza0"]))
		if float(d["forza0"]) >= 1.0:
			al_tetto += 1
			if float(d["forza"]) >= 1.0:
				tetto_pieno += 1
	if ass.is_empty():
		print("  nessun campione tamponato: la forma non si può dedurre.")
		return
	print("  dispersione del calo RELATIVO ..... %.4f (attesa: piccola)"
			% _scarto(rel))
	print("  dispersione del calo ASSOLUTO ..... %.4f (attesa: grande)"
			% _scarto(ass))
	print("  campioni al tetto ................. %d, di cui non tamponati %d"
			% [al_tetto, tetto_pieno])
	if al_tetto > 0 and tetto_pieno == 0:
		print("  ⚠️ NESSUN campione al tetto è rimasto non tamponato: il tampone")
		print("     sta mordendo DOPO il clamp. È `clampf(prodotto,0,1)/D`, cioè")
		print("     una forma diversa da quella decisa dall'autore.")
	if _scarto(rel) > _scarto(ass):
		print("  ⚠️ il calo relativo varia PIÙ dell'assoluto: il conforto sta")
		print("     SOTTRAENDO dal risultato invece di dividere il guadagno.")


func _scarto(a: Array) -> float:
	if a.size() < 2:
		return 0.0
	var m := _media(a)
	var s := 0.0
	for x in a:
		s += (float(x) - m) * (float(x) - m)
	return sqrt(s / float(a.size()))


## ⚠️ I SEI CANCELLI, alla fine e in chiaro. Ognuno stampa il numero che lo
## smentirebbe, non un «ok».
func _cancelli(residenti: Array, secondi: float) -> void:
	print("")
	print("█".repeat(74))
	print("⚠️  IL CANCELLO D'ARRESTO")
	print("█".repeat(74))

	# 1 — chi sta da solo non cambia di un bit
	var soli := 0
	var soli_rotti := 0
	for c in _campioni:
		var d := c as Dictionary
		if bool(d["comp_visibile"]) or int(d["altri"]) > 0 or bool(d["sul_filo"]):
			continue
		soli += 1
		# `==` e non `is_equal_approx`: a conforto zero il divisore è 1,0
		# esatto e `x / 1.0` è esatto in IEEE-754. Qui l'uguaglianza è una
		# proprietà della forma, non una speranza sul virgola mobile.
		if float(d["conforto"]) != 0.0 or float(d["forza"]) != float(d["forza0"]):
			soli_rotti += 1
	print("  1. CHI STA DA SOLO NON CAMBIA DI UN BIT")
	print("     percetti senza nessuno entro il raggio ....... %d" % soli)
	print("     ⚠ di cui cambiati (dev'essere ZERO) .......... %d" % soli_rotti)
	if soli == 0:
		print("     ⚠️ nessun campione: questo cancello NON ha girato, e un")
		print("        cancello che non gira non è un cancello (servono")
		print("        solitari veri: CHIBI_COPPIE più basso, o più tempo)")

	# 2 — può solo abbassare
	var alzati := 0
	var reaz_alzate := 0
	for c in _campioni:
		var d := c as Dictionary
		if float(d["forza"]) > float(d["forza0"]):
			alzati += 1
		if str(d["reazione"]) == "trasalisce" and str(d["reazione0"]) != "trasalisce":
			reaz_alzate += 1
	print("  2. IL PARAMETRO PUÒ SOLO ABBASSARE")
	print("     ⚠ percetti con la forza ALZATA ............... %d" % alzati)
	print("     ⚠ reazioni diventate «trasalisce» ............ %d" % reaz_alzate)

	# 3 — il calore non si tocca
	var calore_rotto := 0
	var cuori_rotti := 0
	for c in _campioni:
		var d := c as Dictionary
		if float(d["calore"]) != float(d["calore0"]):
			calore_rotto += 1
		var a: bool = str(d["reazione"]) == "si_illumina"
		var b: bool = str(d["reazione0"]) == "si_illumina"
		if a != b:
			cuori_rotti += 1
	print("  3. IL CALORE NON SI TOCCA (il cuoricino non si spegne)")
	print("     ⚠ campioni col calore diverso ................ %d" % calore_rotto)
	print("     ⚠ cuoricini comparsi o spariti ............... %d" % cuori_rotti)

	# 4 — il raffreddamento non diventa un moltiplicatore
	var p_coppia: Array = []
	var p_soli: Array = []
	for r in residenti:
		var lab := str((r as Dictionary).get("label", ""))
		var sec := float(_secondi_di.get(lab, 0.0))
		if sec < 20.0:
			continue      # troppo poco tempo a portata: non dice niente
		var tasso := 60.0 * float(_percetti_di.get(lab, 0)) / sec
		if bool(_in_coppia.get(lab, false)):
			p_coppia.append(tasso)
		else:
			p_soli.append(tasso)
	print("  4. IL RAFFREDDAMENTO NON DIVENTA UN MOLTIPLICATORE")
	print("     percetti al minuto (per minuto passato a portata di Mochi)")
	print("       chi ha un compagno ......................... %.2f  (n %d)"
			% [_media(p_coppia), p_coppia.size()])
	print("       chi non ce l'ha ............................ %.2f  (n %d)"
			% [_media(p_soli), p_soli.size()])
	print("     ⚠ devono somigliarsi: se chi è in coppia ne riceve di più, il")
	print("       raffreddamento è finito dentro il ramo `trasalisce` e la")
	print("       meccanica è diventata una classifica sociale.")
	print("     (il conto è sulle DUE fasi insieme, ed è legittimo qui: nella")
	print("      fase FORMA Mochi visita ogni gruppo per lo stesso tempo,")
	print("      quindi il confronto coppia/soli resta appaiato per costruzione)")
	if p_coppia.size() < 5 or p_soli.size() < 5:
		print("     ⚠️ MENO DI CINQUE RESIDENTI PER GRUPPO: questi due numeri")
		print("        NON si leggono. Con tre e due corpi la differenza fra le")
		print("        due medie è la differenza fra due persone, non fra due")
		print("        popolazioni — alzare CHIBI_COPPIE e le durate, o il")
		print("        cancello dice di no su un rumore.")

	# 5 — il villaggio non diventa più rumoroso
	var reaz_ora := 0
	var reaz_senza := 0
	for c in _campioni:
		var d := c as Dictionary
		if str(d["reazione"]) != "nulla":
			reaz_ora += 1
		if str(d["reazione0"]) != "nulla":
			reaz_senza += 1
	print("  5. IL VILLAGGIO NON DIVENTA PIÙ RUMOROSO")
	print("     reazioni non-nulla: %d adesso, %d senza il tampone"
			% [reaz_ora, reaz_senza])
	print("     ⚠ dev'essere «adesso ≤ senza»: l'unica uscita del tampone è un")
	print("       sussulto che NON parte (il secondo divieto — non si nomina mai)")
	var righe: Array = []
	for p in _pose:
		righe.append("%s %d" % [p, int(_pose[p])])
	print("     le pose emesse dai corpi: %s" % (", ".join(righe) if not righe.is_empty() else "(nessuna)"))
	print("     ⚠ e nessuna posa NUOVA deve comparire in questo elenco: il")
	print("       tampone non ha un vocabolario suo.")
	print("     ⚠️ MA QUESTO ELENCO È UN CAMPIONAMENTO A FOTOGRAMMI, e non è")
	print("        un conto: una posa scritta e riscritta dentro lo stesso")
	print("        fotogramma non ci finisce (misurato: 26 trasalimenti veri e")
	print("        zero pose «trasalisce» in elenco). Serve a vedere se compare")
	print("        una parola NUOVA — l\'invariante di questo cancello è la")
	print("        riga sopra, che conta le reazioni e non le pose.")

	# 6 — il prezzo resta una minoranza
	var soppressi := 0
	var tras_senza := 0
	for c in _campioni:
		var d := c as Dictionary
		if str(d["reazione0"]) == "trasalisce":
			tras_senza += 1
			if str(d["reazione"]) != "trasalisce":
				soppressi += 1
	print("  6. IL PREZZO RESTA UNA MINORANZA")
	print("     sussulti soppressi su tutti quelli del villaggio: %d su %d (%.0f%%)"
			% [soppressi, tras_senza,
			100.0 * float(soppressi) / maxf(1.0, float(tras_senza))])
	print("     ⚠ sopra la metà, il conforto lo sta prendendo qualcuno che non")
	print("       dovrebbe: il tampone morde solo su chi ha un compagno accanto")
	print("       nell'istante in cui arrivi, che è per costruzione una minoranza.")
	print("     ⚠ E LA FRAZIONE CHE CONTA È QUELLA DELLA FASE **VIVO**: nella")
	print("       fase FORMA la scena è costruita apposta perché il conforto ci")
	print("       sia quasi sempre, ed è un tetto — vedi (e), spezzata per fase.")
	print("")
	print("  (%.0f s di banco in tutto · TAMPONE_SOCIALE = %.3f · VICINI = %.2f m)"
			% [secondi, _tampone, VISITORS.VICINI])


## ⚠️ LE RIGHE PER LE REPLICHE, alla fine e in un posto solo.
##
## Quali numeri escono di qui non è una scelta di comodità: sono quelli che
## **cambiano fra due corse** e per cui una corsa sola non basta — la
## frequenza del conforto, il calo, il prezzo. I cancelli escono anche loro,
## ma per la ragione opposta: devono valere ZERO su OGNI replica, e un banco
## che li stampasse solo a schermo lascerebbe scoprire su una corsa su otto
## che una violazione c'era.
##
## E il nome porta la FASE, perché «forma» e «vivo» sono due grandezze
## diverse (un tetto e una frequenza): mediarle sarebbe la stessa cosa che
## mettere il possesso e i posati dentro la stessa frazione.
func _righe_misura(residenti: Array) -> void:
	print("")
	_misura("campioni", float(_campioni.size()))
	_misura("scartati.infedeli", float(_infedeli))
	_misura("scartati.senza_geometria", float(_senza_geo))
	for fase in ["forma", "vivo"]:
		var tutti := _di_fase(fase)
		var cali: Array = []
		var rel: Array = []
		var conf: Array = []
		var tamp := 0
		var tetto_pieno := 0
		var tras_senza := 0
		var soppressi := 0
		for c in tutti:
			var d := c as Dictionary
			if str(d["reazione0"]) == "trasalisce":
				tras_senza += 1
				if str(d["reazione"]) != "trasalisce":
					soppressi += 1
			if float(d["conforto"]) <= 0.0:
				continue
			tamp += 1
			conf.append(float(d["conforto"]))
			cali.append(float(d["forza0"]) - float(d["forza"]))
			if float(d["forza0"]) > 0.0:
				rel.append(1.0 - float(d["forza"]) / float(d["forza0"]))
			if float(d["forza0"]) >= 1.0 and float(d["forza"]) >= 1.0:
				tetto_pieno += 1
		_misura("percetti.%s" % fase, float(tutti.size()))
		_misura("tamponati.frazione.%s" % fase,
				float(tamp) / maxf(1.0, float(tutti.size())))
		_misura("conforto.medio.%s" % fase, _media(conf))
		_misura("calo.assoluto.%s" % fase, _media(cali))
		_misura("calo.relativo.%s" % fase, _media(rel))
		_misura("tetto.frazione_inerte.%s" % fase,
				float(tetto_pieno) / maxf(1.0, float(tamp)))
		_misura("prezzo.soppressi.%s" % fase, float(soppressi))
		_misura("prezzo.frazione.%s" % fase,
				float(soppressi) / maxf(1.0, float(tras_senza)))
	# LA FIRMA 1, in un numero: quanto cresce il calo dal terzile basso
	# all'alto. Con la forma decisa dev'essere circa il rapporto delle
	# reattività — che esce accanto, o il primo numero non si può leggere.
	var buoni: Array = []
	for c2 in _campioni:
		var d2 := c2 as Dictionary
		if float(d2["conforto"]) > 0.0 and float(d2["forza0"]) < 1.0:
			buoni.append(d2)
	if buoni.size() >= 9:
		buoni.sort_custom(func(x, y): return float(x["reatt"]) < float(y["reatt"]))
		@warning_ignore("integer_division")
		var n3 := buoni.size() / 3
		var basso: Array = buoni.slice(0, n3)
		var alto: Array = buoni.slice(n3 * 2)
		var cb: Array = []
		var ca: Array = []
		var rb: Array = []
		var ra: Array = []
		for d3 in basso:
			cb.append(float((d3 as Dictionary)["forza0"]) - float((d3 as Dictionary)["forza"]))
			rb.append(float((d3 as Dictionary)["reatt"]))
		for d4 in alto:
			ca.append(float((d4 as Dictionary)["forza0"]) - float((d4 as Dictionary)["forza"]))
			ra.append(float((d4 as Dictionary)["reatt"]))
		_misura("firma1.calo_alto_su_basso", _media(ca) / maxf(0.000001, _media(cb)))
		_misura("firma1.reatt_alto_su_basso", _media(ra) / maxf(0.000001, _media(rb)))
	# I CANCELLI: zero su ogni replica, o la meccanica va tolta.
	var f2 := 0
	var alzati := 0
	var calore_rotto := 0
	var soli := 0
	var soli_rotti := 0
	for c3 in _campioni:
		var d5 := c3 as Dictionary
		if float(d5["forza"]) > float(d5["forza0"]):
			alzati += 1
		if float(d5["calore"]) != float(d5["calore0"]):
			calore_rotto += 1
		if bool(d5["comp_visibile"]):
			continue
		if int(d5["altri"]) > 0:
			if float(d5["conforto"]) > 0.0:
				f2 += 1
			continue
		if bool(d5["sul_filo"]):
			continue
		soli += 1
		if float(d5["conforto"]) != 0.0 or float(d5["forza"]) != float(d5["forza0"]):
			soli_rotti += 1
	_misura("cancello1.soli", float(soli))
	_misura("cancello1.violazioni", float(soli_rotti))
	_misura("cancello2.alzati", float(alzati))
	_misura("cancello3.calore_diverso", float(calore_rotto))
	_misura("firma2.violazioni", float(f2))
	var p_coppia: Array = []
	var p_soli: Array = []
	for r in residenti:
		var lab := str((r as Dictionary).get("label", ""))
		var sec := float(_secondi_di.get(lab, 0.0))
		if sec < 20.0:
			continue
		var tasso := 60.0 * float(_percetti_di.get(lab, 0)) / sec
		if bool(_in_coppia.get(lab, false)):
			p_coppia.append(tasso)
		else:
			p_soli.append(tasso)
	_misura("cancello4.percetti_min.coppia", _media(p_coppia))
	_misura("cancello4.percetti_min.soli", _media(p_soli))
	_misura("cancello4.residenti.coppia", float(p_coppia.size()))
	_misura("cancello4.residenti.soli", float(p_soli.size()))
	var reaz_ora := 0
	var reaz_senza := 0
	for c4 in _campioni:
		var d6 := c4 as Dictionary
		if str(d6["reazione"]) != "nulla":
			reaz_ora += 1
		if str(d6["reazione0"]) != "nulla":
			reaz_senza += 1
	_misura("cancello5.reazioni_ora", float(reaz_ora))
	_misura("cancello5.reazioni_senza", float(reaz_senza))
