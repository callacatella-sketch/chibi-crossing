#include "player_controller.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void PlayerController::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_walk_speed"), &PlayerController::get_walk_speed);
    ClassDB::bind_method(D_METHOD("set_walk_speed", "p_speed"), &PlayerController::set_walk_speed);
    ClassDB::bind_method(D_METHOD("get_run_speed"), &PlayerController::get_run_speed);
    ClassDB::bind_method(D_METHOD("set_run_speed", "p_speed"), &PlayerController::set_run_speed);

    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "walk_speed"), "set_walk_speed", "get_walk_speed");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "run_speed"), "set_run_speed", "get_run_speed");
}

PlayerController::PlayerController() {}

PlayerController::~PlayerController() {}

void PlayerController::_ready() {
    if (Engine::get_singleton()->is_editor_hint()) return;

    set_physics_process(true); // Fondamentale in GDExtension per attivare il loop

    // Cerca il SurvivalComponent come nodo figlio
    survival_comp = get_node<SurvivalComponent>("SurvivalComponent");
    if (!survival_comp) {
        UtilityFunctions::printerr("PlayerController: SurvivalComponent mancante!");
    }
}

void PlayerController::_physics_process(double delta) {
    if (Engine::get_singleton()->is_editor_hint()) return;

    Input *input = Input::get_singleton();
    Vector3 velocity = get_velocity();

    // Lettura input base (assi WASD o controller)
    Vector2 input_dir = input->get_vector("ui_left", "ui_right", "ui_up", "ui_down");
    
    // Converti l'input direzionale in base all'inquadratura isometrica (assumiamo telecamera statica a 45 gradi)
    // Per un vero isometrico, spesso si ruota l'input di 45 gradi. Per ora lo teniamo dritto rispetto agli assi globali X/Z.
    Vector3 direction = Vector3(input_dir.x, 0, input_dir.y).normalized();

    bool is_running = input->is_action_pressed("ui_accept"); // Es. Spazio o Shift per correre
    float current_speed = walk_speed;

    if (is_running && survival_comp && survival_comp->get_stamina() > 0) {
        current_speed = run_speed;
        survival_comp->drain_stamina(run_stamina_cost * delta);
    } else if (survival_comp && !is_running) {
        // Ricarica la stamina se non stiamo correndo (col tasto premuto a
        // stamina zero niente ricarica: la velocità resta stabile a walk)
        survival_comp->set_stamina(survival_comp->get_stamina() + (10.0 * delta));
    }

    if (direction.length() > 0.0) {
        velocity.x = direction.x * current_speed;
        velocity.z = direction.z * current_speed;
    } else {
        // Attrito/Decelerazione
        velocity.x = Math::move_toward(velocity.x, (float)0.0, (float)current_speed);
        velocity.z = Math::move_toward(velocity.z, (float)0.0, (float)current_speed);
    }

    // Applica gravità di base
    if (!is_on_floor()) {
        velocity.y -= 9.8 * delta;
    } else {
        velocity.y = 0;
    }

    set_velocity(velocity);
    move_and_slide();
}

float PlayerController::get_walk_speed() const {
    return walk_speed;
}

void PlayerController::set_walk_speed(float p_speed) {
    walk_speed = p_speed;
}

float PlayerController::get_run_speed() const {
    return run_speed;
}

void PlayerController::set_run_speed(float p_speed) {
    run_speed = p_speed;
}
