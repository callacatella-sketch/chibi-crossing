#ifndef CHIBI_ECS_MONDO_H
#define CHIBI_ECS_MONDO_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

// IL REGISTRO. Un Node Godot che possiede un registry EnTT e gli fa fare
// UNA cosa sola: decidere se un residente sta sveglio, dorme, o è rimasto
// fuori perché qualcuno gli ha chiuso la porta.
//
// Perché così poco: la logica degli NPC di questo gioco sono ~15.000 righe
// di GDScript con undici sistemi che impongono stati a evento (il concerto,
// il salone, il nascondino, le promesse…). Un'autorità C++ che scrivesse
// «lo stato» ogni frame entrerebbe in guerra silenziosa con loro — uno dei
// due vince e nessuno se ne accorge. Qui l'autorità è su UN canale, quello
// del sonno, e su quel canale nessun altro scrive (vedi CLAUDE.md).
//
// COSA NON C'È, e non per dimenticanza:
//  · nessun `_process` / `_physics_process`. Il passo è `avanza()`, chiamato
//    da Visitors.gd dentro il suo frame: l'ordine fatti → passo →
//    applicazione dev'essere deterministico e guidabile dai test. (E i
//    virtuali di una GDExtension non sono chiamabili per nome da GDScript.)
//  · nessuna persistenza, nessun gruppo "persistable", nessun save/load.
//    È la garanzia MECCANICA che questa classe non tocchi village.json.
//  · nessun RNG. I dadi del villaggio si salvano (Animo._rng), e un secondo
//    generatore in C++ sarebbe una seconda storia.
//  · nessuna etichetta, nessun nome. Il villaggio ha già due anagrafi (nome
//    e label): questa non deve diventare la terza. Attraversa il ponte solo
//    un handle numerico, che vive in RAM e non finisce su disco.
class EcsMondo : public godot::Node {
	GDCLASS(EcsMondo, godot::Node)

	// PIMPL: entt.hpp (2.9 MB) vive SOLO dentro ecs_mondo.cpp. Senza, ogni
	// unità di compilazione che includesse questo header se lo tirerebbe
	// dietro, e il tempo di build della CI (che non ha cache) esploderebbe.
	struct Registro;
	Registro *_reg = nullptr;

	// L'ora dell'ultimo `avanza()`. Serve a `in_finestra()`, che è una
	// lettura per la marionetta e per i test: così la finestra continua a
	// esistere in UN posto solo (il sistema puro) e il chiamante non ha
	// modo di chiedersela con un'ora sua, che è come nascono due verità.
	double _ultima_ora = 0.0;

protected:
	static void _bind_methods();

public:
	// Il registry nasce nel COSTRUTTORE e non in `_ready`: la suite istanzia
	// le classi C++ con `.new()` FUORI dall'albero della scena e non chiama
	// mai `_ready` (convenzione dei test del progetto).
	EcsMondo();
	~EcsMondo();

	enum Stato {
		STATO_SVEGLIO = 0,
		STATO_DORME = 1,
		STATO_FUORI = 2,
	};

	// Le azioni dell'agenda. Il GDScript non scrive un indice a mano da
	// nessuna parte: legge queste costanti, come già fa per STATO_*.
	enum Azione {
		AZ_NESSUNA = -1,
		AZ_SPUNTINO = 0,
		AZ_RIPOSO = 1,
		AZ_CHIACCHIERE = 2,
		AZ_CURA_GIARDINO = 3,
		AZ_MERAVIGLIA = 4,
		AZ_STELLA = 5,
		AZ_REGIA = 6,
		AZ_GIRONZOLA = 7,
	};

	// --- anagrafe -------------------------------------------------------
	// L'handle porta dentro la VERSIONE dell'entità EnTT: l'handle di un
	// vicino congedato non risolve mai a un residente nuovo.
	int64_t registra(const godot::PackedStringArray &p_indole, const godot::String &p_quirk);
	// La proiezione del DNA si può RIFARE. Serve perché indole e quirk sono
	// scrivibili a runtime (Visitors.debug_quirk → DebugHarness): una
	// fotografia scattata alla registrazione e mai più aggiornata farebbe
	// andare a letto alle 0.80 uno che è appena diventato nottambulo, e il
	// commento che giurava il contrario sarebbe stato una bugia.
	void riproietta(int64_t p_id, const godot::PackedStringArray &p_indole, const godot::String &p_quirk);
	void dimentica(int64_t p_id);
	void dimentica_tutti();
	bool conosce(int64_t p_id) const;
	int quanti() const;

	// --- i fatti che il mondo riferisce (una chiamata per residente/frame)
	// Sono FATTI, non decisioni: il C++ non entra mai nell'albero della
	// scena e non chiama mai una Callable.
	void riferisci(int64_t p_id, bool p_nascosto, bool p_corpo_libero, bool p_porta_aperta);

	// --- i fatti della FASE 2 (una chiamata per residente per frame) -----
	// I bisogni arrivano come SPECCHIO: il proprietario resta VillagerBrain
	// (sono persistiti), qui se ne tiene una copia di sola lettura per il
	// frame in corso.
	void riferisci_bisogni(int64_t p_id, const godot::PackedFloat64Array &p_bisogni);
	void riferisci_agenda(int64_t p_id, int p_fatti, bool p_corpo_a_riposo, bool p_zittita);
	// Il dado, tirato in GDScript e spinto di qua già estratto. Va rifornito
	// solo quando serve (vedi `vuole_dado`): congelarlo per DECISIONE invece
	// di ritirarlo a ogni frame è una delle tre leve contro il tremolio —
	// senza, misurato, si passa da 0.2 a 922 cambi d'idea al minuto.
	void semina_agenda(int64_t p_id, const godot::PackedFloat64Array &p_jitter);
	bool vuole_dado(int64_t p_id) const;

	// --- il passo -------------------------------------------------------
	void avanza(double p_delta, double p_ora);

	// --- letture (la marionetta) ----------------------------------------
	int azione(int64_t p_id) const;
	// IL FRONTE, ed è l'unico permesso di recitare: `_recita` va chiamata
	// SOLO quando l'azione cambia. Non è una mitigazione statistica del
	// tremolio, è l'impossibilità strutturale di rilanciare `do_task` due
	// frame di fila — che è ciò che impedirebbe al corpo di ARRIVARE.
	bool azione_cambiata(int64_t p_id) const;
	// L'argmax anche quando non si commuta: serve alla scena dell'esitazione
	// (si voleva fare una cosa e se ne sta facendo un'altra).
	int azione_desiderata(int64_t p_id) const;
	double azione_da(int64_t p_id) const;

	int stato(int64_t p_id) const;
	double da_quanto(int64_t p_id) const;
	bool in_finestra(int64_t p_id) const;

	// --- tabelle: i NOMI restano in GDScript, qui solo la traduzione -----
	int maschera_indole(const godot::PackedStringArray &p_nomi) const;
	int indice_quirk(const godot::String &p_nome) const;
	int maschera_fatti(const godot::PackedStringArray &p_nomi) const;
	// --- FASE 3: il pianificatore. Metodi CONST e senza entità: il piano
	// non entra nell'ECS. Il C++ possiede l'ALGORITMO; la vita del piano
	// (i corpi, i segnali, l'albero della scena) resta in GDScript, dove
	// stanno le cose che il piano muove.
	godot::PackedInt32Array pianifica(int p_stato, int p_obiettivo,
			const godot::PackedFloat64Array &p_cammino) const;
	int indice_operatore(const godot::String &p_nome) const;
	int maschera_obiettivo(const godot::String &p_nome) const;
	godot::Dictionary debug_piano(int p_stato, int p_obiettivo,
			const godot::PackedFloat64Array &p_cammino) const;
	godot::Dictionary debug_operatore(int p_id) const;
	void debug_tara_piani(double p_budget, int p_max_nodi, int p_max_prof);
	int indice_azione(const godot::String &p_nome) const;
	int indice_bisogno(const godot::String &p_nome) const;

	// --- oracoli per i test (precedente: EcosystemManager::debug_farfalla)
	godot::Dictionary debug_entita(int64_t p_id) const;
	bool debug_in_finestra(int p_maschera, int p_quirk, double p_ora) const;
	// Quante entità portano una posa. In Fase 1 deve essere SEMPRE 0: un
	// componente scritto ogni frame e letto da nessuno è un motore acceso a
	// vuoto. Il giorno in cui arriva il primo lettore vero, questo test si
	// capovolge di proposito.
	int debug_quante_pose() const;
	godot::PackedFloat64Array debug_punteggi(const godot::PackedFloat64Array &p_bisogni,
			int p_fatti, int p_indole, int p_quirk) const;
	godot::Dictionary debug_agenda(int64_t p_id) const;
	// La taratura si può muovere SOLO da un test: in partita i numeri sono
	// quelli misurati (vedi TaraturaAgenda). Serve alle ablazioni, che
	// guastano una valvola per volta e pretendono che qualcosa fallisca.
	void debug_tara_agenda(double p_t_min, double p_bonus, double p_margine, double p_tetto);
};

VARIANT_ENUM_CAST(EcsMondo::Stato);
VARIANT_ENUM_CAST(EcsMondo::Azione);

#endif // CHIBI_ECS_MONDO_H
