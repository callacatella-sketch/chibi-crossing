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

// LO SPECCHIO DEI BISOGNI. Rinfrescato OGNI FRAME dal proprietario, che
// resta VillagerBrain in GDScript, e MAI scritto dal C++: `punteggi()` lo
// riceve come `const double *` e non ha nemmeno la possibilità sintattica
// di toccarlo.
//
// Perché i bisogni NON traslocano, benché la Fase 2 sia «il motore dei
// bisogni»: sono PERSISTITI dentro residents[].brain in village.json. Una
// seconda casa qui diventerebbe stale al primo `satisfy()` — con la suite
// verde — e un salvataggio scritto mentre la GDExtension non è caricata
// scriverebbe righe senza bisogni. È il cucciolo cancellato dal
// salvataggio, applicato a ventotto vicini insieme. Si migra solo ciò che
// si può PROVARE per equivalenza, e uno stato persistito non ha campione.
struct BisogniComponent {
	double v[5] = { 0.9, 1.0, 0.7, 0.6, 0.8 };
};

// L'AGENDA: stato DERIVATO e VOLATILE, come `coppia()` in Affetti e come la
// fusione delle serre. Niente da migrare, niente che possa restare appeso a
// metà, nessuna chiave nuova su disco.
struct AgendaComponent {
	int32_t azione = -1;     // quel che il registro ha scelto
	int32_t desiderata = -1; // l'argmax, anche quando non si commuta
	double da = 0.0;         // secondi nell'azione corrente
	double impegno = 0.0;    // secondi col corpo occupato (tetto di sicurezza)
	double punteggio = 0.0;
	uint32_t fatti = 0;
	bool corpo_a_riposo = true;
	bool zittita = false; // un altro sistema ha preso il corpo (r["next_act"])
	// IL DADO ARRIVA GIÀ TIRATO. In C++ non c'è e non ci sarà un RNG: i dadi
	// del villaggio si salvano (Animo._rng, come stringa perché da JSON un
	// intero perde undici bit), e un secondo generatore qui sarebbe una
	// seconda storia che nessun salvataggio racconta.
	double jitter[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
	bool cambiata = false; // vero SOLO nel frame del cambio: è il FRONTE
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
