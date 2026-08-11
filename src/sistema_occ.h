#ifndef CHIBI_SISTEMA_OCC_H
#define CHIBI_SISTEMA_OCC_H

#include <cstdint>

#include "grafo_ricordi.h"
#include "sistema_agenda.h" // N_AZIONI e i nomi delle otto azioni

// COSA PROVA UN VICINO PER QUELLO CHE TI HA VISTO FARE.
//
// LA TESI, ed è tutto il file: **l'emozione non è un oggetto**. Non ha
// identità, non ha durata, non ha un contatore che scende. È la LETTURA del
// grafo dei ricordi fatta adesso — la stessa idea di `coppia()` in Affetti
// (un predicato derivato, niente da tenere sincronizzato, niente che resti
// appeso a metà) e di `Animo._recenza` (il tempo si applica in lettura).
//
// Il guasto che questa forma rende IMPOSSIBILE, e che una prima stesura del
// piano aveva: sei istanze d'emozione con la loro mezza vita, che decadono
// per frame accanto a un grafo che decade per conto suo. Due orologi sullo
// stesso sentimento divergono in silenzio, e il giorno che divergono nessun
// test lo dice — è il `BisogniComponent` applicato ai sentimenti.
// Qui non c'è niente da far decadere: si cancella un fatto e l'emozione che
// ne veniva non esiste più nello stesso istante.
//
// COSA NON C'È, e non per dimenticanza:
//  · nessuna valenza NEGATIVA, e non è una taratura prudente: gli otto verbi
//    sono tutti gesti del ciclo di gioco (regola 4 del piano). Senza
//    contenuto negativo su una persona la gogna non è tarata male, è
//    impossibile. `Voce.gd` resta l'unico canale che porta una parola SU
//    qualcuno, ed è un verbo del giocatore.
//  · nessun `arousal`, nessun `umore`, nessun marchio: quella è la casa di
//    `Limbico`, e due umori che divergono in silenzio sarebbero il difetto
//    di sopra con un altro nome. Qui si calcolano ETICHETTE, non stato
//    affettivo.
//  · nessuna nona azione, nessun corpo che si sposta perché il giocatore si
//    è spostato: `modulatori()` INCLINA otto numeri e basta (regola 5).
//  · niente Godot, niente EnTT, niente rng, niente allocazioni. Quarto
//    gemello di sistema_sonno, sistema_agenda e sistema_piani.

namespace chibi {

// IL GUSTO: quanto ti importa di ciascuna delle sei cose.
//
// È uno SPECCHIO, come `BisogniComponent`: il proprietario è il GDScript
// (`scenes/npc/Gusto.gd`, che lo deriva dai pesi del DNA e dall'indole —
// entrambi mutabili a runtime), qui se ne tiene una copia di sola lettura.
// Neutro = tutti 1.0: un villaggio senza gusti è un villaggio in cui ogni
// gesto vale uguale per tutti.
//
// I valori NEGATIVI non esistono: un gusto negativo vorrebbe dire «mi dà
// fastidio che tu annaffi», cioè esattamente il contenuto che la regola 4
// vieta. `valuta()` lo pinza a zero invece di crederci — il segno non è una
// taratura da rispettare per disciplina, è una regola tenuta in codice.
struct Gusto {
	double per_cosa[N_COSE] = { 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 };
};

// LE TINTE: la lettura, in tre famiglie. Sono SEMPRE >= 0.
//
//  · `interesse[c]` — quanto pesa, per me, quello che ti ho visto fare CON
//    quella cosa. È la tinta che sposta il corpo: l'aiuola che ha visto.
//  · `ammirazione` — la somma delle sei. NON è un secondo dato da tenere
//    d'occhio: è una riduzione, come `Critters.colore_pallino()`. Passa dal
//    gusto apposta — un'ammirazione uguale per tutti sarebbe un canale che
//    non discrimina, cioè indistinguibile da un dado (è la lezione delle
//    REAZIONI di Animo, che valevano 0.000000 per ogni carattere e nessun
//    test lo diceva).
//  · `gratitudine` — la parte di sopra che è stata fatta PER ME (R_SU_DI_ME).
struct Tinte {
	double ammirazione = 0.0;
	double gratitudine = 0.0;
	double interesse[N_COSE] = { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 };
};

struct TaraturaOcc {
	// mezza giornata di gioco: DayNight.cycle_seconds (240) / 2. Il default
	// vale quel conto ma non lo SOSTITUISCE: quando arriverà il cablaggio
	// (`imposta_ritmo`, Fase 4 passo 4) dovrà DERIVARLA dal ciclo vero, così
	// un villaggio con le giornate lunghe ha ricordi lunghi. Riscrivere 120
	// da qualche altra parte è il modo in cui i due numeri divorziano.
	double mezza_vita = 120.0;
	// quanto pesa una cosa SENTITA invece che vista: è Villaggio.SMORZAMENTO,
	// passato dal chiamante e mai ricopiato. Pinzato in [0,1]: una voce non
	// può MAI pesare più dell'averlo visto con i propri occhi.
	double peso_sentito = 0.55;
	// la saturazione x/(x+k): il ventesimo gesto conta meno del secondo,
	// che è il motivo per cui annaffiare in cerchio non «carica» nessuno.
	double k_satura = 2.0;
	// il +50% dell'autore, LETTERALE. Il tetto vero sullo scarto lo mette
	// `punteggi()` (DELTA_MAX): qui c'è l'intenzione, là la rete.
	double k_ammirazione = 0.50;
};

// OGNI QUANTO SI TORNA A LEGGERE IL PROPRIO CUORE, in secondi.
//
// LE DUE RAGIONI, E SONO MISURATE (l'ho verificato portando questo numero a
// zero, cioè rileggendo a ogni frame, e rifacendo tutte le misure):
//
//  1. **IL COSTO.** 6.000 passi con 28 vicini e i grafi pieni: 22 ms col
//     gradino, 59 ms senza — **2,6 volte tanto**, e per un dato che cambia
//     due volte in sedici secondi. `valuta()` è pura e costa poco, ma
//     ventotto vicini per ventiquattro ricordi fanno 672 `exp2` per frame,
//     e crescono con quanto il giocatore costruisce.
//  2. **LA LEGGIBILITÀ DEL NUMERO.** Dentro un gradino il modulatore è lo
//     STESSO DOUBLE, bit per bit. Una decisione non poggia su un numero che
//     le scivola sotto mentre la si prende, e — cosa che conta almeno
//     altrettanto — un test può misurarlo con `!=` invece che con «circa».
//
// ⚠️ UNA RAGIONE CHE **NON** VALE, ed è meglio scritta che sottintesa: il
// tremolio. Il piano della Fase 4 giustificava il gradino citando i «922
// cambi d'idea al minuto» misurati in Fase 2 — ma quella misura riguarda il
// DADO ritirato a ogni frame (ampiezza 0.25), non il modulatore. Misurato
// qui: col cuore al massimo il villaggio fa 9,60 cambi d'idea al minuto
// contro i 9,20 a cuore spento, e togliendo il gradino **non cambia**
// (`test_ritmo_emozioni._l_emozione_non_fa_tremare` resta verde). La memoria
// inclina il CHE COSA si sceglie — il 75% dei frame sceglie diversamente —
// non il QUANTO SPESSO. Chi un domani volesse togliere il gradino sappia
// che perde quelle due cose lì sopra, non che il villaggio si mette a
// vibrare.
//
// Otto secondi è la stessa scala della finestra di fusione dei ricordi
// (`FINESTRA_FUSIONE`, grafo_ricordi.h): un gesto e le sue ripetizioni
// entrano nel grafo come UNA cosa, e il cuore se ne accorge una volta.
//
// NON è un tetto sulla prontezza: un ricordo NUOVO alza la versione del
// grafo e forza la rivalutazione nello stesso frame. Questo numero governa
// solo quanto in fretta il TEMPO CHE PASSA si fa sentire.
constexpr double PASSO_EMO = 8.0;

// LA LETTURA. Pura e senza memoria: due chiamate con lo stesso grafo e la
// stessa ora danno lo stesso double, bit per bit.
Tinte valuta(const GrafoRicordi &p_grafo, const Gusto &p_gusto, float p_ora,
		const TaraturaOcc &p_tar);

// GLI OTTO MODULATORI, uno per azione, tutti >= 1.0.
//
// Scrive OTTO 1.0 LETTERALI e poi ne muove DUE. Non è pignoleria: con il
// grafo vuoto il vettore dev'essere fatto di 1.0 ESATTI, perché è su quella
// neutralità che poggia la prova di equivalenza dell'agenda (67.200 confronti
// bit-esatti). Un `1.0 + 0.5 * qualcosa_che_dovrebbe_essere_zero` che invece
// vale 1e-17 la farebbe cadere — o peggio, la farebbe passare per un pelo
// oggi e cadere fra sei mesi.
//
// AZ_STELLA è PINNATA a 1.0: il cielo notturno non è una faccenda di
// simpatie. Le altre cinque restano ferme perché la memoria INCLINA, non
// decide (regola 8): un mod è un moltiplicatore sul punteggio, non un veto,
// e non deve poter aprire la corsia d'urgenza.
void modulatori(const Tinte &p_tinte, const TaraturaOcc &p_tar, double r_mod[N_AZIONI]);

} // namespace chibi

#endif // CHIBI_SISTEMA_OCC_H
