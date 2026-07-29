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
## E il vocabolario: quasi un CENTINAIO di parole FISSE, le stesse
## sillabe per tutti i villager. "grazie" è sempre «ta-ki», la pioggia
## è sempre «ni-nu»: cambia solo la voce che le pronuncia. Col tempo,
## il giocatore impara davvero a capirli — senza una riga di testo.
## Ogni parola ha il suo SUONO-SENSO (il fonosimbolismo delle lingue
## vere): le cose piccole e brillanti stanno sulle vocali acute (i),
## le grandi e tristi su quelle scure (o, u); la legna fa due colpi
## secchi, l'acqua scorre sulle liquide. E alcune parole portano il
## loro CONTORNO di intonazione (vedi CONTORNO): l'addio scende,
## l'aiuto squilla, la musica canticchia da sola.

const RATE := 22050

## Il dizionario Chibiese-italiano. Parole brevi, suoni distintivi,
## OGNI SEQUENZA UNICA (mai due parole omofone: un test fa la guardia):
## impararle deve essere un piacere, non un compito.
const VOCAB := {
	# --- le sedici parole di sempre (MAI cambiarle: chi gioca le sa già) ---
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
	# --- il congedo e i sentimenti (erano BUCHI: i ricordi dell'addio
	# cadevano nel balbettio casuale, proprio nei momenti più cari) ---
	"addio": ["ba", "yo"],
	"triste": ["lo", "mu"],
	"scusa": ["pe", "no"],
	"aiuto": ["ye", "ye"],
	# --- il cielo e le stagioni ---
	"stelle": ["ki", "li"],
	"luna": ["nu", "la"],
	"neve": ["fu", "wa"],
	"vento": ["so", "fu"],
	"freddo": ["bu", "fu"],
	"caldo": ["mo", "ho"],
	# --- l'acqua e il fiume ---
	"acqua": ["lu", "la"],
	"barca": ["bo", "ta"],
	# --- il fare di ogni giorno ---
	"legna": ["to", "ko"],
	"lavoro": ["ko", "po"],
	"aspetta": ["ta", "ta"],
	"andiamo": ["ho", "pa"],
	"guarda": ["ki", "yo"],
	"buono": ["me", "na"],
	# --- la festa e la musica ---
	"musica": ["la", "li", "la"],
	"festa": ["pi", "pa"],
	# --- le misure del mondo ---
	"piccolo": ["pi", "ni"],
	"grande": ["bo", "ba"],
	"nanna": ["mu", "nu"],
	# ================= la GRANDE ESPANSIONE del lessico =================
	# (con le sei consonanti nuove: r, d, g, z, sh, ch)
	# --- le creature del prato e del bosco ---
	"farfalla": ["fi", "la"],     # leggera in punta di "i", poi plana
	"lucciola": ["li", "ki"],     # due lucine acute
	"uccellino": ["chi", "chi"],  # è IL cinguettio
	"ape": ["zi", "zi"],          # è IL ronzio
	"albero": ["go", "ro"],       # tronco cupo, rami arrotati
	"foglia": ["sha", "la"],      # il fruscio, poi la planata
	"bosco": ["do", "go"],        # due passi nel fitto scuro
	"prato": ["la", "pa"],        # aperto e piano
	"fungo": ["pu", "fo"],        # paffuto e soffice
	"stagno": ["lo", "bu"],       # acqua ferma e scura
	"montagna": ["go", "bo"],     # due masse cupe
	# --- il frutteto e il nido ---
	"semino": ["pi", "ku"],       # minuscolo, con lo scatto del guscio
	"nido": ["ni", "do"],         # raccolto e caldo
	"uovo": ["o", "bo"],          # due vocali tonde come lui
	"frutto": ["me", "lo"],       # (il melo sta nel nome)
	"miele": ["me", "lu"],        # scorre denso sulle liquide
	"gufo": ["gu", "hu"],         # è IL bubbolio, cupo e soffiato
	# --- il cielo, le stagioni, il tempo ---
	"primavera": ["fi", "wa", "la"],  # fiore+felice+musica: sboccia
	"estate": ["sa", "ho"],           # sole caldo pieno
	"autunno": ["sho", "ro"],         # fruscio e ruggine
	"inverno": ["fu", "bu"],          # il freddo rigirato (bu-fu al contrario)
	"mattina": ["ki", "ha"],          # luce + il sì del risveglio
	"sera": ["so", "lo"],             # scende piano
	"notte": ["nu", "no"],            # nasali scure
	"nebbia": ["fu", "mo"],           # soffio velato
	"arcobaleno": ["la", "ko", "li"], # sale e riscende: un arco di sillabe
	"domani": ["ho", "yo"],           # aperto, in avanti
	# --- i sentimenti (il Filo Rosso ha bisogno di parole) ---
	"amore": ["mo", "mi"],        # dal caldo al brillante
	"paura": ["hu", "du"],        # fiato e buio
	"coraggio": ["da", "go"],     # due plosive piantate a terra
	"nostalgia": ["mi", "yo"],    # un brillio che si allontana
	"ricordo": ["mi", "mo"],      # un brillio tenuto al caldo
	"cuore": ["du", "du"],        # è IL battito, due colpi sordi
	"insieme": ["yo", "mi"],      # l'uno verso l'altro
	"sorpresa": ["o", "ho"],      # oh-ho!
	"arrabbiato": ["ga", "bu"],   # ringhio e rifiuto
	"vergogna": ["pe", "mu"],     # la scusa che si fa piccola
	"bello": ["wa", "na"],        # meraviglia morbida
	"forte": ["do", "ka"],        # due colpi netti
	"piano": ["shu", "shu"],      # shh, shh: il gesto stesso
	# --- il fare e il giocare ---
	"giocare": ["pi", "po"],      # palline che rimbalzano
	"trovato": ["ta", "da"],      # ta-daa!
	"correre": ["ta", "ka", "ta"],# passetti a terra
	"pescare": ["bo", "li"],      # il tonfo e il guizzo
	"costruire": ["to", "po"],    # martelletti (famiglia di legna/lavoro)
	"cantare": ["la", "lo"],      # solo liquide, gola aperta
	"ballare": ["pa", "la"],      # passo e giro
	"foto": ["ka", "chi"],        # è IL clic dell'otturatore
	"abbraccio": ["mo", "fu"],    # caldo che avvolge
	# --- il villaggio e le sue cose ---
	"lettera": ["pa", "pi"],      # carta che fruscia tra le zampe
	"nocciolina": ["ko", "ki"],   # piccola e dura (la moneta del cuore)
	"lanterna": ["ho", "li"],     # fiamma calda + lucina
	"ombrello": ["po", "fu"],     # tetto tondo + soffio di pioggia
	"te": ["cha"],                # il tè si chiama cha in mezzo mondo
	"dolce": ["mi", "mu"],        # piccolo e morbido in bocca
	"ponte": ["ba", "ta"],        # due assi sotto le zampe
	"sentiero": ["ta", "lo"],     # passi che vanno lontano
	"campana": ["di", "do"],      # è IL din-don
	"villaggio": ["po", "mo", "pa"],  # la casa (po-mo) fatta grande: morfologia!
}

## Il CONTORNO di intonazione di una parola: un moltiplicatore di pitch
## per sillaba (stessa lunghezza della parola, un test lo garantisce).
## È la melodia DENTRO la parola, prima ancora dell'umore della frase:
## l'addio cade, le stelle stanno in punta, la musica canticchia.
const CONTORNO := {
	"addio": [1.04, 0.82],
	"triste": [0.95, 0.85],
	"scusa": [0.98, 0.9],
	"aiuto": [1.2, 1.28],
	"stelle": [1.15, 1.25],
	"musica": [1.0, 1.12, 1.22],
	"risata": [1.1, 1.18, 1.26],
	"andiamo": [0.95, 1.15],
	"guarda": [1.12, 1.2],
	"nanna": [1.0, 0.88],
	"grande": [0.92, 0.85],
	"piccolo": [1.18, 1.24],
	"ciao": [1.06, 1.14],
	# --- le melodie della grande espansione ---
	"farfalla": [1.12, 1.22],       # svolazza verso l'alto
	"lucciola": [1.1, 1.24],        # si accende
	"uccellino": [1.18, 1.26],      # cinguetta in punta
	"ape": [1.12, 1.18],            # ronza allegra
	"foglia": [1.05, 0.9],          # si stacca e cade
	"gufo": [0.98, 0.84],           # il bubbolio scende nel bosco
	"semino": [1.15, 1.22],         # piccolo e pieno di promesse
	"primavera": [1.08, 1.16, 1.24],# sboccia salendo
	"autunno": [1.0, 0.88],         # la ruggine cala
	"inverno": [0.95, 0.85],        # si stringe nel freddo
	"mattina": [1.1, 1.2],          # il risveglio sale
	"sera": [1.0, 0.88],            # scende col sole
	"notte": [0.95, 0.84],          # ancora più giù
	"arcobaleno": [1.05, 1.28, 1.08],  # IL contorno è l'arco stesso
	"domani": [1.02, 1.14],         # aperto verso avanti
	"amore": [1.0, 1.16],           # si scalda salendo
	"paura": [1.1, 0.86],           # sobbalza e si rannicchia
	"coraggio": [0.98, 1.14],       # si pianta e si alza
	"nostalgia": [1.12, 0.82],      # si sporge e ricade: la mancanza
	"ricordo": [1.1, 0.95],         # brilla e si posa
	"cuore": [1.02, 0.94],          # tu-tum
	"sorpresa": [1.2, 1.05],        # l'oh! e il rientro
	"arrabbiato": [0.9, 0.82],      # ringhia verso il basso
	"vergogna": [0.95, 0.86],       # si fa piccola
	"piano": [0.92, 0.86],          # sussurra scendendo
	"giocare": [1.16, 1.06],        # rimbalza
	"trovato": [1.0, 1.26],         # ta-DAA
	"cantare": [1.1, 1.2],          # si apre in gola
	"ballare": [1.06, 1.16],        # il giro che solleva
	"foto": [1.0, 1.22],            # il clic che squilla
	"abbraccio": [1.0, 0.92],       # avvolge e si posa
	"nocciolina": [1.0, 1.18],      # tintinna
	"campana": [1.22, 0.9],         # DIN-don
}

# formanti delle vocali [F1, F2]
const VOWELS := {
	"a": [780.0, 1220.0], "e": [480.0, 1900.0], "i": [300.0, 2350.0],
	"o": [480.0, 900.0], "u": [320.0, 750.0],
}

# l'inventario delle consonanti. Le prime dodici sono quelle di sempre;
# le sei nuove hanno ciascuna il suo gesto in bocca: la "r" arrotata
# (colpetti di lingua), "d"/"g" plosive sonore (chiara e cupa), la "z"
# ronzante (l'ape!), "sh" il fruscio (foglie, il fare piano), "ch" il
# cinguettio secco. I digrammi sono UNA consonante: "chi" = ch+i.
const CONS := ["p", "t", "k", "b", "m", "n", "f", "s", "w", "y", "h", "l",
		"r", "d", "g", "z", "sh", "ch"]

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
	# IL SEME DELLA VOCE è nel genoma e NON SI TOCCA (ChibiDNA: `voce_seed`).
	# Prima si ricavava da nome+PELO+archetipo+taglia, e finché il pelo era
	# per sempre reggeva. Ma dal momento in cui l'aspetto si può cambiare —
	# l'estetista, una tinta — quella formula diventa un difetto grave:
	# cambiare colore ti cambierebbe il TIMBRO, cioè chi sei a orecchio.
	# Il ripiego sulla vecchia formula serve ai genomi nati prima (i
	# salvataggi vecchi): la loro voce resta esattamente quella di ieri.
	var seed_v := int(dna["voce_seed"]) if dna.has("voce_seed") \
			else hash(str(dna.get("name", "?")) + str(dna.get("fur", ""))
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


## La voce di chi è appena nato. Speculare a invecchia(): l'età va in
## una direzione, l'infanzia nell'altra — più acuta, più cantata, più
## veloce a scatti, e senza una traccia di raucedine.
## `quanto`: 1 = appena nato, 0 = ha finito di crescere.
## Mette anche il grado di storpiatura DENTRO la voce (chiave "bimbo"),
## così say() lo trova da sé e la cache resta corretta senza che nessun
## chiamante debba sapere che esiste un cucciolo.
static func bimbo(v: Dictionary, quanto: float) -> Dictionary:
	var q := clampf(quanto, 0.0, 1.0)
	if q <= 0.01:
		return v
	var out := v.duplicate()
	out["pitch"] = float(v["pitch"]) * (1.0 + 0.42 * q)
	out["rate"] = float(v["rate"]) * (1.0 + 0.18 * q)
	out["rough"] = maxf(float(v["rough"]) * (1.0 - 0.8 * q), 0.0)
	out["sing"] = float(v["sing"]) * (1.0 + 0.5 * q)
	out["breath"] = minf(float(v["breath"]) + 0.3 * q, 1.2)
	out["bimbo"] = q
	# la cache è chiavata sulla voce: senza spostare la chiave, un
	# cucciolo si riascolterebbe la propria frase di ieri per sempre
	out["key"] = int(v["key"]) + 7000000 * int(round(q * 4.0))
	return out


## Come un bambino piccolo dice una parola che non sa ancora dire.
## Non è rumore a caso: sono le due tappe vere di ogni lingua umana.
##  1. RADDOPPIO — la prima sillaba si ripete e mangia la seconda:
##     «ta-ki» (grazie) esce «ta-ta». È il primo passo, sempre.
##  2. ARMONIA CONSONANTICA — la seconda sillaba torna, ma con la
##     consonante della prima: «ta-ki» diventa «ta-ti». La bocca sa già
##     fare due vocali, non ancora due consonanti diverse.
##  3. poi la parola è giusta, e resta solo la voce da cucciolo.
## Le parole di UNA sillaba si raddoppiano: è il «pa-pa» di tutti.
## PURA: entra una lista di sillabe, esce una lista di sillabe.
static func storpia(sillabe: Array, quanto: float) -> Array:
	var q := clampf(quanto, 0.0, 1.0)
	if q <= 0.12 or sillabe.is_empty():
		return sillabe.duplicate()
	if sillabe.size() == 1:
		# una sillaba sola: da piccolissimi si dice due volte
		return [str(sillabe[0]), str(sillabe[0])] if q > 0.5 \
				else sillabe.duplicate()
	var out: Array = sillabe.duplicate()
	if q > 0.62:
		for i in range(1, out.size()):
			out[i] = str(out[0])
	elif q > 0.3:
		for i in range(1, out.size()):
			out[i] = _consonante(str(out[0])) + _vocale(str(out[i]))
	return out


## L'attacco di una sillaba ("sha" -> "sh", "o" -> ""). Le sillabe del
## Chibiese sono tutte consonante+vocale, digrammi compresi.
static func _consonante(s: String) -> String:
	for i in s.length():
		if s[i] in "aeiou":
			return s.substr(0, i)
	return s


## La coda vocalica ("sha" -> "a", "o" -> "o").
static func _vocale(s: String) -> String:
	for i in s.length():
		if s[i] in "aeiou":
			return s.substr(i)
	return s


## Una frase: lista di concetti del VOCAB (o "~" per una sillaba di
## chiacchiericcio nello stile della voce). Mood: neutro | felice |
## domanda | triste. Ritorna l'audio pronto da suonare.
static func say(v: Dictionary, concepts: Array, mood := "neutro") -> AudioStreamWAV:
	var key := "%d|%s|%s" % [int(v["key"]), "+".join(PackedStringArray(concepts)), mood]
	if _cache.has(key):
		return _cache[key]

	# la frase come lista di sillabe, con i confini di parola e il
	# CONTORNO di intonazione di ciascuna (1.0 dove la parola non ne ha)
	var syls: Array[String] = []
	var word_end: Array[bool] = []
	var contour: Array[float] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(v["key"]) + hash(key)
	var quanto_bimbo := float(v.get("bimbo", 0.0))
	for c in concepts:
		var w: Array = VOCAB.get(str(c), [])
		var melodia: Array = CONTORNO.get(str(c), [])
		if w.is_empty():
			w = [v["fav"][rng.randi() % 3]]
			melodia = []
		# in bocca a un cucciolo la parola esce ancora storta (il
		# contorno d'intonazione no: la musica della frase i bambini
		# la prendono per prima, molto prima dei suoni)
		if quanto_bimbo > 0.0:
			w = storpia(w, quanto_bimbo)
		for i in w.size():
			syls.append(str(w[i]))
			word_end.append(i == w.size() - 1)
			contour.append(float(melodia[i]) if i < melodia.size() else 1.0)

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
		# la melodia della parola si somma a quella dell'umore
		pm *= contour[k]
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
		"r":
			f2s = f2t * 0.6
			glide = 0.055
		"d":
			f2s = 1700.0 * formant
			glide = 0.035
		"g":
			f1s = 350.0 * formant
			f2s = f2t * 0.82
			glide = 0.045
		"sh", "ch":
			f2s = 2100.0 * formant
			glide = 0.04
		"z":
			f2s = 1900.0 * formant
			glide = 0.04

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
		"d":
			# plosiva sonora dentale: il fratello chiaro della "b"
			var burst := int(0.013 * RATE)
			for i in burst:
				var t := float(i) / RATE
				out.append(rng.randf_range(-1, 1) * sin(TAU * 1600.0 * t) \
						* exp(-t * 280.0) * 0.55)
		"g":
			# plosiva sonora velare: cupa, da fondo gola
			var burst := int(0.015 * RATE)
			for i in burst:
				var t := float(i) / RATE
				out.append(rng.randf_range(-1, 1) * sin(TAU * 640.0 * t) \
						* exp(-t * 230.0) * 0.6)
		"r":
			# la erre arrotata: colpetti di lingua sul palato — un tono
			# al pitch della voce, acceso e spento ~27 volte al secondo
			var trill := int(0.06 * RATE)
			for i in trill:
				var t := float(i) / RATE
				var battito := maxf(0.0, sin(TAU * 27.0 * t))
				out.append(sin(TAU * pitch * t) * battito * battito \
						* minf(t / 0.01, 1.0) * 0.5)
		"z":
			# la zeta ronzante: fricativa SONORA — il ronzio dell'ape
			# (soffio brillante sopra, corda grave sotto)
			var buzz := int(0.055 * RATE)
			for i in buzz:
				var t := float(i) / RATE
				var env := minf(t / 0.012, 1.0) * minf((0.055 - t) / 0.02, 1.0)
				out.append((rng.randf_range(-1, 1) * 0.3 \
						* (0.5 + 0.5 * sin(TAU * 4600.0 * t)) \
						+ 0.42 * sin(TAU * 130.0 * t)) * env)
		"sh":
			# il fruscio morbido: foglie che cadono, il "fare piano"
			var hush := int(0.06 * RATE)
			for i in hush:
				var t := float(i) / RATE
				var env := minf(t / 0.018, 1.0) * minf((0.06 - t) / 0.025, 1.0)
				out.append(rng.randf_range(-1, 1) * (0.5 + 0.5 * sin(TAU * 3600.0 * t)) \
						* env * 0.3)
		"ch":
			# l'affricata del cinguettio: scatto secco + soffio breve
			var gap_ch := int(0.01 * RATE)
			out.resize(out.size() + gap_ch)
			var scatto := int(0.012 * RATE)
			for i in scatto:
				var t := float(i) / RATE
				out.append(rng.randf_range(-1, 1) * sin(TAU * 4300.0 * t) \
						* exp(-t * 300.0) * 0.7)
			var soffio := int(0.028 * RATE)
			for i in soffio:
				var t := float(i) / RATE
				out.append(rng.randf_range(-1, 1) * (0.5 + 0.5 * sin(TAU * 3800.0 * t)) \
						* minf((0.028 - t) / 0.014, 1.0) * 0.3)

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
