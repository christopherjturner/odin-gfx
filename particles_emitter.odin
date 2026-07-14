package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"
import sg "./sokol/gfx"
import "./shaders"

MAX_PARTICLES :: 1024 * 10

Particle :: struct {
	// GPU side params
	pos:         glsl.vec3,
	scale:       f32,
	color:       glsl.vec4,
	atlas_index: f32,
}

Particle_Physics :: struct {
	// CPU-side params
	vel:         glsl.vec3,
	ttl:         f32,
}

Particle_Pool :: struct {
	visual_data:  []Particle,
	physics_data: []Particle_Physics,
	active_count: int,
}

spawn :: proc(pool: ^Particle_Pool, particle: Particle, physics: Particle_Physics) {
	if pool.active_count >= MAX_PARTICLES do return

	free_idx := pool.active_count
	pool.visual_data[free_idx] = particle
	pool.physics_data[free_idx] = physics
	pool.active_count += 1
}

evict :: proc(pool: ^Particle_Pool, idx: int) {
	if idx < 0 || idx >= pool.active_count do return
	pool.active_count -= 1
	pool.visual_data[idx] = pool.visual_data[pool.active_count]
	pool.physics_data[idx] = pool.physics_data[pool.active_count]
}

Particle_Emitter :: struct {
	// working data
	active:    bool,
	emit_accumulator: f32,

	// stats
	emit_count: int,
	active_time_ms: f32,

	// emit rate
	rate:      f32,
	burst:     int,
	duration:  f32,
	loop:      bool,

	origin:    glsl.vec3,
	gravity:   glsl.vec3,
	dir:       glsl.vec3,
	speed:     f32,
	base_ttl:  f32,
}

Particle_System :: struct {
	bind:              sg.Bindings,
	pip:               sg.Pipeline,
	emitters:          []Particle_Emitter,
	particles:         Particle_Pool,
}

init_particle_system :: proc() -> ^Particle_System {

	ps := new(Particle_System)

 	images := load_array_texture({
        "./assets/textures/array/1star.png",
        "./assets/textures/array/2star.png",
        "./assets/textures/array/3star.png",
    })

  ps.bind.views[shaders.VIEW_cpuparticletex] = sg.make_view({
      texture = {
          image  = images,
          slices = { base = 0, count = 0 },
      }
  	})

  ps.bind.samplers[shaders.SMP_cpuparticlesmp] = sg.make_sampler({})

  particle_instance_buffer_desc := sg.Buffer_Desc{
      size = MAX_PARTICLES * size_of(Particle),
      usage = {
          vertex_buffer = true,
          stream_update = true,
      },
      label = "particle-instance-buffer",
  }

  ps.bind.vertex_buffers[0] = sg.make_buffer(particle_instance_buffer_desc)

  ps.pip = sg.make_pipeline({
  	shader = sg.make_shader(shaders.cpu_particles_shader_desc(sg.query_backend())),
	cull_mode = .NONE,
	index_type = .NONE,
   	layout = {
    	buffers = {
     		0 = { stride = size_of(Particle), step_func = .PER_INSTANCE },
     	},
      attrs = {
          shaders.ATTR_cpu_particles_inst_pos   = { buffer_index = 0, offset = i32(offset_of(Particle, pos)), format = .FLOAT3 },
          shaders.ATTR_cpu_particles_inst_scale = { buffer_index = 0, offset = i32(offset_of(Particle, scale)), format = .FLOAT  },
          shaders.ATTR_cpu_particles_inst_color = { buffer_index = 0, offset = i32(offset_of(Particle, color)), format = .FLOAT4 },
          shaders.ATTR_cpu_particles_inst_layer = { buffer_index = 0, offset = i32(offset_of(Particle, atlas_index)), format = .FLOAT  },
      },
    },
    depth = {
        write_enabled = false,
        compare       = .LESS_EQUAL,
    },
	colors = {
		0 = {
			blend = {
				enabled = true,
				src_factor_rgb = .SRC_ALPHA,
	 			dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
			},
		},
	},
  })

  ps.particles.visual_data = make([]Particle, MAX_PARTICLES)
  ps.particles.physics_data = make([]Particle_Physics, MAX_PARTICLES)
  ps.emitters = make([]Particle_Emitter, 1)
  ps.emitters[0] = Particle_Emitter {
 	active   = true,
   	rate     = 0,
    duration = 3,
    loop     = true,
    burst    = 100,
    origin   = { -10.0, 0.0, 10.0 },
	dir      = rand_vec3_direction_rejection(),
	speed    = 5.0,
	base_ttl = 3.0,
 }

  return ps
}

update_particle_system :: proc(ps: ^Particle_System, dt: f32) {
	for &emitter in ps.emitters {
		if !emitter.active do continue

		if  emitter.duration > 0 && emitter.active_time_ms > emitter.duration {
			emitter.emit_accumulator = 0
			emitter.active_time_ms = 0
			emitter.emit_count = 0
			emitter.active = emitter.loop
		}

		emitter.emit_accumulator += emitter.rate * dt
		particles_to_emit := int(emitter.emit_accumulator)

		if emitter.active_time_ms == 0 && emitter.burst > 0 {
			particles_to_emit += emitter.burst
		}

		for i in 0..<particles_to_emit {

			pos := emitter.origin + glsl.vec3 {
				rand.float32_range(-5, 5),
				rand.float32_range(-5, 5),
				rand.float32_range(-5, 5),
			}

			dir := rand_direction_in_cone(emitter.dir, 45 *  0.017453292519943 )
			spawn(&ps.particles,
				Particle { pos = emitter.origin, color = { rand.float32_range(0, 1), rand.float32_range(0, 1), 0, 1}, scale = 0.5, atlas_index = 0, },
				Particle_Physics { vel = dir * emitter.speed, ttl = emitter.base_ttl, }
			)
			emitter.emit_accumulator -= 1
		}

		emitter.emit_count += particles_to_emit
		emitter.active_time_ms += dt
	}

	for i:=0; i<ps.particles.active_count; {
		vd := &ps.particles.visual_data[i]
		pd := &ps.particles.physics_data[i]

		pd.ttl -= dt
		if (pd.ttl > 0) {
			vd.pos += pd.vel * dt
			i+=1
		} else {
			evict(&ps.particles, i)
		}
	}
}

draw_particle_system :: proc(ps: ^Particle_System, cam: Camera, dt: f32) {
	update_particle_system(ps, dt)

	total_active := ps.particles.active_count
	if total_active == 0 do return

	instance_data := make([]Particle, total_active, context.temp_allocator)

	count := ps.particles.active_count
	src := ps.particles.visual_data[:count]
    dst := instance_data[0:count]
    copy(dst, src)

	sg.update_buffer(ps.bind.vertex_buffers[0], {
        ptr  = raw_data(instance_data),
        size = uint(total_active * size_of(Particle)),
    })

	vs_uniforms := shaders.Cpu_Particle_Params{
		view = transmute([16]f32)cam.view,
		proj = transmute([16]f32)cam.proj,
	}

	sg.apply_pipeline(ps.pip)
    sg.apply_bindings(ps.bind)
    sg.apply_uniforms(shaders.UB_cpu_particle_params, { ptr = &vs_uniforms, size = size_of(vs_uniforms) })

    sg.draw(0, 3, total_active)
}
