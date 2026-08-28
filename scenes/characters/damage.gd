class_name Damage
extends Character

@export var fire_attack_scene : PackedScene
@onready var marker_3d: Marker3D = $Marker3D

var facing_dir: Vector3

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var input_dir: Vector2 = input_synchronizer.move_input
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
	if direction.length() > 0:
		facing_dir = direction
			
	if Input.is_action_just_pressed("Fire"):
		var attack_inst = fire_attack_scene.instantiate()
		attack_inst.direction = facing_dir
		attack_inst.global_position = marker_3d.global_position
		get_parent().add_child(attack_inst)
