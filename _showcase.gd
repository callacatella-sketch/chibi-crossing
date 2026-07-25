extends Node

## Vetrina: renderizza VitalHUD dentro un SubViewport di dimensione esatta, per
## card pulite e ritagliate (per la verifica visiva). File usa-e-getta.

const VITAL := preload("res://scenes/ui/VitalHUD.gd")
const OUT := "/private/tmp/claude-501/-Users-duck-Developer-chibi-crossing/8092c0d1-dac0-4eb7-81bc-bc203b5ff925/scratchpad"

var _sv: SubViewport
var _v


func _ready() -> void:
	get_window().size = Vector2i(200, 120)
	_sv = SubViewport.new()
	_sv.size = Vector2i(700, 510)
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sv)

	var bg := ColorRect.new()
	bg.color = Color("6f8f6a")
	bg.size = Vector2(700, 510)
	_sv.add_child(bg)

	_v = VITAL.new()
	_v.size = Vector2(700, 510)
	_v.scale = Vector2(2.7, 2.7)
	_sv.add_child(_v)

	# 1) sereno -> quieto (i valori partono pieni: nessun "pop")
	_set([[0, 1.0, 0], [1, 1.0, 0], [2, 1.0, 0]])
	await _shoot("showcase_sereno", 2.9)
	# 2) multi: acqua critica, fame bassa, energia critica
	_set([[0, 0.10, 2], [1, 0.28, 1], [2, 0.07, 2]])
	await _shoot("showcase_critico", 1.5)
	# 3) refill: l'acqua torna piena -> festa
	_v.update_need(0, 1.0, 0)
	await _shoot("showcase_refill", 0.4)
	get_tree().quit()


func _set(list: Array) -> void:
	for e in list:
		_v.update_need(e[0], e[1], e[2])


func _shoot(fname: String, wait_s: float) -> void:
	await get_tree().create_timer(wait_s).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_sv.get_texture().get_image().save_png(OUT.path_join(fname + ".png"))
