#ifndef CHIBI_PHI_INTEGRATO_H
#define CHIBI_PHI_INTEGRATO_H

// ===========================================================================
//  Φ — L'INFORMAZIONE INTEGRATA, CALCOLATA E NON EVOCATA
// ===========================================================================
//
//  «Un sistema è cosciente se le sue parti sono collegate in modo così
//   stretto che non puoi dividerlo senza distruggerlo.»
//
//  Questo file dà a quella frase un NUMERO. Non una metafora: una quantità
//  che si misura sul sostrato vero, che vale **zero esatto** quando il
//  sistema è modulare, e che si può far crollare tagliando le connessioni —
//  cioè che si può FALSIFICARE.
//
//  ⚠️ E un Φ sbagliato è PEGGIO di nessun Φ: sembra una misura. Per questo
//  ogni formula qui sotto è scritta per esteso con la sua derivazione, e
//  `tools/prova_phi.cpp` la verifica contro casi di cui la risposta si sa
//  in anticipo (un sistema staccato deve dare 0.0 al bit).
//
// ---------------------------------------------------------------------------
//  IL FORMALISMO: la STOCHASTIC INTERACTION gaussiana
//  (Ay 2001; Barrett & Seth 2011, «Practical Measures of Integrated
//   Information», PLoS Comput Biol 7(1): e1001052)
// ---------------------------------------------------------------------------
//
//  Il sostrato è un processo autoregressivo a tempo discreto
//
//      x(t+1) = A·x(t) + ε(t),      ε ~ N(0, Q)
//
//  La covarianza stazionaria Σ risolve l'equazione di Lyapunov discreta
//
//      Σ = A·Σ·Aᵀ + Q
//
//  Per una partizione in parti M₁…M_k, l'informazione integrata è
//
//      Φ_p = Σᵢ H(Mᵢ(t+1) | Mᵢ(t))  −  H(X(t+1) | X(t))
//
//  cioè: **quanta incertezza in più ha una parte quando non può guardare le
//  altre.** Per un gaussiano l'entropia condizionale è ½·ln((2πe)ⁿ·det C), e
//  i termini (2πe)ⁿ si cancellano perché Σᵢnᵢ = n. Resta
//
//      Φ_p = ½·[ Σᵢ ln det(C_cond,ᵢ)  −  ln det(Q) ]
//
//  dove:
//   · **H(X(t+1)|X(t))** usa esattamente Q — conoscendo TUTTO il passato,
//     l'unica incertezza che resta è il rumore;
//   · **C_cond,ᵢ** è la covarianza di Mᵢ(t+1) noto SOLO Mᵢ(t). La parte i
//     riceve anche A_ij·M_j(t), e M_j(t) è incerto:
//
//         C_cond,ᵢ = A_ij · Σ_{j|i} · A_ijᵀ  +  Q_ii
//         Σ_{j|i}  = Σ_jj − Σ_ji·Σ_ii⁻¹·Σ_ij        (condizionale gaussiana)
//
//  ⚠️ **LA PROVA CHE LA FORMULA È GIUSTA È IL SUO ZERO.** Con A_ij = 0 si ha
//  C_cond,ᵢ = Q_ii; se anche Q è a blocchi, det(Q) = Πᵢ det(Q_ii) e la
//  parentesi è ln(Π) − ln(Π) = 0. **Un sistema staccato ha Φ = 0 al bit, per
//  costruzione e non per tolleranza.** È il primo caso di `prova_phi`.
//
// ---------------------------------------------------------------------------
//  LA PARTIZIONE MINIMA (MIP), e perché serve normalizzare
// ---------------------------------------------------------------------------
//
//  Φ del sistema è Φ_p sulla partizione che lo **taglia meglio**: il punto
//  debole. Senza normalizzare, il minimo cade SEMPRE sulla bipartizione più
//  sbilanciata (una parte da un'unità sola ha poco da perdere), e il numero
//  smette di parlare del sistema. Si usa la normalizzazione di Tononi
//
//      K(p) = (k−1) · minᵢ H_max(Mᵢ)          [qui: minᵢ nᵢ, unità omogenee]
//
//  e si sceglie la MIP su Φ_p/K(p), riportando poi Φ_MIP **non
//  normalizzato** — che è la pratica di IIT: la normalizzazione serve a
//  SCEGLIERE il taglio, non a misurare.
//
//  Il costo è 2^(N−1)−1 bipartizioni. Per N=7 sono **63**: Φ esatto è
//  gratis. Per N=12 sono 2047, ancora fattibile fuori dal frame. Oltre, no —
//  e questo è il vincolo che decide quanto può essere grande un nucleo.
//
// ---------------------------------------------------------------------------
//  ⚠️ COSA QUESTO NUMERO NON È
// ---------------------------------------------------------------------------
//
//  Non è «coscienza». È la quantità che la teoria di Tononi propone come sua
//  misura, calcolata su un'approssimazione lineare-gaussiana di un sostrato
//  che lineare non è. Serve a una cosa sola, e quella la fa bene: **dire se
//  le parti si possono staccare senza perdere niente.** Chi la citerà come
//  altro, la citerà male.

#include <cstddef>

namespace chibi {

// Il nucleo è piccolo apposta: Φ esatto costa 2^(N-1) bipartizioni, e la
// misura deve restare ESATTA — un Φ campionato non è falsificabile.
static constexpr int PHI_MAX_N = 12;

struct RisultatoPhi {
    double phi = 0.0;          // Φ alla partizione minima, NON normalizzato
    double phi_norm = 0.0;     // il valore normalizzato con cui è stata scelta
    unsigned mip = 0u;         // la maschera di bit della parte "sinistra"
    int n = 0;
    bool valido = false;       // falso se A non è stabile o i conti degenerano
};

// Risolve Σ = A·Σ·Aᵀ + Q col metodo del raddoppio (Smith): converge in
// ~log₂ iterazioni invece che in centinaia, e non serve fattorizzare niente.
// Torna false se A non è stabile (raggio spettrale ≥ 1): lì la covarianza
// stazionaria NON ESISTE, e inventarne una sarebbe la bugia peggiore.
bool lyapunov_discreta(const double *A, const double *Q, int n, double *sigma);

// Φ esatto sulla minima bipartizione. `A` e `Q` sono n×n per righe.
RisultatoPhi phi_integrato(const double *A, const double *Q, int n);

// ⚠️ **RISCALA A AL RAGGIO SPETTRALE CHIESTO, e non è una comodità: una
// matrice densa presa a caso è INSTABILE per costruzione.** Con N unità e
// pesi dell'ordine di w, il raggio cresce come ~w·√N: a N=7 e w=0.2 si è già
// oltre 1, la covarianza stazionaria **non esiste**, e ogni Φ calcolato lì
// sopra è spazzatura. Il sostrato deve passare di qui prima di girare, e il
// banco pure — sei dei primi otto rossi di `prova_phi` erano esattamente
// questo, cioè una fixture che si era costruita un sistema che diverge.
//
// Il raggio si stima con l'iterazione delle potenze; `rho` è il bersaglio
// (0.85–0.95: sotto, il sostrato dimentica in un attimo; sopra, risuona).
// Torna il raggio MISURATO prima della scala, che è un numero da guardare.
double scala_a_raggio_spettrale(double *A, int n, double rho);

// Vero se Q è diagonale entro `tol`.
//
// ⚠️ **PERCHÉ IL SOSTRATO LO PRETENDE.** La *stochastic interaction* conta
// come integrazione anche la correlazione ISTANTANEA del rumore: con A
// diagonale — cioè parti che non si parlano affatto — e Q pieno, Φ esce
// **positivo** (misurato: 0.553 con n=6 e correlazione 0.6). Non è un difetto
// della formula: è quello che quella quantità misura, la dipendenza TOTALE,
// dinamica più istantanea. Ma per noi sarebbe la porta da cui si bara — si
// alzerebbe Φ senza integrare niente, mettendo una causa comune fuori dal
// sistema — quindi il sostrato tiene Q **diagonale** e Φ finisce per misurare
// SOLO l'accoppiamento dinamico A. La porta si chiude con una proprietà
// strutturale, non con una taratura.
bool q_diagonale(const double *Q, int n, double tol = 1e-12);

// Il log-determinante via Cholesky (le matrici qui sono covarianze, cioè
// simmetriche definite positive). Torna false se non lo è — che è un
// sintomo, non un caso da aggirare.
bool log_det_spd(const double *M, int n, double *out);

} // namespace chibi

#endif
