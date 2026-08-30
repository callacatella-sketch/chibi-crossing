#include "sistema_sonno.h"

namespace chibi {

bool nottambulo(uint32_t p_indole, int32_t p_quirk) {
	// VillagerBrain.nottambulo(): sognatore, oppure chi canta alla luna.
	return (p_indole & I_SOGNATORE) != 0 || p_quirk == Q_CANTA_ALLA_LUNA;
}

void estremi_finestra(uint32_t p_indole, int32_t p_quirk, double &r_inizio,
		double &r_fine) {
	r_inizio = 0.80;
	r_fine = 0.295;
	// `elif` di là, quindi `else if` di qua: col mattiniero E il
	// dormiglione insieme vince il mattiniero. Non è un dettaglio — è il
	// caso che un test prova apposta.
	if ((p_indole & I_MATTINIERO) != 0) {
		r_fine = 0.262;
	} else if ((p_indole & I_DORMIGLIONE) != 0) {
		r_fine = 0.36;
	}
	if (nottambulo(p_indole, p_quirk)) {
		r_inizio = 0.92;
	}
}

bool finestra_di_sonno(uint32_t p_indole, int32_t p_quirk, double p_ora) {
	double inizio = 0.0;
	double fine = 0.0;
	estremi_finestra(p_indole, p_quirk, inizio, fine);
	return p_ora >= inizio || p_ora < fine;
}

double fase_circadiana(uint32_t p_indole, int32_t p_quirk, double p_ora,
		double p_anticipo) {
	if (finestra_di_sonno(p_indole, p_quirk, p_ora)) {
		return 1.0;
	}
	// Un anticipo nullo (o assurdo) riporta al sì/no: il degrado va verso il
	// comportamento che c'era, mai verso un numero inventato.
	//
	// ⚠️ **La forma negata è per il NaN, e non è pignoleria.** Con
	// `p_anticipo == 0` il conto sotto darebbe zero da sé (`manca >= 0` è
	// sempre vero), quindi contro uno zero questa riga è ridondante — la
	// mutazione che la scrive `p_anticipo >= 1.0` lascia la suite verde.
	// Contro un NaN no: `manca >= NaN` è **falso**, si passa oltre, e si
	// torna `1.0 - manca/NaN`, cioè NaN — che entrerebbe in `neuro` e lì è
	// **assorbente** (`clamp(NaN)` è NaN: quattro canali su sette morti per
	// sempre, già misurato). Un caso di test passa NaN apposta.
	if (!(p_anticipo > 0.0) || p_anticipo >= 1.0) {
		return 0.0;
	}
	double inizio = 0.0;
	double fine = 0.0;
	estremi_finestra(p_indole, p_quirk, inizio, fine);
	// Quanto manca all'inizio.
	//
	// ⚠️ **E NON SERVE RIPORTARLA SUL CERCHIO, e va scritto perché una prima
	// stesura ci aveva messo due `while` di normalizzazione.** Qui ci si
	// arriva solo dopo che `finestra_di_sonno` ha detto di NO, e la finestra
	// è `ora >= inizio || ora < fine`: se fosse `ora > inizio` saremmo già
	// dentro e la funzione sarebbe tornata 1.0 dieci righe sopra. Quindi
	// `p_ora < inizio` **sempre**, e `manca` è positiva e minore di uno per
	// costruzione. I due `while` erano irraggiungibili: MISURATO, la
	// mutazione che li spegneva lasciava la suite completamente verde — cioè
	// erano una guardia che nessun test poteva far fallire, e quelle si
	// tolgono.
	const double manca = inizio - p_ora;
	if (manca >= p_anticipo) {
		return 0.0;
	}
	return 1.0 - manca / p_anticipo;
}

int32_t passo_sonno(int32_t p_stato, bool p_nascosto, bool p_in_finestra,
		bool p_corpo_libero, bool p_porta_aperta) {
	int32_t s = p_stato;

	// 1) RICONCILIAZIONE: il CORPO è la verità.
	// Undici sistemi del villaggio svegliano o nascondono un residente a
	// evento (una promessa da mantenere, il debug, un congedo). Senza
	// questa riga il registro li rimetterebbe a dormire un frame dopo, e
	// il gioco avrebbe due padroni che si contraddicono senza un errore.
	if (s == DORME && !p_nascosto) {
		s = SVEGLIO;
	} else if (s != DORME && p_nascosto) {
		s = DORME;
	}

	// 2) LA NOTTE FUORI FINISCE. Chi una sera non è entrato non deve
	// restare curvo per sempre: fuori dalla finestra si torna svegli, e
	// chi applica toglierà la posa. È un canale orfano chiuso.
	if (!p_in_finestra) {
		return SVEGLIO;
	}

	// 3) dentro la finestra
	if (s == DORME) {
		return DORME;
	}
	// IL CORPO OCCUPATO NON SI STRAPPA VIA. Chi sta suonando al concerto o
	// è seduto in mezzo a una scena non viene spedito a letto. Con la porta
	// aperta la posa della porta chiusa va comunque tolta (→ SVEGLIO); con
	// la porta ancora chiusa si conserva lo stato, così chi era FUORI resta
	// FUORI e si tiene le spalle basse.
	if (!p_corpo_libero) {
		return p_porta_aperta ? SVEGLIO : s;
	}
	return p_porta_aperta ? DORME : FUORI;
}

} // namespace chibi
