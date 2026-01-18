package main
import "core:fmt"
import "core:math"
import "core:math/linalg/glsl"
import sg "./sokol/gfx"

Sky_Vertex :: struct {
    pos: [3]f32,
}

Sky_Renderer :: struct {
    pip:     sg.Pipeline,
    bind:    sg.Bindings,
    verts:   []Sky_Vertex,
    indices: []u16,
    state:   Sky_State,
}

Sky_State :: struct {
    time_of_day: f32,
    game_time: f32,
}

init_sky :: proc() -> Sky_Renderer {
    sky: Sky_Renderer

    sky.verts, sky.indices = generate_sky_dome(8, 16)
    sky.state.time_of_day = 0.67


    // Create an bind buffers
    sky.bind.vertex_buffers[0] = sg.make_buffer({
        data = { ptr = &sky.verts[0], size = len(sky.verts) * size_of(Sky_Vertex) },
    })

    sky.bind.index_buffer = sg.make_buffer({
        usage = { index_buffer = true },
        data  = { ptr = &sky.indices[0], size = len(sky.indices) * size_of(u16) },
    })

    // Set up the sky shader pipeline
    shd := sg.make_shader(sky_shader_desc(sg.query_backend()))
    sky.pip = sg.make_pipeline({
        layout = {
            attrs = {
                ATTR_sky_pos = {format = .FLOAT3},
            },
        },
        index_type = .UINT16,
        depth = {
            compare = .ALWAYS,      // Force it to always draw
            write_enabled = false,
        },
        cull_mode = .NONE,
        shader = shd,
    })

    return sky
}

draw_sky :: proc(sky: ^Sky_Renderer, cam: ^Camera) {
    proj := glsl.mat4Perspective(glsl.radians(cam.fov), cam.aspect, 0.1, 10000.0)
    view := glsl.mat4LookAt(cam.position, cam.position + cam.front, cam.up)

    view_proj := get_view_proj(cam)
    sky_view_proj := view_proj
    sky_view_proj[3][0] = 0.0
    sky_view_proj[3][1] = 0.0
    sky_view_proj[3][2] = 0.0

    uniforms := Sky_Params{
        view        = transmute([16]f32)view,
        proj        = transmute([16]f32)proj,
        time_of_day = sky.state.time_of_day,
        game_time   = sky.state.game_time,
    }

    sg.apply_pipeline(sky.pip)
    sg.apply_bindings(sky.bind)
    sg.apply_uniforms(UB_sky_params, {ptr = &uniforms, size = size_of(uniforms)})
    sg.draw(0, i32(len(sky.indices)), 1)
}

generate_sky_dome :: proc(rings: int = 8, segments: int = 16) -> (vertices: []Sky_Vertex, indices: []u16) {

    vertex_count := (rings + 1) * (segments + 1)
    vertices = make([]Sky_Vertex, vertex_count)

    idx := 0
    for ring in 0..=rings {
        theta := f32(ring) / f32(rings) * math.PI * 0.5
        sin_theta := math.sin(theta)
        cos_theta := math.cos(theta)

        for seg in 0..=segments {
            phi := f32(seg) / f32(segments) * math.PI * 2.0

            x := cos_theta * math.cos(phi)
            y := sin_theta
            z := cos_theta * math.sin(phi)

            vertices[idx].pos = {x, y, z}
            idx += 1
        }
    }

    index_count := rings * segments * 6
    indices = make([]u16, index_count)

    i := 0
    for ring in 0..<rings {
        for seg in 0..<segments {
            current := u16(ring * (segments + 1) + seg)
            next := current + u16(segments + 1)

            indices[i]   = current
            indices[i+1] = next
            indices[i+2] = current + 1

            indices[i+3] = current + 1
            indices[i+4] = next
            indices[i+5] = next + 1

            i += 6
        }
    }

    return vertices, indices
}


