## Raya de lluvia (picado): a drowned bay ray that swims in the rain. It circles out of the flame's reach -- harmless, its shadow
## always on the ground -- then hovers, locks a lane through an operator, and dives along it.
## Only the dive hurts. Afterwards it skids to a stop and lies open until it can climb again.
## Steam rising under it knocks it out of the air, and a gravity well drags it down to its lip;
## a dive into an ice wall ends against the wall.
extends "res://scripts/survivor/enemy.gd"
const Telegraph = preload("res://scripts/survivor/telegraph.gd")
const ALTITUDE: float = 3.4
const ORBIT: float = 6.5
const LOCK: float = 0.95
const DIVE: float = 0.62
const GROUNDED: float = 1.7
const DAZED: float = 2.8
const CLIMB: float = 0.8
const LANE_WIDTH: float = 1.3
const OVERSHOOT: float = 3.5
const LENS := Color("ff3b6b")
var orbit_angle: float = 0.0
var orbit_turn: float = 1.0
var circle_for: float = 3.0
var ground_y: float = 0.05
var _ground_in: float = 0.0
var hit_this_dive: bool = false
var card: Node3D
var shadow: Node3D

func _capsule() -> Vector2:
	return Vector2(0.4, 0.7)
func _base_color() -> Color:
	return Color("2c2733")
func airborne() -> bool:
	return state in ["", "lock", "climb"]

func _ready() -> void:
	super()
	ground_y = position.y
	position.y = ground_y + ALTITUDE
	target_position = position
	orbit_turn = 1.0 if int(str(name).trim_prefix("Machine")) % 2 == 0 else -1.0
	circle_for = 2.6 + float(int(str(name).trim_prefix("Machine")) % 5) * 0.35
	# Flyers never shove walkers or each other; they still answer rays and blasts.
	collision_mask = 1
	shadow = Telegraph.shadow(effects_parent(), 0.7)

## The rain ray: its art on the crew's card, drawn from five headings and mirrored for the rest.
func _build(_dark: Material) -> void:
	card = preload("res://scripts/survivor/enemy_card.gd").new()
	card.name = "Art"
	add_child(card)
	card.setup("res://materials/enemies/raya/frames.tres", true)

func _behave(delta: float, target: Character) -> void:
	_ground_in -= delta
	if _ground_in <= 0.0 and state in ["", "lock"]:
		_ground_in = 0.3
		var below: Dictionary = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position, global_position - Vector3.UP * 8.0, 1))
		if not below.is_empty() and below.normal.y > 0.8: ground_y = below.position.y
	match state:
		"":
			if _in_updraft():
				_knock_down()
				return
			orbit_angle += delta * speed / ORBIT * orbit_turn
			var goal: Vector3 = target.global_position + Vector3(cos(orbit_angle), 0, sin(orbit_angle)) * ORBIT
			goal.y = ground_y + ALTITUDE
			var step: Vector3 = (goal - global_position).limit_length(delta * speed * 1.5)
			global_position += step
			velocity = step / maxf(delta, 0.001)
			var gap: Vector3 = target.global_position - global_position
			gap.y = 0
			if state_time > circle_for and gap.length() < ORBIT + 3.0:
				# The lane runs from below the drone, through the operator, and past them.
				var start := Vector3(global_position.x, ground_y, global_position.z)
				var through: Vector3 = Vector3(target.global_position.x, ground_y, target.global_position.z)
				var finish: Vector3 = through + (through - start).normalized() * OVERSHOOT
				set_state("lock", start, finish)
		"lock":
			if _in_updraft():
				_knock_down()
				return
			velocity = (state_to - state_from).normalized() * 0.01
			if state_time >= LOCK:
				hit_this_dive = false
				set_state("dive", global_position, state_to)
		"dive":
			var before: Vector3 = global_position
			var after: Vector3 = dive_point(state_time / DIVE)
			var ray := PhysicsRayQueryParameters3D.create(before, after, 1)
			ray.exclude = [get_rid()]
			var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and hit.normal.y < 0.7:
				# Nose first into a wall: an ice wall takes the blow and shatters, the drone is dazed.
				if hit.collider.is_in_group("matter_constructs"): hit.collider.take_damage(30.0)
				global_position = hit.position - (after - before).normalized() * 0.5
				take_damage(6.0)
				if not down: set_state("grounded", global_position, Vector3(global_position.x, ground_y + 0.05, global_position.z), 1.0)
				return
			global_position = after
			velocity = (after - before) / maxf(delta, 0.001)
			if not hit_this_dive and global_position.y < ground_y + 1.6:
				for player: Character in players_near(global_position, 1.0):
					player.receive_health.rpc(-12.0)
					player.knock.rpc(Vector3(velocity.x, 0, velocity.z).normalized() * 3.5)
					hit_this_dive = true
			if state_time >= DIVE:
				set_state("grounded", global_position, Vector3(state_to.x, ground_y + 0.05, state_to.z), 0.0)
		"grounded":
			velocity = Vector3.ZERO
			global_position = global_position.move_toward(state_to, delta * 12.0)
			if state_time >= (DAZED if state_value > 0.5 else GROUNDED):
				set_state("climb", global_position, Vector3(global_position.x, ground_y + ALTITUDE, global_position.z))
		"climb":
			global_position = state_from.lerp(state_to, ease(clampf(state_time / CLIMB, 0, 1), 0.5))
			velocity = Vector3.ZERO
			if state_time >= CLIMB:
				orbit_angle = atan2(global_position.z - target.global_position.z, global_position.x - target.global_position.x)
				set_state("")

## Committed dive, identical on every peer: drops from the hover to skimming height within the
## first half of the lane, then rakes the rest of it at knee height.
func dive_point(t: float) -> Vector3:
	t = clampf(t, 0.0, 1.0)
	var flat: Vector3 = Vector3(state_from.x, 0, state_from.z).lerp(Vector3(state_to.x, 0, state_to.z), t)
	var skim: float = state_to.y + 0.45
	flat.y = lerpf(state_from.y, skim, smoothstep(0.0, 0.45, t))
	return flat

## Hot vapour under the drone throws it out of the sky.
func _in_updraft() -> bool:
	for record: Dictionary in run.world.records.values():
		if record["material"] == "steam" and Vector2(record["position"].x - global_position.x, record["position"].z - global_position.z).length() < 2.6:
			return true
	return false
func _knock_down() -> void:
	take_damage(5.0)
	if not down: set_state("grounded", global_position, Vector3(global_position.x, ground_y + 0.05, global_position.z), 1.0)

## A well beneath it drags it out of the sky: no burn like the steam's, but it comes down at the
## lip of the well, dazed and open, and lies there as long as a knocked-down ray.
func pulled(field: String, at: Vector3) -> bool:
	if field != "well" or not airborne(): return false
	var flat := Vector3(at.x - global_position.x, 0.0, at.z - global_position.z)
	var landing: Vector3 = global_position + flat - flat.normalized() * minf(flat.length(), 1.0)
	landing.y = ground_y + 0.5
	# Never into the matter it is pulled toward: an ice wall well stops it at its face.
	var ray := PhysicsRayQueryParameters3D.create(Vector3(global_position.x, landing.y, global_position.z), landing, 1)
	ray.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty(): landing = hit.position - flat.normalized() * 0.5
	set_state("grounded", global_position, Vector3(landing.x, ground_y + 0.05, landing.z), 1.0)
	return true

func _client_motion(delta: float) -> void:
	if state == "dive": global_position = dive_point(state_time / DIVE)
	elif state == "climb": global_position = state_from.lerp(state_to, ease(clampf(state_time / CLIMB, 0, 1), 0.5))
	else: super(delta)

func _on_state() -> void:
	exposure = 1.6 if state == "grounded" else 1.0
	match state:
		"lock":
			mark(Telegraph.lane(effects_parent(), state_from, state_to, LANE_WIDTH))
		"dive":
			target_position = state_to
			# Keep the lane under the dive so the hit reads as the one that was promised.
			mark(Telegraph.lane(effects_parent(), Vector3(state_from.x, state_to.y, state_from.z), state_to, LANE_WIDTH))
		"grounded":
			target_position = state_to
			preload("res://scenes/actions/combat_fx.gd").burst(effects_parent(), state_from, LENS)
			# Where it comes down: under it, or at the lip of the well that pulled it.
			preload("res://scenes/actions/combat_fx.gd").ripple(effects_parent(), state_to, Color("ff3b6b"), LANE_WIDTH, 0.3)
		"climb":
			target_position = state_to

func _exit_tree() -> void:
	super()
	if is_instance_valid(shadow): shadow.queue_free()

func _process(delta: float) -> void:
	super(delta)
	if card == null: return
	card.hit_flash(flash > 0.0)
	match state:
		"lock":
			card.play("Lock")
			card.aim(state_to - state_from)
			if not marks.is_empty(): Telegraph.fill(marks[0], state_time / (LOCK + DIVE * 0.5))
		"dive":
			card.play("Dive")
			card.aim(state_to - state_from)
			if not marks.is_empty(): Telegraph.fill(marks[0], 1.0)
		"grounded":
			card.play("Grounded")
		_:
			card.play("Glide")
	# A slow swim through the air while it circles; still when it is down.
	card.position.y = sin(age * 2.6) * 0.12 if airborne() else 0.0
	if is_instance_valid(shadow):
		shadow.visible = state != "grounded"
		shadow.global_position = Vector3(global_position.x, ground_y + 0.04, global_position.z)
		var height: float = clampf((global_position.y - ground_y) / ALTITUDE, 0.0, 1.2)
		shadow.scale = Vector3.ONE * lerpf(1.3, 0.85, height)
