package main

import "base:runtime"
import "core:fmt"
import img "vendor:stb/image"
import slog "./sokol/log"
import sg "./sokol/gfx"
import sgl "./sokol/gl"

import sapp "./sokol/app"
import sglue "./sokol/glue"
import sdtx "./sokol/debugtext"
import "core:math/linalg/glsl"

import m "./math"
import "./shaders"

FONT_KC853 :: 0
FONT_KC854 :: 1
FONT_Z1013 :: 2
FONT_CPC   :: 3
FONT_C64   :: 4
FONT_ORIC  :: 5


OFFSCREEN_WIDTH  :: 640
OFFSCREEN_HEIGHT :: 480


state: struct {
    offscreen: struct {
        pass: sg.Pass,
        pip: sg.Pipeline,
        bind: sg.Bindings,
    },
    display: struct {
        pass: sg.Pass_Action,
        pip: sg.Pipeline,
        bind: sg.Bindings,
    },
    grid: struct {
        pip: sg.Pipeline,
        bind: sg.Bindings,
        count: i32,
    },
    sky: Sky_Renderer,
    billboards: Billboard_Renderer,
    terrain: Terrain_Renderer,
    rx, ry, vx, vy: f32,
    camera: Camera,
    keys: Actions,
    debug_ui: ^Debug_UI,
}

Vertex :: struct {
    x, y, z: f32,
    color: u32,
    u, v: u16,
}

Grid_Vertex :: struct {
    pos: [3]f32,
    color: [4]f32,
}


init :: proc "c" () {
    context = runtime.default_context()
    using shaders
    sg.setup({
        environment = sglue.environment(),
        logger = { func = slog.func },
    })

    sdtx.setup({
        fonts = {
            FONT_KC853 = sdtx.font_kc853(),
            FONT_KC854 = sdtx.font_kc854(),
            FONT_Z1013 = sdtx.font_z1013(),
            FONT_CPC   = sdtx.font_cpc(),
            FONT_C64   = sdtx.font_c64(),
            FONT_ORIC  = sdtx.font_oric(),
        },
        logger = { func = slog.func },
    })

    // sgl for ui
    sgl.setup({})

    // init camera
    state.camera = init_camera(sapp.widthf() / sapp.heightf())
    //sapp.lock_mouse(true)

    uv_max :: 1024 * 6
    vertices := [?]Vertex {
        // pos               color       uvs
        { -1.0, -1.0, -1.0,  0xFF0000FF,     0,     0 },
        {  1.0, -1.0, -1.0,  0xFF0000FF, uv_max,     0 },
        {  1.0,  1.0, -1.0,  0xFF0000FF, uv_max, uv_max },
        { -1.0,  1.0, -1.0,  0xFF0000FF,     0, uv_max },

        { -1.0, -1.0,  1.0,  0xFF00FF00,     0,     0 },
        {  1.0, -1.0,  1.0,  0xFF00FF00, uv_max,     0 },
        {  1.0,  1.0,  1.0,  0xFF00FF00, uv_max, uv_max },
        { -1.0,  1.0,  1.0,  0xFF00FF00,     0, uv_max },
        { -1.0, -1.0, -1.0,  0xFFFF0000,     0,     0 },
        { -1.0,  1.0, -1.0,  0xFFFF0000, uv_max,     0 },
        { -1.0,  1.0,  1.0,  0xFFFF0000, uv_max, uv_max },
        { -1.0, -1.0,  1.0,  0xFFFF0000,     0,  uv_max },

        {  1.0, -1.0, -1.0,  0xFFFF007F,     0,     0 },
        {  1.0,  1.0, -1.0,  0xFFFF007F, uv_max,     0 },
        {  1.0,  1.0,  1.0,  0xFFFF007F, uv_max, uv_max },
        {  1.0, -1.0,  1.0,  0xFFFF007F,     0, uv_max },

        { -1.0, -1.0, -1.0,  0xFFFF7F00,     0,     0 },
        { -1.0, -1.0,  1.0,  0xFFFF7F00, uv_max,     0 },
        {  1.0, -1.0,  1.0,  0xFFFF7F00, uv_max, uv_max },
        {  1.0, -1.0, -1.0,  0xFFFF7F00,     0, uv_max },

        { -1.0,  1.0, -1.0,  0xFF007FFF,     0,     0 },
        { -1.0,  1.0,  1.0,  0xFF007FFF, uv_max,     0 },
        {  1.0,  1.0,  1.0,  0xFF007FFF, uv_max, uv_max },
        {  1.0,  1.0, -1.0,  0xFF007FFF,     0, uv_max },
    }

    state.offscreen.bind.vertex_buffers[0] = sg.make_buffer({
        data = { ptr = &vertices, size = size_of(vertices) },
    })

    indices := [?]u16 {
        0, 1, 2,  0, 2, 3,
        6, 5, 4,  7, 6, 4,
        8, 9, 10,  8, 10, 11,
        14, 13, 12,  15, 14, 12,
        16, 17, 18,  16, 18, 19,
        22, 21, 20,  23, 22, 20,
    }
    state.offscreen.bind.index_buffer = sg.make_buffer({
        usage = { index_buffer = true },
        data = { ptr = &indices, size = size_of(indices) },
    })

    // Texture Loading
    t_width, t_height, t_chan: i32
    pixels := img.load("./texture.png", &t_width, &t_height, &t_chan, 4)
    if pixels == nil {
        fmt.println("image failed to load")
        sapp.quit()
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

    state.offscreen.bind.views[VIEW_tex] = sg.make_view({
        texture = {
            image = sg.make_image(img_desc)
        }
    })

    state.offscreen.bind.samplers[SMP_smp] = sg.make_sampler({})

    // Skybox
    state.sky = init_sky()

    // Terrain
    state.terrain = init_terrain()

    // Billboards
    state.billboards = init_billboards()
    // @hack
    state.billboards.instances[0].pos.y = get_terrain_height(&state.terrain, state.billboards.instances[0].pos.x,state.billboards.instances[0].pos.z) + 1.0
    state.billboards.instances[1].pos.y = get_terrain_height(&state.terrain, state.billboards.instances[1].pos.x,state.billboards.instances[1].pos.z) + 1.0


    // Grid generation
    init_grid()

    // Display Pipeline setup
    offscreen_img := init_offscreen_renderer()
    init_display_renderer(offscreen_img)

    // UIs
    state.debug_ui = init_debug_ui();
}


//------------//
// Frame
//------------//
frame :: proc "c" () {
    context = runtime.default_context()
    using shaders
    t := f32(sapp.frame_duration())

    if .Action in state.keys {
        state.vx = 1
    } else {
        state.vx = 0
    }

    state.rx += state.vx * t
    state.ry += state.vy * t

    state.camera.aspect = sapp.widthf() / sapp.heightf()
    update_camera(&state.camera)
    update_camera_movement(&state.camera, state.keys, t)

    // TEMP: stick camera to the terrain
    height := get_terrain_height(&state.terrain, state.camera.position.x, state.camera.position.z) + 1.0
    state.camera.position.y = height

    // Get the current FPS
    fps := 1 / sapp.frame_duration()

    sdtx.canvas(sapp.widthf() * 0.5, sapp.heightf() * 0.5)
    sdtx.origin(0.0, 2.0)
    sdtx.color3f(1.0, 0.0, 1.0)
    sdtx.font(FONT_CPC)
    sdtx.printf("hello world %.1f %.1f \n", fps, t)

    view_proj := get_view_proj(&state.camera)


    // Pass 1: Render to texture
    sg.begin_pass({
        action = state.offscreen.pass.action,
        attachments = state.offscreen.pass.attachments,
        swapchain = sglue.swapchain()
    })

    // SKY (this doesnt write to the depth buffer, so we draw it first)
    draw_sky(&state.sky, &state.camera, t)

    // Terrain
    draw_terrain(&state.terrain, &state.camera)

    // GRID
    //draw_grid(&state.camera)

    // CUBE
    sg.apply_pipeline(state.offscreen.pip)
    sg.apply_bindings(state.offscreen.bind)
    vs_params := Vs_Params {
        mvp = compute_mvp(state.rx, state.ry)
    }
    sg.apply_uniforms(UB_vs_params, { ptr = &vs_params, size = size_of(vs_params) })
    sg.draw(0, 36, 1)

    // Billboards
    draw_billboards(&state.billboards, &state.camera)

    sg.end_pass()


    // pass 2: Displaying and scaling render texture

    sg.begin_pass({ action = state.display.pass, swapchain = sglue.swapchain() })

    sg.apply_pipeline(state.display.pip)
    sg.apply_bindings(state.display.bind)

    flag: f32 = 0.0
    if .Up in state.keys do flag = 1.0

    display_fs_params := Display_Fs_Params {
        enable         = flag,
        resolution     = { sapp.widthf(), sapp.heightf(),  },
        inv_resolution = { 1.0 /sapp.widthf(), 1.0/sapp.heightf(), },
    }
    sg.apply_uniforms(UB_display_fs_params, { ptr = &display_fs_params, size = size_of(display_fs_params) })

    sg.draw(0,3,1)
    sdtx.draw()

    if state.debug_ui.active {
        draw_debug_ui(state.debug_ui)
    }

    sg.end_pass()

    sg.commit()
}

//------------//
// Events
//------------//
event :: proc "c" (e: ^sapp.Event) {
    context = runtime.default_context()

    if e.type == .KEY_DOWN || e.type == .KEY_UP {
        if action, ok := get_action(e.key_code); ok {
            if e.type == .KEY_DOWN {
                state.keys += {action}
            } else {
                state.keys -= {action}
            }
        }

        if e.type == .KEY_UP {
            if e.key_code == .ESCAPE {
                sapp.request_quit()
            }

            if e.key_code == .TAB {
                state.debug_ui.active = !state.debug_ui.active
            }
        }

    }

    if state.debug_ui.active {
        sapp.lock_mouse(false)
        debug_ui_input(e, state.debug_ui)
        return
    } else {
        sapp.lock_mouse(true)
        handle_camera_input(&state.camera, e)
    }
}


compute_mvp :: proc (rx, ry: f32) -> [16]f32 {
    model := glsl.mat4Rotate({1, 0, 0}, rx)
    model  = model * glsl.mat4Rotate({0, 1, 0}, ry)
    view_proj := get_view_proj(&state.camera)
    mvp := view_proj * model
    return transmute([16]f32)mvp
}


cleanup :: proc "c" () {
    context = runtime.default_context()
    sapp.lock_mouse(false)
    sgl.shutdown()
    sdtx.shutdown()
    sg.shutdown()
}

main :: proc() {
    sapp.run({
        init_cb      = init,
        frame_cb     = frame,
        cleanup_cb   = cleanup,
        event_cb     = event,
        width        = 800,
        height       = 600,
        sample_count = 4,
        window_title = "texcube",
        icon         = { sokol_default = true },
        logger       = { func = slog.func },
        fullscreen   = true,
    })
}


init_offscreen_renderer :: proc() -> sg.Image {
    using shaders
    // Offscreen Pipeline setup
    state.offscreen.pip = sg.make_pipeline({
        shader = sg.make_shader(texcube_shader_desc(sg.query_backend())),
        layout = {
            attrs = {
                ATTR_texcube_pos       = { format = .FLOAT3 },
                ATTR_texcube_color0    = { format = .UBYTE4N },
                ATTR_texcube_texcoord0 = { format = .SHORT2N },
            },
        },
        index_type   = .UINT16,
        cull_mode    = .BACK,
        sample_count = 1,
        colors = {
            0 = { pixel_format = .RGBA8 },
        },
        depth = {
            compare       = .LESS_EQUAL,
            write_enabled = true,
        },
    })

    // setup the color and depth-stencil-attachment images and views
    color_img := sg.make_image({
        usage = { color_attachment = true },
        width = OFFSCREEN_WIDTH,
        height = OFFSCREEN_HEIGHT,
        pixel_format = .RGBA8,
        sample_count = 1,
    })
    depth_img := sg.make_image({
        usage = { depth_stencil_attachment = true },
        width = OFFSCREEN_WIDTH,
        height = OFFSCREEN_HEIGHT,
        sample_count = 1,
        pixel_format = .DEPTH,
    })

    // the offscreen render passes need a color and depth-stencil-attachment view
    state.offscreen.pass.attachments.colors[0] = sg.make_view({
        color_attachment = { image = color_img },
    })
    state.offscreen.pass.attachments.depth_stencil = sg.make_view({
        depth_stencil_attachment = { image = depth_img },
    })
    state.offscreen.pass.action = {
        colors = {
            0 = { load_action = .CLEAR, clear_value = { 0.1, 0.1, 0.75, 1.0 } },
        },
        depth = { load_action = .CLEAR, clear_value = 1.0 },
    }

    return color_img
}

init_display_renderer :: proc(color_img: sg.Image) {
    using shaders
    state.display.pip = sg.make_pipeline({
        shader = sg.make_shader(display_shader_desc(sg.query_backend())),
        cull_mode = .NONE
    })

    state.display.bind.views[VIEW_tex] = sg.make_view({
        texture = { image = color_img },
    })

    state.display.bind.samplers[SMP_smp] = sg.make_sampler({
        min_filter = .LINEAR, //NEAREST,
        mag_filter = .LINEAR,
        wrap_u = .REPEAT,
        wrap_v = .REPEAT,
    })

    state.display.pass = {
        colors = {
            0 = { load_action = .CLEAR, clear_value = { 0.0, 0.0, 0.0, 1.0 } },
        },
        depth = { load_action = .CLEAR, clear_value = 1.0 },
    }

}
