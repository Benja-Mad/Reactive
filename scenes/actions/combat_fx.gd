## Short-lived world effects. Called from already replicated combat events on each peer.
extends Node3D

static func beam(parent: Node, start: Vector3, finish: Vector3, color: Color, duration: float = 0.16, width: float = 0.025) -> void:
	var effect := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = width
	mesh.bottom_radius = width
	mesh.height = maxf(start.distance_to(finish), 0.01)
	mesh.radial_segments = 8
	effect.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	effect.material_override = mat
	effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(effect)
	effect.global_position = (start + finish) * 0.5
	var direction: Vector3 = (finish - start).normalized()
	if direction.length_squared() > 0.1:
		var side: Vector3 = direction.cross(Vector3.FORWARD).normalized()
		if side.length_squared() < 0.01:
			side = direction.cross(Vector3.RIGHT).normalized()
		effect.global_basis = Basis(side, direction, side.cross(direction).normalized())
	var tween := effect.create_tween()
	tween.tween_property(effect, "scale", Vector3(0.01, 1, 0.01), duration)
	tween.tween_callback(effect.queue_free)

## Something breaking or landing hard: a spray of pixel shards in its colour, cooling as they fall,
## and a flash of its light on the floor around it.
static func burst(parent: Node, point: Vector3, color: Color) -> void:
	var shards := CPUParticles3D.new()
	shards.local_coords = false
	shards.one_shot = true
	shards.explosiveness = 1.0
	shards.amount = 12
	shards.lifetime = 0.5
	shards.direction = Vector3.UP
	shards.spread = 80.0
	shards.initial_velocity_min = 2.4
	shards.initial_velocity_max = 4.6
	shards.gravity = Vector3(0, -13, 0)
	shards.scale_amount_min = 0.67
	shards.scale_amount_max = 1.0
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1.0))
	shrink.add_point(Vector2(0.7, 1.0))
	shrink.add_point(Vector2(1, 0.0))
	shards.scale_amount_curve = shrink
	var cooling := Gradient.new()
	cooling.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	cooling.colors = PackedColorArray([color.lightened(0.6), color, color.darkened(0.6)])
	shards.color_ramp = cooling
	var quad := QuadMesh.new()
	# Three texels of the yard's grid: chunky enough to read as debris, still pixel-sized.
	quad.size = Vector2.ONE * 0.09
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.vertex_color_use_as_albedo = true
	paint.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = paint
	shards.mesh = quad
	shards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(shards)
	shards.global_position = point
	shards.emitting = true
	flash(parent, point + Vector3.UP * 0.15, color, 3.5, 3.0, 0.22)
	shards.create_tween().tween_callback(shards.queue_free).set_delay(0.7)

## A light that goes off once and dies: the yard lit for a moment in that colour.
static func flash(parent: Node, point: Vector3, color: Color, energy: float = 3.5, reach: float = 3.0, duration: float = 0.22) -> void:
	var light := OmniLight3D.new()
	parent.add_child(light)
	light.global_position = point
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(light.queue_free)

## A short circuit: hot white pixels thrown every way, fast, gone in a quarter second, and a pop of
## light. Where a discharge goes into something.
static func spark(parent: Node, point: Vector3, color: Color, amount: int = 10) -> void:
	var sparks := CPUParticles3D.new()
	sparks.local_coords = false
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = amount
	sparks.lifetime = 0.26
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 2.5
	sparks.initial_velocity_max = 6.0
	sparks.gravity = Vector3(0, -9, 0)
	sparks.damping_min = 4.0
	sparks.damping_max = 8.0
	var cooling := Gradient.new()
	cooling.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	cooling.colors = PackedColorArray([Color(1.6, 1.6, 1.5), color, color.darkened(0.55)])
	sparks.color_ramp = cooling
	sparks.mesh = _square(_texel(parent) * 2.0, true)
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sparks)
	sparks.global_position = point
	sparks.emitting = true
	flash(parent, point, color, 2.6, 2.4, 0.16)
	sparks.create_tween().tween_callback(sparks.queue_free).set_delay(0.4)

## A hit that lands on the floor: one pixel-thin ring that spreads out to `radius` and breaks into
## dashes as it fades, in the colour of whoever struck.
static func ripple(parent: Node, point: Vector3, color: Color, radius: float = 1.6, duration: float = 0.45) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (radius * 2.0 + 0.4)
	var art := ShaderMaterial.new()
	art.shader = preload("res://scripts/survivor/ripple.gdshader")
	art.set_shader_parameter("radius", radius)
	art.set_shader_parameter("color", color)
	art.set_shader_parameter("line", _texel(parent) * 2.0)
	var ring := MeshInstance3D.new()
	ring.mesh = plane
	ring.material_override = art
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.global_position = point + Vector3.UP * 0.04
	var tween := ring.create_tween()
	tween.tween_method(func(value: float) -> void: art.set_shader_parameter("progress", value), 0.0, 1.0, duration)
	tween.tween_callback(ring.queue_free)

## Smoke off something put out: a few dark pixel clumps that rise slowly and thin away.
static func smoke(parent: Node, point: Vector3, color: Color = Color("6b7686"), amount: int = 12) -> void:
	var puffs := CPUParticles3D.new()
	puffs.local_coords = false
	puffs.one_shot = true
	puffs.explosiveness = 0.7
	puffs.amount = amount
	puffs.lifetime = 1.1
	puffs.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puffs.emission_sphere_radius = 0.25
	puffs.direction = Vector3.UP
	puffs.spread = 25.0
	puffs.initial_velocity_min = 0.6
	puffs.initial_velocity_max = 1.3
	puffs.gravity = Vector3(0, 0.4, 0)
	puffs.damping_min = 0.6
	puffs.damping_max = 1.0
	puffs.scale_amount_min = 1.0
	puffs.scale_amount_max = 2.0
	var thin := Curve.new()
	thin.add_point(Vector2(0, 0.6))
	thin.add_point(Vector2(0.3, 1.0))
	thin.add_point(Vector2(1, 0.0))
	puffs.scale_amount_curve = thin
	var cool := Gradient.new()
	cool.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	cool.colors = PackedColorArray([color.lightened(0.25), color, color.darkened(0.4)])
	puffs.color_ramp = cool
	puffs.mesh = _square(_texel(parent) * 4.0)
	puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(puffs)
	puffs.global_position = point
	puffs.emitting = true
	puffs.create_tween().tween_callback(puffs.queue_free).set_delay(1.3)

## A flat-coloured square of the given size that faces the camera, for pixel particles.
static func _square(size: float, additive: bool = false) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.vertex_color_use_as_albedo = true
	paint.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if additive: paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = paint
	return quad

## One pixel of the yard's grid, in metres.
static func _texel(node: Node) -> float:
	var view: Node = node.get_tree().get_first_node_in_group("pixel_view") if node.is_inside_tree() else null
	return float(view.metres_per_pixel) if view != null and view.metres_per_pixel > 0.0 else 0.03

static func number(parent: Node, point: Vector3, message: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = message
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.pixel_size = 0.007
	label.outline_size = 5
	label.modulate = color
	parent.add_child(label)
	label.global_position = point
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.7, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(label.queue_free)
