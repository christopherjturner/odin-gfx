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
        pip:  sg.Pipeline,
        bind: sg.Bindings,
    },
    display: struct {
        pass: sg.Pass_Action,
        pip:  sg.Pipeline,
        bind: sg.Bindings,
    },
    grid: struct {
        pip:  sg.Pipeline,
        bind: sg.Bindings,
        count: i32,
    },
    world: struct {
        fog_start: f32,
        fog_end: f32,
    },
    meshes:     Mesh_Renderer,
    sky:        Sky_Renderer,
    stars:      Star_Renderer,
    billboards: Billboard_Renderer,
    terrain:    Terrain_Renderer,
    camera:     Camera,
    keys:       Actions,
    debug_ui:   ^Debug_UI,
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

    // Skybox
    state.sky  = init_sky()
    state.stars = init_stars()

    // Terrain
    state.terrain = init_terrain()

    // Billboards
    state.billboards = init_billboards()

    // @TODO: init the instances in the billboard system
    state.billboards.instances[0].pos.y = get_terrain_height(&state.terrain, state.billboards.instances[0].pos.x,state.billboards.instances[0].pos.z) + 1.0
    state.billboards.instances[1].pos.y = get_terrain_height(&state.terrain, state.billboards.instances[1].pos.x,state.billboards.instances[1].pos.z) + 1.0

    // Meshes
    state.meshes = init_meshes()

    // Grid generation
    init_grid()

    // Display Pipeline setup
    offscreen_img, offscreen_depth_img := init_offscreen_renderer()
    init_display_renderer(offscreen_img, offscreen_depth_img)

    state.world = {
        fog_start = 50,
        fog_end   = 250,
    }

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
    sdtx.printf("(%.1f, %.1f, %.1f) -  FPS %.1f %.1f \n",
                state.camera.front.x, state.camera.front.y, state.camera.front.z, fps, t)

    view_proj := get_view_proj(&state.camera)

    // Match the clear color to the sky
    sky_col := state.sky.state.now.horizon_color;
    state.offscreen.pass.action.colors[0].clear_value = { r = sky_col[0], g = sky_col[1], b = sky_col[2], a = 1.0 };

    // Pass 1: Render to texture
    sg.begin_pass({
        action      = state.offscreen.pass.action,
        attachments = state.offscreen.pass.attachments
    })

    // SKY & stars (this doesnt write to the depth buffer, so we draw it first)
    update_sun(&state.stars, state.sky.state)
    draw_sky(&state.sky, &state.camera, t)
    draw_stars(&state.stars, &state.camera, state.sky.state.time_of_day)

    // Terrain
    draw_terrain(&state.terrain, &state.camera)

    // GRID
    //draw_grid(&state.camera)

    draw_meshes(&state.meshes, &state.camera)

    // Billboards
    draw_billboards(&state.billboards, &state.camera)

    sg.end_pass()


    // pass 2: Displaying and scaling render texture
    sg.begin_pass({ action = state.display.pass, swapchain = sglue.swapchain() })

    sg.apply_pipeline(state.display.pip)
    sg.apply_bindings(state.display.bind)

    display_fs_params := Display_Fs_Params {
        resolution     = { sapp.widthf(), sapp.heightf(),  },
        inv_resolution = { 1.0 /sapp.widthf(), 1.0/sapp.heightf(), },
        fog_color      = state.sky.state.now.horizon_color,
        fog_start      = state.world.fog_start,
        fog_end        = state.world.fog_end,
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
            }if e.key_code == .P {
                add_star(&state.stars, &state.camera, state.keys)
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


init_offscreen_renderer :: proc() -> (sg.Image, sg.Image) {
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
        usage        = { color_attachment = true },
        width        = OFFSCREEN_WIDTH,
        height       = OFFSCREEN_HEIGHT,
        pixel_format = .RGBA8,
        sample_count = 1,
    })

    depth_img := sg.make_image({
        usage        = { depth_stencil_attachment = true },
        width        = OFFSCREEN_WIDTH,
        height       = OFFSCREEN_HEIGHT,
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

    sky_col := state.sky.state.now.horizon_color;
    state.offscreen.pass.action = {
        colors = {
            0 = { load_action = .CLEAR, clear_value = { r = sky_col[0], g = sky_col[1], b = sky_col[2], a = 1.0 } },
        },
        depth = { load_action = .CLEAR, clear_value = 1.0 },
    }

    return color_img, depth_img
}

init_display_renderer :: proc(color_img: sg.Image, depth_img: sg.Image) {
    using shaders
    state.display.pip = sg.make_pipeline({
        shader    = sg.make_shader(display_shader_desc(sg.query_backend())),
        cull_mode = .NONE
    })

    state.display.bind.views[VIEW_tex] = sg.make_view({
        texture = { image = color_img },
    })

    state.display.bind.views[VIEW_depthTex] = sg.make_view({
        texture = { image = depth_img },
    })

    state.display.bind.samplers[SMP_smp] = sg.make_sampler({
        min_filter = .LINEAR, //NEAREST,
        mag_filter = .LINEAR,
        wrap_u     = .REPEAT,
        wrap_v     = .REPEAT,
    })

    state.display.bind.samplers[SMP_depthSmp] = sg.make_sampler({
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
        wrap_u     = .REPEAT,
        wrap_v     = .REPEAT,
    })

    sky_col := state.sky.state.now.horizon_color;

    state.display.pass = {
        colors = {
            0 = { load_action = .CLEAR, clear_value = { 0.0, 0.0, 0.0, 1.0 } },
        },
        depth = { load_action = .CLEAR, clear_value = 1.0 },
    }
}
