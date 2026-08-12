#include "llm_ponte.h"

// Il confine. È l'unico include di llama.cpp di tutto il progetto, e sta qui
// dentro (non nell'header) apposta: chi include `llm_ponte.h` non eredita
// niente di llama.
#include "llm_llama.h"

#include "llm_gguf.h"
#include "llm_memoria.h"
#include "llm_pensieri.h"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace {

// llama.cpp scrive su stderr per conto suo. Dirottato qui, il rumore diventa
// una riga di Godot — e sotto la soglia dell'errore resta silenzio: durante il
// caricamento di un modello llama stampa decine di righe INFO che, dentro la
// suite headless, sarebbero indistinguibili dai guasti veri.
void chibi_llm_log(ggml_log_level p_livello, const char *p_testo, void *) {
	if (p_testo == nullptr || p_livello < GGML_LOG_LEVEL_WARN) {
		return;
	}
	String riga = String("[llama] ") + String(p_testo).strip_edges();
	if (riga.length() <= 8) {
		return;
	}
	// ⚠️ UN DECODE ABBANDONATO NON È UN GUASTO, ED È IL CASO NORMALE.
	// Quando `abort_callback` ferma `llama_decode` a metà — cioè a ogni
	// cambio di scena, a ogni ritorno al titolo, a ogni chiusura del gioco —
	// llama.cpp lo racconta con TRE righe di errore («graph_compute … failed
	// with error 1», «process_ubatch: failed to compute graph»,
	// «llama_decode: failed to decode, ret = 2»). Sono la firma di un gesto
	// VOLUTO, e lasciarle passare come errori significherebbe tre errori per
	// ogni cambio di scena: in un progetto che conta gli `SCRIPT ERROR` e
	// pretende zero, non si rompe il gioco — si rompe la rete che si accorge
	// quando il gioco è rotto davvero.
	// Fuori da quella finestra (`abbandono_in_corso`) un errore di llama
	// resta un errore, e si vede.
	if (p_livello >= GGML_LOG_LEVEL_ERROR && !chibi::abbandono_in_corso()) {
		UtilityFunctions::push_error(riga);
	} else {
		UtilityFunctions::push_warning(riga);
	}
}

bool g_acceso = false;

// IL TRADUTTORE DEL PROCESSO. Uno solo, e vive fuori da qualunque istanza:
// `LlmLocale` è un maniglione (vedi l'header). Sta in una funzione e non fra
// le variabili globali perché così nasce alla prima domanda e non all'atto
// del caricamento della libreria — un thread acceso da un costruttore statico
// girerebbe anche nell'editor, dentro `--headless --import`, e dentro la
// suite: cioè in tutti i posti in cui non serve.
chibi::Traduttore &traduttore() {
	static chibi::Traduttore t;
	return t;
}

// `p_s.utf8()` alloca; il risultato si copia SUBITO in un `std::string`,
// perché da lì in poi il testo attraversa il confine del thread e di là non
// deve esistere nessun oggetto di Godot (vedi l'intestazione di
// llm_pensieri.h).
std::string a_std(const String &p_s) {
	CharString c = p_s.utf8();
	return std::string(c.get_data(), static_cast<size_t>(c.length()));
}

} // namespace

LlmLocale::LlmLocale() {
	avvia();
}

LlmLocale::~LlmLocale() {
	// NIENTE `llama_backend_free()` qui. Il registro dei backend è globale al
	// processo, non a questo oggetto: liberarlo quando l'ultimo riferimento
	// GDScript sparisce vorrebbe dire spegnere llama sotto i piedi di chiunque
	// altro lo stia usando. Si spegne quando si spegne il gioco.
}

void LlmLocale::avvia() {
	if (g_acceso) {
		return;
	}
	// L'ORDINE CONTA: le callback prima di tutto, altrimenti le prime righe —
	// quelle che dicono quali istruzioni ha compilato ggml, cioè proprio quelle
	// che si vorrebbe leggere — escono su stderr fuori da Godot.
	llama_log_set(chibi_llm_log, nullptr);
	ggml_log_set(chibi_llm_log, nullptr);
	llama_backend_init();
	g_acceso = true;
}

String LlmLocale::versione() const {
	return String(ggml_version()) + " (" + String(ggml_commit()) + ")";
}

String LlmLocale::info_sistema() const {
	const char *info = llama_print_system_info();
	return info != nullptr ? String(info) : String();
}

int64_t LlmLocale::quanti_backend() const {
	return static_cast<int64_t>(ggml_backend_reg_count());
}

PackedStringArray LlmLocale::backend() const {
	PackedStringArray nomi;
	const size_t quanti = ggml_backend_reg_count();
	for (size_t i = 0; i < quanti; ++i) {
		ggml_backend_reg_t reg = ggml_backend_reg_get(i);
		const char *nome = reg != nullptr ? ggml_backend_reg_name(reg) : nullptr;
		nomi.push_back(nome != nullptr ? String(nome) : String("?"));
	}
	return nomi;
}

// ─────────────────────────────────────────────────────────────────────────
// IL PORTIERE — la faccia Godot di `chibi::esamina_gguf`
// ─────────────────────────────────────────────────────────────────────────

namespace {

String assoluto_di(const String &p_percorso) {
	// `res://` e `user://` sono di Godot, non del sistema: chi passa un
	// percorso di gioco a `fopen` apre un file che non esiste, e il portiere
	// direbbe di no per la ragione sbagliata.
	return p_percorso.begins_with("res://") || p_percorso.begins_with("user://")
			? ProjectSettings::get_singleton()->globalize_path(p_percorso)
			: p_percorso;
}

} // namespace

Dictionary LlmLocale::esamina(const String &p_percorso, bool p_con_impronta) {
	Dictionary d;
	const chibi::FattiGguf f = chibi::esamina_gguf(a_std(assoluto_di(p_percorso)), p_con_impronta);
	d["ok"] = f.ok;
	d["motivo"] = String::utf8(f.motivo.c_str());
	d["versione"] = static_cast<int64_t>(f.versione);
	d["byte_file"] = static_cast<int64_t>(f.byte_file);
	d["byte_pesi"] = static_cast<int64_t>(f.byte_dati);
	d["tensori"] = static_cast<int64_t>(f.n_tensori);
	d["chiavi"] = static_cast<int64_t>(f.n_chiavi);
	d["architettura"] = String::utf8(f.architettura.c_str());
	d["nome"] = String::utf8(f.nome.c_str());
	d["quantizzazione"] = String::utf8(f.quantizzazione.c_str());
	d["parametri"] = static_cast<int64_t>(f.parametri);
	d["vocabolario"] = static_cast<int64_t>(f.vocabolario);
	d["strati"] = static_cast<int64_t>(f.strati);
	d["contesto_addestramento"] = static_cast<int64_t>(f.contesto_addestramento);
	d["embedding"] = static_cast<int64_t>(f.embedding);
	d["teste"] = static_cast<int64_t>(f.teste);
	d["teste_kv"] = static_cast<int64_t>(f.teste_kv);
	d["impronta"] = String::utf8(f.impronta.c_str());
	d["ms_esame"] = f.ms_esame;
	d["ms_impronta"] = f.ms_impronta;
	// La stima serve a decidere PRIMA se un modello ci sta nel tetto. Si dà a
	// due finestre perché il costo della cache cresce con quella, ed è la
	// manopola che il gioco ha in mano.
	d["byte_stimati_2k"] = static_cast<int64_t>(chibi::stima_byte_totali(f, 2048));
	d["byte_stimati_4k"] = static_cast<int64_t>(chibi::stima_byte_totali(f, 4096));
	return d;
}

String LlmLocale::impronta(const String &p_percorso) {
	return String::utf8(chibi::impronta_file(a_std(assoluto_di(p_percorso))).c_str());
}

Dictionary LlmLocale::memoria() const {
	Dictionary d;
	d["impronta"] = static_cast<int64_t>(chibi::memoria_impronta());
	d["residente"] = static_cast<int64_t>(chibi::memoria_residente());
	return d;
}

// ─────────────────────────────────────────────────────────────────────────
// IL TRADUTTORE DI PENSIERI — la faccia Godot di `chibi::Traduttore`
// ─────────────────────────────────────────────────────────────────────────

bool LlmLocale::apri_modello(const String &p_percorso, const Dictionary &p_opzioni) {
	if (traduttore().stato() != chibi::StatoLlm::SPENTO) {
		return false; // c'è già un modello (o ci ha già provato)
	}
	if (p_percorso.is_empty()) {
		return false;
	}
	// IL FILE SI GUARDA PRIMA. Non è pignoleria: `GGML_ABORT` non è `assert()`
	// e `NDEBUG` non lo spegne — un .gguf assente o troncato può portarsi via
	// il PROCESSO, e nessun `try` lo prende (punto 6 di llm_llama.h). Questo
	// controllo non copre un file corrotto; copre il caso banale, che è anche
	// il più frequente: il giocatore non ha (ancora) scaricato il modello.
	const String assoluto = p_percorso.begins_with("res://") || p_percorso.begins_with("user://")
			? ProjectSettings::get_singleton()->globalize_path(p_percorso)
			: p_percorso;
	if (!FileAccess::file_exists(assoluto)) {
		return false;
	}

	chibi::Config cfg;
	cfg.modello = a_std(assoluto);
	if (p_opzioni.has("n_ctx")) {
		cfg.n_ctx = static_cast<int>(p_opzioni["n_ctx"]);
	}
	if (p_opzioni.has("n_thread")) {
		cfg.n_thread = static_cast<int>(p_opzioni["n_thread"]);
	}
	if (p_opzioni.has("priorita")) {
		cfg.priorita = static_cast<int>(p_opzioni["priorita"]);
	}
	if (p_opzioni.has("gpu")) {
		cfg.gpu = static_cast<bool>(p_opzioni["gpu"]);
	}
	if (p_opzioni.has("max_token")) {
		cfg.max_token = static_cast<int>(p_opzioni["max_token"]);
	}
	// IL TETTO DI RAM è dell'autore e vale 2 GB: sta di serie dentro `Config`,
	// e si scavalca solo per misurare (i provini che vogliono sapere quanto
	// costerebbe un modello troppo grande). `0` = nessun tetto.
	if (p_opzioni.has("tetto_byte")) {
		cfg.tetto_byte = static_cast<uint64_t>(static_cast<int64_t>(p_opzioni["tetto_byte"]));
	}
	// L'impronta attesa: se c'è, il file deve essere ESATTAMENTE quello. È
	// l'unica difesa vera contro il residuo dichiarato in `llm_gguf.h`, e il
	// giorno in cui il gioco spedirà il suo modello questa riga sarà una
	// costante in `Llm.gd`, non un'opzione.
	if (p_opzioni.has("impronta")) {
		cfg.impronta_attesa = a_std(p_opzioni["impronta"]);
	}
	return traduttore().apri(cfg);
}

int LlmLocale::stato() const {
	return static_cast<int>(traduttore().stato());
}

bool LlmLocale::pronto() const {
	return traduttore().pronto();
}

bool LlmLocale::libero() const {
	return traduttore().libero();
}

double LlmLocale::caricamento() const {
	return static_cast<double>(traduttore().caricamento());
}

int64_t LlmLocale::accoda(int64_t p_chi, const String &p_sistema, const String &p_utente,
		const String &p_grammatica, const Dictionary &p_opzioni) {
	chibi::Richiesta r;
	r.chi = p_chi;
	r.sistema = a_std(p_sistema);
	r.utente = a_std(p_utente);
	r.grammatica = a_std(p_grammatica);
	if (p_opzioni.has("copie")) {
		r.copie = static_cast<int>(p_opzioni["copie"]);
	}
	if (p_opzioni.has("max_token")) {
		r.max_token = static_cast<int>(p_opzioni["max_token"]);
	}
	if (p_opzioni.has("temperatura")) {
		r.temperatura = static_cast<float>(static_cast<double>(p_opzioni["temperatura"]));
	}
	if (p_opzioni.has("top_p")) {
		r.top_p = static_cast<float>(static_cast<double>(p_opzioni["top_p"]));
	}
	if (p_opzioni.has("penalita")) {
		r.penalita_ripetizione = static_cast<float>(static_cast<double>(p_opzioni["penalita"]));
	}
	// IL SEME ARRIVA DA FUORI, SEMPRE. Qui dentro non c'è un generatore di
	// numeri a caso e non ci sarà: i dadi di questo villaggio si salvano
	// (`Animo._rng`), e un dado in C++ sarebbe una seconda storia che nessun
	// salvataggio racconta.
	if (p_opzioni.has("seme")) {
		r.seme = static_cast<uint32_t>(static_cast<int64_t>(p_opzioni["seme"]) & 0xFFFFFFFF);
	}
	return static_cast<int64_t>(traduttore().accoda(std::move(r)));
}

Dictionary LlmLocale::raccogli() {
	Dictionary d;
	chibi::Esito e;
	if (!traduttore().raccogli(e)) {
		return d; // il caso normale: un atomico, e via
	}
	PackedStringArray bozze;
	for (const std::string &b : e.bozze) {
		bozze.push_back(String::utf8(b.c_str(), static_cast<int>(b.size())));
	}
	d["biglietto"] = static_cast<int64_t>(e.biglietto);
	d["chi"] = e.chi;
	d["bozze"] = bozze;
	d["secondi_prompt"] = e.secondi_prompt;
	d["secondi_generazione"] = e.secondi_generazione;
	d["token_prompt"] = e.token_prompt;
	d["token_generati"] = e.token_generati;
	// 0 = le copie hanno condiviso il prompt (la via veloce). Vedi
	// `Esito::riletture_prompt`: è un prezzo, e va misurato.
	d["riletture_prompt"] = e.riletture_prompt;
	d["errore"] = String::utf8(e.errore.c_str());
	return d;
}

void LlmLocale::annulla() {
	traduttore().annulla();
}

void LlmLocale::chiudi() {
	traduttore().chiudi();
}

void LlmLocale::spegni_tutto() {
	traduttore().chiudi();
}

Dictionary LlmLocale::misure() const {
	Dictionary d;
	const chibi::Traduttore &t = traduttore();
	d["stato"] = static_cast<int>(t.stato());
	d["pensieri"] = static_cast<int64_t>(t.quanti_pensieri());
	d["buttati"] = static_cast<int64_t>(t.quanti_annullati());
	d["secondi_caricamento"] = t.secondi_caricamento();
	d["caricamento"] = static_cast<double>(t.caricamento());
	d["diagnosi"] = String::utf8(t.diagnosi().c_str());
	d["n_thread_consigliati"] = chibi::n_thread_consigliati();
	return d;
}

void LlmLocale::_bind_methods() {
	ClassDB::bind_method(D_METHOD("avvia"), &LlmLocale::avvia);
	ClassDB::bind_method(D_METHOD("versione"), &LlmLocale::versione);
	ClassDB::bind_method(D_METHOD("info_sistema"), &LlmLocale::info_sistema);
	ClassDB::bind_method(D_METHOD("quanti_backend"), &LlmLocale::quanti_backend);
	ClassDB::bind_method(D_METHOD("backend"), &LlmLocale::backend);

	ClassDB::bind_method(D_METHOD("esamina", "percorso", "con_impronta"),
			&LlmLocale::esamina, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("impronta", "percorso"), &LlmLocale::impronta);
	ClassDB::bind_method(D_METHOD("memoria"), &LlmLocale::memoria);

	ClassDB::bind_method(D_METHOD("apri_modello", "percorso", "opzioni"),
			&LlmLocale::apri_modello, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("stato"), &LlmLocale::stato);
	ClassDB::bind_method(D_METHOD("pronto"), &LlmLocale::pronto);
	ClassDB::bind_method(D_METHOD("libero"), &LlmLocale::libero);
	ClassDB::bind_method(D_METHOD("caricamento"), &LlmLocale::caricamento);
	ClassDB::bind_method(D_METHOD("accoda", "chi", "sistema", "utente", "grammatica", "opzioni"),
			&LlmLocale::accoda, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("raccogli"), &LlmLocale::raccogli);
	ClassDB::bind_method(D_METHOD("annulla"), &LlmLocale::annulla);
	ClassDB::bind_method(D_METHOD("chiudi"), &LlmLocale::chiudi);
	ClassDB::bind_method(D_METHOD("misure"), &LlmLocale::misure);

	BIND_ENUM_CONSTANT(LLM_SPENTO);
	BIND_ENUM_CONSTANT(LLM_CARICA);
	BIND_ENUM_CONSTANT(LLM_PRONTO);
	BIND_ENUM_CONSTANT(LLM_PENSA);
	BIND_ENUM_CONSTANT(LLM_GUASTO);
}
