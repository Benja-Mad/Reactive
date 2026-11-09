extends Area3D

@export var speed : float = 10.0
@export var damage: int = 100
## Segundos que frena al enemigo al impactar (0 = no frena).
@export var slow_duration: float = 0.0

var direction : Vector3

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(3).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position = global_position + speed * direction * delta

func _on_body_entered(body: Node3D) -> void:
	if not is_multiplayer_authority():
		return
	if not body.is_in_group("enemies"):
		return
	body.take_damage(damage)
	if slow_duration > 0.0 and body.has_method("apply_slow"):
		body.apply_slow(slow_duration)
	queue_free()
