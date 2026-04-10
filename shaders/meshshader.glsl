@header package shaders
@header import sg "../sokol/gfx"

@vs vs
layout (location = 0) in vec3 position;
layout (location = 1) in vec2 texcoord0;
layout (location = 2) in vec3 normal;

layout(binding=0) uniform mesh_vs_params {
    mat4 mvp;      // Model-View-Projection Matrix
    mat4 model;    // Model matrix for world-space normals
    vec4 ambient_color;
    vec4 sun_color;
    vec3 u_sun_dir;
};

out vec2 v_uv;
out vec3 v_normal;
out vec4 v_col;

void main() {
    gl_Position = mvp * vec4(position, 1.0);
    v_uv = vec2(texcoord0.x, texcoord0.y);

    // Transform normal to world space (simple version)
    v_normal = mat3(model) * normal;

    float diff        = max(dot(normalize(v_normal), u_sun_dir), 0.0);
    vec3 lighting     = ambient_color.rgb + (diff * sun_color.rgb);
    v_col = vec4(lighting, 1.0);
}

@end

@fs fs
in vec2 v_uv;
in vec3 v_normal;
in vec4 v_col;

layout(binding=0) uniform texture2D mesh_tex;
layout(binding=0) uniform sampler mesh_smp;

out vec4 frag_color;

void main() {
    vec4 tex_color = texture(sampler2D(mesh_tex, mesh_smp), v_uv);

    frag_color = tex_color * v_col;;
}
@end

@program meshshader vs fs
