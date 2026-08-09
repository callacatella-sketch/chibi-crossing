extends RefCounted
## I CABLAGGI DELLE SCENE — la guardia contro il SILENZIO DIFENSIVO.
##
## C'è una famiglia di difetti che questo progetto ha pagato cinque volte
## di fila, e ha sempre la stessa forma:
##
##     if nodo and nodo.has_method("qualcosa"):
##         nodo.call("qualcosa", …)
##
## Il `has_method` (o il `get_first_node_in_group`) nasce per non far
## esplodere niente quando il collaboratore non c'è. Ma se il collaboratore
## non c'è MAI — perché il gruppo non lo popola nessuno, o perché il metodo
## non esiste in tutto il repo — quella guardia non protegge: NASCONDE. Il
## ramo non gira nemmeno una volta, non c'è un errore, non c'è un warning,
## e la suite resta verde su una funzione morta.
##
## È così che sono successe, tutte davvero:
##   · il pianoforte del concerto ha suonato sul bus `Master` (il gruppo
##     "sfx" ha zero nodi: `Sfx` è un AUTOLOAD) — e il cursore «Musica»
##     mentiva al giocatore;
##   · «Rispondere» imbucava la lettera più intima del gioco e non diceva
##     niente (il gruppo "toast" ha zero nodi, e il ripiego era un
##     `print()` che il giocatore non legge);
##   · il carretto del mercante restava irraggiungibile col taccuino pieno
##     (`Calendar.merchant_distance` non esisteva, e la distanza restava
##     INF per sempre dietro un `has_method`).
##
## Perciò qui NON si cerca una stringa nei sorgenti sperando che il ramo
## giri: si ISTANZIA, si fa girare il codice vero, e si misura il
## risultato. L'unica eccezione è la prima prova, dove il cablaggio È
## testo — e anche lì la si è vista diventare rossa sui tre difetti veri.

const CONC := preload("res://scenes/interact/Concerto.gd")
const RISP := preload("res://scenes/interact/Rispondere.gd")
const CAL := preload("res://scenes/world/Calendar.gd")
const SAL := preload("res://scenes/interact/Salone.gd")
const L := preload("res://systems/L10n.gd")

## LA LISTA DEI TOLLERATI, ora VUOTA — ed e' cosi' che deve restare.
## Ci stava `__mai__`, un ciclo morto rimasto in `Sogni._fai_spazio`
## (`for l in get_nodes_in_group("__mai__")` seguito da `pass`): innocuo,
## ma teneva aperta una maglia. Il ciclo e' stato tolto, e la rete e'
## tornata stretta. Se un giorno serve aggiungere un nome qui, chiedersi
## prima se non sia piu' onesto togliere il codice che cerca il gruppo.
const GRUPPI_TOLLERATI: Array[String] = []

## Dove vive il gioco (gli `addons` non sono nostri, i `tests` non sono
## gioco, i `worktrees` sono copie di lavoro di altri agenti).
const CARTELLE := ["res://scenes", "res://systems", "res://audio", "res://tools"]


func run(t) -> void:
	_test_nessun_gruppo_fantasma(t)
	_test_concerto_suona_sulla_musica(t)
	_test_concerto_non_applaude_chi_dorme(t)
	_test_titolo_tradotto_a_meta(t)
	_test_rispondere_non_e_muto(t)
	_test_distanza_del_mercante(t)
	_test_il_vanto_non_viene_cancellato(t)


# ================================================ 1. i gruppi fantasma

## Ogni gruppo che il gioco INTERROGA deve avere qualcuno che ci entra.
## Un gruppo vuoto per costruzione è una condizione sempre falsa scritta
## in modo che sembri un cablaggio.
func _test_nessun_gruppo_fantasma(t) -> void:
	var re_cerca := RegEx.new()
	re_cerca.compile('(?:get_first_node_in_group|get_nodes_in_group|call_group' \
			+ '|call_group_flags|notify_group)\\(\\s*&?"([a-zA-Z0-9_]+)"')
	var re_pop := RegEx.new()
	re_pop.compile('add_to_group\\(\\s*&?"([a-zA-Z0-9_]+)"')
	var cercati := {}
	var popolati := {}
	for cartella in CARTELLE:
		for path in _tutti(str(cartella), ".gd"):
			# SENZA I COMMENTI. Un commento che CITA una chiamata (per
			# raccontare la lezione pagata) non è una chiamata: alla prima
			# stesura questa scansione si è accusata da sola, leggendo il
			# commento che spiega perché il gruppo "sfx" non si usa più.
			# È lo stesso errore dei source-check di facciata, al contrario.
			var src := _senza_commenti(_sorgente(path))
			for m in re_cerca.search_all(src):
				var g := m.get_string(1)
				cercati[g] = cercati.get(g, [])
				(cercati[g] as Array).append(path)
			for m in re_pop.search_all(src):
				popolati[m.get_string(1)] = true
	# i gruppi si assegnano anche dall'editor, dentro le scene salvate
	var re_g := RegEx.new()
	re_g.compile('groups\\s*=\\s*\\[([^\\]]*)\\]')
	var re_n := RegEx.new()
	re_n.compile('"([a-zA-Z0-9_]+)"')
	for path in _tutti("res://", ".tscn"):
		for m in re_g.search_all(_sorgente(path)):
			for n in re_n.search_all(m.get_string(1)):
				popolati[n.get_string(1)] = true

	t.ok(cercati.size() > 20, "la scansione ha trovato i gruppi del gioco (%d)"
			% cercati.size())
	for g in cercati:
		if str(g) in GRUPPI_TOLLERATI:
			continue
		t.ok(popolati.has(g),
				"il gruppo «%s» ha qualcuno che ci entra (lo cerca %s)"
						% [g, str((cercati[g] as Array)[0]).get_file()])


# ================================================ 2. il bus del pianoforte

## LA PROVA VIVA. Si mette in scena il Concerto, gli si fa suonare un
## brano vero su un pianoforte finto, e si guarda su quale bus è finito il
## player. Con il vecchio `get_first_node_in_group("sfx")` qui esce
## "Master": il cursore «Musica» non tocca il concerto.
func _test_concerto_suona_sulla_musica(t) -> void:
	var conc = t.stage(CONC.new())
	var sfx = conc.get("_sfx")
	t.ok(sfx != null, "il Concerto ha trovato l'autoload Sfx")
	if sfx == null:
		return
	t.ok(sfx.has_method("bus_musica"), "…ed è proprio lui (sa il bus della musica)")
	var atteso := str(sfx.call("bus_musica"))
	# se il bus non esistesse, la prova sarebbe vuota: lo si dice forte
	t.ok(AudioServer.get_bus_index(atteso) != -1,
			"il bus della musica esiste davvero nell'AudioServer (%s)" % atteso)
	t.ok(atteso != "Master",
			"…e non è il Master, altrimenti questa prova non proverebbe niente")

	var piano := t.stage(Node3D.new()) as Node3D
	conc.call("_suona", piano)
	var player = conc.get("_player")
	t.ok(player != null, "il brano è partito: c'è un player sul pianoforte")
	if player != null:
		t.eq(str(player.bus), atteso,
				"il pianoforte suona sul bus della MUSICA, non sul Master")


# ================================================ 3. il pubblico che dorme

## La finestra del concerto (0.72–0.92) scavalca quella del sonno, che si
## apre a 0.80: a metà brano parte della platea è rientrata in casa
## (`is_hidden()`). Gli applausi distribuivano lo stesso gesti d'affetto e
## momenti del Filo Rosso a chi era a letto — una sera passata insieme che
## non è mai successa.
func _test_concerto_non_applaude_chi_dorme(t) -> void:
	var conc = t.stage(CONC.new())
	var sveglio := t.stage(Vicino.new()) as Node3D
	var dorme := t.stage(Vicino.new()) as Node3D
	dorme.nascosto = true
	conc.set("_visitors", _finti(t, [["Aro", sveglio], ["Bea", dorme]]))
	conc.set("_artista", "Zoe")
	conc.set("_pubblico", ["Aro", "Bea"] as Array[String])

	conc.call("_applausi")

	t.eq(conc.get("_ascoltatori"), 1,
			"applaude UNO solo: l'altro è andato a dormire a metà brano")
	t.ok(sveglio.has_meta("postura"), "chi è rimasto si illumina")
	t.ok(not dorme.has_meta("postura"),
			"a chi dorme non si scrive addosso nessuna posa")
	t.eq((conc.get("_pubblico") as Array).size(), 1,
			"…e il suo posto sulla gradinata torna libero")
	t.ok(not ("Bea" in (conc.get("_pubblico") as Array)),
			"chi dorme esce dalla lista del pubblico")


# ================================================ 4. il titolo del brano

## Gli 80 titoli sono due metà che si incastrano. Comporle in italiano e
## poi passare il risultato a `L10n.tf("«%s»", …)` traduce soltanto le
## virgolette: in inglese uscivano ottanta titoli italiani. E il titolo si
## annoda anche sul Filo Rosso, quindi l'italiano finiva nel SALVATAGGIO.
func _test_titolo_tradotto_a_meta(t) -> void:
	var prog: Dictionary = CONC.programma(7)
	t.ok(prog.has("a") and prog.has("b"),
			"il programma consegna le DUE METÀ, non solo la frase composta")
	t.ok(str(prog["a"]) in CONC.TITOLO_A and str(prog["b"]) in CONC.TITOLO_B,
			"…e sono chiavi italiane vere, prese dalle due tavole")
	t.eq(str(prog["titolo"]), "%s %s" % [prog["a"], prog["b"]],
			"la composizione italiana resta l'identità del brano")

	# LA PROVA VERA: si mette in tabella la traduzione delle due metà e si
	# guarda se il titolo esce tradotto. Chi ricomponesse prima di tradurre
	# ritroverebbe qui l'italiano intatto.
	var prima := L.lingua_corrente()
	L.imposta("en")
	var salva_a: Variant = L._tabella.get("Notturno")
	var salva_b: Variant = L._tabella.get("delle lucciole")
	L._tabella["Notturno"] = "Nocturne"
	L._tabella["delle lucciole"] = "of the fireflies"
	var reso := str(CONC.titolo_reso("Notturno", "delle lucciole"))
	# rimessa a posto PRIMA delle asserzioni: un fallimento non deve
	# lasciare la tabella sporca al caso successivo
	if salva_a == null:
		L._tabella.erase("Notturno")
	else:
		L._tabella["Notturno"] = salva_a
	if salva_b == null:
		L._tabella.erase("delle lucciole")
	else:
		L._tabella["delle lucciole"] = salva_b
	L.imposta(prima)
	t.eq(reso, "Nocturne of the fireflies",
			"le due metà si traducono PRIMA di unirsi")

	# e ciò che va sul filo resta chiave: un salvataggio non ha una lingua
	var conc = t.stage(CONC.new())
	conc.set("_titolo_a", "Notturno")
	conc.set("_titolo_b", "delle lucciole")
	t.eq(str(conc.call("titolo_chiave")), "Notturno|delle lucciole",
			"sul Filo Rosso si annodano le CHIAVI, non la frase da mostrare")
	t.eq(str(t.stage(CONC.new()).call("titolo_chiave")), "",
			"…e prima del primo brano non c'è nessun titolo da annodare")


# ================================================ 5. Rispondere parla

## Il gruppo "toast" ha zero nodi: il primo ramo di `_toast` non ha mai
## preso, e il ripiego era un `print()`. Il giocatore imbucava la lettera
## e a schermo non succedeva niente.
func _test_rispondere_non_e_muto(t) -> void:
	var risp = t.stage(RISP.new())
	var finti = t.stage(FintiVisitors.new())
	risp.set("_visitors", finti)
	risp.call("_toast", "una prova")
	t.eq((finti.toast as Array).size(), 1,
			"il cartellino arriva davvero a schermo (via Visitors._show_toast)")
	# `[0]` su un array vuoto è un errore a RUNTIME, e un errore a runtime
	# ferma la funzione lasciando verdi le asserzioni che seguono: qui si
	# guarda per primo se c'è qualcosa da guardare (vedi CLAUDE.md).
	t.eq(str((finti.toast as Array)[0]) if not (finti.toast as Array).is_empty() \
			else "", "una prova", "…con il testo giusto")

	# e la cassetta senza storie da raccontare non resta zitta: prima
	# chiamava `Mail.mostra_toast`, che in tutto il repo non esiste
	finti.toast.clear()
	risp.set("_legami", t.stage(FintiLegami.new()))
	risp.call("apri")
	t.ok(not risp.call("e_aperto"),
			"senza nessuno a cui scrivere la schermata non si apre")
	t.eq((finti.toast as Array).size(), 1,
			"…ma il gioco lo DICE, invece di sembrare un tasto rotto")


# ================================================ 6. il carretto

## `Visitors` chiede `cal.call("merchant_distance", pos)` dietro un
## `has_method`, per dare al carretto la precedenza sul regalo («altrimenti
## col taccuino pieno il mercante era irraggiungibile»). Il metodo non
## esisteva: la distanza restava INF e la precedenza non scattava MAI.
func _test_distanza_del_mercante(t) -> void:
	var cal = CAL.new()
	t.ok(cal.has_method("merchant_distance"),
			"Calendar espone merchant_distance: è il metodo che Visitors chiede")
	# se il metodo non c'è si ESCE: chiamarlo lo stesso è un errore a
	# runtime, e un errore a runtime lascia verdi tutte le asserzioni che
	# seguono senza far fallire niente (vedi CLAUDE.md)
	if not cal.has_method("merchant_distance"):
		cal.free()
		return
	var lontano: float = cal.call("merchant_distance", Vector3.ZERO)
	t.ok(is_inf(lontano), "senza mercante in piazza la distanza è INF")
	# col carretto in piazza torna la distanza VERA (è ciò che rende la
	# precedenza possibile: sotto 1.6 m la E è del negozio). Il carretto va
	# messo IN SCENA: `global_position` fuori dall'albero è Vector3.ZERO, e
	# la prova sarebbe passata misurando due zeri.
	var carretto := t.stage(Node3D.new()) as Node3D
	carretto.position = Vector3(3, 0, 4)
	cal.set("_merchant", carretto)
	t.almost(float(cal.call("merchant_distance", Vector3.ZERO)), 5.0,
			"col carretto in piazza la distanza è quella vera", 0.001)
	t.ok(float(cal.call("merchant_distance", Vector3(3, 0, 3))) < 1.6,
			"…e da vicino sta sotto la soglia che dà la precedenza al negozio")
	cal.free()


# ================================================ 7. il vanto del salone

## `_vai_a_vantarsi` manda il cliente a cercare un vicino per mostrargli il
## look; la riga successiva gli dava `do_routine("wander")` NELLO STESSO
## FRAME, e l'ultimo ordine vince. La scena «che fa esistere la meccanica
## agli occhi del giocatore» non si è mai vista.
func _test_il_vanto_non_viene_cancellato(t) -> void:
	var sal = t.stage(SAL.new())
	var cliente := t.stage(Vicino.new()) as Node3D
	cliente.position = Vector3.ZERO
	var vicino := t.stage(Vicino.new()) as Node3D
	vicino.position = Vector3(4, 0, 0)
	sal.set("_visitors", _finti(t, [["Cli", cliente], ["Vic", vicino]]))
	sal.set("_estetista", "Est")
	sal.set("_cliente", "Cli")

	sal.call("_finisci_seduta")

	t.eq(cliente.routine, "sniff",
			"il cliente sta ANDANDO a farsi vedere: il congedo non gli ha "
			+ "buttato via la destinazione")
	t.ok(not ("wander" in cliente.routines),
			"…e nessuno gli ha ordinato di mettersi a zonzo nello stesso frame")
	t.eq(str(sal.get("_cliente")), "",
			"la poltrona però è libera: il salone può chiamare il prossimo")
	t.eq(str(sal.call("servito_oggi")), "Cli", "e il registro sa chi è cambiato")

	# il controcanto: senza nessuno a cui farsi vedere, il cliente TORNA a
	# zonzo — altrimenti resterebbe piantato davanti allo specchio
	var solo = t.stage(SAL.new())
	var tale := t.stage(Vicino.new()) as Node3D
	solo.set("_visitors", _finti(t, [["Tal", tale]]))
	solo.set("_cliente", "Tal")
	solo.call("_finisci_seduta")
	t.eq(tale.routine, "wander",
			"senza pubblico il cliente torna a zonzo come sempre")


# ================================================ gli attrezzi

## Un vicino finto: sa fare le poche cose che le scene gli chiedono, e
## soprattutto TIENE IL CONTO degli ordini ricevuti — è l'unico modo di
## accorgersi che un ordine ne ha cancellato un altro.
class Vicino extends Node3D:
	var nascosto := false
	var routine := ""
	var routines: Array = []
	var dna := {"name": "Finto", "fur": "d9c3a8"}
	var look := {}

	func is_hidden() -> bool:
		return nascosto

	func do_routine(nome: String, _a = null, _b = null, _c = null, _d = null) -> void:
		routine = nome
		routines.append(nome)

	func speak(_parole: Array, _umore := "") -> void:
		pass

	func celebrate() -> void:
		pass

	func _spawn_heart() -> void:
		pass

	func rifai_il_look(nuovo: Dictionary) -> bool:
		look = nuovo
		return true


## Il `Visitors` finto: la sola cosa che le scene gli chiedono è la lista
## dei residenti e il cartellino a schermo.
class FintiVisitors extends Node:
	var _residents: Array = []
	var toast: Array = []

	func _show_toast(testo: String) -> void:
		toast.append(testo)


## Un `Legami` senza nessun filo: serve a far arrivare «Rispondere» al suo
## ramo «non hai ancora una storia da raccontare a nessuno».
class FintiLegami extends Node:
	var _fili := {}

	func momento(_nome: String, _tipo: String, _extra := "") -> void:
		pass


# ------------------------------------------------------------- utilità

## Un `Visitors` finto già popolato: `[[label, nodo], …]`. Le scene leggono
## `_residents` con la stessa forma del gioco vero (label · node · dna).
func _finti(t, coppie: Array) -> Node:
	var v = t.stage(FintiVisitors.new())
	for c in coppie:
		var nodo: Node3D = c[1]
		v._residents.append({"label": str(c[0]), "node": nodo,
				"dna": {"name": str(c[0]) + "-nome"}})
	return v


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""


## Via le righe di commento: restano solo le righe che il motore esegue.
func _senza_commenti(src: String) -> String:
	var fuori := PackedStringArray()
	for riga in src.split("\n"):
		if str(riga).strip_edges().begins_with("#"):
			continue
		fuori.append(str(riga))
	return "\n".join(fuori)


func _tutti(dir_path: String, ext: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var p := dir_path.path_join(n)
		if d.current_is_dir():
			# `.claude` contiene i worktree degli altri agenti: sono copie
			# del repo, e scandagliarle raddoppierebbe ogni conteggio
			if not n.begins_with(".") and n != "addons":
				out.append_array(_tutti(p, ext))
		elif n.ends_with(ext):
			out.append(p)
		n = d.get_next()
	d.list_dir_end()
	return out
