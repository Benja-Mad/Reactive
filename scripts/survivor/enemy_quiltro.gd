## Quiltro: one of the block's stray dogs, still in the jumper a neighbour knitted it, its eyes
## taken by a stolen seal. They hunt as a pack: each one closes on its own side of the operator,
## bares its teeth (the eyes flare rose) and only then lunges. Brasa's fire sends them off yelping;
## a soaking from the ánimas stops them dead to shake it off. They still gnaw through ice.
## A dog runs from the flame only once: after that, hunger beats fear.
extends "res://scripts/survivor/enemy.gd"
const BARE: float = 0.38
const LUNGE: float = 0.22
const LUNGE_REACH: float = 1.9
const BITE: float = 7.0
const SHAKE: float = 0.9
const FLEE: float = 0.9
## How far out a dog waits on its side while it is not ready to bite.
const RING: float = 2.6
var cooldown: float = 0.6
## Set once it has run from the fire; it does not run again.
var brave: bool = false
var bitten: bool = false
var card: Node3D

func _capsule() -> Vector2:
	return Vector2(0.36, 0.9)
func _base_color() -> Color:
	return Color("2e241c")

func _build(_dark: Material) -> void:
	card = preload("res://scripts/survivor/enemy_card.gd").new()
	card.name = "Art"
	add_child(card)
	card.setup("res://materials/enemies/quiltro/frames.tres")

## Each dog's place around the operator, fixed by its serial so the pack fans out.
func flank() -> float:
	return (float(int(str(name).trim_prefix("Machine")) % 5) - 2.0) * 0.62

func _behave(delta: float, target: Character) -> void:
	cooldown -= delta
	var gap: Vector3 = target.global_position - global_position
	gap.y = 0
	match state:
		"":
			var goal: Vector3 = target.global_position
			if gap.length() < RING + 1.5 and cooldown > 0.0:
				goal = target.global_position - gap.normalized().rotated(Vector3.UP, flank()) * RING
			gnaw(walk_toward(delta, goal, 1.0 if goal == target.global_position else 0.8), 7.0)
			if cooldown <= 0.0 and gap.length() < LUNGE_REACH + 0.5:
				set_state("bare", global_position, target.global_position)
		"bare":
			velocity = Vector3.ZERO
			if state_time >= BARE:
				# The lunge goes where the operator stood when the teeth came out.
				var reach: Vector3 = state_to - global_position
				reach.y = 0
				bitten = false
				set_state("lunge", global_position, global_position + reach.limit_length(LUNGE_REACH))
		"lunge":
			velocity = (state_to - state_from) / LUNGE
			velocity.y = -4.0
			move_and_slide()
			if not bitten:
				for player: Character in players_near(global_position, 0.95):
					player.receive_health.rpc(-BITE)
					player.knock.rpc((state_to - state_from).normalized() * 2.5)
					bitten = true
			if state_time >= LUNGE:
				cooldown = 1.3 + float(int(str(name).trim_prefix("Machine")) % 4) * 0.2
				set_state("")
		"shake":
			_drift(delta, Vector3.ZERO)
			if state_time >= SHAKE: set_state("")
		"flee":
			var away: Vector3 = global_position - state_from
			away.y = 0
			_drift(delta, away.normalized() * speed * 1.5)
			if state_time >= FLEE: set_state("")

## Moves with only the given run and any shove still to spend.
func _drift(delta: float, run_velocity: Vector3) -> void:
	velocity = run_velocity + shove
	shove = shove.move_toward(Vector3.ZERO, delta * 16.0)
	velocity.y = -4.0
	move_and_slide()

func soak(push: Vector3) -> void:
	super(push)
	if not down and state in ["", "bare"]: set_state("shake")

func burn(origin: Vector3) -> void:
	if not down and not brave and state in ["", "bare", "shake"]:
		brave = true
		set_state("flee", origin)

func _client_motion(delta: float) -> void:
	if state == "lunge": global_position = global_position.lerp(state_from.lerp(state_to, clampf(state_time / LUNGE, 0, 1)), 1.0 - exp(-delta * 30))
	else: super(delta)

func _on_state() -> void:
	if state == "lunge": target_position = state_to

func _process(delta: float) -> void:
	super(delta)
	if card == null: return
	card.hit_flash(flash > 0.0)
	match state:
		"bare":
			card.play("Bare")
			card.aim(state_to - global_position)
		"lunge":
			card.play("Lunge")
			card.aim(state_to - state_from)
		"shake":
			card.play("Shake")
		"flee":
			card.play("Flee")
		_:
			card.play("Run" if Vector2(velocity.x, velocity.z).length() > 0.3 or global_position.distance_to(target_position) > 0.05 else "Idle")
