@header package main
@header import sg "./sokol/gfx"

@vs vs_grid
layout(binding=0) uniform grid_vs_params {
    mat4 mvp;
};

in vec3 pos;
in vec4 color0;

out vec4 color;

void main() {
    gl_Position = mvp * vec4(pos, 1.0);
    color = color0;
}
@end

@fs fs_grid
in vec4 color;
out vec4 frag_color;

void main() {
    frag_color = color;
}
@end

@program grid vs_grid fs_grid