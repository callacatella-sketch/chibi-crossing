#include "neuroni.h"

#include <cmath>
#include <cstring>

namespace chibi {
namespace {

constexpr int N = NEU_N;

// --- la membrana
constexpr double TAU_M      = 0.020;   // 20 ms, la costante di una piramidale
constexpr double V_RIPOSO   = 0.0;
constexpr double V_SOGLIA   = 1.0;
constexpr double V_RESET    = 0.0;
constexpr double T_REF      = 0.003;   // 3 ms
constexpr double TAU_SYN    = 0.008;   // la corrente sinaptica decade in 8 ms
// --- la plasticità
constexpr double TAU_TRACCIA = 0.020;
constexpr double A_PIU      = 0.010;
constexpr double A_MENO     = 0.0105;  // ⚠️ leggermente ASIMMETRICA, apposta
constexpr double W_MAX      = 0.60;
constexpr double W_MIN      = 0.0;
// --- l'omeostasi
constexpr double TAU_MEDIA  = 8.0;     // la frequenza media si legge su 8 s
constexpr double SPARO_OBIETTIVO = 4.0;  // Hz: il bersaglio di ogni neurone
constexpr double OMEO_K     = 0.0025;
// --- il passo interno
constexpr double DT_MAX     = 0.002;   // 2 ms: sotto il refrattario
constexpr int    SUBPASSI_MAX = 24;

inline bool bit(uint32_t m, int i) { return (m >> i) & 1u; }

// splitmix64 — interi soltanto, quindi **bit-identico** su tutti e tre i
// sistemi. ⚠️ Le distribuzioni di <random> non lo sono (non sono specificate
// dallo standard) e Box–Muller nemmeno (log e cos non sono arrotondate
// esattamente da IEEE754): questo progetto ha già pagato la lezione «una
// build che compila solo dove la scrivi non è compilata».
inline uint64_t mix(uint64_t &s) {
    s += 0x9E3779B97F4A7C15ull;
    uint64_t z = s;
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ull;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBull;
    return z ^ (z >> 31);
}
inline double uni(uint64_t &s) {
    // 53 bit su 2^53: divisione ESATTA, nessun arrotondamento di piattaforma
    return static_cast<double>(mix(s) >> 11) * (1.0 / 9007199254740992.0);
}

} // namespace

void genera_sinapsi(uint64_t seme, Sinapsi *out) {
    if (out == nullptr) return;
    std::memset(out->w, 0, sizeof(out->w));
    uint64_t s = seme ^ 0xA5A5C3C35A5A3C3Cull;
    for (int i = 0; i < N; ++i) {
        for (int j = 0; j < N; ++j) {
            if (i == j) continue;                    // niente autosinapsi
            // connettività sparsa: una corteccia non è un grafo completo, e
            // una rete densa con STDP satura sempre
            if (uni(s) > 0.28) continue;
            const bool ecc = (j < NEU_ECC);
            // ⚠️ IL SEGNO È DEL NEURONE, NON DELLA SINAPSI (legge di Dale):
            // un neurone è eccitatorio o inibitorio, e resta quello. È anche
            // ciò che impedisce alla plasticità di far cambiare segno a un
            // arco, che sarebbe la strada più corta verso una rete instabile.
            const double base = 0.10 + uni(s) * 0.22;
            out->w[i * N + j] = ecc ? base : -base * 1.8;
        }
    }
    out->pronto = true;
}

bool passo_neurale(const Sinapsi &syn, const Modulatori &mod, const double *aff,
                   double dt, StatoNeurale *st, Sinapsi *plastico) {
    if (!syn.pronto || aff == nullptr || st == nullptr) return false;
    if (!std::isfinite(dt) || dt <= 0.0) return false;
    for (int i = 0; i < A_NUM; ++i) if (!std::isfinite(aff[i])) return false;

    if (!st->pronto) {
        std::memset(st->v, 0, sizeof(st->v));
        std::memset(st->x, 0, sizeof(st->x));
        std::memset(st->y, 0, sizeof(st->y));
        std::memset(st->i_syn, 0, sizeof(st->i_syn));
        std::memset(st->ref, 0, sizeof(st->ref));
        for (int i = 0; i < N; ++i) st->media[i] = SPARO_OBIETTIVO;
        st->pronto = true;
    }

    // ---- I NEUROMODULATORI, e ognuno entra in un posto DIVERSO
    const double dopa = std::fmin(std::fmax(mod.dopamina, 0.0), 1.0);
    const double sero = std::fmin(std::fmax(mod.serotonina, 0.0), 1.0);
    const double cort = std::fmin(std::fmax(mod.cortisolo, 0.0), 1.0);
    const double mela = std::fmin(std::fmax(mod.melatonina, 0.0), 1.0);
    const double aden = std::fmin(std::fmax(mod.adenosina, 0.0), 1.0);
    const double ossi = std::fmin(std::fmax(mod.ossitocina, 0.0), 1.0);
    const double endo = std::fmin(std::fmax(mod.endorfine, 0.0), 1.0);

    // la serotonina ALZA la soglia: chi sta sereno non si accende per niente
    const double soglia = V_SOGLIA * (0.82 + 0.36 * sero);
    // il cortisolo alza il guadagno — sotto stress si reagisce di più e peggio
    const double guadagno = 1.0 + 0.85 * cort;
    // l'adenosina è inibizione globale: è il sonno, ed è il motivo per cui la
    // caffeina (che la blocca) sveglia
    const double freno = 1.0 - 0.55 * aden;
    // la melatonina chiude la porta al mondo: di notte il mondo non entra
    const double porta = 1.0 - 0.80 * mela;
    // ⚠️ IL TERZO FATTORE. Senza dopamina la STDP non consolida: si impara
    // quello che è successo MENTRE IMPORTAVA, che è anche ciò che questo
    // gioco dice dei ricordi da sempre.
    const double base_dopa = std::isfinite(mod.dopamina_riposo)
            ? std::fmin(std::fmax(mod.dopamina_riposo, 0.0), 1.0) : 0.4;
    const double impara = std::fmax(0.0, dopa - base_dopa) * 3.6;

    // ---- il passo si spezza: il refrattario dura 3 ms, e un passo più lungo
    // farebbe sparire gli spike. Il tempo si integra tutto, in sottopassi.
    int sub = static_cast<int>(std::ceil(dt / DT_MAX));
    if (sub < 1) sub = 1;
    if (sub > SUBPASSI_MAX) sub = SUBPASSI_MAX;
    const double h = dt / static_cast<double>(sub);
    const double a_m = std::exp(-h / TAU_M);
    const double a_s = std::exp(-h / TAU_SYN);
    const double a_t = std::exp(-h / TAU_TRACCIA);
    const double a_med = std::exp(-h / TAU_MEDIA);

    uint32_t sparati = 0u;
    for (int p = 0; p < sub; ++p) {
        // --- la corrente afferente
        double i_aff[N];
        std::memset(i_aff, 0, sizeof(i_aff));
        for (int k = 0; k < A_NUM; ++k) {
            double g = 1.0;
            // l'ossitocina guadagna SOLO sulle afferenze sociali: è quello
            // che fa davvero, e metterla su tutto sarebbe un moltiplicatore
            // in più invece di una funzione
            if (k == A_SOCIALE || k == A_GIOCATORE) g *= (0.55 + 1.1 * ossi);
            // le endorfine alzano la soglia del dolore: smorzano il freddo e
            // la pioggia, non la luce
            if (k == A_FREDDO || k == A_PIOGGIA) g *= (1.0 - 0.5 * endo);
            const double v = aff[k] < 0.0 ? 0.0 : (aff[k] > 1.0 ? 1.0 : aff[k]);
            i_aff[k] = v * g * porta * 2.6;
        }

        uint32_t ora = 0u;
        for (int i = 0; i < N; ++i) {
            st->i_syn[i] *= a_s;
            if (st->ref[i] > 0.0) { st->ref[i] -= h; st->v[i] = V_RESET; continue; }
            const double drive = (st->i_syn[i] + i_aff[i]) * guadagno * freno;
            // integrazione ESATTA della membrana (non Eulero: lo stato non
            // deve dipendere dal frame rate — lezione già pagata dalla chimica)
            const double vinf = V_RIPOSO + drive;
            st->v[i] = vinf + (st->v[i] - vinf) * a_m;
            if (!std::isfinite(st->v[i])) return false;
            if (st->v[i] >= soglia) {
                ora |= (1u << i);
                st->v[i] = V_RESET;
                st->ref[i] = T_REF;
            }
        }
        sparati |= ora;

        // --- le tracce e la propagazione
        for (int i = 0; i < N; ++i) {
            st->x[i] *= a_t; st->y[i] *= a_t;
            st->media[i] = st->media[i] * a_med
                    + (bit(ora, i) ? (1.0 - a_med) / h : 0.0) * 0.0;
        }
        // la frequenza media, in forma esatta: uno spike vale 1/h Hz
        for (int i = 0; i < N; ++i)
            if (bit(ora, i)) st->media[i] += (1.0 - a_med) * (1.0 / h);

        for (int j = 0; j < N; ++j) {
            if (!bit(ora, j)) continue;
            for (int i = 0; i < N; ++i) {
                const double w = syn.w[i * N + j];
                if (w == 0.0) continue;
                st->i_syn[i] += w;
            }
        }

        // --- LA PLASTICITÀ, e solo se c'è il terzo fattore
        if (plastico != nullptr && impara > 0.0) {
            for (int j = 0; j < N; ++j) {
                if (!bit(ora, j)) continue;
                for (int i = 0; i < N; ++i) {
                    if (i == j) continue;
                    // j ha appena sparato: come PRE verso i (depressione se i
                    // ha sparato di recente), e come POST da i (potenziamento
                    // se i ha sparato poco prima)
                    double &w_ij = plastico->w[i * N + j];   // i ← j
                    if (w_ij > 0.0) {
                        w_ij -= A_MENO * st->y[i] * impara;   // pre dopo post
                        if (w_ij < W_MIN) w_ij = W_MIN;
                    }
                    double &w_ji = plastico->w[j * N + i];   // j ← i
                    if (w_ji > 0.0) {
                        w_ji += A_PIU * st->x[i] * impara;    // post dopo pre
                        if (w_ji > W_MAX) w_ji = W_MAX;
                    }
                }
            }
        }
        for (int i = 0; i < N; ++i)
            if (bit(ora, i)) { st->x[i] += 1.0; st->y[i] += 1.0; }
    }

    // --- L'OMEOSTASI (Turrigiano): se un neurone spara troppo, TUTTI i suoi
    // ingressi si abbassano in proporzione. Senza, una rete plastica finisce
    // sempre in uno dei due muri: silenzio o crisi. Gira una volta per passo,
    // non per sottopasso: è un processo lento e deve restare tale.
    if (plastico != nullptr) {
        for (int i = 0; i < N; ++i) {
            if (!std::isfinite(st->media[i])) return false;
            const double err = st->media[i] - SPARO_OBIETTIVO;
            const double k = 1.0 - OMEO_K * dt * err;
            if (!(k > 0.5 && k < 1.5)) continue;
            for (int j = 0; j < N; ++j) {
                double &w = plastico->w[i * N + j];
                if (w <= 0.0) continue;          // solo gli eccitatori scalano
                w *= k;
                if (w > W_MAX) w = W_MAX;
                if (w < W_MIN) w = W_MIN;
            }
        }
    }

    st->spike = sparati;
    return true;
}

EcoNeurale leggi_eco(const StatoNeurale &st, const double *aff) {
    EcoNeurale e;
    if (!st.pronto || aff == nullptr) return e;
    // ⚠️ LA FAMILIARITÀ non è «ho già visto questa scena»: è quanto la rete
    // RISUONA, cioè quanto l'attività ricorrente supera quella che le
    // afferenze da sole spiegherebbero. Una scena mai vista accende solo gli
    // ingressi; una che ha una storia accende anche il resto.
    double att_in = 0.0, att_out = 0.0;
    for (int i = 0; i < NEU_IN; ++i) att_in += st.media[i];
    for (int i = NEU_IN; i < NEU_N; ++i) att_out += st.media[i];
    att_in /= static_cast<double>(NEU_IN);
    att_out /= static_cast<double>(NEU_N - NEU_IN);
    if (!std::isfinite(att_in) || !std::isfinite(att_out)) return e;
    const double tot = att_in + att_out;
    e.attivita = tot > 0.0 ? std::fmin(1.0, tot / (2.0 * SPARO_OBIETTIVO * 2.0)) : 0.0;
    // ⚠️ **E LA SCALA VA TARATA SUL RAPPORTO VERO, o il readout e' MORTO.**
    // Alla prima stesura era `att_out/att_in − 0.35`, e MISURATO usciva
    // **0.000 per tutti**: il rapporto in una rete sana sta sotto quella
    // soglia sempre, quindi quella riga non poteva dire niente su niente. Un
    // readout che risponde una costante e' il difetto pagato nove volte, in
    // miniatura. Adesso si centra sul rapporto di una rete a riposo (~0.45) e
    // si guarda lo SCARTO, che e' la grandezza che cambia.
    // La costante è MISURATA, non indovinata: una rete appena generata, in
    // una scena neutra, sta a **att_in 10.27 Hz, att_out 1.47 Hz, rapporto
    // 0.143** (`tools/prova_neuroni`, diagnosi). Si centra lì e si scala
    // perché un RADDOPPIO dell'attività ricorrente legga quasi 1. Chi cambia
    // la connettività o la taglia della rete deve **rimisurarla**, o questo
    // readout torna a rispondere una costante.
    const double RIPOSO_RAPPORTO = 0.143;
    const double rapporto = att_out / (att_in + 1e-9);
    e.familiarita = std::fmin(1.0,
            std::fmax(0.0, (rapporto - RIPOSO_RAPPORTO) * 7.0));
    // ⚠️ E L'ECO NON HA UN SEGNO PROPRIO: lo prende dalla popolazione
    // INIBITORIA, che è quella che il mondo carica quando qualcosa va male
    // (il freddo, la pioggia, lo stare allo scoperto entrano lì). Non c'è
    // nessuna tabella «colore → emozione»: c'è una rete che ha imparato.
    double ini = 0.0;
    for (int i = NEU_ECC; i < NEU_N; ++i) ini += st.media[i];
    ini /= static_cast<double>(NEU_N - NEU_ECC);
    double ecc = 0.0;
    for (int i = 0; i < NEU_ECC; ++i) ecc += st.media[i];
    ecc /= static_cast<double>(NEU_ECC);
    const double s = ecc + ini;
    e.eco = s > 1e-9 ? std::fmin(1.0, std::fmax(-1.0, (ecc - ini) / s)) : 0.0;
    e.valido = true;
    return e;
}

bool transizione_neurale(const Sinapsi &syn, const Modulatori &mod, double dt,
                         int n_ridotto, double *E, double *Q) {
    if (!syn.pronto || E == nullptr || Q == nullptr) return false;
    if (n_ridotto < 2 || n_ridotto > NEU_N) return false;
    if (!std::isfinite(dt) || dt <= 0.0) return false;
    // ⚠️ **LA LINEARIZZAZIONE, DICHIARATA.** Φ si calcola su un modello
    // lineare-gaussiano; una rete che spara non lo è. Si prende la matrice
    // efficace `E = exp((−I/τ_m + W·g)·dt)` attorno al punto di lavoro, che è
    // l'approssimazione standard (e la stessa che usa la letteratura su Φ per
    // reti spiking). Chi cita il numero deve citare anche questa riga.
    const double cort = std::fmin(std::fmax(mod.cortisolo, 0.0), 1.0);
    const double aden = std::fmin(std::fmax(mod.adenosina, 0.0), 1.0);
    const double g = (1.0 + 0.85 * cort) * (1.0 - 0.55 * aden);
    const int n = n_ridotto;
    // si aggregano i NEU_N neuroni in n gruppi: Φ esatto oltre 12 unità non
    // è calcolabile in tempo utile (5 ms a 12), e un Φ campionato non sa dire
    // se sta scendendo o se è cambiato il campione.
    double M[NEU_N * NEU_N];
    std::memset(M, 0, sizeof(double) * n * n);
    const int per = NEU_N / n;
    for (int i = 0; i < NEU_N; ++i)
        for (int j = 0; j < NEU_N; ++j) {
            int gi = i / per; if (gi >= n) gi = n - 1;
            int gj = j / per; if (gj >= n) gj = n - 1;
            M[gi * n + gj] += syn.w[i * NEU_N + j] * g;
        }
    for (int i = 0; i < n; ++i) M[i * n + i] -= static_cast<double>(per) / TAU_M;
    // exp(M·dt) con scaling and squaring
    double T[NEU_N * NEU_N], P[NEU_N * NEU_N], A[NEU_N * NEU_N];
    double norma = 0.0;
    for (int i = 0; i < n; ++i) {
        double r = 0.0;
        for (int j = 0; j < n; ++j) r += std::fabs(M[i * n + j]);
        if (r > norma) norma = r;
    }
    int s = 0; double sc = norma * dt;
    while (sc > 0.25 && s < 40) { sc *= 0.5; ++s; }
    const double hs = dt / static_cast<double>(1 << s);
    std::memset(E, 0, sizeof(double) * n * n);
    for (int i = 0; i < n; ++i) E[i * n + i] = 1.0;
    for (int i = 0; i < n * n; ++i) { A[i] = M[i] * hs; P[i] = A[i]; E[i] += P[i]; }
    double f = 1.0;
    for (int k = 2; k <= 10; ++k) {
        for (int i = 0; i < n; ++i)
            for (int j = 0; j < n; ++j) {
                double acc = 0.0;
                for (int l = 0; l < n; ++l) acc += P[i * n + l] * A[l * n + j];
                T[i * n + j] = acc;
            }
        std::memcpy(P, T, sizeof(double) * n * n);
        f *= static_cast<double>(k);
        for (int i = 0; i < n * n; ++i) E[i] += P[i] / f;
    }
    for (int q = 0; q < s; ++q) {
        for (int i = 0; i < n; ++i)
            for (int j = 0; j < n; ++j) {
                double acc = 0.0;
                for (int l = 0; l < n; ++l) acc += E[i * n + l] * E[l * n + j];
                T[i * n + j] = acc;
            }
        std::memcpy(E, T, sizeof(double) * n * n);
    }
    for (int i = 0; i < n * n; ++i) if (!std::isfinite(E[i])) return false;
    std::memset(Q, 0, sizeof(double) * n * n);
    for (int i = 0; i < n; ++i) Q[i * n + i] = 1.0;
    return true;
}

void pesi_in_byte(const Sinapsi &syn, uint8_t *out) {
    if (out == nullptr) return;
    for (int k = 0; k < NEU_N * NEU_N; ++k) {
        double v = syn.w[k] / (W_MAX * 2.0);          // −1..1 circa
        if (v < -1.0) v = -1.0;
        if (v > 1.0) v = 1.0;
        out[k] = static_cast<uint8_t>(std::lround((v + 1.0) * 127.5));
    }
}

bool byte_in_pesi(const uint8_t *in, Sinapsi *out) {
    if (in == nullptr || out == nullptr) return false;
    for (int k = 0; k < NEU_N * NEU_N; ++k) {
        const double v = (static_cast<double>(in[k]) / 127.5) - 1.0;
        out->w[k] = v * (W_MAX * 2.0);
    }
    for (int i = 0; i < NEU_N; ++i) out->w[i * NEU_N + i] = 0.0;
    out->pronto = true;
    return true;
}

} // namespace chibi
