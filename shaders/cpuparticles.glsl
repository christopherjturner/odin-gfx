@header package shaders
@header import sg "../sokol/gfx"


@vs cpu_particle_vs

const vec2 QUAD_POS[3] = vec2[](
                                vec2(-1.0, -1.0),
                                vec2 (3.0, -1.0),
                                vec2(-1.0,  3.0)
);

const vec2 QUAD_UV[3] = vec2[](
                                vec2(0.0, 0.0),
                                vec2(2.0, 0.0),
                                vec2(0.0, 2.0)
);

layout(binding=0) uniform cpu_particle_params {
    mat4 view;
    mat4 proj;
};

in vec3 inst_pos;
in float inst_scale;
in vec4  inst_color;
in float inst_layer;

out vec4 color;
out vec2 texcoord;
out float layer;

void main() {
    vec2 vertex_offset = QUAD_POS[gl_VertexIndex] * inst_scale;
    vec4 view_pos      = view * vec4(inst_pos, 1.0);
    view_pos.xy        += vertex_offset;

    gl_Position = proj * view_pos;
    color       = inst_color;
    texcoord    = QUAD_UV[gl_VertexIndex];
    layer       = inst_layer;
}

@end

@fs cpu_particle_fs
layout(binding=0) uniform texture2DArray cpuparticletex;
layout(binding=0) uniform sampler cpuparticlesmp;

in vec4 color;
in vec2 texcoord;
in float layer;
out vec4 frag_color;

void main() {
  if (texcoord.x > 1 || texcoord.y > 1) discard;
  vec4 tex_color = color * texture(sampler2DArray(cpuparticletex, cpuparticlesmp), vec3(texcoord, layer));
  if (tex_color.a < 0.01) discard;

  frag_color = tex_color;
}

@end

@program cpu_particles cpu_particle_vs cpu_particle_fs
