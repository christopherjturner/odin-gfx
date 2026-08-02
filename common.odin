package main

import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:math/rand"

Transform :: struct {
	pos:   glsl.vec3,
	rot:   glsl.quat,
	scale: glsl.vec3,
}

model_matrix_from_transform :: proc(t: Transform) -> glsl.mat4 {
	T := glsl.mat4Translate(t.pos)
	R := glsl.mat4FromQuat(t.rot)
	S := glsl.mat4Scale(t.scale)

	return T * R * S
}

quat_from_pitch_yaw :: proc(pitch, yaw: f32) -> glsl.quat {
	yaw_q := glsl.quatAxisAngle({0, 1, 0}, yaw)
	pitch_q := glsl.quatAxisAngle({1, 0, 0}, pitch)

	return glsl.normalize(yaw_q * pitch_q)
}

quat_from_normal :: proc(normal: glsl.vec3) -> glsl.quat {
	n := glsl.normalize(normal)
	up := glsl.vec3{0.0, 1.0, 0.0}

	dot := glsl.dot(up, n)

	// 3. Handle edge case: target is exactly opposite to our reference up vector
	if dot < -0.99999 {
		// Rotate 180 degrees around an arbitrary orthogonal fallback axis (Local Right)
		return quaternion(w = 1, x = 0, y = 1.0, z = 0)
	}

	// 4. Handle edgecase: target is already aligned perfectly with our reference up vector
	if dot > 0.99999 {
		return quaternion128(1)
	}

	// 5. Standard Shortest-Arc Rotation Calculation
	axis := linalg.cross(up, n)

	q := quaternion(w = 1.0 + dot, x = axis.x, y = axis.y, z = axis.z)

	// Normalize to form a valid unit quaternion rotation
	return glsl.normalize(q)
}

rand_vec3_direction_rejection :: proc() -> [3]f32 {
	x, y, z: f32
	lensq: f32

	// Loop until we find a point inside the unit sphere (excluding the origin)
	for {
		x = rand.float32_range(-1.0, 1.0)
		y = rand.float32_range(-1.0, 1.0)
		z = rand.float32_range(-1.0, 1.0)

		lensq = x * x + y * y + z * z
		if lensq > 0.0001 && lensq <= 1.0 do break
	}

	// Scale to unit length
	inv_len := 1.0 / math.sqrt(lensq)
	return [3]f32{x * inv_len, y * inv_len, z * inv_len}
}

rand_cone_z :: proc(half_angle_rad: f32) -> [3]f32 {
	// Cosine of the max angle gives us the minimum z threshold
	z_min := math.cos(half_angle_rad)
	z := rand.float32_range(z_min, 1.0)

	// Uniformly distribute the rotation around the Z axis
	phi := rand.float32_range(0.0, 2.0 * math.PI)

	// Project onto the sphere surface
	r := math.sqrt(1.0 - z * z)
	x := r * math.cos(phi)
	y := r * math.sin(phi)

	return [3]f32{x, y, z}
}

rand_direction_in_cone :: proc(forward_dir: [3]f32, half_angle_rad: f32) -> [3]f32 {
	// 1. Get a random vector in a cone pointing along world Z
	local_dir := rand_cone_z(half_angle_rad)

	// 2. Ensure target forward is normalized
	dir := glsl.normalize(forward_dir) // implementation depends on your math library

	// 3. Create a coordinate frame where our target 'dir' acts as the Z axis
	// Pick a non-parallel axis to start the cross products
	up := math.abs(dir.z) < 0.999 ? [3]f32{0, 0, 1} : [3]f32{1, 0, 0}

	right := glsl.normalize(glsl.cross(up, dir))
	up_prime := glsl.cross(dir, right)

	// 4. Transform the local Z-aligned vector into our new frame
	out_dir: [3]f32
	out_dir.x = right.x * local_dir.x + up_prime.x * local_dir.y + dir.x * local_dir.z
	out_dir.y = right.y * local_dir.x + up_prime.y * local_dir.y + dir.y * local_dir.z
	out_dir.z = right.z * local_dir.x + up_prime.z * local_dir.y + dir.z * local_dir.z

	return out_dir
}
