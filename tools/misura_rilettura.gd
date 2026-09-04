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
## LE TRE DOMANDE, e la seconda è quella che può uccidere il lavoro
## ────────────────────────────────────────────────────────────────────────
##
## **1 · SUCCEDE?** Quante volte il villaggio sceglie di rileggere invece di
## mordersi la lingua, e su quanti vicini diversi.
##
## **2 · SI VEDE?** La frase è un Rialzo, e ogni Rialzo di questo gioco
## chiede il BUIO (`_sussulto_fresco`). Il buio qui dovrebbe esserci per
## costruzione — la strada veloce gira a 3,5 m e il confronto a 2,6, cioè
## meno di un secondo dopo a passo d'uomo — ma «dovrebbe» non è un numero.
## Se questa frazione è vicina a zero, la meccanica è invisibile e va detto.
##
## **3 · QUANTO COSTA NON RILEGGERE?** È la previsione falsificabile (Gross
## & Levenson: la soppressione lascia il corpo attivato, la rivalutazione
## no). Si misura **appaiata**: la stessa corsa, gli stessi vicini, le stesse
## storie, con la leva `Animo.debug_niente_rilettura` accesa e spenta.
##
## ⚠️ **E L'A/B NON PUÒ STARE DENTRO UNA CORSA SOLA.** La rilettura cambia
## la STORIA di quel vicino (le attese risalgono, la regolazione non si
## consuma) e una storia non si biforca a metà giornata: è la stessa
## eccezione, con la stessa ragione, delle cricche. Corse APPAIATE con gli
## stessi semi, e si riporta la distribuzione — mai un numero solo.
##
## ⚠️ **E L'OROLOGIO SI FERMA.** Un giorno del gioco dura quattro minuti e
## questo banco di più: senza, a metà prova i vicini vanno a dormire
## (`resident_sleep` li rimpicciolisce a scala 0.03) e si misurerebbe un
## prato vuoto.

const VISITORS := preload("res://scenes/npc/Visitors.gd")
const RIL := preload("res://scenes/npc/Rilettura.gd")

var _vis: Node = null
var _build: Node = null
var _player: Node3D = null

var _modi := {}
var _chi_rilegge := {}
var _chi_morde := {}
var _buio_si := 0
var _buio_no := 0
var _gesti_riletti := 0
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
	_prepara(residenti)

	print("")
	print("█".repeat(72))
	print("LA RILETTURA IN PARTITA — %d residenti, %.0f minuti%s"
			% [residenti.size(), minuti, "  ⟨SENZA RILETTURA⟩" if _spento else ""])
	print("  la porta e' `Animo.regola`, chiamata da `_tick_confronti`")
	print("  serve almeno %.2f di prove per unita' di torto, e un divario > 0"
			% RIL.RAPPORTO_MIN)
	print("█".repeat(72))
	await _guarda(minuti * 60.0, residenti)
	_referto(residenti, minuti * 60.0)
	quit(0)


## LE DUE STORIE, e la differenza fra loro e' l'unica cosa che cambia.
##
## Tutti ricevono lo STESSO identico torto — quattro volte «ignorato», la
## porta vera (`Animo.ricorda`, che passa dal Limbico e incide i marchi). La
## meta' pari ha in piu' un PASSATO: dieci gesti gentili del giocatore.
## Quello e' il materiale della rilettura, e non c'e' nient'altro che
## distingua i due gruppi.
func _prepara(residenti: Array) -> void:
	var animi: Dictionary = _vis.get("_animi")
	var con_prove := 0
	for k in residenti.size():
		var r: Dictionary = residenti[k]
		var lab := str(r.get("label", ""))
		if not animi.has(lab):
			continue
		var animo: RefCounted = animi[lab]
		animo.set("debug_niente_rilettura", _spento)
		if k % 2 == 0:
			for _i in 10:
				animo.ricorda("regalo", "giocatore", 0.8, 0.9)
			con_prove += 1
		for _i in 4:
			animo.ricorda("ignorato", "giocatore", -0.8, 0.9)
		# e il gradino nella finestra del morso: [svogliato, confronto)
		r["gradino"] = 2
		animo.set("gradino", 2)
	print("preparati: %d con un passato buono, %d senza — stesso torto per tutti"
			% [con_prove, residenti.size() - con_prove])


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

		# ORACOLO INDIPENDENTE: si legge il referto dei SI' di `Visitors`
		# (`debug_gesti_contatori`), che conta per nome, e si guarda il
		# DELTA. Chiedere al contatore se ha ragione sarebbe chiedere al
		# giudice se e' d'accordo con se' stesso.
		var conta: Dictionary = _vis.call("debug_gesti_contatori")
		for chiave in conta:
			# ⚠️ `debug_gesti_contatori` antepone «✓ » ai SUCCESSI e lascia
			# nudi i no: cercare la chiave nuda contava ZERO decisioni
			# mentre il referto dei no ne dichiarava cinque, nella stessa
			# stampa. Un banco che si contraddice da solo e' peggio di uno
			# che tace.
			var kk := str(chiave)
			if not kk.begins_with("✓ regola: "):
				continue
			var modo := kk.substr(10)
			var adesso := int(conta[chiave])
			var prima := int(visto.get(kk, 0))
			if adesso > prima:
				_modi[modo] = int(_modi.get(modo, 0)) + (adesso - prima)
				visto[kk] = adesso

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
	print("")
	print("(le domande 3 e 4 si leggono APPAIATE con la corsa")
	print(" CHIBI_SENZA_RILETTURA=1: una corsa sola non dice niente)")
