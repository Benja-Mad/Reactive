extends StaticBody3D
var health: float = 100.0
func _ready() -> void:
	add_to_group("matter_damageable")
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.6
	shape.height = 2.0
	collision.shape = shape
	collision.position.y = 1.0
	add_child(collision)
func take_damage(amount: float) -> void:
	if multiplayer.is_server(): health -= amount
