extends RefCounted
## Il concertino del carillon: il Chibiese che canta in coro. Il test
## non può ascoltare — ma la bellezza qui è PER COSTRUZIONE, e quella si
## verifica eccome:
##  • la melodia vive TUTTA nella pentatonica maggiore (la nota storta
##    non esiste proprio);
##  • i tempi forti cantano l'accordo della battuta (giro I–vi–IV–V);
##  • ogni battuta somma 4 beat esatti e la cadenza torna alla tonica;
##  • la seconda voce è sempre consonante (terza pentatonica: 3–7
##    semitoni sotto, mai una seconda);
##  • le voci entrano in ordine: melodia sola, poi armonia (batt. 2),
##    poi il basso al verso B — il coro cresce;
##  • stesso seme → stessa canzone (il concertino di stasera è UNO);
##  • l'ottava comoda: l'orsetto scende d'ottava, la topolina no —
##    l'armonizzazione dal DNA è matematica, non speranza;
##  • canta_linea e la cassettina rendono audio VERO della durata giusta;
##  • i contratti: manovella → gruppo concertino, CozyWorld monta,
##    Sfx sa inchinarsi (duck_music).

const CONCERTINO := "res://scenes/interact/Concertino.gd"
const CHIBIESE := "res://audio/Chibiese.gd"


func run(t) -> void:
	var s: GDScript = load(CONCERTINO)
	var ch: GDScript = load(CHIBIESE)
	t.ok(s != null and s.can_instantiate(), "Concertino.gd compila")
	t.ok(ch != null, "Chibiese.gd compila")
	if s == null or ch == null:
		return

	_test_scala(t, s)
	_test_canzone(t, s)
	_test_armonia(t, s)
	_test_ingressi(t, s)
	_test_determinismo(t, s)
	_test_ottave(t, ch)
	_test_sillabe(t, s, ch)
	_test_audio(t, s, ch)
	_test_riposo(t, s)
	_test_contratti(t)


func _test_scala(t, s: GDScript) -> void:
	t.eq(s.gradino(0), 0, "gradino 0 = tonica")
	t.eq(s.gradino(4), 9, "gradino 4 = sesta (pentatonica)")
	t.eq(s.gradino(5), 12, "gradino 5 = ottava")
	t.eq(s.gradino(-1), -3, "gradino -1 = sesta sotto")
	t.eq(s.gradino(-2), -5, "gradino -2 = quinta sotto")


func _test_canzone(t, s: GDScript) -> void:
	var c: Dictionary = s.componi(4242)
	t.ok(float(c["bpm"]) >= 84.0 and float(c["bpm"]) <= 96.0, "tempo dolce (84–96)")
	t.almost(float(c["beats"]), 18.0, "quattro battute + coda: 18 beat")

	var tonica := int(c["tonica"])
	var melodia: Array = c["melodia"]
	var in_scala := true
	var battute := {0: 0.0, 1: 0.0, 2: 0.0, 3: 0.0}
	for nota in melodia:
		var classe := posmod(int(nota["midi"]) - tonica, 12)
		if not (classe in [0, 2, 4, 7, 9]):
			in_scala = false
		var bar := int(float(nota["b"]) / 4.0)
		if bar < 4:
			battute[bar] += float(nota["beats"])
	t.ok(in_scala, "TUTTA la melodia vive nella pentatonica: mai una nota storta")
	for bar in 4:
		t.almost(float(battute[bar]), 4.0, "la battuta %d somma 4 beat esatti" % bar)

	# i tempi forti (battere e metà battuta) cantano l'accordo del giro
	var forti_ok := true
	for nota in melodia:
		var b := float(nota["b"])
		if b >= 12.0 or (posmod(int(b * 2.0), 4) != 0) or absf(b - roundf(b)) > 0.01:
			continue
		var bar := int(b / 4.0)
		var classe := posmod(int(nota["midi"]) - tonica, 12)
		var toni: Array = s.GIRO_TONI[bar]
		var trovato := false
		for tono in toni:
			if classe == posmod(int(tono), 12):
				trovato = true
		if not trovato:
			forti_ok = false
	t.ok(forti_ok, "i tempi forti cantano l'accordo della battuta")

	# la cadenza torna a casa e la coda la tiene sospesa
	var ultima: Dictionary = melodia[-1]
	t.eq(int(ultima["midi"]), tonica, "l'ultima nota è la tonica")
	t.almost(float(ultima["b"]), 16.0, "…ed è la coda sospesa (beat 16)")


func _test_armonia(t, s: GDScript) -> void:
	var c: Dictionary = s.componi(77)
	var melodia: Array = c["melodia"]
	var armonia: Array = c["armonia"]
	t.ok(armonia.size() > 0, "la seconda voce esiste")
	var consonante := true
	for a in armonia:
		for m in melodia:
			if absf(float(m["b"]) - float(a["b"])) < 0.01:
				var gap := int(m["midi"]) - int(a["midi"])
				if gap < 3 or gap > 7:
					consonante = false
	t.ok(consonante,
			"la seconda voce è SEMPRE consonante (3–7 semitoni sotto, mai seconde)")


func _test_ingressi(t, s: GDScript) -> void:
	var c: Dictionary = s.componi(99)
	var prima_arm := 99.0
	for a in (c["armonia"] as Array):
		prima_arm = minf(prima_arm, float(a["b"]))
	var primo_basso := 99.0
	for b in (c["basso"] as Array):
		primo_basso = minf(primo_basso, float(b["b"]))
	t.almost(prima_arm, 4.0, "l'armonia entra alla seconda battuta")
	t.almost(primo_basso, 8.0, "il basso entra al verso B: il coro cresce")
	# il basso canta le radici del giro
	var basso: Array = c["basso"]
	t.eq(int(basso[0]["midi"]), int(c["tonica"]) + int(s.GIRO_RADICI[2]) - 12,
			"il basso canta la radice della battuta (IV)")
	# le parti del coro: sempre la melodia per primo, mai più di 5
	t.eq(s.parti_per(1), ["melodia"], "un cantante solo → melodia")
	t.eq((s.parti_per(3) as Array).size(), 3, "tre cantanti → tre parti")
	t.eq(str(s.parti_per(5)[2]), "basso", "col coro pieno il basso c'è")


func _test_determinismo(t, s: GDScript) -> void:
	var a: Dictionary = s.componi(123)
	var b: Dictionary = s.componi(123)
	t.eq(str(a), str(b), "stesso seme → la STESSA canzone")
	var diversa: Dictionary = s.componi(124)
	t.ok(str(a) != str(diversa), "seme nuovo → canzone nuova")


func _test_ottave(t, ch: GDScript) -> void:
	t.almost(ch.mtof(69.0), 440.0, "il La centrale è 440 Hz", 0.01)
	t.almost(ch.ftom(440.0), 69.0, "…e viceversa", 0.01)
	# l'orsetto (≈205 Hz) scende d'ottava su una linea a C5; la topolina
	# (≈430 Hz) la canta dov'è: il DNA decide il registro
	t.eq(ch.ottava_comoda({"pitch": 205.0}, 72.0), -12,
			"l'orsetto prende la linea un'ottava sotto")
	t.eq(ch.ottava_comoda({"pitch": 430.0}, 72.0), 0,
			"la topolina la canta cristallina dov'è")


func _test_sillabe(t, s: GDScript, ch: GDScript) -> void:
	var voce: Dictionary = ch.voice({"name": "Prova", "archetype": "gatto",
			"size": 0.7, "fur": "abc"})
	var linea := [{"b": 0.0, "beats": 2.0, "midi": 72},
			{"b": 2.0, "beats": 0.5, "midi": 74}]
	var note: Array = s.sillabe_e_ottava(voce, linea, -12, 7)
	t.eq(note.size(), 2, "ogni nota ha la sua sillaba")
	t.eq(int(note[0]["midi"]), 60, "l'ottava comoda è applicata")
	t.ok(str(note[0]["syl"]) in ["la", "wa", "na", "ma"],
			"la nota lunga si canta aperta («laa», «waa»)")
	for n in note:
		t.ok(str(n["syl"]).length() >= 2, "sillabe vere, mai vuote")


func _test_audio(t, s: GDScript, ch: GDScript) -> void:
	var voce: Dictionary = ch.voice({"name": "Coro", "archetype": "coniglio",
			"size": 0.72, "fur": "def"})
	var wav: AudioStreamWAV = ch.canta_linea(voce,
			[{"b": 0.0, "beats": 1.0, "midi": 72, "syl": "la"},
			{"b": 1.0, "beats": 1.0, "midi": 76, "syl": "wa"}], 2.0, 90.0)
	t.ok(wav != null and wav.data.size() > 0, "canta_linea rende audio vero")
	var attesi := int(2.0 * 60.0 / 90.0 * 22050) * 2
	t.almost(float(wav.data.size()), float(attesi),
			"la linea dura ESATTAMENTE i suoi beat (sincrono garantito)", 4.0)
	var picco := 0
	for i in range(0, wav.data.size() - 1, 2):
		picco = maxi(picco, absi(wav.data.decode_s16(i)))
	t.ok(picco > 8000, "…e non è silenzio: si canta davvero (picco %d)" % picco)

	var canzone: Dictionary = s.componi(31)
	var cassa: AudioStreamWAV = s._rendi_carillon(canzone)
	var attesi_c := int(18.0 * 60.0 / float(canzone["bpm"]) * 22050) * 2
	t.almost(float(cassa.data.size()), float(attesi_c),
			"la cassettina dura quanto il coro", 4.0)


func _test_riposo(t, s: GDScript) -> void:
	var conc = t.stage(s.new())
	conc.avvia(null)               # manovella senza carillon: nulla
	t.ok(not conc._cantando, "senza carillon non si canta")
	conc._riposo = 10.0
	conc.avvia(t.stage(Node3D.new()))
	t.ok(not conc._cantando, "il riposo fra concertini si rispetta")


func _test_contratti(t) -> void:
	var inter := FileAccess.get_file_as_string("res://scenes/interact/Interactions.gd")
	t.ok(inter.contains("concertino") and inter.contains("avvia"),
			"la manovella del carillon chiama il concertino")
	var cozy := FileAccess.get_file_as_string("res://scenes/world/CozyWorld.gd")
	t.ok(cozy.contains("Concertino.gd"), "CozyWorld monta il concertino")
	var sfx := FileAccess.get_file_as_string("res://audio/Sfx.gd")
	t.ok(sfx.contains("func duck_music"), "la musica di fondo sa inchinarsi")
