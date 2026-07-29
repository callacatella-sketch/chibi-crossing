extends RefCounted
## IL GENOMA ESTETICO — la prima pietra dell'estetista.
##
## Prima di poter aprire un salone bisogna poter cambiare un aspetto, e
## per cambiarlo bisogna sapere COSA si può cambiare. Questo test protegge
## la linea di confine, che è tutto il punto della meccanica: cambiare
## pettinatura non è cambiare persona.
##
## E protegge il difetto grave che questa linea ha stanato: la voce del
## Chibiese nasceva da nome+PELO+archetipo+taglia. Finché il pelo era per
## sempre, andava bene. Dal momento in cui esiste una tinta, quella
## formula ti cambia il TIMBRO — cioè chi sei a orecchio — ogni volta che
## cambi colore. Adesso la voce ha un seme suo, piantato alla nascita.

const DNA := preload("res://scenes/npc/ChibiDNA.gd")
const CHB := preload("res://audio/Chibiese.gd")
const VIS := preload("res://scenes/npc/Visitor.gd")

## Quello che l'estetista non deve poter toccare MAI: il corpo con cui sei
## nato, chi sei, e la tua voce.
const INTOCCABILI := ["name", "seed", "voce_seed", "archetype", "size",
		"head_scale", "sogno", "tratti", "weights", "indole", "quirk",
		"eye_r", "eye_gap", "eye_h", "ear_len", "ear_ang", "tail", "label"]


func run(t) -> void:
	_test_il_confine(t)
	_test_la_voce_non_si_tocca(t)
	_test_applicazione_pura(t)
	_test_il_corpo_si_rifa(t)


## LA LINEA DI CONFINE: cosa è estetica e cosa è identità.
func _test_il_confine(t) -> void:
	var d: Dictionary = DNA.generate(11)
	for g in DNA.ESTETICI:
		t.ok(d.has(str(g)),
				"il gene estetico '%s' esiste davvero nel genoma" % g)
	for g in INTOCCABILI:
		t.ok(not str(g) in DNA.ESTETICI,
				"'%s' NON è estetica: è chi sei, o il corpo con cui sei nato" % g)
	# `estetica_di` estrae esattamente quelli, né uno di più né uno di meno
	var e: Dictionary = DNA.estetica_di(d)
	t.eq(e.size(), DNA.ESTETICI.size(),
			"estetica_di torna tutti e soli i geni estetici")
	for g in DNA.ESTETICI:
		t.ok(e.has(str(g)), "…compreso '%s'" % g)


## LA VOCE. Il difetto che questa meccanica avrebbe portato con sé, se
## nessuno l'avesse cercato: una tinta ti cambiava il timbro.
func _test_la_voce_non_si_tocca(t) -> void:
	var d: Dictionary = DNA.generate(2024)
	t.ok(d.has("voce_seed"), "il genoma porta il seme della voce")
	var prima: Dictionary = CHB.voice(d)

	# si cambia OGNI gene estetico, tutti insieme: la voce non si muove
	var d2: Dictionary = DNA.con_estetica(d, {
		"fur": "112233", "fur2": "001122", "belly": "445566",
		"inner_ear": "778899", "dress": "aabbcc", "dress2": "ddeeff",
		"blush": 0.1, "freckles": true, "fluff": 0.99,
		"brow": "dritte", "brow_folto": 1.2, "brow_arco": 0.8, "brow_len": 1.1,
		"bocca": "larga", "bocca_larg": 1.1, "bocca_spess": 1.2, "acc": "fiocco"})
	var dopo: Dictionary = CHB.voice(d2)
	for campo in ["pitch", "formant", "rate", "rough", "sing", "breath", "key"]:
		t.eq(str(prima[campo]), str(dopo[campo]),
				"cambiando TUTTA l'estetica, '%s' della voce non si muove" % campo)

	# e resta la voce di sempre per chi è nato prima del seme (i vecchi
	# salvataggi): si ripiega sulla formula storica, non sul silenzio
	var vecchio: Dictionary = d.duplicate(true)
	vecchio.erase("voce_seed")
	var v: Dictionary = CHB.voice(vecchio)
	t.ok(float(v["pitch"]) > 0.0,
			"un genoma nato prima del seme ha comunque la sua voce")
	t.ok(_sorgente("res://audio/Chibiese.gd").contains("dna.has(\"voce_seed\")"),
			"…col ripiego esplicito sulla formula vecchia")


## L'APPLICAZIONE È PURA e SCARTA il non-estetico: è la guardia contro
## l'errore che rovinerebbe tutto — passare per sbaglio un sogno o un
## nome dentro un cambio di look.
func _test_applicazione_pura(t) -> void:
	var d: Dictionary = DNA.generate(7)
	var copia: Dictionary = d.duplicate(true)
	var nuovo: Dictionary = DNA.con_estetica(d, {
		"fur": "e8b4a0",                       # estetica: passa
		"sogno": "guerriero", "name": "Impostore", "size": 9.9,
		"voce_seed": 1, "archetype": "orsetto"})   # identità: scartati
	t.eq(str(nuovo["fur"]), "e8b4a0", "il gene estetico arriva")
	for g in ["sogno", "name", "size", "voce_seed", "archetype"]:
		t.eq(str(nuovo[g]), str(d[g]),
				"'%s' resta quello di prima, anche se glielo passi" % g)
	t.eq(str(d), str(copia), "e il genoma di partenza non viene toccato (è pura)")
	# un gene inventato non entra di straforo
	var strano: Dictionary = DNA.con_estetica(d, {"colore_anima": "x"})
	t.ok(not strano.has("colore_anima"),
			"un gene che non esiste non entra nel genoma")


## IL CORPO SI RIFÀ DAVVERO, e chi lo abita resta lui.
func _test_il_corpo_si_rifa(t) -> void:
	var v: Node3D = t.stage(VIS.new())
	v.set("species", "chibi")
	v.set("dna", DNA.generate(2024))
	v._ready()
	var d0: Dictionary = (v.get("dna") as Dictionary).duplicate(true)
	var voce0: Dictionary = v.get("_voice")

	var cambiato: bool = v.rifai_il_look({"fur": "e8b4a0", "brow": "decise"})
	t.ok(cambiato, "una seduta che cambia qualcosa dice di sì")
	var d1: Dictionary = v.get("dna")
	t.eq(str(d1["fur"]), "e8b4a0", "il pelo è quello nuovo")
	t.eq(str(d1["brow"]), "decise", "e le sopracciglia pure")
	t.eq(str(d1["name"]), str(d0["name"]), "il nome è lo stesso")
	t.eq(str(d1["sogno"]), str(d0["sogno"]), "il sogno è lo stesso")
	t.almost(float(d1["size"]), float(d0["size"]), "la taglia è la stessa")
	t.eq(str((v.get("_voice") as Dictionary)["key"]), str(voce0["key"]),
			"E LA VOCE È LA STESSA: una tinta non cambia chi sei a orecchio")
	t.ok((v.get("_vis") as Node3D).get_child_count() > 0,
			"il corpo è stato rimontato, non lasciato vuoto")
	t.ok(v.get("_face") != null, "…e il volto vivo è tornato al suo posto")
	t.ok(not (v.get("_c_arms") as Array).is_empty(),
			"…con le braccia nuove agganciate")

	# una seduta che non cambia niente non racconta trasformazioni
	t.ok(not v.rifai_il_look({"fur": "e8b4a0"}),
			"una seduta identica a com'eri torna false")
	t.ok(not v.rifai_il_look({"sogno": "cuoco"}),
			"e una che tocca solo l'identità non cambia niente: torna false")

	# il cablaggio: il montaggio è una funzione richiamabile, non venti
	# righe dentro `_ready` (era il motivo per cui un corpo non si poteva
	# rifare)
	var src := _sorgente("res://scenes/npc/Visitor.gd")
	t.ok(src.contains("func _monta_corpo"),
			"il corpo si monta da una funzione, non da _ready")
	t.ok(_corpo(src, "rifai_il_look").contains("_clear_can"),
			"il bricco in zampa si stacca: resterebbe appeso a un braccio morto")
	t.ok(not _corpo(src, "rifai_il_look").contains("CHIBIESE.voice"),
			"la voce NON si ricalcola: sarebbe l'occasione buona per sbagliare")


func _corpo(src: String, nome: String) -> String:
	var da := src.find("func " + nome)
	if da < 0:
		return ""
	var fine := src.find("\nfunc ", da + 1)
	return src.substr(da, (fine - da) if fine > da else -1)


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""
