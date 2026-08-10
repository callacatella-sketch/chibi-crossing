#ifndef CHIBI_CURVE_UTILITA_H
#define CHIBI_CURVE_UTILITA_H

#include <cstdint>

// LE CURVE DI RISPOSTA (IAUS — Infinite Axis Utility System).
//
// Una considerazione prende un ingresso normalizzato in [0,1] (un bisogno,
// una distanza, un'ora) e lo trasforma in un'utilità in [0,1] con una curva
// parametrica. È la macchina che permette di dire «la stanchezza non conta
// niente finché non conta tutto» invece di scriverlo con un `if`.
//
// TUTTO IN DOUBLE, e non è pignoleria: i float di GDScript SONO double
// IEEE754, e un troncamento a float32 renderebbe impossibile asserire
// l'equivalenza col comportamento di prima — che è l'unica prova che il
// villaggio non è cambiato sotto i piedi del giocatore.
//
// Questo file è PURO: zero Godot, zero EnTT, zero stato globale.

namespace chibi {

enum TipoCurva : int32_t {
	C_COSTANTE = 0,
	C_LINEARE = 1,
	C_QUADRATICA = 2,
	C_LOGISTICA = 3,
	C_LOGIT = 4,
	C_GRADINO = 5,
};

struct Curva {
	int32_t tipo = C_LINEARE;
	double m = 1.0; // pendenza / ampiezza
	double k = 1.0; // esponente (quadratica) o altezza (logistica, gradino)
	double b = 0.0; // spostamento verticale
	double c = 0.0; // spostamento orizzontale (il «centro»)
};

// x viene pinzato in [0,1] PRIMA, y in [0,1] DOPO: una curva non può
// restituire un'utilità fuori scala nemmeno con parametri assurdi, se no
// una considerazione sola potrebbe dominare tutte le altre per un errore
// di taratura invece che per una decisione di progetto.
double valuta(const Curva &p_curva, double p_x);

// IL COMPENSATION FACTOR di Dave Mark. Moltiplicare N considerazioni tutte
// in [0,1] penalizza per costruzione le azioni che ne hanno di più: con
// quattro considerazioni a 0.9 il prodotto è 0.66, e un'azione con una sola
// considerazione a 0.7 vincerebbe pur essendo meno adatta. Questo lo corregge.
//   compensa(p, n) = n <= 1 ? p : p + (1 - p) * (1 - 1/n) * p
// Con n = 2 il guadagno massimo è +0.125, a p = 0.5.
//
// In Fase 2 è SPENTO su tutte le azioni (AzioneDef.compensa = false): con
// il prodotto nudo i punteggi combaciano bit per bit con quelli di prima, ed
// è su quell'uguaglianza esatta che poggia la prova di equivalenza. Accenderlo
// è una scelta di taratura, una azione alla volta, con la misura in mano.
double compensa(double p_prodotto, int p_n);

} // namespace chibi

#endif // CHIBI_CURVE_UTILITA_H
