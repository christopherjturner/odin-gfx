package main

import "core:fmt"
import "core:math"
import "core:math/linalg/glsl"
import sg "./sokol/gfx"
import "./shaders"

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
    time_of_day: f32, // 0.0 - 1.0
    game_time:   f32,
    sun_dir:     [3]f32,
    game_time_offset: f32,
    now:  Sky_Color,
}

// TODO: mix in sun color, maybe we can use the moon as well?
Sky_Color :: struct {
    time:          f32, // 0.0 -> 1.0
    sun_intensity: f32,
    sun_color:     [4]f32,
    ambient_color: [4]f32,
    horizon_color: [4]f32,
    zenith_color:  [4]f32,
}

Sky_Palette :: struct {
    keyframes: []Sky_Color,
}

init_sky :: proc() -> Sky_Renderer {
    using shaders
    sky: Sky_Renderer

    sky.state.time_of_day = 0.5

    // Generate dome
    sky.verts, sky.indices = generate_sky_dome(8, 16)

    // Create an bind buffers
    sky.bind.vertex_buffers[0] = sg.make_buffer({
        data = { ptr = &sky.verts[0], size = len(sky.verts) * size_of(Sky_Vertex) },
    })

    sky.bind.index_buffer = sg.make_buffer({
        usage = { index_buffer = true },
        data  = { ptr = &sky.indices[0], size = len(sky.indices) * size_of(u16) },
    })

    // Set up the sky shader pipeline
    using shaders;
    sky_shader := sg.make_shader(sky_shader_desc(sg.query_backend()))
    sky.pip = sg.make_pipeline({
        layout = {
            attrs = {
                ATTR_sky_pos = {format = .FLOAT3},
            },
        },
        index_type = .UINT16,
        depth = {
            compare       = .LESS_EQUAL,      // TODO: revert this back to actually checking
            write_enabled = false,
        },
        cull_mode = .BACK,
        shader    = sky_shader,
    })

    return sky
}

draw_sky :: proc(sky: ^Sky_Renderer, cam: ^Camera, t: f32) {
    using shaders

    // TODO: work out how much to divide game time into a day/night
    sky.state.game_time += t;
    //sky.state.time_of_day = glsl.mod(0.5 + (sky.state.game_time * 0.01), 1.0);

    p1, p2, pt := find_keyframe_indices(&sky_palette, sky.state.time_of_day)
    sky.state.now = interpolate_keyframes(sky_palette.keyframes[p1], sky_palette.keyframes[p2], pt)
    sky.state.sun_dir = update_sun_direction(sky.state.time_of_day)

    proj := glsl.mat4Perspective(glsl.radians(cam.fov), cam.aspect, 0.1, 10000.0)
    view := glsl.mat4LookAt(cam.position, cam.position + cam.front, cam.up)

    vs_uniforms := Sky_Vs_Params{
        view       = transmute([16]f32)view,
        proj       = transmute([16]f32)proj,
        game_time  = sky.state.game_time,
    }

    fs_uniforms := Sky_Fs_Params{
        horizon_now = sky.state.now.horizon_color,
        zenith_now  = sky.state.now.zenith_color,
        game_time   = sky.state.game_time,
    }

    sg.apply_pipeline(sky.pip)
    sg.apply_bindings(sky.bind)
    sg.apply_uniforms(UB_sky_vs_params, { ptr = &vs_uniforms, size = size_of(vs_uniforms) })
    sg.apply_uniforms(UB_sky_fs_params, { ptr = &fs_uniforms, size = size_of(fs_uniforms) })
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

sky_palette := Sky_Palette {
    keyframes = []Sky_Color {
        // Midnight
        {
            time = 0.0,
            sun_intensity = 0.0,
            sun_color     = {0.0,  0.0,  0.0,  1.0},
            ambient_color = {0.05, 0.05, 0.15, 1.0},
            horizon_color = {0.05, 0.05, 0.15, 1.0},
            zenith_color  = {0.01, 0.01, 0.05, 1.0},
        },

        // Pre-dawn
        {
            time = 0.15,
            sun_intensity = 0.0,
            sun_color     = {0.0,  0.0,  0.0,  1.0},
            ambient_color = {0.08, 0.08, 0.18, 1.0},
            horizon_color = {0.1,  0.1,  0.2,  1.0},
            zenith_color  = {0.01, 0.01, 0.05, 1.0},
        },

        // Dawn
        {
            time = 0.25,
            sun_intensity = 0.3,
            sun_color     = {1.0, 0.6,  0.3,  1.0},
            ambient_color = {0.4, 0.35, 0.45, 1.0},
            horizon_color = {0.7, 0.5,  0.3,  1.0},
            zenith_color  = {0.3, 0.5,  0.8,  1.0},
        },

        // Mid-morning
        {
            time = 0.35,
            sun_intensity = 0.8,
            sun_color     = {1.0, 0.95, 0.85, 1.0},
            ambient_color = {0.6, 0.6,  0.65, 1.0},
            horizon_color = {0.7, 0.7,  0.8,  1.0},
            zenith_color  = {0.3, 0.5,  0.9,  1.0},
        },

        // Noon
        {
            time = 0.5,
            sun_intensity = 1.0,
            sun_color     = {1.0,  0.98, 0.95, 1.0},
            ambient_color = {0.65, 0.65, 0.7,  1.0},
            horizon_color = {0.7,  0.7,  0.85, 1.0},
            zenith_color  = {0.3,  0.5,  0.95, 1.0},
        },

        // Afternoon
        {
            time = 0.65,
            sun_intensity = 0.9,
            sun_color     = {1.0,  0.95, 0.9, 1.0},
            ambient_color = {0.65, 0.65, 0.7, 1.0},
            horizon_color = {0.75, 0.65, 0.7, 1.0},
            zenith_color  = {0.3,  0.5, 0.9,  1.0},
        },
        // Dusk
        {
            time = 0.75,
            sun_intensity = 0.4,
            sun_color     = {1.0,  0.5,  0.2, 1.0},
            ambient_color = {0.45, 0.35, 0.4, 1.0},
            horizon_color = {0.8,  0.4,  0.2, 1.0},
            zenith_color  = {0.2,  0.3,  0.6, 1.0},
        },
        // Post-dusk
        {
            time = 0.85,
            sun_intensity = 0.1,
            sun_color     = {0.6,  0.2,  0.1,  1.0},
            ambient_color = {0.08, 0.08, 0.18, 1.0},
            horizon_color = {0.1,  0.05, 0.15, 1.0},
            zenith_color  = {0.01, 0.01, 0.05, 1.0},
        },

        // Back to midnight (for wrapping)
        {
            time = 1.0,
            sun_intensity = 0.0,
            sun_color     = {0.0,  0.0,  0.0,  0.0},
            ambient_color = {0.05, 0.05, 0.15, 1.0},
            horizon_color = {0.05, 0.05, 0.15, 1.0},
            zenith_color  = {0.01, 0.01, 0.05, 1.0},
        },
    }
}

find_keyframe_indices :: proc(palette: ^Sky_Palette, wrapped_time: f32) -> (idx0, idx1: int, t: f32) {
    for i in 0..<len(palette.keyframes)-1 {
        if wrapped_time >= palette.keyframes[i].time &&
            wrapped_time <= palette.keyframes[i+1].time {
                idx0 = i
                idx1 = i + 1

               // Calculate interpolation factor
               t0 := palette.keyframes[idx0].time
               t1 := palette.keyframes[idx1].time
               t = (wrapped_time - t0) / (t1 - t0)
            return
        }
    }

    // Shouldn't reach here if keyframes are set up correctly
    return 0, 1, 0.0
}

interpolate_keyframes :: proc(k0, k1: Sky_Color, t: f32) -> Sky_Color {
    result := Sky_Color{}

    result.time          = k0.time + (k1.time - k0.time) * t
    result.sun_intensity = k0.sun_intensity + (k1.sun_intensity - k0.sun_intensity) * t
    result.sun_color     = math.lerp(k0.sun_color, k1.sun_color, t) * result.sun_intensity
    result.ambient_color = math.lerp(k0.ambient_color, k1.ambient_color, t)
    result.horizon_color = math.lerp(k0.horizon_color, k1.horizon_color, t)
    result.zenith_color  = math.lerp(k0.zenith_color, k1.zenith_color, t)

    /*
    // Moonlight contribution
    if state.time_of_day < 0.25 || state.time_of_day > 0.75 {
        moon_factor := state.time_of_day < 0.25 ? 
            (0.25 - state.time_of_day) / 0.25 : 
            (state.time_of_day - 0.75) / 0.25
        moon_contrib := [3]f32{0.15, 0.15, 0.2} * moon_factor * 0.3
        lighting.ambient_color += moon_contrib
    }
    */

    return result
}

update_sun_direction :: proc(time_of_day: f32) -> [3]f32 {
    // time_of_day is 0.0 to 1.0
    // We want 0.5 to be "Noon" (Sun at peak)
    // We subtract 0.25 so that 0.0 starts at "Midnight" or "Sunrise"
    angle := (time_of_day - 0.25) * 2.0 * math.PI
    sun_dir: [3]f32
    sun_dir.x = math.cos(angle)
    sun_dir.y = math.sin(angle)
    sun_dir.z = 0.2 // Slight tilt for better looking shadows

    return glsl.normalize(sun_dir)
}
