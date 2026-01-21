package main

import "core:math/linalg/glsl"

import sapp "./sokol/app"

Camera :: struct {
    position : glsl.vec3,
    front    : glsl.vec3,
    up       : glsl.vec3,
    right    : glsl.vec3,

    yaw      : f32,
    pitch    : f32,

    fov      : f32,
    aspect   : f32,
    speed    : f32,
    sens     : f32,
}


init_camera :: proc(aspect: f32) -> Camera {
    cam := Camera {
        position = {0, 1, 10},
        front    = {0, 0, 0},
        up       = {0, 1, 0},
        yaw      = -90.0,
        pitch    = 0.0,
        fov      = 45.0,
        aspect   = aspect,
        speed    = 5.0,
        sens     = 0.1,
    }
    update_camera(&cam)
    return cam
}

update_camera :: proc(cam: ^Camera) {
    front: glsl.vec3
    front.x   = glsl.cos(glsl.radians(cam.yaw)) * glsl.cos(glsl.radians(cam.pitch))
    front.y   = glsl.sin(glsl.radians(cam.pitch))
    front.z   = glsl.sin(glsl.radians(cam.yaw)) * glsl.cos(glsl.radians(cam.pitch))
    cam.front = glsl.normalize(front)
    cam.right = glsl.normalize(glsl.cross(cam.front, glsl.vec3{0, 1, 0}))
}

handle_camera_input :: proc(cam: ^Camera, ev: ^sapp.Event) {
    #partial switch ev.type {
    case .MOUSE_MOVE:
        //if ev.mouse_button == .LEFT { // Only rotate when clicking, or use sapp.lock_mouse()
            cam.yaw   += ev.mouse_dx * cam.sens
            cam.pitch -= ev.mouse_dy * cam.sens
            // Constrain pitch to avoid flipping
            if cam.pitch > 89.0  do cam.pitch = 89.0
            if cam.pitch < -89.0 do cam.pitch = -89.0
        //}
    }

    update_camera(cam)

}

update_camera_movement :: proc(cam: ^Camera, input: Actions, dt: f32) {
    speed := cam.speed * dt
    if .Forward in input do cam.position += cam.front * speed
    if .Backward in input do cam.position -= cam.front * speed

    right := glsl.normalize(glsl.cross(cam.front, cam.up))
    if .Left     in input do cam.position -= right * speed
    if .Right    in input do cam.position += right * speed
}

get_view_proj :: proc(cam: ^Camera) -> glsl.mat4 {
    proj := glsl.mat4Perspective(glsl.radians(cam.fov), cam.aspect, 0.1, 10000.0)
    view := glsl.mat4LookAt(cam.position, cam.position + cam.front, cam.up)
    return proj * view
}

