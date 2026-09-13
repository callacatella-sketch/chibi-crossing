// ===========================================================================
//  IL CARICO — i due bacini, l'isteresi, e il certificato
// ===========================================================================
//   clang++ -std=c++17 -O2 -Isrc tools/prova_carico.cpp src/intreccio.cpp \
//       src/phi_integrato.cpp -o /tmp/prova_carico && /tmp/prova_carico

#include "intreccio.h"
#include "phi_integrato.h"
#include <cstdio>
#include <cmath>
#include <cstring>
#include <initializer_list>

using namespace chibi;
static int passati = 0, falliti = 0;
static void ok(bool c, const char *m) {
    if (c) { ++passati; std::printf("  ok      %s\n", m); }
    else   { ++falliti; std::printf("  GUASTO  %s\n", m); }
}
static const double LAM[7]  = {0.05,0.05,0.02,0.08,0.10,0.04,0.06};
static const double BASE[7] = {0.40,0.40,0.50,0.08,0.0,0.0,0.15};
static const double MEDIO[5] = {0.5,0.5,0.5,0.5,0.5};

// lascia riposare una mente per `sec` secondi e torna dov'è finito il cortisolo
static double riposa(bool acceso, double cort0, double sec) {
    Intreccio it;
    costruisci_intreccio(LAM, MEDIO, &it);
    it.carico_acceso = acceso;
    double n[7]; std::memcpy(n, BASE, sizeof n);
    n[C_CORTISOLO] = cort0;
    for (int k = 0; k < static_cast<int>(sec / 0.05); ++k)
        passo_intreccio(it, 0.05, 1.0, BASE, n);
    return n[C_CORTISOLO];
}

int main() {
    std::printf("\n=== 1. I TRE PUNTI FISSI, TROVATI E NON CREDUTI ===\n");
    double r[3];
    const int n = punti_fissi_carico(LAM[C_CORTISOLO], BASE[C_CORTISOLO], r);
    std::printf("  trovati %d punti fissi:", n);
    for (int i = 0; i < n; ++i) std::printf("  %.4f", r[i]);
    std::printf("\n");
    ok(n == 3, "il sistema è BISTABILE: due bacini, e un crinale in mezzo");
    if (n == 3) {
        std::printf("    stato basso  %.4f   ← il punto di riposo di SEMPRE (%.2f)\n",
                    r[0], BASE[C_CORTISOLO]);
        std::printf("    CRINALE      %.4f   ← la vita normale arriva a 0.42\n", r[1]);
        std::printf("    stato alto   %.4f   ← e ci si RESTA\n", r[2]);
        ok(std::fabs(r[0] - BASE[C_CORTISOLO]) < 1e-3,
           "lo stato basso È il punto di riposo di prima: l'invarianza è salva");
        ok(r[1] > 0.47,
           "il crinale sta SOPRA la vita normale: non ci si cade vivendo");
        std::printf("    stacco fra i due bacini: %.4f\n", r[2] - r[1]);
        ok(r[2] > r[1] + 0.25,
           "e lo stacco fra i due bacini è netto: sono due stati, non due sfumature");
    }

    std::printf("\n=== 2. ⚠️ SOTTO IL CRINALE IL GIOCO È QUELLO DI IERI, AL BIT ===\n");
    {
        double peggio = 0.0;
        for (double c0 : {0.02, 0.08, 0.20, 0.35, 0.42, 0.50}) {
            const double spento = riposa(false, c0, 300.0);
            const double acceso = riposa(true,  c0, 300.0);
            peggio = std::fmax(peggio, std::fabs(spento - acceso));
        }
        std::printf("  scarto massimo fra acceso e spento, partendo sotto il crinale: %.3e\n",
                    peggio);
        ok(peggio == 0.0,
           "chi non supera il crinale ha il gioco di ieri BIT PER BIT (la zona morta)");
    }

    std::printf("\n=== 3. I DUE BACINI, PERCORSI DAVVERO ===\n");
    {
        for (double c0 : {0.10, 0.40, 0.55, 0.58, 0.60, 0.70, 0.90}) {
            const double fine = riposa(true, c0, 900.0);
            std::printf("  parte da %.2f  →  finisce a %.4f   (%s)\n", c0, fine,
                        fine > 0.5 ? "resta GIÙ, nel carico" : "torna al riposo");
        }
        ok(riposa(true, 0.55, 900.0) < 0.2, "da sotto il crinale si torna su");
        ok(riposa(true, 0.70, 900.0) > 0.6, "e da sopra si RESTA: è un secondo stato");
    }

    std::printf("\n=== 4. ⚠️ L'ISTERESI — smettere di spingere NON BASTA ===\n");
    std::printf("(ed è questa la misura giusta, non «quanti punti devi scendere»:\n"
                " la domanda è se togliere la causa riporta indietro, e la risposta\n"
                " è no — è la differenza fra un brutto periodo e uno stato)\n");
    {
        // uno viene spinto sopra il crinale, POI la causa sparisce del tutto:
        // nessuna produzione, nessuno stress, il bersaglio è il riposo
        Intreccio it; costruisci_intreccio(LAM, MEDIO, &it); it.carico_acceso = true;
        double n3[7]; std::memcpy(n3, BASE, sizeof n3);
        n3[C_CORTISOLO] = 0.72;
        for (double t = 0.0; t < 3600.0; t += 0.05)
            passo_intreccio(it, 0.05, 1.0, BASE, n3);
        std::printf("  spinto a 0.72, poi UN'ORA di gioco senza più nessuna causa:\n");
        std::printf("     il cortisolo è a %.4f\n", n3[C_CORTISOLO]);
        ok(n3[C_CORTISOLO] > 0.6,
           "⚠️ togliere la causa NON lo riporta indietro: è un secondo stato");

        // e col carico SPENTO, lo stesso identico colpo si riassorbe
        Intreccio sp; costruisci_intreccio(LAM, MEDIO, &sp); sp.carico_acceso = false;
        double n4[7]; std::memcpy(n4, BASE, sizeof n4);
        n4[C_CORTISOLO] = 0.72;
        for (double t = 0.0; t < 3600.0; t += 0.05)
            passo_intreccio(sp, 0.05, 1.0, BASE, n4);
        std::printf("  e lo STESSO colpo, col carico spento, finisce a %.4f\n",
                    n4[C_CORTISOLO]);
        ok(n4[C_CORTISOLO] < 0.12,
           "…mentre nel gioco di ieri lo stesso colpo si riassorbiva e basta");

        // QUANTO serve per tirarlo fuori: si abbassa il cortisolo a gradini
        double serve = -1.0;
        for (double giu = 0.90; giu >= 0.0; giu -= 0.01) {
            Intreccio q; costruisci_intreccio(LAM, MEDIO, &q); q.carico_acceso = true;
            double m[7]; std::memcpy(m, BASE, sizeof m);
            m[C_CORTISOLO] = giu;
            for (double t = 0.0; t < 1800.0; t += 0.05)
                passo_intreccio(q, 0.05, 1.0, BASE, m);
            if (m[C_CORTISOLO] < 0.2) { serve = giu; break; }
        }
        std::printf("  per tirarlo fuori bisogna portarlo sotto %.2f — e da %.2f\n",
                    serve, n3[C_CORTISOLO]);
        std::printf("  vuol dire toglierne %.2f, che è QUANTO IL GIOCATORE DEVE FARE.\n",
                    n3[C_CORTISOLO] - serve);
        ok(serve > 0.0 && serve < n3[C_CORTISOLO],
           "l'uscita esiste (non è una trappola) ma costa un gesto vero");
    }

    std::printf("\n=== 5. IL CERTIFICATO — lo stato non esce da [0,1] ===\n");
    {
        std::printf("  alpha %.4f < lambda*(1-riposo) = %.4f  (il `static_assert`)\n",
                    CARICO_ALPHA, LAM[C_CORTISOLO] * (1.0 - BASE[C_CORTISOLO]));
        ok(CARICO_ALPHA < LAM[C_CORTISOLO] * (1.0 - BASE[C_CORTISOLO]),
           "f(1) < 0: da uno si torna sempre giù");
        // e lo si prova davvero, partendo dal massimo
        Intreccio it; costruisci_intreccio(LAM, MEDIO, &it); it.carico_acceso = true;
        double n2[7]; for (int i = 0; i < 7; ++i) n2[i] = 1.0;
        bool dentro = true;
        for (int k = 0; k < 40000; ++k) {
            passo_intreccio(it, 0.05, 1.0, BASE, n2);
            for (int i = 0; i < 7; ++i)
                if (!(n2[i] >= 0.0 && n2[i] <= 1.0) || !std::isfinite(n2[i]))
                    dentro = false;
        }
        std::printf("  da TUTTO a uno, dopo 2000 s: cortisolo %.4f\n", n2[C_CORTISOLO]);
        ok(dentro, "e in 40000 passi nessun canale è mai uscito da [0,1]");
    }

    std::printf("\n=== 6. E Φ NON SI ROMPE ===\n");
    {
        Intreccio it; costruisci_intreccio(LAM, MEDIO, &it);
        it.carico_acceso = true;
        double E[49], Q[49];
        ok(matrice_di_transizione(it, 0.05, 1.0, E, Q), "la transizione esiste ancora");
        RisultatoPhi p = phi_integrato(E, Q, 7);
        std::printf("  Φ con il carico acceso: %.7f\n", p.phi);
        ok(p.valido && p.phi > 0.0, "…e Φ resta valido e positivo");
        std::printf("  ⚠️ e Φ NON vede il carico: è calcolato sulla parte LINEARE,\n"
                    "     e il carico è la non-linearità. Chi vorrà un Φ che lo veda\n"
                    "     deve linearizzare attorno allo stato ALTO, non al riposo.\n");
    }

    std::printf("\n===========================================\n");
    std::printf("  %d passati, %d falliti\n", passati, falliti);
    return falliti == 0 ? 0 : 1;
}
