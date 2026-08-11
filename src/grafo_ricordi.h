#ifndef CHIBI_GRAFO_RICORDI_H
#define CHIBI_GRAFO_RICORDI_H

#include <cstdint>

// IL GRAFO DEI RICORDI: che cosa un vicino ha VISTO fare a Mochi.
//
// Quarto gemello di sistema_sonno, sistema_agenda e sistema_piani: puro.
// Niente Godot, niente EnTT, niente rng, niente allocazioni — l'intero
// grafo di un vicino è un campo di 24 righe dentro il suo componente, e ci
// si passa sopra a scansione lineare. Ventiquattro archi si scandiscono in
// meno tempo di quanto costi tenere coerente un indice, e un indice sarebbe
// una seconda copia da sincronizzare.
//
// COSA NON C'È, e non per dimenticanza:
//  · nessun verbo negativo, e nessuna valenza su una persona. Gli otto
//    verbi sono tutti gesti del ciclo di gioco. Un villaggio che ti guarda
//    storto ogni volta che tagli un albero smette di essere un posto dove
//    si va a stare bene e diventa un ufficio morale — con la suite verde. E
//    senza contenuto negativo su una persona la gogna non è tarata male: è
//    IMPOSSIBILE. (`Voce.gd` resta l'unico canale che porta una parola *su*
//    qualcuno, ed è un verbo del giocatore.)
//  · nessuna persistenza. Il grafo vive in RAM sull'entità come l'handle
//    ECS: nessuna chiave nuova in village.json, nessuna migrazione, nessuna
//    riga scartata in silenzio. L'emozione dura minuti e non lascia traccia
//    — se durasse, il gesto gentile diventerebbe una moneta e si
//    imparerebbe ad annaffiare in cerchio per «caricare» i vicini.
//  · nessun rng. I dadi del villaggio si salvano (Animo._rng): un secondo
//    generatore qui sarebbe una seconda storia che nessun salvataggio
//    racconta. Perciò `da_raccontare()` è DETERMINISTICO fino ai pareggi.
//
// ⚠️ UNO SCOSTAMENTO DICHIARATO DAL PIANO DELLA FASE 4 (§2.1): la struttura
// che il piano chiama `Fatto` qui si chiama **`Ricordo`**. Non è gusto:
// `chibi::Fatto` ESISTE GIÀ ed è l'enum delle maschere del mondo in
// sistema_agenda.h (`F_MATTINA`, `F_AIUOLA`, …). Dichiarare una struct con
// quel nome nello stesso namespace è un errore di compilazione in ogni
// unità che includa tutti e due gli header — e sistema_occ.h li include
// tutti e due. I campi, l'ordine e la dimensione (24 byte) restano quelli
// del contratto: cambia solo il nome del tipo.

namespace chibi {

// GLI OTTO VERBI. Sono i gesti che il giocatore compie e che qualcuno può
// vedere: tutti positivi, tutti del ciclo di gioco.
enum Verbo : uint8_t {
	V_ANNAFFIA = 0,
	V_SEMINA = 1,
	V_RACCOGLIE = 2,
	V_COSTRUISCE = 3,
	V_TAGLIA = 4,
	V_PESCA = 5,
	V_CUCINA = 6,
	V_DONA = 7,
	N_VERBI = 8,
};

// LE COSE CHE SI POSSONO RICORDARE SONO LE COSE CHE SI SANNO DIRE.
// Ogni voce esiste in `Visitor.LP_SIMBOLI`: è un SOTTOINSIEME, non una
// biiezione («pioggia», «felice», «ciao» sono simboli che non sono cose
// fatte da Mochi). Il guasto che questa regola evita è un dato che vive nel
// motore e non arriva mai allo schermo — il TransformComponent di nuovo, ma
// peggio, perché *sembra* funzionare. Aggiungere una cosa ricordabile vuol
// dire, nell'ordine: la parola in Chibiese, il simbolo in LP_SIMBOLI, poi
// la voce qui.
enum Cosa : uint8_t {
	C_FIORE = 0,
	C_CIBO = 1,
	C_CASA = 2,
	C_FUOCO = 3,
	C_PESCE = 4,
	C_AMICO = 5,
	N_COSE = 6,
};

// verbo → cosa, e la tabella è UNA. `Ricordo.cosa` è una cache di questa
// riga, non un secondo dato: `inserisci()` la riscrive sempre, così un
// ricordo con una `cosa` che contraddice il suo verbo non può esistere nel
// grafo nemmeno se chi chiama sbaglia.
extern const uint8_t COSA_DEL_VERBO[N_VERBI];

// LE TRE BANDIERE.
//  · R_SENTITO  — non l'ho visto: me l'hanno detto. Un ricordo sentito non
//                 si ri-racconta (una notizia non è un broadcast) e vale di
//                 meno (lo smorza chi lo passa, vedi la nota su `peso`).
//  · R_SU_DI_ME — l'ha fatto A ME: pesa il doppio. È l'unica asimmetria fra
//                 persone che questo file conosce, e non è un giudizio.
//  · R_DETTO    — l'ho già raccontato a qualcuno: non lo ripeto.
enum Bandiera : uint8_t {
	R_SENTITO = 1u << 0,
	R_SU_DI_ME = 1u << 1,
	R_DETTO = 1u << 2,
};

// Nessun soggetto. Vale `entt::null` come intero: l'handle ECS di EnTT è
// (indice + versione) su 32 bit, e 0xFFFFFFFF è il valore che nessuna
// entità viva può avere.
constexpr uint32_t SOGG_NESSUNO = 0xFFFFFFFFu;

// UN RICORDO — 24 byte, alignof 4.
//
// `soggetto` è l'handle ECS **COMPLETO** (indice + versione), non un indice
// a 8 bit, e questa è la riga più importante della struttura. EnTT ricicla
// gli slot: con un indice nudo, chi arriva la settimana prossima
// erediterebbe l'ammirazione di chi è partito il mese scorso — in silenzio,
// dopo cento giorni, e SOLO in un villaggio che ha avuto partenze, cioè
// dove nessun collaudo arriva. Con la versione, un handle morto non risolve
// e il ricordo degrada a «qualcuno»: il guasto peggiore possibile è
// un'etichetta assente, mai un comportamento sbagliato.
struct Ricordo {
	uint32_t soggetto = SOGG_NESSUNO; // handle ECS completo (indice+versione)
	uint8_t verbo = 0;
	uint8_t cosa = 0;
	uint8_t bandiere = 0;
	uint8_t quante = 1;      // quante volte, dentro la finestra di fusione
	uint8_t intensita = 255; // 0..255: quanto forte è arrivato
	uint8_t _pad = 0;
	float px = 0.0f, pz = 0.0f; // DOVE è successo, in coordinate mondo
	float quando = 0.0f;        // secondi di gioco, monotoni
};

// La struttura attraversa tre piattaforme e due compilatori: se un giorno
// qualcuno allarga un campo, che lo dica il compilatore e non il profiler.
static_assert(sizeof(Ricordo) == 24, "Ricordo deve restare 24 byte");

constexpr int MAX_FATTI = 24;

// LA FINESTRA DI FUSIONE, in secondi. Sei aiuole annaffiate nello stesso
// gesto sono UN ricordo con `quante = 6`, non sei ricordi che riempiono
// l'anello e cancellano tutto il resto — che è il modo esatto in cui un
// giocatore diligente si farebbe dimenticare tutto ciò che ha fatto prima.
constexpr double FINESTRA_FUSIONE = 8.0;

struct GrafoRicordi {
	Ricordo f[MAX_FATTI];
	uint8_t n = 0;
	// Si alza a OGNI SCRITTURA VERA, ed è il latch del modulatore: il mod si
	// ricalcola a gradini (quando la versione cambia, o ogni PASSO_EMO), mai
	// al frame. Un mod continuo reinietterebbe il rumore per-frame che il
	// dado congelato ha tolto — misurato, da 0.2 a 922 cambi d'idea al
	// minuto. Per questo un inserimento RIFIUTATO non la tocca.
	uint32_t versione = 0;
};

// IL PESO DI UN RICORDO, E DECADE IN LETTURA.
//
//   (intensita/255) · 2^(-(ora-quando)/mezza_vita)
//                   · (1 + 0.25·(quante-1))
//                   · (su_di_me ? 2 : 1)
//
// È l'idioma di `Animo._recenza` (scenes/npc/Animo.gd), e non è una
// preferenza di stile: nel dato non deve esistere nessun intero che decade.
// Un `int16 × 0.999994` **torna a sé stesso**, e il grafo diventerebbe
// eterno CON LA SUITE VERDE.
//
// NOTA PER `sistema_occ`: qui NON c'è nessuno sconto per R_SENTITO. Il
// sentito dire si smorza una volta sola, e sta dall'altra parte
// (`TaraturaOcc.peso_sentito`, oppure l'intensità già ridotta al momento
// del racconto). Applicarlo tutti e due i posti lo applicherebbe due volte.
double peso(const Ricordo &p_ricordo, float p_ora, double p_mezza_vita);

// INSERISCE, e fa tre cose in questo ordine:
//  1. FONDE le ripetizioni ravvicinate (stessa terna verbo/cosa/soggetto
//     entro FINESTRA_FUSIONE): `quante++`, e il ricordo si rinfresca tutto
//     (tempo e luogo dell'ultima volta, intensità la massima).
//  2. se c'è posto, appende;
//  3. se l'anello è pieno, POTA PER PESO — non per età. Un ricordo forte
//     sopravvive a ventiquattro tiepidi. E se il più debole di tutti è
//     proprio quello nuovo, il nuovo non entra: il grafo tiene i 24 più
//     forti, non gli ultimi 24.
//
// Torna l'indice della riga scritta, oppure **-1 se non ha scritto niente**
// (verbo fuori tabella, o ricordo più debole di tutti). Chi chiama deve
// poter distinguere i due casi: un ricordo perso in silenzio è esattamente
// ciò che questa firma esiste per rendere visibile.
//
// Il TEMPO di un ricordo lo decide `p_ora`, sempre: chi chiama non ha modo
// di antidatarlo. Un ricordo antidatato non si potrebbe più potare.
int inserisci(GrafoRicordi &r_grafo, const Ricordo &p_nuovo, float p_ora,
		double p_mezza_vita);

// COSA RACCONTEREI, SE ADESSO INCONTRASSI QUALCUNO: il più pesante fra
// quelli che ho visto io (non R_SENTITO) e non ho già raccontato (non
// R_DETTO). A parità vince l'indice più basso: nessun dado, mai.
// -1 = non ho niente da dire, ed è il caso normale.
//
// È una domanda PURA: non marchia niente. R_DETTO lo mette chi racconta
// davvero (EcsMondo::racconta), perché è lì che il racconto ACCADE — la
// stessa regola per cui la sazietà si paga quando il gesto accade.
//
// `p_gia_saputi` è una MASCHERA DI VERBI (bit `v` = «l'altro sa già che
// Mochi fa `v`»); 0 vuol dire «a qualcuno che non sa niente», ed è il
// comportamento di sempre. Non è un ornamento, ed è la differenza fra un
// pettegolezzo e un tappo: in un villaggio dove Mochi annaffia tutti i
// giorni, il ricordo più pesante di TUTTI è «annaffia» — e se la scelta
// non potesse scendere di un gradino, ogni chiacchierata proverebbe a
// raccontare l'unica notizia che sanno già tutti, e le altre non
// uscirebbero mai. La domanda vera non è «cosa racconterei», è «cosa
// racconterei A QUESTA PERSONA», e sta in una funzione sola.
int da_raccontare(const GrafoRicordi &p_grafo, float p_ora, double p_mezza_vita,
		uint32_t p_gia_saputi = 0);

} // namespace chibi

#endif // CHIBI_GRAFO_RICORDI_H
