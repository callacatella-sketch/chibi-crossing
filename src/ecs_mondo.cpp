#include "ecs_mondo.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>

#include "ecs_componenti.h"
#include "ecs_entt.h"
#include "grafo_deduzioni.h"
#include "grafo_ricordi.h"
#include "sistema_agenda.h"
#include "sistema_occ.h"
#include "sistema_piani.h"
#include "sistema_sonno.h"

using namespace godot;

// Il registry vive QUI dentro e in nessun header: è tutto il senso del
// PIMPL dichiarato in ecs_mondo.h.
struct EcsMondo::Registro {
	entt::registry reg;
	chibi::TaraturaAgenda tar;
	chibi::TaraturaPiani tar_piani;
	chibi::TaraturaOcc tar_occ;

	Registro() {
		// ⚠️ LO SMORZAMENTO DEL SENTITO DIRE SI PAGA UNA VOLTA SOLA, E SI
		// PAGA IN `racconta()`.
		//
		// `sistema_occ` sa smorzare una voce in due posti diversi, e il piano
		// della Fase 4 li nominava tutti e due senza scegliere: §2.2 mette
		// `peso_sentito = 0.55` nella taratura (smorzatura in LETTURA), §5
		// pretende che `racconta()` scali l'INTENSITÀ (smorzatura nel DATO).
		// Applicarli insieme fa 0.55 × 0.55 = 0.30, e non lo dice nessuno: i
		// numeri restano plausibili, il pettegolezzo diventa solo più fioco
		// del previsto, e nessun test scritto in buona fede se ne accorge.
		//
		// La leva sceglie il DATO, per una ragione che si vede: dopo un
		// racconto, `debug_grafo` mostra un'intensità più bassa — la
		// smorzatura è un fatto OSSERVABILE, non un coefficiente nascosto
		// in una lettura. E chi vede la cosa con i propri occhi la ritrova a
		// piena forza, perché `inserisci()` fonde tenendo l'intensità
		// MASSIMA e cancella `R_SENTITO`.
		//
		// Quindi qui la lettura NON smorza più niente: 1.0, dichiarato. Il
		// default 0.55 resta quello del sistema puro (è il suo contratto, e
		// `test_occ` lo misura); questa riga è la scelta del chiamante, ed è
		// una riga che si vede invece di un default che si eredita.
		tar_occ.peso_sentito = 1.0;
	}
};

// --- la traduzione dei nomi -------------------------------------------
// I NOMI restano in GDScript (VillagerBrain.INDOLI / .QUIRKS): quella è la
// fonte unica. Qui c'è solo la corrispondenza, e un test la confronta con
// la tabella di là chiave per chiave.
namespace {

struct VoceIndole {
	const char *nome;
	uint32_t bit;
};

const VoceIndole INDOLI[] = {
	{ "goloso", chibi::I_GOLOSO },
	{ "dormiglione", chibi::I_DORMIGLIONE },
	{ "mattiniero", chibi::I_MATTINIERO },
	{ "chiacchierone", chibi::I_CHIACCHIERONE },
	{ "timido", chibi::I_TIMIDO },
	{ "sognatore", chibi::I_SOGNATORE },
	{ "ordinato", chibi::I_ORDINATO },
	{ "brontolone", chibi::I_BRONTOLONE },
};

// I nomi dei FATTI e delle AZIONI: come per indoli e quirk, la tabella vera
// vive in GDScript e qui c'è solo la traduzione. Un test li confronta uno a
// uno, cosi aggiungere un'azione di la senza insegnarla di qua fa diventare
// la suite ROSSA invece di far divergere due elenchi in silenzio.
const char *FATTI[] = {
	"mattina", "sera_stellata", "aiuola_da_annaffiare", "spuntino_vicino",
	"amico_in_giro", "regia", "meraviglia_posto", "regia_pronta",
	// FASE 3, in coda: l'ordine dei primi otto è un contratto
	"spuntino_raggiungibile", "aiuola_raggiungibile", "seduta_libera_vicina",
	"meraviglia_raggiungibile", "lavagna_pronta",
};

const char *AZIONI[] = {
	"spuntino", "riposo", "quattro_chiacchiere", "cura_giardino",
	"meraviglia", "stella", "regia", "gironzola",
};

// I NOMI DEGLI OPERATORI e degli obiettivi: come per tutto il resto, la
// tabella vera vive in GDScript e qui c'è solo la traduzione. Un test li
// lega uno a uno.
const char *OPERATORI[] = {
	"vai_al_cibo", "sgranocchia", "vai_all_aiuola", "annaffia",
	"vai_alla_seduta", "siedi", "pisolino", "vai_al_bello", "incantati",
	"vai_alla_lavagna", "chiedi_cibo", "chiedi_cura",
};

const char *OBIETTIVI[] = {
	"provvedi_pancino", "provvedi_cura", "provvedi_energia", "provvedi_meraviglia",
};

const char *BISOGNI[] = {
	"pancino", "energia", "compagnia", "meraviglia", "cura",
};

const char *QUIRKS[] = {
	"parla_ai_funghi",
	"paura_farfalle",
	"canta_alla_luna",
	"colleziona_sassolini",
	"ballerino",
	"pisolini_ovunque",
};

// FASE 4 — I NOMI DEGLI OTTO VERBI, nell'ordine di chibi::Verbo. Il bus
// della percezione manda una parola («annaffia»), non un intero: un numero
// scritto a mano in GDScript è il modo esatto in cui, inserendo un verbo in
// mezzo alla lista, si comincerebbe a ricordare il gesto sbagliato.
const char *VERBI[] = {
	"annaffia", "semina", "raccoglie", "costruisce",
	"taglia", "pesca", "cucina", "dona",
};

// I NOMI DELLE SEI COSE, nell'ordine di chibi::Cosa. Sono anche le chiavi
// di `Visitor.LP_SIMBOLI`, e non per comodità: nel grafo entra solo ciò che
// un chibi sa DIRE, se no è un dato che vive nel motore e non arriva mai
// allo schermo. Un test lega questi sei nomi a quel dizionario.
const char *COSE[] = {
	"fiore", "cibo", "casa", "fuoco", "pesce", "amico",
};

// --- FASE 4: il grafo attraversa il ponte come Dictionary --------------
// Marshalling e basta: nessuna regola vive qui dentro. Le uniche decisioni
// sono i pinzaggi sui campi a 8 bit — un valore fuori scala che entrasse
// per troncamento darebbe un ricordo plausibile e sbagliato, e un test che
// mente è peggio di un test che manca.
inline uint8_t a_u8(int64_t p_v) {
	if (p_v < 0) {
		return 0;
	}
	if (p_v > 255) {
		return 255;
	}
	return static_cast<uint8_t>(p_v);
}

inline int64_t leggi_int(const Dictionary &p_d, const char *p_k, int64_t p_def) {
	return static_cast<int64_t>(p_d.get(p_k, p_def));
}

inline double leggi_float(const Dictionary &p_d, const char *p_k, double p_def) {
	return static_cast<double>(p_d.get(p_k, p_def));
}

chibi::Ricordo ricordo_da(const Dictionary &p_d) {
	chibi::Ricordo r;
	r.soggetto = static_cast<uint32_t>(static_cast<uint64_t>(
			leggi_int(p_d, "soggetto", static_cast<int64_t>(chibi::SOGG_NESSUNO))));
	r.verbo = a_u8(leggi_int(p_d, "verbo", 0));
	r.cosa = a_u8(leggi_int(p_d, "cosa", 0));
	r.bandiere = a_u8(leggi_int(p_d, "bandiere", 0));
	r.quante = a_u8(leggi_int(p_d, "quante", 1));
	r.intensita = a_u8(leggi_int(p_d, "intensita", 255));
	r.px = static_cast<float>(leggi_float(p_d, "px", 0.0));
	r.pz = static_cast<float>(leggi_float(p_d, "pz", 0.0));
	r.quando = static_cast<float>(leggi_float(p_d, "quando", 0.0));
	return r;
}

Dictionary da_ricordo(const chibi::Ricordo &p_r) {
	Dictionary d;
	d["soggetto"] = static_cast<int64_t>(p_r.soggetto);
	d["verbo"] = static_cast<int>(p_r.verbo);
	d["cosa"] = static_cast<int>(p_r.cosa);
	d["bandiere"] = static_cast<int>(p_r.bandiere);
	d["quante"] = static_cast<int>(p_r.quante);
	d["intensita"] = static_cast<int>(p_r.intensita);
	d["px"] = p_r.px;
	d["pz"] = p_r.pz;
	d["quando"] = p_r.quando;
	return d;
}

chibi::GrafoRicordi grafo_da(const Dictionary &p_d) {
	chibi::GrafoRicordi g;
	const Array righe = p_d.get("ricordi", Array());
	const int n = (righe.size() < chibi::MAX_FATTI) ? static_cast<int>(righe.size())
													: chibi::MAX_FATTI;
	for (int i = 0; i < n; i++) {
		const Dictionary riga = righe[i];
		g.f[i] = ricordo_da(riga);
	}
	g.n = static_cast<uint8_t>(n);
	g.versione = static_cast<uint32_t>(static_cast<uint64_t>(leggi_int(p_d, "versione", 0)));
	return g;
}

Dictionary da_grafo(const chibi::GrafoRicordi &p_g) {
	Array righe;
	for (int i = 0; i < static_cast<int>(p_g.n); i++) {
		righe.append(da_ricordo(p_g.f[i]));
	}
	Dictionary d;
	d["ricordi"] = righe;
	d["versione"] = static_cast<int64_t>(p_g.versione);
	return d;
}

// L'handle che attraversa il ponte porta dentro la VERSIONE dell'entità:
// così l'handle di un vicino congedato non risolve mai a un residente
// nuovo che ne ha riciclato lo slot. È lo stesso motivo per cui la cella
// non può fare da chiave d'identità altrove nel progetto.
inline int64_t a_handle(entt::entity e) {
	return static_cast<int64_t>(entt::to_integral(e));
}

inline entt::entity da_handle(int64_t p_id) {
	if (p_id < 0) {
		return entt::null;
	}
	return static_cast<entt::entity>(static_cast<entt::id_type>(p_id));
}

} // namespace

EcsMondo::EcsMondo() {
	// nel COSTRUTTORE, non in _ready: i test istanziano con .new() fuori
	// dall'albero e _ready non viene mai chiamato
	_reg = memnew(Registro);
}

EcsMondo::~EcsMondo() {
	if (_reg != nullptr) {
		memdelete(_reg);
		_reg = nullptr;
	}
}

void EcsMondo::_bind_methods() {
	ClassDB::bind_method(D_METHOD("registra", "indole", "quirk"), &EcsMondo::registra);
	ClassDB::bind_method(D_METHOD("riproietta", "id", "indole", "quirk"), &EcsMondo::riproietta);
	ClassDB::bind_method(D_METHOD("dimentica", "id"), &EcsMondo::dimentica);
	ClassDB::bind_method(D_METHOD("dimentica_tutti"), &EcsMondo::dimentica_tutti);
	ClassDB::bind_method(D_METHOD("conosce", "id"), &EcsMondo::conosce);
	ClassDB::bind_method(D_METHOD("quanti"), &EcsMondo::quanti);
	ClassDB::bind_method(D_METHOD("riferisci", "id", "nascosto", "corpo_libero", "porta_aperta"), &EcsMondo::riferisci);
	ClassDB::bind_method(D_METHOD("riferisci_bisogni", "id", "bisogni"), &EcsMondo::riferisci_bisogni);
	ClassDB::bind_method(D_METHOD("riferisci_agenda", "id", "fatti", "corpo_a_riposo", "zittita"), &EcsMondo::riferisci_agenda);
	ClassDB::bind_method(D_METHOD("semina_agenda", "id", "jitter"), &EcsMondo::semina_agenda);
	ClassDB::bind_method(D_METHOD("vuole_dado", "id"), &EcsMondo::vuole_dado);
	ClassDB::bind_method(D_METHOD("azione", "id"), &EcsMondo::azione);
	ClassDB::bind_method(D_METHOD("azione_cambiata", "id"), &EcsMondo::azione_cambiata);
	ClassDB::bind_method(D_METHOD("azione_desiderata", "id"), &EcsMondo::azione_desiderata);
	ClassDB::bind_method(D_METHOD("azione_da", "id"), &EcsMondo::azione_da);
	ClassDB::bind_method(D_METHOD("maschera_fatti", "nomi"), &EcsMondo::maschera_fatti);
	ClassDB::bind_method(D_METHOD("indice_azione", "nome"), &EcsMondo::indice_azione);
	ClassDB::bind_method(D_METHOD("indice_bisogno", "nome"), &EcsMondo::indice_bisogno);
	ClassDB::bind_method(D_METHOD("debug_punteggi", "bisogni", "fatti", "indole", "quirk"), &EcsMondo::debug_punteggi);
	ClassDB::bind_method(D_METHOD("debug_punteggi_mod", "bisogni", "fatti", "indole", "quirk", "mod"), &EcsMondo::debug_punteggi_mod);
	ClassDB::bind_method(D_METHOD("debug_costanti_agenda"), &EcsMondo::debug_costanti_agenda);
	ClassDB::bind_method(D_METHOD("debug_agenda", "id"), &EcsMondo::debug_agenda);
	ClassDB::bind_method(D_METHOD("debug_occ", "ricordi", "gusto", "ora", "taratura"), &EcsMondo::debug_occ);
	ClassDB::bind_method(D_METHOD("debug_tara_agenda", "t_min", "bonus", "margine", "tetto"), &EcsMondo::debug_tara_agenda);
	ClassDB::bind_method(D_METHOD("pianifica", "stato", "obiettivo", "cammino"), &EcsMondo::pianifica);
	ClassDB::bind_method(D_METHOD("indice_operatore", "nome"), &EcsMondo::indice_operatore);
	ClassDB::bind_method(D_METHOD("maschera_obiettivo", "nome"), &EcsMondo::maschera_obiettivo);
	ClassDB::bind_method(D_METHOD("debug_piano", "stato", "obiettivo", "cammino"), &EcsMondo::debug_piano);
	ClassDB::bind_method(D_METHOD("debug_operatore", "id"), &EcsMondo::debug_operatore);
	ClassDB::bind_method(D_METHOD("debug_tara_piani", "budget", "max_nodi", "max_prof"), &EcsMondo::debug_tara_piani);
	ClassDB::bind_method(D_METHOD("avanza", "delta", "ora"), &EcsMondo::avanza);
	ClassDB::bind_method(D_METHOD("stato", "id"), &EcsMondo::stato);
	ClassDB::bind_method(D_METHOD("da_quanto", "id"), &EcsMondo::da_quanto);
	ClassDB::bind_method(D_METHOD("in_finestra", "id"), &EcsMondo::in_finestra);
	ClassDB::bind_method(D_METHOD("maschera_indole", "nomi"), &EcsMondo::maschera_indole);
	ClassDB::bind_method(D_METHOD("indice_quirk", "nome"), &EcsMondo::indice_quirk);
	ClassDB::bind_method(D_METHOD("debug_entita", "id"), &EcsMondo::debug_entita);
	ClassDB::bind_method(D_METHOD("debug_in_finestra", "maschera", "quirk", "ora"), &EcsMondo::debug_in_finestra);
	ClassDB::bind_method(D_METHOD("debug_quante_pose"), &EcsMondo::debug_quante_pose);
	ClassDB::bind_method(D_METHOD("debug_grafo_inserisci", "grafo", "ricordo", "ora", "mezza_vita"), &EcsMondo::debug_grafo_inserisci);
	ClassDB::bind_method(D_METHOD("debug_grafo_peso", "ricordo", "ora", "mezza_vita"), &EcsMondo::debug_grafo_peso);
	ClassDB::bind_method(D_METHOD("debug_grafo_da_raccontare", "grafo", "ora", "mezza_vita"), &EcsMondo::debug_grafo_da_raccontare);
	ClassDB::bind_method(D_METHOD("debug_grafo_costanti"), &EcsMondo::debug_grafo_costanti);
	// FASE 4 (P4-P5): il grafo vivo sull'entita, e il passaparola
	ClassDB::bind_method(D_METHOD("osserva", "id", "verbo", "dove", "soggetto"), &EcsMondo::osserva);
	ClassDB::bind_method(D_METHOD("racconta", "a", "b", "smorzamento"), &EcsMondo::racconta);
	ClassDB::bind_method(D_METHOD("riferisci_gusto", "id", "gusto"), &EcsMondo::riferisci_gusto);
	ClassDB::bind_method(D_METHOD("imposta_ritmo", "ciclo_secondi"), &EcsMondo::imposta_ritmo);
	// FASE 4 (P6): le tre letture vive — NON sono oracoli, le chiama il gioco
	ClassDB::bind_method(D_METHOD("ammirazione", "id"), &EcsMondo::ammirazione);
	ClassDB::bind_method(D_METHOD("dove", "id", "cosa", "soglia", "se_niente"), &EcsMondo::dove);
	ClassDB::bind_method(D_METHOD("cosa_da_ricordare", "id", "soglia"), &EcsMondo::cosa_da_ricordare);
	ClassDB::bind_method(D_METHOD("debug_grafo", "id"), &EcsMondo::debug_grafo);
	ClassDB::bind_method(D_METHOD("debug_emozioni", "id"), &EcsMondo::debug_emozioni);
	ClassDB::bind_method(D_METHOD("debug_ritmo"), &EcsMondo::debug_ritmo);
	ClassDB::bind_method(D_METHOD("debug_grafo_novita", "grafo", "ora", "mezza_vita", "gia_saputi"), &EcsMondo::debug_grafo_novita);
	// FASE 5 (P3): l'injection. Il JSON si apre in GDScript; di qua passano
	// due interi e una lista di indici (vedi la nota in ecs_mondo.h).
	ClassDB::bind_method(D_METHOD("deduci", "id", "obiettivo", "righe", "soglia"), &EcsMondo::deduci);
	ClassDB::bind_method(D_METHOD("deduzione_muta", "id", "soglia"), &EcsMondo::deduzione_muta);
	ClassDB::bind_method(D_METHOD("deduzione_pronta", "id", "soglia", "attesa", "finestra"), &EcsMondo::deduzione_pronta);
	ClassDB::bind_method(D_METHOD("deduzione_dove", "id", "i", "se_niente"), &EcsMondo::deduzione_dove);
	ClassDB::bind_method(D_METHOD("deduzione_obiettivo", "id", "i"), &EcsMondo::deduzione_obiettivo);
	ClassDB::bind_method(D_METHOD("deduzione_ricevuta", "id", "i"), &EcsMondo::deduzione_ricevuta);
	ClassDB::bind_method(D_METHOD("deduzione_spendi", "id", "i"), &EcsMondo::deduzione_spendi);
	ClassDB::bind_method(D_METHOD("debug_deduzioni", "id"), &EcsMondo::debug_deduzioni);
	ClassDB::bind_method(D_METHOD("debug_deduzioni_costanti"), &EcsMondo::debug_deduzioni_costanti);
	ClassDB::bind_method(D_METHOD("indice_verbo", "nome"), &EcsMondo::indice_verbo);
	ClassDB::bind_method(D_METHOD("indice_cosa", "nome"), &EcsMondo::indice_cosa);
	ClassDB::bind_method(D_METHOD("nome_verbo", "verbo"), &EcsMondo::nome_verbo);
	ClassDB::bind_method(D_METHOD("nome_cosa", "cosa"), &EcsMondo::nome_cosa);

	// il GDScript non scrive mai 0/1/2 a mano
	BIND_ENUM_CONSTANT(STATO_SVEGLIO);
	BIND_ENUM_CONSTANT(STATO_DORME);
	BIND_ENUM_CONSTANT(STATO_FUORI);
	BIND_ENUM_CONSTANT(AZ_NESSUNA);
	BIND_ENUM_CONSTANT(AZ_SPUNTINO);
	BIND_ENUM_CONSTANT(AZ_RIPOSO);
	BIND_ENUM_CONSTANT(AZ_CHIACCHIERE);
	BIND_ENUM_CONSTANT(AZ_CURA_GIARDINO);
	BIND_ENUM_CONSTANT(AZ_MERAVIGLIA);
	BIND_ENUM_CONSTANT(AZ_STELLA);
	BIND_ENUM_CONSTANT(AZ_REGIA);
	BIND_ENUM_CONSTANT(AZ_GIRONZOLA);

	// FASE 4: nemmeno un verbo, una cosa o una bandiera si scrivono a mano
	BIND_ENUM_CONSTANT(V_ANNAFFIA);
	BIND_ENUM_CONSTANT(V_SEMINA);
	BIND_ENUM_CONSTANT(V_RACCOGLIE);
	BIND_ENUM_CONSTANT(V_COSTRUISCE);
	BIND_ENUM_CONSTANT(V_TAGLIA);
	BIND_ENUM_CONSTANT(V_PESCA);
	BIND_ENUM_CONSTANT(V_CUCINA);
	BIND_ENUM_CONSTANT(V_DONA);
	BIND_ENUM_CONSTANT(N_VERBI);
	BIND_ENUM_CONSTANT(C_FIORE);
	BIND_ENUM_CONSTANT(C_CIBO);
	BIND_ENUM_CONSTANT(C_CASA);
	BIND_ENUM_CONSTANT(C_FUOCO);
	BIND_ENUM_CONSTANT(C_PESCE);
	BIND_ENUM_CONSTANT(C_AMICO);
	BIND_ENUM_CONSTANT(N_COSE);
	BIND_ENUM_CONSTANT(R_SENTITO);
	BIND_ENUM_CONSTANT(R_SU_DI_ME);
	BIND_ENUM_CONSTANT(R_DETTO);
}

int EcsMondo::maschera_indole(const PackedStringArray &p_nomi) const {
	uint32_t m = 0;
	for (int i = 0; i < p_nomi.size(); i++) {
		const String &n = p_nomi[i];
		for (const VoceIndole &v : INDOLI) {
			if (n == String(v.nome)) {
				m |= v.bit;
				break;
			}
		}
	}
	// un nome ignoto vale zero e basta: qui non si alza la voce, perché è
	// il TEST che deve accorgersi di una tabella divergente, non il gioco
	// del giocatore
	return static_cast<int>(m);
}

int EcsMondo::indice_quirk(const String &p_nome) const {
	for (int i = 0; i < static_cast<int>(sizeof(QUIRKS) / sizeof(QUIRKS[0])); i++) {
		if (p_nome == String(QUIRKS[i])) {
			return i;
		}
	}
	return chibi::Q_NESSUNO;
}

int64_t EcsMondo::registra(const PackedStringArray &p_indole, const String &p_quirk) {
	ERR_FAIL_NULL_V(_reg, -1);
	const entt::entity e = _reg->reg.create();
	chibi::DnaComponent dna;
	dna.indole = static_cast<uint32_t>(maschera_indole(p_indole));
	dna.quirk = indice_quirk(p_quirk);
	_reg->reg.emplace<chibi::DnaComponent>(e, dna);
	_reg->reg.emplace<chibi::StatoComponent>(e);
	_reg->reg.emplace<chibi::MondoComponent>(e);
	_reg->reg.emplace<chibi::BisogniComponent>(e);
	_reg->reg.emplace<chibi::AgendaComponent>(e);
	// FASE 4: i tre componenti nascono INSIEME agli altri, e con i loro
	// valori neutri (grafo vuoto, gusto tutto 1.0, otto modulatori a 1.0
	// letterale). Non c'è nessun percorso che crei un'entità senza di loro,
	// ed è quello che permette a `vista2` di allargarsi senza cambiare
	// l'insieme degli iterati: un componente aggiunto «quando serve» avrebbe
	// fatto sparire dei residenti dall'agenda, in silenzio.
	_reg->reg.emplace<chibi::GrafoComponent>(e);
	_reg->reg.emplace<chibi::GustoComponent>(e);
	_reg->reg.emplace<chibi::EmozioniComponent>(e);
	// FASE 5: nasce vuoto insieme agli altri, e per chi non ha il modello
	// resta vuoto per l'intera partita. Vedi `DeduzioniComponent`.
	_reg->reg.emplace<chibi::DeduzioniComponent>(e);
	// NIENTE TransformComponent: vedi ecs_componenti.h
	return a_handle(e);
}

void EcsMondo::riproietta(int64_t p_id, const PackedStringArray &p_indole, const String &p_quirk) {
	ERR_FAIL_NULL(_reg);
	ERR_FAIL_COND_MSG(!conosce(p_id), "EcsMondo.riproietta: handle sconosciuto.");
	chibi::DnaComponent &dna = _reg->reg.get<chibi::DnaComponent>(da_handle(p_id));
	dna.indole = static_cast<uint32_t>(maschera_indole(p_indole));
	dna.quirk = indice_quirk(p_quirk);
}

bool EcsMondo::conosce(int64_t p_id) const {
	if (_reg == nullptr) {
		return false;
	}
	const entt::entity e = da_handle(p_id);
	return e != entt::null && _reg->reg.valid(e);
}

void EcsMondo::dimentica(int64_t p_id) {
	ERR_FAIL_NULL(_reg);
	const entt::entity e = da_handle(p_id);
	if (e != entt::null && _reg->reg.valid(e)) {
		_reg->reg.destroy(e);
	}
}

void EcsMondo::dimentica_tutti() {
	ERR_FAIL_NULL(_reg);
	_reg->reg.clear();
}

int EcsMondo::quanti() const {
	if (_reg == nullptr) {
		return 0;
	}
	int n = 0;
	for (const entt::entity e : _reg->reg.view<chibi::StatoComponent>()) {
		(void)e;
		n++;
	}
	return n;
}

void EcsMondo::riferisci(int64_t p_id, bool p_nascosto, bool p_corpo_libero, bool p_porta_aperta) {
	ERR_FAIL_NULL(_reg);
	ERR_FAIL_COND_MSG(!conosce(p_id), "EcsMondo.riferisci: handle sconosciuto.");
	chibi::MondoComponent &m = _reg->reg.get<chibi::MondoComponent>(da_handle(p_id));
	m.nascosto = p_nascosto;
	m.corpo_libero = p_corpo_libero;
	m.porta_aperta = p_porta_aperta;
}

void EcsMondo::avanza(double p_delta, double p_ora) {
	ERR_FAIL_NULL(_reg);
	_ultima_ora = p_ora;
	// L'OROLOGIO DELLA MEMORIA. Monotono per costruzione: un delta negativo
	// (un banco di prova che va all'indietro, un frame patologico) non lo fa
	// tornare indietro. Se potesse, i ricordi ringiovanirebbero e la potatura
	// non troverebbe piu il piu debole — vedi la stessa guardia in `peso()`.
	_tempo += (p_delta > 0.0) ? p_delta : 0.0;
	auto vista = _reg->reg.view<chibi::DnaComponent, chibi::StatoComponent, chibi::MondoComponent>();
	for (const entt::entity e : vista) {
		const chibi::DnaComponent &dna = vista.get<chibi::DnaComponent>(e);
		chibi::StatoComponent &st = vista.get<chibi::StatoComponent>(e);
		const chibi::MondoComponent &mo = vista.get<chibi::MondoComponent>(e);
		const bool dentro = chibi::finestra_di_sonno(dna.indole, dna.quirk, p_ora);
		const int32_t nuovo = chibi::passo_sonno(st.stato, mo.nascosto, dentro,
				mo.corpo_libero, mo.porta_aperta);
		if (nuovo == st.stato) {
			st.da += p_delta;
		} else {
			st.stato = nuovo;
			st.da = 0.0;
		}
	}

	// LA SECONDA VISTA: l'agenda, e gira DOPO il sonno apposta. Deve vedere
	// «dorme» gia deciso in questo stesso frame e tacere, se no il corpo
	// riceverebbe al risveglio un ordine deciso durante la notte.
	//
	// FASE 4 (P4): e qui dentro, e in nessuna terza vista, si rilegge anche
	// il CUORE. Una vista in piu costerebbe un secondo giro su tutte le
	// entita per un dato che serve tre righe piu in basso, e soprattutto
	// aprirebbe la domanda «gira prima o dopo?» su una cosa che deve stare
	// in un ordine solo: il modulatore dev'essere quello di ADESSO quando
	// `punteggi()` lo moltiplica.
	auto vista2 = _reg->reg.view<chibi::DnaComponent, chibi::StatoComponent,
			chibi::BisogniComponent, chibi::AgendaComponent,
			chibi::GrafoComponent, chibi::GustoComponent, chibi::EmozioniComponent>();
	for (const entt::entity e : vista2) {
		const chibi::DnaComponent &dna = vista2.get<chibi::DnaComponent>(e);
		const chibi::StatoComponent &st = vista2.get<chibi::StatoComponent>(e);
		const chibi::BisogniComponent &bi = vista2.get<chibi::BisogniComponent>(e);
		chibi::AgendaComponent &ag = vista2.get<chibi::AgendaComponent>(e);
		const chibi::GrafoComponent &gr = vista2.get<chibi::GrafoComponent>(e);
		const chibi::GustoComponent &gu = vista2.get<chibi::GustoComponent>(e);
		chibi::EmozioniComponent &emo = vista2.get<chibi::EmozioniComponent>(e);

		// IL GRADINO (regola 11 del piano della Fase 4).
		//
		// Si torna a leggere il proprio cuore per DUE ragioni, e nessuna
		// delle due e «e passato un frame»:
		//  · il grafo e cambiato — qualcuno ha visto qualcosa, o gliel'hanno
		//    raccontato, o il gusto e stato riproiettato. La reazione e
		//    IMMEDIATA: la ricevuta di un gesto non deve aspettare otto
		//    secondi, o il giocatore non la collega piu al gesto.
		//  · sono passati PASSO_EMO secondi — cioe il TEMPO che passa, che e
		//    l'unica altra cosa che muove la lettura (il peso decade in
		//    lettura, non nel dato).
		// Fuori da questi due casi il modulatore resta LO STESSO DOUBLE, bit
		// per bit. Perche a gradini e non a frame — le due misure vere, e la
		// ragione che invece NON vale — sta scritto su `PASSO_EMO` in
		// sistema_occ.h, in un posto solo.
		//
		// Il `dt < 0.0` non puo scattare con l'orologio monotono di sopra, e
		// c'e lo stesso: se un domani `_tempo` cambiasse padrone, il degrado
		// giusto e «rileggi», non «non rileggere mai piu».
		const double dt_emo = _tempo - static_cast<double>(emo.t_valutato);
		if (emo.vista != gr.g.versione || dt_emo >= chibi::PASSO_EMO || dt_emo < 0.0) {
			const chibi::Tinte tinte = chibi::valuta(gr.g, gu.gu,
					static_cast<float>(_tempo), _reg->tar_occ);
			// scrive tutti e otto i modulatori, sempre: `modulatori()` posa
			// otto 1.0 letterali e poi ne muove due. Nessun canale orfano —
			// non esiste una voce di `emo.mod` che possa restare indietro.
			chibi::modulatori(tinte, _reg->tar_occ, emo.mod);
			emo.vista = gr.g.versione;
			emo.t_valutato = static_cast<float>(_tempo);
		}

		// Con il grafo vuoto `modulatori()` scrive otto 1.0 LETTERALI, e la
		// neutralita dev'essere ESATTA: 1.0 e l'elemento neutro della
		// moltiplicazione, 0.9999999 no. Su quell'esattezza poggia la prova
		// di equivalenza dell'agenda (67.200 confronti bit-esatti), che
		// continua a valere per ogni residente che non ha ancora visto
		// niente — cioe per tutto il villaggio all'avvio.
		static_assert(chibi::N_AZIONI == 8, "otto azioni, otto modulatori");

		double punti[chibi::N_AZIONI];
		uint32_t fattibile = 0;
		chibi::punteggi(bi.v, ag.fatti, dna.indole,
				chibi::nottambulo(dna.indole, dna.quirk), emo.mod, punti, &fattibile);

		const bool sveglio = (st.stato == chibi::SVEGLIO);
		const chibi::EsitoAgenda es = chibi::passo_agenda(ag.azione, ag.da,
				ag.impegno, punti, ag.jitter, fattibile, ag.corpo_a_riposo,
				ag.zittita, sveglio, _reg->tar);

		ag.desiderata = es.desiderata;
		ag.punteggio = es.punteggio;
		ag.cambiata = es.cambiata;
		if (es.azione == ag.azione) {
			ag.da += p_delta;
		} else {
			ag.azione = es.azione;
			ag.da = 0.0;
		}
		// il tetto di sicurezza: se il corpo resta occupato all'infinito
		// (un cammino che non arriva, un gesto che non finisce) l'impegno
		// cresce finche non sblocca la decisione
		if (ag.corpo_a_riposo) {
			ag.impegno = 0.0;
		} else {
			ag.impegno += p_delta;
		}
	}
}

// --- FASE 2: i fatti, il dado, le letture -------------------------------

void EcsMondo::riferisci_bisogni(int64_t p_id, const PackedFloat64Array &p_bisogni) {
	ERR_FAIL_NULL(_reg);
	ERR_FAIL_COND_MSG(!conosce(p_id), "EcsMondo.riferisci_bisogni: handle sconosciuto.");
	ERR_FAIL_COND_MSG(p_bisogni.size() != chibi::N_BISOGNI,
			"EcsMondo.riferisci_bisogni: servono esattamente cinque bisogni.");
	chibi::BisogniComponent &b = _reg->reg.get<chibi::BisogniComponent>(da_handle(p_id));
	for (int i = 0; i < chibi::N_BISOGNI; i++) {
		b.v[i] = p_bisogni[i];
	}
}

void EcsMondo::riferisci_agenda(int64_t p_id, int p_fatti, bool p_corpo_a_riposo, bool p_zittita) {
	ERR_FAIL_NULL(_reg);
	ERR_FAIL_COND_MSG(!conosce(p_id), "EcsMondo.riferisci_agenda: handle sconosciuto.");
	chibi::AgendaComponent &a = _reg->reg.get<chibi::AgendaComponent>(da_handle(p_id));
	a.fatti = static_cast<uint32_t>(p_fatti);
	a.corpo_a_riposo = p_corpo_a_riposo;
	a.zittita = p_zittita;
}

void EcsMondo::semina_agenda(int64_t p_id, const PackedFloat64Array &p_jitter) {
	ERR_FAIL_NULL(_reg);
	ERR_FAIL_COND_MSG(!conosce(p_id), "EcsMondo.semina_agenda: handle sconosciuto.");
	ERR_FAIL_COND_MSG(p_jitter.size() != chibi::N_AZIONI,
			"EcsMondo.semina_agenda: serve un dado per azione.");
	chibi::AgendaComponent &a = _reg->reg.get<chibi::AgendaComponent>(da_handle(p_id));
	for (int i = 0; i < chibi::N_AZIONI; i++) {
		a.jitter[i] = p_jitter[i];
	}
}

bool EcsMondo::vuole_dado(int64_t p_id) const {
	ERR_FAIL_COND_V(!conosce(p_id), false);
	const chibi::AgendaComponent &a = _reg->reg.get<chibi::AgendaComponent>(da_handle(p_id));
	// il dado si ritira quando una decisione e finita: appena si cambia
	// azione, o quando non se ne sta facendo nessuna. Congelarlo dentro la
	// decisione e una delle tre leve contro il tremolio.
	return a.cambiata || a.azione == chibi::AZ_NESSUNA;
}

int EcsMondo::azione(int64_t p_id) const {
	ERR_FAIL_COND_V(!conosce(p_id), chibi::AZ_NESSUNA);
	return static_cast<int>(_reg->reg.get<chibi::AgendaComponent>(da_handle(p_id)).azione);
}

bool EcsMondo::azione_cambiata(int64_t p_id) const {
	ERR_FAIL_COND_V(!conosce(p_id), false);
	return _reg->reg.get<chibi::AgendaComponent>(da_handle(p_id)).cambiata;
}

int EcsMondo::azione_desiderata(int64_t p_id) const {
	ERR_FAIL_COND_V(!conosce(p_id), chibi::AZ_NESSUNA);
	return static_cast<int>(_reg->reg.get<chibi::AgendaComponent>(da_handle(p_id)).desiderata);
}

double EcsMondo::azione_da(int64_t p_id) const {
	ERR_FAIL_COND_V(!conosce(p_id), -1.0);
	return _reg->reg.get<chibi::AgendaComponent>(da_handle(p_id)).da;
}

int EcsMondo::maschera_fatti(const PackedStringArray &p_nomi) const {
	uint32_t m = 0;
	const int n = static_cast<int>(sizeof(FATTI) / sizeof(FATTI[0]));
	for (int i = 0; i < p_nomi.size(); i++) {
		for (int k = 0; k < n; k++) {
			if (p_nomi[i] == String(FATTI[k])) {
				m |= (1u << k);
				break;
			}
		}
	}
	return static_cast<int>(m);
}

int EcsMondo::indice_azione(const String &p_nome) const {
	const int n = static_cast<int>(sizeof(AZIONI) / sizeof(AZIONI[0]));
	for (int i = 0; i < n; i++) {
		if (p_nome == String(AZIONI[i])) {
			return i;
		}
	}
	return chibi::AZ_NESSUNA;
}

int EcsMondo::indice_bisogno(const String &p_nome) const {
	const int n = static_cast<int>(sizeof(BISOGNI) / sizeof(BISOGNI[0]));
	for (int i = 0; i < n; i++) {
		if (p_nome == String(BISOGNI[i])) {
			return i;
		}
	}
	return -1;
}

PackedFloat64Array EcsMondo::debug_punteggi(const PackedFloat64Array &p_bisogni,
		int p_fatti, int p_indole, int p_quirk) const {
	// OTTO 1.0 LETTERALI, costruiti QUI. Questa e la strada che percorre la
	// prova di equivalenza (67.200 confronti bit-esatti contro le formule di
	// prima), e deve attraversare la moltiplicazione del mod come tutti gli
	// altri: se `p_mod` fosse nullable e questa funzione passasse `nullptr`,
	// l'equivalenza proverebbe il ramo VECCHIO e il codice nuovo resterebbe
	// senza copertura — che e il difetto che la revisione della Fase 1 ha
	// trovato due volte.
	//
	// NON delega a `debug_punteggi_mod`: sono due siti di chiamata veri e
	// distinti, uno con gli 1.0 nati in C++ e uno con gli 1.0 che arrivano
	// dal ponte. Farne uno solo vorrebbe dire provare il ponte una volta e
	// credere di averlo provato due.
	static_assert(chibi::N_AZIONI == 8, "otto azioni, otto 1.0 letterali");
	const double mod[chibi::N_AZIONI] = { 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 };

	PackedFloat64Array out;
	ERR_FAIL_COND_V(p_bisogni.size() != chibi::N_BISOGNI, out);
	double b[chibi::N_BISOGNI];
	for (int i = 0; i < chibi::N_BISOGNI; i++) {
		b[i] = p_bisogni[i];
	}
	double punti[chibi::N_AZIONI];
	uint32_t fattibile = 0;
	const uint32_t ind = static_cast<uint32_t>(p_indole);
	chibi::punteggi(b, static_cast<uint32_t>(p_fatti), ind,
			chibi::nottambulo(ind, static_cast<int32_t>(p_quirk)), mod, punti, &fattibile);
	out.resize(chibi::N_AZIONI);
	for (int i = 0; i < chibi::N_AZIONI; i++) {
		out[i] = punti[i];
	}
	return out;
}

PackedFloat64Array EcsMondo::debug_punteggi_mod(const PackedFloat64Array &p_bisogni,
		int p_fatti, int p_indole, int p_quirk, const PackedFloat64Array &p_mod) const {
	PackedFloat64Array out;
	ERR_FAIL_COND_V(p_bisogni.size() != chibi::N_BISOGNI, out);
	// UN MODULATORE PER AZIONE, e la lista storta si RIFIUTA invece di
	// leggere quel che c'e oltre il fondo: un test scritto male deve dirlo
	// subito, non produrre punteggi plausibili e sbagliati.
	ERR_FAIL_COND_V_MSG(p_mod.size() != chibi::N_AZIONI, out,
			"EcsMondo.debug_punteggi_mod: serve un modulatore per azione.");
	double b[chibi::N_BISOGNI];
	for (int i = 0; i < chibi::N_BISOGNI; i++) {
		b[i] = p_bisogni[i];
	}
	double mod[chibi::N_AZIONI];
	for (int i = 0; i < chibi::N_AZIONI; i++) {
		mod[i] = p_mod[i];
	}
	double punti[chibi::N_AZIONI];
	uint32_t fattibile = 0;
	const uint32_t ind = static_cast<uint32_t>(p_indole);
	chibi::punteggi(b, static_cast<uint32_t>(p_fatti), ind,
			chibi::nottambulo(ind, static_cast<int32_t>(p_quirk)), mod, punti, &fattibile);
	out.resize(chibi::N_AZIONI);
	for (int i = 0; i < chibi::N_AZIONI; i++) {
		out[i] = punti[i];
	}
	return out;
}

Dictionary EcsMondo::debug_costanti_agenda() const {
	Dictionary d;
	ERR_FAIL_NULL_V(_reg, d);
	// LE COSTANTI DELL'INNESTO, lette dal C++ e mai riscritte a mano di la:
	// e la stessa disciplina di `debug_grafo_costanti` e di `debug_occ`.
	// La relazione che conta e `delta_max < margine` — l'emozione INCLINA,
	// non apre la corsia d'urgenza — e un test la pretende leggendo
	// ENTRAMBI i numeri da qui. Se un domani qualcuno alza il tetto, quel
	// test diventa rosso invece di continuare a raccontare una regola che
	// non vale piu.
	d["delta_max"] = chibi::DELTA_MAX;
	d["n_azioni"] = static_cast<int>(chibi::N_AZIONI);
	d["n_bisogni"] = static_cast<int>(chibi::N_BISOGNI);
	// la taratura VIVA di questo registro (per un'istanza appena creata sono
	// i valori con cui il gioco parte; `debug_tara_agenda` la muove)
	d["t_min"] = _reg->tar.t_min;
	d["bonus"] = _reg->tar.bonus;
	d["margine"] = _reg->tar.margine;
	d["tetto_impegno"] = _reg->tar.tetto_impegno;
	return d;
}

Dictionary EcsMondo::debug_agenda(int64_t p_id) const {
	Dictionary d;
	ERR_FAIL_COND_V(!conosce(p_id), d);
	const chibi::AgendaComponent &a = _reg->reg.get<chibi::AgendaComponent>(da_handle(p_id));
	d["azione"] = static_cast<int>(a.azione);
	d["desiderata"] = static_cast<int>(a.desiderata);
	d["da"] = a.da;
	d["impegno"] = a.impegno;
	d["punteggio"] = a.punteggio;
	d["fatti"] = static_cast<int>(a.fatti);
	d["corpo_a_riposo"] = a.corpo_a_riposo;
	d["zittita"] = a.zittita;
	d["cambiata"] = a.cambiata;
	return d;
}

Dictionary EcsMondo::debug_occ(const PackedFloat64Array &p_ricordi,
		const PackedFloat64Array &p_gusto, double p_ora,
		const Dictionary &p_taratura) const {
	Dictionary d;
	// CINQUE double per ricordo: una lista storta è un test scritto male, e
	// deve dirlo subito invece di perdere l'ultimo ricordo in silenzio.
	ERR_FAIL_COND_V_MSG(p_ricordi.size() % 5 != 0, d,
			"EcsMondo.debug_occ: cinque valori per ricordo (verbo, bandiere, quante, intensita, quando).");
	const int n = static_cast<int>(p_ricordi.size() / 5);
	ERR_FAIL_COND_V_MSG(n > chibi::MAX_FATTI, d,
			"EcsMondo.debug_occ: un grafo non tiene piu di MAX_FATTI ricordi.");
	ERR_FAIL_COND_V_MSG(p_gusto.size() != chibi::N_COSE, d,
			"EcsMondo.debug_occ: serve un gusto per cosa.");

	chibi::GrafoRicordi g;
	for (int i = 0; i < n; i++) {
		const int v = static_cast<int>(p_ricordi[i * 5 + 0]);
		ERR_FAIL_COND_V_MSG(v < 0 || v >= chibi::N_VERBI, d,
				"EcsMondo.debug_occ: verbo fuori tabella.");
		chibi::Ricordo r;
		r.verbo = static_cast<uint8_t>(v);
		// la `cosa` NON si passa: la decide la tabella unica, come fa
		// `inserisci()`. Un oracolo che permettesse una coppia impossibile
		// proverebbe un grafo che il gioco non può produrre.
		r.cosa = chibi::COSA_DEL_VERBO[v];
		r.bandiere = static_cast<uint8_t>(static_cast<int>(p_ricordi[i * 5 + 1]) & 0xFF);
		r.quante = static_cast<uint8_t>(static_cast<int>(p_ricordi[i * 5 + 2]) & 0xFF);
		r.intensita = static_cast<uint8_t>(static_cast<int>(p_ricordi[i * 5 + 3]) & 0xFF);
		r.quando = static_cast<float>(p_ricordi[i * 5 + 4]);
		g.f[i] = r;
	}
	g.n = static_cast<uint8_t>(n);

	chibi::Gusto gu;
	for (int c = 0; c < chibi::N_COSE; c++) {
		gu.per_cosa[c] = p_gusto[c];
	}

	// la taratura è FACOLTATIVA campo per campo: quel che non si dice resta
	// quello del gioco, così un test che muove una manopola non si porta
	// dietro le altre tre per sbaglio.
	chibi::TaraturaOcc tar;
	tar.mezza_vita = static_cast<double>(p_taratura.get("mezza_vita", tar.mezza_vita));
	tar.peso_sentito = static_cast<double>(p_taratura.get("peso_sentito", tar.peso_sentito));
	tar.k_satura = static_cast<double>(p_taratura.get("k_satura", tar.k_satura));
	tar.k_ammirazione = static_cast<double>(p_taratura.get("k_ammirazione", tar.k_ammirazione));

	const chibi::Tinte t = chibi::valuta(g, gu, static_cast<float>(p_ora), tar);
	double mod[chibi::N_AZIONI];
	chibi::modulatori(t, tar, mod);

	PackedFloat64Array interesse;
	interesse.resize(chibi::N_COSE);
	for (int c = 0; c < chibi::N_COSE; c++) {
		interesse[c] = t.interesse[c];
	}
	PackedFloat64Array pmod;
	pmod.resize(chibi::N_AZIONI);
	for (int a = 0; a < chibi::N_AZIONI; a++) {
		pmod[a] = mod[a];
	}
	PackedInt32Array cdv;
	cdv.resize(chibi::N_VERBI);
	for (int v = 0; v < chibi::N_VERBI; v++) {
		cdv[v] = static_cast<int32_t>(chibi::COSA_DEL_VERBO[v]);
	}

	d["ammirazione"] = t.ammirazione;
	d["gratitudine"] = t.gratitudine;
	d["interesse"] = interesse;
	d["mod"] = pmod;
	// LE COSTANTI TORNANO DI QUA, e non è cortesia: un test che scrive «2» per
	// R_SU_DI_ME resta verde il giorno che le bandiere cambiano valore. Qui il
	// numero viene sempre e solo dall'enum.
	d["cosa_del_verbo"] = cdv;
	d["sentito"] = static_cast<int>(chibi::R_SENTITO);
	d["su_di_me"] = static_cast<int>(chibi::R_SU_DI_ME);
	d["detto"] = static_cast<int>(chibi::R_DETTO);
	d["max_fatti"] = chibi::MAX_FATTI;
	d["n_cose"] = static_cast<int>(chibi::N_COSE);
	d["n_verbi"] = static_cast<int>(chibi::N_VERBI);
	return d;
}

void EcsMondo::debug_tara_agenda(double p_t_min, double p_bonus, double p_margine, double p_tetto) {
	ERR_FAIL_NULL(_reg);
	_reg->tar.t_min = p_t_min;
	_reg->tar.bonus = p_bonus;
	_reg->tar.margine = p_margine;
	_reg->tar.tetto_impegno = p_tetto;
}

int EcsMondo::stato(int64_t p_id) const {
	ERR_FAIL_COND_V(!conosce(p_id), -1);
	return static_cast<int>(_reg->reg.get<chibi::StatoComponent>(da_handle(p_id)).stato);
}

double EcsMondo::da_quanto(int64_t p_id) const {
	ERR_FAIL_COND_V(!conosce(p_id), -1.0);
	return _reg->reg.get<chibi::StatoComponent>(da_handle(p_id)).da;
}

bool EcsMondo::in_finestra(int64_t p_id) const {
	ERR_FAIL_COND_V(!conosce(p_id), false);
	// la finestra la sa il SISTEMA, non il chiamante: se `in_finestra`
	// accettasse un'ora, chi chiama potrebbe passarne una sua e avremmo due
	// verità sulla stessa domanda. Qui si usa l'ora dell'ultimo passo.
	const chibi::DnaComponent &dna = _reg->reg.get<chibi::DnaComponent>(da_handle(p_id));
	return chibi::finestra_di_sonno(dna.indole, dna.quirk, _ultima_ora);
}

bool EcsMondo::debug_in_finestra(int p_maschera, int p_quirk, double p_ora) const {
	return chibi::finestra_di_sonno(static_cast<uint32_t>(p_maschera),
			static_cast<int32_t>(p_quirk), p_ora);
}

Dictionary EcsMondo::debug_entita(int64_t p_id) const {
	Dictionary d;
	ERR_FAIL_COND_V(!conosce(p_id), d);
	const entt::entity e = da_handle(p_id);
	const chibi::DnaComponent &dna = _reg->reg.get<chibi::DnaComponent>(e);
	const chibi::StatoComponent &st = _reg->reg.get<chibi::StatoComponent>(e);
	const chibi::MondoComponent &mo = _reg->reg.get<chibi::MondoComponent>(e);
	d["stato"] = static_cast<int>(st.stato);
	d["da"] = st.da;
	d["in_finestra"] = chibi::finestra_di_sonno(dna.indole, dna.quirk, _ultima_ora);
	d["nascosto"] = mo.nascosto;
	d["corpo_libero"] = mo.corpo_libero;
	d["porta_aperta"] = mo.porta_aperta;
	d["indole"] = static_cast<int>(dna.indole);
	d["quirk"] = static_cast<int>(dna.quirk);
	// NESSUN nome, NESSUNA etichetta: il ponte non è un'anagrafe
	return d;
}

int EcsMondo::debug_quante_pose() const {
	if (_reg == nullptr) {
		return 0;
	}
	int n = 0;
	for (const entt::entity e : _reg->reg.view<chibi::TransformComponent>()) {
		(void)e;
		n++;
	}
	return n;
}


// --- FASE 3: il pianificatore ------------------------------------------

PackedInt32Array EcsMondo::pianifica(int p_stato, int p_obiettivo,
		const PackedFloat64Array &p_cammino) const {
	PackedInt32Array out;
	ERR_FAIL_NULL_V(_reg, out);
	ERR_FAIL_COND_V_MSG(p_cammino.size() != chibi::N_LUOGHI, out,
			"EcsMondo.pianifica: servono cinque tempi di cammino.");
	double c[chibi::N_LUOGHI];
	for (int i = 0; i < chibi::N_LUOGHI; i++) {
		c[i] = p_cammino[i];
	}
	const chibi::EsitoPiano e = chibi::pianifica(static_cast<uint32_t>(p_stato),
			static_cast<uint32_t>(p_obiettivo), c, _reg->tar_piani);
	out.resize(e.n);
	for (int i = 0; i < e.n; i++) {
		out[i] = e.passi[i];
	}
	return out;
}

int EcsMondo::indice_operatore(const String &p_nome) const {
	const int n = static_cast<int>(sizeof(OPERATORI) / sizeof(OPERATORI[0]));
	for (int i = 0; i < n; i++) {
		if (p_nome == String(OPERATORI[i])) {
			return i;
		}
	}
	return chibi::OP_NESSUNO;
}

int EcsMondo::maschera_obiettivo(const String &p_nome) const {
	const int n = static_cast<int>(sizeof(OBIETTIVI) / sizeof(OBIETTIVI[0]));
	for (int i = 0; i < n; i++) {
		if (p_nome == String(OBIETTIVI[i])) {
			return static_cast<int>(1u << (24 + i));
		}
	}
	return 0;
}

Dictionary EcsMondo::debug_piano(int p_stato, int p_obiettivo,
		const PackedFloat64Array &p_cammino) const {
	Dictionary d;
	ERR_FAIL_NULL_V(_reg, d);
	ERR_FAIL_COND_V_MSG(p_cammino.size() != chibi::N_LUOGHI, d,
			"EcsMondo.debug_piano: servono cinque tempi di cammino.");
	double c[chibi::N_LUOGHI];
	for (int i = 0; i < chibi::N_LUOGHI; i++) {
		c[i] = p_cammino[i];
	}
	const chibi::EsitoPiano e = chibi::pianifica(static_cast<uint32_t>(p_stato),
			static_cast<uint32_t>(p_obiettivo), c, _reg->tar_piani);
	PackedInt32Array passi;
	passi.resize(e.n);
	for (int i = 0; i < e.n; i++) {
		passi[i] = e.passi[i];
	}
	d["passi"] = passi;
	d["costo"] = e.costo;
	d["nodi"] = e.nodi;
	d["esito"] = e.esito;
	return d;
}

Dictionary EcsMondo::debug_operatore(int p_id) const {
	Dictionary d;
	ERR_FAIL_COND_V(p_id < 0 || p_id >= chibi::N_OPERATORI, d);
	const chibi::OperatoreDef &o = chibi::operatori()[p_id];
	d["luogo"] = o.luogo;
	d["richiede"] = static_cast<int>(o.richiede);
	d["vieta"] = static_cast<int>(o.vieta);
	d["aggiunge"] = static_cast<int>(o.aggiunge);
	d["toglie"] = static_cast<int>(o.toglie);
	d["costo"] = o.costo_base;
	return d;
}

void EcsMondo::debug_tara_piani(double p_budget, int p_max_nodi, int p_max_prof) {
	ERR_FAIL_NULL(_reg);
	_reg->tar_piani.budget_secondi = p_budget;
	_reg->tar_piani.max_nodi = p_max_nodi;
	_reg->tar_piani.max_profondita = p_max_prof;
}

// --- FASE 4 (P1): il grafo dei ricordi ---------------------------------
//
// Quattro oracoli CONST e SENZA entità. Chiamano le funzioni VERE
// (`chibi::inserisci`, `chibi::peso`, `chibi::da_raccontare`), mai una
// scorciatoia scritta per il test: una prova che aggira il codice nuovo non
// prova niente, ed è la lezione già pagata due volte in Fase 1.

Dictionary EcsMondo::debug_grafo_inserisci(const Dictionary &p_grafo,
		const Dictionary &p_ricordo, double p_ora, double p_mezza_vita) const {
	chibi::GrafoRicordi g = grafo_da(p_grafo);
	const chibi::Ricordo r = ricordo_da(p_ricordo);
	const int i = chibi::inserisci(g, r, static_cast<float>(p_ora), p_mezza_vita);
	Dictionary out;
	out["grafo"] = da_grafo(g);
	// -1 = non ha scritto niente. Torna sempre, e il test lo guarda: un
	// ricordo perso in silenzio è ciò che questa uscita esiste per mostrare.
	out["indice"] = i;
	return out;
}

double EcsMondo::debug_grafo_peso(const Dictionary &p_ricordo, double p_ora,
		double p_mezza_vita) const {
	const chibi::Ricordo r = ricordo_da(p_ricordo);
	return chibi::peso(r, static_cast<float>(p_ora), p_mezza_vita);
}

int EcsMondo::debug_grafo_da_raccontare(const Dictionary &p_grafo, double p_ora,
		double p_mezza_vita) const {
	const chibi::GrafoRicordi g = grafo_da(p_grafo);
	return chibi::da_raccontare(g, static_cast<float>(p_ora), p_mezza_vita);
}

Dictionary EcsMondo::debug_grafo_costanti() const {
	Dictionary d;
	d["max_fatti"] = chibi::MAX_FATTI;
	d["finestra_fusione"] = chibi::FINESTRA_FUSIONE;
	d["n_verbi"] = static_cast<int>(chibi::N_VERBI);
	d["n_cose"] = static_cast<int>(chibi::N_COSE);
	d["sogg_nessuno"] = static_cast<int64_t>(chibi::SOGG_NESSUNO);
	d["r_sentito"] = static_cast<int>(chibi::R_SENTITO);
	d["r_su_di_me"] = static_cast<int>(chibi::R_SU_DI_ME);
	d["r_detto"] = static_cast<int>(chibi::R_DETTO);
	d["byte_ricordo"] = static_cast<int>(sizeof(chibi::Ricordo));
	// LA CURVA DELLE RIPETIZIONI, cosi il test non ne scrive nemmeno un
	// numero a mano: `1 + rip_tetto·(q-1)/((q-1)+rip_mezza)`. Chi la tara
	// fa muovere il test, invece di farlo mentire.
	d["rip_tetto"] = chibi::RIP_TETTO;
	d["rip_mezza"] = chibi::RIP_MEZZA;
	PackedInt32Array cdv;
	cdv.resize(static_cast<int>(chibi::N_VERBI));
	for (int i = 0; i < static_cast<int>(chibi::N_VERBI); i++) {
		cdv[i] = static_cast<int>(chibi::COSA_DEL_VERBO[i]);
	}
	d["cosa_del_verbo"] = cdv;
	return d;
}

int EcsMondo::indice_verbo(const String &p_nome) const {
	const int n = static_cast<int>(sizeof(VERBI) / sizeof(VERBI[0]));
	for (int i = 0; i < n; i++) {
		if (p_nome == String(VERBI[i])) {
			return i;
		}
	}
	// un verbo ignoto vale -1 e basta: qui non si alza la voce, perché è il
	// TEST che deve accorgersi di una tabella divergente, non il gioco del
	// giocatore (stessa scelta di `maschera_indole`).
	return -1;
}

int EcsMondo::indice_cosa(const String &p_nome) const {
	const int n = static_cast<int>(sizeof(COSE) / sizeof(COSE[0]));
	for (int i = 0; i < n; i++) {
		if (p_nome == String(COSE[i])) {
			return i;
		}
	}
	return -1;
}

String EcsMondo::nome_verbo(int p_verbo) const {
	const int n = static_cast<int>(sizeof(VERBI) / sizeof(VERBI[0]));
	if (p_verbo < 0 || p_verbo >= n) {
		return String();
	}
	return String(VERBI[p_verbo]);
}

String EcsMondo::nome_cosa(int p_cosa) const {
	const int n = static_cast<int>(sizeof(COSE) / sizeof(COSE[0]));
	if (p_cosa < 0 || p_cosa >= n) {
		return String();
	}
	return String(COSE[p_cosa]);
}

// --- FASE 4 (P4-P5): il grafo vivo, e il pettegolezzo ------------------

int EcsMondo::osserva(int64_t p_id, int p_verbo, const Vector3 &p_dove, int64_t p_soggetto) {
	ERR_FAIL_NULL_V(_reg, -1);
	ERR_FAIL_COND_V_MSG(!conosce(p_id), -1, "EcsMondo.osserva: handle sconosciuto.");
	// Un verbo fuori tabella si RIFIUTA e lo si dice. `inserisci()` lo
	// rifiuterebbe comunque, ma in silenzio: qui il chiamante e il bus della
	// percezione, che traduce una parola in un indice, e una parola sbagliata
	// di la deve diventare un errore visibile e non un gesto che non e mai
	// stato visto da nessuno.
	ERR_FAIL_COND_V_MSG(p_verbo < 0 || p_verbo >= static_cast<int>(chibi::N_VERBI), -1,
			"EcsMondo.osserva: verbo fuori tabella.");

	chibi::GrafoComponent &gc = _reg->reg.get<chibi::GrafoComponent>(da_handle(p_id));

	chibi::Ricordo r;
	r.verbo = static_cast<uint8_t>(p_verbo);
	// la `cosa` la posa comunque `inserisci()` dalla tabella unica; scriverla
	// anche qui non e un secondo dato, e la stessa riga letta due volte.
	r.cosa = chibi::COSA_DEL_VERBO[p_verbo];
	r.soggetto = (p_soggetto >= 0)
			? static_cast<uint32_t>(static_cast<uint64_t>(p_soggetto))
			: chibi::SOGG_NESSUNO;
	// R_SU_DI_ME SI DERIVA, non si dichiara: «l'ha fatto a me» e vero se e
	// solo se il destinatario del gesto sono io. Un booleano a parte sarebbe
	// un secondo modo di dire la stessa cosa — cioe la possibilita di dirla
	// diversa, e un vicino che si prende la gratitudine di un regalo fatto a
	// un altro e un guasto che nessuno vedrebbe mai.
	r.bandiere = (p_soggetto >= 0 && p_soggetto == p_id)
			? static_cast<uint8_t>(chibi::R_SU_DI_ME)
			: static_cast<uint8_t>(0);
	r.quante = 1;
	// CHI VEDE CON I PROPRI OCCHI VEDE AL MASSIMO. L'intensita non e un
	// parametro perche non c'e nessuno che avrebbe un secondo valore da
	// passarle: l'unica cosa che smorza, in tutta la fase, e il passaparola.
	r.intensita = 255;
	r.px = static_cast<float>(p_dove.x);
	r.pz = static_cast<float>(p_dove.z);

	return chibi::inserisci(gc.g, r, static_cast<float>(_tempo), _reg->tar_occ.mezza_vita);
}

int EcsMondo::racconta(int64_t p_a, int64_t p_b, double p_smorzamento) {
	ERR_FAIL_NULL_V(_reg, -1);
	// Non ci si racconta niente da soli, e non e un caso di scuola: a
	// `_run_chat` una coppia arriva da due cicli annidati, e un giorno che
	// gli indici sbagliassero, uno che si racconta una notizia a se stesso se
	// la marchierebbe R_DETTO — perdendola per tutti gli altri, in silenzio.
	if (p_a == p_b) {
		return -1;
	}
	ERR_FAIL_COND_V_MSG(!conosce(p_a), -1, "EcsMondo.racconta: chi parla e sconosciuto.");
	ERR_FAIL_COND_V_MSG(!conosce(p_b), -1, "EcsMondo.racconta: chi ascolta e sconosciuto.");

	chibi::GrafoComponent &ga = _reg->reg.get<chibi::GrafoComponent>(da_handle(p_a));
	chibi::GrafoComponent &gb = _reg->reg.get<chibi::GrafoComponent>(da_handle(p_b));

	const float ora = static_cast<float>(_tempo);
	const double mv = _reg->tar_occ.mezza_vita;

	// COSA SA GIA B. Una maschera di verbi, e si guardano TUTTI i suoi
	// ricordi — anche quelli che a sua volta ha solo sentito dire. Se una
	// notizia gli e gia arrivata, ripassargliela non e un pettegolezzo: e un
	// doppione nel suo grafo, che pesa due volte e gli occupa due righe delle
	// ventiquattro.
	//
	// MA UN RICORDO SPENTO NON E CONOSCENZA, ed e la porta che il ritimbro
	// dell'eco ha aperto: da quando l'intensita dell'eco porta anche il
	// freddo che il ricordo ha gia preso (vedi sotto), una voce arrivata
	// molto tardi entra nel grafo di B a intensita ZERO. Senza questa
	// riga quella riga morta gli TAPPEREBBE quel verbo per sempre: chi
	// avesse visto la cosa fresca non potrebbe piu raccontargliela, e la
	// notizia vera resterebbe fuori per colpa di una che non pesa niente.
	// `!(peso > 0)` prende zero, negativi e NaN, come ovunque qui.
	uint32_t saputi = 0;
	const int nb = (gb.g.n < chibi::MAX_FATTI) ? static_cast<int>(gb.g.n) : chibi::MAX_FATTI;
	for (int i = 0; i < nb; i++) {
		const uint8_t v = gb.g.f[i].verbo;
		if (v >= chibi::N_VERBI) {
			continue;
		}
		if (!(chibi::peso(gb.g.f[i], ora, mv) > 0.0)) {
			continue;
		}
		saputi |= (1u << v);
	}

	const int i = chibi::da_raccontare(ga.g, ora, mv, saputi);
	if (i < 0) {
		// IL SILENZIO E IL COMPORTAMENTO NORMALE, ed e importante che qui non
		// succeda proprio NIENTE: nessun marchio, nessuna versione che sale.
		// La notizia resta in tasca per il prossimo che non la sa — se
		// bruciasse qui, basterebbe incontrare per primo qualcuno che l'ha
		// gia sentita perche non la sapesse piu nessun altro.
		return -1;
	}

	// L'UNICO PINZAGGIO, e sta QUI perche qui c'e la REGOLA: una voce non
	// puo mai pesare piu dell'averlo visto con i propri occhi, e non puo
	// pesare meno di niente.
	//  · `!(sm > 0.0)` prende lo zero, i negativi E i NaN (ogni confronto con
	//    un NaN e falso, quindi la negazione e vera). Il NaN conta: senza,
	//    `static_cast<int>(NaN)` e comportamento indefinito.
	//  · `sm > 1.0` e la gerarchia fra «l'ho visto» e «me l'hanno detto», che
	//    e la sola cosa che tiene il pettegolezzo un pettegolezzo invece di
	//    un megafono.
	// Con `sm` in [0,1] e `orig.intensita` in [0,255] per tipo, il prodotto
	// piu mezzo sta in [0, 255]: NON serve una seconda rete piu in giu, e
	// averla non era gratis — l'ho misurato. Con tutte e due, togliere
	// QUESTA restava verde (la seconda pinzava lo stesso), cioe la regola
	// del megafono non era piu falsificabile: una guardia che nessun test
	// puo smentire e una promessa che non si sa se e vera.
	double sm = p_smorzamento;
	if (!(sm > 0.0)) {
		sm = 0.0;
	} else if (sm > 1.0) {
		sm = 1.0;
	}

	const chibi::Ricordo &orig = ga.g.f[i];
	const int cosa = static_cast<int>(orig.cosa);

	chibi::Ricordo eco;
	eco.verbo = orig.verbo;
	eco.cosa = orig.cosa;
	// L'UNICA COSA FUORI POSTO, e sta tutta in questa riga: chi ascolta sa
	// che qualcuno ha ricevuto un regalo, non CHI. Il verbo, la cosa e il
	// luogo passano intatti apposta — se si deformasse anche uno di quelli,
	// la nuvoletta in fondo alla catena non significherebbe piu niente, e un
	// pettegolezzo che non significa niente e rumore.
	eco.soggetto = chibi::SOGG_NESSUNO;
	// R_SU_DI_ME non passa MAI: un regalo fatto ad A non e un regalo fatto a
	// B, e la gratitudine non si trasmette a voce. R_DETTO nemmeno: B non ha
	// raccontato niente a nessuno.
	eco.bandiere = static_cast<uint8_t>(chibi::R_SENTITO);
	// `quante` passa: «l'ho visto annaffiare tutto il pomeriggio» e parte
	// della notizia. E cosi il rapporto fra il peso del sentito e quello del
	// visto e esattamente lo smorzamento, che e una cosa che si puo misurare.
	eco.quante = orig.quante;
	// LA SMORZATURA STA NEL DATO, e si vede: dopo un racconto `debug_grafo`
	// mostra un'intensita piu bassa. (E per questo che la lettura non smorza
	// piu niente — vedi il commento nel costruttore di Registro: applicarla
	// tutte e due le volte farebbe 0.30 invece di 0.55, in silenzio.)
	// L'arrotondamento e al piu vicino, non per troncamento: 255 e 0.55 danno
	// 140.25, e buttare via un quarto di punto per pigrizia su un canale che
	// il giocatore percepisce come «piu fioco» e proprio il genere di
	// sciatteria che si accumula.
	//
	// ⚠️ E CI VA ANCHE IL FREDDO CHE IL RICORDO HA GIA PRESO (`sconto_tempo`).
	// Senza quel fattore la regola dichiarata qui sopra, in `sistema_occ` e
	// in `grafo_ricordi` — «una voce non puo mai pesare piu dell'averlo visto
	// con i propri occhi» — era vera SOLO NELL'ISTANTE del racconto: lo
	// smorzamento stava nell'intensita, ma il tempo si RITIMBRAVA
	// (`inserisci` scrive sempre `p_ora`), quindi la voce ripartiva da capo
	// mentre il testimone continuava a dimenticare. MISURATO, con mezza vita
	// 120 s: raccontata subito B/A = 0.55; raccontata dopo 104 s PAREGGIO;
	// dopo 300 s B pesa 3,1 volte A; dopo 1200 s **562 volte**. La scena era
	// questa: A ti vede annaffiare, e venti minuti di gioco dopo ha dimenticato;
	// proprio allora incrocia B, e B — CHE NON C'ERA — si ritrova sopra
	// soglia con la posizione esatta dell'aiuola e ci va. Era anche l'unico
	// modo in cui un fatto sopravviveva alla mezza vita dichiarata.
	// Col fattore, l'eco nasce gia raffreddata e da li in poi decade come
	// l'originale: **B(t) = smorzamento · A(t) per SEMPRE**, non solo
	// nell'istante. Il rapporto e costante e si misura.
	eco.intensita = static_cast<uint8_t>(
			static_cast<int>(static_cast<double>(orig.intensita)
					* chibi::sconto_tempo(orig, ora, mv) * sm + 0.5));
	eco.px = orig.px;
	eco.pz = orig.pz;

	// Il ricordo di B nasce ADESSO (`inserisci` timbra sempre `p_ora`): non
	// eredita il tempo di chi l'ha visto. Un ricordo antidatato peserebbe gia
	// meno del dovuto — e nella catena lunga non si potrebbe piu potare.
	chibi::inserisci(gb.g, eco, ora, mv);

	// A L'HA RACCONTATA. Il marchio si mette QUI, dove il racconto accade, e
	// non dentro `da_raccontare` (che e una domanda, e una domanda non deve
	// cambiare niente): e la stessa regola per cui la sazieta si paga quando
	// il gesto accade, non quando viene scelto.
	//
	// La versione sale anche se `bandiere` non tocca nessuna tinta: il
	// contratto e «il grafo e cambiato ⇒ la versione e cambiata», e tenerlo
	// vero costa una rivalutazione ogni tanto — mentre romperlo costa un
	// modulatore stantio che nessuno sa spiegare.
	ga.g.f[i].bandiere = static_cast<uint8_t>(ga.g.f[i].bandiere | chibi::R_DETTO);
	ga.g.versione++;

	// SI TORNA LA COSA, non l'esito dell'inserimento in B. Il racconto e un
	// gesto di A: A l'ha detto, e il simbolo esce dalla sua nuvoletta anche
	// nel caso raro in cui il grafo di B fosse pieno di ricordi piu forti e
	// se la lasciasse scivolare via. Quel caso si vede da `debug_grafo(b)`,
	// non lo si nasconde.
	return cosa;
}

void EcsMondo::riferisci_gusto(int64_t p_id, const PackedFloat64Array &p_gusto) {
	ERR_FAIL_NULL(_reg);
	ERR_FAIL_COND_MSG(!conosce(p_id), "EcsMondo.riferisci_gusto: handle sconosciuto.");
	ERR_FAIL_COND_MSG(p_gusto.size() != chibi::N_COSE,
			"EcsMondo.riferisci_gusto: serve un gusto per cosa.");
	const entt::entity e = da_handle(p_id);
	chibi::GustoComponent &g = _reg->reg.get<chibi::GustoComponent>(e);
	chibi::EmozioniComponent &emo = _reg->reg.get<chibi::EmozioniComponent>(e);
	bool cambiato = false;
	for (int c = 0; c < chibi::N_COSE; c++) {
		const double v = p_gusto[c];
		if (g.gu.per_cosa[c] != v) {
			g.gu.per_cosa[c] = v;
			cambiato = true;
		}
	}
	// IL GUSTO E L'ALTRO INGRESSO DELLA LETTURA, e il latch guarda solo il
	// grafo: senza questa riga, il salone di bellezza (o `debug_quirk`)
	// cambierebbe il carattere di un vicino e il suo cuore continuerebbe a
	// usare il modulatore di prima fino al gradino dopo. Si invalida solo se
	// e cambiato QUALCOSA — il cablaggio confronta e riproietta a ogni
	// campionamento dei fatti, e una invalidazione incondizionata qui
	// annullerebbe il gradino trenta volte al secondo.
	if (cambiato) {
		emo.vista = chibi::VISTA_MAI;
	}
}

void EcsMondo::imposta_ritmo(double p_ciclo_secondi) {
	ERR_FAIL_NULL(_reg);
	// Un ciclo nullo o negativo non si «aggiusta» pinzandolo: vorrebbe dire
	// accettare in silenzio un DayNight rotto e proseguire con una mezza vita
	// inventata. Si rifiuta, si dice, e la taratura resta quella di prima —
	// che e sempre un numero sensato.
	ERR_FAIL_COND_MSG(!(p_ciclo_secondi > 0.0),
			"EcsMondo.imposta_ritmo: il ciclo del giorno deve durare piu di zero secondi.");
	// MEZZA GIORNATA DI GIOCO. Si DERIVA: riscrivere 120 da qualche altra
	// parte e il modo in cui i due numeri divorziano.
	_reg->tar_occ.mezza_vita = p_ciclo_secondi * 0.5;
}

// --- FASE 4 (P6): le tre letture vive ----------------------------------

double EcsMondo::ammirazione(int64_t p_id) const {
	// Zero e non un errore: chiedere di un vicino che non c'e piu deve
	// rispondere «non ti ammira», non far saltare il ramo che sta decidendo
	// dove sedersi. Il degrado va verso il comportamento di sempre.
	ERR_FAIL_COND_V(!conosce(p_id), 0.0);
	const entt::entity e = da_handle(p_id);
	// SI LEGGE ADESSO, non si prende dal latch. Il `mod` dell'agenda e di un
	// gradino fa apposta (un numero che sta fermo mentre lo si usa), ma qui
	// non c'e nessuna decisione a cui scivolerebbe sotto: c'e una domanda
	// sola, fatta una volta, nel frame in cui un vicino sceglie di riposare.
	// E soprattutto: leggere il latch vorrebbe dire far dipendere una scena
	// dal fatto che `avanza()` sia gia girato, cioe da un ordine.
	const chibi::Tinte t = chibi::valuta(
			_reg->reg.get<chibi::GrafoComponent>(e).g,
			_reg->reg.get<chibi::GustoComponent>(e).gu,
			static_cast<float>(_tempo), _reg->tar_occ);
	return t.ammirazione;
}

Vector3 EcsMondo::dove(int64_t p_id, int p_cosa, double p_soglia,
		const Vector3 &p_se_niente) const {
	ERR_FAIL_COND_V(!conosce(p_id), p_se_niente);
	// Una `cosa` fuori tabella non e un caso di degrado, e un errore di
	// cablaggio: si dice. (Il ripiego torna lo stesso, cosi il chiamante non
	// si ritrova un corpo mandato all'origine del mondo.)
	ERR_FAIL_COND_V_MSG(p_cosa < 0 || p_cosa >= static_cast<int>(chibi::N_COSE),
			p_se_niente, "EcsMondo.dove: cosa fuori tabella.");

	const chibi::GrafoRicordi &g =
			_reg->reg.get<chibi::GrafoComponent>(da_handle(p_id)).g;
	const int n = (g.n < chibi::MAX_FATTI) ? static_cast<int>(g.n) : chibi::MAX_FATTI;
	const float ora = static_cast<float>(_tempo);

	// IL PAVIMENTO, e non e un ornamento: e la riga per cui un'ancora
	// spostata TORNA A CASA.
	//
	// `migliore` partiva da zero, cioe da «qualunque peso maggiore di zero
	// va bene» — e 2^(-dt/mv) non arriva a zero prima di **~1074 mezze
	// vite** (trentasei ore di gioco). Misurato: un solo gesto visto da un
	// vicino gli spostava l'ancora, e trenta giornate dopo — con
	// l'ammirazione scesa a 0.000000 — l'ancora era ancora spostata. In
	// partita voleva dire: posi UN palo di staccionata mentre qualcuno ti
	// guarda, e da li in poi, per tutta la sessione, quel vicino ignora la
	// panchina a tre metri da casa sua. E' la «conseguenza senza premessa»
	// che questa fase esiste per rendere impossibile, ed e anche la seconda
	// smentita della riga «l'emozione dura minuti e non lascia traccia».
	//
	// LA SOGLIA ARRIVA DAL CHIAMANTE, come `p_smorzamento` in `racconta` e
	// `p_soglia` in `cosa_da_ricordare`: quanto a lungo un gesto deve
	// contare e una decisione di GIOCO, e le decisioni di gioco stanno dove
	// si leggono (`Visitors.AMMIRA_SOGLIA`). Zero riproduce esattamente il
	// comportamento di prima, ed e cosi che il test lo puo falsificare.
	//
	// `!(soglia > 0)` prende zero, negativi E NaN: una taratura assurda
	// dall'altra parte del ponte degrada verso «nessun pavimento», mai
	// verso «nessun ricordo indica piu niente».
	double migliore = p_soglia;
	if (!(migliore > 0.0)) {
		migliore = 0.0;
	}

	// A PARITA VINCE L'INDICE PIU BASSO, come in `da_raccontare`: nessun dado,
	// mai. Due ricordi identici a pari peso devono mandare due vicini nello
	// stesso posto, o la scena 4 diventa una monetina.
	int scelto = -1;
	for (int i = 0; i < n; i++) {
		if (g.f[i].cosa != static_cast<uint8_t>(p_cosa)) {
			continue;
		}
		const double w = chibi::peso(g.f[i], ora, _reg->tar_occ.mezza_vita);
		// `> migliore` prende anche il caso di un ricordo spento (peso 0 o
		// NaN): un ricordo che non pesa piu niente non ha piu un posto da
		// indicare.
		if (w > migliore) {
			migliore = w;
			scelto = i;
		}
	}
	if (scelto < 0) {
		return p_se_niente;
	}
	// La `y` NON si conserva nel ricordo (24 byte, e il villaggio e piatto
	// dove si cammina): si torna quella del ripiego, che e il piano su cui il
	// chiamante sta ragionando. Inventare uno zero manderebbe sottoterra chi
	// ragiona su una casa sull'albero.
	return Vector3(g.f[scelto].px, p_se_niente.y, g.f[scelto].pz);
}

int EcsMondo::cosa_da_ricordare(int64_t p_id, double p_soglia) const {
	ERR_FAIL_COND_V(!conosce(p_id), -1);
	const chibi::GrafoRicordi &g =
			_reg->reg.get<chibi::GrafoComponent>(da_handle(p_id)).g;
	const int n = (g.n < chibi::MAX_FATTI) ? static_cast<int>(g.n) : chibi::MAX_FATTI;
	const float ora = static_cast<float>(_tempo);

	double migliore = 0.0;
	int scelto = -1;
	for (int i = 0; i < n; i++) {
		// SOLO QUELLO CHE HO VISTO IO. Vedi il commento in ecs_mondo.h: una
		// voce non diventa un ricordo permanente.
		if ((g.f[i].bandiere & chibi::R_SENTITO) != 0) {
			continue;
		}
		if (g.f[i].cosa >= chibi::N_COSE) {
			continue;
		}
		const double w = chibi::peso(g.f[i], ora, _reg->tar_occ.mezza_vita);
		if (w > migliore) {
			migliore = w;
			scelto = i;
		}
	}
	// `!(migliore > p_soglia)` e non `<=`: prende anche il NaN, che altrimenti
	// passerebbe (ogni confronto con un NaN e falso). Un ricordo corrotto non
	// deve poter diventare l'unica cosa che sopravvive a un riavvio.
	if (scelto < 0 || !(migliore > p_soglia)) {
		return -1;
	}
	return static_cast<int>(g.f[scelto].cosa);
}

Dictionary EcsMondo::debug_grafo(int64_t p_id) const {
	Dictionary d;
	ERR_FAIL_COND_V(!conosce(p_id), d);
	return da_grafo(_reg->reg.get<chibi::GrafoComponent>(da_handle(p_id)).g);
}

Dictionary EcsMondo::debug_emozioni(int64_t p_id) const {
	Dictionary d;
	ERR_FAIL_COND_V(!conosce(p_id), d);
	const entt::entity e = da_handle(p_id);
	const chibi::EmozioniComponent &emo = _reg->reg.get<chibi::EmozioniComponent>(e);
	const chibi::GrafoComponent &gr = _reg->reg.get<chibi::GrafoComponent>(e);
	const chibi::GustoComponent &gu = _reg->reg.get<chibi::GustoComponent>(e);

	// --- IL LATCH: quel che l'agenda sta usando ADESSO, e da quando.
	PackedFloat64Array pmod;
	pmod.resize(chibi::N_AZIONI);
	for (int a = 0; a < chibi::N_AZIONI; a++) {
		pmod[a] = emo.mod[a];
	}
	PackedFloat64Array pgusto;
	pgusto.resize(chibi::N_COSE);
	for (int c = 0; c < chibi::N_COSE; c++) {
		pgusto[c] = gu.gu.per_cosa[c];
	}
	d["mod"] = pmod;
	d["gusto"] = pgusto;
	d["vista"] = static_cast<int64_t>(emo.vista);
	d["t_valutato"] = static_cast<double>(emo.t_valutato);
	d["versione"] = static_cast<int64_t>(gr.g.versione);
	d["ricordi"] = static_cast<int>(gr.g.n);

	// --- LA LETTURA ADESSO, che e un'altra cosa e puo legittimamente non
	// combaciare col latch: il `mod` e di un gradino fa. Tenerle separate e
	// l'unico modo di poter PROVARE il gradino — se `debug_emozioni`
	// ricalcolasse anche il mod, il test del ritmo misurerebbe se stesso.
	const chibi::Tinte t = chibi::valuta(gr.g, gu.gu, static_cast<float>(_tempo), _reg->tar_occ);
	PackedFloat64Array pint;
	pint.resize(chibi::N_COSE);
	for (int c = 0; c < chibi::N_COSE; c++) {
		pint[c] = t.interesse[c];
	}
	d["ammirazione"] = t.ammirazione;
	d["gratitudine"] = t.gratitudine;
	d["interesse"] = pint;
	return d;
}

Dictionary EcsMondo::debug_ritmo() const {
	Dictionary d;
	ERR_FAIL_NULL_V(_reg, d);
	d["passo_emo"] = chibi::PASSO_EMO;
	d["mezza_vita"] = _reg->tar_occ.mezza_vita;
	d["peso_sentito"] = _reg->tar_occ.peso_sentito;
	d["k_satura"] = _reg->tar_occ.k_satura;
	d["k_ammirazione"] = _reg->tar_occ.k_ammirazione;
	// non e una costante, e sta qui lo stesso: e l'orologio con cui tutti i
	// numeri di sopra vanno letti, e un test che se lo ricostruisse
	// sommando i delta terrebbe una seconda contabilita del tempo.
	d["tempo"] = _tempo;
	return d;
}

int EcsMondo::debug_grafo_novita(const Dictionary &p_grafo, double p_ora,
		double p_mezza_vita, int p_gia_saputi) const {
	const chibi::GrafoRicordi g = grafo_da(p_grafo);
	return chibi::da_raccontare(g, static_cast<float>(p_ora), p_mezza_vita,
			static_cast<uint32_t>(p_gia_saputi));
}

// ======================================================================
// FASE 5 — L'INJECTION
// ======================================================================

int EcsMondo::deduci(int64_t p_id, int p_obiettivo, const PackedInt32Array &p_righe,
		double p_soglia) {
	ERR_FAIL_COND_V(!conosce(p_id), -1);
	const entt::entity e = da_handle(p_id);
	const chibi::GrafoRicordi &g = _reg->reg.get<chibi::GrafoComponent>(e).g;
	const int n_grafo = (g.n < chibi::MAX_FATTI) ? static_cast<int>(g.n) : chibi::MAX_FATTI;

	const int quante = p_righe.size();
	// SI RIFIUTA, NON SI TRONCA — e le due cose non si somigliano affatto.
	// Troncare consegnerebbe al mondo una deduzione DIVERSA da quella che il
	// modello ha proposto e il Giudice ha collaudato, e nessuno se ne
	// accorgerebbe: la catena valutata sarebbe un pezzo di quella scritta.
	// (E questa riga sta PRIMA del ciclo perché il ciclo scrive dentro
	// `d.perche[k]`: senza, una lista lunga uscirebbe dall'array.)
	if (quante <= 0 || quante > chibi::MAX_PERCHE) {
		return -1;
	}

	chibi::Deduzione d;
	d.obiettivo = static_cast<uint32_t>(p_obiettivo);
	for (int k = 0; k < quante; k++) {
		const int riga = p_righe[k];
		// UNA RIGA CHE NON C'È NON REGGE NIENTE. Il Giudice controlla già che
		// il ricordo sia vivo, ma lui guarda il ritratto — che è una
		// FOTOGRAFIA presa quando il pensiero è partito, cioè secondi fa. Fra
		// quella foto e adesso l'anello può essersi mosso. Qui si guarda il
		// grafo VERO, ed è l'ultimo posto in cui si può ancora dire di no.
		if (riga < 0 || riga >= n_grafo) {
			return -1;
		}
		// NIENTE DOPPIONI. Un modello che cita due volte lo stesso ricordo
		// gonfia la propria catena senza aggiungerci niente — e siccome la
		// catena si misura dall'anello più debole, il doppione la farebbe
		// sembrare più corta di quello che è. Si stringe, come sempre dove
		// una regola è incerta.
		for (int j = 0; j < k; j++) {
			if (p_righe[j] == riga) {
				return -1;
			}
		}
		d.perche[k] = g.f[riga];
		// **IL SOGGETTO NON PASSA.** Una deduzione non è mai su qualcuno: vedi
		// il veto in cima a grafo_deduzioni.h. Il peso non cambia di un bit
		// (`peso()` guarda le bandiere, non il soggetto), quindi qui non si
		// sta tarando niente — si sta togliendo l'unico campo con cui una
		// deduzione potrebbe diventare un'opinione su una persona.
		d.perche[k].soggetto = chibi::SOGG_NESSUNO;
	}
	d.n = static_cast<uint8_t>(quante);

	chibi::DeduzioniComponent &dc = _reg->reg.get<chibi::DeduzioniComponent>(e);
	return chibi::inserisci_deduzione(dc.d, d, static_cast<float>(_tempo),
			_reg->tar_occ.mezza_vita, p_soglia);
}

int EcsMondo::deduzione_muta(int64_t p_id, double p_soglia) const {
	ERR_FAIL_COND_V(!conosce(p_id), -1);
	const chibi::Deduzioni &dd =
			_reg->reg.get<chibi::DeduzioniComponent>(da_handle(p_id)).d;
	return chibi::deduzione_muta(dd, static_cast<float>(_tempo),
			_reg->tar_occ.mezza_vita, p_soglia);
}

int EcsMondo::deduzione_pronta(int64_t p_id, double p_soglia, double p_attesa,
		double p_finestra) const {
	ERR_FAIL_COND_V(!conosce(p_id), -1);
	const chibi::Deduzioni &dd =
			_reg->reg.get<chibi::DeduzioniComponent>(da_handle(p_id)).d;
	return chibi::deduzione_pronta(dd, static_cast<float>(_tempo),
			_reg->tar_occ.mezza_vita, p_soglia, p_attesa, p_finestra);
}

Vector3 EcsMondo::deduzione_dove(int64_t p_id, int p_i, const Vector3 &p_se_niente) const {
	ERR_FAIL_COND_V(!conosce(p_id), p_se_niente);
	const chibi::Deduzioni &dd =
			_reg->reg.get<chibi::DeduzioniComponent>(da_handle(p_id)).d;
	if (p_i < 0 || p_i >= static_cast<int>(dd.n)) {
		return p_se_niente;
	}
	const int k = chibi::perche_piu_forte(dd.d[p_i], static_cast<float>(_tempo),
			_reg->tar_occ.mezza_vita);
	if (k < 0) {
		return p_se_niente;
	}
	// La `y` è quella del ripiego, come in `dove()`: il ricordo non la
	// conserva, e inventare uno zero manderebbe sottoterra chi ragiona su una
	// casa sull'albero.
	return Vector3(dd.d[p_i].perche[k].px, p_se_niente.y, dd.d[p_i].perche[k].pz);
}

int EcsMondo::deduzione_obiettivo(int64_t p_id, int p_i) const {
	ERR_FAIL_COND_V(!conosce(p_id), 0);
	const chibi::Deduzioni &dd =
			_reg->reg.get<chibi::DeduzioniComponent>(da_handle(p_id)).d;
	if (p_i < 0 || p_i >= static_cast<int>(dd.n)) {
		return 0;
	}
	return static_cast<int>(dd.d[p_i].obiettivo);
}

void EcsMondo::deduzione_ricevuta(int64_t p_id, int p_i) {
	ERR_FAIL_COND(!conosce(p_id));
	chibi::Deduzioni &dd = _reg->reg.get<chibi::DeduzioniComponent>(da_handle(p_id)).d;
	if (p_i < 0 || p_i >= static_cast<int>(dd.n)) {
		return;
	}
	// SI PAGA UNA VOLTA SOLA. Ripagarla riazzererebbe l'orologio dell'attesa,
	// e una ricevuta che si rinnova è una conseguenza che non arriva mai.
	if ((dd.d[p_i].bandiere & chibi::D_RICEVUTA) != 0) {
		return;
	}
	dd.d[p_i].bandiere |= chibi::D_RICEVUTA;
	dd.d[p_i].ricevuta = static_cast<float>(_tempo);
}

void EcsMondo::deduzione_spendi(int64_t p_id, int p_i) {
	ERR_FAIL_COND(!conosce(p_id));
	chibi::Deduzioni &dd = _reg->reg.get<chibi::DeduzioniComponent>(da_handle(p_id)).d;
	if (p_i < 0 || p_i >= static_cast<int>(dd.n)) {
		return;
	}
	dd.d[p_i].bandiere |= chibi::D_SPESA;
}

Dictionary EcsMondo::debug_deduzioni(int64_t p_id) const {
	Dictionary out;
	Array righe;
	out["deduzioni"] = righe;
	ERR_FAIL_COND_V(!conosce(p_id), out);
	const chibi::Deduzioni &dd =
			_reg->reg.get<chibi::DeduzioniComponent>(da_handle(p_id)).d;
	const float ora = static_cast<float>(_tempo);
	const double mv = _reg->tar_occ.mezza_vita;
	for (int i = 0; i < static_cast<int>(dd.n); i++) {
		const chibi::Deduzione &d = dd.d[i];
		Array perche;
		for (int k = 0; k < static_cast<int>(d.n); k++) {
			perche.append(da_ricordo(d.perche[k]));
		}
		Dictionary r;
		r["obiettivo"] = static_cast<int64_t>(d.obiettivo);
		r["bandiere"] = static_cast<int>(d.bandiere);
		r["quando"] = d.quando;
		r["ricevuta"] = d.ricevuta;
		r["perche"] = perche;
		r["peso"] = chibi::peso_deduzione(d, ora, mv);
		r["peso_utile"] = chibi::peso_utile(d, ora, mv);
		righe.append(r);
	}
	out["deduzioni"] = righe;
	return out;
}

Dictionary EcsMondo::debug_deduzioni_costanti() const {
	Dictionary d;
	d["max_deduzioni"] = chibi::MAX_DEDUZIONI;
	d["max_perche"] = chibi::MAX_PERCHE;
	d["d_ricevuta"] = static_cast<int>(chibi::D_RICEVUTA);
	d["d_spesa"] = static_cast<int>(chibi::D_SPESA);
	d["maschera_provvedimenti"] = static_cast<int64_t>(chibi::MASCHERA_PROVVEDIMENTI);
	return d;
}
