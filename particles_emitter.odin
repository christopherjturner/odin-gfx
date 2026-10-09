package main

import "./shaders"
import sg "./sokol/gfx"
import "core:fmt"
import "core:math/ease"
import "core:math/linalg/glsl"
import "core:math/rand"

MAX_PARTICLES :: 1024 * 10

Particle_GPU :: struct {
	// GPU side params
	pos:         glsl.vec3,
	scale:       f32,
	color:       glsl.vec4,
	atlas_index: f32,
}

Particle_CPU :: struct {
	// CPU-side params
	ttl:       f32,
	updated:   f32,
	vel:       glsl.vec3,
	emitter:   int,
	end_color: glsl.vec4,
	end_scale: f32,
}

Particle_Pool :: struct {
	gpu_data:     []Particle_GPU,
	cpu_data:     []Particle_CPU,
	active_count: int,
}

Particle_Emitter :: struct {
	// working data
	active:           bool,
	emit_accumulator: f32,

	// stats
	emit_count:       int,
	active_time_ms:   f32,

	// emit rate
	rate:             f32,
	burst:            int,
	duration:         f32,
	loop:             bool,

	// start/end state
	origin:           glsl.vec3,
	gravity:          glsl.vec3,
	dir:              glsl.vec3,
	base_ttl:         f32,
	speed:            f32,
	drag:             f32,
	start_color:      glsl.vec4,
	end_color:        glsl.vec4,
	start_scale:      f32,
	end_scale:        f32,
	texture_id:       int,
}

Particle_System :: struct {
	bind:      sg.Bindings,
	pip:       sg.Pipeline,
	emitters:  []Particle_Emitter,
	particles: Particle_Pool,
}

init_particle_system :: proc() -> ^Particle_System {

	ps := new(Particle_System)
	images := get_array_texture(&state.textures, "./assets/textures/array")
	ps.bind.views[shaders.VIEW_cpuparticletex] = sg.make_view(
		{texture = {image = images, slices = {base = 0, count = 0}}},
	)

	ps.bind.samplers[shaders.SMP_cpuparticlesmp] = sg.make_sampler({})

	particle_instance_buffer_desc := sg.Buffer_Desc {
		size = MAX_PARTICLES * size_of(Particle_GPU),
		usage = {vertex_buffer = true, stream_update = true},
		label = "particle-instance-buffer",
	}

	ps.bind.vertex_buffers[0] = sg.make_buffer(particle_instance_buffer_desc)

	ps.pip = sg.make_pipeline(
		{
			shader = sg.make_shader(shaders.cpu_particles_shader_desc(sg.query_backend())),
			cull_mode = .NONE,
			index_type = .NONE,
			layout = {
				buffers = {0 = {stride = size_of(Particle_GPU), step_func = .PER_INSTANCE}},
				attrs = {
					shaders.ATTR_cpu_particles_inst_pos = {
						buffer_index = 0,
						offset = i32(offset_of(Particle_GPU, pos)),
						format = .FLOAT3,
					},
					shaders.ATTR_cpu_particles_inst_scale = {
						buffer_index = 0,
						offset = i32(offset_of(Particle_GPU, scale)),
						format = .FLOAT,
					},
					shaders.ATTR_cpu_particles_inst_color = {
						buffer_index = 0,
						offset = i32(offset_of(Particle_GPU, color)),
						format = .FLOAT4,
					},
					shaders.ATTR_cpu_particles_inst_layer = {
						buffer_index = 0,
						offset = i32(offset_of(Particle_GPU, atlas_index)),
						format = .FLOAT,
					},
				},
			},
			depth = {write_enabled = false, compare = .LESS_EQUAL},
			colors = {
				0 = {
					blend = {
						enabled = true,
						src_factor_rgb = .SRC_ALPHA,
						dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
					},
				},
			},
		},
	)

	ps.particles.gpu_data = make([]Particle_GPU, MAX_PARTICLES)
	ps.particles.cpu_data = make([]Particle_CPU, MAX_PARTICLES)
	ps.emitters = make([]Particle_Emitter, 1)
	ps.emitters[0] = Particle_Emitter {
		active      = true,
		rate        = 10,
		duration    = 0,
		loop        = false,
		burst       = 0,
		origin      = {10.0, 5.0, 10.0},
		dir         = {1, 1, 1}, //rand_vec3_direction_rejection(),
		speed       = 20.0,
		base_ttl    = 3.0,
		start_scale = 0.1,
		end_scale   = 2.0,
		start_color = glsl.vec4{0.2, 0.01, 0, 0.1},
		end_color   = glsl.vec4{1.0, 1.0, 1.0, 1.0},
	}

	return ps
}

update_particle_system :: proc(ps: ^Particle_System, dt: f32) {
	for &emitter, emitter_id in ps.emitters {
		if !emitter.active do continue

		if emitter.duration > 0 && emitter.active_time_ms > emitter.duration {
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

		for i in 0 ..< particles_to_emit {

			EMITTER_MIN :: -5
			EMITTER_MAX :: 5
			pos :=
				emitter.origin +
				glsl.vec3 {
						rand.float32_range(EMITTER_MIN, EMITTER_MAX),
						rand.float32_range(EMITTER_MIN, EMITTER_MAX),
						rand.float32_range(EMITTER_MIN, EMITTER_MAX),
					}

			dir := rand_direction_in_cone(emitter.dir, 180 * 0.017453292519943)
			dir = {0, 1, 0}
			spawn(
				&ps.particles,
				Particle_GPU {
					pos = pos,
					color = emitter.start_color,
					scale = emitter.start_scale,
					atlas_index = f32(emitter.texture_id),
				},
				Particle_CPU {
					vel = (dir * emitter.speed) * dt,
					ttl = emitter.base_ttl,
					emitter = emitter_id,
					end_color = emitter.end_color,
					end_scale = emitter.end_scale,
				},
			)
			emitter.emit_accumulator -= 1
		}

		emitter.emit_count += particles_to_emit
		emitter.active_time_ms += dt
	}

	for i := 0; i < ps.particles.active_count; {
		gpu := &ps.particles.gpu_data[i]
		cpu := &ps.particles.cpu_data[i]
		seed := i64(888)
		cpu.ttl -= dt
		if (cpu.ttl > 0) {
			emitter := ps.emitters[cpu.emitter]
			progress := (emitter.base_ttl - cpu.ttl) / emitter.base_ttl


			//forward := glsl.normalize(cpu.vel)
			//curl := curl_noise_3d(seed, gpu.pos * 1.2)
			//steering := curl - forward * glsl.dot(curl, forward)
			cpu.vel += emitter.gravity * dt
			cpu.vel += (emitter.dir * emitter.speed) * dt
			cpu.vel *= glsl.pow(emitter.drag, cpu.vel)
			//physics.vel = curl

			//gpu.pos += glsl.normalize(cpu.vel) * emitter.speed * dt
			gpu.pos += cpu.vel
			gpu.scale = glsl.lerp(emitter.start_scale, cpu.end_scale, ease.bounce_in(progress))
			gpu.color = glsl.lerp(emitter.start_color, cpu.end_color, progress)

			// move on to next particle
			i += 1
		} else {
			evict(&ps.particles, i)
		}
	}
}

draw_particle_system :: proc(ps: ^Particle_System, cam: Camera, dt: f32) {
	update_particle_system(ps, dt)

	total_active := ps.particles.active_count
	if total_active == 0 do return

	instance_data := make([]Particle_GPU, total_active, context.temp_allocator)

	count := ps.particles.active_count
	src := ps.particles.gpu_data[:count]
	dst := instance_data[0:count]
	copy(dst, src)

	sg.update_buffer(
		ps.bind.vertex_buffers[0],
		{ptr = raw_data(instance_data), size = uint(total_active * size_of(Particle_GPU))},
	)

	vs_uniforms := shaders.Cpu_Particle_Params {
		view = transmute([16]f32)cam.view,
		proj = transmute([16]f32)cam.proj,
	}

	sg.apply_pipeline(ps.pip)
	sg.apply_bindings(ps.bind)
	sg.apply_uniforms(
		shaders.UB_cpu_particle_params,
		{ptr = &vs_uniforms, size = size_of(vs_uniforms)},
	)

	sg.draw(0, 3, total_active)
}

spawn :: proc(pool: ^Particle_Pool, particle: Particle_GPU, physics: Particle_CPU) {
	if pool.active_count >= MAX_PARTICLES do return

	free_idx := pool.active_count
	pool.gpu_data[free_idx] = particle
	pool.cpu_data[free_idx] = physics
	pool.active_count += 1
}

evict :: proc(pool: ^Particle_Pool, idx: int) {
	if idx < 0 || idx >= pool.active_count do return
	pool.active_count -= 1
	pool.gpu_data[idx] = pool.gpu_data[pool.active_count]
	pool.cpu_data[idx] = pool.cpu_data[pool.active_count]
}
