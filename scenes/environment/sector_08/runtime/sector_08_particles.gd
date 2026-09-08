## Airborne motes for Sector 08.
##
## The yard reads as a still photograph because nothing in it moves and nothing crosses the
## light. These are lit particles, not an additive overlay: the quads are shaded, so a mote is
## bright inside the sodium pool, cyan under the spine, and nearly invisible in shadow. That is
## what ties them to the lighting instead of laying a uniform sparkle over the frame.
##
## Three emitters, three draw calls. Counts are deliberately small: at P30 a mote is roughly one
## pixel, so density reads long before count does.
extends Node3D

## name -> { centre, extents, amount, size, colour, drift, lifetime }
const FIELDS := {
	"YardDrift": {
		"centre": Vector3(0.0, 3.0, -4.0), "extents": Vector3(26.0, 5.0, 18.0),
		"amount": 320, "size": 0.030, "colour": Color(0.78, 0.85, 0.95),
		"drift": Vector3(0.35, 0.05, 0.0), "lifetime": 14.0,
	},
	# Denser and slower where the warm shaft lands, so the beam has something to pick out.
	"SodiumMotes": {
		"centre": Vector3(2.0, 2.6, 3.0), "extents": Vector3(9.0, 3.4, 9.0),
		"amount": 220, "size": 0.034, "colour": Color(0.95, 0.88, 0.78),
		"drift": Vector3(0.16, 0.09, 0.04), "lifetime": 11.0,
	},
	# Rising thermals off the spine plant, which is the one part of the scene that is "running".
	"SpineAsh": {
		"centre": Vector3(-16.0, 5.0, -13.0), "extents": Vector3(11.0, 8.0, 9.0),
		"amount": 180, "size": 0.040, "colour": Color(0.80, 0.90, 0.96),
		"drift": Vector3(0.10, 0.55, 0.05), "lifetime": 13.0,
	},
}

var emitters: Array[GPUParticles3D] = []
var _material: StandardMaterial3D


func setup() -> void:
	# One shared material across all three emitters: per-particle colour comes from the process
	# material's colour ramp, so no extra material instances are needed.
	_material = StandardMaterial3D.new()
	_material.resource_name = "CS_air_motes"
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_material.vertex_color_use_as_albedo = true
	_material.albedo_color = Color(1.0, 1.0, 1.0, 0.55)
	_material.roughness = 0.9
	_material.metallic = 0.0
	# Motes are dust, not lamps: they must be lit by the scene, never emit into it.
	_material.disable_receive_shadows = false
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.no_depth_test = false

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
		"lit": _material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL,
		"emissive": _material.emission_enabled,
		"shared_materials": 1,
	}
