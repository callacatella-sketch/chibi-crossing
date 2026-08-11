#include "llm_ponte.h"

// Il confine. È l'unico include di llama.cpp di tutto il progetto, e sta qui
// dentro (non nell'header) apposta: chi include `llm_ponte.h` non eredita
// niente di llama.
#include "llm_llama.h"

#include <godot_cpp/core/class_db.hpp>
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
	if (p_livello >= GGML_LOG_LEVEL_ERROR) {
		UtilityFunctions::push_error(riga);
	} else {
		UtilityFunctions::push_warning(riga);
	}
}

bool g_acceso = false;

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

void LlmLocale::_bind_methods() {
	ClassDB::bind_method(D_METHOD("avvia"), &LlmLocale::avvia);
	ClassDB::bind_method(D_METHOD("versione"), &LlmLocale::versione);
	ClassDB::bind_method(D_METHOD("info_sistema"), &LlmLocale::info_sistema);
	ClassDB::bind_method(D_METHOD("quanti_backend"), &LlmLocale::quanti_backend);
	ClassDB::bind_method(D_METHOD("backend"), &LlmLocale::backend);
}
