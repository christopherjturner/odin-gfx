package main

import "./shaders"
import sg "./sokol/gfx"
import "core:fmt"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:mem"


Transform :: struct {
	pos:   glsl.vec3,
	rot:   glsl.quat,
	scale: glsl.vec3,
}



Mesh_Renderer :: struct {
	pip:    sg.Pipeline,
	bind:   sg.Bindings,
	models: [1]Model,
}


Model :: struct {
	mesh:        ^Mesh,
	transform:   Transform,
	vert_offset: int,
	idx_offset:  int,
    animator:    ^Animator,
}

Animator :: struct {
    animation_index: int,
    animation_time:  f32,

    pose:        []Pose,
    global_mats: []glsl.mat4,
    skin_mats:   [64]glsl.mat4,
}


init_meshes :: proc() -> Mesh_Renderer {
	mesh_renderer: Mesh_Renderer

	// TODO: dynamically load the mesh_renderer from data.
	// TODO: pack all the mesh_renderer into a single vertex bufffer.
	mesh := load_mesh("./assets/meshes/pigeon1.glb")

	mesh_renderer.bind.vertex_buffers[0] = mesh.vertex_buffer
	mesh_renderer.bind.index_buffer = mesh.index_buffer

	mesh_renderer.models[0].mesh = mesh
    mesh_renderer.models[0].animator = init_animator(mesh, context.allocator)

	mesh_renderer.models[0].transform.pos = {3, 4, 3}
	mesh_renderer.models[0].transform.rot.w = 1
	mesh_renderer.models[0].transform.scale = {0.1, 0.1, 0.1}

	shader := sg.make_shader(shaders.meshshader_shader_desc(sg.query_backend()))
	mesh_renderer.pip = sg.make_pipeline({
		shader = shader,
		layout = {
			attrs = {
				shaders.ATTR_meshshader_position  = {format = .FLOAT3},
				shaders.ATTR_meshshader_texcoord0 = {format = .FLOAT2},
				shaders.ATTR_meshshader_normal    = {format = .FLOAT3},
				shaders.ATTR_meshshader_joints    = {format = .UINT4},
				shaders.ATTR_meshshader_weights   = {format = .FLOAT4},
			},
		},
		index_type   = .UINT16,
        face_winding = .CCW, // gltf vs sokol quirk
		cull_mode    = .BACK,
		depth        = {compare = .LESS_EQUAL, write_enabled = true},
	})

	// TODO: load from the glsl instead
	texture := load_texture("./assets/meshes/pigeon1/textures/my_67_baseColor.png")
	mesh_renderer.bind.views[shaders.VIEW_mesh_tex] = sg.make_view({texture = {image = texture}})

	mesh_renderer.bind.samplers[shaders.SMP_mesh_smp] = sg.make_sampler({})
	return mesh_renderer
}


// TODO: manage a list of active mesh_renderer and draw all of the in one go.
draw_meshes :: proc(mesh_renderer: ^Mesh_Renderer, camera: ^Camera, dt: f32) {
	sg.apply_pipeline(mesh_renderer.pip)
	sg.apply_bindings(mesh_renderer.bind)

	view_proj := get_view_proj(camera)
	model_mat := model_matrix_from_transform(mesh_renderer.models[0].transform)

    // TODO: move animation refreshing to its own function so we can control the rate
    update_animation(&mesh_renderer.models[0], dt)

    vs_params := shaders.Mesh_Vs_Params {
		view_proj     = transmute([16]f32)view_proj,
		model         = transmute([16]f32)model_mat,
		ambient_color = state.sky.state.now.ambient_color,
		sun_color     = state.sky.state.now.sun_color, // * state.sky.state.now.sun_intensity,
		u_sun_dir     = state.sky.state.sun_dir,
        u_joints      = transmute([64][16]f32)mesh_renderer.models[0].animator.skin_mats,
	}
	sg.apply_uniforms(shaders.UB_mesh_vs_params, {
        ptr = &vs_params,
        size = size_of(vs_params)
    })
	sg.draw(0, mesh_renderer.models[0].mesh.index_count, 1)

}


model_matrix_from_transform :: proc(t: Transform) -> glsl.mat4 {
	T := glsl.mat4Translate(t.pos)
	R := glsl.mat4FromQuat(t.rot)
	S := glsl.mat4Scale(t.scale)

	return T * R * S
}

quat_from_pitch_yaw :: proc(pitch, yaw: f32) -> glsl.quat {
	yaw_q := glsl.quatAxisAngle({0, 1, 0}, yaw)
	pitch_q := glsl.quatAxisAngle({1, 0, 0}, pitch)

	return glsl.normalize(yaw_q * pitch_q)
}


// Animator setup

init_animator :: proc(mesh: ^Mesh, allocator: mem.Allocator) -> ^Animator {
    joint_count := len(mesh.skeleton.joints)

    inst := new(Animator, allocator)
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
    skeleton := &model.mesh.skeleton
    model.animator.animation_time = model.animator.animation_time + dt
    // For rest pose only:

    copy(model.animator.pose, skeleton.rest_pose)
    for _, i in model.mesh.skeleton.joints {
        track := model.mesh.animations[0].tracks[i]
        model.animator.pose[i] = sample_track(track, model.animator.animation_time, model.animator.pose[i])
    }

    build_global_mats(skeleton, model.animator)
    build_skin_mats(skeleton, model.animator)
}

sample_track :: proc(track: JointTrack, t: f32, base_pose: Pose) -> Pose {
    pose := base_pose // Start with the rest pose

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

        lerped_rot := glsl.lerp(track.rotation_values[r1], track.rotation_values[r2], ra)
        // Ensure the resulting quaternion is normalized so the mesh doesn't distort
        pose.rotation = transmute([4]f32)glsl.normalize(transmute(quaternion128)lerped_rot)
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

find_keyframes :: proc(track: JointTrack, t: f32) -> (t1, t2, r1, r2, s1, s2: int) {
    t1, t2 = find_keyframe_pair(track.translation_times, t)
    r1, r2 = find_keyframe_pair(track.rotation_times, t)
    s1, s2 = find_keyframe_pair(track.scale_times, t)

    return
}

pose_to_mat4 :: proc(p: Pose) -> glsl.mat4 {
    T := glsl.mat4Translate(p.translation)
    local_rot := p.rotation
    R := glsl.mat4FromQuat(transmute(quaternion128)local_rot)
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
        // 1. Copy the unaligned array to a local stack variable
        local_inverse_array := skeleton.joints[i].inverse_bind
        // 2. Transmute the locally aligned copy safely
        aligned_inverse_mat := transmute(glsl.mat4)local_inverse_array
        animator.skin_mats[i] = animator.global_mats[i] * aligned_inverse_mat
    }
}
