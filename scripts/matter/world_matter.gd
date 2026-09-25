## Host-owned bounded world state. Clients submit intent, never material/damage/state records.
extends Node3D
signal matter_event(event: Dictionary)
signal operation_result(result: Dictionary)
const Catalog = preload("res://scripts/matter/materials.gd")
const View = preload("res://scripts/matter/construct_view.gd")
const OPERATIONS := ["create", "raise", "freeze", "impact", "push", "coat", "command", "remove", "react"]
const ATTACHMENT_COMMANDS := {"detonate": "_detonate_attachment"}
const LIMIT := 32
const OWNER_LIMIT := 8
const REACH := 18.0
var records: Dictionary = {}
var views: Dictionary = {}
var next_id: int = 1
var revision: int = 0
var received_revision: int = -1
var cooldowns: Dictionary = {}
var _events: Array[Dictionary] = []
var _busy: bool = false
var _pending_damage: Array[Dictionary] = []
var _tick: float = 0.0
var _dirty: bool = false
var snapshot_bytes: int = 0
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
	if player == null: return _failure("Player unavailable")
	var record: Dictionary = records.get(target, {})
	var point: Variant = args.get("point", Vector3.ZERO) if op == "create" else record.get("position", Vector3.ZERO)
	if not point is Vector3 or not point.is_finite(): return _failure("Invalid position")
	if player.global_position.distance_to(point) > REACH: return _failure("Out of reach")
	if op == "create":
		var substance: String = str(args.get("material", "water"))
		if not Catalog.MATERIALS.has(substance) or not Catalog.MATERIALS[substance].get("spawnable",false): return _failure("Material has no source in this prototype")
		var owned: int = 0
		for item: Dictionary in records.values():
			if item["owner"] == peer: owned += 1
		if records.size() >= LIMIT or owned >= OWNER_LIMIT: return _failure("Construct limit reached")
		var floor_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2.0,point-Vector3.UP*2.0,1))
		if floor_hit.is_empty() or floor_hit.normal.y < 0.9 or absf(floor_hit.position.y-point.y)>0.5: return _failure("Requires level ground")
		return {"ok": true, "size": Vector3(4,0.12,3), "position": floor_hit.position+Vector3.UP*0.02}
	if record.is_empty(): return _failure("Target no longer exists")
	if record["owner"] != peer and op != "impact": return _failure("Target belongs to another player")
	if op == "raise":
		if not Catalog.has_property(record,"reshapeable") or record["shape"] != "patch": return _failure("Requires reshapeable matter")
		var direction: Variant = args.get("vector", Vector3.RIGHT*4.0)
		if not direction is Vector3 or not direction.is_finite() or Vector2(direction.x,direction.z).length()<0.5: return _failure("Choose a line direction")
	if op == "freeze":
		if not Catalog.TRANSITIONS["freeze"].has(record["material"]): return _failure("Cannot freeze this material")
		if not _solid_clear(record): return _failure("Solid volume is occupied")
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
	if op == "react":
		if args.get("trigger", "") not in ["broken", "hit", "transformed"] or args.get("action", "") not in ["push", "command", "freeze"]: return _failure("Invalid reaction")
		var vector: Variant = args.get("vector", Vector3.ZERO)
		if not vector is Vector3 or not vector.is_finite(): return _failure("Invalid direction")
	if op == "command":
		var coating: String = str(args.get("coating", "nanites"))
		if not record["attachments"].has(coating): return _failure("No compatible attachment")
		if str(args.get("command", "")) not in Catalog.COATINGS[coating]["commands"] or not ATTACHMENT_COMMANDS.has(str(args.get("command", ""))): return _failure("Unsupported attachment command")
	return {"ok": true, "position": point, "size": Vector3(4,1.8,0.2) if op == "raise" else record["size"]}

func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

func _solid_clear(record: Dictionary) -> bool:
	var shape := BoxShape3D.new()
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
		records[id] = {"id": id,"owner": peer,"material": str(args.get("material","water")),"shape": "patch","states": Catalog.MATERIALS[str(args.get("material","water"))]["initial_states"].duplicate(),"properties": [],"attachments": {},"position": result["position"],"size": result["size"],"yaw": 0.0,"velocity": Vector3.ZERO,"integrity": 20.0,"ttl": 60.0}
		_event("created",id)
	else:
		call("_op_" + op,records[id],args)
	_dirty = true
	_publish()
	_busy = false
	return {"ok": true, "id": id}

func _op_raise(record: Dictionary, args: Dictionary) -> void:
	var direction: Vector3 = args.get("vector",Vector3.RIGHT*4.0)
	record["yaw"] = -atan2(direction.z,direction.x)
	record["size"] = Vector3(4,1.8,0.2) # Same 1.44 m³ as the source patch.
	record["shape"] = "wall"
	_event("reshaped",record["id"])

func _op_freeze(record: Dictionary, _args: Dictionary) -> void:
	record["material"] = Catalog.TRANSITIONS["freeze"][record["material"]]
	record["states"] = ["frozen"]
	_event("transformed",record["id"])

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
	record["attachments"].erase(coating)
	# Approximate coverage with three lobes along the target's own shape. Divide the
	# energy, so a long coated object does not multiply its damage for free.
	var origin: Vector3 = record["position"] + Vector3.UP*0.6
	var axis := Basis(Vector3.UP,record["yaw"]).x
	var half_span: float = record["size"].x * 0.35
	var id: int = record["id"]
	for offset: float in [-half_span,0.0,half_span]:
		_blast(origin+axis*offset,spec["radius"],spec["damage"]/3.0,id)

func _op_react(record: Dictionary, args: Dictionary) -> void:
	record["reaction"] = {"trigger": args["trigger"], "action": args["action"], "vector": args.get("vector", Vector3.ZERO).limit_length(16.0)}
	_event("armed", record["id"])

func _op_remove(record: Dictionary, _args: Dictionary) -> void:
	_erase(record["id"],"removed")

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
		record["shape"] = "fragments"
		record["properties"] = ["movable", "wind_reactive"]
		record["integrity"] = 5.0
		record["ttl"] = 8.0
		_event("broken",id)
	else: _erase(id,"destroyed")

func _blast(point: Vector3, radius: float, damage: float, source: int) -> void:
	_events.append({"kind": "detonated","id": source,"position": point})
	for id: int in records.keys():
		var distance: float = records[id]["position"].distance_to(point)
		if distance < radius and _blast_visible(point, records[id]["position"]+Vector3.UP*0.6, views.get(id), source): _damage(id,damage*(1.0-distance/radius))
	for actor: Node in get_tree().get_nodes_in_group("matter_damageable"):
		if not actor is Node3D or not actor.has_method("take_damage"): continue
		var distance: float = actor.global_position.distance_to(point)
		if distance < radius and _blast_visible(point, actor.global_position+Vector3.UP*0.6, actor, source): actor.take_damage(damage*(1.0-distance/radius))

func _blast_visible(origin: Vector3, target: Vector3, body: Node, source: int) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(origin,target,1)
	if views.has(source): ray.exclude = [views[source].get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.collider == body

func _erase(id: int, reason: String) -> void:
	if not records.has(id): return
	_event(reason,id)
	records.erase(id)
	_dirty = true

func _event(kind: String, id: int) -> void:
	if _events.size() < 128:
		_events.append({"kind": kind,"id": id,"position": records[id]["position"]})

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or _busy: return
	var start: int = Time.get_ticks_usec()
	_busy = true
	for id: int in records.keys():
		var record: Dictionary = records[id]
		record["ttl"] -= delta
		if record["ttl"] <= 0.0:
			_erase(id,"expired")
			continue
		var velocity: Vector3 = record["velocity"]
		if velocity.length_squared() < 0.01: continue
		var origin: Vector3 = record["position"]+Vector3.UP*0.6
		var destination: Vector3 = origin + velocity*delta
		var ray := PhysicsRayQueryParameters3D.create(origin,destination,1)
		if views.has(id): ray.exclude = [views[id].get_rid()]
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			if hit.collider.has_method("take_damage"): hit.collider.take_damage(minf(12.0,velocity.length()))
			_erase(id,"collided")
		else:
			record["position"] += velocity*delta
			record["velocity"] = velocity.move_toward(Vector3.ZERO,delta*1.5)
		_dirty = true
	var pending: Array[Dictionary] = _pending_damage.duplicate()
	_pending_damage.clear()
	for damage: Dictionary in pending: _damage(damage["id"],damage["amount"])
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

func _publish() -> void:
	_sync_views()
	revision += 1
	var state: Array = records.values().duplicate(true)
	var events: Array = _events.duplicate(true)
	_events.clear()
	snapshot_bytes = var_to_bytes([revision,state,events]).size()
	if multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().is_empty():
		receive_snapshot.rpc(revision,state,events)
	_dirty = false
	for event: Dictionary in events: _deliver(event)

@rpc("any_peer", "call_remote", "reliable")
func request_snapshot() -> void:
	if not multiplayer.is_server(): return
	var peer: int = multiplayer.get_remote_sender_id()
	if peer > 1: receive_snapshot.rpc_id(peer,revision,records.values(),[])

@rpc("authority", "call_remote", "reliable")
func receive_snapshot(version: int, state: Array, events: Array) -> void:
	if multiplayer.is_server() or version <= received_revision: return
	received_revision = version
	records.clear()
	for record: Dictionary in state: records[record["id"]] = record
	_sync_views()
	for event: Dictionary in events: _deliver(event)

func _deliver(event: Dictionary) -> void:
	matter_event.emit(event)
	if event["kind"] == "detonated" and not DisplayServer.get_name() == "headless":
		preload("res://scenes/actions/combat_fx.gd").burst(self,event["position"],Color(0.9,0.65,0.3))

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
