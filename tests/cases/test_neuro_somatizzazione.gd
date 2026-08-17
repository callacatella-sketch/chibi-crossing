extends RefCounted
## Test della somatizzazione procedurale dei neurotrasmettitori per:
## 1. FaceController.gd (corrugatore, dilatazione pupillare, blush, inclinazione sopracciglia, saccadi/focus)
## 2. Andatura.gd (altezza rimbalzo hop, inclinazione busto, scodinzolio e ritardo punta coda)

const FACE := "res://scenes/characters/FaceController.gd"
const ANDATURA := "res://scenes/npc/Andatura.gd"


func run(t) -> void:
	var fc_script: GDScript = load(FACE)
	t.ok(fc_script != null and fc_script.can_instantiate(), "FaceController.gd compila")
	var and_script: GDScript = load(ANDATURA)
	t.ok(and_script != null and and_script.can_instantiate(), "Andatura.gd compila")
	if fc_script == null or and_script == null:
		return

	_test_face_neuro_corrugatore_e_pupilla(t, fc_script)
	_test_face_neuro_ossitocina_blush(t, fc_script)
	_test_face_neuro_serotonina_sopracciglia(t, fc_script)
	_test_face_neuro_dopamina_sguardo(t, fc_script)
	_test_face_api_limbico(t, fc_script)

	_test_andatura_hop_dopamina_adenosina(t, and_script)
	_test_andatura_postura_busto(t, and_script)
	_test_andatura_scodinzolio_serotonina(t, and_script)
	_test_andatura_api_limbico(t, and_script)


	_il_corpo_indossa_la_chimica_IN_PARTITA(t)
	_a_chimica_NEUTRA_il_volto_e_quello_di_sempre(t, fc_script)
# --- Helper rig sintetico per FaceController ---
func _build_rig(t, fc: GDScript) -> Dictionary:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2a1d1d")
	var head := t.stage(Node3D.new()) as Node3D

	var eyes: Array[Node3D] = []
	var eyeballs: Array[MeshInstance3D] = []
	var irises: Array[Node3D] = []
	var happy: Array[Node3D] = []
	var brows: Array[Node3D] = []
	var blush: Array[MeshInstance3D] = []
	for side: float in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(side * 0.155, 0.03, -0.355)
		head.add_child(eye)
		var ball := MeshInstance3D.new()
		ball.mesh = SphereMesh.new()
		ball.material_override = mat
		ball.scale = Vector3(1, 1.18, 0.55)
		eye.add_child(ball)
		eyeballs.append(ball)
		var iris := Node3D.new()
		var shine := MeshInstance3D.new()
		shine.mesh = SphereMesh.new()
		iris.add_child(shine)
		eye.add_child(iris)
		irises.append(iris)
		eyes.append(eye)
		happy.append(fc.build_happy_arc(head, mat, Vector3(side * 0.155, 0.03, -0.36), side))
		brows.append(fc.build_brow(head, mat, side, Vector3(side * 0.15, 0.16, -0.36)))
		var bl := MeshInstance3D.new()
		bl.mesh = SphereMesh.new()
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(1, 0.6, 0.7, 0.6)
		bl.material_override = bm
		head.add_child(bl)
		blush.append(bl)

	var mouths: Dictionary = fc.build_mouth_set(head, mat, Vector3(0, -0.1, -0.408))
	var mouth_open: Node3D = fc.build_mouth_open(head, mat, Vector3(0, -0.1, -0.408))

	return {
		"head": head, "eyes": eyes, "eyeballs": eyeballs, "irises": irises,
		"happy": happy, "brows": brows, "blush": blush,
		"mouths": mouths, "mouth_open": mouth_open,
		"eye_base_scale": Vector3(1, 1.18, 0.55), "face_side": 0.36,
	}


func _test_face_neuro_corrugatore_e_pupilla(t, fc: GDScript) -> void:
	var rig := _build_rig(t, fc)
	var face = fc.new()
	face.setup(rig)
	face.set_expression("neutro", 1.0)

	# Baseline: cortisolo = 0.0
	for f in 30:
		face.update(0.016)
	var base_sq: float = face._c_brow_sq
	var base_pupil: float = face._c_pupil
	t.almost(base_sq, 0.0, "a riposo il corrugatore è rilassato", 0.01)
	t.almost(base_pupil, 1.0, "a riposo la pupilla è neutra", 0.02)

	# Alto cortisolo: allarme/stress acuto
	face.cortisolo = 1.0
	for f in 40:
		face.update(0.016)
	t.ok(face._c_brow_sq > base_sq + 0.03,
			"alto cortisolo: il corrugatore si contrae verso il centro (%.4f > %.4f)"
			% [face._c_brow_sq, base_sq])
	t.ok(face._c_pupil < base_pupil - 0.15,
			"alto cortisolo: la pupilla si restringe per allarme/stress (%.3f < %.3f)"
			% [face._c_pupil, base_pupil])

	# Reset
	face.reset_neuro()
	for f in 40:
		face.update(0.016)
	t.almost(face._c_brow_sq, 0.0, "il reset ripristina il corrugatore", 0.01)


func _test_face_neuro_ossitocina_blush(t, fc: GDScript) -> void:
	var rig := _build_rig(t, fc)
	var face = fc.new()
	face.setup(rig)
	face.set_expression("neutro", 1.0)

	for f in 30:
		face.update(0.016)
	var base_blush: float = face._c_blush
	var base_pupil: float = face._c_pupil

	# Alta ossitocina (calore sociale / affetto / bonding)
	face.ossitocina = 1.0
	for f in 40:
		face.update(0.016)

	t.ok(face._c_blush > base_blush + 0.25,
			"alta ossitocina: blush passivo caldo sulle guance (%.3f > %.3f)"
			% [face._c_blush, base_blush])
	t.ok(face._c_pupil > base_pupil + 0.12,
			"alta ossitocina: dilatazione pupillare da empatia/affetto (%.3f > %.3f)"
			% [face._c_pupil, base_pupil])


func _test_face_neuro_serotonina_sopracciglia(t, fc: GDScript) -> void:
	var rig := _build_rig(t, fc)
	var face = fc.new()
	face.setup(rig)
	face.set_expression("neutro", 1.0)

	# Bassa serotonina = depressione / malinconia / tono basso
	face.serotonina = 0.0
	for f in 50:
		face.update(0.016)
	var ang_bassa: float = face._c_brow_ang
	t.ok(ang_bassa < -0.025,
			"bassa serotonina: inclinazione malinconica a V rovesciata (%.4f < -0.025)"
			% ang_bassa)

	# Alta serotonina = serenità e fiducia
	face.serotonina = 1.0
	for f in 50:
		face.update(0.016)
	var ang_alta: float = face._c_brow_ang
	t.ok(ang_alta > ang_bassa + 0.05,
			"alta serotonina: sguardo sereno e aperto (%.4f > %.4f)"
			% [ang_alta, ang_bassa])


func _test_face_neuro_dopamina_sguardo(t, fc: GDScript) -> void:
	var rig := _build_rig(t, fc)
	var face = fc.new()
	face.setup(rig)
	var target := t.stage(Node3D.new()) as Node3D
	target.position = Vector3(0.5, 0.2, -1.5)
	face.look_at_node(target)

	# Alta dopamina: focus tenace, dilatazione pupillare
	face.dopamina = 1.0
	for f in 40:
		face.update(0.016)
	t.ok(face._c_pupil > 1.05,
			"alta dopamina: dilatazione pupillare da attenzione/ricompensa (%.3f > 1.05)"
			% face._c_pupil)

	# Verifica che lo sguardo insegua senza salti infiniti o NaN
	t.ok(not face._gaze_cur.is_zero_approx(), "lo sguardo è agganciato al bersaglio")
	t.ok(absf(face._gaze_cur.x) <= 1.0 and absf(face._gaze_cur.y) <= 1.0,
			"lo sguardo resta nei limiti anatomici normalizzati")


func _test_face_api_limbico(t, fc: GDScript) -> void:
	var rig := _build_rig(t, fc)
	var face = fc.new()
	face.setup(rig)

	# Dizionario con chiavi italiane e inglesi
	face.set_neuro({"dopamine": 0.8, "serotonin": 0.2, "oxytocin": 0.7, "cortisol": 0.9})
	t.almost(face.dopamina, 0.8, "set_neuro imposta dopamine", 0.001)
	t.almost(face.serotonina, 0.2, "set_neuro imposta serotonin", 0.001)
	t.almost(face.ossitocina, 0.7, "set_neuro imposta oxytocin", 0.001)
	t.almost(face.cortisolo, 0.9, "set_neuro imposta cortisol", 0.001)

	# ⚠️ **E UN LIVELLO NON PUO' PIU' PRENDERSI IL CANALE DI UN ALTRO.**
	# C'era un ramo di «compatibilita'» che faceva `cortisolo = arousal` e
	# `serotonina = 0.5 + 0.5·umore`, e il test provava QUELLO — cioe' la
	# strada che nessuno avrebbe percorso, mentre `set_from_limbico`, che
	# porta il nome del caso, non aveva ne' test ne' chiamanti.
	var prima_cort: float = face.cortisolo
	face.set_neuro({"arousal": 0.65, "umore": -0.5})
	t.almost(face.cortisolo, prima_cort,
			"un livello (arousal) non scrive piu' un canale (cortisolo)", 0.001)

	# …e la strada VERA: i sette canali, presi da un Limbico vero.
	var lim = preload("res://scenes/npc/Limbico.gd").new()
	lim.setup({"codardia": 0.5, "grinta": 0.5, "ambizione": 0.5, "lealta": 0.5})
	lim.neuro["cortisolo"] = 0.77
	lim.neuro["ossitocina"] = 0.66
	face.set_from_limbico(lim)
	t.almost(face.cortisolo, 0.77, "set_from_limbico porta il cortisolo VERO", 0.001)
	t.almost(face.ossitocina, 0.66, "…e l'ossitocina vera", 0.001)


# --- Test Andatura ---
func _build_andatura(t, and_script: GDScript):
	var a = and_script.new()
	var vis := t.stage(Node3D.new()) as Node3D
	var testa := Node3D.new()
	var braccia: Array[Node3D] = [Node3D.new(), Node3D.new()]
	var gambe: Array[Node3D] = [Node3D.new(), Node3D.new()]
	var orecchie: Array[Node3D] = [Node3D.new(), Node3D.new()]
	var coda := Node3D.new()
	var coda_punta := Node3D.new()
	vis.add_child(testa)
	for b in braccia: vis.add_child(b)
	for g in gambe: vis.add_child(g)
	for o in orecchie: vis.add_child(o)
	vis.add_child(coda)
	coda.add_child(coda_punta)

	a.parti({
		"head": testa, "arms": braccia, "legs": gambe,
		"ears": orecchie, "tail": coda, "tail_tip": coda_punta
	}, vis)
	return a


func _test_andatura_hop_dopamina_adenosina(t, and_script: GDScript) -> void:
	# Andatura A: alta dopamina, riposato (adenosina = 0)
	var a_dopa = _build_andatura(t, and_script)
	a_dopa.dopamina = 1.0
	a_dopa.adenosina = 0.0

	# Andatura B: bassa dopamina, esausto (adenosina = 1.0)
	var a_fatica = _build_andatura(t, and_script)
	a_fatica.dopamina = 0.0
	a_fatica.adenosina = 1.0

	var max_hop_dopa := -INF
	var max_hop_fatica := -INF

	for f in 60:
		var pos := Vector3(float(f) * 0.025, 0, 0)
		a_dopa.misura(0.016, pos, 0.0)
		a_dopa.applica()
		max_hop_dopa = maxf(max_hop_dopa, a_dopa.vis.position.y)

		a_fatica.misura(0.016, pos, 0.0)
		a_fatica.applica()
		max_hop_fatica = maxf(max_hop_fatica, a_fatica.vis.position.y)

	t.ok(max_hop_dopa > max_hop_fatica * 1.8,
			"la dopamina aumenta il rimbalzo rispetto alla fatica/adenosina (%.4f > %.4f)"
			% [max_hop_dopa, max_hop_fatica])


func _test_andatura_postura_busto(t, and_script: GDScript) -> void:
	# Andatura con alto stress/depressione (alto cortisolo, bassa serotonina)
	var a_curva = _build_andatura(t, and_script)
	a_curva.cortisolo = 1.0
	a_curva.serotonina = 0.0

	# Andatura fiera/serena (basso cortisolo, alta serotonina)
	var a_fiera = _build_andatura(t, and_script)
	a_fiera.cortisolo = 0.0
	a_fiera.serotonina = 1.0

	for f in 40:
		var pos := Vector3(float(f) * 0.02, 0, 0)
		a_curva.misura(0.016, pos, 0.0)
		a_curva.applica()
		a_fiera.misura(0.016, pos, 0.0)
		a_fiera.applica()

	t.ok(a_curva.vis.rotation.x < a_fiera.vis.rotation.x - 0.25,
			"alto cortisolo e bassa serotonina curvano il busto in avanti (%.3f vs %.3f rad)"
			% [a_curva.vis.rotation.x, a_fiera.vis.rotation.x])


func _test_andatura_scodinzolio_serotonina(t, and_script: GDScript) -> void:
	# Alta serotonina: scodinzolio vivace e ampio, coda sollevata
	var a_alta = _build_andatura(t, and_script)
	a_alta.serotonina = 1.0

	# Bassa serotonina: scodinzolio spento e coda abbassata
	var a_bassa = _build_andatura(t, and_script)
	a_bassa.serotonina = 0.0

	var max_wag_alta := -INF
	var max_wag_bassa := -INF

	for f in 80:
		var pos := Vector3(float(f) * 0.02, 0, 0)
		a_alta.misura(0.016, pos, 0.0)
		a_alta.applica()
		max_wag_alta = maxf(max_wag_alta, absf(a_alta.coda.rotation.y))

		a_bassa.misura(0.016, pos, 0.0)
		a_bassa.applica()
		max_wag_bassa = maxf(max_wag_bassa, absf(a_bassa.coda.rotation.y))

	t.ok(max_wag_alta > max_wag_bassa * 1.5,
			"alta serotonina: scodinzolio più ampio (%.3f > %.3f)"
			% [max_wag_alta, max_wag_bassa])
	t.ok(a_alta.coda.rotation.x > a_bassa.coda.rotation.x + 0.15,
			"alta serotonina: coda più alta e fiera (%.3f > %.3f)"
			% [a_alta.coda.rotation.x, a_bassa.coda.rotation.x])


func _test_andatura_api_limbico(t, and_script: GDScript) -> void:
	var a = _build_andatura(t, and_script)
	# la regolazione NON e' la stanchezza: non deve toccare l'adenosina
	a.set_neuro({"adenosina": 0.10})
	a.set_neuro({"regolazione": 0.0})
	t.almost(a.adenosina, 0.10,
			"la regolazione non si travestre da fatica: chi si trattiene non "
			+ "cammina come un esausto", 0.001)
	a.set_neuro({"dopamine": 0.9, "serotonin": 0.8, "fatica": 0.4, "cortisol": 0.3})
	t.almost(a.dopamina, 0.9, "set_neuro imposta dopamina", 0.001)
	t.almost(a.serotonina, 0.8, "set_neuro imposta serotonina", 0.001)
	t.almost(a.adenosina, 0.4, "set_neuro imposta fatica/adenosina", 0.001)
	t.almost(a.cortisolo, 0.3, "set_neuro imposta cortisolo", 0.001)

	a.reset_neuro()
	t.almost(a.dopamina, 0.5, "reset ripristina dopamina a 0.5", 0.001)
	t.almost(a.serotonina, 0.5, "reset ripristina serotonina a 0.5", 0.001)
	t.almost(a.adenosina, 0.0, "reset ripristina adenosina a 0.0", 0.001)
	t.almost(a.cortisolo, 0.0, "reset ripristina cortisolo a 0.0", 0.001)


## ⚠️ **IL CABLAGGIO ESISTE — ed e' l'unica guardia che conta di questo file.**
##
## Tutto il resto qui dentro prova l'API: si chiama `set_neuro` a mano e si
## guarda il rig. Ma la prima stesura di questo sistema aveva l'API perfetta,
## i test verdi, e **nessun chiamante in tutto il gioco**: 247 righe di
## somatizzazione che non toccavano un pixel. MISURATO allora, sessanta
## secondi di cammino su dieci canali del rig: il corpo usciva
## **bit-identico** a quello di prima (scarto 0.0000000000).
##
## Questo caso fa girare la funzione VERA di `Visitors` — quella che il gioco
## chiama a ogni fotogramma — e guarda se la chimica arriva al corpo. Se
## qualcuno toglie la riga del cablaggio, qui diventa rosso; e se qualcuno
## rifa' il sistema senza collegarlo, non passa affatto.
func _il_corpo_indossa_la_chimica_IN_PARTITA(t) -> void:
	for vecchio in t.tree().get_nodes_in_group("visitors"):
		(vecchio as Node).remove_from_group("visitors")
	var casa := Node3D.new()
	casa.name = "VillaggioNeuro"
	t.stage(casa)
	var giorno := FintoGiornoNeuro.new()
	giorno.name = "DayNight"
	casa.add_child(giorno)
	var vis = RegistroNeuro.new()
	vis.name = "Visitors"
	casa.add_child(vis)
	vis.set("_daynight", giorno)

	var v = preload("res://scenes/npc/Visitor.gd").new()
	v.species = "chibi"
	v.mode = "resident"
	v.dna = preload("res://scenes/npc/ChibiDNA.gd").generate(4242)
	t.stage(v)
	v.set_process(false)
	vis._residents.append({"node": v, "label": "N0", "dna": v.dna,
			"cell": Vector2i(0, 0), "species": "chibi", "next_act": 0.0,
			"phase": "day"})
	vis._ensure_ecs()
	# ⚠️ **L'ANIMO SI PRENDE DA `Visitors`, non se ne fabbrica uno.**
	# `_ensure_brain` ne crea uno suo dal genoma e SOVRASCRIVE `_animi[key]`:
	# un animo di banco messo li' prima viene buttato, e il caso misurerebbe
	# un oggetto che il gioco non guarda. (Costato una corsa: il rig restava
	# a 0.108 — la baseline del carattere — qualunque cosa gli si scrivesse.)
	vis._ensure_brain(vis._residents[0])
	var animo = (vis.get("_animi") as Dictionary)["N0"]

	# l'andatura si aggancia al corpo la prima volta che serve: la si chiede
	# con la funzione VERA, non costruendone una di banco
	v.call("_andatura_pronta")
	# PREMESSA: il corpo ha un'andatura da vestire
	var and_rig = v.get("_andatura")
	t.ok(and_rig != null, "PREMESSA: il corpo ha un rig dell'andatura")
	if and_rig == null:
		return

	animo.limbico.neuro["cortisolo"] = 0.05
	vis._ciclo_sonno(1.0 / 60.0, 0.5)
	var basso: float = float(and_rig.get("cortisolo"))
	animo.limbico.neuro["cortisolo"] = 0.95
	vis._ciclo_sonno(1.0 / 60.0, 0.5)
	var alto: float = float(and_rig.get("cortisolo"))
	t.ok(alto > basso + 0.5,
			("il ciclo VERO di Visitors porta la chimica sul corpo: %.3f -> %.3f "
			+ "(se restano uguali, la somatizzazione e' di nuovo codice morto)")
					% [basso, alto])


class FintoGiornoNeuro extends Node3D:
	var day := 3
	var time := 0.5
	var cycle_seconds := 240.0

	func parametri_ambientali() -> Dictionary:
		return {"temperatura": 20.0, "luce": 1.0, "pioggia": 0.0, "ora": time}


class RegistroNeuro extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		add_to_group("visitors")


## ⚠️ **A CHIMICA NEUTRA IL VOLTO DEV'ESSERE QUELLO DI SEMPRE.**
##
## Il canale neurochimico del sopracciglio aveva infilato un filtro in serie
## con la molla del rig (la molla inseguiva `_c_brow_ang`, cioe' il bersaglio
## gia' passato per un `lerp`, invece del bersaglio). MISURATO **a chimica
## neutra**, cioe' su ogni partita di chiunque: al sesto fotogramma il
## sopracciglio stava a 0.0222 dove prima stava a 0.0564, con uno scarto
## massimo di 0,0384 rad — il 43% della sua ampiezza — su Mochi e su ogni
## chibi, a ogni cambio di espressione.
##
## Il metro non e' un numero scelto: e' il volto SENZA neurochimica. Due
## facce identiche, la stessa espressione, gli stessi fotogrammi, e a una
## sola si passa la chimica di riposo: devono restare **la stessa faccia**.
func _a_chimica_NEUTRA_il_volto_e_quello_di_sempre(t, fc: GDScript) -> void:
	var rig_a := _build_rig(t, fc)
	var rig_b := _build_rig(t, fc)
	var senza = fc.new()
	var con = fc.new()
	senza.setup(rig_a)
	con.setup(rig_b)
	# la chimica di RIPOSO: quella che ha un corpo a cui non e' successo niente
	con.set_neuro({"dopamina": 0.5, "serotonina": 0.5, "ossitocina": 0.0,
			"cortisolo": 0.0, "adenosina": 0.0})
	senza.set_expression("felice")
	con.set_expression("felice")
	var peggio := 0.0
	for f in 40:
		senza.update(1.0 / 60.0)
		con.update(1.0 / 60.0)
		peggio = maxf(peggio, absf(float(rig_a["brows"][0].rotation.z)
				- float(rig_b["brows"][0].rotation.z)))
	t.ok(peggio < 0.002,
			("a chimica di riposo il sopracciglio e' quello di sempre "
			+ "(scarto peggiore %.5f rad su trenta fotogrammi)") % peggio)

	# ⚠️ **RESIDUO DICHIARATO: la molla del sopracciglio NON ha una guardia.**
	#
	# Il canale neurochimico aveva infilato un filtro in serie con la molla
	# del rig (inseguiva `_c_brow_ang`, cioe' il bersaglio gia' passato per
	# un `lerp`, invece del bersaglio): un ritardo che nessuno aveva chiesto,
	# e **anche a chimica neutra** — misurato altrove, 0,0384 rad al nono
	# fotogramma, il 43% dell'ampiezza, su Mochi e su ogni chibi a ogni
	# cambio di espressione. La riga e' stata corretta.
	#
	# Ma la correzione non e' sorvegliata da qui, e va detto invece che
	# lasciato credere: ho provato due guardie — lo scarto fra due facce e il
	# tempo di salita — e la mutazione le lascia VERDI tutte e due. La
	# ragione e' del banco: in questo rig finto `brows[0].rotation.z` arriva
	# al suo valore finale al PRIMO fotogramma, cioe' non passa affatto per
	# la molla, e il canale che il difetto rallenta (`_brow_ang_cur`) qui non
	# muove niente. Un'asserzione che passa in tutti e due i casi non e' una
	# guardia: e' un'asserzione che dice «coperto» senza esserlo.
	#
	# Chi la vorra' chiudere deve prima costruire un rig in cui il
	# sopracciglio si muova DAVVERO attraverso `_apply_rig`, e poi misurare
	# il tempo di salita — che dipende solo dalle due costanti della molla
	# (150 e 14), quindi e' un numero che non e' suo.
