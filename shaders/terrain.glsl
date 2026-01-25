@header package shaders
@header import sg "../sokol/gfx"

//-----------------------
// Vertex Shader
//-----------------------
@vs terrain_vs

layout(binding=0) uniform terrain_vs_params {
    mat4 view_proj;
    vec4 ambient_color;
    vec4 sun_color;
    vec3 chunk_pos;
    vec3 scale;
    int  u_grid_width;
};

in float height;
in vec3 normal;
in vec3 color;

out vec4 f_col;
out vec4 f_ambient;
out vec3 v_world_pos;
out vec3 v_normal;

void main() {

  // 1. Force integer math for the grid position
  int x_int = gl_VertexIndex % int(u_grid_width);
  int z_int = gl_VertexIndex / int(u_grid_width);

  // 2. Convert to float ONLY after the grid position is locked
  vec3 local_pos = vec3(float(x_int), height, float(z_int));
  vec3 world_pos = (local_pos * scale) + chunk_pos;

  f_ambient   = ambient_color;
  v_world_pos = world_pos;
  v_normal    = normal;

  // 2. Lighting Math (The Gouraud Part)
  // We do this here instead of the fragment shader
  vec3 u_sun_dir = normalize(vec3(0.5, 1.0, 0.3));

  float diff = max(dot(normalize(v_normal), u_sun_dir), 0.0);
  vec3 lighting = f_ambient.rgb + (sun_color.rgb * diff);

  f_col = vec4(color * lighting, 1.0);

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
in vec3 v_normal;

out vec4 frag_color;

void main() {
  // TODO: use textures etc
  frag_color = f_col;
}

@end

@program terrain terrain_vs terrain_fs

/**
// Pixel shader version of lighting
void main() {

  vec3 normal = normalize(v_normal);

  // 2. Simple Directional Light (Sun)
  vec3 sun_dir = normalize(vec3(0.5, 1.0, 0.3));
  float diff   = max(dot(normal, sun_dir), 0.0);

  // 3. Final Color (Green terrain)
  vec3 ambient = f_ambient.rgb; //vec3(0.1, 0.15, 0.1);
  vec3 terrain_color = f_col.rgb;

  // TODO: pass sun and direction in as a
  frag_color = vec4(terrain_color * (diff + ambient), 1.0);
}
*/
