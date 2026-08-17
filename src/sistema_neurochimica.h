#ifndef CHIBI_SISTEMA_NEUROCHIMICA_H
#define CHIBI_SISTEMA_NEUROCHIMICA_H

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>

// ======================================================================
// IL SISTEMA NEUROCHIMICO DEL VILLAGGIO
//
// Modello a 7 canali per la dinamica neurochimica interna degli abitanti:
// 1. Dopamina: anticipazione della ricompensa, motivazione ed esplorazione.
// 2. Ossitocina: legame sociale, fiducia, calore e vicinanza affettiva.
// 3. Serotonina: stabilità dell'umore, sazietà e senso di appagamento.
// 4. Cortisolo: risposta allo stress, freddo, maltempo o isolamento.
// 5. Melatonina: propensione al sonno, regolata dal buio e ciclo circadiano.
// 6. Adenosina: pressione omeostatica del sonno (si accumula durante la veglia).
// 7. Endorfine: benessere fisico, sollievo e sensazione di comfort.
//
// DINAMICA TEMPORALE (Integrazione Esatta):
// Ogni canale evolve secondo l'equazione differenziale:
//   dN/dt = -lambda * (N - B) + Pi + impulsi
// la cui soluzione analitica esatta per un passo dt è:
//   N(t + dt) = B + (N(t) - B) * e^(-lambda * dt) + Pi * dt + impulsi * suscettibilita
// ======================================================================

namespace chibi {

enum Neurotrasmettitore : int32_t {
	NT_DOPAMINA = 0,
	NT_OSSITOCINA = 1,
	NT_SEROTONINA = 2,
	NT_CORTISOLO = 3,
	NT_MELATONINA = 4,
	NT_ADENOSINA = 5,
	NT_ENDORFINE = 6,
	N_NEURO = 7,
};

// Contesto ambientale che influenza la produzione continua dei neurotrasmettitori.
struct AmbienteContesto {
	float temperatura = 20.0f; // Gradi Celsius (comfort a ~20°C)
	float luce = 1.0f;        // 0.0 (buio) .. 1.0 (pieno giorno)
	float pioggia = 0.0f;     // 0.0 (asciutto) .. 1.0 (pioggia intensa)
	float ora = 0.5f;         // Frazione della giornata (0.0 .. 1.0)
};

// Forward declaration per i componenti ECS
struct ComponenteNeurochimica;
struct StatoComponent;

// --- FUNZIONI PURE ----------------------------------------------------

// Risolve analiticamente l'equazione differenziale neurochimica su un intervallo dt.
// Garantisce stabilità incondizionata, determinismo e pinzaggio in [0.0, 1.0].
float integrazione_esatta(float livello, float baseline, float decadimento,
		float produzione, float impulso, float suscettibilita, float dt);

// Calcola la produzione continua indotta dall'ambiente esterno per i 7 canali.
void calcola_produzione_ambientale(const AmbienteContesto &ambiente, bool dorme,
		float out_prod[N_NEURO]);

// Esegue il passo neurochimico vettorizzato su un batch di entità.
void passo_neurochimico_batch(ComponenteNeurochimica *neuro, const StatoComponent *stati,
		int n, float dt, const AmbienteContesto &amb);

// Inizializza baseline, decadimenti e suscettibilità in base all'indole dell'abitante.
void inizializza_neurochimica_indole(ComponenteNeurochimica &c, uint32_t indole);

} // namespace chibi

#endif // CHIBI_SISTEMA_NEUROCHIMICA_H
