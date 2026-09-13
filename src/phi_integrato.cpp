#include "phi_integrato.h"

#include <cmath>
#include <cstring>

namespace chibi {
namespace {

constexpr int NMAX = PHI_MAX_N;

inline void mat_mul(const double *X, const double *Y, int n, double *out) {
    for (int i = 0; i < n; ++i)
        for (int j = 0; j < n; ++j) {
            double s = 0.0;
            for (int k = 0; k < n; ++k) s += X[i * n + k] * Y[k * n + j];
            out[i * n + j] = s;
        }
}

inline void mat_mul_bt(const double *X, const double *Y, int n, double *out) {
    // X · Yᵀ
    for (int i = 0; i < n; ++i)
        for (int j = 0; j < n; ++j) {
            double s = 0.0;
            for (int k = 0; k < n; ++k) s += X[i * n + k] * Y[j * n + k];
            out[i * n + j] = s;
        }
}

// Cholesky in place su una copia. `dim` può essere < n (sottomatrice già
// compattata). Torna false se non è definita positiva.
bool cholesky(double *M, int dim) {
    for (int i = 0; i < dim; ++i) {
        for (int j = 0; j <= i; ++j) {
            double s = M[i * dim + j];
            for (int k = 0; k < j; ++k) s -= M[i * dim + k] * M[j * dim + k];
            if (i == j) {
                // ⚠️ NON si "aggiusta" una matrice non definita positiva
                // aggiungendo un epsilon: un Φ calcolato su una covarianza
                // corretta a mano è un numero che non misura più niente.
                if (!(s > 1e-300)) return false;
                M[i * dim + j] = std::sqrt(s);
            } else {
                M[i * dim + j] = s / M[j * dim + j];
            }
        }
        for (int j = i + 1; j < dim; ++j) M[i * dim + j] = 0.0;
    }
    return true;
}

} // namespace

double scala_a_raggio_spettrale(double *A, int n, double rho) {
    if (n <= 0 || n > NMAX) return 0.0;
    // iterazione delle potenze: v ← A·v / |A·v|, il fattore di crescita
    // converge al raggio spettrale. Parte da un vettore non simmetrico, o
    // una matrice simmetrica lo farebbe partire su un autovettore sbagliato.
    double v[NMAX];
    for (int i = 0; i < n; ++i) v[i] = 1.0 + 0.37 * static_cast<double>(i);
    double lambda = 0.0;
    for (int it = 0; it < 200; ++it) {
        double w[NMAX];
        for (int i = 0; i < n; ++i) {
            double s = 0.0;
            for (int j = 0; j < n; ++j) s += A[i * n + j] * v[j];
            w[i] = s;
        }
        double norm = 0.0;
        for (int i = 0; i < n; ++i) norm += w[i] * w[i];
        norm = std::sqrt(norm);
        if (!(norm > 1e-300)) return 0.0;
        lambda = norm;
        for (int i = 0; i < n; ++i) v[i] = w[i] / norm;
    }
    if (!(lambda > 1e-300) || !std::isfinite(lambda)) return 0.0;
    const double k = rho / lambda;
    for (int i = 0; i < n * n; ++i) A[i] *= k;
    return lambda;
}

bool q_diagonale(const double *Q, int n, double tol) {
    for (int i = 0; i < n; ++i)
        for (int j = 0; j < n; ++j)
            if (i != j && std::fabs(Q[i * n + j]) > tol) return false;
    return true;
}

bool log_det_spd(const double *M, int n, double *out) {
    if (n <= 0 || n > NMAX) return false;
    double L[NMAX * NMAX];
    std::memcpy(L, M, sizeof(double) * static_cast<size_t>(n) * static_cast<size_t>(n));
    if (!cholesky(L, n)) return false;
    double acc = 0.0;
    for (int i = 0; i < n; ++i) acc += std::log(L[i * n + i]);
    *out = 2.0 * acc;   // det = Π Lᵢᵢ², quindi ln det = 2·Σ ln Lᵢᵢ
    return true;
}

bool lyapunov_discreta(const double *A, const double *Q, int n, double *sigma) {
    if (n <= 0 || n > NMAX) return false;
    // METODO DEL RADDOPPIO (Smith 1968):
    //   Σ ← Σ + Aₖ·Σ·Aₖᵀ ,  Aₖ ← Aₖ²
    // Dopo m passi Aₖ = A^(2^m): l'errore cala come ρ^(2^m), cioè in una
    // trentina di iterazioni si è alla precisione della macchina anche con
    // ρ = 0.999. L'iterazione ingenua (Σ ← AΣAᵀ + Q) ci metterebbe
    // migliaia di passi allo stesso ρ.
    double Ak[NMAX * NMAX], S[NMAX * NMAX], T1[NMAX * NMAX], T2[NMAX * NMAX];
    const size_t nn = sizeof(double) * static_cast<size_t>(n) * static_cast<size_t>(n);
    std::memcpy(Ak, A, nn);
    std::memcpy(S, Q, nn);
    for (int iter = 0; iter < 64; ++iter) {
        mat_mul(Ak, S, n, T1);
        mat_mul_bt(T1, Ak, n, T2);        // Aₖ·Σ·Aₖᵀ
        double crescita = 0.0;
        for (int i = 0; i < n * n; ++i) {
            S[i] += T2[i];
            crescita += std::fabs(T2[i]);
            if (!std::isfinite(S[i])) return false;   // A instabile: diverge
        }
        mat_mul(Ak, Ak, n, T1);
        std::memcpy(Ak, T1, nn);
        if (crescita < 1e-14) break;
    }
    // simmetrizza: la covarianza lo è per costruzione, e il float no
    for (int i = 0; i < n; ++i)
        for (int j = 0; j < i; ++j) {
            const double m = 0.5 * (S[i * n + j] + S[j * n + i]);
            S[i * n + j] = m;
            S[j * n + i] = m;
        }
    std::memcpy(sigma, S, nn);
    return true;
}

RisultatoPhi phi_integrato(const double *A, const double *Q, int n) {
    RisultatoPhi r;
    r.n = n;
    if (n < 2 || n > NMAX) return r;

    double sigma[NMAX * NMAX];
    if (!lyapunov_discreta(A, Q, n, sigma)) return r;

    double ld_Q = 0.0;
    if (!log_det_spd(Q, n, &ld_Q)) return r;

    double best_norm = 1e300;
    double best_phi = 0.0;
    unsigned best_mask = 0u;

    // Le bipartizioni: ogni maschera da 1 a 2^(n-1)-1 con il bit 0 SEMPRE
    // nella parte sinistra — così ogni taglio si conta una volta sola
    // (una partizione e il suo complemento sono lo stesso taglio).
    const unsigned lim = 1u << (n - 1);
    for (unsigned mask = 1u; mask < lim; ++mask) {
        int idx_a[NMAX], idx_b[NMAX];
        int na = 0, nb = 0;
        for (int i = 0; i < n; ++i) {
            if (i == 0 || (mask >> (i - 1)) & 1u) idx_a[na++] = i;
            else idx_b[nb++] = i;
        }
        if (na == 0 || nb == 0) continue;

        double somma = 0.0;
        bool ok = true;
        // per ognuna delle due parti: C_cond = A_pq·Σ_{q|p}·A_pqᵀ + Q_pp
        for (int lato = 0; lato < 2 && ok; ++lato) {
            const int *P = lato == 0 ? idx_a : idx_b;
            const int *R = lato == 0 ? idx_b : idx_a;
            const int np = lato == 0 ? na : nb;
            const int nr = lato == 0 ? nb : na;

            // Σ_pp, Σ_pr, Σ_rr  (sottomatrici compattate)
            double Spp[NMAX * NMAX], Spr[NMAX * NMAX], Srr[NMAX * NMAX];
            for (int i = 0; i < np; ++i) {
                for (int j = 0; j < np; ++j) Spp[i * np + j] = sigma[P[i] * n + P[j]];
                for (int j = 0; j < nr; ++j) Spr[i * nr + j] = sigma[P[i] * n + R[j]];
            }
            for (int i = 0; i < nr; ++i)
                for (int j = 0; j < nr; ++j) Srr[i * nr + j] = sigma[R[i] * n + R[j]];

            // Σ_{r|p} = Σ_rr − Σ_rp·Σ_pp⁻¹·Σ_pr, via Cholesky di Σ_pp:
            // si risolve Σ_pp·Z = Σ_pr e poi Σ_rr − Σ_prᵀ·Z
            double L[NMAX * NMAX];
            std::memcpy(L, Spp, sizeof(double) * static_cast<size_t>(np) * static_cast<size_t>(np));
            if (!cholesky(L, np)) { ok = false; break; }
            double Z[NMAX * NMAX];
            for (int c = 0; c < nr; ++c) {
                double y[NMAX];
                for (int i = 0; i < np; ++i) {
                    double s = Spr[i * nr + c];
                    for (int k = 0; k < i; ++k) s -= L[i * np + k] * y[k];
                    y[i] = s / L[i * np + i];
                }
                for (int i = np - 1; i >= 0; --i) {
                    double s = y[i];
                    for (int k = i + 1; k < np; ++k) s -= L[k * np + i] * Z[k * nr + c];
                    Z[i * nr + c] = s / L[i * np + i];
                }
            }
            double Srp_cond[NMAX * NMAX];
            for (int i = 0; i < nr; ++i)
                for (int j = 0; j < nr; ++j) {
                    double s = Srr[i * nr + j];
                    for (int k = 0; k < np; ++k) s -= Spr[k * nr + i] * Z[k * nr + j];
                    Srp_cond[i * nr + j] = s;
                }

            // A_pr · Σ_{r|p} · A_prᵀ + Q_pp
            double Apr[NMAX * NMAX];
            for (int i = 0; i < np; ++i)
                for (int j = 0; j < nr; ++j) Apr[i * nr + j] = A[P[i] * n + R[j]];
            double Ccond[NMAX * NMAX];
            for (int i = 0; i < np; ++i)
                for (int j = 0; j < np; ++j) {
                    double s = 0.0;
                    for (int k = 0; k < nr; ++k) {
                        double t = 0.0;
                        for (int l = 0; l < nr; ++l) t += Srp_cond[k * nr + l] * Apr[j * nr + l];
                        s += Apr[i * nr + k] * t;
                    }
                    Ccond[i * np + j] = s + Q[P[i] * n + P[j]];
                }
            double ld = 0.0;
            if (!log_det_spd(Ccond, np, &ld)) { ok = false; break; }
            somma += ld;
        }
        if (!ok) continue;

        const double phi_p = 0.5 * (somma - ld_Q);
        // ⚠️ LA NORMALIZZAZIONE SCEGLIE IL TAGLIO, NON MISURA. Senza, il
        // minimo cade sempre sul taglio più sbilanciato: una parte da
        // un'unità sola ha pochissimo da perdere, e Φ smetterebbe di
        // parlare del sistema per parlare della sua unità più isolata.
        const int nmin = na < nb ? na : nb;
        const double norm = phi_p / static_cast<double>(nmin);
        if (norm < best_norm) {
            best_norm = norm;
            best_phi = phi_p;
            best_mask = mask;
        }
    }

    if (best_norm > 1e299) return r;
    // Φ non può essere negativo: un residuo sotto lo zero è aritmetica in
    // virgola mobile su un sistema quasi staccato, non una scoperta.
    r.phi = best_phi > 0.0 ? best_phi : 0.0;
    r.phi_norm = best_norm > 0.0 ? best_norm : 0.0;
    r.mip = best_mask;
    r.valido = true;
    return r;
}

} // namespace chibi
