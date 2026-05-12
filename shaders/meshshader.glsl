@header package shaders
@header import sg "../sokol/gfx"

@vs vs

const int MAX_JOINTS = 64;

layout(binding = 0) uniform mesh_vs_params {
    mat4 view_proj;
    mat4 model;
    vec4 ambient_color;
    vec4 sun_color;
    vec3 u_sun_dir;
    mat4 u_joints[MAX_JOINTS];
};

layout(location = 0) in vec3 position;
layout(location = 1) in vec2 texcoord0;
layout(location = 2) in vec3 normal;
layout(location = 3) in uvec4 joints;
layout(location = 4) in vec4 weights;

out vec2 v_uv;
out vec3 v_normal;
out vec4 v_col;

void main() {
  mat4 skin =
        weights.x * u_joints[joints.x] +
        weights.y * u_joints[joints.y] +
        weights.z * u_joints[joints.z] +
        weights.w * u_joints[joints.w];

  vec4 local_pos = skin * vec4(position, 1.0);
  vec4 world_pos = model * local_pos;
  gl_Position = view_proj * world_pos;

  // Transform normal to world space (simple version)
  v_normal = mat3(model) * normal;

  v_uv = vec2(texcoord0.x, texcoord0.y);

  // Light
  float diff = max(dot(normalize(v_normal), u_sun_dir), 0.0);
  vec3 lighting = ambient_color.rgb + (diff * sun_color.rgb);
  v_col = vec4(lighting, 1.0);
}

@end

@fs fs
in vec2 v_uv;
in vec3 v_normal;
in vec4 v_col;

layout(binding = 0) uniform texture2D mesh_tex;
layout(binding = 0) uniform sampler mesh_smp;

out vec4 frag_color;

void main() {
    vec4 tex_color = texture(sampler2D(mesh_tex, mesh_smp), v_uv);
    frag_color = tex_color * v_col;
}
@end

@program meshshader vs fs
