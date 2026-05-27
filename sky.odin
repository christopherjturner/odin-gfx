package main

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
    sun_dir:     [3]f32,
    now:         Sky_Color,
    cloud:       struct {
        scale: [2]f32,
        blend: [2]f32,
        mask:  [4]f32,
    }
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

    sky: Sky_Renderer

    sky.state.cloud = {
        scale = { 0.40, 0.90 },
        blend = { 0.95, 0.65 },
        mask  = { 0.25, 0.85, 0.10, 0.65 },
    }

    // Generate dome
    sky.verts, sky.indices = generate_sky_dome(8, 16)

    // Create an bind buffers
    sky.bind.vertex_buffers[0] = sg.make_buffer({
        data  = { ptr = &sky.verts[0], size = len(sky.verts) * size_of(Sky_Vertex) },
        label = "sky-vertex-buffer",
    })

    sky.bind.index_buffer = sg.make_buffer({
        usage = { index_buffer = true },
        data  = { ptr = &sky.indices[0], size = len(sky.indices) * size_of(u16) },
        label = "sky-index-buffer",
    })

    // Load noise texture
    noise_texture := load_texture("./assets/textures/noise.png")

    sky.bind.views[shaders.VIEW_sky_tex] = sg.make_view({
        texture = {
            image = noise_texture
        },
        label = "sky-noise-view",
    })

    sky.bind.samplers[shaders.SMP_sky_smp] = sg.make_sampler({
        min_filter = .LINEAR,
        mag_filter = .LINEAR,
        wrap_u     = .REPEAT,
        wrap_v     = .REPEAT,
    })

    // Set up the sky shader pipeline

    sky_shader := sg.make_shader(shaders.sky_shader_desc(sg.query_backend()))
    sky.pip = sg.make_pipeline({
        layout = {
            attrs = {
                shaders.ATTR_sky_pos = {format = .FLOAT3},
            },
        },
        depth = {
            compare       = .LESS_EQUAL,      // TODO: revert this back to actually checking
            write_enabled = false,
        },
        index_type = .UINT16,
        cull_mode  = .BACK,
        shader     = sky_shader,
        label      = "sky-shader-pipeline",
    })

    return sky
}

draw_sky :: proc(sky: ^Sky_Renderer, cam: ^Camera, t: f32) {

    p1, p2, pt := find_keyframe_indices(&sky_palette, state.world.time_of_day)
    sky.state.now = interpolate_keyframes(sky_palette.keyframes[p1], sky_palette.keyframes[p2], pt)
    sky.state.sun_dir = update_sun_direction(state.world.time_of_day)

    proj := glsl.mat4Perspective(glsl.radians(cam.fov), cam.aspect, 0.1, 10000.0)
    view := glsl.mat4LookAt(cam.position, cam.position + cam.front, cam.up)

    vs_uniforms := shaders.Sky_Vs_Params{
        view       = transmute([16]f32)view,
        proj       = transmute([16]f32)proj,
        game_time  = state.world.game_time,
    }

    fs_uniforms := shaders.Sky_Fs_Params{
        horizon_now = sky.state.now.horizon_color,
        zenith_now  = sky.state.now.zenith_color,
        sun_color   = sky.state.now.sun_color,
        sun_dir     = sky.state.sun_dir,
        view_dir    = glsl.normalize(cam.front),
        game_time   = state.world.game_time,
        time_of_day = state.world.time_of_day,
        cloud_scale = sky.state.cloud.scale,
        cloud_blend = sky.state.cloud.blend,
        cloud_mask  = sky.state.cloud.mask,
    }

    sg.apply_pipeline(sky.pip)
    sg.apply_bindings(sky.bind)
    sg.apply_uniforms(shaders.UB_sky_vs_params, { ptr = &vs_uniforms, size = size_of(vs_uniforms) })
    sg.apply_uniforms(shaders.UB_sky_fs_params, { ptr = &fs_uniforms, size = size_of(fs_uniforms) })
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

    // Moonlight contribution
    if result.time < 0.25 || result.time > 0.75 {
        moon_factor := result.time < 0.25 ? (0.25 - result.time) / 0.25 : (result.time - 0.75) / 0.25
        moon_contrib := [4]f32{0.2, 0.2, 0.2, 1.0} * moon_factor
        result.ambient_color += moon_contrib
    }

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
