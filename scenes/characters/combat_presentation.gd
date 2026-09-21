extends Node3D

var player: Character
var ring: MeshInstance3D
var lamp: OmniLight3D
var tint: Color
var clock: float = 0.0
var step_time: float = 0.0
var previous_health: float = 100.0
var damage_flash: float = 0.0
var aim_marker: MeshInstance3D
var player_name: String = ""

func _ready() -> void:
	player = get_parent() as Character
	# Character._ready() already put the seat's name here; a health bar should not cost it.
	player_name = str(player.label_3d.text)
	tint = Color(1.0, 0.73, 0.16) if player is Damage else Color(0.12, 0.95, 1.0)
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.65
	torus.rings = 48
	torus.ring_segments = 8
	ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 2.0
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var shape := player.get_node("CollisionShape3D") as CollisionShape3D
	ring.position.y = shape.position.y - (shape.shape as CapsuleShape3D).height * 0.5 + 0.035
	lamp = OmniLight3D.new()
	lamp.light_color = tint
	lamp.light_energy = 1.2
	lamp.omni_range = 3.5
	lamp.position.y = 0.3
	add_child(lamp)
	player.label_3d.font_size = 40
	player.label_3d.pixel_size = 0.009
	player.label_3d.outline_size = 5
	player.label_3d.modulate = tint
	player.label_3d.no_depth_test = true
	if player is Damage and player.is_multiplayer_authority():
		aim_marker = MeshInstance3D.new()
		var sight := TorusMesh.new()
		sight.inner_radius = 0.18
		sight.outer_radius = 0.21
		sight.rings = 24
		sight.ring_segments = 4
		aim_marker.mesh = sight
		aim_marker.material_override = material
		aim_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(aim_marker)
		aim_marker.top_level = true
		aim_marker.hide()

func _process(delta: float) -> void:
	clock += delta
	step_time += delta
	if player.health < previous_health:
		damage_flash = 0.3
	previous_health = player.health
	damage_flash = maxf(0, damage_flash - delta)
	lamp.light_color = Color(1, 0.12, 0.08) if damage_flash > 0 else tint
	if step_time > 0.32 and player.is_on_floor() and Vector2(player.velocity.x, player.velocity.z).length() > 0.5:
		step_time = 0.0
		_foot_ripple()
	ring.scale = Vector3.ONE * (1.0 + sin(clock * 3.0) * 0.025)
	lamp.light_energy = (1.7 if damage_flash > 0 else 0.9) + sin(clock * 3.0) * 0.1
	player.label_3d.text = player_name + "\n" + "━".repeat(maxi(0, ceili(player.health / 20.0))) + "\n⌄"
	player.label_3d.modulate = Color(1, 0.25, 0.16) if damage_flash > 0 else tint
	if aim_marker != null:
		var camera := get_viewport().get_camera_3d()
		var mouse := get_viewport().get_mouse_position()
		var point: Variant = Plane(Vector3.UP, 0.06).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
		aim_marker.visible = point != null and player.input_synchronizer.mouse_aim_active and not player.programming_block.code_block.has_focus()
		if point != null:
			aim_marker.global_position = point

func _foot_ripple() -> void:
	var ripple := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.12
	mesh.outer_radius = 0.135
	mesh.rings = 24
	mesh.ring_segments = 4
	ripple.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.42, 0.68, 0.75, 0.3)
	ripple.material_override = material
	ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(ripple)
	ripple.global_position = ring.global_position + Vector3.UP * 0.005
	var tween := ripple.create_tween().set_parallel(true)
	tween.tween_property(ripple, "scale", Vector3(3.0, 1.0, 3.0), 0.45)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(ripple.queue_free)
