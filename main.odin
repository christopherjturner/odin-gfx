package main

import "base:runtime"
import "core:fmt"

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
        game_time:       f32,
        time_of_day:     f32,
        time_multiplier: f32,
        fog_start:       f32,
        fog_end:         f32,
    },
    meshes:     Mesh_Renderer,
    sky:        Sky_Renderer,
    stars:      Star_Renderer,
    billboards: Billboard_Renderer,
    terrain:    Terrain_Renderer,
    game_ui:    ^Game_UI,
    camera:     Camera,
    debug_ui:   ^Debug_UI,
    player:     Player,
    input:      InputState,
}

init :: proc "c" () {
    context = runtime.default_context()

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

    // sgl for debug ui
    sgl.setup({})

    state.input.bindings = init_key_bindings()

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
    //state.billboards.instances[1].pos.y = get_terrain_height(&state.terrain, state.billboards.instances[1].pos.x,state.billboards.instances[1].pos.z) + 1.0

    state.player = {
        position = state.billboards.instances[0].pos,
        forward  = {0,0,0},
        yaw      = -90.0,
        pitch    = 0.0,
        speed    = 50.0,
    }

    // Meshes
    state.meshes = init_meshes()

    // Grid generation
    init_grid()

    // Display Pipeline setup
    offscreen_img, offscreen_depth_img := init_offscreen_renderer()
    init_display_renderer(offscreen_img, offscreen_depth_img)

    state.world = {
        time_multiplier = 1.0,
        fog_start       = 50,
        fog_end         = 250,
    }

    // UIs
    state.game_ui  = init_game_ui();
    state.debug_ui = init_debug_ui();

    fmt.printfln("Who/what is podgin?")
}


//------------//
// Frame
//------------//
frame :: proc "c" () {

    context = runtime.default_context()
    t := f32(sapp.frame_duration())

    handle_global_actions()

    update_player(&state.player, &state.input, t)
    gravity := 6.7 * t
    state.player.position.y = glsl.max(state.player.position.y - gravity , get_terrain_height(&state.terrain, state.player.position.x, state.player.position.z) + 1.0)
    state.meshes.models[0].transform.pos = state.player.position
    state.meshes.models[0].transform.rot = quat_from_pitch_yaw(glsl.radians(state.player.pitch), -glsl.radians(state.player.yaw - 90))
    // TEMP: use billboard 0 as the player sprite

    state.camera.aspect = sapp.widthf() / sapp.heightf()

    //update_fps_camera(&state.camera, t)
    update_camera_follow_behind_target(&state.camera, state.player.position, state.player.forward, 25.0, 5)

    // TEMP: stick camera to the terrain
    //height := get_terrain_height(&state.terrain, state.camera.position.x, state.camera.position.z)
    //state.camera.position.y = glsl.max(height + 3.0, state.camera.position.y)

    // Get the current FPS
    fps := 1 / sapp.frame_duration()

    sdtx.canvas(sapp.widthf() * 0.5, sapp.heightf() * 0.5)
    sdtx.origin(0.0, 2.0)
    sdtx.color3f(1.0, 0.0, 1.0)
    sdtx.font(FONT_CPC)
    sdtx.printf("(%.1f, %.1f, %.1f) -  FPS %.1f %.1f \n",
                state.camera.position.x, state.camera.position.y, state.camera.position.z, fps, t)

    // Increment time
    if !state.debug_ui.active {
        state.world.game_time += (t * state.world.time_multiplier);
        state.world.time_of_day = glsl.mod(0.5 + (state.world.game_time * 0.01), 1.0);
    }

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
    draw_stars(&state.stars, &state.camera, state.world.time_of_day)

    // Terrain
    draw_terrain(&state.terrain, &state.camera)

    // GRID
    //draw_grid(&state.camera)
    draw_meshes(&state.meshes, &state.camera, t)

    // Billboards
    draw_billboards(&state.billboards, &state.camera)

    sg.end_pass()

    // pass 2: Displaying and scaling render texture
    sg.begin_pass({ action = state.display.pass, swapchain = sglue.swapchain() })

    sg.apply_pipeline(state.display.pip)
    sg.apply_bindings(state.display.bind)

    display_fs_params := shaders.Display_Fs_Params {
        resolution     = { sapp.widthf(), sapp.heightf(),  },
        inv_resolution = { 1.0 /sapp.widthf(), 1.0/sapp.heightf(), },
        fog_color      = state.sky.state.now.horizon_color,
        fog_start      = state.world.fog_start,
        fog_end        = state.world.fog_end,
    }
    sg.apply_uniforms(shaders.UB_display_fs_params, { ptr = &display_fs_params, size = size_of(display_fs_params) })

    sg.draw(0,3,1)
    sdtx.draw()

    if state.debug_ui.active {
        draw_debug_ui(state.debug_ui)
    }

    //draw_game_ui(state.game_ui)

    sg.end_pass()

    sg.commit()

    reset_input(&state.input)
}

//------------//
// Events
//------------//
event :: proc "c" (e: ^sapp.Event) {
    context = runtime.default_context()

    handle_input_event(e, &state.input)
    // Pass input to debug UI if its open
    if state.debug_ui.active {
        sapp.lock_mouse(false)
        debug_ui_input(e, state.debug_ui)
        return
    } else {
        sapp.lock_mouse(true)
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
        window_title = "podgin sim",
        icon         = { sokol_default = true },
        logger       = { func = slog.func },
        fullscreen   = true,
    })
}

handle_global_actions :: proc() {

    if action_released(&state.input, .Quit) {
        sapp.request_quit()
    }

    if action_released(&state.input, .Debug) {
        state.debug_ui.active = !state.debug_ui.active
    }

    if action_released(&state.input, .Edit) {
        add_star(&state.stars, &state.camera)
    }
}

init_offscreen_renderer :: proc() -> (sg.Image, sg.Image) {

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

    state.display.pip = sg.make_pipeline({
        shader    = sg.make_shader(shaders.display_shader_desc(sg.query_backend())),
        cull_mode = .NONE
    })

    state.display.bind.views[shaders.VIEW_tex] = sg.make_view({
        texture = { image = color_img },
    })

    state.display.bind.views[shaders.VIEW_depthTex] = sg.make_view({
        texture = { image = depth_img },
    })

    state.display.bind.samplers[shaders.SMP_smp] = sg.make_sampler({
        min_filter = .LINEAR, //NEAREST,
        mag_filter = .LINEAR,
        wrap_u     = .REPEAT,
        wrap_v     = .REPEAT,
    })

    state.display.bind.samplers[shaders.SMP_depthSmp] = sg.make_sampler({
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
        wrap_u     = .REPEAT,
        wrap_v     = .REPEAT,
    })

    state.display.pass = {
        colors = {
            0 = { load_action = .CLEAR, clear_value = { 0.0, 0.0, 0.0, 1.0 } },
        },
        depth = { load_action = .CLEAR, clear_value = 1.0 },
    }
}
