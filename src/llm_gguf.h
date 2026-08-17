#ifndef CHIBI_LLM_GGUF_H
#define CHIBI_LLM_GGUF_H

// IL PORTIERE — si legge il file PRIMA che lo legga llama.cpp.
//
// ─────────────────────────────────────────────────────────────────────────
// PERCHÉ ESISTE QUESTO FILE (la ragione è brutale e sta in una riga)
// ─────────────────────────────────────────────────────────────────────────
//
// `GGML_ASSERT` non è `assert()`. `NDEBUG` non lo spegne, non ha una callback,
// non torna: chiama `abort()`. Un `try` non lo prende — nemmeno il try/catch
// che `llama_model_load_from_file` ha dentro. Vuol dire che un `.gguf`
// corrotto, troncato o scritto male **si porta via il processo del
// giocatore**: non un errore da mostrare, non una lettera che non arriva —
// il gioco che sparisce.
//
// Questo file è la risposta a quel rischio, e non è una risposta completa:
// è un FILTRO messo prima della porta. Legge il .gguf per conto suo, con
// controlli di limite su ogni campo, e quando qualcosa non torna dice di no
// **senza** che llama lo abbia mai aperto.
//
// ─────────────────────────────────────────────────────────────────────────
// COSA ABORTISCE DAVVERO (misurato su b10326, non immaginato)
// ─────────────────────────────────────────────────────────────────────────
//
// Ho letto il codice di lettura di ggml e di llama e ho provato i file
// guasti uno per uno (`tools/rovina_gguf.py`). La superficie è più piccola
// di quel che si teme, ed è questa:
//
//  1. FILE TRONCATO. Il peggiore, e non è nemmeno un abort: llama mappa il
//     file in memoria (mmap) e legge i pesi da lì. Leggere oltre la fine di
//     una mappatura è **SIGBUS** — nessun messaggio, nessun log, niente. Il
//     lettore di ggml non se ne accorge perché i suoi controlli finiscono
//     dove finisce l'intestazione. Qui si controlla che il file arrivi almeno
//     fino all'ultimo byte dell'ultimo tensore.
//  2. ARRAY DI METADATI COL TIPO SBAGLIATO. Il ramo SCALARE di llama
//     (`GKV::get_kv`) TIRA un'eccezione se il tipo non combacia — quello è
//     sano, e il gioco lo vede come «modello non caricato». Il ramo ARRAY no:
//     `llama_model_loader::get_arr` fa `GGML_ASSERT(std::is_same<...>)`, cioè
//     abortisce. Un byte cambiato nel tipo di `tokenizer.ggml.tokens` basta.
//     Per questo, e SOLO per questo, qui sotto c'è una tabella di attese sui
//     pochi metadati che llama legge come array.
//  3. UNA DIMENSIONE A ZERO. Il lettore di ggml accetta `ne >= 0`, ma
//     `llama_model_loader::create_tensor` fa `GGML_ASSERT(ne >= 1)`. Zero
//     passa il primo e abortisce il secondo. Qui si pretende `>= 1`.
//
// ─────────────────────────────────────────────────────────────────────────
// IL RESIDUO, DICHIARATO (non provo a nasconderlo)
// ─────────────────────────────────────────────────────────────────────────
//
// Un file che passa di qui può ancora, in teoria, far abortire llama: gli
// iperparametri hanno invarianti interne che nessun controllo di forma può
// dedurre (`n_expert_used > 0`, le tabelle di rope, i tensori che un'arch si
// aspetta di trovare). Contro QUELLO c'è una sola difesa vera, ed è
// l'impronta: `esamina_gguf(..., con_impronta = true)` calcola lo SHA-256 del
// file, e `Motore::carica` rifiuta se non combacia con quello atteso. Un
// modello che il gioco ha già collaudato non può cambiare senza cambiare
// impronta. Il resto — un .gguf arbitrario messo lì da chi sviluppa — è
// scoperto, e va detto invece che dimenticato.
//
// Niente di tutto questo include Godot: si prova con un `main()` e si legge
// da un test. Il ponte verso GDScript sta in `llm_ponte.cpp`.

#include <cstdint>
#include <string>

namespace chibi {

// Quello che si sa di un file dopo averlo guardato. `ok == false` vuol dire
// che il file NON va dato in pasto a llama, e `motivo` dice perché in
// italiano leggibile (finisce nei log e nei provini, non in faccia a chi
// gioca: per chi gioca il modello semplicemente non c'è).
struct FattiGguf {
	bool ok = false;
	std::string motivo;

	// L'intestazione.
	uint32_t versione = 0;
	uint64_t byte_file = 0;
	int64_t n_tensori = 0;
	int64_t n_chiavi = 0;
	uint64_t allineamento = 32;
	uint64_t inizio_dati = 0; // dove comincia la sezione dei pesi
	uint64_t byte_dati = 0; // quanto occupano i pesi, allineamento compreso

	// Chi è.
	std::string architettura; // "gemma3", "llama", "qwen3"...
	std::string nome; // general.name, se c'è
	std::string quantizzazione; // il tipo ggml più diffuso fra i tensori: "Q4_K"
	uint64_t parametri = 0; // somma degli elementi di tutti i tensori
	int64_t vocabolario = 0; // quante voci ha tokenizer.ggml.tokens

	// Quanto è grande la sua testa (0 = il file non lo dice).
	uint32_t strati = 0;
	uint32_t contesto_addestramento = 0;
	uint32_t embedding = 0;
	uint32_t teste = 0;
	uint32_t teste_kv = 0;
	uint32_t dim_chiave = 0; // attention.key_length
	uint32_t dim_valore = 0; // attention.value_length

	// Vuota se non è stata chiesta: costa una lettura completa del file.
	std::string impronta;

	// Quanto è costato guardarlo.
	double ms_esame = 0.0;
	double ms_impronta = 0.0;
};

// Legge il file e lo giudica. Non alloca mai più di una manciata di kB:
// gli array di metadati (il vocabolario sono 260.000 stringhe) si
// ATTRAVERSANO senza tenerli, perché qui interessa che siano ben formati,
// non cosa dicono.
//
// `con_impronta` aggiunge lo SHA-256 del file intero: sono un paio di
// secondi su un modello da un giga, quindi è una scelta di chi chiama —
// e va fatta fuori dal frame, come tutto il resto di questa fase.
FattiGguf esamina_gguf(const std::string &percorso, bool con_impronta);

// La memoria che servirà DAVVERO, stimata prima di provarci: i pesi (che
// llama mappa dal file) più la cache delle chiavi/valori per `n_ctx` gettoni.
// È una stima per il CANCELLO — «questo modello non ci sta nel tetto, non
// aprirlo nemmeno» — non un numero da mostrare: quello vero lo dà
// `LlmLocale.memoria()` dopo il carico, misurato sul processo.
//
// ⚠️ SBAGLIA PER ECCESSO, ED È VOLUTO. La cache si conta a finestra piena su
// TUTTI gli strati; le architetture a finestra scorrevole (gemma-3) ne
// tengono molto meno su quasi tutti. Misurato: per gemma-3-1b a 2048 gettoni
// la stima dice 814 MB e il processo ne prende 588. Un cancello che
// sottostima lascia entrare il modello che poi manda in swap la macchina di
// chi gioca; uno che sovrastima, al peggio, chiede un modello un po' più
// piccolo. Il verso dell'errore è una decisione, non un difetto.
uint64_t stima_byte_kv(const FattiGguf &f, uint32_t n_ctx);
uint64_t stima_byte_totali(const FattiGguf &f, uint32_t n_ctx);

// Lo SHA-256 di un file, in esadecimale minuscolo. Vuoto se il file non si
// legge. Sta qui perché è il compagno dell'esame, e perché l'impronta è
// l'unica difesa vera contro il residuo dichiarato qui sopra.
//
// ⚠️ SI PUÒ MOLLARE A METÀ, e non è un lusso: dal 2026-08-13 il gioco spedisce
// il suo modello e questa funzione gira sul thread del traduttore a ogni
// avvio, su due gigabyte e mezzo. MISURATO: 11.7 s a priorità normale e
// **37.4 s** alla priorità di fondo che usa il gioco (su macOS la QoS di
// fondo strozza anche l'I/O — è la stessa nota che sta in `Config::priorita`).
// `Traduttore::chiudi()` fa `_thread.join()`: senza una via d'uscita, chi
// torna al titolo mentre l'impronta si calcola aspetterebbe fino a
// trentasette secondi con lo schermo fermo. È esattamente il guasto che le
// «tre uscite» della Fase 5 hanno chiuso (40 s → 6 ms) e che non si può
// riaprire da un'altra porta.
//
// `molla` viene interrogata a ogni blocco da 1 MB (≈5 ms di lettura): se
// risponde `true` la funzione torna **stringa vuota**, come per un file che
// non si legge. Chi chiama deve saperlo — le due risposte si distinguono
// riguardando la propria ragione di mollare, non l'impronta.
std::string impronta_file(const std::string &percorso, double *ms_fuori = nullptr,
		bool (*molla)(void *) = nullptr, void *molla_dato = nullptr);

} // namespace chibi

#endif // CHIBI_LLM_GGUF_H
