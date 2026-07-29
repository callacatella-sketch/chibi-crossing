extends RefCounted
## IL FIATO SOSPESO — aspettare come verbo.
##
## Il test difende le REGOLE DI DESIGN, non solo il codice:
##
##  • la calma cresce COL TEMPO, e in piedi non basta mai: senza una vera
##    dimensione temporale «aspettare» non aggiungerebbe niente a quello
##    che stare fermi già faceva;
##  • il respiro rallenta ed è ASIMMETRICO (inspiro corto, espiro lungo),
##    e con l'ospite addosso quasi si ferma: un sin() puro si smaschera
##    in due cicli;
##  • il corpo scende DAVVERO e le orecchie vanno AVANTI — e tutto torna
##    su da solo se nessuno scrive più il canale (niente canali orfani);
##  • chi si fida non si cattura e non evapora all'appello del bestiario;
##  • niente HUD, niente congelamento, nessuna punizione: muoversi costa
##    una scena, non un punto.

const FIATO := "res://scenes/world/FiatoSospeso.gd"
const MOCHI := "res://scenes/characters/Mochi.gd"
const COZY := "res://scenes/world/CozyWorld.gd"


func run(t) -> void:
	var fs: GDScript = load(FIATO)
	t.ok(fs != null and fs.can_instantiate(), "FiatoSospeso.gd compila")
	if fs == null or not fs.can_instantiate():
		return
	_test_calma(t, fs)
	_test_respiro(t)
	_test_corpo(t)
	_test_prestito(t)
	_test_niente_ansia(t, fs)


# ------------------------------------------------------------- la calma

func _test_calma(t, fs: GDScript) -> void:
	# di corsa non si è calmi in nessun caso
	t.almost(fs.calma(4.0, 0.0, 0.0), 0.0, "correndo la calma è zero", 0.01)
	t.almost(fs.calma(4.0, 1.0, 30.0), 0.0,
			"…e correndo accovacciati pure (non esiste)", 0.01)
	# fermi in piedi si è calmi, ma NON abbastanza da farsi avvicinare
	var in_piedi: float = fs.calma(0.0, 0.0, 0.0)
	t.almost(in_piedi, float(fs.QUIETE_IN_PIEDI),
			"fermo in piedi la calma vale QUIETE_IN_PIEDI", 0.001)
	t.ok(in_piedi < float(fs.SOGLIA_FIDUCIA),
			"…e non basta: in piedi resti un animale grosso che sta lì (%.2f < %.2f)"
			% [in_piedi, float(fs.SOGLIA_FIDUCIA)])

	# giù nell'erba la calma CRESCE col tempo, e non torna mai indietro
	var prima := 0.0
	for s in [0.0, 1.0, 2.0, 4.0, 8.0, 16.0, 40.0]:
		var q: float = fs.calma(0.0, 1.0, float(s))
		t.ok(q >= prima - 0.0001,
				"a %.0f s la calma non è scesa (%.3f ≥ %.3f)" % [s, q, prima])
		t.ok(q <= 1.0, "…e non supera mai uno (%.3f)" % q)
		prima = q
	# la soglia si attraversa in un tempo UMANO: non due secondi (sarebbe
	# gratis) e non un minuto (il ciclo giorno/notte dura quattro minuti)
	var quando := -1.0
	var s2 := 0.0
	while s2 < 60.0:
		if float(fs.calma(0.0, 1.0, s2)) >= float(fs.SOGLIA_FIDUCIA):
			quando = s2
			break
		s2 += 0.1
	t.ok(quando > 2.0 and quando < 20.0,
			"la fiducia si guadagna in un tempo umano (%.1f s)" % quando)
	# e mezzo accovacciati si sta in mezzo: il canale è continuo
	var mezzo: float = fs.calma(0.0, 0.5, 8.0)
	t.ok(mezzo > in_piedi and mezzo < float(fs.calma(0.0, 1.0, 8.0)),
			"a metà strada la calma sta in mezzo (%.3f)" % mezzo)
	# la rottura è più severa dell'accumulo: chi si muove torna al punto
	t.almost(fs.calma(0.0, 1.0, 0.0), in_piedi,
			"appena ti muovi si riparte da capo", 0.001)
	t.ok(float(fs.FIDUCIA_ROTTA) < float(fs.SOGLIA_FIDUCIA),
			"c'è isteresi: si vola via più tardi di quanto si arrivi")


# ------------------------------------------------------------- il respiro

func _test_respiro(t) -> void:
	var ms: GDScript = load(MOCHI)
	if ms == null:
		return
	# ASIMMETRIA: il massimo del ciclo cade PRIMA della metà (inspiro corto,
	# espiro lungo). Un sin() puro avrebbe il massimo esatto a un quarto e
	# tornerebbe a zero a metà: si smaschera in due cicli.
	# la fase è normalizzata (0..1): il periodo vero lo dà periodo_fiato()
	var top := -9.0
	var t_top := 0.0
	var passo := 1.0 / 800.0
	var x := 0.0
	while x < 1.0:
		var v: float = ms.respiro_fiato(x, 1.0)
		if v > top:
			top = v
			t_top = x
		x += passo
	t.ok(t_top > 0.2 and t_top < 0.42,
			"il respiro è asimmetrico: il colmo cade al %.0f%% del ciclo"
			% (t_top * 100.0))
	# …e la prova che lo distingue DAVVERO da un sin(): il rapporto fra
	# discesa e salita. Un seno puro sta a 1.0 (simmetrico) e passa per lo
	# zero a metà; qui l'espiro dura quasi il doppio dell'inspiro.
	var rapporto := (1.0 - t_top) / maxf(t_top, 0.001)
	t.ok(rapporto > 1.4,
			"l'espiro dura molto più dell'inspiro (%.2f× — un sin() sta a 1.0)"
			% rapporto)
	t.ok(float(ms.respiro_fiato(0.5, 1.0)) > top * 0.55,
			"a metà ciclo il torace è ancora alto: sta ancora espirando")
	var minimo := 9.0
	x = 0.0
	while x < 1.0:
		minimo = minf(minimo, float(ms.respiro_fiato(x, 1.0)))
		x += passo
	t.ok(minimo >= -0.0001,
			"il respiro non va mai sotto lo zero: è un torace, non un'onda")
	# LA FORMA NON DIPENDE DAL PERIODO — solo l'ampiezza. È quello che
	# permette alla fase di essere INTEGRATA fuori: se il disegno del
	# respiro cambiasse con «quanto», rallentare mentre scendi
	# deformerebbe il respiro invece di allungarlo. (E a periodo variabile
	# un fposmod(t, periodo) farebbe SALTARE la fase a metà ciclo: è il
	# difetto che l'integrazione chiude.)
	var r1: float = ms.respiro_fiato(0.2, 0.0) / maxf(ms.respiro_fiato(0.2, 1.0), 1e-6)
	var r2: float = ms.respiro_fiato(0.6, 0.0) / maxf(ms.respiro_fiato(0.6, 1.0), 1e-6)
	t.almost(r1, r2, "la forma del respiro è la stessa a ogni profondità "
			+ "(cambia solo l'ampiezza: %.3f vs %.3f)" % [r1, r2], 0.001)
	# e i tre numeri del periodo vivono in UNA casa sola
	t.ok(float(ms.periodo_fiato(1.0, false)) > float(ms.periodo_fiato(0.0, false)),
			"più sei giù, più il respiro è lungo")
	t.ok(float(ms.periodo_fiato(1.0, true)) > float(ms.periodo_fiato(1.0, false)) * 1.5,
			"e con l'ospite addosso il fiato si sospende")
	# il periodo si ALLUNGA scendendo (si respira più piano)
	var v_su: float = 0.0
	var v_giu: float = 0.0
	x = 0.0
	while x < 1.0:
		v_su = maxf(v_su, absf(ms.respiro_fiato(x, 0.0)))
		v_giu = maxf(v_giu, absf(ms.respiro_fiato(x, 1.0)))
		x += 0.005
	t.ok(v_giu < v_su, "giù nell'erba il torace si muove meno (%.4f < %.4f)"
			% [v_giu, v_su])
	# e con qualcuno addosso il respiro si TRATTIENE davvero
	var trattenuto := 0.0
	var libero := 0.0
	x = 0.0
	while x < 1.0:
		trattenuto = maxf(trattenuto, absf(ms.respiro_fiato(x, 1.0, true)))
		libero = maxf(libero, absf(ms.respiro_fiato(x, 1.0, false)))
		x += 0.005
	t.ok(trattenuto < libero * 0.5,
			"con l'ospite sul naso il fiato si sospende (%.4f << %.4f)"
			% [trattenuto, libero])


# --------------------------------------------------------------- il corpo

func _test_corpo(t) -> void:
	var ms: GDScript = load(MOCHI)
	if ms == null or not ms.can_instantiate():
		return
	var mochi = t.stage(ms.new())
	if mochi._head == null:
		mochi._ready()
	if mochi._ears.size() < 2:
		t.ok(false, "Mochi senza orecchie: il resto del test non ha senso")
		return
	# Il tic dell'orecchio è un DADO: scatta ogni 3-8 s e vale fino a 0.35
	# rad — sei volte la tolleranza con cui qui si misura il ritorno a
	# riposo. Qui si misura il canale del FIATO, non il tic: lo si
	# addormenta, e il residuo torna a essere quello vero (zero).
	mochi._next_twitch = 1.0e9
	mochi._twitch_t = -1.0
	mochi._twitch_value = 0.0

	# in piedi, per avere il metro
	for _i in 30:
		mochi._process(0.016)
	var y_piedi: float = mochi.position.y
	var orecchio_piedi: float = (mochi._ears[0] as Node3D).rotation.x
	var testa_piedi: float = mochi._head.rotation.x

	# …e adesso giù nell'erba, scrivendo il canale OGNI frame come fa il
	# sistema vero
	for _i in 90:
		mochi.set_fiato(1.0, false)
		mochi._process(0.016)
	t.ok(mochi.position.y < y_piedi - 0.1,
			"il corpo scende davvero nell'erba (%.3f → %.3f)"
			% [y_piedi, mochi.position.y])
	t.ok((mochi._ears[0] as Node3D).rotation.x < orecchio_piedi - 0.25,
			"LE ORECCHIE VANNO AVANTI (%.3f → %.3f)"
			% [orecchio_piedi, (mochi._ears[0] as Node3D).rotation.x])
	t.ok(mochi._head.rotation.x < testa_piedi,
			"la testolina si abbassa col resto")
	# l'ombra resta incollata al terreno anche da giù
	t.almost(mochi._shadow_blob.position.y, 0.02 - mochi.position.y,
			"l'ombra segue il corpo che scende", 0.02)

	# LA RETE DI SICUREZZA: nessuno scrive più il canale → si torna su da
	# soli. È la classe di difetto già pagata: un canale scritto da un solo
	# stato, dimenticato, lascia il corpo fuori posa per sempre.
	for _i in 180:
		mochi._process(0.016)
	t.almost(mochi.fiato, 0.0, "il canale si spegne da solo", 0.001)
	t.ok(mochi.position.y > y_piedi - 0.05,
			"il corpo è tornato su (%.3f)" % mochi.position.y)
	t.almost((mochi._ears[0] as Node3D).rotation.x, orecchio_piedi,
			"…e le orecchie sono tornate ESATTAMENTE al loro posto", 0.001)

	# i due posatoi esistono e non sono lo stesso punto
	var naso: Vector3 = mochi.punto_naso()
	var testa: Vector3 = mochi.punto_cocuzzolo()
	t.ok(naso.distance_to(testa) > 0.15,
			"naso e cocuzzolo sono due posti diversi (%.2f m)"
			% naso.distance_to(testa))
	t.ok(testa.y > naso.y, "il cocuzzolo sta più in alto del naso")
	t.ok(mochi.direzione_muso().length() > 0.9,
			"il muso sa dove guarda (versore)")


# ------------------------------------------------------------ il prestito

func _test_prestito(t) -> void:
	var cs: GDScript = load(COZY)
	if cs == null or not cs.can_instantiate():
		return
	# CozyWorld va MESSO IN SCENA (senza _ready, che costruirebbe mezzo
	# mondo): `_cull_butterflies` chiama `contesto_critter()`, che fa
	# `get_tree()` — fuori dall'albero abortisce con un errore di script e
	# il test verrebbe vinto dall'errore, non dalla guardia.
	var cozy = t.stage(cs.new())
	# le farfalle
	# finte vanno messe in scena DAVVERO: fuori dall'albero global_position
	# vale il locale, e un test che misura distanze misurerebbe una
	# finzione. cozy resta fuori: nessuna delle due porte usa la sua
	# trasformata.
	var casa := t.stage(Node3D.new()) as Node3D
	var a := Node3D.new()
	var b := Node3D.new()
	a.position = Vector3(0.4, 0.6, 0)
	b.position = Vector3(3.0, 0.6, 0)
	casa.add_child(a)
	casa.add_child(b)
	var lista: Array = cozy.get("_butterflies")
	lista.append({"node": a, "kind": "gialla", "seed": 1.0, "prev": a.position,
			"wing_l": Node3D.new(), "wing_r": Node3D.new()})
	lista.append({"node": b, "kind": "rosa", "seed": 2.0, "prev": b.position,
			"wing_l": Node3D.new(), "wing_r": Node3D.new()})

	t.eq(cozy.nearest_butterfly(Vector3.ZERO, 9.0), 0,
			"col retino si prende la più vicina")
	var chi := str(cozy.chiama_farfalla(Vector3(0.5, 0.6, 0), 9.0))
	t.eq(chi, "gialla", "si fida quella più vicina al posatoio")
	t.eq(str(cozy.farfalla_posata().get("stato", "")), "arriva",
			"…e sta arrivando")
	# CHI SI FIDA NON SI CATTURA: sparisce dai bersagli del retino
	t.eq(cozy.nearest_butterfly(Vector3.ZERO, 9.0), 1,
			"la farfalla che si fida non è più un bersaglio del retino")
	# e non se ne chiama una seconda finché la prima è impegnata
	t.eq(str(cozy.chiama_farfalla(Vector3(0.5, 0.6, 0), 9.0)), "",
			"una alla volta: non si convoca uno sciame")
	# né evapora all'appello del bestiario
	# inverno: né la farfalla gialla né la rosa sono di stagione, quindi
	# SOLO la guardia del prestito può salvare quella posata
	cozy.set("_season", 3)
	cozy.call("_cull_butterflies")
	t.eq(lista.size(), 1, "l'appello porta via chi non è più di stagione…")
	t.eq(str(cozy.farfalla_posata().get("specie", "")), "gialla",
			"…ma NON chi si è posato su di te")
	cozy.congeda_farfalla(false)
	t.eq(cozy.farfalla_posata(), {}, "congedata, il prato se la riprende")
	t.eq(cozy.nearest_butterfly(Vector3.ZERO, 9.0), 0,
			"…e torna a essere una farfalla come le altre")
	cozy.free()


# ------------------------------------------------------------ niente ansia

## Il sorgente senza commenti: una guardia che legge anche i commenti
## accusa l'autore delle proprie buone intenzioni.
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


func _test_niente_ansia(t, _fs: GDScript) -> void:
	var src := _senza_commenti(FileAccess.get_file_as_string(FIATO))
	# autocollaudo della guardia: deve saper vedere una riga malata e
	# lasciare in pace un commento
	t.ok(_senza_commenti("var x = 1  # add_nuts qui è solo una parola").find("add_nuts") < 0,
			"la guardia non accusa i commenti")
	t.ok(_senza_commenti("\tadd_nuts(3)").find("add_nuts") >= 0,
			"…ma vede il codice vero")
	# NESSUNA PUNIZIONE: muoversi costa una scena, non un punto
	for punizione in ["add_nuts", "spend", "stelline", "_bump_friend", "malus",
			"penal", "fallit"]:
		t.ok(not src.contains(punizione),
				"mancare non tocca «%s»: si perde una scena, non un punto"
				% punizione)
	# NIENTE HUD
	t.ok(not src.contains("CanvasLayer") and not src.contains("_show_toast")
			and not src.contains("ProgressBar"),
			"nessuna barra della quiete: lo stato si legge sul corpo e nel prato")
	# NON SI CONGELA IL GIOCATORE (o si spegnerebbero anche la E e l'ESC)
	t.ok(not src.contains("set_physics_process"),
			"il giocatore non si congela mai: muoversi è la rottura, ed è tua")
	# la calma è una sola, e la ascoltano tutti
	t.ok(src.contains("calma_listener"),
			"la calma si pubblica a chi ha paura di te")
	for casa in ["scenes/world/CozyWorld.gd", "scenes/interact/Collection.gd",
			"scenes/world/Ecosystem.gd"]:
		var s := FileAccess.get_file_as_string("res://" + casa)
		t.ok(s.contains("func set_calma("),
				"%s ascolta la calma dalla fonte unica" % casa)
	# e in C++ la paura esiste davvero — chiesto al BINARIO CARICATO, non
	# al sorgente: un contains() resta verde anche svuotando la funzione,
	# e il gioco obbedisce alla .dylib, non al .cpp
	if ClassDB.class_exists("EcosystemManager"):
		var eco = EcosystemManager.new()
		t.ok(eco.has_method("set_osservatore") and eco.has_method("togli_osservatore"),
				"il prato fitto del C++ espone le porte della paura")
		eco.set_osservatore(Vector3.ZERO, 1.0)   # firma giusta: non deve esplodere
		eco.togli_osservatore()
		eco.free()
	else:
		t.ok(false, "GDExtension non caricata: la paura del C++ non è verificabile")
	# LA VISITA FINISCE DA SÉ: un momento che non finisce mai smette di
	# essere un momento
	t.ok(src.contains("_durata_visita"),
			"la farfalla se ne va da sola, prima o poi")
	# lasciare il tasto NON è fuggire: sono due scene diverse
	t.ok(src.contains("_rompi(si_muove)") and src.contains("spaventata := true"),
			"chi lascia il tasto stando fermo non spaventa nessuno")
	# il respiro che si SENTE e quello che si VEDE hanno un periodo solo
	t.ok(src.contains("MOCHI.periodo_fiato"),
			"il periodo del respiro viene dalla fonte unica, non ricopiato")
	# e l'erba sa che ti sei accovacciato
	t.ok(src.contains("mochi_giu"),
			"il canale dell'erba lo scrive chi possiede il fiato")
	var pg := FileAccess.get_file_as_string("res://project.godot")
	t.ok(pg.contains("mochi_giu={"), "…e il globale dello shader esiste")
	var gs := FileAccess.get_file_as_string("res://shaders/grass_blade.gdshader")
	t.ok(gs.contains("global uniform float mochi_giu"),
			"…e l'erba lo legge: accovacciata, si richiude invece di scansarsi")
	# il volume del mondo lo decide UN posto solo
	var sfx := FileAccess.get_file_as_string("res://audio/Sfx.gd")
	t.ok(sfx.contains("func _riallinea_ambiente"),
			"base e ducking del mondo si ricompongono in un posto solo")
	t.ok(sfx.contains("_wind_base_db = -22.0 if on else -27.0"),
			"…e il meteo aggiorna la base, o alzarsi sotto la pioggia zittiva il vento")
	# le lucciole hanno una casa dove tornare
	var cpp2 := FileAccess.get_file_as_string("res://src/ecosystem_manager.cpp")
	t.ok(cpp2.contains("f.casa = f.home") and cpp2.contains("verso_casa"),
			"le lucciole attirate dal Fiato sanno tornare a casa")

	# il montaggio nel gioco
	var lvl := FileAccess.get_file_as_string("res://scenes/levels/MainLevel.gd")
	t.ok(lvl.contains("FiatoSospeso.gd"), "il sistema è montato in MainLevel")
	# e il tasto esiste
	t.ok(InputMap.has_action("fiato"), "c'è un tasto per trattenere il fiato")
