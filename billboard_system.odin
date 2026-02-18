package main

import "core:fmt"
import "core:math/linalg/glsl"
import img "vendor:stb/image"
import sg "./sokol/gfx"
import "./shaders"

MAX_BILLBOARDS :: 200

Billboard_Vertex :: struct {
    pos: [3]f32,
    uv:  [2]f32,
}

Billboard_Instance :: struct {
    pos:   [3]f32,
    scale: f32,
}

Billboard_Renderer :: struct {
    pip:  sg.Pipeline,
    bind: sg.Bindings,
    instances: [2]Billboard_Instance
}

instance_buffer_desc := sg.Buffer_Desc{
    size = MAX_BILLBOARDS * size_of(Billboard_Instance),
    usage = {
        vertex_buffer = true,
        stream_update = true,
    },
    label = "billboard-instance-buffer",
}

billboard_quad := [6]Billboard_Vertex{
    {{-0.5, -0.5, 0.0}, {0, 0}}, {{ 0.5, -0.5, 0.0}, {1, 0}}, {{ 0.5,  0.5, 0.0}, {1, 1}},
    {{-0.5, -0.5, 0.0}, {0, 0}}, {{ 0.5,  0.5, 0.0}, {1, 1}}, {{-0.5,  0.5, 0.0}, {0, 1}},
}


init_billboards :: proc() -> Billboard_Renderer {
    using shaders
    billboard: Billboard_Renderer

    // Load the billboard texture. This will be a texture array at some point.
    t_width, t_height, t_chan: i32

    pixels := img.load("./assets/billboard.png", &t_width, &t_height, &t_chan, 4)
    if pixels == nil {
        panic("image failed to load")
    }
    defer img.image_free(pixels)
    fmt.printf("texture: %d %d %d", t_width, t_height, t_chan)

    img_desc := sg.Image_Desc {
        width = t_width,
        height = t_height,
        pixel_format = .RGBA8,
    }

    img_desc.data.mip_levels[0] = {
        ptr  = pixels,
        size = uint(t_width * t_height * 4),
    }

    billboard.bind.views[VIEW_tex] = sg.make_view({
        texture = {
            image = sg.make_image(img_desc)
        }
    })

    billboard.bind.samplers[SMP_smp] = sg.make_sampler({})


    // Bind quad and instance buffers
    billboard.bind.vertex_buffers[0] = sg.make_buffer({
        data = { ptr = &billboard_quad, size = len(billboard_quad) * size_of(Billboard_Vertex) },
    })
    billboard.bind.vertex_buffers[1] = sg.make_buffer(instance_buffer_desc)

    // Setup the render pipeline with the billboard shader

    billboard.pip = sg.make_pipeline({
        shader = sg.make_shader(billboard_shader_desc(sg.query_backend())),
        layout = {
            buffers = {
                0 = { stride = size_of(Billboard_Vertex), }, // Quad
                1 = { stride = size_of(Billboard_Instance), step_func = .PER_INSTANCE },
            },
            attrs = {
                ATTR_billboard_pos        = { buffer_index = 0, format = .FLOAT3 },
                ATTR_billboard_uv         = { buffer_index = 0, format = .FLOAT2 },
                ATTR_billboard_inst_pos   = { buffer_index = 1, format = .FLOAT3 },
                ATTR_billboard_inst_scale = { buffer_index = 1, format = .FLOAT  },
            },
        },
        depth = {
            write_enabled = true,
            compare = .LESS_EQUAL,
        },
    })

    billboard.instances = { {{2, 0.5, 2}, 1.0}, {{-1, 1, 1}, 1.0} }

    return billboard
}

draw_billboards :: proc(bb: ^Billboard_Renderer, cam: ^Camera) {
    using shaders
    vp := get_view_proj(cam)
    uniforms := Billboard_Params{
        view_proj = transmute([16]f32)vp,
        ambient_color = state.sky.state.now.ambient_color,
    }


    // update instances (these arent dynamic yet, but they will be!)
    sg.update_buffer(bb.bind.vertex_buffers[1], {
        ptr  = &bb.instances[0], // TODO: be careful about the pointers if/when we switch to a slice
        size = size_of(bb.instances),
    })

    sg.apply_pipeline(bb.pip)
    sg.apply_bindings(bb.bind)
    sg.apply_uniforms(UB_billboard_params, { ptr = &uniforms, size = size_of(uniforms) })
    sg.draw(0, 6, len(bb.instances))
}
