## Airborne motes for Sector 08.
##
## The yard reads as a still photograph because nothing in it moves and nothing crosses the
## light. These are lit particles: a mote is bright inside the sodium pool, cyan under the spine,
## and close to invisible in shadow -- which is how dust behaves, being unnoticeable until it
## crosses a lamp.
##
## Getting that took a custom shader. A StandardMaterial3D with alpha blending gives a mote a
## constant grey wash: it *adds* brightness over a dark wall and *subtracts* inside a bright beam,
## because it is darker than what it covers. Measured, that version contributed ten times more in
## shadow than in the sodium beam. See sector_08_air_motes.gdshader.
##
## Three emitters, three draw calls. The quads are far larger than real dust -- a physically sized
## mote is about 0.7 px at this distance, which additive blending cannot resolve at all -- so they
## are sized to read rather than to measure.
extends Node3D

## name -> { centre, extents, amount, size, colour, drift, lifetime }
const FIELDS := {
	"YardDrift": {
		"centre": Vector3(0.0, 3.0, -4.0), "extents": Vector3(26.0, 5.0, 18.0),
		"amount": 220, "size": 0.075, "colour": Color(0.78, 0.85, 0.95),
		"drift": Vector3(0.35, 0.05, 0.0), "lifetime": 14.0,
	},
	# Sited on the maintenance floodlight's beam, which runs from (-3.65, 4.6, -22) down to about
	# (2.35, 0.3, -10). It used to sit at the front of the yard, nowhere near any cone, so the
	# densest field of motes was in the one place no lamp could pick it out.
	"SodiumMotes": {
		"centre": Vector3(-0.6, 2.4, -15.5), "extents": Vector3(7.0, 3.0, 7.5),
		"amount": 120, "size": 0.085, "colour": Color(0.95, 0.88, 0.78),
		"drift": Vector3(0.16, 0.09, 0.04), "lifetime": 11.0,
	},
	# On the cyan shaft itself, which descends from (-19, 19.6, -13) to about (-6, -1.5, 2). The
	# spine had no dust sited on it, so the district's landmark light had nothing to pick out.
	"SpineHalo": {
		"centre": Vector3(-12.0, 7.5, -5.0), "extents": Vector3(4.5, 8.5, 5.0),
		"amount": 150, "size": 0.095, "colour": Color(0.84, 0.92, 0.98),
		"drift": Vector3(0.05, 0.22, 0.03), "lifetime": 16.0,
	},
	# In front of the facade screen, whose spill sits at (18.7, 16.9, 24.8) with a 17 m reach.
	# Magenta is a hue nothing else in the yard carries, so it is worth having motes in it.
	"FacadeHaze": {
		# Sited tight on the spill rather than spread across the whole board: its reach is only
		# 17 m and it attenuates fast, so a wide box put most motes where nothing lights them.
		"centre": Vector3(18.5, 15.0, 24.0), "extents": Vector3(6.5, 5.0, 4.0),
		"amount": 130, "size": 0.100, "colour": Color(0.90, 0.86, 0.96),
		"drift": Vector3(-0.14, 0.06, 0.0), "lifetime": 15.0,
	},
	# Rising thermals off the spine plant, which is the one part of the scene that is "running".
	"SpineAsh": {
		"centre": Vector3(-16.0, 5.0, -13.0), "extents": Vector3(11.0, 8.0, 9.0),
		"amount": 140, "size": 0.095, "colour": Color(0.80, 0.90, 0.96),
		"drift": Vector3(0.10, 0.55, 0.05), "lifetime": 13.0,
	},
}

## The scattering knobs live HERE, not in the shader. sector_08_air_motes.gdshader declares
## defaults for these uniforms, but this dictionary is applied on top at setup, so editing the
## shader alone changes nothing. This is the one place to tune them.
##
##   gain              overall brightness of a mote that is inside a light
##   anisotropy        Henyey-Greenstein asymmetry; higher throws scattering forward
##   ambient_response  how much sun/moon register, as opposed to lamps
##   floor_visibility  how visible a mote is with no light on it at all
const SCATTERING := {
	"gain": 2.6,
	"anisotropy": 0.22,
	"ambient_response": 0.028,
	"floor_visibility": 0.012,
}

var emitters: Array[GPUParticles3D] = []
var _material: ShaderMaterial


func setup() -> void:
	# One shared material across all three emitters: per-particle colour comes from the process
	# material's colour ramp, so no extra material instances are needed.
	_material = ShaderMaterial.new()
	_material.shader = preload("res://scenes/environment/sector_08/runtime/sector_08_air_motes.gdshader")
	_material.resource_name = "CS_air_motes"
	for key: String in SCATTERING:
		_material.set_shader_parameter(key, SCATTERING[key])

	for id: String in FIELDS:
		_field(id, FIELDS[id])


func _field(id: String, config: Dictionary) -> void:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = config["extents"]
	process.direction = (config["drift"] as Vector3).normalized()
	process.spread = 32.0
	process.initial_velocity_min = 0.05
	process.initial_velocity_max = 0.22
	process.gravity = Vector3(0.0, -0.012, 0.0)
	process.damping_min = 0.02
	process.damping_max = 0.10
	process.scale_min = 0.55
	process.scale_max = 1.45
	# Turbulence is what stops the field reading as parallel drifting dots.
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.22
	process.turbulence_noise_scale = 1.8
	process.turbulence_influence_min = 0.05
	process.turbulence_influence_max = 0.35

	var ramp := Gradient.new()
	var tint: Color = config["colour"]
	ramp.set_color(0, Color(tint.r, tint.g, tint.b, 0.0))
	ramp.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	ramp.add_point(0.25, Color(tint.r, tint.g, tint.b, 1.0))
	ramp.add_point(0.72, Color(tint.r, tint.g, tint.b, 1.0))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture

	var quad := QuadMesh.new()
	quad.size = Vector2(config["size"], config["size"])

	var emitter := GPUParticles3D.new()
	emitter.name = id
	emitter.amount = int(config["amount"])
	emitter.lifetime = float(config["lifetime"])
	emitter.preprocess = float(config["lifetime"])
	emitter.randomness = 0.6
	emitter.fixed_fps = 30
	emitter.interpolate = true
	emitter.process_material = process
	emitter.draw_pass_1 = quad
	emitter.material_override = _material
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The emission box is the field, so cull against it rather than the tiny default AABB.
	emitter.visibility_aabb = AABB(-(config["extents"] as Vector3), (config["extents"] as Vector3) * 2.0)
	add_child(emitter)
	emitter.position = config["centre"]
	emitters.append(emitter)


## Motes are airborne dust held up by convection; when the district loses power the extractors
## stop and the air settles, so the field thins with the same supply curve everything else uses.
func sync_power(supply: float) -> void:
	for i in emitters.size():
		var config: Dictionary = FIELDS[str(emitters[i].name)]
		emitters[i].amount_ratio = clampf(0.35 + 0.65 * supply, 0.0, 1.0)


## Godot holds the generated particle shader alive through the process material, and a headless
## run that calls quit() with emitters still live reports it as an unfreed RID at exit. Dropping
## the references on the way out keeps validation output clean.
func _exit_tree() -> void:
	for emitter: GPUParticles3D in emitters:
		emitter.emitting = false
		emitter.process_material = null
		emitter.draw_pass_1 = null
		emitter.material_override = null
	emitters.clear()


func get_report() -> Dictionary:
	var total: int = 0
	for emitter: GPUParticles3D in emitters:
		total += emitter.amount
	return {
		"emitters": emitters.size(),
		"total_particles": total,
		"lit": true,
		"scattering": "henyey-greenstein",
		"blend": "additive",
		"shared_materials": 1,
	}
