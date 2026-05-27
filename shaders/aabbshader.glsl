@header package shaders
@header import sg "../sokol/gfx"

@vs aabb_vs

layout(binding=0) uniform aabb_vs_params {
    mat4 view_proj;
};


in vec3 pos;

in vec3 aabb_min;
in vec3 aabb_max;
in vec3 inst_pos;
in vec3 inst_scale;
in vec4 inst_rot;

out vec4 color;

mat4 composeMatrix(vec3 scale, vec4 q, vec3 pos) {
    // 1. Rotation Matrix from Quaternion
    float x2 = q.x + q.x; float y2 = q.y + q.y; float z2 = q.z + q.z;
    float xx = q.x * x2;   float xy = q.x * y2;   float xz = q.x * z2;
    float yy = q.y * y2;   float yz = q.y * z2;   float zz = q.z * z2;
    float wx = q.w * x2;   float wy = q.w * y2;   float wz = q.w * z2;

    mat4 m = mat4(1.0);
    m[0][0] = 1.0 - (yy + zz);
    m[0][1] = xy + wz;
    m[0][2] = xz - wy;

    m[1][0] = xy - wz;
    m[1][1] = 1.0 - (xx + zz);
    m[1][2] = yz + wx;

    m[2][0] = xz + wy;
    m[2][1] = yz - wx;
    m[2][2] = 1.0 - (xx + yy);

    // 2. Apply Scale to columns
    m[0].xyz *= scale.x;
    m[1].xyz *= scale.y;
    m[2].xyz *= scale.z;

    // 3. Apply Translation (Position)
    m[3].xyz = pos;

    return m;
}

void main() {
  mat4 model = composeMatrix(inst_scale, inst_rot, inst_pos);
  vec3 size = aabb_max - aabb_min;
  vec3 transformed_pos = aabb_min + (pos * size);
  gl_Position = view_proj * model * vec4(transformed_pos, 1.0);
  color = vec4(1.0, 0.0, 0.0, 1.0);
}

@end

@fs aabb_fs
in vec4 color;
out vec4 frag_color;

void main() {
    frag_color = color;
}
@end

@program aabb aabb_vs aabb_fs
