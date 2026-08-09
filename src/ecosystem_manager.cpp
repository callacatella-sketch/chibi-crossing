#include "ecosystem_manager.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

// ------------------------------------------------------------ binding

void EcosystemManager::_bind_methods() {
    ClassDB::bind_method(D_METHOD("configure", "butterfly_mesh", "firefly_mesh", "flower_mesh"), &EcosystemManager::configure);
    ClassDB::bind_method(D_METHOD("set_pond", "center", "radius"), &EcosystemManager::set_pond);
    ClassDB::bind_method(D_METHOD("set_meadow", "min", "max"), &EcosystemManager::set_meadow);
    ClassDB::bind_method(D_METHOD("set_night", "night"), &EcosystemManager::set_night);
    ClassDB::bind_method(D_METHOD("set_flower_sources", "sources"), &EcosystemManager::set_flower_sources);
    ClassDB::bind_method(D_METHOD("set_ground_validator", "validator"), &EcosystemManager::set_ground_validator);
    ClassDB::bind_method(D_METHOD("set_osservatore", "pos", "quiete"), &EcosystemManager::set_osservatore);
    ClassDB::bind_method(D_METHOD("togli_osservatore"), &EcosystemManager::togli_osservatore);
    ClassDB::bind_method(D_METHOD("drop_seeds", "pos", "n"), &EcosystemManager::drop_seeds);
    ClassDB::bind_method(D_METHOD("on_new_day"), &EcosystemManager::on_new_day);
    ClassDB::bind_method(D_METHOD("sparrow_count"), &EcosystemManager::sparrow_count);
    ClassDB::bind_method(D_METHOD("sparrow_pos", "i"), &EcosystemManager::sparrow_pos);
    ClassDB::bind_method(D_METHOD("sparrow_dir", "i"), &EcosystemManager::sparrow_dir);
    ClassDB::bind_method(D_METHOD("sparrow_state", "i"), &EcosystemManager::sparrow_state);
    ClassDB::bind_method(D_METHOD("sparrow_id", "i"), &EcosystemManager::sparrow_id);
    ClassDB::bind_method(D_METHOD("counts"), &EcosystemManager::counts);
    ClassDB::bind_method(D_METHOD("save_state"), &EcosystemManager::save_state);
    ClassDB::bind_method(D_METHOD("load_state", "state"), &EcosystemManager::load_state);
    ClassDB::bind_method(D_METHOD("debug_burst"), &EcosystemManager::debug_burst);
    ClassDB::bind_method(D_METHOD("debug_farfalla", "i"), &EcosystemManager::debug_farfalla);
    ClassDB::bind_method(D_METHOD("debug_lucciola", "i"), &EcosystemManager::debug_lucciola);
}

EcosystemManager::EcosystemManager() {}
EcosystemManager::~EcosystemManager() {}

void EcosystemManager::_ready() {
    if (Engine::get_singleton()->is_editor_hint()) return;
    set_physics_process(true);
}

// ------------------------------------------------------------ setup

void EcosystemManager::configure(const Ref<Mesh> &butterfly_mesh, const Ref<Mesh> &firefly_mesh,
        const Ref<Mesh> &flower_mesh) {
    bf_mm.instantiate();
    bf_mm->set_transform_format(MultiMesh::TRANSFORM_3D);
    bf_mm->set_use_custom_data(true);
    bf_mm->set_mesh(butterfly_mesh);
    bf_mm->set_instance_count(BF_MAX);
    bf_mm->set_visible_instance_count(0);
    bf_mmi = memnew(MultiMeshInstance3D);
    bf_mmi->set_multimesh(bf_mm);
    bf_mmi->set_cast_shadows_setting(GeometryInstance3D::SHADOW_CASTING_SETTING_OFF);
    add_child(bf_mmi);

    ff_mm.instantiate();
    ff_mm->set_transform_format(MultiMesh::TRANSFORM_3D);
    ff_mm->set_use_custom_data(true);
    ff_mm->set_mesh(firefly_mesh);
    ff_mm->set_instance_count(FF_MAX);
    ff_mm->set_visible_instance_count(0);
    ff_mmi = memnew(MultiMeshInstance3D);
    ff_mmi->set_multimesh(ff_mm);
    ff_mmi->set_cast_shadows_setting(GeometryInstance3D::SHADOW_CASTING_SETTING_OFF);
    add_child(ff_mmi);

    wf_mm.instantiate();
    wf_mm->set_transform_format(MultiMesh::TRANSFORM_3D);
    wf_mm->set_use_custom_data(true);
    wf_mm->set_mesh(flower_mesh);
    wf_mm->set_instance_count(WF_MAX);
    wf_mm->set_visible_instance_count(0);
    wf_mmi = memnew(MultiMeshInstance3D);
    wf_mmi->set_multimesh(wf_mm);
    add_child(wf_mmi);

    // la popolazione di partenza: qualche farfalla sul prato e un
    // primo giro di lucciole vicino allo stagno
    for (int i = 0; i < 6; i++) {
        spawn_butterfly(false);
    }
    for (int i = 0; i < 8; i++) {
        Firefly f;
        f.home = pond_center + Vector3(UtilityFunctions::randf_range(-2.5, 2.5), 0.0,
                UtilityFunctions::randf_range(-2.5, 2.5));
        f.casa = f.home;
        f.pos = f.home + Vector3(0, UtilityFunctions::randf_range(0.4, 1.1), 0);
        f.phase = UtilityFunctions::randf();
        f.blink_offset = UtilityFunctions::randf();
        fireflies.push_back(f);
    }
}

void EcosystemManager::set_pond(const Vector3 &center, float radius) {
    pond_center = center;
    pond_radius = radius;
}

void EcosystemManager::set_meadow(const Vector3 &p_min, const Vector3 &p_max) {
    meadow_min = p_min;
    meadow_max = p_max;
}

void EcosystemManager::set_night(bool p_night) {
    night = p_night;
}

void EcosystemManager::set_flower_sources(const PackedVector3Array &sources) {
    flower_sources = sources;
}

// ---------------------------------------------------- il Fiato Sospeso

void EcosystemManager::set_osservatore(const Vector3 &pos, float p_quiete) {
    osservatore = pos;
    quiete = CLAMP(p_quiete, 0.0f, 1.0f);
}

void EcosystemManager::togli_osservatore() {
    quiete = -1.0f;
}

void EcosystemManager::set_ground_validator(const Callable &validator) {
    ground_validator = validator;
}

// ------------------------------------------------------------ eventi

void EcosystemManager::drop_seeds(const Vector3 &pos, int n) {
    for (int i = 0; i < n && (int)seeds.size() < SEED_MAX; i++) {
        Seed s;
        s.pos = pos + Vector3(UtilityFunctions::randf_range(-0.9, 0.9), 0.0,
                UtilityFunctions::randf_range(-0.9, 0.9));
        seeds.push_back(s);
    }
}

void EcosystemManager::on_new_day() {
    // le uova maturano di notte in notte, poi si schiudono al laghetto
    for (int i = (int)eggs.size() - 1; i >= 0; i--) {
        eggs[i].days++;
        if (eggs[i].days >= 2) {
            if ((int)fireflies.size() < FF_MAX) {
                Firefly f;
                f.home = eggs[i].pos;
                f.casa = f.home;
                f.pos = f.home + Vector3(0, 0.6, 0);
                f.phase = UtilityFunctions::randf();
                f.blink_offset = UtilityFunctions::randf();
                fireflies.push_back(f);
            }
            // swap-and-pop: O(1) invece di erase O(n). L'ordine delle uova non
            // conta (nessuno le indicizza da fuori) e il loop va a ritroso, così
            // l'elemento spostato qui è già stato processato.
            eggs[i] = eggs.back();
            eggs.pop_back();
        }
    }
    // un po' di mortalità tiene le popolazioni in equilibrio
    int ff_deaths = MAX(0, (int)(((int)fireflies.size() - 5) * 0.15));
    for (int i = 0; i < ff_deaths && !fireflies.empty(); i++) {
        fireflies.pop_back();
    }
    int wf_deaths = (int)(wildflowers.size() * 0.04);
    for (int i = 0; i < wf_deaths && !wildflowers.empty(); i++) {
        // swap-and-pop: toglie un fiore a caso senza scalare tutto il vettore
        int r = (int)UtilityFunctions::randi_range(0, (int)wildflowers.size() - 1);
        wildflowers[r] = wildflowers.back();
        wildflowers.pop_back();
    }
    push_flowers();
}

// ------------------------------------------------------------ util

Vector3 EcosystemManager::random_meadow_point() const {
    return Vector3(UtilityFunctions::randf_range(meadow_min.x, meadow_max.x), 0.0,
            UtilityFunctions::randf_range(meadow_min.z, meadow_max.z));
}

Vector3 EcosystemManager::random_flower_point() const {
    // cast espliciti a int: flower_sources.size() e wildflowers.size() hanno tipi
    // diversi (int64_t / size_t), confrontarli/sommarli così evita warning.
    int fs = (int)flower_sources.size();
    int total = fs + (int)wildflowers.size();
    if (total == 0) {
        return random_meadow_point();
    }
    int i = (int)UtilityFunctions::randi_range(0, total - 1);
    if (i < fs) {
        return flower_sources[i];
    }
    return wildflowers[i - fs].pos;
}

bool EcosystemManager::ground_ok(const Vector3 &p) {
    if (p.x < meadow_min.x || p.x > meadow_max.x || p.z < meadow_min.z || p.z > meadow_max.z) {
        return false;
    }
    Vector3 flat = p;
    flat.y = pond_center.y;
    if (flat.distance_to(pond_center) < pond_radius + 0.6f) {
        return false;
    }
    if (ground_validator.is_valid()) {
        return (bool)ground_validator.call(p);
    }
    return true;
}

// ------------------------------------------------------------ simulazione

void EcosystemManager::_physics_process(double delta) {
    if (Engine::get_singleton()->is_editor_hint() || bf_mm.is_null()) return;
    t += delta;

    update_butterflies(delta);
    update_fireflies(delta);
    update_sparrows(delta);

    sim_acc += delta;
    if (sim_acc >= 1.5) {
        sim_acc = 0.0;
        sim_step();
    }
    flower_acc += delta;
    if (flower_acc >= 0.5) {
        flower_acc = 0.0;
        // i fiori selvatici crescono piano: da germoglio a corolla
        for (Wildflower &w : wildflowers) {
            w.maturity = MIN(1.0f, w.maturity + 0.004f);
        }
        push_flowers();
    }
    push_transforms();
}

// il passo lento della vita: nascite, partenze, semi che germogliano
void EcosystemManager::sim_step() {
    // capacità portante: più fiori = più farfalle che restano
    int flowers_total = flower_sources.size() * 4 + (int)wildflowers.size();
    int carrying = (int)CLAMP(4.0 + flowers_total * 0.22, 4.0, (double)BF_MAX);

    if ((int)butterflies.size() < carrying && UtilityFunctions::randf() < 0.4) {
        spawn_butterfly(butterflies.empty() || UtilityFunctions::randf() < 0.3);
    }
    if ((int)butterflies.size() > carrying) {
        for (Butterfly &b : butterflies) {
            if (b.state == 0) {
                b.state = 3; // una saluta e se ne va
                break;
            }
        }
    }

    // chi vaga sceglie un fiore da visitare
    for (Butterfly &b : butterflies) {
        if (b.state == 0 && UtilityFunctions::randf() < 0.3) {
            b.target = random_flower_point();
            b.state = 1;
        }
    }

    // i semi dimenticati: o li becca un passerotto, o germogliano
    for (int i = (int)seeds.size() - 1; i >= 0; i--) {
        seeds[i].age += 1.5f;
        if (seeds[i].age > 70.0f) {
            if ((int)wildflowers.size() < WF_MAX && ground_ok(seeds[i].pos)) {
                Wildflower w;
                w.pos = seeds[i].pos;
                w.kind = (int)UtilityFunctions::randi_range(0, 3);
                wildflowers.push_back(w);
            }
            seeds.erase(seeds.begin() + i);
            retarget_sparrows(i);
        }
    }

    // i passerotti arrivano dove ci sono semi
    sparrow_acc += 1.5;
    int wanted = seeds.empty() ? 0 : MIN(2 + (int)seeds.size() / 4, SPARROW_MAX);
    if ((int)sparrows.size() < wanted && sparrow_acc >= 6.0) {
        sparrow_acc = 0.0;
        Sparrow s;
        float side = UtilityFunctions::randf() < 0.5 ? meadow_min.x : meadow_max.x;
        s.pos = Vector3(side, 2.6, UtilityFunctions::randf_range(meadow_min.z, meadow_max.z));
        s.state = 0;
        s.id = sparrow_next_id++;
        sparrows.push_back(s);
    }

    // di notte le lucciole depongono vicino all'acqua
    if (night && fireflies.size() >= 2 && (int)eggs.size() < EGG_MAX &&
            UtilityFunctions::randf() < 0.25) {
        float a = UtilityFunctions::randf() * Math::TAU;
        Egg e;
        e.pos = pond_center + Vector3(Math::cos(a), 0.0, Math::sin(a)) * (pond_radius + 0.9f);
        eggs.push_back(e);
    }
}

void EcosystemManager::spawn_butterfly(bool at_edge) {
    if ((int)butterflies.size() >= BF_MAX) return;
    Butterfly b;
    if (at_edge) {
        b.pos = Vector3(UtilityFunctions::randf() < 0.5 ? meadow_min.x : meadow_max.x,
                UtilityFunctions::randf_range(0.6, 1.4),
                UtilityFunctions::randf_range(meadow_min.z, meadow_max.z));
    } else {
        Vector3 f = random_flower_point();
        b.pos = f + Vector3(UtilityFunctions::randf_range(-1.5, 1.5),
                UtilityFunctions::randf_range(0.5, 1.2),
                UtilityFunctions::randf_range(-1.5, 1.5));
    }
    b.vel = Vector3(UtilityFunctions::randf_range(-0.5, 0.5), 0.0,
            UtilityFunctions::randf_range(-0.5, 0.5));
    b.phase = UtilityFunctions::randf();
    b.blink_offset = UtilityFunctions::randf();
    b.kind = (int)UtilityFunctions::randi_range(0, 2);
    butterflies.push_back(b);
}

// LA PAURA. Finché ti muovi, il prato ti scansa: chi sorseggia lascia il
// fiore, chi vaga si allarga e sale un soffio, fuori portata. Il raggio
// si stringe con la quiete — da fermo del tutto non fai più paura a
// nessuno, ed è lì che comincia il Fiato Sospeso.
void EcosystemManager::applica_paura(Butterfly &b, double delta) {
    if (quiete < 0.0f || b.state >= 3) return;   // nessun osservatore, o già in volo via
    float raggio = PAURA_R * (1.0f - quiete);
    if (raggio < 0.05f) return;
    Vector3 via = b.pos - osservatore;
    via.y = 0.0f;
    float d = via.length();
    if (d > raggio || d < 0.0001f) return;
    float f = 1.0f - d / raggio;                 // 0 al bordo, 1 addosso
    // il pasto può aspettare: chi ti vede arrivare si stacca dalla corolla
    if (b.state == 2 && f > 0.4f) b.state = 0;
    else if (b.state == 1 && f > 0.6f) b.state = 0;
    b.vel += (via / d) * (f * f * PAURA_SPINTA) * (float)delta;
    b.spavento = MAX(b.spavento, f);
}

void EcosystemManager::update_butterflies(double delta) {
    for (int i = (int)butterflies.size() - 1; i >= 0; i--) {
        Butterfly &b = butterflies[i];
        b.phase += delta;
        b.spavento = MAX(0.0f, b.spavento - (float)delta * 0.55f);
        applica_paura(b, delta);
        switch (b.state) {
            case 0: { // vaga: passeggiata aleatoria morbida
                b.vel.x += UtilityFunctions::randf_range(-1.6, 1.6) * delta;
                b.vel.z += UtilityFunctions::randf_range(-1.6, 1.6) * delta;
                Vector3 flat(b.vel.x, 0.0, b.vel.z);
                float sp = flat.length();
                // spaventata vola più forte: il tetto si alza con la paura,
                // altrimenti lo scarto verrebbe limato via dal limite di crociera
                float tetto = 0.9f + b.spavento * 1.5f;
                if (sp > tetto) flat *= tetto / sp;
                b.vel.x = flat.x; b.vel.z = flat.z;
                // resta nel prato
                if (b.pos.x < meadow_min.x + 1.0) b.vel.x += (float)delta * 2.0f;
                if (b.pos.x > meadow_max.x - 1.0) b.vel.x -= (float)delta * 2.0f;
                if (b.pos.z < meadow_min.z + 1.0) b.vel.z += (float)delta * 2.0f;
                if (b.pos.z > meadow_max.z - 1.0) b.vel.z -= (float)delta * 2.0f;
                b.pos += b.vel * delta;
                // e sale, fuori portata: la fuga di una farfalla è verso l'alto
                b.pos.y = 0.75f + Math::sin(b.phase * 2.1f) * 0.28f + b.spavento * 0.6f;
            } break;
            case 1: { // punta il fiore scelto
                Vector3 to = b.target - b.pos;
                to.y = 0.0;
                float d = to.length();
                if (d < 0.25f) {
                    b.state = 2;
                    b.timer = UtilityFunctions::randf_range(2.5, 4.0);
                } else {
                    b.vel = b.vel.lerp(to / d * 1.1f, MIN(1.0, delta * 2.5));
                    b.pos += b.vel * delta;
                    b.pos.y = Math::lerp(b.pos.y, 0.55f + Math::sin(b.phase * 2.4f) * 0.12f,
                            (float)delta * 2.0f);
                }
            } break;
            case 2: { // sorseggia: piccolo cerchio sopra la corolla...
                b.timer -= delta;
                b.pos.x = b.target.x + Math::cos(b.phase * 1.7f) * 0.16f;
                b.pos.z = b.target.z + Math::sin(b.phase * 1.7f) * 0.16f;
                b.pos.y = 0.42f + Math::sin(b.phase * 3.0f) * 0.05f;
                if (b.timer <= 0.0f) {
                    // ...e impollina: può nascere un fiore selvatico
                    if ((int)wildflowers.size() < WF_MAX && UtilityFunctions::randf() < 0.3) {
                        float a = UtilityFunctions::randf() * Math::TAU;
                        Vector3 p = b.target + Vector3(Math::cos(a), 0.0, Math::sin(a)) *
                                UtilityFunctions::randf_range(0.9, 2.8);
                        if (ground_ok(p)) {
                            Wildflower w;
                            w.pos = p;
                            w.kind = (int)UtilityFunctions::randi_range(0, 3);
                            wildflowers.push_back(w);
                        }
                    }
                    b.state = 0;
                }
            } break;
            case 3: { // se ne va oltre il bordo del prato
                b.vel = b.vel.lerp(Vector3(b.vel.x * 2.0f, 0.6f, b.vel.z * 2.0f).normalized() * 1.6f,
                        MIN(1.0, delta * 1.5));
                b.pos += b.vel * delta;
                if (b.pos.x < meadow_min.x - 2.0 || b.pos.x > meadow_max.x + 2.0 ||
                        b.pos.z < meadow_min.z - 2.0 || b.pos.z > meadow_max.z + 2.0) {
                    // swap-and-pop: l'ordine delle farfalle è indifferente
                    // (il MultiMesh le ridisegna tutte ogni frame).
                    butterflies[i] = butterflies.back();
                    butterflies.pop_back();
                }
            } break;
        }
    }
}

void EcosystemManager::update_fireflies(double delta) {
    if (!night) return;
    // di notte la fiducia non si posa: si avvicina. Le lucciole che ti
    // stanno intorno spostano piano il loro giro verso di te — e se ti
    // muovi tornano dov'erano, senza fretta e senza rimprovero.
    bool attira = quiete > 0.5f;
    for (Firefly &f : fireflies) {
        f.phase += delta * 0.6;
        if (quiete >= 0.0f) {
            Vector3 verso = osservatore - f.home;
            verso.y = 0.0f;
            float d = verso.length();
            if (attira && d > 1.2f && d < 9.0f) {
                f.home += verso / d * (float)delta * (quiete - 0.5f) * 1.6f;
            } else {
                // e quando ti rialzi TORNA A CASA. Senza un'ancora, ogni
                // Fiato Sospeso spostava le lucciole un po' più in là e
                // non le riportava mai indietro: dopo qualche notte lo
                // stagno sarebbe rimasto al buio, e nessuno avrebbe
                // saputo perché.
                Vector3 verso_casa = f.casa - f.home;
                verso_casa.y = 0.0f;
                float dc = verso_casa.length();
                if (dc > 0.02f) {
                    f.home += verso_casa / dc * MIN(dc, (float)delta * 0.6f);
                }
            }
        }
        f.pos.x = f.home.x + Math::cos(f.phase * 1.3f) * 1.1f;
        f.pos.z = f.home.z + Math::sin(f.phase * 1.7f) * 1.1f;
        f.pos.y = 0.7f + Math::sin(f.phase * 2.3f) * 0.3f;
    }
}

void EcosystemManager::update_sparrows(double delta) {
    for (int i = (int)sparrows.size() - 1; i >= 0; i--) {
        Sparrow &s = sparrows[i];
        // un passerotto non ti lascia arrivare: se ti muovi qui vicino
        // pianta il seme e riparte. Da fermo, invece, becca a un palmo
        // dalle tue zampe — ed è tutto il premio del Fiato Sospeso.
        if (quiete >= 0.0f && s.state < 2) {
            float raggio = 2.7f * (1.0f - quiete);
            if (s.pos.distance_to(osservatore) < raggio) {
                s.state = 2;
                s.seed_idx = -1;
            }
        }
        switch (s.state) {
            case 0: { // vola verso un seme
                if (s.seed_idx < 0 || s.seed_idx >= (int)seeds.size()) {
                    if (seeds.empty()) { s.state = 2; break; }
                    s.seed_idx = (int)UtilityFunctions::randi_range(0, (int)seeds.size() - 1);
                }
                Vector3 to = seeds[s.seed_idx].pos - s.pos;
                float d = to.length();
                if (d < 0.15f) {
                    s.state = 1;
                    s.timer = 2.2f;
                    s.pos.y = 0.0;
                } else {
                    s.vel = s.vel.lerp(to / d * 3.4f, MIN(1.0, delta * 3.0));
                    s.pos += s.vel * delta;
                }
            } break;
            case 1: { // becca il seme
                s.timer -= delta;
                if (s.timer <= 0.0f) {
                    if (s.seed_idx >= 0 && s.seed_idx < (int)seeds.size()) {
                        int k = s.seed_idx;
                        seeds.erase(seeds.begin() + k);
                        retarget_sparrows(k);
                    }
                    s.seed_idx = -1;
                    s.eaten++;
                    s.state = (s.eaten >= 2 || seeds.empty()) ? 2 : 0;
                }
            } break;
            case 2: { // sazio: riparte verso il cielo
                s.vel = s.vel.lerp(Vector3(2.6f, 2.0f, 0.6f), MIN(1.0, delta * 2.0));
                s.pos += s.vel * delta;
                if (s.pos.y > 7.0f) {
                    // swap-and-pop: il lato GDScript riconosce i passerotti per
                    // `id` (non per posizione), quindi il riordino è sicuro.
                    sparrows[i] = sparrows.back();
                    sparrows.pop_back();
                }
            } break;
        }
    }
}

// ------------------------------------------------------------ rendering

void EcosystemManager::push_transforms() {
    int n = MIN((int)butterflies.size(), BF_MAX);
    bf_mm->set_visible_instance_count(n);
    for (int i = 0; i < n; i++) {
        Butterfly &b = butterflies[i];
        // da posata la velocità è zero e atan2(0,0) la farebbe scattare a
        // nord: l'orientamento si TIENE, e si aggiorna solo mentre vola
        if (b.vel.length_squared() > 0.0004f) {
            b.yaw = Math::atan2(-b.vel.x, -b.vel.z);
        }
        Basis basis(Vector3(0, 1, 0), b.yaw);
        bf_mm->set_instance_transform(i, Transform3D(basis, b.pos));
        // il battito: lento sul fiore, lentissimo da posata (le ali si
        // aprono e si chiudono piano, come un respiro), concitato in fuga
        float battito = 1.0f;
        if (b.state == 2) battito = 0.35f;
        else if (b.state == 3 || b.spavento > 0.05f) battito = 1.0f + b.spavento * 0.9f;
        // .x è lo SFASAMENTO (0..1), non l'orologio: lo shader lo moltiplica
        // per 6.283 per sparpagliare le ali, e con un valore che cresce nel
        // tempo quella derivata si sommava alla frequenza del battito.
        // Il valore si registra QUI, dallo stesso Color che parte: così la
        // verifica headless non può restare verde se un domani questa riga
        // tornasse a spedire b.phase.
        Color cd(b.blink_offset, (float)b.kind, battito, 0.0);
        b.ultimo_custom = cd.r;
        bf_mm->set_instance_custom_data(i, cd);
    }
    int fn = night ? MIN((int)fireflies.size(), FF_MAX) : 0;
    ff_mm->set_visible_instance_count(fn);
    for (int i = 0; i < fn; i++) {
        Firefly &f = fireflies[i];
        ff_mm->set_instance_transform(i, Transform3D(Basis(), f.pos));
        // idem per le lucciole: mandare `phase` (che accumula a 0.6/s) faceva
        // pulsare il lampeggio a 2.4 + 0.6*6.283 = 6.17 rad/s invece di 2.4 —
        // due volte e mezza troppo in fretta, un tremolio da lampadina rotta
        Color cd(f.blink_offset, 0, 0, 0);
        f.ultimo_custom = cd.r;
        ff_mm->set_instance_custom_data(i, cd);
    }
}

void EcosystemManager::push_flowers() {
    if (wf_mm.is_null()) return;
    int n = MIN((int)wildflowers.size(), WF_MAX);
    wf_mm->set_visible_instance_count(n);
    for (int i = 0; i < n; i++) {
        const Wildflower &w = wildflowers[i];
        float s = 0.3f + 0.7f * w.maturity;
        float yaw = (float)(w.kind * 1.7 + i * 0.61);
        Basis basis = Basis(Vector3(0, 1, 0), yaw).scaled(Vector3(s, s, s));
        wf_mm->set_instance_transform(i, Transform3D(basis, w.pos));
        wf_mm->set_instance_custom_data(i, Color((float)w.kind, w.maturity, 0, 0));
    }
}

// ------------------------------------------------------------ letture

int EcosystemManager::sparrow_count() const {
    return (int)sparrows.size();
}

Vector3 EcosystemManager::sparrow_pos(int i) const {
    if (i < 0 || i >= (int)sparrows.size()) return Vector3();
    return sparrows[i].pos;
}

Vector3 EcosystemManager::sparrow_dir(int i) const {
    if (i < 0 || i >= (int)sparrows.size()) return Vector3(0, 0, -1);
    return sparrows[i].vel;
}

int EcosystemManager::sparrow_state(int i) const {
    if (i < 0 || i >= (int)sparrows.size()) return 0;
    return sparrows[i].state;
}

int EcosystemManager::sparrow_id(int i) const {
    if (i < 0 || i >= (int)sparrows.size()) return -1;
    return sparrows[i].id;
}

// Ogni erase su seeds sposta gli indici: chi puntava al seme cancellato
// riparte da capo, chi puntava più avanti scala di uno.
void EcosystemManager::retarget_sparrows(int erased_seed) {
    for (Sparrow &s : sparrows) {
        if (s.seed_idx == erased_seed) {
            s.seed_idx = -1;
        } else if (s.seed_idx > erased_seed) {
            s.seed_idx--;
        }
    }
}

Dictionary EcosystemManager::counts() const {
    Dictionary d;
    d["farfalle"] = (int)butterflies.size();
    d["lucciole"] = (int)fireflies.size();
    d["fiori"] = (int)wildflowers.size();
    d["semi"] = (int)seeds.size();
    d["uova"] = (int)eggs.size();
    d["passerotti"] = (int)sparrows.size();
    return d;
}

// ------------------------------------------------------------ persistenza

Dictionary EcosystemManager::save_state() const {
    Dictionary d;
    d["bf"] = (int)butterflies.size();
    d["ff"] = (int)fireflies.size();
    Array wf;
    for (const Wildflower &w : wildflowers) {
        Array row;
        row.push_back(w.pos.x);
        row.push_back(w.pos.z);
        row.push_back(w.maturity);
        row.push_back(w.kind);
        wf.push_back(row);
    }
    d["wf"] = wf;
    Array eg;
    for (const Egg &e : eggs) {
        Array row;
        row.push_back(e.pos.x);
        row.push_back(e.pos.z);
        row.push_back(e.days);
        eg.push_back(row);
    }
    d["eggs"] = eg;
    Array sd;
    for (const Seed &s : seeds) {
        Array row;
        row.push_back(s.pos.x);
        row.push_back(s.pos.z);
        sd.push_back(row);
    }
    d["seeds"] = sd;
    return d;
}

void EcosystemManager::load_state(const Dictionary &state) {
    wildflowers.clear();
    eggs.clear();
    seeds.clear();
    sparrows.clear(); // i seed_idx salvati in volo non hanno più senso
    // Igiene sui VALORI, non solo sulla struttura: il salvataggio è JSON
    // modificabile a mano. Una maturity infinita/negativa resterebbe tale per
    // sempre (la crescita clampa solo verso l'alto) e corromperebbe le
    // trasformazioni spinte al RenderingServer; uova con days assurdi non si
    // schiuderebbero mai saturando EGG_MAX.
    Array wf = state.get("wf", Array());
    for (int i = 0; i < wf.size() && i < WF_MAX; i++) {
        Array row = wf[i];
        if (row.size() < 4) continue;
        float px = (float)row[0];
        float pz = (float)row[1];
        float m = (float)row[2];
        if (!Math::is_finite(px) || !Math::is_finite(pz) || !Math::is_finite(m)) continue;
        Wildflower w;
        w.pos = Vector3(CLAMP(px, -200.0f, 200.0f), 0.0, CLAMP(pz, -200.0f, 200.0f));
        w.maturity = CLAMP(m, 0.0f, 1.0f);
        w.kind = CLAMP((int)row[3], 0, 3);
        wildflowers.push_back(w);
    }
    Array eg = state.get("eggs", Array());
    for (int i = 0; i < eg.size() && i < EGG_MAX; i++) {
        Array row = eg[i];
        if (row.size() < 3) continue;
        float px = (float)row[0];
        float pz = (float)row[1];
        if (!Math::is_finite(px) || !Math::is_finite(pz)) continue;
        Egg e;
        e.pos = Vector3(CLAMP(px, -200.0f, 200.0f), 0.0, CLAMP(pz, -200.0f, 200.0f));
        e.days = CLAMP((int)row[2], 0, 2);
        eggs.push_back(e);
    }
    Array sd = state.get("seeds", Array());
    for (int i = 0; i < sd.size() && i < SEED_MAX; i++) {
        Array row = sd[i];
        if (row.size() < 2) continue;
        float px = (float)row[0];
        float pz = (float)row[1];
        if (!Math::is_finite(px) || !Math::is_finite(pz)) continue;
        Seed s;
        s.pos = Vector3(CLAMP(px, -200.0f, 200.0f), 0.0, CLAMP(pz, -200.0f, 200.0f));
        seeds.push_back(s);
    }
    // le popolazioni volanti rinascono sul posto, vicino ai fiori
    int bf_n = CLAMP((int)state.get("bf", 6), 0, BF_MAX);
    butterflies.clear();
    for (int i = 0; i < bf_n; i++) {
        spawn_butterfly(false);
    }
    int ff_n = CLAMP((int)state.get("ff", 8), 0, FF_MAX);
    fireflies.clear();
    for (int i = 0; i < ff_n; i++) {
        Firefly f;
        float a = UtilityFunctions::randf() * Math::TAU;
        f.home = pond_center + Vector3(Math::cos(a), 0.0, Math::sin(a)) *
                UtilityFunctions::randf_range(1.0, pond_radius + 1.5f);
        f.casa = f.home;
        f.pos = f.home + Vector3(0, 0.7, 0);
        f.phase = UtilityFunctions::randf();
        f.blink_offset = UtilityFunctions::randf();
        fireflies.push_back(f);
    }
    push_flowers();
}

// ------------------------------------------------------------ debug CLI

// Quel che è finito nel MultiMesh per l'istanza i. Serve alla verifica
// headless: là il RenderingServer è finto e MultiMesh::get_instance_*
// restituisce sempre zero, quindi senza questa finestra l'unico modo di
// controllare cosa arriva allo shader sarebbe rileggere il sorgente — e un
// test che legge il sorgente resta verde su un ramo che non gira mai.
Dictionary EcosystemManager::debug_farfalla(int i) const {
    Dictionary d;
    if (i < 0 || i >= (int)butterflies.size()) return d;
    d["pos"] = butterflies[i].pos;
    d["shader_x"] = butterflies[i].ultimo_custom;
    return d;
}

Dictionary EcosystemManager::debug_lucciola(int i) const {
    Dictionary d;
    if (i < 0 || i >= (int)fireflies.size()) return d;
    d["pos"] = fireflies[i].pos;
    d["shader_x"] = fireflies[i].ultimo_custom;
    return d;
}

void EcosystemManager::debug_burst() {
    // uno stato ricco all'istante, per gli screenshot: fiori selvatici
    // maturi attorno alle fonti, farfalle, semi coi passerotti già a tavola
    for (int i = 0; i < 60 && (int)wildflowers.size() < WF_MAX; i++) {
        Vector3 base = random_flower_point();
        float a = UtilityFunctions::randf() * Math::TAU;
        Vector3 p = base + Vector3(Math::cos(a), 0.0, Math::sin(a)) *
                UtilityFunctions::randf_range(0.8, 3.2);
        if (ground_ok(p)) {
            Wildflower w;
            w.pos = p;
            w.maturity = UtilityFunctions::randf_range(0.55, 1.0);
            w.kind = (int)UtilityFunctions::randi_range(0, 3);
            wildflowers.push_back(w);
        }
    }
    while ((int)butterflies.size() < 22) {
        spawn_butterfly(false);
    }
    // e un paio di passerotti già a tavola sui semi
    for (int i = 0; i < 2 && i < (int)seeds.size() && (int)sparrows.size() < SPARROW_MAX; i++) {
        Sparrow s;
        s.pos = seeds[i].pos;
        s.state = 1;
        s.timer = 8.0f;
        s.seed_idx = i;
        s.id = sparrow_next_id++;
        sparrows.push_back(s);
    }
    push_flowers();
}
