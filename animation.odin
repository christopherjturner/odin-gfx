package main

import "core:math/linalg/glsl"
import "core:mem"


ANIMATION_FPS: f32 = 1.0 / 60
MAX_JOINTS :: 64

Animator :: struct {
    animation_index: int,
    animation_time:  f32,
    last_update:     f32,

    pose:        []Pose,
    global_mats: []glsl.mat4,
    skin_mats:   [64]glsl.mat4,
}


init_animator :: proc(mesh: ^Mesh, allocator: mem.Allocator) -> ^Animator {
    joint_count := len(mesh.skeleton.joints)
    assert(joint_count <= MAX_JOINTS)

    inst := new(Animator)
    inst.animation_index = 0
    inst.animation_time  = 0
    inst.pose            = make([]Pose, joint_count, allocator)
    inst.global_mats     = make([]glsl.mat4, joint_count, allocator)

    copy(inst.pose, mesh.skeleton.rest_pose)
    return inst
}

update_animation :: proc(model: ^Model, dt: f32) {

    if model.animator == nil {
        return
    }

    // Cap animation FPS
    model.animator.last_update += dt
    if model.animator.last_update < ANIMATION_FPS {
        return
    }
    model.animator.last_update = 0


    skeleton := &model.mesh.skeleton
    model.animator.animation_time += dt

    frame_start: f32 = 1.0
    frame_end:   f32 = 1.5
    frame_time := frame_start + glsl.mod(model.animator.animation_time, frame_end - frame_start)

    copy(model.animator.pose, skeleton.rest_pose)

    for _, i in model.mesh.skeleton.joints {
        track := model.mesh.animations[0].tracks[i]
        model.animator.pose[i] = sample_track(track, frame_time, model.animator.pose[i])
    }

    build_global_mats(skeleton, model.animator)
    build_skin_mats(skeleton, model.animator)
}

sample_track :: proc(track: JointTrack, t: f32, base_pose: Pose) -> Pose {
    pose := base_pose

    // Only sample Translation if the track exists
    if len(track.translation_times) > 0 {
        t1, t2 := find_keyframe_pair(track.translation_times, t)
        ta: f32 = 0
        if t1 != t2 {
            ta = (t - track.translation_times[t1]) / (track.translation_times[t2] - track.translation_times[t1])
        }
        pose.translation = glsl.lerp(track.translation_values[t1], track.translation_values[t2], ta)
    }

    // Only sample Rotation if the track exists
    if len(track.rotation_times) > 0 {
        r1, r2 := find_keyframe_pair(track.rotation_times, t)
        ra: f32 = 0
        if r1 != r2 {
            ra = (t - track.rotation_times[r1]) / (track.rotation_times[r2] - track.rotation_times[r1])
        }

        // TODO: check if we still need to normalise it after slerp
        pose.rotation = glsl.slerp(track.rotation_values[r1], track.rotation_values[r2], ra)
    }

    // Only sample Scale if the track exists
    if len(track.scale_times) > 0 {
        s1, s2 := find_keyframe_pair(track.scale_times, t)
        sa: f32 = 0
        if s1 != s2 {
            sa = (t - track.scale_times[s1]) / (track.scale_times[s2] - track.scale_times[s1])
        }
        pose.scale = glsl.lerp(track.scale_values[s1], track.scale_values[s2], sa)
    }

    return pose
}

find_keyframe_pair :: proc(times: []f32, t: f32) -> (i0, i1: int) {
    count := len(times)

    if count == 0 {
        return -1, -1
    }

    if count == 1 {
        return 0, 0
    }

    if t <= times[0] {
        return 0, 0
    }

    last := count - 1

    if t >= times[last] {
        return last, last
    }

    for i := 0; i < last; i += 1 {
        if times[i] <= t && t < times[i + 1] {
            return i, i + 1
        }
    }

    return last, last
}

pose_to_mat4 :: proc(p: Pose) -> glsl.mat4 {
    T := glsl.mat4Translate(p.translation)
    R := glsl.mat4FromQuat(p.rotation)
    S := glsl.mat4Scale(p.scale)
    return T * R * S
}

build_global_mats :: proc(skeleton: ^Skeleton, animator: ^Animator) {
    assert(len(animator.global_mats) >= len(skeleton.joints))
    assert(len(animator.pose) >= len(skeleton.joints))

    for i in 0..<len(skeleton.joints) {
        local := pose_to_mat4(animator.pose[i])
        parent := skeleton.joints[i].parent

        if parent >= 0 {
            animator.global_mats[i] = animator.global_mats[parent] * local
        } else {
            animator.global_mats[i] = local
        }

    }
}

build_skin_mats :: proc(skeleton: ^Skeleton, animator: ^Animator) {
    assert(len(animator.global_mats) >= len(skeleton.joints))
    assert(len(animator.pose) >= len(skeleton.joints))

    for i in 0..<len(skeleton.joints) {
        animator.skin_mats[i] = animator.global_mats[i] * skeleton.joints[i].inverse_bind
    }
}
