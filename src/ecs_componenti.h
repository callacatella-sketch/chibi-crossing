#ifndef CHIBI_ECS_COMPONENTI_H
#define CHIBI_ECS_COMPONENTI_H

#include <cstdint>

#include <godot_cpp/variant/vector3.hpp>

#include "grafo_deduzioni.h" // FASE 5: Deduzioni
#include "grafo_ricordi.h"   // FASE 4: GrafoRicordi
#include "sistema_occ.h"     // FASE 4: Gusto (e, per suo tramite, N_AZIONI)

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

// ======================================================================
// FASE 4 (P4) — PERCEZIONE, MEMORIA, EMOZIONE
//
// Tre componenti, e sono di TRE specie diverse. La specie non è una
// sfumatura: dice chi possiede il dato, e quindi che genere di guasto è
// possibile su quel dato.
// ======================================================================

// IL GRAFO DEI RICORDI — **VOLATILE**, e non è una semplificazione.
//
// Vive in RAM sull'entità, come l'handle: nessuna chiave nuova in
// village.json, nessuna migrazione, nessuna riga scartata in silenzio al
// caricamento. Ed è anche una regola di GAME DESIGN, non solo di
// ingegneria: l'emozione dura minuti e non lascia traccia, perché un
// residuo che dura si impara a coltivare — ci si farebbe guardare mentre
// si annaffia in cerchio per «caricare» i vicini, e il gesto gentile
// diventerebbe una moneta. La moneta dei legami in questo gioco è già
// un'altra (Legami, Affetti), e dev'essere l'unica.
//
// Dove muore il cervello muore l'entità, e con l'entità muore questo
// grafo: `dimentica()` distrugge l'entità e tutti i suoi componenti
// insieme. Non c'è nessuna spazzata da fare sugli handle che i ricordi
// degli ALTRI portano dentro (`Ricordo.soggetto`) — un handle morto non
// risolve, e il ricordo degrada a «qualcuno». È il degrado giusto:
// un'etichetta assente, mai un comportamento sbagliato.
struct GrafoComponent {
	GrafoRicordi g;
};

// IL GUSTO — **SPECCHIO**, esattamente come `BisogniComponent`.
//
// Il proprietario del dato è il GDScript (`scenes/npc/Gusto.gd`), che lo
// deriva dai pesi del DNA e dall'indole. Nessuno dei due è immutabile a
// runtime: il salone di bellezza riscrive DENTRO il Dictionary del DNA e
// `debug_quirk` cambia il quirk di un cervello vivo. Perciò qui c'è una
// COPIA, che il cablaggio confronta e riproietta quando i valori cambiano
// davvero — la stessa disciplina (e la stessa lezione già pagata) del
// `DnaComponent`.
//
// Neutro = tutti 1.0: un villaggio senza gusti è un villaggio in cui ogni
// gesto vale uguale per tutti, ed è lo stato in cui nasce un'entità che
// nessuno ha ancora descritto.
struct GustoComponent {
	Gusto gu;
};

// «Non ho mai valutato». Sta qui e non nel .cpp perché è il valore con cui
// il componente NASCE: chi lo legge deve poterlo riconoscere senza andare
// a cercare da un'altra parte cosa significhi quel numero.
//
// Una versione vera potrebbe teoricamente arrivare a questo valore, ma
// servono 2^32 scritture sullo stesso grafo (a un ricordo per frame, anni
// di gioco continuo su un solo vicino), e la conseguenza sarebbe UNA
// rivalutazione saltata: il gradino dopo la rimette a posto da sé.
constexpr uint32_t VISTA_MAI = 0xFFFFFFFFu;

// LE EMOZIONI — **DERIVATO**, e con un LATCH.
//
// Non è uno stato affettivo: non c'è un umore che scende, non c'è
// un'emozione con la sua identità e la sua durata. `mod` è la LETTURA del
// grafo fatta all'ultimo gradino, congelata fino al prossimo. L'emozione
// *è* la lettura (vedi la tesi in sistema_occ.h); questo componente è solo
// il posto dove la lettura riposa fra un gradino e l'altro.
//
// PERCHÉ UN LATCH E NON UNA LETTURA PER FRAME: costa 2,6 volte meno e dà un
// numero che sta fermo mentre lo si usa. Le due misure e la ragione che
// invece NON vale (il tremolio, che è un'eredità del piano e non si
// verifica) stanno per esteso su `PASSO_EMO`, in sistema_occ.h — qui non se
// ne tiene una seconda copia.
//
// Si rivaluta SOLO quando il grafo è cambiato (`vista` contro
// `GrafoRicordi.versione`) oppure quando sono passati `PASSO_EMO` secondi
// (`t_valutato`). Dentro un gradino il mod è lo stesso double, bit per bit —
// e un test lo pretende bit per bit, non «circa».
//
// Il neutro è LETTERALE, otto 1.0 scritti a mano: su quell'esattezza
// poggia la prova di equivalenza dell'agenda (67.200 confronti bit-esatti).
// Un neutro costruito da un calcolo che «dovrebbe» dare 1.0 la farebbe
// cadere — o peggio, la farebbe passare per un pelo oggi.
struct EmozioniComponent {
	double mod[N_AZIONI] = { 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 };
	uint32_t vista = VISTA_MAI;
	float t_valutato = -1.0e9f;
};

// Se un domani arriva una nona azione, i letterali qui sopra (e i loro
// gemelli in `AgendaComponent.jitter`, in `modulatori()` e in `avanza()`)
// smettono di coprirla: che lo dica il compilatore, non il profiler.
static_assert(N_AZIONI == 8, "otto azioni, otto 1.0 letterali");

// ======================================================================
// FASE 5 — LE DEDUZIONI
// ======================================================================

// LE DEDUZIONI — **VOLATILE**, come il grafo dei ricordi, e per una ragione
// in più che il grafo non aveva.
//
// Il grafo non si salva perché l'emozione dura minuti e non deve diventare
// una moneta. Questo non si salva anche perché **il suo contenuto non è
// riproducibile**: viene da un modello linguistico che il giocatore può non
// avere, che può essere un altro modello, che su un'altra macchina scrive
// un'altra cosa. Un salvataggio che ne dipendesse non si riaprirebbe uguale
// due volte — e per la stragrande maggioranza dei giocatori (il modello è
// spento di serie) questo componente resta vuoto per l'intera partita, il
// che è esattamente la promessa «il gioco funziona IDENTICO senza».
//
// Nasce vuoto INSIEME agli altri, come i tre della Fase 4: un componente
// aggiunto «quando serve» farebbe sparire dei residenti dalle viste che lo
// includono, in silenzio.
struct DeduzioniComponent {
	Deduzioni d;
};

} // namespace chibi

#endif // CHIBI_ECS_COMPONENTI_H
