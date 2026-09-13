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

// ===========================================================================
//  IL CARICO — il secondo stato stabile, e il teorema che lo rendeva
//  impossibile
// ===========================================================================
//
//  Fino a oggi questo sostrato **non poteva** avere due stati stabili, e non
//  per taratura: i sette archi di `G` formano un **DAG** (verificato: ordine
//  topologico adenosina→dopamina→endorfine→cortisolo→serotonina→melatonina,
//  più ossitocina→cortisolo, zero cicli), quindi gli autovalori di
//  `M = −Λ + κG` sono esattamente i `−λᵢ` e l'ascissa spettrale vale
//  **−0.02000000** per ogni carattere e ogni κ. E il budget di riga
//  (Gershgorin) rende la mappa una **contrazione** — che ha **UN** punto
//  fisso, per teorema.
//
//  Un sistema così non può crollare, non può restare giù, e non può
//  oscillare. Qualunque «stato» ci si volesse mettere sopra sarebbe stato un
//  transitorio con un nome.
//
// ---------------------------------------------------------------------------
//  IL MECCANISMO, che è vero e non inventato per l'occasione
// ---------------------------------------------------------------------------
//
//  Sotto stress prolungato il **recettore dei glucocorticoidi si
//  desensibilizza**: il cortisolo alto danneggia proprio la retroazione
//  negativa che dovrebbe spegnerlo. È un autofeedback POSITIVO che SATURA —
//  trascurabile in basso, dominante oltre una soglia — ed è esattamente la
//  forma che serve per due stati stabili.
//
//      ċ = −λ(c − t)  +  H(c)
//      H(c) = 0                                    per c ≤ SOGLIA
//      H(c) = α·d²/(σ² + d²),   d = c − SOGLIA     per c > SOGLIA
//
//  ⚠️ **LA ZONA MORTA È LA RIGA CHE SALVA TUTTO IL RESTO.** Sotto `SOGLIA`
//  il termine è **zero esatto**, quindi il punto di riposo resta `t` al bit e
//  ogni taratura già misurata di questo gioco è intatta. Senza la zona morta
//  (misurato: la stessa funzione senza) lo stato basso si sposta da 0.080 a
//  **0.145**, cioè si sarebbe ritarato mezzo gioco in silenzio dentro un
//  commit che si presenta come «uno stato nuovo».
//
// ---------------------------------------------------------------------------
//  I TRE PUNTI FISSI, CALCOLATI (λ = 0.08, t = 0.08, α = 0.060, θ = 0.55,
//  σ = 0.06)
// ---------------------------------------------------------------------------
//
//    stato basso   0.0800   ← il punto di riposo di SEMPRE
//    CRINALE       0.5704   ← instabile
//    stato alto    0.9195   ← stabile: **ci si resta**
//
//  ⚠️ **E QUESTI SONO MISURATI, non calcolati su carta.** La prima stesura
//  aveva 0.587 / 0.801 da un conto in Python fatto con θ = 0.50 mentre
//  l'header diceva 0.55: il banco ha trovato 0.661 / 0.784 — un crinale più
//  alto e uno stacco di soli 0.12, cioè un secondo bacino troppo debole per
//  essere una cosa. Il numero lo dà `tools/prova_carico.cpp`, non io.
//
//  ⚠️ **E IL CRINALE STA SOPRA LA VITA NORMALE, ed è il numero che decide se
//  questo lavoro si può consegnare.** MISURATO altrove in questo progetto: un
//  vicino «in ansia» arriva a **0.42**. Il crinale è a 0.587. Quindi non ci
//  si cade vivendo: ci si arriva solo se qualcosa spinge, e continua a
//  spingere. Se un giorno una taratura altrove alzasse il cortisolo della
//  vita normale sopra 0.5, questo meccanismo diventerebbe **il villaggio come
//  ospedale** — ed è il primo numero da riguardare.
//
//  **L'ISTERESI**: per entrare bisogna essere spinti sopra 0.587; per uscire
//  bisogna essere riportati sotto 0.587 — ma da 0.801 il sistema tira in SU.
//  La strada del ritorno non è quella dell'andata, e serve che qualcuno
//  faccia qualcosa. *È il punto.*
//
//  **IL CERTIFICATO**, e sostituisce quello di contrazione che qui cade:
//   1. `H ≥ 0` e `H ≤ α` (satura): il campo è limitato;
//   2. `f(1) = −λ(1−t) + H(1) < 0` ⟺ `α < λ(1−t) = 0.0736` (e `α = 0.068`:
//      il margine è **stretto apposta**, perché è lo stacco fra i due bacini
//      a costare — chi lo alza deve rifare il `static_assert` e la misura) — e
//      `static_assert` lo impone. Quindi da 1 si torna sempre giù: **lo stato
//      non può uscire da [0,1]**, senza bisogno del clamp;
//   3. sotto `SOGLIA` il sistema è quello di prima, contrazione compresa.
//  Non è più «un punto fisso»: sono **due bacini**, e la dimostrazione è
//  trovare le radici — che `tools/prova_carico.cpp` fa, invece di crederci.

/// Il crinale: sotto, il termine è zero esatto e il gioco è quello di ieri.
static constexpr double CARICO_SOGLIA = 0.50;
/// Quanto forte può diventare l'autofeedback. ⚠️ Sotto λ(1−t) o lo stato
/// scappa da [0,1]: lo impone un `static_assert`.
static constexpr double CARICO_ALPHA = 0.068;
/// Quanto in fretta satura oltre il crinale.
static constexpr double CARICO_SIGMA = 0.06;

/// Il termine di carico su un livello. Zero sotto il crinale, sempre.
double carico(double c);

/// I tre punti fissi, per chi vuole verificare invece di credere. Torna
/// quanti ne ha trovati (3 = bistabile, 1 = un bacino solo).
int punti_fissi_carico(double lambda, double riposo, double *out3);

struct Intreccio {
    double G[INTRECCIO_N * INTRECCIO_N] = {0};   // accoppiamento, diag. nulla
    double lambda[INTRECCIO_N] = {0};            // i decadimenti di Limbico
    /// ⚠️ **SPENTO DI SERIE.** Chi non l'accende ha il gioco di ieri, bit per
    /// bit — e non per una zona morta, ma perché il ramo non gira affatto.
    bool carico_acceso = false;
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
