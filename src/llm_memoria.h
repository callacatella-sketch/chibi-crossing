#ifndef CHIBI_LLM_MEMORIA_H
#define CHIBI_LLM_MEMORIA_H

// QUANTO PESA QUESTO PROCESSO, ADESSO.
//
// Il tetto della Fase 5 è dell'autore e vale 2 GB. Un tetto senza un metro è
// un desiderio, e questo è il metro — misurato DA DENTRO, col gioco acceso,
// che è l'unico posto da cui il numero è quello vero.
//
// ⚠️ IL RSS MENTE, e in questo progetto lo ha già fatto. Su macOS il
// «resident set size» non conta i buffer che stanno dalla parte della GPU
// (memoria unificata) e conta a modo suo le pagine mappate da file: su un
// modello da 2,84 GB dichiarava 564 MB. Il numero con cui il sistema decide
// davvero chi mandare in swap è il PHYSICAL FOOTPRINT, ed è quello che conta
// su un Mac da 8 GB con un gioco già acceso. Si danno tutti e due, e chi
// legge vede la differenza.
//
// Zero vuol dire «questa piattaforma non lo sa dire»: è dichiarato, non
// nascosto dietro un numero inventato.

#include <cstdint>

namespace chibi {

// L'impronta fisica: quello che il sistema operativo mette sul conto di
// questo processo. Su macOS `phys_footprint`; su Linux il residente
// (che lì è la stessa cosa); su Windows 0, per ora — vedi il .cpp.
uint64_t memoria_impronta();

// Il vecchio RSS. Serve al confronto: quando i due numeri divergono di molto,
// la differenza sta nelle pagine mappate dal .gguf, e quella differenza è
// esattamente ciò che si può togliere dalla RAM senza swap.
uint64_t memoria_residente();

// ─────────────────────────────────────────────────────────────────────────
// E QUANTA RAM HA LA MACCHINA, ADESSO
// ─────────────────────────────────────────────────────────────────────────
//
// Il tetto dell'autore («al massimo 3 GB per il modello») è una domanda sul
// MODELLO. Questa è la domanda sulla MACCHINA, ed è l'altra metà: un Mac da
// 8 GB con due browser aperti non ha tre gigabyte da dare a nessuno, e
// prenderseli lo stesso vuol dire mandare in swap il gioco DEL GIOCATORE —
// cioè trasformare una funzione facoltativa e piacevole nella ragione per cui
// il gioco singhiozza. La Fase 5 ha una regola sola («il gioco funziona
// identico senza»): allora, quando la RAM non c'è, la funzione si deve
// spegnere DA SOLA.
//
// ⚠️ ZERO VUOL DIRE «QUESTA PIATTAFORMA NON LO SA DIRE», e chi legge deve
// trattarlo come «non lo so», mai come «non c'è memoria»: il degrado va
// sempre verso «il gioco continua», e rifiutare il modello per un numero che
// non abbiamo sarebbe spegnere una funzione senza una ragione misurata.

// Quanta RAM fisica ha in tutto questa macchina.
//  · macOS   : `sysctl hw.memsize`
//  · Linux   : MemTotal di /proc/meminfo
//  · Windows : `GlobalMemoryStatusEx().ullTotalPhys` — sta in kernel32, che è
//              già linkata: nessuna libreria in più da aggiungere al link
//              (per questo qui c'è Windows e in `memoria_impronta()` no, dove
//              servirebbe psapi).
uint64_t memoria_totale_sistema();

// Quanta se ne può prendere ADESSO senza far cominciare lo swap.
//
// ⚠️ NON È «free». Su macOS la memoria libera è quasi sempre poca per
// costruzione (il sistema usa tutto quello che avanza come cache del disco),
// e leggere solo `free_count` farebbe rifiutare il modello su una macchina
// vuota. Si sommano le pagine che il sistema può riprendersi senza scrivere
// su disco: libere + inattive + eliminabili. Su Linux la stessa domanda ha
// una risposta ufficiale e migliore della nostra somma, `MemAvailable`, ed è
// quella che si legge.
uint64_t memoria_libera_sistema();

} // namespace chibi

#endif // CHIBI_LLM_MEMORIA_H
