#ifndef CHIBI_NEURONI_H
#define CHIBI_NEURONI_H

// ===========================================================================
//  I NEURONI — una rete che SPARA, e sinapsi che IMPARANO
// ===========================================================================
//
//  Fino a oggi un vicino «giudicava» il mondo con delle tabelle: luce →
//  serotonina, pioggia → cortisolo. Scritte da me, uguali per tutti, e
//  incapaci di imparare qualunque cosa. Il colore non arrivava a nessuno.
//
//  Qui c'è una rete di neuroni **integra-e-spara con perdita** (LIF), con
//  sinapsi **plastiche** (STDP a tre fattori), modulata dai sette canali
//  chimici dell'intreccio. Non decide niente e non muove nessun corpo: fa una
//  cosa sola, e il gioco non la sapeva fare affatto —
//
//      **si RICORDA che cosa va insieme a che cosa, per quella persona.**
//
//  Un vicino a cui è successo qualcosa di brutto sotto un cielo grigio, in
//  quel posto, con quel colore addosso, sviluppa sinapsi che legano quelle
//  cose fra loro. La volta dopo, quel grigio non è più neutro **per lui** —
//  e non perché io abbia scritto «grigio = tristezza», ma perché le sue
//  sinapsi si sono rinforzate mentre gli succedeva.
//
//  ⚠️ **È LA RAGIONE PER CUI QUESTA COSA NON È UNA TABELLA.** Due vicini con
//  la stessa identica architettura, vissuti in modo diverso, hanno **pesi
//  sinaptici fisicamente diversi**, e giudicano lo stesso cielo in modo
//  diverso per STORIA e non per un dado né per un tratto.
//
// ---------------------------------------------------------------------------
//  IL NEURONE (leaky integrate-and-fire)
// ---------------------------------------------------------------------------
//
//      τ_m · dV/dt = −(V − V_riposo) + R·I(t)
//      se V ≥ V_soglia  →  spara, V ← V_reset, refrattario per t_ref
//
//  Integrato in forma **esatta** (non Eulero): con `a = exp(−Δ/τ_m)`,
//  `V ← V∞ + (V − V∞)·a`. È la stessa disciplina della chimica, per la stessa
//  ragione già pagata in questo progetto: un Eulero fa dipendere lo stato dal
//  frame rate, e il frame rate qui va da 25 a 60.
//
// ---------------------------------------------------------------------------
//  LA SINAPSI, e la plasticità a TRE fattori
// ---------------------------------------------------------------------------
//
//  STDP classica: se il pre spara **prima** del post, la sinapsi si rinforza
//  (ha contribuito); se spara **dopo**, si indebolisce. Si implementa con due
//  tracce esponenziali per neurone invece che con una coda di istanti —
//  costo O(sinapsi attive) invece di O(coppie di spike).
//
//      pre spara  →  x_pre ← x_pre + 1                (traccia pre)
//      post spara →  y_post ← y_post + 1              (traccia post)
//      al pre:   Δw = −A₋ · y_post       (depressione)
//      al post:  Δw = +A₊ · x_pre        (potenziamento)
//
//  ⚠️ **IL TERZO FATTORE, e non è un ornamento: è quello che distingue
//  «imparare» da «rumore che si accumula».** Nel cervello la STDP da sola non
//  consolida niente: serve un segnale neuromodulatorio — la dopamina — che
//  dica *questo valeva la pena ricordarlo*. Senza, una rete plastica impara
//  ogni coincidenza che le capita e in mezz'ora è satura di spazzatura.
//  Qui il terzo fattore è la **dopamina dell'intreccio**, che è già quella
//  vera: sale coi gesti gentili, col sogno servito, con quello che al vicino
//  interessa. Quindi **si impara quello che è successo mentre importava** —
//  che è anche esattamente ciò che questo gioco dice dei ricordi.
//
//  ⚠️ E LA RETE NON PUÒ ESPLODERE, per tre ragioni strutturali:
//   1. i pesi sono **limitati** (`W_MAX`), e la STDP satura contro il bordo;
//   2. c'è lo **scaling omeostatico**: se un neurone spara troppo, tutti i
//      suoi ingressi si riducono in proporzione. È il meccanismo vero
//      (Turrigiano), e senza una rete plastica va sempre a finire in uno dei
//      due muri — silenzio totale o crisi epilettica;
//   3. l'inibizione è una **frazione fissa** della popolazione (80/20, come
//      in corteccia), e i pesi inibitori non cambiano segno mai.
//
// ---------------------------------------------------------------------------
//  I SETTE CANALI COME NEUROMODULATORI (ed è la loro funzione VERA)
// ---------------------------------------------------------------------------
//
//   dopamina    → il terzo fattore della plasticità: *quanto si impara adesso*
//   serotonina  → la soglia di sparo (più alta = più difficile eccitarsi)
//   cortisolo   → guadagno e rumore: sotto stress la rete è più reattiva e
//                 più disordinata — ed è la stessa direzione con cui
//                 l'intreccio misura Φ che cala
//   adenosina   → inibizione globale (è letteralmente il meccanismo del
//                 sonno, e il motivo per cui la caffeina funziona)
//   melatonina  → spegne la corrente afferente: di notte il mondo non entra
//   ossitocina  → guadagno sulle afferenze SOCIALI soltanto
//   endorfine   → alza la soglia del dolore: smorza l'afferenza negativa
//
//  Non è decorazione: sono le funzioni che quelle molecole hanno davvero, e
//  ognuna entra in un posto diverso dell'equazione — non tutte come «un
//  moltiplicatore in più».

#include <cstdint>

namespace chibi {

// ⚠️ **LA TAGLIA È IL VINCOLO DEL SALVATAGGIO, non della CPU.** I pesi sono
// ciò che quella persona ha imparato: devono sopravvivere al caricamento, o
// ogni vicino dimentica la propria vita a ogni avvio. A int8 sono N² byte per
// persona: con N=32 fanno 1 KiB a testa, 28 KiB per un villaggio pieno —
// accettabile accanto agli 85 KiB del `village.json` di oggi. A N=64
// sarebbero 114 KiB, cioè il salvataggio raddoppiato per una rete che
// nessuno guarda più da vicino.
static constexpr int NEU_N = 32;
static constexpr int NEU_ECC = 26;            // eccitatori (81%, come in corteccia)
static constexpr int NEU_IN = 12;             // i primi 12 ricevono il mondo

// I canali del codice sensoriale. ⚠️ NON sono «emozioni»: sono proprietà
// FISICHE della scena. La valenza non entra qui — se entrasse, la rete
// imparerebbe la mia tabella invece della propria storia.
enum Afferenza {
    A_LUCE = 0,      // quanto è chiaro
    A_COL_L,         // il colore di ciò che si guarda: Oklab L (chiarezza)
    A_COL_A,         //   …a (verde↔rosso)
    A_COL_B,         //   …b (blu↔giallo)
    A_PIOGGIA,
    A_FREDDO,
    A_CASA,          // sono nel posto mio
    A_APERTO,        // sono allo scoperto
    A_SOCIALE,       // c'è qualcuno vicino
    A_GIOCATORE,     // c'è MOCHI vicino
    A_MOTO,          // mi sto muovendo
    A_ORA,           // dove sta la mia giornata
    A_NUM,
};
static_assert(A_NUM == NEU_IN, "un'afferenza per neurone d'ingresso");

struct StatoNeurale {
    double v[NEU_N] = {0};        // potenziale di membrana
    double x[NEU_N] = {0};        // traccia pre-sinaptica (STDP)
    double y[NEU_N] = {0};        // traccia post-sinaptica (STDP)
    double i_syn[NEU_N] = {0};    // corrente sinaptica in decadimento
    double ref[NEU_N] = {0};      // quanto manca alla fine del refrattario
    double media[NEU_N] = {0};    // frequenza media (per l'omeostasi)
    uint32_t spike = 0u;          // chi ha sparato nell'ultimo passo (bitmask)
    bool pronto = false;
};

// I neuromodulatori, nell'ordine dei canali dell'intreccio.
struct Modulatori {
    double dopamina = 0.4, ossitocina = 0.4, serotonina = 0.5, cortisolo = 0.08;
    double melatonina = 0.0, adenosina = 0.0, endorfine = 0.15;
    // ⚠️ **IL RIPOSO DI QUESTA PERSONA, e non una costante.** Il terzo fattore
    // della plasticita' e' la deviazione della dopamina SOPRA IL PROPRIO
    // riposo, non sopra una soglia fissa. Con una soglia fissa un vicino
    // ambizioso — che ha il punto di riposo piu' alto (`tinta_carattere`) —
    // imparerebbe di continuo anche quando non gli sta succedendo niente, e
    // uno svogliato non imparerebbe mai: il carattere diventerebbe una
    // porta invece di un colore.
    //
    // E' la stessa disciplina di `Limbico.trattieni()`, che scala su
    // `max(0, livello − riposo)`: **si impara quando SUCCEDE qualcosa**, e
    // «qualcosa» vuol dire uno scarto da come si sta di solito.
    double dopamina_riposo = 0.4;
};

// Quello che la rete RESTITUISCE al mondo. Non è una decisione: è una
// disposizione — «questo mi ricorda qualcosa, e mi mette così».
struct EcoNeurale {
    double familiarita = 0.0;   // 0..1: quanto la scena di adesso è già stata
    double eco = 0.0;           // −1..1: come stava quando lo era
    double attivita = 0.0;      // 0..1: quanto la rete è viva adesso
    bool valido = false;
};

// I pesi di una persona: quello che ha imparato. Vivono qui in double e si
// salvano quantizzati a int8 (vedi `pesi_in_byte`).
struct Sinapsi {
    double w[NEU_N * NEU_N] = {0};
    bool pronto = false;
};

// Costruisce la rete iniziale di UNA persona dal suo seme (pura e
// deterministica: il C++ non ha dadi, riceve un numero già salvato).
// ⚠️ splitmix64 + interi: bit-identica su macOS, Windows e Linux. Le
// distribuzioni della libreria standard NON lo sono.
void genera_sinapsi(uint64_t seme, Sinapsi *out);

// Un passo della rete. `aff` sono A_NUM valori in [0,1]. `dt` in secondi.
// Torna false e NON tocca niente se qualcosa non è finito.
bool passo_neurale(const Sinapsi &syn, const Modulatori &mod, const double *aff,
                   double dt, StatoNeurale *st, Sinapsi *plastico);

// Cosa dice la rete, adesso.
EcoNeurale leggi_eco(const StatoNeurale &st, const double *aff);

// La matrice di transizione efficace, per dare Φ a `phi_integrato`: la
// linearizzazione attorno al punto di lavoro. ⚠️ Q esce diagonale, che è la
// porta da cui si barerebbe su Φ (vedi `phi_integrato.h`).
bool transizione_neurale(const Sinapsi &syn, const Modulatori &mod, double dt,
                         int n_ridotto, double *E, double *Q);

// I pesi in byte, e viceversa: è così che una persona si porta dietro quello
// che ha imparato attraverso un salvataggio.
void pesi_in_byte(const Sinapsi &syn, uint8_t *out);
bool byte_in_pesi(const uint8_t *in, Sinapsi *out);

} // namespace chibi

#endif
