// ===========================================================================
//  LA VERIFICA DI Φ — contro casi di cui la risposta si sa PRIMA
// ===========================================================================
//
//   clang++ -std=c++17 -O2 -Isrc tools/prova_phi.cpp src/phi_integrato.cpp \
//       -o /tmp/prova_phi && /tmp/prova_phi
//
//  ⚠️ Un Φ sbagliato è peggio di nessun Φ: sembra una misura. Questo banco
//  non chiede al codice se è d'accordo con sé stesso — gli dà sistemi la cui
//  informazione integrata è nota per ARGOMENTO, e pretende quel numero.

#include "phi_integrato.h"
#include <cstdio>
#include <cmath>
#include <cstring>
#include <chrono>

using namespace chibi;

static int falliti = 0;
static int passati = 0;

static void ok(bool c, const char *msg) {
    if (c) { ++passati; std::printf("  ok      %s\n", msg); }
    else   { ++falliti; std::printf("  GUASTO  %s\n", msg); }
}

static void zero(double v, double tol, const char *msg) {
    if (std::fabs(v) <= tol) { ++passati; std::printf("  ok      %s (%.3e)\n", msg, v); }
    else { ++falliti; std::printf("  GUASTO  %s: atteso 0, ottenuto %.6e\n", msg, v); }
}

// un sistema a due blocchi che NON si parlano
// ⚠️ LA FIXTURE RISCALA AL RAGGIO SPETTRALE. Senza, una matrice densa
// diverge e la covarianza stazionaria non esiste: sei dei primi otto rossi
// di questo banco erano la fixture che si costruiva un sistema impossibile,
// non il codice. `cross` resta il rapporto FRA i blocchi, che è la cosa che
// si sta variando; la scala non lo tocca perché moltiplica tutto.
static void blocchi(double *A, double *Q, int n, int taglio, double acc, double cross) {
    std::memset(A, 0, sizeof(double) * n * n);
    std::memset(Q, 0, sizeof(double) * n * n);
    for (int i = 0; i < n; ++i) {
        A[i * n + i] = acc;
        Q[i * n + i] = 1.0;
        for (int j = 0; j < n; ++j) {
            if (i == j) continue;
            const bool stesso = (i < taglio) == (j < taglio);
            A[i * n + j] = stesso ? acc * 0.35 : cross;
        }
    }
    scala_a_raggio_spettrale(A, n, 0.85);
}

int main() {
    std::printf("\n=== 1. IL SISTEMA STACCATO HA Φ = 0, AL BIT ===\n");
    std::printf("(due blocchi che non si scambiano una riga: dividerlo non distrugge niente)\n");
    for (int n : {4, 6, 7, 8}) {
        double A[PHI_MAX_N * PHI_MAX_N], Q[PHI_MAX_N * PHI_MAX_N];
        blocchi(A, Q, n, n / 2, 0.6, 0.0);
        RisultatoPhi r = phi_integrato(A, Q, n);
        char m[128];
        std::snprintf(m, sizeof m, "n=%d, due blocchi staccati", n);
        ok(r.valido, m);
        zero(r.phi, 1e-10, "   Φ");
    }

    // ⚠️ IL TAGLIO A SINGOLETTO SULL'UNITÀ 0, che per un pezzo non è stato
    // valutato mai. Il ciclo delle bipartizioni partiva da `mask = 1`, e la
    // maschera 0 È il taglio «{unità 0} | tutte le altre»: l'unico modo di
    // generarlo, perché per avere l'unità 0 dall'altra parte servirebbe una
    // maschera che non esiste. In cambio si spendeva un giro sulla maschera
    // `2^(n-1)-1`, che lascia la parte destra vuota ed è invalida: 62 tagli
    // valutati su 63, con i sette canali della neurochimica.
    //
    // Φ è un MINIMO: un taglio saltato non è rumore, è un Φ SOVRASTIMATO.
    // Qui si stacca proprio l'unità 0 dal resto, quindi quel taglio non
    // distrugge NIENTE e Φ deve essere zero al bit. Col ciclo di prima
    // usciva il minimo sugli altri tagli, che spezzano un blocco connesso.
    //
    // ⚠️ E il caso 1 non lo copriva: taglia a `n/2`, cioè su una maschera
    // diversa da zero, che veniva valutata comunque.
    std::printf("\n=== 1b. IL TAGLIO A SINGOLETTO SULL'UNITÀ 0 ===\n");
    std::printf("(l'unità 0 staccata da tutte le altre: quel taglio non toglie niente)\n");
    for (int n : {4, 6, 7, 8}) {
        double A[PHI_MAX_N * PHI_MAX_N], Q[PHI_MAX_N * PHI_MAX_N];
        blocchi(A, Q, n, 1, 0.6, 0.0);
        RisultatoPhi r = phi_integrato(A, Q, n);
        char m[160];
        std::snprintf(m, sizeof m, "n=%d, l'unità 0 e' staccata: il taglio esiste", n);
        ok(r.valido, m);
        zero(r.phi, 1e-10, "   Φ");
        std::snprintf(m, sizeof m, "   …e la MIP e' proprio quella maschera (0x%02x)", r.mip);
        ok(r.mip == 0u, m);
    }

    std::printf("\n=== 2. UNA SOLA CONNESSIONE ACCENDE Φ ===\n");
    for (double c : {0.0, 0.02, 0.05, 0.10, 0.20, 0.35}) {
        double A[PHI_MAX_N * PHI_MAX_N], Q[PHI_MAX_N * PHI_MAX_N];
        blocchi(A, Q, 6, 3, 0.5, c);
        RisultatoPhi r = phi_integrato(A, Q, 6);
        std::printf("  accoppiamento %.2f → Φ = %.6f   (MIP 0x%02x)\n", c, r.phi, r.mip);
    }

    std::printf("\n=== 3. Φ CRESCE COL LEGAME (monotonia) ===\n");
    {
        double prec = -1.0;
        bool mono = true;
        for (double c = 0.0; c <= 0.30001; c += 0.02) {
            double A[PHI_MAX_N * PHI_MAX_N], Q[PHI_MAX_N * PHI_MAX_N];
            blocchi(A, Q, 6, 3, 0.5, c);
            RisultatoPhi r = phi_integrato(A, Q, 6);
            if (r.phi < prec - 1e-9) mono = false;
            prec = r.phi;
        }
        ok(mono, "Φ non scende mai mentre il legame cresce");
    }

    std::printf("\n=== 4. LA MIP TROVA IL PUNTO DEBOLE ===\n");
    std::printf("(due grappoli fitti legati da un filo: il taglio giusto è FRA i grappoli)\n");
    {
        const int n = 6;
        double A[PHI_MAX_N * PHI_MAX_N], Q[PHI_MAX_N * PHI_MAX_N];
        std::memset(A, 0, sizeof(double) * n * n);
        std::memset(Q, 0, sizeof(double) * n * n);
        for (int i = 0; i < n; ++i) {
            A[i * n + i] = 0.45; Q[i * n + i] = 1.0;
            for (int j = 0; j < n; ++j) {
                if (i == j) continue;
                A[i * n + j] = ((i < 3) == (j < 3)) ? 0.30 : 0.015;
            }
        }
        scala_a_raggio_spettrale(A, n, 0.85);
        RisultatoPhi r = phi_integrato(A, Q, n);
        // la parte sinistra contiene sempre l'unità 0; il taglio giusto è
        // {0,1,2} vs {3,4,5}, cioè i bit delle unità 1 e 2 accesi
        const unsigned atteso = (1u << 0) | (1u << 1);   // unità 1 e 2
        std::printf("  MIP = 0x%02x (atteso 0x%02x)   Φ = %.6f\n", r.mip, atteso, r.phi);
        ok(r.mip == atteso, "la partizione minima è il filo fra i due grappoli");
    }

    std::printf("\n=== 5. LA PORTA DA CUI SI BAREREBBE, E COM'È CHIUSA ===\n");
    std::printf("(A diagonale, Q pieno: le parti NON si parlano, si somigliano e basta)\n");
    {
        const int n = 6;
        double A[PHI_MAX_N * PHI_MAX_N], Q[PHI_MAX_N * PHI_MAX_N];
        std::memset(A, 0, sizeof(double) * n * n);
        for (int i = 0; i < n; ++i) {
            A[i * n + i] = 0.5;
            for (int j = 0; j < n; ++j) Q[i * n + j] = (i == j) ? 1.0 : 0.6;
        }
        RisultatoPhi r = phi_integrato(A, Q, n);
        // ⚠️ E LA RISPOSTA ONESTA È CHE Φ_SI CONTA ANCHE QUESTO. La stochastic
        // interaction misura la dipendenza TOTALE — dinamica *più*
        // istantanea — quindi un rumore correlato la alza senza che nessuna
        // parte parli con nessuna. Non è un difetto della formula: è cosa
        // misura. Per noi però sarebbe la porta da cui si bara, e si chiude
        // con una PROPRIETÀ del sostrato, non con una taratura.
        std::printf("  Φ con rumore correlato e dinamica staccata: %.6f\n", r.phi);
        ok(r.phi > 0.1, "Φ_SI conta la correlazione istantanea (è cosa misura)");
        ok(!q_diagonale(Q, n), "…e `q_diagonale` la riconosce: il sostrato la vieta");
        double Qd[PHI_MAX_N * PHI_MAX_N];
        std::memset(Qd, 0, sizeof(double) * n * n);
        for (int i = 0; i < n; ++i) Qd[i * n + i] = 1.0;
        ok(q_diagonale(Qd, n), "un rumore indipendente passa");
        RisultatoPhi rd = phi_integrato(A, Qd, n);
        zero(rd.phi, 1e-10, "e con Q diagonale e A diagonale Φ torna zero esatto");
    }

    std::printf("\n=== 6. LA COVARIANZA STAZIONARIA È GIUSTA (Σ = AΣAᵀ + Q) ===\n");
    {
        const int n = 5;
        double A[PHI_MAX_N * PHI_MAX_N], Q[PHI_MAX_N * PHI_MAX_N], S[PHI_MAX_N * PHI_MAX_N];
        blocchi(A, Q, n, 2, 0.55, 0.12);
        bool okl = lyapunov_discreta(A, Q, n, S);
        ok(okl, "Lyapunov converge");
        double peggio = 0.0;
        for (int i = 0; i < n; ++i)
            for (int j = 0; j < n; ++j) {
                double s = Q[i * n + j];
                for (int k = 0; k < n; ++k)
                    for (int l = 0; l < n; ++l) s += A[i * n + k] * S[k * n + l] * A[j * n + l];
                peggio = std::fmax(peggio, std::fabs(s - S[i * n + j]));
            }
        zero(peggio, 1e-11, "il residuo dell'equazione");
    }

    std::printf("\n=== 7. UN SISTEMA INSTABILE NON INVENTA UN NUMERO ===\n");
    {
        const int n = 4;
        double A[PHI_MAX_N * PHI_MAX_N], Q[PHI_MAX_N * PHI_MAX_N];
        // ⚠️ costruita A MANO, perché `blocchi()` adesso riscala — e la
        // riscalatura È la cura. Qui si prova il ramo che resta: chi arriva
        // con una matrice instabile non deve ricevere un numero.
        std::memset(A, 0, sizeof(double) * n * n);
        std::memset(Q, 0, sizeof(double) * n * n);
        for (int i = 0; i < n; ++i) {
            Q[i * n + i] = 1.0;
            for (int j = 0; j < n; ++j) A[i * n + j] = (i == j) ? 1.4 : 0.3;
        }
        RisultatoPhi r = phi_integrato(A, Q, n);
        ok(!r.valido, "Φ si dichiara NON valido invece di restituire spazzatura");
        zero(r.phi, 0.0, "  e il numero resta zero, non spazzatura");
        // e la riscalatura la rende trattabile, che è il punto
        const double rho = scala_a_raggio_spettrale(A, n, 0.85);
        std::printf("  raggio spettrale misurato prima della scala: %.4f\n", rho);
        ok(rho > 1.0, "l'iterazione delle potenze lo vede instabile");
        RisultatoPhi r2 = phi_integrato(A, Q, n);
        ok(r2.valido, "…e riscalata, la stessa matrice dà un Φ valido");
    }

    std::printf("\n=== 8. IL PREZZO ===\n");
    for (int n : {7, 10, 12}) {
        double A[PHI_MAX_N * PHI_MAX_N], Q[PHI_MAX_N * PHI_MAX_N];
        blocchi(A, Q, n, n / 2, 0.5, 0.12);
        const int giri = n <= 7 ? 2000 : (n <= 10 ? 300 : 60);
        auto t0 = std::chrono::steady_clock::now();
        double acc = 0.0;
        for (int i = 0; i < giri; ++i) acc += phi_integrato(A, Q, n).phi;
        auto t1 = std::chrono::steady_clock::now();
        const double us = std::chrono::duration<double, std::micro>(t1 - t0).count() / giri;
        std::printf("  n=%2d  %5d bipartizioni  →  %8.1f µs a chiamata   (Φ=%.4f)\n",
                    n, (1 << (n - 1)) - 1, us, acc / giri);
    }

    std::printf("\n===========================================\n");
    std::printf("  %d passati, %d falliti\n", passati, falliti);
    return falliti == 0 ? 0 : 1;
}
