#ifndef SURVIVAL_COMPONENT_H
#define SURVIVAL_COMPONENT_H

#include <godot_cpp/classes/node.hpp>

namespace godot {

class SurvivalComponent : public Node {
    GDCLASS(SurvivalComponent, Node)

private:
    double stamina = 100.0;
    double max_stamina = 100.0;
    
    double hunger = 100.0;
    double max_hunger = 100.0;

    double water = 100.0;
    double max_water = 100.0;

protected:
    static void _bind_methods();

public:
    SurvivalComponent();
    ~SurvivalComponent();

    void _ready() override;
    void _process(double delta) override;

    // Stamina
    double get_stamina() const;
    void set_stamina(double p_stamina);
    double get_max_stamina() const;
    void set_max_stamina(double p_max);
    void drain_stamina(double amount);

    // Hunger
    double get_hunger() const;
    void set_hunger(double p_hunger);
    double get_max_hunger() const;
    void set_max_hunger(double p_max);

    // Water
    double get_water() const;
    void set_water(double p_water);
    double get_max_water() const;
    void set_max_water(double p_max);
};

} // namespace godot

#endif // SURVIVAL_COMPONENT_H
