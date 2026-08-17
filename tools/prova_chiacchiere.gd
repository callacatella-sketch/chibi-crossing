extends SceneTree
## CHI PARLA, NEL VILLAGGIO VERO — la prova viva delle chiacchiere.
##
##   ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . \
##       --script res://tools/prova_chiacchiere.gd
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ ESISTE
## ────────────────────────────────────────────────────────────────────────
##
## `test_pettegolezzo.gd` prova `EcsMondo.racconta(a, b)` — che è
## ASIMMETRICA per contratto: A parla, B ascolta. Ma chi sono A e B lo
## decide `Visitors._chats`, e per un anno intero li ha scelti da due cicli
## annidati (`for i … for j in range(i+1, …)`): **sempre i < j**. Finché
## l'ordine era solo coreografia non voleva dire niente; da quando è
## semantica vuol dire che il residente k può raccontare soltanto a
## k+1…N−1, e che l'ULTIMO della lista non racconta a NESSUNO — e in coda
## a `_residents` ci finiscono, per costruzione, il vicino appena arrivato
## e il cucciolo appena nato.
##
## Nessuna asserzione su `racconta()` poteva vederlo: la funzione era
## giusta, era la CHIAMATA a essere sempre nello stesso verso. Questa prova
## guarda il villaggio vero e conta due cose che solo lì si vedono
## (fra parentesi la misura PRIMA della riparazione):
##
##  1. **QUANTE VOLTE OGNUNO HA RACCONTATO** (il capannello): cinque vicini
##     addosso, una notizia diversa a testa, 300 s. Si contano i marchi
##     «già detta» nel grafo di ciascuno. (Prima: 86 chiacchierate, gli
##     indici 0-3 una volta a testa e **l'indice 4 zero**, pur avendo
##     chiacchierato 33 volte.)
##  2. **QUANTE VOLTE OGNUNO HA CHIACCHIERATO** (il falò): dodici vicini
##     sull'anello vero del fuoco, dove ognuno ha quattro persone a portata
##     di voce, 600 s. `_chats` fa UNA chiacchierata ogni 3,5 s. (Prima:
##     181 chiacchierate distribuite 73·72·72·55·38·**0·0·0·0·0**·18·34 —
##     cinque residenti su dodici non avevano aperto bocca mai, perché la
##     prima coppia in ordine lessicografico vinceva sempre.)
##
## Sono due misure diverse dello stesso difetto — l'anagrafe che decideva chi
## ha voce — e vanno guardate insieme: riparare il verso e lasciare la
## scelta della coppia in ordine di indice vorrebbe dire che il cucciolo
## appena nato può raccontare, ma non incontra mai nessuno.

const BANCO := preload("res://tools/banco.gd")

## Il capannello: cinque corpi su un cerchietto, tutti a portata di voce di
## tutti (`_chats` chiede meno di 1.9 m). Raggio 0.85 → i vicini di cerchio
## stanno a 1.00 m, i più lontani a 1.62.
const CAPANNELLO := Vector3(6.0, 0.0, 6.0)
const CAPANNELLO_R := 0.85
const QUANTI_CAPANNELLO := 5

## Il falò: si usano i posti VERI (`Visitors._posto_al_falo`), non un
## cerchio inventato — sull'anello del fuoco ognuno ha a portata di voce
## i due davanti e i due dietro, ed è quella geometria che fa la coda muta.
const QUANTI_FALO := 12

## Le celle dei letti: una fila lontana dal fiume e dalla scogliera.
const CELLA_0 := Vector2i(-14, 12)

## Mochi sta lontanissimo: un giocatore vicino semina ricordi veri
## (`Percezione`) e falserebbe il conto delle notizie.
const MOCHI_VIA := Vector3(-40.0, 0.0, -40.0)

var b: RefCounted = null
var _detto := 0

## Il registro delle chiacchierate, riempito guardando `_pair_cd` cambiare:
## `{"i_j": quante volte}`.
var _visto := {}
var _chiacchiere: Array = []


func _init() -> void:
	b = BANCO.new(self, "")
	_via.call_deferred()


func _via() -> void:
	if not await b.apri():
		quit(1)
		return
	if b.cuore == null:
		print("GUASTO: il cuore ECS non c'è (GDExtension non caricata?)")
		quit(1)
		return
	_detto = int(b.cuore.call("debug_grafo_costanti")["r_detto"])
	b.player.global_position = MOCHI_VIA

	# `CHIBI_CHIACCHIERE=costo` salta i quindici minuti di villaggio e misura
	# solo il prezzo della scansione
	if OS.get_environment("CHIBI_CHIACCHIERE") != "costo":
		await _capannello()
		await _falo()
	await _prezzo()

	quit(b.verdetto("LE CHIACCHIERE DEL VILLAGGIO"))


# =========================================================================
#  l'apparecchiatura
# =========================================================================

## Le case si posano a GRIGLIA, non in fila: ventotto letti in fila
## arrivavano oltre il fiume e `place_cell` ne rifiutava tre in silenzio —
## la prova si ritrovava con venticinque residenti e lo diceva soltanto
## perché conta quelli che ha ottenuto.
func _cella(k: int) -> Vector2i:
	@warning_ignore("integer_division")
	return CELLA_0 + Vector2i((k % 7) * 2, (k / 7) * 2)


## Insedia `n` residenti veri in una griglia di letti e torna le loro righe.
func _insedia(n: int) -> Array:
	b.visitors.call("debug_reset")
	for k in n:
		var cella := _cella(k)
		b.build.call("place_cell", cella, "Letto", 0, false)
		b.build.call("place_cell", cella, "Tetto", 0, false)
	b.build.call("aggiorna_varchi_ora")
	await create_timer(0.6).timeout
	for k in n:
		b.visitors.call("debug_settle", 1000 + k * 137, _cella(k))
	# il censimento ECS lo fa `_ciclo_sonno`, un frame per volta
	await create_timer(1.5).timeout
	var rr: Array = b.visitors.get("_residents")
	b.dico(rr.size() == n, "ci sono %d residenti (ne servivano %d)" % [rr.size(), n])
	var censiti := 0
	for r in rr:
		if (r as Dictionary).has("ecs"):
			censiti += 1
	b.dico(censiti == n, "e tutti e %d sono censiti nell'ECS" % censiti)
	return rr


## Guarda `_pair_cd` e registra le chiacchierate nuove. È l'unico modo
## non invasivo di sapere CHI ha parlato con CHI: la chiave è la coppia, il
## valore è l'istante.
func _spia() -> void:
	var cd: Dictionary = b.visitors.get("_pair_cd")
	for k in cd.keys():
		var quando := int(cd[k])
		if int(_visto.get(k, -1)) == quando:
			continue
		_visto[k] = quando
		_chiacchiere.append(str(k))


func _quante_ha_detto(r: Dictionary) -> int:
	var g: Dictionary = b.cuore.call("debug_grafo", int(r["ecs"]))
	var n := 0
	for riga in (g["ricordi"] as Array):
		if int((riga as Dictionary)["bandiere"]) & _detto:
			n += 1
	return n


## Fa girare il villaggio per `secondi`, spiando le chiacchierate.
func _lascia_vivere(secondi: float) -> void:
	var t := 0.0
	while t < secondi:
		await process_frame
		t += get_root().get_process_delta_time()
		_spia()


# =========================================================================
#  1. IL CAPANNELLO — chi RACCONTA
# =========================================================================

func _capannello() -> void:
	print("\n--- 1) il capannello: cinque vicini, una notizia a testa ---")
	var rr := await _insedia(QUANTI_CAPANNELLO)
	if rr.size() < QUANTI_CAPANNELLO:
		return
	b.sfila()
	for k in QUANTI_CAPANNELLO:
		var ang := TAU * float(k) / float(QUANTI_CAPANNELLO)
		var pos := CAPANNELLO + Vector3(cos(ang), 0, sin(ang)) * CAPANNELLO_R
		b.inchioda(rr[k] as Dictionary, pos, ang)
	await create_timer(0.5).timeout

	# UNA NOTIZIA DIVERSA A TESTA: verbi distinti, così la maschera
	# «cosa sa già l'altro» non entra mai in gioco e l'unico limite è
	# R_DETTO — una notizia si racconta una volta sola. Il massimo
	# possibile è quindi CINQUE racconti, uno a testa.
	var verbi := ["annaffia", "semina", "raccoglie", "costruisce", "taglia"]
	for k in QUANTI_CAPANNELLO:
		b.cuore.call("osserva", int((rr[k] as Dictionary)["ecs"]),
				int(b.cuore.call("indice_verbo", verbi[k])),
				Vector3(3.0 + float(k), 0.0, 4.0), -1)

	_visto.clear()
	_chiacchiere.clear()
	await _lascia_vivere(300.0)

	var chiacchiere_di := []
	var detti := []
	for k in QUANTI_CAPANNELLO:
		chiacchiere_di.append(0)
		detti.append(_quante_ha_detto(rr[k] as Dictionary))
	for c in _chiacchiere:
		var pezzi: PackedStringArray = str(c).split("_")
		chiacchiere_di[int(pezzi[0])] += 1
		chiacchiere_di[int(pezzi[1])] += 1

	print("  %d chiacchierate in 300 s" % _chiacchiere.size())
	for k in QUANTI_CAPANNELLO:
		print("   indice %d — chiacchierate %2d, raccontate %d"
				% [k, chiacchiere_di[k], detti[k]])
	var muti := 0
	for k in QUANTI_CAPANNELLO:
		if int(detti[k]) == 0 and int(chiacchiere_di[k]) > 0:
			muti += 1
	b.dico(muti == 0,
			"nessuno resta MUTO avendo chiacchierato (muti: %d)" % muti)
	b.sfila()


# =========================================================================
#  2. IL FALÒ — chi CHIACCHIERA
# =========================================================================

func _falo() -> void:
	print("\n--- 2) il falò: dodici vicini sull'anello del fuoco ---")
	var rr := await _insedia(QUANTI_FALO)
	if rr.size() < QUANTI_FALO:
		return
	b.sfila()
	for k in QUANTI_FALO:
		var pos: Vector3 = b.visitors.call("_posto_al_falo", k)
		b.inchioda(rr[k] as Dictionary, pos, 0.0)
	await create_timer(0.5).timeout

	# quante persone ha, ognuno, a portata di voce (< 1.9 m)
	var portata := []
	for k in QUANTI_FALO:
		var n := 0
		var pk: Vector3 = b.visitors.call("_posto_al_falo", k)
		for j in QUANTI_FALO:
			if j == k:
				continue
			if pk.distance_to(b.visitors.call("_posto_al_falo", j)) <= 1.9:
				n += 1
		portata.append(n)

	_visto.clear()
	_chiacchiere.clear()
	await _lascia_vivere(600.0)

	var quante := []
	for k in QUANTI_FALO:
		quante.append(0)
	for c in _chiacchiere:
		var pezzi: PackedStringArray = str(c).split("_")
		quante[int(pezzi[0])] += 1
		quante[int(pezzi[1])] += 1

	print("  %d chiacchierate in 600 s attorno al fuoco" % _chiacchiere.size())
	var zero := 0
	for k in QUANTI_FALO:
		print("   indice %2d — a portata di voce %d, chiacchierate %d"
				% [k, portata[k], quante[k]])
		if int(quante[k]) == 0 and int(portata[k]) > 0:
			zero += 1
	b.dico(zero == 0,
			"nessuno resta senza chiacchierare avendo qualcuno a portata (zero: %d)" % zero)
	b.sfila()


# =========================================================================
#  3. IL PREZZO — quanto costa guardarle TUTTE
# =========================================================================
#
# Il sorteggio della coppia obbliga a scandire tutte le coppie invece di
# fermarsi alla prima buona. Ventotto residenti fanno 378 coppie, e il
# villaggio le guarda una volta ogni 3,5 s. Prima di dire «è trascurabile»
# lo si misura, e col villaggio nella posa PIÙ CARA che esista: tutti e
# ventotto attorno al fuoco, dove ognuno ha quattro persone a portata di
# voce e le prove a buon mercato non scartano più niente.

const QUANTI_PREZZO := 28
const GIRI_PREZZO := 300


func _prezzo() -> void:
	print("\n--- 3) il prezzo della scansione: %d residenti al falò ---" % QUANTI_PREZZO)
	var rr := await _insedia(QUANTI_PREZZO)
	if rr.size() < QUANTI_PREZZO:
		return
	b.sfila()
	for k in QUANTI_PREZZO:
		b.inchioda(rr[k] as Dictionary, b.visitors.call("_posto_al_falo", k), 0.0)
	await create_timer(0.5).timeout
	var t0 := Time.get_ticks_usec()
	for _g in GIRI_PREZZO:
		b.visitors.call("_chats", 99.0)
	var us := float(Time.get_ticks_usec() - t0) / float(GIRI_PREZZO)
	print("  %.1f µs per scatto (una volta ogni 3,5 s) = %.4f ms al secondo"
			% [us, us / 3500.0])
	# un frame a 60 Hz dura 16.666 µs·1000: il tetto è mezzo millesimo di
	# frame al secondo, cioè invisibile anche sul portatile più lento
	b.dico(us < 3000.0,
			"uno scatto costa %.1f µs: sta dentro un frame con margine" % us)
	b.sfila()
