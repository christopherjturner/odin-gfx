package main

import "core:fmt"
import "core:math/linalg/glsl"
import sg "./sokol/gfx"
import "./shaders"


Mesh_Renderer :: struct {
    pip:      sg.Pipeline,
    bind:     sg.Bindings,
    models:   [1]Model,
}

Model :: struct {
    vert_offset: int,
    vert_count: int,
    idx_offset: int,
    idx_count: i32,
}


init_meshes :: proc() -> Mesh_Renderer {
    mesh_renderer: Mesh_Renderer

    // TODO: dynamically load the mesh_renderer from data.
    // TODO: pack all the mesh_renderer into a single vertex bufffer.
    mesh_vb, mesh_ib, mesh_ibc := load_mesh("./assets/dovecote.glb")

    mesh_renderer.bind.vertex_buffers[0] = mesh_vb
    mesh_renderer.bind.index_buffer = mesh_ib
    mesh_renderer.models[0].idx_count = mesh_ibc

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
        depth = {
            compare = .LESS_EQUAL,
            write_enabled = true,
        },
    })

    texture := load_texture("./assets/textures/dovecote.png")
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
    h         := get_terrain_height(&state.terrain, 0, 0) + 5.0
    model_mat := glsl.identity(glsl.mat4) * glsl.mat4Translate({0, h, 0})
    view_proj := get_view_proj(camera)
    mvp       := view_proj * model_mat

    vs_params := shaders.Mesh_Vs_Params {
        mvp           = transmute([16]f32)mvp,
        model         = transmute([16]f32)model_mat,
        ambient_color = state.sky.state.now.ambient_color,
        sun_color     = state.sky.state.now.sun_color, // * state.sky.state.now.sun_intensity,
        u_sun_dir     = state.sky.state.sun_dir,
    }

    sg.apply_uniforms(shaders.UB_mesh_vs_params, { ptr = &vs_params, size = size_of(vs_params) })
    sg.draw(0, mesh_renderer.models[0].idx_count, 1)
}
