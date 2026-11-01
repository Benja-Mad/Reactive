class_name Damage
extends Character

@export var fire_attack_scene : PackedScene
@onready var marker_3d: Marker3D = $Marker3D
@onready var fire_attack_spawner: MultiplayerSpawner = $FireAttackSpawner

var facing_dir: Vector3 = Vector3.RIGHT
var fire_cooldown: float = 0.0

func _ready() -> void:
	super._ready()
	fire_attack_spawner.spawn_function = _spawn_fire_attack


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if get_tree().get_first_node_in_group("survivor_run") != null: return
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	var input_dir: Vector2 = input_synchronizer.move_input
	var direction: Vector3 = (movement_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
	if input_synchronizer.aim_direction.length_squared() > 0.1:
		facing_dir = input_synchronizer.aim_direction
	elif direction.length() > 0:
		facing_dir = direction
	if is_multiplayer_authority() and Input.is_action_pressed("Fire") and not programming_block.code_block.has_focus():
		_fire()
			
func use_ability(ability: String) -> void:
	if not is_multiplayer_authority():
		return
		
	match ability:
		"fire":
			_fire()
		
func _fire() -> void:
	if fire_cooldown > 0.0:
		return
	# Soft target assistance within the facing hemisphere keeps F useful at diorama scale.
	var best_distance: float = 19.0
	# Judge every candidate against the player's own aim, not against a direction already
	# snapped to an earlier candidate, or group order decides which sentry gets shot.
	var aim: Vector3 = facing_dir
	var aim_cone: float = 0.94 if input_synchronizer.aim_direction.length_squared() > 0.1 else 0.15
	for enemy: Node3D in get_tree().get_nodes_in_group("yard_sentries"):
		if enemy.down:
			continue
		var difference: Vector3 = enemy.global_position - global_position
		difference.y = 0.0
		if difference.length() >= best_distance or difference.normalized().dot(aim) < aim_cone:
			continue
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.55, enemy.global_position + Vector3.UP * 1.1)
		query.exclude = [get_rid()]
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.collider == enemy:
			best_distance = difference.length()
			facing_dir = difference.normalized()
	fire_cooldown = 0.3
	fire_attack_spawner.spawn({
		"pos": global_position + Vector3.UP * 0.55 + facing_dir * 0.8,
		"facing_dir": facing_dir
	})
	
func _spawn_fire_attack(data: Dictionary) -> Node:
	if not fire_attack_scene:
		return null
	# Runs on every peer as the spawn replicates, so everyone sees the lance kick.
	play_action(&"Fire", 0.28)
	var fire_inst: Node3D = fire_attack_scene.instantiate()
	fire_inst.direction = data.facing_dir
	fire_inst.position = to_local(data.pos)
	fire_inst.set_multiplayer_authority(get_multiplayer_authority())
	return fire_inst
