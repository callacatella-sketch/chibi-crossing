extends SceneTree
## IL METRO DELLA TEORIA DELLA MENTE — le due firme, e i due cancelli.
##
## La previsione da falsificare: l'onniscienza produce **zero ridondanza per
## costruzione**; un modello epistemico costruito solo dalla co-testimonianza
## produce qualche ripetizione benigna e — questa è la firma — una **coda di
## ritardatari**, gente che resta fuori perché tutti credono che sappia già.
##
## ⚠️ L'ORACOLO È INDIPENDENTE: non si chiede al modello se ha ragione. Si
## legge la maschera VERA di B (`debug_saputi_veri`) e la si confronta con
## ciò che A crede (`debug_credenze`). Chiedere al giudice se è d'accordo con
## sé stesso è l'errore che `tools/misura_cammino.gd` esiste per non fare.
##
## ⚠️ E LE DUE FORME SI MISURANO NELLA STESSA CORSA, senza alzare la leva:
## alzarla dà due villaggi diversi, e la differenza misurata non sarebbe più
## della regola. La leva serve a UNA cosa sola, ed è la TARATURA DEL BANCO —
## con l'onniscienza accesa la ridondanza dev'essere esattamente ZERO, ed è
## dimostrabile riga per riga. Se ne misura anche una, non è il gioco a
## essere rotto: è questo strumento.
##
## I DUE CANCELLI D'ARRESTO, dichiarati PRIMA di misurare:
##  1. **la saturazione** — le notizie al minuto nell'ultimo quinto della
##     corsa contro il primo. Se scendono sotto la metà, il pettegolezzo si
##     sta spegnendo: la durata della credenza va abbassata, o il meccanismo
##     va tolto.
##  2. **la classe** — se il ritardatario è sistematicamente il vicino a cui
##     il giocatore sta PIÙ VICINO, la meccanica ha costruito una classifica
##     di chi resta fuori, e la REGOLA SACRA dice che va tolta, non tarata.
##     (Il ricambio del grafo è massimo in chi vede Mochi di più, e il bit si
##     spegne quando la riga viene POTATA: la correlazione è attesa, va
##     misurata.)
##
## CHIBI_MINUTI (6) · CHIBI_QUANTI (14) · CHIBI_DURATA (-1 = quella del gioco;
## 0 = credenza eterna) · CHIBI_ONNI=1 per la taratura.

var _build: Node
var _vis: Node
var _cuore: Node
var _player: Node3D
var _campioni: Array = []
var _ripetizioni := 0
var _nuove := 0
var _muti := 0
var _fuori := 0
var _per_nome := {}
var _notizie: Array = []          # [secondo] di ogni racconto andato a buon fine
var _vicinanza := {}              # nome -> secondi passati entro 6 m da Mochi
var _ultimo_ms := 0


func _init() -> void:
	var minuti := float(OS.get_environment("CHIBI_MINUTI")) if OS.has_environment("CHIBI_MINUTI") else 6.0
	var quanti := int(OS.get_environment("CHIBI_QUANTI")) if OS.has_environment("CHIBI_QUANTI") else 14
	var durata := float(OS.get_environment("CHIBI_DURATA")) if OS.has_environment("CHIBI_DURATA") else -1.0
	var onni := OS.has_environment("CHIBI_ONNI")
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
		print("GUASTO: manca qualcosa nel MainLevel"); quit(1); return
	_build.call("set_persist_for_debug", false)
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	await create_timer(1.5).timeout

	_vis.call("debug_reset")
	var celle: Array[Vector2i] = []
	for gx in range(-7, 7):
		for gz in range(-7, 7):
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
		celle_letto.append(c)
		letti += 1
	# roba con cui il villaggio possa VIVERE: senza mete non si cammina, e
	# senza camminare non si incontra nessuno
	var extra := 0
	while extra < 14 and i < celle.size():
		_build.call("place_cell", celle[i], ["Cespuglio", "Panchina", "Aiuola", "Fontana"][extra % 4], 0, false)
		i += 1
		extra += 1
	_build.call("aggiorna_varchi_ora")
	for k in celle_letto.size():
		_vis.call("debug_settle", 5000 + k * 37, celle_letto[k])
	await create_timer(1.5).timeout

	_cuore = get_first_node_in_group("ecs_mondo")
	if _cuore == null:
		print("GUASTO: EcsMondo non trovato (la GDExtension e' caricata?)"); quit(1); return
	if durata >= 0.0:
		_cuore.call("debug_tara_credenze", durata)
	if onni:
		_cuore.call("debug_onniscienza", true)

	var residenti: Array = _vis.get("_residents")
	print("=== TEORIA DELLA MENTE — %d residenti, %.0f minuti, %s ===" % [
			residenti.size(), minuti,
			"ONNISCIENZA (taratura)" if onni else "modello epistemico"])
	if durata >= 0.0:
		print("    durata credenza forzata: %s" % ("ETERNA" if durata == 0.0 else "%.0f s" % durata))
	if residenti.size() < 4:
		print("GUASTO: troppi pochi residenti (%d)" % residenti.size()); quit(1); return

	await _gira(minuti * 60.0)
	_referto(minuti * 60.0, onni)
	quit()


## Mochi cammina e lavora come un giocatore: senza gesti non c'è niente da
## vedere, e senza testimoni non c'è co-testimonianza.
func _gira(secondi: float) -> void:
	var t := 0.0
	_ultimo_ms = Time.get_ticks_msec()
	var meta := Vector3(randf_range(-12, 12), 0, randf_range(-12, 12))
	var t_gesto := 0.0
	var t_camp := 0.0
	var verbi := ["annaffia", "semina", "raccoglie", "costruisce", "taglia", "pesca", "cucina"]
	var perc := get_first_node_in_group("percezione")
	while t < secondi:
		await process_frame
		# ⚠️ `process_frame` NON torna il delta (torna Nil, e assegnarlo a un
		# float e' un errore a runtime che interrompe la funzione lasciando il
		# banco a zero campioni). Il tempo si legge dall'orologio vero: cosi'
		# il conto dei secondi e' quello che il villaggio ha vissuto davvero,
		# non quello che il banco crede di avergli dato.
		var ora_ms := Time.get_ticks_msec()
		var dt := float(ora_ms - _ultimo_ms) / 1000.0
		_ultimo_ms = ora_ms
		if dt <= 0.0 or dt > 0.5:
			dt = 1.0 / 60.0
		t += dt
		# il giro del giocatore
		var d := meta - _player.global_position
		d.y = 0.0
		if d.length() < 1.0:
			meta = Vector3(randf_range(-12, 12), 0, randf_range(-12, 12))
		else:
			_player.global_position += d.normalized() * 3.0 * dt
		# un gesto ogni tanto, dove si trova
		t_gesto -= dt
		if t_gesto <= 0.0:
			t_gesto = randf_range(1.2, 3.0)
			if perc != null:
				perc.call("accaduto", verbi[randi() % verbi.size()],
						_player.global_position, "")
		# chi e' vicino a Mochi (per il cancello della classe)
		for r in (_vis.get("_residents") as Array):
			var n := r.get("node") as Node3D
			if n == null or not is_instance_valid(n):
				continue
			if n.global_position.distance_to(_player.global_position) < 6.0:
				var nome := str((r.get("dna", {}) as Dictionary).get("name", ""))
				_vicinanza[nome] = float(_vicinanza.get(nome, 0.0)) + dt
		# IL RACCONTO, guidato. ⚠️ Il banco chiama `racconta` sulle stesse
		# coppie nei due rami: la REGOLA e' cio' che cambia, l'accoppiamento
		# no — e guidarlo uniformemente e' l'unico modo di avere un confronto
		# appaiato senza che i due villaggi divergano.
		t_camp -= dt
		if t_camp <= 0.0:
			t_camp = 0.5
			_racconto_guidato(t)


## ⚠️ L'ORACOLO CHE NON PUO' SBAGLIARE: la maschera VERA di B, prima e dopo.
## Se il racconto e' avvenuto e la maschera NON e' cambiata, B lo sapeva gia'
## — cioe' e' stata una ripetizione. Se e' cresciuta, era una notizia.
## Non si chiede al modello se ha ragione: si guarda cosa e' successo a B.
func _racconto_guidato(t: float) -> void:
	var residenti: Array = _vis.get("_residents")
	if residenti.size() < 2:
		return
	var ia := randi() % residenti.size()
	var ib := randi() % residenti.size()
	if ia == ib:
		return
	var ra: Dictionary = residenti[ia]
	var rb: Dictionary = residenti[ib]
	var na := ra.get("node") as Node3D
	var nb := rb.get("node") as Node3D
	if na == null or nb == null or not is_instance_valid(na) or not is_instance_valid(nb):
		return
	# si racconta a chi si ha accanto, come fa il villaggio
	if na.global_position.distance_to(nb.global_position) > 6.0:
		return
	var ida := int(ra.get("ecs", -1))
	var idb := int(rb.get("ecs", -1))
	if ida < 0 or idb < 0:
		return
	var prima := int(_cuore.call("debug_saputi_veri", idb))
	var esito := int(_cuore.call("racconta", ida, idb, 0.55))
	if esito < 0:
		_muti += 1
		return
	var dopo := int(_cuore.call("debug_saputi_veri", idb))
	_notizie.append(t)
	if dopo == prima:
		_ripetizioni += 1
	else:
		_nuove += 1
	# e il RITARDATARIO: A crede che B sappia un verbo che B NON sa piu'
	var cred: Dictionary = _cuore.call("debug_credenze", ida)
	for voce in (cred.get("voci", []) as Array):
		if int((voce as Dictionary).get("chi", -1)) != idb:
			continue
		var creduta := int((voce as Dictionary).get("saputi", 0))
		var fuori := creduta & ~dopo
		if fuori != 0:
			_fuori += _bit(fuori)
			var nome := str((rb.get("dna", {}) as Dictionary).get("name", ""))
			_per_nome[nome] = int(_per_nome.get(nome, 0)) + _bit(fuori)
	_campioni.append(t)


func _bit(m: int) -> int:
	var n := 0
	for v in 8:
		if (m & (1 << v)) != 0:
			n += 1
	return n


func _nome_di(id: int) -> String:
	for r in (_vis.get("_residents") as Array):
		if int(r.get("ecs", -1)) == id:
			return str((r.get("dna", {}) as Dictionary).get("name", ""))
	return "?"


func _referto(secondi: float, onni: bool) -> void:
	var raccontati := _ripetizioni + _nuove
	print("\n--- RACCONTI TENTATI: %d  (andati a segno %d, muti %d) ---" % [
			raccontati + _muti, raccontati, _muti])
	if raccontati == 0:
		print("GUASTO: nessun racconto e' mai andato a segno — il banco non misura niente")
		return
	print("  NOTIZIE (la maschera di B e' cresciuta) : %d" % _nuove)
	print("  RIPETIZIONI (B lo sapeva gia')          : %d  (%.1f%%)" % [
			_ripetizioni, 100.0 * float(_ripetizioni) / float(raccontati)])
	print("  verbi CREDUTI-ma-dimenticati            : %d" % _fuori)

	# ⚠️ LA CURVA SI STAMPA SEMPRE, ANCHE PER L'ONNISCIENZA. Senza, il
	# «declino» del modello non ha un termine di paragone — e ogni ricordo si
	# racconta UNA volta sola (`R_DETTO` e' globale), quindi lo stock di
	# notizie si svuota da solo anche senza credenze. Un cancello che non ha
	# il suo controllo accusa la regola di una cosa che fa il mondo.
	var q := secondi / 5.0
	var primo := 0
	var ultimo := 0
	for tt in _notizie:
		if float(tt) < q:
			primo += 1
		elif float(tt) >= secondi - q:
			ultimo += 1
	print("  racconti a segno — primo quinto: %d · ultimo: %d%s" % [primo, ultimo,
			("  (rapporto %.2f)" % (float(ultimo) / float(primo))) if primo > 0 else ""])

	if onni:
		print("\n=== TARATURA (onniscienza) ===")
		print("  la ridondanza DEVE essere 0, ed e' dimostrabile riga per riga.")
		print("  misurata: %d" % _ripetizioni)
		print("  %s" % ("OK: l'oracolo e' tarato" if _ripetizioni == 0
				else "⚠️ ORACOLO ROTTO: non e' il gioco, e' questo banco"))
		return

	print("\n=== CANCELLO 1: la SATURAZIONE ===")
	print("  (se le notizie al minuto nell'ultimo quinto scendono sotto la")
	print("   meta' del primo, il pettegolezzo si sta spegnendo — MA il")
	print("   confronto e' col ramo onnisciente, non con zero: ogni ricordo")
	print("   si racconta una volta sola, e lo stock si svuota da se')")
	if primo > 0:
		var r := float(ultimo) / float(primo)
		print("  rapporto %.2f — %s" % [r,
				"⚠️ CANCELLO: si sta spegnendo" if r < 0.5 else "passa"])

	print("\n=== CANCELLO 2: la CLASSE ===")
	print("  (se chi resta fuori e' sistematicamente il vicino piu' vicino a")
	print("   Mochi, la meccanica ha costruito una classifica → va TOLTA)")
	var righe: Array = []
	for nome in _per_nome:
		righe.append([str(nome), int(_per_nome[nome]), float(_vicinanza.get(nome, 0.0))])
	righe.sort_custom(func(x, y): return int(x[1]) > int(y[1]))
	if righe.is_empty():
		print("  nessun ritardatario in questa corsa")
		return
	print("  %-14s %8s %12s" % ["chi", "fuori", "s con Mochi"])
	for r in righe:
		print("  %-14s %8d %12.1f" % [r[0], r[1], r[2]])
	if righe.size() >= 4:
		var meta_n := int(righe.size() / 2)
		var alti := 0.0
		var bassi := 0.0
		for k in righe.size():
			if k < meta_n:
				alti += float(righe[k][2])
			else:
				bassi += float(righe[k][2])
		alti /= float(maxi(meta_n, 1))
		bassi /= float(maxi(righe.size() - meta_n, 1))
		print("  secondi medi con Mochi — chi resta fuori di piu': %.1f · di meno: %.1f" % [alti, bassi])
		print("  %s" % ("⚠️ CANCELLO: chi sta con Mochi resta fuori di piu'"
				if alti > bassi * 1.5 else "passa: nessuna classe evidente"))
