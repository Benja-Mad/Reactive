class_name Character
extends CharacterBody3D

const SPEED: float = 4.4
const JUMP_VELOCITY: float = 3.0

@onready var animated_sprite_3d: AnimatedSprite3D = $AnimatedSprite3D
@onready var label_3d: Label3D = $Label3D
@onready var camera_3d: Camera3D = $Camera3D
@onready var input_synchronizer: InputSynchronizer = $InputSynchronizer
@onready var sync_timer: Timer = $SyncTimer
@onready var programming_block: ProgrammingBlock = $ProgrammingBlock

var _health_component: HealthComponent
var _program_executor: ProgramExecutor
var _health_label: Label3D


func _ready() -> void:
	add_to_group(&"players")
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	sync_timer.timeout.connect(_on_sync_timeout)
	_health_component = HealthComponent.new()
	_health_component.name = "HealthComponent"
	add_child(_health_component)
	_health_component.health_changed.connect(_on_health_changed)
	_health_component.healed.connect(_on_healed)
	_program_executor = ProgramExecutor.new()
	_program_executor.name = "ProgramExecutor"
	add_child(_program_executor)
	_program_executor.setup(self)
	_build_health_label()
	animated_sprite_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	camera_3d.position = Vector3(0.0, 9.0, 10.0)
	camera_3d.rotation_degrees = Vector3(-38.0, 0.0, 0.0)
	camera_3d.fov = 44.0


func setup(player_data: Statics.PlayerData) -> void:
	label_3d.text = player_data.name
	set_multiplayer_authority(player_data.id)
	camera_3d.current = is_multiplayer_authority()
	programming_block.setup_for_character(self)
	if is_multiplayer_authority():
		sync_timer.start()


func setup_debug(player_name: String = "Debug Support") -> void:
	label_3d.text = player_name
	camera_3d.current = true
	programming_block.setup_for_character(self)


func get_health_component() -> HealthComponent:
	return _health_component


func get_program_executor() -> ProgramExecutor:
	return _program_executor


func execute_program_instruction(_instruction: ProgramInstruction, _target: Node3D) -> void:
	pass


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if input_synchronizer.jump and is_on_floor():
		velocity.y = JUMP_VELOCITY
		input_synchronizer.jump = false
	var input_dir: Vector2 = input_synchronizer.move_input
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if direction:
		animated_sprite_3d.play(&"Walk")
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		animated_sprite_3d.play(&"Idle")
		velocity.x = move_toward(velocity.x, 0.0, SPEED * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, SPEED * delta * 8.0)
	move_and_slide()
	if absf(velocity.x) > 0.1:
		animated_sprite_3d.flip_h = velocity.x < 0.0


func _build_health_label() -> void:
	_health_label = Label3D.new()
	_health_label.name = "HealthReadout"
	_health_label.position = Vector3(0.0, 1.13, 0.0)
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_label.font_size = 22
	_health_label.outline_size = 6
	_health_label.modulate = Color(0.45, 1.0, 0.65)
	add_child(_health_label)
	_on_health_changed(_health_component.current_health, _health_component.max_health)


func _on_health_changed(current: float, maximum: float) -> void:
	if _health_label == null:
		return
	_health_label.text = "%d / %d" % [int(current), int(maximum)]
	var ratio: float = current / maximum if maximum > 0.0 else 0.0
	_health_label.modulate = Color(1.0 - ratio * 0.55, 0.35 + ratio * 0.65, 0.35)


func _on_healed(_amount: float, _source: Node) -> void:
	animated_sprite_3d.modulate = Color(0.55, 1.35, 0.82)
	var flash: Tween = create_tween()
	flash.tween_property(animated_sprite_3d, "modulate", Color.WHITE, 0.4)


func _on_sync_timeout() -> void:
	_sync(global_position, velocity)


func _sync(pos: Vector3, vel: Vector3) -> void:
	global_position = global_position.lerp(pos, 0.5)
	velocity = velocity.lerp(vel, 0.5)
