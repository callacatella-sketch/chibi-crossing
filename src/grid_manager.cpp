#include "grid_manager.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

using namespace godot;

void GridManager::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_grid_size"), &GridManager::get_grid_size);
    ClassDB::bind_method(D_METHOD("set_grid_size", "p_size"), &GridManager::set_grid_size);
    ClassDB::bind_method(D_METHOD("snap_to_grid", "position"), &GridManager::snap_to_grid);

    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "grid_size"), "set_grid_size", "get_grid_size");
}

GridManager::GridManager() {}

GridManager::~GridManager() {}

float GridManager::get_grid_size() const {
    return grid_size;
}

void GridManager::set_grid_size(float p_size) {
    grid_size = p_size;
}

Vector3 GridManager::snap_to_grid(const Vector3 &position) const {
    if (grid_size <= 0.0) return position;

    float x = std::round(position.x / grid_size) * grid_size;
    float y = position.y; // Mantieni l'altezza invariata (o adattala al terreno se c'è un navmesh)
    float z = std::round(position.z / grid_size) * grid_size;

    return Vector3(x, y, z);
}
