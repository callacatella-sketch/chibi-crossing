// IL BANCO DEL PORTIERE — un file guasto per processo, e si guarda chi muore.
//
// Perché un eseguibile a parte, e non un test dentro il gioco: la domanda a
// cui questo banco risponde è «cosa fa llama.cpp se il portiere NON c'è», e
// la risposta, per certi file, è `abort()`. Un abort dentro la suite si porta
// via il runner; un abort qui si porta via un processo che esiste per morire,
// e lo script che lo lancia legge il codice di uscita e va avanti.
//
// È anche la ragione per cui il ponte verso GDScript non ha una leva per
// spegnere il portiere: la leva la userebbe qualcuno.
//
// COME SI COMPILA (macOS; su Linux togli -framework Accelerate):
//
//   clang++ -std=c++17 -fexceptions -O1 -DCHIBI_LLM \
//     -Isrc -Isrc/thirdparty/llm-build/macos-universal/inst/include \
//     tools/portiere_vs_llama.cpp src/llm_gguf.cpp \
//     src/thirdparty/llm-build/macos-universal/inst/lib/libllama.a \
//     src/thirdparty/llm-build/macos-universal/inst/lib/libggml.a \
//     src/thirdparty/llm-build/macos-universal/inst/lib/libggml-cpu.a \
//     src/thirdparty/llm-build/macos-universal/inst/lib/libggml-blas.a \
//     src/thirdparty/llm-build/macos-universal/inst/lib/libggml-base.a \
//     -framework Accelerate -o /tmp/portiere_vs_llama
//
// COME SI USA:
//
//   portiere_vs_llama portiere <file.gguf>   → 0 accettato · 1 rifiutato
//   portiere_vs_llama llama    <file.gguf>   → 0 caricato  · 1 rifiutato
//                                              (o niente: il processo muore)
//   portiere_vs_llama campionatori <file.gguf> <sistema> <utente> <gbnf>
//                                            → il prezzo di ogni catena
//
// Lo script che tiene il conto è `tools/rovina_gguf.py`.
//
// ─────────────────────────────────────────────────────────────────────────
// PERCHÉ QUI DENTRO C'È ANCHE UN BANCO SUI CAMPIONATORI
// ─────────────────────────────────────────────────────────────────────────
//
// Perché la sonda dentro il gioco misura la configurazione VERA, e per
// capire un numero storto serve poterne cambiare UNA cosa per volta senza
// toccare il codice di produzione. Il numero storto era questo: con
// gemma-3-1b la lettura del prompt va a 149 gettoni/s e la scrittura a 4.4.
// Trentaquattro volte più lenta a scrivere che a leggere non è il modello:
// un 1B decodifica un gettone in pochi millisecondi. È il CAMPIONAMENTO, e
// la colpa è del vocabolario di gemma-3 — 262.144 parole, il doppio di
// llama-3 e otto volte quello di un modello vecchio. Ogni gettone scritto
// costa una passata su tutte.

#include "llm_gguf.h"
#include "llm_llama.h"

#include <chrono>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

namespace {

void zitto(ggml_log_level, const char *, void *) {}

double ms_da(const std::chrono::steady_clock::time_point &t) {
	return std::chrono::duration<double, std::milli>(
			std::chrono::steady_clock::now() - t)
			.count();
}

std::string leggi_tutto(const char *percorso) {
	std::FILE *f = std::fopen(percorso, "rb");
	if (f == nullptr) {
		return std::string();
	}
	std::string s;
	char buf[4096];
	size_t n;
	while ((n = std::fread(buf, 1, sizeof(buf), f)) > 0) {
		s.append(buf, n);
	}
	std::fclose(f);
	return s;
}

// Le quattro catene che vale la pena confrontare. Cambia UNA cosa per volta,
// che è l'unico modo di attribuire un millisecondo a qualcosa.
enum class Catena {
	SOLO_DADO, // il pavimento: costruire i candidati e tirare
	SENZA_GRAMMATICA, // penalità + top_k + top_p + temperatura
	GRAMMATICA_PRIMA, // quella di produzione: la grammatica vede tutto
	GRAMMATICA_DOPO, // top_k prima, la grammatica giudica solo i primi 40
};

const char *nome_catena(Catena c) {
	switch (c) {
		case Catena::SOLO_DADO: return "solo il dado";
		case Catena::SENZA_GRAMMATICA: return "senza grammatica";
		case Catena::GRAMMATICA_PRIMA: return "grammatica PRIMA (produzione)";
		case Catena::GRAMMATICA_DOPO: return "grammatica dopo top_k(40)";
	}
	return "?";
}

int campionatori(const std::string &file, const char *f_sistema, const char *f_utente,
		const char *f_gbnf) {
	llama_log_set(zitto, nullptr);
	ggml_log_set(zitto, nullptr);
	llama_backend_init();

	llama_model_params mp = llama_model_default_params();
	mp.n_gpu_layers = 0;
	llama_model *m = llama_model_load_from_file(file.c_str(), mp);
	if (m == nullptr) {
		std::fprintf(stderr, "il modello non si è aperto\n");
		return 1;
	}
	llama_context_params cp = llama_context_default_params();
	cp.n_ctx = 2048;
	cp.n_batch = 512;
	cp.n_ubatch = 512;
	cp.n_outputs_max = 1;
	cp.n_threads = 4;
	cp.n_threads_batch = 4;
	cp.no_perf = true;
	llama_context *ctx = llama_init_from_model(m, cp);
	if (ctx == nullptr) {
		llama_model_free(m);
		std::fprintf(stderr, "il contesto non si è creato\n");
		return 1;
	}
	const llama_vocab *v = llama_model_get_vocab(m);

	const std::string sistema = leggi_tutto(f_sistema);
	const std::string utente = leggi_tutto(f_utente);
	const std::string gbnf = leggi_tutto(f_gbnf);

	std::string prompt;
	const char *tmpl = llama_model_chat_template(m, nullptr);
	if (tmpl != nullptr) {
		llama_chat_message msg[2] = { { "system", sistema.c_str() }, { "user", utente.c_str() } };
		std::vector<char> buf((sistema.size() + utente.size()) * 2 + 1024);
		const int32_t n = llama_chat_apply_template(tmpl, msg, 2, true, buf.data(),
				int32_t(buf.size()));
		if (n > 0) {
			prompt.assign(buf.data(), size_t(n));
		}
	}
	if (prompt.empty()) {
		prompt = sistema + "\n\n" + utente;
	}

	const int32_t n_prompt = -llama_tokenize(v, prompt.c_str(), int32_t(prompt.size()),
			nullptr, 0, true, true);
	std::vector<llama_token> gettoni(size_t(n_prompt > 0 ? n_prompt : 1));
	llama_tokenize(v, prompt.c_str(), int32_t(prompt.size()), gettoni.data(), n_prompt, true, true);

	std::printf("modello: %s\n", file.c_str());
	std::printf("vocabolario: %d parole · prompt: %d gettoni\n\n",
			llama_vocab_n_tokens(v), n_prompt);

	llama_memory_t mem = llama_get_memory(ctx);
	const int n_tieni = n_prompt - 1;

	// La lettura del prompt si paga una volta: da qui in poi ogni catena
	// riparte dallo stesso punto.
	{
		const auto t = std::chrono::steady_clock::now();
		for (int i = 0; i < n_tieni;) {
			const int quanti = (n_tieni - i) < 512 ? (n_tieni - i) : 512;
			if (llama_decode(ctx, llama_batch_get_one(gettoni.data() + i, quanti)) != 0) {
				std::fprintf(stderr, "il prompt non si legge\n");
				return 1;
			}
			i += quanti;
		}
		const double ms = ms_da(t);
		std::printf("lettura del prompt: %.0f ms = %.1f gettoni/s\n\n",
				ms, double(n_tieni) * 1000.0 / ms);
	}

	const int QUANTI = 60;
	std::printf("%-32s %10s %10s %12s\n", "catena", "ms/gettone", "gettoni/s", "campionare");
	std::printf("%s\n", std::string(70, '-').c_str());

	for (Catena quale : { Catena::SOLO_DADO, Catena::SENZA_GRAMMATICA,
				 Catena::GRAMMATICA_PRIMA, Catena::GRAMMATICA_DOPO }) {
		llama_memory_seq_rm(mem, 0, n_tieni, -1);
		llama_sampler *catena = llama_sampler_chain_init(llama_sampler_chain_default_params());
		if (quale == Catena::GRAMMATICA_PRIMA) {
			llama_sampler *g = llama_sampler_init_grammar(v, gbnf.c_str(), "root");
			if (g == nullptr) {
				std::fprintf(stderr, "la grammatica non compila\n");
				return 1;
			}
			llama_sampler_chain_add(catena, g);
		}
		if (quale != Catena::SOLO_DADO) {
			llama_sampler_chain_add(catena, llama_sampler_init_penalties(
					llama_vocab_n_tokens(v), 64, 1.05f, 0.0f, 0.0f));
			llama_sampler_chain_add(catena, llama_sampler_init_top_k(40));
			llama_sampler_chain_add(catena, llama_sampler_init_top_p(0.9f, 1));
			llama_sampler_chain_add(catena, llama_sampler_init_temp(0.8f));
		}
		if (quale == Catena::GRAMMATICA_DOPO) {
			llama_sampler *g = llama_sampler_init_grammar(v, gbnf.c_str(), "root");
			if (g == nullptr) {
				std::fprintf(stderr, "la grammatica non compila\n");
				return 1;
			}
			llama_sampler_chain_add(catena, g);
		}
		llama_sampler_chain_add(catena, llama_sampler_init_dist(7u));

		llama_token ultimo = gettoni[size_t(n_tieni)];
		double ms_decode = 0.0, ms_campiona = 0.0;
		int fatti = 0;
		std::string morto;
		// ⚠️ IL TRY NON È PRUDENZA: una di queste catene TIRA DAVVERO. Con la
		// grammatica messa dopo top_k può capitare che tutti i quaranta
		// candidati rimasti siano vietati; allora il dado ne sceglie uno
		// comunque, e il passo dopo `llama_sampler_sample` tira «Unexpected
		// empty grammar stack after accepting piece». È la prova che l'ordine
		// della catena non è una questione di velocità ma di correttezza — e
		// il motivo per cui il thread del gioco ha un ombrello
		// (`Traduttore::_riparata`).
		try {
			for (int k = 0; k < QUANTI; ++k) {
				auto t = std::chrono::steady_clock::now();
				if (llama_decode(ctx, llama_batch_get_one(&ultimo, 1)) != 0) {
					break;
				}
				ms_decode += ms_da(t);
				t = std::chrono::steady_clock::now();
				const llama_token id = llama_sampler_sample(catena, ctx, -1);
				ms_campiona += ms_da(t);
				++fatti;
				if (llama_vocab_is_eog(v, id)) {
					break;
				}
				ultimo = id;
			}
		} catch (const std::exception &e) {
			morto = e.what();
		}
		llama_sampler_free(catena);
		if (!morto.empty()) {
			std::printf("%-32s   MUORE dopo %d gettoni: %s\n", nome_catena(quale),
					fatti, morto.c_str());
			continue;
		}
		const double totale = ms_decode + ms_campiona;
		std::printf("%-32s %10.1f %10.1f %11.0f%%\n", nome_catena(quale),
				totale / fatti, double(fatti) * 1000.0 / totale,
				100.0 * ms_campiona / totale);
	}
	std::printf("\n(«campionare» è la quota di tempo che NON è il modello: è la scelta\n"
				" del gettone fra le %d parole del vocabolario.)\n",
			llama_vocab_n_tokens(v));

	llama_free(ctx);
	llama_model_free(m);
	return 0;
}

} // namespace

int main(int argc, char **argv) {
	if (argc == 6 && std::string(argv[1]) == "campionatori") {
		return campionatori(argv[2], argv[3], argv[4], argv[5]);
	}
	if (argc != 3) {
		std::fprintf(stderr,
				"uso: portiere_vs_llama <portiere|llama> <file.gguf>\n"
				"     portiere_vs_llama campionatori <gguf> <sistema.txt> <utente.txt> <g.gbnf>\n");
		return 2;
	}
	const std::string cosa = argv[1];
	const std::string file = argv[2];

	if (cosa == "portiere") {
		const chibi::FattiGguf f = chibi::esamina_gguf(file, false);
		std::printf("%s\t%s\n", f.ok ? "ACCETTATO" : "rifiutato",
				f.ok ? (f.architettura + " " + f.quantizzazione).c_str() : f.motivo.c_str());
		return f.ok ? 0 : 1;
	}

	if (cosa == "llama") {
		// Silenzio: qui interessa il codice di uscita, non le duecento righe
		// che llama stampa caricando.
		llama_log_set(zitto, nullptr);
		ggml_log_set(zitto, nullptr);
		llama_backend_init();
		llama_model_params mp = llama_model_default_params();
		mp.n_gpu_layers = 0;
		llama_model *m = llama_model_load_from_file(file.c_str(), mp);
		if (m == nullptr) {
			std::printf("rifiutato\tllama_model_load_from_file ha tornato nullptr\n");
			return 1;
		}
		// Non basta aprirlo: un file troncato si apre benissimo e poi dà
		// SIGBUS quando qualcuno LEGGE le pagine mappate. Ci si arriva
		// creando il contesto e facendo una decode da un gettone — che è la
		// prima cosa che tocca i pesi davvero.
		llama_context_params cp = llama_context_default_params();
		cp.n_ctx = 256;
		cp.n_batch = 64;
		cp.n_ubatch = 64;
		cp.n_threads = 2;
		cp.n_threads_batch = 2;
		llama_context *ctx = llama_init_from_model(m, cp);
		if (ctx == nullptr) {
			llama_model_free(m);
			std::printf("rifiutato\til contesto non si è creato\n");
			return 1;
		}
		const llama_vocab *v = llama_model_get_vocab(m);
		llama_token t = llama_vocab_bos(v);
		if (t < 0) {
			t = 0;
		}
		const int rc = llama_decode(ctx, llama_batch_get_one(&t, 1));
		std::printf("%s\tllama_decode = %d\n", rc == 0 ? "ACCETTATO" : "rifiutato", rc);
		llama_free(ctx);
		llama_model_free(m);
		return rc == 0 ? 0 : 1;
	}

	std::fprintf(stderr, "non so fare «%s»\n", cosa.c_str());
	return 2;
}
