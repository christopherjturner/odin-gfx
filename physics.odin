package main

import "core:math/linalg/glsl"


Entity :: struct {
    pos: glsl.vec3,
    vel: glsl.vec3,
    dir: f32,
    height: f32,
    is_grounded: bool,
    acceleration_speed: f32,
}

updatePhysics :: proc (entity: ^Entity, dt: f32) {
    terrain_height := get_terrain_height(&state.terrain, entity.pos.x, entity.pos.z)
    terrain_normal := [3]f32{0,1,0} // TODO: get from terrain

    if entity.pos.y > terrain_height + 0.1 {
        // Apply standard gravity in air
        entity.vel.y -= 9.8 * dt
        entity.is_grounded = false
    } else {
        // Project velocity onto terrain slope
        entity.pos.y = terrain_height
        entity.vel = project_on_plane(entity.vel, terrain_normal)

        // Add downhill acceleration
        gravity_dir := [3]f32{0, -1, 0}
        downhill := gravity_dir - (glsl.dot(gravity_dir, terrain_normal) * terrain_normal)
        entity.vel += downhill * entity.acceleration_speed * dt
        entity.is_grounded = true
    }
    entity.pos += entity.vel * dt
}

project_on_plane :: proc (vel: glsl.vec3, normal: glsl.vec3) -> glsl.vec3 {
    n_norm := glsl.normalize(normal)
    dot := glsl.dot(vel, n_norm)
    return vel - (n_norm * dot)
}
