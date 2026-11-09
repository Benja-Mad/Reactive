class_name Support
extends Character

const HEAL_DURATION: float = 1.11
const HEAL_AMOUNT: int = 65
const HEAL_RANGE: float = 6.0

@export var ice_shard_scene: PackedScene
@onready var marker_3d: Marker3D = $Marker3D
@onready var ice_shard_spawner: MultiplayerSpawner = $IceShardSpawner

var facing_dir: Vector3 = Vector3.RIGHT


func _ready() -> void:
	super._ready()
	ice_shard_spawner.spawn_function = _spawn_ice_shard


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
		Statics.Ability.ICE_SHARD:
			_ice_shard()
		Statics.Ability.HEAL:
			_heal()


func _ice_shard() -> void:
	ice_shard_spawner.spawn({
		"pos": marker_3d.global_position,
		"facing_dir": facing_dir
	})


func _spawn_ice_shard(data: Dictionary) -> Node:
	var scene := ice_shard_scene
	if scene == null:
		scene = load("res://scenes/abilities/ice_shard.tscn")
	if scene == null:
		return null
	var shard_inst: Node3D = scene.instantiate()
	shard_inst.direction = data.facing_dir
	shard_inst.position = data.pos
	shard_inst.set_multiplayer_authority(get_multiplayer_authority())
	return shard_inst


func _heal() -> void:
	trigger_particles_all(^"HealParticles")
	cast_animation(&"Heal", HEAL_DURATION)
	heal_target().receive_heal.rpc(HEAL_AMOUNT)


## El jugador vivo más herido (en %) dentro del alcance; ante empate, uno mismo.
func heal_target() -> Character:
	var best: Character = self
	var best_ratio := float(currentHealth) / float(maxHealth)
	for node in get_tree().get_nodes_in_group("players"):
		var player := node as Character
		if player == null or player == self or player.is_dead:
			continue
		if player.global_position.distance_to(global_position) > HEAL_RANGE:
			continue
		var ratio := float(player.currentHealth) / float(player.maxHealth)
		if ratio < best_ratio:
			best = player
			best_ratio = ratio
	return best
