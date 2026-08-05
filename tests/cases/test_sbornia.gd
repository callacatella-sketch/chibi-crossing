extends RefCounted
## LA SBORNIA DI SUCCO DI MELA — le regole del bicchiere di troppo.
##
## Perche' questi test: la curva decide QUANDO il mondo comincia a
## ondeggiare (due succhi devono restare due succhi) e lo smaltimento
## decide che la sbornia PASSA — sbagliarli fa un villaggio o troppo
## sobrio o pateticamente sbronzo per sempre. E il velo e' un nodo con
## uno shader: se il cablaggio salta, tutta la meccanica e' un E che
## ruba noccioline senza far ridere nessuno.

const SBOR := preload("res://scenes/interact/Sbornia.gd")


func run(t) -> void:
	_test_la_curva(t)
	_test_lo_smaltimento(t)
	_test_le_battute(t)
	_test_il_cablaggio(t)


## Due succhi sono solo due succhi; dal terzo si comincia; a otto il
## mondo e' TUTTO scarabocchio; e in mezzo si sale senza mai scendere.
func _test_la_curva(t) -> void:
	t.almost(SBOR.livello(0.0), 0.0, "a stomaco vuoto il mondo e' dritto", 0.001)
	t.almost(SBOR.livello(2.0), 0.0, "due succhi sono solo due succhi", 0.001)
	t.ok(SBOR.livello(3.0) > 0.02, "dal terzo bicchiere si comincia")
	t.almost(SBOR.livello(8.0), 1.0, "a otto bicchieri e' tutto scarabocchio", 0.001)
	t.almost(SBOR.livello(11.0), 1.0, "…e oltre non si peggiora: e' gia' il fondo", 0.001)
	var prima := 0.0
	for b in 20:
		var liv := SBOR.livello(float(b) * 0.5)
		t.ok(liv >= prima, "la curva sale sempre (a %.1f bicchieri)" % (float(b) * 0.5))
		prima = liv
	t.ok(SBOR.livello(5.0) > 0.3 and SBOR.livello(5.0) < 0.7,
			"a meta' strada si ondeggia ma si cammina (%.2f)" % SBOR.livello(5.0))


## La sbornia passa da sola, mai sotto zero, e coi tempi giusti:
## dal pieno si torna sobri in una decina di minuti, non in un'era.
func _test_lo_smaltimento(t) -> void:
	t.ok(SBOR.smaltisci(6.0, 40.0) < 6.0, "il tempo smaltisce")
	t.almost(SBOR.smaltisci(0.4, 100000.0), 0.0, "mai sotto zero: niente postumi", 0.001)
	var b := 8.0
	var minuti := 0
	while SBOR.livello(b) > 0.0 and minuti < 60:
		b = SBOR.smaltisci(b, 60.0)
		minuti += 1
	t.ok(minuti >= 6 and minuti <= 20,
			"dal pieno si torna dritti in %d minuti: ne' un lampo ne' un'era" % minuti)


## Le battute cadono sui bicchieri che contano, e ognuna ha la sua voce
## inglese (la chiave e' la frase italiana: se una manca, il guardiano
## della localizzazione la becca — qui si controlla che ci SIANO).
func _test_le_battute(t) -> void:
	t.ok(SBOR.BATTUTE.has(3), "al terzo bicchiere c'e' una battuta: e' l'inizio")
	t.ok(SBOR.BATTUTE.has(int(SBOR.PIENA)), "all'ultimo bicchiere c'e' il gran finale")
	t.ok(SBOR.COSTO > 0, "il succo si paga: l'economia gentile non regala vizi")
	var src := _sorgente("res://scenes/interact/Sbornia.gd")
	for chiave in ["L10n.t(", "L10n.tf("]:
		t.ok(src.contains(chiave), "le frasi passano da %s: niente italiano crudo" % chiave)


## Il velo esiste, legge lo schermo, ha la manopola giusta; il nodo sta
## nel MainLevel; e bevi() paga PRIMA di versare.
func _test_il_cablaggio(t) -> void:
	var sh := _sorgente("res://scenes/interact/sbornia.gdshader")
	t.ok(sh.contains("hint_screen_texture"),
			"lo shader legge lo schermo: e' un velo, non un rettangolo")
	t.ok(sh.contains("uniform float sbronza"),
			"la manopola si chiama `sbronza` (Sbornia.gd la scrive per nome)")
	var tscn := _sorgente("res://scenes/levels/MainLevel.tscn")
	t.ok(tscn.contains('[node name="Sbornia"'),
			"il nodo sta nel MainLevel: senza, il bar serve succhi immaginari")
	var src := _sorgente("res://scenes/interact/Sbornia.gd")
	var corpo := _corpo(src, "bevi")
	t.ok(corpo.contains("add_nuts"), "bevi() paga il barista")
	t.ok(corpo.find("return") < corpo.find("_bicchieri += "),
			"…e se le noccioline non bastano si esce PRIMA di versare")
	t.ok(_corpo(src, "_build_ui").contains("layer = 7"),
			"il velo sta sopra il HUD: anche le barrette escono scarabocchiate")


func _corpo(src: String, fn: String) -> String:
	var i := src.find("func %s(" % fn)
	if i < 0:
		return ""
	var j := src.find("\nfunc ", i)
	return src.substr(i, (j - i) if j > i else -1)


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""
