#ifndef CHIBI_LLM_LLAMA_H
#define CHIBI_LLM_LLAMA_H

// L'UNICO posto del progetto autorizzato a includere llama.cpp.
//
// È lo stesso idioma di `ecs_entt.h`, per la stessa ragione: i due rami del
// SConstruct compilano con impostazioni ASIMMETRICHE, e llama.cpp non le
// eredita affatto — se le sceglie da sé, perché lo compila la SUA CMake. Qui
// le asimmetrie si pareggiano una volta sola; chi includesse `llama.h` da un
// altro .cpp le riaprirebbe tutte, e nessun test se ne accorgerebbe (il
// difetto uscirebbe come un comportamento diverso fra Windows e macOS, o
// peggio come un `std::terminate` sul PC di un giocatore).
//
// 1) LE ECCEZIONI, ed è la ragione per cui questo file esiste.
//    godot-cpp compila i nostri sorgenti con `-fno-exceptions` su macOS e
//    Linux (godot-cpp/tools/common_compiler_flags.py). llama.cpp compila i
//    suoi CON le eccezioni, e le usa: `llama_model_load_from_file` e
//    `llama_init_from_model` si riprendono da sole (hanno il loro try/catch e
//    tornano `nullptr`), ma `llama_decode`, `llama_tokenize` e
//    `llama_token_to_piece` NO — lì un `std::bad_alloc` o un errore di vocabo
//    RISALE nelle chiamate. Se il primo frame che incontra è compilato senza
//    eccezioni, non c'è nessun catch possibile: è `std::terminate`, cioè il
//    gioco che sparisce mentre il Gufo scrive una lettera.
//    Per questo il SConstruct compila `src/llm_*.cpp` — e SOLO quelli — con
//    `-fexceptions`: il confine è l'unico posto del gioco che può PRENDERE
//    un'eccezione e trasformarla in un errore di ritorno. Le due righe qui
//    sotto sono la guardia: se un domani quel flag sparisse dal SConstruct,
//    la build FALLISCE invece di diventare in silenzio una macchina da
//    terminate.
// 2) GLI ASSERT DI GGML NON SONO assert(). `NDEBUG` non li spegne: sono
//    `GGML_ABORT`, e chiamano `abort()`. Non c'è callback, non c'è ritorno,
//    non c'è modo di intercettarli da qui — un .gguf corrotto o troncato può
//    portarsi via il processo del giocatore. È un residuo DICHIARATO di
//    questa fase: chi porterà il modello vero deve validarlo prima di darlo
//    in pasto a llama (e valutare se farlo girare in un processo suo, che è
//    l'unica difesa vera contro un abort). Nessun `try` lo prende.
// 3) I LOG. llama.cpp scrive su stderr per conto suo, a pagine: il caricamento
//    di un modello sono decine di righe. Dentro Godot finirebbero mescolate
//    agli errori veri, e dentro la suite headless sporcherebbero proprio il
//    conteggio degli `SCRIPT ERROR` su cui questo progetto si fida. Il ponte
//    installa una callback (`llm_ponte.cpp`) e la installa PRIMA di ogni
//    altra chiamata a llama.
// 4) LA SIMD. I nostri oggetti e quelli di ggml hanno flag di architettura
//    DIVERSI (ggml compila con la baseline Haswell su x86, e con quello che
//    trova su ARM; noi con i flag di godot-cpp). Va bene solo finché
//    nell'interfaccia non passano tipi la cui rappresentazione dipende dai
//    flag: verificato a mano su b10326 — `ggml_fp16_t` è un `uint16_t`
//    semplice (ggml.h:370), non un `_Float16`. Se un domani diventasse un
//    tipo nativo, questa riga è il posto in cui accorgersene.
// 5) IL C, E SOLO IL C. Di llama.cpp si usa `llama.h` e `ggml.h`, che sono
//    interfacce C. Mai `llama-cpp.h` (RAII), mai niente di `common/` — che
//    infatti non viene nemmeno compilato (LLAMA_BUILD_COMMON=OFF): fa uso
//    disinvolto di eccezioni e di `std::string` attraverso il confine, e due
//    librerie standard compilate con flag diversi che si scambiano container
//    è il modo classico di rompersi in produzione, non in prova.

#ifndef CHIBI_LLM
#error "llm_llama.h è entrato in una build senza `llm=yes`. Il gioco DEVE compilare identico senza llama.cpp: nessun file del cuore può includere questo header fuori da `src/llm_*.cpp`."
#endif

#if defined(_MSC_VER)
#if !defined(_CPPUNWIND)
#error "Il confine con llama.cpp va compilato con le eccezioni ACCESE (/EHsc): senza, un throw di llama_decode è un terminate. Vedi il punto 1."
#endif
#elif !defined(__EXCEPTIONS)
#error "Il confine con llama.cpp va compilato con le eccezioni ACCESE (-fexceptions): senza, un throw di llama_decode è un terminate. Vedi il punto 1 e `_llm_sorgenti_ponte` nel SConstruct."
#endif

// Gli header arrivano dal `cmake --install` che fa il SConstruct
// (`src/thirdparty/llm-build/<piattaforma>-<arch>/inst/include`): parentesi
// angolari e non virgolette, così è chiaro che vengono da fuori casa.
#include <ggml-backend.h>
#include <ggml.h>
#include <llama.h>

#endif // CHIBI_LLM_LLAMA_H
