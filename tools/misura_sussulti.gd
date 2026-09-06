extends SceneTree
## IL METRO DELLA STRADA VELOCE — chi accende la coda «guardinga», e perché.
##
##   CHIBI_MINUTI=8 CHIBI_QUANTI=28 ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --resolution 1280x720 --script res://tools/misura_sussulti.gd
##
## La suite non dice NIENTE su questo: `Limbico.percepisci` è pura e passa
## verde qualunque cosa faccia il villaggio con la sua risposta. La domanda
## di questo banco è di FREQUENZA e di ATTRIBUZIONE, e nessuna asserzione
## booleana sa rispondere:
##
##   · **quanti percetti per reazione**, e quanti di quelli hanno acceso la
##     coda somatica — cioè quante volte il corpo di un vicino si è messo
##     addosso la faccia della paura;
##   · **con che forza**, e da dove viene (il marchio o la bruschezza);
##   · **il cuoricino senza storia**: quante `si_illumina` capitano a chi non
##     ha nessun marchio positivo addosso — un cuore che il giocatore non può
##     ricondurre a niente, cioè il guasto che INVERTE l'effetto;
##   · **le orecchie nell'istante del cuoricino**: su o giù. È l'unico numero
##     che dice se la gioia si legge come gioia;
##   · e quanti vicini, alla fine, il gioco descrive come «ancora guardinghi»
##     — cioè a quanti il saluto (T) risponderebbe con una nuvoletta di
##     puntini invece che con la faccia contenta (`_spiega_come_sta`).
##
## ⚠️ **L'ORACOLO È INDIPENDENTE.** Non si chiede a `Visitors` se ha acceso la
## coda: si legge il CORPO (`_gs_soma`, `_gs_soma_t` di `Visitor`) e a parte
## il LIMBICO (`ultimo_sussulto`). Chiedere al contatore se è d'accordo con
## sé stesso è l'errore che `tools/misura_cammino.gd` esiste per non
## commettere.
##
## ⚠️ **E IL PERCETTO SI RILEVA DAL RAFFREDDAMENTO.** `Visitors._tick_sussulti`
## rimette `_sussulto_cd[label]` a 9,0 esattamente quando chiama
## `percepisci`: un salto all'insù di quel numero È un percetto nuovo, e non
## costa una riga di produzione. (`ultimo_sussulto` da solo non basta: lo
## riscrivono anche i percetti che tornano «nulla», e non porta un orologio.)
##
## ═══ ⚠️ LE SORGENTI DELLA CODA SONO **DUE**, E VANNO SCONTATE ═══
##
## Questo banco è nato quando `Visitor.somatico` aveva un chiamante solo (il
## ramo `trasalisce` di `_tick_sussulti`): lì «la coda si è armata» e «c'è
## stato uno spavento» erano la stessa frase, e leggere il corpo bastava.
## Dal 2026-09 non è più vero. La **TENSIONE DEL CONFRONTO**
## (`Visitors.TENSIONE_CONFRONTO`, armata in `_tick_confronti` quando Mochi è
## entro 2,6 m di chi ha un torto da gradino «svogliato» in su) è la seconda
## porta di quel livello, ed è LEGITTIMA: è il buio che alla rilettura
## mancava — senza, il Rialzo di chi rilegge si rifiutava sempre (MISURATO:
## 9 riletture, 0 gesti concessi).
##
## E la sua finestra sta **tutta dentro** i 3,2 m del percetto: senza uno
## sconto, ogni arm del confronto azzererebbe `_gs_soma_t` **senza nessun
## percetto dietro**, e questo banco lo attribuirebbe al percetto più vicino
## nel tempo — quasi sempre una `nulla`. La riga «percetti nulla → la coda si
## arma 1 volta su 129», cioè il numero con cui si è dimostrato che la gioia
## non porta più la faccia della paura, tornerebbe a gonfiarsi: si leggerebbe
## una REGRESSIONE di quella cura dove invece c'è una sorgente nuova. E il
## danno vero è il secondo: se un domani qualcuno rompesse davvero il ramo del
## `match`, il banco non saprebbe più distinguere il guasto dal rumore del
## confronto.
##
## **COME SI DISTINGUONO, e sono tre segnali indipendenti fra loro:**
##  1. **la DECISIONE si rileva dal suo raffreddamento**, esattamente come il
##     percetto: `_tick_confronti` rimette `_sussulto_cd["morso_" + label]` a
##     12,0 nell'istante in cui la decisione si prende, cioè la riga sopra
##     l'arm. Un salto all'insù di QUEL numero è una decisione di regolazione
##     su QUEL residente, in QUEL fotogramma — per residente, senza
##     aggregazioni da sbrogliare;
##  2. **il contatore aggregato fa da guardia al cablaggio**, non da oracolo:
##     `debug_regola_contatori()` sale nello stesso fotogramma. Se un giorno
##     la chiave del raffreddamento venisse spostata senza che una decisione
##     si prenda davvero, il referto stampa «decisioni ORFANE» invece di
##     scontare in silenzio arm che nessuno ha armato;
##  3. **e nel fotogramma CONTESO decide la FORZA.** La tensione è
##     deterministica — `lerpf(CODA_SOGLIA·2, TENSIONE_CONFRONTO,
##     ANIMO.frazione(gradino))` — quindi un `_gs_soma` uguale a quel numero
##     è suo; qualunque altro valore è la forza d'allarme del `Limbico`, che
##     nasce da una formula continua. Non si guarda la REAZIONE per decidere
##     (sarebbe dare per buona proprio la cosa che questo banco misura).
##
## ⚠️ **E LA TABELLA CHE QUESTO BANCO HA PUBBLICATO VA RIMISURATA PRIMA DI
## RICOPIARLA.** I numeri che stanno in `CLAUDE.md` («trasalisce 13 → 10»,
## «nulla 129 → 1», «coda visibile 1,1%», «rallentando 5,4%») sono di PRIMA
## che la tensione del confronto esistesse, e sono stati presi con un
## villaggio in cui nessuno aveva un torto da rinfacciare. Vanno rifatti su
## questa corsa, leggendo le due sorgenti separate — e il confronto fra
## vecchio e nuovo si fa sulla colonna del PERCETTO, mai sul totale.

const VISITORS := preload("res://scenes/npc/Visitors.gd")
const LIMBICO := preload("res://scenes/npc/Limbico.gd")
const GESTI := preload("res://scenes/npc/Gesti.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")

var _vis: Node = null
var _build: Node = null
var _player: Node3D = null

# --- i conti ---
var _percetti := {}          # reazione -> quanti
var _coda_accesa := {}       # reazione -> quante volte la coda si è accesa
var _forze := {}             # reazione -> [forze]
var _cuore_senza_storia := 0 # si_illumina con marchio positivo sotto soglia
var _cuore_con_storia := 0
var _orecchie := []          # ear applicato all'istante del cuoricino
var _orecchie_su := 0
var _orecchie_giu := 0
var _sec_vicino := 0.0
var _sec_coda_viva := 0.0    # secondi-vicino con l'ampiezza della coda > 0
var _sec_ritmo_lento := 0.0  # …e col rallentando ancora addosso
var _sec_addosso := 0.0
# --- la SECONDA sorgente della coda: la tensione del confronto ---
var _arm_confronto := 0      # arm scontati: li ha armati `_tick_confronti`
var _decisioni := 0          # decisioni di regolazione viste (morso_<label>)
var _decisioni_orfane := 0   # …senza che il contatore aggregato salga: cablaggio
var _arm_contesi := 0        # percetto E decisione nello STESSO fotogramma
var _regola_tot := 0         # somma di `debug_regola_contatori()` al giro prima
var _sec_coda_conf := 0.0    # dei secondi con la coda viva, quanti sono suoi
var _sec_ritmo_conf := 0.0   # …e altrettanto per il rallentando
var _campioni := 0
var _lavoro := 3.0
var _verbo := 0
var _sosta := 0.0
var _meta := Vector3.ZERO
const VERBI := ["annaffia", "semina", "raccoglie", "costruisce", "pesca"]
## Dopo quanto, da quando comincia il transitorio, si guardano le orecchie.
## Non è un numero a caso: è l'istante in cui il cuoricino è già in volo e
## l'inviluppo di `si_illumina` è al massimo della salita.
const ISTANTE_CUORE := 0.17


func _init() -> void:
	_go()


func _m(c: Vector2i) -> Vector3:
	return Vector3(c.x, 0.0, c.y)


func _go() -> void:
	var minuti := 6.0
	if OS.get_environment("CHIBI_MINUTI") != "":
		minuti = float(OS.get_environment("CHIBI_MINUTI"))
	var quanti := 28
	if OS.get_environment("CHIBI_QUANTI") != "":
		quanti = int(OS.get_environment("CHIBI_QUANTI"))

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 10:
		await process_frame
	var liv := current_scene
	_build = liv.get_node_or_null("BuildSystem")
	_vis = liv.get_node_or_null("Visitors")
	_player = liv.get_node_or_null("Player") as Node3D
	var dn := liv.get_node_or_null("DayNight")
	if _build == null or _vis == null or _player == null:
		print("GUASTO: manca qualcosa nel MainLevel")
		quit(1)
		return
	_build.call("set_persist_for_debug", false)
	# l'orologio si ferma a metà pomeriggio: un giorno dura quattro minuti, e
	# a metà prova i vicini andrebbero a dormire (scala 0.03, e chi dorme non
	# sussulta affatto — si misurerebbe un villaggio vuoto)
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	await create_timer(1.5).timeout

	_vis.call("debug_reset")
	var celle: Array[Vector2i] = []
	var raggio := 7
	for gx in range(-raggio, raggio):
		for gz in range(-raggio, raggio):
			celle.append(Vector2i(gx * 2, gz * 2))
	celle.shuffle()
	var letti := 0
	var i := 0
	while letti < quanti and i < celle.size():
		var c: Vector2i = celle[i]
		i += 1
		_build.call("place_cell", c, "Letto", 0, false)
		_build.call("place_cell", c, "Tetto", 0, false)
		if not bool(_build.call("has_cover", c)):
			continue
		letti += 1
	var extra := 0
	while extra < 12 and i < celle.size():
		var c: Vector2i = celle[i]
		i += 1
		_build.call("place_cell", c, ["Cespuglio", "Panchina", "Aiuola"][extra % 3], 0, false)
		extra += 1
	_build.call("aggiorna_varchi_ora")

	var celle_letto: Array[Vector2i] = []
	for k in range(mini(letti, celle.size())):
		celle_letto.append(celle[k])
	var residenti: Array = []
	for k in celle_letto.size():
		_vis.call("debug_settle", 5000 + k * 37, celle_letto[k])
		residenti = _vis.get("_residents")
	await create_timer(1.5).timeout
	residenti = _vis.get("_residents")
	if residenti.is_empty():
		print("GUASTO: nessun residente")
		quit(1)
		return
	for k in residenti.size():
		_vis.call("debug_stage_resident", k, _m((residenti[k] as Dictionary)["cell"]))
	await create_timer(1.0).timeout
	_prepara(residenti)

	print("")
	print("█".repeat(72))
	print("LA STRADA VELOCE, NEL VILLAGGIO VERO — %d residenti, %.0f minuti"
			% [residenti.size(), minuti])
	print("█".repeat(72))
	await _guarda(minuti * 60.0, residenti)
	_referto(residenti, minuti * 60.0)
	quit(0)


## Le stesse tre preparazioni di `prova_villaggio_gesti`, dalle porte VERE:
## chi ha imparato a temere un posto, chi ha ancora la forza di trattenersi,
## e chi ti vuole bene. Un terzo per parte.
##
## ⚠️ **`friend` NON è il marchio.** Il campo della riga del residente pesa
## sulla strada LENTA (`_tick_riconoscimenti`); il marchio positivo su di te —
## quello che fa `si_illumina` — se lo scrive il Limbico da solo, incontro
## dopo incontro. Scriverlo a mano vorrebbe dire provare un villaggio che non
## esiste, ed è proprio la carica di quel marchio la cosa da misurare.
##
## ⚠️ **E IL SECONDO TERZO È ESATTAMENTE LA POPOLAZIONE CHE ARMA LA
## TENSIONE**: gradino 2 («attrezzi») è sopra «svogliato», cioè la condizione
## di `_tick_confronti`. Non è un effetto collaterale da togliere — è il
## villaggio vero, dove chi ha un torto ce l'ha davvero — ed è la ragione per
## cui lo sconto della seconda sorgente (in cima al file) qui MORDE invece di
## essere una precauzione teorica.
func _prepara(residenti: Array) -> void:
	var animi: Dictionary = _vis.get("_animi")
	var k := 0
	for r in residenti:
		var lab := str((r as Dictionary).get("label", ""))
		if not animi.has(lab):
			continue
		var animo: RefCounted = animi[lab]
		if k % 3 == 0:
			for _i in 4:
				animo.limbico.rivaluta("spavento", "", -0.9, "cucina", true)
		if k % 3 == 1:
			for _i in 2:
				animo.limbico.trattieni()
			r["gradino"] = maxi(int(r.get("gradino", 0)), 2)
			animo.set("gradino", maxi(int(animo.get("gradino")), 2))
		if k % 3 == 2:
			r["friend"] = maxi(int(r.get("friend", 0)), 3)
		k += 1


func _guarda(secondi: float, residenti: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	_meta = Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10))
	var t := 0.0
	var ms := Time.get_ticks_msec()
	var avviso := 0.0
	# lo stato per residente: raffreddamento precedente, transitorio in corso
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
			print("  … %.0f s · percetti %s" % [t, str(_percetti)])
		_muovi_mochi(rng, dt, residenti)
		_lavora(dt, residenti)
		_censimento(residenti, prec, dt)
		_campioni += 1


func _muovi_mochi(rng: RandomNumberGenerator, dt: float, residenti: Array) -> void:
	var p := _player.global_position
	if _sosta > 0.0:
		_sosta -= dt
	elif Vector2(p.x - _meta.x, p.z - _meta.z).length() < 1.0:
		_sosta = 2.5
		# una volta su tre va da qualcuno: il sussulto vuole Mochi entro
		# 3,2 m, e con mete a caso su un prato di trenta metri non capita mai
		if rng.randf() < 0.34 and not residenti.is_empty():
			var q: Dictionary = residenti[rng.randi() % residenti.size()]
			var qn := q.get("node") as Node3D
			_meta = qn.global_position if (qn != null and is_instance_valid(qn)) \
					else Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
		else:
			_meta = Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
	var verso := _meta - p
	verso.y = 0.0
	if _sosta <= 0.0 and verso.length() > 0.01:
		# alla velocità VERA, letta dal giocatore vero: la strada veloce
		# guarda proprio COME arrivi, e sotto 1,6 m/s non c'è niente di brusco
		var lontano: bool = verso.length() > 8.0
		var vel: float = float(_player.get("run_speed") if lontano
				else _player.get("walk_speed"))
		if vel <= 0.0:
			vel = 6.0 if lontano else 3.0
		_player.global_position = p + verso.normalized() * vel * dt


func _lavora(dt: float, residenti: Array) -> void:
	_lavoro -= dt
	if _lavoro > 0.0:
		return
	_lavoro = 5.5
	var perc := current_scene.get_node_or_null("Percezione")
	if perc == null:
		return
	for _k in 2 + (_verbo % 3):
		perc.call("accaduto", VERBI[_verbo % VERBI.size()], _player.global_position)
	_verbo += 1
	if _verbo % 3 == 0:
		var vicino := ""
		var dmin := 9.0
		for r in residenti:
			var n := (r as Dictionary).get("node") as Node3D
			if n == null or not is_instance_valid(n):
				continue
			var dd: float = _player.global_position.distance_to(n.global_position)
			if dd < dmin:
				dmin = dd
				vicino = str((r as Dictionary).get("label", ""))
		if vicino != "":
			perc.call("accaduto", "dona", _player.global_position, vicino)


## LA FORZA CHE `_tick_confronti` PASSEREBBE A `somatico` PER QUESTO CORPO.
##
## ⚠️ È l'unica riga di questo banco che rifà un conto della produzione, e lo
## fa apposta: serve **solo** nel fotogramma conteso (percetto e decisione
## insieme), e l'alternativa — guardare la REAZIONE per decidere di chi sia
## l'arm — vorrebbe dire dare per buona proprio la cosa che questo banco
## misura. Le costanti però NON si ricopiano: si leggono da dove vivono, così
## se qualcuno le tara diverse questo confronto le segue invece di divergere
## in silenzio.
func _tensione_attesa(animo: RefCounted) -> float:
	return lerpf(GESTI.CODA_SOGLIA * 2.0, VISITORS.TENSIONE_CONFRONTO,
			ANIMO.frazione(int(animo.get("gradino"))))


func _censimento(residenti: Array, prec: Dictionary, dt: float) -> void:
	var animi: Dictionary = _vis.get("_animi")
	var cd: Dictionary = _vis.get("_sussulto_cd")
	# ⚠️ LA GUARDIA DEL CABLAGGIO, una volta per fotogramma e non per
	# residente: il contatore aggregato non dice CHI, quindi non serve ad
	# attribuire — serve a sapere che il raffreddamento `morso_<label>`
	# significa ancora «una decisione si è presa». Se un domani quella riga
	# si spostasse, il referto stampa le decisioni ORFANE invece di scontare
	# arm che nessuno ha armato.
	var reg: Dictionary = _vis.call("debug_regola_contatori")
	var tot_reg := 0
	for k in reg:
		tot_reg += int(reg[k])
	var reg_salito: bool = tot_reg > _regola_tot
	_regola_tot = tot_reg
	for r in residenti:
		var lab := str((r as Dictionary).get("label", ""))
		var n := (r as Dictionary).get("node") as Node3D
		if lab == "" or n == null or not is_instance_valid(n) or not animi.has(lab):
			continue
		var animo: RefCounted = animi[lab]
		var lim: RefCounted = animo.limbico
		var stato: Dictionary = prec.get(lab,
				{"cd": 0.0, "trans": "", "t": -1.0, "soma": 0.0, "soma_t": 0.0,
				"morso": 0.0, "fonte": ""})
		var soma: float = float(n.get("_gs_soma"))
		var soma_t: float = float(n.get("_gs_soma_t"))
		var d: float = _player.global_position.distance_to(n.global_position)
		if d <= VISITORS.GESTO_RAGGIO:
			_sec_vicino += dt
			if soma > 0.0:
				if GESTI.coda_ampiezza(soma, soma_t) > 0.0:
					_sec_coda_viva += dt
					# …e di chi è il livello che si sta vedendo. Senza questa
					# riga la percentuale pubblicata sommerebbe due cose
					# diverse, e il confronto con la corsa di prima della
					# tensione direbbe «la coda è tornata ad accendersi».
					if str(stato["fonte"]) == "confronto":
						_sec_coda_conf += dt
				if GESTI.soma_ritmo(soma, soma_t) < 0.995:
					_sec_ritmo_lento += dt
					if str(stato["fonte"]) == "confronto":
						_sec_ritmo_conf += dt
		if d <= 3.2:
			_sec_addosso += dt

		# 1) I DUE OROLOGI DEL FOTOGRAMMA, letti con la STESSA tecnica: un
		# raffreddamento che salta all'insù è la cosa che l'ha rimesso lì.
		#  · `_sussulto_cd[label]`          → un percetto nuovo (9,0)
		#  · `_sussulto_cd["morso_"+label]` → una decisione di regolazione
		#    (12,0), rimessa da `_tick_confronti` sulla riga SOPRA l'arm
		var ora_cd: float = float(cd.get(lab, 0.0))
		var ora_morso: float = float(cd.get("morso_" + lab, 0.0))
		var percetto: bool = ora_cd > float(stato["cd"]) + 0.0001
		var decisione: bool = ora_morso > float(stato["morso"]) + 0.0001
		# ⚠️ LA CODA È STATA **ARMATA** IN QUESTO FOTOGRAMMA? Si guarda il
		# CORPO, non chi l'ha chiamata — e si guarda l'OROLOGIO, non il
		# livello: `_gs_soma_t` cresce di un fotogramma per volta e torna a
		# zero SOLO quando qualcuno riarma. Un livello «acceso» non basta
		# (potrebbe essere di uno spavento di tre secondi fa), e «acceso da
		# poco» sbaglia in silenzio ogni volta che la coda di prima brucia
		# ancora più forte — che era il difetto della prima stesura di questo
		# banco, e sottocontava del 30%.
		var armato: bool = soma > 0.0 and (float(stato["soma"]) <= 0.0
				or soma_t < float(stato["soma_t"]))
		if decisione:
			_decisioni += 1
			if not reg_salito:
				_decisioni_orfane += 1

		# 2) DI CHI È L'ARM. Il percetto è la sorgente di serie; la tensione
		# del confronto se lo prende solo quando la sua decisione è caduta in
		# questo stesso fotogramma su questo stesso corpo.
		var fonte := str(stato["fonte"])
		if armato:
			fonte = "percetto"
			if decisione:
				if not percetto:
					fonte = "confronto"
				else:
					# ⚠️ IL FOTOGRAMMA CONTESO. `_tick_sussulti` gira PRIMA di
					# `_tick_confronti` e `somatico` tiene la più forte:
					# quindi se il livello che si legge adesso è la tensione,
					# l'allarme o non c'è stato o era più debole di lei; se è
					# un altro numero, l'ha scritto il percetto. Si conta a
					# parte perché è una coincidenza rara (due raffreddamenti
					# indipendenti, 9 e 12 s, nello stesso fotogramma): se il
					# referto ne stampa più di una manciata, questa
					# disambiguazione è diventata portante e va guardata.
					_arm_contesi += 1
					if absf(soma - _tensione_attesa(animo)) < 0.0005:
						fonte = "confronto"
			if fonte == "confronto":
				_arm_confronto += 1
		if soma <= 0.0:
			fonte = ""

		# 3) IL PERCETTO, e la coda che gli si può attribuire
		if percetto:
			var s: Dictionary = lim.ultimo_sussulto
			var rea := str(s.get("reazione", "nulla"))
			_percetti[rea] = int(_percetti.get(rea, 0)) + 1
			if not _forze.has(rea):
				_forze[rea] = []
			(_forze[rea] as Array).append(float(s.get("forza", 0.0)))
			if armato and fonte == "percetto":
				_coda_accesa[rea] = int(_coda_accesa.get(rea, 0)) + 1
			if rea == "si_illumina":
				# il cuoricino SENZA STORIA: nessun marchio positivo vero
				if absf(float(s.get("carica", 0.0))) < 0.2:
					_cuore_senza_storia += 1
				else:
					_cuore_con_storia += 1
		stato["cd"] = ora_cd
		stato["morso"] = ora_morso
		stato["soma"] = soma
		stato["soma_t"] = soma_t
		stato["fonte"] = fonte

		# 4) LE ORECCHIE NELL'ISTANTE DEL CUORICINO
		var tr := str(n.get("_rc_trans"))
		if tr != str(stato["trans"]):
			stato["trans"] = tr
			stato["t"] = 0.0 if tr == "si_illumina" else -1.0
		elif float(stato["t"]) >= 0.0:
			stato["t"] = float(stato["t"]) + dt
			if float(stato["t"]) >= ISTANTE_CUORE:
				var appl: Dictionary = n.get("_rc_appl")
				var ear := float(appl.get("ear", 0.0))
				_orecchie.append(ear)
				if ear < 0.0:
					_orecchie_su += 1
				else:
					_orecchie_giu += 1
				stato["t"] = -1.0
		prec[lab] = stato


func _mediana(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


func _referto(residenti: Array, secondi: float) -> void:
	print("")
	print("─".repeat(72))
	print("  I PERCETTI DELLA STRADA VELOCE (uno ogni 9 s per residente)")
	var tot := 0
	for k in _percetti:
		tot += int(_percetti[k])
	for k in ["trasalisce", "si_illumina", "nulla"]:
		var q := int(_percetti.get(k, 0))
		if q == 0 and not _percetti.has(k):
			continue
		var acc := int(_coda_accesa.get(k, 0))
		var f: Array = _forze.get(k, [])
		f.sort()
		print("    %-12s %4d percetti · CODA ACCESA %4d (%3.0f%%) · forza med %.3f  max %.3f"
				% [k, q, acc, 100.0 * float(acc) / maxf(1.0, float(q)),
				_mediana(f), 0.0 if f.is_empty() else float(f[f.size() - 1])])
	print("    (totale %d percetti in %.0f s su %d residenti)" % [tot, secondi, residenti.size()])
	print("    ⚠ «CODA ACCESA» qui conta SOLO gli arm del percetto: quelli della")
	print("      tensione del confronto sono scontati, e stanno nel blocco sotto.")
	print("")
	print("  L'ALTRA SORGENTE DELLA CODA: LA TENSIONE DEL CONFRONTO")
	print("    arm scontati (li ha armati `_tick_confronti`) ..... %d" % _arm_confronto)
	print("    decisioni di regolazione viste .................... %d" % _decisioni)
	var reg2: Dictionary = _vis.call("debug_regola_contatori")
	var righe: PackedStringArray = []
	for k2 in reg2:
		righe.append("%s %d" % [str(k2), int(reg2[k2])])
	print("    …e come sono andate (debug_regola_contatori) ...... %s"
			% ("nessuna" if righe.is_empty() else ", ".join(righe)))
	print("    fotogrammi CONTESI (percetto e decisione insieme) . %d" % _arm_contesi)
	if _decisioni_orfane > 0:
		print("    ⚠ DECISIONI ORFANE (il contatore aggregato non è salito): %d"
				% _decisioni_orfane)
		print("      → il raffreddamento `morso_<label>` non significa più «una")
		print("        decisione si è presa»: lo sconto sopra non è più fidato.")
	print("")
	print("  IL CUORICINO, E LA SUA STORIA")
	print("    con un marchio positivo VERO addosso ......... %d" % _cuore_con_storia)
	print("    ⚠ SENZA nessuna storia (|carica| < 0,2) ...... %d" % _cuore_senza_storia)
	print("")
	print("  LE ORECCHIE NELL'ISTANTE DEL CUORICINO (t = %.2f s dal transitorio)"
			% ISTANTE_CUORE)
	print("    campioni ..................................... %d" % _orecchie.size())
	print("    ⚠ SU (negativo = gioia) ...................... %d" % _orecchie_su)
	print("    ⚠ GIÙ (positivo = la faccia della paura) ..... %d" % _orecchie_giu)
	print("    mediana ...................................... %+.4f rad" % _mediana(_orecchie))
	print("")
	print("  IL LIVELLO «GUARDINGO», quanto sta acceso (su secondi-vicino)")
	print("    secondi-vicino ............................... %.0f" % _sec_vicino)
	print("    con la coda VISIBILE ......................... %.1f%%"
			% (100.0 * _sec_coda_viva / maxf(0.001, _sec_vicino)))
	print("      · di cui dal PERCETTO ...................... %.1f%%"
			% (100.0 * (_sec_coda_viva - _sec_coda_conf) / maxf(0.001, _sec_vicino)))
	print("      · di cui dalla TENSIONE del confronto ...... %.1f%%"
			% (100.0 * _sec_coda_conf / maxf(0.001, _sec_vicino)))
	print("    col rallentando ancora addosso ............... %.1f%%"
			% (100.0 * _sec_ritmo_lento / maxf(0.001, _sec_vicino)))
	print("      · di cui dal PERCETTO ...................... %.1f%%"
			% (100.0 * (_sec_ritmo_lento - _sec_ritmo_conf) / maxf(0.001, _sec_vicino)))
	print("      · di cui dalla TENSIONE del confronto ...... %.1f%%"
			% (100.0 * _sec_ritmo_conf / maxf(0.001, _sec_vicino)))
	print("    ⚠ il confronto con la corsa di PRIMA della tensione si fa sulla")
	print("      riga del PERCETTO, mai sul totale: sono due cose diverse.")
	print("")
	print("  COME IL GIOCO DESCRIVE I CORPI, alla fine (stato_corpo)")
	var corpi := {}
	var scossi := 0
	var animi: Dictionary = _vis.get("_animi")
	for r in residenti:
		var lab := str((r as Dictionary).get("label", ""))
		if not animi.has(lab):
			continue
		var c := str((animi[lab] as RefCounted).limbico.stato_corpo())
		corpi[c] = int(corpi.get(c, 0)) + 1
		if VISITORS.corpo_ha_da_dire(c):
			scossi += 1
	for c in corpi:
		print("    %-20s %d" % [c, corpi[c]])
	print("    ⚠ a quanti il saluto (T) risponde «…» invece che felice: %d su %d"
			% [scossi, residenti.size()])
	print("")
	print("    (secondi-vicino con Mochi entro 3,2 m: %.0f — è la condizione del percetto)"
			% _sec_addosso)
	print("─".repeat(72))
