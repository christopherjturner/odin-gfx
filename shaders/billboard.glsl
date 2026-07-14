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
    mat4 view;
    mat4 proj;
    vec4 u_ambient_color;
    vec4 u_sun_color;
    vec4 u_fog_color;
    vec3 u_sun_dir;
    float u_fog_start;
    vec3 u_camera_pos;
    float u_fog_end;
    int cylindrical;
};

// Per-vertex data (the shared quad)
in vec3 pos;
in vec2 uv;

// Instance data
in vec3 inst_pos;
in float inst_scale;
in vec3 inst_color;
in float inst_layer;

out vec4 v_color;
out vec2 texcoord;
out float layer;
out vec3 v_fog_color;
out float v_fog;


void main() {

    vec2 vertex_offset = pos.xy * inst_scale;
    vec4 view_pos = view * vec4(inst_pos, 1.0);

    // Billboarding

    vec3 billboard_right = vec3(1.0, 0.0, 0.0);
    vec3 billboard_up    = vec3(0.0, 1.0, 0.0);

    if (cylindrical == 1) {
        // Transform the world-up vector (0, 1, 0) into view space
        vec3 world_up_view = (view * vec4(0.0, 1.0, 0.0, 0.0)).xyz;

        // Normalize to prevent scaling issues, with a safe fallback
        // in case the camera is looking directly straight down.
        float len = length(world_up_view);
        billboard_up = (len > 0.001) ? (world_up_view / len) : vec3(0.0, 1.0, 0.0);
    }

    // Extrude the vertex along our calculated billboard axes
    view_pos.xyz += billboard_right * vertex_offset.x + billboard_up * vertex_offset.y;

    vec3 normal = normalize(cross(billboard_right, billboard_up));

    // Light
    float diff    = max(dot(normal, u_sun_dir), 0.0);
    vec3 lighting = u_ambient_color.rgb + (diff * u_sun_color.rgb);



    // Fog
    float dist  = distance(view_pos.xyz, u_camera_pos);
    v_fog       = clamp((u_fog_end - dist) / (u_fog_end - u_fog_start), 0.0, 1.0);
    v_fog_color = u_fog_color.rgb;

    gl_Position = proj * view_pos;
    v_color       = vec4(lighting, 1.0);
    texcoord    = uv;
    layer       = inst_layer;
}
@end


//-----------------------//
// Fragment Shader
//-----------------------//
@fs fs
layout(binding=0) uniform texture2DArray bbtex;
layout(binding=0) uniform sampler bbsmp;

in vec4 v_color;
in vec2 texcoord;
in float layer;
in vec3  v_fog_color;
in float v_fog;

out vec4 frag_color;

void main() {
  vec4 tex_color = texture(sampler2DArray(bbtex, bbsmp), vec3(-texcoord, layer));
  if (tex_color.a < 0.5) discard;
  frag_color = tex_color * v_color;
  frag_color.rgb = mix(frag_color.rgb, v_fog_color, 1.0-v_fog).rgb;
}
@end

@program billboard vs fs
