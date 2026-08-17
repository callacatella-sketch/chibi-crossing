extends SceneTree
## IL METRO DEL CAMMINO — quanto spesso il corpo attraversa un muro, e
## quanto sbanda negli angoli.
##
##   Godot --headless --path . --script res://tools/misura_cammino.gd
##
## Serve a due domande che nessuna asserzione booleana sa fare, e che si
## rispondono solo con un NUMERO prima e un numero dopo:
##
##   1. su mille viaggi veri, in quanti il corpo è passato attraverso un
##      muro? (e di quanto? e in che tratta — la prima, l'ultima, in mezzo?)
##   2. negli angoli, di quanti gradi il corpo si sposta in una direzione
##      diversa da quella in cui guarda, per quanto tempo, e con il ciclo
##      del passo acceso quanto?
##
## ## L'ORACOLO È INDIPENDENTE, e non è un dettaglio
##
## Il controllo NON passa da `Varchi`: se il giudice fosse la stessa
## funzione che decide la strada, misurerebbe la propria coerenza invece
## della verità. Qui i muri si trasformano nei **segmenti veri** che
## occupano sul confine fra due celle (`_segmenti`), e ogni spostamento di
## un frame è un segmento a sua volta: la domanda è se i due si tagliano.
## Aritmetica di orientamento, niente campionamento, nessuna cella di
## mezzo.
##
## E si guarda il MOVIMENTO DI OGNI FRAME, non la traiettoria campionata:
## un corpo che entra e esce da un muro fra due campioni non lascia
## traccia, ed è esattamente il caso che si vuole contare.

const VARCHI := preload("res://scenes/build/Varchi.gd")
const VISITOR := preload("res://scenes/npc/Visitor.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")
const BUILD := preload("res://scenes/build/BuildSystem.gd")

const DT := 1.0 / 60.0
const SECONDI_MAX := 40.0
## Quanti viaggi per banco. Mille è il punto in cui la percentuale smette
## di ballare fra due semi diversi (verificato: ±0.4 punti).
const VIAGGI := 1000


func _init() -> void:
	_go()


func _go() -> void:
	await process_frame
	var muri := _villaggio()
	print("=== IL METRO DEL CAMMINO ===")
	print("villaggio di prova: %d bordi murati" % muri.size())
	var esito := _banco(muri, 20260810)
	_stampa(esito)
	# la controprova: senza muri niente deve cambiare, e nessuno deve
	# poter attraversare qualcosa che non c'è
	print("")
	var libero := _banco({}, 20260810)
	print("--- prato aperto (controprova: il cammino DRITTO) ---")
	print("  viaggi                 : %d" % libero["viaggi"])
	print("  non arrivati           : %d" % libero["non_arrivati"])
	print("  sbandate (>20 gradi)   : %d" % libero["spigoli"])
	print("  deriva max media       : %.1f gradi" % libero["deriva_media"])
	print("  metri per viaggio      : %.2f" % libero["metri_medi"])
	print("  secondi per viaggio    : %.2f" % libero["secondi_medi"])
	# e l'AVVIO: chi era rivolto altrove e si sente dire «vai là»
	print("")
	var avvio := _banco({}, 20260810, false)
	print("--- l'AVVIO (muso a zero, meta dove capita) ---")
	print("  deriva max media       : %.1f gradi" % avvio["deriva_media"])
	print("  durata peggiore        : %.2f s" % avvio["durata_peggiore"])
	print("  scivolata per viaggio  : %.3f m col passo acceso" % avvio["scivolata_pesata"])
	print("  blend del passo mentre sbanda: %.2f" % avvio["blend_alla_deriva"])
	print("  secondi per viaggio    : %.2f" % avvio["secondi_medi"])
	quit(0)


# ------------------------------------------------------------- il villaggio

## Una geometria da villaggio VERO, non un caso di scuola: una casa con la
## porta (il posto in cui i vicini entrano ed escono ogni giorno) e due
## staccionate lunghe. Sono le tre forme che il giocatore costruisce
## davvero, e sono anche le tre che rasentano gli spigoli.
func _villaggio() -> Dictionary:
	var muri := {}
	# la casa 3x3, murata tutt'attorno, con la porta a sud della cella (6,5)
	for x in range(5, 8):
		for z in range(5, 8):
			for d: Vector2i in VARCHI.INTORNO:
				var n := Vector2i(x, z) + d
				if n.x >= 5 and n.x <= 7 and n.y >= 5 and n.y <= 7:
					continue
				muri[VARCHI.bordo_fra(Vector2i(x, z), n)] = true
	muri.erase(VARCHI.bordo_fra(Vector2i(6, 5), Vector2i(6, 4)))
	# una staccionata verticale fra le colonne 9 e 10, da z=3 a z=8
	for z in range(3, 9):
		muri[VARCHI.bordo_fra(Vector2i(9, z), Vector2i(10, z))] = true
	# e una orizzontale fra le righe 1 e 2, da x=2 a x=8
	for x in range(2, 9):
		muri[VARCHI.bordo_fra(Vector2i(x, 1), Vector2i(x, 2))] = true
	return muri


# --------------------------------------------------------------- l'oracolo

## I muri come SEGMENTI di mondo: il confine fra due celle è un metro di
## retta, e sta sui mezzi interi. È l'unica traduzione che serve, e non
## passa da nessuna funzione di `Varchi`.
func _segmenti(muri: Dictionary) -> Array:
	var fuori := []
	for k: Vector2i in muri:
		if posmod(k.y, 2) == 1:
			@warning_ignore("integer_division")
			var cy := (k.y - 1) / 2
			@warning_ignore("integer_division")
			var cx := k.x / 2
			fuori.append([Vector2(cx - 0.5, cy + 0.5), Vector2(cx + 0.5, cy + 0.5)])
		else:
			@warning_ignore("integer_division")
			var cx2 := (k.x - 1) / 2
			@warning_ignore("integer_division")
			var cy2 := k.y / 2
			fuori.append([Vector2(cx2 + 0.5, cy2 - 0.5), Vector2(cx2 + 0.5, cy2 + 0.5)])
	return fuori


static func _cross(o: Vector2, a: Vector2, b: Vector2) -> float:
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)


## I due segmenti si tagliano DAVVERO (non si sfiorano a un capo)? Il
## rasente lo spigolo è lecito nel modello — è il passaggio, non il
## guasto — quindi conta solo l'attraversamento vero e proprio.
static func _taglia(p0: Vector2, p1: Vector2, q0: Vector2, q1: Vector2) -> bool:
	var e := 1e-9
	var d1 := _cross(q0, q1, p0)
	var d2 := _cross(q0, q1, p1)
	var d3 := _cross(p0, p1, q0)
	var d4 := _cross(p0, p1, q1)
	if absf(d1) < e or absf(d2) < e or absf(d3) < e or absf(d4) < e:
		return false
	return (d1 > 0.0) != (d2 > 0.0) and (d3 > 0.0) != (d4 > 0.0)


# ------------------------------------------------------------------ il banco

## L'usciere: il BuildSystem VERO risponde alle domande, ma non va messo
## in scena (il suo `_ready` caricherebbe il village.json dell'utente).
## In scena ci va questo, che sta nel gruppo e gli passa le domande.
class _Usciere:
	extends Node
	var vero: Node3D

	func _ready() -> void:
		add_to_group("build_system")

	func deviazione(da: Vector3, a: Vector3) -> Array[Vector3]:
		var tappe: Array[Vector3] = vero.deviazione(da, a)
		return tappe

	## IL TURNO È SEMPRE APERTO QUI. Questo banco fa mille viaggi dentro un
	## solo frame del motore: col turno acceso, il contatore dei frame non
	## avanzerebbe mai, e da un certo punto in poi nessun viaggio avrebbe
	## più una strada — la misura racconterebbe un gioco che non esiste.
	func turno_rotte_libero() -> bool:
		return true


func _banco(muri: Dictionary, seme: int, allinea := true) -> Dictionary:
	var segs := _segmenti(muri)
	var bs = BUILD.new()
	bs.set("_muri_cache", muri)
	bs.set("_varchi_sporchi", false)
	var usciere := _Usciere.new()
	usciere.vero = bs
	root.add_child(usciere)
	var rng := RandomNumberGenerator.new()
	rng.seed = seme

	var sfondati := 0
	var sfondati_prima := 0
	var sfondati_ultima := 0
	var non_arrivati := 0
	var con_rotta := 0
	var metri := 0.0
	var deriva_max_tot := 0.0
	var deriva_peggiore := 0.0
	var scivolata_peggiore := 0.0
	var scivolata_grezza_peggiore := 0.0
	var durata_peggiore := 0.0
	var blend_alla_deriva := 0.0
	var spigoli := 0
	var fatti := 0
	var secondi := 0.0
	var costo_us := 0.0
	var scivolata_tot := 0.0
	var scivolata_pesata := 0.0
	# DA DOVE VIENE LA SVOLTA SECCA: dalla prima tappa (che può stare
	# dietro le spalle — è il centro della propria cella, quando per uscire
	# bisogna prima tornare in mezzo) o da un tornante in mezzo alla strada?
	var svolte_avvio := 0
	var svolte_strada := 0
	# QUANTO SFIORA IL PALO. Un muro non è una retta senza spessore: la
	# Staccionata chiude i correnti con una pallina di raggio 0.030 centrata
	# sullo SPIGOLO, in mezzo alla fascia in cui cammina un chibi. Passare a
	# due centimetri dallo spigolo, nel grafo, è lecito; addosso a un corpo
	# è dentro il legno. Qui si misura la distanza vera fra la traiettoria e
	# i capi dei muri.
	var pali: Array[Vector2] = []
	for s2 in segs:
		pali.append(s2[0])
		pali.append(s2[1])
	var palo_piu_vicino := 99.0
	var frames_addosso := 0

	while fatti < VIAGGI:
		var da := Vector3(rng.randf_range(0.5, 12.5), 0, rng.randf_range(0.5, 12.5))
		var a := Vector3(rng.randf_range(0.5, 12.5), 0, rng.randf_range(0.5, 12.5))
		if da.distance_to(a) < 2.0:
			continue
		fatti += 1
		var v = VISITOR.new()
		v.set("species", "chibi")
		v.dna = DNA.generate(4242)
		root.add_child(v)
		v.set_process(false)
		v.position = da
		var orologio := Time.get_ticks_usec()
		v.call("_walk_to", a, "r_idle")
		costo_us += float(Time.get_ticks_usec() - orologio)
		var tappe: Array = v.get("_tappe")
		if not tappe.is_empty():
			con_rotta += 1
		var n_tappe := tappe.size()
		# gli angoli della spezzata, uno per uno
		var spezzata: Array[Vector3] = [da, v.get("_target")]
		for p3: Vector3 in tappe:
			spezzata.append(p3)
		for k in range(1, spezzata.size() - 1):
			var u1 := Vector2(spezzata[k].x - spezzata[k - 1].x,
					spezzata[k].z - spezzata[k - 1].z)
			var u2 := Vector2(spezzata[k + 1].x - spezzata[k].x,
					spezzata[k + 1].z - spezzata[k].z)
			if u1.length() > 1e-6 and u2.length() > 1e-6 \
					and absf(rad_to_deg(u1.angle_to(u2))) > 120.0:
				svolte_strada += 1
		if n_tappe > 0:
			var u0 := Vector2(a.x - da.x, a.z - da.z)
			var up := Vector2((v.get("_target") as Vector3).x - da.x,
					(v.get("_target") as Vector3).z - da.z)
			if u0.length() > 1e-6 and up.length() > 1e-6 \
					and absf(rad_to_deg(u0.angle_to(up))) > 120.0:
				svolte_avvio += 1
		# SI PARTE GIÀ RIVOLTI dove si va: senza, ogni viaggio comincia con
		# una giravolta (il muso è a zero e la meta è dove capita) e la
		# sbandata dell'avvio coprirebbe quella degli ANGOLI, che è la cosa
		# da misurare. L'avvio ha il suo banco a parte.
		if allinea:
			var t0: Vector3 = v.get("_target")
			var q: Vector3 = t0 - (v.position as Vector3)
			v.set("_yaw", atan2(-q.x, -q.z))

		var prev: Vector3 = v.position
		var percorsi := 0.0
		var rotto := false
		var rotto_prima := false
		var rotto_ultima := false
		var deriva_max := 0.0
		var deriva_ora := 0.0
		var durata_ora := 0.0
		var scivolata_ora := 0.0
		var scivolata_ora_grezza := 0.0
		var frames := int(SECONDI_MAX / DT)
		for _f in frames:
			var restavano: int = (v.get("_tappe") as Array).size()
			v._process(DT)
			var ora: Vector3 = v.position
			var d := Vector2(ora.x - prev.x, ora.z - prev.z)
			percorsi += d.length()
			if d.length() > 1e-7:
				for s in segs:
					if _taglia(Vector2(prev.x, prev.z), Vector2(ora.x, ora.z), s[0], s[1]):
						rotto = true
						if restavano == n_tappe:
							rotto_prima = true
						elif restavano == 0:
							rotto_ultima = true
						break
				# LA SCIVOLATA COL PASSO ACCESO. È IL numero: un corpo che
				# trasla di lato con le zampe ferme sta pernando (giusto);
				# uno che lo fa col ciclo del passo a cadenza piena è un
				# carrello elevatore. Quindi si pesa col blend.
				var yaw: float = v.get("_yaw")
				var muso := Vector2(-sin(yaw), -cos(yaw))
				var ang := absf(rad_to_deg(d.normalized().angle_to(muso)))
				var lat := absf(d.x * muso.y - d.y * muso.x)
				var bl := 0.0
				var an = v.get("_andatura")
				if an != null:
					bl = float(an.get("blend"))
				for pl: Vector2 in pali:
					var vicino := Geometry2D.get_closest_point_to_segment(pl,
							Vector2(prev.x, prev.z), Vector2(ora.x, ora.z))
					var dd := vicino.distance_to(pl)
					if dd < palo_piu_vicino:
						palo_piu_vicino = dd
					if dd < 0.05:
						frames_addosso += 1
						break
				scivolata_tot += lat
				scivolata_pesata += lat * bl
				deriva_max = maxf(deriva_max, ang)
				if ang > 20.0:
					deriva_ora = maxf(deriva_ora, ang)
					durata_ora += DT
					scivolata_ora += lat * bl
					scivolata_ora_grezza += lat
					blend_alla_deriva = maxf(blend_alla_deriva, bl)
				else:
					if durata_ora > durata_peggiore:
						durata_peggiore = durata_ora
					if deriva_ora > deriva_peggiore:
						deriva_peggiore = deriva_ora
					if scivolata_ora > scivolata_peggiore:
						scivolata_peggiore = scivolata_ora
					if scivolata_ora_grezza > scivolata_grezza_peggiore:
						scivolata_grezza_peggiore = scivolata_ora_grezza
					if deriva_ora > 0.0:
						spigoli += 1
					deriva_ora = 0.0
					durata_ora = 0.0
					scivolata_ora = 0.0
			prev = ora
			secondi += DT
			if str(v.get("_state")) != "walk":
				break
		# la sbandata che finisce col viaggio va contata lo stesso
		if deriva_ora > 0.0:
			spigoli += 1
			durata_peggiore = maxf(durata_peggiore, durata_ora)
			deriva_peggiore = maxf(deriva_peggiore, deriva_ora)
			scivolata_peggiore = maxf(scivolata_peggiore, scivolata_ora)
			scivolata_grezza_peggiore = maxf(scivolata_grezza_peggiore, scivolata_ora_grezza)
		if str(v.get("_state")) == "walk":
			non_arrivati += 1
		if rotto:
			sfondati += 1
			if rotto_prima:
				sfondati_prima += 1
			if rotto_ultima:
				sfondati_ultima += 1
		metri += percorsi
		deriva_max_tot += deriva_max
		v.free()
	usciere.free()
	bs.free()
	return {
		"viaggi": fatti, "sfondati": sfondati, "sfondati_prima": sfondati_prima,
		"sfondati_ultima": sfondati_ultima, "non_arrivati": non_arrivati,
		"con_rotta": con_rotta, "metri_medi": metri / float(fatti),
		"deriva_media": deriva_max_tot / float(fatti),
		"deriva_peggiore": deriva_peggiore, "scivolata_peggiore": scivolata_peggiore,
		"scivolata_grezza_peggiore": scivolata_grezza_peggiore,
		"durata_peggiore": durata_peggiore, "blend_alla_deriva": blend_alla_deriva,
		"spigoli": spigoli, "secondi_medi": secondi / float(fatti),
		"svolte_avvio": svolte_avvio, "svolte_strada": svolte_strada,
		"costo_us": costo_us / float(fatti),
		"palo_piu_vicino": palo_piu_vicino, "frames_addosso": frames_addosso,
		"scivolata_tot": scivolata_tot / float(fatti),
		"scivolata_pesata": scivolata_pesata / float(fatti),
	}


func _stampa(e: Dictionary) -> void:
	print("--- villaggio con muri ---")
	print("  viaggi                 : %d (di cui %d con una rotta da seguire)"
			% [e["viaggi"], e["con_rotta"]])
	print("  ATTRAVERSANO UN MURO   : %d  (%.1f%%)"
			% [e["sfondati"], 100.0 * float(e["sfondati"]) / float(e["viaggi"])])
	print("     di cui nella PRIMA tratta : %d" % e["sfondati_prima"])
	print("     di cui nell'ULTIMA tratta : %d" % e["sfondati_ultima"])
	print("  non arrivati           : %d" % e["non_arrivati"])
	print("  metri per viaggio      : %.2f" % e["metri_medi"])
	print("  secondi per viaggio    : %.2f" % e["secondi_medi"])
	print("  --- il moonwalk ---")
	print("  sbandate (>20 gradi)   : %d in %d viaggi" % [e["spigoli"], e["viaggi"]])
	print("  deriva max media       : %.1f gradi" % e["deriva_media"])
	print("  deriva peggiore        : %.1f gradi" % e["deriva_peggiore"])
	print("  durata peggiore        : %.2f s" % e["durata_peggiore"])
	print("  sbandata peggiore      : %.3f m grezza, %.3f m col passo acceso"
			% [e["scivolata_grezza_peggiore"], e["scivolata_peggiore"]])
	print("  SCIVOLATA PER VIAGGIO  : %.3f m grezza, %.3f m COL PASSO ACCESO"
			% [e["scivolata_tot"], e["scivolata_pesata"]])
	print("  svolte oltre 120 gradi : %d all'AVVIO, %d in mezzo alla strada"
			% [e["svolte_avvio"], e["svolte_strada"]])
	print("  costo di _walk_to      : %.0f us in media (rotta compresa)" % e["costo_us"])
	print("  --- il palo ---")
	print("  piu' vicino a un capo di muro: %.3f m" % e["palo_piu_vicino"])
	print("  frames a meno di 5 cm dal palo: %d" % e["frames_addosso"])
