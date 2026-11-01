## Repartidor: a delivery rider the app never stopped dispatching, the order in his thermal cube
## a stolen seal. When the phone pings rose he marks a short lane through the operator and,
## half a second later, charges down it. Then he stumbles with the cube's lid sprung open.
## Ice or standing water on the lane takes his feet: he slides on and goes down for longer.
## A wall at the end of it stops him hard, dazed, and takes the blow. A gravity well bends the
## charge off its lane and into its lip, where he goes down dazed.
extends "res://scripts/survivor/enemy.gd"
const Telegraph = preload("res://scripts/survivor/telegraph.gd")
const PING: float = 0.45
const DASH: float = 0.34
const DASH_REACH: float = 6.0
const SLIP_EXTRA: float = 2.5
const STUMBLE: float = 0.7
const DAZED: float = 1.6
const LANE_WIDTH: float = 1.0
const HIT: float = 8.0
const SEAL := Color("ff3b6b")
## How a dash ends, carried in state_value so every peer plays the same fall.
const CLEAN: float = 0.0
const CRASH: float = 1.0
const SLIP: float = 2.0
const PULLED: float = 3.0
const GRAVITY := Color("8d7bff")
var cooldown: float = 1.4
var hit_this_dash: bool = false
var crash_into: Node
var card: Node3D

func _capsule() -> Vector2:
	return Vector2(0.32, 1.6)
func _base_color() -> Color:
	return Color("172427")

func _build(_dark: Material) -> void:
	card = preload("res://scripts/survivor/enemy_card.gd").new()
	card.name = "Art"
	add_child(card)
	card.setup("res://materials/enemies/repartidor/frames.tres")

func _behave(delta: float, target: Character) -> void:
	cooldown -= delta
	match state:
		"":
			var gap: Vector3 = target.global_position - global_position
			gap.y = 0
			gnaw(walk_toward(delta, target.global_position), 9.0)
			if cooldown <= 0.0 and gap.length() < DASH_REACH - 0.5 and gap.length() > 0.2:
				_mark_lane(gap.normalized())
		"ping":
			velocity = Vector3.ZERO
			if state_time >= PING:
				hit_this_dash = false
				set_state("dash", state_from, state_to, state_value)
		"dash":
			var before: Vector3 = global_position
			var after: Vector3 = dash_point(state_time / DASH)
			# Matter raised across the lane after the ping still stops him.
			var ray := PhysicsRayQueryParameters3D.create(before + Vector3.UP * 0.6, after + Vector3.UP * 0.6, 1)
			ray.exclude = [get_rid()]
			var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and not hit.collider.is_in_group("coop_players") and hit.normal.y < 0.7:
				var stop := Vector3(hit.position.x, before.y, hit.position.z) - (after - before).normalized() * 0.45
				global_position = stop
				_crash(hit.collider)
				if not down: set_state("dazed", stop, stop, CRASH)
				return
			global_position = after
			velocity = (state_to - state_from) / DASH
			if not hit_this_dash:
				for player: Character in players_near(global_position, 0.9):
					player.receive_health.rpc(-HIT)
					player.knock.rpc((state_to - state_from).normalized() * 5.0)
					hit_this_dash = true
			if state_time >= DASH:
				global_position = state_to
				# What he was going to hit may have died mid-charge.
				if state_value == CRASH: _crash(crash_into if is_instance_valid(crash_into) else null)
				if not down: set_state("stumble" if state_value == CLEAN else "dazed", state_to, state_to, state_value)
		"stumble", "dazed":
			velocity = Vector3.ZERO
			if state_time >= (STUMBLE if state == "stumble" else DAZED):
				cooldown = 1.8
				set_state("")

## Host only: choose the lane from here through the operator, decide how it ends, and warn.
func _mark_lane(direction: Vector3) -> void:
	var from: Vector3 = global_position
	var to: Vector3 = from + direction * DASH_REACH
	var ending: float = CLEAN
	# Water or ice across the lane takes his feet: he slides past the end of it.
	for record: Dictionary in run.world.records.values():
		if record["shape"] != "patch" or record["material"] not in ["water", "ice"]: continue
		var spot := Vector3(record["position"].x, from.y, record["position"].z)
		var along: float = clampf((spot - from).dot(direction), 0.0, DASH_REACH)
		if spot.distance_to(from + direction * along) < 1.3:
			to = from + direction * (DASH_REACH + SLIP_EXTRA)
			ending = SLIP
			break
	crash_into = null
	var ray := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.6, to + Vector3.UP * 0.6, 1)
	ray.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and not hit.collider.is_in_group("coop_players"):
		var stop: float = maxf(0.0, (Vector3(hit.position.x, from.y, hit.position.z) - from).length() - 0.45)
		# Nose to a wall already: not worth a charge, he keeps walking round it.
		if stop < 1.5:
			cooldown = 0.5
			return
		to = from + direction * stop
		ending = CRASH
		crash_into = hit.collider
	set_state("ping", from, to, ending)

## A well holds his feet while the phone pings, and drags a charge he has begun off its lane.
func pulled(field: String, at: Vector3) -> bool:
	if field != "well": return false
	match state:
		"ping": return true
		"dash":
			if state_value != PULLED: _veer(at)
			return true
	return false

## The rest of the charge runs to the well's lip instead, never farther than a full dash.
func _veer(at: Vector3) -> void:
	var from: Vector3 = global_position
	var out := Vector3(from.x - at.x, 0.0, from.z - at.z)
	var lip: Vector3 = Vector3(at.x, from.y, at.z) + (out.normalized() if out.length() > 0.1 else Vector3.ZERO) * minf(out.length(), 0.9)
	set_state("dash", from, from + (lip - from).limit_length(DASH_REACH), PULLED)

## Into a wall at full tilt: matter takes the blow, and so does he.
func _crash(into: Node) -> void:
	if is_instance_valid(into) and into.is_in_group("matter_constructs"): into.take_damage(16.0)
	take_damage(3.0)

## The committed charge, identical on every peer: fast off the mark, easing at the end.
func dash_point(t: float) -> Vector3:
	return state_from.lerp(state_to, ease(clampf(t, 0.0, 1.0), 0.6))

func _client_motion(delta: float) -> void:
	if state == "dash": global_position = dash_point(state_time / DASH)
	else: super(delta)

func _on_state() -> void:
	exposure = 1.6 if state in ["stumble", "dazed"] else 1.0
	match state:
		"ping":
			target_position = state_from
			mark(Telegraph.lane(effects_parent(), state_from, state_to, LANE_WIDTH))
		"dash":
			target_position = state_to
			mark(Telegraph.lane(effects_parent(), state_from, state_to, LANE_WIDTH))
		"dazed":
			target_position = state_to
			if state_value == CRASH:
				preload("res://scenes/actions/combat_fx.gd").burst(effects_parent(), state_to + Vector3.UP * 0.8, SEAL)
				preload("res://scenes/actions/combat_fx.gd").ripple(effects_parent(), state_to, SEAL, 1.1, 0.3)
			elif state_value == PULLED:
				preload("res://scenes/actions/combat_fx.gd").ripple(effects_parent(), state_to, GRAVITY, 1.1, 0.4)
		"stumble":
			target_position = state_to
			# Off the end of a wet lane: a skid of water where he lost his feet.
			if state_value == SLIP: preload("res://scenes/actions/combat_fx.gd").ripple(effects_parent(), state_to, Color("93f3ff"), 1.0, 0.4)

func _process(delta: float) -> void:
	super(delta)
	if card == null: return
	card.hit_flash(flash > 0.0)
	match state:
		"ping":
			card.play("Ping")
			card.aim(state_to - state_from)
			if not marks.is_empty(): Telegraph.fill(marks[0], state_time / PING)
		"dash":
			card.play("Dash")
			card.aim(state_to - state_from)
			if not marks.is_empty(): Telegraph.fill(marks[0], 1.0)
		"stumble", "dazed":
			card.play("Stumble")
		_:
			card.play("Run" if Vector2(velocity.x, velocity.z).length() > 0.3 or global_position.distance_to(target_position) > 0.05 else "Idle")
