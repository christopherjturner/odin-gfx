package main

import "core:fmt"
import "base:runtime"
import mu "vendor:microui"
import sapp "./sokol/app"
import sg "./sokol/gfx"
import sgl "./sokol/gl"

Debug_UI :: struct {
    pip:             sgl.Pipeline,
    mu_ctx:          mu.Context,
    bg:              mu.Color,
    atlas_img:       sg.Image,
    atlas_view:      sg.View,
    atlas_smp:       sg.Sampler,
    key_map:         map[sapp.Keycode]mu.Key,
    active:          bool,
}


init_debug_ui :: proc() -> ^Debug_UI {

    debug_ui := new(Debug_UI)

    pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT)
    for alpha, i in mu.default_atlas_alpha {
        pixels[i].rgb = 0xff
        pixels[i].a = alpha
    }

    debug_ui.atlas_img = sg.make_image(
        sg.Image_Desc {
            width = mu.DEFAULT_ATLAS_WIDTH,
            height = mu.DEFAULT_ATLAS_HEIGHT,
            data =  {
                mip_levels = {
                    0 = {
                            ptr = raw_data(pixels),
                            size = mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT * 4,
                        },
                },
            },
        },
    )

    debug_ui.atlas_smp = sg.make_sampler(
        sg.Sampler_Desc{min_filter = .NEAREST, mag_filter = .NEAREST},
    )

    debug_ui.atlas_view = sg.make_view({
        texture = {
            image = debug_ui.atlas_img,
        }
    })

    debug_ui.pip = sgl.make_pipeline(
        sg.Pipeline_Desc {
            colors =  {
                0 =  {
                    blend =  {
                        enabled = true,
                        src_factor_rgb = .SRC_ALPHA,
                        dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
                    },
                },
            },
        },
    )

    free(raw_data(pixels))

    ctx := &debug_ui.mu_ctx
    mu.init(ctx)
    ctx.text_width = mu.default_atlas_text_width
    ctx.text_height = mu.default_atlas_text_height

    return debug_ui
}


draw_debug_ui :: proc(debug_ui: ^Debug_UI) {
    context = runtime.default_context()

    mu_ctx := &debug_ui.mu_ctx
    mu.begin(mu_ctx)
    layout_debug_ui(mu_ctx)
    mu.end(mu_ctx)

    r_begin(sapp.width(), sapp.height(), debug_ui)
    command_backing: ^mu.Command

    for variant in mu.next_command_iterator(mu_ctx, &command_backing) {
        switch cmd in variant {
        case ^mu.Command_Text:
            r_draw_text(cmd.str, cmd.pos, cmd.color)
        case ^mu.Command_Rect:
            r_draw_rect(cmd.rect, cmd.color)
        case ^mu.Command_Icon:
            r_draw_icon(cmd.id, cmd.rect, cmd.color)
        case ^mu.Command_Clip:
            r_set_clip_rect(cmd.rect)
        case ^mu.Command_Jump:
            unreachable()
        }
    }
    r_end()
    r_draw()
}

debug_ui_input :: proc "c" (ev: ^sapp.Event, debug_ui: ^Debug_UI) {
    context = runtime.default_context()

    mu_ctx := &debug_ui.mu_ctx
    #partial switch ev.type {
    case .MOUSE_DOWN:
        mu.input_mouse_down(mu_ctx, i32(ev.mouse_x), i32(ev.mouse_y), mu.Mouse(ev.mouse_button))
    case .MOUSE_UP:
        mu.input_mouse_up(mu_ctx, i32(ev.mouse_x), i32(ev.mouse_y), mu.Mouse(ev.mouse_button))
    case .MOUSE_MOVE:
        mu.input_mouse_move(mu_ctx, i32(ev.mouse_x), i32(ev.mouse_y))
    case .MOUSE_SCROLL:
        mu.input_scroll(mu_ctx, 0, i32(ev.scroll_y))
    case .KEY_DOWN:
        if ev.key_code in debug_ui.key_map {
            mu.input_key_down(mu_ctx, debug_ui.key_map[ev.key_code])
        }
    case .KEY_UP:
        if ev.key_code in debug_ui.key_map {
            mu.input_key_up(mu_ctx, debug_ui.key_map[ev.key_code])
        }
    case .CHAR:
        mu.input_text(mu_ctx, fmt.tprint(rune(ev.char_code)))
    }
}

layout_debug_ui :: proc(ctx: ^mu.Context) {
    if mu.window(ctx, "Style Window", {350, 250, 300, 240}) {
        sw := i32(f32(mu.get_current_container(ctx).body.w) * 0.25)

        // heightmap checks
        mu.layout_row(ctx, {100, 100, -1})
        height := get_terrain_height(&state.terrain, state.camera.position.x, state.camera.position.z)
        mu.label(ctx, fmt.tprintf("height %.3f", height))


        mu.layout_row(ctx, {100, 100, -1})
        mu.label(ctx, fmt.tprintf("game time %.1f", state.sky.state.game_time))
        mu.label(ctx, fmt.tprintf("time_of_day %.1f", state.sky.state.time_of_day))

        mu.layout_row(ctx, {100, -1})
        mu.label(ctx, "time of day")
        f32_slider(ctx, &state.sky.state.time_of_day, 0.0, 1.0)


        for i := 0; i < len(sky_palette.keyframes); i += 1 {
            mu.layout_row(ctx, {sw, sw, sw, sw, -1})
            mu.label(ctx, fmt.tprintf("%.2f", sky_palette.keyframes[i].time))
            f32_slider(ctx, &sky_palette.keyframes[i].horizon_color.r, 0.0, 1.0)
            f32_slider(ctx, &sky_palette.keyframes[i].horizon_color.b, 0.0, 1.0)
            f32_slider(ctx, &sky_palette.keyframes[i].horizon_color.g, 0.0, 1.0)
        }


    }
}

u8_slider :: proc(ctx: ^mu.Context, val: ^u8, lo, hi: u8) -> (res: mu.Result_Set) {
    mu.push_id(ctx, uintptr(val))
    @(static)
    tmp: mu.Real
    tmp = mu.Real(val^)
    res = mu.slider(ctx, &tmp, mu.Real(lo), mu.Real(hi), 0, "%.0f", {.ALIGN_CENTER})
    val^ = u8(tmp)
    mu.pop_id(ctx)
    return
}

f32_slider :: proc(ctx: ^mu.Context, val: ^f32, lo, hi: f32) -> (res: mu.Result_Set) {
    mu.push_id(ctx, uintptr(val))
    @(static)
    tmp: mu.Real
    tmp = mu.Real(val^)
    res = mu.slider(ctx, &tmp, mu.Real(lo), mu.Real(hi), 0, "%.2f", {.ALIGN_CENTER})
    val^ = f32(tmp)
    mu.pop_id(ctx)
    return
}



r_begin :: proc(disp_width, disp_height: i32, debug_ui: ^Debug_UI) {
    sgl.defaults()
    sgl.push_pipeline()
    sgl.load_pipeline(debug_ui.pip)
    sgl.enable_texture()
    sgl.texture(debug_ui.atlas_view, debug_ui.atlas_smp)
    sgl.matrix_mode_projection()
    sgl.push_matrix()
    sgl.ortho(0.0, f32(disp_width), f32(disp_height), 0.0, -1.0, +1.0)
    sgl.begin_quads()
}


r_push_quad :: proc(dst: mu.Rect, src: mu.Rect, color: mu.Color) {
    u0 := f32(src.x) / f32(mu.DEFAULT_ATLAS_WIDTH)
    v0 := f32(src.y) / f32(mu.DEFAULT_ATLAS_HEIGHT)
    u1 := f32(src.x + src.w) / f32(mu.DEFAULT_ATLAS_WIDTH)
    v1 := f32(src.y + src.h) / f32(mu.DEFAULT_ATLAS_HEIGHT)

    x0 := f32(dst.x)
    y0 := f32(dst.y)
    x1 := f32(dst.x + dst.w)
    y1 := f32(dst.y + dst.h)

    sgl.c4b(color.r, color.g, color.b, color.a)
    sgl.v2f_t2f(x0, y0, u0, v0)
    sgl.v2f_t2f(x1, y0, u1, v0)
    sgl.v2f_t2f(x1, y1, u1, v1)
    sgl.v2f_t2f(x0, y1, u0, v1)
}

r_draw_text :: proc(text: string, pos: mu.Vec2, color: mu.Color) {
    dst := mu.Rect{pos.x, pos.y, 0, 0}
    for ch in text {
        src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + int(ch)]
        dst.w = src.w
        dst.h = src.h
        r_push_quad(dst, src, color)
        dst.x += dst.w
    }
}

r_draw_rect :: proc(rect: mu.Rect, color: mu.Color) {
    r_push_quad(rect, mu.default_atlas[mu.DEFAULT_ATLAS_WHITE], color)
}

r_draw_icon :: proc(id: mu.Icon, rect: mu.Rect, color: mu.Color) {
    src := mu.default_atlas[id]
    x := rect.x + (rect.w - src.w) / 2
    y := rect.y + (rect.h - src.h) / 2
    r_push_quad(mu.Rect{x, y, src.w, src.h}, src, color)
}

r_set_clip_rect :: proc(rect: mu.Rect) {
    sgl.end()
    sgl.scissor_rect(rect.x, rect.y, rect.w, rect.h, true)
    sgl.begin_quads()
}

r_end :: proc() {
    sgl.end()
    sgl.pop_matrix()
    sgl.pop_pipeline()
}

r_draw :: proc() {
    sgl.draw()
}
