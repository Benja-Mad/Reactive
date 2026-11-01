## Host-simulated machines: whatever a stolen seal woke in the district. They pursue, steer around
## scenery and break player ice. Every kind has its own script (see SCRIPTS) and draws its art on
## the crew's lit card.
extends CharacterBody3D
const Art = preload("res://scripts/survivor/worker_visual.gd")
var run: Node
var kind: int = 0
var health: float = 15.0
var down: bool = false
var speed: float = 1.6
var hit_timer: float = 0.0
var age: float = 0.0
var previous_position := Vector3.ZERO
var stuck: float = 0.0
var target_position := Vector3.ZERO
var body: Node3D
var flash: float = 0.0
var shell: StandardMaterial3D
var base_color: Color
## Hose knockback still to spend, and how long the machine keeps dripping (slowed).
var shove := Vector3.ZERO
var soaked: float = 0.0
## Kinds 0-2 are the walkers (quiltros, repartidor, animita); 3+ are the specialists. The walker
## constants keep their old names so rosters and saves stay stable.
const PUMP: int = 0
const RUNNER: int = 1
const HAULER: int = 2
const LEAPER: int = 3
const DIVER: int = 4
const DRINKER: int = 5
const SCRIPTS: Dictionary = {
	PUMP: "res://scripts/survivor/enemy_quiltro.gd",
	RUNNER: "res://scripts/survivor/enemy_repartidor.gd",
	HAULER: "res://scripts/survivor/enemy_animita.gd",
	LEAPER: "res://scripts/survivor/enemy_leaper.gd",
	DIVER: "res://scripts/survivor/enemy_diver.gd",
	DRINKER: "res://scripts/survivor/enemy_drinker.gd",
}
## Per kind: health, speed, salvage value, debris colour.
const STATS: Dictionary = {
	PUMP: [11.0, 1.9, 1, Color("386650")],
	RUNNER: [14.0, 2.3, 1, Color("8fe6c8")],
	HAULER: [46.0, 0.95, 3, Color("ffad4a")],
	LEAPER: [17.0, 1.9, 2, Color("9a9aa4")],
	DIVER: [9.0, 4.2, 2, Color("3fa9f5")],
	DRINKER: [34.0, 1.05, 3, Color("6fd6ff")],
}
## What each kind is made of, in the vocabulary matter shares (see materials.gd): the rules read
## these and the editor quotes them. Metal and water conduct; wax melts; a flyer is out of reach
## of what lies on the ground.
const TAGS: Dictionary = {
	PUMP: {"material": "carne", "mass": 1.0, "flies": false},
	RUNNER: {"material": "metal", "mass": 1.2, "flies": false},
	HAULER: {"material": "cera", "mass": 2.0, "flies": false},
	LEAPER: {"material": "piedra", "mass": 2.5, "flies": false},
	DIVER: {"material": "metal", "mass": 0.4, "flies": true},
	DRINKER: {"material": "agua", "mass": 2.0, "flies": false},
}
## The machine's share of the properties matter has: `temp` -2..+2 and `charge` 0..2. Wet is the
## time it keeps dripping (`soaked`). The host owns them; clients get them packed in `props_code`.
var temp: int = 0
var charge: int = 0
var _wet_seen: bool = false
## Host: seconds before temp steps back toward `rest_temp`, and before a passing charge leaves.
var temp_hold: float = 0.0
var charge_hold: float = 0.0
## Host: nanites an attack with coat planted on it; they go off when it falls or burns.
var nanites: int = 0
## Host: seconds the machine stays locked in place (wet and frozen, or stuck to a magnet).
var frozen: float = 0.0

## The temp a machine settles back to. The animita's candles keep her burning.
func rest_temp() -> int:
	return 0

## How far its own heat reaches beyond touch (the heat rule reads it).
func heat_reach() -> float:
	return 0.0

func tag(key: String) -> Variant:
	return TAGS.get(kind, TAGS[PUMP])[key]

func wet() -> bool:
	return soaked > 0.0 if multiplayer.is_server() else _wet_seen

## temp, wet, charge and planted nanites in one small int, 0 when there is nothing to tell.
func props_code() -> int:
	return (temp + 2) | (int(soaked > 0.0) << 3) | (clampi(charge, 0, 2) << 4) | (int(nanites > 0) << 6) if temp != 0 or soaked > 0.0 or charge > 0 or nanites > 0 else 0

func read_props(code: int) -> void:
	temp = (code & 7) - 2 if code != 0 else 0
	_wet_seen = code & 8 != 0
	charge = (code >> 4) & 3
	nanites = (code >> 6) & 1

## Damage taken is multiplied by this; specialists open up while they recover.
var exposure: float = 1.0
## Specialists act in named phases. The host decides; `machine_state` replays each change on every
## peer with the same anchors, so telegraphs and committed motion match exactly.
var state: String = ""
var state_time: float = 0.0
var state_from := Vector3.ZERO
var state_to := Vector3.ZERO
var state_value: float = 0.0
## Telegraph marks live in the world, not under the machine; freed on each phase change.
var marks: Array[Node3D] = []

static func create(kind_index: int) -> CharacterBody3D:
	var made: CharacterBody3D = load(SCRIPTS[kind_index]).new() if SCRIPTS.has(kind_index) else load("res://scripts/survivor/enemy.gd").new()
	made.kind = kind_index
	made.health = STATS[kind_index][0]
	made.speed = STATS[kind_index][1]
	return made

func _ready() -> void:
	add_to_group("survivor_enemies")
	add_to_group("matter_damageable")
	# Existing projectile assistance and damage surfaces can still discover these machines.
	add_to_group("yard_sentries")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	var size: Vector2 = _capsule()
	capsule.radius = size.x
	capsule.height = size.y
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)
	base_color = _base_color()
	shell = Art.material(base_color, 0.25)
	var dark: Material = Art.material(Color("1f2729"), 0.3)
	body = Node3D.new()
	add_child(body)
	_build(dark)
	target_position = global_position
func _capsule() -> Vector2:
	return Vector2(0.45, 1.1)
func _base_color() -> Color:
	return Color("2a2f3b")
func _build(_dark: Material) -> void:
	pass
## Flying or mid-leap: out of reach of ground weapons like Brasa's flame.
func airborne() -> bool:
	return false
## An emissive material for a machine's lamp or glow.
func _eye(color: Color, energy: float) -> StandardMaterial3D:
	var m := Art.material(color)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m
func _physics_process(delta: float) -> void:
	if down: return
	age += delta
	state_time += delta
	hit_timer = maxf(0, hit_timer - delta)
	if not multiplayer.is_server():
		_client_motion(delta)
		return
	var target: Character = run.nearest_player(global_position)
	if target == null: return
	_behave(delta, target)
	if global_position.y < -3.0 or global_position.distance_to(target.global_position) > 45.0:
		run.despawn_machine.rpc(str(name))
func _client_motion(delta: float) -> void:
	global_position = global_position.lerp(target_position, 1.0 - exp(-delta * 18))
## The plainest life a machine can have: chase the nearest operator, chew through matter, bite on
## contact. Each kind's script replaces it with its own.
func _behave(delta: float, target: Character) -> void:
	var difference: Vector3 = target.global_position - global_position
	difference.y = 0
	gnaw(walk_toward(delta, target.global_position), 9.0)
	if difference.length() < 1.05 and hit_timer <= 0:
		target.receive_health.rpc(-9.0)
		hit_timer = 0.8
## Chew on the crew's matter when it is what blocks the way.
func gnaw(obstacle: Node, damage: float) -> void:
	if obstacle != null and obstacle.is_in_group("matter_constructs") and hit_timer <= 0:
		obstacle.take_damage(damage)
		hit_timer = 0.85
## One step of ground pursuit toward `goal`. Returns the matter construct in the way, if any.
func walk_toward(delta: float, goal: Vector3, pace_scale: float = 1.0) -> Node:
	var difference: Vector3 = goal - global_position
	difference.y = 0
	var wish: Vector3 = difference.normalized()
	# Separation prevents a whole wave occupying a single point.
	var separation := Vector3.ZERO
	for other: Node3D in get_tree().get_nodes_in_group("survivor_enemies"):
		if other == self or other.down or other.airborne(): continue
		var away: Vector3 = global_position - other.global_position
		away.y = 0
		if away.length_squared() < 1.4: separation += away / maxf(away.length_squared(), 0.15)
	wish = (wish + separation * 0.6).normalized()
	var blocker: Node = null
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.6, global_position + Vector3.UP * 0.6 + wish * 1.15, 1)
	ray.exclude = [get_rid()]
	var obstacle: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if not obstacle.is_empty() and not obstacle.collider.is_in_group("coop_players"):
		if obstacle.collider.is_in_group("matter_constructs"):
			blocker = obstacle.collider
		else:
			# Pick the least obstructed tangent, with a stable side for each machine.
			var tangent: Vector3 = wish.rotated(Vector3.UP, PI * 0.48 * (1 if int(name.trim_prefix("Machine")) % 2 == 0 else -1))
			wish = tangent
	var pace: float = speed * pace_scale * run.slow_factor(global_position) * (0.6 if soaked > 0.0 else 1.0) * (0.0 if frozen > 0.0 else 1.0) * (0.8 if temp < 0 else 1.0)
	frozen = maxf(0.0, frozen - delta)
	soaked = maxf(0.0, soaked - delta)
	velocity = wish * pace + shove
	shove = shove.move_toward(Vector3.ZERO, delta * 16.0)
	velocity.y = -4.0
	move_and_slide()
	_impact()
	# Recover machines caught in scenery without teleporting onto the player.
	if global_position.distance_to(previous_position) < 0.004: stuck += delta
	else: stuck = maxf(0, stuck - delta)
	previous_position = global_position
	if stuck > 3.0:
		global_position += wish.rotated(Vector3.UP, PI * 0.5) * 0.8
		stuck = 0
	return blocker
## Impulse: a machine thrown into scenery takes mass times speed, and the throw ends there.
func _impact() -> void:
	if shove.length() < 6.0: return
	for index: int in get_slide_collision_count():
		var hit: KinematicCollision3D = get_slide_collision(index)
		if hit.get_normal().y > 0.5 or hit.get_normal().dot(shove.normalized()) > -0.5: continue
		var other: Object = hit.get_collider()
		if other is CharacterBody3D:
			# Thrown into another machine: the two collide. The crew is never a bowling pin.
			if not (other as Node).is_in_group("survivor_enemies") or other.down or run.spellwork == null: continue
			var speed: float = shove.length()
			shove *= 0.3
			run.spellwork.rules.bowl(self, other as Node3D, speed)
			return
		var blow: float = minf(14.0, float(tag("mass")) * shove.length() * 0.85)
		shove = Vector3.ZERO
		if run.spellwork != null: run.spellwork.rules.count("impacts")
		take_damage(blow)
		return
## Host only: begin a phase everywhere.
func set_state(next: String, from: Vector3 = global_position, to: Vector3 = global_position, value: float = 0.0) -> void:
	if multiplayer.is_server() and not down: run.machine_state.rpc(str(name), next, from, to, value)
func enter_state(next: String, from: Vector3, to: Vector3, value: float) -> void:
	state = next
	state_time = 0.0
	state_from = from
	state_to = to
	state_value = value
	clear_marks()
	_on_state()
func _on_state() -> void:
	pass
func clear_marks() -> void:
	for mark: Node3D in marks: if is_instance_valid(mark): mark.queue_free()
	marks.clear()
func mark(node: Node3D) -> Node3D:
	marks.append(node)
	return node
func effects_parent() -> Node:
	return run.get_parent()
func _exit_tree() -> void:
	clear_marks()
## Every live operator within `radius` of `point` (flat distance), for area hits.
func players_near(point: Vector3, radius: float) -> Array[Character]:
	var found: Array[Character] = []
	for player: Character in run.players():
		if player.eliminated: continue
		if Vector2(player.global_position.x - point.x, player.global_position.z - point.z).length() < radius: found.append(player)
	return found
func _process(delta: float) -> void:
	if body == null: return
	flash = maxf(0, flash - delta)
	shell.albedo_color = Color("e6d5b8") if flash > 0 else base_color
## Hit by an ánima: shoved back and slowed while they drip.
func soak(push: Vector3) -> void:
	if not multiplayer.is_server() or down: return
	shove += push
	soaked = 1.6
## Licked by Brasa's flame from `origin` (host only), after the heat rule has warmed it (see
## rules.ignite). Kinds that answer to fire in their own way override it.
func burn(_origin: Vector3) -> void:
	pass
## The crew's gravity reaching this machine this tick (host only): `field` is "well" or "repel",
## `at` the matter it comes from. Walkers simply take it as shove; a specialist committed to its
## own motion answers here and returns true, and then it takes no shove.
func pulled(_field: String, _at: Vector3) -> bool:
	return false

func take_damage(amount: float) -> void:
	if not multiplayer.is_server() or down: return
	run.log_damage("all", amount * exposure)
	health -= amount * exposure
	run.machine_hit.rpc(str(name))
	if health <= 0:
		down = true
		if nanites > 0 and run.spellwork != null: run.spellwork.rules.detonate_machine(global_position, nanites)
		_on_killed()
		run.machine_killed(global_position, kind)
		run.despawn_machine.rpc(str(name))
func _on_killed() -> void:
	pass
