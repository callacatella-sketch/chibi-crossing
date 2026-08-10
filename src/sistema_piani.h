#ifndef CHIBI_SISTEMA_PIANI_H
#define CHIBI_SISTEMA_PIANI_H

#include <cstdint>

#include "sistema_agenda.h"

// IL PIANIFICATORE (GOAP): dall'obiettivo alla catena di gesti.
//
// La Fase 2 dice cosa un vicino VUOLE («provvedi alla fame»). Qui si
// risponde alla domanda dopo: COME. Non con una sequenza scritta a mano,
// ma cercandola — così quando il mondo cambia, la risposta cambia con lui.
//
// LA TESI DI QUESTA FASE, e spiega tutte le scelte sotto: in questo
// villaggio la risorsa scarsa NON sono gli oggetti, è l'ACCESSO. I vicini
// non hanno un inventario (la loro riga salvata non ne ha uno, e ogni cosa
// che producono finisce nei depositi di Mochi); l'unico ostacolo che il
// gioco modella davvero è una porta chiusa. Perciò il dominio non è
// «ho la mela / la mela è sull'albero» — è «ci arrivo / non ci arrivo».
// E la scena che ne esce è migliore: chiudi il cespuglio dentro un recinto
// mentre un vicino ci sta andando, e lui si ferma, ci ripensa, e va ad
// appendere un biglietto alla Lavagna per chiedere da mangiare a TE.
//
// Terzo gemello di sistema_sonno e sistema_agenda: puro, niente Godot,
// niente rng, e — in più — NESSUNA ALLOCAZIONE. L'arena dei nodi sta nello
// stack: un pianificatore che alloca durante il frame è un pianificatore
// che ogni tanto fa un singhiozzo, e i singhiozzi si vedono.

namespace chibi {

// I CINQUE LUOGHI di un trasferimento. L'indice è quello del vettore dei
// tempi di cammino che GDScript misura sulla ROTTA (non sulla retta): così
// il giro largo per passare dal cancello costa davvero di più.
enum Luogo : int32_t {
	L_NESSUNO = -1,
	L_CIBO = 0,
	L_AIUOLA = 1,
	L_SEDUTA = 2,
	L_BELLO = 3,
	L_LAVAGNA = 4,
	N_LUOGHI = 5,
};

// LE POSE DELL'AGENTE (bit 16-20). Le accende SOLO un operatore, mai il
// mondo: la posizione dei corpi non sta nell'ECS, e non deve entrarci per
// pianificare. Conseguenza dichiarata: il primo passo di ogni piano è
// sempre un trasferimento — il vicino non sa di essere già arrivato.
enum Posa : uint32_t {
	A_AL_CIBO = 1u << 16,
	A_ALL_AIUOLA = 1u << 17,
	A_ALLA_SEDUTA = 1u << 18,
	A_AL_BELLO = 1u << 19,
	A_ALLA_LAVAGNA = 1u << 20,
	MASCHERA_POSE = 0x001F0000u,
};

// I PROVVEDIMENTI (bit 24-27), cioè gli obiettivi.
//
// Il nome è la cosa più importante di questo file. L'obiettivo NON è «sono
// sazio»: è «ho fatto qualcosa per la mia fame». Se chiedere da mangiare
// accendesse «sazio», il pianificatore mentirebbe — chiedere non riempie
// la pancia. La sazietà resta di chi la pagava già (STATO_CHE_SAZIA, le
// callback d'arrivo, e per la richiesta la consegna vera dalle mani del
// giocatore): la regola della Fase 2 — «si paga quando il gesto ACCADE» —
// non si tocca.
enum Provvedimento : uint32_t {
	A_PROV_PANCINO = 1u << 24,
	A_PROV_CURA = 1u << 25,
	A_PROV_ENERGIA = 1u << 26,
	A_PROV_MERAVIGLIA = 1u << 27,
	MASCHERA_PROVVEDIMENTI = 0x0F000000u,
};

// DUE MASCHERE, ED È UN CONTRATTO: il risolutore non può inventarsi un
// fatto del mondo, e il GDScript non può accendere una posa. È la stessa
// disciplina con cui il C++ riceve i bisogni in sola lettura.
constexpr uint32_t MASCHERA_MONDO = 0x00001FFFu;  // bit 0-12
constexpr uint32_t MASCHERA_AGENTE = 0x0F1F0000u; // bit 16-20 e 24-27

enum Operatore : int32_t {
	OP_NESSUNO = -1,
	OP_VAI_CIBO = 0,
	OP_SGRANOCCHIA = 1,
	OP_VAI_AIUOLA = 2,
	OP_ANNAFFIA = 3,
	OP_VAI_SEDUTA = 4,
	OP_SIEDI = 5,
	OP_PISOLINO = 6,
	OP_VAI_BELLO = 7,
	OP_INCANTATI = 8,
	OP_VAI_LAVAGNA = 9,
	OP_CHIEDI_CIBO = 10,
	OP_CHIEDI_CURA = 11,
	N_OPERATORI = 12,
};

struct OperatoreDef {
	int32_t id = OP_NESSUNO;
	int32_t luogo = L_NESSUNO; // >= 0 se è un trasferimento
	uint32_t richiede = 0;     // TUTTI accesi
	uint32_t vieta = 0;        // TUTTI spenti
	uint32_t aggiunge = 0;
	uint32_t toglie = 0;
	double costo_base = 0.0; // secondi; ai trasferimenti si somma la rotta
};

const OperatoreDef *operatori();

struct TaraturaPiani {
	// il budget è il tetto d'impegno dell'agenda (45 s) meno il margine: un
	// piano che dura più di così verrebbe strappato via a metà
	double budget_secondi = 40.0;
	int32_t max_nodi = 256;
	int32_t max_profondita = 6;
};

enum EsitoCodice : int32_t {
	PIANO_OK = 0,
	PIANO_GIA_VERO = 1, // l'obiettivo è già soddisfatto: niente da fare
	PIANO_NIENTE = 2,   // nessuna catena esiste in questo mondo
	PIANO_BUDGET = 3,   // si è esaurita l'arena: MAI un piano parziale
};

struct EsitoPiano {
	int32_t n = 0;
	int32_t passi[6] = { -1, -1, -1, -1, -1, -1 };
	double costo = 0.0;
	int32_t nodi = 0; // le espansioni: è un'USCITA, i test la leggono
	int32_t esito = PIANO_NIENTE;
};

// A* IN AVANTI su stati che sono uint32_t. Deterministico fino ai pareggi:
// niente hash map, niente ordine dipendente dall'allocatore.
// `p_cammino[l] < 0` vuol dire «questo luogo non è disponibile»: è la
// doppia sicurezza oltre ai bit di raggiungibilità.
EsitoPiano pianifica(uint32_t p_stato, uint32_t p_obiettivo,
		const double p_cammino[N_LUOGHI], const TaraturaPiani &p_tar);

} // namespace chibi

#endif // CHIBI_SISTEMA_PIANI_H
