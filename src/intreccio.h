#ifndef CHIBI_INTRECCIO_H
#define CHIBI_INTRECCIO_H

// ===========================================================================
//  L'INTRECCIO — i sette canali smettono di essere sette macchine
// ===========================================================================
//
//  «Un computer elabora tantissimi dati, ma ogni chip fa il suo lavoro in
//   modo separato. Nel cervello ogni sensazione si fonde all'istante in una
//   sola esperienza indivisibile.»
//
//  Fino a oggi la chimica di un vicino era **letteralmente** la prima metà di
//  quella frase. `Limbico.passo_neuro` è questo:
//
//      for tipo in NEURO_TRASMETTITORI:
//          n = eq + (n - eq) * exp(-lam * dt)
//
//  cioè sette equazioni differenziali che non si guardano. La matrice di
//  transizione è `A = diag(exp(−λᵢ·Δ))`: **esattamente diagonale**, quindi
//  **Φ = 0 per teorema**, non per approssimazione. Sette scalari scollegati
//  che per caso li legge lo stesso corpo.
//
//  Qui la matrice diventa densa: il cortisolo morde la serotonina,
//  l'ossitocina spegne il cortisolo, l'adenosina trascina la dopamina. Una
//  gentilezza smette di essere «+0.12 di ossitocina» e diventa una cosa che
//  attraversa tutto lo stato — e quello che ne esce dipende da **dov'era
//  quella mente**, non da una tabella.
//
// ---------------------------------------------------------------------------
//  LA FORMA, e le tre righe che la rendono sicura
// ---------------------------------------------------------------------------
//
//      N(t+H) = t + E·(N(t) − t)            E = exp(M·H),  M = −Λ + G
//
//  con Λ = diag(λᵢ) i decadimenti che esistono già, G la matrice di
//  accoppiamento (**diagonale nulla**), e
//
//      t = B + Λ⁻¹·Π       (il punto di riposo di oggi, canale per canale)
//
//  ⚠️ **1. IL BERSAGLIO STA FUORI DALLA MATRICE, ed è la riga più importante
//  del file.** La forma che si scrive per prima — accoppiare anche la
//  produzione, `Ṅ = M·N + Π` — ha punto fisso `−M⁻¹Π`, che **NON è** il
//  punto di riposo di prima: sposterebbe ogni equilibrio del gioco in
//  silenzio, dentro un commit che si presenta come «integrazione». MISURATO
//  su tre giornate simulate: cortisolo medio da 0.1275 a 0.0334 — sotto la
//  sua stessa baseline — e la porta della tunnel-vision (`cortisolo > 0.45`)
//  da 0.56% del tempo a **0.00%**. Sarebbe stata una ritaratura di mezzo
//  gioco travestita da rifattoring.
//  Con la forma qui sopra il punto fisso è `t` **per QUALUNQUE E**, perché
//  `N = t + E(N−t)` ⟺ `(I−E)(N−t) = 0` ⟺ `N = t` quando `I−E` è
//  invertibile. Non è una taratura: è algebra, e il banco la verifica a
//  3·10⁻¹⁶.
//
//  ⚠️ **2. IL BUDGET DI RIGA È UN TEOREMA AL POSTO DI UNA TARATURA.** Se per
//  ogni riga `Σⱼ|gᵢⱼ| < λᵢ`, allora per Gershgorin ogni autovalore di M ha
//  parte reale negativa, quindi `‖E‖ < 1` e il sistema **non può** oscillare
//  né divergere, con nessun accoppiamento e nessun passo. Lo controlla un
//  `static_assert` su costanti, non un test che qualcuno può dimenticare.
//
//  ⚠️ **3. E LA MODULAZIONE NON PUÒ ROMPERLO.** Il cortisolo stringe
//  l'accoppiamento (`G ← κ·G`, κ ∈ [0,1]): siccome il budget scala con κ,
//  una riga che rispettava il vincolo lo rispetta ancora. Una combinazione
//  convessa di contrazioni è una contrazione.
//
// ---------------------------------------------------------------------------
//  ⚠️ PERCHÉ Φ QUI MISURA UNA MENTE, E NON UNA TABELLA
// ---------------------------------------------------------------------------
//
//  Un Φ calcolato su una matrice di costanti è un test unitario: vale lo
//  stesso per tutti, per sempre. Qui G è **personale** (la tinge il
//  carattere, come `Limbico.tinta_carattere` tinge il punto di riposo) e
//  **dipende dallo stato** (κ dal cortisolo di adesso). Quindi Φ:
//   · è diverso fra due vicini, per la stessa ragione per cui sono diversi;
//   · **cambia dentro una partita**, perché cambia quanto quella mente è
//     tesa. Un vicino sotto stress ha un'informazione integrata diversa da
//     sé stesso di dieci minuti prima.
//  È quello che rende il numero una misura invece che un ornamento — e la
//  differenza si vede in `tools/prova_intreccio.cpp`.
//
// ---------------------------------------------------------------------------
//  IL LETTORE CHE LO PUÒ VEDERE, e non è quello ovvio
// ---------------------------------------------------------------------------
//
//  Il punto fisso è invariante **apposta**, quindi ogni consumatore che legge
//  il livello a regime vede esattamente il gioco di ieri — ed è la garanzia,
//  non un limite. Ma allora chi vede l'intreccio?
//
//  Chi legge il **transitorio**, cioè la deviazione sopra il proprio riposo.
//  Nel gioco ce n'è uno solo, ed esiste già tarato: `Limbico.trattieni()` —
//  la forza di mordersi la lingua — che scala su `max(0, livello − riposo)`.
//  È la stessa grandezza che l'intreccio produce e che l'invarianza lascia
//  intatta.
//
//  ⚠️ E non è `Animo.decide()`, che sarebbe la scelta ovvia e sarebbe
//  MATEMATICAMENTE MUTA: gira solo sul confine del giorno, e
//  `Limbico.consolida_sonno` inchioda il cortisolo al punto fisso un istante
//  prima (un `move_toward` di ≥ 0.40 contro una deviazione massima di
//  0.038). Il segnale sarebbe dieci volte più piccolo della gomma che lo
//  cancella. È il gemello del difetto che questo progetto ha già pagato con
//  `opinione`: un termine che viene letto, in un punto in cui non può
//  differire.

#include <cstdint>

namespace chibi {

static constexpr int INTRECCIO_N = 7;

// L'ordine è quello di `Limbico.NEURO_TRASMETTITORI`, e non si ricopia a
// mano: il ponte lo passa, e un test lega i due elenchi.
enum Canale {
    C_DOPAMINA = 0, C_OSSITOCINA, C_SEROTONINA, C_CORTISOLO,
    C_MELATONINA, C_ADENOSINA, C_ENDORFINE,
};

// Quanto il cortisolo può stringere l'accoppiamento. 0 = l'intreccio si
// spegne sotto stress, 1 = non cambia. Sopra 1 il budget di riga si
// sfonderebbe e il certificato cadrebbe: il `static_assert` lo vieta.
static constexpr double INTRECCIO_KAPPA_MIN = 0.55;
static constexpr double INTRECCIO_KAPPA_MAX = 1.00;

struct Intreccio {
    double G[INTRECCIO_N * INTRECCIO_N] = {0};   // accoppiamento, diag. nulla
    double lambda[INTRECCIO_N] = {0};            // i decadimenti di Limbico
    bool pronto = false;
};

// Costruisce l'intreccio di UNA persona: la tabella di base tinta dal
// carattere. `tratti` sono i cinque in [0,1] nell'ordine di `ChibiDNA`.
// Pura: nessun dado, nessuno stato. Torna false se il budget di riga non
// regge (e allora il chiamante NON deve usarlo: il degrado è la diagonale).
bool costruisci_intreccio(const double *lambda, const double *tratti,
                          Intreccio *out);

// Un passo. `neuro` e `bersaglio` sono INTRECCIO_N; `neuro` viene riscritto.
// `kappa` è la stretta da stress. Torna false se qualcosa non è finito — e
// allora `neuro` non viene toccato affatto (mai un numero inventato).
bool passo_intreccio(const Intreccio &it, double h, double kappa,
                     const double *bersaglio, double *neuro);

// La matrice di transizione E = exp(M·H) e il rumore Q, per darli a
// `phi_integrato`. `Q` esce DIAGONALE per costruzione: è la porta da cui si
// barerebbe su Φ, e si chiude qui (vedi `phi_integrato.h`).
bool matrice_di_transizione(const Intreccio &it, double h, double kappa,
                            double *E, double *Q);

} // namespace chibi

#endif
