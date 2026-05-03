package main

import "core:fmt"
import "core:math/linalg/glsl"
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
    color: [4]f32,
    layer: f32,
}

Billboard_Renderer :: struct {
    pip:  sg.Pipeline,
    bind: sg.Bindings,
    instances: [1]Billboard_Instance
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
    billboard: Billboard_Renderer

    images := load_array_texture({
        "./assets/textures/tree1.png",
        "./assets/textures/tree2.png",
        "./assets/textures/tree3.png",
    })


    billboard.bind.views[shaders.VIEW_tex] = sg.make_view({
        texture = {
            image = images,
            slices = { base = 0, count = 0 },
        }
    })

    billboard.bind.samplers[shaders.SMP_smp] = sg.make_sampler({})


    // Bind quad and instance buffers
    billboard.bind.vertex_buffers[0] = sg.make_buffer({
        data = {
            ptr = &billboard_quad,
            size = len(billboard_quad) * size_of(Billboard_Vertex)
        }
    })
    billboard.bind.vertex_buffers[1] = sg.make_buffer(instance_buffer_desc)

    // Setup the render pipeline with the billboard shader

    billboard.pip = sg.make_pipeline({
        shader = sg.make_shader(shaders.billboard_shader_desc(sg.query_backend())),
        layout = {
            buffers = {
                0 = { stride = size_of(Billboard_Vertex), }, // Quad
                1 = { stride = size_of(Billboard_Instance), step_func = .PER_INSTANCE },
            },
            attrs = {
                shaders.ATTR_billboard_pos        = { buffer_index = 0, format = .FLOAT3 },
                shaders.ATTR_billboard_uv         = { buffer_index = 0, format = .FLOAT2 },
                shaders.ATTR_billboard_inst_pos   = { buffer_index = 1, format = .FLOAT3 },
                shaders.ATTR_billboard_inst_scale = { buffer_index = 1, format = .FLOAT  },
                shaders.ATTR_billboard_inst_color = { buffer_index = 1, format = .FLOAT4 },
                shaders.ATTR_billboard_inst_layer = { buffer_index = 1, format = .FLOAT  },
            },
        },
        depth = {
            write_enabled = true,
            compare       = .LESS_EQUAL,
        },
    })

    billboard.instances = {
        {{4, 0.5, 4}, 5.0,  {1, 1, 1, 1}, 0}
    }

    return billboard
}

draw_billboards :: proc(bb: ^Billboard_Renderer, cam: ^Camera) {

    vp := get_view_proj(cam)
    uniforms := shaders.Billboard_Params{
        view_proj     = transmute([16]f32)vp,
        ambient_color = state.sky.state.now.ambient_color,
    }


    // update instances (these arent dynamic yet, but they will be!)
    sg.update_buffer(bb.bind.vertex_buffers[1], {
        ptr  = &bb.instances[0], // TODO: be careful about the pointers if/when we switch to a slice
        size = size_of(bb.instances),
    })

    sg.apply_pipeline(bb.pip)
    sg.apply_bindings(bb.bind)
    sg.apply_uniforms(shaders.UB_billboard_params, { ptr = &uniforms, size = size_of(uniforms) })
    sg.draw(0, 6, len(bb.instances))
}
