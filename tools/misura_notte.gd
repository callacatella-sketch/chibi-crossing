extends SceneTree
## LA NOTTE CHE ARRIVA — e il CANCELLO che decide se questo canale merita un
## corpo.
##
##   CHIBI_GIORNI=2 CHIBI_QUANTI=20 ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --resolution 1280x720 --script res://tools/misura_notte.gd
##
## ⚠️ **NON --headless**: due dei quattro numeri chiedono se il giocatore
## AVREBBE VISTO, e la visibilità si misura contro il frustum della camera
## vera — che senza rendering non esiste.
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ QUESTO BANCO ESISTE PRIMA DI SCRIVERE UNA RIGA DI RIG
## ────────────────────────────────────────────────────────────────────────
##
## La melatonina ha appena smesso di seguire la luce e ha cominciato a seguire
## la PROPRIA notte. È una correzione di correttezza, e da sola vale: il
## vecchio `Π · (1 − luce)` non era un orologio, era un **barometro** — un
## temporale di mezzogiorno la portava al 94% del picco serale, addosso a
## tutti insieme.
##
## Ma il canale non ha **nessun lettore**, e la tentazione è dargliene uno. Le
## quattro domande qui sotto dicono se quel lettore avrebbe qualcosa da
## leggere. **Se la 1 o la 4 falliscono, il corpo NON si fa** e la consegna è
## la sola correzione della sorgente — che è una consegna legittima, e va
## scritta così invece che travestita da funzione.
##
##   1. QUANTO ALTA arriva davvero, e per quanti secondi VISIBILI.
##      ⚠️ `Visitor.resident_sleep()` non manda nessuno a casa a piedi: appena
##      il sonno dice DORME il corpo si rimpicciolisce a 0.03 e sparisce.
##      Quindi tutta la finestra osservabile è la RAMPA, e basta.
##   2. QUANTI la vedono: la frazione di quei secondi in cui quel corpo era
##      dentro l'inquadratura della camera VERA.
##   3. LA SINCRONIA — il cancello d'arresto. `estremi_finestra` ha DUE soli
##      valori di inizio (0.80 e 0.92): se venti corpi si spengono nello
##      stesso istante, dentro la fase del falò, non è un ritmo circadiano —
##      è un carillon, ed è il contrario di cozy.
##   4. LA DISPERSIONE dell'adenosina alla sera: è la manopola con cui si
##      vorrebbe spezzare la sincronia (l'anticipo tinto dalla stanchezza).
##      Se alla sera sono tutti allo stesso livello, quella cura non cura.

const VISITORS := preload("res://scenes/npc/Visitors.gd")

var _liv: Node
var _vis: Node
var _dn: Node
var _cam: Camera3D
var _quanti := 20
var _giorni := 2

## per residente: campioni della melatonina, e quanti erano inquadrati
var _mel := {}
var _visti := {}
var _sopra := {}
## istante (in frazione di giornata) in cui ognuno ha superato la soglia
var _accensione := {}
var _adeno_sera := []
var _campioni := 0
## quante volte, in un campione, N corpi erano contemporaneamente sopra soglia
var _isto := {}
## i due casi, separati: la rampa di chi sta per rientrare, e la notte di chi
## non e' riuscito ad andare a letto
var _rampa := {}
var _fuori_casa := {}
var _mel_rampa := {}
var _mel_fuori := {}


## Dentro la propria finestra di sonno, adesso? Lo sa il C++, e glielo si
## chiede con la porta che c'e' — mai ricalcolando gli orari di qua.
func _dentro_finestra(r: Dictionary) -> bool:
	var ecs = _vis.get("_ecs")
	if ecs == null or not r.has("ecs"):
		return false
	return bool(ecs.call("in_finestra", int(r["ecs"])))

const SOGLIA := 0.05


func _init() -> void:
	_go()


func _go() -> void:
	if OS.get_environment("CHIBI_QUANTI") != "":
		_quanti = int(OS.get_environment("CHIBI_QUANTI"))
	if OS.get_environment("CHIBI_GIORNI") != "":
		_giorni = int(OS.get_environment("CHIBI_GIORNI"))
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 10:
		await process_frame
	_liv = current_scene
	_vis = _liv.get_node_or_null("Visitors")
	_dn = _liv.get_node_or_null("DayNight")
	var build := _liv.get_node_or_null("BuildSystem")
	if _vis == null or _dn == null or build == null:
		print("GUASTO: livello incompleto")
		quit(1)
		return
	# ⚠️ il salvataggio dell'autore non si tocca: un banco altrui si e' gia'
	# portato via due gigabyte.
	build.call("set_persist_for_debug", false)
	await create_timer(1.5).timeout
	_cam = get_root().get_camera_3d()

	var res: Array = _vis.get("_residents")
	print("")
	print("=".repeat(74))
	print("LA NOTTE CHE ARRIVA — %d residenti, %d giornate" % [res.size(), _giorni])
	print("  il binario sa rispondere a `fase_circadiana`? %s"
			% str(_vis.get("_ecs_sa_la_notte")))
	print("  anticipo %.3f di giornata = %.1f s reali (cycle %.0f)"
			% [VISITORS.ANTICIPO_NOTTE,
			VISITORS.ANTICIPO_NOTTE * float(_dn.get("cycle_seconds")),
			float(_dn.get("cycle_seconds"))])
	print("=".repeat(74))

	var fine := float(_dn.get("cycle_seconds")) * float(_giorni)
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < fine:
		await process_frame
		_campiona()
	_referto()
	quit(0)


func _campiona() -> void:
	var res: Array = _vis.get("_residents")
	var animi: Dictionary = _vis.get("_animi")
	var ora := float(_dn.get("time"))
	var accesi := 0
	_campioni += 1
	for r in res:
		var lab := str(r.get("label", ""))
		var a = animi.get(lab)
		if a == null or a.limbico == null:
			continue
		var m := float((a.limbico.neuro as Dictionary).get("melatonina", 0.0))
		_mel[lab] = maxf(float(_mel.get(lab, 0.0)), m)
		var node := r.get("node") as Node3D
		# ⚠️ **UN CORPO NASCOSTO NON SI VEDE**, e vale piu' di ogni altra
		# valvola: dentro la finestra di sonno il corpo e' a scala 0.03.
		var in_scena: bool = node != null and node.has_method("is_hidden") \
				and not node.call("is_hidden")
		if m > SOGLIA and in_scena:
			accesi += 1
			_sopra[lab] = int(_sopra.get(lab, 0)) + 1
			# ⚠️ **E SI SEPARANO I DUE CASI**, o il numero mente. La rampa
			# dell'anticipo e' il caso NORMALE (sto per rientrare); ma chi e'
			# gia' DENTRO la finestra e ha ancora un corpo in scena non e' un
			# caso normale — e' qualcuno che non e' riuscito ad andare a
			# letto (porta chiusa, nessun letto), e la sua melatonina non si
			# ferma alla rampa: arriva al punto fisso pieno e ci resta tutta
			# la notte. Contarli insieme fa sembrare il canale piu' alto e
			# piu' lungo di quanto sia per chi va a dormire regolarmente.
			var dentro: bool = _dentro_finestra(r)
			if dentro:
				_fuori_casa[lab] = int(_fuori_casa.get(lab, 0)) + 1
				_mel_fuori[lab] = maxf(float(_mel_fuori.get(lab, 0.0)), m)
			else:
				_rampa[lab] = int(_rampa.get(lab, 0)) + 1
				_mel_rampa[lab] = maxf(float(_mel_rampa.get(lab, 0.0)), m)
			if not _accensione.has(lab):
				_accensione[lab] = ora
			if _cam != null and _vis.has_method("_nell_inquadratura") \
					and bool(_vis.call("_nell_inquadratura", node.global_position)):
				_visti[lab] = int(_visti.get(lab, 0)) + 1
		# l'adenosina della sera, per la domanda 4
		if ora > 0.70 and ora < 0.80:
			_adeno_sera.append(float((a.limbico.neuro as Dictionary)
					.get("adenosina", 0.0)))
	_isto[accesi] = int(_isto.get(accesi, 0)) + 1


func _referto() -> void:
	var dt := float(_dn.get("cycle_seconds")) / 240.0
	print("\n1. QUANTO ALTA, e per quanti secondi VISIBILI")
	var picchi: Array = []
	var righe := ""
	for lab in _mel:
		picchi.append(float(_mel[lab]))
		righe += "%s:%.3f/%ds " % [str(lab), float(_mel[lab]),
				int(_sopra.get(lab, 0))]
	print("   %s" % righe)
	print("   picco: %s" % _riass(picchi))
	var tot_sopra := 0
	var tot_visti := 0
	for lab2 in _sopra:
		tot_sopra += int(_sopra[lab2])
		tot_visti += int(_visti.get(lab2, 0))
	print("   campioni sopra %.2f con il corpo IN SCENA: %d su %d residenti-campione"
			% [SOGLIA, tot_sopra, _campioni * maxi(1, _mel.size())])

	var t_r := 0
	var t_f := 0
	for lab5 in _sopra:
		t_r += int(_rampa.get(lab5, 0))
		t_f += int(_fuori_casa.get(lab5, 0))
	print("\n1b. ⚠️ I DUE CASI, SEPARATI")
	print("   la RAMPA (sto per rientrare):   %6d campioni  picco %s"
			% [t_r, _riass(_mel_rampa.values())])
	print("   la NOTTE FUORI (non e' andato a letto): %6d campioni  picco %s"
			% [t_f, _riass(_mel_fuori.values())])
	if t_r + t_f > 0:
		print("   → la rampa e' il %.1f%% del tempo acceso"
				% [100.0 * float(t_r) / float(t_r + t_f)])
	print("   residenti con un letto raggiungibile: %d su %d"
			% [_con_letto(), (_vis.get("_residents") as Array).size()])

	print("\n2. QUANTI LA VEDONO — dentro l'inquadratura della camera vera")
	if tot_sopra == 0:
		print("   ⚠️ ARRESTO: il canale non e' MAI sopra soglia con un corpo in")
		print("      scena. Non c'e' niente da far leggere a nessun canale del")
		print("      rig: la consegna e' la sola correzione della sorgente.")
	else:
		print("   %d su %d (%.1f%%) dei campioni accesi erano inquadrati"
				% [tot_visti, tot_sopra, 100.0 * float(tot_visti) / float(tot_sopra)])

	print("\n3. ⚠️ LA SINCRONIA — IL CANCELLO D'ARRESTO")
	var chiavi: Array = _isto.keys()
	chiavi.sort()
	for k in chiavi:
		if int(k) == 0:
			continue
		print("   %2d corpi accesi insieme  %5.2f%%" % [int(k),
				100.0 * float(_isto[k]) / maxf(1.0, float(_campioni))])
	var quando: Array = []
	for lab3 in _accensione:
		quando.append(float(_accensione[lab3]))
	print("   istante di accensione (frazione di giornata): %s" % _riass(quando))
	var sp := _disp(quando)
	print("   → dispersione degli istanti: %.5f di giornata (%.1f s reali)"
			% [sp, sp * float(_dn.get("cycle_seconds"))])
	print("   Se e' quasi zero, il villaggio si spegne all'unisono: e' un")
	print("   carillon, e il corpo NON si fa.")

	print("\n4. LA DISPERSIONE DELL'ADENOSINA ALLA SERA (la cura proposta)")
	print("   %s" % _riass(_adeno_sera))
	print("   → dispersione: %.5f" % _disp(_adeno_sera))
	print("   Se e' quasi zero, tingere l'anticipo con la stanchezza non")
	print("   spezzerebbe la sincronia: quella cura non cura.")
	print("\n(dt di riferimento %.2f)" % dt)


func _riass(a: Array) -> String:
	if a.is_empty():
		return "(nessun campione)"
	var mn := 9e9
	var mx := -9e9
	var sm := 0.0
	for x in a:
		mn = minf(mn, float(x))
		mx = maxf(mx, float(x))
		sm += float(x)
	return "n=%d  media %.4f  min %.4f  max %.4f" % [a.size(),
			sm / float(a.size()), mn, mx]


func _disp(a: Array) -> float:
	if a.size() < 2:
		return 0.0
	var sm := 0.0
	for x in a:
		sm += float(x)
	var m := sm / float(a.size())
	var v := 0.0
	for x in a:
		v += pow(float(x) - m, 2.0)
	return sqrt(v / float(a.size() - 1))


func _con_letto() -> int:
	var n := 0
	for r in (_vis.get("_residents") as Array):
		if (r as Dictionary).has("cell"):
			n += 1
	return n
