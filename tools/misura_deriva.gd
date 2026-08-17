extends SceneTree
## IL METRO DELLA DERIVA — quanto si vede un tratto spostato, e quanto
## spingerebbe la vita vera.
##
##   CHIBI_GIORNI=1 CHIBI_QUANTI=14 ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --headless --path . --script res://tools/misura_deriva.gd
##
## Questo banco NON implementa nessuna deriva: **il metro viene prima del
## meccanismo**. Risponde a cinque domande che nessuna asserzione booleana sa
## fare, e a tutte e cinque con dei numeri:
##
##   1. QUANTO SI VEDE un tratto spostato di 0,05 / 0,10 / 0,20 / 0,35 —
##      su ognuno dei canali che il giocatore può davvero vedere;
##   2. QUANTO SPINGEREBBE la vita vera: quante volte al giorno capita
##      ognuna delle spinte candidate, per persona;
##   3. LA VARIETÀ DI PARTENZA dei cinque tratti (è la scala contro cui
##      giudicare se una deriva fa convergere le persone);
##   4. QUANTO DURA UNA STAGIONE in minuti reali;
##   5. e la domanda di controllo: DUE RESIDENTI DIVERSI, OGGI, si
##      comportano in modo misurabilmente diverso? Se no, i tratti non
##      contano già adesso.
##
## ⚠️ **I TRATTI SONO CINQUE, NON QUATTRO.** `Animo.TRATTI` li elenca, e
## l'elenco si legge di là: `orgoglio` è il quinto ed è il secondo più letto.
##
## ══════════════════ LE REGOLE DEL BANCO, tutte già pagate ══════════════════
##
## **A · L'ORACOLO È INDIPENDENTE.** Non si chiede a nessun sistema se è
## d'accordo con sé stesso.
##   · il percetto della strada veloce si rileva dal SALTO ALL'INSÙ del
##     raffreddamento (`_sussulto_cd`), come in `misura_sussulti.gd`;
##   · il sonno si legge dal CORPO (`is_hidden`), non dal registro del C++;
##   · le spinte si contano dai REGISTRI VERI (i ricordi dell'Animo, le
##     righe di `Affetti`, gli incontri di `Cricche`, i fili di `Legami`),
##     al netto di una BASELINE presa dopo il caricamento;
##   · e i gemelli non ri-implementano niente: sono `Limbico` e `Animo`
##     VERI, col tratto spostato, a cui si passano gli STESSI stimoli.
##
## **B · IL VILLAGGIO DELL'AUTORE NON SI TOCCA.** `set_persist_for_debug(false)`
## subito dopo il caricamento, e l'impronta SHA-256 di `user://village.json`
## confrontata prima e dopo. Un banco altrui si è già portato via due
## gigabyte, e questo file non deve poterlo fare.
##
## **C · L'OROLOGIO NON SI ACCELERA.** Una giornata dura quattro minuti reali
## (`DayNight.cycle_seconds`), e si legge di là: un ciclo scritto qui sarebbe
## una seconda verità. Il banco dura quindi quanto dura una giornata vera.
##
## **D · IL CARICAMENTO PORTA IL VILLAGGIO DI QUALCUN ALTRO.** Il MainLevel
## apre `village.json`: `Affetti._righe`, `Cricche._incontri` e i fili sono
## già pieni. Si prende una BASELINE e si contano solo i DELTA — senza,
## la prima corsa dichiara «98 chiacchiere per residente in trenta secondi»,
## cioè misura la partita dell'autore.
##
## **E · LE LABEL DEVONO ESSERE UNICHE.** `_animi` è indicizzato per label, e
## i semi a passo fisso ne producono di doppie: due residenti con la stessa
## label sono UNA persona sola per metà dei sistemi. Il banco le scarta.
##
## **F · IL PAREGGIO È ALL'ISTANTE.** I gemelli ricevono `marchi` e `arousal`
## del corpo vero nell'istante del percetto, poi rispondono con la LORO
## reattività. Non accumulano quindi la loro storia (un gemello più pauroso
## si farebbe più arousal, e quindi altri sussulti): i conteggi per ampiezza
## sono un PAVIMENTO, ed è il verso giusto.
##
## **G · LA RIPROIEZIONE NON È FACOLTATIVA.** `Limbico.reattivita` e
## `abitudine` sono derivate dai tratti *una volta sola*, dentro `setup()`, e
## per giunta sono PERSISTITE (`Limbico.save`). Un gemello costruito con
## `setup(dna) + load(save)` si ritrova la reattività della persona di
## partenza: il tratto è spostato e il canale non se ne accorge. Il banco
## riproietta a mano (`_riproietta`) e MISURA quanto vale non farlo.

const ANIMO := preload("res://scenes/npc/Animo.gd")
const LIMBICO := preload("res://scenes/npc/Limbico.gd")
const ANDATURA := preload("res://scenes/npc/Andatura.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")
const AFFETTI := preload("res://scenes/npc/Affetti.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")
const DAYNIGHT := preload("res://scenes/world/DayNight.gd")
const CRICCHE := preload("res://scenes/npc/Cricche.gd")
const BRAIN := preload("res://scenes/npc/VillagerBrain.gd")
const GESTI := preload("res://scenes/npc/Gesti.gd")

## Le ampiezze chieste dall'autore. Sono FRAZIONI DEL CAMPO (0..1), non
## frazioni del tratto: la seconda lettura è una scelta di progetto e va
## fatta dopo aver visto questi numeri, non prima.
const AMPIEZZE := [0.05, 0.10, 0.20, 0.35]
## Quanti genomi si generano per la distribuzione di popolazione. Il campione
## dei residenti in scena è troppo piccolo per una deviazione standard.
const CAMPIONE_POPOLAZIONE := 4000
## Quanti tiri appaiati per la scelta del mestiere.
const TIRI_MESTIERE := 400
## La finestra del rig, in secondi, e il suo passo. Serve solo a far
## convergere la fusione dei neurotrasmettitori (k = 1 − e^(−6·dt)).
const RIG_SEC := 1.5
const RIG_DT := 1.0 / 30.0

var _vis: Node = null
var _build: Node = null
var _player: Node3D = null
var _dn: Node = null
var _perc: Node = null
var _lavori: Node = null

var _residenti: Array = []          # le righe VERE, filtrate per label unica
var _dna_di := {}                   # label -> dna (serve a fabbricare i gemelli)
var _nome_di := {}                  # label -> nome del dna (Cricche e Affetti indicizzano COSI')
var _animo_di := {}                 # label -> Animo vero

# --- la corsa viva ---
var _gemelli := {}                  # label -> {"tratto|delta" -> Limbico}
var _esiti := {}                    # "tratto|delta" -> {reazione -> quanti}
var _discordi := {}                 # "tratto|delta" -> quante volte l'esito cambia
var _forze := {}                    # "tratto|delta" -> [[forza vera, forza del gemello], …]
                                    # SOLO sui percetti che hanno fatto trasalire: e' la'
                                    # che la forza diventa una posa e un rallentando
var _esiti_veri := {}               # reazione -> quanti (il villaggio com'è)
var _stimoli: Array = []            # {lab, grezzo, arousal, marchi, vera}: il percetto VERO,
                                    # conservato per chiedere «quanta deriva serve a ribaltarlo»
var _percetti := 0
var _occasioni_morso := 0
var _morsi := 0
var _scoppi := 0
var _sec_vicino := 0.0
var _dorme := {}                    # label -> stava dormendo
var _sonno_eventi: Array = []       # {"label", "che", "ora", "giorno"}
var _azioni := {}
var _nome_azione := {}   # indice C++ -> nome, chiesto al ponte, mai ricopiato                   # azione dell'agenda -> quanti fotogrammi
var _spinte := {}                   # label -> {tipo -> quanti}
var _giorni_visti := 0
var _giorno0 := 0
var _base_affetti := 0
var _base_cricche := 0
var _base_ricordi := {}             # label -> quanti ricordi aveva
var _base_friend := {}
var _base_momenti := {}
var _incontri_per_giorno := {}      # "label|giorno" -> quanti
var _meta := Vector3.ZERO
var _sosta := 0.0
var _lavoro := 3.0
var _verbo := 0
const VERBI := ["annaffia", "semina", "raccoglie", "costruisce", "pesca"]

var _da_liberare: Array = []


func _init() -> void:
	_go()


func _m(c: Vector2i) -> Vector3:
	return Vector3(c.x, 0.0, c.y)


# ════════════════════════════════════════════════════════ statistica minima

func _media(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += float(v)
	return s / float(a.size())


func _dev(a: Array) -> float:
	if a.size() < 2:
		return 0.0
	var m := _media(a)
	var s := 0.0
	for v in a:
		s += (float(v) - m) * (float(v) - m)
	return sqrt(s / float(a.size() - 1))


func _min(a: Array) -> float:
	var v := INF
	for x in a:
		v = minf(v, float(x))
	return 0.0 if v == INF else v


func _max(a: Array) -> float:
	var v := -INF
	for x in a:
		v = maxf(v, float(x))
	return 0.0 if v == -INF else v


## La frazione di `a` che sta sotto `x`, in percentuale. Serve a dire quanto
## vale un'ampiezza in PERCENTILI, che è l'unica scala che significa
## qualcosa quando si parla di «quanto è diversa una persona da un'altra».
func _percentile_di(a: Array, x: float) -> float:
	if a.is_empty():
		return 0.0
	var n := 0
	for v in a:
		if float(v) < x:
			n += 1
	return 100.0 * float(n) / float(a.size())


func _mediana(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


# ════════════════════════════════════════════════════════ i gemelli

## Un `Animo` VERO, uguale a quello di quella persona, col tratto spostato.
##
## L'ordine dei quattro gesti non è cosmetico:
##   1. `setup(dna)` costruisce la persona dal genoma;
##   2. `load(base.save())` ci mette sopra la sua biografia (ricordi, marchi,
##      arousal, umore, il dado) — e **anche la sua reattività salvata**;
##   3. si sposta il tratto;
##   4. `_riproietta()` rifà i due derivati dai tratti nuovi.
## Senza il 4, il tratto è spostato e nessun canale se ne accorge (regola G).
func _gemello(base, dna: Dictionary, tratto: String,
		delta: float, riproietta := true) -> RefCounted:
	var g = ANIMO.new()
	g.setup(dna)
	g.load(base.save())
	if tratto != "":
		g.tratti[tratto] = clampf(float(g.tratti.get(tratto, 0.5)) + delta, 0.0, 1.0)
	if riproietta:
		_riproietta(g)
	return g


## Rifà i derivati dei tratti SENZA buttare via i livelli vivi.
## ⚠️ `Limbico.setup()` finisce con `neuro = neuro_base.duplicate()`: chiamarlo
## e basta azzererebbe la chimica del momento, cioè misurerebbe un corpo che
## non esiste. Si conserva `neuro`, si riproietta, si rimette — e poi
## `sincronizza_neuro()` rimette il punto di riposo dove i BISOGNI lo vogliono
## oggi, che è il percorso vero (`Animo.setup`).
func _riproietta(a) -> void:
	var vivo: Dictionary = (a.limbico.neuro as Dictionary).duplicate()
	a.limbico.setup(a.tratti)
	a.limbico.neuro = vivo
	a.sincronizza_neuro()


## Un `Limbico` nudo col carattere spostato: serve alla corsa viva, dove di
## una persona interessa solo come RISPONDE a uno stimolo.
func _gemello_limbico(tratti: Dictionary, tratto: String, delta: float) -> RefCounted:
	var t: Dictionary = tratti.duplicate()
	t[tratto] = clampf(float(t.get(tratto, 0.5)) + delta, 0.0, 1.0)
	var l = LIMBICO.new()
	l.setup(t)
	return l


# ════════════════════════════════════════════════════════ il rig vero

## Un corpo finto ma un'ANDATURA vera: le formule del passo non si
## ricopiano qui, si fanno girare. `applica()` scrive sui nodi e noi
## leggiamo i nodi — è lo stesso gesto del gioco.
func _fabbrica_rig() -> Dictionary:
	var vis := Node3D.new()
	var head := Node3D.new()
	var arms: Array = [Node3D.new(), Node3D.new()]
	var legs: Array = [Node3D.new(), Node3D.new()]
	var ears: Array = [Node3D.new(), Node3D.new()]
	var tail := Node3D.new()
	var tip := Node3D.new()
	vis.add_child(head)
	for n in arms:
		vis.add_child(n)
	for n in legs:
		vis.add_child(n)
	for n in ears:
		vis.add_child(n)
	vis.add_child(tail)
	tail.add_child(tip)
	var a = ANDATURA.new()
	a.parti({"head": head, "arms": arms, "legs": legs, "ears": ears,
			"tail": tail, "tail_tip": tip}, vis)
	_da_liberare.append(vis)
	return {"and": a, "vis": vis, "ear": ears[0], "tail": tail}


## Fa camminare un corpo per `RIG_SEC` con la chimica `neuro` e restituisce i
## canali che il giocatore vede. Il moto è identico per tutti i corpi
## confrontati: quello che cambia è solo la chimica.
func _canali_rig(neuro: Dictionary) -> Dictionary:
	var r := _fabbrica_rig()
	var a = r["and"]
	var vis: Node3D = r["vis"]
	var ear: Node3D = r["ear"]
	var tail: Node3D = r["tail"]
	a.set_neuro(neuro)
	var gobba: Array = []
	var orecchie: Array = []
	var coda_max := 0.0
	var hop_max := 0.0
	var coda_pitch := 0.0
	var p := Vector3.ZERO
	var passi := int(RIG_SEC / RIG_DT)
	for i in passi:
		p.z -= 1.45 * RIG_DT          # la velocità di un vicino che cammina
		a.misura(RIG_DT, p, 0.0)
		a.applica()
		# la seconda metà: la fusione dei neurotrasmettitori è già a regime
		if i > passi / 2:
			gobba.append(vis.rotation.x)
			orecchie.append(ear.rotation.x)
			coda_max = maxf(coda_max, absf(tail.rotation.y))
			hop_max = maxf(hop_max, vis.position.y)
			coda_pitch = tail.rotation.x
	vis.free()
	_da_liberare.erase(vis)
	return {"gobba": _media(gobba), "orecchie": _media(orecchie),
			"coda": coda_max, "coda_pitch": coda_pitch, "hop": hop_max}


func _scarto_rig(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {}
	for k in a:
		out[k] = float(b[k]) - float(a[k])
	return out


# ════════════════════════════════════════════════════════ la corsa

func _go() -> void:
	var giorni := 1.0
	if OS.get_environment("CHIBI_GIORNI") != "":
		giorni = float(OS.get_environment("CHIBI_GIORNI"))
	var quanti := 14
	if OS.get_environment("CHIBI_QUANTI") != "":
		quanti = int(OS.get_environment("CHIBI_QUANTI"))
	var con_guardia := OS.get_environment("CHIBI_GUARDIA") != "0"

	# ── B · l'impronta del villaggio dell'autore, PRIMA
	var salvataggio := "user://village.json"
	var impronta_prima := ""
	if FileAccess.file_exists(salvataggio):
		impronta_prima = FileAccess.get_sha256(salvataggio)

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 12:
		await process_frame
	var liv := current_scene
	_build = liv.get_node_or_null("BuildSystem")
	_vis = liv.get_node_or_null("Visitors")
	_player = liv.get_node_or_null("Player") as Node3D
	_dn = liv.get_node_or_null("DayNight")
	_perc = liv.get_node_or_null("Percezione")
	_lavori = liv.get_node_or_null("Lavori")
	if _build == null or _vis == null or _player == null or _dn == null:
		print("GUASTO: manca qualcosa nel MainLevel")
		quit(1)
		return
	_build.call("set_persist_for_debug", false)
	await create_timer(1.5).timeout

	print("")
	print("█".repeat(78))
	print("IL METRO DELLA DERIVA — %d residenti, %.1f giornate di gioco" % [quanti, giorni])
	print("█".repeat(78))

	_parte0_il_tempo(giorni)

	# ── il villaggio del banco
	_vis.call("debug_reset")
	_costruisci(quanti)
	await create_timer(1.5).timeout
	_raccogli_residenti()
	if _residenti.size() < 2:
		print("GUASTO: meno di due residenti con label unica")
		quit(1)
		return
	for k in _residenti.size():
		_vis.call("debug_stage_resident", k, _m((_residenti[k] as Dictionary)["cell"]))
	await create_timer(1.0).timeout
	if con_guardia and _lavori != null:
		_lavori.call("assegna", str((_residenti[0] as Dictionary)["label"]), "guardia")
	_mappa_azioni()
	_prepara_popolazione()
	print("")
	print("     (popolazione preparata come in `misura_sussulti.gd`: un terzo con una")
	print("      paura appresa, un terzo a mezza forza e un gradino sopra, un terzo che")
	print("      ti vuole bene. Senza, la strada veloce non ha niente da leggere.%s)"
			% ("" if con_guardia else " Nessuna guardia: CHIBI_GUARDIA=0"))

	_parte1_varieta()
	_parte2_due_persone()
	_parte3_banco_puro()

	# ── la corsa viva
	_baseline()
	_prepara_gemelli()
	print("")
	print("─".repeat(78))
	print("  LA CORSA VIVA — %.0f s di gioco (l'orologio è quello vero: %.0f s/giornata)"
			% [giorni * float(_dn.get("cycle_seconds")), float(_dn.get("cycle_seconds"))])
	print("─".repeat(78))
	await _corsa(giorni * float(_dn.get("cycle_seconds")))

	_parte3b_sussulti_vivi(giorni)
	_parte4_le_spinte(giorni)
	_parte5_agenda()

	# ── B · l'impronta DOPO
	var impronta_dopo := ""
	if FileAccess.file_exists(salvataggio):
		impronta_dopo = FileAccess.get_sha256(salvataggio)
	print("")
	print("─".repeat(78))
	print("  IL VILLAGGIO DELL'AUTORE")
	print("    impronta prima ... %s" % (impronta_prima if impronta_prima != "" else "(nessun file)"))
	print("    impronta dopo .... %s" % (impronta_dopo if impronta_dopo != "" else "(nessun file)"))
	print("    ⇒ %s" % ("INTATTO" if impronta_prima == impronta_dopo else "⚠️ TOCCATO — GUASTO DEL BANCO"))
	print("─".repeat(78))
	for n in _da_liberare:
		if is_instance_valid(n):
			n.free()
	quit(0)


func _costruisci(quanti: int) -> void:
	var celle: Array[Vector2i] = []
	var raggio := 7
	for gx in range(-raggio, raggio):
		for gz in range(-raggio, raggio):
			celle.append(Vector2i(gx * 2, gz * 2))
	celle.shuffle()
	var letti := 0
	var i := 0
	var celle_letto: Array[Vector2i] = []
	while letti < quanti and i < celle.size():
		var c: Vector2i = celle[i]
		i += 1
		_build.call("place_cell", c, "Letto", 0, false)
		_build.call("place_cell", c, "Tetto", 0, false)
		if not bool(_build.call("has_cover", c)):
			continue
		letti += 1
		celle_letto.append(c)
	# ⚠️ un prato NUDO non produce quasi nessuna spinta: senza panchine né
	# cespugli l'agenda ripiega su «gironzola» e non si incontra nessuno.
	var extra := 0
	while extra < 14 and i < celle.size():
		var c: Vector2i = celle[i]
		i += 1
		_build.call("place_cell", c,
				["Cespuglio", "Panchina", "Aiuola", "Lampione"][extra % 4], 0, false)
		extra += 1
	_build.call("aggiorna_varchi_ora")
	for k in celle_letto.size():
		_vis.call("debug_settle", 5000 + k * 37, celle_letto[k])


## ⚠️ REGOLA E: le label doppie sono UNA persona sola per metà dei sistemi.
func _raccogli_residenti() -> void:
	var animi: Dictionary = _vis.get("_animi")
	var viste := {}
	for r in (_vis.get("_residents") as Array):
		var lab := str((r as Dictionary).get("label", ""))
		if lab == "" or viste.has(lab) or not animi.has(lab):
			continue
		viste[lab] = true
		_residenti.append(r)
		_dna_di[lab] = (r as Dictionary).get("dna", {})
		_nome_di[lab] = str(((r as Dictionary).get("dna", {}) as Dictionary).get("name", ""))
		_animo_di[lab] = animi[lab]


# ════════════════════════════════════════ PARTE 0 · IL TEMPO (domanda 4)

func _parte0_il_tempo(giorni: float) -> void:
	var ciclo: float = float(_dn.get("cycle_seconds"))
	var stag: int = DAYNIGHT.SEASON_DAYS
	var anno: int = DAYNIGHT.YEAR_DAYS
	print("")
	print("─".repeat(78))
	print("  PARTE 0 · IL TEMPO — quanto dura una stagione, in minuti veri")
	print("    una giornata di gioco ............ %.0f s = %.1f min reali" % [ciclo, ciclo / 60.0])
	print("    una stagione (%d giornate) ........ %.1f min reali" % [stag, stag * ciclo / 60.0])
	print("    un anno (%d giornate) ............. %.1f min reali" % [anno, anno * ciclo / 60.0])
	print("    in UN'ORA reale di gioco stanno .. %.1f giornate" % (3600.0 / ciclo))
	print("    «venti notti protette» sono ...... %.1f min reali (%.1f stagioni)"
			% [20.0 * ciclo / 60.0, 20.0 / float(stag)])
	print("    la mezza vita di un RICORDO ...... %.0f giornate = %.1f min = %.2f stagioni"
			% [ANIMO.MEZZA_VITA, ANIMO.MEZZA_VITA * ciclo / 60.0, ANIMO.MEZZA_VITA / float(stag)])
	print("    la memoria degli AFFETTI ......... %.0f–%.0f giornate = %.2f–%.2f stagioni"
			% [AFFETTI.RECENZA_BASE, AFFETTI.RECENZA_LEALE,
			AFFETTI.RECENZA_BASE / float(stag), AFFETTI.RECENZA_LEALE / float(stag)])
	print("    questo banco dura ................ %.1f min reali" % (giorni * ciclo / 60.0))


# ════════════════════════════════════ PARTE 1 · LA VARIETÀ (domanda 3)

func _parte1_varieta() -> void:
	print("")
	print("─".repeat(78))
	print("  PARTE 1 · LA VARIETÀ DI PARTENZA — la scala contro cui giudicare tutto")
	print("")
	# a) la popolazione, dal generatore VERO
	var pop := {}
	for t in ANIMO.TRATTI:
		pop[t] = []
	for s in CAMPIONE_POPOLAZIONE:
		var d: Dictionary = DNA.generate(s * 7 + 3)
		var tt: Dictionary = d.get("tratti", {})
		for t in ANIMO.TRATTI:
			(pop[t] as Array).append(float(tt.get(t, 0.5)))
	print("  a) LA POPOLAZIONE (%d genomi dal generatore vero)" % CAMPIONE_POPOLAZIONE)
	print("     %-11s %8s %8s %8s %8s %8s" % ["tratto", "media", "dev.std", "min", "max", "mediana"])
	for t in ANIMO.TRATTI:
		var a: Array = pop[t]
		print("     %-11s %8.4f %8.4f %8.4f %8.4f %8.4f"
				% [t, _media(a), _dev(a), _min(a), _max(a), _mediana(a)])
	var tutti: Array = []
	for t in ANIMO.TRATTI:
		tutti.append_array(pop[t] as Array)
	var dev_pop := _dev(tutti)
	print("     (tutti e cinque insieme: media %.4f, dev.std %.4f)" % [_media(tutti), dev_pop])
	print("")
	print("  ⇒ QUANTO VALE UN'AMPIEZZA, su quella scala")
	print("     %8s %10s %26s" % ["ampiezza", "in dev.std", "il mediano passa al…"])
	var med := _mediana(tutti)
	for amp in AMPIEZZE:
		print("     %8.2f %10.2f σ %19.0f° percentile (da %.0f°)"
				% [amp, float(amp) / maxf(0.0001, dev_pop),
				_percentile_di(tutti, med + float(amp)), _percentile_di(tutti, med)])
	print("")
	# b) i residenti in scena
	print("  b) I %d RESIDENTI DI QUESTO VILLAGGIO" % _residenti.size())
	print("     %-11s %8s %8s %8s %8s" % ["tratto", "media", "dev.std", "min", "max"])
	for t in ANIMO.TRATTI:
		var a: Array = []
		for lab in _animo_di:
			a.append(float((_animo_di[lab] as RefCounted).tratti.get(t, 0.5)))
		print("     %-11s %8.4f %8.4f %8.4f %8.4f" % [t, _media(a), _dev(a), _min(a), _max(a)])
	print("")
	# c) i DERIVATI: è lì che il carattere diventa comportamento
	print("  c) I DERIVATI DEI TRATTI, sui residenti veri (min → max)")
	var reatt: Array = []
	var abit: Array = []
	var dis: Array = []
	var conf: Array = []
	var mezza: Array = []
	var pnoia: Array = []
	for lab in _animo_di:
		var a = _animo_di[lab]
		reatt.append(float(a.limbico.reattivita))
		abit.append(float(a.limbico.abitudine))
		var s: Dictionary = a.soglie()
		dis.append(float(s["diserzione"]))
		conf.append(float(s["confronto"]))
		mezza.append(lerpf(AFFETTI.RECENZA_BASE, AFFETTI.RECENZA_LEALE,
				float(a.tratti.get("lealta", 0.5))))
		pnoia.append(a.peso_drive("noia"))
	print("     reattività (cod, gri) ......... %.3f → %.3f   (media %.3f)" % [_min(reatt), _max(reatt), _media(reatt)])
	print("     abitudine (amb) ............... %.3f → %.3f" % [_min(abit), _max(abit)])
	print("     soglia della DISERZIONE ....... %.3f → %.3f" % [_min(dis), _max(dis)])
	print("     soglia del CONFRONTO .......... %.3f → %.3f" % [_min(conf), _max(conf)])
	print("     mezza vita degli AFFETTI ...... %.1f → %.1f giornate" % [_min(mezza), _max(mezza)])
	print("     peso del drive «noia» (amb) ... %.3f → %.3f" % [_min(pnoia), _max(pnoia)])
	print("")
	# d) IL MURO. Una deriva ADDITIVA (±amp per tutti) tosa gli estremi contro
	#    0 e 1: tre codardi a 0.85/0.92/0.98 spinti in su finiscono a
	#    1.00/1.00/1.00, cioè tre persone diventate la stessa persona. È il
	#    numero che decide fra «frazione del campo» e «frazione della distanza
	#    dal bordo», e va guardato PRIMA di scegliere la forma della deriva.
	print("  d) QUANTI TRATTI FINIREBBERO CONTRO IL MURO (0 o 1) con una deriva ADDITIVA")
	print("     su %d residenti × %d tratti = %d valori"
			% [_residenti.size(), ANIMO.TRATTI.size(), _residenti.size() * ANIMO.TRATTI.size()])
	for amp in AMPIEZZE:
		var contro := 0
		var tot := 0
		for lab in _animo_di:
			var a = _animo_di[lab]
			for t in ANIMO.TRATTI:
				tot += 1
				var v := float(a.tratti.get(t, 0.5))
				if v + float(amp) >= 1.0 or v - float(amp) <= 0.0:
					contro += 1
		print("     ±%.2f → %d su %d (%.0f%%) toccherebbero un bordo in almeno un verso"
				% [float(amp), contro, tot, 100.0 * float(contro) / maxf(1.0, float(tot))])
	print("     (con una deriva proporzionale alla distanza dal bordo — δ = f·(limite−base) —")
	print("      il conto è ZERO per costruzione, a qualunque ampiezza: nessuno può")
	print("      arrivare a 0 o 1, e l'ordine fra le persone non si inverte mai.)")
	print("")
	# e) un osservabile che i tratti NON toccano, per confronto
	_finestra_di_sonno_dei_residenti()


## L'ora del risveglio, letta dal C++ VERO (`debug_in_finestra`). Serve due
## volte: qui come metro di varietà, e nella PARTE 3 come canale a zero.
func _finestra_di_sonno_dei_residenti() -> void:
	var ecs = _vis.get("_ecs")
	if ecs == null:
		print("  e) LA FINESTRA DEL SONNO: EcsMondo non c'è (GDExtension non caricata)")
		return
	var ore: Array = []
	for r in _residenti:
		var f := _finestra_di(r)
		if f.has("alba"):
			ore.append(float(f["alba"]))
	print("  e) L'ORA DEL RISVEGLIO (dal C++ vero, `debug_in_finestra`)")
	print("     su %d residenti: %.3f → %.3f (media %.3f) — in ore: %.1f → %.1f"
			% [ore.size(), _min(ore), _max(ore), _media(ore), _min(ore) * 24.0, _max(ore) * 24.0])
	print("     ⚠️ questa varietà NON viene dai tratti: `finestra_di_sonno(indole, quirk, ora)`.")


## Scandaglia l'ora e trova i bordi della finestra di sonno di quel residente.
func _finestra_di(r: Dictionary) -> Dictionary:
	var ecs = _vis.get("_ecs")
	if ecs == null:
		return {}
	var brain = _vis.call("_ensure_brain", r)
	if brain == null:
		return {}
	var mask: int = ecs.maschera_indole(PackedStringArray(brain.indole))
	var q: int = ecs.indice_quirk(str(brain.quirk))
	var prima: bool = ecs.debug_in_finestra(mask, q, 0.0)
	var tramonto := -1.0
	var alba := -1.0
	for i in range(1, 2000):
		var ora := float(i) / 2000.0
		var dentro: bool = ecs.debug_in_finestra(mask, q, ora)
		if dentro and not prima:
			tramonto = ora
		elif prima and not dentro:
			alba = ora
		prima = dentro
	return {"alba": alba, "tramonto": tramonto, "mask": mask, "quirk": q}


# ═══════════════════ PARTE 2 · DUE PERSONE DIVERSE, OGGI? (domanda 5)

func _parte2_due_persone() -> void:
	print("")
	print("─".repeat(78))
	print("  PARTE 2 · DUE RESIDENTI DIVERSI SI COMPORTANO DIVERSAMENTE, OGGI?")
	print("     (se no, i tratti non contano già adesso e la deriva non conterebbe niente)")
	print("")
	# 1 · la strada veloce, sulla STESSA griglia di stimoli per tutti
	var righe: Array = []
	for r in _residenti:
		var lab := str((r as Dictionary)["label"])
		var a = _animo_di[lab]
		righe.append({"lab": lab, "sus": _quanti_sussulti(a.tratti),
				"mor": _quanti_morsi(a), "dis": float(a.soglie()["diserzione"]),
				"cod": float(a.tratti.get("codardia", 0.5))})
	righe.sort_custom(func(x, y): return float(x["sus"]) > float(y["sus"]))
	print("  1 · LA STRADA VELOCE — la STESSA griglia di 891 stimoli a ognuno")
	print("     %-14s %6s %10s %10s %8s" % ["chi", "cod", "trasalisce", "morsi", "diserz."])
	for x in righe:
		print("     %-14s %6.3f %10d %10d %8.3f"
				% [x["lab"], x["cod"], x["sus"], x["mor"], x["dis"]])
	var sus: Array = []
	for x in righe:
		sus.append(float(x["sus"]))
	print("     ⇒ scarto fra il più e il meno pauroso: %.0f contro %.0f trasalimenti (×%.2f)"
			% [_max(sus), _min(sus), _max(sus) / maxf(1.0, _min(sus))])
	print("")
	# 2 · il mestiere che sceglierebbero
	print("  2 · IL MESTIERE CHE SCEGLIEREBBERO OGGI (%d tiri a testa, dado loro)" % TIRI_MESTIERE)
	var compiti: Array = ANIMO.COMPITI.keys()
	var dist_di := {}
	for r in _residenti:
		var lab := str((r as Dictionary)["label"])
		var g = _gemello(_animo_di[lab], _dna_di[lab], "", 0.0)
		var d := {}
		for _k in TIRI_MESTIERE:
			var s := str(g.decide(compiti, "se_stesso"))
			d[s] = int(d.get(s, 0)) + 1
		dist_di[lab] = d
	var labs: Array = dist_di.keys()
	var tv: Array = []
	for i in labs.size():
		for j in range(i + 1, labs.size()):
			tv.append(_distanza_totale(dist_di[labs[i]], dist_di[labs[j]], TIRI_MESTIERE))
	for lab in labs:
		var d: Dictionary = dist_di[lab]
		var top := ""
		var q := 0
		for k in d:
			if int(d[k]) > q:
				q = int(d[k])
				top = str(k)
		print("     %-14s preferito «%s» %d%% · mestieri diversi giocati: %d"
				% [lab, top, roundi(100.0 * float(q) / float(TIRI_MESTIERE)), d.size()])
	print("     ⇒ distanza fra due persone (frazione di giornate diverse): mediana %.0f%%, max %.0f%%"
			% [100.0 * _mediana(tv), 100.0 * _max(tv)])


## Quanti trasalimenti su una griglia fissa di stimoli veri. La griglia è la
## stessa per tutti: quello che cambia è la persona.
func _quanti_sussulti(tratti: Dictionary) -> int:
	var l = LIMBICO.new()
	l.setup(tratti)
	var n := 0
	for i in 33:
		var carica := -1.0 + 2.0 * float(i) / 32.0
		for j in 27:
			var grezzo := float(j) / 26.0
			l.arousal = 0.0
			l.marchi = {"chi|giocatore": {"carica": carica, "quando": 0}}
			var s: Dictionary = l.percepisci("giocatore", "", grezzo)
			if str(s.get("reazione", "")) == "trasalisce":
				n += 1
	return n


## Quanti morsi della lingua prima di scoppiare, su una COPIA (mai sul corpo
## vero: `trattieni` consuma la regolazione).
func _quanti_morsi(base) -> int:
	var l = LIMBICO.new()
	l.load(base.limbico.save())
	l.neuro_base = (base.limbico.neuro_base as Dictionary).duplicate()
	l.regolazione = 1.0
	var n := 0
	while n < 200 and l.trattieni():
		n += 1
	return n


func _distanza_totale(a: Dictionary, b: Dictionary, tot: int) -> float:
	var chiavi := {}
	for k in a:
		chiavi[k] = true
	for k in b:
		chiavi[k] = true
	var s := 0.0
	for k in chiavi:
		s += absf(float(a.get(k, 0)) - float(b.get(k, 0)))
	return 0.5 * s / float(tot)


# ═══════════ PARTE 3 · QUANTO SI VEDE UNO SPOSTAMENTO (domanda 1, banco)

func _parte3_banco_puro() -> void:
	print("")
	print("─".repeat(78))
	print("  PARTE 3 · QUANTO SI VEDE UN TRATTO SPOSTATO — un canale per volta")
	print("     Ogni numero è la MEDIA sui %d residenti veri, appaiata: la stessa" % _residenti.size())
	print("     persona con e senza lo spostamento, nello stesso istante.")

	# ── G · quanto vale NON riproiettare
	print("")
	print("  ⚠️ 3.0 · LA RIPROIEZIONE — la deriva arriva SPENTA se nessuno la rifà")
	var senza: Array = []
	var con: Array = []
	for r in _residenti:
		var lab := str((r as Dictionary)["label"])
		var b = _animo_di[lab]
		var g0 = _gemello(b, _dna_di[lab], "codardia", 0.35, false)
		var g1 = _gemello(b, _dna_di[lab], "codardia", 0.35, true)
		senza.append(float(g0.limbico.reattivita) - float(b.limbico.reattivita))
		con.append(float(g1.limbico.reattivita) - float(b.limbico.reattivita))
	print("     +0,35 di codardia → Δreattività  SENZA riproiettare: %+.4f" % _media(senza))
	print("                                       CON  riproiettare: %+.4f" % _media(con))
	print("     (`Limbico.reattivita` è derivata dai tratti in `setup()` e PERSISTITA in")
	print("      `save()`: `load()` la rimette com'era. È il muro contro cui una deriva")
	print("      scritta bene si ferma comunque, senza un errore.)")

	_canale_reattivita()
	_canale_chimica()
	_canale_rig()
	_canale_morsi()
	_canale_mestiere()
	_canale_sonno()
	_canale_soglie()
	_canale_affetti()


func _intestazione_tabella(titolo: String) -> void:
	if titolo != "":
		print("")
		print("  %s" % titolo)
	var s := "     %-9s" % "ampiezza"
	for t in ANIMO.TRATTI:
		s += "%11s" % t.substr(0, 10)
	print(s)


func _riga_tabella(amp: float, valori: Dictionary, forma := "%11.4f") -> void:
	var s := "     %-9.2f" % amp
	for t in ANIMO.TRATTI:
		s += forma % float(valori.get(t, 0.0))
	print(s)


## 1 · LA REATTIVITÀ — il guadagno dell'allarme, cioè il canale che arriva al
## corpo più spesso di ogni altro (un percetto ogni pochi secondi-vicino).
func _canale_reattivita() -> void:
	_intestazione_tabella("3.1 · Δ REATTIVITÀ (il guadagno dell'allarme; media 1.05, campo 0.20–1.80)")
	for amp in AMPIEZZE:
		var v := {}
		for t in ANIMO.TRATTI:
			var d: Array = []
			for r in _residenti:
				var lab := str((r as Dictionary)["label"])
				var b = _animo_di[lab]
				var g = _gemello(b, _dna_di[lab], t, float(amp))
				d.append(float(g.limbico.reattivita) - float(b.limbico.reattivita))
			v[t] = _media(d)
		_riga_tabella(float(amp), v)


## 2 · IL PUNTO DI RIPOSO DELLA CHIMICA — i sette canali che il corpo indossa.
func _canale_chimica() -> void:
	print("")
	print("  3.2 · Δ PUNTO DI RIPOSO DELLA CHIMICA (`neuro_base`, il massimo sui 7 canali)")
	print("        …per la strada VERA (`Animo.setup` → `sincronizza_neuro`)")
	_intestazione_tabella("")
	for amp in AMPIEZZE:
		var v := {}
		for t in ANIMO.TRATTI:
			var d: Array = []
			for r in _residenti:
				var lab := str((r as Dictionary)["label"])
				var b = _animo_di[lab]
				var g = _gemello(b, _dna_di[lab], t, float(amp))
				d.append(_max_scarto(b.limbico.neuro_base, g.limbico.neuro_base))
			v[t] = _media(d)
		_riga_tabella(float(amp), v, "%11.5f")
	print("")
	print("        …e il CONTROFATTUALE: `Limbico.setup(tratti)` DA SOLO, cioè quanto")
	print("        varrebbe la tinta del carattere se qualcuno non la cancellasse subito")
	_intestazione_tabella("")
	for amp in AMPIEZZE:
		var v := {}
		for t in ANIMO.TRATTI:
			var d: Array = []
			for r in _residenti:
				var lab := str((r as Dictionary)["label"])
				var b = _animo_di[lab]
				var l0 = LIMBICO.new()
				l0.setup(b.tratti)
				var tt: Dictionary = (b.tratti as Dictionary).duplicate()
				tt[t] = clampf(float(tt.get(t, 0.5)) + float(amp), 0.0, 1.0)
				var l1 = LIMBICO.new()
				l1.setup(tt)
				d.append(_max_scarto(l0.neuro_base, l1.neuro_base))
			v[t] = _media(d)
		_riga_tabella(float(amp), v, "%11.5f")


func _max_scarto(a: Dictionary, b: Dictionary) -> float:
	var m := 0.0
	for k in a:
		m = maxf(m, absf(float(b.get(k, 0.0)) - float(a[k])))
	return m


## 3 · IL RIG — come cammina. Andatura VERA su un corpo finto, stesso moto.
func _canale_rig() -> void:
	print("")
	print("  3.3 · IL RIG — come cammina (Andatura vera, stesso moto, chimica diversa)")
	print("        A RIPOSO: Δgobba in gradi (il canale più grosso del passo)")
	_intestazione_tabella("")
	for amp in AMPIEZZE:
		var v := {}
		for t in ANIMO.TRATTI:
			var d: Array = []
			for r in _residenti:
				var lab := str((r as Dictionary)["label"])
				var b = _animo_di[lab]
				var g = _gemello(b, _dna_di[lab], t, float(amp))
				var s := _scarto_rig(_canali_rig(b.limbico.neuro), _canali_rig(g.limbico.neuro))
				d.append(rad_to_deg(float(s["gobba"])))
			v[t] = _media(d)
		_riga_tabella(float(amp), v, "%11.4f")
	print("")
	print("        DOPO LO STESSO TORTO (una giornata di lavoro che tradisce il sogno):")
	print("        qui la reattività entra davvero, perché scala l'impulso di cortisolo")
	print("        (`Limbico.rivaluta`: `stimola_neuro(\"cortisolo\", -sentito*0.35*reattivita)`)")
	_intestazione_tabella("")
	for amp in AMPIEZZE:
		var v := {}
		for t in ANIMO.TRATTI:
			var d: Array = []
			for r in _residenti:
				var lab := str((r as Dictionary)["label"])
				var b = _animo_di[lab]
				var g0 = _gemello(b, _dna_di[lab], "", 0.0)
				var g1 = _gemello(b, _dna_di[lab], t, float(amp))
				g0.limbico.rivaluta("taglia_legna", "giocatore", -0.42, "", true)
				g1.limbico.rivaluta("taglia_legna", "giocatore", -0.42, "", true)
				var s := _scarto_rig(_canali_rig(g0.limbico.neuro), _canali_rig(g1.limbico.neuro))
				d.append(rad_to_deg(float(s["gobba"])))
			v[t] = _media(d)
		_riga_tabella(float(amp), v, "%11.4f")
	# la scala: quanto vale un grado su questo rig
	print("")
	print("        LA SCALA DEL RIG (per leggere i numeri qui sopra):")
	# ⚠️ su una chimica NEUTRA: presa da un residente vero, la riga «cortisolo
	# a 1.0» dava lo stesso numero della riga «a riposo», perche' quel corpo
	# ce l'aveva gia' al tetto — una scala che non scala niente.
	var neutra: Dictionary = LIMBICO.NEURO_BASELINE.duplicate()
	var teso: Dictionary = neutra.duplicate()
	teso["cortisolo"] = 1.0
	var spento: Dictionary = neutra.duplicate()
	spento["serotonina"] = 0.0
	var fiero: Dictionary = neutra.duplicate()
	fiero["serotonina"] = 1.0
	print("          gobba con la chimica di riposo . %+.3f°" % rad_to_deg(float((_canali_rig(neutra))["gobba"])))
	print("          gobba col cortisolo a 1.0 ...... %+.3f° (tutto il campo del canale)"
			% rad_to_deg(float((_canali_rig(teso))["gobba"])))
	print("          gobba con la serotonina a 0 .... %+.3f°" % rad_to_deg(float((_canali_rig(spento))["gobba"])))
	print("          gobba con la serotonina a 1.0 .. %+.3f°" % rad_to_deg(float((_canali_rig(fiero))["gobba"])))
	print("          la GOBBA DELLA VECCHIAIA piena . %+.3f° (−0.28 rad, il metro di casa)"
			% rad_to_deg(-0.28))
	print("          il CAPO STORTO, sotto cui il gioco dice «dritto» ... 1.1°")


## 4 · I MORSI DELLA LINGUA.
func _canale_morsi() -> void:
	print("")
	print("  3.4 · Δ MORSI DELLA LINGUA prima di scoppiare (quanti `trattieni()` veri)")
	print("        a riposo, e con addosso lo stress di un torto appena preso")
	_intestazione_tabella("")
	for amp in AMPIEZZE:
		var v := {}
		for t in ANIMO.TRATTI:
			var d: Array = []
			for r in _residenti:
				var lab := str((r as Dictionary)["label"])
				var b = _animo_di[lab]
				var g = _gemello(b, _dna_di[lab], t, float(amp))
				d.append(float(_quanti_morsi(g) - _quanti_morsi(b)))
			v[t] = _media(d)
		_riga_tabella(float(amp), v, "%11.3f")
	_intestazione_tabella("        …e con un torto appena preso (cortisolo sopra il proprio riposo)")
	for amp in AMPIEZZE:
		var v := {}
		for t in ANIMO.TRATTI:
			var d: Array = []
			for r in _residenti:
				var lab := str((r as Dictionary)["label"])
				var b = _animo_di[lab]
				var g0 = _gemello(b, _dna_di[lab], "", 0.0)
				var g1 = _gemello(b, _dna_di[lab], t, float(amp))
				g0.limbico.rivaluta("taglia_legna", "giocatore", -0.42, "", true)
				g1.limbico.rivaluta("taglia_legna", "giocatore", -0.42, "", true)
				d.append(float(_quanti_morsi(g1) - _quanti_morsi(g0)))
			v[t] = _media(d)
		_riga_tabella(float(amp), v, "%11.3f")


## 5 · IL MESTIERE — l'unica cosa che un tratto cambia in una giornata
## normale, e la più leggibile senza guardare in faccia nessuno.
func _canale_mestiere() -> void:
	print("")
	print("  3.5 · IL MESTIERE CHE SCEGLIE DA SÉ — % di giornate in cui sceglie DIVERSO")
	print("        (%d tiri APPAIATI: stesso dado, stessa persona, un tratto spostato)" % TIRI_MESTIERE)
	var compiti: Array = ANIMO.COMPITI.keys()
	_intestazione_tabella("        …con i bisogni di ADESSO (il caso comune)")
	for amp in AMPIEZZE:
		var v := {}
		for t in ANIMO.TRATTI:
			v[t] = 100.0 * _mestiere_cambia(t, float(amp), compiti, false)
		_riga_tabella(float(amp), v, "%10.1f%%")
	_intestazione_tabella("        …dopo una GIORNATACCIA (fatica 0.75, noia 0.70, appartenenza 0.30)")
	for amp in AMPIEZZE:
		var v := {}
		for t in ANIMO.TRATTI:
			v[t] = 100.0 * _mestiere_cambia(t, float(amp), compiti, true)
		_riga_tabella(float(amp), v, "%10.1f%%")


func _mestiere_cambia(tratto: String, amp: float, compiti: Array, stressati: bool) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var diversi := 0
	var tot := 0
	for r in _residenti:
		var lab := str((r as Dictionary)["label"])
		var b = _animo_di[lab]
		var g0 = _gemello(b, _dna_di[lab], "", 0.0)
		var g1 = _gemello(b, _dna_di[lab], tratto, amp)
		if stressati:
			for g in [g0, g1]:
				g.drive["fatica"] = 0.75
				g.drive["noia"] = 0.70
				g.drive["appartenenza"] = 0.30
				g.drive["stima"] = 0.45
				g.sincronizza_neuro()
		var per_persona: int = TIRI_MESTIERE / maxi(1, _residenti.size())
		for _k in maxi(8, per_persona):
			var st := rng.randi()
			g0._rng.state = st
			g1._rng.state = st
			var a := str(g0.decide(compiti, "se_stesso"))
			var c := str(g1.decide(compiti, "se_stesso"))
			tot += 1
			if a != c:
				diversi += 1
	return float(diversi) / maxf(1.0, float(tot))


## 6 · L'ORA DEL RISVEGLIO.
func _canale_sonno() -> void:
	print("")
	print("  3.6 · Δ ORA DEL RISVEGLIO")
	var ecs = _vis.get("_ecs")
	if ecs == null:
		print("        EcsMondo assente: non misurabile in questa corsa.")
		return
	var esempio := _finestra_di(_residenti[0])
	print("        La finestra la decide `chibi::finestra_di_sonno(indole, quirk, ora)`, e")
	print("        il DNA che il cuore in C++ conosce ha DUE campi. Letti dall'entità viva:")
	var r0: Dictionary = _residenti[0]
	if r0.has("ecs"):
		print("          debug_entita → %s" % str(ecs.debug_entita(int(r0["ecs"]))))
	print("          maschera indole = %d · quirk = %d · alba %.4f · tramonto %.4f"
			% [int(esempio.get("mask", 0)), int(esempio.get("quirk", -1)),
			float(esempio.get("alba", -1.0)), float(esempio.get("tramonto", -1.0))])
	_intestazione_tabella("        Δ in ore di gioco, per ampiezza:")
	for amp in AMPIEZZE:
		var v := {}
		for t in ANIMO.TRATTI:
			v[t] = 0.0
		_riga_tabella(float(amp), v, "%11.4f")
	print("        ⇒ ZERO PER COSTRUZIONE, e non per taratura: nessun tratto è fra gli")
	print("          argomenti. La stessa cosa vale per l'AGENDA (vedi PARTE 5).")


## 7 · LE SOGLIE DELLA SCALA — le PORTE. Si misurano perché il progetto
## dovrà decidere se la deriva ha il permesso di attraversarle.
func _canale_soglie() -> void:
	print("")
	print("  3.7 · Δ SOGLIA DELLA DISERZIONE (la porta della PARTENZA definitiva)")
	print("        campo naturale fra i residenti: vedi PARTE 1c")
	_intestazione_tabella("")
	for amp in AMPIEZZE:
		var v := {}
		for t in ANIMO.TRATTI:
			var d: Array = []
			for r in _residenti:
				var lab := str((r as Dictionary)["label"])
				var b = _animo_di[lab]
				var g = _gemello(b, _dna_di[lab], t, float(amp))
				d.append(float((g.soglie())["diserzione"]) - float((b.soglie())["diserzione"]))
			v[t] = _media(d)
		_riga_tabella(float(amp), v, "%11.4f")


## 8 · GLI AFFETTI — l'unico posto in cui un tratto decide CON CHI si vive.
func _canale_affetti() -> void:
	print("")
	print("  3.8 · Δ MEZZA VITA DEL LIBRO MASTRO (lealtà: %.0f→%.0f giornate) e Δ CONTO"
			% [AFFETTI.RECENZA_BASE, AFFETTI.RECENZA_LEALE])
	print("        Il conto è calcolato su un libro mastro finto ma REALISTICO: trenta")
	print("        veglie, una al giorno, lette al giorno 30 con `Affetti.conto`.")
	var righe: Array = []
	for d in 30:
		righe.append({"a": "A", "b": "B", "t": "veglia", "d": d})
	_intestazione_tabella("        Δ mezza vita (giornate):")
	for amp in AMPIEZZE:
		var v := {}
		for t in ANIMO.TRATTI:
			var d: Array = []
			for r in _residenti:
				var lab := str((r as Dictionary)["label"])
				var b = _animo_di[lab]
				var l0 := float(b.tratti.get("lealta", 0.5))
				var l1 := clampf(l0 + (float(amp) if t == "lealta" else 0.0), 0.0, 1.0)
				d.append(lerpf(AFFETTI.RECENZA_BASE, AFFETTI.RECENZA_LEALE, l1)
						- lerpf(AFFETTI.RECENZA_BASE, AFFETTI.RECENZA_LEALE, l0))
			v[t] = _media(d)
		_riga_tabella(float(amp), v, "%11.3f")
	_intestazione_tabella("        Δ conto (soglia della coppia: %.2f):" % AFFETTI.SOGLIA_COPPIA)
	for amp in AMPIEZZE:
		var v := {}
		for t in ANIMO.TRATTI:
			var d: Array = []
			for r in _residenti:
				var lab := str((r as Dictionary)["label"])
				var b = _animo_di[lab]
				var l0 := float(b.tratti.get("lealta", 0.5))
				var l1 := clampf(l0 + (float(amp) if t == "lealta" else 0.0), 0.0, 1.0)
				# `conto` prende la LEALTA', non la mezza vita: la converte lei
				# (`lerpf(RECENZA_BASE, RECENZA_LEALE, lealta)`). Dargliela gia'
				# convertita sarebbe una seconda formula da tenere allineata.
				d.append(AFFETTI.conto(righe, "A", "B", 30, l1)
						- AFFETTI.conto(righe, "A", "B", 30, l0))
			v[t] = _media(d)
		_riga_tabella(float(amp), v, "%11.4f")


# ════════════════════════════════════════════════════ la corsa viva

## La mappa indice→nome delle otto azioni. La lista dei nomi è quella di
## GDScript (`VillagerBrain.AZIONI`, la fonte unica) e l'indice lo dice il
## ponte: nessuna tabella ricopiata, e se l'ordine divergesse si vedrebbe.
func _mappa_azioni() -> void:
	var ecs = _vis.get("_ecs")
	if ecs == null:
		return
	for nome in BRAIN.AZIONI:
		var i: int = int(ecs.indice_azione(str(nome)))
		if i >= 0:
			_nome_azione[i] = str(nome)


## ⚠️ **UN VILLAGGIO APPENA NATO NON HA NESSUNA STORIA ADDOSSO**, e su un
## villaggio senza storia la strada veloce non ha niente da leggere: nessun
## marchio, nessuna paura, nessuno che ti voglia bene. È la stessa
## preparazione di `tools/misura_sussulti.gd`, dalle porte VERE, e va
## dichiarata perché senza di lei questo banco misurerebbe il proprio prato
## vuoto — non «il carattere non conta».
##   · un terzo ha imparato a temere qualcosa;
##   · un terzo ha già speso metà della sua forza di trattenersi ed è salito
##     di un gradino (è l'unico modo perché il morso della lingua ACCADA:
##     `Visitors` lo chiede solo da «svogliato» in su);
##   · un terzo ti vuole bene.
## Il marchio POSITIVO sul giocatore non si scrive a mano: se lo costruisce
## il Limbico durante la corsa, incontro dopo incontro, ed è proprio la sua
## carica la cosa da misurare.
func _prepara_popolazione() -> void:
	var k := 0
	for r in _residenti:
		var lab := str((r as Dictionary)["label"])
		var animo = _animo_di[lab]
		if k % 3 == 0:
			for _i in 4:
				animo.limbico.rivaluta("spavento", "", -0.9, "cucina", true)
		elif k % 3 == 1:
			for _i in 2:
				animo.limbico.trattieni()
			(r as Dictionary)["gradino"] = maxi(int((r as Dictionary).get("gradino", 0)), 2)
			animo.gradino = maxi(int(animo.gradino), 2)
		else:
			(r as Dictionary)["friend"] = maxi(int((r as Dictionary).get("friend", 0)), 3)
		k += 1


func _baseline() -> void:
	_giorno0 = int(_dn.get("day"))
	var aff := get_first_node_in_group("affetti")
	var cri := get_first_node_in_group("cricche")
	_base_affetti = (aff.get("_righe") as Array).size() if aff != null else 0
	_base_cricche = (cri.get("_incontri") as Array).size() if cri != null else 0
	var leg := get_first_node_in_group("legami")
	for r in _residenti:
		var lab := str((r as Dictionary)["label"])
		_base_ricordi[lab] = ((_animo_di[lab] as RefCounted).ricordi as Array).size()
		_base_friend[lab] = int((r as Dictionary).get("friend", 0))
		_base_momenti[lab] = 0
		if leg != null and leg.has_method("momenti_vissuti"):
			_base_momenti[lab] = int(leg.call("momenti_vissuti", lab))
		_spinte[lab] = {}
		_dorme[lab] = false


func _prepara_gemelli() -> void:
	for r in _residenti:
		var lab := str((r as Dictionary)["label"])
		var tratti: Dictionary = (_animo_di[lab] as RefCounted).tratti
		var d := {}
		for t in ANIMO.TRATTI:
			for amp in AMPIEZZE:
				for sg in [1.0, -1.0]:
					var k := "%s|%+.2f" % [t, float(amp) * sg]
					d[k] = _gemello_limbico(tratti, t, float(amp) * sg)
					if not _esiti.has(k):
						_esiti[k] = {}
						_discordi[k] = 0
						_forze[k] = []
		_gemelli[lab] = d


func _corsa(secondi: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	_meta = Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10))
	var t := 0.0
	var ms := Time.get_ticks_msec()
	var avviso := 0.0
	var prec := {}
	while t < secondi:
		await process_frame
		var ora := Time.get_ticks_msec()
		var dt := float(ora - ms) / 1000.0
		ms = ora
		if dt <= 0.0 or dt > 0.5:
			continue
		t += dt
		if t - avviso > 60.0:
			avviso = t
			print("    … %.0f s · giorno %d · percetti %d" % [t, int(_dn.get("day")), _percetti])
		_muovi_mochi(rng, dt)
		_lavora(dt)
		_censimento(prec, dt)


func _muovi_mochi(rng: RandomNumberGenerator, dt: float) -> void:
	var p := _player.global_position
	if _sosta > 0.0:
		_sosta -= dt
	elif Vector2(p.x - _meta.x, p.z - _meta.z).length() < 1.0:
		# ⚠️ chi arriva e riparte non lascia il tempo a niente di succedere:
		# un giocatore si FERMA quando arriva da qualcuno.
		_sosta = 3.0
		# ⚠️ una visita su tre non basta: la strada veloce chiede Mochi entro
		# 3,2 m E un raffreddamento di 9 s, quindi il numero di percetti in una
		# giornata E' quante volte il giocatore si avvicina a qualcuno.
		if rng.randf() < 0.60 and not _residenti.is_empty():
			var q: Dictionary = _residenti[rng.randi() % _residenti.size()]
			var qn := q.get("node") as Node3D
			_meta = qn.global_position if (qn != null and is_instance_valid(qn)) \
					else Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
		else:
			_meta = Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
	var verso := _meta - p
	verso.y = 0.0
	if _sosta <= 0.0 and verso.length() > 0.01:
		# ⚠️ alla velocità VERA del giocatore vero: sotto 1,6 m/s la strada
		# veloce non legge niente di brusco, e nessuno sussulta MAI.
		var lontano: bool = verso.length() > 8.0
		var vel: float = float(_player.get("run_speed") if lontano else _player.get("walk_speed"))
		if vel <= 0.0:
			vel = 6.0 if lontano else 3.0
		_player.global_position = p + verso.normalized() * vel * dt


func _lavora(dt: float) -> void:
	_lavoro -= dt
	if _lavoro > 0.0 or _perc == null:
		return
	_lavoro = 5.5
	for _k in 2 + (_verbo % 3):
		_perc.call("accaduto", VERBI[_verbo % VERBI.size()], _player.global_position)
	_verbo += 1
	if _verbo % 3 == 0:
		var vicino := ""
		var dmin := 9.0
		for r in _residenti:
			var n := (r as Dictionary).get("node") as Node3D
			if n == null or not is_instance_valid(n):
				continue
			var dd: float = _player.global_position.distance_to(n.global_position)
			if dd < dmin:
				dmin = dd
				vicino = str((r as Dictionary).get("label", ""))
		if vicino != "":
			_perc.call("accaduto", "dona", _player.global_position, vicino)


func _censimento(prec: Dictionary, dt: float) -> void:
	var cd: Dictionary = _vis.get("_sussulto_cd")
	var ecs = _vis.get("_ecs")
	var giorno := int(_dn.get("day"))
	var ora := float(_dn.get("time"))
	var cri := get_first_node_in_group("cricche")
	for r in _residenti:
		var lab := str((r as Dictionary)["label"])
		var n := (r as Dictionary).get("node") as Node3D
		if n == null or not is_instance_valid(n):
			continue
		var lim = (_animo_di[lab] as RefCounted).limbico
		var d: float = _player.global_position.distance_to(n.global_position)
		if d <= VISITORS.GESTO_RAGGIO:
			_sec_vicino += dt

		# ── A · il sonno si legge dal CORPO
		var nascosto: bool = bool(n.call("is_hidden"))
		if nascosto != bool(_dorme.get(lab, false)):
			_dorme[lab] = nascosto
			_sonno_eventi.append({"label": lab, "che": "dorme" if nascosto else "sveglio",
					"ora": ora, "giorno": giorno})

		# ── A · un percetto nuovo: il raffreddamento è saltato all'insù
		var stato: Dictionary = prec.get(lab, {"cd": 0.0, "morso": 0.0, "ar": 0.0})
		# ⚠️ **L'AROUSAL DEL PERCETTO È QUELLO DI PRIMA, e va CAMPIONATO.**
		# `await process_frame` riprende all'inizio del fotogramma, PRIMA dei
		# `_process` dei nodi: quello che si legge qui è lo stato di fine
		# fotogramma precedente. Quindi il valore buono per il gemello è
		# quello letto al giro scorso — non `lim.arousal` di adesso, che il
		# percetto ha già alzato con la sua scia.
		#   La prima stesura lo RICOSTRUIVA (`arousal − forza·SCIA_ALLARME`) e
		# sbagliava in modo sistematico: i tre tratti che non entrano affatto
		# nel canale (orgoglio, lealtà, ambizione) mostravano un Δforza di
		# +0.0369 IDENTICO per tutti — cioè un pareggio rotto, non un effetto.
		# Il controllo è in fondo alla PARTE 3b, e dev'essere zero.
		var ar_prec: float = float(stato.get("ar", 0.0))
		var ora_cd: float = float(cd.get(lab, 0.0))
		if ora_cd > float(stato["cd"]) + 0.0001:
			_percetti += 1
			var s: Dictionary = lim.ultimo_sussulto
			var vera := str(s.get("reazione", "nulla"))
			_esiti_veri[vera] = int(_esiti_veri.get(vera, 0)) + 1
			var grezzo := float(s.get("grezzo", 0.0))
			_stimoli.append({"lab": lab, "grezzo": grezzo, "arousal": ar_prec,
					"marchi": (lim.marchi as Dictionary).duplicate(true),
					"vera": vera})
			# ── F · il pareggio è ALL'ISTANTE: stesso corpo, altra persona
			var miei: Dictionary = _gemelli.get(lab, {})
			for k in miei:
				var g = miei[k]
				g.marchi = (lim.marchi as Dictionary).duplicate(true)
				g.arousal = ar_prec
				var sg: Dictionary = g.percepisci("giocatore", "", grezzo)
				var rg := str(sg.get("reazione", "nulla"))
				var e: Dictionary = _esiti[k]
				e[rg] = int(e.get(rg, 0)) + 1
				if rg != vera:
					_discordi[k] = int(_discordi[k]) + 1
				if vera == "trasalisce":
					(_forze[k] as Array).append([float(s.get("forza", 0.0)),
							float(sg.get("forza", 0.0))])
		stato["cd"] = ora_cd

		# ── A · e il MORSO della lingua, con lo stesso oracolo: `Visitors`
		#    rimette `morso_<label>` a 12,0 nell'istante in cui chiede
		#    `trattieni()`. Se dopo quella richiesta la regolazione è scesa,
		#    si è trattenuto; se è a zero, è scoppiato.
		var ora_m: float = float(cd.get("morso_" + lab, 0.0))
		if ora_m > float(stato.get("morso", 0.0)) + 0.0001:
			_occasioni_morso += 1
			if float(lim.regolazione) <= 0.001:
				_scoppi += 1
			else:
				_morsi += 1
		stato["morso"] = ora_m
		stato["ar"] = float(lim.arousal)
		prec[lab] = stato

		# ── l'azione dell'agenda (il censimento delle scelte sociali)
		if ecs != null and (r as Dictionary).has("ecs"):
			var iaz: int = int(ecs.azione(int((r as Dictionary)["ecs"])))
			var az: String = str(_nome_azione.get(iaz, "(nessuna azione)" if iaz < 0 else "azione#%d" % iaz))
			_azioni[az] = int(_azioni.get(az, 0)) + 1

	# ── gli incontri, per giornata e per persona (oracolo: il registro vero)
	if cri != null:
		var righe: Array = cri.get("_incontri")
		for i in range(_base_cricche, righe.size()):
			var x: Dictionary = righe[i]
			for chi in [str(x.get("a", "")), str(x.get("b", ""))]:
				var k := "%s|%d" % [chi, int(x.get("d", giorno))]
				_incontri_per_giorno[k] = int(_incontri_per_giorno.get(k, 0)) + 1


# ═══════════════════ PARTE 3b · I SUSSULTI VIVI, appaiati

func _parte3b_sussulti_vivi(giorni: float) -> void:
	print("")
	print("─".repeat(78))
	print("  PARTE 3b · I SUSSULTI, IN VIVO E APPAIATI — il canale che si vede di più")
	print("     %d percetti in %.1f giornate su %d residenti (%.0f secondi-vicino)"
			% [_percetti, giorni, _residenti.size(), _sec_vicino])
	print("     il villaggio com'è: %s" % str(_esiti_veri))
	if _percetti == 0:
		print("     ⚠️ ZERO PERCETTI: la strada veloce chiede Mochi entro 3,2 m da qualcuno.")
		print("        Con residenti che dormono o un giocatore che non si avvicina, il")
		print("        canale non si accende — e il conto non è del carattere.")
		return
	var veri_tras: int = int(_esiti_veri.get("trasalisce", 0))
	var veri_luce: int = int(_esiti_veri.get("si_illumina", 0))
	print("")
	print("     %-10s %9s %9s %9s %9s %9s"
			% ["tratto", "ampiezza", "trasal.", "Δtrasal.", "illumina", "esiti≠"])
	for t in ANIMO.TRATTI:
		for amp in AMPIEZZE:
			for sg in [1.0, -1.0]:
				var k := "%s|%+.2f" % [t, float(amp) * sg]
				if not _esiti.has(k):
					continue
				var e: Dictionary = _esiti[k]
				var tr := int(e.get("trasalisce", 0))
				var il := int(e.get("si_illumina", 0))
				print("     %-10s %+9.2f %9d %+9d %9d %9d"
						% [t, float(amp) * sg, tr, tr - veri_tras, il, int(_discordi[k])])
	print("     ⚠️ Conteggi APPAIATI ALL'ISTANTE (regola F): i gemelli non accumulano la")
	print("        loro arousal, quindi questi numeri sono un PAVIMENTO.")
	_quanto_cambia_la_posa()
	_quanta_deriva_serve()


## ⚠️ **L'ESITO E' BINARIO, LA POSA NO — e la posa e' quello che si vede.**
## Un sussulto che c'era e resta c'e' sembra «nessun cambiamento»; ma la
## `forza` che esce da `percepisci` non e' un booleano: e' l'ampiezza della
## coda somatica (orecchie giu', braccia chiuse, corpo rimpicciolito) e il
## rallentando del passo — l'unica cosa del vocabolario del corpo che arriva
## ai vicini lontani. Qui si misura QUELLA, con le funzioni vere di `Gesti`.
func _quanto_cambia_la_posa() -> void:
	var campioni := 0
	for k in _forze:
		campioni = maxi(campioni, (_forze[k] as Array).size())
	if campioni == 0:
		return
	print("")
	print("     ⇒ E LA POSA, che non e' binaria: %d trasalimenti veri" % campioni)
	print("       Δforza · Δampiezza della coda al colmo · Δrallentando · Δdurata visibile")
	print("")
	print("     %-11s %9s %9s %10s %11s %10s"
			% ["tratto", "ampiezza", "Δforza", "Δcoda", "Δrallent.", "Δdurata"])
	for t in ANIMO.TRATTI:
		for amp in AMPIEZZE:
			for sg in [1.0, -1.0]:
				var k := "%s|%+.2f" % [t, float(amp) * sg]
				var righe: Array = _forze.get(k, [])
				if righe.is_empty():
					continue
				var df: Array = []
				var dc: Array = []
				var dr: Array = []
				var dd: Array = []
				for x in righe:
					var f0: float = float((x as Array)[0])
					var f1: float = float((x as Array)[1])
					df.append(f1 - f0)
					dc.append(GESTI.coda_ampiezza(f1, 0.0) - GESTI.coda_ampiezza(f0, 0.0))
					dr.append(GESTI.soma_ritmo(f1, 0.0) - GESTI.soma_ritmo(f0, 0.0))
					dd.append(_durata_coda(f1) - _durata_coda(f0))
				if is_zero_approx(_media(df)):
					continue
				print("     %-11s %+9.2f %+9.4f %+10.4f %+10.1f%% %+9.2fs"
						% [t, float(amp) * sg, _media(df), _media(dc),
						100.0 * _media(dr), _media(dd)])
	# ⚠️ IL CONTROLLO DEL PAREGGIO. `orgoglio`, `lealta` e `ambizione` non
	# entrano in `reattivita`: sui loro gemelli la forza dev'essere IDENTICA
	# a quella vera. Se questo numero non è zero, il pareggio è rotto e tutta
	# la tabella qui sopra non vuol dire niente — è già successo una volta.
	var controllo := 0.0
	for t in ["orgoglio", "lealta", "ambizione"]:
		for amp in AMPIEZZE:
			for sg in [1.0, -1.0]:
				for x in (_forze.get("%s|%+.2f" % [t, float(amp) * sg], []) as Array):
					controllo = maxf(controllo, absf(float((x as Array)[1]) - float((x as Array)[0])))
	print("       CONTROLLO DEL PAREGGIO (i tre tratti che non entrano nel canale):")
	print("         scarto massimo di forza ....... %.10f  %s"
			% [controllo, "OK" if controllo < 1e-9 else "⚠️ PAREGGIO ROTTO"])
	print("       (per confronto: la coda si spegne sotto %.3f, e il rallentando ha il"
			% GESTI.CODA_SOGLIA)
	print("        pavimento a %.0f%% della velocita\'.)" % (100.0 * GESTI.SOMA_PAVIMENTO))


## Per quanti secondi la coda somatica resta VISIBILE, con quella forza.
## Si scandaglia la funzione vera invece di invertirla a mano.
func _durata_coda(forza: float) -> float:
	var t := 0.0
	while t < 60.0:
		if GESTI.coda_ampiezza(forza, t) <= 0.0:
			return t
		t += 0.05
	return 60.0


## ⚠️ **LA DOMANDA VERA, e non dipende da quanti percetti sono capitati.**
## Contare gli esiti per ampiezza chiede al caso di mettere uno stimolo
## esattamente a cavallo della soglia; con qualche decina di percetti non
## capita quasi mai, e il referto direbbe «zero» di un canale che invece
## risponde. Qui si rovescia la domanda: per OGNI percetto vero si cerca la
## deriva PIÙ PICCOLA che ne ribalta l'esito, spostando il tratto un
## centesimo per volta e richiedendo la risposta al `Limbico` VERO.
## Il risultato è una distribuzione, e da lì si legge quanta deriva serve
## perché il giocatore veda qualcosa.
func _quanta_deriva_serve() -> void:
	if _stimoli.is_empty():
		return
	print("")
	print("     ⇒ QUANTA DERIVA SERVE PER RIBALTARE UN PERCETTO (per ognuno dei %d)"
			% _stimoli.size())
	print("       si cerca il |Δ| più piccolo che cambia l'esito, un centesimo per volta")
	print("")
	print("     %-11s %8s %8s %8s %8s %8s %8s"
			% ["tratto", "≤0.05", "≤0.10", "≤0.20", "≤0.35", "≤1.00", "mai"])
	for t in ANIMO.TRATTI:
		var conteggi := [0, 0, 0, 0, 0, 0]
		var minimi: Array = []
		for st in _stimoli:
			var d := _delta_che_ribalta(st, str(t))
			if d < 0.0:
				conteggi[5] += 1
				continue
			minimi.append(d)
			if d <= 0.05:
				conteggi[0] += 1
			if d <= 0.10:
				conteggi[1] += 1
			if d <= 0.20:
				conteggi[2] += 1
			if d <= 0.35:
				conteggi[3] += 1
			if d <= 1.00:
				conteggi[4] += 1
		print("     %-11s %8d %8d %8d %8d %8d %8d"
				% [t, conteggi[0], conteggi[1], conteggi[2], conteggi[3],
				conteggi[4], conteggi[5]])
	print("")
	print("       («mai» = nemmeno spostando il tratto di 1,00, cioè da un capo all'altro")
	print("        del campo: quel percetto era troppo lontano dalla soglia, o quel tratto")
	print("        non entra affatto in quel canale.)")


## Il |Δ| più piccolo, su quel tratto, che cambia la reazione a QUESTO
## stimolo. −1 se non la cambia nessun Δ fino a 1,00. Si prova prima in su e
## poi in giù, e vince il più piccolo dei due.
func _delta_che_ribalta(st: Dictionary, tratto: String) -> float:
	var lab := str(st["lab"])
	var base: Dictionary = (_animo_di[lab] as RefCounted).tratti
	var vera := str(st["vera"])
	for i in range(1, 101):
		var d := float(i) / 100.0
		for verso in [1.0, -1.0]:
			var tt: Dictionary = base.duplicate()
			var v := clampf(float(tt.get(tratto, 0.5)) + d * verso, 0.0, 1.0)
			if is_equal_approx(v, float(tt.get(tratto, 0.5))):
				continue        # il tratto è già al bordo da quella parte
			tt[tratto] = v
			var l = LIMBICO.new()
			l.setup(tt)
			l.marchi = (st["marchi"] as Dictionary).duplicate(true)
			l.arousal = float(st["arousal"])
			var r: Dictionary = l.percepisci("giocatore", "", float(st["grezzo"]))
			if str(r.get("reazione", "")) != vera:
				return d
	return -1.0


# ════════════════════════ PARTE 4 · LE SPINTE (domanda 2)

func _parte4_le_spinte(giorni: float) -> void:
	print("")
	print("─".repeat(78))
	print("  PARTE 4 · QUANTO SPINGEREBBE LA VITA VERA")
	print("     Tutti i conti sono DELTA sulla baseline presa dopo il caricamento")
	print("     (regola D: il MainLevel apre il villaggio dell'autore).")
	print("")
	var n := float(_residenti.size())
	var g := maxf(0.001, giorni)

	# 1 · i ricordi dell'Animo, per tipo — E LA COLONNA CHE DECIDE TUTTO:
	#     quella spinta DISTINGUE le persone, o le tratta tutte uguali?
	#     Una spinta che dà a tutti lo stesso numero può spostare il villaggio
	#     intero (è una taratura), mai fare una persona diversa da un'altra.
	var per_tipo := {}
	var per_persona := {}
	for r in _residenti:
		var lab := str((r as Dictionary)["label"])
		var ric: Array = (_animo_di[lab] as RefCounted).ricordi
		for i in range(int(_base_ricordi.get(lab, 0)), ric.size()):
			var x: Dictionary = ric[i]
			var chiave := "%s|%s" % [str(x.get("tipo", "?")), str(x.get("attore", ""))]
			per_tipo[chiave] = int(per_tipo.get(chiave, 0)) + 1
			if not per_persona.has(chiave):
				per_persona[chiave] = {}
			var d: Dictionary = per_persona[chiave]
			d[lab] = int(d.get(lab, 0)) + 1
	print("  1 · I RICORDI NUOVI (tipo|attore) — è il canale che fa fuoco tutti i giorni")
	print("     %-30s %5s %9s %5s %5s %8s"
			% ["tipo|attore", "tot", "/res/gg", "min", "max", "distingue?"])
	if per_tipo.is_empty():
		print("     nessuno. (In %.1f giornate il registro dei lavori assegna una" % giorni)
		print("     giornata a testa SOLO al cambio di giorno: con meno di una giornata")
		print("     piena non scatta.)")
	for k in per_tipo:
		var d: Dictionary = per_persona[k]
		var v: Array = []
		for r in _residenti:
			v.append(float(int(d.get(str((r as Dictionary)["label"]), 0))))
		var uguali: bool = is_equal_approx(_min(v), _max(v))
		print("     %-30s %5d %9.3f %5.0f %5.0f %8s"
				% [k, int(per_tipo[k]), float(per_tipo[k]) / n / g, _min(v), _max(v),
				"NO" if uguali else "sì"])

	# 2 · gli affetti
	var aff := get_first_node_in_group("affetti")
	print("")
	print("  2 · IL LIBRO MASTRO DEGLI AFFETTI (righe nuove, per tipo)")
	if aff != null:
		var righe: Array = aff.get("_righe")
		var tipi := {}
		for i in range(_base_affetti, righe.size()):
			var x: Dictionary = righe[i]
			tipi[str(x.get("t", "?"))] = int(tipi.get(str(x.get("t", "?")), 0)) + 1
		if tipi.is_empty():
			print("     nessuna riga nuova.")
		for k in tipi:
			var peso: float = float(AFFETTI.GESTI.get(k, 0.0))
			print("     %-16s %5d  (peso %.2f%s) · %.3f per residente per giornata"
					% [k, int(tipi[k]), peso,
					", PESANTE" if peso >= AFFETTI.PESO_VERO else "",
					float(tipi[k]) / n / g])

	# 3 · le cricche / la co-presenza
	var cri := get_first_node_in_group("cricche")
	print("")
	print("  3 · LA CO-PRESENZA (`Cricche._incontri`) — e la SOLITUDINE, che ne è il rovescio")
	if cri != null:
		var inc: Array = cri.get("_incontri")
		var nuove: int = inc.size() - _base_cricche
		print("     righe nuove ....................... %d (%.3f per residente per giornata)"
				% [nuove, float(nuove) / n / g])
		var soli := 0
		var tot_gg := 0
		for r in _residenti:
			var lab := str((r as Dictionary)["label"])
			for gg in range(_giorno0, int(_dn.get("day")) + 1):
				tot_gg += 1
				if not _incontri_per_giorno.has("%s|%d" % [str(_nome_di.get(lab, lab)), gg]):
					soli += 1
		print("     giornate-persona senza NESSUN incontro: %d su %d (%.0f%%)"
				% [soli, tot_gg, 100.0 * float(soli) / maxf(1.0, float(tot_gg))])
		print("     ⚠️ la memoria di quel registro dura %d giornate (%.1f stagioni):"
				% [CRICCHE.MEMORIA, float(CRICCHE.MEMORIA) / float(DAYNIGHT.SEASON_DAYS)])
		print("        una spinta che ci si appoggia non può guardare più indietro di così.")

	# 4 · il filo rosso e l'amicizia
	var leg := get_first_node_in_group("legami")
	print("")
	print("  4 · I MOMENTI DEL FILO ROSSO e il contatore `friend`")
	var mom_tot := 0
	var fr_tot := 0
	for r in _residenti:
		var lab := str((r as Dictionary)["label"])
		if leg != null and leg.has_method("momenti_vissuti"):
			mom_tot += int(leg.call("momenti_vissuti", lab)) - int(_base_momenti.get(lab, 0))
		fr_tot += int((r as Dictionary).get("friend", 0)) - int(_base_friend.get(lab, 0))
	print("     momenti nuovi ..................... %d (%.3f per residente per giornata)"
			% [mom_tot, float(mom_tot) / n / g])
	print("     punti di amicizia nuovi ........... %d (%.3f per residente per giornata)"
			% [fr_tot, float(fr_tot) / n / g])

	# 5 · la strada veloce
	print("")
	print("  5 · I PERCETTI DELLA STRADA VELOCE")
	print("     %d percetti (%.3f per residente per giornata) · %s"
			% [_percetti, float(_percetti) / n / g, str(_esiti_veri)])

	print("     occasioni di TRATTENERSI ......... %d · morsi riusciti %d · scoppi %d (%.3f/res/giornata)"
			% [_occasioni_morso, _morsi, _scoppi, float(_morsi) / n / g])
	if _occasioni_morso == 0:
		print("     ⚠️ ZERO: `Visitors` chiede `trattieni()` solo a chi è già almeno")
		print("        «svogliato» sulla scala e ha Mochi entro 2,6 m. In un villaggio")
		print("        senza rancore quel canale non si accende MAI.")

	# 6 · il sonno, e la notte
	print("")
	print("  6 · LE NOTTI — quante ne sono passate, e cosa ci è successo")
	var dormite := 0
	for e in _sonno_eventi:
		if str((e as Dictionary)["che"]) == "dorme":
			dormite += 1
	print("     giornate di gioco attraversate .... %d → %d" % [_giorno0, int(_dn.get("day"))])
	print("     addormentamenti osservati (corpo) . %d su %d residenti" % [dormite, _residenti.size()])
	if not _sonno_eventi.is_empty():
		var ore: Array = []
		for e in _sonno_eventi:
			if str((e as Dictionary)["che"]) == "dorme":
				ore.append(float((e as Dictionary)["ora"]))
		if not ore.is_empty():
			print("     l'ora in cui si va a letto ........ %.3f → %.3f (%.1f → %.1f in ore)"
					% [_min(ore), _max(ore), _min(ore) * 24.0, _max(ore) * 24.0])

	# 7 · le azioni scelte dall'agenda
	print("")
	print("  7 · COSA FANNO, secondo l'agenda del C++ (fotogrammi-residente per azione)")
	var tot_f := 0
	for k in _azioni:
		tot_f += int(_azioni[k])
	var chiavi: Array = _azioni.keys()
	chiavi.sort_custom(func(x, y): return int(_azioni[x]) > int(_azioni[y]))
	for k in chiavi:
		print("     %-24s %7d  (%.1f%%)" % [k, int(_azioni[k]),
				100.0 * float(_azioni[k]) / maxf(1.0, float(tot_f))])


# ══════════════ PARTE 5 · L'AGENDA E I TRATTI (il canale a zero)

func _parte5_agenda() -> void:
	print("")
	print("-".repeat(78))
	print("  PARTE 5 - L'AGENDA IN C++ VEDE I TRATTI? (la prova a scatola nera)")
	var ecs = _vis.get("_ecs")
	if ecs == null or _residenti.is_empty():
		print("     EcsMondo assente: non misurabile.")
		return
	# I QUATTRO ARGOMENTI CHE L'AGENDA RICEVE, presi dalle stesse funzioni che
	# li producono in partita (`Visitors._ciclo_sonno`): i bisogni del cervello,
	# i fatti del mondo, la maschera dell'indole e l'indice del quirk. Se un
	# tratto entrasse da qualche parte, entrerebbe da qui.
	var r: Dictionary = _residenti[0]
	var lab := str(r["label"])
	var node := r.get("node") as Node3D
	var brain = _vis.call("_ensure_brain", r)
	var a = _animo_di[lab]

	var bis0: PackedFloat64Array = brain.bisogni_packed()
	var fat0: int = int(_vis.call("_fatti_di", r, node))
	var ind0: int = ecs.maschera_indole(PackedStringArray(brain.indole))
	var qui0: int = ecs.indice_quirk(str(brain.quirk))
	var pun0: PackedFloat64Array = ecs.debug_punteggi(bis0, fat0, ind0, qui0)

	# +0,35 su TUTTI e cinque i tratti, riproiettati come li riproietterebbe
	# una deriva vera - e poi si rimettono a posto.
	var salvati: Dictionary = (a.tratti as Dictionary).duplicate()
	for t in ANIMO.TRATTI:
		a.tratti[t] = clampf(float(salvati[t]) + 0.35, 0.0, 1.0)
	_riproietta(a)

	var bis1: PackedFloat64Array = brain.bisogni_packed()
	var fat1: int = int(_vis.call("_fatti_di", r, node))
	var ind1: int = ecs.maschera_indole(PackedStringArray(brain.indole))
	var qui1: int = ecs.indice_quirk(str(brain.quirk))
	var pun1: PackedFloat64Array = ecs.debug_punteggi(bis1, fat1, ind1, qui1)

	a.tratti = salvati
	_riproietta(a)

	var db := 0.0
	for i2 in mini(bis0.size(), bis1.size()):
		db = maxf(db, absf(bis1[i2] - bis0[i2]))
	var dp := 0.0
	var quante := 0
	for i2 in mini(pun0.size(), pun1.size()):
		var d: float = absf(pun1[i2] - pun0[i2])
		dp = maxf(dp, d)
		if d > 0.0:
			quante += 1
	print("     su %s, +0,35 su tutti e cinque i tratti (e poi rimessi):" % lab)
	print("       i BISOGNI che il ponte passa .... scarto massimo %.12f" % db)
	print("       i FATTI del mondo ............... %d -> %d" % [fat0, fat1])
	print("       la maschera INDOLE / il QUIRK ... %d/%d -> %d/%d" % [ind0, qui0, ind1, qui1])
	print("       i PUNTEGGI delle %d azioni ...... %d cambiano, scarto massimo %.12f"
			% [pun0.size(), quante, dp])
	if r.has("ecs"):
		print("       il DNA che il cuore conosce ..... %s" % str(ecs.debug_entita(int(r["ecs"]))))
	print("     ⇒ nessuno dei quattro argomenti si muove: l'agenda (e con lei ogni")
	print("       scelta di azione, comprese quelle SOCIALI) e' cieca ai cinque tratti.")
