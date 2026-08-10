#include "sistema_piani.h"

namespace chibi {

namespace {

constexpr uint32_t ALTRE_POSE(uint32_t p_mia) {
	return MASCHERA_POSE & ~p_mia;
}

// LA TABELLA DEGLI OPERATORI. Ogni riga è una frase leggibile: «per
// sgranocchiare devi essere al cespuglio, e ci metti tre secondi e due».
// I trasferimenti hanno costo_base zero perché il loro costo VERO è la
// rotta, che la misura GDScript e passa in `p_cammino`.
const OperatoreDef TAB[N_OPERATORI] = {
	// id, luogo, richiede, vieta, aggiunge, toglie, costo
	{ OP_VAI_CIBO, L_CIBO, F_CIBO | F_CIBO_RAGG, 0,
			A_AL_CIBO, ALTRE_POSE(A_AL_CIBO), 0.0 },
	{ OP_SGRANOCCHIA, L_NESSUNO, A_AL_CIBO, 0,
			A_PROV_PANCINO, 0, 3.2 },

	{ OP_VAI_AIUOLA, L_AIUOLA, F_AIUOLA | F_AIUOLA_RAGG, 0,
			A_ALL_AIUOLA, ALTRE_POSE(A_ALL_AIUOLA), 0.0 },
	// annaffiare TOGLIE l'aiuola assetata dal mondo: è l'unico operatore
	// che cambia un fatto invece di aggiungere una posa, ed è giusto —
	// dopo, quell'aiuola non chiama più nessuno
	{ OP_ANNAFFIA, L_NESSUNO, A_ALL_AIUOLA | F_AIUOLA, 0,
			A_PROV_CURA, F_AIUOLA, 2.6 },

	{ OP_VAI_SEDUTA, L_SEDUTA, F_SEDUTA, 0,
			A_ALLA_SEDUTA, ALTRE_POSE(A_ALLA_SEDUTA), 0.0 },
	{ OP_SIEDI, L_NESSUNO, A_ALLA_SEDUTA, 0,
			A_PROV_ENERGIA, F_SEDUTA, 9.0 },
	// IL PISOLINO PER TERRA: si può SEMPRE, ma è VIETATO se una panchina
	// libera c'è. Non è una precondizione mancante — è una preferenza
	// espressa come divieto, ed è il motivo per cui `F_SEDUTA` non è un
	// gate di AZ_RIPOSO: chi non ha panchina deve poter comunque riposare.
	{ OP_PISOLINO, L_NESSUNO, 0, F_SEDUTA,
			A_PROV_ENERGIA, 0, 12.0 },

	{ OP_VAI_BELLO, L_BELLO, F_MERAVIGLIA_POSTO | F_BELLO_RAGG, 0,
			A_AL_BELLO, ALTRE_POSE(A_AL_BELLO), 0.0 },
	{ OP_INCANTATI, L_NESSUNO, A_AL_BELLO, 0,
			A_PROV_MERAVIGLIA, 0, 4.5 },

	{ OP_VAI_LAVAGNA, L_LAVAGNA, F_LAVAGNA, 0,
			A_ALLA_LAVAGNA, ALTRE_POSE(A_ALLA_LAVAGNA), 0.0 },
	// CHIEDERE, e si può solo se NON ci si arriva da soli. Il divieto è la
	// cosa che rende la scena: finché il cespuglio è raggiungibile nessuno
	// va a scrivere biglietti, e appena il giocatore chiude il recinto
	// quella strada si apre. Costa molto (26.6 s) perché è lenta davvero —
	// la mela arriva quando il giocatore la porta.
	{ OP_CHIEDI_CIBO, L_NESSUNO, A_ALLA_LAVAGNA, F_CIBO_RAGG,
			A_PROV_PANCINO, 0, 26.6 },
	{ OP_CHIEDI_CURA, L_NESSUNO, A_ALLA_LAVAGNA, F_AIUOLA_RAGG,
			A_PROV_CURA, 0, 26.6 },
};

// L'EURISTICA, precalcolata: per ogni bit di obiettivo, il minimo
// `costo_base` fra gli operatori che lo accendono. È ammissibile per
// costruzione — i trasferimenti non accendono mai un provvedimento, e ogni
// cammino costa >= 0 — ma non ci si fida della teoria: un test la verifica
// su tutte le maschere di mondo contro una ricerca esaustiva.
double costo_min_di(uint32_t p_bit) {
	double m = 1.0e300;
	for (int i = 0; i < N_OPERATORI; i++) {
		if ((TAB[i].aggiunge & p_bit) != 0 && TAB[i].costo_base < m) {
			m = TAB[i].costo_base;
		}
	}
	return (m > 1.0e299) ? 0.0 : m;
}

double euristica(uint32_t p_stato, uint32_t p_obiettivo) {
	const uint32_t mancano = p_obiettivo & ~p_stato;
	double h = 0.0;
	for (int b = 24; b < 28; b++) {
		const uint32_t bit = 1u << b;
		if ((mancano & bit) != 0) {
			h += costo_min_di(bit);
		}
	}
	return h;
}

struct Nodo {
	uint32_t stato;
	double g;
	int32_t padre;
	int32_t op;
	int32_t prof;
	bool aperto;
};

} // namespace

const OperatoreDef *operatori() {
	return TAB;
}

EsitoPiano pianifica(uint32_t p_stato, uint32_t p_obiettivo,
		const double p_cammino[N_LUOGHI], const TaraturaPiani &p_tar) {
	EsitoPiano out;

	// l'obiettivo già vero non è un piano vuoto: è una domanda che non
	// andava fatta, e chi chiama deve poterle dare un nome diverso
	if ((p_stato & p_obiettivo) == p_obiettivo) {
		out.esito = PIANO_GIA_VERO;
		return out;
	}

	// ARENA NELLO STACK: 256 nodi. Un pianificatore che alloca durante il
	// frame ogni tanto fa un singhiozzo, e i singhiozzi si vedono.
	Nodo nodi[256];
	const int32_t tetto = (p_tar.max_nodi < 256) ? p_tar.max_nodi : 256;
	int32_t n_nodi = 0;

	nodi[0] = { p_stato, 0.0, -1, OP_NESSUNO, 0, true };
	n_nodi = 1;

	int32_t espansioni = 0;
	int32_t trovato = -1;

	while (true) {
		// FRONTIERA per scansione lineare: con dodici operatori e profondità
		// utile due i nodi veri sono una quindicina, e una scansione batte
		// un heap senza allocare niente.
		int32_t migliore = -1;
		double f_migliore = 1.0e300;
		double g_migliore = -1.0;
		for (int32_t i = 0; i < n_nodi; i++) {
			if (!nodi[i].aperto) {
				continue;
			}
			const double f = nodi[i].g + euristica(nodi[i].stato, p_obiettivo);
			// PAREGGI ROTTI IN MODO DETERMINISTICO: prima f minore, poi g
			// MAGGIORE (più vicino all'obiettivo, meno espansioni), poi
			// l'indice minore — che è l'ordine della tabella.
			if (f < f_migliore - 1.0e-12
					|| (f <= f_migliore + 1.0e-12 && nodi[i].g > g_migliore + 1.0e-12)) {
				f_migliore = f;
				g_migliore = nodi[i].g;
				migliore = i;
			}
		}
		if (migliore < 0) {
			out.esito = PIANO_NIENTE;
			break;
		}
		nodi[migliore].aperto = false;
		espansioni++;

		if ((nodi[migliore].stato & p_obiettivo) == p_obiettivo) {
			trovato = migliore;
			out.esito = PIANO_OK;
			break;
		}
		if (nodi[migliore].prof >= p_tar.max_profondita) {
			continue;
		}

		for (int32_t o = 0; o < N_OPERATORI; o++) {
			const OperatoreDef &d = TAB[o];
			const uint32_t s = nodi[migliore].stato;
			if ((d.richiede & s) != d.richiede) {
				continue;
			}
			if ((d.vieta & s) != 0) {
				continue;
			}
			double costo = d.costo_base;
			if (d.luogo >= 0) {
				const double c = p_cammino[d.luogo];
				// negativo = luogo non disponibile per questo agente: è la
				// doppia sicurezza oltre ai bit di raggiungibilità
				if (c < 0.0) {
					continue;
				}
				costo += c;
			}
			const uint32_t nuovo = (s | d.aggiunge) & ~d.toglie;
			if (nuovo == s) {
				continue; // un operatore che non cambia niente è un cappio
			}
			const double g = nodi[migliore].g + costo;
			if (g > p_tar.budget_secondi) {
				continue; // più lungo del tetto d'impegno: non entra
			}
			// CHIUSA per scansione: se questo stato è già stato raggiunto a
			// costo minore o uguale, non lo si riapre
			bool gia = false;
			for (int32_t i = 0; i < n_nodi; i++) {
				if (nodi[i].stato == nuovo && nodi[i].g <= g + 1.0e-12) {
					gia = true;
					break;
				}
			}
			if (gia) {
				continue;
			}
			if (n_nodi >= tetto) {
				out.esito = PIANO_BUDGET;
				out.nodi = espansioni;
				// MAI un piano parziale: portare il corpo a metà strada e
				// piantarcelo è esattamente il guasto che questa fase deve
				// rendere impossibile
				out.n = 0;
				return out;
			}
			nodi[n_nodi] = { nuovo, g, migliore, o, nodi[migliore].prof + 1, true };
			n_nodi++;
		}
	}

	out.nodi = espansioni;
	if (trovato < 0) {
		out.n = 0;
		return out;
	}
	// si risale al contrario e si rovescia
	int32_t tmp[6];
	int32_t k = 0;
	int32_t cur = trovato;
	while (cur > 0 && k < 6) {
		tmp[k] = nodi[cur].op;
		k++;
		cur = nodi[cur].padre;
	}
	out.n = k;
	out.costo = nodi[trovato].g;
	for (int32_t i = 0; i < k; i++) {
		out.passi[i] = tmp[k - 1 - i];
	}
	return out;
}

} // namespace chibi
