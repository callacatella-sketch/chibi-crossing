extends SceneTree
## LA RILETTURA IN PARTITA — succede davvero, e quanto costa non farla.
##
##   CHIBI_MINUTI=8 CHIBI_QUANTI=14 ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --resolution 1280x720 --script res://tools/misura_rilettura.gd
##
## Questo banco NON collega niente: apre il MainLevel vero, insedia i
## residenti, costruisce le due storie con le porte VERE (`Animo.ricorda`,
## che è il canale unico di ogni evento del gioco) e poi fa camminare Mochi
## come cammina un giocatore. Se il cablaggio in `Visitors._tick_confronti`
## non ci fosse, qui non succederebbe niente — ed è l'unico modo di
## accorgersene: la suite resterebbe verde comunque.
##
## ────────────────────────────────────────────────────────────────────────
## LE QUATTRO DOMANDE, e la terza è quella che può uccidere il lavoro
## ────────────────────────────────────────────────────────────────────────
##
## **0 · SI PUÒ?** ⚠️ **È la domanda che questo banco non faceva, e che vale
## più delle altre tre messe insieme.** La rilettura vive in una finestra
## stretta e CONTESA: `_tick_confronti` chiede di regolare solo a chi sta in
## `[svogliato, confronto)` — sotto non c'è nessun impulso da tenere dentro,
## sopra il corpo va allo sfogo e la regolazione non si chiede affatto — e
## dentro quella finestra la rilettura vuole `prove_totali / torti ≥
## RAPPORTO_MIN`. Le due condizioni tirano in direzioni OPPOSTE: **il gradino
## sale col rancore, e il rancore scende con le prove**. Quanto si
## sovrappongono non è una curiosità: è la frequenza massima con cui questa
## meccanica può accadere in una partita, e il referto la conta.
##
## **1 · SUCCEDE?** Quante volte il villaggio sceglie di rileggere invece di
## mordersi la lingua, e su quanti vicini diversi.
##
## **2 · SI VEDE?** La frase è un Rialzo, e ogni Rialzo di questo gioco
## chiede il BUIO (`_sussulto_fresco`).
##
## ⚠️ **E LA RISPOSTA, MISURATA DA QUESTO BANCO, È QUASI MAI.** La prima
## stesura di questa riga diceva che il buio c'è per costruzione — «la strada
## veloce gira a 3,5 m e il confronto a 2,6» — ed era sbagliata su tutti e
## due i fatti: il raggio è **3,2 m** e la coda somatica la arma **solo**
## `trasalisce`, che vuole una carica negativa oppure `grezzo > 0,25`. A
## passo d'uomo `indizio_grezzo` vale **0,185 anche a distanza zero**: chi
## cammina non fa sussultare nessuno. E chi ha le prove per rileggere è per
## definizione chi NON ha un marchio negativo addosso, cioè **il buio manca
## proprio a chi rilegge**.
##
## **3 · QUANTO COSTA NON RILEGGERE?** È la previsione falsificabile (Gross
## & Levenson: la soppressione lascia il corpo attivato, la rivalutazione
## no). Si misura **appaiata**: la stessa corsa, gli stessi vicini, le stesse
## storie, con la leva `Animo.debug_niente_rilettura` accesa e spenta.
##
## ⚠️ **E L'A/B NON PUÒ STARE DENTRO UNA CORSA SOLA.** La rilettura cambia
## la giornata di quel vicino — la `regolazione` non consumata è forza che
## avrà più tardi, e chi non scoppia non prende la postura né il toast — e
## una storia non si biforca a metà: è la stessa eccezione, con la stessa
## ragione, delle cricche. Corse APPAIATE con gli stessi semi, e si riporta
## la distribuzione, mai un numero solo.
##
## ⚠️ **E L'OROLOGIO SI FERMA.** Un giorno del gioco dura quattro minuti e
## questo banco di più: senza, a metà prova i vicini vanno a dormire
## (`resident_sleep` li rimpicciolisce a scala 0.03) e si misurerebbe un
## prato vuoto.

const VISITORS := preload("res://scenes/npc/Visitors.gd")
const RIL := preload("res://scenes/npc/Rilettura.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")

## LA STORIA CHE SI COSTRUISCE, e i tre numeri non sono di gusto.
##
## ⚠️ Servono perche' il gradino ENTRI da se' nella finestra `[svogliato,
## confronto)`, che e' l'unico posto in cui `_tick_confronti` chiede di
## regolare. Il conto che li ha scelti (e **e' un conto, non una misura**: a
## misurare e' il censimento che il banco stampa):
##
##  · un torto ripetuto si ABITUA (`Limbico.rivaluta`, `ABITUDINE` 0.30):
##    dopo i primi giorni quello che si sente e' ~`letto x 0.25`, cioe' un
##    torto da -0.8 vale ~0.2 a riga. Con quattro al giorno sono ~0.8;
##  · `rancore()` satura a `1 - exp(-somma/55*3)`, e la soglia «svogliato»
##    con tratti medi sta attorno a 0.38 (0.18 + lealta*0.22 + grinta*0.18):
##    servono ~6.5 di torti accumulati, cioe' una settimana scarsa;
##  · le gentilezze devono essere PIU' dei torti, o il rapporto della
##    rilettura non arriva a `RAPPORTO_MIN` — e il banco misurerebbe una
##    finestra aperta con la porta accanto chiusa.
##
## Si spostano con `CHIBI_TORTI` / `CHIBI_DONI` / `CHIBI_GIORNATE`: se il
## censimento dice che nessuno entra nella finestra, la manopola e' quella.
const TORTI_AL_GIORNO := 4
const DONI_AL_GIORNO := 6
const GIORNATE_MAX := 40

var _vis: Node = null
var _build: Node = null
var _player: Node3D = null

var _modi := {}
var _spento := false
var _giro := -1


func _init() -> void:
	_go()


func _m(c: Vector2i) -> Vector3:
	return Vector3(c.x, 0.0, c.y)


func _go() -> void:
	var minuti := 8.0
	if OS.get_environment("CHIBI_MINUTI") != "":
		minuti = float(OS.get_environment("CHIBI_MINUTI"))
	var quanti := 14
	if OS.get_environment("CHIBI_QUANTI") != "":
		quanti = int(OS.get_environment("CHIBI_QUANTI"))
	_spento = OS.get_environment("CHIBI_SENZA_RILETTURA") != ""

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 10:
		await process_frame
	var liv := current_scene
	_build = liv.get_node_or_null("BuildSystem")
	_vis = liv.get_node_or_null("Visitors")
	_player = liv.get_node_or_null("Player") as Node3D
	var dn := liv.get_node_or_null("DayNight")
	if _build == null or _vis == null or _player == null:
		print("GUASTO: manca qualcosa nel MainLevel")
		quit(1)
		return
	# ⚠️ il banco NON tocca il village.json dell'autore: un banco altrui si e'
	# gia' portato via due gigabyte in questo repository.
	_build.call("set_persist_for_debug", false)
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	await create_timer(1.5).timeout

	_vis.call("debug_reset")
	var celle: Array[Vector2i] = []
	for gx in range(-7, 7):
		for gz in range(-7, 7):
			celle.append(Vector2i(gx * 2, gz * 2))
	celle.shuffle()
	var letti := 0
	var i := 0
	while letti < quanti and i < celle.size():
		var c: Vector2i = celle[i]
		i += 1
		_build.call("place_cell", c, "Letto", 0, false)
		_build.call("place_cell", c, "Tetto", 0, false)
		if not bool(_build.call("has_cover", c)):
			continue
		letti += 1
	_build.call("aggiorna_varchi_ora")
	var celle_letto: Array[Vector2i] = []
	for k in range(mini(letti, celle.size())):
		celle_letto.append(celle[k])
	for k in celle_letto.size():
		_vis.call("debug_settle", 5000 + k * 37, celle_letto[k])
	await create_timer(1.5).timeout
	var residenti: Array = _vis.get("_residents")
	if residenti.is_empty():
		print("GUASTO: nessun residente")
		quit(1)
		return
	for k in residenti.size():
		_vis.call("debug_stage_resident", k, _m((residenti[k] as Dictionary)["cell"]))
	await create_timer(1.0).timeout

	print("")
	print("█".repeat(72))
	print("LA RILETTURA IN PARTITA — %d residenti, %.0f minuti%s"
			% [residenti.size(), minuti, "  ⟨SENZA RILETTURA⟩" if _spento else ""])
	print("  la porta e' `Animo.regola`, chiamata da `_tick_confronti`")
	print("  e prima di lei la porta del GRADINO: [svogliato, confronto)")
	print("  la rilettura serve almeno %.2f di prove per unita' di torto"
			% RIL.RAPPORTO_MIN)
	print("█".repeat(72))
	var giorni := _prepara(residenti)
	_porte(residenti, "0 · SI PUÒ?   dopo %d giornate di storia" % giorni)
	await _guarda(minuti * 60.0, residenti)
	_referto(residenti, minuti * 60.0)
	quit(0)


## LE DUE STORIE, e la differenza fra loro e' l'unica cosa che cambia.
##
## Tutti ricevono lo STESSO identico torto, ogni giorno, dalla porta vera
## (`Animo.ricorda`, che passa dal Limbico e incide i marchi). La meta' pari
## ha in piu' un PASSATO: le gentilezze del giocatore, allo stesso ritmo.
## Quello e' il materiale della rilettura, e non c'e' nient'altro che
## distingua i due gruppi.
##
## ⚠️⚠️ **E IL GRADINO NON SI SCRIVE PIU' A MANO — la prima stesura misurava
## la rilettura in uno stato che le sue stesse righe rendono
## IRRAGGIUNGIBILE.** Faceva `r["gradino"] = 2` e `animo.set("gradino", 2)`
## per mettere tutti dentro la finestra del morso; ma `rancore()` e'
## `maxf(0, torti - prove*1.4)`, e per la meta' CON le prove — dieci
## gentilezze contro quattro torti — quel numero e' **0.000 esatto**, quindi
## `aggiorna_scala()` avrebbe tenuto quella meta' a «lavoro» per sempre e la
## porta vera non si sarebbe mai aperta proprio su chi ha di che rileggere.
## Uno stato scritto a mano non e' uno stato del gioco: e' un ritratto.
##
## Adesso la storia si costruisce **un giorno alla volta**, con
## `passa_giorno()` e `aggiorna_scala("giocatore")` chiamati nell'ordine in
## cui li chiama il villaggio (`Visitors._giorno_di_animo`), e il gradino
## sale da se' — uno al giorno, come promette `aggiorna_scala`. Dove arriva
## lo dice il censimento delle due porte; se non arriva a nessuno, il referto
## lo dice invece di far finta, e **quello e' il risultato**.
##
## ⚠️ E ci si ferma quando META' del villaggio e' nella finestra, non al
## primo che ci entra: con un solo residente dentro, le sezioni 3 e 4 —
## che confrontano due GRUPPI — misurerebbero una persona contro tredici.
## Torna le giornate che ci sono volute.
func _prepara(residenti: Array) -> int:
	var animi: Dictionary = _vis.get("_animi")
	var torti := TORTI_AL_GIORNO
	if OS.get_environment("CHIBI_TORTI") != "":
		torti = maxi(0, int(OS.get_environment("CHIBI_TORTI")))
	var doni := DONI_AL_GIORNO
	if OS.get_environment("CHIBI_DONI") != "":
		doni = maxi(0, int(OS.get_environment("CHIBI_DONI")))
	var tetto := GIORNATE_MAX
	if OS.get_environment("CHIBI_GIORNATE") != "":
		tetto = maxi(1, int(OS.get_environment("CHIBI_GIORNATE")))

	var con_prove := 0
	for k in residenti.size():
		var lab := str((residenti[k] as Dictionary).get("label", ""))
		if not animi.has(lab):
			continue
		(animi[lab] as RefCounted).set("debug_niente_rilettura", _spento)
		if k % 2 == 0:
			con_prove += 1
	print("")
	print("preparati: %d con un passato buono (%d gentilezze al giorno), %d senza"
			% [con_prove, doni, residenti.size() - con_prove])
	print("           %d torti al giorno per TUTTI, e il gradino sale da se'"
			% torti)

	var giorni := 0
	while giorni < tetto:
		giorni += 1
		for k in residenti.size():
			var lab := str((residenti[k] as Dictionary).get("label", ""))
			if not animi.has(lab):
				continue
			var animo: RefCounted = animi[lab]
			if k % 2 == 0:
				for _i in doni:
					animo.ricorda("piatto", "giocatore", 0.8, 0.9)
			for _i in torti:
				animo.ricorda("ignorato", "giocatore", -0.8, 0.9)
			animo.passa_giorno()
			animo.aggiorna_scala("giocatore")
		if (_finestra(residenti) as Array).size() * 2 >= residenti.size():
			break
	return giorni


## Chi sta DENTRO la finestra del morso: `[svogliato, confronto)` — l'unico
## posto in cui `_tick_confronti` chiede ad `Animo.regola` cosa fare. Torna
## gli indici, perche' il censimento deve poter dire anche CHI.
##
## ⚠️ I due estremi si chiedono per NOME a `Animo.almeno`, mai per indice: la
## `SCALA` e' fonte unica e un indice a mano punta al gradino sbagliato
## appena qualcuno ne inserisce uno in mezzo — in silenzio.
func _finestra(residenti: Array) -> Array:
	var animi: Dictionary = _vis.get("_animi")
	var out: Array = []
	for k in residenti.size():
		var lab := str((residenti[k] as Dictionary).get("label", ""))
		if not animi.has(lab):
			continue
		var g := int((animi[lab] as RefCounted).gradino)
		if ANIMO.almeno(g, "svogliato") and not ANIMO.almeno(g, "confronto"):
			out.append(k)
	return out


## ⚠️ **IL CENSIMENTO DELLE DUE PORTE — la cosa piu' importante che questo
## banco possa dire.**
##
## La prima porta e' il GRADINO (`[svogliato, confronto)`), la seconda e' il
## RAPPORTO (`prove_totali / torti >= RAPPORTO_MIN`). Tirano in direzioni
## opposte, perche' il gradino sale col rancore e il rancore scende con le
## prove: **quante persone soddisfano tutt'e due insieme e' il tetto della
## frequenza di questa meccanica**, e nessuna asserzione sa dirlo.
##
## Si stampano anche i due complementi, perche' un «zero» ha due cause
## diversissime che da fuori si vedono uguali — nessuno nella finestra
## (troppo poco rancore, o troppo) contro nessuno con le prove.
func _porte(residenti: Array, titolo: String) -> void:
	var animi: Dictionary = _vis.get("_animi")
	var sotto := 0
	var oltre := 0
	var dentro: Array = _finestra(residenti)
	var pronti := 0
	var prove_fuori := 0
	var gradini := {}
	for k in residenti.size():
		var lab := str((residenti[k] as Dictionary).get("label", ""))
		if not animi.has(lab):
			continue
		var a: RefCounted = animi[lab]
		var g := int(a.gradino)
		var nome := str(ANIMO.SCALA[clampi(g, 0, ANIMO.SCALA.size() - 1)])
		gradini[nome] = int(gradini.get(nome, 0)) + 1
		if not ANIMO.almeno(g, "svogliato"):
			sotto += 1
		elif ANIMO.almeno(g, "confronto"):
			oltre += 1
		# ⚠️ `prove_totali`, non `prove`: e' l'aggregato che legge la
		# rilettura (vedi la testata di `Animo.conto_verso`). Chiedere
		# `prove` qui direbbe che nessuno puo' rileggere mai.
		var c: Dictionary = a.conto_verso("giocatore")
		var rap: float = RIL.rapporto(float(c["torti"]), float(c["prove_totali"]))
		if rap >= RIL.RAPPORTO_MIN:
			if k in dentro:
				pronti += 1
			else:
				prove_fuori += 1
	print("")
	print(titolo)
	# ⚠️ i gradini si elencano nell'ordine di `ANIMO.SCALA`, non in quello in
	# cui il Dictionary li ha visti: un censimento che cambia ordine fra due
	# corse non si puo' confrontare a occhio.
	var righe := PackedStringArray()
	for gr in ANIMO.SCALA:
		if gradini.has(gr):
			righe.append("%s x%d" % [str(gr), int(gradini[gr])])
	print("      i gradini:  %s" % (" · ".join(righe)
			if not righe.is_empty() else "—"))
	print("      sotto la finestra %d · DENTRO %d · oltre (sfogo) %d"
			% [sotto, dentro.size(), oltre])
	print("      ⇒ dentro la finestra E con le prove per rileggere: %d su %d"
			% [pronti, residenti.size()])
	print("        con le prove ma FUORI dalla finestra: %d" % prove_fuori)
	print("        (avrebbero di che rileggere e non hanno niente da regolare)")
	if pronti == 0:
		print("      ⚠️ NESSUNO puo' rileggere adesso: le due porte si escludono")
		print("         in questo stato, e le sezioni 1 e 2 misureranno zero —")
		print("         il che e' un RISULTATO, non un guasto del cablaggio.")


func _guarda(secondi: float, residenti: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var meta := Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10))
	var sosta := 0.0
	var t := 0.0
	var ms := Time.get_ticks_msec()
	var avviso := 0.0
	# lo stato di ieri, per accorgersi di un modo NUOVO senza chiedere a
	# nessuno di raccontarcelo: l'oracolo e' indipendente dal contatore.
	var visto: Dictionary = {}
	while t < secondi:
		await process_frame
		var ora := Time.get_ticks_msec()
		var dt := float(ora - ms) / 1000.0
		ms = ora
		if dt <= 0.0 or dt > 0.5:
			continue
		t += dt
		if t - avviso > 60.0:
			avviso = t
			print("  … %.0f s · riletture %d · morsi %d · scoppi %d"
					% [t, int(_modi.get("rilettura", 0)),
					int(_modi.get("morso", 0)), int(_modi.get("scoppio", 0))])

		# ⚠️ **QUESTO NON È UN ORACOLO INDIPENDENTE, e la prima stesura lo
		# dichiarava tale.** `debug_regola_contatori()` è il contatore che
		# `_tick_confronti` scrive: è la stessa funzione di cui il banco
		# misura le decisioni, cioè si sta chiedendo al giudice se è
		# d'accordo con sé stesso. Se un domani quella riga contasse il modo
		# sbagliato, il referto lo confermerebbe con entusiasmo.
		# L'oracolo vero è la colonna 3, che legge il CORPO (`regolazione`,
		# `morsi_oggi`, `esausto`) senza chiedere niente a `Visitors` — ed è
		# quella su cui si legge il risultato.
		var conta: Dictionary = _vis.call("debug_regola_contatori")
		for chiave in conta:
			var modo := str(chiave)
			var adesso := int(conta[chiave])
			if adesso > int(visto.get(modo, 0)):
				_modi[modo] = adesso
				visto[modo] = adesso

		# Mochi cammina, e quando arriva DA QUALCUNO si ferma: il morso e la
		# rilettura vogliono meno di 2,6 m *e* un tick che ci cada dentro
		# (12 s di raffreddamento). Passandoci a sei metri al secondo la
		# finestra e' di mezzo secondo, e non ci cade nessuno.
		var p := _player.global_position
		if sosta > 0.0:
			sosta -= dt
		elif Vector2(p.x - meta.x, p.z - meta.z).length() < 1.2:
			sosta = 4.0
			# ⚠️ **SI VA SEMPRE DA QUALCUNO, A GIRO, E NON A CASO.** Due
			# ragioni, e la seconda e' quella che conta.
			#
			# (1) Questo banco misura il CONFRONTO, che vuole Mochi entro
			#     2,6 m e un tick che ci cada dentro (12 s di
			#     raffreddamento): con mete a caso su un prato di trenta
			#     metri non ci cade quasi nessuno.
			# (2) ⚠️ **E IL GIRO A CASO NON APPAIA LE DUE CORSE.** Con un
			#     bersaglio tirato a sorte il numero di contatti dipende da
			#     dove i corpi si trovano, e i due villaggi divergono appena
			#     il comportamento cambia: MISURATO, **22 decisioni nel
			#     braccio con la rilettura e 2 nel controllo** — con quello
			#     scarto le domande 3 e 4 non dicono niente, ed e' la stessa
			#     trappola gia' dichiarata per le cricche. A giro, il numero
			#     di contatti lo decide il banco e non il villaggio.
			if not residenti.is_empty():
				_giro = (_giro + 1) % residenti.size()
				var q: Dictionary = residenti[_giro]
				var qn := q.get("node") as Node3D
				if qn != null and is_instance_valid(qn):
					meta = qn.global_position
				else:
					meta = Vector3(rng.randf_range(-12, 12), 0,
							rng.randf_range(-12, 12))
		else:
			var d := (meta - p)
			d.y = 0.0
			if d.length() > 0.01:
				_player.global_position = p + d.normalized() \
						* minf(3.0 * dt, d.length())


func _referto(residenti: Array, secondi: float) -> void:
	var animi: Dictionary = _vis.get("_animi")
	print("")
	print("█".repeat(72))
	print("REFERTO — %.0f s di partita%s"
			% [secondi, "  ⟨SENZA RILETTURA⟩" if _spento else ""])
	print("█".repeat(72))
	var tot := 0
	for m in _modi:
		tot += int(_modi[m])
	print("")
	print("1 · SUCCEDE?   %d decisioni di regolazione in tutto" % tot)
	for m in ["rilettura", "morso", "scoppio"]:
		var n := int(_modi.get(m, 0))
		print("      %-11s %4d   (%.1f%%)"
				% [m, n, 100.0 * float(n) / float(maxi(tot, 1))])

	# 2 · SI VEDE? Il contatore dei SI' della regia («✓ ha_riletto») conta i
	# gesti CONCESSI: la differenza con le decisioni sono i no, e il referto
	# dei no li stampa per nome — un banco che dice solo «non si e' visto»
	# lascia indovinare, e si finisce per accusare il cablaggio quando era il
	# gettone.
	var conta: Dictionary = _vis.call("debug_gesti_contatori")
	var concessi := int(conta.get("✓ ha_riletto", 0))
	var decisioni := int(_modi.get("rilettura", 0))
	print("")
	print("2 · SI VEDE?   %d gesti concessi su %d riletture (%.1f%%)"
			% [concessi, decisioni, 100.0 * float(concessi)
			/ float(maxi(decisioni, 1))])
	for chiave in conta:
		var kk := str(chiave)
		if kk.begins_with("✓ ") or kk.begins_with("regola: "):
			continue
		print("      no · %-28s %d" % [kk, int(conta[chiave])])

	print("")
	print("3 · IL CORPO — quanto e' costato a chi ha regolato in un modo e")
	print("    nell'altro. Le due meta' hanno lo STESSO torto: cambia il passato.")
	# ⚠️ **SI STAMPA ANCHE QUANTE DECISIONI HA PRESO OGNI GRUPPO.** Senza,
	# un gruppo che non ha regolato NIENTE esce con «regolazione 1.0000» e si
	# legge come «non ha pagato», mentre vuol dire «non gli e' successo
	# niente»: due cose diversissime con lo stesso numero. E' capitato
	# davvero, in una corsa di questo banco.
	var somme := {"con": [0.0, 0.0, 0, 0, 0], "senza": [0.0, 0.0, 0, 0, 0]}
	for k in residenti.size():
		var lab := str((residenti[k] as Dictionary).get("label", ""))
		if not animi.has(lab):
			continue
		var a: RefCounted = animi[lab]
		var g := "con" if k % 2 == 0 else "senza"
		var v: Array = somme[g]
		v[0] += float(a.limbico.regolazione)
		v[1] += float(a.limbico.livello_neuro("cortisolo"))
		v[2] += 1
		v[3] += int(a.limbico.morsi_oggi)
		if bool(a.limbico.esausto()):
			v[4] += 1
	for g in ["con", "senza"]:
		var v: Array = somme[g]
		var n := maxi(int(v[2]), 1)
		print("      passato %-6s regolazione %.4f · cortisolo %.4f"
				% [g, float(v[0]) / float(n), float(v[1]) / float(n)])
		print("                     morsi riusciti %d · esausti %d/%d"
				% [int(v[3]), int(v[4]), int(v[2])])
	var vc: Array = somme["con"]
	var vs: Array = somme["senza"]
	if int(vc[2]) > 0 and int(vs[2]) > 0:
		print("      ⇒ scarto di regolazione: %+.4f"
				% [float(vc[0]) / float(vc[2]) - float(vs[0]) / float(vs[2])])
		print("      ⇒ scarto di cortisolo:   %+.4f"
				% [float(vc[1]) / float(vc[2]) - float(vs[1]) / float(vs[2])])

	print("")
	print("4 · LE ATTESE verso il giocatore, a fine partita")
	var att_c := 0.0
	var att_s := 0.0
	var nc := 0
	var ns := 0
	for k in residenti.size():
		var lab := str((residenti[k] as Dictionary).get("label", ""))
		if not animi.has(lab):
			continue
		var a: RefCounted = animi[lab]
		var somma := 0.0
		var n := 0
		for kk in a.limbico.attese:
			if not str(kk).ends_with("|giocatore"):
				continue
			somma += float(a.limbico.attese[kk])
			n += 1
		if n == 0:
			continue
		if k % 2 == 0:
			att_c += somma / float(n)
			nc += 1
		else:
			att_s += somma / float(n)
			ns += 1
	if nc > 0:
		print("      con un passato buono:  %+.4f" % (att_c / float(nc)))
	if ns > 0:
		print("      senza:                 %+.4f" % (att_s / float(ns)))
	# ⚠️ **IL CENSIMENTO SI RIFA' ANCHE ALLA FINE.** Fra l'inizio e la fine
	# `_tick_confronti` ha girato per minuti e i marchi si sono mossi; e se
	# le sezioni 1 e 2 sono a zero, questa tabella e' l'unica cosa che
	# distingue «il cablaggio non c'e'» da «le due porte non erano aperte
	# insieme su nessuno». Sono due diagnosi diversissime che da fuori si
	# vedono uguali.
	_porte(residenti, "5 · LE DUE PORTE, a fine partita")
	print("")
	print("(le domande 3 e 4 si leggono APPAIATE con la corsa")
	print(" CHIBI_SENZA_RILETTURA=1: una corsa sola non dice niente)")
