package main

import "core:fmt"
import "core:math"
import "core:math/linalg/glsl"
import img "vendor:stb/image"
import sg "./sokol/gfx"

import "./shaders"


// A heighmap terrain generator

Terrain_Vertex :: struct {
    height: f32,
    normal: [3]f32,
    color:  [3]f32,
}

Terrain_Renderer :: struct {
    pip:      sg.Pipeline,
    bind:     sg.Bindings,
    verts:    []Terrain_Vertex,
    indices:  []u16,
    width:    i32,
    height:   i32,
    pos:      [3]f32,
    scale:    [3]f32,
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
    // TODO: switch indices to u32 otherwise we're capped at 256x256


    CHUNK_X := img_w - 1
    CHUNK_Y := img_h - 1

    terrain.width  = img_w
    terrain.height = img_h

    // Scale and reposition terrain chunk
    terrain.scale  = { 10.0, 100.0, 10.0 }
    terrain.pos    = { f32(-img_w / 2) * terrain.scale.x, 0.0, f32(-img_h / 2) * terrain.scale.z }

    // Generate chunk from image
    terrain.verts   = make([]Terrain_Vertex, img_w * img_h)
    terrain.indices = make([]u16, int((CHUNK_X * CHUNK_Y) * 6))

    // Verts
    for y in 0..<img_h {
        for x in 0..<img_w {
            pixel_idx := (y * img_w) + x
            h := f32(pixels[pixel_idx * 4]) / 255.0;

            vert_id := (y * img_w) + x
            terrain.verts[vert_id] = {
                height = h,
                color  = { 0.3, 0.6, 0.2 },
            }
        }
    }

    // Normals
    for y in 0..<img_h - 1 {
        for x in 0..<img_w - 1 {
            v0_idx := y * img_w + x
            v1_idx := y * img_w + (x + 1)
            v2_idx := (y + 1) * img_w + x

            // Positions for normal calc (apply scale here)
            p0 := [3]f32{f32(x),   terrain.verts[v0_idx].height, f32(y)  } * terrain.scale
            p1 := [3]f32{f32(x+1), terrain.verts[v1_idx].height, f32(y)  } * terrain.scale
            p2 := [3]f32{f32(x),   terrain.verts[v2_idx].height, f32(y+1)} * terrain.scale

            // Edge vectors
            e1 := p1 - p0
            e2 := p2 - p0

            // Cross product for the triangle face normal
            n := glsl.normalize(glsl.cross(e2, e1)) // Reverse e1/e2 if it points down

            // Accumulate normals (Average them for smoothness)
            terrain.verts[v0_idx].normal += n
            terrain.verts[v1_idx].normal += n
            terrain.verts[v2_idx].normal += n
        }
    }

    fmt.printf("\nloaded %d x %d map\n", img_w, img_h)

    // Index
    i_idx := 0
    for y in 0..<CHUNK_Y {
        for x in 0..<CHUNK_X {
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
        cull_mode  = .BACK,
        depth      = { compare = .LESS_EQUAL, write_enabled = true, },
        shader     = terrain_shader,
        layout     = {
            attrs = {
                shaders.ATTR_terrain_height = { format = .FLOAT },
                shaders.ATTR_terrain_normal = { format = .FLOAT3 },
                shaders.ATTR_terrain_color  = { format = .FLOAT3 },
            },
        },
    })
    return terrain
}

draw_terrain :: proc(terrain: ^Terrain_Renderer, cam: ^Camera) {
    view_proj := get_view_proj(cam)

    vs_uniforms := shaders.Terrain_Vs_Params {
        view_proj     = transmute([16]f32)view_proj,
        u_camera_pos  = cam.position,
        ambient_color = state.sky.state.now.ambient_color,
        sun_color     = state.sky.state.now.sun_color, // * state.sky.state.now.sun_intensity,
        chunk_pos     = terrain.pos,
        scale         = terrain.scale,
        u_grid_width  = terrain.width,
        u_sun_dir     = state.sky.state.sun_dir,
    }

    sg.apply_pipeline(terrain.pip)
    sg.apply_bindings(terrain.bind)
    sg.apply_uniforms(shaders.UB_terrain_vs_params, { ptr = &vs_uniforms, size = size_of(vs_uniforms) })
    sg.draw(0, i32(len(terrain.indices)), 1)
}


get_terrain_height :: proc(terrain: ^Terrain_Renderer, world_x, world_z: f32) -> f32 {
    // 1. Transform world coordinates to grid coordinates
    // Assuming your grid starts at 0,0 and spacing is 1.0
    gx := (world_x - terrain.pos.x) / terrain.scale.x
    gz := (world_z - terrain.pos.z) / terrain.scale.z

    // 2. Get the integer grid cell
    ix := int(math.floor(gx))
    iz := int(math.floor(gz))

    // Boundary check: needs to be width - 1 to allow for the "+1" samples
    if ix < 0 || ix >= int(terrain.width) - 1 || iz < 0 || iz >= int(terrain.height) - 1 {
        return 10.0 // A "Kill Plane" depth
    }


    // 3. Find coordinates within the single quad (0.0 to 1.0)
    tx := gx - f32(ix)
    tz := gz - f32(iz)

    // 4. Get the 4 corner heights
    // Using the same stride logic we used for the vertex array
    stride := int(terrain.width)

    h00 := terrain.verts[iz * stride + ix].height             // Top-Left
    h10 := terrain.verts[iz * stride + (ix + 1)].height       // Top-Right
    h01 := terrain.verts[(iz + 1) * stride + ix].height       // Bottom-Left
    h11 := terrain.verts[(iz + 1) * stride + (ix + 1)].height // Bottom-Right

    // 5. Determine which triangle of the quad we are in and interpolate
    // Most grids split quads from (0,0) to (1,1)
    result: f32
    if tx <= (1.0 - tz) {
        // Upper-left triangle
        result = (h00 + tx * (h10 - h00) + tz * (h01 - h00))
    } else {
        // Lower-right triangle
        result = (h11 + (1.0 - tx) * (h01 - h11) + (1.0 - tz) * (h10 - h11))
    }

    return result * terrain.scale.y
}
