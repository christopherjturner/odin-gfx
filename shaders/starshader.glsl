@header package shaders
@header import sg "../sokol/gfx"

//////////////////////////
// Star billboard shader
//////////////////////////

//-----------------------//
// Vertex Shader
//-----------------------//
@vs vs
layout(binding=0) uniform star_params {
    mat4 view;
    mat4 proj;
};

// Per-vertex data (the shared quad)
in vec4 pos;
in vec2 uv;
in vec3 inst_pos;
in float inst_scale;
in vec4 inst_color;
in float inst_layer;

out vec4 color;
out vec2 texcoord;
out float layer;

void main() {
  // zero position
  mat4 v = view;
  v[3] = vec4(0.0, 0.0, 0.0, 1.0);

  // Get the camera's Right and Up vectors from the view matrix
  // This assumes a standard column-major view matrix
  vec3 camera_right = vec3(v[0][0], v[1][0], v[2][0]);
  vec3 camera_up    = vec3(v[0][1], v[1][1], v[2][1]);

  float sky_distance = 500.0;

  // Calculate vertex position in world space
  vec3 world_pos = (inst_pos * sky_distance)
        + camera_right * pos.x * inst_scale
        + camera_up    * pos.y * inst_scale;


    gl_Position   = proj * v * vec4(world_pos, 1.0);
    //gl_Position.z = gl_Position.w;
    texcoord = uv;
    layer    = inst_layer;
    color    = inst_color;
}
@end


//-----------------------//
// Fragment Shader
//-----------------------//
@fs fs
layout(binding=0) uniform texture2DArray startex;
layout(binding=0) uniform sampler starsmp;

in vec4 color;
in vec2 texcoord;
in float layer;

out vec4 frag_color;

void main() {
  vec4 tex_color = texture(sampler2DArray(startex, starsmp), vec3(texcoord, layer));
  frag_color = tex_color * color;
}
@end

@program stars vs fs
