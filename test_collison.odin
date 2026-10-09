package main

import "core:testing"

@(test)
test_aabb_vs_sphere :: proc(t: ^testing.T) {
	aabb := AABB {
		min = {2, 2, 2},
		max = {5, 5, 5},
	}

	sphere := Sphere {
		radius = 1.5,
		pos    = {0, 0, 0},
	}

	assert(check_aabb_sphere(aabb, sphere) == false)

	sphere.pos = {1, 1, 1}
	assert(check_aabb_sphere(aabb, sphere) == true)

	sphere.pos = {3, 3, 3}
	assert(check_aabb_sphere(aabb, sphere) == true)
}
