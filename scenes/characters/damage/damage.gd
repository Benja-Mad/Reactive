class_name Damage
extends Character

@export var fire_attack_scene : PackedScene
@onready var marker_3d: Marker3D = $Marker3D
@onready var fire_attack_spawner: MultiplayerSpawner = $FireAttackSpawner

const FLAME_WAVE_RADIUS: float = 3.0
const FLAME_WAVE_DAMAGE: int = 40

var facing_dir: Vector3 = Vector3.RIGHT

func _ready() -> void:
	super._ready()
	fire_attack_spawner.spawn_function = _spawn_fire_attack


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var input_dir: Vector2 = input_synchronizer.move_input
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
	if direction.length() > 0:
		facing_dir = direction
			
func use_ability(ability: Statics.Ability) -> void:
	if not is_multiplayer_authority() or is_dead:
		return
		
	match ability:
		Statics.Ability.FIRE:
			_fire()
		Statics.Ability.FLAME_WAVE:
			_flame_wave()


## Daña a todos los enemigos alrededor; el impacto lo procesa el caster, como los proyectiles.
func _flame_wave() -> void:
	trigger_particles_all(^"FlameWaveParticles")
	show_flame_wave.rpc()
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node3D
		if enemy != null and enemy.global_position.distance_to(global_position) <= FLAME_WAVE_RADIUS:
			enemy.take_damage(FLAME_WAVE_DAMAGE)


@rpc("call_local")
func show_flame_wave() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.45, 0.1, 0.9)
	torus.material = material
	ring.mesh = torus
	ring.position.y = -0.4
	ring.scale = Vector3.ONE * 0.3
	add_child(ring)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3(FLAME_WAVE_RADIUS, 1.0, FLAME_WAVE_RADIUS), 0.35)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(ring.queue_free)
		
func _fire() -> void:
	fire_attack_spawner.spawn({
		"pos": marker_3d.global_position,
		"facing_dir": facing_dir
	})
	
func _spawn_fire_attack(data: Dictionary) -> Node:
	if not fire_attack_scene:
		return null
	var fire_inst: Node3D = fire_attack_scene.instantiate()
	fire_inst.direction = data.facing_dir
	fire_inst.position = data.pos
	fire_inst.set_multiplayer_authority(get_multiplayer_authority())
	return fire_inst
