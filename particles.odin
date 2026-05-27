package main

import sapp "./sokol/app"
import sg "./sokol/gfx"
import "core:fmt"
import "core:math/linalg/glsl"

import "./shaders"

Particle_System :: struct {
    pip:  sg.Pipeline,
    bind: sg.Bindings,
    time: f32,
    emitters: Emitter,
}

Emitter :: struct {
    active: bool,
    count:  int,

    origin: [3]f32,
    velocity: [3]f32,
    velocity_variance: [3]f32,
    gravity: [3]f32,
    drag: f32,

    orbit_axis: [3]f32,
    orbit_speed: f32,
    radial_acceleration: f32,

    wave_amplitude: [3]f32,
    wave_frequence: [3]f32,

    atlas_index:  f32,
    color_start:  [4]f32,
    color_end:    [4]f32,
    scale_change: [2]f32,

    lifetime_max:      f32,
    lifetime_variance: f32,
    time_scale:        f32,
}


init_particles :: proc() -> Particle_System {
    particle_system: Particle_System

    particle_system.pip = sg.make_pipeline({
        depth = {
            write_enabled = true,
            compare       = .LESS_EQUAL,
        },
        shader     = sg.make_shader(shaders.particles_shader_desc(sg.query_backend())),
        cull_mode  = .NONE,
        index_type = .NONE,
        colors = {
            0 = {
                blend = {
                    enabled = false,
                    src_factor_rgb   = .SRC_ALPHA,
                    dst_factor_rgb   = .ONE_MINUS_SRC_ALPHA,
                    //src_factor_alpha = .ZERO,
                    //dst_factor_alpha = .ONE,
                }
            }
        },
    })

    particle_system.emitters = Emitter {
        count             = 50,
        origin            = { -10.0, 0.0, 10.0 },
        velocity          = { 0.0, 10.0, 0.0 },
        velocity_variance = { 4.0, 4.0, 4.0 },
        gravity           = -1,
        lifetime_max      = 2.0,
        lifetime_variance = 2.0,
        color_start       = { 0.3, 1.0, 1.0, 0.0 },
        color_end         = { 0.3, 0.0, 0.0, 0.0 },
    }
    return particle_system
}

draw_particles :: proc(ps: ^Particle_System, cam: ^Camera, t: f32) {
    view_proj := get_view_proj(cam)

    ps.time += t
    uniforms := shaders.Particle_Vs_Params {
        view        = transmute([16]f32)cam.view,
        proj        = transmute([16]f32)cam.proj,

        t                 = ps.time,
        origin            = ps.emitters.origin,
        velocity          = ps.emitters.velocity,
        velocity_variance = ps.emitters.velocity_variance,
        gravity           = ps.emitters.gravity,
        lifetime_max      = ps.emitters.lifetime_max,
        lifetime_variance = ps.emitters.lifetime_variance,
        color_start       = ps.emitters.color_start,
        color_end         = ps.emitters.color_end,
    }

    sg.apply_pipeline(ps.pip)
    sg.apply_bindings(ps.bind)
    sg.apply_uniforms(shaders.UB_particle_vs_params, {
        ptr = &uniforms,
        size = size_of(uniforms)
    })

    sg.draw(0, 3, ps.emitters.count)
}
