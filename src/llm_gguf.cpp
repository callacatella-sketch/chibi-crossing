#include "llm_gguf.h"

// Il confine: `ggml.h` serve per le TAGLIE DEI BLOCCHI dei tipi quantizzati
// (`ggml_blck_size`, `ggml_type_size`, `ggml_type_name`). Sono tabelle, e
// sono la fonte unica: riscriverle qui vorrebbe dire tenerne due allineate a
// mano, e la seconda comincerebbe a mentire al primo tipo nuovo. Si chiamano
// SOLO dopo aver verificato che il tipo stia nell'intervallo — sono indici in
// un array, e un indice fuori posto in ggml non è un errore, è un abort.
#include "llm_llama.h"

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <map>
#include <set>
#include <string>
#include <vector>

namespace chibi {

namespace {

// ───────────────────────────────────────────────────────────────────────────
// SHA-256. Cento righe, nessuna dipendenza.
//
// Perché a mano e non una libreria: le due che avremmo (CommonCrypto su
// macOS, bcrypt su Windows) sono DIVERSE su ogni piattaforma, e questa è la
// funzione che decide se un file entra o no nel gioco. Una decisione di
// sicurezza che si comporta diversamente fra Windows e macOS è il difetto che
// da un Mac non si può vedere — la stessa ragione per cui esiste `llm_llama.h`.
// ───────────────────────────────────────────────────────────────────────────

struct Sha256 {
	uint32_t stato[8] = { 0x6a09e667u, 0xbb67ae85u, 0x3c6ef372u, 0xa54ff53au,
		0x510e527fu, 0x9b05688cu, 0x1f83d9abu, 0x5be0cd19u };
	uint64_t quanti = 0;
	uint8_t coda[64] = {};
	size_t in_coda = 0;

	static uint32_t ruota(uint32_t x, int n) { return (x >> n) | (x << (32 - n)); }

	void blocco(const uint8_t *p) {
		static const uint32_t K[64] = {
			0x428a2f98u, 0x71374491u, 0xb5c0fbcfu, 0xe9b5dba5u, 0x3956c25bu, 0x59f111f1u,
			0x923f82a4u, 0xab1c5ed5u, 0xd807aa98u, 0x12835b01u, 0x243185beu, 0x550c7dc3u,
			0x72be5d74u, 0x80deb1feu, 0x9bdc06a7u, 0xc19bf174u, 0xe49b69c1u, 0xefbe4786u,
			0x0fc19dc6u, 0x240ca1ccu, 0x2de92c6fu, 0x4a7484aau, 0x5cb0a9dcu, 0x76f988dau,
			0x983e5152u, 0xa831c66du, 0xb00327c8u, 0xbf597fc7u, 0xc6e00bf3u, 0xd5a79147u,
			0x06ca6351u, 0x14292967u, 0x27b70a85u, 0x2e1b2138u, 0x4d2c6dfcu, 0x53380d13u,
			0x650a7354u, 0x766a0abbu, 0x81c2c92eu, 0x92722c85u, 0xa2bfe8a1u, 0xa81a664bu,
			0xc24b8b70u, 0xc76c51a3u, 0xd192e819u, 0xd6990624u, 0xf40e3585u, 0x106aa070u,
			0x19a4c116u, 0x1e376c08u, 0x2748774cu, 0x34b0bcb5u, 0x391c0cb3u, 0x4ed8aa4au,
			0x5b9cca4fu, 0x682e6ff3u, 0x748f82eeu, 0x78a5636fu, 0x84c87814u, 0x8cc70208u,
			0x90befffau, 0xa4506cebu, 0xbef9a3f7u, 0xc67178f2u
		};
		uint32_t w[64];
		for (int i = 0; i < 16; ++i) {
			w[i] = (uint32_t(p[i * 4]) << 24) | (uint32_t(p[i * 4 + 1]) << 16) |
					(uint32_t(p[i * 4 + 2]) << 8) | uint32_t(p[i * 4 + 3]);
		}
		for (int i = 16; i < 64; ++i) {
			const uint32_t s0 = ruota(w[i - 15], 7) ^ ruota(w[i - 15], 18) ^ (w[i - 15] >> 3);
			const uint32_t s1 = ruota(w[i - 2], 17) ^ ruota(w[i - 2], 19) ^ (w[i - 2] >> 10);
			w[i] = w[i - 16] + s0 + w[i - 7] + s1;
		}
		uint32_t a = stato[0], b = stato[1], c = stato[2], d = stato[3];
		uint32_t e = stato[4], f = stato[5], g = stato[6], h = stato[7];
		for (int i = 0; i < 64; ++i) {
			const uint32_t S1 = ruota(e, 6) ^ ruota(e, 11) ^ ruota(e, 25);
			const uint32_t ch = (e & f) ^ ((~e) & g);
			const uint32_t t1 = h + S1 + ch + K[i] + w[i];
			const uint32_t S0 = ruota(a, 2) ^ ruota(a, 13) ^ ruota(a, 22);
			const uint32_t mj = (a & b) ^ (a & c) ^ (b & c);
			const uint32_t t2 = S0 + mj;
			h = g; g = f; f = e; e = d + t1;
			d = c; c = b; b = a; a = t1 + t2;
		}
		stato[0] += a; stato[1] += b; stato[2] += c; stato[3] += d;
		stato[4] += e; stato[5] += f; stato[6] += g; stato[7] += h;
	}

	void mangia(const uint8_t *p, size_t n) {
		quanti += n;
		while (n > 0) {
			if (in_coda == 0 && n >= 64) {
				blocco(p);
				p += 64;
				n -= 64;
				continue;
			}
			const size_t quanto = std::min(n, size_t(64) - in_coda);
			std::memcpy(coda + in_coda, p, quanto);
			in_coda += quanto;
			p += quanto;
			n -= quanto;
			if (in_coda == 64) {
				blocco(coda);
				in_coda = 0;
			}
		}
	}

	std::string chiudi() {
		const uint64_t bit = quanti * 8;
		uint8_t uno = 0x80;
		mangia(&uno, 1);
		const uint8_t zero = 0;
		while (in_coda != 56) {
			mangia(&zero, 1);
		}
		uint8_t coda_bit[8];
		for (int i = 0; i < 8; ++i) {
			coda_bit[i] = uint8_t((bit >> (56 - i * 8)) & 0xff);
		}
		// `mangia` aggiornerebbe `quanti`, ma qui non serve più a nessuno.
		mangia(coda_bit, 8);
		static const char *cifre = "0123456789abcdef";
		std::string esa;
		esa.reserve(64);
		for (int i = 0; i < 8; ++i) {
			for (int b = 3; b >= 0; --b) {
				const uint8_t v = uint8_t((stato[i] >> (b * 8)) & 0xff);
				esa.push_back(cifre[v >> 4]);
				esa.push_back(cifre[v & 0xf]);
			}
		}
		return esa;
	}
};

// ───────────────────────────────────────────────────────────────────────────
// Il lettore con la museruola: ogni lettura sa dov'è la fine del file.
// ───────────────────────────────────────────────────────────────────────────

// Un nome di chiave o di tensore più lungo di così non è un nome: è un campo
// di lunghezza che ha preso un bit sbagliato. (ggml accetta stringhe fino a
// un gigabyte; noi non abbiamo motivo di essere così generosi con un CAMPO
// DI TESTA, e la generosità qui si paga in allocazioni.)
constexpr uint64_t MAX_NOME = 1024;
// I valori stringa invece possono essere lunghi davvero: il template di chat
// di un modello istruito sono decine di migliaia di caratteri.
constexpr uint64_t MAX_VALORE = 1u << 26; // 64 MB
// Nessun modello vero ha più metadati o più tensori di così. Il tetto serve a
// non farsi allocare un milione di stringhe da un numero corrotto.
constexpr int64_t MAX_CHIAVI = 1 << 20;
constexpr int64_t MAX_TENSORI = 1 << 20;
constexpr uint64_t MAX_ELEMENTI_ARRAY = 1u << 30;

struct Lettore {
	std::FILE *f = nullptr;
	uint64_t dim = 0;
	uint64_t pos = 0;
	std::string guasto;

	bool male(const std::string &m) {
		if (guasto.empty()) {
			guasto = m;
		}
		return false;
	}

	bool grezzo(void *dove, uint64_t quanti) {
		if (quanti > dim || pos > dim - quanti) {
			return male("il file finisce prima di quello che dichiara "
						"(byte " + std::to_string(pos) + " di " + std::to_string(dim) + ")");
		}
		if (std::fread(dove, 1, size_t(quanti), f) != quanti) {
			return male("lettura interrotta a " + std::to_string(pos));
		}
		pos += quanti;
		return true;
	}

	bool salta(uint64_t quanti) {
		if (quanti > dim || pos > dim - quanti) {
			return male("un campo dichiara " + std::to_string(quanti) +
					" byte che nel file non ci sono");
		}
		if (
#ifdef _WIN32
				_fseeki64(f, (long long)quanti, SEEK_CUR)
#else
				fseeko(f, (off_t)quanti, SEEK_CUR)
#endif
				!= 0) {
			return male("non riesco a saltare nel file");
		}
		pos += quanti;
		return true;
	}

	bool u32(uint32_t &v) { return grezzo(&v, 4); }
	bool u64(uint64_t &v) { return grezzo(&v, 8); }
	bool i64(int64_t &v) { return grezzo(&v, 8); }

	// Una stringa GGUF: lunghezza a 64 bit e poi i byte, senza terminatore.
	bool stringa(std::string &s, uint64_t massimo) {
		uint64_t n = 0;
		if (!u64(n)) {
			return false;
		}
		if (n > massimo) {
			return male("una stringa dichiara " + std::to_string(n) +
					" byte: non è un testo, è un campo di lunghezza corrotto");
		}
		if (n > dim || pos > dim - n) {
			return male("una stringa esce dal file");
		}
		s.resize(size_t(n));
		if (n > 0 && std::fread(&s[0], 1, size_t(n), f) != n) {
			return male("lettura interrotta dentro una stringa");
		}
		pos += n;
		return true;
	}

	// Come sopra, ma senza tenersela: è così che si attraversano le 260.000
	// voci del vocabolario senza allocare niente.
	bool salta_stringa(uint64_t massimo) {
		uint64_t n = 0;
		if (!u64(n)) {
			return false;
		}
		if (n > massimo) {
			return male("una stringa dichiara " + std::to_string(n) + " byte");
		}
		return salta(n);
	}
};

uint64_t byte_del_tipo(uint32_t t) {
	switch (t) {
		case GGUF_TYPE_UINT8:
		case GGUF_TYPE_INT8:
		case GGUF_TYPE_BOOL: return 1;
		case GGUF_TYPE_UINT16:
		case GGUF_TYPE_INT16: return 2;
		case GGUF_TYPE_UINT32:
		case GGUF_TYPE_INT32:
		case GGUF_TYPE_FLOAT32: return 4;
		case GGUF_TYPE_UINT64:
		case GGUF_TYPE_INT64:
		case GGUF_TYPE_FLOAT64: return 8;
		default: return 0; // STRING e ARRAY non hanno taglia fissa
	}
}

const char *nome_tipo(uint32_t t) {
	switch (t) {
		case GGUF_TYPE_UINT8: return "u8";
		case GGUF_TYPE_INT8: return "i8";
		case GGUF_TYPE_UINT16: return "u16";
		case GGUF_TYPE_INT16: return "i16";
		case GGUF_TYPE_UINT32: return "u32";
		case GGUF_TYPE_INT32: return "i32";
		case GGUF_TYPE_FLOAT32: return "f32";
		case GGUF_TYPE_BOOL: return "bool";
		case GGUF_TYPE_STRING: return "stringa";
		case GGUF_TYPE_ARRAY: return "array";
		case GGUF_TYPE_UINT64: return "u64";
		case GGUF_TYPE_INT64: return "i64";
		case GGUF_TYPE_FLOAT64: return "f64";
		default: return "?";
	}
}

// ───────────────────────────────────────────────────────────────────────────
// LE ATTESE SUGLI ARRAY, e perché la tabella è così corta.
//
// Non è una copia del formato GGUF: è l'elenco esatto dei metadati che llama
// legge con `llama_model_loader::get_arr`, che è l'UNICO punto della lettura
// dove un tipo sbagliato diventa un `abort()` invece di un'eccezione (il ramo
// scalare, `GKV::get_kv`, tira `std::runtime_error` e il gioco lo vede come
// «modello non caricato» — sano). Ogni riga qui sotto chiude una porta
// misurata, non una immaginata; le chiavi che finiscono col nome dell'arch
// davanti si riconoscono dalla CODA, così la tabella non deve conoscere le
// sessanta architetture di llama.cpp.
//
// Se un domani llama leggesse un array nuovo, il peggio che può capitare è
// che questo filtro non lo copra: non che rifiuti un modello buono. Le attese
// sono TUTTE nella forma «se c'è, dev'essere così».
// ───────────────────────────────────────────────────────────────────────────

enum class Attesa {
	stringhe, // array di stringhe
	interi, // array di i32/u32 (llama li legge come uint32_t/int32_t)
	reali, // array di f32
};

struct RigaAttesa {
	const char *chiave;
	bool per_coda; // true = si confronta la fine della chiave (dopo l'arch)
	Attesa attesa;
};

const RigaAttesa ATTESE[] = {
	{ "tokenizer.ggml.tokens", false, Attesa::stringhe },
	{ "tokenizer.ggml.merges", false, Attesa::stringhe },
	{ "tokenizer.ggml.token_type", false, Attesa::interi },
	{ "tokenizer.ggml.scores", false, Attesa::reali },
	{ ".attention.head_count", true, Attesa::interi },
	{ ".attention.head_count_kv", true, Attesa::interi },
	{ ".feed_forward_length", true, Attesa::interi },
	{ ".rope.dimension_sections", true, Attesa::interi },
	{ ".attention.layer_norm_rms_epsilon", true, Attesa::reali },
	{ ".attention.layer_norm_epsilon", true, Attesa::reali },
};

bool finisce_con(const std::string &s, const char *coda) {
	const size_t n = std::strlen(coda);
	return s.size() >= n && s.compare(s.size() - n, n, coda) == 0;
}

// Torna "" se va bene, altrimenti il motivo del rifiuto.
std::string attesa_rispettata(const std::string &chiave, uint32_t tipo_elemento) {
	for (const RigaAttesa &r : ATTESE) {
		const bool mia = r.per_coda ? finisce_con(chiave, r.chiave) : chiave == r.chiave;
		if (!mia) {
			continue;
		}
		bool bene = false;
		const char *voluto = "";
		switch (r.attesa) {
			case Attesa::stringhe:
				bene = tipo_elemento == GGUF_TYPE_STRING;
				voluto = "stringhe";
				break;
			case Attesa::interi:
				bene = tipo_elemento == GGUF_TYPE_UINT32 || tipo_elemento == GGUF_TYPE_INT32;
				voluto = "interi a 32 bit";
				break;
			case Attesa::reali:
				bene = tipo_elemento == GGUF_TYPE_FLOAT32;
				voluto = "numeri a 32 bit";
				break;
		}
		if (!bene) {
			return "l'elenco «" + chiave + "» è fatto di " + nome_tipo(tipo_elemento) +
					" invece che di " + voluto +
					": llama.cpp legge questo elenco con un GGML_ASSERT, e un tipo "
					"sbagliato qui non è un errore, è il processo che muore";
		}
		return std::string();
	}
	return std::string();
}

uint64_t pad(uint64_t x, uint64_t n) {
	return (x + n - 1) & ~(n - 1);
}

} // namespace

std::string impronta_file(const std::string &percorso, double *ms_fuori) {
	const auto t0 = std::chrono::steady_clock::now();
	std::FILE *f = std::fopen(percorso.c_str(), "rb");
	if (f == nullptr) {
		return std::string();
	}
	Sha256 h;
	std::vector<uint8_t> buffer(1u << 20);
	while (true) {
		const size_t letti = std::fread(buffer.data(), 1, buffer.size(), f);
		if (letti == 0) {
			break;
		}
		h.mangia(buffer.data(), letti);
	}
	const bool rotto = std::ferror(f) != 0;
	std::fclose(f);
	if (rotto) {
		return std::string();
	}
	const std::string esa = h.chiudi();
	if (ms_fuori != nullptr) {
		*ms_fuori = std::chrono::duration<double, std::milli>(
				std::chrono::steady_clock::now() - t0)
							.count();
	}
	return esa;
}

FattiGguf esamina_gguf(const std::string &percorso, bool con_impronta) {
	FattiGguf fatti;
	const auto t0 = std::chrono::steady_clock::now();

	// Il confine è compilato CON le eccezioni apposta (vedi `llm_llama.h`):
	// qui dentro l'unica cosa che può tirarne una è l'allocazione di una
	// stringa, e anche quella deve uscire come un «no» leggibile.
	try {
		std::FILE *f = std::fopen(percorso.c_str(), "rb");
		if (f == nullptr) {
			fatti.motivo = "il file non si apre: " + percorso;
			return fatti;
		}
		struct ChiudiPoi {
			std::FILE *f;
			~ChiudiPoi() { std::fclose(f); }
		} chiudi_poi{ f };

		// La dimensione vera, che è metà del lavoro di questo file: la
		// troncatura è il guasto più comune (un download interrotto) ed è
		// anche il più cattivo, perché con mmap non dà un errore ma un
		// SIGBUS.
#ifdef _WIN32
		if (_fseeki64(f, 0, SEEK_END) != 0) {
#else
		if (fseeko(f, 0, SEEK_END) != 0) {
#endif
			fatti.motivo = "non riesco a misurare il file";
			return fatti;
		}
#ifdef _WIN32
		const long long fine = _ftelli64(f);
#else
		const off_t fine = ftello(f);
#endif
		if (fine <= 0) {
			fatti.motivo = "il file è vuoto";
			return fatti;
		}
		std::rewind(f);

		Lettore r;
		r.f = f;
		r.dim = uint64_t(fine);
		fatti.byte_file = r.dim;

		char magia[4] = {};
		if (!r.grezzo(magia, 4)) {
			fatti.motivo = r.guasto;
			return fatti;
		}
		if (std::memcmp(magia, "GGUF", 4) != 0) {
			fatti.motivo = "non è un file GGUF (i primi quattro byte non dicono «GGUF»)";
			return fatti;
		}
		if (!r.u32(fatti.versione) || !r.i64(fatti.n_tensori) || !r.i64(fatti.n_chiavi)) {
			fatti.motivo = r.guasto;
			return fatti;
		}
		// La versione 1 llama.cpp non la carica più, e sopra la 3 non c'è
		// niente: meglio dirlo qui che scoprirlo con un file mezzo letto.
		if (fatti.versione < 2 || fatti.versione > 3) {
			fatti.motivo = "versione GGUF " + std::to_string(fatti.versione) +
					": llama.cpp legge la 2 e la 3";
			return fatti;
		}
		if (fatti.n_tensori < 0 || fatti.n_tensori > MAX_TENSORI) {
			fatti.motivo = "dichiara " + std::to_string(fatti.n_tensori) + " tensori";
			return fatti;
		}
		if (fatti.n_chiavi < 0 || fatti.n_chiavi > MAX_CHIAVI) {
			fatti.motivo = "dichiara " + std::to_string(fatti.n_chiavi) + " metadati";
			return fatti;
		}

		// ── I metadati ────────────────────────────────────────────────────
		std::set<std::string> viste;
		std::map<std::string, uint32_t> interi; // solo quelli che ci servono
		for (int64_t i = 0; i < fatti.n_chiavi; ++i) {
			std::string chiave;
			if (!r.stringa(chiave, MAX_NOME)) {
				fatti.motivo = r.guasto;
				return fatti;
			}
			if (chiave.empty()) {
				fatti.motivo = "il metadato numero " + std::to_string(i) + " non ha nome";
				return fatti;
			}
			if (!viste.insert(chiave).second) {
				// ggml rifiuta i doppioni, e ha ragione: due valori per la
				// stessa chiave vuol dire che uno dei due è spazzatura.
				fatti.motivo = "il metadato «" + chiave + "» compare due volte";
				return fatti;
			}
			uint32_t tipo = 0;
			if (!r.u32(tipo)) {
				fatti.motivo = r.guasto;
				return fatti;
			}
			bool e_array = false;
			uint32_t tipo_elemento = tipo;
			uint64_t quanti = 1;
			if (tipo == GGUF_TYPE_ARRAY) {
				e_array = true;
				if (!r.u32(tipo_elemento) || !r.u64(quanti)) {
					fatti.motivo = r.guasto;
					return fatti;
				}
				if (tipo_elemento == GGUF_TYPE_ARRAY || tipo_elemento >= GGUF_TYPE_COUNT) {
					fatti.motivo = "l'elenco «" + chiave + "» dichiara elementi di tipo " +
							std::to_string(tipo_elemento);
					return fatti;
				}
				if (quanti > MAX_ELEMENTI_ARRAY) {
					fatti.motivo = "l'elenco «" + chiave + "» dichiara " +
							std::to_string(quanti) + " elementi";
					return fatti;
				}
				const std::string no = attesa_rispettata(chiave, tipo_elemento);
				if (!no.empty()) {
					fatti.motivo = no;
					return fatti;
				}
			} else if (tipo >= GGUF_TYPE_COUNT) {
				fatti.motivo = "il metadato «" + chiave + "» ha tipo " + std::to_string(tipo);
				return fatti;
			}

			// ⚠️ L'UNICO METADATO CHE ABORTISCE, e non è in llama: è in ggml.
			// `gguf_init_from_file` legge l'allineamento con
			// `gguf_get_val_u32`, che dentro fa `GGML_ASSERT(get_ne() == 1)` e
			// `GGML_ASSERT(type_to_gguf_type<T>::value == type)`. Tutti gli
			// altri metadati passano dal ramo di llama (`GKV::get_kv` o
			// `get_arr`), che tira un'eccezione — e un'eccezione il gioco la
			// vede come «modello non caricato», che è sano. Questo no: questo è
			// `abort()`, e basta un byte cambiato nel tipo.
			// Misurato: `tools/rovina_gguf.py`, riga `allineamento_reale`, che
			// sulla colonna di llama dice MORTO(6).
			//
			// La condizione ricalca ESATTAMENTE quello che ggml accetta (un u32,
			// scalare o dentro un elenco da un elemento): più stretta
			// rifiuterebbe un file buono, più larga lascerebbe passare un abort.
			if (chiave == "general.alignment" &&
					(tipo_elemento != GGUF_TYPE_UINT32 || quanti != 1)) {
				fatti.motivo = "«general.alignment» è di tipo " +
						std::string(nome_tipo(tipo_elemento)) +
						(quanti != 1 ? " e ha " + std::to_string(quanti) + " valori" : "") +
						" invece che un u32 solo: ggml lo legge con un GGML_ASSERT, e "
						"sbagliarlo qui non è un errore, è il processo che muore";
				return fatti;
			}

			if (tipo_elemento == GGUF_TYPE_STRING) {
				// Le stringhe si attraversano una per una: è l'unico modo di
				// sapere dove finisce l'elenco, e costa una lettura bufferata.
				for (uint64_t k = 0; k < quanti; ++k) {
					const bool tienila = !e_array && quanti == 1;
					if (tienila) {
						std::string valore;
						if (!r.stringa(valore, MAX_VALORE)) {
							fatti.motivo = r.guasto;
							return fatti;
						}
						if (chiave == "general.architecture") {
							fatti.architettura = valore;
						} else if (chiave == "general.name") {
							fatti.nome = valore;
						}
					} else if (!r.salta_stringa(MAX_VALORE)) {
						fatti.motivo = r.guasto;
						return fatti;
					}
				}
				if (e_array && chiave == "tokenizer.ggml.tokens") {
					fatti.vocabolario = int64_t(quanti);
				}
			} else {
				const uint64_t taglia = byte_del_tipo(tipo_elemento);
				if (taglia == 0) {
					fatti.motivo = "il metadato «" + chiave + "» ha un tipo senza taglia";
					return fatti;
				}
				if (quanti > UINT64_MAX / taglia) {
					fatti.motivo = "l'elenco «" + chiave + "» ha una taglia che non sta in 64 bit";
					return fatti;
				}
				const uint64_t byte = quanti * taglia;
				// I pochi scalari che ci servono si leggono; tutto il resto si
				// salta. Meno cose si tengono, meno cose possono andare storte.
				if (!e_array && taglia == 4 &&
						(tipo_elemento == GGUF_TYPE_UINT32 || tipo_elemento == GGUF_TYPE_INT32)) {
					uint32_t v = 0;
					if (!r.u32(v)) {
						fatti.motivo = r.guasto;
						return fatti;
					}
					interi[chiave] = v;
				} else if (!r.salta(byte)) {
					fatti.motivo = r.guasto;
					return fatti;
				}
			}
		}

		if (fatti.architettura.empty()) {
			fatti.motivo = "manca «general.architecture»: senza, llama.cpp non sa "
						   "nemmeno che modello sia";
			return fatti;
		}
		if (viste.find("tokenizer.ggml.tokens") == viste.end()) {
			fatti.motivo = "manca il vocabolario (tokenizer.ggml.tokens)";
			return fatti;
		}

		{
			auto it = interi.find("general.alignment");
			if (it != interi.end()) {
				fatti.allineamento = it->second;
			}
			if (fatti.allineamento == 0 || fatti.allineamento > (1u << 20) ||
					(fatti.allineamento & (fatti.allineamento - 1)) != 0) {
				fatti.motivo = "l'allineamento dichiarato (" +
						std::to_string(fatti.allineamento) + ") non è una potenza di due";
				return fatti;
			}
		}
		const std::string a = fatti.architettura;
		auto prendi = [&](const char *coda, uint32_t &dove) {
			auto it = interi.find(a + coda);
			if (it != interi.end()) {
				dove = it->second;
			}
		};
		prendi(".block_count", fatti.strati);
		prendi(".context_length", fatti.contesto_addestramento);
		prendi(".embedding_length", fatti.embedding);
		prendi(".attention.head_count", fatti.teste);
		prendi(".attention.head_count_kv", fatti.teste_kv);
		prendi(".attention.key_length", fatti.dim_chiave);
		prendi(".attention.value_length", fatti.dim_valore);

		// ── I tensori ─────────────────────────────────────────────────────
		std::set<std::string> nomi;
		std::map<uint32_t, uint64_t> quanti_per_tipo;
		uint64_t somma = 0; // dove dovrebbe cominciare il prossimo tensore
		for (int64_t i = 0; i < fatti.n_tensori; ++i) {
			std::string nome;
			if (!r.stringa(nome, MAX_NOME)) {
				fatti.motivo = r.guasto;
				return fatti;
			}
			if (nome.size() >= GGML_MAX_NAME) {
				fatti.motivo = "il tensore numero " + std::to_string(i) +
						" ha un nome da " + std::to_string(nome.size()) + " caratteri";
				return fatti;
			}
			if (!nomi.insert(nome).second) {
				fatti.motivo = "due tensori si chiamano «" + nome + "»";
				return fatti;
			}
			uint32_t n_dim = 0;
			if (!r.u32(n_dim)) {
				fatti.motivo = r.guasto;
				return fatti;
			}
			if (n_dim > GGML_MAX_DIMS) {
				fatti.motivo = "il tensore «" + nome + "» dichiara " + std::to_string(n_dim) +
						" dimensioni (il massimo è " + std::to_string(GGML_MAX_DIMS) + ")";
				return fatti;
			}
			int64_t ne[GGML_MAX_DIMS] = { 1, 1, 1, 1 };
			for (uint32_t d = 0; d < n_dim; ++d) {
				if (!r.i64(ne[d])) {
					fatti.motivo = r.guasto;
					return fatti;
				}
				// ggml accetta zero, `llama_model_loader::create_tensor` no:
				// fa GGML_ASSERT(ne >= 1). Uno zero qui passa il primo
				// controllo e abortisce dentro il secondo — questa riga è una
				// delle tre porte misurate.
				if (ne[d] < 1) {
					fatti.motivo = "il tensore «" + nome + "» ha la dimensione " +
							std::to_string(d) + " a " + std::to_string(ne[d]);
					return fatti;
				}
			}
			// Il numero di elementi deve stare in 64 bit con margine.
			uint64_t elementi = 1;
			for (int d = 0; d < GGML_MAX_DIMS; ++d) {
				if (uint64_t(ne[d]) != 0 && elementi > UINT64_MAX / uint64_t(ne[d])) {
					fatti.motivo = "il tensore «" + nome + "» dichiara più elementi di quanti "
								   "ne stiano in 64 bit";
					return fatti;
				}
				elementi *= uint64_t(ne[d]);
			}
			uint32_t tipo = 0;
			if (!r.u32(tipo)) {
				fatti.motivo = r.guasto;
				return fatti;
			}
			// L'ordine conta: si controlla l'intervallo PRIMA di chiamare
			// ggml_blck_size, che è un indice in un array.
			if (tipo >= uint32_t(GGML_TYPE_COUNT)) {
				fatti.motivo = "il tensore «" + nome + "» ha il tipo ggml " +
						std::to_string(tipo);
				return fatti;
			}
			const ggml_type tg = ggml_type(tipo);
			const int64_t blocco = ggml_blck_size(tg);
			const size_t taglia_blocco = ggml_type_size(tg);
			if (blocco <= 0 || taglia_blocco == 0) {
				fatti.motivo = "il tensore «" + nome + "» ha un tipo senza taglia";
				return fatti;
			}
			if (ne[0] % blocco != 0) {
				fatti.motivo = "il tensore «" + nome + "» ha righe da " +
						std::to_string(ne[0]) + " elementi, che non è un multiplo del "
											   "blocco di " +
						ggml_type_name(tg);
				return fatti;
			}
			uint64_t offset = 0;
			if (!r.u64(offset)) {
				fatti.motivo = r.guasto;
				return fatti;
			}
			// ggml pretende che i tensori siano scritti IN FILA, senza buchi:
			// l'offset dev'essere esattamente la somma dei precedenti.
			if (offset != somma) {
				fatti.motivo = "il tensore «" + nome + "» dice di cominciare al byte " +
						std::to_string(offset) + " invece che a " + std::to_string(somma);
				return fatti;
			}
			const uint64_t byte = (elementi / uint64_t(blocco)) * uint64_t(taglia_blocco);
			const uint64_t byte_pad = pad(byte, fatti.allineamento);
			if (byte_pad < byte || somma > UINT64_MAX - byte_pad) {
				fatti.motivo = "le taglie dei tensori non stanno in 64 bit";
				return fatti;
			}
			somma += byte_pad;
			quanti_per_tipo[tipo] += byte;
			fatti.parametri += elementi;
		}
		fatti.byte_dati = somma;
		fatti.inizio_dati = fatti.n_tensori > 0 ? pad(r.pos, fatti.allineamento) : r.pos;

		// ── LA RIGA PIÙ IMPORTANTE DEL FILE ───────────────────────────────
		// Un download interrotto è un file GGUF perfetto con dentro metà dei
		// pesi. llama lo mappa in memoria e ci legge sopra: leggere oltre la
		// fine di una mappatura non è un errore che si possa gestire, è un
		// SIGBUS — il gioco che sparisce senza una riga di log.
		if (fatti.inizio_dati > fatti.byte_file ||
				fatti.byte_dati > fatti.byte_file - fatti.inizio_dati) {
			const uint64_t serve = fatti.inizio_dati + fatti.byte_dati;
			fatti.motivo = "il file è TRONCATO: i tensori arrivano al byte " +
					std::to_string(serve) + " ma il file finisce a " +
					std::to_string(fatti.byte_file) + " (mancano " +
					std::to_string(serve - fatti.byte_file) + " byte)";
			return fatti;
		}

		// COME SI CHIAMA QUESTA QUANTIZZAZIONE. Si chiede a llama, che è la
		// fonte unica: `general.file_type` è un numero, e la tabella che lo
		// traduce in «Q4_K - Medium» sta dentro llama.cpp e cambia con le
		// versioni. `llama_ftype_name` ha un `default`, quindi anche un
		// numero corrotto torna una stringa invece di un abort.
		//
		// Il ripiego (nessun `file_type` nel file) è il tipo che occupa PIÙ
		// BYTE. Non il più frequente per elementi: un Q4_K_M vero è un
		// mosaico — gemma-3-1b ne ha quattro diversi, e contando gli
		// elementi vinceva un tipo che sul disco non è il maggiore.
		{
			auto it = interi.find("general.file_type");
			if (it != interi.end()) {
				fatti.quantizzazione = llama_ftype_name(llama_ftype(it->second));
			} else {
				uint64_t massimo = 0;
				for (const auto &p : quanti_per_tipo) {
					if (p.second > massimo) {
						massimo = p.second;
						fatti.quantizzazione = ggml_type_name(ggml_type(p.first));
					}
				}
			}
		}

		fatti.ok = true;
	} catch (const std::exception &e) {
		fatti.ok = false;
		fatti.motivo = std::string("errore leggendo il file: ") + e.what();
		return fatti;
	} catch (...) {
		fatti.ok = false;
		fatti.motivo = "errore sconosciuto leggendo il file";
		return fatti;
	}

	fatti.ms_esame = std::chrono::duration<double, std::milli>(
			std::chrono::steady_clock::now() - t0)
							 .count();

	if (con_impronta) {
		fatti.impronta = impronta_file(percorso, &fatti.ms_impronta);
		if (fatti.impronta.empty()) {
			fatti.ok = false;
			fatti.motivo = "non riesco a rileggere il file per l'impronta";
		}
	}
	return fatti;
}

uint64_t stima_byte_kv(const FattiGguf &f, uint32_t n_ctx) {
	if (f.strati == 0 || n_ctx == 0) {
		return 0;
	}
	// La testa di attenzione: se il file non dichiara `key_length`, vale
	// embedding / teste — è la definizione, non una scorciatoia.
	uint64_t dim_k = f.dim_chiave;
	uint64_t dim_v = f.dim_valore;
	if (dim_k == 0 && f.teste > 0) {
		dim_k = f.embedding / f.teste;
	}
	if (dim_v == 0) {
		dim_v = dim_k;
	}
	const uint64_t teste_kv = f.teste_kv > 0 ? f.teste_kv : (f.teste > 0 ? f.teste : 1);
	// F16: due byte per numero, per la chiave e per il valore, per strato,
	// per gettone. È il valore di partenza di llama (`type_k`/`type_v`).
	return uint64_t(f.strati) * uint64_t(n_ctx) * teste_kv * (dim_k + dim_v) * 2ull;
}

uint64_t stima_byte_totali(const FattiGguf &f, uint32_t n_ctx) {
	// I pesi (che llama mappa dal file, ma che stanno comunque in memoria
	// fisica mentre il modello lavora) più la cache. Il grafo di calcolo e i
	// buffer di lavoro NON sono qui dentro: dipendono dal batch e dal
	// backend, e stimarli a naso vorrebbe dire mettere un numero inventato
	// dentro un cancello. Quelli si MISURANO dopo il carico.
	return f.byte_dati + stima_byte_kv(f, n_ctx);
}

} // namespace chibi
