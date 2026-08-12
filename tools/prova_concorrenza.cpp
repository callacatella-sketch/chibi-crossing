// IL BANCO DELLA CONCORRENZA — la finestra fra `accoda()` e il thread.
//
// Perché un eseguibile a parte, come `portiere_vs_llama.cpp`: la domanda a cui
// questo banco risponde è «cosa succede se `annulla()` arriva PRIMA che il
// thread abbia preso il lavoro», e per farsela serve un `Traduttore` vero, con
// un modello vero, e il controllo dei microsecondi. Dentro la suite non si può
// (senza modello `accoda()` rifiuta sempre, e quindi il difetto è invisibile);
// dentro Godot si può, ma il frame ci mette il suo rumore e la finestra è
// larga decine di microsecondi.
//
// ⚠️ IL DIFETTO CHE QUESTO BANCO HA TROVATO, detto in una riga: `accoda()`
// accende `_in_volo` mettendo in coda, e a spegnerlo è SOLO la fine di un
// lavoro ESEGUITO. Un `annulla()` che prende il lucchetto prima del thread
// buttava via il lavoro e lasciava `_in_volo` acceso PER SEMPRE — cioè
// `libero()` falso per sempre, cioè `accoda()` che rifiuta tutto per il resto
// del processo. Il villaggio ammutolisce, e non c'è una riga di log.
//
// COME SI COMPILA (macOS; su Linux togli -framework Accelerate):
//
//   clang++ -std=c++17 -fexceptions -O2 -DCHIBI_LLM \
//     -Isrc -Isrc/thirdparty/llm-build/macos-universal/inst/include \
//     tools/prova_concorrenza.cpp src/llm_pensieri.cpp src/llm_gguf.cpp \
//     src/llm_memoria.cpp \
//     src/thirdparty/llm-build/macos-universal/inst/lib/lib{llama,ggml,ggml-cpu,ggml-blas,ggml-base}.a \
//     -framework Accelerate -o /tmp/prova_concorrenza
//
// COME SI USA:
//
//   prova_concorrenza finestra  <gguf> [giri]
//       quanto dura la finestra fra `accoda()` e il momento in cui il thread
//       ha preso il lavoro. Non usa `annulla()`: si misura uguale prima e
//       dopo la correzione, ed è il numero che dice quanto è probabile il
//       difetto su una macchina carica.
//
//   prova_concorrenza annulla   <gguf> <ritardo_us> <giri>
//       N giri di «accoda, aspetta <ritardo_us>, annulla»: dopo ognuno il
//       motore deve tornare LIBERO e deve saper consegnare un altro pensiero.
//       Con ritardo 0 si cade dentro la finestra quasi sempre.
//
//   prova_concorrenza abbandono <gguf>
//       la rete del silenzio (`abbandono_in_corso`): dopo un annullamento
//       deve tornare a dire NO, o ogni errore di llama resta declassato ad
//       avviso per il resto del processo.

#include "llm_llama.h"
#include "llm_pensieri.h"

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <thread>
#include <vector>

namespace {

const char *GRAMMATICA = "root ::= riga riga riga\nriga ::= [a-z ,]+ \"\\n\"\n";
const char *SISTEMA = "Sei un gufo anziano che scrive lettere brevi a una gattina.";
const char *UTENTE = "Scrivi tre righe.";

double us_da(const std::chrono::steady_clock::time_point &t) {
	return std::chrono::duration<double, std::micro>(
			std::chrono::steady_clock::now() - t)
			.count();
}

void zitto(ggml_log_level, const char *, void *) {}

chibi::Richiesta richiesta(int p_copie, int p_max, uint32_t p_seme) {
	chibi::Richiesta r;
	r.chi = 1;
	r.sistema = SISTEMA;
	r.utente = UTENTE;
	r.grammatica = GRAMMATICA;
	r.copie = p_copie;
	r.max_token = p_max;
	r.seme = p_seme;
	return r;
}

// Apre il modello e aspetta che il thread si pronunci. Torna false se il
// modello non si è aperto: da lì in poi non c'è niente da misurare.
bool accendi(chibi::Traduttore &t, const std::string &file) {
	llama_log_set(zitto, nullptr);
	ggml_log_set(zitto, nullptr);
	chibi::Config c;
	c.modello = file;
	c.n_ctx = 512;
	c.priorita = 0; // il banco non ha un frame da difendere: si misura in fretta
	// e non ha né tetto né riserva: il modello lo sceglie chi lancia, e questo
	// banco misura la CONCORRENZA — non deve poter dire di no per la memoria
	c.tetto_byte = 0;
	c.riserva_byte = 0;
	if (!t.apri(c)) {
		std::printf("il traduttore non è nemmeno partito (percorso?)\n");
		return false;
	}
	const auto t0 = std::chrono::steady_clock::now();
	while (t.stato() == chibi::StatoLlm::CARICA && us_da(t0) < 300e6) {
		std::this_thread::sleep_for(std::chrono::milliseconds(20));
	}
	if (t.stato() != chibi::StatoLlm::PRONTO) {
		std::printf("il modello non si è aperto: %s\n", t.diagnosi().c_str());
		return false;
	}
	std::printf("modello aperto in %.1f s · %s\n\n", t.secondi_caricamento(),
			t.diagnosi().c_str());
	return true;
}

// Aspetta che il motore torni libero. Torna i millisecondi, oppure -1 se non
// è mai tornato (che è il difetto).
double aspetta_libero(chibi::Traduttore &t, double p_tetto_ms) {
	const auto t0 = std::chrono::steady_clock::now();
	while (!t.libero()) {
		if (us_da(t0) > p_tetto_ms * 1000.0) {
			return -1.0;
		}
		std::this_thread::sleep_for(std::chrono::microseconds(200));
	}
	return us_da(t0) / 1000.0;
}

// Un pensiero intero, dall'inizio alla fine. Torna false se non è arrivato.
bool un_pensiero(chibi::Traduttore &t, uint32_t p_seme, double p_tetto_ms = 60000.0) {
	const uint64_t b = t.accoda(richiesta(1, 8, p_seme));
	if (b == 0) {
		return false;
	}
	const auto t0 = std::chrono::steady_clock::now();
	chibi::Esito e;
	while (us_da(t0) < p_tetto_ms * 1000.0) {
		if (t.raccogli(e)) {
			return e.biglietto == b && !e.bozze.empty();
		}
		std::this_thread::sleep_for(std::chrono::microseconds(500));
	}
	return false;
}

// ── la finestra ──────────────────────────────────────────────────────────
int finestra(const std::string &file, int giri) {
	chibi::Traduttore t;
	if (!accendi(t, file)) {
		return 1;
	}
	std::vector<double> us;
	us.reserve(size_t(giri));
	for (int i = 0; i < giri; ++i) {
		const auto t0 = std::chrono::steady_clock::now();
		if (t.accoda(richiesta(1, 1, uint32_t(i + 1))) == 0) {
			std::printf("giro %d: accoda ha rifiutato (motore non libero)\n", i);
			return 1;
		}
		// il thread annuncia di aver preso il lavoro passando a PENSA: è la
		// prima cosa che fa DOPO aver lasciato il lucchetto del prelievo
		while (t.stato() != chibi::StatoLlm::PENSA) {
			std::this_thread::yield();
		}
		us.push_back(us_da(t0));
		chibi::Esito e;
		const auto t1 = std::chrono::steady_clock::now();
		while (!t.raccogli(e) && us_da(t1) < 60e6) {
			std::this_thread::sleep_for(std::chrono::microseconds(200));
		}
	}
	std::sort(us.begin(), us.end());
	std::printf("LA FINESTRA fra `accoda()` e il prelievo del thread (%d giri)\n", giri);
	std::printf("  minimo %.0f µs · mediana %.0f µs · p90 %.0f µs · MASSIMO %.0f µs\n",
			us.front(), us[us.size() / 2], us[size_t(double(us.size()) * 0.9)], us.back());
	std::printf("\n(è il tempo in cui un `annulla()` cade sul lavoro CHE NON È ANCORA\n"
				" PARTITO. Più la macchina è carica, più è larga — cioè il difetto è\n"
				" più probabile proprio quando il modello sta generando.)\n");
	return 0;
}

// ── annulla dentro la finestra ───────────────────────────────────────────
int annulla(const std::string &file, int ritardo_us, int giri) {
	chibi::Traduttore t;
	if (!accendi(t, file)) {
		return 1;
	}
	std::printf("ACCODA + ANNULLA a %d µs di distanza, %d giri\n", ritardo_us, giri);
	std::printf("%5s %10s %12s %10s %s\n", "giro", "accodato", "libero dopo", "pensiero", "abbandono");
	int appesi = 0;
	int muti = 0;
	for (int i = 0; i < giri; ++i) {
		const uint64_t b = t.accoda(richiesta(20, 128, uint32_t(100 + i)));
		if (b == 0) {
			std::printf("%5d %10s   — il motore non accetta più niente\n", i + 1, "RIFIUTATO");
			++appesi;
			break;
		}
		if (ritardo_us > 0) {
			const auto t0 = std::chrono::steady_clock::now();
			while (us_da(t0) < double(ritardo_us)) {
				std::this_thread::yield();
			}
		}
		const auto t_ann = std::chrono::steady_clock::now();
		t.annulla();
		const double ms_ann = us_da(t_ann) / 1000.0;
		const double ms_lib = aspetta_libero(t, 5000.0);
		// E la prova che conta: il villaggio sa ancora pensare?
		const bool vivo = ms_lib >= 0.0 && un_pensiero(t, uint32_t(500 + i));
		std::printf("%5d %10.3f %11s %10s %10s\n", i + 1, ms_ann,
				ms_lib < 0.0 ? "MAI" : (std::to_string(int(ms_lib)) + " ms").c_str(),
				vivo ? "arriva" : "PERSO", chibi::abbandono_in_corso() ? "APERTO" : "chiuso");
		if (ms_lib < 0.0) {
			++appesi;
			break;
		}
		if (!vivo) {
			++muti;
		}
	}
	std::printf("\nappesi: %d · muti: %d · pensieri fatti: %llu · buttati: %llu\n",
			appesi, muti, (unsigned long long)t.quanti_pensieri(),
			(unsigned long long)t.quanti_annullati());
	std::printf("abbandono_in_corso() alla fine: %s\n",
			chibi::abbandono_in_corso() ? "SÌ (la rete degli errori è spenta)" : "no");
	return (appesi == 0 && muti == 0 && !chibi::abbandono_in_corso()) ? 0 : 1;
}

// ── la rete del silenzio ─────────────────────────────────────────────────
int abbandono(const std::string &file) {
	chibi::Traduttore t;
	if (!accendi(t, file)) {
		return 1;
	}
	std::printf("LA RETE DEL SILENZIO (`abbandono_in_corso`)\n");
	std::printf("  a riposo                     : %s\n",
			chibi::abbandono_in_corso() ? "APERTO" : "chiuso");

	// 1. annulla mentre il lavoro è ancora IN CODA (la finestra)
	t.accoda(richiesta(20, 128, 11));
	t.annulla();
	aspetta_libero(t, 5000.0);
	std::printf("  dopo un annulla nella finestra: %s\n",
			chibi::abbandono_in_corso() ? "APERTO — la rete è spenta" : "chiuso");

	// 2. annulla mentre llama sta DAVVERO generando
	if (t.accoda(richiesta(20, 128, 12)) != 0) {
		const auto t0 = std::chrono::steady_clock::now();
		while (t.stato() != chibi::StatoLlm::PENSA && us_da(t0) < 5e6) {
			std::this_thread::yield();
		}
		std::this_thread::sleep_for(std::chrono::milliseconds(700));
		const bool dentro = t.stato() == chibi::StatoLlm::PENSA;
		t.annulla();
		std::printf("  durante la generazione       : %s (era davvero dentro llama: %s)\n",
				chibi::abbandono_in_corso() ? "APERTO (giusto)" : "chiuso",
				dentro ? "sì" : "no");
		const double ms = aspetta_libero(t, 5000.0);
		std::printf("  e si richiude quando molla   : %s dopo %.0f ms\n",
				chibi::abbandono_in_corso() ? "APERTO — NON si è richiusa" : "chiuso", ms);
	}
	const bool ok = !chibi::abbandono_in_corso();
	std::printf("\n%s\n", ok ? "la rete degli errori è di nuovo accesa."
							 : "GUASTO: da qui in poi ogni errore di llama è un avviso.");
	return ok ? 0 : 1;
}

} // namespace

int main(int argc, char **argv) {
	if (argc < 3) {
		std::fprintf(stderr,
				"uso: prova_concorrenza finestra  <gguf> [giri]\n"
				"     prova_concorrenza annulla   <gguf> <ritardo_us> <giri>\n"
				"     prova_concorrenza abbandono <gguf>\n");
		return 2;
	}
	const std::string cosa = argv[1];
	const std::string file = argv[2];
	if (cosa == "finestra") {
		return finestra(file, argc > 3 ? std::atoi(argv[3]) : 20);
	}
	if (cosa == "annulla") {
		return annulla(file, argc > 3 ? std::atoi(argv[3]) : 0, argc > 4 ? std::atoi(argv[4]) : 5);
	}
	if (cosa == "abbandono") {
		return abbandono(file);
	}
	std::fprintf(stderr, "non so fare «%s»\n", cosa.c_str());
	return 2;
}
