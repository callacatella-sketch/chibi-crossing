#include "sistema_agenda.h"

#include "sistema_sonno.h"

namespace chibi {

namespace {

// (1 - bisogno): la curva che tutte e cinque le azioni «di bisogno» usano
// oggi in GDScript. Scritta come LINEARE m=-1 b=1 c=0, perché sia una curva
// vera e non un caso speciale: il giorno che si vuole una logistica al posto
// suo si cambia una riga di tabella, non il motore.
constexpr Curva MENO_UNO = { C_LINEARE, -1.0, 1.0, 1.0, 0.0 };

inline Fattore f_curva(int32_t p_bisogno) {
	Fattore f;
	f.tipo = FT_CURVA;
	f.ingresso = p_bisogno;
	f.curva = MENO_UNO;
	return f;
}

inline Fattore f_peso(double p_v) {
	Fattore f;
	f.tipo = FT_PESO;
	f.val = p_v;
	return f;
}

inline Fattore f_indole(uint32_t p_bit, double p_si, double p_no) {
	Fattore f;
	f.tipo = FT_SE_INDOLE;
	f.bit = p_bit;
	f.val = p_si;
	f.alt = p_no;
	return f;
}

inline Fattore f_fatto(uint32_t p_bit, double p_si, double p_no) {
	Fattore f;
	f.tipo = FT_SE_FATTO;
	f.bit = p_bit;
	f.val = p_si;
	f.alt = p_no;
	return f;
}

AzioneDef costruisci(int32_t p_id, uint32_t p_richiede, uint32_t p_bit_pav,
		double p_pav, int p_n, const Fattore *p_f) {
	AzioneDef d;
	d.id = p_id;
	d.richiede = p_richiede;
	d.bit_pavimento = p_bit_pav;
	d.pavimento = p_pav;
	d.usa_compensa = false; // vedi curve_utilita.h: spento in Fase 2
	d.n_fattori = p_n;
	for (int i = 0; i < p_n && i < 6; i++) {
		d.fattori[i] = p_f[i];
	}
	return d;
}

// LA TABELLA, e ogni riga è la trascrizione di una riga di
// VillagerBrain.choose(). Chi la cambia cambia il comportamento del
// villaggio: si fa una riga per volta, con la misura in mano.
AzioneDef costruisci_tabella(int p_i) {
	switch (p_i) {
		case AZ_SPUNTINO: {
			// (1-pancino) * 2.0 * (goloso ? 1.6 : 1) * (cibo ? 1 : 0.25)
			// Nota: NON è un gate a zero, è un ATTENUATORE — col cibo
			// lontano lo spuntino può ancora vincere se la fame è tanta.
			const Fattore f[] = { f_curva(B_PANCINO), f_peso(2.0),
				f_indole(I_GOLOSO, 1.6, 1.0), f_fatto(F_CIBO, 1.0, 0.25) };
			return costruisci(AZ_SPUNTINO, 0, 0, 0.0, 4, f);
		}
		case AZ_RIPOSO: {
			// (1-energia) * 1.6 * (dormiglione ? 1.4 : 1)
			// L'unica azione che non guarda il mondo: si può sempre.
			const Fattore f[] = { f_curva(B_ENERGIA), f_peso(1.6),
				f_indole(I_DORMIGLIONE, 1.4, 1.0) };
			return costruisci(AZ_RIPOSO, 0, 0, 0.0, 3, f);
		}
		case AZ_CHIACCHIERE: {
			// (1-compagnia) * 1.8 * (chiacchierone ? 1.5 : 1)
			//   * (timido ? 0.6 : 1) * (amico ? 1 : 0)
			// chiacchierone E timido si MOLTIPLICANO (x0.9 insieme): non si
			// escludono, ed è così anche oggi.
			const Fattore f[] = { f_curva(B_COMPAGNIA), f_peso(1.8),
				f_indole(I_CHIACCHIERONE, 1.5, 1.0),
				f_indole(I_TIMIDO, 0.6, 1.0), f_fatto(F_AMICO, 1.0, 0.0) };
			return costruisci(AZ_CHIACCHIERE, F_AMICO, 0, 0.0, 5, f);
		}
		case AZ_CURA_GIARDINO: {
			// (1-cura) * 1.5 * (ordinato ? 1.7 : 1) * (mattina ? 1.4 : 1)
			//   * (aiuola ? 1 : 0), poi PAVIMENTO 0.9 se c'è l'aiuola secca.
			// Il pavimento è il «chiama chiunque»: un'aiuola assetata batte
			// sempre la regia, anche a pancia piena.
			const Fattore f[] = { f_curva(B_CURA), f_peso(1.5),
				f_indole(I_ORDINATO, 1.7, 1.0), f_fatto(F_MATTINA, 1.4, 1.0),
				f_fatto(F_AIUOLA, 1.0, 0.0) };
			return costruisci(AZ_CURA_GIARDINO, F_AIUOLA, F_AIUOLA, 0.9, 5, f);
		}
		case AZ_MERAVIGLIA: {
			// (1-meraviglia) * 1.4 * (sognatore ? 1.6 : 1)
			// F_MERAVIGLIA_POSTO è la divergenza dichiarata: oggi questa
			// azione può vincere anche dove non c'è né stagno né Grande
			// Albero, e la scena cade su «wander» in silenzio.
			const Fattore f[] = { f_curva(B_MERAVIGLIA), f_peso(1.4),
				f_indole(I_SOGNATORE, 1.6, 1.0) };
			return costruisci(AZ_MERAVIGLIA, F_MERAVIGLIA_POSTO, 0, 0.0, 3, f);
		}
		case AZ_STELLA: {
			// 3.0 se sera stellata E nottambulo, altrimenti 0.
			// Il nottambulo NON è un fatto: si deriva dal DNA in punteggi().
			const Fattore f[] = { f_fatto(F_SERA_STELLATA, 3.0, 0.0) };
			return costruisci(AZ_STELLA, F_SERA_STELLATA, 0, 0.0, 1, f);
		}
		case AZ_REGIA: {
			// 0.75 se c'è il Regista. F_REGIA_PRONTA è la seconda divergenza
			// dichiarata: oggi «regia» vince a 0.75 anche quando il Regista
			// non ha ancora un piano per quel residente, e la scena cade su
			// «wander» senza dire niente.
			const Fattore f[] = { f_fatto(F_REGISTA, 0.75, 0.0) };
			return costruisci(AZ_REGIA, F_REGISTA | F_REGIA_PRONTA, 0, 0.0, 1, f);
		}
		default: {
			// GIRONZOLA non è un'azione nuova: è il `do_routine("wander")`
			// su cui oggi si cade in silenzio quando il mondo non offre il
			// posto. Qui smette di essere un ripiego e diventa una scelta
			// dichiarata, sempre fattibile per costruzione — così un vicino
			// senza niente da fare non resta incastrato su un'azione
			// impossibile credendosi giardiniere.
			const Fattore f[] = { f_peso(0.05) };
			return costruisci(AZ_GIRONZOLA, 0, 0, 0.0, 1, f);
		}
	}
}

const AzioneDef TAB[N_AZIONI] = {
	costruisci_tabella(0), costruisci_tabella(1), costruisci_tabella(2),
	costruisci_tabella(3), costruisci_tabella(4), costruisci_tabella(5),
	costruisci_tabella(6), costruisci_tabella(7),
};

} // namespace

const AzioneDef *tabella() {
	return TAB;
}

void punteggi(const double p_bisogni[N_BISOGNI], uint32_t p_fatti,
		uint32_t p_indole, bool p_nottambulo, const double p_mod[N_AZIONI],
		double r_punti[N_AZIONI], uint32_t *r_fattibile) {
	uint32_t fattibile = 0;
	for (int a = 0; a < N_AZIONI; a++) {
		const AzioneDef &def = TAB[a];
		// INFATTIBILE: manca un fatto richiesto. Non è «punteggio zero», è
		// «non si può»: la differenza conta perché un'azione a zero può
		// comunque vincere se tutte le altre sono a zero, e allora il corpo
		// va da nessuna parte.
		const bool ok = (def.richiede & p_fatti) == def.richiede;
		double v = 1.0;
		// moltiplicazione in ordine STRETTO: è il contratto dell'equivalenza
		for (int i = 0; i < def.n_fattori; i++) {
			const Fattore &f = def.fattori[i];
			switch (f.tipo) {
				case FT_PESO:
					v = v * f.val;
					break;
				case FT_CURVA:
					v = v * valuta(f.curva, p_bisogni[f.ingresso]);
					break;
				case FT_SE_INDOLE:
					v = v * (((p_indole & f.bit) != 0) ? f.val : f.alt);
					break;
				case FT_SE_FATTO:
					v = v * (((p_fatti & f.bit) != 0) ? f.val : f.alt);
					break;
				default:
					break;
			}
		}
		// --- FASE 4: L'INNESTO DELL'EMOZIONE ----------------------------
		// Qui, e non altrove. DOPO i fattori (l'emozione inclina un
		// desiderio già formato, non ne inventa uno) e PRIMA del nottambulo,
		// del compensation factor e del pavimento — e ognuna delle tre è una
		// scelta con una conseguenza:
		//
		//  · prima del NOTTAMBULO e prima del COMPENSATION FACTOR: nessuna
		//    simpatia rimette in piedi una stella che il DNA ha spento.
		//    ONESTÀ SULLA MISURA: oggi queste due sono ordini INDIFFERENTI,
		//    e l'ho verificato guastandoli — spostare l'innesto dopo il
		//    nottambulo lascia la suite verde, perché un mod moltiplicativo
		//    non può resuscitare uno zero (0 × qualunque cosa = 0) e
		//    `usa_compensa` è spento su tutte e otto le azioni. L'ordine
		//    scritto qui è quello che resta GIUSTO il giorno che una delle
		//    due cose cambia (un mod additivo, o una riga che accende
		//    `usa_compensa`), non una proprietà che un test sorveglia.
		//  · prima del PAVIMENTO: un'aiuola che secca chiama chiunque, anche
		//    chi ti ama poco. Il mondo batte l'emozione; con l'ordine
		//    rovesciato un vicino tiepido lascerebbe seccare il giardino
		//    perché tu non gli stai simpatica, e il giocatore non avrebbe
		//    nessun modo di capire perché.
		//
		// Lo SCARTO è pinzato in valore ASSOLUTO, non in rapporto: è la rete
		// che tiene l'emozione fuori dalla corsia d'urgenza (vedi DELTA_MAX).
		// Un tetto sul rapporto — «al massimo x1.5» — lascerebbe passare
		// +1.60 su un punteggio da 3.2, cioè quasi il triplo del margine.
		//
		// Il mod NEGATIVO si pinza a zero PRIMA di moltiplicare. Non è
		// prudenza: è la stessa regola per cui `valuta()` pinza il gusto
		// negativo (un'emozione che TOGLIE voglia sarebbe il contenuto
		// negativo che questa fase si vieta). E senza, un mod < 0 porterebbe
		// il punteggio SOTTO ZERO — un punteggio negativo perde qualunque
		// confronto, compreso quello con «non si può fare».
		const double mo = (p_mod[a] > 0.0) ? p_mod[a] : 0.0;
		const double d = v * mo - v;
		v += (d > DELTA_MAX ? DELTA_MAX : (d < -DELTA_MAX ? -DELTA_MAX : d));

		// il nottambulo della stella, derivato dal DNA e non passato come
		// fatto: la frase «chi è nottambulo» vive in sistema_sonno.cpp e in
		// nessun altro posto
		if (a == AZ_STELLA && !p_nottambulo) {
			v = 0.0;
		}
		if (def.usa_compensa) {
			v = compensa(v, def.n_fattori);
		}
		// il pavimento DOPO tutto il resto, come l'override del GDScript
		if (def.bit_pavimento != 0 && (p_fatti & def.bit_pavimento) != 0 && v < def.pavimento) {
			v = def.pavimento;
		}
		r_punti[a] = ok ? v : 0.0;
		if (ok) {
			fattibile |= (1u << a);
		}
	}
	if (r_fattibile != nullptr) {
		*r_fattibile = fattibile;
	}
}

EsitoAgenda passo_agenda(int32_t p_corrente, double p_da, double p_impegno,
		const double p_punti[N_AZIONI], const double p_jitter[N_AZIONI],
		uint32_t p_fattibile, bool p_corpo_a_riposo, bool p_agenda_zittita,
		bool p_sveglio, const TaraturaAgenda &p_tar) {
	EsitoAgenda e;

	// REGOLA ZERO: chi dorme non ha un'agenda. Il sonno è l'altra autorità
	// del C++ e sta SOPRA questa: se qui si decidesse anche da addormentati,
	// al risveglio il corpo riceverebbe un ordine deciso durante la notte.
	if (!p_sveglio) {
		e.azione = AZ_NESSUNA;
		e.desiderata = AZ_NESSUNA;
		e.cambiata = (p_corrente != AZ_NESSUNA);
		return e;
	}

	// l'argmax, sempre calcolato: serve anche quando non si commuta, perché
	// è quello che il gioco mostra come esitazione (si voleva fare una cosa
	// e se ne sta facendo un'altra)
	int32_t best = AZ_NESSUNA;
	double best_v = -1.0e300;
	for (int a = 0; a < N_AZIONI; a++) {
		if ((p_fattibile & (1u << a)) == 0) {
			continue;
		}
		const double v = p_punti[a] + p_jitter[a];
		if (v > best_v) {
			best_v = v;
			best = a;
		}
	}
	e.desiderata = best;
	e.punteggio = (best == AZ_NESSUNA) ? 0.0 : best_v;

	// LE VALVOLE, in ordine di autorità.
	// 1) gli undici sistemi a evento: quando hanno preso il corpo (il falò,
	//    il congedo, una promessa) l'agenda non emette ordini. Il lease è
	//    loro e il C++ non lo buca mai.
	if (p_agenda_zittita) {
		e.azione = p_corrente;
		e.punteggio = 0.0;
		return e;
	}
	// 2) se non si sta facendo niente, si comincia
	if (p_corrente == AZ_NESSUNA) {
		e.azione = best;
		e.cambiata = (best != AZ_NESSUNA);
		return e;
	}
	// 3) IL LUCCHETTO DEL CORPO: mentre cammina o compie il gesto non si
	//    cambia idea. È la stessa frase di passo_sonno («il corpo è la
	//    verità») portata qui, ed è la leva che conta di più: senza, il
	//    residente rilancia il cammino ogni frame e NON ARRIVA MAI —
	//    misurato, 0-1% di azioni portate a termine.
	//    Il tetto è la valvola di sicurezza: se il corpo resta occupato
	//    oltre 45 s, qualcosa si è incastrato e si ridecide comunque.
	if (!p_corpo_a_riposo && p_impegno < p_tar.tetto_impegno) {
		e.azione = p_corrente;
		return e;
	}
	// 4) L'URGENZA passa sopra al tempo minimo: un'aiuola che secca adesso
	//    non aspetta due secondi.
	const double v_corrente = ((p_fattibile & (1u << p_corrente)) != 0)
			? p_punti[p_corrente] + p_jitter[p_corrente]
			: -1.0e300;
	const bool urgente = (best != p_corrente) && (best_v - v_corrente > p_tar.margine);
	// 5) IL TEMPO MINIMO. L'urgenza lo ABBASSA, non lo abolisce, e la
	//    differenza è tutta: un'azione che sazia il proprio bisogno nel
	//    frame in cui viene scelta (oggi lo fanno «riposo» e il falò) si
	//    azzera il punteggio da sola, e da quel momento QUALUNQUE altra
	//    azione sembra urgente. Con l'urgenza che azzerava il tempo minimo
	//    si otteneva un vicino che cambiava idea alla frequenza del frame —
	//    misurato in test_agenda_ritmo, permanenza minima 0.000 s.
	//    Un quarto di T_MIN (0.5 s) resta ben sotto la soglia di prontezza
	//    che si promette (3 s) e mette comunque un pavimento sotto i piedi.
	const double soglia = urgente ? p_tar.t_min * 0.25 : p_tar.t_min;
	if (p_da < soglia) {
		e.azione = p_corrente;
		return e;
	}
	// 6) e comunque il concorrente deve BATTERE, non pareggiare: senza
	//    questo bonus due azioni quasi pari si alternerebbero all'infinito
	//    ogni volta che scade il tempo minimo.
	if (!urgente && best != p_corrente && best_v <= v_corrente * p_tar.bonus) {
		e.azione = p_corrente;
		return e;
	}
	e.azione = best;
	e.cambiata = (best != p_corrente);
	return e;
}

} // namespace chibi
