## The four rules matter and machines share, on the host: heat, conduction, fields and
## impulse. Each substance acts on its own through them: fire lights what it touches and a burning
## machine lights its neighbours; current looks for the nearest body and is spent a discharge at a
## time; scrap carries charge and holds heat; and matter touching matter reacts too -- water puts
## fire out and boils, fire heats scrap red, heat or a discharge sets nanites off. Nothing here names a combination: a frozen pack or an electrified cloud comes out of
## the properties both sides carry (temp, wet, charge, grav, mass; see materials.gd and the TAGS in
## enemy.gd). The editor reads `touch` to say what a routine's matter will do to what it touches,
## from these same numbers. Gravity runs every frame in spellwork._forces and impulse where things
## move (world_matter, enemy._impact); heat and conduction run here on a half-second beat, with a
## cap on reactions per beat so nothing feeds itself forever.
extends Node
const Catalog = preload("res://scripts/matter/materials.gd")
const TICK := 0.5
## Reactions per beat, all rules together.
const CAP := 64
const SCALD_DAMAGE := 2.5
const BURN_DAMAGE := 1.0
## Heat that melts ice: what the animita's candles did by hand, now any machine burning at +2.
const FREEZE_TIME := 1.0
## Seconds a machine holds a temp before stepping one back toward its rest.
const HOLD := 2.0
const JUMP := 2.8
const MAX_JUMPS := 6
const ARC_DAMAGE := 5.0
## Materials a charge runs through; dry flesh, wax and stone stop it (they still take the first hit).
const CONDUCTORS := ["metal", "agua"]
const BURNS := ["carne", "metal"]
## A burning machine lights the ones beside it, unless they are wet.
const SPREAD := 1.9
const IGNITE_DAMAGE := 3.0
## A machine that has burned is charred for a while and will not catch again from its
## neighbours, so a fire runs through a pack once instead of feeding on it forever. Spreading
## has its own cap per beat, so a burning pack never starves the other rules.
const CHAR_TIME := 8.0
const SPREAD_CAP := 8
## Current looks for ground: it reaches this far for the nearest body, further when it is cold.
const SEEK := 4.5
const COLD_SEEK := 2.5
## Matter a charge runs through on the floor: water, metal, ionised air.
const CONDUCTIVE := ["water", "scrap", "fire", "current"]
var spellwork: Node
var world: Node
## Off only for measuring: the soak run compares a shift with and without heat and conduction.
var enabled: bool = true
var _clock: float = 0.0
var _budget: int = 0
var _contact_frame: int = -1
var _contact_budget: int = CAP
## Machine -> msec until which it is charred (see CHAR_TIME).
var _charred: Dictionary = {}

## A contact reaction must release stored charge before it consumes the carrier. This uses
## its own bounded per-frame budget, so a half-second thermal beat cannot swallow the arc.
func discharge(record: Dictionary) -> void:
	if not enabled or int(record.get("charge", 0)) <= 0: return
	var frame: int = Engine.get_physics_frames()
	if frame != _contact_frame:
		_contact_frame = frame
		_contact_budget = CAP
	var saved: int = _budget
	_budget = _contact_budget
	var live: Array[Node3D] = []
	for enemy: Node3D in get_tree().get_nodes_in_group("survivor_enemies"):
		if not enemy.down: live.append(enemy)
	_conduct(record, live)
	_contact_budget = _budget
	_budget = saved
## Running totals, for the checks and the soak run.
var stats: Dictionary = {"scalded": 0, "frozen": 0, "dried": 0, "melted": 0, "boiled": 0, "chilled": 0, "arcs": 0, "jumps": 0, "longest": 0, "impacts": 0, "capped": 0,
	"ignited": 0, "spread": 0, "quenched": 0, "reddened": 0, "detonated": 0, "grounded": 0, "crushed": 0, "bowled": 0,
	"flared": 0, "overloaded": 0, "electrified": 0, "iced": 0, "shrapnel": 0}

func count(what: String, amount: int = 1) -> void:
	stats[what] = int(stats.get(what, 0)) + amount

static func conducts(enemy: Node3D) -> bool:
	return enemy.tag("material") in CONDUCTORS or enemy.wet()

## One beat of heat and conduction. Gravity and impulse are continuous and live elsewhere.
func tick(delta: float, enemies: Array[Node3D]) -> void:
	if not enabled: return
	for enemy: Node3D in enemies:
		enemy.charge_hold -= delta
		if enemy.charge > 0 and enemy.charge_hold <= 0.0: enemy.charge = 0
	_clock -= delta
	if _clock > 0.0: return
	_clock = TICK
	_budget = CAP
	for enemy: Node3D in enemies: _settle(enemy)
	_spread(enemies)
	_contact(enemies)
	_ring(enemies)
	for id: int in world.records.keys():
		if not world.records.has(id): continue
		var record: Dictionary = world.records[id]
		if int(record.get("charge", 0)) > 0: _conduct(record, enemies)
		if not world.records.has(id) or not _touches(record): continue
		for enemy: Node3D in enemies:
			if not is_instance_valid(enemy) or enemy.down: continue
			if _within(record, enemy, enemy.heat_reach() if enemy.temp >= 2 else 0.0) and not _settled(record, enemy) and _spend(): _heat(record, enemy)
			if not world.records.has(id): break

## Whether touching this record can do anything to a machine by heat: cold scrap and cool
## current do nothing on contact (current acts by conduction), so they cost no reactions.
static func _touches(record: Dictionary) -> bool:
	return float(record.get("quenched_left", 0.0)) <= 0.0 and (record["material"] not in ["scrap", "current"] or Catalog.temp_of(record) != 0)

## A machine already as this matter would leave it: wet in plain water, alight in fire. Touching
## changes nothing, so it costs no reaction -- a pack wading through the yard's mains must not use
## up the beat that a fire or a discharge elsewhere needs.
static func _settled(record: Dictionary, enemy: Node3D) -> bool:
	if int(record.get("charge", 0)) > 0 or record["attachments"].has("nanites"): return false
	var t: int = Catalog.temp_of(record)
	if record["material"] == "water" and t == 0: return enemy.soaked >= 0.6 and absi(enemy.temp) < 2
	if record["material"] == "fire": return enemy.temp >= 2 and not enemy.wet()
	# Warm steam on a dry machine already warm or burning only holds it there.
	if record["material"] == "steam" and t == 1: return enemy.temp >= 1 and not enemy.wet()
	return false

func _spend() -> bool:
	if _budget <= 0:
		count("capped")
		return false
	_budget -= 1
	return true

# --- Heat ---------------------------------------------------------------------------------------

## Fire passes from machine to machine: one burning lights a dry one beside it a step hotter.
func _spread(enemies: Array[Node3D]) -> void:
	var now: int = Time.get_ticks_msec()
	var left: int = SPREAD_CAP
	for key: Variant in _charred.keys():
		if not is_instance_valid(key) or int(_charred[key]) < now: _charred.erase(key)
	for enemy: Node3D in enemies:
		if not is_instance_valid(enemy) or enemy.down or enemy.temp < 2: continue
		if not _charred.has(enemy): _charred[enemy] = now + int(CHAR_TIME * 1000.0)
		for other: Node3D in enemies:
			if left <= 0: return
			if other == enemy or not is_instance_valid(other) or other.down or other.temp >= 2 or other.wet() or _charred.has(other): continue
			if _flat(other.global_position - enemy.global_position).length() > SPREAD: continue
			left -= 1
			_set_temp(other, other.temp + 1)
			count("spread")
			if other.temp >= 2: spellwork.rule_fx.rpc("ignite", PackedVector3Array([other.global_position]))

# --- Gravity ------------------------------------------------------------------------------------

## A well's ring is its matter going round: a machine riding it is touching that matter every beat
## -- soaked by water, lit by fire, scalded by steam -- and tumbling scrap or ice grinds it by its
## weight. What else the ring carries (a puddle it caught, a charged heap) meets it the same way.
const GRIND := 1.0
func _ring(enemies: Array[Node3D]) -> void:
	for id: int in world.records.keys():
		if not world.records.has(id) or Catalog.field(world.records[id]) != "well": continue
		var record: Dictionary = world.records[id]
		var center: Vector3 = Catalog.field_center(record)
		for enemy: Node3D in enemies:
			if not is_instance_valid(enemy) or enemy.down or enemy.airborne(): continue
			if absf(_flat(enemy.global_position - center).length() - Catalog.VORTEX_RING) > Catalog.RING_BAND: continue
			if _touches(record) and not _settled(record, enemy) and _spend(): _heat(record, enemy)
			if not world.records.has(id): break
			if record["material"] in ["scrap", "ice"] and is_instance_valid(enemy) and not enemy.down and _spend():
				var blow: float = GRIND * Catalog.mass_of(record)
				spellwork.run.log_damage("ring", blow * enemy.exposure)
				enemy.take_damage(blow)
				count("ground")
				spellwork.rule_fx.rpc("grind", PackedVector3Array([enemy.global_position]))

## A machine thrown into another: both take the blow by the thrower's mass and speed, and the
## one struck is sent on with part of it, so a repulsor bowls a line over.
func bowl(thrown: Node3D, struck: Node3D, speed: float) -> void:
	var blow: float = minf(9.0, float(thrown.tag("mass")) * speed * 0.45)
	var onward: Vector3 = _flat(struck.global_position - thrown.global_position).normalized() * speed * 0.6
	spellwork.run.log_damage("bowl", blow * 1.5)
	thrown.take_damage(blow * 0.5)
	if is_instance_valid(struck) and not struck.down:
		struck.take_damage(blow)
		struck.shove += onward
	count("bowled")
	spellwork.rule_fx.rpc("bowl", PackedVector3Array([(thrown.global_position + struck.global_position) * 0.5]))

## A machine on its own: it drifts back to its rest temp, burns if it is alight, and a wet one
## that is hot puts itself out in a puff of steam.
func _settle(enemy: Node3D) -> void:
	if enemy.wet() and enemy.temp >= 1 and enemy.rest_temp() < 1:
		_dry(enemy)
		enemy.temp = 0
		return
	if enemy.temp >= 2 and enemy.nanites > 0:
		var planted: int = enemy.nanites
		enemy.nanites = 0
		detonate_machine(enemy.global_position, planted)
	if enemy.temp >= 2 and enemy.tag("material") in BURNS: enemy.take_damage(BURN_DAMAGE)
	if not is_instance_valid(enemy) or enemy.down: return
	var rest: int = enemy.rest_temp()
	if enemy.temp == rest: return
	enemy.temp_hold -= TICK
	if enemy.temp_hold <= 0.0: _set_temp(enemy, enemy.temp + signi(rest - enemy.temp))

func _set_temp(enemy: Node3D, value: int) -> void:
	enemy.temp = clampi(value, -2, 2)
	enemy.temp_hold = HOLD

func _dry(enemy: Node3D) -> void:
	enemy.soaked = 0.0
	count("dried")
	spellwork.rule_fx.rpc("steam", PackedVector3Array([enemy.global_position]))

## Matter and a machine in contact: each moves the other one step toward itself.
func _heat(record: Dictionary, enemy: Node3D) -> void:
	var t: int = Catalog.temp_of(record)
	var id: int = record["id"]
	# Fire, and metal or plasma hot enough, light a dry machine; a wet one hisses dry instead and
	# the fire loses some of its fuel to it.
	if record["material"] in ["fire", "scrap", "current"]:
		if t >= 1 and enemy.wet() and enemy.rest_temp() < 1:
			_dry(enemy)
			if record.has("burn"): record["burn"] = float(record["burn"]) - 1.0
			return
		if record["material"] == "fire" or t >= 2:
			if enemy.temp < 2:
				_set_temp(enemy, 2 if record["material"] == "fire" else enemy.temp + 1)
				enemy.take_damage(IGNITE_DAMAGE)
				count("ignited")
				if is_instance_valid(enemy) and enemy.temp >= 2: spellwork.rule_fx.rpc("ignite", PackedVector3Array([enemy.global_position]))
			return
		if t != 0 and enemy.temp != t and absi(enemy.temp) < 2: _set_temp(enemy, enemy.temp + signi(t - enemy.temp))
		return
	# The machine's heat on the matter first: burning melts ice and boils water, frost freezes it.
	if enemy.temp >= 2 and t <= -1:
		if world.execute(record["owner"], "heat", id, {"remote": true}).get("ok", false): count("melted")
		return
	if enemy.temp >= 2 and t == 0 :
		if world.execute(record["owner"], "heat", id, {"remote": true}).get("ok", false):
			count("boiled")
			_set_temp(enemy, 1)
		return
	if enemy.temp <= -2 and t == 0 :
		if world.execute(record["owner"], "freeze", id, {"remote": true}).get("ok", false): count("chilled")
		return
	# Then the matter's on the machine. Contact with water always wets; charge and cold
	# can subsequently act on that same visible wet state.
	if t == 0:
		if enemy.soaked < 0.6: enemy.soak(Vector3.ZERO)
		return
	if t >= 1 and enemy.wet():
		_dry(enemy)
		return
	if t >= 2:
		enemy.take_damage(SCALD_DAMAGE)
		count("scalded")
		if is_instance_valid(enemy) and not enemy.down and enemy.temp < 1: _set_temp(enemy, 1)
		return
	if t <= -1 and enemy.wet():
		enemy.soaked = 0.0
		enemy.frozen = FREEZE_TIME
		_set_temp(enemy, -1)
		count("frozen")
		spellwork.rule_fx.rpc("frost", PackedVector3Array([enemy.global_position]))
		return
	if t != 0 and enemy.temp != t and absi(enemy.temp) < 2: _set_temp(enemy, enemy.temp + signi(t - enemy.temp))

## Fire arriving all at once -- dropped, burst, thrown as sparks -- on one machine: a dry one
## catches, a wet one is dried instead.
func light(enemy: Node3D) -> void:
	if not is_instance_valid(enemy) or enemy.down: return
	if enemy.wet() and enemy.rest_temp() < 1:
		_dry(enemy)
		return
	if enemy.temp >= 2: return
	_set_temp(enemy, 2)
	enemy.take_damage(IGNITE_DAMAGE)
	count("ignited")
	if is_instance_valid(enemy) and not enemy.down: spellwork.rule_fx.rpc("ignite", PackedVector3Array([enemy.global_position]))

## Current let go all at once from `at`: every machine within `radius` takes a discharge, drawn
## as one arc fanning out.
func shock_around(at: Vector3, radius: float, enemies: Array[Node3D], plasma: bool = false) -> void:
	var path := PackedVector3Array([at + Vector3.UP * 0.4])
	var seen: Dictionary = {}
	var hits: int = 0
	for enemy: Node3D in enemies:
		if not is_instance_valid(enemy) or enemy.down or _flat(enemy.global_position - at).length() > radius: continue
		hits += _shock(enemy, seen, path, plasma)
		path.append(at + Vector3.UP * 0.4)
	if hits == 0: return
	count("arcs")
	count("jumps", hits)
	spellwork.rule_fx.rpc("arc", path)

## A cold hit on a machine: a wet one freezes where it stands, a dry one cools a step.
func chill(enemy: Node3D) -> void:
	if not is_instance_valid(enemy) or enemy.down: return
	if enemy.wet():
		enemy.soaked = 0.0
		enemy.frozen = FREEZE_TIME
		_set_temp(enemy, -1)
		count("frozen")
		spellwork.rule_fx.rpc("frost", PackedVector3Array([enemy.global_position]))
	elif enemy.temp > -2: _set_temp(enemy, enemy.temp - 1)

## A charged hit: `first` takes the discharge and it runs on, `jumps` more, to the nearest machine
## within a jump -- but only on through conductors (wet, metal), like any charge.
func zap(first: Node3D, jumps: int, enemies: Array[Node3D]) -> void:
	if not is_instance_valid(first) or first.down: return
	var seen: Dictionary = {}
	var path := PackedVector3Array([first.global_position + Vector3.UP * 0.8])
	var hits: int = 0
	var at: Node3D = first
	var conducting: bool = conducts(first)
	hits += _shock(first, seen, path)
	for i: int in jumps:
		if not conducting or not is_instance_valid(at): break
		var next: Node3D = null
		var nearest: float = JUMP
		for enemy: Node3D in enemies:
			if seen.has(enemy) or not is_instance_valid(enemy) or enemy.down: continue
			var gap: float = _flat(enemy.global_position - at.global_position).length()
			if gap < nearest:
				nearest = gap
				next = enemy
		if next == null: break
		conducting = conducts(next)
		hits += _shock(next, seen, path)
		at = next
	count("arcs")
	count("jumps", hits)
	stats["longest"] = maxi(int(stats["longest"]), hits)
	spellwork.rule_fx.rpc("arc", path)

## Nanites an attack planted go off when the machine falls or burns: a blast that hurts the ones
## around it, which may carry their own.
const NANITE_RADIUS := 2.4
const NANITE_DAMAGE := 7.0
func detonate_machine(at: Vector3, charge: int) -> void:
	count("detonated")
	spellwork.rule_fx.rpc("nanites", PackedVector3Array([at]))
	for enemy: Node3D in spellwork.get_tree().get_nodes_in_group("survivor_enemies"):
		if not is_instance_valid(enemy) or enemy.down: continue
		var distance: float = _flat(enemy.global_position - at).length()
		if distance >= NANITE_RADIUS: continue
		var blast: float = NANITE_DAMAGE * charge * (1.0 - 0.5 * distance / NANITE_RADIUS)
		spellwork.run.log_damage("nanites", blast)
		enemy.take_damage(blast)

## Brasa's flame on a machine: one step hotter, or dry if it was wet. Then its own answer to fire.
func ignite(enemy: Node3D, origin: Vector3) -> void:
	warm(enemy)
	enemy.burn(origin)

## Heat arriving a step at a time: a wet machine dries first, a dry one warms a step.
func warm(enemy: Node3D) -> void:
	if enemy.wet() and enemy.rest_temp() < 1: _dry(enemy)
	elif enemy.temp < 2: _set_temp(enemy, enemy.temp + 1)

# --- Matter on matter ---------------------------------------------------------------------------

## Two pieces of matter touching react by what they carry, with no machine between them: water
## puts fire out and boils off it, fire heats scrap red, hot scrap boils water and cools, current
## turns to plasma in fire, and anything burning sets off nanites it touches. The crew's matter
## reaching one of the yard's stores sets it off (`_trip`).
func _contact(enemies: Array[Node3D]) -> void:
	var ids: Array = world.records.keys()
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			if not world.records.has(ids[i]) or not world.records.has(ids[j]): continue
			var a: Dictionary = world.records[ids[i]]
			var b: Dictionary = world.records[ids[j]]
			# The yard's sources stand apart: a burst main does not put a drum out.
			if (a.get("source", false) and b.get("source", false)) or not _touching(a, b): continue
			if a.get("source", false): _trip(a, b, enemies)
			elif b.get("source", false): _trip(b, a, enemies)
			if not world.records.has(ids[i]) or not world.records.has(ids[j]): continue
			_react(a, b)
			if world.records.has(ids[i]) and world.records.has(ids[j]): _react(b, a)

## What `hot` does to `other` when they touch, one direction of the pair.
func _react(hot: Dictionary, other: Dictionary) -> void:
	if float(hot.get("quenched_left", 0.0)) > 0.0: return
	# Sources retain their identity; only loose matter changes phase.
	if other.get("source", false): return
	var t: int = Catalog.temp_of(hot)
	var hot_id: int = hot["id"]
	var other_id: int = other["id"]
	# Heat sets off nanites, in the burning matter itself or in what it touches.
	if t >= 2:
		for target: Dictionary in [hot, other]:
			if target["attachments"].has("nanites") and _spend() and _detonate(target): return
	if hot["material"] == "fire":
		match other["material"]:
			"water":
				if not _spend(): return
				_act(other, "heat")
				_act(hot, "quench")
				count("quenched")
				spellwork.linked(hot, other)
				spellwork.rule_fx.rpc("smoke", PackedVector3Array([hot["position"]]))
			"ice":
				if not _spend(): return
				_act(other, "heat")
				hot["burn"] = float(hot.get("burn", Catalog.FIRE_LIFETIME)) - 2.0
				count("melted")
				spellwork.linked(hot, other)
			"scrap", "current":
				if Catalog.temp_of(other) < 2 and _spend() and _act(other, "warm"):
					count("reddened")
					spellwork.linked(hot, other)
		return
	if hot["material"] in ["scrap", "current"] and t >= 1 and other["material"] in ["water", "ice"] and _spend():
		# Hot metal into water: the water steams off and the metal goes back to cold.
		_act(other, "heat")
		_act(hot, "chill")
		count("boiled")
		spellwork.linked(hot, other)
		return
	if hot["material"] == "steam" and other["material"] == "fire" and _spend():
		# Steam smothers a fire it settles on.
		_act(other, "quench")
		count("quenched")
		spellwork.linked(hot, other)
		spellwork.rule_fx.rpc("smoke", PackedVector3Array([other["position"]]))
		return
	if world.records.has(hot_id) and world.records.has(other_id) and int(hot.get("charge", 0)) > 0 and other["attachments"].has("nanites") and _spend():
		spellwork.linked(hot, other)
		_detonate(other)

# --- The yard's stores, set off ----------------------------------------------------------------

## The stores are hazards, not fuel: what a routine throws at one sets it off, and then it rests a
## while before it can go again. A drum fed fire or hot metal flares, lights every machine round
## it and burns low; a transformer fed water, metal, current or fire overloads and lets go at
## everything near (plasma, if it was fire); a burst main carries a charge through its whole pool,
## or freezes what stands in it when ice reaches it; a heap struck by thrown matter bursts into
## shrapnel. The store itself stays where it was.
const TRIP_REST := 6.0
const FLARE_RADIUS := 3.5
const OVERLOAD_RADIUS := 6.0
const POOL_REACH := 1.5
const SHRAPNEL_RADIUS := 3.5
const SHRAPNEL_DAMAGE := 8.0
## How fast thrown matter must be going to burst a heap, m/s.
const THROWN := 4.0
func _trip(store: Dictionary, matter: Dictionary, enemies: Array[Node3D]) -> void:
	if int(matter["owner"]) == world.YARD or matter.get("source", false): return
	if spellwork.run.elapsed < float(store.get("trip_at", -INF)): return
	var at: Vector3 = store["position"]
	var t: int = Catalog.temp_of(matter)
	var kind: String = ""
	match store["material"]:
		"fire":
			if float(store.get("quenched_left", 0.0)) <= 0.0 and (matter["material"] == "fire" or (matter["material"] in ["scrap", "current"] and t >= 1)): kind = "flare"
		"current":
			if matter["material"] in ["water", "ice", "scrap", "current", "fire"]: kind = "overload"
		"water":
			if int(matter.get("charge", 0)) > 0 or matter["material"] == "current": kind = "electrify"
			elif matter["material"] == "ice": kind = "freeze"
		"scrap":
			if matter.get("velocity", Vector3.ZERO).length() >= THROWN: kind = "shrapnel"
	if kind == "" or not _spend(): return
	store["trip_at"] = spellwork.run.elapsed + TRIP_REST
	match kind:
		"flare":
			count("flared")
			spellwork.rule_fx.rpc("flare", PackedVector3Array([at]))
			for enemy: Node3D in _around(at, FLARE_RADIUS, enemies): light(enemy)
			# It burned through its fuel: it sits low and smoking until it catches again.
			_act(store, "quench")
		"overload":
			count("overloaded")
			shock_around(at, OVERLOAD_RADIUS, enemies, matter["material"] == "fire")
			store["charge"] = 0
		"electrify":
			count("electrified")
			shock_around(at, maxf(store["size"].x, store["size"].z) * 0.5 + POOL_REACH, enemies)
		"freeze":
			count("iced")
			spellwork.rule_fx.rpc("frost", PackedVector3Array([at]))
			for enemy: Node3D in _around(at, maxf(store["size"].x, store["size"].z) * 0.5 + POOL_REACH, enemies):
				if not enemy.wet(): enemy.soaked = 1.0
				chill(enemy)
		"shrapnel":
			count("shrapnel")
			spellwork.rule_fx.rpc("shrapnel", PackedVector3Array([at]))
			for enemy: Node3D in _around(at, SHRAPNEL_RADIUS, enemies):
				var away: Vector3 = _flat(enemy.global_position - at)
				var blow: float = SHRAPNEL_DAMAGE * (1.0 - 0.5 * away.length() / SHRAPNEL_RADIUS)
				enemy.shove += (away.normalized() if away.length() > 0.1 else Vector3.RIGHT) * 6.0
				spellwork.run.log_damage("shrapnel", blow)
				enemy.take_damage(blow)
	world._dirty = true

func _around(at: Vector3, radius: float, enemies: Array[Node3D]) -> Array[Node3D]:
	var near: Array[Node3D] = []
	for enemy: Node3D in enemies:
		if is_instance_valid(enemy) and not enemy.down and _flat(enemy.global_position - at).length() <= radius: near.append(enemy)
	return near

func _act(record: Dictionary, op: String) -> bool:
	return world.records.has(record["id"]) and world.execute(record["owner"], op, record["id"], {"remote": true}).get("ok", false)

func _detonate(record: Dictionary) -> bool:
	if not world.records.has(record["id"]): return false
	var done: bool = world.execute(record["owner"], "command", record["id"], {"coating": "nanites", "command": "detonate", "remote": true}).get("ok", false)
	if done: count("detonated")
	return done

func _touching(a: Dictionary, b: Dictionary) -> bool:
	if absf(a["position"].y - b["position"].y) > 2.5: return false
	var reach: float = maxf(a["size"].x, a["size"].z) * 0.5 + maxf(b["size"].x, b["size"].z) * 0.5
	return _flat(a["position"] - b["position"]).length() < reach * 0.8

# --- Conduction ---------------------------------------------------------------------------------

## A charged record discharges when something closes the circuit: a machine touching it, or, for
## water, anything conductive within a jump. The charge runs on through conductors -- wet or metal
## machines, other water -- for 3 jumps per charge, 6 at most, hurting every machine it crosses.
func _conduct(record: Dictionary, enemies: Array[Node3D]) -> void:
	if _budget <= 0: return
	var seeking: bool = record["material"] == "current"
	var plasma: bool = seeking and Catalog.temp_of(record) >= 1
	var limit: int = 3 if seeking else mini(MAX_JUMPS, 3 * int(record["charge"]))
	var first_reach: float = SEEK + (COLD_SEEK if Catalog.temp_of(record) < 0 else 0.0) if seeking else JUMP
	var origin: Vector3 = record["position"] + Vector3.UP * 0.3
	# Search conductors before requiring a victim. Each route stores its actual parent edges;
	# branches never create imaginary arcs between unrelated queue entries.
	var queue: Array = [{"at": origin, "reach": first_reach, "id": record["id"], "path": PackedVector3Array([origin]), "depth": 0}]
	var visited: Dictionary = {record["id"]: true}
	var seen: Dictionary = {}
	var hits: int = 0
	var edges: int = 0
	while not queue.is_empty() and hits < limit and edges < 24:
		var entry: Dictionary = queue.pop_front()
		var at: Vector3 = entry["at"]
		var candidates: Array[Node3D] = enemies.duplicate()
		candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_squared_to(at) < b.global_position.distance_squared_to(at))
		for enemy: Node3D in candidates:
			if hits >= limit: break
			if not is_instance_valid(enemy) or enemy.down or seen.has(enemy): continue
			var target: Vector3 = enemy.global_position + Vector3.UP * 0.4
			var root: bool = int(entry["depth"]) == 0
			var near: bool = _within(record, enemy, first_reach) if root else _flat(target - at).length() <= float(entry["reach"]) + 0.45
			if not near or absf(target.y - at.y) > 2.5 or not _wire_clear(at, target, int(entry["id"]), 0): continue
			if not root and not conducts(enemy): continue
			if not seeking and root and not conducts(enemy) and not _within(record, enemy, 0.0): continue
			if not _spend(): break
			var path: PackedVector3Array = entry["path"].duplicate()
			var onward: bool = conducts(enemy)
			hits += _shock(enemy, seen, path, plasma)
			spellwork.rule_fx.rpc("arc", path)
			if onward and int(entry["depth"]) < MAX_JUMPS:
				queue.append({"at": target, "reach": JUMP, "id": 0, "path": path, "depth": int(entry["depth"]) + 1})
			if seeking and root: break # one nearest body, then conductors only
		if int(entry["depth"]) >= MAX_JUMPS: continue
		for id: int in world.records:
			if visited.has(id) or visited.size() >= 16: continue
			var other: Dictionary = world.records[id]
			if other["material"] not in CONDUCTIVE: continue
			var target: Vector3 = other["position"] + Vector3.UP * 0.3
			if absf(target.y - at.y) > 2.5: continue
			if _surface_gap(other, at) > float(entry["reach"]) or not _wire_clear(at, target, int(entry["id"]), id): continue
			visited[id] = true
			edges += 1
			var path: PackedVector3Array = entry["path"].duplicate()
			path.append(target)
			queue.append({"at": target, "reach": JUMP, "id": id, "path": path, "depth": int(entry["depth"]) + 1})
	if hits == 0: return # no closed circuit, no spent charge
	record["charge"] = int(record["charge"]) - 1 if seeking else 0
	world._dirty = true
	count("grounded")
	count("arcs")
	count("jumps", hits)
	stats["longest"] = maxi(int(stats["longest"]), hits)
	for id: int in visited:
		if not world.records.has(id): continue
		if id != record["id"]: spellwork.linked(record, world.records[id])
		if world.records[id]["attachments"].has("nanites"): _detonate.call_deferred(world.records[id])
	if seeking and int(record["charge"]) <= 0 and not record.get("source", false): world.spend(record["id"])

## Distance to the oriented footprint, not a radius enclosing a long thin wall.
func _surface_gap(record: Dictionary, at: Vector3) -> float:
	var local: Vector3 = Basis(Vector3.UP, record["yaw"]).inverse() * (at - record["position"])
	var half: Vector3 = record["size"] * 0.5
	return Vector2(maxf(0.0, absf(local.x) - half.x), maxf(0.0, absf(local.z) - half.z)).length()

## Walls and scenery insulate the gap. Endpoint conductors may of course receive the arc.
func _wire_clear(from: Vector3, to: Vector3, from_id: int, to_id: int) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1)
	var excluded: Array[RID] = []
	for id: int in [from_id, to_id]:
		if world.views.has(id): excluded.append(world.views[id].get_rid())
	ray.exclude = excluded
	return world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _shock(enemy: Node3D, seen: Dictionary, path: PackedVector3Array, plasma: bool = false) -> int:
	seen[enemy] = true
	path.append(enemy.global_position + Vector3.UP * 0.8)
	enemy.charge = 1
	enemy.charge_hold = 0.6
	enemy.take_damage(ARC_DAMAGE)
	# Plasma burns as it passes.
	if plasma and is_instance_valid(enemy) and not enemy.down and enemy.temp < 2: _set_temp(enemy, enemy.temp + 1)
	return 1

# --- Shared geometry ----------------------------------------------------------------------------

## Whether `enemy` touches the record (its footprint, grown by `reach`).
func _within(record: Dictionary, enemy: Node3D, reach: float) -> bool:
	var gap: Vector3 = enemy.global_position - record["position"]
	if absf(gap.y) > (6.0 if record["material"] == "steam" else 2.5): return false
	var local: Vector3 = Basis(Vector3.UP, record["yaw"]).inverse() * gap
	match record["shape"]:
		"orb": return Vector2(local.x, local.z).length() < Catalog.ORB_SIZE.x * 0.5 + 0.45 + reach
		"wall": return absf(local.x) < 2.3 + reach and absf(local.z) < 1.0 + reach
		"patch": return absf(local.x) < record["size"].x * 0.5 + 0.3 + reach and absf(local.z) < record["size"].z * 0.5 + 0.3 + reach
	return Vector2(local.x, local.z).length() < 2.4 + reach

static func _flat(value: Vector3) -> Vector3:
	return Vector3(value.x, 0.0, value.z)

# --- What the editor says -----------------------------------------------------------------------

## «con lo que toque»: what this matter does to what touches it, told from the rules above. Takes
## a recipe state (temp, grav, charge, mass, material, shape).
static func touch(state: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if state["shape"] == "gone": return out
	var temp: int = state["temp"]
	var material: String = state["material"]
	if material == "fire": out.append("prende a la máquina seca y el fuego pasa a las de al lado, %s de daño; lo mojado se seca y le roba combustible" % _num(IGNITE_DAMAGE))
	elif material in ["scrap", "current"] and temp >= 2: out.append("al rojo: prende lo que toca")
	elif temp >= 2: out.append("quema %s cada %s s y seca lo mojado" % [_num(SCALD_DAMAGE), _num(TICK)])
	elif temp >= 1: out.append("calienta y seca lo mojado")
	if temp <= -1: out.append("congela %s s a la máquina mojada" % _num(FREEZE_TIME))
	if temp <= -2: out.append("enfría lo que la toca")
	var charge: int = int(state.get("charge", 0))
	if material == "current" and charge > 0:
		out.append("busca un cuerpo o un camino de agua/metal; %d descargas de %d, alcance inicial %s m, hasta 3 cuerpos%s" % [charge, ARC_DAMAGE, _num(SEEK + (COLD_SEEK if temp < 0 else 0.0)), "; el plasma además prende" if temp >= 1 else ""])
	elif charge > 0:
		var jumps: int = mini(MAX_JUMPS, 3 * charge)
		out.append("descarga %d de daño por salto, hasta %d saltos por agua, metal o lo mojado%s" % [ARC_DAMAGE, jumps, " (salta a %s m)" % _num(JUMP) if material in ["water", "scrap"] else ""])
	if int(state.get("coat", 0)) > 0 and (temp >= 2 or material == "current"): out.append("los nanitos estallan solos con %s" % ("el calor" if temp >= 2 else "la descarga"))
	if int(state.get("grav", 0)) > 0:
		var riding: String = {"water": "los empapa", "fire": "los prende", "steam": "los escalda", "scrap": "los muele por su peso", "ice": "los muele y enfría", "current": "les descarga lo que lleve"}.get(material, "los arrastra")
		out.append("remolino: lo suelto a %s m gira en un anillo de su materia, que %s; al soltar, todo sale despedido" % [_num(Catalog.VORTEX_REACH), riding])
	elif int(state.get("grav", 0)) < 0:
		out.append("onda: lanza lejos lo que hay a %s m (choca con lo que pille) y luego no deja entrar a %s m" % [_num(Catalog.BLAST_REACH), _num(Catalog.BUBBLE)])
	if state.get("moving", false) and state["material"] not in ["steam", "fire", "current"]:
		out.append("golpea según masa × velocidad (masa %s)" % _num(Catalog.MASS[state["material"]] * (0.5 if state["shape"] == "fragments" else 1.0)))
	if material == "water" and temp == 0 and charge == 0:
		out.append("apaga el fuego que toca; lo que arde la hace hervir; el frío la congela")
	if material == "scrap" and temp == 0: out.append("conduce la carga y guarda el calor del fuego que la toca")
	# What it sets off among the yard's stores (`_trip`), in the same order as there.
	var stores: Array[String] = []
	if material == "fire" or (material in ["scrap", "current"] and temp >= 1): stores.append("aviva un tambor")
	if material in ["water", "ice", "scrap", "current", "fire"]: stores.append("sobrecarga un transformador")
	if charge > 0 or material == "current": stores.append("electrifica el charco de una cañería")
	elif material == "ice": stores.append("congela el charco de una cañería")
	if state.get("moving", false) and material not in ["steam", "fire", "current"]: stores.append("revienta la chatarra en metralla")
	if not stores.is_empty(): out.append("en el patio: " + ", ".join(stores))
	return out

static func _num(value: float) -> String:
	return ("%.2f" % value).rstrip("0").rstrip(".").replace(".", ",")
