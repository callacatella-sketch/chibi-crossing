#include "ecs_mondo.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>

#include "ecs_componenti.h"
#include "ecs_entt.h"
#include "sistema_sonno.h"

using namespace godot;

// Il registry vive QUI dentro e in nessun header: è tutto il senso del
// PIMPL dichiarato in ecs_mondo.h.
struct EcsMondo::Registro {
	entt::registry reg;
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
	ClassDB::bind_method(D_METHOD("dimentica", "id"), &EcsMondo::dimentica);
	ClassDB::bind_method(D_METHOD("dimentica_tutti"), &EcsMondo::dimentica_tutti);
	ClassDB::bind_method(D_METHOD("conosce", "id"), &EcsMondo::conosce);
	ClassDB::bind_method(D_METHOD("quanti"), &EcsMondo::quanti);
	ClassDB::bind_method(D_METHOD("riferisci", "id", "nascosto", "corpo_libero", "porta_aperta"), &EcsMondo::riferisci);
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
	// NIENTE TransformComponent: vedi ecs_componenti.h
	return a_handle(e);
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
