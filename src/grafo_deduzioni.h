#ifndef CHIBI_GRAFO_DEDUZIONI_H
#define CHIBI_GRAFO_DEDUZIONI_H

#include <cstdint>

#include "grafo_ricordi.h"
#include "sistema_piani.h" // MASCHERA_PROVVEDIMENTI: i quattro obiettivi veri

// LE DEDUZIONI: il secondo tipo di nodo del grafo, e l'unico che nessuno ha
// visto.
//
// Quinto gemello di sistema_sonno, sistema_agenda, sistema_piani e
// grafo_ricordi: puro. Niente Godot, niente EnTT, niente rng, niente
// allocazioni.
//
// ────────────────────────────────────────────────────────────────────────
// PERCHÉ NON È UN `Ricordo`, e questa è la riga più importante del file
// ────────────────────────────────────────────────────────────────────────
//
// La tentazione era una bandiera in più (`R_DEDOTTO`) su una riga
// dell'anello. Sarebbe stata la cosa peggiore che questa fase potesse fare,
// e per TRE strade indipendenti — nessuna delle quali stampa un errore:
//
//  1. **`da_raccontare()` la prenderebbe.** Un vicino andrebbe a raccontare
//     a un altro una cosa che non è successa, e l'eco la inciderebbe come
//     `R_SENTITO` in un terzo. L'allucinazione, propagata dal sistema che
//     esiste apposta per propagare i fatti veri.
//  2. **`cosa_da_ricordare()` la promuoverebbe.** È l'unica cosa della Fase
//     4 che attraversa un riavvio (`VillagerBrain.remember`): una deduzione
//     di un modello linguistico diventerebbe un ricordo permanente, salvato
//     su disco, in un gioco che dichiara «l'emozione dura minuti e non
//     lascia traccia».
//  3. **`inserisci()` POTA PER PESO.** Una deduzione forte scaccerebbe un
//     ricordo vero — cioè la macchina cancellerebbe quello che il giocatore
//     ha fatto davvero per far posto a quello che si è immaginata. È la
//     domanda esplicita dell'autore («senza che una deduzione possa
//     scacciare un ricordo vero»), e l'unica risposta che non dipende da
//     una taratura è **un altro array**.
//
// Perciò: le osservazioni stanno nell'anello dei ventiquattro, le deduzioni
// in un anello loro da DUE. La potatura per peso, la fusione delle
// ripetizioni e il decadimento in lettura del grafo dei ricordi non vengono
// toccati da una sola riga di questo file — e non possono esserlo, perché
// niente di qui dentro entra là.
//
// ────────────────────────────────────────────────────────────────────────
// UNA DEDUZIONE PORTA LE COPIE DEI SUOI PERCHÉ, NON GLI INDICI
// ────────────────────────────────────────────────────────────────────────
//
// Un indice dentro l'anello è **la stessa trappola dell'handle nudo** che
// `Ricordo.soggetto` ha già pagato: l'anello ricicla gli slot, quindi la
// riga 3 di adesso non è la riga 3 di fra un minuto, e una deduzione che
// puntasse per indice comincerebbe a citare il ricordo di un altro gesto —
// in silenzio, e solo in un villaggio dove il giocatore lavora molto, cioè
// dove nessun collaudo arriva. Là la cura fu la VERSIONE dentro l'handle;
// qui la cura è non avere un puntatore affatto.
//
// La copia non è un secondo orologio, ed è la sola cosa che va verificata
// prima di crederci: conserva il `quando` ORIGINALE e si legge con
// `chibi::peso`, la stessa funzione. Non c'è una seconda formula, non c'è
// una seconda mezza vita, non c'è niente da tenere sincronizzato — è
// esattamente ciò che fa una CITAZIONE dentro una lettera del Gufo, che
// nessuno ricontrolla dopo averla scritta.
//
// IL RESIDUO, dichiarato: una deduzione può sopravvivere al ricordo che l'ha
// prodotta, se quel ricordo viene potato mentre è ancora forte. È il verso
// giusto — **la conclusione sopravvive al dettaglio, mai il contrario** — e
// dura poco comunque, perché la copia decade con lo stesso esponenziale.
//
// ────────────────────────────────────────────────────────────────────────
// COSA NON C'È, e ognuna di queste assenze è un VETO strutturale
// ────────────────────────────────────────────────────────────────────────
//
//  · **nessun soggetto, nessuna persona.** `EcsMondo::deduci()` azzera il
//    `soggetto` delle copie: una deduzione non è mai SU qualcuno. Non è una
//    regola da rispettare, è un campo che non porta più niente — e senza di
//    lui non esiste una classifica fra persone, non esiste un giudizio, e
//    non c'è nessuno da seguire. (Il numero non cambia: `peso()` non guarda
//    il soggetto, guarda `R_SU_DI_ME`, che sta nelle bandiere.)
//  · **nessun testo.** Non c'è un campo stringa, e non ce ne sarà uno: una
//    frase che nessuno ha collaudato, dentro una struttura che il gioco
//    legge, è l'ancoraggio riaperto dalla finestra dopo averlo chiuso dalla
//    porta (vedi `Giudice.CAMPI_DEDUZIONE`).
//  · **nessun obiettivo nuovo.** `obiettivo` è UNA maschera di
//    `chibi::Provvedimento`, e `obiettivo_solo()` pretende che sia un bit
//    solo di quelli. Il pianificatore non impara niente di nuovo: cambia
//    l'ordine in cui gli si chiede.
//  · **nessuna persistenza, nessun rng.** Come il grafo dei ricordi: vive
//    in RAM sull'entità e muore col cervello. Un salvataggio che dipendesse
//    da quello che ha scritto un modello linguistico sarebbe un
//    salvataggio che non si riapre sulla macchina di un altro.

namespace chibi {

// QUANTI RICORDI POSSONO REGGERE UNA DEDUZIONE. Tre, ed è lo stesso numero
// per cui il Suggeritore mostra sei frasi e non ventiquattro: una catena di
// dieci anelli non è più solida, è solo più difficile da leggere — e il
// Giudice la valuta comunque **dall'anello più debole**, quindi citare tutto
// non conviene già adesso.
constexpr int MAX_PERCHE = 3;

// QUANTE DEDUZIONI VIVE PUÒ AVERE UN VICINO. Due, e non è un numero tondo:
// è quante ne può ricevere prima che la prima sia scaduta. Il Pensatoio ne
// consegna UNA per volta in tutto il villaggio e mette a riposo chi l'ha
// ricevuta per cinque minuti (`Pensatoio.RIPOSO`), quindi tre sarebbe uno
// slot che non si riempie mai. Con due, la seconda può arrivare mentre la
// prima aspetta ancora la sua ricevuta.
constexpr int MAX_DEDUZIONI = 2;

// LE DUE BANDIERE, e sono un ordine di cose che deve accadere.
//
//  · `D_RICEVUTA` — la testa si è girata: **il giocatore ha VISTO**. Finché
//    non c'è, la deduzione non produce nessun obiettivo, mai. È la regola
//    della ricevuta scritta in un bit invece che in un commento.
//  · `D_SPESA`    — il piano è già stato consegnato. Una deduzione vale una
//    volta sola: senza questo bit sarebbe una priorità permanente, cioè un
//    vicino inchiodato per sempre a una cosa che si è immaginata. È lo
//    stesso mestiere di `R_DETTO` per i ricordi.
enum BandieraDeduzione : uint8_t {
	D_RICEVUTA = 1u << 0,
	D_SPESA = 1u << 1,
};

// UNA DEDUZIONE.
//
// `bandiere` NON si può passare a `inserisci_deduzione`: la funzione lo
// azzera. **Una deduzione nasce muta**, e nessun chiamante — nemmeno uno
// sbagliato, nemmeno un test — può fabbricarne una che abbia già la sua
// ricevuta in tasca. La regola della ricevuta non è affidata alla
// disciplina di chi chiama.
struct Deduzione {
	Ricordo perche[MAX_PERCHE];
	uint32_t obiettivo = 0; // UNA maschera di chibi::Provvedimento
	float quando = 0.0f;    // quando è nata (secondi di gioco, monotoni)
	float ricevuta = 0.0f;  // quando la testa si è girata (vale con D_RICEVUTA)
	uint8_t n = 0;
	uint8_t bandiere = 0;
};

struct Deduzioni {
	Deduzione d[MAX_DEDUZIONI];
	uint8_t n = 0;
};

// È UN OBIETTIVO VERO? Uno e uno solo dei quattro provvedimenti. Non è una
// formalità: `pianifica()` accetta qualunque maschera, e una maschera con
// due bit accesi chiederebbe al risolutore un obiettivo che nessun operatore
// può soddisfare — cioè un piano vuoto, cioè un vicino che non fa niente e
// nessuno che sappia perché.
bool obiettivo_solo(uint32_t p_obiettivo);

// IL PESO DI UNA DEDUZIONE È QUELLO DEL SUO ANELLO PIÙ DEBOLE.
//
// È la regola che il Giudice applica già alla nascita («una catena vale
// quanto il suo anello più fragile»), fatta vivere NEL TEMPO invece che in
// un istante solo: la deduzione si spegne quando si spegne il primo dei
// ricordi che la reggevano. Chi cita di più non dura di più.
//
// Zero per una deduzione senza perché — che non può esistere, ma la riga
// che lo dice costa un confronto e toglie un modo di sbagliare.
double peso_deduzione(const Deduzione &p_ded, float p_ora, double p_mezza_vita);

// LO STESSO PESO, MA ZERO SE È GIÀ SPESA. Serve alla sola potatura: una
// deduzione consumata non deve poter tenere occupato uno slot davanti a una
// nuova, per quanto forte fosse. Sono due funzioni e non un parametro
// booleano perché hanno due lettori diversi, e un booleano in più sarebbe un
// modo di chiedere la cosa sbagliata.
double peso_utile(const Deduzione &p_ded, float p_ora, double p_mezza_vita);

// QUALE DEI PERCHÉ SI GUARDA: il più PESANTE. È il posto verso cui si gira
// la testa, e dev'essere quello che il giocatore ha più probabilità di
// riconoscere — non il più debole, che è quello con cui si SCEGLIE fra due
// deduzioni. Le due domande sono diverse apposta.
// A parità vince l'indice più basso: nessun dado, mai.
int perche_piu_forte(const Deduzione &p_ded, float p_ora, double p_mezza_vita);

// INSERISCE, e dice di no in sei modi. Torna l'indice, oppure **-1**.
//
//  1. senza perché, o con più di `MAX_PERCHE`: non è una deduzione;
//  2. obiettivo che non è uno dei quattro: vedi `obiettivo_solo`;
//  3. nata già fioca (peso <= `p_soglia`): una deduzione che comincia sotto
//     la soglia sarebbe già scaduta quando arriva la sua ricevuta;
//  4. **LE RIPETIZIONI SI RIFIUTANO, NON SI FONDONO** — ed è l'opposto di
//     quello che fa l'anello dei ricordi, apposta. Sei aiuole annaffiate
//     nello stesso gesto sono lo stesso gesto ancora, e `quante` le conta;
//     concludere due volte la stessa cosa non è concluderla più forte. Se
//     fondesse, un modello che si ripete — ed è il difetto NATURALE dei
//     modelli piccoli, misurato: due incipit su quindici — si costruirebbe
//     da solo un obiettivo inarrestabile. Una deduzione viva col medesimo
//     obiettivo chiude la porta a tutte le sue gemelle;
//  5. anello pieno e la nuova è la più debole: non entra (è la disciplina di
//     `inserisci()`, e per la stessa ragione — si tengono le più forti, non
//     le ultime);
//  6. anello pieno: si pota la più debole PER PESO UTILE, così una spesa
//     esce prima di una viva.
//
// `bandiere` e `quando` li scrive questa funzione, sempre: chi chiama non ha
// modo di antidatare una deduzione né di darle una ricevuta.
int inserisci_deduzione(Deduzioni &r_ded, const Deduzione &p_nuova, float p_ora,
		double p_mezza_vita, double p_soglia);

// QUALE DEDUZIONE ASPETTA ANCORA LA SUA RICEVUTA. -1 = nessuna, ed è il caso
// normale. A parità vince la più forte, poi l'indice più basso.
int deduzione_muta(const Deduzioni &p_ded, float p_ora, double p_mezza_vita,
		double p_soglia);

// QUALE DEDUZIONE PUÒ DIVENTARE UN OBIETTIVO, ADESSO. -1 = nessuna, ed è il
// caso normale (e il caso di SEMPRE, per chi non ha il modello).
//
// LE CINQUE CONDIZIONI, e ognuna si può guastare da sola:
//  · ha la sua ricevuta (`D_RICEVUTA`): il giocatore ha visto la testa
//    girarsi;
//  · **la ricevuta ha avuto il suo tempo** (`p_attesa`): una testa che si
//    gira e un corpo che parte nello stesso frame non sono una premessa e
//    una conseguenza, sono un'unica cosa illeggibile;
//  · **e non ne ha avuto troppo** (`p_finestra`): passata la finestra, la
//    ricevuta non è più in mente a nessuno. Una conseguenza che arriva tre
//    minuti dopo la sua premessa è una conseguenza che il giocatore NON SA
//    ATTRIBUIRE — e questa fase esiste per rendere quella cosa impossibile,
//    non per tararla bene. La deduzione scade e non se ne parla più;
//  · non è già stata spesa;
//  · pesa ancora più della soglia.
//
// I DUE TEMPI ARRIVANO DAL CHIAMANTE, come `p_soglia` in `dove()` e lo
// smorzamento in `racconta()`: quanto dura uno sguardo e ogni quanto
// l'agenda apre una decisione sono cose che sa il gioco, non il motore. Qui
// c'è la regola, di là i numeri, e i numeri di là sono DERIVATI da dove già
// vivono (`Percezione.DURATA_SGUARDO` e `tetto_impegno`).
//
// `p_finestra <= 0` vuol dire «nessuna scadenza»: è il comportamento che
// c'era prima che questa valvola esistesse, ed è così che un test la può
// falsificare.
int deduzione_pronta(const Deduzioni &p_ded, float p_ora, double p_mezza_vita,
		double p_soglia, double p_attesa, double p_finestra);

} // namespace chibi

#endif // CHIBI_GRAFO_DEDUZIONI_H
