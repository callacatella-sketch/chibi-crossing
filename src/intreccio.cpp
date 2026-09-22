#include "intreccio.h"

#include <cmath>
#include <cstring>

namespace chibi {
namespace {

constexpr int N = INTRECCIO_N;

// ---------------------------------------------------------------------------
//  LA TABELLA DEGLI ACCOPPIAMENTI
// ---------------------------------------------------------------------------
//
//  Ogni voce è `g[bersaglio][sorgente]`: di quanto il canale «sorgente»
//  spinge il canale «bersaglio», per unità e per secondo di gioco.
//
//  ⚠️ **NON SONO NUMERI INVENTATI, e nemmeno biochimica ricopiata da un
//  manuale.** Ognuno esiste perché il gioco DICEVA GIÀ quella cosa, in un
//  posto dove era scritta a mano e istantanea. L'intreccio non aggiunge
//  affermazioni sul mondo: prende quelle che c'erano e dà loro un CORPO e
//  una DURATA. Dove il gioco non diceva niente, qui non c'è una riga.
//
//   · ossitocina ⊣ cortisolo — il tampone sociale. `Limbico.percepisci`
//     divideva già la paura per la vicinanza di un amico, ma nello stesso
//     fotogramma: un conforto che non lasciava traccia. Adesso ha una
//     costante di tempo, cioè una gentilezza continua a lavorare dopo.
//   · cortisolo ⊣ serotonina — «di malumore da giorni». La relazione era in
//     `bersaglio_umore()` e girava a punto fisso: solo chi era teso *a
//     regime* stava peggio. Adesso morde anche un colpo solo.
//   · adenosina ⊣ dopamina — «troppo stanco perché mi importi». Era il
//     `riposo` che vinceva sull'agenda, cioè una gara fra punteggi: qui è
//     il desiderio che si abbassa da sé.
//   · cortisolo ⊣ melatonina — «troppo su di giri per dormire».
//   · serotonina → melatonina — l'unica di pura biochimica (la seconda è
//     precursore della prima), e sta qui perché rende la sera di chi è
//     sereno diversa da quella di chi non lo è.
//   · endorfine ⊣ cortisolo — il sollievo che spegne l'allarme.
//   · dopamina → endorfine — la spinta che si porta dietro il piacere.
//
//  ⚠️ **E NON C'È NESSUN ARCO CHE FABBRICHI UNA VALENZA VERSO UNA PERSONA.**
//  Il sostrato muove sette numeri che avevano già dei lettori: non apre una
//  scena, non muove un corpo, non scrive una riga nel libro mastro. Il
//  perturbante che ne esce è che la reazione non si può più SCOMPORRE — non
//  che il villaggio diventi ostile.
struct Arco { int bersaglio; int sorgente; double g; };

constexpr Arco ARCHI[] = {
    { C_CORTISOLO,  C_OSSITOCINA, -0.030 },
    { C_CORTISOLO,  C_ENDORFINE,  -0.022 },
    { C_SEROTONINA, C_CORTISOLO,  -0.011 },
    { C_DOPAMINA,   C_ADENOSINA,  -0.026 },
    { C_MELATONINA, C_CORTISOLO,  -0.020 },
    { C_MELATONINA, C_SEROTONINA,  0.018 },
    { C_ENDORFINE,  C_DOPAMINA,    0.020 },
};
constexpr int NARCHI = static_cast<int>(sizeof(ARCHI) / sizeof(ARCHI[0]));

// Quanto il carattere tinge un arco. Stessa disciplina di
// `Limbico.tinta_carattere`: uno SCARTO dal carattere neutro, così un
// carattere medio somma **zero esatto** e per lui il gioco è bit-identico.
// ⚠️ E il tratto che tinge non è scelto a caso: è quello che nel gioco
// governava già quella relazione.
//
//  ⚠️ **E OGNI ARCO È TINTO DAL CARATTERE — cioè due vicini non hanno lo
//  stesso cervello con impostazioni diverse: hanno cervelli DIVERSI.**
//
//  Alla prima stesura erano tinti tre archi su sette, e MISURATO: Φ variava
//  dello **0,2%** fra quindici caratteri. Cioè l'intreccio era del villaggio,
//  non della persona — e un Φ uguale per tutti torna a essere la proprietà di
//  una tabella invece che la misura di una mente. Adesso sono tutti e sette,
//  con l'ampiezza più larga che il budget di riga concede.
//
//  La tinta è uno SCARTO dal carattere neutro (`(v−0.5)·2`), la stessa
//  disciplina di `Limbico.tinta_carattere`: **a 0.5 somma zero esatto**, e
//  per un carattere medio l'intreccio è quello di prima al bit — quindi
//  tutte le misure già prese restano valide senza rifarle.
struct Tinta { int arco; int tratto; double amp; };
// i tratti, nell'ordine di ChibiDNA
constexpr int T_CODARDIA = 0, T_GRINTA = 1, T_LEALTA = 2,
              T_AMBIZIONE = 3, T_ORGOGLIO = 4;
constexpr Tinta TINTE[] = {
    // chi è leale riceve più conforto dagli altri: il tampone sociale è suo
    { 0, T_LEALTA,    -0.010 },
    // chi ha grinta si calma da sé: il sollievo gli spegne di più l'allarme
    { 1, T_GRINTA,    -0.010 },
    // chi è codardo si lascia mordere di più dallo stress
    { 2, T_CODARDIA,  -0.006 },
    // chi ha grinta non si lascia spegnere dalla stanchezza
    { 3, T_GRINTA,     0.016 },
    // chi è orgoglioso resta su di giri: la tensione gli toglie il sonno
    { 4, T_ORGOGLIO,  -0.014 },
    // chi è sereno di suo scivola nella sera più facilmente
    { 5, T_CODARDIA,  -0.014 },
    // chi è ambizioso trasforma la spinta in piacere: la corsa gli piace
    { 6, T_AMBIZIONE,  0.018 },
};
constexpr int NTINTE = static_cast<int>(sizeof(TINTE) / sizeof(TINTE[0]));

// ⚠️ IL BUDGET DI RIGA, verificato dal COMPILATORE — e adesso DAVVERO.
//
// Se per ogni riga `Σⱼ|gᵢⱼ| < λᵢ`, per Gershgorin ogni autovalore di
// M = −Λ + G ha parte reale negativa: il sistema non può oscillare né
// divergere, con nessun accoppiamento e nessun passo.
//
// ⚠️ **E PER UN PEZZO IL COMPILATORE NON POTEVA VEDERE NIENTE.** I cinque
// `static_assert` erano scritti con i numeri RICOPIATI A MANO da tre tabelle
// — i `g` di `ARCHI[]`, gli `amp` di `TINTE[]`, e i λ, che in C++ non
// esistono nemmeno (vivono in `Limbico.NEURO_DECADIMENTO` e arrivano a
// runtime). Nessuno dei cinque nominava `ARCHI` o `TINTE`: cambiare un arco
// lasciava gli assert a verificare i numeri VECCHI, in silenzio, e la
// promessa «non un test che qualcuno può dimenticare» diventava una tabella
// gemella — cioè la cosa che questo progetto vieta per iscritto.
//
// Adesso il budget si CALCOLA dalle tabelle, a compile time, e l'assert è
// UNO: aggiungere un canale o un arco non può far dimenticare una riga.
constexpr double val_ass(double x) { return x < 0.0 ? -x : x; }

// la tinta più larga che può toccare l'arco `a` (in valore assoluto): una
// tinta vale `amp·(v−0.5)·2` con v ∈ [0,1], quindi al più `|amp|`.
constexpr double tinta_max(int a) {
    double m = 0.0;
    for (int k = 0; k < NTINTE; ++k) {
        if (TINTE[k].arco != a) continue;
        const double v = val_ass(TINTE[k].amp);
        if (v > m) m = v;
    }
    return m;
}

// il caso peggiore della riga `canale`: ogni arco che ci arriva, al massimo
// del suo modulo più la sua tinta più larga.
constexpr double budget_riga(int canale) {
    double s = 0.0;
    for (int a = 0; a < NARCHI; ++a) {
        if (ARCHI[a].bersaglio != canale) continue;
        s += val_ass(ARCHI[a].g) + tinta_max(a);
    }
    return s;
}

// ⚠️ I λ CONTRO CUI IL CERTIFICATO È CALCOLATO, e NON sono una seconda casa:
// i λ veri vivono in `Limbico.NEURO_DECADIMENTO` e arrivano a runtime, per
// persona. Questi sono quello che il certificato ASSUME — e senza qualcuno
// che leghi le due tabelle resterebbero un desiderio, non una garanzia.
// Il legame è `test_intreccio._i_lambda_del_certificato_sono_quelli_veri`,
// che li legge dal BINARIO (`EcsMondo.intreccio_lambda_certificato`) e li
// confronta con il dizionario di GDScript, nei due versi.
constexpr double LAMBDA_CERTIFICATO[N] = {
    0.05, // dopamina
    0.05, // ossitocina
    0.02, // serotonina
    0.08, // cortisolo
    0.10, // melatonina
    0.04, // adenosina
    0.06, // endorfine
};

constexpr bool certificato_regge() {
    for (int i = 0; i < N; ++i) {
        if (!(budget_riga(i) < LAMBDA_CERTIFICATO[i])) return false;
    }
    return true;
}

// UN assert per tutte le righe: aggiungere un canale o un arco non può
// lasciarne una fuori, che è esattamente il modo in cui cinque assert
// scritti a mano si sarebbero rotti.
static_assert(certificato_regge(),
              "una riga di G somma piu' del suo lambda: Gershgorin non "
              "garantisce piu' che la chimica non oscilli");

static_assert(INTRECCIO_KAPPA_MIN > 0.0 && INTRECCIO_KAPPA_MAX <= 1.0,
              "kappa scala il budget: fuori da (0,1] il certificato cade");

// exp(M·h) con lo scaling-and-squaring: si divide h finché ‖M·h‖ è piccola,
// si fa Taylor, poi si eleva al quadrato. Piccolo e portabile — niente
// librerie, solo +, ×, e un ldexp implicito.
void exp_matrice(const double *M, double h, double *out) {
    double norma = 0.0;
    for (int i = 0; i < N; ++i) {
        double r = 0.0;
        for (int j = 0; j < N; ++j) r += std::fabs(M[i * N + j]);
        if (r > norma) norma = r;
    }
    int s = 0;
    double sc = norma * std::fabs(h);
    while (sc > 0.25 && s < 40) { sc *= 0.5; ++s; }
    const double hs = h / static_cast<double>(1 << s);

    double T[N * N], P[N * N], A[N * N];
    std::memset(out, 0, sizeof(double) * N * N);
    for (int i = 0; i < N; ++i) out[i * N + i] = 1.0;
    for (int i = 0; i < N * N; ++i) { A[i] = M[i] * hs; P[i] = A[i]; }
    for (int i = 0; i < N * N; ++i) out[i] += P[i];
    double fatt = 1.0;
    for (int k = 2; k <= 12; ++k) {
        for (int i = 0; i < N; ++i)
            for (int j = 0; j < N; ++j) {
                double acc = 0.0;
                for (int l = 0; l < N; ++l) acc += P[i * N + l] * A[l * N + j];
                T[i * N + j] = acc;
            }
        std::memcpy(P, T, sizeof(T));
        fatt *= static_cast<double>(k);
        for (int i = 0; i < N * N; ++i) out[i] += P[i] / fatt;
    }
    for (int q = 0; q < s; ++q) {
        for (int i = 0; i < N; ++i)
            for (int j = 0; j < N; ++j) {
                double acc = 0.0;
                for (int l = 0; l < N; ++l) acc += out[i * N + l] * out[l * N + j];
                T[i * N + j] = acc;
            }
        std::memcpy(out, T, sizeof(T));
    }
}

} // namespace

// ⚠️ I λ CHE IL CERTIFICATO ASSUME, esposti perche' qualcuno possa LEGARLI
// a quelli veri. I λ del gioco vivono in `Limbico.NEURO_DECADIMENTO` e
// arrivano qui a runtime, per persona: la tabella di sopra e' quello che lo
// `static_assert` da' per buono, e senza un lettore che confronti le due
// resterebbe un desiderio. Il lettore e'
// `test_intreccio._i_lambda_del_certificato_sono_quelli_veri`.
const double *lambda_certificato() { return LAMBDA_CERTIFICATO; }

double budget_certificato(int p_canale) {
    if (p_canale < 0 || p_canale >= N) return 0.0;
    return budget_riga(p_canale);
}

bool costruisci_intreccio(const double *lambda, const double *tratti,
                          Intreccio *out) {
    if (lambda == nullptr || out == nullptr) return false;
    std::memset(out->G, 0, sizeof(out->G));
    for (int i = 0; i < N; ++i) {
        if (!std::isfinite(lambda[i]) || lambda[i] <= 0.0) return false;
        out->lambda[i] = lambda[i];
    }
    for (int a = 0; a < NARCHI; ++a)
        out->G[ARCHI[a].bersaglio * N + ARCHI[a].sorgente] = ARCHI[a].g;
    if (tratti != nullptr) {
        for (int t = 0; t < NTINTE; ++t) {
            const Arco &ar = ARCHI[TINTE[t].arco];
            const double v = tratti[TINTE[t].tratto];
            if (!std::isfinite(v)) continue;
            // scarto dal carattere neutro: a 0.5 somma ZERO esatto
            out->G[ar.bersaglio * N + ar.sorgente] += TINTE[t].amp * (v - 0.5) * 2.0;
        }
    }
    // il budget di riga, verificato sui numeri VERI di questa persona e non
    // solo sulle costanti: una tinta storta non deve poter uscire dal file
    for (int i = 0; i < N; ++i) {
        double r = 0.0;
        for (int j = 0; j < N; ++j) if (i != j) r += std::fabs(out->G[i * N + j]);
        if (!(r < out->lambda[i])) return false;
    }
    out->pronto = true;
    return true;
}

bool matrice_di_transizione(const Intreccio &it, double h, double kappa,
                            double *E, double *Q) {
    if (!it.pronto || !std::isfinite(h) || h <= 0.0) return false;
    if (!std::isfinite(kappa)) return false;
    const double k = kappa < INTRECCIO_KAPPA_MIN ? INTRECCIO_KAPPA_MIN
                   : (kappa > INTRECCIO_KAPPA_MAX ? INTRECCIO_KAPPA_MAX : kappa);
    double M[N * N];
    for (int i = 0; i < N; ++i)
        for (int j = 0; j < N; ++j)
            M[i * N + j] = (i == j) ? -it.lambda[i] : k * it.G[i * N + j];
    exp_matrice(M, h, E);
    for (int i = 0; i < N * N; ++i) if (!std::isfinite(E[i])) return false;
    if (Q != nullptr) {
        // ⚠️ Q DIAGONALE, E NON È UNA SEMPLIFICAZIONE: è la porta da cui si
        // barerebbe su Φ. La stochastic interaction conta anche la
        // correlazione istantanea del rumore, quindi un Q pieno alzerebbe Φ
        // senza integrare niente. Tenendolo diagonale, Φ misura SOLO
        // l'accoppiamento dinamico — che è la cosa di cui si parla.
        std::memset(Q, 0, sizeof(double) * N * N);
        for (int i = 0; i < N; ++i) Q[i * N + i] = 1.0;
    }
    return true;
}

bool passo_intreccio(const Intreccio &it, double h, double kappa,
                     const double *bersaglio, double *neuro) {
    if (!it.pronto || bersaglio == nullptr || neuro == nullptr) return false;
    if (!std::isfinite(h) || h <= 0.0) return false;
    for (int i = 0; i < N; ++i)
        if (!std::isfinite(bersaglio[i]) || !std::isfinite(neuro[i])) return false;

    double E[N * N];
    if (!matrice_di_transizione(it, h, kappa, E, nullptr)) return false;

    // ⚠️ N ← t + E·(N − t). Il bersaglio sta FUORI dalla matrice: il punto
    // fisso resta `t` per QUALUNQUE E, quindi ogni equilibrio già tarato del
    // gioco è conservato al bit, e quello che cambia è solo COME ci si
    // arriva. È la riga che permette a questo lavoro di non essere una
    // ritaratura di mezzo gioco travestita da rifattoring.
    double d[N], fuori[N];
    for (int i = 0; i < N; ++i) d[i] = neuro[i] - bersaglio[i];
    for (int i = 0; i < N; ++i) {
        double acc = 0.0;
        for (int j = 0; j < N; ++j) acc += E[i * N + j] * d[j];
        fuori[i] = bersaglio[i] + acc;
        if (!std::isfinite(fuori[i])) return false;
    }
    for (int i = 0; i < N; ++i)
        neuro[i] = fuori[i] < 0.0 ? 0.0 : (fuori[i] > 1.0 ? 1.0 : fuori[i]);
    return true;
}

} // namespace chibi
