#ifndef PLAYER_CONTROLLER_H
#define PLAYER_CONTROLLER_H

#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/core/object_id.hpp>
#include "survival_component.h"

namespace godot {

class PlayerController : public CharacterBody3D {
    GDCLASS(PlayerController, CharacterBody3D)

private:
    float walk_speed = 3.0;
    float run_speed = 6.0;
    float run_stamina_cost = 15.0; // Per second

    // ObjectID e non puntatore raw: se il figlio venisse mai liberato, il
    // lookup per-tick restituisce null invece di un dangling pointer (UAF).
    ObjectID survival_comp_id;

protected:
    static void _bind_methods();

public:
    PlayerController();
    ~PlayerController();

    void _ready() override;
    void _physics_process(double delta) override;

    float get_walk_speed() const;
    void set_walk_speed(float p_speed);
    
    float get_run_speed() const;
    void set_run_speed(float p_speed);
};

} // namespace godot

#endif // PLAYER_CONTROLLER_H
