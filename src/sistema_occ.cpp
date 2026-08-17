#include "sistema_occ.h"

namespace chibi {

namespace {

// LA SATURAZIONE, x/(x+k), ed è l'unica curva di questo file.
//
// Perché satura e non lineare: il ventesimo gesto deve contare meno del
// secondo. Senza, «fatti guardare mentre annaffi in cerchio» diventerebbe
// un modo di caricare i vicini — cioè il gesto gentile diventa una moneta,
// e in questo gioco la moneta dei legami è un'altra (regola 6).
//
// Le DUE guardie non sono paranoia: sono le sole due strade per cui da qui
// uscirebbe un numero che non è un numero. E un NaN in un modulatore non fa
// fallire niente — fa fallire ogni CONFRONTO, quindi l'argmax dell'agenda
// sceglierebbe sempre la stessa azione e nessuno saprebbe perché.
//  · `!(x > 0.0)` prende lo zero, i negativi E i NaN (ogni confronto con un
//    NaN è falso, quindi la negazione è vera): un NaN in ingresso esce 0.0.
//  · `!(den > x)` prende TRE casi in una riga sola, ed è per questo che è
//    scritta così invece che con tre `if`: una `k` nulla o negativa (una
//    taratura assurda: darebbe una divisione per zero o per un negativo), un
//    x infinito (inf/inf è NaN), e un x così grande che la k gli sparisce
//    dentro nell'arrotondamento. In tutti e tre il limite giusto è 1.0.
// Non c'è una terza guardia che pinza `k`: sarebbe codice morto, perché con
// k <= 0 il denominatore non cresce mai e ci pensa già la riga di sotto. Una
// guardia che nessun ingresso può far scattare è una guardia che nessun test
// può falsificare, cioè una promessa che non si sa se è vera.
inline double satura(double p_x, double p_k) {
	if (!(p_x > 0.0)) {
		return 0.0;
	}
	const double den = p_x + p_k;
	if (!(den > p_x)) {
		return 1.0;
	}
	return p_x / den;
}

} // namespace

Tinte valuta(const GrafoRicordi &p_grafo, const Gusto &p_gusto, float p_ora,
		const TaraturaOcc &p_tar) {
	Tinte t;

	// UNA VOCE NON PUÒ PESARE PIÙ DI UN OCCHIO. `peso_sentito` arriva da
	// Villaggio.SMORZAMENTO (0.55) attraverso il chiamante; pinzarlo in [0,1]
	// qui vuol dire che nessuna taratura futura, di là, può capovolgere la
	// gerarchia fra «l'ho visto» e «me l'hanno detto» — che è la sola cosa
	// che tiene il pettegolezzo un pettegolezzo invece di un megafono.
	//
	// ⚠️ LO SMORZAMENTO SI APPLICA UNA VOLTA SOLA, e questo è l'unico posto
	// che lo sa fare in modo VISIBILE (un test lo misura: un ricordo sentito
	// pesa esattamente `peso_sentito` volte lo stesso ricordo visto). Se
	// `EcsMondo::racconta()` scalerà anche l'INTENSITÀ nel passaggio, allora
	// la smorzatura è già stata pagata e il chiamante deve passare qui
	// `peso_sentito = 1.0`: due applicazioni della stessa costante fanno 0.30
	// invece di 0.55 e non lo dice nessuno. La leva è del chiamante apposta —
	// così la scelta è una riga che si vede, non un default che si eredita.
	double smorza = p_tar.peso_sentito;
	if (!(smorza > 0.0)) {
		smorza = 0.0;
	} else if (smorza > 1.0) {
		smorza = 1.0;
	}

	const int n = (static_cast<int>(p_grafo.n) < MAX_FATTI)
			? static_cast<int>(p_grafo.n)
			: MAX_FATTI;
	for (int i = 0; i < n; i++) {
		// `Ricordo` e non `Fatto`: `chibi::Fatto` è già l'enum delle maschere
		// del mondo in sistema_agenda.h, che questo file include. Lo
		// scostamento dal nome del piano è dichiarato in grafo_ricordi.h.
		const Ricordo &f = p_grafo.f[i];
		// una `cosa` fuori tabella si SALTA. Attribuirla d'ufficio alla prima
		// voce sarebbe peggio che perderla (un fatto sbagliato muove un
		// corpo), e scriverci dentro l'array sarebbe corruzione di memoria.
		if (f.cosa >= N_COSE) {
			continue;
		}
		double w = peso(f, p_ora, p_tar.mezza_vita);
		// UN RICORDO GUASTO NON NE GUASTA ALTRI CINQUE. `!(w > 0.0)` prende
		// zero, negativi e NaN: senza questa riga basterebbe un `quando`
		// corrotto (un NaN si propaga attraverso l'esponenziale) perché TUTTE
		// e sei le tinte di quel vicino diventassero NaN — e da lì in poi ogni
		// confronto sui suoi punteggi sarebbe falso, per sempre, senza un
		// errore. Un ricordo spento non tinge niente: è il degrado giusto.
		if (!(w > 0.0)) {
			continue;
		}
		if ((f.bandiere & R_SENTITO) != 0) {
			w *= smorza;
		}
		// il gusto NEGATIVO non esiste: vedi la regola 4 in sistema_occ.h
		const double g = (p_gusto.per_cosa[f.cosa] > 0.0) ? p_gusto.per_cosa[f.cosa] : 0.0;
		const double q = w * g;
		t.interesse[f.cosa] += q;
		if ((f.bandiere & R_SU_DI_ME) != 0) {
			// `peso()` ha già raddoppiato un fatto che mi riguarda: qui non
			// si raddoppia una seconda volta, si ISOLA la parte che era per
			// me. La gratitudine è una fetta dell'ammirazione, non un
			// secondo conto.
			t.gratitudine += q;
		}
	}

	// L'AMMIRAZIONE È UNA RIDUZIONE, non una terza accumulazione. Sommarla
	// fatto per fatto dentro il ciclo darebbe un double diverso negli ultimi
	// bit (la somma in virgola mobile non è associativa) e nascerebbe la
	// seconda verità sullo stesso numero: un test che confronta le due la
	// vedrebbe «quasi uguale» e la lascerebbe passare per sempre.
	for (int c = 0; c < N_COSE; c++) {
		t.ammirazione += t.interesse[c];
	}
	return t;
}

void modulatori(const Tinte &p_tinte, const TaraturaOcc &p_tar, double r_mod[N_AZIONI]) {
	// OTTO 1.0 LETTERALI, scritti uno per uno e per nome. Un `for` che
	// riempie di 1.0 farebbe la stessa cosa oggi; questi otto nomi invece
	// costringono chi aggiunge una nona azione a passare di qui e a
	// DECIDERE, invece di ereditare un neutro per distrazione.
	r_mod[AZ_SPUNTINO] = 1.0;
	r_mod[AZ_RIPOSO] = 1.0;
	r_mod[AZ_CHIACCHIERE] = 1.0;
	r_mod[AZ_CURA_GIARDINO] = 1.0;
	r_mod[AZ_MERAVIGLIA] = 1.0;
	r_mod[AZ_STELLA] = 1.0; // PINNATA: il cielo non è una faccenda di simpatie
	r_mod[AZ_REGIA] = 1.0;
	r_mod[AZ_GIRONZOLA] = 1.0;

	// il pavimento a 1.0 è STRUTTURALE, non tarato: una `k` negativa
	// renderebbe il mod < 1, cioè «da quando ti ho vista annaffiare ho meno
	// voglia di parlare». Quello è contenuto negativo su una persona, e la
	// regola 4 non lo vieta per gentilezza: senza, la gogna diventa possibile.
	const double k = (p_tar.k_ammirazione > 0.0) ? p_tar.k_ammirazione : 0.0;

	// LE DUE CHE SI MUOVONO.
	//
	// Chiacchiere: quello che ti ho visto fare, e il doppio di quello che hai
	// fatto per me. Non è «ti voglio più bene»: è che ho una cosa da
	// raccontare — e infatti l'uscita è una nuvoletta fra due di LORO.
	r_mod[AZ_CHIACCHIERE] = 1.0 + k * satura(p_tinte.ammirazione + 2.0 * p_tinte.gratitudine, p_tar.k_satura);
	// Giardino: solo i fiori. È la scena 4 — Mochi torna all'orto e trova il
	// proprio gesto, nello stesso punto, fatto da un altro. Il POSTO lo
	// sceglie il GDScript col fatto più pesante; qui c'è solo la voglia.
	r_mod[AZ_CURA_GIARDINO] = 1.0 + k * satura(p_tinte.interesse[C_FIORE], p_tar.k_satura);
}

} // namespace chibi
