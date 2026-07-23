#ifndef GRID_MANAGER_H
#define GRID_MANAGER_H

#include <godot_cpp/classes/node3d.hpp>

namespace godot {

class GridManager : public Node3D {
    GDCLASS(GridManager, Node3D)

private:
    float grid_size = 2.0; // 2x2 metri per ogni "cella" in stile AC

protected:
    static void _bind_methods();

public:
    GridManager();
    ~GridManager();

    float get_grid_size() const;
    void set_grid_size(float p_size);

    // Converte una posizione arbitraria nello spazio mondo nella coordinata centrale della cella griglia più vicina
    Vector3 snap_to_grid(const Vector3 &position) const;
};

} // namespace godot

#endif // GRID_MANAGER_H
