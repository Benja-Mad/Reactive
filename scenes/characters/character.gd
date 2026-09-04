class_name Character
extends CharacterBody3D


const SPEED: float = 3.5
const JUMP_VELOCITY: float = 3.0
@onready var animated_sprite_3d: AnimatedSprite3D = $AnimatedSprite3D
@onready var label_3d: Label3D = $Label3D
@onready var camera_3d: Camera3D = $Camera3D
@onready var input_synchronizer: InputSynchronizer = $InputSynchronizer
@onready var sync_timer: Timer = $SyncTimer
@onready var programming_block: CanvasLayer = $ProgrammingBlock


func _ready() -> void:
	sync_timer.timeout.connect(_on_sync_timeout)
	var player_data : Statics.PlayerData = Game.instance.get_player(get_multiplayer_authority())
	label_3d.text = player_data.name
	camera_3d.current = is_multiplayer_authority()
	if is_multiplayer_authority():
		sync_timer.start()


func _physics_process(delta: float) -> void:
	if programming_block.get_node("CodeBlock").has_focus():
		return
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if input_synchronizer.jump and is_on_floor():
		velocity.y = JUMP_VELOCITY
		input_synchronizer.jump = false

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir: Vector2 = input_synchronizer.move_input
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
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
	
func _on_sync_timeout() -> void:
	_sync(global_position, velocity)
	
func _sync(pos: Vector3, vel: Vector3) -> void:
	global_position = global_position.lerp(pos, 0.5)
	velocity = velocity.lerp(vel, 0.5)
	
func use_ability(ability: String) -> void:
	return
