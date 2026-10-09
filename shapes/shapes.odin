package shapes

Vertex_Pos :: struct {
	pos: [3]f32,
}

Vertex_Pos_Uv :: struct {
	pos: [3]f32,
    uv:  [2]f32,
}

quad_unindexed_uv := [6]Vertex_Pos_Uv{
    {{-0.5, 0, 0.0}, {0, 0}}, {{ 0.5, 0, 0.0}, {1, 0}}, {{ 0.5,  1, 0.0}, {1, 1}},
    {{-0.5, 0, 0.0}, {0, 0}}, {{ 0.5, 1, 0.0}, {1, 1}}, {{-0.5,  1, 0.0}, {0, 1}},
}

// 8 corners of a unit cube (0 to 1)
unit_cube_vertices := [8]Vertex_Pos {
	{{0, 0, 0}},
	{{1, 0, 0}},
	{{1, 1, 0}},
	{{0, 1, 0}}, // 3
	{{0, 0, 1}}, // 4
	{{1, 0, 1}}, // 5
	{{1, 1, 1}}, // 6
	{{0, 1, 1}}, // 7
}

// 12 lines (24 indices) to form the wireframe
unit_cube_indices := [24]u16 {
	0,
	1,
	1,
	2,
	2,
	3,
	3,
	0, // Bottom
	4,
	5,
	5,
	6,
	6,
	7,
	7,
	4, // Top
	0,
	4,
	1,
	5,
	2,
	6,
	3,
	7, // Vertical pillars
}

full_cube_indices := [36]u16 {
	0,
	1,
	2,
	2,
	3,
	0, // front
	4,
	5,
	6,
	6,
	7,
	4, // back
	4,
	0,
	3,
	3,
	7,
	4, // left
	1,
	5,
	6,
	6,
	2,
	1, // right
	3,
	2,
	6,
	6,
	7,
	3, // top
	4,
	5,
	1,
	1,
	0,
	4, // bottom
}
