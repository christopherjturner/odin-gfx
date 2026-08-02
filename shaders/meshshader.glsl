@header package shaders
@header import sg "../sokol/gfx"

@vs vs

struct instanceData {
    mat4 skin;
};

layout(binding = 1, std430) readonly buffer TransformBuffer {
    instanceData instance[];
};

layout(binding = 0) uniform mesh_vs_params {
    mat4 view_proj;
    mat4 model;
    vec4 ambient_color;
    vec4 sun_color;
    vec3 u_sun_dir;
};

layout(location = 0) in vec3 position;
layout(location = 1) in vec2 texcoord0;
layout(location = 2) in vec3 normal;
layout(location = 3) in uvec4 joints;
layout(location = 4) in vec4 weights;

out vec2 v_uv;
out vec3 v_normal;
out vec4 v_col;
out vec3 v_fog_color;
out float v_fog;

void main() {
  mat4 skin =
        weights.x * instance[int(joints.x)].skin +
        weights.y * instance[joints.y].skin +
        weights.z * instance[joints.z].skin +
        weights.w * instance[joints.w].skin;

  vec4 local_pos = skin * vec4(position, 1.0);
  vec4 world_pos = model * local_pos;
  gl_Position = view_proj * world_pos;

  // Transform normal to world space (simple version)
  // TODO: apply the skin transform too
  v_normal = mat3(model) * mat3(skin) * normal;

  v_uv = vec2(texcoord0.x, texcoord0.y);

  // Light
  float diff = max(dot(normalize(v_normal), u_sun_dir), 0.0);
  vec3 lighting = ambient_color.rgb + (diff * sun_color.rgb);
  v_col = vec4(lighting, 1.0);

  v_fog_color = vec3(1.0, 1.0, 1.0);
  v_fog = 1.0;
}

@end

@vs static_vs

layout(binding = 0) uniform static_mesh_vs_params {
    mat4 view_proj;
    mat4 model;
    vec4 ambient_color;
    vec4 sun_color;
    vec4 u_fog_color;
    vec3 u_sun_dir;
    float u_fog_start;
    vec3 u_camera_pos;
    float u_fog_end;
};

layout(location = 0) in vec3 position;
layout(location = 1) in vec2 texcoord0;
layout(location = 2) in vec3 normal;

out vec2 v_uv;
out vec3 v_normal;
out vec4 v_col;
out vec3 v_fog_color;
out float v_fog;

void main() {

  vec4 local_pos = vec4(position, 1.0);
  vec4 world_pos = model * local_pos;
  gl_Position    = view_proj * world_pos;

  v_normal = mat3(model) * normal;
  v_uv     = vec2(texcoord0.x, texcoord0.y);

  // Light
  float diff    = max(dot(normalize(v_normal), u_sun_dir), 0.0);
  vec3 lighting = ambient_color.rgb + (diff * sun_color.rgb);
  v_col         = vec4(lighting, 1.0);

  // Fog
  float dist  = distance(world_pos.xyz, u_camera_pos);
  v_fog       = clamp((u_fog_end - dist) / (u_fog_end - u_fog_start), 0.0, 1.0);
  v_fog_color = u_fog_color.rgb;
}

@end

@fs fs
in vec2 v_uv;
in vec3 v_normal;
in vec4 v_col;
in vec3  v_fog_color;
in float v_fog;

layout(binding = 0) uniform texture2D mesh_tex;
layout(binding = 0) uniform sampler mesh_smp;

out vec4 frag_color;

void main() {
    vec4 tex_color = texture(sampler2D(mesh_tex, mesh_smp), v_uv);
    frag_color = tex_color * v_col;
    frag_color.rgb = mix(frag_color.rgb, v_fog_color, 1.0-v_fog).rgb;
}
@end

@program meshshader vs fs
@program staticmeshshader static_vs fs
