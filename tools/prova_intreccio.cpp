// ===========================================================================
//  L'INTRECCIO — le tre garanzie, e Φ che misura una MENTE
// ===========================================================================
//
//   clang++ -std=c++17 -O2 -Isrc tools/prova_intreccio.cpp src/intreccio.cpp \
//       src/phi_integrato.cpp -o /tmp/prova_intreccio && /tmp/prova_intreccio

#include "intreccio.h"
#include "phi_integrato.h"
#include <cstdio>
#include <cmath>
#include <cstring>
#include <chrono>

using namespace chibi;
static int passati = 0, falliti = 0;
static void ok(bool c, const char *m) {
    if (c) { ++passati; std::printf("  ok      %s\n", m); }
    else   { ++falliti; std::printf("  GUASTO  %s\n", m); }
}

// i lambda VERI di Limbico.NEURO_DECADIMENTO, nell'ordine dei canali
static const double LAM[7] = {0.05, 0.05, 0.02, 0.08, 0.10, 0.04, 0.06};
// i punti di riposo VERI di NEURO_BASELINE
static const double BASE[7] = {0.40, 0.40, 0.50, 0.08, 0.0, 0.0, 0.15};
static const char *NOMI[7] = {"dopamina","ossitocina","serotonina","cortisolo",
                              "melatonina","adenosina","endorfine"};

int main() {
    const double medio[5] = {0.5, 0.5, 0.5, 0.5, 0.5};

    std::printf("\n=== 1. IL PUNTO FISSO È INVARIANTE — per QUALUNQUE accoppiamento ===\n");
    std::printf("(è la riga che permette di non ritarare mezzo gioco per sbaglio)\n");
    {
        double peggio = 0.0;
        for (double kap : {0.55, 0.7, 0.85, 1.0}) {
            static const double TR_A[5] = {0.9,0.1,0.9,0.2,0.8};
            static const double TR_B[5] = {0.1,0.9,0.1,0.8,0.2};
            for (const double *tr : {medio, TR_A, TR_B}) {
                Intreccio it;
                if (!costruisci_intreccio(LAM, tr, &it)) { ok(false, "costruzione"); continue; }
                double n[7];
                std::memcpy(n, BASE, sizeof n);
                for (int k = 0; k < 4000; ++k) passo_intreccio(it, 0.05, kap, BASE, n);
                for (int i = 0; i < 7; ++i) peggio = std::fmax(peggio, std::fabs(n[i] - BASE[i]));
            }
        }
        std::printf("  scarto massimo dal punto di riposo dopo 4000 passi: %.3e\n", peggio);
        ok(peggio < 1e-12, "chi parte al riposo ci resta, al bit");
    }

    std::printf("\n=== 2. Φ OGGI È ZERO PER TEOREMA (la matrice è diagonale) ===\n");
    {
        double A[49], Q[49];
        std::memset(A, 0, sizeof A); std::memset(Q, 0, sizeof Q);
        for (int i = 0; i < 7; ++i) { A[i*7+i] = std::exp(-LAM[i] * 0.05); Q[i*7+i] = 1.0; }
        RisultatoPhi r = phi_integrato(A, Q, 7);
        std::printf("  Φ della chimica di oggi: %.6e\n", r.phi);
        ok(r.valido && r.phi < 1e-12, "il gioco di oggi ha informazione integrata NULLA");
    }

    std::printf("\n=== 3. …E CON L'INTRECCIO SI ACCENDE ===\n");
    {
        Intreccio it;
        ok(costruisci_intreccio(LAM, medio, &it), "l'intreccio si costruisce");
        double E[49], Q[49];
        ok(matrice_di_transizione(it, 0.05, 1.0, E, Q), "la transizione esiste");
        ok(q_diagonale(Q, 7), "il rumore è diagonale: Φ non si può barare");
        RisultatoPhi r = phi_integrato(E, Q, 7);
        std::printf("  Φ con l'intreccio: %.6f nat   (MIP 0x%02x)\n", r.phi, r.mip);
        // quali canali restano da una parte e dall'altra del taglio minimo
        std::printf("  la partizione minima:  ");
        for (int i = 0; i < 7; ++i)
            if (i == 0 || ((r.mip >> (i-1)) & 1u)) std::printf("%s ", NOMI[i]);
        std::printf("  |  ");
        for (int i = 1; i < 7; ++i)
            if (!((r.mip >> (i-1)) & 1u)) std::printf("%s ", NOMI[i]);
        std::printf("\n");
        ok(r.valido && r.phi > 1e-6, "Φ è positivo: le parti non si possono staccare gratis");
    }

    std::printf("\n=== 4. ⚠️ Φ MISURA UNA MENTE, NON UNA TABELLA ===\n");
    std::printf("(un Φ uguale per tutti e per sempre sarebbe un test unitario su una costante)\n");
    {
        // --- fra PERSONE diverse
        double phi_min = 1e9, phi_max = -1e9;
        for (double cod : {0.05, 0.25, 0.5, 0.75, 0.95})
            for (double lea : {0.05, 0.5, 0.95}) {
                const double tr[5] = {cod, 1.0 - cod, lea, 1.0 - lea, cod};
                Intreccio it;
                if (!costruisci_intreccio(LAM, tr, &it)) continue;
                double E[49], Q[49];
                matrice_di_transizione(it, 0.05, 1.0, E, Q);
                RisultatoPhi r = phi_integrato(E, Q, 7);
                if (!r.valido) continue;
                phi_min = std::fmin(phi_min, r.phi);
                phi_max = std::fmax(phi_max, r.phi);
            }
        std::printf("  fra 15 caratteri diversi: Φ da %.6f a %.6f  (+%.1f%%)\n",
                    phi_min, phi_max, 100.0 * (phi_max / phi_min - 1.0));
        ok(phi_max > phi_min * 1.02, "due vicini diversi hanno un'integrazione diversa");

        // --- dentro UNA persona, al variare di come sta
        Intreccio it;
        costruisci_intreccio(LAM, medio, &it);
        std::printf("  e nella stessa persona, al variare della tensione:\n");
        double p_calmo = 0.0, p_teso = 0.0;
        for (double kap : {1.0, 0.85, 0.70, 0.55}) {
            double E[49], Q[49];
            matrice_di_transizione(it, 0.05, kap, E, Q);
            RisultatoPhi r = phi_integrato(E, Q, 7);
            std::printf("     κ=%.2f  →  Φ = %.6f\n", kap, r.phi);
            if (kap == 1.0) p_calmo = r.phi;
            if (kap == 0.55) p_teso = r.phi;
        }
        ok(p_calmo > p_teso * 1.1,
           "sotto stress l'informazione integrata CALA: la mente si restringe");
    }

    std::printf("\n=== 5. LA STESSA GENTILEZZA, IN DUE MENTI DIVERSE ===\n");
    std::printf("(nessuna tabella dice cosa fa un regalo: dipende da dov'era quella mente)\n");
    {
        struct Caso { const char *chi; double tr[5]; double n0[7]; };
        Caso casi[] = {
            {"sereno",  {0.5,0.5,0.5,0.5,0.5}, {0.40,0.40,0.50,0.08,0.0,0.10,0.15}},
            {"in ansia",{0.5,0.5,0.5,0.5,0.5}, {0.40,0.40,0.50,0.42,0.0,0.10,0.15}},
            {"esausto", {0.5,0.5,0.5,0.5,0.5}, {0.40,0.40,0.50,0.08,0.0,0.62,0.15}},
        };
        for (Caso &c : casi) {
            Intreccio it;
            costruisci_intreccio(LAM, c.tr, &it);
            double n[7]; std::memcpy(n, c.n0, sizeof n);
            // la gentilezza: +0.15 dopamina, +0.12 ossitocina, +0.12 serotonina
            n[C_DOPAMINA]  = std::fmin(1.0, n[C_DOPAMINA]  + 0.15);
            n[C_OSSITOCINA]= std::fmin(1.0, n[C_OSSITOCINA]+ 0.12);
            n[C_SEROTONINA]= std::fmin(1.0, n[C_SEROTONINA]+ 0.12);
            const double cort0 = n[C_CORTISOLO];
            for (int k = 0; k < 600; ++k)       // 30 s di gioco
                passo_intreccio(it, 0.05, 1.0, BASE, n);
            std::printf("  %-9s  cortisolo %.4f → %.4f   (%+.4f)   dopamina %.4f\n",
                        c.chi, cort0, n[C_CORTISOLO], n[C_CORTISOLO] - cort0,
                        n[C_DOPAMINA]);
        }
        std::printf("  ⚠️ e SENZA intreccio la stessa gentilezza lascia il cortisolo\n"
                    "     esattamente dov'era, in tutti e tre — perché i canali non si parlano.\n");
    }

    std::printf("\n=== 6. IL PREZZO ===\n");
    {
        Intreccio it; costruisci_intreccio(LAM, medio, &it);
        double n[7]; std::memcpy(n, BASE, sizeof n);
        const int giri = 200000;
        auto t0 = std::chrono::steady_clock::now();
        for (int i = 0; i < giri; ++i) passo_intreccio(it, 0.05, 0.9, BASE, n);
        auto t1 = std::chrono::steady_clock::now();
        const double us = std::chrono::duration<double,std::micro>(t1-t0).count()/giri;
        std::printf("  un passo: %.3f µs  →  28 vicini a 20 Hz = %.3f ms/s\n",
                    us, us * 28 * 20 / 1000.0);
        double E[49], Q[49];
        auto t2 = std::chrono::steady_clock::now();
        double acc = 0.0;
        for (int i = 0; i < 2000; ++i) {
            matrice_di_transizione(it, 0.05, 0.9, E, Q);
            acc += phi_integrato(E, Q, 7).phi;
        }
        auto t3 = std::chrono::steady_clock::now();
        std::printf("  un Φ:     %.1f µs  →  28 vicini a 1 Hz  = %.3f ms/s\n",
                    std::chrono::duration<double,std::micro>(t3-t2).count()/2000.0,
                    std::chrono::duration<double,std::micro>(t3-t2).count()/2000.0*28/1000.0);
        ok(us < 5.0, "il passo costa meno di cinque microsecondi");
    }

    std::printf("\n=== 7. IL DEGRADO, e non inventa mai un numero ===\n");
    {
        Intreccio it; costruisci_intreccio(LAM, medio, &it);
        double n[7]; std::memcpy(n, BASE, sizeof n);
        double prima[7]; std::memcpy(prima, n, sizeof n);
        ok(!passo_intreccio(it, -1.0, 1.0, BASE, n), "un passo negativo è rifiutato");
        ok(!passo_intreccio(it, NAN, 1.0, BASE, n), "un passo NaN è rifiutato");
        double bers_malato[7]; std::memcpy(bers_malato, BASE, sizeof BASE);
        bers_malato[3] = NAN;
        ok(!passo_intreccio(it, 0.05, 1.0, bers_malato, n), "un bersaglio NaN è rifiutato");
        ok(std::memcmp(prima, n, sizeof n) == 0,
           "…e in nessuno dei tre casi lo stato è stato toccato");
        Intreccio vuoto;
        ok(!passo_intreccio(vuoto, 0.05, 1.0, BASE, n),
           "un intreccio non costruito non gira");
        // un lambda impossibile non deve produrre un intreccio
        double lam_male[7]; std::memcpy(lam_male, LAM, sizeof LAM);
        lam_male[2] = 0.001;   // sotto il budget della riga della serotonina
        Intreccio it2;
        ok(!costruisci_intreccio(lam_male, medio, &it2),
           "un lambda che sfonda il budget di riga è RIFIUTATO, non aggiustato");
    }

    std::printf("\n===========================================\n");
    std::printf("  %d passati, %d falliti\n", passati, falliti);
    return falliti == 0 ? 0 : 1;
}
