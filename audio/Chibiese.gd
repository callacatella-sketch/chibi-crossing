class_name Chibiese
extends RefCounted

## Il Chibiese: la lingua parlata dei villager, sintetizzata dal DNA.
##
## Ogni voce nasce dal genoma — il timbro dall'archetipo (l'orsetto
## brontola grave e ruvido, la topolina squittisce), l'altezza dalla
## taglia, la cadenza dal seed — così ogni residente è riconoscibile
## a orecchio. Le sillabe sono sintetizzate a grani di formante (un
## impulso glottale che fa risuonare F1/F2 a ogni periodo del pitch),
## con vibrato, respiro e prosodia per stato d'animo.
##
## E il vocabolario: quindici parole FISSE, le stesse sillabe per
## tutti i villager. "grazie" è sempre «ta-ki», la pioggia è sempre
## «ni-nu»: cambia solo la voce che le pronuncia. Col tempo, il
## giocatore impara davvero a capirli — senza una riga di testo.

const RATE := 22050

## Il dizionario Chibiese-italiano. Parole brevi, suoni distintivi:
## impararle deve essere un piacere, non un compito.
const VOCAB := {
	"ciao": ["ya", "ho"],
	"casa": ["po", "mo"],
	"pioggia": ["ni", "nu"],
	"sole": ["sa", "la"],
	"grazie": ["ta", "ki"],
	"amico": ["mi", "ka"],
	"cibo": ["na", "mu"],
	"fiore": ["fi", "fi"],
	"felice": ["wa", "wi"],
	"dormire": ["mu", "mu"],
	"regalo": ["pa", "ku"],
	"si": ["ha"],
	"no": ["bu"],
	"fuoco": ["ho", "ka"],
	"pesce": ["bo", "pu"],
	# la risatina: tre sillabe soffiate e acute — col mood "felice" sale
	# di tono ed è A TUTTI GLI EFFETTI una risata (il nascondino ci vive)
	"risata": ["hi", "hi", "hi"],
}

# formanti delle vocali [F1, F2]
const VOWELS := {
	"a": [780.0, 1220.0], "e": [480.0, 1900.0], "i": [300.0, 2350.0],
	"o": [480.0, 900.0], "u": [320.0, 750.0],
}

const CONS := ["p", "t", "k", "b", "m", "n", "f", "s", "w", "y", "h", "l"]

# timbro per archetipo: [pitch base, spostamento formanti, durata
# sillabe, ruvidità, cantilena]
const TIMBRE := {
	"gatto": [330.0, 1.0, 1.0, 0.0, 0.5],
	"coniglio": [375.0, 1.1, 0.88, 0.0, 0.45],
	"orsetto": [205.0, 0.78, 1.18, 0.3, 0.3],
	"volpina": [300.0, 0.95, 1.0, 0.08, 0.65],
	"topolino": [430.0, 1.28, 0.8, 0.0, 0.5],
}

# cache delle frasi renderizzate: {chiave voce+testo+mood: AudioStreamWAV}
static var _cache := {}


## La voce di un villager, deterministica dal DNA.
static func voice(dna: Dictionary) -> Dictionary:
	# tutti gli input voce-determinanti nel seed: due omonimi con pelo
	# uguale ma specie o taglia diverse non si rubano il timbro in cache
	var seed_v := hash(str(dna.get("name", "?")) + str(dna.get("fur", ""))
			+ str(dna.get("archetype", "")) + str(dna.get("size", "")))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var b: Array = TIMBRE.get(str(dna.get("archetype", "gatto")), TIMBRE["gatto"])
	# più piccolo = più acuto, come in natura
	var size_f := clampf(0.69 / float(dna.get("size", 0.7)), 0.85, 1.25)
	var fav: Array[String] = []
	for i in 3:
		fav.append(CONS[rng.randi() % CONS.size()] + "aeiou"[rng.randi() % 5])
	return {
		"pitch": b[0] * size_f * rng.randf_range(0.92, 1.1),
		"formant": float(b[1]) * rng.randf_range(0.95, 1.06),
		"rate": float(b[2]) * rng.randf_range(0.88, 1.12),
		"rough": float(b[3]),
		"sing": float(b[4]) * rng.randf_range(0.8, 1.3),
		"breath": rng.randf_range(0.4, 0.9),
		"fav": fav,
		"key": seed_v,
	}


## La voce che invecchia. Nessun altro gioco può farlo: la voce è
## sintetizzata dal DNA, quindi l'età la attraversa DAVVERO — si
## abbassa, rallenta, si incrina, canta meno e respira di più.
## eta_f: 0 = giovane, 1 = pieno autunno della vita. La chiave di
## cache scatta a quarti d'età: il timbro matura a stagioni, non
## a frame, e la cache non esplode.
static func invecchia(v: Dictionary, eta_f: float) -> Dictionary:
	var f := clampf(eta_f, 0.0, 1.0)
	if f <= 0.01:
		return v
	var out := v.duplicate()
	out["pitch"] = float(v["pitch"]) * (1.0 - 0.10 * f)
	out["rate"] = float(v["rate"]) * (1.0 - 0.20 * f)
	out["rough"] = minf(float(v["rough"]) + 0.30 * f, 1.0)
	out["sing"] = float(v["sing"]) * (1.0 - 0.35 * f)
	out["breath"] = minf(float(v["breath"]) + 0.25 * f, 1.2)
	out["key"] = int(v["key"]) + 1000000 * int(round(f * 4.0))
	return out


## Una frase: lista di concetti del VOCAB (o "~" per una sillaba di
## chiacchiericcio nello stile della voce). Mood: neutro | felice |
## domanda | triste. Ritorna l'audio pronto da suonare.
static func say(v: Dictionary, concepts: Array, mood := "neutro") -> AudioStreamWAV:
	var key := "%d|%s|%s" % [int(v["key"]), "+".join(PackedStringArray(concepts)), mood]
	if _cache.has(key):
		return _cache[key]

	# la frase come lista di sillabe, con i confini di parola
	var syls: Array[String] = []
	var word_end: Array[bool] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(v["key"]) + hash(key)
	for c in concepts:
		var w: Array = VOCAB.get(str(c), [])
		if w.is_empty():
			w = [v["fav"][rng.randi() % 3]]
		for i in w.size():
			syls.append(str(w[i]))
			word_end.append(i == w.size() - 1)

	# prosodia: un moltiplicatore di pitch e durata per sillaba
	var n := syls.size()
	var buf := PackedFloat32Array()
	for k in n:
		var u := float(k) / maxf(float(n - 1), 1.0)
		var pm := 1.0
		var dm := 1.0
		match mood:
			"felice":
				pm = 1.1 + sin(float(k) * 2.1) * 0.06
				dm = 0.92
			"domanda":
				pm = 0.98 if k < n - 1 else 1.22
			"triste":
				pm = 0.94 - 0.1 * u
				dm = 1.25
			_:
				pm = 1.05 - 0.09 * u
		buf.append_array(_syllable(v, syls[k], pm, dm))
		# micro-pausa tra sillabe, respiro tra parole
		var gap := 0.075 if word_end[k] else 0.012
		var silence := PackedFloat32Array()
		silence.resize(int(gap * RATE))
		buf.append_array(silence)

	# normalizza morbido
	var peak := 0.001
	for s in buf:
		peak = maxf(peak, absf(s))
	var gain := 0.82 / peak
	for i in buf.size():
		buf[i] *= gain

	var wav := _wav(buf)
	if _cache.size() > 96:
		_cache.clear()
	_cache[key] = wav
	return wav


## Chiacchiericcio libero: n sillabe preferite della voce.
static func babble(v: Dictionary, n := 3, mood := "neutro") -> AudioStreamWAV:
	var concepts: Array = []
	for i in n:
		concepts.append("~")
	return say(v, concepts, mood)


# ---------------------------------------------------------------- il canto

## Da nota MIDI a frequenza.
static func mtof(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## Da frequenza a nota MIDI (per scegliere l'ottava comoda di una voce).
static func ftom(f: float) -> float:
	return 69.0 + 12.0 * log(f / 440.0) / log(2.0)


## UNA LINEA CANTATA — il Chibiese che smette di parlare e canta.
## [param note]: [{b: beat d'attacco, beats: durata, midi: nota, syl:
## sillaba}]. La linea è renderizzata per l'INTERA durata [param
## beats_totali] (silenzi compresi): tutte le linee di un coro durano
## uguale e partono insieme — il sincrono è garantito dal render, non
## dal caso. La voce resta LEI (stesse formanti dal DNA: l'orsetto canta
## da orsetto, la topolina da topolina — il pitch muove solo la glottide,
## mai il timbro), ma da canto: più vibrato, meno fiato, note legate.
static func canta_linea(v: Dictionary, note: Array, beats_totali: float,
		bpm: float) -> AudioStreamWAV:
	var chiave := "canto|%d|%f|%f" % [int(v["key"]), bpm, beats_totali]
	for nota in note:
		chiave += "|%s@%s~%s%s" % [nota.get("midi"), nota.get("b"),
				nota.get("beats"), nota.get("syl", "la")]
	if _cache.has(chiave):
		return _cache[chiave]

	# la voce da canto: vibrato pieno, respiro raccolto
	var vc := v.duplicate()
	vc["sing"] = minf(float(v["sing"]) * 2.2 + 0.5, 2.2)
	vc["breath"] = float(v["breath"]) * 0.6

	var spb := 60.0 / bpm
	var totale := int(beats_totali * spb * RATE)
	var buf := PackedFloat32Array()
	buf.resize(totale)
	for nota in note:
		var pm := mtof(float(nota["midi"])) / float(vc["pitch"])
		# un filo di respiro fra le note, mai un muro di suono
		var dur := float(nota["beats"]) * spb * 0.9
		var dm := dur / (0.15 * float(vc["rate"]))
		var grano := _syllable(vc, str(nota.get("syl", "la")), pm, dm)
		var da := int(float(nota["b"]) * spb * RATE)
		for i in grano.size():
			var j := da + i
			if j >= totale:
				break
			buf[j] += grano[i]

	# normalizza morbido (le linee si sommano nel mondo, non qui)
	var peak := 0.001
	for s in buf:
		peak = maxf(peak, absf(s))
	var gain := 0.8 / peak
	for i in buf.size():
		buf[i] *= gain

	var wav := _wav(buf)
	if _cache.size() > 96:
		_cache.clear()
	_cache[chiave] = wav
	return wav


## L'ottava comoda: quanti +12/-12 servono perché la linea caschi vicino
## al registro naturale della voce. È QUI che il DNA armonizza il coro:
## le stesse note, ma ognuno nell'ottava del suo corpo — l'orsetto le
## prende basse, la topolina cristalline, e l'accordo si impila da solo.
static func ottava_comoda(v: Dictionary, midi_mediano: float) -> int:
	var proprio := ftom(float(v["pitch"]))
	return clampi(roundi((proprio - midi_mediano) / 12.0), -2, 2) * 12


# ---------------------------------------------------------------- synth

## Una sillaba consonante+vocale a grani di formante.
static func _syllable(v: Dictionary, syl: String, pitch_mult: float, dur_mult: float) -> PackedFloat32Array:
	var vowel := syl[syl.length() - 1]
	var cons := syl.substr(0, syl.length() - 1)
	var f: Array = VOWELS.get(vowel, VOWELS["a"])
	var formant: float = v["formant"]
	var f1t: float = f[0] * formant
	var f2t: float = f[1] * formant
	# la consonante colora l'attacco: da dove partono le formanti
	var f1s := f1t
	var f2s := f2t
	var glide := 0.03
	match cons:
		"w":
			f1s = 320.0 * formant
			f2s = 750.0 * formant
			glide = 0.06
		"y":
			f1s = 300.0 * formant
			f2s = 2350.0 * formant
			glide = 0.06
		"l":
			f2s = f2t * 0.55
			glide = 0.05
		"m", "n":
			f1s = 250.0 * formant
			f2s = f2t * 0.7
			glide = 0.045

	var pitch: float = v["pitch"] * pitch_mult
	var dur := 0.15 * float(v["rate"]) * dur_mult
	var nsmp := int(dur * RATE)
	var out := PackedFloat32Array()

	# --- attacco non-vocalico (burst, fricativa, gap del plosivo) ---
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(syl) + int(v["key"])
	match cons:
		"p", "t", "k":
			var gap := int(0.012 * RATE)
			var burst := int(0.016 * RATE)
			out.resize(gap)
			var bright := 2600.0 if cons == "p" else (5200.0 if cons == "t" else 3600.0)
			for i in burst:
				var t := float(i) / RATE
				out.append(rng.randf_range(-1, 1) * sin(TAU * bright * t) \
						* exp(-t * 320.0) * 0.7)
		"b":
			var burst := int(0.014 * RATE)
			for i in burst:
				var t := float(i) / RATE
				out.append(rng.randf_range(-1, 1) * sin(TAU * 900.0 * t) \
						* exp(-t * 260.0) * 0.55)
		"f", "s":
			var hiss := int(0.05 * RATE)
			var bright := 5800.0 if cons == "s" else 3200.0
			for i in hiss:
				var t := float(i) / RATE
				var env := minf(t / 0.012, 1.0) * minf((0.05 - t) / 0.02, 1.0)
				out.append(rng.randf_range(-1, 1) * (0.5 + 0.5 * sin(TAU * bright * t)) \
						* env * 0.34)
		"h":
			var breath := int(0.035 * RATE)
			for i in breath:
				var t := float(i) / RATE
				out.append(rng.randf_range(-1, 1) * minf(t / 0.03, 1.0) * 0.16)

	# --- la parte vocalica: grani di formante a ogni impulso glottale ---
	var voiced := PackedFloat32Array()
	voiced.resize(nsmp)
	var since_pulse := 0.0
	var period := RATE / pitch
	var atk := 0.014
	var rel := dur * 0.3
	var rough: float = v["rough"]
	var sing: float = v["sing"]
	var breath_amt: float = v["breath"]
	for i in nsmp:
		var t := float(i) / RATE
		var gt := since_pulse / RATE
		var u := minf(t / glide, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		var f1 := lerpf(f1s, f1t, u)
		var f2 := lerpf(f2s, f2t, u)
		var s := sin(TAU * f1 * gt) * exp(-gt * 95.0) \
				+ 0.55 * sin(TAU * f2 * gt) * exp(-gt * 150.0)
		s += rng.randf_range(-1, 1) * 0.05 * breath_amt
		var env := minf(t / atk, 1.0) * clampf((dur - t) / rel, 0.0, 1.0)
		voiced[i] = s * env * env * 0.62

		since_pulse += 1.0
		if since_pulse >= period:
			since_pulse -= period
			# vibrato da cantilena + il brontolio ruvido dell'orsetto
			var vib := 1.0 + sin(TAU * 5.3 * t) * 0.035 * sing
			var jit := 1.0 + rng.randf_range(-1, 1) * 0.22 * rough
			period = RATE / (pitch * vib * jit)

	# le nasali hanno un pre-ronzio morbido al posto del burst
	if cons == "m" or cons == "n":
		var hum := int(0.04 * RATE)
		var pre := PackedFloat32Array()
		pre.resize(hum)
		var sp := 0.0
		for i in hum:
			var gt := sp / RATE
			pre[i] = sin(TAU * 250.0 * gt) * exp(-gt * 80.0) \
					* minf(float(i) / (0.015 * RATE), 1.0) * 0.4
			sp += 1.0
			if sp >= RATE / pitch:
				sp -= RATE / pitch
		out.append_array(pre)

	out.append_array(voiced)
	return out


static func _wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	return wav
