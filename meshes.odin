package main

import "core:math/linalg/glsl"

import "./shaders"
import sg "./sokol/gfx"

// Animated meshes

AnimatedModel :: struct {
	mesh:        ^AnimatedMesh,
	transform:   Transform,
	vert_offset: int,
	idx_offset:  int,
	animator:    ^Animator,
}

Mesh_Renderer :: struct {
	pip:    sg.Pipeline,
	bind:   sg.Bindings,
	models: [1]AnimatedModel,
}


// Non-animated

StaticModel :: struct {
	mesh:        ^StaticMesh,
	transform:   Transform,
	vert_offset: int,
	idx_offset:  int,
}

Static_Mesh_Renderer :: struct {
	pip:    sg.Pipeline,
	bind:   sg.Bindings,
	models: []StaticModel,
}


MegaBuffer :: struct {
	vertex_buffer: sg.Buffer,
	index_buffer:  sg.Buffer,
	meshes:        struct {
		id:            int,
		vertex_offset: int,
		vertex_count:  int,
		index_offset:  int,
		index_count:   int,
		material:      int,
		aabb:          AABB, // TODO: maybe merge colliders into a single struct, aabb, sphere, opt mesh collider?
	},
	// TODO: maybe have a lookup by name table or something?
	// maybe have the texture array here too, or at least a reference to it
}

init_meshes :: proc() -> Mesh_Renderer {
	mesh_renderer: Mesh_Renderer

	// TODO: dynamically load the mesh_renderer from data.
	// TODO: pack all the mesh_renderer into a single vertex bufffer.
	mesh := load_mesh("./assets/meshes/pigeon1.glb")

	mesh_renderer.bind.vertex_buffers[0] = mesh.vertex_buffer
	mesh_renderer.bind.index_buffer = mesh.index_buffer

	mesh_renderer.models[0].mesh = mesh

	mesh_renderer.models[0].animator = init_animator(mesh, context.allocator)

	mesh_renderer.models[0].transform.pos = {3, 4, 3}
	mesh_renderer.models[0].transform.rot = quaternion(w = 1, x = 0, y = 0, z = 0)
	mesh_renderer.models[0].transform.scale = {0.1, 0.1, 0.1}

	shader := sg.make_shader(shaders.meshshader_shader_desc(sg.query_backend()))
	mesh_renderer.pip = sg.make_pipeline(
	{
		shader = shader,
		layout = {
			attrs = {
				shaders.ATTR_meshshader_position = {format = .FLOAT3},
				shaders.ATTR_meshshader_texcoord0 = {format = .FLOAT2},
				shaders.ATTR_meshshader_normal = {format = .FLOAT3},
				shaders.ATTR_meshshader_joints = {format = .UINT4},
				shaders.ATTR_meshshader_weights = {format = .FLOAT4},
			},
		},
		index_type = .UINT16,
		face_winding = .CCW, // gltf vs sokol quirk
		cull_mode = .BACK,
		depth = {compare = .LESS_EQUAL, write_enabled = true},
	},
	)

	texture := load_texture("./assets/meshes/pigeon1/textures/my_67_baseColor.png")
	mesh_renderer.bind.views[shaders.VIEW_mesh_tex] = sg.make_view({texture = {image = texture}})

	mesh_renderer.bind.samplers[shaders.SMP_mesh_smp] = sg.make_sampler({})
	return mesh_renderer
}


// TODO: manage a list of active mesh_renderer and draw all of the in one go.
draw_meshes :: proc(mesh_renderer: ^Mesh_Renderer, camera: ^Camera, dt: f32) {
	sg.apply_pipeline(mesh_renderer.pip)
	sg.apply_bindings(mesh_renderer.bind)

	view_proj := get_view_proj(camera)
	model_mat := model_matrix_from_transform(mesh_renderer.models[0].transform)

	update_animation(&mesh_renderer.models[0], dt)

	vs_params := shaders.Mesh_Vs_Params {
		view_proj     = transmute([16]f32)view_proj,
		model         = transmute([16]f32)model_mat,
		ambient_color = state.sky.state.now.ambient_color,
		sun_color     = state.sky.state.now.sun_color, // * state.sky.state.now.sun_intensity,
		u_sun_dir     = state.sky.state.sun_dir,
		u_joints      = transmute([64][16]f32)mesh_renderer.models[0].animator.skin_mats,
	}
	sg.apply_uniforms(shaders.UB_mesh_vs_params, {ptr = &vs_params, size = size_of(vs_params)})
	sg.draw(0, mesh_renderer.models[0].mesh.index_count, 1)
	add_aabb(state.aabb, mesh_renderer.models[0].mesh.aabb, mesh_renderer.models[0].transform)
}


init_static_meshes :: proc() -> Static_Mesh_Renderer {
	static_mesh_renderer: Static_Mesh_Renderer

	// TODO: dynamically load the mesh_renderer from data.
	// TODO: pack all the mesh_renderer into a single vertex bufffer.
	mesh := load_static_mesh("./assets/meshes/test1.glb")
	texture := load_texture("./assets/grass.png")

	static_mesh_renderer.bind.vertex_buffers[0] = mesh.vertex_buffer
	static_mesh_renderer.bind.index_buffer = mesh.index_buffer

	static_mesh_renderer.models = make([]StaticModel, 1)
	static_mesh_renderer.models[0].mesh = mesh

	static_mesh_renderer.models[0].transform.pos = {0, 0, 0}
	static_mesh_renderer.models[0].transform.rot = quaternion(w = 1, x = 0, y = 0, z = 0)
	static_mesh_renderer.models[0].transform.scale = {1, 1, 1}

	shader := sg.make_shader(shaders.staticmeshshader_shader_desc(sg.query_backend()))
	static_mesh_renderer.pip = sg.make_pipeline(
	{
		shader = shader,
		layout = {
			attrs = {
				shaders.ATTR_staticmeshshader_position = {format = .FLOAT3},
				shaders.ATTR_staticmeshshader_texcoord0 = {format = .FLOAT2},
				shaders.ATTR_staticmeshshader_normal = {format = .FLOAT3},
			},
		},
		index_type = .UINT16,
		face_winding = .CCW, // gltf vs sokol quirk
		cull_mode = .NONE,
		depth = {compare = .LESS_EQUAL, write_enabled = true},
	},
	)

	static_mesh_renderer.bind.views[shaders.VIEW_mesh_tex] = sg.make_view(
		{texture = {image = texture}},
	)
	static_mesh_renderer.bind.samplers[shaders.SMP_mesh_smp] = sg.make_sampler({})
	return static_mesh_renderer
}


// TODO: manage a list of active mesh_renderer and draw all of the in one go.
draw_static_meshes :: proc(static_mesh_renderer: ^Static_Mesh_Renderer, camera: ^Camera, dt: f32) {
	sg.apply_pipeline(static_mesh_renderer.pip)
	sg.apply_bindings(static_mesh_renderer.bind)

	view_proj := get_view_proj(camera)
	model_mat := model_matrix_from_transform(static_mesh_renderer.models[0].transform)

	vs_params := shaders.Static_Mesh_Vs_Params {
		view_proj     = transmute([16]f32)view_proj,
		model         = transmute([16]f32)model_mat,
		ambient_color = state.sky.state.now.ambient_color,
		sun_color     = state.sky.state.now.sun_color, // * state.sky.state.now.sun_intensity,
		u_sun_dir     = state.sky.state.sun_dir,
	}
	sg.apply_uniforms(
		shaders.UB_static_mesh_vs_params,
		{ptr = &vs_params, size = size_of(vs_params)},
	)
	sg.draw(0, static_mesh_renderer.models[0].mesh.index_count, 1)
	add_aabb(
		state.aabb,
		static_mesh_renderer.models[0].mesh.aabb,
		static_mesh_renderer.models[0].transform,
	)
}
