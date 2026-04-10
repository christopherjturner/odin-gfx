package main

import "core:fmt"
import "core:math"
import "core:math/linalg/glsl"

import img "vendor:stb/image"
import sg "./sokol/gfx"

import "./shaders"

MAX_STARS :: 9

Star :: struct {
    lat: f32,
    lon: f32,
    size: f32,
    intensity: f32, // 0.0 - 1.0
}

Star_Renderer :: struct {
    pip:   sg.Pipeline,
    bind:  sg.Bindings,
    stars: [MAX_STARS]Star,
    instances: [MAX_STARS]Billboard_Instance,
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
    pixels := img.load("./assets/textures/star1.png", &t_width, &t_height, &t_chan, 4)
    if pixels == nil {
        panic("image failed to load")
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
            compare       = .LESS_EQUAL, // TODO: what should this be?
        },
    })

    stars.stars = {
        { 120.0, 45.0, 1.0, 5.0 },
        { 125.0, 40.0, 1.0, 4.0 },
        { 135.0, 38.0, 1.1, 3.0 },
        { 140.0, 42.0, 1.0, 2.0 },
        { 150.0, 48.0, 0.8, 1.0 },
        { 160.0, 52.0, 0.6, 0.5 },
        { 170.0, 305.0, 1.3, 0.25 },
        { 170.0, 205.0, 1.3, 0.25 },
        { 40.0,  15.0, 1.0, 0.25 },
    }

    for star, i in stars.stars {
        theta := math.to_radians(star.lon)
        phi   := math.to_radians(star.lat)
        stars.instances[i] = {
            {
                math.cos(phi) * math.cos(theta),
                math.sin(phi),
                math.cos(phi) * math.sin(theta),
            },
            star.size
        }
    }

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

draw_stars :: proc(stars : ^Star_Renderer, cam: ^Camera, t: f32) {
    using shaders

    proj := glsl.mat4Perspective(glsl.radians(cam.fov), cam.aspect, 0.1, 10000.0)
    view := glsl.mat4LookAt(cam.position, cam.position + cam.front, cam.up)

    vs_uniforms := Star_Params {
        view       = transmute([16]f32)view,
        proj       = transmute([16]f32)proj,
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
    sg.draw(0, 6, len(stars.instances))
}
