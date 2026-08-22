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

// GLI ESTREMI della finestra, per chi non gli basta il sì/no.
//
// Non è una seconda tabella: `finestra_di_sonno()` chiama QUESTA, e i tre
// numeri (0.80 / 0.92, 0.295 / 0.262 / 0.36) esistono in un posto solo.
// Serviva perché la melatonina deve sapere QUANTO MANCA alla propria notte,
// non soltanto se ci è già dentro — e ricopiare quei numeri in GDScript
// sarebbe la tabella gemella che questo progetto ha già pagato tre volte.
void estremi_finestra(uint32_t p_indole, int32_t p_quirk, double &r_inizio,
		double &r_fine);

// LA FASE CIRCADIANA: quanto è «la propria notte», adesso. 0 fuori, 1 dentro,
// e una rampa nell'anticipo che precede l'inizio.
//
// ⚠️ **È il segnale ENDOGENO, e la differenza con la luce è tutta qui.** La
// luce è esogena e istantanea: dice che fuori è buio adesso. Questo dice che
// sta arrivando la TUA sera, e la tua non è quella di un altro — la fase è
// quella di `finestra_di_sonno`, cioè il genoma del sonno, che è già
// persistito, già visibile (chi si alza presto lo vedi) ed è perfino il grafo
// sociale del villaggio (le cricche nascono da chi si stanca alla stessa ora).
//
// ⚠️ **E NON DECIDE NIENTE.** È un ingrediente per un canale della chimica,
// non un ingresso di `passo_sonno`: il ciclo sonno/veglia resta l'unica
// autorità, e una seconda autorità sullo stesso canale è il difetto che la
// regola 1 dell'ECS vieta per iscritto.
//
// [param p_anticipo] è quanta parte di giornata prima dell'inizio la rampa
// impiega a salire (0.08 ≈ due ore su ventiquattro). Con 0 la fase è il
// sì/no di `finestra_di_sonno`, cioè il comportamento senza anticipo.
double fase_circadiana(uint32_t p_indole, int32_t p_quirk, double p_ora,
		double p_anticipo);

// IL PASSO. Pura: niente rng, niente stato globale, niente Godot, niente
// albero della scena. Prende lo stato di adesso e i tre fatti, torna lo
// stato dopo.
int32_t passo_sonno(int32_t p_stato, bool p_nascosto, bool p_in_finestra,
		bool p_corpo_libero, bool p_porta_aperta);

} // namespace chibi

#endif // CHIBI_SISTEMA_SONNO_H
