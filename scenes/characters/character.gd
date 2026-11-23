class_name Character
extends CharacterBody3D

signal hp_changed


const RESCUE_RANGE := 2.2
const RESCUE_TIME := 2.0
var rescue_elapsed := 0.0
var rescue_bar: Tween

const SPEED: float = 3.5
const JUMP_VELOCITY: float = 3.0
var sprite_heading: int = 2
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
		if is_multiplayer_authority():
			_tick_rescue(delta)
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
		sprite_heading = SpriteHeading.from_motion(direction.x, direction.z, get_viewport().get_camera_3d())
		if not is_casting:
			animated_sprite_3d.play("Walk_%d" % sprite_heading)
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		if not is_casting:
			animated_sprite_3d.play("Idle_%d" % sprite_heading)
		velocity.x = 0
		velocity.z = 0

	move_and_slide()
	

	
func _on_sync_timeout() -> void:
	if not multiplayer.get_peers().is_empty():
		_sync.rpc(global_position, velocity)
	
@rpc("authority", "call_remote", "unreliable_ordered")
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
	var pose := "%s_%d" % [anim, sprite_heading]
	if not animated_sprite_3d.sprite_frames.has_animation(pose):
		pose = "Idle_%d" % sprite_heading
	animated_sprite_3d.play(pose)
	if anim == &"Fire" or anim == &"Ice":
		var home := animated_sprite_3d.position
		var aim := Vector3(sin(sprite_heading * PI / 4.0), 0, cos(sprite_heading * PI / 4.0))
		animated_sprite_3d.position = home - aim * 0.13
		var recoil := animated_sprite_3d.create_tween()
		recoil.tween_property(animated_sprite_3d, "position", home, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if anim == &"Heal":
		var glow := create_tween()
		glow.tween_property(animated_sprite_3d, "modulate", Color(1.35, 1.8, 1.65), duration * 0.25)
		glow.tween_property(animated_sprite_3d, "modulate", Color.WHITE, duration * 0.75)
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
	broadcast_hp.rpc(maxi(0, currentHealth - amount))


func heal(amount: int) -> void:
	if not is_multiplayer_authority():
		return
	if currentHealth <= 0:
		return
	broadcast_hp.rpc(mini(maxHealth, currentHealth + amount))


## Curación pedida por otro peer (p. ej. Support curando a un aliado); la aplica el dueño.
@rpc("any_peer", "call_local", "reliable")
func receive_heal(amount: int) -> void:
	heal(amount)


@rpc("authority", "call_local", "reliable")
func broadcast_hp(new_health: int) -> void:
	if new_health == currentHealth:
		return
	var was_down := is_dead
	if new_health < currentHealth:
		CombatFeedback.burst(self, CombatFeedback.Burst.HIT, global_position, 1.55, 0.18)
	elif new_health > currentHealth:
		CombatFeedback.burst(self, CombatFeedback.Burst.HEAL, global_position + Vector3.UP * 0.6, 2.35, 0.55)
	currentHealth = new_health
	is_dead = new_health <= 0
	if was_down or is_dead:
		rescue_elapsed = 0.0
		show_rescue(false)
		if is_dead:
			animated_sprite_3d.play("Idle_%d" % sprite_heading)
			animated_sprite_3d.pause()
		animated_sprite_3d.modulate = Color(.49, .61, .67) if is_dead else Color.WHITE
	_update_health_bar()
	hp_changed.emit()


func _tick_rescue(delta: float) -> void:
	for ally: Character in get_tree().get_nodes_in_group("players"):
		if ally == self or ally.is_dead or global_position.distance_squared_to(ally.global_position) > RESCUE_RANGE * RESCUE_RANGE:
			continue
		if rescue_elapsed == 0.0:
			show_rescue.rpc(true)
		rescue_elapsed += delta
		if rescue_elapsed >= RESCUE_TIME:
			broadcast_hp.rpc(ceili(maxHealth * .35))
		return
	if rescue_elapsed > 0.0:
		rescue_elapsed = 0.0
		show_rescue.rpc(false)


@rpc("authority", "call_local", "reliable")
func show_rescue(active: bool) -> void:
	if rescue_bar:
		rescue_bar.kill()
	var player_name: String = Game.instance.get_player(get_multiplayer_authority()).name
	label_3d.text = player_name
	if is_dead:
		label_3d.text += " · RESTART" if active else " · SOS"
	_update_health_bar()
	if active and health_bar:
		rescue_bar = health_bar.create_tween()
		rescue_bar.tween_property(health_bar, "value", health_bar.max_value, RESCUE_TIME)


func _update_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.max_value = maxHealth
	health_bar.value = currentHealth
