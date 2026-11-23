extends Area3D

@export var speed : float = 10.0
@export var damage: int = 100
## Segundos que frena al enemigo al impactar (0 = no frena).
@export var slow_duration: float = 0.0

var direction : Vector3
var spent := false

func _ready() -> void:
	var flare := get_node_or_null("Flare") as Sprite3D
	if flare:
		flare.frame = SpriteHeading.from_motion(direction.x, direction.z, get_viewport().get_camera_3d())
	var muzzle := CombatFeedback.Burst.ICE_CAST if slow_duration > 0 else CombatFeedback.Burst.MUZZLE
	CombatFeedback.burst(self, muzzle, global_position + direction * 0.25, 1.20, 0.13)
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(3).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position = global_position + speed * direction * delta

func _on_body_entered(body: Node3D) -> void:
	if spent or not is_multiplayer_authority():
		return
	if not body.is_in_group("enemies"):
		return
	spent = true
	body.take_damage(damage, slow_duration)
	queue_free()
