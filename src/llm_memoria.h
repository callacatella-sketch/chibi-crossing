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

} // namespace chibi

#endif // CHIBI_LLM_MEMORIA_H
