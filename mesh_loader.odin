package main

import "core:fmt"
import "core:math/linalg/glsl"
import "vendor:cgltf"

import sg "./sokol/gfx"


MeshVert :: struct {
	pos:     [3]f32,
	uv:      [2]f32,
	normal:  [3]f32,
	joints:  [4]u32,
	weights: [4]f32,
}

Mesh :: struct {
	vertex_buffer: sg.Buffer,
	index_buffer:  sg.Buffer,
	index_count:   i32,
	skeleton:      Skeleton,
    animations:    []Animation,
    aabb:          AABB,
}

StaticMeshVert :: struct {
	pos:     [3]f32,
	uv:      [2]f32,
	normal:  [3]f32,
}

StaticMesh :: struct {
	vertex_buffer: sg.Buffer,
	index_buffer:  sg.Buffer,
	index_count:   i32,
    aabb:          AABB,
}

Joint :: struct {
	parent:       int,
	inverse_bind: glsl.mat4,
}

Pose :: struct {
	translation: [3]f32,
	rotation:    quaternion128,
	scale:       [3]f32,
}

Skeleton :: struct {
	joints:    []Joint,
	rest_pose: []Pose,
}

JointTrack :: struct {
	translation_times:  []f32,
	translation_values: [][3]f32,
    translation_linear: bool,

	rotation_times:     []f32,
	rotation_values:    []quaternion128,
    rotation_linear:    bool,

    scale_times:        []f32,
	scale_values:       [][3]f32,
    scale_linear:       bool,
}

Animation :: struct {
	duration: f32,
	tracks:   []JointTrack,
}

AABB :: struct {
    min: [3]f32,
    max: [3]f32,
}

load_mesh :: proc(filename: cstring) -> ^Mesh {
	options: cgltf.options
	mesh := new(Mesh)

	data, result := cgltf.parse_file(options, filename)
	if result != .success {
		panic("failed to load model")
	}

	defer cgltf.free(data)

	res := cgltf.load_buffers(options, data, filename)
	if res != .success {
		panic("failed to load buffers")
	}

    node_to_joint := make(map[^cgltf.node]int)
    defer delete(node_to_joint)
	for j, i in data.skins[0].joints {
        node_to_joint[j] = i
    }

	// Load joints/bones
	mesh.skeleton.joints    = make([]Joint, len(data.skins[0].joints))
    mesh.skeleton.rest_pose = make([]Pose,  len(data.skins[0].joints))

	for j, i in data.skins[0].joints {

        // inverse bind matrix
        unaligned_mat: [16]f32
		if !cgltf.accessor_read_float(data.skins[0].inverse_bind_matrices, uint(i), &unaligned_mat[0], 16) {
			panic("failed to read inverse bind matrix")
		}
        mesh.skeleton.joints[i].inverse_bind = transmute(glsl.mat4)unaligned_mat

        // rest pose
        if j.has_matrix {
            panic("TODO: convert matrix to pose TRS")
        } else {
            rot := transmute(quaternion128)j.rotation
            mesh.skeleton.rest_pose[i].translation = j.translation
            mesh.skeleton.rest_pose[i].rotation    = rot
            mesh.skeleton.rest_pose[i].scale       = j.scale
        }

		mesh.skeleton.joints[i].parent = node_to_joint[j.parent]
        if mesh.skeleton.joints[i].parent == i {
            // i.e. it points to itself
            mesh.skeleton.joints[i].parent = -1
        }
        fmt.printfln("%d joint %s parented to %d", i, j.name, mesh.skeleton.joints[i].parent)
	}

    // Load animations
    mesh.animations = make([]Animation, len(data.animations))

	for animation, i in data.animations {
        mesh.animations[i].tracks = make([]JointTrack, len(mesh.skeleton.joints))
        ani := mesh.animations[i]
        ani.duration = 0

        // TODO: store name
		for c in animation.channels {
			#partial switch c.target_path {
	        case .translation:
                joint_idx, is_joint := node_to_joint[c.target_node]
                if !is_joint do continue

                ani.tracks[joint_idx].translation_times  = make([]f32, c.sampler.input.count)
                ani.tracks[joint_idx].translation_values = make([][3]f32, c.sampler.output.count)
                ani.tracks[joint_idx].translation_linear = c.sampler.interpolation == .linear

                fmt.printfln("Added %d tracks to joint %d", c.sampler.input.count, joint_idx)

                for input_i in 0..<c.sampler.input.count {
				    if !cgltf.accessor_read_float(c.sampler.input, input_i, &ani.tracks[joint_idx].translation_times[input_i], 1) {
					    panic("failed to read pos timings")
				    }
                    ani.duration = glsl.max(ani.duration, ani.tracks[joint_idx].translation_times[input_i])
                }

                for output_i in 0..<c.sampler.output.count {
				    if !cgltf.accessor_read_float(c.sampler.output, output_i, &ani.tracks[joint_idx].translation_values[output_i][0], 3) {
					    panic("failed to read pos values")
				    }
                }

			case .rotation:
                joint_idx, is_joint := node_to_joint[c.target_node]
                if !is_joint do continue

                ani.tracks[joint_idx].rotation_times  = make([]f32, c.sampler.input.count)
                ani.tracks[joint_idx].rotation_values = make([]quaternion128, c.sampler.output.count)
                ani.tracks[joint_idx].rotation_linear = c.sampler.interpolation == .linear

                for input_i in 0..<c.sampler.input.count {
				    if !cgltf.accessor_read_float(c.sampler.input, input_i, &ani.tracks[joint_idx].rotation_times[input_i], 1) {
					    panic("failed to read rot timings")
				    }
                    ani.duration = glsl.max(ani.duration, ani.tracks[joint_idx].rotation_times[input_i])
                }

                for output_i in 0..<c.sampler.output.count {
                    unaligned_rot: [4]f32
				    if !cgltf.accessor_read_float(c.sampler.output, output_i, &unaligned_rot[0], 4) {
					    panic("failed to read rot values")
				    }
                    ani.tracks[joint_idx].rotation_values[output_i] = transmute(quaternion128)unaligned_rot
                }

			case .scale:
                joint_idx, is_joint := node_to_joint[c.target_node]
                if !is_joint do continue
                ani.tracks[joint_idx].scale_times  = make([]f32, c.sampler.input.count)
                ani.tracks[joint_idx].scale_values = make([][3]f32, c.sampler.output.count)
                ani.tracks[joint_idx].scale_linear = c.sampler.interpolation == .linear

                for input_i in 0..<c.sampler.input.count {
				    if !cgltf.accessor_read_float(c.sampler.input, input_i, &ani.tracks[joint_idx].scale_times[input_i], 1) {
					    panic("failed to read scale timings")
				    }
                    ani.duration = glsl.max(ani.duration, ani.tracks[joint_idx].scale_times[input_i])
                }

                for output_i in 0..<c.sampler.output.count {
				    if !cgltf.accessor_read_float(c.sampler.output, output_i, &ani.tracks[joint_idx].scale_values[output_i][0], 3) {
					    panic("failed to read scale values")
				    }
                }
			}
		}
        fmt.printfln("animation duration %f", ani.duration)
	}


	// load vert data
	p := data.meshes[0].primitives[0]
	count := cast(int)p.attributes[0].data.count
	fmt.printf("%s: mesh 0 primative 0 attr count %d\n", filename, count)

	verts := make([]MeshVert, count)
	defer delete(verts)

    mesh.aabb = AABB {
        min = { 999999, 999999, 999999 },
        max = { -999999, -999999, -999999 },
    }

	for i in 0 ..< count {
		v := &verts[i]

		for a in p.attributes {

			#partial switch a.type {
			case .position:
				ok := cgltf.accessor_read_float(a.data, cast(uint)i, &v.pos[0], 3)
				if !ok {
					panic("failed to read verts")
				}
                mesh.aabb.min = { min(mesh.aabb.min[0], v.pos[0]), min(mesh.aabb.min[1], v.pos[1]), min(mesh.aabb.min[2], v.pos[2]) }
                mesh.aabb.max = { max(mesh.aabb.max[0], v.pos[0]), max(mesh.aabb.max[1], v.pos[1]), max(mesh.aabb.max[2], v.pos[2]) }
			case .texcoord:
				if a.index == 0 {
 	                // limited to 1 set of uvs
					ok := cgltf.accessor_read_float(a.data, cast(uint)i, &v.uv[0], 2)
					if !ok {
						panic("failed to read verts")
					}
				}
			case .normal:
				ok := cgltf.accessor_read_float(a.data, cast(uint)i, &v.normal[0], 3)
				if !ok {
					panic("failed to read verts")
				}
			case .joints:
				ok := cgltf.accessor_read_uint(a.data, cast(uint)i, &v.joints[0], 4)
				if !ok {
					panic("failed to read joint")
				}
			case .weights:
				ok := cgltf.accessor_read_float(a.data, cast(uint)i, &v.weights[0], 4)
				if !ok {
					panic("failed to read weights")
				}
			}
		}
	}
    fmt.printfln("mesh aabb %v", mesh.aabb)
    // load vertex buffer
	mesh.vertex_buffer = sg.make_buffer({
        usage = { vertex_buffer = true, immutable = true },
        data = {
            ptr = raw_data(verts),
            size =len(verts) * size_of(MeshVert),
        }
    })

	index_count := cast(i32)p.indices.count
	unpacked_indices := make([]u16, index_count) // Or u32 if your models are large
	defer delete(unpacked_indices)

	for i in 0 ..< index_count {
		unpacked_indices[i] = cast(u16)cgltf.accessor_read_index(p.indices, cast(uint)i)
	}

	// load index buffer
	mesh.index_buffer = sg.make_buffer({
		usage = { index_buffer = true, immutable = true },
		data = {
            ptr = raw_data(unpacked_indices),
            size = len(unpacked_indices) * size_of(u16)
        },
	})

	mesh.index_count = index_count

	return mesh
}


load_static_mesh :: proc(filename: cstring) -> ^StaticMesh {
	options: cgltf.options
	mesh := new(StaticMesh)

	data, result := cgltf.parse_file(options, filename)
	if result != .success {
		panic("failed to load model")
	}

	defer cgltf.free(data)

	res := cgltf.load_buffers(options, data, filename)
	if res != .success {
		panic("failed to load buffers")
	}

	p := data.meshes[0].primitives[0]
	count := cast(int)p.attributes[0].data.count
	fmt.printf("%s: static mesh 0 primative 0 attr count %d\n", filename, count)

	verts := make([]StaticMeshVert, count)
	defer delete(verts)

    mesh.aabb = AABB {
        max = { -999999, -999999, -999999 },
        min = {  999999,  999999,  999999 },
    }

	for i in 0 ..< count {
		v := &verts[i]

		for a in p.attributes {
			#partial switch a.type {
			case .position:
				ok := cgltf.accessor_read_float(a.data, cast(uint)i, &v.pos[0], 3)
				if !ok {
					panic("failed to read verts")
				}
                mesh.aabb.min = { min(mesh.aabb.min[0], v.pos[0]), min(mesh.aabb.min[1], v.pos[1]), min(mesh.aabb.min[2], v.pos[2]) }
                mesh.aabb.max = { max(mesh.aabb.max[0], v.pos[0]), max(mesh.aabb.max[1], v.pos[1]), max(mesh.aabb.max[2], v.pos[2]) }
			case .texcoord:
				if a.index == 0 {
 	                // limited to 1 set of uvs
					ok := cgltf.accessor_read_float(a.data, cast(uint)i, &v.uv[0], 2)
					if !ok {
						panic("failed to read verts")
					}
				}
			case .normal:
				ok := cgltf.accessor_read_float(a.data, cast(uint)i, &v.normal[0], 3)
				if !ok {
					panic("failed to read verts")
				}
			}
		}
	}

    // load vertex buffer
	mesh.vertex_buffer = sg.make_buffer({
        usage = { vertex_buffer = true, immutable = true },
        data = {
            ptr = raw_data(verts),
            size =len(verts) * size_of(MeshVert),
        }
    })

	index_count := cast(i32)p.indices.count
	unpacked_indices := make([]u16, index_count) // Or u32 if your models are large
	defer delete(unpacked_indices)

	for i in 0 ..< index_count {
		unpacked_indices[i] = cast(u16)cgltf.accessor_read_index(p.indices, cast(uint)i)
	}

	// load index buffer
	mesh.index_buffer = sg.make_buffer({
		usage = { index_buffer = true, immutable = true },
		data = {
            ptr = raw_data(unpacked_indices),
            size = len(unpacked_indices) * size_of(u16)
        },
	})

	mesh.index_count = index_count

	return mesh
}
