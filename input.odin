package main

import sapp "./sokol/app"

MAX_KEYS    :: 512
MAX_BUTTONS :: 5

InputState :: struct {
    keys_down:     [MAX_KEYS]bool,
    keys_pressed:  [MAX_KEYS]bool,
    keys_released: [MAX_KEYS]bool,

    mouse_down:     [MAX_BUTTONS]bool,
    mouse_pressed:  [MAX_BUTTONS]bool,
    mouse_released: [MAX_BUTTONS]bool,

    mouse_x: f32,
    mouse_y: f32,

    mouse_dx: f32,
    mouse_dy: f32,

    wheel_x: f32,
    wheel_y: f32,

    mouse_locked: bool,

    bindings: KeyBindings
}

Action :: enum {
    Forward,
    Backward,
    Left,
    Right,
    Up,
    Down,
    Sprint,
    Action,
    Debug,
    Edit,
    Quit,
}

// TODO: maybe allow for button bindings?
KeyBind :: struct {
    key: sapp.Keycode
}

KeyBindings :: [Action]KeyBind

handle_input_event :: proc(ev: ^sapp.Event, input: ^InputState) {
    #partial switch ev.type {
    case .KEY_DOWN:
        code := int(ev.key_code)
        if !ev.key_repeat {
            if !input.keys_down[code] {
                input.keys_pressed[code] = true
            }
            input.keys_down[code] = true
        }

    case .KEY_UP:
        code := int(ev.key_code)
        if !ev.key_repeat {
            input.keys_down[code] = false
            input.keys_released[code] = true
        }

    case .MOUSE_DOWN:
        code := int(ev.mouse_button)
        if !input.mouse_down[code] {
            input.mouse_pressed[code] = true
        }
        input.mouse_down[code] = true

    case .MOUSE_UP:
        code := int(ev.mouse_button)
        input.mouse_down[code] = false
        input.mouse_released[code] = true

    case .MOUSE_MOVE:
        input.mouse_x = ev.mouse_x
        input.mouse_y = ev.mouse_y

        input.mouse_dx += ev.mouse_dx
        input.mouse_dy += ev.mouse_dy

    case .MOUSE_SCROLL:
        input.wheel_x += ev.scroll_x
        input.wheel_y += ev.scroll_y
    }
}

reset_input :: proc(input: ^InputState) {
    for i in 0..<MAX_KEYS {
        input.keys_pressed[i]  = false
        input.keys_released[i] = false
    }

    for i in 0..<MAX_BUTTONS {
        input.mouse_pressed[i]  = false
        input.mouse_released[i] = false
    }

    input.mouse_dx = 0
    input.mouse_dy = 0

    input.wheel_x = 0
    input.wheel_y = 0
}


// Raw key inputs
key_down :: proc(input: ^InputState, key: sapp.Keycode) -> bool {
    return input.keys_down[int(key)]
}

key_pressed :: proc(input: ^InputState, key: sapp.Keycode) -> bool {
    return input.keys_pressed[int(key)]
}

key_released :: proc(input: ^InputState, key: sapp.Keycode) -> bool {
    return input.keys_released[int(key)]
}


// Mouse button inputs
mouse_down :: proc(input: ^InputState, button: sapp.Mousebutton) -> bool {
    return input.mouse_down[int(button)]
}

mouse_pressed :: proc(input: ^InputState, button: sapp.Mousebutton) -> bool {
    return input.mouse_pressed[int(button)]
}

mouse_released :: proc(input: ^InputState, button: sapp.Mousebutton) -> bool {
    return input.mouse_released[int(button)]
}


// Action inputs
action_down :: proc(input: ^InputState, action: Action) -> bool {
    return input.keys_down[int(input.bindings[action].key)]
}

action_pressed :: proc(input: ^InputState, action: Action) -> bool {
    return input.keys_pressed[int(input.bindings[action].key)]
}

action_released :: proc(input: ^InputState, action: Action) -> bool {
    return input.keys_released[int(input.bindings[action].key)]
}


init_key_bindings :: proc() -> KeyBindings {
    // TODO: load from cfg
    binds := KeyBindings {}

    binds[.Forward]  = KeyBind{ key = .W }
    binds[.Backward] = KeyBind{ key = .S }
    binds[.Left]     = KeyBind{ key = .A }
    binds[.Right]    = KeyBind{ key = .D }

    binds[.Action]   = KeyBind{ key = .E }
    binds[.Up]       = KeyBind{ key = .SPACE }
    binds[.Down]     = KeyBind{ key = .LEFT_CONTROL }
    binds[.Sprint]   = KeyBind{ key = .LEFT_SHIFT }

    binds[.Debug]    = KeyBind{ key = .TAB }
    binds[.Edit]     = KeyBind{ key = .P }
    binds[.Quit]     = KeyBind{ key = .ESCAPE }

    return binds
}
