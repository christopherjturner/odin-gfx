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
    mat4 view_proj;
    vec4 ambient_color;
};

// Per-vertex data (the shared quad)
in vec4 pos;
in vec2 uv;
in vec3 inst_pos;
in float inst_scale;

out vec4 color;
out vec2 texcoord;

void main() {
    // Get the camera's Right and Up vectors from the view matrix
    // This assumes a standard column-major view matrix
    vec3 camera_right = vec3(view_proj[0][0], view_proj[1][0], view_proj[2][0]);
    vec3 camera_up    = vec3(view_proj[0][1], view_proj[1][1], view_proj[2][1]);

    // Calculate vertex position in world space
    vec3 world_pos = inst_pos
        + camera_right * pos.x * inst_scale
        + camera_up    * pos.y * inst_scale;

    gl_Position = view_proj * vec4(world_pos, 1.0);
    texcoord = uv;
    color = ambient_color;
}
@end


//-----------------------//
// Fragment Shader
//-----------------------//
@fs fs
layout(binding=0) uniform texture2D bbtex;
layout(binding=0) uniform sampler bbsmp;

in vec4 color;
in vec2 texcoord;
out vec4 frag_color;

void main() {
  vec4 tex_color = texture(sampler2D(bbtex, bbsmp), -texcoord);
  if (tex_color.a < 0.5) discard;
  frag_color = tex_color * color;
}
@end

@program billboard vs fs
