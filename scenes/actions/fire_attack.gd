extends Area3D

@export var speed : float = 10.0
@export var damage: float = 5.0

var direction : Vector3
var spent: bool = false
var _trail: MeshInstance3D

func _ready() -> void:
	var spawn_transform: Transform3D = global_transform
	top_level = true
	global_transform = spawn_transform
	var visual := $MeshInstance3D as MeshInstance3D
	visual.scale = Vector3(0.18, 0.18, 0.18)
	_trail = MeshInstance3D.new()
	var streak := CylinderMesh.new()
	streak.top_radius = 0.035
	streak.bottom_radius = 0.008
	streak.height = 1.0
	streak.radial_segments = 6
	_trail.mesh = streak
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.55, 0.12)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.28, 0.035)
	material.emission_energy_multiplier = 6.0
	visual.material_override = material
	_trail.material_override = material
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.38, 0.08)
	light.light_energy = 2.0
	light.omni_range = 3.0
	add_child(light)
	preload("res://scenes/actions/combat_fx.gd").burst(get_tree().current_scene, global_position, Color(1.0, 0.57, 0.13))
	var operative := get_parent().get_node_or_null("OperativeVisual")
	if operative != null:
		operative.kick()
	await get_tree().create_timer(3).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	if spent:
		return
	var next: Vector3 = global_position + speed * direction.normalized() * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next)
	var shooter := get_parent() as CollisionObject3D
	if shooter != null:
		query.exclude = [shooter.get_rid()]
	# Orient and stretch the one trail the bolt owns, behind its own direction of travel.
	if _trail != null and direction.length_squared() > 0.001:
		var travel: Vector3 = direction.normalized()
		var side: Vector3 = travel.cross(Vector3.UP)
		if side.length_squared() < 0.01:
			side = travel.cross(Vector3.RIGHT)
		side = side.normalized()
		_trail.global_basis = Basis(side, travel, side.cross(travel).normalized()).scaled(Vector3(1.0, 1.6, 1.0))
		_trail.global_position = global_position - travel * 0.8
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		spent = true
		global_position = hit.position
		preload("res://scenes/actions/combat_fx.gd").burst(get_tree().current_scene, global_position, Color(1.0, 0.48, 0.1))
		if multiplayer.is_server() and hit.collider.has_method("take_damage"):
			hit.collider.take_damage(damage)
		var tween := create_tween()
		tween.tween_property($MeshInstance3D, "scale", Vector3.ONE * 0.7, 0.08)
		tween.tween_property($MeshInstance3D, "scale", Vector3.ZERO, 0.12)
		tween.tween_callback(queue_free)
	else:
		global_position = next
