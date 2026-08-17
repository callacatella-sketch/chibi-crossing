#ifndef CHIBI_LLM_PENSIERI_H
#define CHIBI_LLM_PENSIERI_H

// IL TRADUTTORE DI PENSIERI — il thread che scrive mentre il gioco gira.
//
// Quinto gemello dei sistemi puri (sonno, agenda, piani, occ): niente Godot,
// niente EnTT, niente `entt::registry`, niente `godot::String`. Solo
// `std::string`, `std::thread` e tre atomici. Non è pignoleria di stile — è
// LA garanzia di questa fase, e la si può leggere in due righe:
//
//   ⚠️ IL THREAD NON PUÒ TOCCARE IL MONDO PERCHÉ NON HA IL TIPO PER FARLO.
//
// Non «non lo fa»: non ha modo. Nella coda entrano byte (`std::string`), e i
// byte non hanno un puntatore al registro, non hanno un handle di entità, non
// hanno un `Node`. Un domani in cui qualcuno volesse far leggere al thread il
// grafo dei ricordi dovrebbe prima includere `ecs_mondo.h` qui dentro, e a
// quel punto la revisione lo vede. Una guardia che sta nel TIPO non si può
// dimenticare di controllare.
//
// (Il motivo per cui questa regola è la prima: il villaggio ha UNDICI sistemi
// che impongono stati a evento. Un secondo scrittore concorrente — per giunta
// asincrono, per giunta con un dado dentro — renderebbe il gioco non
// riproducibile, e non ci sarebbe nessun test capace di dirlo. Vedi la regola
// 1 dell'ECS in CLAUDE.md.)
//
// ────────────────────────────────────────────────────────────────────────
// COSA ATTRAVERSA IL PONTE, E IN CHE VERSO
// ────────────────────────────────────────────────────────────────────────
//
//   main  →  thread   `Richiesta`  (prompt + grammatica, PER VALORE)
//   thread → main     `Esito`      (le bozze, PER VALORE)
//
// Il prompt lo monta il thread principale, con `Suggeritore.componi()`, nel
// momento in cui la generazione COMINCIA — non quando la richiesta si mette
// in coda. È la differenza fra un pensiero fresco e un pensiero di due minuti
// fa: la coda porta NOMI, non fogli già scritti (vedi `Pensatoio.gd`). Qui
// dentro arriva sempre e solo un foglio appena scritto.
//
// ────────────────────────────────────────────────────────────────────────
// LO SPEGNIMENTO, e perché ci sono DUE verbi
// ────────────────────────────────────────────────────────────────────────
//
//  · `annulla()` NON BLOCCA MAI. Butta via il lavoro in volo e torna subito.
//    È quello che si chiama al cambio di scena, all'uscita al titolo, quando
//    un vicino se ne va: il frame in cui succede non deve pagare niente.
//  · `chiudi()` blocca, e si paga UNA volta sola (la chiusura del gioco).
//
// Tutti e due si fanno sentire DENTRO llama, non fra una chiamata e l'altra:
//  · durante il caricamento, dalla `progress_callback` (torna false → il
//    caricamento si interrompe a metà di due gigabyte);
//  · durante la generazione, dalla `abort_callback` di `llama_context_params`
//    — che interrompe `llama_decode` A METÀ di un token, non alla fine.
//    Funziona solo sul backend CPU, ed è una delle ragioni per cui questo
//    motore gira sulla CPU (l'altra, misurata, sta in `Config::gpu`).
// Senza quelle due callback lo spegnimento peggiore sarebbe **un token
// intero**, e un token di questo modello su CPU costa fra 0.3 e 0.5 secondi
// (misurato: 3.5 gettoni/s a priorità normale, 2.0 a priorità di fondo, su
// una macchina però molto carica — vedi la nota di consegna). Con le
// callback: `annulla()` misurata a 0.045 ms, cioè non si aspetta niente.

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <deque>
#include <functional>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace chibi {

// Dove sta il motore, adesso. Il gioco non ne ha bisogno per funzionare (è la
// regola della Fase 5: il ramo senza è quello normale), ma un provino sì.
enum class StatoLlm : int {
	SPENTO = 0,  // nessun modello richiesto
	CARICA = 1,  // il thread sta aprendo il .gguf
	PRONTO = 2,  // c'è un modello e non sta facendo niente
	PENSA = 3,   // sta generando
	GUASTO = 4,  // il modello non si è aperto: il gioco continua senza
};

struct Config {
	std::string modello;  // percorso del .gguf
	int n_ctx = 2048;     // finestra: prompt (~700) + generato (~120)
	int n_thread = 0;     // 0 = `n_thread_consigliati()`
	// 0 = normale · 1 = utility · 2 = fondo. Su una macchina a core
	// asimmetrici decide su QUALI core gira il modello.
	//
	// ⚠️ IL DEFAULT È **1**, E LO DECIDE UNA MISURA CHE HA SMENTITO IL MIO
	// ISTINTO. Ero partito da 2 (la QoS di fondo, che su Apple Silicon
	// confina il thread sui core di efficienza) perché sembrava l'unico modo
	// di non far pagare niente al frame. Misurato a blocchi alternati sul
	// MainLevel vero con ventotto residenti, il frame **non se ne accorge in
	// nessuno dei due casi**:
	//     priorità 2 → medio 49.99 contro 50.03 fermo (−0.04 ms), p99 60.45
	//                  contro 60.10, frame oltre il doppio della mediana: 0
	//     priorità 0 → medio 48.14 contro 48.23 fermo (−0.09 ms), p99 56.52
	//                  contro 58.65, frame oltre il doppio della mediana: 0
	// Cioè la priorità di fondo non comprava niente sul frame — e costava
	// moltissimo altrove, perché su macOS la QoS di fondo **strozza anche
	// l'I/O**: aprire il modello è passato da 9 secondi a 12, e su una
	// macchina carica fino a 341. Un giocatore che aspetta cinque minuti il
	// primo pensiero ha un gioco rotto, non un gioco discreto.
	//
	// Perciò 1 (utility): il thread resta di seconda classe per lo
	// scheduler, ma non finisce nel girone dove anche leggere un file è
	// lento. La difesa vera del frame non è la priorità — è `n_thread`
	// (metà dei core, mai tutti) più la coda profonda uno.
	//
	// ⚠️ Le due misure vengono da UNA macchina sola (M1, 4+4 core, 8 GB) e
	// per giunta carica. Su un portatile a due core la difesa dei thread
	// conta di più: chi ci arriva rifaccia `tools/misura_pensieri.gd` prima
	// di alzare questo numero.
	int priorita = 1;
	bool gpu = false;     // ⚠️ vedi la nota qui sotto
	int max_token = 128;  // tetto duro alla lunghezza di UNA bozza
	// ⚠️ `gpu = false` NON è una dimenticanza, ed è MISURATO. Con i pesi su
	// Metal, e il gioco acceso, la generazione perde metà della sua velocità
	// (gemma-4-E2B: 14.5 → 9.6 tok/s; llama-3.2-3B: 15.0 → 7.6) perché il
	// modello e il renderer si contendono la stessa GPU — cioè il gioco paga
	// PER FRAME il fatto che un vicino stia pensando. Sulla CPU il costo si
	// paga sui core che avanzano, e il frame non se ne accorge (la tabella sta
	// nella nota di consegna). In più `abort_callback` funziona solo sulla
	// CPU: con Metal, lo spegnimento pulito non esisterebbe.

	// ── IL PORTIERE (vedi `llm_gguf.h`) ──────────────────────────────────
	// `tetto_byte` è il tetto di RAM dell'autore: se i pesi più la cache a
	// `n_ctx` gettoni lo sfondano, il modello non si apre nemmeno — e lo si
	// dice col numero, prima di allocare. Zero = nessun tetto (i banchi di
	// prova, che misurano proprio quanto costa un modello troppo grande).
	//
	// ⚠️ TRE GIGABYTE DAL 2026-08-12, E LO DECIDE L'AUTORE. Erano due, e due
	// non bastavano: sotto quel tetto, con questa quantizzazione, ci stava
	// solo un modello da un miliardo di parametri — e col 1B ventuno lettere
	// su ventiquattro erano rotte. A 3072 MB ci stanno i due modelli che il
	// provino aveva trovato ONESTI (zero invenzioni su quindici):
	// gemma-3-4b (2640 MB stimati a 2048 gettoni) e gemma-4-E2B (2835).
	// Il tetto non è l'unica difesa: da solo direbbe «questo modello costa
	// meno di tre giga» anche su una macchina che di giga liberi ne ha uno.
	// L'altra metà è `riserva_byte`, qui sotto.
	uint64_t tetto_byte = 3ull * 1024 * 1024 * 1024;

	// ── E QUANTA RAM DEVE RESTARE ALLA MACCHINA ──────────────────────────
	//
	// Il tetto è una domanda sul MODELLO; questa è la domanda sul PC di chi
	// gioca, e non si può rispondere con una costante: la stessa build gira
	// su un Mac da 8 GB con due browser aperti e su un fisso da 32 GB con
	// niente. Se dopo aver caricato il modello alla macchina resterebbe meno
	// di questo, il modello NON si apre: la funzione si spegne da sola invece
	// di mandare in swap il gioco del giocatore — che è il contrario della
	// regola della Fase 5 («il gioco funziona identico senza»).
	//
	// Il numero non è a occhio, è quello che il gioco ANCORA CHIEDERÀ dopo
	// che il modello è aperto, misurato su questa macchina:
	//   · il MainLevel con ventotto residenti costa ~700 MB, e il modello si
	//     apre PRIMA che il mondo esista (dal titolo, o appena entrati);
	//   · la cache di attenzione cresce generando e non torna indietro
	//     (misurati +166 MB su gemma-3-1b dopo cinque bozze).
	// Un gigabyte è la somma di quei due, arrotondata in su. Zero = non si
	// guarda: i banchi di prova, che devono poter misurare anche il modello
	// che il gioco rifiuterebbe.
	uint64_t riserva_byte = 1024ull * 1024 * 1024;
	// Se non è vuota, il file deve avere ESATTAMENTE questa impronta
	// SHA-256. È l'unica difesa vera contro il residuo dichiarato in
	// `llm_gguf.h`: un modello che il gioco ha già collaudato non può
	// cambiare sotto i piedi senza cambiare impronta. Costa una lettura
	// completa del file (misurata nella sonda), e sta sul thread.
	std::string impronta_attesa;
	// Il portiere non si spegne dal gioco, e non c'è una leva per farlo:
	// una leva che salta un controllo di sicurezza prima o poi la trova
	// qualcuno acceso. Chi deve misurare cosa fa llama.cpp SENZA portiere
	// (ed è così che si è capito quali guasti abortiscono) usa un
	// eseguibile a parte, in un processo suo, dove un abort non porta via
	// niente: `tools/portiere_vs_llama.cpp`.
	bool valida = true;
};

// Una richiesta. Il `biglietto` lo dà `accoda()` e serve a una cosa sola:
// riconoscere un esito che appartiene a un giro precedente (dopo un
// `annulla()`, dopo un cambio di scena, dopo che quel vicino se n'è andato).
// `chi` è opaco per il traduttore: lo porta a spasso e lo restituisce.
struct Richiesta {
	int64_t chi = -1;
	// Le due metà del prompt arrivano SEPARATE (`Suggeritore.parti()`) perché
	// è il C++ a sapere quale modello è aperto, e quindi a sapere come si
	// scrive un messaggio di sistema per LUI (`llama_chat_apply_template`).
	// Un prompt già montato in GDScript sarebbe una seconda tabella di
	// template di chat, da tenere allineata a mano al file .gguf.
	std::string sistema;
	std::string utente;
	// ⚠️ LA GRAMMATICA NON È FACOLTATIVA, ed è la sola ragione per cui questa
	// fase può stare in un gioco. MISURATO su 184 generazioni: con la
	// grammatica accesa, zero citazioni false su 92; senza, il 27%. Perciò
	// una richiesta senza grammatica viene RIFIUTATA da `accoda()` — non
	// «sconsigliata»: rifiutata. Il degrado è il silenzio, che è il
	// comportamento normale del gioco.
	std::string grammatica;  // GBNF, obbligatoria
	int copie = 1;
	int max_token = 0;  // 0 = quello della Config
	float temperatura = 0.8f;
	float top_p = 0.9f;
	float penalita_ripetizione = 1.05f;
	uint32_t seme = 0;  // 0 = seme dal dado del chiamante (mai da qui dentro)
};

struct Esito {
	uint64_t biglietto = 0;
	int64_t chi = -1;
	std::vector<std::string> bozze;
	double secondi_prompt = 0.0;
	double secondi_generazione = 0.0;
	int token_prompt = 0;
	int token_generati = 0;
	// Quante volte il prompt è stato RILETTO invece di riavvolto. Zero è la
	// via veloce (una lettura sola per N bozze); più di zero vuol dire che
	// questo modello non sa riavvolgere la sua memoria di attenzione e le
	// copie costano un prompt l'una. Non è un errore — è un prezzo, e un
	// prezzo che nessuno misura è un prezzo che si paga per sempre.
	int riletture_prompt = 0;
	std::string errore;  // vuoto = tutto bene
};

// Quanti thread dare a llama.cpp. Non è `hardware_concurrency()`, e la
// ragione è tutta qui: il gioco ha bisogno dei suoi core. Su una macchina a
// core asimmetrici (Apple Silicon: 4 prestazione + 4 efficienza) il conto
// giusto è «quelli che restano», e il resto lo fa la priorità di fondo.
int n_thread_consigliati();

// SI STA ABBANDONANDO UNA GENERAZIONE ADESSO?
//
// Serve a UNA cosa sola, e non è cosmetica: quando `abort_callback` ferma
// `llama_decode` a metà, llama.cpp lo racconta con tre righe di ERRORE
// («graph_compute … failed», «process_ubatch: failed to compute graph»,
// «llama_decode: failed to decode, ret = 2»). Ma in questo gioco un decode
// abbandonato è un evento NORMALE — succede a ogni cambio di scena, a ogni
// ritorno al titolo, a ogni chiusura — e quelle righe finirebbero fra gli
// errori veri di Godot. In un progetto che conta gli `SCRIPT ERROR` e
// pretende zero, tre errori per ogni cambio di scena vogliono dire che quel
// conteggio smette di significare qualcosa: cioè la rete di sicurezza si
// rompe, non il gioco.
//
// La legge chi dirotta i log di llama (`llm_ponte.cpp`), e finché è vera
// quelle righe scendono al livello di avviso.
bool abbandono_in_corso();

class Traduttore {
public:
	Traduttore();
	~Traduttore();

	Traduttore(const Traduttore &) = delete;
	Traduttore &operator=(const Traduttore &) = delete;

	// Accende il thread e gli chiede di aprire il modello. TORNA SUBITO, ed è
	// obbligatorio: aprire due gigabyte è costato fra 12 e 84 SECONDI nelle
	// misure (dipende dal carico e dalla priorità — la QoS di fondo su macOS
	// rallenta anche l'I/O, non solo il calcolo). Nel frame di chi chiama
	// sarebbero da settecento a cinquemila frame persi. Chi vuole sapere se è
	// pronto guarda `stato()`; nel frattempo il gioco usa i testi scritti a
	// mano, che è quello che fa sempre.
	bool apri(const Config &p_config);

	// Le tre letture del frame. Sono SENZA LOCK (solo atomici rilassati):
	// il thread principale le può chiamare sessanta volte al secondo senza
	// mai avere la possibilità di aspettare il thread che pensa.
	StatoLlm stato() const { return _stato.load(std::memory_order_relaxed); }
	bool pronto() const { return stato() == StatoLlm::PRONTO || stato() == StatoLlm::PENSA; }
	bool libero() const { return stato() == StatoLlm::PRONTO && !_in_volo.load(std::memory_order_relaxed); }
	// Frazione del caricamento, 0..1 — solo per un provino.
	float caricamento() const { return _caricamento.load(std::memory_order_relaxed); }

	// Mette in coda UN pensiero. Torna il biglietto, oppure 0 se il motore non
	// è pronto o la coda è piena. **La coda è profonda uno**: un pensiero alla
	// volta, in tutto il villaggio. Non è una limitazione tecnica — è la
	// cadenza (vedi `Pensatoio.gd`): due generazioni insieme su quattro core
	// non vanno il doppio, vanno la metà ciascuna, e nel frattempo il gioco
	// resta senza core.
	uint64_t accoda(Richiesta p_richiesta);

	// Ritira un esito, se c'è. NON BLOCCA MAI, e nel caso normale (niente da
	// ritirare) è UN atomico: si chiama a ogni frame senza pensarci.
	bool raccogli(Esito &r_esito);

	// Butta il lavoro in volo. Non blocca: il thread se ne accorge dentro
	// llama e molla lì. L'esito, se arriva, porta un biglietto vecchio.
	void annulla();

	// Ferma il thread e libera il modello. Bloccante, idempotente, e la
	// chiama anche il distruttore: nessun thread può sopravvivere all'oggetto.
	void chiudi();

	// --- misure (per i provini e per la nota di consegna) ----------------
	uint64_t quanti_pensieri() const { return _fatti.load(std::memory_order_relaxed); }
	uint64_t quanti_annullati() const { return _buttati.load(std::memory_order_relaxed); }
	double secondi_caricamento() const { return _sec_caricamento.load(std::memory_order_relaxed); }
	std::string diagnosi() const;

	// ─────────────────────────────────────────────────────────────────────
	// IL BANCO — un lavoro FINTO, per provare la concorrenza SENZA modello
	// ─────────────────────────────────────────────────────────────────────
	//
	// ⚠️ ESISTE PER UNA RAGIONE SOLA, E NON È COMODITÀ: la corsa fra
	// `annulla()` e chi scrive è il posto in cui questo file ha già
	// ammutolito il villaggio PER SEMPRE (vedi la nota in `annulla()`), e
	// l'unico giudice che aveva era `tools/prova_concorrenza.cpp` — che
	// vuole due gigabyte di pesi, un eseguibile a parte, e non gira in
	// nessuna suite. Cioè: le due righe che riparano quel guasto si
	// potevano togliere tutte e due lasciando la suite completamente verde.
	// MISURATO, togliendole una per volta: 63942 passati, 0 falliti.
	//
	// COSA È FINTO E COSA NO. Finto è **il lavoro**: qui non si apre nessun
	// `.gguf`, non si chiama llama, non si genera un gettone — il testo
	// dell'esito lo passa chi chiama, perché un motore che si inventa le
	// parole sarebbe la cosa più pericolosa che questo file possa avere.
	// Vero è **tutto il resto**: `accoda()`, `annulla()`, il prologo di chi
	// scrive (`_prendi_lavoro`) e il suo epilogo (`_epilogo`) sono le
	// funzioni di produzione, chiamate dagli stessi posti, sotto lo stesso
	// lucchetto. È l'opposto di un doppio: invece di reimplementare la cosa
	// da provare, si toglie di mezzo la cosa che non c'entra.
	//
	// E NON C'È NESSUN THREAD. Il difetto non è di tempistica — è una
	// transizione di stato che nessuno gestiva; il tempo decideva solo
	// quanto spesso ci si cascava. Muovendo il lavoro a mano, la finestra
	// che nel gioco vero dura decine di microsecondi qui dura quanto pare a
	// chi prova, e il caso è DETERMINISTICO invece che probabile.
	//
	// NEL GIOCO NON LO CHIAMA NESSUNO: `banco_accendi()` rifiuta se il
	// traduttore è già acceso, e `test_llm_banco.gd` scandaglia i sorgenti
	// di `scenes/` e `systems/` per tenere chiusa quella porta.

	// Mette il traduttore in PRONTO senza modello e senza thread. `false` se
	// c'è già un motore acceso (o se `chiudi()` l'ha spento): il banco non
	// scavalca mai un traduttore vivo.
	bool banco_accendi();
	// Il PROLOGO di chi scrive: toglie la richiesta dalla coda ed è
	// l'istante in cui il lavoro diventa suo. `false` se la coda è vuota.
	bool banco_prendi();
	// E il suo EPILOGO, con la bozza che chi prova ha deciso. Bozza vuota =
	// una generazione che non ha prodotto niente (un errore del motore), che
	// è un caso vero e va consegnato lo stesso — vedi la nota nell'epilogo.
	void banco_finisci(const std::string &p_bozza);
	// «Chi scrive ha un lavoro in mano?» (= `_preso`, sotto il lucchetto).
	bool banco_in_mano() const;
	// LA DOMANDA CHE LLAMA FA A OGNI NODO DEL GRAFO: `abort_callback`
	// chiede esattamente questo, ed è l'unico modo in cui un `annulla()`
	// arriva dentro una generazione. Un banco che non la potesse leggere
	// non saprebbe distinguere «annullato» da «non annullato».
	bool banco_deve_smettere() const { return _molla(); }

private:
	struct Motore;  // PIMPL: llama.h vive SOLO dentro llm_pensieri.cpp

	void _ciclo();                       // il corpo del thread
	bool _carica();                      // apre il .gguf (sul thread)
	void _genera(const Richiesta &, Esito &);
	// IL PROLOGO E L'EPILOGO DI CHI SCRIVE, in due funzioni loro. Non è
	// un abbellimento: hanno DUE chiamanti (il thread e il banco), e
	// ricopiarli vorrebbe dire provare una seconda implementazione — il
	// doppio che mente, che in questo progetto ha già coperto per mesi il
	// difetto che queste righe riparano.
	//
	// `_prendi_lavoro` PRESUPPONE IL LUCCHETTO PRESO da chi chiama: deve
	// stare nello stesso tratto in cui si è verificato che la coda non è
	// vuota, o fra le due cose ci ricasca `annulla()`.
	bool _prendi_lavoro(Richiesta &r_lavoro, uint64_t &r_biglietto);
	void _epilogo(Esito &&p_esito);
	// L'ombrello: fa girare un lavoro e trasforma una qualunque eccezione di
	// llama.cpp in un `false` con una diagnosi. Un'eccezione che esce dalla
	// funzione di un thread è `std::terminate` — vedi la nota nel .cpp.
	bool _riparata(const std::function<bool()> &p_lavoro, const char *p_dove);
	bool _molla() const;                 // «devo smettere adesso?»
	static bool _abort_llama(void *);    // ggml_abort_callback
	static bool _avanzamento(float, void *);  // llama_progress_callback

	Motore *_m = nullptr;
	Config _cfg;

	std::thread _thread;
	mutable std::mutex _mutex;
	std::condition_variable _campanello;

	// Lo stato che il thread principale legge SENZA lock.
	std::atomic<StatoLlm> _stato{StatoLlm::SPENTO};
	std::atomic<bool> _in_volo{false};
	std::atomic<bool> _annullato{false};
	std::atomic<bool> _fermati{false};
	std::atomic<int> _da_ritirare{0};
	std::atomic<float> _caricamento{0.0f};
	std::atomic<double> _sec_caricamento{0.0};
	std::atomic<uint64_t> _fatti{0};
	std::atomic<uint64_t> _buttati{0};

	// Sotto il lock, e i tratti del lock non sono mai dentro llama.
	std::deque<Richiesta> _coda;
	std::deque<Esito> _esiti;
	uint64_t _biglietto = 0;
	uint64_t _in_lavorazione = 0;
	std::string _diagnosi;
	bool _chiesto_carico = false;
	// «ho aperto io una finestra di silenzio»: vedi `abbandono_in_corso()`
	bool _zittisci = false;
	// ⚠️ «IL THREAD HA UN LAVORO IN MANO», e non è un doppione di `_in_volo`:
	// `_in_volo` si accende quando la richiesta entra IN CODA, questo quando
	// il thread la PRENDE. Fra i due momenti passano decine di microsecondi
	// (misurati: mediana 27 µs a macchina scarica, punte di 117 ms a macchina
	// carica), ed è la finestra in cui `annulla()` deve sapere chi spegne
	// `_in_volo`: il thread, o lei. Senza questa riga il villaggio ammutolisce
	// per sempre — vedi la nota in `annulla()`.
	bool _preso = false;

	// Il lavoro che il BANCO ha in mano (chi e biglietto): nel thread vero
	// sono due variabili locali di `_ciclo`, qui devono sopravvivere fra
	// `banco_prendi()` e `banco_finisci()` perché è chi prova a decidere
	// quanto dura quel tratto.
	Richiesta _banco_lavoro;
	uint64_t _banco_biglietto = 0;
};

}  // namespace chibi

#endif  // CHIBI_LLM_PENSIERI_H
