#include "grafo_deduzioni.h"

namespace chibi {

bool obiettivo_solo(uint32_t p_obiettivo) {
	if (p_obiettivo == 0) {
		return false;
	}
	if ((p_obiettivo & MASCHERA_PROVVEDIMENTI) != p_obiettivo) {
		return false;
	}
	// un bit solo: il trucco di sempre, e qui non è un vezzo — con due bit
	// accesi il risolutore cercherebbe uno stato che nessun operatore sa
	// costruire, e tornerebbe PIANO_NIENTE per ragioni che nessuno capirebbe.
	return (p_obiettivo & (p_obiettivo - 1u)) == 0;
}

double peso_deduzione(const Deduzione &p_ded, float p_ora, double p_mezza_vita) {
	const int n = (p_ded.n < MAX_PERCHE) ? static_cast<int>(p_ded.n) : MAX_PERCHE;
	if (n <= 0) {
		return 0.0;
	}
	double minimo = 0.0;
	for (int i = 0; i < n; i++) {
		const double w = peso(p_ded.perche[i], p_ora, p_mezza_vita);
		// `!(w > 0.0)` prende zero, i negativi E il NaN: un perché guasto
		// spegne la deduzione invece di propagare un NaN dentro i confronti
		// di chi la sceglie — dove un NaN non fallisce, VINCE ogni volta che
		// il confronto è scritto al contrario.
		if (!(w > 0.0)) {
			return 0.0;
		}
		if (i == 0 || w < minimo) {
			minimo = w;
		}
	}
	return minimo;
}

double peso_utile(const Deduzione &p_ded, float p_ora, double p_mezza_vita) {
	if ((p_ded.bandiere & D_SPESA) != 0) {
		return 0.0;
	}
	return peso_deduzione(p_ded, p_ora, p_mezza_vita);
}

int perche_piu_forte(const Deduzione &p_ded, float p_ora, double p_mezza_vita) {
	const int n = (p_ded.n < MAX_PERCHE) ? static_cast<int>(p_ded.n) : MAX_PERCHE;
	int scelto = -1;
	double migliore = 0.0;
	for (int i = 0; i < n; i++) {
		const double w = peso(p_ded.perche[i], p_ora, p_mezza_vita);
		if (w > migliore) {
			migliore = w;
			scelto = i;
		}
	}
	return scelto;
}

int inserisci_deduzione(Deduzioni &r_ded, const Deduzione &p_nuova, float p_ora,
		double p_mezza_vita, double p_soglia) {
	const int quanti = (p_nuova.n < MAX_PERCHE) ? static_cast<int>(p_nuova.n) : MAX_PERCHE;
	if (quanti <= 0 || p_nuova.n > MAX_PERCHE) {
		return -1;
	}
	if (!obiettivo_solo(p_nuova.obiettivo)) {
		return -1;
	}

	// LA DEDUZIONE NASCE MUTA, e la nascita è QUI: bandiere a zero, timbro
	// ad adesso. Un chiamante che passasse `D_RICEVUTA` non ottiene una
	// scorciatoia — ottiene una deduzione muta come tutte le altre.
	Deduzione nuova = p_nuova;
	nuova.bandiere = 0;
	nuova.quando = p_ora;
	nuova.ricevuta = 0.0f;

	// `!(x > soglia)` e non `<=`: prende anche il NaN, che altrimenti
	// passerebbe (ogni confronto con un NaN è falso).
	const double forza = peso_deduzione(nuova, p_ora, p_mezza_vita);
	if (!(forza > p_soglia)) {
		return -1;
	}

	const int n = (r_ded.n < MAX_DEDUZIONI) ? static_cast<int>(r_ded.n) : MAX_DEDUZIONI;

	// LE RIPETIZIONI SI RIFIUTANO. Vedi la regola 4 nell'header: una
	// deduzione viva con lo stesso obiettivo chiude la porta alle gemelle.
	// «Viva» vuol dire non spesa e sopra soglia — cioè esattamente le
	// deduzioni che possono ancora produrre qualcosa.
	for (int i = 0; i < n; i++) {
		if (r_ded.d[i].obiettivo != nuova.obiettivo) {
			continue;
		}
		if (peso_utile(r_ded.d[i], p_ora, p_mezza_vita) > p_soglia) {
			return -1;
		}
	}

	if (n < MAX_DEDUZIONI) {
		r_ded.d[n] = nuova;
		r_ded.n = static_cast<uint8_t>(n + 1);
		return n;
	}

	int piu_debole = 0;
	double minimo = peso_utile(r_ded.d[0], p_ora, p_mezza_vita);
	for (int i = 1; i < MAX_DEDUZIONI; i++) {
		const double w = peso_utile(r_ded.d[i], p_ora, p_mezza_vita);
		if (w < minimo) {
			minimo = w;
			piu_debole = i;
		}
	}
	// SE LA PIÙ DEBOLE È PROPRIO LA NUOVA, LA NUOVA NON ENTRA: si tengono le
	// più forti, non le ultime. È la riga di `inserisci()` per i ricordi, e
	// vale qui per la stessa ragione — chi arriva per ultimo non ha diritto
	// di precedenza per il solo fatto di essere arrivato.
	if (!(forza > minimo)) {
		return -1;
	}
	r_ded.d[piu_debole] = nuova;
	return piu_debole;
}

int deduzione_muta(const Deduzioni &p_ded, float p_ora, double p_mezza_vita,
		double p_soglia) {
	const int n = (p_ded.n < MAX_DEDUZIONI) ? static_cast<int>(p_ded.n) : MAX_DEDUZIONI;
	int scelto = -1;
	double migliore = p_soglia;
	if (!(migliore > 0.0)) {
		migliore = 0.0;
	}
	for (int i = 0; i < n; i++) {
		if ((p_ded.d[i].bandiere & D_RICEVUTA) != 0) {
			continue;
		}
		const double w = peso_utile(p_ded.d[i], p_ora, p_mezza_vita);
		if (w > migliore) {
			migliore = w;
			scelto = i;
		}
	}
	return scelto;
}

int deduzione_pronta(const Deduzioni &p_ded, float p_ora, double p_mezza_vita,
		double p_soglia, double p_attesa, double p_finestra) {
	const int n = (p_ded.n < MAX_DEDUZIONI) ? static_cast<int>(p_ded.n) : MAX_DEDUZIONI;
	double attesa = p_attesa;
	// una taratura assurda degrada verso «nessuna attesa», mai verso «nessuna
	// deduzione arriva mai»: il degrado va sempre verso il comportamento che
	// c'era prima che questa valvola esistesse.
	if (!(attesa > 0.0)) {
		attesa = 0.0;
	}
	int scelto = -1;
	double migliore = p_soglia;
	if (!(migliore > 0.0)) {
		migliore = 0.0;
	}
	for (int i = 0; i < n; i++) {
		const Deduzione &d = p_ded.d[i];
		if ((d.bandiere & D_RICEVUTA) == 0) {
			continue;
		}
		const double da = static_cast<double>(p_ora) - static_cast<double>(d.ricevuta);
		if (da < attesa) {
			continue;
		}
		// `p_finestra > 0.0` prima del confronto: senza scadenza (zero,
		// negativa o NaN) si comporta come prima che la valvola esistesse.
		if (p_finestra > 0.0 && da > p_finestra) {
			continue;
		}
		const double w = peso_utile(d, p_ora, p_mezza_vita);
		if (w > migliore) {
			migliore = w;
			scelto = i;
		}
	}
	return scelto;
}

} // namespace chibi
