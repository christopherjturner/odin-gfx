@header package shaders
@header import sg "../sokol/gfx"

///////////////////////////////////
// Dithered Shader
///////////////////////////////////

// VERTEX SHADER
@vs vs
layout(binding=0) uniform vs_params {
    mat4 mvp;
};

in vec4 pos;
in vec4 color0;
in vec2 texcoord0;

out vec4 color;
out vec2 uv;

void main() {
     gl_Position = mvp * pos;
     color = color0;
     uv = texcoord0 * 5.0;
}
@end


// FRAGMENT SHADER
@fs fs
layout(binding=0) uniform texture2D tex;
layout(binding=0) uniform sampler smp;

const mat4 bayerMatrix = mat4(
    0.0, 8.0, 2.0, 10.0,
    12.0, 4.0, 14.0, 6.0,
    3.0, 11.0, 1.0, 9.0,
    15.0, 7.0, 13.0, 5.0
) / 16.0;

in vec4 color;
in vec2 uv;
out vec4 frag_color;

vec4 quantize24(vec4 c) {
  return vec4(floor(c.rgb * 255.0) / 255.0, 1.0);
}

vec3 quantizeBits(vec3 c, vec3 bits) {
    vec3 levels = pow(vec3(2.0), bits) - 1.0;
    return floor(c * levels) / levels;
}

void main() {
    int x = int(mod(gl_FragCoord.x, 4.0));
    int y = int(mod(gl_FragCoord.y, 4.0));
    float threshold = bayerMatrix[x][y];

    vec4 tcol = texture(sampler2D(tex, smp), uv);
    //tcol.rgb = quantizeBits(tcol.rgb, vec3(3,3,7));
    // Apply dither to the brightness
    float brightness = (tcol.r + tcol.g + tcol.b) / 3.0;
    float dithered = brightness > threshold ? 1.0 : 0.5;

    frag_color = tcol; // * dithered;
}




@end

@program texcube vs fs
