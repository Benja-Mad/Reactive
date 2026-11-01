## Gárgola (saltador): a facade gargoyle a stolen seal woke. It clears barriers: it crouches and
## marks where it will land, slams down there, then sits with its chest split open while it recovers.
## Landing on an ice sheet shatters it, so a leaper can set off the crew's "fragmentos" reactions.
## A gravity well under its leap breaks the arc: it drops at the well's lip instead of on its mark.
extends "res://scripts/survivor/enemy.gd"
const Telegraph = preload("res://scripts/survivor/telegraph.gd")
const CROUCH: float = 0.8
const FLIGHT: float = 0.62
const EXPOSED: float = 1.5
const APEX: float = 2.6
const REACH: float = 7.5
const SLAM_RADIUS: float = 1.7
## A leap a well caught: a straight fall to the well's lip, carried in state_value on "air".
const PULLED: float = 1.0
const FALL: float = 0.4
const CORE := Color("ff3b6b")
var cooldown: float = 1.6
var card: Node3D

func _capsule() -> Vector2:
	return Vector2(0.42, 1.05)
func _base_color() -> Color:
	return Color("2a2f3b")
func airborne() -> bool:
	return state == "air"

## The facade gargoyle: its art on the crew's own card. It perches, prowls on its knuckles,
## gathers with the seal burning through its cracks, leaps, and lands with its chest split open.
func _build(_dark: Material) -> void:
	card = preload("res://scripts/survivor/enemy_card.gd").new()
	card.name = "Art"
	add_child(card)
	card.setup("res://materials/enemies/gargola/frames.tres")

func prowl_side() -> float:
	return 1.0 if int(str(name).trim_prefix("Machine")) % 2 == 0 else -1.0

func _behave(delta: float, target: Character) -> void:
	match state:
		"":
			cooldown -= delta
			var gap: Vector3 = target.global_position - global_position
			gap.y = 0
			# It prowls rather than closes: inside pouncing range with coils still charging, it
			# circles at a distance instead of walking into the operator.
			var goal: Vector3 = target.global_position
			if cooldown > 0.0 and gap.length() < 4.5:
				goal = target.global_position - gap.normalized().rotated(Vector3.UP, 0.9 * prowl_side()) * 4.5
			var blocker: Node = walk_toward(delta, goal, 0.75 if goal != target.global_position else 1.0)
			# A barrier in the way or an operator in range: commit to a marked jump.
			if cooldown <= 0.0 and (blocker != null or (gap.length() > 2.0 and gap.length() < REACH + 1.0)):
				var landing: Variant = _landing(target)
				if landing != null:
					set_state("crouch", global_position, landing)
					return
			if gap.length() < 1.0 and hit_timer <= 0:
				target.receive_health.rpc(-7.0)
				hit_timer = 0.8
		"crouch":
			velocity = Vector3.ZERO
			if state_time >= CROUCH: set_state("air", global_position, state_to)
		"air":
			global_position = arc(state_time / flight())
			if state_time >= flight(): _land()
		"exposed":
			velocity = Vector3.ZERO
			if state_time >= EXPOSED:
				cooldown = 2.4
				set_state("")

## Where to come down: ahead of a moving operator, never farther than REACH, always on clear
## level floor. Returns null when no candidate is safe.
func _landing(target: Character) -> Variant:
	var lead: Vector3 = target.velocity * 0.35
	lead.y = 0
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for aim: Vector3 in [target.global_position + lead, target.global_position, global_position.lerp(target.global_position, 0.7)]:
		var hop: Vector3 = aim - global_position
		hop.y = 0
		if hop.length() > REACH: aim = global_position + hop.normalized() * REACH
		var floor_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(aim.x, global_position.y + 3.0, aim.z), Vector3(aim.x, global_position.y - 2.0, aim.z), 1))
		if floor_hit.is_empty() or floor_hit.normal.y < 0.85: continue
		# A low ice sheet is fair ground (and cracks under the slam); the top of a wall is not.
		if floor_hit.collider.is_in_group("matter_constructs") and floor_hit.position.y > global_position.y + 0.4: continue
		var probe := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.45
		probe.shape = sphere
		probe.transform.origin = floor_hit.position + Vector3.UP * 0.75
		probe.collision_mask = 1
		if not space.intersect_shape(probe, 1).is_empty(): continue
		return floor_hit.position + Vector3.UP * 0.02
	return null

## The committed jump, identical on every peer: a parabola from the crouch to the mark, or, once
## a well has caught it, a fall from where it was caught that gathers speed.
func arc(t: float) -> Vector3:
	t = clampf(t, 0.0, 1.0)
	var point: Vector3 = state_from.lerp(state_to, t)
	if state_value == PULLED: point.y = lerpf(state_from.y, state_to.y, t * t)
	else: point.y += APEX * 4.0 * t * (1.0 - t)
	return point
func flight() -> float:
	return FALL if state_value == PULLED else FLIGHT

## A well holds it to the ground while it gathers, and pulls it out of a leap it has begun.
func pulled(field: String, at: Vector3) -> bool:
	if field != "well": return false
	match state:
		"crouch": return true
		"air":
			if state_value != PULLED: _fall_toward(at)
			return true
	return false

func _fall_toward(at: Vector3) -> void:
	var out := Vector3(global_position.x - at.x, 0.0, global_position.z - at.z)
	out = out.normalized() if out.length() > 0.1 else Vector3.FORWARD
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var lip: Vector3 = Vector3(at.x, state_to.y, at.z) + out * 1.2
	# The lip is level floor beside the well's matter, never the top of an ice wall.
	for reach: float in [1.2, 2.2, 3.2]:
		var spot := Vector3(at.x, state_to.y, at.z) + out * reach
		var floor_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 3.0, spot - Vector3.UP * 2.0, 1))
		if floor_hit.is_empty() or floor_hit.normal.y < 0.85 or floor_hit.position.y > state_to.y + 0.4: continue
		lip = floor_hit.position + Vector3.UP * 0.02
		break
	set_state("air", global_position, lip, PULLED)

func _land() -> void:
	global_position = state_to
	target_position = state_to
	for player: Character in players_near(state_to, SLAM_RADIUS):
		var push: Vector3 = player.global_position - state_to
		push.y = 0
		player.receive_health.rpc(-14.0)
		player.knock.rpc(push.normalized() * 4.5 if push.length() > 0.05 else Vector3.ZERO)
	# The slam cracks any ice it lands on and splashes standing water.
	for id: int in run.world.records.keys():
		var record: Dictionary = run.world.records[id]
		var near: bool = Vector2(record["position"].x - state_to.x, record["position"].z - state_to.z).length() < 3.0
		if not near: continue
		# Sheets underfoot crack; a wall it just cleared is left standing.
		if record["material"] == "ice" and record["shape"] == "patch": run.world.damage_construct(id, 40.0)
		elif record["material"] == "water": soaked = 2.5
	set_state("exposed", state_to, state_to)

func _client_motion(delta: float) -> void:
	if state == "air": global_position = arc(state_time / flight())
	else: super(delta)

func _on_state() -> void:
	exposure = 1.75 if state == "exposed" else 1.0
	match state:
		"crouch":
			target_position = state_from
			mark(Telegraph.ring(effects_parent(), state_to, SLAM_RADIUS))
		"air":
			# Pulled off its mark: the slam is promised again where it will really come down.
			if state_value == PULLED: mark(Telegraph.ring(effects_parent(), state_to, SLAM_RADIUS))
		"exposed":
			target_position = state_to
			preload("res://scenes/actions/combat_fx.gd").burst(effects_parent(), state_to + Vector3.UP * 0.2, CORE)
			# The shockwave runs out to the edge of the ring it promised.
			preload("res://scenes/actions/combat_fx.gd").ripple(effects_parent(), state_to, Color("ff3b6b"), SLAM_RADIUS, 0.35)
			for player: Character in players_near(state_to, 9.0):
				if player.is_multiplayer_authority(): get_tree().call_group("camera_shakers", "add_shake", 0.1)

func _process(delta: float) -> void:
	super(delta)
	if card == null: return
	card.hit_flash(flash > 0.0)
	match state:
		"crouch":
			card.play("Crouch")
			card.aim(state_to - global_position)
			Telegraph.fill(marks[0] if not marks.is_empty() else null, state_time / (CROUCH + FLIGHT))
		"air":
			card.play("Air")
			card.aim(state_to - state_from)
			Telegraph.fill(marks[0] if not marks.is_empty() else null, 1.0 if state_value == PULLED else (CROUCH + state_time) / (CROUCH + FLIGHT))
		"exposed":
			card.play("Open")
		_:
			card.play("Walk" if Vector2(velocity.x, velocity.z).length() > 0.3 or global_position.distance_to(target_position) > 0.05 else "Idle")
