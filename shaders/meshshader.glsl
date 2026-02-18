@header package shaders
@header import sg "../sokol/gfx"

@vs vs
layout (location = 0) in vec3 position;
layout (location = 1) in vec2 texcoord0;
layout (location = 2) in vec3 normal;

layout(binding=0) uniform mesh_vs_params {
    mat4 mvp;      // Model-View-Projection Matrix
    mat4 model;    // Model matrix for world-space normals
};

out vec2 uv;
out vec3 frag_normal;

void main() {
    gl_Position = mvp * vec4(position, 1.0);
    uv = vec2(texcoord0.x, texcoord0.y);
    // Transform normal to world space (simple version)
    frag_normal = mat3(model) * normal;
}

@end

@fs fs
in vec2 uv;
in vec3 frag_normal;

layout(binding=0) uniform texture2D mesh_tex;
layout(binding=0) uniform sampler mesh_smp;

out vec4 frag_color;

void main() {
    // Basic Directional Lighting
    vec3 light_dir = normalize(vec3(0.5, 1.0, 0.3));
    vec3 n = normalize(frag_normal);
    float dot_product = max(dot(n, light_dir), 0.1); // 0.1 for basic ambient light

    // Sample the texture and apply lighting
    // vec4 tex_color = vec4(uv, 0.0, 1.0);

    vec4 tex_color = texture(sampler2D(mesh_tex, mesh_smp), uv);

    frag_color = mix(vec4(uv.x, uv.y, 0.0, 1.0), vec4(tex_color.rgb, 1.0), 0.9);
}
@end

@program meshshader vs fs
