package main

import "core:math/linalg/glsl"

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
	yaw_q   := glsl.quatAxisAngle({0, 1, 0}, yaw)
	pitch_q := glsl.quatAxisAngle({1, 0, 0}, pitch)

	return glsl.normalize(yaw_q * pitch_q)
}


// Verts
/*
Billboard_Vertex :: struct {
    pos: [3]f32,
    uv:  [2]f32,
}

AABB_Vertex :: struct {
    pos: [3]f32
}

Grid_Vertex :: struct {
    pos: [3]f32,
    color: [4]f32,
}

MeshVert :: struct {
	pos:     [3]f32,
	uv:      [2]f32,
	normal:  [3]f32,
	joints:  [4]u32,
	weights: [4]f32,
}

StaticMeshVert :: struct {
	pos:     [3]f32,
	uv:      [2]f32,
	normal:  [3]f32,
}

Sky_Vertex :: struct {
    pos: [3]f32,
}

Terrain_Vertex :: struct {
    height: f32,
    normal: [3]f32,
    color:  [3]f32,
}

UI_Vertex :: struct {
    pos:   [2]f32,
    uv:    [2]f32,
    color: [4]f32,
}

// just points
vert : pos   // sky, aabb, debugging ui

// no normals
billboard_vert, pos, col, uv  // bb, stars
coloured_vert:  pos, col,     // grid

// normals
textured_vert:         pos, uv, normal
textured_colored_vert: pos, uv, normal, color
skinned_vert:          pos, uv, normal, joints, weights

// terrain
heightmap vert: height, normal, color
*/
