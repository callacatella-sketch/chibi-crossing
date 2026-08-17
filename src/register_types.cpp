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
    // LA RETE DI SICUREZZA DELLO SPEGNIMENTO, ed e' l'ULTIMA delle tre — le
    // altre due stanno un piano piu' in su e fermano il lavoro senza liberare
    // il modello: il distruttore dell'ultimo maniglione (`~LlmLocale`) e il
    // `NOTIFICATION_PREDELETE` del Pensatoio. Questa qui e' l'unica che si
    // occupa del THREAD, e serve perche' un thread ancora vivo dentro una
    // libreria dinamica che si sta SCARICANDO e' un crash all'uscita — e un
    // crash all'uscita non lo vede nessuno, perche' la finestra e' gia'
    // sparita. Nel caso normale il thread sta solo aspettando e questa riga
    // costa zero; se stava generando, costa un pezzo di token
    // (l'abort_callback lo interrompe a meta').
    //
    // ⚠️ CHE VENGA CHIAMATA DAVVERO E' MISURATO, non sperato: con una sonda
    // temporanea su stderr, Godot 4.7.1 chiama il terminatore per tutti e
    // quattro i livelli (3, 2, 1, 0) e questa riga gira al livello SCENE (2),
    // con il gioco che si chiude in 2.4 s mentre il modello stava generando.
    // La nota vecchia diceva invece che a spegnere il traduttore era
    // «`Pensatoio._exit_tree`»: quel metodo non esiste — il Pensatoio e' un
    // RefCounted e non sta nell'albero — ed era una rete disegnata, mai tesa.
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
