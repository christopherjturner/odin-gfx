package main

import "core:math/linalg/glsl"


Player :: struct {
    position : glsl.vec3,
    forward  : glsl.vec3,

    yaw      : f32,
    pitch    : f32,
    speed    : f32,
}


update_player :: proc(player: ^Player, input: ^InputState, dt: f32) {

    front: glsl.vec3
    front.x   = glsl.cos(glsl.radians(player.yaw)) * glsl.cos(glsl.radians(player.pitch))
    front.y   = glsl.sin(glsl.radians(player.pitch))
    front.z   = glsl.sin(glsl.radians(player.yaw)) * glsl.cos(glsl.radians(player.pitch))
    player.forward = glsl.normalize(front)

    speed := player.speed * dt
    if action_down(&state.input, .Forward) {
        player.position += player.forward * speed
    }
    if action_down(&state.input, .Backward) {
        player.position -= player.forward * speed
    }

    if action_down(&state.input, .Left) {
        player.yaw -= speed
    }
    if action_down(&state.input, .Right) {
        player.yaw += speed
    }

    if player.pitch > 89.0  do player.pitch = 89.0
    if player.pitch < -89.0 do player.pitch = -89.0
}
