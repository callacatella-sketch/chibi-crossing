extends RefCounted
## LE PROMESSE — un appuntamento con una persona, ancorato a un fenomeno
## del mondo. Il test difende le regole di DESIGN, non solo il codice:
##
##  • si promette solo ciò che il mondo sa PREVEDERE (mai l'arcobaleno:
##    l'incerto è un dono, non un appuntamento);
##  • il giorno promesso è sempre nel FUTURO, e cade davvero in un giorno
##    in cui quel fenomeno esiste (la bruma solo d'autunno, la prima neve
##    solo al primo giorno d'inverno);
##  • ogni finestra del mattino CONTIENE l'ora del risveglio: chi dorme
##    non manca mai un appuntamento per costruzione;
##  • il vicino aspetta OLTRE la fine del fenomeno (trentun secondi di
##    bruma non bastano ad attraversare il villaggio);
##  • la scelta è DETERMINISTICA: ricaricare la partita non riscrive un
##    appuntamento già preso;
##  • una promessa alla volta (due «adesso» sono ansia);
##  • NIENTE ANSIA: mancare non toglie nulla — nessun punto, nessun
##    rancore, nessun blocco — e restituisce una lettera;
##  • se il fenomeno non è mai venuto NON arriva la lettera del rimpianto
##    (non c'è nessuna scena da rimpiangere);
##  • i due posti fisici esistono e nessun HUD li duplica.

const PROM := "res://scenes/npc/Promesse.gd"
const DN := "res://scenes/world/DayNight.gd"


func run(t) -> void:
	var p: GDScript = load(PROM)
	t.ok(p != null and p.can_instantiate(), "Promesse.gd compila")
	if p == null or not p.can_instantiate():
		return

	_test_solo_il_certo(t, p)
	_test_giorno_promesso(t, p)
	_test_finestre(t, p)
	_test_determinismo(t, p)
	_test_testi(t, p)
	_test_niente_ansia(t, p)
	_test_due_posti(t, p)


func _test_solo_il_certo(t, p: GDScript) -> void:
	var fen: Dictionary = p.FEN
	t.ok(fen.size() >= 3, "ci sono almeno tre fenomeni (%d)" % fen.size())
	for incerto in ["arcobaleno", "stella_cadente", "meteora", "bottiglia"]:
		t.ok(not fen.has(incerto),
				"«%s» NON è un appuntamento: l'incerto è un dono" % incerto)
	# e ogni fenomeno in tabella sa dire quando accadrà
	for id in fen:
		t.ok(p.prossimo_giorno(str(id), 1) > 0,
				"«%s» è prevedibile: il vicino può prometterlo" % id)


func _test_giorno_promesso(t, p: GDScript) -> void:
	var dn: GDScript = load(DN)
	for oggi in [1, 5, 12, 20, 27, 40, 103]:
		for id in p.FEN:
			var g: int = p.prossimo_giorno(str(id), oggi)
			t.ok(g > oggi,
					"«%s» da G%d è promesso nel FUTURO (G%d)" % [id, oggi, g])
			t.ok(g <= oggi + int(dn.YEAR_DAYS),
					"…ed entro l'anno (G%d)" % g)
			# e cade davvero in un giorno in cui quel fenomeno esiste
			match str(id):
				"bruma":
					t.eq(p.stagione_di(g), 2,
							"la bruma è promessa in AUTUNNO (G%d)" % g)
				"neve":
					t.eq(p.stagione_di(g), 3,
							"la neve è promessa d'INVERNO (G%d)" % g)
					t.ok(p.stagione_di(g - 1) != 3,
							"…ed è la PRIMA neve, quella che si ricorda")


func _test_finestre(t, p: GDScript) -> void:
	for id in p.FEN:
		var f: Vector2 = p.finestra(str(id))
		t.ok(f.y > f.x, "«%s»: la finestra ha una durata" % id)
		t.ok(p.fine_attesa(str(id)) > f.y,
				"«%s»: il vicino aspetta OLTRE il fenomeno (%.2f > %.2f) — "
				% [id, p.fine_attesa(str(id)), f.y]
				+ "il tempo di attraversare il villaggio")
		# le finestre del MATTINO devono contenere l'ora del risveglio:
		# chi dorme si sveglia già dentro l'appuntamento
		if f.x < 0.5:
			t.ok(f.x <= float(p.ORA_RISVEGLIO) and f.y >= float(p.ORA_RISVEGLIO),
					"«%s»: chi dorme non lo manca per costruzione (%.2f..%.2f "
					% [id, f.x, f.y] + "contiene %.2f)" % p.ORA_RISVEGLIO)


func _test_determinismo(t, p: GDScript) -> void:
	var candidati := [
		{"label": "la volpina Pepita", "nome": "Pepita", "indole": "mattiniero"},
		{"label": "l'orsetto Miele", "nome": "Miele", "indole": "sognatore"},
		{"label": "il gattino Sesamo", "nome": "Sesamo", "indole": ""},
	]
	var prima: Dictionary = p.scegli(12, candidati)
	for i in 10:
		t.eq(str(p.scegli(12, candidati)), str(prima),
				"stesso giorno → STESSO appuntamento: ricaricare non lo riscrive")
	t.ok(str(p.scegli(13, candidati)) != str(prima),
			"un altro giorno → un altro appuntamento")
	t.eq(p.scegli(12, []), {}, "senza candidati non nasce nessuna promessa")

	# l'indole colora il fenomeno: il mattiniero conosce la bruma
	var solo_matt: Dictionary = p.scegli(7,
			[{"label": "x", "nome": "x", "indole": "mattiniero"}])
	t.eq(str(solo_matt.get("fen", "")), "bruma",
			"il mattiniero ti dà appuntamento alla bruma")
	var solo_sogn: Dictionary = p.scegli(7,
			[{"label": "y", "nome": "y", "indole": "sognatore"}])
	t.eq(str(solo_sogn.get("fen", "")), "neve",
			"il sognatore aspetta la prima neve")
	# e la promessa porta con sé tutto ciò che serve, nome DNA compreso
	for chiave in ["chi", "nome", "giorno", "fen", "esito", "arrivato"]:
		t.ok(solo_matt.has(chiave), "la promessa ha il campo «%s»" % chiave)


func _test_testi(t, p: GDScript) -> void:
	for id in p.FEN:
		# i due testi sono RIMANDATI (chiavi, non parole): si leggono con
		# L10n.rendi, che è la stessa porta da cui passa la cassetta
		var big: String = L10n.rendi(p.bigliettino(str(id)))
		var persa: String = L10n.rendi(p.lettera_persa(str(id)))
		t.ok(big.length() > 60, "«%s»: il bigliettino dice qualcosa (%d)"
				% [id, big.length()])
		t.ok(persa.length() > 60, "«%s»: la lettera racconta la scena (%d)"
				% [id, persa.length()])
		t.ok(big.contains("\n"), "«%s»: il bigliettino è scritto a mano, va a capo" % id)
		# NON rimprovera mai: è la regola del design
		for rimprovero in ["non sei venuto", "ti aspettavo invano", "peccato che",
				"hai perso", "dovevi"]:
			t.ok(not persa.to_lower().contains(rimprovero),
					"«%s»: la lettera non rimprovera («%s»)" % [id, rimprovero])
		# e il gessetto è corto: sull'ardesia c'è poco posto
		var corto: String = str((p.FEN[id] as Dictionary)["corto"])
		t.ok(corto.length() <= 16, "«%s»: il gessetto è corto (%d)"
				% [id, corto.length()])


## Il sorgente senza commenti (le stringhe restano intatte). PURA.
static func _senza_commenti(src: String) -> String:
	var out := ""
	for riga in src.split("\n"):
		var pulita := ""
		var in_str := false
		var i := 0
		while i < riga.length():
			var c := riga[i]
			if c == "\"":
				in_str = not in_str
			elif c == "#" and not in_str:
				break
			pulita += c
			i += 1
		out += pulita + "\n"
	return out


func _test_niente_ansia(t, p: GDScript) -> void:
	# il CODICE, senza i commenti: una guardia che legge anche i commenti
	# accusa l'autore delle proprie buone intenzioni («niente rancore»
	# scritto in un commento non è un rancore nel codice)
	var src := _senza_commenti(FileAccess.get_file_as_string(PROM))
	# mancare un appuntamento non deve toccare NULLA di ciò che si conta
	for punizione in ["_bump_friend", "add_nuts", "spend", "stelline",
			"ricorda(", "malus", "penal"]:
		t.ok(not src.contains(punizione),
				"mancare non tocca «%s»: non perdi punti, perdi una scena"
				% punizione)
	# nessun HUD, nessun toast: i due posti fisici sono la lavagna e la posta
	t.ok(not src.contains("_show_toast") and not src.contains("CanvasLayer"),
			"niente toast e niente HUD: l'appuntamento vive in due posti fisici")
	t.ok(src.contains("queue_letter") and src.contains("aggiorna_lavagna"),
			"…che sono la cassetta e la lavagna")
	# una sola promessa per volta
	t.ok(src.contains("if not _attiva.is_empty():\n\t\treturn")
			or src.contains("not _attiva.is_empty() or _visitors == null"),
			"una promessa alla volta: due «adesso» sono ansia")
	# se il fenomeno non è venuto non arriva nessuna lettera di rimpianto
	var chiudi := src.substr(src.find("func _chiudi"), 420)
	t.ok(chiudi.contains("esito == \"mancata\""),
			"la lettera parte SOLO se ti sei perso una scena vera")
	t.ok(chiudi.contains("\"gift\": false"),
			"…e senza regalino: non c'è niente da risarcire")
	var finale := src.substr(src.find("func _esito_finale"), 300)
	t.ok(finale.contains("sfumata"),
			"se il fenomeno non è mai venuto l'esito è «sfumata», non «mancata»")


func _test_due_posti(t, p: GDScript) -> void:
	# la lavagna sa scrivere la riga della promessa
	var cal := FileAccess.get_file_as_string("res://scenes/world/Calendar.gd")
	t.ok(cal.contains("func aggiorna_lavagna"),
			"la Lavagna si lascia riscrivere da chi ha qualcosa da appendere")
	t.ok(cal.contains("per_lavagna"),
			"…e chiede alle Promesse la loro riga di gessetto")
	# il vicino ha un verbo per ASPETTARE (non «wonder», che dura 4 s)
	var vis := FileAccess.get_file_as_string("res://scenes/npc/Visitor.gd")
	t.ok(vis.contains("\"attesa\":") and vis.contains("r_attesa"),
			"il vicino ha un verbo per aspettare in piedi")
	t.ok(vis.contains("\"r_attesa\":\n\t\t\t# in piedi"),
			"…e mentre aspetta respira e ti saluta se arrivi")
	# il momento sul Filo e la sua lettera esistono in ENTRAMBE le tabelle
	var leg := FileAccess.get_file_as_string("res://scenes/world/Legami.gd")
	var mail := FileAccess.get_file_as_string("res://scenes/interact/Mail.gd")
	t.ok(leg.contains("\"promessa\":"), "il Filo Rosso conosce le promesse")
	t.ok(mail.contains("\"promessa\":"), "…e la posta sa raccontarle")
	# ed è montato nel gioco
	var lvl := FileAccess.get_file_as_string("res://scenes/levels/MainLevel.gd")
	t.ok(lvl.contains("Promesse.gd"), "il sistema è montato in MainLevel")