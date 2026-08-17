#include "curve_utilita.h"

#include <cmath>

namespace chibi {

namespace {

inline double pinza(double v, double lo, double hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}

} // namespace

double valuta(const Curva &p_curva, double p_x) {
	const double x = pinza(p_x, 0.0, 1.0);
	double y = 0.0;
	switch (p_curva.tipo) {
		case C_COSTANTE:
			y = p_curva.b;
			break;
		case C_LINEARE:
			y = p_curva.m * (x - p_curva.c) + p_curva.b;
			break;
		case C_QUADRATICA: {
			// la base si pinza a >= 0 PRIMA della potenza: pow(negativo,
			// esponente frazionario) è NaN, e un NaN in un punteggio non
			// perde un confronto — lo rende indefinito, e il vicino sceglie
			// a caso senza che niente si lamenti
			const double base = pinza(x - p_curva.c, 0.0, 1.0);
			y = p_curva.m * std::pow(base, p_curva.k) + p_curva.b;
		} break;
		case C_LOGISTICA:
			// il 10 è la pendenza «utile»: con m = 1 la curva passa da 0.1
			// a 0.9 in circa mezzo intervallo, che è la forma che serve per
			// dire «sotto una soglia diventa l'unica cosa che conta»
			y = p_curva.k / (1.0 + std::exp(-10.0 * p_curva.m * (x - p_curva.c))) + p_curva.b;
			break;
		case C_LOGIT: {
			// definita agli estremi grazie al pinzamento: senza, x = 0 dà
			// log(0) = -inf e l'utilità diventa NaN
			const double u = pinza(x - p_curva.c, 0.001, 0.999);
			y = p_curva.m * std::log(u / (1.0 - u)) / 5.0 + 0.5 + p_curva.b;
		} break;
		case C_GRADINO:
			y = (x >= p_curva.c) ? (p_curva.b + p_curva.k) : p_curva.b;
			break;
		default:
			y = 0.0;
			break;
	}
	return pinza(y, 0.0, 1.0);
}

double compensa(double p_prodotto, int p_n) {
	if (p_n <= 1) {
		return p_prodotto;
	}
	const double mod = 1.0 - 1.0 / static_cast<double>(p_n);
	return p_prodotto + (1.0 - p_prodotto) * mod * p_prodotto;
}

} // namespace chibi
