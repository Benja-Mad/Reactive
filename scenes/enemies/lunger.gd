class_name Lunger
extends Enemy
## Fija el rumbo y carga las pinzas antes de embestir en línea recta.

enum State { CHASE, WINDUP, LUNGE, RECOVER, STALLED }

const CHASE_SPEED: float = 2.2
const WINDUP_DISTANCE: float = 3.2
const WINDUP_TIME: float = 0.6
const LUNGE_SPEED: float = 9.0
const LUNGE_TIME: float = 0.35
const LUNGE_DAMAGE: int = 40
const HIT_RANGE: float = 1.1
const RECOVER_TIME: float = 1.2
const STALL_TIME: float = 1.85

var state: State = State.CHASE
var state_time: float = 0.0
var lunge_dir: Vector3 = Vector3.ZERO
var has_hit: bool = false
var stall_pose: Tween


func is_stalled() -> bool:
	return stall_pose != null and not dying


func _physics_process(delta: float) -> void:
	_tick_slow(delta)
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	state_time -= delta
	var move := Vector3.ZERO
	var charging := state == State.LUNGE
	match state:
		State.CHASE:
			var target := _nearest_player()
			if target != null:
				var to_target := target.global_position - global_position
				to_target.y = 0.0
				if to_target.length() <= WINDUP_DISTANCE:
					lunge_dir = to_target.normalized() if to_target.length() > 0.01 else Vector3.FORWARD
					_set_state(State.WINDUP, WINDUP_TIME)
				else:
					move = to_target.normalized() * CHASE_SPEED * speed_scale()
		State.WINDUP:
			if state_time <= 0.0:
				has_hit = false
				_set_state(State.LUNGE, LUNGE_TIME)
		State.LUNGE:
			move = lunge_dir * LUNGE_SPEED * speed_scale()
		State.RECOVER, State.STALLED:
			if state_time <= 0.0:
				_set_state(State.CHASE, 0.0)

	velocity.x = move.x
	velocity.z = move.z
	move_and_slide()
	if charging:
		_resolve_charge()


func _resolve_charge() -> void:
	for i in get_slide_collision_count():
		var contact := get_slide_collision(i)
		var obstacle := contact.get_collider()
		if not (obstacle is StaticBody3D or obstacle is Enemy):
			continue
		if contact.get_normal().dot(lunge_dir) > -0.60:
			continue
		_set_state(State.STALLED, STALL_TIME)
		show_crash.rpc(contact.get_position().lerp(global_position, .25) + Vector3.UP * .24)
		if obstacle is Enemy and not obstacle.dying:
			obstacle.take_damage(LUNGE_DAMAGE)
		return
	_hit_players()
	if state_time <= 0.0:
		_set_state(State.RECOVER, RECOVER_TIME)


func _hit_players() -> void:
	if has_hit:
		return
	for node in get_tree().get_nodes_in_group("players"):
		var player := node as Character
		if player == null or player.is_dead:
			continue
		if player.global_position.distance_to(global_position) <= HIT_RANGE:
			player.take_damage(LUNGE_DAMAGE)
			has_hit = true
			return


func _set_state(new_state: State, duration: float) -> void:
	var was_stalled := state == State.STALLED
	state = new_state
	state_time = duration
	# Only a charging shell can collide with the other dock workers (layer 2).
	set_collision_mask_value(2, state == State.LUNGE)
	if new_state == State.WINDUP:
		brace_claws.rpc(lunge_dir)
	elif new_state == State.LUNGE:
		launch.rpc(lunge_dir)
	elif new_state == State.RECOVER or was_stalled:
		end_lunge_pose.rpc()


@rpc("call_local", "reliable")
func brace_claws(direction: Vector3) -> void:
	begin_windup(direction, WINDUP_TIME, preload("res://materials/combat/clutch.wav"))


@rpc("authority", "call_local", "reliable")
func launch(direction: Vector3) -> void:
	stop_windup()
	if dying:
		return
	visual.frame_coords = Vector2i(sprite_heading, STRIKE_ROW)
	# Exhaust stays at the push-off point as the claws travel forward.
	var plume := Sprite3D.new()
	plume.texture = preload("res://materials/combat/pressure_release.png")
	plume.hframes = 9
	plume.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plume.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	plume.pixel_size = .044
	plume.modulate = Color(.67, .75, .74, .54)
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plume.flip_h = sprite_heading > 4
	get_tree().current_scene.add_child(plume)
	plume.global_position = global_position - direction * .80 + Vector3.UP * .06
	CombatFeedback.play_frames(plume, .36)
	CombatFeedback.sound(self, preload("res://materials/combat/slice.wav"), -10.0)


@rpc("authority", "call_local", "reliable")
func show_crash(contact: Vector3) -> void:
	if dying:
		return
	var sparks := Sprite3D.new()
	sparks.texture = preload("res://materials/combat/shell_clang.png")
	sparks.hframes = 13
	sparks.pixel_size = .056
	sparks.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sparks.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.flip_h = sprite_heading in [1, 2, 3]
	get_tree().current_scene.add_child(sparks)
	sparks.global_position = contact
	CombatFeedback.play_frames(sparks, .46)
	CombatFeedback.sound(self, preload("res://materials/combat/shell_clang.wav"), -5.5)
	_set_attack_pose(0)
	var kick := -sin(sprite_heading * PI / 4.0)
	visual.offset = Vector2(12 * kick, 4)
	stall_pose = visual.create_tween()
	stall_pose.tween_property(visual, "offset", Vector2(3 * kick, -10), .13)
	stall_pose.tween_interval(STALL_TIME - .43)
	stall_pose.tween_property(visual, "offset", Vector2.ZERO, .30)


@rpc("authority", "call_local", "reliable")
func end_lunge_pose() -> void:
	if dying:
		return
	if stall_pose:
		stall_pose.kill()
		stall_pose = null
	visual.offset = Vector2.ZERO
	pose_locked = false
	visual.frame = sprite_heading
