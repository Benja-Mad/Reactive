## Optical atmosphere in depth, for the diorama framing.
##
## The arena already had one particle system: sector_08_particles.gd, shaded motes that are lit
## by the sodium pool and the spine and go dark in shadow. That gives the air substance but it
## all sits at roughly one depth, so a camera that translates does not read it as depth.
##
## These layers do the other half. They are placed at fixed distances in front of the approved
## framing -- 14 m, 37 m and 64 m, against a scene focused around 88 m -- and anchored in the
## world, never parented to or moved with the camera. So when the rig dollies to follow the
## player, the near motes sweep across the frame several times faster than the pavement does, and
## the shot gains depth from the geometry rather than from a scrolling overlay.
##
## They are part of the scene, not an overlay on it: depth tested, so anything in front occludes
## them, and fog affected, so distance drains them like everything else. They skip depth writing
## only, as any transparent sprite does.
##
## Measured over a 12 m dolly: near motes 2516 px, mid 884 px, far 511 px, gameplay plane 370 px.
##
## Cost is three emitters, three draw calls, one shader, no lights and no shadow casters.
extends Node3D

## The depths, extents and quad sizes below are stated at the reference framing distance and
## scaled with the level's own, so a framing composed from nearer or further keeps these layers at
## the same *screen* depths. Stated in absolute metres they would collapse onto the gameplay plane
## the moment the camera dollied in.
const REFERENCE_DISTANCE := 85.8

## depth     : metres in front of the approved camera, at the reference distance.
## extents   : half-size of the emission box, wide enough to keep the frame fed as it dollies.
## size      : quad edge in metres. Near motes are large because they are wildly out of focus.
## softness  : how far outside the depth of field the layer sits. 0 is a crisp speck at focus
##             distance, 1 is the wide diffuse smudge a mote 14 m from the lens actually becomes.
## variation : how far each mote may stray from that look. Deliberately small -- a field that
##             varies wildly reads as noise rather than as dust.
## churn     : turbulence strength. Enough to break parallel rails, not enough to look agitated.
const LAYERS := [
	{
		# 14 m against a focus of ~88 m: the circle of confusion is enormous, so these are large
		# and almost featureless. Few of them, drifting slowly, is the whole point.
		"id": "LensMotes", "depth": 14.0, "extents": Vector3(17.0, 7.0, 7.0),
		"count": 22, "size": 0.66, "opacity": 0.05, "lifetime": 62.0,
		"drift": Vector3(-0.085, 0.03, 0.008), "softness": 1.0, "variation": 0.30,
		"churn": 0.035, "tint": Color(0.78, 0.83, 0.95), "warm": Color(1.0, 0.74, 0.48),
	},
	{
		"id": "ForegroundDrift", "depth": 37.0, "extents": Vector3(24.0, 11.0, 10.0),
		"count": 52, "size": 0.155, "opacity": 0.135, "lifetime": 74.0,
		"drift": Vector3(-0.065, 0.025, 0.006), "softness": 0.52, "variation": 0.25,
		"churn": 0.05, "tint": Color(0.72, 0.80, 0.92), "warm": Color(1.0, 0.78, 0.55),
	},
	{
		"id": "MiddleDust", "depth": 64.0, "extents": Vector3(30.0, 16.0, 11.0),
		"count": 90, "size": 0.062, "opacity": 0.26, "lifetime": 86.0,
		"drift": Vector3(-0.04, 0.014, 0.0), "softness": 0.12, "variation": 0.22,
		"churn": 0.06, "tint": Color(0.70, 0.79, 0.90), "warm": Color(0.98, 0.82, 0.62),
	},
]

var layers: Array[GPUParticles3D] = []
var materials: Array[ShaderMaterial] = []


var _scale: float = 1.0


func setup(arena: Node) -> void:
	var framing: Transform3D = arena.approved_transform
	_scale = float(arena.framing_distance) / REFERENCE_DISTANCE
	for config: Dictionary in LAYERS:
		_layer(config, framing)
	arena.controller.reactive_state_changed.connect(_sync)
	_sync(arena.controller.get_values())


func _layer(config: Dictionary, framing: Transform3D) -> void:
	var extents: Vector3 = (config["extents"] as Vector3) * _scale
	var drift: Vector3 = config["drift"]
	var depth: float = float(config["depth"]) * _scale

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	process.direction = (framing.basis * drift).normalized()
	process.initial_velocity_min = drift.length() * 0.85
	process.initial_velocity_max = drift.length() * 1.15
	# Narrow spread and a small velocity band: these are meant to hang in the air and slide, not
	# to fly. A wide spread with strong turbulence read as agitated rather than as atmosphere.
	process.spread = 9.0
	process.gravity = Vector3.ZERO
	process.scale_min = 0.72
	process.scale_max = 1.3
	# Just enough turbulence to break parallel rails, on a long wavelength so the wander is slow.
	process.turbulence_enabled = true
	process.turbulence_noise_strength = float(config["churn"])
	process.turbulence_noise_scale = 0.7
	process.turbulence_influence_min = 0.05
	process.turbulence_influence_max = 0.22
	process.damping_min = 0.0
	process.damping_max = 0.02
	# Orientation is randomised once; the residual spin is slow enough to never read as tumbling.
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -0.5
	process.angular_velocity_max = 0.5

	# Fade in and out over the life, so nothing ever pops at the edge of the box.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.16, Color.WHITE)
	gradient.add_point(0.80, Color.WHITE)
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp

	var material := ShaderMaterial.new()
	material.shader = preload("res://scenes/environment/sector_08/runtime/sector_08_cinematic_dust.gdshader")
	material.resource_name = "CS_optical_%s" % config["id"]
	material.set_shader_parameter("opacity", float(config["opacity"]))
	material.set_shader_parameter("tint", Vector3(config["tint"].r, config["tint"].g, config["tint"].b))
	material.set_shader_parameter("tint_warm", Vector3(config["warm"].r, config["warm"].g, config["warm"].b))
	material.set_shader_parameter("softness", float(config["softness"]))
	material.set_shader_parameter("variation", float(config["variation"]))

	# Square quads: the per-particle stretch happens inside the shader, where it can be
	# renormalised so the shape always fades out before the quad edge.
	var quad := QuadMesh.new()
	quad.size = Vector2(float(config["size"]), float(config["size"])) * _scale

	var emitter := GPUParticles3D.new()
	emitter.name = str(config["id"])
	emitter.amount = int(config["count"])
	emitter.lifetime = float(config["lifetime"])
	# Godot 4 exposes emission spread as `randomness` on the node; `lifetime_randomness` is a
	# Godot 3 name and silently does not exist here. Low, so motes do not blink in and out.
	emitter.randomness = 0.25
	emitter.preprocess = float(config["lifetime"])
	# World-space particles: this is what makes the camera's own travel produce the parallax.
	emitter.local_coords = false
	emitter.fixed_fps = 30
	emitter.interpolate = true
	emitter.use_fixed_seed = true
	emitter.seed = 614 + layers.size() * 31
	emitter.visibility_aabb = AABB(-extents - Vector3.ONE * 12.0, extents * 2.0 + Vector3.ONE * 24.0)
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitter.process_material = process
	emitter.draw_pass_1 = quad
	emitter.material_override = material
	add_child(emitter)
	emitter.global_transform = Transform3D(framing.basis, framing.origin - framing.basis.z * depth)
	layers.append(emitter)
	materials.append(material)


## Airborne haze thins when the district loses power, on the same supply curve as every other
## emitter here, so a blackout does not leave a lit dust field hanging in a dark yard.
func _sync(values: Dictionary) -> void:
	var supply: float = clampf(float(values.get("power", 0.92)) / 0.92, 0.0, 1.0)
	supply *= 1.0 - 0.9 * clampf(float(values.get("blackout_amount", 0.0)), 0.0, 1.0)
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("supply", supply)


func _exit_tree() -> void:
	for emitter: GPUParticles3D in layers:
		emitter.emitting = false
		emitter.process_material = null
		emitter.draw_pass_1 = null
		emitter.material_override = null
	layers.clear()


func get_report() -> Dictionary:
	var total: int = 0
	var depths: Array = []
	for config: Dictionary in LAYERS:
		total += int(config["count"])
		depths.append(snappedf(float(config["depth"]) * _scale, 0.01))
	return {
		"layers": layers.size(),
		"particles": total,
		"depths_m": depths,
		"world_anchored": true,
		"additional_lights": 0,
		"shadow_casting": false,
		"draw_calls": layers.size(),
		"shared_shader": 1,
	}
