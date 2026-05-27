package main

import "core:fmt"
import "core:math/linalg/hlsl"

import sgl "./sokol/gl"
import sg "./sokol/gfx"
import sapp "./sokol/app"
import "./shaders"

Grid_Vertex :: struct {
    pos: [3]f32,
    color: [4]f32,
}

init_grid :: proc() {
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
    sg.apply_pipeline(state.grid.pip)
    sg.apply_bindings(state.grid.bind)
    grid_vs: shaders.Vs_Params

    view_proj := get_view_proj(cam)
    grid_vs.mvp = transmute([16]f32)view_proj // Grid doesn't move/rotate
    sg.apply_uniforms(shaders.UB_grid_vs_params, { ptr = &grid_vs, size = size_of(grid_vs) })
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

MAX_DEBUG_AABB :: 32

AABB_Vertex :: struct {
    pos: [3]f32
}

AABB_Instance :: struct {
    aabb_min: [3]f32,
    aabb_max: [3]f32,
    pos:      [3]f32,
    scale:    [3]f32,
    rot:      quaternion128,
}

AABB_Debug_Renderer :: struct {
    pip:       sg.Pipeline,
    bind:      sg.Bindings,
    instances: [dynamic]AABB_Instance,
}

// 8 corners of a unit cube (0 to 1)
unit_cube_vertices := [8]AABB_Vertex{
    {{0,0,0}},
    {{1,0,0}},
    {{1,1,0}},
    {{0,1,0}}, // 3
    {{0,0,1}}, // 4
    {{1,0,1}}, // 5
    {{1,1,1}}, // 6
    {{0,1,1}}, // 7
}

// 12 lines (24 indices) to form the wireframe
unit_cube_indices := [24]u16{
    0,1, 1,2, 2,3, 3,0, // Bottom
    4,5, 5,6, 6,7, 7,4, // Top
    0,4, 1,5, 2,6, 3,7, // Vertical pillars
}

init_aabb_renderer :: proc() -> ^AABB_Debug_Renderer {
    aabb_debug_renderer := new(AABB_Debug_Renderer)

    aabb_debug_renderer.bind.vertex_buffers[0] = sg.make_buffer({
        data = {
            ptr  = &unit_cube_vertices[0],
            size = len(unit_cube_vertices) * size_of(AABB_Vertex)
        },
        label = "aabb-vertex-buffer",
    })

    aabb_debug_renderer.bind.index_buffer = sg.make_buffer({
        usage = { index_buffer = true },
        data  = {
            ptr  = &unit_cube_indices[0],
            size = len(unit_cube_indices) * size_of(u16)
        },
    })

    aabb_debug_renderer.bind.vertex_buffers[1] = sg.make_buffer({
        size = MAX_DEBUG_AABB * size_of(AABB_Instance),
        usage = {
            vertex_buffer = true,
            stream_update = true,
        },
        label = "aabb-instance-buffer",
    })

    aabb_debug_renderer.pip = sg.make_pipeline({
        shader = sg.make_shader(shaders.aabb_shader_desc(sg.query_backend())),
        layout = {
            buffers = {
                0 = { stride = size_of(AABB_Vertex), },
                1 = { stride = size_of(AABB_Instance), step_func = .PER_INSTANCE },
            },
            attrs = {
                shaders.ATTR_aabb_pos        = { buffer_index = 0, format = .FLOAT3 },
                shaders.ATTR_aabb_aabb_min   = { buffer_index = 1, format = .FLOAT3 },
                shaders.ATTR_aabb_aabb_max   = { buffer_index = 1, format = .FLOAT3 },
                shaders.ATTR_aabb_inst_pos   = { buffer_index = 1, format = .FLOAT3 },
                shaders.ATTR_aabb_inst_scale = { buffer_index = 1, format = .FLOAT3 },
                shaders.ATTR_aabb_inst_rot   = { buffer_index = 1, format = .FLOAT4 },
            },
        },
        depth = {
            write_enabled = true,
            compare       = .LESS_EQUAL,
        },
        index_type     = .UINT16,
        primitive_type = .LINES,
        cull_mode      = .BACK,

    })

    return aabb_debug_renderer
}

draw_debug_aabb :: proc(aabb_renderer: ^AABB_Debug_Renderer, cam: ^Camera) {
    if len(aabb_renderer.instances) == 0 {
        return
    }

    view_proj := get_view_proj(cam)
    uniforms := shaders.Aabb_Vs_Params{
        view_proj = transmute([16]f32)view_proj,
    }

    sg.update_buffer(aabb_renderer.bind.vertex_buffers[1], {
        ptr  = raw_data(aabb_renderer.instances),
        size = len(aabb_renderer.instances) * size_of(AABB_Instance),
    })

    sg.apply_pipeline(aabb_renderer.pip)
    sg.apply_bindings(aabb_renderer.bind)
    sg.apply_uniforms(shaders.UB_aabb_vs_params, { ptr = &uniforms, size = size_of(uniforms) })

    sg.draw(0, 24, len(aabb_renderer.instances))
}

add_aabb :: proc(aabb_renderer: ^AABB_Debug_Renderer, box: AABB, transform: Transform) {
    instance := AABB_Instance {
        aabb_min = box.min,
        aabb_max = box.max,
        pos      = transform.pos,
        scale    = transform.scale,
        rot      = transform.rot,

    }
    //append(&aabb_renderer.instances, instance)
}

flush_aabb :: proc(aabb: ^AABB_Debug_Renderer) {
    clear(&aabb.instances)
}
