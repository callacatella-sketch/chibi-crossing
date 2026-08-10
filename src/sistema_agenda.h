#ifndef CHIBI_SISTEMA_AGENDA_H
#define CHIBI_SISTEMA_AGENDA_H

#include <cstdint>

#include "curve_utilita.h"

// L'AGENDA: cosa ha voglia di fare un vicino, adesso.
//
// Gemello di sistema_sonno.{h,cpp}: puro, niente Godot, niente rng, niente
// albero della scena. Prende i bisogni, i fatti del mondo e il carattere, e
// torna un punteggio per azione; poi `passo_agenda` decide se vale la pena
// CAMBIARE quel che si sta facendo — che è una domanda diversa, ed è quella
// difficile.
//
// LA REGOLA CHE VIENE PRIMA DI TUTTE: l'agenda TACE se il residente non è
// sveglio. Il sonno è l'unica altra autorità del C++ (Fase 1) e sta SOPRA,
// non accanto: due padroni sullo stesso corpo si combattono a frame alterni
// senza che compaia un errore. Per questo non esiste, e non deve esistere,
// un'«azione vai a letto».

namespace chibi {

enum Azione : int32_t {
	AZ_NESSUNA = -1,
	AZ_SPUNTINO = 0,
	AZ_RIPOSO = 1,
	AZ_CHIACCHIERE = 2,
	AZ_CURA_GIARDINO = 3,
	AZ_MERAVIGLIA = 4,
	AZ_STELLA = 5,
	AZ_REGIA = 6,
	AZ_GIRONZOLA = 7,
	N_AZIONI = 8,
};

// L'ORDINE È IL CONTRATTO con VillagerBrain.needs (scenes/npc/VillagerBrain.gd):
// il ponte passa cinque double nudi, e se l'ordine di là cambia senza che
// cambi qui, ogni vicino comincia a soddisfare il bisogno sbagliato — in
// silenzio. Un test confronta i due elenchi chiave per chiave.
enum Bisogno : int32_t {
	B_PANCINO = 0,
	B_ENERGIA = 1,
	B_COMPAGNIA = 2,
	B_MERAVIGLIA = 3,
	B_CURA = 4,
	N_BISOGNI = 5,
};

// I FATTI del mondo, come maschera di bit. Sono gli stessi sei che oggi
// costruisce Visitors._brain_ctx, più due gate che la Fase 2 aggiunge
// perché un'azione non vinca quando il posto per farla non esiste.
enum Fatto : uint32_t {
	F_MATTINA = 1u << 0,
	F_SERA_STELLATA = 1u << 1,
	F_AIUOLA = 1u << 2,
	F_CIBO = 1u << 3,
	F_AMICO = 1u << 4,
	F_REGISTA = 1u << 5,
	// i due gate nuovi: divergenze DICHIARATE (vedi CLAUDE.md)
	F_MERAVIGLIA_POSTO = 1u << 6,
	F_REGIA_PRONTA = 1u << 7,
};
// F_NOTTAMBULO non esiste apposta: si deriva dal DnaComponent con
// chibi::nottambulo(), così quella frase resta scritta in un posto solo.

enum TipoFattore : int32_t {
	FT_PESO = 0,      // costante
	FT_CURVA = 1,     // curva su un bisogno
	FT_SE_INDOLE = 2, // val se ha l'indole, alt altrimenti
	FT_SE_FATTO = 3,  // val se il fatto è acceso, alt altrimenti
};

struct Fattore {
	int32_t tipo = FT_PESO;
	int32_t ingresso = 0; // indice di Bisogno (solo FT_CURVA)
	uint32_t bit = 0;     // Indole o Fatto
	double val = 1.0;
	double alt = 1.0;
	Curva curva;
};

struct AzioneDef {
	int32_t id = AZ_NESSUNA;
	uint32_t richiede = 0;      // TUTTI accesi, o l'azione è infattibile
	uint32_t bit_pavimento = 0; // il «chiama chiunque»
	double pavimento = 0.0;
	bool usa_compensa = false;
	int32_t n_fattori = 0;
	Fattore fattori[6];
};

// La tabella vive nel .cpp: qui si espone solo in lettura, perché nessuno
// la modifichi a runtime credendo di «tarare».
const AzioneDef *tabella();

// I PUNTEGGI, deterministici: niente rumore, niente argmax. Il rumore vive
// in GDScript (il villaggio salva i suoi dadi, e un secondo generatore in
// C++ sarebbe una seconda storia) e attraversa il ponte già estratto.
//
// I fattori si moltiplicano in ordine STRETTO da sinistra a destra, come li
// scrive il GDScript: è l'unico modo di avere l'uguaglianza esatta invece
// che «circa», perché con gli stessi operandi e la stessa associazione i
// due risultati sono lo stesso double, bit per bit.
void punteggi(const double p_bisogni[N_BISOGNI], uint32_t p_fatti,
		uint32_t p_indole, bool p_nottambulo,
		double r_punti[N_AZIONI], uint32_t *r_fattibile);

// LE TRE LEVE dell'inerzia. I numeri non sono di gusto: vengono dalle
// misure riportate in CLAUDE.md (il tempo d'arrivo più corto misurato con
// un Visitor vero è 2.02 s su 3 m, quindi T_MIN a 2.0 non tronca mai un
// cammino vero).
struct TaraturaAgenda {
	double t_min = 2.0;        // quanto si resta in un'azione, a corpo fermo
	double bonus = 1.08;       // quanto deve battere il concorrente per vincere
	double margine = 0.60;     // sopra questo scarto è un'urgenza: si cambia subito
	double tetto_impegno = 45.0; // se il corpo resta occupato più di così, si ridecide
};

struct EsitoAgenda {
	int32_t azione = AZ_NESSUNA;
	int32_t desiderata = AZ_NESSUNA; // l'argmax, anche quando non si commuta
	double punteggio = 0.0;
	bool cambiata = false; // vero SOLO nel frame del cambio: è il FRONTE
};

// IL PASSO. Puro. `p_corpo_a_riposo` e `p_agenda_zittita` sono FATTI che
// arrivano dal mondo: il corpo che sta camminando o compiendo un gesto non
// si interrompe, e gli undici sistemi a evento (il falò, il congedo, le
// promesse) tengono l'agenda zitta scrivendo il loro lease.
EsitoAgenda passo_agenda(int32_t p_corrente, double p_da, double p_impegno,
		const double p_punti[N_AZIONI], const double p_jitter[N_AZIONI],
		uint32_t p_fattibile, bool p_corpo_a_riposo, bool p_agenda_zittita,
		bool p_sveglio, const TaraturaAgenda &p_tar);

} // namespace chibi

#endif // CHIBI_SISTEMA_AGENDA_H
