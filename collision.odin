package main

import "core:math/linalg/glsl"

Sphere :: struct {
	pos:    glsl.vec3,
	radius: f32,
}

Capsule :: struct {
	a:      glsl.vec3,
	b:      glsl.vec3,
	radius: f32,
}


check_aabb_aabb :: proc(a: AABB, b: AABB) -> bool {
	if a.max.x < b.min.x || a.min.x > b.max.x do return false
	if a.max.y < b.min.y || a.min.y > b.max.y do return false
	if a.max.z < b.min.z || a.min.z > b.max.z do return false
	return true
}

check_aabb_sphere :: proc(a: AABB, b: Sphere) {

}

check_sphere_sphere :: proc(a: Sphere, b: Sphere) -> bool {
	return glsl.distance_vec3(a.pos, b.pos) < a.radius + b.radius
}
