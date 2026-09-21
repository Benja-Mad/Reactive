extends MeshInstance3D

var origin: Node3D
var target: Node3D
var remaining: float = 0.58

func _ready() -> void:
	mesh = ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.1, 0.9, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.1, 0.9, 1.0)
	material.emission_energy_multiplier = 4.0
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var symbol := Label3D.new()
	symbol.name = "HealSymbol"
	symbol.text = "⊕"
	symbol.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	symbol.font_size = 56
	symbol.pixel_size = 0.008
	symbol.modulate = Color(0.12, 1, 1)
	add_child(symbol)

func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0 or not is_instance_valid(origin) or not is_instance_valid(target):
		queue_free()
		return
	var a: Vector3 = to_local(origin.global_position + Vector3.UP * 0.65)
	var b: Vector3 = to_local(target.global_position + Vector3.UP * 0.65)
	$HealSymbol.position = (a + b) * 0.5 + Vector3.UP * 0.1
	var side: Vector3 = (b-a).cross(get_viewport().get_camera_3d().global_basis.z).normalized() * 0.035
	var geometry := mesh as ImmediateMesh
	geometry.clear_surfaces()
	geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# A small traveling pulse gives the connection direction without obscuring either player.
	for segment: int in 12:
		var t0: float = float(segment) / 12.0
		var t1: float = float(segment + 1) / 12.0
		var p0: Vector3 = a.lerp(b, t0)
		var p1: Vector3 = a.lerp(b, t1)
		p0.y += sin(t0 * PI) * sin(t0 * TAU * 3.0 - remaining * 18.0) * 0.035
		p1.y += sin(t1 * PI) * sin(t1 * TAU * 3.0 - remaining * 18.0) * 0.035
		var width: float = 0.7 + 0.5 * pow(maxf(0.0, cos(t0 * TAU - remaining * 14.0)), 6.0)
		for point: Vector3 in [p0-side*width, p0+side*width, p1+side*width, p0-side*width, p1+side*width, p1-side*width]:
			geometry.surface_add_vertex(point)
	geometry.surface_end()
