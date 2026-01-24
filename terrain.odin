package main

import "core:fmt"
import "core:math/linalg/glsl"
import img "vendor:stb/image"
import sg "./sokol/gfx"

import "./shaders"


// A heighmap terrain generator

Terrain_Vertex :: struct {
    pos: [4]f32,
    color:  [4]f32,
}

Terrain_Renderer :: struct {
    pip:      sg.Pipeline,
    bind:     sg.Bindings,
    verts:    []Terrain_Vertex,
    indices:  []u16,
    width:    i32,
    height:   i32,
    pos:      [3]f32,
    scale:    f32,
}

init_terrain :: proc() -> Terrain_Renderer {
    terrain: Terrain_Renderer

    // load the hightmap from file

    img_w, img_h, t_chan: i32
    pixels := img.load("./assets/map.png", &img_w, &img_h, &t_chan, 4)
    if pixels == nil {
        panic("Failed to load ./assets/map.png")
    }
    defer img.image_free(pixels)

    CHUNK_X := img_w - 1
    CHUNK_Y := img_h - 1

    terrain.width  = img_w
    terrain.height = img_h

    terrain.pos  = { f32(-img_w) * 0.5, -1.0, f32(-img_h) * 0.5 }
    terrain.scale  = 10.0

    // generate grid
    terrain.verts   = make([]Terrain_Vertex, img_w * img_h)
    terrain.indices = make([]u16, int((CHUNK_X * CHUNK_Y) * 6))

    // Verts
    for y in 0..<img_h {
        for x in 0..<img_w {
            pixel_idx := (y * img_w) + x
            h := f32(pixels[pixel_idx * 4]) / 255.0;

            vert_id := (y * img_w) + x
            terrain.verts[vert_id] = {
                // get height from the map
                pos = {
                    f32(x),
                    h * 10.0,
                    f32(y),
                    1.0
                },
                color = { 0.3, 0.6, 0.2, 1.0 },
            }
        }
    }

    fmt.printf("\nloaded %d x %d map\n", CHUNK_X, CHUNK_Y)

    // Index
    i_idx := 0
    for y in 0..<CHUNK_Y {
        for x in 0..<CHUNK_X {
            row_start := u16(y * (CHUNK_X + 1))
			next_row  := u16((y + 1) * (CHUNK_X + 1))

			v0 := u16(y * img_w + x)
			v1 := u16(y * img_w + (x + 1))
			v2 := u16((y + 1) * img_w + x)
			v3 := u16((y + 1) * img_w + (x + 1))

			// Triangle 1
			terrain.indices[i_idx] = v0; i_idx += 1
			terrain.indices[i_idx] = v1; i_idx += 1
            terrain.indices[i_idx] = v2; i_idx += 1

			// Triangle 2
			terrain.indices[i_idx] = v1; i_idx += 1
			terrain.indices[i_idx] = v3; i_idx += 1
			terrain.indices[i_idx] = v2; i_idx += 1
        }
    }

    terrain.bind.vertex_buffers[0] = sg.make_buffer({
        data = { ptr = &terrain.verts[0], size = len(terrain.verts) * size_of(Terrain_Vertex) },
    })

    terrain.bind.index_buffer = sg.make_buffer({
        usage = { index_buffer = true },
        data  = { ptr = &terrain.indices[0], size = len(terrain.indices) * size_of(u16) },
    })

    terrain_shader := sg.make_shader(shaders.terrain_shader_desc(sg.query_backend()))

    terrain.pip = sg.make_pipeline({
        index_type = .UINT16,
        cull_mode    = .BACK,
        depth      = { compare = .LESS_EQUAL, write_enabled = true, },
        shader     = terrain_shader,
        layout     = {
            attrs = {
                shaders.ATTR_terrain_pos   = { format = .FLOAT4 },
                shaders.ATTR_terrain_color = { format = .FLOAT4 },
            },
        },
    })
    return terrain
}

draw_terrain :: proc(terrain: ^Terrain_Renderer, cam: ^Camera) {
    view_proj := get_view_proj(cam)

    vs_uniforms := shaders.Terrain_Vs_Params {
        view_proj     = transmute([16]f32)view_proj,
        ambient_color = state.sky.state.now.ambient_color,
        chunk_pos     = terrain.pos,
        scale         = terrain.scale,
        width         = terrain.width,
        height        = terrain.height,
    }

    sg.apply_pipeline(terrain.pip)
    sg.apply_bindings(terrain.bind)
    sg.apply_uniforms(shaders.UB_terrain_vs_params, { ptr = &vs_uniforms, size = size_of(vs_uniforms) })
    sg.draw(0, i32(len(terrain.indices)), 1)
}
