package main

import "core:fmt"
import "core:math/linalg/glsl"
import img "vendor:stb/image"
import sg "./sokol/gfx"
import sgl "./sokol/gl"

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
    mesh_vb, mesh_ib, mesh_ibc := load_mesh("./assets/npc.glb")

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

    // Texture loader
    // TODO: centralize texture loading since we're repeating this alot
    t_width, t_height, t_chan: i32
    pixels := img.load("./assets/textures/npc1.png", &t_width, &t_height, &t_chan, 4)
    if pixels == nil {
        panic("image failed to load")
    }
    defer img.image_free(pixels)

    img_desc := sg.Image_Desc {
        width        = t_width,
        height       = t_height,
        pixel_format = .RGBA8,
    }

    img_desc.data.mip_levels[0] = {
        ptr  = pixels,
        size = uint(t_width * t_height * 4),
    }

    mesh_renderer.bind.views[shaders.VIEW_mesh_tex] = sg.make_view({
        texture = {
            image = sg.make_image(img_desc)
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
    h         := get_terrain_height(&state.terrain, 0, 0) + 4.0
    model_mat := glsl.identity(glsl.mat4) * glsl.mat4Translate({0, h, 0})
    view_proj := get_view_proj(camera)
    mvp       := view_proj * model_mat

    vs_params := shaders.Mesh_Vs_Params {
        mvp   = transmute([16]f32)mvp,
        model = transmute([16]f32)model_mat,
    }
    sg.apply_uniforms(shaders.UB_mesh_vs_params, { ptr = &vs_params, size = size_of(vs_params) })
    sg.draw(0, mesh_renderer.models[0].idx_count, 1)
}
