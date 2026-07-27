class_name Concertino
extends Node
## IL CONCERTINO DEL CARILLON — la prima volta che il Chibiese canta in coro.
##
## Un giro di manovella al Carillon e i vicini a portata d'orecchio
## accorrono, si dispongono a semicerchio attorno alla cassettina, e quando
## il rullo comincia a girare CANTANO — in Chibiese, ognuno con la voce del
## suo DNA. È il motore vocale di sempre (grani di formante: il timbro non
## si sposta mai, l'orsetto canta da orsetto), ma intonato: ogni voce
## sceglie l'OTTAVA del proprio corpo sulla stessa melodia, e l'accordo si
## impila da solo — armonizzato dal DNA, alla lettera.
##
## La melodia è composta sul momento (componi, puro e seminato dal giorno)
## ma è bella PER COSTRUZIONE, non per fortuna:
##   • scala pentatonica maggiore: non esiste la nota storta;
##   • forma A A B cadenza — il motivo si ripete (memorabile), si alza al
##     terzo verso (il brivido), e scende a casa sulla tonica;
##   • giro I–vi–IV–V, coi tempi forti agganciati alle note dell'accordo;
##   • le voci ENTRANO una alla volta — prima la melodia sola col
##     carillon, poi la seconda voce, poi il basso dell'orsetto al
##     climax — e l'ultima nota resta sospesa insieme, in accordo.
##
## Il carillon accompagna con arpeggi di cassettina (sintetizzati qui),
## la musica di fondo si inchina (Sfx.duck_music), le note colorate del
## vestitino di chi canta salgono fluttuando, e al finale tutti fanno
## festa. Ogni concertino è unico; nessuno è mai brutto.

const CHIBIESE := preload("res://audio/Chibiese.gd")

const RAGGIO_ASCOLTO := 16.0     # da quanto lontano si accorre
const MAX_CANTANTI := 5
const RAGGIO_CERCHIO := 1.7      # il semicerchio attorno al carillon
const RIPOSO := 75.0             # secondi fra un concertino e l'altro
const RATE := 22050

# la scala pentatonica maggiore: gradini (semitoni sulla tonica)
const SCALA := [0, 2, 4, 7, 9]
# il giro: I, vi, IV, V — radici e note d'accordo IN scala pentatonica
const GIRO_RADICI := [0, -3, 5, 7]
const GIRO_TONI := [[0, 4, 7], [0, 4, 9], [0, 9, 5], [7, 2, 0]]
# i motivi ritmici (durate in beat, somma 4): il verso B è il più fitto
const MOTIVI_A := [[1.0, 1.0, 1.0, 1.0], [1.5, 0.5, 1.0, 1.0],
		[1.0, 1.0, 1.5, 0.5]]
const MOTIVO_B := [1.0, 0.5, 0.5, 1.0, 1.0]
const MOTIVO_CADENZA := [1.0, 1.0, 2.0]

var _cantando := false
var _riposo := 0.0
var _t_canto := -1.0             # il tempo dentro il brano (per le note fx)
var _spartito_fx: Array = []     # [{t, nodo cantante, colore}] da far fiorire
var _players: Array = []
var _cantanti: Array = []        # i node dei coristi
var _t_ripeti := 0.0


func _ready() -> void:
	add_to_group("concertino")


func _process(delta: float) -> void:
	_riposo = maxf(_riposo - delta, 0.0)
	if _t_canto < 0.0:
		return
	_t_canto += delta
	# le note fiorite: quando il brano tocca il loro beat, sbocciano
	while not _spartito_fx.is_empty() and float(_spartito_fx[0]["t"]) <= _t_canto:
		var voce: Dictionary = _spartito_fx.pop_front()
		var nodo = voce["nodo"]
		if nodo != null and is_instance_valid(nodo):
			_fiorisci_nota(nodo, voce["colore"])
	# i coristi restano al loro posto: la routine si rinnova piano
	_t_ripeti -= delta
	if _t_ripeti <= 0.0:
		_t_ripeti = 5.0
		for c in _cantanti:
			var nodo = c["nodo"]
			if is_instance_valid(nodo) and nodo.has_method("do_routine"):
				nodo.call("do_routine", "sniff", c["posto"], c["verso"])


# ------------------------------------------------------------- l'avvio

## La manovella è girata (Interactions): se c'è pubblico, si canta.
func avvia(carillon: Node3D) -> void:
	if _cantando or _riposo > 0.0 or carillon == null:
		return
	var visitors := get_node_or_null("../../Visitors")
	if visitors == null:
		return
	# chi è a portata d'orecchio, i più vicini prima
	var vicini: Array = []
	for r in (visitors.get("_residents") as Array):
		var node := r.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("is_hidden") and bool(node.call("is_hidden")):
			continue
		var d := node.global_position.distance_to(carillon.global_position)
		if d <= RAGGIO_ASCOLTO:
			vicini.append([d, r])
	if vicini.is_empty():
		return
	vicini.sort_custom(func(a, b): return a[0] < b[0])

	_cantando = true
	_cantanti = []
	var nomi: Array = []
	for i in mini(MAX_CANTANTI, vicini.size()):
		var r: Dictionary = vicini[i][1]
		var node := r["node"] as Node3D
		# il semicerchio: aperti verso sud, tutti rivolti al carillon
		var a := PI * 0.25 + PI * 0.5 * float(i) / maxf(float(mini(MAX_CANTANTI,
				vicini.size()) - 1), 1.0)
		var posto := carillon.global_position \
				+ Vector3(cos(a), 0, sin(a)) * RAGGIO_CERCHIO
		_cantanti.append({"nodo": node, "dna": r.get("dna", {}),
				"posto": posto, "verso": carillon.global_position})
		nomi.append(str(r.get("label", "un vicino")))
		if node.has_method("do_routine"):
			node.call("do_routine", "sniff", posto, carillon.global_position)
	_toast("Il carillon chiama: %s si stringono attorno alla musica…"
			% " e ".join(PackedStringArray([", ".join(PackedStringArray(
			nomi.slice(0, maxi(nomi.size() - 1, 1)))), nomi[-1]] if nomi.size() > 1 else nomi)))

	# il tempo di accorrere, poi si canta
	get_tree().create_timer(2.8).timeout.connect(_canta.bind(carillon))


func _canta(carillon: Node3D) -> void:
	if not is_instance_valid(carillon):
		_fine()
		return
	var dn := get_node_or_null("../../DayNight")
	var seme := hash(str(int(dn.get("day")) if dn else 0) + "concertino"
			+ str(Time.get_ticks_msec() / 600000))
	var canzone := componi(seme)

	# il rendering (voci + carillon) cuoce in un thread: mai un singhiozzo
	var cantanti := _cantanti.duplicate()
	var thread := Thread.new()
	thread.start(func() -> void:
		var tracce: Array = []
		var parti := parti_per(cantanti.size())
		for i in cantanti.size():
			var dna: Dictionary = cantanti[i]["dna"]
			var voce := CHIBIESE.voice(dna)
			var linea := linea_per_parte(canzone, parti[i])
			if linea.is_empty():
				tracce.append(null)
				continue
			var ottava := CHIBIESE.ottava_comoda(voce, _midi_mediano(linea))
			var note := sillabe_e_ottava(voce, linea, ottava, seme + i)
			tracce.append(CHIBIESE.canta_linea(voce, note,
					float(canzone["beats"]), float(canzone["bpm"])))
		var cassa := _rendi_carillon(canzone)
		call_deferred("_in_scena", canzone, tracce, cassa, carillon, thread))


## Tutto pronto: si spegne (piano) la musica di fondo e si canta davvero.
func _in_scena(canzone: Dictionary, tracce: Array, cassa: AudioStreamWAV,
		carillon: Node3D, thread: Thread) -> void:
	thread.wait_to_finish()
	if not is_instance_valid(carillon):
		_fine()
		return
	var sfx = get_node_or_null(^"/root/Sfx")
	if sfx and sfx.has_method("duck_music"):
		sfx.duck_music(true)

	_players = []
	var spb: float = 60.0 / float(canzone["bpm"])
	_spartito_fx = []
	var parti := parti_per(_cantanti.size())
	for i in _cantanti.size():
		var nodo = _cantanti[i]["nodo"]
		if not is_instance_valid(nodo) or i >= tracce.size() or tracce[i] == null:
			continue
		var p := AudioStreamPlayer3D.new()
		p.stream = tracce[i]
		p.unit_size = 7.0
		p.volume_db = -2.0
		(nodo as Node3D).add_child(p)
		p.position = Vector3(0, 0.8, 0)
		p.play()
		_players.append(p)
		# il volto canta: bocca a tempo, espressione di gioia
		var face = nodo.get("_face")
		if face:
			face.set_expression("gioia", 0.85)
			face.set_talking(true)
		# le note fiorite sbocciano sui SUOI attacchi, del SUO colore
		var colore := Color(str((_cantanti[i]["dna"] as Dictionary) \
				.get("dress", "f2a9bc")))
		for nota in linea_per_parte(canzone, parti[i]):
			_spartito_fx.append({"t": float(nota["b"]) * spb, "nodo": nodo,
					"colore": colore})

	# la cassettina accompagna dal carillon
	var pc := AudioStreamPlayer3D.new()
	pc.stream = cassa
	pc.unit_size = 8.0
	pc.volume_db = -4.0
	carillon.add_child(pc)
	pc.position = Vector3(0, 0.5, 0)
	pc.play()
	_players.append(pc)

	_spartito_fx.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	_t_canto = 0.0
	var durata: float = float(canzone["beats"]) * spb
	get_tree().create_timer(durata + 0.6).timeout.connect(_finale)


func _finale() -> void:
	# l'ultima nota resta sospesa, poi la festa
	for c in _cantanti:
		var nodo = c["nodo"]
		if not is_instance_valid(nodo):
			continue
		var face = nodo.get("_face")
		if face:
			face.set_talking(false)
			face.set_expression("raggiante", 0.9)
		if nodo.has_method("celebrate"):
			nodo.call("celebrate")
		if nodo.has_method("_spawn_heart"):
			nodo.call("_spawn_heart")
	_toast("…e l'ultima nota resta sospesa nell'aria. ")
	get_tree().call_group("regista", "note", "concertino")
	_fine()


func _fine() -> void:
	var sfx = get_node_or_null(^"/root/Sfx")
	if sfx and sfx.has_method("duck_music"):
		sfx.duck_music(false)
	for p in _players:
		if is_instance_valid(p):
			(p as Node).queue_free()
	_players = []
	_cantanti = []
	_spartito_fx = []
	_t_canto = -1.0
	_cantando = false
	_riposo = RIPOSO


# --------------------------------------------------------- il compositore
# Tutto puro e statico: il test ascolta la struttura senza suonare nulla.

## Il gradino pentatonico [param idx] (anche negativo) in semitoni.
static func gradino(idx: int) -> int:
	@warning_ignore("integer_division")
	var ottave := int(floor(float(idx) / 5.0))
	return ottave * 12 + SCALA[posmod(idx, 5)]


## Il gradino più vicino a un semitono d'accordo (per i tempi forti).
static func aggancia_accordo(idx: int, toni: Array) -> int:
	var meglio := idx
	var dist := 99
	for delta in [0, -1, 1, -2, 2]:
		var s := posmod(gradino(idx + delta), 12)
		for tono in toni:
			if s == posmod(int(tono), 12) and absi(delta) < dist:
				dist = absi(delta)
				meglio = idx + delta
	return meglio


## LA CANZONE: quattro battute (A A B cadenza) + coda, ~13 secondi.
## Stesso seme → stessa canzone: il concertino di stasera è IL concertino
## di stasera, non un dado a ogni ascolto.
static func componi(seme: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	# hash del seme: i semi "vicini" (giorni consecutivi) davano PRIMI
	# tiri quasi identici — tutti i concertini partivano sullo stesso bpm
	rng.seed = hash("concertino|%d" % seme)
	var bpm := rng.randf_range(84.0, 96.0)
	var tonica := 72 + rng.randi_range(-3, 2)

	var motivo: Array = MOTIVI_A[rng.randi() % MOTIVI_A.size()]
	var melodia: Array = []
	var idx := 2                      # si parte dalla terza: dolce da subito
	var beat := 0.0
	for bar in 4:
		var ritmo: Array = motivo
		if bar == 2:
			ritmo = MOTIVO_B
		elif bar == 3:
			ritmo = MOTIVO_CADENZA
		var salita := 2 if bar == 2 else 0    # il verso B si alza: il brivido
		var dentro := 0.0
		for k in ritmo.size():
			var dur := float(ritmo[k])
			if bar == 3 and k == ritmo.size() - 1:
				idx = 0                # la cadenza torna a casa: tonica
			else:
				var passo := rng.randi_range(-1, 1)
				if rng.randf() < 0.3:
					passo *= 2
				idx = clampi(idx + passo, -3, 8)
				# i tempi forti cantano l'accordo della battuta
				if dentro < 0.01 or absf(dentro - 2.0) < 0.01:
					idx = aggancia_accordo(idx + salita, GIRO_TONI[bar]) - salita
			melodia.append({"b": beat, "beats": dur,
					"midi": tonica + gradino(idx + salita)})
			beat += dur
			dentro += dur

	# la coda: la tonica sospesa, due beat, tutti insieme
	melodia.append({"b": 16.0, "beats": 2.0, "midi": tonica})

	# la seconda voce: la melodia due gradini sotto (terza pentatonica:
	# sempre consonante), entra dalla SECONDA battuta — il coro cresce
	var armonia: Array = []
	for nota in melodia:
		if float(nota["b"]) < 4.0:
			continue
		var m := int(nota["midi"]) - tonica
		var idx_m := _idx_di(m)
		armonia.append({"b": nota["b"], "beats": nota["beats"],
				"midi": tonica + gradino(idx_m - 2)})

	# il basso: la radice dell'accordo, note intere, entra al verso B
	var basso: Array = []
	for bar in range(2, 4):
		basso.append({"b": float(bar) * 4.0, "beats": 4.0,
				"midi": tonica + int(GIRO_RADICI[bar]) - 12})
	basso.append({"b": 16.0, "beats": 2.0, "midi": tonica - 12})

	# l'arpeggio della cassettina: crome sull'accordo, dall'inizio
	var arpeggio: Array = []
	for bar in 4:
		var toni: Array = GIRO_TONI[bar]
		var giro := [int(toni[0]), int(toni[1]) , int(toni[2]), int(toni[1])]
		for k in 8:
			arpeggio.append({"b": float(bar) * 4.0 + float(k) * 0.5,
					"beats": 0.5,
					"midi": tonica + 12 + int(giro[k % 4]) + (12 if k >= 4 else 0)})
	arpeggio.append({"b": 16.0, "beats": 2.0, "midi": tonica + 12})
	arpeggio.append({"b": 16.0, "beats": 2.0, "midi": tonica + 12 + 7})

	return {"bpm": bpm, "beats": 18.0, "tonica": tonica,
			"melodia": melodia, "armonia": armonia, "basso": basso,
			"arpeggio": arpeggio}


## L'indice pentatonico di un semitono (il più vicino).
static func _idx_di(semitono: int) -> int:
	var meglio := 0
	var dist := 99
	for idx in range(-6, 15):
		var d := absi(gradino(idx) - semitono)
		if d < dist:
			dist = d
			meglio = idx
	return meglio


## Le parti del coro, dal più acuto al più grave (l'ordine dei cantanti
## lo decide chi chiama, per registro vocale).
static func parti_per(quanti: int) -> Array:
	match quanti:
		0: return []
		1: return ["melodia"]
		2: return ["melodia", "armonia"]
		3: return ["melodia", "armonia", "basso"]
		4: return ["melodia", "armonia", "basso", "melodia"]
	return ["melodia", "armonia", "basso", "melodia", "armonia"]


static func linea_per_parte(canzone: Dictionary, parte: String) -> Array:
	return canzone.get(parte, []) as Array


static func _midi_mediano(linea: Array) -> float:
	var somma := 0.0
	for n in linea:
		somma += float(n["midi"])
	return somma / maxf(float(linea.size()), 1.0)


## Le sillabe del canto: le note lunghe si aprono («laa», «waa»), le
## brevi pescano dalle sillabe preferite della voce — ognuno canta nel
## SUO Chibiese. E l'ottava comoda si applica qui.
static func sillabe_e_ottava(voce: Dictionary, linea: Array, ottava: int,
		seme: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	var aperte := ["la", "wa", "na", "ma"]
	var out: Array = []
	for n in linea:
		var syl: String
		if float(n["beats"]) >= 1.5 or rng.randf() < 0.55:
			syl = aperte[rng.randi() % aperte.size()]
		else:
			var fav: Array = voce.get("fav", ["la"])
			syl = str(fav[rng.randi() % fav.size()])
		out.append({"b": n["b"], "beats": n["beats"],
				"midi": int(n["midi"]) + ottava, "syl": syl})
	return out


# ------------------------------------------------- la cassettina che suona

## L'accompagnamento del carillon: note di cassettina (attacco a
## scatto, armonici metallici che svaniscono), renderizzate qui per
## l'intera durata — parte e resta a tempo col coro per costruzione.
static func _rendi_carillon(canzone: Dictionary) -> AudioStreamWAV:
	var spb: float = 60.0 / float(canzone["bpm"])
	var totale := int(float(canzone["beats"]) * spb * RATE)
	var buf := PackedFloat32Array()
	buf.resize(totale)
	for nota in (canzone["arpeggio"] as Array):
		var f := CHIBIESE.mtof(float(nota["midi"]))
		var da := int(float(nota["b"]) * spb * RATE)
		var n := int(minf(float(nota["beats"]) * spb + 0.4, 1.2) * RATE)
		for i in n:
			var j := da + i
			if j >= totale:
				break
			var t := float(i) / RATE
			var s := sin(TAU * f * t) * exp(-t * 4.5) \
					+ 0.4 * sin(TAU * f * 2.0 * t) * exp(-t * 9.0) \
					+ 0.16 * sin(TAU * f * 4.04 * t) * exp(-t * 16.0)
			buf[j] += s * 0.24 * minf(t / 0.004, 1.0)
	var peak := 0.001
	for s in buf:
		peak = maxf(peak, absf(s))
	var gain := 0.7 / peak
	for i in buf.size():
		buf[i] *= gain
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	return wav


# ------------------------------------------------------- le note fiorite

## Una nota musicale (testa, gambo, bandierina) del colore del vestitino
## di chi canta: sboccia sopra la testa, sale ondeggiando, svanisce.
func _fiorisci_nota(nodo: Node3D, colore: Color) -> void:
	var nota := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(colore.lightened(0.25), 0.95)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var testa := SphereMesh.new()
	testa.radius = 0.045
	testa.height = 0.07
	var tm := MeshInstance3D.new()
	tm.mesh = testa
	tm.material_override = mat
	tm.rotation.z = 0.5
	nota.add_child(tm)
	var gambo := BoxMesh.new()
	gambo.size = Vector3(0.016, 0.17, 0.016)
	var gm := MeshInstance3D.new()
	gm.mesh = gambo
	gm.material_override = mat
	gm.position = Vector3(0.038, 0.085, 0)
	nota.add_child(gm)
	var bandiera := BoxMesh.new()
	bandiera.size = Vector3(0.07, 0.03, 0.016)
	var bm := MeshInstance3D.new()
	bm.mesh = bandiera
	bm.material_override = mat
	bm.position = Vector3(0.07, 0.155, 0)
	bm.rotation.z = -0.5
	nota.add_child(bm)

	add_child(nota)
	nota.global_position = nodo.global_position \
			+ Vector3(randf_range(-0.2, 0.2), 1.35, randf_range(-0.15, 0.15))
	nota.rotation.y = randf_range(-0.4, 0.4)
	var sopra := nota.global_position + Vector3(randf_range(-0.3, 0.3), 0.85,
			randf_range(-0.2, 0.2))
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(nota, "global_position", sopra, 1.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(nota.queue_free)


func _toast(testo: String) -> void:
	var visitors := get_node_or_null("../../Visitors")
	if visitors:
		visitors.call("_show_toast", testo)
