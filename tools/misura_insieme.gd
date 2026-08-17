extends SceneTree
## IL METRO DELL'INSIEME — il termine entra nel punteggio, e il villaggio se
## ne accorge? E soprattutto: **si ammucchia?**
##
## Apre il MainLevel VERO, ci mette dei residenti veri, gli costruisce un
## villaggio dove sedersi, e lascia passare giornate di gioco a velocita'
## NORMALE (quattro minuti reali l'una: l'orologio non si accelera, o si
## misurerebbe un villaggio che non esiste — `_chats` guarda ogni 3,5 s e i
## corpi camminano a metri al secondo).
##
##   CHIBI_GIORNI=2    quante giornate di gioco (quattro minuti reali l'una)
##   CHIBI_QUANTI=13   quanti residenti
##   CHIBI_GAZEBO=1    posare il Gazebo (tre sgabelli a 0,92-1,01 m)
##
##   Godot --headless --path . --script res://tools/misura_insieme.gd
##
## ============================================================
## I NOVE NUMERI, e perche' ognuno
## ============================================================
##  1. **la durata di `r_bench`** (p50 e frazione sotto un secondo). E' la
##     precondizione di tutto: se una seduta dura trenta millisecondi non
##     esiste nessuna finestra dentro cui un secondo possa arrivare.
##  2. **il FATTO si accende davvero** — quante volte, e su quanti residenti.
##     Zero vorrebbe dire codice morto in partita con la suite verde, che e'
##     il guasto che questo progetto ha gia' pagato tre volte.
##  3. **IL TREMOLIO**: flip/min del fatto contro cambi d'azione/min. Il
##     fatto dev'essere piu' FERMO della decisione che alimenta, o
##     reinietta il rumore che il dado congelato ha tolto. Si conta anche il
##     booleano NUDO («un vicino entro tre metri») per confronto: e' la
##     forma sbagliata di questa stessa idea, ed e' utile vedere di quanto.
##  4. **il termine SCAVALCA** — appaiato NELLA STESSA CORSA e sullo STESSO
##     istante: per ogni rinfresco col bit acceso si ricalcolano i punteggi
##     con e senza, e si guarda se l'argmax cambia e di quanto. Due corse
##     diverse sarebbero due villaggi, e la differenza misurata non sarebbe
##     del termine.
##  5. **`riposo` nell'argmax**, in percentuale: il termine deve muovere il
##     villaggio, non solo il numero.
##  6. **s-coppia SEDUTI entro `VICINI`** e coppie DISTINTE: e' la cosa che
##     manca al predicato delle cricche per esistere.
##  7. **il GRAPPOLO massimo** e i campioni con tre o piu' seduti vicini.
##  8. ⚠️ **LA BARRA DELLO ZERO** — la frazione di tempo in cui un residente
##     non ha NESSUNO entro tre metri. E' il **cancello di arresto**: se
##     scende, il villaggio si sta ammucchiando e il termine va tolto,
##     qualunque cosa dicano gli altri otto numeri. Un villaggio-grumo e' la
##     fine del cozy — non si distinguono piu' le persone, non ci sono piu'
##     posti, spariscono le distanze che raccontano qualcosa.
##  9. **le righe che il registro delle cricche incassa** per giornata.
##
## ⚠️ **L'ORACOLO E' INDIPENDENTE**: i grappoli e le coppie si contano dalle
## POSIZIONI DEI CORPI, campionate dal banco, mai chiedendo a `Cricche` ne'
## al fatto stesso. Chiedere al giudice se e' d'accordo con se' stesso e'
## l'errore che `tools/misura_cammino.gd` esiste per non commettere.
##
## ⚠️ **E NON SI TOCCA IL `village.json` DELL'AUTORE**:
## `set_persist_for_debug(false)` prima di posare qualunque cosa, e
## l'impronta del file confrontata prima e dopo. Un banco altrui si e' gia'
## portato via due gigabyte.

const VISITORS := preload("res://scenes/npc/Visitors.gd")

## Fin dove si guarda per la barra dello ZERO, in metri. **Non e' `VICINI`**,
## ed e' voluto: `VICINI` (1,9 m) e' «accanto», questo e' «nei paraggi». Il
## grumo si vede alla scala della SCENA, non a quella della panchina — tre
## metri e' la distanza a cui due chibi sono ancora due persone distinte
## invece che un mucchio.
const PARAGGI := 3.0

var _vis: Node
var _dn: Node3D
var _build: Node
var _cric: Node
var _ecs: Object
var _quanti := 13
var _giorni := 2

# --- le misure -----------------------------------------------------------
var _sedute := []            # durate di r_bench, in secondi
var _sedute_apertura := {}   # label -> quando si e' seduto
var _fatto_camp := 0
var _fatto_acceso := 0
var _fatto_chi := {}         # label -> quante volte acceso
var _flip := {}              # label -> quanti cambi del bit
var _prec := {}
var _nudo_flip := {}
var _nudo_prec := {}
var _az_flip := {}
var _az_prec := {}
var _argmax := {}            # azione -> quante volte era l'argmax
var _argmax_tot := 0
var _scavalchi := 0          # quante volte il bit CAMBIA l'argmax
var _scavalchi_visti := 0    # su quante valutazioni col bit acceso
var _scarti := []            # di quanto muove il punteggio del riposo
var _coppie_sedute := 0.0    # secondi-coppia
var _coppie_distinte := {}
var _grappolo_max := 0
var _camp_tre := 0
## ⚠️ **LA DOMANDA DELLA REGOLA SACRA, e nessuno la misurava.** Un
## meccanismo che avvicina la gente puo' produrre due villaggi opposti: uno
## in cui tutti stanno con tutti a turno, e uno in cui si formano dei blocchi
## e qualcuno resta fuori. I numeri della co-presenza (righe, coppie,
## grappoli) **non li distinguono**: cento righe possono essere venti persone
## che si mescolano o quattro che si vedono sempre.
##
## Si contano quindi i PARTNER DISTINTI per residente — e si spezza la curva
## per INDOLE, perche' il modo in cui questo sistema potrebbe escludere
## qualcuno e' proprio quello: il carattere che diventa un cancello invece
## che una preferenza. Il fattore dell'insieme e' cieco al carattere apposta;
## questa e' la riga che lo verifica nel mondo invece che nel commento.
##
## Oracolo INDIPENDENTE: le coppie si contano dalle POSIZIONI DEI CORPI
## campionate qui, mai chiedendo a `Cricche`.
var _partner := {}           # label -> { label dell'altro: campioni }
var _indole := {}            # label -> indole
var _isto := {}              # quanti vicini entro PARAGGI -> campioni
## ⚠️ **LA STESSA BARRA, FUORI DAL RITO.** La barra dello zero misurata su
## tutta la giornata e' dominata dal FALO': ogni sera ventotto corpi si
## siedono in cerchio a posti ASSEGNATI (`_posto_al_falo`), e quella e' una
## coda a otto-nove vicini che vale dieci-diciotto punti percentuali e balla
## di sei punti fra una corsa e l'altra — cioe' piu' di qualunque effetto
## che questo meccanismo possa avere. MISURATO: due corse nello stesso modo
## danno 47,24% e 42,62%, e la differenza fra i due modi e' piu' piccola di
## quella. Un cancello di arresto che non sa distinguere il suo segnale dal
## proprio rumore non e' un cancello.
##
## E l'esclusione non e' una comodita': e' la **stessa regola** con cui
## `Visitors._segna_incontro` rifiuta di registrare la co-presenza al falo'
## — li' la vicinanza non la sceglie nessuno. Un meccanismo che non tocca il
## rito non va misurato attraverso il rito.
var _isto_lib := {}          # …contando solo i campioni in cui NESSUNO e' al falo'
var _isto_lib_tot := 0
var _isto_tot := 0
var _campioni := 0
var _fronti := {}            # azione -> quante volte l'agenda l'ha APERTA
var _fronti_tot := 0
var _arrivi := 0             # quante volte un corpo e' arrivato su una seduta
var _az_corr_prec := {}


func _init() -> void:
	_go()


func _trova(g: String) -> Node:
	for n in get_nodes_in_group(g):
		return n
	return null


func _cella(k: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(-8 + (k % 5) * 4, 2 + (k / 5) * 4)


func _impronta(p: String) -> String:
	if not FileAccess.file_exists(p):
		return "(assente)"
	var f := FileAccess.open(p, FileAccess.READ)
	var c := HashingContext.new()
	c.start(HashingContext.HASH_SHA256)
	c.update(f.get_buffer(f.get_length()))
	return c.finish().hex_encode()


func _go() -> void:
	if OS.get_environment("CHIBI_QUANTI") != "":
		_quanti = int(OS.get_environment("CHIBI_QUANTI"))
	if OS.get_environment("CHIBI_GIORNI") != "":
		_giorni = int(OS.get_environment("CHIBI_GIORNI"))
	var salvataggio := "user://village.json"
	var prima_sha := _impronta(salvataggio)

	if change_scene_to_file("res://scenes/levels/MainLevel.tscn") != OK:
		push_error("MainLevel non si apre")
		quit(1)
		return
	for _i in 40:
		await process_frame
	_vis = _trova("visitors")
	_dn = _trova("daynight") as Node3D
	_build = _trova("build_system")
	_cric = _trova("cricche")
	if _vis == null or _dn == null or _build == null:
		push_error("manca Visitors, DayNight o BuildSystem")
		quit(1)
		return
	# PRIMA DI TOCCARE QUALUNQUE COSA
	_build.call("set_persist_for_debug", false)

	# IL VILLAGGIO DEVE AVERE DOVE SEDERSI, o la co-presenza che si misura e'
	# quella di un prato vuoto. Il Gazebo e' il mobile a TRE sedute fratelle:
	# e' lui che rende possibile una terna, e senza di lui il numero delle
	# cricche non dice niente sul termine.
	for k in 4:
		var z := 2 + k * 4
		for x in [-11, 11]:
			_build.call("place_cell", Vector2i(x, z), "Cespuglio", 0, false)
		for x2 in [-4, 4]:
			_build.call("place_cell", Vector2i(x2, z), "Panchina", 0, false)
	if OS.get_environment("CHIBI_GAZEBO") != "0":
		_build.call("place_cell", Vector2i(0, 10), "Gazebo", 0, false)
	_build.call("aggiorna_varchi_ora")
	await process_frame

	# ⚠️ **SE IL VILLAGGIO C'E' GIA', SI MISURA QUELLO.** Il MainLevel carica
	# il salvataggio, e i residenti veri hanno case vere, sparse come le ha
	# posate il giocatore. I miei starebbero su una griglia a quattro metri —
	# co-presenza FABBRICATA dal banco, cioe' un tetto travestito da media
	# (e' il difetto dichiarato di `misura_cricche`). Se ne mettono di propri
	# solo su un prato vuoto.
	var VS := load("res://scenes/npc/Visitor.gd")
	var DNAG := load("res://scenes/npc/ChibiDNA.gd")
	var residenti: Array = _vis.get("_residents")
	var gia := residenti.size()
	print("residenti gia' nel salvataggio: %d" % gia)
	for k in (0 if gia >= 6 else _quanti):
		var c := _cella(k)
		var v = VS.new()
		v.dna = DNAG.generate(9000 + k * 37)
		_vis.add_child(v)
		v.mode = "resident"
		# ⚠️ SULLA PROPRIA CELLA: `Visitors` calcola i luoghi da `home =
		# cell`, e un corpo lontano dalla sua cella pianifica per un posto e
		# cammina in un altro.
		v.position = Vector3(float(c.x), 0.0, float(c.y))
		v._enter_state("r_idle")
		var lab := "Prova%02d" % k
		var r := {"node": v, "label": lab, "dna": v.dna, "cell": c, "species": "chibi"}
		residenti.append(r)
		_vis.call("_ensure_brain", r)
	for r2 in residenti:
		var l2 := str((r2 as Dictionary).get("label", ""))
		_flip[l2] = 0; _prec[l2] = false
		_nudo_flip[l2] = 0; _nudo_prec[l2] = false
		_az_flip[l2] = 0; _az_prec[l2] = -99
		_fatto_chi[l2] = 0
	for _i2 in 8:
		await process_frame
	_ecs = _vis.get("_ecs")
	var posti := _conta_posti()
	print("residenti %d · posti dove sedersi %d · gazebo %s"
			% [residenti.size(), posti,
			"si" if OS.get_environment("CHIBI_GAZEBO") != "0" else "no"])
	print("il fatto accende il bit %d" % _bit_insieme())

	# ---- LA GEOGRAFIA DELL'INVITO, che non dipende dal tempo ----
	# Se nessun residente ha DUE sedute accanto a portata di casa, il fatto
	# non potra' accendersi mai — e il numero che segue non direbbe niente
	# sul termine: direbbe che il villaggio non ha il mobile.
	var posti_n: Array = []
	for pn in (_build.call("get_placed_by_name", "Panchina") as Array):
		posti_n.append(pn as Node3D)
	for gz in (_build.call("get_placed_by_name", "Gazebo") as Array):
		for pp in (gz as Node3D).find_children("Posto*", "Node3D", true, false):
			posti_n.append(pp as Node3D)
	for sr in (_build.call("get_placed_by_name", "Serra") as Array):
		for pp2 in (sr as Node3D).find_children("Posto*", "Node3D", true, false):
			posti_n.append(pp2 as Node3D)
	var accoppiati := {}
	var coppie_posti := 0
	var terne_posti := 0
	for x in posti_n.size():
		var q := 0
		for y in posti_n.size():
			if x == y:
				continue
			if (posti_n[x] as Node3D).global_position.distance_to(
					(posti_n[y] as Node3D).global_position) <= VISITORS.VICINI:
				q += 1
				if y > x:
					coppie_posti += 1
		if q >= 1:
			accoppiati[x] = true
		if q >= 2:
			terne_posti += 1
	var a_portata := 0
	for r3 in residenti:
		var c3: Vector2i = (r3 as Dictionary).get("cell", Vector2i(999, 999))
		if c3.x == 999:
			continue
		var casa := Vector3(float(c3.x), 0.0, float(c3.y))
		for x2 in accoppiati:
			if casa.distance_to((posti_n[int(x2)] as Node3D).global_position) <= 22.0:
				a_portata += 1
				break
	print("geografia: %d sedute · %d coppie entro %.1f m · %d sedute con due accanto"
			% [posti_n.size(), coppie_posti, VISITORS.VICINI, terne_posti])
	print("           residenti con una coppia di sedute a portata di casa: %d su %d"
			% [a_portata, residenti.size()])

	_dn.call("set_time", 0.02)
	var scatti := 0
	var prima := float(_dn.get("time"))
	var passato := 0.0
	var t_prec := Time.get_ticks_msec()
	while passato < float(_giorni):
		await process_frame
		var ora := float(_dn.get("time"))
		passato += fposmod(ora - prima, 1.0)
		prima = ora
		scatti += 1
		var adesso := Time.get_ticks_msec()
		var dt := float(adesso - t_prec) / 1000.0
		t_prec = adesso
		_ogni_frame(residenti, dt)
		if scatti % 8 == 0:
			_campiona(residenti)
		if scatti % 1800 == 0:
			print("   … %.2f giornate, ora %.2f (%s)"
					% [passato, ora, _vis.call("_phase")])
	_referto(residenti)
	var dopo_sha := _impronta(salvataggio)
	print("\nil salvataggio dell'autore: %s"
			% ["INTATTO" if prima_sha == dopo_sha else "⚠️ TOCCATO ⚠️"])
	quit()


func _bit_insieme() -> int:
	if _ecs == null:
		return 0
	return int(_ecs.maschera_fatti(PackedStringArray([VISITORS.FATTO_INSIEME])))


func _conta_posti() -> int:
	var n: int = (_build.call("get_placed_by_name", "Panchina") as Array).size()
	for g in (_build.call("get_placed_by_name", "Gazebo") as Array):
		n += (g as Node3D).find_children("Posto*", "Node3D", true, false).size()
	return n


## OGNI FRAME: le due cose che un campionamento rado si perderebbe — quanto
## dura una seduta (che comincia e finisce fra due campioni) e quante volte
## il bit CAMBIA (contarne i cambi a campioni radi ne perde la meta').
func _ogni_frame(res: Array, dt: float) -> void:
	var bit := _bit_insieme()
	for r in res:
		var d := r as Dictionary
		var n := d.get("node") as Node3D
		if n == null or not is_instance_valid(n):
			continue
		var lab := str(d.get("label", ""))
		var seduto := str(n.get("_state")) == "r_bench"
		# 1) LA DURATA DELLA SEDUTA, cronometrata sul CORPO
		if seduto:
			if not _sedute_apertura.has(lab):
				_arrivi += 1
			_sedute_apertura[lab] = float(_sedute_apertura.get(lab, 0.0)) + dt
		elif _sedute_apertura.has(lab):
			_sedute.append(float(_sedute_apertura[lab]))
			_sedute_apertura.erase(lab)
		# 2) IL BIT, come lo vede la DECISIONE (cioe' dalla maschera vera,
		#    quella che il ponte ha consegnato al C++, non da una domanda
		#    rifatta qui: rifarla vorrebbe dire misurare il mio conto)
		var acceso := bit != 0 and (int(d.get("fatti", 0)) & bit) != 0
		# 4bis) I FRONTI: quante volte l'agenda apre DAVVERO quella decisione.
		#       L'argmax e' un desiderio; il fronte e' il gesto.
		if _ecs != null and d.has("ecs"):
			var azc: int = _ecs.azione(int(d["ecs"]))
			if azc != int(_az_corr_prec.get(lab, -99)):
				_az_corr_prec[lab] = azc
				if azc >= 0:
					_fronti[azc] = int(_fronti.get(azc, 0)) + 1
					_fronti_tot += 1
		if acceso != bool(_prec[lab]):
			_flip[lab] = int(_flip[lab]) + 1
			_prec[lab] = acceso
		# 3) IL BOOLEANO NUDO, la forma sbagliata della stessa idea
		var nudo := false
		for altro in res:
			var n2 := (altro as Dictionary).get("node") as Node3D
			if n2 != null and n2 != n and is_instance_valid(n2) \
					and n2.global_position.distance_to(n.global_position) <= PARAGGI:
				nudo = true
				break
		if nudo != bool(_nudo_prec[lab]):
			_nudo_flip[lab] = int(_nudo_flip[lab]) + 1
			_nudo_prec[lab] = nudo
		# 4) i cambi d'AZIONE, il metro di confronto
		if _ecs != null and d.has("ecs"):
			var az: int = _ecs.azione(int(d["ecs"]))
			if az != int(_az_prec[lab]):
				_az_flip[lab] = int(_az_flip[lab]) + 1
				_az_prec[lab] = az


## IL CAMPIONE RADO: la geometria (che cambia piano) e le due misure
## appaiate, che costano una chiamata al C++ per residente.
func _campiona(res: Array) -> void:
	var bit := _bit_insieme()
	var seduti: Array = []
	# ⚠️ **IL RITO SI RICONOSCE DALLA FASE, non dallo stato.** La prima
	# stesura guardava chi fosse in `r_fire`, e non bastava: durante la fase
	# del falo' i corpi ci CAMMINANO verso, e ci stanno intorno, senza essere
	# in quello stato — la coda restava tutta li' (9,31% a sette vicini).
	# La fase e' la stessa che `Visitors` usa per comandare il rito.
	var rito := str(_vis.call("_phase")) == "fire"
	# ⚠️ **E UN CORPO DENTRO CASA NON E' NELLA SCENA.** Di notte i residenti
	# sono nascosti (`resident_sleep` li rimpicciolisce a scala 0.03) ma la
	# loro POSIZIONE resta sulla cella di casa: due case adiacenti facevano
	# due «vicini entro tre metri» per tutta la notte, e nessuno dei due
	# corpi era visibile. La domanda del grumo e' «il giocatore vede un
	# mucchio?», quindi si contano i corpi che si vedono.
	var visibili: Array = []
	for r0 in res:
		var n0 := (r0 as Dictionary).get("node") as Node3D
		if n0 == null or not is_instance_valid(n0):
			continue
		if bool(n0.call("is_hidden")) or bool(n0.call("dorme")):
			continue
		visibili.append(n0)
	for r in res:
		var d := r as Dictionary
		var n := d.get("node") as Node3D
		if n == null or not is_instance_valid(n):
			continue
		var lab := str(d.get("label", ""))
		_campioni += 1
		# --- il fatto
		if bit != 0 and (int(d.get("fatti", 0)) & bit) != 0:
			_fatto_acceso += 1
			_fatto_chi[lab] = int(_fatto_chi[lab]) + 1
		_fatto_camp += 1
		# --- l'argmax, e IL CONFRONTO APPAIATO
		if _ecs != null and d.has("ecs"):
			var id: int = int(d["ecs"])
			var az: int = _ecs.azione_desiderata(id)
			if az >= 0:
				_argmax[az] = int(_argmax.get(az, 0)) + 1
				_argmax_tot += 1
			if bit != 0 and (int(d.get("fatti", 0)) & bit) != 0:
				_appaia(d, id, bit)
		# --- la barra dello ZERO, e il grappolo
		var quanti := 0
		for altro in res:
			var n2 := (altro as Dictionary).get("node") as Node3D
			if n2 != null and n2 != n and is_instance_valid(n2) \
					and n2.global_position.distance_to(n.global_position) <= PARAGGI:
				quanti += 1
		_isto[quanti] = int(_isto.get(quanti, 0)) + 1
		_isto_tot += 1
		# …e CHI erano, per l'esclusione. Fuori dal rito, per la stessa
		# ragione della barra 8b: al falo' i posti li assegna il rito, e i
		# partner che ne uscirebbero non li ha scelti nessuno.
		if not rito and not bool(n.call("is_hidden")) and not bool(n.call("dorme")):
			if not _partner.has(lab):
				_partner[lab] = {}
				_indole[lab] = str((d.get("dna", {}) as Dictionary).get("indole", "?"))
			for altro2 in res:
				var d2 := altro2 as Dictionary
				var n3 := d2.get("node") as Node3D
				if n3 == null or n3 == n or not is_instance_valid(n3):
					continue
				if bool(n3.call("is_hidden")) or bool(n3.call("dorme")):
					continue
				if n3.global_position.distance_to(n.global_position) <= VISITORS.VICINI:
					var l2 := str(d2.get("label", ""))
					(_partner[lab] as Dictionary)[l2] = \
							int((_partner[lab] as Dictionary).get(l2, 0)) + 1
		if not rito and not bool(n.call("is_hidden")) and not bool(n.call("dorme")):
			var q_vis := 0
			for nv in visibili:
				if nv != n and (nv as Node3D).global_position \
						.distance_to(n.global_position) <= PARAGGI:
					q_vis += 1
			_isto_lib[q_vis] = int(_isto_lib.get(q_vis, 0)) + 1
			_isto_lib_tot += 1
		if str(n.get("_state")) == "r_bench":
			seduti.append([lab, n.global_position])
	# --- i SEDUTI vicini: coppie, grappolo
	var grappolo := 0
	for i in seduti.size():
		var q := 0
		for j in seduti.size():
			if i == j:
				continue
			if (seduti[i][1] as Vector3).distance_to(seduti[j][1] as Vector3) <= VISITORS.VICINI:
				q += 1
				if j > i:
					_coppie_sedute += 1.0
					var chiave := "%s|%s" % [seduti[i][0], seduti[j][0]]
					_coppie_distinte[chiave] = int(_coppie_distinte.get(chiave, 0)) + 1
		grappolo = maxi(grappolo, q + 1)
	_grappolo_max = maxi(_grappolo_max, grappolo)
	if grappolo >= 3:
		_camp_tre += 1


## LE DUE REGOLE APPAIATE, SULLO STESSO ISTANTE E SULLA STESSA PERSONA.
##
## Quanto conta il termine si misura cosi' e non confrontando due corse: due
## corse sono due villaggi. Qui si prende il contesto VERO di adesso, si
## chiedono i punteggi con e senza il bit, e si guarda se l'argmax cambia.
func _appaia(d: Dictionary, id: int, bit: int) -> void:
	var brain: RefCounted = _vis.call("_ensure_brain", d)
	var ent: Dictionary = _ecs.debug_entita(id)
	var emo: Dictionary = _ecs.debug_emozioni(id)
	var b: PackedFloat64Array = brain.bisogni_packed()
	var f: int = int(d.get("fatti", 0))
	var mod: PackedFloat64Array = emo.get("mod", PackedFloat64Array())
	if mod.size() != 8:
		return
	var con: PackedFloat64Array = _ecs.debug_punteggi_mod(
			b, f, int(ent["indole"]), int(ent["quirk"]), mod)
	var senza: PackedFloat64Array = _ecs.debug_punteggi_mod(
			b, f & ~bit, int(ent["indole"]), int(ent["quirk"]), mod)
	if con.size() != 8 or senza.size() != 8:
		return
	_scavalchi_visti += 1
	_scarti.append(con[1] - senza[1])
	var a_con := 0
	var a_senza := 0
	for i in 8:
		if con[i] > con[a_con]:
			a_con = i
		if senza[i] > senza[a_senza]:
			a_senza = i
	if a_con != a_senza:
		_scavalchi += 1


func _p(v: Array, q: float) -> float:
	if v.is_empty():
		return 0.0
	var s := v.duplicate()
	s.sort()
	return float(s[clampi(int(q * float(s.size())), 0, s.size() - 1)])


func _referto(res: Array) -> void:
	var AZIONI := ["spuntino", "riposo", "chiacchiere", "giardino",
			"meraviglia", "stella", "regia", "gironzola"]
	var minuti := float(_giorni) * 4.0
	print("\n============ IL METRO DELL'INSIEME · %d giornate ============" % _giorni)

	# 1
	var corti := 0
	for s in _sedute:
		if float(s) < 1.0:
			corti += 1
	print("\n1. LA SOSTA — sedute misurate: %d" % _sedute.size())
	if not _sedute.is_empty():
		print("   durata  p50 %.2f s · p10 %.2f · p90 %.2f · sotto un secondo: %d (%.0f%%)"
				% [_p(_sedute, 0.5), _p(_sedute, 0.1), _p(_sedute, 0.9),
				corti, 100.0 * float(corti) / float(_sedute.size())])
		var ord := _sedute.duplicate()
		ord.sort()
		var riga := ""
		for v9 in ord:
			riga += "%.2f " % float(v9)
		print("   per esteso: " + riga)

	# 2
	var chi := 0
	for k in _fatto_chi:
		if int(_fatto_chi[k]) > 0:
			chi += 1
	print("\n2. IL FATTO — acceso nel %.2f%% dei campioni (%d su %d), su %d residenti di %d"
			% [100.0 * float(_fatto_acceso) / maxf(1.0, float(_fatto_camp)),
			_fatto_acceso, _fatto_camp, chi, res.size()])

	# 3
	var sf := 0; var sn := 0; var sa := 0
	for k2 in _flip:
		sf += int(_flip[k2]); sn += int(_nudo_flip[k2]); sa += int(_az_flip[k2])
	var per := float(res.size()) * minuti
	print("\n3. IL TREMOLIO — per residente, al minuto:")
	print("   il FATTO «posto accanto»            %.2f" % (float(sf) / per))
	print("   i CAMBI D'AZIONE (il metro)         %.2f" % (float(sa) / per))
	print("   il booleano NUDO entro %.1f m        %.2f  (la forma sbagliata)"
			% [PARAGGI, float(sn) / per])
	print("   → il fatto e' %s della decisione che alimenta"
			% ["PIU' FERMO" if float(sf) <= float(sa) else "⚠️ PIU' MOSSO ⚠️"])

	# 4
	print("\n4. IL TERMINE SCAVALCA — appaiato, stesso istante, stessa persona:")
	if _scavalchi_visti > 0:
		print("   valutazioni col bit acceso: %d · argmax cambiato: %d (%.2f%%)"
				% [_scavalchi_visti, _scavalchi,
				100.0 * float(_scavalchi) / float(_scavalchi_visti)])
		print("   scarto sul punteggio del riposo:  mediano %.4f · p90 %.4f · max %.4f"
				% [_p(_scarti, 0.5), _p(_scarti, 0.9), _p(_scarti, 0.999)])
	else:
		print("   (mai: il bit non si e' mai acceso)")

	# 5
	print("\n5. I FRONTI — cosa il villaggio si e' MESSO a fare (%d in tutto):" % _fronti_tot)
	for a2 in 8:
		var q2 := int(_fronti.get(a2, 0))
		if q2 > 0:
			print("   %-12s %5.2f%%  (%d)" % [AZIONI[a2],
					100.0 * float(q2) / maxf(1.0, float(_fronti_tot)), q2])
	print("   …e i corpi ARRIVATI su una seduta: %d" % _arrivi)

	print("\n5b. L'ARGMAX — cosa vuole fare il villaggio:")
	for a in 8:
		var q := int(_argmax.get(a, 0))
		if q > 0:
			print("   %-12s %5.2f%%" % [AZIONI[a],
					100.0 * float(q) / maxf(1.0, float(_argmax_tot))])

	# 6
	print("\n6. SEDUTI ACCANTO (entro %.1f m) — %.0f campioni-coppia, %d coppie DISTINTE"
			% [VISITORS.VICINI, _coppie_sedute, _coppie_distinte.size()])

	# 7
	print("\n7. IL GRAPPOLO — massimo %d seduti vicini · campioni con tre o piu': %d"
			% [_grappolo_max, _camp_tre])

	# 8
	_stampa_esclusione()
	_stampa_barra("8b. LA BARRA VERA — corpi VISIBILI, fuori dal rito del falo'",
			_isto_lib, _isto_lib_tot)
	print("\n8. ⚠️ LA BARRA DELLO ZERO — quanti vicini entro %.1f m (col falo' dentro:" % PARAGGI)
	print("   e' dominata dal rito, e balla di sei punti fra due corse uguali):")
	var chiavi := _isto.keys()
	chiavi.sort()
	for k3 in chiavi:
		print("   %2d vicini  %5.2f%%%s" % [int(k3),
				100.0 * float(_isto[k3]) / maxf(1.0, float(_isto_tot)),
				"   ← IL CANCELLO DI ARRESTO" if int(k3) == 0 else ""])

	# 9
	if _cric != null and is_instance_valid(_cric):
		var righe: Array = _cric.get("_incontri")
		print("\n9. IL REGISTRO — %d righe in %d giornate (%.1f al giorno)"
				% [righe.size(), _giorni, float(righe.size()) / float(_giorni)])


## Una barra sola, stampata come le altre — piu' la coda alta, che e' la
## firma del rito: se cresce, quello che si sta guardando e' il falo'.
func _stampa_barra(titolo: String, isto: Dictionary, tot: int) -> void:
	print("\n%s (%d campioni):" % [titolo, tot])
	if tot == 0:
		print("   (nessun campione fuori dal rito)")
		return
	var chiavi: Array = isto.keys()
	chiavi.sort()
	var coda := 0.0
	for k in chiavi:
		var f := 100.0 * float(isto[k]) / float(tot)
		if int(k) >= 5:
			coda += f
		print("   %2d vicini  %5.2f%%%s" % [int(k), f,
				"   ← IL CANCELLO DI ARRESTO" if int(k) == 0 else ""])
	print("   …la coda da 5 vicini in su: %.2f%% (la firma del rito)" % coda)


## ⚠️ **CHI STA CON CHI, E CHI CON NESSUNO** — la domanda della REGOLA SACRA.
##
## Non «quante coppie», che non distingue un villaggio che si mescola da uno
## a blocchi: **quanti partner DIVERSI** ha avuto ciascuno, e la stessa curva
## spezzata per indole. Se una indole ha sistematicamente meno partner delle
## altre, il carattere ha smesso di essere una preferenza ed e' diventato un
## cancello — che e' esattamente cio' che la regola 5 vieta.
func _stampa_esclusione() -> void:
	print("\n10. ⚠️ L'ESCLUSIONE — partner DISTINTI per residente (fuori dal rito):")
	if _partner.is_empty():
		print("   (nessun campione)")
		return
	var per_indole := {}
	var zero := 0
	var righe: Array = []
	for lab in _partner:
		var q: int = (_partner[lab] as Dictionary).size()
		if q == 0:
			zero += 1
		righe.append([q, str(lab), str(_indole.get(lab, "?"))])
		var ind := str(_indole.get(lab, "?"))
		if not per_indole.has(ind):
			per_indole[ind] = []
		(per_indole[ind] as Array).append(q)
	righe.sort_custom(func(a2, b2): return int(a2[0]) > int(b2[0]))
	var linea := ""
	for r in righe:
		linea += "%s:%d " % [str(r[1]), int(r[0])]
	print("   %s" % linea)
	print("   → chi non ha avuto NESSUN partner: %d su %d" % [zero, _partner.size()])
	print("   per indole:")
	for ind in per_indole:
		var v: Array = per_indole[ind]
		var somma := 0
		for x in v:
			somma += int(x)
		print("      %-14s %d residenti, partner distinti in media %.2f"
				% [ind, v.size(), float(somma) / maxf(1.0, float(v.size()))])
