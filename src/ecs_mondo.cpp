#include "ecs_mondo.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>

#include "ecs_componenti.h"
#include "ecs_entt.h"
#include "sistema_agenda.h"
#include "sistema_piani.h"
#include "sistema_sonno.h"

using namespace godot;

// Il registry vive QUI dentro e in nessun header: è tutto il senso del
// PIMPL dichiarato in ecs_mondo.h.
struct EcsMondo::Registro {
	entt::registry reg;
	chibi::TaraturaAgenda tar;
	chibi::TaraturaPiani tar_piani;
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
	ClassDB::bind_method(D_METHOD("debug_agenda", "id"), &EcsMondo::debug_agenda);
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
	auto vista2 = _reg->reg.view<chibi::DnaComponent, chibi::StatoComponent,
			chibi::BisogniComponent, chibi::AgendaComponent>();
	for (const entt::entity e : vista2) {
		const chibi::DnaComponent &dna = vista2.get<chibi::DnaComponent>(e);
		const chibi::StatoComponent &st = vista2.get<chibi::StatoComponent>(e);
		const chibi::BisogniComponent &bi = vista2.get<chibi::BisogniComponent>(e);
		chibi::AgendaComponent &ag = vista2.get<chibi::AgendaComponent>(e);

		double punti[chibi::N_AZIONI];
		uint32_t fattibile = 0;
		chibi::punteggi(bi.v, ag.fatti, dna.indole,
				chibi::nottambulo(dna.indole, dna.quirk), punti, &fattibile);

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
			chibi::nottambulo(ind, static_cast<int32_t>(p_quirk)), punti, &fattibile);
	out.resize(chibi::N_AZIONI);
	for (int i = 0; i < chibi::N_AZIONI; i++) {
		out[i] = punti[i];
	}
	return out;
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
