extends StaticBody3D

var health: float = 30.0
var cycle: float = 0.0
var target_path: NodePath
var sprite: AnimatedSprite3D
var label: Label3D
var warning: MeshInstance3D
var down: bool = false
var operative: Node3D
var aim_point := Vector3.ZERO

func _ready() -> void:
	add_to_group("yard_sentries")
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.65
	shape.height = 2.6
	collision.shape = shape
	collision.position.y = 1.3
	add_child(collision)
	# Reuse the shipped animated character atlas instead of introducing unrelated art.
	var source := preload("res://scenes/characters/damage/damage.tscn").instantiate()
	sprite = AnimatedSprite3D.new()
	sprite.sprite_frames = source.get_node("AnimatedSprite3D").sprite_frames
	source.free()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.065
	sprite.position.y = 1.35
	sprite.modulate = Color(0.65, 0.72, 0.86)
	add_child(sprite)
	sprite.play("Idle")
	sprite.hide()
	operative = preload("res://scenes/characters/operative_visual.gd").new()
	operative.accent = Color(1.0, 0.075, 0.18)
	operative.hostile = true
	add_child(operative)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.45
	label.font_size = 32
	label.pixel_size = 0.009
	label.modulate = Color(1.0, 0.15, 0.25)
	label.text = "━━━━━\n⌄"
	add_child(label)
	warning = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	warning.mesh = torus
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.06, 0.15)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.03, 0.08)
	material.emission_energy_multiplier = 2.0
	warning.material_override = material
	add_child(warning)
	warning.visible = false

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or down:
		return
	cycle += delta
	if cycle >= 2.5 and target_path.is_empty():
		var nearest: Node3D
		var distance: float = 22.0
		for candidate: Node in get_tree().get_nodes_in_group("coop_players"):
			var separation: float = global_position.distance_to(candidate.global_position)
			if separation < distance:
				var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.3, candidate.global_position + Vector3.UP * 0.4)
				ray.exclude = [get_rid()]
				var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
				if not hit.is_empty() and hit.collider != candidate:
					continue
				nearest = candidate
				distance = separation
		if nearest != null:
			target_path = nearest.get_path()
			telegraph.rpc(nearest.global_position)
		else:
			cycle = 0.0
	if cycle >= 3.6 and not target_path.is_empty():
		for candidate: Node in get_tree().get_nodes_in_group("coop_players"):
			if Vector2(candidate.global_position.x-warning.global_position.x, candidate.global_position.z-warning.global_position.z).length() < 1.15:
				# Recheck cover at impact: a player may move behind a barrier during the warning.
				var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.3, candidate.global_position + Vector3.UP * 0.4)
				ray.exclude = [get_rid()]
				var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
				if hit.is_empty() or hit.collider == candidate:
					candidate.receive_health.rpc(-16.0)
		finish_shot.rpc()
		target_path = NodePath()
		cycle = 0.0

@rpc("authority", "call_local", "reliable")
func telegraph(point: Vector3) -> void:
	aim_point = point
	operative.aim_direction = Vector3(point.x - global_position.x, 0, point.z - global_position.z).normalized()
	preload("res://scenes/actions/combat_fx.gd").beam(get_tree().current_scene, global_position + Vector3.UP * 1.2, Vector3(point.x, 0.08, point.z), Color(0.8, 0.025, 0.1), 1.1, 0.008)
	warning.global_position = Vector3(point.x, 0.04, point.z)
	warning.visible = true
	warning.scale = Vector3.ONE * 1.5
	create_tween().tween_property(warning, "scale", Vector3.ONE, 1.1)
	sprite.modulate = Color(1.0, 0.45, 0.45)

@rpc("authority", "call_local", "reliable")
func finish_shot() -> void:
	operative.kick()
	preload("res://scenes/actions/combat_fx.gd").beam(get_tree().current_scene, global_position + Vector3.UP * 1.2, warning.global_position + Vector3.UP * 0.1, Color(1.0, 0.06, 0.16))
	preload("res://scenes/actions/combat_fx.gd").burst(get_tree().current_scene, warning.global_position + Vector3.UP * 0.1, Color(1.0, 0.18, 0.08))
	warning.visible = false
	sprite.modulate = Color(0.65, 0.72, 0.86)

func take_damage(amount: float) -> void:
	if not multiplayer.is_server() or down:
		return
	update_health.rpc(maxf(0.0, health - amount))
	if health <= 0.0:
		await get_tree().create_timer(8.0).timeout
		health = 30.0
		update_health.rpc(health)

@rpc("authority", "call_local", "reliable")
func update_health(value: float) -> void:
	if value < health:
		preload("res://scenes/actions/combat_fx.gd").number(get_tree().current_scene, global_position + Vector3.UP * 2.1, str(int(health - value)), Color(1, 0.7, 0.3))
	health = value
	down = health <= 0.0
	operative.disabled = down
	label.text = "REBOOTING" if down else "━".repeat(ceili(health / 6.0)) + "\n⌄"
	sprite.modulate = Color(0.18, 0.22, 0.27) if down else Color(1.0, 0.6, 0.55)
	sprite.rotation.z = -0.8 if down else 0.0
	if down:
		warning.visible = false
		cycle = 0.0
		target_path = NodePath()
