class_name Lunger
extends Enemy
## Enemigo secundario: se acerca, se detiene marcando en el suelo hacia dónde va a saltar
## y recién entonces embiste en línea recta. Esquivable si se lee la marca.

enum State { CHASE, WINDUP, LUNGE, RECOVER }

const CHASE_SPEED: float = 2.2
const WINDUP_DISTANCE: float = 3.2
const WINDUP_TIME: float = 0.6
const LUNGE_SPEED: float = 9.0
const LUNGE_TIME: float = 0.35
const LUNGE_DAMAGE: int = 40
const HIT_RANGE: float = 1.1
const RECOVER_TIME: float = 1.2

var state: State = State.CHASE
var state_time: float = 0.0
var lunge_dir: Vector3 = Vector3.ZERO
var has_hit: bool = false
var warning: MeshInstance3D
var _last_x: float = 0.0
@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D


func _ready() -> void:
	super._ready()
	warning = MeshInstance3D.new()
	var strip := BoxMesh.new()
	var length := LUNGE_SPEED * LUNGE_TIME
	strip.size = Vector3(0.5, 0.02, length)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.15, 0.1, 0.55)
	strip.material = material
	warning.mesh = strip
	warning.top_level = true
	warning.visible = false
	add_child(warning)
	_last_x = global_position.x


func _physics_process(delta: float) -> void:
	_tick_slow(delta)
	# El arte mira a la derecha; se voltea según hacia dónde se movió (también en clientes).
	var dx := global_position.x - _last_x
	_last_x = global_position.x
	if absf(dx) > 0.001:
		sprite.flip_h = dx < 0.0
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	state_time -= delta
	var target := _nearest_player()
	var move := Vector3.ZERO
	match state:
		State.CHASE:
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
			_hit_players()
			if state_time <= 0.0:
				_set_state(State.RECOVER, RECOVER_TIME)
		State.RECOVER:
			if state_time <= 0.0:
				_set_state(State.CHASE, 0.0)

	velocity.x = move.x
	velocity.z = move.z
	move_and_slide()


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
	state = new_state
	state_time = duration
	var animation: StringName = [&"Run", &"Bare", &"Lunge", &"Idle"][new_state]
	play_animation.rpc(animation)
	if new_state == State.WINDUP:
		show_warning.rpc(global_position, lunge_dir)
	elif new_state == State.LUNGE:
		hide_warning.rpc()


@rpc("call_local", "reliable")
func play_animation(animation: StringName) -> void:
	sprite.play(animation)


@rpc("call_local", "reliable")
func show_warning(from: Vector3, dir: Vector3) -> void:
	var length := LUNGE_SPEED * LUNGE_TIME
	warning.global_transform = Transform3D(Basis.looking_at(dir), Vector3(from.x, from.y - 0.9, from.z) + dir * length * 0.5)
	warning.visible = true


@rpc("call_local", "reliable")
func hide_warning() -> void:
	warning.visible = false
