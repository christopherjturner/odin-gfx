package main

import "core:fmt"
import "core:math/linalg/glsl"

import "shaders"
import "shapes"

import sg "sokol/gfx"

// TODO:
// 1. add lighting/fog support into shader
// 2. switch to array textures
// 3. create decal instances instead of a single hard-coded one

Decal :: struct {
	transform:     Transform,
	texture_index: int,
}

Decal_Render :: struct {
	bind:  sg.Bindings,
	pip:   sg.Pipeline,
	decal: Decal, // TEMP: we'll redefine this later to not be AA etc...
}

init_decals :: proc(depth_tex: ^sg.Image) -> Decal_Render {
	decals: Decal_Render

	// Load the texture map
	texture := get_texture(&state.textures, "./texture.png")

	decals.bind.views[shaders.VIEW_u_decal_tex] = sg.make_view({texture = {image = texture}})
	decals.bind.samplers[shaders.SMP_u_decal_smp] = sg.make_sampler({})

	decals.bind.views[shaders.VIEW_u_decal_depth_tex] = sg.make_view(
		{texture = {image = depth_tex^}, label = "decal_depth"},
	)

	depth_sampler_desc := sg.Sampler_Desc {
		min_filter = .NEAREST,
		mag_filter = .NEAREST,
		wrap_u     = .CLAMP_TO_EDGE,
		wrap_v     = .CLAMP_TO_EDGE,
	}
	decals.bind.samplers[shaders.SMP_u_decal_depth_smp] = sg.make_sampler(depth_sampler_desc)

	decals.bind.vertex_buffers[0] = sg.make_buffer(
		{
			data = {
				ptr = &shapes.unit_cube_vertices[0],
				size = len(shapes.unit_cube_vertices) * size_of(shapes.Vertex_Pos),
			},
			label = "decal-vertex-buffer",
		},
	)

	decals.bind.index_buffer = sg.make_buffer(
		{
			usage = {index_buffer = true},
			data = {
				ptr = &shapes.full_cube_indices[0],
				size = len(shapes.full_cube_indices) * size_of(u16),
			},
		},
	)

	decals.pip = sg.make_pipeline(
		{
			label = "decals",
			depth = {write_enabled = false, compare = .LESS_EQUAL},
			shader = sg.make_shader(shaders.decal_shader_desc(sg.query_backend())),
			cull_mode = .NONE,
			face_winding = .CCW,
			index_type = .UINT16,
			layout = {attrs = {shaders.ATTR_aabb_pos = {buffer_index = 0, format = .FLOAT3}}},
		},
	)

	decals.decal = Decal {
		transform = {pos = {5, -5, 5}, scale = {1, 0.25, 1}},
	}

	return decals
}

draw_decals :: proc(decal_renderer: ^Decal_Render, cam: ^Camera, dt: f32) {

	// temp
	speed :: 10.0

	height, normal := get_terrain_sample(
		&state.terrain,
		decal_renderer.decal.transform.pos.x,
		decal_renderer.decal.transform.pos.z,
	)

	decal_renderer.decal.transform.pos.y = height
	decal_renderer.decal.transform.rot = quat_from_normal(normal)

	if action_down(&state.input, .EditLeft) {
		decal_renderer.decal.transform.pos.x -= (speed * dt)
	}
	if action_down(&state.input, .EditRight) {
		decal_renderer.decal.transform.pos.x += (speed * dt)
	}
	if action_down(&state.input, .EditForward) {
		decal_renderer.decal.transform.pos.z += (speed * dt)
	}
	if action_down(&state.input, .EditBackward) {
		decal_renderer.decal.transform.pos.z -= (speed * dt)
	}

	view_proj := get_view_proj(cam)
	model_mat := model_matrix_from_transform(decal_renderer.decal.transform)

	// 1. Calculate camera inverse for world reconstruction
	inv_vp := glsl.inverse_mat4(get_view_proj(cam))

	// 2. Calculate model inverse to transform world -> decal local space
	// TODO: this only needs updating if the thing moves
	inv_model := glsl.inverse_mat4(model_matrix_from_transform(decal_renderer.decal.transform))

	vs_uniforms := shaders.Decal_Vs_Params {
		u_view_proj = transmute([16]f32)view_proj,
		u_model     = transmute([16]f32)model_mat,
	}
	fs_uniforms := shaders.Decal_Fs_Params {
		u_inv_view_proj  = transmute([16]f32)inv_vp,
		u_world_to_decal = transmute([16]f32)inv_model,
		u_screen_size    = {OFFSCREEN_WIDTH, OFFSCREEN_HEIGHT},
	}

	sg.apply_pipeline(decal_renderer.pip)
	sg.apply_bindings(decal_renderer.bind)
	sg.apply_uniforms(
		shaders.UB_decal_vs_params,
		{ptr = &vs_uniforms, size = size_of(vs_uniforms)},
	)
	sg.apply_uniforms(
		shaders.UB_decal_fs_params,
		{ptr = &fs_uniforms, size = size_of(fs_uniforms)},
	)

	sg.draw(0, len(shapes.full_cube_indices), 1)
}
