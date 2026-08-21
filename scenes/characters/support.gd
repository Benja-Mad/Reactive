extends CharacterBody3D


const SPEED = 3.5
const JUMP_VELOCITY = 3.0
@onready var animated_sprite_3d: AnimatedSprite3D = $AnimatedSprite3D


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		animated_sprite_3d.play("Walk")
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		animated_sprite_3d.play("Idle")
		velocity.x = 0
		velocity.z = 0

	move_and_slide()
	
	if abs(velocity.x) > 0.1:
		animated_sprite_3d.flip_h = velocity.x < 0
	
