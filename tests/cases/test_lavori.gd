## Test per IL REGISTRO DEI LAVORI (scenes/npc/Lavori.gd).
##
## Il registro è il rubinetto da cui scende il risentimento: se assegna un
## lavoro che Animo non conosce, il residente riceve un compito muto e il
## giocatore vede un sistema che "non fa niente". Perciò qui si verifica
## soprattutto una cosa: che i due vocabolari COMBACINO.
##
## Lavori è un Node: si crea con .new() SENZA aggiungerlo all'albero (così
## _ready non parte e non costruisce la finestra) e si libera con .free().

extends RefCounted

const LAVORI := preload("res://scenes/npc/Lavori.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")


func run(t) -> void:
	_test_vocabolari_combaciano(t)
	_test_attivita_e_ripiego(t)
	_test_assegnazione(t)
	_test_parole_umane(t)
	_test_salvataggio(t)


# IL TEST CHE CONTA: ogni lavoro offerto dal registro dev'essere un compito
# che Animo sa valutare. Se qui si scollano, il gioco assegna ordini che non
# producono nessuna conseguenza — il modo più silenzioso di rompere tutto.
func _test_vocabolari_combaciano(t) -> void:
	for chiave in LAVORI.LAVORI:
		if chiave == "":
			continue          # il riposo è l'assenza di ordine, non un compito
		t.ok(ANIMO.COMPITI.has(chiave),
				"il lavoro '%s' esiste anche fra i compiti dell'animo" % chiave)
	t.eq(LAVORI.ORDINE.size(), LAVORI.LAVORI.size(),
			"ogni lavoro è raggiungibile scorrendo con le frecce")
	for chiave in LAVORI.ORDINE:
		t.ok(LAVORI.LAVORI.has(chiave), "e ha un nome da mostrare: '%s'" % chiave)
	# il primo dell'elenco è il riposo: si deve poter sempre TOGLIERE un
	# ordine, o il giocatore non avrebbe modo di rimediare
	t.eq(str(LAVORI.ORDINE[0]), "", "si può sempre rimettere qualcuno a riposo")


func _test_assegnazione(t) -> void:
	var l = LAVORI.new()
	t.eq(l.incarico("Nocciola"), "", "chi non ha ordini riposa")
	l.assegna("Nocciola", "taglia_legna")
	t.eq(l.incarico("Nocciola"), "taglia_legna", "l'ordine viene registrato")
	l.assegna("Nocciola", "")
	t.eq(l.incarico("Nocciola"), "", "e si può revocare")
	# un lavoro inventato non entra: meglio rifiutare che assegnare il nulla
	l.assegna("Nocciola", "pilotare_astronavi")
	t.eq(l.incarico("Nocciola"), "", "un lavoro inesistente viene rifiutato")
	l.free()


# la scala interna non va mai mostrata così com'è: "attrezzi" non significa
# niente per chi gioca
func _test_parole_umane(t) -> void:
	var l = LAVORI.new()
	for gradino in ANIMO.SCALA:
		var testo: String = l._stato_umano(gradino)
		t.ok(testo.length() > 0, "il gradino '%s' ha parole umane" % gradino)
		t.ok(testo != gradino or gradino == "svogliato",
				"e non è il nome tecnico buttato lì ('%s')" % gradino)
	t.eq(l._stato_umano("lavoro"), "sereno", "chi sta bene è 'sereno', non 'lavoro'")
	l.free()


func _test_salvataggio(t) -> void:
	var l = LAVORI.new()
	l.assegna("Nocciola", "taglia_legna")
	l.assegna("Miele", "coltiva")
	var d: Dictionary = l.save_extra()
	t.ok(d.has("incarichi"), "il registro si salva")

	var l2 = LAVORI.new()
	l2.load_extra(d)
	t.eq(l2.incarico("Nocciola"), "taglia_legna", "e gli ordini tornano al loro posto")
	t.eq(l2.incarico("Miele"), "coltiva", "tutti quanti")
	l2.load_extra({})
	t.eq(l2.incarico("Nocciola"), "", "un salvataggio vuoto non fa danni")
	l.free()
	l2.free()


# ---- IL SILENZIO CHE NON DÀ ERRORI ----
# Tre volte, in questo sistema, due vocabolari si sono scollati senza che
# nulla si rompesse: una routine "walk" che non esisteva, un momento "addio"
# che Legami ignorava, un ripiego "passeggia" che _recita non conosceva. Non
# danno errori: non fanno NIENTE, ed è molto peggio. Questo test è la rete.
func _test_attivita_e_ripiego(t) -> void:
	var VIS := load("res://scenes/npc/Visitors.gd")
	# le attività che _recita sa recitare davvero (i rami del suo match)
	var recitabili := ["spuntino", "cura_giardino", "riposo",
			"quattro_chiacchiere", "meraviglia", "stella", "regia"]

	# 1) il ripiego dev'essere un'attività VERA, o chi cambia idea resta fermo
	t.ok(str(VIS.RIPIEGO) in recitabili,
			"il ripiego '%s' è un'attività che il gioco sa recitare" % VIS.RIPIEGO)

	# 2) ogni attività che il filtro sorveglia dev'essere recitabile: se
	#    sorvegliasse un nome inventato, il filtro non scatterebbe mai
	for att in VIS.LUOGO_ATTIVITA:
		t.ok(str(att) in recitabili,
				"il filtro sorveglia '%s', che è un'attività vera" % att)

	# 3) e i luoghi dei lavori e delle attività devono INCONTRARSI almeno una
	#    volta, o il rancore per un lavoro non toccherebbe mai il tempo libero
	var luoghi_lavoro := {}
	for k in VIS.LUOGO_DEL_LAVORO:
		luoghi_lavoro[str(VIS.LUOGO_DEL_LAVORO[k])] = true
	var ponte := 0
	for k in VIS.LUOGO_ATTIVITA:
		if luoghi_lavoro.has(str(VIS.LUOGO_ATTIVITA[k])):
			ponte += 1
	t.ok(ponte > 0,
			"c'è almeno un luogo condiviso fra lavori e tempo libero (%d): senza, " % ponte
			+ "l'avversione per un lavoro non arriverebbe mai a cambiare un comportamento")
