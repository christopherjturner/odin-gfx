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

check_aabb_sphere :: proc(a: AABB, b: Sphere) -> bool {
	nearest_point := glsl.max(a.min, glsl.min(a.max, b.pos))
	return glsl.distance_vec3(nearest_point, b.pos) < (b.radius * b.radius)
}

check_sphere_sphere :: proc(a: Sphere, b: Sphere) -> bool {
	return glsl.distance_vec3(a.pos, b.pos) < a.radius + b.radius
}

aabb_transform_fast :: proc(local_aabb: AABB, model_matrix: glsl.mat4) -> AABB {
	// Start the world bounds using the translation component (column 3 of the matrix)
	world_min := model_matrix[3].xyz
	world_max := model_matrix[3].xyz

	// Loop through rows/columns to project local bounds onto world axes
	for i in 0 ..< 3 {
		for j in 0 ..< 3 {
			a := model_matrix[j][i] * local_aabb.min[j]
			b := model_matrix[j][i] * local_aabb.max[j]

			if a < b {
				world_min[i] += a
				world_max[i] += b
			} else {
				world_min[i] += b
				world_max[i] += a
			}
		}
	}

	return AABB{min = world_min, max = world_max}
}
