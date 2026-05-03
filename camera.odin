package main

import "core:math/linalg/glsl"

import sapp "./sokol/app"

Camera :: struct {
    position : glsl.vec3,
    front    : glsl.vec3,
    up       : glsl.vec3,
    right    : glsl.vec3,
    target   : glsl.vec3,

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
        speed    = 50.0,
        sens     = 0.1,
    }
    return cam
}


// Basically just a freecam atm
update_fps_camera :: proc(cam: ^Camera, dt: f32) {

    // Direction
    cam.yaw   += state.input.mouse_dx * cam.sens
    cam.pitch -= state.input.mouse_dy * cam.sens

    // Constrain pitch to avoid flipping
    if cam.pitch > 89.0  do cam.pitch = 89.0
    if cam.pitch < -89.0 do cam.pitch = -89.0

    front: glsl.vec3
    front.x   = glsl.cos(glsl.radians(cam.yaw)) * glsl.cos(glsl.radians(cam.pitch))
    front.y   = glsl.sin(glsl.radians(cam.pitch))
    front.z   = glsl.sin(glsl.radians(cam.yaw)) * glsl.cos(glsl.radians(cam.pitch))
    cam.front = glsl.normalize(front)
    cam.right = glsl.normalize(glsl.cross(cam.front, cam.up))

    // Movement
    speed := cam.speed * dt
    if action_down(&state.input, .Forward) {
        cam.position += cam.front * speed
    }
    if action_down(&state.input, .Backward) {
        cam.position -= cam.front * speed
    }

    if action_down(&state.input, .Left) {
        cam.position -= cam.right * speed
    }
    if action_down(&state.input, .Right) {
        cam.position += cam.right * speed
    }

    cam.target = cam.position + cam.front
}

get_view_proj :: proc(cam: ^Camera) -> glsl.mat4 {
    proj := glsl.mat4Perspective(glsl.radians(cam.fov), cam.aspect, 0.1, 1000.0)
    view := glsl.mat4LookAt(cam.position, cam.target, cam.up)
    return proj * view
}

update_camera_follow_behind_target :: proc(
    cam: ^Camera,
    target: glsl.vec3,
    target_forward: glsl.vec3,
    distance: f32,
    height: f32,
) {
    world_up := glsl.vec3{0, 1, 0}

    forward := glsl.normalize(target_forward)

    cam.position = target - forward * distance + world_up * height

    height := get_terrain_height(&state.terrain, cam.position.x, cam.position.z)
    cam.position.y = glsl.max(height + 3.0, cam.position.y)

    // Look at the target, slightly above its origin
    look_target := target + world_up * height * 0.5

    cam.front = glsl.normalize(look_target - cam.position)
    cam.right = glsl.normalize(glsl.cross(cam.front, world_up))
    cam.up    = glsl.normalize(glsl.cross(cam.right, cam.front))
    cam.target = target
}
