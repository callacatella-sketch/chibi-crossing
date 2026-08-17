#include "sistema_sonno.h"

namespace chibi {

bool nottambulo(uint32_t p_indole, int32_t p_quirk) {
	// VillagerBrain.nottambulo(): sognatore, oppure chi canta alla luna.
	return (p_indole & I_SOGNATORE) != 0 || p_quirk == Q_CANTA_ALLA_LUNA;
}

bool finestra_di_sonno(uint32_t p_indole, int32_t p_quirk, double p_ora) {
	double inizio = 0.80;
	double fine = 0.295;
	// `elif` di là, quindi `else if` di qua: col mattiniero E il
	// dormiglione insieme vince il mattiniero. Non è un dettaglio — è il
	// caso che un test prova apposta.
	if ((p_indole & I_MATTINIERO) != 0) {
		fine = 0.262;
	} else if ((p_indole & I_DORMIGLIONE) != 0) {
		fine = 0.36;
	}
	if (nottambulo(p_indole, p_quirk)) {
		inizio = 0.92;
	}
	return p_ora >= inizio || p_ora < fine;
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
