package main

import "core:fmt"
import "core:math"
import "core:math/linalg/glsl"

import sapp "./sokol/app"
import sg "./sokol/gfx"
import "./shaders"

UI_Vertex :: struct {
    pos:   [2]f32,
    uv:    [2]f32,
    color: [4]f32,
}

Game_UI :: struct {
    pip: sg.Pipeline,
    bind: sg.Bindings,
    verts:       [dynamic]UI_Vertex,
    indicies:    [dynamic]u16,
}


init_game_ui :: proc() -> ^Game_UI {
    ui := new(Game_UI)

    ui_push_quad(ui, 0, 0, 64, 64, { 1.0, 0.0, 1.0, 1.0 })
    ui_push_quad(ui, 4,4, 64-8, 64-8, { 0.0, 0.0, 1.0, 1.0 })

    // vertex buffer
    ui.bind.vertex_buffers[0] = sg.make_buffer({
        data = { ptr = raw_data(ui.verts), size = len(ui.verts) * size_of(UI_Vertex) },
        usage = {
            vertex_buffer = true,
            stream_update = true,
        },
        label = "ui-vertex-buffer",
    })

    // index buffer
    ui.bind.index_buffer = sg.make_buffer({
        data = { ptr = raw_data(ui.indicies), size = len(ui.indicies) * size_of(u16) },
        usage = {
            index_buffer  = true,
            stream_update = true,
        },
        label = "ui-index-buffer",
    })

    ui.pip = sg.make_pipeline({
        shader = sg.make_shader(shaders.game_ui_shader_desc(sg.query_backend())),
        index_type = .UINT16,
        layout = {
            buffers = {
                0 = { stride = size_of(UI_Vertex), },
                1 = { stride = size_of(u16), },
            },
            attrs = {
                shaders.ATTR_game_ui_pos    = { format = .FLOAT2 },
                shaders.ATTR_game_ui_uv0    = { format = .FLOAT2 },
                shaders.ATTR_game_ui_color0 = { format = .FLOAT4 },
            },
        },
        colors = {
            0 = {
                blend = {
                    enabled = true,
                    src_factor_rgb   = .SRC_ALPHA,
                    dst_factor_rgb   = .ONE_MINUS_SRC_ALPHA,
                    op_rgb           = .ADD,
                    src_factor_alpha = .ONE,
                    dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
                    op_alpha         = .ADD,
                },
            },
        },
        depth = {
            write_enabled = false,
            compare       = .ALWAYS,
        },
        cull_mode = .NONE,
    })

    return ui
}

draw_game_ui :: proc(ui: ^Game_UI) {

    uniforms := shaders.Game_Ui_Vs_Params {
        screen_size = { sapp.widthf() * 0.5, sapp.heightf() * 0.5 },
    }

    sg.apply_pipeline(ui.pip)
    sg.apply_bindings(ui.bind)
    sg.apply_uniforms(shaders.UB_game_ui_vs_params, { ptr = &uniforms, size = size_of(uniforms) })
    sg.draw(0, i32(len(ui.indicies)), 1)
}


// UI helpers
ui_reset :: proc(ui: ^Game_UI) {
    clear(&ui.verts)
    clear(&ui.indicies)
}


ui_push_quad :: proc(ui: ^Game_UI, x: f32, y: f32, w: f32, h: f32, color: [4]f32) {
    base := u16(len(ui.verts))
    append(&ui.verts,
           UI_Vertex{ { x,   y   }, {0, 0}, {1,0,0,1} }, //top left
           UI_Vertex{ { x,   y+h }, {0, 1}, {0,1,0,1} }, // bottom left
           UI_Vertex{ { x+w, y   }, {1, 0}, {0,0,1,1} }, // top right
           UI_Vertex{ { x+w, y+h }, {1, 1}, {1,1,1,1} }, // bottom right
    )

    append(&ui.indicies,
           base+0, base+1, base+2,
           base+1, base+3, base+2,
    )
}
