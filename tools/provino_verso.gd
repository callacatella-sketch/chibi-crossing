extends SceneTree
## IL CANCELLO DEL VERSO — un gesto che si NOTA e non si LEGGE non entra.
##
##   CHIBI_VERSO=/dove/le/foto ~/Downloads/Godot.app/Contents/MacOS/Godot \
##     --path . --resolution 1280x720 --script res://tools/provino_verso.gd
##
## ────────────────────────────────────────────────────────────────────────
## LA CORREZIONE CHE VALE PIÙ DI OGNI GESTO
## ────────────────────────────────────────────────────────────────────────
##
## «Pixel di contorno cambiati» — il conteggio XOR di un gesto contro il
## corpo a riposo — misura la **RILEVABILITÀ**: è successo qualcosa. Non
## misura la **LEGGIBILITÀ**: è successo *di là*. E sono due cose diverse:
## la ricevuta di oggi (la testa che si gira di 44°) cambia 886 px di
## spalle, e i due versi opposti differiscono di 919 — **rapporto 1,04**.
## Vedi le orecchie muoversi e non sai da che parte.
##
##     rilevabilità = |maschera(+A) XOR maschera(riposo)|
##     leggibilità  = |maschera(+A) XOR maschera(−A)|
##     IL CRITERIO  = leggibilità / rilevabilità  ≥  1,6
##
## Sotto 1,6 il gesto non porta il proprio significato su quel canale, e
## **non entra**: si nota, si dimentica, e insegna al giocatore che i vicini
## si muovono a caso.
##
## ────────────────────────────────────────────────────────────────────────
## COME SI MISURA, E PERCHÉ COSÌ
## ────────────────────────────────────────────────────────────────────────
##
##  · **I pixel si contano dal FOTOGRAMMA RENDERIZZATO**, contro una lastra
##    di fondo scattata col corpo invisibile. Non da una funzione del gesto:
##    chiedere al gesto quanti pixel ha cambiato è chiedere al giudice se è
##    d'accordo con sé stesso.
##  · **Lo scrittore è quello VERO** (`Visitor.debug_posa` → `_recita_applica`):
##    un provino che si disegna la posa da sé misura il proprio disegnatore.
##  · **La camera è quella del gioco**, incollata a Mochi: quello che il
##    giocatore vede di un vicino a sei metri *è* quello. Una macchina messa
##    a un metro dal muso risponderebbe a una domanda che nessuno si fa.
##  · **Quattro azimut**, perché di spalle un vicino si guarda il 49,6% delle
##    volte — ed è l'inquadratura in cui l'imbardata muore.
##  · **`−A` non è un gesto del gioco**: è la controprova. Il Raccolto si
##    allunga invece di comprimersi, il Capo pende dall'altra parte.
##
## ⚠️ **IL PUNTO NON È IN QUESTA TABELLA, ed è la ragione per cui esiste.**
## Il suo segnale non è una posa: è un **contrasto di MOTO**. Un corpo a
## velocità di crociera cambia 222–980 px per fotogramma, fermo ne cambia
## 14–25 — 8,9:1 di fronte, 54:1 di profilo, 11:1 di spalle. Quella misura la
## fa la seconda parte di questo provino, che conta i pixel FRA DUE
## FOTOGRAMMI CONSECUTIVI invece che fra due pose.

const VS := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")
const GESTI := preload("res://scenes/npc/Gesti.gd")

const DISTANZE := [6.0, 9.0, 17.0]
## fronte / tre quarti / profilo / spalle, in gradi di imbardata del corpo
## rispetto alla camera (che guarda lungo −Z verso il vicino).
const VISTE := [["fronte", 180.0], ["trequarti", 135.0], ["profilo", 90.0],
		["spalle", 0.0]]
const SEME := 7331
## Quanto deve differire un pixel dal fondo per contare come «corpo».
const SOGLIA := 24
## Il criterio unico.
const SOGLIA_VERSO := 1.6

var _dove := ""
var _player: Node3D = null
var _v: Node3D = null
var _righe := {}
var _ordine := []


func _init() -> void:
	_go()


func _cam() -> Camera3D:
	return get_root().get_camera_3d()


# ------------------------------------------------------------- le sonde
#
# Ogni sonda è una COPPIA: il gesto al suo istante più pieno, e la sua
# controprova. I canali escono da `Gesti` — cioè dalle buste vere, non da
# numeri riscritti qui — e la controprova nega le deviazioni.

## Nega le deviazioni di un dizionario di canali: `r` e `sy` sono
## MOLTIPLICATORI (riposo = 1), tutti gli altri sono somme (riposo = 0).
static func _contro(c: Dictionary) -> Dictionary:
	var out := c.duplicate()
	for k in out:
		if k == "r" or k == "sy":
			out[k] = 2.0 - float(out[k])
		else:
			out[k] = -float(out[k])
	return out


## Un canale solo, al suo valore di lavoro. Serve a sapere quanto vale IL
## CANALE, che è un'altra domanda da «quanto vale il gesto»: un gesto porta
## anche canali di accento (le orecchie, le braccia, la coda) che aggiungono
## rilevabilità e quasi nessun verso — e diluiscono il rapporto. Se un gesto
## sta sotto e il suo canale portante sta sopra, la cura non è ingrandire il
## gesto: è togliergli un accento.
static func _solo(canale: String, valore: float) -> Dictionary:
	var c := GESTI.riposo()
	c[canale] = valore
	return c


func _sonde() -> Array:
	var out := []
	# --- i CANALI, isolati ---
	out.append(["· scala −10%", _solo("sy", 0.90)])
	out.append(["· verticale +5,5 cm", _solo("vy", 0.055)])
	out.append(["· rollio capo 8°", _solo("hz", 0.14)])
	out.append(["· laterale 9 cm", _solo("px", 0.09)])
	out.append(["· orecchie 0,55", _solo("ear", 0.55)])
	out.append(["· braccia 0,30", _solo("ax0", 0.30)])
	# --- i GESTI, interi ---
	# IL RACCOLTO al colmo della tenuta (2,6 s: attacco finito, rilascio
	# non ancora cominciato).
	out.append(["RACCOLTO (scala −10%)", GESTI.bersagli("raccolto", 2.6, {}, 1.0)])
	# IL RIALZO, due istanti: il PICCO (0,12 s) e la TENUTA (0,8 s). Il
	# picco è un istante, la tenuta è la notizia — e a nove metri, dove
	# l'istante è già passato quando l'occhio arriva, si legge la seconda.
	out.append(["RIALZO picco (vy+5,5cm)", GESTI.bersagli("rialzo", 0.12, {}, 1.0)])
	out.append(["RIALZO tenuta (scala+1,5%)", GESTI.bersagli("rialzo", 0.8, {}, 1.0)])
	# IL CAPO CHE PENDE, al colmo del trasferimento.
	var capo := GESTI.riposo()
	capo["hz"] = GESTI.CAPO_AMP_MAX
	out.append(["CAPO rollio %.0f°" % rad_to_deg(GESTI.CAPO_AMP_MAX), capo])
	# --- LA DIAGNOSI: lo stesso Raccolto con un accento SPENTO per volta.
	# È l'unico modo di sapere QUALE canale sta coprendo la parola, invece di
	# ritoccarli tutti e sperare.
	for spento: String in ["ear", "vx", "hx", "ax0", "hpy"]:
		var d: Dictionary = GESTI.bersagli("raccolto", 2.6, {}, 1.0)
		d[spento] = 1.0 if spento == "sy" else 0.0
		if spento == "ear":
			d["ear_dx"] = 0.0
		if spento == "ax0":
			d["ax1"] = 0.0
		out.append(["  RACCOLTO senza «%s»" % spento, d])
	# IL LARGO al colmo dello scostamento.
	out.append(["LARGO (laterale 9cm)", GESTI.bersagli("largo", 1.6, {"via": 1.0}, 1.0)])
	# E LA RICEVUTA DI OGGI, come metro di paragone: è il gesto che il gioco
	# ha già, ed è la ragione per cui questo documento esiste.
	var testa := GESTI.riposo()
	testa["hy"] = 0.775
	out.append(["(oggi) testa girata 44°", testa])
	return out


# --------------------------------------------------------- il conteggio

func _mesh(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_mesh(c, out)


## Il rettangolo dello schermo che contiene tutto il corpo, con margine: si
## conta lì dentro e non su tutto il fotogramma, o l'erba che ondeggia
## sarebbe metà del segnale.
func _bbox() -> Rect2:
	var radice := _v.get("_corpo") as Node3D
	var mm := []
	_mesh(radice, mm)
	var r := Rect2()
	var primo := true
	for m in mm:
		var mi: MeshInstance3D = m
		var ab := mi.get_aabb()
		var xf := mi.global_transform
		for i in 8:
			var q: Vector3 = xf * (ab.position + Vector3(
					ab.size.x * float(i & 1), ab.size.y * float((i >> 1) & 1),
					ab.size.z * float((i >> 2) & 1)))
			if _cam().is_position_behind(q):
				continue
			var s := _cam().unproject_position(q)
			if primo:
				r = Rect2(s, Vector2.ZERO)
				primo = false
			else:
				r = r.expand(s)
	return r


func _leggi(rr: Rect2i) -> PackedByteArray:
	for _i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img.get_region(rr.intersection(Rect2i(Vector2i.ZERO, img.get_size()))) \
			.get_data()


## UN fotogramma, il prossimo. Serve alla misura del moto, dove due campioni
## consecutivi devono essere due FOTOGRAMMI consecutivi: con la lettura
## «stabile» (due `process_frame` più due `frame_post_draw`) in mezzo ne
## passano cinque, e «px per fotogramma» diventerebbe «px per cinque».
func _leggi1(rr: Rect2i) -> PackedByteArray:
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img.get_region(rr.intersection(Rect2i(Vector2i.ZERO, img.get_size()))) \
			.get_data()


func _maschera(cur: PackedByteArray, bg: PackedByteArray, soglia := SOGLIA) -> PackedByteArray:
	var n := cur.size() / 3
	var m := PackedByteArray()
	m.resize(n)
	for i in n:
		var j := i * 3
		var d := absi(int(cur[j]) - int(bg[j])) \
				+ absi(int(cur[j + 1]) - int(bg[j + 1])) \
				+ absi(int(cur[j + 2]) - int(bg[j + 2]))
		m[i] = 1 if d > soglia else 0
	return m


func _xor(a: PackedByteArray, b: PackedByteArray) -> int:
	var n := mini(a.size(), b.size())
	var c := 0
	for i in n:
		if a[i] != b[i]:
			c += 1
	return c


func _scatta(nome: String) -> void:
	if _dove == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_jpg(_dove.rstrip("/") + "/" + nome + ".jpg", 0.92)


# ------------------------------------------------------------------ scena

func _go() -> void:
	_dove = OS.get_environment("CHIBI_VERSO")
	if _dove != "":
		DirAccess.make_dir_recursive_absolute(_dove)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 10:
		await process_frame
	var liv := current_scene
	_player = liv.get_node_or_null("Player") as Node3D
	var visitors := liv.get_node_or_null("Visitors")
	var build := liv.get_node_or_null("BuildSystem")
	var dn := liv.get_node_or_null("DayNight")
	if _player == null or visitors == null:
		print("GUASTO: manca qualcosa nel MainLevel")
		quit(1)
		return
	if build != null:
		build.call("set_persist_for_debug", false)
	# L'OROLOGIO SI FERMA: la luce non deve cambiare fra una variante e
	# l'altra, o si sta confrontando l'ora invece del gesto.
	if dn != null:
		dn.set("cycle_seconds", 1000000.0)
		dn.set("time", 0.42)
	await create_timer(1.5).timeout

	_v = VS.new()
	_v.set("species", "chibi")
	_v.set("dna", DNAG.generate(SEME))
	visitors.add_child(_v)
	_v.set("greet_enabled", false)
	await create_timer(1.2).timeout
	_v.call("_enter_state", "r_idle")
	_v.set("_timer", 999999.0)
	_v.global_position = Vector3.ZERO
	await create_timer(0.8).timeout

	# CHIBI_PARTI sceglie le sezioni: "1" il cancello · "2" la scala delle
	# ampiezze · "3" il moto. Una tornata intera sono venti minuti, e quando
	# si sta tarando UN numero non si rifanno le altre due.
	var parti := OS.get_environment("CHIBI_PARTI")
	if parti == "":
		parti = "123"
	if parti.contains("1"):
		await _il_verso()
	if parti.contains("2"):
		await _le_ampiezze()
	if parti.contains("3"):
		await _il_moto()
	quit(0)


# =========================================================================
# 1) IL VERSO — la lente che decide chi entra
# =========================================================================

func _il_verso() -> void:
	# il corpo si ferma: le pose si confrontano ferme, o si sta misurando il
	# respiro insieme al gesto
	_v.set_process(false)
	Engine.time_scale = 0.0
	for _i in 4:
		await process_frame

	var radice := _v.get("_corpo") as Node3D
	var colonne := []
	for vista in VISTE:
		for dv in DISTANZE:
			var col := "%s@%dm" % [str(vista[0]), int(dv)]
			colonne.append(col)
			_v.global_position = Vector3.ZERO
			_player.global_position = Vector3(0.0, _player.global_position.y,
					float(dv))
			_v.set("_yaw", deg_to_rad(float(vista[1])))
			_v.rotation.y = deg_to_rad(float(vista[1]))
			for _i in 3:
				await process_frame
			var r := _bbox().grow(140.0)
			var rr := Rect2i(Vector2i(floori(r.position.x), floori(r.position.y)),
					Vector2i(ceili(r.size.x), ceili(r.size.y)))
			radice.visible = false
			var bg := await _leggi(rr)
			radice.visible = true
			_v.call("debug_posa", GESTI.riposo())
			_v.force_update_transform()
			var m_base := _maschera(await _leggi(rr), bg)
			for s in _sonde():
				var nome: String = s[0]
				var can: Dictionary = s[1]
				_v.call("debug_posa", can)
				_v.force_update_transform()
				var m_piu := _maschera(await _leggi(rr), bg)
				if _dove != "" and int(dv) == 6:
					await _scatta("verso_%s_%s_piu" % [str(vista[0]),
							nome.left(12).replace(" ", "_")])
				_v.call("debug_posa", _contro(can))
				_v.force_update_transform()
				var m_meno := _maschera(await _leggi(rr), bg)
				if _dove != "" and int(dv) == 6:
					await _scatta("verso_%s_%s_meno" % [str(vista[0]),
							nome.left(12).replace(" ", "_")])
				var rilev := (_xor(m_base, m_piu) + _xor(m_base, m_meno)) / 2
				var legg := _xor(m_piu, m_meno)
				if not _righe.has(nome):
					_righe[nome] = {}
					_ordine.append(nome)
				_righe[nome][col] = [rilev, legg]
			_v.call("debug_posa", GESTI.riposo())
			print("  fatto %s" % col)

	Engine.time_scale = 1.0
	_v.set_process(true)

	print("")
	print("█".repeat(100))
	print("IL CANCELLO DEL VERSO — rilevabilità px / leggibilità px")
	print("█".repeat(100))
	var intest := "sonda".rpad(30)
	for c in colonne:
		intest += str(c).lpad(16)
	print(intest)
	print("-".repeat(intest.length()))
	for nome in _ordine:
		var riga := str(nome).rpad(30)
		for c in colonne:
			var v: Array = _righe[nome][c]
			riga += ("%d/%d" % [int(v[0]), int(v[1])]).lpad(16)
		print(riga)
	print("")
	print("IL CRITERIO: leggibilità / rilevabilità — passa a ≥ %.1f" % SOGLIA_VERSO)
	print("-".repeat(intest.length()))
	for nome in _ordine:
		var riga := str(nome).rpad(30)
		var peggio := 99.0
		for c in colonne:
			var v: Array = _righe[nome][c]
			var q := float(v[1]) / maxf(1.0, float(v[0]))
			peggio = minf(peggio, q)
			riga += ("%.2f" % q).lpad(16)
		print(riga + ("   PASSA" if peggio >= SOGLIA_VERSO else "   ← SOTTO"))


# =========================================================================
# 2) IL MOTO — la misura del PUNTO, che non è una posa
# =========================================================================

## Quanti pixel della SAGOMA cambiano fra due fotogrammi consecutivi:
## camminando, e fermo. È l'unico numero che dice qualcosa sul Punto — il suo
## segnale non è una forma, è l'assenza improvvisa di movimento — e nessuna
## posa del vocabolario si avvicina al rapporto che ne esce.
##
## ⚠️ **SI CONTA LA MASCHERA, NON IL FOTOGRAMMA, e la prima stesura di questa
## misura sbagliava proprio qui.** Confrontando due fotogrammi crudi si conta
## anche l'erba che ondeggia, l'acqua e le foglie: il fondo dava QUINDICIMILA
## px per fotogramma e il rapporto fra corpo in moto e corpo fermo usciva
## 1,3:1 invece di 8,9:1 — cioè la misura diceva «il fermo non si vede», che
## è l'esatto contrario del vero. La maschera (fotogramma meno lastra di
## fondo, sopra soglia) toglie di mezzo tutto ciò che non è il corpo, e il
## PAVIMENTO DI RUMORE si stampa in fondo: senza, non si sa se il numero
## piccolo è un corpo fermo o è il fondo.
func _il_moto() -> void:
	print("")
	print("█".repeat(100))
	print("IL MOTO — px della SAGOMA cambiati fra due fotogrammi")
	print("█".repeat(100))
	print("  (è la misura del PUNTO, che non ha una posa da confrontare:")
	print("   il suo segnale è il CONTRASTO fra il corpo che va e il corpo che sta)")
	print("")
	var riga := "vista".rpad(24) + "cammina".lpad(12) + "fermo".lpad(12) \
			+ "rapporto".lpad(16) + "(fondo)".lpad(12)
	print("  i due numeri sono AL NETTO del pavimento di rumore del renderer")
	print("")
	print(riga)
	print("-".repeat(riga.length()))
	# IL MONDO SI FERMA. Con l'erba che ondeggia, il pavimento di rumore
	# misurava DODICIMILA px per fotogramma — quanto il corpo intero — e il
	# rapporto usciva 1,3:1 invece di 8,9:1: la misura diceva «il fermo non
	# si vede», cioè l'esatto contrario del vero.
	var meteo := current_scene.get_node_or_null("Weather")
	if meteo != null:
		meteo.set_process(false)
	RenderingServer.global_shader_parameter_set("vento_forza", 0.0)
	# …E L'ANTIALIASING SI SPEGNE. È il secondo pavimento, e più subdolo del
	# vento: TAA e FXAA fanno ballare OGNI pixel di bordo a ogni fotogramma,
	# e il bordo di un chibi a sei metri sono qualche centinaio di pixel —
	# cioè lo stesso ordine di grandezza del segnale che si cerca. Con l'AA
	# acceso il pavimento restava a 1300 px e il corpo fermo «cambiava» tanto
	# quanto il corpo che cammina.
	var vp := get_root()
	var taa_prima := vp.use_taa
	var ssaa_prima := vp.screen_space_aa
	var msaa_prima := vp.msaa_3d
	vp.use_taa = false
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.msaa_3d = Viewport.MSAA_DISABLED
	# …E LA SOGLIA SI SCEGLIE, non si indovina. Il terzo pavimento è il
	# renderer stesso: Forward+ dà via dithering e accumuli temporali circa
	# l'1% di pixel che ballano ovunque, corpo o non corpo. Si stampa il
	# pavimento accanto al segnale a QUATTRO soglie, così si vede dove il
	# corpo emerge e il fondo sparisce, invece di fidarsi di un numero.
	var soglie := [60, 120, 200, 300]
	var soglia := 120
	if OS.get_environment("CHIBI_SOGLIA") != "":
		soglie = [int(OS.get_environment("CHIBI_SOGLIA"))]
		soglia = soglie[0]
	var radice := _v.get("_corpo") as Node3D
	for vista in VISTE:
		_player.global_position = Vector3(0.0, _player.global_position.y, 6.0)
		var yaw := deg_to_rad(float(vista[1]))
		var muso := Vector3(-sin(yaw), 0.0, -cos(yaw))
		_v.call("_enter_state", "r_idle")
		_v.set("_timer", 999999.0)
		_v.set("_yaw", yaw)
		_v.rotation.y = yaw
		_v.global_position = Vector3.ZERO
		await create_timer(0.6).timeout
		# ⚠️ il riquadro è LARGO apposta: chi cammina di traverso alla camera
		# esce da un riquadro stretto in due decimi di secondo, e la prima
		# stesura misurava zero pixel di moto per «profilo» e «trequarti» —
		# cioè dichiarava che un corpo che cammina non si vede.
		var r := _bbox().grow(90.0)
		var rr := Rect2i(Vector2i(floori(r.position.x), floori(r.position.y)),
				Vector2i(ceili(r.size.x), ceili(r.size.y)))
		# la lastra di fondo, e il PAVIMENTO DI RUMORE (a ogni soglia)
		radice.visible = false
		var bg := await _leggi(rr)
		var fondo := {}
		var crudi := []
		for _i in 9:
			crudi.append(await _leggi1(rr))
		for s: int in soglie:
			var tot := 0
			for i in range(1, crudi.size()):
				tot += _xor(_maschera(crudi[i], bg, s), _maschera(crudi[i - 1], bg, s))
			fondo[s] = tot / 8
		radice.visible = true
		# FERMO: il corpo dov'è, col suo `_process` acceso — respira, si
		# assesta, le orecchie vivono. Non è un fermo immagine.
		await create_timer(0.4).timeout
		crudi.clear()
		for _i in 9:
			crudi.append(await _leggi1(rr))
		var fermo := {}
		for s: int in soglie:
			var tot := 0
			for i in range(1, crudi.size()):
				tot += _xor(_maschera(crudi[i], bg, s), _maschera(crudi[i - 1], bg, s))
			fermo[s] = tot / 8
		# IN CAMMINO: cammina DAVVERO, con la sua andatura, verso un punto
		# lontano lungo il proprio muso — non lo si trascina a mano, o si
		# misurerebbe una traslazione invece di un passo.
		_v.global_position = -muso * 0.30
		_v.call("_walk_to", muso * 60.0, "r_idle")
		await create_timer(0.20).timeout
		crudi.clear()
		for _i in 9:
			crudi.append(await _leggi1(rr))
		var camm := {}
		for s: int in soglie:
			var tot := 0
			for i in range(1, crudi.size()):
				tot += _xor(_maschera(crudi[i], bg, s), _maschera(crudi[i - 1], bg, s))
			camm[s] = tot / 8
		for s: int in soglie:
			var a: int = maxi(0, int(camm[s]) - int(fondo[s]))
			var b: int = maxi(0, int(fermo[s]) - int(fondo[s]))
			print(("%s (soglia %d)" % [str(vista[0]), s]).rpad(24)
					+ str(a).lpad(12) + str(b).lpad(12)
					+ (("%.1f:1" % (float(a) / float(b))) if b > 0
							else "sotto il fondo").lpad(16)
					+ str(fondo[s]).lpad(12))
	if meteo != null:
		meteo.set_process(true)
	vp.use_taa = taa_prima
	vp.screen_space_aa = ssaa_prima
	vp.msaa_3d = msaa_prima


# =========================================================================
# 3) LA SCALA DELLE AMPIEZZE — quanto verso dà OGNI canale, a ogni taglia
# =========================================================================
#
# Il rapporto non è una proprietà del canale: è una proprietà del canale A
# QUELLA AMPIEZZA. Due regioni spazzate da una rotazione si sovrappongono
# tanto più quanto l'angolo è piccolo — ed è per questo che un rollio da 8°
# sta sotto la soglia a sei metri e la passa a diciassette, dove il corpo è
# più piccolo e i due estremi non si toccano più.
#
# Questa tabella è quella che decide le ampiezze del vocabolario. Senza,
# «0,10 rad» sarebbe un numero indovinato e sperato.
const SCALE := {
	"hz": [0.08, 0.11, 0.14, 0.18, 0.24],
	"ear": [0.20, 0.30, 0.40, 0.55, 0.75],
	"sy": [0.95, 0.92, 0.90, 0.87, 0.84],
	"vy": [0.025, 0.04, 0.055, 0.075, 0.10],
	"px": [0.05, 0.07, 0.09, 0.12, 0.16],
	"vx": [0.05, 0.08, 0.10, 0.13, 0.18],
	"hx": [0.05, 0.08, 0.12, 0.18, 0.25],
	"vz": [0.02, 0.03, 0.05, 0.08, 0.12],
	"tail": [0.10, 0.20, 0.30, 0.45, 0.65],
}


func _le_ampiezze() -> void:
	print("")
	print("█".repeat(100))
	print("LA SCALA DELLE AMPIEZZE — il verso di ogni canale, taglia per taglia")
	print("█".repeat(100))
	print("  (rilevabilità px / verso · il verso PASSA a ≥ %.1f)" % SOGLIA_VERSO)
	_v.set_process(false)
	Engine.time_scale = 0.0
	for _i in 4:
		await process_frame
	var radice := _v.get("_corpo") as Node3D
	for canale in SCALE:
		print("")
		var intest := ("canale «%s»" % canale).rpad(22)
		for vista in VISTE:
			intest += str(vista[0]).lpad(19)
		print(intest)
		print("-".repeat(intest.length()))
		for amp: float in SCALE[canale]:
			var riga := ("  %.3f" % amp).rpad(22)
			for vista in VISTE:
				_v.global_position = Vector3.ZERO
				_player.global_position = Vector3(0.0, _player.global_position.y, 6.0)
				_v.set("_yaw", deg_to_rad(float(vista[1])))
				_v.rotation.y = deg_to_rad(float(vista[1]))
				for _i in 3:
					await process_frame
				var r := _bbox().grow(140.0)
				var rr := Rect2i(Vector2i(floori(r.position.x), floori(r.position.y)),
						Vector2i(ceili(r.size.x), ceili(r.size.y)))
				radice.visible = false
				var bg := await _leggi(rr)
				radice.visible = true
				_v.call("debug_posa", GESTI.riposo())
				_v.force_update_transform()
				var m_base := _maschera(await _leggi(rr), bg)
				var can := _solo(canale, amp)
				_v.call("debug_posa", can)
				_v.force_update_transform()
				var m_piu := _maschera(await _leggi(rr), bg)
				_v.call("debug_posa", _contro(can))
				_v.force_update_transform()
				var m_meno := _maschera(await _leggi(rr), bg)
				var rilev := (_xor(m_base, m_piu) + _xor(m_base, m_meno)) / 2
				var legg := _xor(m_piu, m_meno)
				var q := float(legg) / maxf(1.0, float(rilev))
				riga += ("%d · %.2f%s" % [rilev, q, "" if q >= SOGLIA_VERSO else "←"]).lpad(19)
			print(riga)
	_v.call("debug_posa", GESTI.riposo())
	Engine.time_scale = 1.0
	_v.set_process(true)
