class_name Character
extends CharacterBody3D

signal hp_changed


const SPEED: float = 3.5
const JUMP_VELOCITY: float = 3.0
var is_casting: bool = false
var is_dead: bool = false
@onready var animated_sprite_3d: AnimatedSprite3D = $AnimatedSprite3D
@onready var label_3d: Label3D = $Label3D
@onready var camera_3d: Camera3D = $Camera3D
@onready var input_synchronizer: InputSynchronizer = $InputSynchronizer
@onready var sync_timer: Timer = $SyncTimer
@onready var programming_block: CanvasLayer = $ProgrammingBlock

@export var maxHealth: int = 100
var currentHealth: int
@onready var health_bar: ProgressBar = get_node_or_null("Sprite3D/SubViewport/ProgressBar")

func _ready() -> void:
	sync_timer.timeout.connect(_on_sync_timeout)
	add_to_group("players")
	var player_data : Statics.PlayerData = Game.instance.get_player(get_multiplayer_authority())
	label_3d.text = player_data.name
	camera_3d.current = is_multiplayer_authority()
	currentHealth = maxHealth
	_update_health_bar()
	if is_multiplayer_authority():
		sync_timer.start()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# Handle jump.
	if input_synchronizer.jump and is_on_floor():
		velocity.y = JUMP_VELOCITY
		input_synchronizer.jump = false

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir: Vector2 = input_synchronizer.move_input
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		if not is_casting:
			animated_sprite_3d.play("Walk")
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		if not is_casting:
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
	
func use_ability(_ability: Statics.Ability) -> void:
	pass


func cast_animation(anim: StringName, duration: float) -> void:
	if not is_multiplayer_authority():
		return
	broadcast_cast.rpc(anim, duration)


@rpc("call_local")
func broadcast_cast(anim: StringName, duration: float) -> void:
	if is_casting:
		return
	is_casting = true
	animated_sprite_3d.play(anim)
	await get_tree().create_timer(duration).timeout
	is_casting = false


func trigger_particles(particles: GPUParticles3D) -> void:
	if particles == null:
		return
	if particles.one_shot:
		particles.restart()
	else:
		particles.emitting = true


func trigger_particles_all(node_path: NodePath) -> void:
	broadcast_particles.rpc(node_path)


@rpc("call_local")
func broadcast_particles(node_path: NodePath) -> void:
	trigger_particles(get_node_or_null(node_path))


func take_damage(amount: int) -> void:
	broadcast_damage.rpc(amount)


@rpc("any_peer", "call_local", "reliable")
func broadcast_damage(amount: int) -> void:
	if not is_multiplayer_authority():
		return
	currentHealth = maxi(0, currentHealth - amount)
	broadcast_hp.rpc(currentHealth)


func heal(amount: int) -> void:
	if not is_multiplayer_authority():
		return
	if currentHealth <= 0:
		return
	currentHealth = mini(maxHealth, currentHealth + amount)
	broadcast_hp.rpc(currentHealth)


@rpc("call_local")
func broadcast_hp(new_health: int) -> void:
	currentHealth = new_health
	is_dead = new_health <= 0
	_update_health_bar()
	hp_changed.emit()


func _update_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.max_value = maxHealth
	health_bar.value = currentHealth
