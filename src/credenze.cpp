#include "credenze.h"

namespace chibi {

Credenze::Credenze() : n(0) {
	// SI INIZIALIZZA TUTTO, anche quel che sta oltre `n`. Non è pignoleria:
	// zero-inizializzare `chi` lo riempirebbe di 0, che è un handle VALIDO
	// (entità 0, versione 0) — cioè una credenza su una persona vera,
	// fabbricata dall'allocatore. È la stessa trappola dell'handle nudo, un
	// piano più giù. `SOGG_NESSUNO` è l'unico valore che nessuna entità viva
	// può avere.
	for (int k = 0; k < MAX_CONOSCIUTI; k++) {
		chi[k] = SOGG_NESSUNO;
		for (int v = 0; v < N_VERBI; v++) {
			quando[k][v] = CREDENZA_MAI;
		}
	}
}

namespace {

// DOVE STA `p_chi`, o -1. Scansione lineare sull'handle INTERO, mai su un
// hash e mai sui soli venti bit dell'indice: una collisione qui sarebbe una
// credenza su una persona attribuita a un'altra, cioè esattamente la
// creazione di credenze false che questo file esiste per rendere
// impossibile. Ventotto confronti di `uint32_t` in un array contiguo costano
// meno di quanto costi tenere coerente qualunque struttura che li eviti — è
// l'argomento già scritto per i ventiquattro archi del grafo dei ricordi.
inline int cerca(const Credenze &p_c, uint32_t p_chi) {
	const int n = (p_c.n < MAX_CONOSCIUTI) ? static_cast<int>(p_c.n) : MAX_CONOSCIUTI;
	for (int k = 0; k < n; k++) {
		if (p_c.chi[k] == p_chi) {
			return k;
		}
	}
	return -1;
}

} // namespace

void so_che_sa(Credenze &r_c, uint32_t p_chi, uint8_t p_verbo, float p_ora) {
	// «Non so niente di nessuno» non è una persona di cui si possa credere
	// qualcosa, e un verbo fuori tabella non è un verbo. Si rifiuta e basta:
	// il rumore lo fa il ponte, una volta per gesto, non k² volte.
	if (p_chi == SOGG_NESSUNO) {
		return;
	}
	if (p_verbo >= static_cast<uint8_t>(N_VERBI)) {
		return;
	}

	int k = cerca(r_c, p_chi);

	if (k < 0) {
		const int n = (r_c.n < MAX_CONOSCIUTI) ? static_cast<int>(r_c.n) : MAX_CONOSCIUTI;
		if (n < MAX_CONOSCIUTI) {
			k = n;
			r_c.n = static_cast<uint8_t>(n + 1);
		} else {
			// LA POTATURA PER CAPIENZA, e la sceglie IL TEMPO. Cade la voce il
			// cui timbro più recente è il più vecchio: chi è partito non viene
			// mai più rinfrescato da nessuno, quindi affonda da sé mentre
			// tutti gli altri si aggiornano. Non serve — e non deve esistere —
			// una funzione che tolga la voce di una persona scelta a mano.
			k = 0;
			float piu_vecchia = CREDENZA_MAI;
			bool primo = true;
			for (int j = 0; j < MAX_CONOSCIUTI; j++) {
				float recente = CREDENZA_MAI;
				for (int v = 0; v < N_VERBI; v++) {
					if (r_c.quando[j][v] > recente) {
						recente = r_c.quando[j][v];
					}
				}
				if (primo || recente < piu_vecchia) {
					piu_vecchia = recente;
					k = j;
					primo = false;
				}
			}
		}
		// La voce NASCE COMPLETAMENTE IGNORANTE: otto `MAI`. Non eredita un
		// solo bit da chi stava in quello slot prima — che è la stessa cosa
		// che la versione dentro l'handle garantisce un piano più su, detta
		// qui perché nessuno debba dedurla.
		r_c.chi[k] = p_chi;
		for (int v = 0; v < N_VERBI; v++) {
			r_c.quando[k][v] = CREDENZA_MAI;
		}
	}

	// ⚠️ L'UNICA RIGA CHE TOCCA UNA CREDENZA, e va SOLO IN AVANTI. Un timbro
	// che potesse arretrare sarebbe un modo di accorciare una credenza da
	// fuori — l'ombra di quel «non sa» che qui non deve esistere. L'orologio
	// del ponte è monotono e non potrebbe farlo, ma la proprietà è di questa
	// funzione, non del suo unico chiamante di oggi.
	if (p_ora > r_c.quando[k][p_verbo]) {
		r_c.quando[k][p_verbo] = p_ora;
	}
}

uint32_t saputi_di(const Credenze &p_c, uint32_t p_chi, float p_ora,
		double p_durata) {
	if (p_chi == SOGG_NESSUNO) {
		return 0;
	}
	const int k = cerca(p_c, p_chi);
	if (k < 0) {
		// NON LO CONOSCO ⇒ NON CREDO NIENTE ⇒ GLI RACCONTO TUTTO. È il ramo
		// su cui cade anche l'handle riciclato (versione diversa ⇒ nessuna
		// voce combacia), ed è il degrado giusto: il comportamento che il
		// villaggio aveva prima che questa fase esistesse.
		return 0;
	}

	// `!(p_durata > 0.0)` prende lo zero, i negativi E i NaN, come ovunque
	// qui: «non scade» è la convenzione di `p_finestra` e `p_apertura`.
	const bool eterna = !(p_durata > 0.0);

	uint32_t m = 0;
	for (int v = 0; v < N_VERBI; v++) {
		const float q = p_c.quando[k][v];
		// `!(q > MAI)` prende anche un NaN finito lì per qualunque strada:
		// un timbro che non è un tempo non è una credenza.
		if (!(q > CREDENZA_MAI)) {
			continue;
		}
		if (!eterna) {
			const double dt = static_cast<double>(p_ora) - static_cast<double>(q);
			if (!(dt <= p_durata)) {
				continue;
			}
		}
		m |= (1u << v);
	}
	return m;
}

int dimentica_gli_assenti(Credenze &r_c, const uint32_t *p_vivi, int p_n_vivi) {
	// «NON SO CHI È VIVO» NON È «NON È VIVO NESSUNO». Senza l'elenco non si
	// tocca niente: il degrado va verso lo stato di prima, mai verso una
	// spazzata cieca.
	if (p_vivi == nullptr) {
		return 0;
	}

	const int n = (r_c.n < MAX_CONOSCIUTI) ? static_cast<int>(r_c.n) : MAX_CONOSCIUTI;
	int scritte = 0;
	for (int k = 0; k < n; k++) {
		bool vivo = false;
		for (int j = 0; j < p_n_vivi; j++) {
			if (p_vivi[j] == r_c.chi[k]) {
				vivo = true;
				break;
			}
		}
		if (!vivo) {
			continue;
		}
		// si COMPATTA in testa: `cerca` e la potatura scandiscono [0, n), e
		// un buco in mezzo sarebbe una voce viva che nessuno trova più.
		if (scritte != k) {
			r_c.chi[scritte] = r_c.chi[k];
			for (int v = 0; v < N_VERBI; v++) {
				r_c.quando[scritte][v] = r_c.quando[k][v];
			}
		}
		scritte++;
	}

	// la coda si rimette a nuovo: una voce oltre `n` non viene letta, ma una
	// che porta ancora l'handle di un morto sarebbe visibile in un dump di
	// debug e verrebbe letta come una credenza che c'è ancora.
	for (int k = scritte; k < MAX_CONOSCIUTI; k++) {
		r_c.chi[k] = SOGG_NESSUNO;
		for (int v = 0; v < N_VERBI; v++) {
			r_c.quando[k][v] = CREDENZA_MAI;
		}
	}

	const int tolte = n - scritte;
	r_c.n = static_cast<uint8_t>(scritte);
	return tolte;
}

} // namespace chibi
