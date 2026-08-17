extends SceneTree
## IL METRO DELL'ATTRIBUZIONE — la ricevuta della deduzione si può LEGGERE?
##
##   Godot --headless --path . --script res://tools/misura_attribuzione.gd
##
## La Fase 5 ha una regola che sta sopra tutte: «una conseguenza che il
## giocatore non sa attribuire non attenua l'effetto, LO INVERTE». La
## ricevuta esiste per rendere attribuibile quello che viene dopo — il vicino
## gira la testa verso il posto che l'ha fatto pensare, e poi si muove.
##
## Nessuna asserzione booleana sa dire se quella scena si legge. Queste sono
## le quattro domande che la decidono, e questo banco le misura tutte e
## quattro nel MainLevel VERO, **senza nessun `.gguf`**:
##
##  1. **il giocatore c'era?** La ricevuta è una testa che si gira: se Mochi
##     è dall'altra parte del villaggio, o in modalità costruzione, quella
##     testa non la vede nessuno e resta solo la conseguenza.
##  2. **si capisce COSA guarda?** Uno sguardo è una DIREZIONE, non un
##     punto: se l'ancora è a cinquanta metri, il raggio passa sopra mezzo
##     villaggio e non indica niente.
##  3. **la conseguenza va DOVE ha guardato?** Se il corpo parte dall'altra
##     parte, il giocatore vede un'occhiata di qua e un viaggio di là.
##  4. **e quante ne sopravvivono?** Perché il degrado di questo progetto è
##     il silenzio, ma un canale che tace sempre è un canale morto.
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ IL CENSIMENTO NON HA BISOGNO DEL MODELLO
## ────────────────────────────────────────────────────────────────────────
##
## Quello che un modello può scrivere è un insieme FINITO e lo genera il
## gioco: `Suggeritore.grammatica_deduzione` ammette un obiettivo fra quelli
## che il mondo può servire adesso, e da uno a tre indici fra le righe vive
## del grafo di quel vicino. Quarantuno sottoinsiemi con sei ricordi, per
## quattro obiettivi. **Enumerarli tutti è più onesto che campionarne
## ottantaquattro con un modello**: la geometria non dipende da quale il
## modello sceglie, e la distribuzione su tutto lo spazio non ha un dado
## dentro.
##
## Quello che il censimento NON dice è quanto spesso il modello sceglie una
## certa forma. Per quello c'è `tools/prova_pensieri.gd`, che ne prova
## qualcuna col modello vero.
##
## ⚠️ **IL MONDO È VERO, e non è un dettaglio.** I ricordi nascono da
## `Percezione.accaduto` vero (quindi solo in chi poteva vedere), i luoghi da
## `Visitors._luoghi_del_piano` vero (quindi il cespuglio è quello vero, e la
## panchina quella che il vicino sceglierebbe davvero), la meta dal
## risolutore vero. Un banco con posizioni scritte a mano misurerebbe la
## geometria che gli ho dato io.

const FOGLIO := preload("res://scenes/npc/FoglioDelVicino.gd")
const SUG := preload("res://scenes/npc/Suggeritore.gd")
const PIANI := preload("res://scenes/npc/Piani.gd")
const DED := preload("res://scenes/npc/Deduzioni.gd")
const PERCEZIONE := preload("res://scenes/npc/Percezione.gd")

## `Visitors.AMMIRA_SOGLIA`: sotto questo peso il villaggio ha già deciso,
## in tre posti, che un ricordo non conta più.
const SOGLIA := 0.35

## LE CASE. Sparse apposta: un villaggio in cui tutti hanno visto tutto è il
## caso più facile, e la distanza fra un vicino e il posto che guarda
## uscirebbe piccola per costruzione.
##
## ⚠️ Le celle si provano UNA PER UNA: `place_cell` rifiuta in silenzio nel
## letto del fiume e `debug_settle` su una cella rifiutata non insedia
## nessuno. Il banco conta i letti e si ferma.
const CASE := [
	Vector2i(2, 4), Vector2i(14, 4), Vector2i(4, 15), Vector2i(12, 12),
	Vector2i(8, 2), Vector2i(16, 10), Vector2i(2, 12), Vector2i(10, 17),
]

## I POSTI del villaggio: quello che i quattro provvedimenti vanno a cercare.
## Ce ne sono più d'uno per tipo apposta — con un cespuglio solo, «il
## cespuglio più vicino» è sempre lo stesso e la meta non varia mai.
const CIBI := [Vector2i(6, 9), Vector2i(15, 15), Vector2i(1, 8)]
const PANCHE := [Vector2i(9, 6), Vector2i(3, 17), Vector2i(17, 5)]

## IL GIRO DI MOCHI: dove passa e cosa fa. Sono i gesti veri del ciclo di
## gioco, nei posti veri del villaggio — qualcuno addosso a un cespuglio,
## qualcuno in mezzo al prato, qualcuno davanti a una panchina.
const GIRO := [
	["annaffia", Vector2i(6, 9)], ["costruisce", Vector2i(9, 6)],
	["semina", Vector2i(3, 6)], ["raccoglie", Vector2i(13, 6)],
	["annaffia", Vector2i(5, 13)], ["costruisce", Vector2i(11, 14)],
	["taglia", Vector2i(15, 12)], ["pesca", Vector2i(1, 8)],
	["cucina", Vector2i(8, 16)], ["costruisce", Vector2i(17, 6)],
	["semina", Vector2i(3, 16)], ["annaffia", Vector2i(15, 15)],
]

var _vis: Node = null
var _build: Node = null
var _dn: Node = null
var _player: Node3D = null
var _cuore: Object = null


func _init() -> void:
	_go()


func _m(c: Vector2i) -> Vector3:
	return Vector3(c.x, 0.0, c.y)


# =========================================================================
# LA STATISTICA — mediana e coda, non media
# =========================================================================

## LA MEDIA NON DESCRIVE UNA DISTRIBUZIONE CON UNA CODA LUNGA. Qui la coda è
## tutto: il caso che rovina la scena è quello a cinquanta metri, e in una
## media con ottanta campioni scompare.
func _riepilogo(nome: String, v: Array, unita := "m") -> String:
	if v.is_empty():
		return "  %-34s (nessun campione)" % nome
	var s := v.duplicate()
	s.sort()
	var n := s.size()
	var med: float = float(s[n / 2]) if n % 2 == 1 \
			else (float(s[n / 2 - 1]) + float(s[n / 2])) * 0.5
	return "  %-34s n=%-5d mediana %6.2f %s · p90 %6.2f · max %6.2f" % [
			nome, n, med, unita, float(s[mini(n - 1, int(n * 0.9))]), float(s[n - 1])]


func _quota(nome: String, quanti: int, su: int) -> String:
	return "  %-34s %d su %d (%.0f%%)" % [nome, quanti, su,
			100.0 * float(quanti) / maxf(float(su), 1.0)]


# =========================================================================
# IL MONDO
# =========================================================================

func _go() -> void:
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 8:
		await process_frame
	var livello := current_scene
	if livello == null:
		print("GUASTO: il MainLevel non si è caricato")
		quit(1)
		return
	_build = livello.get_node_or_null("BuildSystem")
	_vis = livello.get_node_or_null("Visitors")
	_dn = livello.get_node_or_null("DayNight")
	_player = livello.get_node_or_null("Player") as Node3D
	if _build == null or _vis == null or _player == null:
		print("GUASTO: BuildSystem=%s Visitors=%s Player=%s" % [_build, _vis, _player])
		quit(1)
		return
	_build.call("set_persist_for_debug", false)
	# L'OROLOGIO SI FERMA: un giorno dura quattro minuti e questo banco
	# parecchi. Senza, a metà prova i vicini vanno a dormire, rientrano in
	# casa e il censimento misura un villaggio vuoto.
	if _dn != null:
		_dn.set("cycle_seconds", 1000000.0)
		_dn.set("time", 0.42)
	await create_timer(1.2).timeout

	_vis.call("debug_reset")
	var posati := 0
	for c in CASE:
		_build.call("place_cell", c, "Letto", 0, false)
		_build.call("place_cell", c, "Tetto", 0, false)
		if (_build.call("get_placed_by_name", "Letto") as Array).size() > posati:
			posati += 1
	for c in CIBI:
		_build.call("place_cell", c, "Cespuglio", 0, false)
	for c in PANCHE:
		_build.call("place_cell", c, "Panchina", 0, false)
	_build.call("aggiorna_varchi_ora")
	print("letti posati: %d su %d" % [posati, CASE.size()])
	if posati < CASE.size():
		print("GUASTO: qualche cella è stata rifiutata (letto del fiume?)")

	var seme := 1000
	for c in CASE:
		_vis.call("debug_settle", seme, c)
		seme += 137
		await create_timer(0.5).timeout
	var residenti: Array = _vis.get("_residents")
	print("residenti insediati: %d" % residenti.size())
	if residenti.is_empty():
		quit(1)
		return
	_cuore = _vis.call("cuore")
	if _cuore == null:
		print("GUASTO: nessun cuore ECS (GDExtension non caricata?)")
		quit(1)
		return

	# ------------------------------------------------------------------
	# IL GIRO DI MOCHI. I gesti veri, dai posti veri, col bus vero: chi
	# non poteva vedere non si ricorda niente, ed è quello che deve
	# succedere.
	# ------------------------------------------------------------------
	for passo in GIRO:
		var dove := _m(passo[1] as Vector2i)
		_player.global_position = Vector3(dove.x, _player.global_position.y, dove.z)
		await process_frame
		call_group("percezione", "accaduto", str(passo[0]), dove, "")
		# un po' di tempo fra un gesto e l'altro: i ricordi devono avere ETÀ
		# diverse, o il «più pesante» sarebbe sempre l'ultimo per costruzione
		await create_timer(1.1).timeout

	# i luoghi e i fatti si rinfrescano da soli ogni FATTI_OGNI frame: si
	# aspetta un giro abbondante, o metà censimento leggerebbe `luoghi` vuoti
	await create_timer(2.5).timeout

	_censimento(residenti)
	await _le_ricevute(residenti)
	await _la_vita(residenti)
	quit(0)


# =========================================================================
# LE RICEVUTE VERE — la regola di prima e quella di adesso, APPAIATE
# =========================================================================

## ⚠️ **DUE REGOLE, UNA SOLA CORSA, LE STESSE DEDUZIONI.** Confrontare due
## corse diverse vorrebbe dire confrontare due villaggi (i vicini camminano,
## i ricordi si raffreddano, l'agenda tira i suoi dadi): la differenza che si
## misurerebbe non sarebbe della regola. Qui le due regole guardano lo STESSO
## istante dello STESSO vicino con la STESSA deduzione nel grafo, e la sola
## cosa che cambia è la domanda che si fanno.
##
##  · **prima**  — `puo_vedere(node, node.global_position, 1.0)`: la distanza
##    è zero per costruzione, e l'ancora è il perché più pesante senza
##    filtro. È la riga che c'era, ricostruita qui per poterla misurare;
##  · **adesso** — `Deduzioni.consegna` vera, con l'occhio di Mochi, il
##    raggio vero e l'apertura vera.
##
## Si registra il PRIMO istante in cui ciascuna avrebbe pagato, e con quale
## geometria. La regola di adesso paga davvero (è il codice di produzione);
## quella di prima si valuta e basta — pagarla due volte falserebbe l'altra.
const RICEVUTE_ATTESA := 90.0

func _le_ricevute(residenti: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var casi := []
	for r in residenti:
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var rit: Dictionary = FOGLIO.ritratto(_vis, _dn, _cuore, r, "pensiero", "Mochi")
		if rit.is_empty():
			continue
		var citabili: Array = SUG.fatti(rit)
		var offerti: Array = SUG.obiettivi_deducibili(rit)
		if citabili.is_empty() or offerti.is_empty():
			continue
		# una bozza come la scriverebbe un modello: un obiettivo fra quelli
		# offerti, da uno a tre indici fra le righe vive
		var indici := PackedInt32Array()
		var quanti := 1 + (rng.randi() % mini(3, citabili.size()))
		for k in quanti:
			indici.append(int((citabili[k] as Dictionary)["riga"]))
		var nome := str(offerti[rng.randi() % offerti.size()])
		var i := int(_cuore.call("deduci", int(r["ecs"]),
				int(_cuore.call("maschera_obiettivo", nome)), indici, SOGLIA))
		if i < 0:
			continue
		casi.append({"r": r, "node": node, "id": int(r["ecs"]), "i": i, "ob": nome,
				"prima": {}, "adesso": {}})
	print("\n" + "█".repeat(72))
	print("LE RICEVUTE — la regola di prima e quella di adesso, sulle stesse deduzioni")
	print("█".repeat(72))
	print("  deduzioni messe nel grafo: %d" % casi.size())

	# ⚠️ **E MOCHI GIRA**, con lo stesso modello dichiarato di `_la_vita`: una
	# ricevuta che aspetta il giocatore va misurata con un giocatore che si
	# muove, o si sta misurando un villaggio in cui nessuno gioca.
	var t := 0.0
	while t < RICEVUTE_ATTESA:
		_passo_mochi(rng)
		for c in casi:
			var node: Node3D = c["node"]
			if not is_instance_valid(node):
				continue
			var r: Dictionary = c["r"]
			var id := int(c["id"])
			var i := int(c["i"])
			var n := node.global_position
			var dm := n.distance_to(_player.global_position)
			var meta: Dictionary = DED.meta_del_gesto(_cuore, id, i,
					r.get("luoghi", []), int(r.get("fatti", 0)))
			var mp: Vector3 = meta.get("pos", n) as Vector3

			# ---- la regola di PRIMA (si valuta, non si paga) ----
			if (c["prima"] as Dictionary).is_empty():
				var dove_v: Vector3 = _cuore.call("deduzione_dove", id, i, n,
						Vector3.ZERO, 0.0)
				if PERCEZIONE.puo_vedere(node, n, 1.0) \
						and node.call("collo_ci_arriva", dove_v):
					c["prima"] = {"t": t, "mochi": dm, "ancora": n.distance_to(dove_v),
							"angolo": rad_to_deg(_angolo(n, dove_v, mp))
									if not meta.is_empty() else -1.0}
			# ---- la regola di ADESSO (è il codice vero, e paga) ----
			if (c["adesso"] as Dictionary).is_empty():
				if DED.consegna(_cuore, id, node, i, _player.global_position,
						r.get("luoghi", []), int(r.get("fatti", 0))):
					var dove_n: Vector3 = _cuore.call("deduzione_dove", id, i, n,
							mp, DED.APERTURA)
					c["adesso"] = {"t": t, "mochi": dm, "ancora": n.distance_to(dove_n),
							"angolo": rad_to_deg(_angolo(n, dove_n, mp))}
		await create_timer(0.25).timeout
		t += 0.25

	for chiave in ["prima", "adesso"]:
		var quante := 0
		var dm := []
		var da := []
		var ang := []
		var lontane := 0
		for c in casi:
			var s: Dictionary = c[chiave]
			if s.is_empty():
				continue
			quante += 1
			dm.append(float(s["mochi"]))
			da.append(float(s["ancora"]))
			if float(s["angolo"]) >= 0.0:
				ang.append(float(s["angolo"]))
			if float(s["mochi"]) > DED.RAGGIO:
				lontane += 1
		print("\n  ── la regola di %s ──" % chiave.to_upper())
		print("  ricevute pagate                 : %d su %d" % [quante, casi.size()])
		print("  di cui con Mochi FUORI dal raggio: %d" % lontane)
		print(_riepilogo("Mochi → il vicino, alla ricevuta", dm))
		print(_riepilogo("vicino → il posto guardato", da))
		print(_riepilogo("ANGOLO fra il posto guardato e la meta", ang, "°"))


# =========================================================================
# LA VITA — quanto spesso il giocatore è lì da vedere
# =========================================================================

## ⚠️ **UN MODELLO DEL GIOCATORE, ED È DICHIARATO.** Nessuno sa dove sta un
## giocatore vero; quello che si può fare è non inventarsi il caso comodo.
## Qui Mochi va **dai posti del villaggio ai posti del villaggio** — le case,
## i cespugli, le panchine — alla velocità del corpo vero, fermandosi qualche
## secondo. È il modello meno favorevole fra quelli onesti: non insegue
## nessuno, non sa dove sono i vicini, e i posti sono gli stessi che i vicini
## frequentano solo perché è lo stesso villaggio.
##
## Il numero che conta NON è «quanto spesso è vicino» (piccolo, e ovvio con
## venti metri di prato): è **quanto spesso lo diventa almeno una volta
## mentre la deduzione è ancora viva**. Una deduzione aspetta la sua
## ricevuta per tutta la sua vita — è la ragione per cui `deduzione_muta`
## si richiede a ogni giro, e il caso «il collo non ci arriva» l'aveva già
## dimostrato.
const VITA_SECONDI := 240.0
const VITA_PASSO := 0.25
const MOCHI_PASSO := 3.0     # m/s: un giocatore che cammina, non che corre
const FINESTRE := [30.0, 60.0, 120.0, 180.0]
const RAGGI := [3.0, 4.5, 6.0, 9.0]

## IL GIRO DI MOCHI, un passo. Dai posti del villaggio ai posti del
## villaggio, con qualche secondo di sosta: vedi il blocco di `_la_vita`.
var _mochi_meta := Vector3.INF
var _mochi_sosta := 0.0

func _passo_mochi(rng: RandomNumberGenerator) -> void:
	if _mochi_meta == Vector3.INF:
		_mochi_meta = _m(CASE[rng.randi() % CASE.size()])
	var p := _player.global_position
	if _mochi_sosta > 0.0:
		_mochi_sosta -= VITA_PASSO
		return
	var m := Vector3(_mochi_meta.x, p.y, _mochi_meta.z)
	if p.distance_to(m) < 0.4:
		_mochi_sosta = rng.randf_range(2.0, 6.0)
		var mete := CASE + CIBI + PANCHE
		_mochi_meta = _m(mete[rng.randi() % mete.size()])
		return
	_player.global_position = p + (m - p).normalized() * MOCHI_PASSO * VITA_PASSO


func _la_vita(residenti: Array) -> void:
	var mete := []
	for c in CASE:
		mete.append(_m(c))
	for c in CIBI:
		mete.append(_m(c))
	for c in PANCHE:
		mete.append(_m(c))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260812
	var meta: Vector3 = mete[rng.randi() % mete.size()]
	var sosta := 0.0

	# `visto[raggio][indice_residente]` = array di bool, campione per campione
	var visto := {}
	for raggio in RAGGI:
		var per_r := []
		for i in residenti.size():
			per_r.append([])
		visto[raggio] = per_r

	var t := 0.0
	while t < VITA_SECONDI:
		var p := _player.global_position
		if sosta > 0.0:
			sosta -= VITA_PASSO
		elif p.distance_to(Vector3(meta.x, p.y, meta.z)) < 0.4:
			sosta = rng.randf_range(2.0, 6.0)
			meta = mete[rng.randi() % mete.size()]
		else:
			var d := (Vector3(meta.x, p.y, meta.z) - p).normalized()
			_player.global_position = p + d * MOCHI_PASSO * VITA_PASSO
		for i in residenti.size():
			var node := (residenti[i] as Dictionary).get("node") as Node3D
			for raggio in RAGGI:
				var ok := node != null and is_instance_valid(node) \
						and PERCEZIONE.puo_vedere(node, _player.global_position, float(raggio))
				((visto[raggio] as Array)[i] as Array).append(ok)
		await create_timer(VITA_PASSO).timeout
		t += VITA_PASSO

	print("\n" + "█".repeat(72))
	print("LA VITA — il giocatore c'è, quando la testa si gira?")
	print("█".repeat(72))
	print("  %.0f s di villaggio vero, Mochi che gira per i suoi posti a %.1f m/s"
			% [VITA_SECONDI, MOCHI_PASSO])
	print("  campioni per vicino: %d" % ((visto[RAGGI[0]] as Array)[0] as Array).size())
	print("\n  raggio   quanto tempo è a tiro   e almeno una volta dentro una finestra di:")
	print("                                    %s" % " ".join(FINESTRE.map(
			func(x): return "%6.0f s" % float(x))))
	for raggio in RAGGI:
		var per_r: Array = visto[raggio]
		var acceso := 0
		var totale := 0
		var quote := []
		for f in FINESTRE:
			var passi := int(float(f) / VITA_PASSO)
			var buone := 0
			var prove := 0
			for i in per_r.size():
				var serie: Array = per_r[i]
				# ogni istante di partenza è una deduzione che nasce lì: si
				# guarda se in quella finestra c'è almeno un momento buono
				for k in range(0, maxi(1, serie.size() - passi), 4):
					prove += 1
					for j in range(k, mini(serie.size(), k + passi)):
						if bool(serie[j]):
							buone += 1
							break
			quote.append(100.0 * float(buone) / maxf(float(prove), 1.0))
		for i in per_r.size():
			for x in (per_r[i] as Array):
				totale += 1
				if bool(x):
					acceso += 1
		print("  %5.1f m        %5.1f%%              %s" % [float(raggio),
				100.0 * float(acceso) / maxf(float(totale), 1.0),
				" ".join(quote.map(func(x): return "%6.0f%%" % float(x)))])


# =========================================================================
# IL CENSIMENTO
# =========================================================================

## DOVE ANDREBBE, se questa deduzione diventasse un obiettivo.
##
## Non c'è una tabella «obiettivo → luogo» e non se ne scrive una: la
## risposta la dà il RISOLUTORE, che è l'unico che sa quale trasferimento
## apre quella catena. Il primo passo di ogni piano è sempre un
## trasferimento (`sistema_piani.h`: le pose le accende solo un operatore),
## e il luogo di quell'operatore è l'indice dentro `luoghi`.
func _meta_di(r: Dictionary, obiettivo: String) -> Dictionary:
	var luoghi: Array = r.get("luoghi", [])
	if luoghi.size() < PIANI.LUOGHI.size():
		return {}
	var ob := int(_cuore.call("maschera_obiettivo", obiettivo))
	if ob == 0:
		return {}
	var passi: PackedInt32Array = _cuore.call("pianifica",
			int(r.get("fatti", 0)), ob, PIANI.cammino(luoghi))
	if passi.is_empty():
		return {}
	var op: Dictionary = _cuore.call("debug_operatore", int(passi[0]))
	var l := int(op.get("luogo", -1))
	if l < 0 or l >= luoghi.size():
		return {}
	var voce: Dictionary = luoghi[l]
	if not bool(voce.get("ok", false)):
		return {}
	return {"luogo": str(PIANI.LUOGHI[l]), "pos": voce["pos"] as Vector3}


func _angolo(da: Vector3, a: Vector3, b: Vector3) -> float:
	var va := (a - da) * Vector3(1, 0, 1)
	var vb := (b - da) * Vector3(1, 0, 1)
	if va.length() < 0.05 or vb.length() < 0.05:
		return PI
	return va.normalized().angle_to(vb.normalized())


func _censimento(residenti: Array) -> void:
	var ritmo: Dictionary = _cuore.call("debug_ritmo")
	var ora := float(ritmo["tempo"])
	var mezza := float(ritmo["mezza_vita"])

	# le distribuzioni
	var d_mochi := []          # quanto dista Mochi dal vicino che deduce
	var d_ancora_forte := []   # vicino → posto guardato (regola di adesso)
	var d_ancora_meta := []    # posto guardato → posto in cui va (regola di adesso)
	var a_ancora_meta := []    # e l'ANGOLO fra i due, visto dal vicino
	var d_scelta := []         # vicino → posto guardato (scegliendo il perché)
	var d_scelta_meta := []
	var a_scelta_meta := []
	var candidati := 0
	var con_meta := 0
	var vicini_con_ricordi := 0

	# quante deduzioni sopravvivono a una porta angolare, al variare
	# dell'apertura: è il numero che decide se il canale resta vivo
	var aperture := [15.0, 20.0, 25.0, 30.0, 40.0, 50.0, 60.0, 90.0]
	var vive_forte := {}
	var vive_scelta := {}
	for g in aperture:
		vive_forte[g] = 0
		vive_scelta[g] = 0
	# e a una porta metrica, per confronto
	var metri := [1.0, 2.0, 3.0, 5.0, 8.0]
	var vive_metri := {}
	for x in metri:
		vive_metri[x] = 0

	for r in residenti:
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var rit: Dictionary = FOGLIO.ritratto(_vis, _dn, _cuore, r, "pensiero", "Mochi")
		if rit.is_empty():
			continue
		var citabili: Array = SUG.fatti(rit)
		if citabili.is_empty():
			continue
		vicini_con_ricordi += 1
		var righe: Array = rit.get("ricordi", [])
		var indici := PackedInt32Array()
		for voce in citabili:
			indici.append(int((voce as Dictionary)["riga"]))
		var pos_di := {}
		var peso_di := {}
		for i in indici:
			var riga: Dictionary = righe[i]
			pos_di[i] = Vector3(float(riga.get("px", 0.0)), 0.0, float(riga.get("pz", 0.0)))
			peso_di[i] = float(_cuore.call("debug_grafo_peso", riga, ora, mezza))

		var n := node.global_position
		var dm := n.distance_to(_player.global_position)

		for obiettivo in SUG.obiettivi_deducibili(rit):
			var meta := _meta_di(r, str(obiettivo))
			# I SOTTOINSIEMI SE LI FA DARE DALLA GRAMMATICA, non se li
			# riscrive: se un domani la grammatica smettesse di ammettere le
			# terne, un banco con la sua copia continuerebbe a misurarle e a
			# raccontare un gioco che non esiste più.
			for gruppo in SUG._sottoinsiemi(indici, 3):
				candidati += 1
				d_mochi.append(dm)
				if meta.is_empty():
					continue
				con_meta += 1
				var mp: Vector3 = meta["pos"]

				# LA REGOLA DI ADESSO: il perché più PESANTE.
				var forte := -1
				for i in (gruppo as Array):
					if forte < 0 or float(peso_di[i]) > float(peso_di[forte]):
						forte = int(i)
				var pf: Vector3 = pos_di[forte]
				d_ancora_forte.append(n.distance_to(pf))
				d_ancora_meta.append(pf.distance_to(mp))
				var af := _angolo(n, pf, mp)
				a_ancora_meta.append(rad_to_deg(af))
				for g in aperture:
					if rad_to_deg(af) <= float(g):
						vive_forte[g] = int(vive_forte[g]) + 1
				for x in metri:
					if pf.distance_to(mp) <= float(x):
						vive_metri[x] = int(vive_metri[x]) + 1

				# LA REGOLA PROPOSTA: fra i perché ALLINEATI alla meta, il più
				# pesante. Non cambia il criterio — restringe il campo: tutti
				# i perché sono veri, e si mostra quello che si legge.
				var scelto := -1
				var ang_scelto := PI
				for i in (gruppo as Array):
					var ai := _angolo(n, pos_di[i], mp)
					if scelto < 0 or ai < ang_scelto - 0.0001 \
							or (absf(ai - ang_scelto) <= 0.0001
									and float(peso_di[i]) > float(peso_di[scelto])):
						scelto = int(i)
						ang_scelto = ai
				var ps: Vector3 = pos_di[scelto]
				d_scelta.append(n.distance_to(ps))
				d_scelta_meta.append(ps.distance_to(mp))
				a_scelta_meta.append(rad_to_deg(ang_scelto))
				for g in aperture:
					if rad_to_deg(ang_scelto) <= float(g):
						vive_scelta[g] = int(vive_scelta[g]) + 1

	print("\n" + "█".repeat(72))
	print("IL CENSIMENTO — tutto ciò che la grammatica può produrre, stasera")
	print("█".repeat(72))
	print("  vicini con qualcosa da dedurre : %d su %d" % [vicini_con_ricordi, residenti.size()])
	print("  candidati (obiettivo × perché) : %d — con una meta vera: %d" % [candidati, con_meta])

	print("\n── 1) IL GIOCATORE C'ERA? ─────────────────────────────────────")
	print(_riepilogo("Mochi → il vicino che deduce", d_mochi))
	var vicino_9 := 0
	var vicino_45 := 0
	for x in d_mochi:
		if float(x) <= PERCEZIONE.RAGGIO:
			vicino_9 += 1
		if float(x) <= 4.5:
			vicino_45 += 1
	print(_quota("entro %.1f m (Percezione.RAGGIO)" % PERCEZIONE.RAGGIO, vicino_9, d_mochi.size()))
	print(_quota("entro 4.5 m", vicino_45, d_mochi.size()))

	print("\n── 2) SI CAPISCE COSA GUARDA? ─────────────────────────────────")
	print(_riepilogo("vicino → ancora (il più pesante)", d_ancora_forte))
	print(_riepilogo("vicino → ancora (il più allineato)", d_scelta))
	var oltre := 0
	for x in d_ancora_forte:
		if float(x) > PERCEZIONE.RAGGIO:
			oltre += 1
	print(_quota("oltre %.0f m con la regola di adesso" % PERCEZIONE.RAGGIO,
			oltre, d_ancora_forte.size()))

	print("\n── 3) VA DOVE HA GUARDATO? ────────────────────────────────────")
	print(_riepilogo("ancora → meta (il più pesante)", d_ancora_meta))
	print(_riepilogo("ancora → meta (il più allineato)", d_scelta_meta))
	print(_riepilogo("ANGOLO ancora/meta (più pesante)", a_ancora_meta, "°"))
	print(_riepilogo("ANGOLO ancora/meta (più allineato)", a_scelta_meta, "°"))

	print("\n── 4) QUANTE NE SOPRAVVIVONO? ─────────────────────────────────")
	print("  porta ANGOLARE (l'angolo che il giocatore vede dal vicino)")
	print("    apertura   con la regola di adesso   scegliendo il perché")
	for g in aperture:
		print("      %5.0f°        %4d  (%3.0f%%)             %4d  (%3.0f%%)" % [float(g),
				int(vive_forte[g]), 100.0 * float(vive_forte[g]) / maxf(float(con_meta), 1.0),
				int(vive_scelta[g]), 100.0 * float(vive_scelta[g]) / maxf(float(con_meta), 1.0)])
	print("  porta METRICA (distanza fra i due posti), regola di adesso")
	for x in metri:
		print("      %5.1f m       %4d  (%3.0f%%)" % [float(x), int(vive_metri[x]),
				100.0 * float(vive_metri[x]) / maxf(float(con_meta), 1.0)])
