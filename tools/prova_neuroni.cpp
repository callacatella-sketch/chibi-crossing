// ===========================================================================
//  LA RETE — spara come un neurone, impara come una sinapsi
// ===========================================================================
//   clang++ -std=c++17 -O2 -Isrc tools/prova_neuroni.cpp src/neuroni.cpp \
//       src/phi_integrato.cpp -o /tmp/prova_neuroni && /tmp/prova_neuroni

#include "neuroni.h"
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

static void scena(double *a, double luce, double L, double A, double B,
                  double pioggia, double freddo, double sociale) {
    for (int i = 0; i < A_NUM; ++i) a[i] = 0.0;
    a[A_LUCE] = luce; a[A_COL_L] = L; a[A_COL_A] = A; a[A_COL_B] = B;
    a[A_PIOGGIA] = pioggia; a[A_FREDDO] = freddo;
    a[A_APERTO] = 0.8; a[A_SOCIALE] = sociale; a[A_ORA] = 0.5;
}

// fa vivere una rete per `sec` secondi in una scena, e torna quanto ha sparato
static double vivi(Sinapsi &syn, StatoNeurale &st, const Modulatori &mod,
                   const double *aff, double sec, bool plastica) {
    int spike = 0;
    const double dt = 0.02;
    for (int k = 0; k < static_cast<int>(sec / dt); ++k) {
        passo_neurale(syn, mod, aff, dt, &st, plastica ? &syn : nullptr);
        for (int i = 0; i < NEU_N; ++i) if ((st.spike >> i) & 1u) ++spike;
    }
    return static_cast<double>(spike) / sec;
}

int main() {
    Modulatori calmo;                       // i punti di riposo veri
    Modulatori importa = calmo; importa.dopamina = 0.85;   // succede qualcosa
    // (il riposo resta 0.4 in tutti e due: la differenza e' lo SCARTO)

    std::printf("\n=== 1. SPARA COME UN NEURONE (e non come un contatore) ===\n");
    {
        Sinapsi s; genera_sinapsi(4242, &s);
        StatoNeurale st;
        double aff[A_NUM];
        scena(aff, 0.8, 0.7, 0.0, 0.1, 0.0, 0.0, 0.3);
        const double hz = vivi(s, st, calmo, aff, 6.0, false) / NEU_N;
        std::printf("  frequenza media: %.2f Hz per neurone\n", hz);
        ok(hz > 0.3 && hz < 60.0,
           "la rete è viva ma non in crisi (una corteccia sta fra 1 e 20 Hz)");
        // e il refrattario: nessun neurone può superare 1/T_REF = 333 Hz
        ok(hz < 333.0, "nessuno supera il proprio refrattario");
    }

    std::printf("\n=== 2. I NEUROMODULATORI FANNO COSE DIVERSE ===\n");
    std::printf("(e non sono sette moltiplicatori: ognuno entra in un posto suo)\n");
    {
        double aff[A_NUM];
        scena(aff, 0.8, 0.7, 0.0, 0.1, 0.0, 0.0, 0.3);
        struct P { const char *nome; Modulatori m; };
        Modulatori m_ser = calmo; m_ser.serotonina = 0.95;
        Modulatori m_cor = calmo; m_cor.cortisolo = 0.80;
        Modulatori m_ade = calmo; m_ade.adenosina = 0.85;
        Modulatori m_mel = calmo; m_mel.melatonina = 0.85;
        P casi[] = {{"riposo", calmo}, {"serotonina alta", m_ser},
                    {"cortisolo alto", m_cor}, {"adenosina alta", m_ade},
                    {"melatonina alta", m_mel}};
        double base = 0.0;
        for (P &p : casi) {
            Sinapsi s; genera_sinapsi(4242, &s);
            StatoNeurale st;
            const double hz = vivi(s, st, p.m, aff, 4.0, false) / NEU_N;
            std::printf("  %-16s → %6.2f Hz\n", p.nome, hz);
            if (std::strcmp(p.nome, "riposo") == 0) base = hz;
            else ok(std::fabs(hz - base) > 1e-6,
                    "…e cambia qualcosa rispetto al riposo");
        }
    }

    std::printf("\n=== 3. ⚠️ IMPARA — e il TERZO FATTORE decide QUANTO ===\n");
    std::printf("(la STDP da sola impara ogni coincidenza che le capita: serve un segnale\n"
                " che dica «questo valeva la pena ricordarlo». Qui è la dopamina SOPRA IL\n"
                " PROPRIO riposo, cioè: si impara quello che è successo mentre importava.)\n");
    {
        double grigio[A_NUM];
        scena(grigio, 0.35, 0.35, -0.02, -0.05, 0.9, 0.7, 0.0);
        // ⚠️ **NON SI MISURA LO SCARTO DEI PESI DA SOLO, e due stesure ci sono
        // cascate.** L'OMEOSTASI muove i pesi sempre — è il suo mestiere, e
        // deve girare anche quando non si impara niente: misurando il totale
        // (o «quante sono salite») si misura la REGOLAZIONE e la si chiama
        // apprendimento. Qui si fa un A/B con controllo: tre reti identiche,
        // stessa scena, stesso seme; due hanno la dopamina al riposo e una la
        // ha alta. Quello che le separa è **solo** il terzo fattore.
        Sinapsi a, b, c;
        genera_sinapsi(777, &a); genera_sinapsi(777, &b); genera_sinapsi(777, &c);
        StatoNeurale sa, sb, sc;
        vivi(a, sa, calmo,   grigio, 40.0, true);
        vivi(b, sb, importa, grigio, 40.0, true);
        vivi(c, sc, calmo,   grigio, 40.0, true);   // il GEMELLO di `a`

        double d_ac = 0.0, d_ab = 0.0;
        int n_ab = 0;
        for (int k = 0; k < NEU_N * NEU_N; ++k) {
            d_ac += std::fabs(a.w[k] - c.w[k]);
            const double d = std::fabs(a.w[k] - b.w[k]);
            d_ab += d;
            if (d > 1e-5) ++n_ab;
        }
        std::printf("  due vite IDENTICHE:        scarto %.10f   (il controllo)\n", d_ac);
        std::printf("  stessa vita, dopamina su:  scarto %.6f su %d sinapsi\n", d_ab, n_ab);
        ok(d_ac == 0.0,
           "⚠️ IL CONTROLLO: due reti identiche restano identiche AL BIT (è anche "
           "la prova che la rete è deterministica e portabile)");
        ok(d_ab > 0.01 && n_ab > 5,
           "…e il terzo fattore le separa: si impara quando importa");
    }

    std::printf("\n=== 4. ⚠️ DUE VITE DIVERSE, SINAPSI DIVERSE ===\n");
    std::printf("(la stessa architettura, lo stesso seme: cambia solo cosa gli è successo)\n");
    {
        double grigio[A_NUM], sole[A_NUM];
        scena(grigio, 0.30, 0.32, -0.02, -0.06, 0.9, 0.8, 0.0);
        scena(sole,   0.95, 0.85,  0.03,  0.12, 0.0, 0.0, 0.9);
        Sinapsi a, b; genera_sinapsi(1234, &a); genera_sinapsi(1234, &b);
        StatoNeurale sa, sb;
        for (int g = 0; g < 6; ++g) {          // sei "giornate"
            vivi(a, sa, importa, grigio, 20.0, true);
            vivi(b, sb, importa, sole,   20.0, true);
        }
        double diff = 0.0; int mossi = 0;
        for (int k = 0; k < NEU_N * NEU_N; ++k) {
            const double d = std::fabs(a.w[k] - b.w[k]);
            diff += d;
            if (d > 1e-4) ++mossi;
        }
        std::printf("  sinapsi che le distinguono: %d   scarto totale %.4f\n", mossi, diff);
        ok(mossi > 10, "chi ha vissuto sotto il grigio ha un cervello diverso");

        // …e ADESSO la domanda vera: giudicano lo stesso cielo in modo diverso?
        StatoNeurale ta, tb;
        vivi(a, ta, calmo, grigio, 6.0, false);
        vivi(b, tb, calmo, grigio, 6.0, false);
        EcoNeurale ea = leggi_eco(ta, grigio), eb = leggi_eco(tb, grigio);
        std::printf("  davanti allo STESSO cielo grigio:\n");
        std::printf("     chi ci ha vissuto:      familiarità %.3f   eco %+.3f   attività %.3f\n",
                    ea.familiarita, ea.eco, ea.attivita);
        std::printf("     chi ha visto solo sole: familiarità %.3f   eco %+.3f   attività %.3f\n",
                    eb.familiarita, eb.eco, eb.attivita);
        ok(ea.valido && eb.valido, "l'eco si legge");
        ok(std::fabs(ea.familiarita - eb.familiarita) > 1e-4
           || std::fabs(ea.eco - eb.eco) > 1e-4,
           "…e lo stesso cielo NON produce la stessa cosa nei due");
    }

    std::printf("\n=== 5. NON ESPLODE E NON MUORE (omeostasi) ===\n");
    {
        Sinapsi s; genera_sinapsi(99, &s);
        StatoNeurale st;
        double forte[A_NUM];
        scena(forte, 1.0, 1.0, 0.2, 0.2, 1.0, 1.0, 1.0);       // tutto al massimo
        Modulatori estremo = calmo; estremo.dopamina = 1.0; estremo.cortisolo = 1.0;
        double hz = 0.0;
        for (int g = 0; g < 10; ++g) hz = vivi(s, st, estremo, forte, 30.0, true) / NEU_N;
        double wmax = 0.0;
        for (int k = 0; k < NEU_N * NEU_N; ++k) wmax = std::fmax(wmax, std::fabs(s.w[k]));
        std::printf("  dopo 300 s al massimo: %.2f Hz, peso massimo %.4f\n", hz, wmax);
        ok(hz > 0.05 && hz < 200.0, "la rete non è né morta né in crisi");
        ok(wmax < 1.5, "i pesi restano limitati");
        bool finiti = true;
        for (int k = 0; k < NEU_N * NEU_N; ++k) if (!std::isfinite(s.w[k])) finiti = false;
        ok(finiti, "e nessun peso è diventato NaN");
    }

    std::printf("\n=== 6. Φ DELLA RETE (e l'ablazione lo fa crollare) ===\n");
    {
        Sinapsi s; genera_sinapsi(4242, &s);
        double E[144], Q[144];
        ok(transizione_neurale(s, calmo, 0.02, 8, E, Q), "la transizione si calcola");
        RisultatoPhi r = phi_integrato(E, Q, 8);
        std::printf("  Φ della rete intera:    %.6f nat\n", r.phi);
        // ABLAZIONE: si tagliano le connessioni FRA i due gruppi
        Sinapsi tagliata = s;
        for (int i = 0; i < NEU_N; ++i)
            for (int j = 0; j < NEU_N; ++j)
                if ((i < NEU_N/2) != (j < NEU_N/2)) tagliata.w[i*NEU_N+j] = 0.0;
        double E2[144], Q2[144];
        transizione_neurale(tagliata, calmo, 0.02, 8, E2, Q2);
        RisultatoPhi r2 = phi_integrato(E2, Q2, 8);
        std::printf("  Φ con la rete TAGLIATA: %.6f nat\n", r2.phi);
        ok(r.valido && r2.valido, "tutti e due i Φ sono validi");
        ok(r2.phi < r.phi * 0.5,
           "tagliare le connessioni fa CROLLARE l'informazione integrata");
    }

    std::printf("\n=== 7. I PESI SOPRAVVIVONO AL SALVATAGGIO ===\n");
    {
        Sinapsi s; genera_sinapsi(31337, &s);
        StatoNeurale st;
        double aff[A_NUM]; scena(aff, 0.5, 0.5, 0.0, 0.0, 0.5, 0.5, 0.5);
        vivi(s, st, importa, aff, 30.0, true);
        uint8_t byte[NEU_N * NEU_N];
        pesi_in_byte(s, byte);
        Sinapsi r;
        ok(byte_in_pesi(byte, &r), "i byte tornano pesi");
        double peggio = 0.0;
        for (int k = 0; k < NEU_N * NEU_N; ++k)
            peggio = std::fmax(peggio, std::fabs(s.w[k] - r.w[k]));
        std::printf("  %d byte per persona (%d KiB per 28 vicini), errore max %.5f\n",
                    NEU_N*NEU_N, NEU_N*NEU_N*28/1024, peggio);
        ok(peggio < 0.01, "e l'errore di quantizzazione è sotto il centesimo");
    }

    std::printf("\n=== 8. IL DEGRADO ===\n");
    {
        Sinapsi s; genera_sinapsi(1, &s);
        StatoNeurale st;
        double aff[A_NUM]; scena(aff, 0.5, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0);
        ok(!passo_neurale(s, calmo, aff, -1.0, &st, nullptr), "un passo negativo è rifiutato");
        ok(!passo_neurale(s, calmo, aff, NAN, &st, nullptr), "un passo NaN è rifiutato");
        double malato[A_NUM]; std::memcpy(malato, aff, sizeof aff);
        malato[A_COL_A] = NAN;
        ok(!passo_neurale(s, calmo, malato, 0.02, &st, nullptr), "un'afferenza NaN è rifiutata");
        Sinapsi vuota;
        ok(!passo_neurale(vuota, calmo, aff, 0.02, &st, nullptr),
           "una rete non generata non gira");
    }

    std::printf("\n=== 9. IL PREZZO ===\n");
    {
        Sinapsi s; genera_sinapsi(4242, &s);
        StatoNeurale st;
        double aff[A_NUM]; scena(aff, 0.8, 0.7, 0.0, 0.1, 0.0, 0.0, 0.3);
        const int giri = 20000;
        auto t0 = std::chrono::steady_clock::now();
        for (int i = 0; i < giri; ++i) passo_neurale(s, importa, aff, 0.02, &st, &s);
        auto t1 = std::chrono::steady_clock::now();
        const double us = std::chrono::duration<double,std::micro>(t1-t0).count()/giri;
        std::printf("  un passo da 20 ms (con plasticità): %.2f µs\n", us);
        std::printf("  28 vicini a 20 Hz: %.2f ms/s  (%.2f%% di un secondo)\n",
                    us*28*20/1000.0, us*28*20/10000.0);
        ok(us * 28 * 20 / 1000.0 < 30.0, "28 reti stanno in meno del 3% del tempo");
    }

    std::printf("\n===========================================\n");
    std::printf("  %d passati, %d falliti\n", passati, falliti);
    return falliti == 0 ? 0 : 1;
}
