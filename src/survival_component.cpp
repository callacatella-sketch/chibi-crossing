#include "survival_component.h"
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void SurvivalComponent::_bind_methods() {
    // Registra metodi e proprietà
    ClassDB::bind_method(D_METHOD("get_stamina"), &SurvivalComponent::get_stamina);
    ClassDB::bind_method(D_METHOD("set_stamina", "p_stamina"), &SurvivalComponent::set_stamina);
    ClassDB::bind_method(D_METHOD("get_max_stamina"), &SurvivalComponent::get_max_stamina);
    ClassDB::bind_method(D_METHOD("set_max_stamina", "p_max"), &SurvivalComponent::set_max_stamina);
    ClassDB::bind_method(D_METHOD("drain_stamina", "amount"), &SurvivalComponent::drain_stamina);

    ClassDB::bind_method(D_METHOD("get_hunger"), &SurvivalComponent::get_hunger);
    ClassDB::bind_method(D_METHOD("set_hunger", "p_hunger"), &SurvivalComponent::set_hunger);
    ClassDB::bind_method(D_METHOD("get_max_hunger"), &SurvivalComponent::get_max_hunger);
    ClassDB::bind_method(D_METHOD("set_max_hunger", "p_max"), &SurvivalComponent::set_max_hunger);

    ClassDB::bind_method(D_METHOD("get_water"), &SurvivalComponent::get_water);
    ClassDB::bind_method(D_METHOD("set_water", "p_water"), &SurvivalComponent::set_water);
    ClassDB::bind_method(D_METHOD("get_max_water"), &SurvivalComponent::get_max_water);
    ClassDB::bind_method(D_METHOD("set_max_water", "p_max"), &SurvivalComponent::set_max_water);

    // Proprietà esposte nell'Editor
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "max_stamina"), "set_max_stamina", "get_max_stamina");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "max_hunger"), "set_max_hunger", "get_max_hunger");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "max_water"), "set_max_water", "get_max_water");

    // Segnali
    ADD_SIGNAL(MethodInfo("stamina_changed", PropertyInfo(Variant::FLOAT, "new_value"), PropertyInfo(Variant::FLOAT, "max_value")));
    ADD_SIGNAL(MethodInfo("hunger_changed", PropertyInfo(Variant::FLOAT, "new_value"), PropertyInfo(Variant::FLOAT, "max_value")));
    ADD_SIGNAL(MethodInfo("water_changed", PropertyInfo(Variant::FLOAT, "new_value"), PropertyInfo(Variant::FLOAT, "max_value")));
}

SurvivalComponent::SurvivalComponent() {}

SurvivalComponent::~SurvivalComponent() {}

void SurvivalComponent::_ready() {
    // set_process va attivato quando il nodo è nell'albero, non nel costruttore.
    if (Engine::get_singleton()->is_editor_hint()) return;
    set_process(true);
}

void SurvivalComponent::_process(double delta) {
    if (Engine::get_singleton()->is_editor_hint()) return;

    // Non consumare fame/acqua mentre il gioco è in pausa (menu, dialoghi). Con
    // il process_mode di default (PAUSABLE) _process non verrebbe nemmeno
    // chiamato a gioco in pausa; questa guardia copre anche il caso in cui il
    // nodo venga messo in PROCESS_MODE_ALWAYS.
    SceneTree *tree = get_tree();
    if (tree && tree->is_paused()) return;

    // Sete e Fame scendono lentamente nel tempo.
    double hunger_drain_rate = 0.5; // al secondo
    double water_drain_rate = 1.0;  // al secondo
    set_hunger(hunger - (hunger_drain_rate * delta));
    set_water(water - (water_drain_rate * delta));
}

// Stamina Implementation
double SurvivalComponent::get_stamina() const { return stamina; }
void SurvivalComponent::set_stamina(double p_stamina) {
    double old_stamina = stamina;
    stamina = UtilityFunctions::clamp(p_stamina, 0.0, max_stamina);
    if (stamina != old_stamina) {
        emit_signal("stamina_changed", stamina, max_stamina);
    }
}
double SurvivalComponent::get_max_stamina() const { return max_stamina; }
void SurvivalComponent::set_max_stamina(double p_max) {
    max_stamina = MAX(p_max, 0.0);
    set_stamina(stamina); // ri-clampa il corrente ed emette il segnale se cambia
}
void SurvivalComponent::drain_stamina(double amount) {
    set_stamina(stamina - amount);
}

// Hunger Implementation
double SurvivalComponent::get_hunger() const { return hunger; }
void SurvivalComponent::set_hunger(double p_hunger) {
    double old_hunger = hunger;
    hunger = UtilityFunctions::clamp(p_hunger, 0.0, max_hunger);
    if (hunger != old_hunger) {
        emit_signal("hunger_changed", hunger, max_hunger);
    }
}
double SurvivalComponent::get_max_hunger() const { return max_hunger; }
void SurvivalComponent::set_max_hunger(double p_max) {
    max_hunger = MAX(p_max, 0.0);
    set_hunger(hunger);
}

// Water Implementation
double SurvivalComponent::get_water() const { return water; }
void SurvivalComponent::set_water(double p_water) {
    double old_water = water;
    water = UtilityFunctions::clamp(p_water, 0.0, max_water);
    if (water != old_water) {
        emit_signal("water_changed", water, max_water);
    }
}
double SurvivalComponent::get_max_water() const { return max_water; }
void SurvivalComponent::set_max_water(double p_max) {
    max_water = MAX(p_max, 0.0);
    set_water(water);
}
