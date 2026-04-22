@header package shaders
@header import sg "../sokol/gfx"

//////////////////////////
// Sky Shader
//////////////////////////

//-----------------------
// Vertex Shader
//-----------------------
@vs vs

layout(binding=0) uniform sky_vs_params {
  mat4 view;
  mat4 proj;
  float game_time;
  vec3 _pad;
};

in vec3 pos;
out vec3 dir;
out vec3 v_pos;

vec3 rotate_axis(vec3 v, vec3 axis, float a) {
  axis = normalize(axis);
  float s = sin(a);
  float c = cos(a);
  return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

void main() {
  v_pos = pos;
  const float scale = 1000.0;

  vec3 scaled_pos = pos * scale;
  dir = normalize(scaled_pos);

  // Apply Earth's axial tilt (23.4 degrees)
  const float tilt = radians(0);

  vec3 pole = normalize(vec3(sin(tilt), cos(tilt), 0.0));
  //dir = rotate_axis(dir, pole, game_time * 0.001);

  // Lock view position to camera (skybox effect)
  mat4 v = view;
  v[3] = vec4(0.0, 0.0, 0.0, 1.0);

  gl_Position = proj * v * vec4(scaled_pos, 1.0);
}
@end

//-----------------------
// Fragment Shader
//-----------------------
@fs fs
in vec3 dir;
in vec3 v_pos;
out vec4 frag_color;

layout(binding=0) uniform texture2D sky_tex;
layout(binding=0) uniform sampler sky_smp;


layout(binding=1) uniform sky_fs_params {
  vec4 horizon_now;
  vec4 zenith_now;
  vec4 sun_color;
  vec3 sun_dir;
  vec3 view_dir;
  float game_time;
  float time_of_day;
};

float saturate(float x) {
  return clamp(x, 0.0, 1.0);
}


vec2 sky_uv(vec3 dir, float scale, vec2 scroll) {
  vec2 uv = dir.xz / (dir.y + 0.01);
  return uv * scale + scroll;
}


vec4 sample_cloud_layer(vec3 dir, float scale, vec2 speed) {
    vec2 scroll = game_time * speed;
    vec2 uv     = sky_uv(dir, scale, scroll);
    return texture(sampler2D(sky_tex, sky_smp), uv);
}


vec3 apply_clouds(vec3 sky_color, vec3 dir) {
    float fade = clamp(dir.y * 0.5, 0.0, 1.0);

    // Upper layer — opaque base, slower, larger scale
    vec4 upper = sample_cloud_layer(dir, 0.7 * fade, vec2(0.008, 0.002));

    // Lower layer — transparent wisps, faster, tighter scale
    vec4 lower = sample_cloud_layer(dir, 0.9, vec2(0.020, 0.06));

    // Threshold both into cloud masks
    //float upper_mask = smoothstep(0.25, 0.85, upper.r) * fade;
    float upper_mask = smoothstep(0.65, 0.85, upper.r) * fade;
    float lower_mask = smoothstep(0.10, 0.65, lower.r) * fade * 0.6;

    // Cloud colour — white lit top, grey shadowed base
    // Tint warm near the sun for sunrise/sunset
    float sun_angle  = clamp(dot(dir, sun_dir), 0.0, 1.0);

    vec3 cloud_light  = mix(horizon_now.rgb, sun_color.rgb, 0.7);
    vec3 cloud_shadow = mix(horizon_now.rgb * 0.4, sun_color.rgb, 0.4);

    vec3 cloud_color = mix(cloud_shadow, cloud_light, upper_mask);

    // Composite: upper first (opaque-ish), lower on top (transparent wisps)
    sky_color = mix(sky_color, cloud_color, upper_mask * 0.95) ;
    //sky_color = mix(sky_color, cloud_light, lower_mask * 0.65);

    return sky_color;
}

void main() {
  // Gradient from horizon to zenith
  //float blend = dir.y * dir.y;
  float blend = dir.y;
  vec4 sky_color = mix(horizon_now, zenith_now, blend);

  vec3 clouds = apply_clouds(sky_color.rgb, dir);

  sky_color.rgb = clouds;

  /*
  vec2 uv = dir.xz /  (dir.y +0.01);
  float horizon_fade = clamp(dir.y + 5.0, 0.0, 1.0);

  float clouds = cloud_density(uv, game_time) * horizon_fade;

  vec3 cloud_color = mix(vec3(0.85, 0.88, 0.95),
                         vec3(1.0, 1.0, 1.0),
                         clouds);

  float sun_influence = max(0.0, dot(dir, sun_dir));
  cloud_color = mix(cloud_color, sun_color.rgb, sun_influence * 0.4 * (1.0 - game_time));

  // Add stars
  //sky_color += vec4(stars(v_pos, 0.15, 1000.0, game_time) * 0.5, 1.0);

  // Add sun
  //sky_color = moon(drawSun(sky_color));
  //sky_color.rgb = mix(sky_color.rgb, cloud_color, clouds * 0.9);
  */

  frag_color = sky_color;
}
@end

@program sky vs fs

