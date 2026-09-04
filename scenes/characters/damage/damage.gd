class_name Damage
extends Character

@export var fire_attack_scene : PackedScene
@onready var marker_3d: Marker3D = $Marker3D
@onready var fire_attack_spawner: MultiplayerSpawner = $FireAttackSpawner

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
			
func use_ability(ability: String) -> void:
	if not is_multiplayer_authority():
		return
		
	match ability:
		"fire":
			_fire()
		
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
