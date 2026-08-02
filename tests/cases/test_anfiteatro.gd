extends RefCounted
## L'ANFITEATRO — il posto dell'artista, e il mestiere che ci si fa.
##
## Il sogno «artista» c'era dal primo giorno in `Animo.SOGNI` e non portava
## da nessuna parte. Questo test tiene insieme le tre cose che gliel'hanno
## dato: i pezzi (che si POSANO uno accanto all'altro, o l'anfiteatro non
## si può fare grande), il compito nel registro, e la serata.
##
## Le misure NON sono gusto: sono la ragione per cui il pianoforte può
## stare sul palco. La griglia dà una cella per strato, e finché il
## tavolato era un mobile (strato 2) come il pianoforte, i due pezzi si
## escludevano a vicenda — un palco su cui non si poteva mettere niente.
## Il tavolato è un PAVIMENTO. Se qualcuno lo riporta a strato 2, qui
## suona la sirena.

const CAT := preload("res://scenes/build/BuildCatalog.gd")
const CONC := preload("res://scenes/interact/Concerto.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")
const LAV := preload("res://scenes/npc/Lavori.gd")
const G := preload("res://scenes/npc/GufoOrders.gd")
const ECO := preload("res://scenes/ui/Economy.gd")

## I pezzi che formano l'anfiteatro, e cosa DEVE essere ciascuno.
const PEZZI := {
	"Palco": {"layer": 0, "cols": 0},        # pavimento: ci si posa sopra
	"Fondale": {"layer": 2, "cols": 1},      # mobile: ci si sbatte contro
	"Gradinata": {"layer": 2, "cols": 1},
	"Pianoforte": {"layer": 2, "cols": 1},
}


func run(t) -> void:
	_test_i_pezzi(t)
	_test_il_palco_e_un_pavimento(t)
	_test_il_pianoforte(t)
	_test_i_posti(t)
	_test_il_mestiere(t)
	_test_la_serata(t)
	_test_lo_sblocco(t)


# ---------------------------------------------------------------- i pezzi

func _test_i_pezzi(t) -> void:
	var per_nome := {}
	for v in CAT.items():
		per_nome[str(v["name"])] = v
	for nome in PEZZI:
		t.ok(per_nome.has(str(nome)), "il pezzo '%s' esiste nel catalogo" % nome)
		if not per_nome.has(str(nome)):
			continue
		var v: Dictionary = per_nome[str(nome)]
		var atteso: Dictionary = PEZZI[str(nome)]
		t.eq(int(v.get("layer", -1)), int(atteso["layer"]),
				"'%s' sta sullo strato giusto" % nome)
		var quante: int = (v.get("cols", []) as Array).size()
		if int(atteso["cols"]) == 0:
			t.eq(quante, 0,
					"'%s' non ha collisioni: e' un pavimento, ci si cammina" % nome)
		else:
			t.ok(quante >= 1, "'%s' ha un corpo con cui si scontra" % nome)
		# e si costruisce davvero, senza rompersi
		var n: Node3D = (v["builder"] as Callable).call()
		t.ok(n != null and n.get_child_count() > 0,
				"'%s' si costruisce e non e' vuoto" % nome)
		if n:
			n.free()


## IL PALCO È UN PAVIMENTO, e i pavimenti si affiancano: un anfiteatro
## grande è tante celle di tavolato, non un unico pezzo gigante. Deve
## essere BASSO (ci si sale camminando) e largo esattamente una cella, o
## fra un'asse e l'altra si vedrebbe l'erba.
func _test_il_palco_e_un_pavimento(t) -> void:
	var n: Node3D = CAT._palco()
	var aabb := _ingombro(n)
	t.ok(aabb.size.y <= 0.12,
			"il tavolato e' basso (%.3f m): ci si sale senza saltare" % aabb.size.y)
	t.ok(aabb.size.x >= 0.98 and aabb.size.x <= 1.02,
			"il tavolato e' largo una cella esatta (%.3f m): si affianca" % aabb.size.x)
	t.ok(aabb.size.z >= 0.96 and aabb.size.z <= 1.02,
			"…e profondo una cella esatta (%.3f m)" % aabb.size.z)
	t.ok(aabb.position.y >= -0.001, "e non sprofonda sotto terra")
	n.free()

	# il fondale invece SVETTA: e' lui che si vede da lontano
	var f: Node3D = CAT._fondale()
	var af := _ingombro(f)
	t.ok(af.size.y >= 0.75,
			"la conchiglia e' alta (%.2f m): domina il palco" % af.size.y)
	t.ok(af.size.x <= 1.02,
			"…ma sta dentro la sua cella (%.2f m), o sborda sul vicino" % af.size.x)
	t.ok(f.find_child("Ribalta", true, false) != null,
			"il fondale ha la Ribalta: il punto dove ci si mette a recitare")
	t.ok(_conta(f, "OmniLight3D") >= 1,
			"e una luce vera: un palco che di sera non si accende non e' un palco")
	f.free()


## IL PIANOFORTE. È il pezzo che giustifica tutto il resto: se non ha una
## cassa curva, il coperchio alzato, i tasti bianchi E neri e un posto per
## sedersi, è una scatola nera.
func _test_il_pianoforte(t) -> void:
	var n: Node3D = CAT._pianoforte()
	var aabb := _ingombro(n)
	t.ok(aabb.size.y >= 0.30 and aabb.size.y <= 0.70,
			"il coda e' alto quanto un chibi in piedi (%.2f m)" % aabb.size.y)
	t.ok(aabb.size.z >= 0.55,
			"…e lungo (%.2f m): un coda e' profondo, non un verticale" % aabb.size.z)
	# i tasti: due gruppi distinti, o la tastiera e' una striscia dipinta
	t.ok(_conta_nome(n, "Tasto") >= 14,
			"la tastiera ha i tasti uno per uno, non una striscia sola")
	t.ok(_conta_nome(n, "TastoNero") >= 5,
			"…compresi i neri, che sono quelli che si vedono")
	# LA PANCHETTA VIENE COL PIANOFORTE, e ha un nome: e' li' che
	# l'artista si siede (Concerto la cerca per nome, non a occhio)
	var panca := n.find_child("Panchetta", true, false) as Node3D
	t.ok(panca != null, "il pianoforte porta la sua panchetta, con quel nome")
	if panca:
		t.ok(panca.position.z > 0.0,
				"la panchetta sta DAVANTI alla tastiera, non dietro la cassa")
	n.free()


## I POSTI. Una gradinata senza ancoraggi è una macchia di colore: chi
## ascolta deve avere un punto dove sedersi, con un nome.
func _test_i_posti(t) -> void:
	var g: Node3D = CAT._gradinata()
	var posti := g.find_children("Posto*", "Node3D", true, false)
	# il numero e' il CONTRATTO con Concerto (fonte unica): non un numero
	# scritto due volte che diverge alla prima modifica del builder
	t.eq(posti.size(), CONC.POSTI_PER_GRADINATA,
			"ogni gradinata offre i posti che Concerto si aspetta")
	var bassi := 0
	var alti := 0
	for p in posti:
		var y: float = (p as Node3D).position.y
		t.ok(y > 0.15 and y < 0.75,
				"il posto e' su una pedata (y=%.2f), non per aria ne' sottoterra" % y)
		if y < 0.45:
			bassi += 1
		else:
			alti += 1
	t.ok(bassi > 0 and alti > 0,
			"i posti stanno su TUTTE E DUE le file (%d bassi, %d alti): da dietro
			la fila alta non deve sembrare disabitata" % [bassi, alti])
	g.free()
	# e la platea cresce affiancando gradinate, ma non oltre il buonsenso
	t.eq(CONC.posti_per(0), 0, "senza gradinate non c'e' platea")
	t.eq(CONC.posti_per(2), mini(2 * CONC.POSTI_PER_GRADINATA, CONC.MAX_PUBBLICO),
			"due gradinate: il doppio dei posti, entro il tetto")
	t.eq(CONC.posti_per(99), CONC.MAX_PUBBLICO,
			"e non si accalca piu' gente di quanta se ne possa guardare")


# ---------------------------------------------------------------- il mestiere

## «Artista» era l'ultimo sogno senza sbocco. Adesso ha un compito, un
## posto nel registro, e la resa che lo premia.
func _test_il_mestiere(t) -> void:
	t.ok("artista" in ANIMO.SOGNI, "il sogno esiste")
	t.ok(ANIMO.COMPITI.has(CONC.COMPITO),
			"…e il compito che lo realizza sta nell'animo")
	t.eq(str(ANIMO.COMPITI[CONC.COMPITO].get("serve", "")), CONC.SOGNO,
			"il compito serve proprio il sogno dell'artista")
	# SUONARE NON E' UN LAVORO COME GLI ALTRI, e il modello dell'animo lo
	# deve dire: non annoia (e' la cosa che l'artista farebbe comunque) e
	# paga in STIMA piu' di ogni altro mestiere — gli applausi sono
	# l'unico stipendio del palco. Se qualcuno pareggia la stima altrove,
	# il palco diventa un turno di guardia con la musica.
	var suona: Dictionary = ANIMO.COMPITI[CONC.COMPITO]
	t.ok(float(suona["noia"]) < 0.0, "suonare non annoia: la noia scende")
	for altro in ANIMO.COMPITI:
		if str(altro) == CONC.COMPITO or not str(altro) in LAV.ORDINE:
			continue
		var d: Dictionary = ANIMO.COMPITI[altro]
		t.ok(float(suona["stima"]) > float(d.get("stima", 0.0)),
				"…e paga in stima piu' del mestiere '%s'" % altro)
	# il registro dei lavori lo sa assegnare
	t.ok(LAV.LAVORI.has(CONC.COMPITO), "il registro dei lavori ha la sua voce")
	t.ok(CONC.COMPITO in LAV.ORDINE,
			"…e compare nella rotella con cui si sceglie (o e' inassegnabile)")
	# la resa premia chi lo sogna
	var suo := LAV.resa("sereno", "artista", CONC.COMPITO)
	var altrui := LAV.resa("sereno", "cuoco", CONC.COMPITO)
	t.ok(suo > altrui,
			"chi sogna il palco rende piu' di chi ci e' capitato (%.2f > %.2f)"
			% [suo, altrui])


## LA SERATA. Le parti pure: quando si suona, e che brano.
func _test_la_serata(t) -> void:
	# SI SUONA DI SERA, e il salone tiene il giorno: i due mestieri non si
	# pestano i piedi. Se qualcuno sposta gli orari, questo lo dice.
	var SAL := load("res://scenes/interact/Salone.gd")
	t.ok(CONC.APRE >= SAL.CHIUDE,
			"il concerto comincia dopo che il salone ha chiuso (%.2f >= %.2f)"
			% [CONC.APRE, SAL.CHIUDE])
	t.ok(not CONC.ora_di_concerto(0.4), "a meta' pomeriggio non si suona")
	t.ok(CONC.ora_di_concerto(0.8), "di sera si")
	t.ok(not CONC.ora_di_concerto(0.97), "a notte fonda le lanterne sono spente")

	# IL PROGRAMMA E' DETERMINISTICO: la stessa sera, lo stesso concerto —
	# e' quello che lo rende provabile senza far suonare niente
	var a: Dictionary = CONC.programma(7)
	var b: Dictionary = CONC.programma(7)
	t.eq(str(a["titolo"]), str(b["titolo"]), "lo stesso seme da' lo stesso brano")
	t.ok(str(a["titolo"]).length() > 4, "il brano ha un titolo vero")
	var diversi := {}
	for i in 40:
		diversi[str((CONC.programma(i) as Dictionary)["titolo"])] = true
	t.ok(diversi.size() >= 20,
			"…e in quaranta sere non si ripete sempre uguale (%d titoli)"
			% diversi.size())
	# la musica c'e' davvero, e viene dal compositore del coro (una sola
	# fonte per "una melodia bella")
	var canzone: Dictionary = a["canzone"]
	for voce in ["melodia", "armonia", "basso", "arpeggio"]:
		t.ok(not (canzone[voce] as Array).is_empty(),
				"il brano ha la sua parte di %s" % voce)
	t.ok(_sorgente("res://scenes/interact/Concerto.gd").contains("CONCERTINO.componi"),
			"e la compone Concertino: il compositore non si duplica")

	# IL SUONO. Un pianoforte reso male e' peggio del silenzio: si controlla
	# che l'onda esista, non sia muta e non sia satura.
	var wav: AudioStreamWAV = CONC._rendi_piano(canzone)
	t.ok(wav != null and wav.data.size() > 40000, "il brano diventa audio vero")
	var picco := 0
	for i in range(0, wav.data.size() - 1, 512):
		picco = maxi(picco, absi(wav.data.decode_s16(i - i % 2)))
	t.ok(picco > 4000, "…e non e' silenzio (picco %d)" % picco)
	t.ok(picco < 32700, "…ne' una lastra satura")


## LO SBLOCCO. Il giocatore non trova l'anfiteatro nel menu: se lo deve
## guadagnare, come il salone.
func _test_lo_sblocco(t) -> void:
	var in_negozio := {}
	for p in ECO.SHOP_PIECES:
		in_negozio[str(p["name"])] = true
	for nome in ["Palco", "Fondale", "Gradinata", "Pianoforte"]:
		t.ok(in_negozio.has(nome),
				"'%s' si compra: non e' gratis dal primo minuto" % nome)
		t.ok(not nome in G.STARTER, "…e non e' fra i pezzi di partenza")
	# e il Gufo lo regala a chi accoglie un artista: e' la ricompensa
	# giusta, perche' senza qualcuno che lo sogni il palco resta vuoto
	var trovato := false
	for d in G.DESIDERI:
		if str(d.get("id", "")) != "l-anfiteatro-di-chi-lo-sogna":
			continue
		trovato = true
		var pred: Dictionary = d["predicate"]
		t.eq(str(pred.get("type", "")), "sogno", "si esaudisce accogliendo qualcuno")
		t.eq(str(pred.get("sogno", "")), "artista", "…che sogni proprio di suonare")
		var regalati := str(d.get("gift_piece", "")).split("|", false)
		t.ok(regalati.size() >= 4,
				"e il pacco contiene TUTTO l'anfiteatro (%d pezzi), non un pezzo solo"
				% regalati.size())
	t.ok(trovato, "il desiderio dell'anfiteatro esiste fra quelli del Gufo")


# ---------------------------------------------------------------- utensili

## L'ingombro VERO, dai vertici delle mesh: le misure a occhio mentono.
func _ingombro(n: Node3D) -> AABB:
	var out := AABB()
	var primo := true
	for m in _mesh(n):
		# le mesh sono figlie dirette o nipoti: si compone la catena
		var nodo: Node3D = m
		var acc := Transform3D()
		while nodo != null and nodo != n:
			acc = nodo.transform * acc
			nodo = nodo.get_parent() as Node3D
		var a: AABB = acc * (m.mesh as Mesh).get_aabb()
		if primo:
			out = a
			primo = false
		else:
			out = out.merge(a)
	return out


func _mesh(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		out.append_array(_mesh(c))
	return out


func _conta(n: Node, classe: String) -> int:
	var k := 1 if n.is_class(classe) else 0
	for c in n.get_children():
		k += _conta(c, classe)
	return k


func _conta_nome(n: Node, prefisso: String) -> int:
	var k := 1 if str(n.name).begins_with(prefisso) else 0
	for c in n.get_children():
		k += _conta_nome(c, prefisso)
	return k


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""
