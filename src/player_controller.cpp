#include "player_controller.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/object.hpp>
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

    // Cerca il SurvivalComponent come nodo figlio (tenuto per ObjectID)
    SurvivalComponent *sc = get_node<SurvivalComponent>("SurvivalComponent");
    if (sc) {
        survival_comp_id = sc->get_instance_id();
    } else {
        UtilityFunctions::printerr("PlayerController: SurvivalComponent mancante!");
    }
}

void PlayerController::_physics_process(double delta) {
    if (Engine::get_singleton()->is_editor_hint()) return;

    Input *input = Input::get_singleton();
    Vector3 velocity = get_velocity();

    // Lettura input base (assi WASD o controller)
    Vector2 input_dir = input->get_vector("ui_left", "ui_right", "ui_up", "ui_down");
    
    // La CameraPivot non ha yaw (la camera guarda lungo -Z, dietro/sopra Mochi):
    // quindi l'input mappa direttamente sugli assi mondo X/Z ed è GIÀ corretto
    // ("su" allontana dalla camera). NON ruotare l'input di 45°: romperebbe i
    // controlli. Servirebbe il camera-relative movement solo se in futuro la
    // camera diventasse rotabile (allora: ruotare l'input per lo yaw della camera).
    // NIENTE .normalized(): con un pad l'inclinazione parziale del levetta È
    // l'andatura, e normalizzando qualunque tocco oltre la deadzone dava
    // velocità PIENA. Danno concreto: FiatoSospeso.calma() misura
    // 1 - velocita/3.0, quindi a walk_speed pieno la calma è esattamente 0 e
    // «imparare dove e quando fermarsi» si riduceva a fermo/non-fermo.
    // Input::get_vector clampa già il modulo a 1 (le diagonali da tastiera
    // escono a 0.707): il clamp qui sotto è solo una rete di sicurezza.
    Vector3 direction = Vector3(input_dir.x, 0, input_dir.y);
    if (direction.length() > 1.0f) {
        direction = direction.normalized();
    }

    // il componente si risolve a ogni tick: null se il nodo non esiste piu'
    SurvivalComponent *survival_comp =
            Object::cast_to<SurvivalComponent>(ObjectDB::get_instance(survival_comp_id));

    // Correre = tasto premuto E movimento effettivo: da fermi il tasto di
    // corsa (ui_accept, che e' anche il "conferma" globale) non deve bruciare
    // stamina. A stamina zero col tasto premuto IN MOVIMENTO la ricarica resta
    // bloccata (come prima): evita lo sfarfallio corsa/camminata sullo zero.
    bool is_running = input->is_action_pressed("ui_accept") && direction.length() > 0.0;
    float current_speed = walk_speed;

    // La VELOCITÀ della corsa e il CONSUMO sono due cose diverse. Legarle
    // insieme rompeva la monotonia dello sfinimento: a stamina ESATTAMENTE 0
    // nessuno dei due rami toccava current_speed, che restava walk_speed
    // (3.0), mentre il GDScript aveva già portato run_speed a
    // EXHAUSTED_RUN_SPEED (1.7). La sequenza usciva 6.0 → 1.7 → 3.0: chi era
    // completamente a terra correva PIÙ VELOCE di chi era quasi a terra.
    // Ora, con la corsa premuta, si usa sempre run_speed — che è il GDScript
    // a rallentare quando sei sfinito — e solo il drenaggio guarda la stamina.
    if (is_running) {
        current_speed = run_speed;
        if (survival_comp && survival_comp->get_stamina() > 0) {
            survival_comp->drain_stamina(run_stamina_cost * delta);
        }
        // a stamina zero col tasto premuto IN MOVIMENTO la ricarica resta
        // bloccata (come prima): evita lo sfarfallio corsa/camminata sullo zero
    } else if (survival_comp) {
        // Ricarica la stamina se non stiamo correndo
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
