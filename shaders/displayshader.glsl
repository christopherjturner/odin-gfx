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


  frag_color = texture(sampler2D(dtex, dsmp), uv2);
  //frag_color.rgb = quantizeBits(frag_color.rgb, vec3(7,7,7));

}

@end

//-----------------------------------------//

@program display vs fs
