#include "sistema_neurochimica.h"

#include <algorithm>
#include <cmath>

#include "ecs_componenti.h"
#include "sistema_sonno.h"

namespace chibi {

// ----------------------------------------------------------------------
// Integrazione analitica esatta per un canale neurochimico.
// Formula differenziale:
//   dN/dt = -lambda * (N - B) + Pi + impulsi
// Soluzione esatta:
//   N(t + dt) = B + (N - B) * e^(-lambda * dt) + Pi * dt + impulsi * suscettibilita
// ----------------------------------------------------------------------
float integrazione_esatta(float livello, float baseline, float decadimento,
		float produzione, float impulso, float suscettibilita, float dt) {
	if (dt <= 0.0f) {
		const float res = livello + impulso * suscettibilita;
		return std::clamp(res, 0.0f, 1.0f);
	}

	const float fattore_decadimento = (decadimento > 0.0f) ? std::exp(-decadimento * dt) : 1.0f;
	const float delta_prod = produzione * dt;
	const float delta_imp = impulso * suscettibilita;
	const float nuovo = baseline + (livello - baseline) * fattore_decadimento + delta_prod + delta_imp;

	return std::clamp(nuovo, 0.0f, 1.0f);
}

// ----------------------------------------------------------------------
// Calcolo della produzione continua ambientale (Pi) per ciascuno dei 7 canali.
// ----------------------------------------------------------------------
void calcola_produzione_ambientale(const AmbienteContesto &ambiente, bool dorme,
		float out_prod[N_NEURO]) {
	if (!out_prod) {
		return;
	}
	for (int i = 0; i < N_NEURO; i++) {
		out_prod[i] = 0.0f;
	}

	const float luce = std::clamp(ambiente.luce, 0.0f, 1.0f);
	const float pioggia = std::clamp(ambiente.pioggia, 0.0f, 1.0f);
	const float temp = ambiente.temperatura;
	const float diff_temp = std::abs(temp - 20.0f);
	const float comfort_termico = std::clamp(1.0f - (diff_temp / 20.0f), 0.0f, 1.0f);

	// 1. Dopamina: clima gradevole e luce favoriscono la motivazione all'esplorazione
	out_prod[NT_DOPAMINA] = 0.01f * comfort_termico * luce;

	// 2. Ossitocina: ambiente confortevole e calore percepito
	out_prod[NT_OSSITOCINA] = 0.005f * comfort_termico;

	// 3. Serotonina: forte stimolo dalla luce solare diretta, inibita dal maltempo
	out_prod[NT_SEROTONINA] = 0.04f * luce * (1.0f - 0.5f * pioggia);

	// 4. Cortisolo: stress indotto da pioggia battente o disagio termico (troppo freddo o troppo caldo)
	if (!dorme) {
		const float stress = 0.03f * pioggia + 0.02f * (1.0f - comfort_termico);
		out_prod[NT_CORTISOLO] = stress;
	} else {
		out_prod[NT_CORTISOLO] = 0.0f;
	}

	// 5. Melatonina: sale progressivamente col buio (1.0 - luce)
	out_prod[NT_MELATONINA] = 0.06f * (1.0f - luce);

	// 6. Adenosina: accumulo omeostatico di sonno durante la veglia
	if (!dorme) {
		out_prod[NT_ADENOSINA] = 0.015f;
	} else {
		out_prod[NT_ADENOSINA] = 0.0f;
	}

	// 7. Endorfine: senso di benessere fisico derivato dal comfort e clima temperato
	out_prod[NT_ENDORFINE] = 0.01f * comfort_termico * (1.0f - 0.5f * pioggia);
}

// ----------------------------------------------------------------------
// Passo neurochimico batch su un array di componenti
// ----------------------------------------------------------------------
void passo_neurochimico_batch(ComponenteNeurochimica *neuro, const StatoComponent *stati,
		int n, float dt, const AmbienteContesto &amb) {
	if (!neuro || n <= 0 || dt <= 0.0f) {
		return;
	}

	for (int i = 0; i < n; i++) {
		const bool dorme = (stati != nullptr) && (stati[i].stato == chibi::DORME);
		float prod_amb[N_NEURO];
		calcola_produzione_ambientale(amb, dorme, prod_amb);

		for (int k = 0; k < N_NEURO; k++) {
			const float prod_totale = neuro[i].produzione[k] + prod_amb[k];
			neuro[i].livello[k] = integrazione_esatta(
					neuro[i].livello[k],
					neuro[i].baseline[k],
					neuro[i].decadimento[k],
					prod_totale,
					neuro[i].impulsi[k],
					neuro[i].suscettibilita[k],
					dt);
			// Gli impulsi istantanei vengono consumati al passo di integrazione
			neuro[i].impulsi[k] = 0.0f;
		}
	}
}

// ----------------------------------------------------------------------
// Inizializzazione personalizzata di baseline e dinamiche per indole
// ----------------------------------------------------------------------
void inizializza_neurochimica_indole(ComponenteNeurochimica &c, uint32_t indole) {
	// Baseline neutra standard
	c.baseline[NT_DOPAMINA] = 0.50f;
	c.baseline[NT_OSSITOCINA] = 0.50f;
	c.baseline[NT_SEROTONINA] = 0.50f;
	c.baseline[NT_CORTISOLO] = 0.20f;
	c.baseline[NT_MELATONINA] = 0.10f;
	c.baseline[NT_ADENOSINA] = 0.20f;
	c.baseline[NT_ENDORFINE] = 0.40f;

	c.decadimento[NT_DOPAMINA] = 0.05f;
	c.decadimento[NT_OSSITOCINA] = 0.05f;
	c.decadimento[NT_SEROTONINA] = 0.02f;
	c.decadimento[NT_CORTISOLO] = 0.08f;
	c.decadimento[NT_MELATONINA] = 0.10f;
	c.decadimento[NT_ADENOSINA] = 0.04f;
	c.decadimento[NT_ENDORFINE] = 0.06f;

	for (int i = 0; i < N_NEURO; i++) {
		c.produzione[i] = 0.0f;
		c.impulsi[i] = 0.0f;
		c.suscettibilita[i] = 1.0f;
	}

	// Adattamento dei parametri omeostatici per indole
	if (indole & I_GOLOSO) {
		c.baseline[NT_DOPAMINA] = 0.60f;
		c.baseline[NT_ENDORFINE] = 0.50f;
		c.suscettibilita[NT_DOPAMINA] = 1.3f;
	}
	if (indole & I_DORMIGLIONE) {
		c.baseline[NT_MELATONINA] = 0.30f;
		c.baseline[NT_ADENOSINA] = 0.25f;
		c.baseline[NT_CORTISOLO] = 0.10f;
		c.decadimento[NT_ADENOSINA] = 0.02f;
	}
	if (indole & I_MATTINIERO) {
		c.baseline[NT_MELATONINA] = 0.05f;
		c.baseline[NT_SEROTONINA] = 0.65f;
		c.decadimento[NT_MELATONINA] = 0.15f;
	}
	if (indole & I_CHIACCHIERONE) {
		c.baseline[NT_OSSITOCINA] = 0.65f;
		c.baseline[NT_DOPAMINA] = 0.55f;
		c.suscettibilita[NT_OSSITOCINA] = 1.4f;
	}
	if (indole & I_TIMIDO) {
		c.baseline[NT_CORTISOLO] = 0.30f;
		c.baseline[NT_OSSITOCINA] = 0.40f;
		c.suscettibilita[NT_CORTISOLO] = 1.3f;
	}
	if (indole & I_SOGNATORE) {
		c.baseline[NT_SEROTONINA] = 0.60f;
		c.baseline[NT_DOPAMINA] = 0.55f;
		c.baseline[NT_MELATONINA] = 0.20f;
	}
	if (indole & I_ORDINATO) {
		c.baseline[NT_SEROTONINA] = 0.60f;
		c.baseline[NT_CORTISOLO] = 0.15f;
	}
	if (indole & I_BRONTOLONE) {
		c.baseline[NT_CORTISOLO] = 0.35f;
		c.baseline[NT_SEROTONINA] = 0.35f;
		c.baseline[NT_OSSITOCINA] = 0.35f;
	}

	// I livelli attuali partono sincronizzati alla baseline
	for (int i = 0; i < N_NEURO; i++) {
		c.livello[i] = c.baseline[i];
	}
}

} // namespace chibi
