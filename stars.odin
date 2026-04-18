package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"

import img "vendor:stb/image"
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
    using shaders
    stars: Star_Renderer

    // load star texture(s)
    t_width, t_height, t_chan: i32
    pixels := img.load("./assets/textures/star2.png", &t_width, &t_height, &t_chan, 4)
    if pixels == nil {
        panic("image failed to load stars1.png")
    }
    defer img.image_free(pixels)

    img_desc := sg.Image_Desc {
        width = t_width,
        height = t_height,
        pixel_format = .RGBA8,
    }

    img_desc.data.mip_levels[0] = {
        ptr  = pixels,
        size = uint(t_width * t_height * 4),
    }

    stars.bind.views[VIEW_tex] = sg.make_view({
        texture = {
            image = sg.make_image(img_desc)
        }
    })

    stars.bind.samplers[SMP_smp] = sg.make_sampler({})

    // Reuse BB verts
    stars.bind.vertex_buffers[0] = sg.make_buffer({
        data = { ptr = &billboard_quad, size = len(billboard_quad) * size_of(Billboard_Vertex) },
    })

    stars.bind.vertex_buffers[1] = sg.make_buffer(star_instance_buffer_desc)

    stars.pip = sg.make_pipeline({
        shader = sg.make_shader(stars_shader_desc(sg.query_backend())),
        layout = {
            buffers = {
                0 = { stride = size_of(Billboard_Vertex), }, // Quad
                1 = { stride = size_of(Billboard_Instance), step_func = .PER_INSTANCE },
            },
            attrs = {
                ATTR_billboard_pos        = { buffer_index = 0, format = .FLOAT3 },
                ATTR_billboard_uv         = { buffer_index = 0, format = .FLOAT2 },
                ATTR_billboard_inst_pos   = { buffer_index = 1, format = .FLOAT3 },
                ATTR_billboard_inst_scale = { buffer_index = 1, format = .FLOAT  },
            },
        },
        depth = {
            write_enabled = false,
            compare       = .LESS_EQUAL,
        },
    })

    stars.instances[0] = Billboard_Instance {
        {
            0,0,0,
        },
        30,
        { 1, 1, 1, 1 }
    }
    stars.active = 1

    stars.pip = sg.make_pipeline({
        shader = sg.make_shader(stars_shader_desc(sg.query_backend())),
        layout = {
            buffers = {
                0 = { stride = size_of(Billboard_Vertex), }, // Quad
                1 = { stride = size_of(Billboard_Instance), step_func = .PER_INSTANCE },
            },
            attrs = {
                ATTR_stars_pos        = { buffer_index = 0, format = .FLOAT3 },
                ATTR_stars_uv         = { buffer_index = 0, format = .FLOAT2 },
                ATTR_stars_inst_pos   = { buffer_index = 1, format = .FLOAT3 },
                ATTR_stars_inst_scale = { buffer_index = 1, format = .FLOAT  },
                ATTR_stars_inst_color = { buffer_index = 1, format = .FLOAT4 },
            },
        },
        colors = {
            0 = {
                blend = {
                    enabled = true,
                    src_factor_rgb   = .SRC_ALPHA,
                    dst_factor_rgb   = .ONE, // Additive blending for "bright" stars
                    src_factor_alpha = .ONE,
                    dst_factor_alpha = .ZERO
                }
            }
        },
        depth = {
            write_enabled = false,
            compare = .LESS_EQUAL,
        },
    })

    return stars
}

update_sun :: proc(stars: ^Star_Renderer, sky: Sky_State) {
    angle := (sky.time_of_day - 0.25) * 2.0 * math.PI
    stars.instances[0].pos = { math.cos(angle), math.sin(angle), 0.1 }
    stars.instances[0].color = sky.now.sun_color
}

add_star :: proc(stars: ^Star_Renderer, cam: ^Camera, input: Actions) {
    stars.instances[stars.active].pos = cam.front
    stars.instances[stars.active].scale = rand.float32_range(1.0, 4.0)
    col := rand.float32_range(0.3, 1.0)
    stars.instances[stars.active].color = { col, col, col, 0.6 }

    stars.active += 1
    fmt.printf("Adding star %v\n", stars.instances[stars.active].pos)
    fmt.printf("Active stars: %d\n", stars.active)
    for i := 0; i < stars.active; i+=1 {
        fmt.printf("Star %v\n", stars.instances[i])
    }
}

draw_stars :: proc(stars : ^Star_Renderer, cam: ^Camera, time_of_day: f32) {
    using shaders

    proj := glsl.mat4Perspective(glsl.radians(cam.fov), cam.aspect, 0.1, 10000.0)
    view := glsl.mat4LookAt(cam.position, cam.position + cam.front, cam.up)

    vs_uniforms := Star_Params {
        view = transmute([16]f32)view,
        proj = transmute([16]f32)proj,
    }

    sg.apply_pipeline(stars.pip)
    sg.apply_bindings(stars.bind)
    sg.apply_uniforms(UB_star_params, { ptr = &vs_uniforms, size = size_of(vs_uniforms) })

    sg.update_buffer(stars.bind.vertex_buffers[1], {
        ptr  = &stars.instances[0], // TODO: be careful about the pointers if/when we switch to a slice
        size = size_of(stars.instances),
    })

    sg.apply_pipeline(stars.pip)
    sg.apply_bindings(stars.bind)
    sg.draw(0, 6, stars.active)
}
