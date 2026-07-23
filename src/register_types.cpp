#include "register_types.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

// Includes dei nostri componenti custom
#include "survival_component.h"
#include "grid_manager.h"
#include "player_controller.h"
#include "ecosystem_manager.h"

using namespace godot;

void initialize_chibi_crossing_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    // Registrazione delle classi C++
    ClassDB::register_class<SurvivalComponent>();
    ClassDB::register_class<GridManager>();
    ClassDB::register_class<PlayerController>();
    ClassDB::register_class<EcosystemManager>();
}

void uninitialize_chibi_crossing_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}

extern "C" {
// Punto di ingresso richiesto da Godot per l'inizializzazione della libreria dinamica
GDExtensionBool GDE_EXPORT chibi_crossing_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
    godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

    init_obj.register_initializer(initialize_chibi_crossing_module);
    init_obj.register_terminator(uninitialize_chibi_crossing_module);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

    return init_obj.init();
}
}
