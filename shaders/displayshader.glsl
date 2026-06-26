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
  vec4 fog_color;
  float fog_start;
  float fog_end;
};

layout(binding=0) uniform texture2D dtex;
layout(binding=0) uniform sampler dsmp;

layout(binding=1) uniform texture2D depthTex;
layout(binding=1) uniform sampler depthSmp;

in vec2 uv;
out vec4 frag_color;

const float near = 0.1;
const float far  = 1000.0;

const vec3  quant = vec3(6.0, 7.0, 6.0);
const vec3  qstep = 1.0 / quant;


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


float bayer4x4v2(vec2 p) {
    int x = int(mod(p.x, 4.0));
    int y = int(mod(p.y, 4.0));

    if (y == 0) {
        if (x == 0) return  0.0 / 16.0 - 0.5;
        if (x == 1) return  8.0 / 16.0 - 0.5;
        if (x == 2) return  2.0 / 16.0 - 0.5;
        return            10.0 / 16.0 - 0.5;
    }
    if (y == 1) {
        if (x == 0) return 12.0 / 16.0 - 0.5;
        if (x == 1) return  4.0 / 16.0 - 0.5;
        if (x == 2) return 14.0 / 16.0 - 0.5;
        return             6.0 / 16.0 - 0.5;
    }
    if (y == 2) {
        if (x == 0) return  3.0 / 16.0 - 0.5;
        if (x == 1) return 11.0 / 16.0 - 0.5;
        if (x == 2) return  1.0 / 16.0 - 0.5;
        return             9.0 / 16.0 - 0.5;
    }

    if (x == 0) return 15.0 / 16.0 - 0.5;
    if (x == 1) return  7.0 / 16.0 - 0.5;
    if (x == 2) return 13.0 / 16.0 - 0.5;
    return             5.0 / 16.0 - 0.5;
}


float linearize_depth(float z) {
  return (2.0 * near * far) / (far + near - (z * 2.0 - 1.0) * (far - near));
}


vec3 quantize666(vec3 c, vec2 fragXY) {
    float d = bayer4x4v2(floor(fragXY));
    vec3 stepSize = vec3(1.0 / 5.0);   // 6 levels per channel

    c += d * stepSize * 0.75;
    c = clamp(c, 0.0, 1.0);

    c.r = floor(c.r * 5.0) / 5.0;
    c.g = floor(c.g * 5.0) / 5.0;
    c.b = floor(c.b * 5.0) / 5.0;
    return c;
}

vec3 quantAndDither(vec3 color, vec2 srcPixel) {
  // dither
  float d = bayer4x4v2(srcPixel);
  float strength = 1.0 / 64.0;
  color += d * qstep * 0.5;

  // quantise
  color = clamp(color, 0.0, 1.0);
  color = floor(color * quant) / quant;
  return color;

}

float rgbToLum(vec3 color) {
  return dot(color, vec3(0.299, 0.587, 0.114));
}

void main() {

  vec2 srcSize = vec2(640.0, 480.0);
  vec2 dstSize = resolution;

  vec2 srcPixel = floor(gl_FragCoord.xy * srcSize / dstSize);
  vec2 srcUV = (srcPixel + 0.5) / srcSize;

  vec3 original = texture(sampler2D(dtex, dsmp), srcUV).rgb;

  vec2 uv2 = uv;

  // Pixel perfect scaling
  // Disable to get a blury CRT style.
  /* srcUV = gl_FragCoord.xy * inv_resolution;
  vec2 tex_size = vec2(textureSize(sampler2D(dtex, dsmp), 0));
  srcUV = (floor(srcUV * tex_size) + 0.5) / tex_size;
  */
  // depth buffer
  float depth = texture(sampler2D(depthTex, depthSmp), srcUV).r;

  vec3 color = original;

  // Fog
  if (depth < 0.9999999) {
    float dist = linearize_depth(depth);
    float fog_factor = clamp( (dist - fog_start) / (fog_end - fog_start ), 0.0, 0.7);
    color = mix(color, fog_color.rgb, fog_factor * 0);
  }

  // Colour pop
  //float luma = dot(color, vec3(0.299, 0.587, 0.114));
  //color = mix(vec3(luma), color, 1.115);
  //color = clamp(color, 0.0, 1.0);


  // looks very VGA, a bit too much?
  //color = quantize666(color, gl_FragCoord.xy);
  //color = quantize666(color, srcPixel.xy);


  //color = quantAndDither(color, srcPixel.xy);
  // Final Color
  frag_color = vec4(color, 1.0);

}

@end

//-----------------------------------------//

@program display vs fs
