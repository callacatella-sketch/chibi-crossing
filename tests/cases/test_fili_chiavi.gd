extends RefCounted
## LE CHIAVI DEL FILO ROSSO — un filo per persona, mai un fantasma.
##
## Le chiavi di `Legami._fili` sono il NOME del DNA ("Pepita"). Ma per
## tutto il gioco girano anche le LABEL ("la volpina Pepita"): i toast, le
## lettere, e persino `Visitors._animi` sono indicizzati COSÌ. Basta un
## chiamante distratto e il momento finisce in un filo separato che
## nessuno legge più — ed è successo davvero all'ADDIO della diserzione,
## il momento più importante che un filo possa avere.
##
## Questo test sorveglia l'INTERA CLASSE del difetto, non il caso singolo:
##  • nome_da_chiave riporta ogni label al suo nome, per ogni archetipo,
##    prendendo i prefissi dalla fonte unica (ChibiDNA.DESCR);
##  • `momento` scritto con una label finisce nel filo GIUSTO (la difesa
##    nel cuore: nessun chiamante può più creare un fantasma);
##  • i salvataggi già scritti si MIGRANO: i fantasmi si riversano nel
##    filo vero senza duplicati e senza perdere né momenti né il ricordo
##    del DNA di chi è partito;
##  • REGRESSIONE DELL'ADDIO: nessun call site passa più una label.

const LEGAMI := "res://scenes/world/Legami.gd"
const DNA := "res://scenes/npc/ChibiDNA.gd"


func run(t) -> void:
	var lg: GDScript = load(LEGAMI)
	t.ok(lg != null and lg.can_instantiate(), "Legami.gd compila")
	if lg == null or not lg.can_instantiate():
		return

	_test_nome_da_chiave(t, lg)
	_test_difesa_nel_cuore(t, lg)
	_test_migrazione(t, lg)
	_test_call_site(t)
	_test_diserzione_vera(t)


func _test_nome_da_chiave(t, lg: GDScript) -> void:
	var dna_s: GDScript = load(DNA)
	# ogni archetipo, con la label COSTRUITA come la costruisce il DNA
	for arche in dna_s.ARCHETYPES:
		var label := "%s %s" % [dna_s.DESCR[arche], "Pepita"]
		t.eq(lg.nome_da_chiave(label), "Pepita",
				"«%s» → «Pepita»" % label)
	t.eq(lg.nome_da_chiave("Pepita"), "Pepita",
			"un nome resta sé stesso (nessuna mutilazione)")
	t.eq(lg.nome_da_chiave(""), "", "la chiave vuota non esplode")
	# una stringa con uno spazio ma senza un prefisso NOTO resta intatta:
	# meglio non toccare che sbagliare a tagliare
	t.eq(lg.nome_da_chiave("Anna Maria"), "Anna Maria",
			"senza un prefisso della fonte unica non si taglia nulla")


func _test_difesa_nel_cuore(t, lg: GDScript) -> void:
	var dna_s: GDScript = load(DNA)
	var l = t.stage(lg.new())
	var label := "%s %s" % [dna_s.DESCR["volpina"], "Pepita"]

	# prima un momento col nome, poi uno con la LABEL: devono finire
	# nello STESSO filo (è la difesa che rende impossibile il fantasma)
	l.momento("Pepita", "benvenuto", "")
	l.momento(label, "addio", "se n'è andata")
	var suoi: Array = l.momenti_di("Pepita")
	t.eq(suoi.size(), 2,
			"nome e label finiscono nello stesso filo (%d momenti)" % suoi.size())
	var tipi: Array = []
	for m in suoi:
		tipi.append(str(m.get("t", "")))
	t.ok("addio" in tipi,
			"REGRESSIONE FILO FANTASMA: l'addio è nel filo di Pepita")
	t.eq((l.momenti_di(label) as Array).size(), 2,
			"…e lo si ritrova anche interrogando con la label")
	t.eq((l.get("_fili") as Dictionary).size(), 1,
			"esiste UN SOLO filo, non due")


func _test_migrazione(t, lg: GDScript) -> void:
	var dna_s: GDScript = load(DNA)
	var label := "%s %s" % [dna_s.DESCR["volpina"], "Pepita"]

	# un salvataggio SCRITTO PRIMA della correzione: il filo vero e il
	# suo fantasma con dentro l'addio
	var salvato := {
		"Pepita": {"giorno_arrivo": 10, "momenti": [
			{"d": 10, "t": "benvenuto", "x": ""},
			{"d": 30, "t": "piatto", "x": "zuppa"},
		]},
		label: {"giorno_arrivo": 44, "momenti": [
			{"d": 44, "t": "addio", "x": "se n'è andata"},
			{"d": 30, "t": "piatto", "x": "zuppa"},
		], "dna_ricordo": {"name": "Pepita"}},
		"Miele": {"giorno_arrivo": 5, "momenti": [{"d": 5, "t": "trasloco", "x": ""}]},
	}
	var migrato: Dictionary = lg.migra_fili(salvato)

	t.ok(not migrato.has(label), "il filo fantasma non esiste più")
	t.eq(migrato.size(), 2, "restano i due fili veri (Pepita, Miele)")
	var pepita: Dictionary = migrato["Pepita"]
	var tipi: Array = []
	for m in (pepita["momenti"] as Array):
		tipi.append(str(m.get("t", "")))
	t.ok("addio" in tipi, "l'ADDIO è stato salvato dal fantasma")
	t.ok("benvenuto" in tipi and "piatto" in tipi, "…e i momenti veri ci sono ancora")
	t.eq((pepita["momenti"] as Array).size(), 3,
			"il piatto doppio (stesso giorno, stesso tipo) NON si duplica")
	t.eq(int(pepita["giorno_arrivo"]), 10,
			"resta il giorno d'arrivo più antico, non quello del fantasma")
	t.ok(pepita.has("dna_ricordo"),
			"il ricordo del DNA di chi è partito non si perde")
	# i giorni restano in ordine: il filo si racconta dal principio
	var giorni: Array = []
	for m in (pepita["momenti"] as Array):
		giorni.append(int(m.get("d", 0)))
	var ordinati := giorni.duplicate()
	ordinati.sort()
	t.eq(giorni, ordinati, "i momenti restano in ordine di giorno")
	# un salvataggio già sano non viene toccato
	var sano := {"Miele": {"giorno_arrivo": 5, "momenti": []}}
	t.eq(str(lg.migra_fili(sano)), str(sano),
			"un salvataggio già corretto passa indenne")


func _test_call_site(t) -> void:
	# REGRESSIONE DELL'INTERA CLASSE: nessun chiamante scrive un momento
	# con una LABEL. Copre le due forme in uso nel repo:
	#   call_group("legami", "momento", <chi>, …) / call("momento", <chi>, …)
	#   legami.momento(<chi>, …)
	# <chi> deve venire dal DNA o da una variabile che si chiama nome.
	var sospetti: Array = []
	for percorso in ["res://scenes/npc/Visitors.gd", "res://scenes/world/Congedo.gd",
			"res://scenes/interact/RichiesteFoto.gd", "res://scenes/interact/Nascondino.gd",
			"res://scenes/npc/Commissioni.gd", "res://scenes/world/Onsen.gd",
			"res://scenes/levels/DebugHarness.gd"]:
		var src := FileAccess.get_file_as_string(percorso)
		if src == "":
			continue
		for forma in ["\"momento\", ", ".momento("]:
			var da := 0
			while true:
				var i := src.find(forma, da)
				if i < 0:
					break
				da = i + forma.length()
				var arg := src.substr(da, 220)
				var virgola := arg.find(",")
				if virgola < 0:
					continue
				var chi := arg.substr(0, virgola).strip_edges()
				if chi.contains("label") and not chi.contains("dna") \
						and not chi.contains("nome"):
					sospetti.append("%s → momento(%s, …)"
							% [percorso.get_file(), chi])
	t.eq(sospetti.size(), 0,
			"nessun momento scritto con una LABEL (fili fantasma): %s"
			% str(sospetti))
	# e la guardia sa DAVVERO accorgersene (se non sapesse fallire non
	# varrebbe nulla): la si prova su una riga finta col difetto
	var finta := "legami.call(\"momento\", label, \"addio\", animo.racconta())"
	var arg2 := finta.substr(finta.find("\"momento\", ") + 11, 60)
	var chi2 := arg2.substr(0, arg2.find(",")).strip_edges()
	t.ok(chi2.contains("label") and not chi2.contains("dna"),
			"la guardia riconosce una label passata a momento (%s)" % chi2)


## LA PROVA CHE CONTA: una diserzione VERA, dal congedo al filo.
## Non si controlla il sorgente: si fa partire un residente e si guarda
## dove finisce il suo addio. È il percorso che il bug rompeva.
func _test_diserzione_vera(t) -> void:
	var vs: GDScript = load("res://scenes/npc/Visitors.gd")
	var lg: GDScript = load("res://scenes/world/Legami.gd")
	var dna_s: GDScript = load(DNA)
	if vs == null or not vs.can_instantiate():
		t.ok(false, "Visitors.gd non compilabile")
		return

	var visitors = t.stage(vs.new())
	# i casi girano tutti nello STESSO frame: un Legami staged da una
	# prova precedente e' ancora nel gruppo, e _congeda prende il PRIMO
	# che trova (col break). Qui deve esserci solo il nostro.
	for altro in visitors.get_tree().get_nodes_in_group("legami"):
		altro.remove_from_group("legami")
	var legami = t.stage(lg.new())
	legami.add_to_group("legami")

	var gene: Dictionary = dna_s.generate(4242)
	var nome := str(gene["name"])
	var label := str(gene["label"])
	t.ok(label != nome and label.ends_with(nome),
			"il residente ha label «%s» e nome «%s»: sono diversi" % [label, nome])

	# il filo di chi sta per partire esiste già (è arrivato, gli si è
	# voluto bene) — poi se ne va
	legami.momento(nome, "benvenuto", "")
	# l'Animo va costruito come lo costruisce Visitors (setup dal genoma),
	# o racconta()/sfogo() non hanno di che parlare
	var animo = load("res://scenes/npc/Animo.gd").new()
	animo.setup(gene)
	animo.nome = label
	var r := {"dna": gene, "label": label, "cell": Vector2i(3, 2),
			"node": null, "friend": 3}
	# _residents e' un Array[Dictionary] TIPIZZATO: un set() con una lista
	# non tipizzata non attecchisce e resta vuoto — si muta il suo
	(visitors.get("_residents") as Array).append(r)
	(visitors.get("_animi") as Dictionary)[label] = animo
	t.ok(visitors.get_tree() != null, "SONDA: Visitors e' nell'albero")
	t.eq(visitors.get_tree().get_nodes_in_group("legami").size(), 1,
			"SONDA: il gruppo legami ha esattamente il nostro nodo")
	visitors.call("_congeda", 0, r, animo)

	var suoi: Array = legami.momenti_di(nome)
	var tipi: Array = []
	for m in suoi:
		tipi.append(str(m.get("t", "")))
	t.ok("addio" in tipi,
			"DISERZIONE VERA: l'addio è nel filo di %s (%s)" % [nome, str(tipi)])
	t.eq((legami.get("_fili") as Dictionary).size(), 1,
			"…e non è nato nessun filo fantasma")
	t.ok("benvenuto" in tipi,
			"…accanto al benvenuto: la storia intera in un filo solo")
