## A bounded host scheduler for structured routines. No evaluation of player text.
extends Node
signal feedback(result: Dictionary)
const STEPS := ["raise", "freeze", "coat", "impact", "push"]
const TRIGGERS := ["broken", "hit", "transformed"]
const ACTIONS := ["push", "command", "freeze"]
var jobs: Dictionary = {}
var pending: Array[Dictionary] = []
var last_run: Dictionary = {}
@onready var world: Node = get_parent()

func _ready() -> void:
	world.matter_event.connect(_event)
	multiplayer.peer_disconnected.connect(func(peer: int):
		jobs.erase(peer)
		last_run.erase(peer))

func valid(draft: Dictionary) -> bool:
	var steps: Variant = draft.get("steps", [])
	if not steps is Array or steps.size() > 4: return false
	for step: Variant in steps:
		if not step is String or step not in STEPS: return false
	return draft.get("trigger", "") in TRIGGERS and draft.get("action", "") in ACTIONS

func submit(draft: Dictionary, point: Vector3, direction: Vector3) -> void:
	request_run.rpc_id(1, draft, point, direction)

@rpc("any_peer", "call_local", "reliable")
func request_run(draft: Dictionary, point: Vector3, direction: Vector3) -> void:
	if not multiplayer.is_server(): return
	var peer: int = multiplayer.get_remote_sender_id()
	if peer == 0: peer = multiplayer.get_unique_id()
	var result: Dictionary = start(peer, draft, point, direction)
	_reply(peer, result)

func start(peer: int, draft: Dictionary, point: Vector3, direction: Vector3) -> Dictionary:
	if not multiplayer.is_server(): return {"ok": false, "reason": "Host only"}
	direction.y = 0
	if not valid(draft) or not direction.is_finite() or direction.length() < 0.1:
		return {"ok": false, "reason": "Rutina inválida"}
	if jobs.has(peer): return {"ok": false, "reason": "Rutina en ejecución"}
	var now: int = Time.get_ticks_msec()
	if now - int(last_run.get(peer, -6000)) < 6000: return {"ok": false, "reason": "Recarga · 6 s entre despliegues"}
	var result: Dictionary = world.execute(peer, "create", 0, {"point": point})
	if not result["ok"]: return result
	last_run[peer] = now
	direction.y = 0
	jobs[peer] = {"id": result["id"], "steps": draft["steps"].duplicate(), "trigger": draft["trigger"], "action": draft["action"], "vector": direction.normalized()*14.0, "delay": 0.18}
	return {"ok": true, "id": result["id"], "message": "Rutina iniciada"}

func _event(event: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var record: Dictionary = world.records.get(event["id"], {})
	var reaction: Dictionary = record.get("reaction", {})
	if reaction.is_empty() or reaction["trigger"] != event["kind"]: return
	# Consume before scheduling. Each binding fires once, so events cannot recurse.
	record.erase("reaction")
	if pending.size() < 32:
		pending.append({"peer": record["owner"], "id": record["id"], "action": reaction["action"], "vector": reaction["vector"]})
	world._dirty = true

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or world._busy: return
	var work: Array[Dictionary] = pending.duplicate()
	pending.clear()
	for item: Dictionary in work:
		var result: Dictionary = world.execute(item["peer"], item["action"], item["id"], {"vector": item["vector"], "command": "detonate"})
		result["message"] = "Reacción ejecutada · " + item["action"]
		_reply(item["peer"], result)
	for peer: int in jobs.keys():
		var job: Dictionary = jobs[peer]
		job["delay"] -= delta
		if job["delay"] > 0: continue
		job["delay"] = 0.18
		if not world.records.has(job["id"]):
			jobs.erase(peer)
			_reply(peer, {"ok": false, "reason": "La referencia ya no existe"})
			continue
		if job["steps"].is_empty():
			var result: Dictionary = world.execute(peer, "react", job["id"], job)
			result["message"] = "Armado · " + job["trigger"] + " → " + job["action"]
			_reply(peer, result)
			jobs.erase(peer)
			continue
		var op: String = job["steps"].pop_front()
		var vector: Vector3 = job["vector"]
		if op == "raise": vector = vector.cross(Vector3.UP)
		var result: Dictionary = world.execute(peer, op, job["id"], {"vector": vector})
		if not result["ok"]:
			jobs.erase(peer)
			_reply(peer, result) # Keep completed matter so failures are legible, not rolled back.

func _reply(peer: int, result: Dictionary) -> void:
	if peer == multiplayer.get_unique_id(): feedback.emit(result)
	elif peer in multiplayer.get_peers(): receive_feedback.rpc_id(peer, result)

@rpc("authority", "call_remote", "reliable")
func receive_feedback(result: Dictionary) -> void:
	feedback.emit(result)
