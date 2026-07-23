extends CanvasLayer

@onready var water_bar = %WaterBar
@onready var hunger_bar = %HungerBar
@onready var stamina_bar = %StaminaBar

# Chiamata quando il Player viene istanziato, per collegare i segnali
func connect_survival_component(survival_comp: Node):
    if not survival_comp:
        return
        
    # Applica i colori pastello base tramite StyleBoxFlat in GDScript o nell'editor (qui lo facciamo in GDScript per comodità del prototipo)
    _setup_pastel_colors()
    
    survival_comp.connect("water_changed", Callable(self, "_on_water_changed"))
    survival_comp.connect("hunger_changed", Callable(self, "_on_hunger_changed"))
    survival_comp.connect("stamina_changed", Callable(self, "_on_stamina_changed"))
    
    # Inizializza le barre ai valori attuali
    water_bar.max_value = survival_comp.get_max_water()
    water_bar.value = survival_comp.get_water()
    
    hunger_bar.max_value = survival_comp.get_max_hunger()
    hunger_bar.value = survival_comp.get_hunger()
    
    stamina_bar.max_value = survival_comp.get_max_stamina()
    stamina_bar.value = survival_comp.get_stamina()

func _setup_pastel_colors():
    _apply_bar_color(water_bar, Color("A2D2FF"))   # Azzurro pastello
    _apply_bar_color(hunger_bar, Color("FFC8DD"))  # Rosa pastello
    _apply_bar_color(stamina_bar, Color("B9FBC0")) # Verde pastello

func _apply_bar_color(bar: ProgressBar, color: Color):
    var sb = StyleBoxFlat.new()
    sb.bg_color = color
    sb.corner_radius_top_left = 10
    sb.corner_radius_top_right = 10
    sb.corner_radius_bottom_left = 10
    sb.corner_radius_bottom_right = 10
    bar.add_theme_stylebox_override("fill", sb)
    
    var bg = StyleBoxFlat.new()
    bg.bg_color = Color(0.2, 0.2, 0.2, 0.5)
    bg.corner_radius_top_left = 10
    bg.corner_radius_top_right = 10
    bg.corner_radius_bottom_left = 10
    bg.corner_radius_bottom_right = 10
    bar.add_theme_stylebox_override("background", bg)

func _on_water_changed(new_value: float, max_value: float):
    water_bar.max_value = max_value
    _animate_bar(water_bar, new_value)

func _on_hunger_changed(new_value: float, max_value: float):
    hunger_bar.max_value = max_value
    _animate_bar(hunger_bar, new_value)

func _on_stamina_changed(new_value: float, max_value: float):
    stamina_bar.max_value = max_value
    _animate_bar(stamina_bar, new_value)

# un tween per barra: i segnali survival scattano a ogni tick fisico e
# senza kill si accumulerebbero decine di tween vivi sulla stessa proprietà
var _bar_tweens := {}

func _animate_bar(bar: ProgressBar, target_value: float):
    var old = _bar_tweens.get(bar)
    if old is Tween and (old as Tween).is_valid():
        (old as Tween).kill()
    # Animazione fluida per la UI AAA
    var tween = create_tween()
    _bar_tweens[bar] = tween
    tween.tween_property(bar, "value", target_value, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
