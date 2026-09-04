class_name FireAttack
extends Area3D

@export var speed: float = 10.0
@export var damage: float = 12.0
@export var lifetime: float = 4.0
var direction: Vector3 = Vector3.FORWARD
var source: Character
var target: Node3D
var _age: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true
	_build_trail()


func setup_projectile(caster: Character, travel_direction: Vector3, tracked_target: Node3D, power: float) -> void:
	source = caster
	direction = travel_direction
	target = tracked_target
	damage = power


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	if target != null and is_instance_valid(target):
		var desired: Vector3 = (target.global_position - global_position).normalized()
		direction = direction.lerp(desired, minf(delta * 4.0, 1.0)).normalized()
	global_position += speed * direction * delta


func _on_body_entered(body: Node3D) -> void:
	if body == source:
		return
	if body.has_method("get_health_component"):
		var health: HealthComponent = body.call("get_health_component") as HealthComponent
		if health != null:
			health.apply_damage(damage, source)
			_spawn_impact()
			queue_free()


func _build_trail() -> void:
	var particles: GPUParticles3D = AbilityVfx._particles(18, Color(1.0, 0.35, 0.08), 0.45, 0.25)
	particles.one_shot = false
	particles.amount = 18
	particles.lifetime = 0.45
	particles.position = -direction * 0.15
	add_child(particles)
	particles.emitting = true
	var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		mesh_instance.set_surface_override_material(0, AbilityVfx._material(Color(1.0, 0.23, 0.04), 5.0, false))
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.28, 0.06)
	light.light_energy = 1.4
	light.omni_range = 2.0
	light.shadow_enabled = false
	add_child(light)


func _spawn_impact() -> void:
	var impact: Node3D = Node3D.new()
	get_tree().current_scene.add_child(impact)
	impact.global_position = global_position
	var burst: GPUParticles3D = AbilityVfx._particles(20, Color(1.0, 0.3, 0.06), 0.7, 2.5)
	impact.add_child(burst)
	burst.emitting = true
	var cleanup: Tween = impact.create_tween()
	cleanup.tween_interval(0.9)
	cleanup.tween_callback(impact.queue_free)
