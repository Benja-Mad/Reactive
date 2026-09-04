extends Area3D

@export var speed : float = 10.0
@export var damage: float = 5.0

var direction : Vector3

func _ready() -> void:
	await get_tree().create_timer(3).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position = global_position + speed * direction * delta
