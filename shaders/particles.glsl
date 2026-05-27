@header package shaders
@header import sg "../sokol/gfx"


@vs particle_vs

const vec2 QUAD_POS[3] = vec2[](
                                vec2(-1.0, -1.0),
                                vec2(3.0, -1.0),
                                vec2(-1.0, 3.0)
);


vec3 hash(uint x) {
    x = ((x >> 16) ^ x) * 0x45d9f3bbu;
    x = ((x >> 16) ^ x) * 0x45d9f3bbu;
    x = ((x >> 16) ^ x);


    return vec3(float(x & 0x000FFF) / 4095.0,
                float((x >> 12) & 0x000FFF) / 4095.0,
                float((x >> 24) & 0x000FFF) / 4095.0);
}


layout(binding=0) uniform particle_vs_params {
  mat4 view;
  mat4 proj;

  vec3 origin;
  float t;

  // Movement
  vec3 velocity;
  float lifetime_max;
  vec3 velocity_variance;
  float lifetime_variance;
  vec3 gravity;
  float drag;

  // Rotation
  vec3 orbit_axis;
  float orbit_speed;

  // Wave
  vec3 wave_amplitude;
  float radial_acceleration;
  vec3 wave_frequence;

  // Display, color & texture
  float atlas_index;
  vec4 color_start;
  vec4 color_end;
  vec2 scale_change;
  float time_scale;

};

out vec4 col;

void main() {

  float seed = gl_InstanceIndex;
  vec3 rand1 = hash(uint(seed));
  vec3 rand2 = hash(uint(seed) + 123);

  float max_lifetime = 1.5 + (rand1.x * 2.0);
  float birth_offset = rand1.y * max_lifetime;

  float age = mod(t + birth_offset, max_lifetime);
  float normalized_age = age / max_lifetime; // 0.0 (birth) to 1.0 (death)

  vec2 vertex_offset = QUAD_POS[gl_VertexIndex];

  vec3 random_spread = (rand2 - vec3(0.5)) * velocity_variance;
  vec3 initial_velocity = velocity + random_spread;

  float drag_factor = (drag > 0.0) ? (1.0 - exp(-drag * age)) / drag : age;
  vec3 world_pos = origin + (initial_velocity * drag_factor) + (0.5 * gravity * age * age);

  vec4 view_pos = view * vec4(world_pos, 1.0);
  view_pos.xy += vertex_offset;
  gl_Position = proj * view_pos;

  col.r = mix(color_start.r, color_end.r, normalized_age);
  col.g = mix(color_start.g, color_end.g, normalized_age);
  col.b = mix(color_start.b, color_end.b, normalized_age);
  col.a = mix(color_start.a, color_end.a, normalized_age);
}

@end


@fs particle_fs

const float BayerMatrix[16] = float[](
     0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
    12.0 / 16.0,  4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
     3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
    15.0 / 16.0,  7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
);

in vec4 col;
out vec4 frag_color;

void main() {
  ivec2 pixelCoord = ivec2(gl_FragCoord.xy);
  int x = pixelCoord.x % 4;
  int y = pixelCoord.y % 4;
  int index = x + y * 4;

  float threshold = BayerMatrix[index];


  if (col.a < threshold) {
    discard;
  }

  frag_color = col;
}

@end

@program particles particle_vs particle_fs
