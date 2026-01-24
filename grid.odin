package main

import sg "./sokol/gfx"
import "./shaders"

init_grid :: proc() {
    using shaders
    grid_verts, grid_count := create_grid()
    state.grid.count = grid_count
    state.grid.bind.vertex_buffers[0] = grid_verts
    state.grid.pip = sg.make_pipeline({
        shader = sg.make_shader(shaders.grid_shader_desc(sg.query_backend())),
        layout = {
            attrs = {
                shaders.ATTR_grid_pos    = { format = .FLOAT3 },
                shaders.ATTR_grid_color0 = { format = .FLOAT4 },
            },
        },
        primitive_type = .LINES,
        depth = {
            compare = .LESS_EQUAL,
            write_enabled = true,
        },
    })
}

draw_grid :: proc(cam: ^Camera) {
    using shaders

    sg.apply_pipeline(state.grid.pip)
    sg.apply_bindings(state.grid.bind)
    grid_vs: Vs_Params

    view_proj := get_view_proj(cam)
    grid_vs.mvp = transmute([16]f32)view_proj // Grid doesn't move/rotate
    sg.apply_uniforms(UB_grid_vs_params, { ptr = &grid_vs, size = size_of(grid_vs) })
    sg.draw(0, state.grid.count, 1)
}

create_grid :: proc() -> (sg.Buffer, i32) {
    verts := [dynamic]Grid_Vertex{}
    size  := f32(10.0)
    step  := f32(1.0)
    for i := -size; i <= size; i += step {
        // Lines along X
        append(&verts, Grid_Vertex{{-size, 0, i}, 0xFF666666})
        append(&verts, Grid_Vertex{{ size, 0, i}, 0xFF666666})
        // Lines along Z
        append(&verts, Grid_Vertex{{i, 0, -size}, 0xFF666666})
        append(&verts, Grid_Vertex{{i, 0,  size}, 0xFF666666})
    }
    buf := sg.make_buffer({
        data = { ptr = &verts[0], size = len(verts) * size_of(Grid_Vertex) },
    })
    return buf, i32(len(verts))
}
