#ifndef CHIBI_ECS_COMPONENTI_H
#define CHIBI_ECS_COMPONENTI_H

#include <cstdint>

#include <godot_cpp/variant/vector3.hpp>

namespace chibi {

// IL DNA, e la regola che gli impedisce di mentire.
//
// Qui entrano SOLO i geni che il gioco dichiara immutabili a corpo nato.
// Il salone di bellezza riscrive i geni estetici scrivendo DENTRO il
// Dictionary del DNA — che è lo stesso oggetto della riga del salvataggio,
// condiviso per riferimento. Una copia C++ di un gene estetico diventerebbe
// quindi stale al primo cambio di look, e la suite resterebbe verde.
// `indole` e `quirk` non sono estetici, quindi il SALONE non li tocca: è per
// questo che stanno qui e i diciassette geni estetici no.
//
// Ma «non estetico» non vuol dire «immutabile»: `Visitors.debug_quirk()`
// scrive il quirk su un cervello vivo (lo usa DebugHarness per fabbricare un
// nottambulo). Una fotografia scattata alla registrazione e mai più
// aggiornata manderebbe a letto alle 0.80 uno che è appena diventato
// nottambulo — e non se ne accorgerebbe nessuno. Per questo esiste
// `EcsMondo::riproietta()`, che il cablaggio chiama quando i valori del
// cervello CAMBIANO davvero (non a ogni frame: si confrontano prima).
// La prima stesura di questo commento diceva che la proiezione «non PUÒ
// scadere». Non era vero, e l'ha trovato una revisione avversariale.
//
// L'ordine dei bit NON è un contratto verso il salvataggio: la tabella vera
// resta `VillagerBrain.INDOLI` in GDScript, e la traduzione nome→bit la fa
// `EcsMondo::maschera_indole()`, che un test confronta riga per riga con lei.
struct DnaComponent {
	uint32_t indole = 0; // maschera di bit (vedi chibi::Indole)
	int32_t quirk = -1;  // indice in VillagerBrain.QUIRKS, -1 = nessuno
};

// LO STATO, e sono TRE valori — non i 43 stati-stringa del Visitor.
// `da` serve ai test (e domani alle isteresi): quanti secondi di gioco il
// residente sta in questo stato.
struct StatoComponent {
	int32_t stato = 0; // chibi::SVEGLIO / DORME / FUORI
	double da = 0.0;
};

// I FATTI che il mondo riferisce ogni frame. Non decisioni: sono le tre
// cose che il C++ non può sapere da solo perché vivono nell'albero della
// scena.
struct MondoComponent {
	bool nascosto = false;     // il corpo è già sparito dentro casa
	bool corpo_libero = true;  // sta facendo qualcosa da cui si può staccare
	bool porta_aperta = true;  // chi divide la casa con lui gliela apre
};

// DICHIARATO, MAI ISTANZIATO IN FASE 1 — e non è una svista.
//
// In Fase 1 nessun sistema C++ legge una posizione: sarebbe un componente
// scritto ogni frame e letto da nessuno, cioè un motore acceso a vuoto, e
// per giunta una seconda casa della posizione (il padrone resta il Node3D).
// `EcsMondo::debug_quante_pose()` deve tornare 0, e un test lo pretende.
// Entra vivo quando arriva il suo primo lettore vero — il cammino.
// `frame_agg` esiste perché una lettura stantia sia RILEVABILE invece di
// essere plausibile.
struct TransformComponent {
	godot::Vector3 pos;
	float yaw = 0.0f;
	uint64_t frame_agg = 0;
};

} // namespace chibi

#endif // CHIBI_ECS_COMPONENTI_H
