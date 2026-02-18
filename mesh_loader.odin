package main

import "vendor:cgltf"
import "core:fmt"

import sg "./sokol/gfx"


MeshVert :: struct {
    pos: [3]f32,
    uv:  [2]f32,
    normal: [3]f32,
}

load_mesh :: proc(filename: cstring) -> (sg.Buffer, sg.Buffer, i32) {
    options: cgltf.options

    data, result := cgltf.parse_file(options, filename)
    if result != .success {
        panic("failed to load model")
    }

    defer cgltf.free(data)

    res := cgltf.load_buffers(options, data, filename)
    if res != .success {
        panic("failed to load buffers")
    }

    // load vert data
    p := data.meshes[0].primitives[0]
    count := cast(int)p.attributes[0].data.count
    verts := make([]MeshVert, count)
    defer delete(verts)

    for i in 0..<count {
        v := &verts[i]

        for a in p.attributes {

            #partial switch a.type {
            case .position:
                ok := cgltf.accessor_read_float(a.data, cast(uint)i, &v.pos[0], 3)
                if !ok {
                    panic("failed to read verts")
                }
            case .texcoord:
                ok := cgltf.accessor_read_float(a.data, cast(uint)i, &v.uv[0], 2)
                if !ok {
                    panic("failed to read verts")
                }
            case .normal:
                ok := cgltf.accessor_read_float(a.data, cast(uint)i, &v.normal[0], 3)
                if !ok {
                    panic("failed to read verts")
                }
            case: // ignore
            }
        }
    }

    vbuf := sg.make_buffer({
        usage = { vertex_buffer = true },
        data = {
            ptr = raw_data(verts),
            size = len(verts) * size_of(MeshVert),
        },
    })

    fmt.printf("\n%d index data: %v\n", cast(i32)p.indices.count, p.indices.buffer_view.buffer.data)

    index_count := cast(i32)p.indices.count
    unpacked_indices := make([]u16, index_count) // Or u32 if your models are large
    defer delete(unpacked_indices)

    for i in 0..<index_count {
        unpacked_indices[i] = cast(u16)cgltf.accessor_read_index(p.indices, cast(uint)i)
    }

    // load index buffer
    ibuf := sg.make_buffer({
        usage = { index_buffer = true },
        data  = {
            ptr  = raw_data(unpacked_indices),
            size = len(unpacked_indices) * size_of(u16),
        },
    })

    return vbuf, ibuf, cast(i32)p.indices.count
}
