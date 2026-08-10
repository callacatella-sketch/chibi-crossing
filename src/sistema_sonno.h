#ifndef CHIBI_SISTEMA_SONNO_H
#define CHIBI_SISTEMA_SONNO_H

#include <cstdint>

namespace chibi {

enum Stato : int32_t {
	SVEGLIO = 0,
	DORME = 1,
	FUORI = 2,
};

// I bit delle indoli, NELL'ORDINE di VillagerBrain.INDOLI (scenes/npc/
// VillagerBrain.gd). L'ordine qui non è un contratto di salvataggio, ma la
// corrispondenza nome→bit sì: un test la confronta con la tabella GDScript
// chiave per chiave, così aggiungere un'indole di là senza insegnarla di
// qua fa diventare la suite ROSSA invece di far divergere due tabelle in
// silenzio (è già successo, con la scala della ribellione).
enum Indole : uint32_t {
	I_GOLOSO = 1u << 0,
	I_DORMIGLIONE = 1u << 1,
	I_MATTINIERO = 1u << 2,
	I_CHIACCHIERONE = 1u << 3,
	I_TIMIDO = 1u << 4,
	I_SOGNATORE = 1u << 5,
	I_ORDINATO = 1u << 6,
	I_BRONTOLONE = 1u << 7,
};

// Gli indici dei quirk, nell'ordine di VillagerBrain.QUIRKS. Conta davvero:
// `nottambulo()` dipende da `canta_alla_luna`, e chi inserisse un quirk in
// mezzo alla lista renderebbe nottambulo il ballerino.
enum Quirk : int32_t {
	Q_NESSUNO = -1,
	Q_PARLA_AI_FUNGHI = 0,
	Q_PAURA_FARFALLE = 1,
	Q_CANTA_ALLA_LUNA = 2,
	Q_COLLEZIONA_SASSOLINI = 3,
	Q_BALLERINO = 4,
	Q_PISOLINI_OVUNQUE = 5,
};

// VillagerBrain.nottambulo(): resta alzato quando gli altri rientrano.
bool nottambulo(uint32_t p_indole, int32_t p_quirk);

// La finestra del sonno. Era Visitors._sleep_window(), ed è stata CANCELLATA
// di là: adesso vive qui e in nessun altro posto.
//   inizio 0.80, oppure 0.92 per i nottambuli;
//   fine   0.295, 0.262 col mattiniero, 0.36 col dormiglione —
//   e il MATTINIERO VINCE sul dormiglione, perché di là era un `elif`.
// La finestra ATTRAVERSA la mezzanotte: `t >= inizio or t < fine`.
bool finestra_di_sonno(uint32_t p_indole, int32_t p_quirk, double p_ora);

// IL PASSO. Pura: niente rng, niente stato globale, niente Godot, niente
// albero della scena. Prende lo stato di adesso e i tre fatti, torna lo
// stato dopo.
int32_t passo_sonno(int32_t p_stato, bool p_nascosto, bool p_in_finestra,
		bool p_corpo_libero, bool p_porta_aperta);

} // namespace chibi

#endif // CHIBI_SISTEMA_SONNO_H
