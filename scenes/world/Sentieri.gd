class_name Sentieri
extends Node
## SENTIERI CONSUMATI — il mondo che ricorda i tuoi passi.
##
## Il tema del gioco è la memoria: anche il terreno deve ricordare. Ogni
## passo di Mochi e dei residenti lascia un'orma morbida in una tela fuori
## schermo (un SubViewport 2D che NON si cancella mai: accumula). Il manto
## del prato (ground.gdshader) legge quella tela come `sentieri_tex` e dove
## l'usura cresce prima spegne l'erba (calpestata), poi scopre la terra
## battuta: dopo settimane di andirivieni nascono da soli i sentierini
## verso lo stagno, il falò, la casa dell'amico del cuore.
##
## La memoria è VERA memoria: la tela si salva su disco (PNG in user://) a
## ogni cambio di giorno e periodicamente, e rinasce identica alla partita
## dopo. E come i ricordi, sbiadisce piano: a ogni nuovo giorno l'usura
## cala di un soffio — i sentieri percorsi ogni giorno restano, quelli
## abbandonati rinverdiscono in un paio di settimane.
##
## Efficienza: il viewport si ridisegna SOLO quando ci sono orme nuove
## (UPDATE_ONCE), mai a vuoto. Con nessuno in giro il costo è zero.
##
## Contratto con ground.gdshader: `sentieri_tex` + `sentieri_origin` +
## `sentieri_size` (lo stesso patto di tuft_map). Un test fa la guardia.

## L'area di mondo coperta dalla tela (XZ). Copre il villaggio intero:
## prato, stagno, radura del falò, le case — con un margine di passeggio.
const AREA := Rect2(-22.0, -26.0, 44.0, 44.0)
const RISOLUZIONE := 512

## Il passo: sotto questa soglia non è camminare (respiro, idle) e non
## lascia orme; sopra TELETRASPORTO è uno spawn/routine, non un tragitto.
const PASSO_MIN := 0.14
const TELETRASPORTO := 3.0
## Distanza fra due orme lungo un tragitto veloce: senza, chi corre
## lascerebbe una fila di puntini staccati invece di una pesta continua.
const INTERPASSO := 0.18

const RAGGIO_ORMA := 0.34          # raggio dell'orma nel mondo (unità)
const PESO_MOCHI := 0.030          # quanto scava un passo di Mochi
const PESO_RESIDENTE := 0.020      # i chibi pesano meno (zampette!)
const GUARIGIONE_GIORNO := 0.055   # sbiadimento a ogni nuovo giorno
const QUOTA_TERRA := 1.5           # sopra quest'altezza non si calpesta il prato

const FILE_MEMORIA := "user://sentieri_consumati.png"
const INTERVALLO_CAMPIONE := 0.22  # ogni quanto si campionano i passi (s)
const INTERVALLO_SALVA := 180.0    # autosalvataggio della tela (s)
const INTERVALLO_CENSIMENTO := 4.0 # ogni quanto si ricontano i camminatori

var _vp: SubViewport
var _strato_init: Node2D    # fondo nero + memoria caricata (blend normale)
var _strato_orme: Node2D    # le orme del giro (blend ADD: accumula)
var _strato_alba: Node2D    # lo sbiadimento del nuovo giorno (blend SUB)

# un camminatore: {"node": Node3D, "ultimo": Vector3|null, "peso": float}
var _camminatori: Array = []
var _orme: Array = []       # orme da dipingere al prossimo flush: [Vector2 px, peso]
var _init_da_fare := true
var _alba_da_fare := 0.0
var _sporca := false        # la tela ha orme non ancora salvate

var _t_campione := 0.0
var _t_censimento := 0.0
var _t_salva := 0.0

var _pennello: GradientTexture2D


func _ready() -> void:
	add_to_group("sentieri")
	_pennello = _fai_pennello()
	_fai_tela()
	_collega_terreno()
	# il nuovo giorno sbiadisce i sentieri dimenticati
	var daynight := get_node_or_null("../../DayNight")
	if daynight and daynight.has_signal("day_changed"):
		daynight.day_changed.connect(_nuovo_giorno)
	# i primi camminatori
	_censimento()


# ------------------------------------------------------------ la tela

func _fai_tela() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(RISOLUZIONE, RISOLUZIONE)
	_vp.disable_3d = true
	_vp.transparent_bg = false
	# la tela NON si cancella mai: è la memoria. Si dipinge solo quando
	# c'è qualcosa di nuovo (UPDATE_ONCE al flush, mai a vuoto).
	_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)

	# tre strati nell'ordine di pittura: fondo/memoria, orme (+), alba (-).
	# A OGNI flush tutti e tre ridisegnano (anche vuoto): un CanvasItem non
	# ridisegnato rieseguirebbe i comandi vecchi — il fondo nero, ridipinto
	# per sbaglio, CANCELLEREBBE la memoria.
	_strato_init = Node2D.new()
	_strato_init.draw.connect(_disegna_init)
	_vp.add_child(_strato_init)

	_strato_orme = Node2D.new()
	var madd := CanvasItemMaterial.new()
	madd.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_strato_orme.material = madd
	_strato_orme.draw.connect(_disegna_orme)
	_vp.add_child(_strato_orme)

	_strato_alba = Node2D.new()
	var msub := CanvasItemMaterial.new()
	msub.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
	_strato_alba.material = msub
	_strato_alba.draw.connect(_disegna_alba)
	_vp.add_child(_strato_alba)

	# il primo flush: fondo nero + la memoria salvata, se c'è
	_flush()


func _fai_pennello() -> GradientTexture2D:
	# un'orma morbida: piena al centro, svanisce al bordo
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	return tex


func _collega_terreno() -> void:
	var floor_mi := get_node_or_null("../../Floor/MeshInstance3D") as MeshInstance3D
	if floor_mi == null:
		return
	var gmat := floor_mi.get_surface_override_material(0) as ShaderMaterial
	if gmat == null:
		return
	gmat.set_shader_parameter("sentieri_tex", _vp.get_texture())
	gmat.set_shader_parameter("sentieri_origin", AREA.position)
	gmat.set_shader_parameter("sentieri_size", AREA.size)


## Un giro di pittura: tutti gli strati ridisegnano, il viewport renderizza
## UNA volta e poi torna a dormire.
func _flush() -> void:
	_strato_init.queue_redraw()
	_strato_orme.queue_redraw()
	_strato_alba.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _disegna_init() -> void:
	if not _init_da_fare:
		return
	_init_da_fare = false
	# il fondo nero esplicito: senza, il primo clear userebbe il colore di
	# sfondo del progetto (crema) = mondo interamente consumato
	_strato_init.draw_rect(Rect2(0, 0, RISOLUZIONE, RISOLUZIONE), Color.BLACK)
	# la memoria della partita scorsa, se esiste
	if FileAccess.file_exists(FILE_MEMORIA):
		var img := Image.load_from_file(FILE_MEMORIA)
		if img != null and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			_strato_init.draw_texture_rect(tex,
					Rect2(0, 0, RISOLUZIONE, RISOLUZIONE), false)


func _disegna_orme() -> void:
	if _orme.is_empty():
		return
	var r := RAGGIO_ORMA / AREA.size.x * float(RISOLUZIONE)
	for orma in _orme:
		var px: Vector2 = orma[0]
		var peso: float = orma[1]
		_strato_orme.draw_texture_rect(_pennello,
				Rect2(px - Vector2(r, r), Vector2(r * 2.0, r * 2.0)),
				false, Color(1, 1, 1, peso))
	_orme.clear()
	_sporca = true


func _disegna_alba() -> void:
	if _alba_da_fare <= 0.0:
		return
	var d := _alba_da_fare
	_alba_da_fare = 0.0
	_strato_alba.draw_rect(Rect2(0, 0, RISOLUZIONE, RISOLUZIONE),
			Color(d, d, d, 1.0))
	_sporca = true


# ------------------------------------------------------------ i passi

func _process(delta: float) -> void:
	_t_censimento -= delta
	if _t_censimento <= 0.0:
		_t_censimento = INTERVALLO_CENSIMENTO
		_censimento()

	_t_campione += delta
	if _t_campione >= INTERVALLO_CAMPIONE:
		_t_campione = 0.0
		_campiona()

	_t_salva += delta
	if _t_salva >= INTERVALLO_SALVA:
		_t_salva = 0.0
		salva()


## Chi cammina nel villaggio: Mochi (il Player) e i residenti/visitatori
## (figli Node3D del gestionale Visitors). Altri sistemi possono aggiungere
## i propri camminatori con registra().
func _censimento() -> void:
	var vivi: Array = []
	var gia := {}
	for w in _camminatori:
		var n = w["node"]
		if is_instance_valid(n) and (n as Node3D).is_inside_tree():
			vivi.append(w)
			gia[n.get_instance_id()] = true
	var player := get_node_or_null("../../Player") as Node3D
	if player and not gia.has(player.get_instance_id()):
		vivi.append({"node": player, "ultimo": null, "peso": PESO_MOCHI})
	var visitors := get_node_or_null("../../Visitors")
	if visitors:
		for c in visitors.get_children():
			var n3 := c as Node3D
			if n3 and not gia.has(n3.get_instance_id()):
				vivi.append({"node": n3, "ultimo": null, "peso": PESO_RESIDENTE})
	_camminatori = vivi


## Aggiunge un camminatore esterno (l'amico co-op, un cucciolo futuro…).
func registra(node: Node3D, peso := PESO_RESIDENTE) -> void:
	for w in _camminatori:
		if w["node"] == node:
			return
	_camminatori.append({"node": node, "ultimo": null, "peso": peso})


func _campiona() -> void:
	var nuove := false
	for w in _camminatori:
		var n = w["node"]
		if not is_instance_valid(n) or not (n as Node3D).is_inside_tree():
			continue
		var pos: Vector3 = (n as Node3D).global_position
		if pos.y > QUOTA_TERRA:
			continue                      # in alto (piani, scale): non è prato
		var ultimo = w["ultimo"]
		w["ultimo"] = pos
		if ultimo == null:
			continue
		for passo in passi_fra(ultimo, pos):
			var px := px_di(passo)
			if px.x >= 0.0:
				_orme.append([px, w["peso"]])
				nuove = true
	if nuove:
		_flush()


# ------------------------------------------------ la matematica dei passi
# Pura e statica: testabile headless, dove il viewport non renderizza.

## Da mondo (XZ) a UV della tela [0..1]; fuori area → componenti < 0.
static func uv_di(p: Vector3) -> Vector2:
	var uv := Vector2((p.x - AREA.position.x) / AREA.size.x,
			(p.z - AREA.position.y) / AREA.size.y)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return Vector2(-1.0, -1.0)
	return uv


## Da mondo a pixel della tela; fuori area → (-1,-1).
static func px_di(p: Vector3) -> Vector2:
	var uv := uv_di(p)
	if uv.x < 0.0:
		return Vector2(-1.0, -1.0)
	return uv * float(RISOLUZIONE)


## Le orme lungo un tragitto: niente sotto PASSO_MIN (idle), niente oltre
## TELETRASPORTO (spawn/routine), altrimenti punti equidistanti ≤ INTERPASSO
## così anche una corsa lascia una pesta continua.
static func passi_fra(da: Vector3, a: Vector3) -> Array:
	var d := Vector2(a.x - da.x, a.z - da.z).length()
	if d < PASSO_MIN or d > TELETRASPORTO:
		return []
	var n := int(ceil(d / INTERPASSO))
	var out := []
	for i in n:
		out.append(da.lerp(a, float(i + 1) / float(n)))
	return out


# ------------------------------------------------------------ la memoria

func _nuovo_giorno(_day: int) -> void:
	# i sentieri dimenticati rinverdiscono un soffio per giorno; quelli
	# vissuti ogni giorno si rimarginano subito coi passi nuovi
	_alba_da_fare = GUARIGIONE_GIORNO
	_flush()
	# e la memoria si mette al sicuro
	salva.call_deferred()


## Scrive la tela su disco. È la memoria a lungo termine del terreno:
## alla prossima partita i sentieri sono ancora lì.
func salva() -> void:
	if not _sporca or _vp == null:
		return
	# headless (test): il renderer dummy leggerebbe una tela nera e
	# CANCELLEREBBE la memoria vera del giocatore. Mai salvare da lì.
	if DisplayServer.get_name() == "headless":
		return
	var img := _vp.get_texture().get_image()
	if img == null or img.is_empty():
		return
	img.convert(Image.FORMAT_L8)
	if img.save_png(FILE_MEMORIA) == OK:
		_sporca = false


func _exit_tree() -> void:
	salva()
