## One authoritative five-minute shift. Players steer; builds choose targets and place matter.
extends Node
const Build = preload("res://scripts/survivor/build.gd")
const Enemy = preload("res://scripts/survivor/enemy.gd")
const Pickup = preload("res://scripts/survivor/pickup.gd")
const Art = preload("res://scripts/survivor/worker_visual.gd")
const Catalog = preload("res://scripts/matter/materials.gd")
const Attack = preload("res://scripts/survivor/attack.gd")
const DURATION: float = 300.0
var phase: String = "running"
var elapsed: float = 0.0
var kills: int = 0
var xp: int = 0
var level: int = 1
var builds: Dictionary = {}
var offers: Dictionary = {}
var clocks: Dictionary = {}
## Per peer, how charged each routine is (0..1). Host-computed, replicated for the HUD only.
var charges: Dictionary = {}
## Routines a player just changed, run once on the house as play resumes so the change shows in
## the yard at once: peer -> [routine index]. `_trial_in` paces them.
var trials: Dictionary = {}
var _trial_in: float = 0.0
const TRIAL_GAP := 0.45
var collected: int = 0
var machines_spawned: int = 0
var automations_fired: int = 0
## How routines fared: drawn (under way) or blocked (nowhere to put it). For the soak run.
var water_log: Dictionary = {}
## Damage machines took, by what dealt it: weapon, crush, bowl, nanites, and the rest. For the soak run.
var damage_log: Dictionary = {}
func log_damage(source: String, amount: float) -> void:
	damage_log[source] = snappedf(float(damage_log.get(source, 0.0)) + amount, 0.1)
var _spawn_in: float = 1.2
var _net_in: float = 0
var _serial: int = 0
var _pickup_serial: int = 0
var _rng := RandomNumberGenerator.new()
var machines: Node3D
var pickups: Node3D
var world: Node
var arena: Node3D
var hud: Control
## Builds routines, fires their reactions and applies matter's forces (see spellwork.gd).
var spellwork: Node
var test_mode: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("survivor_run")
	_rng.randomize()
	world = get_parent().get_node("WorldMatter")
	world.residue = true
	arena = get_parent().get_node("Arena")
	if arena.has_method("apply_survivor_dressing"): arena.apply_survivor_dressing()
	machines = Node3D.new()
	machines.name = "Machines"
	machines.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(machines)
	pickups = Node3D.new()
	pickups.name = "Salvage"
	pickups.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(pickups)
	spellwork = preload("res://scripts/survivor/spellwork.gd").new()
	spellwork.name = "Spellwork"
	spellwork.run = self
	add_child(spellwork)
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	hud = preload("res://scripts/survivor/hud.gd").new()
	hud.run = self
	layer.add_child(hud)
	var sightline := preload("res://scripts/survivor/sightline.gd").new()
	sightline.name = "Sightline"
	sightline.run = self
	sightline.arena = arena
	add_child(sightline)
	var pixels := preload("res://scripts/survivor/pixel_view.gd").new()
	add_child(pixels)
	pixels.setup(arena.gameplay_camera, float(arena.framing_distance))
	if not multiplayer.is_server(): request_state.rpc_id(1)

func players() -> Array[Node]:
	return get_tree().get_nodes_in_group("coop_players")
func nearest_player(point: Vector3) -> Character:
	var found: Character
	var best: float = INF
	for player: Character in players():
		if player.eliminated: continue
		var distance: float = player.global_position.distance_squared_to(point)
		if distance < best:
			best = distance
			found = player
	return found
func local_player() -> Character:
	return world._player(multiplayer.get_unique_id()) as Character

## «on cue»: the player's own trigger. A click names a spot on the floor and the host fires every
## ready routine that starts on cue there, on its next tick.
func _unhandled_input(event: InputEvent) -> void:
	if phase != "running" or get_tree().paused or not event.is_action_pressed("cue"): return
	var spot: Variant = cue_spot()
	if spot == null: return
	cue.rpc_id(1, spot)
	# The click answers at once, here: corners on the floor, amber if a routine on cue is ready.
	# Amber when the click does something: a routine fires, a trap goes, or a machine is marked.
	var ready: bool = cue_ready(spot) or machine_at(spot) != null
	if spellwork._fx != null: spellwork._fx.aim(spot, ready)
	Sfx.of(self).play("cue" if ready else "cue_idle")

## Local, every frame: while one of your routines on cue is ready, the floor under the pointer
## shows it can be clicked.
func _process(_delta: float) -> void:
	# Which of your routines have matter armed «on click», read once a frame for the HUD and the
	# pointer.
	click_armed.clear()
	var spots: Array = []
	var reach_now: Dictionary = {}
	if world != null:
		for record: Dictionary in world.records.values():
			if not Build.Recipe.click_ready(record, multiplayer.get_unique_id(), false): continue
			click_armed[int(record["reaction"].get("routine", -1))] = true
			var size: Vector3 = record.get("size", Vector3.ONE)
			var half: float = clampf(maxf(size.x, size.z) * 0.36, 0.45, 1.4)
			# A machine within its reach now: the moment to let it go.
			var near: bool = machine_at(record["position"], half + 1.4) != null
			spots.append([record["position"], half, near])
			# Heard once as it comes into reach, so the moment can be caught without looking.
			if near and not _in_reach.has(record["id"]): Sfx.of(self).play("armed", 1.5, 2.0)
			if near: reach_now[record["id"]] = true
	_in_reach = reach_now
	_armed_spots = spots
	if spellwork == null or spellwork._fx == null: return
	spellwork._fx.click_spots = spots
	var live: bool = phase == "running" and not get_tree().paused
	var spot: Variant = cue_spot() if live else null
	# Over a machine, the corners close on it instead: a click there marks it.
	var over: Node3D = machine_at(spot) if spot != null else null
	spellwork._fx.hover_machine = over if over != spellwork._fx.mark else null
	spellwork._fx.hover = spot if spot != null and over == null and cue_ready(spot) else null
	# What this click would let go stands out from what it would not.
	for armed: Array in spots: armed.append(spot != null and Vector2(armed[0].x - spot.x, armed[0].z - spot.z).length() <= spellwork.RELEASE_RADIUS)

## Whether a click of yours would do something now: a routine on cue charged, or matter of
## yours armed «on click».
func cue_ready(spot: Variant = null) -> bool:
	var routines: Array = builds.get(multiplayer.get_unique_id(), {}).get("routines", [])
	var charge: Array = charges.get(multiplayer.get_unique_id(), [])
	for index: int in routines.size():
		if routines[index]["when"] == "mano" and index < charge.size() and float(charge[index]) >= 1.0: return true
	if spot == null: return not click_armed.is_empty()
	for armed: Array in _armed_spots:
		if Vector2(armed[0].x - spot.x, armed[0].z - spot.z).length() <= spellwork.RELEASE_RADIUS: return true
	return false

## Where the pointer meets the floor, brought within reach the way the host will bring it, so
## the corners stand where the matter will land.
func cue_spot() -> Variant:
	if local_player() == null or arena == null: return null
	var camera: Camera3D = arena.gameplay_camera
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var spot: Variant = Plane(Vector3.UP, 0.07).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if spot == null: return null
	var me: Vector3 = local_player().global_position
	var reach := Vector3(spot.x - me.x, 0, spot.z - me.z)
	if reach.length() > Build.DRAW_REACH: spot = Vector3(me.x, 0.07, me.z) + reach.normalized() * Build.DRAW_REACH
	return spot

@rpc("any_peer", "call_local", "reliable")
func cue(point: Vector3) -> void:
	if not multiplayer.is_server() or phase != "running": return
	var peer: int = multiplayer.get_remote_sender_id()
	if peer == 0: peer = multiplayer.get_unique_id()
	if not clocks.has(peer): return
	var body: Character = world._player(peer) as Character
	if body == null or body.eliminated: return
	clocks[peer]["cue"] = point
	# One click, read by priority. First it lets go their THENs armed «on click» near where it
	# landed; a click that does that marks nothing, so springing a trap as a machine walks into
	# it never retargets the whole program onto that machine.
	var freed: int = spellwork.release(peer, point)
	var picked: Node3D = machine_at(point)
	var clock: Dictionary = clocks[peer]
	if clock.has("mark") and not is_instance_valid(clock["mark"]): clock.erase("mark")
	# A trap of theirs right there that is still settling (the client already shows it ready):
	# the click was meant for it, so it marks nothing either.
	var settling: bool = false
	if freed == 0 and picked != null:
		for record: Dictionary in world.records.values():
			if Build.Recipe.click_ready(record, peer, false) and Vector2(record["position"].x - point.x, record["position"].z - point.z).length() <= spellwork.RELEASE_RADIUS:
				settling = true
				break
	var marking: bool = freed == 0 and picked != null and not settling
	if marking and clock.get("mark") != picked:
		# Otherwise a click on a machine marks it: your routines take it first while in reach.
		clock["mark"] = picked
		marked.rpc(peer, str(picked.name))
	# On cue always fires at the point. A click that does nothing at all costs a little: every
	# routine on cue still recharging waits half a second more, so spamming does not pay.
	var routines: Array = builds.get(peer, {}).get("routines", [])
	var any_ready: bool = false
	for index: int in routines.size():
		if routines[index]["when"] == "mano" and float(clock.get("r%d" % index, 0.0)) <= 0.0: any_ready = true
	if freed == 0 and not marking and not any_ready:
		for index: int in routines.size():
			var key: String = "r%d" % index
			if routines[index]["when"] == "mano" and float(clock.get(key, 0.0)) > 0.0: clock[key] = float(clock[key]) + IDLE_CLICK

## The standing machine nearest `point` within a click's reach of it, or null.
func machine_at(point: Vector3, radius: float = MARK_RADIUS) -> Node3D:
	var picked: Node3D = null
	var best: float = radius
	for enemy: Node3D in get_tree().get_nodes_in_group("survivor_enemies"):
		if enemy.down: continue
		var gap: float = Vector2(enemy.global_position.x - point.x, enemy.global_position.z - point.z).length()
		if gap < best:
			best = gap
			picked = enemy
	return picked

## This machine's player's mark, by node name, as the host last said.
var my_mark: String = ""
## Every player's mark by peer, by node name, as the host last said.
var crew_marks: Dictionary = {}

## Routine indices of yours with matter armed «on click» this frame (see _process).
var click_armed: Dictionary = {}
var _in_reach: Dictionary = {}
## This frame's armed spots: [position, half, machine in reach].
var _armed_spots: Array = []

## What a click that does nothing adds to the recharge of your routines on cue.
const IDLE_CLICK := 0.5
## How far a mark may be before it is let go: the reach routines pick their machines from.
const MARK_KEEP := 16.0

## How near a click must land to a machine to mark it.
const MARK_RADIUS := 2.2

## The host's word to everyone: this machine is now `peer`'s mark ("" for none).
@rpc("authority", "call_local", "reliable")
func marked(peer: int, key: String) -> void:
	if key == "": crew_marks.erase(peer)
	else: crew_marks[peer] = key
	var enemy: Node3D = machines.get_node_or_null(key) if machines != null and key != "" else null
	var fx: Node = spellwork._fx if spellwork != null else null
	if peer != multiplayer.get_unique_id():
		# A crewmate's mark: seen by everyone, so one can point and another strike.
		if fx != null:
			if enemy != null: fx.others[peer] = enemy
			else: fx.others.erase(peer)
		return
	my_mark = key
	if fx == null: return
	fx.mark = enemy
	if enemy != null: Sfx.of(self).play("armed", 0.75, 4.0)
func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or phase != "running" or get_tree().paused: return
	if players().is_empty(): return
	if not _watered and not test_mode: open_sources()
	for player: Character in players():
		var peer: int = player.get_multiplayer_authority()
		if not builds.has(peer):
			builds[peer] = Build.fresh()
			clocks[peer] = {"shot": 0.2, "heal": 3.0, "trail": player.global_position, "made": {}}
		if player.eliminated:
			# Out of service, their mark goes with them: if marked no longer answers to it.
			if clocks[peer].has("mark"):
				clocks[peer].erase("mark")
				marked.rpc(peer, "")
			continue
		player.move_multiplier = 1.0 + builds[peer]["tools"]["boots"] * 0.1
		_automate(player, peer, delta)
	_run_trials(delta)
	_land_animas(delta)
	_land_falls(delta)
	if nearest_player(Vector3.ZERO) == null:
		set_phase.rpc("lost")
		return
	elapsed += delta
	if elapsed >= DURATION:
		elapsed = DURATION
		set_phase.rpc("won")
		return
	_spawn_in -= delta
	if _spawn_in <= 0 and not test_mode:
		_spawn_in = maxf(0.30, 1.65 - elapsed * 0.004)
		for i: int in (2 if elapsed > 90 else 1): spawn_near_player()
	spellwork.tick(delta)
	_net_in -= delta
	if _net_in <= 0:
		_net_in = 0.1
		publish()

func targets(player: Character, reach: float = 16.0) -> Array[Node3D]:
	var result: Array[Node3D] = []
	# The crew fires over its own matter: a wall that shields you must not also blind you.
	var clear: Array[RID] = [player.get_rid()]
	for view: Node in world.views.values(): if view is CollisionObject3D: clear.append((view as CollisionObject3D).get_rid())
	for enemy: Node3D in get_tree().get_nodes_in_group("survivor_enemies"):
		if enemy.down or player.global_position.distance_to(enemy.global_position) > reach: continue
		var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.9, enemy.global_position + Vector3.UP * 0.7, 1)
		query.exclude = clear
		var hit: Dictionary = arena.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): result.append(enemy)
	result.sort_custom(func(a: Node3D, b: Node3D) -> bool: return player.global_position.distance_squared_to(a.global_position) < player.global_position.distance_squared_to(b.global_position))
	# The player's mark goes first while it is in sight, so every routine that picks a machine
	# picks that one.
	var mark: Variant = clocks.get(player.get_multiplayer_authority(), {}).get("mark")
	if mark != null and is_instance_valid(mark) and mark in result:
		result.erase(mark)
		result.push_front(mark)
	return result
func _automate(player: Character, peer: int, delta: float) -> void:
	var build: Dictionary = builds[peer]
	var tools: Dictionary = build["tools"]
	var clock: Dictionary = clocks[peer]
	clock["shot"] -= delta
	clock["heal"] -= delta
	# A mark left far behind is let go: out past the reach routines pick from, it only misleads.
	if clock.has("mark") and (not is_instance_valid(clock["mark"]) or player.global_position.distance_to(clock["mark"].global_position) > MARK_KEEP):
		clock.erase("mark")
		marked.rpc(peer, "")
	var enemies: Array[Node3D] = targets(player)
	if clock["shot"] <= 0:
		if player is Support: _animas(player, peer, clock, tools)
		else: _flame(player, peer, clock, tools)
	if player is Support and clock["heal"] <= 0:
		clock["heal"] = 4.0
		for ally: Character in players():
			if not ally.eliminated and ally.health < 100 and ally.global_position.distance_to(player.global_position) < 9:
				ally.receive_health.rpc(5.0)
	var hurt: bool = player.health < float(clock.get("last_health", player.health))
	clock["last_health"] = player.health
	if hurt: clock["hurt"] = true
	var routines: Array = build["routines"]
	for index: int in routines.size():
		var routine: Dictionary = routines[index]
		var key: String = "r%d" % index
		clock[key] = float(clock.get(key, 0.8 + index * 0.7)) - delta
		if routine["when"] == "" or clock[key] > 0: continue
		var placement: Variant = _placement(player, clock, routine["when"], enemies)
		if placement == null: continue
		var outcome: String = spellwork.begin(peer, index, placement[0], placement[1], 0, placement[2] if placement.size() > 2 else 0)
		# With nowhere to put it, it retries soon instead of losing the cycle.
		clock[key] = cooldown(build, index) if outcome == "" else 0.6
		water_log[outcome if outcome != "" else "drawn"] = int(water_log.get(outcome if outcome != "" else "drawn", 0)) + 1
	# A click is spent on this tick: one that found nothing ready does not wait for a recharge.
	clock.erase("cue")

## Brasa's combustion arm: a short cone of fire from the palm, many times a second. Bare, it
## hurts and heats a step what it licks, and flashes the puddles in its path into steam; every
## other thing it does is a DO piece plugged into it (attack.gd).
const FLAME_REACH: float = Attack.WEAPON["fire"]["reach"]
## However fast a weapon fires, what a hit does beyond damage (heat, charge, shove, nanites)
## lands on any one machine at most this often.
const STRIKE_BEAT: float = 0.5
func _flame(player: Character, peer: int, clock: Dictionary, tools: Dictionary) -> void:
	var hit: Dictionary = Attack.profile(Build.attack_steps(builds[peer]), "fire")
	# Fire licks along the ground: what is in the air waits for the ánimas, unless it is raised.
	var near: Array[Node3D] = []
	for enemy: Node3D in targets(player, FLAME_REACH + 0.6): if hit["aloft"] or not enemy.airborne(): near.append(enemy)
	if near.is_empty(): return
	clock["shot"] = Attack.WEAPON["fire"]["every"] * pow(0.82, tools["cadence"])
	var me: Vector3 = player.global_position
	var aim: Vector3 = near[0].global_position - me
	aim.y = 0
	aim = aim.normalized()
	# Dos bocas widens the fan instead of adding a second target.
	var half_angle: float = 0.5 + tools["split"] * 0.16
	var focus: Vector3 = near[0].global_position
	for enemy: Node3D in near:
		var gap: Vector3 = enemy.global_position - me
		gap.y = 0
		if gap.length() > FLAME_REACH + 0.6 or (gap.length() > 1.0 and aim.angle_to(gap) > half_angle): continue
		strike(peer, enemy, hit, me, focus, Attack.WEAPON["fire"]["damage"] + tools["power"] * Attack.WEAPON["fire"]["power"], near)
	if hit["slam"]: _lift(peer, player, near[0], hit)
	# Low along the floor: a hot flame boils the puddles in its path, a cold one leaves them be.
	if hit["temp"] >= 1: world.heat_along(me - Vector3.UP * 1.0 + aim * 0.5, me - Vector3.UP * 1.0 + aim * FLAME_REACH)
	weapon_fx.rpc(peer, me + aim * FLAME_REACH)
	automations_fired += 1

## One hit of a programmed weapon on `enemy`, from `origin`, toward the lead target at `focus`.
func strike(peer: int, enemy: Node3D, hit: Dictionary, origin: Vector3, focus: Vector3, damage: float, pack: Array[Node3D], shove: float = 0.0) -> void:
	if not clocks.has(peer): clocks[peer] = {}
	var clock: Dictionary = clocks[peer]
	if not clock.has("struck"): clock["struck"] = {}
	if clock["struck"].size() > 96:
		for machine: String in clock["struck"].keys(): if float(clock["struck"][machine]) < elapsed: clock["struck"].erase(machine)
	var key: String = str(enemy.name)
	var ready: bool = elapsed >= float(clock["struck"].get(key, -1.0))
	if ready: clock["struck"][key] = elapsed + STRIKE_BEAT
	var rules: Node = spellwork.rules
	var away: Vector3 = Vector3(enemy.global_position.x - origin.x, 0, enemy.global_position.z - origin.z).normalized()
	log_damage("weapon", damage * enemy.exposure)
	enemy.take_damage(damage)
	if not is_instance_valid(enemy) or enemy.down: return
	if shove > 0.0: enemy.shove += away * shove
	if not ready: return
	# Heat: fire's own step up, or what heat and cold pieces made of it.
	var water: bool = hit["base"] == "water"
	match hit["temp"]:
		2:
			if water:
				rules.warm(enemy)
				enemy.take_damage(rules.SCALD_DAMAGE)
			else:
				rules.light(enemy)
				if is_instance_valid(enemy) and not enemy.down: enemy.burn(origin)
		1:
			if water: rules.warm(enemy)
			else: rules.ignite(enemy, origin)
		0: pass
		_:
			rules.chill(enemy)
			if hit["temp"] <= -2 and is_instance_valid(enemy) and not enemy.down: rules.chill(enemy)
	if not is_instance_valid(enemy) or enemy.down: return
	if hit["charge"] > 0 and elapsed >= float(clock.get("zap", -1.0)):
		clock["zap"] = elapsed + STRIKE_BEAT
		rules.zap(enemy, hit["charge"], pack)
		if not is_instance_valid(enemy) or enemy.down: return
	if hit["knock"] > 0: enemy.shove += away * 4.0 * hit["knock"]
	if hit["scatter"]: enemy.shove += away * 6.0
	if hit["gather"]:
		var inward := Vector3(focus.x - enemy.global_position.x, 0, focus.z - enemy.global_position.z)
		if inward.length() > 1.2: enemy.shove += inward.normalized() * 5.0
	if hit["coat"] > 0: enemy.nanites = maxi(enemy.nanites, hit["coat"])
	# Wall: the weapon leaves its matter on the floor, poured from the operator's hands.
	if hit["trail"] and elapsed >= float(clock.get("trail_at", -1.0)):
		clock["trail_at"] = elapsed + 2.5
		var spot := Vector3(enemy.global_position.x, 0.07, enemy.global_position.z)
		if world.spill(spot, 1.0, hit["base"]) != 0: spellwork.stream_fx.rpc(Vector3(origin.x, 0.07, origin.z), spot, 0.25, hit["base"])

## El Sereno's ánimas: rain-spirits loosed from the ward over his hand. Each one wanders to a
## machine and bursts into water there: the one it chased and everything within the splash are
## hurt and wet, and now and then the water stays as a puddle the crew's routines and Brasa's fire
## can both work with. What else a burst does is the DO pieces plugged into it (attack.gd). The
## host lands each burst after the same flight the peers draw.
const ANIMA_REACH: float = Attack.WEAPON["water"]["reach"]
const WeaponSpray = preload("res://scripts/survivor/weapon_spray.gd")
## Ánimas in the air: where each is headed, whose it is, and how long until it bursts.
var _flying: Array[Dictionary] = []
func _animas(player: Character, peer: int, clock: Dictionary, tools: Dictionary) -> void:
	var hit: Dictionary = Attack.profile(Build.attack_steps(builds[peer]), "water")
	var far: Array[Node3D] = targets(player, ANIMA_REACH + (3.0 if hit["aloft"] else 0.0))
	if far.is_empty(): return
	clock["shot"] = Attack.WEAPON["water"]["every"] * pow(0.82, tools["cadence"])
	var me: Vector3 = player.global_position
	for index: int in mini(1 + tools["split"], far.size()):
		var enemy: Node3D = far[index]
		_flying.append({"left": WeaponSpray.ANIMA_FLIGHT, "enemy": enemy, "at": enemy.global_position, "from": me,
				"peer": peer, "damage": Attack.WEAPON["water"]["damage"] + tools["power"] * Attack.WEAPON["water"]["power"], "lead": index == 0, "hit": hit})
		anima_fx.rpc(peer, str(enemy.name), enemy.global_position)
	if hit["slam"]: _lift(peer, player, far[0], hit)
	clock["puddle"] = float(clock.get("puddle", 0.0)) - clock["shot"]
	automations_fired += 1

## Host: the ánimas still in the air follow their machines and burst when their flight is up.
## Tests pass a long `delta` to land everything at once.
func _land_animas(delta: float) -> void:
	for flight: Dictionary in _flying.duplicate():
		var enemy: Node3D = flight["enemy"] if is_instance_valid(flight["enemy"]) else null
		if enemy != null and not enemy.down: flight["at"] = enemy.global_position
		flight["left"] -= delta
		if flight["left"] > 0.0: continue
		_flying.erase(flight)
		_anima_blast(flight, enemy)

## What the splash around the chased machine takes of the ánima's damage.
const ANIMA_SPLASH := 0.6
func _anima_blast(flight: Dictionary, struck: Node3D) -> void:
	var point: Vector3 = flight["at"]
	var peer: int = flight["peer"]
	var hit: Dictionary = flight.get("hit", Attack.profile([], "water"))
	var caught: Array[Node3D] = []
	for enemy: Node3D in get_tree().get_nodes_in_group("survivor_enemies"):
		if enemy.down: continue
		var gap: Vector3 = enemy.global_position - point
		var flat := Vector3(gap.x, 0, gap.z)
		# The machine it chased is always caught, even in the air; the splash spreads over the floor.
		if enemy != struck and (flat.length() > WeaponSpray.ANIMA_BLAST or absf(gap.y) > 1.6): continue
		caught.append(enemy)
	for enemy: Node3D in caught:
		if not is_instance_valid(enemy) or enemy.down: continue
		# The burst shoves out from where it broke; the one it chased, back from the operator.
		var origin: Vector3 = flight["from"] if enemy == struck else point
		# Water wets on the burst itself (hail after its cold, so it freezes what was already wet);
		# the one it chased takes the full shove, the rest of the splash only staggers.
		if hit["temp"] == 0: enemy.soak(Vector3.ZERO)
		var chased: bool = enemy == struck
		strike(peer, enemy, hit, origin, point, flight["damage"] * (1.0 if chased else ANIMA_SPLASH), caught, 5.0 if chased else 1.5)
		if hit["temp"] < 0 and is_instance_valid(enemy) and not enemy.down and enemy.frozen <= 0.0: enemy.soak(Vector3.ZERO)
	if flight["lead"] and clocks.has(peer) and float(clocks[peer].get("puddle", 0.0)) <= 0.0: _anima_puddle(peer, point)

## An ánima is rain: what it leaves lands on the yard as water anyone's routines can draw.
func _anima_puddle(peer: int, point: Vector3) -> void:
	point.y = 0.07
	if world.spill(point, 0.5) != 0: clocks[peer]["puddle"] = 2.6

## Drop after raise: a ball of the weapon's matter goes up from the operator's hands and comes
## down where the lead machine is headed, its shadow on the floor the whole way (attack.gd).
var _falling: Array[Dictionary] = []
func _lift(peer: int, player: Character, enemy: Node3D, hit: Dictionary) -> void:
	var clock: Dictionary = clocks[peer]
	if elapsed < float(clock.get("fall", -1.0)): return
	clock["fall"] = elapsed + Attack.FALL_EVERY
	var spot: Vector3 = enemy.global_position + Vector3(enemy.velocity.x, 0, enemy.velocity.z) * Attack.FALL_TIME
	spot.y = 0.07
	_falling.append({"left": Attack.FALL_TIME, "at": spot, "peer": peer, "hit": hit})
	spellwork.fall_fx.rpc(player.global_position, spot, hit["base"], Attack.FALL_TIME)

## Host: the balls in the air land when their time is up. Tests pass a long `delta`.
func _land_falls(delta: float) -> void:
	for fall: Dictionary in _falling.duplicate():
		fall["left"] -= delta
		if fall["left"] > 0.0: continue
		_falling.erase(fall)
		_fall(fall)

## A ball landing: a hit of the weapon's own on everything under it, flyers brought down with it.
func _fall(fall: Dictionary) -> void:
	var spot: Vector3 = fall["at"]
	var peer: int = fall["peer"]
	var hit: Dictionary = fall["hit"]
	var water: bool = hit["base"] == "water"
	var caught: Array[Node3D] = []
	for enemy: Node3D in get_tree().get_nodes_in_group("survivor_enemies"):
		if enemy.down: continue
		var gap: Vector3 = enemy.global_position - spot
		if Vector2(gap.x, gap.z).length() < Attack.FALL_RADIUS and gap.y > -1.0 and gap.y < Attack.FALL_HEIGHT + 1.0: caught.append(enemy)
	var damage: float = Attack.WEAPON[hit["base"]]["fall"] * (1.0 + builds[peer]["tools"]["power"] * 0.25)
	for enemy: Node3D in caught:
		if not is_instance_valid(enemy) or enemy.down: continue
		var flat := Vector3(enemy.global_position.x - spot.x, 0, enemy.global_position.z - spot.z)
		if enemy.airborne(): enemy.pulled("well", enemy.global_position)
		if water and hit["temp"] == 0: enemy.soak(flat.normalized() * 2.0)
		# Its own blow: what the weapon does lands with it, whenever the last hit was.
		if clocks.has(peer) and clocks[peer].has("struck"): clocks[peer]["struck"].erase(str(enemy.name))
		strike(peer, enemy, hit, spot, spot, damage * (1.0 - 0.4 * flat.length() / Attack.FALL_RADIUS), caught, 2.0)
		if water and hit["temp"] < 0 and is_instance_valid(enemy) and not enemy.down and enemy.frozen <= 0.0: enemy.soak(Vector3.ZERO)
	# Water stays where it fell, for anyone's routines; a cold ball is hail and leaves none.
	if water and hit["temp"] == 0: world.spill(spot, 0.5)

func cooldown(build: Dictionary, index: int) -> float:
	return Build.cooldown(build, index)

## Where the yard holds water from the start: burst mains and overflowing drains, each keeping a
## puddle full. A routine draws from water within reach of its operator, so these are the places
## a shift begins around; the fight then leaves its own puddles wherever its matter lands.
## Spots probed clear of the yard's props for a full puddle (7 x 5.4 m), spread so most of the
## paving is within a routine's reach of one.
const SOURCES: Array[Vector3] = [Vector3(-7.75, 0, -1.7), Vector3(-17, 0, -4), Vector3(14.5, 0, -8), Vector3(-14, 0, 15), Vector3(5, 0, 19.5), Vector3(18.5, 0, 13)]
## The yard's other stores, each a thing a crew would find there: oil drums burning, a substation
## transformer still live, junk heaps from the machines that came before. Probed clear like the
## water, away from it, two of each, so every kind is within reach from some part of the yard.
const STORES := {
	"fire": [Vector3(-15, 0, 6), Vector3(9, 0, 3)],
	"current": [Vector3(-7, 0, -11), Vector3(-2, 0, 12)],
	"scrap": [Vector3(3, 0, -5), Vector3(20, 0, 21)],
}
var _watered: bool = false
func open_sources() -> void:
	_watered = true
	for point: Vector3 in SOURCES: world.add_source(point + Vector3.UP * 0.05)
	for material: String in STORES:
		for point: Vector3 in STORES[material]: world.add_source(point + Vector3.UP * 0.05, material)

## Where and toward what a trigger fires, or null when its condition does not hold this tick.
func _placement(player: Character, clock: Dictionary, when: String, enemies: Array[Node3D]) -> Variant:
	var me: Vector3 = player.global_position
	var toward: Vector3 = Vector3.FORWARD
	if not enemies.is_empty():
		toward = enemies[0].global_position - me
		toward.y = 0
		toward = toward.normalized()
	match when:
		"cerca":
			# Near you: the mark if it is near, otherwise the nearest machine.
			for enemy: Node3D in enemies:
				var gap: Vector3 = enemy.global_position - me
				gap.y = 0
				if gap.length() > 9.0: continue
				return [me + gap.normalized() * 3.1, gap.normalized()]
			return null
		"cada":
			if enemies.is_empty(): return null
			return [enemies[0].global_position, toward]
		"rastro":
			if me.distance_to(clock["trail"]) < 4.0: return null
			clock["trail"] = me
			var behind: Vector3 = -Vector3(player.velocity.x, 0, player.velocity.z).normalized()
			if behind.is_zero_approx(): behind = -toward
			return [me + behind * 1.6, -behind]
		"grupo":
			var best: Array = []
			for enemy: Node3D in enemies:
				var near: Array = enemies.filter(func(other: Node3D) -> bool: return other.global_position.distance_to(enemy.global_position) < 3.5)
				if near.size() > best.size(): best = near
			if best.size() < 3: return null
			var center := Vector3.ZERO
			for enemy: Node3D in best: center += enemy.global_position
			center /= best.size()
			var away: Vector3 = center - me
			away.y = 0
			return [center, away.normalized()]
		"herido":
			if not clock.get("hurt", false): return null
			clock["hurt"] = false
			return [me + toward * 1.8, toward]
		"derribo":
			var fallen: Variant = spellwork.take_kill(me)
			if fallen == null: return null
			return [fallen, toward]
		"mano":
			# Where the player clicked, brought within reach.
			if not clock.has("cue"): return null
			var spot: Vector3 = clock["cue"]
			var reach := Vector3(spot.x - me.x, 0, spot.z - me.z)
			if reach.length() > Build.DRAW_REACH: spot = Vector3(me.x, 0, me.z) + reach.normalized() * Build.DRAW_REACH
			return [spot, reach.normalized() if reach.length() > 0.1 else toward]
		"charco":
			# A machine standing in water within reach: the routine works that very puddle.
			for enemy: Node3D in enemies:
				var puddle: int = wading(enemy, me)
				if puddle == 0: continue
				var at: Vector3 = world.records[puddle]["position"]
				var ahead: Vector3 = Vector3(at.x - me.x, 0, at.z - me.z)
				return [at, ahead.normalized() if ahead.length() > 0.1 else toward, puddle]
	# «echo» never fires on its own: the routine above fires it.
	return null

## The puddle `enemy` is standing in, if `me` could draw from it; 0 otherwise.
func wading(enemy: Node3D, me: Vector3) -> int:
	if enemy.airborne(): return 0
	for record: Dictionary in world.records.values():
		if not Catalog.drawable(record) or float(record.get("volume", 1.0)) < 0.99: continue
		if Vector2(record["position"].x - me.x, record["position"].z - me.z).length() > spellwork.DRAW_REACH: continue
		var gap: Vector3 = enemy.global_position - record["position"]
		if absf(gap.x) < record["size"].x * 0.5 and absf(gap.z) < record["size"].z * 0.5: return record["id"]
	return 0

## A routine built whole, at once, on water conjured at `point` (see spellwork.cast): for checks
## and captures. In play routines draw their water and take shape step by step. Returns its id.
func run_routine(peer: int, index: int, point: Vector3, toward: Vector3) -> int:
	return spellwork.cast(peer, index, point, toward)

func slow_factor(point: Vector3) -> float:
	var factor: float = 1.0
	for record: Dictionary in world.records.values():
		if record["material"] == "steam" and point.distance_to(record["position"]) < 3.0:
			factor = minf(factor, 1.0 - float(record.get("survivor_steam", 0.35)))
		elif record["shape"] == "patch" and absf(point.x - record["position"].x) < record["size"].x * 0.5 and absf(point.z - record["position"].z) < record["size"].z * 0.5:
			# Standing water drags, scrap underfoot more; a sheet of ice makes machines skid and
			# lose their footing. Fire and current do not hold anything back: they hurt instead.
			match record["material"]:
				"water": factor = minf(factor, 0.75)
				"scrap": factor = minf(factor, 0.65)
				"ice": factor = minf(factor, 0.45 if int(record.get("temp", -1)) <= -2 else 0.55)
	return factor

func spawn_near_player() -> void:
	if machines.get_child_count() >= 55: return
	var live: Array[Character] = []
	for player: Character in players():
		if not player.eliminated: live.append(player)
	if live.is_empty(): return
	var player: Character = live[_rng.randi_range(0, live.size() - 1)]
	var space: PhysicsDirectSpaceState3D = arena.get_world_3d().direct_space_state
	for attempt: int in 16:
		var angle: float = _rng.randf_range(-PI, PI)
		var point: Vector3 = player.global_position + Vector3(cos(angle), 0, sin(angle)) * _rng.randf_range(13, 19)
		point.y = 0.05
		# Constrain spawns to this district's paved yard and verify floor + free volume.
		if absf(point.x) > 26 or point.z < -15 or point.z > 28: continue
		var floor_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2, point - Vector3.UP * 2, 1))
		if floor_hit.is_empty() or floor_hit.normal.y < 0.9: continue
		var probe := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.7
		probe.shape = sphere
		probe.transform.origin = point + Vector3.UP * 0.8
		probe.collision_mask = 1 | 2 | 4
		if not space.intersect_shape(probe, 1).is_empty(): continue
		_serial += 1
		var kind: int = next_kind()
		spawn_machine.rpc(_serial, point, kind, 1.0 + elapsed / 300.0)
		machines_spawned += 1
		return
## The shift's cast, introduced one at a time so each new threat is learned before the next:
## quiltros from the start, repartidores at 0:25, leapers at 0:45, drinkers at 1:05 (once the crew has water down), divers at
## 1:25, animitas at 1:40. Specialists are capped so they punctuate the swarm, not replace it.
const ROSTER: Array = [
	# kind, unlocks at (s), one in N spawns, most alive at once
	[Enemy.HAULER, 100.0, 7, 99],
	[Enemy.DIVER, 85.0, 6, 4],
	[Enemy.DRINKER, 65.0, 8, 3],
	[Enemy.LEAPER, 45.0, 5, 6],
	[Enemy.RUNNER, 25.0, 3, 99],
]
func next_kind() -> int:
	var alive: Dictionary = {}
	for enemy: Node in machines.get_children(): alive[enemy.kind] = int(alive.get(enemy.kind, 0)) + 1
	for entry: Array in ROSTER:
		if elapsed > entry[1] and _serial % entry[2] == 0 and int(alive.get(entry[0], 0)) < entry[3]: return entry[0]
	return Enemy.PUMP
@rpc("authority", "call_local", "reliable")
func spawn_machine(id: int, point: Vector3, kind: int, strength: float) -> void:
	var key: String = "Machine%d" % id
	if machines.has_node(key): return
	var enemy := Enemy.create(kind)
	enemy.name = key
	enemy.run = self
	enemy.health *= strength
	enemy.position = point
	machines.add_child(enemy)
@rpc("authority", "call_local", "reliable")
func despawn_machine(key: String) -> void:
	if key == my_mark: my_mark = ""
	for peer: int in crew_marks.keys(): if crew_marks[peer] == key: crew_marks.erase(peer)
	var enemy := machines.get_node_or_null(key)
	if enemy != null:
		enemy.down = true
		enemy.queue_free()
## A specialist's phase change, replayed on every peer with the host's anchors.
@rpc("authority", "call_local", "reliable")
func machine_state(key: String, state: String, from: Vector3, to: Vector3, value: float) -> void:
	var enemy := machines.get_node_or_null(key)
	if enemy != null and not enemy.down: enemy.enter_state(state, from, to, value)
@rpc("authority", "call_local", "unreliable")
func machine_hit(key: String) -> void:
	var enemy := machines.get_node_or_null(key)
	if enemy != null: enemy.flash = 0.1
func machine_killed(point: Vector3, kind: int) -> void:
	kills += 1
	spellwork.note_kill(point)
	# What is left of it is scrap: half a draught where it fell, a whole one where two fell close.
	if world.residue: world.spill(point, 0.5, "scrap")
	machine_down_fx.rpc(point, kind)
	if pickups.get_child_count() >= 90:
		# Bound scene size without silently losing earned XP.
		gain_xp(Enemy.STATS[kind][2])
		return
	_pickup_serial += 1
	spawn_pickup.rpc(_pickup_serial, point, Enemy.STATS[kind][2])
@rpc("authority", "call_local", "unreliable")
func machine_down_fx(point: Vector3, kind: int) -> void:
	# A machine coming apart is the payoff of an automatic build: it has to read at a glance.
	var debris: Color = Enemy.STATS[kind][3]
	Sfx.of(self).at("crunch", point, 3.0 if kind in [Enemy.HAULER, Enemy.DRINKER] else 0.0)
	preload("res://scenes/actions/combat_fx.gd").burst(get_parent(), point + Vector3.UP * 0.7, debris)
	if kind in [Enemy.HAULER, Enemy.DRINKER]: get_tree().call_group("camera_shakers", "add_shake", 0.12)
@rpc("authority", "call_local", "reliable")
func spawn_pickup(id: int, point: Vector3, value: int) -> void:
	var key: String = "Scrap%d" % id
	if pickups.has_node(key): return
	var pickup := Pickup.new()
	pickup.name = key
	pickup.run = self
	pickup.value = value
	pickup.position = point
	pickups.add_child(pickup)
var _pick_run: int = 0
var _pick_at: float = -1.0
@rpc("authority", "call_local", "reliable")
func collect_pickup(key: String) -> void:
	var pickup := pickups.get_node_or_null(key)
	if pickup != null:
		# A quick run of pickups climbs the scale; a pause starts it over.
		var now: float = Time.get_ticks_msec() / 1000.0
		_pick_run = _pick_run + 1 if now - _pick_at < 0.35 else 0
		_pick_at = now
		Sfx.of(self).at("pick", pickup.global_position, 0.0, Sfx.note(0, _pick_run % Sfx.SCALE.size()))
		pickup.set_physics_process(false)
		pickup.queue_free()
func gain_xp(amount: int) -> void:
	if not multiplayer.is_server(): return
	xp += amount
	collected += amount
	if xp < Build.threshold(level) or phase != "running": return
	xp -= Build.threshold(level)
	level += 1
	offers.clear()
	for player: Character in players():
		if player.eliminated: continue
		var peer: int = player.get_multiplayer_authority()
		offers[peer] = Build.offers(builds[peer], _rng)
		player.receive_health.rpc(5.0 + builds[peer]["tools"]["repair"] * 5.0)
	publish()
	set_phase.rpc("upgrade")
## A level-up choice. A piece goes where the player asked in the same message: a routine index,
## or -1 for the box. The host re-derives the placement; the client only names it.
@rpc("any_peer", "call_local", "reliable")
func choose_upgrade(key: String, routine_index: int = -1, proposed: Dictionary = {}) -> void:
	if not multiplayer.is_server() or phase != "upgrade": return
	var peer: int = multiplayer.get_remote_sender_id()
	if peer == 0: peer = multiplayer.get_unique_id()
	if not offers.has(peer) or key not in offers[peer]: return
	var build: Dictionary = builds[peer]
	if Build.is_tool_key(key):
		build["tools"][key] += 1
		if key == "repair": world._player(peer).receive_health.rpc(35.0)
		if key == "slot" and build["routines"].size() < Build.MAX_ROUTINES: build["routines"].append(Build.empty_routine())
	else:
		# The node editor sends the whole rearranged build: it must hold exactly what was owned
		# plus the new piece.
		var boxed: Dictionary = Build.place(build, key, -1)
		if not proposed.is_empty() and Build.well_formed(proposed, build["routines"].size()) and Build.same_pieces(proposed, boxed):
			boxed["routines"] = proposed["routines"].duplicate(true)
			boxed["attack"] = proposed.get("attack", {"steps": []}).duplicate(true)
			boxed["box"] = proposed["box"].duplicate()
			builds[peer] = boxed
		else:
			var placed: Dictionary = Build.place(build, key, routine_index)
			builds[peer] = placed if not placed.is_empty() else boxed
		_note_changes(peer, build["routines"], builds[peer]["routines"])
	offers.erase(peer)
	publish()
	if offers.is_empty():
		set_phase.rpc("running")
		gain_xp(0)

## The workshop: a player rearranges pieces they already own. Same pieces in, same pieces out.
@rpc("any_peer", "call_local", "reliable")
func submit_build(proposed: Dictionary) -> void:
	if not multiplayer.is_server() or phase not in ["paused", "upgrade"]: return
	var peer: int = multiplayer.get_remote_sender_id()
	if peer == 0: peer = multiplayer.get_unique_id()
	if not builds.has(peer): return
	var current: Dictionary = builds[peer]
	if not Build.well_formed(proposed, current["routines"].size()) or not Build.same_pieces(proposed, current): return
	var next: Dictionary = current.duplicate(true)
	next["routines"] = proposed["routines"].duplicate(true)
	next["attack"] = proposed.get("attack", {"steps": []}).duplicate(true)
	next["box"] = proposed["box"].duplicate()
	builds[peer] = next
	_note_changes(peer, current["routines"], next["routines"])
	publish()

## Every routine that came out of an edit different and able to fire is queued to run once.
func _note_changes(peer: int, before: Array, after: Array) -> void:
	var queued: Array = trials.get(peer, [])
	for index: int in after.size():
		var was: Variant = before[index] if index < before.size() else null
		if after[index]["when"] == "" or after[index] == was or index in queued: continue
		queued.append(index)
	if not queued.is_empty():
		trials[peer] = queued
		_trial_in = TRIAL_GAP

## One queued trial every beat once play has resumed: where its WHEN would put it if it can say,
## otherwise on the nearest machine in sight, otherwise a few steps ahead. Cooldowns are untouched.
func _run_trials(delta: float) -> void:
	if trials.is_empty(): return
	_trial_in -= delta
	if _trial_in > 0.0: return
	_trial_in = TRIAL_GAP
	var peer: int = trials.keys()[0]
	var index: int = trials[peer].pop_front()
	if trials[peer].is_empty(): trials.erase(peer)
	var player: Character = world._player(peer) as Character
	if player == null or player.eliminated or not builds.has(peer) or index >= builds[peer]["routines"].size(): return
	var routine: Dictionary = builds[peer]["routines"][index]
	if routine["when"] == "": return
	var enemies: Array[Node3D] = targets(player)
	var clock: Dictionary = clocks[peer].duplicate()
	var placement: Variant = _placement(player, clock, routine["when"], enemies) if routine["when"] not in ["eco", "mano", "rastro", "herido", "derribo"] else null
	if placement == null:
		var me: Vector3 = player.global_position
		var ahead: Vector3 = Vector3(player.velocity.x, 0, player.velocity.z).normalized()
		if ahead.is_zero_approx(): ahead = Vector3.FORWARD
		if not enemies.is_empty() and enemies[0].global_position.distance_to(me) < Build.DRAW_REACH:
			ahead = Vector3(enemies[0].global_position.x - me.x, 0, enemies[0].global_position.z - me.z).normalized()
			placement = [enemies[0].global_position, ahead]
		else: placement = [me + ahead * 4.0, ahead]
	spellwork.begin(peer, index, placement[0], placement[1], 0, placement[2] if placement.size() > 2 else 0)

@rpc("authority", "call_local", "reliable")
func set_phase(value: String) -> void:
	if value == "upgrade" and phase == "running": Sfx.of(self).play("level")
	phase = value
	get_tree().paused = value != "running"
@rpc("any_peer", "call_local", "reliable")
func toggle_pause() -> void:
	if not multiplayer.is_server(): return
	if multiplayer.get_remote_sender_id() not in [0, 1]: return
	if phase in ["running", "paused"]: set_phase.rpc("paused" if phase == "running" else "running")
@rpc("any_peer", "call_local", "reliable")
func restart() -> void:
	if not multiplayer.is_server() or phase not in ["won", "lost"]: return
	if multiplayer.get_remote_sender_id() not in [0, 1]: return
	reload_match.rpc()
@rpc("authority", "call_local", "reliable")
func reload_match() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
@rpc("any_peer", "reliable")
func request_state() -> void:
	if multiplayer.is_server(): publish()
func publish() -> void:
	var enemy_positions: Dictionary = {}
	var pickup_positions: Dictionary = {}
	for enemy: Node3D in machines.get_children():
		enemy_positions[str(enemy.name)] = [enemy.global_position, enemy.velocity]
		# Temp, wet and charge ride along only on machines that have any.
		var props: int = enemy.props_code()
		if props != 0: enemy_positions[str(enemy.name)].append(props)
	for pickup: Node3D in pickups.get_children(): pickup_positions[str(pickup.name)] = pickup.global_position
	charges.clear()
	for peer: int in builds:
		var row: Array = []
		for index: int in builds[peer]["routines"].size():
			var full: float = cooldown(builds[peer], index)
			row.append(1.0 if full <= 0 else clampf(1.0 - float(clocks.get(peer, {}).get("r%d" % index, 0.0)) / full, 0, 1))
		charges[peer] = row
	sync_state.rpc(elapsed, kills, xp, level, builds, offers, charges, enemy_positions, pickup_positions)
@rpc("authority", "call_remote", "reliable")
func sync_state(time: float, count: int, experience: int, rank: int, loadouts: Dictionary, choices: Dictionary, charge: Dictionary, enemy_positions: Dictionary, pickup_positions: Dictionary) -> void:
	elapsed = time
	charges = charge
	kills = count
	xp = experience
	level = rank
	builds = loadouts
	offers = choices
	for player: Character in players(): player.move_multiplier = 1.0 + builds.get(player.get_multiplayer_authority(), {}).get("tools", {}).get("boots", 0) * 0.1
	for key: String in enemy_positions:
		var enemy := machines.get_node_or_null(key)
		if enemy != null:
			enemy.target_position = enemy_positions[key][0]
			enemy.velocity = enemy_positions[key][1]
			enemy.read_props(enemy_positions[key][2] if enemy_positions[key].size() > 2 else 0)
	for key: String in pickup_positions:
		var pickup := pickups.get_node_or_null(key)
		if pickup != null: pickup.position = pickup_positions[key]
## An ánima seen by every peer: the operator looses it toward `to`, and it chases the machine
## named `target` while that machine is there.
@rpc("authority", "call_local", "unreliable")
func anima_fx(peer: int, target: String, to: Vector3) -> void:
	var player: Character = world._player(peer)
	if player == null: return
	var worker := player.get_node_or_null("ShiftWorker")
	if worker != null: worker.spray(to, machines.get_node_or_null(target))

## The weapon seen by every peer: the operator turns and sprays toward `to`.
@rpc("authority", "call_local", "unreliable")
func weapon_fx(peer: int, to: Vector3) -> void:
	var player: Character = world._player(peer)
	if player == null: return
	var worker := player.get_node_or_null("ShiftWorker")
	if worker != null: worker.spray(to)
