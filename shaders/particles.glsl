@header package shaders
@header import sg "../sokol/gfx"


@vs particle_vs

const vec2 QUAD_POS[3] = vec2[](
                                vec2(-1.0, -1.0),
                                vec2 (3.0, -1.0),
                                vec2(-1.0,  3.0)
);

const vec2 QUAD_UV[3] = vec2[](
                                vec2(0.0, 0.0),
                                vec2(2.0, 0.0),
                                vec2(0.0, 2.0)
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
  vec3 wave_frequency;

  // Display, color & texture
  float atlas_index;
  vec4 color_start;
  vec4 color_end;
  vec2 scale_change;
  float time_scale;

  float orbit_radius;
};

out vec4 col;
out vec2 uv;
out float atlas;

void main() {

  float seed = gl_InstanceIndex;
  vec3 rand1 = hash(uint(seed));
  vec3 rand2 = hash(uint(seed) ^ 0x9E3779B9u);

  float max_lifetime = lifetime_max + (rand1.x * 2.0);
  float birth_offset = rand1.y * lifetime_variance;

  float age = mod(t + birth_offset, max_lifetime);
  float normalized_age = age / max_lifetime; // 0.0 (birth) to 1.0 (death)

  vec2 vertex_offset = QUAD_POS[gl_VertexIndex];
  vertex_offset *= mix(scale_change.x, scale_change.y, normalized_age);

  // Movement
  vec3 random_spread = (rand2 * 0.5) * velocity_variance;
  vec3 initial_velocity = velocity + random_spread;
  float drag_factor = (drag > 0.0) ? (1.0 - exp(-drag * age)) / drag : age;
  vec3 world_pos = origin + (initial_velocity * drag_factor) + (0.5 * gravity * age * age);

  // Orbit
  float angle = age * orbit_speed + (seed * 0.5);
  float radius = orbit_radius + (radial_acceleration * age); // Added an initial radius

  // Assuming XZ plane orbit based on your original logic
  vec3 orbit_offset = vec3(cos(angle) * radius, 0.0, sin(angle) * radius);
  world_pos += orbit_offset * step(0.001, orbit_speed + radial_acceleration);

  // Wave
  vec3 wave_offset = sin(age * wave_frequency + (seed * 12.34)) * wave_amplitude;
  world_pos = world_pos + wave_offset;

  vec4 view_pos = view * vec4(world_pos, 1.0);
  view_pos.xy += vertex_offset;

  // Outputs
  gl_Position = proj * view_pos;
  uv = QUAD_UV[gl_VertexIndex];
  atlas = atlas_index;

  col = mix(color_start, color_end, normalized_age);
}

@end


@fs particle_fs
layout(binding=0) uniform texture2DArray particletex;
layout(binding=0) uniform sampler particlesmp;

in vec4 col;
in vec2 uv;
in float atlas;
out vec4 frag_color;

const float BayerMatrix4x4[16] = float[](
     0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
    12.0 / 16.0,  4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
     3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
    15.0 / 16.0,  7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
);

const float BayerMatrix[64] = float[](
     0.0/64.0, 48.0/64.0, 12.0/64.0, 60.0/64.0,  3.0/64.0, 51.0/64.0, 15.0/64.0, 63.0/64.0,
    32.0/64.0, 16.0/64.0, 44.0/64.0, 28.0/64.0, 35.0/64.0, 19.0/64.0, 47.0/64.0, 31.0/64.0,
     8.0/64.0, 56.0/64.0,  4.0/64.0, 52.0/64.0, 11.0/64.0, 59.0/64.0,  7.0/64.0, 55.0/64.0,
    40.0/64.0, 24.0/64.0, 48.0/64.0, 20.0/64.0, 43.0/64.0, 27.0/64.0, 51.0/64.0, 23.0/64.0,
     2.0/64.0, 50.0/64.0, 14.0/64.0, 62.0/64.0,  1.0/64.0, 49.0/64.0, 13.0/64.0, 61.0/64.0,
    34.0/64.0, 18.0/64.0, 46.0/64.0, 30.0/64.0, 33.0/64.0, 17.0/64.0, 45.0/64.0, 29.0/64.0,
    10.0/64.0, 58.0/64.0,  6.0/64.0, 54.0/64.0,  9.0/64.0, 57.0/64.0,  5.0/64.0, 53.0/64.0,
    42.0/64.0, 26.0/64.0, 50.0/64.0, 22.0/64.0, 41.0/64.0, 25.0/64.0, 49.0/64.0, 21.0/64.0
);


void main() {
  ivec2 pixelCoord = ivec2(gl_FragCoord.xy);
  int x = pixelCoord.x % 8;
  int y = pixelCoord.y % 8;
  int index = x + y * 8;

  float threshold = BayerMatrix[index];

  vec4 tex_color = col * texture(sampler2DArray(particletex, particlesmp), vec3(uv, atlas));

  //frag_color = tex_color; 

  if (uv.x > 1 || uv.y > 1) discard;
  //  if (tex_color.a < threshold) discard;

  frag_color = tex_color;
}

@end

@program particles particle_vs particle_fs
