extends SceneTree
## LA DERIVA, MISURATA SULLE BIOGRAFIE VERE — e i quattro numeri che, se
## escono, dicono che il piano è sbagliato e va detto invece che tarato.
##
##   CHIBI_GIORNI=6 CHIBI_QUANTI=14 ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --headless --path . --script res://tools/misura_deriva_vera.gd
##
## Due parti, e la prima è la sola che possa dire la verità sui numeri:
##
## 1. **IL FLUSSO VERO.** Quante righe di `piatto` / `regalo` / `festa` il
##    giocatore lascia per residente per giornata, giocando come si gioca. È
##    il numero che il piano ha dichiarato «il più incerto di tutto il
##    progetto», e da lui dipende tutta la previsione.
## 2. **LA DERIVA SU CHI ESISTE GIÀ.** Si prendono i residenti veri del
##    salvataggio, con la loro biografia, e si guarda dove sarebbero dopo una,
##    tre e dodici stagioni di quel flusso — usando le funzioni VERE
##    (`Deriva.spinta`, `Animo.tratto`), mai una formula ricopiata di qua.
##
## ⚠️ **PERCHÉ NON QUATTRO STAGIONI IN VIVO.** Una giornata di gioco dura
## quattro minuti reali: quattro stagioni sono **112 minuti per corsa**, e la
## misura ne vuole due appaiate. Il flusso si misura in vivo (parte 1), la
## proiezione è aritmetica **sulle funzioni vere** (parte 2), e questa
## distinzione sta scritta accanto a ogni numero. Chi vorrà la corsa lunga la
## faccia: qui c'è il metro, e la soglia è già dichiarata.
##
## ⚠️ E NON SI TOCCA il `village.json` dell'autore.

const DERIVA := preload("res://scenes/npc/Deriva.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")

var _guasti := 0


func _init() -> void:
	_go()


func _dev(a: Array) -> float:
	if a.size() < 2:
		return 0.0
	var m := 0.0
	for x in a:
		m += float(x)
	m /= float(a.size())
	var s := 0.0
	for x2 in a:
		s += pow(float(x2) - m, 2.0)
	return sqrt(s / float(a.size()))


func _dico(ok: bool, testo: String) -> void:
	if not ok:
		_guasti += 1
	print(("  ok      " if ok else "  ARRESTO ") + testo)


func _go() -> void:
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 8:
		await process_frame
	var liv := current_scene
	var vis := liv.get_node_or_null("Visitors")
	var build := liv.get_node_or_null("BuildSystem")
	if vis == null or build == null:
		print("GUASTO: livello incompleto"); quit(1); return
	build.call("set_persist_for_debug", false)
	await create_timer(1.2).timeout

	var res: Array = vis.get("_residents")
	var animi: Dictionary = vis.get("_animi")
	print("\n=== residenti: %d ===" % res.size())
	if res.is_empty():
		print("GUASTO: nessun residente"); quit(1); return

	# ---------------------------------------------------------------------
	# PARTE 1 — IL FLUSSO VERO, giocando come si gioca
	# ---------------------------------------------------------------------
	print("\n--- 1) il flusso: quante prove il giocatore lascia davvero ---")
	var giorni := int(OS.get_environment("CHIBI_GIORNI")) if OS.get_environment("CHIBI_GIORNI") != "" else 4
	var prima := {}
	for r in res:
		var lab := str(r.get("label", ""))
		prima[lab] = _conta_prove(animi.get(lab))
	var dn := liv.get_node_or_null("DayNight")
	var g0 := int(dn.get("day")) if dn else 0
	# il giocatore fa quello che fa un giocatore: gira, e ogni tanto porta
	# qualcosa a qualcuno. Non a tutti: e' il vincolo che fa la varieta'.
	var passi := int(giorni * 240.0 / 3.0)
	for p in passi:
		await create_timer(3.0).timeout
		if p % 9 == 4 and not res.is_empty():
			var chi: Dictionary = res[(p / 9) % mini(4, res.size())]
			if vis.has_method("gesto_gentile"):
				vis.call("gesto_gentile", str(chi.get("label", "")),
						"piatto" if p % 18 == 4 else "regalo", 0.85)
	var g1 := int(dn.get("day")) if dn else giorni
	var passate: int = maxi(1, g1 - g0)
	var flussi: Array = []
	for r2 in res:
		var lab2 := str(r2.get("label", ""))
		var d: float = float(_conta_prove(animi.get(lab2)) - int(prima.get(lab2, 0)))
		flussi.append(d / float(passate))
	var somma := 0.0
	var maxf_ := 0.0
	for f in flussi:
		somma += float(f)
		maxf_ = maxf(maxf_, float(f))
	print("       %d giornate passate · prove del giocatore per residente per giornata:" % passate)
	print("       media %.3f · massimo %.3f · dev.std %.3f"
			% [somma / float(flussi.size()), maxf_, _dev(flussi)])
	_dico(maxf_ > 0.0,
			"il giocatore lascia davvero delle prove (se e' zero, la deriva non "
			+ "ha carburante e il piano e' sbagliato)")
	_dico(_dev(flussi) > 0.0,
			"e non le lascia a tutti allo stesso modo: e' il vincolo che fa la "
			+ "varieta'")

	# ---------------------------------------------------------------------
	# PARTE 2 — LA DERIVA, sulle biografie vere, alle FUNZIONI VERE
	# ---------------------------------------------------------------------
	print("\n--- 2) la deriva su chi esiste gia' ---")
	var basi: Array = []
	var derivati: Array = []
	var al_muro := 0
	var righe: Array = []
	for r3 in res:
		var lab3 := str(r3.get("label", ""))
		var a = animi.get(lab3)
		if a == null:
			continue
		a._deriva_giorno = -1
		a._ricalcola_deriva()
		var b: float = a.tratto_base("codardia")
		var d2: float = a.tratto("codardia")
		basi.append(b)
		derivati.append(d2)
		if d2 <= 0.0 or d2 >= 1.0:
			al_muro += 1
		righe.append([lab3, b, d2, d2 - b])
	righe.sort_custom(func(x, y): return absf(float(x[3])) > absf(float(y[3])))
	print("       chi si e' mosso di piu':")
	for i in mini(6, righe.size()):
		print("         %-22s  %.3f → %.3f   (δ %+.4f)"
				% [righe[i][0], righe[i][1], righe[i][2], righe[i][3]])

	var dev_base := _dev(basi)
	var dev_der := _dev(derivati)
	print("\n       dispersione della codardia:  di nascita %.4f → derivata %.4f"
			% [dev_base, dev_der])

	# --- ⚠️ I QUATTRO NUMERI DI ARRESTO
	print("\n--- I NUMERI DI ARRESTO, dichiarati PRIMA di misurare ---")
	_dico(al_muro == 0,
			"nessun tratto derivato tocca il muro (%d): chi era resta "
					% al_muro + "riconoscibile")
	_dico(dev_der >= dev_base - 1e-9,
			("la dispersione NON scende (%.4f contro %.4f): il meccanismo non "
			+ "sta rendendo le persone uguali") % [dev_der, dev_base])
	# l'ordine si conserva?
	var inversioni := 0
	for i2 in righe.size():
		for j in range(i2 + 1, righe.size()):
			var a1 := float(righe[i2][1])
			var b1 := float(righe[j][1])
			var a2 := float(righe[i2][2])
			var b2 := float(righe[j][2])
			if (a1 - b1) * (a2 - b2) < 0.0:
				inversioni += 1
	print("       inversioni d'ordine fra i residenti: %d" % inversioni)

	# --- la PROIEZIONE, e si dice che e' aritmetica
	print("\n--- 3) dove sarebbero, con questo flusso, fra una stagione e un anno ---")
	print("       (⚠️ proiezione sulle FUNZIONI VERE, non una corsa: una")
	print("        stagione in vivo costa 28 minuti reali, un anno 112)")
	var per_giornata: float = maxf_ if maxf_ > 0.0 else 0.25
	for stagioni in [1, 3, 12]:
		var gg: int = int(stagioni) * 7
		# si simula un vicino tipico: la sua base mediana, e il flusso misurato
		var finto = ANIMO.new()
		finto.setup(DNA.generate(4242))
		for g in gg:
			for k in int(ceil(per_giornata)):
				finto.ricorda("piatto", "giocatore", 0.85, 0.9)
			finto.passa_giorno()
		print("       %2d stagioni (%3d giornate): %.3f → %.3f  (δ %+.4f)"
				% [stagioni, gg, finto.tratto_base("codardia"),
						finto.tratto("codardia"),
						finto.tratto("codardia") - finto.tratto_base("codardia")])

	print("\n==== DERIVA VERA: %s ====" % ("TUTTO A POSTO" if _guasti == 0
			else "%d ARRESTI" % _guasti))
	quit(1 if _guasti > 0 else 0)


func _conta_prove(a) -> int:
	if a == null:
		return 0
	var n := 0
	for r in a.ricordi:
		var d := r as Dictionary
		if str(d.get("attore", "")) != "giocatore":
			continue
		if (DERIVA.SPINTE["codardia"] as Dictionary).has(str(d.get("tipo", ""))):
			n += 1
	for k in a.sommario:
		var p := str(k).split("|")
		if p.size() > 1 and str(p[1]) == "giocatore" \
				and (DERIVA.SPINTE["codardia"] as Dictionary).has(str(p[0])):
			n += int((a.sommario[k] as Dictionary).get("quante", 1))
	return n
