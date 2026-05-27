package main

import "core:fmt"

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
    pip:       sg.Pipeline,
    bind:      sg.Bindings,
    instances: [MAX_BILLBOARDS]Billboard_Instance,
    active:    uint,
}

instance_buffer_desc := sg.Buffer_Desc{
    size = MAX_BILLBOARDS * size_of(Billboard_Instance),
    usage = {
        vertex_buffer = true,
        stream_update = true,
    },
    label = "billboard-instance-buffer",
}
/*
billboard_quad := [6]Billboard_Vertex{
    {{-0.5, -0.5, 0.0}, {0, 0}}, {{ 0.5, -0.5, 0.0}, {1, 0}}, {{ 0.5,  0.5, 0.0}, {1, 1}},
    {{-0.5, -0.5, 0.0}, {0, 0}}, {{ 0.5,  0.5, 0.0}, {1, 1}}, {{-0.5,  0.5, 0.0}, {0, 1}},
}*/


billboard_quad := [6]Billboard_Vertex{
    {{0.0, 0.0, 0.0}, {0, 0}}, {{ 1.0, 0.0, 0.0}, {1, 0}}, {{ 1.0,  1.0, 0.0}, {1, 1}},
    {{0.0, 0.0, 0.0}, {0, 0}}, {{ 1.0, 1.0, 0.0}, {1, 1}}, {{ 0.0,  1.0, 0.0}, {0, 1}},
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

    push_billboard(&billboard, { {4, 0.0, 4}, 5.0, {1, 1, 1, 1}, 0 })
    push_billboard(&billboard, { {-10, -10.0, 0}, 4.0, {1, 1, 1, 1}, 0 })
    push_billboard(&billboard, { {-3, -10.0, 4}, 5.0, {1, 1, 1, 1}, 0 })

    return billboard
}

draw_billboards :: proc(bb: ^Billboard_Renderer, cam: ^Camera) {

    view_proj := get_view_proj(cam)
    uniforms := shaders.Billboard_Params{
        view_proj     = transmute([16]f32)view_proj,
        ambient_color = state.sky.state.now.ambient_color,
    }


    // update instances (these arent dynamic yet, but they will be!)
    sg.update_buffer(bb.bind.vertex_buffers[1], {
        ptr  = raw_data(bb.instances[0:bb.active]), // TODO: be careful about the pointers if/when we switch to a slice
        size = bb.active * size_of(Billboard_Instance),
    })

    sg.apply_pipeline(bb.pip)
    sg.apply_bindings(bb.bind)
    sg.apply_uniforms(shaders.UB_billboard_params, { ptr = &uniforms, size = size_of(uniforms) })
    sg.draw(0, 6, bb.active)
}

clear_billboards :: proc(bb: ^Billboard_Renderer) {
    bb.active = 0
}

push_billboard :: proc(bb :^Billboard_Renderer, instance: Billboard_Instance) {
    bb.instances[bb.active] = instance
    fmt.printfln("added %d %v", bb.active, bb.instances[bb.active])
    bb.active += 1
}
