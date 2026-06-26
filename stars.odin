package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"

import sg "./sokol/gfx"

import "./shaders"

MAX_STARS :: 255


Star_Renderer :: struct {
    pip:       sg.Pipeline,
    bind:      sg.Bindings,
    instances: [MAX_STARS]Billboard_Instance,
    active:    int,
}

star_instance_buffer_desc := sg.Buffer_Desc{
    size = MAX_STARS * size_of(Billboard_Instance),
    usage = {
        vertex_buffer = true,
        stream_update = true,
    },
    label = "stars-instance-buffer",
}


init_stars :: proc() -> Star_Renderer {
    stars: Star_Renderer

    // load star texture(s)
    images := load_array_texture({
        "./assets/textures/array/1star.png",
        "./assets/textures/array/2star.png",
        "./assets/textures/array/3star.png",
    })

    stars.bind.views[shaders.VIEW_tex] = sg.make_view({
        texture = {
            image  = images,
            slices = { base = 0, count = 0 },
        }
    })

    stars.bind.samplers[shaders.SMP_smp] = sg.make_sampler({})

    // Reuse BB verts
    stars.bind.vertex_buffers[0] = sg.make_buffer({
        data = {
            ptr = &billboard_quad,
            size = len(billboard_quad) * size_of(Billboard_Vertex)
        },
    })

    stars.bind.vertex_buffers[1] = sg.make_buffer(star_instance_buffer_desc)

    stars.instances[0] = Billboard_Instance {{0,0,0,}, 30, {1,1,1}, 0}
    stars.active = 1

    stars.pip = sg.make_pipeline({
        shader = sg.make_shader(shaders.stars_shader_desc(sg.query_backend())),
        layout = {
            buffers = {
                0 = { stride = size_of(Billboard_Vertex), }, // Quad
                1 = { stride = size_of(Billboard_Instance), step_func = .PER_INSTANCE },
            },
            attrs = {
                shaders.ATTR_stars_pos        = { buffer_index = 0, format = .FLOAT3 },
                shaders.ATTR_stars_uv         = { buffer_index = 0, format = .FLOAT2 },
                shaders.ATTR_stars_inst_pos   = { buffer_index = 1, format = .FLOAT3 },
                shaders.ATTR_stars_inst_scale = { buffer_index = 1, format = .FLOAT  },
                shaders.ATTR_stars_inst_color = { buffer_index = 1, format = .FLOAT4 },
                shaders.ATTR_stars_inst_layer = { buffer_index = 1, format = .FLOAT  },

            },
        },
        colors = {
            0 = {
                blend = {
                    enabled = true,
                    src_factor_rgb   = .SRC_ALPHA,
                    dst_factor_rgb   = .ONE_MINUS_SRC_ALPHA,
                }
            }
        },
        depth = {
            write_enabled = false,
            compare       = .LESS_EQUAL,
        },
    })

    return stars
}

update_sun :: proc(stars: ^Star_Renderer, sky: Sky_State) {
    angle := (state.world.time_of_day - 0.25) * 2.0 * math.PI
    stars.instances[0].pos = { math.cos(angle), math.sin(angle), 0.1 }
    stars.instances[0].color = sky.now.sun_color.rgb
}

add_star :: proc(stars: ^Star_Renderer, cam: ^Camera) {
    stars.instances[stars.active].pos = cam.front
    stars.instances[stars.active].scale = rand.float32_range(1.0, 4.0)
    col := rand.float32_range(0.3, 1.0)
    stars.instances[stars.active].color = { col, col, col }
    stars.instances[stars.active].layer = 1

    stars.active += 1
    fmt.printf("Adding star %v\n", stars.instances[stars.active].pos)
}

draw_stars :: proc(stars : ^Star_Renderer, cam: ^Camera, time_of_day: f32) {

    proj := cam.proj
    view := cam.view

    vs_uniforms := shaders.Star_Params {
        view = transmute([16]f32)view,
        proj = transmute([16]f32)proj,
    }

    sg.apply_pipeline(stars.pip)
    sg.apply_bindings(stars.bind)
    sg.apply_uniforms(shaders.UB_star_params, { ptr = &vs_uniforms, size = size_of(vs_uniforms) })

    sg.update_buffer(stars.bind.vertex_buffers[1], {
        ptr  = &stars.instances[0], // TODO: be careful about the pointers if/when we switch to a slice
        size = size_of(stars.instances),
    })

    sg.apply_pipeline(stars.pip)
    sg.apply_bindings(stars.bind)
    sg.draw(0, 6, stars.active)
}
