## Two actual ENet processes: authority, replication, movement and independent upgrade choices.
extends Node
var scene: Node
var run: Node
var is_host: bool
var client_id: int = 0
var report: Dictionary = {}
var checks: Dictionary = {}
## The beats of its own routines this peer heard, by stage: what lights its program in the corner.
var beats: Dictionary = {}
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_host = "host" in OS.get_cmdline_user_args()
	Game.instance.multiplayer_test = false
	Lobby.instance.return_to_lobby_on_player_disconnect = false
	var peer := ENetMultiplayerPeer.new()
	if is_host:
		peer.create_server(15467, 1)
		multiplayer.multiplayer_peer = peer
	else:
		peer.create_client("127.0.0.1", 15467)
		multiplayer.multiplayer_peer = peer
		multiplayer.connected_to_server.connect(func() -> void: register.rpc_id(1, multiplayer.get_unique_id()))
	get_tree().create_timer(25, true).timeout.connect(func() -> void:
		push_error("SURVIVOR NETWORK TIMEOUT")
		get_tree().quit(1))
@rpc("any_peer", "reliable")
func register(id: int) -> void:
	if not is_host: return
	client_id = id
	launch.rpc(id)
	call_deferred("host_checks")
@rpc("authority", "call_local", "reliable")
func launch(id: int) -> void:
	Game.instance.players = [Statics.PlayerData.new(1,"Host",0,Statics.Role.DAMAGE), Statics.PlayerData.new(id,"Client",1,Statics.Role.SUPPORT)]
	scene = load("res://scenes/main_scene.tscn").instantiate()
	add_child(scene)
	run = scene.get_node("SurvivorRun")
	run.test_mode = true
	run.spellwork.beat.connect(func(peer: int, _index: int, stage: String, _k: int, _duration: float) -> void:
		if peer == multiplayer.get_unique_id(): beats[stage] = int(beats.get(stage, 0)) + 1)
func frames(count: int) -> void:
	for i: int in count: await get_tree().physics_frame
func host_checks() -> void:
	await frames(100)
	checks["both_peers_spawned"] = scene.get_node("Players").get_child_count() == 2
	var player: Character = run.world._player(1)
	player.global_position = Vector3(-3,1.15,-2)
	run.spawn_machine.rpc(700, Vector3(-3,0.05,-7), 0, 1.0)
	await frames(230)
	checks["host_auto_combat"] = run.automations_fired > 0 and run.kills > 0
	var client: Character = run.world._player(client_id)
	var before: Vector3 = client.global_position
	move_client.rpc()
	await frames(55)
	checks["client_movement_replicates"] = client.global_position.distance_to(before) > 0.3
	run.gain_xp(8)
	await frames(15)
	checks["both_receive_choices"] = run.offers.size() == 2
	var key: String = run.offers[1][0]
	run.choose_upgrade(key)
	checks["host_cannot_spend_client_choice"] = run.offers.size() == 1 and run.offers.has(client_id)
	choose_client.rpc()
	await frames(20)
	checks["both_choices_resume_world"] = run.phase == "running" and not get_tree().paused
	# A specialist's tell must reach the client: same phase, same marked landing zone.
	var hound: Node = null
	run.spawn_machine.rpc(701, player.global_position + Vector3(0, -1.1, -5.5), 3, 1.0)
	await frames(2)
	hound = run.machines.get_node_or_null("Machine701")
	if hound != null:
		hound.health = 5000
		hound.cooldown = 0.0
		for i: int in 400:
			if hound.state == "crouch": break
			await get_tree().physics_frame
		checks["host_specialist_crouches"] = hound.state == "crouch"
		inspect_specialist.rpc(hound.state_to)
		await frames(10)
	# A gravity well built on the host reaches the client as a field it can draw.
	run.builds[1]["routines"][0] = {"when": "cerca", "steps": ["well", "coat"], "then": "detonar", "on": "pulse"}
	var well: int = run.run_routine(1, 0, player.global_position + Vector3(0, -1.1, -3.5), Vector3.FORWARD)
	checks["host_builds_well"] = well > 0 and int(run.world.records[well].get("grav", 0)) > 0
	run.builds[1]["routines"][0] = {"when": "cerca", "steps": ["raise", "cold"], "then": "fragmentos", "on": "pulse"}
	var orb: int = run.run_routine(1, 0, player.global_position + Vector3(4, -1.1, 3), Vector3.RIGHT)
	checks["host_builds_held_ice"] = orb > 0 and run.world.records[orb]["shape"] == "orb" and run.world.records[orb]["suspended"]
	await frames(8)
	# A machine's properties ride the snapshot: the client draws what the rules read.
	if hound != null:
		hound.temp = 2
		hound.temp_hold = 30.0
		hound.charge = 1
		hound.charge_hold = 30.0
		hound.soaked = 30.0
	# One of the client's routines run by the host: the client hears each beat of it.
	var client_build: Dictionary = run.builds[client_id]
	if client_build["routines"].is_empty(): client_build["routines"].append({"when": "", "steps": [], "then": ""})
	client_build["routines"][0] = {"when": "cerca", "steps": ["raise", "cold"], "then": "estallar", "from": "water"}
	var client_body: Node3D = run.world._player(client_id)
	run.publish()
	run.spellwork.begin(client_id, 0, client_body.global_position + Vector3(2.5, 0, 0), Vector3.RIGHT)
	await frames(80)
	run.publish()
	inspect_client.rpc()
	await frames(20)
	for key_name: String in report: checks[key_name] = report[key_name]
	checks["client_report_received"] = not report.is_empty()
	print("SURVIVOR NETWORK ", JSON.stringify(checks))
	finish.rpc(1 if false in checks.values() else 0)
@rpc("authority", "call_remote", "reliable")
func move_client() -> void:
	Input.action_press("move_right")
	await frames(25)
	Input.action_release("move_right")
@rpc("authority", "call_remote", "reliable")
func choose_client() -> void:
	var choices: Array = run.offers.get(multiplayer.get_unique_id(), [])
	if not choices.is_empty(): run.choose_upgrade.rpc_id(1, choices[0])
@rpc("authority", "call_remote", "reliable")
func inspect_client() -> void:
	var me: Character = run.local_player()
	submit_report.rpc_id(1, {"client_has_body": me != null, "client_has_builds": run.builds.size() == 2, "client_has_host_kills": run.kills > 0, "client_phase_resumed": run.phase == "running", "client_worker_present": me != null and me.has_node("ShiftWorker"),
		"client_hears_its_routine_beats": int(beats.get("draw", 0)) >= 1 and int(beats.get("step", 0)) + int(beats.get("idle", 0)) >= 2 and int(beats.get("armed", 0)) >= 1,
		"client_sees_well_field": run.world.records.values().any(func(r: Dictionary) -> bool: return int(r.get("grav", 0)) > 0 and r.get("reaction", {}).get("action", "") == "detonar"),
		"client_sees_well_turning": run.world.records.values().any(func(r: Dictionary) -> bool: return int(r.get("grav", 0)) > 0 and r.get("grav_left", 0.0) > 0.0),
		"client_sees_held_sphere_and_trigger": run.world.records.values().any(func(r: Dictionary) -> bool: return r["shape"] == "orb" and r.get("suspended", false) and r.get("reaction", {}).get("on", "") == "pulse" and run.world.views[r["id"]].collider.shape is SphereShape3D),
		"client_sees_machine_props": run.machines.has_node("Machine701") and run.machines.get_node("Machine701").temp == 2 and run.machines.get_node("Machine701").charge == 1 and run.machines.get_node("Machine701").wet()})
@rpc("authority", "call_remote", "reliable")
func inspect_specialist(landing: Vector3) -> void:
	var hound: Node = run.machines.get_node_or_null("Machine701")
	submit_report.rpc_id(1, {"client_sees_specialist_phase": hound != null and hound.state in ["crouch", "air"], "client_sees_landing_mark": hound != null and hound.marks.size() == 1 and hound.state_to.distance_to(landing) < 0.01})
@rpc("any_peer", "reliable")
func submit_report(value: Dictionary) -> void:
	if is_host and multiplayer.get_remote_sender_id() == client_id: report.merge(value, true)
@rpc("authority", "call_local", "reliable")
func finish(code: int) -> void:
	get_tree().paused = false
	get_tree().quit(code)
