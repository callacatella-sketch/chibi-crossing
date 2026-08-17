extends SceneTree
## LA SCENA DELLA FASE 5, nel MainLevel VERO — e senza nessun modello.
##
##   Godot --headless --path . --script res://tools/prova_deduzione.gd
##
## La suite prova le regole; questo prova **la scena**, che è l'unica cosa
## che il giocatore vede. E la prova senza un `.gguf` da due gigabyte: le
## bozze sono tre JSON scritti a mano, che è esattamente quello che un
## modello restituirebbe. Tutto il resto del cammino è quello vero — il
## Giudice vero, il ponte vero, il registro vero, il corpo vero.
##
## LE TRE DOMANDE, e nessuna si può fare con un'asserzione booleana:
##
##  1. **la testa si gira DAVVERO, e verso il posto giusto?** Si campiona
##     l'imbardata del collo frame per frame e si stampa la pellicola. Una
##     posa non si giudica in un fotogramma: la ricevuta è un movimento, e
##     un movimento si guarda in una tabella di angoli.
##  2. **la conseguenza arriva DOPO?** Si stampa l'istante in cui la testa
##     arriva sul bersaglio e quello in cui la deduzione diventa un
##     obiettivo. Se il secondo non è dopo il primo, la premessa e la
##     conseguenza sono la stessa cosa, e non si legge niente.
##  3. **il corpo va DOVE ha guardato?** Si lascia recitare il registro vero
##     e si stampa dove cammina.
##
## E una quarta, che è la promessa dell'autore: **rifatto tutto senza la
## deduzione, il vicino fa quello che avrebbe fatto comunque.** È il ramo
## che gira sulla macchina di chi non ha installato niente, e va guardato
## anche lui.

const DED := preload("res://scenes/npc/Deduzioni.gd")
const FOGLIO := preload("res://scenes/npc/FoglioDelVicino.gd")
const SUG := preload("res://scenes/npc/Suggeritore.gd")
const PERCEZIONE := preload("res://scenes/npc/Percezione.gd")
const VISITOR := preload("res://scenes/npc/Visitor.gd")

const CASA := Vector2i(6, 6)
## UN SECONDO VICINO, e serve alla scena 4: senza nessuno con cui parlare
## «quattro_chiacchiere» non manda il corpo da nessuna parte, e la prova
## «senza deduzione fa quello che farebbe comunque» misurerebbe un corpo
## fermo dov'era — cioè non misurerebbe niente.
const CASA_2 := Vector2i(14, 4)
## I DUE POSTI, e stanno DI FIANCO alla casa, non davanti: il vicino li vede
## (nove metri è il raggio della percezione) e per guardarli deve girare la
## testa di traverso — che è il caso in cui il movimento si legge. Un
## bersaglio davanti al muso non produrrebbe nessuna imbardata da misurare.
##
## Ce ne sono DUE perché la deduzione non si sceglie a mano: si legge quello
## che il mondo può servire adesso (`Visitors.obiettivi_fattibili`) e si mette
## il gesto di Mochi **nel posto di quell'obiettivo**. Così la premessa (dove
## ha guardato) e la conseguenza (dove va) sono lo stesso punto, che è il
## motivo per cui la scena si legge.
const CESPUGLIO := Vector2i(2, 11)
const PANCHINA := Vector2i(11, 10)
const POSTO_DI := {
	"provvedi_pancino": CESPUGLIO,
	"provvedi_energia": PANCHINA,
}

## La soglia del villaggio: `Visitors.AMMIRA_SOGLIA`.
const SOGLIA := 0.35

## A CHE DISTANZA STA MOCHI mentre il vicino paga la sua ricevuta. Dentro
## `Deduzioni.RAGGIO` (4,5 m) perché la testa che si gira si veda, e non
## addosso: il vicino gironzola attorno a casa sua, e a mezzo metro gli si
## finirebbe in mezzo alla strada.
const MOCHI_GUARDA_DA := 2.6

var _guasti := 0


func _init() -> void:
	_go()


func _dico(ok: bool, testo: String) -> void:
	if not ok:
		_guasti += 1
	print(("  ok      " if ok else "  GUASTO  ") + testo)


func _go() -> void:
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 8:
		await process_frame
	var livello := current_scene
	if livello == null:
		print("GUASTO: il MainLevel non si è caricato")
		quit(1)
		return
	var build := livello.get_node_or_null("BuildSystem")
	var visitors := livello.get_node_or_null("Visitors")
	if build == null or visitors == null:
		print("GUASTO: BuildSystem=%s Visitors=%s" % [build, visitors])
		quit(1)
		return
	build.call("set_persist_for_debug", false)
	await create_timer(1.2).timeout

	visitors.call("debug_reset")
	build.call("place_cell", CASA, "Letto", 0, false)
	build.call("place_cell", CASA, "Tetto", 0, false)
	build.call("place_cell", CESPUGLIO, "Cespuglio", 0, false)
	build.call("place_cell", PANCHINA, "Panchina", 0, false)
	build.call("place_cell", CASA_2, "Letto", 0, false)
	build.call("place_cell", CASA_2, "Tetto", 0, false)
	build.call("aggiorna_varchi_ora")
	visitors.call("debug_settle", 4242, CASA)
	await create_timer(0.8).timeout
	visitors.call("debug_settle", 7171, CASA_2)
	await create_timer(0.8).timeout

	var residenti: Array = visitors.get("_residents")
	if residenti.is_empty():
		print("GUASTO: nessun residente")
		quit(1)
		return
	var r: Dictionary = residenti[0]
	var corpo: Node3D = r["node"]
	var cuore: Object = visitors.call("cuore")
	if cuore == null:
		print("GUASTO: nessun cuore ECS (GDExtension non caricata?)")
		quit(1)
		return
	var id := int(r["ecs"])
	print("\n=== %s, casa in %s ===" % [str(r.get("label", "?")), CASA])

	# ------------------------------------------------------------------
	# 0) COSA PUÒ DEDURRE, e DOVE. Non si sceglie a mano: si chiede al
	#    villaggio per cosa ha una strada adesso (è la stessa lista che
	#    entra nella grammatica) e si mette il gesto di Mochi nel posto di
	#    quell'obiettivo. Premessa e conseguenza nello stesso punto.
	# ------------------------------------------------------------------
	var giorno := livello.get_node_or_null("DayNight")
	# SI ZITTISCE L'AGENDA per tutta la prova, con lo stesso lease che usano
	# gli undici sistemi a evento. Senza, fra il gesto e la deduzione il
	# registro cambia mestiere da solo: l'obiettivo che il vicino sta già
	# perseguendo esce dai deducibili (giustamente — proporlo non sarebbe una
	# deduzione) e il banco proverebbe una cosa diversa a ogni corsa. È lo
	# stesso motivo per cui i banchi delle rotte spengono il turno.
	visitors.call("debug_force_activity", 0, "gironzola")
	await create_timer(0.4).timeout
	var rit0: Dictionary = FOGLIO.ritratto(visitors, giorno, cuore, r, "pensiero", "Mochi")
	print("\n        (l'agenda è ferma su «%s»)" % str(rit0.get("azione", "?")))
	var offerti := SUG.obiettivi_deducibili(rit0)
	print("\n--- 0) cosa il mondo può servire: %s ---" % str(offerti))
	var obiettivo := ""
	for o in offerti:
		if POSTO_DI.has(str(o)):
			obiettivo = str(o)
			break
	_dico(obiettivo != "", "c'è almeno un obiettivo deducibile con un posto suo")
	if obiettivo == "":
		print("        (il vicino sta già facendo tutto quello che il mondo serve)")
		quit(1)
		return
	var cella: Vector2i = POSTO_DI[obiettivo]
	var posto := Vector3(cella.x, 0, cella.y)

	# ------------------------------------------------------------------
	#    IL GESTO. Mochi lavora là sotto gli occhi del vicino: è la PREMESSA
	#    di tutto, e non la si fabbrica a mano — passa dal bus della
	#    percezione, come in partita.
	# ------------------------------------------------------------------
	print("        Mochi annaffia a %s (per «%s»), e lui guarda" % [posto, obiettivo])
	# TRE GESTI DENTRO LA FINESTRA DI FUSIONE: fanno UN ricordo con `quante = 3`
	# — «ti ho vista lavorare lì per un pezzo» — che pesa più del doppio della
	# soglia e non scade a metà della prova. Fuori dalla finestra sarebbero
	# tre ricordi identici, cioè tre righe uguali nel foglio: vero, ma non
	# quello che questa scena vuole mostrare.
	for _k in 3:
		call_group("percezione", "accaduto", "annaffia", posto, "")
		await create_timer(2.5).timeout

	# ⚠️ **E POI MOCHI TORNA INDIETRO E RESTA LÌ A GUARDARE.**
	#
	# La ricevuta non si paga a chi non ha nessuno che lo guardi
	# (`Deduzioni.RAGGIO`), e senza questa riga il banco misurerebbe una scena
	# che in partita non succede: un vicino che gira la testa in un villaggio
	# vuoto. Non è una comodità di banco — è il pezzo di mondo che il banco
	# deve fornire, come l'orologio fermo e il lease sull'agenda.
	#
	# Si mette dalla parte OPPOSTA all'ancora, e a più di un metro e mezzo:
	# se fosse sulla linea di sguardo, la testa che si gira si leggerebbe come
	# «sta guardando lei», che è la scena della Fase 4 e non questa.
	var casa_del_vicino := Vector3(CASA.x, 0, CASA.y)
	var giocatore := livello.get_node_or_null("Player") as Node3D
	_dico(giocatore != null, "il MainLevel ha un Player (senza, nessuna ricevuta)")
	if giocatore != null:
		var indietro: Vector3 = casa_del_vicino - posto
		indietro.y = 0.0
		indietro = indietro.normalized() if indietro.length() > 0.01 else Vector3.FORWARD
		var dove_mochi: Vector3 = casa_del_vicino + indietro * MOCHI_GUARDA_DA
		giocatore.global_position = Vector3(dove_mochi.x,
				giocatore.global_position.y, dove_mochi.z)
		print("        Mochi torna a %.1f m da casa sua e guarda (dalla parte opposta all'ancora)"
				% MOCHI_GUARDA_DA)

	var grafo: Dictionary = cuore.call("debug_grafo", id)
	var righe: Array = grafo.get("ricordi", [])
	_dico(righe.size() >= 1, "il gesto è nel suo grafo (%d ricordi)" % righe.size())
	if righe.is_empty():
		quit(1)
		return
	var ritmo: Dictionary = cuore.call("debug_ritmo")
	print("        il ricordo pesa %.3f (soglia %.2f)"
			% [float(cuore.call("debug_grafo_peso", righe[0], ritmo["tempo"],
					ritmo["mezza_vita"])), SOGLIA])

	# lo sguardo del gesto deve essersi SPENTO prima di misurare la ricevuta,
	# o si misurerebbe quello invece di questa
	await create_timer(PERCEZIONE.DURATA_SGUARDO + 1.5).timeout

	# ------------------------------------------------------------------
	# 1) LA DEDUZIONE. Tre bozze come le scriverebbe un modello, e la porta
	#    vera: `Deduzioni.incassa` apre il JSON, il Giudice sceglie, il
	#    ponte incassa.
	# ------------------------------------------------------------------
	print("\n--- 1) il modello ha scritto tre bozze; il Giudice ne prende una ---")
	var rit: Dictionary = FOGLIO.ritratto(visitors, giorno, cuore, r, "pensiero", "Mochi")
	var vive := SUG.righe_vive(rit)
	var offerti2 := SUG.obiettivi_deducibili(rit)
	print("        righe vive: %s · obiettivi offerti: %s" % [str(vive), str(offerti2)])
	_dico(vive.size() > 0, "c'è almeno un ricordo su cui appoggiarsi")
	_dico(offerti2.has(obiettivo), "«%s» è ancora deducibile" % obiettivo)
	if vive.is_empty() or not offerti2.has(obiettivo):
		quit(1)
		return
	# IL FOGLIO E LA GRAMMATICA, per esteso. Si guardano a occhio, come le
	# citazioni delle lettere: sono le due sole cose che il modello vede, e
	# nessun test può dire se si leggono bene.
	var parti: Dictionary = SUG.parti_deduzione(rit)
	_dico(not parti.is_empty(), "il foglio della deduzione si costruisce")
	if not parti.is_empty():
		print("\n······ QUELLO CHE IL MODELLO LEGGE ······")
		print(str(parti["sistema"]))
		print("")
		print(str(parti["utente"]))
		print("······································\n")
	print("%s" % SUG.grammatica_deduzione(rit))
	var bozze := [
		"{\"obiettivo\":\"%s\",\"perche\":[%d]}" % [obiettivo, int(vive[0])],
		"{\"obiettivo\":\"%s\",\"perche\":[99]}" % obiettivo,   # riga inventata
		"non è nemmeno un json",
	]
	var aperte := DED.bozze_da(bozze)
	_dico(aperte.size() == 2, "quella che non è un JSON sparisce (%d aperte)" % aperte.size())
	var esito: Dictionary = DED.incassa(cuore, id, aperte, rit,
			{"fattibili": offerti2}, SOGLIA)
	print("        esito: %s" % str(esito))
	_dico(int(esito["indice"]) >= 0, "la deduzione è entrata nel grafo")
	_dico(str(esito["obiettivo"]) == obiettivo,
			"e la bozza che citava una riga inesistente è stata buttata")
	if int(esito["indice"]) < 0:
		quit(1)
		return

	# il grafo dei ricordi non si è mosso di un byte
	_dico(str(cuore.call("debug_grafo", id)) == str(grafo),
			"e il grafo dei RICORDI è rimasto identico")

	# ------------------------------------------------------------------
	# 2) LA RICEVUTA, frame per frame. La ricevuta la paga il registro da
	#    solo, alla cadenza dei fatti: non si chiama niente a mano.
	# ------------------------------------------------------------------
	print("\n--- 2) la ricevuta: si ASPETTA il momento, poi la testa si gira ---")
	print("        (nessuno la chiama a mano: la paga `Visitors._cuore_di`)")
	print("        t      collo    scarto dal bersaglio   muta?  pronta?")
	# lo si lascia gironzolare, che è quello che fa un vicino: camminando
	# cambia verso, e prima o poi il posto gli finisce davanti. Se non
	# succedesse, la deduzione morirebbe in silenzio — l'esito buono.
	visitors.call("debug_force_activity", 0, "gironzola")
	var t0 := 0.0
	var t_ricevuta := -1.0
	var scarto_alla_ricevuta := -1.0
	var picco := 999.0
	var t_picco := -1.0
	var t_pronta := -1.0
	var girata := false
	while t0 < 40.0:
		await process_frame
		# il passo nominale del motore: qui non serve il delta vero, serve un
		# asse dei tempi leggibile accanto agli angoli
		t0 += 1.0 / 60.0
		var scarto := _scarto(corpo, posto)
		var collo := _collo(corpo)
		var muta := int(cuore.call("deduzione_muta", id, SOGLIA)) >= 0
		if not muta and t_ricevuta < 0.0:
			t_ricevuta = t0
			scarto_alla_ricevuta = scarto
			print("        ---- ricevuta pagata a t=%.2f, con %.1f° di scarto ----"
					% [t0, rad_to_deg(scarto)])
		if t_ricevuta >= 0.0:
			if scarto < picco:
				picco = scarto
				t_picco = t0
			if absf(collo) > 0.12:
				girata = true
		var pronta := int(cuore.call("deduzione_pronta", id, SOGLIA,
				DED.ATTESA, DED.finestra(cuore))) >= 0
		if pronta and t_pronta < 0.0:
			t_pronta = t0
		if fmod(t0, 1.0) < 1.0 / 60.0:
			print("        %5.2f  %+6.1f°   %6.1f°               %s      %s"
					% [t0, rad_to_deg(collo), rad_to_deg(scarto),
							"sì" if muta else "—", "sì" if pronta else "—"])
		if pronta and t0 - t_pronta > 1.0:
			break
	_dico(t_ricevuta >= 0.0, "la ricevuta è stata pagata (a t=%.2f)" % t_ricevuta)
	_dico(scarto_alla_ricevuta >= 0.0
					and scarto_alla_ricevuta <= VISITOR.tetto_ricevuta() + 0.15,
			"e nell'istante in cui si paga il posto era DAVANTI a lui (%.1f°, tetto %.1f°)"
					% [rad_to_deg(scarto_alla_ricevuta), rad_to_deg(VISITOR.tetto_ricevuta())])
	_dico(girata, "la testa si è girata davvero (non è restata a zero)")
	_dico(picco < deg_to_rad(25.0),
			"e ha puntato il posto (minimo %.1f° a t=%.2f)" % [rad_to_deg(picco), t_picco])
	_dico(t_pronta > t_ricevuta,
			"la conseguenza è arrivata DOPO la premessa (vista a %.2f, pronta a %.2f)"
					% [t_ricevuta, t_pronta])

	# ------------------------------------------------------------------
	# 3) IL CORPO. L'agenda vorrebbe fare due chiacchiere; la deduzione dice
	#    di andare dove ha guardato. Si guarda dove cammina.
	# ------------------------------------------------------------------
	var dedotta := DED.azione_di(obiettivo)
	print("\n--- 3) l'agenda dice «quattro_chiacchiere», la deduzione dice «%s» ---"
			% dedotta)
	var casa := Vector3(CASA.x, 0, CASA.y)
	visitors.call("debug_force_activity", 0, "quattro_chiacchiere")
	await create_timer(1.5).timeout
	var meta := _dove_va(corpo)
	print("        va verso %s (stato «%s»)" % [meta, corpo.get("_state")])
	print("        distanza dal posto guardato: %.2f m · da casa: %.2f m"
			% [meta.distance_to(posto), meta.distance_to(casa)])
	_dico(meta.distance_to(posto) < 2.5,
			"cammina verso IL POSTO CHE HA GUARDATO, non dove l'agenda lo mandava")

	# ------------------------------------------------------------------
	# 4) E SENZA. La deduzione è spesa: lo stesso identico gesto rifà quello
	#    che il gioco fa da sempre. È il ramo di chi non ha il modello.
	# ------------------------------------------------------------------
	print("\n--- 4) la deduzione è spesa: il gioco torna quello di sempre ---")
	_dico(int(cuore.call("deduzione_pronta", id, SOGLIA, DED.ATTESA,
			DED.finestra(cuore))) < 0, "non c'è più niente di pronto")
	# LA STESSA DOMANDA, alla stessa porta: adesso risponde «niente».
	var stessa := str(DED.dirotta(cuore, id, "quattro_chiacchiere",
			r.get("luoghi", []), int(r.get("fatti", 0)), SOGLIA))
	_dico(stessa == "quattro_chiacchiere",
			"il dirottamento restituisce la stessa Stringa che gli è arrivata («%s»)" % stessa)
	# e si lascia arrivare, o si misurerebbe il viaggio di prima
	var atteso := 0.0
	while atteso < 20.0 and str(corpo.get("_state")) == "walk":
		await create_timer(0.5).timeout
		atteso += 0.5
	print("        arrivato dopo %.1f s (stato «%s», a %.2f m dal posto guardato)"
			% [atteso, corpo.get("_state"), corpo.global_position.distance_to(posto)])
	visitors.call("debug_force_activity", 0, "quattro_chiacchiere")
	await create_timer(1.5).timeout
	var meta2 := _dove_va(corpo)
	print("        va verso %s (stato «%s»)" % [meta2, corpo.get("_state")])
	print("        distanza dal posto guardato: %.2f m · dall'altro vicino: %.2f m"
			% [meta2.distance_to(posto),
					meta2.distance_to(Vector3(CASA_2.x, 0, CASA_2.y))])
	_dico(meta2.distance_to(posto) > 2.5,
			"e adesso NON ci torna: fa quello che farebbe su qualunque macchina")

	print("\n==== DEDUZIONE: %s ====" % ("TUTTO A POSTO" if _guasti == 0
			else "%d GUASTI" % _guasti))
	quit(1 if _guasti > 0 else 0)


## L'imbardata del collo, così com'è stata disegnata. Zero = la testa sta
## dove lo stato l'ha messa.
func _collo(corpo: Node3D) -> float:
	var testa = corpo.get("_head")
	if testa == null or not is_instance_valid(testa):
		return 0.0
	return wrapf(float((testa as Node3D).rotation.y), -PI, PI)


## Di quanto la testa MANCA il bersaglio, in radianti. Si misura sul muso
## vero (il rig guarda −Z), non su un angolo interno: è quello che si vede.
func _scarto(corpo: Node3D, bersaglio: Vector3) -> float:
	var testa = corpo.get("_head")
	if testa == null or not is_instance_valid(testa):
		return PI
	var t := testa as Node3D
	var avanti: Vector3 = -t.global_transform.basis.z
	avanti.y = 0.0
	var verso: Vector3 = bersaglio - t.global_position
	verso.y = 0.0
	if avanti.length() < 0.001 or verso.length() < 0.001:
		return PI
	return absf(avanti.normalized().angle_to(verso.normalized()))


## Dove sta andando: la meta del cammino se ne ha una, altrimenti dov'è.
func _dove_va(corpo: Node3D) -> Vector3:
	if corpo.has_method("meta_cammino"):
		var m: Vector3 = corpo.call("meta_cammino")
		if m != Vector3.ZERO:
			return m
	return corpo.global_position
