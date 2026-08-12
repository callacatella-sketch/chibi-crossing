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
#include <godot_cpp/variant/dictionary.hpp>
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

	// IL TRADUTTORE È UNO SOLO IN TUTTO IL PROCESSO, e questa classe è un
	// MANIGLIONE, non il proprietario. `Llm.apri()` fa `ClassDB.instantiate`
	// ogni volta che qualcuno chiede: se ogni istanza avesse il suo modello,
	// due chiamate vorrebbero dire quattro gigabyte su una macchina che ne ha
	// otto — e la seconda si prende l'errore di allocazione a metà partita.
	// Il modello è una risorsa del processo, esattamente come il registro dei
	// backend di ggml qui sotto.
	enum Stato {
		LLM_SPENTO = 0,
		LLM_CARICA = 1,
		LLM_PRONTO = 2,
		LLM_PENSA = 3,
		LLM_GUASTO = 4,
	};

	// --- il modello ------------------------------------------------------
	// Apre il .gguf. TORNA SUBITO (il caricamento è sul thread: da 12 a 84
	// secondi misurati — e il frame, misurato, non se ne accorge: durante il
	// caricamento zero frame sopra il doppio della mediana). `false` = non ci ha
	// nemmeno provato: percorso vuoto, file assente, oppure c'è già un
	// modello aperto. Non è un guasto — è la configurazione normale di chi
	// non ha il modello, e il gioco va avanti con i testi scritti a mano.
	//
	// `p_opzioni` (tutte facoltative): n_ctx, n_thread, priorita, gpu,
	// max_token. Restano manopole da PROVINO: i valori di serie sono quelli
	// misurati, e chi li muove deve rimisurare il frame peggiore.
	bool apri_modello(const String &p_percorso, const Dictionary &p_opzioni);
	int stato() const;
	bool pronto() const;
	// «posso chiedergli un pensiero adesso?» — è la domanda del frame, ed è
	// senza lock: due atomici. Si può chiamare sessanta volte al secondo.
	bool libero() const;
	double caricamento() const;

	// --- i pensieri ------------------------------------------------------
	// Mette in coda UN pensiero e torna il biglietto (0 = rifiutato). Il
	// prompt arriva in due metà da `Suggeritore.parti()`; la grammatica da
	// `Suggeritore.grammatica()` ed è OBBLIGATORIA.
	//
	// `p_chi` è l'handle ECS di quel vicino: il ponte non lo guarda, lo porta
	// a spasso e lo restituisce. Chi riceve deve controllare che sia ancora
	// vivo — un handle morto non risolve, ed è la stessa disciplina del
	// soggetto dentro un ricordo.
	int64_t accoda(int64_t p_chi, const String &p_sistema, const String &p_utente,
			const String &p_grammatica, const Dictionary &p_opzioni);

	// Ritira un pensiero finito, oppure `{}` — che è il caso normale, e
	// costa UN atomico. Chiavi: biglietto, chi, bozze (PackedStringArray),
	// secondi_prompt, secondi_generazione, token_prompt, token_generati,
	// errore.
	Dictionary raccogli();

	// Butta il lavoro in volo. NON BLOCCA: si chiama al cambio di scena.
	void annulla();
	// Spegne il thread e libera il modello. Bloccante, idempotente. La
	// chiama anche lo spegnimento della GDExtension, che è la rete di
	// sicurezza: un thread vivo dentro una libreria che si sta scaricando è
	// un crash all'uscita, e all'uscita non lo vede nessuno.
	void chiudi();

	static void spegni_tutto();

	Dictionary misure() const;

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

	// --- il portiere ------------------------------------------------------
	// GUARDA UN .gguf SENZA APRIRLO CON LLAMA, e dice se è sano. Serve a chi
	// installa un modello (un provino, un pannello, un domani in cui il gioco
	// scaricherà il suo), e serve ai test: la stessa funzione che sta davanti
	// al caricamento vero, chiamabile su un file qualunque senza rischiare
	// niente. Vedi `llm_gguf.h` per cosa può e cosa non può.
	//
	// Chiavi tornate: ok, motivo, versione, byte_file, byte_pesi, tensori,
	// chiavi, architettura, nome, quantizzazione, parametri, vocabolario,
	// strati, contesto_addestramento, embedding, teste, teste_kv, impronta,
	// ms_esame, ms_impronta, byte_stimati_2k, byte_stimati_4k.
	//
	// `p_con_impronta` aggiunge lo SHA-256: costa una lettura intera del file
	// (secondi), quindi NON si chiama nel frame.
	Dictionary esamina(const String &p_percorso, bool p_con_impronta = false);

	// Lo SHA-256 di un file, per chi vuole solo quello (per esempio per
	// scriverselo da qualche parte e poi pretenderlo).
	String impronta(const String &p_percorso);

	// Quanto pesa QUESTO PROCESSO adesso, in byte: { impronta, residente }.
	// È il metro del tetto dei 2 GB, e va letto col gioco acceso — che è
	// l'unico posto da cui il numero è quello vero. Zero = la piattaforma non
	// lo sa dire (vedi `llm_memoria.cpp`).
	Dictionary memoria() const;
};

} // namespace godot

VARIANT_ENUM_CAST(godot::LlmLocale::Stato);

#endif // CHIBI_LLM_PONTE_H
