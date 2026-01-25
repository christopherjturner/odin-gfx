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

vec3 rotate_axis(vec3 v, vec3 axis, float a) {
  axis = normalize(axis);
  float s = sin(a);
  float c = cos(a);
  return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

void main() {
  const float scale = 100.0;

  vec3 scaled_pos = pos * scale;
  dir = normalize(scaled_pos);

  // Apply Earth's axial tilt (23.4 degrees)
  const float tilt = radians(23.4);
  vec3 pole = normalize(vec3(sin(tilt), cos(tilt), 0.0));
  dir = rotate_axis(dir, pole, game_time * 0.001);

  // Lock view position to camera (skybox effect)
  mat4 v = view;
  v[3] = vec4(0.0, -scale * 0.5, 0.0, 1.0);

  gl_Position = proj * v * vec4(scaled_pos, 1.0);
}
@end

//-----------------------
// Fragment Shader
//-----------------------
@fs fs
in vec3 dir;
out vec4 frag_color;

layout(binding=1) uniform sky_fs_params {
  vec4 horizon_now;
  vec4 zenith_now;
  vec4 sun_color;
  vec3 sun_dir;
  vec3 view_dir;
  float game_time;
};

float saturate(float x) {
  return clamp(x, 0.0, 1.0);
}

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 34.345);
  return fract(p.x * p.y);
}

vec3 stars(vec3 dir, float threshold, float grid, float t) {
  float star_mask = pow(saturate(dir.y), 4.0);

  // Project onto dome
  vec2 star_p = dir.xz / max(0.001, dir.y + 1.2);

  float h = hash(floor(star_p * grid));
  float star = saturate((h - threshold) / (1.0 - threshold));
  star = pow(star, 10.0);

  // Twinkle effect
  float twinkle = 0.5 + 0.25 * sin((t * 5) * dir.x * dir.y);

  return vec3(star * star_mask * twinkle);
}

vec4 drawSun(vec4 sky_color) {

  float sun_height = max(sun_dir.y, 0.0);
  float expansion = 1.0 + (1.0 - sun_height) * (30 * sun_height); // Simple linear boost
  float base_radius = 0.9999;
  float dynamic_radius = 1.0 - ((1.0 - base_radius) * expansion);

  float sun_dot = dot(normalize(dir), sun_dir);
  float sun_mask = smoothstep(dynamic_radius, dynamic_radius + 0.0002, sun_dot);
  return mix(sky_color, sun_color * 1.2, sun_mask);
}

vec4 moon(vec4 sky_color) {
  float moon_dot = dot(normalize(dir), -sun_dir);
  float moon_mask = smoothstep(0.999, 0.9991, moon_dot);
  return mix(sky_color, vec4(0.75, 0.7, 0.711, 1.0), moon_mask);
}

void main() {
  // Gradient from horizon to zenith
  float blend = dir.y * dir.y;
  vec4 sky_color = mix(horizon_now, zenith_now, blend);

  // Add stars
  sky_color += vec4(stars(dir, 0.995, 800.0, game_time), 1.0);

  // Add sun
  sky_color = moon(drawSun(sky_color));

  frag_color = sky_color;
}
@end

@program sky vs fs

