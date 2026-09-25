extends Node
var world: Node
var is_host: bool
var phase: int = 0
var elapsed: float = 0.0
var delay: float = 0.0
var own_id: int = 0
var denied: bool = false
var out: String
var peer: ENetMultiplayerPeer

func _ready() -> void: call_deferred("start")
func add_player(id: int) -> void:
	var actor := Node3D.new()
	actor.name = "Player%d" % id
	actor.position = Vector3(-4,0,0)
	actor.set_multiplayer_authority(id)
	actor.add_to_group("coop_players")
	add_child(actor)
func start() -> void:
	# Isolate transport from the production lobby's scene-navigation callbacks.
	for signal_name: String in ["connected_to_server", "server_disconnected", "peer_connected", "peer_disconnected"]:
		for connection: Dictionary in multiplayer.get_signal_connection_list(signal_name):
			var callback: Callable = connection["callable"]
			if callback.get_object() == Lobby: multiplayer.disconnect(signal_name,callback)
	var args := OS.get_cmdline_user_args()
	is_host = args[0] == "host"
	out = args[1]
	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(24367,4) if is_host else peer.create_client("127.0.0.1",24367)
	assert(error == OK)
	multiplayer.multiplayer_peer = peer
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40,1,40)
	collision.shape = box
	collision.position.y = -0.5
	floor_body.add_child(collision)
	add_child(floor_body)
	add_player(1)
	world = preload("res://scripts/matter/world_matter.gd").new()
	world.name = "WorldMatter"
	# Client joins only after connected, so the initial request has an established transport.
	if is_host:
		add_child(world)
		multiplayer.peer_connected.connect(func(id: int): add_player(id))
		multiplayer.peer_disconnected.connect(disconnected)
		for i in 3: await get_tree().physics_frame
		assert(world.execute(1,"create",0,{"point":Vector3.ZERO})["ok"])
		phase = 1
	else:
		multiplayer.connected_to_server.connect(connected)
	set_process(true)
func connected() -> void:
	add_player(multiplayer.get_unique_id())
	add_child(world)
	world.operation_result.connect(func(result: Dictionary):
		if not result["ok"] and result.get("reason","") == "Target belongs to another player": denied = true)
	phase = 1
func disconnected(id: int) -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	var cleaned := true
	for record: Dictionary in world.records.values():
		if record["owner"] == id: cleaned = false
	finish(cleaned and world.records.size() == 1,"disconnect cleanup; host construct retained")
func _process(delta: float) -> void:
	elapsed += delta
	delay += delta
	if elapsed > 45.0:
		finish(false,"timeout phase %d" % phase)
		return
	if is_host or phase == 0 or world == null or not world.is_inside_tree() or delay < 0.2: return
	delay = 0.0
	if phase == 1 and world.records.size() == 1:
		assert(not world.execute(multiplayer.get_unique_id(),"remove",1)["ok"])
		world.submit("remove",1)
		phase = 2
	elif phase == 2 and denied:
		world.get_node("Programs").submit({"steps":[],"trigger":"broken","action":"push"},Vector3(5,0,0),Vector3(0,0,-1))
		phase = 3
	elif phase == 3 and world.records.size() == 2:
		for id: int in world.records:
			if world.records[id]["owner"] == multiplayer.get_unique_id(): own_id = id
		assert(own_id > 0)
		world.submit("freeze",own_id)
		phase = 4
	elif phase == 4 and world.records[own_id]["material"] == "ice":
		assert(world.views[own_id].collision_layer == 1)
		world.submit("coat",own_id)
		phase = 5
	elif phase == 5 and world.records[own_id]["attachments"].has("nanites"):
		world.submit("impact",own_id)
		phase = 6
	elif phase == 6 and world.records[own_id]["shape"] == "fragments":
		assert(world.views[own_id].collision_layer == 0)
		assert(not world.records[own_id].has("reaction")) # Server consumed the one-shot event.
		phase = 7
	elif phase == 7 and world.records[own_id]["position"].z < -0.3:
		finish(true,"late snapshot, ownership rejection, host routine/freeze/coat/break, automatic reaction and motion replication")
func finish(ok: bool, detail: String) -> void:
	set_process(false)
	FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify({"ok":ok,"detail":detail,"phase":phase},"  "))
	print("MATTER NETWORK ","PASS" if ok else "FAIL"," ",detail)
	peer.close()
	get_tree().quit(0 if ok else 1)
