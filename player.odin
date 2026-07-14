package main

import "core:fmt"
import "core:math/linalg/glsl"


Player :: struct {
	position: glsl.vec3,
	forward:  glsl.vec3,
	yaw:      f32,
	pitch:    f32,
	speed:    f32,
	collide:  bool,
	vel:      glsl.vec3
}


update_player :: proc(player: ^Player, input: ^InputState, dt: f32) {

	front: glsl.vec3
	front.x = glsl.cos(glsl.radians(player.yaw)) * glsl.cos(glsl.radians(player.pitch))
	front.y = glsl.sin(glsl.radians(player.pitch))
	front.z = glsl.sin(glsl.radians(player.yaw)) * glsl.cos(glsl.radians(player.pitch))
	player.forward = glsl.normalize(front)

	old_pos := player.position

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

	if player.pitch > 89.0 do player.pitch = 89.0
	if player.pitch < -89.0 do player.pitch = -89.0

	if check_player_collison(player, state.static_meshes) do player.position = old_pos
}

check_player_collison :: proc(player: ^Player, smr: Static_Mesh_Renderer) -> bool {
	size := glsl.vec3{0.5, 0.5, 0.5}
	aabb := AABB {
		max = player.position + size,
		min = player.position - size,
	}

	player.collide = false

	for model in smr.models {
		if (check_aabb_aabb(aabb, model.mesh.aabb)) {
			fmt.println("collide")
			player.collide = true
			return true
		}
	}
	return false
}
