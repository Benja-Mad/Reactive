## The host side of the crew's routines. Builds each routine's matter through the recipe table
## (the same one the editor reads), fires THEN reactions when their moment comes, carries relay
## pulses between routines, and applies what matter does to machines: wells pull, repulsors push,
## waves and rain soak, scalding steam burns.
extends Node
const Build = preload("res://scripts/survivor/build.gd")
const Recipe = preload("res://scripts/survivor/recipe.gd")
const Catalog = preload("res://scripts/matter/materials.gd")
const PULSE_SPEED := 9.0
var run: Node
var world: Node
## Relay pulses on their way: {"to": id, "left": seconds}.
var _pulses: Array[Dictionary] = []
## Records a pulse reached this frame; answered in `tick`, outside the world's own resolution.
var _arrived: Array[int] = []
var _splashes: Array[Vector3] = []
## Per repulsor record, the machines its front has already thrown.
var _thrown: Dictionary = {}
## Recent machine deaths, for «on kill»: {"point", "at" (msec)}.
var _kills: Array[Dictionary] = []
## Heat and conduction (see rules.gd); gravity by mass is in `_forces`.
var rules: Node
var _fx: Node3D

func _ready() -> void:
	world = run.world
	world.matter_event.connect(_on_event)
	rules = preload("res://scripts/survivor/rules.gd").new()
	rules.name = "Rules"
	rules.spellwork = self
	rules.world = world
	add_child(rules)
	if DisplayServer.get_name() != "headless":
		_fx = preload("res://scripts/survivor/fields_fx.gd").new()
		_fx.name = "FieldsFx"
		_fx.world = world
		_fx.machines = run.machines
		add_child(_fx)

## What a rule just did, drawn on every peer: an arc's path, a puff of steam, a crust of frost.
@rpc("authority", "call_local", "unreliable")
func rule_fx(kind: String, points: PackedVector3Array) -> void:
	if _fx != null: _fx.rule(kind, points)

## A weapon's ball going up from the operator at `from` and falling on `spot` in `time` seconds.
@rpc("authority", "call_local", "reliable")
func fall_fx(from: Vector3, spot: Vector3, base: String, time: float) -> void:
	if _fx != null: _fx.fall(from, spot, base, time)

func _on_event(event: Dictionary) -> void:
	if multiplayer.is_server() and event["kind"] == "splashed" and _splashes.size() < 32: _splashes.append(event["position"])
	if multiplayer.is_server() and event["kind"] == "released": _let_go(int(event["id"]), event["position"])
	if multiplayer.is_server() and event["kind"] == "pulsed" and _arrived.size() < 32: _arrived.append(int(event["id"]))

func note_kill(point: Vector3) -> void:
	# Shift time, not the wall clock: a pause or a faster soak keeps the window the same.
	_kills.append({"point": point, "at": run.elapsed})
	if _kills.size() > 16: _kills.pop_front()

## «on kill»: the freshest death within reach of `me`, consumed so it fires once.
func take_kill(me: Vector3) -> Variant:
	for index: int in range(_kills.size() - 1, -1, -1):
		var kill: Dictionary = _kills[index]
		if run.elapsed - float(kill["at"]) > 1.5: continue
		if Vector2(kill["point"].x - me.x, kill["point"].z - me.z).length() <= 10.0:
			_kills.remove_at(index)
			return kill["point"]
	return null

# --- Building a routine -------------------------------------------------------------------------

## A routine pours its matter from its operator's hands -- the Sereno's ward rains it, Brasa's
## arm burns it out -- or, for a trigger that names a puddle (`charco`), works that matter where it
## lies. The draught runs along the floor to where the routine acts, and there each DO step happens
## one beat after the last, with a beam from the operator for every energy it puts in.
const DRAW_REACH := Build.DRAW_REACH
const DRAW_SPEED := 18.0
const STEP_BEAT := 0.28
## Each beat of a routine as the world takes it, for the program in the corner to light the same
## piece at the same moment: "draw" (the trigger fired; the draught runs for `duration`), "step" or
## "idle" (DO number `k` acted, or found nothing to act on), "no" (a condition said no) and "skip"
## (the DO it skipped), "armed" (the THEN waits), "fire".
signal beat(peer: int, index: int, stage: String, k: int, duration: float)

@rpc("authority", "call_local", "unreliable")
func beat_fx(peer: int, index: int, stage: String, k: int, duration: float) -> void:
	beat.emit(peer, index, stage, k, duration)

## Matter from two of one player's routines acted on each other: the program joins the two rows.
signal combo(peer: int, a: int, b: int)
var _combo_at: Dictionary = {}

@rpc("authority", "call_local", "unreliable")
func combo_fx(peer: int, a: int, b: int, at: Vector3 = Vector3.INF) -> void:
	combo.emit(peer, a, b)
	# Where it happened, for the one whose routines met: an amber ring off the spot.
	if _fx != null and peer == multiplayer.get_unique_id() and at != Vector3.INF: _fx.combo(at)

## A machine felled by a routine's matter: that routine's number lights on its owner's plate and an
## amber ring goes off the wreck, so what the program achieved is seen where and in which row.
signal credited(peer: int, index: int)
@rpc("authority", "call_local", "reliable")
func credit_fx(peer: int, index: int, at: Vector3) -> void:
	if peer != multiplayer.get_unique_id(): return
	credited.emit(peer, index)
	if _fx != null: _fx.combo(at)

## A machine wet by a routine's matter remembers whose, so a later shock or freeze from another
## routine of the same player counts as a combo between the two.
func wet_by(enemy: Node3D, record: Dictionary) -> void:
	if record.has("routine") and is_instance_valid(enemy): enemy.set_meta("wet_by", {"owner": record["owner"], "routine": record["routine"]})

## The wet machine `enemy` was shocked or frozen by `record`: a combo if another routine wet it.
func wet_and(enemy: Node3D, record: Dictionary) -> void:
	if record.is_empty() or not is_instance_valid(enemy) or not enemy.wet() or not enemy.has_meta("wet_by"): return
	linked(enemy.get_meta("wet_by"), record, enemy.global_position)

## Called by the rules when `one` and `other` reacted: if they came from two different routines of
## the same player, that player's program shows it (once a second per pair at most).
func linked(one: Dictionary, other: Dictionary, at: Variant = null) -> void:
	if not one.has("routine") or not other.has("routine") or one["owner"] != other["owner"]: return
	var a: int = int(one["routine"])
	var b: int = int(other["routine"])
	if a == b: return
	var key: String = "%d:%d:%d" % [int(one["owner"]), mini(a, b), maxi(a, b)]
	if run.elapsed < float(_combo_at.get(key, -INF)): return
	_combo_at[key] = run.elapsed + 1.0
	rules.count("combos")
	if at == null: at = other.get("position", one.get("position", Vector3.ZERO))
	combo_fx.rpc(int(one["owner"]), mini(a, b), maxi(a, b), at)

## Routines under way: {"peer", "index", "point", "toward", "depth", "left", "id", "steps", "then", "on"}.
## `id` is 0 while the drawn water is still running to its spot.
var _casts: Array[Dictionary] = []

## A routine fired in play. Returns "" when it is under way, or "blocked" when there is nowhere to
## put it; then nothing is poured.
## `source` names a puddle to work in place, for a trigger that already chose one.
func begin(peer: int, index: int, point: Vector3, toward: Vector3, depth: int = 0, source: int = 0) -> String:
	var routine: Dictionary = run.builds[peer]["routines"][index]
	var substance: String = routine.get("from", "water")
	point.y = 0.07
	if not world.preview(peer, "create", 0, {"point": point, "material": substance}).get("ok", false): return "blocked"
	var player: Node3D = world._player(peer)
	if player == null: return "blocked"
	var from: Variant = null
	if source != 0 and world.records.has(source) and Catalog.drawable(world.records[source], substance): from = world.draw_from(source)
	if from == null: from = Vector3(player.global_position.x, 0.07, player.global_position.z)
	var travel: float = maxf(0.15, _flat(point - from).length() / DRAW_SPEED)
	stream_fx.rpc(from, point, travel, substance)
	beat_fx.rpc(peer, index, "draw", 0, travel)
	_casts.append({"k": 0, "peer": peer, "index": index, "point": point, "toward": toward, "depth": depth, "left": travel, "id": 0, "material": substance,
		"steps": routine["steps"].duplicate(), "then": routine["then"], "on": routine.get("on", "contact")})
	run.automations_fired += 1
	return ""

## Every cast under way, one beat at a time: the water lands, then each step acts, then the THEN
## is armed and an echo below begins.
func _advance(delta: float) -> void:
	for cast: Dictionary in _casts.duplicate():
		cast["left"] -= delta
		if cast["left"] > 0.0: continue
		var peer: int = cast["peer"]
		if cast["id"] == 0:
			var made: Dictionary = world.execute(peer, "create", 0, {"point": cast["point"], "material": cast["material"]})
			if not made.get("ok", false):
				# The water (or scrap) got there all the same: it stays on the floor.
				if cast["material"] in ["water", "scrap"]: world.spill(cast["point"], 1.0, cast["material"])
				_casts.erase(cast)
				continue
			cast["id"] = made["id"]
			world.records[cast["id"]]["ttl"] = MATTER_TTL
			world.records[cast["id"]]["routine"] = cast["index"]
			world.records[cast["id"]]["forming"] = true
			cast["left"] = STEP_BEAT * 0.6
			continue
		var id: int = cast["id"]
		if not world.records.has(id) or not run.builds.has(peer):
			_casts.erase(cast)
			continue
		if not cast["steps"].is_empty():
			var key: String = cast["steps"].pop_front()
			var stage: String = "idle"
			if cast.get("skip", false):
				# A no skips the DO it guards, and any conditions stacked before that DO with it.
				if not Recipe.GATES.has(key): cast.erase("skip")
				stage = "skip"
			elif Recipe.GATES.has(key):
				stage = "step" if gate(key, id) else "no"
				rules.count("gate_yes" if stage == "step" else "gate_no")
				if stage == "no": cast["skip"] = true
			elif _apply_step(peer, id, key, cast["toward"], true): stage = "step"
			beat_fx.rpc(peer, cast["index"], stage, cast["k"], STEP_BEAT)
			cast["k"] += 1
			cast["left"] = STEP_BEAT
			continue
		_casts.erase(cast)
		if not world.records.has(id): continue
		world.records[id].erase("forming")
		_arm(peer, cast["index"], id, cast["then"], cast["on"], cast["toward"])
		if cast["then"] != "": beat_fx.rpc(peer, cast["index"], "armed", cast["k"], 0.0)
		var routines: Array = run.builds[peer]["routines"]
		var below: int = cast["index"] + 1
		if cast["depth"] < Build.MAX_ROUTINES and below < routines.size() and routines[below]["when"] == "eco":
			begin(peer, below, world.records[id]["position"] + cast["toward"] * 2.5 if world.records.has(id) else cast["point"], cast["toward"], cast["depth"] + 1)

## Whether `peer` has a routine still taking shape.
func casting(peer: int) -> bool:
	for cast: Dictionary in _casts: if cast["peer"] == peer: return true
	return false

## One DO step compiled against the matter as it is now. Paced, a push is aimed when it happens
## (at the operator's mark nearby, else the machine nearest the matter, see `_aim`), and the operator's beam shows where the energy came from.
## Returns whether it changed the matter.
func _apply_step(peer: int, id: int, key: String, toward: Vector3, paced: bool = false) -> bool:
	var plan: Dictionary = Recipe.step(Recipe.state_of(world.records[id]), key)
	if plan["op"] == "": return false
	var at: Vector3 = world.records[id]["position"]
	var heading: Vector3 = _aim(at, toward, peer, null, false) if paced and plan["op"] in ["push", "slide"] else toward
	var vector: Vector3 = toward.cross(Vector3.UP) * 4.0 if plan["op"] == "wall" else heading * 9.0
	var before: Dictionary = world.records[id].duplicate()
	if paced and key in TETHERED: tether_fx.rpc(key, peer, at + Vector3.UP * (0.9 if before.get("suspended", false) else 0.2))
	if not world.execute(peer, plan["op"], id, {"vector": vector}).get("ok", false): return false
	_after_step(plan["op"], before, id)
	return true

## A DO gate's answer, now: whether a machine within reach of the matter is as it asks.
const GATE_REACH := 4.0
func gate(key: String, id: int) -> bool:
	if not world.records.has(id): return false
	# Any living crewmate's mark counts: one points, another's routine strikes.
	var marks: Array = []
	for peer: int in run.clocks:
		var mark: Variant = run.clocks[peer].get("mark")
		var body: Character = world._player(peer) as Character
		if mark != null and is_instance_valid(mark) and body != null and not body.eliminated: marks.append(mark)
	for enemy: Node3D in _enemies_near(world.records[id]["position"], GATE_REACH, true):
		match key:
			"si_marcada": if enemy in marks: return true
			"si_mojada": if enemy.wet(): return true
			"si_arde": if enemy.temp >= 1: return true
	return false

## Steps that put the operator's own energy into the matter, drawn as a beam from them to it.
const TETHERED := ["cold", "fire", "arc", "coat", "push", "well", "repel"]

## The finished matter armed with its THEN, and remembered as this routine's for a relay.
func _arm(peer: int, index: int, id: int, then: String, on: String, toward: Vector3) -> void:
	if not run.clocks[peer].has("made"): run.clocks[peer]["made"] = {}
	run.clocks[peer]["made"][index] = id
	if not world.records.has(id): return
	var record: Dictionary = world.records[id]
	if record["material"] == "steam": record["survivor_steam"] = 0.5
	if record["material"] in ["ice", "scrap"] and record["shape"] != "fragments": record["integrity"] = (20.0 + record["size"].y * 4.0) * (world.HARD_INTEGRITY if Catalog.hard(record) else 1.0)
	if then != "":
		# `trigger` is not a world event, so the generic scheduler leaves it to this script;
		# the construct still shows itself armed.
		record["reaction"] = {"trigger": "survivor", "action": then, "vector": toward * 14.0, "routine": index, "on": on, "after": Recipe.REACTION_DELAY}
		if then == "cadena": _wire(peer, index, id)
	world._dirty = true

## The whole routine at once, on water conjured at `point`: what the checks and captures use to
## look at a routine's result without waiting for it. Play goes through `begin`. Returns the id.
func cast(peer: int, index: int, point: Vector3, toward: Vector3, depth: int = 0) -> int:
	var routines: Array = run.builds[peer]["routines"]
	var routine: Dictionary = routines[index]
	point.y = 0.07
	var created: Dictionary = world.execute(peer, "create", 0, {"point": point, "material": routine.get("from", "water")})
	if not created.get("ok", false): return 0
	var id: int = created["id"]
	world.records[id]["ttl"] = MATTER_TTL
	world.records[id]["routine"] = index
	var skip: bool = false
	for key: String in routine["steps"]:
		if not world.records.has(id): break
		if skip: skip = Recipe.GATES.has(key)
		elif Recipe.GATES.has(key): skip = not gate(key, id)
		else: _apply_step(peer, id, key, toward)
	run.automations_fired += 1
	_arm(peer, index, id, routine["then"], routine.get("on", "contact"), toward)
	# An echo below fires right after, a little further along.
	if depth < Build.MAX_ROUTINES and index + 1 < routines.size() and routines[index + 1]["when"] == "eco":
		cast(peer, index + 1, point + toward * 2.5, toward, depth + 1)
	return id

## A draught running along the floor from where it was drawn to where a routine acts: water,
## a trail of burning fuel, current crawling over the paving, scrap dragged scraping.
@rpc("authority", "call_local", "unreliable")
func stream_fx(from: Vector3, to: Vector3, duration: float, substance: String = "water") -> void:
	if _fx != null: _fx.stream(from, to, duration, substance)

## The operator putting a step's energy into the matter at `to`.
@rpc("authority", "call_local", "unreliable")
func tether_fx(key: String, peer: int, to: Vector3) -> void:
	var player: Node3D = world._player(peer)
	if _fx != null and player != null: _fx.tether(key, player.global_position + Vector3.UP * 0.2, to)

## What a step does to machines, on top of what it did to the matter.
func _after_step(op: String, before: Dictionary, id: int) -> void:
	var at: Vector3 = world.records[id]["position"] if world.records.has(id) else before["position"]
	match op:
		"drop":
			var radius: float = 2.6 if before["shape"] == "wall" else Recipe.DROP_SOAK_RADIUS
			match before["material"]:
				"water", "steam":
					for enemy: Node3D in _enemies_near(at, radius):
						enemy.soak(_flat(enemy.global_position - at).normalized() * 2.0)
						wet_by(enemy, before)
				"fire":
					for enemy: Node3D in _enemies_near(at, 2.6): rules.light(enemy)
				"current":
					# Current brought down to the floor goes to ground through all of them at once.
					rules.shock_around(at, radius, _enemies_near(at, radius), Catalog.temp_of(before) >= 1)
					if world.records.has(id): world.spend(id)

## The conduit a relay pulse will travel, drawn as soon as both ends exist.
func _wire(peer: int, index: int, id: int) -> int:
	var target: int = Build.relay_target(run.builds[peer]["routines"], index)
	if target < 0: return 0
	var other: int = int(run.clocks[peer].get("made", {}).get(target, 0))
	if other == id or not world.records.has(other): return 0
	if world.records[id].get("link", 0) != other: world.execute(peer, "link", id, {"to": other, "remote": true})
	return other if world.records[id].get("link", 0) == other else 0

# --- Every tick ---------------------------------------------------------------------------------

func tick(delta: float) -> void:
	_advance(delta)
	for point: Vector3 in _splashes: _splash(point, 2.0, 0.0)
	_splashes.clear()
	for index: int in range(_pulses.size() - 1, -1, -1):
		var pulse: Dictionary = _pulses[index]
		pulse["left"] -= delta
		if pulse["left"] > 0.0: continue
		_pulses.remove_at(index)
		world.deliver_pulse(pulse["to"])
	var arrived: Array[int] = _arrived.duplicate()
	_arrived.clear()
	for id: int in arrived:
		if not world.records.has(id): continue
		var reaction: Dictionary = world.records[id].get("reaction", {})
		if reaction.get("trigger", "") == "survivor" and reaction.get("on", "contact") == "pulse": fire(id)
		
	for id: int in world.records.keys():
		if not world.records.has(id): continue
		var record: Dictionary = world.records[id]
		if record.get("reaction", {}).get("trigger", "") == "survivor":
			record["reaction"]["after"] = float(record["reaction"].get("after", Recipe.REACTION_DELAY)) - delta
		if record.get("reaction", {}).get("trigger", "") == "survivor" and _moment(record):
			fire(id)
			if not world.records.has(id): continue
		_forces(record, delta)
	for id: int in _thrown.keys():
		if not world.records.has(id) or Catalog.field(world.records[id]) != "repel": _thrown.erase(id)
	var live: Array[Node3D] = []
	for enemy: Node3D in get_tree().get_nodes_in_group("survivor_enemies"): if not enemy.down: live.append(enemy)
	rules.tick(delta, live)

## How near the click armed matter must stand for that click to let it go.
const RELEASE_RADIUS := 5.0
## How long a routine's matter lives on the floor unless something else keeps it.
const MATTER_TTL := 12.0

## The THENs of `peer`'s matter armed «on click» and standing long enough, let go at once
## (run.cue): those within RELEASE_RADIUS of `at`, or all of them when `at` is null.
func release(peer: int, at: Variant = null) -> int:
	var let_go: int = 0
	for id: int in world.records.keys():
		if not world.records.has(id): continue
		var record: Dictionary = world.records[id]
		if not Recipe.click_ready(record, peer): continue
		if at != null and _flat(record["position"] - at).length() > RELEASE_RADIUS: continue
		fire(id, at)
		let_go += 1
	return let_go

## Whether this record's THEN should fire now.
func _moment(record: Dictionary) -> bool:
	match record["reaction"].get("on", "contact"):
		"contact": return _touched(record)
		"broken": return record["shape"] == "fragments"
		"timer": return float(record["reaction"].get("after", 1.0)) <= 0.0
		"mano": return float(record["reaction"].get("after", 0.0)) <= Recipe.REACTION_DELAY - Recipe.CLICK_STALE and _touched(record)
	return false # A relay explicitly delivers the pulse.

func _touched(record: Dictionary) -> bool:
	var inverse: Basis = Basis(Vector3.UP, record["yaw"]).inverse()
	for enemy: Node3D in _enemies_near(record["position"], 3.2):
		var local: Vector3 = inverse * (enemy.global_position - record["position"])
		match record["shape"]:
			"orb": if Vector2(local.x, local.z).length() < Catalog.ORB_SIZE.x * 0.5 + 0.45: return true
			"wall": if absf(local.x) < 2.3 and absf(local.z) < 1.0: return true
			"patch": if absf(local.x) < record["size"].x * 0.5 + 0.3 and absf(local.z) < record["size"].z * 0.5 + 0.3: return true
			_: if Vector2(local.x, local.z).length() < 2.4: return true
	return false

## What standing matter does to machines around it, every tick.
func _forces(record: Dictionary, delta: float) -> void:
	var at: Vector3 = record["position"]
	var field: String = Catalog.field(record)
	if field == "well":
		# Caught machines go round the ring with the matter; a specialist busy with its own motion
		# answers for itself (see enemy.pulled).
		var center: Vector3 = Catalog.field_center(record)
		for enemy: Node3D in _enemies_near(center, Catalog.VORTEX_REACH, true):
			if enemy.pulled(field, center) or enemy.airborne(): continue
			enemy.shove = Catalog.orbit_velocity(enemy.shove, center, enemy.global_position, delta, Catalog.gravity(record))
	elif field == "repel":
		# The front throws each machine once as it passes; then the bubble keeps them out.
		var center: Vector3 = Catalog.field_center(record)
		var front: float = Catalog.wave_front(float(record.get("wave_age", 0.0)))
		var thrown: Dictionary = _thrown.get(record["id"], {})
		_thrown[record["id"]] = thrown
		for enemy: Node3D in _enemies_near(center, Catalog.BLAST_REACH, true):
			if enemy.pulled(field, center) or enemy.airborne(): continue
			var gap: Vector3 = _flat(enemy.global_position - center)
			if not thrown.has(enemy) and gap.length() <= front:
				thrown[enemy] = true
				enemy.shove = Catalog.blast_velocity(center, enemy.global_position)
			elif thrown.has(enemy) and gap.length() < Catalog.BUBBLE:
				enemy.shove = enemy.shove.move_toward(gap.normalized() * 4.5, Catalog.FIELD_ACCEL * delta)
	if record.get("sliding", false) and record["material"] == "water":
		for enemy: Node3D in _enemies_near(at, 2.0):
			if enemy.soaked < 0.6:
				enemy.soak(_flat(record["velocity"]).normalized() * 4.0)
				wet_by(enemy, record)
	# A tongue of fire lights what it runs over.
	if record.get("sliding", false) and record["material"] == "fire":
		for enemy: Node3D in _enemies_near(at, 2.0):
			if enemy.temp < 2: rules.light(enemy)

# --- Reactions ----------------------------------------------------------------------------------

## A record's THEN, now. The reaction is spent before it acts, so nothing fires twice.
## `aim_at`: where the click that let it go landed, so its throw goes at the machine there.
func fire(id: int, aim_at: Variant = null) -> void:
	var record: Dictionary = world.records[id]
	var reaction: Dictionary = record["reaction"]
	record.erase("reaction")
	world._dirty = true
	beat_fx.rpc(int(record["owner"]), int(reaction.get("routine", -1)), "fire", 0, 0.0)
	rules.discharge(record)
	match reaction["action"]:
		"fragmentos": _shrapnel(id, reaction["vector"], aim_at)
		"estallar": _burst(id)
		"detonar": _detonate(id)
		"colapso":
			world.execute(record["owner"], "well", id, {"time": 1.0, "remote": true})
			# A short hard whirl; letting go flings it all (see _let_go).
			if world.records.has(id): world.records[id]["grav_power"] = 2.5
		"cadena":
			_relay(id, int(reaction.get("routine", -1)))

func _shrapnel(id: int, fallback: Vector3, aim_at: Variant = null) -> void:
	var record: Dictionary = world.records[id]
	var peer: int = record["owner"]
	match record["material"]:
		"ice":
			if record["shape"] != "fragments": world.damage_construct(id, 999.0)
			if world.records.has(id): world.execute(peer, "push", id, {"vector": _aim(record["position"], fallback, peer, aim_at) * 14.0, "remote": true})
		"water":
			_splash(record["position"], Recipe.SPLASH_RADIUS, 3.0)
			world.spend(id)
		"steam":
			_gust(id)
			if world.records.has(id): world.execute(peer, "push", id, {"vector": _aim(record["position"], fallback, peer, aim_at) * 9.0, "remote": true})
		"scrap":
			# Shrapnel: the scrap breaks and its pieces fly where `_aim` says (click, mark, else nearest).
			if record["shape"] != "fragments": world.damage_construct(id, 999.0)
			if world.records.has(id): world.execute(peer, "push", id, {"vector": _aim(record["position"], fallback, peer, aim_at) * 16.0, "remote": true})
		"fire":
			# Sparks thrown out: every dry machine around catches.
			spark_fx.rpc(record["position"], Recipe.SPLASH_RADIUS)
			for enemy: Node3D in _enemies_near(record["position"], Recipe.SPLASH_RADIUS): rules.light(enemy)
			world.spend(id)
		"current":
			# Let go: it jumps machine to machine until its charge is gone.
			while world.records.has(id) and int(world.records[id].get("charge", 0)) > 0:
				var before: int = int(world.records[id]["charge"])
				rules.discharge(world.records[id])
				if world.records.has(id) and int(world.records[id].get("charge", 0)) == before: break
			if world.records.has(id): world.spend(id)

## Radial: everything around takes the hit and is thrown out; the matter is spent.
func _burst(id: int) -> void:
	if not world.records.has(id): return
	var record: Dictionary = world.records[id]
	var was: Dictionary = world.culprit
	world.culprit = record
	_burst_blow(id, record)
	world.culprit = was

func _burst_blow(id: int, record: Dictionary) -> void:
	var at: Vector3 = record["position"]
	if record["material"] == "water": _splash(at, Recipe.BURST_RADIUS, 0.0)
	elif record["material"] == "current": rules.shock_around(at, Recipe.BURST_RADIUS, _enemies_near(at, Recipe.BURST_RADIUS), Catalog.temp_of(record) >= 1)
	else:
		for enemy: Node3D in _enemies_near(at, Recipe.BURST_RADIUS):
			var away: Vector3 = _flat(enemy.global_position - at)
			if record["material"] in ["ice", "scrap"]: enemy.take_damage(Catalog.impact(record, 6.0))
			elif record["material"] == "fire": rules.light(enemy)
			elif Catalog.scald(record): enemy.take_damage(Recipe.GUST_DAMAGE)
			if is_instance_valid(enemy) and not enemy.down: enemy.shove += away.normalized() * 6.0
	world.announce_burst(id)
	if not world.records.has(id): return
	if record["material"] in ["ice", "scrap"] and record["shape"] != "fragments": world.damage_construct(id, 999.0)
	elif record["material"] not in ["ice", "scrap"]: world.spend(id)

## Sparks flying out of a fire let go, drawn on every peer.
@rpc("authority", "call_local", "unreliable")
func spark_fx(at: Vector3, radius: float) -> void:
	if _fx != null: _fx.sparks(at, radius)

func _splash(at: Vector3, radius: float, damage: float) -> void:
	for enemy: Node3D in _enemies_near(at, radius):
		var away: Vector3 = _flat(enemy.global_position - at)
		enemy.take_damage(damage)
		if is_instance_valid(enemy) and not enemy.down: enemy.soak((away.normalized() if away.length() > 0.1 else Vector3.RIGHT) * 8.0)

func _gust(id: int) -> void:
	var at: Vector3 = world.records[id]["position"]
	var was: Dictionary = world.culprit
	world.culprit = world.records[id]
	for enemy: Node3D in _enemies_near(at, Recipe.SPLASH_RADIUS):
		var away: Vector3 = _flat(enemy.global_position - at)
		if Catalog.scald(world.records[id]): enemy.take_damage(Recipe.GUST_DAMAGE)
		if is_instance_valid(enemy) and not enemy.down: enemy.shove += (away.normalized() if away.length() > 0.1 else Vector3.RIGHT) * 6.0
	world.culprit = was

## A well letting go (world event "released"): the machines riding its ring fly off along it,
## into whatever stands there, and the well's own matter is flung out with them -- water splashes,
## fire scatters burning, scrap and ice break into what is round them, current discharges. A wall
## was only ever the heart of the whirl and stays standing.
func _let_go(id: int, at: Vector3) -> void:
	var center := Vector3(at.x, at.y, at.z)
	if world.records.has(id): center = Catalog.field_center(world.records[id])
	for enemy: Node3D in _enemies_near(center, Catalog.VORTEX_RING + Catalog.RING_BAND * 1.5):
		if enemy.pulled("well", center): continue
		enemy.shove = Catalog.sling(center, enemy.global_position)
		# Whose whirl threw it, for a bowl it makes in the next moments (rules.bowl).
		if world.records.has(id): enemy.set_meta("flung_by", [{"owner": world.records[id].get("owner", 0), "routine": world.records[id].get("routine", -1)}, run.elapsed])
	rules.count("slung")
	rule_fx.rpc("sling", PackedVector3Array([center]))
	if world.records.has(id) and world.records[id]["shape"] != "wall": _burst(id)

func _detonate(id: int) -> void:
	if world.records.has(id) and world.records[id]["attachments"].has("nanites"):
		world.execute(world.records[id]["owner"], "command", id, {"command": "detonate", "remote": true})

func _relay(id: int, routine: int) -> void:
	if not world.records.has(id) or routine < 0: return
	var peer: int = world.records[id]["owner"]
	if not run.builds.has(peer): return
	var other: int = _wire(peer, routine, id)
	if other == 0: return
	var travel: float = world.announce_pulse(id, other)
	if travel > 0.0 and _pulses.size() < 32: _pulses.append({"to": other, "left": travel})

# --- Helpers ------------------------------------------------------------------------------------

## Machines within `radius` of `at`, flat. `aloft` also takes flyers and leapers overhead.
func _enemies_near(at: Vector3, radius: float, aloft: bool = false) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for enemy: Node3D in get_tree().get_nodes_in_group("survivor_enemies"):
		if enemy.down or (enemy.airborne() and not aloft): continue
		var gap: Vector3 = enemy.global_position - at
		if Vector2(gap.x, gap.z).length() < radius and absf(gap.y) < (6.0 if aloft else 2.5): found.append(enemy)
	return found

## Toward the machine nearest `from`, flat; `fallback` when there is none.
## Where a throw from `from` goes: at the machine `peer` clicked (`at`), else at their own mark if
## it stands within MARK_STEER of the matter, else at the machine nearest the matter. When the
## click or the mark chose a THEN's throw, a thin amber thread shows it, so the turn has a cause; a
## DO step's push (`shown` false) turns quietly, since it already has the operator's beam.
func _aim(from: Vector3, fallback: Vector3, peer: int = 0, at: Variant = null, shown: bool = true) -> Vector3:
	var best: Node3D = run.machine_at(at) if at != null else null
	if best == null and peer != 0 and run.clocks.has(peer):
		var mark: Variant = run.clocks[peer].get("mark")
		if mark != null and is_instance_valid(mark) and not mark.down and _flat(mark.global_position - from).length() <= MARK_STEER: best = mark
	if best != null and shown:
		rules.count("aimed")
		aimed_fx.rpc(from, best.global_position)
	else:
		for enemy: Node3D in get_tree().get_nodes_in_group("survivor_enemies"):
			if enemy.down: continue
			if best == null or enemy.global_position.distance_squared_to(from) < best.global_position.distance_squared_to(from): best = enemy
	var aim: Vector3 = _flat(best.global_position - from) if best != null else _flat(fallback)
	return aim.normalized() if aim.length() > 0.05 else Vector3.FORWARD

## How far from the matter a player's mark still pulls its throws; past it, the nearest machine.
const MARK_STEER := 9.0

## The thread from matter to the machine a click or a mark sent it at, drawn on every peer.
@rpc("authority", "call_local", "unreliable")
func aimed_fx(from: Vector3, to: Vector3) -> void:
	if _fx != null: _fx.aimed(from, to)

static func _flat(value: Vector3) -> Vector3:
	return Vector3(value.x, 0.0, value.z)
