@header package shaders
@header import sg "../sokol/gfx"

//-----------------------
// Vertex Shader
//-----------------------
@vs terrain_vs

layout(binding=0) uniform terrain_vs_params {
    mat4 view_proj;
    vec4 ambient_color;
    vec3 chunk_pos;
    float scale;
    int width;
    int height;
};

in vec4 pos;
in vec4 color;

out vec4 f_col;
out vec4 f_ambient;
out vec3 v_world_pos;

void main() {
  vec3 world_pos = vec3(float(gl_VertexIndex % width ), pos.y, float(gl_VertexIndex / height));

  world_pos = (world_pos + chunk_pos) * scale;
  v_world_pos = world_pos;

  f_col = color;
  f_ambient = ambient_color;
  //f_col.r = clamp(pos.y / 0.3, 0.0, 1.0);

  gl_Position = view_proj * vec4(world_pos, 1.0);
}
@end

//----------------------
// Fragment Shader
//---------------------
@fs terrain_fs
in vec4 f_col;
in vec4 f_ambient;
in vec3 v_world_pos;

out vec4 frag_color;

void main() {

  // 1. Calculate the face normal dynamically
  // dFdx/y calculates the difference in world_pos between adjacent pixels
  vec3 dx = dFdx(v_world_pos);
  vec3 dy = dFdy(v_world_pos);
  vec3 normal = normalize(cross(dx, dy));

  // 2. Simple Directional Light (Sun)
  vec3 sun_dir = normalize(vec3(0.5, 1.0, 0.3));
  float diff = max(dot(normal, sun_dir), 0.0);

  // 3. Final Color (Green terrain)
  vec3 ambient = f_ambient.rgb; //vec3(0.1, 0.15, 0.1);
  vec3 terrain_color = vec3(1.0, 1.0, 1.0); //f_col.rgb;

  frag_color = vec4(terrain_color * (diff + ambient) * ambient, 1.0);


  // Standard lighting trick: calculate normals based on derivative of position

  //vec3 normal = normalize(cross(dFdx(v_world_pos), dFdy(v_world_pos)));
  //float light = max(dot(normal, normalize(vec3(0.5, 1.0, 0.2))), 0.0);
  //float light = max(dot(normal, normalize(f_ambient.rgb)), 0.0);

  //frag_color = vec4(f_col.rgb * (light + 0.2), 1.0); // light + ambient
}

@end

@program terrain terrain_vs terrain_fs
