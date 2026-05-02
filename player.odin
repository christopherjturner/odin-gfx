package main

import "core:math/linalg/glsl"


Flight_State :: struct {
    velocity:      [3]f32,
    angular_vel:   [3]f32, // For smooth rotation damping

    // Coefficients (Tweak these for "Arcade" vs "Sim")
    lift_factor:   f32, // How much lift per unit of speed
    drag_factor:   f32, // Base air resistance
    stall_angle:   f32, // The angle where lift disappears

    is_flapping:   bool,
    flap_cooldown: f32,
}

Player :: struct {
    position :: glsl.vec3,
    velocity :: glsl.vec3,
    orientation:  linalg.Quaternion, // Use quaternions to avoid gimbal lock

    pitch:        f32,
    yaw:          f32,
    roll:         f32,

    speed:        f32,
    stamina:      f32,
    is_gliding:   bool,
}


apply_flight_physics :: proc(camera: ^Camera, flight_state: ^Flight_State, dt: f32) {
    forward := camera.front //get_forward_vector(bird.orientation)
    up      := camera.up //get_up_vector(bird.orientation)

    speed := glsl.length(flight_state.velocity)

    // 1. Drag (increases with speed squared)
    drag_mag := speed * speed * flight_state.drag_factor
    drag_force := -glsl.normalize(flight_state.velocity) * drag_mag

    // 2. Lift (Simplified: Lift points 'up' relative to bird, based on speed)
    // Real lift depends on "Angle of Attack," but for approachable flight,
    // speed-based lift is more intuitive.
    lift_mag := speed * flight_state.lift_factor
    lift_force := up * lift_mag

    // 3. Flapping (Thrust)
    thrust_force: [3]f32
    if flight_state.is_flapping {
        thrust_force = forward * 50.0
    }

    // Total Force = Gravity + Lift + Drag + Thrust
    total_force := [3]f32{0, -9.81, 0} + lift_force + drag_force + thrust_force

    // Acceleration = F / m (assuming mass = 1)
    flight_state.velocity += total_force * dt
    camera.position  += flight_state.velocity * dt
}
