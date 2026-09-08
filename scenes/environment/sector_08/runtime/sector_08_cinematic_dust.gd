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

## depth     : metres in front of the approved camera.
## extents   : half-size of the emission box, wide enough to keep the frame fed as it dollies.
## size      : quad edge in metres. Near motes are large because they are wildly out of focus.
## defocus   : average character of the layer -- 0 sharp specks, 1 defocused aperture discs. Each
##             particle strays from it by its own draw, so a layer is a spread, not one sprite.
## variation : how far that stray is allowed to go.
## churn     : turbulence strength, so motes in the same layer do not travel on parallel rails.
const LAYERS := [
	{
		"id": "LensMotes", "depth": 14.0, "extents": Vector3(17.0, 7.0, 7.0),
		"count": 52, "size": 0.34, "opacity": 0.21, "lifetime": 26.0,
		"drift": Vector3(-0.22, 0.09, 0.02), "defocus": 0.85, "variation": 0.85,
		"churn": 0.16, "tint": Color(0.78, 0.83, 0.95), "warm": Color(1.0, 0.74, 0.48),
	},
	{
		"id": "ForegroundDrift", "depth": 37.0, "extents": Vector3(24.0, 11.0, 10.0),
		"count": 100, "size": 0.13, "opacity": 0.24, "lifetime": 32.0,
		"drift": Vector3(-0.14, 0.06, 0.01), "defocus": 0.45, "variation": 0.75,
		"churn": 0.24, "tint": Color(0.72, 0.80, 0.92), "warm": Color(1.0, 0.78, 0.55),
	},
	{
		"id": "MiddleDust", "depth": 64.0, "extents": Vector3(30.0, 16.0, 11.0),
		"count": 150, "size": 0.06, "opacity": 0.34, "lifetime": 38.0,
		"drift": Vector3(-0.08, 0.03, 0.0), "defocus": 0.10, "variation": 0.6,
		"churn": 0.30, "tint": Color(0.70, 0.79, 0.90), "warm": Color(0.98, 0.82, 0.62),
	},
]

var layers: Array[GPUParticles3D] = []
var materials: Array[ShaderMaterial] = []


func setup(arena: Node) -> void:
	var framing: Transform3D = arena.approved_transform
	for config: Dictionary in LAYERS:
		_layer(config, framing)
	arena.controller.reactive_state_changed.connect(_sync)
	_sync(arena.controller.get_values())


func _layer(config: Dictionary, framing: Transform3D) -> void:
	var extents: Vector3 = config["extents"]
	var drift: Vector3 = config["drift"]

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	process.direction = (framing.basis * drift).normalized()
	process.initial_velocity_min = drift.length() * 0.7
	process.initial_velocity_max = drift.length() * 1.4
	process.spread = 34.0
	process.gravity = Vector3.ZERO
	process.scale_min = 0.55
	process.scale_max = 1.6
	# Turbulence, damping and angular drift are what stop a layer travelling on parallel rails.
	process.turbulence_enabled = true
	process.turbulence_noise_strength = float(config["churn"])
	process.turbulence_noise_scale = 2.4
	process.turbulence_influence_min = 0.10
	process.turbulence_influence_max = 0.75
	process.damping_min = 0.0
	process.damping_max = 0.06
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -7.0
	process.angular_velocity_max = 7.0

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
	material.set_shader_parameter("defocus", float(config["defocus"]))
	material.set_shader_parameter("variation", float(config["variation"]))

	# Square quads: the per-particle stretch happens inside the shader, where it can be
	# renormalised so the shape always fades out before the quad edge.
	var quad := QuadMesh.new()
	quad.size = Vector2(float(config["size"]), float(config["size"]))

	var emitter := GPUParticles3D.new()
	emitter.name = str(config["id"])
	emitter.amount = int(config["count"])
	emitter.lifetime = float(config["lifetime"])
	# Godot 4 exposes emission spread as `randomness` on the node; `lifetime_randomness` is a
	# Godot 3 name and silently does not exist here.
	emitter.randomness = 0.85
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
	emitter.global_transform = Transform3D(framing.basis, framing.origin - framing.basis.z * float(config["depth"]))
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
		depths.append(float(config["depth"]))
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
