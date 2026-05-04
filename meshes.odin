package main

import "core:fmt"
import "core:math/linalg/glsl"
import sg "./sokol/gfx"
import "./shaders"


Transform :: struct {
    pos: glsl.vec3,
    rot: glsl.quat,
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


Mesh_Renderer :: struct {
    pip:      sg.Pipeline,
    bind:     sg.Bindings,
    models:   [1]Model,
}


Model :: struct {
    mesh: ^Mesh,
    transform: Transform,
    vert_offset: int,
    idx_offset: int,
}



init_meshes :: proc() -> Mesh_Renderer {
    mesh_renderer: Mesh_Renderer

    // TODO: dynamically load the mesh_renderer from data.
    // TODO: pack all the mesh_renderer into a single vertex bufffer.
    mesh := load_mesh("./assets/meshes/pigeon1.glb")

    mesh_renderer.bind.vertex_buffers[0] = mesh.vertex_buffer
    mesh_renderer.bind.index_buffer = mesh.index_buffer

    mesh_renderer.models[0].mesh = mesh

    mesh_renderer.models[0].transform.pos   = {3, 4, 3}
    mesh_renderer.models[0].transform.rot.w = 1
    mesh_renderer.models[0].transform.scale = {0.1, 0.1, 0.1}

    shader := sg.make_shader(shaders.meshshader_shader_desc(sg.query_backend()))
    mesh_renderer.pip = sg.make_pipeline({
        shader = shader,
        layout = {
            attrs = {
                0 = { format = .FLOAT3 }, // ATTR_vs_position
                1 = { format = .FLOAT2 }, // ATTR_vs_texcoord0
                2 = { format = .FLOAT3 }, // ATTR_vs_normal
            },
        },
        index_type = .UINT16,
        cull_mode  = .FRONT,
        depth = {
            compare = .LESS_EQUAL,
            write_enabled = true,
        },
    })

    // TODO: load from the glsl instead
    texture := load_texture("./assets/meshes/pigeon1/textures/my_67_baseColor.png")
    mesh_renderer.bind.views[shaders.VIEW_mesh_tex] = sg.make_view({
        texture = {
            image = texture
        }
    })

    mesh_renderer.bind.samplers[shaders.SMP_mesh_smp] = sg.make_sampler({})

    return mesh_renderer
}


// TODO: manage a list of active mesh_renderer and draw all of the in one go.
draw_meshes :: proc(mesh_renderer: ^Mesh_Renderer, camera: ^Camera) {
    sg.apply_pipeline(mesh_renderer.pip)
    sg.apply_bindings(mesh_renderer.bind)

    // TODO: move this to a per instace field
    // h         := get_terrain_height(&state.terrain, 0, 0) + 5.0
    model_mat := model_matrix_from_transform(mesh_renderer.models[0].transform)
    view_proj := get_view_proj(camera)

    vs_params := shaders.Mesh_Vs_Params {
        view_proj     = transmute([16]f32)view_proj,
        model         = transmute([16]f32)model_mat,
        ambient_color = state.sky.state.now.ambient_color,
        sun_color     = state.sky.state.now.sun_color, // * state.sky.state.now.sun_intensity,
        u_sun_dir     = state.sky.state.sun_dir,
    }

    sg.apply_uniforms(shaders.UB_mesh_vs_params, { ptr = &vs_params, size = size_of(vs_params) })
    sg.draw(0, mesh_renderer.models[0].mesh.index_count, 1)
}
