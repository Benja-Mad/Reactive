## A sentry's shot, drawn on every peer from the host's verdict. The discharge runs down the
## locked line as a white-hot front, leaves an ionised channel that crackles for a moment, and
## lands differently on what it met: a player, cover, a cloud, or the yard itself.
## Purely visual -- damage was already resolved on the host when this is spawned.
extends Node3D

enum Outcome { SCENERY, COVER, PLAYER, VEILED }

const Fx = preload("res://scripts/matter/matter_fx.gd")
const TRAVEL := 0.085
const LINGER := 0.22
const HOT := Color(1.0, 0.9, 0.86)
const SHEATH := Color(1.0, 0.07, 0.15)

var from := Vector3.ZERO
var to := Vector3.ZERO
var outcome: int = Outcome.SCENERY
var _age: float = 0.0
var _core: MeshInstance3D
var _sheath: MeshInstance3D
var _arc: MeshInstance3D
var _core_material: ShaderMaterial
var _sheath_material: ShaderMaterial
var _arc_material: StandardMaterial3D
var _landed: bool = false
var _rng := RandomNumberGenerator.new()

static func fire(parent: Node, start: Vector3, finish: Vector3, result: int) -> void:
	if parent == null or DisplayServer.get_name() == "headless": return
	var shot := new()
	shot.from = start
	shot.to = finish
	shot.outcome = result
	parent.add_child(shot)

func _ready() -> void:
	top_level = true
	_rng.randomize()
	_core = _tube()
	_core_material = _core.material_override
	_sheath = _tube()
	_sheath_material = _sheath.material_override
	_arc = MeshInstance3D.new()
	_arc.mesh = ImmediateMesh.new()
	_arc_material = StandardMaterial3D.new()
	_arc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arc_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_arc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_arc_material.albedo_color = Color(1.0, 0.35, 0.4, 0.9)
	_arc.material_override = _arc_material
	_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arc)
	# Muzzle: a flash that lights the sentry from its own weapon, and a breath of smoke.
	Fx.flash(get_parent(), from, Color(1.0, 0.2, 0.18), 7.0, 5.0, 0.18)
	Fx.burst(get_parent(), from, 10, Fx.quad(0.1), Fx.spark_material(Color(1.0, 0.45, 0.3)), Vector2(2.0, 5.0), 25.0, Vector3(0, -4, 0), 0.25, Vector2(0.5, 1.0))
	Fx.burst(get_parent(), from, 5, Fx.quad(0.5), Fx.puff_material(Color(0.32, 0.3, 0.32, 0.5), 0.15), Vector2(0.2, 0.6), 40.0, Vector3(0, 0.6, 0), 0.9, Vector2(0.5, 1.0), Vector3.ZERO, false, 1.5)

func _tube() -> MeshInstance3D:
	var tube := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 1
	tube.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://scenes/characters/sentry_beam.gdshader")
	material.set_shader_parameter("dash", 0.0)
	tube.material_override = material
	tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tube)
	return tube

func _process(delta: float) -> void:
	_age += delta
	var span: Vector3 = to - from
	var length: float = maxf(span.length(), 0.01)
	var axis: Vector3 = span / length
	# The front runs out to the target, then the channel fades and narrows behind it.
	var reach: float = clampf(_age / TRAVEL, 0.0, 1.0)
	var fade: float = 1.0 - clampf((_age - TRAVEL) / LINGER, 0.0, 1.0)
	if reach >= 1.0 and not _landed:
		_landed = true
		_land(axis)
	if fade <= 0.0:
		queue_free()
		return
	var tail: float = clampf((_age - TRAVEL * 0.6) / (TRAVEL + LINGER) * 0.35, 0.0, 0.35) if _age > TRAVEL else 0.0
	var start: Vector3 = from + span * tail
	var end: Vector3 = from + span * reach
	var flicker: float = 0.75 + 0.25 * _rng.randf()
	_place(_core, start, end, 0.03 * (0.4 + fade * 0.6))
	_place(_sheath, start, end, 0.09 * fade + 0.02)
	_core_material.set_shader_parameter("color", HOT)
	_core_material.set_shader_parameter("intensity", 5.0 * fade * flicker)
	_core_material.set_shader_parameter("length", length)
	_sheath_material.set_shader_parameter("color", SHEATH)
	_sheath_material.set_shader_parameter("intensity", 2.4 * fade * flicker)
	_sheath_material.set_shader_parameter("length", length)
	_draw_arc(start, end, axis, fade)

func _place(tube: MeshInstance3D, start: Vector3, end: Vector3, width: float) -> void:
	var span: Vector3 = end - start
	var length: float = maxf(span.length(), 0.01)
	var axis: Vector3 = span / length
	var side: Vector3 = axis.cross(Vector3.UP)
	if side.length_squared() < 0.001: side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var forward: Vector3 = side.cross(axis).normalized()
	tube.global_transform = Transform3D(Basis(side * width, axis * length, forward * width), start + span * 0.5)

## A jagged filament wound around the channel, re-rolled every frame so it crackles.
func _draw_arc(start: Vector3, end: Vector3, axis: Vector3, fade: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var geometry := _arc.mesh as ImmediateMesh
	geometry.clear_surfaces()
	if camera == null or fade <= 0.05: return
	var side: Vector3 = axis.cross(Vector3.UP).normalized()
	var up: Vector3 = side.cross(axis).normalized()
	geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var segments: int = 14
	for i: int in segments + 1:
		var t: float = float(i) / float(segments)
		var jitter: float = 0.0 if i == 0 or i == segments else 0.16 * fade
		var point: Vector3 = start.lerp(end, t) + side * _rng.randf_range(-jitter, jitter) + up * _rng.randf_range(-jitter, jitter)
		var across: Vector3 = axis.cross(camera.global_position - point).normalized() * 0.012
		geometry.surface_add_vertex(point - across)
		geometry.surface_add_vertex(point + across)
	geometry.surface_end()
	_arc_material.albedo_color.a = 0.9 * fade

func _land(axis: Vector3) -> void:
	var parent: Node = get_parent()
	match outcome:
		Outcome.PLAYER:
			Fx.burst(parent, to, 22, Fx.quad(0.11), Fx.spark_material(Color(1.0, 0.3, 0.22)), Vector2(3.0, 7.0), 70.0, Vector3(0, -9, 0), 0.5, Vector2(0.5, 1.2))
			Fx.flash(parent, to, Color(1.0, 0.18, 0.15), 8.0, 4.5, 0.3)
			Fx.burst(parent, to, 6, Fx.quad(0.7), Fx.puff_material(Color(1.0, 0.3, 0.25, 0.35), 0.6, false), Vector2(0.2, 0.8), 90.0, Vector3.ZERO, 0.35, Vector2(0.8, 1.3), Vector3.ZERO, false, 2.0)
		Outcome.COVER:
			# Cover takes it: molten spatter clings to the surface instead of passing through.
			Fx.burst(parent, to - axis * 0.05, 26, Fx.quad(0.09), Fx.spark_material(Color(1.0, 0.62, 0.3)), Vector2(2.0, 5.0), 55.0, Vector3(0, -10, 0), 0.7, Vector2(0.5, 1.1))
			Fx.flash(parent, to - axis * 0.3, Color(1.0, 0.4, 0.2), 6.0, 4.0, 0.4)
		Outcome.VEILED:
			# Scattered inside the cloud: a dull red bloom, nothing sharp.
			Fx.burst(parent, to, 10, Fx.quad(1.4), Fx.puff_material(Color(1.0, 0.25, 0.22, 0.4), 0.9, false), Vector2(0.4, 1.2), 90.0, Vector3.ZERO, 0.6, Vector2(0.8, 1.6), Vector3(0.4, 0.4, 0.4), false, 2.0)
			Fx.flash(parent, to, Color(1.0, 0.2, 0.2), 5.0, 6.0, 0.6)
		_:
			Fx.burst(parent, to, 18, Fx.quad(0.09), Fx.spark_material(Color(1.0, 0.5, 0.3)), Vector2(2.5, 6.0), 60.0, Vector3(0, -10, 0), 0.6, Vector2(0.5, 1.1))
			Fx.burst(parent, to, 4, Fx.quad(0.6), Fx.puff_material(Color(0.25, 0.24, 0.26, 0.55), 0.1), Vector2(0.2, 0.7), 50.0, Vector3(0, 0.5, 0), 1.2, Vector2(0.6, 1.2), Vector3.ZERO, false, 1.5)
			Fx.flash(parent, to + Vector3.UP * 0.2, Color(1.0, 0.3, 0.2), 5.0, 3.5, 0.35)
			_scorch(to, 1.1)

static var _scorch_texture: GradientTexture2D

## A soot burn on the ground where the discharge landed, fading after a few seconds.
func _scorch(point: Vector3, size: float) -> void:
	if _scorch_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 1.0])
		gradient.colors = PackedColorArray([Color(0.02, 0.015, 0.012, 0.95), Color(0.05, 0.03, 0.025, 0.85), Color(0.06, 0.05, 0.045, 0.4), Color(0, 0, 0, 0)])
		_scorch_texture = GradientTexture2D.new()
		_scorch_texture.gradient = gradient
		_scorch_texture.fill = GradientTexture2D.FILL_RADIAL
		_scorch_texture.fill_from = Vector2(0.5, 0.5)
		_scorch_texture.fill_to = Vector2(1.0, 0.5)
	var decal := Decal.new()
	decal.texture_albedo = _scorch_texture
	decal.size = Vector3(size, 0.6, size)
	decal.cull_mask = 1
	get_parent().add_child(decal)
	decal.global_position = point
	decal.rotation.y = _rng.randf() * TAU
	var tween := decal.create_tween()
	tween.tween_interval(4.5)
	tween.tween_property(decal, "albedo_mix", 0.0, 1.5)
	tween.tween_callback(decal.queue_free)
