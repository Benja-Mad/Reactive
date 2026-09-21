class_name Character
extends CharacterBody3D


const SPEED: float = 3.5
const JUMP_VELOCITY: float = 3.0

## Horizontal frame the movement input is expressed in. A diorama arena sets this from its
## approved camera so "up" walks into the screen rather than along world -Z, which is what the
## world-aligned default would do under a camera yawed 35 degrees. Identity keeps the old
## behaviour for any scene that does not set it.
static var movement_basis: Basis = Basis.IDENTITY
## Cleared by an arena that owns the framing itself, so a fixed diorama camera is not fighting
## one camera per player for which is current.
@export var use_own_camera: bool = true
var health: float = 100.0
var respawn_position: Vector3
var coyote_time: float = 0.0
var jump_buffer: float = 0.0
@onready var animated_sprite_3d: AnimatedSprite3D = $AnimatedSprite3D
@onready var label_3d: Label3D = $Label3D
@onready var camera_3d: Camera3D = $Camera3D
@onready var input_synchronizer: InputSynchronizer = $InputSynchronizer
@onready var sync_timer: Timer = $SyncTimer
@onready var programming_block: CanvasLayer = $ProgrammingBlock


func _ready() -> void:
	add_to_group("coop_players")
	respawn_position = global_position
	sync_timer.timeout.connect(_on_sync_timeout)
	var player_data : Statics.PlayerData = Game.instance.get_player(get_multiplayer_authority())
	label_3d.text = player_data.name
	camera_3d.current = use_own_camera and is_multiplayer_authority()
	if is_multiplayer_authority():
		sync_timer.start()


func _physics_process(delta: float) -> void:
	if programming_block.get_node("CodeBlock").has_focus():
		input_synchronizer.move_input = Vector2.ZERO
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	coyote_time = 0.10 if is_on_floor() else maxf(0.0, coyote_time - delta)
	jump_buffer = maxf(0.0, jump_buffer - delta)
	if input_synchronizer.jump:
		jump_buffer = 0.14
		input_synchronizer.jump = false
	if jump_buffer > 0.0 and coyote_time > 0.0:
		velocity.y = JUMP_VELOCITY
		coyote_time = 0.0
		jump_buffer = 0.0

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir: Vector2 = input_synchronizer.move_input
	var direction: Vector3 = (movement_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		animated_sprite_3d.play("Walk")
		velocity.x = move_toward(velocity.x, direction.x * SPEED, delta * 22.0)
		velocity.z = move_toward(velocity.z, direction.z * SPEED, delta * 22.0)
	else:
		animated_sprite_3d.play("Idle")
		velocity.x = move_toward(velocity.x, 0.0, delta * 28.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 28.0)

	move_and_slide()
	
	# Flip on the camera's screen-right, not on world X: under a yawed diorama camera those are
	# different axes and the sprite would face the wrong way while walking.
	var screen_right: float = Vector3(velocity.x, 0.0, velocity.z).dot(movement_basis.x)
	if absf(screen_right) > 0.1:
		animated_sprite_3d.flip_h = screen_right < 0.0
	
func _on_sync_timeout() -> void:
	_sync.rpc(global_position, velocity)
	
@rpc("authority", "call_remote", "unreliable_ordered")
func _sync(pos: Vector3, vel: Vector3) -> void:
	global_position = pos if global_position.distance_to(pos) > 3.0 else global_position.lerp(pos, 0.5)
	velocity = velocity.lerp(vel, 0.5)
	
func use_ability(ability: String) -> void:
	return


@rpc("any_peer", "call_local", "reliable")
func receive_health(amount: float) -> void:
	# Only the host resolves combat; each player retains movement authority.
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	var applied: float = clampf(health + amount, 0.0, 100.0) - health
	if not is_zero_approx(applied):
		var color := Color(0.1, 1, 0.85) if applied > 0 else Color(1, 0.25, 0.18)
		preload("res://scenes/actions/combat_fx.gd").number(get_tree().current_scene, global_position + Vector3.UP * 1.8, ("+" if applied > 0 else "") + str(int(applied)), color)
	health = clampf(health + amount, 0.0, 100.0)
	if health <= 0.0:
		preload("res://scenes/actions/combat_fx.gd").burst(get_tree().current_scene, global_position, Color(0.15, 0.85, 1.0))
		health = 100.0
		if is_multiplayer_authority():
			global_position = respawn_position + Vector3.UP * 0.6
			velocity = Vector3.ZERO
			_sync.rpc(global_position, velocity)
