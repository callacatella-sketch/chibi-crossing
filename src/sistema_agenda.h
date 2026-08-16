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
	// --- FASE 3: la RAGGIUNGIBILITÀ. Si appendono in coda perché
	// l'ordine dei primi otto è un contratto col GDScript (un test li
	// confronta uno a uno).
	// La differenza fra F_CIBO e F_CIBO_RAGG è tutta la Fase 3: il primo
	// dice «un cespuglio c'è», il secondo «e ci si arriva». Finché
	// coincidono non succede niente di nuovo; il giorno che il giocatore
	// chiude un recinto si separano, ed è lì che nasce un piano diverso.
	F_CIBO_RAGG = 1u << 8,
	F_AIUOLA_RAGG = 1u << 9,
	F_SEDUTA = 1u << 10,
	F_BELLO_RAGG = 1u << 11,
	F_LAVAGNA = 1u << 12,
	// --- L'INSIEME: la nozione che l'utility AI non aveva -------------
	// «il posto che sceglierei ha, entro un braccio, qualcuno che ci E'
	// SEDUTO ADESSO». Tre proprieta' strutturali, e nessuna e' tarata:
	//  · e' un POSTO, non un corpo — una seduta non cammina, quindi non
	//    c'e' nessuno da inseguire (la stessa regola di `_ancora_ritrovo`);
	//  · e' un FATTO DEL MONDO, non un'intenzione — chi sta CAMMINANDO
	//    verso una seduta non conta. E' la sola forma che non produce lo
	//    stallo: se contasse anche l'intenzione, due che si dirigono
	//    ciascuno accanto al posto intenzionale dell'altro non
	//    partirebbero mai, e il primo che arriva troverebbe vuoto;
	//  · e' un BOOLEANO, mai un conteggio — «c'e' qualcuno» e «ce ne sono
	//    cinque» valgono lo stesso, quindi un posto che si riempie non
	//    diventa piu' forte: diventa PIENO. Un conteggio sarebbe
	//    preferential attachment, e in poche giornate una legge di potenza
	//    (cioe' il villaggio-grumo).
	F_INSIEME = 1u << 13,
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

// --- FASE 4: IL TETTO SULLO SCARTO ASSOLUTO -----------------------------
//
// Quanto, al massimo, l'emozione può muovere un punteggio. È uno scarto
// ASSOLUTO e non un rapporto, e il numero non è di gusto: `TaraturaAgenda`
// (qui sotto) apre la corsia d'urgenza quando il primo batte il corrente di
// più di `margine` (0.60), e l'urgenza porta il tempo minimo da 2,0 s a
// 0,5 s. Con 0.45 < 0.60 l'emozione, PARTENDO DA UN PAREGGIO, non può mai
// aprire quella corsia da sola: se potesse, un vicino che ti ammira
// cambierebbe idea quattro volte più spesso — per sempre, e senza che
// nessun test se ne accorga, perché tutte le asserzioni sui punteggi
// resterebbero verdi.
//
// Il `+50%` dell'autore resta LETTERALE dove si esprime l'intenzione
// (`sistema_occ.h`, `k_ammirazione`): qui c'è solo la rete.
constexpr double DELTA_MAX = 0.45;

// --- L'INSIEME: I TRE NUMERI DEL RIPOSO, ESTRATTI DALLA RIGA ------------
//
// `riposo` vale (1-energia) · RIPOSO_PESO · (dormiglione ? RIPOSO_DORMIGLIONE
// : 1) · (insieme ? K_INSIEME : 1), ed e' la riga di `costruisci_tabella`
// (case AZ_RIPOSO) letta ad alta voce. Stanno QUI e non la' perche' il
// `static_assert` in fondo a questo file possa leggerli: ricopiarli
// sarebbe una tabella gemella, cioe' un tetto che sorveglia numeri diversi
// da quelli che il villaggio usa davvero.
//
// K_INSIEME e' 1.20 e non e' un valore di gusto: e' MISURATO, appaiato sullo
// stesso contesto (`tools/misura_k_insieme.gd`, 40.960 contesti veri —
// nove caratteri, quattro forme di mondo, i cinque bisogni indipendenti):
//
//   K      decisioni SCAVALCATE   scarto (mediano/max)   urgenze aperte
//   1.10       0.90%                0.1024 / 0.2061           0
//   1.15       3.70%                0.1536 / 0.3091           0
//   1.20       4.62%                0.2048 / 0.4122           0   ←
//   1.25       7.04%                0.2560 / 0.5152           0
//   1.30      11.44%                0.3072 / 0.6182        2048   ⚠️
//
// Quattro decisioni su cento e' una CONSIDERAZIONE: novantasei volte su
// cento il vicino fa quello che avrebbe fatto comunque. Sotto 1.15 il
// termine non muove quasi niente (0,90%, e 1.05 e 1.10 danno lo stesso
// identico conteggio); da 1.30 in su comincia ad APRIRE la corsia
// d'urgenza — che e' esattamente dove il `static_assert` qui sotto ferma
// la build, e le due cose combaciano perche' sono la stessa relazione.
//
// E CHI VIENE SCAVALCATO conta quanto il quanto: a 1.20, delle 1892
// decisioni ribaltate 1562 le toglie a «quattro_chiacchiere» (che e'
// l'azione piu' scelta del villaggio) e SOLO 40 a «cura_giardino» — perche'
// il pavimento dell'aiuola assetata chiama chiunque, e il mondo batte
// l'insieme. Da «stella» e da «regia» non toglie mai niente.
//
// ⚠️ E NEL VILLAGGIO VERO IL TERMINE E' MOLTO PIU' TIMIDO DI COSI', ed e'
// onesto scriverlo qui: su tre giornate di gioco il bit si accende nello
// 0,89% dei campioni (due residenti su tredici), e in quelle 1501
// valutazioni — appaiate sullo stesso istante, col bit e senza — **non ha
// mai cambiato l'argmax**, perche' chi aveva compagnia accanto non era
// stanco. La spazzata qui sopra dice quanto il termine PUO' spostare; il
// villaggio dice quanto spesso gliene capita l'occasione, e quel numero non
// lo alza K: lo alza QUALE seduta viene scelta.
constexpr double RIPOSO_PESO = 1.6;
constexpr double RIPOSO_DORMIGLIONE = 1.4;
constexpr double K_INSIEME = 1.20;

// I PUNTEGGI, deterministici: niente rumore, niente argmax. Il rumore vive
// in GDScript (il villaggio salva i suoi dadi, e un secondo generatore in
// C++ sarebbe una seconda storia) e attraversa il ponte già estratto.
//
// I fattori si moltiplicano in ordine STRETTO da sinistra a destra, come li
// scrive il GDScript: è l'unico modo di avere l'uguaglianza esatta invece
// che «circa», perché con gli stessi operandi e la stessa associazione i
// due risultati sono lo stesso double, bit per bit.
//
// `p_mod` è OBBLIGATORIO e MAI NULLABLE, ed è una decisione di progetto, non
// una svista: con un puntatore nullable la prova di equivalenza (67.200
// confronti bit-esatti) passerebbe dal ramo `nullptr` e NON PROVEREBBE IL
// CODICE NUOVO. È la lezione già pagata due volte in Fase 1 — una prova che
// aggira il codice nuovo non prova niente. Chi non ha emozioni da dichiarare
// passa otto 1.0 letterali, e quegli 1.0 attraversano la moltiplicazione
// come tutti gli altri.
void punteggi(const double p_bisogni[N_BISOGNI], uint32_t p_fatti,
		uint32_t p_indole, bool p_nottambulo, const double p_mod[N_AZIONI],
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

// LA RETE, verificata dal compilatore: se un giorno qualcuno alza DELTA_MAX
// o abbassa il margine, la build non parte. Un test in GDScript lo ripete a
// runtime leggendo ENTRAMBI i numeri dal C++ (mai riscritti a mano di là),
// perché questa relazione è l'unica cosa che tiene l'emozione fuori dalla
// corsia d'urgenza — e una relazione affidata solo alla memoria di chi tara
// è una relazione che prima o poi si rompe in silenzio.
static_assert(DELTA_MAX < TaraturaAgenda{}.margine,
		"DELTA_MAX deve restare sotto il margine d'urgenza: l'emozione INCLINA, non accelera.");

// LA STESSA RETE PER L'INSIEME, e serve una riga sua perche' e' un canale
// DIVERSO: `DELTA_MAX` pinza `p_mod`, cioe' l'emozione, e un fattore di
// TABELLA non ci passa mai. Senza questo assert il tetto dell'insieme non
// esisterebbe affatto — e la prova di equivalenza non potrebbe vederlo, che
// e' cieca al bit 13 per costruzione (la sua spazzata accende solo i sei
// fatti storici).
//
// Lo scarto piu' grande che il fattore puo' produrre e' a energia zero, su
// un dormiglione: 1.0 · 1.6 · 1.4 · (1.20 - 1.0) = 0.448, sotto il margine
// (0.60) oltre il quale il tempo minimo scende da 2,0 s a 0,5 s. Partendo
// da un pareggio, quindi, l'insieme non puo' MAI aprire la corsia
// d'urgenza da solo: INCLINA, non accelera. Il giorno che qualcuno alza il
// peso del riposo per una ragione che con le cricche non c'entra, la build
// NON PARTE — che e' l'unico posto in cui questa relazione puo' essere
// sorvegliata da qualcosa che non dimentica.
static_assert(RIPOSO_PESO * RIPOSO_DORMIGLIONE * (K_INSIEME - 1.0) < TaraturaAgenda{}.margine,
		"K_INSIEME sfonda il margine d'urgenza: l'insieme INCLINA, non accelera.");

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
