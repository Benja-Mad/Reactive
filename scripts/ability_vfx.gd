class_name AbilityVfx
extends RefCounted

const HEAL_COLOR: Color = Color(0.25, 1.0, 0.68, 1.0)
const SHIELD_COLOR: Color = Color(0.3, 0.72, 1.0, 1.0)
const ORB_SCENE: PackedScene = preload("res://scenes/effects/healer_orb_sprite.tscn")
const SHIELD_SCENE: PackedScene = preload("res://scenes/effects/shield_ward_sprite.tscn")
const POISON_TEXTURE: Texture2D = preload("res://assets/generated/poison_status_icon_frame_0.png")


static func spawn_heal(source: Node3D, target: Node3D) -> void:
	if source == null or target == null or source.get_tree() == null:
		return
	var root: Node3D = Node3D.new()
	root.name = "HealTravelVFX"
	source.get_tree().current_scene.add_child(root)
	root.global_position = source.global_position + Vector3.UP * 0.7
	var orb: AnimatedSprite3D = ORB_SCENE.instantiate() as AnimatedSprite3D
	if orb != null:
		root.add_child(orb)
	var halo: MeshInstance3D = _sphere(0.24, Color(0.5, 1.0, 0.82, 0.12), 1.4, true)
	root.add_child(halo)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = HEAL_COLOR
	light.light_energy = 1.8
	light.omni_range = 2.5
	light.shadow_enabled = false
	root.add_child(light)
	var destination: Vector3 = target.global_position + Vector3.UP * 0.65
	var travel: Tween = root.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	travel.tween_property(root, "global_position", destination, 0.38)
	travel.tween_callback(_spawn_impact.bind(target))
	travel.tween_callback(root.queue_free)


static func spawn_shield(target: Node3D, duration: float) -> void:
	if target == null:
		return
	var shield_root: Node3D = Node3D.new()
	shield_root.name = "ShieldVFX"
	target.add_child(shield_root)
	shield_root.position = Vector3.UP * 0.55
	var shell: MeshInstance3D = _sphere(0.78, Color(0.22, 0.7, 1.0, 0.07), 1.1, true)
	shell.scale = Vector3(1.0, 1.25, 1.0)
	shield_root.add_child(shell)
	var ward: AnimatedSprite3D = SHIELD_SCENE.instantiate() as AnimatedSprite3D
	if ward != null:
		ward.position.y = 0.05
		shield_root.add_child(ward)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = SHIELD_COLOR
	light.light_energy = 1.2
	light.omni_range = 2.2
	light.shadow_enabled = false
	shield_root.add_child(light)
	shield_root.scale = Vector3(0.15, 0.15, 0.15)
	var appear: Tween = shield_root.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	appear.tween_property(shield_root, "scale", Vector3.ONE, 0.28)
	appear.tween_interval(maxf(duration - 0.6, 0.1))
	appear.tween_property(shield_root, "scale", Vector3(1.18, 1.18, 1.18), 0.25)
	appear.parallel().tween_property(shell, "transparency", 1.0, 0.25)
	appear.tween_callback(shield_root.queue_free)


static func spawn_status(target: Node3D, _color: Color, duration: float) -> void:
	if target == null:
		return
	var root: Node3D = Node3D.new()
	root.name = "PoisonStatusVFX"
	target.add_child(root)
	var icon: Sprite3D = Sprite3D.new()
	icon.texture = POISON_TEXTURE
	icon.pixel_size = 0.014
	icon.position = Vector3(0.0, 1.48, 0.0)
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.shaded = false
	icon.no_depth_test = true
	icon.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	root.add_child(icon)
	var bob: Tween = root.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(icon, "position:y", 1.58, 0.55)
	bob.tween_property(icon, "position:y", 1.48, 0.55)
	var life: Tween = root.create_tween()
	life.tween_interval(duration)
	life.tween_property(icon, "transparency", 1.0, 0.25)
	life.tween_callback(root.queue_free)


static func _spawn_impact(target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var impact: Node3D = Node3D.new()
	impact.name = "HealImpactVFX"
	target.add_child(impact)
	impact.position = Vector3(0.0, 0.05, 0.0)
	var ring: MeshInstance3D = _ring(0.78, 0.06, Color(0.35, 1.0, 0.68, 0.5), 3.2)
	impact.add_child(ring)
	var burst: GPUParticles3D = _particles(18, HEAL_COLOR, 0.8, 1.8)
	burst.position.y = 0.15
	impact.add_child(burst)
	burst.emitting = true
	impact.scale = Vector3(0.2, 0.2, 0.2)
	var pulse: Tween = impact.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pulse.tween_property(impact, "scale", Vector3(1.45, 1.45, 1.45), 0.35)
	pulse.parallel().tween_property(ring, "transparency", 1.0, 0.55)
	pulse.tween_interval(0.55)
	pulse.tween_callback(impact.queue_free)


static func _sphere(radius: float, color: Color, energy: float, transparent: bool) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = _material(color, energy, transparent)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


static func _ring(radius: float, thickness: float, color: Color, energy: float) -> MeshInstance3D:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = maxf(radius - thickness, 0.02)
	mesh.outer_radius = radius
	mesh.rings = 32
	mesh.ring_segments = 8
	mesh.material = _material(color, energy, true)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


static func _material(color: Color, energy: float, transparent: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = energy
	material.roughness = 0.35
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


static func _particles(amount: int, color: Color, lifetime: float, velocity: float) -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.local_coords = true
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.45
	process.direction = Vector3.UP
	process.spread = 35.0
	process.initial_velocity_min = velocity * 0.65
	process.initial_velocity_max = velocity
	process.gravity = Vector3(0.0, -0.8, 0.0)
	process.scale_min = 0.06
	process.scale_max = 0.13
	process.color = color
	particles.process_material = process
	var draw_mesh: SphereMesh = SphereMesh.new()
	draw_mesh.radius = 0.045
	draw_mesh.height = 0.09
	draw_mesh.material = _material(color, 3.5, true)
	particles.draw_pass_1 = draw_mesh
	return particles
