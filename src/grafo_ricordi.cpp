#include "grafo_ricordi.h"

#include <cmath>

namespace chibi {

// LA TABELLA UNICA verbo → cosa. Annaffiare e seminare parlano dello stesso
// fiore; raccogliere e cucinare dello stesso cibo. Sono otto gesti e sei
// cose apposta: quello che resta in mente non è il gesto, è di che cosa si
// stava occupando.
const uint8_t COSA_DEL_VERBO[N_VERBI] = {
	C_FIORE, // V_ANNAFFIA
	C_FIORE, // V_SEMINA
	C_CIBO, // V_RACCOGLIE
	C_CASA, // V_COSTRUISCE
	C_FUOCO, // V_TAGLIA
	C_PESCE, // V_PESCA
	C_CIBO, // V_CUCINA
	C_AMICO, // V_DONA
};

namespace {

// Una mezza vita nulla darebbe 0/0 = NaN, e un NaN in un peso NON fallisce:
// fa fallire ogni confronto. La potatura sceglierebbe sempre la riga zero e
// nessuno se ne accorgerebbe. Si pinza, e il pinzaggio è documentato.
constexpr double MV_MINIMA = 1.0e-6;

} // namespace

double peso(const Ricordo &p_ricordo, float p_ora, double p_mezza_vita) {
	const double mv = (p_mezza_vita > MV_MINIMA) ? p_mezza_vita : MV_MINIMA;

	double dt = static_cast<double>(p_ora) - static_cast<double>(p_ricordo.quando);
	// UN RICORDO DAL FUTURO. Non dovrebbe esistere (il tempo di gioco è
	// monotono e `inserisci` lo timbra da sé), ma se esistesse peserebbe più
	// di uno fresco e continuerebbe a crescere: non lo poterebbe più
	// nessuno, e il grafo si bloccherebbe con la suite verde. Il degrado va
	// verso «è appena successo», mai verso «vale più di tutto».
	if (dt < 0.0) {
		dt = 0.0;
	}

	// le ripetizioni contano poco per volta: sei aiuole valgono 2.25 volte
	// una, non sei. Un pomeriggio in giardino non deve schiacciare tutto il
	// resto di quello che si è fatto.
	const int volte = (p_ricordo.quante >= 1) ? (static_cast<int>(p_ricordo.quante) - 1) : 0;
	const double ripetizioni = 1.0 + 0.25 * static_cast<double>(volte);
	const double a_me = ((p_ricordo.bandiere & R_SU_DI_ME) != 0) ? 2.0 : 1.0;

	return (static_cast<double>(p_ricordo.intensita) / 255.0)
			* std::exp2(-dt / mv) * ripetizioni * a_me;
}

int inserisci(GrafoRicordi &r_grafo, const Ricordo &p_nuovo, float p_ora,
		double p_mezza_vita) {
	// UN VERBO CHE NON ESISTE NON ENTRA. Non lo si pinza a zero: pinzarlo
	// vorrebbe dire inventarsi «annaffia», e la riga sbagliata finirebbe
	// dentro `interesse[cosa]` di sistema_occ — che indicizza un array.
	// Rifiutare è l'unico degrado onesto, e chi chiama lo vede (-1).
	if (p_nuovo.verbo >= N_VERBI) {
		return -1;
	}

	Ricordo r = p_nuovo;
	// `cosa` è una CACHE di COSA_DEL_VERBO, non un secondo dato: si riscrive
	// sempre, così nel grafo non può esistere un ricordo la cui cosa
	// contraddice il suo verbo, nemmeno se chi chiama si sbaglia.
	r.cosa = COSA_DEL_VERBO[r.verbo];
	if (r.quante < 1) {
		r.quante = 1;
	}
	// IL TEMPO LO DECIDE `p_ora`, sempre: un ricordo antidatato non si
	// potrebbe più potare, e ci si arriva senza volerlo (un racconto porta
	// il tempo di chi l'ha visto, non di chi l'ha sentito).
	r.quando = p_ora;

	const int n = (r_grafo.n < MAX_FATTI) ? static_cast<int>(r_grafo.n) : MAX_FATTI;

	// --- 1. LA FUSIONE -------------------------------------------------
	for (int i = 0; i < n; i++) {
		Ricordo &v = r_grafo.f[i];
		if (v.verbo != r.verbo || v.cosa != r.cosa || v.soggetto != r.soggetto) {
			continue;
		}
		if (static_cast<double>(p_ora) - static_cast<double>(v.quando) > FINESTRA_FUSIONE) {
			continue;
		}
		// QUANTE SATURA. Senza, la duecentocinquantaseiesima annaffiatura
		// riporta il contatore a zero e un pomeriggio intero di lavoro pesa
		// meno di un gesto solo — con la suite verde.
		const int somma = static_cast<int>(v.quante) + static_cast<int>(r.quante);
		v.quante = static_cast<uint8_t>(somma > 255 ? 255 : somma);
		if (r.intensita > v.intensita) {
			v.intensita = r.intensita;
		}
		// il ricordo si rinfresca TUTTO: tempo e luogo sono quelli
		// dell'ultima volta. Per la scena dell'aiuola va bene qualunque
		// delle sei, purché sia una vera.
		v.quando = r.quando;
		v.px = r.px;
		v.pz = r.pz;
		// LE BANDIERE SI SOMMANO, con una sola eccezione: vederlo con i
		// propri occhi CANCELLA il sentito dire. Senza quella riga, chi ha
		// prima sentito una voce e poi visto la cosa non potrebbe più
		// raccontarla (`da_raccontare` salta i R_SENTITO) — e il
		// pettegolezzo morirebbe proprio sul testimone giusto.
		uint8_t b = static_cast<uint8_t>(v.bandiere | r.bandiere);
		if ((r.bandiere & R_SENTITO) == 0) {
			b = static_cast<uint8_t>(b & static_cast<uint8_t>(~static_cast<uint8_t>(R_SENTITO)));
		}
		v.bandiere = b;
		r_grafo.versione++;
		return i;
	}

	// --- 2. C'È POSTO ---------------------------------------------------
	if (n < MAX_FATTI) {
		r_grafo.f[n] = r;
		r_grafo.n = static_cast<uint8_t>(n + 1);
		r_grafo.versione++;
		return n;
	}

	// --- 3. L'ANELLO È PIENO: si pota PER PESO, non per età -------------
	// Un ricordo forte sopravvive a ventiquattro tiepidi. La stessa regola
	// vale per il nuovo: se è lui il più debole di tutti, è lui a restare
	// fuori — il grafo tiene i ventiquattro più forti, non gli ultimi
	// ventiquattro.
	int peggiore = 0;
	double p_peggiore = peso(r_grafo.f[0], p_ora, p_mezza_vita);
	for (int i = 1; i < MAX_FATTI; i++) {
		const double p = peso(r_grafo.f[i], p_ora, p_mezza_vita);
		if (p < p_peggiore) { // stretto: a parità vince l'indice più basso
			p_peggiore = p;
			peggiore = i;
		}
	}
	if (p_peggiore > peso(r, p_ora, p_mezza_vita)) {
		// NIENTE SCRITTURA, quindi NIENTE `versione++`: la versione è il
		// latch del modulatore, e farla salire a vuoto vorrebbe dire
		// rivalutare le emozioni per un ricordo che non è entrato.
		return -1;
	}
	r_grafo.f[peggiore] = r;
	r_grafo.versione++;
	return peggiore;
}

int da_raccontare(const GrafoRicordi &p_grafo, float p_ora, double p_mezza_vita,
		uint32_t p_gia_saputi) {
	const int n = (p_grafo.n < MAX_FATTI) ? static_cast<int>(p_grafo.n) : MAX_FATTI;
	int migliore = -1;
	double p_migliore = 0.0;
	for (int i = 0; i < n; i++) {
		const Ricordo &r = p_grafo.f[i];
		// non si racconta quel che si è solo sentito dire (una notizia non è
		// un broadcast: da chi l'ha sentita NON riparte), né quel che si è
		// già raccontato.
		if ((r.bandiere & (R_SENTITO | R_DETTO)) != 0) {
			continue;
		}
		// …né quel che l'altro sa già. Il controllo è sul VERBO e non sulla
		// cosa: chi ha visto annaffiare non ha visto SEMINARE, e sono due
		// notizie diverse anche se parlano tutte e due del giardino.
		// Il `r.verbo < N_VERBI` non è decorativo: la maschera indicizza uno
		// shift, e un verbo fuori tabella (possibile solo da un grafo
		// costruito a mano, cioè da un oracolo di prova) darebbe uno shift
		// oltre la larghezza del tipo — comportamento indefinito, non un
		// errore visibile.
		if (r.verbo < N_VERBI && (p_gia_saputi & (1u << r.verbo)) != 0) {
			continue;
		}
		const double p = peso(r, p_ora, p_mezza_vita);
		// `>` stretto: a parità vince l'indice più basso. Nessun dado, mai.
		if (migliore < 0 || p > p_migliore) {
			p_migliore = p;
			migliore = i;
		}
	}
	return migliore;
}

} // namespace chibi
