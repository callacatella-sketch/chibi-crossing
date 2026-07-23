extends Node

## Sfx — tutta la colonna sonora di Chibi Crossing, sintetizzata in codice.
## Nessun file audio esterno: passi, pop del builder, campanellini UI,
## cinguettii, vento in loop e una musichetta carillon (I-V-vi-IV) vengono
## generati all'avvio come AudioStreamWAV. Musica e vento sono renderizzati
## in un thread per non bloccare il caricamento.

const RATE := 22050
const MUSIC_RATE := 16000

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_next := 0
var _music: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _bird: AudioStreamPlayer
var _rain_p: AudioStreamPlayer
var _bird_timer: Timer
var _thread: Thread
var _rain_on := false
var _rain_muffled := false
# un solo tween alla volta su pioggia e vento: quello vecchio si uccide,
# così la dissolvenza d'uscita non spegne mai la pioggia appena riaccesa
var _rain_tw: Tween
var _wind_tw: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_sfx()

	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

	_music = AudioStreamPlayer.new()
	_music.volume_db = -60.0
	add_child(_music)

	_wind = AudioStreamPlayer.new()
	_wind.volume_db = -60.0
	add_child(_wind)

	_bird = AudioStreamPlayer.new()
	_bird.volume_db = -18.0
	add_child(_bird)

	_rain_p = AudioStreamPlayer.new()
	_rain_p.volume_db = -60.0
	_rain_p.stream = _streams["rain_loop"]
	add_child(_rain_p)

	_bird_timer = Timer.new()
	_bird_timer.one_shot = true
	_bird_timer.timeout.connect(_on_bird_timer)
	add_child(_bird_timer)

	_thread = Thread.new()
	_thread.start(_render_slow_audio)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


# ================================================================ API

## Quanti effetti sono stati sintetizzati (usato dalla verifica CLI).
func sound_count() -> int:
	return _streams.size()


func play(sound: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sound):
		return
	var p: AudioStreamPlayer = null
	for cand in _pool:
		if not cand.playing:
			p = cand
			break
	if p == null:
		p = _pool[_pool_next % _pool.size()]
		_pool_next += 1
	p.stream = _streams[sound]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


## Passo differenziato per superficie: "grass", "wood" o "stone".
func footstep(surface := "grass") -> void:
	play("step_%s%d" % [surface, 1 + randi() % 3], -14.0, randf_range(0.92, 1.1))

func ui_select() -> void:
	play("select", -10.0, randf_range(0.98, 1.02))

func place_ok() -> void:
	play("place", -8.0)

func place_deny() -> void:
	play("deny", -12.0)

func remove_item() -> void:
	play("remove", -10.0)

func rotate_tick() -> void:
	play("tick", -12.0, randf_range(0.95, 1.05))

func build_open() -> void:
	play("open", -10.0)

func build_close() -> void:
	play("close", -10.0)

func wake_up() -> void:
	play("wake", -9.0)

func water() -> void:
	play("water", -12.0)

func boil() -> void:
	play("boil", -14.0)

func net_swish() -> void:
	play("swish", -10.0, randf_range(0.95, 1.08))

func plop() -> void:
	play("plop", -11.0, randf_range(0.92, 1.08))

func munch() -> void:
	play("munch", -11.0, randf_range(0.95, 1.05))

func camera_click() -> void:
	play("tick", -8.0, 1.5)


## La pioggia entra ed esce in dissolvenza; con lei il vento si fa sentire.
func set_rain(on: bool) -> void:
	_rain_on = on
	if on and not _rain_p.playing:
		_rain_p.play()
	_retune_rain()
	if _wind.playing:
		if _wind_tw and _wind_tw.is_valid():
			_wind_tw.kill()
		_wind_tw = create_tween()
		_wind_tw.tween_property(_wind, "volume_db", -22.0 if on else -27.0, 2.5)


## Sotto un tetto la pioggia suona ovattata: coccola pura.
func set_rain_muffled(m: bool) -> void:
	if m == _rain_muffled:
		return
	_rain_muffled = m
	_retune_rain()


func _retune_rain() -> void:
	var target := -60.0
	if _rain_on:
		target = -24.0 if _rain_muffled else -19.0
	if _rain_tw and _rain_tw.is_valid():
		_rain_tw.kill()
	_rain_tw = create_tween()
	_rain_tw.tween_property(_rain_p, "volume_db", target, 2.2)
	if not _rain_on:
		_rain_tw.tween_callback(func(): if not _rain_on: _rain_p.stop())


# ================================================================ util

func _wav(buf: PackedFloat32Array, rate := RATE, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, clampi(int(buf[i] * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = buf.size()
	return wav


func _normalize(buf: PackedFloat32Array, peak := 0.8) -> void:
	var m := 0.0
	for v in buf:
		m = maxf(m, absf(v))
	if m < 0.0001:
		return
	var k := peak / m
	for i in buf.size():
		buf[i] *= k


func _mtof(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


# nota da carillon: attacco istantaneo, coda dolce, armonici che svaniscono
func _add_musicbox(buf: PackedFloat32Array, rate: int, start_s: float, freq: float, vel: float, loop_idx := false) -> void:
	var n := int(1.6 * rate)
	var n0 := int(start_s * rate)
	var total := buf.size()
	for i in n:
		var idx := n0 + i
		if loop_idx:
			idx = idx % total
		elif idx >= total:
			break
		var t := float(i) / float(rate)
		var env := exp(-t * 3.4) * minf(t / 0.004, 1.0)
		var v := sin(TAU * freq * t) \
				+ 0.35 * sin(TAU * freq * 2.0 * t) * exp(-t * 6.0) \
				+ 0.12 * sin(TAU * freq * 3.01 * t) * exp(-t * 9.0)
		buf[idx] += v * env * vel


func _add_bass(buf: PackedFloat32Array, rate: int, start_s: float, freq: float, vel: float) -> void:
	var n := int(1.5 * rate)
	var n0 := int(start_s * rate)
	var total := buf.size()
	for i in n:
		var idx := (n0 + i) % total
		var t := float(i) / float(rate)
		var env := exp(-t * 2.2) * minf(t / 0.01, 1.0)
		buf[idx] += (sin(TAU * freq * t) + 0.2 * sin(TAU * freq * 2.0 * t)) * env * vel


# ================================================================ sfx

func _build_sfx() -> void:
	for i in 3:
		_streams["step_grass" + str(i + 1)] = _gen_step_grass(i * 7 + 1)
		_streams["step_wood" + str(i + 1)] = _gen_step_wood(i * 11 + 3)
		_streams["step_stone" + str(i + 1)] = _gen_step_stone(i * 5 + 9)
		_streams["step_wet" + str(i + 1)] = _gen_step_wet(i * 3 + 17)
	_streams["rain_loop"] = _gen_rain()
	_streams["place"] = _gen_place()
	_streams["deny"] = _gen_deny()
	_streams["remove"] = _gen_remove()
	_streams["tick"] = _gen_tick()
	_streams["select"] = _gen_select()
	_streams["open"] = _gen_two_notes(72, 79)
	_streams["close"] = _gen_two_notes(79, 72)
	_streams["wake"] = _gen_wake()
	for i in 3:
		_streams["chirp" + str(i + 1)] = _gen_chirp(i * 13 + 5)
	_streams["door_open"] = _gen_door(true)
	_streams["door_close"] = _gen_door(false)
	_streams["water"] = _gen_water()
	_streams["boil"] = _gen_boil()
	_streams["swish"] = _gen_swish()
	_streams["plop"] = _gen_plop()
	_streams["munch"] = _gen_munch()


# passo sull'erba: fruscio filtrato + piccolo tonfo
func _gen_step_grass(seed_v: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := int(0.09 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf() * 2.0 - 1.0
		lp += (white - lp) * 0.2
		ph += TAU * (105.0 - 55.0 * t / 0.09) / RATE
		var thump := sin(ph) * exp(-t * 34.0)
		buf[i] = lp * exp(-t * 46.0) * 0.75 + thump * 0.85
	_normalize(buf, 0.7)
	return _wav(buf)


# passo sul parquet: "tok" cavo di legno, due parziali smorzate + click
func _gen_step_wood(seed_v: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := int(0.11 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var detune := rng.randf_range(0.95, 1.05)
	for i in n:
		var t := float(i) / RATE
		var body := (sin(TAU * 172.0 * detune * t) * 0.7 \
				+ sin(TAU * 291.0 * detune * t) * 0.3) * exp(-t * 42.0)
		var white := rng.randf() * 2.0 - 1.0
		lp += (white - lp) * 0.3
		buf[i] = body + lp * exp(-t * 220.0) * 0.5
	_normalize(buf, 0.65)
	return _wav(buf)


# passo sulla pietra: "tak" secco e brillante, con un filo di tonfo
func _gen_step_stone(seed_v: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := int(0.09 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var detune := rng.randf_range(0.94, 1.06)
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf() * 2.0 - 1.0
		lp += (white - lp) * 0.5
		var hp := white - lp
		buf[i] = hp * exp(-t * 150.0) * 0.7 \
				+ sin(TAU * 415.0 * detune * t) * exp(-t * 70.0) * 0.45 \
				+ sin(TAU * 138.0 * t) * exp(-t * 50.0) * 0.3
	_normalize(buf, 0.6)
	return _wav(buf)


# passo sull'erba bagnata: splash morbido con un "plip" acquoso
func _gen_step_wet(seed_v: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := int(0.13 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var ph := 0.0
	var plip_f := rng.randf_range(750.0, 980.0)
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf() * 2.0 - 1.0
		lp += (white - lp) * 0.4
		var hp := white - lp
		# splash: banda larga che si spegne subito
		buf[i] = (lp * 0.5 + hp * 0.5) * exp(-t * 60.0) * 0.7
		# il "plip": goccia tonda che scende di tono
		ph += TAU * (plip_f - 2400.0 * t) / RATE
		buf[i] += sin(ph) * exp(-t * 70.0) * 0.4 * minf(t / 0.008, 1.0)
	_normalize(buf, 0.6)
	return _wav(buf)


# pioggerella in loop: pioggia larga e morbida con goccioline sparse,
# coda in crossfade sulla testa per un loop senza cuciture
func _gen_rain() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var dur := 4.2
	var fade := 0.5
	var n := int(dur * RATE)
	var nf := int(fade * RATE)
	var raw := PackedFloat32Array()
	raw.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf() * 2.0 - 1.0
		lp += (white - lp) * 0.3
		lp2 += (lp - lp2) * 0.3
		# corpo della pioggia: fruscio pieno ma vellutato, con un respiro lento
		raw[i] = lp2 * (0.75 + 0.25 * sin(TAU * 0.17 * t + 0.8))
	# goccioline in primo piano: tic brevi e gentili
	for d in 26:
		var at := rng.randf_range(0.0, dur - 0.05)
		var f := rng.randf_range(1400.0, 3200.0)
		var vel := rng.randf_range(0.1, 0.22)
		var start := int(at * RATE)
		for i in int(0.02 * RATE):
			if start + i >= n:
				break
			var t := float(i) / RATE
			raw[start + i] += sin(TAU * f * t) * exp(-t * 420.0) * vel
	var buf := PackedFloat32Array()
	buf.resize(n - nf)
	for i in n - nf:
		var v := raw[i]
		if i < nf:
			var w := float(i) / float(nf)
			v = raw[i] * w + raw[n - nf + i] * (1.0 - w)
		buf[i] = v
	_normalize(buf, 0.55)
	return _wav(buf, RATE, true)


# "pop!" felice + arpeggio di campanellini (piazzamento riuscito)
func _gen_place() -> AudioStreamWAV:
	var n := int(0.7 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	for i in int(0.07 * RATE):
		var t := float(i) / RATE
		ph += TAU * (280.0 + 3600.0 * t) / RATE
		buf[i] += sin(ph) * exp(-t * 26.0) * 0.8
	_add_musicbox(buf, RATE, 0.05, _mtof(84), 0.5)   # C6
	_add_musicbox(buf, RATE, 0.13, _mtof(88), 0.42)  # E6
	_add_musicbox(buf, RATE, 0.21, _mtof(91), 0.5)   # G6
	_normalize(buf, 0.75)
	return _wav(buf)


# "mh-mh" negativo, morbido (piazzamento non valido)
func _gen_deny() -> AudioStreamWAV:
	var n := int(0.22 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for seg in 2:
		var f := 174.0 if seg == 0 else 155.0
		var start := int(seg * 0.11 * RATE)
		for i in int(0.09 * RATE):
			var t := float(i) / RATE
			var env := exp(-t * 30.0) * minf(t / 0.006, 1.0)
			buf[start + i] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 3.0 * t)) * env * 0.7
	_normalize(buf, 0.6)
	return _wav(buf)


# poof + discesa (rimozione)
func _gen_remove() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var n := int(0.3 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf() * 2.0 - 1.0
		lp += (white - lp) * 0.12
		buf[i] += lp * exp(-t * 16.0) * 0.7
		if t < 0.14:
			ph += TAU * (520.0 - 2300.0 * t) / RATE
			buf[i] += sin(ph) * exp(-t * 22.0) * 0.5
	_normalize(buf, 0.65)
	return _wav(buf)


# tic secco di rotazione
func _gen_tick() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := int(0.07 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / RATE
		buf[i] = (rng.randf() * 2.0 - 1.0) * exp(-t * 180.0) * 0.6 \
				+ sin(TAU * 720.0 * t) * exp(-t * 80.0) * 0.5
	_normalize(buf, 0.6)
	return _wav(buf)


# plin di selezione
func _gen_select() -> AudioStreamWAV:
	var n := int(0.4 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	_add_musicbox(buf, RATE, 0.0, _mtof(84), 0.55)
	_normalize(buf, 0.6)
	return _wav(buf)


# la sveglia del mattino: arpeggio di carillon che sale come il sole
func _gen_wake() -> AudioStreamWAV:
	var n := int(1.8 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	_add_musicbox(buf, RATE, 0.0, _mtof(72), 0.4)    # C5
	_add_musicbox(buf, RATE, 0.16, _mtof(76), 0.38)  # E5
	_add_musicbox(buf, RATE, 0.32, _mtof(79), 0.42)  # G5
	_add_musicbox(buf, RATE, 0.48, _mtof(84), 0.5)   # C6
	_add_musicbox(buf, RATE, 0.72, _mtof(88), 0.28)  # E6, l'ultima scintilla
	_normalize(buf, 0.7)
	return _wav(buf)


# due note di carillon (apertura/chiusura modalità costruzione)
func _gen_two_notes(midi_a: int, midi_b: int) -> AudioStreamWAV:
	var n := int(0.6 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	_add_musicbox(buf, RATE, 0.0, _mtof(midi_a), 0.5)
	_add_musicbox(buf, RATE, 0.1, _mtof(midi_b), 0.45)
	_normalize(buf, 0.65)
	return _wav(buf)


# scatto breve e sordo (maniglia / serratura)
func _add_click(buf: PackedFloat32Array, at: float, vel: float, tone: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at * 1000.0) + 7
	var start := int(at * RATE)
	for i in int(0.012 * RATE):
		if start + i >= buf.size():
			break
		var t := float(i) / RATE
		buf[start + i] += (sin(TAU * tone * t) * 0.55 + (rng.randf() * 2.0 - 1.0) * 0.45) \
				* exp(-t * 650.0) * vel


# tonfo caldo di legno
func _add_thump(buf: PackedFloat32Array, at: float, freq: float, vel: float) -> void:
	var start := int(at * RATE)
	for i in int(0.1 * RATE):
		if start + i >= buf.size():
			break
		var t := float(i) / RATE
		buf[start + i] += sin(TAU * freq * (1.0 - t * 0.3) * t) * exp(-t * 30.0) * vel


# porta di legno: solo un soffio d'aria morbido; in apertura il click della
# maniglia, in chiusura il tonfo del battente e lo scatto della serratura
func _gen_door(open: bool) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31 if open else 32
	var n := int(0.34 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var p := t / 0.34
		var white := rng.randf() * 2.0 - 1.0
		lp += (white - lp) * 0.09
		lp2 += (lp - lp2) * 0.09
		var env: float
		if open:
			env = pow(maxf(sin(minf(p * 1.1, 1.0) * PI), 0.0), 1.5)
		else:
			env = pow(maxf(sin(minf(p * 1.45, 1.0) * PI), 0.0), 1.5)
		buf[i] += lp2 * env * 1.4
	if open:
		_add_click(buf, 0.004, 0.5, 1300.0)
	else:
		_add_thump(buf, 0.17, 90.0, 0.95)
		_add_click(buf, 0.225, 0.4, 1800.0)
	_normalize(buf, 0.55)
	return _wav(buf)


# gnam gnam: tre morsetti soffici e contenti
func _gen_munch() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 93
	var n := int(0.5 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for bite in 3:
		var start := int(float(bite) * 0.16 * RATE)
		var f := 145.0 + float(bite) * 12.0
		var lp := 0.0
		for i in int(0.1 * RATE):
			if start + i >= n:
				break
			var t := float(i) / RATE
			var white := rng.randf() * 2.0 - 1.0
			lp += (white - lp) * 0.14
			buf[start + i] += lp * exp(-t * 55.0) * 0.55 \
					+ sin(TAU * f * t) * exp(-t * 48.0) * 0.6 * minf(t / 0.006, 1.0)
	_normalize(buf, 0.6)
	return _wav(buf)


# il "bloop" del galleggiante che tocca l'acqua
func _gen_plop() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var n := int(0.2 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		# il tonfo tondo che scende di tono
		ph += TAU * (420.0 - 1700.0 * minf(t, 0.13)) / RATE
		buf[i] += sin(ph) * exp(-t * 26.0) * 0.8 * minf(t / 0.004, 1.0)
		# spruzzino
		var white := rng.randf() * 2.0 - 1.0
		lp += (white - lp) * 0.35
		buf[i] += lp * exp(-t * 70.0) * 0.3
	# la bollicina che risale
	var start := int(0.09 * RATE)
	var ph2 := 0.0
	for i in int(0.05 * RATE):
		if start + i >= n:
			break
		var t := float(i) / RATE
		ph2 += TAU * (240.0 + 5200.0 * t) / RATE
		buf[start + i] += sin(ph2) * exp(-t * 90.0) * 0.35
	_normalize(buf, 0.6)
	return _wav(buf)


# il colpo di retino: un "swoosh" d'aria rapido e leggero
func _gen_swish() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var n := int(0.22 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var p := t / 0.22
		var white := rng.randf() * 2.0 - 1.0
		# il filtro si apre e si chiude seguendo la sventagliata
		var alpha := 0.1 + 0.45 * sin(minf(p * 1.2, 1.0) * PI)
		lp += (white - lp) * alpha
		var hp := white - lp
		buf[i] = hp * pow(sin(minf(p * 1.15, 1.0) * PI), 1.4)
	_normalize(buf, 0.55)
	return _wav(buf)


# annaffiatoio: pioggerella filtrata + qualche goccia tintinnante
func _gen_water() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var n := int(0.9 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var p := t / 0.9
		var white := rng.randf() * 2.0 - 1.0
		lp += (white - lp) * 0.35
		var hp := white - lp
		buf[i] = hp * pow(sin(minf(p * 1.2, 1.0) * PI), 1.2) * 0.5
	# goccioline: brevi ping acuti sparsi
	for d in 7:
		var at := rng.randf_range(0.1, 0.75)
		var f := rng.randf_range(1800.0, 3400.0)
		var start := int(at * RATE)
		for i in int(0.03 * RATE):
			if start + i >= n:
				break
			var t := float(i) / RATE
			buf[start + i] += sin(TAU * f * t) * exp(-t * 260.0) * 0.3
	_normalize(buf, 0.55)
	return _wav(buf)


# pentolino che sobbolle: brontolio basso + bollicine che salgono
func _gen_boil() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 66
	var n := int(1.6 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var p := t / 1.6
		var white := rng.randf() * 2.0 - 1.0
		lp += (white - lp) * 0.06
		buf[i] = lp * pow(sin(minf(p * 1.1, 1.0) * PI), 1.3) * 0.9
	# bollicine: piccoli glissando in su
	for d in 10:
		var at := rng.randf_range(0.1, 1.4)
		var f0 := rng.randf_range(260.0, 480.0)
		var start := int(at * RATE)
		var ph := 0.0
		for i in int(0.06 * RATE):
			if start + i >= n:
				break
			var t := float(i) / RATE
			ph += TAU * (f0 + 2600.0 * t) / RATE
			buf[start + i] += sin(ph) * exp(-t * 90.0) * 0.35
	_normalize(buf, 0.5)
	return _wav(buf)


# cinguettio: 2-3 sillabe con vibrato, dolce
func _gen_chirp(seed_v: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := int(0.55 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var cursor := 0.02
	var syllables := 2 + rng.randi() % 2
	for s in syllables:
		var dur := rng.randf_range(0.07, 0.13)
		var f0 := rng.randf_range(2500.0, 3200.0)
		var sweep := rng.randf_range(500.0, 1300.0) * (1.0 if rng.randf() < 0.7 else -0.6)
		var ph := 0.0
		var start := int(cursor * RATE)
		var count := int(dur * RATE)
		for i in count:
			var t := float(i) / RATE
			var p := t / dur
			var f := f0 + sweep * p + 140.0 * sin(TAU * 38.0 * t)
			ph += TAU * f / RATE
			var env := sin(p * PI)
			if start + i < n:
				buf[start + i] += sin(ph) * env * env * 0.5
		cursor += dur + rng.randf_range(0.03, 0.07)
	_normalize(buf, 0.5)
	return _wav(buf)


# ================================================================ thread

func _render_slow_audio() -> void:
	var music := _render_music()
	var wind := _render_wind()
	call_deferred("_apply_slow_audio", music, wind)


func _apply_slow_audio(music: AudioStreamWAV, wind: AudioStreamWAV) -> void:
	_music.stream = music
	_music.play()
	var mt := create_tween()
	mt.tween_property(_music, "volume_db", -16.0, 3.0)

	_wind.stream = wind
	_wind.play()
	var wt := create_tween()
	wt.tween_property(_wind, "volume_db", -27.0, 4.0)

	_bird_timer.start(randf_range(2.0, 5.0))


func _on_bird_timer() -> void:
	_bird.stream = _streams["chirp" + str(1 + randi() % 3)]
	_bird.pitch_scale = randf_range(0.9, 1.15)
	_bird.play()
	_bird_timer.start(randf_range(4.0, 11.0))


# la musichetta: carillon su C - G - Am - F, 8 battute in loop senza cuciture
func _render_music() -> AudioStreamWAV:
	var bpm := 82.0
	var spb := 60.0 / bpm
	var total_beats := 32.0
	var n := int(total_beats * spb * MUSIC_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)

	# [beat, midi, velocità]
	var melody := [
		[0.0, 79, 0.5], [1.0, 76, 0.45], [2.0, 84, 0.55],
		[4.0, 86, 0.5], [5.0, 83, 0.45], [6.0, 79, 0.5],
		[8.0, 81, 0.5], [9.0, 84, 0.45], [10.0, 76, 0.5],
		[12.0, 77, 0.45], [13.0, 81, 0.45], [14.0, 79, 0.5],
		[16.0, 76, 0.5], [17.0, 79, 0.45], [18.0, 72, 0.5],
		[20.0, 74, 0.45], [21.0, 79, 0.45], [22.0, 83, 0.5],
		[24.0, 84, 0.5], [25.0, 81, 0.45], [26.0, 77, 0.5],
		[28.0, 86, 0.45], [29.0, 84, 0.55],
		# scintille alte, come un ricordo
		[2.5, 96, 0.22], [10.5, 93, 0.2], [18.5, 91, 0.2], [26.5, 96, 0.22],
	]
	# giro I - V - vi - IV, poi I - V - IV - I
	var bass := [
		[0.0, 48], [2.0, 55], [4.0, 43], [6.0, 50],
		[8.0, 45], [10.0, 52], [12.0, 41], [14.0, 48],
		[16.0, 48], [18.0, 55], [20.0, 43], [22.0, 50],
		[24.0, 41], [26.0, 48], [28.0, 48], [30.0, 55],
	]

	for m in melody:
		_add_musicbox(buf, MUSIC_RATE, m[0] * spb, _mtof(m[1]), m[2], true)
	for b in bass:
		_add_bass(buf, MUSIC_RATE, b[0] * spb, _mtof(b[1]), 0.3)

	_normalize(buf, 0.75)
	return _wav(buf, MUSIC_RATE, true)


# vento leggero in loop, con respiro lento
func _render_wind() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var dur := 3.6
	var fade := 0.5
	var n := int(dur * RATE)
	var nf := int(fade * RATE)
	var raw := PackedFloat32Array()
	raw.resize(n)
	var brown := 0.0
	var lp1 := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		brown = brown * 0.997 + (rng.randf() * 2.0 - 1.0) * 0.05
		lp1 += (brown - lp1) * 0.05
		lp2 += (lp1 - lp2) * 0.05
		raw[i] = lp2 * (0.6 + 0.4 * sin(TAU * 0.1 * t + 1.3))
	# crossfade coda→testa per un loop senza click
	var buf := PackedFloat32Array()
	buf.resize(n - nf)
	for i in n - nf:
		var v := raw[i]
		if i < nf:
			var w := float(i) / float(nf)
			v = raw[i] * w + raw[n - nf + i] * (1.0 - w)
		buf[i] = v
	_normalize(buf, 0.5)
	return _wav(buf, RATE, true)
