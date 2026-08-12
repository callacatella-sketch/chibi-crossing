#include "llm_pensieri.h"

// Il confine con llama.cpp. Unico include ammesso, e solo dai file `llm_*`.
#include "llm_llama.h"

// Il portiere: guarda il .gguf PRIMA che lo guardi llama. Vedi `llm_gguf.h`
// per la lista dei guasti che abortiscono il processo e di quelli che no.
#include "llm_gguf.h"

#include <chrono>
#include <cstring>
#include <exception>

#if defined(__APPLE__)
#include <pthread.h>
#include <sys/qos.h>
#elif defined(_WIN32)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#else
#include <sys/resource.h>
#include <unistd.h>
#endif

namespace chibi {

namespace {

double adesso_s() {
	using namespace std::chrono;
	return duration<double>(steady_clock::now().time_since_epoch()).count();
}

// LA PRIORITÀ DEL THREAD, e su Apple Silicon è la manopola che decide se il
// gioco se ne accorge. `QOS_CLASS_BACKGROUND` non è «un po' meno importante»:
// è la classe che lo scheduler confina sui core di efficienza. Il modello ci
// va più piano, e il frame non lo sente proprio.
//
// ⚠️ E VALE ANCHE PER I THREAD DI GGML, che è il motivo per cui si chiama
// QUI DENTRO e non da chi crea l'oggetto: su macOS un thread nato senza una
// QoS esplicita EREDITA quella di chi lo crea, e ggml crea la sua squadra
// alla prima `llama_decode`, cioè da questo thread. Chiamarla da fuori la
// darebbe al thread principale — cioè al gioco.
void priorita_di_fondo(int p_livello) {
	if (p_livello <= 0) {
		return;
	}
#if defined(__APPLE__)
	pthread_set_qos_class_self_np(
			p_livello >= 2 ? QOS_CLASS_BACKGROUND : QOS_CLASS_UTILITY, 0);
#elif defined(_WIN32)
	SetThreadPriority(GetCurrentThread(),
			p_livello >= 2 ? THREAD_PRIORITY_LOWEST : THREAD_PRIORITY_BELOW_NORMAL);
#else
	// Su Linux `setpriority(PRIO_PROCESS, 0, ...)` da dentro un thread vale
	// per QUEL thread (i thread sono processi leggeri): è il modo portabile
	// di dire «io conto meno del gioco».
	setpriority(PRIO_PROCESS, 0, p_livello >= 2 ? 10 : 5);
#endif
}

// Quante generazioni si stanno abbandonando adesso. È un contatore e non un
// booleano perché la finestra si apre da un thread (chi chiama `annulla`) e
// si chiude da un altro (chi stava generando): con un booleano, due
// annullamenti ravvicinati si chiuderebbero a vicenda e le righe del secondo
// uscirebbero come errori.
std::atomic<int> g_abbandoni{ 0 };

}  // namespace

bool abbandono_in_corso() {
	return g_abbandoni.load(std::memory_order_relaxed) > 0;
}

int n_thread_consigliati() {
	const unsigned int quanti = std::thread::hardware_concurrency();
	if (quanti <= 2) {
		return 1;
	}
	// Metà, e mai più di quattro. Un modello che prende tutti i core non va
	// più veloce di uno che ne prende metà (la memoria è il collo di
	// bottiglia, non l'aritmetica) e intanto il gioco resta senza.
	const int meta = static_cast<int>(quanti / 2);
	return meta > 4 ? 4 : meta;
}

// ─────────────────────────────────────────────────────────────────────────
// IL MOTORE — tutto ciò che sa di llama.cpp vive qui dentro, e questa
// struttura non esce mai dal thread che pensa.
// ─────────────────────────────────────────────────────────────────────────
struct Traduttore::Motore {
	llama_model *modello = nullptr;
	llama_context *ctx = nullptr;
	const llama_vocab *vocab = nullptr;
	const char *template_chat = nullptr;
	std::vector<llama_token> gettoni;
	std::string testo;
	std::string montato;
};

Traduttore::Traduttore() {}

Traduttore::~Traduttore() {
	chiudi();
}

bool Traduttore::apri(const Config &p_config) {
	if (_thread.joinable() || _fermati.load()) {
		return false;  // già acceso, o già chiuso: `apri` si chiama una volta
	}
	if (p_config.modello.empty()) {
		return false;
	}
	_cfg = p_config;
	if (_cfg.n_thread <= 0) {
		_cfg.n_thread = n_thread_consigliati();
	}
	_m = new Motore();
	_stato.store(StatoLlm::CARICA, std::memory_order_relaxed);
	{
		std::lock_guard<std::mutex> g(_mutex);
		_chiesto_carico = true;
	}
	_thread = std::thread(&Traduttore::_ciclo, this);
	return true;
}

uint64_t Traduttore::accoda(Richiesta p_richiesta) {
	// Le tre porte, e nessuna delle tre è decorativa:
	//  · il motore dev'essere PRONTO (non «acceso»): durante il caricamento
	//    accettare vorrebbe dire una coda che si riempie di pensieri vecchi;
	//  · la coda è profonda UNO (vedi l'intestazione);
	//  · senza grammatica non si scrive. Vedi la nota su `Richiesta`.
	if (!libero() || p_richiesta.grammatica.empty()) {
		return 0;
	}
	if (p_richiesta.utente.empty()) {
		return 0;
	}
	std::lock_guard<std::mutex> g(_mutex);
	if (!_coda.empty()) {
		return 0;
	}
	const uint64_t b = ++_biglietto;
	_coda.push_back(std::move(p_richiesta));
	_in_volo.store(true, std::memory_order_relaxed);
	_campanello.notify_one();
	return b;
}

bool Traduttore::raccogli(Esito &r_esito) {
	// IL CASO NORMALE È UN ATOMICO SOLO. Questa funzione la chiama il thread
	// principale a ogni frame: se prendesse il lock ogni volta, il frame
	// avrebbe la POSSIBILITÀ di aspettare il thread che pensa — raramente,
	// una volta ogni tanto, cioè esattamente il genere di singhiozzo che
	// nessun profilo medio mostra e che si vede.
	if (_da_ritirare.load(std::memory_order_acquire) == 0) {
		return false;
	}
	std::lock_guard<std::mutex> g(_mutex);
	if (_esiti.empty()) {
		return false;
	}
	r_esito = std::move(_esiti.front());
	_esiti.pop_front();
	_da_ritirare.store(static_cast<int>(_esiti.size()), std::memory_order_release);
	return true;
}

void Traduttore::annulla() {
	// NON BLOCCA. Alza la bandiera e se ne va: il thread se ne accorge dentro
	// `llama_decode` (abort_callback) e molla lì. Chi chiama sta cambiando
	// scena, e una scena non aspetta un token.
	//
	// ⚠️ LA BANDIERA SI ALZA SOTTO IL LUCCHETTO, e non è pignoleria: è il
	// guasto vero che questa riga ha già causato una volta, e non lasciava
	// nessuna traccia. `annulla()` su un traduttore FERMO (nessuna
	// generazione in volo — il caso normale: si cambia scena mentre il
	// villaggio non stava pensando) lasciava la bandiera alzata per sempre,
	// perché a spegnerla è il thread quando FINISCE un lavoro. Il pensiero
	// dopo — cioè il primo della scena nuova — nasceva già annullato: il
	// thread lo prendeva, `_molla()` diceva subito di sì, e l'esito veniva
	// buttato senza una riga di log. Nel banco a blocchi alternati il
	// risultato era «zero pensieri consegnati» con tutto verde.
	//
	// Sotto lo stesso lucchetto del prelievo, invece, i due ordini possibili
	// sono tutti e due giusti: o il lavoro è ancora in coda (e lo si butta),
	// o il thread l'ha già preso (e allora ha già azzerato la bandiera, che
	// si rialza adesso e lo interrompe).
	std::lock_guard<std::mutex> g(_mutex);
	if (!_annullato.exchange(true, std::memory_order_relaxed) &&
			_in_volo.load(std::memory_order_relaxed)) {
		// da qui e fino alla fine del lavoro in volo, gli errori che llama
		// stampa mentre molla non sono errori: sono il rumore di questo gesto
		g_abbandoni.fetch_add(1, std::memory_order_relaxed);
		_zittisci = true;
	}
	_buttati.fetch_add(_coda.size(), std::memory_order_relaxed);
	_coda.clear();
	_esiti.clear();
	_da_ritirare.store(0, std::memory_order_release);
}

void Traduttore::chiudi() {
	if (!_thread.joinable()) {
		// Nessun thread: resta comunque da liberare il motore se `apri` è
		// stata chiamata e il caricamento non è mai partito.
		if (_m != nullptr) {
			delete _m;
			_m = nullptr;
		}
		_fermati.store(true, std::memory_order_relaxed);
		return;
	}
	_fermati.store(true, std::memory_order_relaxed);
	_annullato.store(true, std::memory_order_relaxed);
	// chiudere mentre si genera fa mollare llama a metà, e llama lo racconta
	// con tre righe di errore: qui sono il rumore della chiusura, non guasti
	if (_in_volo.load(std::memory_order_relaxed)) {
		g_abbandoni.fetch_add(1, std::memory_order_relaxed);
		_zittisci = true;
	}
	_campanello.notify_all();
	_thread.join();
	if (_zittisci) {
		_zittisci = false;
		g_abbandoni.fetch_sub(1, std::memory_order_relaxed);
	}
	if (_m != nullptr) {
		delete _m;
		_m = nullptr;
	}
	_stato.store(StatoLlm::SPENTO, std::memory_order_relaxed);
}

std::string Traduttore::diagnosi() const {
	std::lock_guard<std::mutex> g(_mutex);
	return _diagnosi;
}

bool Traduttore::_molla() const {
	return _fermati.load(std::memory_order_relaxed) ||
			_annullato.load(std::memory_order_relaxed);
}

bool Traduttore::_abort_llama(void *p_dato) {
	// ggml chiama questa a ogni nodo del grafo: torna true e `llama_decode`
	// si ferma A METÀ di un token. È l'unica via per cui chiudere il gioco
	// mentre il Gufo scrive non costa l'attesa di un token intero.
	return static_cast<Traduttore *>(p_dato)->_molla();
}

bool Traduttore::_avanzamento(float p_frazione, void *p_dato) {
	Traduttore *t = static_cast<Traduttore *>(p_dato);
	t->_caricamento.store(p_frazione, std::memory_order_relaxed);
	// `false` = smetti di caricare. Due gigabyte non si aspettano: chi chiude
	// il gioco mentre il modello si apre non deve vedere una finestra ferma.
	return !t->_fermati.load(std::memory_order_relaxed);
}

// ─────────────────────────────────────────────────────────────────────────
// IL THREAD
// ─────────────────────────────────────────────────────────────────────────
void Traduttore::_ciclo() {
	priorita_di_fondo(_cfg.priorita);

	for (;;) {
		Richiesta lavoro;
		uint64_t biglietto = 0;
		bool carica = false;
		{
			std::unique_lock<std::mutex> g(_mutex);
			_campanello.wait(g, [this] {
				return _fermati.load(std::memory_order_relaxed) || _chiesto_carico ||
						!_coda.empty();
			});
			if (_fermati.load(std::memory_order_relaxed)) {
				break;
			}
			if (_chiesto_carico) {
				_chiesto_carico = false;
				carica = true;
			} else {
				lavoro = std::move(_coda.front());
				_coda.pop_front();
				// IL BIGLIETTO SI PRENDE QUI, sotto lo stesso lock del prelievo.
				// Leggerlo più tardi vorrebbe dire leggere un contatore che nel
				// frattempo può essere avanzato, cioè consegnare un pensiero
				// con il numero di un altro — ed è proprio il numero con cui
				// chi riceve decide se buttarlo.
				_in_lavorazione = _biglietto;
				biglietto = _biglietto;
				// E QUI SI AZZERA LA BANDIERA DELL'ANNULLAMENTO: un annullamento
				// arrivato PRIMA che questo lavoro esistesse non lo riguarda.
				// Sta sotto lo stesso lucchetto di `annulla()` apposta — vedi
				// la nota là, è il guasto che rendeva muto il villaggio.
				_annullato.store(false, std::memory_order_relaxed);
			}
		}

		if (carica) {
			const double t0 = adesso_s();
			const bool ok = _riparata(
					[this]() { return _carica(); }, "aprendo il modello");
			_sec_caricamento.store(adesso_s() - t0, std::memory_order_relaxed);
			_stato.store(ok ? StatoLlm::PRONTO : StatoLlm::GUASTO,
					std::memory_order_relaxed);
			if (!ok) {
				// GUASTO NON È UN'ECCEZIONE: è la configurazione di chi non ha
				// il modello. Il thread resta vivo (così `chiudi()` è sempre
				// la stessa cosa) ma non accetterà mai lavoro, perché
				// `libero()` guarda PRONTO.
				continue;
			}
			continue;
		}

		_stato.store(StatoLlm::PENSA, std::memory_order_relaxed);
		Esito esito;
		esito.chi = lavoro.chi;
		esito.biglietto = biglietto;
		if (!_riparata([this, &lavoro, &esito]() {
					_genera(lavoro, esito);
					return true;
				},
					"scrivendo")) {
			esito.bozze.clear();
			esito.errore = "llama.cpp si è lamentata mentre scriveva";
		}
		_stato.store(StatoLlm::PRONTO, std::memory_order_relaxed);

		const bool buttato = _annullato.exchange(false, std::memory_order_relaxed);
		{
			// la finestra del silenzio si chiude QUI: il lavoro che stava
			// mollando è finito, e da adesso un errore di llama è un errore
			std::lock_guard<std::mutex> g(_mutex);
			if (_zittisci) {
				_zittisci = false;
				g_abbandoni.fetch_sub(1, std::memory_order_relaxed);
			}
		}
		// ⚠️ `_in_volo` SI SPEGNE PER ULTIMO, DOPO CHE L'ESITO È RITIRABILE.
		// È lui, e non lo stato, a dire al thread principale «ho finito»
		// (`libero()` li guarda tutti e due). Spegnendolo PRIMA di posare
		// l'esito si apre una finestra di pochi microsecondi in cui il gioco
		// vede un motore libero e una cassetta ancora vuota — e chi aspetta
		// quel biglietto lo dichiara perso un istante prima che arrivi, per
		// poi buttarlo un frame dopo perché il numero non è più quello che
		// aspettava. Un pensiero perso ogni tanto, senza una riga di log, e
		// solo su una macchina carica: la specie di difetto che si scopre in
		// produzione o non si scopre affatto.
		if (buttato) {
			// UN ESITO ANNULLATO NON SI CONSEGNA. Se si consegnasse, il
			// chiamante dovrebbe ricordarsi di guardare un flag — e prima o
			// poi qualcuno non se ne ricorda, e un pensiero di due scene fa
			// arriva addosso a un vicino che nel frattempo se n'è andato.
			_buttati.fetch_add(1, std::memory_order_relaxed);
		} else {
			// ⚠️ MA UN ESITO VUOTO SÌ, ED È UNA CORREZIONE, NON UNO SFIZIO.
			// Prima si buttava anche quello (`|| esito.bozze.empty()`), e il
			// risultato era il guasto peggiore di tutta la fase: chi aspetta
			// quel biglietto — `Pensatoio` — non lo riceve MAI, quindi non
			// smette mai di aspettarlo, quindi non chiede più nessun pensiero.
			// **Il villaggio diventa muto per sempre, in silenzio, dopo un
			// errore solo**: un prompt più lungo della finestra, una grammatica
			// che non si apre, un `llama_decode` che rifiuta. Un errore che
			// nessuno riceve non è un errore gestito: è un sistema che si
			// spegne da solo. L'esito vuoto porta `errore` compilato, ed è la
			// sola strada per cui quel testo arriva a chi può stamparlo.
			if (esito.bozze.empty()) {
				_buttati.fetch_add(1, std::memory_order_relaxed);
			} else {
				_fatti.fetch_add(1, std::memory_order_relaxed);
			}
			std::lock_guard<std::mutex> g(_mutex);
			_esiti.push_back(std::move(esito));
			_da_ritirare.store(static_cast<int>(_esiti.size()), std::memory_order_release);
		}
		_in_volo.store(false, std::memory_order_relaxed);
	}

	// Il modello si libera SUL THREAD che l'ha aperto: `llama_free` tocca i
	// backend, e farlo dal thread principale mentre questo è ancora dentro
	// una decode è il modo classico di finire in un crash che si riproduce
	// una volta su venti.
	if (_m != nullptr) {
		if (_m->ctx != nullptr) {
			llama_free(_m->ctx);
			_m->ctx = nullptr;
		}
		if (_m->modello != nullptr) {
			llama_model_free(_m->modello);
			_m->modello = nullptr;
		}
	}
}

bool Traduttore::_riparata(const std::function<bool()> &p_lavoro, const char *p_dove) {
	// ⚠️ L'OMBRELLO DEL THREAD, ed è obbligatorio — non prudente.
	//
	// Un'eccezione che esce dalla funzione di un `std::thread` NON è un
	// errore da gestire: è `std::terminate`, cioè il gioco che sparisce senza
	// una riga. E llama.cpp le tira: `llama_decode`, `llama_tokenize` e
	// `llama_token_to_piece` non se le riprendono (lo dice `llm_llama.h`,
	// punto 1), e ce n'è almeno una che si RAGGIUNGE DAVVERO — «Unexpected
	// empty grammar stack after accepting piece», che parte da dentro
	// `llama_sampler_sample` quando il gettone scelto non è uno di quelli che
	// la grammatica permetteva. Misurata: `tools/portiere_vs_llama campionatori`
	// la fa scattare in dieci secondi mettendo la grammatica DOPO top_k.
	//
	// La catena di produzione ha la grammatica per prima e quel caso non lo
	// tocca — ma «oggi non ci passa» non è una difesa: basta una manopola
	// spostata (un top_k, un min_p, una grammatica nuova) perché ci passi, e
	// il costo dell'errore è il processo del giocatore. Questo è il confine
	// che `llm_llama.h` dice che deve esistere, e prima non esisteva.
	//
	// Il degrado va sempre verso «il gioco continua senza»: il pensiero si
	// perde, il thread resta vivo, le lettere scritte a mano ci sono.
	try {
		return p_lavoro();
	} catch (const std::exception &e) {
		std::lock_guard<std::mutex> g(_mutex);
		_diagnosi = std::string("llama.cpp si è lamentata ") + p_dove + ": " + e.what();
		return false;
	} catch (...) {
		std::lock_guard<std::mutex> g(_mutex);
		_diagnosi = std::string("llama.cpp si è lamentata ") + p_dove +
				" in un modo che non so raccontare";
		return false;
	}
}

bool Traduttore::_carica() {
	// ── IL PORTIERE, E STA QUI PER DUE RAGIONI ───────────────────────────
	//
	// 1. PRIMA DI LLAMA. `GGML_ABORT` chiama `abort()`: non è `assert()`,
	//    `NDEBUG` non lo spegne, non ha callback e nessun `try` lo prende —
	//    nemmeno quello che `llama_model_load_from_file` ha dentro. Un file
	//    troncato è anche peggio: llama lo mappa in memoria e ci legge sopra,
	//    e leggere oltre una mappatura è SIGBUS, cioè il gioco che sparisce
	//    senza una riga di log. Il portiere legge il file per conto suo, con
	//    un controllo di limite su ogni campo, e dice di no senza che llama
	//    lo abbia mai aperto. Quali guasti chiude e quali no sta scritto in
	//    `llm_gguf.h`, misurato con `tools/rovina_gguf.py`.
	// 2. SUL THREAD. L'esame costa (l'intestazione di un modello sono
	//    duecentomila stringhe di vocabolario da attraversare) e l'impronta
	//    costa molto di più. Il frame non deve pagare niente: qui siamo già
	//    dentro il thread del traduttore, e `_molla()` può interromperlo.
	if (_cfg.valida) {
		const FattiGguf fatti = esamina_gguf(_cfg.modello, !_cfg.impronta_attesa.empty());
		if (!fatti.ok) {
			std::lock_guard<std::mutex> g(_mutex);
			_diagnosi = "il file non è un modello sano: " + fatti.motivo;
			return false;
		}
		if (!_cfg.impronta_attesa.empty() && fatti.impronta != _cfg.impronta_attesa) {
			std::lock_guard<std::mutex> g(_mutex);
			_diagnosi = "l'impronta non combacia: questo non è il modello collaudato";
			return false;
		}
		if (_cfg.tetto_byte > 0) {
			// IL TETTO SI DICE PRIMA. Un tetto che si scopre dopo aver
			// riempito la memoria non è un tetto: è un referto.
			const uint64_t serve = stima_byte_totali(fatti, static_cast<uint32_t>(_cfg.n_ctx));
			if (serve > _cfg.tetto_byte) {
				std::lock_guard<std::mutex> g(_mutex);
				_diagnosi = "il modello chiede circa " +
						std::to_string(serve / (1024 * 1024)) + " MB (pesi + cache a " +
						std::to_string(_cfg.n_ctx) + " gettoni) e il tetto è " +
						std::to_string(_cfg.tetto_byte / (1024 * 1024)) + " MB";
				return false;
			}
		}
	}

	llama_model_params mp = llama_model_default_params();
	// ⚠️ ZERO STRATI SULLA GPU, e non è una taratura: vedi `Config::gpu`.
	mp.n_gpu_layers = _cfg.gpu ? 999 : 0;
	mp.progress_callback = &Traduttore::_avanzamento;
	mp.progress_callback_user_data = this;

	_m->modello = llama_model_load_from_file(_cfg.modello.c_str(), mp);
	if (_m->modello == nullptr) {
		std::lock_guard<std::mutex> g(_mutex);
		_diagnosi = "il modello non si è aperto: " + _cfg.modello;
		return false;
	}

	llama_context_params cp = llama_context_default_params();
	cp.n_ctx = static_cast<uint32_t>(_cfg.n_ctx);
	cp.n_batch = 512;
	cp.n_ubatch = 512;
	cp.n_seq_max = 1;
	// UN SOLO LOGIT ALLA VOLTA. Il buffer di uscita del grafo è
	// `n_outputs_max × n_vocab × 4 byte`: col valore di serie (= n_batch) su
	// un vocabolario da 128k parole fanno 262 MB di buffer di calcolo per una
	// cosa che campiona SEMPRE un token solo. Su una macchina da 8 GB con un
	// modello da 1.9 GB dentro, 262 MB non sono un dettaglio.
	cp.n_outputs_max = 1;
	cp.n_threads = _cfg.n_thread;
	cp.n_threads_batch = _cfg.n_thread;
	cp.abort_callback = &Traduttore::_abort_llama;
	cp.abort_callback_data = this;
	cp.no_perf = true;

	_m->ctx = llama_init_from_model(_m->modello, cp);
	if (_m->ctx == nullptr) {
		std::lock_guard<std::mutex> g(_mutex);
		_diagnosi = "il contesto non si è creato (memoria?)";
		llama_model_free(_m->modello);
		_m->modello = nullptr;
		return false;
	}
	_m->vocab = llama_model_get_vocab(_m->modello);
	_m->template_chat = llama_model_chat_template(_m->modello, nullptr);
	{
		std::lock_guard<std::mutex> g(_mutex);
		_diagnosi = "pronto";
	}
	return true;
}

void Traduttore::_genera(const Richiesta &p_r, Esito &r_esito) {
	Motore &m = *_m;
	const int tetto = p_r.max_token > 0 ? p_r.max_token : _cfg.max_token;

	// --- 1. IL FOGLIO, montato come lo vuole QUESTO modello --------------
	m.montato.clear();
	bool montato_ok = false;
	if (m.template_chat != nullptr && !p_r.sistema.empty()) {
		llama_chat_message msg[2];
		msg[0].role = "system";
		msg[0].content = p_r.sistema.c_str();
		msg[1].role = "user";
		msg[1].content = p_r.utente.c_str();
		std::vector<char> buf((p_r.sistema.size() + p_r.utente.size()) * 2 + 512);
		int32_t n = llama_chat_apply_template(m.template_chat, msg, 2, true,
				buf.data(), static_cast<int32_t>(buf.size()));
		if (n > static_cast<int32_t>(buf.size())) {
			buf.resize(static_cast<size_t>(n) + 1);
			n = llama_chat_apply_template(m.template_chat, msg, 2, true,
					buf.data(), static_cast<int32_t>(buf.size()));
		}
		if (n > 0) {
			m.montato.assign(buf.data(), static_cast<size_t>(n));
			montato_ok = true;
		}
	}
	if (!montato_ok) {
		// Nessun template (o modello non istruito): le due metà si attaccano
		// come le attaccherebbe `Suggeritore.componi()`. È il ripiego, e il
		// degrado va verso «si scrive lo stesso».
		m.montato = p_r.sistema.empty() ? p_r.utente : (p_r.sistema + "\n\n" + p_r.utente);
	}

	// --- 2. I GETTONI ----------------------------------------------------
	const int max_gettoni = _cfg.n_ctx;
	m.gettoni.resize(static_cast<size_t>(max_gettoni));
	int n_prompt = llama_tokenize(m.vocab, m.montato.c_str(),
			static_cast<int32_t>(m.montato.size()), m.gettoni.data(), max_gettoni,
			/*add_special=*/true, /*parse_special=*/true);
	if (n_prompt <= 0) {
		r_esito.errore = "il prompt non entra nella finestra";
		return;
	}
	if (n_prompt + tetto + 4 > _cfg.n_ctx) {
		// I NUMERI DENTRO IL MESSAGGIO, e non è pedanteria: sotto il tetto dei
		// 2 GB dell'autore un 3B quantizzato entra solo con una finestra da
		// 1024 gettoni, e il foglio più pieno che questo gioco sappia
		// costruire (sei ricordi con tutti i pezzi facoltativi) ne misura
		// 727. Il margine c'è ma è sottile: chi allarga il prompt deve poter
		// leggere DI QUANTO ha sforato, non «troppo lungo».
		r_esito.errore = "prompt di " + std::to_string(n_prompt) +
				" gettoni + " + std::to_string(tetto) + " di uscita: non entrano in " +
				std::to_string(_cfg.n_ctx);
		return;
	}
	m.gettoni.resize(static_cast<size_t>(n_prompt));
	r_esito.token_prompt = n_prompt;

	llama_memory_t mem = llama_get_memory(m.ctx);
	llama_memory_clear(mem, true);

	// --- 3. IL PROMPT SI PAGA UNA VOLTA SOLA -----------------------------
	// IL TRUCCO DELLE COPIE, ed è la ragione per cui «molte copie» sta dentro
	// il thread e non fuori. Le N bozze condividono lo STESSO prompt: se si
	// chiedessero N generazioni separate, il prompt si ripagherebbe N volte —
	// e il prompt di questo gioco è la parte CARA: 727 gettoni misurati sul
	// foglio più pieno, contro le ~60 di una bozza. Qui il
	// prompt si decodifica UNA volta; poi, per ogni copia, si taglia via dalla
	// memoria di attenzione solo la coda generata e si riparte dall'ultimo
	// gettone del prompt. Cinque bozze costano un prompt e cinque code.
	const int n_tieni = n_prompt - 1;
	const double t_prompt = adesso_s();
	for (int i = 0; i < n_tieni;) {
		const int quanti = (n_tieni - i) < 512 ? (n_tieni - i) : 512;
		const int rc = llama_decode(m.ctx, llama_batch_get_one(m.gettoni.data() + i, quanti));
		if (rc != 0 || _molla()) {
			r_esito.errore = rc != 0 ? "llama_decode ha rifiutato il prompt" : "";
			return;
		}
		i += quanti;
	}
	r_esito.secondi_prompt = adesso_s() - t_prompt;

	// --- 4. LE COPIE -----------------------------------------------------
	const double t_gen = adesso_s();
	const int copie = p_r.copie > 0 ? p_r.copie : 1;
	for (int c = 0; c < copie && !_molla(); ++c) {
		// SI TORNA AL FOGLIO PULITO: via tutto ciò che è stato scritto dopo.
		//
		// ⚠️ E SE IL RIAVVOLGIMENTO NON SI PUÒ FARE, SI RILEGGE. `seq_rm`
		// torna `false` quando una cancellazione PARZIALE non è possibile —
		// succede con le architetture a finestra scorrevole, dove i pezzi
		// vecchi della memoria non ci sono più. Ignorare quel `false` sarebbe
		// il difetto peggiore di tutto questo file: il contesto resterebbe
		// con la coda della bozza precedente ancora attaccata, e la copia
		// dopo continuerebbe la copia prima **invece** di ripartire dal
		// prompt. Le bozze uscirebbero belle, plausibili, e una il seguito
		// dell'altra: nessun errore, nessuna riga di log, e la SELEZIONE —
		// che è tutto il punto delle molte copie — si troverebbe a scegliere
		// fra cinque pezzi dello stesso testo.
		// Il ripiego costa un prompt in più ed è sempre giusto.
		if (c > 0 && !llama_memory_seq_rm(mem, 0, n_tieni, -1)) {
			llama_memory_clear(mem, true);
			bool rifatto = true;
			for (int i = 0; i < n_tieni;) {
				const int quanti = (n_tieni - i) < 512 ? (n_tieni - i) : 512;
				if (llama_decode(m.ctx, llama_batch_get_one(m.gettoni.data() + i, quanti)) != 0 ||
						_molla()) {
					rifatto = false;
					break;
				}
				i += quanti;
			}
			++r_esito.riletture_prompt;
			if (!rifatto) {
				break;
			}
		}

		llama_sampler *catena = llama_sampler_chain_init(llama_sampler_chain_default_params());
		// LA GRAMMATICA VA PER PRIMA: spegne i gettoni che non esistono in
		// questo villaggio PRIMA che gli altri campionatori si mettano a
		// pesare le probabilità. Al contrario, top-p sceglierebbe fra parole
		// che poi la grammatica butta, e la coda della distribuzione
		// diventerebbe rumore.
		llama_sampler *gram = llama_sampler_init_grammar(m.vocab,
				p_r.grammatica.c_str(), "root");
		if (gram == nullptr) {
			// ⚠️ SI SMETTE. Generare senza grammatica sarebbe il 27% di
			// citazioni inventate, cioè il guasto che INVERTE l'effetto.
			llama_sampler_free(catena);
			r_esito.errore = "la grammatica non si è aperta";
			r_esito.bozze.clear();
			return;
		}
		llama_sampler_chain_add(catena, gram);
		llama_sampler_chain_add(catena, llama_sampler_init_penalties(
				llama_vocab_n_tokens(m.vocab), 64, p_r.penalita_ripetizione, 0.0f, 0.0f));
		llama_sampler_chain_add(catena, llama_sampler_init_top_p(p_r.top_p, 1));
		llama_sampler_chain_add(catena, llama_sampler_init_temp(p_r.temperatura));
		// IL SEME ARRIVA DA FUORI. In questo cuore non c'è, e non ci sarà, un
		// generatore di numeri a caso: i dadi del villaggio si salvano
		// (`Animo._rng`) e un secondo dado qui dentro sarebbe una seconda
		// storia che nessun salvataggio racconta. `seme + c` distingue le
		// copie fra loro restando figlio del dado di là.
		llama_sampler_chain_add(catena, llama_sampler_init_dist(p_r.seme + static_cast<uint32_t>(c)));

		// si riparte dall'ULTIMO gettone del prompt: costa un token e rimette
		// i logit al posto giusto dopo il taglio
		llama_token ultimo = m.gettoni[static_cast<size_t>(n_tieni)];
		m.testo.clear();
		int n_gen = 0;
		bool rotto = false;
		for (int k = 0; k < tetto; ++k) {
			const int rc = llama_decode(m.ctx, llama_batch_get_one(&ultimo, 1));
			if (rc != 0 || _molla()) {
				rotto = true;
				break;
			}
			const llama_token t = llama_sampler_sample(catena, m.ctx, -1);
			if (llama_vocab_is_eog(m.vocab, t)) {
				break;
			}
			char pezzo[256];
			const int32_t n = llama_token_to_piece(m.vocab, t, pezzo, sizeof(pezzo), 0, false);
			if (n > 0) {
				m.testo.append(pezzo, static_cast<size_t>(n));
			}
			++n_gen;
			ultimo = t;
		}
		llama_sampler_free(catena);
		r_esito.token_generati += n_gen;
		if (!rotto && !m.testo.empty()) {
			r_esito.bozze.push_back(m.testo);
		}
		if (rotto) {
			break;
		}
	}
	r_esito.secondi_generazione = adesso_s() - t_gen;
}

}  // namespace chibi
