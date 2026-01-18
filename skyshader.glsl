@header package main
@header import sg "./sokol/gfx"

//////////////////////////
// Sky Shader
//////////////////////////

//-----------------------//
// Vertex Shader
//-----------------------//
@vs vs
layout(binding=0) uniform sky_params {
  mat4 view;
  mat4 proj;
  float time_of_day;
  float game_time;
};

in vec3 pos;

out vec3 dir;
out float time;
out float t;

vec3 rotate_axis(vec3 v, vec3 axis, float a) {
  axis = normalize(axis);
  float s = sin(a);
  float c = cos(a);
  return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

void main() {

  float scale = 30.0;

  time = time_of_day;
  t = game_time;

  vec3 p = pos * scale;
  dir = normalize(p);

  float tilt = radians(23.4);
  vec3 pole = normalize(vec3(sin(tilt), cos(tilt), 0.0)); // tilted from +Y towards +X
  dir = rotate_axis(dir, pole, game_time * 0.01);

  mat4 v = view;
  v[3] = vec4(0.0, -1.0 * (scale*0.25), 0.0, 1.0);

  vec4 trans = vec4(pos * 100.0, 1.0);

  gl_Position = proj * v * vec4(p, 1.0);
}
@end

//-----------------------//
// Fragment Shader
//-----------------------//

@fs fs
in vec3 dir;
in float time;
in float t;
out vec4 frag_color;

float saturate(float x) { return clamp(x, 0.0, 1.0); }

vec3 get_horizon_color(float t) {
  float blend = (t - 0.5) / 0.25;
  return mix(vec3(0.7, 0.5, 0.3), vec3(0.8, 0.4, 0.2), blend);
}

vec3 get_zenith_color(float t) {
  float blend = (t - 0.5) / 0.25;
  return mix(vec3(0.3, 0.5, 0.8), vec3(0.2, 0.3, 0.6), blend);
}

// Simple hash for stars (cheap and stable)
float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 34.345);
  return fract(p.x * p.y);
}

void main() {
  float height = dir.y;
  vec3 horizon = get_horizon_color(time);
  vec3 zenith  = get_zenith_color(time);

  float blend = height * height;
  vec3 sky_color = mix(horizon, zenith, blend);

  float star_mask = pow(saturate(height), 4.0) * 1.0;


  float grid = 800.0;
  float threshold = 0.9985;
  vec2 star_p = dir.xz / max(0.001, (dir.y + 1.2)); // cheap "projection"
  float h = hash(floor(star_p * grid));
  float star = clamp((h - threshold) / (1.0 - threshold), 0.0, 1.0);
  star = pow(star, 10.0);
  sky_color += vec3(1.0) * star * star_mask;
  frag_color = vec4(sky_color.rgb, 1.0);
}

@end

@program sky vs fs
