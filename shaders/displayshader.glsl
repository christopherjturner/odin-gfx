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
in vec2 uv;
out vec4 frag_color;

const mat4 bayerMatrix = mat4(
    0.0, 8.0, 2.0, 10.0,
    12.0, 4.0, 14.0, 6.0,
    3.0, 11.0, 1.0, 9.0,
    15.0, 7.0, 13.0, 5.0
) / 16.0;



vec3 quantizeBits(vec3 c, vec3 bits) {
    vec3 levels = pow(vec3(2.0), bits) - 1.0;
    return floor(c * levels) / levels;
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
  int x = int(mod(gl_FragCoord.x, 4.0));
  int y = int(mod(gl_FragCoord.y, 4.0));


  float threshold  = bayerMatrix[x][y];
  vec4 tcol        = texture(sampler2D(dtex, dsmp), uv2);
  float brightness = (tcol.r + tcol.g + tcol.b) / 3.0;
  float dithered   = brightness > threshold ? 1.0 : 0.5;

  vec4 final_color = tcol;
  //final_color = vec4(quantizeBits(final_color.rgb, vec3(5,6,5)), 1.0);
  //final_color = final_color * dithered;

  frag_color = final_color;
}

@end

//-----------------------------------------//

@program display vs fs
