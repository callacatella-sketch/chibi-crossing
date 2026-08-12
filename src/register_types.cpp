#include "register_types.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

// Includes dei nostri componenti custom
#include "survival_component.h"
#include "grid_manager.h"
#include "player_controller.h"
#include "ecosystem_manager.h"
#include "ecs_mondo.h"

// FASE 5, e la condizione non e' decorativa: `CHIBI_LLM` lo definisce il
// SConstruct solo con `llm=yes`. Senza, `llm_ponte.cpp` non viene nemmeno
// compilato, questo include sparisce, e il preprocessore restituisce
// esattamente il file di prima — il binario e' identico byte per byte
// (verificato per impronta SHA-256 su entrambi i target).
#ifdef CHIBI_LLM
#include "llm_ponte.h"
#endif

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
    ClassDB::register_class<EcsMondo>();
#ifdef CHIBI_LLM
    // L'ESISTENZA di questa classe e' il segnale: il gioco chiede
    // `ClassDB.class_exists("LlmLocale")` e sa se ha un cuore che scrive.
    // Nessun sistema deve DIPENDERE dalla risposta `true`.
    ClassDB::register_class<LlmLocale>();
#endif
}

void uninitialize_chibi_crossing_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
#ifdef CHIBI_LLM
    // LA RETE DI SICUREZZA DELLO SPEGNIMENTO. Il gioco spegne il traduttore da
    // solo (`Pensatoio._exit_tree`), ma un thread ancora vivo dentro una
    // libreria dinamica che si sta SCARICANDO e' un crash all'uscita — e un
    // crash all'uscita non lo vede nessuno, perche' la finestra e' gia'
    // sparita. Qui il thread e' gia' fermo nel caso normale, e questa riga
    // costa zero; nel caso che qualcuno si e' dimenticato, costa l'attesa di
    // un pezzo di token (l'abort_callback lo interrompe a meta').
    LlmLocale::spegni_tutto();
#endif
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
