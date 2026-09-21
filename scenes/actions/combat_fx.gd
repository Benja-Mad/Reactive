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

static func burst(parent: Node, point: Vector3, color: Color) -> void:
	for index: int in 7:
		var angle: float = float(index) * TAU / 7.0
		var direction := Vector3(cos(angle), 0.4 + float(index % 3) * 0.2, sin(angle))
		beam(parent, point, point + direction * 0.45, color, 0.22, 0.018)
	var light := OmniLight3D.new()
	parent.add_child(light)
	light.global_position = point + Vector3.UP * 0.15
	light.light_color = color
	light.light_energy = 3.5
	light.omni_range = 3.0
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.22)
	tween.tween_callback(light.queue_free)

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
