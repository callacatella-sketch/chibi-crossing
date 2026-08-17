#ifndef CHIBI_ECS_ENTT_H
#define CHIBI_ECS_ENTT_H

// L'UNICO posto del progetto autorizzato a includere EnTT.
//
// Non è pignoleria: i due rami del SConstruct compilano con impostazioni
// ASIMMETRICHE, e qui le si pareggia una volta sola. Chi includesse
// `thirdparty/entt/entt.hpp` da un altro .cpp le riaprirebbe entrambe, e
// nessun test se ne accorgerebbe (il difetto uscirebbe come un
// comportamento diverso fra la build Windows e quella macOS).
//
// 1) LE ECCEZIONI. godot-cpp compila con `-fno-exceptions` su macOS/Linux
//    (godot-cpp/tools/common_compiler_flags.py), mentre il nostro ramo
//    Windows usa /EHsc (SConstruct) senza `_HAS_EXCEPTIONS=0`. EnTT non
//    deve lanciare MAI: su macOS un throw sarebbe una `std::terminate`.
// 2) GLI ASSERT. `NDEBUG` è definito in release sul ramo win32, e anche
//    in `template_debug` su macOS/Linux (godot-cpp non fa dev_build). Senza
//    questa riga gli assert di EnTT sarebbero vivi solo in una delle
//    quattro combinazioni. Qui sono uguali ovunque e rumorosi alla maniera
//    di Godot: stampano e proseguono, non abbattono il gioco del giocatore.
#include <godot_cpp/core/error_macros.hpp>

#define ENTT_NOEXCEPTION 1
#define ENTT_ASSERT(condition, msg) \
	do { \
		if (!(condition)) { \
			ERR_PRINT(msg); \
		} \
	} while (0)

#include "thirdparty/entt/entt.hpp"

#endif // CHIBI_ECS_ENTT_H
