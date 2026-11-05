## Host-owned bounded world state. Clients submit intent, never material/damage/state records.
extends Node3D
signal matter_event(event: Dictionary)
signal operation_result(result: Dictionary)
const Catalog = preload("res://scripts/matter/materials.gd")
const View = preload("res://scripts/matter/construct_view.gd")
const OPERATIONS := ["create", "raise", "wall", "freeze", "heat", "impact", "push", "coat", "command", "remove", "react", "link",
	# The fuller vocabulary the survivor routines compile to: each gives an existing verb a
	# meaning on matter the plain verb refuses (ice raised, ice frozen harder, steam heated
	# further, a second coat, water or ice pushed), plus gravity: a well, a repulsor, a drop.
	"lift", "harden", "scald", "charge", "slide", "well", "repel", "drop",
	# Electric charge on the matter itself (0..2); the survivor's conduction rule spends it.
	"arc",
	# Fire, current and scrap: heat taken up or given off, a fire put out, a fire fed.
	"warm", "chill", "quench", "stoke"]
const ATTACHMENT_COMMANDS := {"detonate": "_detonate_attachment"}
const LIMIT := 32
## The yard's own water, owned by nobody: the sources that keep a puddle full and the puddles
## spent matter leaves. It counts apart from the crew's limit and any player may work it.
const YARD := 0
const YARD_PUDDLES := 16
## Scrap piles the yard keeps apart from its water, so wrecks never crowd the puddles out.
const YARD_PILES := 8
## Spent water joins a yard puddle this close instead of lying beside it.
const MERGE_REACH := 2.8
const PUDDLE_TTL := 45.0
## A yard puddle shrinks away over its last seconds instead of vanishing.
const EVAPORATE := 5.0
## Yard ice warms back to water on its own; a source refills one draught every few seconds.
const MELT_TIME := 9.0
const SOURCE_REFILL := 3.0
const OWNER_LIMIT := 8
const REACH := 18.0
const HARD_INTEGRITY := 1.6
const WELL_TIME := 5.0
const REPEL_TIME := 4.0
const DROP_RADIUS := 2.5
const DROP_DAMAGE := 10.0
var records: Dictionary = {}
## The matter whose blow is landing right now (host only), so a machine it fells can name the
## routine that made it; empty between blows.
var culprit: Dictionary = {}
var views: Dictionary = {}
var next_id: int = 1
var revision: int = 0
var received_revision: int = -1
var cooldowns: Dictionary = {}
var _events: Array[Dictionary] = []
var _busy: bool = false
var _pending_damage: Array[Dictionary] = []
var _pending_heat: Array[int] = []
var _tick: float = 0.0
var _dirty: bool = false
var snapshot_bytes: int = 0
## Cosmetic aftermath, bounded and replicated for late joiners.
var floor_marks: Array = []
var _mark_serial: int = 0
const MAX_FLOOR_MARKS := 24
var tick_usec_max: int = 0
var tick_usec_total: int = 0
var tick_count: int = 0

func _ready() -> void:
	add_to_group("world_matter")
	var scheduler := preload("res://scripts/matter/reactive_program.gd").new()
	scheduler.name = "Programs"
	add_child(scheduler)
	multiplayer.peer_disconnected.connect(_peer_left)
	if not multiplayer.is_server():
		request_snapshot.rpc_id(1)

func _peer_left(peer: int) -> void:
	if not is_inside_tree(): return
	if not multiplayer.is_server(): return
	for id: int in records.keys():
		if records[id]["owner"] == peer: _erase(id, "owner_left")
	cooldowns.erase(peer)
	_publish()

func _player(peer: int) -> Node3D:
	for player: Node in get_tree().get_nodes_in_group("coop_players"):
		if player.get_multiplayer_authority() == peer: return player as Node3D
	return null

## Shared by previews, debug tools and a future programming-block adapter.
## No state changes. The same validation is repeated on the host at commit.
func preview(peer: int, op: String, target: int = 0, args: Dictionary = {}) -> Dictionary:
	if op not in OPERATIONS: return _failure("Unknown operation")
	var player: Node3D = _player(peer)
	var record: Dictionary = records.get(target, {})
	# The host's own rules may work the yard's water with no player behind them.
	var yard_rule: bool = op != "create" and record.get("owner", -1) == YARD and args.get("remote", false)
	if player == null and not yard_rule: return _failure("Player unavailable")
	var point: Variant = args.get("point", Vector3.ZERO) if op == "create" else record.get("position", Vector3.ZERO)
	if not point is Vector3 or not point.is_finite(): return _failure("Invalid position")
	# Host-scheduled reactions act where the matter is, however far its owner has walked.
	if player != null and player.global_position.distance_to(point) > REACH and not (args.get("remote", false) and op != "create"): return _failure("Out of reach")
	if op == "create":
		var substance: String = str(args.get("material", "water"))
		if not Catalog.MATERIALS.has(substance) or not Catalog.MATERIALS[substance].get("spawnable",false): return _failure("Material has no source in this prototype")
		var owned: int = 0
		var crew: int = 0
		for item: Dictionary in records.values():
			if item["owner"] == peer: owned += 1
			if item["owner"] != YARD: crew += 1
		if crew >= LIMIT or owned >= OWNER_LIMIT: return _failure("Construct limit reached")
		var floor_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2.0,point-Vector3.UP*2.0,1))
		if floor_hit.is_empty() or floor_hit.normal.y < 0.9 or absf(floor_hit.position.y-point.y)>0.5: return _failure("Requires level ground")
		return {"ok": true, "size": Vector3(4,0.12,3), "position": floor_hit.position+Vector3.UP*0.02}
	if record.is_empty(): return _failure("Target no longer exists")
	if record["owner"] != peer and record["owner"] != YARD and op != "impact": return _failure("Target belongs to another player")
	if op in ["raise", "lift"]:
		if not Catalog.can_raise(record): return _failure("La materia ya está elevada o no se puede sostener")
		if record["material"] == "ice":
			var held: Dictionary = record.duplicate()
			held["position"].y += Catalog.HOLD_HEIGHT
			held["shape"] = "orb"
			held["size"] = Catalog.ORB_SIZE
			if not _solid_clear(held): return _failure("Solid volume is occupied")
	if op == "wall":
		if not Catalog.can_wall(record): return _failure("Un muro requiere agua o hielo sin romper")
		var direction: Variant = args.get("vector", Vector3.RIGHT * 4.0)
		if not direction is Vector3 or not direction.is_finite() or Vector2(direction.x, direction.z).length() < 0.5: return _failure("Choose a line direction")
		if record["material"] == "ice":
			var shaped: Dictionary = record.duplicate()
			shaped["size"] = Catalog.WALL_SIZE
			shaped["shape"] = "wall"
			shaped["position"].y = record.get("ground_y", record["position"].y)
			shaped["yaw"] = -atan2(direction.z, direction.x)
			if not _solid_clear(shaped): return _failure("Solid volume is occupied")
	if op == "freeze":
		if not Catalog.TRANSITIONS["freeze"].has(record["material"]): return _failure("Cannot freeze this material")
		var frozen_into: String = Catalog.TRANSITIONS["freeze"][record["material"]]
		if "solid" in Catalog.MATERIALS[frozen_into]["properties"] and not _solid_clear(record): return _failure("Solid volume is occupied")
	if op == "heat" and not Catalog.TRANSITIONS["heat"].has(record["material"]): return _failure("Cannot heat this material")
	if op == "link":
		var to: Variant = args.get("to", 0)
		if not to is int or to == target or not records.has(to): return _failure("Choose another reference")
		if records[to]["owner"] != peer: return _failure("Target belongs to another player")
		if record["position"].distance_to(records[to]["position"]) > Catalog.LINK_RANGE: return _failure("Conduit out of range")
	if op == "impact" and not Catalog.has_property(record,"breakable"): return _failure("Requires breakable matter")
	if op == "push":
		if not Catalog.has_property(record,"movable"): return _failure("Requires movable matter")
		var direction: Variant = args.get("vector", Vector3.ZERO)
		if not direction is Vector3 or not direction.is_finite() or Vector2(direction.x,direction.z).length()<0.01: return _failure("Choose an impulse direction")
	if op == "coat":
		var coating: String = str(args.get("coating", "nanites"))
		if not Catalog.COATINGS.has(coating): return _failure("Unknown coating")
		if not Catalog.has_property(record,Catalog.COATINGS[coating]["requires"]): return _failure("Incompatible surface")
		if record["attachments"].has(coating): return _failure("Already coated")
	if op == "harden" and (record["material"] != "ice" or Catalog.hard(record)): return _failure("Requires unhardened ice")
	if op == "scald" and (record["material"] != "steam" or Catalog.scald(record)): return _failure("Requires plain steam")
	if op == "charge":
		if not record["attachments"].has("nanites"): return _failure("No compatible attachment")
		if int(record["attachments"]["nanites"].get("charge", 1)) >= 2: return _failure("Already charged")
	if op == "arc" and int(record.get("charge", 0)) >= (Catalog.MAX_CURRENT if record["material"] == "current" else 2): return _failure("Already fully charged")
	if op in ["warm", "chill"] and Catalog.substance_of(record["material"]) == "water": return _failure("Water changes phase: freeze or heat it")
	if op == "warm" and Catalog.temp_of(record) >= 2: return _failure("Already burning")
	if op == "chill" and Catalog.temp_of(record) <= -2: return _failure("Already frozen")
	if op in ["quench", "stoke"] and record["material"] != "fire": return _failure("Requires fire")
	if op == "slide":
		if record["material"] not in ["water", "ice", "fire", "current", "scrap"] or record["shape"] not in ["patch", "wall"]: return _failure("Requires a sheet or wall of matter on the floor")
		var heading: Variant = args.get("vector", Vector3.ZERO)
		if not heading is Vector3 or not heading.is_finite() or Vector2(heading.x,heading.z).length()<0.01: return _failure("Choose an impulse direction")
	if op == "drop":
		if not Catalog.can_drop(record): return _failure("Ya está en el suelo: usa raise antes de drop")
		var fall: Variant = args.get("vector", Vector3.ZERO)
		if not fall is Vector3 or not fall.is_finite(): return _failure("Invalid direction")
	if op == "react":
		if args.get("trigger", "") not in Catalog.TRIGGERS or args.get("action", "") not in Catalog.REACTIONS: return _failure("Invalid reaction")
		var vector: Variant = args.get("vector", Vector3.ZERO)
		if not vector is Vector3 or not vector.is_finite(): return _failure("Invalid direction")
	if op == "command":
		var coating: String = str(args.get("coating", "nanites"))
		if not record["attachments"].has(coating): return _failure("No compatible attachment")
		if str(args.get("command", "")) not in Catalog.COATINGS[coating]["commands"] or not ATTACHMENT_COMMANDS.has(str(args.get("command", ""))): return _failure("Unsupported attachment command")
	return {"ok": true, "position": point, "size": Catalog.ORB_SIZE if op == "raise" and record["material"] != "steam" else record["size"]}

func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

func _solid_clear(record: Dictionary) -> bool:
	# A sheet of ice on the floor is walked on, not into: whatever stands in a puddle can be frozen in it.
	if record["shape"] == "patch": return true
	var shape: Shape3D
	if record["shape"] == "orb":
		shape = SphereShape3D.new()
		shape.radius = record["size"].x * 0.49
	else:
		shape = BoxShape3D.new()
		shape.size = record["size"] * 0.98
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(Vector3.UP,record["yaw"]),record["position"]+Vector3.UP*record["size"].y*0.5)
	if views.has(record["id"]): query.exclude = [views[record["id"]].get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

## Safe client entry point. No arbitrary code or trusted client-supplied owner IDs.
func submit(op: String, target: int = 0, args: Dictionary = {}) -> void:
	request_operation.rpc_id(1,op,target,args)

@rpc("any_peer", "call_local", "reliable")
func request_operation(op: String, target: int, args: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var peer: int = multiplayer.get_remote_sender_id()
	if peer == 0: peer = multiplayer.get_unique_id()
	args.erase("remote") # Only the host's own scheduling may act out of reach.
	var now: int = Time.get_ticks_msec()
	if now - int(cooldowns.get(peer,-1000)) < 120: return
	cooldowns[peer] = now
	var result: Dictionary = execute(peer,op,target,args)
	if peer == multiplayer.get_unique_id(): operation_result.emit(result)
	else: receive_result.rpc_id(peer,result)

@rpc("authority", "call_remote", "reliable")
func receive_result(result: Dictionary) -> void:
	operation_result.emit(result)

## Internal authoritative entry used by tests and future host ability scheduling.
func execute(peer: int, op: String, target: int = 0, args: Dictionary = {}) -> Dictionary:
	if not multiplayer.is_server(): return _failure("Host only")
	if _busy: return _failure("Operation already resolving")
	var result: Dictionary = preview(peer,op,target,args)
	if not result["ok"]: return result
	_busy = true
	var id: int = target
	if op == "create":
		id = next_id
		next_id += 1
		records[id] = {"id": id,"owner": peer,"material": str(args.get("material","water")),"shape": "patch","states": Catalog.MATERIALS[str(args.get("material","water"))]["initial_states"].duplicate(),"properties": [],"attachments": {},"position": result["position"],"ground_y": result["position"].y,"suspended": false,"size": result["size"],"yaw": 0.0,"velocity": Vector3.ZERO,"integrity": 20.0,"ttl": 60.0,"temp": Catalog.PHASE_TEMP.get(str(args.get("material","water")),0),"mass": Catalog.MASS.get(str(args.get("material","water")),1.0)}
		_kindle(records[id])
		_event("created",id)
	else:
		call("_op_" + op,records[id],args)
	_dirty = true
	_publish()
	_busy = false
	return {"ok": true, "id": id}

func _op_raise(record: Dictionary, _args: Dictionary) -> void:
	record["ground_y"] = record["position"].y
	record["suspended"] = true
	record["position"].y += Catalog.HOLD_HEIGHT
	record["yaw"] = 0.0
	if record["material"] != "steam":
		record["size"] = Catalog.ORB_SIZE
		record["shape"] = "orb"
	_event("reshaped",record["id"])

func _settle(record: Dictionary) -> void:
	record["position"].y = record.get("ground_y", record["position"].y)
	record["suspended"] = false
	record["velocity"] = Vector3.ZERO
	record.erase("sliding")

func _op_wall(record: Dictionary, args: Dictionary) -> void:
	_settle(record)
	var direction: Vector3 = args.get("vector", Vector3.RIGHT * 4.0)
	record["yaw"] = -atan2(direction.z, direction.x)
	record["size"] = Catalog.WALL_SIZE
	record["shape"] = "wall"
	_event("reshaped", record["id"])

func _op_freeze(record: Dictionary, _args: Dictionary) -> void:
	_transition(record,Catalog.TRANSITIONS["freeze"][record["material"]])

func _op_heat(record: Dictionary, _args: Dictionary) -> void:
	_transition(record,Catalog.TRANSITIONS["heat"][record["material"]])

## One phase change, whichever direction. Identity, owner, coating, conduit and reaction all
## survive it: the construct changes state, it is not replaced.
func _transition(record: Dictionary, material: String) -> void:
	var previous: String = record["material"]
	record["material"] = material
	record["states"] = Catalog.MATERIALS[material]["initial_states"].duplicate()
	# The temp stays inside the new phase's range; a phase change resets a hardened or boiling extreme.
	record["temp"] = Catalog.PHASE_TEMP[material]
	record["mass"] = Catalog.MASS[material]
	if material == "steam":
		record["shape"] = "cloud"
		record["size"] = Catalog.STEAM_SIZE
		record["properties"] = []
		record["condense"] = Catalog.STEAM_LIFETIME
		record["integrity"] = Catalog.MATERIALS["steam"]["integrity"]
	elif previous == "steam":
		# Condensed vapour settles where the cloud stands, as the patch it started as.
		record["shape"] = "orb" if record.get("suspended", false) else "patch"
		record["size"] = Catalog.ORB_SIZE if record.get("suspended", false) else Catalog.puddle_size(float(record.get("volume", 1.0)))
		record["yaw"] = 0.0
		record["velocity"] = Vector3.ZERO
		record.erase("condense")
	elif previous == "ice" and record["shape"] == "fragments":
		# Melted shards run together into one puddle rather than staying a cloud of debris.
		record["shape"] = "patch"
		record["size"] = Catalog.PATCH_SIZE
		record["properties"] = []
		record["velocity"] = Vector3.ZERO
	if previous == "ice":
		record["integrity"] = Catalog.MATERIALS[material]["integrity"]
	_event("transformed",record["id"])

## What a fresh draught of each substance starts with: fire its fuel, current its discharges,
## scrap its weight in the hand.
func _kindle(record: Dictionary) -> void:
	match record["material"]:
		"fire": record["burn"] = Catalog.FIRE_LIFETIME
		"current": record["charge"] = Catalog.CURRENT_CHARGE
	record["integrity"] = Catalog.MATERIALS[record["material"]]["integrity"]

## Scrap or current taking heat: scrap goes red-hot and burns what it touches; current turns to
## plasma.
func _op_warm(record: Dictionary, _args: Dictionary) -> void:
	record["temp"] = mini(Catalog.temp_of(record) + 1, 2)
	_event("transformed", record["id"])

func _op_chill(record: Dictionary, _args: Dictionary) -> void:
	record["temp"] = maxi(Catalog.temp_of(record) - 1, -2)
	_event("transformed", record["id"])

## A fire put out: smoke, and nothing left to burn.
func _op_quench(record: Dictionary, _args: Dictionary) -> void:
	if record.get("source", false):
		record["quenched_left"] = 4.0
		_dirty = true
		return
	_erase(record["id"], "quenched")

## A fire fed: it burns longer and fiercer.
func _op_stoke(record: Dictionary, _args: Dictionary) -> void:
	record["burn"] = float(record.get("burn", Catalog.FIRE_LIFETIME)) + Catalog.STOKE
	record["fierce"] = true
	_event("transformed", record["id"])

## Legacy host alias; lifting and raising now mean the same thing.
func _op_lift(record: Dictionary, args: Dictionary) -> void:
	_op_raise(record, args)

## Ice frozen further: denser, it takes more to break.
func _op_harden(record: Dictionary, _args: Dictionary) -> void:
	record["temp"] = -2
	record["integrity"] *= HARD_INTEGRITY
	_event("transformed",record["id"])

## Steam heated further: it scalds what is inside, and holds a little longer.
func _op_scald(record: Dictionary, _args: Dictionary) -> void:
	record["temp"] = 2
	record["condense"] = float(record.get("condense",Catalog.STEAM_LIFETIME)) + 1.5
	_event("transformed",record["id"])

## A second coat: the same nanites, denser, so the blast carries further and hits harder.
func _op_charge(record: Dictionary, _args: Dictionary) -> void:
	record["attachments"]["nanites"]["charge"] = 2
	_event("coated",record["id"])

## Charge in the matter: it holds it until something it can reach closes the circuit.
func _op_arc(record: Dictionary, _args: Dictionary) -> void:
	record["charge"] = mini(int(record.get("charge", 0)) + 1, Catalog.MAX_CURRENT if record["material"] == "current" else 2)
	_event("charged",record["id"])

## Water or ice pushed along the floor. Water runs as a wave and goes round machines; ice is a
## ram that breaks on what it meets (see `_physics_process`).
func _op_slide(record: Dictionary, args: Dictionary) -> void:
	var force: Vector3 = args["vector"]
	force.y = 0.0
	record["velocity"] = force.limit_length(12.0)
	record["sliding"] = true
	_event("impulsed",record["id"])

## A well: the matter spins out into a ring and draws what is loose round onto it (the survivor
## run does the same to machines). When it ends it lets go (see _release).
func _op_well(record: Dictionary, args: Dictionary) -> void:
	record["grav"] = 1
	# A well remembers its strength after it fades, so a relay pulse can wake it again.
	record["grav_power"] = float(record.get("grav_power", 1.0))
	record["grav_left"] = float(args.get("time", WELL_TIME))
	_event("well",record["id"])

## A repulsor: a wave runs out from the matter, then a bubble holds round it. `wave_age` is how
## long the front has been running, replicated so every peer draws it where the host throws.
func _op_repel(record: Dictionary, args: Dictionary) -> void:
	record["grav"] = -1
	record["grav_left"] = float(args.get("time", REPEL_TIME))
	record["wave_age"] = 0.0
	_event("repelled",record["id"])

## The matter falls from above: walls topple along `vector`, ice and shards crush what is under
## them and break, steam comes down as rain and settles as water.
func _op_drop(record: Dictionary, args: Dictionary) -> void:
	var toward: Vector3 = args.get("vector",Vector3.ZERO)
	toward.y = 0.0
	if record["shape"] == "wall":
		record["position"] += (toward.normalized() if toward.length() > 0.01 else Basis(Vector3.UP,record["yaw"]).z) * 1.4
		record["shape"] = "patch"
		record["size"] = Catalog.PATCH_SIZE
	_settle(record)
	if record["material"] == "steam":
		_transition(record,"water")
	if record["material"] in ["water", "fire", "current", "scrap"]:
		record["shape"] = "patch"
		record["size"] = Catalog.PATCH_SIZE
	_event("dropped",record["id"])
	# Scrap comes down hardest and lies where it fell; ice crushes and breaks.
	if record["material"] == "scrap": _crush(record["position"],DROP_RADIUS,DROP_DAMAGE * 1.5,record["id"])
	var heavy: bool = record["material"] == "ice"
	if heavy: _crush(record["position"],DROP_RADIUS,DROP_DAMAGE,record["id"])
	if heavy and record["shape"] == "fragments": _erase(record["id"],"collided")
	elif heavy: _damage(record["id"],999.0)

func _crush(point: Vector3, radius: float, damage: float, source: int) -> void:
	for actor: Node in get_tree().get_nodes_in_group("matter_damageable"):
		if not actor is Node3D or not actor.has_method("take_damage"): continue
		var gap: Vector3 = actor.global_position - point
		var distance: float = Vector2(gap.x,gap.z).length()
		if distance < radius and absf(gap.y) < 2.0: strike(actor, records.get(source, {}), damage*(1.0-0.5*distance/radius))
	for id: int in records.keys():
		if id != source and records[id]["position"].distance_to(point) < radius: _damage(id,damage)

func _op_link(record: Dictionary, args: Dictionary) -> void:
	record["link"] = int(args["to"])
	_event("linked",record["id"])

func _op_impact(record: Dictionary, _args: Dictionary) -> void:
	_damage(record["id"],25.0)

func _op_push(record: Dictionary, args: Dictionary) -> void:
	var force: Vector3 = args["vector"]
	force.y = 0.0
	record["velocity"] = (record["velocity"] + force.limit_length(16.0)).limit_length(20.0)
	_event("impulsed",record["id"])

func _op_coat(record: Dictionary, args: Dictionary) -> void:
	var coating: String = str(args.get("coating","nanites"))
	record["attachments"][coating] = {"owner": record["owner"]}
	_event("coated",record["id"])

func _op_command(record: Dictionary, args: Dictionary) -> void:
	var coating: String = str(args.get("coating","nanites"))
	_event("commanded",record["id"])
	call(ATTACHMENT_COMMANDS[str(args["command"])],record,coating)

func _detonate_attachment(record: Dictionary, coating: String) -> void:
	var spec: Dictionary = Catalog.COATINGS[coating]
	var charge: float = float(record["attachments"][coating].get("charge", 1))
	record["attachments"].erase(coating)
	# Approximate coverage with three lobes along the target's own shape. Divide the
	# energy, so a long coated object does not multiply its damage for free.
	var suspended: bool = record["material"] == "steam"
	var origin: Vector3 = record["position"] + Vector3.UP*(record["size"].y*0.5 if suspended else 0.6)
	var axis := Basis(Vector3.UP,record["yaw"]).x
	var half_span: float = record["size"].x * 0.35
	var radius: float = spec["radius"] * (Catalog.SUSPENDED_BLAST_RADIUS if suspended else 1.0) * (1.0 + (charge-1.0)*0.35)
	var id: int = record["id"]
	for offset: float in [-half_span,0.0,half_span]:
		_blast(origin+axis*offset,radius,spec["damage"]*charge/3.0,id)

func _op_react(record: Dictionary, args: Dictionary) -> void:
	record["reaction"] = {"trigger": args["trigger"], "action": args["action"], "vector": args.get("vector", Vector3.ZERO).limit_length(16.0)}
	_event("armed", record["id"])

func _op_remove(record: Dictionary, _args: Dictionary) -> void:
	_erase(record["id"],"removed")

## Host: a routine's matter used up by its reaction. Its water lands where it was.
func spend(id: int) -> void:
	if not multiplayer.is_server() or not records.has(id): return
	_erase(id, "spent")

func damage_construct(id: int, amount: float) -> void:
	if not multiplayer.is_server() or not is_finite(amount) or amount <= 0: return
	if _busy:
		if _pending_damage.size() < 32: _pending_damage.append({"id": id,"amount": minf(amount,100.0)})
		return
	_busy = true
	_damage(id,minf(amount,100.0))
	_publish()
	_busy = false

func _damage(id: int, amount: float) -> void:
	if not records.has(id) or not Catalog.has_property(records[id],"breakable"): return
	var record: Dictionary = records[id]
	record["integrity"] -= amount
	_event("hit",id)
	_dirty = true
	if record["integrity"] > 0.0: return
	if Catalog.has_property(record,"brittle") and record["shape"] != "fragments":
		_settle(record)
		record["shape"] = "fragments"
		record["properties"] = ["movable", "wind_reactive"]
		record["integrity"] = 5.0
		record["ttl"] = 8.0
		_event("broken",id)
	else: _erase(id,"destroyed")

func _blast(point: Vector3, radius: float, damage: float, source: int) -> void:
	_events.append({"kind": "detonated","id": source,"position": point,"material": records[source]["material"] if records.has(source) else ""})
	for id: int in records.keys():
		var distance: float = records[id]["position"].distance_to(point)
		if distance < radius and _blast_visible(point, records[id]["position"]+Vector3.UP*0.6, views.get(id), source): _damage(id,damage*(1.0-distance/radius))
	for actor: Node in get_tree().get_nodes_in_group("matter_damageable"):
		if not actor is Node3D or not actor.has_method("take_damage"): continue
		var distance: float = actor.global_position.distance_to(point)
		if distance < radius and _blast_visible(point, actor.global_position+Vector3.UP*0.6, actor, source): strike(actor, records.get(source, {}), damage*(1.0-distance/radius))

func _blast_visible(origin: Vector3, target: Vector3, body: Node, source: int) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(origin,target,1)
	if views.has(source): ray.exclude = [views[source].get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.collider == body

func _erase(id: int, reason: String) -> void:
	if not records.has(id): return
	_event(reason,id)
	var record: Dictionary = records[id]
	records.erase(id)
	if residue and record["material"] in ["fire", "current"] and reason in ["burned", "quenched", "spent", "expired", "collided"]:
		_mark_serial += 1
		floor_marks.append({"id": _mark_serial, "position": Vector3(record["position"].x, record.get("ground_y", 0.07), record["position"].z), "kind": record["material"], "left": 8.0})
		if floor_marks.size() > MAX_FLOOR_MARKS: floor_marks.pop_front()
	for other: Dictionary in records.values():
		if other.get("link",0) == id: other.erase("link")
	_dirty = true
	# The crew's water is water however it ends: a splash, a shattered orb, shards that melt, a
	# cloud that rains; scrap is scrap. Each lands where it ended. Fire is consumed as it burns
	# and current as it discharges: they leave nothing to pick up.
	var lands: String = {"water": "water", "scrap": "scrap"}.get(Catalog.substance_of(record["material"]), "")
	if residue and record["owner"] != YARD and reason in SPENT and lands != "":
		spill(Vector3(record["position"].x, float(record.get("ground_y", record["position"].y)), record["position"].z), float(record.get("volume", 1.0)), lands)

## Ways a construct ends that leave its water on the floor.
const SPENT := ["expired", "spent", "collided", "destroyed"]
## Whether spent matter lands as water. The survivor run turns it on; the bare matter sandbox keeps
## its constructs self-contained.
var residue: bool = false

## Host: water (or scrap) landing on the floor at `point`. It joins a yard puddle (or pile) of the
## same already there, or lies as a new one the yard owns. Returns its id, or 0 when it ran off:
## no level floor, or the yard already holds all it keeps.
func spill(point: Vector3, volume: float = 1.0, material: String = "water") -> int:
	if not multiplayer.is_server() or volume <= 0.0 or not point.is_finite(): return 0
	var best: int = 0
	var nearest: float = MERGE_REACH
	var yard: int = 0
	for record: Dictionary in records.values():
		if record["owner"] != YARD: continue
		if (record["material"] == "scrap") == (material == "scrap") and not record.get("source", false): yard += 1
		if not Catalog.drawable(record, material) or record.get("source", false) and material != "water": continue
		var distance: float = Vector2(record["position"].x - point.x, record["position"].z - point.z).length()
		if distance < nearest:
			nearest = distance
			best = record["id"]
	if best != 0:
		fill(best, volume)
		return best
	if yard >= (YARD_PILES if material == "scrap" else YARD_PUDDLES): return 0
	var floor_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.5, point - Vector3.UP * 2.0, 1))
	if floor_hit.is_empty() or floor_hit.normal.y < 0.9: return 0
	return _puddle(floor_hit.position + Vector3.UP * 0.02, minf(volume, Catalog.MAX_VOLUME), PUDDLE_TTL if material == "water" else SCRAP_TTL, material)

## Host: a source keeps its matter where it stands: a burst main its puddle, a burning drum its
## fire, a transformer its live terminals, a junk heap its scrap. Each gives a draught at a time
## and refills.
func add_source(point: Vector3, material: String = "water") -> int:
	if not multiplayer.is_server(): return 0
	var floor_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.5, point - Vector3.UP * 2.0, 1))
	if floor_hit.is_empty(): return 0
	var id: int = _puddle(floor_hit.position + Vector3.UP * 0.02, Catalog.MAX_VOLUME, INF, material)
	records[id]["source"] = true
	records[id]["refill"] = REFILL[material]
	records[id]["size"] = size_of(records[id])
	return id

## Seconds a source takes to give back one draught, by what it holds.
const REFILL := {"water": SOURCE_REFILL, "fire": 4.0, "current": 5.0, "scrap": 6.0}
## Scrap lies longer than water does before the yard's sweepers take it.
const SCRAP_TTL := 25.0

## How big a puddle, pile or source draws: drums and transformers are their own size.
static func size_of(record: Dictionary) -> Vector3:
	if record.get("source", false) and record["material"] in ["fire", "current"]: return Catalog.SOURCE_SIZE
	return Catalog.puddle_size(float(record.get("volume", 1.0)))

## A draught boiled off a puddle: a cloud of the yard's that rains back where it stands.
func _cloud(at: Vector3) -> void:
	var id: int = _puddle(at, 1.0, PUDDLE_TTL)
	_transition(records[id], "steam")

## Condensed yard water joins the puddle it rose from, if that is still there.
func _merge(record: Dictionary) -> void:
	for other: Dictionary in records.values():
		if other["id"] == record["id"] or other["owner"] != YARD or not Catalog.drawable(other): continue
		if Vector2(other["position"].x - record["position"].x, other["position"].z - record["position"].z).length() > MERGE_REACH: continue
		fill(other["id"], float(record.get("volume", 1.0)))
		_erase(record["id"], "merged")
		return

func _puddle(at: Vector3, volume: float, ttl: float, material: String = "water") -> int:
	var id: int = next_id
	next_id += 1
	records[id] = {"id": id, "owner": YARD, "material": material, "shape": "patch", "states": Catalog.MATERIALS[material]["initial_states"].duplicate(), "properties": [], "attachments": {},
		"position": at, "ground_y": at.y, "suspended": false, "size": Catalog.puddle_size(volume), "yaw": 0.0, "velocity": Vector3.ZERO,
		"integrity": Catalog.MATERIALS[material]["integrity"], "ttl": ttl, "temp": Catalog.PHASE_TEMP[material], "mass": Catalog.MASS[material], "volume": volume}
	if material == "current": records[id]["charge"] = 1
	_event("created", id)
	_dirty = true
	return id

## Host: more water into a puddle; it spreads to hold it.
func fill(id: int, volume: float) -> void:
	if not records.has(id): return
	var record: Dictionary = records[id]
	record["volume"] = minf(Catalog.MAX_VOLUME, float(record.get("volume", 1.0)) + volume)
	record["size"] = size_of(record)
	if not record.get("source", false): record["ttl"] = maxf(record["ttl"], PUDDLE_TTL)
	_event("filled", id)
	_dirty = true

## Host: one draught taken out of a puddle -- a routine drawing it, the Novia drinking it. The
## puddle shrinks; drunk dry it is gone, except a source, which keeps its film and refills.
## Returns where the water was taken from, or null when there was not a draught there.
func draw_from(id: int, volume: float = 1.0) -> Variant:
	if not multiplayer.is_server() or not records.has(id) or not Catalog.drawable(records[id], records[id]["material"]): return null
	var record: Dictionary = records[id]
	var left: float = float(record.get("volume", 1.0)) - volume
	if left < -0.01: return null
	var at: Vector3 = record["position"]
	if left <= 0.01 and not record.get("source", false):
		_erase(id, "drawn")
		return at
	record["volume"] = maxf(left, 0.0)
	record["size"] = size_of(record)
	_event("drawn", id)
	_dirty = true
	return at

func _event(kind: String, id: int) -> void:
	if _events.size() < 128:
		_events.append({"kind": kind,"id": id,"position": records[id]["position"],"material": records[id]["material"],"shape": records[id]["shape"]})

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or _busy: return
	var start: int = Time.get_ticks_usec()
	_busy = true
	for mark: Dictionary in floor_marks: mark["left"] -= delta
	var kept: Array = floor_marks.filter(func(mark: Dictionary) -> bool: return float(mark["left"]) > 0.0)
	if kept.size() != floor_marks.size(): _dirty = true
	floor_marks = kept
	for id: int in records.keys():
		# A well may have swallowed it earlier this tick.
		if not records.has(id): continue
		var record: Dictionary = records[id]
		record["ttl"] -= delta
		if record["ttl"] <= 0.0:
			_erase(id,"evaporated" if record["owner"] == YARD else "expired")
			continue
		if record["owner"] == YARD: _yard(record, delta)
		if record.has("burn") and not record.get("source", false):
			record["burn"] -= delta
			if record["burn"] <= 0.0:
				_erase(id, "burned")
				continue
		if record.has("condense"):
			record["condense"] -= delta
			if record["condense"] <= 0.0:
				_transition(record,"water")
				if record["owner"] == YARD and not record.get("suspended", false): _merge(record)
				_dirty = true
				continue
		if record.has("grav_left"):
			record["grav_left"] -= delta
			if record["grav_left"] <= 0.0:
				var spun: bool = int(record.get("grav", 0)) > 0
				record.erase("grav_left")
				record.erase("grav")
				record.erase("wave_age")
				_dirty = true
				if spun: _release(record)
			else: _pull_toward(record,delta)
		var velocity: Vector3 = record["velocity"]
		if velocity.length_squared() < 0.01:
			record.erase("sliding")
			record.erase("motion_tail")
			continue
		var tail: Array = record.get("motion_tail", [])
		if tail.is_empty() or (tail.back() as Vector3).distance_to(record["position"]) > 0.3:
			tail.append(record["position"])
			if tail.size() > 6: tail.pop_front()
			record["motion_tail"] = tail
		var origin: Vector3 = record["position"] + Vector3.UP * (record["size"].y * 0.5 if record["shape"] == "orb" else 0.6)
		var destination: Vector3 = origin + velocity*delta
		# A wave runs round machines (the run soaks them); everything else meets them.
		var wave: bool = record.get("sliding", false) and record["material"] in ["water", "fire", "current"]
		var ray := PhysicsRayQueryParameters3D.create(origin,destination + velocity.normalized()*(record["size"].x*0.3 if record.get("sliding", false) else 0.0),1 if wave else 1 | 4)
		if views.has(id): ray.exclude = [views[id].get_rid()]
		var hit: Dictionary = _sweep_orb(record, velocity * delta) if record["shape"] == "orb" else get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and record["shape"] == "orb":
			strike(hit.collider, record, Catalog.impact(record, velocity.length()))
			if record["material"] in ["ice", "scrap"]: _damage(id, 999.0)
			else:
				# Water splashes, fire spatters into a burning pool, current goes to ground.
				_event({"fire": "flared", "current": "grounded"}.get(record["material"], "splashed"), id)
				_settle(record)
				record["shape"] = "patch"
				record["size"] = Catalog.PATCH_SIZE
		elif not hit.is_empty() and record.get("sliding", false):
			# A sliding sheet stops where it meets something; ice rams it and breaks.
			record["velocity"] = Vector3.ZERO
			record.erase("sliding")
			if record["material"] in ["ice", "scrap"]:
				strike(hit.collider, record, Catalog.impact(record, velocity.length()))
				_damage(id,999.0)
		elif not hit.is_empty() and record["material"] == "steam":
			# A pushed cloud banks up against what it meets; vapour has nothing to break with.
			record["velocity"] = Vector3.ZERO
		elif not hit.is_empty():
			strike(hit.collider, record, Catalog.impact(record, velocity.length()))
			_erase(id,"collided")
		else:
			record["position"] += velocity*delta
			record["velocity"] = velocity.move_toward(Vector3.ZERO,delta*(5.0 if record.get("sliding", false) else 1.5))
		_dirty = true
	var pending: Array[Dictionary] = _pending_damage.duplicate()
	_pending_damage.clear()
	for damage: Dictionary in pending: _damage(damage["id"],damage["amount"])
	var heated: Array[int] = _pending_heat.duplicate()
	_pending_heat.clear()
	for heated_id: int in heated: _heat(heated_id)
	_tick += delta
	# Host views update at physics cadence; network snapshots are bounded at 10 Hz in motion.
	_sync_views()
	if _tick >= 0.1:
		_tick = 0.0
		if _dirty: _publish()
	_busy = false
	var cost: int = Time.get_ticks_usec()-start
	tick_usec_max = maxi(tick_usec_max,cost)
	tick_usec_total += cost
	tick_count += 1

## Sweep the real sphere, including grazing hits that a center ray would miss.
func _sweep_orb(record: Dictionary, motion: Vector3) -> Dictionary:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = record["size"].x * 0.5
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, record["position"] + Vector3.UP * record["size"].y * 0.5)
	query.collision_mask = 1 | 4
	query.margin = 0.015
	if views.has(record["id"]): query.exclude = [views[record["id"]].get_rid()]
	var space := get_world_3d().direct_space_state
	var hit: Dictionary = space.get_rest_info(query)
	if hit.is_empty():
		query.motion = motion
		var travel: PackedFloat32Array = space.cast_motion(query)
		if travel.size() < 2 or travel[0] >= 1.0: return {}
		query.transform.origin += motion * travel[1]
		query.motion = Vector3.ZERO
		hit = space.get_rest_info(query)
	if not hit.is_empty(): hit["collider"] = instance_from_id(hit["collider_id"])
	return hit

## Fire passing through standing water flashes it to steam. Called by projectiles on the host.
func heat_along(from: Vector3, to: Vector3) -> void:
	if not multiplayer.is_server(): return
	for id: int in records.keys():
		var record: Dictionary = records[id]
		if record["material"] != "water" or id in _pending_heat or not _segment_hits_box(from,to,record): continue
		if _busy: _pending_heat.append(id)
		else:
			_busy = true
			_heat(id)
			_publish()
			_busy = false

## Both fields act on free matter. Anchored walls resist; grounded patches slide.
## The yard looks after its own water: sources refill, its ice warms back to water, and a
## puddle near its end dries from the edges in.
func _yard(record: Dictionary, delta: float) -> void:
	if record.has("quenched_left"):
		record["quenched_left"] -= delta
		if record["quenched_left"] <= 0.0:
			record.erase("quenched_left")
			_dirty = true
	if record["material"] == "ice":
		record["melt"] = float(record.get("melt", MELT_TIME)) - delta
		if record["melt"] <= 0.0:
			record.erase("melt")
			_transition(record, "water")
			record["shape"] = "patch"
			record["size"] = Catalog.puddle_size(float(record.get("volume", 1.0)))
			_dirty = true
		return
	if record.has("scorched"):
		record["scorched"] -= delta
		if record["scorched"] <= 0.0: record.erase("scorched")
	if record.get("source", false) and REFILL.has(record["material"]):
		record["refill"] = float(record.get("refill", SOURCE_REFILL)) - delta
		if record["refill"] <= 0.0:
			record["refill"] = REFILL[record["material"]]
			if float(record.get("volume", 0.0)) < Catalog.MAX_VOLUME: fill(record["id"], 1.0)
			# A transformer's terminals charge back up after they have arced.
			if record["material"] == "current" and int(record.get("charge", 0)) < 1:
				record["charge"] = 1
				_dirty = true
		return
	if record["ttl"] < EVAPORATE and record["shape"] == "patch":
		var dried: Vector3 = Catalog.puddle_size(float(record.get("volume", 1.0)) * maxf(record["ttl"] / EVAPORATE, 0.1))
		if dried.distance_to(record["size"]) > 0.08:
			record["size"] = dried
			_dirty = true

## A field moving the loose matter round it; the yard's stores, walls and other fields stay put.
## Nothing is swallowed or merged: what a well catches keeps its own identity and goes round on
## the ring, meeting the well's matter there by the usual rules. A repulsor's front throws what
## it passes once, then its bubble pushes back whatever drifts inside.
func _pull_toward(record: Dictionary, delta: float) -> void:
	var center: Vector3 = Catalog.field_center(record)
	var spinning: bool = int(record.get("grav", 0)) > 0
	var front: float = 0.0
	var last_front: float = 0.0
	if not spinning:
		last_front = Catalog.wave_front(float(record.get("wave_age", 0.0)))
		record["wave_age"] = float(record.get("wave_age", 0.0)) + delta
		front = Catalog.wave_front(float(record["wave_age"]))
	for other: Dictionary in records.values():
		if other["id"] == record["id"] or not Catalog.field_mobile(other) or other.get("source", false): continue
		var gap := Vector3(other["position"].x - center.x, 0, other["position"].z - center.z)
		var distance: float = gap.length()
		if spinning:
			if distance > Catalog.VORTEX_REACH: continue
			other["velocity"] = Catalog.orbit_velocity(other["velocity"], center, other["position"], delta, Catalog.gravity(record))
		elif distance > last_front and distance <= front:
			other["velocity"] = Catalog.blast_velocity(center, other["position"])
		elif distance < Catalog.BUBBLE:
			other["velocity"] = other["velocity"].move_toward(gap.normalized() * 4.0, Catalog.FIELD_ACCEL * delta)
		else: continue
		if other["shape"] == "patch": other["sliding"] = true
		_dirty = true

## A well letting go: everything loose riding its ring flies off along it, and the survivor run
## does the same to machines and flings the well's own matter (event "released").
func _release(record: Dictionary) -> void:
	var center: Vector3 = Catalog.field_center(record)
	for other: Dictionary in records.values():
		if other["id"] == record["id"] or not Catalog.field_mobile(other) or other.get("source", false): continue
		var gap := Vector3(other["position"].x - center.x, 0, other["position"].z - center.z)
		if gap.length() > Catalog.VORTEX_RING + Catalog.RING_BAND * 1.5: continue
		other["velocity"] = Catalog.sling(center, other["position"])
		if other["shape"] == "patch": other["sliding"] = true
	_event("released", record["id"])

## Seconds a deep puddle needs between one draught boiled off it and the next.
const SCORCH := 1.5

func _heat(id: int) -> void:
	# Fire over a deep puddle boils one draught off it into a cloud; a shallow one flashes whole.
	if records.has(id) and records[id]["material"] == "water" and float(records[id].get("volume", 1.0)) > 1.01:
		var record: Dictionary = records[id]
		if float(record.get("scorched", 0.0)) > 0.0: return
		record["scorched"] = SCORCH
		var at: Variant = draw_from(id)
		if at != null: _cloud(at)
		return
	if records.has(id) and Catalog.TRANSITIONS["heat"].has(records[id]["material"]):
		_transition(records[id],Catalog.TRANSITIONS["heat"][records[id]["material"]])
		_dirty = true

func _segment_hits_box(from: Vector3, to: Vector3, record: Dictionary) -> bool:
	var half: Vector3 = record["size"] * 0.5 + Vector3.ONE * 0.08
	var inverse: Basis = Basis(Vector3.UP,record["yaw"]).inverse()
	var center: Vector3 = record["position"] + Vector3.UP*record["size"].y*0.5
	var a: Vector3 = inverse * (from-center)
	var d: Vector3 = inverse * (to-from)
	var enter: float = 0.0
	var leave: float = 1.0
	for axis: int in 3:
		if absf(d[axis]) < 0.00001:
			if absf(a[axis]) > half[axis]: return false
			continue
		var t0: float = (-half[axis]-a[axis])/d[axis]
		var t1: float = (half[axis]-a[axis])/d[axis]
		enter = maxf(enter,minf(t0,t1))
		leave = minf(leave,maxf(t0,t1))
		if enter > leave: return false
	return true

## Where a sight line first enters a dense cloud, or null when it stays clear. Pure reads of
## replicated records, so a client can draw what the host will decide.
func sight_obstruction(from: Vector3, to: Vector3) -> Variant:
	var nearest: float = 2.0
	for record: Dictionary in records.values():
		if record["material"] != "steam": continue
		# The fringe stays see-through: only the inner 80% of the ellipsoid hides a target.
		var radii: Vector3 = record["size"] * 0.5 * 0.8
		var inverse: Basis = Basis(Vector3.UP,record["yaw"]).inverse()
		var center: Vector3 = record["position"] + Vector3.UP*record["size"].y*0.5
		var a: Vector3 = (inverse * (from-center)) / radii
		var d: Vector3 = (inverse * (to-from)) / radii
		# Solve |a + d t| = 1 for the first t in [0, 1].
		var qa: float = d.length_squared()
		var qb: float = 2.0*a.dot(d)
		var qc: float = a.length_squared()-1.0
		var disc: float = qb*qb-4.0*qa*qc
		if qa < 0.000001 or disc < 0.0: continue
		var t: float = (-qb-sqrt(disc))/(2.0*qa)
		if qc < 0.0: t = 0.0
		if t >= 0.0 and t <= 1.0: nearest = minf(nearest,t)
	return from.lerp(to,nearest) if nearest <= 1.0 else null

func sight_blocked(from: Vector3, to: Vector3) -> bool:
	return sight_obstruction(from,to) != null

## A conduit pulse leaves `from_id` now; the reaction scheduler resolves its arrival.
func announce_pulse(from_id: int, to_id: int) -> float:
	if not records.has(from_id) or not records.has(to_id): return -1.0
	var a: Vector3 = records[from_id]["position"]
	var b: Vector3 = records[to_id]["position"]
	var duration: float = maxf(0.15,a.distance_to(b)/Catalog.PULSE_SPEED)
	if _events.size() < 128: _events.append({"kind":"pulse","id":from_id,"position":a,"to":b,"duration":duration})
	_dirty = true
	return duration

## A reaction bursting at `id`, for the effects every peer draws.
func announce_burst(id: int) -> void:
	if not records.has(id): return
	if _events.size() < 128: _events.append({"kind":"burst","id":id,"position":records[id]["position"],"material":records[id]["material"]})
	_dirty = true

func deliver_pulse(to_id: int) -> void:
	if not multiplayer.is_server() or _busy or not records.has(to_id): return
	_busy = true
	_event("pulsed",to_id)
	_dirty = true
	_publish()
	_busy = false

func _publish() -> void:
	_sync_views()
	revision += 1
	var state: Array = records.values().duplicate(true)
	var events: Array = _events.duplicate(true)
	_events.clear()
	snapshot_bytes = var_to_bytes([revision,state,events,floor_marks]).size()
	if multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().is_empty():
		receive_snapshot.rpc(revision,state,events,floor_marks)
	_dirty = false
	for event: Dictionary in events: _deliver(event)

@rpc("any_peer", "call_remote", "reliable")
func request_snapshot() -> void:
	if not multiplayer.is_server(): return
	var peer: int = multiplayer.get_remote_sender_id()
	if peer > 1: receive_snapshot.rpc_id(peer,revision,records.values(),[],floor_marks)

@rpc("authority", "call_remote", "reliable")
func receive_snapshot(version: int, state: Array, events: Array, marks: Array = []) -> void:
	if multiplayer.is_server() or version <= received_revision: return
	received_revision = version
	floor_marks = marks
	records.clear()
	for record: Dictionary in state: records[record["id"]] = record
	_sync_views()
	for event: Dictionary in events: _deliver(event)

func _deliver(event: Dictionary) -> void:
	matter_event.emit(event)
	if DisplayServer.get_name() == "headless": return
	# Effects are parented beside the world, not under it: its children are the construct views.
	var Fx = preload("res://scripts/matter/matter_fx.gd")
	var id: int = event.get("id", 0)
	if views.has(id): views[id].react_to(event)
	match event["kind"]:
		"detonated":
			var suspended: bool = event.get("material", "") == "steam"
			Fx.shockwave(get_parent(), event["position"], Catalog.COATINGS["nanites"]["radius"] * (Catalog.SUSPENDED_BLAST_RADIUS if suspended else 1.0))
		"destroyed", "collided":
			if event.get("material", "") == "ice": Fx.chips(get_parent(), event["position"] + Vector3.UP * 0.5, null)
		"removed", "expired", "spent":
			Fx.splash(get_parent(), event["position"], Vector3(1.2, 0.1, 0.9))

func _sync_views() -> void:
	for id: int in views.keys():
		if not records.has(id):
			views[id].collision_layer = 0
			views[id].queue_free()
			views.erase(id)
	for id: int in records:
		if not views.has(id):
			var view = View.new()
			view.name = "Matter%d" % id
			view.system = self
			view.construct_id = id
			add_child(view)
			views[id] = view
		views[id].apply(records[id])

## Matter `record` meeting `body` with `amount` of blow, named as the culprit while it lands (and
## the culprit before it restored after): every blow that can credit a routine goes through here.
func strike(body: Object, record: Dictionary, amount: float) -> void:
	if not body.has_method("take_damage"): return
	var was: Dictionary = culprit
	culprit = record
	body.take_damage(amount)
	culprit = was
