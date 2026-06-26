package game

MAX_ENTITIES :: 1024

import "core:math/linalg/glsl"


Spherical :: struct {
    radius: f32
}

AABB :: struct {
    min: glsl.vec3,
    max: glsl.vec3,
}

Attribute :: struct {
    active: bool,
}

Transform :: struct {
	pos:   glsl.vec3,
	rot:   glsl.quat,
	scale: glsl.vec3,
}

Static_Model :: struct {
    // mesh ref,
    // color/other per instance vars
}


Skinned_Model :: struct {
    // mesh ref,
    // animator,
    // color/other per instance vars
}


Billboard_Model :: struct {
    // texture ref,
    // color/other per instance vars
}

Renderable :: union { Static_Model, Skinned_Model }

Collidable :: struct {
    active: bool,
    aabb:: AABB,
    sphere:: Spherical,
}

Stats :: struct {
    speed: f32,
    turn_speed: f32,
    weight: f32,
    flying: bool,
}

EntityState :: struct {
    seen: f32,
    can_see_player: f32, // how long have they seen them for
}

Movement :: struct {
    vel: glsl.vec3,
}

GameState :: struct {
    transforms:   [MAX_ENTITIES]Transform,
    renderables:  [MAX_ENTITIES]Renderable,
}
