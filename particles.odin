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
    emitters: []Emitter,
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
    wave_frequency: [3]f32,

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

    images := load_array_texture({
        "./assets/textures/array/1star.png",
        "./assets/textures/array/2star.png",
        "./assets/textures/array/3star.png",
    })

    particle_system.bind.views[shaders.VIEW_tex] = sg.make_view({
        texture = {
            image  = images,
            slices = { base = 0, count = 0 },
        }
    })

    particle_system.bind.samplers[shaders.SMP_smp] = sg.make_sampler({
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
        wrap_u     = .CLAMP_TO_EDGE,
        wrap_v     = .CLAMP_TO_EDGE,
    })

    particle_system.pip = sg.make_pipeline({
        depth = {
            write_enabled = false,
            compare       = .LESS_EQUAL,
        },
        shader     = sg.make_shader(shaders.particles_shader_desc(sg.query_backend())),
        cull_mode  = .NONE,
        index_type = .NONE,
        colors = {
            0 = {
                blend = {
                    enabled = true,
                    src_factor_rgb   = .SRC_ALPHA,
                    dst_factor_rgb   = .ONE,
                    src_factor_alpha = .ZERO,
                    dst_factor_alpha = .ONE,
                    op_rgb = .ADD,
                }
            }
        },
    })

    particle_system.emitters = make([]Emitter, 1)
    particle_system.emitters[0] = Emitter {
        count               = 10,
        origin              = { -10.0, 0.0, 10.0 },
        velocity            = { 0.0, 5.0, 0.0 },
        velocity_variance   = { 0.0, 0.0, 0.0 },
        gravity             = 0,
        orbit_axis          = { 0, 0, 0 },
        orbit_speed         = 0.0,
        radial_acceleration = 0.0,
        wave_amplitude      = { 0.0, 0, 0 },
        wave_frequency      = { 0, 0, 0 },
        lifetime_max        = 5.0,
        lifetime_variance   = 0.0,
        color_start         = { 0.0, 1.0, 0.0, 1.0 },
        color_end           = { 0.0, 0.5, 0.0, 1.0 },
        scale_change        = { 0.2, 2.25 },
    }
    return particle_system
}

draw_particles :: proc(ps: ^Particle_System, cam: ^Camera, t: f32) {
    view_proj := get_view_proj(cam)

    ps.time += t
    sg.apply_pipeline(ps.pip)
    sg.apply_bindings(ps.bind)

    for e in ps.emitters {

        uniforms := shaders.Particle_Vs_Params {
            view              = transmute([16]f32)cam.view,
            proj              = transmute([16]f32)cam.proj,
            t                 = ps.time,
            origin            = e.origin,
            velocity          = e.velocity,
            velocity_variance = e.velocity_variance,
            gravity           = e.gravity,
            orbit_axis        = e.orbit_axis,
            orbit_speed       = e.orbit_speed,
            radial_acceleration = e.radial_acceleration,
            wave_amplitude    = e.wave_amplitude,
            wave_frequency    = e.wave_frequency,
            lifetime_max      = e.lifetime_max,
            lifetime_variance = e.lifetime_variance,
            color_start       = e.color_start,
            color_end         = e.color_end,
            atlas_index       = e.atlas_index,
            scale_change      = e.scale_change,
        }

        sg.apply_uniforms(shaders.UB_particle_vs_params, {
            ptr = &uniforms,
            size = size_of(uniforms)
        })

        sg.draw(0, 3, e.count)
    }
}
