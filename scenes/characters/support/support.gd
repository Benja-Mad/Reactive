class_name Support
extends Character

const HEAL_DURATION: float = 1.11
const HEAL_AMOUNT: int = 65

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
	heal(HEAL_AMOUNT)
