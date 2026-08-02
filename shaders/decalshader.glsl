@header package shaders
@header import sg "../sokol/gfx"


@vs decal_vs

layout(binding=0) uniform decal_vs_params {
    mat4 u_view_proj;
    mat4 u_model;
};

in vec3 pos;

void main() {
  gl_Position = u_view_proj * u_model * vec4(pos - 0.5, 1.0);
}

@end

@fs decal_fs
out vec4 frag_color;

layout(binding=1) uniform decal_fs_params {
    mat4 u_inv_view_proj;
    mat4 u_world_to_decal;
    vec2 u_screen_size;
};

layout(binding=0) uniform texture2D u_decal_tex;
layout(binding=0) uniform sampler u_decal_smp;

layout(binding=1) uniform texture2D u_decal_depth_tex;
layout(binding=1) uniform sampler u_decal_depth_smp;


void main() {
    vec2 screen_uv = gl_FragCoord.xy / u_screen_size;
    float depth = texture(sampler2D(u_decal_depth_tex, u_decal_depth_smp), screen_uv).r;

    //vec4 clip_space = vec4(screen_uv * 2.0 - 1.0, depth, 1.0); // use this for dx11/metal
    vec4 clip_space = vec4(screen_uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 world_pos = u_inv_view_proj * clip_space;
    world_pos /= world_pos.w;
    vec3 local_pos = (u_world_to_decal * world_pos).xyz;

    if (abs(local_pos.x) > 0.5 || abs(local_pos.y) > 0.5 || abs(local_pos.z) > 0.5) {
        discard;
    }

    vec2 decal_uv = local_pos.xz + 0.5;
    decal_uv.y = 1.0 - decal_uv.y;
    frag_color = texture(sampler2D(u_decal_tex, u_decal_smp), decal_uv);
}
@end

@program decal decal_vs decal_fs
