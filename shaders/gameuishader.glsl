@header package shaders
@header import sg "../sokol/gfx"

@vs vs
layout(binding=0) uniform game_ui_vs_params {
    vec2 screen_size;
};

in vec2 pos;
in vec2 uv0;
in vec4 color0;

out vec2 uv;
out vec4 color;

void main() {
    vec2 p = pos / screen_size;
    p = p * 2.0 - 1.0;
    p.y = -p.y;

    gl_Position = vec4(p, 0.0, 1.0);
    uv = uv0;
    color = color0;
}
@end

@fs fs
//uniform texture2D tex;
//uniform sampler smp;

in vec2 uv;
in vec4 color;

out vec4 frag_color;

void main() {
  //vec4 texel = texture(sampler2D(tex, smp), uv);
  frag_color = color;
}
@end

@program game_ui vs fs
