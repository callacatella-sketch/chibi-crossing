#ifndef ECOSYSTEM_MANAGER_H
#define ECOSYSTEM_MANAGER_H

#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/classes/multi_mesh_instance3d.hpp>
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

#include <vector>

namespace godot {

// Il micro-ecosistema del prato: farfalle che impollinano e fanno
// nascere fiori selvatici, fiori che attirano altre farfalle, lucciole
// che depongono vicino all'acqua, passerotti che mangiano i semi
// dimenticati. Popolazioni vere: il prato risponde a come giochi.
// La simulazione gira qui; il rendering è MultiMesh (centinaia di
// individui a costo fisso). L'arte (mesh e shader) arriva da GDScript.
class EcosystemManager : public Node3D {
    GDCLASS(EcosystemManager, Node3D)

    struct Butterfly {
        Vector3 pos;
        Vector3 vel;
        Vector3 target;
        float phase = 0.0f;
        float timer = 0.0f;
        float spavento = 0.0f; // quanto le hai fatto paura adesso (0..1)
        float yaw = 0.0f;      // tenuto: da posata la velocità non dice più dove guarda
        int kind = 0;
        // 0 vaga · 1 punta un fiore · 2 sorseggia · 3 se ne va
        // 4 si fida e si avvicina · 5 posata su di te (il Fiato Sospeso)
        int state = 0;
    };

    struct Firefly {
        Vector3 pos;
        Vector3 home;
        float phase = 0.0f;
    };

    struct Sparrow {
        Vector3 pos;
        Vector3 vel;
        float timer = 0.0f;
        int seed_idx = -1;
        int eaten = 0;
        int state = 0; // 0 arriva · 1 becca · 2 riparte
        int id = -1; // stabile per tutta la vita: il GDScript mappa i corpi su questo
    };

    struct Wildflower {
        Vector3 pos;
        float maturity = 0.05f;
        int kind = 0;
    };

    struct Seed {
        Vector3 pos;
        float age = 0.0f;
    };

    struct Egg {
        Vector3 pos;
        int days = 0;
    };

    std::vector<Butterfly> butterflies;
    std::vector<Firefly> fireflies;
    std::vector<Sparrow> sparrows;
    std::vector<Wildflower> wildflowers;
    std::vector<Seed> seeds;
    std::vector<Egg> eggs;

    PackedVector3Array flower_sources; // aiuole/orti in fiore (da GDScript)

    MultiMeshInstance3D *bf_mmi = nullptr;
    MultiMeshInstance3D *ff_mmi = nullptr;
    MultiMeshInstance3D *wf_mmi = nullptr;
    Ref<MultiMesh> bf_mm;
    Ref<MultiMesh> ff_mm;
    Ref<MultiMesh> wf_mm;

    Vector3 pond_center = Vector3(9.6, 0.0, -10.0);
    float pond_radius = 3.0f;
    Vector3 meadow_min = Vector3(-13.0, 0.0, -14.0);
    Vector3 meadow_max = Vector3(13.0, 0.0, 12.0);
    bool night = false;
    Callable ground_validator;

    // --- IL FIATO SOSPESO ---
    // Il prato ha paura di te finché ti muovi: le farfalle ti scansano, i
    // passerotti scappano dai loro semi. È quella paura che si scioglie
    // quando trattieni il fiato — e senza di lei «il prato smette di avere
    // paura di te» non vorrebbe dire niente.
    Vector3 osservatore;         // dove stai
    float quiete = -1.0f;        // <0 nessun osservatore · 0 ti muovi · 1 sei un sasso
    Vector3 posatoio;            // il tuo naso: dove si posa chi si fida
    bool posatoio_valido = false;
    float fiducia_cd = 0.0f;     // fra un tentativo e l'altro passa un respiro
    int fiducia_kind = -1;       // la specie posata adesso (-1 nessuna)

    static constexpr float PAURA_R = 3.4f;       // il raggio della paura, da fermo-che-si-muove
    static constexpr float PAURA_SPINTA = 5.5f;  // quanto forte ti scansano
    static constexpr float FIDUCIA_SOGLIA = 0.62f; // da qui in su una si avvicina
    static constexpr float FIDUCIA_ROTTA = 0.34f;  // sotto qui vola via
    static constexpr float FIDUCIA_R = 7.0f;     // da quanto lontano può venire

    double sim_acc = 0.0;
    double flower_acc = 0.0;
    double sparrow_acc = 0.0;
    double t = 0.0;
    int sparrow_next_id = 0;

    void retarget_sparrows(int erased_seed);

    static const int BF_MAX = 90;
    static const int FF_MAX = 60;
    static const int WF_MAX = 380;
    static const int SEED_MAX = 40;
    static const int EGG_MAX = 14;
    static const int SPARROW_MAX = 7;

    Vector3 random_meadow_point() const;
    Vector3 random_flower_point() const;
    bool ground_ok(const Vector3 &p);
    void sim_step();
    void spawn_butterfly(bool at_edge);
    void update_butterflies(double delta);
    void update_fireflies(double delta);
    void update_sparrows(double delta);
    void applica_paura(Butterfly &b, double delta);
    void aggiorna_fiducia(double delta);
    void push_transforms();
    void push_flowers();

protected:
    static void _bind_methods();

public:
    EcosystemManager();
    ~EcosystemManager();

    void _ready() override;
    void _physics_process(double delta) override;

    // --- cablaggio dal GDScript ---
    void configure(const Ref<Mesh> &butterfly_mesh, const Ref<Mesh> &firefly_mesh,
            const Ref<Mesh> &flower_mesh);
    void set_pond(const Vector3 &center, float radius);
    void set_meadow(const Vector3 &p_min, const Vector3 &p_max);
    void set_night(bool p_night);
    void set_flower_sources(const PackedVector3Array &sources);
    void set_ground_validator(const Callable &validator);

    // --- il Fiato Sospeso: chi guarda, e dove può posarsi la fiducia ---
    void set_osservatore(const Vector3 &pos, float p_quiete);
    void togli_osservatore();
    void set_posatoio(const Vector3 &pos);
    void togli_posatoio();
    // {"stato": 0 nessuna / 1 in arrivo / 2 posata, "kind": int, "pos": Vector3}
    Dictionary fiducia() const;

    // --- eventi di gioco ---
    void drop_seeds(const Vector3 &pos, int n);
    void on_new_day();

    // --- letture (passerotti disegnati dal GDScript, HUD, debug) ---
    int sparrow_count() const;
    Vector3 sparrow_pos(int i) const;
    Vector3 sparrow_dir(int i) const;
    int sparrow_state(int i) const;
    int sparrow_id(int i) const;
    Dictionary counts() const;

    // --- persistenza ---
    Dictionary save_state() const;
    void load_state(const Dictionary &state);

    // --- per la verifica CLI: semina uno stato ricco all'istante ---
    void debug_burst();
};

} // namespace godot

#endif
