#ifndef CHIBI_LLM_PONTE_H
#define CHIBI_LLM_PONTE_H

// Il ponte fra il gioco e llama.cpp — la Fase 5 comincia da qui.
//
// ATTENZIONE, e vale per chiunque ci lavorerà sopra: questo header NON include
// `llama.h`, e non deve mai farlo. Lo include solo `llm_ponte.cpp`, passando
// per `llm_llama.h` (il confine). Così `register_types.cpp` — che è compilato
// con le impostazioni di TUTTO il resto del cuore — non vede niente di
// llama.cpp: nemmeno un tipo, nemmeno un enum.
//
// L'intero file esiste solo con `scons llm=yes`: senza, non viene proprio
// compilato (vedi il SConstruct), la classe `LlmLocale` non esiste, e
// `ClassDB.class_exists("LlmLocale")` risponde `false`. È IL segnale con cui
// il gioco sa se ha un cuore che scrive — e la risposta `false` non è un
// guasto: è la configurazione normale, quella di chi ha il gioco senza il
// modello.

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class LlmLocale : public RefCounted {
	GDCLASS(LlmLocale, RefCounted)

protected:
	static void _bind_methods();

public:
	LlmLocale();
	~LlmLocale();

	// Accende llama.cpp: dirotta i suoi log dentro quelli di Godot e inizializza
	// il registro dei backend. Idempotente, e chiamata da sola dal costruttore:
	// nessun altro sistema deve ricordarsi di farlo.
	void avvia();

	// "0.19.0 (3653e6d)" — la versione di ggml e il commit da cui è compilata.
	// È l'unico posto in cui il gioco può dire QUALE llama.cpp ha dentro.
	String versione() const;

	// La riga con cui llama.cpp dichiara le istruzioni che ha compilato
	// (NEON / AVX2 / FMA / F16C...). Serve a leggere nei log della CI se la
	// baseline è quella che il SConstruct ha chiesto: un binario che dice
	// AVX2 = 0 è un binario lento su tutte le macchine, e non lo direbbe
	// nessun'altra prova.
	String info_sistema() const;

	// Quanti backend di calcolo si sono registrati (CPU, Metal, ...). Se
	// tornasse 0, gli archivi statici sono stati linkati ma i costruttori del
	// registro no — è il modo silenzioso in cui una build "riuscita" può
	// essere inutile.
	int64_t quanti_backend() const;

	// Il nome di ognuno, in ordine.
	PackedStringArray backend() const;
};

} // namespace godot

#endif // CHIBI_LLM_PONTE_H
