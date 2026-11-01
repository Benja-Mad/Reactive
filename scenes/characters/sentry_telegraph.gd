## A sentry's warning, drawn on every peer from replicated state. While the shot charges, a
## targeting beam hunts the player -- loose at first, tightening as the charge builds -- and ends
## on whatever is actually in the way, so a player reads their cover from the beam itself. When
## the host commits the shot the beam stops moving: that frozen line is the dodge window.
## Nothing here resolves combat; YardSentry on the host does.
extends Node3D

enum Phase { IDLE, TRACKING, LOCKED, SPENT }

const MUZZLE := Vector3(0, 0.05, -0.47)
const HUNT := Color(1.0, 0.07, 0.16)
const COMMIT := Color(1.0, 0.42, 0.36)

var operative: Node3D
var phase: int = Phase.IDLE
var target: Node3D
var progress: float = 0.0
var track_time: float = 0.75
var lock_point := Vector3.ZERO
var aim := Vector3.ZERO
var beam_end := Vector3.ZERO
var _seed: float = 0.0
var _fade: float = 0.0
var _beam: MeshInstance3D
var _beam_material: ShaderMaterial
var _dot: MeshInstance3D
var _charge: MeshInstance3D
var _glow_material: StandardMaterial3D
var _dot_light: OmniLight3D
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _locked_for: float = 0.0
var _matter: Node

func _ready() -> void:
	top_level = true
	_seed = randf() * 100.0
	_beam = MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0
	tube.bottom_radius = 1.0
	tube.height = 1.0
	tube.radial_segments = 8
	tube.rings = 1
	_beam.mesh = tube
	_beam_material = ShaderMaterial.new()
	_beam_material.shader = preload("res://scenes/characters/sentry_beam.gdshader")
	_beam.material_override = _beam_material
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_glow_material = StandardMaterial3D.new()
	_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_glow_material.no_depth_test = false
	_glow_material.albedo_texture = _radial_texture()
	_glow_material.vertex_color_use_as_albedo = false
	_dot = _sprite(0.5)
	_charge = _sprite(0.3)
	# The commit cue: a ring closing on the locked point over the dodge window.
	_ring_material = _glow_material.duplicate()
	_ring_material.albedo_texture = _ring_texture()
	_ring = _sprite(1.0)
	_ring.material_override = _ring_material
	_dot_light = OmniLight3D.new()
	_dot_light.light_color = HUNT
	_dot_light.omni_range = 1.6
	_dot_light.shadow_enabled = false
	add_child(_dot_light)
	_set_visible(false)

func _sprite(size: float) -> MeshInstance3D:
	var sprite := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	sprite.mesh = quad
	sprite.material_override = _glow_material
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	return sprite

static func _ring_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.72, 0.82, 0.88, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture

static func _radial_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.18, Color(1, 1, 1, 0.85))
	gradient.add_point(0.45, Color(1, 1, 1, 0.18))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture

func begin(new_target: Node3D, duration: float) -> void:
	target = new_target
	track_time = maxf(duration, 0.05)
	progress = 0.0
	phase = Phase.TRACKING
	# Start the hunt off to one side of the player rather than on them, so the sweep is visible.
	var origin: Vector3 = muzzle()
	var chest: Vector3 = _chest(target)
	var side: Vector3 = (chest - origin).cross(Vector3.UP).normalized()
	aim = chest + side * (1.6 if randf() < 0.5 else -1.6) + Vector3.UP * 0.6
	_set_visible(true)

func lock(point: Vector3) -> void:
	lock_point = point + Vector3.UP * 0.9
	aim = lock_point
	phase = Phase.LOCKED
	_locked_for = 0.0
	_gather()

## Sparks drawn into the muzzle over the lock: the shot is coming, from exactly there.
func _gather() -> void:
	if DisplayServer.get_name() == "headless": return
	var particles := GPUParticles3D.new()
	particles.one_shot = true
	particles.amount = 18
	particles.lifetime = 0.32
	particles.explosiveness = 0.35
	particles.local_coords = true
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	process.emission_sphere_radius = 0.75
	process.gravity = Vector3.ZERO
	process.radial_accel_min = -28.0
	process.radial_accel_max = -20.0
	process.scale_min = 0.5
	process.scale_max = 1.0
	process.scale_curve = preload("res://scripts/matter/matter_fx.gd").grow_curve(0.4, 1.2)
	particles.process_material = process
	particles.draw_pass_1 = preload("res://scripts/matter/matter_fx.gd").quad(0.08)
	particles.material_override = preload("res://scripts/matter/matter_fx.gd").spark_material(Color(1.0, 0.3, 0.3))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	particles.global_position = muzzle()
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

func release() -> void:
	if phase == Phase.IDLE: return
	phase = Phase.SPENT
	_fade = 1.0

func cancel() -> void:
	phase = Phase.IDLE
	target = null
	_set_visible(false)

func muzzle() -> Vector3:
	if operative != null and operative.weapon != null:
		return operative.weapon.to_global(MUZZLE)
	return get_parent().global_position + Vector3.UP * 1.2

func _chest(node: Node3D) -> Vector3:
	return node.global_position + Vector3.UP * 0.9

func _set_visible(value: bool) -> void:
	_ring.visible = false
	_beam.visible = value
	_dot.visible = value
	_charge.visible = value
	_dot_light.visible = value

func _process(delta: float) -> void:
	if phase == Phase.IDLE: return
	if _matter == null: _matter = get_tree().get_first_node_in_group("world_matter")
	var origin: Vector3 = muzzle()
	var intensity: float = 1.0
	var width: float = 0.01
	var dash: float = 1.0
	var color: Color = HUNT
	match phase:
		Phase.TRACKING:
			if not is_instance_valid(target):
				cancel()
				return
			progress = minf(progress + delta / track_time, 1.0)
			# Loose and searching at first, settling onto the player as the charge completes.
			var settle: float = lerpf(2.5, 16.0, progress * progress)
			var wander: float = (1.0 - progress) * 0.45
			var t: float = Time.get_ticks_msec() * 0.001 + _seed
			var goal: Vector3 = _chest(target) + Vector3(sin(t * 7.3), sin(t * 5.1) * 0.5, cos(t * 6.1)) * wander
			aim = aim.lerp(goal, 1.0 - exp(-delta * settle))
			intensity = lerpf(0.35, 1.3, progress)
			width = lerpf(0.006, 0.014, progress)
			dash = 1.0 - progress * 0.6
			# Point the body at the beam so the figure, not just the line, reads as aiming.
			if operative != null:
				var flat := Vector3(aim.x - origin.x, 0.0, aim.z - origin.z)
				if flat.length_squared() > 0.01: operative.aim_direction = flat.normalized()
		Phase.LOCKED:
			_locked_for += delta
			var flicker: float = 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.06)
			intensity = 2.6 * flicker
			width = 0.022
			dash = 0.0
			color = COMMIT
		Phase.SPENT:
			_fade = maxf(0.0, _fade - delta * 6.0)
			if _fade <= 0.0:
				cancel()
				return
			intensity = 2.0 * _fade
			width = 0.03 * _fade
			dash = 0.0
			color = COMMIT
	beam_end = _resolve_end(origin, aim)
	var span: Vector3 = beam_end - origin
	var length: float = maxf(span.length(), 0.01)
	var axis: Vector3 = span / length
	var side: Vector3 = axis.cross(Vector3.UP)
	if side.length_squared() < 0.001: side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var forward: Vector3 = side.cross(axis).normalized()
	_beam.global_transform = Transform3D(Basis(side * width, axis * length, forward * width), origin + span * 0.5)
	_beam_material.set_shader_parameter("color", color)
	_beam_material.set_shader_parameter("intensity", intensity)
	_beam_material.set_shader_parameter("dash", dash)
	_beam_material.set_shader_parameter("length", length)
	_dot.global_position = beam_end - axis * 0.04
	_dot.scale = Vector3.ONE * (0.55 + intensity * 0.35)
	_charge.global_position = origin
	_charge.scale = Vector3.ONE * (0.4 + (progress if phase == Phase.TRACKING else 1.0) * 0.9)
	_glow_material.albedo_color = Color(color.r, color.g, color.b, clampf(intensity * 0.55, 0.0, 1.0))
	_ring.visible = phase == Phase.LOCKED
	if _ring.visible:
		var closing: float = clampf(_locked_for / 0.35, 0.0, 1.0)
		_ring.global_position = beam_end - axis * 0.06
		_ring.scale = Vector3.ONE * lerpf(1.5, 0.32, closing * closing)
		_ring_material.albedo_color = Color(COMMIT.r, COMMIT.g, COMMIT.b, lerpf(0.35, 1.0, closing))
	_dot_light.global_position = beam_end - axis * 0.25
	_dot_light.light_color = color
	_dot_light.light_energy = intensity * 0.9

## The beam stops on the first thing a real shot would meet: scenery, cover, a player, or the
## dense core of a cloud. Extended a little past the aim so it lands on surfaces, not in air.
func _resolve_end(origin: Vector3, point: Vector3) -> Vector3:
	var reach: Vector3 = point + (point - origin).normalized() * 0.6
	var query := PhysicsRayQueryParameters3D.create(origin, reach)
	var sentry := get_parent() as CollisionObject3D
	if sentry != null: query.exclude = [sentry.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = reach if hit.is_empty() else hit.position
	if _matter != null:
		var veiled: Variant = _matter.sight_obstruction(origin, end)
		if veiled != null: end = veiled
	return end
