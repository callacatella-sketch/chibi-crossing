extends Node3D

## UN VICINO NEL DIORAMA DEL MENÙ, e quello che sta facendo.
##
## Non è un `Visitor`: quello è un residente vero, con bisogni, cervello,
## animo e mezzo villaggio attaccato — nel menù sarebbe come accendere il
## motore per far girare l'autoradio. Questo è il suo corpo (lo stesso
## `ChibiBuilder`, lo stesso DNA salvato) e la sua ANDATURA (la stessa
## `Andatura` del gioco: camminano identici, e non è un caso — è che c'è
## una sola implementazione).
##
## Sopra ci va un MESTIERE: cosa sta facendo mentre tu guardi il menù.
## Nessun mestiere è un loop di due secondi: ognuno ha una durata, delle
## pause, un modo di finire, e qualcosa che non torna mai uguale.
##
## E i mestieri sanno del lutto. Nei giorni tristi non è che si muovono di
## meno: si muovono in un ALTRO modo — si siedono vicini, la coda ferma,
## le orecchie basse, e ogni tanto uno guarda in su.

const BUILDER := preload("res://scenes/npc/ChibiBuilder.gd")
const ANDATURA := preload("res://scenes/npc/Andatura.gd")
const FACE := preload("res://scenes/characters/FaceController.gd")

## I mestieri. Il diorama li distribuisce secondo il clima.
const MESTIERI := ["rincorre", "scappa", "seduto", "gioca", "altalena",
		"dorme", "saluta", "annusa", "veglia", "guarda_in_su"]

var mestiere := "seduto"
## Il centro attorno a cui si svolge il mestiere (l'albero, di solito).
var perno := Vector3.ZERO
## Il raggio della sua orbita attorno al perno.
var raggio := 2.0
## Chi insegue / da chi scappa: l'altro attore della coppia.
var compagno: Node3D
## Quanto è vivace il villaggio adesso (dal clima): scala le velocità.
var vivacita := 1.0
## Dove sta chi guarda. I mestieri fermi si girano più o meno da quella
## parte: un diorama di schiene è una fila alla cassa, non un villaggio —
## e le facce di queste creature sono metà del gioco. Non tutti la
## guardano dritta (sarebbe una foto di gruppo): ognuno ha il suo scarto.
var verso_camera := Vector3(6, 0, 10)
var scarto_sguardo := 0.0
## Da 0 (giovane) a 1 (anziano): gobba, orecchie stanche, passo posato.
var eta := 0.0

## Quanto dura ancora il mestiere di adesso. A zero se ne cerca un altro:
## è questo che fa evolvere la scena mentre la guardi, invece di lasciarla
## in loop. Chi resta sul menù un minuto vede finire una rincorsa, uno che
## si sveglia, uno che si alza e va all'altalena.
var _resta := 12.0
## Mentre una scenetta è in corso il mestiere non cambia: le interruzioni
## a metà gesto sono la cosa che fa sembrare finto un diorama.
var _in_scena := false

var _parti := {}
var _vis: Node3D
var _andatura: RefCounted
var _faccia
var _t := 0.0
var _fase := 0.0              # l'orologio del mestiere corrente
var _meta := Vector3.ZERO
var _yaw := 0.0
var _rng := RandomNumberGenerator.new()
var _sosta := 0.0
var _seduto_t := 0.0
var _altalena: Node3D         # il nodo dell'altalena, se ne ha una


func costruisci(dna: Dictionary, semina: int) -> void:
	_rng.seed = semina
	_parti = BUILDER.build(dna)
	_vis = Node3D.new()
	add_child(_vis)
	_vis.add_child(_parti["root"])
	_andatura = ANDATURA.new()
	_andatura.parti(_parti, _vis)
	_andatura.eta = eta
	# MUTI. Dodici passi che scricchiolano dietro un menù sono rumore, non
	# atmosfera: nel diorama l'andatura non suona (Andatura.sfx resta null).
	if _parti.has("face"):
		var rig: Dictionary = _parti["face"]
		rig["head"] = _parti["head"]
		_faccia = FACE.new()
		_faccia.setup(rig)
	_meta = global_position
	_fase = _rng.randf() * TAU
	_sosta = _rng.randf_range(0.0, 2.0)
	scarto_sguardo = _rng.randf_range(-0.85, 0.85)


## L'altalena dell'albero, per chi la usa.
func usa_altalena(nodo: Node3D) -> void:
	_altalena = nodo


## Cambia mestiere adesso, e decide da solo quanto durerà.
##
## Le durate non sono uguali per tutti né tonde: una rincorsa dura poco e
## finisce col fiato corto, un pisolino dura parecchio, una seduta sta in
## mezzo. E ognuno ha il suo scarto — se due vicini cambiassero mestiere
## nello stesso istante si vedrebbe la macchina dietro.
func cambia_mestiere(nuovo: String) -> void:
	mestiere = nuovo
	_fase = _rng.randf() * TAU
	_sosta = _rng.randf_range(0.0, 1.2)
	match nuovo:
		"rincorre", "scappa":
			_resta = _rng.randf_range(11.0, 22.0)
		"dorme":
			_resta = _rng.randf_range(26.0, 55.0)
		"altalena":
			_resta = _rng.randf_range(18.0, 40.0)
		"annusa", "gioca":
			_resta = _rng.randf_range(12.0, 26.0)
		"saluta":
			_resta = _rng.randf_range(6.0, 11.0)
		_:
			_resta = _rng.randf_range(14.0, 30.0)


## È ora di cambiare? (Lo chiede la regia del diorama, che sa quali
## mestieri sono ancora liberi e chi può accoppiarsi con chi.)
func vuole_cambiare() -> bool:
	return _resta <= 0.0 and not _in_scena


# ============================================================== le scenette

## Entra in una scenetta: da qui il mestiere non cambia più finché non
## finisce, e chi la dirige comanda dove andare e cosa guardare.
func entra_in_scena() -> void:
	_in_scena = true


func esci_di_scena() -> void:
	_in_scena = false
	_resta = _rng.randf_range(6.0, 14.0)


## Va incontro a qualcuno e gli si ferma davanti, a distanza di saluto.
## Torna true quando è arrivato.
func raggiungi(altro: Node3D, distanza := 0.95, delta := 0.0) -> bool:
	if altro == null or not is_instance_valid(altro):
		return true
	var d := altro.global_position - global_position
	d.y = 0.0
	if d.length() <= distanza:
		_guarda(altro.global_position, delta)
		return true
	_vai_verso(altro.global_position - d.normalized() * distanza, 1.15, delta)
	return false


## Si gira verso qualcuno e resta lì a guardarlo.
func rivolgiti(altro: Node3D, delta: float) -> void:
	if altro and is_instance_valid(altro):
		_guarda(altro.global_position, delta)
	_fa_seduta_in_piedi(delta)


## IL SALTELLO. Il gesto più corto del diorama e quello che fa più
## effetto: due decimi di secondo di contentezza, con l'overshoot della
## molla in salita e la discesa più lenta della salita.
func saltella(forza := 1.0) -> void:
	if _vis == null:
		return
	var tw := create_tween()
	tw.tween_property(_vis, "position:y", 0.16 * forza, 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_vis, "position:y", 0.0, 0.30) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if _faccia:
		_faccia.set_expression("gioia", 1.0)


## Dice qualcosa: una nuvoletta con dentro un glifo. Nel diorama il
## Chibiese non si SENTE (il menù ha la sua musica) — si vede.
func nuvoletta(glifo := "♪") -> void:
	if _parti.get("head") == null:
		return
	var bolla := Node3D.new()
	var sfondo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.34, 0.26)
	sfondo.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.98, 0.93, 0.94)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sfondo.material_override = mat
	bolla.add_child(sfondo)
	var lbl := Label3D.new()
	lbl.text = glifo
	lbl.font_size = 96
	lbl.pixel_size = 0.0022
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(0.45, 0.32, 0.28)
	lbl.render_priority = 2
	lbl.position = Vector3(0, 0, 0.01)
	bolla.add_child(lbl)
	add_child(bolla)
	bolla.global_position = (_parti["head"] as Node3D).global_position \
			+ Vector3(0.10, 0.30, 0)
	bolla.scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(bolla, "scale", Vector3.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.4)
	tw.tween_property(bolla, "scale", Vector3.ONE * 0.05, 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(bolla.queue_free)


## Segue con gli OCCHI qualcosa che passa (una farfalla, una stella): la
## testa si gira, il corpo no. È il gesto che dice «sono vivo» col minimo
## sforzo, ed è quello che il giocatore nota senza accorgersene.
func segui_con_lo_sguardo(punto: Vector3, delta: float) -> void:
	if _parti.get("head") == null:
		return
	var testa: Node3D = _parti["head"]
	var d := punto - testa.global_position
	if d.length() < 0.05:
		return
	var locale := global_transform.basis.inverse() * d
	var voluto_y := clampf(atan2(locale.x, locale.z), -1.1, 1.1)
	var voluto_x := clampf(-atan2(locale.y, Vector2(locale.x, locale.z).length()),
			-0.55, 0.35)
	testa.rotation.y = lerp_angle(testa.rotation.y, voluto_y, clampf(delta * 3.5, 0.0, 1.0))
	testa.rotation.x = lerpf(testa.rotation.x, voluto_x, clampf(delta * 3.5, 0.0, 1.0))
	if _faccia:
		_faccia.set_expression("curioso", 0.6)


## Come la seduta, ma in piedi: si posa senza piegare le gambe (serve
## nelle scenette, dove ci si parla stando su).
func _fa_seduta_in_piedi(delta: float) -> void:
	_seduto_t = maxf(0.0, _seduto_t - delta * 2.0)
	for gamba: Node3D in _parti.get("legs", []):
		gamba.rotation.x = lerpf(gamba.rotation.x, 0.0, delta * 5.0)
	_vis.rotation.x = lerpf(_vis.rotation.x, 0.0, delta * 5.0)


func _process(delta: float) -> void:
	_t += delta
	_fase += delta
	if not _in_scena:
		_resta -= delta
	match mestiere:
		"rincorre", "scappa":
			_fa_rincorsa(delta)
		"gioca":
			_fa_gioco(delta)
		"altalena":
			_fa_altalena(delta)
		"dorme":
			_fa_sonno(delta)
		"saluta":
			_fa_saluto(delta)
		"annusa":
			_fa_annusata(delta)
		"veglia":
			_fa_veglia(delta)
		"guarda_in_su":
			_fa_guarda_in_su(delta)
		_:
			_fa_seduta(delta)
	_andatura.eta = eta
	_andatura.misura(delta, global_position, _yaw)
	_andatura.applica()
	if _faccia:
		_faccia.update(delta)


# ============================================================== i mestieri

## LA RINCORSA. Due che si inseguono attorno all'albero — il mestiere che
## più di tutti dice «qui si vive».
##
## Non è un cerchio: chi scappa cambia raggio e verso, e chi insegue TAGLIA
## invece di seguire la scia (punta dove l'altro STARÀ, non dov'è). È la
## differenza fra due sagome su un binario e due che giocano davvero. E
## ogni tanto chi scappa si ferma di colpo e riparte dall'altra parte:
## quello è il momento in cui chi guarda sorride.
func _fa_rincorsa(delta: float) -> void:
	var velocita := (1.55 if mestiere == "scappa" else 1.72) * (0.55 + 0.45 * vivacita)
	if mestiere == "scappa":
		# la finta: ogni tanto inverte, e chi insegue ci casca
		if _sosta <= 0.0:
			_sosta = _rng.randf_range(2.6, 5.4)
			raggio = clampf(raggio + _rng.randf_range(-0.7, 0.7), 1.5, 3.6)
			velocita *= -1.0 if _rng.randf() < 0.35 else 1.0
		_sosta -= delta
		_fase += delta * velocita * 0.55
		_meta = perno + Vector3(cos(_fase) * raggio, 0, sin(_fase) * raggio)
	elif compagno and is_instance_valid(compagno):
		# TAGLIA la curva: punta dove sarà fra poco, non dov'è adesso
		var davanti: Vector3 = compagno.global_position
		var verso := (davanti - perno).normalized()
		var anticipo := verso.rotated(Vector3.UP, -0.55) * raggio
		_meta = perno + anticipo
	_vai_verso(_meta, velocita * 1.05, delta)


## IL GIOCO SOTTO L'ALBERO. Piccoli scatti fra due punti vicini, con delle
## pause in cui si guarda l'altro: non una corsa, un gioco.
func _fa_gioco(delta: float) -> void:
	_sosta -= delta
	if _sosta <= 0.0:
		_sosta = _rng.randf_range(1.1, 2.8)
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(0.6, 1.5)
		_meta = perno + Vector3(cos(a) * (raggio + d * 0.3), 0, sin(a) * (raggio + d * 0.3))
	_vai_verso(_meta, 1.25 * (0.5 + 0.5 * vivacita), delta)
	# il saltello di contentezza quando arriva
	if global_position.distance_to(_meta) < 0.35:
		_vis.position.y = maxf(_vis.position.y, absf(sin(_t * 7.0)) * 0.05 * vivacita)


## L'ALTALENA. Chi ci sta sopra ci sta DAVVERO: si muove con lei, e
## l'ampiezza cala e risale da sola invece di oscillare uguale per sempre.
func _fa_altalena(delta: float) -> void:
	if _altalena == null or not is_instance_valid(_altalena):
		mestiere = "seduto"
		return
	# due orologi incommensurabili: l'ampiezza non si richiude mai uguale
	var amp := (0.42 + 0.16 * sin(_t * 0.23) * cos(_t * 0.11)) * (0.4 + 0.6 * vivacita)
	var ang := sin(_t * 1.35) * amp
	_altalena.rotation.x = ang
	var drop: float = 0.0
	for c in _altalena.get_children():
		drop = maxf(drop, absf((c as Node3D).position.y))
	var seduta: Vector3 = _altalena.global_position \
			+ Vector3(0, -cos(ang) * drop, sin(ang) * drop)
	global_position = seduta + Vector3(0, 0.16, 0)
	_yaw = _altalena.global_rotation.y
	rotation.y = _yaw
	# il corpo segue l'oscillazione, la testa resta più indietro (inerzia)
	_vis.rotation.x = -ang * 0.55
	if _parti.has("head"):
		(_parti["head"] as Node3D).rotation.x = ang * 0.30
	for gamba: Node3D in _parti.get("legs", []):
		gamba.rotation.x = -1.1 + sin(_t * 1.35 + 0.7) * 0.25


## IL PISOLINO. Rannicchiato, con il respiro asimmetrico (l'inspiro più
## corto dell'espiro: un `sin()` puro si smaschera in due cicli).
func _fa_sonno(delta: float) -> void:
	_verso_chi_guarda(delta)
	_seduto_t = minf(_seduto_t + delta * 1.6, 1.0)
	var q := _seduto_t
	_vis.rotation.x = lerpf(_vis.rotation.x, 0.95, delta * 3.0)
	_vis.position.y = lerpf(_vis.position.y, -0.10, delta * 3.0)
	var respiro := sin(_t * 1.05)
	var soffio: float = (respiro * 0.38 if respiro > 0.0 else respiro * 0.62)
	if _parti.has("head"):
		var testa: Node3D = _parti["head"]
		testa.rotation.x = 0.42 * q + soffio * 0.035
		testa.rotation.z = 0.22 * q
	for ear: Node3D in _parti.get("ears", []):
		ear.rotation.x = 0.85 * q
	if _parti.get("tail"):
		(_parti["tail"] as Node3D).rotation.x = -0.9 * q
	for gamba: Node3D in _parti.get("legs", []):
		gamba.rotation.x = -1.3 * q


## IL SALUTO. Verso la camera: è l'unico momento in cui un vicino del
## diorama si accorge di chi sta dall'altra parte dello schermo. Raro, e
## per questo bello — un menù dove tutti salutano sempre è una vetrina.
func _fa_saluto(delta: float) -> void:
	_guarda(perno + Vector3(0, 0, 6.0), delta)
	_sosta -= delta
	if _sosta > 0.0:
		_fa_seduta(delta)
		return
	var t := fmod(_t, 6.5)
	if t < 1.5 and _parti.get("arms", []).size() == 2:
		var braccio: Node3D = _parti["arms"][0]
		braccio.rotation.z = -2.1
		braccio.rotation.x = sin(t * 11.0) * 0.45
		if _faccia:
			_faccia.set_expression("felice", 1.0)


## ANNUSARE UN FIORE. Si china, si ferma, e riparte. Il collo scende in
## fretta e risale piano: è la curva di chi sta assaporando qualcosa.
func _fa_annusata(delta: float) -> void:
	var t := fmod(_t + _fase, 7.0)
	var giu := 0.0
	if t < 1.0:
		giu = smoothstep(0.0, 1.0, t)
	elif t < 3.2:
		giu = 1.0
	elif t < 5.0:
		giu = 1.0 - smoothstep(0.0, 1.0, (t - 3.2) / 1.8)
	if _parti.has("head"):
		var testa: Node3D = _parti["head"]
		testa.rotation.x = lerpf(testa.rotation.x, 0.55 * giu, delta * 8.0)
	_vis.rotation.x = lerpf(_vis.rotation.x, 0.22 * giu, delta * 6.0)
	if giu > 0.6 and _faccia:
		_faccia.set_expression("beato", 0.8)


## LA VEGLIA. Il mestiere del lutto: seduti vicini, senza fare niente.
##
## Non è «l'animazione triste»: è l'ASSENZA delle altre. La coda non
## scodinzola, le orecchie stanno giù, il respiro è più lungo del solito,
## e ogni tanto — non a tempo — uno alza la testa e guarda in su, poi la
## riabbassa. In un menù dove di solito ci si rincorre, dodici secondi di
## questo dicono più di qualunque scritta.
func _fa_veglia(delta: float) -> void:
	_verso_chi_guarda(delta)
	_seduto_t = minf(_seduto_t + delta * 1.2, 1.0)
	var q := _seduto_t
	_vis.rotation.x = lerpf(_vis.rotation.x, 0.30, delta * 2.0)
	var respiro := sin(_t * 0.62)
	var soffio: float = (respiro * 0.35 if respiro > 0.0 else respiro * 0.65)
	if _parti.has("head"):
		var testa: Node3D = _parti["head"]
		# la testa bassa, e ogni tanto su: due orologi che non si
		# richiudono mai insieme, così non si vede il ciclo
		var su := maxf(0.0, sin(_t * 0.13) * cos(_t * 0.071 + 1.2))
		testa.rotation.x = lerpf(0.40 * q, -0.28, smoothstep(0.55, 0.95, su)) \
				+ soffio * 0.03
		testa.rotation.y = sin(_t * 0.19) * 0.10
	for ear: Node3D in _parti.get("ears", []):
		ear.rotation.x = lerpf(ear.rotation.x, 0.95 * q, delta * 2.0)
	if _parti.get("tail"):
		(_parti["tail"] as Node3D).rotation.y = 0.0
	if _parti.get("tail_tip"):
		(_parti["tail_tip"] as Node3D).rotation.y = 0.0
	for gamba: Node3D in _parti.get("legs", []):
		gamba.rotation.x = lerpf(gamba.rotation.x, -1.35 * q, delta * 2.5)
	if _faccia:
		_faccia.set_expression("triste", 0.55 + 0.2 * q)


## Chi guarda in alto — la sera del commiato, o quando c'è una stella.
func _fa_guarda_in_su(delta: float) -> void:
	_fa_seduta(delta)
	if _parti.has("head"):
		var testa: Node3D = _parti["head"]
		testa.rotation.x = lerpf(testa.rotation.x, -0.42, delta * 2.0)
	if _faccia:
		_faccia.set_expression("meraviglia", 0.7)


## SEDUTO A TERRA. La posa di riposo, e il fondo di quasi tutti gli altri
## mestieri: il corpo si posa, le gambe si piegano, il respiro va.
func _fa_seduta(delta: float) -> void:
	_verso_chi_guarda(delta)
	_seduto_t = minf(_seduto_t + delta * 1.5, 1.0)
	var q := _seduto_t
	_vis.position.y = lerpf(_vis.position.y, -0.06 * q, delta * 4.0)
	for gamba: Node3D in _parti.get("legs", []):
		gamba.rotation.x = lerpf(gamba.rotation.x, -1.30 * q, delta * 3.5)
	# il dondolio di chi sta seduto e non ha fretta
	_vis.rotation.z = sin(_t * 0.9 + _fase) * 0.03 * q


# ============================================================== il moto

## Va verso un punto camminando: gira il muso PRIMA di partire (chi
## cammina di sbieco sembra scivolare), e si ferma senza inchiodare.
func _vai_verso(dove: Vector3, velocita: float, delta: float) -> void:
	# alzarsi da seduti, se serve
	_seduto_t = maxf(0.0, _seduto_t - delta * 2.5)
	for gamba: Node3D in _parti.get("legs", []):
		gamba.rotation.x = lerpf(gamba.rotation.x, 0.0, delta * 6.0)
	_vis.rotation.x = lerpf(_vis.rotation.x, 0.0, delta * 6.0)

	var d := dove - global_position
	d.y = 0.0
	var dist := d.length()
	if dist < 0.06:
		return
	_guarda(dove, delta)
	# la velocità cala vicino alla meta: nessuno arriva a tutta e si ferma
	var v: float = velocita * clampf(dist / 0.6, 0.25, 1.0)
	global_position += d.normalized() * v * delta


## Si gira più o meno verso chi guarda, ognuno col suo scarto — e con una
## deriva lenta, così nessuno resta piantato sullo stesso angolo.
func _verso_chi_guarda(delta: float) -> void:
	var d := verso_camera - global_position
	d.y = 0.0
	if d.length() < 0.01:
		return
	var voluto := atan2(d.x, d.z) + scarto_sguardo + sin(_t * 0.17 + _fase) * 0.12
	_yaw = lerp_angle(_yaw, voluto, clampf(delta * 1.6, 0.0, 1.0))
	rotation.y = _yaw


func _guarda(dove: Vector3, delta: float) -> void:
	var d := dove - global_position
	d.y = 0.0
	if d.length() < 0.01:
		return
	var voluto := atan2(d.x, d.z)
	_yaw = lerp_angle(_yaw, voluto, clampf(delta * 6.0, 0.0, 1.0))
	rotation.y = _yaw
