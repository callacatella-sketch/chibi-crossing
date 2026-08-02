extends RefCounted
## IL MENÙ CHE SENTE.
##
## Il titolo non è più una cartolina: legge il salvataggio e ne mostra il
## villaggio VERO — l'albero alla taglia che ha raggiunto, i vicini che ci
## abitano davvero, e un CLIMA emotivo che comanda cielo, luce, petali,
## posa di Mochi e cosa stanno facendo tutti.
##
## È un sistema che si rompe in silenzio: se il clima sbaglia, il menù è
## comunque un bel menù — solo, il giorno dopo un lutto ti accoglie con i
## coriandoli. Nessun crash, nessun errore, e la cosa più fredda che
## questo gioco possa fare. Perciò qui si controlla la REGIA: quale clima
## esce da quale villaggio, e cosa fanno i vicini in ognuno.

const RIASSUNTO := preload("res://scenes/ui/RiassuntoSalvataggio.gd")
const TITOLO := preload("res://scenes/ui/TitleScreen.gd")
const ALBERO := preload("res://scenes/world/AlberoGeo.gd")
const L := preload("res://systems/L10n.gd")


func run(t) -> void:
	_test_villaggio_vuoto_non_rompe_niente(t)
	_test_il_clima_di_ogni_villaggio(t)
	_test_il_lutto_batte_tutto(t)
	_test_albero_alla_taglia_vera(t)
	_test_la_regia_dei_mestieri(t)
	_test_nel_lutto_non_gioca_nessuno(t)
	_test_la_vivacita_segue_il_clima(t)
	_test_ogni_sottotitolo_e_tradotto(t)


## Un salvataggio finto ma della forma vera.
static func _villaggio(giorno: int, quanti: int, momenti_per: int,
		amici := 0, extra := {}) -> Dictionary:
	var residenti := []
	var fili := {}
	for i in quanti:
		residenti.append({"dna": {"name": "N%d" % i, "size": 1.0},
				"label": "il vicino %d" % i, "friend": 4 if i < amici else 1})
		fili["N%d" % i] = {"momenti": [], "n": momenti_per, "s": "adulto"}
	var d := {"day": giorno, "residents": residenti, "legami": fili}
	d.merge(extra, true)
	return d


# ------------------------------------------------------- la robustezza

## IL MENÙ NON SI ROMPE MAI. È l'unica schermata da cui si può ancora
## rimediare a un salvataggio andato storto: se si piantasse lì, il
## giocatore non avrebbe più nessun posto dove andare.
func _test_villaggio_vuoto_non_rompe_niente(t) -> void:
	for rotto: Variant in [{}, {"day": "non un numero"},
			{"residents": "nemmeno questo"}, {"legami": 42},
			{"residents": [null, 7, {}, {"dna": "no"}]},
			{"day": -100, "cuore_mochi": "boh"}]:
		var r = RIASSUNTO.da_salvataggio(rotto if rotto is Dictionary else {})
		t.ok(r.clima() in ["attesa", "serena", "allegria", "armonia",
				"malinconia", "commiato", "lutto"],
				"un salvataggio storto dà comunque un clima buono (%s)" % r.clima())
		t.ok(r.giorno >= 1, "e almeno il giorno uno")
		t.ok(r.stage_albero() > 0.0, "e un albero che esiste")
		t.ok(str(r.sottotitolo()) != "", "e qualcosa da scrivere sotto al titolo")


# ---------------------------------------------------------- i climi

func _test_il_clima_di_ogni_villaggio(t) -> void:
	var casi := [
		["attesa", _villaggio(2, 0, 0)],
		["serena", _villaggio(9, 3, 3)],
		["allegria", _villaggio(22, 5, 4, 2)],
		["armonia", _villaggio(46, 7, 9, 5)],
		["malinconia", _villaggio(52, 4, 8, 2, {"cuore_mochi": {"umore": -0.6}})],
		["commiato", _villaggio(60, 5, 9, 3, {"congedo": {"nome": "Nocciola"}})],
		["lutto", _villaggio(64, 5, 10, 4,
				{"lutto": {"nome": "Nocciola", "giorno_inizio": 62}})],
	]
	for caso in casi:
		var r = RIASSUNTO.da_salvataggio(caso[1])
		t.eq(r.clima(), str(caso[0]),
				"il villaggio «%s» produce il suo clima" % caso[0])


## IL LUTTO STA SOPRA TUTTO. Un villaggio può essere pieno di amici, di
## storia e di fiori e aver perso qualcuno ieri: quel giorno il menù è
## grigio comunque. Se la statistica dell'allegria coprisse il lutto,
## sarebbe la cosa più fredda che il gioco possa fare.
func _test_il_lutto_batte_tutto(t) -> void:
	var pieno := _villaggio(80, 7, 20, 6)      # il villaggio più felice possibile
	var r = RIASSUNTO.da_salvataggio(pieno)
	t.eq(r.clima(), "armonia", "senza lutto, un villaggio così è in armonia")
	pieno["lutto"] = {"nome": "Nocciola", "giorno_inizio": 79}
	t.eq(RIASSUNTO.da_salvataggio(pieno).clima(), "lutto",
			"con un lutto fresco, l'armonia NON lo copre")
	# …e dopo, il villaggio ricomincia a respirare (non dimentica: il
	# fiore del ricordo resta nel gioco — è il MENÙ che torna a colori)
	pieno["lutto"] = {"nome": "Nocciola",
			"giorno_inizio": 80 - RIASSUNTO.LUTTO_GIORNI - 1}
	t.eq(RIASSUNTO.da_salvataggio(pieno).clima(), "armonia",
			"passati i giorni del lutto il menù torna a respirare")


## FONTE UNICA: l'albero del menù è quello del villaggio, non una copia
## che gli somiglia. Se un domani la crescita cambia in AlberoGeo, il
## menù cambia con lei — e se qualcuno ricopia la formula, qui è rosso.
func _test_albero_alla_taglia_vera(t) -> void:
	for giorno in [1, 5, 12, 30, 60, 200]:
		var r = RIASSUNTO.da_salvataggio({"day": giorno})
		t.almost(r.stage_albero(), ALBERO.stage_per_giorno(giorno),
				"al giorno %d il menù mostra l'albero del villaggio" % giorno, 0.0001)
	# e cresce davvero: il giorno 40 non è il giorno 2
	t.ok(RIASSUNTO.da_salvataggio({"day": 40}).stage_albero()
			> RIASSUNTO.da_salvataggio({"day": 2}).stage_albero() * 2.0,
			"un villaggio vissuto ha un albero visibilmente più grande")


# ------------------------------------------------------- i mestieri

## UNA RINCORSA SI FA IN DUE. Con un vicino solo, «rincorre» sarebbe uno
## che gira intorno all'albero da solo — che è tutta un'altra faccenda, e
## neanche allegra.
func _test_la_regia_dei_mestieri(t) -> void:
	for clima in ["attesa", "serena", "allegria", "armonia", "malinconia",
			"commiato", "lutto"]:
		for quanti in range(0, 8):
			var m: Array = TITOLO._mestieri_per(clima, quanti)
			t.eq(m.size(), quanti,
					"%s con %d vicini: un mestiere a testa" % [clima, quanti])
			t.eq(m.count("rincorre"), m.count("scappa"),
					"%s con %d: chi insegue ha sempre qualcuno da inseguire"
					% [clima, quanti])
			for voce in m:
				t.ok(str(voce) in TITOLO.ATTORE.MESTIERI,
						"«%s» è un mestiere che esiste davvero" % voce)


## NEL LUTTO NON GIOCA NESSUNO. Non è che si muovono di meno: si muovono
## in un altro modo. Se anche un solo vicino si mettesse a rincorrere,
## la scena direbbe il contrario di quello che è successo.
func _test_nel_lutto_non_gioca_nessuno(t) -> void:
	for quanti in range(1, 8):
		var m: Array = TITOLO._mestieri_per("lutto", quanti)
		for allegro in ["rincorre", "scappa", "gioca", "altalena", "saluta"]:
			t.ok(not (allegro in m),
					"nel lutto nessuno fa «%s» (%d vicini)" % [allegro, quanti])
		t.ok(m.count("veglia") >= 1, "si veglia, invece")
	# e nei giorni pieni invece SÌ: la differenza si vede
	var festa: Array = TITOLO._mestieri_per("armonia", 6)
	t.ok(festa.count("rincorre") == 1 and festa.count("scappa") == 1,
			"in armonia c'è una coppia che si rincorre")


func _test_la_vivacita_segue_il_clima(t) -> void:
	var scala := {}
	for clima in ["lutto", "commiato", "malinconia", "attesa", "serena",
			"allegria", "armonia"]:
		# ogni clima si ottiene dal villaggio che lo produce davvero
		scala[clima] = _vivacita_di(clima)
	t.almost(float(scala["lutto"]), 0.0, "nel lutto il diorama si ferma", 0.001)
	t.ok(float(scala["armonia"]) > float(scala["allegria"]),
			"e l'armonia è la più viva di tutte")
	var prima := -1.0
	for clima in ["lutto", "commiato", "malinconia", "attesa", "serena",
			"allegria", "armonia"]:
		t.ok(float(scala[clima]) >= prima,
				"la vivacità sale col clima, senza salti indietro (%s)" % clima)
		prima = float(scala[clima])


static func _vivacita_di(clima: String) -> float:
	var casi := {
		"attesa": _villaggio(2, 0, 0),
		"serena": _villaggio(9, 3, 3),
		"allegria": _villaggio(22, 5, 4, 2),
		"armonia": _villaggio(46, 7, 9, 5),
		"malinconia": _villaggio(52, 4, 8, 2, {"cuore_mochi": {"umore": -0.6}}),
		"commiato": _villaggio(60, 5, 9, 3, {"congedo": {"nome": "X"}}),
		"lutto": _villaggio(64, 5, 10, 4, {"lutto": {"nome": "X", "giorno_inizio": 63}}),
	}
	return float(RIASSUNTO.da_salvataggio(casi[clima]).vivacita())


# ------------------------------------------------------- la traduzione

## Le frasi del sottotitolo non passano da un `L10n.t("…")` letterale (le
## sceglie un `match`), quindi la guardia dei sorgenti non le vede: se ne
## aggiungesse una senza tradurla, il menù inglese mostrerebbe una riga in
## italiano e nessun test diventerebbe rosso. Qui si prendono TUTTE le
## frasi che il menù può dire e si pretende l'inglese per ognuna.
func _test_ogni_sottotitolo_e_tradotto(t) -> void:
	var prima := L.lingua_corrente()
	L.imposta("en")
	var viste := {}
	for clima in ["attesa", "serena", "allegria", "armonia", "malinconia",
			"commiato", "lutto"]:
		var casi := {
			"attesa": _villaggio(2, 0, 0),
			"serena": _villaggio(9, 3, 3),
			"allegria": _villaggio(22, 5, 4, 2),
			"armonia": _villaggio(46, 7, 9, 5),
			"malinconia": _villaggio(52, 4, 8, 2, {"cuore_mochi": {"umore": -0.6}}),
			"commiato": _villaggio(60, 5, 9, 3, {"congedo": {"nome": "X"}}),
			"lutto": _villaggio(64, 5, 10, 4, {"lutto": {"nome": "X", "giorno_inizio": 63}}),
		}
		var frase := str(RIASSUNTO.da_salvataggio(casi[clima]).sottotitolo())
		viste[frase] = true
		t.ok(L.t(frase) != frase,
				"il sottotitolo del clima «%s» è tradotto in inglese" % clima)
	t.ok(viste.size() >= 6,
			"e i climi non dicono tutti la stessa cosa (%d frasi diverse)"
			% viste.size())
	L.imposta(prima)
