@header package shaders
@header import sg "../sokol/gfx"

//////////////////////////
// Billboard Shader
//////////////////////////

//-----------------------//
// Vertex Shader
//-----------------------//
@vs vs
layout(binding=0) uniform billboard_params {
    mat4 view;
    mat4 proj;
    vec4 ambient_color;
};

// Per-vertex data (the shared quad)
in vec3 pos; // vec4??
in vec2 uv;
in vec3 inst_pos;
in float inst_scale;
in vec3 inst_color;
in float inst_layer;

out vec4 color;
out vec2 texcoord;
out float layer;

void main() {
  vec3 right = normalize(vec3(view[0][0], view[1][0], view[2][0]));
  vec3 up    = vec3(0, 1, 0);

  vec3 local = pos * inst_scale;

  // Calculate vertex position in world space
  vec3 world_pos = inst_pos +
    right * local.x +
    up    * local.y;

  gl_Position = proj * view * vec4(world_pos, 1.0);
  texcoord = uv;
  layer = inst_layer;
  color = vec4(inst_color, 1.0)  * ambient_color;
}
@end


//-----------------------//
// Fragment Shader
//-----------------------//
@fs fs
layout(binding=0) uniform texture2DArray bbtex;
layout(binding=0) uniform sampler bbsmp;

in vec4 color;
in vec2 texcoord;
in float layer;
out vec4 frag_color;

void main() {
  vec4 tex_color = texture(sampler2DArray(bbtex, bbsmp), vec3(-texcoord, layer));
  if (tex_color.a < 0.5) discard;
  frag_color = tex_color * color;
}
@end

@program billboard vs fs
