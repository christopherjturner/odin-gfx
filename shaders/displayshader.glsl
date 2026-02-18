@header package shaders
@header import sg "../sokol/gfx"

/////////////////////////////////////////////////
// Display Shader
/////////////////////////////////////////////////

@vs vs
out vec2 uv;

void main() {
    // Generate a triangle that covers the screen
    // Vertices: (-1, -1), (3, -1), (-1, 3)
    float x = -1.0 + float((gl_VertexIndex & 1) << 2);
    float y = -1.0 + float((gl_VertexIndex & 2) << 1);
    uv.x = (x + 1.0) * 0.5;
    uv.y = (y + 1.0) * 0.5;
    gl_Position = vec4(x, y, 0.0, 1.0);
}

@end

//-----------------------------------------//
// Fragment Shader
@fs fs


layout(binding=0) uniform display_fs_params {
  vec2 resolution;
  vec2 inv_resolution;
  float enable;
};

layout(binding=0) uniform texture2D dtex;
layout(binding=0) uniform sampler dsmp;

layout(binding=1) uniform texture2D depthTex;
layout(binding=1) uniform sampler depthSmp;

in vec2 uv;
out vec4 frag_color;

const mat4 bayerMatrix = mat4(
    0.0, 8.0, 2.0, 10.0,
    12.0, 4.0, 14.0, 6.0,
    3.0, 11.0, 1.0, 9.0,
    15.0, 7.0, 13.0, 5.0
) / 16.0;

float bayer4x4(vec2 p) {
    int x = int(mod(p.x, 4.0));
    int y = int(mod(p.y, 4.0));
    int index = x + y * 4;

    float dither[16] = float[](
         0.0,  8.0,  2.0, 10.0,
        12.0,  4.0, 14.0,  6.0,
         3.0, 11.0,  1.0,  9.0,
        15.0,  7.0, 13.0,  5.0
    );

    return dither[index] / 16.0 - 0.5;
}


const float near = 0.1;
const float far =  1000.0;
const float fog_start = 200.0;
const float fog_end = 450.0;

vec3 quantizeBits(vec3 c, vec3 bits) {
    vec3 levels = pow(vec3(2.0), bits) - 1.0;
    return floor(c * levels) / levels;
}

float linearize_depth(float z) {
  return (2.0 * near * far) / (far + near - (z * 2.0 - 1.0) * (far - near));
}

void main() {

  vec2 uv2 = uv;

  if(enable > 0.0) {
    uv2 = uv;
  } else {
    uv2 = gl_FragCoord.xy * inv_resolution;
    vec2 tex_size = vec2(textureSize(sampler2D(dtex, dsmp), 0));
    uv2 = (floor(uv2 * tex_size) + 0.5) / tex_size;
  }



  // dithering, looks kinda janky
  vec2 srcSize = vec2(640.0, 480.0);      // original resolution
  vec2 dstSize = resolution;              // screen resolution

  vec2 srcUV    = floor(gl_FragCoord.xy * srcSize / dstSize) / srcSize;
  vec2 srcPixel = floor(srcUV * resolution);
  float d       = bayer4x4(srcPixel);

  vec3 color = texture(sampler2D(dtex, dsmp), uv2).rgb;

  // depth fog
  float depth = texture(sampler2D(depthTex, depthSmp), uv2).r;
  float dist = linearize_depth(depth);
  vec4 fog_color = vec4(0.5, 0.5, 0.5, 1.0);
  float fog_factor = clamp( (dist - fog_start) / (fog_end - fog_start ), 0.0, 1.0);
  color = mix(color, fog_color.rgb, fog_factor);

  // strength depends on bit depth
  float strength = 1.0 / 64.0;
  color += d * strength;

  // quantise
  color.r = floor(color.r * 31.0) / 31.0;
  color.g = floor(color.g * 63.0) / 63.0;
  color.b = floor(color.b * 31.0) / 31.0;

  // Final Color
  frag_color = vec4(color, 1.0);

}

@end

//-----------------------------------------//

@program display vs fs
