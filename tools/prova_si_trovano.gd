extends SceneTree
## SI TROVANO — la prova VIVA, nel MainLevel vero.
##
##   ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##       --resolution 1280x720 --script res://tools/prova_si_trovano.gd
##   CHIBI_TROVANO=/dove/le/foto …          (le foto: serve la finestra)
##   CHIBI_MINUTI=6                         (quanto dura la partita finta)
##
## La suite dice che il duetto è indivisibile, che il riposo lo pagano in
## due e che chi sta da solo non cambia di un bit. Non dice **quanto spesso
## il momento capita davvero**, e questo è il numero che decide se la fase è
## viva o è codice morto con la suite verde — il guasto che questo progetto
## si è già trovato in casa tre volte (i gesti pesanti di `Affetti`, il Filo
## Rosso, il vento delle corde).
##
## ============================================================
## LE CINQUE SCENE
## ============================================================
##   1  IL MOMENTO, frame per frame — chi si ferma per primo, il Δt VERO
##      misurato sul corpo, i secondi di sovrapposizione, dove vanno dopo
##   2  I NOVE NO DELL'USCIERE, uno per uno — un duetto tace quasi sempre, e
##      senza il conto per motivo nessuno saprà mai se funziona o se è morto
##   3  CHI STA DA SOLO — i tre numeri appaiati (gesti ricevuti, secondi di
##      lease, distanza da qualcuno) su un residente che non si ritrova con
##      nessuno, col sistema ACCESO e SPENTO nella stessa corsa
##   4  IL GIOCATORE NEL LORO POSTO — ci si mette in mezzo e si guarda se
##      qualcuno se ne accorge
##   5  UNA PARTITA — N minuti col villaggio che vive, e i momenti contati
##
## ⚠️ **L'ORACOLO DELLA SCENA 3 È INDIPENDENTE.** I contatori li tiene il
## sistema; qui si guardano i CORPI e le righe dei residenti. Chiedere al
## sistema se ha ragione è chiedere al giudice se è d'accordo con sé stesso,
## che è l'errore che `tools/misura_cammino.gd` esiste per non commettere.

const CRICCHE := preload("res://scenes/npc/Cricche.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")

var _liv: Node = null
var _vis: Node = null
var _cric: Node = null
var _dn: Node = null
var _build: Node = null
var _player: Node3D = null
var _dove := ""
var _scatti := 0


func _init() -> void:
	_go()


func _go() -> void:
	_dove = OS.get_environment("CHIBI_TROVANO")
	if _dove != "":
		DirAccess.make_dir_recursive_absolute(_dove)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 12:
		await process_frame
	_liv = current_scene
	_vis = _liv.get_node_or_null("Visitors")
	_cric = _liv.get_node_or_null("Cricche")
	_dn = _liv.get_node_or_null("DayNight")
	_build = _liv.get_node_or_null("BuildSystem")
	_player = _liv.get_node_or_null("Player") as Node3D
	if _vis == null or _player == null:
		print("GUASTO: manca Visitors o Player nel MainLevel")
		quit(1)
		return
	if _cric == null:
		print("GUASTO: il nodo Cricche non è in MainLevel.tscn — la fase è")
		print("        SCOLLEGATA, e nessuna suite può accorgersene.")
		quit(1)
		return
	if _build != null:
		_build.call("set_persist_for_debug", false)
	# l'orologio si ferma: una giornata dura quattro minuti e questa prova ne
	# dura parecchi. Senza, a metà i vicini vanno a dormire e si misura il
	# sonno invece del ritrovo.
	if _dn != null:
		_dn.set("cycle_seconds", 1000000.0)
		_dn.set("time", 0.42)
	await create_timer(1.5).timeout

	var quanti := 6
	var celle := await _insedia(quanti)
	if celle.size() < 4:
		print("GUASTO: insediati solo %d vicini" % celle.size())
		quit(1)
		return
	print("  insediati %d vicini" % celle.size())

	var dove := await _ritrovo_seminato()
	await _scena_1_il_momento(dove)
	_scena_2_i_no()
	await _scena_3_chi_sta_da_solo(dove)
	await _scena_4_il_giocatore(dove)
	await _scena_5_una_partita()

	print("\n  scatti: %d%s" % [_scatti, "" if _dove == "" else " in " + _dove])
	quit(0)


# ------------------------------------------------------------------ il banco

## UNA CASA NON È UN LETTO, e `debug_settle` su una cella senza letto non
## insedia nessuno **in silenzio**: prima si costruisce (letto + tetto, e si
## verifica la copertura), poi si insedia. Le celle si provano una per una
## perché `place_cell` rifiuta senza dire niente nel letto del fiume.
##
## E I CORPI VANNO SULLA PROPRIA CELLA: `Visitors` calcola i luoghi a partire
## da `home = cell`, e un corpo a trenta metri dalla sua cella pianifica per
## un posto e cammina in un altro. (Sono tutte e due trappole di banco già
## pagate dalla Fase 5.)
func _insedia(quanti: int) -> Array:
	if _build == null:
		return []
	var celle: Array = []
	var k := 0
	while celle.size() < quanti and k < 80:
		var cella := Vector2i(6 + (k % 8) * 3, -6 + int(k / 8) * 3)
		k += 1
		_build.call("place_cell", cella, "Letto", 0, false)
		_build.call("place_cell", cella, "Tetto", 0, false)
		if not bool(_build.call("has_cover", cella)):
			continue
		celle.append(cella)
	# e qualche posto dove andare: senza cespugli e senza panchine nessun
	# luogo è raggiungibile, quindi nessuno cammina, quindi nessun momento
	for e in 8:
		_build.call("place_cell", Vector2i(2 + e * 2, 4),
				["Cespuglio", "Panchina", "Aiuola", "Lampada"][e % 4], 0, false)
	_build.call("aggiorna_varchi_ora")
	for i in celle.size():
		_vis.call("debug_settle", 5000 + i * 37, celle[i])
	await create_timer(1.5).timeout
	var res: Array = _vis.get("_residents")
	for j in res.size():
		var cc: Vector2i = (res[j] as Dictionary)["cell"]
		_vis.call("debug_stage_resident", j, Vector3(cc.x, 0, cc.y))
	await create_timer(1.0).timeout
	return celle


## Semina un'abitudine VERA fra i primi due residenti, passando dalla
## funzione di produzione (`Cricche.registra`): un registro scritto a mano
## proverebbe un formato invece che un predicato.
func _ritrovo_seminato() -> Vector3:
	var res: Array = _vis.get("_residents")
	if res.size() < 2:
		return Vector3.ZERO
	var na := str((res[0].get("dna", {}) as Dictionary).get("name", ""))
	var nb := str((res[1].get("dna", {}) as Dictionary).get("name", ""))
	var ca: Vector2i = res[0]["cell"]
	var cb: Vector2i = res[1]["cell"]
	var dove := Vector3(float(ca.x + cb.x) * 0.5, 0.0, float(ca.y + cb.y) * 0.5)
	var oggi := int(_dn.get("day")) if _dn != null else 1
	var ora := float(_dn.get("time")) if _dn != null else 0.5
	var inc: Array = _cric.get("_incontri")
	for g in 4:
		CRICCHE.registra(inc, na, nb, oggi - 4 + g, ora, dove)
	_cric.set("_incontri", inc)
	_cric.set("_ultimo_giorno", -1)
	_cric.call("giro_del_giorno", oggi)
	var coppie: Array = _cric.get("_coppie")
	print("  seminata l'abitudine di %s e %s attorno a (%.1f, %.1f)"
			% [na, nb, dove.x, dove.z])
	print("  coppie vive: %d · cricche: %d"
			% [coppie.size(), (_cric.get("_oggi") as Array).size()])
	return dove


func _scatta(nome: String) -> void:
	if _dove == "":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_jpg(
			_dove.rstrip("/") + "/" + nome + ".jpg", 0.92)
	_scatti += 1


func _corpo(i: int) -> Node3D:
	var res: Array = _vis.get("_residents")
	return res[i].get("node") as Node3D


# ------------------------------------------------------------------ scena 1

## LA PELLICOLA DEL MOMENTO. Il Δt fra i due fermi non si crede sulla parola:
## si guarda il rig, fotogramma per fotogramma, e si stampa **quando il ciclo
## del passo di ciascuno arriva a zero**.
func _scena_1_il_momento(dove: Vector3) -> void:
	print("")
	print("█".repeat(72))
	print("SCENA 1 — IL MOMENTO, frame per frame")
	print("█".repeat(72))
	var a := _corpo(0)
	var b := _corpo(1)
	_player.global_position = dove + Vector3(0, 0, 6.5)
	await create_timer(0.4).timeout
	await _due_giri(a, b, dove)
	var ult: Dictionary = _vis.call("debug_duetto_ultimo")
	if ult.is_empty():
		print("  nessun duetto. I no dell'usciere, uno per uno:")
		var no: Dictionary = _vis.call("debug_gesti_contatori")
		var kk: Array = no.keys()
		kk.sort()
		for k in kk:
			print("     %-46s %4d" % [str(k), int(no[k])])
		return
	print("  apre %s, risponde %s, battuta %.3f s"
			% [str(ult["apre"]), str(ult["risponde"]), float(ult["battuta"])])
	var t0 := Time.get_ticks_msec()
	var fermo_a := -1.0
	var fermo_b := -1.0
	var insieme := 0.0
	var scatto := 0
	# la pellicola dura più del gesto (Punto ≈ 3,4 s): un conto che finisce
	# prima misura un pavimento e lo fa sembrare una misura
	for _k in 600:
		await process_frame
		var t := float(Time.get_ticks_msec() - t0) / 1000.0
		var va := _ritmo(a)
		var vb := _ritmo(b)
		if fermo_a < 0.0 and va < 0.15:
			fermo_a = t
		if fermo_b < 0.0 and vb < 0.15:
			fermo_b = t
		if va < 0.15 and vb < 0.15:
			insieme += get_root().get_process_delta_time()
		if _k % 12 == 0:
			print("   t=%5.2f  ritmo A=%.2f B=%.2f  gesto A=%-7s B=%-7s  d=%.2f m"
					% [t, va, vb, str(a.call("gesto_in_corso")),
						str(b.call("gesto_in_corso")),
						a.global_position.distance_to(b.global_position)])
			await _scatta("momento_%02d" % scatto)
			scatto += 1
	print("")
	print("  → il primo si ferma a %.2f s, il secondo a %.2f s: Δt = %.2f s"
			% [fermo_a, fermo_b, absf(fermo_b - fermo_a)])
	print("  → fermi INSIEME per %.2f s (la scritta è PUNTO_TENUTA ≈ 1,8)"
			% insieme)
	print("  → e dopo se ne vanno a %.1f m l'uno dall'altro"
			% a.global_position.distance_to(b.global_position))


func _ritmo(v: Node3D) -> float:
	var an = v.get("_andatura")
	return 1.0 if an == null else float(an.blend)


## I DUE GIRI DEL MOMENTO: il primo semina la distanza precedente (senza un
## «prima» non esiste un «si avvicinano»), il secondo chiede.
##
## ⚠️ **FRA L'ULTIMO SPOSTAMENTO E LA DOMANDA NON PASSA UN FOTOGRAMMA**, e
## la prima stesura non lo rispettava: mezzo secondo di attesa in mezzo, e i
## due corpi camminavano davvero — arrivavano a meno di `GESTO_STRADA_MIN`
## dalla loro meta, e l'usciere rispondeva «troppo vicino all'arrivo». Il
## banco dichiarava un silenzio che era **suo**. (Il numero grande è la
## stessa ragione: partire da 5,2 m lascia strada davanti anche dopo che il
## motore ha macinato i suoi frame.)
func _due_giri(a: Node3D, b: Node3D, dove: Vector3) -> void:
	_avvicina(a, b, dove, 5.2)
	await create_timer(0.4).timeout
	_avvicina(a, b, dove, 5.2)
	_sgombra()
	_cric.call("debug_guarda_ora")     # semina il «prima»
	await create_timer(0.3).timeout
	_avvicina(a, b, dove, 4.0)
	_sgombra()
	_cric.call("debug_guarda_ora")     # …e adesso si chiede


func _sgombra() -> void:
	_vis.set("_gesto_acc", 0.0)
	_vis.set("_gesto_chi", "")
	_vis.set("_gesto_riposo", {})


## La geometria della convergenza: dallo stesso quadrante, o due che arrivano
## da parti opposte disterebbero per forza più di sei metri (ognuno deve
## avere tre metri di strada davanti).
func _avvicina(a: Node3D, b: Node3D, dove: Vector3, raggio: float) -> void:
	var arco := PI / 3.0
	# ⚠️ **L'AGENDA SI ZITTISCE, o il banco misura un'altra cosa.** Fra il
	# momento in cui li si mette in cammino e quello in cui si guarda passano
	# dei fotogrammi VERI, e in quei fotogrammi il registro dell'agenda può
	# cambiare mestiere a uno dei due: il corpo esce da «walk» e il duetto
	# tace per una ragione che con questa prova non c'entra. È il lease, cioè
	# l'idioma con cui gli undici sistemi a evento fanno aspettare l'agenda —
	# lo stesso che `prova_deduzione` usa per la stessa ragione.
	for r in (_vis.get("_residents") as Array):
		var n := (r as Dictionary).get("node") as Node3D
		if n == a or n == b:
			(r as Dictionary)["next_act"] = 30.0
	for i in 2:
		var v: Node3D = a if i == 0 else b
		var ang := -arco * 0.5 + arco * float(i)
		var p := dove + Vector3(sin(ang), 0.0, cos(ang)) * raggio
		v.global_position = p
		v.call("_enter_state", "r_idle")
		v.call("_walk_to", dove, "r_idle")
		v.set("_gs_viaggio", false)
		v.global_position = p


# ------------------------------------------------------------------ scena 2

## I NO DELL'USCIERE, uno per uno. Un duetto tace quasi sempre — è il
## comportamento normale — e senza il conto per motivo nessuno saprà mai se
## sta funzionando o se è morto.
func _scena_2_i_no() -> void:
	print("")
	print("█".repeat(72))
	print("SCENA 2 — I NO DELL'USCIERE E I MOMENTI RICONOSCIUTI")
	print("█".repeat(72))
	var no: Dictionary = _vis.call("debug_gesti_contatori")
	var chiavi: Array = no.keys()
	chiavi.sort()
	for k in chiavi:
		print("   %-52s %5d" % [str(k), int(no[k])])
	print("  ---")
	var m: Dictionary = _cric.call("debug_momenti")
	var mk: Array = m.keys()
	mk.sort()
	for k2 in mk:
		print("   %-52s %5d" % [str(k2), int(m[k2])])
	if mk.is_empty():
		print("   (nessun momento riconosciuto: o non è la loro ora, o non")
		print("    c'è nessuna coppia viva — vedi `debug_stato`)")


# ------------------------------------------------------------------ scena 3

## CHI STA DA SOLO — i tre numeri, appaiati sulla STESSA corsa.
##
## ⚠️ **È LA MISURA DI RIPRESA, e non è la cricca: è chi è fuori.** Se uno di
## questi tre peggiora, il canale che lo peggiora si toglie, non si tara.
func _scena_3_chi_sta_da_solo(dove: Vector3) -> void:
	print("")
	print("█".repeat(72))
	print("SCENA 3 — CHI STA DA SOLO (l'oracolo è indipendente)")
	print("█".repeat(72))
	var res: Array = _vis.get("_residents")
	var soli: Array = []
	for i in range(res.size()):
		var nome := str((res[i].get("dna", {}) as Dictionary).get("name", ""))
		if (_cric.call("compagni", nome) as PackedStringArray).is_empty():
			soli.append(i)
	print("  chi si ritrova con qualcuno: %d · chi no: %d"
			% [res.size() - soli.size(), soli.size()])
	if soli.is_empty():
		print("  (tutti si ritrovano: questa scena non ha soggetto)")
		return
	# il solitario si mette IN MEZZO ai due che si ritrovano, alla loro ora,
	# nel loro posto: il caso più ostile che si possa costruire
	var solo := _corpo(int(soli[0]))
	solo.global_position = dove
	solo.call("_enter_state", "r_idle")
	res[int(soli[0])]["next_act"] = 0.0
	var lease0 := float(res[int(soli[0])].get("next_act", 0.0))
	var gesto0 := str(solo.call("gesto_in_corso"))
	var ancora0: Vector3 = _vis.call("_ancora_ritrovo", res[int(soli[0])],
			Vector3(9, 0, 9))
	_player.global_position = dove + Vector3(0, 0, 6.5)
	_cric.set("_duetto_giorno", -1)
	_cric.set("_duetto_visti", {})
	await _due_giri(_corpo(0), _corpo(1), dove)
	await create_timer(1.0).timeout
	var lease1 := float(res[int(soli[0])].get("next_act", 0.0))
	var gesto1 := str(solo.call("gesto_in_corso"))
	print("  il solitario, prima e dopo che i due si trovino accanto a lui:")
	print("   · lease dell'agenda   %.2f s  →  %.2f s" % [lease0, lease1])
	print("   · gesto in corso      «%s»  →  «%s»" % [gesto0, gesto1])
	print("   · ancora della panca  %s (casa è (9, 9): scarto %.3f m)"
			% [str(ancora0), ancora0.distance_to(Vector3(9, 0, 9))])
	print("  → dev'essere TUTTO identico: per lui non è successo niente, ed è")
	print("    la differenza fra «sta bene da solo» e «nessuno lo vuole».")
	await _scatta("solitario")


# ------------------------------------------------------------------ scena 4

## IL GIOCATORE NEL LORO POSTO. Ci si mette in mezzo, alla loro ora, e si
## guarda se qualcuno se ne accorge. È l'unica scena in cui il canale deve
## parlare AL giocatore, ed è quella che rende impossibile la frase «il
## villaggio ha un posto in cui io non sono».
func _scena_4_il_giocatore(dove: Vector3) -> void:
	print("")
	print("█".repeat(72))
	print("SCENA 4 — IL GIOCATORE NEL LORO POSTO")
	print("█".repeat(72))
	var a := _corpo(0)
	var b := _corpo(1)
	var res: Array = _vis.get("_residents")
	# il duetto SAREBBE disponibile — niente traccia, niente tetto speso — ma
	# nel loro posto ci sei tu
	_cric.set("_duetto_giorno", -1)
	_cric.set("_duetto_visti", {})
	_cric.set("_momenti", {})
	_vis.set("_gesto_no", {})
	_vis.set("_gesto_si", {})
	# ⚠️ **MOCHI NEL LORO POSTO, MA DAVANTI A LORO.** La camera di questo
	# gioco non si gira: sta 3,7 m dietro Mochi e guarda −Z. Piazzandola
	# ESATTAMENTE sul punto di ritrovo, chi ci arriva da quella parte spunta
	# **dietro l'obiettivo** — misurato, 5 no su 6 «fuori dall'inquadratura».
	# Due metri più in qua è ancora «nel loro posto» (`ACCANTO` è 2,5) e i due
	# arrivano in campo.
	_player.global_position = dove + Vector3(0, 0, 2.0)
	await _due_giri(a, b, dove)
	var m: Dictionary = _cric.call("debug_momenti")
	print("   ci sei anche tu (chiesti/concessi): %d / %d"
			% [int(m.get("? ci sei anche tu", 0)),
				int(m.get("✓ ci sei anche tu", 0))])
	print("   il duetto ha lasciato il palco: %s"
			% str(int(_cric.get("_duetto_giorno")) < 0))
	var no4: Dictionary = _vis.call("debug_gesti_contatori")
	var k4: Array = no4.keys()
	k4.sort()
	for kk in k4:
		print("     %-46s %4d" % [str(kk), int(no4[kk])])
	# …e i sei secondi: con TE accanto, non ci si alza per primi
	a.global_position = dove
	a.call("_enter_state", "r_idle")
	res[0]["next_act"] = 0.0
	_player.global_position = dove + Vector3(1.2, 0, 0)
	_cric.call("debug_guarda_ora")
	print("   e il lease di chi era lì: %.2f s (i sei secondi contano ANCHE te)"
			% float(res[0].get("next_act", 0.0)))
	var t0 := Time.get_ticks_msec()
	for k in 8:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < float(k) * 0.35:
			await process_frame
		await _scatta("giocatore_%02d" % k)


# ------------------------------------------------------------------ scena 5

## UNA PARTITA. Il villaggio vive per N minuti col giocatore che gira, e si
## contano i momenti. È il numero che dice se la fase è viva.
func _scena_5_una_partita() -> void:
	var minuti := float(OS.get_environment("CHIBI_MINUTI").to_float())
	if minuti <= 0.0:
		minuti = 3.0
	print("")
	print("█".repeat(72))
	print("SCENA 5 — UNA PARTITA di %.0f minuti" % minuti)
	print("█".repeat(72))
	# l'orologio riparte: senza giornate che passano non c'è nessun giro del
	# giorno, quindi nessuna coppia viva e nessun momento
	if _dn != null:
		_dn.set("cycle_seconds", 240.0)
	_vis.set("_gesto_no", {})
	_vis.set("_gesto_si", {})
	_cric.set("_momenti", {})
	# ⚠️ **I DUE TETTI SI AZZERANO, o questa scena non misura niente.** Le
	# quattro scene di sopra hanno già speso il duetto del giorno e hanno già
	# segnato quella coppia come «vista»: senza azzerare, il conto qui sotto
	# sarebbe zero **per costruzione**, e si leggerebbe come «la fase è
	# morta» invece che «il banco si è mangiato il suo stesso soggetto».
	_cric.set("_duetto_giorno", -1)
	_cric.set("_duetto_visti", {})
	var t0 := Time.get_ticks_msec()
	var raggio := 14.0
	var frame := 0
	while float(Time.get_ticks_msec() - t0) / 1000.0 < minuti * 60.0:
		await process_frame
		frame += 1
		var t := float(Time.get_ticks_msec() - t0) / 1000.0
		# Mochi gira per il villaggio come gira un giocatore
		_player.global_position = Vector3(cos(t * 0.11) * raggio, 0.0,
				sin(t * 0.07) * raggio)
		if frame % 1800 == 0:
			var st: Dictionary = _cric.call("debug_stato")
			print("   t=%5.0f s · giorno %d · coppie %d · cricche %d · momenti %s"
					% [t, int(st.get("giorno", 0)), int(st.get("coppie", 0)),
						(st.get("cricche", []) as Array).size(),
						str(st.get("momenti", {}))])
	print("")
	_scena_2_i_no()
	var st2: Dictionary = _cric.call("debug_stato")
	print("  ---")
	print("  righe di co-presenza: %d" % int(st2.get("incontri", 0)))
	print("  coppie che si ritrovano: %d" % int(st2.get("coppie", 0)))
	print("  cricche: %d" % (st2.get("cricche", []) as Array).size())
