package main

import sapp "./sokol/app"

Action :: enum {
    Forward,
    Backward,
    Left,
    Right,
    Up,
    Down,
    Sprint,
    Action
}

Actions :: bit_set[Action]

get_action :: proc(key: sapp.Keycode) -> (Action, bool) {
    #partial switch key {
        case .W:          return .Forward,  true
        case .S:          return .Backward, true
        case .A:          return .Left,     true
        case .D:          return .Right,    true
        case .E:          return .Action,   true
        case .SPACE:      return .Up,       true
        case .LEFT_CONTROL: return .Down,     true
        case .LEFT_SHIFT:   return .Sprint,   true
    }
    return nil, false
}
