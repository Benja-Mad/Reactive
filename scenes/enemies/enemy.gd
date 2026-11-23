class_name Enemy
extends CharacterBody3D

const BLADE_WINDUP := 0.58
const BLADE_REACH := 1.7
const BRACE_ROW := 9
const STRIKE_ROW := 10
const READY_ROW := 11
const GLINT_ROW := 12
const PEAK_GLINT_ROW := 13
const SPEED: float = 2.5
const ATTACK_RANGE: float = 1.5
const ATTACK_DAMAGE: int = 75
const ATTACK_COOLDOWN: float = 1.0
const SLOW_FACTOR: float = 0.4
const SLOW_TINT := Color(0.45, 0.75, 1.0)

@export var maxHealth: int = 30
var currentHealth: int
var attack_timer: float = 0.0
## Segundos que le quedan frenado por hielo; corre en todos los peers para el tinte.
var slow_time: float = 0.0
@onready var visual: Sprite3D = $Visual
var sprite_heading := 1
var pose_locked := false
var last_visual_position: Vector3
var stride_phase := 0.0
var time_since_step := 0.0

var windup_animation: Tween
var windup_voice: AudioStreamPlayer3D
var strike_dir := Vector3.FORWARD
var windup_remaining := 0.0
var dying := false
var reaction: Tween
var visual_home: Vector3


func _ready() -> void:
	add_to_group("enemies")
	currentHealth = maxHealth
	last_visual_position = global_position
	visual.frame = sprite_heading
	visual_home = visual.position


# Derive the cosmetic stride from actual displacement, also on replicated peers.
func _process(delta: float) -> void:
	var step := global_position - last_visual_position
	last_visual_position = global_position
	if pose_locked or dying:
		return
	var planar := Vector2(step.x, step.z)
	if planar.length_squared() > 0.000001:
		time_since_step = 0.0
		sprite_heading = SpriteHeading.from_motion(step.x, step.z, get_viewport().get_camera_3d())
		stride_phase = fmod(stride_phase + planar.length() * 6.4, 8.0)
		visual.frame = (1 + int(stride_phase)) * visual.hframes + sprite_heading
	else:
		time_since_step += delta
		if time_since_step > 0.12:
			visual.frame = sprite_heading


func _physics_process(delta: float) -> void:
	_tick_slow(delta)
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	velocity.x = 0.0
	velocity.z = 0.0
	attack_timer = maxf(0.0, attack_timer - delta)
	if windup_remaining > 0.0:
		windup_remaining -= delta
		if windup_remaining <= 0.0:
			attack_timer = ATTACK_COOLDOWN
			release_blade.rpc()
			for player: Character in get_tree().get_nodes_in_group("players"):
				var offset := player.global_position - global_position
				if player.is_dead or absf(offset.y) > 1.2:
					continue
				offset.y = 0.0
				if offset.length() <= BLADE_REACH and (offset.is_zero_approx() or offset.normalized().dot(strike_dir) >= 0.5):
					player.take_damage(ATTACK_DAMAGE)
	else:
		var target := _nearest_player()
		if target:
			var offset := target.global_position - global_position
			offset.y = 0.0
			if offset.length() > ATTACK_RANGE:
				var walk := offset.normalized() * SPEED * speed_scale()
				velocity.x = walk.x
				velocity.z = walk.z
			elif attack_timer <= 0.0:
				strike_dir = Vector3.FORWARD if offset.is_zero_approx() else offset.normalized()
				windup_remaining = BLADE_WINDUP
				show_blade_strike.rpc(strike_dir)

	move_and_slide()


@rpc("authority", "call_local", "reliable")
func show_blade_strike(direction: Vector3) -> void:
	begin_windup(direction, BLADE_WINDUP, preload("res://materials/combat/blade_charge.wav"))


func begin_windup(direction: Vector3, duration: float, cue: AudioStream) -> void:
	if dying:
		return
	stop_windup()
	sprite_heading = SpriteHeading.from_motion(direction.x, direction.z, get_viewport().get_camera_3d())
	pose_locked = true
	_set_attack_pose(BRACE_ROW)
	windup_voice = CombatFeedback.sound(self, cue, -7.5)
	windup_animation = visual.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	windup_animation.tween_callback(_set_attack_pose.bind(READY_ROW)).set_delay(duration * 0.27)
	windup_animation.tween_callback(_set_attack_pose.bind(GLINT_ROW)).set_delay(duration * 0.32)
	windup_animation.tween_callback(_set_attack_pose.bind(PEAK_GLINT_ROW)).set_delay(duration * 0.10)
	windup_animation.tween_callback(_set_attack_pose.bind(GLINT_ROW)).set_delay(duration * 0.22)


func _set_attack_pose(row: int) -> void:
	visual.frame_coords = Vector2i(sprite_heading, row)


func stop_windup() -> void:
	if windup_animation:
		windup_animation.kill()
		windup_animation = null
		if visual.frame_coords.y in [GLINT_ROW, PEAK_GLINT_ROW]:
			_set_attack_pose(READY_ROW)
	if is_instance_valid(windup_voice):
		windup_voice.queue_free()
		windup_voice = null


@rpc("authority", "call_local", "reliable")
func release_blade() -> void:
	stop_windup()
	if dying:
		return
	visual.frame_coords = Vector2i(sprite_heading, STRIKE_ROW)
	CombatFeedback.sound(self, preload("res://materials/combat/slice.wav"), -7.5)
	await get_tree().create_timer(0.23).timeout
	if dying:
		return
	pose_locked = false
	visual.frame = sprite_heading


func speed_scale() -> float:
	return SLOW_FACTOR if slow_time > 0.0 else 1.0


func _tick_slow(delta: float) -> void:
	if slow_time <= 0.0:
		return
	slow_time -= delta
	if slow_time <= 0.0:
		visual.modulate = Color.WHITE


func _nearest_player() -> Character:
	var nearest: Character = null
	var nearest_dist := INF
	for node in get_tree().get_nodes_in_group("players"):
		var player := node as Character
		if player == null or player.is_dead:
			continue
		var dist := global_position.distance_squared_to(player.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = player
	return nearest


func take_damage(amount: int, chill_seconds := 0.0) -> void:
	apply_damage.rpc_id(get_multiplayer_authority(), amount, chill_seconds)


@rpc("any_peer", "call_local", "reliable")
func apply_damage(amount: int, chill_seconds := 0.0) -> void:
	if not is_multiplayer_authority() or dying or amount <= 0:
		return
	var hp := maxi(0, currentHealth - amount)
	show_hit.rpc(hp, chill_seconds > 0.0, maxf(slow_time, chill_seconds))
	if hp == 0:
		await get_tree().create_timer(0.60).timeout
		queue_free()


@rpc("authority", "call_local", "reliable")
func show_hit(hp: int, ice_hit: bool, remaining_chill: float) -> void:
	if dying:
		return
	currentHealth = hp
	slow_time = remaining_chill
	dying = hp == 0
	if reaction:
		reaction.kill()
	visual.scale = Vector3.ONE
	visual.position = visual_home
	visual.modulate = Color(2.4, 2.25, 1.95)
	reaction = create_tween()
	if dying:
		remove_from_group("enemies")
		set_physics_process(false)
		$CollisionShape3D.set_deferred("disabled", true)
		stop_windup()
		$Footprint.hide()
		var parts := CombatFeedback.Burst.EJECT if self is Lunger else CombatFeedback.Burst.VENT
		var outlet := global_position + Vector3.UP * (0.65 if self is Lunger else 0.38)
		CombatFeedback.burst(self, parts, outlet, 3.15, 0.52)
		CombatFeedback.shed_part(self, $Footprint.global_position, self is Lunger)
		reaction.tween_interval(0.055)
		reaction.tween_property(visual, "modulate", Color(0.68, 0.84, 0.87), 0.06)
		reaction.set_parallel(true)
		reaction.tween_property(visual, "position:y", visual_home.y - 0.65, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		reaction.tween_property(visual, "scale", Vector3(1.10, 0.16, 1.0), 0.29)
		reaction.tween_property(visual, "modulate:a", 0.0, 0.18).set_delay(0.16)
	else:
		var contact := CombatFeedback.Burst.ICE_HIT if ice_hit else CombatFeedback.Burst.HIT
		CombatFeedback.burst(self, contact, global_position, 1.7, 0.19)
		visual.scale = Vector3(1.10, 0.92, 1.0)
		reaction.tween_property(visual, "scale", Vector3.ONE, 0.12)
		reaction.tween_callback(func() -> void: visual.modulate = SLOW_TINT if slow_time > 0 else Color.WHITE)
