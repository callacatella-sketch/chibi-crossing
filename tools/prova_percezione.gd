extends SceneTree
## LA RICEVUTA, GUARDATA CON GLI OCCHI — quello che la suite non può dire.
##
##   CHIBI_PERC=/dove ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##       --script res://tools/prova_percezione.gd
##
## (senza `CHIBI_PERC` gira lo stesso e misura tutto, ma non fotografa
## niente: utile per il verdetto, inutile per la domanda vera.)
##
## ────────────────────────────────────────────────────────────────────────
## LA DOMANDA A CUI QUESTO FILE ESISTE PER RISPONDERE
## ────────────────────────────────────────────────────────────────────────
##
## **La testa girata si legge a occhio?**
##
## Tutta la Fase 4 poggia su una premessa sola: quando un vicino ti ha vista
## fare qualcosa, gira la testa. Da lì in poi ogni conseguenza — la panchina
## che si sposta, l'aiuola che sceglie, il simbolo che gli scappa in una
## chiacchiera — è *falsificabile dal giocatore*: se l'ha vista, la testa
## girata gliel'ha detto. Se quella testa NON si vede, non succede che il
## sistema sia un po' meno leggibile: succede che le conseguenze arrivano
## senza premessa, e una conseguenza senza premessa non attenua l'effetto,
## **lo inverte** — insegna che i vicini fanno cose a caso, e da quel
## momento il giocatore non riconosce più nessuna delle conseguenze vere,
## comprese quelle che sono costate mesi.
##
## `test_percezione.gd` prova che la testa si gira dalla parte giusta, che
## torna a posto, e che le quattro valvole tengono. Nessuna di quelle
## asserzioni sa dire se si VEDE. Perciò qui non si legge un `print`: si
## guardano le immagini.
##
## ────────────────────────────────────────────────────────────────────────
## COSA FA, in ordine
## ────────────────────────────────────────────────────────────────────────
##
## 0. **IL PROVINO DELLA TARATURA.** Sei chibi identici — stesso genoma,
##    stessa posa, cambia solo l'angolo del collo (0.00 · 0.45 · 0.70 ·
##    0.90 · 1.10 · 1.30 rad) — di fronte, di tre quarti e di profilo, e poi
##    **alla distanza vera della camera di gioco**. È così che si sceglie
##    `Visitor.TESTA_MAX`: guardando, non indovinando. Il provino del primo
##    giro era fatto a otto metri con una lente da 40°, cioè in
##    un'inquadratura che nel gioco non esiste.
## 1. **LA PANCHINA DI SEMPRE**, misurata PRIMA che succeda qualsiasi cosa.
##    Va per forza qui: dopo il gesto quel vicino ti ha vista, e un «prima»
##    misurato dopo non è un prima. (Il primo giro di questa prova lo
##    misurava in fondo, e diceva che il sistema non funzionava.)
## 2. **LA RICEVUTA, nel MainLevel vero.** Tre residenti veri (a 6 m, a 20 m
##    e dall'altra parte del villaggio), Mochi che annaffia **davvero**
##    (`Garden._water`: il bricco in zampa, il getto, la terra che si
##    scurisce), e tre scatti sulla STESSA inquadratura — prima, durante,
##    dopo. Un fotogramma solo non dimostra niente: la prova che una testa è
##    girata è la stessa testa dritta accanto. Più i due primi piani
##    **appaiati** (stessa lente, stessa distanza, stesso angolo) del vicino
##    e del lontano.
## 3. **LA CHIACCHIERA.** Il testimone incontra chi non c'era: nella
##    nuvoletta esce il fiore, perché è quello che ha visto.
## 4. **LA PANCHINA, DOPO.** Con le distanze, e lo scarto da casa che deve
##    restare dentro `SPOSTA_MAX`.
## 5. **NESSUNO TI SEGUE.** Il villaggio va da solo per quaranta secondi e
##    si misura quanto si avvicina: se resta lì a fissare Mochi, la regola 5
##    è rotta e il gioco è rovinato.
## 6. **L'AIUOLA**, scelta fra tre assetate.
## 7. **LA RAFFICA.** Quaranta pezzi posati uno al secondo — la piazza che si
##    lastrica, l'attività più ripetuta del gioco — con un vicino a sei
##    metri. Si misura per quanti secondi VERI resta con la testa girata, e
##    si fotografa la stessa inquadratura in quattro momenti della raffica:
##    la prima occhiata, i fatti suoi, la ripresa, i fatti suoi di nuovo. Se
##    tutti e quattro i fotogrammi hanno la testa girata, il sistema non dice
##    più «ti ho vista»: dice «mi stanno fissando».
## 8. **LO STROBO DELLA TENUTA.** Due vicini affiancati, stesso gesto, cinque
##    scatti a mezzo secondo l'uno dall'altro. È l'unico modo di vedere in
##    fotografia una cosa che è temporale: se i cinque fotogrammi sono
##    identici, la tenuta è un adesivo; e se i due vicini hanno la stessa
##    identica testa, sono due pupazzi sullo stesso filo.
## 9. **LA SCENA RARA.** Un Carillon vero, la manovella girata, il coro che si
##    stringe — e Mochi che posa un pezzo a sei metri. Nessuna di quelle teste
##    deve girarsi. È l'unica sezione che prova un CABLAGGIO invece di una
##    taratura, e serve perché un cablaggio mancante non si vede: la scena
##    continua, solo peggio.
##
## Verdetto secco e codice d'uscita, come `tools/prova_recinto.gd`.

const BANCO := preload("res://tools/banco.gd")
const VISITOR := preload("res://scenes/npc/Visitor.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")

# ---------------------------------------------------------------- il villaggio
#
# Tutto a ovest di x = 17: il fiume corre fra x ≈ 18.1 e x ≈ 20.4
# (`WorldMath.river_x`), e un corpo piantato nel letto del fiume è una prova
# che sembra rotta senza esserlo.
#
# E LE CASE STANNO LONTANE DAL GESTO. Non è una scelta di scena: nel primo
# giro la casa del secondo residente cadeva a due metri dal testimone, e
# ogni primo piano della ricevuta aveva un letto con la trapunta rosa
# piantato in primo piano. Un fotogramma in cui l'occhio va da un'altra
# parte non risponde alla domanda per cui è stato scattato.
const CASA_A := Vector2i(4, 6)        # il testimone
const CASA_B := Vector2i(0, 14)       # chi era lontano
const CASA_C := Vector2i(-12, 14)     # chi era dall'altra parte del villaggio
const PANCA_VIA := Vector2i(1, 6)     # 3.0 m da casa A, dalla parte opposta a Mochi
const PANCA_QUA := Vector2i(10, 6)    # 6.0 m da casa A, dalla parte di Mochi
const AIUOLA_VISTA := Vector2i(12, 9)   # quella che Mochi annaffia
const AIUOLA_CASA := Vector2i(2, 4)     # la più vicina a casa del testimone
const AIUOLA_TERZA := Vector2i(7, 1)    # la terza assetata

## Dove sta Mochi mentre annaffia: accanto all'aiuola, in diagonale.
const MOCHI_ORTO := Vector3(12.9, 0, 9.9)
## Dove sta Mochi quando si guarda la panchina: nove metri a est di casa A,
## dentro i venti di `MOCHI_VICINA`, e in linea con la panchina di là — così
## l'ancora spostata di sei metri ci cade sopra esatta. Non più in là:
## un'inquadratura che deve contenere le due panchine E Mochi diventa un
## quadro da quindici metri, e a quindici metri un chibi è un puntino.
const MOCHI_QUI := Vector3(13, 0, 6)
## E dove va quando ci si chiede se qualcuno la segue.
const MOCHI_VIA := Vector3(-22, 0, -16)

## Il testimone e il lontano stanno **di traverso** al gesto, apposta: se
## guardassero già da quella parte la testa girata non proverebbe niente.
## Novantesimo grado esatto — il caso più comune e il più leggibile — e la
## testa arriva al tetto del collo senza raggiungere il bersaglio: lo scarto
## che resta è una misura, e la prova lo stampa invece di nasconderlo.
const TESTIMONE := Vector3(15.0, 0, 3.8)     # 6.00 m dall'aiuola
const LONTANO := Vector3(14.0, 0, -10.9)     # 20.0 m
const ALTROVE := Vector3(-12.0, 0, 14.0)     # 24.5 m

## Dove si mettono a chiacchierare, e da che parte li guarda la camera.
const CHIACCHIERA := Vector3(15.0, 0, 3.8)

## LA PIAZZA CHE SI LASTRICA: otto celle per cinque, quaranta pezzi, tutte
## entro nove metri dal testimone e nessuna addosso alle case, alle panchine
## o alle aiuole della prova. È il cantiere della sezione 7.
const PIAZZA_X0 := 9
const PIAZZA_Z0 := 0
const PIAZZA_W := 8
const PIAZZA_PEZZI := 40
## Ogni quanto cade un pezzo, in secondi: la cadenza misurata di chi tiene
## premuto il tasto senza fretta. (`_try_place` sta su `is_action_pressed`:
## chi lo tiene premuto ne posa anche tre al secondo.)
const PIAZZA_CADENZA := 1.0

## Le tarature del collo messe una accanto all'altra. Zero c'è apposta: è il
## metro. Una testa girata si giudica solo con una testa dritta accanto.
const TARATURE := [0.00, 0.45, 0.70, 0.90, 1.10, 1.30]
## Dove si tiene il banco delle tarature: prato pulito, lontano dal
## villaggio, senza un filo d'erba alta che copra un muso.
const BANCO_TARATURE := Vector3(0, 0, 42)

var b   # il banco (tools/banco.gd)
## Il verso del corpo dei due testimoni: lo stesso per tutti e due, o le due
## teste non sarebbero confrontabili.
var _yaw_corpo := 0.0


func _init() -> void:
	_go()


func _m(c: Vector2i) -> Vector3:
	return Vector3(c.x, 0, c.y)


func _ricordi(r: Dictionary) -> int:
	var g: Dictionary = b.cuore.call("debug_grafo", int(r["ecs"]))
	return (g.get("ricordi", []) as Array).size()


# =========================================================================
#  0. IL PROVINO DELLA TARATURA
# =========================================================================

func _provino_tarature() -> void:
	if b.dove == "":
		return
	print("\n--- 0) il provino della taratura del collo ---")
	var padre := Node3D.new()
	padre.position = BANCO_TARATURE
	root.add_child(padre)
	var corpi: Array = []
	for k in TARATURE.size():
		var v = VISITOR.new()
		# STESSO GENOMA PER TUTTI E SEI. Sei chibi diversi confrontano sei
		# musi, non sei angoli: il primo provino di questa costante aveva
		# cinque genomi diversi, e metà di quello che si vedeva era il
		# personaggio, non la posa.
		v.dna = DNA.generate(4242)
		padre.add_child(v)
		v.position = Vector3(float(k) * 1.35 - 3.4, 0, 0)
		v.mode = "resident"
		v.call("_enter_state", "r_idle")
		v.set("_timer", 9999.0)
		v.set("_yaw", 0.0)          # muso verso −Z, cioè verso la camera
		corpi.append(v)
		var l := Label3D.new()
		l.text = "%.2f" % float(TARATURE[k])
		l.font_size = 64
		l.pixel_size = 0.005       # 32 cm di lettera: si legge anche da dieci metri
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.outline_size = 18
		l.outline_modulate = Color(0.12, 0.09, 0.14)
		l.position = Vector3(0, 1.55, 0)
		v.add_child(l)
	for _i in 40:
		await process_frame
	# POSA CONGELATA: si spegne il `_process` e si scrive il canale a mano,
	# così i sei si guardano fianco a fianco senza respirare a fasi diverse
	# (e senza che lo sguardo del testimone, che gira per ogni stato, ci
	# rimetta le mani sopra).
	for k in corpi.size():
		var v: Node3D = corpi[k]
		v.set_process(false)
		var testa := v.get("_head") as Node3D
		if testa != null:
			testa.rotation.y = -float(TARATURE[k])   # verso la sua destra
	for _i in 4:
		await process_frame

	var c := BANCO_TARATURE + Vector3(0, 0.72, 0)
	b.targa("le tarature del collo (rad) — a sinistra 1.30, a destra 0.00")
	await b.scatta(c, c + Vector3(0, 0.55, -5.2), "0a-tarature-fronte")
	await b.scatta(c, c + Vector3(3.4, 0.9, -4.6), "0b-tarature-trequarti")
	# LA TERZA VISTA È DALL'ALTO, non di fianco. Sei corpi in fila guardati
	# da un capo della fila si coprono a vicenda: il «profilo» della prima
	# stesura di questo provino erano sei teste una dietro l'altra, cioè
	# nessun profilo. Da sopra invece la fila non si copre mai, e l'angolo
	# del muso si legge come su un goniometro — che è esattamente la cosa da
	# misurare. Il profilo VERO, quello che smaschera il muso staccato dalla
	# testona, sta due righe più giù su un corpo solo.
	await b.scatta(c, c + Vector3(1.2, 7.2, -2.4), "0c-tarature-dallalto")
	# …E ALLA DISTANZA VERA. Un primo piano dimostra solo che un primo piano
	# si legge: nel gioco la camera sta 3,7 m dietro e 2,7 m sopra Mochi
	# (fov 50), e un vicino a sei metri da lei è a DIECI metri dalla lente.
	# Se a quella distanza le sei teste sembrano uguali, la ricevuta non
	# esiste — per quanto bella sia da vicino.
	b.targa("…le stesse sei, alla distanza vera della camera di gioco")
	await b.scatta(c, c + Vector3(0, 2.7, -9.6), "0d-tarature-distanza-di-gioco")
	# IL PROFILO VERO, su un corpo solo e quello che il gioco usa davvero
	# (0.90): è di fianco che si smaschera il muso «in volo» staccato dalla
	# testona, ed è la verifica che CLAUDE.md chiede per nome.
	# quale delle sei è quella in vigore lo dice `Visitor.TESTA_MAX`, non un
	# numero ricopiato qui: se un domani il collo si ritara, questo scatto
	# segue da solo la taratura nuova
	var k_scelta := 0
	for k in TARATURE.size():
		if absf(float(TARATURE[k]) - VISITOR.TESTA_MAX) \
				< absf(float(TARATURE[k_scelta]) - VISITOR.TESTA_MAX):
			k_scelta = k
	var scelto: Node3D = corpi[k_scelta]
	var muso := Vector3(sin(float(TARATURE[k_scelta])), 0, -cos(float(TARATURE[k_scelta])))
	var di_lato := muso.rotated(Vector3.UP, PI * 0.5)
	var p := scelto.global_position + Vector3(0, 0.68, 0)
	b.targa("di profilo, alla taratura in vigore (%.2f rad): il muso resta attaccato alla testona"
			% VISITOR.TESTA_MAX)
	await b.scatta(p, p + di_lato * 1.7 + Vector3(0, 0.18, 0), "0e-profilo-della-scelta")
	b.targa("")
	b.affianca(["0a-tarature-fronte", "0b-tarature-trequarti", "0c-tarature-dallalto"],
			"0-provino-tarature")

	for v in corpi:
		(v as Node).queue_free()
	padre.queue_free()
	for _i in 6:
		await process_frame


# =========================================================================
#  il villaggio della prova
# =========================================================================

func _posa_villaggio() -> bool:
	for c in [CASA_A, CASA_B, CASA_C]:
		b.build.call("place_cell", c, "Letto", 0, false)
		b.build.call("place_cell", c, "Tetto", 0, false)
	b.build.call("place_cell", PANCA_VIA, "Panchina", 0, false)
	b.build.call("place_cell", PANCA_QUA, "Panchina", 0, false)
	for a in [AIUOLA_VISTA, AIUOLA_CASA, AIUOLA_TERZA]:
		b.build.call("place_cell", a, "Aiuola", 0, false)
	b.build.call("aggiorna_varchi_ora")
	await create_timer(1.0).timeout
	# ASSETATE, ma senza piantarle davvero: `Garden._plant` emette a sua
	# volta sul bus della percezione, e la semina finirebbe nella memoria dei
	# vicini falsando tutto quello che viene dopo.
	_riassetta_le_aiuole()
	b.dico((b.build.call("get_placed_by_name", "Aiuola") as Array).size() == 3,
			"le tre aiuole ci sono")
	b.dico(b.garden.call("bed_needing_water", _m(AIUOLA_CASA), 0.9) != null,
			"e hanno sete tutte e tre")

	b.visitors.call("debug_reset")
	b.visitors.call("debug_settle", 4242, CASA_A)
	b.visitors.call("debug_settle", 7171, CASA_B)
	b.visitors.call("debug_settle", 9393, CASA_C)
	# il censimento ECS lo fa `_ciclo_sonno` da solo, un frame per volta:
	# gli si dà il tempo, e poi si CONTROLLA che sia successo
	await create_timer(1.5).timeout
	var residenti: Array = b.visitors.get("_residents")
	if residenti.size() != 3:
		print("GUASTO: servono tre residenti, ce ne sono %d" % residenti.size())
		return false
	b.cuore = b.visitors.call("cuore")
	if b.cuore == null:
		print("GUASTO: il cuore ECS non c'è (GDExtension non caricata?)")
		return false
	for r in residenti:
		if not (r as Dictionary).has("ecs"):
			print("GUASTO: un residente non è stato censito nell'ECS")
			return false

	# il verso del corpo dei testimoni: novanta gradi esatti dal gesto
	var verso := (_m(AIUOLA_VISTA) - TESTIMONE)
	_yaw_corpo = atan2(-verso.x, -verso.z) - PI * 0.5
	return true


func _riassetta_le_aiuole() -> void:
	for a in [AIUOLA_VISTA, AIUOLA_CASA, AIUOLA_TERZA]:
		b.garden.call("debug_set_stage", a, 1, false)


## Il verso del corpo (dove punta il muso) come vettore.
func _avanti() -> Vector3:
	return Vector3(-sin(_yaw_corpo), 0, -cos(_yaw_corpo))


# =========================================================================
#  1. LA PANCHINA DI SEMPRE (prima che succeda qualunque cosa)
# =========================================================================

func _panchina_prima(rr: Array) -> Dictionary:
	print("\n--- 1) la panchina di sempre, PRIMA che il vicino abbia visto niente ---")
	var casa := _m(CASA_A)
	var t0: Node3D = (rr[0] as Dictionary)["node"]
	# gli altri due lontani: un vicino che passa di lì occupa una panchina
	# (`_free_bench` salta i posti presi) e la prova misurerebbe altro
	await b.porta(1, _m(CASA_B))
	await b.porta(2, _m(CASA_C))
	b.player.global_position = MOCHI_QUI
	var amm := float(b.cuore.call("ammirazione", int((rr[0] as Dictionary)["ecs"])))
	await b.porta(0, casa)
	b.visitors.call("debug_force_activity", 0, "riposo")
	await create_timer(0.6).timeout
	var meta_a: Vector3 = b.meta(t0)
	print("       ammirazione %.3f (soglia %.2f) → va verso %s"
			% [amm, float(b.visitors.get("AMMIRA_SOGLIA")), meta_a])
	print("       (panchina di casa %s · panchina dalla parte di Mochi %s)"
			% [_m(PANCA_VIA), _m(PANCA_QUA)])
	await b.aspetta(t0, "r_bench")
	var d := t0.global_position.distance_to(b.player.global_position)
	print("       si è seduto in %s, a %.2f m da Mochi" % [t0.global_position, d])
	# DAGLI OCCHI DI MOCHI, e ci sono volute quattro inquadrature sbagliate
	# per capirlo. La scena è larga dodici metri: da terra non ci sta dentro,
	# da mezz'aria un albero del villaggio copre metà quadro, e dall'alto
	# diventa una mappa in cui i corpi sono bottoni. Ma la domanda vera non è
	# «dove sono le due panchine»: è **«questo vicino è qui con me o no»**, e
	# quella la risponde una sola lente — la sua. Prima il prato davanti a
	# Mochi è vuoto (lui è dodici metri a sinistra, fuori quadro); dopo è
	# seduto lì. È esattamente quello che vede chi gioca, ed è tutto.
	b.targa("PRIMA — il prato davanti a Mochi è vuoto: lui siede dall'altra parte")
	await b.scatta_come_in_gioco("3a-panchina-prima")
	b.targa("")
	b.dico(amm < float(b.visitors.get("AMMIRA_SOGLIA")),
			"chi non ha ancora visto niente non ti ammira")
	b.dico(meta_a.distance_to(_m(PANCA_VIA)) < 1.6,
			"e sceglie la panchina più vicina a casa sua")
	return {"meta": meta_a, "d": d}


# =========================================================================
#  2. LA RICEVUTA
# =========================================================================

func _la_ricevuta(rr: Array) -> void:
	print("\n--- 2) la ricevuta: Mochi annaffia, e chi c'era gira la testa ---")
	var bersaglio := _m(AIUOLA_VISTA)
	# I TRE CORPI DI TRAVERSO AL GESTO, e con lo STESSO verso: due teste
	# affiancate si confrontano solo se i due colli partono uguali.
	b.inchioda(rr[0], TESTIMONE, _yaw_corpo)
	b.inchioda(rr[1], LONTANO, _yaw_corpo)
	b.inchioda(rr[2], ALTROVE, _yaw_corpo)
	b.player.global_position = MOCHI_ORTO
	await create_timer(0.8).timeout

	var t0: Node3D = (rr[0] as Dictionary)["node"]
	var t1: Node3D = (rr[1] as Dictionary)["node"]
	for i in 3:
		var r := rr[i] as Dictionary
		var n := r["node"] as Node3D
		print("       %-8s a %5.1f m dal gesto, ricordi %d"
				% [str(r["label"]), bersaglio.distance_to(n.global_position),
				_ricordi(r)])
	b.dico(_ricordi(rr[0]) == 0 and _ricordi(rr[1]) == 0 and _ricordi(rr[2]) == 0,
			"prima del gesto nessuno ricorda niente")

	# LE DUE INQUADRATURE, decise una volta e usate tre volte (prima,
	# durante, dopo): un confronto vale solo se la camera non si è mossa.
	#
	# NON C'È un terzo quadro «largo» che tenga insieme il testimone, Mochi e
	# l'aiuola, ed è una rinuncia MISURATA: quella scena è larga dodici metri,
	# a dodici metri un chibi è alto novanta pixel, e la camera piazzata con
	# la trigonometria e senza guardare finisce dentro un albero del
	# villaggio (il MainLevel è un mondo, non un fondale — è successo due
	# volte). Il quadro largo esiste già ed è **quello del gioco**, qui sotto:
	# se la ricevuta va letta in un quadro largo, dev'essere quello vero.
	var u := (bersaglio - TESTIMONE).normalized()
	var f := _avanti()
	# a) IL PRIMO PIANO, di fronte al corpo: lì la testa girata si legge come
	#    scarto dalla linea delle spalle, che è il modo in cui la legge
	#    l'occhio quando non sa ancora dove guardare.
	var occhio_p := TESTIMONE + f * 2.1 + Vector3(0, 0.95, 0)
	var centro_p := TESTIMONE + Vector3(0, 0.66, 0)
	# b) DI PROFILO, dal lato del gesto: è lì che si smascherano i trucchi —
	#    un muso «in volo» davanti alla testona si vede solo di fianco.
	var occhio_l := TESTIMONE + u * 2.3 + Vector3(0, 0.9, 0)

	b.targa("PRIMA — nessuno ha visto niente")
	await b.scatta(centro_p, occhio_p, "2d-prima-primo-piano")
	await b.scatta_come_in_gioco("2a-prima-vista-di-gioco")
	var gradi_prima: Vector2 = b.testa_gradi(t0)

	# ------------------------------------------------- il gesto, per davvero
	# Non una chiamata al bus: il GESTO. `Garden._water` fa sbocciare il
	# bricco in zampa a Mochi, la gira verso l'aiuola, versa, e — nella
	# stessa riga in cui avvisa il Regista — avvisa la percezione. Chiamare
	# il bus a mano proverebbe il bus; questo prova il gioco.
	var aiuola: Node3D = b.garden.call("bed_needing_water", bersaglio, 0.9)
	if aiuola == null:
		b.dico(false, "l'aiuola da annaffiare esiste")
		return
	b.garden.call("_water", aiuola)
	await create_timer(1.15).timeout   # il getto è al colmo fra 0,7 e 1,7 s

	var gradi: Vector2 = b.testa_gradi(t0)
	var gradi_l: Vector2 = b.testa_gradi(t1)
	var scarto := float(b.scarto_dal_bersaglio(t0, bersaglio))
	var scarto_l := float(b.scarto_dal_bersaglio(t1, bersaglio))
	print("       testimone: testa %+6.1f° (di cui ricevuta %+6.1f°), manca %5.1f° al bersaglio"
			% [gradi.x, gradi.y, scarto])
	print("       lontano:   testa %+6.1f° (di cui ricevuta %+6.1f°), manca %5.1f° al bersaglio"
			% [gradi_l.x, gradi_l.y, scarto_l])
	print("       ricordi: testimone %d · lontano %d · altrove %d"
			% [_ricordi(rr[0]), _ricordi(rr[1]), _ricordi(rr[2])])

	b.targa("DURANTE — il testimone (6 m) gira la testa verso Mochi")
	await b.scatta(centro_p, occhio_p, "2e-durante-primo-piano")
	await b.scatta_come_in_gioco("2b-durante-vista-di-gioco")
	await b.scatta(TESTIMONE + Vector3(0, 0.66, 0), occhio_l, "2g-durante-profilo")
	# I DUE APPAIATI, stessa lente, stessa distanza, stesso angolo: uno ha
	# visto e l'altro no, e la differenza è tutta nel collo. Un quadro largo
	# che li contenesse tutti e due li renderebbe due puntini — questo li
	# mette alla stessa scala, che è l'unico modo di confrontarli davvero.
	b.targa("il vicino, a 6 m")
	await b.scatta(centro_p, occhio_p, "2h1-vicino")
	b.targa("il lontano, a 20 m — stessa lente, stessa distanza, stesso angolo")
	await b.scatta(LONTANO + Vector3(0, 0.66, 0),
			LONTANO + f * 2.1 + Vector3(0, 0.95, 0), "2h2-lontano")
	# ------------------------------------------------------------- e dopo
	await create_timer(5.0).timeout
	var gradi_dopo: Vector2 = b.testa_gradi(t0)
	print("       dopo la scadenza: testa %+6.1f° (ricevuta %+6.1f°)"
			% [gradi_dopo.x, gradi_dopo.y])
	b.targa("DOPO — lo sguardo è scaduto, ai fatti suoi")
	await b.scatta(centro_p, occhio_p, "2f-dopo-primo-piano")
	await b.scatta_come_in_gioco("2c-dopo-vista-di-gioco")
	b.targa("")
	b.affianca(["2a-prima-vista-di-gioco", "2b-durante-vista-di-gioco",
			"2c-dopo-vista-di-gioco"], "2-provino-ricevuta-vista-di-gioco")
	b.affianca(["2d-prima-primo-piano", "2e-durante-primo-piano", "2f-dopo-primo-piano"],
			"2-provino-ricevuta-primo-piano")
	b.affianca(["2h1-vicino", "2h2-lontano"], "2-provino-vicino-e-lontano")

	# ----------------------------------------------------------- il verdetto
	b.dico(_ricordi(rr[0]) == 1, "il gesto è entrato nella memoria di chi era a 6 m")
	b.dico(_ricordi(rr[1]) == 0, "e NON in quella di chi era a 20 m")
	b.dico(_ricordi(rr[2]) == 0, "né in quella di chi era dall'altra parte")
	b.dico(absf(gradi_prima.y) < 1.0, "prima del gesto la testa era dritta")
	# la soglia è in gradi, e NON si ricava da `TESTA_MAX`: un banco che si
	# porta dietro la costante che sorveglia resta verde anche se quella
	# costante va a zero. Trenta gradi è «una testa che si legge come
	# girata», misurato guardando il provino qui sopra.
	b.dico(absf(gradi.y) > 30.0,
			"durante il gesto la testa del testimone è girata di più di 30°")
	b.dico(absf(gradi_l.y) < 1.0, "quella del lontano no")
	b.dico(scarto < scarto_l,
			"e punta il gesto molto più di quanto ci punti il lontano")
	b.dico(absf(gradi_dopo.y) < 2.0, "dopo la scadenza la testa è tornata dritta")


# =========================================================================
#  3. LA CHIACCHIERA
# =========================================================================

func _la_chiacchiera(rr: Array) -> void:
	print("\n--- 3) la chiacchiera: nella nuvoletta esce quel che ha visto ---")
	b.sfila()
	# QUANTI NE AVEVA PRIMA, e si legge PRIMA di avvicinarli. Sembra una
	# pignoleria e non lo è: appena due residenti si trovano a meno di 1,6 m
	# il villaggio li fa chiacchierare per conto suo (`_chats`, una coppia
	# ogni 3,5 s), la notizia passa lì — e la prova, che la misurava dopo
	# averli accostati, trovava il ricordo già arrivato e si dichiarava
	# rotta. Ha ragione il gioco: quella è la scena vera, arrivata da sola.
	var prima_l := _ricordi(rr[1])
	# …e adesso si zittisce il chiacchiericcio d'ambiente, o la chiacchierata
	# spontanea si prenderebbe la notizia un istante prima di quella che
	# stiamo per fotografare, e nella nuvoletta uscirebbe un tema qualunque.
	b.visitors.set("_chat_acc", 99.0)
	# affiancati in diagonale e girati l'uno verso l'altro, con la camera
	# perpendicolare al loro asse: due profili e due nuvolette, non due nuche
	var a := CHIACCHIERA + Vector3(-0.6, 0, 0.6)
	var c := CHIACCHIERA + Vector3(0.6, 0, -0.6)
	var verso := (c - a).normalized()
	b.inchioda(rr[0], a, atan2(-verso.x, -verso.z))
	b.inchioda(rr[1], c, atan2(verso.x, verso.z))
	# …E IL TERZO VA INCHIODATO ANCHE LUI, a casa sua. Non è pignoleria di
	# messa in scena: lasciato libero, l'agenda lo manda a spasso e finisce
	# in mezzo all'inquadratura — con la sua nuvoletta addosso, per giunta,
	# perché anche lui ogni tanto parla. Un terzo chibi nel quadro di una
	# prova sul passaparola è la cosa che la rende illeggibile.
	b.inchioda(rr[2], ALTROVE, 0.0)
	b.player.global_position = MOCHI_QUI
	await create_timer(0.6).timeout

	b.visitors.call("debug_force_chat")
	await create_timer(0.45).timeout
	# camera ALL'ALTEZZA DELLE TESTE e vicina: le nuvolette stanno appena
	# sopra il testone, e da un punto più alto finiscono contro il prato
	# (bianco su giallo). Da qui si stagliano sul cielo.
	var perp := verso.rotated(Vector3.UP, PI * 0.5)
	var centro := CHIACCHIERA + Vector3(0, 1.0, 0)
	var occhio := CHIACCHIERA + perp * 2.6 + Vector3(0, 1.05, 0)
	b.targa("la nuvoletta del testimone: il fiore, perché è quel che ha visto")
	await b.scatta(centro, occhio, "3a-nuvoletta")
	await create_timer(0.95).timeout   # la risposta arriva a 1,1 s
	b.targa("…e la risposta di chi non c'era")
	await b.scatta(centro, occhio, "3b-nuvoletta-risposta")
	b.targa("")
	b.affianca(["3a-nuvoletta", "3b-nuvoletta-risposta"], "3-provino-chiacchiera")

	# COSA dev'esserci dentro quella nuvoletta, in numeri: il simbolo lo
	# decide `Visitor.LP_SIMBOLI` (fonte unica) a partire dal nome della cosa
	# raccontata, e la cosa raccontata dev'essere il fiore.
	var righe: Array = (b.cuore.call("debug_grafo", int((rr[1] as Dictionary)["ecs"]))
			as Dictionary).get("ricordi", [])
	var sentito := {}
	for riga in righe:
		if (int((riga as Dictionary)["bandiere"]) & int(b.cuore.R_SENTITO)) != 0:
			sentito = riga
	print("       chi non c'era aveva %d ricordi, adesso ne ha %d"
			% [prima_l, righe.size()])
	b.dico(prima_l == 0 and not sentito.is_empty(),
			"chi non c'era si porta via la notizia")
	if sentito.is_empty():
		return
	var nome := str(b.cuore.call("nome_cosa", int(sentito["cosa"])))
	var simbolo := str(VISITOR.LP_SIMBOLI.get(nome, "?"))
	print("       la cosa raccontata è «%s», e il suo simbolo è «%s»" % [nome, simbolo])
	b.dico(nome == "fiore", "e la cosa raccontata è il FIORE, non una a caso")
	b.dico(simbolo == "✿", "che nella nuvoletta è il fiore vero (LP_SIMBOLI)")
	# la soglia è il terzo argomento (`dove` ha un PAVIMENTO: sotto quel peso
	# un ricordo non indica più niente e si torna al ripiego). Qui la notizia
	# è appena arrivata, quindi si chiede quella del gioco: se un domani
	# l'eco arrivasse già spenta, questa riga lo direbbe.
	var dove_sa: Vector3 = b.cuore.call("dove", int((rr[1] as Dictionary)["ecs"]),
			b.cuore.C_FIORE, float(b.visitors.get("AMMIRA_SOGLIA")), Vector3.ZERO)
	print("       e sa dove: %s (l'aiuola sta in %s)" % [dove_sa, _m(AIUOLA_VISTA)])
	b.dico(dove_sa.distance_to(_m(AIUOLA_VISTA)) < 0.6,
			"il luogo attraversa il passaparola intatto")


# =========================================================================
#  4. LA PANCHINA, DOPO
# =========================================================================

func _panchina_dopo(rr: Array, prima: Dictionary) -> void:
	print("\n--- 4) la panchina, DOPO che ti ha vista annaffiare ---")
	b.sfila()
	var casa := _m(CASA_A)
	var t0: Node3D = (rr[0] as Dictionary)["node"]
	await b.porta(1, _m(CASA_B))
	await b.porta(2, _m(CASA_C))
	b.player.global_position = MOCHI_QUI
	var amm := float(b.cuore.call("ammirazione", int((rr[0] as Dictionary)["ecs"])))
	var ancora: Vector3 = b.visitors.call("ancora_riposo", casa,
			b.player.global_position, amm)
	await b.porta(0, casa)
	b.visitors.call("debug_force_activity", 0, "riposo")
	await create_timer(0.6).timeout
	var meta_b: Vector3 = b.meta(t0)
	print("       ammirazione %.3f (soglia %.2f) → va verso %s"
			% [amm, float(b.visitors.get("AMMIRA_SOGLIA")), meta_b])
	print("       l'ancora è a %.2f m da casa (tetto SPOSTA_MAX %.1f)"
			% [ancora.distance_to(casa), float(b.visitors.get("SPOSTA_MAX"))])
	await b.aspetta(t0, "r_bench")
	var d := t0.global_position.distance_to(b.player.global_position)
	print("       si è seduto in %s, a %.2f m da Mochi (prima erano %.2f)"
			% [t0.global_position, d, float(prima["d"])])
	b.targa("DOPO — stessa lente, stesso posto: adesso è seduto lì. Non è venuto più vicino")
	await b.scatta_come_in_gioco("3b-panchina-dopo")
	b.targa("")
	b.affianca(["3a-panchina-prima", "3b-panchina-dopo"], "3-provino-panchina")

	b.dico(amm > float(b.visitors.get("AMMIRA_SOGLIA")),
			"quel che ha visto gli è importato abbastanza")
	b.dico(meta_b.distance_to(_m(PANCA_QUA)) < 1.6,
			"e sceglie la panchina dalla TUA parte")
	b.dico(meta_b.distance_to(prima["meta"]) > 2.0,
			"cioè un'altra rispetto a prima")
	b.dico(d < float(prima["d"]), "adesso siede più vicino a te di prima")
	b.dico(ancora.distance_to(casa) <= float(b.visitors.get("SPOSTA_MAX")) + 0.01,
			"ma l'ancora resta dentro il suo tetto da casa: non è un guinzaglio")


# =========================================================================
#  5. NESSUNO TI SEGUE (la regola 5, misurata)
# =========================================================================

func _nessuno_ti_segue(rr: Array) -> void:
	print("\n--- 5) il villaggio va da solo: qualcuno mi segue? ---")
	# niente `debug_force_activity`, niente chiodi: si lascia decidere
	# all'agenda in C++ e si guarda cosa fa un vicino che ti ammira
	var t0: Node3D = (rr[0] as Dictionary)["node"]
	var sazianti := 0
	var min_qui := 999.0
	var visti := {}
	for _k in 40:                       # 20 s con Mochi ferma qui
		await create_timer(0.5).timeout
		var st := str(t0.get("_state"))
		visti[st] = true
		if st in ["r_bench", "r_fire"] or st.begins_with("tk_"):
			sazianti += 1
		min_qui = minf(min_qui, t0.global_position.distance_to(b.player.global_position))
	b.player.global_position = MOCHI_VIA
	var min_via := 999.0
	for _k in 40:                       # …e 20 s dopo che se n'è andata
		await create_timer(0.5).timeout
		min_via = minf(min_via, t0.global_position.distance_to(b.player.global_position))
	print("       stati attraversati: %s" % [visti.keys()])
	print("       più vicino a Mochi: %.2f m mentre era qui, %.2f m dopo che se n'è andata"
			% [min_qui, min_via])
	b.dico(sazianti > 0,
			"il vicino se ne va comunque a fare i fatti suoi (e a saziarsi)")
	b.dico(min_qui > 1.4,
			"non ti viene addosso: resta fuori perfino dal raggio del saluto")
	# dodici metri: più della metà di `MOCHI_VICINA`, cioè fuori da qualunque
	# lettura di «mi sta venendo dietro». La soglia è indipendente dalle
	# costanti che sorveglia, apposta.
	b.dico(min_via > 12.0,
			"e quando te ne vai NON ti segue: resta nel suo angolo di villaggio")


# =========================================================================
#  6. L'AIUOLA CHE HA VISTO
# =========================================================================

func _l_aiuola(rr: Array) -> void:
	print("\n--- 6) l'aiuola scelta fra tre assetate ---")
	var casa := _m(CASA_A)
	var t0: Node3D = (rr[0] as Dictionary)["node"]
	b.player.global_position = MOCHI_QUI
	_riassetta_le_aiuole()
	await b.porta(0, casa)
	b.visitors.call("debug_force_activity", 0, "cura_giardino")
	await create_timer(0.6).timeout
	var meta_d: Vector3 = b.meta(t0)
	print("       va verso %s" % meta_d)
	print("       (di casa %s a %.1f m · la terza %s a %.1f m · quella vista %s a %.1f m)"
			% [_m(AIUOLA_CASA), casa.distance_to(_m(AIUOLA_CASA)),
			_m(AIUOLA_TERZA), casa.distance_to(_m(AIUOLA_TERZA)),
			_m(AIUOLA_VISTA), casa.distance_to(_m(AIUOLA_VISTA))])
	b.dico(meta_d.distance_to(_m(AIUOLA_VISTA)) < 1.6,
			"fra TRE assetate sceglie quella che ha visto annaffiare — non la più vicina")
	var t = await b.aspetta(t0, "tk_water")
	print("       ci è arrivato dopo %.2f s, in %s" % [t, t0.global_position])
	b.targa("Mochi torna all'orto e ritrova il proprio gesto, fatto da un altro")
	await create_timer(0.8).timeout
	# il vicino annaffia da `bed + (0.75, 0, 0.1)`: si inquadra LUI, non la
	# cella. E da est, dalla parte del fiume: a ovest dell'orto c'è un masso
	# del villaggio, e la prima stesura di questa inquadratura ci è finita
	# dentro (un fotogramma marrone e basta).
	var chino := _m(AIUOLA_VISTA) + Vector3(0.4, 0.45, 0.05)
	await b.scatta(chino, chino + Vector3(3.4, 2.0, -3.4), "4a-aiuola-scelta")
	await b.scatta(chino, chino + Vector3(4.4, 1.0, 0.8), "4b-aiuola-scelta-profilo")
	b.targa("")
	b.dico(str(t0.get("_state")) == "tk_water", "e ci si mette davvero ad annaffiare")


# =========================================================================
#  7. LA RAFFICA: quaranta pezzi, quante ricevute?
# =========================================================================
#
# È l'unica sezione che misura il TEMPO invece di guardare un istante, e lo
# fa perché il guasto che sorveglia è fatto di tempo: nessun fotogramma
# singolo può dire «questa testa è girata da quaranta secondi». Il
# campionatore si attacca a `process_frame` e conta i secondi VERI, quelli
# che passano per chi gioca.

var _camp := {"nodo": null, "ms": 0, "girata": 0.0, "tot": 0.0,
		"alzate": 0, "su": false}


func _campiona() -> void:
	var n: Node3D = _camp["nodo"]
	if n == null or not is_instance_valid(n):
		return
	var ms := Time.get_ticks_msec()
	var dt := float(ms - int(_camp["ms"])) / 1000.0
	_camp["ms"] = ms
	if dt <= 0.0 or dt > 0.5:      # il primo giro, e le pause di caricamento
		return
	_camp["tot"] = float(_camp["tot"]) + dt
	# la stessa soglia con cui la revisione ha misurato il guasto: 0,45 rad
	# è «una testa che si legge come girata», non il tetto del collo
	var su: bool = absf(float(n.get("_tst_off"))) > 0.45
	if su:
		_camp["girata"] = float(_camp["girata"]) + dt
		if not bool(_camp["su"]):
			_camp["alzate"] = int(_camp["alzate"]) + 1
	_camp["su"] = su


func _la_raffica(rr: Array) -> void:
	print("\n--- 7) la raffica: quaranta pezzi in piazza, uno al secondo ---")
	b.sfila()
	# IL TESTIMONE STA DI TRAVERSO AL CANTIERE, novanta gradi esatti, e il
	# verso si ricava dalla piazza invece di riusare quello dell'orto: col
	# verso dell'orto la piazza gli cadeva quasi DAVANTI, la testa non doveva
	# girarsi per guardarla, e la misura diceva 5% qualunque cosa facesse il
	# codice. Una prova che non può fallire non è una prova.
	var centro_piazza := Vector3(float(PIAZZA_X0) + float(PIAZZA_W) * 0.5 - 0.5,
			0.0, float(PIAZZA_Z0) + 2.0)
	var verso_p := centro_piazza - TESTIMONE
	var yaw_p := atan2(-verso_p.x, -verso_p.z) - PI * 0.5
	b.inchioda(rr[0], TESTIMONE, yaw_p)
	b.inchioda(rr[1], LONTANO, yaw_p)
	b.inchioda(rr[2], ALTROVE, yaw_p)
	var t0: Node3D = (rr[0] as Dictionary)["node"]
	var f := Vector3(-sin(yaw_p), 0, -cos(yaw_p))
	var occhio_p := TESTIMONE + f * 2.1 + Vector3(0, 0.95, 0)
	var centro_p := TESTIMONE + Vector3(0, 0.66, 0)
	var prima_lontano := _ricordi(rr[1])
	# SI ASPETTA CHE IL TESTIMONE NON STIA GIÀ GUARDANDO NIENTE, e non è
	# pignoleria: lo strobo qui sopra gli lascia addosso uno sguardo di dodici
	# secondi, e la prima stesura di questa misura partiva dentro quello. Il
	# risultato era una raffica che sembrava cominciare con la testa già girata
	# (−48,9° al PRIMO pezzo, quando la molla non ha ancora avuto un frame per
	# muoversi) e un 27% che non era il suo.
	var attesa := 0.0
	while float(t0.get("_tst_t")) > 0.0 and attesa < 20.0:
		await create_timer(0.25).timeout
		attesa += 0.25
	await create_timer(0.6).timeout

	_camp = {"nodo": t0, "ms": Time.get_ticks_msec(), "girata": 0.0,
			"tot": 0.0, "alzate": 0, "su": false}
	process_frame.connect(_campiona)
	# I QUATTRO MOMENTI. Tre sono a pezzo fisso; il terzo NO — si scatta al
	# primo pezzo che RIALZA la testa, perché quel momento non si può
	# prevedere: il ritmo delle riprese è di ciascuno (`_taratura_sguardo`), e
	# un istante scelto a tavolino cadrebbe quasi sempre nel mezzo. Se la
	# ricevuta fosse ancora quella di prima, i quattro fotogrammi avrebbero
	# quattro teste girate uguali.
	var fatti := {}
	var ripresa := false
	for k in PIAZZA_PEZZI:
		var cella := Vector2i(PIAZZA_X0 + (k % PIAZZA_W), PIAZZA_Z0 + int(k / PIAZZA_W))
		# IL PEZZO SI POSA DAVVERO (si vede nel fotogramma), e si emette la
		# STESSA riga del sito vero — `BuildSystem._try_place`, parola per
		# parola, col punto del cursore. Chiamare `place_cell` non emette
		# niente da sé: l'emissione è del gesto del giocatore, non della
		# posa (è così che il caricamento di un villaggio non fa credere a
		# nessuno di aver visto costruire mille pezzi in un frame).
		b.build.call("place_cell", cella, "Sentiero", 0, false)
		call_group("percezione", "accaduto", "costruisce",
				Vector3(float(cella.x), 0.0, float(cella.y)))
		var quale := ""
		var didascalia := ""
		if k == 0:
			# mezzo secondo dopo il gesto: il tempo che la molla del collo ci
			# mette ad arrivare. Scattando nell'istante dell'emissione si
			# fotograferebbe una testa ancora dritta e si crederebbe un guasto.
			await create_timer(0.55).timeout
			quale = "5a-raffica-prima-occhiata"
			didascalia = "1° pezzo — la prima occhiata"
		elif k == 5:
			quale = "5b-raffica-ai-fatti-suoi"
			didascalia = "6° pezzo — il cantiere continua, lui è ai fatti suoi"
		elif not ripresa and k > 6 and float(t0.get("_tst_t")) > 0.0:
			ripresa = true
			await create_timer(0.45).timeout
			quale = "5c-raffica-la-ripresa"
			didascalia = "%d° pezzo — torna a dare un'occhiata" % (k + 1)
		elif k == 30:
			quale = "5d-raffica-di-nuovo-ai-fatti-suoi"
			didascalia = "31° pezzo — e di nuovo ai fatti suoi"
		if quale != "":
			var g: Vector2 = b.testa_gradi(t0)
			b.targa("%s  (ricevuta %+.0f°)" % [didascalia, g.y])
			await b.scatta(centro_p, occhio_p, quale)
			fatti[quale] = true
			print("       al pezzo %2d: testa %+6.1f° (ricevuta %+6.1f°)  — %s"
					% [k + 1, g.x, g.y, didascalia])
		await create_timer(PIAZZA_CADENZA).timeout
	process_frame.disconnect(_campiona)
	b.targa("")
	var nomi: Array = []
	for n in ["5a-raffica-prima-occhiata", "5b-raffica-ai-fatti-suoi",
			"5c-raffica-la-ripresa", "5d-raffica-di-nuovo-ai-fatti-suoi"]:
		if fatti.has(n):
			nomi.append(n)
	b.affianca(nomi, "5-provino-raffica")

	var tot := float(_camp["tot"])
	var girata := float(_camp["girata"])
	var quota := girata / maxf(tot, 0.001)
	print("       testa girata per %.1f s su %.1f (%.0f%%), in %d occhiate"
			% [girata, tot, quota * 100.0, int(_camp["alzate"])])
	# la soglia è una FRAZIONE DEL TEMPO, cioè la cosa che si vede — e non si
	# ricava da nessuna delle costanti che sorveglia. Prima della cura: 100%.
	b.dico(quota < 0.35,
			"quaranta pezzi non fanno quaranta ricevute (%.0f%% del tempo)" % (quota * 100.0))
	b.dico(int(_camp["alzate"]) >= 2,
			"…e non è nemmeno diventata muta: la testa si rialza %d volte"
					% int(_camp["alzate"]))
	# PRIMA E DOPO, non «zero»: a questo punto della prova chi era lontano ha
	# già un ricordo — gliel'ha raccontato il testimone nella sezione 3, ed è
	# giusto così. Quel che deve restare vero è che il CANTIERE non l'ha visto.
	b.dico(_ricordi(rr[1]) == prima_lontano,
			"e chi era a venti metri dal cantiere non ne ha visto niente")


# =========================================================================
#  8. LO STROBO DELLA TENUTA
# =========================================================================
#
# Una fotografia non sa dire se una posa è viva. Cinque fotografie della
# stessa inquadratura a mezzo secondo l'una dall'altra sì: se sono identiche
# la tenuta è un adesivo, e se i due vicini nel quadro hanno la stessa
# identica testa sono due pupazzi sullo stesso filo.

func _lo_strobo(rr: Array) -> void:
	print("\n--- 8) lo strobo: la tenuta è viva, e non è uguale per due ---")
	b.sfila()
	# I DUE AFFIANCATI, e si scostano LUNGO LA LINEA DEL GESTO — non di
	# traverso. Di traverso stavano uno DIETRO L'ALTRO rispetto alla lente (il
	# corpo è girato di novanta gradi dal gesto, quindi la perpendicolare al
	# gesto è proprio l'asse della camera): il primo strobo di questa prova
	# ritraeva un vicino solo, con l'altro nascosto dietro. Così invece la
	# lente li vede fianco a fianco — e il bersaglio resta nella stessa
	# direzione per tutti e due, quindi le due teste sono confrontabili.
	var bersaglio := _m(AIUOLA_VISTA)
	var u := (bersaglio - TESTIMONE).normalized()
	var pa := TESTIMONE - u * 0.62
	var pb := TESTIMONE + u * 0.62
	b.inchioda(rr[0], pa, _yaw_corpo)
	b.inchioda(rr[1], pb, _yaw_corpo)
	b.inchioda(rr[2], ALTROVE, 0.0)
	b.player.global_position = MOCHI_ORTO
	await create_timer(0.8).timeout

	var t0: Node3D = (rr[0] as Dictionary)["node"]
	var t1: Node3D = (rr[1] as Dictionary)["node"]
	# un gesto solo, e LUNGO: lo strobo deve stare dentro una tenuta sola
	for n in [t0, t1]:
		n.call("guarda_gesto", bersaglio, 12.0)
	await create_timer(0.5).timeout      # la molla è arrivata: comincia la tenuta

	var f := _avanti()
	var centro := TESTIMONE + Vector3(0, 0.72, 0)
	var occhio := TESTIMONE + f * 2.2 + Vector3(0, 0.86, 0)
	var nomi: Array = []
	var serie_a: Array = []
	var serie_b: Array = []
	for k in 5:
		var ga: Vector2 = b.testa_gradi(t0)
		var gb: Vector2 = b.testa_gradi(t1)
		serie_a.append(ga.x)
		serie_b.append(gb.x)
		b.targa("+%.1f s — sinistra %+.1f°   destra %+.1f°" % [float(k) * 0.5, ga.x, gb.x])
		await b.scatta(centro, occhio, "6%s-strobo" % ["a", "b", "c", "d", "e"][k])
		nomi.append("6%s-strobo" % ["a", "b", "c", "d", "e"][k])
		print("       +%.1f s   sinistra %+6.2f°   destra %+6.2f°   (scarto %.2f°)"
				% [float(k) * 0.5, ga.x, gb.x, absf(ga.x - gb.x)])
		await create_timer(0.5).timeout
	b.targa("")
	b.affianca(nomi, "6-provino-strobo", 640)

	var esc_a := _escursione(serie_a)
	var scarto := 0.0
	for i in serie_a.size():
		scarto = maxf(scarto, absf(float(serie_a[i]) - float(serie_b[i])))
	print("       escursione della tenuta: %.2f° · scarto massimo fra i due: %.2f°"
			% [esc_a, scarto])
	# le due soglie sono in GRADI e non vengono da nessuna costante del rig:
	# mezzo grado è il limite sotto il quale una differenza non esiste per
	# l'occhio, un grado è il limite sotto il quale una posa è ferma.
	b.dico(esc_a > 1.0, "la tenuta si muove (%.2f° di escursione in due secondi)" % esc_a)
	b.dico(scarto > 0.5,
			"e i due vicini non hanno la stessa identica testa (%.2f°)" % scarto)


func _escursione(s: Array) -> float:
	var lo := 9999.0
	var hi := -9999.0
	for x in s:
		lo = minf(lo, float(x))
		hi = maxf(hi, float(x))
	return hi - lo


# =========================================================================
#  9. LA SCENA RARA: il coro attorno al carillon, mentre Mochi costruisce
# =========================================================================
#
# `in_scena()` è la valvola che toglie un vicino ai gesti del giocatore
# mentre sta vivendo una scena scritta a mano. Per un pezzo l'unico a
# chiamarla era `Promesse`: il concerto, il coro, il nascondino, il raduno del
# lutto e la prima parola di un cucciolo restavano scoperti — con il commento
# di `Percezione.puo_vedere` che li elencava tutti e cinque.
#
# Qui la valvola si prova DOVE VIVE: si posa un Carillon vero, si gira la
# manovella, e mentre il coro canta si posa un pezzo a sei metri. Nessuna di
# quelle teste deve girarsi. È l'unica di queste sezioni che prova un
# CABLAGGIO invece di una taratura, e serve proprio perché un cablaggio
# mancante non si vede: la scena continua, solo peggio.

const CARILLON_CELLA := Vector2i(5, 11)


func _la_scena_rara(rr: Array) -> void:
	print("\n--- 9) la scena rara: il coro canta, Mochi costruisce accanto ---")
	b.sfila()
	var carillon_pos := _m(CARILLON_CELLA)
	b.build.call("place_cell", CARILLON_CELLA, "Carillon", 0, false)
	await create_timer(0.5).timeout
	var posati: Array = b.build.call("get_placed_by_name", "Carillon")
	if posati.is_empty():
		b.dico(false, "il Carillon si posa")
		return
	var carillon := posati[0] as Node3D
	# `var … =` e non `:=`: `get_first_node_in_group` torna un Node non
	# tipizzato e l'inferenza fallisce (la convenzione dei test del progetto).
	var concertino = get_first_node_in_group("concertino")
	if concertino == null:
		b.dico(false, "il Concertino c'è nel mondo vero")
		return

	# i due vicini a portata d'orecchio, e Mochi appena più in là
	await b.porta(0, carillon_pos + Vector3(2.2, 0, 1.4))
	await b.porta(1, carillon_pos + Vector3(-2.0, 0, 1.6))
	await b.porta(2, ALTROVE)
	b.player.global_position = carillon_pos + Vector3(6.0, 0, 0.5)
	await create_timer(0.5).timeout

	var t0: Node3D = (rr[0] as Dictionary)["node"]
	var t1: Node3D = (rr[1] as Dictionary)["node"]
	var prima0 := _ricordi(rr[0])
	var prima1 := _ricordi(rr[1])
	concertino.call("avvia", carillon)
	# il tempo di accorrere e stringersi in semicerchio (l'attesa vera è 2,8 s)
	await create_timer(4.0).timeout
	var in_scena0: bool = bool(t0.call("in_scena"))
	var in_scena1: bool = bool(t1.call("in_scena"))
	print("       in scena: %s %s · %s %s"
			% [str((rr[0] as Dictionary)["label"]), in_scena0,
			str((rr[1] as Dictionary)["label"]), in_scena1])
	b.dico(in_scena0 and in_scena1,
			"il coro attorno al carillon sta vivendo una scena")

	# …E ADESSO MOCHI POSA UN PEZZO A SEI METRI, la cosa più ordinaria del
	# gioco. Il gesto è quello vero del sito: stessa riga di `_try_place`.
	var dove_costruisce := carillon_pos + Vector3(6.0, 0, 0.0)
	b.build.call("place_cell", Vector2i(CARILLON_CELLA.x + 6, CARILLON_CELLA.y),
			"Sentiero", 0, false)
	call_group("percezione", "accaduto", "costruisce", dove_costruisce)
	await create_timer(0.5).timeout
	var g0: Vector2 = b.testa_gradi(t0)
	var g1: Vector2 = b.testa_gradi(t1)
	print("       dopo il gesto a %.1f m: teste %+.1f° e %+.1f° (ricevuta %+.1f° e %+.1f°)"
			% [carillon_pos.distance_to(dove_costruisce), g0.x, g1.x, g0.y, g1.y])
	b.targa("il coro canta. Mochi posa un pezzo a sei metri, e nessuno si volta")
	var occhio := carillon_pos + Vector3(0.4, 1.35, -3.6)
	await b.scatta(carillon_pos + Vector3(0, 0.75, 0), occhio, "7a-scena-rara")
	b.targa("")

	b.dico(absf(g0.y) < 1.0 and absf(g1.y) < 1.0,
			"e nessuna di quelle teste si gira verso il cursore")
	b.dico(_ricordi(rr[0]) == prima0 and _ricordi(rr[1]) == prima1,
			"…né il gesto entra nella loro memoria: la scena è tutta loro")


# =========================================================================

func _go() -> void:
	b = BANCO.new(self, OS.get_environment("CHIBI_PERC"))
	if not await b.apri():
		quit(1)
		return
	await _provino_tarature()
	if not await _posa_villaggio():
		quit(1)
		return
	var rr: Array = []
	for r in (b.visitors.get("_residents") as Array):
		rr.append(r)
	print("=== %s (casa %s) · %s (casa %s) · %s (casa %s) ==="
			% [rr[0]["label"], CASA_A, rr[1]["label"], CASA_B, rr[2]["label"], CASA_C])

	var prima = await _panchina_prima(rr)
	await _la_ricevuta(rr)
	await _la_chiacchiera(rr)
	await _panchina_dopo(rr, prima)
	await _nessuno_ti_segue(rr)
	await _l_aiuola(rr)
	# LE DUE ULTIME VANNO IN FONDO, e non è per comodità: la sezione 7 posa
	# quaranta pezzi in piazza e riempie di ricordi il testimone. Messe prima,
	# tutto quello che viene dopo (la chiacchiera, la panchina, l'aiuola)
	# misurerebbe un vicino che ha appena visto un cantiere intero.
	# E LO STROBO VA PRIMA DELLA RAFFICA, per una ragione di ripresa: dopo la
	# raffica il prato davanti al testimone è lastricato di quaranta pietre, e
	# cinque fotogrammi che devono far vedere una testa non hanno bisogno di un
	# cantiere in primo piano.
	await _lo_strobo(rr)
	await _la_raffica(rr)
	# LA SCENA RARA VA PER ULTIMA: il coro tiene i due vicini «in scena» per
	# tutta la durata del brano, e qualunque misura venisse dopo troverebbe due
	# corpi che il sistema — giustamente — sta ignorando.
	await _la_scena_rara(rr)
	b.sfila()
	quit(b.verdetto("PERCEZIONE"))
